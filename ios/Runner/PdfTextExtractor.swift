import CoreGraphics
import Foundation
import PDFKit

/// Failure codes match `PdfImportFailure` in
/// lib/logic/import/pdf_text_extractor.dart and the Android extractor.
struct PdfImportError: Error, Equatable {
  let code: String
  let message: String

  static func invalid(_ message: String = "PDF could not be read") -> PdfImportError {
    PdfImportError(code: "invalidPdf", message: message)
  }
}

/// Offline text extraction only: no rendering, OCR, links or JavaScript.
/// iOS counterpart of the Android PDFBox extractor, with the same limits.
struct PdfTextExtractor {
  static let maxBytes = 10 * 1024 * 1024
  static let maxPages = 50
  static let maxText = 200_000
  static let maxOperators = 500_000

  /// Runs `extract` on a dedicated thread and reports back on the main queue.
  /// The large stack gives CoreGraphics' parser headroom on hostile nesting
  /// instead of overflowing a 512 KiB dispatch worker stack.
  static func extractInBackground(
    _ bytes: Data,
    completion: @escaping (Result<String, PdfImportError>) -> Void
  ) {
    let thread = Thread {
      let outcome: Result<String, PdfImportError>
      do {
        outcome = .success(try PdfTextExtractor().extract(bytes))
      } catch let error as PdfImportError {
        outcome = .failure(error)
      } catch {
        outcome = .failure(.invalid())
      }
      DispatchQueue.main.async { completion(outcome) }
    }
    thread.name = "morphcook.pdf-import"
    thread.stackSize = 16 * 1024 * 1024
    thread.qualityOfService = .userInitiated
    thread.start()
  }

  func extract(_ bytes: Data) throws -> String {
    if bytes.count > Self.maxBytes {
      throw PdfImportError(code: "tooLarge", message: "PDF is too large")
    }
    if bytes.count < 5 || bytes.prefix(5) != Data("%PDF-".utf8) {
      throw PdfImportError.invalid("Not a PDF document")
    }
    guard let provider = CGDataProvider(data: bytes as CFData),
      let document = CGPDFDocument(provider)
    else {
      throw PdfImportError.invalid()
    }
    if !document.isUnlocked {
      throw PdfImportError(code: "encrypted", message: "PDF requires a password")
    }
    if !document.allowsCopying {
      throw PdfImportError(code: "permissionDenied", message: "PDF does not permit text extraction")
    }
    // Empty-password encryption is still encryption: do not silently
    // bypass it merely because the library can open the document.
    if document.isEncrypted {
      throw PdfImportError(code: "encrypted", message: "PDF is encrypted")
    }
    if document.numberOfPages > Self.maxPages {
      throw PdfImportError(code: "tooManyPages", message: "PDF has too many pages")
    }
    try ContentBudget().check(document)

    guard let pdf = PDFDocument(data: bytes), pdf.pageCount == document.numberOfPages else {
      throw PdfImportError.invalid()
    }
    var text = ""
    var length = 0
    for index in 0..<pdf.pageCount {
      let pageText = autoreleasepool { pdf.page(at: index)?.string ?? "" }
      length += pageText.utf16.count + 1
      if length > Self.maxText {
        throw PdfImportError(code: "textTooLarge", message: "PDF contains too much text")
      }
      text += pageText
      text += "\n"
    }
    let result = Self.recomposeFractions(text)
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if result.isEmpty {
      throw PdfImportError(code: "noText", message: "PDF has no selectable text")
    }
    return result
  }

  /// Older PDFKit releases (seen on iOS 17) return vulgar fractions in their
  /// compatibility form, "1⁄2" for "½". Recompose them so amounts parse the
  /// same as on Android and current iOS; "1⁄25" stays untouched.
  private static let fractions: [(NSRegularExpression, String)] = "½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅐⅛⅜⅝⅞⅑⅒".map {
    let fraction = String($0)
    let pattern = NSRegularExpression.escapedPattern(
      for: fraction.decomposedStringWithCompatibilityMapping) + "(?!\\d)"
    return (try! NSRegularExpression(pattern: pattern), fraction)
  }

  static func recomposeFractions(_ text: String) -> String {
    guard text.contains("\u{2044}") else { return text }
    let result = NSMutableString(string: text)
    for (pattern, fraction) in fractions {
      pattern.replaceMatches(
        in: result, range: NSRange(location: 0, length: result.length), withTemplate: fraction)
    }
    return result as String
  }
}

/// Bounds the work hidden in content streams before PDFKit sees them, like the
/// operator and character counters in the Android stripper: a tiny compressed
/// PDF must not make extraction spin, and content CoreGraphics cannot tokenize
/// (e.g. an image-only filter on page content) is rejected as invalid.
private final class ContentBudget {
  private static let maxFormDepth = 32
  // Shown text in raw bytes. Two-byte CID fonts use up to two bytes per
  // character, so this only catches what could never fit `maxText`; the exact
  // character limit is enforced on the extracted text.
  private static let maxRawTextBytes = 2 * PdfTextExtractor.maxText

  private static let operators = [
    "b", "B", "b*", "B*", "BDC", "BI", "BMC", "BT", "BX", "c", "cm", "CS", "cs",
    "d", "d0", "d1", "DP", "EI", "EMC", "ET", "EX", "f", "F", "f*", "G", "g",
    "gs", "h", "i", "ID", "j", "J", "K", "k", "l", "m", "M", "MP", "n", "q",
    "Q", "re", "RG", "rg", "ri", "s", "S", "SC", "sc", "SCN", "scn", "sh", "T*",
    "Tc", "Td", "TD", "Tf", "TL", "Tm", "Tr", "Ts", "Tw", "Tz", "v", "w", "W",
    "W*", "y",
  ]

  private var failure: PdfImportError?
  private var operatorCount = 0
  private var rawTextBytes = 0
  private var depth = 0
  private var table: CGPDFOperatorTableRef?

  func check(_ document: CGPDFDocument) throws {
    guard let table = CGPDFOperatorTableCreate() else { throw PdfImportError.invalid() }
    self.table = table
    defer {
      self.table = nil
      CGPDFOperatorTableRelease(table)
    }
    for name in Self.operators {
      CGPDFOperatorTableSetCallback(table, name, Self.countOperator)
    }
    for name in ["Tj", "'", "\""] {
      CGPDFOperatorTableSetCallback(table, name, Self.showString)
    }
    CGPDFOperatorTableSetCallback(table, "TJ", Self.showArray)
    CGPDFOperatorTableSetCallback(table, "Do", Self.drawObject)

    guard document.numberOfPages > 0 else { return }
    for number in 1...document.numberOfPages {
      guard let page = document.page(at: number) else { throw PdfImportError.invalid() }
      let content = CGPDFContentStreamCreateWithPage(page)
      defer { CGPDFContentStreamRelease(content) }
      scan(content)
      if let failure { throw failure }
    }
  }

  private func scan(_ content: CGPDFContentStreamRef) {
    guard failure == nil, let table else { return }
    depth += 1
    defer { depth -= 1 }
    if depth > Self.maxFormDepth {
      failure = .invalid("PDF contains invalid recursive content")
      return
    }
    let scanner = CGPDFScannerCreate(content, table, Unmanaged.passUnretained(self).toOpaque())
    defer { CGPDFScannerRelease(scanner) }
    if !CGPDFScannerScan(scanner), failure == nil {
      failure = .invalid()
    }
  }

  /// Counts one operator; false once the budget is spent. Scanning cannot be
  /// aborted portably (CGPDFScannerStop is not in older iOS releases), so
  /// later callbacks just return early.
  private func spend() -> Bool {
    guard failure == nil else { return false }
    operatorCount += 1
    if operatorCount > PdfTextExtractor.maxOperators {
      failure = PdfImportError(code: "textTooLarge", message: "PDF content is too complex")
      return false
    }
    return true
  }

  private func show(_ string: CGPDFStringRef) {
    rawTextBytes += CGPDFStringGetLength(string)
    if rawTextBytes > Self.maxRawTextBytes, failure == nil {
      failure = PdfImportError(code: "textTooLarge", message: "PDF contains too much text")
    }
  }

  private static func budget(_ info: UnsafeMutableRawPointer?) -> ContentBudget {
    Unmanaged<ContentBudget>.fromOpaque(info!).takeUnretainedValue()
  }

  private static let countOperator: CGPDFOperatorCallback = { _, info in
    _ = budget(info).spend()
  }

  private static let showString: CGPDFOperatorCallback = { scanner, info in
    let budget = budget(info)
    guard budget.spend() else { return }
    var string: CGPDFStringRef?
    if CGPDFScannerPopString(scanner, &string), let string {
      budget.show(string)
    }
  }

  private static let showArray: CGPDFOperatorCallback = { scanner, info in
    let budget = budget(info)
    guard budget.spend() else { return }
    var array: CGPDFArrayRef?
    guard CGPDFScannerPopArray(scanner, &array), let array else { return }
    for index in 0..<CGPDFArrayGetCount(array) {
      var string: CGPDFStringRef?
      if CGPDFArrayGetString(array, index, &string), let string {
        budget.show(string)
      }
    }
  }

  /// Form XObjects are content streams too; PDFKit extracts their text, so
  /// their operators count against the same budget.
  private static let drawObject: CGPDFOperatorCallback = { scanner, info in
    let budget = budget(info)
    guard budget.spend() else { return }
    var name: UnsafePointer<CChar>?
    guard CGPDFScannerPopName(scanner, &name), let name else { return }
    let parent = CGPDFScannerGetContentStream(scanner)
    guard let object = CGPDFContentStreamGetResource(parent, "XObject", name) else { return }
    var stream: CGPDFStreamRef?
    guard CGPDFObjectGetValue(object, .stream, &stream), let stream,
      let dictionary = CGPDFStreamGetDictionary(stream)
    else { return }
    var subtype: UnsafePointer<CChar>?
    guard CGPDFDictionaryGetName(dictionary, "Subtype", &subtype), let subtype,
      strcmp(subtype, "Form") == 0
    else { return }
    var resources: CGPDFDictionaryRef?
    if !CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources) {
      resources = nil
    }
    let form = CGPDFContentStreamCreateWithStream(stream, resources ?? dictionary, parent)
    defer { CGPDFContentStreamRelease(form) }
    budget.scan(form)
  }
}

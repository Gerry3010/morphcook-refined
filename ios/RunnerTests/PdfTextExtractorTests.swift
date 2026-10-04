import Flutter
import UIKit
import XCTest

@testable import Runner

/// Real PDF bytes through the production iOS extractor; mirrors the Android
/// PdfTextExtractorTest so both platforms reject the same documents.
final class PdfTextExtractorTests: XCTestCase {
  func testExtractsCompressedUnicodeRecipe() throws {
    let expected = ["Kartoffelsuppe für zwei", "Zutaten", "½ EL Öl", "Zubereitung", "Gemüse dünsten."]
    let bytes = renderPdf(pages: 1) { _ in
      for (index, line) in expected.enumerated() {
        (line as NSString).draw(
          at: CGPoint(x: 40, y: 60 + index * 24),
          withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
      }
    }
    XCTAssertTrue(String(decoding: bytes, as: UTF8.self).contains("/FlateDecode"))
    let actual = try extract(bytes).get()
    for line in expected {
      XCTAssertTrue(actual.contains(line), "Missing \(line) in \(actual)")
    }
  }

  func testRecomposesDecomposedFractions() {
    XCTAssertEqual(PdfTextExtractor.recomposeFractions("1\u{2044}2 EL Öl"), "½ EL Öl")
    XCTAssertEqual(PdfTextExtractor.recomposeFractions("11\u{2044}2 Tassen"), "1½ Tassen")
    XCTAssertEqual(PdfTextExtractor.recomposeFractions("1\u{2044}10 l"), "⅒ l")
    XCTAssertEqual(PdfTextExtractor.recomposeFractions("1\u{2044}25 l"), "1\u{2044}25 l")
    XCTAssertEqual(PdfTextExtractor.recomposeFractions("½ und ¾"), "½ und ¾")
  }

  func testRejectsOversizedBytesBeforeParsing() {
    assertFailure("tooLarge", Data(count: PdfTextExtractor.maxBytes + 1))
  }

  func testRejectsPageOverflowWithoutTruncation() {
    assertFailure("tooManyPages", renderPdf(pages: 51) { _ in })
  }

  func testRejectsLargeTextOnOnePage() {
    // 201 lines of 1000 glyphs at 1pt still fit on the page; PDFKit only
    // extracts on-page text, so the limit must trip on what it really returns.
    let line = "(" + String(repeating: "a", count: 1000) + ") Tj 0 -1.2 Td\n"
    let content = "BT /F1 1 Tf 10 780 Td\n" + String(repeating: line, count: 201) + "ET"
    assertFailure("textTooLarge", rawPdf(content: content))
  }

  func testRejectsExcessiveContentOperations() {
    assertFailure("textTooLarge", rawPdf(content: String(repeating: "q Q\n", count: 250_001)))
  }

  func testRejectsDeeplyNestedContentWithoutCrashing() {
    let content = String(repeating: "[", count: 20_000) + "0" + String(repeating: "]", count: 20_000)
    // Android reports invalidPdf; CoreGraphics skips the unusable content, so
    // iOS may only find no text. Either is a clean, user-facing failure.
    assertFailure(oneOf: ["invalidPdf", "noText"], rawPdf(content: content))
  }

  func testRejectsSelfReferencingFormsWithoutCrashing() {
    let form = streamObject(
      "/Type /XObject /Subtype /Form /BBox [0 0 10 10] /Resources << /XObject << /Loop 5 0 R >> >>",
      Data("/Loop Do".utf8))
    assertFailure(
      oneOf: ["invalidPdf", "textTooLarge", "noText"],
      rawPdf(content: "/Loop Do", resources: "/XObject << /Loop 5 0 R >>", extraObjects: [form]))
  }

  func testRejectsPasswordAndEmptyPasswordEncryption() {
    for password in ["secret", ""] {
      let bytes = quartzPdf([
        kCGPDFContextOwnerPassword: "owner",
        kCGPDFContextUserPassword: password,
      ])
      assertFailure("encrypted", bytes)
    }
  }

  func testRespectsExtractionPermissions() {
    let bytes = quartzPdf([
      kCGPDFContextOwnerPassword: "owner",
      kCGPDFContextUserPassword: "",
      kCGPDFContextAllowsCopying: false,
    ])
    assertFailure("permissionDenied", bytes)
  }

  func testRejectsCorruptAndImageOnlyDocuments() {
    assertFailure("invalidPdf", Data("%PDF-1.7\nnot a valid document".utf8))
    assertFailure("invalidPdf", Data("not a PDF".utf8))
    let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
      UIColor.black.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
    }
    assertFailure("noText", renderPdf(pages: 1) { _ in image.draw(at: .zero) })
  }

  func testExtractsRecipeTextWithoutDecodingJpeg2000Images() throws {
    func pdfWithImage(_ text: String) -> Data {
      let image = streamObject(
        "/Type /XObject /Subtype /Image /Width 1 /Height 1 /BitsPerComponent 8 /ColorSpace /DeviceRGB /Filter /JPXDecode",
        Self.jpeg2000Pixel)
      return rawPdf(
        content: "BT /F1 12 Tf 40 700 Td (\(text)) Tj ET\nq 1 0 0 1 0 0 cm /JPXTest Do Q",
        resources: "/Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> /XObject << /JPXTest 5 0 R >>",
        extraObjects: [image])
    }
    XCTAssertEqual(try extract(pdfWithImage("Soup: simmer carrots.")).get(), "Soup: simmer carrots.")
    assertFailure("noText", pdfWithImage(""))
  }

  func testRejectsJpeg2000FilteredPageContentWithoutCrashing() {
    // Malformed PDFs can put an image-only filter on the text content stream.
    let bytes = pdf(objects: [
      Data("<< /Type /Catalog /Pages 2 0 R >>".utf8),
      Data("<< /Type /Pages /Kids [3 0 R] /Count 1 >>".utf8),
      Data("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>".utf8),
      streamObject("/Filter /JPXDecode", Self.jpeg2000Pixel),
    ])
    assertFailure(oneOf: ["invalidPdf", "noText"], bytes)
  }

  func testChannelAllowsOneImportAtATime() {
    let plugin = PdfImportPlugin()
    let bytes = renderPdf(pages: 1) { _ in
      ("Soup" as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
    }
    let call = FlutterMethodCall(
      methodName: "extractText", arguments: ["bytes": FlutterStandardTypedData(bytes: bytes)])
    let first = expectation(description: "first import")
    plugin.handle(call) { value in
      XCTAssertEqual(value as? String, "Soup")
      first.fulfill()
    }
    plugin.handle(call) { value in
      XCTAssertEqual((value as? FlutterError)?.code, "unavailable")
    }
    wait(for: [first], timeout: 30)

    let unknown = expectation(description: "unknown method")
    plugin.handle(FlutterMethodCall(methodName: "render", arguments: nil)) { value in
      XCTAssertTrue((value as AnyObject) === (FlutterMethodNotImplemented as AnyObject))
      unknown.fulfill()
    }
    wait(for: [unknown], timeout: 5)
  }

  // MARK: - Helpers

  private func extract(_ bytes: Data) -> Result<String, PdfImportError> {
    let done = expectation(description: "extract")
    var outcome: Result<String, PdfImportError>!
    PdfTextExtractor.extractInBackground(bytes) {
      outcome = $0
      done.fulfill()
    }
    wait(for: [done], timeout: 60)
    return outcome
  }

  private func assertFailure(_ code: String, _ bytes: Data, line: UInt = #line) {
    assertFailure(oneOf: [code], bytes, line: line)
  }

  private func assertFailure(oneOf codes: Set<String>, _ bytes: Data, line: UInt = #line) {
    switch extract(bytes) {
    case .success(let text):
      XCTFail("Expected \(codes.sorted()), extracted \(text.prefix(80))", line: line)
    case .failure(let error):
      XCTAssertTrue(codes.contains(error.code), "Unexpected \(error.code)", line: line)
    }
  }

  private func renderPdf(pages: Int, draw: (UIGraphicsPDFRendererContext) -> Void) -> Data {
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
    return renderer.pdfData { context in
      for _ in 0..<pages {
        context.beginPage()
        draw(context)
      }
    }
  }

  private func quartzPdf(_ options: [CFString: Any]) -> Data {
    let data = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: 612, height: 792)
    let consumer = CGDataConsumer(data: data as CFMutableData)!
    let context = CGContext(consumer: consumer, mediaBox: &box, options as CFDictionary)!
    context.beginPDFPage(nil)
    context.endPDFPage()
    context.closePDF()
    return data as Data
  }

  private func rawPdf(
    content: String,
    resources: String = "/Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >>",
    extraObjects: [Data] = []
  ) -> Data {
    let objects: [Data] = [
      Data("<< /Type /Catalog /Pages 2 0 R >>".utf8),
      Data("<< /Type /Pages /Kids [3 0 R] /Count 1 >>".utf8),
      Data("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << \(resources) >> /Contents 4 0 R >>".utf8),
      streamObject("", Data(content.utf8)),
    ]
    return pdf(objects: objects + extraObjects)
  }

  private func streamObject(_ dictionary: String, _ payload: Data) -> Data {
    var object = Data("<< \(dictionary) /Length \(payload.count) >>\nstream\n".utf8)
    object.append(payload)
    object.append(Data("\nendstream".utf8))
    return object
  }

  /// Minimal PDF writer with a correct xref table; objects are numbered from 1.
  private func pdf(objects: [Data]) -> Data {
    var output = Data("%PDF-1.7\n".utf8)
    var offsets: [Int] = []
    for (index, object) in objects.enumerated() {
      offsets.append(output.count)
      output.append(Data("\(index + 1) 0 obj\n".utf8))
      output.append(object)
      output.append(Data("\nendobj\n".utf8))
    }
    let xref = output.count
    var table = "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
    for offset in offsets {
      table += String(format: "%010d 00000 n \n", offset)
    }
    table += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
    output.append(Data(table.utf8))
    return output
  }

  // A real 1x1 blue JP2 fixture (same bytes as the Android test).
  private static let jpeg2000Pixel = Data(
    base64Encoded:
      "AAAADGpQICANCocKAAAAFGZ0eXBqcDIgAAAAAGpwMiAAAAAtanAyaAAAABZpaGRyAAAAAQAAAAEAAwcHAAAAAAAPY29scgEAAAAAABAAAACSanAyY/9P/1EALwAAAAAAAQAAAAEAAAAAAAAAAAAAAAEAAAABAAAAAAAAAAAAAwcBAQcBAQcBAf9SAAwAAAABAAAEBAAB/1wABEBA/2QAJQABQ3JlYXRlZCBieSBPcGVuSlBFRyB2ZXJzaW9uIDIuNS40/5AACgAAAAAAGgAB/5PfgAgH34AIB8+0BAD/2Q=="
  )!
}

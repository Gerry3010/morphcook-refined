import Flutter
import Foundation

/// Serves `morphcook/pdf_import` like the Android MainActivity handler: one
/// import at a time, extracted off the main thread with the same limits.
final class PdfImportPlugin: NSObject, FlutterPlugin {
  static let channelName = "morphcook/pdf_import"

  private var busy = false  // only touched on the main thread

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(PdfImportPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "extractText" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let arguments = call.arguments as? [String: Any]
    guard let bytes = (arguments?["bytes"] as? FlutterStandardTypedData)?.data, !bytes.isEmpty else {
      result(FlutterError(code: "invalidPdf", message: "No PDF data was supplied", details: nil))
      return
    }
    if bytes.count > PdfTextExtractor.maxBytes {
      result(FlutterError(code: "tooLarge", message: "The PDF exceeds the file limit", details: nil))
      return
    }
    if busy {
      result(FlutterError(code: "unavailable", message: "A PDF import is already running", details: nil))
      return
    }
    busy = true
    PdfTextExtractor.extractInBackground(bytes) { [weak self] outcome in
      self?.busy = false
      switch outcome {
      case .success(let text):
        result(text)
      case .failure(let error):
        result(FlutterError(code: error.code, message: error.message, details: nil))
      }
    }
  }
}

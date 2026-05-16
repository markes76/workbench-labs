import AppKit
import CoreImage
import Foundation

public enum QRCodeService {
  public static func pngData(for text: String, scale: CGFloat = 12) throws -> Data {
    guard !text.isEmpty else { throw ToolEngineError.emptyInput }
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
      throw ToolEngineError.runtimeUnavailable("CIQRCodeGenerator is not available.")
    }
    filter.setValue(Data(text.utf8), forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    guard let outputImage = filter.outputImage else {
      throw ToolEngineError.invalidInput("Could not generate a QR code from this text.")
    }

    let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let representation = NSCIImageRep(ciImage: transformed)
    let image = NSImage(size: representation.size)
    image.addRepresentation(representation)
    guard
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
    else {
      throw ToolEngineError.invalidInput("Could not encode the generated QR code as PNG.")
    }
    return png
  }

  public static func readQRCode(fromImageAt path: String) throws -> String {
    let url = URL(fileURLWithPath: path.expandingTildeInPath)
    guard let image = CIImage(contentsOf: url) else {
      throw ToolEngineError.invalidInput("Could not open an image at \(path).")
    }
    let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [
      CIDetectorAccuracy: CIDetectorAccuracyHigh
    ])
    let features = detector?.features(in: image) as? [CIQRCodeFeature] ?? []
    let messages = features.compactMap(\.messageString)
    guard !messages.isEmpty else {
      throw ToolEngineError.invalidInput("No QR code was found in the image.")
    }
    return messages.joined(separator: "\n")
  }
}

private extension String {
  var expandingTildeInPath: String {
    NSString(string: self).expandingTildeInPath
  }
}

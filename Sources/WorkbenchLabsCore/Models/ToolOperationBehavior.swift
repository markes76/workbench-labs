import Foundation

public enum ToolOperationBehavior {
  public static func inverseOperation(for toolID: ToolID, currentOperation: String) -> String? {
    switch toolID {
    case .base64Codec, .urlCodec, .htmlEntities:
      return inverse(currentOperation, first: "encode", second: "decode")
    case .backslashCodec:
      return inverse(currentOperation, first: "escape", second: "unescape")
    default:
      return nil
    }
  }

  private static func inverse(_ currentOperation: String, first: String, second: String) -> String? {
    switch currentOperation {
    case first:
      return second
    case second:
      return first
    default:
      return nil
    }
  }
}

import Foundation
import XCTest
@testable import WorkbenchLabsCore

final class JavaScriptToolRunnerRuntimeSafetyTests: XCTestCase {
  func testRuntimeTimeoutTerminatesHungProcessAndReportsTool() throws {
    let scriptURL = try makeRuntimeScript(
      """
      trap '' TERM
      while :; do :; done
      """
    )
    let runner = JavaScriptToolRunner(
      runtimeScriptURL: scriptURL,
      nodeExecutableURL: URL(fileURLWithPath: "/bin/sh"),
      timeout: 0.2,
      maxCapturedOutputBytes: 4_096
    )

    let startedAt = Date()
    XCTAssertThrowsError(try runner.run(tool: "json", input: "{}")) { error in
      XCTAssertLessThan(Date().timeIntervalSince(startedAt), 2.0)
      guard case ToolEngineError.runtimeUnavailable(let message) = error else {
        return XCTFail("Expected runtimeUnavailable, got \(error)")
      }
      XCTAssertTrue(message.contains("timed out"), message)
      XCTAssertTrue(message.contains("json"), message)
    }
  }

  func testRuntimeFailureDrainsAndCapsLargeStderr() throws {
    let scriptURL = try makeRuntimeScript(
      """
      i=0
      while [ "$i" -lt 10000 ]; do
        printf 'stderr-chunk-%05d\\n' "$i" >&2
        i=$((i + 1))
      done
      exit 7
      """
    )
    let runner = JavaScriptToolRunner(
      runtimeScriptURL: scriptURL,
      nodeExecutableURL: URL(fileURLWithPath: "/bin/sh"),
      timeout: 2,
      maxCapturedOutputBytes: 256
    )

    XCTAssertThrowsError(try runner.run(tool: "json", input: "{}")) { error in
      guard case ToolEngineError.runtimeUnavailable(let message) = error else {
        return XCTFail("Expected runtimeUnavailable, got \(error)")
      }
      XCTAssertTrue(message.contains("exited with status 7"), message)
      XCTAssertTrue(message.contains("stderr-chunk-00000"), message)
      XCTAssertTrue(message.contains("truncated"), message)
      XCTAssertFalse(message.contains("stderr-chunk-09999"), message)
      XCTAssertLessThan(message.count, 800)
    }
  }

  private func makeRuntimeScript(_ body: String) throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("JavaScriptToolRunnerRuntimeSafetyTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: directoryURL)
    }

    let scriptURL = directoryURL.appendingPathComponent("runtime.sh")
    try "#!/bin/sh\n\(body)\n".write(to: scriptURL, atomically: true, encoding: .utf8)
    return scriptURL
  }
}

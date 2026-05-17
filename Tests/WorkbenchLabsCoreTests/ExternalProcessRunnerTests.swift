import XCTest
@testable import WorkbenchLabsCore

final class ExternalProcessRunnerTests: XCTestCase {
  func testRunCapturesStdoutStderrAndExitCode() throws {
    let runner = ExternalProcessRunner()
    let result = try runner.run(
      executableURL: URL(fileURLWithPath: "/bin/sh"),
      arguments: ["-c", "printf 'hello'; printf 'warn' >&2"],
      timeout: 2
    )

    XCTAssertEqual(result.stdoutString, "hello")
    XCTAssertEqual(result.stderrString, "warn")
    XCTAssertEqual(result.exitCode, 0)
    XCTAssertFalse(result.didTimeOut)
    XCTAssertTrue(result.isSuccess)
  }

  func testRunCapturesNonzeroExitCodeWithoutThrowing() throws {
    let runner = ExternalProcessRunner()
    let result = try runner.run(
      executableURL: URL(fileURLWithPath: "/bin/sh"),
      arguments: ["-c", "printf 'bad' >&2; exit 7"],
      timeout: 2
    )

    XCTAssertEqual(result.stdoutString, "")
    XCTAssertEqual(result.stderrString, "bad")
    XCTAssertEqual(result.exitCode, 7)
    XCTAssertFalse(result.didTimeOut)
    XCTAssertFalse(result.isSuccess)
  }

  func testRequireExecutableReportsLookupFailures() {
    let runner = ExternalProcessRunner(searchPaths: ["/tmp/workbench-labs-missing-tools"])

    XCTAssertThrowsError(try runner.requireExecutable(named: "definitely-not-installed")) { error in
      guard case let ExternalProcessRunnerError.executableNotFound(name, searchPaths) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(name, "definitely-not-installed")
      XCTAssertEqual(searchPaths, ["/tmp/workbench-labs-missing-tools"])
    }
  }

  func testRunCapturesTimeoutAndTerminatesProcess() throws {
    let runner = ExternalProcessRunner()
    let result = try runner.run(
      executableURL: URL(fileURLWithPath: "/bin/sh"),
      arguments: ["-c", "printf 'started'; sleep 5"],
      timeout: 0.1
    )

    XCTAssertEqual(result.stdoutString, "started")
    XCTAssertNil(result.exitCode)
    XCTAssertTrue(result.didTimeOut)
    XCTAssertFalse(result.isSuccess)
  }
}

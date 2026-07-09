import CotermFoundation
import Darwin
import Foundation
import XCTest

#if canImport(Coterm_DEV)
@testable import Coterm_DEV
#elseif canImport(Coterm)
@testable import Coterm
#endif

// The descriptor-level read regressions (would-block on an open writer,
// end-of-file on a closed writer, partial data preserved on a failing read)
// are covered in CotermFoundation's FileHandleProcessPipeReadingTests, next to
// the moved implementation. This app-side test pins the consumer behavior
// that depends on app types.
final class ProcessPipeReadCrashRegressionTests: XCTestCase {
    func testProcessOutputCollectorTreatsBrokenReadDescriptorAsClosedPipe() {
        let stdout = Pipe()
        let stderr = Pipe()
        let collector = ProcessOutputCollector(stdout: stdout, stderr: stderr)

        try? stdout.fileHandleForWriting.close()
        try? stderr.fileHandleForWriting.close()
        Darwin.close(stdout.fileHandleForReading.fileDescriptor)

        let output = collector.finish()

        XCTAssertEqual(output, "")
    }
}

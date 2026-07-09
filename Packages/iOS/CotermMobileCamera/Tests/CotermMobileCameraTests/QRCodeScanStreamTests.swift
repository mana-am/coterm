import Testing
@testable import CotermMobileCamera

@Suite struct QRCodeScanStreamTests {
    @Test func yieldsCodesInOrderThenFinishes() async {
        let stream = QRCodeScanStream()
        stream.yield("coterm-ios://one")
        stream.yield("coterm-ios://two")
        stream.finish()

        var seen: [String] = []
        for await code in stream.codes {
            seen.append(code)
        }
        #expect(seen == ["coterm-ios://one", "coterm-ios://two"])
    }

    @Test func finishWithoutYieldProducesEmptySequence() async {
        let stream = QRCodeScanStream()
        stream.finish()

        var seen: [String] = []
        for await code in stream.codes {
            seen.append(code)
        }
        #expect(seen.isEmpty)
    }
}

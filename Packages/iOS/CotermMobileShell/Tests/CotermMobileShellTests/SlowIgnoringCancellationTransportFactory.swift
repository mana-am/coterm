import CotermMobileCore
import CotermMobileRPC

struct SlowIgnoringCancellationTransportFactory: CmxByteTransportFactory {
    func makeTransport(for route: CmxAttachRoute) throws -> any CmxByteTransport {
        SlowIgnoringCancellationTransport()
    }
}

import CotermMobileCore
@testable import CotermMobileRPC

struct ResponseTimeoutSurvivalTransportFactory: CmxByteTransportFactory {
    let transport: ResponseTimeoutSurvivalTransport

    func makeTransport(for route: CmxAttachRoute) throws -> any CmxByteTransport {
        transport
    }
}

import CotermMobileCore
import CotermMobileRPC
import CotermMobileShellModel

/// The live client to a secondary Mac plus the route/ticket it was dialed on.
struct SecondaryClientHandle {
    let client: MobileCoreRPCClient
    let route: CmxAttachRoute
    let ticket: CmxAttachTicket
    let supportedHostCapabilities: Set<String>
    let actionCapabilities: MobileWorkspaceActionCapabilities
}

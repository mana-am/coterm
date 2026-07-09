import Foundation

/// Current sidebar state delivered by COTERM to a sidebar extension.
public struct CotermSidebarContext: Sendable {
    /// Latest workspace snapshot filtered to the permissions granted by the user.
    public let snapshot: CotermSidebarSnapshot

    /// Read scopes COTERM granted for this snapshot.
    public let grantedReadScopes: Set<CotermExtensionScope>

    /// Host actions COTERM will currently accept from this extension.
    public let grantedActionScopes: Set<CotermExtensionActionScope>

    /// Typed command channel back to COTERM.
    public let host: CotermSidebarHost

    @MainActor
    public init(
        snapshot: CotermSidebarSnapshot,
        grantedReadScopes: Set<CotermExtensionScope>? = nil,
        grantedActionScopes: Set<CotermExtensionActionScope>? = nil,
        host: CotermSidebarHost
    ) {
        self.snapshot = snapshot
        self.grantedReadScopes = grantedReadScopes ?? snapshot.grantedReadScopes
        self.grantedActionScopes = grantedActionScopes ?? snapshot.grantedActionScopes
        self.host = host
    }
}

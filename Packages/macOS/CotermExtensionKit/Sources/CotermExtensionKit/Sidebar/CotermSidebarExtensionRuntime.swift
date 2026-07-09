import Foundation

/// Runtime bridge between one sidebar extension instance and its XPC connection.
///
/// `@unchecked Sendable` is safe here because the only stored state is the
/// lock-protected `CotermSidebarExtensionConnection`. The extension instance is
/// captured weakly inside `@MainActor` callbacks and is not stored on this type.
final class CotermSidebarExtensionRuntime: @unchecked Sendable {
    private let connection: CotermSidebarExtensionConnection

    @MainActor
    init<Extension: CotermSidebarExtension>(sidebarExtension: Extension) {
        var transport: CotermSidebarExtensionConnection!
        transport = CotermSidebarExtensionConnection(
            manifest: Extension.manifest,
            onSnapshot: { [weak sidebarExtension] snapshot in
                let host = CotermSidebarHost(
                    performCancellableAction: { action, reply in
                        transport.perform(action, reply: reply)
                    },
                    refreshSnapshot: {
                        transport.refreshSnapshot()
                    }
                )
                sidebarExtension?.update(context: CotermSidebarContext(snapshot: snapshot, host: host))
            },
            onStatus: { [weak sidebarExtension] status in
                sidebarExtension?.connectionStatusDidChange(status)
            }
        )
        self.connection = transport
    }

    @discardableResult
    func accept(_ connection: NSXPCConnection) -> Bool {
        self.connection.accept(connection)
    }

    deinit {
        connection.invalidate()
    }
}

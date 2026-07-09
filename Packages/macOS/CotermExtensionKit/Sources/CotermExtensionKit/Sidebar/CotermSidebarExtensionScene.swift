import ExtensionFoundation
import ExtensionKit
import Foundation
import SwiftUI

struct CotermSidebarExtensionScene<Extension: CotermSidebarExtension>: AppExtensionScene {
    private let sidebarExtension: Extension
    private let id: String

    init(_ extension: Extension, id: String = CotermSidebarExtensionPoint.defaultSceneID) {
        self.sidebarExtension = `extension`
        self.id = id
    }

    @MainActor
    var body: PrimitiveAppExtensionScene {
        let runtime = CotermSidebarExtensionRuntime(sidebarExtension: sidebarExtension)
        let acceptConnection: @Sendable (NSXPCConnection) -> Bool = { connection in
            runtime.accept(connection)
        }
        return PrimitiveAppExtensionScene(id: id) {
            sidebarExtension.body
        } onConnection: { connection in
            acceptConnection(connection)
        }
    }
}

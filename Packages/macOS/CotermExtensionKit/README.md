# COTERM Extension Kit

`CotermExtensionKit` is the zero-dependency public SDK for COTERM sidebar extensions.

Version 1 only supports sidebar extensions. The API exposes a stable workspace snapshot and typed action channels:

- read the current sidebar snapshot
- create, select, navigate, and close workspaces
- create, select, navigate, split, zoom, and close surfaces
- ask COTERM to open a URL

The snapshot includes workspace identity, title, detail text, paths, git branch, unread state, listening ports, pull request URLs, and shared surface metadata. It does not expose terminal buffers, shell history, environment variables, secrets, or arbitrary filesystem access.

Host-side lifecycle, discovery, and display belong in `Packages/macOS/CotermExtensionHostSupport`.
Internal coterm-owned sidebar provider/render models live in `Packages/macOS/CotermSidebarProviderKit`.
They are separate from the public extension-author SDK.

## Five-Minute Sidebar Extension

Sidebar extensions are ExtensionKit app extensions. `CotermExtensionKit` and the reference projects target macOS 14+, matching COTERM.

Use `Examples/SampleSidebarExtensionApp` as the reference project:

1. Open `SampleSidebarExtensionApp.xcodeproj`.
2. Change the app and extension bundle identifiers to your own reverse-DNS prefix.
3. Change the signing team from emergent.inc to your team.
4. Keep the extension point identifier as `coterm.com.emergent.app.coterm.sidebar`.
5. Build and launch the containing app once so macOS registers the embedded extension.
6. In COTERM, open Sidebar Extensions from the puzzle button next to the sidebar help button and enable your extension.
7. Choose the extension sidebar provider from that puzzle menu.
8. If more than one sidebar extension is enabled, choose your extension from the extension sidebar header.

The extension target declares the extension point manually in its `Info.plist`:

```xml
<key>EXAppExtensionAttributes</key>
<dict>
  <key>EXExtensionPointIdentifier</key>
  <string>coterm.com.emergent.app.coterm.sidebar</string>
</dict>
```

Define your ExtensionKit entrypoint by conforming directly to `CotermSidebarExtension`.
The SDK refines `ExtensionFoundation.AppExtension`, supplies the ExtensionKit
configuration, owns the scene/XPC wiring, and uses the stable sidebar scene ID.
Your extension provides the manifest, SwiftUI view, and update handling:

```swift
import CotermExtensionKit
import Observation
import SwiftUI

@main
@Observable
@MainActor
final class ExampleSidebarExtension: CotermSidebarExtension {
    static let manifest = CotermExtensionManifest(
        id: "dev.example.sidebar",
        displayName: String(localized: "exampleSidebar.manifest.displayName", defaultValue: "Example Sidebar"),
        readScopes: [.workspaceMetadata],
        actionScopes: [.selectWorkspace]
    )

    private(set) var snapshot: CotermSidebarSnapshot?
    private var host: CotermSidebarHost?

    required init() {}

    var body: some View {
        List(snapshot?.workspaces ?? []) { workspace in
            Button(workspace.title) {
                Task { @MainActor in
                    try? await host?.selectWorkspace(workspace.id)
                }
            }
        }
    }

    func update(context: CotermSidebarContext) {
        snapshot = context.snapshot
        host = context.host
    }

    func connectionStatusDidChange(_ status: CotermSidebarConnectionStatus) {
        // Update optional connection UI here.
    }
}
```

## Extension Protocols

`CotermSidebarExtension` is the public extension protocol. It refines `AppExtension`,
requires a manifest and SwiftUI `body`, and delivers `CotermSidebarContext`, which
contains the filtered `CotermSidebarSnapshot` and a typed `CotermSidebarHost` command
channel.

The lower-level transport lives behind COTERM host SPI. New sidebar extensions should
conform to `CotermSidebarExtension` and should not handle XPC directly.

`connectionStatusDidChange(_:)` reports `.connected`, `.waitingForHost`, or
`.error(String)` when the host connection changes. Extensions that do not show
connection state can omit the method.

`context.host` is the public command channel for sidebar extensions. It exposes
typed helpers for workspace, surface, and URL actions. Raw transport setup and
host-side callbacks are SPI for COTERM's own host implementation.
Creating or splitting a browser surface with a URL requires both the surface
action scope and `openURL`.

## Permissions

List every scope and action your extension needs in its manifest. COTERM filters the
snapshot and rejects actions that have not been granted:

- `workspaceList`: workspace identities and ordering only
- `workspaceMetadata`: workspace names, branches, unread counts, and selection
- `surfaceMetadata`: shared tab/surface names, kinds, focus, and unread counts
- `workspacePaths`: local workspace and project paths
- `notifications`: latest workspace notifications
- `networkPorts`: listening ports for each workspace
- `pullRequests`: pull request links associated with workspaces
- `createWorkspace`: create workspaces
- `selectWorkspace`: select a workspace from your UI
- `closeWorkspace`: close workspaces from your UI
- `createSurface`: create terminal and browser surfaces
- `selectSurface`: select a surface within a workspace
- `closeSurface`: close a surface
- `splitSurface`: split a terminal or browser surface
- `zoomSurface`: toggle surface zoom
- `navigateWorkspace`: select the next or previous workspace
- `navigateSurface`: select the next or previous surface
- `openURL`: open links from your UI
- `createWorkspaceWithPath`: create workspaces for specific local folders

If your extension does not appear, confirm the containing app has been launched, the embedded appex is signed by your team, the extension point identifier is unchanged, and COTERM's Sidebar Extensions browser shows the extension as enabled.

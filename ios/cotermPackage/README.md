# cotermFeature

The iOS **composition-root** package: the thin layer that wires the focused
mobile packages together and hands the assembled graph to the app shell. It is
no longer the catch-all it started as (it was ~10.6k LOC across stores, RPC,
persistence, and every view). After the 5079 refactor waves it is ~425 LOC
across six cohesive files, all of which belong to one role: *build the runtime
DI bundle, the auth graph, and the root scene; inject everything down.*

## What lives here

| Type | Layer | Role |
|---|---|---|
| `CotermMobileRuntime` | service DI bundle | Sendable `MobileSyncRuntime`: transport factory, injected access-token provider, timeouts, clock, capability flags. The bright-spot init-injection bundle the rest of the line was modeled on. |
| `MobileAuthComposition` | composition | Builds the de-singletonized auth graph once at startup over `CotermAuthRuntime` + `CotermAuthCore` (coordinator, Stack client, caches, push registration). Replaces `AuthManager.shared` / `StackAuthApp.shared` / `AppEnvironment`. |
| `MobileAuthBuildPolicy` | value | Build-flag policy (the DEBUG `42` dev-auth shortcut) as a value, not a static namespace. |
| `DeferredSignInHook` | composition | Breaks the coordinator ↔ push construction cycle. |
| `AuthCoordinatorIdentityProvider` | seam adapter | `MobileIdentityProviding` over the injected `AuthCoordinator`. |
| `CotermMobileRootScene` | ui (root) | The top-level SwiftUI scene: assembles `CotermMobileShellStore`, injects the coordinator + push coordinator into the environment, mounts `CotermMobileShellUI`. |

Everything else that used to be fused in here was lifted out into focused
packages over waves 1-3:

- **core / shared** — `CotermMobileCore` (wire DTOs + transport seam),
  `CotermAuthCore` (auth value model), `CotermMobileShellModel` (shell value types
  + route-auth policy), `CotermMobileWorkspace` (pure presentation/layout policy).
- **service** — `CotermMobileRPC`, `CotermMobilePairedMac`, `CotermMobileTransport`,
  `CotermMobileCamera`, `CotermMobileDiagnostics`, `CotermMobileSupport`.
- **domain** — `CotermMobileShell` (the decomposed shell store + coordinators),
  `CotermMobileTerminalKit`, `CotermAuthRuntime` (the shared injected
  `AuthCoordinator`).
- **ui** — `CotermMobileShellUI` (workspace shell, sign-in, pairing, push
  coordinator), `CotermMobileTerminal` (the libghostty surface stack).

## Why it is still its own package, not folded into the app shell

The app shell (`ios/coterm/cotermApp.swift` + `CotermAppDelegate.swift` +
`AppCompositionRoot.swift`) is the *executable* layer: `@main App`, the
`UIApplicationDelegate`, and the constructed object graph. `cotermFeature` is the
*root-scene + DI* layer just below it, depended on by both the shell and (via
re-export of `CotermMobileShellUI`) the UI. Keeping the scene assembly and the
runtime bundle in a SwiftPM target keeps the app target itself a true shim
(imports `cotermFeature`, `CotermMobileCore`, `CotermMobileTransport` and nothing
else) and keeps the assembly independently testable in `cotermFeatureTests`
without launching the app.

## Build / test

```bash
# App build (the cotermFeature gate; cotermFeature is not macOS-resolvable on its own)
xcodebuild -workspace ../../coterm.xcworkspace -scheme coterm-ios \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  ARCHS=arm64 build

# Package test suite
swift test --package-path .
```

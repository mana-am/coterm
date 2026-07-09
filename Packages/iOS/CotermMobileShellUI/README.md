# CotermMobileShellUI

The SwiftUI half of the coterm iOS shell.

This is the leaf UI layer extracted out of the `cotermFeature` catch-all target. It
owns the workspace shell, sign-in, pairing, terminal detail, and root routing
views, plus the iOS push coordinator that the root view injects into the
SwiftUI environment.

It depends only downward: the decomposed domain facade
(`CotermMobileShell.CotermMobileShellStore`), the core/value packages
(`CotermMobileCore`, `CotermMobileShellModel`, `CotermMobileWorkspace`,
`CotermMobileSupport`), `CotermAuthRuntime` for the injected `AuthCoordinator`,
`CotermMobileTerminal` for the libghostty surface, and `CotermMobileCamera` for the
QR-pairing capture stack. It never reaches into RPC/transport concretes.

`cotermFeature` now sits *above* this package as the composition root
(`CotermMobileRootScene`, `CotermMobileRuntime`, the auth/push wiring) and
re-exports the package so the app shell keeps `import cotermFeature` working.

## Entry points

- ``CotermMobileAppView`` — the live mobile UI root, mounted by `CotermMobileRootScene`.
- ``MobilePushCoordinator`` — APNs↔store bridge, constructed at the app root.

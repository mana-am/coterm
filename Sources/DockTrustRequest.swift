struct DockTrustRequest: Identifiable, Sendable {
    var id: String { descriptor.fingerprint }
    let descriptor: CotermActionTrustDescriptor
    let configPath: String
}

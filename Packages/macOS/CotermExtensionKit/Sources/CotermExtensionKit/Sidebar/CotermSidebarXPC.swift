import Foundation

@_spi(CotermHostTransport) @objc public protocol CotermSidebarHostXPC: NSObjectProtocol {
    func requestSidebarSnapshot(reply: @escaping (NSData?, NSString?) -> Void)
    func performSidebarAction(_ payload: NSData, reply: @escaping (NSData?, NSString?) -> Void)
}

@_spi(CotermHostTransport) @objc public protocol CotermSidebarExtensionXPC: NSObjectProtocol {
    @objc optional func requestExtensionManifest(reply: @escaping (NSData?, NSString?) -> Void)
    func sidebarSnapshotDidChange(_ payload: NSData)
}

@_spi(CotermHostTransport)
public enum CotermSidebarXPCCodec {
    public static let maximumSnapshotPayloadBytes = 512 * 1024
    public static let maximumManifestPayloadBytes = 64 * 1024
    public static let maximumActionPayloadBytes = 8 * 1024
    public static let maximumActionResultPayloadBytes = 8 * 1024

    public static func encodeSnapshot(_ snapshot: CotermSidebarSnapshot) throws -> NSData {
        try encode(snapshot, kind: "snapshot", maximumBytes: maximumSnapshotPayloadBytes)
    }

    public static func decodeSnapshot(_ payload: NSData) throws -> CotermSidebarSnapshot {
        try validatePayloadSize(payload, kind: "snapshot", maximumBytes: maximumSnapshotPayloadBytes)
        return try JSONDecoder().decode(CotermSidebarSnapshot.self, from: payload as Data)
    }

    public static func encodeManifest(_ manifest: CotermExtensionManifest) throws -> NSData {
        try encode(manifest, kind: "manifest", maximumBytes: maximumManifestPayloadBytes)
    }

    public static func decodeManifest(_ payload: NSData) throws -> CotermExtensionManifest {
        try validatePayloadSize(payload, kind: "manifest", maximumBytes: maximumManifestPayloadBytes)
        return try JSONDecoder().decode(CotermExtensionManifest.self, from: payload as Data)
    }

    public static func encodeAction(_ action: CotermSidebarAction) throws -> NSData {
        try encode(action, kind: "action", maximumBytes: maximumActionPayloadBytes)
    }

    public static func decodeAction(_ payload: NSData) throws -> CotermSidebarAction {
        try validatePayloadSize(payload, kind: "action", maximumBytes: maximumActionPayloadBytes)
        return try JSONDecoder().decode(CotermSidebarAction.self, from: payload as Data)
    }

    public static func encodeActionResult(_ result: CotermSidebarActionResult) throws -> NSData {
        try encode(result, kind: "actionResult", maximumBytes: maximumActionResultPayloadBytes)
    }

    public static func decodeActionResult(_ payload: NSData) throws -> CotermSidebarActionResult {
        try validatePayloadSize(payload, kind: "actionResult", maximumBytes: maximumActionResultPayloadBytes)
        return try JSONDecoder().decode(CotermSidebarActionResult.self, from: payload as Data)
    }

    private static func validatePayloadSize(_ payload: NSData, kind: String, maximumBytes: Int) throws {
        guard payload.length <= maximumBytes else {
            throw CotermExtensionValidationError.payloadTooLarge(
                kind: kind,
                actualBytes: payload.length,
                maximumBytes: maximumBytes
            )
        }
    }

    private static func encode<T: Encodable>(_ value: T, kind: String, maximumBytes: Int) throws -> NSData {
        let payload = try JSONEncoder().encode(value) as NSData
        try validatePayloadSize(payload, kind: kind, maximumBytes: maximumBytes)
        return payload
    }
}

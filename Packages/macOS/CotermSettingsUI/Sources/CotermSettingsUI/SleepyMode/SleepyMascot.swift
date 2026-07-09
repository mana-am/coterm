import Foundation

/// Which mascot/face the Sleepy Mode scene draws.
public enum SleepyMascot: String, CaseIterable, Identifiable, Sendable {
    /// The coterm mascot.
    case coterm
    /// A sleepy cat.
    case cat
    /// A friendly ghost.
    case ghost
    /// A face built from the coterm `>` chevron logo.
    case logoFace

    /// Stable identity for `Identifiable` (the raw string value).
    public var id: String { rawValue }
}

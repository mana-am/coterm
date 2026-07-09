import Foundation

/// Visual presentation style used to render provider output in COTERM's sidebar.
public enum CotermSidebarProviderPresentation: String, Codable, Equatable, Sendable {
    /// Standard tree/list sidebar layout.
    case tree
    /// Browser-stack layout with stable required sections.
    case browserStack = "browser-stack"
}

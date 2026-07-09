import Bonsplit
import Foundation

enum CotermSurfaceTabBarBuiltInAction: String, Codable, Sendable, CaseIterable, Hashable {
    case newWorkspace = "coterm.newWorkspace"
    case cloudVM = "coterm.cloudvm"
    case newTerminal = "coterm.newTerminal"
    case newBrowser = "coterm.newBrowser"
    case splitRight = "coterm.splitRight"
    case splitDown = "coterm.splitDown"

    init?(configID: String) {
        switch configID {
        case "coterm.newWorkspace", "newWorkspace":
            self = .newWorkspace
        case "coterm.cloudvm", "coterm.cloudVM", "cloudVM", "cloudvm",
             "coterm.newCloudVM", "coterm.newCloudVm", "newCloudVM", "newCloudVm",
             "coterm.startCloudVM", "coterm.startCloudVm", "startCloudVM", "startCloudVm":
            self = .cloudVM
        case "coterm.newTerminal", "newTerminal":
            self = .newTerminal
        case "coterm.newBrowser", "newBrowser":
            self = .newBrowser
        case "coterm.splitRight", "splitRight":
            self = .splitRight
        case "coterm.splitDown", "splitDown":
            self = .splitDown
        default:
            return nil
        }
    }

    var configID: String {
        rawValue
    }

    var defaultIcon: String {
        switch self {
        case .newWorkspace:
            return "plus.square"
        case .cloudVM:
            return "cloud"
        case .newTerminal:
            return "plus"
        case .newBrowser:
            return "globe"
        case .splitRight:
            return "square.split.2x1"
        case .splitDown:
            return "square.split.1x2"
        }
    }

    var bonsplitAction: BonsplitConfiguration.SplitActionButton.Action? {
        switch self {
        case .newWorkspace, .cloudVM:
            return nil
        case .newTerminal:
            return .newTerminal
        case .newBrowser:
            return .newBrowser
        case .splitRight:
            return .splitRight
        case .splitDown:
            return .splitDown
        }
    }
}

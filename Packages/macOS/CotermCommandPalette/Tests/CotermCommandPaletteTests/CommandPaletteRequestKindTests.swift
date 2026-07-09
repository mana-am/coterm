import Foundation
import Testing

@testable import CotermCommandPalette

@Suite struct CommandPaletteRequestKindTests {
    @Test func notificationNamesMatchLegacyLiterals() {
        #expect(CommandPaletteRequestKind.commands.notificationName == "coterm.commandPaletteRequested")
        #expect(CommandPaletteRequestKind.switcher.notificationName == "coterm.commandPaletteSwitcherRequested")
        #expect(CommandPaletteRequestKind.renameTab.notificationName == "coterm.commandPaletteRenameTabRequested")
        #expect(CommandPaletteRequestKind.renameWorkspace.notificationName == "coterm.commandPaletteRenameWorkspaceRequested")
        #expect(
            CommandPaletteRequestKind.editWorkspaceDescription.notificationName
                == "coterm.commandPaletteEditWorkspaceDescriptionRequested"
        )
    }

    @Test func everyKindMarksPending() {
        for kind in CommandPaletteRequestKind.allCases {
            #expect(kind.marksPending)
        }
    }

    @Test func notificationNamesAreDistinct() {
        let names = Set(CommandPaletteRequestKind.allCases.map(\.notificationName))
        #expect(names.count == CommandPaletteRequestKind.allCases.count)
    }
}

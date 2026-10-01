import AppKit
import KayakomaKit
import SwiftUI

private struct MarkdownCheatSheetKey: FocusedValueKey {
    typealias Value = @MainActor () -> Void
}

extension FocusedValues {
    /// Shows the Markdown cheat sheet on the key window.
    var showMarkdownCheatSheet: (@MainActor () -> Void)? {
        get { self[MarkdownCheatSheetKey.self] }
        set { self[MarkdownCheatSheetKey.self] = newValue }
    }
}

/// The Help menu: the cheat sheet takes the place and the shortcut of
/// the app's help book, which Kayakoma does not have.
struct MarkdownHelpCommands: Commands {
    @FocusedValue(\.showMarkdownCheatSheet) private var showCheatSheet

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Aide-mémoire Markdown") { showCheatSheet?() }
                .keyboardShortcut("?", modifiers: .command)
                .disabled(showCheatSheet == nil)
        }
    }
}

/// The cheat sheet in the Viewer: read only, rows copy their syntax.
struct ViewerCheatSheet: View {
    let theme: Theme
    @Binding var isPresented: Bool
    var initialSection: CheatSheetSection? = .text

    var body: some View {
        MarkdownCheatSheet(theme: theme, action: CheatSheetPasteboard.copyAction, onDone: { isPresented = false },
                           initialSection: initialSection)
            .environment(\.softAccent, .lagoon)
    }
}

import AppKit
import KayakomaKit
import SwiftUI

@main
struct ViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        DocumentGroup(viewing: MarkdownFile.self) { file in
            DocumentWindow(fileURL: file.fileURL, content: file.document.content)
        }
        .commands {
            SidebarCommands()
            UpdateCommands(model: .shared)
            ViewerCommands()
            MarkdownHelpCommands()
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var updater: SparkleUpdater?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updater = SparkleUpdater(model: .shared, accent: .lagoon, notesTheme: .viewerDefault)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppearanceMode.applyStored()
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { AppearanceMode.applyStored() }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        ThemeLibrary.shared.reload()
        EditorLauncher.shared.refresh()
    }
}

/// Menu bar additions: Open in Editor and Export as PDF in the File menu,
/// Find in the Edit menu, text size in the View menu.
struct ViewerCommands: Commands {
    @FocusedValue(\.documentActions) private var actions
    @ObservedObject private var editor = EditorLauncher.shared
    @AppStorage(Preferences.fontSize) private var fontSize = Preferences.defaultFontSize

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            if editor.editorURL != nil {
                Button("Ouvrir dans l'Éditeur") {
                    if let url = actions?.fileURL { editor.open(url) }
                }
                .keyboardShortcut("e")
                .disabled(actions?.fileURL == nil)
            }
            Button("Exporter en PDF…") { actions?.exportPDF() }
                .keyboardShortcut("e", modifiers: [.command, .option])
                .disabled(actions == nil)
        }

        // ⌘E is Open in Editor here, so Use Selection for Find has no shortcut.
        CommandGroup(after: .pasteboard) {
            Divider()
            Menu("Rechercher") {
                Button("Rechercher…") { actions?.find(.showFindInterface) }
                    .keyboardShortcut("f")
                Button("Rechercher le suivant") { actions?.find(.nextMatch) }
                    .keyboardShortcut("g")
                Button("Rechercher le précédent") { actions?.find(.previousMatch) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Utiliser la sélection pour rechercher") { actions?.find(.setSearchString) }
            }
            .disabled(actions == nil)
        }

        CommandGroup(after: .sidebar) {
            Divider()
            Button("Agrandir le texte") { setFontSize(fontSize + 1) }
                .keyboardShortcut("+")
            Button("Réduire le texte") { setFontSize(fontSize - 1) }
                .keyboardShortcut("-")
            Button("Taille par défaut") { setFontSize(Preferences.defaultFontSize) }
                .keyboardShortcut("0")
        }
    }

    private func setFontSize(_ size: Double) {
        let range = Preferences.fontSizeRange
        fontSize = min(max(size, range.lowerBound), range.upperBound)
    }
}

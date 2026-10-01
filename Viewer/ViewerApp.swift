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
            ViewerCommands()
            MarkdownHelpCommands()
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
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
/// text size in the View menu.
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

import AppKit
import Combine

/// Finds Kayakoma Editor, so that "Open in Editor" shows only when it is installed.
@MainActor
final class EditorLauncher: ObservableObject {
    static let shared = EditorLauncher()
    static let bundleIdentifier = "app.kayakoma.editor"

    @Published private(set) var editorURL: URL?

    private init() {
        refresh()
    }

    /// Looks for the Editor again; called whenever the app becomes active.
    func refresh() {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleIdentifier)
        if url != editorURL { editorURL = url }
    }

    func open(_ fileURL: URL) {
        // The Editor may have moved or been reinstalled since the last lookup.
        refresh()
        guard let editorURL else { return }
        NSWorkspace.shared.open([fileURL], withApplicationAt: editorURL, configuration: NSWorkspace.OpenConfiguration())
    }
}

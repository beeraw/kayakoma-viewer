import AppKit
import KayakomaKit
import SwiftUI
import XCTest

/// Renders the main views offscreen into PNG files, to check the rendering
/// by eye. Runs only when `SNAPSHOT_DIR` is set (pass
/// `TEST_RUNNER_SNAPSHOT_DIR` to `xcodebuild test`).
@MainActor
final class SnapshotTests: XCTestCase {
    private static let sample = """
    # Mangrove

    > Carnet de terrain en Markdown, rangé par marée et par station.

    Mangrove range les relevés de terrain écrits en **Markdown** dans une arborescence datée, \
    et produit un index consultable *hors ligne*. Voir le [guide des stations](docs/stations.md).

    ## Installation

    ```sh
    $ brew install mangrove
    $ mangrove init ~/Releves
    ```

    ## Utilisation

    - `mangrove ajoute` crée la fiche du jour à partir du modèle ;
    - `mangrove range` déplace les fiches dans `AAAA/MM/` ;
    - `mangrove index` reconstruit le sommaire.

    ## Options

    | Option | Par défaut | Rôle |
    |---|---|---|
    | `--station` | aucune | Filtre sur une station |
    | `--depuis` | 30 jours | Période couverte |

    ## Feuille de route

    - [x] Import des relevés CSV
    - [ ] Export vers un tableur

    ## Licence

    MIT.
    """

    private var outputDirectory: URL!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        guard let path = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else {
            throw XCTSkip("SNAPSHOT_DIR is not set")
        }
        outputDirectory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: "app.kayakoma.viewer.snapshots")
    }

    override func tearDown() async throws {
        defaults?.removePersistentDomain(forName: "app.kayakoma.viewer.snapshots")
    }

    private func sampleFile() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "mangrove", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "README.md")
        try Self.sample.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testDocumentWindow() throws {
        let url = try sampleFile()
        let content = MarkdownFile.Content.text(DecodedText(text: Self.sample, encoding: .utf8))
        for dark in [false, true] {
            let view = DocumentWindow(fileURL: url, content: content).defaultAppStorage(defaults)
            try snapshotWindow(view, size: CGSize(width: 1100, height: 720), dark: dark,
                               name: "document-\(dark ? "dark" : "light")")
        }
        defaults.set(ThemeLibrary.paperID, forKey: Preferences.themeID)
        let paper = DocumentWindow(fileURL: url, content: content).defaultAppStorage(defaults)
        try snapshotWindow(paper, size: CGSize(width: 1100, height: 720), dark: false, name: "document-paper-light")
        try snapshotWindow(paper, size: CGSize(width: 1100, height: 720), dark: true, name: "document-paper-dark")
    }

    func testOutlineSidebar() throws {
        let model = DocumentModel(content: .text(DecodedText(text: Self.sample, encoding: .utf8)))
        model.currentHeadingID = "utilisation"
        for dark in [false, true] {
            let view = OutlineSidebar(model: model).frame(width: 230, height: 420).environment(\.softAccent, .lagoon)
            try snapshotWindow(view, size: CGSize(width: 230, height: 420), dark: dark,
                               name: "sidebar-\(dark ? "dark" : "light")")
        }
    }

    func testShortDocumentHasNoOutline() throws {
        let short = "# Note\n\nUn paragraphe court, sans autre titre.\n"
        let view = DocumentWindow(fileURL: nil, content: .text(DecodedText(text: short, encoding: .windows1252)))
            .defaultAppStorage(defaults)
        try snapshotWindow(view, size: CGSize(width: 800, height: 400), dark: false, name: "document-short")
    }

    func testPopoverAndSettings() throws {
        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            try snapshotView(ReadingOptionsView().defaultAppStorage(defaults), dark: dark, name: "popover-\(suffix)")
            try snapshotView(SettingsView().defaultAppStorage(defaults), dark: dark, name: "settings-\(suffix)")
        }
    }

    func testNotMarkdown() throws {
        let view = NotMarkdownView(fileName: "rapport-final.docx", fileURL: URL(fileURLWithPath: "/tmp/rapport-final.docx"),
                                   reason: .binary)
        try snapshotWindow(view, size: CGSize(width: 640, height: 420), dark: false, name: "not-markdown-light")
        try snapshotWindow(view, size: CGSize(width: 640, height: 420), dark: true, name: "not-markdown-dark")
    }

    /// The soft controls of the sheet C5, in every appearance.
    func testSoftControlsSheet() throws {
        for (appearance, name) in Self.appearances {
            try snapshotView(SoftControlsSheet(), appearance: appearance, name: "soft-controls-\(name)")
        }
    }

    /// The toolbar's contents as a strip: a window's toolbar is not drawn
    /// offscreen.
    func testToolbarStrip() throws {
        let url = try sampleFile()
        for (appearance, name) in Self.appearances {
            try snapshotView(ViewerToolbarStrip(fileURL: url), appearance: appearance, name: "viewer-toolbar-\(name)")
        }
    }

    /// Increase Contrast cannot be simulated offscreen: its appearances only
    /// serve for matching and cannot be created.
    static let appearances: [(NSAppearance.Name, String)] = [(.aqua, "light"), (.darkAqua, "dark")]

    // MARK: - Rendering

    /// Renders a view in a titled window, frame and toolbar included.
    private func snapshotWindow<V: View>(_ view: V, size: CGSize, dark: Bool, name: String) throws {
        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: 80, y: 80), size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "README.md"
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentViewController = NSHostingController(rootView: view)
        window.setContentSize(size)
        settle(window)
        let frameView = window.contentView?.superview ?? window.contentView!
        try write(frameView, appearance: window.appearance!, name: name)
        window.close()
    }

    /// Renders a view at its own size.
    private func snapshotView<V: View>(_ view: V, dark: Bool, name: String) throws {
        try snapshotView(view, appearance: dark ? .darkAqua : .aqua, name: name)
    }

    private func snapshotView<V: View>(_ view: V, appearance: NSAppearance.Name, name: String) throws {
        let hosting = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        hosting.appearance = NSAppearance(named: appearance)
        let window = NSWindow(contentRect: CGRect(x: 80, y: 80, width: 10, height: 10), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = hosting.appearance
        window.contentView = hosting
        window.setContentSize(hosting.fittingSize)
        settle(window)
        try write(hosting, appearance: hosting.appearance!, name: name)
        window.close()
    }

    private func settle(_ window: NSWindow) {
        for _ in 0..<6 {
            window.layoutIfNeeded()
            window.displayIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        }
    }

    private func write(_ view: NSView, appearance: NSAppearance, name: String) throws {
        var data: Data?
        appearance.performAsCurrentDrawingAppearance {
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            data = rep.representation(using: .png, properties: [:])
        }
        let png = try XCTUnwrap(data)
        try png.write(to: outputDirectory.appending(path: name + ".png"))
    }
}

/// The Viewer's toolbar contents laid out as in the document window: outline button and
/// title on the left, « Aa » and share, then « Modifier » apart at the right.
private struct ViewerToolbarStrip: View {
    let fileURL: URL
    @State private var visibility = NavigationSplitViewVisibility.all
    @State private var showsOptions = false

    var body: some View {
        HStack(spacing: 8) {
            OutlineToggle(columnVisibility: $visibility)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "README.md").font(.system(size: 12.5, weight: .semibold))
                Text(verbatim: "mangrove").font(.system(size: 11)).foregroundStyle(SoftColor.secondaryLabel)
            }
            Spacer()
            ReadingOptionsButton(isPresented: $showsOptions)
            ShareButton(fileURL: fileURL, exportPDF: {})
            EditButton(fileURL: fileURL, editor: EditorLauncher.shared)
                .padding(.leading, 6)
        }
        .padding(.horizontal, 10)
        .frame(width: 900, height: 40)
        .environment(\.softAccent, .lagoon)
    }
}

import AppKit
import KayakomaKit
import SwiftUI

/// What the menu bar can do with the document of the key window.
struct DocumentActions {
    let fileURL: URL?
    let exportPDF: @MainActor () -> Void
}

private struct DocumentActionsKey: FocusedValueKey {
    typealias Value = DocumentActions
}

extension FocusedValues {
    var documentActions: DocumentActions? {
        get { self[DocumentActionsKey.self] }
        set { self[DocumentActionsKey.self] = newValue }
    }
}

/// A document window: the rendered document, with its outline in a sidebar
/// that opens by itself for documents with several headings.
struct DocumentWindow: View {
    let fileURL: URL?
    let fileContent: MarkdownFile.Content

    @State private var model: DocumentModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var showsReadingOptions = false
    @State private var showsCheatSheet = false
    @State private var watcher: FileWatcher?
    /// Whether the outline is shown, kept with the window: "shown", "hidden",
    /// or empty until the window first decides.
    @SceneStorage("outlineState") private var outlineState = ""

    @AppStorage(Preferences.themeID) private var themeID = ThemeLibrary.defaultID
    @AppStorage(Preferences.fontSize) private var fontSize = Preferences.defaultFontSize
    @AppStorage(Preferences.maxLineCharacters) private var maxLineCharacters = Preferences.defaultMaxLineCharacters
    @AppStorage(Preferences.showsOutlineAutomatically) private var showsOutlineAutomatically = true
    @AppStorage(Preferences.reloadsOnChange) private var reloadsOnChange = true

    @ObservedObject private var editor = EditorLauncher.shared

    private let library = ThemeLibrary.shared

    init(fileURL: URL?, content: MarkdownFile.Content) {
        self.fileURL = fileURL
        self.fileContent = content
        _model = State(initialValue: DocumentModel(content: content))
    }

    var body: some View {
        Group {
            switch model.content {
            case .text:
                documentView
            case .notMarkdown(let reason):
                NotMarkdownView(fileName: fileName, fileURL: fileURL, reason: reason)
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .background(WindowSizer())
        .environment(\.softAccent, .lagoon)
        .navigationSubtitle(subtitle)
        .focusedSceneValue(\.showMarkdownCheatSheet, { showsCheatSheet = true })
        .sheet(isPresented: $showsCheatSheet) {
            ViewerCheatSheet(theme: theme, isPresented: $showsCheatSheet)
        }
        .onChange(of: fileContent) { _, content in model.load(content) }
        .task(id: WatchKey(url: fileURL, isOn: reloadsOnChange)) { startWatching() }
        .onDisappear { watcher?.stop() }
    }

    private var documentView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            OutlineSidebar(model: model)
                // The soft button below takes the place of the system's.
                .toolbar(removing: .sidebarToggle)
                .navigationSplitViewColumnWidth(min: 180, ideal: 230, max: 360)
        } detail: {
            RenderedMarkdownView(model: model, document: model.document, theme: theme, baseURL: baseURL)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .toolbar { toolbar }
        .onAppear(perform: restoreOutline)
        .onChange(of: columnVisibility) { _, visibility in
            outlineState = visibility == .detailOnly ? "hidden" : "shown"
        }
        .focusedSceneValue(\.documentActions, DocumentActions(fileURL: fileURL, exportPDF: exportPDF))
    }

    /// The native toolbar with soft icon buttons; « Modifier » keeps
    /// its own place at the right, as a pale coral tinted button.
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            OutlineToggle(columnVisibility: $columnVisibility)
        }
        .softToolbarItem()

        ToolbarItem(placement: .primaryAction) {
            ReadingOptionsButton(isPresented: $showsReadingOptions)
        }
        .softToolbarItem()

        ToolbarItem(placement: .primaryAction) {
            ShareButton(fileURL: fileURL, exportPDF: exportPDF)
        }
        .softToolbarItem()

        ToolbarItem(placement: .primaryAction) {
            if editor.editorURL != nil {
                EditButton(fileURL: fileURL, editor: editor)
            }
        }
        .softToolbarItem()
    }

    // MARK: - State

    private var theme: Theme {
        library.theme(id: themeID)
            .applyingReadingSettings(fontSize: fontSize, maxLineCharacters: maxLineCharacters)
    }

    private var baseURL: URL? { fileURL?.deletingLastPathComponent() }

    private var fileName: String {
        fileURL?.lastPathComponent ?? String(localized: "Sans titre")
    }

    /// The enclosing folder, and the encoding when UTF-8 had to be given up.
    private var subtitle: String {
        let folder = fileURL?.deletingLastPathComponent().lastPathComponent ?? ""
        guard let encoding = model.decodedText?.encoding, encoding.isFallback else { return folder }
        let name = encoding == .windows1252 ? "Windows-1252" : "Latin-1"
        let note = String(localized: "lu en \(name)")
        return folder.isEmpty ? note : "\(folder) · \(note)"
    }

    /// A new window shows the outline when the document has enough headings
    /// to need one; a restored window keeps what the reader chose.
    private func restoreOutline() {
        let shown: Bool
        switch outlineState {
        case "shown": shown = true
        case "hidden": shown = false
        default: shown = showsOutlineAutomatically && model.outline.count >= Preferences.outlineHeadingThreshold
        }
        columnVisibility = shown ? .all : .detailOnly
        outlineState = shown ? "shown" : "hidden"
    }

    private struct WatchKey: Equatable {
        let url: URL?
        let isOn: Bool
    }

    private func startWatching() {
        watcher?.stop()
        watcher = nil
        guard reloadsOnChange, let fileURL else { return }
        let model = model
        watcher = FileWatcher(url: fileURL) { model.reload(from: fileURL) }
    }

    private func exportPDF() {
        PDFExport.run(document: model.document, theme: theme, baseURL: baseURL,
                      fileName: fileName, window: NSApp.keyWindow)
    }
}

/// Shows or hides the outline, like the system's sidebar button.
struct OutlineToggle: View {
    @Binding var columnVisibility: NavigationSplitViewVisibility

    var body: some View {
        Button {
            withAnimation {
                columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
            }
        } label: {
            Label("Sommaire", systemImage: "sidebar.left")
        }
        .buttonStyle(SoftIconButtonStyle())
        .help("Afficher ou masquer le sommaire")
    }
}

/// « Aa »: the reading options in a popover.
struct ReadingOptionsButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("Réglages de lecture", systemImage: "textformat.size")
        }
        .buttonStyle(SoftIconButtonStyle())
        .help("Taille du texte, thème et apparence")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ReadingOptionsView()
        }
    }
}

struct ShareButton: View {
    let fileURL: URL?
    let exportPDF: @MainActor () -> Void

    var body: some View {
        Menu {
            if let fileURL {
                ShareLink(item: fileURL) {
                    Label("Partager…", systemImage: "square.and.arrow.up")
                }
                Divider()
            }
            Button("Exporter en PDF…", action: exportPDF)
        } label: {
            Label("Partager", systemImage: "square.and.arrow.up")
        }
        .menuStyle(.button)
        .buttonStyle(SoftIconButtonStyle())
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Partager ou exporter en PDF")
    }
}

/// « Modifier », shown only when the Editor is installed: a pale coral tinted
/// button, the only coloured element of the bar; same action as File > Open
/// in Editor (⌘E).
struct EditButton: View {
    let fileURL: URL?
    let editor: EditorLauncher

    var body: some View {
        Button {
            if let fileURL { editor.open(fileURL) }
        } label: {
            Label("Modifier", systemImage: "pencil")
        }
        .buttonStyle(SoftTintedButtonStyle(accent: .coral))
        .disabled(fileURL == nil)
        .help("Modifier dans Kayakoma Editor (⌘E)")
        .accessibilityLabel(Text("Modifier"))
    }
}

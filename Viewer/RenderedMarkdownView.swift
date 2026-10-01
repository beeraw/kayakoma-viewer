import KayakomaKit
import SwiftUI

/// The rendered document of a window, wired to its model: the model can
/// scroll it, and it reports the reader's position back.
struct RenderedMarkdownView: NSViewRepresentable {
    let model: DocumentModel
    let document: RenderedDocument
    let theme: Theme
    let baseURL: URL?

    func makeNSView(context: Context) -> MarkdownView {
        let view = MarkdownView()
        model.view = view
        view.onTopVisibleSourceLineChange = { [weak model] line in
            model?.topVisibleLineChanged(line)
        }
        return view
    }

    func updateNSView(_ view: MarkdownView, context: Context) {
        view.theme = theme
        view.baseURL = baseURL
        if view.document?.source != document.source {
            view.document = document
        }
    }
}

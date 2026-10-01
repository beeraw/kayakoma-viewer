import AppKit
import Quartz
import KayakomaKit

/// Space-bar preview of Markdown files in the Finder, with the engine's
/// default theme: the column keeps a readable width and comfortable margins
/// in the panel, and follows the light or dark appearance.
final class PreviewViewController: NSViewController, QLPreviewingController {
    private let markdownView = MarkdownView()

    override func loadView() {
        view = markdownView
        preferredContentSize = NSSize(width: 820, height: 640)
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let data = try Data(contentsOf: url)
        let text = try DecodedText(data: data).text
        // Relative images are read next to the file when the extension's
        // sandbox allows it; otherwise the engine shows their placeholder.
        markdownView.baseURL = url.deletingLastPathComponent()
        markdownView.document = RenderedDocument(source: text)
    }
}

import AppKit
import KayakomaKit
import Observation
import UniformTypeIdentifiers

/// A heading of the document, as listed in the outline.
struct OutlineItem: Identifiable, Equatable {
    /// The heading's GitHub-style anchor, unique in the document.
    let id: String
    let title: String
    let level: Int
    /// First source line of the heading, 1-based.
    let line: Int

    /// The headings of a document, in order.
    static func items(in document: RenderedDocument) -> [OutlineItem] {
        document.blocks.compactMap { block in
            guard case .heading(let level) = block.kind, let anchor = block.anchor else { return nil }
            return OutlineItem(
                id: anchor,
                title: title(ofHeading: block.sourceText),
                level: level,
                line: block.sourceLines?.lowerBound ?? 0
            )
        }
    }

    /// The text of a heading as a reader sees it, from its source: `#` marks
    /// or setext underline removed, inline Markdown resolved.
    static func title(ofHeading source: String) -> String {
        var lines = source.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        var text: String
        if let first = lines.first, first.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
            text = first.trimmingCharacters(in: .whitespaces)
            text = String(text.drop { $0 == "#" })
            // A closing sequence of `#` is decoration.
            if let range = text.range(of: #"\s+#+\s*$"#, options: .regularExpression) {
                text.removeSubrange(range)
            }
        } else {
            if lines.count > 1 { lines.removeLast() }
            text = lines.joined(separator: " ")
        }
        text = text.trimmingCharacters(in: .whitespaces)
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: text, options: options) {
            text = String(attributed.characters)
        }
        return text
    }
}

/// State of one document window: the text on display, its headings, and the
/// heading the reader is in.
@MainActor
@Observable
final class DocumentModel {
    private(set) var content: MarkdownFile.Content
    private(set) var document: RenderedDocument
    private(set) var outline: [OutlineItem]
    private(set) var wordCount: Int
    /// The heading at or above the top of the visible area.
    var currentHeadingID: String?

    /// The view showing the document, to scroll it from the outline.
    @ObservationIgnored weak var view: MarkdownView?
    @ObservationIgnored private var isFollowingOutline = false

    init(content: MarkdownFile.Content) {
        self.content = content
        self.document = RenderedDocument(source: "")
        self.outline = []
        self.wordCount = 0
        load(content)
    }

    var decodedText: DecodedText? {
        if case .text(let decoded) = content { decoded } else { nil }
    }

    func load(_ content: MarkdownFile.Content) {
        self.content = content
        let text = decodedText?.text ?? ""
        guard text != document.source else { return }
        document = RenderedDocument(source: text)
        outline = OutlineItem.items(in: document)
        wordCount = Self.countWords(in: text)
        if currentHeadingID == nil || !outline.contains(where: { $0.id == currentHeadingID }) {
            currentHeadingID = outline.first?.id
        }
    }

    /// Reads the file again after it changed on disk. A file that cannot be
    /// read for now (being replaced, for instance) keeps what is on display.
    func reload(from url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
        load(MarkdownFile.content(of: data, type: type))
    }

    /// Scrolls the document to a heading picked in the outline.
    func show(_ id: String) {
        currentHeadingID = id
        isFollowingOutline = true
        view?.scrollToAnchor(id)
        isFollowingOutline = false
    }

    /// Follows the reader's scrolling: the current heading is the last one
    /// that starts at or above the top visible line.
    func topVisibleLineChanged(_ line: Int) {
        guard !isFollowingOutline else { return }
        let id = outline.last { $0.line <= line }?.id ?? outline.first?.id
        if id != currentHeadingID { currentHeadingID = id }
    }

    var readingMinutes: Int { max(1, Int((Double(wordCount) / 230).rounded())) }

    /// Words of prose: runs of characters holding at least one letter or digit,
    /// so that Markdown marks do not count.
    static func countWords(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count { $0.contains { $0.isLetter || $0.isNumber } }
    }
}

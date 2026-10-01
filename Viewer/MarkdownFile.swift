import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}

/// Read-only Markdown file: the viewer never writes back to disk.
///
/// A file that cannot be read fails here, and the document system shows its
/// alert. A file that was read but is not Markdown (binary data, or text of
/// another kind such as source code) still opens, so that its window can say
/// why it cannot be displayed.
struct MarkdownFile: FileDocument {
    static let readableContentTypes: [UTType] = [.markdown, .plainText]
    static let writableContentTypes: [UTType] = []

    enum Content: Equatable {
        case text(DecodedText)
        /// Binary data, or a kind of text that is not meant to be read as Markdown.
        case notMarkdown(NotMarkdownReason)
    }

    enum NotMarkdownReason: Equatable {
        case binary
        case structuredText
    }

    let content: Content

    init(content: Content) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        content = Self.content(of: data, type: configuration.contentType)
    }

    /// Kinds of text that conform to plain text but are not prose.
    private static let structuredText: [UTType] = [.sourceCode, .script, .delimitedText, .json, .xml, .propertyList, .yaml]

    /// Markdown and plain text (`.txt`) are displayed; source code, CSV and
    /// other structured text are not.
    static func content(of data: Data, type: UTType?) -> Content {
        if let type, !type.conforms(to: .markdown), structuredText.contains(where: type.conforms(to:)) {
            return .notMarkdown(.structuredText)
        }
        guard let decoded = try? DecodedText(data: data) else { return .notMarkdown(.binary) }
        return .text(decoded)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission)
    }
}

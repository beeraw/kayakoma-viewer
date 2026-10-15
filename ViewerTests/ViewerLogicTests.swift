import AppKit
import KayakomaKit
import XCTest

final class ViewerLogicTests: XCTestCase {
    func testUTF8IsDecoded() throws {
        let decoded = try DecodedText(data: Data("\u{FEFF}# Été".utf8))
        XCTAssertEqual(decoded.text, "# Été")
        XCTAssertEqual(decoded.encoding, .utf8)
    }

    func testInvalidUTF8FallsBackToWindows1252() throws {
        // "Café" with é as the single byte 0xE9, and a Windows-1252 euro sign.
        let decoded = try DecodedText(data: Data([0x43, 0x61, 0x66, 0xE9, 0x20, 0x80]))
        XCTAssertEqual(decoded.text, "Café €")
        XCTAssertEqual(decoded.encoding, .windows1252)
        XCTAssertTrue(decoded.encoding.isFallback)
    }

    func testBytesUndefinedInWindows1252FallBackToLatin1() throws {
        let decoded = try DecodedText(data: Data([0x41, 0x81, 0xE9]))
        XCTAssertEqual(decoded.encoding, .latin1)
        XCTAssertEqual(decoded.text.unicodeScalars.count, 3)
    }

    func testBinaryDataIsRejected() {
        XCTAssertThrowsError(try DecodedText(data: Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00])))
    }

    func testFileKinds() {
        let text = Data("# Notes".utf8)
        XCTAssertEqual(MarkdownFile.content(of: text, type: .plainText), .text(DecodedText(text: "# Notes", encoding: .utf8)))
        XCTAssertEqual(MarkdownFile.content(of: text, type: .swiftSource), .notMarkdown(.structuredText))
        XCTAssertEqual(MarkdownFile.content(of: Data([0, 1, 2]), type: .markdown), .notMarkdown(.binary))
    }

    func testOutlineTitles() {
        XCTAssertEqual(OutlineItem.title(ofHeading: "## Getting *started* ##"), "Getting started")
        XCTAssertEqual(OutlineItem.title(ofHeading: "# The `--station` option"), "The --station option")
        XCTAssertEqual(OutlineItem.title(ofHeading: "Setext title\n============"), "Setext title")
        XCTAssertEqual(OutlineItem.title(ofHeading: "### [Guide](docs/guide.md)"), "Guide")
    }

    @MainActor
    func testCurrentHeadingFollowsScrolling() {
        let source = "# One\n\ntext\n\n## Two\n\ntext\n\n## Three\n"
        let model = DocumentModel(content: .text(DecodedText(text: source, encoding: .utf8)))
        XCTAssertEqual(model.outline.map(\.id), ["one", "two", "three"])
        XCTAssertEqual(model.currentHeadingID, "one")
        model.topVisibleLineChanged(6)
        XCTAssertEqual(model.currentHeadingID, "two")
        model.topVisibleLineChanged(9)
        XCTAssertEqual(model.currentHeadingID, "three")
    }

    /// The find actions of the menu and the toolbar reach the document's text.
    @MainActor
    func testFindOpensTheFindBar() throws {
        let source = "# Tides\n\nThe reef at low tide.\n\nThe lagoon at high tide.\n"
        let model = DocumentModel(content: .text(DecodedText(text: source, encoding: .utf8)))
        let view = MarkdownView(frame: NSRect(x: 0, y: 0, width: 480, height: 360))
        view.document = model.document
        model.view = view
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        defer { window.close() }
        let textView = try XCTUnwrap(view.contentTextView)
        let scrollView = try XCTUnwrap(textView.enclosingScrollView)
        XCTAssertFalse(scrollView.isFindBarVisible)
        model.performFind(.showFindInterface)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertTrue(scrollView.isFindBarVisible)
    }

    @MainActor
    func testBuiltInThemesAreDistinct() {
        let entries = ThemeLibrary(folderURL: URL(fileURLWithPath: "/nonexistent-themes")).builtInEntries
        XCTAssertEqual(entries.count, 6)
        XCTAssertEqual(Set(entries.map(\.id)).count, 6)
        let themes = entries.compactMap(\.theme)
        XCTAssertEqual(themes.count, 6)
        for (index, theme) in themes.enumerated() {
            XCTAssertFalse(themes[..<index].contains(theme), "\(entries[index].id) repeats another theme")
        }
    }

    func testThemeErrorNamesTheKey() {
        let result = ThemeLibrary.decodeTheme(Data(#"{ "headings": { "2": { "wieght": "bold" } } }"#.utf8))
        guard case .failure(let error) = result else { return XCTFail("decoded an invalid theme") }
        XCTAssertTrue(error.message.contains("wieght"), error.message)

        let colour = ThemeLibrary.decodeTheme(Data(##"{ "textColor": { "light": "#12" } }"##.utf8))
        guard case .failure(let colourError) = colour else { return XCTFail("decoded an invalid colour") }
        XCTAssertTrue(colourError.message.contains("textColor"), colourError.message)

        let syntax = ThemeLibrary.decodeTheme(Data("{ fontSize: 3".utf8))
        guard case .failure = syntax else { return XCTFail("decoded invalid JSON") }
    }

    func testPartialThemeKeepsViewerLinks() throws {
        let theme = try ThemeLibrary.decodeTheme(Data(#"{ "fontSize": 16 }"#.utf8)).get()
        XCTAssertEqual(theme.fontSize, 16)
        XCTAssertEqual(theme.linkColor, Theme.lagoonLink)
        let blue = try ThemeLibrary.decodeTheme(Data(#"{ "linkColor": "link" }"#.utf8)).get()
        XCTAssertEqual(blue.linkColor, .system(.link))
    }

    func testReadingSettingsScaleTheTheme() {
        let theme = Theme.viewerDefault.applyingReadingSettings(fontSize: 21, maxLineCharacters: 80)
        XCTAssertEqual(theme.fontSize, 21)
        XCTAssertEqual(theme.headings[level: 1].size, 42)
        XCTAssertEqual(theme.maxLineWidth, 840)
    }

    func testTopOfLineWidthRangeLiftsTheLimit() {
        let theme = Theme.viewerDefault.applyingReadingSettings(
            fontSize: 15, maxLineCharacters: Preferences.maxLineCharactersRange.upperBound)
        XCTAssertNil(theme.maxLineWidth)
    }
}

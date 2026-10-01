import Foundation

/// Text read from a file, with the encoding that made sense of it.
struct DecodedText: Equatable, Sendable {
    enum Encoding: Equatable, Sendable {
        case utf8
        case utf16
        /// UTF-8 was invalid; the bytes were read as Windows-1252.
        case windows1252
        /// UTF-8 and Windows-1252 both failed; the bytes were read as ISO Latin-1, which never fails.
        case latin1

        /// Whether the encoding was a guess after UTF-8 failed.
        var isFallback: Bool { self == .windows1252 || self == .latin1 }
    }

    let text: String
    let encoding: Encoding

    /// Thrown when the data is not text at all.
    struct BinaryDataError: Error {}

    /// Decodes UTF-8 (with or without a byte order mark) or UTF-16 with a byte
    /// order mark. Invalid UTF-8 falls back to Windows-1252, then Latin-1,
    /// rather than failing. Data holding NUL bytes outside UTF-16 is binary.
    init(data: Data) throws {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]),
           let text = String(data: data, encoding: .utf16) {
            self.init(text: text.droppingByteOrderMark, encoding: .utf16)
            return
        }
        if Self.looksBinary(data) { throw BinaryDataError() }
        if let text = String(data: data, encoding: .utf8) {
            self.init(text: text.droppingByteOrderMark, encoding: .utf8)
        } else if let text = String(data: data, encoding: .windowsCP1252) {
            self.init(text: text, encoding: .windows1252)
        } else {
            // Every byte is a Latin-1 character, so this cannot fail.
            let text = String(data: data, encoding: .isoLatin1) ?? String(String.UnicodeScalarView(data.map(Unicode.Scalar.init)))
            self.init(text: text, encoding: .latin1)
        }
    }

    init(text: String, encoding: Encoding) {
        self.text = text
        self.encoding = encoding
    }

    /// Text never holds NUL bytes; looking at the start of the file is enough.
    private static func looksBinary(_ data: Data) -> Bool {
        data.prefix(8192).contains(0)
    }
}

private extension String {
    var droppingByteOrderMark: String {
        hasPrefix("\u{FEFF}") ? String(dropFirst()) : self
    }
}

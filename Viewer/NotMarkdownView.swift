import AppKit
import SwiftUI

/// Shown in place of the document when the file is not Markdown.
struct NotMarkdownView: View {
    let fileName: String
    let fileURL: URL?
    let reason: MarkdownFile.NotMarkdownReason

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(.secondary)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .orange)
                        .offset(x: 6, y: 4)
                }
                .padding(.bottom, 4)

            Text("Impossible d'afficher « \(fileName) »")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(explanation)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            HStack(spacing: 10) {
                if let fileURL {
                    Button("Afficher dans le Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                    }
                }
                Button("Ouvrir un autre fichier…") {
                    NSDocumentController.shared.openDocument(nil)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var explanation: LocalizedStringKey {
        switch reason {
        case .binary:
            "Ce fichier n'est pas du texte. Kayakoma Viewer lit les fichiers Markdown (.md, .markdown) et le texte brut."
        case .structuredText:
            "Ce fichier contient du texte qui n'est pas du Markdown. Kayakoma Viewer lit les fichiers Markdown (.md, .markdown) et le texte brut."
        }
    }
}

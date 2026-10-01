import SwiftUI

/// Table of contents built from the document's headings; the heading the
/// reader is in stays marked as the document scrolls. Compact rows (C5):
/// 24 pt, 12.5 pt text, the current heading on the pale lagoon tint.
struct OutlineSidebar: View {
    let model: DocumentModel
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if model.outline.isEmpty {
                ContentUnavailableView("Aucun titre", systemImage: "list.bullet",
                                       description: Text("Ce document n'a pas de titres."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Sommaire")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SoftColor.secondaryLabel)
                            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            .accessibilityAddTraits(.isHeader)
                        ForEach(model.outline) { item in
                            OutlineRow(item: item, indent: CGFloat(item.level - topLevel) * 12,
                                       isTopLevel: item.level == topLevel,
                                       isCurrent: item.id == model.currentHeadingID) {
                                model.show(item.id)
                                isFocused = true
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .focusable()
                .focused($isFocused)
                .focusEffectDisabled()
                // As in a list: the arrow keys move to the previous or next heading.
                .onKeyPress(.upArrow) { step(by: -1) }
                .onKeyPress(.downArrow) { step(by: 1) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
    }

    private var topLevel: Int {
        model.outline.map(\.level).min() ?? 1
    }

    private func step(by offset: Int) -> KeyPress.Result {
        let outline = model.outline
        guard !outline.isEmpty else { return .ignored }
        let index = outline.firstIndex { $0.id == model.currentHeadingID } ?? 0
        let next = min(max(index + offset, 0), outline.count - 1)
        if next != index || model.currentHeadingID == nil { model.show(outline[next].id) }
        return .handled
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text("\(model.wordCount) mots")
            Text(verbatim: "·")
            Text("\(model.readingMinutes) min de lecture")
        }
        .font(.system(size: 11))
        .foregroundStyle(SoftColor.secondaryLabel)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// A heading of the outline; a click scrolls the document to it.
private struct OutlineRow: View {
    let item: OutlineItem
    let indent: CGFloat
    let isTopLevel: Bool
    let isCurrent: Bool
    let action: () -> Void

    @Environment(\.softAccent) private var accent
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(item.title)
                .font(.system(size: 12.5, weight: isCurrent ? .semibold : isTopLevel ? .medium : .regular))
                .foregroundStyle(isCurrent ? accent.text : SoftColor.label)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.leading, 8 + indent)
                .padding(.trailing, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: SoftMetrics.segmentRadius, style: .continuous)
                        .fill(isCurrent ? accent.tint : isHovered ? SoftColor.hover : .clear)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

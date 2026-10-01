import KayakomaKit
import SwiftUI

/// The themes as tiles on a soft track, each sample drawn in its own colours
/// and face; the chosen theme sits on the white pill.
struct ThemeSwatches: View {
    let entries: [ThemeEntry]
    @Binding var selection: String
    var columns = 5
    var tileWidth: CGFloat = 92

    var body: some View {
        SoftTileTrack(items: entries, columns: columns, tileWidth: tileWidth,
                      isSelected: { $0.id == selection },
                      action: select,
                      accessibilityLabel: { Text($0.name) }) { entry, isSelected in
            ThemeTile(entry: entry, isSelected: isSelected)
        }
    }

    private func select(_ entry: ThemeEntry) {
        switch entry.result {
        case .success: selection = entry.id
        case .failure(let error): ThemeLibrary.presentError(error, themeName: entry.name)
        }
    }
}

private struct ThemeTile: View {
    let entry: ThemeEntry
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            sample
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.15), lineWidth: 0.5)
                }
            Text(entry.name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .help(helpText)
    }

    @ViewBuilder private var sample: some View {
        if let theme = entry.theme {
            let ink = Color(nsColor: theme.textColor.nsColor)
            ZStack(alignment: .topLeading) {
                Color(nsColor: theme.backgroundColor.nsColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Titre")
                        .font(theme.fontFamily.map { .custom($0, size: 10.5).bold() } ?? .system(size: 10.5, weight: .bold))
                        .foregroundStyle(ink)
                        .padding(.bottom, 1)
                    Capsule().fill(ink.opacity(0.45)).frame(height: 2.5)
                    Capsule().fill(ink.opacity(0.45)).frame(height: 2.5)
                        .padding(.trailing, 18)
                }
                .padding(EdgeInsets(top: 6, leading: 7, bottom: 6, trailing: 7))
            }
        } else {
            ZStack {
                Color(nsColor: .quaternarySystemFill)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var helpText: Text {
        if case .failure(let error) = entry.result { Text(verbatim: error.message) } else { Text(entry.name) }
    }
}

/// Content of the « Aa » popover: text size, theme, appearance, with the
/// same soft controls as the settings.
struct ReadingOptionsView: View {
    @AppStorage(Preferences.fontSize) private var fontSize = Preferences.defaultFontSize
    @AppStorage(Preferences.themeID) private var themeID = ThemeLibrary.defaultID
    @AppStorage(Preferences.appearance) private var appearance = AppearanceMode.auto
    var library = ThemeLibrary.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            caption("Taille du texte")
            HStack(spacing: 8) {
                Image(systemName: "textformat.size.smaller")
                    .foregroundStyle(SoftColor.iconIdle)
                Slider(value: $fontSize.rounded(toMultipleOf: 1), in: Preferences.fontSizeRange) {
                    Text("Taille du texte")
                }
                .labelsHidden()
                .controlSize(.small)
                Image(systemName: "textformat.size.larger")
                    .foregroundStyle(SoftColor.iconIdle)
            }

            caption("Thème")
            ScrollView(.horizontal, showsIndicators: false) {
                ThemeSwatches(entries: library.entries, selection: $themeID, columns: 3, tileWidth: 80)
            }

            caption("Apparence")
            AppearanceSwitcher(appearance: $appearance)
        }
        .padding(14)
        .frame(width: 290, alignment: .leading)
        .environment(\.softAccent, .lagoon)
    }

    private func caption(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SoftColor.secondaryLabel)
    }
}

extension Binding where Value == Double {
    /// Rounds what a slider sets, without the tick marks a stepped slider draws.
    func rounded(toMultipleOf step: Double) -> Binding<Double> {
        Binding(get: { wrappedValue }, set: { wrappedValue = ($0 / step).rounded() * step })
    }
}

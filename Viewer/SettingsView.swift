import SwiftUI

extension AppearanceMode {
    var symbol: String {
        switch self {
        case .auto: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

/// Auto / Clair / Sombre on a soft track.
struct AppearanceSwitcher: View {
    @Binding var appearance: AppearanceMode

    var body: some View {
        SoftSegmentedControl(Text("Mode"), selection: $appearance,
                             segments: AppearanceMode.allCases.map { SoftSegment($0, title: Text($0.title), systemImage: $0.symbol) },
                             content: .labels)
    }
}

/// A row with a switch on the right; the row's title is the switch's label.
struct SoftToggleRow: View {
    let title: Text
    @Binding var isOn: Bool

    init(_ title: Text, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    var body: some View {
        SoftRow(title, announcesTitle: false) {
            Toggle(isOn: $isOn) { title }
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }
}

/// The settings window: one grouped form in the compact soft style.
struct SettingsView: View {
    @AppStorage(Preferences.appearance) private var appearance = AppearanceMode.auto
    @AppStorage(Preferences.opensWindowsLarge) private var opensWindowsLarge = true
    @AppStorage(Preferences.themeID) private var themeID = ThemeLibrary.defaultID
    @AppStorage(Preferences.fontSize) private var fontSize = Preferences.defaultFontSize
    @AppStorage(Preferences.maxLineCharacters) private var maxLineCharacters = Preferences.defaultMaxLineCharacters
    @AppStorage(Preferences.showsOutlineAutomatically) private var showsOutlineAutomatically = true
    @AppStorage(Preferences.reloadsOnChange) private var reloadsOnChange = true
    var library = ThemeLibrary.shared

    var body: some View {
        VStack(spacing: 0) {
            SoftSectionHeader(Text("Apparence"))
            SoftGroup {
                SoftRow(Text("Mode")) {
                    AppearanceSwitcher(appearance: $appearance)
                }
                SoftRowDivider()
                SoftToggleRow(Text("Ouvrir les fenêtres en grand"), isOn: $opensWindowsLarge)
            }

            SoftSectionHeader(Text("Thème"))
            SoftGroup(padding: EdgeInsets(top: 10, leading: 10, bottom: 2, trailing: 10)) {
                ThemeSwatches(entries: library.entries, selection: $themeID)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                SoftRow(Text("Thème personnalisé"), help: Text("Fichier JSON partiel, complété par le thème par défaut")) {
                    Button("Ouvrir…") { library.chooseAndImportTheme() }
                        .controlSize(.small)
                        .accessibilityLabel(Text("Ouvrir un fichier de thème…"))
                        .help("Ouvrir un fichier de thème…")
                }
                .padding(.horizontal, 2)
                SoftRowDivider()
                SoftRow(Text("Dossier des thèmes")) {
                    Button("Ouvrir…") { library.revealFolder() }
                        .controlSize(.small)
                        .accessibilityLabel(Text("Ouvrir le dossier des thèmes"))
                        .help("Ouvrir le dossier des thèmes")
                }
                .padding(.horizontal, 2)
            }

            SoftSectionHeader(Text("Texte"))
            SoftGroup {
                SoftRow(Text("Taille")) {
                    SoftStepper(title: Text("Taille"), value: $fontSize, range: Preferences.fontSizeRange,
                                valueLabel: Text("\(Int(fontSize)) pt"))
                }
                SoftRowDivider()
                SoftRow(Text("Largeur maximale de ligne")) {
                    HStack(spacing: 10) {
                        Slider(value: $maxLineCharacters.rounded(toMultipleOf: 5), in: Preferences.maxLineCharactersRange) {
                            Text("Largeur maximale de ligne")
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: 140)
                        Text("\(Int(maxLineCharacters)) car.")
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(SoftColor.secondaryLabel)
                            .frame(minWidth: 48, alignment: .trailing)
                    }
                }
            }

            SoftSectionHeader(Text("Général"))
            SoftGroup {
                SoftToggleRow(Text("Afficher le sommaire à partir de 4 titres"), isOn: $showsOutlineAutomatically)
                SoftRowDivider()
                SoftToggleRow(Text("Recharger quand le fichier change sur le disque"), isOn: $reloadsOnChange)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 20, bottom: 20, trailing: 20))
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
        .background(SoftColor.chrome)
        .environment(\.softAccent, .lagoon)
        .onAppear { library.reload() }
    }
}

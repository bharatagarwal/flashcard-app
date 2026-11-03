import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct AppearanceMenu: View {
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    var body: some View {
        Menu {
            Picker("Theme", selection: $appearance) {
                ForEach(AppAppearance.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
        } label: {
            Image(systemName: appearance.symbol)
                .font(.system(size: 20))
                .foregroundStyle(Palette.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Theme")
        .accessibilityValue(appearance.title)
        .accessibilityHint("Choose System, Light, or Dark")
    }
}

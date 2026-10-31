import SwiftUI

/// How Shortie's windows look. Retro uses pixel icons and Shortie's violet, like
/// the website; Modern uses glossy icon tiles and your system accent colour.
enum Look: String, CaseIterable, Identifiable {
    case retro, modern

    var id: Self { self }

    var title: String {
        switch self {
        case .retro: "Retro"
        case .modern: "Modern"
        }
    }

    static var current: Look {
        Look(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.look) ?? "") ?? .retro
    }

    /// Retro tints controls violet. Modern leaves them in your system accent colour.
    var tint: Color? {
        self == .retro ? Color("Violet") : nil
    }
}

/// A Retro / Modern switch, used in General and in the welcome window.
struct LookPicker: View {
    @AppStorage(DefaultsKey.look) private var look = Look.retro

    var body: some View {
        Picker("Look", selection: $look) {
            ForEach(Look.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}

extension View {
    /// Applies the chosen look's accent colour to a whole window.
    func lookTint() -> some View {
        modifier(LookTint())
    }
}

private struct LookTint: ViewModifier {
    @AppStorage(DefaultsKey.look) private var look = Look.retro

    func body(content: Content) -> some View {
        content.tint(look.tint)
    }
}

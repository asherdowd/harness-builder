//
//  SettingsSheet.swift
//  Harness Builder
//
//  App settings: appearance, a placeholder for Build with AI, and about.
//

import SwiftUI

/// How the app picks light or dark. System follows the phone.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// nil lets the phone decide.
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Reads a saved value; anything unknown means System.
    static func from(_ raw: String) -> AppearanceMode {
        AppearanceMode(rawValue: raw) ?? .system
    }
}

struct SettingsSheet: View {
    let onClose: () -> Void

    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    private var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Button("Done", action: onClose)
                        .font(.system(size: 14, weight: .semibold))
                        .tint(Palette.amberInk)
                }

                header("APPEARANCE")
                SegRow(options: AppearanceMode.allCases.map { ($0.rawValue, $0.label) },
                       selection: $appearanceRaw)
                Text("System follows your phone's light or dark setting.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.nameText)

                header("BUILD WITH AI")
                row(title: "Anthropic key",
                    sub: "Coming soon. You'll add your own key here to have a plug or harness drafted from a description.",
                    icon: "lock")

                header("ABOUT")
                row(title: "Version", sub: version, icon: nil)
                Text("Your harnesses are stored on this device only. There is no account.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.nameText)
            }
            .padding(16)
        }
        .background(Palette.sheetBg)
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Palette.nameText)
            .padding(.top, 8)
    }

    private func row(title: String, sub: String, icon: String?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.nameText)
            }
            Spacer()
            if let icon {
                Image(systemName: icon).foregroundStyle(Palette.nameText)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.chipFill))
    }
}

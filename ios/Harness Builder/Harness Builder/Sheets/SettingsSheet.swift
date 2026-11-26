//
//  SettingsSheet.swift
//  Harness Builder
//
//  App settings: appearance, your data, Build with AI (key and model), and about.
//

import SwiftUI
import UniformTypeIdentifiers

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
    let store: HarnessStore
    let onClose: () -> Void

    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    @State private var backupURL: URL?
    @State private var importing = false
    @State private var pending: AppState?
    @State private var confirmRestore = false
    @State private var dataMessage: String?
    @State private var dataError: String?

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
                Text("System follows this device's light or dark setting.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.nameText)

                header("YOUR DATA")
                dataSection

                header("BUILD WITH AI")
                AIKeySection()

                header("ABOUT")
                row(title: "Version", sub: version, icon: nil)
                Text("Your harnesses are stored on this device only. There is no account.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.nameText)
            }
            .padding(16)
        }
        .background(Palette.sheetBg)
        .onAppear { makeBackup() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            readBackup(result)
        }
        .alert("Replace everything?", isPresented: $confirmRestore) {
            Button("Cancel", role: .cancel) { pending = nil }
            Button("Replace", role: .destructive) {
                if let pending { store.restore(pending) }
                pending = nil
                dataMessage = "Restored. Your previous data was kept as a copy on this device."
                makeBackup()
            }
        } message: {
            Text(restoreSummary)
        }
    }

    private var restoreSummary: String {
        guard let p = pending else { return "" }
        let plugs = p.harnesses.reduce(0) { $0 + $1.connectors.count }
        return "This backup has \(p.harnesses.count) harnesses and \(plugs) plugs. They will replace what is in the app now."
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let backupURL {
                ShareLink(item: backupURL) {
                    Label("Back up to Files or share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.chipFill))
                }
            }
            Button {
                dataMessage = nil
                dataError = nil
                importing = true
            } label: {
                Label("Restore from a backup", systemImage: "arrow.down.doc")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.chipFill))
            }
            .buttonStyle(.plain)
            Text("A backup is one file with every harness. Save it to Files or iCloud Drive, and restore it on this or another device.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.nameText)
            if let dataMessage {
                Text(dataMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.text)
            }
            if let dataError {
                Text(dataError)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.warnStrong)
            }
        }
    }

    private func makeBackup() {
        backupURL = try? store.writeBackupFile()
    }

    private func readBackup(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            dataError = error.localizedDescription
        case .success(let url):
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                pending = try HarnessStore.decodeBackup(data)
                confirmRestore = true
            } catch {
                dataError = "That file isn't a Harness Builder backup. (\(error.localizedDescription))"
            }
        }
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

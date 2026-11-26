//
//  AIKeySection.swift
//  Harness Builder
//
//  The "Build with AI" part of Settings: the user's Anthropic key, a test,
//  the model, and a plain statement of what leaves the device.
//

import SwiftUI

struct AIKeySection: View {
    @AppStorage(AIModels.storageKey) private var modelRaw = AIModels.defaultID

    @State private var saved: String?
    @State private var entry = ""
    @State private var replacing = false
    @State private var confirmRemove = false
    @State private var testing = false
    @State private var message: String?
    @State private var failed = false

    private let keychain = KeychainStore()

    private var model: String { AIModels.resolve(modelRaw) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let saved, !replacing {
                savedCard(saved)
            } else {
                entryCard
            }

            Text("MODEL")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.nameText)
                .padding(.top, 6)
            SegRow(options: AIModels.all.map { ($0.id, $0.label) }, selection: Binding(
                get: { model },
                set: { modelRaw = $0 }
            ))
            if let blurb = AIModels.all.first(where: { $0.id == model })?.blurb {
                Text(blurb)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.nameText)
            }

            Text("WHAT LEAVES YOUR DEVICE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.nameText)
                .padding(.top, 6)
            Text("Only the open harness, the names of plugs on your other harnesses, and what you type. It goes straight to Anthropic with your key, with no server in between. Your key stays in this device's Keychain and is never in a backup or an export. You pay Anthropic for each use. The app works fully without a key.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.chipText)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.field))
        }
        .onAppear { saved = keychain.read() }
        .confirmationDialog("Remove your key?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove key", role: .destructive) {
                keychain.delete()
                saved = nil
                replacing = false
                message = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The assistant stops working until you add a key again.")
        }
    }

    // MARK: pieces

    private var entryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField("Paste your Anthropic key", text: $entry)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.field))
                .foregroundStyle(Palette.text)
            HStack(spacing: 8) {
                button("Save key", prominent: true) { save() }
                if replacing {
                    button("Cancel") { replacing = false; entry = ""; message = nil }
                }
            }
            if let message {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(failed ? Palette.warnStrong : Palette.text)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.field))
    }

    private func savedCard(_ key: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(KeychainStore.masked(key))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("Saved on this device")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.amberInk)
            }
            HStack(spacing: 8) {
                button(testing ? "Testing…" : "Test key") { test(key) }
                    .disabled(testing)
                button("Replace") { replacing = true; entry = ""; message = nil }
                Button { confirmRemove = true } label: {
                    Text("Remove")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.warnText)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.warnFill))
                }
                .buttonStyle(.plain)
            }
            if let message {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(failed ? Palette.warnStrong : Palette.text)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.field))
    }

    private func button(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(prominent ? Palette.amberText : Palette.chipText)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(RoundedRectangle(cornerRadius: 11).fill(prominent ? Palette.amber : Palette.chipFill))
        }
        .buttonStyle(.plain)
    }

    // MARK: actions

    private func save() {
        do {
            try keychain.save(entry)
            saved = keychain.read()
            entry = ""
            replacing = false
            failed = false
            message = "Saved. Use Test key to check it works."
        } catch {
            failed = true
            message = error.localizedDescription
        }
    }

    private func test(_ key: String) {
        testing = true
        message = nil
        Task {
            do {
                try await AnthropicClient(key: key, model: model).testKey()
                failed = false
                message = "The key works."
            } catch {
                failed = true
                message = error.localizedDescription
            }
            testing = false
        }
    }
}

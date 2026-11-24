//
//  AddHarnessSheet.swift
//  Harness Builder
//
//  "Add a harness": start empty, or start from a template (an editable copy).
//

import SwiftUI

struct AddHarnessSheet: View {
    let store: HarnessStore
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Add a harness")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Cancel", action: onClose)
                        .font(.system(size: 14, weight: .semibold))
                        .tint(Palette.amber)
                }

                row(title: "Create a harness", sub: "Start empty and add your own plugs.", enabled: true, note: nil) {
                    store.createHarness()
                    onClose()
                }

                Text("START FROM A TEMPLATE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.nameText)
                    .padding(.top, 8)
                Text("A template is your own copy. Rename it, change any plug, or delete it.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.nameText)

                ForEach(store.templates) { t in
                    let can = store.canAdd(t)
                    row(title: t.label, sub: t.sub, enabled: can, note: can ? nil : "Already added") {
                        store.addTemplate(key: t.key)
                        onClose()
                    }
                }
            }
            .padding(16)
        }
        .background(Color(hex: 0x1b1f26))
    }

    private func row(title: String, sub: String, enabled: Bool, note: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.nameText)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if let note {
                    Text(note)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.nameText)
                } else {
                    Image(systemName: "chevron.right").foregroundStyle(Palette.nameText)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.chipFill))
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

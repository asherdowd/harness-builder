//
//  HarnessMenuSheet.swift
//  Harness Builder
//
//  The "⋯" menu for the open harness: rename, delete (with a warning that
//  says what would be lost).
//

import SwiftUI

struct HarnessMenuSheet: View {
    let store: HarnessStore
    let harnessID: String
    let onClose: () -> Void

    @State private var name = ""
    @State private var loaded = false
    @State private var confirmDelete = false

    private var harness: Harness? { store.harness(id: harnessID) }

    /// Plugs in this harness, wires set on them, and plugs elsewhere linked to them.
    private var loss: (plugs: Int, wires: Int, links: Int) {
        guard let h = harness else { return (0, 0, 0) }
        let ids = Set(h.connectors.map(\.id))
        let wires = h.connectors.flatMap(\.flatPins).filter { $0.pin.populated }.count
        let links = store.harnesses
            .filter { $0.id != h.id }
            .flatMap(\.connectors)
            .filter { c in c.link.map { ids.contains($0.cid) } ?? false }
            .count
        return (h.connectors.count, wires, links)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Harness")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button("Done", action: onClose)
                    .font(.system(size: 14, weight: .semibold))
                    .tint(Palette.amber)
            }

            Text("Name")
                .font(.system(size: 13))
                .foregroundStyle(Palette.nameText)
            HStack(spacing: 8) {
                TextField("Harness name", text: $name)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: 0x1d2128)))
                    .foregroundStyle(.white)
                    .submitLabel(.done)
                    .onSubmit(saveName)
                Button("Rename", action: saveName)
                    .buttonStyle(.bordered)
                    .tint(Palette.amber)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || name == harness?.title)
            }

            if !store.isBlank {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Text("Delete this harness")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.bordered)
                .padding(.top, 6)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(hex: 0x1b1f26))
        .onAppear {
            if !loaded {
                name = harness?.title ?? ""
                loaded = true
            }
        }
        .alert("Delete this harness?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete harness", role: .destructive) {
                store.deleteHarness(id: harnessID)
                onClose()
            }
        } message: {
            let l = loss
            Text("\"\(harness?.title ?? "This harness")\" and its \(l.plugs) plugs with \(l.wires) wires would be deleted for good." +
                 (l.links > 0 ? " \(l.links) component plugs linked to plugs here would lose their link." : ""))
        }
    }

    private func saveName() {
        store.renameHarness(id: harnessID, to: name)
    }
}

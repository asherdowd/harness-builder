//
//  PlugSheet.swift
//  Harness Builder
//
//  The bottom sheet for one plug: numbered pinout, wire list, component link
//  cards, and Edit / move / Remove.
//  Tapping a wire selects it; Edit then opens the wizard on that pin.
//

import SwiftUI

struct PlugSheet: View {
    let store: HarnessStore
    let plugID: String
    /// Open another plug (switches to its harness tab and selects it).
    let onJump: (PlugRef) -> Void
    /// The plug was removed.
    let onRemoved: () -> Void
    /// Open the wizard to edit this plug, on the selected pin (0-based) if there is one.
    let onEdit: (Connector, Int?) -> Void
    /// Open the link picker for this (component) plug.
    let onLink: (Connector) -> Void

    @State private var confirmRemove = false
    @State private var selectedPin: Int?

    var body: some View {
        if let ref = store.plug(id: plugID) {
            content(ref)
        } else {
            Color.clear
        }
    }

    private func content(_ ref: PlugRef) -> some View {
        let c = ref.connector
        let siblings = ref.harness.connectors
        let index = siblings.firstIndex { $0.id == c.id } ?? 0
        let target = store.linkTarget(of: c)
        let linkedFrom = store.linkedComponents(to: c.id)

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(c)

                if ref.harness.kind == .component {
                    linkSection(c, target: target)
                }
                ForEach(linkedFrom) { other in
                    linkCard(label: "Linked component", ref: other, onJump: onJump)
                }

                PinoutView(connector: c)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.bg))

                wireList(c, target: target?.connector)

                actions(c, index: index, count: siblings.count)
            }
            .padding(16)
        }
        .background(Color(hex: 0x1b1f26))
        .confirmationDialog("Remove this plug?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                store.removePlug(id: c.id)
                onRemoved()
            }
        }
    }

    // MARK: pieces

    private func header(_ c: Connector) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(c.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if c.noRef != true {
                    Text("Ref \(c.id)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.nameText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Palette.chipFill))
                }
            }
            Text("\(c.pinCount) pins")
                .font(.system(size: 13))
                .foregroundStyle(Palette.nameText)
            if let d = c.description, !d.isEmpty {
                Text(d)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.chipText)
                    .padding(.top, 2)
            }
        }
    }

    /// Component plugs: shows what the plug is linked to and lets you change it.
    private func linkSection(_ c: Connector, target: PlugRef?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let target {
                linkCard(label: "Linked to", ref: target, onJump: onJump)
            } else {
                Text("Not linked yet. Link it to the plug on another harness that it connects to.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.nameText)
            }
            HStack(spacing: 8) {
                Button(target == nil ? "Link to a plug" : "Change link") { onLink(c) }
                if target != nil {
                    Button("Unlink") { store.setLink(from: c.id, to: nil) }
                }
            }
            .buttonStyle(.bordered)
            .tint(Palette.amber)
        }
    }

    private func linkCard(label: String, ref: PlugRef, onJump: @escaping (PlugRef) -> Void) -> some View {
        Button {
            onJump(ref)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.amber)
                    Text(ref.connector.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(ref.harness.tabLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.nameText)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Palette.nameText)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.chipFill))
        }
        .buttonStyle(.plain)
    }

    private func wireList(_ c: Connector, target: Connector?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("WIRES")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.nameText)
                .padding(.bottom, 6)
            ForEach(c.flatPins, id: \.number) { fp in
                wireRow(fp, target: target)
                    .contentShape(Rectangle())
                    .background(selectedPin == fp.number - 1 ? Palette.amber.opacity(0.14) : Color.clear)
                    .onTapGesture {
                        guard fp.pin.populated else { return }
                        selectedPin = selectedPin == fp.number - 1 ? nil : fp.number - 1
                    }
                Divider().overlay(Color(hex: 0x2a2e35))
            }
        }
    }

    private func wireRow(_ fp: FlatPin, target: Connector?) -> some View {
        let p = fp.pin
        return HStack(spacing: 10) {
            Text("\(fp.number)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.idText)
                .frame(width: 22, alignment: .leading)
            if p.populated {
                ColorSwatch(code: p.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.guess ?? "Not labeled")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Text(WireColor.label(p.color) + (p.gauge.map { " · \($0) AWG" } ?? "") + (p.confidence.map { " · \($0)" } ?? ""))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.nameText)
                }
                Spacer()
                if let target, let n = Self.matchPin(for: p, in: target) {
                    Text("goes to pin \(n)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.amber)
                }
                if let role = WireRole(rawValue: p.role ?? "") {
                    RoleBadge(role: role, size: 20)
                }
            } else {
                Text("Empty")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.nameText)
                Spacer()
            }
        }
        .padding(.vertical, 9)
    }

    private func actions(_ c: Connector, index: Int, count: Int) -> some View {
        HStack(spacing: 8) {
            Button("Edit") {
                onEdit(c, selectedPin)
            }
            Spacer()
            Button {
                store.movePlug(id: c.id, by: -1)
            } label: {
                Image(systemName: "arrow.up")
            }
            .disabled(index == 0)
            Button {
                store.movePlug(id: c.id, by: 1)
            } label: {
                Image(systemName: "arrow.down")
            }
            .disabled(index >= count - 1)
            Button("Remove", role: .destructive) {
                confirmRemove = true
            }
        }
        .buttonStyle(.bordered)
        .padding(.top, 6)
    }

    /// Placeholder rule for "goes to pin N": same netId, else same function text.
    static func matchPin(for pin: Pin, in target: Connector) -> Int? {
        if let net = pin.netId, !net.isEmpty,
           let m = target.flatPins.first(where: { $0.pin.populated && $0.pin.netId == net }) {
            return m.number
        }
        if let g = pin.guess, !g.isEmpty,
           let m = target.flatPins.first(where: { $0.pin.populated && $0.pin.guess == g }) {
            return m.number
        }
        return nil
    }
}

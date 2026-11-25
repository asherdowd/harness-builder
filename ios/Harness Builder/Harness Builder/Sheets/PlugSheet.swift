//
//  PlugSheet.swift
//  Harness Builder
//
//  The bottom sheet for one plug: numbered pinout, wire list, component link
//  cards, and Edit / Remove. (Moving a plug along the trunk is on the canvas.)
//  Tapping a wire selects it; Edit then opens the wizard on that pin.
//

import SwiftUI

struct PlugSheet: View {
    let store: HarnessStore
    let plugID: String
    /// The selected wire (0-based), owned by the main screen so the canvas can outline where it goes.
    @Binding var selectedPin: Int?
    /// Open another plug (switches to its harness tab and selects it).
    let onJump: (PlugRef) -> Void
    /// The plug was removed.
    let onRemoved: () -> Void
    /// Open the wizard to edit this plug, on the selected pin (0-based) if there is one.
    let onEdit: (Connector, Int?) -> Void
    /// Open the link picker for this (component) plug.
    let onLink: (Connector) -> Void

    @State private var confirmRemove = false
    @State private var notesOpen = false
    @State private var editingNote = false
    @State private var noteText = ""

    var body: some View {
        Group {
            if let ref = store.plug(id: plugID) {
                content(ref)
            } else {
                Color.clear
            }
        }
        // Another plug was opened in this same sheet: start fresh.
        .onChange(of: plugID) { _, _ in
            selectedPin = nil
            notesOpen = false
            editingNote = false
        }
    }

    private func content(_ ref: PlugRef) -> some View {
        let c = ref.connector
        let target = store.linkTarget(of: c)
        let linkedFrom = store.linkedComponents(to: c.id)

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(c)

                notesSection(c)

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

                if let idx = selectedPin, let fp = c.flatPins.first(where: { $0.number == idx + 1 }) {
                    traceSection(c, fp)
                }
            }
            .padding(16)
        }
        // Edit / Remove stay pinned at the bottom so a long wire list never hides them.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actions(c)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Palette.sheetBg)
                .overlay(alignment: .top) { Divider().overlay(Palette.divider) }
        }
        .background(Palette.sheetBg)
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
                    .foregroundStyle(Palette.text)
                Spacer()
            }
            Text("\(c.pinCount) pins · \(c.wiredCount) wired · \(c.spareCount) spare")
                .font(.system(size: 13))
                .foregroundStyle(Palette.nameText)
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
            .tint(Palette.amberInk)
        }
    }

    /// Notes: collapsed by default; always there so a first note can be added.
    private func notesSection(_ c: Connector) -> some View {
        let text = c.description ?? ""
        let firstLine = text.split(separator: "\n").first.map(String.init) ?? ""
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { notesOpen.toggle() }
                if !notesOpen { editingNote = false }
            } label: {
                HStack(spacing: 8) {
                    Text("Notes")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.chipText)
                    if !notesOpen, !firstLine.isEmpty {
                        Text(firstLine)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.nameText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: notesOpen ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Palette.nameText)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if notesOpen {
                VStack(alignment: .leading, spacing: 10) {
                    if editingNote {
                        TextEditor(text: $noteText)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(Palette.text)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.field))
                        HStack {
                            Button("Cancel") { editingNote = false }
                            Spacer()
                            Button("Save") {
                                let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                                store.updatePlug(id: c.id) { $0.description = trimmed.isEmpty ? nil : trimmed }
                                editingNote = false
                            }
                            .fontWeight(.bold)
                        }
                        .buttonStyle(.bordered)
                        .tint(Palette.amberInk)
                    } else {
                        if text.isEmpty {
                            Text("No notes yet.")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.nameText)
                        } else {
                            Text(text)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.chipText)
                                .textSelection(.enabled)
                        }
                        Button(text.isEmpty ? "Add a note" : "Edit note") {
                            noteText = text
                            editingNote = true
                        }
                        .buttonStyle(.bordered)
                        .tint(Palette.amberInk)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.chipFill))
    }

    /// Where the selected wire goes: same wire, same job, or the whole plug.
    private func traceSection(_ c: Connector, _ fp: FlatPin) -> some View {
        let links = WireTrace.links(for: fp, in: c, harnesses: store.harnesses)
        let same = links.filter { $0.precise && $0.same }
        let job = links.filter { $0.precise && !$0.same }
        let whole = links.filter { !$0.precise }
        return VStack(alignment: .leading, spacing: 10) {
            if c.custom == true && (fp.pin.netId ?? "").isEmpty {
                hint("This wire isn't connected to another plug yet. Edit the plug and use Connects to.")
            }
            traceGroup("Same wire continues at", same, sub: "same wire")
            traceGroup("Does the same job in", job, sub: "same job, other harness")
            traceGroup("This plug as a whole matches", whole, sub: "pins not mapped yet")
            if c.custom != true && links.isEmpty {
                hint("Nothing mapped for this wire yet.")
            }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Palette.nameText)
    }

    @ViewBuilder
    private func traceGroup(_ title: String, _ items: [TraceLink], sub: String) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.amberInk)
                ForEach(items) { l in
                    Button {
                        if let ref = store.plug(id: l.plugID) { onJump(ref) }
                    } label: {
                        HStack(spacing: 10) {
                            if l.color != nil { ColorSwatch(code: l.color, width: 26, height: 20) }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.plugTitle + (l.pinNumber.map { " · pin \($0)" } ?? ""))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                Text("\(l.harnessTitle), \(sub)")
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
            }
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
                        .foregroundStyle(Palette.amberInk)
                    Text(ref.connector.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.text)
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
                    .background(selectedPin == fp.number - 1 ? Palette.amberInk.opacity(0.14) : Color.clear)
                    .onTapGesture {
                        guard fp.pin.populated else { return }
                        selectedPin = selectedPin == fp.number - 1 ? nil : fp.number - 1
                    }
                Divider().overlay(Palette.rowDivider)
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
                        .foregroundStyle(Palette.text)
                    Text(WireColor.label(p.color) + (p.gauge.map { " · \($0) AWG" } ?? "") + (p.confidence.map { " · \($0)" } ?? ""))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.nameText)
                }
                Spacer()
                if let target, let n = Self.matchPin(for: p, in: target) {
                    Text("goes to pin \(n)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.amberInk)
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

    private func actions(_ c: Connector) -> some View {
        HStack(spacing: 8) {
            Button("Edit") {
                onEdit(c, selectedPin)
            }
            Spacer()
            Button("Remove", role: .destructive) {
                confirmRemove = true
            }
        }
        .buttonStyle(.bordered)
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

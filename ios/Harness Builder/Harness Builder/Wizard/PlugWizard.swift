//
//  PlugWizard.swift
//  Harness Builder
//
//  Builds a new plug (pick a shape, name it, set each pin) or edits an
//  existing one (name and pin settings; the pin layout stays as it is).
//

import SwiftUI

struct PlugWizard: View {
    let store: HarnessStore
    let harnessID: String
    let editing: Connector?
    let onClose: () -> Void
    /// Called with the plug's id after it is added or saved.
    let onSaved: (String) -> Void

    @State private var draft: PlugDraft?
    @State private var sel: Int

    /// `startPin` is the pin (0-based) the editor opens on when editing.
    init(store: HarnessStore, harnessID: String, editing: Connector?, startPin: Int?,
         onClose: @escaping () -> Void, onSaved: @escaping (String) -> Void) {
        self.store = store
        self.harnessID = harnessID
        self.editing = editing
        self.onClose = onClose
        self.onSaved = onSaved
        let initial = editing.map { PlugDraft(editing: $0) }
        _draft = State(initialValue: initial)
        let count = initial?.pins.count ?? 1
        _sel = State(initialValue: min(max(startPin ?? 0, 0), max(count - 1, 0)))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let d = Binding($draft) {
                editor(d)
            } else {
                ShapePicker { def in
                    draft = PlugDraft(newShape: def.key)
                    sel = 0
                }
            }
        }
        .background(Color(hex: 0x1b1f26))
        .scrollDismissesKeyboard(.interactively)
    }

    private var topBar: some View {
        HStack {
            if draft != nil, editing == nil {
                Button {
                    draft = nil
                } label: {
                    Label("Shapes", systemImage: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            Spacer()
            Button("Cancel", action: onClose)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .tint(Palette.amber)
    }

    // MARK: editor step

    private func editor(_ d: Binding<PlugDraft>) -> some View {
        let value = d.wrappedValue
        let total = value.total
        let title = editing == nil ? (value.def?.label ?? "New plug") : "Edit plug"

        return VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            PlugPreview(connector: value.connector(), maxWidth: 220, height: 96, showRoles: true)
                .frame(maxWidth: .infinity)
                .frame(height: 112)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.bg))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Name")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.nameText)
                    TextField("e.g. Fuel pump relay plug", text: d.name)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: 0x1d2128)))
                        .foregroundStyle(.white)

                    sizeControls(d)

                    Text("Tap a pin, then set its wire")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.nameText)
                        .padding(.top, 6)
                    pinGrid(value)

                    Text("Pin \(sel + 1)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                    if value.pins.indices.contains(sel) {
                        PinEditor(pin: Binding(
                            get: { d.wrappedValue.pins[sel] },
                            set: { newValue in
                                if d.wrappedValue.pins.indices.contains(sel) { d.wrappedValue.pins[sel] = newValue }
                            }))
                    }

                    HStack(spacing: 10) {
                        if sel < total - 1 {
                            Button {
                                sel += 1
                            } label: {
                                Text("Next pin")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.chipFill))
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            save(value)
                        } label: {
                            Text(editing == nil ? "Add to harness" : "Save changes")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Palette.amberText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.amber))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)

                    Text("\(value.coloredCount) of \(total) pins have a color")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.nameText)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    /// Row and pin count steppers (new plugs only).
    @ViewBuilder
    private func sizeControls(_ d: Binding<PlugDraft>) -> some View {
        let value = d.wrappedValue
        if value.fixedRows == nil, let def = value.def, def.adjust != .none {
            let maxCols = def.adjust == .splice ? 4 : (def.adjust == .cols ? 6 : 13)
            VStack(spacing: 8) {
                if def.adjust == .grid {
                    stepRow("Rows", value: value.rowCount, range: 1...3) { n in
                        d.wrappedValue.resize(rows: n)
                        sel = min(sel, d.wrappedValue.total - 1)
                    }
                }
                stepRow(def.adjust == .grid ? "Pins per row" : "Pins", value: value.colCount, range: 2...maxCols) { n in
                    d.wrappedValue.resize(cols: n)
                    sel = min(sel, d.wrappedValue.total - 1)
                }
            }
        }
    }

    private func stepRow(_ title: String, value: Int, range: ClosedRange<Int>, set: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(Palette.chipText)
            Spacer()
            Button { set(max(range.lowerBound, value - 1)) } label: {
                Image(systemName: "minus").frame(width: 38, height: 34)
            }
            Text("\(value)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(minWidth: 26)
            Button { set(min(range.upperBound, value + 1)) } label: {
                Image(systemName: "plus").frame(width: 38, height: 34)
            }
        }
        .buttonStyle(.bordered)
        .tint(Palette.amber)
    }

    /// The plug's pins as tappable color chips, laid out in rows.
    private func pinGrid(_ value: PlugDraft) -> some View {
        let rows = normalizeRows(shape: value.shape, rows: value.buildRows())
        var counter = 0
        var numbered: [[Int]] = []
        for r in rows {
            var line: [Int] = []
            for _ in r.pins {
                line.append(counter)
                counter += 1
            }
            numbered.append(line)
        }
        return VStack(spacing: 8) {
            ForEach(Array(numbered.enumerated()), id: \.offset) { rowItem in
                HStack(spacing: 10) {
                    ForEach(rowItem.element, id: \.self) { i in
                        pinChip(i, pin: value.pins.indices.contains(i) ? value.pins[i] : nil)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func pinChip(_ i: Int, pin: Pin?) -> some View {
        let on = i == sel
        return Button {
            sel = i
        } label: {
            VStack(spacing: 2) {
                if let pin, pin.populated {
                    ColorSwatch(code: pin.color, width: 32, height: 32)
                } else {
                    Circle()
                        .stroke(Palette.pinEmptyStroke, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .frame(width: 32, height: 32)
                }
                Text("\(i + 1)").font(.system(size: 11)).foregroundStyle(Palette.nameText)
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 10).fill(on ? Color(hex: 0x2d2a22) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? Palette.amber : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    // MARK: saving

    private func save(_ d: PlugDraft) {
        let rows = d.buildRows()
        let name = d.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let editing {
            store.updatePlug(id: editing.id) { c in
                c.rows = rows
                if !name.isEmpty, name != c.title {
                    c.name = name
                    c.displayName = name
                }
            }
            onSaved(editing.id)
        } else {
            var c = d.connector()
            c.name = name
            if let id = store.addPlug(c, toHarness: harnessID) {
                onSaved(id)
            }
        }
    }
}

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
    @State private var pickingShape = false
    @State private var confirmDrop = false
    @State private var confirmDiscard = false
    @State private var pickingWire = false

    /// `startPin` is the pin (0-based) the editor opens on when editing.
    /// `resumed` is an unsaved draft picked up from where the user left off.
    init(store: HarnessStore, harnessID: String, editing: Connector?, startPin: Int?,
         resumed: SavedPlugDraft? = nil,
         onClose: @escaping () -> Void, onSaved: @escaping (String) -> Void) {
        self.store = store
        self.harnessID = harnessID
        self.editing = editing
        self.onClose = onClose
        self.onSaved = onSaved
        let initial = resumed?.draft ?? editing.map { PlugDraft(editing: $0) }
        _draft = State(initialValue: initial)
        let count = initial?.pins.count ?? 1
        _sel = State(initialValue: min(max(resumed?.sel ?? startPin ?? 0, 0), max(count - 1, 0)))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let d = Binding($draft), !pickingShape {
                editor(d)
            } else {
                ShapePicker { def in
                    if draft == nil {
                        draft = PlugDraft(newShape: def.key)
                        sel = 0
                    } else {
                        draft?.changeShape(to: def.key)
                        sel = min(sel, max((draft?.total ?? 1) - 1, 0))
                    }
                    pickingShape = false
                }
            }
        }
        .background(Palette.sheetBg)
        .scrollDismissesKeyboard(.interactively)
        .interactiveDismissDisabled(draft?.hasChanges ?? false)
        .onChange(of: draft) { _, _ in persistDraft() }
        .onChange(of: sel) { _, _ in persistDraft() }
        .sheet(isPresented: $pickingWire) {
            WirePickerSheet(store: store, excludingPlugID: editing?.id,
                            onPick: { plugID, number, pin in
                                draft?.connect(pin: sel, toPlug: plugID, pinNumber: number, targetPin: pin)
                                pickingWire = false
                            },
                            onClose: { pickingWire = false })
                .presentationDetents([.large])
                .presentationBackground(Palette.sheetBg)
        }
        .alert("Data will be lost", isPresented: $confirmDrop) {
            Button("Cancel", role: .cancel) {}
            Button("Delete \(draft?.droppedWiredCount ?? 0) wired pins and save", role: .destructive) {
                if let d = draft { save(d) }
            }
        } message: {
            Text("This plug now has fewer pins. \(draft?.droppedWiredCount ?? 0) pins that have wires set on them would be deleted for good, along with their color, function, gauge and type.")
        }
    }

    private var topBar: some View {
        HStack {
            if pickingShape, draft != nil {
                Button {
                    pickingShape = false
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
            } else if draft != nil, editing == nil {
                Button {
                    draft = nil
                } label: {
                    Label("Shapes", systemImage: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            Spacer()
            Button("Cancel") {
                if draft?.hasChanges == true { confirmDiscard = true } else { onClose() }
            }
            .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .tint(Palette.amberInk)
        .confirmationDialog("Discard your changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) {
                store.clearDraft()
                onClose()
            }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("What you set on this plug has not been saved.")
        }
    }

    // MARK: editor step

    private func editor(_ d: Binding<PlugDraft>) -> some View {
        let value = d.wrappedValue
        let total = value.total
        let title = editing == nil ? (value.def?.label ?? "New plug") : "Edit plug"

        return VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.text)
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
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.field))
                        .foregroundStyle(Palette.text)

                    shapeRow(value)
                    sizeControls(d)

                    Text("Tap a pin, then set its wire")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.nameText)
                        .padding(.top, 6)
                    pinGrid(value)

                    Text("Pin \(sel + 1)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .padding(.top, 4)
                    if value.pins.indices.contains(sel) {
                        PinEditor(pin: Binding(
                            get: { d.wrappedValue.pins[sel] },
                            set: { newValue in
                                if d.wrappedValue.pins.indices.contains(sel) { d.wrappedValue.pins[sel] = newValue }
                            }),
                            connections: connections(value, pin: sel),
                            onConnect: { pickingWire = true },
                            onDisconnect: { d.wrappedValue.disconnect(pin: sel) })
                    }

                    if value.droppedWiredCount > 0 {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Palette.warnStrong)
                            Text("Warning: \(value.droppedWiredCount) pins that have wires set on them are gone from this layout. Saving will delete them for good. Add pins back to keep them.")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.warnText)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.warnFill))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.warnStrong, lineWidth: 1.5))
                        .padding(.top, 8)
                    }

                    HStack(spacing: 10) {
                        if sel < total - 1 {
                            Button {
                                sel += 1
                            } label: {
                                Text("Next pin")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.chipFill))
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            if value.droppedWiredCount > 0 { confirmDrop = true } else { save(value) }
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

    /// The current shape, with a button to pick another.
    private func shapeRow(_ value: PlugDraft) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shape")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.nameText)
                Text(value.def?.label ?? "Imported layout")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.chipText)
            }
            Spacer()
            Button("Change shape") { pickingShape = true }
                .buttonStyle(.bordered)
                .tint(Palette.amberInk)
        }
        .padding(.top, 4)
    }

    /// Row and pin count steppers (up to 60 pins in all).
    @ViewBuilder
    private func sizeControls(_ d: Binding<PlugDraft>) -> some View {
        let value = d.wrappedValue
        if let def = value.def, def.adjust != .none {
            let maxCols = def.adjust == .splice ? 4 : (def.adjust == .cols ? ShapeLimits.maxInlineCols : ShapeLimits.maxCols)
            let colLimit = def.adjust == .grid ? min(maxCols, ShapeLimits.maxPins / max(value.rowCount, 1)) : maxCols
            VStack(spacing: 8) {
                if def.adjust == .grid {
                    let rowLimit = min(ShapeLimits.maxRows, ShapeLimits.maxPins / max(value.colCount, 1))
                    stepRow("Rows", value: value.rowCount, range: 1...max(rowLimit, 1)) { n in
                        d.wrappedValue.resize(rows: n)
                        sel = min(sel, d.wrappedValue.total - 1)
                    }
                }
                stepRow(def.adjust == .grid ? "Pins per row" : "Pins", value: value.colCount, range: 2...max(colLimit, 2)) { n in
                    d.wrappedValue.resize(cols: n)
                    sel = min(sel, d.wrappedValue.total - 1)
                }
                Text("\(value.total) pins in all")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.nameText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else if value.def == nil {
            Text("\(value.pins.count) pins, laid out as imported. Change the shape to resize.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.nameText)
        }
    }

    private func stepRow(_ title: String, value: Int, range: ClosedRange<Int>, set: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(Palette.chipText)
            Spacer()
            Button { set(min(max(range.lowerBound, value - 1), max(value, range.lowerBound))) } label: {
                Image(systemName: "minus").frame(width: 38, height: 34)
            }
            Text("\(value)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.text)
                .frame(minWidth: 26)
            Button { set(max(min(range.upperBound, value + 1), min(value, range.upperBound))) } label: {
                Image(systemName: "plus").frame(width: 38, height: 34)
            }
        }
        .buttonStyle(.bordered)
        .tint(Palette.amberInk)
    }

    /// The plug's pins as tappable color chips, laid out in rows.
    /// Wide plugs (many pins per row) get small chips and scroll sideways.
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
        let compact = (numbered.map(\.count).max() ?? 0) > 7
        let grid = VStack(spacing: compact ? 4 : 8) {
            ForEach(Array(numbered.enumerated()), id: \.offset) { rowItem in
                HStack(spacing: compact ? 4 : 10) {
                    ForEach(rowItem.element, id: \.self) { i in
                        pinChip(i, pin: value.pins.indices.contains(i) ? value.pins[i] : nil, compact: compact)
                            .id(i)
                    }
                }
            }
        }
        return Group {
            if compact {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: true) {
                        grid.padding(.horizontal, 2).padding(.bottom, 8)
                    }
                    .onChange(of: sel) { _, n in
                        withAnimation { proxy.scrollTo(n, anchor: .center) }
                    }
                }
            } else {
                grid.frame(maxWidth: .infinity)
            }
        }
    }

    private func pinChip(_ i: Int, pin: Pin?, compact: Bool) -> some View {
        let on = i == sel
        let size: CGFloat = compact ? 22 : 32
        return Button {
            sel = i
        } label: {
            VStack(spacing: 2) {
                if let pin, pin.populated {
                    ColorSwatch(code: pin.color, width: size, height: size)
                } else {
                    Circle()
                        .stroke(Palette.pinEmptyStroke, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .frame(width: size, height: size)
                }
                Text("\(i + 1)").font(.system(size: compact ? 9 : 11)).foregroundStyle(Palette.nameText)
            }
            .padding(compact ? 3 : 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(on ? Palette.selectedFill : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(on ? Palette.amberInk : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    /// Pins on other plugs that this pin is connected to (saved, or chosen but not saved yet).
    private func connections(_ value: PlugDraft, pin i: Int) -> [PinConnection] {
        guard value.pins.indices.contains(i), let net = value.pins[i].netId, !net.isEmpty else { return [] }
        var out: [PinConnection] = []
        var seen = Set<String>()
        func add(_ plug: Connector, _ harness: Harness, _ number: Int) {
            let key = "\(plug.id)#\(number)"
            guard seen.insert(key).inserted else { return }
            out.append(PinConnection(id: key, title: "\(plug.title) · pin \(number)", sub: harness.tabLabel))
        }
        for st in value.stamps where st.pinIndex == i {
            if let ref = store.plug(id: st.plugID) { add(ref.connector, ref.harness, st.pinNumber) }
        }
        for h in store.harnesses {
            for c in h.connectors {
                for fp in c.flatPins where fp.pin.netId == net {
                    if c.id == editing?.id && fp.number == i + 1 { continue }
                    add(c, h, fp.number)
                }
            }
        }
        return out
    }

    // MARK: saving

    /// Keeps what is being built on the device, so closing the app doesn't lose it.
    private func persistDraft() {
        guard let d = draft, d.hasChanges else {
            store.clearDraft()
            return
        }
        store.saveDraft(SavedPlugDraft(harnessID: harnessID, editingID: editing?.id, sel: sel, draft: d))
    }

    private func save(_ d: PlugDraft) {
        let rows = d.buildRows()
        let name = d.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let editing {
            store.updatePlug(id: editing.id) { c in
                if d.shape != c.shape {
                    c.shape = d.shape
                    c.shapeProvisional = false
                }
                c.rows = rows
                if !name.isEmpty, name != c.title {
                    c.name = name
                    c.displayName = name
                }
            }
            store.stampNets(d.validStamps)
            store.clearDraft()
            onSaved(editing.id)
        } else {
            var c = d.connector()
            c.name = name
            if let id = store.addPlug(c, toHarness: harnessID) {
                store.stampNets(d.validStamps)
                store.clearDraft()
                onSaved(id)
            }
        }
    }
}

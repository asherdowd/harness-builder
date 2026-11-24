//
//  MainView.swift
//  Harness Builder
//
//  The app's main screen: harness tabs and the canvas.
//  Tapping a plug opens the plug sheet; "+" adds a plug; "＋ New" adds a harness; "⋯" is the harness menu.
//

import SwiftUI

/// What the main screen's one bottom sheet is showing. All cases share an id,
/// so switching between them swaps the content instead of closing the sheet.
private enum ActiveSheet: Identifiable {
    case plug(String)
    case wizard(WizardRequest)
    case addHarness
    case harnessMenu
    case linkPicker(String)

    var id: String { "sheet" }
}

/// Sheets opened from the header, the tab row, or a component plug.
private enum Panel {
    case addHarness
    case harnessMenu
    case linkPicker(String)
}

private struct WizardRequest {
    var harnessID: String
    var editing: Connector?
    var startPin: Int?
}

struct MainView: View {
    @State private var store = HarnessStore()
    @State private var selectedID: String?
    @State private var wizard: WizardRequest?
    @State private var panel: Panel?
    @State private var showRoles = true
    @State private var fitTick = 0
    @State private var selectedPin: Int?
    @State private var focusID: String?
    @State private var focusTick = 0

    /// Select a plug and bring it into view (above the plug sheet).
    private func select(_ id: String?) {
        if id != selectedID { selectedPin = nil }
        selectedID = id
        if let id {
            focusID = id
            focusTick += 1
        }
    }

    /// Plugs to outline on the canvas for the selected wire (or same-circuit plugs).
    private var linkedIDs: Set<String> {
        guard let id = selectedID, let ref = store.plug(id: id) else { return [] }
        return WireTrace.highlightIDs(selected: ref.connector, pinIndex: selectedPin,
                                      harnesses: store.harnesses, activeID: store.active.id)
    }

    private var activeSheet: Binding<ActiveSheet?> {
        Binding(
            get: {
                if let p = panel {
                    switch p {
                    case .addHarness: return .addHarness
                    case .harnessMenu: return .harnessMenu
                    case .linkPicker(let id): return .linkPicker(id)
                    }
                }
                if let w = wizard { return .wizard(w) }
                if let id = selectedID, store.plug(id: id) != nil { return .plug(id) }
                return nil
            },
            set: { newValue in
                guard newValue == nil else { return }
                if panel != nil { panel = nil }
                else if wizard != nil { wizard = nil }
                else { selectedID = nil }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                tabRow
            }
            .background(Palette.surface)
            Divider().overlay(Palette.divider)
            ZStack(alignment: .bottom) {
                HarnessCanvasView(harness: store.active, selectedID: selectedID,
                                  onSelect: { select($0) }, showRoles: showRoles,
                                  onMove: { id, delta in store.movePlug(id: id, by: delta) },
                                  linkedIDs: linkedIDs, focusID: focusID, focusTick: focusTick,
                                  fitTick: fitTick)
                if store.isBlank {
                    firstOpenCard
                }
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(item: activeSheet) { kind in
            switch kind {
            case .plug(let id):
                PlugSheet(store: store, plugID: id, selectedPin: $selectedPin,
                          onJump: { ref in
                              store.setActive(ref.harness.id)
                              select(ref.connector.id)
                          },
                          onRemoved: { selectedID = nil },
                          onEdit: { plug, pin in
                              wizard = WizardRequest(harnessID: store.active.id, editing: plug, startPin: pin)
                          },
                          onLink: { plug in panel = .linkPicker(plug.id) })
                    .presentationDetents([.fraction(0.46), .large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.46)))
                    .presentationBackground(Color(hex: 0x1b1f26))
            case .wizard(let req):
                PlugWizard(store: store, harnessID: req.harnessID, editing: req.editing, startPin: req.startPin,
                           onClose: { wizard = nil },
                           onSaved: { id in
                               selectedID = id
                               wizard = nil
                           })
                    .presentationDetents([.large])
                    .presentationBackground(Color(hex: 0x1b1f26))
            case .addHarness:
                AddHarnessSheet(store: store, onClose: {
                    selectedID = nil
                    panel = nil
                })
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Color(hex: 0x1b1f26))
            case .harnessMenu:
                HarnessMenuSheet(store: store, harnessID: store.active.id, onClose: {
                    selectedID = nil
                    panel = nil
                })
                    .presentationDetents([.medium])
                    .presentationBackground(Color(hex: 0x1b1f26))
            case .linkPicker(let id):
                LinkPickerSheet(store: store, plugID: id, onClose: { panel = nil })
                    .presentationDetents([.large])
                    .presentationBackground(Color(hex: 0x1b1f26))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(store.active.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Button {
                showRoles.toggle()
            } label: {
                Image(systemName: "plusminus.circle")
                    .foregroundStyle(showRoles ? Palette.amberText : Palette.chipText)
                    .frame(width: 36, height: 32)
                    .background(Capsule().fill(showRoles ? Palette.amber : Palette.chipFill))
            }
            .accessibilityLabel("Show wire types")
            Button {
                fitTick += 1
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .foregroundStyle(Palette.chipText)
                    .frame(width: 36, height: 32)
                    .background(Capsule().fill(Palette.chipFill))
            }
            .accessibilityLabel("Fit all")
            Button {
                selectedID = nil
                wizard = WizardRequest(harnessID: store.active.id, editing: nil, startPin: nil)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.amberText)
                    .frame(width: 36, height: 32)
                    .background(Capsule().fill(Palette.amber))
            }
            Button {
                selectedID = nil
                panel = .harnessMenu
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Palette.chipText)
                    .frame(width: 36, height: 32)
                    .background(Capsule().fill(Palette.chipFill))
            }
            .accessibilityLabel("Harness menu")
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var tabRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.harnesses) { h in
                    let on = h.id == store.state.activeID
                    Button {
                        selectedID = nil
                        store.setActive(h.id)
                    } label: {
                        Text((h.kind == .component ? "◇ " : "") + h.tabLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(on ? Palette.amberText : Palette.chipText)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(on ? Palette.amber : Palette.chipFill))
                    }
                }
                Button {
                    selectedID = nil
                    panel = .addHarness
                } label: {
                    Text("＋ New")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.amber)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .overlay(Capsule().stroke(Palette.amber.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 8)
    }

    private var firstOpenCard: some View {
        VStack {
            VStack(spacing: 10) {
                Text("Build a harness")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("Start with an example to see how a harness looks, then make it your own.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.nameText)
                    .multilineTextAlignment(.center)
                Button {
                    wizard = WizardRequest(harnessID: store.active.id, editing: nil, startPin: nil)
                } label: {
                    Text("Add your first plug")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Palette.amberText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.amber))
                }
                .padding(.top, 6)
                Button {
                    selectedID = nil
                    store.loadExample()
                } label: {
                    Text("Try the example")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.chipText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.chipFill))
                }
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: 0x1b1f26)))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: 0x3a414c), lineWidth: 1))
            .padding(.horizontal, 24)
            .padding(.top, 70)
            Spacer()
        }
    }
}

#Preview {
    MainView()
}

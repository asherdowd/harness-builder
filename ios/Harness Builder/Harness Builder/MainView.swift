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
    case export
    case settings
    case checks
    case linkPicker(String)

    var id: String { "sheet" }
}

/// Sheets opened from the header, the tab row, or a component plug.
private enum Panel {
    case addHarness
    case harnessMenu
    case export
    case settings
    case checks
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
    @State private var showRoles = false
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
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
                    case .export: return .export
                    case .settings: return .settings
                    case .checks: return .checks
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
                tabRow
                Divider().overlay(Palette.divider)
                header
            }
            .background(Palette.surface)
            Divider().overlay(Palette.divider)
            ZStack(alignment: .bottom) {
                HarnessCanvasView(harness: store.active, selectedID: selectedID,
                                  onSelect: { select($0) }, showRoles: showRoles,
                                  linkedIDs: linkedIDs, focusID: focusID, focusTick: focusTick,
                                  onMove: { id, delta in store.movePlug(id: id, by: delta) },
                                  fitTick: fitTick)
                if store.isBlank {
                    firstOpenCard
                }
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .preferredColorScheme(AppearanceMode.from(appearanceRaw).scheme)
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
                    .presentationBackground(Palette.sheetBg)
            case .wizard(let req):
                PlugWizard(store: store, harnessID: req.harnessID, editing: req.editing, startPin: req.startPin,
                           onClose: { wizard = nil },
                           onSaved: { id in
                               selectedID = id
                               wizard = nil
                           })
                    .presentationDetents([.large])
                    .presentationBackground(Palette.sheetBg)
            case .addHarness:
                AddHarnessSheet(store: store, onClose: {
                    selectedID = nil
                    panel = nil
                })
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Palette.sheetBg)
            case .harnessMenu:
                HarnessMenuSheet(store: store, harnessID: store.active.id, onClose: {
                    selectedID = nil
                    panel = nil
                }, onExport: { panel = .export }, onChecks: { panel = .checks })
                    .presentationDetents([.medium])
                    .presentationBackground(Palette.sheetBg)
            case .export:
                ExportSheet(store: store, onClose: { panel = nil })
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Palette.sheetBg)
            case .checks:
                ChecksSheet(store: store,
                            onJump: { id in
                                panel = nil
                                select(id)
                            },
                            onClose: { panel = nil })
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Palette.sheetBg)
            case .settings:
                SettingsSheet(store: store, onClose: { panel = nil })
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Palette.sheetBg)
            case .linkPicker(let id):
                LinkPickerSheet(store: store, plugID: id, onClose: { panel = nil })
                    .presentationDetents([.large])
                    .presentationBackground(Palette.sheetBg)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(store.active.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.text)
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
        // "＋ New" stays pinned at the right edge; only the harness tabs scroll.
        HStack(spacing: 8) {
            Button {
                selectedID = nil
                panel = .settings
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(Palette.chipText)
                    .frame(width: 36, height: 32)
                    .background(Capsule().fill(Palette.chipFill))
            }
            .accessibilityLabel("Settings")
            .padding(.leading, 14)
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
                }
            }
            Button {
                selectedID = nil
                panel = .addHarness
            } label: {
                Text("＋ New")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.amberInk)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .overlay(Capsule().stroke(Palette.amberInk.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
            .padding(.trailing, 14)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var firstOpenCard: some View {
        VStack {
            VStack(spacing: 10) {
                Text("Build a harness")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.text)
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
            .background(RoundedRectangle(cornerRadius: 20).fill(Palette.sheetBg))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.cardStroke, lineWidth: 1))
            .padding(.horizontal, 24)
            .padding(.top, 70)
            Spacer()
        }
    }
}

#Preview {
    MainView()
}

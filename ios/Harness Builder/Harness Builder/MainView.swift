//
//  MainView.swift
//  Harness Builder
//
//  The app's main screen: harness tabs and the canvas.
//  Tapping a plug opens the plug sheet; "+" opens the add-plug wizard. (The "Add a harness" sheet
//  comes next; until then the wrench button opens the temporary test tools.)
//

import SwiftUI

/// What the main screen's one bottom sheet is showing. All cases share an id,
/// so switching between them swaps the content instead of closing the sheet.
private enum ActiveSheet: Identifiable {
    case plug(String)
    case wizard(WizardRequest)
    case tools

    var id: String { "sheet" }
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
    @State private var showTools = false

    private var activeSheet: Binding<ActiveSheet?> {
        Binding(
            get: {
                if showTools { return .tools }
                if let w = wizard { return .wizard(w) }
                if let id = selectedID, store.plug(id: id) != nil { return .plug(id) }
                return nil
            },
            set: { newValue in
                guard newValue == nil else { return }
                if showTools { showTools = false }
                else if wizard != nil { wizard = nil }
                else { selectedID = nil }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabRow
            ZStack(alignment: .bottom) {
                HarnessCanvasView(harness: store.active, selectedID: selectedID) { selectedID = $0 }
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
                PlugSheet(store: store, plugID: id,
                          onJump: { ref in
                              store.setActive(ref.harness.id)
                              selectedID = ref.connector.id
                          },
                          onRemoved: { selectedID = nil },
                          onEdit: { plug, pin in
                              wizard = WizardRequest(harnessID: store.active.id, editing: plug, startPin: pin)
                          })
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
            case .tools:
                ModelCheckView(store: store)
            }
        }
    }

    private var header: some View {
        HStack {
            Text(store.active.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
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
                showTools = true
            } label: {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(Palette.chipText)
                    .frame(width: 36, height: 32)
                    .background(Capsule().fill(Palette.chipFill))
            }
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

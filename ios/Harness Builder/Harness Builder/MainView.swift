//
//  MainView.swift
//  Harness Builder
//
//  The app's main screen: harness tabs and the canvas.
//  (The plug sheet, add-plug wizard and "Add a harness" sheet come next;
//  until then the wrench button opens the temporary test tools.)
//

import SwiftUI

struct MainView: View {
    @State private var store = HarnessStore()
    @State private var selectedID: String?
    @State private var showTools = false

    private var selectedPlug: Connector? {
        guard let id = selectedID else { return nil }
        return store.active.connectors.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabRow
            ZStack(alignment: .bottom) {
                HarnessCanvasView(harness: store.active, selectedID: selectedID) { selectedID = $0 }
                if store.isBlank {
                    firstOpenCard
                } else if let plug = selectedPlug {
                    selectionBar(plug)
                }
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showTools) {
            ModelCheckView(store: store)
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
                    selectedID = nil
                    store.loadExample()
                } label: {
                    Text("Try the example")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Palette.amberText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.amber))
                }
                .padding(.top, 6)
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: 0x1b1f26)))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: 0x3a414c), lineWidth: 1))
            .padding(.horizontal, 24)
            .padding(.top, 70)
            Spacer()
        }
    }

    private func selectionBar(_ plug: Connector) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(plug.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(plug.pinCount) pins. The plug sheet comes next.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.nameText)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x1b1f26)))
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }
}

#Preview {
    MainView()
}

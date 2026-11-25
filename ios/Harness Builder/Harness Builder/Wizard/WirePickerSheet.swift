//
//  WirePickerSheet.swift
//  Harness Builder
//
//  Pick a pin on another plug that the wire being edited connects to.
//  Step one lists plugs (on every harness); step two lists that plug's wires.
//

import SwiftUI

struct WirePickerSheet: View {
    let store: HarnessStore
    /// The plug being edited (it can't connect to itself). nil for a new plug.
    let excludingPlugID: String?
    let onPick: (_ plugID: String, _ pinNumber: Int, _ pin: Pin) -> Void
    let onClose: () -> Void

    @State private var chosen: PlugRef?

    private struct HarnessPlugs: Identifiable {
        var harness: Harness
        var plugs: [Connector]
        var id: String { harness.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if chosen != nil {
                        Button {
                            chosen = nil
                        } label: {
                            Label("Plugs", systemImage: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    Spacer()
                    Button("Cancel", action: onClose)
                        .font(.system(size: 14, weight: .semibold))
                }
                .tint(Palette.amberInk)

                if let ref = chosen {
                    pins(of: ref)
                } else {
                    plugs()
                }
            }
            .padding(16)
        }
        .background(Palette.sheetBg)
    }

    // MARK: step one

    private func plugs() -> some View {
        let groups = store.harnesses
            .map { h in HarnessPlugs(harness: h, plugs: h.connectors.filter { plug in plug.id != excludingPlugID }) }
            .filter { !$0.plugs.isEmpty }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Connect to a pin")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.text)
            Text("Pick the plug this wire continues to.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.nameText)

            if groups.isEmpty {
                Text("There are no other plugs yet. Add another plug first, then connect them.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.chipText)
                    .padding(.top, 8)
            }

            ForEach(groups) { g in
                Text(g.harness.tabLabel.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.nameText)
                    .padding(.top, 6)
                ForEach(g.plugs) { c in
                    Button {
                        chosen = PlugRef(harness: g.harness, connector: c)
                    } label: {
                        row(title: c.title, sub: "\(c.pinCount) pins")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: step two

    private func pins(of ref: PlugRef) -> some View {
        let wires = ref.connector.flatPins.filter { $0.pin.populated }
        return VStack(alignment: .leading, spacing: 12) {
            Text(ref.connector.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.text)
            Text("Pick the pin this wire connects to.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.nameText)

            if wires.isEmpty {
                Text("This plug has no wires set yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.chipText)
            }

            ForEach(wires, id: \.number) { fp in
                Button {
                    onPick(ref.connector.id, fp.number, fp.pin)
                } label: {
                    HStack(spacing: 10) {
                        Text("\(fp.number)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.idText)
                            .frame(width: 22, alignment: .leading)
                        ColorSwatch(code: fp.pin.color)
                        Text(fp.pin.guess ?? "Not labeled")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.text)
                        Spacer()
                        if !(fp.pin.netId ?? "").isEmpty {
                            Image(systemName: "link").foregroundStyle(Palette.amberInk)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.chipFill))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(title: String, sub: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.nameText)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Palette.nameText)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.chipFill))
    }
}

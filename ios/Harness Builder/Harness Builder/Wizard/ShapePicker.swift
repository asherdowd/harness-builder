//
//  ShapePicker.swift
//  Harness Builder
//
//  Step 1 of the wizard: pick the shape that matches the real plug.
//  Also holds PlugPreview, a small plug drawing used by the wizard.
//

import SwiftUI

/// A plug drawn small enough to fit a box (used for the picker and live preview).
struct PlugPreview: View {
    let connector: Connector
    var maxWidth: CGFloat = 120
    var height: CGFloat = 64
    var showRoles = false

    var body: some View {
        let art = ArtModel.make(for: connector)
        let k = min(1.6, height / max(art.height, 1), maxWidth / max(art.width, 1))
        PlugArt(model: art, showRoles: showRoles)
            .scaleEffect(k)
            .frame(width: art.width * k, height: art.height * k)
    }
}

struct ShapePicker: View {
    let onPick: (ShapeDef) -> Void
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    /// A sample plug of this shape, with a few wire colors, for its picture.
    private func sample(_ d: ShapeDef) -> Connector {
        var draft = PlugDraft(newShape: d.key)
        let colors = ["RED", "BLU", "GRN/WHT", "YEL", "BRN", "ORN", "PNK", "GRY"]
        for i in draft.pins.indices { draft.pins[i].color = colors[i % colors.count] }
        return draft.connector()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("What kind of plug?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text("Pick the shape that matches the real one. The pin layout follows.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.nameText)
                    .padding(.bottom, 8)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(ShapeCatalog.all, id: \.key) { d in
                        Button {
                            onPick(d)
                        } label: {
                            VStack(spacing: 8) {
                                PlugPreview(connector: sample(d), maxWidth: 110, height: 64)
                                    .frame(height: 70)
                                Text(d.label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.chipText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.bg))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
    }
}

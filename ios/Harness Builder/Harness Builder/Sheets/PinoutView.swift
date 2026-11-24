//
//  PinoutView.swift
//  Harness Builder
//
//  A large, numbered drawing of one plug for the plug sheet.
//

import SwiftUI

struct PinoutView: View {
    let connector: Connector

    var body: some View {
        let art = ArtModel.make(for: connector)
        let k = min(2.0, 280 / max(art.width, 1))
        ZStack {
            PlugArt(model: art, showRoles: true)
            ForEach(Array(art.pins.enumerated()), id: \.offset) { item in
                Text("\(item.offset + 1)")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Palette.nameText)
                    .position(x: art.width / 2 + item.element.x, y: art.height / 2 + item.element.y + 10)
            }
        }
        .frame(width: art.width, height: art.height)
        .scaleEffect(k)
        .frame(width: art.width * k, height: art.height * k)
    }
}

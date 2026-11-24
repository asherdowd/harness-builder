//
//  HarnessLayout.swift
//  Harness Builder
//
//  Places a harness's plugs along a central trunk, alternating sides
//  (ported from the web app's HarnessCanvas). x = 0 is the trunk's center.
//

import SwiftUI

struct PlacedPlug: Identifiable {
    var id: String
    var connector: Connector
    var art: ArtModel
    var side: CGFloat      // -1 = left of the trunk, +1 = right
    var x: CGFloat         // center of the plug
    var y: CGFloat
    var width: CGFloat { art.width }
    var height: CGFloat { art.height }
}

struct HarnessLayout {
    var items: [PlacedPlug] = []
    var minX: CGFloat = -60
    var maxX: CGFloat = 60
    var lastY: CGFloat = 220

    init(connectors: [Connector]) {
        let lead: CGFloat = 54
        var placed: [PlacedPlug] = []
        for (i, conn) in connectors.enumerated() {
            let art = ArtModel.make(for: conn)
            let side: CGFloat = i % 2 == 0 ? -1 : 1
            var y: CGFloat = i == 0 ? 70 : placed[i - 1].y + 96
            if i >= 2 {
                y = max(y, placed[i - 2].y + (placed[i - 2].height + art.height) / 2 + 66)
            }
            let x = side * (14 + lead + (art.width - 14) / 2)
            placed.append(PlacedPlug(id: conn.id, connector: conn, art: art, side: side, x: x, y: y))
        }
        items = placed
        if let last = placed.last {
            let xs = placed.flatMap { [$0.x - $0.width / 2, $0.x + $0.width / 2] }
            minX = min(xs.min() ?? -20, -20)
            maxX = max(xs.max() ?? 20, 20)
            lastY = last.y + last.height / 2 + 40
        }
    }

    /// Moves trunk coordinates into the drawing's own space (which starts at 0).
    var shiftX: CGFloat { -minX + 40 }
    var worldWidth: CGFloat { maxX - minX + 80 }
    var worldHeight: CGFloat { lastY + 60 }
}

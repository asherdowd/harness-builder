//
//  Geometry.swift
//  Harness Builder
//
//  Layout helpers ported from the web app (lib/geometry.js).
//  Coordinates are relative to the center of a plug.
//

import SwiftUI

/// A pin placed at a position inside a plug drawing.
struct PinDot {
    var x: CGFloat
    var y: CGFloat
    var pin: Pin
}

/// Grid-based pin layout for row/column style connectors.
func gridLayout(rows: [Row],
                colGap: CGFloat = 24,
                rowGap: CGFloat = 22,
                padX: CGFloat = 14,
                padY: CGFloat = 14,
                topExtra: CGFloat = 8) -> (width: CGFloat, height: CGFloat, pins: [PinDot]) {
    let maxCols = CGFloat(rows.map { $0.positions }.max() ?? 1)
    let width = maxCols * colGap + padX * 2
    let height = CGFloat(rows.count) * rowGap + padY * 2 + topExtra
    var pins: [PinDot] = []
    for (ri, row) in rows.enumerated() {
        let rowWidth = CGFloat(row.positions - 1) * colGap
        let startX = -rowWidth / 2
        let y = -height / 2 + padY + topExtra + CGFloat(ri) * rowGap
        for (pi, p) in row.pins.enumerated() {
            pins.append(PinDot(x: startX + CGFloat(pi) * colGap, y: y, pin: p))
        }
    }
    return (width, height, pins)
}

/// A closed path through a convex polygon with rounded corners.
func roundedPolyPath(_ pts: [CGPoint], radius r: CGFloat) -> Path {
    var path = Path()
    let n = pts.count
    guard n >= 3 else { return path }
    for i in 0..<n {
        let prev = pts[(i - 1 + n) % n]
        let curr = pts[i]
        let next = pts[(i + 1) % n]
        let len1 = hypot(curr.x - prev.x, curr.y - prev.y)
        let len2 = hypot(next.x - curr.x, next.y - curr.y)
        guard len1 > 0, len2 > 0 else { continue }
        let u1 = CGPoint(x: (curr.x - prev.x) / len1, y: (curr.y - prev.y) / len1)
        let u2 = CGPoint(x: (next.x - curr.x) / len2, y: (next.y - curr.y) / len2)
        let cr = min(r, len1 / 2, len2 / 2)
        let p1 = CGPoint(x: curr.x - u1.x * cr, y: curr.y - u1.y * cr)
        let p2 = CGPoint(x: curr.x + u2.x * cr, y: curr.y + u2.y * cr)
        if path.isEmpty { path.move(to: p1) } else { path.addLine(to: p1) }
        path.addQuadCurve(to: p2, control: curr)
    }
    path.closeSubpath()
    return path
}

/// Some connector families have a known, fixed physical row count, whatever
/// way the source data grouped the pins (a square 4-pin housing is always
/// 2 rows of 2). This re-chunks the flat pin list into that row count.
private let forcedRowCount: [String: Int] = [
    "square-4pin": 2,
    "square-2pin": 2,
    "round-2pin-vertical": 2,
]

func normalizeRows(shape: String, rows: [Row]) -> [Row] {
    guard let forced = forcedRowCount[shape] else { return rows }
    let flat = rows.flatMap { $0.pins }
    guard !flat.isEmpty else { return rows }
    let rowSize = Int((Double(flat.count) / Double(forced)).rounded(.up))
    var out: [Row] = []
    var i = 0
    while i < flat.count {
        let slice = Array(flat[i..<min(i + rowSize, flat.count)])
        out.append(Row(row: out.count + 1, positions: slice.count, pins: slice))
        i += rowSize
    }
    return out
}

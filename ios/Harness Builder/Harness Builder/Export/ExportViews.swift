//
//  ExportViews.swift
//  Harness Builder
//
//  The pages that get exported: a static drawing of the harness, the wire
//  table, and the PDF pages / PNG sheet built from them.
//

import SwiftUI

// MARK: - the drawing

/// The whole harness, drawn full size with no pan or zoom.
struct ExportDrawing: View {
    let connectors: [Connector]

    static func size(for connectors: [Connector]) -> CGSize {
        let l = HarnessLayout(connectors: connectors)
        return CGSize(width: l.worldWidth, height: l.worldHeight)
    }

    var body: some View {
        let layout = HarnessLayout(connectors: connectors)
        ZStack(alignment: .topLeading) {
            TrunkLayer(layout: layout)
            LeadsLayer(layout: layout)
            ForEach(layout.items) { item in
                PlugItemView(item: item, shiftX: layout.shiftX, selected: false, linked: false,
                             showRoles: true, canUp: false, canDown: false, counterScale: 1,
                             onMove: { _ in }, onTap: {})
            }
        }
        .frame(width: layout.worldWidth, height: layout.worldHeight, alignment: .topLeading)
    }
}

/// The drawing scaled by k, taking exactly the scaled size.
struct ScaledExportDrawing: View {
    let connectors: [Connector]
    let k: CGFloat

    var body: some View {
        let size = ExportDrawing.size(for: connectors)
        ExportDrawing(connectors: connectors)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .scaleEffect(k, anchor: .topLeading)
            .frame(width: size.width * k, height: size.height * k, alignment: .topLeading)
    }
}

// MARK: - the wire table

private enum Col {
    static let pin: CGFloat = 26
    static let swatch: CGFloat = 26
    static let color: CGFloat = 100
    static let gauge: CGFloat = 40
    static let type: CGFloat = 56
    static let sure: CGFloat = 66
}

private func sureLabel(_ c: String?) -> String {
    switch c {
    case "High": return "Sure"
    case "Med-High": return "Pretty sure"
    case "Med": return "Probably"
    case "Low-Med": return "Unsure"
    case "Low": return "Just a guess"
    default: return ""
    }
}

private func typeLabel(_ role: String?) -> String {
    switch role {
    case "power": return "Hot"
    case "signal": return "Signal"
    case "ground": return "Ground"
    default: return ""
    }
}

/// One plug's title and column captions.
struct ExportPlugHeader: View {
    let connector: Connector

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(connector.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.idText)
                Spacer()
                Text("\(connector.pinCount) pins")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.nameText)
            }
            HStack(spacing: 8) {
                Text("Pin").frame(width: Col.pin, alignment: .trailing)
                Text("").frame(width: Col.swatch)
                Text("Color").frame(width: Col.color, alignment: .leading)
                Text("Function").frame(maxWidth: .infinity, alignment: .leading)
                Text("AWG").frame(width: Col.gauge, alignment: .leading)
                Text("Type").frame(width: Col.type, alignment: .leading)
                Text("Sure?").frame(width: Col.sure, alignment: .leading)
            }
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(Palette.nameText)
        }
        .frame(height: HarnessExporter.headH, alignment: .bottom)
    }
}

/// One wire.
struct ExportWireRow: View {
    let fp: FlatPin

    var body: some View {
        let p = fp.pin
        HStack(spacing: 8) {
            Text("\(fp.number)")
                .foregroundStyle(Palette.idText)
                .frame(width: Col.pin, alignment: .trailing)
            if p.populated {
                ColorSwatch(code: p.color, width: Col.swatch, height: 12)
                Text(WireColor.label(p.color)).frame(width: Col.color, alignment: .leading)
                Text(p.guess ?? "").frame(maxWidth: .infinity, alignment: .leading)
                Text(p.gauge.map { "\($0)" } ?? "").frame(width: Col.gauge, alignment: .leading)
                Text(typeLabel(p.role)).frame(width: Col.type, alignment: .leading)
                Text(sureLabel(p.confidence)).frame(width: Col.sure, alignment: .leading)
            } else {
                Color.clear.frame(width: Col.swatch, height: 1)
                Text("Empty")
                    .foregroundStyle(Palette.nameText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(Palette.chipText)
        .lineLimit(1)
        .frame(height: HarnessExporter.rowH)
    }
}

// MARK: - PDF pages

/// Page 1 of a harness: its name and the whole drawing, scaled to fit.
struct ExportCoverPage: View {
    let harness: Harness

    var body: some View {
        let m = HarnessExporter.margin
        let size = ExportDrawing.size(for: harness.connectors)
        let availW = HarnessExporter.pageW - m * 2
        let availH = HarnessExporter.pageH - m * 2 - 56
        let k = min(availW / size.width, availH / size.height, 1.5)
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(harness.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(harness.connectors.count) plugs")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.nameText)
            }
            .frame(height: 44, alignment: .topLeading)
            ScaledExportDrawing(connectors: harness.connectors, k: k)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .padding(m)
        .frame(width: HarnessExporter.pageW, height: HarnessExporter.pageH, alignment: .topLeading)
        .background(Palette.bg)
    }
}

enum ExportTableItem {
    case header(Connector)
    case row(FlatPin)
}

/// One page of the wire table.
struct ExportTablePage: View {
    let title: String
    let items: [ExportTableItem]
    let page: Int
    let pages: Int

    var body: some View {
        let m = HarnessExporter.margin
        VStack(alignment: .leading, spacing: 0) {
            Text("\(title): wires (page \(page) of \(pages))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.nameText)
                .frame(height: HarnessExporter.pageTitleH, alignment: .topLeading)
            ForEach(Array(items.enumerated()), id: \.offset) { item in
                switch item.element {
                case .header(let c): ExportPlugHeader(connector: c)
                case .row(let fp): ExportWireRow(fp: fp)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(m)
        .frame(width: HarnessExporter.pageW, height: HarnessExporter.pageH, alignment: .topLeading)
        .background(Palette.bg)
    }
}

// MARK: - PNG sheet

/// One tall image: name, drawing, and (optionally) all the wires.
struct ExportImageSheet: View {
    let harness: Harness
    let includeTable: Bool

    static let width: CGFloat = 720
    static let pad: CGFloat = 24
    static let titleH: CGFloat = 44

    static func drawingScale(_ connectors: [Connector]) -> CGFloat {
        let size = ExportDrawing.size(for: connectors)
        return min(1.2, (width - pad * 2) / size.width)
    }

    /// Height of the whole sheet, in points (rows have fixed heights).
    static func height(_ harness: Harness, includeTable: Bool) -> CGFloat {
        let size = ExportDrawing.size(for: harness.connectors)
        var h = pad * 2 + titleH + 14 + size.height * drawingScale(harness.connectors)
        if includeTable {
            for c in harness.connectors {
                h += 14 + HarnessExporter.headH + HarnessExporter.rowH * CGFloat(c.flatPins.count)
            }
        }
        return h
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(harness.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(harness.connectors.count) plugs")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.nameText)
            }
            .frame(height: Self.titleH, alignment: .topLeading)

            ScaledExportDrawing(connectors: harness.connectors, k: Self.drawingScale(harness.connectors))

            if includeTable {
                ForEach(harness.connectors) { c in
                    VStack(alignment: .leading, spacing: 0) {
                        ExportPlugHeader(connector: c)
                        ForEach(c.flatPins, id: \.number) { fp in
                            ExportWireRow(fp: fp)
                        }
                    }
                }
            }
        }
        .padding(Self.pad)
        .frame(width: Self.width, alignment: .topLeading)
        .background(Palette.bg)
    }
}

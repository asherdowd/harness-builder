//
//  HarnessExporter.swift
//  Harness Builder
//
//  Turns harnesses into a PDF (one file, a page for each harness plus its
//  wire table pages), PNG images (one per harness) or a CSV wire list,
//  saved in a temporary folder so they can be shared.
//

import SwiftUI
import UIKit

enum ExportError: LocalizedError {
    case couldNotCreate
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .couldNotCreate: return "The file could not be created."
        case .renderFailed: return "The image could not be drawn. Try the PDF instead."
        }
    }
}

@MainActor
enum HarnessExporter {
    enum Format: Hashable {
        case pdf, png, csv
    }

    // US Letter, in points.
    nonisolated static let pageW: CGFloat = 612
    nonisolated static let pageH: CGFloat = 792
    nonisolated static let margin: CGFloat = 36
    nonisolated static let pageTitleH: CGFloat = 24
    nonisolated static let rowH: CGFloat = 22
    nonisolated static let headH: CGFloat = 34

    /// Keeps PNGs inside what the renderer handles reliably.
    private static let maxPixels: CGFloat = 10000

    static func export(_ harnesses: [Harness], includeTable: Bool, format: Format, allHarnesses: [Harness]? = nil) throws -> [URL] {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        switch format {
        case .pdf:
            let name = harnesses.count == 1 ? fileName(harnesses[0].title) : "Harnesses"
            let url = dir.appendingPathComponent(name + ".pdf")
            try writePDF(harnesses, includeTable: includeTable, to: url)
            return [url]
        case .csv:
            let name = harnesses.count == 1 ? fileName(harnesses[0].title) + "-wires" : "Harnesses-wires"
            let url = dir.appendingPathComponent(name + ".csv")
            do {
                try WireListCSV.csv(harnesses, allHarnesses: allHarnesses).write(to: url, atomically: true, encoding: .utf8)
            } catch {
                throw ExportError.couldNotCreate
            }
            return [url]
        case .png:
            return try harnesses.enumerated().map { i, h in
                let prefix = harnesses.count > 1 ? "\(i + 1)-" : ""
                let url = dir.appendingPathComponent(prefix + fileName(h.title) + ".png")
                try writePNG(h, includeTable: includeTable, to: url)
                return url
            }
        }
    }

    private static func fileName(_ title: String) -> String {
        let cleaned = title.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "-" }
        let name = String(cleaned).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return name.isEmpty ? "Harness" : name
    }

    // MARK: PDF

    private static func writePDF(_ harnesses: [Harness], includeTable: Bool, to url: URL) throws {
        var box = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { throw ExportError.couldNotCreate }
        for h in harnesses {
            addPage(ctx, ExportCoverPage(harness: h))
            if includeTable {
                let pages = paginate(h)
                for (i, items) in pages.enumerated() {
                    addPage(ctx, ExportTablePage(title: h.title, items: items, page: i + 1, pages: pages.count))
                }
            }
        }
        ctx.closePDF()
    }

    private static func addPage<V: View>(_ ctx: CGContext, _ view: V) {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.proposedSize = ProposedViewSize(width: pageW, height: pageH)
        renderer.render { _, draw in
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
        }
    }

    /// Splits the wire table over pages. A plug's title never sits alone at the bottom of a page.
    static func paginate(_ harness: Harness) -> [[ExportTableItem]] {
        var items: [ExportTableItem] = []
        for c in harness.connectors {
            items.append(.header(c))
            for fp in c.flatPins { items.append(.row(fp)) }
        }
        let avail = pageH - margin * 2 - pageTitleH
        var pages: [[ExportTableItem]] = []
        var current: [ExportTableItem] = []
        var used: CGFloat = 0
        for item in items {
            let height: CGFloat
            let needed: CGFloat
            switch item {
            case .header: height = headH; needed = headH + rowH
            case .row: height = rowH; needed = rowH
            }
            if used + needed > avail, !current.isEmpty {
                pages.append(current)
                current = []
                used = 0
            }
            current.append(item)
            used += height
        }
        if !current.isEmpty { pages.append(current) }
        return pages.isEmpty ? [[]] : pages
    }

    // MARK: PNG

    private static func writePNG(_ harness: Harness, includeTable: Bool, to url: URL) throws {
        let height = ExportImageSheet.height(harness, includeTable: includeTable)
        let renderer = ImageRenderer(content: ExportImageSheet(harness: harness, includeTable: includeTable).environment(\.colorScheme, .dark))
        renderer.scale = max(0.5, min(2, maxPixels / max(height, 1)))
        guard let image = renderer.uiImage, let data = image.pngData() else { throw ExportError.renderFailed }
        try data.write(to: url, options: .atomic)
    }
}

//
//  SVGExportTests.swift
//  Harness BuilderTests
//
//  The SVG export: valid XML, the right size, every pin and plug name drawn,
//  every shape drawable, and the colors matching the app's palette.
//

import Foundation
import SwiftUI
import Testing
@testable import Harness_Builder

@MainActor
struct SVGExportTests {
    /// Counts elements while checking the text is well-formed XML.
    private final class Counter: NSObject, XMLParserDelegate {
        var counts: [String: Int] = [:]
        var root: [String: String] = [:]
        var texts: [String] = []
        private var current = ""
        private var first = true

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
            counts[name, default: 0] += 1
            if first { root = attributes; first = false }
            current = ""
        }
        func parser(_ parser: XMLParser, foundCharacters string: String) { current += string }
        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            if name == "text" { texts.append(current) }
        }
    }

    private func parse(_ svg: String) throws -> Counter {
        let counter = Counter()
        let parser = XMLParser(data: Data(svg.utf8))
        parser.delegate = counter
        #expect(parser.parse(), "not well-formed: \(parser.parserError?.localizedDescription ?? "?")")
        return counter
    }

    private func harness() -> Harness {
        let a = Fixture.connector("A", name: "Fuel & pump <1>", pins: [Fixture.pin(1), Fixture.pin(2, populated: false), Fixture.pin(3, role: "power")])
        let b = Fixture.connector("B", name: "ECU", pins: Fixture.pins(4), perRow: 2)
        return Fixture.harness("H1", title: "Engine", plugs: [a, b])
    }

    @Test func theSVGIsWellFormedAndTheSizeOfTheDrawing() throws {
        let h = harness()
        let counter = try parse(HarnessSVG.svg(for: h))
        let size = ExportDrawing.size(for: h.connectors)
        #expect(counter.counts["svg"] == 1)
        #expect(counter.root["viewBox"] == "0 0 \(HarnessSVG.n(size.width)) \(HarnessSVG.n(size.height))")
    }

    @Test func everyPinIsDrawnOnce() throws {
        let h = harness()
        let counter = try parse(HarnessSVG.svg(for: h))
        let pins = h.connectors.reduce(0) { $0 + $1.flatPins.count }
        // Each pin is a circle; the role badge, the leads' dots and the plug bodies add more.
        let rolesBadges = 1
        let leadDots = h.connectors.count
        #expect((counter.counts["circle"] ?? 0) >= pins + rolesBadges + leadDots)
    }

    @Test func plugNamesAreDrawnAndEscaped() throws {
        let svg = HarnessSVG.svg(for: harness())
        let counter = try parse(svg)
        #expect(counter.texts.contains("Fuel & pump <1>"))
        #expect(svg.contains("Fuel &amp; pump &lt;1&gt;"))
        #expect(counter.texts.contains("3 pins"))
    }

    @Test func aHarnessWithNoPlugsStillMakesAnSVG() throws {
        let counter = try parse(HarnessSVG.svg(for: Fixture.harness("H1")))
        #expect(counter.counts["svg"] == 1)
    }

    @Test func everyShapeMakesAnSVG() throws {
        for def in ShapeCatalog.all {
            var d = PlugDraft(newShape: def.key)
            d.name = def.label
            let h = Fixture.harness("H1", plugs: [d.connector()])
            let svg = HarnessSVG.svg(for: h)
            _ = try parse(svg)
            #expect(!svg.contains("nan"), "\(def.key)")
            #expect(!svg.contains("inf"), "\(def.key)")
        }
    }

    @Test func aSixtyPinPlugMakesAnSVG() throws {
        let big = Fixture.connector("E1", name: "ECU", pins: Fixture.pins(60), perRow: 10)
        let counter = try parse(HarnessSVG.svg(for: Fixture.harness("H1", plugs: [big])))
        #expect((counter.counts["circle"] ?? 0) >= 60)
    }

    // MARK: styles and colors

    @Test func theDarkSVGUsesThePalettesDarkColors() {
        let svg = HarnessSVG.svg(for: harness(), style: .dark)
        #expect(svg.contains("fill=\"#12151a\""))          // Palette.bg, dark
        #expect(svg.contains("#e2a355"))                   // pin fill
    }

    @Test func thePrintSVGHasAWhitePageAndWhitePlugs() {
        let svg = HarnessSVG.svg(for: harness(), style: .print)
        #expect(svg.contains("<rect width=") && svg.contains("fill=\"#ffffff\""))
        #expect(!svg.contains("fill=\"#12151a\""))
        #expect(!svg.contains("#b0b6bd"))                  // the light-mode gray plug body is not used
    }

    @Test func resolvedColorsMatchThePalette() {
        let dark = HarnessSVG.Colors(style: .dark)
        let light = HarnessSVG.Colors(style: .print)
        #expect(dark.bg == "#12151a")
        #expect(dark.bodyStroke == "#7c8794")
        #expect(light.bodyStroke == "#4a525d")
        #expect(light.page == "#ffffff")
    }

    // MARK: helpers and files

    @Test func numbersAreShortAndUseADot() {
        #expect(HarnessSVG.n(12) == "12")
        #expect(HarnessSVG.n(12.5) == "12.5")
        #expect(HarnessSVG.n(1.004) == "1")
        #expect(HarnessSVG.n(-0.001) == "0")
    }

    @Test func aPathBecomesPathData() {
        var p = Path()
        p.move(to: CGPoint(x: 1, y: 2))
        p.addLine(to: CGPoint(x: 3, y: 4))
        p.closeSubpath()
        #expect(HarnessSVG.path(p) == "M1 2 L3 4 Z")
    }

    @Test func svgExportWritesOneFilePerHarness() throws {
        let hs = [harness(), Fixture.harness("H2", title: "Firewall", plugs: [Fixture.connector("C", pins: Fixture.pins(2))])]
        let urls = try HarnessExporter.export(hs, includeTable: false, format: .svg)
        defer { if let u = urls.first { try? FileManager.default.removeItem(at: u.deletingLastPathComponent()) } }
        #expect(urls.count == 2)
        #expect(urls.allSatisfy { $0.pathExtension == "svg" })
        let text = try String(contentsOf: urls[0], encoding: .utf8)
        #expect(text.hasPrefix("<?xml"))
    }
}

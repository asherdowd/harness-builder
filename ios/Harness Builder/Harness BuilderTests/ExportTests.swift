//
//  ExportTests.swift
//  Harness BuilderTests
//
//  Export: how the wire table is split over pages, and that real PDF and PNG
//  files come out (including for a harness with several 60-pin plugs).
//

import Foundation
import Testing
@testable import Harness_Builder

@MainActor
struct ExportPaginationTests {
    private let available = HarnessExporter.pageH - HarnessExporter.margin * 2 - HarnessExporter.pageTitleH

    private func harness(plugs: Int, pinsEach: Int) -> Harness {
        Fixture.harness("H1", plugs: (1...max(plugs, 1)).prefix(plugs).map {
            Fixture.connector("P\($0)", pins: Fixture.pins(pinsEach), perRow: min(pinsEach, 10))
        })
    }

    private func height(_ item: ExportTableItem) -> CGFloat {
        switch item {
        case .header: return HarnessExporter.headH
        case .row: return HarnessExporter.rowH
        }
    }

    @Test func anEmptyHarnessStillGetsOneEmptyPage() {
        let pages = HarnessExporter.paginate(Fixture.harness("H1"))
        #expect(pages.count == 1)
        #expect(pages[0].isEmpty)
    }

    @Test func aSmallHarnessFitsOnOnePage() {
        let pages = HarnessExporter.paginate(harness(plugs: 2, pinsEach: 6))
        #expect(pages.count == 1)
    }

    @Test func everyPlugAndPinAppearsExactlyOnce() {
        let h = harness(plugs: 5, pinsEach: 26)
        let items = HarnessExporter.paginate(h).flatMap { $0 }
        let headers = items.filter { if case .header = $0 { return true } else { return false } }
        let rows = items.filter { if case .row = $0 { return true } else { return false } }
        #expect(headers.count == 5)
        #expect(rows.count == 5 * 26)
    }

    @Test func noPageIsOverfull() {
        for pages in [HarnessExporter.paginate(harness(plugs: 5, pinsEach: 26)),
                      HarnessExporter.paginate(harness(plugs: 1, pinsEach: 60)),
                      HarnessExporter.paginate(harness(plugs: 8, pinsEach: 60))] {
            for page in pages {
                let used = page.reduce(CGFloat(0)) { $0 + height($1) }
                #expect(used <= available, "a page uses \(used) of \(available)")
            }
        }
    }

    @Test func aPlugTitleNeverSitsAloneAtTheBottomOfAPage() {
        for h in [harness(plugs: 7, pinsEach: 26), harness(plugs: 3, pinsEach: 59), harness(plugs: 9, pinsEach: 13)] {
            for (i, page) in HarnessExporter.paginate(h).enumerated() {
                if case .header? = page.last { Issue.record("page \(i + 1) ends with a plug title") }
            }
        }
    }

    @Test func aSixtyPinPlugSpillsOntoMorePages() {
        let pages = HarnessExporter.paginate(harness(plugs: 1, pinsEach: 60))
        #expect(pages.count >= 2)
        #expect(pages.flatMap { $0 }.count == 61)
    }

    @Test func pagesKeepPlugsInHarnessOrder() {
        let h = harness(plugs: 4, pinsEach: 30)
        let order = HarnessExporter.paginate(h).flatMap { $0 }.compactMap { item -> String? in
            if case .header(let c) = item { return c.id } else { return nil }
        }
        #expect(order == ["P1", "P2", "P3", "P4"])
    }
}

@MainActor
struct ExportFileTests {
    private func bigHarness() -> Harness {
        Fixture.harness("H1", title: "Big ECU harness", plugs: (1...3).map {
            Fixture.connector("E\($0)", name: "ECU plug \($0)", pins: Fixture.pins(60), perRow: 10)
        })
    }

    private func read(_ url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    @Test func pdfOfOneHarnessIsARealPDF() throws {
        let h = Fixture.harness("H1", title: "Dash", plugs: [Fixture.connector("A", pins: Fixture.pins(8), perRow: 4)])
        let urls = try HarnessExporter.export([h], includeTable: true, format: .pdf)
        #expect(urls.count == 1)
        let data = try read(urls[0])
        #expect(urls[0].pathExtension == "pdf")
        #expect(data.count > 1000)
        #expect(data.prefix(5) == Data("%PDF-".utf8))
    }

    @Test func pdfOfAllHarnessesIsOneFile() throws {
        let hs = [Fixture.harness("H1", title: "One", plugs: [Fixture.connector("A", pins: Fixture.pins(4))]),
                  Fixture.harness("H2", title: "Two", plugs: [Fixture.connector("B", pins: Fixture.pins(4))])]
        let urls = try HarnessExporter.export(hs, includeTable: false, format: .pdf)
        #expect(urls.count == 1)
        #expect(urls[0].lastPathComponent == "Harnesses.pdf")
    }

    @Test func pngMakesOneImagePerHarness() throws {
        let hs = [Fixture.harness("H1", title: "One", plugs: [Fixture.connector("A", pins: Fixture.pins(4))]),
                  Fixture.harness("H2", title: "Two", plugs: [Fixture.connector("B", pins: Fixture.pins(4))])]
        let urls = try HarnessExporter.export(hs, includeTable: true, format: .png)
        #expect(urls.count == 2)
        for url in urls {
            let data = try read(url)
            #expect(data.count > 1000)
            #expect(data.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))        // PNG signature
        }
    }

    @Test func fileNamesAreSafe() throws {
        let h = Fixture.harness("H1", title: "Dash / engine: bay?", plugs: [Fixture.connector("A", pins: Fixture.pins(2))])
        let url = try #require(try HarnessExporter.export([h], includeTable: false, format: .pdf).first)
        let name = url.deletingPathExtension().lastPathComponent
        #expect(!name.contains("/") && !name.contains(":") && !name.contains("?"))
        #expect(!name.isEmpty)
    }

    @Test func aTitleWithNothingUsableStillGetsAName() throws {
        let h = Fixture.harness("H1", title: "???", plugs: [Fixture.connector("A", pins: Fixture.pins(2))])
        let url = try #require(try HarnessExporter.export([h], includeTable: false, format: .pdf).first)
        #expect(url.lastPathComponent == "Harness.pdf")
    }

    @Test func aHarnessOfSixtyPinPlugsExportsToPDF() throws {
        let urls = try HarnessExporter.export([bigHarness()], includeTable: true, format: .pdf)
        let data = try read(urls[0])
        #expect(data.count > 5000)
        #expect(data.prefix(5) == Data("%PDF-".utf8))
    }

    @Test func aHarnessOfSixtyPinPlugsExportsToPNG() throws {
        let urls = try HarnessExporter.export([bigHarness()], includeTable: true, format: .png)
        let data = try read(urls[0])
        #expect(data.count > 5000)
        #expect(data.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func eachExportGoesInItsOwnFolder() throws {
        let h = Fixture.harness("H1", title: "Dash", plugs: [Fixture.connector("A", pins: Fixture.pins(2))])
        let a = try #require(try HarnessExporter.export([h], includeTable: false, format: .pdf).first)
        let b = try #require(try HarnessExporter.export([h], includeTable: false, format: .pdf).first)
        #expect(a.deletingLastPathComponent() != b.deletingLastPathComponent())
    }
}

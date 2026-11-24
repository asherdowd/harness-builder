//
//  LayoutTests.swift
//  Harness BuilderTests
//
//  Where plugs sit on the trunk, and that every plug shape can be drawn.
//

import CoreGraphics
import Testing
@testable import Harness_Builder

@MainActor
struct LayoutTests {
    private func plugs(_ n: Int, shape: String = "square-4pin", pinsEach: Int = 4) -> [Connector] {
        (1...n).map { Fixture.connector("P\($0)", shape: shape, pins: Fixture.pins(pinsEach)) }
    }

    @Test func plugsAlternateSidesAlongTheTrunk() {
        let layout = HarnessLayout(connectors: plugs(4))
        #expect(layout.items.map(\.side) == [-1, 1, -1, 1])
        #expect(layout.items[0].x < 0)
        #expect(layout.items[1].x > 0)
    }

    @Test func plugsRunDownTheTrunkInOrder() {
        let layout = HarnessLayout(connectors: plugs(6))
        let ys = layout.items.map(\.y)
        #expect(ys == ys.sorted())
        #expect(Set(ys).count == ys.count)
        #expect(layout.items.map(\.id) == ["P1", "P2", "P3", "P4", "P5", "P6"])
    }

    @Test func plugsNeverOverlapTheOneBeforeThatOnTheSameSide() {
        let layout = HarnessLayout(connectors: plugs(6, shape: "rectangular-block", pinsEach: 8))
        for i in 2..<layout.items.count {
            let a = layout.items[i - 2], b = layout.items[i]
            #expect(b.y - a.y >= (a.height + b.height) / 2, "plugs \(i - 1) and \(i + 1) overlap")
        }
    }

    @Test func everyPlugFitsInsideTheDrawing() {
        let layout = HarnessLayout(connectors: plugs(5, shape: "rectangular-block", pinsEach: 14))
        for p in layout.items {
            #expect(p.x - p.width / 2 + layout.shiftX >= 0)
            #expect(p.x + p.width / 2 + layout.shiftX <= layout.worldWidth)
            #expect(p.y + p.height / 2 <= layout.worldHeight)
        }
    }

    @Test func anEmptyHarnessStillHasASize() {
        let layout = HarnessLayout(connectors: [])
        #expect(layout.items.isEmpty)
        #expect(layout.worldWidth > 0)
        #expect(layout.worldHeight > 0)
    }

    @Test func moreWidePlugsMakeTheDrawingTallerNotInfinite() {
        let layout = HarnessLayout(connectors: plugs(12, shape: "rectangular-block", pinsEach: 60))
        #expect(layout.worldWidth.isFinite)
        #expect(layout.worldHeight.isFinite)
        #expect(layout.worldHeight > HarnessLayout(connectors: plugs(2)).worldHeight)
    }

    @Test func sixtyPinPlugHasAllItsPinsDrawn() {
        let c = Fixture.connector("ECU", shape: "rectangular-block", pins: Fixture.pins(60), perRow: 10)
        let art = ArtModel.make(for: c)
        #expect(art.pins.count == 60)
        #expect(art.width > 0)
        #expect(art.height > 0)
        #expect(art.width.isFinite && art.height.isFinite)
    }

    @Test func aShapeWeHaveNoDrawingForIsShownLoudly() {
        let c = Fixture.connector("X", shape: "made-up-shape", pins: Fixture.pins(2))
        if case .unknown = ArtModel.make(for: c).kind {} else { Issue.record("expected the unknown marker") }
        var provisional = c
        provisional.shapeProvisional = true
        if case .provisional = ArtModel.make(for: provisional).kind {} else { Issue.record("expected the dashed placeholder") }
    }

    @Test func fixedFourPinPlugIsRegroupedIntoTwoRows() {
        let c = Fixture.connector("S", shape: "square-4pin", pins: Fixture.pins(4), perRow: 4)
        #expect(normalizeRows(shape: c.shape, rows: c.rows).map { $0.pins.count } == [2, 2])
    }
}

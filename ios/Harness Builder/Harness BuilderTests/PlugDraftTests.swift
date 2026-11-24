//
//  PlugDraftTests.swift
//  Harness BuilderTests
//
//  The plug wizard's model: sizes, limits, changing shape, and the
//  data-loss counting behind the "Data will be lost" warning.
//

import Testing
@testable import Harness_Builder

@MainActor
struct PlugDraftTests {
    // MARK: shapes and limits

    @Test func limitsAllowSixtyPins() {
        #expect(ShapeLimits.maxPins == 60)
        #expect(ShapeLimits.maxRows * ShapeLimits.maxCols >= ShapeLimits.maxPins)
    }

    @Test func shapeKeysAreUnique() {
        let keys = ShapeCatalog.all.map(\.key)
        #expect(Set(keys).count == keys.count)
        for d in ShapeCatalog.all {
            #expect(ShapeCatalog.def(d.key)?.label == d.label)
        }
        #expect(ShapeCatalog.def("not-a-shape") == nil)
    }

    @Test func everyShapeBuildsADrawablePlug() {
        for d in ShapeCatalog.all {
            let draft = PlugDraft(newShape: d.key)
            #expect(!draft.pins.isEmpty, "\(d.key) has no pins")
            var c = draft.connector()
            c.shapeProvisional = nil
            if case .unknown = ArtModel.make(for: c).kind {
                Issue.record("\(d.key) cannot be drawn")
            }
        }
    }

    // MARK: new plugs

    @Test func newBlockStartsAsTwoRowsOfFour() {
        let d = PlugDraft(newShape: "rectangular-block")
        #expect(d.rowCount == 2)
        #expect(d.colCount == 4)
        #expect(d.total == 8)
        #expect(d.pins.count == 8)
        #expect(d.pins.map(\.position) == Array(1...8))
        #expect(d.pins.allSatisfy { $0.populated && $0.confidence == "High" })
    }

    @Test func fixedShapesKeepTheirPinCount() {
        #expect(PlugDraft(newShape: "square-4pin").pins.count == 4)
        #expect(PlugDraft(newShape: "square-2pin").pins.count == 2)
        #expect(PlugDraft(newShape: "single-bullet").pins.count == 1)
        #expect(PlugDraft(newShape: "soldered-splice").pins.count == 3)
    }

    @Test func untouchedNewPlugHasNoChanges() {
        var d = PlugDraft(newShape: "rectangular-block")
        #expect(!d.hasChanges)
        d.name = "Dash plug"
        #expect(d.hasChanges)
    }

    @Test(arguments: ["color", "guess", "role", "gauge", "empty"])
    func settingAnythingOnAPinCountsAsAChange(_ what: String) {
        var d = PlugDraft(newShape: "square-4pin")
        switch what {
        case "color": d.pins[0].color = "RED"
        case "guess": d.pins[0].guess = "Horn"
        case "role": d.pins[0].role = "power"
        case "gauge": d.pins[0].gauge = 18
        default: d.pins[0].populated = false
        }
        #expect(d.hasChanges)
    }

    @Test func coloredCountOnlyCountsWiresWithAColor() {
        var d = PlugDraft(newShape: "square-4pin")
        d.pins[0].color = "RED"
        d.pins[1].color = "BLK"
        d.pins[1].populated = false      // empty pin: not counted
        d.pins[2].color = ""
        #expect(d.coloredCount == 1)
    }

    // MARK: resizing

    @Test func growingKeepsExistingPinsInOrder() {
        var d = PlugDraft(newShape: "rectangular-block")
        d.pins[0].color = "RED"
        d.pins[7].guess = "Last"
        d.resize(cols: 6)
        #expect(d.pins.count == 12)
        #expect(d.pins[0].color == "RED")
        #expect(d.pins[7].guess == "Last")
        #expect(d.pins[8].color == nil)
    }

    @Test func shrinkingKeepsTheFirstPins() {
        var d = PlugDraft(newShape: "rectangular-block")
        d.pins[0].color = "RED"
        d.resize(cols: 2)
        #expect(d.pins.count == 4)
        #expect(d.pins[0].color == "RED")
    }

    @Test func sixtyPinPlugBuildsSixRowsOfTen() {
        var d = PlugDraft(newShape: "rectangular-block")
        d.resize(rows: 6, cols: 10)
        #expect(d.total == 60)
        #expect(d.pins.count == 60)
        let rows = d.buildRows()
        #expect(rows.count == 6)
        #expect(rows.allSatisfy { $0.pins.count == 10 && $0.positions == 10 })
        #expect(rows[0].pins.map(\.position) == Array(1...10))
        #expect(rows.flatMap(\.pins).count == 60)
        #expect(d.connector().flatPins.map(\.number) == Array(1...60))
    }

    @Test func inlineBlockIsASingleRow() {
        var d = PlugDraft(newShape: "inline-block")
        d.resize(cols: 16)
        let rows = d.buildRows()
        #expect(rows.count == 1)
        #expect(rows[0].pins.count == 16)
    }

    // MARK: changing shape

    @Test func changingShapeKeepsPinsInOrder() {
        var d = PlugDraft(newShape: "rectangular-block")      // 8 pins
        d.pins[0].color = "RED"
        d.pins[5].guess = "Sixth"
        d.changeShape(to: "inline-block")
        #expect(d.shape == "inline-block")
        #expect(d.rowCount == 1)
        #expect(d.pins.count == 8)
        #expect(d.pins[0].color == "RED")
        #expect(d.pins[5].guess == "Sixth")
    }

    @Test func changingToAFixedShapeUsesItsPinCount() {
        var d = PlugDraft(newShape: "rectangular-block")
        d.pins[0].color = "RED"
        d.changeShape(to: "square-4pin")
        #expect(d.pins.count == 4)
        #expect(d.pins[0].color == "RED")
    }

    @Test func changingToTheSameOrAnUnknownShapeDoesNothing() {
        var d = PlugDraft(newShape: "rectangular-block")
        d.pins[0].color = "RED"
        let before = d.pins
        d.changeShape(to: "rectangular-block")
        d.changeShape(to: "not-a-shape")
        #expect(d.pins == before)
        #expect(d.shape == "rectangular-block")
    }

    @Test func largePlugMovedToABlockStaysWithinTheLimits() {
        var d = PlugDraft(newShape: "inline-block")
        d.resize(cols: 16)
        d.changeShape(to: "rectangular-block")
        #expect(d.pins.count == 16)
        #expect(d.rowCount <= ShapeLimits.maxRows)
        #expect(d.colCount <= ShapeLimits.maxCols)
    }

    // MARK: editing an existing plug

    private func twoRowPlug() -> Connector {
        Fixture.connector("A", name: "Dash", pins: Fixture.pins(5), perRow: 3)
    }

    @Test func untouchedEditHasNoChangesAndKeepsItsLayout() {
        let d = PlugDraft(editing: twoRowPlug())
        #expect(!d.hasChanges)
        #expect(d.pins.count == 5)
        #expect(d.name == "Dash")
        let rows = d.buildRows()
        #expect(rows.map { $0.pins.count } == [3, 2])
    }

    @Test func editingAPinKeepsTheImportedRows() {
        var d = PlugDraft(editing: twoRowPlug())
        d.pins[4].guess = "Changed"
        #expect(d.hasChanges)
        let c = d.connector()
        #expect(c.rows.map { $0.pins.count } == [3, 2])
        #expect(c.flatPins[4].pin.guess == "Changed")
        #expect(c.id == "A")
    }

    @Test func renamingCountsAsAChange() {
        var d = PlugDraft(editing: twoRowPlug())
        d.name = "Renamed"
        #expect(d.hasChanges)
    }

    @Test func touchingTheSizeReplacesTheImportedLayout() {
        var d = PlugDraft(editing: twoRowPlug())
        d.resize(cols: 4)
        #expect(d.hasChanges)
    }

    @Test func nothingIsLostWhenNoWiredPinIsRemoved() {
        var d = PlugDraft(editing: twoRowPlug())
        d.resize(cols: 3)               // 2 rows x 3 = 6 pins: bigger, nothing dropped
        #expect(d.droppedWiredCount == 0)
    }

    @Test func removedWiredPinsAreCounted() {
        var plug = Fixture.connector("A", shape: "rectangular-block", pins: Fixture.pins(6), perRow: 3)
        plug.rows[1].pins[2] = Fixture.pin(6, color: nil, guess: nil, populated: false)   // an empty pin
        var d = PlugDraft(editing: plug)
        d.resize(cols: 2)               // 2 rows x 2 = 4 pins: pins 5 and 6 are removed
        #expect(d.pins.count == 4)
        #expect(d.droppedWiredCount == 1)        // pin 5 had a wire; pin 6 was empty
    }

    @Test func aPinWithOnlyAFunctionCountsAsWired() {
        var plug = Fixture.connector("A", shape: "rectangular-block", pins: Fixture.pins(4), perRow: 2)
        plug.rows[1].pins[1] = Fixture.pin(4, color: nil, guess: "Horn")
        var d = PlugDraft(editing: plug)
        d.resize(cols: 1)               // 2 pins left
        #expect(d.droppedWiredCount == 2)
    }

    @Test func shrinkingABigPlugToInlineReportsTheLoss() {
        let big = Fixture.connector("ECU", shape: "rectangular-block", pins: Fixture.pins(60), perRow: 10)
        var d = PlugDraft(editing: big)
        #expect(d.pins.count == 60)
        d.changeShape(to: "inline-block")
        #expect(d.pins.count == ShapeLimits.maxInlineCols)
        #expect(d.droppedWiredCount == 60 - ShapeLimits.maxInlineCols)
    }

    @Test func keepingThePinCountLosesNothing() {
        var d = PlugDraft(editing: Fixture.connector("A", shape: "rectangular-block", pins: Fixture.pins(8), perRow: 4))
        d.changeShape(to: "inline-block")
        #expect(d.pins.count == 8)
        #expect(d.droppedWiredCount == 0)
    }

    // MARK: the plug that gets saved

    @Test func newPlugIsMarkedAsBuiltOnTheDevice() {
        var d = PlugDraft(newShape: "square-4pin")
        d.name = "Horn"
        let c = d.connector()
        #expect(c.custom == true)
        #expect(c.name == "Horn")
        #expect(c.shape == "square-4pin")
        #expect(c.flatPins.count == 4)
    }
}

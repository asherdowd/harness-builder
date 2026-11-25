//
//  ProposalEngineTests.swift
//  Harness BuilderTests
//
//  The AI safety layer: what a proposal may ask for, what the preview reports,
//  and the guarantees (nothing deleted, nothing silently replaced or moved,
//  AI values marked as guesses, nothing changed by a preview).
//

import Foundation
import Testing
@testable import Harness_Builder

@MainActor
struct ProposalEngineTests {
    // MARK: fixtures

    private func spare(_ n: Int) -> Pin { Fixture.pin(n, color: nil, guess: nil, populated: false) }
    private func blank(_ n: Int) -> Pin { Fixture.pin(n, color: nil, guess: nil) }

    /// H1 has plugs A (3 wired pins with color and function) and B (blank wired pins, one spare).
    /// H2 has plug C.
    private func state() -> AppState {
        let a = Fixture.connector("A", name: "Alpha", pins: Fixture.pins(3))
        let b = Fixture.connector("B", name: "Bravo", pins: [blank(1), blank(2), spare(3)])
        let c = Fixture.connector("C", name: "Charlie", pins: [blank(1), blank(2)])
        return AppState(harnesses: [Fixture.harness("H1", plugs: [a, b]), Fixture.harness("H2", plugs: [c])], activeID: "H1")
    }

    private func preview(_ changes: [AIChange], _ s: AppState? = nil) -> ProposalPreview {
        ProposalEngine.preview(AIProposal(summary: "Test", changes: changes), on: s ?? state(), harnessID: "H1")
    }

    private func pin(_ p: ProposalPreview, _ plug: String, _ n: Int) -> Pin? {
        for h in p.after?.harnesses ?? [] {
            if let c = h.connectors.first(where: { $0.id == plug }) { return c.flatPins.first { $0.number == n }?.pin }
        }
        return nil
    }

    private func set(_ plug: String, _ pin: Int, color: String? = nil, function: String? = nil,
                     role: String? = nil, gauge: Int? = nil) -> AIChange {
        .setPin(plug: plug, pin: pin, color: color, function: function, role: role, gauge: gauge)
    }

    // MARK: the format

    @Test func everyChangeSurvivesJSON() throws {
        let proposal = AIProposal(summary: "All three", changes: [
            .addPlug(ref: "new1", shape: "rectangular-block", name: "Pump", rows: 2, cols: 4),
            .setPin(plug: "new1", pin: 1, color: "GRN/WHT", function: "Pump +", role: "power", gauge: 18),
            .connect(plugA: "new1", pinA: 1, plugB: "A", pinB: 2),
        ])
        let back = try JSONDecoder().decode(AIProposal.self, from: JSONEncoder().encode(proposal))
        #expect(back == proposal)
    }

    @Test func aProposalDecodesFromTheToolSchemaShape() throws {
        let json = """
        {"summary":"Wire it","changes":[
          {"type":"add_plug","ref":"p","shape":"square-2pin","name":"Relay"},
          {"type":"set_pin","plug":"p","pin":1,"color":"RED"},
          {"type":"connect","plug_a":"p","pin_a":1,"plug_b":"A","pin_b":1}]}
        """
        let p = try JSONDecoder().decode(AIProposal.self, from: Data(json.utf8))
        #expect(p.changes.count == 3)
        #expect(p.changes[0] == .addPlug(ref: "p", shape: "square-2pin", name: "Relay", rows: nil, cols: nil))
    }

    @Test func anUnknownKindOfChangeIsRejected() {
        let json = #"{"summary":"x","changes":[{"type":"delete_plug","plug":"A"}]}"#
        #expect(throws: (any Error).self) { try JSONDecoder().decode(AIProposal.self, from: Data(json.utf8)) }
    }

    // MARK: whole-proposal rules

    @Test func anEmptyProposalCannotBeApplied() {
        let p = preview([])
        #expect(!p.errors.isEmpty)
        #expect(!p.canApply)
        #expect(p.after == nil)
    }

    @Test func tooManyChangesAreRefused() {
        let many = Array(repeating: set("A", 1, color: "RED"), count: ProposalEngine.maxChanges + 1)
        #expect(!preview(many).errors.isEmpty)
    }

    @Test func aMissingHarnessIsRefused() {
        let p = ProposalEngine.preview(AIProposal(summary: "x", changes: [set("A", 1, color: "BLU")]), on: state(), harnessID: "NOPE")
        #expect(!p.canApply)
    }

    @Test func aPreviewChangesNothing() {
        let before = state()
        let p = preview([set("A", 1, color: "BLU"), .connect(plugA: "A", pinA: 1, plugB: "B", pinB: 1)], before)
        #expect(p.canApply)
        #expect(p.base == before)
        #expect(p.after != before)
    }

    @Test func oneBadChangeBlocksTheWholeProposal() {
        let p = preview([set("A", 1, color: "BLU"), set("A", 2, color: "PURPLE")])
        #expect(p.errors.count == 1)
        #expect(p.errors[0].hasPrefix("Change 2:"))
        #expect(p.after == nil)
        #expect(!p.canApply)
    }

    @Test func nothingIsEverDeleted() throws {
        let s = state()
        let p = preview([
            .addPlug(ref: "n", shape: "inline-block", name: "New", rows: nil, cols: 4),
            set("A", 1, color: "BLU", function: "Changed", role: "ground", gauge: 22),
            set("B", 3, color: "RED"),
            .connect(plugA: "A", pinA: 1, plugB: "C", pinB: 1),
        ], s)
        let after = try #require(p.after)
        let plugsBefore = s.harnesses.flatMap(\.connectors).count
        let plugsAfter = after.harnesses.flatMap(\.connectors).count
        let pinsBefore = s.harnesses.flatMap(\.connectors).reduce(0) { $0 + $1.flatPins.count }
        let pinsAfter = after.harnesses.flatMap(\.connectors).reduce(0) { $0 + $1.flatPins.count }
        #expect(plugsAfter == plugsBefore + 1)
        #expect(pinsAfter == pinsBefore + 4)
        #expect(after.harnesses.count == s.harnesses.count)
    }

    // MARK: addPlug

    @Test func aNewFixedPlugIsAddedWithTheNextID() throws {
        let p = preview([.addPlug(ref: "x", shape: "square-4pin", name: "  Fuel pump  ", rows: nil, cols: nil)])
        let after = try #require(p.after)
        let plug = try #require(after.harnesses[0].connectors.last)
        #expect(plug.id == "MY-01")
        #expect(plug.title == "Fuel pump")
        #expect(plug.custom == true)
        #expect(plug.totalPositions == 4)
        #expect(p.newPlugs == ["Fuel pump"])
    }

    @Test func aGridPlugTakesRowsAndColumns() throws {
        let p = preview([.addPlug(ref: "x", shape: "rectangular-block", name: "ECU", rows: 3, cols: 10)])
        let plug = try #require(p.after?.harnesses[0].connectors.last)
        #expect(plug.flatPins.count == 30)
        #expect(plug.rows.count == 3)
    }

    @Test func aPlugIsMadeOfWiredBlankPins() throws {
        let p = preview([.addPlug(ref: "x", shape: "square-2pin", name: "Relay", rows: nil, cols: nil)])
        let plug = try #require(p.after?.harnesses[0].connectors.last)
        #expect(plug.flatPins.allSatisfy { $0.pin.populated && ($0.pin.color ?? "").isEmpty })
    }

    @Test func badPlugsAreRefused() {
        let cases: [(AIChange, String)] = [
            (.addPlug(ref: "x", shape: "nonsense", name: "N", rows: nil, cols: nil), "unknown shape"),
            (.addPlug(ref: "x", shape: "square-2pin", name: "   ", rows: nil, cols: nil), "blank name"),
            (.addPlug(ref: "x", shape: "square-2pin", name: String(repeating: "n", count: 41), rows: nil, cols: nil), "long name"),
            (.addPlug(ref: "x", shape: "square-2pin", name: "N", rows: 2, cols: 2), "fixed shape given a size"),
            (.addPlug(ref: "x", shape: "rectangular-block", name: "N", rows: 7, cols: 4), "too many rows"),
            (.addPlug(ref: "x", shape: "rectangular-block", name: "N", rows: 6, cols: 11), "over 60 pins"),
            (.addPlug(ref: "x", shape: "rectangular-block", name: "N", rows: 2, cols: 1), "one column"),
            (.addPlug(ref: "x", shape: "inline-block", name: "N", rows: 2, cols: 4), "inline with rows"),
            (.addPlug(ref: "x", shape: "inline-block", name: "N", rows: nil, cols: 17), "inline too long"),
            (.addPlug(ref: "x", shape: "soldered-splice", name: "N", rows: nil, cols: 5), "splice too wide"),
            (.addPlug(ref: "", shape: "square-2pin", name: "N", rows: nil, cols: nil), "empty ref"),
            (.addPlug(ref: "A", shape: "square-2pin", name: "N", rows: nil, cols: nil), "ref is an existing plug"),
        ]
        for (change, why) in cases {
            #expect(!preview([change]).errors.isEmpty, "\(why)")
        }
    }

    @Test func aReferenceCannotBeUsedTwice() {
        let add = AIChange.addPlug(ref: "x", shape: "square-2pin", name: "N", rows: nil, cols: nil)
        #expect(!preview([add, add]).errors.isEmpty)
    }

    @Test func twoNewPlugsGetDifferentIDs() throws {
        let p = preview([.addPlug(ref: "x", shape: "square-2pin", name: "One", rows: nil, cols: nil),
                         .addPlug(ref: "y", shape: "square-2pin", name: "Two", rows: nil, cols: nil)])
        let ids = try #require(p.after?.harnesses[0].connectors.suffix(2).map(\.id))
        #expect(ids == ["MY-01", "MY-02"])
    }

    // MARK: setPin

    @Test func aNewPlugsPinsCanBeFilledInByReference() throws {
        let p = preview([.addPlug(ref: "x", shape: "square-2pin", name: "Relay", rows: nil, cols: nil),
                         set("x", 2, color: "LT BLU/WHT", function: "Relay coil", role: "signal", gauge: 20)])
        let pin = try #require(self.pin(p, "MY-01", 2))
        #expect(pin.color == "LT BLU/WHT")
        #expect(pin.guess == "Relay coil")
        #expect(pin.role == "signal")
        #expect(pin.gauge == 20)
    }

    @Test func everythingTheAISetsIsMarkedAsAGuess() throws {
        let p = preview([set("B", 1, color: "RED")])
        #expect(pin(p, "B", 1)?.confidence == "Low")
    }

    @Test func pinsTheAIDoesNotTouchAreLeftAlone() throws {
        let s = state()
        let p = preview([set("B", 1, color: "RED")], s)
        #expect(pin(p, "B", 2) == s.harnesses[0].connectors[1].flatPins[1].pin)
        #expect(pin(p, "A", 1) == s.harnesses[0].connectors[0].flatPins[0].pin)
    }

    @Test func fillingABlankPinIsNotAnOverwrite() {
        let p = preview([set("B", 1, color: "RED", function: "Pump +")])
        #expect(p.overwrites.isEmpty)
        #expect(!p.needsConfirmation)
        #expect(p.fieldChanges.count == 2)
    }

    @Test func replacingAValueIsListedAndNeedsConfirmation() throws {
        let p = preview([set("A", 1, color: "BLU")])        // A1 is RED
        let change = try #require(p.overwrites.first)
        #expect(change.field == "Color")
        #expect(change.before == "RED")
        #expect(change.after == "BLU")
        #expect(change.plugTitle == "Alpha")
        #expect(p.needsConfirmation)
    }

    @Test func settingTheSameValueChangesNothing() {
        let p = preview([set("A", 1, color: "RED", function: "Signal")])
        #expect(p.fieldChanges.isEmpty)
        #expect(!p.canApply)
    }

    @Test func fillingASparePinWiresItAndSaysSo() throws {
        let p = preview([set("B", 3, color: "GRN")])
        #expect(pin(p, "B", 3)?.populated == true)
        #expect(p.fieldChanges.contains { $0.field == "Pin" && $0.before == "spare" && $0.after == "wired" })
        #expect(p.overwrites.isEmpty)
    }

    @Test func badPinValuesAreRefused() {
        let cases: [(AIChange, String)] = [
            (set("A", 1, color: "PURPLE"), "unknown color"),
            (set("A", 1, color: "GRN/"), "empty stripe"),
            (set("A", 1, color: "GRN/WHT/RED"), "three parts"),
            (set("A", 1, color: "GRN/XXX"), "unknown stripe"),
            (set("A", 1, color: ""), "empty color"),
            (set("A", 1, role: "hot"), "unknown role"),
            (set("A", 1, gauge: 17), "unknown gauge"),
            (set("A", 1, function: "   "), "blank function"),
            (set("A", 1, function: "two\nlines"), "multi-line function"),
            (set("A", 1, function: String(repeating: "f", count: 61)), "long function"),
            (set("A", 1), "sets nothing"),
            (set("A", 4, color: "RED"), "pin past the end"),
            (set("A", 0, color: "RED"), "pin zero"),
            (set("ZZ", 1, color: "RED"), "unknown plug"),
            (set("C", 1, color: "RED"), "plug on another harness"),
        ]
        for (change, why) in cases {
            #expect(!preview([change]).errors.isEmpty, "\(why)")
        }
    }

    @Test func colorCodesAreNormalized() {
        #expect(ProposalEngine.normalizedColor("grn/wht") == "GRN/WHT")
        #expect(ProposalEngine.normalizedColor("lt blu") == "LT BLU")
        #expect(ProposalEngine.normalizedColor("BLK") == "BLK")
        #expect(ProposalEngine.normalizedColor("") == nil)
        #expect(ProposalEngine.normalizedColor("LT") == nil)
    }

    // MARK: connect

    @Test func connectingTwoBlankWiresGivesThemOneNewNet() throws {
        let p = preview([.connect(plugA: "B", pinA: 1, plugB: "B", pinB: 2)])
        let a = try #require(pin(p, "B", 1)), b = try #require(pin(p, "B", 2))
        #expect(!(a.netId ?? "").isEmpty)
        #expect(a.netId == b.netId)
        #expect(a.netType == "wire")
        #expect(p.connections == ["Bravo · pin 1 ↔ Bravo · pin 2"])
        #expect(p.rewires.isEmpty)
    }

    @Test func connectingToAWireAlreadyOnANetJoinsIt() throws {
        var s = state()
        s.harnesses[0].connectors[0].rows[0].pins[0].netId = "W-1"
        s.harnesses[0].connectors[0].rows[0].pins[0].netType = "wire"
        let p = preview([.connect(plugA: "B", pinA: 1, plugB: "A", pinB: 1)], s)
        #expect(pin(p, "B", 1)?.netId == "W-1")
        #expect(p.rewires.isEmpty)
    }

    @Test func connectionsCanReachOtherHarnesses() throws {
        let p = preview([.connect(plugA: "B", pinA: 1, plugB: "C", pinB: 1)])
        #expect(p.canApply)
        #expect(pin(p, "C", 1)?.netId == pin(p, "B", 1)?.netId)
    }

    @Test func aSparePinCannotBeConnected() {
        #expect(!preview([.connect(plugA: "B", pinA: 3, plugB: "B", pinB: 1)]).errors.isEmpty)
        #expect(!preview([.connect(plugA: "B", pinA: 1, plugB: "B", pinB: 3)]).errors.isEmpty)
    }

    @Test func aPinCannotBeConnectedToItself() {
        #expect(!preview([.connect(plugA: "B", pinA: 1, plugB: "B", pinB: 1)]).errors.isEmpty)
    }

    @Test func connectingToAnUnknownPlugOrPinIsRefused() {
        #expect(!preview([.connect(plugA: "B", pinA: 1, plugB: "ZZ", pinB: 1)]).errors.isEmpty)
        #expect(!preview([.connect(plugA: "B", pinA: 1, plugB: "A", pinB: 9)]).errors.isEmpty)
    }

    @Test func pinsAlreadyOnOneWireAreLeftAlone() {
        var s = state()
        for ci in 0..<2 { s.harnesses[0].connectors[ci].rows[0].pins[0].netId = "W-1" }
        let p = preview([.connect(plugA: "A", pinA: 1, plugB: "B", pinB: 1)], s)
        #expect(!p.canApply)
        #expect(p.connections.isEmpty)
    }

    @Test func movingAPinOffAWireOthersAreOnIsReported() throws {
        // Net X: A1, A2, B1.   Net Y: B2 alone.  Connect A1 to B2: B2 (fewer left behind) moves, nothing is left behind.
        var s = state()
        func tag(_ plug: Int, _ pin: Int, _ net: String) {
            s.harnesses[0].connectors[plug].rows[0].pins[pin].netId = net
            s.harnesses[0].connectors[plug].rows[0].pins[pin].netType = "wire"
        }
        tag(0, 0, "X"); tag(0, 1, "X"); tag(1, 0, "X"); tag(1, 1, "Y")
        let p = preview([.connect(plugA: "A", pinA: 1, plugB: "B", pinB: 2)], s)
        #expect(pin(p, "B", 2)?.netId == "X")
        #expect(p.rewires.isEmpty)           // B2 was alone on Y, so moving it leaves nobody behind
        #expect(pin(p, "A", 1)?.netId == "X")
    }

    @Test func whenBothWiresHaveOthersTheMoveIsReportedAndConfirmed() throws {
        // Net X: A1, A2.  Net Y: B1, B2.  Connect A1 to B1: one of them leaves a partner behind.
        var s = state()
        func tag(_ plug: Int, _ pin: Int, _ net: String) {
            s.harnesses[0].connectors[plug].rows[0].pins[pin].netId = net
            s.harnesses[0].connectors[plug].rows[0].pins[pin].netType = "wire"
        }
        tag(0, 0, "X"); tag(0, 1, "X"); tag(1, 0, "Y"); tag(1, 1, "Y")
        let p = preview([.connect(plugA: "A", pinA: 1, plugB: "B", pinB: 1)], s)
        #expect(p.rewires.count == 1)
        #expect(p.rewires[0].left == 1)
        #expect(p.needsConfirmation)
    }

    // MARK: checks

    @Test func aProposalThatAddsAProblemIsFlaggedAndNeedsConfirmation() throws {
        let p = preview([set("A", 1, role: "power", gauge: 18), set("B", 1, color: "RED", function: "Signal", role: "ground"),
                         .connect(plugA: "A", pinA: 1, plugB: "B", pinB: 1)])
        #expect(p.newProblems.contains { $0.title == "Power and ground on one wire" })
        #expect(p.needsConfirmation)
    }

    @Test func problemsThatWereAlreadyThereAreNotBlamedOnTheProposal() throws {
        var s = state()
        s.harnesses[0].connectors[0].rows[0].pins[0].netId = "W-LONELY"
        s.harnesses[0].connectors[0].rows[0].pins[0].netType = "wire"      // already "Connected to nothing"
        let p = preview([set("B", 1, color: "RED")], s)
        #expect(p.newProblems.isEmpty)
        #expect(!p.newIssues.contains { $0.title == "Connected to nothing" })
    }

    @Test func aCleanProposalAddsNoProblems() {
        let p = preview([set("B", 1, color: "RED", function: "Signal"), set("B", 2, color: "RED", function: "Signal"),
                         .connect(plugA: "B", pinA: 1, plugB: "B", pinB: 2)])
        #expect(p.newProblems.isEmpty)
    }
}

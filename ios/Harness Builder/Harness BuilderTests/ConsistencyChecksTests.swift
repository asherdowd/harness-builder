//
//  ConsistencyChecksTests.swift
//  Harness BuilderTests
//
//  The checks that catch pins and wires disagreeing with each other: power and
//  ground on one wire, gauges or functions that differ, leftover data on spare
//  pins, and the warning before a pin is moved off its wire.
//

import Testing
@testable import Harness_Builder

@MainActor
struct ConsistencyChecksTests {
    private func run(_ plugs: [Connector], _ others: [Harness] = []) -> [MapIssue] {
        let h = Fixture.harness("H1", plugs: plugs)
        return MapChecks.run(on: h, in: [h] + others)
    }

    private func wire(_ n: Int, net: String = "W-1", role: String? = nil, gauge: Int? = nil, guess: String? = "Signal") -> Pin {
        Fixture.pin(n, color: "RED", guess: guess, netId: net, netType: "wire", role: role, gauge: gauge)
    }

    // MARK: role, gauge, function

    @Test func powerAndGroundOnOneWireIsAProblem() {
        let a = Fixture.connector("A", pins: [wire(1, role: "power")])
        let b = Fixture.connector("B", pins: [wire(1, role: "ground")])
        let issues = run([a, b]).filter { $0.title == "Power and ground on one wire" }
        #expect(issues.count == 1)
        #expect(issues[0].severity == .problem)
    }

    @Test func powerAndGroundOnAWireAcrossHarnessesIsStillFound() {
        let a = Fixture.connector("A", pins: [wire(1, role: "power")])
        let far = Fixture.harness("H2", plugs: [Fixture.connector("B", pins: [wire(1, role: "ground")])])
        #expect(run([a], [far]).contains { $0.title == "Power and ground on one wire" })
    }

    @Test func powerAndSignalOnOneWireIsFine() {
        let a = Fixture.connector("A", pins: [wire(1, role: "power")])
        let b = Fixture.connector("B", pins: [wire(1, role: "signal")])
        #expect(!run([a, b]).contains { $0.title == "Power and ground on one wire" })
    }

    @Test func gaugesThatDifferAreANote() {
        let a = Fixture.connector("A", pins: [wire(1, gauge: 18)])
        let b = Fixture.connector("B", pins: [wire(1, gauge: 22)])
        let issues = run([a, b]).filter { $0.title == "Gauges differ along one wire" }
        #expect(issues.count == 1)
        #expect(issues[0].severity == .note)
        #expect(issues[0].detail.contains("18 AWG") && issues[0].detail.contains("22 AWG"))
    }

    @Test func aGaugeOnOnlyOneEndIsNotADifference() {
        let a = Fixture.connector("A", pins: [wire(1, gauge: 18)])
        let b = Fixture.connector("B", pins: [wire(1)])
        #expect(!run([a, b]).contains { $0.title == "Gauges differ along one wire" })
    }

    @Test func functionsThatDifferAreANoteButCaseAndSpacesAreIgnored() {
        let a = Fixture.connector("A", pins: [wire(1, guess: "Fuel pump +")])
        let b = Fixture.connector("B", pins: [wire(1, guess: " fuel pump + ")])
        #expect(!run([a, b]).contains { $0.title == "Functions differ along one wire" })

        let c = Fixture.connector("C", pins: [wire(1, guess: "Ground")])
        #expect(run([a, c]).contains { $0.title == "Functions differ along one wire" })
    }

    @Test func eachWireIsReportedOnceNotOncePerPin() {
        let a = Fixture.connector("A", pins: [wire(1, role: "power"), wire(2, role: "power")])
        let b = Fixture.connector("B", pins: [wire(1, role: "ground"), wire(2, role: "ground")])
        #expect(run([a, b]).filter { $0.title == "Power and ground on one wire" }.count == 1)
    }

    // MARK: spare pins

    @Test func aSparePinWithLeftoverDataIsANote() {
        for leftover in [
            Fixture.pin(2, color: "RED", guess: nil, populated: false),
            Fixture.pin(2, color: nil, guess: "Signal", populated: false),
            Fixture.pin(2, color: nil, guess: nil, populated: false, role: "power"),
            Fixture.pin(2, color: nil, guess: nil, populated: false, gauge: 18),
            Fixture.pin(2, color: nil, guess: nil, netId: "W-1", netType: "wire", populated: false),
        ] {
            let a = Fixture.connector("A", pins: [Fixture.pin(1), leftover])
            let issues = run([a]).filter { $0.title == "Spare pin has wire data" }
            #expect(issues.count == 1)
            #expect(issues.first?.pinNumber == 2)
            #expect(issues.first?.severity == .note)
        }
    }

    @Test func aCleanSparePinIsNotFlagged() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1), Fixture.pin(2, color: nil, guess: nil, populated: false)])
        #expect(!run([a]).contains { $0.title == "Spare pin has wire data" })
    }

    // MARK: moving a pin off its wire

    private func draftWithPinOnWire() -> PlugDraft {
        var d = PlugDraft(newShape: "rectangular-block")
        d.pins[0].netId = "W-OLD"
        d.pins[0].netType = "wire"
        return d
    }

    private func target(net: String?) -> Pin {
        Fixture.pin(1, netId: net, netType: net == nil ? nil : "wire")
    }

    @Test func movingAPinCountsTheOthersLeftOnItsOldWire() {
        var d = draftWithPinOnWire()
        d.pins[1].netId = "W-OLD"                                   // another pin on this plug
        let elsewhere = Fixture.harness("H1", plugs: [Fixture.connector("X", pins: [wire(1, net: "W-OLD")])])
        #expect(d.pinsLeftBehind(pin: 0, movingTo: target(net: "W-NEW"), in: [elsewhere]) == 2)
    }

    @Test func movingAPinNobodyElseSharesLeavesNothingBehind() {
        let d = draftWithPinOnWire()
        #expect(d.pinsLeftBehind(pin: 0, movingTo: target(net: "W-NEW"), in: []) == 0)
    }

    @Test func noWarningWhenThePinHasNoWireOrTheTargetHasNone() {
        var d = PlugDraft(newShape: "rectangular-block")
        let elsewhere = Fixture.harness("H1", plugs: [Fixture.connector("X", pins: [wire(1, net: "W-OLD")])])
        #expect(d.pinsLeftBehind(pin: 0, movingTo: target(net: "W-NEW"), in: [elsewhere]) == 0)   // pin has no wire
        d.pins[0].netId = "W-OLD"
        #expect(d.pinsLeftBehind(pin: 0, movingTo: target(net: nil), in: [elsewhere]) == 0)       // target has none
    }

    @Test func noWarningWhenBothAreAlreadyOnTheSameWire() {
        let d = draftWithPinOnWire()
        let elsewhere = Fixture.harness("H1", plugs: [Fixture.connector("X", pins: [wire(1, net: "W-OLD")])])
        #expect(d.pinsLeftBehind(pin: 0, movingTo: target(net: "W-OLD"), in: [elsewhere]) == 0)
    }

    @Test func theSavedVersionOfThePlugBeingEditedIsNotCounted() {
        let plug = Fixture.connector("A", pins: [wire(1, net: "W-OLD"), wire(2, net: "W-OLD")])
        let h = Fixture.harness("H1", plugs: [plug])
        var d = PlugDraft(editing: plug)
        d.pins[1].netId = nil                                       // the edit already took pin 2 off the wire
        #expect(d.pinsLeftBehind(pin: 0, movingTo: target(net: "W-NEW"), in: [h]) == 0)
    }

    @Test func anOutOfRangePinIsIgnored() {
        let d = draftWithPinOnWire()
        #expect(d.pinsLeftBehind(pin: 99, movingTo: target(net: "W-NEW"), in: []) == 0)
    }
}

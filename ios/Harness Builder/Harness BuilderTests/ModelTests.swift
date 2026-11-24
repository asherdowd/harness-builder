//
//  ModelTests.swift
//  Harness BuilderTests
//
//  The data model: decoding the web app's JSON, the app-only role and gauge
//  fields, pin numbering, and what gets saved.
//

import Foundation
import Testing
@testable import Harness_Builder

@MainActor
struct ModelTests {
    private func decodePin(_ json: String) throws -> Pin {
        try JSONDecoder().decode(Pin.self, from: Data(json.utf8))
    }

    @Test func minimalPinDecodesWithDefaults() throws {
        let p = try decodePin(#"{"position": 3}"#)
        #expect(p.position == 3)
        #expect(p.populated == true)
        #expect(p.color == nil)
        #expect(p.role == nil)
        #expect(p.gauge == nil)
    }

    @Test func roleAndGaugeDecode() throws {
        let p = try decodePin(#"{"position": 1, "color": "RED", "role": "power", "gauge": 18}"#)
        #expect(p.role == "power")
        #expect(p.gauge == 18)
    }

    @Test func unknownKeysAreIgnored() throws {
        let p = try decodePin(#"{"position": 2, "futureField": {"a": 1}, "color": "BLK"}"#)
        #expect(p.position == 2)
        #expect(p.color == "BLK")
    }

    @Test func emptyRoleAndGaugeAreNotSaved() throws {
        let data = try JSONEncoder().encode(Fixture.pin(1, role: nil, gauge: nil))
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("\"role\""))
        #expect(!text.contains("\"gauge\""))
    }

    @Test func roleAndGaugeSurviveSaveAndLoad() throws {
        let original = Fixture.pin(4, role: "ground", gauge: 20)
        let back = try JSONDecoder().decode(Pin.self, from: JSONEncoder().encode(original))
        #expect(back == original)
        #expect(back.role == "ground")
        #expect(back.gauge == 20)
    }

    @Test func wireRolesMatchTheSavedValues() {
        #expect(WireRole(rawValue: "power") == .power)
        #expect(WireRole(rawValue: "signal") == .signal)
        #expect(WireRole(rawValue: "ground") == .ground)
        #expect(WireRole(rawValue: "hot") == nil)
        #expect(WireRole.allCases.count == 3)
    }

    @Test func flatPinsAreNumberedAcrossRows() {
        let c = Fixture.connector("A", pins: Fixture.pins(5), perRow: 3)
        #expect(c.rows.count == 2)
        let flat = c.flatPins
        #expect(flat.map(\.number) == [1, 2, 3, 4, 5])
        #expect(flat.map(\.rowIndex) == [0, 0, 0, 1, 1])
    }

    @Test func pinCountPrefersTheStoredTotal() {
        var c = Fixture.connector("A", pins: Fixture.pins(4))
        #expect(c.pinCount == 4)
        c.totalPositions = 6
        #expect(c.pinCount == 6)
    }

    @Test func titleUsesTheDisplayNameWhenThereIsOne() {
        var c = Fixture.connector("A", name: "Raw name", pins: Fixture.pins(1))
        #expect(c.title == "Raw name")
        c.displayName = "Friendly name"
        #expect(c.title == "Friendly name")
    }

    @Test func tabLabelFallsBackToTheTitle() {
        var h = Fixture.harness("H1", title: "Engine harness")
        #expect(h.tabLabel == "Engine harness")
        h.tab = "Engine"
        #expect(h.tabLabel == "Engine")
    }

    @Test func blankStateIsOneEmptyHarness() {
        let s = AppState.blank()
        #expect(s.harnesses.count == 1)
        #expect(s.harnesses[0].connectors.isEmpty)
        #expect(s.harnesses[0].kind == .harness)
        #expect(s.activeID == s.harnesses[0].id)
    }

    @Test func wholeStateSurvivesSaveAndLoad() throws {
        let link = PlugLink(hid: "H2", cid: "P1")
        let state = AppState(harnesses: [
            Fixture.harness("H1", kind: .component, plugs: [
                Fixture.connector("C1", pins: [Fixture.pin(1, role: "signal", gauge: 22), Fixture.pin(2, color: nil, guess: nil, populated: false)], link: link),
            ]),
            Fixture.harness("H2", plugs: [Fixture.connector("P1", pins: Fixture.pins(3), perRow: 2, sameCircuitAs: ["C1"])]),
        ], activeID: "H2")
        let back = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
        #expect(back == state)
        #expect(back.harnesses[0].connectors[0].link == link)
    }
}

//
//  MapChecksTests.swift
//  Harness BuilderTests
//
//  "Check this harness": what it flags and what it leaves alone.
//

import Testing
@testable import Harness_Builder

@MainActor
struct MapChecksTests {
    private func run(_ h: Harness, _ all: [Harness]? = nil) -> [MapIssue] {
        MapChecks.run(on: h, in: all ?? [h])
    }

    private func titles(_ issues: [MapIssue]) -> [String] { issues.map(\.title) }

    @Test func aCleanHarnessHasNoIssues() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1), Fixture.pin(2)])
        #expect(run(Fixture.harness("H1", plugs: [a])).isEmpty)
    }

    @Test func aPlugWithNoWiresIsANote() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1, color: nil, guess: nil, populated: false)])
        let issues = run(Fixture.harness("H1", plugs: [a]))
        #expect(titles(issues) == ["No wires set"])
        #expect(issues[0].severity == .note)
    }

    @Test func aWireWithNoColorOrLabelIsNoted() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1, color: nil, guess: nil)])
        let issues = run(Fixture.harness("H1", plugs: [a]))
        #expect(Set(titles(issues)) == ["No color", "Not labeled"])
        #expect(issues.allSatisfy { $0.pinNumber == 1 })
    }

    @Test func emptyPinsAreNeverFlagged() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1), Fixture.pin(2, color: nil, guess: nil, populated: false)])
        #expect(run(Fixture.harness("H1", plugs: [a])).isEmpty)
    }

    @Test func aConnectionNothingElseSharesIsAProblem() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1, netId: "W-1", netType: "wire")])
        let issues = run(Fixture.harness("H1", plugs: [a]))
        #expect(titles(issues) == ["Connected to nothing"])
        #expect(issues[0].severity == .problem)
    }

    @Test func aConnectionToAnotherHarnessCounts() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1, netId: "W-1", netType: "wire")])
        let b = Fixture.connector("B", pins: [Fixture.pin(1, netId: "W-1", netType: "wire")])
        let h1 = Fixture.harness("H1", plugs: [a]), h2 = Fixture.harness("H2", plugs: [b])
        #expect(run(h1, [h1, h2]).isEmpty)
    }

    @Test func importedNetsThatEndHereAreNotFlagged() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1, netId: "N1", netType: "engine")])
        #expect(run(Fixture.harness("H1", plugs: [a])).isEmpty)
    }

    @Test func differentColorsOnOneWireAreANote() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1, color: "RED", netId: "W-1", netType: "wire")])
        let b = Fixture.connector("B", pins: [Fixture.pin(1, color: "BLK", netId: "W-1", netType: "wire")])
        let h = Fixture.harness("H1", plugs: [a, b])
        #expect(titles(run(h)) == ["Colors differ along one wire"])
    }

    @Test func sameColorsOnOneWireAreFine() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1, color: "RED", netId: "W-1", netType: "wire")])
        let b = Fixture.connector("B", pins: [Fixture.pin(1, color: "RED", netId: "W-1", netType: "wire")])
        #expect(run(Fixture.harness("H1", plugs: [a, b])).isEmpty)
    }

    @Test func anUnlinkedComponentIsANoteAndALinkedOneIsFine() {
        let unlinked = Fixture.connector("C1", pins: [Fixture.pin(1)])
        let linked = Fixture.connector("C2", pins: [Fixture.pin(1)], link: PlugLink(hid: "H1", cid: "A"))
        #expect(titles(run(Fixture.harness("C", kind: .component, plugs: [unlinked]))) == ["Not linked"])
        #expect(run(Fixture.harness("C", kind: .component, plugs: [linked])).isEmpty)
    }

    @Test func problemsComeBeforeNotes() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1, color: nil), Fixture.pin(2, netId: "W-9", netType: "wire")])
        let issues = run(Fixture.harness("H1", plugs: [a]))
        #expect(issues.first?.severity == .problem)
        #expect(issues.last?.severity == .note)
    }

    @Test func issueIDsAreUnique() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1, color: nil, guess: nil), Fixture.pin(2, color: nil, guess: nil)])
        let ids = run(Fixture.harness("H1", plugs: [a])).map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}

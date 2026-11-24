//
//  TraceTests.swift
//  Harness BuilderTests
//
//  Wire tracing across harnesses, the plugs outlined on the canvas, and the
//  rule that decides which wire a linked component's pin goes to.
//

import Testing
@testable import Harness_Builder

@MainActor
struct TraceTests {
    /// H1 has plugs A and B, H2 has plug C. Pin 1 of A, pin 2 of B and pin 1 of C share net N1.
    private func world() -> (harnesses: [Harness], a: Connector, b: Connector, c: Connector) {
        let a = Fixture.connector("A", name: "Plug A", pins: [
            Fixture.pin(1, netId: "N1", netType: "engine"), Fixture.pin(2, netId: "N2", netType: "engine"),
        ])
        let b = Fixture.connector("B", name: "Plug B", pins: [
            Fixture.pin(1, netId: "N9", netType: "engine"), Fixture.pin(2, netId: "N1", netType: "engine"),
        ])
        let c = Fixture.connector("C", name: "Plug C", pins: [Fixture.pin(1, netId: "N1", netType: "firewall")])
        let h1 = Fixture.harness("H1", title: "Engine", plugs: [a, b])
        let h2 = Fixture.harness("H2", title: "Firewall", plugs: [c])
        return ([h1, h2], a, b, c)
    }

    // MARK: links

    @Test func aWireIsFollowedToEveryPlugOnTheSameNet() throws {
        let w = world()
        let pin = try #require(w.a.flatPins.first)
        let links = WireTrace.links(for: pin, in: w.a, harnesses: w.harnesses)
        #expect(Set(links.map(\.plugID)) == ["B", "C"])
        #expect(links.allSatisfy { $0.precise })
    }

    @Test func theWireItselfIsNotListed() throws {
        let w = world()
        let pin = try #require(w.a.flatPins.first)
        let links = WireTrace.links(for: pin, in: w.a, harnesses: w.harnesses)
        #expect(!links.contains { $0.plugID == "A" && $0.pinNumber == 1 })
    }

    @Test func sameNetAndGroupIsTheSameWireElseTheSameJob() throws {
        let w = world()
        let pin = try #require(w.a.flatPins.first)
        let links = WireTrace.links(for: pin, in: w.a, harnesses: w.harnesses)
        let b = try #require(links.first { $0.plugID == "B" })
        let c = try #require(links.first { $0.plugID == "C" })
        #expect(b.same)
        #expect(!c.same)
        #expect(b.pinNumber == 2)
        #expect(b.harnessTitle == "Engine")
        #expect(c.harnessTitle == "Firewall")
    }

    @Test func anotherPinOnTheSamePlugCanShareTheNet() throws {
        let plug = Fixture.connector("A", pins: [Fixture.pin(1, netId: "N1"), Fixture.pin(2, netId: "N1")])
        let h = Fixture.harness("H1", plugs: [plug])
        let pin = try #require(plug.flatPins.first)
        let links = WireTrace.links(for: pin, in: plug, harnesses: [h])
        #expect(links.map(\.pinNumber) == [2])
    }

    @Test func aWireWithNoMatchHasNoLinks() throws {
        let w = world()
        let pin = try #require(w.b.flatPins.first)          // net N9 is unique
        #expect(WireTrace.links(for: pin, in: w.b, harnesses: w.harnesses).isEmpty)
    }

    @Test func plugsMarkedAsTheSameCircuitAreUsedWhenThereIsNoNet() throws {
        let a = Fixture.connector("A", pins: [Fixture.pin(1)], sameCircuitAs: ["C"])
        let c = Fixture.connector("C", name: "Plug C", pins: [Fixture.pin(1)])
        let hs = [Fixture.harness("H1", plugs: [a]), Fixture.harness("H2", title: "Other", plugs: [c])]
        let pin = try #require(a.flatPins.first)
        let links = WireTrace.links(for: pin, in: a, harnesses: hs)
        #expect(links.count == 1)
        #expect(links[0].plugID == "C")
        #expect(links[0].pinNumber == nil)
        #expect(!links[0].precise)
        #expect(!links[0].same)
        #expect(links[0].harnessTitle == "Other")
    }

    @Test func anEmptyNetCountsAsNoNet() throws {
        let a = Fixture.connector("A", pins: [Fixture.pin(1, netId: "")], sameCircuitAs: ["C"])
        let c = Fixture.connector("C", pins: [Fixture.pin(1, netId: "")])
        let hs = [Fixture.harness("H1", plugs: [a]), Fixture.harness("H2", plugs: [c])]
        let pin = try #require(a.flatPins.first)
        let links = WireTrace.links(for: pin, in: a, harnesses: hs)
        #expect(links.map(\.plugID) == ["C"])
        #expect(links.allSatisfy { !$0.precise })
    }

    @Test func aMissingSameCircuitPlugIsSkipped() throws {
        let a = Fixture.connector("A", pins: [Fixture.pin(1)], sameCircuitAs: ["gone"])
        let pin = try #require(a.flatPins.first)
        #expect(WireTrace.links(for: pin, in: a, harnesses: [Fixture.harness("H1", plugs: [a])]).isEmpty)
    }

    @Test func traceLinkIDsAreUniquePerPlugAndPin() {
        let one = TraceLink(harnessID: "H", harnessTitle: "H", plugID: "P", plugTitle: "P", pinNumber: 3, color: nil, same: true, precise: true)
        var two = one
        two.pinNumber = 4
        var whole = one
        whole.pinNumber = nil
        #expect(one.id != two.id)
        #expect(whole.id == "P#0")
    }

    // MARK: outlines on the canvas

    @Test func selectedWireOutlinesPlugsOnTheOpenHarnessOnly() {
        let w = world()
        let ids = WireTrace.highlightIDs(selected: w.a, pinIndex: 0, harnesses: w.harnesses, activeID: "H1")
        #expect(ids == ["B"])                        // C is on another harness
        let other = WireTrace.highlightIDs(selected: w.a, pinIndex: 0, harnesses: w.harnesses, activeID: "H2")
        #expect(other == ["C"])
    }

    @Test func noSelectedWireOutlinesTheSameCircuitPlugsBothWays() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1)], sameCircuitAs: ["B"])
        let b = Fixture.connector("B", pins: [Fixture.pin(1)])
        let c = Fixture.connector("C", pins: [Fixture.pin(1)], sameCircuitAs: ["A"])     // points back at A
        let h = Fixture.harness("H1", plugs: [a, b, c])
        let ids = WireTrace.highlightIDs(selected: a, pinIndex: nil, harnesses: [h], activeID: "H1")
        #expect(ids == ["B", "C"])
    }

    @Test func aPinNumberOutsideThePlugOutlinesNothingExtra() {
        let a = Fixture.connector("A", pins: [Fixture.pin(1)])
        let h = Fixture.harness("H1", plugs: [a])
        #expect(WireTrace.highlightIDs(selected: a, pinIndex: 7, harnesses: [h], activeID: "H1").isEmpty)
    }

    // MARK: "goes to pin N" for linked components

    @Test func componentPinsGoToTheMatchingNetFirst() {
        let target = Fixture.connector("T", pins: [
            Fixture.pin(1, guess: "Horn", netId: "N5"), Fixture.pin(2, guess: "Fuel pump", netId: "N7"),
        ])
        let pin = Fixture.pin(1, guess: "Fuel pump", netId: "N5")        // net says pin 1, function says pin 2
        #expect(PlugSheet.matchPin(for: pin, in: target) == 1)
    }

    @Test func componentPinsFallBackToTheSameFunction() {
        let target = Fixture.connector("T", pins: [Fixture.pin(1, guess: "Horn"), Fixture.pin(2, guess: "Fuel pump")])
        #expect(PlugSheet.matchPin(for: Fixture.pin(1, guess: "Fuel pump"), in: target) == 2)
    }

    @Test func noMatchMeansNoPinNumber() {
        let target = Fixture.connector("T", pins: [Fixture.pin(1, guess: "Horn")])
        #expect(PlugSheet.matchPin(for: Fixture.pin(1, guess: "Something else"), in: target) == nil)
        #expect(PlugSheet.matchPin(for: Fixture.pin(1, guess: nil), in: target) == nil)
    }

    @Test func emptyPinsAreNeverMatched() {
        let target = Fixture.connector("T", pins: [Fixture.pin(1, guess: "Horn", populated: false)])
        #expect(PlugSheet.matchPin(for: Fixture.pin(1, guess: "Horn"), in: target) == nil)
    }
}

//
//  WireConnectTests.swift
//  Harness BuilderTests
//
//  Connecting a wire you build to a pin on another plug: the draft, the
//  store, and that the existing wire tracing finds the connection.
//

import Foundation
import Testing
@testable import Harness_Builder

@MainActor
struct WireConnectTests {
    private func draft(pins: Int = 3) -> PlugDraft {
        var d = PlugDraft(newShape: "inline-block")
        d.resize(cols: pins)
        return d
    }

    // MARK: the draft

    @Test func connectingGivesBothEndsOneNewWireNet() {
        var d = draft()
        d.connect(pin: 0, toPlug: "MY-01", pinNumber: 2, targetPin: Fixture.pin(2))
        let net = d.pins[0].netId ?? ""
        #expect(net.hasPrefix("W-"))
        #expect(d.pins[0].netType == "wire")
        #expect(d.stamps == [NetStamp(pinIndex: 0, plugID: "MY-01", pinNumber: 2, net: net, netType: "wire")])
    }

    @Test func connectingToAPinWithANetJoinsThatNet() {
        var d = draft()
        d.connect(pin: 1, toPlug: "A", pinNumber: 1, targetPin: Fixture.pin(1, netId: "N1", netType: "engine"))
        #expect(d.pins[1].netId == "N1")
        #expect(d.pins[1].netType == "engine")
    }

    @Test func connectingToASecondPinKeepsTheSameNet() {
        var d = draft()
        d.connect(pin: 0, toPlug: "B", pinNumber: 1, targetPin: Fixture.pin(1))
        let net = d.pins[0].netId
        d.connect(pin: 0, toPlug: "C", pinNumber: 4, targetPin: Fixture.pin(4))
        #expect(d.pins[0].netId == net)
        #expect(d.stamps.count == 2)
    }

    @Test func connectingTheSamePinTwiceIsOneStamp() {
        var d = draft()
        d.connect(pin: 0, toPlug: "B", pinNumber: 1, targetPin: Fixture.pin(1))
        d.connect(pin: 0, toPlug: "B", pinNumber: 1, targetPin: Fixture.pin(1))
        #expect(d.stamps.count == 1)
    }

    @Test func disconnectingClearsThePinAndItsStamps() {
        var d = draft()
        d.connect(pin: 0, toPlug: "B", pinNumber: 1, targetPin: Fixture.pin(1))
        d.disconnect(pin: 0)
        #expect(d.pins[0].netId == nil)
        #expect(d.pins[0].netType == nil)
        #expect(d.stamps.isEmpty)
    }

    @Test func aPinOutsideTheDraftIsIgnored() {
        var d = draft(pins: 2)
        d.connect(pin: 9, toPlug: "B", pinNumber: 1, targetPin: Fixture.pin(1))
        d.disconnect(pin: 9)
        #expect(d.stamps.isEmpty)
    }

    @Test func stampsForRemovedOrChangedPinsAreDropped() {
        var d = draft(pins: 4)
        d.connect(pin: 3, toPlug: "B", pinNumber: 1, targetPin: Fixture.pin(1))
        d.connect(pin: 0, toPlug: "C", pinNumber: 2, targetPin: Fixture.pin(2))
        #expect(d.validStamps.count == 2)
        d.resize(cols: 2)                       // pin 4 is gone
        #expect(d.validStamps.count == 1)
        d.pins[0].netId = "other"               // pin 1 moved to another net
        #expect(d.validStamps.isEmpty)
    }

    @Test func aConnectionCountsAsAChangeOnANewPlug() {
        var d = draft()
        #expect(!d.hasChanges)
        d.connect(pin: 0, toPlug: "B", pinNumber: 1, targetPin: Fixture.pin(1))
        #expect(d.hasChanges)
    }

    // MARK: the store

    private func twoPlugState() -> AppState {
        let a = Fixture.connector("A", pins: [Fixture.pin(1), Fixture.pin(2), Fixture.pin(3, netId: "N7", netType: "engine")], perRow: 2)
        let b = Fixture.connector("B", pins: [Fixture.pin(1)])
        return AppState(harnesses: [Fixture.harness("H1", plugs: [a]), Fixture.harness("H2", plugs: [b])], activeID: "H1")
    }

    @Test func stampingWritesTheNetOntoTheRightPinAcrossRows() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(twoPlugState(), at: url)
        store.stampNets([NetStamp(pinIndex: 0, plugID: "A", pinNumber: 2, net: "W-1", netType: "wire")])
        let pins = try #require(store.plug(id: "A")).connector.flatPins
        #expect(pins[0].pin.netId == nil)
        #expect(pins[1].pin.netId == "W-1")
        #expect(pins[1].pin.netType == "wire")
    }

    @Test func stampingNeverOverwritesAPinThatAlreadyHasANet() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(twoPlugState(), at: url)
        store.stampNets([NetStamp(pinIndex: 0, plugID: "A", pinNumber: 3, net: "W-1", netType: "wire")])
        let pin = try #require(store.plug(id: "A")).connector.flatPins[2].pin
        #expect(pin.netId == "N7")
        #expect(pin.netType == "engine")
    }

    @Test func stampingAnUnknownPlugOrPinChangesNothing() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(twoPlugState(), at: url)
        let before = store.state
        store.stampNets([
            NetStamp(pinIndex: 0, plugID: "NOPE", pinNumber: 1, net: "W-1", netType: "wire"),
            NetStamp(pinIndex: 0, plugID: "B", pinNumber: 9, net: "W-1", netType: "wire"),
        ])
        #expect(store.state == before)
    }

    @Test func stampsSurviveARelaunch() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(twoPlugState(), at: url)
        store.stampNets([NetStamp(pinIndex: 0, plugID: "B", pinNumber: 1, net: "W-1", netType: "wire")])
        let again = try Fixture.store(at: url)
        #expect(try #require(again.plug(id: "B")).connector.flatPins[0].pin.netId == "W-1")
    }

    // MARK: end to end

    @Test func aConnectedWireIsTracedFromBothPlugs() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(twoPlugState(), at: url)

        // Build a new plug in H1 whose pin 1 connects to pin 1 of plug B.
        var d = draft(pins: 2)
        d.name = "New plug"
        let target = try #require(store.plug(id: "B")).connector.flatPins[0].pin
        d.connect(pin: 0, toPlug: "B", pinNumber: 1, targetPin: target)
        let id = try #require(store.addPlug(d.connector(), toHarness: "H1"))
        store.stampNets(d.validStamps)

        let mine = try #require(store.plug(id: id)).connector
        let fromMine = WireTrace.links(for: mine.flatPins[0], in: mine, harnesses: store.harnesses)
        #expect(fromMine.map(\.plugID) == ["B"])
        #expect(fromMine.first?.same == true)
        #expect(fromMine.first?.precise == true)

        let b = try #require(store.plug(id: "B")).connector
        let fromB = WireTrace.links(for: b.flatPins[0], in: b, harnesses: store.harnesses)
        #expect(fromB.map(\.plugID) == [id])
        #expect(fromB.first?.same == true)
    }
}

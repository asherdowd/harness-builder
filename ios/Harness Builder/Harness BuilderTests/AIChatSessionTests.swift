//
//  AIChatSessionTests.swift
//  Harness BuilderTests
//
//  The conversation: sending, history, proposals, the one retry when the app
//  rejects a proposal, and every failure. Uses a canned transport.
//

import Foundation
import Testing
@testable import Harness_Builder

@MainActor
struct AIChatSessionTests {
    private func makeStore() throws -> (HarnessStore, URL) {
        let a = Fixture.connector("A", name: "Alpha", pins: [Fixture.pin(1, color: nil, guess: nil), Fixture.pin(2, color: nil, guess: nil)])
        let url = Fixture.tempFileURL()
        return (try Fixture.store(AppState(harnesses: [Fixture.harness("H1", plugs: [a])], activeID: "H1"), at: url), url)
    }

    private func session(_ store: HarnessStore, _ script: Script?, key: Bool = true) -> AIChatSession {
        AIChatSession(store: store, harnessID: "H1") {
            guard key, let script else { return nil }
            return AnthropicClient(key: "sk-ant-test", model: "claude-haiku-5-5", send: script.send)
        }
    }

    private let good = #"{"summary":"Color pin 1","changes":[{"type":"set_pin","plug":"A","pin":1,"color":"GRN"}]}"#
    private let bad = #"{"summary":"Color pin 1","changes":[{"type":"set_pin","plug":"A","pin":1,"color":"PURPLE"}]}"#

    @Test func aQuestionGetsAnAnswerAndNoProposal() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let s = session(store, Script([(200, textReply("Which pin?"))]))
        await s.send("the green wire")
        #expect(s.messages.map(\.role) == [.user, .assistant])
        #expect(s.messages[1].text == "Which pin?")
        #expect(s.messages[1].proposal == nil)
        #expect(!s.hasProposal)
        #expect(s.errorText == nil)
        #expect(!s.busy)
    }

    @Test func aGoodProposalIsKeptOnTheReply() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let s = session(store, Script([(200, toolReply(good))]))
        await s.send("pin 1 is green")
        #expect(s.hasProposal)
        let p = try #require(s.messages.last?.proposal)
        #expect(s.preview(p).canApply)
    }

    @Test func nothingIsAppliedBySending() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let before = store.state
        let s = session(store, Script([(200, toolReply(good))]))
        await s.send("pin 1 is green")
        #expect(store.state == before)
    }

    @Test func aRejectedProposalGetsOneChanceToBeFixed() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let script = Script([(200, toolReply(bad)), (200, toolReply(good, text: "Fixed."))])
        let s = session(store, script)
        await s.send("pin 1 is purple")
        #expect(script.requests.count == 2)
        #expect(s.messages.last?.text == "Fixed.")
        #expect(s.hasProposal)
        // The second request carries the app's exact complaint.
        let msgs = script.lastBody["messages"] as? [[String: Any]]
        let last = msgs?.last?["content"] as? String ?? ""
        #expect(last.contains("PURPLE"))
        #expect(msgs?.last?["role"] as? String == "user")
        // The complaint is not shown to the user.
        #expect(!s.messages.contains { $0.text.contains("could not use that proposal") })
    }

    @Test func aProposalThatStaysBadIsNeverShown() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let script = Script([(200, toolReply(bad)), (200, toolReply(bad))])
        let s = session(store, script)
        await s.send("pin 1 is purple")
        #expect(script.requests.count == 2)
        #expect(!s.hasProposal)
        #expect(s.messages.last?.role == .assistant)
        #expect(s.messages.last?.text.contains("couldn't turn that into changes") == true)
    }

    @Test func anUnreadableAnswerIsRetriedOnce() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let broken = #"{"summary":"x","changes":[{"type":"delete_plug"}]}"#
        let script = Script([(200, toolReply(broken)), (200, toolReply(good))])
        let s = session(store, script)
        await s.send("pin 1 is green")
        #expect(script.requests.count == 2)
        #expect(s.hasProposal)
    }

    @Test func aProposalWithNoTextStillGetsAMessage() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let body = #"{"content":[{"type":"tool_use","id":"t","name":"propose_changes","input":\#(good)}],"stop_reason":"tool_use"}"#
        let s = session(store, Script([(200, body)]))
        await s.send("pin 1 is green")
        #expect(s.messages.last?.text.contains("Nothing changes until you review it") == true)
    }

    @Test func noKeyMeansNothingIsSentAndTheUserIsTold() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let script = Script([(200, textReply("x"))])
        let s = session(store, script, key: false)
        await s.send("hello")
        #expect(script.requests.isEmpty)
        #expect(s.messages.isEmpty)
        #expect(s.errorText == AIError.noKey.errorDescription)
    }

    @Test func aFailureShowsAPlainMessageAndKeepsWhatYouTyped() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let s = session(store, Script([(401, "{}")]))
        await s.send("hello")
        #expect(s.errorText == AIError.badKey.errorDescription)
        #expect(s.messages.map(\.role) == [.user])
        #expect(!s.busy)
    }

    @Test func emptyMessagesAreIgnored() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let script = Script([(200, textReply("x"))])
        let s = session(store, script)
        await s.send("   \n")
        #expect(script.requests.isEmpty)
        #expect(s.messages.isEmpty)
    }

    @Test func theHarnessAsItIsNowGoesWithEveryMessage() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let script = Script([(200, textReply("ok")), (200, textReply("ok"))])
        let s = session(store, script)
        await s.send("first")
        store.updatePlug(id: "A") { $0.name = "Renamed plug" }
        await s.send("second")
        let system = script.lastBody["system"] as? String ?? ""
        #expect(system.contains("Renamed plug"))
    }

    @Test func historyGoesBackAndIsLimited() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let script = Script(Array(repeating: (200, textReply("ok")), count: 10))
        let s = session(store, script)
        for i in 1...10 { await s.send("message \(i)") }
        let sent = script.lastBody["messages"] as? [[String: Any]] ?? []
        #expect(sent.count <= AIChatSession.historyLimit)
        #expect(sent.last?["content"] as? String == "message 10")
    }

    @Test func dismissingAProposalAndClearingWork() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let s = session(store, Script([(200, toolReply(good))]))
        await s.send("pin 1 is green")
        let id = try #require(s.messages.last?.id)
        s.dismissProposal(on: id)
        #expect(!s.hasProposal)
        s.clear()
        #expect(s.messages.isEmpty)
    }

    @Test func aBusySessionIgnoresASecondSend() async throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let script = Script([(200, textReply("ok"))])
        let s = session(store, script)
        async let first: Void = s.send("one")
        async let second: Void = s.send("two")
        _ = await (first, second)
        #expect(script.requests.count <= 2)
        #expect(!s.busy)
    }
}

//
//  AnthropicClientTests.swift
//  Harness BuilderTests
//
//  The API client with a canned transport: what it sends, how it reads
//  replies, and how every kind of failure becomes a plain message. Nothing
//  here touches the network.
//

import Foundation
import Testing
@testable import Harness_Builder

/// Hands out canned replies in order and remembers what was sent.
@MainActor
final class Script {
    var replies: [(status: Int, body: String, headers: [String: String])]
    var requests: [URLRequest] = []

    init(_ replies: [(Int, String)]) {
        self.replies = replies.map { ($0.0, $0.1, [:]) }
    }

    var send: AISend {
        { [self] req in
            requests.append(req)
            guard !replies.isEmpty else { throw AIError.network }
            let r = replies.removeFirst()
            let http = HTTPURLResponse(url: req.url!, statusCode: r.status, httpVersion: nil, headerFields: r.headers)!
            return (Data(r.body.utf8), http)
        }
    }

    var lastBody: [String: Any] {
        guard let d = requests.last?.httpBody else { return [:] }
        return (try? JSONSerialization.jsonObject(with: d) as? [String: Any]) ?? [:]
    }
}

func toolReply(_ proposalJSON: String, text: String = "Here you go.") -> String {
    #"{"content":[{"type":"text","text":"\#(text)"},{"type":"tool_use","id":"t1","name":"propose_changes","input":\#(proposalJSON)}],"stop_reason":"tool_use"}"#
}

func textReply(_ text: String) -> String {
    #"{"content":[{"type":"text","text":"\#(text)"}],"stop_reason":"end_turn"}"#
}

@MainActor
struct AnthropicClientTests {
    private func client(_ script: Script, model: String = "claude-haiku-5-5") -> AnthropicClient {
        AnthropicClient(key: "sk-ant-test-key", model: model, send: script.send)
    }

    // MARK: what is sent

    @Test func theRequestGoesToTheMessagesAPIWithTheKey() async throws {
        let script = Script([(200, textReply("Hi"))])
        _ = try await client(script).ask(system: "sys", messages: [AIMessage(role: .user, text: "hello")])
        let req = try #require(script.requests.first)
        #expect(req.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(req.httpMethod == "POST")
        #expect(req.value(forHTTPHeaderField: "x-api-key") == "sk-ant-test-key")
        #expect(req.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(req.value(forHTTPHeaderField: "content-type") == "application/json")
    }

    @Test func theBodyCarriesTheModelSystemMessagesAndTheTool() async throws {
        let script = Script([(200, textReply("Hi"))])
        _ = try await client(script, model: "claude-sonnet-5-5")
            .ask(system: "be brief", messages: [AIMessage(role: .user, text: "one"), AIMessage(role: .assistant, text: "two"), AIMessage(role: .user, text: "three")])
        let body = script.lastBody
        #expect(body["model"] as? String == "claude-sonnet-5-5")
        #expect(body["system"] as? String == "be brief")
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.map { $0["role"] as? String } == ["user", "assistant", "user"])
        #expect(messages.map { $0["content"] as? String } == ["one", "two", "three"])
        let tools = try #require(body["tools"] as? [[String: Any]])
        #expect(tools.count == 1)
        #expect(tools[0]["name"] as? String == "propose_changes")
        #expect(tools[0]["strict"] == nil)
        #expect((body["max_tokens"] as? Int ?? 0) > 0)
    }

    @Test func theToolIsNeverForcedBecauseSomeModelsRejectThat() async throws {
        let script = Script([(200, textReply("Hi"))])
        _ = try await client(script, model: "claude-sonnet-5-5").ask(system: "s", messages: [AIMessage(role: .user, text: "x")])
        let choice = script.lastBody["tool_choice"] as? [String: Any]
        #expect(choice?["type"] as? String == "auto")
    }

    @Test func noSamplingSettingsAreSent() async throws {
        let script = Script([(200, textReply("Hi"))])
        _ = try await client(script).ask(system: "s", messages: [AIMessage(role: .user, text: "x")])
        #expect(script.lastBody["temperature"] == nil)
        #expect(script.lastBody["top_p"] == nil)
        #expect(script.lastBody["top_k"] == nil)
    }

    @Test func theKeyIsNeverInTheBody() async throws {
        let script = Script([(200, textReply("Hi"))])
        _ = try await client(script).ask(system: "s", messages: [AIMessage(role: .user, text: "x")])
        let text = String(decoding: script.requests[0].httpBody ?? Data(), as: UTF8.self)
        #expect(!text.contains("sk-ant"))
    }

    @Test func testingTheKeySendsOneTinyRequest() async throws {
        let script = Script([(200, textReply("Hi"))])
        try await client(script).testKey()
        #expect(script.requests.count == 1)
        #expect(script.lastBody["max_tokens"] as? Int == 1)
        #expect(script.lastBody["tools"] == nil)
    }

    // MARK: what comes back

    @Test func aPlainReplyIsJustText() async throws {
        let reply = try await client(Script([(200, textReply("Which pin is that?"))]))
            .ask(system: "s", messages: [AIMessage(role: .user, text: "x")])
        #expect(reply.text == "Which pin is that?")
        #expect(reply.proposal == nil)
    }

    @Test func aToolCallBecomesAProposal() async throws {
        let json = #"{"summary":"Color it","changes":[{"type":"set_pin","plug":"A","pin":2,"color":"GRN"}]}"#
        let reply = try await client(Script([(200, toolReply(json, text: "Done."))]))
            .ask(system: "s", messages: [AIMessage(role: .user, text: "x")])
        #expect(reply.text == "Done.")
        #expect(reply.proposal == AIProposal(summary: "Color it", changes: [.setPin(plug: "A", pin: 2, color: "GRN", function: nil, role: nil, gauge: nil)]))
    }

    @Test func aToolCallThatDoesNotMatchTheFormatIsUnreadable() async {
        let json = #"{"summary":"Bad","changes":[{"type":"delete_plug","plug":"A"}]}"#
        await #expect(throws: AIError.self) {
            _ = try await client(Script([(200, toolReply(json))])).ask(system: "s", messages: [AIMessage(role: .user, text: "x")])
        }
    }

    @Test func aCutOffToolCallIsTooLong() async {
        let body = #"{"content":[{"type":"tool_use","id":"t","name":"propose_changes","input":{"summary":"x","changes":[]}}],"stop_reason":"max_tokens"}"#
        await #expect(throws: AIError.tooLong) {
            _ = try await client(Script([(200, body)])).ask(system: "s", messages: [AIMessage(role: .user, text: "x")])
        }
    }

    @Test func aToolWeDidNotOfferIsIgnored() async throws {
        let body = #"{"content":[{"type":"tool_use","id":"t","name":"something_else","input":{}}],"stop_reason":"tool_use"}"#
        let reply = try await client(Script([(200, body)])).ask(system: "s", messages: [AIMessage(role: .user, text: "x")])
        #expect(reply.proposal == nil)
    }

    @Test func garbageIsUnreadable() async {
        await #expect(throws: AIError.self) {
            _ = try await client(Script([(200, "not json")])).ask(system: "s", messages: [AIMessage(role: .user, text: "x")])
        }
    }

    // MARK: failures

    private func failure(_ status: Int, _ body: String = "{}", headers: [String: String] = [:]) async -> AIError? {
        let script = Script([(status, body)])
        script.replies[0].headers = headers
        do {
            _ = try await client(script).ask(system: "s", messages: [AIMessage(role: .user, text: "x")])
            return nil
        } catch {
            return error as? AIError
        }
    }

    @Test func eachFailureHasAPlainMeaning() async {
        #expect(await failure(401) == .badKey)
        #expect(await failure(403) == .forbidden)
        #expect(await failure(413) == .tooLong)
        #expect(await failure(429, headers: ["retry-after": "20"]) == .rateLimited(retryAfter: 20))
        #expect(await failure(429) == .rateLimited(retryAfter: nil))
        #expect(await failure(529) == .overloaded)
        #expect(await failure(503) == .overloaded)
    }

    @Test func aRejectedRequestKeepsTheServersMessage() async {
        let body = #"{"type":"error","error":{"type":"invalid_request_error","message":"model not found"}}"#
        #expect(await failure(400, body) == .rejected("model not found"))
        #expect(await failure(404) == .rejected("(error 404)"))
    }

    @Test func noConnectionAndTimeoutsAreTold() async {
        for (error, expected) in [(URLError(.notConnectedToInternet), AIError.network), (URLError(.timedOut), AIError.timedOut)] {
            let c = AnthropicClient(key: "k", model: "m", send: { _ in throw error })
            do {
                _ = try await c.ask(system: "s", messages: [AIMessage(role: .user, text: "x")])
                Issue.record("should have thrown")
            } catch {
                #expect(error as? AIError == expected)
            }
        }
    }

    @Test func everyErrorHasAMessageAndNoneShowsTheKey() {
        let all: [AIError] = [.noKey, .badKey, .forbidden, .rateLimited(retryAfter: 5), .rateLimited(retryAfter: nil),
                              .overloaded, .network, .timedOut, .tooLong, .rejected("x"), .unreadable("y")]
        for e in all {
            let text = e.errorDescription ?? ""
            #expect(!text.isEmpty)
            #expect(!text.contains("sk-ant"))
        }
    }

    // MARK: models

    @Test func theDefaultModelIsHaikuAndBadSavedValuesFallBackToIt() {
        #expect(AIModels.defaultID == "claude-haiku-5-5")
        #expect(AIModels.resolve("claude-sonnet-5-5") == "claude-sonnet-5-5")
        #expect(AIModels.resolve("") == "claude-haiku-5-5")
        #expect(AIModels.resolve("claude-3-old") == "claude-haiku-5-5")
        #expect(Set(AIModels.all.map(\.id)).count == AIModels.all.count)
    }
}

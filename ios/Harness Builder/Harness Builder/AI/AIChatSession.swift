//
//  AIChatSession.swift
//  Harness Builder
//
//  One conversation with the assistant about the open harness. It sends what
//  you type with the harness as it is right now, and keeps the replies. A
//  reply may carry a proposal; the proposal is checked here before you ever
//  see it, and if the app rejects it the assistant gets one chance to fix it.
//  Nothing is applied here: that happens only from the review screen.
//

import Foundation
import Observation

@Observable
final class AIChatSession {
    struct Message: Identifiable, Equatable {
        let id = UUID()
        var role: AIMessage.Role
        var text: String
        var proposal: AIProposal?
    }

    private(set) var messages: [Message] = []
    private(set) var busy = false
    private(set) var errorText: String?

    let store: HarnessStore
    var harnessID: String
    /// Builds a client with the saved key and model, or nil when there is no key.
    var makeClient: () -> AnthropicClient?

    /// How many recent messages go back to the assistant each time.
    static let historyLimit = 12

    init(store: HarnessStore, harnessID: String, makeClient: @escaping () -> AnthropicClient?) {
        self.store = store
        self.harnessID = harnessID
        self.makeClient = makeClient
    }

    /// The newest proposal that hasn't been dealt with, for the edge tab's dot.
    var hasProposal: Bool { messages.last?.proposal != nil }

    func preview(_ proposal: AIProposal) -> ProposalPreview {
        ProposalEngine.preview(proposal, on: store.state, harnessID: harnessID)
    }

    /// Removes a proposal from the conversation once it has been applied or put aside.
    func dismissProposal(on id: UUID) {
        if let i = messages.firstIndex(where: { $0.id == id }) { messages[i].proposal = nil }
    }

    func clear() {
        messages = []
        errorText = nil
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !busy else { return }
        guard let client = makeClient() else {
            errorText = AIError.noKey.errorDescription
            return
        }

        errorText = nil
        messages.append(Message(role: .user, text: trimmed))
        busy = true
        defer { busy = false }

        let system = AIContext.systemPrompt(state: store.state, harnessID: harnessID)
        var history = Array(messages.suffix(Self.historyLimit)).map { m -> AIMessage in
            AIMessage(role: m.role, text: m.proposal == nil ? m.text : m.text + "\n[You proposed changes; the user is reviewing them.]")
        }

        do {
            var reply = try await ask(client, system, history)
            if let problem = problem(with: reply) {
                // One chance to fix it, with the app's exact complaint.
                history.append(AIMessage(role: .assistant, text: reply.text.isEmpty ? "(proposal)" : reply.text))
                history.append(AIMessage(role: .user, text: "The app could not use that proposal: \(problem) Fix it and propose again, or ask me a question if something is unclear."))
                reply = try await ask(client, system, history)
                if let still = problem(with: reply) {
                    messages.append(Message(role: .assistant,
                                            text: "I couldn't turn that into changes the app accepts. \(still) Try saying it a different way, or one plug at a time."))
                    return
                }
            }
            var text = reply.text
            if text.isEmpty { text = reply.proposal == nil ? "I didn't have anything to add." : "Here is what I would set. Nothing changes until you review it." }
            messages.append(Message(role: .assistant, text: text, proposal: reply.proposal))
        } catch let e as AIError {
            errorText = e.errorDescription
        } catch {
            errorText = AIError.network.errorDescription
        }
    }

    /// An unreadable proposal is fixed the same way as a rejected one.
    private func ask(_ client: AnthropicClient, _ system: String, _ history: [AIMessage]) async throws -> AIReply {
        do {
            return try await client.ask(system: system, messages: history)
        } catch AIError.unreadable(let detail) {
            return AIReply(text: "", proposal: nil, unreadable: detail)
        }
    }

    /// Why the app can't use this reply's proposal, or nil when there is none or it is fine.
    private func problem(with reply: AIReply) -> String? {
        if let detail = reply.unreadable { return "It didn't match the format (\(detail))." }
        guard let proposal = reply.proposal else { return nil }
        let p = preview(proposal)
        guard !p.errors.isEmpty else { return nil }
        return p.errors.prefix(5).joined(separator: " ")
    }
}

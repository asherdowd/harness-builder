//
//  AnthropicClient.swift
//  Harness Builder
//
//  Talks to the Anthropic Messages API straight from the device with the
//  user's own key. No server in between. The assistant gets one tool
//  (propose_changes) and its reply is turned into text plus an optional
//  AIProposal. Sending is a closure so tests can supply canned replies.
//
//  The tool is called with tool_choice "auto" and a strict schema, not forced:
//  forcing a tool is rejected by some of the models offered here.
//

import Foundation

typealias AISend = (URLRequest) async throws -> (Data, HTTPURLResponse)

struct AIMessage: Equatable {
    enum Role: String { case user, assistant }
    var role: Role
    var text: String
}

struct AIReply: Equatable {
    var text: String
    var proposal: AIProposal?
    /// Set when the assistant called the tool but its answer couldn't be read.
    var unreadable: String?
}

enum AIError: LocalizedError, Equatable {
    case noKey
    case badKey
    case forbidden
    case rateLimited(retryAfter: Int?)
    case overloaded
    case network
    case timedOut
    case tooLong
    case rejected(String)
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .noKey: return "Add your Anthropic key in Settings first."
        case .badKey: return "Anthropic didn't accept the key. Check it in Settings."
        case .forbidden: return "This key isn't allowed to use that model."
        case .rateLimited(let s):
            return "Anthropic says to slow down." + (s.map { " Try again in about \($0) seconds." } ?? " Try again in a minute.")
        case .overloaded: return "Anthropic is busy right now. Try again in a moment."
        case .network: return "Couldn't reach Anthropic. Check your connection."
        case .timedOut: return "That took too long. Try again."
        case .tooLong: return "That was too much to answer at once. Try a smaller piece."
        case .rejected(let m): return "Anthropic couldn't use that request. \(m)"
        case .unreadable: return "The assistant's answer couldn't be read. Try again."
        }
    }
}

struct AnthropicClient {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2023-06-01"

    let key: String
    let model: String
    var send: AISend = AnthropicClient.urlSessionSend

    // MARK: asking

    func ask(system: String, messages: [AIMessage]) async throws -> AIReply {
        let data = try await post(try request(system: system, messages: messages))
        return try Self.parse(data)
    }

    /// A tiny request to check the key and model work.
    func testKey() async throws {
        let body: [String: Any] = ["model": model, "max_tokens": 1,
                                   "messages": [["role": "user", "content": "Hi"]]]
        _ = try await post(try urlRequest(body: body))
    }

    private func post(_ req: URLRequest) async throws -> Data {
        let (data, response): (Data, HTTPURLResponse)
        do {
            (data, response) = try await send(req)
        } catch let e as AIError {
            throw e
        } catch let e as URLError {
            throw e.code == .timedOut ? AIError.timedOut : AIError.network
        } catch {
            throw AIError.network
        }
        guard (200..<300).contains(response.statusCode) else {
            throw Self.error(status: response.statusCode, data: data,
                             retryAfter: response.value(forHTTPHeaderField: "retry-after").flatMap { Int($0) })
        }
        return data
    }

    // MARK: building and reading

    func request(system: String, messages: [AIMessage], maxTokens: Int = 4096) throws -> URLRequest {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.text] },
            "tools": [AIContext.tool],
            "tool_choice": ["type": "auto"],
        ]
        return try urlRequest(body: body)
    }

    private func urlRequest(body: [String: Any]) throws -> URLRequest {
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return req
    }

    static func parse(_ data: Data) throws -> AIReply {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = root["content"] as? [[String: Any]]
        else { throw AIError.unreadable("not a message") }

        var text: [String] = []
        var proposal: AIProposal?
        for block in content {
            switch block["type"] as? String {
            case "text":
                if let t = block["text"] as? String, !t.isEmpty { text.append(t) }
            case "tool_use":
                guard block["name"] as? String == AIContext.toolName, let input = block["input"] else { continue }
                if root["stop_reason"] as? String == "max_tokens" { throw AIError.tooLong }
                do {
                    let json = try JSONSerialization.data(withJSONObject: input)
                    proposal = try JSONDecoder().decode(AIProposal.self, from: json)
                } catch {
                    throw AIError.unreadable("the proposal didn't match the format (\(error.localizedDescription))")
                }
            default:
                continue
            }
        }
        return AIReply(text: text.joined(separator: "\n\n"), proposal: proposal)
    }

    static func error(status: Int, data: Data, retryAfter: Int?) -> AIError {
        let message = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])
            .flatMap { $0["error"] as? [String: Any] }
            .flatMap { $0["message"] as? String }
        switch status {
        case 401: return .badKey
        case 403: return .forbidden
        case 413: return .tooLong
        case 429: return .rateLimited(retryAfter: retryAfter)
        case 529, 500...599: return .overloaded
        default: return .rejected(message ?? "(error \(status))")
        }
    }

    static let urlSessionSend: AISend = { req in
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw AIError.network }
        return (data, http)
    }
}

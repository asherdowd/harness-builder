//
//  AIModels.swift
//  Harness Builder
//
//  The models the assistant can use. The list lives here so adding a model
//  later is one line. Haiku is the default: it is the cheapest and quick, and
//  the app's own checks catch bad output. Sonnet is better at guessing what a
//  wire does.
//

import Foundation

struct AIModel: Identifiable, Equatable {
    let id: String          // the API model name
    let label: String
    let blurb: String
}

enum AIModels {
    static let storageKey = "aiModel"

    static let haiku = AIModel(id: "claude-haiku-5-5", label: "Haiku 5.5",
                               blurb: "Faster and cheaper.")
    static let sonnet = AIModel(id: "claude-sonnet-5-5", label: "Sonnet 5.5",
                                blurb: "Better at guessing what a wire does, and costs more.")

    static let all = [haiku, sonnet]
    static var defaultID: String { haiku.id }

    /// A saved choice, or the default when it is missing or no longer offered.
    static func resolve(_ saved: String) -> String {
        all.contains { $0.id == saved } ? saved : defaultID
    }
}

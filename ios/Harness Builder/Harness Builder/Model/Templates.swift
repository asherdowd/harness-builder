//
//  Templates.swift
//  Harness Builder
//
//  Templates the user can start from when adding a harness. They live in
//  Resources/Templates.json and are copied (never edited in place) into the
//  user's build.
//

import Foundation

struct Template: Codable, Identifiable {
    var key: String          // "VX", "SHK", "ECU", "COMP"
    var label: String        // shown in the Add a harness sheet
    var sub: String          // one-line description
    var repeatable: Bool     // can be added more than once
    var harness: Harness     // the content that gets copied

    var id: String { key }
}

struct TemplateLibrary: Codable {
    var version: Int
    var templates: [Template]

    /// Keys loaded together by "Try the example".
    static let exampleKeys = ["VX", "SHK", "ECU"]

    static func loadFromBundle(_ bundle: Bundle = .main) throws -> TemplateLibrary {
        guard let url = bundle.url(forResource: "Templates", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "Templates.json is missing from the app bundle."])
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TemplateLibrary.self, from: data)
    }
}

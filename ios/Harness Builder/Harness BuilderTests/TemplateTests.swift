//
//  TemplateTests.swift
//  Harness BuilderTests
//
//  The bundled example harnesses: they load, they are internally consistent,
//  and they stay clean of research notes, reference codes and personal names.
//

import Foundation
import Testing
@testable import Harness_Builder

@MainActor
struct TemplateTests {
    private func library() throws -> TemplateLibrary {
        try Fixture.bundledLibrary()
    }

    private func allPlugs(_ lib: TemplateLibrary) -> [Connector] {
        lib.templates.flatMap { $0.harness.connectors }
    }

    private func matches(_ text: String?, _ pattern: String) -> Bool {
        guard let text else { return false }
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: structure

    @Test func templatesLoadFromTheAppBundle() throws {
        let lib = try library()
        #expect(lib.version >= 1)
        #expect(Set(lib.templates.map(\.key)) == ["VX", "SHK", "ECU", "COMP"])
    }

    @Test func keysAreUniqueAndExamplesExist() throws {
        let lib = try library()
        let keys = lib.templates.map(\.key)
        #expect(Set(keys).count == keys.count)
        for key in TemplateLibrary.exampleKeys {
            #expect(keys.contains(key), "example key \(key) has no template")
        }
    }

    @Test func onlyTheComponentCanBeAddedRepeatedly() throws {
        for t in try library().templates {
            #expect(t.repeatable == (t.key == "COMP"), "\(t.key)")
        }
    }

    @Test func aTemplatesHarnessIDMatchesItsKeyUnlessRepeatable() throws {
        // The Add a harness sheet decides "Already added" by comparing these.
        for t in try library().templates where !t.repeatable {
            #expect(t.harness.id == t.key)
        }
        let comp = try #require(try library().templates.first { $0.key == "COMP" })
        #expect(comp.harness.kind == .component)
    }

    @Test func plugIDsAreUniqueAcrossTheExamples() throws {
        let lib = try library()
        let ids = lib.templates.filter { !$0.repeatable }.flatMap { $0.harness.connectors.map(\.id) }
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyPlugIsWellFormed() throws {
        for c in allPlugs(try library()) {
            #expect(!c.rows.isEmpty, "\(c.id) has no rows")
            #expect(!c.flatPins.isEmpty, "\(c.id) has no pins")
            #expect(!c.shape.isEmpty)
            if let total = c.totalPositions {
                #expect(total == c.flatPins.count, "\(c.id) pin total is wrong")
            }
            for r in c.rows {
                #expect(r.pins.count <= r.positions, "\(c.id) row \(r.row) has too many pins")
            }
            #expect(!c.title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @Test func everyExamplePlugCanBeDrawn() throws {
        for c in allPlugs(try library()) {
            if case .unknown = ArtModel.make(for: c).kind {
                Issue.record("\(c.id) (\(c.shape)) has no drawing and is not marked as pending")
            }
        }
    }

    @Test func pinValuesAreFromTheKnownLists() throws {
        let confidences: Set<String> = ["High", "Med-High", "Med", "Low-Med", "Low"]
        for c in allPlugs(try library()) {
            for fp in c.flatPins {
                let p = fp.pin
                if let conf = p.confidence { #expect(confidences.contains(conf), "\(c.id) pin \(fp.number): \(conf)") }
                if let role = p.role { #expect(WireRole(rawValue: role) != nil, "\(c.id) pin \(fp.number): \(role)") }
                if let g = p.gauge { #expect(gaugeChoices.contains(g), "\(c.id) pin \(fp.number): \(g) AWG") }
                if p.populated, let color = p.color, !color.isEmpty, color.lowercased() != "n/a" {
                    #expect(!WireColor.parse(color).isEmpty, "\(c.id) pin \(fp.number): \(color)")
                    #expect(WireColor.parse(color).allSatisfy { $0.hex != nil }, "\(c.id) pin \(fp.number): unknown color \(color)")
                }
            }
        }
    }

    @Test func netIDsLinkPinsAcrossTheExamples() throws {
        // Wire tracing needs at least some pins that share a net across harnesses.
        let lib = try library()
        let harnesses = lib.templates.filter { TemplateLibrary.exampleKeys.contains($0.key) }.map(\.harness)
        var found = false
        for h in harnesses {
            for c in h.connectors {
                for fp in c.flatPins where fp.pin.netId != nil {
                    if !WireTrace.links(for: fp, in: c, harnesses: harnesses).isEmpty { found = true }
                }
            }
        }
        #expect(found, "no example wire can be traced to another plug")
    }

    // MARK: clean data

    @Test func researchFieldsAreEmptyInTheExamples() throws {
        for c in allPlugs(try library()) {
            #expect((c.description ?? "").isEmpty, "\(c.id) description")
            #expect((c.anomalies ?? []).isEmpty, "\(c.id) anomalies")
            #expect((c.status ?? "").isEmpty, "\(c.id) status")
            #expect((c.condition ?? "").isEmpty, "\(c.id) condition")
            #expect((c.buildAction ?? "").isEmpty, "\(c.id) buildAction")
            #expect((c.location ?? "").isEmpty, "\(c.id) location")
            #expect((c.shapeNote ?? "").isEmpty, "\(c.id) shapeNote")
            #expect((c.partNumber ?? "").isEmpty, "\(c.id) partNumber")
            #expect((c.gender ?? "").isEmpty, "\(c.id) gender")
            for fp in c.flatPins {
                #expect((fp.pin.colorNote ?? "").isEmpty, "\(c.id) pin \(fp.number) colorNote")
            }
        }
    }

    @Test func noReferenceCodesOrPersonalNamesAreVisibleInTheExamples() throws {
        // Reference codes look like VX-EH-03, SHK-EH-04, ECU-EH-01, MY-02 or CMP-01.
        let code = #"\b[A-Z]{2,5}-[A-Z]{1,3}-?[0-9]{2}\b|\bMY-[0-9]+\b|\bCMP-[0-9]+\b"#
        let personal = "(?i)seth|dowd|bagel"
        for t in try library().templates {
            let visible = [t.label, t.sub, t.harness.title, t.harness.tab]
            for text in visible {
                #expect(!matches(text, code), "code in \(t.key): \(text ?? "")")
                #expect(!matches(text, personal), "personal name in \(t.key): \(text ?? "")")
            }
            for c in t.harness.connectors {
                for text in [c.name, c.displayName] {
                    #expect(!matches(text, code), "code in plug \(c.id): \(text ?? "")")
                    #expect(!matches(text, personal), "personal name in plug \(c.id): \(text ?? "")")
                }
                for fp in c.flatPins {
                    #expect(!matches(fp.pin.guess, code), "code in \(c.id) pin \(fp.number): \(fp.pin.guess ?? "")")
                    #expect(!matches(fp.pin.guess, personal), "personal name in \(c.id) pin \(fp.number)")
                }
            }
        }
    }

    @Test func noResearchShorthandInWireFunctions() throws {
        // Hedges and research marks that belong in notes, not in what the app shows.
        let shorthand = #"\?\?|\bTODO\b|\bTBD\b|\bhypothes|\bunverified\b|\bprobably\b|\bmaybe\b"#
        for c in allPlugs(try library()) {
            for fp in c.flatPins {
                #expect(!matches(fp.pin.guess, "(?i)" + shorthand), "\(c.id) pin \(fp.number): \(fp.pin.guess ?? "")")
            }
        }
    }
}

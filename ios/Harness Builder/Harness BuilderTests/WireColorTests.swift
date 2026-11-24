//
//  WireColorTests.swift
//  Harness BuilderTests
//
//  Wire color codes: parsing, names, and the pieces the wizard edits.
//

import Testing
@testable import Harness_Builder

@MainActor
struct WireColorTests {
    @Test func twoToneCodeSplitsIntoTwoSegments() {
        let segs = WireColor.parse("GRN/WHT")
        #expect(segs.map(\.token) == ["GRN", "WHT"])
        #expect(segs.allSatisfy { $0.hex != nil })
        #expect(segs.allSatisfy { !$0.isLight })
    }

    @Test func parsingIgnoresCase() {
        #expect(WireColor.parse("grn/wht").map(\.token) == ["GRN", "WHT"])
    }

    @Test func lightPrefixMakesTheColorLighter() throws {
        let plain = try #require(WireColor.parse("BLU").first?.hex)
        let seg = try #require(WireColor.parse("LT BLU").first)
        let light = try #require(seg.hex)
        #expect(seg.isLight)
        #expect(seg.token == "BLU")
        #expect(light != plain)
        // Lighter means every channel is at least as bright.
        #expect((light >> 16) & 0xff >= (plain >> 16) & 0xff)
        #expect((light >> 8) & 0xff >= (plain >> 8) & 0xff)
        #expect(light & 0xff >= plain & 0xff)
    }

    @Test func emptyOrNotApplicableMeansNoColor() {
        #expect(WireColor.parse(nil).isEmpty)
        #expect(WireColor.parse("").isEmpty)
        #expect(WireColor.parse("n/a").isEmpty)
        #expect(WireColor.parse("N/A").isEmpty)
        #expect(WireColor.label(nil) == "No color")
    }

    @Test func unknownCodeIsKeptButHasNoColor() throws {
        let seg = try #require(WireColor.parse("XYZ").first)
        #expect(seg.hex == nil)
        #expect(WireColor.label("XYZ") == "XYZ")
    }

    @Test func labelsReadNaturally() {
        #expect(WireColor.label("LT GRN/WHT") == "Light Green / White")
        #expect(WireColor.label("BLK") == "Black")
        #expect(WireColor.label("RED/BLK") == "Red / Black")
    }

    @Test func darkWiresGetALightOutline() {
        #expect(WireColor.parse("BLK").first?.outline == true)
        #expect(WireColor.parse("BRN").first?.outline == true)
        #expect(WireColor.parse("WHT").first?.outline == false)
    }

    @Test func everyWizardColorIsKnown() {
        for token in wireTokens {
            #expect(WireColor.parse(token.code).first?.hex != nil, "no color for \(token.code)")
            #expect(WireColor.label(token.code) == token.name)
        }
    }

    @Test func colorPartsSplitAndRebuildACode() {
        let parts = ColorParts(code: "lt grn/wht")
        #expect(parts.main == "GRN")
        #expect(parts.light)
        #expect(parts.stripe == "WHT")
        #expect(parts.code == "LT GRN/WHT")
    }

    @Test func colorPartsRoundTrip() {
        for code in ["RED", "RED/BLK", "LT BLU", "LT BLU/WHT"] {
            #expect(ColorParts(code: code).code == code)
        }
    }

    @Test func colorPartsWithNothingGiveNoCode() {
        #expect(ColorParts(code: nil).code == "")
        #expect(ColorParts(code: "").code == "")
        var parts = ColorParts(code: nil)
        parts.stripe = "WHT"          // a stripe on its own is not a color
        #expect(parts.code == "")
    }

    @Test func gaugeChoicesAreStandardSizes() {
        #expect(gaugeChoices.contains(18))
        #expect(gaugeChoices == gaugeChoices.sorted(by: >))
    }
}

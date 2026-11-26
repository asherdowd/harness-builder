//
//  WordingTests.swift
//  Harness BuilderTests
//

import Testing
@testable import Harness_Builder

@MainActor
struct WordingTests {
    @Test func oneIsSingularEverythingElseIsPlural() {
        #expect(pinCountText(1) == "1 pin")
        #expect(pinCountText(0) == "0 pins")
        #expect(pinCountText(2) == "2 pins")
        #expect(pinCountText(60) == "60 pins")
    }
}

//
//  SettingsTests.swift
//  Harness BuilderTests
//
//  The appearance setting and the light/dark palette.
//

import SwiftUI
import UIKit
import Testing
@testable import Harness_Builder

@MainActor
struct SettingsTests {
    @Test func appearanceMapsToTheRightScheme() {
        #expect(AppearanceMode.system.scheme == nil)
        #expect(AppearanceMode.light.scheme == .light)
        #expect(AppearanceMode.dark.scheme == .dark)
    }

    @Test func unknownOrMissingValuesMeanSystem() {
        #expect(AppearanceMode.from("") == .system)
        #expect(AppearanceMode.from("sepia") == .system)
        #expect(AppearanceMode.from("dark") == .dark)
        #expect(AppearanceMode.from("light") == .light)
    }

    @Test func everyModeHasALabelAndAUniqueSavedValue() {
        let all = AppearanceMode.allCases
        #expect(all.map(\.label) == ["System", "Light", "Dark"])
        #expect(Set(all.map(\.rawValue)).count == all.count)
    }

    private func resolve(_ c: Color, _ style: UIUserInterfaceStyle) -> [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(c).resolvedColor(with: UITraitCollection(userInterfaceStyle: style)).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b]
    }

    @Test func surfacesAndTextChangeBetweenLightAndDark() {
        for c in [Palette.bg, Palette.sheetBg, Palette.field, Palette.text, Palette.chipFill, Palette.bodyFill] {
            #expect(resolve(c, .light) != resolve(c, .dark))
        }
    }

    @Test func textIsDarkOnLightAndLightOnDark() {
        #expect(resolve(Palette.text, .light)[0] < 0.3)
        #expect(resolve(Palette.text, .dark)[0] > 0.9)
        #expect(resolve(Palette.sheetBg, .light)[0] > 0.9)
        #expect(resolve(Palette.sheetBg, .dark)[0] < 0.3)
    }

    @Test func solidAmberAndPinColorsAreTheSameInBothModes() {
        for c in [Palette.amber, Palette.amberText, Palette.pinFill] {
            #expect(resolve(c, .light) == resolve(c, .dark))
        }
    }
}

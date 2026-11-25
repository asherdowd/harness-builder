//
//  Palette.swift
//  Harness Builder
//
//  Colors for the whole app. Each is a light/dark pair that follows the
//  appearance (System, Light or Dark in Settings). Exports force the dark
//  pair so a PDF or PNG looks the same whatever the phone is set to.
//

import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: opacity)
    }

    /// A color that switches with the appearance.
    init(light: UInt32, dark: UInt32, lightOpacity: Double = 1, darkOpacity: Double = 1) {
        func ui(_ hex: UInt32, _ opacity: Double) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xff) / 255,
                    green: CGFloat((hex >> 8) & 0xff) / 255,
                    blue: CGFloat(hex & 0xff) / 255,
                    alpha: opacity)
        }
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? ui(dark, darkOpacity) : ui(light, lightOpacity)
        })
    }
}

enum Palette {
    // Canvas
    static let bg = Color(light: 0xeceff3, dark: 0x12151a)
    static let trunkFill = Color(light: 0xd9dee5, dark: 0x262b33)
    static let trunkStroke = Color(light: 0x9aa3af, dark: 0x4a515c)
    static let trunkStrand = Color(light: 0xc3cad3, dark: 0x343b45)
    static let bodyFill = Color(light: 0xb0b6bd, dark: 0x1b1f26)
    static let bodyStroke = Color(light: 0x4a525d, dark: 0x7c8794)
    static let leadStroke = Color(light: 0x8a93a0, dark: 0x565e6a)
    static let pinFill = Color(hex: 0xe2a355)
    static let pinRing = Color(light: 0x1c1205, dark: 0x0d0f12)
    static let pinEmptyStroke = Color(light: 0x3a4049, dark: 0x454c56)
    static let grid = Color(light: 0xd6dbe2, dark: 0x252b34, lightOpacity: 0.9, darkOpacity: 0.65)

    // Text
    static let text = Color(light: 0x1b1f26, dark: 0xffffff)
    static let nameText = Color(light: 0x5d6773, dark: 0x8b93a1)
    static let chipText = Color(light: 0x3b4350, dark: 0xcfd4db)
    static let captionText = Color(light: 0x5d6773, dark: 0x9aa2ad)
    static let segText = Color(light: 0x3b4350, dark: 0xaeb4bd)
    /// Pin numbers and ids.
    static let idText = Color(light: 0x8a5a12, dark: 0xe8b25c)

    // Amber: `amber` is a solid fill (always with `amberText` on top);
    // `amberInk` is amber used as text, a tint or an outline.
    static let amber = Color(hex: 0xe8b25c)
    static let amberText = Color(hex: 0x1a1408)
    static let amberInk = Color(light: 0x9a600f, dark: 0xe8b25c)

    // Surfaces
    static let surface = Color(light: 0xf7f8fa, dark: 0x181c22)
    static let sheetBg = Color(light: 0xffffff, dark: 0x1b1f26)
    static let field = Color(light: 0xeef0f4, dark: 0x1d2128)
    static let chipFill = Color(light: 0xe3e7ec, dark: 0x2a2e35)
    static let divider = Color(light: 0xd6dbe2, dark: 0x2c323b)
    static let rowDivider = Color(light: 0xdde1e7, dark: 0x2a2e35)
    static let cardStroke = Color(light: 0xc9ced6, dark: 0x3a414c)
    static let selectedFill = Color(light: 0xf6e7c8, dark: 0x2d2a22)

    // Warnings and links
    static let warnStrong = Color(light: 0xc0392b, dark: 0xff6b5b)
    static let warnText = Color(light: 0x8a1f14, dark: 0xffb4ab)
    static let warnFill = Color(light: 0xfbe3e0, dark: 0x4a1f1b)
    static let linkOutline = Color(light: 0x2b7f9a, dark: 0x6fb3c9)
}

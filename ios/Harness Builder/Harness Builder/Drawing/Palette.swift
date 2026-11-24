//
//  Palette.swift
//  Harness Builder
//
//  Colors used by the canvas (same values as the web app's theme).
//

import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: opacity)
    }
}

enum Palette {
    static let bg = Color(hex: 0x12151a)
    static let trunkFill = Color(hex: 0x262b33)
    static let trunkStroke = Color(hex: 0x4a515c)
    static let trunkStrand = Color(hex: 0x343b45)
    static let bodyFill = Color(hex: 0x1b1f26)
    static let bodyStroke = Color(hex: 0x7c8794)
    static let leadStroke = Color(hex: 0x565e6a)
    static let pinFill = Color(hex: 0xe2a355)
    static let pinRing = Color(hex: 0x0d0f12)
    static let pinEmptyStroke = Color(hex: 0x454c56)
    static let idText = Color(hex: 0xe8b25c)
    static let nameText = Color(hex: 0x8b93a1)
    static let amber = Color(hex: 0xe8b25c)
    static let amberText = Color(hex: 0x1a1408)
    static let chipFill = Color(hex: 0x2a2e35)
    static let chipText = Color(hex: 0xcfd4db)
}

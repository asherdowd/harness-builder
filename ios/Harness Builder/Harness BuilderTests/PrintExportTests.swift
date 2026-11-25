//
//  PrintExportTests.swift
//  Harness BuilderTests
//
//  The print-friendly export: a real file with a white page, and the dark
//  export unchanged.
//

import SwiftUI
import UIKit
import Testing
@testable import Harness_Builder

@MainActor
struct PrintExportTests {
    private func harness() -> Harness {
        let a = Fixture.connector("A", name: "Plug A", pins: Fixture.pins(4))
        return Fixture.harness("H1", title: "Engine", plugs: [a])
    }

    /// Brightness (0...1) of the top-left pixel of a PNG file.
    private func cornerBrightness(_ url: URL) throws -> Double {
        let image = try #require(UIImage(contentsOfFile: url.path)?.cgImage)
        var px = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let ctx = try #require(CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                         space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))   // scales the whole image to one pixel
        _ = px
        // Sample the real corner by drawing the image offset so its top-left pixel lands in the 1x1 context.
        ctx.clear(CGRect(x: 0, y: 0, width: 1, height: 1))
        ctx.draw(image, in: CGRect(x: 0, y: -(image.height - 1), width: image.width, height: image.height))
        return (Double(px[0]) + Double(px[1]) + Double(px[2])) / (3 * 255)
    }

    @Test func styleMapsToAColorScheme() {
        #expect(ExportStyle.dark.scheme == .dark)
        #expect(ExportStyle.print.scheme == .light)
    }

    @Test func aPrintPDFIsARealPDF() throws {
        let urls = try HarnessExporter.export([harness()], includeTable: true, format: .pdf, style: .print)
        let url = try #require(urls.first)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let data = try Data(contentsOf: url)
        #expect(String(decoding: data.prefix(5), as: UTF8.self) == "%PDF-")
    }

    @Test func aPrintPNGHasAWhitePage() throws {
        let urls = try HarnessExporter.export([harness()], includeTable: false, format: .png, style: .print)
        let url = try #require(urls.first)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(try cornerBrightness(url) > 0.95)
    }

    @Test func theDarkPNGStaysDark() throws {
        let urls = try HarnessExporter.export([harness()], includeTable: false, format: .png)
        let url = try #require(urls.first)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(try cornerBrightness(url) < 0.2)
    }
}

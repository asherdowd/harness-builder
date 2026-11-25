//
//  KeychainStoreTests.swift
//  Harness BuilderTests
//
//  The Anthropic key's storage. Each test uses its own Keychain service name
//  and removes it afterwards, so the real key is never touched.
//

import Foundation
import Testing
@testable import Harness_Builder

@MainActor
struct KeychainStoreTests {
    private func store() -> KeychainStore {
        KeychainStore(service: "BagelBytez.Harness-Builder.tests." + UUID().uuidString, account: "api-key")
    }

    @Test func aSavedKeyCanBeReadBack() throws {
        let k = store()
        defer { k.delete() }
        try k.save("sk-ant-test-1234")
        #expect(k.read() == "sk-ant-test-1234")
        #expect(k.hasKey)
    }

    @Test func savingAgainReplacesTheKey() throws {
        let k = store()
        defer { k.delete() }
        try k.save("sk-ant-first-1111")
        try k.save("sk-ant-second-2222")
        #expect(k.read() == "sk-ant-second-2222")
    }

    @Test func deletingRemovesIt() throws {
        let k = store()
        try k.save("sk-ant-test-1234")
        k.delete()
        #expect(k.read() == nil)
        #expect(!k.hasKey)
    }

    @Test func noKeyMeansNil() {
        #expect(store().read() == nil)
    }

    @Test func surroundingSpacesAreTrimmed() throws {
        let k = store()
        defer { k.delete() }
        try k.save("  sk-ant-test-1234\n")
        #expect(k.read() == "sk-ant-test-1234")
    }

    @Test func emptyOrSpacedKeysAreRefused() {
        let k = store()
        #expect(throws: KeychainStore.KeyError.empty) { try k.save("   ") }
        #expect(throws: KeychainStore.KeyError.hasSpaces) { try k.save("sk-ant abc") }
        #expect(throws: KeychainStore.KeyError.hasSpaces) { try k.save("sk-ant\nabc") }
        #expect(k.read() == nil)
    }

    @Test func aRefusedKeyKeepsTheOldOne() throws {
        let k = store()
        defer { k.delete() }
        try k.save("sk-ant-keep-9999")
        _ = try? k.save("not a key")
        #expect(k.read() == "sk-ant-keep-9999")
    }

    @Test func onlyTheLastFourCharactersAreShown() {
        #expect(KeychainStore.masked("sk-ant-api03-abcdefWXYZ") == "••••WXYZ")
        #expect(!KeychainStore.masked("sk-ant-api03-abcdefWXYZ").contains("api03"))
    }

    @Test func theKeyIsNeverInTheSavedData() throws {
        let k = store()
        defer { k.delete() }
        try k.save("sk-ant-secret-0000")
        let a = Fixture.connector("A", pins: Fixture.pins(1))
        let s = try Fixture.store(AppState(harnesses: [Fixture.harness("H1", plugs: [a])], activeID: "H1"))
        let text = String(decoding: try s.backupData(), as: UTF8.self)
        #expect(!text.contains("sk-ant"))
    }
}

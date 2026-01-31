import Foundation
import Testing
@testable import OpenClawSDK

struct DeviceIdentityTests {
    @Test func createsAndPersistsIdentity() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = DeviceIdentityStore(rootURL: base)
        let first = store.loadOrCreate()
        let second = store.loadOrCreate()
        #expect(first.deviceId == second.deviceId)
        #expect(!first.publicKey.isEmpty)
        #expect(!first.privateKey.isEmpty)
    }

    @Test func signsPayload() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = DeviceIdentityStore(rootURL: base)
        let identity = store.loadOrCreate()
        let signature = store.signPayload("hello", identity: identity)
        #expect(signature != nil)
    }
}

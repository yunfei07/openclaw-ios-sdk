import Testing
@testable import OpenClawSDK

struct TokenStoreTests {
    @Test func storesAndLoadsToken() throws {
        let store = InMemoryTokenStore()
        _ = store.storeToken(deviceId: "device", role: "operator", token: "abc", scopes: ["operator.read"])
        let loaded = store.loadToken(deviceId: "device", role: "operator")
        #expect(loaded?.token == "abc")
        #expect(loaded?.scopes == ["operator.read"])
    }
}

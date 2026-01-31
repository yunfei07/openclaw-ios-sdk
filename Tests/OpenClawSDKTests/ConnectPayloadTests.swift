import Foundation
import Testing
import OpenClawProtocol
@testable import OpenClawSDK

struct ConnectPayloadTests {
    @Test func buildsConnectParamsWithChallenge() throws {
        let identityStore = DeviceIdentityStore(
            rootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let identity = identityStore.loadOrCreate()

        let params = ConnectPayloadBuilder.build(
            clientId: "openclaw-ios",
            clientMode: "ui",
            displayName: "iPhone",
            role: "operator",
            scopes: ["operator.read", "operator.write"],
            token: "tok",
            challengeNonce: "nonce",
            identity: identity
        )

        let authToken = params.auth?["token"]?.value as? String
        let device = params.device
        #expect(authToken == "tok")
        #expect(device?["nonce"] != nil)

        let publicKey = device?["publicKey"]?.value as? String
        #expect(publicKey == base64UrlFromBase64(identity.publicKey))
    }
}

private func base64UrlFromBase64(_ base64: String) -> String? {
    guard let data = Data(base64Encoded: base64) else { return nil }
    let encoded = data.base64EncodedString()
    return encoded
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

import Foundation
import OpenClawProtocol

public enum ConnectPayloadBuilder {
    public static func build(
        clientId: String,
        clientMode: String,
        displayName: String,
        role: String,
        scopes: [String],
        token: String?,
        challengeNonce: String?,
        identity: DeviceIdentity
    ) -> ConnectParams {
        let client: [String: AnyCodable] = [
            "id": AnyCodable(clientId),
            "displayName": AnyCodable(displayName),
            "version": AnyCodable("dev"),
            "platform": AnyCodable(ProcessInfo.processInfo.operatingSystemVersionString),
            "mode": AnyCodable(clientMode),
            "instanceId": AnyCodable(UUID().uuidString.lowercased()),
        ]

        var auth: [String: AnyCodable]? = nil
        if let token {
            auth = ["token": AnyCodable(token)]
        }

        var device: [String: AnyCodable]? = nil
        let signedAtMs = Int(Date().timeIntervalSince1970 * 1000)
        var payloadParts = [
            challengeNonce == nil ? "v1" : "v2",
            identity.deviceId,
            clientId,
            clientMode,
            role,
            scopes.joined(separator: ","),
            String(signedAtMs),
            token ?? "",
        ]
        if let challengeNonce {
            payloadParts.append(challengeNonce)
        }
        let payload = payloadParts.joined(separator: "|")
        if let signature = DeviceIdentityStore().signPayload(payload, identity: identity),
           let publicKey = base64UrlFromBase64(identity.publicKey)
        {
            device = [
                "id": AnyCodable(identity.deviceId),
                "publicKey": AnyCodable(publicKey),
                "signature": AnyCodable(signature),
                "signedAt": AnyCodable(signedAtMs),
            ]
            if let challengeNonce {
                device?["nonce"] = AnyCodable(challengeNonce)
            }
        }

        return ConnectParams(
            minprotocol: GATEWAY_PROTOCOL_VERSION,
            maxprotocol: GATEWAY_PROTOCOL_VERSION,
            client: client,
            caps: [],
            commands: nil,
            permissions: nil,
            pathenv: nil,
            role: role,
            scopes: scopes,
            device: device,
            auth: auth,
            locale: Locale.preferredLanguages.first,
            useragent: ProcessInfo.processInfo.operatingSystemVersionString
        )
    }

    private static func base64UrlFromBase64(_ base64: String) -> String? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        let encoded = data.base64EncodedString()
        return encoded
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

import CryptoKit
import Foundation

public struct DeviceIdentity: Codable, Sendable {
    public var deviceId: String
    public var publicKey: String
    public var privateKey: String
    public var createdAtMs: Int

    public init(deviceId: String, publicKey: String, privateKey: String, createdAtMs: Int) {
        self.deviceId = deviceId
        self.publicKey = publicKey
        self.privateKey = privateKey
        self.createdAtMs = createdAtMs
    }
}

public final class DeviceIdentityStore: Sendable {
    private let rootURL: URL

    public init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
        } else if let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            self.rootURL = base.appendingPathComponent("OpenClaw", isDirectory: true)
        } else {
            self.rootURL = FileManager.default.temporaryDirectory.appendingPathComponent("openclaw", isDirectory: true)
        }
    }

    public func loadOrCreate() -> DeviceIdentity {
        let url = self.fileURL()
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(DeviceIdentity.self, from: data),
           !decoded.deviceId.isEmpty,
           !decoded.publicKey.isEmpty,
           !decoded.privateKey.isEmpty
        {
            return decoded
        }
        let identity = generate()
        save(identity)
        return identity
    }

    public func signPayload(_ payload: String, identity: DeviceIdentity) -> String? {
        guard let privateKeyData = Data(base64Encoded: identity.privateKey) else { return nil }
        do {
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
            let signature = try privateKey.signature(for: Data(payload.utf8))
            return base64UrlEncode(signature)
        } catch {
            return nil
        }
    }

    private func generate() -> DeviceIdentity {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let publicKeyData = publicKey.rawRepresentation
        let privateKeyData = privateKey.rawRepresentation
        let deviceId = SHA256.hash(data: publicKeyData).compactMap { String(format: "%02x", $0) }.joined()
        return DeviceIdentity(
            deviceId: deviceId,
            publicKey: publicKeyData.base64EncodedString(),
            privateKey: privateKeyData.base64EncodedString(),
            createdAtMs: Int(Date().timeIntervalSince1970 * 1000)
        )
    }

    private func base64UrlEncode(_ data: Data) -> String {
        let base64 = data.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func fileURL() -> URL {
        rootURL
            .appendingPathComponent("identity", isDirectory: true)
            .appendingPathComponent("device.json", isDirectory: false)
    }

    private func save(_ identity: DeviceIdentity) {
        let url = self.fileURL()
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(identity)
            try data.write(to: url, options: [.atomic])
        } catch {
            // best-effort
        }
    }
}

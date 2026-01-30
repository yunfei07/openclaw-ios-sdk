import Foundation

public struct DeviceAuthEntry: Codable, Sendable {
    public let token: String
    public let role: String
    public let scopes: [String]
    public let updatedAtMs: Int

    public init(token: String, role: String, scopes: [String], updatedAtMs: Int) {
        self.token = token
        self.role = role
        self.scopes = scopes
        self.updatedAtMs = updatedAtMs
    }
}

public protocol TokenStoring: Sendable {
    func loadToken(deviceId: String, role: String) -> DeviceAuthEntry?
    func storeToken(deviceId: String, role: String, token: String, scopes: [String]) -> DeviceAuthEntry
    func clearToken(deviceId: String, role: String)
}

public final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {
    private var tokens: [String: DeviceAuthEntry] = [:]

    public init() {}

    public func loadToken(deviceId: String, role: String) -> DeviceAuthEntry? {
        tokens[key(deviceId, role)]
    }

    public func storeToken(deviceId: String, role: String, token: String, scopes: [String]) -> DeviceAuthEntry {
        let entry = DeviceAuthEntry(
            token: token,
            role: role.trimmingCharacters(in: .whitespacesAndNewlines),
            scopes: Array(Set(scopes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })).sorted(),
            updatedAtMs: Int(Date().timeIntervalSince1970 * 1000)
        )
        tokens[key(deviceId, role)] = entry
        return entry
    }

    public func clearToken(deviceId: String, role: String) {
        tokens.removeValue(forKey: key(deviceId, role))
    }

    private func key(_ deviceId: String, _ role: String) -> String {
        "\(deviceId)|\(role)"
    }
}

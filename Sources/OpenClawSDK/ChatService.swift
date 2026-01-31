import Foundation
import OpenClawProtocol

public protocol GatewayRequesting: Sendable {
    func request(method: String, payload: Data) async throws -> Data
}

public struct ChatHistoryResponse: Codable, Sendable {
    public let sessionKey: String
    public let sessionId: String?
    public let messages: [AnyCodable]?
    public let thinkingLevel: String?

    public init(sessionKey: String, sessionId: String?, messages: [AnyCodable]?, thinkingLevel: String?) {
        self.sessionKey = sessionKey
        self.sessionId = sessionId
        self.messages = messages
        self.thinkingLevel = thinkingLevel
    }
}

public struct ChatSendResponse: Codable, Sendable {
    public let runId: String
    public let status: String

    public init(runId: String, status: String) {
        self.runId = runId
        self.status = status
    }
}

public struct ChatAbortResponse: Codable, Sendable {
    public let ok: Bool
    public let aborted: Bool
    public let runIds: [String]

    public init(ok: Bool, aborted: Bool, runIds: [String]) {
        self.ok = ok
        self.aborted = aborted
        self.runIds = runIds
    }
}

public struct ChatService: Sendable {
    private let gateway: GatewayRequesting
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(gateway: GatewayRequesting) {
        self.gateway = gateway
    }

    public func history(sessionKey: String) async throws -> ChatHistoryResponse {
        let params = ChatHistoryParams(sessionkey: sessionKey, limit: nil)
        let data = try encoder.encode(params)
        let res = try await gateway.request(method: "chat.history", payload: data)
        return try decoder.decode(ChatHistoryResponse.self, from: res)
    }

    public func send(
        sessionKey: String,
        message: String,
        thinking: String?,
        idempotencyKey: String
    ) async throws -> ChatSendResponse {
        let params = ChatSendParams(
            sessionkey: sessionKey,
            message: message,
            thinking: thinking,
            deliver: nil,
            attachments: nil,
            timeoutms: nil,
            idempotencykey: idempotencyKey
        )
        let data = try encoder.encode(params)
        let res = try await gateway.request(method: "chat.send", payload: data)
        return try decoder.decode(ChatSendResponse.self, from: res)
    }

    public func abort(sessionKey: String, runId: String?) async throws -> ChatAbortResponse {
        let params = ChatAbortParams(sessionkey: sessionKey, runid: runId)
        let data = try encoder.encode(params)
        let res = try await gateway.request(method: "chat.abort", payload: data)
        return try decoder.decode(ChatAbortResponse.self, from: res)
    }
}

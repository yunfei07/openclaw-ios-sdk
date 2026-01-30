import Foundation
import Testing
import OpenClawProtocol
@testable import OpenClawSDK

final class MockGateway: GatewayRequesting, @unchecked Sendable {
    var lastMethod: String?
    var lastPayload: Data?
    var response: Data = Data()

    func request(method: String, payload: Data) async throws -> Data {
        lastMethod = method
        lastPayload = payload
        return response
    }
}

struct ChatServiceTests {
    @Test func sendBuildsChatSendParams() async throws {
        let gateway = MockGateway()
        let service = ChatService(gateway: gateway)
        let res = ChatSendResponse(runId: "r1", status: "started")
        gateway.response = try JSONEncoder().encode(res)

        _ = try await service.send(
            sessionKey: "main",
            message: "hi",
            thinking: "low",
            idempotencyKey: "id"
        )

        #expect(gateway.lastMethod == "chat.send")
        let sent = try JSONDecoder().decode(ChatSendParams.self, from: gateway.lastPayload ?? Data())
        #expect(sent.sessionkey == "main")
        #expect(sent.message == "hi")
        #expect(sent.idempotencykey == "id")
    }
}

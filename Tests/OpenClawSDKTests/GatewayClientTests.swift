import Foundation
import Testing
import OpenClawProtocol
@testable import OpenClawSDK

final class MockWebSocket: WebSocketTasking, @unchecked Sendable {
    var state: URLSessionTask.State = .running
    var sent: [URLSessionWebSocketTask.Message] = []
    var inbox: [URLSessionWebSocketTask.Message] = []

    func resume() {}
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {}

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        sent.append(message)
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        return inbox.removeFirst()
    }

    func receive(completionHandler: @escaping @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        completionHandler(.success(inbox.removeFirst()))
    }
}

struct GatewayClientTests {
    @Test func connectsAndStoresDeviceToken() async throws {
        let socket = MockWebSocket()
        let tokenStore = InMemoryTokenStore()
        let identityStore = DeviceIdentityStore(
            rootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )

        let challenge = EventFrame(
            type: "event",
            event: "connect.challenge",
            payload: AnyCodable(["nonce": AnyCodable("n")]),
            seq: nil,
            stateversion: nil
        )

        let snapshot = Snapshot(
            presence: [],
            health: AnyCodable(["ok": true]),
            stateversion: StateVersion(presence: 0, health: 0),
            uptimems: 0,
            configpath: nil,
            statedir: nil,
            sessiondefaults: nil
        )

        let ok = HelloOk(
            type: "hello-ok",
            _protocol: GATEWAY_PROTOCOL_VERSION,
            server: [:],
            features: ["methods": AnyCodable([]), "events": AnyCodable([])],
            snapshot: snapshot,
            canvashosturl: nil,
            auth: [
                "deviceToken": AnyCodable("dtok"),
                "role": AnyCodable("operator"),
                "scopes": AnyCodable(["operator.read"]),
            ],
            policy: [
                "tickIntervalMs": AnyCodable(15000),
                "maxPayload": AnyCodable(1),
                "maxBufferedBytes": AnyCodable(1),
            ]
        )
        let okData = try JSONEncoder().encode(ok)
        let okJson = try JSONSerialization.jsonObject(with: okData) as? [String: Any] ?? [:]
        let res = ResponseFrame(type: "res", id: "req", ok: true, payload: AnyCodable(okJson), error: nil)

        let encoder = JSONEncoder()
        socket.inbox = [
            .data(try encoder.encode(challenge)),
            .data(try encoder.encode(res)),
        ]

        let client = GatewayClient(
            url: URL(string: "ws://example")!,
            sharedToken: "tok",
            tokenStore: tokenStore,
            identityStore: identityStore,
            webSocket: socket
        )

        try await client.connect()
        let stored = tokenStore.loadToken(deviceId: identityStore.loadOrCreate().deviceId, role: "operator")
        #expect(stored?.token == "dtok")
    }
}

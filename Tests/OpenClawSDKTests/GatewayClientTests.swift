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

    @Test func agentProfileGetSendsRequestAndDecodesResponse() async throws {
        let socket = MockWebSocket()
        let tokenStore = InMemoryTokenStore()
        let identityStore = DeviceIdentityStore(
            rootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )

        let payload = AgentProfileResult(
            agentid: "main",
            identity: ["name": AnyCodable("Nova")],
            usermarkdown: "# USER",
            identitymarkdown: "# IDENTITY",
            usertemplate: "# USER",
            identitytemplate: "# IDENTITY",
            hash: "hash-1"
        )
        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(payload)
        let payloadJson = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] ?? [:]
        let res = ResponseFrame(type: "res", id: "req-1", ok: true, payload: AnyCodable(payloadJson), error: nil)
        socket.inbox = [.data(try encoder.encode(res))]

        let client = GatewayClient(
            url: URL(string: "ws://example")!,
            sharedToken: nil,
            tokenStore: tokenStore,
            identityStore: identityStore,
            webSocket: socket
        )

        let result = try await client.agentProfileGet(agentId: "main")
        #expect(result.agentid == "main")
        #expect(result.hash == "hash-1")

        guard case let .data(data) = socket.sent.first else {
            Issue.record("missing request frame")
            return
        }
        let req = try JSONDecoder().decode(RequestFrame.self, from: data)
        #expect(req.method == "agent.profile.get")
        let params = req.params?.value as? [String: AnyCodable]
        #expect(params?["agentId"]?.value as? String == "main")
    }

    @Test func agentProfileSetSendsRequestAndDecodesResponse() async throws {
        let socket = MockWebSocket()
        let tokenStore = InMemoryTokenStore()
        let identityStore = DeviceIdentityStore(
            rootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )

        let payload = AgentProfileResult(
            agentid: "main",
            identity: ["name": AnyCodable("Nova")],
            usermarkdown: "# USER",
            identitymarkdown: "# IDENTITY",
            usertemplate: nil,
            identitytemplate: nil,
            hash: "hash-2"
        )
        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(payload)
        let payloadJson = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] ?? [:]
        let res = ResponseFrame(type: "res", id: "req-2", ok: true, payload: AnyCodable(payloadJson), error: nil)
        socket.inbox = [.data(try encoder.encode(res))]

        let client = GatewayClient(
            url: URL(string: "ws://example")!,
            sharedToken: nil,
            tokenStore: tokenStore,
            identityStore: identityStore,
            webSocket: socket
        )

        let result = try await client.agentProfileSet(
            agentId: "main",
            identity: ["name": AnyCodable("Nova")],
            userMarkdown: "# USER",
            identityMarkdown: "# IDENTITY",
            baseHash: "hash-1"
        )
        #expect(result.hash == "hash-2")

        guard case let .data(data) = socket.sent.first else {
            Issue.record("missing request frame")
            return
        }
        let req = try JSONDecoder().decode(RequestFrame.self, from: data)
        #expect(req.method == "agent.profile.set")
        let params = req.params?.value as? [String: AnyCodable]
        #expect(params?["agentId"]?.value as? String == "main")
        #expect(params?["baseHash"]?.value as? String == "hash-1")
        let identity = params?["identity"]?.value as? [String: AnyCodable]
        #expect(identity?["name"]?.value as? String == "Nova")
    }
}

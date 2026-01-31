# OpenClawSDK (iOS)

OpenClaw 的 iOS SwiftPM SDK：提供协议模型与最小网关客户端能力，便于在 iOS 端接入 OpenClaw Gateway。

## 适用环境
- iOS 18+
- Xcode 16 / Swift 6.2
- macOS 15+（开发与测试）

## 安装（SwiftPM）
### Package.swift
```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YourApp",
    dependencies: [
        .package(url: "https://github.com/yunfei07/openclaw-ios-sdk.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: [
                .product(name: "OpenClawSDK", package: "openclaw-ios-sdk"),
                .product(name: "OpenClawProtocol", package: "openclaw-ios-sdk"),
            ]
        ),
    ]
)
```

### Xcode
1. `File` → `Add Packages...`
2. 输入仓库地址 `https://github.com/yunfei07/openclaw-ios-sdk.git`
3. 选择 `main` 分支，添加 `OpenClawSDK`（需要协议模型时同时选 `OpenClawProtocol`）

## 同步协议模型
在 openclaw 仓库根目录执行：
```bash
pnpm protocol:gen:swift
OPENCLAW_IOS_SDK_DIR=../openclaw-ios-sdk pnpm ios:sdk:sync
```

## 使用说明（完整流程）
下面示例展示：建立 WebSocket 连接 → connect 握手 → chat.history / chat.send / chat.abort。
示例为最小实现，未包含超时、重连、多路复用与事件流处理。

```swift
import Foundation
import OpenClawSDK
import OpenClawProtocol

final class GatewayRPC: GatewayRequesting, @unchecked Sendable {
    private let socket: URLSessionWebSocketTask
    private let tokenStore: TokenStoring
    private let identityStore: DeviceIdentityStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(url: URL, tokenStore: TokenStoring, identityStore: DeviceIdentityStore) {
        self.tokenStore = tokenStore
        self.identityStore = identityStore
        let task = URLSession(configuration: .default).webSocketTask(with: url)
        task.maximumMessageSize = 16 * 1024 * 1024
        self.socket = task
        task.resume()
    }

    func connect(sharedToken: String?) async throws {
        let identity = identityStore.loadOrCreate()
        let challengeNonce = await receiveChallenge()

        let stored = tokenStore.loadToken(deviceId: identity.deviceId, role: "operator")?.token
        let token = stored ?? sharedToken

        let params = ConnectPayloadBuilder.build(
            clientId: "openclaw-ios",
            clientMode: "ui",
            displayName: "iOS",
            role: "operator",
            scopes: ["operator.read", "operator.write"],
            token: token,
            challengeNonce: challengeNonce,
            identity: identity
        )

        let paramsData = try encoder.encode(params)
        let paramsJson = try JSONSerialization.jsonObject(with: paramsData) as? [String: Any] ?? [:]
        let frame = RequestFrame(type: "req", id: "connect", method: "connect", params: AnyCodable(paramsJson))
        try await socket.send(.data(try encoder.encode(frame)))

        let resData = decodeMessageData(try await socket.receive())
        let resFrame = try decoder.decode(GatewayFrame.self, from: resData)
        guard case let .res(res) = resFrame, res.ok == true, let payload = res.payload else {
            throw NSError(domain: "Gateway", code: 1, userInfo: [NSLocalizedDescriptionKey: "connect failed"])
        }

        let okData = try encoder.encode(payload)
        let ok = try decoder.decode(HelloOk.self, from: okData)
        if let auth = ok.auth, let tokenValue = auth["deviceToken"]?.value as? String {
            let role = auth["role"]?.value as? String ?? "operator"
            let scopes = (auth["scopes"]?.value as? [AnyCodable])?.compactMap { $0.value as? String } ?? []
            _ = tokenStore.storeToken(deviceId: identity.deviceId, role: role, token: tokenValue, scopes: scopes)
        }
    }

    func request(method: String, payload: Data) async throws -> Data {
        let id = UUID().uuidString
        let paramsJson = try JSONSerialization.jsonObject(with: payload) as? [String: Any] ?? [:]
        let frame = RequestFrame(type: "req", id: id, method: method, params: AnyCodable(paramsJson))
        try await socket.send(.data(try encoder.encode(frame)))

        while true {
            let resData = decodeMessageData(try await socket.receive())
            let frame = try decoder.decode(GatewayFrame.self, from: resData)
            if case let .res(res) = frame, res.id == id {
                guard res.ok, let payload = res.payload else {
                    throw NSError(domain: "Gateway", code: 1, userInfo: [NSLocalizedDescriptionKey: "request failed"])
                }
                return try encoder.encode(payload)
            }
        }
    }

    private func receiveChallenge() async -> String? {
        do {
            let msg = try await socket.receive()
            let data = decodeMessageData(msg)
            let frame = try decoder.decode(GatewayFrame.self, from: data)
            if case let .event(evt) = frame, evt.event == "connect.challenge" {
                if let payload = evt.payload?.value as? [String: AnyCodable],
                   let nonce = payload["nonce"]?.value as? String {
                    return nonce
                }
            }
        } catch {}
        return nil
    }

    private func decodeMessageData(_ msg: URLSessionWebSocketTask.Message) -> Data {
        switch msg {
        case let .data(data): return data
        case let .string(text): return Data(text.utf8)
        @unknown default: return Data()
        }
    }
}

let url = URL(string: "ws://127.0.0.1:18789")!
let tokenStore = InMemoryTokenStore()
let identityStore = DeviceIdentityStore()
let gateway = GatewayRPC(url: url, tokenStore: tokenStore, identityStore: identityStore)
try await gateway.connect(sharedToken: "<gateway-token>")

let chat = ChatService(gateway: gateway)
let history = try await chat.history(sessionKey: "main")
let send = try await chat.send(
    sessionKey: "main",
    message: "你好",
    thinking: "low",
    idempotencyKey: UUID().uuidString
)
_ = try await chat.abort(sessionKey: "main", runId: send.runId)
_ = history
```

## 注意事项
- 示例为最小实现，生产环境需要补充超时、重连、事件流、多路复用等能力。
- `DeviceIdentityStore` 会持久化设备身份到应用支持目录；如需稳定设备身份，请勿清理该目录。
- `InMemoryTokenStore` 仅适用于开发；生产环境建议用 Keychain 实现 `TokenStoring`。

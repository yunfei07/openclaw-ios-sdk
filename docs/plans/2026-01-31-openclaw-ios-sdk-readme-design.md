# OpenClaw iOS SDK README Design (2026-01-31)

## 目标
在 main 分支补齐中文 README，给出完整使用流程：SwiftPM 安装、协议模型同步、网关连接、chat.history / chat.send / chat.abort 调用示例。README 需面向首次接入用户，提供可直接拷贝的 Package.swift 与最小可运行的代码片段。

## 结构
1. 标题与简介：说明这是 OpenClaw iOS SwiftPM SDK。
2. 适用环境：iOS 18+，Xcode 16 / Swift 6.2，macOS 15+ 用于开发与测试。
3. 安装（SwiftPM）：
   - Package.swift 依赖片段（包含 OpenClawSDK 与 OpenClawProtocol）。
   - Xcode 添加包的操作步骤。
4. 同步协议模型：在 openclaw 仓库根目录执行 `pnpm protocol:gen:swift` 与 `pnpm ios:sdk:sync`。
5. 使用说明（完整流程）：提供一个最小 GatewayRPC 示例，完成 connect 握手与 request 响应循环，并展示 ChatService 的 history/send/abort 使用方式。
6. 注意事项：声明示例为最小实现，生产环境需补充超时、重连、事件流、多路复用；说明 DeviceIdentityStore 的持久化位置与 TokenStoring 的安全性要求。

## 非目标
- 不在 README 中引入完整事件流或多连接管理。
- 不在本次文档里新增 SDK 代码或 API。

## 设计取舍
为了保证示例可运行，README 中提供一个最小 GatewayRPC（实现 GatewayRequesting），并在同一连接上完成 connect 与 chat 请求；同时明确该实现仅用于演示，生产需自行完善。

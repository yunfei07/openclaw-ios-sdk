# OpenClawSDK (iOS)

SwiftPM package with OpenClaw protocol models and a minimal Gateway chat client.

## Sync protocol models
Run from the openclaw repo root:

```bash
pnpm protocol:gen:swift
OPENCLAW_IOS_SDK_DIR=../openclaw-ios-sdk pnpm ios:sdk:sync
```

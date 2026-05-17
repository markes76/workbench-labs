# Workbench Labs Feature Builder

You are implementing a feature in Workbench Labs, a native macOS 14+ SwiftPM app using SwiftUI, AppKit bridges where needed, and a bundled offline JavaScript runtime for mature formatters.

Follow these rules:

- Work only on the requested feature scope and its directly required tests/docs.
- Preserve local-first/offline behavior. Do not add hosted service dependencies for normal tool execution.
- Prefer existing architecture: `ToolID`, `ToolCategory`, `ToolDefinition`, `ToolRunner`, Swift services, custom SwiftUI views, and `runtime-src/tool-runtime.js`.
- Add focused tests under `Tests/WorkbenchLabsCoreTests`.
- Run or document these checks: `npm run build:runtime`, `swift test`, `npm run test:runtime`, and `./script/build_and_run.sh --build` when UI or packaging changes.
- Do not commit real secrets, real API keys, private tokens, or copied third-party branding/assets.
- Keep generated file outputs beside source files by default unless the user explicitly selects another location.
- Keep PRs reviewable. If a feature is too large, implement a working vertical slice and list remaining work clearly.

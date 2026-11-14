# iOS runtime setup

MeshMind uses a local Swift package at `ios/MeshMindInference` to expose the
llama.cpp iOS XCFramework to the Flutter runner. The package is pinned to the
`b5046` XCFramework release and keeps the app's minimum iOS target at 14.

On macOS with Xcode:

```bash
flutter pub get
flutter build ios --release --no-codesign
```

The first Xcode build downloads the XCFramework through Swift Package Manager.
The app does not ship a model. On the iPhone, use Model Bay to choose a GGUF
file from Files; MeshMind copies it into app-support storage before invoking
llama.cpp. The native method channel returns the generated text to the Flutter
router, while the UI continues to show an explicit fallback state when the
runtime or model is unavailable.

The same Flutter UI can act as a coordinator for older LAN workers. A desktop
worker with `llama-cli` installed can import its own GGUF file and serve
requests over the MeshMind WebSocket mesh.

The Linux workstation cannot run `xcodebuild`, so the repository's macOS CI job
is the authoritative iOS compile check.

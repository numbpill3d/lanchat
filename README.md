# MeshMind

Private local AI assembled from the devices you already own. No account, no
cloud round-trip, and no central server: the iPhone coordinates a mesh of
nearby phones, tablets, laptops, and single-board computers over mDNS and
WebSockets.

MeshMind is a Flutter app for **Linux, macOS, Windows, Android, and iOS**.
The iPhone is the control surface; workers contribute local models and compute.

## Screenshots

The current UI is the pale-metal control-panel dashboard in
`lib/screens/mesh_screen.dart`.

## Highlights

- **mDNS peer discovery** via `_meshmind._tcp` — nearby workers appear automatically.
- **Capability handshake** — nodes advertise platform, memory, models, battery,
  thermal state, and supported features.
- **Targeted streaming inference** — the coordinator routes a prompt to the
  best available worker and falls back locally if it disappears.
- **Model Bay** — import GGUF files from Files or a LAN
  share; MeshMind copies them into its local app-support model directory.
- **Legacy-worker support** — a laptop with `llama-cli` installed can run a
  real GGUF model without requiring the iPhone to be the strongest device.
- **Private by design** — the prototype stays on the LAN and keeps no cloud
  account or server-side history.

## Quick start

### Install on your platform

| Platform | Where to get it |
| --- | --- |
| **Linux (AUR)** | `yay -S lanchat-bin` (uses `packaging/aur/PKGBUILD`) |
| **Linux (tarball)** | Download `lanchat-linux-x64.tar.gz` from the [latest release](https://github.com/numbpill3d/lanchat/releases/latest), extract, and run `./lanchat` |
| **macOS** | Download `lanchat-macos.dmg` (or `.zip`) from the [latest release](https://github.com/numbpill3d/lanchat/releases/latest) |
| **Windows** | Download `lanchat-windows-x64.zip` or `*.msix` from the [latest release](https://github.com/numbpill3d/lanchat/releases/latest) |
| **Android** | Download the per-ABI APK from the [latest release](https://github.com/numbpill3d/lanchat/releases/latest). `minSdk` is 21. |

On Linux you also need `avahi` and `gtk3` available on the system for mDNS and
the GTK application to work. To make a Linux/macOS/Windows laptop a real GGUF
worker, install `llama-cli` from llama.cpp, launch MeshMind, and import the
model in Model Bay. The adapter streams the local process output and never
sends the model to a cloud service.

### Build from source

```bash
flutter --version        # stable channel, 3.32 or newer
flutter pub get
flutter run              # desktop, Android, or iOS
flutter build linux      # builds ./build/linux/x64/release/bundle/
```

To produce a packaged release locally:

```bash
flutter build linux --release
flutter build macos --release
flutter build windows --release
flutter build apk --release --split-per-abi
```

For the native iOS GGUF runtime and model lifecycle, see
[`docs/IOS_RUNTIME.md`](docs/IOS_RUNTIME.md).

## How it works

When you launch MeshMind, your client:

1. Picks a free port in `5700-5800` and starts a `shelf`-based WebSocket
   server bound to all IPv4 interfaces.
2. Broadcasts an mDNS service of type `_meshmind._tcp` with your nickname and
   device id in the attributes.
3. Discovers other `_meshmind._tcp` services, resolves their host/port, and
   opens an outbound WebSocket to each.
4. Exchanges node capabilities and targets inference envelopes at the selected
   worker. Each message is deduped by `id` so a payload can hop through the
   mesh without being duplicated.

Closing the app stops the server, shuts down mDNS, and broadcasts a
`leave` message so the other peers can drop you from their peer list.

### Network requirements

- mDNS / Bonjour / Avahi must be available on the network. On Linux this
  usually means `avahi-daemon` is running.
- All peers must be on the same subnet. Routers typically block multicast
  mDNS and inbound WebSocket traffic between subnets.
- WebSocket traffic is on the chosen port in `5700-5800`. Make sure your
  host firewall allows inbound TCP on this range if you want other peers to
  reach you.

## Configuration

MeshMind is intentionally configuration-light. The main choices are:

- The local node nickname.
- The model file imported into Model Bay, if this device should also serve as
  a worker.
- The bundled app icon is `assets/icon/icon.png`. Replace it and rerun
  `dart run flutter_launcher_icons` to regenerate the platform icons.

## Project layout

```
lib/
  main.dart              # Window setup + theme + app shell
  models/
    message.dart         # Mesh message envelope and message types
    inference_envelope.dart
    node_capability.dart # Worker capability handshake
    local_model.dart     # Imported model metadata and executable path
  services/
    chat_service.dart    # Server, discovery, capability and mesh transport
    inference_service.dart # Routing, streaming, native and llama-cli adapters
  screens/
    mesh_screen.dart     # Pool, nodes, prompt router and Model Bay
test/
  inference_service_test.dart
  node_capability_test.dart
.github/workflows/
  ci.yml                 # analyze + test + Linux + Android on every push
  release.yml            # Linux/Windows/macOS/Android + signed GitHub release
android/                 # Gradle (AGP 8.7.3, Kotlin 2.1.21, compileSdk 35)
linux/, macos/, windows/  # Native scaffolding
assets/icon/             # Source icon
packaging/aur/PKGBUILD   # AUR packaging helper
```

## Development

Run the test suite:

```bash
flutter pub get
flutter test
```

Run the linter:

```bash
flutter analyze
```

### Code signing for release artifacts

The release workflow can sign Android APKs and Windows MSIX packages if
you provide the following repository secrets:

- `LANCHAT_KEYSTORE_BASE64` — base64-encoded Android keystore (`.jks`).
- `LANCHAT_KEYSTORE_PASSWORD`, `LANCHAT_KEY_ALIAS`, `LANCHAT_KEY_PASSWORD`
  — keystore credentials.
- `MSIX_CERT_BASE64`, `MSIX_CERT_PASSWORD` — base64-encoded `.pfx` and its
  password for Windows MSIX signing.

If these are not set, the build will still succeed but the artifacts will
be unsigned (Android uses the debug keystore, MSIX is built without a
publisher certificate).

## Releases

Releases are cut by pushing a `v*` tag:

```bash
git tag v1.1.0
git push origin v1.1.0
```

The `Release` workflow builds Linux, Windows, macOS, and Android artifacts
and publishes a draft GitHub release with auto-generated notes.

## License

MIT — see [LICENSE](LICENSE).

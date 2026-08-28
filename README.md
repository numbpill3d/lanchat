# LanChat

Zero-account local-network chat for people on the same Wi-Fi. No signup, no
internet, no central server — every peer runs its own WebSocket and the
desktop and mobile clients find each other through mDNS.

LanChat is a Flutter app for **Linux, macOS, Windows, Android, and iOS**.
Messages and images stay on the local network and disappear when you close
the app.

![LanChat screenshot](docs/screenshot.png)

## Highlights

- **mDNS peer discovery** via `bonsoir` — every peer is auto-detected on the
  local network.
- **WebSocket mesh** with `shelf` — each peer runs a tiny WebSocket server on
  a free port in `5700-5800` and connects to every other peer it discovers.
- **Ephemeral** — no history, no cloud, no accounts. The chat list is gone
  when you close the window.
- **Text and images** — drag a PNG/JPG/GIF into the picker and the bytes go
  base64-encoded to every connected peer.
- **Dark, focused UI** — fixed black/red surface, mono-styled typography, no
  distractions.

## Quick start

### Install on your platform

| Platform | Where to get it |
| --- | --- |
| **Linux (AUR)** | `yay -S lanchat-bin` (uses `packaging/aur/PKGBUILD`) |
| **Linux (tarball)** | Download `lanchat-linux-x64.tar.gz` from the [latest release](https://github.com/numbpill3d/lanchat/releases/latest), extract, and run `./lanchat` |
| **macOS** | Download `lanchat-macos.dmg` (or `.zip`) from the [latest release](https://github.com/numbpill3d/lanchat/releases/latest) |
| **Windows** | Download `lanchat-windows-x64.zip` or `*.msix` from the [latest release](https://github.com/numbpill3d/lanchat/releases/latest) |
| **Android** | Download the per-ABI APK from the [latest release](https://github.com/numbpill3d/lanchat/releases/latest). `minSdk` is 21. |

On Linux you also need `avahi` and `gtk3` available on the system for
mDNS and the GTK application to work.

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

## How it works

When you launch LanChat and pick a nickname, your client:

1. Picks a free port in `5700-5800` and starts a `shelf`-based WebSocket
   server bound to all IPv4 interfaces.
2. Broadcasts an mDNS service of type `_lanchat._tcp` with your nickname and
   device id in the attributes.
3. Discovers other `_lanchat._tcp` services, resolves their host/port, and
   opens an outbound WebSocket to each.
4. Echoes every text or image message to every connected peer (server- and
   client-side channels). Each message is deduped by `id` so the same
   payload can hop through the mesh without being duplicated.

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

LanChat is intentionally configuration-free. The only choices are:

- The auto-generated nickname on the launch screen. You can edit it before
  joining.
- The bundled app icon is `assets/icon/icon.png`. Replace it and rerun
  `dart run flutter_launcher_icons` to regenerate the platform icons.

## Project layout

```
lib/
  main.dart              # Window setup + theme + app shell
  models/
    message.dart         # Message + MessageType (text/image/join/leave)
    peer.dart            # Discovered peer metadata
  services/
    chat_service.dart    # Server, discovery, broadcast, dedupe
  screens/
    nickname_screen.dart # Launch screen
    chat_screen.dart     # Message list, peer sheet, input bar
  widgets/
    message_bubble.dart  # Bubble + image content
test/
  widget_test.dart       # Message serialization and round-trip
  peer_test.dart         # Peer value semantics
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

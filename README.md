# lanchat

Zero-account local network chat for people on the same Wi-Fi.

Built with Flutter. Uses mDNS (Bonjour/Avahi) for peer discovery and WebSockets for messaging.

## What it does

- No signup, no internet, no server — just open and talk
- Automatically finds everyone on the same Wi-Fi via mDNS
- Supports text messages and image sharing
- Cross-platform: Android, iOS, Linux, macOS, Windows

## What's Improved

- **Message persistence** — chat history survives app restarts (SQLite-backed).
- **Auto-reconnect** — re-discovers peers automatically when a connection drops.
- **Sorted peers** — online list is alphabetical by nickname.
- **Memory safety** — processed ID cache is capped at 10,000 entries to prevent unbounded growth.

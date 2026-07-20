# HK Drop ⚡

> **Effortless, Offline, Privacy-First Device Companion for Phones and Laptops.**

HK Drop is an offline cross-device sharing application designed to provide seamless file and text transfers between mobile devices (Android / iOS) and laptops (Windows / macOS / Linux) — with **zero cloud dependencies, zero user accounts, and max local transfer speeds**.

---

## 🌟 Key Features

* **Instant File Transfer**: Share photos, videos, documents, or any file up to gigabytes in size over local Wi-Fi / hotspot.
* **Instant Text & Clipboard Sharing**: Pass links, notes, code snippets, and OTPs between phone and laptop instantly.
* **1-Time QR / PIN Pairing**: Mutual trust established once using Ed25519 signatures; nearby trusted devices auto-connect.
* **Zero Cloud & Absolute Privacy**: Communication never leaves your local network. No tracking, no servers, no accounts.
* **High-Speed Chunk Streaming**: Resumable local HTTP/TCP streaming with real-time speed indicators (MB/s) and SHA-256 integrity checks.
* **Platform Integrations**:
  * **Mobile**: Native Android Share Sheet target filter & system notifications.
  * **Desktop**: Drag-and-drop zone, system tray menu, and floating toast popups.

---

## 🛠️ Technology Stack & Architecture

* **UI Framework**: Flutter (Dart) with Dark Glassmorphism design system.
* **Discovery Protocol**: mDNS / Zeroconf (`bonsoir`) over local Wi-Fi with subnet ping fallback.
* **Transport Engine**: Embedded HTTP streaming server (`shelf`) listening on local TCP port `45789`.
* **Security & Cryptography**: Dynamic Ed25519 signature exchange, AES-256-GCM payload encryption, hardware-backed key vault (`flutter_secure_storage`).

---

## 🤖 Fully Automated GitHub Actions CI/CD Build

You **do not need to install local development dependencies** or set up Flutter locally to produce release builds. The repository includes an automated GitHub Actions workflow (`.github/workflows/build_app.yml`) that automatically generates:

1. **Android**: Release APK & AAB bundles (`.apk`)
2. **Windows**: Standalone Windows Executable & Release ZIP (`.exe` / `.zip`)

Release build artifacts are automatically attached to every GitHub commit and push!

---

## 📁 Repository Structure

```
.
├── .github/workflows/build_app.yml   # Automated multi-platform build workflow
├── android/                           # Android manifest, permissions & build config
├── lib/
│   ├── main.dart                      # Application entrypoint & initializers
│   ├── core/                          # Theme, colors, constants, glassmorphic styles
│   ├── security/                      # CryptoService, TrustStore, DeviceIdentity, Pairing
│   ├── network/                       # DiscoveryService (mDNS), TransferServer, TransferClient
│   ├── services/                      # TextSharing, Notification, Platform Tray & Intents
│   └── ui/                            # RadarView, DeviceCard, PairingScreen, HomeScreen
├── test/                              # Automated unit & integration test suites
├── pubspec.yaml                       # Dependencies configuration
└── README.md                          # Project guide & documentation
```

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClashX.Meta is a macOS menu bar proxy client based on [Clash Meta (mihomo)](https://github.com/MetaCubeX/Clash.Meta). It provides a native macOS interface for the Clash proxy core with features like Tun mode support.

## Build & Run

### Requirements
- Xcode
- Go (for building the core, though dependency script fetches pre-built binaries)
- Python 3 (for helper scripts)

### Setup
```bash
# Download mihomo core, geo databases, and zashboard dashboard
bash install_dependency.sh
```

This script:
- Downloads the latest mihomo (Clash Meta) arm64 binary
- Updates the MD5 hash in `ClashX/AppDelegate.swift` (line 19)
- Downloads geo data (country.mmdb, geosite.dat, geoip.dat)
- Downloads the zashboard web dashboard

### Build
Open `ClashX.xcodeproj` in Xcode and build/run. The app name is "ClashX Meta".

### Linting
```bash
swiftlint
```
Configuration is in `.swiftlint.yml`. The `ClashX/Vendor` directory is excluded.

## Architecture

### Two-Process Model
The app uses a privileged helper architecture:

1. **ClashX (Main App)** - Menu bar application with UI
2. **ProxyConfigHelper** - Privileged helper daemon that runs as root for:
   - Changing system-wide proxy settings
   - Managing the Tun interface
   - Running the mihomo process

Communication between them uses `NSXPCConnection`.

### Key Components

**Main App (`/ClashX/`)**
- `AppDelegate.swift` - Entry point, menu bar management, lifecycle
- `General/Managers/` - Singleton managers:
  - `ConfigManager.swift` - Configuration state
  - `SystemProxyManager.swift` - macOS system proxy settings
  - `PrivilegedHelperManager.swift` - XPC communication with helper
  - `RemoteConfigManager.swift` - Remote config subscriptions
- `Dashboard/` - SwiftUI-based dashboard UI
- `ViewControllers/` - AppKit view controllers

**Privileged Helper (`/ProxyConfigHelper/`)**
- `main.swift` - Helper entry point
- `MetaTask.swift` - Manages mihomo process lifecycle
- `ProxyConfigRemoteProcessProtocol.swift` - XPC protocol definitions

### Dependencies (via SPM)
- **RxSwift/RxCocoa** - Reactive bindings for UI
- **Alamofire** - HTTP networking
- **SwiftyJSON** - JSON parsing
- **Yams** - YAML parsing for Clash configs
- **Starscream** - WebSocket for Clash API
- **Sparkle** - Auto-updates (currently hidden)
- **KeyboardShortcuts** - Global hotkeys

### Config Location
Default configuration directory: `~/.config/clash`

### Core Binary
The mihomo binary is bundled as `com.metacubex.ClashX.ProxyConfigHelper.meta` in Resources. The MD5 is verified at runtime against the constant in `AppDelegate.swift`.

## AppleScript Support
The app exposes AppleScript commands:
- `toggleProxy` - Toggle system proxy
- `proxyMode 'global'|'direct'|'rule'` - Change proxy mode
- `TunMode` - Toggle Tun mode

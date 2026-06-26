# Ciber_Radar v2.0

Android security audit toolkit for WiFi scanning, BLE discovery, LAN host enumeration, cellular tower monitoring, EMF sensing, and PDF report generation.

Built with **Dart/Flutter** for mobile-first security operations.

## What's new in v2.0

### Critical bug fixes
- **WiFi security classification fixed**: `isOpen` no longer false-positives on WPA3 networks (ESS check removed, now checks absence of all security protocols)
- **5G NR real support**: `MainActivity.kt` now uses `CellInfoNr` with real `CellSignalStrengthNr` data (no more hardcoded -65 dBm)
- **Report uses shared scanner data**: PDF report now uses the same `ScannerService` instance as the UI -- no more disconnected rescans
- **Dashboard performance fixed**: `AnimatedBuilder` replaces `setState` in animation listener (was rebuilding 60fps)
- **WiFi scan throttle works**: Throttle now returns `notYet` instead of silently proceeding

### Improvements
- GPS now requests fresh position (was using stale `getLastKnownPosition`)
- `ScannerService.dispose()` properly cancels stream subscriptions
- WiFi entity has `securityType`, `channel`, `band`, `isVulnerable`, `==`/`hashCode`
- Report PDF has summary section with vulnerability count
- Magnetic field threshold raised to 100 uT (was 60, causing false positives)
- Typo fixed: "ESCANENDO" -> "ESCANEANDO"
- Cleaned up debug files (errors.txt, analysis files)

## Features

- **WiFi Scanner** -- Identify vulnerable networks (WEP, open, WPS detection)
- **Bluetooth Scanner** -- BLE device discovery with OUI manufacturer lookup
- **LAN Scanner** -- TCP port scan + mDNS/NSD discovery
- **Cellular Monitor** -- Tower info with 5G NR, 4G LTE, 3G WCDMA, 2G GSM and downgrade attack detection
- **EMF Sensor** -- Magnetometer for hidden device detection
- **PDF Report** -- Comprehensive audit report with all findings

## Tech Stack

- **Dart** + **Flutter** -- Cross-platform mobile framework
- **Android** first, expandable to iOS
- **Native Kotlin** for cellular tower info (MethodChannel + EventChannel)

## Installation

```bash
# Clone
git clone https://github.com/PoisonXploIT/Ciber_Radar.git

# Install dependencies
flutter pub get

# Run
flutter run
```

## Disclaimer

This tool is intended for **authorized security auditing only**. Always obtain proper permission before scanning or testing any network or system you do not own.

## License

MIT License -- see [LICENSE](LICENSE) for details.
# Ciber_Radar v2.1

Android security audit toolkit for WiFi scanning, BLE discovery, LAN host enumeration with port detection, cellular tower monitoring with IMSI catcher detection, EMF sensing, and JSON/CSV/KML/PDF report generation.

Built with **Dart/Flutter** for mobile-first security operations. **No root required.**

## What's new in v2.1

### New security features

**1. LAN port scanning with risk assessment**
- Each discovered host now shows which ports are open
- Common ports scanned: 80, 443, 22, 53, 445, 23, 8080, 8008, 8009, 9100, 5000, 1900, 8081, 8888
- Telnet (23) and SMB (445) flagged as HIGH risk
- SSH + Web combination flagged as MEDIUM
- ExpansionTile per host showing port chips with service names
- NSD services resolved (previously commented out)

**2. Real IMSI catcher detection**
- **Downgrade attack**: detects 4G/5G -> 2G transition (classic IMSI catcher)
- **Cell jump**: rapid cell ID change with strong signal (<30s, >-80 dBm)
- **Strong 2G signal**: abnormally strong 2G signal (>-50 dBm) = possible fake tower
- **Jamming indicator**: neighbor cells disappear + signal drop >20 dBm
- ThreatLevel.CRITICAL level added (purple alert)
- Alert history with timestamps shown in UI
- Alert cards with color-coded severity

**3. JSON export compatible with sec-dashboard**
- Comprehensive JSON report with all scan data
- Format: `source`, `version`, `exported_at`, `summary`, `events[]`
- Events include: wifi_scan, ble_scan, lan_host, cell_scan, emf_reading
- Share sheet integration (share via WhatsApp, email, etc.)
- Compatible with sec-dashboard ingestion and any SIEM

### v2.0 fixes (still included)
- WiFi security classification fixed (no more ESS false positive)
- 5G NR real data (no more hardcoded values)
- Report uses shared scanner data
- Dashboard AnimatedBuilder (no more 60fps rebuild)
- WiFi scan throttle works
- GPS requests fresh position

## Features

- **WiFi Scanner** -- Security classification (OPEN/WEP/WPA/WPA2/WPA3), channel, band, OUI manufacturer
- **Bluetooth Scanner** -- BLE device discovery with manufacturer lookup and random MAC detection
- **LAN Scanner** -- TCP port scan (15 ports) + mDNS/NSD with port-level detail and risk assessment
- **Cellular Monitor** -- 5G/4G/3G/2G tower info with real IMSI catcher detection (downgrade, cell jump, jamming)
- **EMF Sensor** -- Magnetometer for hidden device detection
- **Reports** -- PDF (comprehensive audit), CSV (WiFi+BLE), KML (heatmap), JSON (sec-dashboard compatible)

## Tech Stack

- **Dart** + **Flutter** -- Cross-platform mobile framework
- **Android** first (no root required)
- **Native Kotlin** for cellular tower info (MethodChannel + EventChannel + TelephonyCallback)

## Installation

```bash
git clone https://github.com/PoisonXploIT/Ciber_Radar.git
cd Ciber_Radar
flutter pub get
flutter run
```

## Disclaimer

This tool is intended for **authorized security auditing only**. Always obtain proper permission before scanning or testing any network or system you do not own.

## License

MIT License -- see [LICENSE](LICENSE) for details.
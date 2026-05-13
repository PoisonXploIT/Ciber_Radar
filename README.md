# Ciber_Radar

Android security audit toolkit for WiFi scanning, port scanning, OSINT reconnaissance and vulnerability assessment in the field.

Built with **Dart/Flutter** for mobile-first security operations.

## Features

- **WiFi Scanner** -- Identify vulnerable networks in your vicinity
- **Port Scanner** -- Detect open ports and services on target hosts
- **OSINT Reconnaissance** -- Gather intelligence from public sources
- **Vulnerability Assessment** -- Quick field-level security checks
- **Intuitive mobile UI** -- Designed for on-the-go security professionals

## Quick Start Missions

### Mision 1: "La Busqueda del Vecino Inseguro" (WiFi)

**Objetivo:** Identificar redes vulnerables en tu entorno.

1. Abre la pestana WiFi Scanner
2. Escanea redes disponibles
3. Analiza los resultados buscando WEP, WPS habilitado o senales debiles
4. Documenta hallazgos

### Mision 2: "El Puerto Abierto" (Port Scan)

**Objetivo:** Detectar servicios expuestos en un objetivo.

1. Introduce la IP o hostname del objetivo
2. Selecciona rango de puertos (top 100, top 1000 o personalizado)
3. Ejecuta el escaneo
4. Revisa servicios y versiones detectadas

### Mision 3: "Huella Digital" (OSINT)

**Objetivo:** Recopilar informacion publica sobre un dominio.

1. Introduce el dominio objetivo
2. Ejecuta busqueda OSINT
3. Analiza resultados: DNS, subdominios, emails, leaks
4. Genera reporte

## Tech Stack

- **Dart** + **Flutter** -- Cross-platform mobile framework
- **Android** first, expandable to iOS

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

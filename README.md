# MacPulse

MacPulse ist eine native macOS-App fuer System- und Netzwerkmonitoring. Sie zeigt CPU, Speicher, Laufwerke, Batterie, GPU-Heuristiken, Prozesse, Netzwerkinterfaces, Verbindungen, lokale Geraete, Packet Capture, Portscan und mehrere Visualisierungen.

Der aktuelle Stand ist eine lauffaehige SwiftUI-App, aber noch kein fertig gehaertetes Release-Produkt. Die technische Roadmap steht in `ROADMAP.md`.

## Voraussetzungen

- macOS 14 oder neuer
- Xcode mit macOS SDK
- Apple Silicon Build wurde verifiziert
- System-libpcap, bereitgestellt durch macOS

## Build

```sh
xcodebuild -project MacPulse.xcodeproj -scheme MacPulse -configuration Debug -derivedDataPath /tmp/MacPulseDerivedData build
```

Erfolgreicher Build erzeugt:

```text
/tmp/MacPulseDerivedData/Build/Products/Debug/MacPulse.app
```

## Projektstruktur

```text
MacPulse/
  MacPulseApp.swift
  ContentView.swift
  Models/
  Services/
  Views/
  Helpers/
  Resources/
MacPulse.xcodeproj/
```

## Aktuelle Features

- Dashboard fuer CPU, Speicher, Volumes, Batterie, GPU-Anzeige und Netzwerkdurchsatz
- Prozessliste mit CPU-/Speicher-Historie und Terminierungsaktionen
- Netzwerkuebersicht mit Interfaces, ARP/mDNS-Device-Discovery und Verbindungen
- Packet Capture ueber libpcap mit BPF-Filter und Exportpfad
- Portscanner auf Basis von `NWConnection`
- Menu-Bar-Extra mit kompakten Metriken
- Storage-, Memory-, Activity- und 3D-City-Visualisierungen
- Privacy Mode mit zentraler Redaction-Logik fuer sichtbare Netzwerkdaten
- Diagnostics-Bereich fuer BPF-, Systemtool-, LaunchDaemon- und Settings-Checks
- Metadata-only Reports als JSON oder Markdown mit Privacy-Redaction

## Bekannte Einschraenkungen

- Packet Capture funktioniert nur mit passendem Zugriff auf `/dev/bpf*`.
- GPU-Auslastung wird ueber IOKit-Heuristiken gelesen und ist nicht auf allen Macs verlaesslich.
- Disk-I/O-Throughput wird ueber IOKit-Storage-Statistiken gelesen; auf Systemen ohne passende Counter faellt die Anzeige auf 0 zurueck.
- Memory Pressure wird aus Verfuegbarkeit, Active/Wired/Compressed Memory und Swap-Nutzung heuristisch berechnet.
- OUI-Lookup nutzt aktuell eine kleine eingebettete Prefix-Liste statt einer vollstaendigen gebundelten Datenbank.
- Geo-IP und Network-Map-Logik sollten weiter aus den Views in Services extrahiert werden.
- Privacy Mode maskiert zentrale Netzwerk-UI-Werte und metadata-only Reports; PCAP-Rohdaten bleiben ein separater Raw-Export.
- Diagnostics ist read-only und fuehrt keine Reparatur- oder Admin-Aktionen aus.
- Es gibt ein Unit-Test-Target fuer Parser, Formatter, Port-Mapping und Disk-I/O-Delta-Logik.

## Dokumentation

- `ARCHITECTURE.md`: Module, Datenfluss, Service-Lifecycle
- `DEVELOPMENT.md`: Build, Coding-Konventionen, Teststrategie
- `SECURITY.md`: Rechte, Packet Capture, Datenschutz, privilegierte Aktionen
- `ROADMAP.md`: technische Sanierung und Feature-Ausbau

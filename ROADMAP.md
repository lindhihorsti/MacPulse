# Roadmap

Diese Roadmap trennt technische Sanierung von Feature-Ausbau. Reihenfolge ist wichtiger als Umfang.

## Phase 1: Grundlage und Wahrheit

Status: begonnen

- Dokumentation auf aktuellen Ist-Zustand bringen.
- Build-Befehl und Runtime-Grenzen dokumentieren.
- Feature-Matrix pflegen.
- Sicherheitsrelevante Operationen dokumentieren.

## Phase 2: Stabilitaet

- Service-Lifecycle pruefen und vereinheitlichen.
- Observable State konsequent auf MainActor aktualisieren.
- Doppelte oder unkontrollierte Timer vermeiden.
- Settings-Defaults zentralisieren. Done: `MacPulseSettings`.
- Parser aus Services extrahieren. Begonnen: `lsof`, `arp`, `netstat`, `networksetup`.
- Deterministische Sortierungen fuer UI-Listen sicherstellen.

## Phase 3: Testbarkeit

- `MacPulseTests` Target anlegen. Done.
- Fixtures fuer `lsof`, `arp`, `netstat` und Packet Bytes erstellen. Begonnen mit inline Parser-Fixtures.
- Tests fuer Parser, Formatter und Port-Service-Mapping. Parser-, Packet-, Formatter-, Disk-I/O- und Port-Mapping-Tests begonnen.
- Live-Systemreader von Pure Parsern trennen.

## Phase 4: Fehlende Kernfeatures

- Disk-I/O-Throughput real implementieren. Done via IOKit `IOBlockStorageDriver` counters.
- Memory Pressure realistischer bestimmen. Done: testbare Heuristik aus Available, Active, Wired, Compressed und Swap.
- Packet Parsing erweitern: IPv6, ARP, DNS, ICMP Details. Begonnen: ARP, IPv6, IPv4 TCP/UDP/ICMP.
- OUI-Datenbank als Ressource laden und Updateprozess dokumentieren.
- Geo-IP als separaten Service modellieren. Guardrail begonnen: `IPAddressClassifier`.
- Private IPs konsequent von Geo-IP ausschliessen. Done fuer zentrale Klassifizierung und Traffic-Flow-Filter.
- Device Discovery mit mDNS-Namen besser zusammenfuehren.
- Privacy Mode als zentrale Redaction-Schicht einfuehren. Begonnen: Settings-Key, Helper, Tests, Netzwerklisten.
- Diagnostics-Grundlage einfuehren. Begonnen: read-only Service, Settings-UI und Tests fuer Tools, BPF, LaunchDaemon, Settings.
- Netzwerk-Intelligenz planen und umsetzen: 5-Tuple-Flows, Prozess-Korrelation, DNS/Reverse-DNS, Device-Inventar, Netzwerk-Alerts. Begonnen: TrafficFlow nutzt 5-Tuple-Identitaet; `NetworkCorrelationEngine` korreliert Connections und Flows.
- Metadata-only Reports einfuehren. Done: JSON/Markdown via `ReportExportService` mit Privacy-Redaction.

## Phase 5: UI-Struktur

- `NetworkView.swift` in kleinere Views und Services aufteilen.
- `ProcessListView.swift` in Liste, Detail, Panels und Flow-Visualisierung splitten.
- `SystemCityView.swift` modularisieren.
- `StorageFlowView.swift` Datenservice und UI staerker trennen.
- Empty, Loading und Error States vereinheitlichen.
- Accessibility-Pass fuer Labels, Kontraste und Tastatursteuerung.

## Phase 6: Release-Vorbereitung

- Developer ID Signing.
- Hardened Runtime pruefen.
- Notarization.
- DMG Pipeline.
- Reversible Install-/Uninstall-Doku fuer BPF LaunchDaemon.
- Datenschutznotizen fuer Packet Capture und Geo-IP.

## Feature-Matrix

| Bereich | Status | Naechster Schritt |
| --- | --- | --- |
| CPU Monitoring | Teilweise fertig | Messlogik validieren, Tests/Smoke-Checks |
| Memory Monitoring | Teilweise fertig | UI/Alerts gegen neue Pressure-Heuristik validieren |
| Disk Volumes | Teilweise fertig | Disk-I/O-Throughput implementieren |
| Battery | Teilweise fertig | Desktop-Macs sauber behandeln |
| GPU | Experimentell | Grenzen dokumentieren oder Reader verbessern |
| Process List | Teilweise fertig | Tests, UI-Split, sichere Aktionen |
| Interfaces | Teilweise fertig | Primary Interface und VPN-Erkennung verbessern |
| Connections | Teilweise fertig | `lsof` Parser testen/haerten |
| Device Discovery | Teilweise fertig | mDNS/OUI/stale handling verbessern |
| Packet Capture | Teilweise fertig | Rechtefluss, IPv6/ARP/DNS Parsing |
| Port Scan | Teilweise fertig | Cancellation vorhanden; Zielvalidierung und Tests begonnen |
| Settings | Teilweise fertig | zentrale Defaults und echte Service-Anbindung |
| Privacy Mode | Begonnen | Export/Copy/Details konsequent redigieren |
| Reports | Teilweise fertig | UI-Exportflow fuer JSON/Markdown vorhanden; Flow-/Prozessdaten spaeter direkt anbinden |
| Diagnostics | Begonnen | Check-Texte schaerfen und explizite Actions ergaenzen |
| Netzwerk-Intelligenz | Begonnen | Korrelationsdaten in Network-/Process-UI anzeigen |
| Distribution | Fehlt | Signing, Notarization, DMG |

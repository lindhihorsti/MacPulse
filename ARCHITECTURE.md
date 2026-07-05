# Architecture

## Ueberblick

MacPulse ist eine SwiftUI-App mit lokalem Monitoring. Die App liest Systemdaten direkt ueber macOS APIs und wenige Systemtools. Es gibt keinen Backend-Service und keine Datenbank.

## Einstiegspunkte

- `MacPulse/MacPulseApp.swift`: App-Entry, Hauptfenster, Settings, Menu-Bar-Extra, Onboarding und Alert-Timer.
- `MacPulse/ContentView.swift`: Sidebar-Navigation und Routing zu den Hauptbereichen.

## Schichten

### Models

`MacPulse/Models` enthaelt einfache Wertmodelle fuer Systemmetriken, Prozesse, Netzwerkgeraete, Verbindungen, Packet-Infos, Portscan-Ergebnisse und Graphdaten.

### Services

`MacPulse/Services` enthaelt Observable Services mit direktem Zugriff auf System APIs:

- `SystemMonitorService`: CPU, Memory, Disk, Battery, GPU, Network Counters.
- `ProcessMonitorService`: Prozessdaten via `proc_listallpids`, `proc_pidinfo`, `proc_pidpath`.
- `NetworkMonitorService`: Interfaces via `getifaddrs`, Verbindungen via `/usr/sbin/lsof`.
- `DeviceDiscoveryService`: lokales IP/Gateway, ARP Scan, mDNS.
- `PacketCaptureService`: libpcap Capture, BPF-Filter, Packet Parsing und Export.
- `PacketParser`: reine Ethernet/IPv4/IPv6/ARP-Auswertung fuer Capture-Daten.
- `DiskIOReader`: IOKit-Reader fuer Read/Write-Counter und testbare Delta-Berechnung.
- `MemoryPressureCalculator`: testbare Heuristik fuer Memory Pressure aus VM- und Swap-Kennzahlen.
- `PrivacyRedactor`: reine Redaction-Logik fuer IPs, MAC-Adressen, Hostnamen, Prozessnamen und freie Texte.
- `PortScannerService`: TCP Portscan mit `NWConnection`.
- `TrafficFlowService`: Flow-Erfassung fuer Traffic-Visualisierung, intern auf 5-Tuple-Basis via `PacketParser`.
- `NetworkCorrelationEngine`: reine Korrelation von `NetworkConnection`-Snapshots mit 5-Tuple-`TrafficFlow`s pro Prozess.
- `ReportExportService`: metadata-only JSON-/Markdown-Snapshots mit optionaler Privacy-Redaction.
- `DiagnosticsService`: read-only Health Checks fuer Systemtools, BPF-Zugriff, LaunchDaemon und Settings.
- `ForceLayoutEngine`: Layout/Physik fuer Graphdarstellungen.
- `AlertService`: Schwellenwertpruefung und UserNotifications.

### Views

`MacPulse/Views` enthaelt SwiftUI-Views nach Bereichen. Einige Dateien sind aktuell noch sehr gross und sollten schrittweise zerlegt werden:

- `Views/Network/NetworkView.swift`
- `Views/Shared/ProcessListView.swift`
- `Views/City/SystemCityView.swift`
- `Views/Storage/StorageFlowView.swift`

## Datenfluss

1. Views besitzen oder erhalten Observable Services.
2. Services starten Timer oder Tasks.
3. Services lesen Systemdaten und aktualisieren Observable Properties.
4. SwiftUI rendert die abhaengigen Views neu.

Der Hauptmonitor wird in `MacPulseApp` als `@State` gehalten und per Environment in die App gegeben. Andere Views erzeugen aktuell eigene Services lokal.

## Externe Systemquellen

- Darwin/Mach: CPU, VM-Statistiken, Prozessdaten.
- IOKit/IOPS: Batterie und GPU-Heuristiken.
- `getifaddrs`: Interfaces und Traffic Counters.
- `/usr/sbin/lsof`: Netzwerkverbindungen.
- `/usr/sbin/arp`: ARP-Tabelle.
- `/usr/sbin/netstat`: Default Gateway.
- `/usr/sbin/networksetup`: Hardware-Port-Namen.
- libpcap: Packet Capture.

## Technische Schulden

- Service-Lifecycle ist uneinheitlich; mehrere Timer koennen unabhaengig laufen.
- Main-Thread- und Background-Updates sind nicht durchgehend formalisiert.
- Parser fuer Systemtool-Ausgaben, Packet Bytes und Traffic-Flow-Identitaet haben erste Unit-Tests; Fixture-Abdeckung sollte weiter wachsen.
- Einige Feature-Services sind noch in grossen Views eingebettet.
- Persistenz laeuft ueber verstreute `@AppStorage` Keys.
- Privacy Mode ist als zentraler Helper vorhanden, aber noch nicht in allen Export- und Detailpfaden durchgezogen.

## Zielarchitektur

- Klare Service-Grenzen pro Datenquelle.
- Parser als reine, testbare Funktionen.
- View-Dateien deutlich kleiner, Logik in Services oder ViewModels.
- Zentraler Settings-Typ fuer UserDefaults Keys und Defaults.
- Redaction als verbindliche Darstellungsschicht fuer UI, Copy-Aktionen und Exporte.
- Reports sollen metadata-only bleiben; PCAP-Rohdaten bleiben ein expliziter Spezialexport.
- Diagnostics-UI mit erklaerbaren Checks und ohne automatische Systemreparaturen. Begonnen in den Settings.
- Prozess-zu-Netzwerk-Views auf Basis von `NetworkCorrelationEngine`, nicht auf reinen Remote-IP-Gruppen.
- Dedizierte Tests fuer Parser, Formatter und Service-Helfer.

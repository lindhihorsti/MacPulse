# MacPulse Agent Notes

Diese Datei ist die kurze Arbeitsorientierung fuer Coding-Agenten. Ausfuehrliche Projektdokumentation liegt in:

- `README.md`
- `ARCHITECTURE.md`
- `DEVELOPMENT.md`
- `SECURITY.md`
- `ROADMAP.md`

## Projekt

MacPulse ist eine native macOS-App fuer System- und Netzwerkmonitoring. Die App nutzt SwiftUI, Observation, Darwin/IOKit APIs, Network.framework und libpcap. Das aktuelle Target heisst `MacPulse`, das Scheme ebenfalls `MacPulse`, Deployment Target ist macOS 14.0.

## Build

```sh
xcodebuild -project MacPulse.xcodeproj -scheme MacPulse -configuration Debug -derivedDataPath /tmp/MacPulseDerivedData build
```

Das Projekt linkt gegen `libpcap` ueber `OTHER_LDFLAGS = -lpcap` und nutzt den Bridging Header `MacPulse/Helpers/libpcap-Bridging-Header.h`.

## Wichtige Grenzen

- Packet Capture braucht Zugriff auf `/dev/bpf*`.
- Netzwerkdaten kommen teilweise aus Systemtools wie `lsof`, `arp`, `netstat` und `networksetup`.
- Einige Features sind bewusst noch Roadmap-Arbeit: vollstaendige OUI-Datenbank, robuste Geo-IP-Schicht, Disk-I/O-Throughput, erweitertes Packet Parsing und Distribution/Notarization.
- Vor groesseren Refactors erst `ARCHITECTURE.md` und `ROADMAP.md` lesen.

## Arbeitsregeln

- Bestehende SwiftUI- und Observation-Patterns beibehalten.
- Grosse Views nur schrittweise extrahieren; keine breit angelegten Umbauten ohne Build-Verifikation.
- Systemtool-Ausgaben mit Parsern/Fixures testbar machen, bevor Verhalten erweitert wird.
- Sicherheitsrelevante Aenderungen an BPF, Prozessbeendigung oder LaunchDaemons immer in `SECURITY.md` dokumentieren.

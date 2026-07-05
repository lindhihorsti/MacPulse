# Development

## Build

```sh
xcodebuild -project MacPulse.xcodeproj -scheme MacPulse -configuration Debug -derivedDataPath /tmp/MacPulseDerivedData build
```

Bei lokalen Sandbox-Laeufen koennen Xcode/CoreSimulator-Warnungen erscheinen. Fuer dieses macOS-App-Target ist entscheidend, ob der Build mit `BUILD SUCCEEDED` endet.

## Lokaler Start

Nach dem Build liegt die App hier:

```text
/tmp/MacPulseDerivedData/Build/Products/Debug/MacPulse.app
```

Packet Capture benoetigt zusaetzliche BPF-Rechte, siehe `SECURITY.md`.

## Coding-Konventionen

- SwiftUI + Observation beibehalten.
- Kleine, fokussierte Aenderungen bevorzugen.
- Parser fuer externe Tool-Ausgaben als pure Funktionen halten.
- Systemzugriffe in Services kapseln, nicht in Views.
- UI-Dateien bei Erweiterungen nicht weiter aufblasen; neue Sections extrahieren.
- Keine sicherheitsrelevanten Aktionen ohne sichtbaren User-Kontext.

## Settings Keys

Aktuell genutzte UserDefaults/AppStorage Keys:

- `hasCompletedOnboarding`
- `showMenuBarIcon`
- `menuBarShowCPU`
- `menuBarShowMemory`
- `launchAtLogin`
- `privacyMode`
- `refreshInterval`
- `alertsEnabled`
- `cpuAlertThreshold`
- `memoryAlertThreshold`

Die kanonischen Keys und Defaults liegen in `MacPulse/Helpers/MacPulseSettings.swift`.

## Teststrategie

Es gibt ein Unit-Test-Target `MacPulseTests`. Ausfuehren:

```sh
xcodebuild test -project MacPulse.xcodeproj -scheme MacPulse -configuration Debug -derivedDataPath /tmp/MacPulseDerivedData
```

Aktuelle Testabdeckung umfasst Systemcommand-Parser, Packet-Parsing, IP-Adressklassifizierung, Traffic-Flow-Identitaet, Prozess-Netzwerk-Korrelation, metadata-only Reports, Formatter, Port-Service-Mapping, Portscan-Zielvalidierung, Disk-I/O-Delta-Logik, Memory-Pressure-Heuristik, Privacy-Redaction und Diagnostics-Checks.

Empfohlene Reihenfolge fuer den weiteren Ausbau:

1. Weitere Fixtures fuer `lsof`, `arp`, `netstat` und Packet Bytes ergaenzen.
2. IPv6-TCP/UDP-Fixtures und DNS/ICMP-Detailparser ergaenzen.
3. Prozess-Netzwerk-Korrelation in die Network-/Process-UI integrieren.
4. Privacy Mode in Copy-Aktionen und Packet-Details erzwingen.
5. Diagnostics-Check-Texte auf Endnutzer-Verstaendlichkeit pruefen und Actions nur als explizite User-Flows ergaenzen.
6. Geo-IP-Aufloesung nur ueber `IPAddressClassifier.isEligibleForExternalGeoLookup(_:)` erlauben.
7. Service-Reader weiter von Parsern trennen, damit Live-Systemdaten nicht fuer Unit-Tests noetig sind.
8. UI-Smoke-Test fuer die Hauptnavigation spaeter ergaenzen.

## Manuelle QA

- App startet und Sidebar-Views wechseln ohne Crash.
- Dashboard zeigt CPU/Memory/Network-Werte.
- Prozessliste laedt und Sortierung bleibt stabil.
- Network Interfaces werden angezeigt.
- Device Scan zeigt ARP-Geraete, falls vorhanden.
- Packet Capture zeigt bei fehlenden BPF-Rechten einen verstaendlichen Fehler.
- Portscan kann `127.0.0.1` scannen, laesst sich abbrechen und lehnt URLs/Pfade/ungueltige Hosts sichtbar ab.
- Settings schreiben erwartete Werte.
- Privacy Mode maskiert IP/MAC/Hostname/Prozessnamen in Netzwerklisten.
- Diagnostics-Checks melden BPF-/Tool-/LaunchDaemon-/Settings-Zustand plausibel.
- Network-Report laesst sich als JSON oder Markdown exportieren und respektiert Privacy Mode.
- Menu-Bar-Extra laesst sich ein- und ausblenden.

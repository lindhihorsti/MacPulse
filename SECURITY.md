# Security

MacPulse liest lokale System- und Netzwerkdaten. Einige Funktionen greifen auf sensible Betriebssystembereiche zu und muessen bewusst behandelt werden.

## Packet Capture

Packet Capture nutzt libpcap und benoetigt Zugriff auf `/dev/bpf*`. Ohne passende Rechte kann `pcap_open_live` fehlschlagen.

Die App enthaelt Hilfen fuer:

- temporaeres Setzen von Leserechten auf `/dev/bpf*`
- optionale Installation eines LaunchDaemons fuer dauerhafte BPF-Rechte

Diese Aktionen verlangen Administratorrechte und veraendern Systemzustand. Jede Erweiterung in diesem Bereich muss klar dokumentieren:

- welche Dateien geaendert werden
- ob die Aenderung persistent ist
- wie sie rueckgaengig gemacht werden kann
- welche Sicherheitswirkung sie hat

## Prozessaktionen

`ProcessMonitorService` kann Prozesse mit `SIGTERM` oder `SIGKILL` beenden. UI-Flows muessen eine klare Bestaetigung fuer destructive Aktionen behalten.

## Netzwerkdaten

Die App kann lokale Interfaces, lokale Geraete, Verbindungen, IP-Adressen und Packet-Metadaten anzeigen. Diese Daten koennen private Informationen enthalten.

Regeln:

- Keine externe Uebertragung lokaler Netzwerkdaten ohne explizite User-Aktion.
- Private, loopback, multicast, reserved, unspecified und link-local IPs duerfen nicht an externe Geo-IP-Dienste gesendet werden.
- Packet Payloads nicht ungefragt persistieren oder exportieren.

`IPAddressClassifier.isEligibleForExternalGeoLookup(_:)` ist die zentrale Guardrail fuer kuenftige Geo-IP-Aufloesung. Neue Geo-IP- oder Enrichment-Services muessen diese Pruefung vor jedem externen Lookup verwenden.

## Portscan

Der Portscan arbeitet nur mit einem explizit eingegebenen Ziel. Eingaben werden vor dem Start auf Hostname, IPv4 oder IPv6 normalisiert; URLs, Pfade und Hosts mit Leerzeichen werden abgelehnt. Der Scanner startet keine automatischen Netzwerkscans im Hintergrund.

## Privacy Mode

Privacy Mode ist als zentrale Redaction-Schicht begonnen. `PrivacyRedactor` maskiert IP-Adressen, MAC-Adressen, Hostnamen, Prozessnamen und freie Texte deterministisch. Netzwerklisten nutzen diese Schicht bereits fuer sichtbare Werte.

Wichtige Grenzen:

- Rohmodelle und Services behalten die originalen Messwerte fuer Korrelation, Filter und Systemlogik.
- Metadata-only Reports nutzen die Redaction-Schicht.
- Packet-/PCAP-Export kann weiterhin Rohdaten enthalten und muss als Raw-Export behandelt werden.
- Neue Copy-, Export- und Detailansichten muessen explizit dieselbe Redaction-Schicht verwenden.

## Externe Tools

Die App nutzt Systemtools wie `lsof`, `arp`, `netstat` und `networksetup`. Diese Tools koennen je nach macOS-Version, Rechten und Datenschutz-Einstellungen unterschiedliche Ausgaben liefern. Parser muessen robust gegen fehlende Felder und Fehlerausgaben sein.

## Diagnostics

`DiagnosticsService` fuehrt nur lesende Checks aus. Er prueft unter anderem die Ausfuehrbarkeit benoetigter Systemtools, sichtbare/lesbare BPF-Devices, den optionalen BPF-LaunchDaemon und Settings-Plausibilitaet.

Diagnostics darf keine Admin-Aktionen, LaunchDaemon-Installationen oder Rechteaenderungen automatisch ausloesen. Reparaturen bleiben separate, sichtbare User-Aktionen.

## Signing und Distribution

Aktuell ist der Debug-Build lokal signiert. Fuer Distribution sind noch offen:

- Developer ID Signing
- Hardened Runtime Verifikation
- Notarization
- DMG-Erstellung
- dokumentierter BPF-Rechtefluss fuer Endnutzer

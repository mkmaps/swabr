# Swabr-Regelwerk

Stand: 25.10.2026 · gilt für `SwabrDirect` und `SwabrStore`

Dieses Dokument legt fest, **was Swabr anfassen darf, wie es einstuft und wann es ablehnt**. Es ist die
verbindliche Grundlage für `Tools/rules/make_rules.py`, `Tools/rules/make_protection.py` und die Schutzlogik in
`Packages/SwabrCore`. Zu jeder Regel steht der Ist-Stand im Code und, wo etwas fehlt, eine Maßnahme
(Kennung **M-xx**, Liste in Abschnitt 6).

Legende Ist-Stand: ✅ umgesetzt · ⚠️ teilweise · ❌ fehlt

---

## 0. Grundsätze

| Nr. | Grundsatz |
|---|---|
| G1 | **Scannen ändert nichts.** Gelöscht wird erst nach Anzeige, Auswahl und Bestätigung. |
| G2 | **Im Zweifel behalten.** Nach dem Scan ist standardmäßig nichts vorausgewählt; der Nutzer entscheidet, was geht. „Prüfen“-Einträge sind nur mit der Einstellung „Alle“ vorausgewählt. |
| G3 | **Mehrere unabhängige Sperren.** Regel → Einstufung → Whitelist → Pfadprüfung → Prüfung direkt vor dem Löschen. Jede Schicht muss allein ausreichen, um Schaden zu verhindern. |
| G4 | **Muster nie breiter als nötig.** Ein Muster wird gegen eine echte App-Liste und einen echten Benutzerordner geprüft (Lehre aus `com.apple.*`, das Safari-Web-Apps und Pixelmator gesperrt hat). |
| G5 | **Papierkorb zuerst.** Standard ist der Papierkorb, endgültiges Löschen nur auf ausdrückliche Einstellung. Apps gehen immer in den Papierkorb. |
| G6 | **Eigenständige Regeln.** Quellen sind die Ordnerkonventionen von macOS, die Herstellerdokumentation der Werkzeuge und die Bestandsaufnahme. Kataloge oder Pfadlisten fremder Produkte werden nicht übernommen. Ideen auf Konzeptebene (z. B. Stufenmodell) sind erlaubt. |
| G7 | **Jede Löschung wird protokolliert** (`~/Library/Application Support/Swabr/operations.log`). |
| G8 | **Erklärbar.** Jeder Fund zeigt in einfachen Worten, was das Entfernen bedeutet (`RuleKind.impact`, `Leftover.impact`). |

---

## 1. Begriffe

- **Regel** (`CleanRule`): Abschnitt, Bezeichnung, Art (`kind`), Glob-Pfade, optional Ausnahmen und Bedingungen.
- **Art** (`RuleKind`): bestimmt die Erklärung und die Standard-Einstufung.
- **Einstufung** (`Safety`): wie sicher ein Fund ohne Hinsehen entfernt werden kann.
- **Abschnitt** (`section`): Gruppierung in der Oberfläche. Reihenfolge: `system, browsers, apps, developer, app_caches, leftovers`.
- **Whitelist**: vom Nutzer geschützte Muster (`~/.config/swabr/whitelist`).
- **Sicherheitsmuster** (`safetyWhitelist`): immer geschützt, unabhängig von der Whitelist.
- **Tabu-Bereich** (`PathSafety.neverTouch`/`neverRemove`): wird nie angefasst bzw. selbst nie entfernt.

---

## 2. Die Schutzschichten

### S1 – Regelkatalog (Aufräumen)

**Regeln**
1. Regeln entstehen nur in `make_rules.py`; `clean_rules.json` wird nie von Hand bearbeitet.
2. Jede Regel hat `section`, `label`, `kind`, `paths`. `label` ist ein Produktname (unübersetzt) oder ein deutscher Schlüssel aus dem Kern-Katalog.
3. **Erster Treffer gewinnt.** Gezielte Regeln stehen vor allgemeinen. Eine wegen laufender App übersprungene Regel beansprucht ihre Pfade trotzdem (`CleanScanner.resolve`), damit keine breitere Regel sie aufgreift.
4. Pfade enden auf `/*` (Inhalt), nie auf dem Ordner selbst, außer bei einzelnen Dateien (`~/.zcompdump*`).
5. Bedingungen:
   - `skipIfRunning`: Regel ruht, solange die App läuft.
   - `skipRunningOwner`: pro Treffer die besitzende App prüfen (für Sammelregeln).
   - `chromiumOnly`: ein Ordner `Cache` zählt nur neben `Code Cache`/`GPUCache`.
   - `minAgeDays`: nur Unverändertes ab diesem Alter.
   - `exclude`: an spätere Regeln weiterreichen.
   - `keep`: der Treffer selbst bleibt, nur sein Inhalt wird entfernt.
6. Apple-Pfade (`com.apple.*`) sind in Sammelregeln ausgenommen und laufen nur über die eigene Regel „macOS-Caches“ (Einstufung *Prüfen*).
7. **Dynamische Regeln** (`DynamicRules`) ergänzen den Katalog zur Laufzeit:
   - Werkzeug-Caches an ihrem konfigurierten Ort: npm, Bun, uv, Corepack, rustup.
   - Reste entfernter Apps: ab 30 Tagen unverändert, immer *Prüfen*.
   - Unbenutzte Luftaufnahmen.
   - Ältere JetBrains-Versionen.
   - Großdatenbestände nur als Hinweis.

**Ist-Stand** ✅
- 123 Regeln mit 174 Mustern (Stand nach M-11, vorher 118 mit 167).

  | Abschnitt | Regeln | Sicher | Prüfen |
  |---|---|---|---|
  | system | 8 | 1 | 7 |
  | browsers | 15 | 13 | 2 |
  | apps | 22 | 18 | 4 |
  | developer | 66 | 54 | 12 |
  | app_caches | 12 | 9 | 3 |

- Bestandsaufnahme vom 25.10.2026: Vor M-11 waren 9 230 Pfade abgedeckt, 22 Funde über 20 MB fehlten. Danach sind es 9 570 Pfade und keine Lücke über 20 MB (Abschnitt 5).
- Verschachtelte Container (Safari-Web-Apps) gehören der inneren Bundle-ID (`CleanScanner.owners`), so greift `skipRunningOwner` pro Web-App.
- Die Tests in `ImpactTests.swift` prüfen das Format und die Tabu-Bereiche.

### S2 – Einstufung

**Regeln**: vier Stufen. Zwei davon sind auswählbar, zwei werden nur angezeigt bzw. gar nicht gezeigt.

| Stufe | Bedeutung | Vorausgewählt | Umsetzung |
|---|---|---|---|
| **Sicher** | Cache, Log, Temp, Pakete, Build-Ergebnisse, die von selbst neu entstehen | nur mit Einstellung „Empfohlen“ oder „Alle“, sonst per Knopf „Empfohlen“ | `Safety.safe` |
| **Prüfen** | kann noch gewollte Daten, Anmeldungen, Verläufe oder lange Downloads enthalten | nur mit Einstellung „Alle“ | `Safety.review` |
| **Hinweis** | wird nur mit Größe und Weg zum Aufräumen gezeigt, Swabr löscht nicht | – | `DynamicRules.largeData` |
| **Gesperrt** | wird nie gezeigt und nie gelöscht | – | `safetyWhitelist`, `PathSafety` |

Zuordnung `kind` → Standard-Einstufung (`Rules.swift:9`):
- *Sicher*: `cache, browserCache, log, crash, temp, packages, build, derivedData`
- *Prüfen*: `deviceSupport, updates, state, trash, mailDownloads, models, recentItems, history, suggestions, aerials, worktrees`

Eine Regel darf ihre Einstufung nur **verschärfen** (`safety: "review"`), nie lockern.
Pflicht für *Prüfen*:
- großer Neu-Download (Gradle, Playwright, Cypress)
- Anmeldedaten (AWS-Tokens)
- laufende Sitzungen (Jupyter)
- Sammelregeln ohne eindeutigen Besitzer (`Application Support/*/Cache`, `Group Containers`, `Containers/*/Data/tmp`)

**Ist-Stand** ✅
- *Sicher* und *Prüfen* sind als `Safety` umgesetzt. *Hinweis* ist die Gruppe „Große Datenbestände (nur Hinweis)“. *Gesperrt* erscheint aufgeklappt mit Grund und als Zahl „Geschützt und übersprungen“ (M-08).
- Einstellung „Nach dem Scan vorauswählen“ (`Prefs.preselect`, seit 31.10.2026) für Aufräumen, Projekte, Installer und Optimieren: **Nichts** (Standard) / Empfohlen (Aufräumen nur „Sicher“, Projekte nur unbenutzte, Optimieren nur unauffällige Aufgaben) / Alle (alles außer Geschütztem und Laufendem). Optimieren merkt sich eine einmal getroffene Auswahl. Die Auswahl bleibt in „Auswahl ansehen“ und in der Prüfansicht vor dem Löschen sichtbar.
- Test `catalogueNeverLoosensSafety` (M-07): Keine Regel setzt `safety: "safe"`, und die Pflicht-*Prüfen*-Regeln sind festgehalten.

### S3 – Pfadprüfung (letzte Sperre)

**Regeln**: Ein Pfad wird abgelehnt, wenn er

| # | Bedingung | Ist-Stand |
|---|---|---|
| P1 | nicht absolut ist | ✅ `PathSafety.check` |
| P2 | `.` oder `..` als Bestandteil enthält | ✅ |
| P3 | außerhalb des Benutzerordners liegt (Aufräumen) | ✅ |
| P4 | ein geschützter Grundordner selbst ist (`Library`, `Library/Caches`, `Documents`, `Desktop` … `neverRemove`) | ✅ `Protection.swift:84` |
| P5 | in einem Tabu-Bereich liegt (`Mobile Documents`, `Keychains`, `CloudStorage`, `.ssh`, `.gnupg`) | ✅ `Protection.swift:90` |
| P6 | einen Symlink als Vorfahren hat | ✅ `lstat`-Kette |
| P7 | Steuerzeichen (Zeilenumbruch, NUL, ESC) enthält | ✅ `PathSafety.hasControlCharacters`, auch in Systempfaden, Speicher und Projekten (M-01) |
| P8 | leer ist | ✅ implizit (P1) |
| P9 | von Whitelist oder Sicherheitsmuster geschützt ist, auch als Eltern- oder Kindpfad eines geschützten Pfads | ✅ `Whitelist.protectingPattern` |

Ein Symlink als Ziel wird als Link entfernt, nie sein Ziel. Das ist bereits so, weil `trashItem`/`removeItem` dem Link nicht folgen.

### S4 – Whitelist und „Nie aufräumen“

**Regeln**
1. Datei `~/.config/swabr/whitelist`, ein Glob pro Zeile, `~` steht für den Benutzerordner, `#` leitet einen Kommentar ein.
2. Existiert die Datei, **ersetzt** sie die Standardwerte (`defaultWhitelist`: Gradle, Playwright, Hugging Face). Sicherheitsmuster gelten immer.
3. Ist die Datei **unlesbar, läuft keine Bereinigung** (`Whitelist.load` wirft einen Fehler).
4. Die Whitelist wird beim Scan **und** direkt vor jedem Löschen geprüft.
5. In der Prüfansicht gibt es zwei Aktionen:
   - **„Nie aufräumen“** für den Eintrag. Gespeichert wird das Muster der Regel, nicht jeder Einzelpfad.
   - **„Nie aufräumen: alle Ordner namens X“** als Namensregel.
6. Unter Einstellungen → Geschützte Daten stehen Schalter pro Produkt (`whitelistOptions`, 44 Stück), eigene Muster, die Sicherheitsmuster als Liste zum Lesen und „Zurücksetzen“.

**Ist-Stand** ✅
- „Nie bereinigen“ für einen Eintrag speichert die **Muster seiner Regeln** (`ProtectionPattern.forItem`), damit auch spätere Treffer geschützt sind. Klammern `{a,b}` werden aufgelöst, weil die Whitelist mit `fnmatch` vergleicht (M-03).
- Pro Ort in der aufgeklappten Liste gibt es drei Aktionen (M-04):
  - „dieser Ort“
  - „alles von <App>“ (`~/Library/<Anker>/<App>/*`)
  - „alle Ordner namens X“ (`*/X/*`)
- Der Schutz wirkt sofort ohne neuen Scan (`CleanItem.applying`). Eine Leiste über der Liste bietet „Rückgängig“.

### S5 – Laufende Apps und Prüfung direkt vor dem Löschen

**Regeln**
1. Beim Scan ruhen Regeln oder Treffer, deren App läuft (`skipIfRunning`, `skipRunningOwner`).
2. **Unmittelbar vor dem Löschen** wird erneut geprüft: ob der Pfad noch existiert, P1–P9, die Whitelist **und ob die besitzende App inzwischen gestartet wurde**. Ein Treffer einer seither gestarteten App wird mit „App wurde nach der Prüfung gestartet“ übersprungen.
3. Bei Projekten blockiert ein Prozess, der im Projektordner arbeitet (`Processes.isInUse`).

**Ist-Stand** ✅
- Alle drei Punkte sind umgesetzt.
- `CleanItem` übernimmt `skipIfRunning`/`skipRunningOwner` seiner Regeln, beim Zusammenführen von allen.
- `Cleaner.clean` fragt direkt vor dem Löschen erneut nach den laufenden Apps (M-02).

### S6 – Löschen und Ergebnis

**Regeln**
1. Modus „Papierkorb“ (Standard) oder „Endgültig“. Was schon im Papierkorb liegt, wird immer endgültig entfernt.
2. Das Ergebnis wird nach Grund gruppiert: *entfernt*, *übersprungen: Whitelist / geschützter Pfad / App läuft / keine Berechtigung / nicht mehr vorhanden*, *fehlgeschlagen*.
3. Jede Löschung kommt mit Aktion, Bytes, Bezeichnung und Pfad ins Protokoll.

**Ist-Stand** ✅
- `ProtectedPath.Kind` (`whitelist, protectedPath, running, permission, failed`) wird überall gesetzt, wo übersprungen oder abgelehnt wird. Aufräumen, Speicher, Projekte und Deinstallieren setzen ihn; Berechtigungsfehler erkennt `ProtectedPath(path:error:)`.
- Das Ergebnis von „Aufräumen“ ist nach diesen Gründen gruppiert (M-09).

### S7 – Administratorrechte (Systempfade)

**Regeln**
1. Außerhalb des Benutzerordners wird nur unter **erlaubten Wurzeln** gelöscht:
   - `/Library/{Application Support, Caches, Logs, Preferences, LaunchAgents, LaunchDaemons, PrivilegedHelperTools, Receipts, Frameworks, Internet Plug-Ins, Input Methods, Audio/Plug-Ins, QuickLook, PreferencePanes, Screen Savers, Extensions, StartupItems}/<Name>`
   - nie die Wurzel selbst
   - nie `com.apple.*` und nie `Apple*`
2. Pro Vorgang gibt es eine einzige Passwortabfrage. Daemons werden vor dem Verschieben gestoppt.
3. Das als root laufende Skript **prüft jeden Pfad selbst noch einmal**, bevor es ihn anfasst:
   - kein Symlink
   - der physische Elternordner ist unverändert (`cd -P` und `pwd -P`)
   - kein `..`, kein Zeilenumbruch
   - der Pfad liegt unter einer erlaubten Wurzel

   Grund: `/Library/Caches` ist für alle Benutzer beschreibbar, und zwischen Scan und root-Aktion kann ein Ordner gegen einen Link getauscht werden.
4. Ziel ist der Papierkorb des Benutzers, danach geht die Datei per `chown` an den Benutzer.

**Ist-Stand** ✅
- Alle Punkte sind umgesetzt.
- Jeder root-Schritt ist eine feste `RootOperation` (`Privileged/RootOperation.swift`) und wird vom `RootExecutor` ausgeführt; ein Shell-Skript als root gibt es nicht mehr (seit 31.10.2026, Abnahme A-01). Erlaubte Wurzeln: `RootExecutor.systemRoots` (= `LeftoverFinder.systemRoots`), die App-Ordner, der Benutzerordner und `/Volumes/` (mindestens zwei Ebenen unter dem Volume).
- Der `RootExecutor` prüft Wurzel, `..`, `com.apple.`, Steuerzeichen, Links an Quelle und Elternordner sowie den physischen Elternordner (`realpath`). Er verschiebt per `renameatx_np` relativ zu den mit `O_NOFOLLOW` geöffneten Ordnern, nie auf ein bestehendes Ziel (`RENAME_EXCL`), und nur direkt in den Papierkorb des anfragenden Benutzers (M-05).
- Genutzt wird es von Deinstallieren (Apps von root, Systemdateien) und von Startobjekte (verwaiste Systemdienste).

**Hilfsdienst (Direct, seit 25.10.2026)**
- `SwabrHelper` wird per `SMAppService.daemon` angemeldet und einmal unter Anmeldeobjekte erlaubt. Danach führt er Admin-Schritte ohne Passwort aus, auf Wunsch des Nutzers ohne Rückfrage.
- Er nimmt nur Verbindungen der App mit der Kennung `io.github.mkmaps.swabr` und Team `Y94QZAZZ45` an. Umgekehrt verbindet sich die App nur mit dem gleich signierten Dienst.
- Er nimmt nur feste `RootOperation`s an (Papierkorb, Dienst stoppen, App ersetzen, sieben Wartungsbefehle), prüft jede selbst und startet Programme ohne Shell mit festen Argumenten und Zeitlimit (Abnahme A-01/A-02). Für wen er arbeitet, entnimmt er der XPC-Verbindung, nicht der Anfrage.
- Ohne Freigabe fragt macOS nach dem Passwort und startet dann dasselbe Helferprogramm einmal (`--perform`), mit denselben Prüfungen.
- Entfernen geht unter Einstellungen → Verhalten → Administratorrechte.

**Root-Weg für Einträge, die root gehören (seit 25.10.2026)**
- Scheitert Speicher, Aufräumen, Projekte oder Installer am Papierkorb, weil der Nutzer keine Rechte hat, legt `RootTrash.move` die Einträge in einem einzigen Root-Schritt in den Papierkorb.
  - Jeder Eintrag hat vorher alle Prüfungen des Moduls bestanden.
  - Danach gehören die Einträge per `chown` wieder dem Nutzer.
  - Erlaubte Wurzeln: beim Aufräumen nur der Benutzerordner, bei Projekten nur die Suchorte, im Speicher nur die Wurzeln von `RootScript.roots`. Der Helfer prüft zusätzlich gegen seine eigenen Wurzeln.
  - „Endgültig löschen“ löscht anschließend als Nutzer im Papierkorb. Als root läuft nie ein `rm`.
- Verschlanken ersetzt Apps, die root gehören, ebenfalls über einen Root-Schritt (`AppSlimmer.rootSwap`):
  1. Original per `RootOperation.replaceApp` in den Papierkorb (nur aus den App-Ordnern, Kopie gleichen Namens aus einem Arbeitsordner).
  2. Geprüfte Kopie an seinen Platz.
  3. Eigentümer des Originals übernehmen.
  4. Schlägt Schritt 2 fehl, kommt das Original zurück.
- In der Store-Variante gibt es keinen Root-Weg; dort bleibt es bei „keine Berechtigung“.

### S8 – Deinstallieren: Zuordnung von Resten

**Regeln**
1. Nicht deinstalliert werden:
   - Swabr selbst
   - Teile von macOS (SIP-Flag `SF_RESTRICTED` oder Link nach `/System`; Liste `systemCriticalBundles`, Ausnahmen in `appleUninstallableApps`)
   - Sicherheits- und MDM-Software, die ein eigenes Deinstallationsprogramm braucht (`officialUninstallerRules`, 13 Hersteller, Namensteile nur als ganze Wörter)
2. App-Store-Apps gelten nie als Teil von macOS (Beleg ist das Receipt).
3. Ein Rest wird einer App über **Belege** zugeordnet. Die Belege haben eine Stärke:

   | Beleg | Stärke | Ist-Stand |
   |---|---|---|
   | Bundle-ID exakt oder `id.` als Präfix | stark | ✅ |
   | Container-Metadaten (`MCMMetadataIdentifier`, iPhone/iPad-Apps) | stark | ✅ |
   | Gruppen-Container mit ID-Grenze (`TEAM.id`) | stark | ✅ |
   | LaunchAgent/Daemon, dessen Programm in der App liegt | stark | ✅ |
   | Hersteller/Produkt aus der Bundle-ID (`Google/Chrome`) | mittel | ✅ |
   | Paketbeleg (`pkgutil --file-info`/`--files`) | stark | ✅ (M-06b) |
   | Homebrew-Cask (`brew uninstall --zap`) | stark | ✅ über brew |
   | **nur Namensgleichheit** | schwach | ✅ gefunden, nie vorausgewählt (M-06) |

4. Vorauswahl nach **Art und Belegstärke**:

   | Art | Vorausgewählt |
   |---|---|
   | `disposable` (Caches, Logs, Fensterzustand) | ja, aber nur bei starkem oder mittlerem Beleg |
   | `launchAgent` | ja |
   | `personal` | nein, nur mit „Alle Daten entfernen“ |
   | `sensitive` (Gruppen-Container, Browser- und Spielprofile) | nie, auch nicht mit „Alle Daten“ |
   | `system` | nur mit Passwort |

5. Keine Reste werden gesucht, wenn eine zweite installierte Kopie dieselbe Bundle-ID hat.
6. Häufige Wörter (`commonNames`) gelten nie als Namensbeleg. Grundordner (`bareRoots`) werden nie selbst geliefert.
7. Daten von Passwort-, Schlüssel-, Wallet-, VPN- und Eingabe-Programmen (`sensitiveBundles`, 31 Muster) gelten nie als Rest entfernter Apps.

**Ist-Stand** ✅
- `Leftover.evidence` unterscheidet `identity` (Bundle-ID, Container-Metadaten, Gruppen-Container, Hersteller/Produkt, Programmpfad) von `nameOnly`.
- Reine Namenstreffer sind nie vorausgewählt, auch nicht mit der Einstellung „Systemdateien mit entfernen“. Sie werden in der Liste mit Warnung und dem Hinweis „Nur über den Namen gefunden, bitte prüfen“ gezeigt (M-06).
- Paketbelege (M-06b, `Uninstall/PackageReceipts.swift`) funktionieren so:
  - Die Pakete, die das App-Bundle installiert haben (`pkgutil --file-info`), und die nach der Bundle-ID benannten Pakete gelten als Eigentümer.
  - Deren Ordner in `/Library` zählen als starker Beleg, wenn kein fremdes Paket sie mitbenutzt. Ist der Herstellerordner geteilt, gilt das für den Produktordner eine Ebene tiefer.
  - Apple-Pakete zählen nie.

### S9 – Startobjekte

**Regeln**
1. Verwaltbar (blockieren, erlauben, entfernen) sind nur LaunchAgents im Benutzerordner. Systemweite Objekte werden in den Systemeinstellungen geändert. Ausnahme: Ist ihr Programm verschwunden, dürfen sie mit Passwort entfernt werden.
2. `com.apple.*` wird nie gelistet. Labels müssen `^[A-Za-z0-9._-]+$` erfüllen.
3. **Sicherheits-, MDM- und VPN-Dienste** (Hersteller aus `officialUninstallerRules` und `sensitiveBundles`) werden als „Geschützt“ gezeigt: Blockieren geht nur nach Warnung, Entfernen gar nicht.
4. Swabrs eigene Dienste sind immer geschützt.

**Ist-Stand** ✅
- `StartupItems.protectionReason` setzt `protectedReason` für Swabr selbst, Hersteller aus `officialUninstallerRules` (Präfix oder ganzes Wort) und `sensitiveBundles`.
- Geschützte Dienste lassen sich nur nach einer Rückfrage blockieren (`block(_:confirmed:)`). Entfernen geht nur, wenn ihr Programm fehlt (M-10).

### S10 – Speicher (Analyse)

**Regeln**: Verschieben in den Papierkorb ist abgelehnt für:
- kritische Wurzeln (`/`, `/System`, `/Library`, `/usr` außer `/usr/local`, `/private/*` …)
- den Benutzerordner selbst und `neverRemove`
- Daten laufender VMs (Docker, OrbStack)
- iCloud und Schlüsselbund

Geprüft wird sowohl der bereinigte als auch der aufgelöste Pfad.

**Ist-Stand** ✅ `AnalyzeTrash.refusal`

### S11 – Projekte

**Regeln**
1. Nur bekannte Artefakt-Namen (`ProjectPurge.targets`) in Ordnern mit Projektkennzeichen (`package.json`, `Cargo.toml`, `.git` …).
2. Geschützt sind:
   - verschachtelte `.git`
   - `*-keypair.json`
   - von git verfolgte Dateien
   - `bin` außer .NET-Ausgabe
   - `vendor` außer Composer
   - das globale Xcode-DerivedData
3. Was nicht innerhalb von 20 s geprüft werden konnte, gilt als geschützt.
4. Vorausgewählt wird nur mit der Einstellung „Empfohlen“ (Projekte ohne Aktivität in den letzten 7 Tagen) oder „Alle“; Standard ist nichts.
5. Läuft ein Prozess im Projekt, wird es übersprungen, auch noch direkt vor dem Löschen.
6. Außerhalb des Benutzerordners nur unter konfigurierten Wurzeln auf `/Volumes`, ohne Symlink.

**Ist-Stand** ✅ `ProjectPurge` (Neubau 25.10.2026): Kennzeichen-Tabelle je Werkzeug, Schutzprüfung beim Scan und erneut in `delete`. Zusätzlich gilt: Das Artefakt muss in einem Suchort liegen, ein Prozess darüber bis zum Suchort zählt als „in Benutzung“, und `~/Library` sowie Bundles werden nie betreten.

### S12 – Optimieren

**Regeln**
1. Jede Aufgabe meldet einen dieser Zustände: *angewendet, unverändert, übersprungen, Hinweis, fehlgeschlagen, nicht verfügbar*.
2. Abgewählte Aufgaben werden gemerkt und gelten als Optimieren-Whitelist.
3. Alle Admin-Schritte laufen unter einer Passwortabfrage.
4. In der Store-Variante gibt es nur sandbox-taugliche Aufgaben.
5. Datenbanken über 100 MB oder beschädigte Datenbanken werden nicht angefasst.

**Ist-Stand** ✅ (`OptimizeModel`, `SQLiteMaintenance`)

---

## 3. Abgleich auf einen Blick

| Schicht | Stand | Offene Maßnahme |
|---|---|---|
| S1 Regelkatalog | ✅ | – |
| S2 Einstufung | ✅ | – |
| S3 Pfadprüfung | ✅ | – |
| S4 Whitelist | ✅ | – |
| S5 Prüfung vor dem Löschen | ✅ | – |
| S6 Ergebnis | ✅ | – |
| S7 Admin-Pfad | ✅ | – |
| S8 Deinstallieren | ✅ | – |
| S9 Startobjekte | ✅ | – |
| S10 Speicher | ✅ | – |
| S11 Projekte | ✅ | – |
| S12 Optimieren | ✅ | – |

---

## 4. Regeln für neue Katalogeinträge

1. **Beleg zuerst**: Herstellerdoku oder macOS-Konvention nennen (Kommentar in `make_rules.py`), dann den Pfad im echten Benutzerordner nachweisen.
2. **Art wählen**, nicht Einstufung. Die Einstufung nur verschärfen, wenn ein Pflichtgrund aus S2 vorliegt.
3. **Laufende App** angeben (`skipIfRunning` mit Prozess- oder Bundle-Namen), sobald die App den Ordner offen halten kann.
4. **Gezielt vor allgemein** einsortieren. Prüfen, dass keine breitere Regel den Pfad vorher beansprucht.
5. Für Sammelregeln Apple ausnehmen (`exclude`) und `skipRunningOwner` setzen.
6. Inhalte mit Nutzerwert (Offline-Musik, Zwischenablage-Verlauf, Offline-Anhänge, Chat-Medien, die nicht neu ladbar sind) sind **kein Cache**, auch wenn der Ordner so heißt. Solche Inhalte bekommen *Prüfen* oder werden gar nicht aufgenommen.
7. Nach jeder Änderung:
   ```bash
   python3 -I Tools/rules/make_rules.py && python3 -I Tools/rules/make_protection.py
   cd Packages/SwabrCore && swift test
   ```
   Dazu die Bestandsaufnahme wiederholen (Abschnitt 5).

---

## 5. Bestandsaufnahme vom 25.10.2026 (Lücken im Katalog)

**Methode** (`python3 -I Tools/rules/inventory.py Packages/SwabrCore/Sources/SwabrCore/Resources/clean_rules.json inventory.tsv`): Alle Regelmuster und die dynamischen Werkzeug-Caches wurden auf den echten Benutzerordner angewendet. Danach wurden alle Ordner gesucht, die nach Cache, Log, Temp oder Update heißen (unter `~/Library/*` und `~/.*`), aber von keiner Regel erfasst werden. Gemeldet ist alles ab 20 MB.

Ergebnis: **9 230 abgedeckte Pfade, 22 Lücken**.

| Größe | Pfad | Bewertung | Vorschlag |
|---|---|---|---|
| ≈ 4,1 GB (15 Ordner) | `~/Library/Containers/com.apple.Safari.WebApp/Data/Library/Containers/com.apple.Safari.WebApp.<UUID>/Library/Caches` | Web-Cache der Safari-Web-Apps („Zum Dock hinzufügen“). Die Container liegen verschachtelt, deshalb erreicht sie weder „macOS-Caches“ noch die Sammelregel. | Eigene Regel in `browsers`. *Prüfen*, bis geklärt ist, unter welchem Prozessnamen die Web-Apps laufen; danach mit `skipIfRunning` auf *Sicher*. |
| 325 MB | `~/Library/Application Support/Evernote/resource-cache` | Offline-Kopien von Anhängen. Werden neu geladen, aber nur mit Internet. | `apps`, `cache`, `safety: review`, `skipIfRunning: Evernote` |
| 135 MB | `~/Library/Application Support/BambuStudioBeta/log` | Log-Ordner in Kleinschreibung (Einzahl), die Sammelregel kennt nur `logs`/`Logs`. | Sammelregel „App-Protokolle“ auf `{log,logs,Logs}` erweitern |
| 80 MB | `~/.codex/plugins/cache` | Plugin-Downloads von Codex | `developer`, `cache`, `skipIfRunning: Codex` |
| 54 MB | `~/Library/Group Containers/UBF8T346G9.com.microsoft.teams/Library/Application Support/Logs` | Logs in Gruppen-Containern sind noch nicht erfasst. | `app_caches`, `log`: `~/Library/Group Containers/*/Library/{Logs,Application Support/Logs,Application Support/logs}/*`, Apple ausgenommen (`group.com.apple.*`, `*.com.apple.*`) |
| 51 MB | `~/.pcloud/temp` | Temp-Ordner von pCloud Drive, kann ausstehende Uploads enthalten. | `apps`, `temp`, `safety: review`, `skipIfRunning: pCloud Drive` |
| 27 MB | `~/.cargo/registry/index/*/.cache` | Index-Cache von Cargo, wird neu geladen. | Regel „Cargo“ um `~/.cargo/registry/index/*/.cache/*` ergänzen |
| 22 MB | `~/Library/Application Support/asc.onlyoffice.ONLYOFFICE/data/cache` | Cache von ONLYOFFICE | `apps`, `cache`, `skipIfRunning: ONLYOFFICE` |

Umgesetzt in `make_rules.py` (M-11). Die Safari-Web-Apps sind *Sicher*, weil `skipRunningOwner` jede laufende Web-App erkennt. Ursprünglicher Vorschlag:
```python
# Safari web apps ("Add to Dock") keep one container each, nested inside the shared WebApp container.
rule("browsers", "Safari-Web-Apps", "browserCache",
     ["~/Library/Containers/com.apple.Safari.WebApp/Data/Library/Containers/com.apple.Safari.WebApp.*/Library/Caches/*"],
     safety="review")
rule("apps", "Evernote", "cache", ["~/Library/Application Support/Evernote/resource-cache/*"],
     skipIfRunning="Evernote", safety="review")
rule("apps", "pCloud Drive", "temp", ["~/.pcloud/temp/*"], skipIfRunning="pCloud Drive", safety="review")
rule("apps", "ONLYOFFICE", "cache", ["~/Library/Application Support/asc.onlyoffice.ONLYOFFICE/data/cache/*"],
     skipIfRunning="ONLYOFFICE")
rule("developer", "Codex", "cache", ["~/.codex/cache/*", "~/.codex/plugins/cache/*"], skipIfRunning="Codex")
# Cargo: add to the existing rule
#   "~/.cargo/registry/index/*/.cache/*"
# App-Protokolle: {logs,Logs} -> {log,logs,Logs}, plus group containers:
rule("app_caches", "App-Protokolle", "log",
     ["~/Library/Group Containers/*/Library/{Logs,Application Support/Logs,Application Support/logs}/*"],
     exclude=["~/Library/Group Containers/group.com.apple.*", "~/Library/Group Containers/*.com.apple.*"])
```
Neue deutsche Schlüssel („Safari-Web-Apps“) brauchen Übersetzungen in den Katalogen (Tools/i18n).

---

## 6. Maßnahmen

| Nr. | Prio | Schicht | Maßnahme | Ort |
|---|---|---|---|---|
| ✅ M-01 | erledigt | S3 | Steuerzeichen (`\0`, `\n`, `\r`, ESC, alle < 0x20 und 0x7F) im Pfad ablehnen, Grund „Pfad enthält Steuerzeichen“ | `PathSafety.check` |
| ✅ M-02 | erledigt | S5 | Vor dem Löschen die besitzende App erneut prüfen (`CleanScanner.owners` + `RunningApps.snapshot()`), ebenso `skipIfRunning` der Regel. Dafür `CleanItem` um die Regelbedingung ergänzen. | `Cleaner.clean`, `CleanItem` |
| ✅ M-03 | erledigt | S4 | „Nie aufräumen“ speichert die **Muster der Regel** statt der Einzelpfade, damit auch künftige Treffer geschützt sind. Bei Sammelregeln: den Treffer-Elternordner + `/*`. | `CleanModel.protect` |
| ✅ M-05 | erledigt | S7 | root-Skript mit eigener Prüfung: für jeden Pfad `[ ! -L ]`, physischen Elternordner vergleichen (`cd -P`, `pwd -P`), erlaubte Wurzel per `case`, `..` und Zeilenumbruch ablehnen, erst dann `mv`. Test: Symlink-Tausch zwischen Scan und Ausführung. | `Uninstaller.moveAsAdmin`, `removeSystemFiles`, `StartupItems` (verwaiste Systemdienste) |
| ✅ M-06 | erledigt | S8 | `Leftover.evidence` (`identity`/`nameOnly`). Reine Namenstreffer sind nie vorausgewählt und werden in der Oberfläche markiert. | `LeftoverFinder.find`, `Leftover.preselected`, `UninstallModel`, `UninstallView` |
| ✅ M-06b | erledigt | S8 | Paketbelege über `pkgutil --pkgs`/`--files` als starker Beleg für Systemdateien | `LeftoverFinder.systemCandidates` |
| ✅ M-10 | erledigt | S9 | Startobjekte von Sicherheits-, MDM- und VPN-Herstellern sowie Swabrs eigene als „Geschützt“ markieren: Blockieren nur nach Warnung, kein Entfernen. Quelle: `officialUninstallerRules` + `sensitiveBundles`, Abgleich nur als ganze Wörter. | `StartupItem.policy` |
| ✅ M-11 | erledigt | S1 | Lücken aus Abschnitt 5 aufnehmen und Übersetzungen ergänzen | `make_rules.py`, Tools/i18n |
| ✅ M-04 | erledigt | S4 | Namensregel „Nie aufräumen: alle Ordner namens X“ (Whitelist-Muster `*/X` bzw. `*/X/*`) und „Rückgängig“ direkt in der Liste | `CleanView`, `CleanModel` |
| ✅ M-07 | erledigt | S2 | Test: keine Regel setzt `safety: "safe"` bei einer Art, deren Standard *Prüfen* ist. Pflicht-*Prüfen* für die Sammelregeln aus S2 per Test festhalten. | `ImpactTests.swift` |
| ✅ M-09 | erledigt | S6 | Feste Gründe als Enum (`whitelist, protectedPath, running, permission, missing, failed`) statt Freitext, Ergebnisansicht danach gruppieren | `ProtectedPath`, `CleanView` |
| ✅ M-08 | erledigt | S2 | Gesperrte Treffer zählen und dezent zeigen („3 geschützte Orte übersprungen“), Einstufung *Hinweis* in der Oberfläche als eigene Gruppe „Selbst verwalten“ | `CleanScanner`, `CleanView` |

Alle Maßnahmen sind am 25.10.2026 erledigt. Tests stehen in `SafetyTests.swift` und `ImpactTests.swift`; 97 Tests sind grün, beide Varianten bauen. Neue Lücken kommen als neue M-Nummern dazu.

---

## 7. Pflege dieses Dokuments

- Jede Änderung an Regeln oder Schutzlogik aktualisiert den zugehörigen Ist-Stand hier und setzt die Maßnahme auf ✅.
- Die Bestandsaufnahme (Abschnitt 5) wird bei größeren Katalogänderungen wiederholt.

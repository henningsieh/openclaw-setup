# Fehlerbericht: Browser- und Preisverifikation

**Datum:** 2026-09-25 (Europe/Berlin)  
**Zweck:** Weitergabe an den Systemadministrator-Agent  
**Auswirkung:** Preise und Packungsgrößen der Seed-Händlerangebote konnten in der letzten Recherche nicht vollständig und zuverlässig verifiziert werden. Die betroffene Tabelle ist daher kein belastbarer vollständiger Preisvergleich.

## Kurzfassung

Das OpenClaw-Browser-Tool ist aktiviert und erreichbar, aber sein verwaltetes Chromium kann nicht gestartet werden, weil kein unterstütztes Browser-Binary erkannt wird. Der aktuelle `browser doctor` meldet `No Chromium executable detected`; Statuswerte sind `running=false`, `chosenBrowser=null` und `executablePath=null`. Die vorangegangenen Produktseiten-Aufrufe scheiterten mit `No supported browser found` / `executablePath: null`.

Die Websuche war davon getrennt ebenfalls unzuverlässig: In der vorangegangenen Sitzung wurden **13 Suchaufrufe, davon 11 fehlgeschlagen**, angezeigt. `web_search` und `web_fetch` sind im OpenClaw-Toolkatalog vorhanden; ihre bloße Verfügbarkeit belegt nicht, dass alle Händlerseiten oder Varianten erfolgreich extrahiert werden können.

## Aktuelle Bestandsaufnahme

| Komponente | Befund | Beleg |
|---|---|---|
| OpenClaw Browser-Plugin | Aktiviert | `browser doctor`: `plugin-enabled: pass` |
| Browser-Profil/Transport | Profil `openclaw`, Transport `cdp` | `browser doctor` / `browser status` |
| Chromium/Chrome-Binary | Nicht erkannt; `executablePath=null` | `browser doctor`: `managed-executable: warn`, `No Chromium executable detected` |
| Browser-Prozess/CDP | Läuft nicht; nicht startbar bis Binary verfügbar ist | `running=false`, `cdpReady=false`, `chosenBrowser=null` |
| Browser-Pakete im aktuellen Shell-Kontext | `chromium`, `chromium-browser`, `google-chrome`, `google-chrome-stable`, `firefox`, `firefox-esr` nicht im `PATH`; Firefox-Pakete als `not-installed` | Lokale `command -v`- und `dpkg-query`-Prüfung am 2026-09-25 |
| OpenClaw `web_search` / `web_fetch` | Werkzeuge im Toolkatalog vorhanden | Aktueller OpenClaw-Toolkatalog; kein Erfolgsnachweis für Händlerseiten |

## Benötigte Maßnahmen / Anforderungen

1. **Auf dem tatsächlichen OpenClaw-Gateway-Host** ein von der installierten OpenClaw-Version unterstütztes Chrome-/Chromium-Binary installieren (oder ein bereits vorhandenes Binary identifizieren). Der Pfad muss für den Gateway-Servicebenutzer `shelldon` ausführbar sein.
2. Wenn das Binary nicht automatisch erkannt wird, den absoluten Pfad in der OpenClaw-Browserkonfiguration als `browser.executablePath` setzen. Konfiguration nur nach Prüfung der installierten Version und des relevanten Runbooks ändern.
3. Sicherstellen, dass der Gateway-Service in seiner Linux-Umgebung den verwalteten Browser headless starten darf. `browser doctor` hat bereits den Headless-Modus als passend ausgewählt (`Linux no-display fallback selected headless mode`). Kein Desktop/GUI ist für diesen headless-Use-Case laut aktuellem Doctor-Befund nicht die Blockade.
4. Danach `openclaw browser doctor` und `openclaw browser status` erneut ausführen und einen einzelnen Browserstart sowie das Öffnen/Lesen einer Händler-Produktseite prüfen. Erwartung: erkanntes Binary, `chosenBrowser`/`executablePath` belegt, `running=true` nach Start und CDP erreichbar.
5. Für die eigentliche Preistabelle pro Angebot **Preis und Stückzahl derselben auswählbaren Variante** aus der Produktseite belegen; erst dann `EUR/Seed = Preis ÷ Stückzahl` berechnen. Bei dynamisch gerenderten Seiten Browser-Automation verwenden; `web_fetch`-Ausgaben nicht als vollständig ansehen, falls Varianten/Preisoptionen fehlen.

## Nicht als Voraussetzung belegt

- Es gibt derzeit keinen Befund, dass zusätzliche Python-, Node.js-, Selenium-, Playwright- oder Puppeteer-Pakete erforderlich sind. Der OpenClaw-Browser-Doctor verlangt konkret ein unterstütztes Chrome-/Chromium-/Brave-/Edge-Binary oder einen gesetzten `browser.executablePath`; erst nach Installation wäre ein weiterer Fehler Anlass, zusätzliche Abhängigkeiten zu prüfen.
- Es wurde keine Gateway-Konfiguration geändert und kein Browser installiert.

## Reproduzierbare Meldung

```text
Browser plugin: enabled
Profile: openclaw via cdp
Chromium executable: No Chromium executable detected
Fix hint: Install Chrome/Chromium/Brave/Edge or set browser.executablePath.
Browser status: running=false, cdpReady=false, chosenBrowser=null,
                detectedExecutablePath=null, executablePath=null
```

**Abgrenzung:** Die Paketprüfung lief in der aktuellen Agent-Shell. Der Doctor-Status bezieht sich auf das konfigurierte OpenClaw-Browserprofil. Vor einer Installation bitte sicherstellen, dass Shell und Gateway auf demselben Host bzw. in derselben Runtime-Umgebung laufen.

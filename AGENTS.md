# AGENTS.md

## Kommunikation
- Kurz und knapp antworten.

## Projektkontext
- Shiny-App "Berliner Badestellen - Thematische Karte zur Erreichbarkeit".
- App befindet sich in der Entwicklung
- Hauptdatei: app.R (drei zentrale Teile: UI, Karten-Server, Sidebars pro Tab).
- Tabs (`tabsetPanel(id = "map_tab")`): `start`, `karte` (interaktive Karte), `ranking` (Ortsteil-Tabelle), `lakes` (Badestellen-Tabelle), `meta` (Metadaten & Methodik).

## Datenherkunft
- Die App lädt `data/shiny_data.RData` (enthält die `shiny_*`-Objekte wie `shiny_ortsteile`, `shiny_lakes`, `shiny_iso_rings` usw.).
- Alle Pipeline-Skripte liegen in diesem Projekt unter `scripts/`. Reihenfolge: `1_data_preparation.R` (WFS-Download) → `1_explore_bezirke_pop.R` (optionale Exploration) → `2_get_isochrones_all.R` (ORS-API – nicht ohne Absprache laufen lassen) → `3_analysis_a.R` → `3_analysis_b.R` → `3_analysis_c.R` (Gravity-Modell) → `4_prepare_final_shiny_data.R` (schreibt direkt nach `data/shiny_data.RData`) → `5_make_www_plots.R` (erzeugt alle drei www-PNGs neu).
- Nur noch EIN Datenordner: `data/` (ehemaliges `data_new/` ist aufgelöst). Kein manuelles Kopieren von `shiny_data.RData` mehr nötig.
- Lokales Backup des Re-Run-Vergleichs: `data/_backup_2026-09-13/` (nicht versioniert) — kann nach Sichtung gelöscht werden.
- Manuelle, nicht per Skript erzeugte Eingaben in `data/`: `lakes_new.gpkg` (QGIS-bereinigte Badestellenpunkte), `berlin_waters.gpkg` (OSM/Overpass-Wasserflächen), `einwohnerzahlen.csv` (amtliche Bezirks-EW). Diese drei plus `2_isochrones_all.RData` (eingefrorener ORS-API-Ergebnisstand) sind per `.gitignore`-Ausnahme **versioniert** — ohne sie kann niemand die Pipeline nachrechnen. `lakes_new.gpkg` ist die kanonische Quelle der Badestellenpunkte: Skript 1 bettet sie zusätzlich in `1_processed_data.RData` ein, 3b/3c lesen sie direkt.
- Skript 2 liest den ORS-Key aus `.Renviron` (`ORS_API_KEY`, neben `STADIA_MAPS_API_KEY`); die alte Klartext-Datei ist gelöscht. Resume: schon geholte Isochronen in `data/2_isochrones_all.RData` werden beim Re-Run übersprungen.
- Die Skripte enthalten kein `rm(list=ls())` mehr — jedes Skript lädt alle Eingaben selbst aus Dateien; 3a → 3b → 3c → 4 → 5 laufen daher in einer einzigen R-Session durch.

## Metadaten-Dokumentation
- `notes/Metadaten_Methodik.md` ist die Arbeitsfassung für den Tab `meta` ("Metadaten & Methodik"). Die Nutzerin bearbeitet diese Datei extern und ergänzt sie; der Stand wird später in die App übernommen.
- Die Datei spiegelt bewusst die Gliederung der App: `# Metadaten`, `# Umsetzung & Code`, `# Methodik`, jeweils mit denselben Unterüberschriften. Übernahme 1:1: Markdown-Überschrift → `h4()`, Absatz → `p()`, `**fett**` → `strong()`, Link → `a(href = ..., target = "_blank")`, die `---`-Linien entsprechen den `hr()`-Trennern.
- Ausnahme beim Übernehmen: Das "Datum der letzten Aktualisierung" steht in der Datei fest, in der App kommt es aus `Sys.Date()`.
- Die Datei ist reine Arbeitsgrundlage und hat keine technische Verbindung zur App; sie kann verschoben werden.

## Wichtige App-Fakten
- Travel-Mode-Umschaltung (Fahrrad/Fuß) als Radio-Buttons `map_mode` im statischen Kopf der linken Sidebar des Karten-Tabs; die Werte `cycling-regular`/`foot-walking` liegen in `shiny_lakes`/`shiny_iso_rings` vor. Zentraler Helper `sel_mode()`: außerhalb des Tabs `karte` immer `cycling-regular`.
- Daneben `actionButton("reset_map")` ("Ansicht zurücksetzen"): setzt Auswahl, beide Dropdowns und `map_mode` auf den Erst-Ladezustand zurück und erhöht `reset_key()`, das als Dependency in `renderTmap` ein Neu-Rendern des Widgets erzwingt.
- Der Modus wirkt damit auf die Karte und die linke Ortsteil-Sidebar; Ortsteil-Tabelle und Challenges bleiben modus-unabhängig (C1/C2 fix Fahrrad, C3/C4 fix zu Fuß, C5 beide).
- Sidebars: links pro Tab via `conditionalPanel(input$map_tab)` – Willkommenstext (start); im Karten-Tab ein statischer Kopf (Überschrift, `map_mode`, Reset-Button), darunter `uiOutput("sidebar_content")` mit Bezirks-`selectInput("bezirk_select")`, nach Bezirk gefiltertem Ortsteil-`selectInput("ortsteil_select")` und dem Detailbereich darunter (`implied_selection()` synchronisiert Karten-Klicks und Dropdowns in beide Richtungen); `ranking_sidebar`, `lakes_sidebar`, statische Meta-Outline (meta). Rechts im Karten-Tab nur noch die Box mit `iso_sidebar` (Iso-Ring-Bevölkerung + Top-3-Ranking).
- Klick-Logik: Bezirke haben eine eigene ID `B_<nr>` (`bezirk_click`, damit Namensgleichheit wie "Mitte" nicht als Ortsteil-Klick gilt), Ortsteile `id = "ortsteil"`, Badestellen `id = "lake_id"` (wird erst beim Laden aus Zeilennummer + "c"/"w" gebaut). Badestellen-Klicks öffnen nur ein Popup, keine Sidebar-Info.
- tmap kodiert Leerzeichen und Bindestriche in Feature-IDs als Unterstriche – beim Klick-Rückauflösen `gsub("[^[:alnum:]]", "_", ...)` verwenden.
- Basemaps: `basemap_layer()` nutzt Stadia (AlidadeDark/AlidadeSmooth/OSMBright) mit `STADIA_MAPS_API_KEY` aus `.Renviron`, sonst Fallback auf CartoDB/OSM.
- Statische Assets liegen in `www/`: Banner-Foto und zwei Kartenbilder (Start-Tab) sowie `plot_lakes_ew.png` (Hilfsdiagramm im Badestellen-Tab). Alle drei Karten/Diagramme erzeugt `scripts/5_make_www_plots.R` direkt nach `www/` – nach einem Daten-Neubau neu ausführen. In der App öffnen der Button "Diagramm in neuem Fenster öffnen" und die Miniatur-Vorschau das Bild per `window.open` in einem eigenen Fenster (1200×950), damit die Badestellen-Namen lesbar sind.
- Ortsteil-Tabelle: Prozentwerte und EW/ha auf 1, Flächen auf 2 Nachkommastellen gerundet (konsistent zur Sidebar), Rundungshinweis über der Tabelle.
- Badestellen-Tabelle: beide Modi nebeneinander (Rang, zugerechnete EW in % und absolut; Bezug 3.913.490 EW); 2 der 39 Badestellen haben zu Fuß keinen Rang.

## Bekannte Stolperfallen
- Editor-Puffer vs. Disk: Nach Assistant-Edits kann der Editor-Puffer veraltet sein (Symptom: widersprüchliche Meldungen wie "String not found" trotz vorhandener Zeile). Disk-Stand verifizieren, z. B. mit parse("app.R"). Vor manuellen Änderungen im Editor: Datei neu laden (File -> Reload from Disk), sonst überschreibt Speichern die Fixes.
- Windows-Datei-Sperre: Läuft die Shiny-App, hält sie app.R gesperrt – Änderungen an der Datei schlägen dann fehl oder korrumpieren sie (Symptom: "The process cannot access the file ..."). Deshalb: App stoppen, bevor Änderungen beginnen; Assistant prüft die Schreibbarkeit der Datei vorab.

## Connect Cloud & Locale (Deploy über GitHub)
- Deploy-Weg: Live-App läuft auf Posit Connect Cloud und wird aus dem GitHub-Repo gebaut (remote `ivonne286/BerlinerBadestellen_ShinyApp`, Branch `main`, committete `manifest.json` via GitHub-Publishing). Code-Änderungen wirken online erst nach Commit + push (ggf. zusätzlich Rebuild im Content-Dashboard anstoßen).
- Locale-Bug (aufgetreten & behoben 2026-09-14, Commit 9cba304): manifest.json enthielt `"locale": "en_DE"` — ein Windows-Pseudo-Locale, das auf Ubuntu nicht existiert. Der R-Prozess fiel auf C/ASCII zurück. Symptome online: DT-Warnungen wegen Umlaut-Spaltennamen ("Rang (zu Fuß)" / "Fläche (km²)" not found), Dropdowns zeigten `<U+2013> keine Auswahl <U+2013>`, Dropdown- und `map_mode`-Reaktivität tot (Vergleiche wie `shiny_bezirke$bezirk == input$bezirk_select` matchen nicht; Kartenklicks funktionierten, weil sie über ASCII-IDs laufen). Lokal unauffällig, da R >= 4.2 auf Windows nativ UTF-8 nutzt.
- Fix (zweigleisig): `"locale": "C.UTF-8"` in manifest.json + Locale-Guard ganz oben in app.R vor allen `library()`-Aufrufen (`if (!l10n_info()$`UTF-8`) Sys.setlocale(locale = "C.UTF-8")`, danach `message("Locale: ", Sys.getlocale())` für die Server-Logs). Guard ist lokal ein No-Op.
- **Stolperfalle bei jedem künftigen `rsconnect::writeManifest()`**: Es schreibt das locale-Feld aus der aktuellen Windows-Session wieder ("en_DE" o. ä.) → danach `"locale": "C.UTF-8"` manuell im Manifest überschreiben, sonst droht der Bug zurück. writeManifest auch nicht durch vorheriges `Sys.setlocale()` auf Linux-Locales "faken" — Hand-Edit ist der robuste Weg.
- Diagnose, falls Online-Bugs mit Umlauten wieder auftauchen: In den Connect-Cloud-Logs die Zeile `Locale: ...` prüfen. Steht dort eine UTF-8-Locale und die Bugs bleiben → Locale-These falsch, neu analysieren. Reservelösung: Umlaute/En-Dash aus Spaltennamen und choices verbannen ("Rang (zu Fuss)", "Flaeche (km2)", Bindestrich statt Gedankenstrich) — funktioniert in jeder Locale.
- Alle `format()`-Aufrufe in app.R nutzen explizite `decimal.mark`/`big.mark` und sind damit locale-unabhängig; der Locale-Guard hat darauf keine Nebenwirkungen.

## Git & Line-Endings (LF-Setup)
- Repo ist vollständig auf LF: `.gitattributes` im Root mit `* text=auto eol=lf` (plus `*.RData`, `*.rds`, `*.gpkg`, `*.shp` usw. als `binary`); committet in d31b093.
- Hintergrund: Git-for-Windows-Standard `core.autocrlf=true` verursachte den CRLF-Ärger. Repo-lokal ist jetzt `core.autocrlf=false` gesetzt; maßgeblich ist die `.gitattributes`.
- RStudio-Einstellung für neue Dateien: Tools -> Global Options -> Code -> Saving -> Line end conversion = "Posix (LF)".
- git hat keine konfigurierte Identity (user.name/user.email leer). Commits aus dem Code daher mit `-c user.name=ivonne286 -c user.email=ivonne.giske@posteo.net` (Identität des letzten Commits) oder Commit im RStudio-Git-Pane.
- Falls git eine Textdatei als "binary" behandelt: auf doppelte CRs (`\r\r\n`) prüfen – war bei AGENTS.md der Fall und ist bereinigt (bedad9f).

## Regeln
- Diese Datei liegt im Projekt-Root und wird von Posit Assistant automatisch als Projektkontext geladen.
- Keine Dateien ohne vorherige Freigabe ändern – vor jeder Änderung nachfragen.
- `notes/TODO.txt` wird hauptsächlich von Nutzerin gepflegt. Der Assistant vermerkt erledigte Aufgaben nicht selbst, sondern fragt bei Bedarf nach.

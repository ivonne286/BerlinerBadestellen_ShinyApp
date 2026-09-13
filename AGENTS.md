# AGENTS.md

## Kommunikation
- Kurz und knapp antworten.

## Projektkontext
- Shiny-App "Berliner Badestellen - Thematische Karte zur Erreichbarkeit".
- App befindet sich in der Entwicklung
- Hauptdatei: BerlinLakeAccess_ShinyApp.R (drei zentrale Teile: UI, Karten-Server, Sidebars pro Tab).
- Tabs (`tabsetPanel(id = "map_tab")`): `start`, `karte` (interaktive Karte), `ranking` (Ortsteil-Tabelle), `lakes` (Badestellen-Tabelle), `meta` (Metadaten & Methodik).

## Datenherkunft
- Die App lädt `data/shiny_data.RData` (enthält die `shiny_*`-Objekte wie `shiny_ortsteile`, `shiny_lakes`, `shiny_iso_rings` usw.).
- Die Daten werden erzeugt im Data-Prep-Skript:
  `Projekt_Badegewaesser_Berlin/scripts/4_prepare_final_shiny_data.R`
- Nach dem Neu-Bauen des Skripts wird die Datei `data_new/shiny_data.RData` aus dem Prep-Projekt in das `data/`-Verzeichnis dieser Shiny-App kopiert.

## Metadaten-Dokumentation
- `Metadaten_Methodik.md` im Projekt-Root ist die Arbeitsfassung für den Tab `meta` ("Metadaten & Methodik"). Die Nutzerin bearbeitet diese Datei extern und ergänzt sie; der Stand wird später in die App übernommen.
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
- Statische Assets liegen in `www/`: Banner-Foto und zwei Kartenbilder (Start-Tab) sowie `plot_lakes_ew.png` (Hilfsdiagramm im Badestellen-Tab). Erzeugt wird es von `scripts/make_lakes_plot.R` (lädt `data/shiny_data.RData`, gruppierte Balken je Badestelle nach Mobilitätsmodus, sortiert nach Fahrrad-Wert, `ggsave` nach `www/`) – nach einem Daten-Neubau neu ausführen. In der App öffnen der Button "Diagramm in neuem Fenster öffnen" und die Miniatur-Vorschau das Bild per `window.open` in einem eigenen Fenster (1200×950), damit die Badestellen-Namen lesbar sind.
- Ortsteil-Tabelle: Prozentwerte und EW/ha auf 1, Flächen auf 2 Nachkommastellen gerundet (konsistent zur Sidebar), Rundungshinweis über der Tabelle.
- Badestellen-Tabelle: beide Modi nebeneinander (Rang, zugerechnete EW in % und absolut; Bezug 3.913.490 EW); 2 der 39 Badestellen haben zu Fuß keinen Rang.

## Bekannte Stolperfallen
- Editor-Puffer vs. Disk: Nach Assistant-Edits kann der Editor-Puffer veraltet sein (Symptom: widersprüchliche Meldungen wie "String not found" trotz vorhandener Zeile). Disk-Stand verifizieren, z. B. mit parse("BerlinLakeAccess_ShinyApp.R"). Vor manuellen Änderungen im Editor: Datei neu laden (File -> Reload from Disk), sonst überschreibt Speichern die Fixes.
- Windows-Datei-Sperre: Läuft die Shiny-App, hält sie BerlinLakeAccess_ShinyApp.R gesperrt – Änderungen an der Datei schlägen dann fehl oder korrumpieren sie (Symptom: "The process cannot access the file ..."). Deshalb: App stoppen, bevor Änderungen beginnen; Assistant prüft die Schreibbarkeit der Datei vorab.

## Git & Line-Endings (LF-Setup)
- Repo ist vollständig auf LF: `.gitattributes` im Root mit `* text=auto eol=lf` (plus `*.RData`, `*.rds`, `*.gpkg`, `*.shp` usw. als `binary`); committet in d31b093.
- Hintergrund: Git-for-Windows-Standard `core.autocrlf=true` verursachte den CRLF-Ärger. Repo-lokal ist jetzt `core.autocrlf=false` gesetzt; maßgeblich ist die `.gitattributes`.
- RStudio-Einstellung für neue Dateien: Tools -> Global Options -> Code -> Saving -> Line end conversion = "Posix (LF)".
- git hat keine konfigurierte Identity (user.name/user.email leer). Commits aus dem Code daher mit `-c user.name=ivonne286 -c user.email=ivonne.giske@posteo.net` (Identität des letzten Commits) oder Commit im RStudio-Git-Pane.
- Falls git eine Textdatei als "binary" behandelt: auf doppelte CRs (`\r\r\n`) prüfen – war bei AGENTS.md der Fall und ist bereinigt (bedad9f).

## Regeln
- Keine Dateien ohne vorherige Freigabe ändern – vor jeder Änderung nachfragen.
- `TODO.txt` wird hauptsächlich von Nutzerin gepflegt. Der Assistant vermerkt erledigte Aufgaben nicht selbst, sondern fragt bei Bedarf nach.

# AGENTS.md

## Kommunikation
- Kurz und knapp antworten.

## Projektkontext
- Shiny-App "Bathing Sites in Berlin": Ungleicher Zugang zu Badestellen und potenzielle Nachfrage.
- App befindet sich in der Entwicklung – Karten-Design wird noch erkundet und kann sich ändern.
- Hauptdatei: BerlinLakeAccess_ShinyApp.R (drei zentrale Teile: UI, Karten-Server, Sidebars pro Tab).

## Datenherkunft
- Die App lädt `data/shiny_data.RData` (enthält die `shiny_*`-Objekte wie `shiny_ortsteile`, `shiny_lakes`, `shiny_iso_rings` usw.).
- Die Daten werden erzeugt im Data-Prep-Skript:
  `Projekt_Badegewaesser_Berlin/scripts/4_prepare_final_shiny_data.R`
- Nach dem Neu-Bauen des Skripts wird die Datei `data/shiny_data.RData` aus dem Prep-Projekt in das `data/`-Verzeichnis dieser Shiny-App kopiert.

## Wichtige App-Fakten
- Travel-Mode-Umschaltung (Fahrrad/Fuß) als Radio-Buttons oberhalb der Karte; der Wert `input$mode` liegt in `shiny_lakes`/`shiny_iso_rings` als `cycling-regular` bzw. `foot-walking` vor. Wirkt nur auf die Karten-Tabs (map1/map2); Ortsteil-Tabelle und Challenges sind modus-unabhängig (C1/C2 fix Fahrrad, C3/C4 fix zu Fuß, C5 beide).
- Sidebar ist pro Tab getrennt (map1: Ortsteil-Infos; map2: Iso-Ring-Bevölkerung); Anzeige über `conditionalPanel(input$map_tab)`.
- tmap kodiert Leerzeichen und Bindestriche in Feature-IDs als Unterstriche – beim Klick-Rückauflösen `gsub("[^[:alnum:]]", "_", ...)` verwenden.
- Ortsteil-Tabelle: Prozentwerte auf 1 Nachkommastelle gerundet (konsistent zur map1-Sidebar), Rundungshinweis über der Tabelle.

## Bekannte Stolperfallen
- Editor-Puffer vs. Disk: Nach Assistant-Edits kann der Editor-Puffer veraltet sein (Symptom: widersprüchliche Meldungen wie "String not found" trotz vorhandener Zeile). Disk-Stand verifizieren, z. B. mit parse("BerlinLakeAccess_ShinyApp.R"). Vor manuellen Änderungen im Editor: Datei neu laden (File -> Reload from Disk), sonst überschreibt Speichern die Fixes.
- Windows-Datei-Sperre: Läuft die Shiny-App, hält sie BerlinLakeAccess_ShinyApp.R gesperrt – Änderungen an der Datei schlägen dann fehl oder korrumpieren sie (Symptom: "The process cannot access the file ..."). Deshalb: App stoppen, bevor Änderungen beginnen; Assistant prüft die Schreibbarkeit der Datei vorab.

## Regeln
- Keine Dateien ohne vorherige Freigabe ändern – vor jeder Änderung nachfragen.

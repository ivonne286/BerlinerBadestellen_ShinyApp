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
- Travel-Mode-Umschaltung (Fahrrad/Fuß) als Radio-Buttons oberhalb der Karte; der Wert `input$mode` liegt in `shiny_lakes`/`shiny_iso_rings` als `cycling-regular` bzw. `foot-walking` vor.
- Sidebar ist pro Tab getrennt (map1: Ortsteil-Infos; map2: Iso-Ring-Bevölkerung); Anzeige über `conditionalPanel(input$map_tab)`.
- tmap kodiert Leerzeichen und Bindestriche in Feature-IDs als Unterstriche – beim Klick-Rückauflösen `gsub("[^[:alnum:]]", "_", ...)` verwenden.

## Regeln
- Keine Dateien ohne vorherige Freigabe ändern – vor jeder Änderung nachfragen.

# Berliner Badestellen – Thematische Karte zur Erreichbarkeit

Interaktive Shiny-App, die analysiert, wie viele Berliner Einwohner*innen eine
offizielle Badestelle innerhalb von 5/10/20 Minuten erreichen können — mit
dem Fahrrad oder zu Fuß. Enthalten sind eine Isochronen-Karte, Rankings nach
Ortsteil und nach Badestelle sowie ein Tab mit Metadaten und Methodik.

## Repositorystruktur

- `app.R` — die komplette App (UI + Server), eine Datei
- `scripts/` — Datenpipeline (nummeriert, in dieser Reihenfolge ausführen)
- `data/` — Pipeline-Eingaben und -Ausgaben; nur die unten genannten Dateien
  sind versioniert
- `www/` — statische Assets der App (Bilder der Startseite, Hilfsdiagramm)

## App starten

- `app.R` in RStudio öffnen → **Run App**
  (oder `shiny::runApp("app.R")`)
- Ein Pipeline-Durchlauf ist nicht nötig — `data/shiny_data.RData` ist enthalten.

## Datenpipeline (`scripts/`)

| Schritt | Skript | Zweck |
|---|---|---|
| 1 | `1_data_preparation.R` | Lädt Berliner WFS-Daten herunter (Bezirke, Ortsteile, Bevölkerungsdichte), erzeugt Bevölkerungspunkte |
| 1e | `1_explore_bezirke_pop.R` | Optionale Exploration (Bevölkerungsstatistiken der Bezirke) |
| 2 | `2_get_isochrones_all.R` | Abruf von Reisezeit-Isochronen über die OpenRouteService-API — **benötigt API-Key, nicht beiläufig neu ausführen** |
| 3a | `3_analysis_a.R` | Erreichbarkeits-Statistiken je Ortsteil/Bezirk |
| 3b | `3_analysis_b.R` | Einzugsgebiete & Aufteilung nach Gleichanteilen je Badestelle |
| 3c | `3_analysis_c.R` | Gravity-Modell → Ranking der Badestellen |
| 4 | `4_prepare_final_shiny_data.R` | Baut `data/shiny_data.RData` |
| 5 | `5_make_www_plots.R` | Erstellt alle Bilder in `www/` neu (Hilfsdiagramm + zwei Startseiten-Karten) |

Die Schrittnummern entsprechen der Ausführungsreihenfolge — jedes Skript liest
die Ausgaben der vorherigen.

### Daten aus einem frischen Clone reproduzieren

1. `1_data_preparation.R` ausführen — lädt Berliner WFS-Daten herunter und
   schreibt `data/1_processed_data.RData`
2. **Schritt 2 überspringen** — die Isochronen sind bereits enthalten
   (`data/2_isochrones_all.RData`); nur mit eigenem `ORS_API_KEY` neu
   ausführen, wenn sie neu abgerufen werden sollen
3. `3_analysis_a.R` → `3_analysis_b.R` → `3_analysis_c.R` ausführen
   (in dieser Reihenfolge)
4. `4_prepare_final_shiny_data.R` ausführen — schreibt `data/shiny_data.RData`
5. `5_make_www_plots.R` ausführen — erneuert die Bilder in `www/`

Hinweise:

- `1_processed_data.RData` ist nicht Teil des Repos — Schritt 1 erzeugt sie
  neu (Internet erforderlich, aber kein API-Key)
- Jedes Skript lädt alle seine Eingaben aus Dateien; die Schritte 3–5 laufen
  daher sauber in einer einzigen frischen R-Session durch
- `1_explore_bezirke_pop.R` (Schritt 1e) ist eine optionale Exploration und
  für die App-Daten nicht erforderlich

## Im Repository enthaltene Datendateien

- `data/shiny_data.RData` — alle `shiny_*`-Objekte, die die App lädt
- `data/lakes_new.gpkg` — Zugangspunkte der Badestellen, in QGIS manuell
  bereinigt
- `data/lakes_original.gpkg` — ursprüngliche Badestellenpunkte aus dem
  WFS-Download, als Vergleichsgrundlage zur bereinigten Version
- `data/berlin_waters.gpkg` — Berliner Wasserflächen (OSM/Overpass)
- `data/2_isochrones_all.RData` — eingefrorener ORS-Isochronen-Ergebnisstand
- `data/einwohnerzahlen.csv` — amtliche Einwohner*innenzahlen auf
  Bezirksebene

## API-Keys (`.Renviron`)

Beide Keys liegen in einer `.Renviron`-Datei im Projekt-Root — diese Datei ist
git-ignoriert und muss daher selbst angelegt werden:

1. Eine Textdatei namens `.Renviron` im Projekt-Root anlegen
2. Pro Key eine Zeile ergänzen:
   `ORS_API_KEY=eigener_key` und/oder `STADIA_MAPS_API_KEY=eigener_key`
3. R neu starten (`.Renviron` wird nur beim Start gelesen)

- `STADIA_MAPS_API_KEY` — optional, für das Basemap-Styling; ohne ihn nutzt
  die App automatisch die freien CartoDB/OSM-Karten
- `ORS_API_KEY` — nur für die erneute Ausführung von Skript 2 (Isochronen)
  nötig; die App selbst läuft ohne ihn

## Abhängigkeiten

- App: `shiny`, `sf`, `dplyr`, `tmap`, `tmap.mapgl`, `DT`
- Pipeline zusätzlich: `tidyr`, `gstat`, `stars`, `ggplot2`, `tmap`,
  `openrouteservice`, `tidyverse`

## Datenquellen

- Berliner WFS-Dienste (gdi.berlin.de): Badestellen, ALKIS-Grenzen von Bezirken
  und Ortsteilen, Bevölkerungsdichte 2025
- OpenStreetMap via Overpass (Wasserflächen)
- Amtliche Einwohner*innenzahlen (Bezirksebene)

## Status

Die App befindet sich in Entwicklung — Methodendetails sind in der App
dokumentiert (Tab "Metadaten & Methodik"). Der Code ist auf GitHub
veröffentlicht; eine Live-App auf Posit Connect Cloud ist geplant.

## Kontakt

Ivonne Giske — [ivonne.giske@posteo.net](mailto:ivonne.giske@posteo.net)
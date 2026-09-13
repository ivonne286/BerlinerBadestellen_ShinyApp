# Berlin Bathing Sites – Thematic Accessibility Map

Interactive Shiny app analysing how many Berlin residents can reach an official
bathing site (Badestelle) within 5/10/20 minutes — by bike or on foot.
Includes an isochrone map, rankings by Ortsteil and by bathing site, and a
metadata & methods tab (German).

## Repository structure

- `BerlinLakeAccess_ShinyApp.R` — the complete app (UI + server), single file
- `scripts/` — data pipeline (numbered, run in order)
- `data/` — pipeline inputs/outputs; only the files below are tracked
- `www/` — static assets used by the app (start-page images, helper chart)

## Run the app

- Open `BerlinLakeAccess_ShinyApp.R` in RStudio → **Run App**
  (or `shiny::runApp("BerlinLakeAccess_ShinyApp.R")`)
- No pipeline run needed — `data/shiny_data.RData` is included.

## Data pipeline (`scripts/`)

| Step | Script | Purpose |
|---|---|---|
| 1 | `1_data_preparation.R` | Download Berlin WFS data (districts, Ortsteile, population density), build population points |
| 1e | `1_explore_bezirke_pop.R` | Optional exploration (district population stats) |
| 2 | `2_get_isochrones_all.R` | Fetch travel-time isochrones via OpenRouteService API — **needs API key, do not re-run casually** |
| 3a | `3_analysis_a.R` | Access statistics per Ortsteil/Bezirk |
| 3b | `3_analysis_b.R` | Catchment & equal-share allocation per bathing site |
| 3c | `3_analysis_c.R` | Gravity model → ranking of bathing sites |
| 4 | `4_prepare_final_shiny_data.R` | Build `data/shiny_data.RData` |
| 5 | `5_make_www_plots.R` | Recreates all images in `www/` (helper chart + two start-page maps) |

Step numbers = run order — each script reads the outputs of the previous ones.

### Reproducing the data from a fresh clone

1. Run `1_data_preparation.R` — downloads Berlin WFS data, writes
   `data/1_processed_data.RData`
2. **Skip step 2** — isochrones are already included
   (`data/2_isochrones_all.RData`); only re-run it with your own
   `ORS_API_KEY` if you want to refetch them
3. Run `3_analysis_a.R` → `3_analysis_b.R` → `3_analysis_c.R` (in this order)
4. Run `4_prepare_final_shiny_data.R` — writes `data/shiny_data.RData`
5. Run `5_make_www_plots.R` — refreshes the images in `www/`

Notes:

- `1_processed_data.RData` is not part of the repo — step 1 regenerates it
  (needs internet, but no API key)
- Each script loads all its inputs from files, so steps 3–5 run cleanly in a
  single fresh R session
- `1_explore_bezirke_pop.R` (step 1e) is optional exploration, not needed
  for the app data

## Data files included in the repository

- `data/shiny_data.RData` — all `shiny_*` objects the app loads
- `data/lakes_new.gpkg` — bathing site access points, manually corrected in QGIS
- `data/lakes_original.gpkg` — original bathing site points as downloaded from the WFS, for comparison with the corrected version
- `data/berlin_waters.gpkg` — Berlin water bodies (OSM/Overpass)
- `data/2_isochrones_all.RData` — frozen ORS isochrone results
- `data/einwohnerzahlen.csv` — official district population figures

## API keys (`.Renviron`)

Both keys live in a `.Renviron` file in the project root — this file is
git-ignored, so create your own:

1. Create a text file named `.Renviron` in the project root
2. Add one line per key:
   `ORS_API_KEY=your_key_here` and/or
   `STADIA_MAPS_API_KEY=your_key_here`
3. Restart R (`.Renviron` is only read at startup)

- `STADIA_MAPS_API_KEY` — optional, basemap styling; the app falls back to
  free CartoDB/OSM tiles without it
- `ORS_API_KEY` — only needed to re-run script 2 (isochrones); the app itself
  runs without it

## Dependencies

- App: `shiny`, `sf`, `dplyr`, `tmap`, `tmap.mapgl`, `DT`
- Pipeline additionally: `tidyr`, `gstat`, `stars`, `ggplot2`, `tmap`,
  `openrouteservice`, `tidyverse`

## Data sources

- Berlin WFS services (gdi.berlin.de): bathing sites, ALKIS district/Ortsteil
  boundaries, 2025 population density
- OpenStreetMap via Overpass (water bodies)
- Amtliche Einwohnerzahlen (district level)

## Status

Under development — method details are documented inside the app
(tab "Metadaten & Methodik"). Publication planned: GitHub (code) and
Posit Connect Cloud (live app).

## Contact

Ivonne Giske — [ivonne.giske@posteo.net](mailto:ivonne.giske@posteo.net)
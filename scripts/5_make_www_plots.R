### Skript 5: Plots für die Shiny-App (www/)
### Ivonne Giske
### Beginn: 01.07.2026
### Projekt: Berliner Badestellen – Thematische Karte zur Erreichbarkeit
### Modul: Thematische Internetkartografie
### Aufgabe: Erstellung einer thematischen, interaktiven Karte, browserfähig
###
### Erzeugt alle drei PNGs in www/:
###   1) plot_lakes_ew.png       – Hilfsdiagramm für den Tab "Badestellen-Tabelle"
###   2) start_map_shiny_cycle.png – Startkarte (Modus Fahrrad)
###   3) start_map_shiny_walk.png  – Startkarte (Modus zu Fuß)
###
### Ausführung aus dem Projekt-Root (RStudio-Projekt geöffnet):
###   source("scripts/5_make_www_plots.R")
###
### Neu ausführen, wenn sich die Daten in data/shiny_data.RData ändern –
### die PNGs sind Kopien der Werte und werden nicht automatisch nachgezogen.

library(sf)
library(dplyr)
library(tidyr)
library(ggplot2)
library(tmap)

load("data/shiny_data.RData")

### ________________________________________________
#   PLOT 1: Hilfsdiagramm Badestellen-Tabelle
#   zugerechnete Einwohner*innen je Badestelle, getrennt nach Mobilitätsmodus,
#   sortiert nach Größe (Fahrrad)
### ________________________________________________

# Bezugsgröße wie in der Badestellen-Tabelle der App
base_ew <- 3913490

pct_cyc <- shiny_lakes |>
  st_drop_geometry() |>
  filter(mode == "cycling-regular") |>
  select(lake_name, pct_cyc = pressure_share_pct)

pct_wlk <- shiny_lakes |>
  st_drop_geometry() |>
  filter(mode == "foot-walking") |>
  select(lake_name, pct_walk = pressure_share_pct)

plot_df <- pct_cyc |>
  left_join(pct_wlk, by = "lake_name") |>
  mutate(
    Fahrrad = pct_cyc / 100 * base_ew,
    `zu Fuß` = pct_walk / 100 * base_ew,
    # aufsteigende Faktorstufen: der größte Wert steht oben
    lake_name = factor(lake_name, levels = lake_name[order(Fahrrad)])
  ) |>
  # lange Form: ein Layer, damit die Balken sauber nebeneinander liegen
  pivot_longer(
    cols = c("zu Fuß", "Fahrrad"),
    names_to = "modus",
    values_to = "ew"
  ) |>
  mutate(modus = factor(modus, levels = c("zu Fuß", "Fahrrad")))

p_lakes_ew <- ggplot(plot_df, aes(x = lake_name, y = ew / 1000, fill = modus)) +
  geom_col(position = position_dodge(width = 0.8), na.rm = TRUE) +
  scale_fill_manual(values = c("zu Fuß" = "#18C93E", "Fahrrad" = "#8C4BBE")) +
  labs(
    y = "Zugerechnete Einwohner*innen in Tausend",
    x = "Badestellen",
    fill = NULL
  ) +
  theme_minimal(base_size = 12) +
  # flach geneigte Badestellen-Namen, damit sie sich nicht überlappen
  theme(axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1))

p_lakes_ew

ggsave(
  filename = "www/plot_lakes_ew.png",
  plot = p_lakes_ew,
  width = 14,
  height = 9,
  dpi = 150
)


### ________________________________________________
#   PLOT 2: Statische Startkarte für die Shiny-App (Modus Fahrrad)
### ________________________________________________

tmap_mode("plot")

lakes_cycling <- shiny_lakes |>
  filter(mode == "cycling-regular")

lakes_walking <- shiny_lakes |>
  filter(mode == "foot-walking")

start_map_cycle <-
  tm_shape(shiny_ew_density_raster) +
  tm_raster(
    col.scale = tm_scale_continuous_sqrt(values = "yl_or_rd"),
    col_alpha = 0.4,
    col.legend = tm_legend_hide()
  ) +

  tm_shape(shiny_ortsteile) +
  tm_borders(col = "indianred4", lwd = 0.75) +

  tm_shape(shiny_bezirke) +
  tm_borders(col = "darkslategrey", lwd = 1) +


  tm_shape(shiny_iso_unions_clipped |> filter(mode == "cycling-regular")) +
  tm_polygons(
    fill = "minutes",
    fill.scale = tm_scale_categorical(
      values = c(
        "5"  = "#8C4BBE",
        "10" = "#BC96D9",
        "20" = "#D9C3E9"
      )
    ),
    fill_alpha = 0.35,
    col = "#6a3ea0",
    lwd = 0.4,
    lty = "dashed"
  ) +

  tm_shape(shiny_water_background) +
  tm_polygons(fill = "cyan4", col = NA, fill_alpha = 1) +

  tm_shape(lakes_cycling) +
  tm_bubbles(
    size = "gravity_visual",
    tm_legend_hide(),
    fill = "cyan2",
    fill_alpha = 0.9,
    col = "darkslategrey",
    lwd = 0.6,
    size.scale = tm_scale_continuous(ticks = c(50, 150, 300))
  ) +


  tm_layout(
    legend.show = FALSE,
    frame = FALSE,
    bg.color = "ivory"
  )

start_map_cycle

tmap_save(
  start_map_cycle,
  filename = "www/start_map_shiny_cycle.png",
  width = 10,
  height = 8,
  dpi = 300,
  asp = 0
)


### ________________________________________________
#   PLOT 3: Statische Startkarte für die Shiny-App (Modus zu Fuß)
### ________________________________________________

start_map_walk <-
  tm_shape(shiny_ew_density_raster) +
  tm_raster(
    col.scale = tm_scale_continuous_sqrt(values = "yl_or_rd"),
    col_alpha = 0.4,
    col.legend = tm_legend_hide()
  ) +

  tm_shape(shiny_ortsteile) +
  tm_borders(col = "indianred4", lwd = 0.75) +

  tm_shape(shiny_bezirke) +
  tm_borders(col = "darkslategrey", lwd = 1) +


  tm_shape(shiny_iso_unions_clipped |> filter(mode == "foot-walking")) +
  tm_polygons(
    fill = "minutes",
    fill.scale = tm_scale_categorical(
      values = c(
        "5"  = "#18C93E",
        "10" = "#5BEC7A",
        "20" = "#A4F4B5"
      )
    ),
    fill_alpha = 0.35,
    col = "#0f7a2a",
    lwd = 0.4,
    lty = "dashed"
  ) +

  tm_shape(shiny_water_background) +
  tm_polygons(fill = "cyan4", col = NA, fill_alpha = 1) +

  tm_shape(lakes_walking) +
  tm_bubbles(
    size = "gravity_visual",
    tm_legend_hide(),
    fill = "cyan2",
    fill_alpha = 0.9,
    col = "darkslategrey",
    lwd = 0.6,
    size.scale = tm_scale_continuous(ticks = c(50, 150, 300))
  ) +


  tm_layout(
    legend.show = FALSE,
    frame = FALSE,
    bg.color = "ivory"
  )

start_map_walk

tmap_save(
  start_map_walk,
  filename = "www/start_map_shiny_walk.png",
  width = 10,
  height = 8,
  dpi = 300,
  asp = 0
)
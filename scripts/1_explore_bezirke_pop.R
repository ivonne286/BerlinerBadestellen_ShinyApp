### Skript 1e: Exploration der Bezirke (Bevölkerung, Badestellen, Distanzen)
### Ivonne Giske
### Beginn: 01.07.2026
### Projekt: Berliner Badestellen – Thematische Karte zur Erreichbarkeit
### Modul: Thematische Internetkartografie
### Aufgabe: Erstellung einer thematischen, interaktiven Karte, browserfähig
###
### Eingabe:  data/1_processed_data.RData, data/einwohnerzahlen.csv
### Ausgabe:  data/1_explore_bezirke_pop.RData
###
### Exploration – nicht nötig für die Erzeugung von shiny_data.RData.

library(sf)
library(tidyverse)

tmp <- new.env()
load("data/1_processed_data.RData", envir = tmp)

lakes_new <- tmp$lakes_new
bezirke <- tmp$bezirke


# GET EINWOHNERZAHLEN PRO BEZIRK von CSV
einwohner <- read_csv("data/einwohnerzahlen.csv", show_col_types = FALSE)
spec(einwohner)

# BERECHNUNGEN
# Bevölkerungsdichte
bezirke_pop <- bezirke |> 
  left_join(einwohner, by = c("namgem" = "Bezirk"))

bezirke_pop$area_m2 <- st_area(bezirke_pop)
bezirke_pop$area_km2 <- as.numeric(bezirke_pop$area_m2) / 1e6

bezirke_pop <- bezirke_pop |>
  mutate(pop_density = Einwohnerzahl / area_km2)

# Anzahl lakes_new pro Bezirk
bezirke_pop$lake_count <- lengths(
  st_intersects(bezirke_pop, lakes_new)
)

# Distances
centroids <- st_centroid(bezirke_pop)
dist_matrix <- st_distance(centroids, lakes_new)

bezirke_pop$nearest_dist_lake_km <- round((apply(dist_matrix, 1, min) / 1000), 1)
bezirke_pop$average_dist_lake_km <- round((apply(dist_matrix, 1, mean) / 1000), 1)

# Clean the dataframe

bezirke_pop <- bezirke_pop |>
  rename(bezirk = namgem) |>
  select(
    geom,
    bezirk,
    Einwohnerzahl,
    area_km2,
    pop_density,
    lake_count,
    nearest_dist_lake_km,
    average_dist_lake_km
  )

bezirke_grenzen <- bezirke |>
  rename(bezirk = namgem) |>
  select(
    geom,
    bezirk
  )


# ===============================
# SAVE DATA
rm(list=setdiff(ls(),c('bezirke_grenzen', 'bezirke_pop', 'einwohner', 'lakes_new')))
save(
  bezirke_grenzen,
  bezirke_pop,
  einwohner,
  lakes_new,
  file = "data/1_explore_bezirke_pop.RData"
)
# ===============================

### Skript 3b: Datenanalyse badestellenbezogen
### Ivonne Giske
### Beginn: 01.07.2026
### Projekt: Berliner Badestellen – Thematische Karte zur Erreichbarkeit
### Modul: Thematische Internetkartografie
### Aufgabe: Erstellung einer thematischen, interaktiven Karte, browserfähig
###
### Eingabe:  data/2_isochrones_all.RData, data/ew_points_3a.gpkg, data/lakes_new.gpkg
### Ausgabe:  data/3_lake_stats.rds, data/3_analysis_b_lake_stats.RData

library(sf)
library(tmap)
library(dplyr)
library(tidyr)

# load data
load("data/2_isochrones_all.RData")
ew_points_b <- st_read("data/ew_points_3a.gpkg")
lakes_b <- st_read("data/lakes_new.gpkg")
rm(cycle_iso, walk_iso)


# prepare loop
modes <- c("foot-walking", "cycling-regular")
times <- c(5, 10, 20)


# step A:
# For every EW population point, we check if it falls inside one of these 39 isochrone polygons and if yes, we attach the corresponding lake_name
# if a population point falls into two or more overlapping isochrones, then the entry is copied for each lake_name/isochrone polygon (resulting in more obs. in ew_points_in_iso)
# So: For every transport mode, and for every travel time, find the 39 relevant lake catchments and determine which population points fall inside them.

# step B:
# we count how often an ew_point_id is in ew_points_in_iso as this gives us the number of lakes that these ew_points have access to
# the table prints per mode and time: n_lakes and the amount of ew_points underneath (not yet the population)

# step C:
# Equal-share allocation

# after the loop
# step D: we turn the point-level allocations into lake-level statistics
# step E: create


# for storing the results per ew_point, needed for further calculations
results <- list()

for (m in modes) {
  
  for (time in times) {
    
    iso_time <- all_isochrones_sf |>
      filter(mode == m, minutes == time)
    
    # step A
    ew_points_in_iso <- st_join(
      ew_points_b,
      iso_time |> select(lake_name),
      join = st_within,
      left = FALSE
    )
    
    # step B
    ew_lake_access <- ew_points_in_iso |>
      count(point_id, name = "n_lakes") |>
      st_drop_geometry()
    
    # step C
    ew_points_in_iso <- ew_points_in_iso |>
      left_join(
        ew_lake_access,
        by = "point_id"
      ) |>
      mutate(
        share = 1 / n_lakes,
        ew_assigned = ew2025 * share
      )
    
    ew_points_in_iso <- ew_points_in_iso |>
      select(
        point_id, ew2025, lake_name, n_lakes, share, ew_assigned
      ) |>
      mutate(
        mode = m,
        minutes = time
      )
    
    # save this iterations results
    results[[paste(m, time, sep = "_")]] <- ew_points_in_iso
    
  }
}



# create the all_allocations object from the result list
all_allocations <- bind_rows(results) |>
  st_drop_geometry()

# test check
all_allocations |>
  filter(point_id == 12127) 

# results
results$`cycling-regular_10` |>
  select(point_id, ew2025, lake_name, n_lakes, share, ew_assigned) |>
  filter(n_lakes > 3) |>
  tail(10)


# step D:
# Step 1 — aggregate assigned population
lake_allocations <- all_allocations |>
  group_by(lake_name, mode, minutes) |>
  summarise(
    ew_assigned = sum(ew_assigned),
    .groups = "drop"
  )
# Step 2 - get lakes ew_catchment
# (ew2025 = population for an ew_point)
# ew_catchment   = population within the lake's isochrone (Bevölkerung im Einzugsgebiet)
# ew_assigned    = population allocated to the lake after competition (nach Seen-Konkurrenz zugewiesene Bev.)

lake_catchment <- all_allocations |>
  distinct(lake_name, mode, minutes, point_id, ew2025) |>
  group_by(lake_name, mode, minutes) |>
  summarise(
    ew_catchment = sum(ew2025),
    .groups = "drop"
  )

lake_assigned <- all_allocations |>
  group_by(lake_name, mode, minutes) |>
  summarise(
    ew_assigned = sum(ew_assigned),
    .groups = "drop"
  )

lake_stats <- lake_catchment |>
  left_join(
    lake_assigned,
    by = c("lake_name", "mode", "minutes")
  )

tail(lake_stats)

# Step 3 add the missing lake × mode × time combinations
# every lake now has a row for every walking/cycling × 5/10/20 scenario,
# even when nobody lives within the corresponding isochrone

lake_combinations <- expand_grid(
  lake_name = lakes_b$lake_name,
  mode = modes,
  minutes = times
)

lake_stats <- lake_combinations |>
  left_join(
    lake_stats,
    by = c("lake_name", "mode", "minutes")
  ) |>
  mutate(
    ew_catchment = replace_na(ew_catchment, 0),
    ew_assigned = replace_na(ew_assigned, 0)
  )

lake_stats |>
  filter(ew_catchment == 0) |>
  arrange(lake_name, mode, minutes)


# save
saveRDS(lake_stats, "data/3_lake_stats.rds")

save(
  all_allocations,
  ew_points_in_iso,
  lake_combinations,
  results,
  lake_stats,
  file = "data/3_analysis_b_lake_stats.RData"
)






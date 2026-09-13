### Skript 3a: Datenanalyse ortsteil- o. bezirkbezogen
### Ivonne Giske
### Beginn: 01.07.2026
### Projekt: Berliner Badestellen – Thematische Karte zur Erreichbarkeit
### Modul: Thematische Internetkartografie
### Aufgabe: Erstellung einer thematischen, interaktiven Karte, browserfähig
###
### Eingabe:  data/1_processed_data.RData, data/2_isochrones_all.RData
### Ausgabe:  data/ew_points_3a.gpkg, data/3_analysis_a_ew_point_access_stats.RData
###           data/3_ortsteile_access_stats.rds, data/3_bezirke_access_stats.rds

library(sf)
library(dplyr)

#load("data/1_original_data.RData")
load("data/1_processed_data.RData")
load("data/2_isochrones_all.RData")

# rm(all_isochrones_sf, ew_dichte2025, ew_dichte2025_simple, lakes)

# dataframe for analysis (a)
ew_points_a <- ew_points

# join Ortsteil/Bezirk (original borders used to avoid NA assignments)
# sum check should give 0
ew_points_a <- st_join(
  ew_points_a,
  ortsteile[, "nam"]
)
names(ew_points_a)[names(ew_points_a) == "nam"] <- "ortsteil"
# sum(is.na(ew_points_a$ortsteil))

ew_points_a <- st_join(
  ew_points_a,
  bezirke[, "namgem"]
)
names(ew_points_a)[names(ew_points_a) == "namgem"] <- "bezirk"
# sum(is.na(ew_points_a$bezirk))


# Intersection of points and isochrones
# st_intersects() returns an sgbp object (sparse geometry binary predicate)
# which is a memory-efficient list structure

walk_hits <- st_intersects(ew_points_a, walk_iso)
length(walk_hits)
sum(lengths(walk_hits) > 0)

cycle_hits <- st_intersects(ew_points_a, cycle_iso)
length(cycle_hits)
sum(lengths(cycle_hits) > 0)

# add minimum walking minutes to each ew_point (or NA if not available)
walk_min <- sapply(walk_hits, function(x) {

  if (length(x) == 0) {
    return(NA)
  } else {
    return(min(walk_iso$minutes[x]))
  }
})
ew_points_a$walk_min <- walk_min

# add minimum cycling minutes to each ew_point (or NA if not available)
cycle_min <- sapply(cycle_hits, function(x) {
  
  if (length(x) == 0) {
    return(NA)
  } else {
    return(min(cycle_iso$minutes[x]))
  }
})
ew_points_a$cycle_min <- cycle_min

# health checking
table(ew_points_a$cycle_min, useNA = "always")
table(ew_points_a$walk_min, useNA = "always")


# add factors for later plotting/legend issues:
ew_points_a <- ew_points_a |>
  mutate(
    walk_class = factor(
      walk_min,
      levels = c(5, 10, 20, NA),
      labels = c(
        "Within 5 min",
        "Within 10 min",
        "Within 20 min",
        "Not within 20 min"
      ),
      exclude = NULL
    ),
    
    cycle_class = factor(
      cycle_min,
      levels = c(5, 10, 20, NA),
      labels = c(
        "Within 5 min",
        "Within 10 min",
        "Within 20 min",
        "Not within 20 min"
      ),
      exclude = NULL
    )
  )

# reorder the columns
ew_points_a <- ew_points_a |>
  select(point_id, ew2025, ha, ew_ha_2025, typklar, bezirk, ortsteil, walk_min, walk_class, cycle_min, cycle_class, geom)


# Population & Access Statistics (new objects)
# 1) for ORTSTEILE
ortsteile_access_stats <- ew_points_a |>
  group_by(ortsteil) |>
  summarise(
    pop_total = sum(ew2025, na.rm = TRUE),
    
    pop_walk_within_5 = sum(ew2025[walk_min <= 5], na.rm = TRUE),
    pop_walk_within_10 = sum(ew2025[walk_min <= 10], na.rm = TRUE),
    pop_walk_within_20 = sum(ew2025[walk_min <= 20], na.rm = TRUE),
    pop_walk_not_within_20 = sum(ew2025[is.na(walk_min)], na.rm = TRUE),
    
    pop_cycle_within_5 = sum(ew2025[cycle_min <= 5], na.rm = TRUE),
    pop_cycle_within_10 = sum(ew2025[cycle_min <= 10], na.rm = TRUE),
    pop_cycle_within_20 = sum(ew2025[cycle_min <= 20], na.rm = TRUE),
    pop_cycle_not_within_20 = sum(ew2025[is.na(cycle_min)], na.rm = TRUE)
  )

ortsteile_access_stats <- ortsteile |>
  select(ortsteil = nam, geom) |>
  left_join(
    st_drop_geometry(ortsteile_access_stats),
    by = "ortsteil"
  ) |>
  mutate(
    area_km2 = as.numeric(st_area(geom)) / 1e6,
    pop_density = pop_total / area_km2,
    lake_count = lengths(st_intersects(geom, lakes_new))
  ) |>
  st_drop_geometry()


# safety check again
sum(ortsteile_access_stats$pop_walk_within_20 +
      ortsteile_access_stats$pop_walk_not_within_20)
sum(ortsteile_access_stats$pop_total)

# check
class(ortsteile_access_stats)
ortsteile_access_stats |>
  arrange(desc(pop_walk_within_5)) |>
  head()

# add percentage
ortsteile_access_stats <- ortsteile_access_stats |>
  mutate(
    walk_within_5_pct = round(pop_walk_within_5 / pop_total * 100, 2),
    walk_within_10_pct = round(pop_walk_within_10 / pop_total * 100, 2),
    walk_within_20_pct = round(pop_walk_within_20 / pop_total * 100, 2),
    walk_not_within_20_pct = round(pop_walk_not_within_20 / pop_total * 100, 2),
    
    cycle_within_5_pct = round(pop_cycle_within_5 / pop_total * 100, 2),
    cycle_within_10_pct = round(pop_cycle_within_10 / pop_total * 100, 2),
    cycle_within_20_pct = round(pop_cycle_within_20 / pop_total * 100, 2),
    cycle_not_within_20_pct = round(pop_cycle_not_within_20 / pop_total * 100, 2)
  )

# reorder ortsteile dataset
ortsteile_access_stats <- ortsteile_access_stats |>
  select(
    ortsteil,
    pop_total,
    area_km2,
    pop_density,
    lake_count,
    
    pop_walk_within_5,
    pop_walk_within_10,
    pop_walk_within_20,
    pop_walk_not_within_20,
    
    walk_within_5_pct,
    walk_within_10_pct,
    walk_within_20_pct,
    walk_not_within_20_pct,
    
    pop_cycle_within_5,
    pop_cycle_within_10,
    pop_cycle_within_20,
    pop_cycle_not_within_20,
    
    cycle_within_5_pct,
    cycle_within_10_pct,
    cycle_within_20_pct,
    cycle_not_within_20_pct
  )

# 2) for BEZIRKE
bezirke_access_stats <- ew_points_a |>
  group_by(bezirk) |>
  summarise(
    pop_total = sum(ew2025, na.rm = TRUE),
    
    pop_walk_within_5 = sum(ew2025[walk_min <= 5], na.rm = TRUE),
    pop_walk_within_10 = sum(ew2025[walk_min <= 10], na.rm = TRUE),
    pop_walk_within_20 = sum(ew2025[walk_min <= 20], na.rm = TRUE),
    pop_walk_not_within_20 = sum(ew2025[is.na(walk_min)], na.rm = TRUE),
    
    pop_cycle_within_5 = sum(ew2025[cycle_min <= 5], na.rm = TRUE),
    pop_cycle_within_10 = sum(ew2025[cycle_min <= 10], na.rm = TRUE),
    pop_cycle_within_20 = sum(ew2025[cycle_min <= 20], na.rm = TRUE),
    pop_cycle_not_within_20 = sum(ew2025[is.na(cycle_min)], na.rm = TRUE)
  )

bezirke_access_stats <- bezirke |>
  select(bezirk = namgem, geom) |>
  left_join(
    st_drop_geometry(bezirke_access_stats),
    by = "bezirk"
  ) |>
  mutate(
    area_km2 = as.numeric(st_area(geom)) / 1e6,
    pop_density = pop_total / area_km2,
    lake_count = lengths(st_intersects(geom, lakes_new))
  ) |>
  st_drop_geometry()


# safety check again
sum(bezirke_access_stats$pop_walk_within_20 +
    bezirke_access_stats$pop_walk_not_within_20)
sum(bezirke_access_stats$pop_total)

# check
class(bezirke_access_stats)
bezirke_access_stats |>
  arrange(desc(pop_walk_within_5)) |>
  head()

# add percentage
bezirke_access_stats <- bezirke_access_stats |>
  mutate(
    walk_within_5_pct = round(pop_walk_within_5 / pop_total * 100, 2),
    walk_within_10_pct = round(pop_walk_within_10 / pop_total * 100, 2),
    walk_within_20_pct = round(pop_walk_within_20 / pop_total * 100, 2),
    walk_not_within_20_pct = round(pop_walk_not_within_20 / pop_total * 100, 2),
    
    cycle_within_5_pct = round(pop_cycle_within_5 / pop_total * 100, 2),
    cycle_within_10_pct = round(pop_cycle_within_10 / pop_total * 100, 2),
    cycle_within_20_pct = round(pop_cycle_within_20 / pop_total * 100, 2),
    cycle_not_within_20_pct = round(pop_cycle_not_within_20 / pop_total * 100, 2)
  )

# reorder dataset
bezirke_access_stats <- bezirke_access_stats |>
  select(
    bezirk,
    pop_total,
    area_km2,
    pop_density,
    lake_count,
    
    pop_walk_within_5,
    pop_walk_within_10,
    pop_walk_within_20,
    pop_walk_not_within_20,
    
    walk_within_5_pct,
    walk_within_10_pct,
    walk_within_20_pct,
    walk_not_within_20_pct,
    
    pop_cycle_within_5,
    pop_cycle_within_10,
    pop_cycle_within_20,
    pop_cycle_not_within_20,
    
    cycle_within_5_pct,
    cycle_within_10_pct,
    cycle_within_20_pct,
    cycle_not_within_20_pct
  )

# SAFETY
# save statistics
saveRDS(ortsteile_access_stats, "data/3_ortsteile_access_stats.rds")
saveRDS(bezirke_access_stats, "data/3_bezirke_access_stats.rds")

# save points that include first iso analysis results
st_write(
  ew_points_a,
  "data/ew_points_3a.gpkg",
  delete_dsn = TRUE
)

# save both as RData
save(
  ew_points_a,
  ortsteile_access_stats,
  bezirke_access_stats,
  file = "data/3_analysis_a_ew_point_access_stats.RData"
)



### Skript 4: Vorbereitung der Daten für ShinyApp
### Ivonne Giske
### Beginn: 01.07.2026
### Projekt: Berliner Badestellen – Thematische Karte zur Erreichbarkeit
### Modul: Thematische Internetkartografie
### Aufgabe: Erstellung einer thematischen, interaktiven Karte, browserfähig
###
### Eingabe:  data/1_processed_data.RData, data/2_isochrones_all.RData,
###           data/3_analysis_c_lake_ranking.RData, data/3_analysis_a_ew_point_access_stats.RData,
###           data/berlin_waters.gpkg
### Ausgabe:  data/shiny_data.RData (alle shiny_*-Objekte für die App)

library(sf)
library(dplyr)
library(tidyr)
library(gstat)  # IDW-Interpolation
library(stars)  # Raster: st_rasterize

tmp = new.env()
tmp_A = new.env()
tmp_B = new.env()
tmp_D = new.env()
load("data/1_processed_data.RData", envir = tmp)
load("data/2_isochrones_all.RData", envir = tmp_B)

# the following two are changeable
load("data/3_analysis_c_lake_ranking.RData", envir = tmp_A)
load("data/3_analysis_a_ew_point_access_stats.RData", envir = tmp_D)

ortsteile <- tmp$ortsteile
bezirke <- tmp$bezirke
lake_ranking <- tmp_A$lake_ranking
lakes_b <- tmp_A$lakes_b
all_isochrones_sf <- tmp_B$all_isochrones_sf
# heißt in 3_analysis_a ew_points_a; hier übernommen als ew_points_b (Konvention der Folge-Skripte)
ew_points_b <- tmp_D$ew_points_a

ortsteile_access_stats <- tmp_D$ortsteile_access_stats
bezirke_access_stats <- tmp_D$bezirke_access_stats
berlin_waters <- st_read("data/berlin_waters.gpkg")

### =============================
# 1a) Final Lake Dataset For Shiny
### =============================
shiny_lakes <- lakes_b |>
  crossing(
    mode = c("cycling-regular", "foot-walking")
  ) |>
  left_join(
    lake_ranking |>
      select(
        lake_name,
        mode,
        gravity_score,
        pressure_share,
        pressure_share_pct,
        rank
      ),
    by = c("lake_name", "mode")
  )

# now shiny lakes is a table, we need sf-object
class(shiny_lakes)


# get the geometry correct
shiny_lakes <- lakes_b |>
  select(lake_name, geom) |>
  left_join(
    shiny_lakes,
    by = "lake_name"
  )

# now it is an sf-object
class(shiny_lakes)


# collect all needed attributes
shiny_lakes <- shiny_lakes |>
  select(
    lake_name,
    link,
    mode,
    gravity_score,
    pressure_share,
    pressure_share_pct,
    rank,
    geom = geom.x
  )

# add label for ranks
shiny_lakes <- shiny_lakes |>
  group_by(mode) |>
  mutate(
    rank_label = if_else(
      is.na(rank),
      "Kein Rang",
      paste0(rank, " von ", sum(!is.na(rank)))
    )
  ) |>
  ungroup()

# lake gravity class preparation for shiny
shiny_lakes |>
  st_drop_geometry() |>
  group_by(mode) |>
  summarise(
    min = min(gravity_score, na.rm = TRUE),
    q25 = quantile(gravity_score, 0.25, na.rm = TRUE),
    median = median(gravity_score, na.rm = TRUE),
    q75 = quantile(gravity_score, 0.75, na.rm = TRUE),
    max = max(gravity_score, na.rm = TRUE)
  )

shiny_lakes <- shiny_lakes |>
  mutate(
    gravity_visual = sqrt(gravity_score),
    link_html = if_else(
      is.na(link),
      NA_character_,
      paste0('<a href="', link, '" target="_blank">More lake info</a>')
    )
  )

# add the Bezirk and Ortsteil each lake lies in (spatial join of the points)
shiny_lakes$bezirk <- st_join(
  shiny_lakes,
  bezirke["namgem"],
  join = st_within
)$namgem
shiny_lakes$ortsteil <- st_join(
  shiny_lakes,
  ortsteile["nam"],
  join = st_within
)$nam


# final check of object shiny_lakes
shiny_lakes |>
  st_geometry_type() |>
  table()

shiny_lakes |>
  st_drop_geometry() |>
  count(mode, rank_label == "Not ranked")

# names(shiny_lakes)
# class(shiny_lakes)
# st_crs(shiny_lakes)



### =============================
# 1b) Final Water Background
### =============================

shiny_water_background <- berlin_waters |>
  select(geom)

### =============================
# 2) Final Ortsteile Shiny Data
### =============================
# names(ortsteile)
# names(ortsteile_access_stats)

setdiff(
  ortsteile$nam,
  ortsteile_access_stats$ortsteil
)

shiny_ortsteile <- ortsteile |>
  select(ortsteil = nam, geom) |>
  left_join(
    ortsteile_access_stats,
    by = "ortsteil"
  )

# add the Bezirk each Ortsteil belongs to (spatial join via centroid)
shiny_ortsteile$bezirk <- st_join(
  st_centroid(shiny_ortsteile),
  bezirke["namgem"],
  join = st_within
)$namgem

# lakes outside all Ortsteil polygons get the nearest Ortsteil (and its Bezirk);
# muss NACH shiny_ortsteile (inkl. bezirk-Spalte) laufen, sonst Objekt nicht definiert
outside <- is.na(shiny_lakes$ortsteil)
if (any(outside)) {
  nearest <- st_nearest_feature(shiny_lakes[outside, ], shiny_ortsteile)
  shiny_lakes$ortsteil[outside] <- shiny_ortsteile$ortsteil[nearest]
  shiny_lakes$bezirk[outside] <- shiny_ortsteile$bezirk[nearest]
}

class(shiny_ortsteile)
st_crs(shiny_ortsteile)
names(shiny_ortsteile)

shiny_ortsteile |>
  st_geometry_type() |>
  table()

### =============================
# 3) Final Bezirke Shiny Data
### =============================
setdiff(
  bezirke$namgem,
  bezirke_access_stats$bezirk
)

shiny_bezirke <- bezirke |>
  select(bezirk = namgem, geom) |>
  left_join(
    bezirke_access_stats,
    by = "bezirk"
  )

class(shiny_bezirke)
st_crs(shiny_bezirke)
names(shiny_bezirke)

shiny_bezirke |>
  st_geometry_type() |>
  table()

### =============================
# 4a) Final Isochronen Shiny Data
### =============================

shiny_isochrones <- all_isochrones_sf

# create united iso objects / all lakes + one mode + one time
shiny_iso_unions <- all_isochrones_sf |>
  group_by(mode, minutes) |>
  summarise(
    .groups = "drop"
  )


# enrich with population data
total_pop_berlin <- 3913490

shiny_iso_unions <- shiny_iso_unions |>
  rowwise() |>
  mutate(
    population = {
      hits <- st_intersects(
        ew_points_b,
        geometry
      )
      
      sum(
        ew_points_b$ew2025[lengths(hits) > 0],
        na.rm = TRUE
      )
    },
    population_pct = population / total_pop_berlin * 100
  ) |>
  ungroup()

# check results
shiny_iso_unions |>
  st_drop_geometry()

### =============================
# 4b) Berlin Borders
### =============================

shiny_berlin_boundary <- bezirke |>
  summarise()

shiny_iso_unions_clipped <- shiny_iso_unions |>
  st_intersection(shiny_berlin_boundary)


### =============================
# 4c) Isochronen-Ringe (kategorisch) für die Karte
### =============================

make_rings <- function(x) {
  x <- x |> arrange(minutes)
  
  g5  <- st_union(x |> filter(minutes == 5))
  g10 <- st_union(x |> filter(minutes == 10))
  g20 <- st_union(x |> filter(minutes == 20))
  
  x |>
    mutate(
      ring_pop = population - lag(population, default = 0),
      ring_pop_pct = population_pct - lag(population_pct, default = 0),
      time_band = c("0–5 min", "5–10 min", "10–20 min")
    ) |>
    st_set_geometry(
      c(g5, st_difference(g10, g5), st_difference(g20, g10))
    )
}

shiny_iso_rings <- shiny_iso_unions_clipped |>
  group_split(mode) |>
  lapply(make_rings) |>
  bind_rows()

# check: ring populations add up to the 20-min isochrone
shiny_iso_rings |>
  st_drop_geometry() |>
  group_by(mode) |>
  summarise(
    ring_pop_sum = sum(ring_pop, na.rm = TRUE),
    pop_20 = population[minutes == 20],
    diff = ring_pop_sum - pop_20,
    ring_pct_sum = sum(ring_pop_pct, na.rm = TRUE),
    pop_20_pct = population_pct[minutes == 20],
    diff_pct = ring_pct_sum - pop_20_pct
  )

# minutes as factor for a robust categorical map scale
shiny_iso_rings <- shiny_iso_rings |>
  mutate(
    minutes = factor(
      minutes,
      levels = c(5, 10, 20),
      labels = c("up to 5 min", "up to 10 min", "up to 20 min")
    )
  )


### =============================
# 4d) Bevölkerungsdichte-Raster (IDW-Hitzekarte)
### =============================
# Kontinuierliche Dichteoberfläche (Einwohner je ha) aus den Baublock-Punkten,
# auf ein 100-m-Raster interpoliert und auf Berlin maskiert.
# Enthält nur die rohen Dichtewerte, keine Farben - die Farbskala (z.B.
# tm_scale_continuous_sqrt()) wird erst beim Plotten in tmap festgelegt.

g_idw <- gstat(
  formula = ew_ha_2025 ~ 1,
  locations = ew_points_b,
  nmax = 15,
  set = list(idp = 2)
)

bb <- st_bbox(ew_points_b)
grid_pts <- expand.grid(
  x = seq(bb$xmin, bb$xmax, by = 100),
  y = seq(bb$ymin, bb$ymax, by = 100)
) |>
  st_as_sf(
    coords = c("x", "y"),
    crs = st_crs(ew_points_b)
  )

pred <- predict(g_idw, grid_pts)
pred <- pred[lengths(st_intersects(pred, st_union(bezirke))) > 0, ]

shiny_ew_density_raster <- st_rasterize(
  pred["var1.pred"],
  dx = 100,
  dy = 100
)
names(shiny_ew_density_raster) <- "ew_ha_2025_idw"

# check
shiny_ew_density_raster


### =============================
# 5) Final Shiny Data Check
### =============================
shiny_lakes |>
  st_drop_geometry() |>
  count(mode)

summary(shiny_lakes)
summary(shiny_ortsteile)
summary(shiny_bezirke)
summary(shiny_iso_unions)
summary(shiny_iso_rings)
summary(shiny_water_background)
summary(shiny_ew_density_raster)

table(
  shiny_isochrones$mode,
  shiny_isochrones$minutes
)


### ======================
# 6) Save Final Shiny Data
### ======================
shiny_objects <- ls(pattern = "^shiny_")
print(shiny_objects)

save(
  list = shiny_objects,
  file = "data/shiny_data.RData"
)

# BESTANDSAUFNAHME
for (x in shiny_objects) {
  cat("\n", x, ":\n", sep = "")
  print(names(get(x)))
}





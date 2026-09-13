### Skript 1: Datenabruf & Datenaufbereitung
### Ivonne Giske
### Beginn: 01.07.2026
### Projekt: Berliner Badestellen – Thematische Karte zur Erreichbarkeit
### Modul: Thematische Internetkartografie
### Aufgabe: Erstellung einer thematischen, interaktiven Karte, browserfähig
###
### Eingabe:  WFS Geoportal Berlin (Badestellen, Bezirke, Ortsteile, Einwohnerdichte)
###           data/lakes_new.gpkg (QGIS-bereinigte Badestellenpunkte)
### Ausgabe:  data/bezirke.gpkg, data/ortsteile.gpkg, data/ew_points.gpkg, data/lakes_original.gpkg
###           data/1_original_data.RData, data/1_processed_data.RData

library(sf)
library(dplyr)

st_layers("WFS:https://gdi.berlin.de/services/wfs/badegewaesser")
st_layers("WFS:https://gdi.berlin.de/services/wfs/alkis_bezirke")
st_layers("WFS:https://gdi.berlin.de/services/wfs/alkis_ortsteile")
st_layers("WFS:https://gdi.berlin.de/services/wfs/ua_einwohnerdichte_2025")

# ---------------
# GET BEZIRKE
# ---------------
url_bez <- "https://gdi.berlin.de/services/wfs/alkis_bezirke"

bezirke <- st_read(
  paste0(
    url_bez,
    "?service=WFS",
    "&version=2.0.0",
    "&request=GetFeature",
    "&typenames=alkis_bezirke:bezirksgrenzen",
    "&outputFormat=GML2"
    
  )
)

st_crs(bezirke) <- 25833
st_write(bezirke, "data/bezirke.gpkg", delete_layer = TRUE, quiet=TRUE)


# ---------------
# GET ORTSTEILE
# ---------------
url_ot <- "https://gdi.berlin.de/services/wfs/alkis_ortsteile"

ortsteile <- st_read(
  paste0(
    url_ot,
    "?service=WFS",
    "&version=2.0.0",
    "&request=GetFeature",
    "&typenames=alkis_ortsteile:ortsteile",
    "&outputFormat=GML2"
  )
)

st_crs(ortsteile) <- 25833
st_write(ortsteile, "data/ortsteile.gpkg", delete_layer = TRUE, quiet=TRUE)

# --------------------
# EINWOHNERDICHTE 2025
# --------------------
url_ew <- "https://gdi.berlin.de/services/wfs/ua_einwohnerdichte_2025"

ew_dichte2025 <- st_read(
  paste0(
    url_ew,
    "?service=WFS",
    "&version=2.0.0",
    "&request=GetFeature",
    "&typenames=ua_einwohnerdichte_2025:ua_einwohnerdichte_2025",
    "&outputFormat=GML2"
  )
)

ew_dichte2025_simple <- ew_dichte2025 |>
  select(ew2025, ha, ew_ha_2025, typklar, geom) |>
  filter(ew2025 != 0, ha != 0)

# set crs
st_crs(ew_dichte2025_simple) <- 25833

# delete people living in Gewässer, unplausible (15 people, 3 rows)
# population polygons
ew_poly <- ew_dichte2025_simple[
  ew_dichte2025_simple$typklar != "Gewässer",
]

# give a unique id to each ew-polygon, not sure if needed
ew_poly$point_id <- seq_len(nrow(ew_poly))

# representative population point retrieved from ew_poly
# one point per polygon for later analysis of accessibility
# point on surface guarantees the point lies inside the polygon, whereas for centroids this is not always secured
ew_points <- st_point_on_surface(ew_poly)

st_write(ew_points, "data/ew_points.gpkg", delete_layer = TRUE, quiet=TRUE)



# ---------------
# LAKES
# ---------------
lakes_original <- st_read(
  "WFS:https://gdi.berlin.de/services/wfs/badegewaesser",
  layer = "badegewaesser:aa_badestellen"
)

# save as gpkg
st_write(lakes_original, "data/lakes_original.gpkg", delete_layer = TRUE, quiet=TRUE)

# -------------------------
# !!! LAKES EDITING IN QGIS
# -------------------------

# before saving or working with lakes, in QGIS some of the lakes' access points had to be corrected so that they represent a realistic entry point of a lake and/or that they lies within berlin boundary

# the following lakes_new geopackage is used from now on for calculations
lakes_new <- st_read("data/lakes_new.gpkg")



# ------------
# FINAL CHECKS
# ------------
sum(ew_points$ew2025)
sum(ew_poly$ew2025)
st_crs(bezirke)$epsg
st_crs(lakes_new)$epsg
st_crs(ortsteile)$epsg
st_crs(ew_poly)$epsg
st_crs(ew_points)$epsg

# =========
# SAVE DATA
# =========

save(
  lakes_original,
  ew_dichte2025,
  file = "data/1_original_data.RData"
)

save(
  lakes_new,
  bezirke,
  ortsteile,
  ew_dichte2025_simple,
  ew_points,
  ew_poly,
  file = "data/1_processed_data.RData"
)

# ==========================================================================================

### Skript 3c: Gravity-Modell für die Badestellen (Ranking)
### Ivonne Giske
### Beginn: 01.07.2026
### Projekt: Berliner Badestellen – Thematische Karte zur Erreichbarkeit
### Modul: Thematische Internetkartografie
### Aufgabe: Erstellung einer thematischen, interaktiven Karte, browserfähig
###
### Eingabe:  data/3_analysis_b_lake_stats.RData  (aus 3_analysis_b.R)
### Ausgabe: data/3_analysis_c_lake_ranking.RData
###           -> nur lake_ranking und lakes_b (für 4_prepare_final_shiny_data.R)
###
### Historie: Ein früheres 3_analysis_c.R (altes Szenarien-Modell, 5/10/20 min)
### wurde gelöscht; der Buchstabe c ist seit der Umbenennung dieses Skripts
### wieder frei und bezeichnet jetzt das Gravity-Modell.

library(sf)
library(dplyr)
library(tidyr)
library(ggplot2)

# ---- inputs ----
load("data/3_analysis_b_lake_stats.RData")
ew_points_b <- st_read("data/ew_points_3a.gpkg")
lakes_b <- st_read("data/lakes_new.gpkg")


# =======================
# 1) Gravity-Klassen
# =======================

point_lake_class <- all_allocations |>
  group_by(point_id, lake_name, mode) |>
  summarise(
    first_minutes = min(minutes),
    .groups = "drop"
  )

gravity_weights <- tibble(
  first_minutes = c(5, 10, 20),
  gravity_weight = c(1, 0.5, 0.25)
)

point_lake_class <- point_lake_class |>
  left_join(
    gravity_weights,
    by = "first_minutes"
  )

tail(point_lake_class)


# =======================
# 2) Gravity-Modell (konkurrenz- und distanzgewichtet)
# =======================

gravity_new <- point_lake_class |>
  group_by(point_id, mode) |>
  mutate(
    total_weight = sum(gravity_weight),
    gravity_share = gravity_weight / total_weight
  ) |>
  ungroup()

# point_lake_class |>
#   filter(point_id == 12127)

gravity_new <- gravity_new |>
  left_join(
    ew_points_b |>
      st_drop_geometry() |>
      select(point_id, ew2025),
    by = "point_id"
  ) |>
  mutate(
    ew_gravity_new = ew2025 * gravity_share
  )

gravity_new |>
  filter(point_id == 12280) |>
  select(
    point_id,
    lake_name,
    mode,
    first_minutes,
    gravity_share,
    ew2025,
    ew_gravity_new
  ) |>
  print(width = Inf)


lake_gravity_score_new <- gravity_new |>
  group_by(
    lake_name,
    mode
  ) |>
  summarise(
    gravity_score = sum(ew_gravity_new),
    .groups = "drop"
  )

lake_gravity_score_new |>
  arrange(desc(gravity_score))


lake_gravity_score_new |>
  group_by(mode) |>
  summarise(
    n = n(),
    min = min(gravity_score),
    mean = mean(gravity_score),
    median = median(gravity_score),
    max = max(gravity_score)
  )

lake_gravity_score_new |>
  group_by(mode) |>
  summarise(
    total_gravity = sum(gravity_score)
  )


# Pressure-Share Berechnung
# Welcher Anteil der Berliner Gesamtbevölkerung entfällt nach unserem Gravity-Modell auf diesen See?
# Dieser See repräsentiert ein konkurrenz- und distanzgewichtetes Bevölkerungspotenzial
# von 2,55 % der Berliner Bevölkerung.
total_ew <- 3913490

lake_gravity_score_new <- lake_gravity_score_new |>
  mutate(
    pressure_share = gravity_score / total_ew
  )

lake_gravity_score_new <- lake_gravity_score_new |>
  mutate(
    pressure_share_pct = gravity_score / total_ew * 100
  )

head(lake_gravity_score_new)


# ranking der seen
lake_ranking <- lake_gravity_score_new |>
  group_by(mode) |>
  arrange(desc(gravity_score), .by_group = TRUE) |>
  mutate(
    rank = row_number()
  ) |>
  ungroup()

# Check ein Beispielranking für cycling
# Aussage: Beispielsweise bedeutet:
# Strandbad Weißensee, Cycling: 428.425 EW, rank 1
# heißt nicht, dass 428.425 Menschen tatsächlich dort baden.
# - nach dem Modell werden dem Strandbad Weißensee 428.425 EW als konkurrenz- und entfernungsgewichtetes Bevölkerungspotenzial zugerechnet
# - die 10,9 % sind die EW relativ zur Berliner Gesamtbevölkerung

lake_ranking |>
  filter(mode == "foot-walking") |>
  arrange(rank)


# =======================
# checks
# =======================

# histograms
lake_ranking |>
  filter(mode == "cycling-regular") |>
  ggplot(aes(x = gravity_score)) +
  geom_histogram(bins = 10) +
  labs(
    title = "Distribution of gravity scores – Cycling",
    x = "Gravity score",
    y = "Number of lakes"
  )

lake_ranking |>
  filter(mode == "foot-walking") |>
  ggplot(aes(x = gravity_score)) +
  geom_histogram(bins = 10) +
  labs(
    title = "Distribution of gravity scores – Walking",
    x = "Gravity score",
    y = "Number of lakes"
  )

# weitere checks
lake_ranking |>
  group_by(mode) |>
  summarise(
    min = min(gravity_score),
    p10 = quantile(gravity_score, 0.10),
    p25 = quantile(gravity_score, 0.25),
    median = median(gravity_score),
    p75 = quantile(gravity_score, 0.75),
    p90 = quantile(gravity_score, 0.90),
    max = max(gravity_score),
    mean = mean(gravity_score)
  )

point_lake_class |>
  count(first_minutes)

gravity_new |>
  group_by(point_id, mode) |>
  summarise(
    total_share = sum(gravity_share),
    .groups = "drop"
  ) |>
  summarise(
    min = min(total_share),
    max = max(total_share)
  )


# =======================
# 3) Save
# =======================

# der eine Output für 4_prepare_final_shiny_data.R
save(
  lake_ranking,
  lakes_b,
  file = "data/3_analysis_c_lake_ranking.RData"
)
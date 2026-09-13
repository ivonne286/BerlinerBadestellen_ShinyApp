# Hilfsdiagramm für den Tab "Badestellen-Tabelle":
# zugerechnete Einwohner*innen je Badestelle, getrennt nach Mobilitätsmodus,
# sortiert nach Größe (Fahrrad). Ausgabe: www/plot_lakes_ew.png
#
# Ausführung aus dem Projekt-Root (RStudio-Projekt geöffnet):
#   source("scripts/make_lakes_plot.R")
#
# Neu ausführen, wenn sich die Daten in data/shiny_data.RData ändern –
# das PNG ist eine Kopie der Werte und wird nicht automatisch nachgezogen.

library(sf)
library(dplyr)
library(tidyr)
library(ggplot2)

load("data/shiny_data.RData")

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

p <- ggplot(plot_df, aes(x = lake_name, y = ew / 1000, fill = modus)) +
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

p

ggsave(
  filename = "www/plot_lakes_ew.png",
  plot = p,
  width = 14,
  height = 9,
  dpi = 150
)

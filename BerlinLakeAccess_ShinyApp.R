library(shiny)
library(sf)
library(dplyr)
library(tmap)
library(tmap.mapgl)

# load data
load("data/shiny_data.RData")
tmap_mode("view")

# ─────────────────────────────────────────────────────────
# USER INTERFACE UI
# ─────────────────────────────────────────────────────────
ui <- fluidPage(

  # ── App title ─────────────────────────────────────────
  div(
    h1("Bathing Sites in Berlin"),
    h4("Unequal Access and Potential Demand")
  ),

  # ── Shared travel mode switch (above the map area) ─────
  radioButtons(
    inputId = "mode",
    label = "Travel mode:",
    choiceNames = list(
      tagList(icon("bicycle"), " Cycling"),
      tagList(icon("person-walking"), " Walking")
    ),
    choiceValues = c("cycling-regular", "foot-walking"),
    selected = "cycling-regular",
    inline = TRUE
  ),

  # ── Main layout: sidebar + maps ───────────────────────
  sidebarLayout(
    sidebarPanel(
      width = 3,
      # map1 sidebar: selected Ortsteil
      conditionalPanel(
        condition = "input.map_tab == 'map1'",
        uiOutput("sidebar_content")
      ),
      # map2 sidebar: population within iso-rings
      conditionalPanel(
        condition = "input.map_tab == 'map2'",
        uiOutput("iso_sidebar")
      )
    ),
    mainPanel(
      width = 9,
      tabsetPanel(
        id = "map_tab",

        # Tab 1: Einwohnerdichte & Besuchsdruck
        tabPanel(
          title = "Einwohnerdichte & Besuchsdruck",
          value = "map1",
          tmapOutput("density_map", height = "800px")
        ),

        # Tab 2: Iso-Rings
        tabPanel(
          title = "Iso-Rings",
          value = "map2",
          tmapOutput("iso_map", height = "800px")
        )
      )
    )
  )
)


# ─────────────────────────────────────────────────────────
# SERVER
# ─────────────────────────────────────────────────────────
server <- function(input, output, session) {

  # ────────────────────────
  # Tab 1 Map: Einwohnerdichte & Besuchsdruck
  # ────────────────────────
  output$density_map <- renderTmap({

    req(input$mode)

    # lake ranking / bubble size depends on travel mode
    lakes <- shiny_lakes |> filter(mode == input$mode)

    tm_basemap("CartoDB.PositronNoLabels") +

      # Basis - Heatmap
      tm_shape(shiny_ew_density_raster) +
      tm_raster(
        col.scale = tm_scale_continuous_sqrt(values = "yl_or_rd"),
        col_alpha = 0.8,
        col.legend = tm_legend(title = "Einw./ha")
      ) +

      # Wasser
      tm_shape(shiny_water_background) +
      tm_polygons(
        fill = "turquoise3",
        fill_alpha = 0.8,
        lwd = 0
      ) +

      # Ortsteile
      tm_shape(shiny_ortsteile) +
      tm_polygons(
        fill = NULL,
        col = "indianred1",
        lwd = 0.75,
        id = "ortsteil",
        hover = "ortsteil",
        popup = tm_popup(
          vars = c(
            "Bezirk" = "bezirk",
            "Ortsteil" = "ortsteil"
          )
        )
      ) +

      # Bezirke
      tm_shape(shiny_bezirke) +
      tm_borders(col = "darkslategrey", lwd = 1) +

      # Lakes
      tm_shape(lakes) +
      tm_bubbles(
        size = "gravity_visual",
        fill = "cyan2",
        fill_alpha = 0.9,
        col = "darkslategrey",
        lwd = 2,
        popup = tm_popup(
          vars = c(
            "Lake" = "lake_name",
            "Rank" = "rank_label",
            "Details" = "link_html"
          ),
          format = list(
            link_html = tm_label_format(html.escape = FALSE)
          )
        )
      ) +

      # Border
      tm_shape(shiny_berlin_boundary) +
      tm_borders(col = "darkslategrey", lwd = 1.5) +

      # Subtitle und Titel
      # tm_title_in("EW-Dichte-Raster: 100x100m, Berlin 2025") +
      tm_title("Einwohnerdichte & Besuchsdruck auf Seen")
  })


  # ────────────────────────
  # Tab 1 Sidebar: selected Ortsteil
  # ────────────────────────
  selected_ortsteil <- reactive({
    req(input$density_map_shape_click$id)

    clicked <- input$density_map_shape_click$id

    # tmap replaces every non-alphanumeric char (spaces, hyphens) with
    # underscores in the feature ID; reverse that
    clicked <- shiny_ortsteile$ortsteil[
      gsub("[^[:alnum:]]", "_", shiny_ortsteile$ortsteil) == clicked
    ]

    shiny_ortsteile |>
      filter(ortsteil == clicked)
  })

  # map1 sidebar: selected Ortsteil
  output$sidebar_content <- renderUI({

    req(selected_ortsteil())
    ot <- selected_ortsteil()

    # lakes in this Ortsteil (for the current travel mode)
    lakes_in_ot <- shiny_lakes |>
      filter(ortsteil == ot$ortsteil[[1]], mode == input$mode) |>
      pull(lake_name) |>
      unique()

    # access share depending on travel mode
    if (input$mode == "cycling-regular") {
      access_pct <- ot$cycle_within_20_pct[[1]]
      mode_label <- "cycling"
    } else {
      access_pct <- ot$walk_within_20_pct[[1]]
      mode_label <- "walking"
    }

    tagList(
      h5("Bezirk"),
      h4(ot$bezirk[[1]]),
      hr(),
      h5("Ortsteil"),
      h2(ot$ortsteil[[1]]),
      hr(),
      
      h5("Einwohnerzahl"),
      div(style = "font-size: 28px; font-weight: bold; color: #E34447;",
          paste0(format(round(ot$pop_total[[1]]), big.mark = ".", decimal.mark = ","), " EW")),
      hr(),
      
      h5("Größe"),
      div(style = "font-size: 28px; font-weight: bold; color: #E34447;",
          paste0(format(round(ot$area_km2[[1]], 1), big.mark = ".", decimal.mark = ","), " km²")),
      hr(),
      
      h5("Einwohnerdichte"),
      div(style = "font-size: 28px; font-weight: bold; color: #E34447;",
      paste0(format(round(ot$pop_density[[1]] / 100, 1), big.mark = ".", decimal.mark = ","), " EW/ha")),
      hr(),
      
      h5("Badestellen in diesem Ortsteil"),
      if (length(lakes_in_ot) == 0) {
        div(
          style = "font-size: 20px; font-weight: bold; color: #00868B;",
          "- keine -"
        )
      } else {
        tags$ul(
          lapply(lakes_in_ot, function(lk) {
            tags$li(
              style = "font-size: 20px; font-weight: bold; color: #00868B;",
              lk
            )
          })
        )
      },
      hr(),
      
      h5("Badestellen-Zugang",
         icon(if (input$mode == "cycling-regular") "bicycle" else "person-walking")),
      div(style = "font-size: 20px; font-weight: bold; color: #00868B;",
      paste0(access_pct, "% der EW von ", ot$ortsteil[[1]],
             " können innerhalb von maximal 20 Minuten eine Badestelle erreichen"
      ))
    )
  })


  # ────────────────────────
  # Tab 2 Map: Iso-Rings
  # ────────────────────────
  output$iso_map <- renderTmap({

    req(input$mode)

    # rings and lakes depend on travel mode
    rings <- shiny_iso_rings |> filter(mode == input$mode)
    lakes <- shiny_lakes |> filter(mode == input$mode)

    if (input$mode == "cycling-regular") {
      ring_colors <- c(
        "up to 5 min" = "#8C4BBE",
        "up to 10 min" = "#BC96D9",
        "up to 20 min" = "#D9C3E9"
      )
      legend_title <- "Max. minutes to a lake - Cycling"
    } else {
      ring_colors <- c(
        "up to 5 min" = "#18C93E",
        "up to 10 min" = "#5BEC7A",
        "up to 20 min" = "#A4F4B5"
      )
      legend_title <- "Max. minutes to a lake - Walking"
    }

    tm_basemap("CartoDB.Positron") +

      # rings
      tm_shape(rings) +
      tm_polygons(
        fill = "minutes",
        fill.legend = tm_legend(title = legend_title),
        fill.scale = tm_scale_categorical(values = ring_colors),
        fill_alpha = 0.7,
        lwd = 0,
        popup = FALSE
      ) +

      # water background
      tm_shape(shiny_water_background) +
      tm_polygons(
        fill = "turquoise3",
        fill_alpha = 0.9,
        lwd = 0
      ) +
      tm_layout(frame = FALSE) +

      # border
      tm_shape(shiny_berlin_boundary) +
      tm_borders(
        col = "darkslategrey",
        lwd = 2
      ) +

      # lakes
      tm_shape(lakes) +
      tm_symbols(
        fill = "cyan2",
        col = "darkslategrey",
        size = 0.7,
        lwd = 1.5,
        popup = tm_popup(
          vars = c(
            "Lake" = "lake_name",
            "Rank" = "rank_label",
            "Details" = "link_html"
          ),
          format = list(
            link_html = tm_label_format(html.escape = FALSE)
          )
        )
      ) +
      tm_text(
        text = "lake_name",
        size = 0.7,
        col = "darkslategrey",
        options = opt_tm_text(just = "center"),
        xmod = 0,
        ymod = 0.1
      ) +
      
      # title
      tm_title("Erreichbarkeit der Berliner Badestellen") +

      # legend
      tm_layout(legend.outside = TRUE)
  })

  # ────────────────────────
  # Tab 2 Sidebar Ring Info
  # ────────────────────────
  output$iso_sidebar <- renderUI({

    req(input$mode)

    rings <- shiny_iso_rings |> filter(mode == input$mode)
    pop5  <- rings$population[rings$minutes == "up to 5 min"]
    pop10 <- rings$population[rings$minutes == "up to 10 min"]
    pct5  <- rings$population_pct[rings$minutes == "up to 5 min"]
    pct10 <- rings$population_pct[rings$minutes == "up to 10 min"]

    tagList(
      h3(
        "Wo wohnen die Berliner*innen im Bezug auf die Erreichbarkeit von Badestellen?",
        icon(if (input$mode == "cycling-regular") "bicycle" else "person-walking")
      ),
      hr(),
      p("Innerhalb einer max-5-Minuten-Zone:"),
      div(
        style = "font-size: 28px; font-weight: bold; color: #00868B;",
        paste0(format(pop5, big.mark = ".", decimal.mark = ","), " Einwohner")
      ),
      p(paste0(
        "(", format(round(pct5, 1), big.mark = ".", decimal.mark = ","),
        " % der Berliner*innen)"
      )),
      hr(),
      p("Innerhalb einer max-10-Minuten-Zone:"),
      div(
        style = "font-size: 28px; font-weight: bold; color: #00868B;",
        paste0(format(pop10, big.mark = ".", decimal.mark = ","), " Einwohner")
      ),
      p(paste0(
        "(", format(round(pct10, 1), big.mark = ".", decimal.mark = ","),
        " % der Berliner*innen)"
      ))
    )
  })
}

shinyApp(ui, server)

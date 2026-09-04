library(shiny)
library(sf)
library(dplyr)
library(tmap)
library(tmap.mapgl)
library(DT)

# load data
load("data/shiny_data.RData")
tmap_mode("view")

# lake ids + German details link (map click handling + popups, both tabs)
shiny_lakes <- shiny_lakes |>
  mutate(
    lake_id = paste0(row_number(), if_else(mode == "cycling-regular", "c", "w")),
    link_html = paste0(
      '<a href="', link, '" target="_blank">',
      'ausführliche Informationen</a>'
    )
  )

# ─────────────────────────────────────────────────────────
# USER INTERFACE UI
# ─────────────────────────────────────────────────────────
ui <- fluidPage(

  # sidebar stretches to full layout height (at least map height);
  # tab styling: teal background, coral accent on active tab
  tags$style(HTML("
    .container-fluid > .row { display: flex; }
    .col-sm-3 > .well { height: 100%; }

    .tabbable > .nav > li > a {
      background-color: #E1F0F1;
      color: #006366;
      border: 1px solid #00868B;
    }
    .tabbable > .nav > li.active > a {
      background-color: #00868B;
      color: #FFFFFF;
      border: 1px solid #00868B;
      border-bottom: 3px solid #EE6363;
      font-weight: bold;
    }
    .tabbable > .nav > li > a:hover {
      background-color: #CDE4E5;
      color: #00494C;
    }

    .app-title { text-align: center; margin-bottom: 8px; }
    .app-title h1 {
      color: #006366;
      font-weight: 700;
      margin-bottom: 2px;
    }
    .app-title h1 .fas { color: #00868B; margin-right: 10px; }
    .app-title h4 {
      color: #6c757d;
      font-weight: normal;
      margin-top: 4px;
    }
    .title-rule {
      height: 3px; width: 280px; margin: 14px auto 0 auto; border: 0;
      background: linear-gradient(90deg, #00868B, #EE6363);
      border-radius: 4px;
    }

    details summary { cursor: pointer; color: #006366; font-size: 14px; }
    details summary:hover { color: #00494C; }
  ")),

  # ── App title ─────────────────────────────────────────
  div(
    class = "app-title",
    h1(icon("umbrella-beach"), "Berliner Badestellen"),
    h4("Thematische Karten zur Erreichbarkeit"),
    div(class = "title-rule")
  ),

  # ── Shared travel mode switch (above the map area) ─────
  # Switch affects the map tabs only; the Ortsteil-Tabelle (Challenges +
  # table) is Fahrrad-based and ignores it.
  radioButtons(
    inputId = "mode",
    label = "Verkehrsmittel:",
    choiceNames = list(
      tagList(icon("bicycle"), " Fahrrad"),
      tagList(icon("person-walking"), " Zu Fuß")
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
      ),
      # ranking tab: challenges
      conditionalPanel(
        condition = "input.map_tab == 'ranking'",
        uiOutput("ranking_sidebar")
      ),
      # lakes tab: challenges for the Badestellen table
      conditionalPanel(
        condition = "input.map_tab == 'lakes'",
        uiOutput("lakes_sidebar")
      )
    ),
    mainPanel(
      width = 9,
      tabsetPanel(
        id = "map_tab",

        # Tab 1: Einwohnerdichte & Besuchsdruck
        tabPanel(
          title = "Ortsteilanalyse",
          value = "map1",
          tmapOutput("density_map", height = "880px")
        ),

        # Tab 2: Iso-Rings
        tabPanel(
          title = "Erreichbarkeitszonen",
          value = "map2",
          div(
            style = "position: relative;",
            tmapOutput("iso_map", height = "880px"),
            # Legende: Kreisgröße = Druck auf Badestelle (Overlay auf der Karte)
            div(
              style = "position: absolute; bottom: 20px; left: 20px; z-index: 1000; background: #FFFFFFE6; padding: 10px 14px; border-radius: 4px; box-shadow: 0 1px 4px #0000004D;",
              p(style = "font-size: 13px; font-weight: bold; color: #00494C; margin: 0 0 8px 0;",
                "Druck auf Badestelle"),
              div(
                style = "display: flex; align-items: flex-end; gap: 24px;",
                div(style = "text-align: center;",
                    div(style = "width: 12px; height: 12px; border-radius: 50%; background: #00EEEE; border: 2px solid darkslategrey; margin: 0 auto;"),
                    p(style = "font-size: 11px; margin: 4px 0 0 0; color: #00494C;", "niedrig")),
                div(style = "text-align: center;",
                    div(style = "width: 34px; height: 34px; border-radius: 50%; background: #00EEEE; border: 2px solid darkslategrey; margin: 0 auto;"),
                    p(style = "font-size: 11px; margin: 4px 0 0 0; color: #00494C;", "hoch"))
              ),
              div(
                style = "display: flex; align-items: center; margin-top: 8px;",
                div(style = "flex: 1; height: 2px; background: darkslategrey;"),
                div(style = "width: 0; height: 0; border-top: 5px solid transparent; border-bottom: 5px solid transparent; border-left: 8px solid darkslategrey;")
              )
            )
          )
        ),

        # Tab 3: Ranking table
        tabPanel(
          title = "Ortsteil-Tabelle",
          value = "ranking",
          h3("Alle Ortsteile im Vergleich"),
          hr(),
          p("Hinweis: Prozentwerte und EW/ha sind auf 1, Flächen auf 2 Nachkommastelle(n) gerundet", style = "font-size: 13px; font-weight: normal; font-style: italic"),
          hr(),
          DT::dataTableOutput("ranking_table")
        ),

        # Tab 4: Badestellen-Tabelle
        tabPanel(
          title = "Badestellen",
          value = "lakes",
          h3("Alle Badestellen im Vergleich"),
          hr(),
          p("Hinweis: 39 offizielle, von der EU überwachte Badestellen. Rang und Druckanteil sind modellbasiert (Gravity-Modell, Methodik siehe Tab Metadaten); Prozentwerte auf 1 Nachkommastelle gerundet. Zu Fuß sind 3 Badestellen nicht gerankt – in ihren 20-Minuten-Zonen liegt keine Bevölkerung.",
            style = "font-size: 13px; font-weight: normal; font-style: italic"),
          hr(),
          DT::dataTableOutput("lakes_table")
        ),

        # Tab 5: Metadaten
        tabPanel(
          title = "Metadaten",
          value = "meta",
          h3("Metadaten & Methodik"),
          hr(),
          h4("Datenbasis & Jahr"),
          p("Bevölkerungsraster (2025), Auflösung 100x100 m."),
          hr(),
          h4("Hinweis zur Einwohnerzahl"),
          p("Die Einwohnerzahl wird aus dem Bevölkerungsraster abgeleitet und ist keine amtliche Einwohnerzahl. Personen, die laut Raster in Wasserflächen leben, wurden ausgeschlossen."),
          hr(),
          h4("Methodik"),
          p("Isochronen-Berechnung für Fahrrad und Fuß; Erreichbarkeitszonen in 5-, 10- und 20-Minuten-Ringen."),
          hr(),
          h4("Ranking der Badestellen"),
          p("Der Rang einer Badestelle ergibt sich aus einem Gravity-Modell, das sowohl Entfernung als auch Konkurrenz zwischen Badestellen berücksichtigt. Jeder Bevölkerungspunkt wird allen Badestellen zugeordnet, die er innerhalb von 20 Minuten erreichen kann. Nähere Badestellen erhalten dabei ein höheres Gewicht (5 Minuten = 1, 10 Minuten = 0,5, 20 Minuten = 0,25). Die Einwohner*innen eines Punktes werden anteilig auf alle erreichbaren Badestellen verteilt – je mehr konkurrierende Badestellen in der Nähe liegen, desto weniger entfällt auf die einzelne. Der Gravity-Score einer Badestelle ist die Summe dieser gewichteten und aufgeteilten Einwohner*innen. Der Rang ist die Position nach absteigendem Gravity-Score (Rang 1 = höchste potenzielle Nachfrage). Der Druckanteil (pressure share) gibt an, welcher Anteil der Berliner Bevölkerung nach diesem Modell auf die jeweilige Badestelle entfällt."),
          hr(),
          h4("Quellen"),
          p("Badestellen, Ortsteile, Bezirke, Wasserflächen.")
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
  # TEST: print click events to the console (temporary)
  # ────────────────────────
  observe({
    ev <- list(
      density_map_click = input$density_map_click,
      iso_map_click     = input$iso_map_click
    )
    if (any(!vapply(ev, is.null, logical(1)))) {
      print(ev)
    }
  })

  # ────────────────────────
  # Tab 1 Map: Einwohnerdichte
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
        col.legend = tm_legend(title = "EW/ha")
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
        col = "indianred4",
        lwd = 0.75,
        id = "ortsteil",
        hover = "ortsteil",
        popup = tm_popup(
          vars = c(
            "Bezirk" = "bezirk"
          ),
          # etwas Luft zwischen Label und Wert
          css = ".tmap-popup-label { padding-right: 14px; }"
        )
      ) +

      # Bezirke
      tm_shape(shiny_bezirke) +
      tm_borders(col = "darkslategrey", lwd = 1.25) +

      # Lakes (simple points)
      tm_shape(lakes) +
      tm_symbols(
        fill = "cyan2",
        col = "darkslategrey",
        size = 0.7,
        lwd = 1.5,
        id = "lake_id",
        hover = "lake_name",
        popup = tm_popup(
          title = "lake_name",
          vars = c(
            "Bezirk"  = "bezirk",
            "Ortsteil" = "ortsteil",
            "Details" = "link_html"
          ),
          format = list(
            link_html = tm_label_format(html.escape = FALSE)
          ),
          # Luft zwischen Label und Wert
          css = ".tmap-popup-label { padding-right: 14px; }"
        )
      ) +

      # Border
      tm_shape(shiny_berlin_boundary) +
      tm_borders(col = "darkslategrey", lwd = 1.5)
  })


  # ────────────────────────
  # Tab 1 Sidebar: selected Ortsteil
  # ────────────────────────
  # Last clicked Ortsteil (NULL = nothing selected yet)
  sel_ortsteil <- reactiveVal(NULL)

  observeEvent(input$density_map_shape_click$id, {
    clicked <- input$density_map_shape_click$id
    req(clicked)

    # 1) Lake click: unique lake_id (e.g. 1c) -> Ortsteil of that lake
    lake_hit <- shiny_lakes |>
      filter(lake_id == clicked) |>
      pull(ortsteil)
    if (length(lake_hit) > 0) {
      sel_ortsteil(lake_hit[1])
      return()
    }

    # 2) Ortsteil click: tmap replaces non-alphanumeric chars (spaces,
    #    hyphens, ...) with underscores in the feature ID; reverse that.
    #    Second pattern covers a stricter ASCII sanitization of umlauts.
    hit <- shiny_ortsteile$ortsteil[
      gsub("[^[:alnum:]]", "_", shiny_ortsteile$ortsteil) == clicked
    ]
    if (length(hit) == 0) {
      hit <- shiny_ortsteile$ortsteil[
        gsub("[^a-zA-Z0-9]", "_", enc2utf8(shiny_ortsteile$ortsteil)) == clicked
      ]
    }

    # click on something else -> keep the current selection
    if (length(hit) > 0) sel_ortsteil(hit[1])
  })

  # map1 sidebar: selected Ortsteil
  output$sidebar_content <- renderUI({

    # Startup / nothing selected yet: title + instructions + two extremes
    ot_name <- sel_ortsteil()
    if (is.null(ot_name)) {

      return(tagList(
        h3("Einwohnerdichte und Erreichbarkeit von Badestellen nach Ortsteilen"),
        hr(),
        p("Klicken Sie auf einen Ortsteil oder eine Badestelle, um Details anzuzeigen.",
          style = "font-size: 19px; margin-top: 10px;"),
        p("Die Verkehrsmittelauswahl (Fahrrad / Zu Fuß) ändert die angezeigten Werte.",
          style = "font-size: 19px;")
      ))
    }

    ot <- shiny_ortsteile |> filter(ortsteil == ot_name)

    # lakes reachable from this Ortsteil within 20 min (current travel mode):
    # a lake counts if its 20-min isochrone covers part of the Ortsteil
    iso20 <- shiny_isochrones |> filter(minutes == 20, mode == input$mode)
    reachable <- iso20$lake_name[lengths(st_intersects(iso20, ot)) > 0] |>
      unique() |>
      sort()

    # access share depending on travel mode
    if (input$mode == "cycling-regular") {
      access_pct <- ot$cycle_within_20_pct[[1]]
    } else {
      access_pct <- ot$walk_within_20_pct[[1]]
    }
    pct_txt <- format(round(access_pct, 1), big.mark = ".", decimal.mark = ",")
    ot_txt  <- ot$ortsteil[[1]]
    mode_word <- if (input$mode == "cycling-regular") "mit Fahrrad" else "zu Fuß"

    # sentence depends on the number of reachable bathing sites;
    # only the percentage number is bold + teal
    pct_span <- tags$span(style = "font-size: 24px; font-weight: bold; color: #EE6363;",
                          paste0(pct_txt, " %"))
    if (length(reachable) == 0) {
      reach_sentence <- tagList(
        pct_span, tags$br()," Für die Bevölkerung des Ortsteils ", ot_txt,
        " ist keine Badestelle erreichbar."
      )
    } else if (length(reachable) == 1) {
      reach_sentence <- tagList(
        pct_span, " der Bevölkerung von ", ot_txt,
        " kann folgende Badestelle erreichen:"
      )
    } else {
      reach_sentence <- tagList(
        pct_span, " der Bevölkerung von ", ot_txt,
        " kann mindestens eine der folgenden Badestellen erreichen:"
      )
    }

    tagList(
      h3("Einwohnerdichte und Erreichbarkeit von Badestellen nach Ortsteilen"),
      hr(),
      
      h5("Ortsteil"),
      div(style = "font-size: 28px; font-weight: bold; color: #00868B;",
          ot$ortsteil[[1]]),
      
      h5("Bezirk"),
      div(style = "font-size: 20px; color: #00868B;",
          ot$bezirk[[1]]),
      hr(),
      
      h5("Einwohnerdichte"),
      div(style = "font-size: 24px; font-weight: bold; color: #EE6363;",
      paste0(format(round(ot$pop_density[[1]] / 100, 1), big.mark = ".", decimal.mark = ","), " EW/ha")),
      
      h5("Einwohnerzahl"),
      div(style = "font-size: 20px; color: #EE6363;",
          paste0(format(round(ot$pop_total[[1]]), big.mark = ".", decimal.mark = ","), " EW")),
      
      h5("Fläche"),
      div(style = "font-size: 20px; color: #EE6363;",
          paste0(format(round(ot$area_km2[[1]], 1), big.mark = ".", decimal.mark = ","), " km²")),
      hr(),
      
      h5("Badestellen-Erreichbarkeit für die Bevölkerung (anteilig)",
         tags$br(),
         icon(if (input$mode == "cycling-regular") "bicycle" else "person-walking"),
         tags$span(
           style = "font-size: 13px; font-weight: normal; font-style: italic",
           paste0(" maximal 20 Minuten · ", mode_word)
         ), 
         tags$br(),
      ),
         
      div(style = "font-size: 20px;", reach_sentence),
      if (length(reachable) > 0) {
        tags$ul(
          lapply(reachable, function(lk) {
            tags$li(
              style = "font-size: 20px; font-weight: normal; color: #00868B;",
              lk
            )
          })
        )
      }
    )
  })


  # ────────────────────────
  # Tab 2 Map: Iso-Rings
  # ────────────────────────
  output$iso_map <- renderTmap({

    req(input$mode)

    # rings and lakes depend on travel mode
    rings <- shiny_iso_rings |>
      filter(mode == input$mode) |>
      mutate(zone = case_when(
        minutes == "up to 5 min"  ~ "Zone A (bis zu 5 Min.)",
        minutes == "up to 10 min" ~ "Zone B (bis zu 10 Min.)",
        minutes == "up to 20 min" ~ "Zone C (bis zu 20 Min.)"
      ))
    lakes <- shiny_lakes |> filter(mode == input$mode)

    if (input$mode == "cycling-regular") {
      ring_colors <- c(
        "Zone A (bis zu 5 Min.)"  = "#8C4BBE",
        "Zone B (bis zu 10 Min.)" = "#BC96D9",
        "Zone C (bis zu 20 Min.)" = "#D9C3E9"
      )
      legend_title <- "Erreichbarkeitszonen mit Fahrrad"
    } else {
      ring_colors <- c(
        "Zone A (bis zu 5 Min.)"  = "#18C93E",
        "Zone B (bis zu 10 Min.)" = "#5BEC7A",
        "Zone C (bis zu 20 Min.)" = "#A4F4B5"
      )
      legend_title <- "Erreichbarkeitszonen zu Fuß"
    }

    tm_basemap("CartoDB.Positron") +

      # rings
      tm_shape(rings) +
      tm_polygons(
        fill = "zone",
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

      
      # size.legend.show = FALSE,
      # fill.legend.show = FALSE,
      #
      # lakes (gravity-sized bubbles with rank)
      tm_shape(lakes) +
      tm_bubbles(
        size = "gravity_visual",
        size.legend  = tm_legend_hide(),
        fill = "cyan2",
        fill.legend = tm_legend_hide(),
        fill_alpha = 0.9,
        col = "darkslategrey",
        lwd = 2,
        id = "lake_id",
        hover = "lake_name",
        popup = tm_popup(
          title = "lake_name",
          vars = c(
            "Rang"    = "rank_label",
            "Details" = "link_html"
          ),
          format = list(
            link_html = tm_label_format(html.escape = FALSE)
          ),
          # Luft zwischen Label und Wert
          css = ".tmap-popup-label { padding-right: 14px; }"
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
      tm_layout(legend.outside = TRUE)
  })

  # ────────────────────────
  # Tab 2 Sidebar Ring Info
  # ────────────────────────
  output$iso_sidebar <- renderUI({

    req(input$mode)

    rings <- shiny_iso_rings |>
      filter(mode == input$mode) |>
      mutate(zone = case_when(
        minutes == "up to 5 min"  ~ "Zone A (bis zu 5 Min.)",
        minutes == "up to 10 min" ~ "Zone B (bis zu 10 Min.)",
        minutes == "up to 20 min" ~ "Zone C (bis zu 20 Min.)"
      ))
    pop5  <- rings$population[rings$minutes == "up to 5 min"]
    pop10 <- rings$population[rings$minutes == "up to 10 min"]
    pop20 <- rings$population[rings$minutes == "up to 20 min"]
    pct5  <- rings$population_pct[rings$minutes == "up to 5 min"]
    pct10 <- rings$population_pct[rings$minutes == "up to 10 min"]
    pct20 <- rings$population_pct[rings$minutes == "up to 20 min"]
    
    # total Berlin population, derived from the 5-min ring (population / share in %)
    berlin_pop <- as.numeric(pop5) / (as.numeric(pct5) / 100)

    # population outside all zones (more than 20 min to a bathing site)
    rest_pop <- berlin_pop - as.numeric(pop20)
    rest_pct <- 100 - as.numeric(pct20)

    mode_icon <- if (input$mode == "cycling-regular") "bicycle" else "person-walking"
    mode_word <- if (input$mode == "cycling-regular") "mit Fahrrad" else "zu Fuß"

    # Top 3 des gewählten Modus als Ranking-Einstieg
    top3 <- shiny_lakes |>
      st_drop_geometry() |>
      filter(mode == input$mode, !is.na(rank)) |>
      arrange(rank) |>
      slice_head(n = 3)

    # Farben der Unterstreichung = Zonenfarben der Karte (modusabhängig)
    zone_colors <- if (input$mode == "cycling-regular") {
      c("A" = "#8C4BBE", "B" = "#BC96D9", "C" = "#D9C3E9")
    } else {
      c("A" = "#18C93E", "B" = "#5BEC7A", "C" = "#A4F4B5")
    }

    # compact row like tab 1: heading underlined in zone color (NULL = no underline),
    # numbers in dark teal, optional hint line below
    zone_row <- function(label, pct, pop, underline_col, col_main, col_sub, hint = NULL) {
      heading_style <- if (is.null(underline_col)) {
        "margin-bottom: 4px;"
      } else {
        paste0(
          "margin-bottom: 4px; text-decoration: underline; ",
          "text-decoration-thickness: 2px; text-underline-offset: 4px; ",
          "text-decoration-color: ", underline_col, ";"
        )
      }
      tagList(
        p(style = heading_style, label),
        p(
          style = "margin-top: 4px; margin-bottom: 0;",
          tags$span(
            style = paste0("font-size: 26px; font-weight: bold; color: ", col_main, ";"),
            paste0(format(round(pct, 1), big.mark = ".", decimal.mark = ","), " %")
          ),
          tags$span(
            style = paste0("font-size: 18px; color: ", col_sub, ";"),
            paste0(" · ", format(round(pop), big.mark = ".", decimal.mark = ","), " EW")
          )
        ),
        if (!is.null(hint)) {
          p(style = "font-size: 13px; font-weight: normal; font-style: italic; margin: 2px 0 0 0;", hint)
        },
        hr(style = "margin: 10px 0;")
      )
    }

    tagList(
      h3("Erreichbarkeitszonen um die Berliner Badestellen"),

      p(style = "font-size: 13px; font-weight: normal; font-style: italic",
        "Bevölkerung anteilig", tags$br(), icon(mode_icon), " ", mode_word),

      zone_row("Zone A - bis 5 Min.",  pct5,  pop5,    zone_colors["A"], "#00868B", "#006366"),
      zone_row("Zone B - bis 10 Min.", pct10, pop10,   zone_colors["B"], "#00868B", "#006366"),
      zone_row("Zone C - bis 20 Min.", pct20, pop20,   zone_colors["C"], "#00868B", "#006366"),
      zone_row("mehr als 20 Min.", rest_pct, rest_pop, "#EE6363", "#EE6363", "#EE6363",
               hint = "Bevölkerung, wohnhaft außerhalb der farbigen Zonen auf der Karte."),
      hr(),

      h4("Badestellen unter Druck"),
      p(tags$span(style = "font-size: 13px; font-weight: normal; font-style: italic",
                  icon("umbrella-beach"), " Top 3 – Rang 1 = höchster potenzieller Druck")),

      lapply(seq_len(nrow(top3)), function(i) {
        p(style = "margin: 2px 0; color: #15C8CF; font-weight: bold; font-size: 15px;",
          paste0("Rang ", i, ": ", top3$lake_name[i]))
      }),

      p("Methodik zur Berechnung des Drucks auf die Badestellen, siehe Tab 'Metadaten'.",
  tags$br(),
  "Gesamtes Ranking: siehe Tab 'Badestellen-Tabelle'",
  style = "font-size: 13px; font-weight: normal; font-style: italic; margin-top: 8px;")

    )
  })

  # ────────────────────────
  # Tab 3: Ortsteil-Tabelle (Challenges)
  # ────────────────────────
  output$ranking_sidebar <- renderUI({

    # Challenges beziehen sich fix auf Fahrrad – unabhängig vom Karten-Modus
    otd <- shiny_ortsteile |>
      st_drop_geometry() |>
      select(ortsteil, bezirk, pop_total, pop_density, area_km2,
             access = cycle_within_20_pct, pop_no = pop_cycle_not_within_20)

    fmt_pop2 <- function(x) format(round(x), big.mark = ".", decimal.mark = ",")
    fmt_dens <- function(x) format(round(x / 100, 1), big.mark = ".", decimal.mark = ",")

    # C1 (Fahrrad): 100 % Zugang, niedrigste Bevölkerungsdichte
    c1 <- otd |> filter(access >= 99.95) |> arrange(pop_density) |> slice_head(n = 1)
    # C2 (Fahrrad): 0 % Zugang, meisten EW ohne Zugang
    c2 <- otd |> filter(access == 0) |> arrange(desc(pop_no)) |> slice_head(n = 1)
    # C3 (zu Fuß): Anzahl Ortsteile mit (praktisch) 0 % Fuß-Zugang
    n_walk0 <- sum(shiny_ortsteile$walk_within_20_pct == 0)
    n_walk0_prac <- sum(round(shiny_ortsteile$walk_within_20_pct, 1) == 0)
    # C4 (zu Fuß): 100 % Fuß-Zugang, kleinster Ortsteil
    c4 <- shiny_ortsteile |>
      st_drop_geometry() |>
      filter(walk_within_20_pct >= 99.95) |>
      arrange(area_km2) |>
      slice_head(n = 1)
    # C5: Bezirk mit niedrigstem Zugang (Fahrrad + Fuß)
    c5 <- shiny_ortsteile |>
      st_drop_geometry() |>
      group_by(bezirk) |>
      summarise(
        pop = sum(pop_total),
        cycle_pct = 100 * sum(pop_cycle_within_20) / sum(pop_total),
        walk_pct = 100 * sum(pop_walk_within_20) / sum(pop_total),
        .groups = "drop"
      ) |>
      mutate(reach = cycle_pct + walk_pct) |>
      arrange(reach, desc(pop)) |>
      slice_head(n = 1)

    fmt_km2 <- function(x) format(round(x, 1), decimal.mark = ",")

    challenge_box <- function(title, task, col, nm, detail) {
      div(
        style = paste0("border: 2px solid ", col,
                       "; padding: 10px 12px; margin-bottom: 12px; border-radius: 4px;"),
        p(style = "margin-bottom: 4px; color: #00494C;",
          tags$strong(title)),
        p(style = "font-size: 15px; margin-bottom: 6px; color: #00494C;", task),
        tags$details(
          tags$summary("Lösung anzeigen"),
          div(style = "font-size: 16px; font-weight: bold; color: #00494C;", nm),
          p(style = "font-size: 15px; margin-bottom: 0; color: #00494C;", detail)
        )
      )
    }

    section_hdr <- function(icon_name, label) {
      h5(style = "color: #00494C; margin-bottom: 8px;",
         icon(icon_name), " ", tags$strong(label))
    }

    tagList(
      h3("Challenges"),
      hr(),
      p("Finden Sie die Antworten – sortieren und filtern Sie in der Ortsteil-Tabelle.",
        style = "font-size: 19px; margin-top: 10px;"),

      section_hdr("bicycle", "Fahrrad"),
      challenge_box(
        "Challenge 1",
        "Welcher Ortsteil ist besonders dünn besiedelt und außerdem gut mit Badestellen versorgt?",
        "#CD5555",
        c1$ortsteil[[1]],
        paste0("(", c1$bezirk[[1]], "): nur ", fmt_dens(c1$pop_density[[1]]), " EW/ha, aber ",
               round(c1$access[[1]]), " % Fahrrad-Zugang in 20 Min. (",
               fmt_pop2(c1$pop_total[[1]]), " EW).")
      ),
      challenge_box(
        "Challenge 2",
        "In welchem Ortsteil leben die meisten Menschen ohne erreichbare Badestelle(n) – per Fahrrad innerhalb von maximal 20 Minuten?",
        "#CD5555",
        c2$ortsteil[[1]],
        paste0("(", c2$bezirk[[1]], "): ", fmt_pop2(c2$pop_no[[1]]), " von ",
               fmt_pop2(c2$pop_total[[1]]), " EW ohne Badestelle in 20 Min. (0 % Zugang)")
      ),

      section_hdr("person-walking", "Zu Fuß"),
      challenge_box(
        "Challenge 3",
        "Für wie viele der 97 Berliner Ortsteile gibt es keine (oder praktisch keine) Badestellen, die in maximal 20 Minuten zu Fuß erreichbar sind?",
        "#8B3A3A",
        paste0(n_walk0_prac, " von 97 Ortsteilen"),
        paste0(n_walk0, " Ortsteile haben exakt 0 %, 2 weitere (Reinickendorf, Fennpfuhl) runden auf 0,0 %.")
      ),
      challenge_box(
        "Challenge 4",
        "In welchem Ortsteil können alle Einwohner*innen zu Fuß und in maximal 20 Minuten eine Badestelle erreichen? Was ist das Besondere an diesem Ortsteil?",
        "#8B3A3A",
        c4$ortsteil[[1]],
        paste0("(", c4$bezirk[[1]], "): mit nur ", fmt_km2(c4$area_km2[[1]]),
               " km² der zweitkleinste Ortsteil Berlins – Badestelle: Strandbad Halensee im angrenzenden Grunewald.")
      ),

      section_hdr("star", "Zusatzfrage"),
      challenge_box(
        "Challenge 5",
        "Die Bevölkerung welches Bezirks kann keine oder die wenigsten Badestellen erreichen (zu Fuß und/oder Fahrrad)?",
        "#00C5CD",
        c5$bezirk[[1]],
        paste0("0 % Zugang – weder zu Fuß noch mit dem Fahrrad (", fmt_pop2(c5$pop[[1]]),
               " EW). Kein anderer Bezirk liegt bei beiden Verkehrsmitteln bei 0 %.")
      )
    )
  })

  # ────────────────────────
  # Tab 3: Ortsteil-Tabelle
  # ────────────────────────
  output$ranking_table <- DT::renderDataTable({
    ot_rank <- shiny_ortsteile |>
      st_drop_geometry() |>
      transmute(
        Ortsteil = ortsteil,
        Bezirk = bezirk,
        `EW` = round(pop_total),
        `EW/ha` = round(pop_density / 100, 1),
        `Fläche (km²)` = round(area_km2, 2),
        `Anzahl Badestellen im Ortsteil` = lake_count,
        `Bevölkerungsanteil in % (mit Fahrrad in max. 20 Min.)` =
          round(cycle_within_20_pct, 1),
        `Bevölkerungsanteil in % (zu Fuß in max. 20 Min.)` =
          round(walk_within_20_pct, 1)
      ) |>
      arrange(Ortsteil)

    DT::datatable(
      ot_rank,
      rownames = FALSE,
      filter = "top",
      options = list(
        pageLength = 10,
        lengthMenu = c(10, 25, 50, 97),
        language = list(
          emptyTable = "Keine Daten",
          search = "Suchen:",
          lengthMenu = "Zeige _MENU_ Ortsteile",
          info = "Zeige _START_–_END_ von _TOTAL_ Ortsteilen",
          infoFiltered = "(gefiltert von _MAX_ Ortsteilen)",
          infoEmpty = "Keine Ortsteile",
          paginate = list(previous = "Zurück", `next` = "Weiter")
        )
      )
    )
  })

  # ────────────────────────
  # Tab 4: Badestellen-Tabelle (beide Modi nebeneinander)
  # ────────────────────────
  output$lakes_table <- DT::renderDataTable({
    lk <- shiny_lakes |>
      st_drop_geometry() |>
      select(lake_name, bezirk, ortsteil, mode, rank, pressure_share_pct, link)

    lk_c <- lk |> filter(mode == "cycling-regular") |> select(-mode)
    lk_w <- lk |>
      filter(mode == "foot-walking") |>
      select(lake_name, rank, pressure_share_pct)

    lk_tab <- lk_c |>
      left_join(lk_w, by = "lake_name", suffix = c(".cyc", ".walk")) |>
      transmute(
        Badestelle = lake_name,
        Bezirk = bezirk,
        Ortsteil = ortsteil,
        `Rang (Fahrrad)` = rank.cyc,
        `Rang (zu Fuß)` = rank.walk,
        `Druckanteil in % (Fahrrad)` = round(pressure_share_pct.cyc, 1),
        `Druckanteil in % (zu Fuß)` = round(pressure_share_pct.walk, 1),
        Link = if_else(
          is.na(link),
          NA_character_,
          paste0('<a href="', link, '" target="_blank">LAGESO</a>')
        )
      ) |>
      arrange(`Rang (Fahrrad)`, `Rang (zu Fuß)`)

    DT::datatable(
      lk_tab,
      rownames = FALSE,
      filter = "top",
      escape = FALSE,
      options = list(
        pageLength = 10,
        lengthMenu = c(10, 25, 50, 39),
        language = list(
          emptyTable = "Keine Daten",
          search = "Suchen:",
          lengthMenu = "Zeige _MENU_ Badestellen",
          info = "Zeige _START_–_END_ von _TOTAL_ Badestellen",
          infoFiltered = "(gefiltert von _MAX_ Badestellen)",
          infoEmpty = "Keine Badestellen",
          paginate = list(previous = "Zurück", `next` = "Weiter")
        )
      )
    )
  })

  # ────────────────────────
  # Tab 4 Sidebar: Badestellen-Challenges
  # ────────────────────────
  output$lakes_sidebar <- renderUI({

    lk <- shiny_lakes |>
      st_drop_geometry() |>
      select(lake_name, bezirk, ortsteil, mode, rank, pressure_share_pct, link)
    lk_c <- lk |> filter(mode == "cycling-regular") |> select(-mode)
    lk_w <- lk |>
      filter(mode == "foot-walking") |>
      select(lake_name, rank, pressure_share_pct)
    lk_tab <- lk_c |>
      left_join(lk_w, by = "lake_name", suffix = c(".cyc", ".walk"))

    fmt_pct <- function(x) format(round(x, 1), big.mark = ".", decimal.mark = ",")

    challenge_box <- function(title, task, col, nm, detail) {
      div(
        style = paste0("border: 2px solid ", col,
                       "; padding: 10px 12px; margin-bottom: 12px; border-radius: 4px;"),
        p(style = "margin-bottom: 4px; color: #00494C;",
          tags$strong(title)),
        p(style = "font-size: 15px; margin-bottom: 6px; color: #00494C;", task),
        tags$details(
          tags$summary("Lösung anzeigen"),
          div(style = "font-size: 16px; font-weight: bold; color: #00494C;", nm),
          p(style = "font-size: 15px; margin-bottom: 0; color: #00494C;", detail)
        )
      )
    }

    section_hdr <- function(icon_name, label) {
      h5(style = "color: #00494C; margin-bottom: 8px;",
         icon(icon_name), " ", tags$strong(label))
    }

    # B1: stärkster Rang-Gewinn Fahrrad vs. Fuß
    b1 <- lk_tab |>
      filter(!is.na(rank.walk)) |>
      mutate(gain = rank.walk - rank.cyc) |>
      arrange(desc(gain)) |>
      slice_head(n = 1)
    # B2: Top 3 Druckanteil zu Fuß
    b2 <- lk_tab |>
      arrange(desc(pressure_share_pct.walk)) |>
      slice_head(n = 3)
    # B3: zu Fuß ungerankte Badestellen
    b3 <- lk_tab |> filter(is.na(rank.walk))

    tagList(
      h3("Challenges"),
      hr(),
      p("Finden Sie die Antworten – sortieren und filtern Sie in der Badestellen-Tabelle.",
        style = "font-size: 19px; margin-top: 10px;"),

      section_hdr("water", "Badestellen"),
      challenge_box(
        "Challenge B1",
        "Welche Badestelle klettert im Ranking am stärksten, wenn man statt zu Fuß das Fahrrad nimmt?",
        "#B452CD",
        b1$lake_name[[1]],
        paste0("(", b1$bezirk[[1]], "): Rang ", b1$rank.walk[[1]], " zu Fuß, aber Rang ",
               b1$rank.cyc[[1]], " mit dem Fahrrad – ", b1$gain[[1]], " Plätze besser.")
      ),
      challenge_box(
        "Challenge B2",
        "Welche drei Badestellen haben zu Fuß den höchsten Druckanteil?",
        "#00868B",
        paste(b2$lake_name, collapse = ", "),
        paste0("zu Fuß: ", fmt_pct(b2$pressure_share_pct.walk[[1]]), " %, ",
               fmt_pct(b2$pressure_share_pct.walk[[2]]), " %, ",
               fmt_pct(b2$pressure_share_pct.walk[[3]]), " % der Berliner Bevölkerung.")
      ),
      challenge_box(
        "Challenge B3",
        "Drei Badestellen sind zu Fuß nicht gerankt. Welche sind es – und warum?",
        "#EE6363",
        paste(b3$lake_name, collapse = ", "),
        paste0("In ihren 20-Minuten-Fuß-Zonen liegt keine Bevölkerung (Bezirke: ",
               paste(unique(b3$bezirk), collapse = ", "), ").")
      )
    )
  })
}

shinyApp(ui, server)

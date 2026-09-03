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

    details summary { cursor: pointer; color: #006366; font-size: 14px; }
    details summary:hover { color: #00494C; }
  ")),

  # ── App title ─────────────────────────────────────────
  div(
    h1("Berliner Badestellen"),
    h4("Thematische Karten zur Analyse der Erreichbarkeit.")
  ),

  # ── Shared travel mode switch (above the map area) ─────
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
          tmapOutput("iso_map", height = "880px")
        ),

        # Tab 3: Ranking table
        tabPanel(
          title = "Ortsteil-Tabelle",
          value = "ranking",
          h3("Alle Ortsteile im Vergleich"),
          hr(),
          p("Sortieren Sie per Klick auf die Spalten\u00fcberschrift und filtern Sie \u00fcber die Suchfelder.",
            style = "color: #6c757d;"),
          DT::dataTableOutput("ranking_table")
        ),

        # Tab 4: Metadaten
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
        col = "indianred1",
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
      tm_borders(col = "darkslategrey", lwd = 1) +

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
        p("Klicken Sie auf einen Ortsteil oder eine Badestelle, um Details anzuzeigen."),
        p("Die Verkehrsmittelauswahl (Fahrrad / Zu Fuß) ändert die angezeigten Werte.")
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
           style = "font-size: 0.85em; font-weight: normal; font-style: italic",
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
      legend_title <- "Erreichbarkeit per Fahrrad"
    } else {
      ring_colors <- c(
        "Zone A (bis zu 5 Min.)"  = "#18C93E",
        "Zone B (bis zu 10 Min.)" = "#5BEC7A",
        "Zone C (bis zu 20 Min.)" = "#A4F4B5"
      )
      legend_title <- "Erreichbarkeit zu Fuß"
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

      # lakes (gravity-sized bubbles with rank)
      tm_shape(lakes) +
      tm_bubbles(
        size = "gravity_visual",
        fill = "cyan2",
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

      # manual legend entry: bubble size = potential bathing pressure
      tm_add_legend(
        type = "symbol",
        title = "Badestellen",
        labels = paste0(
          "Kreisgr\u00f6\u00dfe = potenzieller Druck auf die Badestelle\n",
          "(Bev\u00f6lkerung im Umfeld, Konkurrenz, Fahrzeit \u2013 Details siehe Metadaten)"
        ),
        fill = "cyan2",
        border_col = "darkslategrey",
        border_lwd = 2,
        shape = 21
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

    # compact row: icon + label, then "x % · y EW" on one line
    zone_row <- function(label, pct, pop, col_main, col_sub) {
      tagList(
        p(icon(mode_icon), " ", label),
        p(
          style = "margin-top: 4px;",
          tags$span(
            style = paste0("font-size: 26px; font-weight: bold; color: ", col_main, ";"),
            paste0(format(round(pct, 1), big.mark = ".", decimal.mark = ","), " %")
          ),
          tags$span(
            style = paste0("font-size: 18px; color: ", col_sub, ";"),
            paste0(" · ", format(round(pop), big.mark = ".", decimal.mark = ","), " EW")
          )
        ),
        hr()
      )
    }

    tagList(
      h3("Erreichbarkeit der Berliner Badestellen"),
      hr(),
      
      h4("Anteil der Bevölkerung nach Erreichbarkeitszone"),
      hr(),
      
      zone_row("Zone A - bis 5 Min.",  pct5,  pop5,    "#00868B", "#006366"),
      zone_row("Zone B - bis 10 Min.", pct10, pop10,   "#00868B", "#006366"),
      zone_row("Zone C - bis 20 Min.", pct20, pop20,   "#00868B", "#006366"),
      zone_row("mehr als 20 Min.",     rest_pct, rest_pop, "#EE6363", "#EE6363"),
      
      p(paste0("Gesamtbevölkerung Berlin laut Datenbasis (2025): 3,9 Mio. (",
               format(round(berlin_pop), big.mark = ".", decimal.mark = ","),
               " EW)"))
    )
  })

  # ────────────────────────
  # Tab 3: Ortsteil-Tabelle (Challenges)
  # ────────────────────────
  output$ranking_sidebar <- renderUI({

    req(input$mode)

    mode_word <- if (input$mode == "cycling-regular") "mit dem Fahrrad" else "zu Fu\u00df"
    access_col <- if (input$mode == "cycling-regular") "cycle_within_20_pct" else "walk_within_20_pct"
    pop_no_col <- if (input$mode == "cycling-regular") "pop_cycle_not_within_20" else "pop_walk_not_within_20"
    otd <- shiny_ortsteile |>
      st_drop_geometry() |>
      select(ortsteil, bezirk, pop_total, pop_density,
             access = all_of(access_col), pop_no = all_of(pop_no_col))

    # Wüste: kein Zugang, höchste Bevölkerung ohne Zugang
    worst <- otd |> filter(access == 0)     |> arrange(desc(pop_no))     |> slice_head(n = 1)
    # Bestversorgt: 100 % Zugang, niedrigste Einwohnerdichte
    best  <- otd |> filter(access >= 99.95) |> arrange(pop_density)     |> slice_head(n = 1)

    fmt_pop2 <- function(x) format(round(x), big.mark = ".", decimal.mark = ",")

    challenge_box <- function(icon_name, title, task, border_col, bg_col, nm, detail) {
      div(
        style = paste0("border-left: 5px solid ", border_col,
                       "; background-color: ", bg_col,
                       "; padding: 10px 12px; margin-bottom: 12px; border-radius: 4px;"),
        p(style = "margin-bottom: 4px; color: #00494C;",
          icon(icon_name), " ", tags$strong(title)),
        p(style = "font-size: 15px; margin-bottom: 6px; color: #00494C;", task),
        tags$details(
          tags$summary("L\u00f6sung anzeigen"),
          div(style = "font-size: 16px; font-weight: bold; color: #00494C;", nm),
          p(style = "font-size: 15px; margin-bottom: 0; color: #00494C;", detail)
        )
      )
    }

    tagList(
      h4(icon("trophy"), " Deine Challenge"),
      hr(),
      p("Finden Sie die Extreme selbst \u2013 sortieren und filtern Sie in der Ortsteil-Tabelle dieses Tabs."),
      challenge_box(
        "sun",
        "Challenge 1: Finde die Erreichbarkeits-W\u00fcste",
        paste0("Welcher Ortsteil hat ", mode_word,
               " die meisten Einwohner*innen ohne Badestelle in 20 Minuten?"),
        "#EE6363", "#FDECEC",
        worst$ortsteil[[1]],
        paste0("(", worst$bezirk[[1]], "): ",
               fmt_pop2(worst$pop_no[[1]]), " von ", fmt_pop2(worst$pop_total[[1]]),
               " EW ohne Zugang")
      ),
      challenge_box(
        "medal",
        "Challenge 2: Finde den bestversorgten Ortsteil",
        paste0("Welcher Ortsteil ist am d\u00fcnnsten besiedelt und hat ", mode_word,
               " trotzdem 100 % Zugang in 20 Minuten?"),
        "#00868B", "#E1F0F1",
        best$ortsteil[[1]],
        paste0("(", best$bezirk[[1]], "): ",
               fmt_pop2(best$pop_total[[1]]), " EW \u00b7 ",
               format(round(best$pop_density[[1]] / 100, 1),
                      big.mark = ".", decimal.mark = ","), " EW/ha")
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
        `Badestellen im Ortsteil` = lake_count,
        `Zugang Fahrrad (% in 20 Min.)` = round(cycle_within_20_pct, 1),
        `EW ohne Zugang (Fahrrad)` = round(pop_cycle_not_within_20),
        `Zugang zu Fuß (% in 20 Min.)` = round(walk_within_20_pct, 1),
        `EW ohne Zugang (zu Fuß)` = round(pop_walk_not_within_20)
      ) |>
      arrange(desc(`EW ohne Zugang (Fahrrad)`))

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
          info = "Zeige _START_\u2013_END_ von _TOTAL_ Ortsteilen",
          infoFiltered = "(gefiltert von _MAX_ Ortsteilen)",
          infoEmpty = "Keine Ortsteile",
          paginate = list(previous = "Zur\u00fcck", `next` = "Weiter")
        )
      )
    )
  })
}

shinyApp(ui, server)

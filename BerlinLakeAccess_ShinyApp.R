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
  
  # ─────────────────────────────────────────────────────────
  # App title
  # ─────────────────────────────────────────────────────────
  
  div(
    h1("Bathing Sites in Berlin"),
    h4("Unequal Access and Potential Demand")
  ),
  

  # ─────────────────────────────────────────────────────────
  # Main layout
  # ─────────────────────────────────────────────────────────
  
  sidebarLayout(
    
    # ── Sidebar STATISTICS WHATEVER─────────────────────────
    
    sidebarPanel(
      width = 3,
      uiOutput("sidebar_content")
    ),
    
    
    # ── Main content MAPS ───────────────────────────────────
    
    mainPanel(
      width = 9,
      
      tabsetPanel(
        id = "map_tab",
        
        # Tab 1 Bezirke
        tabPanel(
          title = "Berlin Districts",
          value = "map1",
          tmapOutput("bezirke_map", height="800px")
        ),
        
        # Tab 2 Ortsteile
        tabPanel(
          title = "Berlin Ortsteile",
          value = "map2",
          tmapOutput("ortsteile_map", height="800px")
        ),
        
        # Tab 3 Bathing Sites
        tabPanel(
          title = "Bathing Sites",
          value = "map3",
          tmapOutput("lake_map", height="800px"),
        )
      )
    )
  )
)


# ─────────────────────────────────────────────────────────
# SERVER
# ─────────────────────────────────────────────────────────
server <- function(input, output, session) {
  
  # ── TEST: alle Click-Inputs ausgeben ─────────────────────
  # activate this code whenever needed
  # observe({
  #   clicks <- reactiveValuesToList(input)
  #   clicks <- clicks[grepl("click", names(clicks), ignore.case = TRUE)]
  #   # nur ausgeben, wenn ein Click-Input tatsächlich einen Wert hat
  #   has_val <- vapply(clicks, function(x) !is.null(x) && length(x) > 0, logical(1))
  #   if (any(has_val)) {
  #     print(clicks[has_val])
  #   }
  # })

  # ─────────────────────────────────────────────────────────
  # SIDEBARS CHANGING DEPENDING ON MAP
  # ─────────────────────────────────────────────────────────
  
  output$sidebar_content <- renderUI({
    
    if (input$map_tab == "map1") {
      
      tagList(
        
        h4("Berlin Districts: Find Title"),
        hr(),
        h5("Information"),
        p("Select a Travel mode and click a district on the map."),
        hr(),
        selectInput(
          inputId = "mode_1",
          label = "Travel mode:",
          choices = c(
            "Cycling" = "cycling-regular",
            "Walking" = "foot-walking"
          ),
          selected = "cycling-regular"
        ),
        hr(),
        uiOutput("selected_bezirk_info"),
        hr(),
        
      )
      
    } else if (input$map_tab == "map2") {
      
      tagList(
        
        h4("Berliner Ortsteile und Badestellen"),
        hr(),
          p("Wähle Ortsteil oder Badestelle auf der Karte und erfahre mehr."),
        hr(),
            selectInput(
              inputId = "mode_2",
              label = "Travel mode:",
              choices = c(
                "Cycling" = "cycling-regular",
                "Walking" = "foot-walking"
              ),
              selected = "cycling-regular"
            ),
        hr(),
        h3("Informationen zum gewählten Ortsteil"),
        uiOutput("selected_ortsteil_info"),
        hr(),
        h3("Informationen zur gewählten Badestellen"),
        uiOutput("selected_lake_info"),
        hr(),
        
        
      )
      
    } else if (input$map_tab == "map3") {
      
      tagList(
        
        h4("Bathing Sites Ranking"),
        p("Lake rankings reflect potential visitor pressure based on local population, walking or cycling travel time, and competition from other accessible lakes."),
        p("Rank 1 indicates the highest potential visitor pressure, not the best or most desirable lake."),
        hr(),
        selectInput(
          inputId = "mode_3",
          label = "Travel mode:",
          choices = c(
            "Cycling" = "cycling-regular",
            "Walking" = "foot-walking"
          ),
          selected = "cycling-regular"
        )
        
      )
    }
  })
  
  
  # ─────────────────────────────────────────────────────────
  # MAP RENDERING
  # ─────────────────────────────────────────────────────────
  
  
    # ────────────────────────
    # Lakes
    # ────────────────────────
  output$lake_map <- renderTmap({
    
    req(input$mode_3)
    
    # get iso and its color depening on travel mode
    if (input$mode_3 == "cycling-regular") {
      iso <- shiny_iso_cycle_20
      iso_fill <- "darkseagreen"
    } else {
      iso <- shiny_iso_walk_20
      iso_fill <- "khaki"
    }
    
    # prepare lakes layer
    lakes <- shiny_lakes |>
      # =inputID
      filter(mode == input$mode_3) |> 
      # popup html for links
      mutate(
        rank_visual = max(rank, na.rm = TRUE) - rank + 1,
        url_html = paste0(
          '<span style="padding-left: 10px;">',
          '<a href="', link, '" ',
          'target="_blank" rel="noopener noreferrer">',
          'Details →',
          '</a>',
          '</span>'
        )
      )
    
    # lakes ranking reverse for visualisation in scale
    n_ranked <- max(lakes$rank_visual, na.rm = TRUE)
    
    # map
    tm_basemap("CartoDB.Positron") +
      
      tm_shape(iso) +
      tm_polygons(
        fill = iso_fill,
        fill_alpha = 0.25,
        lwd = 0
      ) +
      
      tm_shape(lakes) +
      tm_bubbles(
        size = tm_const(),
        
        fill = "rank_visual",
        fill_alpha = 0.8,
        fill.scale = tm_scale_continuous(
          values = c("#B2EBF2", "#006064"),
          ticks = c(1, n_ranked),
          labels = c("Lower", "Higher")
        ),
        fill.legend = tm_legend(
          title = "Potential visitor pressure"
        ),
        col = NA,
        
        hover = "lake_name",
        popup = tm_popup(
          vars = c(
            "Rank" = "rank_label",
            "More info" = "url_html"
          ),
          title = "lake_name",
          format = tm_label_format(
            html.escape = FALSE
          )
        )
      ) +
      
      tm_view(
        set_view = c(13.405, 52.52, 10)
      )
    
  })
  
  
  
    # ────────────────────────
    # Bezirke
    # ────────────────────────
  
  output$bezirke_map <- renderTmap({
    
    req(input$mode_1)
    
    # ── 1. DEFINE VARIABLES DEPENDING ON TRAVEL MODE ─
    
    if (input$mode_1 == "cycling-regular") {
      over_20_pct <- "cycle_not_within_20_pct"
      within_20_pct <- "cycle_within_20_pct"
      fill_values <- c("#54FF9F", "#2E8B57")
      legend_title <- "Resident share over 20 min — Cycling"
      map_title <- "Berlin Districts: Share of residents more than 20 minutes from an official bathing site - Cycling"
    } else {
      over_20_pct <- "walk_not_within_20_pct"
      within_20_pct <- "walk_within_20_pct"
      fill_values <- c("khaki2", "khaki4")
      legend_title <- "Resident share over 20 min — Walking"
      map_title <- "Berlin Districts: Share of residents more than 20 minutes from an official bathing site - Walking"
    }
    
    
    # ── 2. DEFINE POPUP VARIABLES AND STYLE ──
    
    popup_data <- shiny_bezirke |>
      mutate(
        within_20_label = paste0(.data[[within_20_pct]], "%"),
        over_20_label = paste0(.data[[over_20_pct]], "%")
      )
    
    # ── 3. MAP ──
    
    tm_basemap("CartoDB.Positron") +
      
      tm_shape(popup_data) +
      
      tm_polygons(
        
        fill = over_20_pct,
        fill.scale = tm_scale_continuous(
          values = fill_values,
          ticks = c(0, 25, 50, 75, 100),
          labels = c("0%", "25%", "50%", "75%", "100%")
        ),
        fill.legend = tm_legend(
          title = legend_title
        ),
        fill_alpha = 0.8,
        col = "white",
        lwd = 1,
        
        id = "bezirk",
        hover = "bezirk",
        
        popup = tm_popup(
          vars = c(
            "Population" = "pop_total",
            "Population density" = "pop_density",
            "Bathing sites in district" = "lake_count",
            "Resident share within 20 min" = "within_20_label",
            "Resident share over 20 min" = "over_20_label"
          ),
          title = "bezirk"
        )
        
      ) +
      
      tm_title(map_title) +
      
      tm_view(set_view = c(13.405, 52.52, 10))
    
  })
  
  
    # ────────────────────────
    # Ortsteile
    # ────────────────────────
  
  output$ortsteile_map <- renderTmap({
    
    req(input$mode_2)
    
    # ── 1. DEFINE VARIABLES DEPENDING ON TRAVEL MODE ─
    
    if (input$mode_2 == "cycling-regular") {
      over_20_pct <- "cycle_not_within_20_pct"
      within_20_pct <- "cycle_within_20_pct"
      fill_values <- c("#54FF9F", "#2E8B57")
      legend_title <- "Resident share over 20 min — Cycling"
      map_title <- "Berlin Ortsteile: Share of residents more than 20 minutes from an official bathing site - Cycling"
      
    } else {
      over_20_pct <- "walk_not_within_20_pct"
      within_20_pct <- "walk_within_20_pct"
      fill_values <- c("khaki2", "khaki4")
      legend_title <- "Resident share over 20 min — Walking"
      map_title <- "Berlin Ortsteile: Share of residents more than 20 minutes from an official bathing site - Walking"
      
    }
    
    bezirksgrenzen <- shiny_bezirke
    lakes <- filter(shiny_lakes, mode == input$mode_2)
    
    
    
    # ── 2. DEFINE POPUP VARIABLES AND STYLE ──
    
    popup_data <- shiny_ortsteile |>
      mutate(
        within_20_label = paste0(.data[[within_20_pct]], "%"),
        over_20_label = paste0(.data[[over_20_pct]], "%")
      )
    
    
    # ── 3. MAP ──
    
    tm_basemap("CartoDB.Positron") +
      
      tm_shape(popup_data) +
      tm_polygons(
        
        fill = over_20_pct,
        fill.scale = tm_scale_continuous(
          values = fill_values,
          ticks = c(0, 25, 50, 75, 100),
          labels = c("0%", "25%", "50%", "75%", "100%")
        ),
        fill.legend = tm_legend(
          title = legend_title
        ),
        fill_alpha = 0.75,
        
        col = "white",
        col_alpha = 0.5,
        lwd = 1,
        
        id = "ortsteil",
        hover = "ortsteil",
        
        popup = tm_popup(
          vars = c(
            "Population" = "pop_total",
            "Population density" = "pop_density",
            "Bathing sites in Ortsteil" = "lake_count",
            "Resident share within 20 min" = "within_20_label",
            "Resident share over 20 min" = "over_20_label"
          ),
          title = "ortsteil"
        )
        
      ) +
      
      tm_shape(bezirksgrenzen) +
        tm_borders("#2F4F4F", lwd = 2) +
      
      tm_shape(lakes) + 
        tm_bubbles(
          id = "lake_name",
          fill = "#00BFFF",
          hover = "lake_name",
        ) +
      
      
      
      tm_title(map_title) +
      
      tm_view(set_view = c(13.405, 52.52, 10))
  
    
    
  })
  
  # ─────────────────────────────────────────────────────────
  # REACTIVE ELEMENTS
  # ─────────────────────────────────────────────────────────
  
  # ── Selections ──
  
  # Bezirk
  selected_bezirk <- reactive({
    
    req(input$bezirke_map_shape_click$id)
    
    clicked_bezirk <- input$bezirke_map_shape_click$id
    
    # tmap replaces hyphens with underscores in the feature ID; reverse that
    # by matching against the known bezirk names (none of which contain underscores)
    clicked_bezirk <- shiny_bezirke$bezirk[
      gsub("-", "_", shiny_bezirke$bezirk) == clicked_bezirk
    ]
    
    shiny_bezirke |>
      filter(bezirk == clicked_bezirk)
  })
  
  
  # Ortsteil
  selected_ortsteil <- reactive({
    
    req(input$ortsteile_map_shape_click$id)
    
    clicked_ortsteil <- input$ortsteile_map_shape_click$id
    
    # tmap replaces hyphens with underscores in the feature ID; reverse that
    # by matching against the known ortsteil names (none of which contain underscores)
    clicked_ortsteil <- shiny_ortsteile$ortsteil[
      gsub("-", "_", shiny_ortsteile$ortsteil) == clicked_ortsteil
    ]
    
    shiny_ortsteile |>
      filter(ortsteil == clicked_ortsteil)
  })
  
  
  # Lake
  selected_lake <- reactive({
    req(input$ortsteile_map_marker_click$id)
    req(input$mode_2)
    
    clicked_lake <- input$ortsteile_map_marker_click$id
    
    # tmap replaces every non-alphanumeric char (spaces, commas) with underscores;
    # reverse that by matching against the encoded lake names
    clicked_lake <- shiny_lakes$lake_name[
      gsub("[^[:alnum:]]", "_", shiny_lakes$lake_name) == clicked_lake
    ]
    
    shiny_lakes |>
      filter(lake_name == clicked_lake, mode == input$mode_2) |>
      mutate(
        url_html = paste0(
          '<a href="', link, '" ',
          'target="_blank" rel="noopener noreferrer">',
          'Details →',
          '</a>'
        )
      )
  })
  
  
  
  # ── Reactive Output ──
  
  # Bezirk
  output$selected_bezirk_info <- renderUI({
    
    req(input$bezirke_map_shape_click$id)
    req(input$mode_1)
    
    bezirk_name <- selected_bezirk()$bezirk[[1]]
    
    if (input$mode_1 == "cycling-regular") {
      access_pct <- selected_bezirk()$cycle_not_within_20_pct[[1]]
      access_label <- "Residents over 20 min by bicycle"
    } else {
      access_pct <- selected_bezirk()$walk_not_within_20_pct[[1]]
      access_label <- "Residents over 20 min on foot"
    }
    
    div(
      h4(bezirk_name),
      h2(paste0(access_pct, "%")),
      p(access_label)
    )
    
  })
  
  # Ortsteil
  output$selected_ortsteil_info <- renderUI({
    
    req(input$ortsteile_map_shape_click$id)
    req(input$mode_2)
    
    ortsteil_name <- selected_ortsteil()$ortsteil[[1]]
    
    if (input$mode_2 == "cycling-regular") {
      access_pct <- selected_ortsteil()$cycle_not_within_20_pct[[1]]
      access_label <- "Residents over 20 min by bicycle"
    } else {
      access_pct <- selected_ortsteil()$walk_not_within_20_pct[[1]]
      access_label <- "Residents over 20 min on foot"
    }
    
    div(
      h4(ortsteil_name),
      h2(paste0(access_pct, "%")),
      p(access_label)
    )
    
  })
  
  
  # Lake
  output$selected_lake_info <- renderUI({
    
    req(input$ortsteile_map_marker_click$id)
    req(input$mode_2)
    
    lake <- selected_lake()
    
    div(
      h4(lake$lake_name[[1]]),
      h5(lake$rank_label[[1]]),
      HTML(lake$url_html[[1]])
    )
    
  })
  
  
}

shinyApp(ui, server)









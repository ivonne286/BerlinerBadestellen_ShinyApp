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
          title = "Map 2",
          value = "map2",
          h3("Map 2"),
          div(
            style = "height: 1000px; background-color: #f5f5f5;",
            "Map 2"
          )
        ),
        
        # Tab 3 Bathing Sites
        tabPanel(
          title = "Bathing Sites",
          value = "map3",
          tmapOutput("lake_map", height = "800px"),
        )
      )
    )
  )
)


# ─────────────────────────────────────────────────────────
# SERVER
# ─────────────────────────────────────────────────────────
server <- function(input, output, session) {
  
  # ─────────────────────────────────────────────────────────
  # SIDEBARS CHANGING DEPENDING ON MAP
  # ─────────────────────────────────────────────────────────
  
  output$sidebar_content <- renderUI({
    
    if (input$map_tab == "map1") {
      
      tagList(
        
        h4("Berlin Districts: Access to Bathing Sites"),
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
        
        h4("Map 2"),
        
        h5("Statistics"),
        
        p("Placeholder for statistics"),
        
        hr(),
        
        selectInput(
          "map2_variable",
          "Variable:",
          choices = c(
            "Variable A",
            "Variable B"
          )
        )
        
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
  
  
  # ─────────────────────────────────────────────────────────
  # REACTIVE ELEMENTS
  # ─────────────────────────────────────────────────────────
  
  # ── Selections ──
  
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
  
  
  
  # ── Reactive Output ──
  
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
  
  
}

shinyApp(ui, server)









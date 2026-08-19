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
          title = "Bezirke",
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
        
        h4("Map 1"),
        h5("Statistics"),
        p("Placeholder for statistics"),
        hr(),
        selectInput(
          inputId = "mode_1",
          label = "Travel mode:",
          choices = c(
            "Cycling" = "cycling-regular",
            "Walking" = "foot-walking"
          ),
          selected = "cycling-regular"
        )
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
    
    # define map vars depending on travel mode
    if (input$mode_1 == "cycling-regular") {
      access_var <- "cycle_within_20_pct"
      fill_values <- c("#54FF9F", "#2E8B57")
      legend_title <- "max 20-min cycling access"
    } else {
      access_var <- "walk_within_20_pct"
      fill_values <- c("khaki2", "khaki4")
      legend_title <- "max 20-min walking access"
    }
    
    # map
    tm_basemap("CartoDB.Positron") +
      
      tm_shape(shiny_bezirke) +
      tm_polygons(
        fill = access_var,
        fill.scale = tm_scale_continuous(
          values = fill_values,
          ticks = c(0, 100),
          labels = c("Lower", "Higher")
        ),
        fill.legend = tm_legend(
          title = legend_title
        ),
        fill_alpha = 0.8,
        col = "white",
        lwd = 1,
        
        hover = "bezirk",
        popup = tm_popup(
          vars = c(
            "Population" = "pop_total",
            "Pop. Density" = "pop_density",
            "Amount of Bathing Sites (BS): " = "lake_count",
            "Shortest average Distance to any Lake (km)" = "nearest_dist_lake_km"
          ),
          title = "bezirk"
        )
      ) +
      
      tm_view(
        set_view = c(13.405, 52.52, 10)
      )
    
  })
}

shinyApp(ui, server)









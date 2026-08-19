library(shiny)
library(sf)
library(dplyr)
library(tmap)
library(tmap.mapgl)

# load data
load("data/shiny_data.RData")

# tmap mode
tmap_mode("view")


# --------------
# USER INTERFACE
# --------------

ui <- fluidPage(
  titlePanel("Bathing Sites – Inequality of Access across Berlin"),
  
  # Dropdown input by user: travel mode
  selectInput(
    inputId = "mode",
    label = "Travel mode:",
    choices = c(
      "Cycling" = "cycling-regular",
      "Walking" = "foot-walking"
    ),
    selected = "cycling-regular"
  ),
  
  # Map output
  tmapOutput("lake_map", height = "750px")
)


# ------
# SERVER
# ------

server <- function(input, output, session) {
  
  # Map output + Dropdown input
  output$lake_map <- renderTmap({
    
    # prepare lakes layer
    lakes <- shiny_lakes |>
      # =inputID
      filter(mode == input$mode) |> 
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
    
    # isochrones for background depending on input mode
    iso <- if (input$mode == "foot-walking") {
      shiny_iso_walk_20
    } else {
      shiny_iso_cycle_20
    }
    
    # BUILD MAP
    tm_basemap("CartoDB.Positron") +
      
      tm_shape(iso) +
      tm_polygons(
        fill = "lavenderblush",
        fill_alpha = 0.3,
        col = "lavenderblush4",
        lwd = 1
      ) +
      
      tm_shape(lakes) +
      tm_bubbles(
        size = tm_const(),
        
        fill = "rank_visual",
        fill.scale = tm_scale_continuous(
          values = c("#B2EBF2", "#006064"),
          ticks = c(1, n_ranked),
          labels = c("Lower", "Higher")
        ),
        fill.legend = tm_legend(
          title = "Potential visitor pressure"
        ),
        
        col = "blue4",
        col_alpha = 0.8,
        lwd = 1,
        
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
        set.view = c(13.405, 52.52, 10)
      )
  })
}


# ---------
# SHINY APP
# ---------
shinyApp(ui, server)


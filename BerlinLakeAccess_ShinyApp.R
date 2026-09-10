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
    /* Layout: linke Sidebar 20 %, Hauptbereich füllt den Rest */
    .left-sidebar {
      flex: 0 0 20vw;
      margin-left: 16px;
      min-height: 0;
      max-height: none;
      overflow-y: auto;
      align-self: stretch;
    }
    .main-column {
      flex: 1 1 auto;
      min-width: 0;
    }

    /* Einheitlicher Sidebar-Style (Hintergrund, Rahmen, Unterkante) */
    .left-sidebar {
      background-color: #F5F5F5;
      border: 1px solid #E3E3E3;
      border-radius: 4px;
      padding: 20px;
    }

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
    /* Button Zur Karte: Hover wie die Navigation */
    #go_to_map:hover {
      background-color: #CDE4E5 !important;
      color: #00494C !important;
      border-color: #00868B !important;
    }
    .tabbable > .nav { display: flex; }
    .tabbable > .nav > li { flex: 1 1 0; text-align: center; }
    .tabbable > .nav > li > a { text-align: center; }

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
      height: 3px; width: 420px; margin: 14px auto 0 auto; border: 0;
      background: linear-gradient(90deg, #00868B, #EE6363);
      border-radius: 4px;
    }

    details summary { cursor: pointer; color: #006366; font-size: 14px; }
    details summary:hover { color: #00494C; }

    /* Outline-Navigation im Metadaten-Tab */
    .meta-nav ul { margin-bottom: 0; }
    .meta-nav li { margin-bottom: 6px; }
    .meta-nav a {
      color: #006366;
      text-decoration: none;
      font-size: 14px;
      display: block;
      padding: 4px 8px;
      border-radius: 3px;
    }
    .meta-nav a:hover {
      background-color: #CDE4E5;
      color: #00494C;
      text-decoration: none;
    }
    .meta-section-title {
      color: #00868B;
      font-size: 20px;
      font-weight: bold;
      margin-top: 8px;
      margin-bottom: 8px;
    }

    /* Start-Tab: eigene Layout-Klasse, darf natürlich hoch sein */
    .start-tab-layout {
      display: block;
      padding: 40px 0 10px 0;
    }
    .start-tab-layout .map-wrap > div {
      width: 100%;
      max-width: 1400px;
      margin: 0 auto;
    }

    /* Karten-Tab: Karte + graue Infobox nebeneinander */
    .map-tab-layout {
      display: flex;
      gap: 16px;
      align-items: flex-start;
      height: calc(100vh - 200px);      /* dynamische Höhe: Viewport abzüglich Titel+Tabs */
      min-height: 560px;
    }
    .map-tab-layout .map-wrap {
      flex: 1 1 auto;
      min-width: 0;
      height: 100%;
      min-height: 560px;
    }
    .map-tab-layout .map-wrap .shiny-tmap,
    .map-tab-layout .map-wrap .leaflet,
    .map-tab-layout .map-wrap .mapboxgl-map {
      height: 100% !important;
      min-height: 560px;
    }
    .iso-box {
      width: 20vw;
      flex: 0 0 20vw;
      background-color: #F5F5F5;
      border: 1px solid #E3E3E3;
      border-radius: 4px;
      padding: 20px;
      height: 100%;
      min-height: 560px;
      overflow-y: auto;
    }

    /* 15-Zoll-Laptops und kleiner: Seitbars etwas schmaler */
    @media (max-width: 1400px) {
      .left-sidebar { flex: 0 0 18vw; }
      .iso-box {
        flex: 0 0 18vw;
        padding: 16px;
      }
    }

    /* sehr kleine Laptops: Seitbars minimal schmaler, etwas weniger Padding */
    @media (max-width: 1200px) {
      .left-sidebar { flex: 0 0 16vw; }
      .iso-box {
        flex: 0 0 16vw;
        padding: 14px;
      }
    }

  ")),

  # ── App title ─────────────────────────────────────────
  div(
    class = "app-title",
    h1(icon("umbrella-beach"), "Berliner Badestellen"),
    h4("Thematische Karte zur Erreichbarkeit",
       style = "color: #EE6363;"),
    div(class = "title-rule")
  ),

  # ── Main layout: sidebar + maps ───────────────────────
  fluidRow(
    column(
      width = 2,
      class = "left-sidebar",
      # start tab: Willkommen
      conditionalPanel(
        condition = "input.map_tab == 'start'",
        h3("Willkommen!"),
        div(
          style = "background: #E1F0F1; border: 1px solid #00868B; border-radius: 4px; padding: 12px 14px;",
          p("Diese Anwendung zeigt, wie gut die Berliner Bevölkerung Badestellen im Stadtgebiet zu Fuß oder mit dem Fahrrad erreichen kann.",
            tags$br(), tags$br(),
            "Erkunden Sie die interaktive Karte, vergleichen Sie die Daten in der Ortsteil- oder Badestellen-Tabelle und lösen Sie die dazugehörigen Aufgaben.",
            tags$br(), tags$br(),
            "Einen schnellen Überblick zum aktuellen Zustand der Badegewässer finden Sie hier: ",
            a("Landesamt für Gesundheit und Soziales - Liste der Badestellen", href = "https://www.berlin.de/lageso/gesundheit/gesundheitsschutz/badegewaesser/liste-der-badestellen/", target = "_blank"),
            style = "font-size: 17px; font-weight: bold; color: #00868B; margin-bottom: 0;")
        )
      ),
      # map sidebar: selected Ortsteil
      conditionalPanel(
        condition = "input.map_tab == 'karte'",
        uiOutput("sidebar_content")
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
      ),
      # meta tab: Metadaten & Methodik
      conditionalPanel(
        condition = "input.map_tab == 'meta'",
        h3("Metadaten & Methodik"),
        tags$nav(
          class = "meta-nav",
          tags$ul(
            style = "list-style: none; padding-left: 0; margin-top: 12px;",
            tags$li(tags$a(href = "#meta-daten", "Metadaten")),
            tags$li(tags$a(href = "#meta-umsetzung", "Umsetzung & Code")),
            tags$li(tags$a(href = "#meta-methodik", "Methodik"))
          )
        )
      )
    ),
    column(
      width = 8,
      class = "main-column",
      tabsetPanel(
        id = "map_tab",

        # Tab 0: Startseite
        tabPanel(
          title = tagList(icon("house"), " Startseite"),
          value = "start",
          div(
            class = "start-tab-layout",
            div(
              class = "map-wrap",
              div(
                style = "width: 100%;",
              # Banner-Foto
              div(
                style = "width: 100%; height: 260px; overflow: hidden; border-radius: 6px; margin-bottom: 24px; box-shadow: 0 1px 4px #0000004D;",
                img(src = "start_foto_lake.png", style = "width: 100%; height: 100%; object-fit: cover; display: block;")
              ),
              # Karten-PNGs
              div(
                style = "display: flex; justify-content: center; gap: 24px; flex-wrap: wrap; margin: 0 0 24px 0;",
                div(
                  style = "flex: 1 1 0; min-width: 300px;",
                  div(
                    style = "border: 1px solid #00868B; border-radius: 4px; padding: 4px; background: #FFFFFF; box-shadow: 0 1px 4px #0000004D;",
                    img(src = "start_map_shiny_cycle.png", style = "width: 100%; height: auto; border-radius: 2px; display: block;")
                  )
                ),
                div(
                  style = "flex: 1 1 0; min-width: 300px;",
                  div(
                    style = "border: 1px solid #00868B; border-radius: 4px; padding: 4px; background: #FFFFFF; box-shadow: 0 1px 4px #0000004D;",
                    img(src = "start_map_shiny_walk.png", style = "width: 100%; height: auto; border-radius: 2px; display: block;")
                  )
                )
              ),
              # Kennzahlen-Boxen + Button: 2 links, Button, 2 rechts
              div(
                style = "display: flex; justify-content: center; align-items: stretch; gap: 20px; flex-wrap: wrap;",
                # linke Gruppe
                div(style = "display: flex; align-items: stretch; gap: 20px; flex: 1 1 auto; justify-content: flex-end;",
                    div(style = "flex: 1 1 0; min-width: 140px; max-width: 220px; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #F1948A; border: 1px solid #E16450; border-radius: 4px; padding: 20px 12px;",
                        div(style = "font-size: 40px; font-weight: bold; color: #006366;", "39"),
                        div(style = "font-size: 14px; color: #006366; text-align: center;", "Badestellen")),
                    div(style = "flex: 1 1 0; min-width: 140px; max-width: 220px; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #F1948A; border: 1px solid #E16450; border-radius: 4px; padding: 20px 12px;",
                        div(style = "font-size: 40px; font-weight: bold; color: #006366;", "97"),
                        div(style = "font-size: 14px; color: #006366; text-align: center;", "Ortsteile"))
                ),
                # mittlerer Button
                div(style = "flex: 0 0 auto; display: flex; align-items: stretch;",
                    actionButton("go_to_map", tagList(icon("map"), " Zur Karte"),
                      style = "background-color: #00868B; color: #FFFFFF; border: 1px solid #00868B; border-radius: 4px; padding: 8px 24px; font-size: 15px; font-weight: bold; height: 100%;")),
                # rechte Gruppe
                div(style = "display: flex; align-items: stretch; gap: 20px; flex: 1 1 auto; justify-content: flex-start;",
                    div(style = "flex: 1 1 0; min-width: 140px; max-width: 220px; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #F1948A; border: 1px solid #E16450; border-radius: 4px; padding: 20px 12px;",
                        div(style = "font-size: 40px; font-weight: bold; color: #006366;", "12"),
                        div(style = "font-size: 14px; color: #006366; text-align: center;", "Bezirke")),
                    div(style = "flex: 1 1 0; min-width: 140px; max-width: 220px; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #F1948A; border: 1px solid #E16450; border-radius: 4px; padding: 20px 12px;",
                        div(style = "font-size: 40px; font-weight: bold; color: #006366;", "3,9 Mio."),
                        div(style = "font-size: 14px; color: #006366; text-align: center;", "Einwohner*innen"))
                )
              )
            )
            )
          )
        ),

        # Tab 1: Interaktive Karte (Einwohnerdichte + Erreichbarkeitszonen)
        tabPanel(
          title = tagList(icon("map"), " Interaktive Karte"),
          value = "karte",
          div(
            class = "map-tab-layout",
            div(
              class = "map-wrap",
              style = "position: relative;",
              tmapOutput("main_map", height = "100%"),
              # Custom legend: Kreisgröße = Druck auf Badestelle
              # (vorläufig deaktiviert; tmap-Size-Legende oben rechts genutzt)
              div(
                style = "display: none; position: absolute; bottom: 40px; right: 10px; z-index: 1000;
                         width: 180px; background: #FFFFFFCC; padding: 10px 14px;
                         border-radius: 4px; box-shadow: 0 1px 4px #0000004D;",
                p(style = "font-family: sans-serif; font-size: 12px; font-weight: normal; color: black; margin: 0 0 8px 0;",
                  "Badestelle – Rang"),
                div(style = "display: flex; align-items: center;",
                  div(style = "text-align: center;",
                    div(style = "width: 12px; height: 12px; border-radius: 50%; background: #00EEEE; border: 2px solid darkslategrey; margin: 0 auto;"),
                    p(style = "font-size: 10px; margin: 3px 0 0 0; color: black;", "niedrig")),
                  div(style = "display: flex; align-items: center; width: 60px; margin-top: -6px;",
                    div(style = "flex: 1; height: 2px; background: darkslategrey;"),
                    div(style = "width: 0; height: 0; border-top: 5px solid transparent; border-bottom: 5px solid transparent; border-left: 8px solid darkslategrey;")),
                  div(style = "text-align: center;",
                    div(style = "width: 28px; height: 28px; border-radius: 50%; background: #00EEEE; border: 2px solid darkslategrey; margin: 0 auto;"),
                    p(style = "font-size: 10px; margin: 3px 0 0 0; color: black;", "hoch")))
              )
            ),
            div(
              class = "iso-box",
              radioButtons(
                inputId = "map_mode",
                label = "Mobilitätsmodus:",
                choiceNames = list(
                  tagList(icon("bicycle"), " Fahrrad"),
                  tagList(icon("person-walking"), " Zu Fuß")
                ),
                choiceValues = c("cycling-regular", "foot-walking"),
                selected = "cycling-regular",
                inline = TRUE
              ),
              hr(),
              uiOutput("iso_sidebar")
            )
          )
        ),

        # Tab 2: Ranking table
        tabPanel(
          title = tagList(icon("table"), " Ortsteil-Tabelle"),
          value = "ranking",
          h3("Alle Ortsteile im Vergleich"),
          hr(),
          p("Hinweis: Prozentwerte und EW/ha sind auf 1, Flächen auf 2 Nachkommastelle(n) gerundet", style = "font-size: 13px; font-weight: normal; font-style: italic"),
          hr(),
          DT::dataTableOutput("ranking_table")
        ),

        # Tab 4: Badestellen-Tabelle
        tabPanel(
          title = tagList(icon("table"), " Badestellen-Tabelle"),
          value = "lakes",
          h3("Alle Badestellen im Vergleich"),
          hr(),
          p("Hinweis: 39 offizielle, von der EU überwachte Badestellen. Rang und zugerechnete Einwohner*innen (EW) sind modellbasiert (Gravity-Modell, Methodik siehe Tab Metadaten); Prozentwerte auf 1 Nachkommastelle gerundet, Personenzahlen gerundet auf ganze Personen.",
            style = "font-size: 13px; font-weight: normal; font-style: italic"),
          hr(),
          DT::dataTableOutput("lakes_table")
        ),

        # Tab 5: Metadaten
        tabPanel(
          title = tagList(icon("database"), " Metadaten & Methodik"),
          value = "meta",
          div(
            style = "max-width: 900px; padding-top: 14px; padding-right: 24px;",
            div(
              id = "meta-daten",
            h3(class = "meta-section-title", "Metadaten"),
            hr(),
            h4("Autorin"),
            p("Ivonne Giske"),
            hr(),
            h4("Titel"),
            p("Berliner Badestellen - Thematische Karte zur Erreichbarkeit"),
            hr(),
            h4("Entstehungskontext"),
            p("Die Anwendung wurde im Rahmen des Moduls Thematische Internetkartographie im Studiengang Geoinformation (MSc) an der Berliner Hochschule für Technik (BHT) im Sommersemester 2026 entwickelt. Aufgabe war die Erstellung einer interaktiven Webkarte zu einem selbst gewählten Thema."),
            hr(),
            h4("Hintergrund & Fragestellung"),
            p("Heiße Sommer erhöhen den Bedarf an schnell erreichbaren Möglichkeiten zur Abkühlung. Initiativen wie Flussbad Berlin machen mit Badeaktionen in der Spree auf das Potenzial innerstädtischer Bademöglichkeiten und den Bedarf an weiteren Badestellen aufmerksam. Auch temporäre Projekte wie ein Schwimmbecken vor der Volksbühne zeigen den Diskussionsbedarf um zusätzliche Bademöglichkeiten in zentralen Stadtgebieten."),
            p("Es stellt sich die Frage nach der Erreichbarkeit von Badestellen im vergleichsweise wasserreichen Berlin. Welche Ortsteile oder Bezirke schneiden besonders gut ab? Wo befinden sich „Badewüsten“? Gibt es Zusammenhänge mit der Verteilung dicht besiedelter Bereiche?"),
            p("Die Anwendung veranschaulicht die räumliche Verteilung der 39 offiziell ausgewiesenen und nach der EU-Badegewässerrichtlinie überwachten Badestellen Berlins und deren Erreichbarkeit auf Grundlage von Einwohnerdichtedaten. Untersucht werden die Mobilitätsmodi Fahrrad und zu Fuß für drei Anreisezeiten von 5, 10 und 20 Minuten. Zusätzlich werden die Badestellen mithilfe eines Gravity-Modells gerankt (siehe Methodik). Das Ranking dient dazu, den potenziellen „Druck“ auf die einzelnen Badestellen abzubilden. Die Ergebnisse werden in einer interaktiven Karte dargestellt."),
            hr(),
            h4("Ziel & Ausblick"),
            p("Die Anwendung soll eine datenbasierte Betrachtung des Themas ermöglichen und damit zur Diskussion über eine gerechte und bedarfsorientierte Verteilung von Bademöglichkeiten in Berlin beitragen. Die Ergebnisse können als Grundlage für weiterführende Untersuchungen dienen, etwa zur Frage, wie die Erreichbarkeit mit sozioökonomischen und demografischen Merkmalen der Bevölkerung zusammenhängt."),
            hr(),
            h4("Datenquellen"),
            p(strong("Badestellen"), br(),
              "Geoportal Berlin: Badegewässerqualität, Layer aa_badestellen (WFS). Verantwortliche Stelle: Landesamt für Gesundheit und Soziales Berlin. Lizenz: CC BY 4.0. Abruf: 07.09.2026. ",
              a("Metadaten-Link", href = "https://gdi.berlin.de/geonetwork/srv/ger/catalog.search#/metadata/0b0218f9-5d32-4dba-9cc6-169768af2027", target = "_blank"), "."
            ),
            p(strong("Einwohnerdichte"), br(),
              "Geoportal Berlin: Einwohnerdichte 2025 (Umweltatlas), Layer ua_einwohnerdichte_2025 (WFS). Datengeber: Amt für Statistik Berlin-Brandenburg. Lizenz: CC BY 3.0 DE. Abgerufen am 07.09.2026. ",
              a("Metadaten-Link", href = "https://gdi.berlin.de/geonetwork/srv/ger/catalog.search#/metadata/69b82abc-377e-44d2-b598-c8feb8643e95", target = "_blank"), "."
            ),
            p("Datenstand 2025; Summe der Einwohnerzahlen der verwendeten Einwohnerdichte-Flächen: 3.913.490 EW (3,9 Mio.)."),
            p(strong("Bezirke, Ortsteile"), br(),
              "Geoportal Berlin: ALKIS Bezirke, Ortsteile Berlin (WFS). Datengeber: Senatsverwaltung für Stadtentwicklung, Bauen und Wohnen Berlin. Lizenz: Datenlizenz Deutschland – Zero – Version 2.0. Abruf: 07.09.2026. ",
              a("Metadaten-Link", href = "https://gdi.berlin.de/geonetwork/srv/ger/catalog.search#/metadata/0a7c53a5-b29d-3f45-9734-1c811045e6c2", target = "_blank"), "."
            ),
            p(strong("Erreichbarkeitszonen (Isochronen)"), br(),
              "openrouteservice des Heidelberg Institute for Geoinformation Technology (HeiGIT), mit API-Key. Abruf: 07.09.2026. ",
              a("Webseite", href = "https://heigit.org/de/", target = "_blank"), "."
            ),
            p(strong("Wasserflächen"), br(),
              "OpenStreetMap, Overpass-Abfrage in QGIS, anschließend manuell selektiert. Abruf: 07.09.2026."
            ),
            hr(),
            h4("Basemaps und Anbieter"),
            p("Stadia Maps / CARTO / OpenMapTiles / OpenStreetMap.")
          ),

          hr(),

          div(
            id = "meta-umsetzung",
            h3(class = "meta-section-title", "Umsetzung & Code"),
            hr(),
            h4("R, R-Pakete und Versionen"),
            p("Die Anwendung wurde als Shiny-App mit tmap und tmap.mapgl in RStudio entwickelt. Die Veröffentlichung erfolgte über RPubs."),
            p("R Version 4.5.1 (2025-06-13)"),
            p("shiny 1.13.0, sf 1.1.0, dplyr 1.2.1, tmap 4.4, tmap.mapgl 0.3, DT 0.34.0, leaflet 2.2.3, stars 0.7.2, tidyr 1.3.2, purrr 1.2.2, stringr 1.6.0, readr 2.2.0, ggplot2 4.0.2."),
            hr(),
            h4("Repository"),
            p("github-link folgt"),
            hr(),
            h4("Hinweis auf KI-Unterstützung"),
            p("Konzeption, Fragestellung, Auswahl und Durchführung der Analyse sowie die fachlichen und methodischen Entscheidungen wurden eigenständig entwickelt und getroffen. ChatGPT wurde zur Überprüfung von R-Code bei der Datenaufbereitung eingesetzt. Für die Programmierung der Shiny-App wurde der Posit Assistant mit den Modellen deepseek-v4-flash, glm-5.3-flash und kimi-k2.7-code eingesetzt.")
          ),

          hr(),

          div(
            id = "meta-methodik",
            h3(class = "meta-section-title", "Methodik"),
            hr(),
            h4("Datenaufbereitung"),
            p("Die Punktgeometrien einiger Badestellen wurden geringfügig lagekorrigiert, damit sie geeignete Zugangspunkte für die anschließende Erreichbarkeitsanalyse darstellen."),
            p("Aus den über OpenStreetMap abgefragten Wasserflächen wurden zur Orientierung lediglich die wichtigsten Berliner Gewässer, insbesondere größere Seen und Fließgewässer, ausgewählt."),
            p("Für die Analyse der Einwohnerdichte wurden zunächst Polygone ohne Einwohner*innen (EW) sowie als Gewässer klassifizierte Flächen ausgeschlossen. Zudem wurden 15 EW aufgrund einer unplausiblen Lage innerhalb von Gewässerflächen entfernt. Aus den verbleibenden Polygonen wurde jeweils ein innerhalb des Polygons liegender Repräsentativpunkt abgeleitet. Die im Ausgangsdatensatz enthaltenen Einwohnerzahlen wurden den entsprechenden Punkten zugeordnet. Für die Karte wurden daraus ein Rasterdatensatz mit der Auflösung 100x100 m erstellt."),
            p("Die Erreichbarkeitszonen (Polygone) von 39 Badestellen wurden pro Mobilitätsmodus (Fahrrad, Fuß) zu 3 Zonen vereinigt: bis 5, 10 und 20 Minuten."),
            hr(),
            h4("Ranking der Badestellen mit dem Gravity-Modell"),
            p("Das Ranking der Badestellen basiert auf einem Gravity-Modell, das berücksichtigt, wie gut die Badestellen von der Berliner Bevölkerung aus erreichbar sind und wie stark sie dabei mit anderen erreichbaren Badestellen konkurrieren."),
            p("Dazu wird für jeden Bevölkerungspunkt ermittelt, welche Badestellen innerhalb von 20 Minuten mit dem jeweiligen Mobilitätsmodus erreichbar sind. Je kürzer die Reisezeit, desto höher das Gewicht: 5 Minuten entsprechen einem Gewicht von 1, 10 Minuten von 0,5 und 20 Minuten von 0,25."),
            p("Erreicht ein Bevölkerungspunkt mehrere Badestellen, wird seine Einwohnerzahl auf diese Badestellen verteilt. Dabei erhält eine näher gelegene Badestelle einen größeren Anteil, während zusätzliche erreichbare Badestellen den Anteil der einzelnen Badestelle verringern."),
            p("Der Gravity-Score einer Badestelle ist die Summe der auf diese Weise zugeordneten Einwohner*innen. Er beschreibt damit eine modellbasierte, distanz- und konkurrenzgewichtete Bevölkerungsgröße – und nicht die tatsächliche oder erwartete Zahl der Badegäste."),
            p("Das Ranking ergibt sich aus dem Gravity-Score: Rang 1 hat den höchsten modellbasierten Wert."),
            p("Der Pressure Share zeigt, welcher Anteil der gesamten Berliner Bevölkerung einer Badestelle nach diesem Modell zugeordnet wird. Ein Wert von beispielsweise 10 % bedeutet daher, dass dem See nach dem Modell ein Anteil von 10 % der Berliner Bevölkerung zugerechnet wird."),
            hr(),
            h4("Grenzen der Analyse"),
            p("Die Analyse berücksichtigt keine öffentlichen Verkehrsmittel wie S- und U-Bahn und bildet die tatsächliche Erreichbarkeit der Badestellen daher nur teilweise ab. Die Annahme, dass die Berliner Bevölkerung ausschließlich zu Fuß oder mit dem Fahrrad zu den Badestellen gelangt, stellt eine Vereinfachung dar. Zudem werden Personen, die von außerhalb Berlins anreisen, nicht berücksichtigt. Badestellen im angrenzenden Brandenburg bleiben ebenfalls unberücksichtigt, obwohl sie für Teile der Berliner Bevölkerung leichter erreichbar sein können als innerhalb Berlins gelegene Badestellen.")
          ),

            hr(),
            h4("Datum der letzten Aktualisierung"),
            p(as.character(Sys.Date())),
            hr(),
            div(
              style = "text-align: center; margin-top: 16px; margin-bottom: 24px;",
              actionButton(
                inputId = "meta_scroll_top",
                label = "Nach oben",
                icon = icon("arrow-up"),
                style = "background-color: #00868B; color: #FFFFFF; border: 1px solid #00868B; border-radius: 4px; padding: 8px 20px; font-weight: bold;",
                onclick = "(function(btn){var el=btn.closest('.tab-pane.active, .tab-content, .main-column, .container-fluid'); while(el && el.scrollHeight <= el.clientHeight){el=el.parentElement;} if(el){el.scrollTo({top:0,behavior:'smooth'});}})(this);"
              )
            )
          )
        )
      )
    )
  )
)


# ─────────────────────────────────────────────────────────
# Hover-Tooltip für Bezirke (Tab 1): "Bezirk: <Name>"; Ortsteile ohne Hover
# ─────────────────────────────────────────────────────────
shiny_bezirke$bezirk_hover <- paste("Bezirk:", shiny_bezirke$bezirk)

# Eindeutige Klick-ID pro Bezirk (B_<nr>): verhindert, dass ein Bezirks-Klick
# als Ortsteil-Klick interpretiert wird (Namensgleichheit, z. B. "Mitte")
shiny_bezirke$bezirk_click <- paste0("B_", seq_len(nrow(shiny_bezirke)))

# ─────────────────────────────────────────────────────────
# SERVER
# ─────────────────────────────────────────────────────────
server <- function(input, output, session) {

  # Button "Zur Karte" auf der Startseite wechselt zur interaktiven Karte
  observeEvent(input$go_to_map, {
    updateTabsetPanel(session, "map_tab", selected = "karte")
  })

  # ── Basemap helper: Stadia with API key, fallback to CartoDB ──
  # Three basemaps as a single radio group in the native tmap layer control.
  basemap_layer <- reactive({
    api_key <- Sys.getenv("STADIA_MAPS_API_KEY")
    if (nzchar(api_key)) {
      tm_basemap(
        server = c(
          "reduziert" = "Stadia.AlidadeDark",
          "hell"      = "Stadia.AlidadeSmooth",
          "OSM-style" = "Stadia.OSMBright"
        ),
        api = api_key,
        group = "Basiskarte",
        group.control = "radio"
      )
    } else {
      # Fallback if no key is available
      tm_basemap(
        server = c(
          "reduziert" = "CartoDB.DarkMatter",
          "hell"      = "CartoDB.PositronNoLabels",
          "OSM-style" = "OpenStreetMap"
        ),
        group = "Basiskarte",
        group.control = "radio"
      )
    }
  })

  # ────────────────────────
  # Interaktive Karte: Einwohnerdichte + Erreichbarkeitszonen
  # (Layer-Reihenfolge: Dichte -> Zonen -> Wasser -> Bezirke -> Ortsteile -> Badestellen)
  # ────────────────────────
  output$main_map <- renderTmap({

    # lake ranking / bubble size depends on the selected mobility mode
    lakes <- shiny_lakes |>
      filter(mode == sel_mode()) |>
      mutate(
        legend_label = "Badestelle",
        rank_html = paste0(
          '<span style="color:#00CDCD; font-size:20px; font-weight:bold;">',
          rank_label, "</span>"
        ),
        rank_legend_cat = case_when(
          rank == min(rank, na.rm = TRUE) ~ "Rang 1 (hoch)",
          rank == max(rank, na.rm = TRUE) ~ paste0("Rang ", max(rank, na.rm = TRUE), " (niedrig)"),
          TRUE ~ NA_character_
        )
      )

    # rings and mode-dependent style (palettes from the static start maps)
    rings <- shiny_iso_rings |>
      filter(mode == sel_mode()) |>
      mutate(zone = case_when(
        minutes == "up to 5 min"  ~ "Zone A (bis zu 5 Min.)",
        minutes == "up to 10 min" ~ "Zone B (bis zu 10 Min.)",
        minutes == "up to 20 min" ~ "Zone C (bis zu 20 Min.)"
      ))

    if (sel_mode() == "cycling-regular") {
      ring_colors <- c(
        "Zone A (bis zu 5 Min.)"  = "#8C4BBE",
        "Zone B (bis zu 10 Min.)" = "#BC96D9",
        "Zone C (bis zu 20 Min.)" = "#D9C3E9"
      )
      ring_border <- "#6a3ea0"
      legend_title <- "Erreichbarkeitszonen mit Fahrrad"
    } else {
      ring_colors <- c(
        "Zone A (bis zu 5 Min.)"  = "#18C93E",
        "Zone B (bis zu 10 Min.)" = "#5BEC7A",
        "Zone C (bis zu 20 Min.)" = "#A4F4B5"
      )
      ring_border <- "#0f7a2a"
      legend_title <- "Erreichbarkeitszonen zu Fuß"
    }

    basemap_layer() +

      # Basis - Heatmap
      tm_shape(shiny_ew_density_raster, name = "Einwohnerdichte") +
      tm_raster(
        col.scale = tm_scale_continuous_sqrt(values = "yl_or_rd"),
        col_alpha = 0.7,
        col.legend = tm_legend(title = "EW/ha", position = c("left", "bottom"))
      ) +

      # Iso-Zonen (gestrichelte Ränder im Stil der statischen Startkarten)
      tm_shape(rings, name = "Erreichbarkeitszonen") +
      tm_polygons(
        fill = "zone",
        fill.legend = tm_legend(title = legend_title, position = c("right", "top")),
        fill.scale = tm_scale_categorical(values = ring_colors),
        fill_alpha = 0.7,
        col = ring_border,
        lwd = 0.4,
        lty = "dashed",
        popup = FALSE
      ) +

      # Wasser (über den Zonen, damit die Zonen das Wasser nicht abdecken)
      tm_shape(shiny_water_background, name = "Wasserflächen") +
      tm_polygons(
        fill = "turquoise4",
        lwd = 0
      ) +

      # Bezirke: unsichtbare Füllung (fill_alpha = 0) bleibt interaktiv
      # (Bezirks-Hover + Klick), liegt UNTER den Ortsteilen.
      tm_shape(shiny_bezirke, name = "Bezirke") +
      tm_polygons(
        fill = "grey95",
        fill_alpha = 0,
        col = "darkslategrey",
        lwd = 1.25,
        id = "bezirk_click",
        hover = "bezirk_hover",
        popup = FALSE,
        fill.legend = tm_legend_hide()
      ) +
      # Bezirksnamen dauerhaft sichtbar, Farbe wie die Grenzen
      tm_shape(mutate(shiny_bezirke, bezirk_caps = toupper(bezirk))) +
      tm_text(
        text = "bezirk_caps",
        size = 0.8,
        col = "darkslategrey",
        group = "Bezirke", group.control = "none",
        options = opt_tm_text(
          just = "center",
          halo = TRUE, halo.col = "ivory", halo.width = 0.2,
          point_per = "feature", on_surface = TRUE
        )
      ) +

      # Ortsteile (Grenzen + Ortsteilnamen in EINER Layer-Gruppe:
      # gemeinsames Häkchen "Ortsteile" im Layermenü)
      tm_shape(shiny_ortsteile, name = "Ortsteile") +
      tm_polygons(
        fill = NULL,
        col = "indianred4",
        lwd = 0.75,
        id = "ortsteil",
        hover = FALSE, # kein redundantes Hover-Label; Klick bleibt aktiv
        popup = tm_popup(
          vars = c(
            "Bezirk" = "bezirk"
          ),
          # etwas Luft zwischen Label und Wert
          css = ".tmap-popup-label { padding-right: 14px; }"
        )
      ) +
      # Ortsteilnamen dauerhaft sichtbar in Versalien, Farbe wie die Grenzen
      # (on-the-fly per mutate; gleiche Gruppe wie Grenzen und ohne eigene
      #  ID, damit kein redundanter Hover erscheint)
      tm_shape(mutate(shiny_ortsteile, ortsteil_caps = toupper(ortsteil))) +
      tm_text(
        text = "ortsteil_caps",
        size = 0.6,
        col = "indianred4",
        group = "Ortsteile", group.control = "none",
        options = opt_tm_text(
          just = "center",
          halo = TRUE, halo.col = "ivory", halo.width = 0.18,
          point_per = "feature", on_surface = TRUE
        )
      ) +

      # Badestellen: Gravity-Größe, Hover + Popup mit Rang (wie bisher Iso-Karte)
      tm_shape(lakes, name = "Badestellen") +
      tm_bubbles(
        size = "gravity_visual",
        size.legend = tm_legend(
          title = "Badestelle – Rang",
          position = c("right", "bottom")
        ),
        size.scale = tm_scale_continuous(
          ticks = c(min(lakes$gravity_visual, na.rm = TRUE),
                    max(lakes$gravity_visual, na.rm = TRUE)),
          labels = c("niedrig", "hoch")
        ),
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
            "Rang"     = "rank_html",
            "Bezirk"   = "bezirk",
            "Ortsteil" = "ortsteil",
            "Details"  = "link_html"
          ),
          format = list(
            rank_html = tm_label_format(html.escape = FALSE),
            link_html = tm_label_format(html.escape = FALSE)
          ),
          css = paste(
            ".tmap-popup-label { padding-right: 14px; }",
            ".tmap-popup-title { background: #00CDCD; color: #2F4F4F;",
            "font-size: 16px; font-weight: bold; padding: 8px 12px; margin: -14px -14px 12px -14px; }",
            ".tmap-popup-row { border-bottom: 1px solid #E1F0F1; padding: 6px 0; }",
            ".tmap-popup-row:last-child { border-bottom: none; }",
            "a { font-weight: bold; }",
            "a:hover { color: #00CDCD; }"
          )
        )
      ) +

      tm_credits(
        if (nzchar(Sys.getenv("STADIA_MAPS_API_KEY"))) {
          "© Berliner Badestellen 2026, I.Giske · Daten: Geoportal Berlin, HeiGIT/openrouteservice · Basemaps: © Stadia Maps / © OpenMapTiles / © OpenStreetMap contributors"
        } else {
          "© Berliner Badestellen 2026, I.Giske · Daten: Geoportal Berlin, HeiGIT/openrouteservice · Basemaps: © CARTO / © OpenStreetMap contributors"
        },
        position = c("right", "bottom")
      ) +

      tm_layout(legend.position = c("right", "top"), control.collapse = FALSE)
  })


  # ────────────────────────
  # Karte Sidebar: selected Ortsteil / Bezirk
  # ────────────────────────
  # Last map selection (NULL = nothing selected yet);
  # type "ortsteil" or "bezirk"
  selection <- reactiveVal(NULL)

  # Aktiver Mobilitätsmodus: eine einzige Radio-Gruppe (map_mode) auf dem
  # gemergten Karten-Tab. Für Nicht-Karten-Tabs gilt fix Fahrrad.
  sel_mode <- reactive({
    tab <- input$map_tab
    if (is.null(tab) || tab != "karte") {
      "cycling-regular"
    } else {
      if (is.null(input$map_mode)) "cycling-regular" else input$map_mode
    }
  })

  # Klick-Handler für die main_map: nur Bezirk- und Ortsteil-Klicks
  # ändern die Sidebar. Badestellen zeigen stattdessen ein Popup.
  observeEvent(input$main_map_shape_click$id, {
    clicked <- input$main_map_shape_click$id
    req(clicked)

    # 1) Bezirk click: unique B_<nr> id -> nur Mini-Info in der Sidebar
    if (grepl("^B_[0-9]+$", clicked)) {
      selection(list(type = "bezirk", idx = as.integer(sub("^B_", "", clicked))))
      return()
    }

    # 2) Ortsteil click: tmap replaces non-alphanumeric chars (spaces,
    #    hyphens, ...) with underscores in the feature ID; reverse that.
    #    Second pattern covers a stricter ASCII sanitization of umlauts.
    hit_ot <- shiny_ortsteile$ortsteil[
      gsub("[^[:alnum:]]", "_", shiny_ortsteile$ortsteil) == clicked
    ]
    if (length(hit_ot) == 0) {
      hit_ot <- shiny_ortsteile$ortsteil[
        gsub("[^a-zA-Z0-9]", "_", enc2utf8(shiny_ortsteile$ortsteil)) == clicked
      ]
    }
    if (length(hit_ot) > 0) {
      selection(list(type = "ortsteil", ortsteil = hit_ot[1]))
    }
  })

  # map1 sidebar: selected Ortsteil or Bezirk
  output$sidebar_content <- renderUI({

    sel <- selection()

    # Startup / nothing selected yet: title + instructions
    if (is.null(sel)) {

      return(tagList(
        h3("Einwohnerdichte und Erreichbarkeit von Badestellen nach Ortsteilen"),
        hr(),
        div(
          style = "background: #E1F0F1; border: 1px solid #00868B; border-radius: 4px; padding: 12px 14px;",
          p("Klicken Sie auf einen Ortsteil oder eine Badestelle, um Details zu erfahren. Über die Ebenensteuerung oben links blenden Sie Layer ein und aus und wechseln die Basiskarte. Der Mobilitätsmodus in der rechten Sidebar beeinflusst die Erreichbarkeit und damit die angezeigten Werte.",
            style = "font-size: 17px; color: #00868B; margin-bottom: 0;")
        )
      ))
    }

    # Bezirk angeklickt: nur minimale Info (Name + Anzahl Badestellen)
    if (sel$type == "bezirk") {
      bz_name <- shiny_bezirke$bezirk[sel$idx]
      # st_drop_geometry: summarise auf leeren sf-Objekten (Bezirk ohne
      # Badestellen) wirft sonst einen Recycle-Fehler
      n_lakes <- shiny_lakes |>
        st_drop_geometry() |>
        filter(bezirk == bz_name) |>
        summarise(n = n_distinct(lake_name)) |>
        pull(n)
      return(tagList(
        h3("Einwohnerdichte und Erreichbarkeit von Badestellen nach Ortsteilen"),
        hr(),
        h5("Bezirk"),
        div(style = "font-size: 28px; font-weight: bold; color: #00868B;", bz_name),
        h5("Badestellen im Bezirk"),
        div(style = "font-size: 24px; font-weight: bold; color: #00868B;", n_lakes),
        hr(),
        p("Hinweis: Details wie Einwohnerdichte und erreichbare Badestellen finden sich auf Ortsteil-Ebene.",
          style = "font-size: 13px; font-weight: normal; font-style: italic;")
      ))
    }

    ot_name <- sel$ortsteil
    ot <- shiny_ortsteile |> filter(ortsteil == ot_name)

    # lakes reachable from this Ortsteil within 20 min (current mode):
    # a lake counts if its 20-min isochrone covers part of the Ortsteil
    iso20 <- shiny_isochrones |> filter(minutes == 20, mode == sel_mode())
    reachable <- iso20$lake_name[lengths(st_intersects(iso20, ot)) > 0] |>
      unique() |>
      sort()

    # access share depending on the selected mode
    if (sel_mode() == "cycling-regular") {
      access_pct <- ot$cycle_within_20_pct[[1]]
    } else {
      access_pct <- ot$walk_within_20_pct[[1]]
    }
    pct_txt <- format(round(access_pct, 1), big.mark = ".", decimal.mark = ",")
    ot_txt  <- ot$ortsteil[[1]]
    mode_word <- if (sel_mode() == "cycling-regular") "mit Fahrrad" else "zu Fuß"

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
         icon(if (sel_mode() == "cycling-regular") "bicycle" else "person-walking"),
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
  # Rechte Sidebar: Iso-Ring-Statistiken
  # ────────────────────────
  output$iso_sidebar <- renderUI({

    rings <- shiny_iso_rings |>
      filter(mode == sel_mode()) |>
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

    mode_icon <- if (sel_mode() == "cycling-regular") "bicycle" else "person-walking"
    mode_word <- if (sel_mode() == "cycling-regular") "mit Fahrrad" else "zu Fuß"

    # Top 3 des gewählten Modus als Ranking-Einstieg
    top3 <- shiny_lakes |>
      st_drop_geometry() |>
      filter(mode == sel_mode(), !is.na(rank)) |>
      arrange(rank) |>
      slice_head(n = 3)

    # Farben der Unterstreichung = Zonenfarben der Karte (modusabhängig)
    zone_colors <- if (sel_mode() == "cycling-regular") {
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
        "Bevölkerung anteilig, EW = Einwohner*innen", tags$sup("1"), tags$br()),

      zone_row("Zone A - bis 5 Min.",  pct5,  pop5,    zone_colors["A"], "#00868B", "#006366"),
      zone_row("Zone B - bis 10 Min.", pct10, pop10,   zone_colors["B"], "#00868B", "#006366"),
      zone_row("Zone C - bis 20 Min.", pct20, pop20,   zone_colors["C"], "#00868B", "#006366"),
      zone_row("mehr als 20 Min.", rest_pct, rest_pop, "#EE6363", "#EE6363", "#EE6363"),
      hr(),

      h3("Badestellen unter Druck"),
      p(style = "font-size: 16px; font-weight: bold; margin: 0 0 4px 0;",
        icon("umbrella-beach"), " Top 3"),
      p(style = "font-size: 13px; font-weight: normal; font-style: italic; margin: 0 0 8px 0;",
        "Rang 1 = höchste Anzahl zugeordneter Einwohner*innen", tags$sup("2")),

      lapply(seq_len(nrow(top3)), function(i) {
        p(style = "margin: 2px 0; color: #15C8CF; font-weight: bold; font-size: 15px;",
          paste0("Rang ", i, ": ", top3$lake_name[i]))
      }),
      hr(),

      p(style = "font-size: 13px; font-weight: normal; font-style: italic; margin-top: 8px;",
        "Fußnoten", tags$br(),
        tags$sup("1"), "Gesamtbevölkerung Berlin laut Datenbasis (2025): 3,9 Mio. EW.",
        tags$br(),
        tags$sup("2"), " Der Rang ergibt sich aus den der Badestelle zugerechneten Einwohner*innen auf Basis eines Gravity-Modells (siehe 'Metadaten', unter Methodik). Das gesamte Ranking finden Sie in der 'Badestellen-Tabelle'.")

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
      h3("Aufgaben"),
      hr(),
      p("Finden Sie die Antworten – sortieren und filtern Sie in der Ortsteil-Tabelle.",
        style = "font-size: 19px; margin-top: 10px;"),

      section_hdr("bicycle", "Fahrrad"),
      challenge_box(
        "Aufgabe 1",
        "Welcher Ortsteil ist besonders dünn besiedelt und außerdem gut mit Badestellen versorgt?",
        "#EE6363",
        c1$ortsteil[[1]],
        paste0("(", c1$bezirk[[1]], "): nur ", fmt_dens(c1$pop_density[[1]]), " EW/ha, aber ",
               round(c1$access[[1]]), " % Fahrrad-Zugang in 20 Min. (",
               fmt_pop2(c1$pop_total[[1]]), " EW).")
      ),
      challenge_box(
        "Aufgabe 2",
        "In welchem Ortsteil leben die meisten Menschen ohne erreichbare Badestelle(n) – per Fahrrad innerhalb von maximal 20 Minuten?",
        "#EE6363",
        c2$ortsteil[[1]],
        paste0("(", c2$bezirk[[1]], "): ", fmt_pop2(c2$pop_no[[1]]), " von ",
               fmt_pop2(c2$pop_total[[1]]), " EW ohne Badestelle in 20 Min. (0 % Zugang)")
      ),

      section_hdr("person-walking", "Zu Fuß"),
      challenge_box(
        "Aufgabe 3",
        "Für wie viele der 97 Berliner Ortsteile gibt es keine (oder praktisch keine) Badestellen, die in maximal 20 Minuten zu Fuß erreichbar sind?",
        "#EE6363",
        paste0(n_walk0_prac, " von 97 Ortsteilen"),
        paste0(n_walk0, " Ortsteile haben exakt 0 %, 2 weitere (Fennpfuhl, Reinickendorf) liegen unter 0,1 %.")
      ),
      challenge_box(
        "Aufgabe 4",
        "In welchem Ortsteil können alle Einwohner*innen zu Fuß und in maximal 20 Minuten eine Badestelle erreichen? Was ist das Besondere an diesem Ortsteil?",
        "#EE6363",
        c4$ortsteil[[1]],
        paste0("(", c4$bezirk[[1]], "): mit nur ", fmt_km2(c4$area_km2[[1]]),
               " km² der zweitkleinste Ortsteil Berlins – Badestelle: Strandbad Halensee im angrenzenden Grunewald.")
      ),

      section_hdr("star", "Zusatzfrage"),
      challenge_box(
        "Aufgabe 5",
        "Die Bevölkerung welches Bezirks kann keine oder die wenigsten Badestellen erreichen (zu Fuß und/oder Fahrrad)?",
        "#EE6363",
        c5$bezirk[[1]],
        paste0("0 % Zugang – weder zu Fuß noch mit dem Fahrrad (", fmt_pop2(c5$pop[[1]]),
               " EW). Kein anderer Bezirk liegt bei beiden Mobilitätsmodi bei 0 %.")
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
        pageLength = 15,
        lengthMenu = c(15, 30, 60, 90, 97),
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
      select(lake_name, bezirk, ortsteil, mode, rank, pressure_share_pct)

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
        `Zugerechnete EW in % (Fahrrad)` = round(pressure_share_pct.cyc, 1),
        `Zugerechnete EW (Fahrrad)` = round(pressure_share_pct.cyc / 100 * 3913490),
        `Rang (zu Fuß)` = rank.walk,
        `Zugerechnete EW in % (zu Fuß)` = round(pressure_share_pct.walk, 1),
        `Zugerechnete EW (zu Fuß)` = round(pressure_share_pct.walk / 100 * 3913490)
      ) |>
      arrange(`Rang (Fahrrad)`, `Rang (zu Fuß)`)

    DT::datatable(
      lk_tab,
      rownames = FALSE,
      filter = "top",
      options = list(
        pageLength = 15,
        lengthMenu = c(15, 30, 39),
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
      select(lake_name, bezirk, ortsteil, mode, rank, pressure_share_pct)
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
    # B2: zwei Badestellen mit rund 1 % zu Fuß
    b2 <- lk_tab |>
      filter(round(pressure_share_pct.walk, 1) == 1) |>
      arrange(desc(pressure_share_pct.walk))
    # B3: in beiden Top 5
    top_cyc5 <- lk_tab |>
      arrange(rank.cyc) |>
      slice_head(n = 5) |>
      pull(lake_name)
    top_walk5 <- lk_tab |>
      arrange(rank.walk) |>
      slice_head(n = 5) |>
      pull(lake_name)
    b3 <- lk_tab |>
      filter(lake_name %in% intersect(top_cyc5, top_walk5)) |>
      arrange(rank.cyc)

    tagList(
      h3("Aufgaben"),
      hr(),
      p("Finden Sie die Antworten – sortieren und filtern Sie in der Badestellen-Tabelle.",
        style = "font-size: 19px; margin-top: 10px;"),
      p("Details zur Berechnung mit dem Gravity-Modell finden sich in den Metadaten.",
        style = "font-size: 13px; font-weight: normal; font-style: italic"),

      section_hdr("umbrella-beach", "Badestellen"),
      challenge_box(
        "Aufgabe B1",
        "Bei welcher Badestelle ändert sich die Zahl der zugerechneten Einwohner*innen am stärksten, wenn man statt zu Fuß mit dem Fahrrad anreist?",
        "#00C5CD",
        "Strandbad Weißensee",
        "(Pankow): Dem Strandbad werden mit dem Fahrrad rund 428.000 Einwohner*innen zugerechnet, zu Fuß nur rund 36.000 – ein Unterschied von rund 392.000."
      ),
      challenge_box(
        "Aufgabe B2",
        "Welchen beiden Badestellen wird zu Fuß jeweils rund 1 % der Berliner Bevölkerung zugerechnet?",
        "#00C5CD",
        "Strandbad Halensee (Charlottenburg-Wilmersdorf) und Flussbad Gartenstraße (Treptow-Köpenick)",
        "Beiden Badestellen wird zu Fuß jeweils rund 1 % der Berliner Bevölkerung zugerechnet."
      ),
      challenge_box(
        "Aufgabe B3",
        "Welche drei Badestellen gehören sowohl mit dem Fahrrad als auch zu Fuß zu den Top 5 im Ranking?",
        "#00C5CD",
        "Strandbad Weißensee (Pankow), Strandbad Halensee (Charlottenburg-Wilmersdorf) und Strandbad Orankesee (Lichtenberg)",
        "Diese drei Badestellen liegen vergleichsweise zentral in Gebieten mit hoher Bevölkerungsdichte, weshalb ihnen in beiden Modi hohe Anteile der Berliner Bevölkerung zugerechnet werden."
      ),
      challenge_box(
        "Aufgabe B4",
        "In welchen drei Ortsteilen liegen die Badestellen, denen mit dem Fahrrad weniger als 2.500 Einwohner*innen zugerechnet werden – und was haben sie gemeinsam?",
        "#00C5CD",
        "Schmöckwitz (Treptow-Köpenick), Nikolassee (Steglitz-Zehlendorf) und Grunewald (Charlottenburg-Wilmersdorf)",
        "Die vier Badestellen (Seddinsee, Schmöckwitz, Lieper Bucht und Grunewaldturm) liegen weit am Stadtrand in großen Wald- und Seengebieten, in denen kaum Menschen wohnen – ihnen werden daher nur rund 1.000 bis 2.400 Einwohner*innen zugerechnet. Das Muster zeigt sich auf beiden Stadtseiten."
      ),
      challenge_box(
        "Aufgabe B5",
        "Zu Fuß werden zwei Badestellen gar nicht gerankt. Um welche beiden Badestellen handelt es sich?",
        "#00C5CD",
        "Lieper Bucht und Radfahrerwiese (beide Ortsteil Nikolassee, Steglitz-Zehlendorf)",
        "In ihren 20-Minuten-Zonen zu Fuß liegt keine Wohnbevölkerung, ihnen werden daher keine Einwohner*innen zugerechnet und somit kein Rang."
      )
    )
  })

  # Karte soll auch rendern, wenn der Karten-Tab noch nicht aktiv ist,
  # damit der Wechsel auf "Interaktive Karte" schneller wirkt.
  outputOptions(output, "main_map", suspendWhenHidden = FALSE)
}

shinyApp(ui, server)



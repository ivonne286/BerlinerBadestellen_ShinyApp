### Skript 2: Abfrage aller Isochronen mit OpenRouteService API
### Ivonne Giske
### Beginn: 01.07.2026
### Projekt: Berliner Badestellen – Thematische Karte zur Erreichbarkeit
### Modul: Thematische Internetkartografie
### Aufgabe: Erstellung einer thematischen, interaktiven Karte, browserfähig
###
### Eingabe:  data/1_processed_data.RData; ORS_API_KEY aus .Renviron
### Ausgabe:  data/2_isochrones_all.RData
###
### Achtung: führt API-Aufrufe aus (Kosten/Limit) – nicht blind laufen lassen.
### Resume: bereits geholte Isochronen in data/2_isochrones_all.RData werden übersprungen.

library(openrouteservice)
library(sf)

# heigit.org endpoint: service paths must be set explicitly
options(
  openrouteservice.url = "https://api.heigit.org",
  openrouteservice.paths = list(
    isochrones = "openrouteservice/v2/isochrones"
  )
)


# load lake data
tmp <- new.env()
load("data/1_processed_data.RData", envir = tmp)
lakes_new <- tmp$lakes_new

# change crs to wgs84 (epsg code 4326), required by ors api
lakes_wgs <- st_transform(lakes_new, 4326)

# set api-key (stored in .Renviron as ORS_API_KEY next to the Stadia basemap key;
# the openrouteservice package reads the same env var via ors_api_key())
key <- Sys.getenv("ORS_API_KEY")
if (!nzchar(key)) {
  stop("ORS_API_KEY fehlt - bitte in .Renviron eintragen und R neu starten.")
}


# set parameters for api request 2 modi and 3 times (20 min, 10 min, 5 min)
modes <- c("foot-walking", "cycling-regular")
seconds <- c(1200, 600, 300)

# initialize empty list to collect isochrones and
# set a list-entry counter (j)
all_isochrones_list <- list()
j <- 1

# df for error collection
failed_requests <- data.frame()
# set TRUE on a blocking error (quota/rate limit) to stop wasting requests
stop_fetching <- FALSE

# resume support: restore isochrones from a previous run and build a lookup
# of already-fetched combos so they are NOT requested again
done_keys <- character(0)
if (file.exists("data/2_isochrones_all.RData")) {
  prior <- new.env()
  load("data/2_isochrones_all.RData", envir = prior)
  prior_sf <- prior$all_isochrones_sf
  rm(prior)
  if (!is.null(prior_sf) && nrow(prior_sf) > 0) {
    done_keys <- paste(prior_sf$lake_name, prior_sf$mode, prior_sf$minutes)
    # restore already-saved isochrones so they are kept in the output
    all_isochrones_list <- lapply(seq_len(nrow(prior_sf)), function(k) prior_sf[k, ])
    j <- length(all_isochrones_list) + 1
    cat("Resuming: skipped", length(done_keys), "already-fetched isochrones from previous run.\n")
  }
}

# loop that collects all isochrones and adds them to the list
for (i in 1:nrow(lakes_wgs)) {
  if (stop_fetching) break
  lake <- lakes_wgs[i,]
  coords <- st_coordinates(lake)

  for (mode in modes) {
    if (stop_fetching) break

    for (second in seconds) {
      if (stop_fetching) break

      # skip combos already fetched in a previous run (saves API calls)
      combo_key <- paste(lake$lake_name, mode, second / 60)
      if (combo_key %in% done_keys) next

      # Show progress in the R console
      cat(
        "Lake:", i, "/", nrow(lakes_wgs),
        "|", lake$lake_name,
        "|", mode,
        "|", second / 60, "min\n"
      )
      
      # Fetch with a few retries. The free tier allows 20 isochrones/min; a
      # request rejected as rate/quota-limited does NOT consume monthly quota,
      # so waiting ~65 s and retrying survives brief per-minute trips instead
      # of wasting the rest of the run.
      iso_i <- NULL
      for (attempt in 1:3) {
        res <- tryCatch(
          ors_isochrones(
            locations = coords,
            profile = mode,
            range = second,
            output = "sf",
            api_key = key
          ),
          error = function(e) e
        )
        if (inherits(res, "error")) {
          err_message <- conditionMessage(res)
          if (grepl("403|429|quota|limit", err_message, ignore.case = TRUE)) {
            message(sprintf(
              "  rate/quota limit hit — retrying in 65 s (attempt %d/3)", attempt
            ))
            Sys.sleep(65)
          } else {
            # non-quota failure (e.g. temporary server error): record and move on
            failed_requests <<- rbind(
              failed_requests,
              data.frame(
                lake = lake$lake_name,
                mode = mode,
                seconds = second,
                error = err_message
              )
            )
            break
          }
        } else {
          iso_i <- res
          break
        }
      }
      
      # retries exhausted on a rate/quota error -> stop before wasting calls
      if (is.null(iso_i)) {
        failed_requests <<- rbind(
          failed_requests,
          data.frame(
            lake = lake$lake_name,
            mode = mode,
            seconds = second,
            error = "rate/quota limit after 3 retries"
          )
        )
        stop_fetching <- TRUE
        break
      }
      
      iso_i$lake_name <- lake$lake_name
      iso_i$mode <- mode
      iso_i$minutes <- second / 60
      all_isochrones_list[[j]] <- iso_i
      j <- j + 1
      
      # 3 s spacing + request time ≈ 12-15 req/min, under the 20/min free-tier limit
      Sys.sleep(3)
    }
  }

}

# warn if the run stopped early on a blocking error
if (stop_fetching) {
  message(sprintf(
    "Run stopped early after %d failed requests (blocking API error). Remaining calls were NOT made.",
    nrow(failed_requests)
  ))
}

# transform collected list to sf object (class sf data.frame)
all_isochrones_sf <- do.call(rbind, all_isochrones_list)

# transfer isochrones back to epsg 25833
all_isochrones_sf <- st_transform(all_isochrones_sf, 25833)

# create class column that contains labels for map legend
all_isochrones_sf$minutes_class <- cut(
  all_isochrones_sf$minutes,
  breaks = c(0, 5, 10, 20),
  labels = c("≤ 5 minutes", "≤ 10 minutes", "≤ 20 minutes"),
  include.lowest = TRUE
)

# separate the transport modes for different map views
walk_iso <- all_isochrones_sf[
  all_isochrones_sf$mode == "foot-walking",
]

cycle_iso <- all_isochrones_sf[
  all_isochrones_sf$mode == "cycling-regular",
]

rm(list=setdiff(ls(),c('all_isochrones_sf', 'cycle_iso', 'walk_iso')))
save.image('data/2_isochrones_all.RData')


# log any requests that failed to reach the API
if (nrow(failed_requests) > 0) {
  message(sprintf("WARNING: %d/%d isochrone requests failed — see below:",
                  nrow(failed_requests),
                  nrow(lakes_wgs) * length(modes) * length(seconds)))
  print(failed_requests)
} else {
  message(sprintf("All %d isochrones fetched OK.",
                  nrow(lakes_wgs) * length(modes) * length(seconds)))
}

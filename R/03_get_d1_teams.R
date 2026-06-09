library(wehoop)
library(dplyr)
library(purrr)
library(readr)

seasons <- 2017:2026

message("Pulling D1 team IDs for seasons ", min(seasons), " to ", max(seasons), "...")

standings_teams <- purrr::map_dfr(seasons, function(yr) {
  message("  Fetching standings ", yr, "...")
  tryCatch({
    standings <- wehoop::espn_wbb_standings(year = yr)
    dplyr::tibble(season = yr, team_id = standings$team_id)
  }, error = function(e) {
    message("  Warning: could not fetch ", yr, " - ", e$message)
    NULL
  })
})

raw <- readr::read_csv("data/raw/wbb_team_box_raw.csv", show_col_types = FALSE)

games_teams <- raw |>
  dplyr::group_by(season, team_id) |>
  dplyr::summarise(games = dplyr::n(), .groups = "drop") |>
  dplyr::filter(games >= 25) |>
  dplyr::select(season, team_id) |>
  dplyr::mutate(season = as.integer(season))

d1_teams <- dplyr::bind_rows(
  standings_teams,
  games_teams
) |>
  dplyr::distinct() |>
  dplyr::arrange(season, team_id)

readr::write_csv(d1_teams, "data/raw/d1_team_ids.csv")

d1_teams |>
  dplyr::count(season) |>
  print()

message("Done! Total D1 team-season records: ", nrow(d1_teams))
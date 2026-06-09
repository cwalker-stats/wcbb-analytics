library(wehoop)
library(dplyr)
library(readr)

seasons_to_pull <- 2017:2026

message("Pulling WBB team box scores for seasons ", min(seasons_to_pull), " to ", max(seasons_to_pull), "...")

raw_data <- wehoop::load_wbb_team_box(seasons = seasons_to_pull)

regular_season <- raw_data |>
  dplyr::filter(season_type == 2)

readr::write_csv(regular_season, "data/raw/wbb_team_box_raw.csv")

message("Done! Rows saved: ", nrow(regular_season))
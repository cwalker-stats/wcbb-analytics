library(dplyr)
library(readr)
library(jsonlite)

raw <- readr::read_csv("data/raw/wbb_team_box_raw.csv", show_col_types = FALSE)
d1_ids <- readr::read_csv("data/raw/d1_team_ids.csv", show_col_types = FALSE)
ratings <- readr::read_csv("data/processed/team_ratings.csv", show_col_types = FALSE) |>
  dplyr::as_tibble() |>
  dplyr::select(-dplyr::any_of("luck"))

raw_d1 <- raw |>
  dplyr::inner_join(d1_ids, by = c("season", "team_id"))

opponent_pts <- raw_d1 |>
  dplyr::select(game_id, opp_team_id = team_id, opp_points = team_score)

game_level <- raw_d1 |>
  dplyr::left_join(opponent_pts, by = dplyr::join_by(game_id, opponent_team_id == opp_team_id)) |>
  dplyr::filter(!is.na(team_score), !is.na(opp_points), team_score > 0, opp_points > 0)

game_level <- game_level |>
  dplyr::mutate(
    pyth_win_prob = team_score^10.25 / (team_score^10.25 + opp_points^10.25),
    actual_win    = as.numeric(team_winner)
  )

luck <- game_level |>
  dplyr::group_by(season, team_id) |>
  dplyr::summarise(
    actual_wins   = sum(actual_win, na.rm = TRUE),
    expected_wins = sum(pyth_win_prob, na.rm = TRUE),
    games         = n(),
    luck          = (actual_wins - expected_wins) / games,
    .groups = "drop"
  )

final <- ratings |>
  dplyr::left_join(
    luck |> dplyr::select(season, team_id, luck),
    by = c("season", "team_id")
  ) |>
  dplyr::mutate(luck = round(luck, 3))

readr::write_csv(final, "data/processed/team_ratings.csv")
jsonlite::write_json(final, "output/json/team_ratings.json", pretty = TRUE)

message("Done! Spot check 2026:")
final |>
  dplyr::filter(season == 2026) |>
  dplyr::select(team_display_name, wins, losses, luck) |>
  dplyr::arrange(dplyr::desc(luck)) |>
  head(10) |>
  print()
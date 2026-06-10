library(dplyr)
library(readr)
library(jsonlite)

processed <- readr::read_csv("data/processed/team_season_stats.csv", show_col_types = FALSE)
ratings <- readr::read_csv("data/processed/team_ratings.csv", show_col_types = FALSE) |>
  dplyr::select(season, team_id, net)

four_factors <- processed |>
  dplyr::left_join(ratings, by = c("season", "team_id")) |>
  dplyr::mutate(
    off_efg    = round((fgm + 0.5 * fg3m) / fga * 100, 1),
    off_to_pct = round(turnovers / (fga + 0.475 * fta + turnovers) * 100, 1),
    off_or_pct = round(off_reb / (off_reb + opp_def_reb) * 100, 1),
    off_ftr    = round(fta / fga * 100, 1),
    def_efg    = round((opp_fgm + 0.5 * opp_fg3m) / opp_fga * 100, 1),
    def_to_pct = round(opp_turnovers / (opp_fga + 0.475 * opp_fta + opp_turnovers) * 100, 1),
    def_or_pct = round(opp_off_reb / (opp_off_reb + def_reb) * 100, 1),
    def_ftr    = round(opp_fta / opp_fga * 100, 1)
  ) |>
  dplyr::select(
    season, team_id, team_display_name, team_abbreviation,
    team_location, team_name, team_logo, team_color,
    team_alternate_color, wins, losses, games, net,
    off_efg, off_to_pct, off_or_pct, off_ftr,
    def_efg, def_to_pct, def_or_pct, def_ftr
  )

readr::write_csv(four_factors, "data/processed/four_factors.csv")
jsonlite::write_json(four_factors, "output/json/four_factors.json", pretty = TRUE)

message("Done! Records: ", nrow(four_factors))

four_factors |>
  dplyr::filter(season == 2026) |>
  dplyr::arrange(dplyr::desc(net)) |>
  dplyr::select(team_display_name, wins, losses, net,
                off_efg, off_to_pct, off_or_pct, off_ftr,
                def_efg, def_to_pct, def_or_pct, def_ftr) |>
  dplyr::slice_head(n = 10) |>
  print()
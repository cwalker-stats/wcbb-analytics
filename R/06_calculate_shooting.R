library(dplyr)
library(readr)
library(jsonlite)

processed <- readr::read_csv("data/processed/team_season_stats.csv", show_col_types = FALSE)
ratings <- readr::read_csv("data/processed/team_ratings.csv", show_col_types = FALSE) |>
  dplyr::select(season, team_id, net)

shooting <- processed |>
  dplyr::left_join(ratings, by = c("season", "team_id")) |>
  dplyr::mutate(
    efg_pct     = round((fgm + 0.5 * fg3m) / fga * 100, 1),
    ts_pct      = round(points / (2 * (fga + 0.475 * fta)) * 100, 1),
    fg2m        = fgm - fg3m,
    fg2a        = fga - fg3a,
    fg2_pct     = round(fg2m / fg2a * 100, 1),
    fg3_pct_off = round(fg3_pct, 1),
    fg3a_rate   = round(fg3a / fga * 100, 1),
    fg3m_rate   = round(fg3m / fgm * 100, 1),
    ftr         = round(fta / fga * 100, 1),
    ft_pct_off  = round(ft_pct, 1)
  ) |>
  dplyr::select(
    season, team_id, team_display_name, team_abbreviation,
    team_location, team_name, team_logo, team_color,
    team_alternate_color, wins, losses, games, net,
    efg_pct, ts_pct, fg2_pct, fg3_pct_off,
    fg3a_rate, fg3m_rate, ftr, ft_pct_off
  )

readr::write_csv(shooting, "data/processed/shooting.csv")
jsonlite::write_json(shooting, "output/json/shooting.json", pretty = TRUE)

message("Done! Records: ", nrow(shooting))

shooting |>
  dplyr::filter(season == 2026) |>
  dplyr::arrange(dplyr::desc(net)) |>
  dplyr::select(team_display_name, wins, losses, net,
                efg_pct, ts_pct, fg2_pct, fg3_pct_off,
                fg3a_rate, fg3m_rate, ftr, ft_pct_off) |>
  dplyr::slice_head(n = 10) |>
  print()
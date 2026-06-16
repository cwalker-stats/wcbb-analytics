library(dplyr)
library(readr)
library(jsonlite)

processed <- readr::read_csv("data/processed/team_season_stats.csv", show_col_types = FALSE)
ratings <- readr::read_csv("data/processed/team_ratings.csv", show_col_types = FALSE) |>
  dplyr::select(season, team_id, net)

misc <- processed |>
  dplyr::left_join(ratings, by = c("season", "team_id")) |>
  dplyr::mutate(
    off_ast_pct  = round(assists / fgm * 100, 1),
    off_ato      = round(assists / turnovers, 2),
    off_ft_pct   = round(ft_pct, 1),
    off_stl_pct  = round(steals / (fga + 0.475 * fta + turnovers) * 100, 1),
    off_blk_pct  = round(blocks / (opp_fga - opp_fg3a) * 100, 1),
    def_ast_pct  = round(opp_assists / opp_fgm * 100, 1),
    def_ato      = round(opp_assists / opp_turnovers, 2),
    def_ft_pct   = round(opp_ft_pct, 1),
    def_stl_pct  = round(opp_steals / (opp_fga + 0.475 * opp_fta + opp_turnovers) * 100, 1),
    def_blk_pct  = round(opp_blocks / (fga - fg3a) * 100, 1)
  ) |>
  dplyr::select(
    season, team_id, team_display_name, team_abbreviation,
    team_location, team_name, team_logo, team_color,
    team_alternate_color, wins, losses, games, net,
    conference, conference_short,
    off_ast_pct, off_ato, off_ft_pct, off_stl_pct, off_blk_pct,
    def_ast_pct, def_ato, def_ft_pct, def_stl_pct, def_blk_pct
  )

readr::write_csv(misc, "data/processed/misc.csv")
jsonlite::write_json(misc, "output/json/misc.json", pretty = TRUE)

message("Done! Records: ", nrow(misc))

misc |>
  dplyr::filter(season == 2026) |>
  dplyr::arrange(dplyr::desc(net)) |>
  dplyr::select(team_display_name, wins, losses, net,
                off_ast_pct, off_ato, off_ft_pct, off_stl_pct, off_blk_pct,
                def_ast_pct, def_ato, def_ft_pct, def_stl_pct, def_blk_pct) |>
  dplyr::slice_head(n = 10) |>
  print()
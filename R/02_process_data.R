library(dplyr)
library(readr)
library(janitor)
library(jsonlite)

raw <- readr::read_csv("data/raw/wbb_team_box_raw.csv", show_col_types = FALSE)
d1_ids <- readr::read_csv("data/raw/d1_team_ids.csv", show_col_types = FALSE)

raw_d1 <- raw |>
  dplyr::inner_join(d1_ids, by = c("season", "team_id"))

message("Rows after D1 filter: ", nrow(raw_d1), " (was ", nrow(raw), ")")

opponent_stats <- raw_d1 |>
  dplyr::select(
    game_id,
    opp_team_id = team_id,
    opp_fgm = field_goals_made,
    opp_fga = field_goals_attempted,
    opp_fg_pct = field_goal_pct,
    opp_fg3m = three_point_field_goals_made,
    opp_fg3a = three_point_field_goals_attempted,
    opp_fg3_pct = three_point_field_goal_pct,
    opp_ftm = free_throws_made,
    opp_fta = free_throws_attempted,
    opp_ft_pct = free_throw_pct,
    opp_off_reb = offensive_rebounds,
    opp_def_reb = defensive_rebounds,
    opp_tot_reb = total_rebounds,
    opp_turnovers = total_turnovers
  )

joined <- raw_d1 |>
  dplyr::left_join(opponent_stats,
                   by = dplyr::join_by(game_id, opponent_team_id == opp_team_id))

team_season_stats <- joined |>
  dplyr::group_by(season, team_id, team_display_name, team_abbreviation,
                  team_location, team_name, team_logo, team_color,
                  team_alternate_color) |>
  dplyr::summarise(
    games = dplyr::n(),
    wins = sum(team_winner, na.rm = TRUE),
    losses = sum(!team_winner, na.rm = TRUE),
    points = mean(team_score, na.rm = TRUE),
    opp_points = mean(opponent_team_score, na.rm = TRUE),
    fgm = mean(field_goals_made, na.rm = TRUE),
    fga = mean(field_goals_attempted, na.rm = TRUE),
    fg_pct = mean(field_goal_pct, na.rm = TRUE),
    fg3m = mean(three_point_field_goals_made, na.rm = TRUE),
    fg3a = mean(three_point_field_goals_attempted, na.rm = TRUE),
    fg3_pct = mean(three_point_field_goal_pct, na.rm = TRUE),
    ftm = mean(free_throws_made, na.rm = TRUE),
    fta = mean(free_throws_attempted, na.rm = TRUE),
    ft_pct = mean(free_throw_pct, na.rm = TRUE),
    off_reb = mean(offensive_rebounds, na.rm = TRUE),
    def_reb = mean(defensive_rebounds, na.rm = TRUE),
    tot_reb = mean(total_rebounds, na.rm = TRUE),
    assists = mean(assists, na.rm = TRUE),
    steals = mean(steals, na.rm = TRUE),
    blocks = mean(blocks, na.rm = TRUE),
    turnovers = mean(total_turnovers, na.rm = TRUE),
    fouls = mean(fouls, na.rm = TRUE),
    opp_fgm = mean(opp_fgm, na.rm = TRUE),
    opp_fga = mean(opp_fga, na.rm = TRUE),
    opp_fg_pct = mean(opp_fg_pct, na.rm = TRUE),
    opp_fg3m = mean(opp_fg3m, na.rm = TRUE),
    opp_fg3a = mean(opp_fg3a, na.rm = TRUE),
    opp_fg3_pct = mean(opp_fg3_pct, na.rm = TRUE),
    opp_ftm = mean(opp_ftm, na.rm = TRUE),
    opp_fta = mean(opp_fta, na.rm = TRUE),
    opp_ft_pct = mean(opp_ft_pct, na.rm = TRUE),
    opp_tot_reb = mean(opp_tot_reb, na.rm = TRUE),
    opp_off_reb = mean(opp_off_reb, na.rm = TRUE),
    opp_def_reb = mean(opp_def_reb, na.rm = TRUE),
    opp_turnovers = mean(opp_turnovers, na.rm = TRUE),
    .groups = "drop"
  ) |>
  janitor::clean_names()

readr::write_csv(team_season_stats, "data/processed/team_season_stats.csv")

jsonlite::write_json(team_season_stats, "output/json/team_season_stats.json", pretty = TRUE)

message("Done! Teams processed: ", nrow(team_season_stats))
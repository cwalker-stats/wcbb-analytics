library(dplyr)
library(readr)
library(jsonlite)
library(purrr)

raw <- readr::read_csv("data/raw/wbb_team_box_raw.csv", show_col_types = FALSE)
d1_ids <- readr::read_csv("data/raw/d1_team_ids.csv", show_col_types = FALSE)
game_minutes <- readr::read_csv("data/raw/game_minutes.csv", show_col_types = FALSE)
conf_data <- readr::read_csv("data/raw/conference_data.csv", show_col_types = FALSE)

raw_d1 <- raw |>
  dplyr::inner_join(d1_ids, by = c("season", "team_id")) |>
  dplyr::left_join(
    conf_data |> dplyr::select(season, team_id, conference, conference_short),
    by = c("season", "team_id")
  )

game_stats <- raw_d1 |>
  dplyr::mutate(
    poss = field_goals_attempted - offensive_rebounds + total_turnovers + 0.475 * free_throws_attempted
  ) |>
  dplyr::select(
    season, game_id, team_id, opponent_team_id,
    team_score, opponent_team_score, poss
  )

game_pairs <- game_stats |>
  dplyr::inner_join(
    game_stats |>
      dplyr::select(game_id, opponent_team_id = team_id, opp_poss = poss),
    by = c("game_id", "opponent_team_id")
  ) |>
  dplyr::inner_join(
    d1_ids |> dplyr::select(season, opponent_team_id = team_id),
    by = c("season", "opponent_team_id")
  ) |>
  dplyr::left_join(
    game_minutes |> dplyr::select(game_id, game_minutes),
    by = "game_id"
  ) |>
  dplyr::filter(!is.na(game_minutes)) |>
  dplyr::mutate(
    game_poss = (poss + opp_poss) / 2,
    raw_ortg  = 100 * team_score / game_poss,
    raw_drtg  = 100 * opponent_team_score / game_poss,
    raw_pace  = game_poss / game_minutes * 40
  )

message("Game-level stats calculated. Games: ", nrow(game_pairs))

iterate_ratings <- function(season_games, n_iter = 30) {
  d1_avg_ortg <- 100 * sum(season_games$team_score, na.rm = TRUE) / sum(season_games$game_poss, na.rm = TRUE)
  d1_avg_drtg <- 100 * sum(season_games$opponent_team_score, na.rm = TRUE) / sum(season_games$game_poss, na.rm = TRUE)
  d1_avg_pace <- mean(season_games$raw_pace, na.rm = TRUE)
  
  ratings <- season_games |>
    dplyr::group_by(team_id) |>
    dplyr::summarise(
      adj_ortg = mean(raw_ortg, na.rm = TRUE),
      adj_drtg = mean(raw_drtg, na.rm = TRUE),
      adj_pace = mean(raw_pace, na.rm = TRUE),
      .groups  = "drop"
    )
  
  for (i in seq_len(n_iter)) {
    opp_ratings <- ratings |>
      dplyr::select(
        opponent_team_id = team_id,
        opp_adj_ortg     = adj_ortg,
        opp_adj_drtg     = adj_drtg,
        opp_adj_pace     = adj_pace
      )
    
    new_ratings <- season_games |>
      dplyr::left_join(opp_ratings, by = "opponent_team_id") |>
      dplyr::group_by(team_id) |>
      dplyr::summarise(
        adj_ortg = mean(raw_ortg * (d1_avg_drtg / opp_adj_drtg), na.rm = TRUE),
        adj_drtg = mean(raw_drtg * (d1_avg_ortg / opp_adj_ortg), na.rm = TRUE),
        adj_pace = mean(raw_pace * (d1_avg_pace / opp_adj_pace), na.rm = TRUE),
        .groups  = "drop"
      )
    
    ratings <- new_ratings
  }
  
  ratings
}

message("Running iterative adjustments (KenPom multiplicative method)...")

seasons <- sort(unique(game_pairs$season))

adjusted_ratings <- purrr::map_dfr(seasons, function(s) {
  message("  Season ", s, "...")
  season_games <- game_pairs |> dplyr::filter(season == s)
  iterate_ratings(season_games) |> dplyr::mutate(season = s)
})

message("Calculating SOS metrics...")

league_avgs <- game_pairs |>
  dplyr::group_by(season) |>
  dplyr::summarise(
    league_avg_ortg = mean(raw_ortg, na.rm = TRUE),
    league_avg_drtg = mean(raw_drtg, na.rm = TRUE),
    league_avg_pace = mean(raw_pace, na.rm = TRUE),
    .groups = "drop"
  )

raw_team_avg <- game_pairs |>
  dplyr::group_by(season, team_id) |>
  dplyr::summarise(
    raw_ortg = mean(raw_ortg, na.rm = TRUE),
    raw_drtg = mean(raw_drtg, na.rm = TRUE),
    .groups  = "drop"
  )

sos_metrics <- game_pairs |>
  dplyr::left_join(
    raw_team_avg |>
      dplyr::select(
        season,
        opponent_team_id = team_id,
        opp_raw_ortg     = raw_ortg,
        opp_raw_drtg     = raw_drtg
      ),
    by = c("season", "opponent_team_id")
  ) |>
  dplyr::left_join(league_avgs, by = "season") |>
  dplyr::group_by(season, team_id) |>
  dplyr::summarise(
    sos  = mean((opp_raw_ortg - opp_raw_drtg) - (league_avg_ortg - league_avg_drtg), na.rm = TRUE),
    osos = mean(opp_raw_drtg - league_avg_drtg, na.rm = TRUE),
    dsos = mean(opp_raw_ortg - league_avg_ortg, na.rm = TRUE),
    .groups = "drop"
  )

team_info <- raw_d1 |>
  dplyr::distinct(
    season, team_id, team_display_name, team_abbreviation,
    team_location, team_name, team_logo, team_color, team_alternate_color,
    conference, conference_short
  )

wins_losses <- raw_d1 |>
  dplyr::group_by(season, team_id) |>
  dplyr::summarise(
    wins   = sum(team_winner, na.rm = TRUE),
    losses = sum(!team_winner, na.rm = TRUE),
    games  = dplyr::n(),
    .groups = "drop"
  )

final_ratings <- adjusted_ratings |>
  dplyr::left_join(sos_metrics, by = c("season", "team_id")) |>
  dplyr::left_join(team_info,   by = c("season", "team_id")) |>
  dplyr::left_join(wins_losses, by = c("season", "team_id")) |>
  dplyr::rename(
    ortg = adj_ortg,
    drtg = adj_drtg,
    pace = adj_pace
  ) |>
  dplyr::left_join(
    league_avgs |> dplyr::select(season, league_avg_ortg, league_avg_drtg),
    by = "season"
  ) |>
  dplyr::mutate(
    season_avg = (league_avg_ortg + league_avg_drtg) / 2,
    scale      = 100 / season_avg,
    ortg       = round(ortg * scale, 1),
    drtg       = round(drtg * scale, 1),
    net        = round(ortg - drtg, 1),
    sos        = round(sos, 2),
    osos       = round(osos, 2),
    dsos       = round(dsos, 2),
    pace       = round(pace, 1)
  ) |>
  dplyr::select(-season_avg, -scale, -league_avg_ortg, -league_avg_drtg) |>
  dplyr::arrange(season, dplyr::desc(net))

readr::write_csv(final_ratings, "data/processed/team_ratings.csv")
jsonlite::write_json(final_ratings, "output/json/team_ratings.json", pretty = TRUE)

message("Done! Records: ", nrow(final_ratings))

final_ratings |>
  dplyr::filter(season == 2026) |>
  dplyr::select(team_display_name, wins, losses, net, ortg, drtg, sos, osos, dsos, pace) |>
  dplyr::slice_head(n = 10) |>
  print()

final_ratings |>
  dplyr::filter(season == 2026) |>
  dplyr::summarise(
    avg_ortg = mean(ortg),
    avg_drtg = mean(drtg),
    avg_net  = mean(net),
    avg_pace = mean(pace),
    avg_sos  = mean(sos)
  ) |>
  print()
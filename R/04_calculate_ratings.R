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
    poss = field_goals_attempted - offensive_rebounds + total_turnovers + 0.44 * free_throws_attempted
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

iterate_ratings <- function(season_games, n_iter = 50, tol = 0.01) {
  
  team_total_poss <- season_games |>
    dplyr::group_by(team_id) |>
    dplyr::summarise(total_poss = sum(game_poss, na.rm = TRUE), .groups = "drop")
  
  ratings <- season_games |>
    dplyr::group_by(team_id) |>
    dplyr::summarise(
      adj_ortg = weighted.mean(raw_ortg, w = game_poss, na.rm = TRUE),
      adj_drtg = weighted.mean(raw_drtg, w = game_poss, na.rm = TRUE),
      pace     = weighted.mean(raw_pace, w = game_poss, na.rm = TRUE),
      .groups  = "drop"
    )
  
  for (i in seq_len(n_iter)) {
    poss_weights <- team_total_poss$total_poss[match(ratings$team_id, team_total_poss$team_id)]
    league_ortg <- weighted.mean(ratings$adj_ortg, w = poss_weights, na.rm = TRUE)
    league_drtg <- weighted.mean(ratings$adj_drtg, w = poss_weights, na.rm = TRUE)
    
    opp_ratings <- ratings |>
      dplyr::select(
        opponent_team_id = team_id,
        opp_adj_ortg     = adj_ortg,
        opp_adj_drtg     = adj_drtg
      )
    
    new_ratings <- season_games |>
      dplyr::left_join(opp_ratings, by = "opponent_team_id") |>
      dplyr::group_by(team_id) |>
      dplyr::summarise(
        adj_ortg = weighted.mean(raw_ortg * (league_drtg / opp_adj_drtg), w = game_poss, na.rm = TRUE),
        adj_drtg = weighted.mean(raw_drtg * (league_ortg / opp_adj_ortg), w = game_poss, na.rm = TRUE),
        .groups  = "drop"
      )
    
    poss_weights_new <- team_total_poss$total_poss[match(new_ratings$team_id, team_total_poss$team_id)]
    mean_o <- weighted.mean(new_ratings$adj_ortg, w = poss_weights_new, na.rm = TRUE)
    mean_d <- weighted.mean(new_ratings$adj_drtg, w = poss_weights_new, na.rm = TRUE)
    
    new_ratings <- new_ratings |>
      dplyr::mutate(
        adj_ortg = adj_ortg * (league_ortg / mean_o),
        adj_drtg = adj_drtg * (league_drtg / mean_d)
      )
    
    max_change <- max(
      c(
        abs(new_ratings$adj_ortg - ratings$adj_ortg),
        abs(new_ratings$adj_drtg - ratings$adj_drtg)
      ),
      na.rm = TRUE
    )
    
    ratings <- ratings |>
      dplyr::select(team_id, pace) |>
      dplyr::inner_join(new_ratings, by = "team_id")
    
    if (max_change < tol) {
      message("    Converged at iteration ", i)
      break
    }
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

message("Computing SOS from converged ratings...")

team_poss <- game_pairs |>
  dplyr::group_by(season, team_id) |>
  dplyr::summarise(total_poss = sum(game_poss, na.rm = TRUE), .groups = "drop")

league_avg_adj <- adjusted_ratings |>
  dplyr::left_join(team_poss, by = c("season", "team_id")) |>
  dplyr::group_by(season) |>
  dplyr::summarise(
    league_avg_adj_ortg = weighted.mean(adj_ortg, w = total_poss, na.rm = TRUE),
    league_avg_adj_drtg = weighted.mean(adj_drtg, w = total_poss, na.rm = TRUE),
    .groups = "drop"
  )

sos_metrics <- game_pairs |>
  dplyr::left_join(
    adjusted_ratings |>
      dplyr::select(
        season,
        opponent_team_id = team_id,
        opp_adj_ortg     = adj_ortg,
        opp_adj_drtg     = adj_drtg
      ),
    by = c("season", "opponent_team_id")
  ) |>
  dplyr::left_join(league_avg_adj, by = "season") |>
  dplyr::group_by(season, team_id) |>
  dplyr::summarise(
    dsos = weighted.mean(opp_adj_ortg - league_avg_adj_ortg, w = game_poss, na.rm = TRUE),
    osos = weighted.mean(league_avg_adj_drtg - opp_adj_drtg, w = game_poss, na.rm = TRUE),
    sos  = dsos + osos,
    .groups = "drop"
  )

message("Scaling ratings to interpretable baseline...")

league_scales <- adjusted_ratings |>
  dplyr::left_join(team_poss, by = c("season", "team_id")) |>
  dplyr::group_by(season) |>
  dplyr::summarise(
    league_ortg_scale = weighted.mean(adj_ortg, w = total_poss, na.rm = TRUE),
    league_drtg_scale = weighted.mean(adj_drtg, w = total_poss, na.rm = TRUE),
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
  dplyr::left_join(league_scales, by = "season") |>
  dplyr::mutate(
    ortg = adj_ortg * (100 / league_ortg_scale),
    drtg = adj_drtg * (100 / league_drtg_scale)
  ) |>
  dplyr::group_by(season) |>
  dplyr::mutate(
    net_center = mean(ortg - drtg, na.rm = TRUE),
    drtg = drtg + net_center,
    ortg = round(ortg, 1),
    drtg = round(drtg, 1),
    net  = round(ortg - drtg, 1),
    pace = round(pace, 1)
  ) |>
  dplyr::ungroup() |>
  dplyr::select(-adj_ortg, -adj_drtg, -league_ortg_scale, -league_drtg_scale, -net_center) |>
  dplyr::left_join(sos_metrics, by = c("season", "team_id")) |>
  dplyr::left_join(team_info,   by = c("season", "team_id")) |>
  dplyr::left_join(wins_losses, by = c("season", "team_id")) |>
  dplyr::mutate(
    sos  = round(sos,  2),
    osos = round(osos, 2),
    dsos = round(dsos, 2)
  ) |>
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
    mean_ortg = mean(ortg),
    mean_drtg = mean(drtg),
    mean_net  = mean(net),
    mean_sos  = mean(sos),
    mean_dsos = mean(dsos),
    mean_osos = mean(osos),
    mean_pace = mean(pace)
  ) |>
  print()
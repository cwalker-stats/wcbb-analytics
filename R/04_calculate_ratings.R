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

iterate_efficiency <- function(season_games, n_iter = 100, tol = 0.005, damping = 0.7) {
  
  league_ortg <- weighted.mean(season_games$raw_ortg, w = season_games$game_poss, na.rm = TRUE)
  league_drtg <- weighted.mean(season_games$raw_drtg, w = season_games$game_poss, na.rm = TRUE)
  
  ratings <- season_games |>
    dplyr::group_by(team_id) |>
    dplyr::summarise(
      adj_ortg = weighted.mean(raw_ortg, w = game_poss, na.rm = TRUE),
      adj_drtg = weighted.mean(raw_drtg, w = game_poss, na.rm = TRUE),
      .groups  = "drop"
    )
  
  for (i in seq_len(n_iter)) {
    opp_ratings <- ratings |>
      dplyr::select(
        opponent_team_id = team_id,
        opp_adj_ortg     = adj_ortg,
        opp_adj_drtg     = adj_drtg
      )
    
    game_adj <- season_games |>
      dplyr::left_join(opp_ratings, by = "opponent_team_id") |>
      dplyr::mutate(
        game_adj_ortg = raw_ortg - (opp_adj_drtg - league_drtg),
        game_adj_drtg = raw_drtg - (opp_adj_ortg - league_ortg)
      )
    
    proposed_ratings <- game_adj |>
      dplyr::group_by(team_id) |>
      dplyr::summarise(
        adj_ortg = weighted.mean(game_adj_ortg, w = game_poss, na.rm = TRUE),
        adj_drtg = weighted.mean(game_adj_drtg, w = game_poss, na.rm = TRUE),
        .groups  = "drop"
      )
    
    new_ratings <- ratings |>
      dplyr::inner_join(proposed_ratings, by = "team_id", suffix = c("_old", "_new")) |>
      dplyr::mutate(
        adj_ortg = damping * adj_ortg_new + (1 - damping) * adj_ortg_old,
        adj_drtg = damping * adj_drtg_new + (1 - damping) * adj_drtg_old
      ) |>
      dplyr::select(team_id, adj_ortg, adj_drtg)
    
    deltas <- c(
      abs(new_ratings$adj_ortg - ratings$adj_ortg),
      abs(new_ratings$adj_drtg - ratings$adj_drtg)
    )
    max_change    <- max(deltas, na.rm = TRUE)
    median_change <- median(deltas, na.rm = TRUE)
    
    ratings <- new_ratings
    
    if (median_change < tol) {
      message("    Converged at iteration ", i, " (median_change = ", round(median_change, 5), ")")
      break
    }
  }
  
  ratings
}

iterate_pace <- function(season_games, n_iter = 100, tol = 0.005, damping = 0.7) {
  
  league_pace <- weighted.mean(season_games$raw_pace, w = season_games$game_poss, na.rm = TRUE)
  
  ratings <- season_games |>
    dplyr::group_by(team_id) |>
    dplyr::summarise(
      adj_pace = weighted.mean(raw_pace, w = game_poss, na.rm = TRUE),
      .groups  = "drop"
    )
  
  for (i in seq_len(n_iter)) {
    opp_ratings <- ratings |>
      dplyr::select(opponent_team_id = team_id, opp_adj_pace = adj_pace)
    
    game_adj <- season_games |>
      dplyr::left_join(opp_ratings, by = "opponent_team_id") |>
      dplyr::mutate(
        game_adj_pace = raw_pace - (opp_adj_pace - league_pace)
      )
    
    proposed_ratings <- game_adj |>
      dplyr::group_by(team_id) |>
      dplyr::summarise(
        adj_pace = weighted.mean(game_adj_pace, w = game_poss, na.rm = TRUE),
        .groups  = "drop"
      )
    
    new_ratings <- ratings |>
      dplyr::inner_join(proposed_ratings, by = "team_id", suffix = c("_old", "_new")) |>
      dplyr::mutate(
        adj_pace = damping * adj_pace_new + (1 - damping) * adj_pace_old
      ) |>
      dplyr::select(team_id, adj_pace)
    
    deltas <- abs(new_ratings$adj_pace - ratings$adj_pace)
    median_change <- median(deltas, na.rm = TRUE)
    
    ratings <- new_ratings
    
    if (median_change < tol) {
      message("    Pace converged at iteration ", i)
      break
    }
  }
  
  ratings
}

message("Running additive opponent-adjusted iteration (KenPom-style)...")

seasons <- sort(unique(game_pairs$season))

adjusted_ratings <- purrr::map_dfr(seasons, function(s) {
  message("  Season ", s, " efficiency...")
  season_games <- game_pairs |> dplyr::filter(season == s)
  eff <- iterate_efficiency(season_games)
  message("  Season ", s, " pace...")
  pace <- iterate_pace(season_games)
  eff |>
    dplyr::left_join(pace, by = "team_id") |>
    dplyr::mutate(season = s)
})

message("Computing SOS from converged ratings...")

league_avg_adj <- adjusted_ratings |>
  dplyr::group_by(season) |>
  dplyr::summarise(
    league_avg_adj_ortg = mean(adj_ortg, na.rm = TRUE),
    league_avg_adj_drtg = mean(adj_drtg, na.rm = TRUE),
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

message("Finalizing ratings...")

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
  dplyr::group_by(season) |>
  dplyr::mutate(
    net_center = mean(adj_ortg - adj_drtg, na.rm = TRUE),
    ortg = round(adj_ortg, 1),
    drtg = round(adj_drtg + net_center, 1),
    net  = round(ortg - drtg, 1),
    pace = round(adj_pace, 1)
  ) |>
  dplyr::ungroup() |>
  dplyr::select(-adj_ortg, -adj_drtg, -adj_pace, -net_center) |>
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
    mean_pace = mean(pace),
    sd_net    = sd(net),
    min_net   = min(net),
    max_net   = max(net)
  ) |>
  print()
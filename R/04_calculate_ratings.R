library(dplyr)
library(readr)
library(jsonlite)
library(purrr)

raw        <- readr::read_csv("data/raw/wbb_team_box_raw.csv",  show_col_types = FALSE)
d1_ids     <- readr::read_csv("data/raw/d1_team_ids.csv",       show_col_types = FALSE)
game_minutes <- readr::read_csv("data/raw/game_minutes.csv",    show_col_types = FALSE)
conf_data  <- readr::read_csv("data/raw/conference_data.csv",   show_col_types = FALSE)
schedule   <- readr::read_csv("data/raw/game_schedule.csv",     show_col_types = FALSE)

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
    season, game_id, game_date, team_id, opponent_team_id,
    team_score, opponent_team_score, team_home_away, poss
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
  dplyr::left_join(
    schedule |> dplyr::select(game_id, neutral_site),
    by = "game_id"
  ) |>
  dplyr::filter(!is.na(game_minutes)) |>
  dplyr::mutate(
    game_poss = (poss + opp_poss) / 2,
    raw_ortg  = 100 * team_score / game_poss,
    raw_drtg  = 100 * opponent_team_score / game_poss,
    raw_pace  = game_poss / game_minutes * 40,
    eff_poss  = game_poss
  )

message("Game-level stats calculated. Games: ", nrow(game_pairs))

game_pairs |>
  dplyr::count(neutral_site, team_home_away) |>
  print()

iterate_efficiency <- function(season_games, hca = 3.5, n_iter = 100, tol = 0.005, damping = 0.7, k_shrink = 100) {
  
  scale_factor <- 100 / weighted.mean(season_games$raw_ortg, w = season_games$game_poss, na.rm = TRUE)
  hca_scaled   <- hca * scale_factor
  
  season_games <- season_games |>
    dplyr::mutate(
      raw_ortg = raw_ortg * scale_factor,
      raw_drtg = raw_drtg * scale_factor,
      site_adj = dplyr::case_when(
        neutral_site == TRUE              ~ 0,
        team_home_away == "home"          ~ hca_scaled / 2,
        team_home_away == "away"          ~ -hca_scaled / 2,
        TRUE                              ~ 0
      ),
      raw_ortg_site = raw_ortg - site_adj,
      raw_drtg_site = raw_drtg + site_adj
    )
  
  league_ortg <- weighted.mean(season_games$raw_ortg_site, w = season_games$eff_poss, na.rm = TRUE)
  league_drtg <- weighted.mean(season_games$raw_drtg_site, w = season_games$eff_poss, na.rm = TRUE)
  
  opp_map <- season_games |>
    dplyr::select(team_id, opponent_team_id, game_poss, eff_poss, raw_ortg_site, raw_drtg_site)
  
  ratings <- season_games |>
    dplyr::group_by(team_id) |>
    dplyr::summarise(
      adj_ortg = weighted.mean(raw_ortg_site, w = eff_poss, na.rm = TRUE),
      adj_drtg = weighted.mean(raw_drtg_site, w = eff_poss, na.rm = TRUE),
      .groups  = "drop"
    )
  
  stable_count <- 0
  
  for (i in seq_len(n_iter)) {
    opp_ratings <- ratings |>
      dplyr::select(
        opponent_team_id = team_id,
        opp_adj_ortg     = adj_ortg,
        opp_adj_drtg     = adj_drtg
      )
    
    game_adj <- opp_map |>
      dplyr::left_join(opp_ratings, by = "opponent_team_id") |>
      dplyr::mutate(
        game_adj_ortg = raw_ortg_site - (opp_adj_drtg - league_drtg),
        game_adj_drtg = raw_drtg_site - (opp_adj_ortg - league_ortg)
      )
    
    proposed_ratings <- game_adj |>
      dplyr::group_by(team_id) |>
      dplyr::summarise(
        sum_eff_poss  = sum(eff_poss, na.rm = TRUE),
        sum_ortg_poss = sum(game_adj_ortg * eff_poss, na.rm = TRUE),
        sum_drtg_poss = sum(game_adj_drtg * eff_poss, na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::mutate(
        adj_ortg = (sum_ortg_poss + k_shrink * league_ortg) / (sum_eff_poss + k_shrink),
        adj_drtg = (sum_drtg_poss + k_shrink * league_drtg) / (sum_eff_poss + k_shrink)
      )
    
    new_ratings <- ratings |>
      dplyr::inner_join(proposed_ratings, by = "team_id", suffix = c("_old", "_new")) |>
      dplyr::mutate(
        adj_ortg = damping * adj_ortg_new + (1 - damping) * adj_ortg_old,
        adj_drtg = damping * adj_drtg_new + (1 - damping) * adj_drtg_old
      ) |>
      dplyr::select(team_id, adj_ortg, adj_drtg, sum_eff_poss)
    
    mean_o        <- weighted.mean(new_ratings$adj_ortg, w = new_ratings$sum_eff_poss, na.rm = TRUE)
    mean_d        <- weighted.mean(new_ratings$adj_drtg, w = new_ratings$sum_eff_poss, na.rm = TRUE)
    shared_center <- (mean_o + mean_d) / 2
    target_center <- (league_ortg + league_drtg) / 2
    drift         <- shared_center - target_center
    
    new_ratings <- new_ratings |>
      dplyr::mutate(
        adj_ortg = adj_ortg - drift,
        adj_drtg = adj_drtg - drift
      ) |>
      dplyr::select(team_id, adj_ortg, adj_drtg)
    
    deltas <- c(
      abs(new_ratings$adj_ortg - ratings$adj_ortg),
      abs(new_ratings$adj_drtg - ratings$adj_drtg)
    )
    median_change <- median(deltas, na.rm = TRUE)
    
    ratings <- new_ratings
    
    if (median_change < tol) {
      stable_count <- stable_count + 1
    } else {
      stable_count <- 0
    }
    
    if (stable_count >= 2) {
      message("    Converged at iteration ", i, " (2 consecutive stable iterations)")
      break
    }
  }
  
  ratings |>
    dplyr::mutate(
      adj_ortg = adj_ortg / scale_factor,
      adj_drtg = adj_drtg / scale_factor
    )
}

iterate_pace <- function(season_games, n_iter = 100, tol = 0.005, damping = 0.7, k_shrink = 100) {
  
  league_pace <- weighted.mean(season_games$raw_pace, w = season_games$eff_poss, na.rm = TRUE)
  
  opp_map <- season_games |>
    dplyr::select(team_id, opponent_team_id, game_poss, eff_poss, raw_pace)
  
  ratings <- season_games |>
    dplyr::group_by(team_id) |>
    dplyr::summarise(
      adj_pace = weighted.mean(raw_pace, w = eff_poss, na.rm = TRUE),
      .groups  = "drop"
    )
  
  stable_count <- 0
  
  for (i in seq_len(n_iter)) {
    opp_ratings <- ratings |>
      dplyr::select(opponent_team_id = team_id, opp_adj_pace = adj_pace)
    
    game_adj <- opp_map |>
      dplyr::left_join(opp_ratings, by = "opponent_team_id") |>
      dplyr::mutate(
        game_adj_pace = raw_pace * league_pace / opp_adj_pace
      )
    
    proposed_ratings <- game_adj |>
      dplyr::group_by(team_id) |>
      dplyr::summarise(
        sum_eff_poss  = sum(eff_poss, na.rm = TRUE),
        sum_pace_poss = sum(game_adj_pace * eff_poss, na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::mutate(
        adj_pace = (sum_pace_poss + k_shrink * league_pace) / (sum_eff_poss + k_shrink)
      )
    
    new_ratings <- ratings |>
      dplyr::inner_join(proposed_ratings, by = "team_id", suffix = c("_old", "_new")) |>
      dplyr::mutate(
        adj_pace = damping * adj_pace_new + (1 - damping) * adj_pace_old
      ) |>
      dplyr::select(team_id, adj_pace, sum_eff_poss)
    
    mean_p <- weighted.mean(new_ratings$adj_pace, w = new_ratings$sum_eff_poss, na.rm = TRUE)
    
    new_ratings <- new_ratings |>
      dplyr::mutate(adj_pace = adj_pace * league_pace / mean_p) |>
      dplyr::select(team_id, adj_pace)
    
    deltas <- abs(new_ratings$adj_pace - ratings$adj_pace)
    median_change <- median(deltas, na.rm = TRUE)
    
    ratings <- new_ratings
    
    if (median_change < tol) {
      stable_count <- stable_count + 1
    } else {
      stable_count <- 0
    }
    
    if (stable_count >= 2) {
      message("    Pace converged at iteration ", i)
      break
    }
  }
  
  ratings
}

message("Running ratings with home court adjustment (HCA = 3.5 pts)...")

seasons <- sort(unique(game_pairs$season))

adjusted_ratings <- purrr::map_dfr(seasons, function(s) {
  message("  Season ", s, " efficiency...")
  season_games <- game_pairs |> dplyr::filter(season == s)
  eff <- iterate_efficiency(season_games, hca = 3.5)
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
  dplyr::mutate(
    ortg = round(adj_ortg, 1),
    drtg = round(adj_drtg, 1),
    net  = round(adj_ortg - adj_drtg, 1),
    pace = round(adj_pace, 1)
  ) |>
  dplyr::select(-adj_ortg, -adj_drtg, -adj_pace) |>
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
library(dplyr)
library(readr)

raw       <- readr::read_csv("data/raw/wbb_team_box_raw.csv", show_col_types = FALSE)
d1_ids    <- readr::read_csv("data/raw/d1_team_ids.csv",      show_col_types = FALSE)
minutes   <- readr::read_csv("data/raw/game_minutes.csv",     show_col_types = FALSE)
conf_data <- readr::read_csv("data/raw/conference_data.csv",  show_col_types = FALSE)

raw_d1 <- raw |>
  dplyr::inner_join(d1_ids, by = c("season", "team_id")) |>
  dplyr::left_join(
    conf_data |> dplyr::select(season, team_id, conference, conference_short),
    by = c("season", "team_id")
  )

game_stats <- raw_d1 |>
  dplyr::mutate(
    poss = field_goals_attempted - offensive_rebounds +
      total_turnovers + 0.44 * free_throws_attempted
  ) |>
  dplyr::select(
    season, game_id, game_date, team_id, opponent_team_id,
    team_score, opponent_team_score, poss
  )

game_pairs_full <- game_stats |>
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
    minutes |> dplyr::select(game_id, game_minutes),
    by = "game_id"
  ) |>
  dplyr::filter(!is.na(game_minutes)) |>
  dplyr::mutate(
    game_poss = (poss + opp_poss) / 2,
    raw_ortg  = 100 * team_score  / game_poss,
    raw_drtg  = 100 * opponent_team_score / game_poss,
    raw_pace  = game_poss / game_minutes * 40
  )

game_pairs <- game_pairs |>
  dplyr::mutate(eff_poss = game_poss)

focus_season <- 2026

all_dates <- game_pairs_full |>
  dplyr::filter(season == focus_season) |>
  dplyr::pull(game_date) |>
  unique() |>
  sort()

cutoff_date <- max(all_dates) - 21

message("Holdout window: ", cutoff_date + 1, " through ", max(all_dates))
message("Training dates: ", sum(all_dates <= cutoff_date),
        " | Holdout dates: ", sum(all_dates > cutoff_date))

train_pairs   <- game_pairs_full |> dplyr::filter(season == focus_season, game_date <= cutoff_date)
holdout_pairs <- game_pairs_full |> dplyr::filter(season == focus_season, game_date >  cutoff_date)

message("Training games (rows): ",  nrow(train_pairs))
message("Holdout games (rows): ",   nrow(holdout_pairs))

train_pairs <- train_pairs |> dplyr::mutate(eff_poss = game_poss)

calculate_ratings <- function(game_pairs) {
  
  k_shrink      <- 100
  damping       <- 0.70
  tol           <- 0.005
  max_iter      <- 100
  stable_needed <- 2
  
  scale_factor <- 100 / weighted.mean(game_pairs$raw_ortg, w = game_pairs$game_poss, na.rm = TRUE)
  
  game_pairs <- game_pairs |>
    dplyr::mutate(
      raw_ortg = raw_ortg * scale_factor,
      raw_drtg = raw_drtg * scale_factor
    )
  
  league_ortg <- weighted.mean(game_pairs$raw_ortg, w = game_pairs$eff_poss, na.rm = TRUE)
  league_drtg <- weighted.mean(game_pairs$raw_drtg, w = game_pairs$eff_poss, na.rm = TRUE)
  league_pace <- weighted.mean(game_pairs$raw_pace,  w = game_pairs$eff_poss, na.rm = TRUE)
  
  opp_map <- game_pairs |>
    dplyr::select(team_id, opponent_team_id, game_poss, eff_poss, raw_ortg, raw_drtg, raw_pace)
  
  team_ratings <- game_pairs |>
    dplyr::group_by(team_id) |>
    dplyr::summarise(
      adj_ortg   = weighted.mean(raw_ortg, w = eff_poss, na.rm = TRUE),
      adj_drtg   = weighted.mean(raw_drtg, w = eff_poss, na.rm = TRUE),
      adj_pace   = weighted.mean(raw_pace,  w = eff_poss, na.rm = TRUE),
      .groups    = "drop"
    )
  
  stable_count <- 0
  
  for (i in seq_len(max_iter)) {
    
    prev_ratings <- team_ratings |> dplyr::select(team_id, adj_ortg, adj_drtg)
    
    game_adj <- opp_map |>
      dplyr::left_join(
        team_ratings |> dplyr::select(
          opponent_team_id = team_id,
          opp_adj_ortg     = adj_ortg,
          opp_adj_drtg     = adj_drtg
        ),
        by = "opponent_team_id"
      ) |>
      dplyr::mutate(
        game_adj_ortg = raw_ortg - (opp_adj_drtg - league_drtg),
        game_adj_drtg = raw_drtg - (opp_adj_ortg - league_ortg)
      )
    
    proposed <- game_adj |>
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
    
    new_ratings <- team_ratings |>
      dplyr::inner_join(proposed, by = "team_id", suffix = c("_old", "_new")) |>
      dplyr::mutate(
        adj_ortg = damping * adj_ortg_new + (1 - damping) * adj_ortg_old,
        adj_drtg = damping * adj_drtg_new + (1 - damping) * adj_drtg_old
      ) |>
      dplyr::select(team_id, adj_ortg, adj_drtg, adj_pace, sum_eff_poss)
    
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
      dplyr::select(team_id, adj_ortg, adj_drtg, adj_pace)
    
    delta <- new_ratings |>
      dplyr::left_join(prev_ratings, by = "team_id", suffix = c("", "_prev")) |>
      dplyr::summarise(
        med_delta = median(abs(adj_ortg - adj_ortg_prev) +
                             abs(adj_drtg - adj_drtg_prev))
      ) |>
      dplyr::pull(med_delta)
    
    team_ratings <- new_ratings
    
    if (delta < tol) {
      stable_count <- stable_count + 1
      if (stable_count >= stable_needed) {
        message("  Efficiency converged at iteration ", i)
        break
      }
    } else {
      stable_count <- 0
    }
  }
  
  stable_count_p <- 0
  
  for (i in seq_len(max_iter)) {
    
    prev_pace <- team_ratings |> dplyr::select(team_id, adj_pace)
    
    game_pace_adj <- opp_map |>
      dplyr::left_join(
        team_ratings |> dplyr::select(opponent_team_id = team_id, opp_adj_pace = adj_pace),
        by = "opponent_team_id"
      ) |>
      dplyr::mutate(game_adj_pace = raw_pace - (opp_adj_pace - league_pace))
    
    proposed_pace <- game_pace_adj |>
      dplyr::group_by(team_id) |>
      dplyr::summarise(
        sum_eff_poss  = sum(eff_poss, na.rm = TRUE),
        sum_pace_poss = sum(game_adj_pace * eff_poss, na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::mutate(
        adj_pace = (sum_pace_poss + k_shrink * league_pace) / (sum_eff_poss + k_shrink)
      )
    
    new_pace <- team_ratings |>
      dplyr::inner_join(proposed_pace, by = "team_id", suffix = c("_old", "_new")) |>
      dplyr::mutate(
        adj_pace = damping * adj_pace_new + (1 - damping) * adj_pace_old
      ) |>
      dplyr::select(team_id, adj_ortg, adj_drtg, adj_pace, sum_eff_poss)
    
    mean_p <- weighted.mean(new_pace$adj_pace, w = new_pace$sum_eff_poss, na.rm = TRUE)
    
    new_pace <- new_pace |>
      dplyr::mutate(adj_pace = adj_pace - (mean_p - league_pace)) |>
      dplyr::select(team_id, adj_ortg, adj_drtg, adj_pace)
    
    delta_p <- new_pace |>
      dplyr::left_join(prev_pace, by = "team_id", suffix = c("", "_prev")) |>
      dplyr::summarise(med_delta = median(abs(adj_pace - adj_pace_prev))) |>
      dplyr::pull(med_delta)
    
    team_ratings <- new_pace
    
    if (delta_p < tol) {
      stable_count_p <- stable_count_p + 1
      if (stable_count_p >= stable_needed) {
        message("  Pace converged at iteration ", i)
        break
      }
    } else {
      stable_count_p <- 0
    }
  }
  
  team_ratings |>
    dplyr::mutate(
      adj_ortg = adj_ortg / scale_factor,
      adj_drtg = adj_drtg / scale_factor,
      net      = adj_ortg - adj_drtg
    ) |>
    dplyr::select(team_id, adj_ortg, adj_drtg, adj_pace, net)
}

message("\nBuilding ratings on training data (pre-cutoff)...")
train_ratings <- calculate_ratings(train_pairs)

holdout_scored <- holdout_pairs |>
  dplyr::left_join(
    train_ratings |> dplyr::select(team_id, team_net = net, team_pace = adj_pace),
    by = "team_id"
  ) |>
  dplyr::left_join(
    train_ratings |> dplyr::select(opponent_team_id = team_id, opp_net = net),
    by = "opponent_team_id"
  ) |>
  dplyr::filter(!is.na(team_net), !is.na(opp_net)) |>
  dplyr::mutate(
    pred_margin   = (team_net - opp_net) * raw_pace / 100,
    actual_margin = team_score - opponent_team_score,
    error         = actual_margin - pred_margin
  )

oos_metrics <- holdout_scored |>
  dplyr::summarise(
    n_games     = dplyr::n(),
    mae         = mean(abs(error)),
    rmse        = sqrt(mean(error^2)),
    correlation = cor(pred_margin, actual_margin),
    bias        = mean(error)
  )

message("\n========================================")
message("  OUT-OF-SAMPLE VALIDATION RESULTS")
message("  Cutoff: ", cutoff_date, " | Season: ", focus_season)
message("========================================")
message("  Holdout games:  ", oos_metrics$n_games)
message("  MAE:            ", round(oos_metrics$mae, 3),
        "   (baseline: 10.093)")
message("  RMSE:           ", round(oos_metrics$rmse, 3),
        "   (baseline: 12.783)")
message("  Correlation:    ", round(oos_metrics$correlation, 3),
        "   (baseline: 0.802)")
message("  Bias:           ", round(oos_metrics$bias, 3),
        "   (should be near 0)")
message("========================================")
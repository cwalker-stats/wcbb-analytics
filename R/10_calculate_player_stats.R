library(dplyr)
library(readr)
library(jsonlite)

message("Loading raw data...")

player_raw <- wehoop::load_wbb_player_box(seasons = 2017:2026)
d1_ids     <- readr::read_csv("data/raw/d1_team_ids.csv",      show_col_types = FALSE)
conf_data  <- readr::read_csv("data/raw/conference_data.csv",  show_col_types = FALSE)
team_box   <- readr::read_csv("data/raw/wbb_team_box_raw.csv", show_col_types = FALSE)

message("Rows loaded: ", nrow(player_raw))

player_d1 <- player_raw |>
  dplyr::filter(!did_not_play, !is.na(minutes), minutes > 0) |>
  dplyr::inner_join(
    d1_ids |> dplyr::select(season, team_id),
    by = c("season", "team_id")
  ) |>
  dplyr::left_join(
    conf_data |> dplyr::select(season, team_id, conference, conference_short),
    by = c("season", "team_id")
  )

message("D1 player-game rows: ", nrow(player_d1))

team_totals <- player_d1 |>
  dplyr::group_by(game_id, team_id) |>
  dplyr::summarise(
    team_mp  = sum(minutes,                        na.rm = TRUE),
    team_fgm = sum(field_goals_made,               na.rm = TRUE),
    team_fga = sum(field_goals_attempted,          na.rm = TRUE),
    team_3pm = sum(three_point_field_goals_made,   na.rm = TRUE),
    team_3pa = sum(three_point_field_goals_attempted, na.rm = TRUE),
    team_ftm = sum(free_throws_made,               na.rm = TRUE),
    team_fta = sum(free_throws_attempted,          na.rm = TRUE),
    team_orb = sum(offensive_rebounds,             na.rm = TRUE),
    team_drb = sum(defensive_rebounds,             na.rm = TRUE),
    team_ast = sum(assists,                        na.rm = TRUE),
    team_tov = sum(turnovers,                      na.rm = TRUE),
    team_pts = sum(points,                         na.rm = TRUE),
    team_stl = sum(steals,                         na.rm = TRUE),
    team_blk = sum(blocks,                         na.rm = TRUE),
    .groups  = "drop"
  )

opp_totals <- player_d1 |>
  dplyr::group_by(game_id, opponent_team_id = team_id) |>
  dplyr::summarise(
    opp_fga = sum(field_goals_attempted,             na.rm = TRUE),
    opp_3pa = sum(three_point_field_goals_attempted, na.rm = TRUE),
    opp_fta = sum(free_throws_attempted,             na.rm = TRUE),
    opp_orb = sum(offensive_rebounds,                na.rm = TRUE),
    opp_drb = sum(defensive_rebounds,                na.rm = TRUE),
    opp_tov = sum(turnovers,                         na.rm = TRUE),
    opp_pts = sum(points,                            na.rm = TRUE),
    .groups = "drop"
  )

team_poss_data <- team_box |>
  dplyr::inner_join(d1_ids, by = c("season", "team_id")) |>
  dplyr::mutate(
    game_poss = field_goals_attempted - offensive_rebounds +
      total_turnovers + 0.44 * free_throws_attempted
  ) |>
  dplyr::select(game_id, team_id, game_poss)

opp_poss_data <- team_box |>
  dplyr::inner_join(d1_ids, by = c("season", "team_id")) |>
  dplyr::mutate(
    opp_poss = field_goals_attempted - offensive_rebounds +
      total_turnovers + 0.44 * free_throws_attempted
  ) |>
  dplyr::select(game_id, opponent_team_id = team_id, opp_poss)

player_games <- player_d1 |>
  dplyr::left_join(team_totals,   by = c("game_id", "team_id")) |>
  dplyr::left_join(opp_totals,    by = c("game_id", "opponent_team_id")) |>
  dplyr::left_join(team_poss_data, by = c("game_id", "team_id")) |>
  dplyr::left_join(opp_poss_data,  by = c("game_id", "opponent_team_id"))

message("Computing per-game advanced stats...")

player_games <- player_games |>
  dplyr::mutate(
    two_point_made      = field_goals_made - three_point_field_goals_made,
    two_point_attempted = field_goals_attempted - three_point_field_goals_attempted,
    
    ts_denom = 2 * (field_goals_attempted + 0.44 * free_throws_attempted),
    ts_pct   = dplyr::if_else(ts_denom > 0, points / ts_denom, NA_real_),
    
    efg_pct = dplyr::if_else(
      field_goals_attempted > 0,
      (field_goals_made + 0.5 * three_point_field_goals_made) / field_goals_attempted,
      NA_real_
    ),
    
    fg2_pct = dplyr::if_else(
      two_point_attempted > 0,
      two_point_made / two_point_attempted,
      NA_real_
    ),
    
    fg3_pct = dplyr::if_else(
      three_point_field_goals_attempted > 0,
      three_point_field_goals_made / three_point_field_goals_attempted,
      NA_real_
    ),
    
    ft_pct = dplyr::if_else(
      free_throws_attempted > 0,
      free_throws_made / free_throws_attempted,
      NA_real_
    ),
    
    ftr    = dplyr::if_else(field_goals_attempted > 0,
                            free_throws_attempted / field_goals_attempted, NA_real_),
    fg3a_r = dplyr::if_else(field_goals_attempted > 0,
                            three_point_field_goals_attempted / field_goals_attempted, NA_real_),
    fg3m_r = dplyr::if_else(field_goals_made > 0,
                            three_point_field_goals_made / field_goals_made, NA_real_),
    pps    = dplyr::if_else(field_goals_attempted > 0,
                            points / field_goals_attempted, NA_real_),
    
    poss_used = field_goals_attempted - offensive_rebounds +
      turnovers + 0.44 * free_throws_attempted,
    
    off_load = dplyr::if_else(
      !is.na(game_poss) & game_poss > 0,
      (poss_used + assists) / game_poss,
      NA_real_
    ),
    
    ast_pct = dplyr::if_else(
      team_mp > 0 & !is.na(team_fgm) &
        ((minutes / (team_mp / 5)) * team_fgm - field_goals_made) > 0,
      100 * assists / ((minutes / (team_mp / 5)) * team_fgm - field_goals_made),
      NA_real_
    ),
    ast_pct = dplyr::if_else(is.infinite(ast_pct) | is.nan(ast_pct), NA_real_, ast_pct),
    
    tov_pct = dplyr::if_else(
      poss_used > 0,
      100 * turnovers / poss_used,
      NA_real_
    ),
    
    ast_to = dplyr::if_else(turnovers > 0, assists / turnovers, NA_real_),
    
    to_economy = dplyr::if_else(
      (turnovers + assists) > 0,
      assists / (turnovers + assists),
      NA_real_
    ),
    
    net_play = dplyr::if_else(
      !is.na(ast_pct) & !is.na(tov_pct),
      ast_pct - tov_pct,
      NA_real_
    ),
    
    ppr = dplyr::if_else(
      turnovers > 0,
      (assists - turnovers) * (assists / turnovers),
      NA_real_
    ),
    
    orb_pct = dplyr::if_else(
      !is.na(opp_drb) & (team_orb + opp_drb) > 0 & minutes > 0 & team_mp > 0,
      pmin(100, 100 * (offensive_rebounds * (team_mp / 5)) /
             (minutes * (team_orb + opp_drb))),
      NA_real_
    ),
    
    drb_pct = dplyr::if_else(
      !is.na(opp_orb) & (team_drb + opp_orb) > 0 & minutes > 0 & team_mp > 0,
      pmin(100, 100 * (defensive_rebounds * (team_mp / 5)) /
             (minutes * (team_drb + opp_orb))),
      NA_real_
    ),
    
    trb_pct = dplyr::if_else(
      !is.na(opp_orb) & !is.na(opp_drb) & minutes > 0 & team_mp > 0 &
        (team_orb + team_drb + opp_orb + opp_drb) > 0,
      pmin(100, 100 * (rebounds * (team_mp / 5)) /
             (minutes * (team_orb + team_drb + opp_orb + opp_drb))),
      NA_real_
    ),
    
    stl_pct = dplyr::if_else(
      !is.na(opp_poss) & opp_poss > 0 & minutes > 0 & team_mp > 0,
      pmin(100, 100 * (steals * (team_mp / 5)) / (minutes * opp_poss)),
      NA_real_
    ),
    
    blk_pct = dplyr::if_else(
      !is.na(opp_fga) & !is.na(opp_3pa) & (opp_fga - opp_3pa) > 0 &
        minutes > 0 & team_mp > 0,
      pmin(100, 100 * (blocks * (team_mp / 5)) / (minutes * (opp_fga - opp_3pa))),
      NA_real_
    ),
    
    game_score = points + 0.4 * field_goals_made - 0.7 * field_goals_attempted -
      0.4 * (free_throws_attempted - free_throws_made) +
      0.7 * offensive_rebounds + 0.3 * defensive_rebounds +
      steals + 0.7 * assists + 0.7 * blocks - 0.4 * fouls - turnovers,
    
    versatility = dplyr::if_else(
      minutes > 0,
      (points + rebounds + assists) / sqrt(minutes),
      NA_real_
    ),
    
    team_ts = dplyr::if_else(
      !is.na(team_pts) & !is.na(team_fga) & !is.na(team_fta) &
        (team_fga + 0.44 * team_fta) > 0,
      team_pts / (2 * (team_fga + 0.44 * team_fta)),
      NA_real_
    ),
    rel_ts = dplyr::if_else(!is.na(ts_pct) & !is.na(team_ts), ts_pct - team_ts, NA_real_)
  )

message("Aggregating to season level...")

normalize_position <- function(pos) {
  dplyr::case_when(
    pos %in% c("G", "Guard", "Point Guard", "Shooting Guard", "PG", "SG") ~ "G",
    pos %in% c("F", "Forward", "Small Forward", "Power Forward", "SF", "PF") ~ "F",
    pos %in% c("C", "Center") ~ "C",
    pos %in% c("G/F", "F/G") ~ "G/F",
    pos %in% c("F/C", "C/F") ~ "F/C",
    is.na(pos) | pos == "" ~ "\u2014",
    TRUE ~ "G/F"
  )
}

player_season <- player_games |>
  dplyr::group_by(
    season, athlete_id, athlete_display_name, team_id, team_display_name,
    team_abbreviation, conference_short, athlete_headshot_href,
    athlete_position_abbreviation
  ) |>
  dplyr::summarise(
    gp            = dplyr::n(),
    gs            = sum(starter,                       na.rm = TRUE),
    total_min     = sum(minutes,                       na.rm = TRUE),
    total_pts     = sum(points,                        na.rm = TRUE),
    total_fgm     = sum(field_goals_made,              na.rm = TRUE),
    total_fga     = sum(field_goals_attempted,         na.rm = TRUE),
    total_3pm     = sum(three_point_field_goals_made,  na.rm = TRUE),
    total_3pa     = sum(three_point_field_goals_attempted, na.rm = TRUE),
    total_ftm     = sum(free_throws_made,              na.rm = TRUE),
    total_fta     = sum(free_throws_attempted,         na.rm = TRUE),
    total_orb     = sum(offensive_rebounds,            na.rm = TRUE),
    total_drb     = sum(defensive_rebounds,            na.rm = TRUE),
    total_reb     = sum(rebounds,                      na.rm = TRUE),
    total_ast     = sum(assists,                       na.rm = TRUE),
    total_stl     = sum(steals,                        na.rm = TRUE),
    total_blk     = sum(blocks,                        na.rm = TRUE),
    total_tov     = sum(turnovers,                     na.rm = TRUE),
    total_fouls   = sum(fouls,                         na.rm = TRUE),
    total_2pm     = sum(two_point_made,                na.rm = TRUE),
    total_2pa     = sum(two_point_attempted,           na.rm = TRUE),
    total_poss    = sum(poss_used,                     na.rm = TRUE),
    total_gs_raw  = sum(game_score,                    na.rm = TRUE),
    avg_ast_pct   = mean(ast_pct,    na.rm = TRUE),
    avg_orb_pct   = mean(orb_pct,    na.rm = TRUE),
    avg_drb_pct   = mean(drb_pct,    na.rm = TRUE),
    avg_trb_pct   = mean(trb_pct,    na.rm = TRUE),
    avg_stl_pct   = mean(stl_pct,    na.rm = TRUE),
    avg_blk_pct   = mean(blk_pct,    na.rm = TRUE),
    avg_to_econ   = mean(to_economy, na.rm = TRUE),
    avg_net_play  = mean(net_play,   na.rm = TRUE),
    avg_off_load  = mean(off_load,   na.rm = TRUE),
    avg_rel_ts    = mean(rel_ts,     na.rm = TRUE),
    avg_vers      = mean(versatility, na.rm = TRUE),
    avg_ppr       = mean(ppr,        na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    mpg = round(total_min / gp, 1),
    
    ts_pct  = round(dplyr::if_else(
      (total_fga + 0.44 * total_fta) > 0,
      total_pts / (2 * (total_fga + 0.44 * total_fta)), NA_real_), 3),
    
    efg_pct = round(dplyr::if_else(total_fga > 0,
                                   (total_fgm + 0.5 * total_3pm) / total_fga, NA_real_), 3),
    
    fg2_pct = round(dplyr::if_else(total_2pa > 0,
                                   total_2pm / total_2pa, NA_real_), 3),
    
    fg3_pct = round(dplyr::if_else(total_3pa > 0,
                                   total_3pm / total_3pa, NA_real_), 3),
    
    ft_pct  = round(dplyr::if_else(total_fta > 0,
                                   total_ftm / total_fta, NA_real_), 3),
    
    ftr     = round(dplyr::if_else(total_fga > 0,
                                   total_fta / total_fga, NA_real_), 3),
    
    fg3a_r  = round(dplyr::if_else(total_fga > 0,
                                   total_3pa / total_fga, NA_real_), 3),
    
    fg3m_r  = round(dplyr::if_else(total_fgm > 0,
                                   total_3pm / total_fgm, NA_real_), 3),
    
    pps     = round(dplyr::if_else(total_fga > 0,
                                   total_pts / total_fga, NA_real_), 3),
    
    tov_pct = round(dplyr::if_else(total_poss > 0,
                                   100 * total_tov / total_poss, NA_real_), 1),
    
    ast_to  = round(dplyr::if_else(total_tov > 0,
                                   total_ast / total_tov, NA_real_), 2),
    
    stocks_40    = round((total_stl + total_blk) / total_min * 40, 2),
    game_score_40 = round(total_gs_raw / total_min * 40, 2),
    
    ast_pct     = round(avg_ast_pct,  1),
    orb_pct     = round(avg_orb_pct,  1),
    drb_pct     = round(avg_drb_pct,  1),
    trb_pct     = round(avg_trb_pct,  1),
    stl_pct     = round(avg_stl_pct,  1),
    blk_pct     = round(avg_blk_pct,  1),
    to_economy  = round(avg_to_econ,  3),
    net_play    = round(avg_net_play, 1),
    off_load    = round(avg_off_load, 3),
    rel_ts      = round(avg_rel_ts,   3),
    versatility = round(avg_vers,     2),
    ppr         = round(avg_ppr,      2),
    
    season_games = dplyr::case_when(season <= 2020 ~ 30, TRUE ~ 32),
    
    position = normalize_position(athlete_position_abbreviation),
    headshot = dplyr::if_else(
      is.na(athlete_headshot_href) | athlete_headshot_href == "",
      "https://a.espncdn.com/i/headshots/nophoto.png",
      athlete_headshot_href
    ),
    
    qualified = mpg >= 10 & gp >= 10
  )

message("Computing BPM, Win Shares, and VORP...")

league_avgs <- player_season |>
  dplyr::group_by(season) |>
  dplyr::summarise(
    lg_ts = sum(total_pts, na.rm = TRUE) /
      (2 * (sum(total_fga, na.rm = TRUE) + 0.44 * sum(total_fta, na.rm = TRUE))),
    .groups = "drop"
  )

player_season <- player_season |>
  dplyr::left_join(league_avgs, by = "season") |>
  dplyr::mutate(
    pos_num = dplyr::case_when(
      position == "G"   ~ 1,
      position == "G/F" ~ 2,
      position == "F"   ~ 3,
      position == "F/C" ~ 4,
      position == "C"   ~ 5,
      TRUE              ~ 3
    ),
    
    raw_obpm =
      -2.1569 +
      0.0119  * (dplyr::if_else(!is.na(ts_pct), ts_pct - lg_ts, 0) * 100) +
      0.0519  * dplyr::if_else(!is.na(ast_pct), ast_pct, 0) +
      -0.0494 * dplyr::if_else(!is.na(tov_pct), tov_pct, 0) +
      0.0491  * dplyr::if_else(!is.na(orb_pct), orb_pct, 0) +
      0.0456  * dplyr::if_else(!is.na(drb_pct), drb_pct, 0) +
      0.1488  * dplyr::if_else(!is.na(stl_pct), stl_pct, 0) +
      0.0629  * dplyr::if_else(!is.na(blk_pct), blk_pct, 0) +
      -0.0650 * pos_num,
    
    raw_dbpm =
      -1.3 +
      0.1656 * dplyr::if_else(!is.na(stl_pct), stl_pct, 0) +
      0.1340 * dplyr::if_else(!is.na(blk_pct), blk_pct, 0) +
      0.0805 * dplyr::if_else(!is.na(drb_pct), drb_pct, 0) +
      -0.0150 * pos_num,
    
    bpm  = raw_obpm + raw_dbpm,
    obpm = raw_obpm,
    dbpm = raw_dbpm
  ) |>
  dplyr::select(-raw_obpm, -raw_dbpm, -lg_ts, -pos_num)

bpm_correction <- player_season |>
  dplyr::filter(!is.na(bpm)) |>
  dplyr::group_by(season) |>
  dplyr::summarise(
    season_bpm_mean = weighted.mean(bpm, w = total_min, na.rm = TRUE),
    .groups = "drop"
  )

player_season <- player_season |>
  dplyr::left_join(bpm_correction, by = "season") |>
  dplyr::mutate(
    bpm  = round(bpm  - season_bpm_mean, 1),
    obpm = round(obpm - season_bpm_mean / 2, 1),
    dbpm = round(dbpm - season_bpm_mean / 2, 1),
    vorp = round(
      (bpm - (-2.0)) * (total_min / (season_games * 40 / 5)) * (season_games / 82), 2),
    ows = round(
      (dplyr::if_else(!is.na(ts_pct) & (total_fga + 0.44 * total_fta) > 0,
                      total_pts / (2 * (total_fga + 0.44 * total_fta)), 0) - 0.44) *
        total_fga / 30, 2),
    dws = round(
      (total_stl + total_blk * 0.5 + total_drb * 0.25) / 40, 2),
    win_shares = round(ows + dws, 2)
  ) |>
  dplyr::select(
    -season_bpm_mean, -season_games,
    -avg_ast_pct, -avg_orb_pct, -avg_drb_pct, -avg_trb_pct,
    -avg_stl_pct, -avg_blk_pct, -avg_to_econ, -avg_net_play,
    -avg_off_load, -avg_rel_ts, -avg_vers, -avg_ppr,
    -athlete_position_abbreviation
  )

message("Writing outputs...")

readr::write_csv(player_season, "data/processed/player_stats.csv")
jsonlite::write_json(player_season, "output/json/player_stats.json", pretty = FALSE)

message("Done! Records: ", nrow(player_season))

player_season |>
  dplyr::filter(season == 2026, qualified) |>
  dplyr::arrange(desc(bpm)) |>
  dplyr::select(athlete_display_name, team_abbreviation, position,
                gp, mpg, bpm, obpm, dbpm, vorp, win_shares, ts_pct, ast_pct) |>
  dplyr::slice_head(n = 10) |>
  print()

player_season |>
  dplyr::filter(season == 2026, qualified) |>
  dplyr::summarise(
    mean_bpm      = round(weighted.mean(bpm, w = total_min, na.rm = TRUE), 3),
    mean_ts       = round(mean(ts_pct,  na.rm = TRUE), 3),
    max_drb       = round(max(drb_pct,  na.rm = TRUE), 1),
    max_orb       = round(max(orb_pct,  na.rm = TRUE), 1),
    max_stl       = round(max(stl_pct,  na.rm = TRUE), 1),
    max_blk       = round(max(blk_pct,  na.rm = TRUE), 1),
    n_players     = dplyr::n()
  ) |>
  print()
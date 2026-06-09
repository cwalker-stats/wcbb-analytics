"use client";

import { useState, useEffect } from "react";
import {
  TeamSeasonStats,
  getTeamStats,
  getSeasons,
  filterBySeason,
  rankTeams,
  getRankColor,
} from "../../lib/data";

export default function RatingsTable() {
  const [allData, setAllData] = useState<TeamSeasonStats[]>([]);
  const [seasons, setSeasons] = useState<number[]>([]);
  const [selectedSeason, setSelectedSeason] = useState<number>(2026);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getTeamStats()
      .then((data) => {
        setAllData(data);
        const availableSeasons = getSeasons(data);
        setSeasons(availableSeasons);
        setSelectedSeason(availableSeasons[0]);
        setLoading(false);
      })
      .catch(() => {
        setError("Failed to load data");
        setLoading(false);
      });
  }, []);

  if (loading) {
    return (
      <div style={{ color: "var(--text-secondary)", padding: "2rem" }}>
        Loading...
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ color: "var(--negative)", padding: "2rem" }}>{error}</div>
    );
  }

  const seasonData = filterBySeason(allData, selectedSeason);
  const ranked = rankTeams(seasonData, "points");
  const total = ranked.length;

  return (
    <div>
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: "1rem",
          marginBottom: "1.5rem",
        }}
      >
        <label
          style={{ color: "var(--text-secondary)", fontSize: "0.875rem" }}
        >
          Season
        </label>
        <select
          value={selectedSeason}
          onChange={(e) => setSelectedSeason(Number(e.target.value))}
          style={{
            backgroundColor: "var(--bg-card)",
            color: "var(--text-primary)",
            border: "1px solid var(--border)",
            borderRadius: "6px",
            padding: "0.4rem 0.75rem",
            fontSize: "0.875rem",
            cursor: "pointer",
          }}
        >
          {seasons.map((s) => (
            <option key={s} value={s}>
              {s - 1}–{String(s).slice(2)}
            </option>
          ))}
        </select>
        <span style={{ color: "var(--text-muted)", fontSize: "0.8rem" }}>
          {total} teams
        </span>
      </div>

      <div style={{ overflowX: "auto" }}>
        <table
          style={{
            width: "100%",
            borderCollapse: "collapse",
            fontSize: "0.875rem",
          }}
        >
          <thead>
            <tr
              style={{
                borderBottom: "1px solid var(--border)",
                color: "var(--text-muted)",
                fontSize: "0.75rem",
                textTransform: "uppercase",
                letterSpacing: "0.05em",
              }}
            >
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500" }}>Rk</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500" }}>Team</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500" }}>W</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500" }}>L</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500" }}>PTS</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500" }}>OPP PTS</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500" }}>DIFF</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500" }}>FG%</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500" }}>3P%</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500" }}>FT%</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500" }}>REB</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500" }}>AST</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500" }}>TOV</th>
            </tr>
          </thead>
          <tbody>
            {ranked.map((team, i) => {
              const diff = team.points - team.opp_points;
              return (
                <tr
                  key={`${team.team_id}-${team.season}`}
                  style={{
                    borderBottom: "1px solid var(--border)",
                    backgroundColor: i % 2 === 0 ? "transparent" : "rgba(255,255,255,0.015)",
                  }}
                >
                  <td
                    style={{
                      padding: "0.6rem 0.75rem",
                      color: "var(--text-muted)",
                      fontSize: "0.75rem",
                    }}
                  >
                    {team.rank}
                  </td>
                  <td style={{ padding: "0.6rem 0.75rem" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "0.6rem" }}>
                      <img
                        src={team.team_logo}
                        alt={team.team_display_name}
                        style={{ width: "24px", height: "24px", objectFit: "contain" }}
                      />
                      <span style={{ color: "var(--text-primary)", fontWeight: "500" }}>
                        {team.team_display_name}
                      </span>
                    </div>
                  </td>
                  <td style={{ padding: "0.6rem 0.75rem", textAlign: "center", color: "var(--text-secondary)" }}>
                    {team.wins}
                  </td>
                  <td style={{ padding: "0.6rem 0.75rem", textAlign: "center", color: "var(--text-secondary)" }}>
                    {team.losses}
                  </td>
                  <td
                    style={{
                      padding: "0.6rem 0.75rem",
                      textAlign: "center",
                      backgroundColor: getRankColor(team.rank, total),
                      color: "var(--text-primary)",
                      fontWeight: "500",
                    }}
                  >
                    {team.points.toFixed(1)}
                  </td>
                  <td style={{ padding: "0.6rem 0.75rem", textAlign: "center", color: "var(--text-secondary)" }}>
                    {team.opp_points.toFixed(1)}
                  </td>
                  <td
                    style={{
                      padding: "0.6rem 0.75rem",
                      textAlign: "center",
                      color: diff >= 0 ? "var(--positive)" : "var(--negative)",
                      fontWeight: "500",
                    }}
                  >
                    {diff >= 0 ? "+" : ""}{diff.toFixed(1)}
                  </td>
                  <td style={{ padding: "0.6rem 0.75rem", textAlign: "center", color: "var(--text-secondary)" }}>
                    {team.fg_pct.toFixed(1)}%
                  </td>
                  <td style={{ padding: "0.6rem 0.75rem", textAlign: "center", color: "var(--text-secondary)" }}>
                    {team.fg3_pct.toFixed(1)}%
                  </td>
                  <td style={{ padding: "0.6rem 0.75rem", textAlign: "center", color: "var(--text-secondary)" }}>
                    {team.ft_pct.toFixed(1)}%
                  </td>
                  <td style={{ padding: "0.6rem 0.75rem", textAlign: "center", color: "var(--text-secondary)" }}>
                    {team.tot_reb.toFixed(1)}
                  </td>
                  <td style={{ padding: "0.6rem 0.75rem", textAlign: "center", color: "var(--text-secondary)" }}>
                    {team.assists.toFixed(1)}
                  </td>
                  <td style={{ padding: "0.6rem 0.75rem", textAlign: "center", color: "var(--text-secondary)" }}>
                    {team.turnovers.toFixed(1)}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
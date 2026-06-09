"use client";

import { useState, useEffect } from "react";
import {
  TeamRating,
  getTeamRatings,
  getSeasons,
  filterBySeason,
  getRankColor,
  formatSeason,
} from "../../lib/data";

type RankedTeam = TeamRating & { rank: number };

function rankBy(
  data: TeamRating[],
  column: keyof TeamRating,
  ascending: boolean = false
): RankedTeam[] {
  const sorted = [...data].sort((a, b) => {
    const aVal = a[column] as number;
    const bVal = b[column] as number;
    return ascending ? aVal - bVal : bVal - aVal;
  });
  return sorted.map((team, index) => ({ ...team, rank: index + 1 }));
}

type ColumnDef = {
  key: keyof TeamRating;
  label: string;
  ascending: boolean;
  decimals: number;
  showPlus: boolean;
};

const COLUMNS: ColumnDef[] = [
  { key: "net", label: "AdjEM", ascending: false, decimals: 1, showPlus: true },
  { key: "ortg", label: "AdjO", ascending: false, decimals: 1, showPlus: false },
  { key: "drtg", label: "AdjD", ascending: true, decimals: 1, showPlus: false },
  { key: "sos", label: "SOS", ascending: false, decimals: 2, showPlus: true },
  { key: "osos", label: "OSOS", ascending: false, decimals: 2, showPlus: true },
  { key: "dsos", label: "DSOS", ascending: false, decimals: 2, showPlus: true },
  { key: "pace", label: "AdjT", ascending: false, decimals: 1, showPlus: false },
];

export default function RatingsTable() {
  const [allData, setAllData] = useState<TeamRating[]>([]);
  const [seasons, setSeasons] = useState<number[]>([]);
  const [selectedSeason, setSelectedSeason] = useState<number>(2026);
  const [sortCol, setSortCol] = useState<keyof TeamRating>("net");
  const [sortAsc, setSortAsc] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getTeamRatings()
      .then((data) => {
        setAllData(data);
        const availableSeasons = getSeasons(data);
        setSeasons(availableSeasons);
        setSelectedSeason(availableSeasons[0]);
        setLoading(false);
      })
      .catch(() => {
        setError("Failed to load ratings data");
        setLoading(false);
      });
  }, []);

  if (loading) return <div style={{ color: "var(--text-secondary)", padding: "2rem" }}>Loading...</div>;
  if (error) return <div style={{ color: "var(--negative)", padding: "2rem" }}>{error}</div>;

  const seasonData = filterBySeason(allData, selectedSeason);
  const ranked = rankBy(seasonData, sortCol, sortAsc);
  const total = ranked.length;

  const handleSort = (col: keyof TeamRating, defaultAsc: boolean) => {
    if (sortCol === col) {
      setSortAsc(!sortAsc);
    } else {
      setSortCol(col);
      setSortAsc(defaultAsc);
    }
  };

  const getColRank = (team: TeamRating, col: ColumnDef): number => {
    const sorted = [...seasonData].sort((a, b) => {
      const aVal = a[col.key] as number;
      const bVal = b[col.key] as number;
      return col.ascending ? aVal - bVal : bVal - aVal;
    });
    return sorted.findIndex((t) => t.team_id === team.team_id) + 1;
  };

  return (
    <div>
      <div style={{ display: "flex", alignItems: "center", gap: "1rem", marginBottom: "1.5rem" }}>
        <label style={{ color: "var(--text-secondary)", fontSize: "0.875rem" }}>Season</label>
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
            <option key={s} value={s}>{formatSeason(s)}</option>
          ))}
        </select>
        <span style={{ color: "var(--text-muted)", fontSize: "0.8rem" }}>{total} teams</span>
      </div>

      <div style={{ overflowX: "auto" }}>
        <table style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
          <thead>
            <tr style={{
              borderBottom: "1px solid var(--border)",
              color: "var(--text-muted)",
              fontSize: "0.75rem",
              textTransform: "none",
              letterSpacing: "0.05em",
            }}>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500" }}>Rk</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500" }}>Team</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500" }}>W-L</th>
              {COLUMNS.map((col) => (
                <th
                  key={col.key}
                  onClick={() => handleSort(col.key, col.ascending)}
                  style={{
                    padding: "0.6rem 0.75rem",
                    textAlign: "center",
                    fontWeight: "500",
                    cursor: "pointer",
                    color: sortCol === col.key ? "var(--accent-bright)" : "var(--text-muted)",
                    userSelect: "none",
                    whiteSpace: "nowrap",
                  }}
                >
                  {col.label} {sortCol === col.key ? (sortAsc ? "↑" : "↓") : ""}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {ranked.map((team, i) => (
              <tr
                key={`${team.team_id}-${team.season}`}
                style={{
                  borderBottom: "1px solid var(--border)",
                  backgroundColor: i % 2 === 0 ? "transparent" : "rgba(255,255,255,0.015)",
                }}
              >
                <td style={{ padding: "0.6rem 0.75rem", color: "var(--text-muted)", fontSize: "0.75rem" }}>
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
                  {team.wins}-{team.losses}
                </td>
                {COLUMNS.map((col) => {
                  const val = team[col.key] as number;
                  const colRank = getColRank(team, col);
                  const bg = getRankColor(colRank, total);
                  const formatted = col.showPlus && val > 0
                    ? `+${val.toFixed(col.decimals)}`
                    : val.toFixed(col.decimals);
                  return (
                    <td
                      key={col.key}
                      style={{
                        padding: "0.6rem 0.75rem",
                        textAlign: "center",
                        backgroundColor: bg,
                        color: "var(--text-primary)",
                        fontWeight: sortCol === col.key ? "600" : "400",
                      }}
                    >
                      <div style={{ fontSize: "0.875rem" }}>{formatted}</div>
                      <div style={{ fontSize: "0.65rem", color: "var(--text-muted)", marginTop: "1px" }}>
                        {colRank}
                      </div>
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
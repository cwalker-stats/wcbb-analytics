"use client";

import { useState, useEffect, useRef } from "react";
import React from "react";
import ReactDOM from "react-dom";
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
  tooltip: string;
};

const ADJ_COLUMNS: ColumnDef[] = [
  { key: "net", label: "AdjEM", ascending: false, decimals: 1, showPlus: true, tooltip: "Adjusted scoring margin per 100 possessions." },
];

const QUALITY_COLUMNS: ColumnDef[] = [
  { key: "ortg", label: "AdjO", ascending: false, decimals: 1, showPlus: false, tooltip: "Adjusted points scored per 100 possessions." },
  { key: "drtg", label: "AdjD", ascending: true, decimals: 1, showPlus: false, tooltip: "Adjusted points allowed per 100 possessions." },
  { key: "pace", label: "AdjT", ascending: false, decimals: 1, showPlus: false, tooltip: "Adjusted possessions per 40 minutes." },
];

const CONTEXT_COLUMNS: ColumnDef[] = [
  { key: "luck", label: "Luck", ascending: false, decimals: 3, showPlus: true, tooltip: "Wins above expectation based on scoring efficiency." },
  { key: "sos", label: "SOS", ascending: false, decimals: 2, showPlus: true, tooltip: "Strength of schedule relative to average (pts/100)." },
  { key: "osos", label: "OSOS", ascending: false, decimals: 2, showPlus: true, tooltip: "Opponent defensive strength relative to average (pts/100)." },
  { key: "dsos", label: "DSOS", ascending: false, decimals: 2, showPlus: true, tooltip: "Opponent offensive strength relative to average (pts/100)." },
];

const ALL_COLUMNS = [...ADJ_COLUMNS, ...QUALITY_COLUMNS, ...CONTEXT_COLUMNS];

type TooltipThProps = {
  col: ColumnDef;
  sortCol: keyof TeamRating;
  sortAsc: boolean;
  onSort: (key: keyof TeamRating, defaultAsc: boolean) => void;
};

function TooltipTh({ col, sortCol, sortAsc, onSort }: TooltipThProps) {
  const [tooltip, setTooltip] = useState<{ x: number; y: number } | null>(null);
  const thRef = useRef<HTMLTableCellElement>(null);

  const handleMouseEnter = () => {
    if (thRef.current) {
      const rect = thRef.current.getBoundingClientRect();
      setTooltip({ x: rect.left + rect.width / 2, y: rect.top - 8 });
    }
  };

  return (
    <>
      <th
        ref={thRef}
        onClick={() => { onSort(col.key, col.ascending); setTooltip(null); }}
        onMouseEnter={handleMouseEnter}
        onMouseLeave={() => setTooltip(null)}
        style={{
          padding: "0.6rem 0.75rem",
          textAlign: "center",
          fontWeight: "500",
          cursor: "pointer",
          color: sortCol === col.key ? "var(--accent-bright)" : "var(--text-muted)",
          userSelect: "none",
          whiteSpace: "nowrap",
          minWidth: "72px",
        }}
      >
        {col.label} {sortCol === col.key ? (sortAsc ? "↑" : "↓") : ""}
      </th>
      {tooltip && typeof document !== "undefined" &&
        ReactDOM.createPortal(
          <div style={{
            position: "fixed",
            left: tooltip.x,
            top: tooltip.y,
            transform: "translate(-50%, -100%)",
            backgroundColor: "#1a1d2e",
            color: "#f0f0f5",
            fontSize: "0.72rem",
            padding: "0.5rem 0.65rem",
            borderRadius: "6px",
            width: "auto",
            maxWidth: "320px",
            whiteSpace: "nowrap",
            zIndex: 9999,
            pointerEvents: "none",
            lineHeight: "1.4",
            boxShadow: "0 4px 12px rgba(0,0,0,0.2)",
            textAlign: "left",
            fontWeight: "400",
          }}>
            {col.tooltip}
          </div>,
          document.body
        )
      }
    </>
  );
}

export default function RatingsTable() {
  const [allData, setAllData] = useState<TeamRating[]>([]);
  const [seasons, setSeasons] = useState<number[]>([]);
  const [selectedSeason, setSelectedSeason] = useState<number>(2026);
  const [selectedConference, setSelectedConference] = useState<string>("All");
  const [sortCol, setSortCol] = useState<keyof TeamRating>("net");
  const [sortAsc, setSortAsc] = useState(false);
  const [search, setSearch] = useState("");
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

  useEffect(() => {
    setSelectedConference("All");
  }, [selectedSeason]);

  if (loading) return <div style={{ color: "var(--text-secondary)", padding: "2rem" }}>Loading...</div>;
  if (error) return <div style={{ color: "var(--negative)", padding: "2rem" }}>{error}</div>;

  const seasonData = filterBySeason(allData, selectedSeason);
  const seasonConferences = [...new Set(seasonData.map((d) => d.conference_short).filter(Boolean))].sort();

  const filteredData = seasonData.filter((t) =>
    selectedConference === "All" || t.conference_short === selectedConference
  );

  const allRanked = rankBy(filteredData, sortCol, sortAsc);
  const ranked = allRanked.filter((t) =>
    t.team_location.toLowerCase().includes(search.toLowerCase())
  );
  const total = seasonData.length;

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

  const selectStyle = {
    backgroundColor: "var(--bg-card)",
    color: "var(--text-primary)",
    border: "1px solid var(--border)",
    borderRadius: "6px",
    padding: "0.4rem 0.75rem",
    fontSize: "0.875rem",
    cursor: "pointer",
  };

  const headerStyle = {
    padding: "0.4rem 0.75rem",
    textAlign: "center" as const,
    fontSize: "0.7rem",
    fontWeight: "600",
    letterSpacing: "0.06em",
    color: "var(--text-muted)",
    borderBottom: "1px solid var(--border)",
  };

  return (
    <div>
      <div style={{ overflowX: "auto", marginBottom: "1.5rem" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "0.75rem", minWidth: "max-content" }}>
          <label style={{ color: "var(--text-secondary)", fontSize: "0.875rem" }}>Season</label>
          <select value={selectedSeason} onChange={(e) => setSelectedSeason(Number(e.target.value))} style={selectStyle}>
            {seasons.map((s) => (
              <option key={s} value={s}>{formatSeason(s)}</option>
            ))}
          </select>
          <label style={{ color: "var(--text-secondary)", fontSize: "0.875rem" }}>Conference</label>
          <select value={selectedConference} onChange={(e) => setSelectedConference(e.target.value)} style={selectStyle}>
            <option key="All" value="All">All</option>
            {seasonConferences.map((c) => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
          <span style={{ color: "var(--text-muted)", fontSize: "0.8rem", whiteSpace: "nowrap" }}>
            {ranked.length} of {seasonData.length} teams
          </span>
          <input
            type="text"
            placeholder="Search team..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{ ...selectStyle, outline: "none", width: "160px" }}
          />
        </div>
      </div>

      <div style={{ overflowX: "auto" }}>
        <table style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
          <thead>
            <tr>
              <th colSpan={5} style={{ padding: 0, border: "none", backgroundColor: "transparent" }} />
              <th colSpan={3} style={{ ...headerStyle, backgroundColor: "rgba(74,158,107,0.06)", borderRight: "2px solid var(--border)" }}>
                TEAM QUALITY
              </th>
              <th colSpan={4} style={{ ...headerStyle, backgroundColor: "rgba(100,120,180,0.06)" }}>
                CONTEXT & SCHEDULE
              </th>
            </tr>
            <tr style={{ borderBottom: "2px solid var(--border)", fontSize: "0.75rem", letterSpacing: "0.03em" }}>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500", color: "var(--text-muted)" }}>Rk</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500", color: "var(--text-muted)", width: "1%" }}>Team</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500", color: "var(--text-muted)" }}>Conf</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500", color: "var(--text-muted)" }}>W-L</th>
              {ADJ_COLUMNS.map((col) => (
                <TooltipTh key={col.key} col={col} sortCol={sortCol} sortAsc={sortAsc} onSort={handleSort} />
              ))}
              {QUALITY_COLUMNS.map((col) => (
                <TooltipTh key={col.key} col={col} sortCol={sortCol} sortAsc={sortAsc} onSort={handleSort} />
              ))}
              {CONTEXT_COLUMNS.map((col) => (
                <TooltipTh key={col.key} col={col} sortCol={sortCol} sortAsc={sortAsc} onSort={handleSort} />
              ))}
            </tr>
          </thead>
          <tbody>
            {ranked.map((team, i) => (
              <tr
                key={`${team.team_id}-${team.season}`}
                style={{
                  borderBottom: "1px solid var(--border)",
                  backgroundColor: i % 2 === 0 ? "transparent" : "var(--bg-card)",
                }}
              >
                <td style={{ padding: "0.6rem 0.75rem", color: "var(--text-muted)", fontSize: "0.75rem" }}>
                  {team.rank}
                </td>
                <td style={{ padding: "0.6rem 0.75rem" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "0.6rem", whiteSpace: "nowrap", minWidth: "200px" }}>
                    <img src={team.team_logo} alt={team.team_display_name} style={{ width: "24px", height: "24px", objectFit: "contain" }} />
                    <span style={{ color: "var(--text-primary)", fontWeight: "500", whiteSpace: "nowrap" }}>
                      {team.team_location}
                    </span>
                  </div>
                </td>
                <td style={{ padding: "0.6rem 0.75rem", color: "var(--text-muted)", fontSize: "0.75rem", whiteSpace: "nowrap" }}>
                  {team.conference_short}
                </td>
                <td style={{ padding: "0.6rem 0.75rem", textAlign: "center", color: "var(--text-secondary)" }}>
                  {team.wins}-{team.losses}
                </td>
                {ALL_COLUMNS.map((col, i) => {
                  const val = team[col.key] as number;
                  const colRank = getColRank(team, col);
                  const bg = getRankColor(colRank, total);
                  const isLastAdj = i === ADJ_COLUMNS.length - 1;
                  const isLastQuality = i === ADJ_COLUMNS.length + QUALITY_COLUMNS.length - 1;
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
                        borderRight: isLastAdj || isLastQuality ? "2px solid var(--border)" : undefined,
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
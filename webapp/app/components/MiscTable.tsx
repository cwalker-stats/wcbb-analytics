"use client";

import { useState, useEffect, useRef } from "react";
import React from "react";
import ReactDOM from "react-dom";
import { getSeasons, filterBySeason, getRankColor, formatSeason } from "../../lib/data";

type MiscStats = {
  season: number;
  team_id: number;
  team_display_name: string;
  team_abbreviation: string;
  team_location: string;
  team_name: string;
  team_logo: string;
  team_color: string;
  team_alternate_color: string;
  wins: number;
  losses: number;
  games: number;
  net: number;
  off_ast_pct: number;
  off_ato: number;
  off_ft_pct: number;
  off_stl_pct: number;
  off_blk_pct: number;
  def_ast_pct: number;
  def_ato: number;
  def_ft_pct: number;
  def_stl_pct: number;
  def_blk_pct: number;
  conference: string;
  conference_short: string;
};

type ColumnDef = {
  key: keyof MiscStats;
  label: string;
  ascending: boolean;
  tooltip: string;
  decimals: number;
};

const ADJ_COLUMNS: ColumnDef[] = [
  { key: "net", label: "AdjEM", ascending: false, tooltip: "Adjusted scoring margin per 100 possessions.", decimals: 1 },
];

const OFF_COLUMNS: ColumnDef[] = [
  { key: "off_ast_pct", label: "AST%", ascending: false, tooltip: "Share of field goals assisted.", decimals: 1 },
  { key: "off_ato", label: "A/TO", ascending: false, tooltip: "Assists per turnover.", decimals: 2 },
  { key: "off_ft_pct", label: "FT%", ascending: false, tooltip: "Free throws made per attempt.", decimals: 1 },
];

const DEF_COLUMNS: ColumnDef[] = [
  { key: "off_stl_pct", label: "STL%", ascending: false, tooltip: "Possessions ending in a steal.", decimals: 1 },
  { key: "off_blk_pct", label: "BLK%", ascending: false, tooltip: "Two-point field goal attempts blocked.", decimals: 1 },
  { key: "def_ast_pct", label: "AST%", ascending: true, tooltip: "Opponent share of field goals assisted.", decimals: 1 },
  { key: "def_ato", label: "A/TO", ascending: true, tooltip: "Opponent assists per turnover.", decimals: 2 },
  { key: "def_ft_pct", label: "FT%", ascending: true, tooltip: "Opponent free throws made per attempt.", decimals: 1 },
];

const ALL_COLUMNS = [...ADJ_COLUMNS, ...OFF_COLUMNS, ...DEF_COLUMNS];

async function getMiscStats(): Promise<MiscStats[]> {
  const res = await fetch("/data/misc.json");
  if (!res.ok) throw new Error("Failed to load misc data");
  return res.json();
}

type TooltipThProps = {
  col: ColumnDef;
  sortCol: keyof MiscStats;
  sortAsc: boolean;
  onSort: (key: keyof MiscStats, defaultAsc: boolean) => void;
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

export default function MiscTable() {
  const [allData, setAllData] = useState<MiscStats[]>([]);
  const [seasons, setSeasons] = useState<number[]>([]);
  const [selectedSeason, setSelectedSeason] = useState<number>(2026);
  const [selectedConference, setSelectedConference] = useState<string>("All");
  const [sortCol, setSortCol] = useState<keyof MiscStats>("net");
  const [sortAsc, setSortAsc] = useState(false);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getMiscStats()
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

  const allRanked = [...filteredData].sort((a, b) => {
    const aVal = a[sortCol] as number;
    const bVal = b[sortCol] as number;
    return sortAsc ? aVal - bVal : bVal - aVal;
  }).map((team, index) => ({ ...team, rank: index + 1 }));

  const ranked = allRanked.filter((t) =>
    t.team_location.toLowerCase().includes(search.toLowerCase())
  );

  const total = seasonData.length;

  const handleSort = (col: keyof MiscStats, defaultAsc: boolean) => {
    if (sortCol === col) {
      setSortAsc(!sortAsc);
    } else {
      setSortCol(col);
      setSortAsc(defaultAsc);
    }
  };

  const getColRank = (team: MiscStats, col: ColumnDef): number => {
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
      <div style={{ display: "flex", alignItems: "center", gap: "1rem", marginBottom: "1.5rem", flexWrap: "wrap" }}>
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
        <span style={{ color: "var(--text-muted)", fontSize: "0.8rem" }}>{ranked.length} of {seasonData.length} teams</span>
        <input
          type="text"
          placeholder="Search team..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ ...selectStyle, outline: "none", width: "160px" }}
        />
      </div>

      <div style={{ overflowX: "auto" }}>
        <table style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
          <thead>
            <tr>
              <th colSpan={5} style={{ padding: 0, border: "none", backgroundColor: "transparent" }} />
              <th colSpan={3} style={{ ...headerStyle, backgroundColor: "rgba(74,158,107,0.06)", borderRight: "2px solid var(--border)" }}>
                OFF. MISC
              </th>
              <th colSpan={5} style={{ ...headerStyle, backgroundColor: "rgba(196,92,92,0.06)" }}>
                DEF. MISC
              </th>
            </tr>
            <tr style={{ borderBottom: "2px solid var(--border)", fontSize: "0.75rem" }}>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500", color: "var(--text-muted)" }}>Rk</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500", color: "var(--text-muted)", width: "1%" }}>Team</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500", color: "var(--text-muted)" }}>Conf</th>
              <th style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500", color: "var(--text-muted)" }}>W-L</th>
              {ALL_COLUMNS.map((col) => (
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
                {ALL_COLUMNS.map((col) => {
                  const val = team[col.key] as number;
                  const colRank = getColRank(team, col);
                  const bg = getRankColor(colRank, total);
                  const isLastAdj = col.key === "net";
                  const isLastOff = col.key === "off_ft_pct";
                  const formatted = col.key === "net" && val > 0
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
                        borderRight: isLastAdj || isLastOff ? "2px solid var(--border)" : undefined,
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
"use client";

import { useState, useRef, useEffect } from "react";
import React from "react";
import ReactDOM from "react-dom";
import {
    PlayerStat,
    getPlayerStats,
    getPlayerSeasons,
    filterPlayersBySeason,
    getPlayerRankColor,
} from "../../lib/playerData";
import { formatSeason } from "../../lib/data";

type ColumnDef = {
    key: keyof PlayerStat;
    label: string;
    ascending: boolean;
    decimals: number;
    showPlus?: boolean;
    tooltip: string;
    pct?: boolean;
};

const POSITIONS = ["All", "G", "G/F", "F", "F/C", "C"];
const PAGE_SIZES = [25, 50, 100];

const IMPACT_COLUMNS: ColumnDef[] = [
    { key: "bpm", label: "BPM", ascending: false, decimals: 1, showPlus: true, tooltip: "Estimated impact per 100 possessions above average." },
    { key: "obpm", label: "OBPM", ascending: false, decimals: 1, showPlus: true, tooltip: "Estimated offensive impact per 100 possessions." },
    { key: "dbpm", label: "DBPM", ascending: false, decimals: 1, showPlus: true, tooltip: "Estimated defensive impact per 100 possessions." },
    { key: "vorp", label: "VORP", ascending: false, decimals: 2, showPlus: true, tooltip: "Estimated value above a replacement-level player." },
];

const VALUE_COLUMNS: ColumnDef[] = [
    { key: "win_shares", label: "WS", ascending: false, decimals: 2, tooltip: "Estimated wins contributed." },
    { key: "ows", label: "OWS", ascending: false, decimals: 2, tooltip: "Estimated offensive wins contributed." },
    { key: "dws", label: "DWS", ascending: false, decimals: 2, tooltip: "Estimated defensive wins contributed." },
    { key: "game_score_40", label: "GmSc", ascending: false, decimals: 1, tooltip: "Overall box score production per 40 minutes." },
    { key: "versatility", label: "VI", ascending: false, decimals: 2, tooltip: "Contribution across multiple statistical categories." },
];

const ALL_COLUMNS = [...IMPACT_COLUMNS, ...VALUE_COLUMNS];
const MPG_COL: ColumnDef = { key: "mpg", label: "MPG", ascending: false, decimals: 1, tooltip: "Average minutes played per game." };

function TooltipTh({
    col, sortCol, sortAsc, onSort,
}: {
    col: ColumnDef;
    sortCol: keyof PlayerStat;
    sortAsc: boolean;
    onSort: (key: keyof PlayerStat, asc: boolean) => void;
}) {
    const [tip, setTip] = useState<{ x: number; y: number } | null>(null);
    const ref = useRef<HTMLTableCellElement>(null);
    return (
        <>
            <th
                ref={ref}
                onClick={() => { onSort(col.key, col.ascending); setTip(null); }}
                onMouseEnter={() => { if (ref.current) { const r = ref.current.getBoundingClientRect(); setTip({ x: r.left + r.width / 2, y: r.top - 8 }); } }}
                onMouseLeave={() => setTip(null)}
                style={{ padding: "0.6rem 0.75rem", textAlign: "center", fontWeight: "500", cursor: "pointer", color: sortCol === col.key ? "var(--accent-bright)" : "var(--text-muted)", userSelect: "none", whiteSpace: "nowrap", minWidth: "72px" }}
            >
                {col.label} {sortCol === col.key ? (sortAsc ? "↑" : "↓") : ""}
            </th>
            {tip && typeof document !== "undefined" && ReactDOM.createPortal(
                <div style={{ position: "fixed", left: tip.x, top: tip.y, transform: "translate(-50%, -100%)", backgroundColor: "#1a1d2e", color: "#f0f0f5", fontSize: "0.72rem", padding: "0.5rem 0.65rem", borderRadius: "6px", maxWidth: "320px", whiteSpace: "nowrap", zIndex: 9999, pointerEvents: "none", lineHeight: "1.4", boxShadow: "0 4px 12px rgba(0,0,0,0.2)", fontWeight: "400" }}>
                    {col.tooltip}
                </div>, document.body
            )}
        </>
    );
}

export default function PlayerAdvancedTable() {
    const [allData, setAllData] = useState<PlayerStat[]>([]);
    const [seasons, setSeasons] = useState<number[]>([]);
    const [selectedSeason, setSelectedSeason] = useState<number>(2026);
    const [selectedConf, setSelectedConf] = useState<string>("All");
    const [selectedTeam, setSelectedTeam] = useState<string>("All");
    const [selectedPos, setSelectedPos] = useState<string>("All");
    const [qualifiedOnly, setQualifiedOnly] = useState<boolean>(true);
    const [sortCol, setSortCol] = useState<keyof PlayerStat>("mpg");
    const [sortAsc, setSortAsc] = useState<boolean>(false);
    const [search, setSearch] = useState<string>("");
    const [loading, setLoading] = useState<boolean>(true);
    const [error, setError] = useState<string | null>(null);
    const [page, setPage] = useState<number>(1);
    const [pageSize, setPageSize] = useState<number>(25);

    useEffect(() => {
        getPlayerStats()
            .then((data: PlayerStat[]) => {
                setAllData(data);
                const s = getPlayerSeasons(data);
                setSeasons(s);
                setSelectedSeason(s[0]);
                setLoading(false);
            })
            .catch(() => { setError("Failed to load player data"); setLoading(false); });
    }, []);

    useEffect(() => { setSelectedConf("All"); setSelectedTeam("All"); setSelectedPos("All"); setPage(1); }, [selectedSeason]);
    useEffect(() => { setSelectedTeam("All"); setPage(1); }, [selectedConf]);
    useEffect(() => { setPage(1); }, [selectedTeam, selectedPos, qualifiedOnly, search, sortCol, sortAsc]);

    if (loading) return <div style={{ color: "var(--text-secondary)", padding: "2rem" }}>Loading...</div>;
    if (error) return <div style={{ color: "var(--negative)", padding: "2rem" }}>{error}</div>;

    const seasonData = filterPlayersBySeason(allData, selectedSeason);
    const confs = [...new Set(seasonData.map((d: PlayerStat) => d.conference_short).filter(Boolean))].sort();
    const confTeams = [...new Set(seasonData.filter((d: PlayerStat) => selectedConf === "All" || d.conference_short === selectedConf).map((d: PlayerStat) => d.team_location))].sort();

    const rankPool = seasonData.filter((p: PlayerStat) => {
        if (qualifiedOnly && !p.qualified) return false;
        return true;
    });

    const filtered = seasonData.filter((p: PlayerStat) => {
        if (qualifiedOnly && !p.qualified) return false;
        if (selectedConf !== "All" && p.conference_short !== selectedConf) return false;
        if (selectedTeam !== "All" && p.team_location !== selectedTeam) return false;
        if (selectedPos !== "All" && p.position !== selectedPos) return false;
        if (search && !p.athlete_display_name.toLowerCase().includes(search.toLowerCase())) return false;
        return true;
    });

    const sorted = [...filtered]
        .sort((a: PlayerStat, b: PlayerStat) => {
            const av = a[sortCol] as number;
            const bv = b[sortCol] as number;
            if (isNaN(av) && isNaN(bv)) return 0;
            if (isNaN(av)) return 1;
            if (isNaN(bv)) return -1;
            return sortAsc ? av - bv : bv - av;
        })
        .map((p: PlayerStat, i: number) => ({ ...p, rank: i + 1 }));

    const total = rankPool.length;
    const totalPages = Math.ceil(sorted.length / pageSize);
    const paginated = sorted.slice((page - 1) * pageSize, page * pageSize);

    const handleSort = (key: keyof PlayerStat, asc: boolean) => {
        if (sortCol === key) { setSortAsc(!sortAsc); } else { setSortCol(key); setSortAsc(asc); }
    };

    const getColRank = (player: PlayerStat, col: ColumnDef): number => {
        const pool = rankPool.filter((p: PlayerStat) => { const v = p[col.key] as number; return v !== null && v !== undefined && !isNaN(Number(v)); });
        const s = [...pool].sort((a: PlayerStat, b: PlayerStat) => { const av = a[col.key] as number; const bv = b[col.key] as number; return col.ascending ? av - bv : bv - av; });
        return s.findIndex((p: PlayerStat) => p.athlete_id === player.athlete_id && p.season === player.season) + 1;
    };

    const formatVal = (val: number, col: ColumnDef): string => {
        if (val === null || val === undefined || isNaN(val)) return "—";
        const base = col.pct ? (val * 100).toFixed(col.decimals) : val.toFixed(col.decimals);
        return col.showPlus && val > 0 ? `+${base}` : base;
    };

    const selectStyle: React.CSSProperties = { backgroundColor: "var(--bg-card)", color: "var(--text-primary)", border: "1px solid var(--border)", borderRadius: "6px", padding: "0.4rem 0.75rem", fontSize: "0.875rem", cursor: "pointer" };
    const headerStyle: React.CSSProperties = { padding: "0.4rem 0.75rem", textAlign: "center", fontSize: "0.7rem", fontWeight: "600", letterSpacing: "0.06em", color: "var(--text-muted)", borderBottom: "1px solid var(--border)" };

    return (
        <div>
            <div style={{ overflowX: "auto", marginBottom: "1.5rem" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "0.75rem", minWidth: "max-content" }}>
                    <label style={{ color: "var(--text-secondary)", fontSize: "0.875rem" }}>Season</label>
                    <select value={selectedSeason} onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setSelectedSeason(Number(e.target.value))} style={selectStyle}>
                        {seasons.map((s: number) => <option key={s} value={s}>{formatSeason(s)}</option>)}
                    </select>
                    <label style={{ color: "var(--text-secondary)", fontSize: "0.875rem" }}>Conference</label>
                    <select value={selectedConf} onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setSelectedConf(e.target.value)} style={selectStyle}>
                        <option value="All">All</option>
                        {confs.map((c: string) => <option key={c} value={c}>{c}</option>)}
                    </select>
                    <label style={{ color: "var(--text-secondary)", fontSize: "0.875rem" }}>Team</label>
                    <select value={selectedTeam} onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setSelectedTeam(e.target.value)} style={selectStyle}>
                        <option value="All">All</option>
                        {confTeams.map((t: string) => <option key={t} value={t}>{t}</option>)}
                    </select>
                    <label style={{ color: "var(--text-secondary)", fontSize: "0.875rem" }}>Position</label>
                    <select value={selectedPos} onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setSelectedPos(e.target.value)} style={selectStyle}>
                        {POSITIONS.map((p: string) => <option key={p} value={p}>{p}</option>)}
                    </select>
                    <label style={{ color: "var(--text-secondary)", fontSize: "0.875rem" }}>Per page</label>
                    <select value={pageSize} onChange={(e: React.ChangeEvent<HTMLSelectElement>) => { setPageSize(Number(e.target.value)); setPage(1); }} style={selectStyle}>
                        {PAGE_SIZES.map((s: number) => <option key={s} value={s}>{s}</option>)}
                    </select>
                    <span style={{ color: "var(--text-muted)", fontSize: "0.8rem", whiteSpace: "nowrap" }}>{sorted.length} of {seasonData.length} players</span>
                    <input type="text" placeholder="Search player..." value={search} onChange={(e: React.ChangeEvent<HTMLInputElement>) => setSearch(e.target.value)} style={{ ...selectStyle, outline: "none", width: "160px" }} />
                    <label style={{ display: "flex", alignItems: "center", gap: "0.4rem", color: "var(--text-secondary)", fontSize: "0.875rem", cursor: "pointer" }}>
                        <input type="checkbox" checked={qualifiedOnly} onChange={(e: React.ChangeEvent<HTMLInputElement>) => setQualifiedOnly(e.target.checked)} style={{ cursor: "pointer" }} />
                        Qualified only
                    </label>
                </div>
            </div>

            <div style={{ overflowX: "auto" }}>
                <table style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
                    <thead>
                        <tr>
                            <th colSpan={6} style={{ padding: 0, border: "none", backgroundColor: "transparent" }} />
                            <th colSpan={4} style={{ ...headerStyle, backgroundColor: "rgba(74,158,107,0.06)", borderRight: "2px solid var(--border)" }}>OVERALL IMPACT</th>
                            <th colSpan={5} style={{ ...headerStyle, backgroundColor: "rgba(100,120,180,0.06)" }}>VALUE</th>
                        </tr>
                        <tr style={{ borderBottom: "2px solid var(--border)", fontSize: "0.75rem", letterSpacing: "0.03em" }}>
                            <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500", color: "var(--text-muted)" }}>Rk</th>
                            <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500", color: "var(--text-muted)", width: "40px" }} />
                            <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500", color: "var(--text-muted)", minWidth: "160px" }}>Player</th>
                            <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500", color: "var(--text-muted)", minWidth: "200px" }}>Team</th>
                            <th style={{ padding: "0.6rem 0.75rem", textAlign: "left", fontWeight: "500", color: "var(--text-muted)" }}>Conf</th>
                            <TooltipTh col={MPG_COL} sortCol={sortCol} sortAsc={sortAsc} onSort={handleSort} />
                            {ALL_COLUMNS.map((col: ColumnDef) => (
                                <TooltipTh key={String(col.key)} col={col} sortCol={sortCol} sortAsc={sortAsc} onSort={handleSort} />
                            ))}
                        </tr>
                    </thead>
                    <tbody>
                        {paginated.map((player, i: number) => (
                            <tr key={`${player.athlete_id}-${player.season}`} style={{ borderBottom: "1px solid var(--border)", backgroundColor: i % 2 === 0 ? "transparent" : "var(--bg-card)" }}>
                                <td style={{ padding: "0.6rem 0.75rem", color: "var(--text-muted)", fontSize: "0.75rem" }}>{player.rank}</td>
                                <td style={{ padding: "0.4rem 0.5rem" }}>
                                    <img src={player.headshot} alt={player.athlete_display_name} style={{ width: "40px", height: "40px", borderRadius: "50%", objectFit: "cover", display: "block" }} onError={(e: React.SyntheticEvent<HTMLImageElement>) => { (e.target as HTMLImageElement).src = "https://a.espncdn.com/i/headshots/nophoto.png"; }} />
                                </td>
                                <td style={{ padding: "0.6rem 0.75rem", whiteSpace: "nowrap" }}>
                                    <span style={{ color: "var(--text-primary)", fontWeight: "500" }}>{player.athlete_display_name}</span>
                                    {player.position && player.position !== "—" && (
                                        <span style={{ color: "var(--text-muted)", fontWeight: "400", marginLeft: "0.4rem", fontSize: "0.8rem" }}>{player.position}</span>
                                    )}
                                </td>
                                <td style={{ padding: "0.6rem 0.75rem" }}>
                                    <div style={{ display: "flex", alignItems: "center", gap: "0.6rem", whiteSpace: "nowrap" }}>
                                        <img src={`https://a.espncdn.com/i/teamlogos/ncaa/500/${player.team_id}.png`} alt={player.team_location} style={{ width: "24px", height: "24px", objectFit: "contain", flexShrink: 0 }} onError={(e: React.SyntheticEvent<HTMLImageElement>) => { (e.target as HTMLImageElement).style.display = "none"; }} />
                                        <span style={{ color: "var(--text-primary)", fontWeight: "500" }}>{player.team_location}</span>
                                    </div>
                                </td>
                                <td style={{ padding: "0.6rem 0.75rem", color: "var(--text-muted)", fontSize: "0.75rem", whiteSpace: "nowrap" }}>{player.conference_short}</td>
                                {(() => {
                                    const mpgRank = getColRank(player, MPG_COL);
                                    const mpgBg = mpgRank > 0 ? getPlayerRankColor(mpgRank, total) : "transparent";
                                    return (
                                        <td style={{ padding: "0.6rem 0.75rem", textAlign: "center", backgroundColor: mpgBg, color: "var(--text-primary)", fontWeight: sortCol === "mpg" ? "600" : "400", borderRight: "2px solid var(--border)" }}>
                                            <div style={{ fontSize: "0.875rem" }}>{player.mpg.toFixed(1)}</div>
                                            {mpgRank > 0 && <div style={{ fontSize: "0.65rem", color: "var(--text-muted)", marginTop: "1px" }}>{mpgRank}</div>}
                                        </td>
                                    );
                                })()}
                                {ALL_COLUMNS.map((col: ColumnDef, ci: number) => {
                                    const val = player[col.key] as number;
                                    const rank = getColRank(player, col);
                                    const bg = rank > 0 ? getPlayerRankColor(rank, total) : "transparent";
                                    const display = formatVal(val, col);
                                    const isGroupBoundary = ci === IMPACT_COLUMNS.length - 1;
                                    return (
                                        <td key={String(col.key)} style={{ padding: "0.6rem 0.75rem", textAlign: "center", backgroundColor: bg, color: "var(--text-primary)", fontWeight: sortCol === col.key ? "600" : "400", borderRight: isGroupBoundary ? "2px solid var(--border)" : undefined }}>
                                            <div style={{ fontSize: "0.875rem" }}>{display}</div>
                                            {rank > 0 && <div style={{ fontSize: "0.65rem", color: "var(--text-muted)", marginTop: "1px" }}>{rank}</div>}
                                        </td>
                                    );
                                })}
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {totalPages > 1 && (
                <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: "0.5rem", marginTop: "1.5rem" }}>
                    <button onClick={() => setPage(1)} disabled={page === 1} style={{ padding: "0.35rem 0.65rem", backgroundColor: "var(--bg-card)", color: page === 1 ? "var(--text-muted)" : "var(--text-primary)", border: "1px solid var(--border)", borderRadius: "6px", cursor: page === 1 ? "default" : "pointer", fontSize: "0.8rem" }}>«</button>
                    <button onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page === 1} style={{ padding: "0.35rem 0.65rem", backgroundColor: "var(--bg-card)", color: page === 1 ? "var(--text-muted)" : "var(--text-primary)", border: "1px solid var(--border)", borderRadius: "6px", cursor: page === 1 ? "default" : "pointer", fontSize: "0.8rem" }}>‹</button>
                    <span style={{ color: "var(--text-muted)", fontSize: "0.8rem", padding: "0 0.25rem" }}>Page {page} of {totalPages}</span>
                    <button onClick={() => setPage((p) => Math.min(totalPages, p + 1))} disabled={page === totalPages} style={{ padding: "0.35rem 0.65rem", backgroundColor: "var(--bg-card)", color: page === totalPages ? "var(--text-muted)" : "var(--text-primary)", border: "1px solid var(--border)", borderRadius: "6px", cursor: page === totalPages ? "default" : "pointer", fontSize: "0.8rem" }}>›</button>
                    <button onClick={() => setPage(totalPages)} disabled={page === totalPages} style={{ padding: "0.35rem 0.65rem", backgroundColor: "var(--bg-card)", color: page === totalPages ? "var(--text-muted)" : "var(--text-primary)", border: "1px solid var(--border)", borderRadius: "6px", cursor: page === totalPages ? "default" : "pointer", fontSize: "0.8rem" }}>»</button>
                </div>
            )}
        </div>
    );
}
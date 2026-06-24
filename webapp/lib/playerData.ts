export type PlayerStat = {
    season: number;
    athlete_id: number;
    athlete_display_name: string;
    team_id: number;
    team_display_name: string;
    team_location: string;
    team_abbreviation: string;
    conference_short: string;
    headshot: string;
    position: string;
    gp: number;
    gs: number;
    mpg: number;
    qualified: boolean;
    ts_pct: number;
    efg_pct: number;
    fg2_pct: number;
    fg3_pct: number;
    ft_pct: number;
    ftr: number;
    fg3a_r: number;
    fg3m_r: number;
    pps: number;
    off_load: number;
    ast_pct: number;
    tov_pct: number;
    ast_to: number;
    net_play: number;
    to_economy: number;
    ppr: number;
    orb_pct: number;
    drb_pct: number;
    trb_pct: number;
    stl_pct: number;
    blk_pct: number;
    stocks_40: number;
    bpm: number;
    obpm: number;
    dbpm: number;
    vorp: number;
    win_shares: number;
    ows: number;
    dws: number;
    game_score_40: number;
    versatility: number;
};

let cachedPlayerData: PlayerStat[] | null = null;

export async function getPlayerStats(): Promise<PlayerStat[]> {
    if (cachedPlayerData) return cachedPlayerData;
    const res = await fetch("/data/player_stats.json");
    if (!res.ok) throw new Error("Failed to load player stats");
    cachedPlayerData = await res.json();
    return cachedPlayerData!;
}

export function getPlayerSeasons(data: PlayerStat[]): number[] {
    return [...new Set(data.map((d) => d.season))].sort((a, b) => b - a);
}

export function filterPlayersBySeason(data: PlayerStat[], season: number): PlayerStat[] {
    return data.filter((d) => d.season === season);
}

export function getPlayerRankColor(rank: number, total: number): string {
    const pct = rank / total;
    if (pct <= 0.1) return "rgba(74, 158, 107, 0.35)";
    if (pct <= 0.25) return "rgba(74, 158, 107, 0.2)";
    if (pct <= 0.4) return "rgba(74, 158, 107, 0.08)";
    if (pct >= 0.9) return "rgba(196, 92, 92, 0.35)";
    if (pct >= 0.75) return "rgba(196, 92, 92, 0.2)";
    if (pct >= 0.6) return "rgba(196, 92, 92, 0.08)";
    return "transparent";
}
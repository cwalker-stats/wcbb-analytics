export type TeamRating = {
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
  net: number;
  ortg: number;
  drtg: number;
  sos: number;
  osos: number;
  dsos: number;
  pace: number;
  games: number;
  conference: string;
  conference_short: string;
  luck: number;
};

export type TeamSeasonStats = {
  season: number;
  team_id: number;
  team_display_name: string;
  team_abbreviation: string;
  team_location: string;
  team_name: string;
  team_logo: string;
  team_color: string;
  team_alternate_color: string;
  games: number;
  wins: number;
  losses: number;
  points: number;
  opp_points: number;
  fgm: number;
  fga: number;
  fg_pct: number;
  fg3m: number;
  fg3a: number;
  fg3_pct: number;
  ftm: number;
  fta: number;
  ft_pct: number;
  off_reb: number;
  def_reb: number;
  tot_reb: number;
  assists: number;
  steals: number;
  blocks: number;
  turnovers: number;
  fouls: number;
  opp_fgm: number;
  opp_fga: number;
  opp_fg_pct: number;
  opp_fg3m: number;
  opp_fg3a: number;
  opp_fg3_pct: number;
  opp_ftm: number;
  opp_fta: number;
  opp_ft_pct: number;
  opp_tot_reb: number;
  opp_turnovers: number;
  conference: string;
  conference_short: string;
};

export async function getTeamRatings(): Promise<TeamRating[]> {
  const res = await fetch("/data/team_ratings.json");
  if (!res.ok) throw new Error("Failed to load team ratings");
  return res.json();
}

export async function getTeamStats(): Promise<TeamSeasonStats[]> {
  const res = await fetch("/data/team_season_stats.json");
  if (!res.ok) throw new Error("Failed to load team stats");
  return res.json();
}

export function getSeasons(data: { season: number }[]): number[] {
  const seasons = [...new Set(data.map((d) => d.season))];
  return seasons.sort((a, b) => b - a);
}

export function getConferences(data: { conference_short: string }[]): string[] {
  const confs = [...new Set(data.map((d) => d.conference_short).filter(Boolean))];
  return confs.sort();
}

export function filterBySeason<T extends { season: number }>(
  data: T[],
  season: number
): T[] {
  return data.filter((d) => d.season === season);
}

export function rankTeams<T extends Record<string, unknown>>(
  data: T[],
  column: keyof T,
  ascending: boolean = false
): (T & { rank: number })[] {
  const sorted = [...data].sort((a, b) => {
    const aVal = a[column] as number;
    const bVal = b[column] as number;
    return ascending ? aVal - bVal : bVal - aVal;
  });
  return sorted.map((team, index) => ({ ...team, rank: index + 1 }));
}

export function getRankColor(rank: number, total: number): string {
  const pct = rank / total;
  if (pct <= 0.1) return "rgba(74, 158, 107, 0.35)";
  if (pct <= 0.25) return "rgba(74, 158, 107, 0.2)";
  if (pct <= 0.4) return "rgba(74, 158, 107, 0.08)";
  if (pct >= 0.9) return "rgba(196, 92, 92, 0.35)";
  if (pct >= 0.75) return "rgba(196, 92, 92, 0.2)";
  if (pct >= 0.6) return "rgba(196, 92, 92, 0.08)";
  return "transparent";
}

export function formatSeason(season: number): string {
  return `${season - 1}–${String(season).slice(2)}`;
}
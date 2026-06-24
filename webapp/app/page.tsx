"use client";

import { useState } from "react";
import RatingsTable from "./components/RatingsTable";
import FourFactorsTable from "./components/FourFactorsTable";
import OffShootingTable from "./components/OffShootingTable";
import DefShootingTable from "./components/DefShootingTable";
import MiscTable from "./components/MiscTable";
import PlayerShootingTable from "./components/PlayerShootingTable";
import PlayerPlaymakingTable from "./components/PlayerPlaymakingTable";
import PlayerReboundingTable from "./components/PlayerReboundingTable";
import PlayerAdvancedTable from "./components/PlayerAdvancedTable";

const TOP_NAV = [
  { id: "team-stats", label: "Team Stats" },
  { id: "player-stats", label: "Player Stats" },
];

const SUB_NAV: Record<string, { id: string; label: string }[]> = {
  "team-stats": [
    { id: "ratings", label: "Ratings" },
    { id: "four-factors", label: "Four Factors" },
    { id: "off-shooting", label: "Off. Shooting" },
    { id: "def-shooting", label: "Def. Shooting" },
    { id: "misc", label: "Misc" },
  ],
  "player-stats": [
    { id: "p-shooting", label: "Shooting" },
    { id: "p-playmaking", label: "Playmaking" },
    { id: "p-rebounding", label: "Rebounding & Defense" },
    { id: "p-advanced", label: "Advanced" },
  ],
};

export default function Home() {
  const [activeTop, setActiveTop] = useState("team-stats");
  const [activeTab, setActiveTab] = useState("ratings");

  const subTabs = SUB_NAV[activeTop] ?? [];

  return (
    <div style={{ minHeight: "100vh", backgroundColor: "var(--bg-primary)" }}>
      <header
        style={{
          backgroundColor: "var(--bg-secondary)",
          borderBottom: "1px solid var(--border)",
          padding: "0 2rem",
        }}
      >
        <div
          style={{
            maxWidth: "1400px",
            margin: "0 auto",
            display: "flex",
            flexDirection: "column",
            gap: "0",
          }}
        >
          <div style={{ padding: "1.5rem 0 1rem" }}>
            <h1
              style={{
                fontSize: "1.5rem",
                fontWeight: "700",
                color: "var(--text-primary)",
                letterSpacing: "-0.02em",
              }}
            >
              WCBB Analytics
            </h1>
            <p
              style={{
                fontSize: "0.875rem",
                color: "var(--text-secondary)",
                marginTop: "0.25rem",
              }}
            >
              Women&apos;s College Basketball Analytics
            </p>
          </div>

          <nav style={{ display: "flex", gap: "0", overflowX: "auto" }}>
            {TOP_NAV.map((item) => (
              <button
                key={item.id}
                onClick={() => {
                  setActiveTop(item.id);
                  setActiveTab(SUB_NAV[item.id]?.[0]?.id ?? "");
                }}
                style={{
                  padding: "0.75rem 1.25rem",
                  fontSize: "0.875rem",
                  fontWeight: activeTop === item.id ? "600" : "400",
                  color: activeTop === item.id ? "var(--text-primary)" : "var(--text-secondary)",
                  backgroundColor: "transparent",
                  border: "none",
                  borderBottom: activeTop === item.id ? "2px solid var(--accent-bright)" : "2px solid transparent",
                  cursor: "pointer",
                  transition: "all 0.15s ease",
                  whiteSpace: "nowrap",
                }}
              >
                {item.label}
              </button>
            ))}
          </nav>

          {subTabs.length > 0 && (
            <nav style={{
              display: "flex",
              gap: "0",
              overflowX: "auto",
              borderTop: "1px solid var(--border)",
            }}>
              {subTabs.map((tab) => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  style={{
                    padding: "0.6rem 1.1rem",
                    fontSize: "0.8rem",
                    fontWeight: activeTab === tab.id ? "600" : "400",
                    color: activeTab === tab.id ? "var(--accent-bright)" : "var(--text-muted)",
                    backgroundColor: "transparent",
                    border: "none",
                    borderBottom: activeTab === tab.id ? "2px solid var(--accent-bright)" : "2px solid transparent",
                    cursor: "pointer",
                    transition: "all 0.15s ease",
                    whiteSpace: "nowrap",
                  }}
                >
                  {tab.label}
                </button>
              ))}
            </nav>
          )}
        </div>
      </header>

      <main
        style={{
          maxWidth: "1400px",
          margin: "0 auto",
          padding: "1rem",
        }}
      >
        {activeTab === "ratings" && <RatingsTable />}
        {activeTab === "four-factors" && <FourFactorsTable />}
        {activeTab === "off-shooting" && <OffShootingTable />}
        {activeTab === "def-shooting" && <DefShootingTable />}
        {activeTab === "misc" && <MiscTable />}
        {activeTab === "p-shooting" && <PlayerShootingTable />}
        {activeTab === "p-playmaking" && <PlayerPlaymakingTable />}
        {activeTab === "p-rebounding" && <PlayerReboundingTable />}
        {activeTab === "p-advanced" && <PlayerAdvancedTable />}
      </main>

      <footer style={{ borderTop: "1px solid var(--border)", padding: "1.5rem 2rem", textAlign: "center", fontSize: "0.75rem", color: "var(--text-muted)" }}>
        Built by cwalkerstats · Data via the <a href="https://github.com/sportsdataverse/wehoop" target="_blank" rel="noopener noreferrer" style={{ color: "var(--accent)", textDecoration: "none" }}>wehoop</a> R package
      </footer>
    </div>
  );
}
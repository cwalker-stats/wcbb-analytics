"use client";

import { useState } from "react";
import RatingsTable from "./components/RatingsTable";
import FourFactorsTable from "./components/FourFactorsTable";
import OffShootingTable from "./components/OffShootingTable";
import DefShootingTable from "./components/DefShootingTable";

const TABS = [
  { id: "ratings", label: "Ratings" },
  { id: "four-factors", label: "Four Factors" },
  { id: "off-shooting", label: "Off. Shooting" },
  { id: "def-shooting", label: "Def. Shooting" },
  { id: "misc", label: "Misc" },
];

export default function Home() {
  const [activeTab, setActiveTab] = useState("ratings");

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

          <nav style={{ display: "flex", gap: "0" }}>
            {TABS.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                style={{
                  padding: "0.75rem 1.25rem",
                  fontSize: "0.875rem",
                  fontWeight: activeTab === tab.id ? "600" : "400",
                  color:
                    activeTab === tab.id
                      ? "var(--text-primary)"
                      : "var(--text-secondary)",
                  backgroundColor: "transparent",
                  border: "none",
                  borderBottom:
                    activeTab === tab.id
                      ? "2px solid var(--accent-bright)"
                      : "2px solid transparent",
                  cursor: "pointer",
                  transition: "all 0.15s ease",
                  whiteSpace: "nowrap",
                }}
              >
                {tab.label}
              </button>
            ))}
          </nav>
        </div>
      </header>

      <main
        style={{
          maxWidth: "1400px",
          margin: "0 auto",
          padding: "2rem",
        }}
      >
        {activeTab === "ratings" && <RatingsTable />}
        {activeTab === "four-factors" && <FourFactorsTable />}
        {activeTab === "off-shooting" && <OffShootingTable />}
        {activeTab === "def-shooting" && <DefShootingTable />}

        {activeTab === "misc" && (
          <div>
            <h2
              style={{
                fontSize: "1.25rem",
                fontWeight: "600",
                color: "var(--text-primary)",
                marginBottom: "1rem",
              }}
            >
              Miscellaneous
            </h2>
            <p style={{ color: "var(--text-secondary)" }}>
              Miscellaneous statistics coming soon.
            </p>
          </div>
        )}
      </main>
    </div>
  );
}
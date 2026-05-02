// ── Library screen ──────────────────────────────────────────────────────

const LIB_TABS = [
  { id: "movies", label: "Movies",   icon: "movie" },
  { id: "shows",  label: "TV Shows", icon: "tv" },
  { id: "music",  label: "Music",    icon: "music" },
  { id: "photos", label: "Photos",   icon: "photo" },
];

const LibraryScreen = ({ activeTab = "movies" }) => {
  const movies = window.FluxData2.movies;
  const shows  = window.FluxData2.shows;
  const items  = activeTab === "shows" ? shows : movies;

  return (
    <div style={{ background: M.bg, height: "100%", display: "flex", flexDirection: "column" }}>
      <div style={{ padding: "12px 16px 6px" }}>
        <div style={{ fontSize: 26, fontWeight: 800, letterSpacing: -0.6, color: M.fg }}>Library</div>
        <div style={{ fontSize: 12.5, color: M.fgMuted, marginTop: 2 }}>
          atlas-server · 4 sources · 2.4 TB
        </div>
      </div>

      {/* Tabs */}
      <div style={{
        display: "flex", gap: 8, padding: "10px 16px 4px",
        overflowX: "auto", scrollbarWidth: "none",
      }}>
        {LIB_TABS.map(t => {
          const on = t.id === activeTab;
          return (
            <button key={t.id} style={{
              display: "inline-flex", alignItems: "center", gap: 6,
              padding: "8px 14px", borderRadius: 999, fontSize: 12.5, fontWeight: 600,
              border: on ? `1px solid ${M.accent}` : `1px solid ${M.border}`,
              background: on ? M.accentSoft : "transparent",
              color: on ? "#E9D5FF" : M.fgMuted,
              fontFamily: "inherit", cursor: "pointer", whiteSpace: "nowrap",
            }}>
              <Icon name={t.icon} size={14} stroke={on ? "#E9D5FF" : "#94A3B8"}/>
              {t.label}
            </button>
          );
        })}
      </div>

      {/* filter row */}
      <div style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "10px 16px",
      }}>
        <div style={{ display: "flex", gap: 6 }}>
          <MChip active>All</MChip>
          <MChip>4K HDR</MChip>
          <MChip>Recent</MChip>
        </div>
        <button style={{
          width: 36, height: 32, borderRadius: 8,
          background: "rgba(255,255,255,0.04)", border: `1px solid ${M.border}`,
          color: M.fgMuted, display: "flex", alignItems: "center", justifyContent: "center",
        }}><Icon name="grid" size={15}/></button>
      </div>

      {/* poster grid */}
      <div style={{ flex: 1, overflowY: "auto", padding: "4px 16px 24px" }}>
        <div style={{
          display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 10,
        }}>
          {items.map((it, i) => (
            <div key={i}>
              <Poster art={it.art} w="100%" h={170} qual={it.qual}/>
              <div style={{ marginTop: 7, fontSize: 12.5, fontWeight: 600, color: M.fg, lineHeight: 1.2 }}>{it.title}</div>
              <div style={{ marginTop: 1, fontSize: 11, color: M.fgMuted }}>
                {it.year || `${it.seasons} seasons`} · ★ {it.rating}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

window.LibraryScreen = LibraryScreen;

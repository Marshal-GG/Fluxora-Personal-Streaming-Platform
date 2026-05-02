// ── Search screen ───────────────────────────────────────────────────────

const SearchScreen = () => {
  const recents = ["Interstellar", "Dune", "Severance", "Daft Punk", "Andor"];
  const trending = ["The Batman", "Oppenheimer", "Breaking Bad", "Tenet", "Drive", "Succession"];
  const browse = [
    { label: "Movies", icon: "movie",  grad: "linear-gradient(135deg, #2a1a4a, #6a3aaa)" },
    { label: "TV Shows", icon: "tv",   grad: "linear-gradient(135deg, #0a1a3a, #4a8aea)" },
    { label: "Music", icon: "music",   grad: "linear-gradient(135deg, #c44a8a, #f4a4ca)" },
    { label: "4K HDR", icon: "diamond",grad: "linear-gradient(135deg, #1a3a5a, #6acac4)" },
    { label: "Recently Added", icon: "sparkle", grad: "linear-gradient(135deg, #2a160a, #f4c47a)" },
    { label: "Top Rated", icon: "crown", grad: "linear-gradient(135deg, #1a0a2a, #ec4899)" },
  ];
  return (
    <div style={{ background: M.bg, height: "100%", display: "flex", flexDirection: "column" }}>
      {/* search field */}
      <div style={{ padding: "12px 16px 6px" }}>
        <div style={{ fontSize: 26, fontWeight: 800, letterSpacing: -0.6, color: M.fg, marginBottom: 14 }}>Search</div>
        <div style={{
          display: "flex", alignItems: "center", gap: 10, height: 46,
          background: "rgba(255,255,255,0.05)", border: `1px solid ${M.border}`,
          borderRadius: 12, padding: "0 14px",
        }}>
          <Icon name="search" size={18} stroke="#94A3B8"/>
          <input placeholder="Movies, shows, music, people…" style={{
            flex: 1, background: "transparent", border: "none", outline: "none",
            color: M.fg, fontSize: 14, fontFamily: "inherit",
          }}/>
          <button style={{ background: "none", border: "none", color: M.accent, cursor: "pointer" }}>
            <Icon name="qr" size={18} stroke={M.accent}/>
          </button>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: "auto", padding: "8px 16px 24px" }}>
        {/* recents */}
        <div style={{ marginTop: 10 }}>
          <div style={{
            display: "flex", alignItems: "center", justifyContent: "space-between",
            marginBottom: 8,
          }}>
            <div style={{
              fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: M.fgDim, textTransform: "uppercase",
            }}>Recent searches</div>
            <button style={{ background: "none", border: "none", color: M.fgMuted, fontSize: 11, fontWeight: 600 }}>Clear</button>
          </div>
          {recents.map((r, i) => (
            <div key={i} style={{
              display: "flex", alignItems: "center", gap: 12, padding: "10px 0",
              borderBottom: i < recents.length - 1 ? `1px solid ${M.border}` : "none",
            }}>
              <Icon name="history2" size={16} stroke="#64748B"/>
              <div style={{ flex: 1, fontSize: 14, color: M.fg }}>{r}</div>
              <Icon name="arrowUp" size={14} stroke="#64748B" style={{ transform: "rotate(-45deg)" }}/>
            </div>
          ))}
        </div>

        {/* trending pills */}
        <div style={{ marginTop: 22 }}>
          <div style={{
            fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: M.fgDim,
            textTransform: "uppercase", marginBottom: 10,
          }}>Trending</div>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
            {trending.map(t => <MChip key={t}>{t}</MChip>)}
          </div>
        </div>

        {/* browse categories */}
        <div style={{ marginTop: 24 }}>
          <div style={{
            fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: M.fgDim,
            textTransform: "uppercase", marginBottom: 10,
          }}>Browse</div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
            {browse.map(b => (
              <div key={b.label} style={{
                position: "relative", height: 76, borderRadius: 12, overflow: "hidden",
                background: b.grad, padding: 14, display: "flex", alignItems: "flex-end",
                boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.06)",
              }}>
                <div style={{
                  position: "absolute", inset: 0,
                  background: "linear-gradient(135deg, transparent, rgba(0,0,0,0.35))",
                }}/>
                <div style={{ position: "absolute", top: 10, right: 10, opacity: 0.55 }}>
                  <Icon name={b.icon} size={26} stroke="#fff"/>
                </div>
                <div style={{ position: "relative", fontSize: 14, fontWeight: 700, color: "#fff" }}>
                  {b.label}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

window.SearchScreen = SearchScreen;

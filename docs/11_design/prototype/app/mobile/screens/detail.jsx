// ── Title detail screen (Interstellar-style) ────────────────────────────

const DetailScreen = () => {
  const m = {
    title: "Interstellar", year: 2014, runtime: "2h 49m", rating: 8.7,
    qual: "4K HDR · Dolby Atmos", dir: "Christopher Nolan",
    cast: "M. McConaughey, A. Hathaway, J. Chastain, M. Caine",
    genre: ["Sci-Fi", "Drama", "Adventure"],
    art: "linear-gradient(180deg, #050810 0%, #1a2b50 50%, #2a3a6a 100%)",
    plot: "When Earth's resources are running out, a team of explorers travels through a wormhole near Saturn in search of a new home for humanity. Cooper must choose between leaving his children to save the species — or staying and watching them die.",
  };
  const eps = [
    { num: "Episodes",  label: "Watch trailer · 2:32" },
    { num: "Bonus",     label: "Behind the scenes · 14:08" },
  ];
  const recs = window.FluxData2.movies.filter(x => x.title !== "Interstellar").slice(0, 6);

  return (
    <div style={{ background: M.bg, height: "100%", overflowY: "auto" }}>
      {/* hero */}
      <div style={{ position: "relative", height: 320 }}>
        <div style={{ position: "absolute", inset: 0, background: m.art }}/>
        <div style={{
          position: "absolute", inset: 0, opacity: 0.12,
          background: "repeating-linear-gradient(135deg, transparent 0 10px, rgba(255,255,255,0.06) 10px 11px)",
        }}/>
        <div style={{
          position: "absolute", left: 0, right: 0, bottom: 0, height: "70%",
          background: "linear-gradient(to top, #08061A 5%, rgba(8,6,26,0.55) 60%, transparent)",
        }}/>
        {/* top bar overlay */}
        <div style={{
          position: "absolute", top: 36, left: 0, right: 0, height: 50,
          display: "flex", alignItems: "center", justifyContent: "space-between",
          padding: "0 8px",
        }}>
          <button style={iconBtn}><Icon name="chevronL" size={20} stroke="#fff"/></button>
          <div style={{ display: "flex", gap: 4 }}>
            <button style={iconBtn}><Icon name="search" size={18} stroke="#fff"/></button>
            <button style={iconBtn}><Icon name="moreH" size={18} stroke="#fff"/></button>
          </div>
        </div>
        {/* title block */}
        <div style={{ position: "absolute", left: 16, right: 16, bottom: 18 }}>
          <div style={{
            fontSize: 36, fontWeight: 800, color: "#fff", letterSpacing: -0.8, lineHeight: 1,
          }}>{m.title}</div>
          <div style={{
            marginTop: 8, fontSize: 12, color: "rgba(255,255,255,0.75)",
            display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap",
          }}>
            <span>{m.year}</span><span>·</span>
            <span>{m.runtime}</span><span>·</span>
            <span style={{ color: "#22D3EE", fontWeight: 600 }}>★ {m.rating}</span>
          </div>
          <div style={{ marginTop: 6, fontSize: 11, color: "#E9D5FF", fontWeight: 600, letterSpacing: 0.4 }}>
            {m.qual}
          </div>
        </div>
      </div>

      {/* primary actions */}
      <div style={{ padding: "14px 16px 6px", display: "flex", gap: 8 }}>
        <button style={{
          flex: 1, height: 46, borderRadius: 12, border: "none",
          background: "linear-gradient(135deg, #8B5CF6, #A855F7)",
          color: "#fff", fontWeight: 700, fontSize: 14.5, fontFamily: "inherit",
          display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8,
          boxShadow: "0 8px 22px rgba(139,92,246,0.45)",
        }}>
          <Icon name="play" size={16} stroke="#fff"/> Play · 1h 12m left
        </button>
        <button style={ghostSquare}><Icon name="download" size={18}/></button>
      </div>

      {/* genre chips */}
      <div style={{ display: "flex", gap: 6, padding: "10px 16px 0", flexWrap: "wrap" }}>
        {m.genre.map(g => <MChip key={g}>{g}</MChip>)}
      </div>

      {/* plot */}
      <div style={{ padding: "16px 16px 8px" }}>
        <div style={{ fontSize: 14, color: "#CBD5E1", lineHeight: 1.55 }}>{m.plot}</div>
        <div style={{ marginTop: 12, fontSize: 12, color: M.fgMuted }}>
          <div><span style={{ color: M.fgDim }}>Directed by</span> <span style={{ color: M.fg }}>{m.dir}</span></div>
          <div style={{ marginTop: 4 }}>
            <span style={{ color: M.fgDim }}>Cast </span>
            <span style={{ color: M.fg }}>{m.cast}</span>
          </div>
        </div>
      </div>

      {/* secondary actions */}
      <div style={{
        margin: "12px 16px 0", padding: "12px 6px",
        borderTop: `1px solid ${M.border}`, borderBottom: `1px solid ${M.border}`,
        display: "flex", justifyContent: "space-around",
      }}>
        {[
          { icon: "plus", label: "My List" },
          { icon: "shieldCheck", label: "Rate" },
          { icon: "extLink", label: "Share" },
          { icon: "msg", label: "Trailer" },
        ].map(a => (
          <button key={a.label} style={{
            background: "none", border: "none", display: "flex", flexDirection: "column",
            alignItems: "center", gap: 4, color: M.fgMuted, cursor: "pointer", padding: "4px 8px",
          }}>
            <Icon name={a.icon} size={20} stroke="#94A3B8"/>
            <span style={{ fontSize: 11, fontWeight: 500 }}>{a.label}</span>
          </button>
        ))}
      </div>

      {/* more like this */}
      <div style={{ marginTop: 20, paddingBottom: 24 }}>
        <div style={{ padding: "0 16px 10px", fontSize: 14, fontWeight: 700, color: M.fg }}>
          More like this
        </div>
        <div style={{
          display: "flex", gap: 10, padding: "0 16px",
          overflowX: "auto", scrollbarWidth: "none",
        }}>
          {recs.map((it, i) => (
            <Poster key={i} art={it.art} title={it.title} year={it.year} qual={it.qual} w={110} h={158}/>
          ))}
        </div>
      </div>
    </div>
  );
};

const iconBtn = {
  width: 38, height: 38, borderRadius: 999,
  background: "rgba(0,0,0,0.45)", border: "1px solid rgba(255,255,255,0.1)",
  display: "flex", alignItems: "center", justifyContent: "center",
  backdropFilter: "blur(8px)", cursor: "pointer",
};
const ghostSquare = {
  width: 46, height: 46, borderRadius: 12,
  background: "rgba(255,255,255,0.04)", border: `1px solid ${M.border}`,
  color: M.fg, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer",
};

window.DetailScreen = DetailScreen;

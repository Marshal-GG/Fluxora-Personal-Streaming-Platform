// ── Home / Discover screen ──────────────────────────────────────────────

const PosterRail = ({ title, items, posterW = 118, posterH = 172 }) => (
  <div style={{ marginTop: 22 }}>
    <div style={{
      display: "flex", alignItems: "baseline", justifyContent: "space-between",
      padding: "0 16px", marginBottom: 10,
    }}>
      <div style={{ fontSize: 15, fontWeight: 700, color: M.fg, letterSpacing: -0.1 }}>{title}</div>
      <button style={{
        background: "none", border: "none", color: M.fgMuted, fontSize: 12,
        fontWeight: 600, cursor: "pointer", display: "flex", alignItems: "center", gap: 2,
      }}>See all <Icon name="chevron" size={12}/></button>
    </div>
    <div style={{
      display: "flex", gap: 10, padding: "0 16px",
      overflowX: "auto", scrollbarWidth: "none",
    }}>
      {items.map((it, i) => (
        <Poster key={i} art={it.art} img={it.img} title={it.title} year={it.year} qual={it.qual} w={posterW} h={posterH}/>
      ))}
    </div>
  </div>
);

const ContinueWatching = ({ items }) => (
  <div style={{ marginTop: 16 }}>
    <div style={{
      padding: "0 16px", marginBottom: 10,
      fontSize: 15, fontWeight: 700, color: M.fg, letterSpacing: -0.1,
    }}>Continue watching</div>
    <div style={{
      display: "flex", gap: 12, padding: "0 16px",
      overflowX: "auto", scrollbarWidth: "none",
    }}>
      {items.map((it, i) => (
        <div key={i} style={{ width: 220, flexShrink: 0 }}>
          <div style={{ position: "relative" }}>
            <Poster art={it.art} img={it.img} w={220} h={124} radius={10}/>
            <div style={{
              position: "absolute", inset: 0, display: "flex",
              alignItems: "center", justifyContent: "center",
            }}>
              <div style={{
                width: 44, height: 44, borderRadius: "50%",
                background: "rgba(0,0,0,0.55)", border: "1.5px solid rgba(255,255,255,0.85)",
                display: "flex", alignItems: "center", justifyContent: "center",
                backdropFilter: "blur(4px)",
              }}>
                <Icon name="play" size={18} stroke="#fff"/>
              </div>
            </div>
            {/* progress */}
            <div style={{
              position: "absolute", left: 0, right: 0, bottom: 0, height: 3,
              background: "rgba(0,0,0,0.5)", borderBottomLeftRadius: 10, borderBottomRightRadius: 10,
              overflow: "hidden",
            }}>
              <div style={{ width: `${it.progress}%`, height: "100%", background: M.accent }}/>
            </div>
          </div>
          <div style={{ marginTop: 8, fontSize: 13, fontWeight: 600, color: M.fg, lineHeight: 1.25 }}>{it.title}</div>
          <div style={{ marginTop: 2, fontSize: 11, color: M.fgMuted }}>{it.sub}</div>
        </div>
      ))}
    </div>
  </div>
);

const HomeHero = ({ item }) => (
  <div style={{ position: "relative", height: 360 }}>
    <div style={{
      position: "absolute", inset: 0,
      background: item.art,
    }}/>
    <div style={{
      position: "absolute", inset: 0, opacity: 0.18,
      background: "repeating-linear-gradient(135deg, transparent 0 12px, rgba(255,255,255,0.05) 12px 13px)",
    }}/>
    <div style={{
      position: "absolute", left: 0, right: 0, bottom: 0, height: "70%",
      background: "linear-gradient(to top, #08061A 8%, rgba(8,6,26,0.7) 50%, transparent)",
    }}/>
    <div style={{ position: "absolute", left: 16, right: 16, bottom: 22 }}>
      <div style={{
        fontSize: 11, fontWeight: 700, letterSpacing: 1.4, color: M.accent,
        textTransform: "uppercase", marginBottom: 8,
      }}>Featured · {item.tag}</div>
      <div style={{
        fontSize: 32, fontWeight: 800, color: "#fff", lineHeight: 1.05,
        letterSpacing: -0.6, marginBottom: 6,
      }}>{item.title}</div>
      <div style={{
        fontSize: 12, color: "rgba(255,255,255,0.7)", display: "flex",
        gap: 8, alignItems: "center", marginBottom: 14, flexWrap: "wrap",
      }}>
        <span style={{ color: "#22D3EE", fontWeight: 600 }}>★ {item.rating}</span>
        <span>·</span><span>{item.year}</span>
        <span>·</span><span>{item.runtime}</span>
        <span>·</span><span style={{ color: "#E9D5FF" }}>{item.qual}</span>
      </div>
      <div style={{ display: "flex", gap: 8 }}>
        <button style={{
          flex: 1, height: 42, borderRadius: 10, border: "none",
          background: "linear-gradient(135deg, #8B5CF6, #A855F7)",
          color: "#fff", fontWeight: 700, fontSize: 14, fontFamily: "inherit",
          display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8,
          boxShadow: "0 8px 22px rgba(139,92,246,0.45)",
        }}>
          <Icon name="play" size={15} stroke="#fff"/> Play
        </button>
        <button style={{
          width: 42, height: 42, borderRadius: 10,
          background: "rgba(255,255,255,0.10)", border: "1px solid rgba(255,255,255,0.15)",
          color: "#fff", display: "flex", alignItems: "center", justifyContent: "center",
        }}><Icon name="plus" size={18} stroke="#fff"/></button>
        <button style={{
          width: 42, height: 42, borderRadius: 10,
          background: "rgba(255,255,255,0.10)", border: "1px solid rgba(255,255,255,0.15)",
          color: "#fff", display: "flex", alignItems: "center", justifyContent: "center",
        }}><Icon name="info" size={18} stroke="#fff"/></button>
      </div>
    </div>
    {/* status bar bg */}
    <div style={{
      position: "absolute", top: 0, left: 0, right: 0, height: 70,
      background: "linear-gradient(to bottom, rgba(8,6,26,0.5), transparent)",
      pointerEvents: "none",
    }}/>
  </div>
);

const HomeScreen = () => {
  const movies = window.FluxData2.movies;
  const shows  = window.FluxData2.shows;
  const hero = {
    title: "Dune: Part Two", year: 2024, rating: 8.6, runtime: "2h 46m",
    qual: "4K HDR · Atmos", tag: "On Fluxora",
    art: "linear-gradient(160deg, #2a160a 0%, #6b3a18 35%, #f4c47a 100%)",
  };
  const cont = [
    { title: "Severance", sub: "S2 · E5 — 24m left", progress: 62, art: shows[2].art, img: shows[2].img },
    { title: "Interstellar", sub: "1h 12m left",     progress: 35, art: movies[1].art, img: movies[1].img },
    { title: "Andor",     sub: "S1 · E9 — 16m left", progress: 78, art: shows[3].art, img: shows[3].img },
  ];
  return (
    <div style={{ background: M.bg, height: "100%", overflowY: "auto" }}>
      <HomeHero item={hero}/>
      <ContinueWatching items={cont}/>
      <PosterRail title="Trending now"     items={movies.slice(0, 8)}/>
      <PosterRail title="New on Fluxora"   items={shows.slice(0, 8)}/>
      <PosterRail title="Because you watched Interstellar" items={movies.slice(2, 10)}/>
      <div style={{ height: 24 }}/>
    </div>
  );
};

window.HomeScreen = HomeScreen;
window.PosterRail = PosterRail;
window.ContinueWatching = ContinueWatching;

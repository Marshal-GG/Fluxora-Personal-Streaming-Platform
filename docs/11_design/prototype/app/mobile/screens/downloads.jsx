// ── Downloads / Offline screen ──────────────────────────────────────────

const DownloadsScreen = () => {
  const movies = window.FluxData2.movies;
  const shows  = window.FluxData2.shows;
  const completed = [
    { ...movies[1], size: "8.4 GB", expires: "in 28 days" },
    { ...shows[2],  size: "2.1 GB", episodes: "5 of 10 eps", expires: "in 12 days" },
    { ...movies[3], size: "11.2 GB", expires: "in 30 days" },
    { ...shows[3],  size: "4.6 GB", episodes: "all eps", expires: "—" },
  ];
  const inProgress = [
    { ...movies[0], pct: 64, size: "5.4 / 8.4 GB", speed: "12.4 MB/s" },
    { ...shows[5],  pct: 18, size: "0.8 / 4.5 GB", speed: "8.1 MB/s", episodes: "S1 E2" },
  ];

  return (
    <div style={{ background: M.bg, height: "100%", display: "flex", flexDirection: "column" }}>
      <div style={{ padding: "12px 16px 6px" }}>
        <div style={{ fontSize: 26, fontWeight: 800, letterSpacing: -0.6, color: M.fg }}>Downloads</div>
        <div style={{ fontSize: 12.5, color: M.fgMuted, marginTop: 2 }}>
          26.3 GB used · 64 GB available on device
        </div>
        <div style={{
          marginTop: 10, height: 6, borderRadius: 999, background: "rgba(255,255,255,0.06)",
          overflow: "hidden",
        }}>
          <div style={{
            width: "29%", height: "100%",
            background: "linear-gradient(90deg, #8B5CF6, #A855F7, #22D3EE)",
          }}/>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: "auto", padding: "12px 16px 24px" }}>
        {/* in progress */}
        <div style={{
          fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: M.fgDim,
          textTransform: "uppercase", margin: "8px 0 10px",
        }}>Downloading · {inProgress.length}</div>

        {inProgress.map((it, i) => (
          <div key={i} style={{
            display: "flex", gap: 12, padding: "12px",
            background: "rgba(168,85,247,0.06)", border: `1px solid ${M.accentSoft}`,
            borderRadius: 12, marginBottom: 8,
          }}>
            <Poster art={it.art} w={56} h={80} radius={8}/>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: M.fg }}>{it.title}</div>
              <div style={{ fontSize: 11, color: M.fgMuted, marginTop: 2 }}>
                {it.episodes ? `${it.episodes} · ${it.size}` : it.size} · {it.speed}
              </div>
              <div style={{ marginTop: 8, height: 4, background: "rgba(255,255,255,0.08)", borderRadius: 999, overflow: "hidden" }}>
                <div style={{ width: `${it.pct}%`, height: "100%", background: "linear-gradient(90deg, #8B5CF6, #A855F7)" }}/>
              </div>
              <div style={{ marginTop: 4, fontSize: 10.5, color: M.accent, fontWeight: 600 }}>{it.pct}%</div>
            </div>
            <button style={{
              width: 32, height: 32, borderRadius: 999,
              background: "rgba(255,255,255,0.06)", border: "none",
              color: M.fg, display: "flex", alignItems: "center", justifyContent: "center",
              alignSelf: "center",
            }}><Icon name="pause" size={14}/></button>
          </div>
        ))}

        {/* completed */}
        <div style={{
          fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: M.fgDim,
          textTransform: "uppercase", margin: "20px 0 10px",
        }}>Available offline · {completed.length}</div>

        {completed.map((it, i) => (
          <div key={i} style={{
            display: "flex", gap: 12, padding: "10px 0",
            borderBottom: i < completed.length - 1 ? `1px solid ${M.border}` : "none",
          }}>
            <Poster art={it.art} w={50} h={72} radius={8}/>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 13.5, fontWeight: 600, color: M.fg }}>{it.title}</div>
              <div style={{ fontSize: 11, color: M.fgMuted, marginTop: 3 }}>
                {it.episodes ? `${it.episodes} · ` : ""}{it.size} · {it.qual || it.qual || "1080p"}
              </div>
              <div style={{ fontSize: 11, color: M.fgDim, marginTop: 2 }}>Expires {it.expires}</div>
            </div>
            <button style={{
              width: 32, height: 32, borderRadius: 999,
              background: "rgba(255,255,255,0.04)", border: `1px solid ${M.border}`,
              color: M.fgMuted, display: "flex", alignItems: "center", justifyContent: "center",
              alignSelf: "center",
            }}><Icon name="moreH" size={15}/></button>
          </div>
        ))}
      </div>
    </div>
  );
};

window.DownloadsScreen = DownloadsScreen;

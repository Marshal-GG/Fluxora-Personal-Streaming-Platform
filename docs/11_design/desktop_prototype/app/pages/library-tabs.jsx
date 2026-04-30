// ── Library tab content (Movies / TV / Music / Docs / Photos) ──────────
const MoviesTab = () => (
  <div>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
      <div style={{ fontSize: 13.5, fontWeight: 600, color: "#F1F5F9" }}>Movies <span style={{ color: "#64748B", fontWeight: 500 }}>· {FluxData2.movies.length}</span></div>
      <div style={{ display: "flex", gap: 8 }}>
        <Button variant="secondary" size="sm" iconRight="chevronD">Sort: Recently Added</Button>
        <Button variant="secondary" size="sm" icon="layers">Filter</Button>
        <Button variant="primary" size="sm" icon="play">Shuffle</Button>
      </div>
    </div>
    <div style={{ display: "grid", gridTemplateColumns: "repeat(6, 1fr)", gap: 14 }}>
      {FluxData2.movies.map((m, i) => (
        <div key={i} style={{ cursor: "pointer" }}>
          <div style={{ aspectRatio: "2/3", borderRadius: 9, background: m.art, position: "relative", overflow: "hidden", border: "1px solid rgba(255,255,255,0.06)", boxShadow: "0 6px 20px rgba(0,0,0,0.3)" }}>
            <div style={{ position: "absolute", top: 6, right: 6, padding: "2px 6px", background: "rgba(0,0,0,0.6)", backdropFilter: "blur(6px)", borderRadius: 4, fontSize: 9, fontWeight: 700, color: "#E9D5FF", fontFamily: "JetBrains Mono" }}>{m.qual}</div>
            <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, padding: "20px 8px 8px", background: "linear-gradient(180deg, transparent, rgba(0,0,0,0.7))" }}>
              <div style={{ display: "flex", alignItems: "center", gap: 4, fontSize: 10, color: "#FBBF24", fontWeight: 600 }}>★ {m.rating}</div>
            </div>
          </div>
          <div style={{ marginTop: 7, fontSize: 12, fontWeight: 600, color: "#E2E8F0", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{m.title}</div>
          <div style={{ fontSize: 11, color: "#64748B", marginTop: 1 }}>{m.year} · {m.runtime}</div>
        </div>
      ))}
    </div>
  </div>
);

const TVTab = () => (
  <div>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
      <div style={{ fontSize: 13.5, fontWeight: 600, color: "#F1F5F9" }}>TV Shows <span style={{ color: "#64748B", fontWeight: 500 }}>· {FluxData2.shows.length}</span></div>
      <div style={{ display: "flex", gap: 8 }}>
        <Button variant="secondary" size="sm" iconRight="chevronD">Sort: A–Z</Button>
        <Button variant="secondary" size="sm" icon="layers">Filter</Button>
      </div>
    </div>
    <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 14 }}>
      {FluxData2.shows.map((s, i) => (
        <Card key={i} padding={0} hoverable>
          <div style={{ aspectRatio: "16/9", background: s.art, position: "relative", borderRadius: "12px 12px 0 0" }}>
            <div style={{ position: "absolute", top: 8, right: 8, padding: "3px 8px", background: "rgba(0,0,0,0.65)", backdropFilter: "blur(6px)", borderRadius: 4, fontSize: 10, fontWeight: 700, color: "#E9D5FF", fontFamily: "JetBrains Mono" }}>{s.qual}</div>
            <div style={{ position: "absolute", bottom: 8, left: 10, fontSize: 10.5, color: "#FBBF24", fontWeight: 600 }}>★ {s.rating}</div>
          </div>
          <div style={{ padding: 14 }}>
            <div style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9" }}>{s.title}</div>
            <div style={{ fontSize: 11.5, color: "#64748B", marginTop: 4, display: "flex", justifyContent: "space-between" }}>
              <span>{s.seasons} seasons · {s.episodes} eps</span>
              <span>Watched 24/{s.episodes}</span>
            </div>
            <div style={{ height: 3, background: "rgba(255,255,255,0.05)", borderRadius: 99, marginTop: 8, overflow: "hidden" }}>
              <div style={{ width: `${(24/s.episodes)*100}%`, height: "100%", background: "linear-gradient(90deg, #8B5CF6, #A855F7)" }}/>
            </div>
          </div>
        </Card>
      ))}
    </div>
  </div>
);

const MusicTab = () => (
  <div>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
      <div style={{ fontSize: 13.5, fontWeight: 600, color: "#F1F5F9" }}>Albums <span style={{ color: "#64748B", fontWeight: 500 }}>· {FluxData2.music.length}</span></div>
      <div style={{ display: "flex", gap: 8 }}>
        <Button variant="secondary" size="sm" iconRight="chevronD">View: Albums</Button>
        <Button variant="primary" size="sm" icon="play">Play All</Button>
      </div>
    </div>
    <div style={{ display: "grid", gridTemplateColumns: "repeat(5, 1fr)", gap: 14 }}>
      {FluxData2.music.map((a, i) => (
        <div key={i}>
          <div style={{ aspectRatio: "1/1", borderRadius: 8, background: a.art, position: "relative", overflow: "hidden", boxShadow: "0 6px 20px rgba(0,0,0,0.3)" }}>
            <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "flex-end", padding: 10, background: "linear-gradient(180deg, transparent 60%, rgba(0,0,0,0.5))" }}>
              <div style={{ width: 32, height: 32, borderRadius: "50%", background: "#A855F7", display: "flex", alignItems: "center", justifyContent: "center", marginLeft: "auto" }}>
                <Icon name="play" size={12} stroke="#fff" fill="#fff"/>
              </div>
            </div>
          </div>
          <div style={{ marginTop: 8, fontSize: 12.5, fontWeight: 600, color: "#E2E8F0", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{a.title}</div>
          <div style={{ fontSize: 11, color: "#64748B", marginTop: 2 }}>{a.artist} · {a.year}</div>
        </div>
      ))}
    </div>
  </div>
);

const DocsTab = () => (
  <Card padding={0}>
    <div style={{ padding: "14px 20px", borderBottom: "1px solid rgba(255,255,255,0.05)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
      <div style={{ fontSize: 13.5, fontWeight: 600, color: "#F1F5F9" }}>Documents <span style={{ color: "#64748B", fontWeight: 500 }}>· {FluxData2.docs.length}</span></div>
      <Button variant="primary" size="sm" icon="plus">Upload</Button>
    </div>
    <div style={{ display: "grid", gridTemplateColumns: "2.5fr 1fr 0.8fr 1.2fr 0.6fr", gap: 12, padding: "10px 20px", fontSize: 11, fontWeight: 600, color: "#94A3B8", borderBottom: "1px solid rgba(255,255,255,0.03)" }}>
      <div>Name</div><div>Size</div><div>Type</div><div>Modified</div><div style={{ textAlign: "right" }}>Actions</div>
    </div>
    {FluxData2.docs.map((d, i) => {
      const colors = { PDF: "#F87171", XLSX: "#10B981", ZIP: "#F59E0B", MD: "#94A3B8", DOCX: "#3B82F6" };
      const c = colors[d.type] || "#94A3B8";
      return (
        <div key={i} style={{ display: "grid", gridTemplateColumns: "2.5fr 1fr 0.8fr 1.2fr 0.6fr", gap: 12, padding: "11px 20px", alignItems: "center", borderTop: "1px solid rgba(255,255,255,0.03)", fontSize: 12.5 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div style={{ width: 26, height: 26, borderRadius: 5, background: `${c}1c`, border: `1px solid ${c}3c`, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 9, fontWeight: 800, color: c, fontFamily: "JetBrains Mono" }}>{d.type}</div>
            <span style={{ color: "#E2E8F0" }}>{d.name}</span>
          </div>
          <span style={{ color: "#94A3B8" }}>{d.size}</span>
          <span style={{ color: c, fontFamily: "JetBrains Mono", fontWeight: 600 }}>{d.type}</span>
          <span style={{ color: "#94A3B8", fontSize: 11.5 }}>{d.modified}</span>
          <div style={{ display: "flex", gap: 4, justifyContent: "flex-end" }}>
            <button style={{ ...iconBtnSub }}><Icon name="eye" size={12} stroke="#94A3B8"/></button>
            <button style={{ ...iconBtnSub }}><Icon name="download" size={12} stroke="#94A3B8"/></button>
          </div>
        </div>
      );
    })}
  </Card>
);

const PhotosTab = () => (
  <div>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
      <div style={{ fontSize: 13.5, fontWeight: 600, color: "#F1F5F9" }}>Photos <span style={{ color: "#64748B", fontWeight: 500 }}>· 2,847 items</span></div>
      <div style={{ display: "flex", gap: 8 }}>
        <Button variant="secondary" size="sm" iconRight="chevronD">View: Grid</Button>
        <Button variant="primary" size="sm" icon="plus">Upload</Button>
      </div>
    </div>
    <div style={{ fontSize: 12, color: "#94A3B8", marginBottom: 12, fontWeight: 500 }}>May 2025</div>
    <div style={{ display: "grid", gridTemplateColumns: "repeat(6, 1fr)", gap: 6 }}>
      {FluxData2.photos.map((p, i) => (
        <div key={i} style={{ aspectRatio: "1/1", background: p.grad, borderRadius: 6, position: "relative", cursor: "pointer", boxShadow: "0 2px 8px rgba(0,0,0,0.2)" }}>
          {i === 0 && <div style={{ position: "absolute", top: 6, right: 6, width: 18, height: 18, borderRadius: "50%", background: "rgba(0,0,0,0.5)", backdropFilter: "blur(4px)", display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="play" size={8} stroke="#fff" fill="#fff"/></div>}
        </div>
      ))}
    </div>
  </div>
);

window.MoviesTab = MoviesTab;
window.TVTab = TVTab;
window.MusicTab = MusicTab;
window.DocsTab = DocsTab;
window.PhotosTab = PhotosTab;

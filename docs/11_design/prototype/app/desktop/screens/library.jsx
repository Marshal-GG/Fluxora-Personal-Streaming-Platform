// ── Library ────────────────────────────────────────────────────────────
const LibraryScreen = () => {
  const [tab, setTab] = React.useState("all");
  const [selected, setSelected] = React.useState(FluxData.libraries[0]);

  return (
    <div style={{ display: "flex", flex: 1, overflow: "hidden" }}>
      <div style={{ flex: 1, overflow: "auto", padding: "0 24px 24px" }}>
        <PageHeader title="Library" subtitle="Manage your media libraries and files" search="Search in library…" actions={
          <div style={{ display: "flex", gap: 8 }}>
            <Button variant="secondary" icon="refresh">Scan Library</Button>
            <Button variant="primary" icon="plus" iconRight="chevronD">Add Library</Button>
          </div>
        }/>

        {/* Tabs */}
        <div style={{ display: "flex", gap: 18, padding: "0 4px 16px", borderBottom: "1px solid rgba(255,255,255,0.06)", marginBottom: 18 }}>
          {[
            { id: "all", label: "All Libraries", icon: "folder" },
            { id: "movies", label: "Movies", icon: "movie" },
            { id: "tv", label: "TV Shows", icon: "tv" },
            { id: "music", label: "Music", icon: "music" },
            { id: "docs", label: "Documents", icon: "doc" },
            { id: "photos", label: "Photos", icon: "photo" },
          ].map(t => (
            <button key={t.id} onClick={() => setTab(t.id)} style={{
              background: "transparent", border: "none",
              padding: "0 0 12px",
              color: tab === t.id ? "#C4A8F5" : "#94A3B8",
              fontSize: 13, fontWeight: tab === t.id ? 600 : 500,
              cursor: "pointer", display: "flex", alignItems: "center", gap: 8,
              borderBottom: tab === t.id ? "2px solid #A855F7" : "2px solid transparent",
              marginBottom: -1, fontFamily: "Inter",
            }}>
              <Icon name={t.icon} size={14}/>
              {t.label}
            </button>
          ))}
        </div>

        {/* Stat tiles */}
        {tab === "all" ? (<>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 14, marginBottom: 18 }}>
          <StatTile icon="folder" label="Total Libraries" value="6" sub="+1 this week" color="#A855F7"/>
          <StatTile icon="file" label="Total Files" value="3,248" sub="+128 this week" color="#3B82F6"/>
          <StatTile icon="server" label="Total Size" value="2.4 TB" sub="of 4 TB used" color="#10B981" accent="#94A3B8"/>
          <StatTile icon="refresh" label="Last Scan" value="May 21, 2025" sub="10:30 AM" color="#F59E0B" accent="#94A3B8"/>
        </div>

        {/* View toggle + sort */}
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
          <div style={{ display: "flex", gap: 4, padding: 3, background: "rgba(255,255,255,0.04)", borderRadius: 8 }}>
            <button style={{ padding: "5px 9px", background: "rgba(168,85,247,0.18)", border: "none", borderRadius: 6, cursor: "pointer" }}><Icon name="grid" size={14} stroke="#C4A8F5"/></button>
            <button style={{ padding: "5px 9px", background: "transparent", border: "none", borderRadius: 6, cursor: "pointer" }}><Icon name="list" size={14} stroke="#64748B"/></button>
          </div>
          <div style={{ display: "flex", gap: 8 }}>
            <Button variant="secondary" size="sm" iconRight="chevronD">Sort by: Name</Button>
            <Button variant="secondary" size="sm" icon="filter">Filter</Button>
          </div>
        </div>

        {/* Library grid */}
        <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 14 }}>
          {FluxData.libraries.map(lib => (
            <LibraryCard key={lib.id} lib={lib} active={selected.id === lib.id} onClick={() => setSelected(lib)}/>
          ))}
          <div style={{
            border: "1.5px dashed rgba(168,85,247,0.3)",
            borderRadius: 12,
            padding: 20,
            display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
            gap: 8, minHeight: 130, cursor: "pointer",
            background: "rgba(168,85,247,0.04)",
          }}>
            <div style={{ width: 40, height: 40, borderRadius: "50%", background: "rgba(168,85,247,0.18)", display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Icon name="plus" size={18} stroke="#A855F7"/>
            </div>
            <div style={{ fontSize: 13, fontWeight: 600, color: "#E2E8F0" }}>Add Library</div>
            <div style={{ fontSize: 11, color: "#64748B" }}>Add a new library to get started</div>
          </div>
        </div>
        </>) : (
          <>
            {tab === "movies" && <MoviesTab/>}
            {tab === "tv"     && <TVTab/>}
            {tab === "music"  && <MusicTab/>}
            {tab === "docs"   && <DocsTab/>}
            {tab === "photos" && <PhotosTab/>}
          </>
        )}
      </div>

      {/* Right detail panel */}
      <LibraryDetail lib={selected}/>
    </div>
  );
};

const LibraryCard = ({ lib, active, onClick }) => {
  const [hover, setHover] = React.useState(false);
  // Use poster art for movies/tv, abstract for others
  const bg = lib.id === "movies" ? "linear-gradient(135deg, #1a0f2e 0%, #3a1a5a 50%, #6b3aa6 100%)" :
             lib.id === "tv"     ? "linear-gradient(135deg, #0a1929 0%, #1e3a5f 50%, #3b82c4 100%)" :
             lib.id === "music"  ? "linear-gradient(135deg, #2a0a1f 0%, #5a1a3a 50%, #c43a6a 100%)" :
             lib.id === "docs"   ? "linear-gradient(135deg, #1a1f0a 0%, #3a3f1a 50%, #8a7f3a 100%)" :
             lib.id === "photos" ? "linear-gradient(135deg, #0a1f1a 0%, #1a3f2a 50%, #2a8f5a 100%)" :
                                   "linear-gradient(135deg, #0a1a2a 0%, #1a3f5f 50%, #06b6d4 100%)";
  return (
    <div onClick={onClick} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)} style={{
      borderRadius: 12,
      overflow: "hidden",
      cursor: "pointer",
      border: active ? "1.5px solid #A855F7" : "1px solid rgba(255,255,255,0.06)",
      boxShadow: active ? "0 0 0 1px rgba(168,85,247,0.3), 0 8px 24px rgba(168,85,247,0.15)" : "none",
      background: bg,
      position: "relative",
      minHeight: 130,
      transition: "all 150ms ease",
      transform: hover && !active ? "translateY(-2px)" : "none",
    }}>
      <div style={{ position: "absolute", inset: 0, background: "linear-gradient(180deg, transparent 30%, rgba(0,0,0,0.7))" }}/>
      <div style={{ position: "absolute", inset: 0, padding: 14, display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
        <div style={{
          width: 32, height: 32, borderRadius: 8,
          background: lib.color,
          display: "flex", alignItems: "center", justifyContent: "center",
          boxShadow: `0 4px 12px ${lib.color}50`,
        }}>
          <Icon name={lib.icon} size={16} stroke="#fff"/>
        </div>
        <div>
          <div style={{ fontSize: 16, fontWeight: 700, color: "#fff", marginBottom: 2 }}>{lib.name}</div>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <div style={{ fontSize: 11, color: "rgba(255,255,255,0.7)" }}>{lib.files.toLocaleString()} files · {lib.size}</div>
            <Icon name="moreH" size={14} stroke="rgba(255,255,255,0.6)"/>
          </div>
        </div>
      </div>
    </div>
  );
};

const LibraryDetail = ({ lib }) => (
  <div style={{
    width: 300, flexShrink: 0,
    borderLeft: "1px solid rgba(255,255,255,0.05)",
    background: "rgba(13,11,28,0.5)",
    overflow: "auto", padding: "20px",
  }}>
    <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 16 }}>
      <div style={{ width: 38, height: 38, borderRadius: 8, background: lib.color, display: "flex", alignItems: "center", justifyContent: "center" }}>
        <Icon name={lib.icon} size={18} stroke="#fff"/>
      </div>
      <div style={{ flex: 1, fontSize: 18, fontWeight: 700, color: "#F1F5F9" }}>{lib.name}</div>
      <Icon name="edit" size={14} stroke="#94A3B8"/>
    </div>

    <div style={{ marginBottom: 16 }}>
      <div style={{ fontSize: 11, color: "#94A3B8", marginBottom: 6, fontWeight: 500 }}>Library Path</div>
      <div style={{
        display: "flex", alignItems: "center", gap: 8,
        padding: "8px 10px",
        background: "rgba(255,255,255,0.03)",
        border: "1px solid rgba(255,255,255,0.05)",
        borderRadius: 7,
        fontSize: 12, fontFamily: "JetBrains Mono", color: "#E2E8F0",
      }}>
        <Icon name="folder" size={12} stroke="#A855F7"/>
        <span style={{ flex: 1 }}>{lib.path}</span>
        <Icon name="folder" size={12} stroke="#64748B"/>
      </div>
    </div>

    <div style={{ marginBottom: 18 }}>
      <div style={{ fontSize: 11, color: "#94A3B8", marginBottom: 6, fontWeight: 500 }}>Description</div>
      <div style={{
        padding: 10,
        background: "rgba(255,255,255,0.03)",
        border: "1px solid rgba(255,255,255,0.05)",
        borderRadius: 7,
        fontSize: 12, color: "#CBD5E1", lineHeight: 1.5, minHeight: 56,
      }}>
        All my movie collection
      </div>
    </div>

    <div style={{ marginBottom: 18 }}>
      <div style={{ fontSize: 12, fontWeight: 600, color: "#F1F5F9", marginBottom: 10 }}>Statistics</div>
      {[
        ["Total Files", "1,245"],
        ["Total Size", "892 GB"],
        ["Folders", "128"],
        ["Last Scanned", "May 21, 2025 10:30 AM"],
      ].map(([k, v], i) => (
        <div key={i} style={{ display: "flex", justifyContent: "space-between", padding: "5px 0", fontSize: 12 }}>
          <span style={{ color: "#94A3B8" }}>{k}</span>
          <span style={{ color: "#E2E8F0", fontFamily: "JetBrains Mono" }}>{v}</span>
        </div>
      ))}
    </div>

    <div style={{ marginBottom: 18 }}>
      <div style={{ fontSize: 12, fontWeight: 600, color: "#F1F5F9", marginBottom: 10 }}>Content Breakdown</div>
      <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
        <div style={{ flex: 1, fontSize: 12 }}>
          {[
            ["Movies", "1,102", "#A855F7"],
            ["Videos", "1,245", "#3B82F6"],
            ["Subtitles", "2,341", "#10B981"],
            ["Other Files", "156", "#EC4899"],
          ].map(([l, n, c], i) => (
            <div key={i} style={{ display: "flex", alignItems: "center", gap: 8, padding: "3px 0" }}>
              <span style={{ width: 7, height: 7, borderRadius: "50%", background: c }}/>
              <span style={{ flex: 1, color: "#CBD5E1" }}>{l}</span>
              <span style={{ color: "#94A3B8", fontFamily: "JetBrains Mono" }}>{n}</span>
            </div>
          ))}
        </div>
        <div style={{
          width: 70, height: 70, borderRadius: "50%",
          background: "conic-gradient(#A855F7 0% 46%, #3B82F6 46% 78%, #10B981 78% 90%, #EC4899 90% 100%)",
          padding: 8, position: "relative",
        }}>
          <div style={{ position: "absolute", inset: 8, borderRadius: "50%", background: "#0D0B1C", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 11, fontWeight: 700, color: "#F1F5F9" }}>892 GB</div>
        </div>
      </div>
    </div>

    <div>
      <div style={{ fontSize: 12, fontWeight: 600, color: "#F1F5F9", marginBottom: 10 }}>Actions</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
        {[
          { icon: "refresh", title: "Scan Library", sub: "Scan for new files and updates" },
          { icon: "sparkle", title: "Rescan Metadata", sub: "Refresh all metadata and thumbnails" },
          { icon: "folder",  title: "View Library Files", sub: "Browse all files in this library" },
        ].map((a, i) => (
          <div key={i} style={{
            display: "flex", alignItems: "center", gap: 10,
            padding: "8px 10px",
            background: "rgba(255,255,255,0.02)",
            border: "1px solid rgba(255,255,255,0.04)",
            borderRadius: 7, cursor: "pointer",
          }}>
            <Icon name={a.icon} size={14} stroke="#94A3B8"/>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12.5, color: "#E2E8F0", fontWeight: 500 }}>{a.title}</div>
              <div style={{ fontSize: 10.5, color: "#64748B" }}>{a.sub}</div>
            </div>
            <Icon name="chevron" size={11} stroke="#475569"/>
          </div>
        ))}
        <div style={{
          display: "flex", alignItems: "center", gap: 10,
          padding: "8px 10px",
          background: "rgba(239,68,68,0.06)",
          border: "1px solid rgba(239,68,68,0.2)",
          borderRadius: 7, cursor: "pointer", marginTop: 4,
        }}>
          <Icon name="trash" size={14} stroke="#F87171"/>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12.5, color: "#F87171", fontWeight: 500 }}>Remove Library</div>
            <div style={{ fontSize: 10.5, color: "rgba(248,113,113,0.7)" }}>Remove this library and its data</div>
          </div>
        </div>
      </div>
    </div>
  </div>
);

window.LibraryScreen = LibraryScreen;

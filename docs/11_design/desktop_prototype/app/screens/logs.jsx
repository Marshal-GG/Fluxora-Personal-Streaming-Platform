// ── Logs ───────────────────────────────────────────────────────────────
const LogsScreen = () => {
  const [tab, setTab] = React.useState("live");
  const [selected, setSelected] = React.useState(0);
  const lvlColor = { INFO: "#3B82F6", WARN: "#F59E0B", ERROR: "#EF4444", DEBUG: "#94A3B8" };
  const lvlBg = { INFO: "rgba(59,130,246,0.15)", WARN: "rgba(245,158,11,0.15)", ERROR: "rgba(239,68,68,0.15)", DEBUG: "rgba(148,163,184,0.15)" };

  return (
    <div style={{ display: "flex", flex: 1, overflow: "hidden" }}>
      <div style={{ flex: 1, overflow: "auto", padding: "0 24px 24px" }}>
        <PageHeader title="Logs" subtitle="View and monitor server logs in real time" search="Search logs…" actions={
          <div style={{ display: "flex", gap: 8 }}>
            <Button variant="secondary" icon="pause">Pause</Button>
            <Button variant="danger" icon="trash">Clear Logs</Button>
          </div>
        }/>
        <div style={{ display: "flex", gap: 18, padding: "0 4px 12px", borderBottom: "1px solid rgba(255,255,255,0.06)", marginBottom: 14 }}>
          {[{id:"live",label:"Live Logs",icon:"activity"},{id:"files",label:"Log Files",icon:"file"},{id:"export",label:"Export Logs",icon:"download"}].map(t => (
            <button key={t.id} onClick={() => setTab(t.id)} style={{
              background: "transparent", border: "none", padding: "0 0 10px",
              color: tab === t.id ? "#C4A8F5" : "#94A3B8",
              fontSize: 13, fontWeight: tab === t.id ? 600 : 500, cursor: "pointer",
              borderBottom: tab === t.id ? "2px solid #A855F7" : "2px solid transparent",
              fontFamily: "Inter", display: "flex", alignItems: "center", gap: 8,
            }}><Icon name={t.icon} size={13}/>{t.label}</button>
          ))}
        </div>

        {tab === "files"  && <LogsFilesTab/>}
        {tab === "export" && <LogsExportTab/>}
        {tab === "live"   && (
        <Card padding={0}>
          <div style={{ display: "grid", gridTemplateColumns: "1.6fr 0.5fr 0.7fr 3fr", gap: 12, padding: "10px 16px", fontSize: 11, fontWeight: 600, color: "#94A3B8", borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
            <div>Time</div><div>Level</div><div>Source</div><div>Message</div>
          </div>
          {FluxData.logs.map((l, i) => (
            <div key={i} onClick={() => setSelected(i)} style={{
              display: "grid", gridTemplateColumns: "1.6fr 0.5fr 0.7fr 3fr",
              gap: 12, padding: "9px 16px", alignItems: "center",
              borderTop: "1px solid rgba(255,255,255,0.03)",
              background: selected === i ? "rgba(168,85,247,0.10)" : "transparent",
              cursor: "pointer",
              fontSize: 11.5, fontFamily: "JetBrains Mono",
            }}>
              <div style={{ color: "#94A3B8" }}>{l.time}</div>
              <div><span style={{ padding: "2px 8px", borderRadius: 4, background: lvlBg[l.level], color: lvlColor[l.level], fontSize: 10, fontWeight: 700, fontFamily: "Inter" }}>{l.level}</span></div>
              <div style={{ color: "#A855F7", fontFamily: "Inter", fontWeight: 500 }}>{l.source}</div>
              <div style={{ color: l.level === "ERROR" ? "#F87171" : l.level === "WARN" ? "#FBBF24" : "#E2E8F0" }}>{l.msg}</div>
            </div>
          ))}
          <div style={{ padding: "12px 16px", display: "flex", justifyContent: "space-between", alignItems: "center", fontSize: 12, color: "#94A3B8", borderTop: "1px solid rgba(255,255,255,0.04)" }}>
            <span>Showing 1 to 14 of 1,248 logs</span>
            <div style={{ display: "flex", gap: 4, alignItems: "center" }}>
              <button style={pgBtn}><Icon name="chevronL" size={11} stroke="#94A3B8"/></button>
              {[1,2,3,4,5].map(p => <button key={p} style={p===1 ? {...pgBtn, background:"rgba(168,85,247,0.18)", border:"1px solid rgba(168,85,247,0.4)", color:"#C4A8F5"} : pgBtn}>{p}</button>)}
              <span style={{ padding: "0 6px", color: "#475569" }}>…</span>
              <button style={pgBtn}>89</button>
              <button style={pgBtn}><Icon name="chevron" size={11} stroke="#94A3B8"/></button>
              <span style={{ marginLeft: 8 }}>50 / page</span>
            </div>
          </div>
        </Card>
        )}
      </div>

      <div style={{ width: 280, flexShrink: 0, borderLeft: "1px solid rgba(255,255,255,0.05)", background: "rgba(13,11,28,0.5)", overflow: "auto", padding: 18 }}>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 14 }}>
          <span style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Log Filters</span>
          <a style={{ fontSize: 11, color: "#A855F7", cursor: "pointer", fontWeight: 500 }}>Reset</a>
        </div>
        {[
          ["Level", ["All Levels", "INFO", "WARN", "ERROR", "DEBUG"]],
          ["Source", ["All Sources"]],
          ["Time Range", ["Last 24 Hours"]],
        ].map(([l, opts], i) => (
          <div key={i} style={{ marginBottom: 12 }}>
            <div style={{ fontSize: 11, color: "#94A3B8", marginBottom: 5, fontWeight: 500 }}>{l}</div>
            <div style={{ display: "flex", alignItems: "center", padding: "8px 10px", background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)", borderRadius: 7, fontSize: 12, color: "#E2E8F0" }}>
              <span style={{ flex: 1 }}>{opts[0]}</span>
              <Icon name="chevronD" size={12} stroke="#64748B"/>
            </div>
          </div>
        ))}
        <div style={{ marginBottom: 12 }}>
          <div style={{ fontSize: 11, color: "#94A3B8", marginBottom: 5, fontWeight: 500 }}>Search</div>
          <div style={{ position: "relative" }}>
            <input placeholder="Search in logs…" style={{ width: "100%", padding: "8px 32px 8px 10px", background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)", borderRadius: 7, color: "#E2E8F0", fontSize: 12, fontFamily: "Inter", outline: "none" }}/>
            <Icon name="search" size={12} stroke="#64748B" style={{ position: "absolute", right: 10, top: 9 }}/>
          </div>
        </div>
        <Button variant="primary" fullWidth>Apply Filters</Button>

        <div style={{ marginTop: 20 }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9", marginBottom: 10 }}>Logs Summary</div>
          {[
            ["Info", 1048, "#3B82F6"],
            ["Warning", 142, "#F59E0B"],
            ["Error", 36, "#EF4444"],
            ["Debug", 22, "#94A3B8"],
          ].map(([l, n, c], i) => (
            <div key={i} style={{ display: "flex", alignItems: "center", gap: 8, padding: "5px 0", fontSize: 12 }}>
              <span style={{ width: 7, height: 7, borderRadius: "50%", background: c }}/>
              <span style={{ flex: 1, color: "#E2E8F0" }}>{l}</span>
              <span style={{ color: "#94A3B8", fontFamily: "JetBrains Mono" }}>{n.toLocaleString()}</span>
            </div>
          ))}
          <div style={{ display: "flex", justifyContent: "space-between", padding: "8px 0 0", marginTop: 6, borderTop: "1px solid rgba(255,255,255,0.05)", fontSize: 12 }}>
            <span style={{ color: "#E2E8F0", fontWeight: 600 }}>Total Logs</span>
            <span style={{ color: "#A855F7", fontFamily: "JetBrains Mono", fontWeight: 600 }}>1,248</span>
          </div>
        </div>

        <div style={{ marginTop: 20 }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9", marginBottom: 10 }}>Quick Actions</div>
          {[
            ["folder", "Open Log Folder", "View log files in explorer"],
            ["download", "Export Current Logs", "Export logs as .zip file"],
            ["trash", "Clear Old Logs", "Remove logs older than 7 days"],
          ].map(([ic, t, s], i) => (
            <div key={i} style={{ display: "flex", alignItems: "center", gap: 10, padding: "8px 10px", background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.04)", borderRadius: 7, marginBottom: 5, cursor: "pointer" }}>
              <Icon name={ic} size={13} stroke="#94A3B8"/>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 12, color: "#E2E8F0", fontWeight: 500 }}>{t}</div>
                <div style={{ fontSize: 10.5, color: "#64748B" }}>{s}</div>
              </div>
              <Icon name="chevron" size={11} stroke="#475569"/>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
window.LogsScreen = LogsScreen;

// ── Logs sub-tabs ──────────────────────────────────────────────────────
const LogsFilesTab = () => (
  <Card padding={0}>
    <div style={{ padding: "14px 20px", borderBottom: "1px solid rgba(255,255,255,0.05)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
      <div>
        <div style={{ fontSize: 13.5, fontWeight: 600, color: "#F1F5F9" }}>Log Files</div>
        <div style={{ fontSize: 11.5, color: "#64748B", marginTop: 2 }}>20.6 MB across 7 files · auto-rotate at 5 MB</div>
      </div>
      <div style={{ display: "flex", gap: 8 }}>
        <Button variant="secondary" size="sm" icon="refresh">Rotate Now</Button>
        <Button variant="danger" size="sm" icon="trash">Clear All</Button>
      </div>
    </div>
    <div style={{ display: "grid", gridTemplateColumns: "2fr 1fr 1fr 1fr 1fr 1fr", gap: 12, padding: "10px 20px", fontSize: 11, fontWeight: 600, color: "#94A3B8", borderBottom: "1px solid rgba(255,255,255,0.03)" }}>
      <div>File Name</div><div>Size</div><div>Entries</div><div>Status</div><div>Modified</div><div style={{ textAlign: "right" }}>Actions</div>
    </div>
    {FluxData2.logFiles.map((f, i) => (
      <div key={i} style={{ display: "grid", gridTemplateColumns: "2fr 1fr 1fr 1fr 1fr 1fr", gap: 12, padding: "12px 20px", alignItems: "center", borderTop: "1px solid rgba(255,255,255,0.03)", fontSize: 12.5 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <Icon name="doc" size={13} stroke={f.status === "Active" ? "#10B981" : "#64748B"}/>
          <span style={{ fontFamily: "JetBrains Mono", color: "#E2E8F0", fontSize: 12 }}>{f.name}</span>
        </div>
        <span style={{ color: "#94A3B8" }}>{f.size}</span>
        <span style={{ color: "#94A3B8", fontFamily: "JetBrains Mono" }}>{f.entries.toLocaleString()}</span>
        <Pill color={f.status === "Active" ? "success" : "neutral"}>{f.status}</Pill>
        <span style={{ color: "#94A3B8", fontSize: 11.5 }}>{f.date}</span>
        <div style={{ display: "flex", gap: 4, justifyContent: "flex-end" }}>
          <button style={{ ...iconBtnSub }}><Icon name="eye" size={12} stroke="#94A3B8"/></button>
          <button style={{ ...iconBtnSub }}><Icon name="download" size={12} stroke="#94A3B8"/></button>
          <button style={{ ...iconBtnSub }}><Icon name="trash" size={12} stroke="#F87171"/></button>
        </div>
      </div>
    ))}
  </Card>
);

const LogsExportTab = () => (
  <div style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 14 }}>
    <Card padding={22}>
      <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 14 }}>Export Logs</div>
      <SField label="Date Range" sub="Select start and end dates" control={
        <div style={{ display: "flex", gap: 8 }}>
          <TextField value="2025-05-15"/><TextField value="2025-05-21"/>
        </div>
      }/>
      <SField label="Log Levels" sub="Include the following severity levels" control={
        <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
          {[["INFO","#3B82F6"],["WARN","#F59E0B"],["ERROR","#F87171"],["DEBUG","#94A3B8"],["FATAL","#EC4899"]].map(([l, c]) => (
            <span key={l} style={{ padding: "4px 10px", background: `${c}18`, border: `1px solid ${c}40`, borderRadius: 6, fontSize: 11, fontWeight: 600, color: c, fontFamily: "JetBrains Mono", cursor: "pointer" }}>{l}</span>
          ))}
        </div>
      }/>
      <SField label="Sources" sub="Pick which subsystems to include" control={<SelectField value="All sources (12)"/>}/>
      <SField label="Format" sub="Output file format" control={
        <div style={{ display: "flex", gap: 6 }}>
          {["TXT","JSON","CSV","NDJSON"].map((f, i) => (
            <span key={f} style={{ padding: "5px 10px", background: i === 1 ? "rgba(168,85,247,0.18)" : "rgba(255,255,255,0.03)", border: i === 1 ? "1px solid rgba(168,85,247,0.5)" : "1px solid rgba(255,255,255,0.06)", borderRadius: 6, fontSize: 11, fontWeight: 600, color: i === 1 ? "#E9D5FF" : "#94A3B8", fontFamily: "JetBrains Mono", cursor: "pointer" }}>{f}</span>
          ))}
        </div>
      }/>
      <SField label="Compression" control={<TToggle on/>}/>
      <SField label="Anonymize IPs" sub="Mask client IP addresses" control={<TToggle on={false}/>}/>
      <div style={{ display: "flex", gap: 8, marginTop: 18 }}>
        <Button variant="primary" icon="download">Export 8,160 entries</Button>
        <Button variant="secondary" icon="msg">Email to me</Button>
      </div>
    </Card>
    <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
      <Card padding={18}>
        <div style={{ fontSize: 13.5, fontWeight: 600, color: "#F1F5F9", marginBottom: 12 }}>Recent Exports</div>
        {[
          ["logs_2025-05-15_to_21.json.gz", "May 21, 11:22", "1.4 MB"],
          ["error_dump_2025-05-19.txt",     "May 19, 18:04", "286 KB"],
          ["full_archive_2025-05-01.zip",   "May 01, 09:00", "12 MB"],
        ].map(([n, t, s], i) => (
          <div key={i} style={{ padding: "10px 0", borderTop: i ? "1px solid rgba(255,255,255,0.04)" : "none" }}>
            <div style={{ fontSize: 12, fontFamily: "JetBrains Mono", color: "#E2E8F0" }}>{n}</div>
            <div style={{ fontSize: 11, color: "#64748B", marginTop: 2, display: "flex", justifyContent: "space-between" }}>
              <span>{t}</span><span>{s}</span>
            </div>
          </div>
        ))}
      </Card>
      <Card padding={18}>
        <div style={{ fontSize: 13.5, fontWeight: 600, color: "#F1F5F9", marginBottom: 10 }}>Auto-Export</div>
        <SwitchRow label="Weekly archive" sub="Every Sunday at 3am" on/>
      </Card>
    </div>
  </div>
);

window.LogsFilesTab = LogsFilesTab;
window.LogsExportTab = LogsExportTab;

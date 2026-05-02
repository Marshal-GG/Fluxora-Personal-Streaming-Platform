// ── Help / Shortcuts ───────────────────────────────────────────────────
const HelpScreen = () => (
  <div style={{ overflow: "auto", flex: 1, padding: "0 28px 28px" }}>
    <PageHeader title="Help & Shortcuts" subtitle="Quick reference, keyboard shortcuts, and support resources"/>

    <div style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 14 }}>
      <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
        <Card padding={22}>
          <div style={{ display: "flex", gap: 14, alignItems: "center", marginBottom: 6 }}>
            <div style={{ width: 44, height: 44, borderRadius: 10, background: "linear-gradient(135deg, #6366F1, #A855F7)", display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Icon name="cmd" size={18} stroke="#fff"/>
            </div>
            <div>
              <div style={{ fontSize: 15, fontWeight: 700, color: "#F1F5F9" }}>Keyboard Shortcuts</div>
              <div style={{ fontSize: 12, color: "#94A3B8" }}>Speed up your workflow with these key bindings</div>
            </div>
          </div>
        </Card>

        {FluxData2.shortcuts.map(g => (
          <Card key={g.group} padding={0}>
            <div style={{ padding: "14px 22px", borderBottom: "1px solid rgba(255,255,255,0.04)", fontSize: 13.5, fontWeight: 600, color: "#F1F5F9" }}>{g.group}</div>
            {g.items.map(([k, keys], i) => (
              <div key={i} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "11px 22px", borderTop: "1px solid rgba(255,255,255,0.03)", fontSize: 12.5 }}>
                <span style={{ color: "#E2E8F0" }}>{k}</span>
                <div style={{ display: "flex", gap: 4 }}>
                  {keys.split(" ").map((kk, j) => (
                    <kbd key={j} style={{ padding: "3px 9px", background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)", borderBottom: "2px solid rgba(255,255,255,0.05)", borderRadius: 5, fontSize: 11, fontFamily: "JetBrains Mono", color: "#E2E8F0", fontWeight: 600 }}>{kk}</kbd>
                  ))}
                </div>
              </div>
            ))}
          </Card>
        ))}
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
        <Card padding={20}>
          <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 12 }}>Get Help</div>
          {[
            ["doc",     "Documentation",     "User guides + API"],
            ["users",   "Community",         "12k+ self-hosters"],
            ["msg",     "Live Chat",         "Plus & Pro plans"],
            ["info",    "Submit a Ticket",   "24h response"],
            ["sparkle", "What's New",        "Latest releases"],
          ].map(([ic, t, s], i) => (
            <div key={i} style={{ display: "flex", alignItems: "center", gap: 12, padding: "10px 0", borderTop: i ? "1px solid rgba(255,255,255,0.04)" : "none", cursor: "pointer" }}>
              <Icon name={ic} size={14} stroke="#A855F7"/>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 12.5, color: "#E2E8F0", fontWeight: 500 }}>{t}</div>
                <div style={{ fontSize: 11, color: "#64748B" }}>{s}</div>
              </div>
              <Icon name="extLink" size={11} stroke="#475569"/>
            </div>
          ))}
        </Card>

        <Card padding={20}>
          <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 8 }}>Status</div>
          {[
            ["Streaming Service", "online"],
            ["Authentication", "online"],
            ["Cloud Sync", "online"],
            ["Update Servers", "warning"],
          ].map(([k, s], i) => (
            <div key={i} style={{ display: "flex", alignItems: "center", gap: 8, padding: "7px 0", borderTop: i ? "1px solid rgba(255,255,255,0.04)" : "none", fontSize: 12 }}>
              <StatusDot status={s} size={6}/>
              <span style={{ flex: 1, color: "#94A3B8" }}>{k}</span>
              <span style={{ color: s === "online" ? "#10B981" : "#F59E0B", fontSize: 11, fontWeight: 600 }}>{s === "online" ? "Operational" : "Degraded"}</span>
            </div>
          ))}
          <a style={{ fontSize: 11.5, color: "#A855F7", marginTop: 10, display: "inline-block", cursor: "pointer", fontWeight: 500 }}>status.fluxora.com →</a>
        </Card>

        <Card padding={20}>
          <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 8 }}>Quick Diagnostics</div>
          <div style={{ fontSize: 11.5, color: "#64748B", lineHeight: 1.5, marginBottom: 12 }}>Generate a support bundle with logs, configuration, and system info.</div>
          <Button variant="primary" fullWidth icon="download">Generate Bundle</Button>
        </Card>
      </div>
    </div>
  </div>
);

window.HelpScreen = HelpScreen;

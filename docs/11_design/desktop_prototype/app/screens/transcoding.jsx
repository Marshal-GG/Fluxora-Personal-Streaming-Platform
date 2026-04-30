// ── Transcoding ────────────────────────────────────────────────────────
const TranscodingScreen = ({ tick, onNav }) => (
  <div style={{ overflow: "auto", flex: 1, padding: "0 28px 28px" }}>
    <PageHeader title="Transcoding" subtitle="Real-time encoder load and per-session details" actions={<div style={{ display: "flex", gap: 8 }}><Button variant="secondary" icon="settings" onClick={() => onNav && onNav("encoder")}>Encoder Settings</Button></div>}/>

    <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 14, marginBottom: 18 }}>
      <StatTile icon="cpu" label="Active Transcodes" value="3" sub="of 4 max" color="#A855F7"/>
      <StatTile icon="zap" label="Hardware Encoder" value="NVENC" sub="RTX 4070" color="#10B981" accent="#10B981"/>
      <StatTile icon="activity" label="Encoder Load" value="68%" sub="GPU healthy" color="#EC4899"/>
      <StatTile icon="layers" label="Queue Depth" value="1" sub="Avg wait 0s" color="#3B82F6"/>
    </div>

    <Card padding={0}>
      <div style={{ display: "flex", justifyContent: "space-between", padding: "14px 18px", borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
        <span style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9" }}>Active Sessions</span>
        <Button variant="danger" size="sm" icon="stop">Stop All</Button>
      </div>
      {FluxData.transcodes.map((t, i) => (
        <div key={t.id} style={{ padding: "16px 20px", borderTop: i ? "1px solid rgba(255,255,255,0.03)" : "none" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
            <div>
              <div style={{ fontSize: 13, fontWeight: 600, color: "#E2E8F0" }}>{t.title}</div>
              <div style={{ fontSize: 11, color: "#64748B", marginTop: 2, display: "flex", gap: 8, fontFamily: "JetBrains Mono" }}>
                <span>{t.client}</span>
                <span>·</span>
                <span style={{ color: "#94A3B8" }}>{t.source}</span>
                <Icon name="arrow" size={11} stroke="#475569"/>
                <span style={{ color: "#A855F7" }}>{t.target}</span>
              </div>
            </div>
            <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
              {t.status === "active" ? (
                <>
                  <Pill color="success">{t.fps} fps · {t.speed.toFixed(1)}x</Pill>
                  <button style={iconBtn}><Icon name="pause" size={12} stroke="#94A3B8"/></button>
                  <button style={iconBtn}><Icon name="stop" size={12} stroke="#F87171"/></button>
                </>
              ) : <Pill color="neutral">Queued</Pill>}
            </div>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <div style={{ flex: 1 }}><Progress value={t.progress} color={t.status === "active" ? "linear-gradient(90deg, #8B5CF6, #EC4899)" : "rgba(255,255,255,0.15)"}/></div>
            <span style={{ fontSize: 11, color: "#94A3B8", fontFamily: "JetBrains Mono", minWidth: 36, textAlign: "right" }}>{Math.floor(t.progress*100)}%</span>
          </div>
        </div>
      ))}
    </Card>
  </div>
);
window.TranscodingScreen = TranscodingScreen;

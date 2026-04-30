// ── Activity ───────────────────────────────────────────────────────────
const ActivityScreen = () => (
  <div style={{ overflow: "auto", flex: 1, padding: "0 28px 28px" }}>
    <PageHeader title="Activity" subtitle="Real-time event log of streams, clients, and server operations" search="Search events…" actions={<Button variant="secondary" icon="download">Export</Button>}/>
    <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 14, marginBottom: 18 }}>
      <StatTile icon="activity" label="Events Today" value="142" sub="+24 this hour" color="#A855F7"/>
      <StatTile icon="play" label="Streams Started" value="38" sub="12 active now" color="#3B82F6"/>
      <StatTile icon="users" label="Client Events" value="56" sub="9 connections" color="#10B981"/>
      <StatTile icon="info" label="Warnings" value="4" sub="0 errors" color="#F59E0B" accent="#F59E0B"/>
    </div>
    <div style={{ display: "grid", gridTemplateColumns: "1fr 280px", gap: 14 }}>
      <Card padding={0}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "14px 18px", borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <span style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9" }}>Live Activity</span>
            <span style={{ display: "inline-flex", alignItems: "center", gap: 5, fontSize: 10.5, color: "#10B981" }}>
              <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#10B981", boxShadow: "0 0 6px #10B981" }}/> Live
            </span>
          </div>
          <Button variant="secondary" size="sm" icon="pause">Pause</Button>
        </div>
        {FluxData.activity.map((a, i) => (
          <div key={i} style={{ display: "flex", alignItems: "center", gap: 14, padding: "14px 20px", borderBottom: i < FluxData.activity.length - 1 ? "1px solid rgba(255,255,255,0.03)" : "none" }}>
            <div style={{ width: 36, height: 36, borderRadius: 9, background: `${a.color}1F`, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
              <Icon name={a.icon} size={15} stroke={a.color}/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13, color: "#E2E8F0", fontWeight: 500 }}>{a.title}: <span style={{ color: "#A855F7" }}>{a.msg}</span></div>
              <div style={{ fontSize: 11, color: "#64748B", marginTop: 2 }}>{a.sub}</div>
            </div>
            <div style={{ fontSize: 11, color: "#64748B", fontFamily: "JetBrains Mono" }}>{a.ago}</div>
          </div>
        ))}
      </Card>
      <div>
        <Card padding={18} style={{ marginBottom: 14 }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9", marginBottom: 12 }}>Filter by Type</div>
          {[
            ["Streams",     38, "#A855F7"],
            ["Clients",     56, "#3B82F6"],
            ["Transcoding", 24, "#EC4899"],
            ["Library",     16, "#10B981"],
            ["System",      8,  "#94A3B8"],
          ].map(([l, n, c], i) => (
            <label key={i} style={{ display: "flex", alignItems: "center", gap: 10, padding: "6px 0", fontSize: 12, color: "#E2E8F0", cursor: "pointer" }}>
              <input type="checkbox" defaultChecked style={{ accentColor: c }}/>
              <span style={{ width: 8, height: 8, borderRadius: "50%", background: c }}/>
              <span style={{ flex: 1 }}>{l}</span>
              <span style={{ color: "#64748B", fontFamily: "JetBrains Mono" }}>{n}</span>
            </label>
          ))}
        </Card>
        <Card padding={18}>
          <div style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9", marginBottom: 12 }}>Top Clients Today</div>
          {[
            ["iPhone 14 Pro", 24, "#A855F7"],
            ["Windows Laptop", 18, "#3B82F6"],
            ["MacBook Air", 11, "#10B981"],
          ].map(([n, c, col], i) => (
            <div key={i} style={{ marginBottom: 10 }}>
              <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
                <span style={{ fontSize: 12, color: "#E2E8F0" }}>{n}</span>
                <span style={{ fontSize: 11, color: "#94A3B8", fontFamily: "JetBrains Mono" }}>{c} events</span>
              </div>
              <Progress value={c/30} color={col}/>
            </div>
          ))}
        </Card>
      </div>
    </div>
  </div>
);
window.ActivityScreen = ActivityScreen;

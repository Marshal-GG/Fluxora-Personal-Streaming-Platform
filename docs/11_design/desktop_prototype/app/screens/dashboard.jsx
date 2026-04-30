// ── Dashboard ──────────────────────────────────────────────────────────
const DashboardScreen = ({ tick }) => {
  const cpu = 18 + Math.sin(tick/8)*2;

  return (
    <div style={{ overflow: "auto", flex: 1, padding: "0 28px 28px" }}>
      <PageHeader title="Dashboard" subtitle="Overview of your media server" actions={
        <div style={{ display: "flex", gap: 8 }}>
          <Button variant="secondary" icon="refresh">Restart Server</Button>
          <Button variant="danger" icon="stop">Stop Server</Button>
        </div>
      }/>

      {/* 4 stat tiles */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 14, marginBottom: 18 }}>
        <Card padding={18}>
          <div style={{ display: "flex", alignItems: "flex-start", gap: 12 }}>
            <div style={{ width: 40, height: 40, borderRadius: 10, background: "rgba(168,85,247,0.15)", display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Icon name="folder" size={20} stroke="#A855F7"/>
            </div>
            <div>
              <div style={{ fontSize: 12, color: "#94A3B8" }}>Libraries</div>
              <div style={{ fontSize: 26, fontWeight: 700, color: "#F1F5F9", lineHeight: 1.1, marginTop: 2 }}>4</div>
            </div>
          </div>
          <a style={{ display: "inline-flex", alignItems: "center", gap: 4, fontSize: 11, color: "#A855F7", marginTop: 12, cursor: "pointer", fontWeight: 500 }}>View all <Icon name="chevron" size={11}/></a>
        </Card>
        <Card padding={18}>
          <div style={{ display: "flex", alignItems: "flex-start", gap: 12 }}>
            <div style={{ width: 40, height: 40, borderRadius: 10, background: "rgba(59,130,246,0.15)", display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Icon name="desktop" size={20} stroke="#3B82F6"/>
            </div>
            <div>
              <div style={{ fontSize: 12, color: "#94A3B8" }}>Connected Clients</div>
              <div style={{ fontSize: 26, fontWeight: 700, color: "#F1F5F9", lineHeight: 1.1, marginTop: 2 }}>2</div>
            </div>
          </div>
          <a style={{ display: "inline-flex", alignItems: "center", gap: 4, fontSize: 11, color: "#3B82F6", marginTop: 12, cursor: "pointer", fontWeight: 500 }}>View all <Icon name="chevron" size={11}/></a>
        </Card>
        <Card padding={18}>
          <div style={{ display: "flex", alignItems: "flex-start", gap: 12 }}>
            <div style={{ width: 40, height: 40, borderRadius: 10, background: "rgba(236,72,153,0.15)", display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Icon name="play" size={20} stroke="#EC4899"/>
            </div>
            <div>
              <div style={{ fontSize: 12, color: "#94A3B8" }}>Active Streams</div>
              <div style={{ fontSize: 26, fontWeight: 700, color: "#F1F5F9", lineHeight: 1.1, marginTop: 2 }}>1</div>
            </div>
          </div>
          <a style={{ display: "inline-flex", alignItems: "center", gap: 4, fontSize: 11, color: "#EC4899", marginTop: 12, cursor: "pointer", fontWeight: 500 }}>View all <Icon name="chevron" size={11}/></a>
        </Card>
        <Card padding={18}>
          <div style={{ display: "flex", alignItems: "flex-start", gap: 12 }}>
            <div style={{ width: 40, height: 40, borderRadius: 10, background: "rgba(245,158,11,0.15)", display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Icon name="activity" size={20} stroke="#F59E0B"/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12, color: "#94A3B8" }}>CPU Usage</div>
              <div style={{ fontSize: 26, fontWeight: 700, color: "#F1F5F9", lineHeight: 1.1, marginTop: 2 }}>{cpu.toFixed(0)}%</div>
            </div>
          </div>
          <Sparkline data={FluxData.cpuSpark} color="#F59E0B"/>
        </Card>
      </div>

      {/* Server Info + Quick Access */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14, marginBottom: 18 }}>
        <Card padding={20}>
          <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 16 }}>Server Information</div>
          {[
            ["Server Name", "Fluxora Server"],
            ["Local IP", <span style={{ display:"inline-flex", alignItems:"center", gap:6 }}><StatusDot status="online" size={7}/> 192.168.1.105</span>],
            ["Internet Status", <Pill color="success">Connected</Pill>],
            ["Public Address", <span style={{ display:"inline-flex", alignItems:"center", gap:6, fontFamily:"JetBrains Mono" }}>103.21.45.67:8443 <Icon name="extLink" size={11} stroke="#A855F7"/></span>],
            ["Uptime", "2h 45m 12s"],
            ["Version", "1.0.0"],
          ].map(([k, v], i) => (
            <div key={i} style={{ display: "flex", justifyContent: "space-between", padding: "9px 0", borderBottom: i < 5 ? "1px solid rgba(255,255,255,0.04)" : "none", fontSize: 13 }}>
              <span style={{ color: "#94A3B8" }}>{k}</span>
              <span style={{ color: "#E2E8F0", fontWeight: 500 }}>{v}</span>
            </div>
          ))}
        </Card>

        <Card padding={20}>
          <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 16 }}>Quick Access</div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
            {[
              { icon: "folderPlus", title: "Add Library", sub: "Add folders to library", color: "#A855F7" },
              { icon: "users", title: "Manage Clients", sub: "View connected devices", color: "#3B82F6" },
              { icon: "groups", title: "Create Group", sub: "Organize your content", color: "#EC4899" },
              { icon: "activity", title: "View Activity", sub: "Real-time activity", color: "#F59E0B" },
            ].map((a, i) => (
              <div key={i} style={{
                padding: 14,
                background: "rgba(255,255,255,0.02)",
                border: "1px solid rgba(255,255,255,0.05)",
                borderRadius: 10,
                cursor: "pointer",
                transition: "all 150ms",
              }} className="hoverable-card">
                <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 4 }}>
                  <Icon name={a.icon} size={16} stroke={a.color}/>
                  <span style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9" }}>{a.title}</span>
                </div>
                <div style={{ fontSize: 11, color: "#64748B" }}>{a.sub}</div>
              </div>
            ))}
            <div style={{
              gridColumn: "span 2",
              padding: 14,
              background: "rgba(255,255,255,0.02)",
              border: "1px solid rgba(255,255,255,0.05)",
              borderRadius: 10,
              cursor: "pointer",
              display: "flex", alignItems: "center", gap: 10,
            }} className="hoverable-card">
              <Icon name="settings" size={16} stroke="#94A3B8"/>
              <div>
                <div style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9" }}>Server Settings</div>
                <div style={{ fontSize: 11, color: "#64748B" }}>Configure server options</div>
              </div>
            </div>
          </div>
        </Card>
      </div>

      {/* Activity + Storage donut */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
        <Card padding={0}>
          <div style={{ padding: "16px 20px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Recent Activity</div>
            <a style={{ fontSize: 12, color: "#A855F7", cursor: "pointer", fontWeight: 500 }}>View All</a>
          </div>
          {FluxData.activity.slice(0, 4).map((a, i) => (
            <div key={i} style={{ display: "flex", alignItems: "center", gap: 12, padding: "10px 20px", borderTop: "1px solid rgba(255,255,255,0.03)" }}>
              <div style={{ width: 30, height: 30, borderRadius: 8, background: `${a.color}20`, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                <Icon name={a.icon} size={13} stroke={a.color}/>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 12.5, color: "#E2E8F0", fontWeight: 500 }}>{a.title}: {a.msg}</div>
                <div style={{ fontSize: 11, color: "#64748B", marginTop: 2 }}>{a.sub}</div>
              </div>
              <div style={{ fontSize: 11, color: "#64748B", fontFamily: "JetBrains Mono" }}>{a.ago}</div>
            </div>
          ))}
        </Card>

        <Card padding={20}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Storage Overview</div>
            <span style={{ fontSize: 11, color: "#94A3B8" }}>Total: <span style={{ color: "#E2E8F0", fontWeight: 600 }}>2.72 TB</span></span>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 24 }}>
            <Donut/>
            <div style={{ flex: 1 }}>
              {[
                { label: "Movies",   size: "1.25 TB", pct: 46, color: "#A855F7" },
                { label: "TV Shows", size: "890 GB",  pct: 32, color: "#F59E0B" },
                { label: "Music",    size: "320 GB",  pct: 12, color: "#10B981" },
                { label: "Others",   size: "260 GB",  pct: 10, color: "#EC4899" },
              ].map((s, i) => (
                <div key={i} style={{ display: "flex", alignItems: "center", gap: 10, padding: "5px 0", fontSize: 12 }}>
                  <span style={{ width: 8, height: 8, borderRadius: "50%", background: s.color }}/>
                  <span style={{ flex: 1, color: "#E2E8F0" }}>{s.label}</span>
                  <span style={{ color: "#94A3B8", fontFamily: "JetBrains Mono" }}>{s.size}</span>
                  <span style={{ color: "#64748B", width: 32, textAlign: "right", fontFamily: "JetBrains Mono" }}>{s.pct}%</span>
                </div>
              ))}
            </div>
          </div>
          <div style={{ marginTop: 16 }}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6, fontSize: 11.5 }}>
              <span style={{ color: "#94A3B8" }}>2.72 TB of 4 TB used</span>
              <span style={{ color: "#A855F7", fontWeight: 600 }}>68%</span>
            </div>
            <Progress value={0.68}/>
          </div>
        </Card>
      </div>
    </div>
  );
};

const Sparkline = ({ data, color = "#A855F7" }) => {
  const w = 200, h = 36;
  const max = Math.max(...data), min = Math.min(...data);
  const r = max - min || 1;
  const step = w / (data.length - 1);
  const pts = data.map((v, i) => `${i*step},${h - ((v-min)/r)*(h-4)-2}`).join(" L ");
  return (
    <svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} style={{ marginTop: 8 }}>
      <path d={`M ${pts}`} fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round"/>
    </svg>
  );
};

const Donut = () => {
  const data = [{ pct: 46, color: "#A855F7" }, { pct: 32, color: "#F59E0B" }, { pct: 12, color: "#10B981" }, { pct: 10, color: "#EC4899" }];
  const r = 44, cx = 60, cy = 60, c = 2 * Math.PI * r;
  let off = 0;
  return (
    <svg width="120" height="120" style={{ flexShrink: 0 }}>
      <circle cx={cx} cy={cy} r={r} fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth="14"/>
      {data.map((d, i) => {
        const len = (d.pct/100) * c;
        const dash = `${len} ${c-len}`;
        const dashOff = -off;
        off += len;
        return <circle key={i} cx={cx} cy={cy} r={r} fill="none" stroke={d.color} strokeWidth="14" strokeDasharray={dash} strokeDashoffset={dashOff} transform={`rotate(-90 ${cx} ${cy})`}/>;
      })}
      <text x={cx} y={cy-2} textAnchor="middle" fill="#F1F5F9" fontSize="14" fontWeight="700" fontFamily="Inter">2.72</text>
      <text x={cx} y={cy+14} textAnchor="middle" fill="#94A3B8" fontSize="10" fontFamily="Inter">TB</text>
    </svg>
  );
};

window.DashboardScreen = DashboardScreen;

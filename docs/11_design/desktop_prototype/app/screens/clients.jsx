// ── Clients ────────────────────────────────────────────────────────────
const ClientsScreen = () => {
  const [selected, setSelected] = React.useState(FluxData.clients[0]);

  return (
    <div style={{ display: "flex", flex: 1, overflow: "hidden" }}>
      <div style={{ flex: 1, overflow: "auto", padding: "0 24px 24px" }}>
        <PageHeader title="Clients" subtitle="Manage connected devices and client access"/>

        {/* Stats */}
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 14, marginBottom: 18 }}>
          <StatTile icon="users" label="Total Clients" value="6" sub="+1 this week" color="#A855F7"/>
          <StatTile icon="dashboard" label="Online Now" value="3" sub="50% of total" color="#10B981" accent="#94A3B8"/>
          <StatTile icon="play" label="Active Streams" value="2" sub="2 streams running" color="#3B82F6" accent="#94A3B8"/>
          <StatTile icon="history2" label="Total Connections" value="48" sub="+12 this week" color="#EC4899"/>
        </div>

        {/* Filter row */}
        <div style={{ display: "flex", gap: 10, marginBottom: 14, alignItems: "center" }}>
          <div style={{ position: "relative", flex: 1, maxWidth: 280 }}>
            <Icon name="search" size={13} stroke="#64748B" style={{ position: "absolute", left: 11, top: 9 }}/>
            <input placeholder="Search clients…" style={{
              width: "100%", background: "rgba(20,18,38,0.7)", border: "1px solid rgba(255,255,255,0.06)",
              borderRadius: 7, padding: "7px 12px 7px 32px", color: "#E2E8F0", fontSize: 12, fontFamily: "Inter", outline: "none",
            }}/>
          </div>
          <Button variant="secondary" size="sm" iconRight="chevronD">All Status</Button>
          <Button variant="secondary" size="sm" iconRight="chevronD">All Devices</Button>
          <Button variant="secondary" size="sm" iconRight="chevronD">Sort: Last Active</Button>
          <button style={{ width: 32, height: 32, borderRadius: 7, background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.06)", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
            <Icon name="refresh" size={13} stroke="#94A3B8"/>
          </button>
        </div>

        {/* Table */}
        <Card padding={0}>
          <div style={{
            display: "grid", gridTemplateColumns: "1.6fr 1fr 1.1fr 0.9fr 1fr 1.6fr 1fr",
            gap: 12, padding: "12px 18px",
            fontSize: 11, fontWeight: 600, color: "#94A3B8",
            letterSpacing: "0.04em",
            borderBottom: "1px solid rgba(255,255,255,0.05)",
          }}>
            <div>Client</div><div>Device</div><div>IP Address</div><div>Status</div><div>Last Active</div><div>Current Stream</div><div style={{ textAlign: "right" }}>Actions</div>
          </div>
          {FluxData.clients.map(c => (
            <ClientRow key={c.id} client={c} active={selected.id === c.id} onClick={() => setSelected(c)}/>
          ))}
          <div style={{ padding: "12px 18px", display: "flex", justifyContent: "space-between", alignItems: "center", fontSize: 12, color: "#94A3B8", borderTop: "1px solid rgba(255,255,255,0.04)" }}>
            <span>Showing 1 to 6 of 6 clients</span>
            <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
              <button style={pgBtn}><Icon name="chevronL" size={12} stroke="#94A3B8"/></button>
              <button style={{...pgBtn, background: "rgba(168,85,247,0.18)", border: "1px solid rgba(168,85,247,0.4)", color: "#C4A8F5"}}>1</button>
              <button style={pgBtn}><Icon name="chevron" size={12} stroke="#94A3B8"/></button>
              <span style={{ marginLeft: 8 }}>10 per page</span>
            </div>
          </div>
        </Card>
      </div>

      <ClientDetail client={selected}/>
    </div>
  );
};

const pgBtn = { width: 26, height: 26, borderRadius: 6, background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.06)", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", fontSize: 11, color: "#94A3B8", fontFamily: "Inter", fontWeight: 600 };

const ClientRow = ({ client, active, onClick }) => {
  const [hover, setHover] = React.useState(false);
  const movieData = client.stream && FluxData.movies.find(m => client.stream.title.includes(m.title));
  return (
    <div onClick={onClick} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)} style={{
      display: "grid", gridTemplateColumns: "1.6fr 1fr 1.1fr 0.9fr 1fr 1.6fr 1fr",
      gap: 12, padding: "12px 18px", alignItems: "center",
      borderTop: "1px solid rgba(255,255,255,0.03)",
      background: active ? "rgba(168,85,247,0.08)" : (hover ? "rgba(255,255,255,0.02)" : "transparent"),
      cursor: "pointer",
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{ width: 28, height: 28, borderRadius: 7, background: "rgba(255,255,255,0.04)", display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Icon name={client.platformIcon} size={14} stroke="#94A3B8"/>
        </div>
        <div style={{ minWidth: 0 }}>
          <div style={{ fontSize: 12.5, color: "#E2E8F0", fontWeight: 600 }}>{client.name}</div>
          <div style={{ fontSize: 10.5, color: "#64748B" }}>{client.os}</div>
        </div>
      </div>
      <div style={{ fontSize: 12, color: "#94A3B8", display: "flex", alignItems: "center", gap: 6 }}>
        <Icon name={client.type === "Mobile" ? "iphone" : client.type === "Tablet" ? "tablet" : client.type === "TV" ? "tv" : "desktop"} size={12} stroke="#64748B"/>
        {client.type}
      </div>
      <div style={{ fontSize: 12, color: "#94A3B8", fontFamily: "JetBrains Mono" }}>{client.ip}</div>
      <div><Pill color={client.status === "online" ? "success" : client.status === "idle" ? "warning" : "neutral"}>{client.status[0].toUpperCase()+client.status.slice(1)}</Pill></div>
      <div style={{ fontSize: 12, color: client.lastActive === "Now" ? "#10B981" : "#94A3B8" }}>{client.lastActive}</div>
      <div>
        {client.stream ? (
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <div style={{ width: 28, height: 36, borderRadius: 4, background: movieData?.art || "linear-gradient(135deg, #1a0f2e, #6b3aa6)", flexShrink: 0 }}/>
            <div style={{ minWidth: 0 }}>
              <div style={{ fontSize: 11.5, color: "#E2E8F0", fontWeight: 500, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{client.stream.title}</div>
              <div style={{ fontSize: 10, color: "#A855F7", marginTop: 1 }}>{client.stream.quality}</div>
            </div>
          </div>
        ) : <span style={{ color: "#475569" }}>—</span>}
      </div>
      <div style={{ display: "flex", justifyContent: "flex-end", gap: 4 }}>
        <button style={iconBtn}><Icon name="eye" size={12} stroke="#94A3B8"/></button>
        <button style={iconBtn}><Icon name="stop" size={12} stroke="#94A3B8"/></button>
        <button style={iconBtn}><Icon name="moreH" size={12} stroke="#94A3B8"/></button>
      </div>
    </div>
  );
};

const iconBtn = { width: 26, height: 26, borderRadius: 6, background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.05)", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" };

const ClientDetail = ({ client }) => {
  return (
    <div style={{ width: 300, flexShrink: 0, borderLeft: "1px solid rgba(255,255,255,0.05)", background: "rgba(13,11,28,0.5)", overflow: "auto", padding: 20 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
        <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Client Details</div>
        <Icon name="x" size={14} stroke="#64748B"/>
      </div>

      <div style={{
        background: "rgba(168,85,247,0.10)",
        border: "1px solid rgba(168,85,247,0.2)",
        borderRadius: 12,
        padding: 16, textAlign: "center", marginBottom: 16,
      }}>
        <div style={{
          width: 56, height: 56, borderRadius: 12,
          background: "rgba(168,85,247,0.18)",
          margin: "0 auto 10px",
          display: "flex", alignItems: "center", justifyContent: "center",
        }}>
          <Icon name={client.platformIcon} size={26} stroke="#C4A8F5"/>
        </div>
        <div style={{ fontSize: 16, fontWeight: 700, color: "#F1F5F9" }}>{client.name}</div>
        <div style={{ display: "inline-flex", alignItems: "center", gap: 5, marginTop: 4, fontSize: 11, color: "#10B981" }}>
          <StatusDot status={client.status} size={6}/> {client.status[0].toUpperCase()+client.status.slice(1)}
        </div>
      </div>

      {[
        ["Device Type", client.type],
        ["OS", client.os],
        ["IP Address", client.ip],
        ["First Connected", client.firstConn || "May 18, 2025 10:15 AM"],
        ["Last Active", client.lastActive],
        ["Total Sessions", client.sessions || "12"],
        ["Total Watch Time", client.watchTime || "18h 45m"],
      ].map(([k, v], i) => (
        <div key={i} style={{ display: "flex", justifyContent: "space-between", padding: "7px 0", fontSize: 12, borderBottom: i < 6 ? "1px solid rgba(255,255,255,0.04)" : "none" }}>
          <span style={{ color: "#94A3B8" }}>{k}</span>
          <span style={{ color: "#E2E8F0", fontWeight: 500, fontFamily: k.includes("IP") ? "JetBrains Mono" : "Inter" }}>{v}</span>
        </div>
      ))}

      {client.stream && (
        <div style={{ marginTop: 16 }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: "#F1F5F9", marginBottom: 10 }}>Active Session</div>
          <div style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.05)", borderRadius: 8, padding: 12 }}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 8 }}>
              <span style={{ fontSize: 12, color: "#E2E8F0", fontWeight: 600 }}>{client.stream.title}</span>
              <Pill color="purple">{client.stream.quality}</Pill>
            </div>
            <Progress value={client.stream.progress}/>
            <div style={{ fontSize: 10.5, color: "#64748B", marginTop: 6, fontFamily: "JetBrains Mono" }}>00:45:12 / 02:28:07</div>
          </div>
        </div>
      )}

      <div style={{ marginTop: 16 }}>
        <div style={{ fontSize: 12, fontWeight: 600, color: "#F1F5F9", marginBottom: 10 }}>Client Actions</div>
        {[
          { icon: "msg", label: "Send Message", color: "#94A3B8" },
          { icon: "x", label: "Disconnect Client", color: "#F87171" },
          { icon: "block", label: "Block Client", color: "#F87171" },
          { icon: "history2", label: "View Playback History", color: "#94A3B8" },
        ].map((a, i) => (
          <div key={i} style={{ display: "flex", alignItems: "center", gap: 10, padding: "8px 10px", background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.04)", borderRadius: 7, marginBottom: 4, cursor: "pointer", fontSize: 12.5, color: a.color }}>
            <Icon name={a.icon} size={13} stroke={a.color}/>
            <span>{a.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

window.ClientsScreen = ClientsScreen;

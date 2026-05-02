// ── Notifications panel (slide-out) ────────────────────────────────────
const NotificationsPanel = ({ open, onClose }) => {
  if (!open) return null;
  const groups = [
    { label: "Today", items: [
      { icon: "play",     color: "#A855F7", title: "Sarah started watching",   sub: "Inception (1080p HDR) on iPhone 14 Pro", time: "12 min ago", unread: true },
      { icon: "warn",     color: "#F59E0B", title: "Bandwidth limit reached",  sub: "Server Network · 950/1000 Mbps",          time: "34 min ago", unread: true },
      { icon: "user",     color: "#10B981", title: "New device registered",    sub: "Apple TV 4K · 192.168.1.108",              time: "2h ago",     unread: true },
    ]},
    { label: "Yesterday", items: [
      { icon: "check",    color: "#10B981", title: "Library scan completed",   sub: "Added 12 new items to Movies",             time: "Yesterday, 23:00" },
      { icon: "refresh",  color: "#3B82F6", title: "Auto-update available",    sub: "Fluxora 1.0.1 ready to install",            time: "Yesterday, 20:14" },
      { icon: "shield",   color: "#F87171", title: "Failed login attempt",     sub: "Unknown · 85.214.62.10 · Germany",          time: "Yesterday, 09:42" },
    ]},
    { label: "Earlier", items: [
      { icon: "zap",      color: "#A855F7", title: "Welcome to Plus!",         sub: "Your subscription is active",                time: "May 19" },
      { icon: "info",     color: "#94A3B8", title: "Backup completed",         sub: "742 GB synced to S3 bucket",                  time: "May 18" },
    ]},
  ];
  return (
    <div onClick={onClose} style={{ position: "fixed", inset: 0, zIndex: 90, background: "rgba(2,1,8,0.5)", backdropFilter: "blur(2px)" }}>
      <div onClick={e => e.stopPropagation()} style={{
        position: "absolute", top: 0, right: 0, bottom: 0, width: 420,
        background: "linear-gradient(180deg, rgba(20,12,40,0.98), rgba(15,8,32,0.98))",
        borderLeft: "1px solid rgba(168,85,247,0.18)",
        boxShadow: "-12px 0 48px rgba(0,0,0,0.5)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "18px 20px", borderBottom: "1px solid rgba(255,255,255,0.05)", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <Icon name="bell" size={16} stroke="#A855F7"/>
            <span style={{ fontSize: 15, fontWeight: 700, color: "#F1F5F9" }}>Notifications</span>
            <span style={{ padding: "2px 7px", background: "rgba(168,85,247,0.2)", border: "1px solid rgba(168,85,247,0.4)", borderRadius: 999, fontSize: 10, fontWeight: 700, color: "#E9D5FF" }}>3 new</span>
          </div>
          <div style={{ display: "flex", gap: 4 }}>
            <button style={{ ...iconBtnSub, width: 30, height: 30 }}><Icon name="check" size={13} stroke="#94A3B8"/></button>
            <button onClick={onClose} style={{ ...iconBtnSub, width: 30, height: 30 }}><Icon name="x" size={13} stroke="#94A3B8"/></button>
          </div>
        </div>
        <div style={{ padding: "8px 14px", borderBottom: "1px solid rgba(255,255,255,0.04)", display: "flex", gap: 4 }}>
          {["All","Unread","Streaming","Security","System"].map((t, i) => (
            <span key={t} style={{ padding: "5px 10px", background: i === 0 ? "rgba(168,85,247,0.15)" : "transparent", borderRadius: 6, fontSize: 11.5, color: i === 0 ? "#E9D5FF" : "#94A3B8", fontWeight: 500, cursor: "pointer" }}>{t}</span>
          ))}
        </div>
        <div style={{ flex: 1, overflow: "auto" }}>
          {groups.map(g => (
            <div key={g.label}>
              <div style={{ padding: "10px 20px 6px", fontSize: 10.5, fontWeight: 700, color: "#64748B", letterSpacing: 1, textTransform: "uppercase" }}>{g.label}</div>
              {g.items.map((n, i) => (
                <div key={i} style={{ padding: "12px 20px", display: "flex", gap: 12, borderTop: "1px solid rgba(255,255,255,0.03)", cursor: "pointer", position: "relative" }}>
                  {n.unread && <span style={{ position: "absolute", top: 18, left: 8, width: 6, height: 6, borderRadius: "50%", background: "#A855F7" }}/>}
                  <div style={{ width: 32, height: 32, borderRadius: 7, background: `${n.color}1c`, border: `1px solid ${n.color}3c`, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                    <Icon name={n.icon} size={13} stroke={n.color}/>
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 12.5, fontWeight: 600, color: "#F1F5F9" }}>{n.title}</div>
                    <div style={{ fontSize: 11.5, color: "#94A3B8", marginTop: 2, lineHeight: 1.45 }}>{n.sub}</div>
                    <div style={{ fontSize: 10.5, color: "#64748B", marginTop: 4, fontFamily: "JetBrains Mono" }}>{n.time}</div>
                  </div>
                </div>
              ))}
            </div>
          ))}
        </div>
        <div style={{ padding: "12px 20px", borderTop: "1px solid rgba(255,255,255,0.05)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <a style={{ fontSize: 11.5, color: "#A855F7", cursor: "pointer", fontWeight: 500 }}>Notification Settings</a>
          <a style={{ fontSize: 11.5, color: "#94A3B8", cursor: "pointer", fontWeight: 500 }}>Mark all as read</a>
        </div>
      </div>
    </div>
  );
};

window.NotificationsPanel = NotificationsPanel;

// ── Sidebar ────────────────────────────────────────────────────────────
const Sidebar = ({ active, onNav }) => {
  const items = [
    { id: "dashboard",   label: "Dashboard",   icon: "dashboard" },
    { id: "library",     label: "Library",     icon: "library" },
    { id: "clients",     label: "Clients",     icon: "clients" },
    { id: "groups",      label: "Groups",      icon: "groups" },
    { id: "activity",    label: "Activity",    icon: "activity" },
    { id: "transcoding", label: "Transcoding", icon: "transcode" },
    { id: "logs",        label: "Logs",        icon: "logs" },
    { id: "settings",    label: "Settings",    icon: "settings" },
    { id: "subscription",label: "Subscription",icon: "crown" },
  ];

  return (
    <aside style={{
      width: 232, flexShrink: 0,
      background: "rgba(13,11,28,0.7)",
      borderRight: "1px solid rgba(255,255,255,0.05)",
      display: "flex", flexDirection: "column",
      backdropFilter: "blur(20px)",
    }}>
      {/* Logo */}
      <div style={{ padding: "20px 18px 16px", display: "flex", alignItems: "center", gap: 11 }}>
        <FluxoraMark size={32}/>
        <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
          <FluxoraWordmark height={14}/>
          <span style={{ fontSize: 9.5, color: "#64748B", letterSpacing: 0.3 }}>Stream. Sync. Anywhere.</span>
        </div>
      </div>

      {/* Nav */}
      <div style={{ padding: "8px 10px", flex: 1, overflowY: "auto" }}>
        <nav style={{ display: "flex", flexDirection: "column", gap: 1 }}>
          {items.map(it => <NavItem key={it.id} item={it} active={active === it.id} onClick={() => onNav(it.id)}/>)}
        </nav>
      </div>

      {/* System Status */}
      <div style={{ padding: "0 16px 12px" }}>
        <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: "0.14em", color: "#64748B", textTransform: "uppercase", marginBottom: 10 }}>
          System Status
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12, color: "#E2E8F0", fontWeight: 600 }}>Server Running</div>
              <div style={{ fontSize: 10.5, color: "#64748B", marginTop: 2 }}>Uptime: 2h 45m 12s</div>
            </div>
            <StatusDot status="active"/>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12, color: "#E2E8F0", fontWeight: 600, display: "flex", alignItems: "center", gap: 6 }}>
                <Icon name="wifi" size={11} stroke="#94A3B8"/> LAN Mode
              </div>
              <div style={{ fontSize: 10.5, color: "#64748B", marginTop: 2, fontFamily: "JetBrains Mono" }}>192.168.1.105</div>
            </div>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12, color: "#E2E8F0", fontWeight: 600, display: "flex", alignItems: "center", gap: 6 }}>
                <Icon name="globe" size={11} stroke="#94A3B8"/> Internet Access
              </div>
              <div style={{ fontSize: 10.5, color: "#10B981", marginTop: 2 }}>Connected</div>
            </div>
            <StatusDot status="online"/>
          </div>
        </div>
      </div>

      {/* Upgrade card */}
      <div style={{ padding: "0 12px 12px" }}>
        <div style={{
          padding: 14,
          borderRadius: 10,
          background: "linear-gradient(135deg, rgba(168,85,247,0.18), rgba(139,92,246,0.08))",
          border: "1px solid rgba(168,85,247,0.3)",
        }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: "#C4A8F5", marginBottom: 4 }}>Upgrade to Pro</div>
          <div style={{ fontSize: 11, color: "#94A3B8", lineHeight: 1.45, marginBottom: 12 }}>
            Unlock premium features and experience Fluxora without limits
          </div>
          <button onClick={() => onNav("subscription")} style={{
            width: "100%",
            padding: "7px 12px",
            background: "rgba(255,255,255,0.04)",
            border: "1px solid rgba(168,85,247,0.4)",
            borderRadius: 7, color: "#E2E8F0",
            fontSize: 12, fontWeight: 600, cursor: "pointer",
            display: "flex", alignItems: "center", justifyContent: "center", gap: 6,
            fontFamily: "Inter",
          }}>
            View Plans <Icon name="chevron" size={12}/>
          </button>
        </div>
      </div>

      {/* User footer */}
      <button onClick={() => onNav("profile")} style={{
        padding: "10px 14px",
        borderTop: "1px solid rgba(255,255,255,0.05)",
        display: "flex", alignItems: "center", gap: 10,
        background: active === "profile" ? "rgba(168,85,247,0.10)" : "transparent",
        border: "none", cursor: "pointer", textAlign: "left", fontFamily: "Inter",
      }}>
        <div style={{
          width: 32, height: 32, borderRadius: "50%",
          background: "linear-gradient(135deg, #A855F7, #6366F1)",
          display: "flex", alignItems: "center", justifyContent: "center",
          fontSize: 11, fontWeight: 700, color: "white",
        }}>A</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 12.5, color: "#E2E8F0", fontWeight: 600 }}>Admin</div>
          <div style={{ fontSize: 10.5, color: "#64748B" }}>admin@fluxora.local</div>
        </div>
        <Icon name="chevronD" size={13} stroke="#475569"/>
      </button>
    </aside>
  );
};

const NavItem = ({ item, active, onClick }) => {
  const [hover, setHover] = React.useState(false);
  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        background: active ? "rgba(168,85,247,0.14)" : (hover ? "rgba(255,255,255,0.03)" : "transparent"),
        color: active ? "#E9D5FF" : (hover ? "#E2E8F0" : "#94A3B8"),
        border: active ? "1px solid rgba(168,85,247,0.3)" : "1px solid transparent",
        borderRadius: 8,
        padding: "9px 12px",
        display: "flex", alignItems: "center", gap: 11,
        fontSize: 13, fontWeight: active ? 600 : 500,
        cursor: "pointer", textAlign: "left",
        transition: "all 100ms ease",
        fontFamily: "Inter",
      }}>
      <Icon name={item.icon} size={16} stroke={active ? "#C4A8F5" : "currentColor"}/>
      <span>{item.label}</span>
    </button>
  );
};

window.Sidebar = Sidebar;

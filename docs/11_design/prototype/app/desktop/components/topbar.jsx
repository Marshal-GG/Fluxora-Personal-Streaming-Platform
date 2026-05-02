// ── Top header (title + actions) ───────────────────────────────────────
const PageHeader = ({ title, subtitle, search, actions }) => (
  <div style={{
    padding: "20px 28px 16px",
    display: "flex", alignItems: "center", gap: 18,
    flexShrink: 0,
  }}>
    <div style={{ flex: 1, minWidth: 0 }}>
      <h1 style={{
        fontSize: 24, fontWeight: 700, color: "#F1F5F9",
        letterSpacing: "-0.02em", lineHeight: 1.2, margin: 0,
      }}>{title}</h1>
      {subtitle && <div style={{ fontSize: 13, color: "#94A3B8", marginTop: 4 }}>{subtitle}</div>}
    </div>
    {search && (
      <div style={{
        position: "relative", width: 280,
      }}>
        <Icon name="search" size={14} stroke="#64748B" style={{ position: "absolute", left: 12, top: 10 }}/>
        <input placeholder={search}
          style={{
            width: "100%",
            background: "rgba(20,18,38,0.7)",
            border: "1px solid rgba(255,255,255,0.06)",
            borderRadius: 8,
            padding: "8px 12px 8px 36px",
            color: "#E2E8F0",
            fontSize: 12.5,
            fontFamily: "Inter",
            outline: "none",
          }}/>
        <span style={{
          position: "absolute", right: 10, top: 7,
          fontFamily: "JetBrains Mono", fontSize: 10, fontWeight: 600,
          padding: "2px 6px", background: "rgba(255,255,255,0.06)",
          borderRadius: 4, color: "#94A3B8",
        }}>Ctrl K</span>
      </div>
    )}
    {actions}
  </div>
);

// ── Status bar footer ──────────────────────────────────────────────────
const StatusBar = ({ tick }) => {
  const cpu = 18 + Math.sin(tick/8)*2;
  return (
    <div style={{
      height: 36, flexShrink: 0,
      borderTop: "1px solid rgba(255,255,255,0.05)",
      background: "rgba(8,6,18,0.8)",
      display: "flex", alignItems: "center", padding: "0 18px", gap: 24,
      fontSize: 11.5, color: "#94A3B8",
      fontFamily: "JetBrains Mono",
    }}>
      <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
        <Icon name="activity" size={12} stroke="#A855F7"/>
        <span>CPU: <span style={{ color: "#E2E8F0", fontWeight: 600 }}>{cpu.toFixed(0)}%</span></span>
      </span>
      <span style={{ color: "#1E293B" }}>│</span>
      <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
        <Icon name="server" size={12} stroke="#94A3B8"/>
        <span>Memory: <span style={{ color: "#E2E8F0", fontWeight: 600 }}>4.2 GB / 16 GB</span></span>
      </span>
      <span style={{ flex: 1 }}/>
      <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
        <Icon name="wifi" size={12} stroke="#94A3B8"/> LAN Mode
      </span>
      <span style={{ color: "#1E293B" }}>│</span>
      <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
        Network:
        <span style={{ color: "#E2E8F0" }}><Icon name="arrowUp" size={10} stroke="#10B981"/> 8.4 Mbps</span>
        <span style={{ color: "#E2E8F0" }}><Icon name="arrowDown" size={10} stroke="#3B82F6"/> 32.1 Mbps</span>
      </span>
      <span style={{ color: "#1E293B" }}>│</span>
      <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
        <StatusDot status="online" size={6}/> Uptime 2h 45m
      </span>
    </div>
  );
};

window.PageHeader = PageHeader;
window.StatusBar = StatusBar;

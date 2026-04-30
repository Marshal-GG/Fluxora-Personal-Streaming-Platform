// ── Reusable UI primitives ─────────────────────────────────────────────
const Card = ({ children, style, hoverable, padding = 20, onClick, glow }) => (
  <div onClick={onClick} className={hoverable ? "hoverable-card" : ""} style={{
    background: "rgba(20,18,38,0.7)",
    border: "1px solid rgba(255,255,255,0.06)",
    borderRadius: 12,
    padding,
    transition: "all 150ms ease",
    cursor: onClick ? "pointer" : "default",
    boxShadow: glow ? "0 0 0 1px rgba(168,85,247,0.25), 0 0 24px rgba(168,85,247,0.10)" : "none",
    ...style,
  }}>{children}</div>
);

const SectionLabel = ({ children, style }) => (
  <div style={{
    fontSize: 11, fontWeight: 600, letterSpacing: "0.14em",
    textTransform: "uppercase", color: "#64748B", marginBottom: 14, ...style,
  }}>{children}</div>
);

const StatusDot = ({ status, size = 8 }) => {
  const colors = { online: "#10B981", active: "#10B981", streaming: "#A855F7", idle: "#F59E0B", pending: "#F59E0B", offline: "#475569", inactive: "#64748B", error: "#EF4444" };
  const c = colors[status] || "#64748B";
  return <span style={{ display: "inline-block", width: size, height: size, borderRadius: "50%", background: c, boxShadow: status === "online" || status === "active" || status === "streaming" ? `0 0 8px ${c}` : "none" }}/>;
};

const Pill = ({ children, color = "neutral", style }) => {
  const palette = {
    neutral: { bg: "rgba(71,85,105,0.18)", fg: "#94A3B8" },
    purple:  { bg: "rgba(168,85,247,0.16)", fg: "#C4A8F5" },
    success: { bg: "rgba(16,185,129,0.15)", fg: "#34D399" },
    warning: { bg: "rgba(245,158,11,0.15)", fg: "#FBBF24" },
    error:   { bg: "rgba(239,68,68,0.15)", fg: "#F87171" },
    info:    { bg: "rgba(59,130,246,0.15)", fg: "#60A5FA" },
    pink:    { bg: "rgba(236,72,153,0.15)", fg: "#F472B6" },
  };
  const p = palette[color] || palette.neutral;
  return <span style={{ display: "inline-flex", alignItems: "center", gap: 6, padding: "3px 10px", borderRadius: 999, background: p.bg, color: p.fg, fontSize: 11, fontWeight: 600, ...style }}>{children}</span>;
};

const Button = ({ children, variant = "primary", size = "md", icon, iconRight, onClick, style, fullWidth }) => {
  const sizes = { sm: { padding: "6px 12px", fontSize: 12 }, md: { padding: "9px 16px", fontSize: 13 }, lg: { padding: "12px 22px", fontSize: 14 } };
  const variants = {
    primary:   { background: "linear-gradient(135deg, #8B5CF6, #A855F7)", color: "white", border: "none", boxShadow: "0 4px 12px rgba(139,92,246,0.3)" },
    secondary: { background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "#E2E8F0" },
    ghost:     { background: "transparent", border: "1px solid transparent", color: "#94A3B8" },
    outline:   { background: "transparent", border: "1px solid rgba(168,85,247,0.4)", color: "#C4A8F5" },
    danger:    { background: "rgba(239,68,68,0.10)", color: "#F87171", border: "1px solid rgba(239,68,68,0.3)" },
    success:   { background: "rgba(16,185,129,0.12)", color: "#34D399", border: "1px solid rgba(16,185,129,0.3)" },
  };
  return (
    <button onClick={onClick} style={{
      display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8,
      borderRadius: 8, fontWeight: 600, cursor: "pointer", fontFamily: "Inter",
      transition: "all 150ms ease", width: fullWidth ? "100%" : "auto",
      ...sizes[size], ...variants[variant], ...style,
    }}>
      {icon && <Icon name={icon} size={size === "sm" ? 13 : 15}/>}
      {children}
      {iconRight && <Icon name={iconRight} size={size === "sm" ? 13 : 15}/>}
    </button>
  );
};

const Progress = ({ value, color = "linear-gradient(90deg, #8B5CF6, #A855F7)", height = 4, track = "rgba(255,255,255,0.06)" }) => (
  <div style={{ background: track, borderRadius: 999, height, width: "100%", overflow: "hidden" }}>
    <div style={{ background: color, height: "100%", width: `${Math.min(100, Math.max(0, value*100))}%`, borderRadius: 999, transition: "width 400ms ease" }}/>
  </div>
);

const StatTile = ({ icon, label, value, sub, color = "#A855F7", iconBg, accent }) => (
  <Card padding={18} style={{ position: "relative" }}>
    <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
      <div style={{
        width: 44, height: 44, borderRadius: 10,
        background: iconBg || `${color}1F`,
        display: "flex", alignItems: "center", justifyContent: "center",
        flexShrink: 0,
      }}>
        <Icon name={icon} size={20} stroke={color}/>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 12, color: "#94A3B8", fontWeight: 500, marginBottom: 2 }}>{label}</div>
        <div style={{ fontSize: 24, fontWeight: 700, color: "#F1F5F9", lineHeight: 1.1, letterSpacing: "-0.01em" }}>{value}</div>
        {sub && <div style={{ fontSize: 11, color: accent || "#10B981", marginTop: 4, fontWeight: 500 }}>{sub}</div>}
      </div>
    </div>
  </Card>
);

const fmt = {
  ago: (s) => s < 60 ? `${Math.floor(s)}s ago` : s < 3600 ? `${Math.floor(s/60)}m ago` : `${Math.floor(s/3600)}h ago`,
};

Object.assign(window, { Card, SectionLabel, StatusDot, Pill, Button, Progress, StatTile, fmt });

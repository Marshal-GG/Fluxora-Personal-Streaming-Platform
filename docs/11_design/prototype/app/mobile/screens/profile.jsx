// ── Profile / Account screen ────────────────────────────────────────────

const ProfileScreen = () => {
  const stats = [
    { label: "Hours", value: "284" },
    { label: "Movies", value: "62" },
    { label: "Shows",  value: "18" },
  ];
  const groups = [
    { icon: "user",       label: "Account",          sub: "alex@fluxora.io" },
    { icon: "creditCard", label: "Subscription",     sub: "Plus · renews Jun 21", pill: "Plus" },
    { icon: "download",   label: "Downloads",        sub: "Quality · auto-delete" },
    { icon: "wifi",       label: "Playback",         sub: "Wi-Fi only · streaming quality" },
    { icon: "globe",      label: "Language & region" },
    { icon: "bell",       label: "Notifications" },
    { icon: "shieldCheck",label: "Privacy & security" },
    { icon: "helpCircle", label: "Help & support" },
    { icon: "info",       label: "About Fluxora",    sub: "v1.0.0 · build 482" },
  ];
  return (
    <div style={{ background: M.bg, height: "100%", display: "flex", flexDirection: "column" }}>
      <div style={{ padding: "12px 16px 6px", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div style={{ fontSize: 26, fontWeight: 800, letterSpacing: -0.6, color: M.fg }}>Profile</div>
        <button style={{
          width: 38, height: 38, borderRadius: 999,
          background: "rgba(255,255,255,0.04)", border: `1px solid ${M.border}`,
          color: M.fg, display: "flex", alignItems: "center", justifyContent: "center",
        }}><Icon name="settings" size={17}/></button>
      </div>

      <div style={{ flex: 1, overflowY: "auto", padding: "10px 16px 24px" }}>
        {/* avatar block */}
        <div style={{
          display: "flex", alignItems: "center", gap: 14, padding: "14px",
          background: "linear-gradient(135deg, rgba(168,85,247,0.18), rgba(34,211,238,0.06))",
          border: `1px solid ${M.borderStrong}`, borderRadius: 16,
        }}>
          <div style={{
            width: 64, height: 64, borderRadius: "50%",
            background: "linear-gradient(135deg, #8B5CF6, #EC4899)",
            display: "flex", alignItems: "center", justifyContent: "center",
            color: "#fff", fontWeight: 700, fontSize: 24, letterSpacing: -0.5,
            boxShadow: "0 8px 22px rgba(139,92,246,0.4)",
          }}>AK</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 17, fontWeight: 700, color: M.fg }}>Alex Kowalski</div>
            <div style={{ fontSize: 12, color: M.fgMuted, marginTop: 2 }}>alex@fluxora.io</div>
            <div style={{ display: "inline-flex", alignItems: "center", gap: 5, marginTop: 7,
              padding: "3px 9px", borderRadius: 999, background: M.accentSoft, color: "#E9D5FF",
              fontSize: 10.5, fontWeight: 700, letterSpacing: 0.3 }}>
              <Icon name="crown" size={10} stroke="#E9D5FF"/> PLUS MEMBER
            </div>
          </div>
        </div>

        {/* stat row */}
        <div style={{
          marginTop: 12, padding: "14px 0",
          background: "rgba(255,255,255,0.03)", border: `1px solid ${M.border}`,
          borderRadius: 12,
          display: "flex",
        }}>
          {stats.map((s, i) => (
            <div key={i} style={{
              flex: 1, textAlign: "center",
              borderRight: i < stats.length - 1 ? `1px solid ${M.border}` : "none",
            }}>
              <div style={{ fontSize: 22, fontWeight: 800, color: M.fg, letterSpacing: -0.5 }}>{s.value}</div>
              <div style={{ fontSize: 10.5, color: M.fgMuted, marginTop: 2, letterSpacing: 0.4, textTransform: "uppercase", fontWeight: 600 }}>{s.label}</div>
            </div>
          ))}
        </div>

        {/* settings list */}
        <div style={{
          marginTop: 14, background: "rgba(255,255,255,0.03)",
          border: `1px solid ${M.border}`, borderRadius: 12, overflow: "hidden",
        }}>
          {groups.map((g, i) => (
            <div key={i} style={{
              display: "flex", alignItems: "center", gap: 14,
              padding: "14px 14px",
              borderBottom: i < groups.length - 1 ? `1px solid ${M.border}` : "none",
            }}>
              <div style={{
                width: 34, height: 34, borderRadius: 9,
                background: M.accentSoft, color: M.accent,
                display: "flex", alignItems: "center", justifyContent: "center",
              }}><Icon name={g.icon} size={16} stroke={M.accent}/></div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13.5, fontWeight: 600, color: M.fg }}>{g.label}</div>
                {g.sub && <div style={{ fontSize: 11.5, color: M.fgMuted, marginTop: 2 }}>{g.sub}</div>}
              </div>
              {g.pill && <span style={{
                fontSize: 10, fontWeight: 700, color: "#E9D5FF",
                padding: "3px 7px", borderRadius: 5, background: M.accentSoft,
                letterSpacing: 0.4,
              }}>{g.pill}</span>}
              <Icon name="chevron" size={15} stroke="#64748B"/>
            </div>
          ))}
        </div>

        <button style={{
          marginTop: 18, width: "100%", padding: "14px",
          background: "rgba(239,68,68,0.10)", border: "1px solid rgba(239,68,68,0.25)",
          color: "#F87171", borderRadius: 12, fontSize: 13.5, fontWeight: 600,
          fontFamily: "inherit", cursor: "pointer",
        }}>Sign out</button>
      </div>
    </div>
  );
};

window.ProfileScreen = ProfileScreen;

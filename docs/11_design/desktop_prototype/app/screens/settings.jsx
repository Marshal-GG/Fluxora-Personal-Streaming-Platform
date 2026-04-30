// ── Settings ───────────────────────────────────────────────────────────
const SettingsScreen = () => {
  const [tab, setTab] = React.useState("general");
  const tabs = [
    { id: "general",  label: "General",   icon: "settings" },
    { id: "network",  label: "Network",   icon: "wifi" },
    { id: "streaming",label: "Streaming", icon: "play" },
    { id: "security", label: "Security",  icon: "shield" },
    { id: "advanced", label: "Advanced",  icon: "cogs" },
    { id: "about",    label: "About",     icon: "info" },
  ];
  return (
    <div style={{ overflow: "auto", flex: 1, padding: "0 28px 28px" }}>
      <PageHeader title="Settings" subtitle="Configure your server preferences and system settings" actions={<Button variant="primary" icon="save">Save Changes</Button>}/>

      <div style={{ display: "flex", gap: 8, padding: "0 4px 14px", borderBottom: "1px solid rgba(255,255,255,0.06)", marginBottom: 18 }}>
        {tabs.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)} style={{
            background: "transparent", border: "none",
            padding: "0 6px 12px",
            color: tab === t.id ? "#C4A8F5" : "#94A3B8",
            fontSize: 13, fontWeight: tab === t.id ? 600 : 500, cursor: "pointer",
            borderBottom: tab === t.id ? "2px solid #A855F7" : "2px solid transparent",
            display: "flex", alignItems: "center", gap: 7, marginBottom: -1,
            fontFamily: "Inter",
          }}><Icon name={t.icon} size={13}/>{t.label}</button>
        ))}
      </div>

      {tab === "network"   && <SettingsNetworkTab/>}
      {tab === "streaming" && <SettingsStreamingTab/>}
      {tab === "security"  && <SettingsSecurityTab/>}
      {tab === "advanced"  && <SettingsAdvancedTab/>}
      {tab === "about"     && <SettingsAboutTab/>}
      {tab === "general"   && (
      <div style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 14 }}>
        <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
          <SettingBlock icon="settings" title="General Settings">
            <SField label="Server Name" sub="This name will be visible to other devices" control={<TextField value="Fluxora Server"/>}/>
            <SField label="Language" sub="Choose your preferred language" control={<SelectField value="English"/>}/>
            <SField label="Auto Start on Boot" sub="Start the server automatically when system boots" control={<TToggle on/>}/>
            <SField label="Auto Restart on Crash" sub="Automatically restart the server if it crashes" control={<TToggle on/>}/>
          </SettingBlock>

          <SettingBlock icon="folder" title="Media Library Settings">
            <SField label="Default Library View" sub="Choose how to display your media" control={<SelectField value="Grid View"/>}/>
            <SField label="Scan Library on Startup" sub="Automatically scan for new media files" control={<TToggle on/>}/>
            <SField label="Generate Thumbnails" sub="Generate video thumbnails for better browsing" control={<TToggle on/>}/>
          </SettingBlock>

          <SettingBlock icon="sun" title="Appearance">
            <SField label="Theme" sub="Choose your preferred theme" control={
              <div style={{ display: "flex", gap: 6 }}>
                <ThemeBtn icon="moon" label="Dark" active/>
                <ThemeBtn icon="sun" label="Light"/>
                <ThemeBtn icon="desktop" label="System"/>
              </div>
            }/>
            <SField label="Accent Color" sub="Choose accent color for the application" control={
              <div style={{ display: "flex", gap: 8 }}>
                {["#A855F7", "#3B82F6", "#10B981", "#F59E0B", "#EF4444"].map((c, i) => (
                  <button key={i} style={{
                    width: 28, height: 28, borderRadius: "50%",
                    background: c, border: i === 0 ? "2px solid #fff" : "2px solid transparent",
                    cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center",
                  }}>
                    {i === 0 && <Icon name="check" size={13} stroke="#fff"/>}
                  </button>
                ))}
              </div>
            }/>
          </SettingBlock>
        </div>

        <div>
          <Card padding={18} style={{ marginBottom: 14 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 14 }}>
              <Icon name="server" size={16} stroke="#A855F7"/>
              <span style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>System Information</span>
            </div>
            {[
              ["Server Status", <span style={{ display: "inline-flex", alignItems: "center", gap: 6, color: "#10B981" }}><StatusDot status="online" size={6}/> Running</span>],
              ["Local IP Address", "192.168.1.105"],
              ["Public Address", <span style={{ display:"inline-flex", alignItems:"center", gap:6 }}>103.21.45.67:8443 <Icon name="extLink" size={11} stroke="#A855F7"/></span>],
              ["Uptime", "2h 45m 12s"],
              ["Version", "1.0.0"],
              ["Operating System", "Windows 11 Pro"],
              ["CPU Usage", "18%"],
              ["Memory Usage", "4.2 GB / 16 GB"],
            ].map(([k, v], i) => (
              <div key={i} style={{ display: "flex", justifyContent: "space-between", padding: "7px 0", fontSize: 12, borderBottom: i < 7 ? "1px solid rgba(255,255,255,0.04)" : "none" }}>
                <span style={{ color: "#94A3B8" }}>{k}</span>
                <span style={{ color: "#E2E8F0", fontWeight: 500, fontFamily: typeof v === "string" && v.match(/[\d.]+%|GB|\d+\.\d+\.\d+/) ? "JetBrains Mono" : "Inter" }}>{v}</span>
              </div>
            ))}
          </Card>

          <Card padding={18}>
            <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 14 }}>
              <Icon name="zap" size={16} stroke="#F59E0B"/>
              <span style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Quick Actions</span>
            </div>
            {[
              { icon: "refresh", title: "Restart Server",   sub: "Restart the streaming server" },
              { icon: "trash",   title: "Clear Cache",      sub: "Clear all cached files and thumbnails" },
              { icon: "save",    title: "Backup Settings",  sub: "Export your current settings" },
              { icon: "cogs",    title: "Reset Settings",   sub: "Reset all settings to default" },
            ].map((a, i) => (
              <div key={i} style={{ display: "flex", alignItems: "center", gap: 10, padding: "9px 10px", background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.04)", borderRadius: 7, marginBottom: 5, cursor: "pointer" }}>
                <Icon name={a.icon} size={14} stroke="#94A3B8"/>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 12.5, color: "#E2E8F0", fontWeight: 500 }}>{a.title}</div>
                  <div style={{ fontSize: 10.5, color: "#64748B" }}>{a.sub}</div>
                </div>
                <Icon name="chevron" size={11} stroke="#475569"/>
              </div>
            ))}
          </Card>
        </div>
      </div>
      )}
    </div>
  );
};

const SettingBlock = ({ icon, title, children }) => (
  <Card padding={0}>
    <div style={{ padding: "16px 20px", display: "flex", alignItems: "center", gap: 10, borderBottom: "1px solid rgba(255,255,255,0.04)" }}>
      <Icon name={icon} size={15} stroke="#A855F7"/>
      <span style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>{title}</span>
    </div>
    <div style={{ padding: "8px 0" }}>{children}</div>
  </Card>
);
const SField = ({ label, sub, control }) => (
  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px 20px", gap: 16 }}>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 13, color: "#E2E8F0", fontWeight: 500 }}>{label}</div>
      {sub && <div style={{ fontSize: 11, color: "#64748B", marginTop: 2 }}>{sub}</div>}
    </div>
    {control}
  </div>
);
const TextField = ({ value }) => (
  <input defaultValue={value} style={{
    width: 200, padding: "7px 10px",
    background: "rgba(255,255,255,0.03)",
    border: "1px solid rgba(255,255,255,0.08)",
    borderRadius: 7, color: "#E2E8F0", fontSize: 12.5, outline: "none", fontFamily: "Inter",
  }}/>
);
const SelectField = ({ value }) => (
  <div style={{ width: 200, padding: "7px 10px", background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 7, color: "#E2E8F0", fontSize: 12.5, display: "flex", alignItems: "center", cursor: "pointer" }}>
    <span style={{ flex: 1 }}>{value}</span>
    <Icon name="chevronD" size={12} stroke="#64748B"/>
  </div>
);
const TToggle = ({ on: initial }) => {
  const [on, setOn] = React.useState(initial);
  return (
    <button onClick={() => setOn(!on)} style={{
      width: 38, height: 22, borderRadius: 999,
      background: on ? "linear-gradient(135deg, #8B5CF6, #A855F7)" : "rgba(255,255,255,0.08)",
      border: "none", cursor: "pointer", position: "relative", flexShrink: 0,
    }}>
      <span style={{ position: "absolute", top: 3, left: on ? 19 : 3, width: 16, height: 16, borderRadius: "50%", background: "#fff", transition: "left 200ms" }}/>
    </button>
  );
};
const ThemeBtn = ({ icon, label, active }) => (
  <div style={{
    display: "flex", alignItems: "center", gap: 6, padding: "6px 12px",
    background: active ? "rgba(168,85,247,0.18)" : "rgba(255,255,255,0.03)",
    border: active ? "1px solid rgba(168,85,247,0.4)" : "1px solid rgba(255,255,255,0.08)",
    borderRadius: 7, color: active ? "#C4A8F5" : "#94A3B8", fontSize: 12, fontWeight: 500, cursor: "pointer",
  }}>
    <Icon name={icon} size={12}/>{label}
  </div>
);

window.SettingsScreen = SettingsScreen;

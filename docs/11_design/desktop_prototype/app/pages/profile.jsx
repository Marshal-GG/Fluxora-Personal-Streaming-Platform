// ── Profile / Account ──────────────────────────────────────────────────
const ProfileScreen = ({ onNav }) => {
  const [tab, setTab] = React.useState("profile");
  const tabs = [
    { id:"profile",  label:"Profile",       icon:"user" },
    { id:"security", label:"Security",      icon:"shield" },
    { id:"prefs",    label:"Preferences",   icon:"settings" },
    { id:"sessions", label:"Active Sessions", icon:"desktop" },
    { id:"danger",   label:"Danger Zone",   icon:"info" },
  ];
  return (
    <div style={{ overflow: "auto", flex: 1, padding: "0 28px 28px" }}>
      <PageHeader title="Account" subtitle="Manage your profile, security and preferences" actions={<Button variant="primary" icon="save">Save Changes</Button>}/>

      <div style={{ display: "grid", gridTemplateColumns: "240px 1fr", gap: 18 }}>
        <Card padding={0}>
          <div style={{ padding: "20px 18px 18px", textAlign: "center", borderBottom: "1px solid rgba(255,255,255,0.04)" }}>
            <div style={{
              width: 84, height: 84, borderRadius: "50%", margin: "0 auto 10px",
              background: "linear-gradient(135deg, #A855F7, #6366F1, #06B6D4)",
              display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: 30, fontWeight: 700, color: "#fff",
              border: "3px solid rgba(168,85,247,0.3)",
              boxShadow: "0 8px 24px rgba(168,85,247,0.25)",
            }}>A</div>
            <div style={{ fontSize: 15, fontWeight: 700, color: "#F1F5F9" }}>Admin User</div>
            <div style={{ fontSize: 11.5, color: "#64748B" }}>admin@fluxora.local</div>
            <div style={{ marginTop: 10 }}><Pill color="purple">Plus Plan · Owner</Pill></div>
          </div>
          <div style={{ padding: 8 }}>
            {tabs.map(t => (
              <button key={t.id} onClick={() => setTab(t.id)} style={{
                background: tab === t.id ? "rgba(168,85,247,0.14)" : "transparent",
                color: tab === t.id ? "#E9D5FF" : "#94A3B8",
                border: tab === t.id ? "1px solid rgba(168,85,247,0.3)" : "1px solid transparent",
                borderRadius: 7, padding: "8px 12px", display: "flex", alignItems: "center", gap: 10,
                fontSize: 12.5, fontWeight: tab === t.id ? 600 : 500,
                cursor: "pointer", textAlign: "left", width: "100%",
                fontFamily: "Inter", marginBottom: 2,
              }}>
                <Icon name={t.icon} size={14}/>{t.label}
              </button>
            ))}
          </div>
        </Card>

        <div>
          {tab === "profile"  && <ProfileTab/>}
          {tab === "security" && <SecurityTab/>}
          {tab === "prefs"    && <PrefsTab/>}
          {tab === "sessions" && <SessionsTab/>}
          {tab === "danger"   && <DangerTab/>}
        </div>
      </div>
    </div>
  );
};

const ProfileTab = () => (
  <Card padding={0}>
    <div style={{ padding: "16px 22px", borderBottom: "1px solid rgba(255,255,255,0.04)" }}>
      <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Profile Information</div>
      <div style={{ fontSize: 12, color: "#64748B", marginTop: 2 }}>Update your personal details and contact information</div>
    </div>
    <div style={{ padding: 22 }}>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14, marginBottom: 14 }}>
        <Field label="Display Name"  value="Admin User"/>
        <Field label="Username"      value="admin" mono/>
        <Field label="Email"         value="admin@fluxora.local"/>
        <Field label="Phone"         value="+1 (555) 0123"/>
      </div>
      <div style={{ marginBottom: 14 }}>
        <div style={{ fontSize: 11.5, color: "#94A3B8", marginBottom: 6, fontWeight: 500 }}>Bio</div>
        <textarea defaultValue="Server admin and self-hosting enthusiast. Running Fluxora on a custom rig with NVENC transcoding."
          style={{ width: "100%", minHeight: 80, padding: 12, background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 7, color: "#E2E8F0", fontSize: 12.5, outline: "none", fontFamily: "Inter", resize: "vertical" }}/>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
        <Field label="Time Zone" value="America/Los_Angeles" select/>
        <Field label="Country"   value="United States" select/>
      </div>
    </div>
  </Card>
);

const SecurityTab = () => (
  <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
    <Card padding={0}>
      <div style={{ padding: "16px 22px", borderBottom: "1px solid rgba(255,255,255,0.04)" }}>
        <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Password</div>
        <div style={{ fontSize: 12, color: "#64748B", marginTop: 2 }}>Last changed 47 days ago</div>
      </div>
      <div style={{ padding: 22, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
        <Field label="Current Password" value="••••••••••••" type="password"/>
        <div/>
        <Field label="New Password" value="" type="password"/>
        <Field label="Confirm New Password" value="" type="password"/>
        <div style={{ gridColumn: "1 / -1" }}>
          <Button variant="primary">Change Password</Button>
        </div>
      </div>
    </Card>

    <Card padding={0}>
      <div style={{ padding: "16px 22px", borderBottom: "1px solid rgba(255,255,255,0.04)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Two-Factor Authentication</div>
          <div style={{ fontSize: 12, color: "#64748B", marginTop: 2 }}>Add an extra layer of security</div>
        </div>
        <Pill color="success">Enabled</Pill>
      </div>
      <div style={{ padding: 22 }}>
        <div style={{ display: "flex", gap: 14, marginBottom: 16 }}>
          <div style={{ width: 140, height: 140, borderRadius: 10, background: "rgba(255,255,255,0.06)", padding: 12, flexShrink: 0 }}>
            <QRPattern/>
          </div>
          <div>
            <div style={{ fontSize: 12.5, color: "#E2E8F0", fontWeight: 500, marginBottom: 6 }}>Authenticator App</div>
            <div style={{ fontSize: 11.5, color: "#94A3B8", lineHeight: 1.5, marginBottom: 10 }}>Scan with Authy, 1Password, or Google Authenticator</div>
            <div style={{ fontFamily: "JetBrains Mono", fontSize: 11, color: "#A855F7", padding: "6px 10px", background: "rgba(168,85,247,0.08)", borderRadius: 6, display: "inline-block" }}>FLUX-X4Y2-9KQ7-MN3R</div>
            <div style={{ display: "flex", gap: 6, marginTop: 12 }}>
              <Button variant="secondary" size="sm" icon="refresh">Regenerate</Button>
              <Button variant="ghost" size="sm">View backup codes</Button>
            </div>
          </div>
        </div>
        <SwitchRow label="SMS backup" sub="Receive a one-time code via text" on/>
        <SwitchRow label="Hardware key (WebAuthn)" sub="YubiKey or Touch ID" on={false}/>
      </div>
    </Card>

    <Card padding={0}>
      <div style={{ padding: "16px 22px", borderBottom: "1px solid rgba(255,255,255,0.04)" }}>
        <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Recent Login Activity</div>
      </div>
      {[
        ["MacBook Air · Chrome", "192.168.1.104", "Now",          "United States",  "online"],
        ["iPhone 14 Pro · Fluxora App", "103.21.45.67", "2h ago",   "United States",  "online"],
        ["Windows · Edge",       "192.168.1.103", "Yesterday",    "United States",  "offline"],
        ["Unknown · Firefox",    "85.214.62.10",  "May 19, 09:42","Germany",        "offline"],
      ].map(([d, ip, t, c, s], i) => (
        <div key={i} style={{ padding: "12px 22px", display: "grid", gridTemplateColumns: "2fr 1fr 1fr 1fr 0.6fr", gap: 12, borderTop: "1px solid rgba(255,255,255,0.03)", fontSize: 12.5, alignItems: "center" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <StatusDot status={s} size={6}/>
            <span style={{ color: "#E2E8F0", fontWeight: 500 }}>{d}</span>
          </div>
          <span style={{ color: "#94A3B8", fontFamily: "JetBrains Mono" }}>{ip}</span>
          <span style={{ color: "#94A3B8" }}>{t}</span>
          <span style={{ color: "#94A3B8" }}>{c}</span>
          <a style={{ color: "#F87171", fontSize: 11.5, textAlign: "right", cursor: "pointer", fontWeight: 500 }}>Revoke</a>
        </div>
      ))}
    </Card>
  </div>
);

const PrefsTab = () => (
  <Card padding={0}>
    <div style={{ padding: "16px 22px", borderBottom: "1px solid rgba(255,255,255,0.04)" }}>
      <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Preferences</div>
    </div>
    <div style={{ padding: "8px 0" }}>
      <SwitchRow label="Email notifications" sub="Receive product news and updates" on/>
      <SwitchRow label="Weekly activity digest" sub="Sent every Monday at 9am" on/>
      <SwitchRow label="Show watch progress in sidebar" sub="Display continue-watching items" on/>
      <SwitchRow label="Auto-play next episode" sub="When watching TV shows" on={false}/>
      <SwitchRow label="Beta features" sub="Try experimental features early" on={false}/>
    </div>
  </Card>
);

const SessionsTab = () => (
  <Card padding={0}>
    <div style={{ padding: "16px 22px", borderBottom: "1px solid rgba(255,255,255,0.04)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
      <div>
        <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Active Sessions</div>
        <div style={{ fontSize: 12, color: "#64748B", marginTop: 2 }}>Devices currently signed in to your account</div>
      </div>
      <Button variant="danger" size="sm" icon="x">Sign out everywhere</Button>
    </div>
    {[
      ["MacBook Air", "macOS · Chrome 124",       "192.168.1.104", "Current session", true],
      ["iPhone 14 Pro", "Fluxora iOS · v1.0.0",  "103.21.45.67",  "2 hours ago",     false],
      ["iPad Pro",     "iPadOS · Safari",         "192.168.1.105", "Yesterday",       false],
      ["Apple TV",     "tvOS · Fluxora 1.0",      "192.168.1.108", "May 19",          false],
    ].map(([dev, meta, ip, when, current], i) => (
      <div key={i} style={{ display: "grid", gridTemplateColumns: "1.5fr 1.4fr 1fr 1fr 0.6fr", gap: 14, padding: "14px 22px", borderTop: "1px solid rgba(255,255,255,0.03)", alignItems: "center", fontSize: 12.5 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <Icon name={i === 1 ? "iphone" : i === 2 ? "tablet" : i === 3 ? "tv" : "laptop"} size={16} stroke="#A855F7"/>
          <div>
            <div style={{ color: "#E2E8F0", fontWeight: 600 }}>{dev}</div>
            {current && <div style={{ fontSize: 10.5, color: "#10B981", marginTop: 2 }}>● Current</div>}
          </div>
        </div>
        <span style={{ color: "#94A3B8" }}>{meta}</span>
        <span style={{ color: "#94A3B8", fontFamily: "JetBrains Mono" }}>{ip}</span>
        <span style={{ color: "#94A3B8" }}>{when}</span>
        <div style={{ textAlign: "right" }}>{!current && <a style={{ color: "#F87171", fontSize: 11.5, cursor: "pointer", fontWeight: 500 }}>Revoke</a>}</div>
      </div>
    ))}
  </Card>
);

const DangerTab = () => (
  <Card padding={0} style={{ borderColor: "rgba(239,68,68,0.2)" }}>
    <div style={{ padding: "16px 22px", borderBottom: "1px solid rgba(239,68,68,0.2)", background: "rgba(239,68,68,0.05)" }}>
      <div style={{ fontSize: 14, fontWeight: 600, color: "#F87171" }}>Danger Zone</div>
      <div style={{ fontSize: 12, color: "#94A3B8", marginTop: 2 }}>Irreversible and destructive actions</div>
    </div>
    {[
      { title: "Export Account Data", sub: "Download all your data as a ZIP archive", btn: "Export", variant: "outline" },
      { title: "Reset All Preferences", sub: "Restore default settings without deleting data", btn: "Reset", variant: "outline" },
      { title: "Transfer Ownership", sub: "Move server ownership to another user", btn: "Transfer", variant: "outline" },
      { title: "Delete Account", sub: "Permanently delete your account and all associated data", btn: "Delete Account", variant: "danger" },
    ].map((a, i) => (
      <div key={i} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "14px 22px", borderTop: "1px solid rgba(255,255,255,0.04)", gap: 14 }}>
        <div>
          <div style={{ fontSize: 13, color: "#E2E8F0", fontWeight: 600 }}>{a.title}</div>
          <div style={{ fontSize: 11.5, color: "#64748B", marginTop: 2 }}>{a.sub}</div>
        </div>
        <Button variant={a.variant} size="sm">{a.btn}</Button>
      </div>
    ))}
  </Card>
);

const Field = ({ label, value, mono, type = "text", select }) => (
  <div>
    <div style={{ fontSize: 11.5, color: "#94A3B8", marginBottom: 6, fontWeight: 500 }}>{label}</div>
    {select ? (
      <div style={{ padding: "9px 12px", background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 7, fontSize: 12.5, color: "#E2E8F0", display: "flex", alignItems: "center", cursor: "pointer" }}>
        <span style={{ flex: 1 }}>{value}</span>
        <Icon name="chevronD" size={12} stroke="#64748B"/>
      </div>
    ) : (
      <input defaultValue={value} type={type} style={{ width: "100%", padding: "9px 12px", background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 7, color: "#E2E8F0", fontSize: 12.5, outline: "none", fontFamily: mono ? "JetBrains Mono" : "Inter" }}/>
    )}
  </div>
);

const SwitchRow = ({ label, sub, on: initial }) => {
  const [on, setOn] = React.useState(initial);
  return (
    <div style={{ padding: "12px 22px", display: "flex", alignItems: "center", gap: 16, borderTop: "1px solid rgba(255,255,255,0.03)" }}>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 12.5, color: "#E2E8F0", fontWeight: 500 }}>{label}</div>
        {sub && <div style={{ fontSize: 11, color: "#64748B", marginTop: 2 }}>{sub}</div>}
      </div>
      <button onClick={() => setOn(!on)} style={{
        width: 38, height: 22, borderRadius: 999,
        background: on ? "linear-gradient(135deg, #8B5CF6, #A855F7)" : "rgba(255,255,255,0.08)",
        border: "none", cursor: "pointer", position: "relative", flexShrink: 0,
      }}>
        <span style={{ position: "absolute", top: 3, left: on ? 19 : 3, width: 16, height: 16, borderRadius: "50%", background: "#fff", transition: "left 200ms" }}/>
      </button>
    </div>
  );
};

const QRPattern = () => {
  const cells = 11;
  const data = React.useMemo(() => Array.from({ length: cells*cells }, () => Math.random() > 0.55), []);
  return (
    <div style={{ width: "100%", height: "100%", display: "grid", gridTemplateColumns: `repeat(${cells}, 1fr)`, gap: 1.5 }}>
      {data.map((on, i) => <div key={i} style={{ background: on ? "#0D0B1C" : "transparent", borderRadius: 1 }}/>)}
    </div>
  );
};

window.ProfileScreen = ProfileScreen;
window.QRPattern = QRPattern;
window.SwitchRow = SwitchRow;

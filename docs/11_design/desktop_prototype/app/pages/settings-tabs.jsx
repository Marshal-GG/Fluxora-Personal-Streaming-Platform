// ── Settings sub-tabs ──────────────────────────────────────────────────
const SettingsNetworkTab = () => (
  <div style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 14 }}>
    <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
      <SettingBlock icon="wifi" title="Network Configuration">
        <SField label="Server Port" sub="Local port for HTTP and streaming" control={<TextField value="8000"/>}/>
        <SField label="HTTPS Port"  sub="Secure port (TLS)"                 control={<TextField value="8443"/>}/>
        <SField label="Bind Address" sub="Network interface to listen on"   control={<SelectField value="0.0.0.0 (all interfaces)"/>}/>
        <SField label="Use SSL/TLS" sub="Encrypt connections with TLS"      control={<TToggle on/>}/>
        <SField label="WebRTC Relay" sub="Use Fluxora relay when direct fails" control={<TToggle on/>}/>
      </SettingBlock>

      <SettingBlock icon="globe" title="Remote Access">
        <SField label="Enable Internet Access" sub="Allow connections from outside your LAN" control={<TToggle on/>}/>
        <SField label="Public Domain"          sub="Custom domain (Pro)" control={<TextField value="my-server.fluxora.cloud"/>}/>
        <SField label="UPnP Port Forwarding"   sub="Auto-configure router (recommended)" control={<TToggle on/>}/>
        <SField label="Manual Port Forwarding" sub="Configure router manually" control={<Button variant="secondary" size="sm" iconRight="extLink">Setup Guide</Button>}/>
      </SettingBlock>

      <SettingBlock icon="shieldCheck" title="Bandwidth Limits">
        <SField label="Internet Upload Cap"  sub="Max upload speed for remote streams" control={<TextField value="50 Mbps"/>}/>
        <SField label="LAN Speed"            sub="Local network bandwidth" control={<SelectField value="Unlimited"/>}/>
        <SField label="Per-Stream Limit"     sub="Maximum bitrate per single stream" control={<TextField value="20 Mbps"/>}/>
      </SettingBlock>
    </div>
    <div>
      <Card padding={18} style={{ marginBottom: 14 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 14 }}>
          <Icon name="activity" size={16} stroke="#10B981"/>
          <span style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Connection Test</span>
        </div>
        {[
          ["Local Network", "Reachable",       "online"],
          ["Internet Access", "Connected",     "online"],
          ["WebRTC Direct",   "Active",        "online"],
          ["UPnP Forwarding", "Mapped 8443",   "online"],
          ["DNS Resolution",  "8.4 ms",        "online"],
        ].map(([k, v, s], i) => (
          <div key={i} style={{ display: "flex", alignItems: "center", gap: 10, padding: "8px 0", borderBottom: i < 4 ? "1px solid rgba(255,255,255,0.04)" : "none", fontSize: 12 }}>
            <StatusDot status={s} size={6}/>
            <span style={{ flex: 1, color: "#94A3B8" }}>{k}</span>
            <span style={{ color: "#10B981", fontFamily: "JetBrains Mono", fontSize: 11.5 }}>{v}</span>
          </div>
        ))}
        <Button variant="primary" fullWidth icon="refresh" style={{ marginTop: 12 }}>Run Test</Button>
      </Card>

      <Card padding={18}>
        <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 12 }}>Active Interfaces</div>
        {[
          ["Ethernet", "192.168.1.105", "1 Gbps", "#10B981"],
          ["Wi-Fi",    "192.168.1.106", "300 Mbps", "#94A3B8"],
        ].map(([n, ip, sp, c], i) => (
          <div key={i} style={{ padding: "10px 0", borderBottom: i ? "none" : "1px solid rgba(255,255,255,0.04)" }}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 2 }}>
              <span style={{ fontSize: 12, color: "#E2E8F0", fontWeight: 600 }}>{n}</span>
              <span style={{ fontSize: 11, color: c, fontWeight: 600 }}>{sp}</span>
            </div>
            <div style={{ fontSize: 11, color: "#64748B", fontFamily: "JetBrains Mono" }}>{ip}</div>
          </div>
        ))}
      </Card>
    </div>
  </div>
);

const SettingsStreamingTab = () => (
  <div style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 14 }}>
    <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
      <SettingBlock icon="play" title="Streaming Quality">
        <SField label="LAN Quality"     sub="Quality on local network" control={<SelectField value="Original (No transcode)"/>}/>
        <SField label="Internet Quality" sub="Default for remote streams" control={<SelectField value="Adaptive (up to 4K)"/>}/>
        <SField label="Auto-quality" sub="Adjust quality based on bandwidth" control={<TToggle on/>}/>
        <SField label="Direct Play" sub="Skip transcoding when supported" control={<TToggle on/>}/>
        <SField label="Direct Stream" sub="Remux without re-encoding" control={<TToggle on/>}/>
      </SettingBlock>

      <SettingBlock icon="layers" title="Subtitles & Audio">
        <SField label="Default Subtitle Language"  control={<SelectField value="English"/>}/>
        <SField label="Default Audio Language"     control={<SelectField value="Original audio"/>}/>
        <SField label="Burn-in Subtitles"          sub="When client doesn't support PGS" control={<TToggle on/>}/>
        <SField label="Audio Boost"                sub="Normalize quiet dialogue" control={<TToggle on={false}/>}/>
      </SettingBlock>

      <SettingBlock icon="sparkle" title="Playback">
        <SField label="Skip Intro"             sub="Auto-skip detected intros" control={<TToggle on/>}/>
        <SField label="Auto-play Next Episode" control={<TToggle on={false}/>}/>
        <SField label="Resume Threshold"       sub="Mark watched at" control={<SelectField value="95% watched"/>}/>
        <SField label="Buffer Size"            sub="Pre-load duration" control={<SelectField value="10 seconds"/>}/>
      </SettingBlock>
    </div>
    <Card padding={18}>
      <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 12 }}>Quality Presets</div>
      {[
        ["Original", "Same as source",      "—",        "#10B981"],
        ["4K HDR",   "20 Mbps · HEVC",      "Best",     "#A855F7"],
        ["1080p",    "8 Mbps · H.264",      "Standard", "#3B82F6"],
        ["720p",     "4 Mbps · H.264",      "Mobile",   "#F59E0B"],
        ["480p",     "1.5 Mbps · H.264",    "Cellular", "#EC4899"],
      ].map(([n, s, t, c], i) => (
        <div key={i} style={{ padding: "10px 0", borderBottom: i < 4 ? "1px solid rgba(255,255,255,0.04)" : "none" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 2 }}>
            <span style={{ fontSize: 12.5, color: c, fontWeight: 600 }}>{n}</span>
            <span style={{ fontSize: 10, color: "#94A3B8", padding: "1px 6px", background: "rgba(255,255,255,0.04)", borderRadius: 4 }}>{t}</span>
          </div>
          <div style={{ fontSize: 11, color: "#64748B" }}>{s}</div>
        </div>
      ))}
    </Card>
  </div>
);

const SettingsSecurityTab = () => (
  <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
    <SettingBlock icon="shield" title="Authentication">
      <SField label="Require Password for Local Clients" sub="Even on the same network" control={<TToggle on/>}/>
      <SField label="Two-Factor Authentication" sub="Required for admin access" control={<TToggle on/>}/>
      <SField label="Session Timeout" sub="Auto sign-out after inactivity" control={<SelectField value="30 days"/>}/>
      <SField label="Allow PIN Login" sub="6-digit PIN on trusted devices" control={<TToggle on={false}/>}/>
    </SettingBlock>
    <SettingBlock icon="shieldCheck" title="Access Control">
      <SField label="Block Unrecognized Clients" sub="Require approval for new devices" control={<TToggle on/>}/>
      <SField label="Geo-blocking" sub="Restrict access by country" control={<Button variant="secondary" size="sm" iconRight="chevron">Configure</Button>}/>
      <SField label="IP Allowlist" sub="Only allow specific IP ranges" control={<TToggle on={false}/>}/>
      <SField label="Failed Login Attempts" sub="Lock after N attempts" control={<SelectField value="5 attempts"/>}/>
    </SettingBlock>
    <SettingBlock icon="info" title="Audit & Logging">
      <SField label="Log All Sign-ins" control={<TToggle on/>}/>
      <SField label="Log Stream Activity" control={<TToggle on/>}/>
      <SField label="Retention Period" sub="How long to keep logs" control={<SelectField value="90 days"/>}/>
      <SField label="Send Security Alerts" sub="Email me on suspicious activity" control={<TToggle on/>}/>
    </SettingBlock>
  </div>
);

const SettingsAdvancedTab = () => (
  <div style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 14 }}>
    <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
      <SettingBlock icon="cpu" title="Server Performance">
        <SField label="Max Concurrent Streams" control={<TextField value="10"/>}/>
        <SField label="Max CPU Usage %"        control={<TextField value="80"/>}/>
        <SField label="Process Priority"       control={<SelectField value="High"/>}/>
        <SField label="Database Cache"         control={<SelectField value="512 MB"/>}/>
      </SettingBlock>
      <SettingBlock icon="cogs" title="Developer">
        <SField label="Verbose Logging" control={<TToggle on={false}/>}/>
        <SField label="Allow API Access" sub="Enable REST API endpoints" control={<TToggle on/>}/>
        <SField label="API Token" sub="For automation and scripts" control={
          <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
            <span style={{ fontFamily: "JetBrains Mono", fontSize: 11, padding: "5px 8px", background: "rgba(255,255,255,0.03)", borderRadius: 6, color: "#A855F7" }}>flx_••••6kQ7</span>
            <button style={{ ...iconBtnSub }}><Icon name="copy" size={12} stroke="#94A3B8"/></button>
          </div>
        }/>
        <SField label="Webhooks" sub="Send events to external URL" control={<Button variant="secondary" size="sm" iconRight="chevron">Configure</Button>}/>
      </SettingBlock>
    </div>
    <Card padding={18}>
      <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 12 }}>System Diagnostics</div>
      <div style={{ fontFamily: "JetBrains Mono", fontSize: 11, color: "#94A3B8", lineHeight: 1.7 }}>
        <div><span style={{ color: "#64748B" }}>kernel</span>  Windows NT 10.0.22631</div>
        <div><span style={{ color: "#64748B" }}>cpu</span>     Intel i7-13700K · 16C 24T</div>
        <div><span style={{ color: "#64748B" }}>gpu</span>     NVIDIA RTX 4070 · 12 GB</div>
        <div><span style={{ color: "#64748B" }}>ram</span>     32 GB DDR5 6000</div>
        <div><span style={{ color: "#64748B" }}>disk</span>    NVMe 2 TB · 32 GB free</div>
        <div><span style={{ color: "#64748B" }}>encoder</span> NVENC h264 + hevc</div>
        <div><span style={{ color: "#64748B" }}>uptime</span>  2h 45m 12s</div>
      </div>
      <Button variant="secondary" fullWidth icon="download" style={{ marginTop: 14 }}>Download Diagnostics</Button>
    </Card>
  </div>
);

const SettingsAboutTab = () => (
  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
    <Card padding={28} style={{ textAlign: "center" }}>
      <div style={{ display: "inline-flex", justifyContent: "center", marginBottom: 16 }}><FluxoraMark size={72}/></div>
      <div style={{ display: "inline-flex", justifyContent: "center", marginTop: 4 }}><FluxoraWordmark height={26}/></div>
      <div style={{ fontSize: 12, color: "#94A3B8", marginTop: 8 }}>Stream. Sync. Anywhere.</div>
      <div style={{ fontFamily: "JetBrains Mono", fontSize: 11, color: "#A855F7", marginTop: 14 }}>v1.0.0 · build 2025.05.21.482</div>
      <div style={{ marginTop: 18, display: "flex", gap: 8, justifyContent: "center" }}>
        <Button variant="primary" icon="refresh">Check for Updates</Button>
        <Button variant="secondary" icon="extLink">Release Notes</Button>
      </div>
      <div style={{ marginTop: 18, padding: 12, background: "rgba(16,185,129,0.06)", border: "1px solid rgba(16,185,129,0.2)", borderRadius: 8, fontSize: 12, color: "#34D399" }}>
        ✓ You are running the latest version
      </div>
    </Card>
    <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
      <Card padding={20}>
        <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 12 }}>Resources</div>
        {[
          ["doc",       "Documentation",    "Browse user guides and API docs"],
          ["users",     "Community Forum",  "Get help from other Fluxora users"],
          ["msg",       "Contact Support",  "Reach our team directly"],
          ["info",      "Report a Bug",     "File an issue on GitHub"],
          ["sparkle",   "Feature Requests", "Suggest improvements"],
        ].map(([ic, t, s], i) => (
          <div key={i} style={{ display: "flex", alignItems: "center", gap: 12, padding: "10px 0", borderTop: i ? "1px solid rgba(255,255,255,0.04)" : "none" }}>
            <Icon name={ic} size={14} stroke="#A855F7"/>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12.5, color: "#E2E8F0", fontWeight: 500 }}>{t}</div>
              <div style={{ fontSize: 11, color: "#64748B", marginTop: 1 }}>{s}</div>
            </div>
            <Icon name="extLink" size={11} stroke="#475569"/>
          </div>
        ))}
      </Card>
      <Card padding={20}>
        <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 10 }}>Legal</div>
        <div style={{ display: "flex", gap: 14, flexWrap: "wrap", fontSize: 12 }}>
          <a style={{ color: "#A855F7", cursor: "pointer" }}>Terms of Service</a>
          <a style={{ color: "#A855F7", cursor: "pointer" }}>Privacy Policy</a>
          <a style={{ color: "#A855F7", cursor: "pointer" }}>Open Source Licenses</a>
          <a style={{ color: "#A855F7", cursor: "pointer" }}>Acknowledgements</a>
        </div>
        <div style={{ fontSize: 11, color: "#64748B", marginTop: 14, lineHeight: 1.5 }}>© 2025 Fluxora Inc. All rights reserved. Fluxora and the Fluxora logo are trademarks of Fluxora Inc.</div>
      </Card>
    </div>
  </div>
);

window.SettingsNetworkTab = SettingsNetworkTab;
window.SettingsStreamingTab = SettingsStreamingTab;
window.SettingsSecurityTab = SettingsSecurityTab;
window.SettingsAdvancedTab = SettingsAdvancedTab;
window.SettingsAboutTab = SettingsAboutTab;

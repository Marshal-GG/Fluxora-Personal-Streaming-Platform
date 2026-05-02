// ── Modal sheets & smaller screens ──────────────────────────────────────

// Generic bottom sheet wrapper rendered inside a phone
const Sheet = ({ title, children, height = 380 }) => (
  <div style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.5)" }}>
    <div style={{ position: "absolute", inset: 0, backdropFilter: "blur(4px)" }}/>
    <div style={{
      position: "absolute", left: 0, right: 0, bottom: 0, height,
      background: "#0F0C24", borderTopLeftRadius: 22, borderTopRightRadius: 22,
      borderTop: `1px solid ${M.borderStrong}`, padding: "10px 18px 24px",
      display: "flex", flexDirection: "column",
    }}>
      <div style={{ width: 38, height: 4, borderRadius: 999, background: "rgba(255,255,255,0.18)", margin: "4px auto 14px" }}/>
      <div style={{ fontSize: 16, fontWeight: 700, color: M.fg, marginBottom: 14 }}>{title}</div>
      <div style={{ flex: 1, overflowY: "auto" }}>{children}</div>
    </div>
  </div>
);

const Row = ({ icon, label, sub, right, on }) => (
  <div style={{
    display: "flex", alignItems: "center", gap: 12, padding: "12px 4px",
    borderBottom: `1px solid ${M.border}`,
  }}>
    {icon && <Icon name={icon} size={18} stroke={on ? M.accent : "#94A3B8"}/>}
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 14, fontWeight: 600, color: on ? "#E9D5FF" : M.fg }}>{label}</div>
      {sub && <div style={{ fontSize: 11.5, color: M.fgMuted, marginTop: 2 }}>{sub}</div>}
    </div>
    {right || (on && <Icon name="check" size={16} stroke={M.accent}/>)}
  </div>
);

// Cast picker
const CastSheet = () => (
  <div style={{ width: "100%", height: "100%", background: M.bg, position: "relative" }}>
    <Sheet title="Cast to a device" height={440}>
      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.4, color: M.fgDim, textTransform: "uppercase", margin: "4px 0 8px" }}>This network</div>
      <Row icon="tv" label="Living Room TV" sub="Chromecast · 4K" on/>
      <Row icon="tv" label="Bedroom Apple TV" sub="AirPlay · 1080p"/>
      <Row icon="server" label="Office Roku Stick" sub="Roku · 1080p"/>
      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.4, color: M.fgDim, textTransform: "uppercase", margin: "16px 0 8px" }}>Bluetooth</div>
      <Row icon="wifi" label="AirPods Pro" sub="Connected · 84% battery"/>
      <Row icon="wifi" label="Sonos Beam"/>
    </Sheet>
  </div>
);

// Audio & subtitles sheet
const AudioSubsSheet = () => (
  <div style={{ width: "100%", height: "100%", background: M.bg, position: "relative" }}>
    <Sheet title="Audio & subtitles" height={500}>
      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.4, color: M.fgDim, textTransform: "uppercase", margin: "4px 0 8px" }}>Audio track</div>
      <Row label="English · 5.1 Dolby Atmos" sub="Original" on/>
      <Row label="English · Stereo"/>
      <Row label="Spanish · 5.1"/>
      <Row label="Japanese · Stereo"/>
      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.4, color: M.fgDim, textTransform: "uppercase", margin: "20px 0 8px" }}>Subtitles</div>
      <Row label="Off"/>
      <Row label="English (CC)" on/>
      <Row label="English"/>
      <Row label="Spanish"/>
      <Row label="Customize style…" right={<Icon name="chevron" size={14} stroke="#64748B"/>}/>
    </Sheet>
  </div>
);

// Quality picker
const QualitySheet = () => (
  <div style={{ width: "100%", height: "100%", background: M.bg, position: "relative" }}>
    <Sheet title="Streaming quality" height={420}>
      <Row label="Auto" sub="Adjusts to your network" on/>
      <Row label="4K UHD" sub="Up to 25 GB / hour"/>
      <Row label="1080p HD" sub="Up to 8 GB / hour"/>
      <Row label="720p HD" sub="Up to 3 GB / hour"/>
      <Row label="480p" sub="Up to 1 GB / hour"/>
      <Row label="Data saver" sub="Up to 250 MB / hour"/>
    </Sheet>
  </div>
);

// Speed picker
const SpeedSheet = () => (
  <div style={{ width: "100%", height: "100%", background: M.bg, position: "relative" }}>
    <Sheet title="Playback speed" height={360}>
      {["0.25×","0.5×","0.75×","1.0×","1.25×","1.5×","1.75×","2.0×"].map((s, i) => (
        <Row key={i} label={s} on={s === "1.0×"} sub={s === "1.0×" ? "Normal" : null}/>
      ))}
    </Sheet>
  </div>
);

// Sleep timer
const SleepTimerSheet = () => (
  <div style={{ width: "100%", height: "100%", background: M.bg, position: "relative" }}>
    <Sheet title="Sleep timer" height={420}>
      <Row label="Off" on/>
      <Row label="End of episode"/>
      <Row label="15 minutes"/>
      <Row label="30 minutes"/>
      <Row label="45 minutes"/>
      <Row label="1 hour"/>
      <Row label="Custom…" right={<Icon name="chevron" size={14} stroke="#64748B"/>}/>
    </Sheet>
  </div>
);

// Episodes list (TV shows)
const EpisodesScreen = () => {
  const eps = [
    { n: 1, title: "Hello, Ms. Cobel", dur: "57m", date: "Jan 17, 2025", sub: "Mark navigates a new chapter at Lumon.", watched: true },
    { n: 2, title: "Goodbye, Mrs. Selvig", dur: "55m", date: "Jan 24, 2025", sub: "Helly finds an unsettling note at home.", watched: true },
    { n: 3, title: "Who Is Alive?", dur: "54m", date: "Jan 31, 2025", sub: "Irving searches the corridors of MDR.", watched: true },
    { n: 4, title: "Woe's Hollow", dur: "62m", date: "Feb 07, 2025", sub: "A team-building retreat goes sideways.", progress: 0.62 },
    { n: 5, title: "Trojan's Horse", dur: "53m", date: "Feb 14, 2025", sub: "Dylan considers an offer he can't refuse." },
    { n: 6, title: "Attila", dur: "58m", date: "Feb 21, 2025", sub: "Cobel returns to her hometown." },
    { n: 7, title: "Chikhai Bardo", dur: "67m", date: "Feb 28, 2025", sub: "Mark and Gemma's life before Lumon." },
  ];
  return (
    <div style={{ background: M.bg, height: "100%", display: "flex", flexDirection: "column", color: M.fg }}>
      <MAppBar title="Severance" onBack={() => {}} trailing={
        <button style={{ background: "rgba(255,255,255,0.04)", border: `1px solid ${M.border}`, color: M.fg, padding: "7px 12px", borderRadius: 999, fontSize: 12, fontWeight: 600, fontFamily: "inherit" }}>
          Season 2 ▾
        </button>
      }/>
      <div style={{ flex: 1, overflowY: "auto" }}>
        {eps.map(e => (
          <div key={e.n} style={{ display: "flex", gap: 12, padding: "14px 16px", borderBottom: `1px solid ${M.border}` }}>
            <div style={{
              width: 110, height: 64, borderRadius: 8,
              background: "linear-gradient(135deg, #0a1a3a, #4a8aea)",
              position: "relative", flexShrink: 0,
              boxShadow: "0 4px 12px rgba(0,0,0,0.4)",
            }}>
              <div style={{
                position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center",
                background: "linear-gradient(135deg, transparent, rgba(0,0,0,0.4))",
              }}>
                <Icon name="play" size={20} stroke="#fff"/>
              </div>
              {e.progress && (
                <div style={{ position: "absolute", left: 4, right: 4, bottom: 4, height: 3, background: "rgba(0,0,0,0.5)", borderRadius: 999, overflow: "hidden" }}>
                  <div style={{ width: `${e.progress*100}%`, height: "100%", background: M.accent }}/>
                </div>
              )}
              {e.watched && (
                <div style={{ position: "absolute", top: 4, right: 4, width: 18, height: 18, borderRadius: "50%", background: "rgba(0,0,0,0.6)", display: "flex", alignItems: "center", justifyContent: "center" }}>
                  <Icon name="check" size={11} stroke={M.success}/>
                </div>
              )}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 13.5, fontWeight: 700, color: M.fg }}>{e.n}. {e.title}</div>
              <div style={{ fontSize: 11.5, color: M.fgMuted, marginTop: 2 }}>{e.dur} · {e.date}</div>
              <div style={{ fontSize: 12, color: "#CBD5E1", marginTop: 6, lineHeight: 1.4 }}>{e.sub}</div>
            </div>
            <button style={{ alignSelf: "center", background: "none", border: "none", color: M.fgMuted, cursor: "pointer" }}>
              <Icon name="download" size={18} stroke="#94A3B8"/>
            </button>
          </div>
        ))}
      </div>
    </div>
  );
};

// Server picker (first-run / reconnect)
const ServerPickerScreen = () => {
  const servers = [
    { name: "atlas-server", host: "atlas.local · 192.168.1.42", lat: "12 ms", on: true, status: "Owner · 2.4 TB" },
    { name: "Friend's Plex", host: "shared via Fluxora link",   lat: "84 ms", status: "Shared library · 980 GB" },
    { name: "office-nas",   host: "10.0.5.18",                  lat: "—",     status: "Offline", offline: true },
  ];
  return (
    <div style={{ background: M.bg, height: "100%", display: "flex", flexDirection: "column", color: M.fg }}>
      <MAppBar title="Connect to a server" onBack={() => {}}/>
      <div style={{ padding: "16px 16px 8px" }}>
        <div style={{ fontSize: 13, color: M.fgMuted, lineHeight: 1.5 }}>
          Fluxora found these servers on your network. Tap one to connect, or add a server by IP / invite code.
        </div>
      </div>
      <div style={{ flex: 1, overflowY: "auto", padding: "8px 16px 16px" }}>
        {servers.map((s, i) => (
          <div key={i} style={{
            display: "flex", alignItems: "center", gap: 14, padding: "14px",
            background: s.on ? "rgba(168,85,247,0.07)" : "rgba(255,255,255,0.03)",
            border: s.on ? `1px solid ${M.accentSoft}` : `1px solid ${M.border}`,
            borderRadius: 12, marginBottom: 10,
            opacity: s.offline ? 0.55 : 1,
          }}>
            <div style={{
              width: 42, height: 42, borderRadius: 10,
              background: s.on ? "linear-gradient(135deg, #8B5CF6, #A855F7)" : "rgba(255,255,255,0.05)",
              display: "flex", alignItems: "center", justifyContent: "center",
              boxShadow: s.on ? "0 6px 16px rgba(139,92,246,0.4)" : "none",
            }}><Icon name="server" size={20} stroke="#fff"/></div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: M.fg }}>{s.name}</div>
                {s.on && <span style={{ fontSize: 10, fontWeight: 700, color: M.success, padding: "2px 6px", borderRadius: 4, background: "rgba(16,185,129,0.12)" }}>CONNECTED</span>}
                {s.offline && <span style={{ fontSize: 10, fontWeight: 700, color: M.fgMuted, padding: "2px 6px", borderRadius: 4, background: "rgba(255,255,255,0.06)" }}>OFFLINE</span>}
              </div>
              <div style={{ fontSize: 11.5, color: M.fgMuted, marginTop: 2 }}>{s.host}</div>
              <div style={{ fontSize: 11.5, color: s.on ? "#E9D5FF" : M.fgDim, marginTop: 2 }}>{s.status} · {s.lat}</div>
            </div>
            <Icon name="chevron" size={16} stroke="#64748B"/>
          </div>
        ))}
        <button style={{
          width: "100%", marginTop: 4, padding: "13px",
          background: "rgba(255,255,255,0.04)", border: `1px dashed ${M.borderStrong}`,
          color: M.fg, borderRadius: 12, fontSize: 13, fontWeight: 600, fontFamily: "inherit",
          display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8,
        }}>
          <Icon name="plus" size={16}/> Add by IP or invite code
        </button>
      </div>
    </div>
  );
};

// Notifications
const NotificationsScreen = () => {
  const groups = [
    { date: "Today", items: [
      { icon: "play",   title: "New episode available", sub: "Severance · S2 E8 — 'Sweet Vitriol'", time: "2h ago", unread: true },
      { icon: "download", title: "Download complete",   sub: "Dune: Part Two · 11.2 GB · 4K HDR",   time: "5h ago", unread: true },
      { icon: "users",  title: "Group watch invite",    sub: "Sarah invited you to watch Severance S2 E8", time: "8h ago" },
    ]},
    { date: "Yesterday", items: [
      { icon: "sparkle", title: "Recommended for you",  sub: "We added 12 titles based on Interstellar", time: "1d ago" },
      { icon: "shieldCheck", title: "New device signed in", sub: "Alex's iPhone · Pixel 7 Pro · Brooklyn, NY", time: "1d ago" },
    ]},
    { date: "This week", items: [
      { icon: "creditCard", title: "Receipt available",  sub: "Plus Plan – Monthly Renewal · $4.99", time: "3d ago" },
      { icon: "info",   title: "Server update available", sub: "atlas-server · Fluxora 1.0.4", time: "4d ago" },
    ]},
  ];
  return (
    <div style={{ background: M.bg, height: "100%", display: "flex", flexDirection: "column", color: M.fg }}>
      <MAppBar title="Notifications" trailing={
        <button style={{ background: "none", border: "none", color: M.fgMuted, fontSize: 12, fontWeight: 600, padding: "0 10px", cursor: "pointer", fontFamily: "inherit" }}>
          Mark all read
        </button>
      }/>
      <div style={{ flex: 1, overflowY: "auto", padding: "0 16px 16px" }}>
        {groups.map((g, gi) => (
          <div key={gi}>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.4, color: M.fgDim, textTransform: "uppercase", margin: "16px 0 6px" }}>{g.date}</div>
            {g.items.map((n, i) => (
              <div key={i} style={{
                display: "flex", gap: 12, padding: "12px 0",
                borderBottom: i < g.items.length - 1 ? `1px solid ${M.border}` : "none",
              }}>
                <div style={{
                  width: 36, height: 36, borderRadius: 9,
                  background: M.accentSoft, color: M.accent,
                  display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
                }}><Icon name={n.icon} size={16} stroke={M.accent}/></div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13.5, fontWeight: 700, color: M.fg, display: "flex", alignItems: "center", gap: 8 }}>
                    {n.title}
                    {n.unread && <span style={{ width: 7, height: 7, borderRadius: "50%", background: M.accent, flexShrink: 0 }}/>}
                  </div>
                  <div style={{ fontSize: 12, color: M.fgMuted, marginTop: 2, lineHeight: 1.4 }}>{n.sub}</div>
                  <div style={{ fontSize: 11, color: M.fgDim, marginTop: 4 }}>{n.time}</div>
                </div>
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
};

// Group watch (party / co-watch)
const GroupWatchScreen = () => (
  <div style={{ background: M.bg, height: "100%", display: "flex", flexDirection: "column", color: M.fg }}>
    <MAppBar title="Group Watch" onBack={() => {}}/>
    <div style={{ flex: 1, overflowY: "auto", padding: "8px 16px 24px" }}>
      <div style={{
        height: 200, borderRadius: 14, position: "relative", overflow: "hidden",
        background: "linear-gradient(180deg, #050810 0%, #2a3a6a 100%)",
        boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.06)",
      }}>
        <div style={{ position: "absolute", inset: 0, opacity: 0.6, backgroundImage: "radial-gradient(1px 1px at 14% 18%, #fff, transparent),radial-gradient(1px 1px at 32% 12%, #fff, transparent),radial-gradient(1px 1px at 58% 22%, #fff, transparent),radial-gradient(1px 1px at 78% 14%, #fff, transparent)" }}/>
        <div style={{ position: "absolute", left: 14, right: 14, bottom: 14 }}>
          <div style={{ fontSize: 10.5, fontWeight: 700, color: "#22D3EE", letterSpacing: 1.4, textTransform: "uppercase" }}>● Live · Now playing</div>
          <div style={{ fontSize: 18, fontWeight: 800, color: "#fff", marginTop: 4 }}>Interstellar</div>
          <div style={{ fontSize: 11.5, color: "rgba(255,255,255,0.7)", marginTop: 2 }}>1:12:45 / 2:49:03</div>
        </div>
      </div>

      <div style={{ marginTop: 16, fontSize: 11, fontWeight: 700, letterSpacing: 1.4, color: M.fgDim, textTransform: "uppercase", marginBottom: 10 }}>In the room · 4</div>
      {[
        { name: "Alex (you)",      sub: "Host · Pixel 7 Pro",      colors: "linear-gradient(135deg, #8B5CF6, #EC4899)", initials: "AK" },
        { name: "Sarah Mendez",    sub: "iPhone 15 · joined 12m ago", colors: "linear-gradient(135deg, #22D3EE, #6366F1)", initials: "SM" },
        { name: "Jamie Liu",       sub: "Apple TV · joined 8m ago", colors: "linear-gradient(135deg, #F59E0B, #EF4444)", initials: "JL" },
        { name: "Theo Park",       sub: "iPad · joined 4m ago",    colors: "linear-gradient(135deg, #10B981, #22D3EE)", initials: "TP" },
      ].map((u, i) => (
        <div key={i} style={{ display: "flex", alignItems: "center", gap: 12, padding: "10px 0", borderBottom: `1px solid ${M.border}` }}>
          <div style={{ width: 38, height: 38, borderRadius: "50%", background: u.colors, color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 13, fontWeight: 700 }}>{u.initials}</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13.5, fontWeight: 600, color: M.fg }}>{u.name}</div>
            <div style={{ fontSize: 11.5, color: M.fgMuted, marginTop: 2 }}>{u.sub}</div>
          </div>
          <Icon name="msg" size={16} stroke="#94A3B8"/>
        </div>
      ))}

      <div style={{ marginTop: 16, padding: 14, background: "rgba(255,255,255,0.03)", border: `1px solid ${M.border}`, borderRadius: 12 }}>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.4, color: M.fgDim, textTransform: "uppercase" }}>Invite link</div>
        <div style={{ marginTop: 8, display: "flex", gap: 8 }}>
          <div style={{ flex: 1, padding: "11px 14px", background: "#08061A", border: `1px solid ${M.border}`, borderRadius: 10, color: M.fg, fontFamily: "JetBrains Mono", fontSize: 12 }}>
            fluxora.io/w/aTl2-xK9p
          </div>
          <button style={{ width: 44, height: 44, borderRadius: 10, background: M.accentSoft, border: "none", color: M.accent, cursor: "pointer" }}>
            <Icon name="copy" size={16} stroke={M.accent}/>
          </button>
        </div>
      </div>

      <div style={{ display: "flex", gap: 8, marginTop: 14 }}>
        <button style={{ flex: 1, height: 46, borderRadius: 12, background: "rgba(239,68,68,0.10)", border: "1px solid rgba(239,68,68,0.3)", color: "#F87171", fontWeight: 700, fontSize: 13.5, fontFamily: "inherit", cursor: "pointer" }}>Leave</button>
        <button style={{ flex: 2, height: 46, borderRadius: 12, border: "none", background: "linear-gradient(135deg, #8B5CF6, #A855F7)", color: "#fff", fontWeight: 700, fontSize: 13.5, fontFamily: "inherit", cursor: "pointer", display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
          <Icon name="play" size={15} stroke="#fff"/> Resume for everyone
        </button>
      </div>
    </div>
  </div>
);

// Mini-player + home (PiP-style at bottom)
const HomeWithMiniPlayer = () => {
  const movies = window.FluxData2.movies;
  const shows  = window.FluxData2.shows;
  return (
    <div style={{ background: M.bg, height: "100%", position: "relative", display: "flex", flexDirection: "column" }}>
      <div style={{ flex: 1, overflowY: "auto" }}>
        <PosterRail title="Trending now" items={movies.slice(0, 8)}/>
        <PosterRail title="Continue watching shows" items={shows.slice(0, 6)}/>
        <div style={{ height: 80 }}/>
      </div>
      {/* mini-player */}
      <div style={{
        position: "absolute", left: 8, right: 8, bottom: 4,
        background: "rgba(20,18,38,0.96)", border: `1px solid ${M.borderStrong}`,
        borderRadius: 14, padding: 8, display: "flex", alignItems: "center", gap: 10,
        backdropFilter: "blur(20px)", boxShadow: "0 -8px 30px rgba(0,0,0,0.5)",
      }}>
        <div style={{
          width: 56, height: 56, borderRadius: 8, flexShrink: 0,
          background: "linear-gradient(180deg, #050810 0%, #2a3a6a 100%)",
          position: "relative", overflow: "hidden",
        }}>
          <div style={{ position: "absolute", inset: 0, opacity: 0.5, backgroundImage: "radial-gradient(1px 1px at 30% 30%, #fff, transparent),radial-gradient(1px 1px at 70% 50%, #fff, transparent)" }}/>
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: M.fg, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>Interstellar</div>
          <div style={{ fontSize: 11, color: M.fgMuted, marginTop: 2 }}>1:12:45 — 1:36 left</div>
          <div style={{ marginTop: 6, height: 3, background: "rgba(255,255,255,0.08)", borderRadius: 999, overflow: "hidden" }}>
            <div style={{ width: "44%", height: "100%", background: "linear-gradient(90deg, #8B5CF6, #A855F7)" }}/>
          </div>
        </div>
        <button style={{ width: 36, height: 36, borderRadius: "50%", background: "linear-gradient(135deg, #8B5CF6, #A855F7)", border: "none", color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
          <Icon name="pause" size={14} stroke="#fff"/>
        </button>
        <button style={{ width: 36, height: 36, borderRadius: 8, background: "transparent", border: "none", color: M.fgMuted, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Icon name="x" size={16} stroke="#94A3B8"/>
        </button>
      </div>
    </div>
  );
};

// X-Ray panel (cast / scene info during playback)
const XRayScreen = () => (
  <div style={{ background: M.bg, height: "100%", display: "flex", flexDirection: "column", color: M.fg }}>
    <MAppBar title="X-Ray · Interstellar" onBack={() => {}} trailing={
      <span style={{ fontSize: 11, color: M.fgMuted, padding: "0 10px" }}>1:12:45</span>
    }/>
    <div style={{ flex: 1, overflowY: "auto", padding: "8px 16px 16px" }}>
      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.4, color: M.fgDim, textTransform: "uppercase", margin: "8px 0 10px" }}>In this scene · 3</div>
      {[
        { name: "Matthew McConaughey", role: "as Cooper", c: "linear-gradient(135deg, #f59e0b, #ef4444)", initials: "MM" },
        { name: "Anne Hathaway",       role: "as Brand",  c: "linear-gradient(135deg, #8B5CF6, #EC4899)", initials: "AH" },
        { name: "David Gyasi",         role: "as Romilly",c: "linear-gradient(135deg, #22D3EE, #6366F1)", initials: "DG" },
      ].map((p, i) => (
        <div key={i} style={{ display: "flex", alignItems: "center", gap: 12, padding: "10px 0", borderBottom: `1px solid ${M.border}` }}>
          <div style={{ width: 44, height: 44, borderRadius: "50%", background: p.c, color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 700 }}>{p.initials}</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13.5, fontWeight: 700, color: M.fg }}>{p.name}</div>
            <div style={{ fontSize: 12, color: M.fgMuted, marginTop: 2 }}>{p.role}</div>
          </div>
          <Icon name="chevron" size={16} stroke="#64748B"/>
        </div>
      ))}

      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.4, color: M.fgDim, textTransform: "uppercase", margin: "20px 0 10px" }}>Trivia</div>
      <div style={{ padding: 14, background: "rgba(255,255,255,0.03)", border: `1px solid ${M.border}`, borderRadius: 12, marginBottom: 8 }}>
        <div style={{ fontSize: 11, fontWeight: 700, color: M.accent, letterSpacing: 0.4, textTransform: "uppercase" }}>Did you know?</div>
        <div style={{ fontSize: 13, color: "#CBD5E1", marginTop: 6, lineHeight: 1.5 }}>
          The frozen clouds on Mann's planet were inspired by real stratiform formations photographed over Iceland.
        </div>
      </div>
      <div style={{ padding: 14, background: "rgba(255,255,255,0.03)", border: `1px solid ${M.border}`, borderRadius: 12 }}>
        <div style={{ fontSize: 11, fontWeight: 700, color: M.accent, letterSpacing: 0.4, textTransform: "uppercase" }}>Soundtrack</div>
        <div style={{ fontSize: 13, color: "#CBD5E1", marginTop: 6, lineHeight: 1.5 }}>
          "Mountains" — Hans Zimmer · From the Original Motion Picture Soundtrack.
        </div>
      </div>
    </div>
  </div>
);

// Empty state — no internet / no library
const EmptyOfflineScreen = () => (
  <div style={{
    background: M.bg, height: "100%", display: "flex", flexDirection: "column",
    alignItems: "center", justifyContent: "center", padding: 24, color: M.fg, textAlign: "center",
  }}>
    <div style={{
      width: 84, height: 84, borderRadius: "50%",
      background: "rgba(168,85,247,0.10)", border: `1px solid ${M.borderStrong}`,
      display: "flex", alignItems: "center", justifyContent: "center",
      marginBottom: 22,
    }}><Icon name="wifi" size={36} stroke={M.accent}/></div>
    <div style={{ fontSize: 19, fontWeight: 800, color: M.fg, letterSpacing: -0.3 }}>You're offline</div>
    <div style={{ fontSize: 13, color: M.fgMuted, marginTop: 8, maxWidth: 280, lineHeight: 1.5 }}>
      We can't reach <span style={{ color: M.fg }}>atlas-server</span> right now. Your downloads are still available below.
    </div>
    <button style={{
      marginTop: 22, padding: "12px 22px", borderRadius: 12, border: "none",
      background: "linear-gradient(135deg, #8B5CF6, #A855F7)", color: "#fff",
      fontSize: 13.5, fontWeight: 700, fontFamily: "inherit", cursor: "pointer",
      display: "inline-flex", alignItems: "center", gap: 8,
    }}><Icon name="refresh" size={15} stroke="#fff"/> Retry connection</button>
    <button style={{
      marginTop: 10, padding: "12px 22px", borderRadius: 12,
      background: "rgba(255,255,255,0.04)", border: `1px solid ${M.border}`,
      color: M.fg, fontSize: 13.5, fontWeight: 700, fontFamily: "inherit", cursor: "pointer",
    }}>Open downloads</button>
  </div>
);

Object.assign(window, {
  CastSheet, AudioSubsSheet, QualitySheet, SpeedSheet, SleepTimerSheet,
  EpisodesScreen, ServerPickerScreen, NotificationsScreen, GroupWatchScreen,
  HomeWithMiniPlayer, XRayScreen, EmptyOfflineScreen,
  Row,
});

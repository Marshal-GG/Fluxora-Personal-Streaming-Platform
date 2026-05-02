// ── Phase-2 screens · file types, server hosting, auth, multi-format ────
// Answers: yes, Fluxora handles ANY file (movies/shows/music/photos/docs/PDFs).
// And yes, a phone can BE a server too — pair it with auth, share a library,
// generate invite codes for friends.

// 1 ─ Document / PDF viewer ─────────────────────────────────────────────
const DocViewerScreen = () => (
  <div style={{ background: M.bg, height: "100%", display: "flex", flexDirection: "column", color: M.fg }}>
    <MAppBar title="Project Brief — Atlas.pdf" onBack={() => {}} trailing={
      <div style={{ display: "flex", gap: 4 }}>
        <button style={{ width:40,height:40, background:"none", border:"none", cursor:"pointer" }}><Icon name="download" size={18} stroke="#94A3B8"/></button>
        <button style={{ width:40,height:40, background:"none", border:"none", cursor:"pointer" }}><Icon name="moreH" size={18} stroke="#94A3B8"/></button>
      </div>
    }/>
    {/* Page area */}
    <div style={{ flex: 1, overflowY: "auto", padding: 18, background: "#0a0816" }}>
      <div style={{
        background: "#fff", color: "#0F172A", borderRadius: 6, padding: "32px 28px",
        boxShadow: "0 8px 30px rgba(0,0,0,0.6)", fontFamily: "Georgia, serif",
        minHeight: 520,
      }}>
        <div style={{ fontSize: 10, color: "#94A3B8", letterSpacing: 1.4, textTransform: "uppercase" }}>ATLAS · INTERNAL</div>
        <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4, lineHeight: 1.2 }}>Project Brief — Atlas Server v2</div>
        <div style={{ fontSize: 11, color: "#64748B", marginTop: 8 }}>May 18, 2025 · Alex K. · 14 pages</div>
        <div style={{ height: 1, background: "#E2E8F0", margin: "16px 0" }}/>
        <div style={{ fontSize: 14, fontWeight: 700, marginBottom: 8 }}>1. Summary</div>
        <div style={{ fontSize: 11.5, lineHeight: 1.7, color: "#334155" }}>
          Atlas is the next-generation home media server, designed to consolidate movies, shows, music, photos, and documents into a single shared library. This brief outlines goals, technical scope, and a phased delivery plan for v2.
        </div>
        <div style={{ fontSize: 14, fontWeight: 700, margin: "16px 0 8px" }}>2. Goals</div>
        <ul style={{ fontSize: 11.5, lineHeight: 1.7, color: "#334155", paddingLeft: 18, margin: 0 }}>
          <li>Unify media management across file types</li>
          <li>Run on Mac, Windows, Linux, and ARM (Pi 5)</li>
          <li>End-to-end encryption with per-share auth</li>
        </ul>
        <div style={{ fontSize: 14, fontWeight: 700, margin: "16px 0 8px" }}>3. Architecture</div>
        <div style={{ fontSize: 11.5, lineHeight: 1.7, color: "#334155" }}>
          Core daemon (Rust) · Transcoder (FFmpeg) · WebRTC relay · SQLite metadata store · gRPC client API.
        </div>
      </div>
      <div style={{ textAlign: "center", fontSize: 11, color: M.fgDim, marginTop: 14 }}>Page 1 of 14</div>
    </div>
    {/* Bottom toolbar */}
    <div style={{
      flexShrink: 0, background: "rgba(8,6,20,0.96)", borderTop: `1px solid ${M.border}`,
      padding: "10px 12px", display: "flex", alignItems: "center", gap: 10, backdropFilter: "blur(20px)",
    }}>
      <button style={{ width:38,height:38,borderRadius:9,background:"rgba(255,255,255,0.04)",border:`1px solid ${M.border}`,color:M.fg,cursor:"pointer" }}>
        <Icon name="chevronL" size={16}/>
      </button>
      <div style={{ flex: 1, height: 38, borderRadius: 9, background: "rgba(255,255,255,0.04)", border:`1px solid ${M.border}`, display:"flex", alignItems:"center", justifyContent:"center", fontSize: 12, color: M.fg, fontWeight: 600 }}>
        1 / 14
      </div>
      <button style={{ width:38,height:38,borderRadius:9,background:"rgba(255,255,255,0.04)",border:`1px solid ${M.border}`,color:M.fg,cursor:"pointer" }}>
        <Icon name="chevron" size={16}/>
      </button>
      <button style={{ width:38,height:38,borderRadius:9,background:M.accentSoft,border:"none",color:M.accent,cursor:"pointer" }}>
        <Icon name="search" size={16} stroke={M.accent}/>
      </button>
    </div>
  </div>
);

// 2 ─ Photo viewer (full-bleed) ─────────────────────────────────────────
const PhotoViewerScreen = () => (
  <div style={{ background: "#000", height: "100%", display: "flex", flexDirection: "column", position: "relative" }}>
    <div style={{
      position:"absolute", inset:0,
      backgroundImage: "url(https://picsum.photos/seed/fluxora-photo/800/1200)",
      backgroundSize: "cover", backgroundPosition: "center",
    }}/>
    <div style={{ position:"absolute", inset:0, background:"linear-gradient(180deg, rgba(0,0,0,0.55) 0%, transparent 30%, transparent 70%, rgba(0,0,0,0.55) 100%)" }}/>
    <div style={{ position:"relative", padding:"10px 8px", display:"flex", alignItems:"center", color:"#fff" }}>
      <button style={{ width:44,height:44,background:"none",border:"none",color:"#fff",cursor:"pointer" }}><Icon name="x" size={20} stroke="#fff"/></button>
      <div style={{ flex:1, textAlign:"center" }}>
        <div style={{ fontSize:13, fontWeight:600 }}>IMG_4521.jpg</div>
        <div style={{ fontSize:11, opacity:0.7, marginTop:2 }}>3 of 487 · May 18, 2025</div>
      </div>
      <button style={{ width:44,height:44,background:"none",border:"none",color:"#fff",cursor:"pointer" }}><Icon name="moreH" size={18} stroke="#fff"/></button>
    </div>
    <div style={{ flex:1 }}/>
    <div style={{ position:"relative", padding:"12px 18px 18px", color:"#fff" }}>
      <div style={{ display:"flex", justifyContent:"space-around" }}>
        {[
          { i:"upload",   l:"Share" },
          { i:"bolt",     l:"Edit" },
          { i:"eye",      l:"Info" },
          { i:"download", l:"Save" },
          { i:"trash",    l:"Delete" },
        ].map((a,i)=>(
          <button key={i} style={{ background:"none", border:"none", color:"#fff", display:"flex", flexDirection:"column", alignItems:"center", gap:4, cursor:"pointer" }}>
            <Icon name={a.i} size={20} stroke="#fff"/>
            <span style={{ fontSize:10.5, opacity:0.85 }}>{a.l}</span>
          </button>
        ))}
      </div>
    </div>
  </div>
);

// 3 ─ Music player (now playing) ────────────────────────────────────────
const MusicPlayerScreen = () => (
  <div style={{ background: "linear-gradient(180deg, #1a0820 0%, #08061A 60%)", height: "100%", display: "flex", flexDirection: "column", color: M.fg }}>
    <MAppBar title="" transparent leading={
      <button style={{ width:44,height:44,background:"none",border:"none",cursor:"pointer" }}><Icon name="chevronD" size={22} stroke="#fff"/></button>
    } trailing={
      <button style={{ width:44,height:44,background:"none",border:"none",cursor:"pointer" }}><Icon name="moreH" size={18} stroke="#fff"/></button>
    }/>
    <div style={{ flex:1, padding:"8px 28px 0", display:"flex", flexDirection:"column", alignItems:"center" }}>
      <img src="https://image.tmdb.org/t/p/w500/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg"
           alt="album"
           style={{ width:280, height:280, borderRadius:18, objectFit:"cover", boxShadow:"0 20px 50px rgba(0,0,0,0.6)" }}
           onError={(e)=>{e.currentTarget.style.background="linear-gradient(135deg, #c44a8a, #f4a4ca)";e.currentTarget.style.objectFit="";e.currentTarget.removeAttribute("src");}}/>
      <div style={{ marginTop:30, width:"100%", textAlign:"center" }}>
        <div style={{ fontSize:11, color:M.accent, fontWeight:700, letterSpacing:1.4, textTransform:"uppercase" }}>Now playing</div>
        <div style={{ fontSize:22, fontWeight:800, marginTop:6, letterSpacing:-0.3 }}>Get Lucky</div>
        <div style={{ fontSize:13.5, color:M.fgMuted, marginTop:4 }}>Daft Punk · Random Access Memories</div>
      </div>
      <div style={{ width:"100%", marginTop:24 }}>
        <div style={{ height:4, background:"rgba(255,255,255,0.08)", borderRadius:999, overflow:"hidden" }}>
          <div style={{ width:"38%", height:"100%", background:"linear-gradient(90deg,#8B5CF6,#A855F7)" }}/>
        </div>
        <div style={{ display:"flex", justifyContent:"space-between", marginTop:6, fontSize:11, color:M.fgMuted }}>
          <span>2:18</span><span>6:09</span>
        </div>
      </div>
      <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", width:"100%", marginTop:18 }}>
        <button style={{ background:"none", border:"none", color:M.fgMuted, cursor:"pointer" }}><Icon name="refresh" size={20} stroke="#94A3B8"/></button>
        <button style={{ background:"none", border:"none", color:M.fg, cursor:"pointer" }}><Icon name="chevronL" size={28} stroke="#fff"/></button>
        <button style={{ width:64,height:64,borderRadius:"50%",background:"linear-gradient(135deg,#8B5CF6,#A855F7)",border:"none",color:"#fff",display:"flex",alignItems:"center",justifyContent:"center",cursor:"pointer",boxShadow:"0 10px 30px rgba(168,85,247,0.5)" }}>
          <Icon name="pause" size={26} stroke="#fff"/>
        </button>
        <button style={{ background:"none", border:"none", color:M.fg, cursor:"pointer" }}><Icon name="chevron" size={28} stroke="#fff"/></button>
        <button style={{ background:"none", border:"none", color:M.fgMuted, cursor:"pointer" }}><Icon name="list" size={20} stroke="#94A3B8"/></button>
      </div>
    </div>
  </div>
);

// 4 ─ Server host setup (start a server FROM THE PHONE, with auth) ──────
const HostServerScreen = () => (
  <div style={{ background: M.bg, height: "100%", display: "flex", flexDirection: "column", color: M.fg }}>
    <MAppBar title="Host a server" onBack={() => {}}/>
    <div style={{ flex:1, overflowY:"auto", padding:"6px 16px 18px" }}>
      {/* status hero */}
      <div style={{ padding:14, borderRadius:14, background:"linear-gradient(135deg, rgba(16,185,129,0.18), rgba(34,211,238,0.10))", border:"1px solid rgba(16,185,129,0.35)" }}>
        <div style={{ display:"flex", alignItems:"center", gap:8 }}>
          <span style={{ width:8,height:8,borderRadius:"50%",background:M.success,boxShadow:"0 0 8px #10B981" }}/>
          <span style={{ fontSize:11, fontWeight:700, color:M.success, letterSpacing:1.4, textTransform:"uppercase" }}>Running</span>
        </div>
        <div style={{ fontSize:18, fontWeight:800, marginTop:6 }}>alex-pixel.local</div>
        <div style={{ fontSize:12, color:M.fgMuted, marginTop:2 }}>192.168.1.84 · 4 clients · uptime 6h 12m</div>
      </div>

      {/* sections */}
      <div style={{ fontSize:11, fontWeight:700, letterSpacing:1.4, color:M.fgDim, textTransform:"uppercase", margin:"18px 0 8px" }}>Authentication</div>
      <div style={{ background:"rgba(255,255,255,0.03)", border:`1px solid ${M.border}`, borderRadius:12, overflow:"hidden" }}>
        <Row icon="key"     label="Password"          sub="Required for new clients" right={<span style={{fontSize:11.5,color:M.success,fontWeight:600}}>On</span>}/>
        <Row icon="shieldCheck" label="Two-factor auth" sub="6-digit code via authenticator" right={<span style={{fontSize:11.5,color:M.success,fontWeight:600}}>On</span>}/>
        <Row icon="qr"      label="Pair via QR code"  sub="Tap to show QR"           right={<Icon name="chevron" size={14} stroke="#64748B"/>}/>
        <Row icon="key"     label="Invite codes"      sub="3 active · expires in 24h" right={<Icon name="chevron" size={14} stroke="#64748B"/>}/>
      </div>

      <div style={{ fontSize:11, fontWeight:700, letterSpacing:1.4, color:M.fgDim, textTransform:"uppercase", margin:"18px 0 8px" }}>Sharing</div>
      <div style={{ background:"rgba(255,255,255,0.03)", border:`1px solid ${M.border}`, borderRadius:12, overflow:"hidden" }}>
        <Row icon="globe"   label="Remote access"     sub="Reachable over Fluxora relay" right={<span style={{fontSize:11.5,color:M.success,fontWeight:600}}>On</span>}/>
        <Row icon="users"   label="Friends & family"  sub="3 people have access"        right={<Icon name="chevron" size={14} stroke="#64748B"/>}/>
        <Row icon="folder"  label="Shared libraries"  sub="Movies · Shows · Photos"      right={<Icon name="chevron" size={14} stroke="#64748B"/>}/>
      </div>

      <div style={{ fontSize:11, fontWeight:700, letterSpacing:1.4, color:M.fgDim, textTransform:"uppercase", margin:"18px 0 8px" }}>Performance</div>
      <div style={{ background:"rgba(255,255,255,0.03)", border:`1px solid ${M.border}`, borderRadius:12, overflow:"hidden" }}>
        <Row icon="cpu"     label="Hardware transcode" sub="Pixel Tensor G3 · enabled"   right={<span style={{fontSize:11.5,color:M.success,fontWeight:600}}>On</span>}/>
        <Row icon="bolt"    label="Background streaming" sub="Continue when phone is locked" right={<span style={{fontSize:11.5,color:M.fgMuted,fontWeight:600}}>Off</span>}/>
      </div>

      <button style={{ width:"100%", marginTop:18, padding:"14px", borderRadius:12, background:"rgba(239,68,68,0.10)", border:"1px solid rgba(239,68,68,0.3)", color:"#F87171", fontWeight:700, fontSize:13.5, fontFamily:"inherit", cursor:"pointer" }}>
        Stop server
      </button>
    </div>
  </div>
);

// 5 ─ Sign-in / 2FA prompt screen ───────────────────────────────────────
const SignInScreen = () => (
  <div style={{ background: M.bg, height: "100%", display: "flex", flexDirection: "column", color: M.fg, padding: "24px 22px" }}>
    <div style={{ marginTop: 24, fontSize: 11, color: M.accent, fontWeight: 700, letterSpacing: 1.6, textTransform: "uppercase" }}>Sign in</div>
    <div style={{ fontSize: 22, fontWeight: 800, marginTop: 6, letterSpacing: -0.3 }}>Welcome back, Alex</div>
    <div style={{ fontSize: 13, color: M.fgMuted, marginTop: 6 }}>Connecting to <span style={{ color: M.fg }}>atlas-server</span></div>

    <div style={{ marginTop: 24 }}>
      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.4, color: M.fgDim, textTransform: "uppercase", marginBottom: 6 }}>Email</div>
      <div style={{ height: 48, padding: "0 14px", display:"flex", alignItems:"center", borderRadius: 10, background: "rgba(255,255,255,0.04)", border: `1px solid ${M.border}`, color: M.fg, fontSize: 13.5 }}>
        alex@kepler.studio
      </div>

      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.4, color: M.fgDim, textTransform: "uppercase", margin: "14px 0 6px" }}>Password</div>
      <div style={{ height: 48, padding: "0 14px", display:"flex", alignItems:"center", borderRadius: 10, background: "rgba(255,255,255,0.04)", border: `1px solid ${M.accentSoft}`, color: M.fg, fontSize: 13.5, justifyContent: "space-between" }}>
        <span style={{ letterSpacing: 4 }}>••••••••••</span>
        <Icon name="eye" size={16} stroke="#94A3B8"/>
      </div>

      <button style={{ width:"100%", marginTop:18, height:48, borderRadius:10, border:"none", background:"linear-gradient(135deg, #8B5CF6, #A855F7)", color:"#fff", fontWeight:700, fontSize:14, fontFamily:"inherit", cursor:"pointer" }}>
        Sign in
      </button>

      <div style={{ display:"flex", alignItems:"center", gap:10, margin:"18px 0", color:M.fgDim, fontSize:11 }}>
        <div style={{ flex:1, height:1, background:M.border }}/> OR <div style={{ flex:1, height:1, background:M.border }}/>
      </div>

      <button style={{ width:"100%", height:48, borderRadius:10, border:`1px solid ${M.border}`, background:"rgba(255,255,255,0.03)", color:M.fg, fontWeight:600, fontSize:13.5, fontFamily:"inherit", cursor:"pointer", display:"inline-flex", alignItems:"center", justifyContent:"center", gap:10 }}>
        <Icon name="qr" size={18}/> Scan QR to sign in
      </button>
      <button style={{ width:"100%", marginTop:8, height:48, borderRadius:10, border:`1px solid ${M.border}`, background:"rgba(255,255,255,0.03)", color:M.fg, fontWeight:600, fontSize:13.5, fontFamily:"inherit", cursor:"pointer", display:"inline-flex", alignItems:"center", justifyContent:"center", gap:10 }}>
        <Icon name="key" size={18}/> Use 6-digit invite code
      </button>
    </div>

    <div style={{ flex: 1 }}/>
    <div style={{ textAlign:"center", fontSize: 11.5, color: M.fgMuted }}>
      By signing in you agree to our <span style={{ color: M.accent }}>Terms</span> &amp; <span style={{ color: M.accent }}>Privacy</span>.
    </div>
  </div>
);

// 6 ─ File browser (mixed file types — answers "can it handle other files") ─
const FileBrowserScreen = () => {
  const items = [
    { name:"Movies",      sub:"1,245 files · 892 GB", icon:"movie",  color:"#A855F7" },
    { name:"TV Shows",    sub:"324 files · 256 GB",   icon:"tv",     color:"#3B82F6" },
    { name:"Music",       sub:"1,023 files · 142 GB", icon:"music",  color:"#EC4899" },
    { name:"Photos",      sub:"487 files · 38 GB",    icon:"photo",  color:"#22D3EE" },
    { name:"Documents",   sub:"326 files · 8.4 GB",   icon:"doc",    color:"#F59E0B" },
    { name:"Books & PDFs",sub:"142 files · 1.2 GB",   icon:"book",   color:"#10B981" },
  ];
  const recent = [
    { name:"Project Brief — Atlas.pdf", sub:"2.4 MB · PDF · today",    icon:"doc"  },
    { name:"IMG_4521.jpg",              sub:"3.1 MB · JPEG · today",   icon:"photo" },
    { name:"Discovery — Daft Punk.flac",sub:"412 MB · FLAC · yesterday", icon:"music" },
    { name:"Q1 Financials.xlsx",        sub:"680 KB · XLSX · 3d ago",  icon:"file" },
  ];
  return (
    <div style={{ background: M.bg, height:"100%", display:"flex", flexDirection:"column", color:M.fg }}>
      <MAppBar title="All files" onBack={() => {}} trailing={<button style={{width:40,height:40,background:"none",border:"none",cursor:"pointer"}}><Icon name="search" size={18} stroke="#94A3B8"/></button>}/>
      <div style={{ flex:1, overflowY:"auto", padding:"6px 16px 18px" }}>
        <div style={{ fontSize:11, fontWeight:700, letterSpacing:1.4, color:M.fgDim, textTransform:"uppercase", margin:"6px 0 10px" }}>Categories</div>
        <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:10 }}>
          {items.map((it,i) => (
            <div key={i} style={{ padding:"14px 12px", borderRadius:12, background:"rgba(255,255,255,0.03)", border:`1px solid ${M.border}` }}>
              <div style={{ width:36, height:36, borderRadius:9, background:`${it.color}20`, display:"flex", alignItems:"center", justifyContent:"center" }}>
                <Icon name={it.icon} size={18} stroke={it.color}/>
              </div>
              <div style={{ fontSize:13.5, fontWeight:700, marginTop:10 }}>{it.name}</div>
              <div style={{ fontSize:11, color:M.fgMuted, marginTop:2 }}>{it.sub}</div>
            </div>
          ))}
        </div>

        <div style={{ fontSize:11, fontWeight:700, letterSpacing:1.4, color:M.fgDim, textTransform:"uppercase", margin:"22px 0 6px" }}>Recent files</div>
        <div style={{ background:"rgba(255,255,255,0.03)", border:`1px solid ${M.border}`, borderRadius:12 }}>
          {recent.map((r,i) => (
            <div key={i} style={{ display:"flex", alignItems:"center", gap:12, padding:"12px 14px", borderBottom: i < recent.length-1 ? `1px solid ${M.border}` : "none" }}>
              <div style={{ width:34,height:34,borderRadius:8, background:M.accentSoft, display:"flex", alignItems:"center", justifyContent:"center" }}>
                <Icon name={r.icon} size={16} stroke={M.accent}/>
              </div>
              <div style={{ flex:1, minWidth:0 }}>
                <div style={{ fontSize:13, fontWeight:600, color:M.fg, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{r.name}</div>
                <div style={{ fontSize:11, color:M.fgMuted, marginTop:2 }}>{r.sub}</div>
              </div>
              <Icon name="chevron" size={14} stroke="#64748B"/>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { DocViewerScreen, PhotoViewerScreen, MusicPlayerScreen, HostServerScreen, SignInScreen, FileBrowserScreen });

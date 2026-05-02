// ── Mobile flow diagram (graph of screens & how they connect) ───────────

const FlowNode = ({ x, y, w = 140, h = 90, label, kind = "screen", desc, accent }) => {
  const palette = {
    entry:   { bg: "linear-gradient(135deg, #8B5CF6, #A855F7)", fg: "#fff", stroke: "#A855F7" },
    screen:  { bg: "rgba(168,85,247,0.06)", fg: "#E2E8F0", stroke: "rgba(168,85,247,0.30)" },
    sheet:   { bg: "rgba(34,211,238,0.06)", fg: "#E2E8F0", stroke: "rgba(34,211,238,0.30)" },
    state:   { bg: "rgba(245,158,11,0.06)", fg: "#E2E8F0", stroke: "rgba(245,158,11,0.30)" },
    feature: { bg: "rgba(16,185,129,0.06)", fg: "#E2E8F0", stroke: "rgba(16,185,129,0.30)" },
  }[kind];
  return (
    <div style={{
      position: "absolute", left: x, top: y, width: w, height: h,
      background: palette.bg, border: `1px solid ${accent || palette.stroke}`,
      borderRadius: 12, padding: 12, color: palette.fg,
      display: "flex", flexDirection: "column", justifyContent: "center",
      boxShadow: kind === "entry" ? "0 8px 24px rgba(168,85,247,0.35)" : "0 2px 8px rgba(0,0,0,0.2)",
    }}>
      <div style={{ fontSize: 10.5, fontWeight: 700, letterSpacing: 1.2, color: kind === "entry" ? "rgba(255,255,255,0.7)" : "#94A3B8", textTransform: "uppercase" }}>
        {kind === "entry" ? "START" : kind === "sheet" ? "Sheet" : kind === "state" ? "State" : kind === "feature" ? "Feature" : "Screen"}
      </div>
      <div style={{ fontSize: 13, fontWeight: 700, marginTop: 4, lineHeight: 1.2 }}>{label}</div>
      {desc && <div style={{ fontSize: 10.5, color: kind === "entry" ? "rgba(255,255,255,0.75)" : "#94A3B8", marginTop: 4, lineHeight: 1.3 }}>{desc}</div>}
    </div>
  );
};

const FlowEdge = ({ from, to, label, dashed, color = "#A855F7", curve = 0 }) => {
  // Compute simple cubic path between two points.
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const cx1 = from.x + dx * 0.5 + curve;
  const cy1 = from.y;
  const cx2 = to.x - dx * 0.5 - curve;
  const cy2 = to.y;
  const path = `M ${from.x} ${from.y} C ${cx1} ${cy1}, ${cx2} ${cy2}, ${to.x} ${to.y}`;
  const mx = (from.x + to.x) / 2;
  const my = (from.y + to.y) / 2;
  return (
    <g>
      <path d={path} stroke={color} strokeWidth="1.5" fill="none" strokeDasharray={dashed ? "4 4" : "none"} markerEnd="url(#arrow)" opacity="0.65"/>
      {label && (
        <g transform={`translate(${mx}, ${my})`}>
          <rect x="-32" y="-9" width="64" height="18" rx="4" fill="#0F0C24" stroke="rgba(168,85,247,0.3)" strokeWidth="1"/>
          <text x="0" y="3" textAnchor="middle" fill="#CBD5E1" fontSize="10" fontFamily="Inter, sans-serif" fontWeight="600">{label}</text>
        </g>
      )}
    </g>
  );
};

const MobileFlowDiagram = () => {
  // Position helper: nodes and (x,y) center points
  const W = 140, H = 90;
  const center = (n) => ({ x: n.x + W/2, y: n.y + H/2 });
  const top    = (n) => ({ x: n.x + W/2, y: n.y });
  const bot    = (n) => ({ x: n.x + W/2, y: n.y + H });
  const left   = (n) => ({ x: n.x,       y: n.y + H/2 });
  const right  = (n) => ({ x: n.x + W,   y: n.y + H/2 });

  // Layout (left → right, grouped vertically)
  const splash    = { x: 40,   y: 280, label: "Splash", kind: "entry",   desc: "App launch · auth" };
  const server    = { x: 230,  y: 280, label: "Server picker", kind: "screen", desc: "Connect / reconnect" };
  const home      = { x: 430,  y: 280, label: "Home", kind: "screen", desc: "Hero · rails · continue" };

  // Above home — discovery
  const search    = { x: 430,  y: 110, label: "Search", kind: "screen", desc: "Recents · trending" };
  const library   = { x: 230,  y: 110, label: "Library", kind: "screen", desc: "Movies · Shows · Music" };

  // Below home — system
  const downloads = { x: 230,  y: 470, label: "Downloads", kind: "screen", desc: "Offline + queue" };
  const profile   = { x: 40,   y: 470, label: "Profile", kind: "screen", desc: "Account · settings" };
  const notifs    = { x: 40,   y: 110, label: "Notifications", kind: "screen", desc: "Activity feed" };
  const offline   = { x: 40,   y: 600, label: "Offline state", kind: "state", desc: "No server reachable" };

  // Right of home — title & playback
  const detail    = { x: 640,  y: 280, label: "Title detail", kind: "screen", desc: "Synopsis · cast · play" };
  const episodes  = { x: 640,  y: 110, label: "Episodes list", kind: "screen", desc: "Seasons · download" };
  const player    = { x: 870,  y: 280, label: "Player · Portrait", kind: "screen", desc: "Tap → fullscreen" };
  const playerL   = { x: 1080, y: 280, label: "Player · Landscape", kind: "screen", desc: "Gestures · scrub" };

  // Above player — sheets (modal overlays)
  const audioSubs = { x: 870,  y: 110, label: "Audio & Subs", kind: "sheet" };
  const quality   = { x: 1080, y: 110, label: "Quality", kind: "sheet" };
  const speed     = { x: 1080, y: 30,  label: "Speed", kind: "sheet" };
  const sleep     = { x: 870,  y: 30,  label: "Sleep timer", kind: "sheet" };

  // Below player — features
  const cast      = { x: 870,  y: 470, label: "Cast picker", kind: "sheet" };
  const xray      = { x: 1080, y: 470, label: "X-Ray panel", kind: "feature", desc: "Cast · trivia" };
  const groupW    = { x: 1080, y: 600, label: "Group Watch", kind: "feature", desc: "Co-watch · invite" };
  const mini      = { x: 870,  y: 600, label: "Mini-player", kind: "state",   desc: "PiP · dock" };

  return (
    <div style={{
      width: 1640, height: 760, marginTop: 18,
      background: "#0c0a1c", border: `1px solid ${M.border}`,
      borderRadius: 16, color: M.fg, position: "relative", overflow: "hidden",
      fontFamily: "Inter, system-ui, sans-serif",
    }}>
      {/* Header */}
      <div style={{ position: "absolute", top: 18, left: 22, right: 22, display: "flex", justifyContent: "space-between", alignItems: "flex-start", zIndex: 2 }}>
        <div>
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.6, color: M.accent, textTransform: "uppercase" }}>App flow</div>
          <div style={{ fontSize: 18, fontWeight: 800, color: M.fg, marginTop: 2, letterSpacing: -0.3 }}>Fluxora Mobile · screens & navigation</div>
        </div>
        <div style={{ display: "flex", gap: 16, fontSize: 11, color: M.fgMuted }}>
          {[
            { c: "#A855F7", l: "Screen" },
            { c: "#22D3EE", l: "Modal sheet" },
            { c: "#F59E0B", l: "State" },
            { c: "#10B981", l: "Feature" },
          ].map(k => (
            <div key={k.l} style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
              <span style={{ width: 10, height: 10, borderRadius: 3, background: k.c, opacity: 0.8 }}/> {k.l}
            </div>
          ))}
        </div>
      </div>

      {/* Background grid */}
      <svg width="100%" height="100%" style={{ position: "absolute", inset: 0, opacity: 0.5 }}>
        <defs>
          <pattern id="grid" width="32" height="32" patternUnits="userSpaceOnUse">
            <path d="M 32 0 L 0 0 0 32" fill="none" stroke="rgba(255,255,255,0.025)" strokeWidth="1"/>
          </pattern>
          <marker id="arrow" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto">
            <path d="M0,0 L0,6 L9,3 z" fill="#A855F7" opacity="0.7"/>
          </marker>
        </defs>
        <rect width="100%" height="100%" fill="url(#grid)"/>

        {/* Edges */}
        <FlowEdge from={right(splash)}  to={left(server)}   label="connected"/>
        <FlowEdge from={right(server)}  to={left(home)}     label="enter"/>
        <FlowEdge from={top(home)}      to={bot(library)}   label="tab"/>
        <FlowEdge from={top(home)}      to={bot(search)}    label="tab"/>
        <FlowEdge from={top(library)}   to={bot(notifs)}    dashed/>
        <FlowEdge from={bot(home)}      to={top(downloads)} label="tab"/>
        <FlowEdge from={bot(downloads)} to={top(profile)}   dashed/>
        <FlowEdge from={left(profile)}  to={right({x: -120, y: 470})} dashed/>
        <FlowEdge from={bot(profile)}   to={top(offline)}   dashed color="#F59E0B"/>

        <FlowEdge from={right(home)}    to={left(detail)}   label="tap poster"/>
        <FlowEdge from={top(detail)}    to={bot(episodes)}  label="show"/>
        <FlowEdge from={right(detail)}  to={left(player)}   label="play ▶"/>
        <FlowEdge from={right(player)}  to={left(playerL)}  label="rotate"/>

        <FlowEdge from={top(player)}    to={bot(audioSubs)} dashed color="#22D3EE"/>
        <FlowEdge from={top(playerL)}   to={bot(quality)}   dashed color="#22D3EE"/>
        <FlowEdge from={top(quality)}   to={bot(speed)}     dashed color="#22D3EE"/>
        <FlowEdge from={top(audioSubs)} to={bot(sleep)}     dashed color="#22D3EE"/>

        <FlowEdge from={bot(player)}    to={top(cast)}      label="cast"  color="#22D3EE"/>
        <FlowEdge from={bot(playerL)}   to={top(xray)}      label="X-Ray" color="#10B981"/>
        <FlowEdge from={bot(xray)}      to={top(groupW)}    dashed color="#10B981"/>
        <FlowEdge from={bot(cast)}      to={top(mini)}      dashed color="#F59E0B"/>
        <FlowEdge from={left(mini)}     to={right({x: 750, y: 645})} dashed color="#F59E0B"/>
      </svg>

      {/* Nodes */}
      {[splash, server, home, search, library, notifs, downloads, profile, offline,
        detail, episodes, player, playerL, audioSubs, quality, speed, sleep,
        cast, xray, groupW, mini].map((n, i) => (
        <FlowNode key={i} {...n}/>
      ))}
    </div>
  );
};

window.MobileFlowDiagram = MobileFlowDiagram;

// ── Player gestures + controls legend (below landscape player) ──────────

const LegendCol = ({ title, items }) => (
  <div style={{ flex: 1, minWidth: 0 }}>
    <div style={{
      fontSize: 11, fontWeight: 700, letterSpacing: 1.6,
      color: M.accent, textTransform: "uppercase", marginBottom: 16,
    }}>{title}</div>
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      {items.map((it, i) => (
        <div key={i} style={{ display: "flex", gap: 12, alignItems: "flex-start" }}>
          <div style={{
            width: 34, height: 34, borderRadius: 8, flexShrink: 0,
            background: "rgba(168,85,247,0.10)", border: `1px solid ${M.border}`,
            color: M.accent, display: "flex", alignItems: "center", justifyContent: "center",
            fontSize: 11, fontWeight: 700,
          }}>
            {it.iconNode || <Icon name={it.icon} size={16} stroke={M.accent}/>}
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: M.fg, lineHeight: 1.2 }}>{it.title}</div>
            <div style={{ fontSize: 11.5, color: M.fgMuted, marginTop: 3, lineHeight: 1.35 }}>{it.sub}</div>
          </div>
        </div>
      ))}
    </div>
  </div>
);

const swipeIcon = (dir) => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#A855F7" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
    <path d="M9 11V6a3 3 0 0 1 6 0v8"/>
    <path d="M15 14V9a2 2 0 0 1 4 0v9a4 4 0 0 1-4 4H9a4 4 0 0 1-4-4l-2-5"/>
    {dir === "up" && <path d="M2 13l3-3 3 3"/>}
    {dir === "lr" && <path d="M2 17h6M5 14l-3 3 3 3"/>}
  </svg>
);

const PlayerLegend = () => (
  <div style={{
    width: 1640, marginTop: 18, padding: "26px 28px",
    background: "#0c0a1c", border: `1px solid ${M.border}`,
    borderRadius: 16, color: M.fg, fontFamily: "Inter, system-ui, sans-serif",
    display: "flex", gap: 36, alignItems: "flex-start",
  }}>
    <LegendCol title="Gestures" items={[
      { iconNode: swipeIcon("up"), title: "Brightness", sub: "Swipe up & down on left side" },
      { icon: "wifi",   title: "Volume",     sub: "Swipe up & down on right side" },
      { iconNode: swipeIcon("lr"), title: "Seek", sub: "Swipe left & right anywhere on screen" },
      { icon: "refresh",title: "Double Tap", sub: "Left: Rewind 10s · Right: Forward 10s" },
    ]}/>
    <LegendCol title="Playback Controls" items={[
      { icon: "refresh", title: "Rewind 10s",   sub: "Go back 10 seconds" },
      { icon: "pause",   title: "Play / Pause", sub: "Play or pause the video" },
      { icon: "refresh", title: "Forward 10s",  sub: "Forward 10 seconds" },
      { icon: "minus",   title: "Progress Bar", sub: "Tap or drag to seek" },
      { icon: "diamond", title: "Chapters / Markers", sub: "Tap on markers to jump" },
    ]}/>
    <LegendCol title="More Controls" items={[
      { icon: "bolt",    title: "Speed",            sub: "0.25×, 0.5×, 1×, 1.25×, 1.5×, 2×" },
      { icon: "msg",     title: "Audio & Subtitles",sub: "Choose audio track and subtitle options" },
      { icon: "play",    title: "Next Episode",     sub: "Play next episode automatically" },
      { icon: "list",    title: "Playlist",         sub: "View current playlist or queue" },
      { icon: "grid",    title: "Resize",           sub: "Fit, Fill or Zoom" },
      { icon: "tv",      title: "Picture in Picture", sub: "Continue watching in mini player" },
      { icon: "extLink", title: "Cast",             sub: "Cast to your TV" },
      { icon: "moreH",   title: "More",             sub: "Additional settings and options" },
    ]}/>
    <LegendCol title="Additional Features" items={[
      { icon: "x",          title: "X-Ray",       sub: "View cast, trivia and more" },
      { icon: "doc",        title: "Subtitles",   sub: "Turn subtitles on / off" },
      { icon: "wifi",       title: "Audio Settings", sub: "Adjust audio output" },
      { icon: "history2",   title: "Sleep Timer", sub: "Stop playback after set time" },
      { icon: "diamond",    title: "Quality",     sub: "Auto, 480p, 720p, 1080p, 4K (2160p)" },
    ]}/>
  </div>
);

window.PlayerLegend = PlayerLegend;

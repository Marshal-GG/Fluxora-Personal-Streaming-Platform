// ── Video Player — Portrait (vertical / mini-player friendly) ───────────

const PlayerPortrait = () => (
  <div style={{
    width: "100%", height: "100%", position: "relative",
    background: "#000", overflow: "hidden", color: "#fff",
    fontFamily: "Inter, Roboto, system-ui, sans-serif",
  }}>
    {/* video tile */}
    <div style={{ position: "relative", width: "100%", height: 220 }}>
      <div style={{
        position: "absolute", inset: 0,
        background:
          "radial-gradient(60% 70% at 50% 65%, #1a2238 0%, #050810 65%, #000 100%)",
      }}/>
      <div style={{
        position: "absolute", inset: 0, opacity: 0.6,
        backgroundImage:
          "radial-gradient(1px 1px at 14% 18%, #fff, transparent)," +
          "radial-gradient(1px 1px at 32% 12%, #fff, transparent)," +
          "radial-gradient(1px 1px at 58% 22%, #fff, transparent)," +
          "radial-gradient(1px 1px at 78% 14%, #fff, transparent)," +
          "radial-gradient(1px 1px at 88% 28%, #fff, transparent)",
      }}/>
      <div style={{
        position: "absolute", left: 0, right: 0, top: "65%", height: "16%",
        background: "linear-gradient(to bottom, rgba(244,150,90,0.5), transparent)",
        filter: "blur(8px)",
      }}/>
      <div style={{ position: "absolute", inset: 0, background: "linear-gradient(180deg, rgba(0,0,0,0.55), rgba(0,0,0,0.1) 30%, rgba(0,0,0,0.1) 70%, rgba(0,0,0,0.6))" }}/>

      {/* top bar */}
      <div style={{
        position: "absolute", top: 12, left: 10, right: 10,
        display: "flex", alignItems: "center", gap: 6,
      }}>
        <button style={pIconBtn}><Icon name="chevronD" size={18} stroke="#fff"/></button>
        <div style={{ flex: 1 }}/>
        <button style={pIconBtn}><Icon name="extLink" size={15} stroke="#fff"/></button>
        <button style={pIconBtn}><Icon name="grid" size={15} stroke="#fff"/></button>
        <button style={pIconBtn}><Icon name="moreH" size={15} stroke="#fff"/></button>
      </div>

      {/* center play */}
      <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: 30 }}>
        <CircBtn size={42}><Icon name="refresh" size={16} stroke="#fff" style={{ transform: "scaleX(-1)" }}/></CircBtn>
        <CircBtn size={62} primary><Icon name="pause" size={22} stroke="#fff"/></CircBtn>
        <CircBtn size={42}><Icon name="refresh" size={16} stroke="#fff"/></CircBtn>
      </div>

      {/* progress bottom */}
      <div style={{ position: "absolute", left: 14, right: 14, bottom: 10, display: "flex", alignItems: "center", gap: 8 }}>
        <span style={{ fontSize: 10.5, color: "rgba(255,255,255,0.85)", fontVariantNumeric: "tabular-nums" }}>1:12:45</span>
        <div style={{ flex: 1, height: 3, background: "rgba(255,255,255,0.18)", borderRadius: 999, position: "relative" }}>
          <div style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: "44%", background: "linear-gradient(90deg, #8B5CF6, #A855F7)", borderRadius: 999 }}/>
          <div style={{ position: "absolute", left: "44%", top: "50%", transform: "translate(-50%,-50%)", width: 11, height: 11, borderRadius: "50%", background: "#fff", boxShadow: "0 0 0 3px rgba(168,85,247,0.35)" }}/>
        </div>
        <span style={{ fontSize: 10.5, color: "rgba(255,255,255,0.85)", fontVariantNumeric: "tabular-nums" }}>2:49:03</span>
      </div>
    </div>

    {/* metadata + controls below */}
    <div style={{ background: "#08061A", padding: "16px", height: "calc(100% - 220px)", overflowY: "auto" }}>
      <div style={{ fontSize: 22, fontWeight: 800, letterSpacing: -0.4, color: "#fff" }}>Interstellar</div>
      <div style={{
        marginTop: 6, fontSize: 12, color: "rgba(255,255,255,0.65)",
        display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap",
      }}>
        <span>2014</span><span>·</span>
        <span>2h 49m</span><span>·</span>
        <span style={{ color: "#22D3EE", fontWeight: 600 }}>★ 8.7</span><span>·</span>
        <span style={{ color: "#E9D5FF" }}>4K HDR · Atmos</span>
      </div>

      {/* quick controls grid */}
      <div style={{ marginTop: 16, display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 10 }}>
        {[
          { icon: "msg", label: "Audio · EN" },
          { icon: "doc", label: "Subs · EN" },
          { icon: "extLink", label: "Cast" },
          { icon: "bolt", label: "1.0×" },
          { icon: "diamond", label: "1080p" },
          { icon: "history2", label: "Sleep" },
          { icon: "list", label: "Episodes" },
          { icon: "moreH", label: "More" },
        ].map(b => (
          <button key={b.label} style={{
            background: "rgba(255,255,255,0.04)", border: `1px solid ${M.border}`,
            borderRadius: 12, padding: "12px 6px", color: M.fgMuted,
            display: "flex", flexDirection: "column", alignItems: "center", gap: 6,
            cursor: "pointer", fontFamily: "inherit",
          }}>
            <Icon name={b.icon} size={18} stroke="#94A3B8"/>
            <span style={{ fontSize: 10.5, fontWeight: 600, color: M.fg }}>{b.label}</span>
          </button>
        ))}
      </div>

      {/* up next */}
      <div style={{ marginTop: 22, fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: M.fgDim, textTransform: "uppercase" }}>Up next</div>
      <div style={{ marginTop: 10, display: "flex", gap: 12, alignItems: "center", padding: "12px", background: "rgba(255,255,255,0.03)", border: `1px solid ${M.border}`, borderRadius: 12 }}>
        <Poster art="linear-gradient(135deg, #1a0f2e, #6b3aa6)" w={56} h={80} radius={8}/>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 13.5, fontWeight: 700, color: M.fg }}>Inception</div>
          <div style={{ fontSize: 11, color: M.fgMuted, marginTop: 3 }}>2010 · 2h 28m · 1080p HDR</div>
          <div style={{ marginTop: 6, fontSize: 11, color: M.accent, fontWeight: 600 }}>Auto-play in 8s</div>
        </div>
        <button style={{
          padding: "8px 14px", borderRadius: 999, border: "none",
          background: "linear-gradient(135deg, #8B5CF6, #A855F7)",
          color: "#fff", fontSize: 12, fontWeight: 700, cursor: "pointer", fontFamily: "inherit",
        }}>Play</button>
      </div>
    </div>
  </div>
);

window.PlayerPortrait = PlayerPortrait;

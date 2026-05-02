// ── Video Player — Landscape (matches reference) ────────────────────────

const PlayerLandscape = () => {
  return (
    <div style={{
      width: "100%", height: "100%", position: "relative",
      background: "#000", overflow: "hidden",
      fontFamily: "Inter, Roboto, system-ui, sans-serif", color: "#fff",
    }}>
      {/* poster image / video frame */}
      <div style={{
        position: "absolute", inset: 0,
        background:
          "radial-gradient(80% 70% at 50% 65%, #1a2238 0%, #050810 60%, #000 100%)",
      }}/>
      {/* faux scene art — astronaut silhouette via radial */}
      <div style={{
        position: "absolute", inset: 0,
        background:
          "radial-gradient(40% 60% at 50% 70%, rgba(40,30,80,0.65), transparent 60%)," +
          "linear-gradient(180deg, #07101e 0%, #1d2750 35%, #2a2230 60%, #4a2a18 80%, #1a0e0a 100%)",
      }}/>
      {/* horizon glow */}
      <div style={{
        position: "absolute", left: 0, right: 0, top: "55%", height: "12%",
        background: "linear-gradient(to bottom, rgba(244,150,90,0.45), transparent)",
        filter: "blur(6px)",
      }}/>
      {/* stars */}
      <div style={{
        position: "absolute", inset: 0, opacity: 0.7,
        backgroundImage:
          "radial-gradient(1px 1px at 12% 14%, #fff, transparent)," +
          "radial-gradient(1px 1px at 28% 9%, #fff, transparent)," +
          "radial-gradient(1px 1px at 41% 18%, #fff, transparent)," +
          "radial-gradient(1px 1px at 63% 11%, #fff, transparent)," +
          "radial-gradient(1px 1px at 76% 21%, #fff, transparent)," +
          "radial-gradient(1px 1px at 88% 8%, #fff, transparent)",
      }}/>
      {/* dark overlay for control legibility */}
      <div style={{
        position: "absolute", inset: 0,
        background: "linear-gradient(180deg, rgba(0,0,0,0.55) 0%, rgba(0,0,0,0.15) 25%, rgba(0,0,0,0.15) 70%, rgba(0,0,0,0.7) 100%)",
      }}/>

      {/* ── TOP BAR ──────────────────────────────────── */}
      <div style={{
        position: "absolute", top: 14, left: 14, right: 14,
        display: "flex", alignItems: "center", gap: 10,
      }}>
        <button style={pIconBtn}><Icon name="chevronL" size={18} stroke="#fff"/></button>
        <button style={{
          ...pIconBtn, width: "auto", padding: "0 12px", gap: 6,
          background: "rgba(0,0,0,0.4)",
        }}>
          <span style={{ fontSize: 12, fontWeight: 600, color: "#E9D5FF" }}>X-Ray</span>
          <Icon name="chevron" size={12} stroke="#94A3B8"/>
        </button>
        <div style={{ flex: 1, textAlign: "center" }}>
          <div style={{ fontSize: 15, fontWeight: 700, letterSpacing: -0.1 }}>Interstellar (2014)</div>
          <div style={{
            display: "inline-flex", alignItems: "center", gap: 6, marginTop: 2,
            fontSize: 10.5, color: "rgba(255,255,255,0.65)",
          }}>
            <span style={{
              padding: "2px 6px", borderRadius: 4, background: "rgba(168,85,247,0.22)",
              color: "#E9D5FF", fontWeight: 600,
            }}>Dual Audio</span>
            <span>· 1080p · Dolby Atmos</span>
          </div>
        </div>
        <div style={{ display: "flex", gap: 6 }}>
          <button style={pIconBtn}><Icon name="extLink" size={16} stroke="#fff"/></button>
          <button style={pIconBtn}><Icon name="msg" size={16} stroke="#fff"/></button>
          <button style={pIconBtn}><Icon name="layers" size={16} stroke="#fff"/></button>
          <button style={pIconBtn}><Icon name="moreH" size={16} stroke="#fff"/></button>
        </div>
      </div>

      {/* ── LEFT BRIGHTNESS SLIDER ─────────────────── */}
      <div style={{
        position: "absolute", top: "50%", left: 18, transform: "translateY(-50%)",
        display: "flex", flexDirection: "column", alignItems: "center", gap: 6,
      }}>
        <Icon name="chevronD" size={14} stroke="#fff" style={{ transform: "rotate(180deg)", opacity: 0.7 }}/>
        <SideSlider value={0.55} icon="sun" topIcon="sun"/>
      </div>
      <button style={{
        position: "absolute", top: "50%", left: 78, transform: "translateY(-50%)",
        width: 38, height: 38, borderRadius: 999,
        background: "rgba(0,0,0,0.55)", border: "1px solid rgba(255,255,255,0.12)",
        display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer",
      }}><Icon name="shield" size={16} stroke="#fff"/></button>

      {/* ── CENTER PLAYBACK BUTTONS ─────────────────── */}
      <div style={{
        position: "absolute", left: "50%", top: "48%",
        transform: "translate(-50%, -50%)",
        display: "flex", alignItems: "center", gap: 38,
      }}>
        <CircBtn size={62}><Icon name="refresh" size={22} stroke="#fff" style={{ transform: "scaleX(-1)" }}/>
          <span style={tinyLbl}>10</span>
        </CircBtn>
        <CircBtn size={86} primary>
          <Icon name="pause" size={32} stroke="#fff"/>
        </CircBtn>
        <CircBtn size={62}><Icon name="refresh" size={22} stroke="#fff"/>
          <span style={tinyLbl}>10</span>
        </CircBtn>
      </div>

      {/* ── RIGHT VOLUME SLIDER ─────────────────────── */}
      <div style={{
        position: "absolute", top: "50%", right: 18, transform: "translateY(-50%)",
        display: "flex", flexDirection: "column", alignItems: "center", gap: 6,
      }}>
        <Icon name="sun" size={14} stroke="#fff" style={{ opacity: 0.85 }}/>
        <SideSlider value={0.78} accent="#A855F7" />
        <Icon name="sun" size={14} stroke="#fff" style={{ opacity: 0.5 }}/>
      </div>
      <button style={{
        position: "absolute", top: "50%", right: 78, transform: "translateY(-50%)",
        width: 38, height: 38, borderRadius: 999,
        background: "rgba(0,0,0,0.55)", border: "1px solid rgba(255,255,255,0.12)",
        display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer",
      }}><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
        <path d="M11 5 6 9H2v6h4l5 4V5z"/>
        <path d="M15.54 8.46a5 5 0 0 1 0 7.07"/>
      </svg></button>

      {/* ── PROGRESS BAR ─────────────────────────────── */}
      <div style={{
        position: "absolute", left: 18, right: 18, bottom: 78,
        display: "flex", alignItems: "center", gap: 10,
      }}>
        <span style={{ fontSize: 11.5, fontVariantNumeric: "tabular-nums", color: "rgba(255,255,255,0.85)", minWidth: 44 }}>1:12:45</span>
        <div style={{ flex: 1, height: 4, background: "rgba(255,255,255,0.18)", borderRadius: 999, position: "relative" }}>
          <div style={{
            position: "absolute", left: 0, top: 0, bottom: 0, width: "44%",
            background: "linear-gradient(90deg, #8B5CF6, #A855F7)", borderRadius: 999,
          }}/>
          {/* chapter dots */}
          <div style={{ position: "absolute", left: "62%", top: "50%", transform: "translate(-50%,-50%)", width: 5, height: 5, borderRadius: 999, background: M.accent }}/>
          {/* scrubber */}
          <div style={{
            position: "absolute", left: "44%", top: "50%", transform: "translate(-50%,-50%)",
            width: 14, height: 14, borderRadius: "50%", background: "#fff",
            boxShadow: "0 0 0 4px rgba(168,85,247,0.35)",
          }}/>
        </div>
        <span style={{ fontSize: 11.5, fontVariantNumeric: "tabular-nums", color: "rgba(255,255,255,0.85)", minWidth: 44, textAlign: "right" }}>2:49:03</span>
      </div>

      {/* ── BOTTOM BAR ───────────────────────────────── */}
      <div style={{
        position: "absolute", left: 0, right: 0, bottom: 14,
        padding: "0 18px", display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8,
      }}>
        {[
          { icon: "shield", label: "Lock" },
          { icon: "tv",     label: "Screen" },
          { icon: "bolt",   label: "Speed" },
          { icon: "msg",    label: "Audio & Subs" },
        ].map(b => <BotBtn key={b.label} {...b}/>)}
        <button style={{
          padding: "8px 20px", borderRadius: 999,
          background: "rgba(0,0,0,0.55)", border: "1px solid rgba(255,255,255,0.18)",
          color: "#fff", fontSize: 13, fontWeight: 600,
          display: "inline-flex", alignItems: "center", gap: 6, cursor: "pointer", fontFamily: "inherit",
        }}>Episodes <Icon name="chevronD" size={13} stroke="#fff" style={{ transform: "rotate(180deg)" }}/></button>
        {[
          { icon: "play",   label: "Next Episode" },
          { icon: "list",   label: "Playlist" },
          { icon: "grid",   label: "Resize" },
          { icon: "moreH",  label: "More" },
        ].map(b => <BotBtn key={b.label} {...b}/>)}
      </div>
    </div>
  );
};

// ── helpers ─────────────────────────────────────────────────────────────
const pIconBtn = {
  width: 36, height: 36, borderRadius: 999,
  background: "rgba(0,0,0,0.4)", border: "1px solid rgba(255,255,255,0.1)",
  color: "#fff", display: "flex", alignItems: "center", justifyContent: "center",
  cursor: "pointer", backdropFilter: "blur(6px)",
};

const tinyLbl = {
  position: "absolute", fontSize: 9.5, fontWeight: 700, color: "#fff", letterSpacing: 0.3,
  marginTop: 2,
};

const CircBtn = ({ size = 60, primary, children }) => (
  <button style={{
    width: size, height: size, borderRadius: "50%",
    background: primary ? "rgba(0,0,0,0.65)" : "rgba(0,0,0,0.55)",
    border: primary ? "1.5px solid rgba(255,255,255,0.85)" : "1px solid rgba(255,255,255,0.55)",
    display: "flex", alignItems: "center", justifyContent: "center",
    backdropFilter: "blur(6px)", color: "#fff", cursor: "pointer",
    position: "relative",
    boxShadow: primary ? "0 8px 30px rgba(168,85,247,0.3)" : "none",
  }}>{children}</button>
);

const BotBtn = ({ icon, label }) => (
  <button style={{
    background: "none", border: "none", display: "flex", flexDirection: "column",
    alignItems: "center", gap: 4, color: "rgba(255,255,255,0.85)", cursor: "pointer",
    padding: "4px 6px", fontFamily: "inherit",
  }}>
    <Icon name={icon} size={18} stroke="#fff"/>
    <span style={{ fontSize: 10, fontWeight: 500 }}>{label}</span>
  </button>
);

const SideSlider = ({ value = 0.5, accent = "#A855F7" }) => (
  <div style={{
    width: 4, height: 130, background: "rgba(255,255,255,0.2)",
    borderRadius: 999, position: "relative",
  }}>
    <div style={{
      position: "absolute", left: 0, right: 0, bottom: 0, height: `${value*100}%`,
      background: accent, borderRadius: 999,
    }}/>
    <div style={{
      position: "absolute", left: "50%", bottom: `${value*100}%`,
      transform: "translate(-50%, 50%)",
      width: 12, height: 12, borderRadius: "50%", background: "#fff",
      boxShadow: `0 0 0 3px ${accent}55`,
    }}/>
  </div>
);

window.PlayerLandscape = PlayerLandscape;

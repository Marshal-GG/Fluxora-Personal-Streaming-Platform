// ── Fluxora Mobile primitives + theme ───────────────────────────────────
// Reusable mobile-flavored UI built on top of the desktop's brand DNA.

const M = {
  // Brand palette — matches desktop
  bg: "#08061A",
  bgRaised: "#0F0C24",
  bgCard: "rgba(20,18,38,0.85)",
  border: "rgba(255,255,255,0.06)",
  borderStrong: "rgba(255,255,255,0.12)",
  fg: "#F1F5F9",
  fgMuted: "#94A3B8",
  fgDim: "#64748B",
  accent: "#A855F7",
  accent2: "#8B5CF6",
  accentSoft: "rgba(168,85,247,0.16)",
  cyan: "#22D3EE",
  pink: "#EC4899",
  success: "#10B981",
  warn: "#F59E0B",
  danger: "#EF4444",
  bgGradient:
    "radial-gradient(120% 60% at 0% 0%, rgba(168,85,247,0.18), transparent 50%)," +
    "radial-gradient(100% 60% at 100% 100%, rgba(34,211,238,0.10), transparent 50%)," +
    "#08061A",
};

// Phone shell — Fluxora-themed (replaces the M3 light AndroidDevice)
// width 412, height 892 by default (Pixel-7-ish). Pass orientation="landscape"
// to flip dimensions.
const Phone = ({
  children,
  width,
  height,
  orientation = "portrait",
  showStatus = true,
  showNav = true,
  statusFg = "#FFFFFF",
  bg = M.bg,
  notch = true,
  bezel = 10,
  radius = 38,
  style,
}) => {
  const w = width  ?? (orientation === "landscape" ? 892 : 412);
  const h = height ?? (orientation === "landscape" ? 412 : 892);
  return (
    <div style={{
      width: w, height: h, borderRadius: radius, overflow: "hidden",
      background: "#0a0814",
      border: `${bezel}px solid #1a1828`,
      boxShadow: "0 30px 80px rgba(0,0,0,0.55), inset 0 0 0 1px rgba(255,255,255,0.04)",
      display: "flex", flexDirection: orientation === "landscape" ? "row" : "column",
      boxSizing: "border-box", position: "relative",
      fontFamily: "Inter, Roboto, system-ui, sans-serif",
      color: M.fg,
      ...style,
    }}>
      <div style={{
        flex: 1, minHeight: 0, minWidth: 0,
        background: bg,
        display: "flex", flexDirection: "column",
        position: "relative", overflow: "hidden",
      }}>
        {showStatus && orientation === "portrait" && (
          <PhoneStatusBar fg={statusFg} notch={notch}/>
        )}
        <div style={{ flex: 1, minHeight: 0, position: "relative", overflow: "hidden" }}>
          {children}
        </div>
        {showNav && orientation === "portrait" && <PhoneNavPill fg={statusFg}/>}
      </div>
      {orientation === "landscape" && showNav && (
        <div style={{
          width: 18, display: "flex", alignItems: "center", justifyContent: "center",
        }}>
          <div style={{
            width: 4, height: 80, borderRadius: 2,
            background: statusFg, opacity: 0.4,
          }}/>
        </div>
      )}
    </div>
  );
};

const PhoneStatusBar = ({ fg = "#FFFFFF", notch = true }) => (
  <div style={{
    height: 36, flexShrink: 0, display: "flex", alignItems: "center",
    justifyContent: "space-between", padding: "0 22px",
    position: "relative", zIndex: 5,
  }}>
    <span style={{ fontSize: 14, fontWeight: 600, color: fg, letterSpacing: 0.2 }}>9:41</span>
    {notch && (
      <div style={{
        position: "absolute", left: "50%", top: 8, transform: "translateX(-50%)",
        width: 26, height: 26, borderRadius: "50%", background: "#000",
        boxShadow: "inset 0 0 0 1.5px rgba(255,255,255,0.04)",
      }}/>
    )}
    <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
      {/* signal */}
      <svg width="15" height="11" viewBox="0 0 15 11" fill={fg}>
        <rect x="0"  y="7" width="2.5" height="4" rx="0.5"/>
        <rect x="4"  y="5" width="2.5" height="6" rx="0.5"/>
        <rect x="8"  y="3" width="2.5" height="8" rx="0.5"/>
        <rect x="12" y="0" width="2.5" height="11" rx="0.5"/>
      </svg>
      {/* wifi */}
      <svg width="15" height="11" viewBox="0 0 16 12" fill={fg}>
        <path d="M8 11.3L0.67 4.5a10.37 10.37 0 0114.66 0L8 11.3z" fillOpacity="0.95"/>
      </svg>
      {/* battery */}
      <svg width="22" height="11" viewBox="0 0 22 11">
        <rect x="0.5" y="0.5" width="18" height="10" rx="2.5" fill="none" stroke={fg} strokeOpacity="0.6"/>
        <rect x="2"   y="2"   width="14" height="7"  rx="1.5" fill={fg}/>
        <rect x="19.5" y="3.5" width="2"  height="4"  rx="1" fill={fg} fillOpacity="0.7"/>
      </svg>
    </div>
  </div>
);

const PhoneNavPill = ({ fg = "#FFFFFF" }) => (
  <div style={{
    height: 22, flexShrink: 0, display: "flex",
    alignItems: "center", justifyContent: "center",
    position: "relative", zIndex: 5,
  }}>
    <div style={{
      width: 124, height: 4, borderRadius: 2, background: fg, opacity: 0.6,
    }}/>
  </div>
);

// ── Bottom tab bar ──────────────────────────────────────────────────────
const TAB_ITEMS = [
  { id: "home",      label: "Home",       icon: "dashboard" },
  { id: "library",   label: "Library",    icon: "library" },
  { id: "search",    label: "Search",     icon: "search" },
  { id: "downloads", label: "Downloads",  icon: "download" },
  { id: "profile",   label: "Profile",    icon: "user" },
];

const BottomTabs = ({ active = "home", onChange = () => {}, style }) => (
  <div style={{
    flexShrink: 0,
    background: "rgba(8,6,20,0.92)",
    borderTop: `1px solid ${M.border}`,
    backdropFilter: "blur(20px)",
    padding: "8px 6px 6px",
    display: "flex", alignItems: "center", justifyContent: "space-around",
    ...style,
  }}>
    {TAB_ITEMS.map(t => {
      const on = active === t.id;
      return (
        <button key={t.id} onClick={() => onChange(t.id)} style={{
          background: "none", border: "none", flex: 1,
          display: "flex", flexDirection: "column", alignItems: "center", gap: 4,
          padding: "6px 0", cursor: "pointer", color: on ? M.accent : M.fgDim,
        }}>
          <Icon name={t.icon} size={22} stroke={on ? M.accent : "#94A3B8"}/>
          <span style={{ fontSize: 10.5, fontWeight: on ? 700 : 500, letterSpacing: 0.1 }}>{t.label}</span>
        </button>
      );
    })}
  </div>
);

// ── Mobile chip / pill ──────────────────────────────────────────────────
const MChip = ({ children, active, onClick, style }) => (
  <button onClick={onClick} style={{
    border: active ? `1px solid ${M.accent}` : `1px solid ${M.border}`,
    background: active ? M.accentSoft : "rgba(255,255,255,0.03)",
    color: active ? "#E9D5FF" : M.fgMuted,
    padding: "7px 14px", borderRadius: 999, fontSize: 12.5, fontWeight: 600,
    fontFamily: "inherit", cursor: "pointer", whiteSpace: "nowrap",
    ...style,
  }}>{children}</button>
);

// ── Mobile App Bar ──────────────────────────────────────────────────────
const MAppBar = ({ title, leading, trailing, transparent, onBack, style }) => (
  <div style={{
    height: 52, flexShrink: 0, display: "flex", alignItems: "center",
    padding: "0 8px 0 4px",
    background: transparent ? "transparent" : "rgba(8,6,20,0.85)",
    borderBottom: transparent ? "none" : `1px solid ${M.border}`,
    backdropFilter: transparent ? "none" : "blur(20px)",
    ...style,
  }}>
    {onBack ? (
      <button onClick={onBack} style={{
        width: 44, height: 44, display: "flex", alignItems: "center", justifyContent: "center",
        background: "none", border: "none", color: M.fg, cursor: "pointer",
      }}>
        <Icon name="chevronL" size={22}/>
      </button>
    ) : leading || <div style={{ width: 8 }}/>}
    <div style={{
      flex: 1, fontSize: 17, fontWeight: 700, letterSpacing: -0.1,
      color: M.fg, padding: "0 4px",
    }}>{title}</div>
    <div style={{ display: "flex", alignItems: "center", gap: 2 }}>{trailing}</div>
  </div>
);

// ── Poster placeholder (uses the gradient `art` strings from FluxData2) ──
const Poster = ({ art, img, title, year, qual, w, h, radius = 12, style }) => (
  <div style={{
    width: w, height: h, borderRadius: radius, position: "relative",
    background: art || "linear-gradient(135deg, #2a1a4a, #6a3aaa)",
    overflow: "hidden", flexShrink: 0,
    boxShadow: "0 6px 22px rgba(0,0,0,0.45), inset 0 0 0 1px rgba(255,255,255,0.06)",
    ...style,
  }}>
    {img && (
      <img src={img} alt={title || ""}
        style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover" }}
        onError={(e) => { e.currentTarget.style.display = "none"; }}/>
    )}
    {/* subtle noise via diagonal stripes — only on gradient fallback */}
    {!img && <div style={{
      position: "absolute", inset: 0, opacity: 0.18,
      background: "repeating-linear-gradient(135deg, transparent 0 8px, rgba(255,255,255,0.06) 8px 9px)",
    }}/>}
    {/* dark gradient bottom */}
    <div style={{
      position: "absolute", left: 0, right: 0, bottom: 0, height: "55%",
      background: "linear-gradient(to top, rgba(0,0,0,0.85), transparent)",
    }}/>
    {qual && (
      <div style={{
        position: "absolute", top: 8, left: 8,
        background: "rgba(0,0,0,0.55)", color: "#E9D5FF",
        fontSize: 9.5, fontWeight: 700, letterSpacing: 0.4,
        padding: "3px 7px", borderRadius: 5,
        border: "1px solid rgba(255,255,255,0.1)",
      }}>{qual}</div>
    )}
    {title && (
      <div style={{ position: "absolute", left: 10, right: 10, bottom: 8 }}>
        <div style={{
          fontSize: 12.5, fontWeight: 700, color: "#fff", lineHeight: 1.2,
          textShadow: "0 1px 2px rgba(0,0,0,0.6)",
        }}>{title}</div>
        {year && <div style={{ fontSize: 10, color: "rgba(255,255,255,0.65)", marginTop: 2 }}>{year}</div>}
      </div>
    )}
  </div>
);

Object.assign(window, { M, Phone, PhoneStatusBar, PhoneNavPill, BottomTabs, MChip, MAppBar, Poster, TAB_ITEMS });

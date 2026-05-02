// ── Fluxora Logo (real brand assets) ───────────────────────────────────
// Uses the official PNG mark and wordmark from app/assets.

const FluxoraMark = ({ size = 32, glow = false, style }) => (
  <img
    src="app/shared/assets/logo-icon.png"
    width={size}
    height={size}
    alt="Fluxora"
    draggable={false}
    style={{
      display: "block",
      width: size,
      height: size,
      objectFit: "contain",
      filter: glow ? "drop-shadow(0 0 8px rgba(168,85,247,0.55))" : undefined,
      ...style,
    }}
  />
);

const FluxoraWordmark = ({ height = 22, style }) => (
  <img
    src="app/shared/assets/logo-wordmark.png"
    height={height}
    alt="Fluxora"
    draggable={false}
    style={{ display: "block", height, width: "auto", objectFit: "contain", ...style }}
  />
);

const FluxoraLogo = ({ size = 32, withWordmark = true, withTagline = false }) => (
  <div style={{ display: "flex", alignItems: "center", gap: size * 0.34 }}>
    <FluxoraMark size={size}/>
    {withWordmark && (
      <div style={{ display: "flex", flexDirection: "column", justifyContent: "center", lineHeight: 1 }}>
        <FluxoraWordmark height={size * 0.55}/>
        {withTagline && (
          <span style={{
            fontSize: size * 0.26,
            color: "rgba(255,255,255,0.55)",
            marginTop: size * 0.18,
            letterSpacing: size * 0.01,
            fontWeight: 500,
          }}>Stream. Sync. Anywhere.</span>
        )}
      </div>
    )}
  </div>
);

window.FluxoraMark = FluxoraMark;
window.FluxoraWordmark = FluxoraWordmark;
window.FluxoraLogo = FluxoraLogo;

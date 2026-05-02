// ── Splash / Sign-in ────────────────────────────────────────────────────

const SplashScreen = () => (
  <div style={{
    width: "100%", height: "100%", position: "relative",
    background:
      "radial-gradient(80% 60% at 30% 10%, rgba(168,85,247,0.45), transparent 60%)," +
      "radial-gradient(80% 60% at 80% 95%, rgba(34,211,238,0.20), transparent 60%)," +
      "#08061A",
    display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "space-between",
    padding: "40px 24px 28px",
    color: "#fff",
  }}>
    {/* hero */}
    <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 28, width: "100%" }}>
      <FluxoraMark size={104} glow/>
      <div style={{ textAlign: "center" }}>
        <FluxoraWordmark height={26}/>
        <div style={{ marginTop: 14, fontSize: 13, color: "rgba(255,255,255,0.65)", letterSpacing: 0.2 }}>
          Stream. Sync. Anywhere.
        </div>
      </div>
      <div style={{ display: "flex", gap: 6, marginTop: 6 }}>
        {[0,1,2].map(i => (
          <div key={i} style={{
            width: i === 0 ? 22 : 6, height: 6, borderRadius: 999,
            background: i === 0 ? M.accent : "rgba(255,255,255,0.2)",
          }}/>
        ))}
      </div>
    </div>

    {/* CTAs */}
    <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: 10 }}>
      <button style={{
        height: 50, borderRadius: 14, border: "none",
        background: "linear-gradient(135deg, #8B5CF6, #A855F7)",
        color: "#fff", fontWeight: 700, fontSize: 15, fontFamily: "inherit", cursor: "pointer",
        boxShadow: "0 12px 28px rgba(139,92,246,0.45)",
      }}>Sign in to Fluxora</button>
      <button style={{
        height: 50, borderRadius: 14,
        background: "rgba(255,255,255,0.04)", border: `1px solid ${M.borderStrong}`,
        color: "#fff", fontWeight: 700, fontSize: 15, fontFamily: "inherit", cursor: "pointer",
        display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8,
      }}>
        <Icon name="server" size={16} stroke="#fff"/> Connect to a server
      </button>
      <button style={{
        height: 44, background: "transparent", border: "none",
        color: M.fgMuted, fontWeight: 600, fontSize: 13, fontFamily: "inherit", cursor: "pointer",
      }}>Continue as guest</button>

      <div style={{ marginTop: 6, fontSize: 11, color: M.fgDim, textAlign: "center" }}>
        By continuing you agree to our <span style={{ color: M.fgMuted, textDecoration: "underline" }}>Terms</span>
        {" & "}<span style={{ color: M.fgMuted, textDecoration: "underline" }}>Privacy</span>
      </div>
    </div>
  </div>
);

window.SplashScreen = SplashScreen;

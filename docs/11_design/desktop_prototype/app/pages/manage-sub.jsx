// ── Manage Subscription modal ──────────────────────────────────────────
const ManageSubModal = ({ open, onClose }) => {
  if (!open) return null;
  return (
    <div onClick={onClose} style={{
      position: "fixed", inset: 0, zIndex: 100,
      background: "rgba(2,1,8,0.7)", backdropFilter: "blur(6px)",
      display: "flex", alignItems: "center", justifyContent: "center",
    }}>
      <div onClick={e => e.stopPropagation()} style={{
        width: 560, maxHeight: "85vh", overflow: "auto",
        background: "linear-gradient(180deg, rgba(28,18,52,0.96), rgba(20,12,42,0.96))",
        border: "1px solid rgba(168,85,247,0.25)",
        borderRadius: 14,
        boxShadow: "0 24px 72px rgba(0,0,0,0.6), 0 0 0 1px rgba(168,85,247,0.12)",
      }}>
        <div style={{ padding: "18px 22px", borderBottom: "1px solid rgba(255,255,255,0.06)", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div>
            <div style={{ fontSize: 16, fontWeight: 700, color: "#F1F5F9" }}>Manage Subscription</div>
            <div style={{ fontSize: 12, color: "#94A3B8", marginTop: 2 }}>Plus Plan · $4.99/month</div>
          </div>
          <button onClick={onClose} style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 7, width: 30, height: 30, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}>
            <Icon name="x" size={14} stroke="#94A3B8"/>
          </button>
        </div>
        <div style={{ padding: 22 }}>
          <div style={{ background: "rgba(168,85,247,0.08)", border: "1px solid rgba(168,85,247,0.25)", borderRadius: 10, padding: 16, marginBottom: 18, display: "flex", alignItems: "center", gap: 14 }}>
            <div style={{ width: 44, height: 44, borderRadius: 10, background: "linear-gradient(135deg, #8B5CF6, #A855F7)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
              <Icon name="zap" size={20} stroke="#fff"/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 700, color: "#F1F5F9" }}>Plus Plan – Monthly</div>
              <div style={{ fontSize: 11.5, color: "#94A3B8", marginTop: 2 }}>Active since Nov 21, 2024 · renews May 28, 2025</div>
            </div>
            <Pill color="success">Active</Pill>
          </div>

          <div style={{ marginBottom: 16 }}>
            <div style={{ fontSize: 12, fontWeight: 600, color: "#F1F5F9", marginBottom: 10 }}>Switch Billing Cycle</div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
              <CycleOption period="Monthly" price="$4.99" sub="Renews monthly" active/>
              <CycleOption period="Yearly" price="$47.90" sub="Save 20% · $4/mo equivalent" badge="20% off"/>
            </div>
          </div>

          <div style={{ marginBottom: 16 }}>
            <div style={{ fontSize: 12, fontWeight: 600, color: "#F1F5F9", marginBottom: 10 }}>Plan Actions</div>
            {[
              { icon: "arrowUp",   title: "Upgrade to Pro",       sub: "$9.99/mo · 4K + 20 clients", color: "#3B82F6" },
              { icon: "arrowDown", title: "Downgrade to Free",    sub: "Lose internet streaming",     color: "#94A3B8" },
              { icon: "pause",     title: "Pause Subscription",   sub: "Pause for up to 3 months",    color: "#F59E0B" },
              { icon: "x",         title: "Cancel Subscription",  sub: "Active until May 28, 2025",   color: "#F87171" },
            ].map((a, i) => (
              <div key={i} style={{ display: "flex", alignItems: "center", gap: 12, padding: "11px 12px", background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.05)", borderRadius: 8, marginBottom: 6, cursor: "pointer" }}>
                <Icon name={a.icon} size={14} stroke={a.color}/>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 12.5, color: a.color, fontWeight: 600 }}>{a.title}</div>
                  <div style={{ fontSize: 11, color: "#64748B", marginTop: 1 }}>{a.sub}</div>
                </div>
                <Icon name="chevron" size={11} stroke="#475569"/>
              </div>
            ))}
          </div>

          <div style={{ background: "rgba(245,158,11,0.06)", border: "1px solid rgba(245,158,11,0.2)", borderRadius: 8, padding: 12, fontSize: 11.5, color: "#FBBF24", display: "flex", gap: 10 }}>
            <Icon name="info" size={14} stroke="#F59E0B" style={{ flexShrink: 0, marginTop: 1 }}/>
            <span style={{ lineHeight: 1.5 }}>Cancellations take effect at the end of your current billing period. You'll keep all Plus features until then.</span>
          </div>
        </div>
        <div style={{ padding: "14px 22px", borderTop: "1px solid rgba(255,255,255,0.06)", display: "flex", justifyContent: "flex-end", gap: 8 }}>
          <Button variant="secondary" onClick={onClose}>Close</Button>
          <Button variant="primary">Save Changes</Button>
        </div>
      </div>
    </div>
  );
};
const CycleOption = ({ period, price, sub, active, badge }) => (
  <div style={{
    padding: 14,
    background: active ? "rgba(168,85,247,0.10)" : "rgba(255,255,255,0.02)",
    border: active ? "1.5px solid rgba(168,85,247,0.5)" : "1px solid rgba(255,255,255,0.06)",
    borderRadius: 10, cursor: "pointer", position: "relative",
  }}>
    {badge && <span style={{ position: "absolute", top: -7, right: 10, padding: "2px 8px", background: "#10B981", color: "#fff", fontSize: 9.5, fontWeight: 700, borderRadius: 999, letterSpacing: 0.4 }}>{badge}</span>}
    <div style={{ fontSize: 12, fontWeight: 600, color: "#94A3B8", marginBottom: 4 }}>{period}</div>
    <div style={{ fontSize: 22, fontWeight: 700, color: "#F1F5F9" }}>{price}</div>
    <div style={{ fontSize: 11, color: "#64748B", marginTop: 4 }}>{sub}</div>
  </div>
);
window.ManageSubModal = ManageSubModal;

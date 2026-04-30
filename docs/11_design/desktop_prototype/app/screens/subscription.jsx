// ── Subscription ───────────────────────────────────────────────────────
const SubscriptionScreen = ({ onNav }) => {
  const [tab, setTab] = React.useState("plans");
  const [period, setPeriod] = React.useState("monthly");
  const [manageOpen, setManageOpen] = React.useState(false);
  return (
    <div style={{ display: "flex", flex: 1, overflow: "hidden" }}>
      <div style={{ flex: 1, overflow: "auto", padding: "0 24px 24px" }}>
        <PageHeader title="Subscription" subtitle="Choose the perfect plan for your streaming experience"/>

        <div style={{ display: "flex", gap: 18, padding: "0 4px 12px", borderBottom: "1px solid rgba(255,255,255,0.06)", marginBottom: 18 }}>
          {[{id:"plans",label:"Plans & Pricing",icon:"crown"},{id:"history",label:"Billing History",icon:"history"}].map(t => (
            <button key={t.id} onClick={() => setTab(t.id)} style={{
              background: "transparent", border: "none", padding: "0 4px 10px",
              color: tab === t.id ? "#C4A8F5" : "#94A3B8",
              fontSize: 13, fontWeight: tab === t.id ? 600 : 500, cursor: "pointer",
              borderBottom: tab === t.id ? "2px solid #A855F7" : "2px solid transparent",
              fontFamily: "Inter", display: "flex", alignItems: "center", gap: 7,
            }}><Icon name={t.icon} size={13}/>{t.label}</button>
          ))}
        </div>

        {tab === "history" ? <BillingHistoryTab/> : <>
        <div style={{ display: "flex", justifyContent: "center", marginBottom: 24 }}>
          <div style={{ display: "flex", padding: 4, background: "rgba(255,255,255,0.04)", borderRadius: 999, gap: 4 }}>
            {[
              { id: "monthly", label: "Monthly" },
              { id: "yearly", label: "Yearly" },
              { id: "save", label: "Save 20%", highlight: true },
            ].map(p => (
              <button key={p.id} onClick={() => p.id !== "save" && setPeriod(p.id)} style={{
                padding: "6px 16px",
                borderRadius: 999, border: "none", cursor: "pointer",
                background: period === p.id ? "linear-gradient(135deg, #8B5CF6, #A855F7)" : "transparent",
                color: period === p.id ? "#fff" : (p.highlight ? "#34D399" : "#94A3B8"),
                fontSize: 12, fontWeight: 600, fontFamily: "Inter",
              }}>{p.label}</button>
            ))}
          </div>
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 14, marginBottom: 24 }}>
          <PlanCard tier="Free" sub="Get started with basics" price="$0" icon="user" color="#94A3B8"
            features={[{txt:"Stream over LAN",ok:true},{txt:"Up to 2 clients",ok:true},{txt:"1080p streaming",ok:true},{txt:"5 libraries",ok:true},{txt:"No internet streaming",ok:false},{txt:"No transcoding",ok:false},{txt:"No priority support",ok:false}]}
            cta="Current Plan" current/>
          <PlanCard tier="Plus" sub="For personal use" price="$4.99" icon="zap" color="#A855F7" popular
            features={[{txt:"Everything in Free",ok:true},{txt:"Stream over Internet",ok:true},{txt:"Up to 5 clients",ok:true},{txt:"1080p Full HD",ok:true},{txt:"Hardware transcoding",ok:true},{txt:"50 libraries",ok:true},{txt:"Email support",ok:true}]}
            cta="Upgrade to Plus"/>
          <PlanCard tier="Pro" sub="For power users" price="$9.99" icon="crown" color="#3B82F6"
            features={[{txt:"Everything in Plus",ok:true},{txt:"Up to 20 clients",ok:true},{txt:"4K Ultra HD streaming",ok:true},{txt:"Advanced transcoding",ok:true},{txt:"Unlimited libraries",ok:true},{txt:"Custom access control",ok:true},{txt:"Activity & analytics",ok:true}]}
            cta="Upgrade to Pro"/>
          <PlanCard tier="Ultimate" sub="For the ultimate experience" price="$19.99" icon="diamond" color="#EC4899"
            features={[{txt:"Everything in Pro",ok:true},{txt:"Unlimited clients",ok:true},{txt:"4K + HDR streaming",ok:true},{txt:"AI transcoding optimization",ok:true},{txt:"Advanced user roles",ok:true},{txt:"Real-time sync",ok:true},{txt:"Dedicated support",ok:true},{txt:"Early access to new features",ok:true}]}
            cta="Upgrade to Ultimate"/>
        </div>

        <Card padding={0}>
          <div style={{ display: "grid", gridTemplateColumns: "1.5fr 1fr 1fr 1fr 1fr", gap: 12, padding: "14px 20px", fontSize: 12, fontWeight: 600, color: "#F1F5F9", borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
            <div>Compare Plans</div><div style={{ textAlign: "center" }}>Free</div><div style={{ textAlign: "center" }}>Plus</div><div style={{ textAlign: "center" }}>Pro</div><div style={{ textAlign: "center" }}>Ultimate</div>
          </div>
          {[
            ["LAN Streaming", true, true, true, true],
            ["Internet Streaming", false, true, true, true],
            ["Max Clients", "2", "5", "20", "Unlimited"],
            ["Max Quality", "1080p", "1080p", "4K", "4K + HDR"],
            ["Hardware Transcoding", false, true, true, true],
            ["Support", "Community", "Email", "Priority", "Dedicated"],
          ].map((row, i) => (
            <div key={i} style={{ display: "grid", gridTemplateColumns: "1.5fr 1fr 1fr 1fr 1fr", gap: 12, padding: "12px 20px", alignItems: "center", borderTop: "1px solid rgba(255,255,255,0.03)", fontSize: 12.5 }}>
              <div style={{ color: "#94A3B8" }}>{row[0]}</div>
              {row.slice(1).map((v, j) => (
                <div key={j} style={{ textAlign: "center", color: "#E2E8F0", fontWeight: 500 }}>
                  {v === true ? <Icon name="check" size={14} stroke="#A855F7" style={{ display: "inline-block" }}/> : v === false ? <Icon name="minus" size={14} stroke="#475569" style={{ display: "inline-block" }}/> : v}
                </div>
              ))}
            </div>
          ))}
        </Card>
        </>}
      </div>

      {/* Right rail */}
      <div style={{ width: 300, flexShrink: 0, borderLeft: "1px solid rgba(255,255,255,0.05)", background: "rgba(13,11,28,0.5)", overflow: "auto", padding: 18 }}>
        <Card padding={14} style={{ marginBottom: 14, background: "rgba(16,185,129,0.06)", borderColor: "rgba(16,185,129,0.2)" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 6 }}>
            <Icon name="shieldCheck" size={16} stroke="#10B981"/>
            <span style={{ fontSize: 13, fontWeight: 600, color: "#34D399" }}>Secure Payments</span>
          </div>
          <div style={{ fontSize: 11.5, color: "#94A3B8", lineHeight: 1.5 }}>All payments are encrypted and secure.</div>
        </Card>

        <Card padding={16} style={{ marginBottom: 14 }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 12 }}>Current Plan</div>
          <div style={{ display: "flex", alignItems: "flex-start", gap: 10, marginBottom: 14 }}>
            <div style={{ width: 38, height: 38, borderRadius: 9, background: "linear-gradient(135deg, #8B5CF6, #A855F7)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
              <Icon name="zap" size={16} stroke="#fff"/>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8, marginBottom: 3 }}>
                <span style={{ fontSize: 13, color: "#F1F5F9", fontWeight: 600, whiteSpace: "nowrap" }}>Plus Plan</span>
                <Pill color="success">Active</Pill>
              </div>
              <div style={{ fontSize: 11, color: "#64748B" }}>Renews on May 28, 2025</div>
            </div>
          </div>
          <Button variant="outline" fullWidth onClick={() => setManageOpen(true)}>Manage Subscription</Button>
        </Card>

        <Card padding={16} style={{ marginBottom: 14 }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9", marginBottom: 10 }}>Payment Method</div>
          <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 10, padding: "8px 10px", background: "rgba(255,255,255,0.03)", borderRadius: 7 }}>
            <div style={{ width: 32, height: 22, borderRadius: 4, background: "linear-gradient(135deg, #1A4FFF, #0033AA)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 9, fontWeight: 800, color: "#fff", letterSpacing: 0.5 }}>VISA</div>
            <div style={{ flex: 1, fontSize: 12, color: "#E2E8F0", fontFamily: "JetBrains Mono" }}>**** **** **** 4242</div>
          </div>
          <a style={{ fontSize: 11.5, color: "#A855F7", cursor: "pointer", fontWeight: 500 }}>Update Payment Method</a>
        </Card>

        <Card padding={16} style={{ marginBottom: 14 }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9", marginBottom: 12 }}>Why Upgrade?</div>
          {[
            ["globe", "Stream Anywhere", "Access your content from anywhere in the world."],
            ["sparkle", "Better Quality", "Enjoy higher quality streaming up to 4K + HDR."],
            ["users", "More Devices", "Connect more devices and share with your family."],
            ["zap", "Priority Support", "Get priority assistance whenever you need it."],
          ].map(([ic, t, s], i) => (
            <div key={i} style={{ display: "flex", gap: 10, padding: "8px 0", borderTop: i ? "1px solid rgba(255,255,255,0.04)" : "none" }}>
              <div style={{ width: 28, height: 28, borderRadius: 7, background: "rgba(168,85,247,0.15)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                <Icon name={ic} size={13} stroke="#C4A8F5"/>
              </div>
              <div>
                <div style={{ fontSize: 12, fontWeight: 600, color: "#E2E8F0" }}>{t}</div>
                <div style={{ fontSize: 11, color: "#64748B", lineHeight: 1.45, marginTop: 2 }}>{s}</div>
              </div>
            </div>
          ))}
        </Card>

        <Card padding={16}>
          <div style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9", marginBottom: 8 }}>Need Help?</div>
          <div style={{ fontSize: 11.5, color: "#94A3B8", lineHeight: 1.5, marginBottom: 12 }}>Visit our <a style={{ color: "#A855F7" }}>Help Center</a> or contact us for any subscription questions.</div>
          <Button variant="outline" icon="helpCircle" fullWidth>Help Center</Button>
        </Card>
      </div>
      <ManageSubModal open={manageOpen} onClose={() => setManageOpen(false)}/>
    </div>
  );
};

const PlanCard = ({ tier, sub, price, icon, color, features, cta, popular, current }) => (
  <div style={{
    position: "relative",
    background: popular ? "linear-gradient(180deg, rgba(168,85,247,0.10), rgba(20,18,38,0.8))" : "rgba(20,18,38,0.7)",
    border: popular ? "1.5px solid rgba(168,85,247,0.5)" : "1px solid rgba(255,255,255,0.06)",
    borderRadius: 14, padding: 22,
    boxShadow: popular ? "0 12px 32px rgba(168,85,247,0.18)" : "none",
  }}>
    {popular && <div style={{ position: "absolute", top: -10, left: "50%", transform: "translateX(-50%)", background: "linear-gradient(135deg, #8B5CF6, #A855F7)", color: "#fff", fontSize: 10, fontWeight: 700, letterSpacing: 0.4, padding: "4px 12px", borderRadius: 999, textTransform: "uppercase", whiteSpace: "nowrap" }}>Most Popular</div>}
    <div style={{ width: 38, height: 38, borderRadius: 10, background: `${color}1F`, display: "flex", alignItems: "center", justifyContent: "center", marginBottom: 14 }}>
      <Icon name={icon} size={18} stroke={color}/>
    </div>
    <div style={{ fontSize: 18, fontWeight: 700, color: "#F1F5F9" }}>{tier}</div>
    <div style={{ fontSize: 11.5, color: "#64748B", marginTop: 2, marginBottom: 14 }}>{sub}</div>
    <div style={{ display: "flex", alignItems: "baseline", gap: 4, marginBottom: 18 }}>
      <span style={{ fontSize: 30, fontWeight: 700, color: popular ? "#fff" : "#F1F5F9", letterSpacing: "-0.02em" }}>{price}</span>
      <span style={{ fontSize: 12, color: "#64748B" }}>/month</span>
    </div>
    <div style={{ display: "flex", flexDirection: "column", gap: 8, marginBottom: 18 }}>
      {features.map((f, i) => (
        <div key={i} style={{ display: "flex", gap: 8, alignItems: "flex-start", fontSize: 12 }}>
          {f.ok ? <Icon name="check" size={13} stroke="#A855F7" style={{ flexShrink: 0, marginTop: 1 }}/> : <Icon name="x" size={13} stroke="#475569" style={{ flexShrink: 0, marginTop: 1 }}/>}
          <span style={{ color: f.ok ? "#CBD5E1" : "#475569" }}>{f.txt}</span>
        </div>
      ))}
    </div>
    {current ? (
      <div style={{ padding: "9px 12px", background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 8, color: "#94A3B8", fontSize: 12, fontWeight: 600, textAlign: "center" }}>{cta}</div>
    ) : (
      <Button variant={popular ? "primary" : "outline"} fullWidth>{cta}</Button>
    )}
  </div>
);

window.SubscriptionScreen = SubscriptionScreen;
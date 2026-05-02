// ── Subscription / Billing History tab ─────────────────────────────────
const BillingHistoryTab = () => (
  <>
    <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 14, marginBottom: 18 }}>
      <StatTile icon="creditCard" label="Total Spent" value="$54.89" sub="Since Nov 2024" color="#A855F7"/>
      <StatTile icon="check"      label="Paid Invoices" value="6" sub="On time" color="#10B981" accent="#10B981"/>
      <StatTile icon="refresh"    label="Next Charge" value="$4.99" sub="May 28, 2025" color="#3B82F6" accent="#94A3B8"/>
      <StatTile icon="download"   label="Avg Monthly" value="$4.99" sub="Plus plan" color="#F59E0B" accent="#94A3B8"/>
    </div>

    <Card padding={0}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "14px 20px", borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
        <span style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9" }}>Invoice History</span>
        <div style={{ display: "flex", gap: 8 }}>
          <Button variant="secondary" size="sm" iconRight="chevronD">Last 12 months</Button>
          <Button variant="secondary" size="sm" icon="download">Export CSV</Button>
        </div>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1.4fr 1.1fr 2fr 1fr 1fr 1fr 0.6fr", gap: 12, padding: "10px 20px", fontSize: 11, fontWeight: 600, color: "#94A3B8", borderBottom: "1px solid rgba(255,255,255,0.03)" }}>
        <div>Invoice</div><div>Date</div><div>Description</div><div>Amount</div><div>Status</div><div>Method</div><div style={{ textAlign: "right" }}>Action</div>
      </div>
      {FluxData2.invoices.map((inv, i) => (
        <div key={i} style={{ display: "grid", gridTemplateColumns: "1.4fr 1.1fr 2fr 1fr 1fr 1fr 0.6fr", gap: 12, padding: "12px 20px", alignItems: "center", borderTop: "1px solid rgba(255,255,255,0.03)", fontSize: 12.5 }}>
          <div style={{ fontFamily: "JetBrains Mono", color: "#E2E8F0", fontWeight: 500 }}>{inv.id}</div>
          <div style={{ color: "#94A3B8" }}>{inv.date}</div>
          <div style={{ color: "#E2E8F0" }}>{inv.desc}</div>
          <div style={{ color: inv.amount.startsWith("-") ? "#F87171" : "#E2E8F0", fontFamily: "JetBrains Mono", fontWeight: 600 }}>{inv.amount}</div>
          <div><Pill color={inv.status === "Paid" ? "success" : inv.status === "Refund" ? "warning" : "neutral"}>{inv.status}</Pill></div>
          <div style={{ color: "#94A3B8", fontSize: 11.5 }}>{inv.method}</div>
          <div style={{ textAlign: "right", display: "flex", gap: 4, justifyContent: "flex-end" }}>
            <button style={{ ...iconBtnSub }}><Icon name="eye" size={12} stroke="#94A3B8"/></button>
            <button style={{ ...iconBtnSub }}><Icon name="download" size={12} stroke="#94A3B8"/></button>
          </div>
        </div>
      ))}
      <div style={{ padding: "12px 20px", display: "flex", justifyContent: "space-between", alignItems: "center", fontSize: 12, color: "#94A3B8", borderTop: "1px solid rgba(255,255,255,0.04)" }}>
        <span>Showing 7 of 7 invoices</span>
        <a style={{ color: "#A855F7", cursor: "pointer", fontWeight: 500 }}>View all transactions →</a>
      </div>
    </Card>

    <div style={{ marginTop: 14, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
      <Card padding={20}>
        <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 14 }}>Payment Method</div>
        <div style={{ padding: 16, background: "linear-gradient(135deg, #1A4FFF 0%, #5A2AAA 100%)", borderRadius: 10, marginBottom: 12 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 28 }}>
            <span style={{ fontSize: 11, fontWeight: 600, color: "rgba(255,255,255,0.85)", letterSpacing: 1 }}>FLUXORA · BILLING</span>
            <span style={{ fontSize: 11, fontWeight: 800, color: "#fff", letterSpacing: 1 }}>VISA</span>
          </div>
          <div style={{ fontFamily: "JetBrains Mono", fontSize: 16, color: "#fff", letterSpacing: 2, marginBottom: 12 }}>•••• •••• •••• 4242</div>
          <div style={{ display: "flex", justifyContent: "space-between", fontSize: 11, color: "rgba(255,255,255,0.85)" }}>
            <span>ADMIN</span><span>EXP 09/27</span>
          </div>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          <Button variant="outline" icon="edit" fullWidth>Update</Button>
          <Button variant="secondary" icon="plus" fullWidth>Add</Button>
        </div>
      </Card>
      <Card padding={20}>
        <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 14 }}>Billing Address</div>
        {[
          ["Name", "Admin User"],
          ["Address", "1247 Kepler Avenue"],
          ["City / Postal", "San Francisco, 94107"],
          ["Country", "United States"],
          ["VAT / Tax ID", "—"],
        ].map(([k, v], i) => (
          <div key={i} style={{ display: "flex", justifyContent: "space-between", padding: "8px 0", borderBottom: i < 4 ? "1px solid rgba(255,255,255,0.04)" : "none", fontSize: 12.5 }}>
            <span style={{ color: "#94A3B8" }}>{k}</span>
            <span style={{ color: "#E2E8F0", fontWeight: 500 }}>{v}</span>
          </div>
        ))}
        <Button variant="outline" icon="edit" fullWidth style={{ marginTop: 14 }}>Edit Address</Button>
      </Card>
    </div>
  </>
);

const iconBtnSub = { width: 26, height: 26, borderRadius: 6, background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.05)", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" };

window.BillingHistoryTab = BillingHistoryTab;

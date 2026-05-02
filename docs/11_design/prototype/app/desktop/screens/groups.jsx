// ── Groups ─────────────────────────────────────────────────────────────
const GroupsScreen = () => {
  const [tab, setTab] = React.useState("all");
  const [selected, setSelected] = React.useState(FluxData.groups[0]);
  return (
    <div style={{ display: "flex", flex: 1, overflow: "hidden" }}>
      <div style={{ flex: 1, overflow: "auto", padding: "0 24px 24px" }}>
        <PageHeader title="Groups" subtitle="Organize your clients and manage shared access" search="Search groups…" actions={<Button variant="primary" icon="plus">Create Group</Button>}/>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 14, marginBottom: 18 }}>
          <StatTile icon="users" label="Total Groups" value="6" sub="+1 this week" color="#A855F7"/>
          <StatTile icon="user" label="Total Members" value="23" sub="+3 this week" color="#3B82F6"/>
          <StatTile icon="shieldCheck" label="Groups Online" value="4" sub="66% of total" color="#10B981"/>
          <StatTile icon="shield" label="Restricted Groups" value="2" sub="Require approval" color="#F59E0B" accent="#F59E0B"/>
        </div>

        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
          <div style={{ display: "flex", gap: 18 }}>
            {[
              { id: "all", label: "All Groups" },
              { id: "my", label: "My Groups" },
              { id: "public", label: "Public Groups" },
              { id: "inv", label: "Invitations", count: 2 },
            ].map(t => (
              <button key={t.id} onClick={() => setTab(t.id)} style={{
                background: "transparent", border: "none", padding: "0 0 10px",
                color: tab === t.id ? "#C4A8F5" : "#94A3B8",
                fontSize: 13, fontWeight: tab === t.id ? 600 : 500, cursor: "pointer",
                borderBottom: tab === t.id ? "2px solid #A855F7" : "2px solid transparent",
                fontFamily: "Inter", display: "flex", alignItems: "center", gap: 8,
              }}>
                {t.label}
                {t.count && <span style={{ padding: "1px 6px", background: "rgba(168,85,247,0.2)", color: "#C4A8F5", borderRadius: 999, fontSize: 10, fontWeight: 600 }}>{t.count}</span>}
              </button>
            ))}
          </div>
          <div style={{ display: "flex", gap: 8 }}>
            <Button variant="secondary" size="sm" icon="filter">Filter</Button>
            <div style={{ display: "flex", gap: 4, padding: 3, background: "rgba(255,255,255,0.04)", borderRadius: 8 }}>
              <button style={{ padding: "5px 9px", background: "rgba(168,85,247,0.18)", border: "none", borderRadius: 6, cursor: "pointer" }}><Icon name="list" size={13} stroke="#C4A8F5"/></button>
              <button style={{ padding: "5px 9px", background: "transparent", border: "none", borderRadius: 6, cursor: "pointer" }}><Icon name="grid" size={13} stroke="#64748B"/></button>
            </div>
          </div>
        </div>

        <Card padding={0}>
          <div style={{ display: "grid", gridTemplateColumns: "2fr 1.5fr 1fr 1fr 0.8fr 0.6fr", gap: 12, padding: "12px 18px", fontSize: 11, fontWeight: 600, color: "#94A3B8", borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
            <div>Group Name</div><div>Members</div><div>Access Level</div><div>Created On</div><div>Status</div><div style={{ textAlign: "right" }}>Actions</div>
          </div>
          {FluxData.groups.map(g => (
            <GroupRow key={g.id} group={g} active={selected.id === g.id} onClick={() => setSelected(g)}/>
          ))}
        </Card>
      </div>
      <GroupDetail group={selected}/>
    </div>
  );
};

const GroupRow = ({ group, active, onClick }) => (
  <div onClick={onClick} style={{
    display: "grid", gridTemplateColumns: "2fr 1.5fr 1fr 1fr 0.8fr 0.6fr",
    gap: 12, padding: "12px 18px", alignItems: "center",
    borderTop: "1px solid rgba(255,255,255,0.03)",
    background: active ? "rgba(168,85,247,0.08)" : "transparent",
    cursor: "pointer",
  }}>
    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
      <div style={{ width: 32, height: 32, borderRadius: 8, background: `${group.color}20`, display: "flex", alignItems: "center", justifyContent: "center" }}>
        <Icon name={group.icon} size={14} stroke={group.color}/>
      </div>
      <div>
        <div style={{ fontSize: 12.5, color: "#E2E8F0", fontWeight: 600, display: "flex", alignItems: "center", gap: 6 }}>
          {group.name}
          {group.restricted && <Icon name="shield" size={11} stroke="#F59E0B"/>}
        </div>
        <div style={{ fontSize: 10.5, color: "#64748B" }}>{group.sub}</div>
      </div>
    </div>
    <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
      <div style={{ display: "flex" }}>
        {[0,1,2].map(i => (
          <div key={i} style={{
            width: 22, height: 22, borderRadius: "50%",
            background: `linear-gradient(135deg, hsl(${(i*60+200)%360}, 60%, 50%), hsl(${(i*60+260)%360}, 60%, 60%))`,
            border: "2px solid #0D0B1C",
            marginLeft: i ? -6 : 0,
          }}/>
        ))}
      </div>
      <span style={{ fontSize: 11, color: "#94A3B8", fontFamily: "JetBrains Mono" }}>+{group.members - 3}</span>
    </div>
    <div>
      <Pill color={group.access === "Full Access" ? "purple" : group.access === "Limited Access" ? "info" : group.access === "Custom" ? "warning" : group.access === "View Only" ? "neutral" : "error"}>{group.access}</Pill>
    </div>
    <div style={{ fontSize: 12, color: "#94A3B8" }}>{group.created}</div>
    <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12, color: "#E2E8F0" }}>
      <StatusDot status={group.status === "active" ? "online" : group.status === "pending" ? "warning" : "offline"} size={6}/>
      {group.status[0].toUpperCase()+group.status.slice(1)}
    </div>
    <div style={{ textAlign: "right" }}><button style={iconBtn}><Icon name="moreH" size={12} stroke="#94A3B8"/></button></div>
  </div>
);

const GroupDetail = ({ group }) => (
  <div style={{ width: 300, flexShrink: 0, borderLeft: "1px solid rgba(255,255,255,0.05)", background: "rgba(13,11,28,0.5)", overflow: "auto", padding: 20 }}>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
      <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Group Details</div>
      <div style={{ display: "flex", gap: 6 }}>
        <Icon name="edit" size={14} stroke="#94A3B8"/>
        <Icon name="x" size={14} stroke="#64748B"/>
      </div>
    </div>

    <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 18 }}>
      <div style={{ width: 44, height: 44, borderRadius: 10, background: `${group.color}20`, display: "flex", alignItems: "center", justifyContent: "center" }}>
        <Icon name={group.icon} size={20} stroke={group.color}/>
      </div>
      <div>
        <div style={{ fontSize: 16, fontWeight: 700, color: "#F1F5F9", display: "flex", alignItems: "center", gap: 8 }}>
          {group.name}
          <Pill color="success">Active</Pill>
        </div>
        <div style={{ fontSize: 11, color: "#94A3B8", marginTop: 2 }}>{group.sub}</div>
      </div>
    </div>

    {[
      ["Access Level", <span style={{ color: group.color, fontWeight: 600 }}>{group.access}</span>],
      ["Members", group.members],
      ["Created On", group.created],
      ["Created By", "You"],
    ].map(([k, v], i) => (
      <div key={i} style={{ display: "flex", justifyContent: "space-between", padding: "7px 0", fontSize: 12, borderBottom: i < 3 ? "1px solid rgba(255,255,255,0.04)" : "none" }}>
        <span style={{ color: "#94A3B8" }}>{k}</span><span style={{ color: "#E2E8F0", fontWeight: 500 }}>{v}</span>
      </div>
    ))}

    <div style={{ marginTop: 14, marginBottom: 16 }}>
      <div style={{ fontSize: 11, color: "#94A3B8", marginBottom: 6 }}>Description</div>
      <div style={{ fontSize: 12, color: "#CBD5E1", lineHeight: 1.5 }}>This group has full access to all libraries and features.</div>
    </div>

    <div style={{ marginBottom: 16 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
        <span style={{ fontSize: 12, fontWeight: 600, color: "#F1F5F9" }}>Members ({group.members})</span>
        <a style={{ fontSize: 11, color: "#A855F7", cursor: "pointer", fontWeight: 500 }}>Manage</a>
      </div>
      {FluxData.groupMembers.map((m, i) => (
        <div key={i} style={{ display: "flex", alignItems: "center", gap: 10, padding: "7px 0" }}>
          <div style={{ width: 28, height: 28, borderRadius: "50%", background: `linear-gradient(135deg, hsl(${i*60}, 60%, 50%), hsl(${i*60+60}, 60%, 60%))`, flexShrink: 0 }}/>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 12, color: "#E2E8F0", fontWeight: 500 }}>{m.name}</div>
            <div style={{ fontSize: 10.5, color: "#64748B" }}>{m.email}</div>
          </div>
          <span style={{ display: "flex", alignItems: "center", gap: 4, fontSize: 10.5, color: m.status === "online" ? "#10B981" : "#64748B" }}>
            <StatusDot status={m.status} size={5}/> {m.status[0].toUpperCase()+m.status.slice(1)}
          </span>
        </div>
      ))}
      <div style={{ marginTop: 8, padding: "7px 10px", background: "rgba(255,255,255,0.03)", borderRadius: 7, fontSize: 12, color: "#94A3B8", display: "flex", justifyContent: "space-between", alignItems: "center", cursor: "pointer" }}>
        <span>+{group.members - 4} more members</span>
        <Icon name="chevron" size={11} stroke="#94A3B8"/>
      </div>
    </div>

    <Button variant="danger" icon="trash" fullWidth>Delete Group</Button>
  </div>
);

window.GroupsScreen = GroupsScreen;

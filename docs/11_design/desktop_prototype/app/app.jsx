// ── App shell ──────────────────────────────────────────────────────────
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "violet"
}/*EDITMODE-END*/;

const App = () => {
  const [route, setRoute] = React.useState("dashboard");
  const [tick, setTick] = React.useState(0);
  const [notifOpen, setNotifOpen] = React.useState(false);
  const [tweaks, setTweak] = (window.useTweaks || ((d) => [d, () => {}]))(TWEAK_DEFAULTS);

  React.useEffect(() => {
    const id = setInterval(() => setTick(t => t + 1), 1100);
    return () => clearInterval(id);
  }, []);

  const screens = {
    dashboard: <DashboardScreen tick={tick}/>,
    library: <LibraryScreen/>,
    clients: <ClientsScreen/>,
    groups: <GroupsScreen/>,
    activity: <ActivityScreen/>,
    transcoding: <TranscodingScreen tick={tick} onNav={setRoute}/>,
    encoder: <EncoderSettings onBack={() => setRoute("transcoding")}/>,
    logs: <LogsScreen/>,
    settings: <SettingsScreen/>,
    subscription: <SubscriptionScreen onNav={setRoute}/>,
    profile: <ProfileScreen onNav={setRoute}/>,
    help: <HelpScreen/>,
  };

  return (
    <>
      <div className="titlebar">
        <div style={{ display: "flex", alignItems: "center", gap: 10, flex: 1 }}>
          <FluxoraMark size={18}/>
          <FluxoraWordmark height={11}/>
          <span style={{ fontSize: 11.5, color: "#64748B" }}>· Stream. Sync. Anywhere.</span>
        </div>
        <div style={{ display: "flex", gap: 4, alignItems: "center", marginRight: 8 }}>
          <button onClick={() => setRoute("help")} title="Help" style={tbBtn}>
            <Icon name="helpCircle" size={13} stroke="#94A3B8"/>
          </button>
          <button onClick={() => setNotifOpen(true)} title="Notifications" style={{ ...tbBtn, position: "relative" }}>
            <Icon name="bell" size={13} stroke="#94A3B8"/>
            <span style={{ position: "absolute", top: 4, right: 4, width: 6, height: 6, borderRadius: "50%", background: "#A855F7", boxShadow: "0 0 6px #A855F7" }}/>
          </button>
        </div>
        <div style={{ display: "flex", gap: 14, alignItems: "center" }}>
          <button style={winBtn}><Icon name="minimize" size={13} stroke="#94A3B8"/></button>
          <button style={winBtn}><Icon name="square" size={11} stroke="#94A3B8"/></button>
          <button style={winBtn}><Icon name="x" size={13} stroke="#94A3B8"/></button>
        </div>
      </div>

      <div className="main">
        <Sidebar active={route} onNav={setRoute}/>
        <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
          {screens[route]}
        </div>
      </div>

      <StatusBar tick={tick}/>

      {window.NotificationsPanel && <NotificationsPanel open={notifOpen} onClose={() => setNotifOpen(false)}/>}

      {window.TweaksPanel && (
        <window.TweaksPanel title="Tweaks">
          <window.TweakSection title="Theme">
            <window.TweakRadio label="Accent" value={tweaks.accent} options={["violet","indigo","cyan","pink"]} onChange={v => setTweak("accent", v)}/>
          </window.TweakSection>
        </window.TweaksPanel>
      )}
    </>
  );
};

const winBtn = { background: "transparent", border: "none", padding: 4, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" };
const tbBtn = { background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.05)", padding: 0, width: 26, height: 26, borderRadius: 6, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" };

ReactDOM.createRoot(document.getElementById("app-window")).render(<App/>);

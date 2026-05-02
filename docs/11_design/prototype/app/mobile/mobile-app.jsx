// ── Fluxora Mobile · main composition ───────────────────────────────────
// Wraps each screen in a Phone, lays them out on a DesignCanvas.

const App = () => {
  // App-shell wrapper: phone + status bar + screen body + bottom tabs.
  // Tab state is local to each artboard so users can switch tabs in any
  // single phone without affecting the others.
  const Shell = ({ children, defaultTab = "home", showTabs = true, statusFg = "#fff" }) => {
    const [tab, setTab] = React.useState(defaultTab);
    return (
      <Phone statusFg={statusFg}>
        <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
          <div style={{ flex: 1, minHeight: 0, position: "relative" }}>
            {typeof children === "function" ? children({ tab, setTab }) : children}
          </div>
          {showTabs && <BottomTabs active={tab} onChange={setTab}/>}
        </div>
      </Phone>
    );
  };

  return (
    <DesignCanvas>
      {/* ── 1 · Onboarding ─────────────────────────────────────────────── */}
      <DCSection id="entry" title="Onboarding" subtitle="First-run · auth · server pairing">
        <DCArtboard id="splash" label="01 · Splash / Sign-in" width={412} height={892}>
          <Phone showNav><SplashScreen/></Phone>
        </DCArtboard>

        <DCArtboard id="server" label="02 · Server picker" width={412} height={892}>
          <Phone><ServerPickerScreen/></Phone>
        </DCArtboard>
      </DCSection>

      {/* ── 2 · Discover ───────────────────────────────────────────────── */}
      <DCSection id="discover" title="Discover" subtitle="Home, search, library — main viewing surfaces">
        <DCArtboard id="home" label="03 · Home / Discover" width={412} height={892}>
          <Shell defaultTab="home"><HomeScreen/></Shell>
        </DCArtboard>

        <DCArtboard id="library" label="04 · Library" width={412} height={892}>
          <Shell defaultTab="library"><LibraryScreen/></Shell>
        </DCArtboard>

        <DCArtboard id="search" label="05 · Search" width={412} height={892}>
          <Shell defaultTab="search"><SearchScreen/></Shell>
        </DCArtboard>

        <DCArtboard id="notifications" label="06 · Notifications" width={412} height={892}>
          <Phone><NotificationsScreen/></Phone>
        </DCArtboard>
      </DCSection>

      {/* ── 3 · Title detail & playback ────────────────────────────────── */}
      <DCSection id="title" title="Title detail & playback" subtitle="From poster tap → watching">
        <DCArtboard id="detail" label="07 · Title Detail" width={412} height={892}>
          <Phone><DetailScreen/></Phone>
        </DCArtboard>

        <DCArtboard id="episodes" label="08 · Episodes list (TV)" width={412} height={892}>
          <Phone><EpisodesScreen/></Phone>
        </DCArtboard>

        <DCArtboard id="player-portrait" label="09 · Player · Portrait" width={412} height={892}>
          <Phone statusFg="#fff" bg="#000"><PlayerPortrait/></Phone>
        </DCArtboard>

        <DCArtboard id="mini-player" label="10 · Home with mini-player (PiP)" width={412} height={892}>
          <Shell defaultTab="home"><HomeWithMiniPlayer/></Shell>
        </DCArtboard>
      </DCSection>

      {/* ── 4 · Landscape player + legend ──────────────────────────────── */}
      <DCSection id="player-landscape-section" title="Landscape player" subtitle="Full controls + gestures legend (matches reference)">
        <DCArtboard id="player-landscape" label="11 · Player · Landscape" width={892} height={412}>
          <Phone orientation="landscape" showStatus={false} bg="#000"><PlayerLandscape/></Phone>
        </DCArtboard>

        <DCArtboard id="legend" label="12 · Player legend (gestures + controls)" width={1640} height={400}>
          <PlayerLegend/>
        </DCArtboard>
      </DCSection>

      {/* ── 5 · Modal sheets ───────────────────────────────────────────── */}
      <DCSection id="sheets" title="Modal sheets" subtitle="Bottom-sheet pickers invoked from the player & elsewhere">
        <DCArtboard id="audio-subs" label="13 · Audio & subtitles" width={412} height={892}>
          <Phone bg="#000"><AudioSubsSheet/></Phone>
        </DCArtboard>

        <DCArtboard id="quality" label="14 · Streaming quality" width={412} height={892}>
          <Phone bg="#000"><QualitySheet/></Phone>
        </DCArtboard>

        <DCArtboard id="speed" label="15 · Playback speed" width={412} height={892}>
          <Phone bg="#000"><SpeedSheet/></Phone>
        </DCArtboard>

        <DCArtboard id="sleep" label="16 · Sleep timer" width={412} height={892}>
          <Phone bg="#000"><SleepTimerSheet/></Phone>
        </DCArtboard>

        <DCArtboard id="cast" label="17 · Cast picker" width={412} height={892}>
          <Phone bg="#000"><CastSheet/></Phone>
        </DCArtboard>
      </DCSection>

      {/* ── 6 · Features ───────────────────────────────────────────────── */}
      <DCSection id="features" title="Features" subtitle="X-Ray, Group Watch, offline state">
        <DCArtboard id="xray" label="18 · X-Ray panel" width={412} height={892}>
          <Phone><XRayScreen/></Phone>
        </DCArtboard>

        <DCArtboard id="group-watch" label="19 · Group Watch (party)" width={412} height={892}>
          <Phone><GroupWatchScreen/></Phone>
        </DCArtboard>

        <DCArtboard id="offline" label="20 · Offline state" width={412} height={892}>
          <Phone><EmptyOfflineScreen/></Phone>
        </DCArtboard>
      </DCSection>

      {/* ── 7 · Account ────────────────────────────────────────────────── */}
      <DCSection id="account" title="Library management & account" subtitle="Downloads + profile">
        <DCArtboard id="downloads" label="21 · Downloads" width={412} height={892}>
          <Shell defaultTab="downloads"><DownloadsScreen/></Shell>
        </DCArtboard>

        <DCArtboard id="profile" label="22 · Profile / Account" width={412} height={892}>
          <Shell defaultTab="profile"><ProfileScreen/></Shell>
        </DCArtboard>
      </DCSection>

      {/* ── 8 · Beyond video ───────────────────────────────────────────── */}
      <DCSection id="files" title="Beyond video — every file type" subtitle="Fluxora handles movies, shows, music, photos, documents and PDFs">
        <DCArtboard id="files-browser" label="23 · All files" width={412} height={892}>
          <Phone><FileBrowserScreen/></Phone>
        </DCArtboard>

        <DCArtboard id="doc-viewer" label="24 · PDF / document viewer" width={412} height={892}>
          <Phone><DocViewerScreen/></Phone>
        </DCArtboard>

        <DCArtboard id="photo-viewer" label="25 · Photo viewer" width={412} height={892}>
          <Phone bg="#000" statusFg="#fff"><PhotoViewerScreen/></Phone>
        </DCArtboard>

        <DCArtboard id="music-player" label="26 · Music player" width={412} height={892}>
          <Phone bg="#08061A" statusFg="#fff"><MusicPlayerScreen/></Phone>
        </DCArtboard>
      </DCSection>

      {/* ── 9 · Host & auth ────────────────────────────────────────────── */}
      <DCSection id="host" title="Phone as a server" subtitle="Yes — your phone can run Fluxora server too. Auth, 2FA, friends.">
        <DCArtboard id="host-server" label="27 · Host a server" width={412} height={892}>
          <Phone><HostServerScreen/></Phone>
        </DCArtboard>

        <DCArtboard id="signin" label="28 · Sign-in / 2FA" width={412} height={892}>
          <Phone><SignInScreen/></Phone>
        </DCArtboard>
      </DCSection>

      {/* ── 8 · Flow diagram ───────────────────────────────────────────── */}
      <DCSection id="flow" title="App flow" subtitle="How the screens connect">
        <DCArtboard id="flow-diagram" label="Screens & navigation" width={1640} height={760}>
          <MobileFlowDiagram/>
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
};

ReactDOM.createRoot(document.getElementById("mobile-root")).render(<App/>);

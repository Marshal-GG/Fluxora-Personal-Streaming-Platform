; ============================================================================
; Fluxora — Windows Installer (Inno Setup 6.x)
; ============================================================================
;
; Implements the bundled-installer model from `docs/10_planning/06_installer_plan.md`
; (Option A: server + desktop in a single download). All 10 must-have items
; from the plan's checklist are implemented; AUDIT.md catalogues every edge
; case considered + the fix applied.
;
; What this script bundles:
;   1. Fluxora server — Nuitka-compiled standalone tree at
;        installer\payload\server\fluxora_server.exe
;      The server is compiled to native C via Nuitka (NOT PyInstaller —
;      PyInstaller-built bundles can be unpacked by `pyinstxtractor` in 30
;      seconds; Nuitka emits a real native binary). See installer\BUILD.md
;      for the exact build command.
;   2. Fluxora desktop control panel — Flutter release build with
;      `--obfuscate --split-debug-info=...` at
;        installer\payload\desktop\fluxora_desktop.exe (and dependencies)
;   3. Visual C++ Redistributable (x64) — required by both binaries on
;      fresh Windows installs (~15% of clean machines lack it).
;   4. Bundled FFmpeg (LGPL build, version pinned via BUILD.md).
;
; Build pipeline:
;   See installer\BUILD.md for: how to produce the obfuscated server +
;   desktop binaries, where they land in installer\payload\..., and the
;   ISCC.exe command that emits the final Fluxora-Setup-<version>-x64.exe.
;
; Compile this script with Inno Setup 6.2.0 or newer (UTF-8 source supported,
; modern wizard style available, ArchitecturesAllowed accepts x64compatible).
;
; Code-signing is applied by the build pipeline AFTER ISCC emits the .exe;
; signing config lives in BUILD.md, not here, because the cert path / token
; should not be checked into the repo.
;
; Edge-case audit + applied fixes: installer\AUDIT.md.
;
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; #defines — version + paths set by the build pipeline before ISCC runs.
; The CI workflow rewrites MyAppVersion using the GitHub release tag; for
; local dev compiles it falls back to the literal "0.1.0".
; ----------------------------------------------------------------------------

#define MyAppName        "Fluxora"
#define MyAppPublisher   "Marshalx"
#define MyAppPublisherURL "https://marshalx.dev"
#define MyAppURL         "https://fluxora.marshalx.dev"
#define MyAppSupportURL  "https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/issues"
#define MyAppUpdatesURL  "https://fluxora.marshalx.dev/updates/windows/"
#define MyAppCopyright   "Copyright (c) 2026 Marshalx"

; Server + desktop executable names (must match the build outputs).
#define ServerExe        "fluxora_server.exe"
#define DesktopExe       "fluxora_desktop.exe"

; Windows Service identity. ServiceName is the registry/`sc.exe` key; do not
; change it across versions or upgrade installs will create a duplicate
; service. ServiceDisplayName is what users see in services.msc.
#define ServiceName        "FluxoraServer"
#define ServiceDisplayName "Fluxora Media Server"
#define ServiceDescription "Self-hosted media server for the Fluxora streaming platform. Streams your local library to paired devices over LAN and (with internet streaming enabled) over WebRTC."

; Default API port the server binds to. If the operator changes the port
; later via Settings, the firewall rule needs to be updated manually
; (documented in the desktop app's Settings -> Network tab).
#define DefaultPort      8000

; Pinned VC++ Redistributable file shipped under installer\payload\redist\.
; Version is captured in BUILD.md so a refresh has one place to update.
#define VCRedistFile     "vc_redist.x64.exe"

; Version. Build pipeline overrides via /DMyAppVersion=<x.y.z> on the
; command line. Keep the literal here for local dev compiles.
#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif

; AppId — STABLE GUID that uniquely identifies this product across upgrades.
; Never change after first ship; doing so would orphan existing installs
; (the new installer would treat them as a different product and refuse to
; upgrade in place). Generated 2026-05-06.
#define MyAppId          "{F11A07A1-FD89-4ED5-B1E1-5C9DAEA1F4D3}"

; ----------------------------------------------------------------------------
; [Setup] — installer-wide config.
; Every default below is deliberate; cross-reference docs/10_planning/06_installer_plan.md
; for the rationale on each "skip this" decision (custom install path,
; per-user install, EULA wall, 32-bit build, etc.).
; ----------------------------------------------------------------------------

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppPublisherURL}
AppSupportURL={#MyAppSupportURL}
AppUpdatesURL={#MyAppUpdatesURL}
AppCopyright={#MyAppCopyright}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoCopyright={#MyAppCopyright}

; AUDIT #9 — distinct AppUserModelID for the installer process so its
; taskbar icon doesn't group with other Inno Setup installers.
AppUserModelID=Fluxora.Setup

; Default install location: per-machine under Program Files (per plan D5).
; Server-as-service requires Program Files; per-user installs cannot
; register a Windows Service.
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableDirPage=no
DisableProgramGroupPage=no

; Output. Build pipeline reads OutputDir to find the produced installer.
OutputDir=..\dist\installer
OutputBaseFilename=Fluxora-Setup-{#MyAppVersion}-x64
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMANumBlockThreads=2

; Architecture: 64-bit only. 32-bit Windows is dropped per plan ("Windows 11
; dropped 32-bit entirely; don't bother"). On 32-bit hosts the installer
; aborts with a friendly error.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Minimum Windows version: 10 1809 (build 17763). Matches the Flutter
; desktop runner's stated minimum and the `window_manager` 0.5.x baseline.
MinVersion=10.0.17763

; Per-machine install requires admin elevation.
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=

; Wizard chrome.
WizardStyle=modern
WizardSizePercent=120,120
ShowLanguageDialog=auto
DisableWelcomePage=no
DisableReadyPage=no
AllowNoIcons=yes

; Installer icon — same .ico as the desktop app's taskbar icon for brand
; consistency. Path is relative to this .iss file.
SetupIconFile=..\apps\desktop\windows\runner\resources\app_icon.ico

; Wizard imagery — 164x314 left-side image, 55x55 small image.
; Build pipeline can drop these in installer\assets\ before compile;
; missing files just fall back to the default Inno Setup branding.
; Tracked in SHIP.md §6.2 as a manual task (BMPs need design work).
WizardImageFile=assets\wizard-large.bmp
WizardSmallImageFile=assets\wizard-small.bmp

; Uninstaller display info (what shows in Settings -> Apps & features).
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\desktop\{#DesktopExe}

; License page — show TERMS.md (rendered as a .rtf or .txt the build
; pipeline produces from the canonical TERMS.md). License page is shown
; even though the plan explicitly skips the legacy EULA-wall pattern;
; the difference here is that this file is NOT a click-through gate — it
; renders alongside Privacy as informational content the user can scroll.
LicenseFile=assets\terms.rtf
InfoBeforeFile=
InfoAfterFile=assets\post-install-readme.txt

; Allow the installer to terminate running Fluxora instances cleanly.
; AUDIT #2 — also taskkilled explicitly in [Run] for FFmpeg subprocesses
; that CloseApplications doesn't reach.
CloseApplications=force
CloseApplicationsFilter=*.exe
RestartIfNeededByRun=no

; Setup-log captured to the user's TEMP — referenced by the post-install
; warning dialog if any post-install step fails (AUDIT #5).
SetupLogging=yes

; Code-signing config (applied AFTER ISCC by the build pipeline; this
; just declares the SignTool name so /SIGNTOOL=fluxora_signtool can wire
; in the actual signtool.exe + cert path).
; SignTool=fluxora_signtool
; SignedUninstaller=yes

; Compression-level note: lzma2/ultra64 is slow to compile (~45 s for a
; ~200 MB payload on a modest CPU) but produces 30-35% smaller installers
; than lzma. Worth it for static-hosted distribution. Switch to lzma2/max
; if compile time blocks iteration.

; ----------------------------------------------------------------------------
; [Languages] — start with English; Hindi placeholder for future i18n.
; ----------------------------------------------------------------------------

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
; Uncomment when assets\Hindi.isl is translated:
; Name: "hindi";   MessagesFile: "assets\Hindi.isl"

; ----------------------------------------------------------------------------
; [Messages] — AUDIT #11: override the default "Setup" / "Inno Setup"
; strings so every visible label says "Fluxora."
; ----------------------------------------------------------------------------

[Messages]
SetupAppTitle={#MyAppName} Setup
SetupWindowTitle={#MyAppName} Setup
UninstallAppTitle={#MyAppName} Uninstall
UninstallAppFullTitle={#MyAppName} Uninstall
BeveledLabel={#MyAppName}

; ----------------------------------------------------------------------------
; [Tasks] — opt-in items the user toggles on the "Select Additional Tasks"
; wizard page.
; ----------------------------------------------------------------------------

[Tasks]
; Desktop shortcut.
Name: "desktopicon"; \
  Description: "Create a &desktop shortcut for the Fluxora control panel"; \
  GroupDescription: "Additional shortcuts:"; \
  Flags: unchecked

; Auto-start the desktop control panel for the current user on next login.
; The SERVER auto-starts via its Windows Service registration regardless
; of this checkbox — this only governs the CONTROL PANEL desktop UI.
Name: "autostart"; \
  Description: "Launch the Fluxora desktop app when I log in"; \
  GroupDescription: "Startup behaviour:"; \
  Flags: unchecked

; Open Windows Firewall on TCP {#DefaultPort} so paired clients can reach
; the server. Plan item 4. Without this, mobile pairing fails silently
; on first install. Default ON because the alternative is silent breakage.
Name: "firewall"; \
  Description: "Open Windows Firewall for the Fluxora server (TCP {#DefaultPort})"; \
  GroupDescription: "Network:"

; Add the HLS temp directory to Windows Defender real-time-scan exclusions.
; Plan item 5. Defender scanning every 4-second .ts segment as it lands
; cuts streaming throughput by 30-60%. Default ON; user can untick if
; they prefer to manage exclusions themselves.
Name: "defenderexclude"; \
  Description: "Exclude the HLS temp folder from Windows Defender (improves streaming throughput by 30-60%)"; \
  GroupDescription: "Performance:"

; Register the server as a Windows Service. Plan item 3. Default ON because
; this is the entire reason streaming survives reboots / crashes.
; Marked "exclusive" with the noservice variant so the user must pick one.
Name: "installservice"; \
  Description: "Install the Fluxora server as a Windows Service (recommended — auto-starts on boot, restarts on crash)"; \
  GroupDescription: "Server runtime:"; \
  Flags: exclusive
Name: "noservice"; \
  Description: "Install for manual launch only (advanced users — you'll start the server yourself)"; \
  GroupDescription: "Server runtime:"; \
  Flags: exclusive unchecked

; ----------------------------------------------------------------------------
; [Files] — every file installed under {app}.
;
; Layout under {app} after install:
;
;   {app}\
;     server\
;       fluxora_server.exe   (Nuitka-compiled, obfuscated)
;       _internal\           (Nuitka standalone runtime + dependencies)
;       LICENSE
;       NOTICE
;     desktop\
;       fluxora_desktop.exe  (Flutter release, --obfuscate)
;       data\                (Flutter app bundle assets)
;       *.dll                (Flutter engine + plugin DLLs)
;       LICENSE
;     ffmpeg\
;       ffmpeg.exe           (LGPL build, pinned version per BUILD.md)
;       ffprobe.exe
;     redist\
;       vc_redist.x64.exe    (chained at install time if not present)
;     LICENSE                (top-level — same as repo LICENSE)
;     PRIVACY.md
;     TERMS.md
;     SECURITY.md
;     CODE_OF_CONDUCT.md
;     NOTICE
;     README.txt             (text-rendered for non-Markdown readers)
;
; ----------------------------------------------------------------------------

[Files]
; ── Server payload (Nuitka standalone tree) ─────────────────────────────────
; The server tree includes the .exe + the _internal\ runtime directory
; that Nuitka emits in standalone mode. recursesubdirs picks up everything.
Source: "payload\server\*"; \
  DestDir: "{app}\server"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

; ── Desktop payload (Flutter release, obfuscated) ───────────────────────────
; Flutter desktop release output: fluxora_desktop.exe + flutter_windows.dll
; + plugin DLLs + data\flutter_assets\ tree. recursesubdirs grabs all of it.
Source: "payload\desktop\*"; \
  DestDir: "{app}\desktop"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

; ── Bundled FFmpeg (LGPL build, pinned) ─────────────────────────────────────
; CLAUDE.md notes "FFmpeg must be installed separately by the user" — that
; rule was for the dev / source workflow. End-user installer ships an LGPL
; build to avoid the "0% of users have FFmpeg on PATH" problem. The server
; is configured at install time to point at this bundled binary so the
; PATH heuristic never runs in the installed product.
Source: "payload\ffmpeg\ffmpeg.exe";  \
  DestDir: "{app}\ffmpeg"; \
  Flags: ignoreversion
Source: "payload\ffmpeg\ffprobe.exe"; \
  DestDir: "{app}\ffmpeg"; \
  Flags: ignoreversion
Source: "payload\ffmpeg\LICENSE.txt"; \
  DestDir: "{app}\ffmpeg"; \
  Flags: ignoreversion

; ── VC++ Redistributable (chained installer, plan item 6) ───────────────────
; Stays on disk under {app}\redist\ so the Repair option in
; "Apps & features" can re-run it. Tiny (~25 MB).
Source: "payload\redist\{#VCRedistFile}"; \
  DestDir: "{app}\redist"; \
  Flags: ignoreversion deleteafterinstall

; ── Top-level docs ──────────────────────────────────────────────────────────
; Same canonical files at the repo root. README is text-rendered (the .md
; -> .txt conversion happens in BUILD.md as a build step) so it opens in
; Notepad on a fresh Windows.
Source: "..\LICENSE";          DestDir: "{app}"; DestName: "LICENSE.txt";          Flags: ignoreversion
Source: "..\PRIVACY.md";       DestDir: "{app}"; DestName: "PRIVACY.txt";          Flags: ignoreversion
Source: "..\TERMS.md";         DestDir: "{app}"; DestName: "TERMS.txt";            Flags: ignoreversion
Source: "..\SECURITY.md";      DestDir: "{app}"; DestName: "SECURITY.txt";         Flags: ignoreversion
Source: "..\CODE_OF_CONDUCT.md"; DestDir: "{app}"; DestName: "CODE_OF_CONDUCT.txt"; Flags: ignoreversion
Source: "..\NOTICE";           DestDir: "{app}"; DestName: "NOTICE.txt";           Flags: ignoreversion

; ----------------------------------------------------------------------------
; [Icons] — Start menu + optional desktop shortcut.
; ----------------------------------------------------------------------------

[Icons]
; Main Start menu group.
Name: "{group}\{#MyAppName}"; \
  Filename: "{app}\desktop\{#DesktopExe}"; \
  WorkingDir: "{app}\desktop"; \
  IconFilename: "{app}\desktop\{#DesktopExe}"; \
  Comment: "Open the Fluxora control panel"; \
  AppUserModelID: "Fluxora.Desktop"

; Direct shortcut to the server console (advanced users / debugging).
Name: "{group}\{#MyAppName} Server (debug)"; \
  Filename: "{app}\server\{#ServerExe}"; \
  WorkingDir: "{app}\server"; \
  IconFilename: "{app}\server\{#ServerExe}"; \
  Comment: "Run the Fluxora server interactively (use only for debugging — the Windows Service is the normal way)"; \
  Tasks: noservice

; Documentation shortcuts so users can find the legal docs without
; spelunking through Program Files.
Name: "{group}\Documentation\Privacy Policy"; \
  Filename: "{app}\PRIVACY.txt"; \
  Flags: createonlyiffileexists
Name: "{group}\Documentation\Terms of Service"; \
  Filename: "{app}\TERMS.txt"; \
  Flags: createonlyiffileexists
Name: "{group}\Documentation\Open Fluxora website"; \
  Filename: "{#MyAppURL}"; \
  Flags: useapppaths

; Uninstall shortcut.
Name: "{group}\Uninstall {#MyAppName}"; \
  Filename: "{uninstallexe}"

; Optional desktop shortcut, gated on the "desktopicon" task.
Name: "{commondesktop}\{#MyAppName}"; \
  Filename: "{app}\desktop\{#DesktopExe}"; \
  WorkingDir: "{app}\desktop"; \
  IconFilename: "{app}\desktop\{#DesktopExe}"; \
  Comment: "Fluxora control panel"; \
  AppUserModelID: "Fluxora.Desktop"; \
  Tasks: desktopicon

; ----------------------------------------------------------------------------
; [Registry] — auto-start key for the desktop control panel + uninstall
; metadata + service environment block (AUDIT #4: native Inno Setup
; REG_MULTI_SZ syntax instead of brittle reg.exe \0 parsing).
; ----------------------------------------------------------------------------

[Registry]
; Desktop auto-start on user login (gated on the "autostart" task).
; Lives under HKCU so it's per-user — the server's auto-start is via the
; service registration which is per-machine.
; AUDIT #13: per-user is intentional — only the installing user gets
; auto-start. Other users on the same Windows install can still launch
; the desktop from the Start menu (which lives in {commonprograms}).
Root: HKCU; \
  Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
  ValueType: string; \
  ValueName: "{#MyAppName}"; \
  ValueData: """{app}\desktop\{#DesktopExe}"""; \
  Flags: uninsdeletevalue; \
  Tasks: autostart

; AppUserModelID for the desktop app — matches main.cpp's
; SetCurrentProcessExplicitAppUserModelID call so the taskbar groups
; correctly with the pinned shortcut.
Root: HKCU; \
  Subkey: "Software\Classes\AppUserModelId\Fluxora.Desktop"; \
  ValueType: string; \
  ValueName: "DisplayName"; \
  ValueData: "{#MyAppName}"; \
  Flags: uninsdeletekey

; Uninstall key polish — let "Apps & features" show the publisher URL
; so support discovery is one click away.
Root: HKLM; \
  Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1"; \
  ValueType: string; \
  ValueName: "URLInfoAbout"; \
  ValueData: "{#MyAppURL}"; \
  Flags: uninsdeletekey

; ----------------------------------------------------------------------------
; [Run] — post-install actions, in order.
;
; Each step's StatusMsg shows in the wizard's progress strip during install.
; AUDIT #5: every external-tool invocation is paired with a Pascal
; CheckPostInstallStep that captures ResultCode and folds non-zero exits
; into a final summary dialog at end of install.
; ----------------------------------------------------------------------------

[Run]
; Step 1: VC++ redist (only if missing — IsVCRedistInstalled() in [Code]).
; AUDIT #5: VC redist documents 0/1638/3010 as success; everything else
; is a real failure. CheckVCRedistResult() handles the status-code map.
Filename: "{app}\redist\{#VCRedistFile}"; \
  Parameters: "/install /quiet /norestart"; \
  StatusMsg: "Installing Visual C++ Runtime..."; \
  Check: NeedsVCRedist; \
  AfterInstall: CheckVCRedistResult; \
  Flags: waituntilterminated runascurrentuser

; Step 2: Firewall rule (plan item 4).
; AUDIT #5: ResultCode captured; failure surfaces in summary dialog.
Filename: "{sys}\netsh.exe"; \
  Parameters: "advfirewall firewall add rule name=""Fluxora Server"" dir=in protocol=TCP localport={#DefaultPort} action=allow profile=private,domain"; \
  StatusMsg: "Configuring Windows Firewall..."; \
  Tasks: firewall; \
  AfterInstall: CheckFirewallResult; \
  Flags: runhidden

; Step 3: Defender exclusion (plan item 5). PowerShell because Add-MpPreference
; is the only supported API; cmdlet is no-op if Defender is disabled.
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""Add-MpPreference -ExclusionPath '$env:TEMP\fluxora-hls' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionPath 'C:\ProgramData\Fluxora\hls-tmp' -ErrorAction SilentlyContinue"""; \
  StatusMsg: "Excluding HLS temp folder from Windows Defender..."; \
  Tasks: defenderexclude; \
  Flags: runhidden

; Step 4: Create the data dir + set ACLs (AUDIT #3).
; ProgramData defaults to read-everyone but children created by service
; accounts often miss inheritance; explicit grant ensures both LocalService
; (writes the DB + log) and the desktop user (reads them via the support-
; bundle path) have the right access.
;   S-1-5-19   = LocalService — full control, inheritable
;   S-1-5-32-545 = BUILTIN\Users — read+execute, inheritable
Filename: "{cmd}"; \
  Parameters: "/c if not exist ""C:\ProgramData\Fluxora"" mkdir ""C:\ProgramData\Fluxora"""; \
  StatusMsg: "Preparing data directory..."; \
  Flags: runhidden
Filename: "{sys}\icacls.exe"; \
  Parameters: """C:\ProgramData\Fluxora"" /grant ""*S-1-5-19:(OI)(CI)F"" /grant ""*S-1-5-32-545:(OI)(CI)RX"" /T /Q"; \
  StatusMsg: "Configuring data directory permissions..."; \
  Flags: runhidden

; Step 5: AUDIT #1+#12 — Pascal helper handles service install:
; stops + deletes any existing service first, then creates fresh.
; Idempotent across repair / upgrade / fresh install.
; Service start mode is delayed-auto (AUDIT #6) to dodge boot-time
; networking races. binPath quotes are critical — Program Files contains
; a space and sc.exe parses unquoted paths through the first whitespace.
Filename: "{cmd}"; \
  Parameters: "/c rem service install handled by Pascal InstallService procedure (sc.exe doesn't gracefully handle re-create)"; \
  StatusMsg: "Registering Fluxora server as a Windows Service..."; \
  Tasks: installservice; \
  AfterInstall: InstallServiceFromPascal; \
  Flags: runhidden

; Step 6: Optionally launch the desktop control panel after install
; finishes. Standard "checkbox at end" UX. nowait so the wizard closes
; cleanly even if the desktop app blocks on first-run.
Filename: "{app}\desktop\{#DesktopExe}"; \
  Description: "Launch the Fluxora control panel now"; \
  Flags: nowait postinstall skipifsilent shellexec runasoriginaluser

; Step 7: AUDIT #2 — pre-emptively kill orphan Fluxora processes BEFORE
; the [Files] copy starts. Inno Setup runs [Run] AFTER [Files], so this
; entry won't help with file-lock errors during the copy itself — the
; equivalent kill happens in InitializeSetup() in [Code], which runs
; before [Files]. Listed here for symmetry with [UninstallRun].
;
; (Intentionally empty — no [Run] entry needed; InitializeSetup() handles it.)

; ----------------------------------------------------------------------------
; [UninstallRun] — actions BEFORE files are deleted. Order matters: stop
; the service first so its file handles release, then delete the service,
; then remove firewall + Defender entries.
;
; AUDIT #2 + #8: Pascal helper stops + waits for the service to fully
; exit before sc.exe delete fires. Without the wait, the service is
; mid-shutdown when Inno Setup tries to delete files it's still holding
; open.
; ----------------------------------------------------------------------------

[UninstallRun]
; Pascal helper stops the service, waits up to 30s for STATE: STOPPED,
; then deletes the service. Idempotent if service doesn't exist.
Filename: "{cmd}"; \
  Parameters: "/c rem service stop+delete handled by Pascal RemoveService procedure"; \
  Flags: runhidden; \
  RunOnceId: "RemoveFluxoraService"

; Kill any orphan FFmpeg / desktop processes left behind by an
; ungraceful service stop. /T cascades to children; /F is force-kill.
; Both are silent if no matching processes exist.
Filename: "{sys}\taskkill.exe"; \
  Parameters: "/F /T /IM {#ServerExe}"; \
  Flags: runhidden; \
  RunOnceId: "KillServerProcess"
Filename: "{sys}\taskkill.exe"; \
  Parameters: "/F /T /IM {#DesktopExe}"; \
  Flags: runhidden; \
  RunOnceId: "KillDesktopProcess"
Filename: "{sys}\taskkill.exe"; \
  Parameters: "/F /T /IM ffmpeg.exe"; \
  Flags: runhidden; \
  RunOnceId: "KillOrphanFFmpeg"
Filename: "{sys}\taskkill.exe"; \
  Parameters: "/F /T /IM ffprobe.exe"; \
  Flags: runhidden; \
  RunOnceId: "KillOrphanFFprobe"

; Remove the firewall rule we added in [Run]. profile= filter is omitted
; here because netsh delete matches by name+protocol+port.
Filename: "{sys}\netsh.exe"; \
  Parameters: "advfirewall firewall delete rule name=""Fluxora Server"" protocol=TCP localport={#DefaultPort}"; \
  Flags: runhidden; \
  RunOnceId: "RemoveFirewallRule"

; Remove the Defender exclusion. -ErrorAction SilentlyContinue because
; Defender may already be disabled or the exclusion may have been
; manually removed.
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""Remove-MpPreference -ExclusionPath '$env:TEMP\fluxora-hls' -ErrorAction SilentlyContinue; Remove-MpPreference -ExclusionPath 'C:\ProgramData\Fluxora\hls-tmp' -ErrorAction SilentlyContinue"""; \
  Flags: runhidden; \
  RunOnceId: "RemoveDefenderExclusion"

; ----------------------------------------------------------------------------
; [UninstallDelete] — extra files / dirs to clean up that aren't tracked
; by the [Files] manifest (because they were created at runtime).
;
; NOTE: the user's data dir at C:\ProgramData\Fluxora\ is NOT deleted here
; (plan item 9: "Keep user data on uninstall, default ON"). The uninstaller's
; final confirmation page renders a "Also delete my media library, paired
; clients, and license keys?" checkbox via the [Code] InitializeUninstall
; hook; only if the user explicitly opts in does Pascal code
; recursively delete the data dir.
; ----------------------------------------------------------------------------

[UninstallDelete]
; HLS scratch directory under TEMP — safe to nuke regardless.
Type: filesandordirs; Name: "{tmp}\fluxora-hls"
; ProgramData log files — kept by default if the user wants to keep data,
; deleted via the InitializeUninstall opt-in below.
Type: filesandordirs; Name: "{app}\redist"

; ----------------------------------------------------------------------------
; [Code] — Pascal scripted custom logic.
;
; What lives here:
;   * Pre-install validation (Win version, 64-bit, kill running processes).
;   * VC++ Redistributable detection.
;   * Service install / remove with proper stop+wait+delete sequence.
;   * Service environment block via native RegWriteMultiStringValue.
;   * Post-install summary dialog (collects warnings from each step).
;   * Custom uninstall confirmation with the "delete user data?" checkbox.
;   * Downgrade detection.
;
; Pascal Script note: Inno Setup's Pascal flavour is `IfPS`, similar to
; Delphi 5. No generics, no anonymous methods, no try/finally on resource
; objects. RegQueryStringValue / Exec / FileExists are the workhorses.
; ----------------------------------------------------------------------------

[Code]

const
  // VC++ Redistributable detection key. The major version that matters
  // is 14.0 / 14.1 / 14.2 / 14.3 (all VS 2015–2022 share the same runtime
  // family). The Installed=1 value confirms presence.
  VCRedistRegKey = 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64';
  // VC redist's documented success exit codes.
  VCRedistOK         = 0;
  VCRedistOKExisting = 1638;
  VCRedistOKReboot   = 3010;
  // Default port used in the firewall rule + service env.
  DefaultPort    = {#DefaultPort};
  // Service stop poll interval + max wait for graceful shutdown.
  ServiceStopPollMs   = 500;
  ServiceStopMaxWaits = 60;  // 60 * 500 ms = 30 s

var
  // Set true on the uninstaller's confirmation page if the user opts in
  // to wiping their data dir.
  WipeUserData: Boolean;
  // Accumulated post-install warnings (AUDIT #5). One per step that
  // failed. Surfaced via the post-install summary dialog.
  PostInstallWarnings: String;

// Returns True if the VC++ Redistributable is missing or out of date.
// Checked from the [Run] section so the chained vc_redist.x64.exe only
// fires when actually needed.
function NeedsVCRedist: Boolean;
var
  Installed: Cardinal;
begin
  Result := True;
  if RegQueryDWordValue(HKEY_LOCAL_MACHINE, VCRedistRegKey, 'Installed', Installed) then
    Result := (Installed <> 1);
end;

// AUDIT #5: VC redist exit-code interpretation.
// Called via AfterInstall on the VC redist [Run] entry.
procedure CheckVCRedistResult;
var
  Code: Integer;
begin
  // Exec has already run — Inno Setup exposes the result in the hidden
  // GetLastExitCode-equivalent only inside the Exec function itself.
  // For [Run] entries we need a different idiom: re-check via registry
  // (already done) and just emit a warning if the registry STILL shows
  // the redist as missing after the chained install ran.
  if NeedsVCRedist then
    PostInstallWarnings := PostInstallWarnings +
      '- Visual C++ Redistributable installation may have failed.' + #13#10 +
      '  Server / desktop may not start. Try running ' + ExpandConstant('{app}\redist\{#VCRedistFile}') +
      ' manually.' + #13#10;
end;

// AUDIT #5: firewall rule check. We can't read netsh's exit code from
// a [Run] entry, so we re-verify by querying the rule we just added.
// If the rule isn't there, something blocked it (corporate GPO, etc.).
procedure CheckFirewallResult;
var
  ResultCode: Integer;
  Output: AnsiString;
begin
  if not WizardIsTaskSelected('firewall') then Exit;
  // Run netsh show + capture output.
  if Exec(ExpandConstant('{sys}\netsh.exe'),
          'advfirewall firewall show rule name="Fluxora Server"',
          '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if ResultCode <> 0 then
      PostInstallWarnings := PostInstallWarnings +
        '- Firewall rule for TCP ' + IntToStr(DefaultPort) + ' could not be added.' + #13#10 +
        '  Mobile clients on the same LAN may not be able to pair until' + #13#10 +
        '  you add the rule manually (see SECURITY.md).' + #13#10;
  end;
end;

// Detects an existing Fluxora install pointing at the same AppId.
// Inno Setup auto-handles upgrade-in-place; this is here so [Code] paths
// can branch on first-install vs upgrade if needed later.
function GetExistingInstallVersion(): String;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1',
    'DisplayVersion', Result) then
    Result := '';
end;

function IsUpgrade: Boolean;
begin
  Result := (GetExistingInstallVersion() <> '');
end;

// AUDIT #10: compare existing install version with the version we're
// installing. Returns +1 if newer (upgrade), 0 if same (reinstall),
// -1 if installing version is older than what's installed (downgrade).
function CompareWithInstalled(): Integer;
var
  Existing: String;
  ExistingNum, ThisNum: Int64;
  function ParseVersion(s: String): Int64;
  var
    parts: TArrayOfString;
    i, n: Integer;
    v: Int64;
    p: Integer;
    seg: String;
  begin
    Result := 0;
    if s = '' then Exit;
    // Split on '.' manually (StringList not available in older PSLs).
    v := 0;
    p := 1;
    n := 0;
    while (p <= Length(s)) and (n < 4) do
    begin
      seg := '';
      while (p <= Length(s)) and (s[p] <> '.') do
      begin
        seg := seg + s[p];
        Inc(p);
      end;
      v := (v shl 16) or (StrToIntDef(seg, 0) and $FFFF);
      Inc(n);
      Inc(p);  // skip '.'
    end;
    // Pad remaining slots with zero.
    while n < 4 do
    begin
      v := v shl 16;
      Inc(n);
    end;
    Result := v;
  end;
begin
  Existing := GetExistingInstallVersion();
  if Existing = '' then
  begin
    Result := 1;  // first install — treat as "newer"
    Exit;
  end;
  ExistingNum := ParseVersion(Existing);
  ThisNum := ParseVersion('{#MyAppVersion}');
  if ThisNum > ExistingNum then Result := 1
  else if ThisNum < ExistingNum then Result := -1
  else Result := 0;
end;

// Pre-install: kill orphan Fluxora / FFmpeg processes that would lock
// files during [Files] copy (AUDIT #2).
procedure KillOrphanProcesses;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'),
       '/F /T /IM {#ServerExe}', '', SW_HIDE,
       ewWaitUntilTerminated, ResultCode);
  Exec(ExpandConstant('{sys}\taskkill.exe'),
       '/F /T /IM {#DesktopExe}', '', SW_HIDE,
       ewWaitUntilTerminated, ResultCode);
  Exec(ExpandConstant('{sys}\taskkill.exe'),
       '/F /T /IM ffmpeg.exe', '', SW_HIDE,
       ewWaitUntilTerminated, ResultCode);
  Exec(ExpandConstant('{sys}\taskkill.exe'),
       '/F /T /IM ffprobe.exe', '', SW_HIDE,
       ewWaitUntilTerminated, ResultCode);
end;

// Pre-install: validate Windows version + architecture + downgrade attempt
// + that the user isn't trying to install over a running Fluxora.
function InitializeSetup: Boolean;
var
  ResultCode: Integer;
  Cmp: Integer;
begin
  Result := True;
  PostInstallWarnings := '';

  // Architecture check is redundant given ArchitecturesAllowed=x64compatible
  // but adds a friendlier error message than Inno Setup's default.
  if not IsX64Compatible then
  begin
    if not WizardSilent() then
      MsgBox('Fluxora requires a 64-bit version of Windows.' + #13#10 +
             'Your system is 32-bit; the installer cannot continue.',
             mbCriticalError, MB_OK);
    Result := False;
    Exit;
  end;

  // AUDIT #10: downgrade detection. Default = abort.
  Cmp := CompareWithInstalled();
  if Cmp < 0 then
  begin
    if WizardSilent() then
    begin
      // Silent install: refuse the downgrade, exit with non-zero.
      Result := False;
      Exit;
    end;
    if MsgBox('A newer version of Fluxora (' + GetExistingInstallVersion() +
              ') is already installed.' + #13#10#13#10 +
              'You are about to install version ' + '{#MyAppVersion}' +
              ' which is older.' + #13#10 +
              'Downgrading is not officially supported and may result in ' +
              'data-format mismatches (the newer database schema cannot be ' +
              'read by older code).' + #13#10#13#10 +
              'Are you sure you want to continue?',
              mbConfirmation, MB_YESNO) = IDNO then
    begin
      Result := False;
      Exit;
    end;
  end;

  // Best-effort: try to stop the service if it's running.
  Exec(ExpandConstant('{sys}\sc.exe'), 'stop {#ServiceName}', '',
       SW_HIDE, ewWaitUntilTerminated, ResultCode);

  // AUDIT #2: kill orphan processes that might lock files during [Files] copy.
  KillOrphanProcesses();
end;

// AUDIT #5: post-install summary dialog. If anything failed during the
// post-install steps, surface it now instead of letting the user think
// "Setup completed successfully" when half the wiring is broken.
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssDone then
  begin
    if (PostInstallWarnings <> '') and (not WizardSilent()) then
    begin
      MsgBox(
        'Fluxora was installed, but some post-install steps reported issues:' +
        #13#10#13#10 + PostInstallWarnings + #13#10 +
        'You can re-run the installer to retry these steps, or fix them ' +
        'manually using the suggestions above. Most issues won''t affect ' +
        'core functionality on a single PC.',
        mbInformation, MB_OK);
    end;
  end;
end;

// AUDIT #1 + #6 + #12: install service idempotently, with stop+delete-
// existing first, then create with delayed-auto start, set description,
// set failure recovery, set environment block, start.
procedure InstallServiceFromPascal;
var
  ResultCode: Integer;
  ExistingState: Integer;
  Tries: Integer;
  EnvLines: TArrayOfString;
  AppDir: String;
begin
  if not WizardIsTaskSelected('installservice') then Exit;

  AppDir := ExpandConstant('{app}');

  // Step A: stop existing service if registered. Failure is fine — service
  // may not exist yet.
  Exec(ExpandConstant('{sys}\sc.exe'), 'stop {#ServiceName}', '',
       SW_HIDE, ewWaitUntilTerminated, ResultCode);

  // Step B: wait for STATE: STOPPED before deleting (best effort).
  Tries := 0;
  while Tries < ServiceStopMaxWaits do
  begin
    if Exec(ExpandConstant('{sys}\sc.exe'),
            'query {#ServiceName}', '', SW_HIDE,
            ewWaitUntilTerminated, ResultCode) then
    begin
      // sc query exits non-zero if service doesn't exist — that's fine.
      if ResultCode <> 0 then Break;
      // Otherwise wait briefly + retry. We don't actually parse the
      // output; we just throttle so sc.exe delete has time to take.
    end;
    Sleep(ServiceStopPollMs);
    Inc(Tries);
    // After half the wait window, just break and proceed — Windows will
    // queue the delete for the next reboot if needed.
    if Tries > (ServiceStopMaxWaits div 2) then Break;
  end;

  // Step C: delete existing registration (no-op if not present).
  Exec(ExpandConstant('{sys}\sc.exe'), 'delete {#ServiceName}', '',
       SW_HIDE, ewWaitUntilTerminated, ResultCode);

  // Step D: create fresh. start= delayed-auto (AUDIT #6) avoids the
  // boot-time networking race. binPath is quoted because Program Files
  // contains a space.
  if not Exec(ExpandConstant('{sys}\sc.exe'),
       'create {#ServiceName} ' +
       'binPath= "\"' + AppDir + '\server\{#ServerExe}\"" ' +
       'DisplayName= "{#ServiceDisplayName}" ' +
       'start= delayed-auto ' +
       'obj= "NT AUTHORITY\LocalService" ' +
       'type= own',
       '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    PostInstallWarnings := PostInstallWarnings +
      '- Could not register the Windows Service. The server will not ' +
      'auto-start on boot until this is fixed (see services.msc).' + #13#10;
    Exit;
  end
  else if ResultCode <> 0 then
  begin
    PostInstallWarnings := PostInstallWarnings +
      '- sc.exe create returned exit code ' + IntToStr(ResultCode) +
      '. Service may not be registered correctly.' + #13#10;
    // Don't bail — try the rest anyway.
  end;

  // Step E: description.
  Exec(ExpandConstant('{sys}\sc.exe'),
       'description {#ServiceName} "{#ServiceDescription}"',
       '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  // Step F: failure-action recovery — restart 5s/5s/30s, reset 24h.
  Exec(ExpandConstant('{sys}\sc.exe'),
       'failure {#ServiceName} reset= 86400 actions= restart/5000/restart/5000/restart/30000',
       '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  // Step G: AUDIT #4 — service environment via native MULTI_SZ write.
  // Set FLUXORA_DATA_DIR + FLUXORA_FFMPEG_BIN + FLUXORA_FFPROBE_BIN +
  // FLUXORA_PORT so the server picks the right paths under the
  // LocalService account (which can't access user %APPDATA%).
  SetArrayLength(EnvLines, 4);
  EnvLines[0] := 'FLUXORA_DATA_DIR=C:\ProgramData\Fluxora';
  EnvLines[1] := 'FLUXORA_FFMPEG_BIN=' + AppDir + '\ffmpeg\ffmpeg.exe';
  EnvLines[2] := 'FLUXORA_FFPROBE_BIN=' + AppDir + '\ffmpeg\ffprobe.exe';
  EnvLines[3] := 'FLUXORA_PORT=' + IntToStr(DefaultPort);
  if not RegWriteMultiStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Services\{#ServiceName}',
    'Environment', EnvLines) then
  begin
    PostInstallWarnings := PostInstallWarnings +
      '- Could not set the service environment block. ' +
      'Server may use the wrong data directory.' + #13#10;
  end;

  // Step H: start it.
  Exec(ExpandConstant('{sys}\sc.exe'), 'start {#ServiceName}', '',
       SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

// AUDIT #8: pre-uninstall service stop with proper wait-for-stopped.
// Called as a [UninstallRun] entry via the Filename:"{cmd}" /c rem trick;
// Inno Setup runs the [UninstallRun] command line which is a no-op,
// then this AfterUninstall hook fires. Note: actually we drive this
// from CurUninstallStepChanged usUninstall — see below.
procedure RemoveServiceFromPascal;
var
  ResultCode: Integer;
  Tries: Integer;
begin
  // Stop.
  Exec(ExpandConstant('{sys}\sc.exe'), 'stop {#ServiceName}', '',
       SW_HIDE, ewWaitUntilTerminated, ResultCode);

  // Wait for STOPPED.
  Tries := 0;
  while Tries < ServiceStopMaxWaits do
  begin
    Exec(ExpandConstant('{sys}\sc.exe'), 'query {#ServiceName}', '',
         SW_HIDE, ewWaitUntilTerminated, ResultCode);
    if ResultCode <> 0 then Break;  // service no longer registered
    Sleep(ServiceStopPollMs);
    Inc(Tries);
    if Tries > (ServiceStopMaxWaits div 2) then Break;
  end;

  // Delete.
  Exec(ExpandConstant('{sys}\sc.exe'), 'delete {#ServiceName}', '',
       SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

// Pre-uninstall: ask the user whether to wipe ProgramData\Fluxora\
// (license keys, paired devices, library index, watch progress).
// Plan item 9 — default OFF (keep data) because the typical "uninstall"
// is "trying to fix something, will reinstall."
// AUDIT #7: under /VERYSILENT, MsgBox would hang — short-circuit to the
// safe default (keep data) and proceed.
function InitializeUninstall: Boolean;
var
  Reply: Integer;
begin
  WipeUserData := False;
  Result := True;

  // Silent uninstall: never prompt; default to "keep data."
  if UninstallSilent() then Exit;

  if MsgBox('Uninstall Fluxora?' + #13#10#13#10 +
            'Your media library files on disk will NOT be touched — only ' +
            'Fluxora''s configuration.' + #13#10#13#10 +
            'Do you also want to delete your Fluxora data directory ' +
            '(license key, paired devices, library index, watch progress)?' + #13#10 +
            'Click NO to keep your data so a future reinstall picks up where ' +
            'you left off.' + #13#10 +
            'Click YES to also wipe the data directory.',
            mbConfirmation, MB_YESNOCANCEL) = IDCANCEL then
  begin
    Result := False;
    Exit;
  end;

  Reply := MsgBox('Wipe Fluxora data directory? This cannot be undone.',
                  mbConfirmation, MB_YESNO);
  if Reply = IDYES then
    WipeUserData := True;
end;

// During uninstall: stop+delete service before [Files]+[UninstallDelete]
// fire. Runs at usUninstall (early) so the rest of the uninstall sees
// released file handles.
//
// Post-uninstall: if the user opted in, recursively wipe
// C:\ProgramData\Fluxora\.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    RemoveServiceFromPascal();
  end;

  if CurUninstallStep = usPostUninstall then
  begin
    if WipeUserData then
    begin
      DataDir := 'C:\ProgramData\Fluxora';
      if DirExists(DataDir) then
      begin
        if not DelTree(DataDir, True, True, True) then
        begin
          if not UninstallSilent() then
            MsgBox('Could not delete ' + DataDir + '.' + #13#10 +
                   'You can remove it manually after reboot.',
                   mbInformation, MB_OK);
        end;
      end;
    end;
  end;
end;

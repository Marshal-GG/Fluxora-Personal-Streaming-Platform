// ── Encoder Settings (Transcoding) ─────────────────────────────────────
const EncoderSettings = ({ onBack }) => (
  <div style={{ overflow: "auto", flex: 1, padding: "0 28px 28px" }}>
    <PageHeader
      title="Encoder Settings"
      subtitle="Configure hardware acceleration and codec preferences"
      back={onBack}
      actions={<><Button variant="secondary" icon="refresh">Reset Defaults</Button><Button variant="primary" icon="save">Apply Changes</Button></>}
    />

    <div style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 14 }}>
      <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
        <Card padding={0}>
          <div style={{ padding: "16px 22px", borderBottom: "1px solid rgba(255,255,255,0.04)", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <div>
              <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9" }}>Hardware Acceleration</div>
              <div style={{ fontSize: 12, color: "#64748B", marginTop: 2 }}>Use dedicated GPU/silicon for transcoding</div>
            </div>
            <Pill color="success">3 detected</Pill>
          </div>
          <div style={{ padding: 18, display: "flex", flexDirection: "column", gap: 10 }}>
            {[
              { name: "NVIDIA NVENC", sub: "RTX 4070 · CUDA 12.4 · 8th-gen NVENC", codecs: ["H.264","HEVC","AV1"], primary: true, load: 64, color: "#10B981" },
              { name: "Intel QuickSync", sub: "Iris Xe · Driver 31.0.101", codecs: ["H.264","HEVC","VP9"], primary: false, load: 0,  color: "#3B82F6" },
              { name: "Software (libx264)", sub: "CPU fallback · 16 cores available", codecs: ["H.264","HEVC","VP9","AV1"], primary: false, load: 8, color: "#94A3B8" },
            ].map((e, i) => (
              <div key={i} style={{
                padding: 14, borderRadius: 10,
                background: e.primary ? "rgba(168,85,247,0.08)" : "rgba(255,255,255,0.02)",
                border: e.primary ? "1.5px solid rgba(168,85,247,0.4)" : "1px solid rgba(255,255,255,0.05)",
              }}>
                <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 10 }}>
                  <div style={{ width: 32, height: 32, borderRadius: 7, background: `${e.color}22`, border: `1px solid ${e.color}44`, display: "flex", alignItems: "center", justifyContent: "center" }}>
                    <Icon name="cpu" size={14} stroke={e.color}/>
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13, fontWeight: 600, color: "#F1F5F9", display: "flex", alignItems: "center", gap: 8 }}>
                      {e.name}{e.primary && <Pill color="purple">Primary</Pill>}
                    </div>
                    <div style={{ fontSize: 11.5, color: "#64748B", marginTop: 2 }}>{e.sub}</div>
                  </div>
                  <TToggle on={e.primary || i === 1}/>
                </div>
                <div style={{ display: "flex", gap: 6, marginBottom: 10 }}>
                  {e.codecs.map(c => (
                    <span key={c} style={{ padding: "2px 8px", background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.06)", borderRadius: 4, fontSize: 10.5, fontFamily: "JetBrains Mono", color: "#94A3B8" }}>{c}</span>
                  ))}
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <span style={{ fontSize: 11, color: "#94A3B8", width: 60 }}>Current Load</span>
                  <div style={{ flex: 1, height: 5, background: "rgba(255,255,255,0.05)", borderRadius: 99 }}>
                    <div style={{ width: `${e.load}%`, height: "100%", background: e.color, borderRadius: 99 }}/>
                  </div>
                  <span style={{ fontSize: 11, color: e.color, fontFamily: "JetBrains Mono", fontWeight: 600, width: 36, textAlign: "right" }}>{e.load}%</span>
                </div>
              </div>
            ))}
          </div>
        </Card>

        <SettingBlock icon="layers" title="Codec Preferences">
          <SField label="Preferred Output Codec"  sub="Used for new transcodes" control={<SelectField value="HEVC (H.265)"/>}/>
          <SField label="Audio Codec"             sub="Output audio format" control={<SelectField value="AAC 256kbps"/>}/>
          <SField label="HDR Tone Mapping"        sub="Convert HDR→SDR for non-HDR clients" control={<TToggle on/>}/>
          <SField label="10-bit Output"           sub="When source is 10-bit" control={<TToggle on/>}/>
        </SettingBlock>

        <SettingBlock icon="sparkle" title="Quality & Performance">
          <SField label="Encoding Preset" sub="Speed vs quality tradeoff" control={
            <div style={{ display: "flex", gap: 4 }}>
              {["Ultrafast","Fast","Medium","Slow","Quality"].map((p, i) => (
                <span key={p} style={{ padding: "5px 9px", background: i === 2 ? "rgba(168,85,247,0.18)" : "rgba(255,255,255,0.03)", border: i === 2 ? "1px solid rgba(168,85,247,0.5)" : "1px solid rgba(255,255,255,0.06)", borderRadius: 6, fontSize: 11, fontFamily: "JetBrains Mono", color: i === 2 ? "#E9D5FF" : "#94A3B8", cursor: "pointer", fontWeight: 600 }}>{p}</span>
              ))}
            </div>
          }/>
          <SField label="Constant Rate Factor (CRF)" sub="Lower = higher quality" control={<TextField value="22"/>}/>
          <SField label="Max Bitrate" control={<TextField value="20 Mbps"/>}/>
          <SField label="Look-ahead Frames" control={<TextField value="40"/>}/>
          <SField label="Two-pass Encoding" sub="Higher quality, slower" control={<TToggle on={false}/>}/>
        </SettingBlock>

        <SettingBlock icon="db" title="Cache & Buffers">
          <SField label="Transcoder Temp Path" control={<TextField value="C:\\Fluxora\\Transcode" mono/>}/>
          <SField label="Max Cache Size" control={<SelectField value="50 GB"/>}/>
          <SField label="Pre-buffer Duration" sub="Frames to encode ahead of playback" control={<SelectField value="10 seconds"/>}/>
          <SField label="Throttle when client buffer is full" control={<TToggle on/>}/>
          <SField label="Clear Transcode Cache" control={<Button variant="danger" size="sm" icon="trash">Clear Now (8.4 GB)</Button>}/>
        </SettingBlock>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
        <Card padding={18}>
          <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 14 }}>Live Stats</div>
          {[
            ["Active Sessions",   "3",        "#A855F7"],
            ["Total Encode FPS",  "284",      "#10B981"],
            ["Avg Speed",         "2.1×",     "#3B82F6"],
            ["GPU Utilization",   "64%",      "#F59E0B"],
            ["GPU Temperature",   "67°C",     "#10B981"],
            ["Power Draw",        "142 W",    "#EC4899"],
            ["Cache Used",        "8.4 / 50 GB", "#94A3B8"],
          ].map(([k, v, c], i) => (
            <div key={i} style={{ display: "flex", justifyContent: "space-between", padding: "8px 0", borderBottom: i < 6 ? "1px solid rgba(255,255,255,0.04)" : "none", fontSize: 12 }}>
              <span style={{ color: "#94A3B8" }}>{k}</span>
              <span style={{ color: c, fontFamily: "JetBrains Mono", fontWeight: 600 }}>{v}</span>
            </div>
          ))}
        </Card>

        <Card padding={18}>
          <div style={{ fontSize: 14, fontWeight: 600, color: "#F1F5F9", marginBottom: 12 }}>Encoder Test</div>
          <div style={{ fontSize: 11.5, color: "#64748B", lineHeight: 1.5, marginBottom: 12 }}>Run a benchmark to verify hardware acceleration and measure encode speed.</div>
          <Button variant="primary" fullWidth icon="play">Run Benchmark</Button>
          <div style={{ marginTop: 14, padding: 12, background: "rgba(255,255,255,0.02)", borderRadius: 8, fontFamily: "JetBrains Mono", fontSize: 10.5, color: "#94A3B8", lineHeight: 1.7 }}>
            <div>Last run: <span style={{ color: "#10B981" }}>May 19, 09:42</span></div>
            <div>NVENC h264 → <span style={{ color: "#10B981" }}>342 fps</span></div>
            <div>NVENC hevc → <span style={{ color: "#10B981" }}>284 fps</span></div>
            <div>QSV h264   → <span style={{ color: "#3B82F6" }}>198 fps</span></div>
            <div>libx264    → <span style={{ color: "#94A3B8" }}>52 fps</span></div>
          </div>
        </Card>
      </div>
    </div>
  </div>
);

window.EncoderSettings = EncoderSettings;

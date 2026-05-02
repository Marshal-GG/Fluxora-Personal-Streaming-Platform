// ── Mock data ─────────────────────────────────────────────────────────
const FluxData = (() => {
  const movies = [
    { id:"m1", title: "Inception", year: 2010, runtime: 148, rating: 8.8, genre: "Sci-Fi · Thriller", quality:"1080p HDR",
      art: "linear-gradient(135deg, #1a0f2e 0%, #3a1a5a 40%, #6b3aa6 100%)" },
    { id:"m2", title: "Interstellar", year: 2014, runtime: 169, rating: 8.7, genre: "Sci-Fi · Adventure", quality:"4K HDR",
      art: "linear-gradient(180deg, #050810 0%, #0e1730 50%, #2a3a6a 100%)" },
    { id:"m3", title: "The Batman", year: 2022, runtime: 176, rating: 7.8, genre: "Action · Crime", quality:"720p",
      art: "linear-gradient(160deg, #050508, #1a0e1a 50%, #3a1422 100%)" },
    { id:"m4", title: "Dune: Part Two", year: 2024, runtime: 166, rating: 8.6, genre: "Sci-Fi · Drama", quality:"4K HDR",
      art: "linear-gradient(135deg, #2a160a, #c46a2a 70%, #f4c47a)" },
    { id:"m5", title: "Oppenheimer", year: 2023, runtime: 180, rating: 8.4, genre: "Drama · Biopic", quality:"1080p",
      art: "linear-gradient(160deg, #0a0a0a 0%, #2c1810 50%, #d4a72c 110%)" },
    { id:"m6", title: "Arrival", year: 2016, runtime: 116, rating: 7.9, genre: "Sci-Fi · Drama", quality:"1080p",
      art: "linear-gradient(135deg, #06121a, #1f3a4a 60%, #5a9aa6)" },
  ];

  const libraries = [
    { id:"movies",   name:"Movies",    files:1245, size:"892 GB", icon:"movie", color:"#A855F7", path:"D:\\Media\\Movies", subs:2341, folders:128, lastScan:"May 21, 2025 10:30 AM", featured: true },
    { id:"tv",       name:"TV Shows",  files:324,  size:"256 GB", icon:"tv",    color:"#3B82F6", path:"D:\\Media\\TV" },
    { id:"music",    name:"Music",     files:1023, size:"142 GB", icon:"music", color:"#EC4899", path:"D:\\Media\\Music" },
    { id:"docs",     name:"Documents", files:326,  size:"8.4 GB", icon:"doc",   color:"#F59E0B", path:"D:\\Documents" },
    { id:"photos",   name:"Photos",    files:287,  size:"12.6 GB",icon:"photo", color:"#10B981", path:"D:\\Photos" },
    { id:"anime",    name:"Anime",     files:43,   size:"189 GB", icon:"movie", color:"#06B6D4", path:"D:\\Anime" },
  ];

  const clients = [
    { id:"c1", name:"iPhone 14 Pro",     os:"iOS 17.4",     type:"Mobile",  ip:"192.168.1.101", status:"online",  lastActive:"Now",     stream:{title:"Inception (2010).mkv", quality:"1080p HDR", progress:0.36, watched:"45m of 2h 28m"}, sessions:12, watchTime:"18h 45m", firstConn:"May 18, 2025 10:15 AM", platformIcon:"iphone" },
    { id:"c2", name:"Samsung Galaxy S21",os:"Android 14",   type:"Mobile",  ip:"192.168.1.102", status:"online",  lastActive:"2m ago",  stream:{title:"Interstellar (2014).mkv", quality:"720p", progress:0.18}, platformIcon:"android" },
    { id:"c3", name:"Windows Laptop",    os:"Windows 11",   type:"Desktop", ip:"192.168.1.103", status:"online",  lastActive:"5m ago",  stream:{title:"The Batman (2022).mkv", quality:"720p (Transcoding)", progress:0.62}, platformIcon:"laptop" },
    { id:"c4", name:"MacBook Air",       os:"macOS 14.3",   type:"Desktop", ip:"192.168.1.104", status:"idle",    lastActive:"15m ago", platformIcon:"laptop" },
    { id:"c5", name:"iPad Pro",          os:"iPadOS 17.4",  type:"Tablet",  ip:"192.168.1.105", status:"offline", lastActive:"1h ago",  platformIcon:"tablet" },
    { id:"c6", name:"Android TV",        os:"Android TV 12",type:"TV",      ip:"192.168.1.106", status:"offline", lastActive:"2h ago",  platformIcon:"tv" },
  ];

  const groups = [
    { id:"g1", name:"Family",        sub:"My family members",  members:7, access:"Full Access",    created:"May 10, 2025", status:"active",   icon:"users",   color:"#A855F7", restricted:false },
    { id:"g2", name:"Friends",       sub:"Close friends",       members:8, access:"Limited Access", created:"May 8, 2025",  status:"active",   icon:"users",   color:"#F59E0B", restricted:false },
    { id:"g3", name:"Work Team",     sub:"Office collaborators",members:6, access:"Full Access",    created:"Apr 28, 2025", status:"active",   icon:"briefcase",color:"#3B82F6", restricted:false },
    { id:"g4", name:"Premium Users", sub:"Paid premium members",members:2, access:"Custom",         created:"Apr 20, 2025", status:"active",   icon:"crown",   color:"#EC4899", restricted:true  },
    { id:"g5", name:"Guests",        sub:"Temporary access",    members:1, access:"View Only",      created:"May 15, 2025", status:"pending",  icon:"user",    color:"#10B981", restricted:false },
    { id:"g6", name:"Blocked Users", sub:"Blocked accounts",    members:3, access:"No Access",      created:"Apr 12, 2025", status:"inactive", icon:"shield",  color:"#EF4444", restricted:true  },
  ];

  const groupMembers = [
    { name:"You (Owner)", email:"you@example.com",   status:"online" },
    { name:"Alice",        email:"alice@example.com", status:"online" },
    { name:"Bob",          email:"bob@example.com",   status:"online" },
    { name:"Charlie",      email:"charlie@example.com", status:"offline" },
  ];

  // 24-h activity feed
  const activity = [
    { id:1, type:"stream",   title:"Started streaming",  msg:"Inception (2010).mkv",        sub:"Client: iPhone 14 Pro",        ago:"2 min ago",  color:"#A855F7", icon:"play" },
    { id:2, type:"client",   title:"Client connected",   msg:"Samsung Galaxy S21",          sub:"IP: 192.168.1.101",            ago:"5 min ago",  color:"#3B82F6", icon:"user" },
    { id:3, type:"transcode",title:"Transcoding started",msg:"The Batman (2022).mkv",       sub:"To: 720p (H.264)",             ago:"8 min ago",  color:"#EC4899", icon:"cpu" },
    { id:4, type:"scan",     title:"Library scan completed", msg:"Movies library",          sub:"+12 new files",                ago:"23 min ago", color:"#10B981", icon:"refresh" },
    { id:5, type:"stream",   title:"Stream stopped",     msg:"Interstellar (2014).mkv",     sub:"Client: Samsung Galaxy S21",   ago:"38 min ago", color:"#A855F7", icon:"stop" },
    { id:6, type:"system",   title:"Backup completed",   msg:"Settings & metadata",         sub:"Auto-saved to D:\\Backup",     ago:"1 hr ago",   color:"#10B981", icon:"check" },
    { id:7, type:"client",   title:"Client disconnected",msg:"iPad Pro",                    sub:"Last seen 1h ago",             ago:"1 hr ago",   color:"#64748B", icon:"x" },
    { id:8, type:"warning",  title:"High CPU usage",     msg:"Detected 85% during transcode", sub:"Throttled to maintain quality", ago:"2 hr ago", color:"#F59E0B", icon:"info" },
  ];

  const logs = [
    { time:"2025-05-21 15:42:31.123", level:"INFO",  source:"Server",      msg:"Server started successfully on port 8000" },
    { time:"2025-05-21 15:42:28.456", level:"INFO",  source:"Database",    msg:"Database connection established" },
    { time:"2025-05-21 15:42:27.891", level:"INFO",  source:"Network",     msg:"LAN interface detected: 192.168.1.105" },
    { time:"2025-05-21 15:40:11.234", level:"INFO",  source:"Client",      msg:"Client connected: iPhone 14 Pro (192.168.1.101)" },
    { time:"2025-05-21 15:40:11.233", level:"INFO",  source:"Streaming",   msg:"New stream started: Inception (2010).mkv (1080p)" },
    { time:"2025-05-21 15:39:45.672", level:"WARN",  source:"Transcoding", msg:"High CPU usage detected (85%) during transcoding" },
    { time:"2025-05-21 15:39:45.671", level:"INFO",  source:"Transcoding", msg:"Transcoding started: The Batman (2022).mkv → 720p (H.264)" },
    { time:"2025-05-21 15:38:22.009", level:"INFO",  source:"Client",      msg:"Client disconnected: Samsung Galaxy S21" },
    { time:"2025-05-21 15:38:22.008", level:"INFO",  source:"Streaming",   msg:"Stream stopped: Interstellar (2014).mkv" },
    { time:"2025-05-21 15:37:10.432", level:"ERROR", source:"Storage",     msg:"Failed to read file: /Movies/Unknown.mkv (File not found)" },
    { time:"2025-05-21 15:36:55.123", level:"WARN",  source:"Network",     msg:"WebRTC relay in use (Direct connection failed)" },
    { time:"2025-05-21 15:36:55.122", level:"INFO",  source:"Network",     msg:"Remote client connected via WebRTC: 103.21.45.67" },
    { time:"2025-05-21 15:35:12.001", level:"INFO",  source:"System",      msg:"Automatic backup completed successfully" },
    { time:"2025-05-21 15:34:01.876", level:"INFO",  source:"System",      msg:"Log rotation completed (old logs archived)" },
  ];

  const transcodes = [
    { id:"t1", title:"The Batman (2022).mkv",     client:"Windows Laptop", source:"4K HEVC",  target:"720p H.264", progress:0.62, fps:48, speed:1.4, status:"active" },
    { id:"t2", title:"Inception (2010).mkv",      client:"iPhone 14 Pro",  source:"1080p",     target:"1080p HDR",  progress:0.36, fps:56, speed:1.8, status:"active" },
    { id:"t3", title:"Interstellar (2014).mkv",   client:"Galaxy S21",     source:"4K",        target:"720p H.264", progress:0.18, fps:62, speed:2.1, status:"active" },
    { id:"t4", title:"Arrival (2016).mkv",        client:"Smart TV",       source:"1080p",     target:"1080p H.264",progress:1.00, fps:0,  speed:0,   status:"queued" },
  ];

  // CPU sparkline
  const cpuSpark = Array.from({length:40}, (_,i) => 18 + Math.sin(i*0.5)*6 + (i>30?Math.random()*8:Math.random()*3));

  return { movies, libraries, clients, groups, groupMembers, activity, logs, transcodes, cpuSpark };
})();

window.FluxData = FluxData;

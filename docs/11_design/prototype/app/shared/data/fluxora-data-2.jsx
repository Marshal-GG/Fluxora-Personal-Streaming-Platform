// ── Extra data for sub-pages ───────────────────────────────────────────
window.FluxData2 = {
  invoices: [
    { id:"INV-2025-0521", date:"May 21, 2025", desc:"Plus Plan – Monthly Renewal",  amount:"$4.99", status:"Paid",     method:"Visa ····4242" },
    { id:"INV-2025-0421", date:"Apr 21, 2025", desc:"Plus Plan – Monthly Renewal",  amount:"$4.99", status:"Paid",     method:"Visa ····4242" },
    { id:"INV-2025-0321", date:"Mar 21, 2025", desc:"Plus Plan – Monthly Renewal",  amount:"$4.99", status:"Paid",     method:"Visa ····4242" },
    { id:"INV-2025-0221", date:"Feb 21, 2025", desc:"Plus Plan – Monthly Renewal",  amount:"$4.99", status:"Paid",     method:"Visa ····4242" },
    { id:"INV-2025-0121", date:"Jan 21, 2025", desc:"Plus Plan – Annual Discount",  amount:"-$10.00", status:"Refund", method:"Visa ····4242" },
    { id:"INV-2024-1221", date:"Dec 21, 2024", desc:"Plus Plan – Monthly Renewal",  amount:"$4.99", status:"Paid",     method:"Visa ····4242" },
    { id:"INV-2024-1121", date:"Nov 21, 2024", desc:"Free → Plus Upgrade",          amount:"$4.99", status:"Paid",     method:"Visa ····4242" },
  ],

  // TMDB poster URLs (image.tmdb.org CDN, publicly fetchable). Each title
  // keeps its `art` gradient as a fallback while the image loads / on error.
  movies: [
    { title:"Inception",        year:2010, runtime:"2h 28m", rating:8.8, qual:"1080p HDR", art:"linear-gradient(135deg, #1a0f2e, #6b3aa6)", img:"https://image.tmdb.org/t/p/w500/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg" },
    { title:"Interstellar",     year:2014, runtime:"2h 49m", rating:8.7, qual:"4K HDR",    art:"linear-gradient(180deg, #050810, #2a3a6a)", img:"https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg" },
    { title:"The Batman",       year:2022, runtime:"2h 56m", rating:7.8, qual:"720p",      art:"linear-gradient(160deg, #050508, #3a1422)", img:"https://image.tmdb.org/t/p/w500/74xTEgt7R36Fpooo50r9T25onhq.jpg" },
    { title:"Dune: Part Two",   year:2024, runtime:"2h 46m", rating:8.6, qual:"4K HDR",    art:"linear-gradient(135deg, #2a160a, #f4c47a)", img:"https://image.tmdb.org/t/p/w500/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg" },
    { title:"Oppenheimer",      year:2023, runtime:"3h 00m", rating:8.4, qual:"1080p",     art:"linear-gradient(160deg, #0a0a0a, #d4a72c)", img:"https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg" },
    { title:"Arrival",          year:2016, runtime:"1h 56m", rating:7.9, qual:"1080p",     art:"linear-gradient(135deg, #06121a, #5a9aa6)", img:"https://image.tmdb.org/t/p/w500/x2FJsf1ElAgr63Y3PNPtJrcmpoe.jpg" },
    { title:"Blade Runner 2049",year:2017, runtime:"2h 44m", rating:8.0, qual:"4K HDR",    art:"linear-gradient(135deg, #2a0a14, #f4844a)", img:"https://image.tmdb.org/t/p/w500/gajva2L0rPYkEWjzgFlBXCAVBE5.jpg" },
    { title:"Tenet",            year:2020, runtime:"2h 30m", rating:7.4, qual:"1080p",     art:"linear-gradient(135deg, #0a141a, #ea7322)", img:"https://image.tmdb.org/t/p/w500/k68nPLbIST6NP96JmTxmZijEvCA.jpg" },
    { title:"The Prestige",     year:2006, runtime:"2h 10m", rating:8.5, qual:"1080p",     art:"linear-gradient(135deg, #0a0a0a, #6a4a2a)", img:"https://image.tmdb.org/t/p/w500/bdN3gXuIZYaJP7ftKK2sU0nPtEA.jpg" },
    { title:"Sicario",          year:2015, runtime:"2h 01m", rating:7.6, qual:"1080p",     art:"linear-gradient(135deg, #1a0a08, #c4a07a)", img:"https://image.tmdb.org/t/p/w500/iYzhBSOhyManXAjj7yhrONyQDXk.jpg" },
    { title:"Heat",             year:1995, runtime:"2h 50m", rating:8.3, qual:"720p",      art:"linear-gradient(180deg, #1a1a1a, #4a6a8a)", img:"https://image.tmdb.org/t/p/w500/zMyfPUelumio3tiDKPffaUpsQTD.jpg" },
    { title:"Drive",            year:2011, runtime:"1h 40m", rating:7.8, qual:"1080p",     art:"linear-gradient(135deg, #1a0820, #ec4899)", img:"https://image.tmdb.org/t/p/w500/6dM31eiSoxiRfYIbeMLkS50djFy.jpg" },
  ],

  shows: [
    { title:"Breaking Bad",        seasons:5, episodes:62, rating:9.5, qual:"1080p",  art:"linear-gradient(135deg, #1a3a1a, #4a8a4a)", img:"https://image.tmdb.org/t/p/w500/ggFHVNu6YYI5L9pCfOacjizRGt.jpg" },
    { title:"The Wire",            seasons:5, episodes:60, rating:9.3, qual:"720p",   art:"linear-gradient(135deg, #1a1a2a, #4a4a6a)", img:"https://image.tmdb.org/t/p/w500/4lbclFySvugI51fwsyxBTOm4DqK.jpg" },
    { title:"Severance",           seasons:2, episodes:19, rating:8.7, qual:"4K HDR", art:"linear-gradient(135deg, #0a1a3a, #4a8aea)", img:"https://image.tmdb.org/t/p/w500/lFf6LLrQjYldcZItzOkGmMMigP7.jpg" },
    { title:"Andor",               seasons:1, episodes:12, rating:8.4, qual:"4K HDR", art:"linear-gradient(135deg, #2a1a0a, #ea8a4a)", img:"https://image.tmdb.org/t/p/w500/rrwt0u1rW685u9bJ9ougg5HJEHC.jpg" },
    { title:"Better Call Saul",    seasons:6, episodes:63, rating:9.0, qual:"1080p",  art:"linear-gradient(135deg, #2a0a0a, #ea4a4a)", img:"https://image.tmdb.org/t/p/w500/fC2HDm5t0kHl7mTm7jxMR31b7by.jpg" },
    { title:"True Detective",      seasons:4, episodes:32, rating:8.9, qual:"1080p",  art:"linear-gradient(135deg, #0a2a2a, #4aaaaa)", img:"https://image.tmdb.org/t/p/w500/qElO9tLFAfO6QbOY7d8pUOlz4tF.jpg" },
    { title:"Succession",          seasons:4, episodes:39, rating:8.9, qual:"4K HDR", art:"linear-gradient(135deg, #1a1a1a, #aaaaaa)", img:"https://image.tmdb.org/t/p/w500/7HW47XbkNQ5fiwQFYGWdw9gs144.jpg" },
    { title:"Chernobyl",           seasons:1, episodes:5,  rating:9.4, qual:"1080p",  art:"linear-gradient(135deg, #2a2a1a, #cacaaa)", img:"https://image.tmdb.org/t/p/w500/m6NREiVkdEtKsbliOlczchClGw0.jpg" },
  ],

  music: [
    { title:"Random Access Memories", artist:"Daft Punk",       year:2013, tracks:13, art:"linear-gradient(135deg, #c44a8a, #f4a4ca)" },
    { title:"Currents",                artist:"Tame Impala",     year:2015, tracks:13, art:"linear-gradient(135deg, #ea7a4a, #f4caaa)" },
    { title:"In Rainbows",             artist:"Radiohead",       year:2007, tracks:10, art:"linear-gradient(135deg, #1a0a2a, #6a4aaa)" },
    { title:"To Pimp a Butterfly",     artist:"Kendrick Lamar",  year:2015, tracks:16, art:"linear-gradient(135deg, #1a1a1a, #4a4a4a)" },
    { title:"Kid A",                   artist:"Radiohead",       year:2000, tracks:10, art:"linear-gradient(135deg, #c4caca, #6a8a8a)" },
    { title:"Discovery",               artist:"Daft Punk",       year:2001, tracks:14, art:"linear-gradient(135deg, #ea4a4a, #f4ca4a)" },
  ],

  docs: [
    { name:"Project Brief — Atlas.pdf",       size:"2.4 MB",  type:"PDF",  modified:"May 18, 2025" },
    { name:"Q1 Financials.xlsx",              size:"680 KB",  type:"XLSX", modified:"Apr 30, 2025" },
    { name:"Architecture Diagrams.zip",       size:"14.2 MB", type:"ZIP",  modified:"May 12, 2025" },
    { name:"Notes — Server Migration.md",     size:"12 KB",   type:"MD",   modified:"May 21, 2025" },
    { name:"Resume_2025.docx",                size:"148 KB",  type:"DOCX", modified:"Mar 11, 2025" },
    { name:"Tax Documents 2024.zip",          size:"6.8 MB",  type:"ZIP",  modified:"Feb 04, 2025" },
  ],

  photos: [
    { name:"IMG_4521.jpg", grad:"linear-gradient(135deg, #1a3a5a, #6acac4)" },
    { name:"IMG_4522.jpg", grad:"linear-gradient(135deg, #2a1a4a, #ea4a8a)" },
    { name:"IMG_4523.jpg", grad:"linear-gradient(135deg, #4a2a0a, #faaa4a)" },
    { name:"IMG_4524.jpg", grad:"linear-gradient(135deg, #0a3a2a, #4aaa6a)" },
    { name:"IMG_4525.jpg", grad:"linear-gradient(135deg, #1a1a3a, #4a6aaa)" },
    { name:"IMG_4526.jpg", grad:"linear-gradient(135deg, #3a0a2a, #ea4aaa)" },
    { name:"IMG_4527.jpg", grad:"linear-gradient(135deg, #0a0a1a, #2a2a4a)" },
    { name:"IMG_4528.jpg", grad:"linear-gradient(135deg, #2a3a0a, #aaca4a)" },
    { name:"IMG_4529.jpg", grad:"linear-gradient(135deg, #0a2a3a, #4acaea)" },
    { name:"IMG_4530.jpg", grad:"linear-gradient(135deg, #3a2a0a, #eaaa4a)" },
    { name:"IMG_4531.jpg", grad:"linear-gradient(135deg, #1a0a3a, #6a4aea)" },
    { name:"IMG_4532.jpg", grad:"linear-gradient(135deg, #2a3a3a, #aacaca)" },
  ],

  logFiles: [
    { name:"server-2025-05-21.log", size:"2.4 MB",  entries:1248, status:"Active",   date:"Today, 15:42" },
    { name:"server-2025-05-20.log", size:"3.1 MB",  entries:1684, status:"Archived", date:"Yesterday" },
    { name:"server-2025-05-19.log", size:"2.8 MB",  entries:1502, status:"Archived", date:"May 19" },
    { name:"server-2025-05-18.log", size:"3.4 MB",  entries:1832, status:"Archived", date:"May 18" },
    { name:"server-2025-05-17.log", size:"2.1 MB",  entries:1098, status:"Archived", date:"May 17" },
    { name:"server-2025-05-16.log", size:"2.6 MB",  entries:1412, status:"Archived", date:"May 16" },
    { name:"server-2025-05-15.log", size:"4.2 MB",  entries:2284, status:"Archived", date:"May 15" },
  ],

  shortcuts: [
    { group:"Global", items: [
      ["Open Command Palette", "Ctrl K"],
      ["Show Shortcuts", "Ctrl /"],
      ["Toggle Sidebar", "Ctrl B"],
      ["Search Library", "Ctrl F"],
      ["Quick Settings", "Ctrl ,"],
    ]},
    { group:"Navigation", items: [
      ["Dashboard", "G then D"],
      ["Library", "G then L"],
      ["Clients", "G then C"],
      ["Activity", "G then A"],
      ["Settings", "G then S"],
    ]},
    { group:"Streaming", items: [
      ["Pause/Resume Active", "Space"],
      ["Stop All Streams", "Ctrl Shift X"],
      ["Restart Server", "Ctrl Shift R"],
      ["Clear Cache", "Ctrl Shift K"],
    ]},
  ],
};

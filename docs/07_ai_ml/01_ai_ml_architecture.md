# AI & ML Architecture

> **Category:** AI/ML  
> **Status:** ✅ Documented — Implementation: Phase 5 (Future)  
> **Last Updated:** 2026-04-27

---

## Philosophy

AI features are a **Pro/Ultimate tier differentiator** — not a core dependency.

The product works fully without AI (Phase 1–4). AI is an additive enhancement layered on top
of a working streaming and library system. All AI features must:

1. Have a graceful non-AI fallback
2. Run **server-side only** (no on-device ML on mobile)
3. Be opt-in and disableable from Control Panel settings
4. Never block core streaming functionality if they fail

---

## AI Feature Breakdown

| Feature | Tier | Phase | Description |
|---------|------|-------|-------------|
| TMDB Metadata Matching | All tiers | Phase 2 | REST API — not ML, but powers ML features |
| Smart Metadata Matching | Pro | Phase 5 | ML similarity scoring to improve TMDB match accuracy |
| AI File Organization | Pro | Phase 5 | Auto-categorize, tag, and rename media files |
| Duplicate Detection | Pro | Phase 5 | Find near-duplicate files (e.g., different quality versions of same movie) |
| Content Recommendations | Ultimate | Phase 5 | Recommend next content based on watch history |
| Semantic Search | Pro | Phase 5 | Search library by description, not just filename |

---

## Technology Stack (Phase 5)

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Metadata API | TMDB REST API | Movie/TV metadata (used from Phase 2) |
| Embedding model | `sentence-transformers` (local) | Semantic similarity — runs offline on server |
| LLM (cloud option) | OpenAI GPT-4o / Google Gemini (TBD) | AI file organization, disambiguation |
| LLM (local option) | Ollama + Llama 3 / Gemma 2 | Offline mode for Pro users without API key |
| Vector index | `hnswlib` or `faiss` | In-memory semantic search index over library |

All AI components run on the **server (PC)** — never on the mobile client.

---

## TMDB Integration (Phase 2)

> TMDB is a standard REST API — not ML. It is the foundation all AI features build on.

```
[Library Scan]
    └──▶ For each new file:
            ├── Extract filename hints (strip year, quality tags, etc.)
            ├── GET https://api.themoviedb.org/3/search/movie?query={title}
            ├── Pick best match by title similarity + year
            ├── Store: title, poster_url, description, genre, rating, tmdb_id
            └── Mark file as metadata_status = "matched" | "unmatched"
```

**Config:** `FLUXORA_TMDB_KEY` env var. If empty, TMDB features disabled gracefully.

---

## AI File Organization Pipeline (Phase 5)

```
[User triggers "AI Organize" in Control Panel]
        │
        ├──▶ Scan all unmatched / low-confidence files
        ├──▶ Extract filename + existing metadata hints
        ├──▶ Query TMDB (confidence score returned)
        │
        ├── If confidence ≥ 0.85:
        │       └──▶ Auto-accept TMDB match
        │
        ├── If confidence 0.50–0.85:
        │       └──▶ Query LLM for disambiguation
        │               Input: filename + top 3 TMDB candidates
        │               Output: best match + reasoning
        │
        └── If confidence < 0.50:
                └──▶ Flag for manual review in Control Panel
        │
        └──▶ Generate proposed rename/move operations
        └──▶ Show proposals in Control Panel "Review" screen
        └──▶ User approves / rejects each proposal
        └──▶ Apply approved changes to filesystem
        └──▶ Update library DB records
```

**No file is moved or renamed without explicit user approval.**

---

## Duplicate Detection Pipeline (Phase 5)

```
[User triggers "Find Duplicates"]
        │
        ├──▶ For each pair of files: compare
        │       ├── tmdb_id (exact match → definite duplicate)
        │       ├── filename embedding similarity (≥ 0.92 cosine → likely duplicate)
        │       └── File size + duration metadata (cross-check)
        │
        └──▶ Present grouped duplicates in Control Panel
        └──▶ User selects which version to keep
        └──▶ Fluxora removes (or moves to trash) the others
```

---

## Semantic Search (Phase 5)

```
[Library loaded]
        └──▶ Build HNSW index from:
                - TMDB description embeddings
                - Genre + cast embeddings
                (runs once, cached in ~/.fluxora/search_index.bin)

[User searches: "space adventure with robots"]
        └──▶ Embed query using same sentence-transformers model
        └──▶ ANN search in HNSW index (top-K results)
        └──▶ Return ranked results to Flutter client
```

---

## Content Recommendations (Phase 5 — Ultimate)

| Signal | Weight | Notes |
|--------|--------|-------|
| Watch history (completed) | High | Strongest signal |
| Watch history (abandoned) | Negative | Indicates dislike |
| Genre preferences | Medium | Derived from history |
| Rating scores | Medium | User ratings in library |
| Time of day | Low | Morning vs evening viewing patterns |

Implementation: collaborative filtering (simple cosine similarity over user history vectors)
— no external ML API required for basic recommendations.

---

## Integration Points

| System | How AI Connects |
|--------|----------------|
| `library_service.py` | Triggers TMDB fetch on scan; updates `metadata_status` |
| `ai_service.py` (Phase 5) | Wraps LLM calls, embedding model, HNSW index |
| Control Panel → AI Organize screen | Drives the organize pipeline; shows proposals |
| Control Panel → Search | Sends semantic query to `GET /api/v1/library/search?q=` |
| SQLite `files` table | Stores `tmdb_id`, `metadata_status`, `embedding_vector` (Phase 5) |

---

## Fallback Strategy

| AI Component | Failure Mode | Fallback |
|-------------|-------------|---------|
| TMDB API | Down or no key | Skip metadata, file listed by filename only |
| LLM API | Down or no key | Skip AI disambiguation, flag for manual review |
| Embedding model | Load failure | Disable semantic search, use filename search only |
| HNSW index | Build failure | Log error, continue without search index |
| Recommendations | Insufficient history | Show "Watch more to get recommendations" message |

---

## Quality Targets

| Metric | Target |
|--------|--------|
| TMDB match accuracy (filename only) | > 80% |
| AI disambiguation acceptance rate | > 70% |
| AI response latency (per file) | < 5s |
| Duplicate detection precision | > 95% (minimize false positives) |
| Semantic search relevance (top-5) | > 80% user satisfaction |

---

## Cost Model

| Service | Cost | Notes |
|---------|------|-------|
| TMDB API | Free | Rate limit: 40 req/10s — more than sufficient |
| OpenAI GPT-4o | ~$0.005/file | Only called for low-confidence matches |
| Google Gemini | ~$0.002/file | Alternative; TBD at Phase 5 |
| Ollama (local) | $0 | Requires capable GPU; slower |
| `sentence-transformers` | $0 | Runs locally on CPU; ~200ms/file |

LLM API costs are offset by Pro/Ultimate subscription pricing.
Local-only option (Ollama) available for users who prefer no API key.

---

## Open Questions (To Resolve at Phase 5)

| Question | Options |
|----------|---------|
| Primary LLM provider | OpenAI GPT-4o vs Google Gemini vs local Ollama |
| Embedding model | `all-MiniLM-L6-v2` (fast, small) vs `bge-large` (slower, more accurate) |
| Vector store | In-memory `hnswlib` vs SQLite-VSS extension |
| Recommendation engine | Cosine similarity vs lightweight collaborative filter |
| AI Organize UX | Batch review screen vs inline approval per-file |

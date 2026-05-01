# Runbook: Triaging a Dependabot PR flood

> **What:** Process for working through 10–30 Dependabot PRs that arrive after a long gap of no updates. Covers tier-by-tier safety classification, cross-package coupling traps, and the merge-order rules.
> **Estimated time:** 30 min for ~20 PRs once you have the workflow in muscle memory.

---

## When you'll need this

- First time you turn Dependabot on against an established repo (Dependabot opens one PR per outdated dep — easily 20+)
- After being away from the project for ~3+ months — the queue has grown
- After a deliberate "let dependencies bake" period and you're catching up

The tactical problem: you can't merge them all at once via the GitHub UI's "merge all" pattern, because some bumps are coupled (a major bump in package A breaks package B's pin), some have new lint rules that require code fixes, and some Action bumps frequently break workflow assumptions silently.

---

## The four tiers

Sort every PR into one of these before merging anything.

### Tier 1 — Grouped minor + patch bumps

Branch names contain `-deps` group identifiers (e.g. `python-runtime`, `dart-deps`, `npm-deps`). Dependabot is configured (in `dependabot.yml`) to group these under `update-types: ["minor", "patch"]`.

**Action:** merge as soon as CI is green on each. They're contractually non-breaking by semver.

### Tier 2 — Single-package majors with low blast radius

Lint config bumps, formatter bumps, dev tooling. Won't change runtime behavior; may surface new warnings.

**Action:** check out branch locally, run analyze + format check + tests, fix anything that surfaces, push, merge. Common offenders: `flutter_lints`, `eslint`, `black`, `ruff`.

### Tier 3 — Single-package majors with API churn

Routing libraries, DI containers, secure-storage clients, test frameworks. These break code the project actually uses.

**Action:** read the **CHANGELOG**, then check out the branch, run the full test suite. Fix breaks. Don't merge from the GitHub UI without local validation.

### Tier 4 — GitHub Actions majors

`actions/checkout`, `actions/setup-*`, `actions/upload-artifact`, etc. These have a history of silently breaking workflows (the `actions/upload-artifact@v4` "no merge" change broke many pipelines).

**Action:** **default to closing without merging.** Pin to current major and add to dependabot.yml's `ignore` for `update-types: ["version-update:semver-major"]`. Only manually bump when you need a feature in the new major.

```yaml
# dependabot.yml — pin Actions to current majors
- package-ecosystem: "github-actions"
  directory: "/"
  ignore:
    - dependency-name: "actions/*"
      update-types: ["version-update:semver-major"]
```

---

## Coupling traps that flag a "🔴 don't merge alone"

Dependabot operates per-pubspec/per-pyproject. It can't see when two files coordinate on a version. Three patterns to watch for:

### Cross-package pin coordination

If `packages/foo` and `apps/bar` both pin `some-dep: ^9.x` separately, Dependabot will open a v10 bump only against one of them. Merging that PR alone breaks `flutter pub get` (or `pip install`) on the other side.

**Detect:** before merging any major bump, grep for the package name across **every** `pubspec.yaml`, `pyproject.toml`, `package.json`:

```bash
grep -rn "package_name" --include=pubspec.yaml --include=pyproject.toml --include=package.json
```

If it appears in more than one place at different version constraints, the bump must be cross-cut. Either:
- Open a manual PR that bumps all of them together
- Or close Dependabot's PR and wait for the new major to be irrelevant / replaced

### Paired major bumps in one ecosystem

Some Python tools have hard inter-deps: `pytest 9` won't install with `pytest-asyncio 0.x`. Dependabot opens them as separate PRs, but merging only one fails the install.

**Detect:** for any test-framework or linter major bump, run `pip install -e ".[dev]"` against the proposed `pyproject.toml` and check for "ResolutionImpossible" / "conflicting dependencies" errors.

**Action:** either (a) merge them together (cherry-pick the second PR into the first), or (b) merge in dependency order with the constraint loosened temporarily.

### New lint warnings on lint-config bumps

Bumping `flutter_lints`, `eslint`, `ruff` config rules can surface new warnings on otherwise unchanged code. Examples seen in the wild:
- `flutter_lints 6` flags `unnecessary_library_name` (a `library foo;` declaration that's optional in Dart 3+)
- `eslint 10` deprecates several rules

**Detect:** check out branch, run `flutter analyze` / `npx eslint .` / `ruff check .`. Read the warnings.

**Action:** either fix the code first on `main`, OR fix-on-merge.

---

## Test methodology

For each PR, what to run before deciding to merge:

| Ecosystem | Commands |
|-----------|----------|
| **Python** | `git checkout origin/<branch> -- apps/server/pyproject.toml`<br>`cd apps/server && pip install -e ".[dev]" && python -m pytest -q && python -m black --check . && python -m ruff check .`<br>`git checkout main -- apps/server/pyproject.toml` |
| **Flutter (lib package)** | `git checkout origin/<branch> -- packages/foo/pubspec.{yaml,lock}`<br>`cd packages/foo && flutter pub get && flutter analyze`<br>**Also**: `cd ../../apps/<app> && flutter pub get` (verify downstream resolution)<br>`git checkout main -- packages/foo/pubspec.{yaml,lock}` |
| **Flutter (app)** | `git checkout origin/<branch> -- apps/foo/pubspec.{yaml,lock}`<br>`cd apps/foo && flutter pub get && flutter analyze && flutter test`<br>`git checkout main -- apps/foo/pubspec.{yaml,lock}` |
| **npm** | `git checkout origin/<branch> -- apps/foo/package*.json`<br>`cd apps/foo && npm ci && npm run build && npm test`<br>`git checkout main -- apps/foo/package*.json` |
| **GitHub Actions** | Inspect diff for arg changes; if none, plausibly safe; if any, read action README |

This loop revert-on-each pattern keeps your working tree untouched between checks. You're effectively running each PR's pubspec/pyproject through your local toolchain without checking the branch fully out.

---

## Merge order rules

Once classified, merge in this order:

1. **Tier 1 grouped bumps first.** Lowest risk, fastest signal that CI still works.
2. **Tier 2 single-package majors.** Watch for new lint warnings; fix-on-merge or pre-fix.
3. **Tier 3 high-risk majors — only after local validation.** Don't merge UI-only.
4. **Coupled bumps merge together** — either bundle them in one PR, or merge sequentially in the same hour to keep `main` consistent.
5. **Tier 4 Actions** — close, pin, ignore. Re-evaluate quarterly.

After each merge, **wait for CI to go green** before merging the next. Concurrent CI runs can mask interactions.

---

## When to bail on a PR

Sometimes a Dependabot PR isn't worth merging at all:

- The bump introduces a hard breaking change that would require non-trivial refactor (`go_router 13 → 17` if you use deprecated APIs heavily).
- The bump breaks downstream coupling and you're not ready to do the cross-package cut.
- The new major has known issues / open bugs that haven't shipped a fix yet.
- The dependency itself is one you're planning to remove.

In each case: **close the PR with a comment explaining why**. Add the package + version to `dependabot.yml`'s `ignore` if you want the bump to stop being suggested:

```yaml
- package-ecosystem: "pub"
  directory: "/apps/mobile"
  ignore:
    - dependency-name: "go_router"
      versions: ["17.x", "18.x"]   # un-ignore in 6 months
```

Don't just close-and-forget; the next Dependabot run reopens the same PR.

---

## Worked example — Fluxora's first triage (2026-05-01)

Twenty PRs opened in one batch. Tiering:

- **6 grouped (Tier 1):** python-runtime (FastAPI 0.111→0.136 + 6 others), core dart-deps, desktop dart-deps, plus 3 npm. All passed CI, merged immediately.
- **5 single-package majors (Tier 2):** `flutter_lints` (mobile + core), `pytest`, `pytest-asyncio`, `black`. All passed local tests; `flutter_lints` in core needed a one-line code fix (remove `library fluxora_core;`).
- **3 risky majors (Tier 3):** `go_router 13 → 17`, `get_it 7 → 9` — both passed local tests against existing usage. Surprised but verified. `flutter_secure_storage 9 → 10` was the **trap**: bumping it in `packages/fluxora_core` broke `apps/mobile` and `apps/desktop` because both had separate `^9.x` pins. Closed the PR; will be reopened as a manual cross-pubspec bump.
- **5 Actions majors (Tier 4):** all closed. `dependabot.yml` updated with `ignore: actions/* update-types: ["version-update:semver-major"]` to stop the recurring flood.
- **1 paired-only (`pytest 9` + `pytest-asyncio 1.3`):** must merge together; alone, `pytest 9` fails install resolution against the existing `pytest-asyncio 0.23.7` pin.

Net: 14 of 20 merged cleanly. 1 needed a code fix first. 5 closed with rationale.

---

## Cross-references

- **Dependabot config:** [`.github/dependabot.yml`](../../../.github/dependabot.yml)
- **Action workflow patterns:** [`03_github_ci_cd.md`](./03_github_ci_cd.md)
- **Branch / PR workflow:** [`04_branch_and_pr_workflow.md`](./04_branch_and_pr_workflow.md)

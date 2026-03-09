# JS Repo Architecture — Summary

## Current State

Four repos. Two JS repos (`construkted.js`, `construkted.uploadjs`) build bundles that get manually copied into the WordPress theme (`construkted_reality_v1.x`). The API (`construkted_api`) is a separate Node.js backend.

- **construkted.js** — 55+ TypeScript files, ~394K built lines. 3D viewer, maps, annotations. Legitimately complex. Needs its own build pipeline.
- **construkted.uploadjs** — 6 files, ~1,700 lines. File upload UI. Too small to justify a separate repo.
- **WordPress theme** — contains 7 hand-written JS files (~1,067 lines) with no build tool, plus a mystery `construkted.admin.js` whose source repo is missing.

## Three Problems

1. **`construkted.uploadjs` is unnecessary overhead.** 6 files duplicating the entire tooling stack of a separate repo. The build config has hardcoded Windows paths (`C:/xampp/htdocs/...`).
2. **Orphaned code.** `construkted.admin.js` has no source repo. If the developer's machine dies, the source is gone.
3. **Inconsistent tooling.** Some JS gets full TypeScript + linting; 7 files in WordPress get zero quality checks.

## Recommendation

**Monorepo with workspaces** (industry standard). One repo, multiple packages, shared config:

```
construkted-frontend/
├── packages/
│   ├── viewer/       ← construkted.js
│   ├── upload/       ← construkted.uploadjs
│   ├── admin/        ← construkted.admin.js (source recovered)
│   └── dashboard/    ← the 7 hand-written JS files
├── shared/           ← shared types, utilities
├── package.json
├── tsconfig.base.json
└── eslint.config.js
```

**Why:** Shared tooling config, code sharing between packages, atomic cross-package changes, clear rules for where new JS goes. ~90% confident this is the right move.

**Caveat:** For a 1-2 person team with slow growth, setup cost may delay payoff. But the orphaned `construkted.admin.js` shows the current approach already has gaps.

## Action Item

Ask Zhefengjin: *"Where is the source for `construkted.admin.js`? If we add another JS feature, do we create a 4th repo?"*

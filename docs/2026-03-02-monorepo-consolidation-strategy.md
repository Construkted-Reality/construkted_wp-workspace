---
title: "feat: Consolidate four repositories into a single monorepo with CI/CD deployment"
type: feat
status: draft
date: 2026-03-02
---

# Monorepo Consolidation Strategy

## Overview

Consolidate all four repositories (`construkted_api`, `construkted.js`, `construkted.uploadjs`, `construkted_reality_v1.x`) into a single monorepo with automated CI/CD deployment pipelines. Replace the current manual git-pull deployment and cross-repo artifact copying with rsync-based deployments triggered by GitHub Actions, using GitHub Environments to control deployment targets.

## Problem Statement / Motivation

### Cross-Repo Coordination Is the Bottleneck

A single feature frequently requires changes across two or more repos. The current workflow forces developers to:

- Maintain matching branch names across repos (DEVGUIDE: "every js branch should have a corresponding construkted_reality branch")
- Manually build JS, copy artifacts to the theme repo, and commit them
- Decide which repo an issue belongs in when it spans multiple repos
- Coordinate pull requests across repos for a single logical change

### The JS-to-Theme Pipeline Is a Rube Goldberg Machine

**`construkted.js`** has a GitHub Action (`.github/workflows/deploy.yml`) that:
1. Builds the JS
2. Clones the `construkted_reality_v1.x` repo via SSH deploy key
3. Checks out or creates a matching branch
4. Copies the built artifact into the cloned repo
5. Commits and pushes to the theme repo

This is a distributed monorepo with extra failure modes.

**`construkted.uploadjs`** has no CI/CD at all. The only build-to-theme path is a Vite `closeBundle` plugin with hardcoded Windows paths (`C:/xampp/htdocs/...` and `C:/laragon/www/...`). This does not work on Linux, in CI, or for any developer who doesn't use Xampp or Laragon.

**The theme repo commits built JS artifacts.** `construkted.js` and `construkted.upload.js` (compiled, obfuscated output) are tracked in git inside the theme. This means derived files are version-controlled, creating merge conflicts on the binary output and obscuring actual changes in diffs.

### The API Is More Coupled Than It Appears

Evidence of coupling between `construkted_api` and the WordPress theme:

| Evidence | Location |
|----------|----------|
| API hardcodes WP theme path | `config.ts:41` — `/wp-content/themes/gowatch-child/control_asset_details.php` |
| Cross-repo feature in progress | `feature/shared-secret-auth` branch spans both repos, with planning docs in API naming specific theme files |
| Implicit type contracts | `AssetModelTypes`, error codes (100–1000), status codes (QUEUED=10 through CANCELED=60) defined independently in both repos |
| Bidirectional HTTP calls | WP→API: tiling, cancellation, deletion, version checks. API→WP: error reporting, field updates, pinging |
| CHANGELOG cross-references | API changelog references `construkted_reality_v1.x` GitHub issues |
| Shared secret | `X-Construkted-Key` header and `WP_SHARED_SECRET` env var must match across repos |

### No Single Home for Documentation

AI agent documentation, architecture decisions, and learnings have no natural home. Creating a 5th repo for docs adds management overhead. The monorepo provides a `docs/` directory that sits alongside all the code it documents.

## Current State

### Repository Inventory

| Repo | Stack | Working Branch | Deploy Target | Deploy Method |
|------|-------|---------------|---------------|---------------|
| `construkted_api` | Node.js/TypeScript, Express | `master` | tile03/04/05 servers (port 5000) | Manual SSH + git pull + systemd restart |
| `construkted.js` | TypeScript, Vite/Rollup/Gulp | `develop` | Built artifact committed to theme repo | GitHub Action clones theme repo and pushes |
| `construkted.uploadjs` | TypeScript, Vite | `main` | Built artifact manually copied to theme | Local-only, hardcoded Windows paths |
| `construkted_reality_v1.x` | WordPress PHP theme | `develop` | VPS with cPanel (4 environments) | GitHub Action: SSH + git reset --hard + git pull |

### Current Deployment Environments (Theme)

| Environment | Branch Trigger | Server Path | Purpose |
|-------------|---------------|-------------|---------|
| Production | `master` | `/home/construkted/public_html` | Live site |
| Staging (gw4) | `develop` | `/home/gw4/public_html` | QA/staging |
| Dev 1 | `dev1*` branches | `/home/dev01con/public_html` | Development |
| Dev 2 | `dev2*` branches | `/home/dev02con/public_html` | Development |

### Current Deployment (API)

| Server | Domain | Purpose |
|--------|--------|---------|
| tile03 | tile03-api.construkted.com | Production |
| tile04 | tile04-api.construkted.com | Development |
| tile05 | tile05-api.construkted.com | Development |

Deployed manually via SSH. Runs `ts-node` directly against TypeScript source (not compiled output). Managed by systemd (`construkted_api_prod.service`).

### Known Technical Debt (Pre-Migration)

These issues exist today and should be addressed during or immediately after migration:

1. **`construkted.js` has three build systems** — Vite (dev), Rollup (legacy), Gulp + Rollup + javascript-obfuscator (production). Consolidate to Vite only.
2. **`construkted.uploadjs` has no `build` script** — only `dev` (watch mode). No way to produce a production build from npm scripts.
3. **`construkted_api` runs ts-node in production** — the systemd service executes `ts-node index.ts` instead of the compiled `dist/index.js`.
4. **No tests in any repo.** Zero test files, zero test frameworks, zero test scripts.
5. **CesiumJS 1.132 is vendored in the theme** (~5MB+ in git). Should be loaded from CDN or npm.
6. **Dead dependencies** across JS repos (unused Rollup plugins, `javascript-obfuscator` installed but not wired in uploadjs, deprecated `request` library in API).
7. **Pre-commit hooks disabled** — `construkted.js` husky config has lint commented out.

## Proposed Solution

### Monorepo Structure

```
construkted/                          # Monorepo root
├── packages/
│   ├── api/                          # construkted_api (Node.js tiling server)
│   │   ├── src/
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── js/                           # construkted.js (Cesium 3D viewer library)
│   │   ├── src/
│   │   ├── package.json
│   │   ├── vite.config.js
│   │   └── tsconfig.json
│   └── uploadjs/                     # construkted.uploadjs (upload form)
│       ├── src/
│       ├── package.json
│       ├── vite.config.js
│       └── tsconfig.json
├── theme/                            # construkted_reality_v1.x
│   └── wp-content/
│       └── themes/
│           ├── gowatch/              # Parent theme (vendored)
│           └── gowatch-child/        # Active child theme
│               ├── functions.php
│               ├── includes/
│               │   ├── construkted/
│               │   │   └── assets/
│               │   │       └── js/   # ← construkted.js build output (gitignored)
│               │   └── frontend-submission/
│               │       └── assets/
│               │           └── js/   # ← construkted.uploadjs build output (gitignored)
│               └── ...
├── shared/                           # Shared type contracts (new)
│   ├── asset-model-types.ts          # AssetModelTypes enum (single source of truth)
│   ├── error-codes.ts                # Error codes 100–1000
│   ├── status-codes.ts               # QUEUED=10, RUNNING=20, etc.
│   └── index.ts
├── docs/                             # Architecture decisions, AI agent docs, learnings
│   ├── brainstorms/
│   ├── plans/
│   └── research/
├── .github/
│   └── workflows/
│       ├── deploy-theme.yml          # Build JS + rsync theme to WP servers
│       ├── deploy-api.yml            # rsync API to tiling servers
│       └── ci.yml                    # Lint, typecheck, test (when tests exist)
├── package.json                      # Workspace root (npm workspaces)
├── turbo.json                        # (Optional) Turborepo for build orchestration
├── AGENTS.md                         # AI agent configuration
└── .gitignore
```

### Key Design Decisions

**Built JS artifacts are gitignored.** The `theme/.../assets/js/construkted.js` and `theme/.../frontend-submission/assets/js/construkted.upload.js` files are NOT committed. They are built in CI and deployed as part of the theme. This eliminates merge conflicts on binary/obfuscated output and makes diffs meaningful.

**npm workspaces at the root.** The root `package.json` defines workspaces for `packages/js`, `packages/uploadjs`, `packages/api`, and `shared`. This enables shared dependency hoisting and cross-package imports (e.g., `packages/api` can `import { AssetModelType } from '@construkted/shared'`).

**rsync replaces git-pull for deployment.** The deployment servers no longer need the monorepo cloned. They receive only the files relevant to them (theme files for the WP VPS, API files for the tiling servers) via rsync over SSH.

**Path-based CI triggers.** Each deployment workflow only triggers when relevant files change. A theme-only change does not redeploy the API, and vice versa. An API-only change does not touch the WP servers.

**`shared/` changes trigger both pipelines.** A change to shared type contracts (error codes, status codes, asset model types) is by definition a cross-cutting change — both the API and the theme need to redeploy with updated definitions. If a `shared/` change is purely additive and backward-compatible, the second deploy is a no-op in practice, but the pipeline fires to keep environments consistent.

**GitHub Environments control deployment targets, not branch names.** Branch names describe the work being done (`feature/shared-secret-auth`, `fix/upload-timeout`). The deployment target is a separate, explicit choice made at deploy time via GitHub Environments. See the CI/CD Pipeline Design section for details.

**The WP admin UI controls which tiling server each WP instance uses.** WordPress stores configurable API server URLs in the database (`api_urls` option), managed through Settings > Construkted > Backend Server URLs. The CI/CD pipeline does not enforce which WP dev server talks to which tiling server — that mapping is set by the developer in the WP admin UI after deploying to a dev environment. This is the same workflow as today.

## CI/CD Pipeline Design

### Deployment Target Selection: GitHub Environments

Deployment targets are defined as **GitHub Environments** in the repository settings, not derived from branch names. Each environment holds its own secrets (SSH host, user, path) and optional protection rules. The workflow reads secrets from whichever environment is selected — there is no if/else branch-name logic in the YAML.

**Theme environments:**

| Environment | Secrets | Protection Rules | Purpose |
|-------------|---------|-----------------|---------|
| `theme-production` | DEPLOY_HOST, DEPLOY_USER, DEPLOY_PATH for prod VPS | Require 1 reviewer approval. Restrict to `main` only. | Live site |
| `theme-staging` | Same secret names, staging (gw4) values | No approval. Restrict to `main` and `develop`. | QA/staging |
| `theme-dev1` | Same secret names, dev01 values | No restrictions. Any branch. | Dev server 1 |
| `theme-dev2` | Same secret names, dev02 values | No restrictions. Any branch. | Dev server 2 |

**API environments:**

| Environment | Secrets | Protection Rules | Purpose |
|-------------|---------|-----------------|---------|
| `api-production` | API_HOST=tile03, API_USER | Require 1 reviewer approval. Restrict to `main` only. | tile03 (production) |
| `api-dev-tile04` | API_HOST=tile04, API_USER | No restrictions. Any branch. | tile04 (development) |
| `api-dev-tile05` | API_HOST=tile05, API_USER | No restrictions. Any branch. | tile05 (development) |

Adding a new server in the future means adding a new environment in GitHub settings. No workflow YAML changes required.

### Selective Deployment — Only What Changed

Path-based triggers ensure each pipeline only fires when its relevant files change:

| What changed | Theme pipeline fires? | API pipeline fires? |
|---|---|---|
| `theme/**` only | Yes | No |
| `packages/js/**` or `packages/uploadjs/**` only | Yes | No |
| `packages/api/**` only | No | Yes |
| `shared/**` | Yes | Yes |
| `docs/**` or root config files | No | No |

A spelling fix in the API fires only `deploy-api.yml`. A CSS tweak in the theme fires only `deploy-theme.yml`. WP servers are never touched by an API-only change, and tiling servers are never touched by a theme-only change.

### Theme Deployment (`deploy-theme.yml`)

**Automatic deploys** fire on push to `main` (→ `theme-production`) and `develop` (→ `theme-staging`), but only when theme or JS files changed.

**Dev environment deploys** are triggered manually via `workflow_dispatch`, selecting the target environment from a dropdown. Any branch can deploy to any dev environment.

```yaml
on:
  push:
    branches: [main, develop]
    paths:
      - 'theme/**'
      - 'packages/js/**'
      - 'packages/uploadjs/**'
      - 'shared/**'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment target'
        required: true
        type: environment   # GitHub renders this as a dropdown of defined environments

jobs:
  deploy-theme:
    runs-on: ubuntu-latest
    environment: >-
      ${{ inputs.environment
          || (github.ref_name == 'main' && 'theme-production')
          || 'theme-staging' }}
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install dependencies
        run: npm ci

      - name: Build construkted.js
        run: npm run build --workspace=packages/js
        # Output → theme/.../construkted/assets/js/construkted.js

      - name: Build construkted.uploadjs
        run: npm run build --workspace=packages/uploadjs
        # Output → theme/.../frontend-submission/assets/js/construkted.upload.js

      - name: Deploy via rsync
        run: |
          rsync -avz --delete \
            --exclude='.git' \
            --exclude='node_modules' \
            --exclude='.env' \
            theme/wp-content/themes/ \
            ${{ secrets.DEPLOY_USER }}@${{ secrets.DEPLOY_HOST }}:${{ secrets.DEPLOY_PATH }}/wp-content/themes/
        # DEPLOY_HOST, DEPLOY_USER, DEPLOY_PATH are environment-specific secrets
        # No branch-name if/else logic — the environment provides the correct values
```

**Developer workflow for dev deployments:**

1. Push your branch (name it whatever describes the work — no prefix required)
2. Go to **Actions → `deploy-theme.yml` → Run workflow**
3. Select your branch and choose `theme-dev1` or `theme-dev2` from the environment dropdown
4. Click Run

To move the same branch to a different server: repeat step 2–4 with a different environment selection. No branch rename needed.

### API Deployment (`deploy-api.yml`)

**Automatic deploys** fire on push to `main` (→ `api-production`) only, when API files changed.

**Dev tiling server deploys** are always manual via `workflow_dispatch`. This reflects the reality that dev API deployments are ad-hoc — you choose which tiling server to target based on what you're testing, not based on branch name.

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'packages/api/**'
      - 'shared/**'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target tiling server'
        required: true
        type: environment

jobs:
  deploy-api:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'api-production' }}
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install dependencies
        run: npm ci --workspace=packages/api

      - name: Build API (compile TypeScript)
        run: npm run build --workspace=packages/api
        # Produces packages/api/dist/index.js

      - name: Deploy via rsync
        run: |
          rsync -avz --delete \
            --exclude='node_modules' \
            --exclude='.env' \
            --exclude='data/' \
            --exclude='tmp/' \
            --exclude='log/' \
            packages/api/ \
            ${{ secrets.API_USER }}@${{ secrets.API_HOST }}:~/construkted_api/

      - name: Install production deps and restart
        run: |
          ssh ${{ secrets.API_USER }}@${{ secrets.API_HOST }} \
            "cd ~/construkted_api && npm ci --omit=dev && sudo systemctl restart construkted_api_prod.service"
        # API_HOST and API_USER are environment-specific secrets
        # api-production → tile03, api-dev-tile04 → tile04, api-dev-tile05 → tile05
```

This also fixes the ts-node-in-production issue — the systemd service should be updated to run `node dist/index.js` instead of `ts-node index.ts`.

### Cross-Cutting Changes (Both API and Theme Changed)

When a branch changes both `packages/api/` and `theme/`, both workflows are triggered independently. Each is deployed manually to its respective dev environment from the Actions UI. Because deploys are manual for dev environments, there is no race condition and no ambiguity about which server received what.

Typical workflow for a cross-cutting change:

1. Push `feature/shared-secret-auth` with changes in both `packages/api/` and `theme/`
2. Go to Actions → `deploy-api.yml` → Run workflow → select branch + `api-dev-tile04` → Run
3. Go to Actions → `deploy-theme.yml` → Run workflow → select branch + `theme-dev1` → Run
4. In dev01's WP admin, confirm the API URL points to `tile04-api.construkted.com`
5. Test the integrated change

Both deploys happen without SSHing into any server manually.

### CI Checks (`ci.yml`)

Triggers on all pull requests and all pushes. No deployment — checks only.

```yaml
on: [push, pull_request]

jobs:
  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npx tsc --noEmit --workspace=packages/js
      - run: npx tsc --noEmit --workspace=packages/uploadjs
      - run: npx tsc --noEmit --workspace=packages/api

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run lint --workspaces --if-present

  # Add test jobs here when tests exist
```

### Best Practices for Vite-Built JS in WordPress Theme

1. **Never commit built artifacts.** The `theme/.../assets/js/` directories are `.gitignored`. Builds happen in CI only.
2. **Build in CI, not on the server.** The WordPress VPS should not have Node.js installed. It receives only the final theme files.
3. **Version the build.** Use `wp_enqueue_script` with a version parameter derived from `CONSTRUKTED_VERSION` in `functions.php`. Consider appending a short git hash in CI for cache busting:
   ```php
   wp_enqueue_script('construkted-script', $js_url, ['jquery', 'cesiumjs'], CONSTRUKTED_VERSION . '-' . CONSTRUKTED_BUILD_HASH, true);
   ```
4. **Source maps.** Generate source maps in CI. Deploy them alongside the JS for staging/dev environments. Exclude from production deploys (or serve them only to authenticated users).
5. **Consolidate to one build tool.** Vite is the modern path. Remove the Rollup and Gulp+Obfuscator pipelines. If obfuscation is required, add it as a Vite plugin (e.g., `rollup-plugin-obfuscator`), not a separate post-build step.

## Shared Type Contracts

### Problem

Today, type contracts between the API and theme are implicit:

- `AssetModelTypes` (Unknown, PolygonMesh, PointCloud, 3DTile, 3DCADModel, Orthomosaic) — defined in `construkted_api/lib/tiling/assetModelTypes.ts`, expected by WordPress PHP as string values in query parameters
- Error codes (100–1000) — defined in `construkted_api/lib/taskErrorInfos.ts`, parsed by theme in `control_asset_details.php`
- Status codes (QUEUED=10, RUNNING=20, etc.) — defined independently in both `construkted_api/lib/statusCodes.ts` and `construkted_reality_v1.x/.../functions.php`
- API response shape `{errCode, errMsg, ...data}` — defined in `construkted_api/lib/http.ts`, expected by theme PHP

There is no validation. Types drift silently.

### Solution

Create a `shared/` package that is the single source of truth:

```typescript
// shared/asset-model-types.ts
export enum AssetModelType {
  Unknown = 'Unknown',
  PolygonMesh = 'PolygonMesh',
  PointCloud = 'PointCloud',
  ThreeDTile = '3DTile',
  ThreeDCADModel = '3DCADModel',
  Orthomosaic = 'Orthomosaic',
}

// shared/status-codes.ts
export enum TilingStatus {
  QUEUED = 10,
  RUNNING = 20,
  COMPLETED = 30,
  FAILED = 40,
  CANCELED = 60,
}

// shared/error-codes.ts
export const ErrorCodes = {
  INVALID_INPUT: 100,
  DOWNLOAD_FAILED: 200,
  // ... etc
} as const;
```

- `packages/api` imports from `@construkted/shared`
- `packages/js` imports from `@construkted/shared`
- For PHP: add a CI step or script that generates `shared-constants.php` from the TypeScript definitions. This ensures PHP constants stay in sync without manual duplication.

## Migration Plan

### Phase 0: Preparation (Before Migration Day)

1. **Get team buy-in.** Everyone's workflow changes. Communicate what's happening and why.
2. **Ensure all repos have clean working states.** Merge or shelve in-progress branches. The migration should happen from the default branches (`master`/`develop`/`main`).
3. **Document the current implicit contracts.** Inventory all shared types, constants, and API shapes before migration so nothing is missed when creating the `shared/` package.
4. **Consolidate `construkted.js` build tooling.** Remove Rollup and Gulp. Make Vite the sole build system. This is easier to do before the migration than after.
5. **Add a `build` script to `construkted.uploadjs`.** Currently only `dev` (watch mode) exists.

### Phase 1: Create the Monorepo (Half-Day)

Use `git filter-repo` or a similar tool to migrate each repo while preserving full git history:

```bash
# For each repo, rewrite history to move files under the target directory
# Example for construkted_api:
git clone construkted_api construkted_api_migrated
cd construkted_api_migrated
git filter-repo --to-subdirectory-filter packages/api

# Repeat for each repo:
# construkted.js         → packages/js
# construkted.uploadjs   → packages/uploadjs
# construkted_reality_v1.x → theme
```

Then merge all four into a new repo:

```bash
mkdir construkted && cd construkted && git init
git remote add api ../construkted_api_migrated
git remote add js ../construkted_js_migrated
git remote add uploadjs ../construkted_uploadjs_migrated
git remote add theme ../construkted_reality_migrated

git fetch api && git merge api/master --allow-unrelated-histories
git fetch js && git merge js/develop --allow-unrelated-histories
git fetch uploadjs && git merge uploadjs/main --allow-unrelated-histories
git fetch theme && git merge theme/develop --allow-unrelated-histories
```

### Phase 2: Wire Up Workspaces and Builds (Half-Day)

1. Create root `package.json` with npm workspaces
2. Update `packages/js/vite.config.js` to output directly to `theme/.../assets/js/`
3. Update `packages/uploadjs/vite.config.js` to output directly to `theme/.../frontend-submission/assets/js/`
4. Add `theme/.../assets/js/construkted.js` and `theme/.../assets/js/construkted.upload.js` to `.gitignore`
5. Remove the built artifacts from git tracking (`git rm --cached`)
6. Create `shared/` package with extracted type contracts
7. Update imports in `packages/api` and `packages/js` to use `@construkted/shared`
8. Verify all three packages build successfully from the monorepo root

### Phase 3: Set Up GitHub Environments and CI/CD (Half-Day)

1. **Create GitHub Environments** in repository Settings → Environments:
   - `theme-production` — add DEPLOY_HOST, DEPLOY_USER, DEPLOY_PATH secrets; set branch restriction to `main`; enable required reviewer approval
   - `theme-staging` — add secrets for gw4; restrict to `main` and `develop`
   - `theme-dev1` — add secrets for dev01; no restrictions
   - `theme-dev2` — add secrets for dev02; no restrictions
   - `api-production` — add API_HOST (tile03), API_USER secrets; restrict to `main`; enable required reviewer approval
   - `api-dev-tile04` — add API_HOST (tile04), API_USER secrets; no restrictions
   - `api-dev-tile05` — add API_HOST (tile05), API_USER secrets; no restrictions
2. Create `.github/workflows/deploy-theme.yml` with path-based triggers and environment-driven rsync deployment
3. Create `.github/workflows/deploy-api.yml` with path-based triggers and environment-driven rsync deployment
4. Create `.github/workflows/ci.yml` for typecheck and lint on all pushes and PRs
5. Test deployment to dev environments first (manually dispatch to `theme-dev1` and `api-dev-tile04`)
6. Remove the old GitHub Actions from the individual repos (they will be in the monorepo's git history but no longer active)

### Phase 4: Validate and Cut Over (Half-Day)

1. Deploy to dev1 and tile04 via the new pipeline
2. Verify the site works — JS loads, uploads work, API callbacks succeed
3. Deploy to staging (gw4) and verify
4. Update developer documentation / DEVGUIDE with new workflow (branch naming is free; use Actions UI for dev deploys)
5. Archive the four original GitHub repositories (do not delete — archive)
6. Deploy to production (will require reviewer approval via the environment protection rule)

### Phase 5: Cleanup (Following Week)

1. Update the API systemd service to run compiled output (`node dist/index.js`) instead of `ts-node`
2. Remove dead dependencies from all packages
3. Remove old Rollup/Gulp configs from `packages/js`
4. Fix `construkted.uploadjs` misplaced dependencies (`vite`, `@types/jquery` in `dependencies` instead of `devDependencies`)
5. Evaluate replacing vendored CesiumJS with CDN or npm dependency
6. Set up pre-commit hooks (lint, typecheck) in the monorepo

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| rsync deployment fails on cPanel VPS due to permissions | Medium | High | Test rsync to all environments before cutting over. Ensure SSH user has write access to theme directories. Fall back to the branch-based approach in the appendix if needed. |
| Migration breaks in-progress feature branches | High | Medium | Merge or shelve all active branches before migration. Provide a script to rebase old branches onto the new monorepo structure. |
| Path-based CI triggers fire incorrectly (e.g., docs change triggers theme deploy) | Low | Medium | Use precise path filters. Test with dry-run deploys. Production environment protection rules provide an approval gate as a final safeguard. |
| GitHub plan does not support environment protection rules | Medium | Medium | Protection rules (required reviewers, branch restrictions) require GitHub Team plan for private repos. Without them, environments still work for secrets isolation but lack the approval gate. Evaluate plan upgrade or accept the risk. |
| Monorepo size (vendored CesiumJS, parent theme) slows git operations | Medium | Low | Use shallow clones in CI (`fetch-depth: 1`). Consider removing vendored CesiumJS in favour of CDN. Use `.gitattributes` for large binary files. |
| Team members unfamiliar with the Actions UI for dev deploys | Medium | Medium | Write clear DEVGUIDE with screenshots. The workflow is two extra clicks compared to a branch push — the trade-off is full flexibility over which server gets which branch. |
| API deployment via rsync misses environment-specific config (.env, SSL certs) | Low | High | Exclude `.env`, `data/`, `tmp/`, `log/` from rsync. These stay on the server permanently and are never deployed from CI. |

## What We Stop Doing

- Committing built JS artifacts to the theme repo
- The `construkted.js` GitHub Action that clones a second repo to push artifacts
- Manually copying built JS between sibling directories
- Encoding deployment targets in branch names (`dev1/my-feature`, `dev2/other-feature`)
- Maintaining matching branch names across repos ("every js branch should have a corresponding construkted_reality branch")
- Debating which repo an issue belongs in
- Maintaining implicit type contracts that drift between repos
- Manual SSH + git pull + systemd restart on tiling servers
- Accidentally redeploying the API when only the theme changed (and vice versa)

## What We Start Doing

- One repo, one branch, one PR for cross-cutting changes
- Branch names that describe the work, not the deployment target
- CI builds JS and deploys the theme with built artifacts included — only when theme/JS files changed
- CI deploys the API from compiled TypeScript (not ts-node) — only when API files changed
- GitHub Environments for explicit, auditable deployment target selection with per-environment secrets
- Required reviewer approval before any push reaches production (via environment protection rules)
- Shared TypeScript types as the single source of truth for API contracts
- rsync-based deployment (each server receives only the files it needs)
- WP admin UI continues to control which tiling server each WP instance uses — no change to that workflow
- All documentation, learnings, and architecture decisions in one `docs/` directory

## Open Questions

1. **Turborepo or plain npm workspaces?** Turborepo adds intelligent build caching and task orchestration. For three packages, plain npm workspaces may be sufficient. Turborepo becomes more valuable if build times grow or more packages are added.
2. **Obfuscation — is it still required?** The production `construkted.js` build currently runs through `javascript-obfuscator`. This adds build complexity and makes production debugging harder. Evaluate whether minification + source maps is sufficient, or if obfuscation is a business requirement.
3. **CesiumJS vendoring — CDN or npm?** CesiumJS 1.132 is currently vendored at ~5MB+ in the theme. Options: (a) keep vendored, (b) load from Cesium's CDN, (c) install via npm and bundle/copy in CI. Each has tradeoffs for offline capability, version control, and repo size.
4. **PHP constants generation — manual or automated?** The `shared/` TypeScript types need a PHP counterpart. Options: (a) a simple Node script that generates `shared-constants.php` from the TypeScript, run in CI, (b) maintain PHP constants manually with a CI check that validates they match the TypeScript. Option (a) is more reliable.
5. **GitHub plan for environment protection rules?** Environment protection rules (required reviewers, branch restrictions) are only available on GitHub Team plan or higher for private repos. Confirm the current plan before relying on these as a production safety gate.
6. **Auto-deploy `develop` → `api-dev-tile04`?** The theme pipeline auto-deploys `develop` to staging, but the API pipeline does not auto-deploy `develop` anywhere — all dev API deploys are manual. Consider whether auto-deploying `develop` to tile04 would be convenient or risky for the team's workflow.

---

## Appendix: Branch-Name-Based Deployment (Prior Approach)

This section documents the branch-based deployment routing that was the initial design for this migration. It is retained as a reference and as a fallback option if GitHub Environments prove impractical (e.g., due to GitHub plan constraints or team preference for push-to-deploy on dev servers).

### Why It Was Replaced

Branch-based routing couples version control conventions to infrastructure topology. The branch name serves two masters: it describes the work being done *and* it encodes the deployment target. This means:

- You cannot deploy the same branch to a different server without renaming it
- Branch naming conventions are dictated by infrastructure, not by the nature of the work
- Adding a new server requires updating CI YAML with new branch patterns
- Two developers cannot deploy different branches to the same dev server without overwriting each other

GitHub Environments solve all of these by making the deployment target an explicit choice at dispatch time, decoupled from the branch name.

### Branch → Server Mapping (Theme)

| Branch pattern | Deploys to |
|---|---|
| `main` | Production VPS (`/home/construkted/public_html`) |
| `develop` | Staging VPS — gw4 (`/home/gw4/public_html`) |
| `dev1/*` | Dev server 1 (`/home/dev01con/public_html`) |
| `dev2/*` | Dev server 2 (`/home/dev02con/public_html`) |

### Branch → Server Mapping (API)

| Branch pattern | Tiling server |
|---|---|
| `main` | tile03 — `tile03-api.construkted.com` |
| `develop` | tile04 — `tile04-api.construkted.com` |
| `dev1/*` | tile04 — `tile04-api.construkted.com` |
| `dev2/*` | tile05 — `tile05-api.construkted.com` |

### Theme Workflow YAML (Branch-Based)

```yaml
on:
  push:
    branches: [main, develop, 'dev1/**', 'dev2/**']
    paths:
      - 'theme/**'
      - 'packages/js/**'
      - 'packages/uploadjs/**'
      - 'shared/**'

jobs:
  deploy-theme:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run build --workspace=packages/js
      - run: npm run build --workspace=packages/uploadjs

      - name: Resolve deploy target
        id: target
        run: |
          if [[ "${{ github.ref_name }}" == "main" ]]; then
            echo "host=${{ secrets.PROD_HOST }}" >> $GITHUB_OUTPUT
            echo "path=/home/construkted/public_html" >> $GITHUB_OUTPUT
            echo "user=${{ secrets.PROD_USER }}" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref_name }}" == dev2/* ]]; then
            echo "host=${{ secrets.DEV2_HOST }}" >> $GITHUB_OUTPUT
            echo "path=/home/dev02con/public_html" >> $GITHUB_OUTPUT
            echo "user=${{ secrets.DEV2_USER }}" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref_name }}" == dev1/* ]]; then
            echo "host=${{ secrets.DEV1_HOST }}" >> $GITHUB_OUTPUT
            echo "path=/home/dev01con/public_html" >> $GITHUB_OUTPUT
            echo "user=${{ secrets.DEV1_USER }}" >> $GITHUB_OUTPUT
          else
            # develop
            echo "host=${{ secrets.STAGING_HOST }}" >> $GITHUB_OUTPUT
            echo "path=/home/gw4/public_html" >> $GITHUB_OUTPUT
            echo "user=${{ secrets.STAGING_USER }}" >> $GITHUB_OUTPUT
          fi

      - name: Deploy via rsync
        run: |
          rsync -avz --delete \
            --exclude='.git' --exclude='node_modules' --exclude='.env' \
            theme/wp-content/themes/ \
            ${{ steps.target.outputs.user }}@${{ steps.target.outputs.host }}:${{ steps.target.outputs.path }}/wp-content/themes/
```

### API Workflow YAML (Branch-Based, with `workflow_dispatch` override)

```yaml
on:
  push:
    branches: [main, develop, 'dev1/**', 'dev2/**']
    paths:
      - 'packages/api/**'
      - 'shared/**'
  workflow_dispatch:
    inputs:
      target_server:
        description: 'Target tiling server (overrides branch default)'
        required: true
        type: choice
        options: [tile04, tile05, tile03]

jobs:
  deploy-api:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci --workspace=packages/api
      - run: npm run build --workspace=packages/api

      - name: Resolve target server
        id: target
        run: |
          if [ -n "${{ inputs.target_server }}" ]; then
            echo "host=${{ inputs.target_server }}-api.construkted.com" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref_name }}" == "main" ]]; then
            echo "host=tile03-api.construkted.com" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref_name }}" == dev2/* ]]; then
            echo "host=tile05-api.construkted.com" >> $GITHUB_OUTPUT
          else
            echo "host=tile04-api.construkted.com" >> $GITHUB_OUTPUT
          fi

      - name: Deploy via rsync
        run: |
          rsync -avz --delete \
            --exclude='node_modules' --exclude='.env' \
            --exclude='data/' --exclude='tmp/' --exclude='log/' \
            packages/api/ \
            ${{ secrets.API_USER }}@${{ steps.target.outputs.host }}:~/construkted_api/

      - name: Install and restart
        run: |
          ssh ${{ secrets.API_USER }}@${{ steps.target.outputs.host }} \
            "cd ~/construkted_api && npm ci --omit=dev && sudo systemctl restart construkted_api_prod.service"
```

### When to Use This Approach Instead

Consider reverting to branch-based routing if:

- Your GitHub plan does not support environment secrets on private repos (GitHub Free)
- The team strongly prefers push-to-deploy on dev servers and finds the Actions UI dispatch friction unacceptable
- You have a very small team (1–2 people) where the coupling of branch names to targets is not a practical problem

---
title: "feat: Monorepo and CI/CD strategy — fresh design from first principles"
type: feat
status: draft
date: 2026-03-02
notes: "Designed from scratch without legacy assumptions. Compare with 2026-03-02-monorepo-consolidation-strategy.md"
---

# Construkted Reality — Monorepo &amp; CI/CD Strategy

## Table of Contents

1. [Monorepo Structure](#1-monorepo-structure)
2. [Branch Strategy](#2-branch-strategy)
3. [GitHub Environments Setup](#3-github-environments-setup)
4. [CI/CD Pipeline Design](#4-cicd-pipeline-design)
5. [Selective Deployment](#5-selective-deployment)
6. [Shared Types Package](#6-shared-types-package)
7. [Local Development Workflow](#7-local-development-workflow)
8. [Security Considerations](#8-security-considerations)
9. [Risks and Trade-offs](#9-risks-and-trade-offs)

---

## 1. Monorepo Structure

### Package Manager: pnpm

**Why pnpm over npm/yarn:**
- Native workspace support with `pnpm-workspace.yaml` — simpler than npm workspaces, more deterministic than yarn
- Strict dependency isolation by default (no phantom dependencies — a package can only import what it explicitly declares)
- Content-addressable storage means shared dependencies across packages don't waste disk
- `pnpm --filter` gives fine-grained control for CI (build only what changed)
- First-class `pnpm/action-setup` GitHub Action with built-in caching
- Industry standard for monorepos at this scale (2025-2026)

**Node version:** 22 LTS (current LTS as of 2026, aligns with the existing `actions/setup-node` usage in construkted.js)

### Directory Layout

```
construkted/                          # Repository root
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                    # PR checks: lint, typecheck, build
│   │   ├── deploy-theme.yml          # Theme deployment (build JS + rsync theme)
│   │   ├── deploy-api.yml            # API deployment (build + rsync + restart)
│   │   └── release.yml               # Production deployment with approval gate
│   └── CODEOWNERS
├── packages/
│   ├── js/                           # Viewer library (currently construkted.js)
│   │   ├── src/
│   │   ├── package.json              # name: @construkted/viewer
│   │   ├── tsconfig.json
│   │   └── vite.config.ts
│   ├── uploadjs/                     # Upload library (currently construkted.uploadjs)
│   │   ├── src/
│   │   ├── package.json              # name: @construkted/upload
│   │   ├── tsconfig.json
│   │   └── vite.config.ts
│   ├── api/                          # Processing API (currently construkted_api)
│   │   ├── lib/
│   │   ├── package.json              # name: @construkted/api
│   │   ├── tsconfig.json
│   │   └── eslint.config.mjs
│   └── shared/                       # NEW: Shared type definitions
│       ├── src/
│       │   ├── index.ts
│       │   ├── asset-model-types.ts
│       │   ├── status-codes.ts
│       │   ├── running-status-codes.ts
│       │   ├── error-codes.ts
│       │   └── api-contracts.ts
│       ├── scripts/
│       │   └── generate-php.ts
│       ├── package.json              # name: @construkted/shared
│       └── tsconfig.json
├── theme/                            # WordPress child theme (currently construkted_reality_v1.x)
│   ├── wp-content/themes/gowatch-child/
│   │   ├── includes/
│   │   │   ├── construkted/assets/js/
│   │   │   │   └── .gitkeep          # Built artifacts go here, but NOT committed
│   │   │   └── frontend-submission/assets/js/
│   │   │       └── .gitkeep          # Built artifacts go here, but NOT committed
│   │   ├── functions.php
│   │   ├── style.css
│   │   └── ...
│   └── wp-content/themes/gowatch/    # Parent theme (vendored, rarely changes)
├── docs/                             # Documentation
│   ├── architecture/
│   │   └── decisions/                # ADRs (Architecture Decision Records)
│   ├── agents/                       # AI agent documentation
│   ├── coding-standards.md
│   └── deployment.md
├── pnpm-workspace.yaml
├── package.json                      # Root workspace config
├── tsconfig.base.json                # Shared TypeScript config
├── .eslintrc.base.json               # Shared ESLint config (extended by packages)
├── .prettierrc.js
├── .gitignore
├── .nvmrc                            # Node version pin: 22
└── README.md
```

### Workspace Configuration

**`pnpm-workspace.yaml`:**
```yaml
packages:
  - 'packages/*'
```

Note: `theme/` is intentionally NOT a workspace package — it's pure PHP with no `package.json`. It's a deployment target, not a build dependency.

**Root `package.json`:**
```json
{
  "name": "construkted",
  "private": true,
  "scripts": {
    "build": "pnpm --filter './packages/**' run build",
    "build:js": "pnpm --filter @construkted/viewer build",
    "build:upload": "pnpm --filter @construkted/upload build",
    "build:api": "pnpm --filter @construkted/api build",
    "build:shared": "pnpm --filter @construkted/shared build",
    "build:frontend": "pnpm --filter @construkted/shared build && pnpm --filter @construkted/viewer --filter @construkted/upload build",
    "dev:js": "pnpm --filter @construkted/viewer dev",
    "dev:upload": "pnpm --filter @construkted/upload dev",
    "dev:api": "pnpm --filter @construkted/api dev",
    "lint": "pnpm -r run lint",
    "typecheck": "pnpm -r run typecheck",
    "clean": "pnpm -r run clean"
  },
  "engines": {
    "node": ">=22.0.0",
    "pnpm": ">=9.0.0"
  },
  "packageManager": "pnpm@9.15.0"
}
```

**`tsconfig.base.json`** (shared TypeScript config):
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "isolatedModules": true
  }
}
```

Individual packages extend this with `"extends": "../../tsconfig.base.json"` and override what they need (the API overrides `module` to `CommonJS`, for example).

### `.gitignore` additions

```gitignore
# Built JS artifacts — these are built in CI, never committed
theme/wp-content/themes/gowatch-child/includes/construkted/assets/js/construkted.js
theme/wp-content/themes/gowatch-child/includes/construkted/assets/js/construkted.js.map
theme/wp-content/themes/gowatch-child/includes/frontend-submission/assets/js/construkted.upload.js
theme/wp-content/themes/gowatch-child/includes/frontend-submission/assets/js/construkted.upload.js.map

# Package build outputs
packages/*/dist/
packages/api/dist/

# Dependencies
node_modules/
```

---

## 2. Branch Strategy

### Model: Trunk-Based Development with Short-Lived Feature Branches

**Why not Gitflow:**
- Gitflow's `develop`/`release`/`hotfix` branches add ceremony that doesn't match weekly-or-less deploy cadence with a 4-person team
- The current multi-branch mapping (master→prod, develop→staging, dev1*→dev1, dev2*→dev2) is a bespoke Gitflow variant that's already causing friction
- Gitflow was designed for versioned software releases, not web application deployments

**Why not pure trunk-based:**
- With 4+ developers and mixed ownership, direct-to-main commits are risky without a mature test suite (currently zero tests)
- PRs provide a natural code review checkpoint

### The Model

```
main ─────────────────────────────────────────────►
  │                    ▲          ▲
  ├─ feature/viewer-xyz ─┘       │
  │                              │
  └─ fix/upload-s3-retry ────────┘
```

**`main`** — the single source of truth. Always deployable to production.

**Feature branches** — short-lived (hours to a few days), branched from `main`, merged via PR back to `main`. Naming convention: `feature/<description>`, `fix/<description>`, `chore/<description>`.

### How Deployments Map to Branches

Instead of mapping branches to environments, deployments are triggered by **explicit action on `main`** or **manual dispatch on any branch**.

| Trigger | Target | When |
|---|---|---|
| Push to `main` | Staging (gw4) | Automatic — every merge to main deploys to staging |
| Manual dispatch from `main` | Production | On-demand, with approval gate |
| Manual dispatch from any branch | Dev 1 or Dev 2 | Developer chooses target via workflow dispatch |
| Manual dispatch from any branch | tile04 or tile05 (API dev) | Developer chooses target via workflow dispatch |

**Why this is better than branch-name mapping:**
1. Developers don't have to name branches `dev1/something` to deploy to dev1 — any branch can go to any dev server
2. Two developers can work on separate features and both deploy to different dev servers without branch naming conflicts
3. A developer can deploy the same branch to both dev1 AND dev2 if they want to test in parallel
4. No more `git reset --hard && git pull` on servers — built artifacts are deployed via rsync

### Branch Protection Rules on `main`

- Require PR before merging (no direct pushes)
- Require at least 1 approving review
- Require status checks to pass (CI workflow)
- Require branches to be up-to-date before merging
- Automatically delete head branches after merge

---

## 3. GitHub Environments Setup

### Environment Definitions

| Environment Name | Purpose | Protection Rules | Secrets Scope |
|---|---|---|---|
| `staging` | QA/staging server (gw4) | None — auto-deploys on push to main | WP VPS SSH credentials (gw4 user) |
| `production` | Live site (construkted) | Required reviewer (1+), branch restriction (main only) | WP VPS SSH credentials (construkted user) |
| `dev1` | Developer server 1 | None | WP VPS SSH credentials (dev01con user) |
| `dev2` | Developer server 2 | None | WP VPS SSH credentials (dev02con user) |
| `api-prod` | Production tiling server (tile03) | Required reviewer (1+), branch restriction (main only) | tile03 SSH credentials |
| `api-dev-tile04` | Dev tiling server (tile04) | None | tile04 SSH credentials |
| `api-dev-tile05` | Dev tiling server (tile05) | None | tile05 SSH credentials |

### Secrets per Environment

Each WP environment gets:

| Secret | Description |
|---|---|
| `SSH_HOST` | Server hostname/IP |
| `SSH_PORT` | SSH port |
| `SSH_USER` | cPanel/SSH username |
| `SSH_PRIVATE_KEY` | SSH private key (Ed25519) |
| `DEPLOY_PATH` | Absolute path to theme directory |

Each API environment gets:

| Secret | Description |
|---|---|
| `SSH_HOST` | Server hostname/IP |
| `SSH_PORT` | SSH port |
| `SSH_USER` | SSH username |
| `SSH_PRIVATE_KEY` | SSH private key (Ed25519) |
| `DEPLOY_PATH` | Absolute path to API directory |
| `SERVICE_NAME` | systemd service name for restart |

### Repository-Level Secrets (shared across all workflows)

| Secret | Description |
|---|---|
| `ACTIONS_SSH_KNOWN_HOSTS` | Pre-computed known_hosts entries for all servers (prevents MITM prompts) |

### Why SSH Keys Instead of Passwords

The current workflows use `appleboy/ssh-action` with password auth. This should change:

1. **Passwords stored in GitHub Secrets as plaintext** — SSH keys are more resistant to brute-force
2. **SSH keys can be scoped** — generate a deploy-only keypair per environment, limiting blast radius if a key leaks
3. **SSH keys enable rsync** — you can't rsync over password auth without `sshpass`, which is a security antipattern
4. **Key rotation is simpler** — rotate the key, update one GitHub Secret, done

---

## 4. CI/CD Pipeline Design

### Overview of Workflows

```
PR opened/updated ──► ci.yml (lint, typecheck, build verification)
                             │
                             ▼ (merge to main)
Push to main ──────► deploy-theme.yml (staging auto-deploy)
                  └► [deploy-api.yml staging — if API files changed]

Manual dispatch ───► deploy-theme.yml (choose: dev1, dev2, staging, production)
                  └► deploy-api.yml (choose: tile04, tile05, tile03-prod)

Release ───────────► release.yml (production deploy with approval for both theme + API)
```

### Workflow 1: `ci.yml` — PR Checks

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      shared: ${{ steps.filter.outputs.shared }}
      viewer: ${{ steps.filter.outputs.viewer }}
      upload: ${{ steps.filter.outputs.upload }}
      api: ${{ steps.filter.outputs.api }}
      theme: ${{ steps.filter.outputs.theme }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            shared:
              - 'packages/shared/**'
            viewer:
              - 'packages/js/**'
              - 'packages/shared/**'
            upload:
              - 'packages/uploadjs/**'
              - 'packages/shared/**'
            api:
              - 'packages/api/**'
              - 'packages/shared/**'
            theme:
              - 'theme/**'

  lint-and-typecheck:
    runs-on: ubuntu-latest
    needs: changes
    if: >-
      needs.changes.outputs.shared == 'true' ||
      needs.changes.outputs.viewer == 'true' ||
      needs.changes.outputs.upload == 'true' ||
      needs.changes.outputs.api == 'true'
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v4
        with:
          node-version-file: '.nvmrc'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Lint (shared)
        if: needs.changes.outputs.shared == 'true'
        run: pnpm --filter @construkted/shared lint

      - name: Lint (viewer)
        if: needs.changes.outputs.viewer == 'true'
        run: pnpm --filter @construkted/viewer lint

      - name: Lint (upload)
        if: needs.changes.outputs.upload == 'true'
        run: pnpm --filter @construkted/upload lint

      - name: Lint (api)
        if: needs.changes.outputs.api == 'true'
        run: pnpm --filter @construkted/api lint

      - name: Typecheck all changed packages
        run: pnpm run typecheck

  build-verification:
    runs-on: ubuntu-latest
    needs: changes
    if: >-
      needs.changes.outputs.shared == 'true' ||
      needs.changes.outputs.viewer == 'true' ||
      needs.changes.outputs.upload == 'true' ||
      needs.changes.outputs.api == 'true'
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v4
        with:
          node-version-file: '.nvmrc'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build shared (always first — others depend on it)
        run: pnpm --filter @construkted/shared build

      - name: Build viewer
        if: needs.changes.outputs.viewer == 'true'
        run: pnpm --filter @construkted/viewer build

      - name: Build upload
        if: needs.changes.outputs.upload == 'true'
        run: pnpm --filter @construkted/upload build

      - name: Build API
        if: needs.changes.outputs.api == 'true'
        run: pnpm --filter @construkted/api build

      - name: Verify build artifacts exist
        run: |
          if [ "${{ needs.changes.outputs.viewer }}" == "true" ]; then
            test -f packages/js/dist/construkted.js || (echo "FAIL: construkted.js not built" && exit 1)
          fi
          if [ "${{ needs.changes.outputs.upload }}" == "true" ]; then
            test -f packages/uploadjs/dist/construkted.upload.js || (echo "FAIL: construkted.upload.js not built" && exit 1)
          fi
          if [ "${{ needs.changes.outputs.api }}" == "true" ]; then
            test -f packages/api/dist/index.js || (echo "FAIL: API dist/index.js not built" && exit 1)
          fi

  php-lint:
    runs-on: ubuntu-latest
    needs: changes
    if: needs.changes.outputs.theme == 'true'
    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'
          tools: phpcs

      - name: PHP syntax check
        run: find theme/ -name "*.php" -exec php -l {} \; | grep -v "No syntax errors"
```

### Workflow 2: `deploy-theme.yml` — Theme Deployment

```yaml
name: Deploy Theme

on:
  push:
    branches: [main]
    paths:
      - 'theme/**'
      - 'packages/js/**'
      - 'packages/uploadjs/**'
      - 'packages/shared/**'

  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - dev1
          - dev2
          - staging
          - production
      include_sourcemaps:
        description: 'Include source maps'
        required: false
        type: boolean
        default: true

concurrency:
  group: deploy-theme-${{ github.event.inputs.environment || 'staging' }}
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v4
        with:
          node-version-file: '.nvmrc'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build shared types
        run: pnpm --filter @construkted/shared build

      - name: Build viewer (construkted.js)
        run: pnpm --filter @construkted/viewer build

      - name: Build upload (construkted.upload.js)
        run: pnpm --filter @construkted/upload build

      - name: Assemble theme deployment artifact
        run: |
          mkdir -p deploy-staging-dir

          # Copy the theme directory
          cp -r theme/wp-content/themes/gowatch-child deploy-staging-dir/gowatch-child

          # Place built JS into the theme directory structure
          cp packages/js/dist/construkted.js \
             deploy-staging-dir/gowatch-child/includes/construkted/assets/js/construkted.js

          cp packages/uploadjs/dist/construkted.upload.js \
             deploy-staging-dir/gowatch-child/includes/frontend-submission/assets/js/construkted.upload.js

          # Include source maps based on environment/input
          INCLUDE_MAPS="${{ github.event.inputs.include_sourcemaps || 'true' }}"
          if [ "$INCLUDE_MAPS" == "true" ]; then
            cp packages/js/dist/construkted.js.map \
               deploy-staging-dir/gowatch-child/includes/construkted/assets/js/construkted.js.map
            cp packages/uploadjs/dist/construkted.upload.js.map \
               deploy-staging-dir/gowatch-child/includes/frontend-submission/assets/js/construkted.upload.js.map
          fi

      - name: Upload deployment artifact
        uses: actions/upload-artifact@v4
        with:
          name: theme-deploy-${{ github.sha }}
          path: deploy-staging-dir/gowatch-child
          retention-days: 7

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'staging' }}
    steps:
      - name: Download deployment artifact
        uses: actions/download-artifact@v4
        with:
          name: theme-deploy-${{ github.sha }}
          path: deploy-payload

      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          echo "${{ secrets.ACTIONS_SSH_KNOWN_HOSTS }}" >> ~/.ssh/known_hosts

      - name: Deploy via rsync
        run: |
          rsync -azv --delete \
            --exclude='.git' \
            --exclude='node_modules' \
            -e "ssh -i ~/.ssh/deploy_key -p ${{ secrets.SSH_PORT }}" \
            deploy-payload/ \
            ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }}:${{ secrets.DEPLOY_PATH }}/

      - name: Post-deploy verification
        run: |
          ssh -i ~/.ssh/deploy_key -p ${{ secrets.SSH_PORT }} \
            ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }} \
            "test -f ${{ secrets.DEPLOY_PATH }}/includes/construkted/assets/js/construkted.js && echo 'construkted.js: OK' || echo 'construkted.js: MISSING'"
```

### Workflow 3: `deploy-api.yml` — API Deployment

```yaml
name: Deploy API

on:
  push:
    branches: [main]
    paths:
      - 'packages/api/**'
      - 'packages/shared/**'

  workflow_dispatch:
    inputs:
      environment:
        description: 'Target API server'
        required: true
        type: choice
        options:
          - api-dev-tile04
          - api-dev-tile05
          - api-prod

concurrency:
  group: deploy-api-${{ github.event.inputs.environment || 'api-dev-tile04' }}
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v4
        with:
          node-version-file: '.nvmrc'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build shared types
        run: pnpm --filter @construkted/shared build

      - name: Build API
        run: pnpm --filter @construkted/api build

      - name: Prepare API deployment package
        run: |
          mkdir -p api-deploy

          # Copy compiled output
          cp -r packages/api/dist api-deploy/dist

          # Copy package.json and lockfile for production install
          cp packages/api/package.json api-deploy/
          cp pnpm-lock.yaml api-deploy/

          # Copy shared types dist (API depends on it at runtime)
          mkdir -p api-deploy/node_modules/@construkted/shared
          cp -r packages/shared/dist api-deploy/node_modules/@construkted/shared/dist
          cp packages/shared/package.json api-deploy/node_modules/@construkted/shared/

          # Copy env template
          cp packages/api/env.example api-deploy/env.example

      - name: Upload API artifact
        uses: actions/upload-artifact@v4
        with:
          name: api-deploy-${{ github.sha }}
          path: api-deploy
          retention-days: 7

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'api-dev-tile04' }}
    steps:
      - name: Download API artifact
        uses: actions/download-artifact@v4
        with:
          name: api-deploy-${{ github.sha }}
          path: api-payload

      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          echo "${{ secrets.ACTIONS_SSH_KNOWN_HOSTS }}" >> ~/.ssh/known_hosts

      - name: Deploy API via rsync
        run: |
          rsync -azv \
            --exclude='.env' \
            --exclude='node_modules' \
            --exclude='tmp' \
            --exclude='data' \
            -e "ssh -i ~/.ssh/deploy_key -p ${{ secrets.SSH_PORT }}" \
            api-payload/ \
            ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }}:${{ secrets.DEPLOY_PATH }}/

      - name: Install production dependencies on server
        run: |
          ssh -i ~/.ssh/deploy_key -p ${{ secrets.SSH_PORT }} \
            ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }} \
            "cd ${{ secrets.DEPLOY_PATH }} && npm install --omit=dev --ignore-scripts"

      - name: Restart API service
        run: |
          ssh -i ~/.ssh/deploy_key -p ${{ secrets.SSH_PORT }} \
            ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }} \
            "sudo systemctl restart ${{ secrets.SERVICE_NAME }}"

      - name: Health check
        run: |
          sleep 5
          ssh -i ~/.ssh/deploy_key -p ${{ secrets.SSH_PORT }} \
            ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }} \
            "systemctl is-active ${{ secrets.SERVICE_NAME }} && echo 'Service: RUNNING' || (echo 'Service: FAILED' && exit 1)"
```

### Workflow 4: `release.yml` — Production Release

Coordinates production deployments for both theme and API. Requires explicit manual trigger and environment approval gates.

```yaml
name: Production Release

on:
  workflow_dispatch:
    inputs:
      deploy_theme:
        description: 'Deploy theme to production'
        required: true
        type: boolean
        default: true
      deploy_api:
        description: 'Deploy API to production (tile03)'
        required: true
        type: boolean
        default: false
      sourcemaps:
        description: 'Include source maps in production'
        required: false
        type: boolean
        default: false

run-name: "Production Release - Theme:${{ inputs.deploy_theme }} API:${{ inputs.deploy_api }}"

concurrency:
  group: production-release
  cancel-in-progress: false

jobs:
  preflight:
    runs-on: ubuntu-latest
    steps:
      - name: Verify branch
        if: github.ref != 'refs/heads/main'
        run: |
          echo "Production releases must be triggered from main branch."
          echo "Current ref: ${{ github.ref }}"
          exit 1

  deploy-theme-production:
    needs: preflight
    if: inputs.deploy_theme
    uses: ./.github/workflows/deploy-theme.yml
    with:
      environment: production
      include_sourcemaps: ${{ inputs.sourcemaps }}
    secrets: inherit

  deploy-api-production:
    needs: preflight
    if: inputs.deploy_api
    uses: ./.github/workflows/deploy-api.yml
    with:
      environment: api-prod
    secrets: inherit
```

> **Note:** For the reusable workflow pattern above, `deploy-theme.yml` and `deploy-api.yml` need an additional `on: workflow_call:` trigger with corresponding inputs. The self-contained versions above show the full logic for clarity.

### How Developers Deploy to Dev Environments

1. Developer pushes their feature branch to GitHub
2. Navigates to **Actions** tab → **Deploy Theme** (or **Deploy API**) → **Run workflow**
3. Selects their branch from the branch dropdown
4. Chooses target environment (`dev1` or `dev2`)
5. Clicks **Run workflow**

No branch naming convention needed. No special permissions for dev environments.

### How Code Reaches Production

1. Developer opens PR from feature branch → `main`
2. CI runs (lint, typecheck, build verification)
3. Reviewer approves, PR is merged to `main`
4. Push to `main` auto-deploys to staging
5. QA validates on staging
6. Someone navigates to **Actions** → **Production Release** → **Run workflow**
7. GitHub pauses the workflow and requests approval from required reviewers (environment protection)
8. Reviewer approves the deployment
9. Production deploy runs

### Cross-Cutting Changes (Theme + API)

1. **Single PR** — all changes are in one PR touching `packages/shared/`, `packages/api/`, `packages/js/`, and possibly `theme/`
2. **CI validates everything together** — typecheck catches contract mismatches at build time
3. **Staging deploy covers the theme side automatically** (push to main)
4. **API deploy is separate** — manually trigger API deploy to tile04 for integration testing
5. **Production release** — use the release workflow to deploy both `deploy_theme: true` and `deploy_api: true`

---

## 5. Selective Deployment

### Path-Based Change Detection

The `dorny/paths-filter` action (used in CI) and GitHub's native `paths:` trigger filter (used in deploy workflows) handle this.

**How it works for CI:**
- `packages/shared/**` changes → rebuild and check ALL downstream packages
- `packages/js/**` changes → only rebuild/check viewer
- `packages/uploadjs/**` changes → only rebuild/check upload
- `packages/api/**` changes → only rebuild/check API
- `theme/**` changes → only run PHP lint

**How it works for deployment:**
- Theme deploy fires on changes to `theme/**`, `packages/js/**`, `packages/uploadjs/**`, or `packages/shared/**`
- API deploy fires on changes to `packages/api/**` or `packages/shared/**`
- A change to `docs/` fires nothing

**Important:** Deploy workflows always build ALL JS packages even if only one changed, because rsync `--delete` synchronizes the full directory. Building both ensures the deployment artifact is always complete. Vite builds are sub-second for these packages.

### Manual Dispatch Overrides Selective Logic

When a developer manually triggers a deploy, it always builds and deploys regardless of what files changed.

---

## 6. Shared Types Package

### Package: `@construkted/shared`

**`packages/shared/package.json`:**
```json
{
  "name": "@construkted/shared",
  "version": "1.0.0",
  "private": true,
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "default": "./dist/index.js"
    }
  },
  "scripts": {
    "build": "tsc",
    "build:php": "tsx scripts/generate-php.ts",
    "typecheck": "tsc --noEmit",
    "lint": "eslint src/",
    "clean": "rm -rf dist"
  },
  "devDependencies": {
    "typescript": "^5.4.5",
    "tsx": "^4.0.0"
  }
}
```

### Source Files

**`packages/shared/src/asset-model-types.ts`:**
```typescript
export const AssetModelTypes = {
    Unknown: "Unknown",
    PolygonMesh: "PolygonMesh",
    PointCloud: "PointCloud",
    ThreeDTiles: "3DTile",
    CAD: "3DCADModel",
    Orthomosaic: "Orthomosaic",
} as const;

export type AssetModelType = (typeof AssetModelTypes)[keyof typeof AssetModelTypes];
```

**`packages/shared/src/status-codes.ts`:**
```typescript
export enum StatusCodes {
    QUEUED = 10,
    RUNNING = 20,
    PAUSED = 21,
    CPU_INTENSIVE_RUNNING_QUEUED = 30,
    FAILED = 40,
    COMPLETED = 50,
    CANCELED = 60,
}
```

**`packages/shared/src/running-status-codes.ts`:**
```typescript
export enum RunningStatusCodes {
    NONE = 0,
    PROCESSING_DRONE_IMAGE = 10,
    DOWNLOADING_ZIP = 20,
    TILING = 30,
    UPLOADING_TILES = 40,
}
```

**`packages/shared/src/error-codes.ts`:**
```typescript
export const ErrorCodes = {
    DOWNLOAD_FAILED: 100,
    DOWNLOAD_TERMINATED: 101,
    EXTRACTION_PATH_NOT_FOUND: 200,
    EXTRACTION_FAILED: 201,
    EXTRACTION_TERMINATED: 202,
    NO_MESH_FILES: 300,
    ULTRAMESH_SPAWN_FAILED: 301,
    ULTRAMESH_RUNTIME_ERROR: 302,
    ULTRAMESH_TERMINATED: 303,
    ULTRAMESH_NO_TILESET: 304,
    OBJ_RENAMED: 305,
    MESH_NOT_LOCAL_COORDS: 306,
    OBJ_MISSING_TEXTURES: 307,
    MESH_NOT_TEXTURED: 308,
    NO_JSON_IN_3DTILES: 400,
    MULTIPLE_JSON_IN_3DTILES: 401,
    PC_RECORD_COUNT_FAILED: 500,
    PC_TILER_SPAWN_FAILED: 501,
    PC_TILER_RUNTIME_ERROR: 502,
    PC_TILER_TERMINATED: 503,
    PC_TILER_NO_TILESET: 504,
    PC_INVALID_FORMAT: 505,
    NO_TIFF_FILES: 600,
    IMAGE_TILER_SPAWN_FAILED: 601,
    IMAGE_TILER_RUNTIME_ERROR: 602,
    IMAGE_TILER_TERMINATED: 603,
    WEBP_COMPRESSION_FAILED: 604,
    UPLOAD_US_EAST_FAILED: 700,
    UPLOAD_US_EAST_TERMINATED: 701,
    UPLOAD_EU_CENTRAL_FAILED: 702,
    UPLOAD_EU_CENTRAL_TERMINATED: 703,
    INPUT_UPLOAD_FAILED: 800,
    INPUT_UPLOAD_TERMINATED: 801,
    INPUT_FILE_REMOVAL_FAILED: 802,
    CESIUM_ION_INVALID_DATA: 900,
    CESIUM_ION_TILING_ERROR: 901,
    CESIUM_ION_ARCHIVE_ERROR: 902,
} as const;

export type ErrorCode = (typeof ErrorCodes)[keyof typeof ErrorCodes];
```

**`packages/shared/src/index.ts`:**
```typescript
export { AssetModelTypes, type AssetModelType } from './asset-model-types';
export { StatusCodes } from './status-codes';
export { RunningStatusCodes } from './running-status-codes';
export { ErrorCodes, type ErrorCode } from './error-codes';
```

### How Packages Consume Shared Types

In `packages/api/package.json` and `packages/js/package.json`:
```json
{
  "dependencies": {
    "@construkted/shared": "workspace:*"
  }
}
```

pnpm resolves `workspace:*` to the local package. In the API code:
```typescript
import { AssetModelTypes, StatusCodes, ErrorCodes } from '@construkted/shared';
```

### How the PHP Theme Consumes Shared Types

A **generated PHP constants file** is produced by `packages/shared/scripts/generate-php.ts`. It generates `constants-shared.php` which IS committed to git (the PHP server has no Node.js to generate it). The theme includes it:

```php
require_once get_stylesheet_directory() . '/includes/constants-shared.php';
```

CI verifies the generated file is up-to-date by running `build:php` and checking for git diff.

---

## 7. Local Development Workflow

### Initial Setup

```bash
# Clone the monorepo
git clone git@github.com:Construkted-Reality/construkted.git
cd construkted

# Install pnpm (if not already)
corepack enable

# Install all dependencies
pnpm install

# Build shared types (required before other packages)
pnpm build:shared
```

### Developing the Viewer Library

```bash
# Set the local dev dir in packages/js/.env
echo 'LOCAL_DEV_DIR=/path/to/local/wp/wp-content/themes/gowatch-child/includes/construkted/assets/js' > packages/js/.env

# Start the Vite watcher — builds on save and copies to local WP
pnpm dev:js
```

### Developing the Upload Library

```bash
echo 'LOCAL_DEV_DIR=/path/to/local/wp/wp-content/themes/gowatch-child/includes/frontend-submission/assets/js' > packages/uploadjs/.env

pnpm dev:upload
```

### Developing the API

```bash
pnpm dev:api
```

### Developing the Theme (PHP)

The theme is pure PHP — no build step. Developers work in `theme/wp-content/themes/gowatch-child/` directly. For local WP:

```bash
# Symlink the theme into your local WP installation
ln -s /path/to/construkted/theme/wp-content/themes/gowatch-child /path/to/local-wp/wp-content/themes/gowatch-child
```

### Working on Shared Types

```bash
# Terminal 1: Watch shared types
cd packages/shared && pnpm tsc --watch

# Terminal 2: Watch viewer (picks up shared type changes)
pnpm dev:js
```

### Pre-Commit Hooks (via Husky + lint-staged)

```bash
# .husky/pre-commit
pnpm lint-staged
```

`lint-staged` config in root `package.json`:
```json
{
  "lint-staged": {
    "packages/**/*.{ts,js}": ["eslint --fix"],
    "theme/**/*.php": ["php -l"]
  }
}
```

---

## 8. Security Considerations

### Secrets Management

**Principle of least privilege:**
- Each environment has its own SSH keypair. The `dev1` deploy key can only access the dev1 server.
- Environment secrets are scoped — a workflow in `dev1` cannot access `production` secrets.
- API server `.env` files are NEVER in git or GitHub Secrets. They're on the server only, excluded from rsync.

**SSH key management:**
- Use Ed25519 keys (not RSA) — shorter, faster, more secure
- Generate one keypair per environment
- Restrict keys on the server side with `rrsync`:
  ```
  command="/usr/bin/rrsync /home/gw4/public_html/wp-content/themes/gowatch-child",restrict ssh-ed25519 AAAA... github-deploy-staging
  ```

**Repository settings:**
- Private repository
- Branch protection on `main`
- Environment protection on `production` and `api-prod`

### CODEOWNERS

```
# .github/CODEOWNERS
.github/                    @Construkted-Reality/leads
packages/shared/            @Construkted-Reality/leads
packages/js/                @viewer-team
packages/uploadjs/          @viewer-team
packages/api/               @api-team
theme/                      @Construkted-Reality/leads
```

---

## 9. Risks and Trade-offs

### Risks

**1. Migration disruption**
Consolidating 4 repos is a one-time disruptive event. Plan for a half-day of team downtime.

**Mitigation:** Do migration on a low-activity day. Keep old repos archived for 90 days. Write a migration guide.

**2. rsync `--delete` risk**
Removes files on target that don't exist in source. Wrong artifact = deleted server files.

**Mitigation:** Build step verifies artifact contents. Use `--dry-run` for testing. Consider `--backup` flag.

**3. No test safety net**
Zero tests. CI catches syntax and type errors but not logic bugs.

**Mitigation:** Staging is the canary — auto-deploys from main. Production requires manual trigger + approval.

**4. No rollback mechanism**
rsync deploys don't have built-in rollback.

**Mitigation:** GitHub retains build artifacts for 7 days. A rollback workflow could re-deploy a previous artifact.

**5. CesiumJS vendored in theme (5MB+)**
Large static asset in every deploy.

**Mitigation:** rsync delta transfer handles this after first sync. Long-term, consider CDN.

### Trade-offs Accepted

| Decision | What you gain | What you give up |
|---|---|---|
| pnpm over npm | Strict deps, fast installs, native workspaces | Developers must have pnpm (mitigated by `corepack`) |
| Trunk-based over Gitflow | Simpler branch model, no release branch ceremony | No long-lived develop branch |
| rsync over git-pull-on-server | Proper artifact deployment, no git/Node on WP server | Slightly more complex workflow YAML |
| Manual dispatch for dev deploys | Any branch → any server flexibility | One more click vs. automatic branch-name deploy |
| Source maps excluded from production by default | Smaller footprint, no source exposure | Harder to debug production (toggle available) |
| Single monorepo | Atomic changes, shared CI, single PRs | Larger clone, wider blast radius of broken main |

### What This Strategy Does NOT Cover

- **Docker/containerization** — servers run bare-metal systemd/cPanel. No ROI at current scale.
- **Blue-green or canary deployments** — requires load balancer infrastructure that doesn't exist.
- **Automated testing** — zero tests. CI has a place for them, but writing tests is separate work.
- **CDN/asset cache invalidation** — assets served directly by WordPress/cPanel.
- **Database migrations** — WordPress handles schema via `dbDelta()`. API has no database.

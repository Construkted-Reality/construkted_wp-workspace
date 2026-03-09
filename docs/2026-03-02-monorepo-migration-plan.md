---
title: "feat: Monorepo migration plan — 4 repos to construkted-wp"
type: feat
status: draft
date: 2026-03-02
---

# Monorepo Migration Plan: 4 Repos → `construkted-wp`

## Table of Contents

- [Phase 0: Pre-Migration Fixes (in existing repos)](#phase-0-pre-migration-fixes)
- [Phase 1: Create Monorepo Scaffold](#phase-1-create-monorepo-scaffold)
- [Phase 2: Migrate Packages](#phase-2-migrate-packages)
- [Phase 3: Wire @construkted/shared](#phase-3-wire-construktedshared)
- [Phase 4: GitHub Setup](#phase-4-github-setup)
- [Phase 5: CI/CD Workflows](#phase-5-cicd-workflows)
- [Phase 6: Cutover Procedure](#phase-6-cutover-procedure)
- [Phase 7: Migrating In-Flight Feature Branches](#phase-7-migrating-in-flight-feature-branches)

---

## Overview

### Source repos

| Repo | Language | Toolchain | Primary branch |
|---|---|---|---|
| `construkted_api` | TypeScript 5.4.x | tsc, CommonJS | `master` |
| `construkted.js` | TypeScript 4.7.4 | Vite | `develop` |
| `construkted.uploadjs` | TypeScript 4.7.4 | Vite | `main` |
| `construkted_reality_v1.x` | PHP (no build step) | — | `develop` |

### Target monorepo

`construkted-wp` under `Construkted-Reality` GitHub org (private)

### Key decisions

- **Clean start** — no git history preservation. Old repos archived for reference.
- **Migrate primary branches first** — in-flight feature branches ported manually after (see Phase 7).
- **Vite only** for construkted.js — Gulp, Rollup, and javascript-obfuscator dropped entirely.
- **Defer TypeScript upgrade** — construkted.js and uploadjs stay on TS 4.7.4. A compat `tsconfig.base.json` handles the split.
- **pnpm 9.15.0** workspace, Node 22 LTS.
- **pnpm on tile servers** for API production dependency installs.
- **Trunk-based development** — single `main` branch, short-lived feature branches, PRs required.

### Final monorepo layout

```
construkted-wp/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml
│   │   ├── deploy-theme.yml
│   │   ├── deploy-api.yml
│   │   └── release.yml
│   └── CODEOWNERS
├── packages/
│   ├── shared/          # NEW — @construkted/shared (TS 5.4.5, CommonJS)
│   ├── api/             # @construkted/api  (from construkted_api master)
│   ├── js/              # @construkted/viewer (from construkted.js develop)
│   └── uploadjs/        # @construkted/upload (from construkted.uploadjs main)
├── theme/               # NOT a workspace package — pure PHP
│   └── wp-content/
│       └── themes/
│           ├── gowatch-child/
│           └── gowatch/
├── docs/
├── pnpm-workspace.yaml
├── package.json
├── tsconfig.base.json
├── .nvmrc
├── .gitignore
└── README.md
```

---

## Phase 0: Pre-Migration Fixes

**Do this before creating the monorepo.** These are small PRs in the existing repos that prevent broken state from being migrated in.

### 0.1 — Fix `construkted.js` (open PR against `develop`)

**Problem:** `build` script calls `gulp build`, which doesn't exist without the gulp toolchain. Vite configs mix CJS `require()` with ESM `import`. Dead devDependencies have been accumulating.

**Changes:**

**`package.json`** — update `build` script, remove dead devDependencies:

```json
{
  "name": "construkted_js",
  "version": "4.12.8",
  "main": "src/index.ts",
  "scripts": {
    "dev": "vite build --watch",
    "build": "vite build",
    "lint": "eslint \"src/**/*.{ts,js}\" --fix --max-warnings=0 && tsc --extendedDiagnostics",
    "lint-fix": "eslint ./src/*.{ts,js} --fix --debug",
    "postinstall": "husky install"
  },
  "dependencies": {
    "@jdultra/threedtiles": "9.1.12",
    "@turf/boolean-point-in-polygon": "^6.5.0",
    "@turf/turf": "^6.5.0",
    "@types/proj4": "^2.5.6",
    "cesium": "1.132",
    "jquery": "^3.6.3",
    "keycode-js": "^3.1.0",
    "markdown-it": "^12.1.0",
    "markdown-it-sanitizer": "^0.4.3",
    "point-in-polygon": "^1.1.0",
    "proj4": "^2.15.0",
    "three": "0.152.0",
    "tslib": "^2.4.1"
  },
  "devDependencies": {
    "@types/jquery": "^3.5.16",
    "@types/three": "^0.152.1",
    "@typescript-eslint/eslint-plugin": "^5.35.1",
    "@typescript-eslint/parser": "^5.35.1",
    "dotenv": "^17.2.4",
    "eslint": "8.2.0",
    "eslint-config-airbnb-base": "15.0.0",
    "eslint-config-prettier": "^8.3.0",
    "eslint-plugin-import": "2.25.2",
    "eslint-plugin-jsx-a11y": "6.5.1",
    "eslint-plugin-prettier": "^3.4.0",
    "husky": "^8.0.2",
    "prettier": "^2.3.2",
    "typescript": "^4.7.4",
    "vite": "^5.4.10",
    "vite-plugin-lib-inject-css": "^2.1.1"
  }
}
```

**Removed devDependencies** (dead — drop every one):
- `@rbnlffl/rollup-plugin-eslint`
- `@rollup/plugin-commonjs`, `@rollup/plugin-json`, `@rollup/plugin-node-resolve`, `@rollup/plugin-typescript`
- `browser-sync`
- `gulp`, `gulp-concat`, `gulp-connect`, `gulp-open`
- `javascript-obfuscator`
- `rollup`, `rollup-plugin-html`, `rollup-plugin-less`, `rollup-plugin-terser`

**`vite.config.js`** — fix mixed CJS/ESM:

```javascript
import { resolve } from 'path'
import { copyFileSync, existsSync } from 'fs'
import { defineConfig, loadEnv } from 'vite'
import { libInjectCss } from 'vite-plugin-lib-inject-css'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const localDevDir = env.LOCAL_DEV_DIR

  return {
    build: {
      lib: {
        entry: resolve(__dirname, 'src/index.ts'),
        name: 'ConstruktedJs',
        fileName: () => 'construkted.js',
        formats: ['umd'],
      },
      rollupOptions: {
        external: ['cesium'],
        output: {
          globals: {
            cesium: 'Cesium',
          },
        },
      },
      sourcemap: true,
    },
    plugins: [
      libInjectCss(),
      {
        name: 'copy-to-local-dev',
        closeBundle() {
          if (!localDevDir) {
            console.info('LOCAL_DEV_DIR not set in .env, skipping copy')
            return
          }
          if (!existsSync(localDevDir)) {
            console.info(`LOCAL_DEV_DIR does not exist: ${localDevDir}`)
            return
          }
          copyFileSync('./dist/construkted.js', `${localDevDir}/construkted.js`)
          copyFileSync('./dist/construkted.js.map', `${localDevDir}/construkted.js.map`)
          console.info(`Copied to ${localDevDir}`)
        },
      },
    ],
  }
})
```

**Files to delete:**
- `gulpfile.js`
- `rollup.config.js`
- `rollup.config.release.js`
- `rollup.build.css`

**Verify:**
```bash
yarn build
# Must produce dist/construkted.js and dist/construkted.js.map without errors
ls dist/construkted.js dist/construkted.js.map
```

**Commit message:** `chore: drop gulp/rollup, switch build to vite, fix ESM imports`

---

### 0.2 — Fix `construkted.uploadjs` (open PR against `main`)

**Problem:** No `build` script (only `dev`). vite.config.js uses hardcoded Windows paths and CJS `require()`.

**`package.json`** — add build script, remove dead devDependencies:

```json
{
  "name": "construkted.upload.js",
  "version": "1.1.2",
  "main": "src/index.ts",
  "license": "MIT",
  "scripts": {
    "dev": "vite build --watch",
    "build": "vite build"
  },
  "dependencies": {
    "@types/jquery": "^3.5.32",
    "vite": "^5.4.10"
  },
  "devDependencies": {
    "@typescript-eslint/eslint-plugin": "^5.35.1",
    "@typescript-eslint/parser": "^5.35.1",
    "eslint": "8.2.0",
    "eslint-config-airbnb-base": "15.0.0",
    "eslint-config-prettier": "^8.3.0",
    "eslint-plugin-import": "2.25.2",
    "eslint-plugin-jsx-a11y": "6.5.1",
    "eslint-plugin-prettier": "^3.4.0",
    "husky": "^8.0.2",
    "prettier": "^2.3.2",
    "typescript": "^4.7.4",
    "vite-plugin-lib-inject-css": "^2.1.1"
  }
}
```

**Removed devDependencies** (dead — drop every one):
- `@rbnlffl/rollup-plugin-eslint`
- `@rollup/plugin-commonjs`, `@rollup/plugin-json`, `@rollup/plugin-node-resolve`, `@rollup/plugin-typescript`
- `browser-sync`
- `javascript-obfuscator`
- `rollup`, `rollup-plugin-html`, `rollup-plugin-less`, `rollup-plugin-terser`

**`vite.config.js`** — replace entirely with .env-based LOCAL_DEV_DIR pattern:

```javascript
import { resolve } from 'path'
import { copyFileSync, existsSync } from 'fs'
import { defineConfig, loadEnv } from 'vite'
import { libInjectCss } from 'vite-plugin-lib-inject-css'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const localDevDir = env.LOCAL_DEV_DIR

  return {
    build: {
      lib: {
        entry: resolve(__dirname, 'src/index.ts'),
        name: 'ConstruktedJs',
        fileName: () => 'construkted.upload.js',
        formats: ['umd'],
      },
      rollupOptions: {
        external: ['cesium', 'plupload'],
        output: {
          globals: {
            cesium: 'Cesium',
          },
        },
      },
      sourcemap: true,
    },
    plugins: [
      libInjectCss(),
      {
        name: 'copy-to-local-dev',
        closeBundle() {
          if (!localDevDir) {
            console.info('LOCAL_DEV_DIR not set in .env, skipping copy')
            return
          }
          if (!existsSync(localDevDir)) {
            console.info(`LOCAL_DEV_DIR does not exist: ${localDevDir}`)
            return
          }
          copyFileSync('./dist/construkted.upload.js', `${localDevDir}/construkted.upload.js`)
          copyFileSync('./dist/construkted.upload.js.map', `${localDevDir}/construkted.upload.js.map`)
          console.info(`Copied to ${localDevDir}`)
        },
      },
    ],
  }
})
```

**Add `.env.example`:**
```
# Path to the JS assets directory in your local WordPress install.
# The built construkted.upload.js will be copied here after each build.
# LOCAL_DEV_DIR=/path/to/wp-content/themes/gowatch-child/includes/frontend-submission/assets/js
```

**Verify:**
```bash
yarn build
# Must produce dist/construkted.upload.js and dist/construkted.upload.js.map without errors
ls dist/construkted.upload.js dist/construkted.upload.js.map
```

**Commit message:** `chore: add build script, switch to env-based LOCAL_DEV_DIR, fix ESM imports`

---

### Phase 0 verification checklist

- [ ] `construkted.js` PR merged to `develop`
- [ ] `construkted.uploadjs` PR merged to `main`
- [ ] Both `yarn build` commands produce correct dist artifacts
- [ ] No gulp/rollup references remain in either repo

---

## Phase 1: Create Monorepo Scaffold

### 1.1 — Create the GitHub repository

1. Go to `https://github.com/organizations/Construkted-Reality/repositories/new`
2. Repository name: `construkted-wp`
3. Visibility: **Private**
4. **Do NOT** initialize with README, .gitignore, or license — start completely empty
5. Click **Create repository**

### 1.2 — Clone and initialize locally

```bash
git clone git@github.com:Construkted-Reality/construkted-wp.git
cd construkted-wp
```

### 1.3 — Create directory structure

```bash
mkdir -p .github/workflows
mkdir -p packages/shared/src
mkdir -p packages/shared/scripts
mkdir -p packages/api
mkdir -p packages/js
mkdir -p packages/uploadjs
mkdir -p theme/wp-content/themes
mkdir -p docs/architecture/decisions
```

### 1.4 — Create root config files

**`pnpm-workspace.yaml`:**
```yaml
packages:
  - 'packages/*'
```

Note: `theme/` is intentionally NOT listed — it's pure PHP with no `package.json`.

---

**`package.json`:**
```json
{
  "name": "construkted",
  "private": true,
  "scripts": {
    "build": "pnpm --filter './packages/**' run build",
    "build:shared": "pnpm --filter @construkted/shared build",
    "build:api": "pnpm --filter @construkted/api build",
    "build:js": "pnpm --filter @construkted/viewer build",
    "build:upload": "pnpm --filter @construkted/upload build",
    "build:frontend": "pnpm --filter @construkted/shared build && pnpm --filter @construkted/viewer --filter @construkted/upload build",
    "dev:js": "pnpm --filter @construkted/viewer dev",
    "dev:upload": "pnpm --filter @construkted/upload dev",
    "dev:api": "pnpm --filter @construkted/api dev",
    "typecheck": "pnpm -r run typecheck",
    "lint": "pnpm -r run lint",
    "clean": "pnpm -r run clean",
    "prepare": "husky"
  },
  "engines": {
    "node": ">=22.0.0",
    "pnpm": ">=9.0.0"
  },
  "packageManager": "pnpm@9.15.0",
  "devDependencies": {
    "husky": "^9.0.0",
    "lint-staged": "^15.0.0"
  },
  "lint-staged": {
    "packages/**/*.{ts,js}": ["eslint --fix"],
    "theme/**/*.php": ["php -l"]
  }
}
```

---

**`tsconfig.base.json`:**

> **Critical:** This must be TS 4.7.4-compatible. `moduleResolution: "bundler"` was introduced in TS 5.0 — do NOT include it. Do NOT include `target`, `module`, `moduleResolution`, `lib`, or `isolatedModules` here. Each package tsconfig sets those for its own TypeScript version and runtime context.

```json
{
  "compilerOptions": {
    "strict": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

---

**`.nvmrc`:**
```
22
```

---

**`.gitignore`:**
```gitignore
# Dependencies — all levels
node_modules/

# Package build outputs
packages/*/dist/

# Built JS artifacts — built in CI, never committed to repo
theme/wp-content/themes/gowatch-child/includes/construkted/assets/js/construkted.js
theme/wp-content/themes/gowatch-child/includes/construkted/assets/js/construkted.js.map
theme/wp-content/themes/gowatch-child/includes/frontend-submission/assets/js/construkted.upload.js
theme/wp-content/themes/gowatch-child/includes/frontend-submission/assets/js/construkted.upload.js.map

# TypeScript incremental build info
*.tsbuildinfo

# Environment files — never commit
.env
.env.local
.env.*.local

# OS junk
.DS_Store
Thumbs.db
desktop.ini

# Editor
.vscode/settings.json
.idea/

# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*

# Temporary files
tmp/
temp/
```

---

**`README.md`:**
```markdown
# construkted-wp

Monorepo for Construkted Reality — viewer library, upload library, tiling API, and WordPress theme.

## Packages

| Package | Path | Description |
|---|---|---|
| `@construkted/shared` | `packages/shared/` | Shared TypeScript types and PHP constants generator |
| `@construkted/api` | `packages/api/` | Node.js tiling API server (Express, CommonJS) |
| `@construkted/viewer` | `packages/js/` | 3D viewer JavaScript library (Vite UMD build) |
| `@construkted/upload` | `packages/uploadjs/` | Upload form JavaScript library (Vite UMD build) |

The WordPress theme lives in `theme/` and is **not** a workspace package (pure PHP, no build step of its own).

## Requirements

- Node 22 LTS (`nvm use` will pick up `.nvmrc`)
- pnpm 9.15.0 (`corepack enable && corepack prepare pnpm@9.15.0 --activate`)

## Getting started

```bash
pnpm install
pnpm build:shared   # build shared types first — other packages depend on this
pnpm build          # build all packages
```

## Local development

See `docs/deployment.md` for server setup. For local JS development:

```bash
# Copy packages/js/.env.example → packages/js/.env and set LOCAL_DEV_DIR
pnpm dev:js

# Copy packages/uploadjs/.env.example → packages/uploadjs/.env and set LOCAL_DEV_DIR  
pnpm dev:upload

pnpm dev:api
```
```

---

**`.github/CODEOWNERS`:**
```
# .github/CODEOWNERS
.github/                    @Construkted-Reality/leads
packages/shared/            @Construkted-Reality/leads
packages/js/                @Construkted-Reality/leads
packages/uploadjs/          @Construkted-Reality/leads
packages/api/               @Construkted-Reality/leads
theme/                      @Construkted-Reality/leads
```

### 1.5 — First commit

```bash
git add .
git commit -m "chore: initialize monorepo scaffold"
git push -u origin main
```

### Phase 1 verification checklist

- [ ] Repo exists on GitHub under `Construkted-Reality` org, private
- [ ] Directory structure matches the layout above
- [ ] All 6 root config files committed
- [ ] `pnpm-workspace.yaml` lists only `packages/*` (not `theme/`)
- [ ] `tsconfig.base.json` contains NO `target`, `module`, `moduleResolution`, `lib`, or `isolatedModules`
- [ ] `.gitignore` covers node_modules at all depths, dist/, built JS artifacts in theme/, .env files

---

## Phase 2: Migrate Packages

Migrate in this order: **shared → api → js → uploadjs → theme**

The order matters: shared has no internal dependencies; api depends on shared; js and uploadjs depend on shared.

---

### 2.1 — `packages/shared` (NEW package)

This package does not exist yet. Create it from scratch.

**Directory structure:**
```
packages/shared/
├── src/
│   ├── index.ts
│   ├── asset-model-types.ts
│   ├── status-codes.ts
│   ├── running-status-codes.ts
│   └── error-codes.ts
├── scripts/
│   └── generate-php.ts
├── package.json
└── tsconfig.json
```

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
    "tsx": "^4.0.0",
    "typescript": "^5.4.5"
  }
}
```

**`packages/shared/tsconfig.json`:**
```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "target": "ES2020",
    "module": "CommonJS",
    "moduleResolution": "node",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist", "scripts"]
}
```

**`packages/shared/src/status-codes.ts`:**

> Copied verbatim from `construkted_api/lib/statusCodes.ts`

```typescript
export enum StatusCodes {
    QUEUED = 10,
    RUNNING = 20,
    // task started by UltraMesh is paused because system memory is not sufficient.
    PAUSED = 21,
    // task is paused and waiting for CPU-intensive slot
    CPU_INTENSIVE_RUNNING_QUEUED = 30,
    FAILED = 40,
    COMPLETED = 50,
    CANCELED = 60,
}
```

**`packages/shared/src/running-status-codes.ts`:**

> Copied verbatim from `construkted_api/lib/runningStatusCodes.ts`

```typescript
export enum RunningStatusCodes {
    NONE = 0,
    PROCESSING_DRONE_IMAGE = 10,
    // api starts downloading an input zip file from wasabi
    DOWNLOADING_ZIP = 20,
    // starts tiling by UltraMesh
    TILING = 30,
    // starts uploading tiles to wasabi
    UPLOADING_TILES = 40,
}
```

**`packages/shared/src/asset-model-types.ts`:**
```typescript
export const AssetModelTypes = {
    Unknown: 'Unknown',
    PolygonMesh: 'PolygonMesh',
    PointCloud: 'PointCloud',
    ThreeDTiles: '3DTile',
    CAD: '3DCADModel',
    Orthomosaic: 'Orthomosaic',
} as const;

export type AssetModelType = (typeof AssetModelTypes)[keyof typeof AssetModelTypes];
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

**`packages/shared/scripts/generate-php.ts`:**

This script reads the TypeScript source files and writes a PHP constants file into the theme. The output path is relative to the monorepo root.

```typescript
import { writeFileSync, mkdirSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

// ---------------------------------------------------------------------------
// Import the compiled shared types.
// Run `pnpm build` before `pnpm build:php`, or run via tsx (no compile needed).
// ---------------------------------------------------------------------------
import { StatusCodes, RunningStatusCodes, AssetModelTypes, ErrorCodes } from '../src/index';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Output path — relative to monorepo root
const OUTPUT_PATH = resolve(
    __dirname,
    '../../../theme/wp-content/themes/gowatch-child/includes/construkted/constants-shared.php'
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function phpConstant(name: string, value: string | number): string {
    const phpValue = typeof value === 'number' ? String(value) : `'${value}'`;
    return `if (!defined('${name}')) {\n    define('${name}', ${phpValue});\n}`;
}

function phpSection(title: string): string {
    return `\n// ${'-'.repeat(75)}\n// ${title}\n// ${'-'.repeat(75)}\n`;
}

// ---------------------------------------------------------------------------
// Generate content
// ---------------------------------------------------------------------------

const lines: string[] = [
    '<?php',
    '/**',
    ' * Construkted Shared Constants — AUTO-GENERATED',
    ' *',
    ' * DO NOT EDIT THIS FILE MANUALLY.',
    ' * This file is generated by packages/shared/scripts/generate-php.ts',
    ' * Run: pnpm --filter @construkted/shared build:php',
    ' *',
    ' * @package Construkted',
    ' */',
    '',
    "if (!defined('ABSPATH')) {",
    '    exit;',
    '}',
];

// StatusCodes
lines.push(phpSection('StatusCodes (matches packages/shared/src/status-codes.ts)'));
for (const [key, value] of Object.entries(StatusCodes)) {
    if (isNaN(Number(key))) {
        // Enum has both key→value and value→key entries; skip the numeric keys
        lines.push(phpConstant(`STATUS_${key.toUpperCase()}`, value as number));
    }
}

// RunningStatusCodes
lines.push(phpSection('RunningStatusCodes (matches packages/shared/src/running-status-codes.ts)'));
for (const [key, value] of Object.entries(RunningStatusCodes)) {
    if (isNaN(Number(key))) {
        lines.push(phpConstant(`RUNNING_STATUS_${key.toUpperCase()}`, value as number));
    }
}

// AssetModelTypes
lines.push(phpSection('AssetModelTypes (matches packages/shared/src/asset-model-types.ts)'));
for (const [key, value] of Object.entries(AssetModelTypes)) {
    const constName = `ASSET_MODEL_TYPE_${key.toUpperCase().replace(/[^A-Z0-9]/g, '_')}`;
    lines.push(phpConstant(constName, value as string));
}

// ErrorCodes
lines.push(phpSection('ErrorCodes (matches packages/shared/src/error-codes.ts)'));
for (const [key, value] of Object.entries(ErrorCodes)) {
    lines.push(phpConstant(`ERROR_CODE_${key}`, value as number));
}

lines.push('');

// ---------------------------------------------------------------------------
// Write output
// ---------------------------------------------------------------------------

mkdirSync(dirname(OUTPUT_PATH), { recursive: true });
writeFileSync(OUTPUT_PATH, lines.join('\n'), 'utf-8');
console.log(`Generated: ${OUTPUT_PATH}`);
```

**Expected output format** (excerpt of `constants-shared.php`):
```php
<?php
/**
 * Construkted Shared Constants — AUTO-GENERATED
 *
 * DO NOT EDIT THIS FILE MANUALLY.
 * This file is generated by packages/shared/scripts/generate-php.ts
 * Run: pnpm --filter @construkted/shared build:php
 *
 * @package Construkted
 */

if (!defined('ABSPATH')) {
    exit;
}

// ---------------------------------------------------------------------------
// StatusCodes (matches packages/shared/src/status-codes.ts)
// ---------------------------------------------------------------------------
if (!defined('STATUS_QUEUED')) {
    define('STATUS_QUEUED', 10);
}
if (!defined('STATUS_RUNNING')) {
    define('STATUS_RUNNING', 20);
}
if (!defined('STATUS_PAUSED')) {
    define('STATUS_PAUSED', 21);
}
if (!defined('STATUS_CPU_INTENSIVE_RUNNING_QUEUED')) {
    define('STATUS_CPU_INTENSIVE_RUNNING_QUEUED', 30);
}
if (!defined('STATUS_FAILED')) {
    define('STATUS_FAILED', 40);
}
if (!defined('STATUS_COMPLETED')) {
    define('STATUS_COMPLETED', 50);
}
if (!defined('STATUS_CANCELED')) {
    define('STATUS_CANCELED', 60);
}

// ---------------------------------------------------------------------------
// RunningStatusCodes (matches packages/shared/src/running-status-codes.ts)
// ---------------------------------------------------------------------------
if (!defined('RUNNING_STATUS_NONE')) {
    define('RUNNING_STATUS_NONE', 0);
}
// ... etc.
```

**Commit:**
```bash
git add packages/shared/
git commit -m "feat(shared): add @construkted/shared package with types and PHP generator"
```

---

### 2.2 — `packages/api` (from `construkted_api` master)

**What to copy:**

From `construkted_api/` master branch, copy everything EXCEPT:
- `node_modules/` — regenerated by pnpm install
- `dist/` — regenerated by build
- `package-lock.json` — replaced by root pnpm-lock.yaml
- `.git/` — obviously
- `tmp/` — runtime data directory

Copy these (representative list — copy all non-excluded files):
```bash
# From the construkted_api repo root:
cp -r lib/ types/ doc/ docs/
cp app.ts bucketConfig.ts CHANGELOG.md compress-webp.sh config.ts env.example
cp eslint.config.mjs global.ts index.ts README.md
# tsconfig.json — see replacement below
# package.json — see replacement below
```

**`packages/api/package.json`:**
```json
{
  "name": "@construkted/api",
  "version": "2.0.11",
  "description": "Construkted Reality tiling API server",
  "main": "dist/index.js",
  "private": true,
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "nodemon --exec \"npm run build && node dist/index.js\" --ext ts",
    "dev:watch": "tsc --watch",
    "typecheck": "tsc --noEmit",
    "lint": "eslint **/*.{js,ts}",
    "lint:fix": "eslint --fix ./**/*.{js,ts}",
    "clean": "rimraf dist"
  },
  "dependencies": {
    "@aws-sdk/client-s3": "^3.914.0",
    "@aws-sdk/lib-storage": "^3.914.0",
    "@construkted/shared": "workspace:*",
    "async": "^2.6.1",
    "axios": "^1.6.8",
    "bluebird": "^3.5.3",
    "cesium": "^1.104.0",
    "dotenv": "^16.4.7",
    "express": "^4.17.1",
    "fs-extra": "^7.0.1",
    "gm": "^1.23.1",
    "is-image": "^3.0.0",
    "node-schedule": "^1.3.1",
    "node-unzip-2": "^0.2.7",
    "request": "^2.88.2",
    "request-promise": "^4.2.6",
    "uuid": "^11.1.0"
  },
  "devDependencies": {
    "@eslint/js": "^9.35.0",
    "@types/async": "^3.2.24",
    "@types/express": "^4.17.21",
    "@types/fs-extra": "^11.0.4",
    "@types/gm": "^1.25.4",
    "@types/node": "^20.14.0",
    "@types/node-schedule": "^2.1.7",
    "@types/request": "^2.48.12",
    "@types/request-promise": "^4.1.51",
    "@types/uuid": "^10.0.0",
    "@typescript-eslint/eslint-plugin": "^8.0.0",
    "@typescript-eslint/parser": "^8.0.0",
    "eslint": "^9.35.0",
    "eslint-config-love": "^133.0.0",
    "eslint-plugin-import": "^2.27.5",
    "eslint-plugin-n": "^15.6.1",
    "eslint-plugin-promise": "^6.1.1",
    "globals": "^16.4.0",
    "nodemon": "^3.1.9",
    "rimraf": "^5.0.7",
    "ts-node": "^10.9.2",
    "typescript": "^5.4.5"
  },
  "type": "commonjs"
}
```

**`packages/api/tsconfig.json`:**
```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "target": "ES2020",
    "module": "CommonJS",
    "moduleResolution": "node",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./",
    "removeComments": false,
    "baseUrl": "./",
    "paths": {
      "*": ["node_modules/*", "types/*"]
    },
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "typeRoots": ["./node_modules/@types", "./types"],
    "types": ["node"]
  },
  "include": [
    "**/*.ts",
    "**/*.js"
  ],
  "exclude": [
    "node_modules",
    "dist",
    "tmp",
    "test"
  ],
  "ts-node": {
    "esm": false,
    "experimentalSpecifierResolution": "node"
  }
}
```

**Note on `lib/statusCodes.ts` and `lib/runningStatusCodes.ts`:** For now, keep these files as re-exports pointing to `@construkted/shared`. This avoids breaking existing internal imports. Future cleanup task: update all internal API references to import directly from `@construkted/shared`.

Add to `lib/statusCodes.ts` (replace file content):
```typescript
// Re-exported from @construkted/shared for backwards compatibility.
// TODO: update all imports in this package to use @construkted/shared directly.
export { StatusCodes } from '@construkted/shared';
```

Add to `lib/runningStatusCodes.ts` (replace file content):
```typescript
// Re-exported from @construkted/shared for backwards compatibility.
// TODO: update all imports in this package to use @construkted/shared directly.
export { RunningStatusCodes } from '@construkted/shared';
```

**Commit:**
```bash
git add packages/api/
git commit -m "feat(api): migrate construkted_api to packages/api"
```

---

### 2.3 — `packages/js` (from `construkted.js` develop)

**What to copy:**

```bash
# From construkted.js develop branch:
cp -r src/                                    packages/js/src/
cp tsconfig.json                              packages/js/tsconfig.json   # replaced below
cp .eslintrc* .prettierrc* .env.example       packages/js/
# vite.config.js — replaced with the fixed version from Phase 0 (now .ts extension)
# package.json — replaced below
```

**Do NOT copy:**
- `dist/`, `build/` — regenerated
- `yarn.lock` — replaced by root pnpm-lock.yaml
- `gulpfile.js`, `rollup.config.js`, `rollup.config.release.js`, `rollup.build.css` — deleted in Phase 0
- The root-level `construkted.js` file (compiled artifact from old build process)
- `node_modules/`
- `.git/`

**`packages/js/package.json`:**
```json
{
  "name": "@construkted/viewer",
  "version": "4.12.8",
  "private": true,
  "main": "dist/construkted.js",
  "scripts": {
    "dev": "vite build --watch",
    "build": "vite build",
    "typecheck": "tsc --noEmit",
    "lint": "eslint \"src/**/*.{ts,js}\" --fix --max-warnings=0",
    "clean": "rm -rf dist"
  },
  "dependencies": {
    "@construkted/shared": "workspace:*",
    "@jdultra/threedtiles": "9.1.12",
    "@turf/boolean-point-in-polygon": "^6.5.0",
    "@turf/turf": "^6.5.0",
    "@types/proj4": "^2.5.6",
    "cesium": "1.132",
    "jquery": "^3.6.3",
    "keycode-js": "^3.1.0",
    "markdown-it": "^12.1.0",
    "markdown-it-sanitizer": "^0.4.3",
    "point-in-polygon": "^1.1.0",
    "proj4": "^2.15.0",
    "three": "0.152.0",
    "tslib": "^2.4.1"
  },
  "devDependencies": {
    "@types/jquery": "^3.5.16",
    "@types/three": "^0.152.1",
    "@typescript-eslint/eslint-plugin": "^5.35.1",
    "@typescript-eslint/parser": "^5.35.1",
    "dotenv": "^17.2.4",
    "eslint": "8.2.0",
    "eslint-config-airbnb-base": "15.0.0",
    "eslint-config-prettier": "^8.3.0",
    "eslint-plugin-import": "2.25.2",
    "eslint-plugin-jsx-a11y": "6.5.1",
    "eslint-plugin-prettier": "^3.4.0",
    "prettier": "^2.3.2",
    "typescript": "^4.7.4",
    "vite": "^5.4.10",
    "vite-plugin-lib-inject-css": "^2.1.1"
  }
}
```

**`packages/js/tsconfig.json`:**
```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "target": "ES6",
    "module": "ESNext",
    "moduleResolution": "node",
    "lib": ["dom", "dom.iterable", "esnext"],
    "downlevelIteration": true,
    "allowJs": true,
    "isolatedModules": true,
    "noEmit": false,
    "outDir": "dist",
    "rootDir": "./",
    "incremental": true
  },
  "include": ["./src", "./src/**/*.js", "./src/**/*.ts"],
  "typeRoots": ["./node_modules/@types/"]
}
```

**`packages/js/vite.config.ts`:**

> This is the cleaned-up version from Phase 0, renamed to `.ts` (TypeScript extension).

```typescript
import { resolve } from 'path'
import { copyFileSync, existsSync } from 'fs'
import { defineConfig, loadEnv } from 'vite'
import { libInjectCss } from 'vite-plugin-lib-inject-css'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const localDevDir = env.LOCAL_DEV_DIR

  return {
    build: {
      lib: {
        entry: resolve(__dirname, 'src/index.ts'),
        name: 'ConstruktedJs',
        fileName: () => 'construkted.js',
        formats: ['umd'],
      },
      rollupOptions: {
        external: ['cesium'],
        output: {
          globals: {
            cesium: 'Cesium',
          },
        },
      },
      sourcemap: true,
    },
    plugins: [
      libInjectCss(),
      {
        name: 'copy-to-local-dev',
        closeBundle() {
          if (!localDevDir) {
            console.info('LOCAL_DEV_DIR not set in .env, skipping copy')
            return
          }
          if (!existsSync(localDevDir)) {
            console.info(`LOCAL_DEV_DIR does not exist: ${localDevDir}`)
            return
          }
          copyFileSync('./dist/construkted.js', `${localDevDir}/construkted.js`)
          copyFileSync('./dist/construkted.js.map', `${localDevDir}/construkted.js.map`)
          console.info(`Copied to ${localDevDir}`)
        },
      },
    ],
  }
})
```

**`.env.example`** (if not already present in source):
```
# Path to the JS assets directory in your local WordPress install.
# LOCAL_DEV_DIR=/path/to/wp-content/themes/gowatch-child/includes/construkted/assets/js
```

**Commit:**
```bash
git add packages/js/
git commit -m "feat(viewer): migrate construkted.js to packages/js"
```

---

### 2.4 — `packages/uploadjs` (from `construkted.uploadjs` main)

**What to copy:**

```bash
# From construkted.uploadjs main branch:
cp -r src/    packages/uploadjs/src/
cp tsconfig.json                              packages/uploadjs/tsconfig.json  # replaced below
cp .eslintrc* .prettierrc*                   packages/uploadjs/  # if they exist
cp CHAGELOG.md                               packages/uploadjs/CHANGELOG.md
# vite.config.js — replaced with fixed version from Phase 0 (now .ts extension)
# package.json — replaced below
```

**Do NOT copy:**
- `yarn.lock` — replaced by root pnpm-lock.yaml
- `node_modules/`
- `.git/`

**`packages/uploadjs/package.json`:**
```json
{
  "name": "@construkted/upload",
  "version": "1.1.2",
  "private": true,
  "main": "dist/construkted.upload.js",
  "scripts": {
    "dev": "vite build --watch",
    "build": "vite build",
    "typecheck": "tsc --noEmit",
    "lint": "eslint \"src/**/*.{ts,js}\" --fix --max-warnings=0",
    "clean": "rm -rf dist"
  },
  "dependencies": {
    "@construkted/shared": "workspace:*",
    "@types/jquery": "^3.5.32"
  },
  "devDependencies": {
    "@typescript-eslint/eslint-plugin": "^5.35.1",
    "@typescript-eslint/parser": "^5.35.1",
    "eslint": "8.2.0",
    "eslint-config-airbnb-base": "15.0.0",
    "eslint-config-prettier": "^8.3.0",
    "eslint-plugin-import": "2.25.2",
    "eslint-plugin-jsx-a11y": "6.5.1",
    "eslint-plugin-prettier": "^3.4.0",
    "prettier": "^2.3.2",
    "typescript": "^4.7.4",
    "vite": "^5.4.10",
    "vite-plugin-lib-inject-css": "^2.1.1"
  }
}
```

**`packages/uploadjs/tsconfig.json`:**
```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "target": "ES6",
    "module": "ESNext",
    "moduleResolution": "node",
    "lib": ["dom", "dom.iterable", "esnext"],
    "downlevelIteration": true,
    "allowJs": true,
    "isolatedModules": true,
    "noEmit": false,
    "outDir": "dist",
    "rootDir": "./",
    "incremental": true
  },
  "include": ["./src", "./src/**/*.ts"],
  "typeRoots": ["./node_modules/@types/"]
}
```

**`packages/uploadjs/vite.config.ts`:**

> This is the rewritten version from Phase 0, now with `.ts` extension.

```typescript
import { resolve } from 'path'
import { copyFileSync, existsSync } from 'fs'
import { defineConfig, loadEnv } from 'vite'
import { libInjectCss } from 'vite-plugin-lib-inject-css'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const localDevDir = env.LOCAL_DEV_DIR

  return {
    build: {
      lib: {
        entry: resolve(__dirname, 'src/index.ts'),
        name: 'ConstruktedJs',
        fileName: () => 'construkted.upload.js',
        formats: ['umd'],
      },
      rollupOptions: {
        external: ['cesium', 'plupload'],
        output: {
          globals: {
            cesium: 'Cesium',
          },
        },
      },
      sourcemap: true,
    },
    plugins: [
      libInjectCss(),
      {
        name: 'copy-to-local-dev',
        closeBundle() {
          if (!localDevDir) {
            console.info('LOCAL_DEV_DIR not set in .env, skipping copy')
            return
          }
          if (!existsSync(localDevDir)) {
            console.info(`LOCAL_DEV_DIR does not exist: ${localDevDir}`)
            return
          }
          copyFileSync('./dist/construkted.upload.js', `${localDevDir}/construkted.upload.js`)
          copyFileSync('./dist/construkted.upload.js.map', `${localDevDir}/construkted.upload.js.map`)
          console.info(`Copied to ${localDevDir}`)
        },
      },
    ],
  }
})
```

**`.env.example`:**
```
# Path to the JS assets directory in your local WordPress install.
# LOCAL_DEV_DIR=/path/to/wp-content/themes/gowatch-child/includes/frontend-submission/assets/js
```

**Commit:**
```bash
git add packages/uploadjs/
git commit -m "feat(upload): migrate construkted.uploadjs to packages/uploadjs"
```

---

### 2.5 — `theme/` (from `construkted_reality_v1.x` develop)

**What to copy:**

```bash
# From construkted_reality_v1.x develop branch:
cp -r wp-content/themes/gowatch-child/    theme/wp-content/themes/gowatch-child/
cp -r wp-content/themes/gowatch/          theme/wp-content/themes/gowatch/
```

**Do NOT copy:**
- `.github/` — the monorepo has its own
- `.git/`
- `CHANGELOG.md` at repo root — move to `docs/theme-changelog.md` if you want to keep it
- The built JS artifacts in `gowatch-child/includes/construkted/assets/js/` and `gowatch-child/includes/frontend-submission/assets/js/` — these are now gitignored. Add `.gitkeep` files instead.

**Add `.gitkeep` files to preserve empty artifact directories:**
```bash
touch theme/wp-content/themes/gowatch-child/includes/construkted/assets/js/.gitkeep
touch theme/wp-content/themes/gowatch-child/includes/frontend-submission/assets/js/.gitkeep
```

**Note on `constants.php`:** The existing `theme/wp-content/themes/gowatch-child/includes/constants.php` stays as-is for now. In Phase 3, `pnpm --filter @construkted/shared build:php` will generate `includes/construkted/constants-shared.php` with the numeric status/error codes. The two files serve different purposes:
- `constants.php` — PHP meta key strings, globe status strings, view access strings (theme-only concerns, not in shared TS types)
- `constants-shared.php` — StatusCodes, RunningStatusCodes, AssetModelTypes, ErrorCodes (generated from shared TS)

Both files are committed to git.

**Commit:**
```bash
git add theme/
git commit -m "feat(theme): migrate construkted_reality_v1.x to theme/"
```

---

### Phase 2 verification checklist

- [ ] `packages/shared/` — all 5 source files created, package.json, tsconfig.json
- [ ] `packages/api/` — all source files copied, new package.json with `@construkted/shared: workspace:*`, new tsconfig.json extending base
- [ ] `packages/js/` — src/ copied, no gulp/rollup files, vite.config.ts (not .js), new package.json with `@construkted/shared: workspace:*`
- [ ] `packages/uploadjs/` — src/ copied, vite.config.ts (not .js), new package.json with `@construkted/shared: workspace:*`
- [ ] `theme/wp-content/themes/gowatch-child/` and `gowatch/` present
- [ ] No `yarn.lock` files anywhere in the monorepo
- [ ] No `node_modules/` directories committed
- [ ] `.gitkeep` files in both JS artifact directories in theme
- [ ] `tsconfig.base.json` does NOT contain `target`, `module`, `moduleResolution`, `lib`, or `isolatedModules`

---

## Phase 3: Wire @construkted/shared

### 3.1 — Install and verify workspace links

```bash
# From monorepo root
pnpm install
```

This resolves `workspace:*` references. Verify the links exist:

```bash
ls packages/api/node_modules/@construkted/
# Should show: shared -> ../../../packages/shared
ls packages/js/node_modules/@construkted/
# Should show: shared -> ../../../packages/shared
ls packages/uploadjs/node_modules/@construkted/
# Should show: shared -> ../../../packages/shared
```

### 3.2 — Build shared

```bash
pnpm build:shared
# Should compile packages/shared/src/ → packages/shared/dist/
ls packages/shared/dist/
# Should show: index.js, index.d.ts, index.js.map, etc.
```

### 3.3 — Verify API re-exports compile

```bash
pnpm --filter @construkted/api typecheck
# Should pass. If it fails on lib/statusCodes.ts or lib/runningStatusCodes.ts,
# check that the re-export syntax is correct and @construkted/shared dist exists.
```

### 3.4 — Generate PHP constants

```bash
pnpm --filter @construkted/shared build:php
```

This runs `scripts/generate-php.ts` via `tsx` and writes:
```
theme/wp-content/themes/gowatch-child/includes/construkted/constants-shared.php
```

Verify the file was created:
```bash
head -30 theme/wp-content/themes/gowatch-child/includes/construkted/constants-shared.php
```

### 3.5 — Include the generated constants in the theme

Add this line near the top of `theme/wp-content/themes/gowatch-child/includes/functions.php` (or wherever `constants.php` is currently required):

```php
// Auto-generated shared constants (StatusCodes, RunningStatusCodes, ErrorCodes, AssetModelTypes)
require_once get_stylesheet_directory() . '/includes/construkted/constants-shared.php';
```

Cross-reference: the existing `constants.php` uses string constants for asset types like `'polygon-mesh'`, `'point-cloud'`, etc. These differ from the `AssetModelTypes` object values (`'PolygonMesh'`, `'PointCloud'`). Verify which format the API and viewer actually use before deciding whether to update `constants.php` or keep both.

### 3.6 — Commit the wiring

```bash
git add packages/shared/dist/ theme/wp-content/themes/gowatch-child/includes/construkted/constants-shared.php theme/wp-content/themes/gowatch-child/includes/
git commit -m "feat(shared): wire @construkted/shared, generate PHP constants"
```

### 3.7 — Full build test

```bash
pnpm build
# All 4 packages should build without errors
```

### Phase 3 verification checklist

- [ ] `pnpm install` completes with no errors
- [ ] `packages/shared/dist/` exists with compiled JS and type declarations
- [ ] `packages/api/node_modules/@construkted/shared` is a symlink to `../../../packages/shared`
- [ ] `pnpm --filter @construkted/api typecheck` passes
- [ ] `pnpm --filter @construkted/viewer typecheck` passes
- [ ] `pnpm --filter @construkted/upload typecheck` passes
- [ ] `constants-shared.php` generated and committed
- [ ] `pnpm build` builds all 4 packages without errors
- [ ] `packages/js/dist/construkted.js` exists
- [ ] `packages/uploadjs/dist/construkted.upload.js` exists
- [ ] `packages/api/dist/index.js` exists

---

## Phase 4: GitHub Setup

### 4.1 — Install pnpm on tile servers (one-time, do before cutover)

Run on each tile server (tile03, tile04, tile05):

```bash
# Option A — via corepack (preferred if Node is managed by nvm or system)
corepack enable
corepack prepare pnpm@9.15.0 --activate

# Option B — via npm if corepack is unavailable
npm install -g pnpm@9.15.0

# Verify
pnpm --version
# Should output: 9.15.0
```

### 4.2 — Generate SSH keypairs (one per environment)

Generate Ed25519 keys — one keypair per environment. Do this on your local machine.

```bash
# Staging (gw4)
ssh-keygen -t ed25519 -C "github-deploy-staging" -f ~/.ssh/construkted_deploy_staging -N ""

# Production
ssh-keygen -t ed25519 -C "github-deploy-production" -f ~/.ssh/construkted_deploy_production -N ""

# Dev1
ssh-keygen -t ed25519 -C "github-deploy-dev1" -f ~/.ssh/construkted_deploy_dev1 -N ""

# Dev2
ssh-keygen -t ed25519 -C "github-deploy-dev2" -f ~/.ssh/construkted_deploy_dev2 -N ""

# API prod (tile03)
ssh-keygen -t ed25519 -C "github-deploy-api-prod" -f ~/.ssh/construkted_deploy_api_prod -N ""

# API dev tile04
ssh-keygen -t ed25519 -C "github-deploy-api-tile04" -f ~/.ssh/construkted_deploy_api_tile04 -N ""

# API dev tile05
ssh-keygen -t ed25519 -C "github-deploy-api-tile05" -f ~/.ssh/construkted_deploy_api_tile05 -N ""
```

**Add public keys to each server's `~/.ssh/authorized_keys`:**

For WordPress/cPanel servers, restrict the key with `rrsync` to limit rsync to the deploy directory only:

```
command="/usr/bin/rrsync /home/gw4/public_html/wp-content/themes/gowatch-child",restrict ssh-ed25519 AAAA...publickey... github-deploy-staging
```

For API servers (tile03/04/05), add the key without restriction (the deploy script needs to restart the service):

```
ssh-ed25519 AAAA...publickey... github-deploy-api-prod
```

### 4.3 — Generate `ACTIONS_SSH_KNOWN_HOSTS` secret

Run this for every server hostname that workflows will connect to:

```bash
ssh-keyscan -H <staging-hostname> >> known_hosts_combined
ssh-keyscan -H <production-hostname> >> known_hosts_combined
ssh-keyscan -H <dev1-hostname> >> known_hosts_combined
ssh-keyscan -H <dev2-hostname> >> known_hosts_combined
ssh-keyscan -H <tile03-hostname> >> known_hosts_combined
ssh-keyscan -H <tile04-hostname> >> known_hosts_combined
ssh-keyscan -H <tile05-hostname> >> known_hosts_combined

cat known_hosts_combined
```

Copy the full output. This becomes the `ACTIONS_SSH_KNOWN_HOSTS` repository-level secret.

### 4.4 — Create GitHub Environments

Navigate to: `Settings → Environments → New environment`

Create all 7 environments:

| Environment | Protection rules | Branch restriction |
|---|---|---|
| `staging` | None | None |
| `production` | Required reviewer: 1+ | Branch: `main` only |
| `dev1` | None | None |
| `dev2` | None | None |
| `api-prod` | Required reviewer: 1+ | Branch: `main` only |
| `api-dev-tile04` | None | None |
| `api-dev-tile05` | None | None |

### 4.5 — Populate environment secrets

**For each WordPress environment** (`staging`, `production`, `dev1`, `dev2`):

| Secret name | Value |
|---|---|
| `SSH_HOST` | Server hostname or IP |
| `SSH_PORT` | SSH port (usually 22) |
| `SSH_USER` | cPanel/SSH username |
| `SSH_PRIVATE_KEY` | Contents of the matching `~/.ssh/construkted_deploy_<env>` private key file |
| `DEPLOY_PATH` | Absolute path to theme directory, e.g. `/home/gw4/public_html/wp-content/themes/gowatch-child` |

**For each API environment** (`api-prod`, `api-dev-tile04`, `api-dev-tile05`):

| Secret name | Value |
|---|---|
| `SSH_HOST` | tile server hostname or IP |
| `SSH_PORT` | SSH port |
| `SSH_USER` | SSH username on tile server |
| `SSH_PRIVATE_KEY` | Contents of the matching private key file |
| `DEPLOY_PATH` | Absolute path to API directory on the server |
| `SERVICE_NAME` | systemd service name, e.g. `construkted-api` |

**Repository-level secrets** (Settings → Secrets and variables → Actions → New repository secret):

| Secret name | Value |
|---|---|
| `ACTIONS_SSH_KNOWN_HOSTS` | Contents of `known_hosts_combined` from step 4.3 |

### 4.6 — Configure branch protection on `main`

Settings → Branches → Add branch protection rule for `main`:

- [x] Require a pull request before merging
- [x] Require at least 1 approving review
- [x] Dismiss stale pull request approvals when new commits are pushed
- [x] Require status checks to pass before merging
  - Add: `lint-and-typecheck` (from ci.yml)
  - Add: `build-verification` (from ci.yml)
- [x] Require branches to be up to date before merging
- [x] Do not allow bypassing the above settings
- [x] Automatically delete head branches

### Phase 4 verification checklist

- [ ] pnpm 9.15.0 installed on tile03, tile04, tile05
- [ ] 7 SSH keypairs generated
- [ ] Public keys added to authorized_keys on each server
- [ ] WP server keys restricted with `rrsync`
- [ ] `ACTIONS_SSH_KNOWN_HOSTS` secret populated with all 7 server fingerprints
- [ ] All 7 GitHub Environments created
- [ ] `production` and `api-prod` have required reviewer protection
- [ ] All environment secrets populated (SSH_HOST, SSH_PORT, SSH_USER, SSH_PRIVATE_KEY, DEPLOY_PATH)
- [ ] API environments have SERVICE_NAME secret
- [ ] Branch protection on `main` requires CI checks

---

## Phase 5: CI/CD Workflows

All workflows go in `.github/workflows/`. Create all 4 files and commit them together:

```bash
git commit -m "feat(ci): add GitHub Actions workflows"
```

---

### 5.1 — `ci.yml`

Bugs fixed vs previous plan:
- Added PHP constants staleness check step in `build-verification` job

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

      - name: Typecheck all packages
        run: pnpm typecheck

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

      - name: Check PHP constants are up-to-date
        if: needs.changes.outputs.shared == 'true'
        run: |
          pnpm --filter @construkted/shared build:php
          if ! git diff --exit-code theme/wp-content/themes/gowatch-child/includes/construkted/constants-shared.php; then
            echo ""
            echo "ERROR: constants-shared.php is out of date."
            echo "The shared TypeScript types were changed but the generated PHP constants file was not regenerated."
            echo "Fix: run 'pnpm --filter @construkted/shared build:php' locally and commit the updated constants-shared.php."
            exit 1
          fi
          echo "PHP constants are up-to-date."

      - name: Verify build artifacts exist
        run: |
          if [ "${{ needs.changes.outputs.viewer }}" == "true" ]; then
            test -f packages/js/dist/construkted.js \
              || (echo "FAIL: packages/js/dist/construkted.js not built" && exit 1)
          fi
          if [ "${{ needs.changes.outputs.upload }}" == "true" ]; then
            test -f packages/uploadjs/dist/construkted.upload.js \
              || (echo "FAIL: packages/uploadjs/dist/construkted.upload.js not built" && exit 1)
          fi
          if [ "${{ needs.changes.outputs.api }}" == "true" ]; then
            test -f packages/api/dist/index.js \
              || (echo "FAIL: packages/api/dist/index.js not built" && exit 1)
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
        run: |
          find theme/ -name "*.php" -print0 | xargs -0 -n1 php -l | grep -v "No syntax errors" || true
          echo "PHP syntax check complete."
```

---

### 5.2 — `deploy-theme.yml`

Bugs fixed vs previous plan:
- Added `on: workflow_call:` trigger with matching inputs (enables `release.yml` to call this)
- All `github.event.inputs.xxx` replaced with `inputs.xxx` (works for both `workflow_dispatch` and `workflow_call`)
- Concurrency group uses `inputs.environment || 'staging'` (not `github.event.inputs.environment` which is empty on push)

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

  workflow_call:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: string
      include_sourcemaps:
        description: 'Include source maps'
        required: false
        type: boolean
        default: false

concurrency:
  group: deploy-theme-${{ inputs.environment || 'staging' }}
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
          mkdir -p deploy-theme-artifact

          # Copy the theme directory
          cp -r theme/wp-content/themes/gowatch-child deploy-theme-artifact/gowatch-child

          # Place built JS into the theme directory structure
          cp packages/js/dist/construkted.js \
             deploy-theme-artifact/gowatch-child/includes/construkted/assets/js/construkted.js

          cp packages/uploadjs/dist/construkted.upload.js \
             deploy-theme-artifact/gowatch-child/includes/frontend-submission/assets/js/construkted.upload.js

          # Include source maps based on input
          INCLUDE_MAPS="${{ inputs.include_sourcemaps }}"
          if [ "$INCLUDE_MAPS" == "true" ]; then
            cp packages/js/dist/construkted.js.map \
               deploy-theme-artifact/gowatch-child/includes/construkted/assets/js/construkted.js.map
            cp packages/uploadjs/dist/construkted.upload.js.map \
               deploy-theme-artifact/gowatch-child/includes/frontend-submission/assets/js/construkted.upload.js.map
          fi

      - name: Upload deployment artifact
        uses: actions/upload-artifact@v4
        with:
          name: theme-deploy-${{ github.sha }}
          path: deploy-theme-artifact/gowatch-child
          retention-days: 7

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'staging' }}
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
            "test -f ${{ secrets.DEPLOY_PATH }}/includes/construkted/assets/js/construkted.js \
              && echo 'construkted.js: OK' \
              || (echo 'construkted.js: MISSING' && exit 1)"
```

---

### 5.3 — `deploy-api.yml`

Bugs fixed vs previous plan:
- Added `on: workflow_call:` trigger with matching inputs
- Removed the broken `cp pnpm-lock.yaml api-deploy/` line — the lockfile is not needed on the server
- Server-side install now uses `pnpm install --prod --frozen-lockfile` (not `npm install`)
- All `github.event.inputs.xxx` replaced with `inputs.xxx`

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

  workflow_call:
    inputs:
      environment:
        description: 'Target API server'
        required: true
        type: string

concurrency:
  group: deploy-api-${{ inputs.environment || 'api-dev-tile04' }}
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

          # Compiled output
          cp -r packages/api/dist api-deploy/dist

          # package.json only — pnpm install runs on the server
          cp packages/api/package.json api-deploy/

          # Embed shared types dist directly (workspace dep, not resolvable on server)
          mkdir -p api-deploy/node_modules/@construkted/shared
          cp -r packages/shared/dist api-deploy/node_modules/@construkted/shared/dist
          cp packages/shared/package.json api-deploy/node_modules/@construkted/shared/

          # Env template for reference
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
    environment: ${{ inputs.environment || 'api-dev-tile04' }}
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
            "cd ${{ secrets.DEPLOY_PATH }} && pnpm install --prod --frozen-lockfile"

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
            "systemctl is-active ${{ secrets.SERVICE_NAME }} \
              && echo 'Service: RUNNING' \
              || (echo 'Service: FAILED' && exit 1)"
```

---

### 5.4 — `release.yml`

This workflow now works correctly because `deploy-theme.yml` and `deploy-api.yml` both have `on: workflow_call:` triggers with matching `inputs` blocks.

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
        description: 'Include source maps in production build'
        required: false
        type: boolean
        default: false

run-name: "Production Release — Theme:${{ inputs.deploy_theme }} API:${{ inputs.deploy_api }}"

concurrency:
  group: production-release
  cancel-in-progress: false

jobs:
  preflight:
    runs-on: ubuntu-latest
    steps:
      - name: Verify branch is main
        if: github.ref != 'refs/heads/main'
        run: |
          echo "Production releases must be triggered from the main branch."
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

---

### Phase 5 verification checklist

- [ ] All 4 workflow YAML files committed under `.github/workflows/`
- [ ] `ci.yml` — PHP constants staleness check step present in `build-verification` job
- [ ] `deploy-theme.yml` — has `on: workflow_call:` block with `inputs:` matching `workflow_dispatch`
- [ ] `deploy-theme.yml` — all references use `inputs.xxx` not `github.event.inputs.xxx`
- [ ] `deploy-theme.yml` — concurrency group uses `inputs.environment || 'staging'`
- [ ] `deploy-api.yml` — has `on: workflow_call:` block
- [ ] `deploy-api.yml` — server install uses `pnpm install --prod --frozen-lockfile`
- [ ] `deploy-api.yml` — no `cp pnpm-lock.yaml` line
- [ ] `release.yml` — calls both workflows with `secrets: inherit`
- [ ] YAML files pass syntax check: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` (repeat for all 4)

---

## Phase 6: Cutover Procedure

Execute this checklist in order. Do not proceed to the next step if a step fails.

### Pre-cutover prerequisites

1. **Confirm Phase 0 PRs merged**
   - [ ] `construkted.js` Phase 0 PR is merged to `develop`
   - [ ] `construkted.uploadjs` Phase 0 PR is merged to `main`

2. **Confirm pnpm on tile servers**
   - [ ] `pnpm --version` returns `9.15.0` on tile03
   - [ ] `pnpm --version` returns `9.15.0` on tile04
   - [ ] `pnpm --version` returns `9.15.0` on tile05

3. **Confirm GitHub Environments exist**
   - [ ] All 7 environments created with correct secrets (see Phase 4 checklist)
   - [ ] `ACTIONS_SSH_KNOWN_HOSTS` repository secret populated

4. **Confirm SSH keys work**
   - [ ] Test SSH connection to each server: `ssh -i ~/.ssh/construkted_deploy_staging -p <port> <user>@<host> "echo ok"`

### Cutover steps

5. **Full local build**
   ```bash
   cd construkted-wp
   pnpm install && pnpm build
   ```
   - [ ] All 4 packages build without errors

6. **Create a test PR**
   - Make a trivial change (e.g., add a comment to `README.md`)
   - Open a PR to `main`
   - [ ] CI workflow triggers and passes all jobs
   - [ ] Merge the PR

7. **Verify staging auto-deploy**
   - [ ] After merging to `main`, the `deploy-theme.yml` workflow triggers automatically
   - [ ] Deployment succeeds
   - [ ] SSH to staging server and verify `construkted.js` is present in theme directory

8. **Test API deploy**
   - Manually trigger `Deploy API` workflow → target `api-dev-tile04`
   - [ ] Workflow succeeds
   - [ ] API service is running on tile04 (`systemctl is-active <service-name>`)

9. **QA staging site**
   - [ ] Staging site loads without JS errors
   - [ ] 3D viewer initializes correctly
   - [ ] Upload form functions correctly
   - [ ] No PHP errors in WordPress logs

10. **Archive old repos**
    - In each old repo's `README.md`, prepend:
      ```markdown
      > **ARCHIVED:** This repository has been superseded by [construkted-wp](https://github.com/Construkted-Reality/construkted-wp).
      > Archived on 2026-03-XX. This repo is kept for historical reference only.
      ```
    - Commit and push to each old repo's primary branch
    - In GitHub, go to Settings → Danger Zone → Archive this repository for each:
      - `construkted_api`
      - `construkted.js`
      - `construkted.uploadjs`
      - `construkted_reality_v1.x`

11. **Announce to team**
    - Share monorepo URL
    - Share local development setup instructions (clone, `pnpm install`, `pnpm build:shared`, set up `.env` for each package)
    - Note which old branches need to be ported (see Phase 7)

### Phase 6 verification checklist

- [ ] `pnpm build` passes locally with no errors
- [ ] CI passes on a real PR
- [ ] Staging auto-deploys on merge to main
- [ ] API deploys successfully to tile04
- [ ] Staging site is functional
- [ ] All 4 old repos archived on GitHub

---

## Phase 7: Migrating In-Flight Feature Branches

Use this process to port any feature branch from an old repo into the monorepo. Repeat for each branch that needs to be carried forward.

### The general process

**Step 1 — Identify what changed in the old branch**

In the old repo:
```bash
# Find the base branch the feature branched from
git log --oneline <base-branch>..<feature-branch>

# List changed files
git diff <base-branch> <feature-branch> --name-only

# Get the full diff
git diff <base-branch> <feature-branch> > /tmp/feature-branch.patch
```

**Step 2 — Create a new branch in the monorepo**

```bash
cd construkted-wp
git checkout main
git pull
git checkout -b feature/<same-name>
```

**Step 3 — Apply changes**

For each changed file, apply the change to the corresponding monorepo path using the path mapping below. Do not use `git apply` on the raw patch — paths won't match. Instead:

1. Open the old diff
2. Locate each changed file
3. Manually apply the change at the new path

**Step 4 — Update imports if needed**

If the changed file imported from `lib/statusCodes.ts`, `lib/runningStatusCodes.ts`, or equivalent:

```typescript
// Old import (construkted_api)
import { StatusCodes } from '../lib/statusCodes';

// New import (monorepo, packages/api)
import { StatusCodes } from '@construkted/shared';
```

**Step 5 — Open a PR in the monorepo**

```bash
git push -u origin feature/<same-name>
```

Open the PR and add this to the description:
```
Ported from <old-repo>#<PR-number> (<link>)

Original branch: <feature-branch-name>
```

**Step 6 — Close the original PR**

Comment on the original PR:
```
Superseded by Construkted-Reality/construkted-wp#<new-PR-number>.
This PR is now closed — the changes have been ported to the monorepo.
```

Close without merging.

---

### Path mapping reference

| Old path | New path in monorepo |
|---|---|
| `construkted_api/<file>` | `packages/api/<file>` |
| `construkted_api/lib/<file>` | `packages/api/lib/<file>` |
| `construkted_reality_v1.x/wp-content/themes/gowatch-child/<file>` | `theme/wp-content/themes/gowatch-child/<file>` |
| `construkted.js/src/<file>` | `packages/js/src/<file>` |
| `construkted.uploadjs/src/<file>` | `packages/uploadjs/src/<file>` |

---

### Specific branch: `feature/shared-secret-auth`

Both `construkted_api` and `construkted_reality_v1.x` have a `feature/shared-secret-auth` branch. These two branches form one logical feature that spans both repos — exactly the scenario the monorepo is designed for.

**In the old repos:**

```bash
# construkted_api
cd /path/to/construkted_api
git diff master feature/shared-secret-auth --name-only
git diff master feature/shared-secret-auth > /tmp/api-shared-secret-auth.patch

# construkted_reality_v1.x
cd /path/to/construkted_reality_v1.x
git diff develop feature/shared-secret-auth --name-only
git diff develop feature/shared-secret-auth > /tmp/theme-shared-secret-auth.patch
```

**In the monorepo:**

```bash
cd construkted-wp
git checkout -b feature/shared-secret-auth
```

Apply the API diff changes to `packages/api/`, apply the theme diff changes to `theme/wp-content/themes/gowatch-child/`.

Open **one PR** in the monorepo touching both `packages/api/` and `theme/`. This is the monorepo advantage: the cross-repo feature is now a single reviewable PR.

**PR description template:**
```
feat: shared secret authentication between API and theme

Ported from:
- construkted_api feature/shared-secret-auth (original PR: #XX)
- construkted_reality_v1.x feature/shared-secret-auth (original PR: #XX)

This combines both sides of the cross-repo feature into a single PR.
```

---

### Phase 7 verification checklist (per branch)

- [ ] `git diff <base>..<feature> --name-only` run in old repo to identify all changed files
- [ ] New branch created from `main` in monorepo
- [ ] All changed files applied at correct monorepo paths
- [ ] Import paths updated where needed (especially `@construkted/shared`)
- [ ] `pnpm typecheck` passes
- [ ] `pnpm build` passes
- [ ] PR opened in monorepo with link to original PR
- [ ] Original PR closed with comment linking to monorepo PR

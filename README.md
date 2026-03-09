# Construkted Workspace

Shared workspace for the Construkted Reality web platform. This repo ties together 4 independent sub-repositories, provides a unified development environment, and houses cross-repo documentation, plans, and AI agent configuration.

## Sub-Repositories

| Repo | Description | Stack | Working Branch | Production Branch |
|------|-------------|-------|----------------|-------------------|
| `construkted_api` | 3D asset processing API — tiling pipelines, S3 uploads, task management | Express / TypeScript | `master` | `master` |
| `construkted.js` | 3D globe viewer — CesiumJS/Three.js map, annotations, XR, navigation | CesiumJS / TypeScript | `develop` | `master` |
| `construkted.uploadjs` | File upload widget — drag-and-drop upload UI for WordPress frontend | jQuery / TypeScript | `main` | `main` |
| `construkted_reality_v1.x` | WordPress site — GoWatch child theme with project/album pages | PHP / WordPress | `develop` | `master` |

These repos are **not** git submodules. They are independent clones that live inside this workspace directory and are ignored by the workspace's own `.gitignore`.

## Setup

### Prerequisites

- Git installed and configured
- SSH key added to GitHub (or use `--https` / `-UseHttps` for HTTPS)

### 1. Clone this repo

```bash
git clone git@github.com:Construkted-Reality/construkted_wp-workspace.git
cd construkted_wp-workspace
```

### 2. Run the setup script

The setup script clones all 4 sub-repos into the workspace directory and checks out their default working branches.

**Linux / Mac:**
```bash
./setup.sh
```

**Windows (PowerShell):**
```powershell
.\setup.ps1
```

**Options:**

| Flag | Description |
|------|-------------|
| `--https` / `-UseHttps` | Clone using HTTPS instead of SSH |
| `--update` / `-Update` | Pull latest changes for repos that already exist |

### 3. Open the workspace

```bash
code construkted.code-workspace    # VS Code
cursor construkted.code-workspace  # Cursor
```

Or double-click `construkted.code-workspace` in your file explorer.

## Workspace Structure

```
construkted_wp-workspace/
├── construkted_api/             ← sub-repo (cloned by setup script)
├── construkted.js/              ← sub-repo (cloned by setup script)
├── construkted.uploadjs/        ← sub-repo (cloned by setup script)
├── construkted_reality_v1.x/    ← sub-repo (cloned by setup script)
├── wordpress/                   ← vanilla WordPress install (DDEV)
├── docs/                        ← cross-repo documentation
│   ├── plans/                   ← feature/fix plans (shared across team)
│   ├── brainstorms/             ← brainstorm documents
│   └── research/                ← research notes
├── agent-os/                    ← product standards and conventions
│   ├── product/                 ← mission, roadmap, tech stack
│   └── standards/               ← API, PHP, TypeScript, build standards
├── tests/                       ← workspace-level functional tests
├── AGENTS.md                    ← AI agent configuration and branch rules
├── construkted.code-workspace   ← VS Code / Cursor workspace file
├── setup.sh                     ← Linux/Mac setup script
└── setup.ps1                    ← Windows setup script
```

## docs/plans Convention

AI tools and developers use `docs/plans/` to record feature plans and fix strategies. These files are committed to this repo and serve as historical context for future work.

**Naming convention:**
```
docs/plans/{YYYY-MM-DD}-{type}-{short-description}-plan.md
```

Examples:
- `docs/plans/2026-02-22-fix-user-notification-email-never-sent-plan.md`
- `docs/plans/2026-03-05-fix-s3-5gb-upload-limit-plan.md`

## Branch Rules

This workspace repo uses `main` as its default branch.

For the sub-repos, see the branch rules in [AGENTS.md](AGENTS.md). The key rule: **never branch from `master`** in `construkted.js`, `construkted.uploadjs`, or `construkted_reality_v1.x` — always use `develop` (or `main` for uploadjs).

## Commit Convention

All repos follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

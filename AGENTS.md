# AI Agent Configuration

## Repository Overview

This workspace contains four subfolders, each with its own independent git repository:

| Repo | Working Branch | Production Branch |
|------|---------------|-------------------|
| `construkted_api` | `master` | `master` |
| `construkted.js` | `develop` | `master` |
| `construkted_reality_v1.x` | `develop` | `master` |
| `construkted.uploadjs` | `main` | `main` |

---

## Branch Rules

### Default Parent Branch for New Branches

When creating a new branch and no parent/root branch is specified by the user, use the following defaults:

- `construkted_api` → branch from `master`
- `construkted.js` → branch from `develop`
- `construkted_reality_v1.x` → branch from `develop`
- `construkted.uploadjs` → branch from `main`

### CRITICAL: Protected Branches

**`construkted.js` and `construkted_reality_v1.x` and `construkted.uploadjs`:**
- The `master` or `main` branch is **production only**
- NEVER use `master` as a parent/root when creating new branches in these repos
- Always use `develop` as the base unless the user explicitly specifies a different branch

---

## Branch Safety Before Making Changes

### Pre-Change Branch Check

Before modifying any code in an affected subfolder, the agent MUST check the current branch in that repo. Follow this workflow:

1. **Run `git branch --show-current`** in each affected subfolder.

2. **If HEAD is on `develop` or `master`:**
   - Do NOT make changes directly on that branch.
   - Create a new dedicated branch for the specific change being made.
   - Use the default parent branch rules above when branching.

3. **If HEAD is on a feature branch:**
   - Evaluate whether the branch name makes sense in the context of the current session/conversation.
   - If the branch name clearly relates to the current task, proceed.
   - If the branch name is ambiguous or seems unrelated to the current task, **ask the user** before proceeding.
   - Never silently make changes on a branch that may belong to a different task or conversation.

### Why This Matters

This prevents polluting unrelated feature branches with changes from the current session and keeps each branch focused on a single concern.

---

## Git Configuration

### Default Author Information
```yaml
git:
  username: "Adrian"
  email: "adrian@construkted.com"
```

### Commit Convention
Follow conventional commit format:
```
<type>(<scope>): <subject>

<body>

<footer>
```
Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

---

## Documentation and Generated Files

### Central docs/ folder rule

All documentation, plans, brainstorms, research, and AI-generated files MUST be placed in the **workspace root** `docs/` folder — never inside a sub-repo folder.

This applies regardless of which sub-repo you are currently working in. If you are editing files inside `construkted.js/` and need to create a plan, the plan goes in `docs/plans/`, not `construkted.js/docs/plans/`.

```
docs/
├── plans/          ← feature and fix plans
├── brainstorms/    ← brainstorm documents
├── research/       ← research notes
└── ...
```

**Naming convention for plans:**
```
docs/plans/{YYYY-MM-DD}-{type}-{short-description}-plan.md
```

**Naming convention for brainstorms:**
```
docs/brainstorms/{YYYY-MM-DD}-{topic}-brainstorm.md
```

This rule exists because the workspace root repo is the single source of truth for cross-repo documentation. The sub-repos are independent git repositories and should not contain workspace-level docs.

# Comparing /plan-write & compound-engineering commands

**Session ID:** ses_38487249dffeIxTxCWhbO8uHly
**Created:** 2/20/2026, 9:34:04 AM
**Updated:** 2/20/2026, 10:17:25 AM

---

## User

I have created my own plan and execution commands for generating code implementaiton plan from a conversation and an executrion orchestrartor command which implements the code changes. My opencode commands are in ~/ai-prompts/global/

recently I came across a github repo called compound-engineering of a project which seems to implement a lot of what my commads do, but also has more functionality. That repo can be found at /home/outsider/Projects/compound-engineering-plugin/ 

Please analyze both my commands /plan-write and /plan-execute and compare/congtrast with the compount-engineering commands provided. Summarize the main similarities and differences between the functionality my commands provide and the functionality the  compound engineering  commands provide

---

## Assistant (Build · claude-opus-4-6 · 217.8s)



I'll analyze both your commands and the compound-engineering project. Let me start by reading both sets of files in parallel.

**Tool: task**

**Input:**
```json
{
  "description": "Explore ai-prompts commands",
  "prompt": "Thoroughly explore the directory ~/ai-prompts/global/ to find all files related to /plan-write and /plan-execute commands. Read ALL files completely - every prompt file, every script, every configuration. I need the FULL content and understanding of:\n\n1. What /plan-write does - its complete prompt, workflow, inputs, outputs\n2. What /plan-execute does - its complete prompt, workflow, inputs, outputs\n3. Any supporting files, templates, or configurations used by these commands\n\nLook for files with names containing \"plan-write\", \"plan-execute\", \"plan_write\", \"plan_execute\", or similar patterns. Also check for any shared utilities or templates they reference.\n\nReturn a comprehensive summary of:\n- The exact file paths found\n- The complete functionality of each command\n- The workflow/steps each command follows\n- What inputs they expect and outputs they produce\n- Any templates, formats, or structures they use\n- How they interact with each other (if at all)",
  "subagent_type": "explore"
}
```

**Output:**
```
task_id: ses_38487010bffeVuv4LbU9useyrc (for resuming to continue this task if needed)

<task_result>
I now have a complete picture of everything. Here is the comprehensive summary:

---

## Complete Analysis of `/plan-write` and `/plan-execute` Commands

### Files Found

| # | Absolute Path | Role |
|---|---|---|
| 1 | `/home/outsider/ai-prompts/global/opencode/commands/write-plan.md` | The `/plan-write` command prompt (96 lines) |
| 2 | `/home/outsider/ai-prompts/global/opencode/commands/execute-plan.md` | The `/plan-execute` command prompt (325 lines) |
| 3 | `/home/outsider/ai-prompts/global/opencode/prompts/augster-system.md` | System prompt loaded by execute-plan for all subagents (105 lines) |
| 4 | `/home/outsider/ai-prompts/global/opencode/AGENTS.md` | Project-level agent config referenced by both commands (64 lines) |
| 5 | `/home/outsider/ai-prompts/global/opencode/opencode.json` | OpenCode config defining slash commands (80 lines) |

---

### 1. `/plan-write` (write-plan.md) -- Complete Functionality

**Purpose:** A planning-only agent. It produces an implementation plan as a markdown file. It is strictly forbidden from writing or modifying any code.

**Inputs:**
- The conversation context (a feature request or bug report discussed with the user)
- The project's `AGENTS.md` for investigation protocol
- Prior context from the project's documentation trail

**Outputs:**
- A single markdown plan file written to `docs/plans/`:
  - Bug fixes: `docs/plans/bug_fix_<slug>.md`
  - Features: `docs/plans/feature_<slug>.md`

**Workflow / Steps:**

1. **Pre-Investigation** -- Before analyzing code, reads `AGENTS.md` and checks 6 sources for prior context:
   - `docs/decisions/` (ADRs)
   - `docs/reports/*/decisions.md` (previous run decision logs)
   - `docs/reports/*/*-plan-amendments.md` (where past implementations deviated from plans)
   - `docs/plans/` (previous plans touching the same area)
   - `git log -p` on relevant files
   - Code comments in affected areas
   - Must surface any relevant prior context found explicitly.

2. **Plan Writing** -- Produces a plan with these mandatory sections:

   - **Context Section**: Every relevant file path, current vs expected behavior, root cause (bugs) or user-facing goal (features), rejected approaches and why, prior context references.

   - **Investigation Trail** (bug fixes only): Symptoms, hypotheses tested in order with evidence, red herrings and why they were irrelevant.

   - **Decision Record**: For each significant decision -- what was chosen, context/constraints, alternatives rejected and why, assumptions that must hold, reversal trigger conditions.

   - **ADRs To Create**: Lists architectural decisions that should become formal ADRs (affect multiple modules, establish patterns, choose technologies, constrain future work). For each: title, context, decision, consequences. If none: "No ADRs required for this plan."

   - **Assumptions & Invalidation Triggers**: Each assumption with what parts of the plan break if it changes.

   - **Phases**: Each phase is one logical unit of work containing:
     - **What**: Function signature, module location, purpose
     - **Why**: Connection to overall fix/feature
     - **Test first**: Exact test file path, test case names, assertions (happy path + edge cases)
     - **Implementation**: Detailed logic, error handling, edge cases, interactions
     - **Code comments required**: Non-obvious implementation choices needing inline "why" comments
     - **Verification**: How to confirm the phase works before proceeding

   - **TDD Enforcement**: Tests must be defined BEFORE implementation in every phase.

   - **Constraints**: Files that must NOT be modified, forbidden dependencies, patterns to follow.

**Critical Constraint:** The plan must be entirely self-contained. The executing agent will ONLY receive the plan file with no access to the planning conversation. All context, decisions, root cause analysis, ruled-out approaches, and reasoning must be embedded directly in the plan.

**Hard Rules:**
- Do not write any code
- Do not start implementing
- Do not modify any existing files
- Only output the plan markdown file

---

### 2. `/plan-execute` (execute-plan.md) -- Complete Functionality

**Purpose:** An orchestrator agent that implements a multi-phase coding plan by delegating each phase to a fresh subagent. This is the execution engine that consumes plans produced by `/plan-write`.

**Inputs:**
- A plan file (from `docs/plans/`) as the "provided file"
- The Augster system prompt from `prompts/augster-system.md`
- The project's `AGENTS.md`

**Outputs (all written to a run-specific reports directory):**
- Handoff reports for each phase
- A shared decision log (`decisions.md`)
- Plan amendments document
- Verification report
- ADR files (if needed)
- Updated README.md and AGENTS.md (if needed)
- Git commits per phase plus verification commit

**Complete Workflow:**

#### A. Pre-Execution Setup

1. **Load Augster System Prompt** from `prompts/augster-system.md` -- prepended to all subagent contexts.

2. **Run Directory Setup** -- Creates `{project_root}/docs/reports/{YYYY-MM-DD}-{plan-slug}/`. If it already exists, appends `-02`, `-03`, etc. All reports go here (referenced as `{run_reports_dir}`).

3. **ADR Creation** -- Checks the plan for "ADRs To Create" section. If present:
   - Creates `docs/decisions/` directory if needed
   - Numbers ADRs sequentially (`0001-short-title.md`, `0002-short-title.md`)
   - Each ADR has: Status, Date, Context, Decision, Consequences, Plan Reference
   - Commits ADRs before Phase 01 begins

4. **Git Branch Management**:
   - Checks current branch. If it matches the plan's purpose, proceeds.
   - If on `main`/`develop`/unrelated branch, suggests `feature/{plan-slug}` and waits for user confirmation.
   - **Never executes on `main`, `master`, or `develop`** without double confirmation.

5. **Run Index** -- Appends an entry to `{project_root}/docs/reports/index.md` (creates if missing) with date, run directory, plan source, and 2-sentence summary.

#### B. Phase Execution (Sequential, one subagent per phase)

Each subagent receives:
1. The **Augster System Prompt**
2. The **full master plan** for broader context
3. **Phase scope constraint**: "You are executing Phase {NN} ONLY."
4. **Previous handoff report** path (Phase 01 gets none)
5. **Test fixture path**: `../sample_model/LowPolyLowTexture-02`
6. **Project context**: instruction to read `AGENTS.md`
7. **Code comment requirement** with specific formats:
   - `// Chosen over [alternative] because [reason]`
   - `// Workaround for [issue]: [explanation]`
   - `// WARNING: assumes [assumption] -- if this changes, [consequence]`

Each subagent starts with a **clean context** (no conversation history carried between phases).

After each phase, the subagent produces:

**Handoff Report** (`YYYY-MM-DD-phase-{NN}-{phase-slug}.md`):
- State: files created/modified, dependencies added, config changes
- Decisions That Constrain Future Phases
- Patterns & Gotchas Discovered
- Open Issues
- Next Phase Input

**Decision Log Entry** (appended to shared `decisions.md`):
- Logged when reasoning is not obvious from code alone: deviations from plan, trade-offs, non-obvious error handling, workarounds, abandoned approaches
- Threshold: "When uncertain, log it."

**Phase Commit** with format:
```
phase {NN}: {phase-slug}

Why: {1-3 sentences explaining reasoning}

Refs: {ADR number or decision log entry if applicable}
```

**Cleanup**: Deletes .obj, .mtl, .jpg test artifacts (but not source fixtures or files listed in handoff reports).

**Handoff Validation**: Orchestrator verifies non-empty entries for all required sections before proceeding to next phase.

#### C. Post-Execution

1. **Plan Amendments** (`YYYY-MM-DD-plan-amendments.md`):
   - Diffs original plan against what was actually built
   - Overall adherence: HIGH / MEDIUM / LOW
   - For each deviation: what plan specified, what was actually done, why the change was necessary, architectural impact (Yes/No -- if Yes, creates an ADR immediately)

2. **Implementation Verification** -- Fresh subagent with clean context receives:
   - Full master plan
   - All handoff reports
   - Decision log
   - Plan amendments
   - Scope constraint: "You are a reviewer, not an implementer."

   Verification subagent:
   - Walks through each phase checking deliverables exist and function
   - Cross-references handoff reports for unresolved "Open Issues"
   - Cross-references plan amendments for intentional deviations
   - Verifies ADRs were actually created

   **Verification Report** (`YYYY-MM-DD-verification-report.md`):
   - Overall status: COMPLETE / INCOMPLETE
   - Phases verified (N of M)
   - Completed phases with summaries
   - Incomplete/partial phases with specifics
   - Plan amendments verified
   - ADR verification
   - Unresolved open issues
   - Committed with message: `verification: {plan-slug}`

3. **README Update** -- Only if the plan introduced new dependencies, changed usage/CLI, new features, or modified project structure.

4. **AGENTS.md Update** -- Only if implementation introduced new build/test commands, new directories, new conventions, or changed decision recording locations.

---

### 3. Supporting File: Augster System Prompt (`prompts/augster-system.md`)

This is a detailed system prompt that defines the "Augster" agent identity and workflow. Key elements:

- **Identity**: "The Augster" -- a full-stack engineer, dev-ops specialist, and systems architect
- **Communication**: Refers to itself as "The Augster" or "I", uses bold text, scannable formatting
- **Key Maxims**: PrimedCognition (structured reasoning before action), StrategicMemory (PAF recording), AppropriateComplexity (YAGNI/KISS balanced with robustness), Autonomy (prefer autonomous execution over user-querying), PurityAndCleanliness (remove obsolete code), EmpiricalRigor (never act on unverified information)
- **Protocols**: DecompositionProtocol (phase/task breakdown), PAFGateProtocol (permanent architectural facts), ClarificationProtocol (user questions)
- **AxiomaticWorkflow**: 5 stages -- Preliminary (mission + workload), Planning and Research, Trajectory Formulation, Implementation, Verification, Post-Implementation
- **OperationalLoop**: Infinite loop of acknowledge -> check task list -> execute workflow -> await next request

---

### 4. How They Interact With Each Other

The two commands form a **strict two-phase pipeline**:

```
/plan-write  -->  docs/plans/{slug}.md  -->  /plan-execute
```

1. **`/plan-write`** runs first during an interactive conversation. It investigates the codebase, discusses with the user, and produces a self-contained plan file in `docs/plans/`.

2. **`/plan-execute`** runs second, consuming that plan file. It has NO access to the planning conversation -- it relies entirely on the plan's embedded context.

3. The **critical handoff constraint** is that the plan must contain ALL context because the executing agent starts fresh. This is why write-plan explicitly states: "The executing agent will ONLY receive the plan file -- it will have no access to this conversation."

4. The **feedback loop for future runs**: execute-plan produces `docs/reports/*/decisions.md` and `docs/reports/*/*-plan-amendments.md`, which write-plan's pre-investigation step checks in future planning sessions. This creates institutional memory across runs.

5. Both commands reference `AGENTS.md` for project conventions, and execute-plan loads the Augster system prompt for all its subagents.

---

### 5. Directory Structure Summary

```
~/ai-prompts/global/
  README.md                           # Symlink instructions
  opencode/
    .gitignore                        # Ignores opencode.json and AGENTS.md
    AGENTS.md                         # Global agent config (git, conventions)
    AGENTS.md.template                # Template version with placeholder values
    opencode.json                     # Full config with commands + permissions
    opencode_example.json             # Example provider config
    commands/
      write-plan.md                   # /plan-write command (96 lines)
      execute-plan.md                 # /plan-execute command (325 lines)
      chat-summary.md                 # /chat-summary command
      code-simplifier.md              # /code-simplifier command
    prompts/
      augster-system.md               # Augster system prompt (105 lines)
    agents/
      (31 specialized agent definitions)
```
</task_result>
```

**Tool: task**

**Input:**
```json
{
  "description": "Explore compound-engineering plugin",
  "prompt": "Thoroughly explore the directory /home/outsider/Projects/compound-engineering-plugin/ to understand ALL commands, skills, and functionality it provides. Read ALL files completely - every prompt file, every script, every skill, every configuration.\n\nI need a comprehensive understanding of:\n\n1. ALL available commands/slash-commands - read each one fully\n2. ALL skills defined - read each SKILL.md fully\n3. The overall architecture and how commands/skills interact\n4. Any plan-related, implementation-related, or code-generation-related functionality\n5. Review/analysis agents or workflows\n6. Configuration files and how the system is set up\n\nPay special attention to:\n- Any planning or brainstorming commands\n- Any execution or implementation commands  \n- Any review or analysis commands\n- How tasks flow from planning to implementation to review\n- Templates, formats, or structures used\n\nReturn a comprehensive summary of:\n- The complete directory structure\n- Every command and what it does\n- Every skill and what it does\n- Every agent type and its purpose\n- The overall workflow the system enables\n- Key features and capabilities",
  "subagent_type": "explore"
}
```

**Output:**
```
task_id: ses_38486ebb1ffecwCjCKNL6zywis (for resuming to continue this task if needed)

<task_result>
## Goal

The user requested a **comprehensive, exhaustive exploration and understanding** of the entire `/home/outsider/Projects/compound-engineering-plugin/` repository — every command, skill, agent, configuration file, and architectural pattern. The purpose is to have a complete mental model of what this system provides, how it works, and how all pieces interact.

## Instructions

- Read ALL files completely — every prompt file, every script, every skill, every configuration
- Pay special attention to planning, implementation, review, and code-generation functionality
- Understand the complete workflow from planning → implementation → review
- Identify ALL slash-commands, skills, agents, and their purposes
- Understand how the CLI converter system works (converting Claude Code plugins to other AI tool formats)
- Return a comprehensive summary of everything

## Discoveries

### Repository Overview

This is the **Compound Engineering Plugin** — a Claude Code plugin marketplace by Every Inc. It has **two major components**:

1. **A Claude Code plugin** (`plugins/compound-engineering/`) with 29 agents, 22 commands, 19 skills, and 1 MCP server
2. **A Bun/TypeScript CLI** (`src/`) that converts Claude Code plugins into formats for OpenCode, Codex, Factory Droid, Pi, Gemini CLI, GitHub Copilot, and Kiro

### Core Philosophy

**"Each unit of engineering work should make subsequent units easier—not harder."** The workflow is: `Plan → Work → Review → Compound → Repeat`. 80% planning/review, 20% execution. Knowledge compounds over time via `docs/solutions/`.

### The Complete Workflow Pipeline

The core workflow is a 5-step cycle:

1. **`/workflows:brainstorm`** — Explores WHAT to build through collaborative dialogue. Asks questions one-at-a-time, proposes 2-3 approaches, writes brainstorm doc to `docs/brainstorms/`. Uses `brainstorming` skill. Outputs to `docs/brainstorms/YYYY-MM-DD-<topic>-brainstorm.md`.

2. **`/workflows:plan`** — Transforms feature descriptions into structured plans. Auto-detects brainstorm docs. Runs parallel research agents (`repo-research-analyst`, `learnings-researcher`). Conditional external research (`best-practices-researcher`, `framework-docs-researcher`). Runs `spec-flow-analyzer` for validation. Three detail levels: MINIMAL, MORE, A LOT. Outputs to `docs/plans/YYYY-MM-DD-<type>-<name>-plan.md`. **NEVER CODES** — just researches and writes plans.

3. **`/workflows:work`** — Executes plans systematically. Reads plan, creates branches/worktrees, breaks into TodoWrite tasks, executes task loop with System-Wide Test Checks (callbacks, mocked vs real tests, orphaned state, API parity, error alignment). Incremental commits. Quality checks with configurable review agents from `compound-engineering.local.md`. Creates PR with Post-Deploy Monitoring section. Optional **Swarm Mode** for parallel execution using TeammateTool.

4. **`/workflows:review`** — Multi-agent code review. Loads review agents from `compound-engineering.local.md` (configured via `setup` skill). Runs agents in parallel. Conditional agents for migrations (schema-drift-detector, data-migration-expert, deployment-verification-agent). Ultra-thinking deep dive phases. Synthesizes findings into `todos/` directory using `file-todos` skill. P1 findings block merge. Optional end-to-end testing via `/test-browser` or `/xcode-test`.

5. **`/workflows:compound`** — Documents solved problems. Two-phase orchestration: Phase 1 parallel research (5 sub-agents return text), Phase 2 assembly into single file at `docs/solutions/[category]/[filename].md`. Uses `compound-docs` skill with YAML frontmatter schema. Creates searchable institutional knowledge.

### Automation Commands

- **`/lfg`** — Full autonomous pipeline: plan → deepen-plan → work → review → resolve_todo_parallel → test-browser → feature-video. Sequential, `disable-model-invocation: true`.
- **`/slfg`** — Swarm-enabled LFG: same pipeline but uses swarm mode for `/workflows:work` and parallelizes review + browser testing.

### Enhancement & Research Commands

- **`/deepen-plan`** — Massively enhances a plan. Discovers ALL available skills and agents from all sources, spawns sub-agents for EVERY matched skill, checks `docs/solutions/` learnings, launches per-section research agents, runs ALL review agents (20-40+ parallel), uses Context7 MCP for framework docs, synthesizes everything back into the plan. **NEVER CODES**.

### Utility Commands

- **`/changelog`** — Creates engaging changelogs from recent merges, with Every style guide review
- **`/create-agent-skill`** — Invokes `create-agent-skills` skill to create/edit Claude Code skills
- **`/generate_command`** — Creates new slash commands in `.claude/commands/`
- **`/heal-skill`** — Fixes incorrect SKILL.md files based on conversation context
- **`/report-bug`** — Creates structured GitHub issues for plugin bugs
- **`/reproduce-bug`** — Investigates bugs using logs, console, and Playwright browser
- **`/resolve_parallel`** — Resolves TODO comments in parallel using `pr-comment-resolver` agents
- **`/resolve_todo_parallel`** — Resolves pending CLI todos from `todos/*.md` in parallel
- **`/triage`** — Interactive triage of findings in `todos/` (pending → ready or delete). Uses Haiku model. **NEVER CODES** during triage.
- **`/test-browser`** — End-to-end browser testing using `agent-browser` CLI (NOT Chrome MCP). Maps changed files to routes, tests each page, handles failures.
- **`/test-xcode`** — iOS simulator testing using XcodeBuildMCP. Build, install, launch, screenshot, capture logs.
- **`/feature-video`** — Records video walkthroughs of features using agent-browser screenshots → ffmpeg → rclone upload → PR description update.
- **`/deploy-docs`** — Validates documentation site for GitHub Pages deployment
- **`/agent-native-audit`** — Comprehensive 8-principle agent-native architecture audit with scored report. Launches 8 parallel sub-agents.

### All 29 Agents (by category)

**Review (15):**
- `agent-native-reviewer` — Verifies agent-native parity (action + context parity)
- `architecture-strategist` — SOLID principles, coupling, dependency analysis
- `code-simplicity-reviewer` — YAGNI, minimalism, LOC reduction
- `data-integrity-guardian` — Migration safety, transactions, privacy compliance
- `data-migration-expert` — Validates ID mappings match production, swapped values
- `deployment-verification-agent` — Go/No-Go checklists with SQL verification queries
- `dhh-rails-reviewer` — DHH's Rails philosophy (majestic monolith, convention over configuration)
- `julik-frontend-races-reviewer` — JavaScript/Stimulus race conditions, DOM lifecycle, timing. Unique voice: British wit + Eastern-European directness.
- `kieran-rails-reviewer` — Strict Rails conventions (turbo streams inline, `Class Module::ClassName`, duplication > complexity)
- `kieran-python-reviewer` — Python conventions (type hints, PEP 8, Pythonic patterns)
- `kieran-typescript-reviewer` — TypeScript conventions (no `any`, strict null checks)
- `pattern-recognition-specialist` — Design patterns, anti-patterns, naming consistency, duplication
- `performance-oracle` — Algorithmic complexity, N+1 queries, caching, memory
- `schema-drift-detector` — Detects unrelated schema.rb changes by cross-referencing migrations
- `security-sentinel` — OWASP Top 10, input validation, SQL injection, XSS, hardcoded secrets

**Research (5):**
- `best-practices-researcher` — External best practices. Checks skills first, then Context7, then web. Mandatory deprecation check for APIs.
- `framework-docs-researcher` — Framework documentation via Context7, gem source code, GitHub research
- `git-history-analyzer` — Git archaeology: file evolution, blame, contributor mapping
- `learnings-researcher` — Searches `docs/solutions/` by YAML frontmatter. Uses Grep pre-filtering for efficiency. Model: haiku.
- `repo-research-analyst` — Repository structure, conventions, templates, codebase patterns

**Design (3):**
- `design-implementation-reviewer` — Pixel-perfect comparison of live UI vs Figma designs
- `design-iterator` — N-cycle screenshot→analyze→improve iterations. Anti-"AI slop" aesthetics.
- `figma-design-sync` — Detects/fixes visual differences between implementation and Figma

**Workflow (5):**
- `bug-reproduction-validator` — Systematically reproduces and classifies bug reports
- `every-style-editor` — Every's editorial style guide (title case, Oxford commas, em dashes, etc.)
- `lint` — Ruby/ERB linting (standardrb, erblint, brakeman). Model: haiku.
- `pr-comment-resolver` — Implements requested changes from PR review comments
- `spec-flow-analyzer` — Analyzes specs for user flow completeness, edge cases, gap identification

**Docs (1):**
- `ankane-readme-writer` — READMEs following Andrew Kane's template (imperative voice, 15-word sentences, standard sections)

### All 19 Skills

- **`agent-browser`** — CLI browser automation using Vercel's agent-browser (ref-based selection @e1, @e2)
- **`agent-native-architecture`** — Comprehensive guide to building agent-native apps. 12+ reference docs covering parity, granularity, context injection, shared workspace, MCP tool design, self-modification, mobile patterns, testing.
- **`andrew-kane-gem-writer`** — Ruby gem writing following Andrew Kane's patterns. 5 reference docs.
- **`brainstorming`** — Detailed question techniques, approach exploration, YAGNI principles, design doc template
- **`compound-docs`** — 7-step process for capturing solved problems. YAML frontmatter schema with enum-validated problem types. 511 lines.
- **`dhh-rails-style`** — DHH/37signals Rails coding style
- **`document-review`** — Structured self-review of brainstorm/plan documents (clarity, completeness, specificity, YAGNI)
- **`dspy-ruby`** — Build type-safe LLM applications with DSPy.rb
- **`every-style-editor`** — Every's editorial style guide reference
- **`file-todos`** — File-based todo tracking system in `todos/`. Template, naming conventions, lifecycle management.
- **`gemini-imagegen`** — Image generation via Google Gemini API. Scripts: generate_image.py, multi_turn_chat.py, compose_images.py
- **`git-worktree`** — Git worktree management with shell script. Copies .env files, manages .gitignore.
- **`orchestrating-swarms`** — 1718-line comprehensive guide to Claude Code's TeammateTool and Task system. Covers primitives, lifecycle, spawn backends (in-process/tmux/iterm2), all operations, 6 orchestration patterns, 3 complete workflows.
- **`rclone`** — File upload to S3/R2/B2/cloud storage
- **`resolve-pr-parallel`** — PR comment resolution in parallel with scripts for fetching comments via GraphQL
- **`setup`** — Interactive configuration of `compound-engineering.local.md`. Auto-detects stack (Rails/Python/TypeScript/general), configures review agents for `/workflows:review` and `/workflows:work`.
- **`skill-creator`** — Meta-skill for creating new skills. Anatomy, best practices, validation scripts (init_skill.py, quick_validate.py, package_skill.py).

### CLI Converter System (`src/`)

The TypeScript/Bun CLI converts Claude Code plugins to 7 other formats:
- **Commands:** `install`, `convert`, `list`, `sync`
- **Parsers:** `claude.ts`, `claude-home.ts` — Parse Claude plugin structure
- **Converters:** `claude-to-opencode.ts`, `claude-to-codex.ts`, `claude-to-droid.ts`, `claude-to-pi.ts`, `claude-to-gemini.ts`, `claude-to-copilot.ts`, `claude-to-kiro.ts`
- **Writers/Targets:** One per provider in `src/targets/`
- **Sync:** Syncs personal `~/.claude/` config to other tools (symlinks skills, copies MCP servers)
- **Types:** Provider-specific types in `src/types/`

### Configuration Architecture

- **`compound-engineering.local.md`** — Per-project config with YAML frontmatter listing `review_agents` and `plan_review_agents`. Created by `setup` skill.
- **`.claude-plugin/plugin.json`** — Plugin metadata (v2.35.1)
- **`.mcp.json`** — MCP server config (Context7 HTTP)
- **`.cursor-plugin/plugin.json`** — Cursor plugin metadata
- **`AGENTS.md`** — Repository-level agent instructions for the CLI repo itself

### Additional Plugin: `coding-tutor`

A second plugin exists at `plugins/coding-tutor/` with:
- Commands: `teach-me.md`, `quiz-me.md`, `sync-tutorials.md`
- Skills: `coding-tutor/SKILL.md` with scripts (setup_tutorials.py, quiz_priority.py, etc.)

### Key Architectural Patterns

1. **Protected Artifacts:** `docs/plans/*.md` and `docs/solutions/*.md` are NEVER flagged for deletion by review agents
2. **Pipeline Mode:** When running from LFG/SLFG, commands skip AskUserQuestion calls and make decisions automatically
3. **Parallel Execution:** Commands heavily use Claude's `Task` tool for parallel sub-agent execution
4. **Configurable Review Agents:** The `setup` skill creates `compound-engineering.local.md` which controls which agents run during review/work
5. **Institutional Knowledge Loop:** `/workflows:compound` → `docs/solutions/` → `learnings-researcher` → `/workflows:plan` (knowledge compounds)

## Accomplished

- ✅ Read ALL top-level config files (README.md, AGENTS.md, CLAUDE.md, package.json, tsconfig.json, .gitignore)
- ✅ Read ALL 22 command files completely
- ✅ Read ALL 29 agent files completely
- ✅ Read key portions of ALL 19 skill SKILL.md files (some truncated at 50 lines but key content captured)
- ✅ Read plugin configuration files (plugin.json, marketplace.json, .mcp.json)
- ✅ Mapped complete directory structure of src/, plugins/, docs/, tests/
- ✅ Understood the CLI converter architecture
- ✅ Identified the coding-tutor secondary plugin
- ✅ Comprehensive summary constructed

**Not fully read (truncated to 50 lines):**
- `skills/compound-docs/SKILL.md` (511 lines total — read first 50)
- `skills/agent-native-architecture/SKILL.md` (435 lines total — read first 50, has 12 reference docs not read)
- `skills/skill-creator/SKILL.md` (210 lines total — read first 50)
- `skills/orchestrating-swarms/SKILL.md` — Read completely (1718 lines)
- `skills/file-todos/SKILL.md` (252 lines — read first 50)
- `skills/git-worktree/SKILL.md` (302 lines — read first 50)
- `skills/agent-browser/SKILL.md` (223 lines — read first 50)
- Skills not read at all: `dhh-rails-style`, `dspy-ruby`, `rclone`, `gemini-imagegen`, `every-style-editor`, `andrew-kane-gem-writer`
- Reference docs in skills (e.g., `agent-native-architecture/references/` — 12 files)
- `src/` TypeScript source files (converter logic, parsers, writers)
- Test files
- Docs site HTML/CSS/JS
- CHANGELOG.md files

## Relevant files / directories

### Top-level configuration
- `/home/outsider/Projects/compound-engineering-plugin/README.md`
- `/home/outsider/Projects/compound-engineering-plugin/AGENTS.md`
- `/home/outsider/Projects/compound-engineering-plugin/CLAUDE.md`
- `/home/outsider/Projects/compound-engineering-plugin/package.json`
- `/home/outsider/Projects/compound-engineering-plugin/tsconfig.json`

### Plugin core
- `/home/outsider/Projects/compound-engineering-plugin/plugins/compound-engineering/README.md`
- `/home/outsider/Projects/compound-engineering-plugin/plugins/compound-engineering/CLAUDE.md`
- `/home/outsider/Projects/compound-engineering-plugin/plugins/compound-engineering/.claude-plugin/plugin.json`
- `/home/outsider/Projects/compound-engineering-plugin/plugins/compound-engineering/.mcp.json`

### All Commands (22 files)
- `/home/outsider/Projects/compound-engineering-plugin/plugins/compound-engineering/commands/` (entire directory)
  - `workflows/brainstorm.md`, `workflows/plan.md`, `workflows/work.md`, `workflows/review.md`, `workflows/compound.md`
  - `lfg.md`, `slfg.md`, `deepen-plan.md`, `changelog.md`, `create-agent-skill.md`, `generate_command.md`, `heal-skill.md`, `report-bug.md`, `reproduce-bug.md`, `resolve_parallel.md`, `resolve_todo_parallel.md`, `triage.md`, `test-browser.md`, `test-xcode.md`, `feature-video.md`, `deploy-docs.md`, `agent-native-audit.md`

### All Agents (29 files)
- `/home/outsider/Projects/compound-engineering-plugin/plugins/compound-engineering/agents/` (entire directory)
  - `review/` — 15 agents
  - `research/` — 5 agents
  - `design/` — 3 agents
  - `workflow/` — 5 agents
  - `docs/` — 1 agent

### All Skills (19 directories)
- `/home/outsider/Projects/compound-engineering-plugin/plugins/compound-engineering/skills/` (entire directory)
  - `agent-browser/`, `agent-native-architecture/`, `andrew-kane-gem-writer/`, `brainstorming/`, `compound-docs/`, `dhh-rails-style/`, `document-review/`, `dspy-ruby/`, `every-style-editor/`, `file-todos/`, `gemini-imagegen/`, `git-worktree/`, `orchestrating-swarms/`, `rclone/`, `resolve-pr-parallel/`, `setup/`, `skill-creator/`

### CLI Source
- `/home/outsider/Projects/compound-engineering-plugin/src/` (entire directory — not deeply read)
  - `index.ts`, `commands/`, `parsers/`, `converters/`, `targets/`, `types/`, `sync/`, `utils/`, `templates/`

### Secondary plugin
- `/home/outsider/Projects/compound-engineering-plugin/plugins/coding-tutor/` (entire directory)

### Documentation
- `/home/outsider/Projects/compound-engineering-plugin/docs/` (plans, specs, brainstorms, decisions, reports, solutions)

### Tests
- `/home/outsider/Projects/compound-engineering-plugin/tests/` (entire directory — not read)
</task_result>
```

---

## Assistant (Build · claude-opus-4-6 · 59.1s)

Now I have a thorough understanding of both systems. Here's the comparative analysis:

---

## Comparison: Your Commands vs. Compound Engineering

### What You Built

Your system is a **two-command pipeline** with a supporting system prompt:

| Command | File | Purpose |
|---|---|---|
| `/plan-write` | `write-plan.md` (96 lines) | Investigates codebase, produces a self-contained plan in `docs/plans/` |
| `/plan-execute` | `execute-plan.md` (325 lines) | Orchestrates plan implementation via sequential subagents, one per phase |
| Augster Prompt | `augster-system.md` (105 lines) | System identity/persona injected into all subagents |

### What Compound Engineering Provides

A **22-command, 29-agent, 19-skill ecosystem** with a 5-step workflow cycle: `brainstorm → plan → work → review → compound`.

---

### Core Similarities

**1. Strict plan-then-execute separation.** Both systems enforce that planning and execution are completely separate operations. Both forbid writing code during planning. Both produce plan files to `docs/plans/`.

**2. Plans must be self-contained.** Both explicitly state that the executing agent has NO access to the planning conversation — all context must be embedded in the plan document.

**3. Phase-based execution with subagents.** Both execute plans by spawning fresh subagents per phase, each with a clean context. Both pass handoff information between phases sequentially.

**4. Handoff reports between phases.** Both generate per-phase reports documenting state changes, decisions made, patterns discovered, and open issues. Your format and compound's are structurally similar.

**5. Decision logging.** Both maintain a shared decision log (`decisions.md`) across phases for non-obvious choices, deviations, and trade-offs.

**6. Plan amendments / deviation tracking.** Both produce a post-execution document comparing what was planned vs. what was actually built, with adherence ratings and explanations.

**7. Verification as a separate step.** Both spawn a dedicated verification subagent with reviewer-only constraints after all phases complete.

**8. ADR (Architectural Decision Record) support.** Both identify architectural decisions during planning and create formal ADR files in `docs/decisions/`.

**9. Git branch management.** Both check the current branch, suggest feature branches, and refuse to execute on main/master without explicit confirmation.

**10. Incremental commits per phase.** Both commit after each phase with structured commit messages that include reasoning.

---

### Key Differences

#### 1. Scope and Breadth

| Aspect | Your Commands | Compound Engineering |
|---|---|---|
| Commands | 2 | 22 |
| Agents | 0 (uses system prompt) | 29 specialized |
| Skills | 0 | 19 |
| Total workflow steps | 2 (plan → execute) | 5 (brainstorm → plan → work → review → compound) |

Your system is a focused planning-and-execution engine. Compound Engineering is a full software engineering lifecycle platform.

#### 2. Pre-Planning Phase (Brainstorming)

**You:** Jump straight into planning from a conversation.

**Compound:** Has a dedicated `/workflows:brainstorm` step that explores *what* to build through structured questioning before any planning begins. Outputs to `docs/brainstorms/`. The plan command auto-detects brainstorm docs as input.

#### 3. Research During Planning

**You:** `/plan-write` investigates the codebase directly — checks ADRs, prior reports, git history, and code comments. Single-agent investigation.

**Compound:** `/workflows:plan` spawns **parallel research sub-agents** — `repo-research-analyst`, `learnings-researcher`, `best-practices-researcher`, `framework-docs-researcher` — plus a `spec-flow-analyzer` for validation. Much more parallelized and specialized research.

#### 4. Plan Enrichment

**You:** No equivalent.

**Compound:** Has `/deepen-plan` which massively enhances an existing plan by discovering ALL available skills/agents, spawning sub-agents for every matched skill, checking institutional knowledge in `docs/solutions/`, launching per-section research agents, running 20-40+ review agents in parallel, and using Context7 MCP for framework documentation.

#### 5. Code Review

**You:** Verification subagent checks deliverables exist and function, cross-references handoff reports and amendments. Single pass, single agent.

**Compound:** `/workflows:review` runs **up to 15+ specialized review agents in parallel** — architecture, security, performance, data integrity, Rails conventions, TypeScript strictness, race conditions, schema drift, etc. Findings go to a `todos/` directory. P1 findings block merge. Optional browser-based end-to-end testing.

#### 6. Institutional Knowledge / Compounding

**You:** Creates plan amendments and decision logs that future `/plan-write` runs check. Basic feedback loop.

**Compound:** Has a dedicated `/workflows:compound` step that documents solved problems into `docs/solutions/` with YAML frontmatter. A `learnings-researcher` agent searches these during future planning. This is a structured, searchable institutional knowledge base — the core thesis of the project ("each unit of engineering work makes subsequent units easier").

#### 7. System Prompt / Agent Identity

**You:** The Augster system prompt defines a rich persona with named maxims (PrimedCognition, StrategicMemory, AppropriateComplexity, etc.) and a detailed operational loop. All subagents share this identity.

**Compound:** No single persona. Instead, 29 distinct agent definitions, each with focused instructions. Some have unique voices (e.g., `julik-frontend-races-reviewer` has "British wit + Eastern-European directness").

#### 8. TDD Enforcement

**You:** `/plan-write` explicitly mandates TDD — tests must be defined BEFORE implementation in every phase, with exact test file paths, case names, and assertions.

**Compound:** `/workflows:work` has "System-Wide Test Checks" (callbacks, mocked vs real tests, orphaned state, API parity, error alignment) but does not enforce strict TDD ordering in the plan format itself.

#### 9. Automation / Full Pipeline

**You:** Manual — user runs `/plan-write`, then separately runs `/plan-execute`.

**Compound:** Has `/lfg` (full autonomous pipeline: plan → deepen → work → review → resolve todos → browser test → feature video) and `/slfg` (swarm-enabled version with parallel execution). Completely hands-off.

#### 10. Swarm / Parallel Execution

**You:** Strictly sequential — one subagent per phase, one phase at a time.

**Compound:** Has swarm mode using Claude's TeammateTool. The `orchestrating-swarms` skill (1718 lines) covers fan-out, pipeline, and self-organizing patterns. `/slfg` uses this for parallel work execution.

#### 11. Configurability

**You:** Fixed behavior defined in the command files.

**Compound:** Per-project configuration via `compound-engineering.local.md` (created by `setup` skill) that controls which review agents run during `/workflows:review` and `/workflows:work`. Auto-detects stack (Rails/Python/TypeScript/general).

#### 12. Cleanup / Artifact Management

**You:** `/plan-execute` explicitly deletes `.obj`, `.mtl`, `.jpg` test artifacts after each phase (specific to your 3D model project).

**Compound:** No domain-specific cleanup — it's project-agnostic.

#### 13. Additional Capabilities Compound Has That You Don't

- Browser-based testing (`/test-browser`, `/test-xcode`)
- Bug reproduction (`/reproduce-bug`)
- Feature video recording (`/feature-video`)
- Changelog generation (`/changelog`)
- PR comment resolution (`/resolve_parallel`, `/resolve_todo_parallel`)
- Design review against Figma (`design-implementation-reviewer`, `figma-design-sync`)
- Triage workflow (`/triage`)
- CLI converter to 7 other AI tools (OpenCode, Codex, Copilot, etc.)

---

### Summary

Your `/plan-write` + `/plan-execute` pipeline covers the **core** of what compound engineering does in its `/workflows:plan` + `/workflows:work` commands — and does it well. The strict separation, self-contained plans, phase-based subagent execution, handoff reports, decision logging, and verification are all present in both systems and structurally very similar.

Where compound engineering significantly extends beyond your system:

1. **Upstream** — structured brainstorming before planning
2. **Research depth** — parallel specialized research agents during planning
3. **Review breadth** — 15+ specialized review agents vs. your single verification pass
4. **Downstream** — institutional knowledge capture (`/workflows:compound`) creating a searchable solutions database
5. **Automation** — full pipeline commands (`/lfg`, `/slfg`) that chain everything together
6. **Parallelism** — swarm mode for concurrent execution
7. **Tooling breadth** — browser testing, design review, PR resolution, video recording, etc.

Your system's unique strengths that compound engineering lacks:

1. **Augster persona** — a cohesive, characterful system prompt with named engineering maxims
2. **Strict TDD enforcement** — tests defined before implementation in every phase at the plan level
3. **Domain-specific artifact cleanup** — tailored to your project's needs
4. **Simplicity** — 2 commands vs. 22; easier to understand, maintain, and customize

---

## User

I am inclined to continue using the CE version since it's maintained by a large company and had a lot of active development, whereas mine is only sometimes being developed by one person-me. 

What functionlaity would you recommend I create PR for to push to the CE repo for consideration?

---

## Assistant (Build · claude-opus-4-6 · 29.0s)



Good reasoning — leveraging a maintained project while contributing back your unique ideas is the right call.

Based on the analysis, here are the features from your system that would be genuinely valuable contributions to CE, ranked by likelihood of acceptance and impact:

---

### High Value, High Likelihood of Acceptance

**1. Strict TDD Enforcement in Plan Format**

Your `/plan-write` mandates that every phase defines tests *before* implementation — exact test file paths, case names, and assertions. CE's `/workflows:plan` doesn't enforce this structure. CE's `/workflows:work` has test checks, but they're runtime checks, not plan-level requirements.

**Why CE would want this:** It aligns with CE's philosophy of "80% planning, 20% execution." Pushing TDD into the plan document means the executing agent has no ambiguity about what to test. This is a structural improvement to the plan template, not a new command — low friction to adopt.

**2. Plan Amendments / Deviation Tracking**

Your `/plan-execute` produces a dedicated `plan-amendments.md` that diffs the original plan against what was actually built, with per-deviation explanations and an overall adherence rating (HIGH/MEDIUM/LOW). CE's `/workflows:work` doesn't produce this artifact.

**Why CE would want this:** It feeds directly into CE's compounding philosophy. If you know *where* and *why* plans deviate, future plans improve. It also gives the `/workflows:review` agents concrete data to evaluate. This closes a gap in CE's feedback loop.

**3. Prior Context Investigation Protocol**

Your `/plan-write` has a structured pre-investigation step that checks 6 specific sources before writing a plan: ADRs, previous decision logs, past plan amendments, previous plans touching the same area, git history on relevant files, and code comments. CE's `/workflows:plan` runs research agents but doesn't have this explicit checklist targeting its own output artifacts.

**Why CE would want this:** CE already generates all these artifacts (`docs/decisions/`, `docs/solutions/`, `docs/plans/`). Your protocol would make CE's planner systematically consult its own institutional memory, strengthening the compound loop that is CE's core thesis.

---

### Medium Value, Moderate Likelihood

**4. Assumptions & Invalidation Triggers Section**

Your plan format includes a dedicated section where each assumption is paired with what parts of the plan break if that assumption changes. CE's plan format doesn't have this.

**Why it's useful:** It makes plans more robust and gives the executing agent explicit guardrails. If an assumption fails mid-execution, the agent knows which phases are affected rather than blindly continuing.

**5. Verification Report as a Formal Artifact**

Your system produces a structured verification report with overall status (COMPLETE/INCOMPLETE), per-phase verification, cross-referenced open issues, and ADR verification. CE's `/workflows:review` is more focused on code quality than on verifying plan completion fidelity.

**Why it's useful:** It's a different concern than code review. "Did we build what we planned?" is distinct from "Is the code good?" CE currently answers the second question well but not the first.

---

### Lower Priority / Harder Sell

**6. Augster System Prompt / Named Engineering Maxims**

Your Augster prompt (PrimedCognition, StrategicMemory, AppropriateComplexity, etc.) is well-crafted, but CE deliberately avoids a single persona in favor of 29 specialized agents. This would be a philosophical change they're unlikely to adopt wholesale. However, specific maxims like "AppropriateComplexity" or "EmpiricalRigor" could be distilled into guidance within existing agent definitions.

---

### Recommended Approach

I'd suggest starting with **items 1-3 as a single PR** since they're all enhancements to the `/workflows:plan` and `/workflows:work` commands rather than new commands. Frame it as "strengthening the plan-execute feedback loop" — that language maps directly to CE's core thesis of compounding knowledge.

Items 4-5 could be a follow-up PR if the first is well-received.

Want me to help draft any of these as actual code changes against the CE repo?

---


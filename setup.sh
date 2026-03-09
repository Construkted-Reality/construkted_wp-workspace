#!/usr/bin/env bash
#
# setup.sh — Clone Construkted sub-repos into the workspace root.
#
# Usage:
#   ./setup.sh          Clone/update all repos using SSH (default)
#   ./setup.sh --https  Clone/update all repos using HTTPS
#
# Prerequisites:
#   - git installed and configured
#   - SSH key added to GitHub (for SSH mode) or credentials configured (for HTTPS)
#
# This script is idempotent: running it again will skip repos that already exist
# and offer to update them instead.

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────

GITHUB_ORG="Construkted-Reality"

# repo-name | target-folder | default-branch
REPOS=(
  "construkted_api|construkted_api|master"
  "construkted.js|construkted.js|develop"
  "construkted.uploadjs|construkted.uploadjs|main"
  "construkted_reality_v1.x|construkted_reality_v1.x|develop"
)

# ── Parse arguments ─────────────────────────────────────────────────────────

USE_HTTPS=false
UPDATE_EXISTING=false

for arg in "$@"; do
  case "$arg" in
    --https) USE_HTTPS=true ;;
    --update) UPDATE_EXISTING=true ;;
    --help|-h)
      echo "Usage: ./setup.sh [--https] [--update]"
      echo ""
      echo "  --https   Use HTTPS URLs instead of SSH"
      echo "  --update  Pull latest changes for repos that already exist"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: ./setup.sh [--https] [--update]"
      exit 1
      ;;
  esac
done

# ── Helpers ──────────────────────────────────────────────────────────────────

build_url() {
  local repo_name="$1"
  if [ "$USE_HTTPS" = true ]; then
    echo "https://github.com/${GITHUB_ORG}/${repo_name}.git"
  else
    echo "git@github.com:${GITHUB_ORG}/${repo_name}.git"
  fi
}

log_info() {
  echo "[INFO]  $1"
}

log_skip() {
  echo "[SKIP]  $1"
}

log_ok() {
  echo "[OK]    $1"
}

log_error() {
  echo "[ERROR] $1" >&2
}

# ── Verify we're in the workspace root ───────────────────────────────────────

if [ ! -f ".gitignore" ] || [ ! -d ".git" ]; then
  log_error "This script must be run from the workspace root directory (where .git and .gitignore exist)."
  exit 1
fi

# ── Main ─────────────────────────────────────────────────────────────────────

echo ""
echo "Construkted Workspace Setup"
echo "==========================="
echo ""

errors=0

for entry in "${REPOS[@]}"; do
  IFS='|' read -r repo_name folder default_branch <<< "$entry"
  url=$(build_url "$repo_name")

  if [ -d "$folder/.git" ]; then
    if [ "$UPDATE_EXISTING" = true ]; then
      log_info "${folder}: already exists, updating..."
      if git -C "$folder" fetch origin && git -C "$folder" pull --ff-only 2>/dev/null; then
        log_ok "${folder}: updated successfully"
      else
        log_error "${folder}: pull failed (you may have local changes or diverged history)"
        errors=$((errors + 1))
      fi
    else
      log_skip "${folder}: already exists (use --update to pull latest)"
    fi
  elif [ -d "$folder" ]; then
    log_error "${folder}: directory exists but is not a git repo. Remove it and re-run."
    errors=$((errors + 1))
  else
    log_info "${folder}: cloning from ${url}..."
    if git clone "$url" "$folder"; then
      git -C "$folder" checkout "$default_branch" 2>/dev/null || true
      log_ok "${folder}: cloned and checked out '${default_branch}'"
    else
      log_error "${folder}: clone failed. Check your access and network connection."
      errors=$((errors + 1))
    fi
  fi
done

echo ""

if [ "$errors" -gt 0 ]; then
  echo "Setup completed with ${errors} error(s). See above for details."
  exit 1
else
  echo "Setup complete. All repos are in place."
  echo ""
  echo "Next steps:"
  echo "  - Open construkted.code-workspace in VS Code or Cursor"
  echo "  - Or open this folder directly in your editor"
  echo ""
fi

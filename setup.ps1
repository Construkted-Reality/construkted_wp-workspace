#Requires -Version 5.1
<#
.SYNOPSIS
    Clone Construkted sub-repos into the workspace root.

.DESCRIPTION
    This script clones the 4 Construkted sub-repositories into the current
    workspace directory. It is idempotent: running it again will skip repos
    that already exist unless -Update is specified.

.PARAMETER UseHttps
    Clone using HTTPS URLs instead of SSH (default).

.PARAMETER Update
    Pull latest changes for repos that already exist.

.EXAMPLE
    .\setup.ps1
    Clone all repos using SSH.

.EXAMPLE
    .\setup.ps1 -UseHttps
    Clone all repos using HTTPS.

.EXAMPLE
    .\setup.ps1 -Update
    Pull latest changes for existing repos.
#>

param(
    [switch]$UseHttps,
    [switch]$Update
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Configuration ────────────────────────────────────────────────────────────

$GitHubOrg = "Construkted-Reality"

$Repos = @(
    @{ Name = "construkted_api";          Folder = "construkted_api";          Branch = "master"  }
    @{ Name = "construkted.js";           Folder = "construkted.js";           Branch = "develop" }
    @{ Name = "construkted.uploadjs";     Folder = "construkted.uploadjs";     Branch = "main"    }
    @{ Name = "construkted_reality_v1.x"; Folder = "construkted_reality_v1.x"; Branch = "develop" }
)

# ── Helpers ──────────────────────────────────────────────────────────────────

function Get-RepoUrl {
    param([string]$RepoName)
    if ($UseHttps) {
        return "https://github.com/$GitHubOrg/$RepoName.git"
    } else {
        return "git@github.com:${GitHubOrg}/${RepoName}.git"
    }
}

function Write-LogInfo  { param([string]$Msg) Write-Host "[INFO]  $Msg" }
function Write-LogSkip  { param([string]$Msg) Write-Host "[SKIP]  $Msg" -ForegroundColor Yellow }
function Write-LogOk    { param([string]$Msg) Write-Host "[OK]    $Msg" -ForegroundColor Green }
function Write-LogError { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

# ── Verify we're in the workspace root ───────────────────────────────────────

if (-not (Test-Path ".gitignore") -or -not (Test-Path ".git")) {
    Write-LogError "This script must be run from the workspace root directory (where .git and .gitignore exist)."
    exit 1
}

# Verify git is available
try {
    $null = git --version
} catch {
    Write-LogError "git is not installed or not in PATH."
    exit 1
}

# ── Main ─────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Construkted Workspace Setup"
Write-Host "==========================="
Write-Host ""

$errors = 0

foreach ($repo in $Repos) {
    $repoName = $repo.Name
    $folder   = $repo.Folder
    $branch   = $repo.Branch
    $url      = Get-RepoUrl -RepoName $repoName

    $gitDir = Join-Path $folder ".git"

    if (Test-Path $gitDir) {
        if ($Update) {
            Write-LogInfo "${folder}: already exists, updating..."
            try {
                git -C $folder fetch origin 2>&1 | Out-Null
                git -C $folder pull --ff-only 2>&1 | Out-Null
                Write-LogOk "${folder}: updated successfully"
            } catch {
                Write-LogError "${folder}: pull failed (you may have local changes or diverged history)"
                $errors++
            }
        } else {
            Write-LogSkip "${folder}: already exists (use -Update to pull latest)"
        }
    } elseif (Test-Path $folder) {
        Write-LogError "${folder}: directory exists but is not a git repo. Remove it and re-run."
        $errors++
    } else {
        Write-LogInfo "${folder}: cloning from ${url}..."
        try {
            git clone $url $folder 2>&1 | Out-Null
            git -C $folder checkout $branch 2>&1 | Out-Null
            Write-LogOk "${folder}: cloned and checked out '${branch}'"
        } catch {
            Write-LogError "${folder}: clone failed. Check your access and network connection."
            $errors++
        }
    }
}

Write-Host ""

if ($errors -gt 0) {
    Write-Host "Setup completed with $errors error(s). See above for details."
    exit 1
} else {
    Write-Host "Setup complete. All repos are in place."
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  - Open construkted.code-workspace in VS Code or Cursor"
    Write-Host "  - Or open this folder directly in your editor"
    Write-Host ""
}

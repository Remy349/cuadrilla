# Cuadrilla installer for OpenCode (Windows PowerShell 5.1+ / PowerShell 7+)
#   https://github.com/Remy349/cuadrilla
#
#   Global (all projects), from the web:
#     irm https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.ps1 | iex
#   Pin a version:
#     $env:CUADRILLA_REF = "v0.1.1"; irm https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.ps1 | iex
#
#   From a clone:
#     .\install.ps1                    # global
#     .\install.ps1 -Project .         # into .\.opencode (commit it with your team)
#     .\install.ps1 -Uninstall [-Project .]
#
#   Files are copied (symlinks need admin or Developer Mode on Windows),
#   so re-run the installer to update.
#
#   Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less files as ANSI.
param(
  [string]$Project,
  [string]$Ref,
  [switch]$Uninstall
)
$ErrorActionPreference = "Stop"

$RepoUrl  = if ($env:CUADRILLA_REPO) { $env:CUADRILLA_REPO } else { "https://github.com/Remy349/cuadrilla.git" }
if (-not $Ref) { $Ref = if ($env:CUADRILLA_REF) { $env:CUADRILLA_REF } else { "main" } }
$CloneDir = if ($env:CUADRILLA_HOME) { $env:CUADRILLA_HOME } else { Join-Path $env:LOCALAPPDATA "cuadrilla" }

# Judge git by its exit code. "Continue" is scoped to this function: under "Stop",
# Windows PowerShell 5.1 turns git's stderr into a terminating error in non-console hosts.
function Invoke-Git {
  $ErrorActionPreference = "Continue"
  & git @args
  if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed (exit code $LASTEXITCODE)" }
}

# --- Locate the source files (local clone or fetch) -------------------------
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "agents"))) {
  $Src = $PSScriptRoot
} else {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is required: install it from https://git-scm.com/download/win (or: winget install Git.Git)"
  }
  if (Test-Path (Join-Path $CloneDir ".git")) {
    Write-Host "Updating $CloneDir ($Ref)"
    Invoke-Git -C $CloneDir fetch --quiet --tags --force origin
    Invoke-Git -C $CloneDir checkout --quiet $Ref
    # A tag leaves HEAD detached and has nothing to pull; only branches are updated.
    # (stdout only: redirecting a native command's stderr throws under "Stop" in 5.1)
    $null = & git -C $CloneDir symbolic-ref -q HEAD
    if ($LASTEXITCODE -eq 0) { Invoke-Git -C $CloneDir pull --quiet --ff-only origin $Ref }
  } else {
    Write-Host "Cloning $RepoUrl ($Ref) into $CloneDir"
    Invoke-Git -c advice.detachedHead=false clone --quiet --branch $Ref $RepoUrl $CloneDir
  }
  $Src = $CloneDir
}

# --- Resolve target ----------------------------------------------------------
if ($Project) {
  $Target = Join-Path (Resolve-Path $Project).Path ".opencode"
} else {
  # OpenCode uses XDG paths on every OS: %USERPROFILE%\.config\opencode on Windows.
  $ConfigHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME ".config" }
  $Target = Join-Path $ConfigHome "opencode"
}

$Stamp = Get-Date -Format "yyyyMMddHHmmss"
$Count = 0
foreach ($Kind in @("agents", "commands")) {
  $Dir = Join-Path $Target $Kind
  if (-not $Uninstall) { New-Item -ItemType Directory -Force -Path $Dir | Out-Null }
  foreach ($File in Get-ChildItem (Join-Path $Src $Kind) -Filter *.md) {
    $Dest = Join-Path $Dir $File.Name
    if ($Uninstall) {
      if (Test-Path $Dest) { Remove-Item $Dest -Force; Write-Host "removed $Kind/$($File.Name)"; $Count++ }
      continue
    }
    # Back up anything that isn't already ours
    if ((Test-Path $Dest) -and ((Get-FileHash $Dest).Hash -ne (Get-FileHash $File.FullName).Hash)) {
      Move-Item $Dest "$Dest.bak.$Stamp"
      Write-Host "backed up existing $Kind/$($File.Name) -> $($File.Name).bak.$Stamp"
    }
    Copy-Item $File.FullName $Dest -Force
    $Count++
  }
}

if ($Uninstall) {
  Write-Host "Uninstalled $Count files from $Target"
} else {
  Write-Host "Installed $Count files into $Target (copy)"
  Write-Host ""
  Write-Host "Next steps:"
  Write-Host "  1. Restart OpenCode."
  Write-Host "  2. Press Tab until you see the 'cuadrilla' agent, then describe what you want."
  Write-Host "  3. Try:  /cuadrilla-plan add rate limiting to the login endpoint"
  Write-Host "  4. Optional: set per-agent models - see examples\opencode.json in $Src"
  Write-Host "  Update later by re-running the installer."
}

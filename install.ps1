# Cuadrilla installer for OpenCode (Windows PowerShell 5.1+ / PowerShell 7+)
#   https://github.com/Remy349/cuadrilla
#
#   Global (all projects), from the web - also adds the `cuadrilla` command to your PATH:
#     irm https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.ps1 | iex
#   Pin a version:
#     $env:CUADRILLA_REF = "v0.2.0"; irm https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.ps1 | iex
#
#   Update an existing install (same as `cuadrilla update`):
#     .\install.ps1 -Update [-Ref <tag|branch>] [-Project <dir>]
#
#   From a clone:
#     .\install.ps1                    # global
#     .\install.ps1 -Project .         # into .\.opencode (commit it with your team)
#     .\install.ps1 -Uninstall [-Project .]
#
#   -Format auto|v1|v2 picks the agent format (default auto): v1 is read by OpenCode 1.x
#   and 2.x; v2 is native to OpenCode 2.x and must not be used where OpenCode 1.x reads
#   the same config (1.x would ignore its permissions). auto = v2 only when OpenCode 2.x
#   is the only version found on PATH.
#
#   Files are copied (symlinks need admin or Developer Mode on Windows).
#
#   Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less files as ANSI.
param(
  [string]$Project,
  [string]$Ref,
  [string]$Format,
  [switch]$Update,
  [switch]$Uninstall,
  [switch]$NoPath
)
$ErrorActionPreference = "Stop"

$RepoUrl  = if ($env:CUADRILLA_REPO) { $env:CUADRILLA_REPO } else { "https://github.com/Remy349/cuadrilla.git" }
$RefOpt   = $Ref
if (-not $Ref) { $Ref = if ($env:CUADRILLA_REF) { $env:CUADRILLA_REF } else { "main" } }
$DataHome = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME ".local/share" }  # pwsh off Windows
$CloneDir = if ($env:CUADRILLA_HOME) { $env:CUADRILLA_HOME } else { Join-Path $DataHome "cuadrilla" }
if (-not $Format) { $Format = if ($env:CUADRILLA_FORMAT) { $env:CUADRILLA_FORMAT } else { "auto" } }
if ($Format -notin @("auto", "v1", "v2")) { throw "Invalid format '$Format' (expected auto, v1 or v2)" }
if ($env:CUADRILLA_NO_PATH) { $NoPath = $true }
$OnWindows = ($PSVersionTable.PSEdition -eq "Desktop") -or $IsWindows
$ManifestName = ".cuadrilla-manifest"

# Judge git by its exit code. "Continue" is scoped to this function: under "Stop",
# Windows PowerShell 5.1 turns git's stderr into a terminating error in non-console hosts.
function Invoke-Git {
  $ErrorActionPreference = "Continue"
  & git @args
  if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed (exit code $LASTEXITCODE)" }
}

function Get-Description([string]$Repo) {
  $ErrorActionPreference = "Continue"
  $Out = & git -C $Repo describe --tags --always 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $Out) { return "unknown" }
  return "$Out".Trim()
}

function Test-OnBranch([string]$Repo) {
  $ErrorActionPreference = "Continue"
  $null = & git -C $Repo symbolic-ref -q HEAD 2>$null
  return ($LASTEXITCODE -eq 0)
}

# Bring an existing clone up to date: -Ref if given; a branch is pulled; a detached
# HEAD (an install pinned to a release tag) moves to the newest release tag.
function Invoke-CloneUpdate([string]$Repo) {
  if (-not (Test-Path (Join-Path $Repo ".git"))) {
    throw "$Repo is not a git clone; reinstall with the one-line installer instead"
  }
  $From = Get-Description $Repo
  Invoke-Git -C $Repo fetch --quiet --tags --force origin
  if ($RefOpt) {
    Invoke-Git -C $Repo -c advice.detachedHead=false checkout --quiet $RefOpt
  } elseif (-not (Test-OnBranch $Repo)) {
    $Latest = @(& git -C $Repo tag -l "v[0-9]*" --sort=-v:refname) | Select-Object -First 1
    if ($Latest) { Invoke-Git -C $Repo -c advice.detachedHead=false checkout --quiet $Latest }
  }
  if (Test-OnBranch $Repo) {
    $Branch = "$(& git -C $Repo branch --show-current)".Trim()
    Invoke-Git -C $Repo pull --quiet --ff-only origin $Branch
  }
  $To = Get-Description $Repo
  if ($From -eq $To) { Write-Host "Cuadrilla is up to date ($To)" } else { Write-Host "Cuadrilla updated: $From -> $To" }
}

# Major version of an OpenCode binary on PATH, or $null.
function Get-OpenCodeMajor([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { return $null }
  $ErrorActionPreference = "Continue"
  $Out = (& $Name --version 2>$null | Out-String)
  if ($Out -match '(\d+)\.\d+') { return [int]$Matches[1] }
  return $null
}

function Get-Sha256([string]$Path) { return (Get-FileHash -Algorithm SHA256 $Path).Hash.ToLowerInvariant() }

# --- Locate the source files (local clone or fetch) -------------------------
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "agents"))) {
  $Src = $PSScriptRoot
  if ($Update) { Invoke-CloneUpdate $Src }
} else {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is required: install it from https://git-scm.com/download/win (or: winget install Git.Git)"
  }
  if ((Test-Path (Join-Path $CloneDir ".git")) -and $Update) {
    Invoke-CloneUpdate $CloneDir
  } elseif (Test-Path (Join-Path $CloneDir ".git")) {
    Write-Host "Updating $CloneDir ($Ref)"
    Invoke-Git -C $CloneDir fetch --quiet --tags --force origin
    Invoke-Git -C $CloneDir checkout --quiet $Ref
    # A tag leaves HEAD detached and has nothing to pull; only branches are updated.
    if (Test-OnBranch $CloneDir) { Invoke-Git -C $CloneDir pull --quiet --ff-only origin $Ref }
  } else {
    Write-Host "Cloning $RepoUrl ($Ref) into $CloneDir"
    Invoke-Git -c advice.detachedHead=false clone --quiet --branch $Ref $RepoUrl $CloneDir
  }
  $Src = $CloneDir
}

# After an update, the installer itself may have changed: run the updated one.
if ($Update) {
  $Forward = @{ Format = $Format }
  if ($Project) { $Forward.Project = $Project }
  if ($NoPath) { $Forward.NoPath = $true }
  & (Join-Path $Src "install.ps1") @Forward
  return
}

# --- Resolve target and format -------------------------------------------------
if ($Project) {
  $Target = Join-Path (Resolve-Path $Project).Path ".opencode"
} else {
  # OpenCode uses XDG paths on every OS: %USERPROFILE%\.config\opencode on Windows.
  $ConfigHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME ".config" }
  $Target = Join-Path $ConfigHome "opencode"
}

if ($Format -eq "auto" -and -not $Uninstall) {
  $HasV1 = $false; $HasV2 = $false
  foreach ($Bin in @("opencode", "opencode2")) {
    $Major = Get-OpenCodeMajor $Bin
    if ($null -eq $Major) { continue }
    if ($Major -le 1) { $HasV1 = $true } else { $HasV2 = $true }
  }
  $Format = if ($HasV2 -and -not $HasV1) { "v2" } else { "v1" }
  if (-not $HasV1 -and -not $HasV2) {
    Write-Host "OpenCode not found on PATH: installing the v1 format, which OpenCode 1.x and 2.x both read"
  }
}
$AgentsSrc = if ($Format -eq "v2") { Join-Path $Src "dist/v2/agents" } else { Join-Path $Src "agents" }
if (-not $Uninstall -and -not (Test-Path $AgentsSrc)) { throw "$AgentsSrc not found: this checkout has no $Format agents" }

# Previous install, from the manifest: "<sha256>  <kind>/<name>" lines.
$ManifestPath = Join-Path $Target $ManifestName
$Recorded = @{}
if (Test-Path $ManifestPath) {
  foreach ($Line in Get-Content $ManifestPath) {
    if (-not $Line -or $Line.StartsWith("#")) { continue }
    $Parts = $Line -split '\s+', 2
    if ($Parts.Count -eq 2) { $Recorded[$Parts[1]] = $Parts[0] }
  }
}

$BinDir = Join-Path $Src "bin"
$Stamp = Get-Date -Format "yyyyMMddHHmmss"
$Count = 0
$Installed = [ordered]@{}

# --- Uninstall ------------------------------------------------------------------
if ($Uninstall) {
  $Names = New-Object System.Collections.Generic.List[string]
  foreach ($Dir in @("agents", "dist/v2/agents")) {
    $Path = Join-Path $Src $Dir
    if (Test-Path $Path) { foreach ($File in Get-ChildItem $Path -Filter *.md) { $Names.Add("agents/$($File.Name)") } }
  }
  foreach ($File in Get-ChildItem (Join-Path $Src "commands") -Filter *.md) { $Names.Add("commands/$($File.Name)") }
  foreach ($Rel in $Recorded.Keys) { $Names.Add($Rel) }
  foreach ($Rel in ($Names | Select-Object -Unique)) {
    $Dest = Join-Path $Target $Rel
    if (Test-Path $Dest) { Remove-Item $Dest -Force; Write-Host "removed $Rel"; $Count++ }
  }
  if (Test-Path $ManifestPath) { Remove-Item $ManifestPath -Force }
  if (-not $Project -and $OnWindows) {
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $Entries = @($UserPath -split ";" | Where-Object { $_ })
    if ($Entries -contains $BinDir) {
      [Environment]::SetEnvironmentVariable("Path", (($Entries | Where-Object { $_ -ne $BinDir }) -join ";"), "User")
      Write-Host "removed $BinDir from your PATH"
    }
  }
  Write-Host "Uninstalled $Count files from $Target"
  return
}

# --- Install --------------------------------------------------------------------
foreach ($Kind in @("agents", "commands")) {
  $From = if ($Kind -eq "agents") { $AgentsSrc } else { Join-Path $Src "commands" }
  $Dir = Join-Path $Target $Kind
  New-Item -ItemType Directory -Force -Path $Dir | Out-Null
  foreach ($File in Get-ChildItem $From -Filter *.md) {
    $Rel = "$Kind/$($File.Name)"
    $Dest = Join-Path $Dir $File.Name
    $Installed[$Rel] = $true
    # Back up anything that isn't ours: not what we installed last time (manifest hash)
    # and not identical to the new file.
    if (Test-Path $Dest) {
      $Current = Get-Sha256 $Dest
      if ($Current -ne (Get-Sha256 $File.FullName) -and $Current -ne $Recorded[$Rel]) {
        Move-Item $Dest "$Dest.bak.$Stamp"
        Write-Host "backed up existing $Rel -> $($File.Name).bak.$Stamp"
      }
    }
    Copy-Item $File.FullName $Dest -Force
    $Count++
  }
}

# Remove files a previous version installed that this one no longer ships.
foreach ($Rel in @($Recorded.Keys)) {
  if ($Installed.Contains($Rel)) { continue }
  $Dest = Join-Path $Target $Rel
  if ((Test-Path $Dest) -and (Get-Sha256 $Dest) -eq $Recorded[$Rel]) {
    Remove-Item $Dest -Force
    Write-Host "removed $Rel (no longer part of Cuadrilla)"
  }
}

$Source = Get-Description $Src
$Lines = @(
  "# Cuadrilla install manifest: lets updates and uninstalls tell its files from yours.",
  "# format: $Format - source: $Source"
)
foreach ($Rel in $Installed.Keys) { $Lines += "$(Get-Sha256 (Join-Path $Target $Rel))  $Rel" }
[IO.File]::WriteAllText($ManifestPath, (($Lines -join "`n") + "`n"))

Write-Host "Installed $Count files into $Target (copy, $Format format, $Source)"

# The `cuadrilla` command (global installs on Windows): the clone's bin folder on your PATH.
$UpdateHint = "re-run the installer"
if (-not $Project -and (Test-Path (Join-Path $BinDir "cuadrilla.cmd"))) {
  if ($OnWindows -and -not $NoPath) {
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $Entries = @($UserPath -split ";" | Where-Object { $_ })
    if ($Entries -notcontains $BinDir) {
      [Environment]::SetEnvironmentVariable("Path", (@($Entries + $BinDir) -join ";"), "User")
      Write-Host "added $BinDir to your PATH (open a new terminal to use it)"
    }
    if (@($env:Path -split ";") -notcontains $BinDir) { $env:Path = "$env:Path;$BinDir" }
    $UpdateHint = "cuadrilla update"
  } else {
    $UpdateHint = "& '$(Join-Path $BinDir "cuadrilla.ps1")' update"
  }
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart OpenCode."
Write-Host "  2. Press Tab until you see the 'cuadrilla' agent, then describe what you want."
Write-Host "  3. Try:  /cuadrilla-plan add rate limiting to the login endpoint"
Write-Host "  4. Optional: set per-agent models - see examples in $Src"
Write-Host "  Update later with:  $UpdateHint"

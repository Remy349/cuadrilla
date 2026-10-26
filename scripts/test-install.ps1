# End-to-end test for install.ps1 and bin/cuadrilla.ps1 in isolated temp dirs (nothing
# outside them is touched; the user PATH is left alone via CUADRILLA_NO_PATH).
# Covers: global and project installs, format selection (auto/v1/v2 with fake OpenCode
# binaries), backups, the manifest (no spurious backups, stale files removed), uninstall,
# remote installs (as with irm | iex) pinned to a tag, and `cuadrilla update`.
#
# Usage (in a fresh process, it sets env vars):
#   pwsh -NoProfile -File scripts/test-install.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-install.ps1
$ErrorActionPreference = "Stop"

$Root      = Split-Path -Parent $PSScriptRoot
$Installer = Join-Path $Root "install.ps1"
$Tmp       = Join-Path ([IO.Path]::GetTempPath()) ("cuadrilla-test-" + [guid]::NewGuid())
$Tag       = "v0.0.1"
$OnWindows = ($PSVersionTable.PSEdition -eq "Desktop") -or $IsWindows

function Assert-That([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "FAIL - $Message" }
  Write-Host "ok - $Message"
}
function Invoke-Git {
  $ErrorActionPreference = "Continue"
  & git @args
  if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed" }
}
function Save-Fixture([string]$Message) {
  Invoke-Git -C $Fixture add -A
  Invoke-Git -C $Fixture -c user.name=ci -c user.email=ci@example.invalid commit -qm $Message
}
# Fake OpenCode binaries: auto-detection reads `opencode --version` / `opencode2 --version`.
function Write-FakeOpenCode([string]$Name, [string]$Version) {
  if ($OnWindows) {
    $Body = if ($Version) { "@echo $Version" } else { "@echo off" }
    Set-Content -Path (Join-Path $FakeBin "$Name.cmd") -Value $Body -Encoding ascii
  } else {
    $Path = Join-Path $FakeBin $Name
    [IO.File]::WriteAllText($Path, "#!/bin/sh`necho `"$Version`"`n")
    & chmod +x $Path
  }
}
function Get-Hash([string]$Path) { (Get-FileHash -Algorithm SHA256 $Path).Hash }

New-Item -ItemType Directory -Path $Tmp | Out-Null
try {
  $env:XDG_CONFIG_HOME   = Join-Path $Tmp "config"
  $env:CUADRILLA_HOME    = Join-Path $Tmp "clone"
  $env:CUADRILLA_NO_PATH = "1"
  Remove-Item Env:CUADRILLA_REF, Env:CUADRILLA_REPO, Env:CUADRILLA_FORMAT -ErrorAction SilentlyContinue
  $Config   = Join-Path $env:XDG_CONFIG_HOME "opencode"
  $Agent    = Join-Path $Config "agents/cuadrilla.md"
  $Manifest = Join-Path $Config ".cuadrilla-manifest"
  $V1Agent  = Join-Path $Root "agents/cuadrilla.md"
  $V2Agent  = Join-Path $Root "dist/v2/agents/cuadrilla.md"

  $FakeBin = Join-Path $Tmp "fakebin"
  New-Item -ItemType Directory -Path $FakeBin | Out-Null
  # Environment variable names are case-sensitive off Windows (PATH, not Path).
  if ($OnWindows) { $env:Path = "$FakeBin;$env:Path" } else { $env:PATH = "$FakeBin`:$env:PATH" }
  Write-FakeOpenCode "opencode" ""   # an unknown version counts as "not found"
  Write-FakeOpenCode "opencode2" ""

  # Fixture repo: a copy of the working tree's installable files, with a release tag.
  $Fixture = Join-Path $Tmp "src"
  Invoke-Git -c init.defaultBranch=main init -q $Fixture
  foreach ($Item in @("agents", "commands", "dist", "bin", "install.ps1")) {
    Copy-Item -Recurse (Join-Path $Root $Item) $Fixture
  }
  Save-Fixture "fixture"
  Invoke-Git -C $Fixture tag $Tag

  # --- From a clone ------------------------------------------------------------
  & $Installer 6>$null | Out-Null
  Assert-That (Test-Path $Agent) "global install"
  Assert-That (Test-Path (Join-Path $Config "commands/cuadrilla-plan.md")) "global install includes commands"
  Assert-That ((Get-Hash $Agent) -eq (Get-Hash $V1Agent)) "no OpenCode found -> v1 format"
  Assert-That (Test-Path $Manifest) "manifest written"

  Write-FakeOpenCode "opencode" "opencode 2.1.4"
  & $Installer 6>$null | Out-Null
  Assert-That ((Get-Hash $Agent) -eq (Get-Hash $V2Agent)) "auto format: only OpenCode 2.x -> v2"
  Assert-That (@(Get-ChildItem (Split-Path $Agent) -Filter "*.bak.*").Count -eq 0) "switching formats makes no backups of our own files"

  Write-FakeOpenCode "opencode2" "2.1.4"
  Write-FakeOpenCode "opencode" "1.19.4"
  & $Installer 6>$null | Out-Null
  Assert-That ((Get-Hash $Agent) -eq (Get-Hash $V1Agent)) "auto format: OpenCode 1.x and 2.x -> v1"

  & $Installer -Format v2 6>$null | Out-Null
  Assert-That ((Get-Hash $Agent) -eq (Get-Hash $V2Agent)) "-Format v2"
  Assert-That ((Get-Content $Manifest) -contains "# format: v2 - source: $(& git -C $Root describe --tags --always)") "manifest records the format"
  Write-FakeOpenCode "opencode" ""
  Write-FakeOpenCode "opencode2" ""

  & $Installer -Uninstall 6>$null | Out-Null
  Assert-That (-not (Test-Path $Agent)) "global uninstall"
  Assert-That (-not (Test-Path $Manifest)) "uninstall removes the manifest"

  $Proj = Join-Path $Tmp "proj"
  New-Item -ItemType Directory -Path $Proj | Out-Null
  & $Installer -Project $Proj 6>$null | Out-Null
  $ProjAgent = Join-Path $Proj ".opencode/agents/cuadrilla.md"
  Assert-That (Test-Path $ProjAgent) "project install"

  Set-Content $ProjAgent "mine"
  & $Installer -Project $Proj 6>$null | Out-Null
  Assert-That (@(Get-ChildItem (Split-Path $ProjAgent) -Filter "cuadrilla.md.bak.*").Count -eq 1) "backup of a modified file"

  # --- Remote (as with irm | iex: no $PSScriptRoot next to the agents) ---------
  $Code = Get-Content $Installer -Raw
  $env:CUADRILLA_REPO = $Fixture
  $Clone = $env:CUADRILLA_HOME
  $Cli = Join-Path $Clone "bin/cuadrilla.ps1"

  $env:CUADRILLA_REF = $Tag
  Invoke-Expression $Code 6>$null | Out-Null
  Assert-That ((& git -C $Clone describe --tags --exact-match) -eq $Tag) "remote install pinned to $Tag"
  Assert-That (Test-Path $Agent) "remote install copies agents"

  Invoke-Expression $Code 6>$null | Out-Null
  Assert-That ((& git -C $Clone describe --tags --exact-match) -eq $Tag) "remote re-install on a tag"
  Remove-Item Env:CUADRILLA_REF

  # --- cuadrilla update ----------------------------------------------------------
  # A new release that drops one agent and adds another.
  Invoke-Git -C $Fixture rm -q agents/cuadrilla-mobile.md
  Copy-Item (Join-Path $Fixture "agents/cuadrilla-qa.md") (Join-Path $Fixture "agents/cuadrilla-newcomer.md")
  Save-Fixture "release 0.0.2"
  Invoke-Git -C $Fixture tag v0.0.2

  & $Cli update 6>$null | Out-Null
  Assert-That ((& git -C $Clone describe --tags --exact-match) -eq "v0.0.2") "update moves a pinned install to the newest release"
  Assert-That (Test-Path (Join-Path $Config "agents/cuadrilla-newcomer.md")) "update installs new agents"
  Assert-That (-not (Test-Path (Join-Path $Config "agents/cuadrilla-mobile.md"))) "update removes agents that were dropped"

  & $Cli update --ref main 6>$null | Out-Null
  Assert-That ((& git -C $Clone branch --show-current) -eq "main") "update --ref main"
  Add-Content (Join-Path $Fixture "commands/cuadrilla-plan.md") "# change"
  Save-Fixture "unreleased change"
  & $Cli update 6>$null | Out-Null
  Assert-That ((& git -C $Clone rev-parse HEAD) -eq (& git -C $Fixture rev-parse HEAD)) "update pulls a branch"

  & $Cli update --project $Proj 6>$null | Out-Null
  Assert-That (Test-Path (Join-Path $Proj ".opencode/agents/cuadrilla-newcomer.md")) "update --project refreshes a project"

  if ($OnWindows) {
    # The command users type: cuadrilla.cmd -> Windows PowerShell -> cuadrilla.ps1.
    $Output = & (Join-Path $Clone "bin/cuadrilla.cmd") version | Out-String
    Assert-That ($LASTEXITCODE -eq 0 -and $Output -match "cuadrilla ") "cuadrilla.cmd version"
  }

  & $Cli uninstall 6>$null | Out-Null
  Assert-That (-not (Test-Path $Agent)) "cuadrilla uninstall"

  $env:CUADRILLA_HOME = Join-Path $Tmp "clone-bad"
  $env:CUADRILLA_REF  = "no-such-ref"
  $Failed = $false
  try { Invoke-Expression $Code *> $null } catch { $Failed = $true }
  Assert-That $Failed "a failing git command stops the installer"
} finally {
  $ErrorActionPreference = "Continue"
  Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
# All assertions passed. Exit explicitly: the negative test leaves git's exit code (128)
# in $LASTEXITCODE, and CI runners report that as the script's result.
exit 0

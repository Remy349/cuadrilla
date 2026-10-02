# End-to-end test for install.ps1 in isolated temp dirs (nothing outside them is touched).
# Covers: global, project, uninstall, backups, and remote installs (as with irm | iex)
# pinned to a tag, re-run on the tag, then switched to a branch.
#
# Usage (in a fresh process, it sets env vars):
#   pwsh -NoProfile -File scripts/test-install.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-install.ps1
$ErrorActionPreference = "Stop"

$Root      = Split-Path -Parent $PSScriptRoot
$Installer = Join-Path $Root "install.ps1"
$Tmp       = Join-Path ([IO.Path]::GetTempPath()) ("cuadrilla-test-" + [guid]::NewGuid())
$Tag       = "v0.0.0-test"

function Assert-That([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "FAIL - $Message" }
  Write-Host "ok - $Message"
}
function Invoke-Git {
  $ErrorActionPreference = "Continue"
  & git @args
  if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed" }
}

New-Item -ItemType Directory -Path $Tmp | Out-Null
try {
  $env:XDG_CONFIG_HOME = Join-Path $Tmp "config"
  $env:CUADRILLA_HOME  = Join-Path $Tmp "clone"
  Remove-Item Env:CUADRILLA_REF, Env:CUADRILLA_REPO -ErrorAction SilentlyContinue
  $Config = Join-Path $env:XDG_CONFIG_HOME "opencode"
  $Agent  = Join-Path $Config "agents/cuadrilla.md"

  # Fixture repo with the working tree's agents/commands, a tag and a branch.
  $Fixture = Join-Path $Tmp "src"
  Invoke-Git -c init.defaultBranch=main init -q $Fixture
  Copy-Item -Recurse (Join-Path $Root "agents"), (Join-Path $Root "commands") $Fixture
  Invoke-Git -C $Fixture add .
  Invoke-Git -C $Fixture -c user.name=ci -c user.email=ci@example.invalid commit -qm fixture
  Invoke-Git -C $Fixture tag $Tag

  # --- From a clone ------------------------------------------------------------
  & $Installer 6>$null | Out-Null
  Assert-That (Test-Path $Agent) "global install"
  Assert-That (Test-Path (Join-Path $Config "commands/cuadrilla-plan.md")) "global install includes commands"

  & $Installer -Uninstall 6>$null | Out-Null
  Assert-That (-not (Test-Path $Agent)) "global uninstall"

  $Proj = Join-Path $Tmp "proj"
  New-Item -ItemType Directory -Path $Proj | Out-Null
  & $Installer -Project $Proj 6>$null | Out-Null
  $ProjAgent = Join-Path $Proj ".opencode/agents/cuadrilla.md"
  Assert-That (Test-Path $ProjAgent) "project install"

  Set-Content $ProjAgent "mine"
  & $Installer -Project $Proj 6>$null | Out-Null
  Assert-That (@(Get-ChildItem (Split-Path $ProjAgent) -Filter "cuadrilla.md.bak.*").Count -eq 1) "backup of a modified file"

  & $Installer -Uninstall -Project $Proj 6>$null | Out-Null
  Assert-That (-not (Test-Path $ProjAgent)) "project uninstall"

  # --- Remote (as with irm | iex: no $PSScriptRoot next to the agents) ---------
  $Code = Get-Content $Installer -Raw
  $env:CUADRILLA_REPO = $Fixture

  $env:CUADRILLA_REF = $Tag
  Invoke-Expression $Code 6>$null | Out-Null
  Assert-That ((& git -C $env:CUADRILLA_HOME describe --tags --exact-match) -eq $Tag) "remote install pinned to $Tag"
  Assert-That (Test-Path $Agent) "remote install copies agents"

  Invoke-Expression $Code 6>$null | Out-Null
  Assert-That ((& git -C $env:CUADRILLA_HOME describe --tags --exact-match) -eq $Tag) "remote re-install on a tag"

  $env:CUADRILLA_REF = "main"
  Invoke-Expression $Code 6>$null | Out-Null
  Assert-That ((& git -C $env:CUADRILLA_HOME branch --show-current) -eq "main") "remote switch from tag to main"

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

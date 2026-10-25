# cuadrilla - manage an installed Cuadrilla (https://github.com/Remy349/cuadrilla).
# Windows: the global installer puts this folder on your PATH; cuadrilla.cmd runs this file.
# It works on the clone it lives in. Keep this file ASCII-only (Windows PowerShell 5.1).
#
#   cuadrilla update [--ref <tag|branch>] [--format auto|v1|v2] [--project [dir]]
#   cuadrilla version
#   cuadrilla uninstall [--project [dir]]
$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
$Installer = Join-Path $Repo "install.ps1"

function Show-Usage {
  Write-Host "Usage: cuadrilla <command> [options]"
  Write-Host ""
  Write-Host "Commands:"
  Write-Host "  update [--ref <tag|branch>] [--format auto|v1|v2] [--project [dir]]"
  Write-Host "             Fetch the latest Cuadrilla and reinstall it. A branch install is pulled;"
  Write-Host "             an install pinned to a release moves to the newest release. --ref picks"
  Write-Host "             a specific tag or branch. --project refreshes <dir>/.opencode instead of the global install."
  Write-Host "  version    Show the installed version and where it lives."
  Write-Host "  uninstall [--project [dir]]"
  Write-Host "             Remove Cuadrilla's agents, commands and this command from your PATH."
  Write-Host "  help       Show this help."
  Write-Host ""
  Write-Host "Clone: $Repo"
}

# Accept both --ref/--project/--format and -Ref/-Project/-Format.
$Command = if ($args.Count -gt 0) { "$($args[0])" } else { "help" }
$Options = @{}
$Index = 1
while ($Index -lt $args.Count) {
  $Name = "$($args[$Index])".TrimStart("-").ToLowerInvariant()
  $Next = if ($Index + 1 -lt $args.Count) { "$($args[$Index + 1])" } else { $null }
  switch ($Name) {
    "ref"     { if (-not $Next) { throw "--ref needs a tag or branch" }; $Options.Ref = $Next; $Index++ }
    "format"  { if (-not $Next) { throw "--format needs auto, v1 or v2" }; $Options.Format = $Next; $Index++ }
    "project" {
      if ($Next -and -not $Next.StartsWith("-")) { $Options.Project = $Next; $Index++ } else { $Options.Project = "." }
    }
    "nopath"  { $Options.NoPath = $true }
    default   { throw "cuadrilla: unknown option '$($args[$Index])'" }
  }
  $Index++
}

switch ($Command) {
  "update"    { & $Installer -Update @Options }
  "uninstall" {
    $Options.Remove("Ref"); $Options.Remove("Format")
    & $Installer -Uninstall @Options
  }
  { $_ -in @("version", "--version", "-v") } {
    $ErrorActionPreference = "Continue"
    $Version = & git -C $Repo describe --tags --always --dirty 2>$null
    if (-not $Version) { $Version = "unknown" }
    Write-Host "cuadrilla $Version"
    Write-Host "clone:  $Repo"
    $ConfigHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME ".config" }
    $Manifest = Join-Path $ConfigHome "opencode/.cuadrilla-manifest"
    if (Test-Path $Manifest) {
      foreach ($Line in Get-Content $Manifest) {
        if ($Line -match '^# format: (.*)$') { Write-Host "global: $($Matches[1])" }
      }
    }
  }
  { $_ -in @("help", "-h", "--help") } { Show-Usage }
  default { Show-Usage; throw "cuadrilla: unknown command '$Command'" }
}

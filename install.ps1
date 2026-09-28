# Cuadrilla installer for OpenCode (Windows PowerShell)
#   irm https://raw.githubusercontent.com/OWNER/cuadrilla/main/install.ps1 | iex
#   .\install.ps1                    # global
#   .\install.ps1 -Project .         # into .\.opencode
#   .\install.ps1 -Uninstall
param(
  [string]$Project,
  [switch]$Uninstall
)
$ErrorActionPreference = "Stop"

$RepoUrl  = if ($env:CUADRILLA_REPO) { $env:CUADRILLA_REPO } else { "https://github.com/OWNER/cuadrilla.git" }
$Ref      = if ($env:CUADRILLA_REF)  { $env:CUADRILLA_REF }  else { "main" }
$CloneDir = if ($env:CUADRILLA_HOME) { $env:CUADRILLA_HOME } else { Join-Path $env:LOCALAPPDATA "cuadrilla" }

if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "agents"))) {
  $Src = $PSScriptRoot
} else {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "git is required" }
  if (Test-Path (Join-Path $CloneDir ".git")) {
    git -C $CloneDir fetch --quiet --tags origin
    git -C $CloneDir checkout --quiet $Ref
    git -C $CloneDir pull --quiet --ff-only origin $Ref
  } else {
    git clone --quiet --branch $Ref $RepoUrl $CloneDir
  }
  $Src = $CloneDir
}

if ($Project) {
  $Target = Join-Path (Resolve-Path $Project) ".opencode"
} else {
  $ConfigHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME ".config" }
  $Target = Join-Path $ConfigHome "opencode"
}

$Stamp = Get-Date -Format "yyyyMMddHHmmss"
$Count = 0
foreach ($Kind in @("agents", "commands")) {
  $Dir = Join-Path $Target $Kind
  New-Item -ItemType Directory -Force -Path $Dir | Out-Null
  foreach ($File in Get-ChildItem (Join-Path $Src $Kind) -Filter *.md) {
    $Dest = Join-Path $Dir $File.Name
    if ($Uninstall) {
      if (Test-Path $Dest) { Remove-Item $Dest -Force; $Count++ }
      continue
    }
    if ((Test-Path $Dest) -and ((Get-FileHash $Dest).Hash -ne (Get-FileHash $File.FullName).Hash)) {
      Move-Item $Dest "$Dest.bak.$Stamp"
      Write-Host "backed up existing $Kind/$($File.Name)"
    }
    Copy-Item $File.FullName $Dest -Force
    $Count++
  }
}

if ($Uninstall) { Write-Host "Uninstalled $Count files from $Target" }
else {
  Write-Host "Installed $Count files into $Target"
  Write-Host "Restart OpenCode, press Tab to select 'cuadrilla', or try: /cuadrilla-plan <task>"
}

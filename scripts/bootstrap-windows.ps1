[CmdletBinding()]
param(
  [switch]$SkipAndroidStudio
)

$ErrorActionPreference = "Stop"

function Test-Command {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-CommandPath {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Candidates
  )

  foreach ($candidate in $Candidates) {
    $command = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }
  }

  return $null
}

function Test-AndroidStudio {
  $defaultPath = Join-Path ${env:ProgramFiles} "Android\Android Studio\bin\studio64.exe"
  return Test-Path $defaultPath
}

function Install-WingetPackage {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Id,
    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  Write-Host "Installing $Label..."
  winget install --id $Id --exact --accept-package-agreements --accept-source-agreements --disable-interactivity
}

function Ensure-NpmGlobalPackage {
  param(
    [Parameter(Mandatory = $true)]
    [string]$CommandName,
    [Parameter(Mandatory = $true)]
    [string]$PackageName,
    [string]$Version = ""
  )

  if (Test-Command $CommandName) {
    Write-Host "$PackageName already available."
    return
  }

  $npm = Get-CommandPath -Candidates @("npm.cmd", "npm")
  if (-not $npm) {
    throw "npm is required to install $PackageName. Install Node.js LTS first."
  }

  $packageSpec = if ($Version) { "$PackageName@$Version" } else { $PackageName }
  Write-Host "Installing $PackageName with npm..."
  & $npm install --global $packageSpec
}

function Get-PuroExecutable {
  $command = Get-Command "puro" -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $wingetPath = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe"
  if (Test-Path $wingetPath) {
    return $wingetPath
  }

  return $null
}

if (-not (Test-Command "winget")) {
  throw "winget is required for this bootstrap script."
}

$wingetPackages = @(
  @{ Label = "Git"; Id = "Git.Git"; Command = "git" },
  @{ Label = "Node.js LTS"; Id = "OpenJS.NodeJS.LTS"; Command = "node" },
  @{ Label = "Python 3.12"; Id = "Python.Python.3.12"; Command = "python" }
)

foreach ($package in $wingetPackages) {
  if (Test-Command $package.Command) {
    Write-Host "$($package.Label) already available."
    continue
  }

  Install-WingetPackage -Id $package.Id -Label $package.Label
}

if (-not $SkipAndroidStudio) {
  if (Test-AndroidStudio) {
    Write-Host "Android Studio already available."
  }
  else {
    Install-WingetPackage -Id "Google.AndroidStudio" -Label "Android Studio"
  }
}

Ensure-NpmGlobalPackage -CommandName "pnpm.cmd" -PackageName "pnpm" -Version "10.0.0"
Ensure-NpmGlobalPackage -CommandName "firebase.cmd" -PackageName "firebase-tools"

if (-not (Test-Command "puro")) {
  Install-WingetPackage -Id "pingbird.Puro" -Label "Puro"
}

$puro = Get-PuroExecutable
if (-not $puro) {
  throw "Puro was not found after installation."
}

$stableFlutter = Join-Path $env:USERPROFILE ".puro\envs\stable\flutter\bin\flutter.bat"
if (-not (Test-Path $stableFlutter)) {
  Write-Host "Installing Flutter stable 3.41.8 with Puro..."
  & $puro create stable 3.41.8
}

Write-Host "Setting the global Flutter environment to 'stable'..."
& $puro use stable --global

if (-not (Test-Path $stableFlutter)) {
  throw "Flutter stable was not installed correctly."
}

Write-Host ""
Write-Host "Verification commands:"
Write-Host "  git --version"
Write-Host "  node --version"
Write-Host "  npm.cmd --version"
Write-Host "  pnpm.cmd --version"
Write-Host "  firebase.cmd --version"
Write-Host "  $stableFlutter --version"
Write-Host "  $stableFlutter doctor"
Write-Host "  python --version"
Write-Host "  pnpm.cmd --dir backend/worker-api exec wrangler --version"
Write-Host "  pnpm.cmd --dir backend/worker-admin exec wrangler --version"

#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build and push DapperExtensions release package to NuGet.org

.DESCRIPTION
    This script builds the DapperExtensions project in Release mode,
    creates a NuGet package, and pushes it to nuget.org.

.PARAMETER ApiKey
    NuGet.org API key for authentication (required for push)
    If not provided, the script will prompt for it.

.PARAMETER SkipPush
    Skip the push to NuGet.org (useful for testing the build/pack process)

.PARAMETER Clean
    Clean bin and obj directories before building

.EXAMPLE
    .\build-release-package.ps1 -ApiKey "oy2..." -Clean

.EXAMPLE
    .\build-release-package.ps1 -SkipPush  # Build and pack without pushing
#>

param(
    [string]$ApiKey,
    [switch]$SkipPush,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$projectPath = "DapperExtensions\DapperExtensions.csproj"
$projectDir = "DapperExtensions"

Write-Host "🔨 DapperExtensions Release Build & Push Script" -ForegroundColor Cyan
Write-Host ""

# Verify project file exists
if (-not (Test-Path $projectPath)) {
    Write-Error "Project file not found: $projectPath"
    exit 1
}

# Clean if requested
if ($Clean) {
    Write-Host "🧹 Cleaning bin and obj directories..." -ForegroundColor Yellow
    Remove-Item "$projectDir\bin" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$projectDir\obj" -Recurse -Force -ErrorAction SilentlyContinue
}

# Restore dependencies
Write-Host "📦 Restoring dependencies..." -ForegroundColor Cyan
dotnet restore $projectPath
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to restore dependencies"
    exit 1
}

# Build in Release mode
Write-Host "🏗️ Building in Release mode..." -ForegroundColor Cyan
dotnet build $projectPath -c Release -v minimal
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed"
    exit 1
}

# Pack the NuGet package
Write-Host "📮 Packing NuGet package..." -ForegroundColor Cyan
dotnet pack $projectPath -c Release -o ./nupkg --no-build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Pack failed"
    exit 1
}

# Find the generated package
$nupkg = Get-ChildItem "./nupkg" -Filter "*.nupkg" -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $nupkg) {
    Write-Error "No .nupkg file found in ./nupkg directory"
    exit 1
}

Write-Host "✅ Package created: $($nupkg.Name)" -ForegroundColor Green
Write-Host ""

# Skip push if requested
if ($SkipPush) {
    Write-Host "⏭️  Skipping push to NuGet.org (--SkipPush flag set)" -ForegroundColor Yellow
    Write-Host "📍 Package location: $($nupkg.FullName)" -ForegroundColor Cyan
    exit 0
}

# Get API key if not provided
if (-not $ApiKey) {
    Write-Host "🔐 NuGet.org API Key required for push" -ForegroundColor Yellow
    $ApiKey = Read-Host "Enter your NuGet.org API key (or Ctrl+C to cancel)"
    
    if (-not $ApiKey) {
        Write-Error "API key is required"
        exit 1
    }
}

# Push to NuGet.org
Write-Host "🚀 Pushing to NuGet.org..." -ForegroundColor Cyan
dotnet nuget push "$($nupkg.FullName)" `
    --api-key $ApiKey `
    --source https://api.nuget.org/v3/index.json
    
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to push package to NuGet.org"
    exit 1
}

Write-Host ""
Write-Host "✅ Successfully pushed $($nupkg.Name) to NuGet.org!" -ForegroundColor Green
Write-Host "📍 Package will be available shortly at: https://www.nuget.org/packages/DapperExtensions.StrongNameReference/" -ForegroundColor Cyan

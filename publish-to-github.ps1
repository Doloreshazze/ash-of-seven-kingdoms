# Пепел семи королевств: publication and CI APK retrieval using the official GitHub CLI.
# Run from PowerShell: powershell -NoProfile -ExecutionPolicy Bypass -File .\publish-to-github.ps1
# Prerequisites: Git and GitHub CLI (gh). Only authenticates using the official 'gh auth login' flow.
$ErrorActionPreference = 'Stop'
$repo = 'Doloreshazze/ash-of-seven-kingdoms'
$artifact = 'Ash-of-the-Seven-Kingdoms-Android-debug-APK'
Set-Location $PSScriptRoot

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git is not installed. Install Git for Windows: https://git-scm.com/download/win'
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI is not installed. Install it: https://cli.github.com/'
}

Write-Host '1/4: Signing in to GitHub (official CLI; no passwords stored in this project)...'
gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { throw 'GitHub login failed.' }
}

Write-Host '2/4: Preparing project files...'
if (-not (Test-Path '.git')) {
    git init -b main
    if ($LASTEXITCODE -ne 0) { throw 'git init failed.' }
}
$branch = (git branch --show-current).Trim()
if ($branch -ne 'main') { git branch -M main }
git add -A
if ($LASTEXITCODE -ne 0) { throw 'git add failed.' }
$pending = git status --porcelain
if ($pending) {
    git -c 'user.name=Doloreshazze' -c 'user.email=181396029+Doloreshazze@users.noreply.github.com' commit -m 'Initial Godot fantasy prologue with Android APK CI'
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }
}

Write-Host '3/4: Creating private repository or pushing to existing repository...'
gh repo view $repo --json name --jq '.name' 2>$null | Out-Null
$exists = ($LASTEXITCODE -eq 0)
if (-not $exists) {
    gh repo create $repo --private --source '.' --remote origin --push
    if ($LASTEXITCODE -ne 0) { throw 'Repository creation or first push failed.' }
} else {
    $remote = git remote get-url origin 2>$null
    if ($LASTEXITCODE -ne 0) {
        git remote add origin "https://github.com/$repo.git"
    } elseif ($remote -notmatch '(github.com[/:]Doloreshazze/ash-of-seven-kingdoms(\.git)?)$') {
        throw "Unexpected existing origin: $remote. Check the repository before pushing."
    }
    git push -u origin main
    if ($LASTEXITCODE -ne 0) { throw 'git push failed (the remote branch may contain different history).' }
}

Write-Host 'Repository: https://github.com/Doloreshazze/ash-of-seven-kingdoms'
Write-Host '4/4: Waiting for the GitHub Actions Android debug APK build...'
$runId = $null
for ($attempt = 0; $attempt -lt 12; $attempt++) {
    $runId = gh run list --repo $repo --workflow 'build-android.yml' --branch main --limit 1 --json databaseId --jq '.[0].databaseId' 2>$null
    if ($LASTEXITCODE -eq 0 -and $runId -match '^\d+$') { break }
    Start-Sleep -Seconds 10
}
if (-not $runId -or $runId -notmatch '^\d+$') {
    throw 'Android workflow has not appeared. Open GitHub Actions to inspect whether Actions are enabled.'
}
gh run watch $runId --repo $repo --exit-status
if ($LASTEXITCODE -ne 0) {
    throw "Build $runId failed. Check https://github.com/$repo/actions/runs/$runId"
}
$apkFolder = Join-Path $PSScriptRoot 'APK'
New-Item -Path $apkFolder -ItemType Directory -Force | Out-Null
gh run download $runId --repo $repo --name $artifact --dir $apkFolder
if ($LASTEXITCODE -ne 0) { throw 'APK artifact download failed.' }
$apk = Get-ChildItem -Path $apkFolder -Filter '*.apk' -File | Select-Object -First 1
if (-not $apk) { throw 'Build finished but APK not found in the downloaded artifact.' }
Write-Host "Success! APK: $($apk.FullName)"

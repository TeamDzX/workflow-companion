# WorkFlow companion: install on Windows in one line (PowerShell):
#   irm https://raw.githubusercontent.com/TeamDzX/workflow-companion/main/install.ps1 | iex
# Installs Node.js if needed, signs this PC in to iCloud for WorkFlow, adds the
# companion to Claude Code, and offers to let it start work on its own.
$ErrorActionPreference = 'Continue'
Write-Host "`nWorkFlow companion setup`n" -ForegroundColor Cyan

function Get-NodeMajor { try { [int](((node -v) 2>$null) -replace '^v(\d+).*', '$1') } catch { 0 } }

if ((Get-NodeMajor) -lt 18) {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "Node.js 18 or later is needed, and winget isn't available to install it."
    Write-Host "Install the LTS from https://nodejs.org, then run this command again."
    return
  }
  Write-Host "Installing Node.js (LTS)..."
  winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
  if ((Get-NodeMajor) -lt 18) {
    Write-Host "Node.js is installed but this window can't see it yet. Close PowerShell, open a new one, and run the same command again."
    return
  }
}
Write-Host "Node.js $(node -v) OK`n"

Write-Host "Step 1 of 3: sign in to iCloud for WorkFlow (a browser window opens)" -ForegroundColor Cyan
npx -y @opticell/workflow-companion@latest setup
if ($LASTEXITCODE -ne 0) { Write-Host "Sign-in didn't finish. Run the same command again to retry."; return }

if (Get-Command claude -ErrorAction SilentlyContinue) {
  Write-Host "`nStep 2 of 3: add it to Claude Code" -ForegroundColor Cyan
  claude mcp remove workflow -s user *> $null
  claude mcp add --scope user workflow -- cmd /c npx -y @opticell/workflow-companion@latest
  Write-Host "`nStep 3 of 3" -ForegroundColor Cyan
  $answer = Read-Host "Start work on its own when you hand it something in WorkFlow? (Y/n)"
  if ($answer -notmatch '^[nN]') { npx -y @opticell/workflow-companion@latest wake-on }
} else {
  Write-Host "`nClaude Code isn't on this PC yet. Install it from https://claude.com/claude-code and sign in, then run:"
  Write-Host "  claude mcp add --scope user workflow -- cmd /c npx -y @opticell/workflow-companion@latest"
  Write-Host "  npx -y @opticell/workflow-companion@latest wake-on"
}
Write-Host "`nDone. Check on it any time with: npx -y @opticell/workflow-companion@latest status`n" -ForegroundColor Green

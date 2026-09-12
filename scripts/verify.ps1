# verify.ps1 —— 检查项目是否正确接入 vibe-rules（Windows PowerShell 版）
#
# 用法：
#   pwsh C:\path\to\vibe-rules\scripts\verify.ps1 C:\path\to\your-project

param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VibeHome = Resolve-Path (Join-Path $ScriptDir "..")
$ProjectRoot = Resolve-Path $ProjectRoot

Write-Host "🔍 检查 $ProjectRoot"
Write-Host ""

Set-Location $ProjectRoot

$PASS = 0
$FAIL = 0

function Check {
    param([string]$Desc, [bool]$Condition)
    if ($Condition) {
        Write-Host "  ✅ $Desc"
        $script:PASS++
    } else {
        Write-Host "  ❌ $Desc"
        $script:FAIL++
    }
}

# 1. AGENTS.md
Check "项目根有 AGENTS.md" (Test-Path "AGENTS.md")
Check "AGENTS.md 引用了规则库" (Select-String -Path "AGENTS.md" -Pattern "vibe" -Quiet)

# 2. 证据文件
Check ".vibe-rules 证据文件存在" (Test-Path ".vibe-rules")

# 3. 单文件型（按实际安装的检查）
Check "CLAUDE.md 存在" (Test-Path "CLAUDE.md")
Check ".cursorrules 存在" (Test-Path ".cursorrules")
Check ".windsurfrules 存在" (Test-Path ".windsurfrules")
Check ".github/copilot-instructions.md 存在" (Test-Path ".github\copilot-instructions.md")

# 4. 目录型
Check ".cursor/rules/ 存在" (Test-Path ".cursor\rules")
Check ".qoder/rules/ 存在" (Test-Path ".qoder\rules")
Check ".trae/rules/ 存在" (Test-Path ".trae\rules")
Check ".codebuddy/rules/ 存在" (Test-Path ".codebuddy\rules")

Write-Host ""
Write-Host "📊 结果：$PASS 通过，$FAIL 未通过"

if ($FAIL -gt 0) {
    Write-Host ""
    Write-Host "🔧 修复：重新跑 install.ps1"
    exit 1
} else {
    Write-Host ""
    Write-Host "🎉 项目已正确接入 vibe-rules。"
}

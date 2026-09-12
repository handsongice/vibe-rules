# update.ps1 —— 把项目里的 vibe-rules 规则副本刷新到规则库最新版（Windows PowerShell 版）
#
# 用法：
#   pwsh scripts\update.ps1 [项目路径] [-Link] [-NoPersonal] [-Copy] [-Yes]
#
# 做的事：
#   - 重新复制规则本体到 <项目>\.vibe-rules\（embedded 模式，默认）
#   - 刷新 AGENTS.md 顶部的引用块
#   - 保留 .vibe-rules\project\ 里的项目专属笔记（永不覆盖）
#   - 没显式指定 mode/agent 时，沿用证据文件里上次安装的选择
#
# 选项：
#   -Link           显式切回/保持外链模式（一般不传：自动沿用上次安装的模式）
#   -NoPersonal     副本不含 personal\
#   -Copy           入口用复制文件代替 symlink
#   -Yes            非交互
#   -Help           显示本帮助

param(
    [Parameter(Position=0)][string]$ProjectRoot = ".",
    [switch]$Link,
    [switch]$NoPersonal,
    [switch]$Copy,
    [switch]$Yes,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# ---------- 用法输出（-Help 或缺参数时用） ----------
function Show-Usage {
    foreach ($line in (Get-Content -LiteralPath $PSCommandPath)) {
        if (-not $line.StartsWith('#')) { break }
        if ($line -eq '#') { Write-Host "" }
        elseif ($line.StartsWith('# ')) { Write-Host $line.Substring(2) }
        else { Write-Host $line }
    }
}

if ($Help) {
    Show-Usage
    exit 0
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VibeHome = (Resolve-Path (Join-Path $ScriptDir "..")).Path

if (-not (Test-Path $ProjectRoot)) {
    Write-Host "❌ 目录不存在：$ProjectRoot"
    exit 1
}
$ProjectRoot = (Resolve-Path $ProjectRoot).Path

$evidence = ""
if (Test-Path (Join-Path $ProjectRoot ".vibe-rules\installed")) {
    $evidence = Join-Path $ProjectRoot ".vibe-rules\installed"
} elseif ((Test-Path (Join-Path $ProjectRoot ".vibe-rules")) -and
          -not (Test-Path (Join-Path $ProjectRoot ".vibe-rules") -PathType Container)) {
    $evidence = Join-Path $ProjectRoot ".vibe-rules"
}
if (-not $evidence) {
    Write-Host "❌ 项目还没接入 vibe-rules：$ProjectRoot"
    Write-Host "   先跑：pwsh $VibeHome\scripts\install.ps1 $ProjectRoot"
    exit 1
}

Write-Host "🔄 更新规则副本：$ProjectRoot"

$modeFromEvidence = ""
$agentsFromEvidence = ""
foreach ($line in ((Get-Content $evidence -Raw) -split "`r?`n")) {
    if ($line -like "mode=*") { $modeFromEvidence = $line.Substring(5).Trim() }
    if ($line -like "agents=*") { $agentsFromEvidence = $line.Substring(7).Trim() }
}

$installParams = @{ ProjectRoot = $ProjectRoot }
if ($Link -or $modeFromEvidence -eq "link") { $installParams["Link"] = $true }
if ($NoPersonal) { $installParams["NoPersonal"] = $true }
if ($Copy) { $installParams["Copy"] = $true }
if ($agentsFromEvidence) { $installParams["AgentNums"] = $agentsFromEvidence }
$installParams["Yes"] = $true

& (Join-Path $ScriptDir "install.ps1") @installParams

Write-Host ""
Write-Host "🎉 规则副本已刷新到最新版。"
Write-Host "   项目专属笔记 .vibe-rules\project\README.md 未被改动。"

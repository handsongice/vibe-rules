# update.ps1 —— 把项目里的 vibe-rules 规则副本刷新到规则库最新版（Windows PowerShell 版）
#
# 用法：
#   pwsh scripts\update.ps1 [项目路径] [-All | -AgentNums 1,3] [-Link] [-NoPersonal] [-Profile team|hybrid|personal] [-Copy] [-Yes] [-WithCi]
#
# 做的事：
#   - 重新复制规则本体到 <项目>\.vibe-rules\（embedded 模式，默认）
#   - 刷新 AGENTS.md 顶部的引用块
#   - 保留 .vibe-rules\project\ 里的项目专属笔记（永不覆盖）
#   - 没显式指定 mode/profile/agent 时，沿用证据文件里上次安装的选择
#
# 选项：
#   -All            全选 agents（覆盖沿用）
#   -AgentNums 1,3  只带指定编号的 agents（覆盖沿用）
#   -Link           显式切回/保持外链模式（一般不传：自动沿用上次安装的模式）
#   -NoPersonal     副本不含 personal\
#   -Profile        策略档位（team|hybrid|personal，覆盖沿用）
#   -Copy           入口用复制文件代替 symlink
#   -WithCi         顺手把 .github\workflows\vibe-rules-verify.yml 重新钉到当前规则库 commit
#   -Yes            非交互
#   -Help           显示本帮助

param(
    [Parameter(Position=0)][string]$ProjectRoot = ".",
    [switch]$All,
    [string]$AgentNums = "",
    [switch]$Link,
    [switch]$NoPersonal,
    [string]$Profile = "",
    [switch]$Copy,
    [switch]$WithCi,
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
$profileFromEvidence = ""
foreach ($line in ((Get-Content $evidence -Raw) -split "`r?`n")) {
    if ($line -like "mode=*") { $modeFromEvidence = $line.Substring(5).Trim() }
    if ($line -like "agents=*") { $agentsFromEvidence = $line.Substring(7).Trim() }
    if ($line -like "profile=*") { $profileFromEvidence = $line.Substring(8).Trim() }
}

$installParams = @{ ProjectRoot = $ProjectRoot }

# 显式传了 -Link / -NoPersonal / -Profile 就按用户的来，不再沿用档位（与 update.sh 一致）
$explicitOverride = $Link -or $NoPersonal -or ($Profile -ne "")
if (-not $explicitOverride) {
    if ($profileFromEvidence -eq "team" -or $profileFromEvidence -eq "hybrid" -or $profileFromEvidence -eq "personal") {
        # 档位是装的时候定的策略，更新时原样沿用（team/hybrid 顺带带上 no-personal 的语义）
        $installParams["Profile"] = $profileFromEvidence
    } elseif ($modeFromEvidence -eq "link") {
        $installParams["Link"] = $true
    }
}
if ($Link) { $installParams["Link"] = $true }
if ($NoPersonal) { $installParams["NoPersonal"] = $true }
if ($Profile -ne "") { $installParams["Profile"] = $Profile }
if ($All) { $installParams["All"] = $true }
if ($AgentNums -ne "") { $installParams["AgentNums"] = $AgentNums }
if ($Copy) { $installParams["Copy"] = $true }
if ($WithCi) { $installParams["WithCi"] = $true }
# 没显式指定 agent 时沿用证据里的名单，并 --yes 跳过交互（与 update.sh 一致）
if (-not $All -and $AgentNums -eq "" -and $agentsFromEvidence) {
    $installParams["AgentNums"] = $agentsFromEvidence
    $installParams["Yes"] = $true
}

& (Join-Path $ScriptDir "install.ps1") @installParams

Write-Host ""
Write-Host "🎉 规则副本已刷新到最新版。"
Write-Host "   项目专属笔记 .vibe-rules\project\README.md 未被改动。"

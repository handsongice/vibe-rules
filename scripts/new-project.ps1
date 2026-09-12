# new-project.ps1 —— 初始化一个新项目的 vibe-rules 骨架（Windows PowerShell 版）
#
# 用法：
#   pwsh scripts\new-project.ps1 <项目路径> [-All] [-AgentNums 1,3,5] [-Copy] [-Yes]
#
# 选项：
#   -All            给所有 agent 建入口
#   -AgentNums 1,3  只建指定编号
#   -Copy           用复制文件代替 symlink
#   -Yes            非交互
#   -Help           显示本帮助
#
# 做的事：
#   1. 建项目目录 + AGENTS.md（引用块由 install.ps1 注入）
#   2. 在规则库 projects/<slug>/ 建项目专属沉淀文件
#   3. 跑 install.ps1 建各 agent 入口 + 证据文件

param(
    [Parameter(Position=0)][string]$ProjectRoot = "",
    [switch]$Help,
    [switch]$All,
    [string]$AgentNums = "",
    [switch]$Copy,
    [switch]$Yes
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

if (-not $ProjectRoot) {
    Show-Usage
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VibeHome = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$Slug = Split-Path -Leaf $ProjectRoot

# ---------- 1. 创建项目目录 ----------
New-Item -ItemType Directory -Path $ProjectRoot -Force | Out-Null
$ProjectRoot = (Resolve-Path $ProjectRoot).Path

# ---------- 2. 项目专属沉淀 ----------
$ProjectSpecific = Join-Path $VibeHome "projects\$Slug"
New-Item -ItemType Directory -Path $ProjectSpecific -Force | Out-Null
if (-not (Test-Path "$ProjectSpecific\README.md")) {
    $content = @"
# $Slug 项目专属规范

> 这个文件记录 $Slug 项目特有的架构决策、历史坑、约定。
> 通用规则去 $VibeHome\global\ 和 $VibeHome\languages\。
> 项目根 AGENTS.md 的引用块里已经指向本文件，agent 每次开工都会读。

## 架构
<!-- TODO: 核心模块、数据流、关键依赖 -->

## 关键决策记录（ADR 风格）
### [YYYY-MM-DD] 决策标题
- **背景**：
- **决策**：
- **为什么**：
- **后果**：

## 本项目踩坑
<!-- 每次踩坑在这里追加，格式见 $VibeHome\global\anti-patterns.md 头部 -->
"@
    [System.IO.File]::WriteAllText((Join-Path $ProjectSpecific "README.md"), $content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "✅ 写入 $ProjectSpecific\README.md"
} else {
    Write-Host "ℹ️  $ProjectSpecific\README.md 已存在，保留不动"
}

# ---------- 3. 生成 AGENTS.md + 入口文件（交给 install.ps1，单一实现） ----------
# 注意：这里必须用「哈希表 splat」，不能用数组 splat。
# PowerShell 的数组 splat 只会按位置传参，"-AgentNums" 这种会被当成位置参数，
# 直接报 “A positional parameter cannot be found that accepts argument '-AgentNums'”。
$installParams = @{ ProjectRoot = $ProjectRoot }
if ($All)       { $installParams["All"]       = $true }
if ($AgentNums) { $installParams["AgentNums"] = $AgentNums }
if ($Copy)      { $installParams["Copy"]      = $true }
if ($Yes)       { $installParams["Yes"]       = $true }
& (Join-Path $ScriptDir "install.ps1") @installParams

Write-Host ""
Write-Host "🎉 项目 $Slug 初始化完成。"
Write-Host "   下一步："
Write-Host "   1. 编辑 $ProjectRoot\AGENTS.md 填项目信息（顶部引用块不用动）"
Write-Host "   2. 在 $ProjectSpecific\README.md 记录架构决策"

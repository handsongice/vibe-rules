# new-project.ps1 —— 初始化一个新项目的 vibe-rules 骨架（Windows PowerShell 版）
#
# 用法：
#   pwsh scripts\new-project.ps1 <项目路径> [-All] [-AgentNums 1,3,5] [-Link] [-NoPersonal] [-Copy] [-Yes]
#
# 选项：
#   -All            给所有 agent 建入口
#   -AgentNums 1,3  只建指定编号
#   -Link           外链模式（默认是自包含副本模式）
#   -NoPersonal     副本不含 personal\
#   -Copy           用复制文件代替 symlink
#   -Yes            非交互
#   -Help           显示本帮助
#
# 做的事：
#   1. 建项目目录
#   2. 跑 install.ps1：AGENTS.md + 规则副本 + 各 agent 入口
#      （项目专属笔记由 install 在 .vibe-rules\project\README.md 建档，之后永不覆盖）

param(
    [Parameter(Position=0)][string]$ProjectRoot = "",
    [switch]$Help,
    [switch]$All,
    [string]$AgentNums = "",
    [switch]$Link,
    [switch]$NoPersonal,
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

# ---------- 3. 生成 AGENTS.md + 入口文件（交给 install.ps1，单一实现） ----------
# 注意：这里必须用「哈希表 splat」，不能用数组 splat。
# PowerShell 的数组 splat 只会按位置传参，"-AgentNums" 这种会被当成位置参数，
# 直接报 “A positional parameter cannot be found that accepts argument '-AgentNums'”。
$installParams = @{ ProjectRoot = $ProjectRoot }
if ($All)        { $installParams["All"]        = $true }
if ($AgentNums)  { $installParams["AgentNums"]  = $AgentNums }
if ($Link)       { $installParams["Link"]       = $true }
if ($NoPersonal) { $installParams["NoPersonal"] = $true }
if ($Copy)       { $installParams["Copy"]       = $true }
if ($Yes)        { $installParams["Yes"]        = $true }
& (Join-Path $ScriptDir "install.ps1") @installParams

Write-Host ""
Write-Host "🎉 项目 $Slug 初始化完成。"
Write-Host "   下一步："
Write-Host "   1. 编辑 $ProjectRoot\AGENTS.md 填项目信息（顶部引用块不用动）"
Write-Host "   2. 编辑 $ProjectRoot\.vibe-rules\project\README.md 记录架构决策和历史坑"
Write-Host "   3. 把 AGENTS.md 和 .vibe-rules\ 一起提交，任何 agent、任何机器打开都能读到这些规则"

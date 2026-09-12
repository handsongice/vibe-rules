# new-project.ps1 —— 初始化一个新项目的 vibe-rules 骨架（Windows PowerShell 版）
#
# 用法：
#   pwsh C:\path\to\vibe-rules\scripts\new-project.ps1 C:\path\to\new-project

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectRoot
)

$ErrorActionPreference = "Stop"

# 从脚本位置反推规则库根目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VibeHome = Resolve-Path (Join-Path $ScriptDir "..")

$Slug = Split-Path -Leaf $ProjectRoot

# 1. 创建项目目录
New-Item -ItemType Directory -Path $ProjectRoot -Force | Out-Null
$ProjectRoot = Resolve-Path $ProjectRoot

# 2. 生成 AGENTS.md
$AgentsFile = Join-Path $ProjectRoot "AGENTS.md"
if (-not (Test-Path $AgentsFile)) {
    $template = Get-Content (Join-Path $VibeHome "templates\AGENTS.md") -Raw
    $template = $template -replace [regex]::Escape('~/.vibe'), $VibeHome
    Set-Content -Path $AgentsFile -Value $template -Encoding UTF8
    Write-Host "✅ 写入 $AgentsFile"
} else {
    Write-Host "ℹ️  $AgentsFile 已存在，保留不动"
}

# 3. 在规则库 projects/ 下建项目专属目录
$ProjectSpecific = Join-Path $VibeHome "projects\$Slug"
New-Item -ItemType Directory -Path $ProjectSpecific -Force | Out-Null

if (-not (Test-Path "$ProjectSpecific\README.md")) {
    $content = @"
# $Slug 项目专属规范

> 这个文件记录 $Slug 项目特有的架构决策、历史坑、约定。
> 通用规则去 $VibeHome\global\ 和 $VibeHome\languages\。

## 架构
<!-- TODO: 核心模块、数据流、关键依赖 -->

## 关键决策记录（ADR 风格）
### [YYYY-MM-DD] 决策标题
- **背景**：
- **决策**：
- **为什么**：
- **后果**：

## 本项目踩坑
<!-- 每次踩坑在这里追加 -->
"@
    Set-Content -Path "$ProjectSpecific\README.md" -Value $content -Encoding UTF8
    Write-Host "✅ 写入 $ProjectSpecific\README.md"
}

# 4. 跑 install.ps1
& (Join-Path $ScriptDir "install.ps1") $ProjectRoot

Write-Host ""
Write-Host "🎉 项目 $Slug 初始化完成。"
Write-Host "   1. 编辑 $AgentsFile 填项目信息"
Write-Host "   2. 在 $ProjectSpecific\README.md 记录架构决策"

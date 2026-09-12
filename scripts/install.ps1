# install.ps1 —— 在你的开发项目里接入 vibe-rules（Windows PowerShell 版）
#
# 用法：
#   pwsh C:\path\to\vibe-rules\scripts\install.ps1 [项目路径]
#
# 交互式：列出所有支持的 agent，你选哪个就生成哪个。

param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VibeHome = Resolve-Path (Join-Path $ScriptDir "..")

# 支持的 agent：num | name | type | path | 官方文档
# type: native=原生读AGENTS.md, single=symlink, dir=目录型wrapper
$Agents = @(
    @{num=1;  name="Claude Code";       type="single"; path="CLAUDE.md"},
    @{num=2;  name="Codex CLI";          type="native"; path="AGENTS.md"},
    @{num=3;  name="Cursor";            type="single"; path=".cursorrules"},
    @{num=4;  name="Cursor（新版规则）"; type="dir";    path=".cursor/rules/00-project-entry.mdc"},
    @{num=5;  name="Qoder";             type="dir";    path=".qoder/rules/00-project-entry.md"},
    @{num=6;  name="Trae";              type="dir";    path=".trae/rules/00-project-entry.md"},
    @{num=7;  name="CodeBuddy";         type="dir";    path=".codebuddy/rules/project-entry/RULE.mdc"},
    @{num=8;  name="Hermes";            type="native"; path="AGENTS.md"},
    @{num=9;  name="Kimi Code";         type="native"; path="AGENTS.md"},
    @{num=10; name="DeepSeek Harness";  type="native"; path="AGENTS.md"},
    @{num=11; name="Windsurf";          type="single"; path=".windsurfrules"},
    @{num=12; name="GitHub Copilot";   type="single"; path=".github/copilot-instructions.md"}
)

# 创建项目目录
if (-not (Test-Path $ProjectRoot)) {
    Write-Host "📁 目录不存在，自动创建：$ProjectRoot"
    New-Item -ItemType Directory -Path $ProjectRoot -Force | Out-Null
}
$ProjectRoot = Resolve-Path $ProjectRoot

Write-Host "📦 规则库：$VibeHome"
Write-Host "🎯 项目：$ProjectRoot"
Write-Host ""

# AGENTS.md
$AgentsFile = Join-Path $ProjectRoot "AGENTS.md"
if (-not (Test-Path $AgentsFile)) {
    $template = Get-Content (Join-Path $VibeHome "templates\AGENTS.md") -Raw
    $template = $template -replace [regex]::Escape('~/.vibe'), $VibeHome
    Set-Content -Path $AgentsFile -Value $template -Encoding UTF8
    Write-Host "📝 生成 AGENTS.md"
} else {
    Write-Host "ℹ️  AGENTS.md 已存在"
}

Set-Location $ProjectRoot

# 交互选择
Write-Host "你用哪个 agent？输入编号（空格分隔多选），或输入 all 全选："
Write-Host ""
foreach ($a in $Agents) {
    Write-Host ("  {0,2}. {1}" -f $a.num, $a.name)
}
Write-Host ""
$choice = Read-Host "选择"

if ($choice -eq "all") {
    $Selected = $Agents
} else {
    $nums = $choice -split '\s+'
    $Selected = $Agents | Where-Object { $nums -contains $_.num.ToString() }
}

Write-Host ""
Write-Host "🔗 创建入口文件..."

function Link-AgentFile {
    param([string]$Target, [string]$LinkPath)
    if ((Test-Path $LinkPath) -and -not ((Get-Item $LinkPath).LinkType)) {
        Write-Host "  ⚠️  跳过 $LinkPath（已存在）"
        return
    }
    Remove-Item $LinkPath -Force -ErrorAction SilentlyContinue
    try {
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $Target -ErrorAction Stop | Out-Null
        Write-Host "  ✅ $LinkPath"
    } catch {
        Copy-Item $Target $LinkPath
        Write-Host "  ✅ $LinkPath (复制)"
    }
}

function Write-Wrapper {
    param([string]$Path, [string]$Note)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if ((Test-Path $Path) -and -not ((Get-Item $Path).LinkType)) {
        Write-Host "  ⚠️  跳过 $Path（已存在）"
        return
    }
    Remove-Item $Path -Force -ErrorAction SilentlyContinue
    $content = @"
---
description: $Note
alwaysApply: true
---

# 项目入口

先读项目根目录的 ``AGENTS.md``，再读规则库 ``$VibeHome\README.md``。
不要凭记忆猜测项目约定，按这两个文件里写的来。
"@
    Set-Content -Path $Path -Value $content -Encoding UTF8
    Write-Host "  ✅ $Path"
}

foreach ($a in $Selected) {
    if ($a.type -eq "native") {
        Write-Host "  ℹ️  $($a.name) 原生读 AGENTS.md，无需额外文件"
    } elseif ($a.type -eq "single") {
        if ($a.path -eq ".github/copilot-instructions.md") {
            if (-not (Test-Path ".github")) { New-Item -ItemType Directory ".github" | Out-Null }
            Link-AgentFile "../AGENTS.md" $a.path
        } else {
            Link-AgentFile "AGENTS.md" $a.path
        }
    } elseif ($a.type -eq "dir") {
        Write-Wrapper $a.path "$($a.name) 项目入口规则"
    }
}

# 证据文件
$vibeVersion = "unknown"
if (Test-Path (Join-Path $VibeHome ".git")) {
    $vibeVersion = (git -C $VibeHome rev-parse --short HEAD 2>$null)
}
$agentsList = ($Selected | ForEach-Object { $_.num }) -join ","
@"
rules_home=$VibeHome
rules_version=$vibeVersion
installed_at=$(Get-Date -Format "yyyy-MM-dd")
agents=$agentsList
"@ | Set-Content -Path ".vibe-rules" -Encoding UTF8
Write-Host "  ✅ .vibe-rules（证据文件）"

Write-Host ""
Write-Host "🎉 完成。"

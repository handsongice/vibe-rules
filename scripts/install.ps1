# install.ps1 —— 在你的开发项目里接入 vibe-rules（Windows PowerShell 版）
#
# 用法：
#   pwsh C:\path\to\vibe-rules\scripts\install.ps1 C:\path\to\your-project
#
# 规则库放哪都行，脚本会自动定位。

param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

# 从脚本位置反推规则库根目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VibeHome = Resolve-Path (Join-Path $ScriptDir "..")
$ProjectRoot = Resolve-Path $ProjectRoot

Write-Host "📦 规则库位置：$VibeHome"
Write-Host "🎯 目标项目：$ProjectRoot"

if (-not (Test-Path $ProjectRoot)) {
    Write-Host "❌ 项目目录不存在：$ProjectRoot"
    exit 1
}

if (-not (Test-Path (Join-Path $VibeHome "README.md"))) {
    Write-Host "❌ $VibeHome 看起来不像 vibe-rules 目录"
    exit 1
}

# —— AGENTS.md ——
$AgentsFile = Join-Path $ProjectRoot "AGENTS.md"

if (-not (Test-Path $AgentsFile)) {
    $template = Get-Content (Join-Path $VibeHome "templates\AGENTS.md") -Raw
    $template = $template -replace [regex]::Escape('~/.vibe'), $VibeHome
    Set-Content -Path $AgentsFile -Value $template -Encoding UTF8
    Write-Host "📝 生成 $AgentsFile"
} else {
    Write-Host "ℹ️  $AgentsFile 已存在，保留不动"
}

Set-Location $ProjectRoot
Write-Host "🔗 创建 agent 入口文件..."

# 工具：建 symlink，失败就复制
function Link-AgentFile {
    param([string]$Target, [string]$LinkPath)

    if ((Test-Path $LinkPath) -and -not ((Get-Item $LinkPath).LinkType)) {
        Write-Host "  ⚠️  跳过 $LinkPath（已存在真实文件）"
        return
    }

    Remove-Item $LinkPath -Force -ErrorAction SilentlyContinue

    try {
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $Target -ErrorAction Stop | Out-Null
        Write-Host "  ✅ $LinkPath -> $Target (symlink)"
    } catch {
        Copy-Item $Target $LinkPath
        Write-Host "  ✅ $LinkPath (复制)"
    }
}

# 目录型 wrapper
function Write-Wrapper {
    param([string]$Path, [string]$Note)

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if ((Test-Path $Path) -and -not ((Get-Item $Path).LinkType)) {
        Write-Host "  ⚠️  跳过 $Path（已存在真实文件）"
        return
    }

    Remove-Item $Path -Force -ErrorAction SilentlyContinue

    $content = @"
---
trigger: always_on
description: $Note
---

# 项目入口

先读项目根目录的 ``AGENTS.md``，再读规则库 ``$VibeHome\README.md``。
不要凭记忆猜测项目约定，按这两个文件里写的来。
"@
    Set-Content -Path $Path -Value $content -Encoding UTF8
    Write-Host "  ✅ $Path"
}

# —— 单文件型 ——
Link-AgentFile "AGENTS.md" "CLAUDE.md"
Link-AgentFile "AGENTS.md" "CODEBUDDY.md"
Link-AgentFile "AGENTS.md" "GEMINI.md"
Link-AgentFile "AGENTS.md" "CONVENTIONS.md"
Link-AgentFile "AGENTS.md" ".cursorrules"
Link-AgentFile "AGENTS.md" ".windsurfrules"
Link-AgentFile "AGENTS.md" ".clinerules"
Link-AgentFile "AGENTS.md" ".roorules"

# GitHub Copilot
if (-not (Test-Path ".github")) { New-Item -ItemType Directory ".github" | Out-Null }
Link-AgentFile "AGENTS.md" ".github\copilot-instructions.md"

# —— 目录型 ——
Write-Wrapper ".cursor\rules\00-project-entry.mdc" "项目入口规则，始终加载"
Write-Wrapper ".windsurf\rules\00-project-entry.md" "项目入口规则，始终加载"
Write-Wrapper ".trae\rules\00-project-entry.md" "项目入口规则，始终加载"
Write-Wrapper ".qoder\rules\00-project-entry.md" "项目入口规则，始终加载"
Write-Wrapper ".codebuddy\rules\00-project-entry.md" "项目入口规则，始终加载"
Write-Wrapper ".continue\rules\00-project-entry.md" "项目入口规则，始终加载"
Write-Wrapper ".roo\rules\00-project-entry.md" "项目入口规则，始终加载"
Write-Wrapper ".kiro\steering\00-project-entry.md" "项目入口规则，始终加载"
Write-Wrapper ".amazonq\rules\00-project-entry.md" "项目入口规则，始终加载"

Write-Host ""
Write-Host "🎉 完成。已为 15+ 个主流 coding agent 创建入口文件。"
Write-Host "   规则库挪了位置？重新跑一次本脚本即可。"

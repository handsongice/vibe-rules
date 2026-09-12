# install.ps1 —— 在你的开发项目里接入 vibe-rules（Windows PowerShell 版）
#
# 用法：
#   pwsh C:\path\to\vibe-rules\scripts\install.ps1 C:\path\to\your-project
#
# 规则库放哪都行，脚本会自动定位。
# 需要 PowerShell 7+（pwsh）或 Windows PowerShell 5.1。

param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

# 从脚本位置反推规则库根目录（scripts\ 的上一级）
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VibeHome = Resolve-Path (Join-Path $ScriptDir "..")

# 转成绝对路径
$ProjectRoot = Resolve-Path $ProjectRoot

Write-Host "📦 规则库位置：$VibeHome"
Write-Host "🎯 目标项目：$ProjectRoot"

# 安全检查
if (-not (Test-Path $ProjectRoot)) {
    Write-Host "❌ 项目目录不存在：$ProjectRoot"
    exit 1
}

if (-not (Test-Path (Join-Path $VibeHome "README.md"))) {
    Write-Host "❌ $VibeHome 看起来不像 vibe-rules 目录"
    exit 1
}

# —— AGENTS.md：没有就从模板生成 ——
$AgentsFile = Join-Path $ProjectRoot "AGENTS.md"

if (-not (Test-Path $AgentsFile)) {
    $template = Get-Content (Join-Path $VibeHome "templates\AGENTS.md") -Raw
    # 把模板里的 ~/.vibe 占位替换成实际路径
    $template = $template -replace [regex]::Escape('~/.vibe'), $VibeHome
    Set-Content -Path $AgentsFile -Value $template -Encoding UTF8
    Write-Host "📝 生成 $AgentsFile（已写入规则库实际路径，记得填项目信息）"
} else {
    Write-Host "ℹ️  $AgentsFile 已存在，保留不动"
}

Set-Location $ProjectRoot
Write-Host "🔗 创建 agent 入口链接..."

# 工具：建 symlink，失败就复制（Windows symlink 需要管理员或开发者模式）
function Link-AgentFile {
    param([string]$Target, [string]$LinkPath)

    if ((Test-Path $LinkPath) -and -not ((Get-Item $LinkPath).LinkType)) {
        Write-Host "  ⚠️  跳过 $LinkPath（已存在真实文件）"
        return
    }

    Remove-Item $LinkPath -Force -ErrorAction SilentlyContinue

    # 先尝试 symlink
    try {
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $Target -ErrorAction Stop | Out-Null
        Write-Host "  ✅ $LinkPath -> $Target (symlink)"
    } catch {
        # symlink 失败（没权限），就复制内容
        Copy-Item $Target $LinkPath
        Write-Host "  ✅ $LinkPath (复制，symlink 需要管理员权限)"
    }
}

# 根目录级入口文件
Link-AgentFile "AGENTS.md" "CLAUDE.md"
Link-AgentFile "AGENTS.md" "CODEBUDDY.md"
Link-AgentFile "AGENTS.md" "GEMINI.md"
Link-AgentFile "AGENTS.md" ".cursorrules"
Link-AgentFile "AGENTS.md" ".windsurfrules"

# GitHub Copilot
$copilotDir = ".github"
if (-not (Test-Path $copilotDir)) { New-Item -ItemType Directory $copilotDir | Out-Null }
Link-AgentFile "AGENTS.md" ".github\copilot-instructions.md"

# 目录型 rules（Trae / Qoder / CodeBuddy）
foreach ($dir in @(".trae\rules", ".qoder\rules", ".codebuddy\rules")) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

function Write-Wrapper {
    param([string]$Path, [string]$Note)

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

Write-Wrapper ".trae\rules\00-project-entry.md" "项目入口规则，始终加载"
Write-Wrapper ".qoder\rules\00-project-entry.md" "项目入口规则，始终加载"
Write-Wrapper ".codebuddy\rules\00-project-entry.md" "项目入口规则，始终加载"

Write-Host ""
Write-Host "🎉 完成。各 agent 现在都会读到项目根 AGENTS.md。"
Write-Host "   规则库挪了位置？重新跑一次本脚本即可。"

# uninstall.ps1 —— 从项目中移除 vibe-rules 入口文件（Windows PowerShell 版）
#
# 用法：
#   pwsh C:\path\to\vibe-rules\scripts\uninstall.ps1 [项目路径]

param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

$VibeHome = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")
$ProjectRoot = Resolve-Path $ProjectRoot

Write-Host "🗑️  从 $ProjectRoot 移除 vibe-rules 入口文件..."
Write-Host ""

Set-Location $ProjectRoot

$removed = 0
$skipped = 0

function Remove-Link {
    param([string]$Path)
    if (Test-Path $Path) {
        $item = Get-Item $Path
        if ($item.LinkType) {
            Remove-Item $Path -Force
            Write-Host "  ✅ 删除 symlink: $Path"
            $script:removed++
        } else {
            Write-Host "  ⚠️  保留真实文件: $Path"
            $script:skipped++
        }
    }
}

function Remove-Wrapper {
    param([string]$Path)
    if (Test-Path $Path) {
        $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
        if ($content -match "vibe-rules" -or $content -match "AGENTS.md") {
            Remove-Item $Path -Force
            Write-Host "  ✅ 删除 wrapper: $Path"
            $script:removed++
        } else {
            Write-Host "  ⚠️  保留: $Path"
            $script:skipped++
        }
    }
}

# 单文件型
Remove-Link "CLAUDE.md"
Remove-Link "CODEBUDDY.md"
Remove-Link "GEMINI.md"
Remove-Link "CONVENTIONS.md"
Remove-Link ".cursorrules"
Remove-Link ".windsurfrules"
Remove-Link ".clinerules"
Remove-Link ".roorules"
Remove-Link ".github\copilot-instructions.md"

# 目录型
Remove-Wrapper ".cursor\rules\00-project-entry.mdc"
Remove-Wrapper ".windsurf\rules\00-project-entry.md"
Remove-Wrapper ".trae\rules\00-project-entry.md"
Remove-Wrapper ".qoder\rules\00-project-entry.md"
Remove-Wrapper ".codebuddy\rules\00-project-entry.md"
Remove-Wrapper ".continue\rules\00-project-entry.md"
Remove-Wrapper ".roo\rules\00-project-entry.md"
Remove-Wrapper ".kiro\steering\00-project-entry.md"
Remove-Wrapper ".amazonq\rules\00-project-entry.md"
Remove-Wrapper ".hermes\rules\00-project-entry.md"
Remove-Wrapper ".kimi\rules\00-project-entry.md"
Remove-Wrapper ".dsh\rules\00-project-entry.md"

# 证据文件
if (Test-Path ".vibe-rules") {
    Remove-Item ".vibe-rules" -Force
    Write-Host "  ✅ 删除 .vibe-rules"
    $removed++
}

Write-Host ""
Write-Host "🎉 完成。删除 $removed 个文件，保留 $skipped 个真实文件。"
Write-Host "   AGENTS.md 保留不动。"

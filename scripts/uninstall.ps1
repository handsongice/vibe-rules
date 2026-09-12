# uninstall.ps1 —— 从项目中移除 vibe-rules 入口文件（Windows PowerShell 版）
#
# 用法：
#   pwsh scripts\uninstall.ps1 [项目路径]
#
#   -Help           显示本帮助
#
# 会删除 vibe-rules 建的入口文件、.vibe-rules、AGENTS.md 顶部的引用块；
# 保留 AGENTS.md 正文和项目原有的真实文件。

param(
    [Parameter(Position=0)][string]$ProjectRoot = ".",
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
$ConfFile = Join-Path $ScriptDir "agents.conf"

if (-not (Test-Path $ProjectRoot)) {
    Write-Host "❌ 目录不存在：$ProjectRoot"
    exit 1
}
$ProjectRoot = (Resolve-Path $ProjectRoot).Path

Write-Host "🗑️  从 $ProjectRoot 移除 vibe-rules 入口文件..."
Write-Host ""

Set-Location $ProjectRoot

$script:removed = 0
$script:skipped = 0

function Remove-Link {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $item = Get-Item $Path -Force
    if ($item.LinkType) {
        Remove-Item $Path -Force
        Write-Host "  ✅ 删除 symlink: $Path"
        $script:removed++
    } else {
        $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
        if ($content -and $content.Contains("<!-- vibe-rules:begin")) {
            Remove-Item $Path -Force
            Write-Host "  ✅ 删除含引用块的文件: $Path"
            $script:removed++
        } else {
            Write-Host "  ⚠️  保留真实文件: $Path（不是 vibe-rules 建的）"
            $script:skipped++
        }
    }
}

function Remove-Wrapper {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
    if ($content -and $content -match 'vibe-rules') {
        Remove-Item $Path -Force
        Write-Host "  ✅ 删除 wrapper: $Path"
        $script:removed++
    } else {
        Write-Host "  ⚠️  保留: $Path（不是 vibe-rules 生成的）"
        $script:skipped++
    }
}

# ---------- 按单一数据源清理入口文件 ----------
if (Test-Path $ConfFile) {
    Get-Content $ConfFile | ForEach-Object {
        if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
        $p = $_ -split '\|'
        if ($p.Count -lt 5) { return }
        $type = $p[2].Trim()
        $path = $p[3].Trim()
        if ($type -eq "single") { Remove-Link $path }
        elseif ($type -eq "dir") { Remove-Wrapper $path }
    }
}

# ---------- 移除 AGENTS.md 引用块（正文保留） ----------
if (Test-Path "AGENTS.md") {
    $agentsPath = (Resolve-Path "AGENTS.md").Path
    $content = [System.IO.File]::ReadAllText($agentsPath)
    $begin = "<!-- vibe-rules:begin"
    $end = "<!-- vibe-rules:end -->"
    if ($content.Contains($begin)) {
        $b = $content.IndexOf($begin)
        $e = $content.IndexOf($end, $b)
        if ($e -ge 0) {
            $content = $content.Substring(0, $b) + $content.Substring($e + $end.Length)
            $content = $content -replace '^(\s*\r?\n)+', ''
            [System.IO.File]::WriteAllText($agentsPath, $content, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "  ✅ AGENTS.md 引用块已移除（正文保留）"
            $script:removed++
        }
    }
}

# ---------- 证据文件 ----------
if (Test-Path ".vibe-rules") {
    Remove-Item ".vibe-rules" -Force
    Write-Host "  ✅ 删除 .vibe-rules"
    $script:removed++
}

# ---------- 清理空目录 ----------
if (Test-Path $ConfFile) {
    Get-Content $ConfFile | ForEach-Object {
        if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
        $p = $_ -split '\|'
        if ($p.Count -lt 5) { return }
        if ($p[2].Trim() -ne "dir") { return }
        $dir = Split-Path -Parent $p[3].Trim()
        if ($dir -and (Test-Path $dir) -and -not (Get-ChildItem $dir -Force | Select-Object -First 1)) {
            Remove-Item $dir -Force -ErrorAction SilentlyContinue
            Write-Host "  ✅ 删除空目录: $dir"
        }
    }
}
if ((Test-Path ".github") -and -not (Get-ChildItem ".github" -Force | Select-Object -First 1)) {
    Remove-Item ".github" -Force -ErrorAction SilentlyContinue
    Write-Host "  ✅ 删除空目录: .github"
}

Write-Host ""
Write-Host "🎉 完成。删除 $script:removed 个文件，保留 $script:skipped 个真实文件。"
Write-Host "   AGENTS.md 正文保留不动。"

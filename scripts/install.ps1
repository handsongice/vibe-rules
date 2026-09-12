# install.ps1 —— 在你的开发项目里接入 vibe-rules（Windows PowerShell 版）
#
# 用法：
#   pwsh scripts\install.ps1 [项目路径] [-All] [-AgentNums 1,3,5] [-Copy] [-Yes]
#
# 选项：
#   -All            安装所有 agent 入口
#   -AgentNums 1,3  只安装指定编号（逗号或空格分隔）
#   -Copy           用真实文件复制代替 symlink（无 symlink 权限时的默认降级也一样）
#   -Yes            非交互模式（配合 -All / -AgentNums）
#   -Help           显示本帮助
#
# 幂等：可重复执行。已有 AGENTS.md 不会被覆盖，只在顶部注入/刷新引用块。

param(
    [Parameter(Position=0)][string]$ProjectRoot = ".",
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

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VibeHome = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$ConfFile = Join-Path $ScriptDir "agents.conf"

# ---------- 读取 agent 清单（单一数据源） ----------
if (-not (Test-Path $ConfFile)) {
    Write-Host "❌ 缺少 agent 清单：$ConfFile"
    exit 1
}
$AgentDefs = @()
Get-Content $ConfFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
    $p = $_ -split '\|'
    if ($p.Count -ge 5) {
        $AgentDefs += [pscustomobject]@{
            num  = $p[0].Trim()
            name = $p[1].Trim()
            type = $p[2].Trim()
            path = $p[3].Trim()
            doc  = $p[4].Trim()
        }
    }
}
if ($AgentDefs.Count -eq 0) {
    Write-Host "❌ agent 清单是空的：$ConfFile"
    exit 1
}

# ---------- 项目目录 ----------
if (-not (Test-Path $ProjectRoot)) {
    Write-Host "📁 目录不存在，自动创建：$ProjectRoot"
    New-Item -ItemType Directory -Path $ProjectRoot -Force | Out-Null
}
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$Slug = Split-Path -Leaf $ProjectRoot

Write-Host "📦 规则库：$VibeHome"
Write-Host "🎯 项目：$ProjectRoot"
Write-Host ""

# ---------- 选择 agent ----------
if ($All) {
    $Selection = "all"
} elseif ($AgentNums) {
    $Selection = $AgentNums
} elseif ($Yes) {
    $Selection = "all"
} else {
    Write-Host "你用哪个 agent？输入编号（空格或逗号分隔多选），或输入 all 全选："
    Write-Host ""
    foreach ($a in $AgentDefs) {
        Write-Host ("  {0,2}. {1}" -f $a.num, $a.name)
    }
    Write-Host ""
    $Selection = Read-Host "选择"
}

$SelectedNums = @()
if ($Selection -match '^(?i)all$') {
    foreach ($a in $AgentDefs) { $SelectedNums += $a.num }
} else {
    $tokens = ($Selection -replace ',', ' ').Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
    foreach ($t in $tokens) {
        $def = $AgentDefs | Where-Object { $_.num -eq $t } | Select-Object -First 1
        if (-not $def) {
            Write-Host "❌ 无效的 agent 编号：$t"
            Write-Host ("   可用编号：{0}" -f (($AgentDefs | ForEach-Object { $_.num }) -join ' '))
            exit 1
        }
        $SelectedNums += $def.num
    }
}
if ($SelectedNums.Count -eq 0) {
    Write-Host "❌ 没有选择任何 agent"
    exit 1
}

# ---------- 引用块 ----------
$BeginMarker = "<!-- vibe-rules:begin"
$EndMarker = "<!-- vibe-rules:end -->"
$BlockTemplate = @'
<!-- vibe-rules:begin（本块由 vibe-rules 自动维护，勿手改；重跑 install.ps1 即可刷新） -->
## 全局规则库（vibe-rules）

开始任何工作前，按下面的顺序读（路径是本机路径，不存在就跳过）：

1. **全局规则库入口**：`@VIBE_HOME@\README.md` —— 六条铁律 + 索引
2. **个人偏好层**：`@VIBE_HOME@\personal\preferences.md`
3. **个人记忆（最新 10 条）**：`@VIBE_HOME@\personal\memory.md`
4. **全局踩坑库（最新 10 条）**：`@VIBE_HOME@\global\anti-patterns.md`
5. **本项目专属沉淀**：`@VIBE_HOME@\projects\@SLUG@\README.md`（存在就读；没有可跑 new-project.ps1 建档）
6. **技术栈规范**：`@VIBE_HOME@\languages\<tech>.md`（按本项目实际栈读，不要全读）

> 规则优先级：项目内约定 > 个人偏好 > 全局规范。冲突时以更具体的一层为准，并在回复里指出冲突。
<!-- vibe-rules:end -->
'@
$Block = $BlockTemplate.Replace('@VIBE_HOME@', $VibeHome).Replace('@SLUG@', $Slug)

function Repair-LegacyTemplate {
    param([string]$File)
    $path = (Resolve-Path $File).Path
    $content = [System.IO.File]::ReadAllText($path)
    $changed = $false
    if ($content.Contains('~/.vibe')) {
        $content = $content.Replace('~/.vibe', $VibeHome)
        $changed = $true
    }
    if ($content -match '(?m)^## 0\. 必须先读') {
        $lines = $content -split "`r?`n"
        $out = New-Object System.Collections.Generic.List[string]
        $skip = $false
        foreach ($line in $lines) {
            if ($line -match '^## 0\. 必须先读') { $skip = $true; continue }
            if ($skip -and $line -match '^---\s*$') { $skip = $false; continue }
            if ($skip) { continue }
            $out.Add($line)
        }
        $content = ($out -join "`n")
        $changed = $true
    }
    if ($changed) {
        [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "🧹 已清理旧版模板残留（旧路径 / 旧「必须先读」章节）"
    }
}

function Add-VibeBlock {
    param([string]$File)
    $path = (Resolve-Path $File).Path
    $content = [System.IO.File]::ReadAllText($path)
    $nl = "`n"
    if ($content.Contains("`r`n")) { $nl = "`r`n" }
    $blockText = ($Block -replace "`n", $nl)

    if ($content.Contains($BeginMarker)) {
        $b = $content.IndexOf($BeginMarker)
        $e = $content.IndexOf($EndMarker, $b)
        if ($e -lt 0) { throw "AGENTS.md 里的 vibe-rules 引用块不完整（缺少结束标记）" }
        $content = $content.Substring(0, $b) + $blockText + $content.Substring($e + $EndMarker.Length)
        Write-Host "🔄 AGENTS.md 引用块已刷新"
    } elseif ([string]::IsNullOrWhiteSpace($content)) {
        $content = $blockText + $nl
        Write-Host "📝 已向空 AGENTS.md 写入引用块"
    } elseif ($content.StartsWith("---")) {
        $lines = $content -split "`r?`n"
        $endIdx = -1
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -eq "---") { $endIdx = $i; break }
        }
        if ($endIdx -gt 0) {
            $head = ($lines[0..$endIdx] -join $nl)
            $tail = ""
            if ($endIdx + 1 -lt $lines.Count) {
                $tail = ($lines[($endIdx + 1)..($lines.Count - 1)] -join $nl)
            }
            $content = $head + $nl + $nl + $blockText + $nl + $tail
        } else {
            $content = $blockText + $nl + $nl + $content
        }
        Write-Host "📝 已向 AGENTS.md 注入规则库引用块"
    } else {
        $content = $blockText + $nl + $nl + $content
        Write-Host "📝 已向已有 AGENTS.md 注入规则库引用块"
    }
    [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------- AGENTS.md ----------
Set-Location $ProjectRoot
$AgentsFile = Join-Path $ProjectRoot "AGENTS.md"
if (-not (Test-Path $AgentsFile)) {
    Copy-Item (Join-Path $VibeHome "templates\AGENTS.md") $AgentsFile
    Write-Host "📝 生成 AGENTS.md（来自模板）"
}
Repair-LegacyTemplate $AgentsFile
Add-VibeBlock $AgentsFile

# ---------- 入口文件工具函数 ----------
function Link-AgentFile {
    param([string]$Target, [string]$LinkPath)
    $linkDir = Split-Path -Parent $LinkPath
    if ($linkDir -and -not (Test-Path $linkDir)) {
        New-Item -ItemType Directory -Path $linkDir -Force | Out-Null
    }
    if (Test-Path $LinkPath) {
        $item = Get-Item $LinkPath -Force
        if (-not $item.LinkType) {
            Write-Host "  ⚠️  跳过 $LinkPath（已存在真实文件，不动它）"
            return
        }
        Remove-Item $LinkPath -Force -ErrorAction SilentlyContinue
    }
    # 复制源要相对「链接所在目录」解析（Copilot 的 ../AGENTS.md 就是为此）
    $src = if ($linkDir) { Join-Path $linkDir $Target } else { $Target }
    if ($Copy) {
        Copy-Item $src $LinkPath
        Write-Host "  ✅ $LinkPath（复制）"
        return
    }
    try {
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $Target -ErrorAction Stop | Out-Null
        Write-Host "  ✅ $LinkPath"
    } catch {
        Copy-Item $src $LinkPath
        Write-Host "  ✅ $LinkPath（复制，symlink 不可用）"
    }
}

function Write-Wrapper {
    param([string]$Path, [string]$Note)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Test-Path $Path) {
        $existing = Get-Content $Path -Raw -ErrorAction SilentlyContinue
        if ($existing -notmatch 'vibe-rules') {
            Write-Host "  ⚠️  跳过 $Path（已存在且不是 vibe-rules 生成的）"
            return
        }
        Remove-Item $Path -Force
    }
    $wrapper = @"
---
description: $Note
alwaysApply: true
---

<!-- vibe-rules:managed（本文件由 vibe-rules 自动生成，勿手改；重跑 install.ps1 刷新） -->

# 项目入口

先读项目根目录 ``AGENTS.md`` 顶部的 vibe-rules 引用块，按其中顺序加载规则库。
不要凭记忆猜测项目约定，按规则库和 AGENTS.md 里写的来。
"@
    Set-Content -Path $Path -Value $wrapper -Encoding UTF8
    Write-Host "  ✅ $Path"
}

# ---------- 创建入口文件 ----------
Write-Host ""
Write-Host "🔗 创建入口文件..."
foreach ($a in $AgentDefs) {
    if ($SelectedNums -notcontains $a.num) { continue }
    if ($a.type -eq "native") {
        Write-Host "  ℹ️  $($a.name) 原生读 AGENTS.md，无需额外入口文件"
    } elseif ($a.type -eq "single") {
        if ($a.path -like ".github/*") {
            Link-AgentFile "../AGENTS.md" $a.path
        } else {
            Link-AgentFile "AGENTS.md" $a.path
        }
    } elseif ($a.type -eq "dir") {
        Write-Wrapper $a.path "$($a.name) 项目入口规则"
    }
}

# ---------- 证据文件 ----------
$vibeVersion = "unknown"
if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $VibeHome ".git"))) {
    try {
        $v = & git -C $VibeHome rev-parse --short HEAD 2>$null
        if ($v) { $vibeVersion = $v.Trim() }
    } catch { }
}
$agentsList = ($SelectedNums -join ",")
$evidence = @"
rules_home=$VibeHome
rules_version=$vibeVersion
installed_at=$(Get-Date -Format "yyyy-MM-dd")
project=$ProjectRoot
agents=$agentsList
"@
[System.IO.File]::WriteAllText((Join-Path $ProjectRoot ".vibe-rules"), $evidence, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  ✅ .vibe-rules（证据文件，agents=$agentsList）"

Write-Host ""
Write-Host "🎉 完成。"
Write-Host "   验证：pwsh $VibeHome\scripts\verify.ps1 $ProjectRoot"
Write-Host ""
Write-Host "   提示："
Write-Host "   - .vibe-rules 记录的是本机绝对路径，建议加入项目 .gitignore（不要提交）"
Write-Host "   - 规则库搬家后，重跑本脚本会自动刷新路径"

# verify.ps1 —— 检查项目是否正确接入 vibe-rules（Windows PowerShell 版）
#
# 用法：
#   pwsh scripts\verify.ps1 [项目路径]
#
#   -Help           显示本帮助
#
# 只检查 .vibe-rules 证据文件里记录过的 agent，不会因为「没装某个 agent」报错。

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
Set-Location $ProjectRoot

Write-Host "🔍 检查 $ProjectRoot"
Write-Host ""

$script:PASS = 0
$script:FAIL = 0
function Ok   { param([string]$m) Write-Host "  ✅ $m"; $script:PASS++ }
function Bad  { param([string]$m) Write-Host "  ❌ $m"; $script:FAIL++ }
function Warn { param([string]$m) Write-Host "  ⚠️  $m" }

# ---------- 1. 证据文件 ----------
if (-not (Test-Path ".vibe-rules")) {
    Write-Host "  ❌ 未接入：缺少 .vibe-rules 证据文件"
    Write-Host ""
    Write-Host "🔧 修复："
    Write-Host "   pwsh $VibeHome\scripts\install.ps1 $ProjectRoot"
    exit 1
}
Ok ".vibe-rules 证据文件存在"

$rulesHome = ""
$installed = ""
foreach ($line in ((Get-Content ".vibe-rules" -Raw) -split "`r?`n")) {
    if ($line -like "rules_home=*") { $rulesHome = $line.Substring(11).Trim() }
    if ($line -like "agents=*") { $installed = $line.Substring(7).Trim() }
}

# ---------- 2. 规则库本体 ----------
if ($rulesHome -and (Test-Path $rulesHome)) {
    Ok "规则库路径有效：$rulesHome"
} else {
    Bad "规则库路径失效：$rulesHome（被移动或删除？重跑 install.ps1）"
}
if ($rulesHome -and (Test-Path (Join-Path $rulesHome "README.md"))) {
    Ok "规则库入口存在：README.md"
} else {
    Bad "规则库入口缺失：$rulesHome\README.md"
}
foreach ($extra in @("personal\preferences.md", "personal\memory.md", "global\anti-patterns.md")) {
    if (-not ($rulesHome -and (Test-Path (Join-Path $rulesHome $extra)))) {
        Warn "规则库中缺少 $extra（AGENTS.md 引用块会指向空路径）"
    }
}

# ---------- 3. AGENTS.md 引用块 ----------
if (Test-Path "AGENTS.md") {
    Ok "项目根有 AGENTS.md"
    $agentsMd = Get-Content "AGENTS.md" -Raw
    if ($agentsMd -match [regex]::Escape("<!-- vibe-rules:begin")) {
        Ok "AGENTS.md 含 vibe-rules 引用块"
        if ($rulesHome -and $agentsMd.Contains($rulesHome)) {
            Ok "引用块指向当前规则库路径"
        } else {
            Bad "引用块里的规则库路径不是当前路径（重跑 install.ps1 即可刷新）"
        }
    } else {
        Bad "AGENTS.md 缺少 vibe-rules 引用块（重跑 install.ps1 注入）"
    }
} else {
    Bad "项目根没有 AGENTS.md"
}

# ---------- 4. 入口文件（只查装过的） ----------
if (-not (Test-Path $ConfFile)) {
    Bad "缺少 agent 清单：$ConfFile"
} else {
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
            }
        }
    }
    $installedNums = @()
    if ($installed) {
        $installedNums = $installed.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    Write-Host ""
    Write-Host "🔗 已安装 agent 的入口文件："
    foreach ($a in $AgentDefs) {
        if ($installedNums -notcontains $a.num) { continue }
        switch ($a.type) {
            "native" {
                Ok "$($a.name)：原生读 AGENTS.md"
            }
            "single" {
                if (-not (Test-Path $a.path)) {
                    Bad "$($a.path) 不存在"
                } else {
                    $item = Get-Item $a.path -Force
                    if ($item.LinkType) {
                        Ok "$($a.path)（symlink）"
                    } elseif ((Get-Content $a.path -Raw) -match [regex]::Escape("<!-- vibe-rules:begin")) {
                        Ok "$($a.path)（复制文件，含引用块）"
                    } else {
                        Bad "$($a.path) 是真实文件且不含 vibe-rules 引用块"
                    }
                }
            }
            "dir" {
                if (-not (Test-Path $a.path)) {
                    Bad "$($a.path) 不存在"
                } elseif ((Get-Content $a.path -Raw) -match 'vibe-rules') {
                    Ok "$($a.path)"
                } else {
                    Bad "$($a.path) 存在但不是 vibe-rules 生成的文件"
                }
            }
        }
    }
}

# ---------- 汇总 ----------
Write-Host ""
Write-Host "📊 结果：$script:PASS 通过，$script:FAIL 未通过"

if ($script:FAIL -gt 0) {
    Write-Host ""
    Write-Host "🔧 修复：重跑 install（幂等，不会覆盖你的 AGENTS.md 正文）"
    Write-Host "   pwsh $VibeHome\scripts\install.ps1 $ProjectRoot"
    exit 1
}

Write-Host ""
Write-Host "🎉 项目已正确接入 vibe-rules。"

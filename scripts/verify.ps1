# verify.ps1 —— 检查项目是否正确接入 vibe-rules（Windows PowerShell 版）
#
# 用法：
#   pwsh scripts\verify.ps1 [项目路径]
#
#   -Help           显示本帮助
#
# 只检查 .vibe-rules\installed 证据文件里记录过的 agent，不会因为「没装某个 agent」报错。
# 两种模式都支持：embedded（自包含副本，校验 .vibe-rules\ 副本）、link（外链本机规则库）。

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
foreach ($pat in @("ModuleAnalysisCache*", "StartupProfileData*")) {
    Get-ChildItem -Path $ProjectRoot -Filter $pat -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

Write-Host ""

$script:PASS = 0
$script:FAIL = 0
function Ok   { param([string]$m) Write-Host "  ✅ $m"; $script:PASS++ }
function Bad  { param([string]$m) Write-Host "  ❌ $m"; $script:FAIL++ }
function Warn { param([string]$m) Write-Host "  ⚠️  $m" }

# ---------- 1. 证据文件 ----------
$evidence = ""
if (Test-Path ".vibe-rules\installed") {
    $evidence = ".vibe-rules\installed"
} elseif ((Test-Path ".vibe-rules") -and -not (Test-Path ".vibe-rules" -PathType Container)) {
    $evidence = ".vibe-rules"
}
if (-not $evidence) {
    Write-Host "  ❌ 未接入：缺少 .vibe-rules\installed 证据文件"
    Write-Host ""
    Write-Host "🔧 修复："
    Write-Host "   pwsh $VibeHome\scripts\install.ps1 $ProjectRoot"
    exit 1
}
Ok "证据文件存在：$evidence"

$mode = ""; $rulesHome = ""; $rulesVersion = ""; $installed = ""; $profile = ""
foreach ($line in ((Get-Content $evidence -Raw) -split "`r?`n")) {
    if ($line -like "mode=*") { $mode = $line.Substring(5).Trim() }
    if ($line -like "rules_home=*") { $rulesHome = $line.Substring(11).Trim() }
    if ($line -like "rules_version=*") { $rulesVersion = $line.Substring(14).Trim() }
    if ($line -like "agents=*") { $installed = $line.Substring(7).Trim() }
    if ($line -like "profile=*") { $profile = $line.Substring(8).Trim() }
}
if (-not $profile) { $profile = "default" }   # 兼容旧版证据文件
if (-not $mode) { $mode = "link" }   # 兼容旧版证据文件
if ($mode -eq "embedded" -or $mode -eq "link") {
    Ok "模式：$mode"
} else {
    Bad "证据文件 mode 值无效：$mode（应为 embedded 或 link）"
}

# ---------- 2. 规则本体 ----------
if ($mode -eq "embedded") {
    if (Test-Path ".vibe-rules\README.md") { Ok "副本入口存在：.vibe-rules\README.md" }
    else { Bad "副本入口缺失：.vibe-rules\README.md（重跑 install.ps1 刷新副本）" }

    foreach ($extra in @("global\iron-rules.md", "global\anti-patterns.md", "skills\README.md")) {
        if (Test-Path (Join-Path ".vibe-rules" $extra)) { Ok "副本含 $extra" }
        else { Bad "副本缺少 $extra" }
    }
    if (Test-Path ".vibe-rules\languages") { Ok "副本含 languages\（技术栈规范）" }
    else { Bad "副本缺少 languages\" }

    if (Test-Path ".vibe-rules\project\README.md") { Ok "项目专属笔记存在：.vibe-rules\project\README.md" }
    else { Warn "缺少 .vibe-rules\project\README.md（重跑 install.ps1 会建档，且不会覆盖已有内容）" }

    if (Test-Path ".vibe-rules\personal\preferences.md") { Ok "副本含 personal\（个人偏好与记忆）" }
    elseif ($profile -eq "hybrid") { Ok "副本不含 personal\（混合档：个人层走本机外链，符合预期）" }
    else { Warn "副本不含 personal\（安装时用了 -NoPersonal，属正常）" }
} else {
    if ($rulesHome -and (Test-Path $rulesHome)) { Ok "规则库路径有效：$rulesHome" }
    else { Bad "规则库路径失效：$rulesHome（被移动或删除？重跑 install.ps1）" }

    if ($rulesHome -and (Test-Path (Join-Path $rulesHome "README.md"))) { Ok "规则库入口存在：README.md" }
    else { Bad "规则库入口缺失：$rulesHome\README.md" }

    foreach ($extra in @("personal\preferences.md", "personal\memory.md", "global\anti-patterns.md")) {
        if (-not ($rulesHome -and (Test-Path (Join-Path $rulesHome $extra)))) {
            Warn "规则库中缺少 $extra（AGENTS.md 引用块会指向空路径）"
        }
    }
}

# ---------- 2b. 策略档位（本地/团队策略有没有真的落实） ----------
$ignoresVibe = $false
if (Test-Path ".gitignore") {
    if (Get-Content ".gitignore" | Where-Object { $_ -match '^\s*/?\.vibe-rules/?\s*$' }) { $ignoresVibe = $true }
}

switch ($profile) {
    "default" { Ok "策略档位：default（未指定，按细粒度选项走）" }
    "team" {
        Ok "策略档位：team（团队共享）"
        if ($mode -ne "embedded") {
            Bad "团队档要求自包含副本模式，实际是 $mode（重跑 install.ps1 -Profile team）"
        }
        if (Test-Path ".vibe-rules\personal") {
            Bad "团队档副本里不该有 personal\（个人偏好会跟着进仓库；重跑 install.ps1 -Profile team）"
        } else {
            Ok "团队档：副本不含 personal\"
        }
        if ($ignoresVibe) {
            Bad "团队档：.gitignore 忽略了 .vibe-rules\，副本进不了仓库（队友/云端/CI 读不到）"
        } else {
            Ok "团队档：.vibe-rules\ 没有被 .gitignore 排除"
        }
    }
    "hybrid" {
        Ok "策略档位：hybrid（副本进仓库 + personal 本机外链）"
        if ($mode -ne "embedded") {
            Bad "混合档要求自包含副本模式，实际是 $mode（重跑 install.ps1 -Profile hybrid）"
        }
        if (Test-Path ".vibe-rules\personal") {
            Bad "混合档副本里不该有 personal\（个人偏好会跟着进仓库；重跑 install.ps1 -Profile hybrid）"
        } else {
            Ok "混合档：副本不含 personal\"
        }
        if ($ignoresVibe) {
            Bad "混合档：.gitignore 忽略了 .vibe-rules\，副本进不了仓库（队友/云端/CI 读不到）"
        } else {
            Ok "混合档：.vibe-rules\ 没有被 .gitignore 排除"
        }
        $personalDir = Join-Path $rulesHome "personal"
        if ($rulesHome -and (Test-Path $personalDir)) {
            Ok "混合档：本机个人层存在（$personalDir）"
        } else {
            Warn "混合档：本机规则库里没有 personal\（换台机器就读不到个人偏好）"
        }
        $personalRef = ($personalDir -replace '\\', '/')
        $agentsText = ""
        if (Test-Path "AGENTS.md") { $agentsText = Get-Content "AGENTS.md" -Raw }
        if ($personalRef -and $agentsText.Contains($personalRef)) {
            Ok "混合档：AGENTS.md 第 3 条指向本机 personal\"
        } else {
            Bad "混合档：AGENTS.md 没指向本机 personal\（重跑 install.ps1 -Profile hybrid）"
        }
    }
    "personal" {
        Ok "策略档位：personal（个人自用）"
        if ($mode -ne "link") {
            Bad "个人档要求外链模式，实际是 $mode（重跑 install.ps1 -Profile personal）"
        }
        if (-not $ignoresVibe) {
            Warn "个人档：.vibe-rules 没被 .gitignore 忽略，本机路径会被提交（加一行 .vibe-rules 即可）"
        } else {
            Ok "个人档：.vibe-rules 已被 .gitignore 忽略"
        }
    }
    default { Bad "证据文件 profile 值无效：$profile（应为 team / hybrid / personal / default）" }
}

# 项目文档约定（规格驱动）：副本模式下由 install 建档
if ($mode -eq "embedded") {
    foreach ($docDir in @("docs\specs", "docs\plans")) {
        if (Test-Path (Join-Path $docDir "README.md")) {
            Ok "文档约定已就位：$docDir\README.md"
        } else {
            Warn "缺少 $docDir\README.md（重跑 install.ps1 会建档，且不会覆盖已有内容）"
        }
    }
}

# ---------- 3. AGENTS.md 引用块 ----------
if (Test-Path "AGENTS.md") {
    Ok "项目根有 AGENTS.md"
    $agentsMd = Get-Content "AGENTS.md" -Raw
    if ($agentsMd -match [regex]::Escape("<!-- vibe-rules:begin")) {
        Ok "AGENTS.md 含 vibe-rules 引用块"
        if ($mode -eq "embedded") {
            if ($agentsMd.Contains(".vibe-rules/README.md")) { Ok "引用块指向项目内副本（.vibe-rules/）" }
            else { Bad "引用块不是指向项目内副本（重跑 install.ps1 刷新）" }
        } else {
            $rulesHomeFwd = $rulesHome -replace '\\', '/'
            if ($rulesHome -and ($agentsMd.Contains($rulesHome) -or $agentsMd.Contains($rulesHomeFwd))) { Ok "引用块指向当前规则库路径" }
            else { Bad "引用块里的规则库路径不是当前路径（重跑 install.ps1 即可刷新）" }
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
            "native" { Ok "$($a.name)：原生读 AGENTS.md" }
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
                if (-not (Test-Path $a.path)) { Bad "$($a.path) 不存在" }
                elseif ((Get-Content $a.path -Raw) -match 'vibe-rules') { Ok "$($a.path)" }
                else { Bad "$($a.path) 存在但不是 vibe-rules 生成的文件" }
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

# install.ps1 —— 在你的开发项目里接入 vibe-rules（Windows PowerShell 版）
#
# 用法：
#   pwsh scripts\install.ps1 [项目路径] [-All] [-AgentNums 1,3,5] [-Link] [-NoPersonal] [-Profile team|hybrid|personal] [-Copy] [-Yes] [-WithCi]
#
# 选项：
#   -All            安装所有 agent 入口
#   -AgentNums 1,3  只安装指定编号（逗号或空格分隔）
#   -AgentNums 0    通用项：只留根目录 AGENTS.md，不建任何额外入口文件
#                   （Android Studio 等原生读 AGENTS.md 的工具用这个）
#   -Link           外链模式：规则本体留在本机规则库，引用块用绝对路径（默认是自包含副本模式）
#   -NoPersonal     副本里不含 personal\（个人偏好与记忆不进项目仓库）
#   -Profile team      团队档：强制自包含副本 + 不含 personal\，并要求副本真的能进仓库
#   -Profile hybrid    混合档：副本进仓库，但 personal\ 不进仓库、只在本机外链
#   -Profile personal  个人档：强制外链模式（规则不落进仓库），个人层照常带上
#   -Copy           入口用真实文件复制代替 symlink（无 symlink 权限时的默认降级也一样）
#   -WithCi         生成 .github\workflows\vibe-rules-verify.yml（PR 上校验副本漂移 + 接入完整性；只对副本模式有意义）
#   -Yes            非交互模式（配合 -All / -AgentNums）
#   -Help           显示本帮助
#
# 默认行为（自包含副本模式）：规则复制进项目 .vibe-rules\，AGENTS.md 引用块用相对路径。
# 队友 clone、云端 agent、CI 都能直接读到，不依赖任何人的本机路径。
# 项目专属笔记在 .vibe-rules\project\README.md，只在不存在时建档，之后永不覆盖。
#
# 幂等：可重复执行。已有 AGENTS.md 不会被覆盖，只在顶部注入/刷新引用块。

param(
    [Parameter(Position=0)][string]$ProjectRoot = ".",
    [switch]$Help,
    [switch]$All,
    [string]$AgentNums = "",
    [switch]$Link,
    [switch]$NoPersonal,
    [string]$Profile = "default",
    [switch]$Copy,
    [switch]$WithCi,
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

# ---------- 策略档位（本地/团队策略在脚本层收口，不靠人记） ----------
$PersonalRef = ""   # 空 = 个人层跟着规则本体；hybrid 档指向本机规则库
switch ($Profile) {
    "default" { }
    "team" {
        if ($Link) {
            Write-Host "❌ -Profile team 与 -Link 矛盾：团队档要求规则副本进仓库，外链模式做不到"
            exit 1
        }
        $NoPersonal = $true
    }
    "hybrid" {
        if ($Link) {
            Write-Host "❌ -Profile hybrid 与 -Link 矛盾：混合档要求规则副本进仓库（只有 personal 走外链）"
            exit 1
        }
        if ($NoPersonal) {
            Write-Host "❌ -Profile hybrid 与 -NoPersonal 矛盾：混合档就是要把个人层接上（本机外链）"
            exit 1
        }
        # 副本里不含 personal\，改用本机规则库的 personal\（绝对路径）
        $NoPersonal = $true
        $PersonalRef = (Join-Path $VibeHome "personal") -replace '\\', '/'
    }
    "personal" {
        if ($NoPersonal) {
            Write-Host "❌ -Profile personal 与 -NoPersonal 矛盾：个人档就是要把个人层带上"
            exit 1
        }
        $Link = $true
    }
    default {
        Write-Host "❌ -Profile 只支持 team / hybrid / personal，收到：$Profile"
        exit 1
    }
}

# ---------- 模式与规则本体 ----------
if ($Link) { $Mode = "link" } else { $Mode = "embedded" }
switch ($Profile) {
    "team"     { Write-Host "🧭 策略档位：team（团队共享：副本进仓库 + 不含 personal）" }
    "hybrid"   { Write-Host "🧭 策略档位：hybrid（副本进仓库；personal 不进仓库，只在本机外链）" }
    "personal" { Write-Host "🧭 策略档位：personal（个人自用：外链模式，规则不进仓库）" }
    default    { Write-Host "🧭 策略档位：default（未指定，按上面选的模式走）" }
}
$RulesDir = Join-Path $ProjectRoot ".vibe-rules"
$PersonalNote = "（有就读）"

if ($Mode -eq "embedded") {
    Write-Host "📦 模式：自包含副本（规则复制进 $RulesDir，引用块用相对路径）"
} else {
    Write-Host "📦 模式：外链（规则留在本机，引用块指向 $VibeHome）"
}

if ($Mode -eq "embedded") {
    if ($VibeHome -eq $ProjectRoot) {
        Write-Host "❌ 项目路径不能是规则库本身（会把副本复制进自己）"
        exit 1
    }

    # 旧版把证据文件写成项目根的 .vibe-rules（普通文件），会挡住副本目录：识别并升级掉
    if ((Test-Path -LiteralPath $RulesDir) -and -not (Test-Path -LiteralPath $RulesDir -PathType Container)) {
        $legacyText = Get-Content -LiteralPath $RulesDir -Raw -ErrorAction SilentlyContinue
        if ($legacyText -match "(?m)^rules_home=") {
            Write-Host "🧹 检测到旧版证据文件 .vibe-rules（外链时代遗留），升级为副本目录"
            Remove-Item -LiteralPath $RulesDir -Force
        } else {
            Write-Host "❌ $RulesDir 已存在且不是 vibe-rules 生成的证据文件，请先手动处理后重试"
            exit 1
        }
    }

    Write-Host "📄 复制规则副本 → $RulesDir"
    New-Item -ItemType Directory -Path $RulesDir -Force | Out-Null

    # 排除清单：工具本身和项目专属笔记不进副本
    # 排除清单：工具与打包清单不跟着项目走（项目只需要规则本体）
    $exclude = @(".git", ".github", ".gitignore", ".gitattributes", "scripts", "tests", "templates",
                 "projects", "project", "inbox", ".agents", ".claude-plugin", ".codex-plugin",
                 "VERSION", "CHANGELOG.md", ".pre-commit-config.yaml", "RELEASE-NOTES.md")
    $rootLen = $VibeHome.Length + 1
    Get-ChildItem -Path $VibeHome -Recurse -Force | ForEach-Object {
        $rel = $_.FullName.Substring($rootLen)
        $top = ($rel -split '[\\/]')[0]
        if ($exclude -contains $top) { return }
        if ($_.Name -like "StartupProfileData*" -or $_.Name -like "ModuleAnalysisCache*") { return }
        if ($NoPersonal -and $top -eq "personal") { return }
        $dest = Join-Path $RulesDir $rel
        if ($_.PSIsContainer) {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
        } else {
            $destDir = Split-Path -Parent $dest
            if ($destDir -and -not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
        }
    }

    # 清掉旧版曾装进来的打包产物（保持幂等，也让 --purge-project 能删净）
    foreach ($stale in @(".agents", ".claude-plugin", ".codex-plugin", "VERSION", "CHANGELOG.md", ".gitattributes",
                         ".pre-commit-config.yaml", "RELEASE-NOTES.md")) {
        $stalePath = Join-Path $RulesDir $stale
        if (Test-Path -LiteralPath $stalePath) {
            Remove-Item -LiteralPath $stalePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # pwsh 运行时垃圾（旧版可能带进副本）：清掉，保证副本干净、-PurgeProject 能删净
    foreach ($pat in @("ModuleAnalysisCache*", "StartupProfileData*")) {
        Get-ChildItem -Path $RulesDir -Filter $pat -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    # -NoPersonal 时清掉上一轮遗留的 personal\（保持幂等）
    if ($NoPersonal) {
        $stalePersonal = Join-Path $RulesDir "personal"
        if (Test-Path $stalePersonal) {
            Remove-Item $stalePersonal -Recurse -Force
        }
    }

    $InstalledAt = (Get-Date -Format "yyyy-MM-dd")
    $vibeVersionForEntry = "unknown"
    if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $VibeHome ".git"))) {
        try {
            $v = & git -C $VibeHome rev-parse --short HEAD 2>$null
            if ($v) { $vibeVersionForEntry = $v.Trim() }
        } catch { }
    }
    $entry = Get-Content (Join-Path $VibeHome "templates\ENTRY.md") -Raw
    $entry = $entry.Replace("@VIBE_VERSION@", $vibeVersionForEntry).Replace("@INSTALLED_AT@", $InstalledAt)
    [System.IO.File]::WriteAllText((Join-Path $RulesDir "README.md"), $entry, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "   ✅ README.md（副本入口指南）"

    $notesFile = Join-Path $RulesDir "project\README.md"
    if (-not (Test-Path $notesFile)) {
        New-Item -ItemType Directory -Path (Join-Path $RulesDir "project") -Force | Out-Null
        $notes = Get-Content (Join-Path $VibeHome "templates\PROJECT-NOTES.md") -Raw
        $notes = $notes.Replace("@SLUG@", $Slug)
        [System.IO.File]::WriteAllText($notesFile, $notes, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "   ✅ project\README.md（项目专属笔记，之后不会被覆盖）"
    } else {
        Write-Host "   ℹ️  project\README.md 已存在，保留不动"
    }

    # 项目文档约定（规格驱动）：设计文档 docs\specs\、实现计划 docs\plans\
    # 同样只在不存在时建档，永不覆盖用户已有内容
    foreach ($docDir in @("specs", "plans")) {
        $docPath = Join-Path $ProjectRoot "docs\$docDir"
        if (-not (Test-Path $docPath)) { New-Item -ItemType Directory -Path $docPath -Force | Out-Null }
    }
    $specsReadme = Join-Path $ProjectRoot "docs\specs\README.md"
    if (-not (Test-Path $specsReadme)) {
        $tpl = (Get-Content (Join-Path $VibeHome "templates\DOCS-SPECS.md") -Raw).Replace("@SLUG@", $Slug)
        [System.IO.File]::WriteAllText($specsReadme, $tpl, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "   ✅ docs\specs\README.md（设计文档约定）"
    }
    $plansReadme = Join-Path $ProjectRoot "docs\plans\README.md"
    if (-not (Test-Path $plansReadme)) {
        $tpl = (Get-Content (Join-Path $VibeHome "templates\DOCS-PLANS.md") -Raw).Replace("@SLUG@", $Slug)
        [System.IO.File]::WriteAllText($plansReadme, $tpl, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "   ✅ docs\plans\README.md（实现计划约定）"
    }
} else {
    $linkNotes = Join-Path $VibeHome "projects\$Slug"
    if (-not (Test-Path (Join-Path $linkNotes "README.md"))) {
        New-Item -ItemType Directory -Path $linkNotes -Force | Out-Null
        $notes = Get-Content (Join-Path $VibeHome "templates\PROJECT-NOTES.md") -Raw
        $notes = $notes.Replace("@SLUG@", $Slug)
        [System.IO.File]::WriteAllText((Join-Path $linkNotes "README.md"), $notes, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "📝 规则库里建了项目专属笔记：$linkNotes\README.md"
    }
}

# ---------- GitHub Action（可选）：PR 上校验副本漂移 + 接入完整性 ----------
if ($WithCi) {
    if ($Mode -ne "embedded") {
        Write-Host "⏭️  -WithCi 跳过：外链模式的规则库在本机，CI 里读不到（要 CI 校验请用副本模式）"
    } else {
        $ciFile = Join-Path $ProjectRoot ".github\workflows\vibe-rules-verify.yml"
        $ciOurs = $false
        if (Test-Path $ciFile) {
            $ciHead = Get-Content -LiteralPath $ciFile -TotalCount 40 -ErrorAction SilentlyContinue
            if ($ciHead -match 'vibe-rules install --with-ci 生成') { $ciOurs = $true }
        }
        if ((Test-Path $ciFile) -and -not $ciOurs) {
            Write-Host "   ℹ️  .github\workflows\vibe-rules-verify.yml 已存在且不是 vibe-rules 生成的，保留不动"
            Write-Host "       （想换成模板：手动复制 $VibeHome\templates\CI-VERIFY.yml）"
        } else {
            $rulesRepo = $null
            try { $rulesRepo = & git -C $VibeHome remote get-url origin 2>$null } catch { }
            if (-not $rulesRepo) { $rulesRepo = "https://github.com/handsongice/vibe-rules.git" }
            $rulesRepo = $rulesRepo.Trim()
            if ($rulesRepo -like "git@github.com:*") {
                $rulesRepo = "https://github.com/" + $rulesRepo.Substring("git@github.com:".Length)
            }
            $rulesSha = $null
            try { $rulesSha = & git -C $VibeHome rev-parse HEAD 2>$null } catch { }
            if (-not $rulesSha) { $rulesSha = "main" }
            $rulesSha = $rulesSha.Trim()
            if ($rulesSha -ne "main") {
                $hasRemote = $false
                try { $hasRemote = [bool](& git -C $VibeHome branch -r --contains HEAD 2>$null) } catch { }
                if (-not $hasRemote) {
                    Write-Host "   ⚠️  本机规则库的 HEAD 还没推到远端：CI 里可能拉不到这个 commit（先 push，或改 workflow 里的 VIBE_RULES_SHA）"
                }
            }
            $ciDir = Split-Path -Parent $ciFile
            if (-not (Test-Path $ciDir)) { New-Item -ItemType Directory -Path $ciDir -Force | Out-Null }
            $ciTpl = [System.IO.File]::ReadAllText((Join-Path $VibeHome "templates\CI-VERIFY.yml"))
            $ciTpl = $ciTpl.Replace("@VIBE_REPO@", $rulesRepo).Replace("@VIBE_SHA@", $rulesSha)
            [System.IO.File]::WriteAllText($ciFile, $ciTpl, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "   ✅ .github\workflows\vibe-rules-verify.yml（PR 上校验副本漂移 + 接入完整性）"
        }
    }
}

# ---------- 引用块 ----------
$BeginMarker = "<!-- vibe-rules:begin"
$EndMarker = "<!-- vibe-rules:end -->"
if ($Mode -eq "embedded" -and $PersonalRef) {
    $rulesRef = ".vibe-rules"
    $notesRef = ".vibe-rules/project/README.md"
    $blockIntro = "开始任何工作前，按下面的顺序读（**混合档**：规则副本在项目内、路径相对项目根；第 3 条个人层在本机绝对路径，不存在就跳过）："
} elseif ($Mode -eq "embedded") {
    $rulesRef = ".vibe-rules"
    $notesRef = ".vibe-rules/project/README.md"
    $blockIntro = "开始任何工作前，按下面的顺序读（**自包含副本**，路径相对项目根，不需要访问项目外的任何文件）："
} else {
    $rulesRef = $VibeHome -replace '\\', '/'
    $notesRef = "$rulesRef/projects/$Slug/README.md"
    $blockIntro = "开始任何工作前，按下面的顺序读（**外链模式**，路径是本机规则库的绝对路径，不存在就跳过）："
}
if ($NoPersonal) {
    if ($PersonalRef) {
        $PersonalNote = "（**本机外链**，不进仓库、换机器读不到）"
    } else {
        $PersonalNote = "（副本里未包含，跳过）"
    }
}
if (-not $PersonalRef) { $PersonalRef = "$rulesRef/personal" }
$BlockTemplate = @'
<!-- vibe-rules:begin（本块由 vibe-rules 自动维护，勿手改；重跑 install.ps1 / update.ps1 即可刷新） -->
## 全局规则库（vibe-rules）

@INTRO@

1. **规则库入口**：`@RULES_REF@/README.md` —— 六条铁律 + 索引
2. **全局踩坑库（最新 10 条）**：`@RULES_REF@/global/anti-patterns.md`
3. **个人偏好与记忆**：`@PERSONAL_REF@/preferences.md`、`@PERSONAL_REF@/memory.md`@PERSONAL_NOTE@
4. **本项目专属沉淀**：`@NOTES_REF@` —— 最具体，冲突时优先
5. **技术栈规范**：`@RULES_REF@/languages/<tech>.md`（按本项目实际栈读，不要全读）
6. **可复用工作流**：`@RULES_REF@/skills/README.md`，再按当前任务挑一个 `@RULES_REF@/skills/<name>/SKILL.md`
7. **本项目文档约定**：设计文档 → `docs/specs/YYYY-MM-DD-<topic>.md`，实现计划 → `docs/plans/YYYY-MM-DD-<feature>.md`；每份文档开头写 `> status: draft|active|done|abandoned · updated: YYYY-MM-DD`（`done` 的不用重读全文；汇总见规则库 scripts/docs-status.sh）

> 规则优先级：项目内约定（AGENTS.md + project/README.md）> 个人偏好 > 全局规范。冲突时以更具体的一层为准，并在回复里指出冲突。
<!-- vibe-rules:end -->
'@
$Block = $BlockTemplate.Replace('@INTRO@', $blockIntro).Replace('@RULES_REF@', $rulesRef).Replace('@NOTES_REF@', $notesRef).Replace('@PERSONAL_REF@', $PersonalRef).Replace('@PERSONAL_NOTE@', $PersonalNote)

function Repair-LegacyTemplate {
    param([string]$File)
    $path = (Resolve-Path $File).Path
    $content = [System.IO.File]::ReadAllText($path)
    $changed = $false
    if ($content.Contains('~/.vibe')) {
        if ($Mode -eq "embedded") {
            $content = $content.Replace('~/.vibe', '.vibe-rules/')
        } else {
            $content = $content.Replace('~/.vibe', $VibeHome)
        }
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
mode=$Mode
profile=$Profile
rules_home=$VibeHome
rules_version=$vibeVersion
installed_at=$(Get-Date -Format "yyyy-MM-dd")
project=$ProjectRoot
agents=$agentsList
"@
if ($Mode -eq "embedded") {
    $evidencePath = Join-Path $RulesDir "installed"
    $evidenceLabel = ".vibe-rules\installed"
} else {
    $evidencePath = Join-Path $ProjectRoot ".vibe-rules"
    $evidenceLabel = ".vibe-rules"
}
[System.IO.File]::WriteAllText($evidencePath, $evidence, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  ✅ $evidenceLabel（mode=$Mode，agents=$agentsList）"

# 清掉 pwsh 在某些环境下往工作目录写的运行时垃圾文件
foreach ($pat in @("ModuleAnalysisCache*", "StartupProfileData*")) {
    Get-ChildItem -Path $ProjectRoot -Filter $pat -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "🎉 完成。"
Write-Host "   验证：pwsh $VibeHome\scripts\verify.ps1 $ProjectRoot"
Write-Host ""
Write-Host "   提示："
if ($Mode -eq "embedded") {
    Write-Host "   - 规则副本已进项目：.vibe-rules\（整目录提交进仓库，团队/云端/CI 都能直接读到，不依赖任何人的本机路径）"
    Write-Host "   - 项目专属笔记在 .vibe-rules\project\README.md，也建议提交；重装/更新都不会覆盖它"
    if (-not $NoPersonal) {
        Write-Host "   - 副本里含 personal\（个人偏好与记忆）。不想带进仓库：用 -NoPersonal 装，或把 .vibe-rules\personal\ 加进 .gitignore"
    } elseif ($PersonalRef -and $PersonalRef -ne "$rulesRef/personal") {
        Write-Host "   - 个人层走本机外链：$PersonalRef（不会进仓库；换机器想继续用，记得在那边也放一份）"
    }
    Write-Host "   - 规则库以后改了：pwsh $VibeHome\scripts\update.ps1 $ProjectRoot"
} else {
    Write-Host "   - 外链模式：规则本体留在本机，$VibeHome 搬家后重跑 install/update 即可刷新"
    Write-Host "   - .vibe-rules 里记录的是本机路径，建议加进项目 .gitignore（不要提交）"
}

# ---------- 档位自查：team 必须真的能进仓库，personal 不该被提交 ----------
$ignoresVibe = $false
$gitignorePath = Join-Path $ProjectRoot ".gitignore"
if (Test-Path $gitignorePath) {
    if (Get-Content $gitignorePath | Where-Object { $_ -match '^\s*/?\.vibe-rules/?\s*$' }) { $ignoresVibe = $true }
}
$profileLabel = ""
if ($Profile -eq "team") { $profileLabel = "团队档" }
elseif ($Profile -eq "hybrid") { $profileLabel = "混合档" }
if ($profileLabel -and $ignoresVibe) {
    Write-Host ""
    Write-Host "⚠️  ${profileLabel}提醒：本项目 .gitignore 忽略了 .vibe-rules\，副本不会进仓库，"
    Write-Host "   队友 / 云端 agent / CI 都读不到——这正是这个档位要拦住的情况。"
    Write-Host "   修：把该条从 .gitignore 删掉（或加一行 !.vibe-rules/ 例外）；"
    Write-Host "   如果你就是不想让规则进仓库，改用 -Profile personal 重装。"
}
if ($Profile -eq "personal" -and -not $ignoresVibe) {
    Write-Host ""
    Write-Host "⚠️  个人档提醒：建议把 .vibe-rules 加进项目 .gitignore——"
    Write-Host "   外链模式的证据文件里记的是本机规则库绝对路径，提交上去对别人没用。"
}

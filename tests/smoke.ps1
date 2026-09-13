# tests/smoke.ps1 —— PowerShell 版端到端冒烟测试（与 tests/smoke.sh 对齐）
#
# 用法：
#   pwsh tests/smoke.ps1
#
# 覆盖 install/verify/uninstall/new-project/update 的：
#   自包含副本模式（默认）、外链模式（-Link）、引用块注入、幂等、旧模板迁移、
#   -Copy 复制模式、-NoPersonal、-Profile 策略档位、项目笔记保留、-PurgeProject、-Help、无效编号拒绝。
#   另有 CI 接入 -WithCi（生成 workflow、占位符替换、钉 commit、不吃用户同名文件、uninstall 只删自己的）。
#
# 说明：bash 版（tests/smoke.sh）另覆盖 migrate、带空格路径、bash 3.2 回归，两边互补。

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$TmpRoot  = Join-Path ([System.IO.Path]::GetTempPath()) ("vibe-rules-ps-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TmpRoot -Force | Out-Null

$script:Pass = 0
$script:Fail = 0

function Ok  { param([string]$m) $script:Pass++; Write-Host "  [OK]   $m" }
function Bad { param([string]$m) $script:Fail++; Write-Host "  [FAIL] $m" }
function Check {
    param([string]$Desc, [scriptblock]$Test)
    try {
        if (& $Test) { Ok $Desc } else { Bad $Desc }
    } catch {
        Bad "$Desc（异常：$($_.Exception.Message)）"
    }
}
function Refute {
    param([string]$Desc, [scriptblock]$Test)
    try {
        if (& $Test) { Bad $Desc } else { Ok $Desc }
    } catch { Ok $Desc }
}

# 当前 PowerShell 可执行文件（不赌 PATH；拿不到就退回 "pwsh"）
$script:PwshExe = Join-Path $PSHOME $(if ($IsWindows) { "pwsh.exe" } else { "pwsh" })
if (-not (Test-Path $script:PwshExe)) { $script:PwshExe = "pwsh" }

# 独立进程跑脚本，拿退出码（避免污染当前会话）。
function Run-Script {
    param([string]$Path, [string[]]$ScriptArgs = @())
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"   # native 的 stderr 在 Stop 下会变成终止错误
    $out = & $script:PwshExe -NoProfile -File $Path @ScriptArgs 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($code -ne 0) {
        Write-Host "      ┌─ $([System.IO.Path]::GetFileName($Path)) 退出码 $code，输出："
        foreach ($line in @($out)) { Write-Host "      │ $line" }
        Write-Host "      └─"
    }
    return $code
}
# 跑脚本并拿到输出文本（断言提示语用）
function Run-ScriptOut {
    param([string]$Path, [string[]]$ScriptArgs = @())
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = (& $script:PwshExe -NoProfile -File $Path @ScriptArgs 2>&1 | Out-String)
    $ErrorActionPreference = $prevEap
    return $out
}
function Raw { param([string]$Path) [System.IO.File]::ReadAllText($Path) }
function Write-Text {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

try {
    # ---------- 复制一份规则库，避免污染工作区 ----------
    $R1 = Join-Path $TmpRoot "rules"
    New-Item -ItemType Directory -Path $R1 -Force | Out-Null
    Get-ChildItem -Path $RepoRoot -Force | Where-Object { $_.Name -ne ".git" -and $_.Name -ne "projects" } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $R1 -Recurse -Force
    }

    # 模拟 pwsh 在只读 HOME 环境落到工作目录的运行时垃圾：不该被复制进项目副本
    Write-Text (Join-Path $R1 "ModuleAnalysisCache-TESTONLY") "junk"
    Write-Text (Join-Path $R1 "StartupProfileData-NonInteractive") "junk"

    $Install  = Join-Path $R1 "scripts/install.ps1"
    $Verify   = Join-Path $R1 "scripts/verify.ps1"
    $Uninst   = Join-Path $R1 "scripts/uninstall.ps1"
    $NewProj  = Join-Path $R1 "scripts/new-project.ps1"
    $Update   = Join-Path $R1 "scripts/update.ps1"
    $Migrate  = Join-Path $R1 "scripts/migrate.ps1"

    Write-Host "== 1. -Help =="
    foreach ($pair in @(@("install", $Install), @("verify", $Verify), @("uninstall", $Uninst),
                        @("new-project", $NewProj), @("update", $Update), @("migrate", $Migrate))) {
        $name = $pair[0]; $path = $pair[1]
        $code = Run-Script $path @("-Help")
        Check "$name.ps1 -Help 退出码 0" { $code -eq 0 }
    }

    Write-Host "== 2. 全新项目安装（默认自包含副本模式） =="
    $P1 = Join-Path $TmpRoot "proj-empty"
    $code = Run-Script $Install @($P1, "-AgentNums", "1,4,7,12", "-Yes")
    Check "install -AgentNums 1,4,7,12 -Yes 退出码 0" { $code -eq 0 }
    $Agents1 = Join-Path $P1 "AGENTS.md"
    Check "AGENTS.md 生成" { Test-Path $Agents1 }
    Check "引用块已注入" { (Raw $Agents1).Contains("<!-- vibe-rules:begin") }
    Check "引用块有结束标记" { (Raw $Agents1).Contains("<!-- vibe-rules:end -->") }
    Check "引用块用相对路径（指向项目内副本）" { (Raw $Agents1).Contains(".vibe-rules/README.md") }
    Refute "引用块不含本机绝对路径" { (Raw $Agents1).Contains($R1) }
    Check "副本入口 README.md 存在" { Test-Path (Join-Path $P1 ".vibe-rules/README.md") }
    Check "副本含 global/iron-rules.md" { Test-Path (Join-Path $P1 ".vibe-rules/global/iron-rules.md") }
    Check "副本含 languages/" { Test-Path (Join-Path $P1 ".vibe-rules/languages") }
    Check "副本含 skills/README.md" { Test-Path (Join-Path $P1 ".vibe-rules/skills/README.md") }
    Check "副本不含 scripts/" { -not (Test-Path (Join-Path $P1 ".vibe-rules/scripts")) }
    Check "副本不含插件清单（打包产物不跟项目走）" { -not (Test-Path (Join-Path $P1 ".vibe-rules/.codex-plugin")) }
    Check "副本不含 VERSION/CHANGELOG" { -not (Test-Path (Join-Path $P1 ".vibe-rules/VERSION")) }
    Check "副本无 pwsh 运行时垃圾文件（StartupProfileData）" { -not (Test-Path (Join-Path $P1 ".vibe-rules/StartupProfileData-NonInteractive")) }
    Check "副本无 pwsh 运行时垃圾文件（ModuleAnalysisCache）" { -not (Test-Path (Join-Path $P1 ".vibe-rules/ModuleAnalysisCache-TESTONLY")) }
    Check "证据文件在副本内" { Test-Path (Join-Path $P1 ".vibe-rules/installed") }
    Check "证据文件记录 mode=embedded" { (Raw (Join-Path $P1 ".vibe-rules/installed")).Contains("mode=embedded") }
    Check "证据文件记录 profile=default" { (Raw (Join-Path $P1 ".vibe-rules/installed")).Contains("profile=default") }
    Check "项目文档约定：docs/specs/README.md 建档" { Test-Path (Join-Path $P1 "docs/specs/README.md") }
    Check "项目文档约定：docs/plans/README.md 建档" { Test-Path (Join-Path $P1 "docs/plans/README.md") }
    Check "引用块含文档约定（第 7 条）" { (Raw $Agents1).Contains("docs/plans/YYYY-MM-DD") }
    Check "CLAUDE.md 入口（symlink 或复制）" { Test-Path (Join-Path $P1 "CLAUDE.md") }
    Check "Cursor 规则文件" { Test-Path (Join-Path $P1 ".cursor/rules/00-project-entry.mdc") }
    Check "CodeBuddy RULE.mdc" { Test-Path (Join-Path $P1 ".codebuddy/rules/project-entry/RULE.mdc") }
    Check "Copilot 指令文件" { Test-Path (Join-Path $P1 ".github/copilot-instructions.md") }
    Check "证据文件记录 4 个 agent" { (Raw (Join-Path $P1 ".vibe-rules/installed")).Contains("agents=1,4,7,12") }
    Check "项目笔记建在项目内" { Test-Path (Join-Path $P1 ".vibe-rules/project/README.md") }
    Check "verify 通过（只装 4 个不误报）" { (Run-Script $Verify @($P1)) -eq 0 }

    Write-Host "== 3. 幂等 =="
    Run-Script $Install @($P1, "-AgentNums", "1,4,7,12", "-Yes") | Out-Null
    $beginCount = ([regex]::Matches((Raw $Agents1), '<!-- vibe-rules:begin')).Count
    Check "引用块只有一份（实际 $beginCount）" { $beginCount -eq 1 }
    Check "副本没有嵌套副本" { -not (Test-Path (Join-Path $P1 ".vibe-rules/.vibe-rules")) }
    Check "verify 仍然通过" { (Run-Script $Verify @($P1)) -eq 0 }

    Write-Host "== 4. 已有 AGENTS.md 的老项目 =="
    $P2 = Join-Path $TmpRoot "proj-existing"
    New-Item -ItemType Directory -Path $P2 -Force | Out-Null
    Write-Text (Join-Path $P2 "AGENTS.md") "# 我的项目规则`n`n- 不要动 legacy/ 目录`n"
    Run-Script $Install @($P2, "-AgentNums", "2", "-Yes") | Out-Null
    $A2 = Join-Path $P2 "AGENTS.md"
    Check "原有正文保留" { (Raw $A2).Contains("不要动 legacy/ 目录") }
    Check "引用块已注入" { (Raw $A2).Contains("<!-- vibe-rules:begin") }
    Check "引用块在文件最顶部" { (Get-Content -LiteralPath $A2 -TotalCount 1).StartsWith("<!-- vibe-rules:begin") }
    Check "verify 通过" { (Run-Script $Verify @($P2)) -eq 0 }

    Write-Host "== 5. 空 AGENTS.md =="
    $P3 = Join-Path $TmpRoot "proj-empty-agents"
    New-Item -ItemType Directory -Path $P3 -Force | Out-Null
    Write-Text (Join-Path $P3 "AGENTS.md") ""
    Run-Script $Install @($P3, "-AgentNums", "2", "-Yes") | Out-Null
    $A3 = Join-Path $P3 "AGENTS.md"
    Check "空文件被写入引用块" { (Raw $A3).Contains("<!-- vibe-rules:begin") }
    Check "引用块有结束标记" { (Raw $A3).Contains("<!-- vibe-rules:end -->") }
    Check "verify 通过" { (Run-Script $Verify @($P3)) -eq 0 }

    Write-Host "== 6. 旧版模板迁移 =="
    $P4 = Join-Path $TmpRoot "proj-legacy"
    New-Item -ItemType Directory -Path $P4 -Force | Out-Null
    Write-Text (Join-Path $P4 "AGENTS.md") "# AGENTS.md`n`n## 0. 必须先读`n1. ``~/.vibe/README.md```n`n---`n`n## 1. 项目说明`n正文必须保留`n"
    Run-Script $Install @($P4, "-AgentNums", "2", "-Yes") | Out-Null
    $A4 = Join-Path $P4 "AGENTS.md"
    Refute "旧 ~/.vibe 硬编码已被替换" { (Raw $A4).Contains("~/.vibe") }
    Refute "旧「0. 必须先读」章节已删除" { (Raw $A4).Contains("## 0. 必须先读") }
    Check "原有正文保留" { (Raw $A4).Contains("正文必须保留") }
    Check "verify 通过" { (Run-Script $Verify @($P4)) -eq 0 }

    Write-Host "== 7. -Copy 复制模式 =="
    $P5 = Join-Path $TmpRoot "proj-copy"
    $code = Run-Script $Install @($P5, "-AgentNums", "1,12", "-Copy", "-Yes")
    Check "install -Copy 退出码 0" { $code -eq 0 }
    Check "CLAUDE.md 是真实文件" { (Test-Path (Join-Path $P5 "CLAUDE.md")) -and -not (Test-Path (Join-Path $P5 "CLAUDE.md") -PathType Container) }
    Check "复制出的 CLAUDE.md 含引用块" { (Raw (Join-Path $P5 "CLAUDE.md")).Contains("<!-- vibe-rules:begin") }
    Check "复制出的 Copilot 指令含引用块" { (Raw (Join-Path $P5 ".github/copilot-instructions.md")).Contains("<!-- vibe-rules:begin") }
    Check "verify 通过" { (Run-Script $Verify @($P5)) -eq 0 }

    Write-Host "== 8. -Link 外链模式 =="
    $P8 = Join-Path $TmpRoot "proj-link"
    $code = Run-Script $Install @($P8, "-AgentNums", "2", "-Link", "-Yes")
    Check "install -Link 退出码 0" { $code -eq 0 }
    Check "证据文件记录 mode=link" { (Raw (Join-Path $P8 ".vibe-rules")).Contains("mode=link") }
    Check "引用块指向本机规则库" { (Raw (Join-Path $P8 "AGENTS.md")).Contains(($R1 -replace '\\', '/')) }
    Refute "link 模式不建副本" { Test-Path (Join-Path $P8 ".vibe-rules/global") }
    Check "verify 通过" { (Run-Script $Verify @($P8)) -eq 0 }

    Write-Host "== 9. -NoPersonal =="
    $P9 = Join-Path $TmpRoot "proj-no-personal"
    $code = Run-Script $Install @($P9, "-AgentNums", "2", "-Yes", "-NoPersonal")
    Check "install -NoPersonal 退出码 0" { $code -eq 0 }
    Refute "副本不含 personal\\" { Test-Path (Join-Path $P9 ".vibe-rules/personal") }
    Check "引用块标注个人层跳过" { (Raw (Join-Path $P9 "AGENTS.md")).Contains("未包含") }
    Check "verify 通过（personal 缺失只警告）" { (Run-Script $Verify @($P9)) -eq 0 }

    Write-Host "== 9b. 旧版证据文件升级 =="
    $P9b = Join-Path $TmpRoot "proj-upgrade"
    New-Item -ItemType Directory -Path $P9b -Force | Out-Null
    $legacyEvidence = "rules_home=$R1`nrules_version=old`ninstalled_at=2026-01-01`nproject=$P9b`nagents=2`n"
    [System.IO.File]::WriteAllText((Join-Path $P9b ".vibe-rules"), $legacyEvidence, (New-Object System.Text.UTF8Encoding($false)))
    $code = Run-Script $Install @($P9b, "-Yes")
    Check "旧项目重跑 install 退出码 0" { $code -eq 0 }
    Check "升级后 .vibe-rules 变成目录" { Test-Path (Join-Path $P9b ".vibe-rules") -PathType Container }
    Check "升级后证据文件就位" { Test-Path (Join-Path $P9b ".vibe-rules/installed") }
    Check "升级后副本入口就位" { Test-Path (Join-Path $P9b ".vibe-rules/README.md") }
    Check "升级后引用块用相对路径" { (Raw (Join-Path $P9b "AGENTS.md")).Contains(".vibe-rules/README.md") }
    Check "升级后 verify 通过" { (Run-Script $Verify @($P9b)) -eq 0 }
    $P9c = Join-Path $TmpRoot "proj-unknown-dotfile"
    New-Item -ItemType Directory -Path $P9c -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $P9c ".vibe-rules"), "my own notes`n", (New-Object System.Text.UTF8Encoding($false)))
    $code = Run-Script $Install @($P9c, "-Yes")
    Refute "未知 .vibe-rules 文件被拒绝（不误删用户文件）" { $code -eq 0 }
    Check "被拒绝后用户文件原样保留" { (Raw (Join-Path $P9c ".vibe-rules")).Contains("my own notes") }

    Write-Host "== 10. 无效编号 =="
    $code = Run-Script $Install @((Join-Path $TmpRoot "proj-bad"), "-AgentNums", "99", "-Yes")
    Refute "无效编号被拒绝（退出码非 0）" { $code -eq 0 }

    Write-Host "== 11. new-project + update =="
    $P6 = Join-Path $TmpRoot "newproj"
    $code = Run-Script $NewProj @($P6, "-AgentNums", "2", "-Yes")
    Check "new-project 退出码 0" { $code -eq 0 }
    Check "项目专属笔记建在项目内" { Test-Path (Join-Path $P6 ".vibe-rules/project/README.md") }
    Check "笔记含项目名" { (Raw (Join-Path $P6 ".vibe-rules/project/README.md")).Contains("newproj") }
    Check "verify 通过" { (Run-Script $Verify @($P6)) -eq 0 }

    Add-Content -Path (Join-Path $P6 ".vibe-rules/project/README.md") -Value "`n我的项目专属决策`n"
    Add-Content -Path (Join-Path $R1 "global/anti-patterns.md") -Value "`n# 规则库后来加的新章节`n"
    $code = Run-Script $Update @($P6)
    Check "update 退出码 0" { $code -eq 0 }
    Check "update 后新规则进副本" { (Raw (Join-Path $P6 ".vibe-rules/global/anti-patterns.md")).Contains("规则库后来加的新章节") }
    Check "update 不覆盖项目笔记" { (Raw (Join-Path $P6 ".vibe-rules/project/README.md")).Contains("我的项目专属决策") }
    Check "update 后 verify 通过" { (Run-Script $Verify @($P6)) -eq 0 }
    $code = Run-Script $Update @($P8)
    Check "link 项目 update 保持 link 模式" { $code -eq 0 -and (Raw (Join-Path $P8 ".vibe-rules")).Contains("mode=link") }

    Write-Host "== 12. migrate =="
    $MigA = Join-Path $R1 "projects/mig-a"
    New-Item -ItemType Directory -Path $MigA -Force | Out-Null
    Write-Text (Join-Path $MigA "README.md") "# mig-a`n`n沉淀内容`n"
    $code = Run-Script $Migrate @("mig-a", "mig-b")
    Check "migrate 退出码 0" { $code -eq 0 }
    Check "沉淀内容已迁移到 mig-b" { (Raw (Join-Path $R1 "projects/mig-b/README.md")).Contains("沉淀内容") }

    Write-Host "== 13. 插件打包结构 =="
    Check "Codex 插件清单存在" { Test-Path (Join-Path $R1 ".codex-plugin/plugin.json") }
    Check "Claude 插件清单存在" { Test-Path (Join-Path $R1 ".claude-plugin/plugin.json") }
    Check "Codex marketplace 存在" { Test-Path (Join-Path $R1 ".agents/plugins/marketplace.json") }
    Check "Claude marketplace 存在" { Test-Path (Join-Path $R1 ".claude-plugin/marketplace.json") }
    Check "插件清单 JSON 合法" {
        $null = Get-Content -LiteralPath (Join-Path $R1 ".codex-plugin/plugin.json") -Raw | ConvertFrom-Json
        $null = Get-Content -LiteralPath (Join-Path $R1 ".agents/plugins/marketplace.json") -Raw | ConvertFrom-Json
        $true
    }
    Check "Codex 清单 skills 指向目录（官方规范）" { (Raw (Join-Path $R1 ".codex-plugin/plugin.json")).Contains('"skills": "./skills/"') }
    Check "Claude 清单 skills 列出全部 skill" { (Raw (Join-Path $R1 ".claude-plugin/plugin.json")).Contains("./skills/code-review") }
    Check "VERSION 是 semver" { (Raw (Join-Path $R1 "VERSION")).Trim() -match '^\d+\.\d+\.\d+$' }
    Check "RELEASE-NOTES.md 存在" { Test-Path (Join-Path $R1 "RELEASE-NOTES.md") }
    Check ".pre-commit-config.yaml 存在" { Test-Path (Join-Path $R1 ".pre-commit-config.yaml") }
    Check "pre-commit 挂了 validate-package" { (Raw (Join-Path $R1 ".pre-commit-config.yaml")).Contains("scripts/validate-package.sh") }
    Check "preflight.sh 存在" { Test-Path (Join-Path $R1 "scripts/preflight.sh") }
    Check "preflight 里挂了 pwsh 冒烟" { (Raw (Join-Path $R1 "scripts/preflight.sh")).Contains("smoke.ps1") }
    Check "lint.sh 存在" { Test-Path (Join-Path $R1 "scripts/lint.sh") }
    Check "pre-commit 挂了 lint" { (Raw (Join-Path $R1 ".pre-commit-config.yaml")).Contains("scripts/lint.sh") }
    Check "preflight 里挂了 lint" { (Raw (Join-Path $R1 "scripts/preflight.sh")).Contains("scripts/lint.sh") }
    Check "CI 里挂了 lint（bash 与 macOS 3.2 两处）" {
        ((Raw (Join-Path $R1 ".github/workflows/smoke.yml")) -split "scripts/lint.sh").Count -eq 3
    }
    Check "插件版本与 VERSION 一致" {
        $v = (Raw (Join-Path $R1 "VERSION")).Trim()
        $manifest = Get-Content -LiteralPath (Join-Path $R1 ".codex-plugin/plugin.json") -Raw | ConvertFrom-Json
        $manifest.version -eq $v
    }
    Check "每个 skill 有 agents/openai.yaml" {
        $ok = $true
        foreach ($d in Get-ChildItem -Path (Join-Path $R1 "skills") -Directory) {
            if (-not (Test-Path (Join-Path $d.FullName "agents/openai.yaml"))) { $ok = $false }
        }
        $ok
    }
    Check "skill 的 default_prompt 带 \$skill-name" {
        $ok = $true
        foreach ($d in Get-ChildItem -Path (Join-Path $R1 "skills") -Directory) {
            $y = Raw (Join-Path $d.FullName "agents/openai.yaml")
            if (-not $y.Contains("`$$($d.Name)")) { $ok = $false }
        }
        $ok
    }

    Write-Host "== 13b. 策略档位 -Profile =="
    $c1 = Run-Script $Install @((Join-Path $TmpRoot "proj-c1"), "-Profile", "team", "-Link", "-Yes")
    Check "-Profile team 与 -Link 冲突被拒绝" { $c1 -ne 0 }
    $c2 = Run-Script $Install @((Join-Path $TmpRoot "proj-c2"), "-Profile", "personal", "-NoPersonal", "-Yes")
    Check "-Profile personal 与 -NoPersonal 冲突被拒绝" { $c2 -ne 0 }
    $c3 = Run-Script $Install @((Join-Path $TmpRoot "proj-c3"), "-Profile", "nope", "-Yes")
    Check "-Profile 非法值被拒绝" { $c3 -ne 0 }
    Refute "被拒绝的档位没在项目里留垃圾" { Test-Path (Join-Path $TmpRoot "proj-c1/.vibe-rules") }

    $PT = Join-Path $TmpRoot "proj-team"
    New-Item -ItemType Directory -Path $PT -Force | Out-Null
    Write-Text (Join-Path $PT ".gitignore") "node_modules/`n"
    $code = Run-Script $Install @($PT, "-Profile", "team", "-AgentNums", "1", "-Yes")
    Check "install -Profile team 退出码 0" { $code -eq 0 }
    $teamEvidence = raw (Join-Path $PT ".vibe-rules/installed")
    Check "team：证据文件 profile=team" { $teamEvidence.Contains("profile=team") }
    Check "team：模式仍是 embedded" { $teamEvidence.Contains("mode=embedded") }
    Refute "team：副本不含 personal\" { Test-Path (Join-Path $PT ".vibe-rules/personal") }
    Check "team：verify 通过" { (Run-Script $Verify @($PT)) -eq 0 }

    Add-Content -Path (Join-Path $R1 "global/anti-patterns.md") -Value "`n# 档位沿用测试`n"
    $code = Run-Script $Update @($PT)
    Check "team：update 退出码 0" { $code -eq 0 }
    Check "team：update 沿用档位（profile=team）" { (Raw (Join-Path $PT ".vibe-rules/installed")).Contains("profile=team") }
    Refute "team：update 后仍然不含 personal\" { Test-Path (Join-Path $PT ".vibe-rules/personal") }

    Add-Content -Path (Join-Path $PT ".gitignore") ".vibe-rules/`n"
    $teamOut = Run-ScriptOut $Install @($PT, "-Profile", "team", "-AgentNums", "1", "-Yes")
    Check "team：装的时候提醒副本被 .gitignore 排除" { $teamOut.Contains("团队档提醒") }
    Refute "team：.gitignore 忽略副本 → verify 报错" { (Run-Script $Verify @($PT)) -eq 0 }

    $PP = Join-Path $TmpRoot "proj-personal"
    New-Item -ItemType Directory -Path $PP -Force | Out-Null
    $code = Run-Script $Install @($PP, "-Profile", "personal", "-AgentNums", "1", "-Yes")
    Check "install -Profile personal 退出码 0" { $code -eq 0 }
    Check "personal：证据文件 profile=personal" { (Raw (Join-Path $PP ".vibe-rules")).Contains("profile=personal") }
    Check "personal：模式是 link" { (Raw (Join-Path $PP ".vibe-rules")).Contains("mode=link") }
    Refute "personal：规则本体没进项目" { Test-Path (Join-Path $PP ".vibe-rules/global") }
    Check "personal：verify 通过（未忽略只警告）" { (Run-Script $Verify @($PP)) -eq 0 }
    Write-Text (Join-Path $PP ".gitignore") ".vibe-rules`n"
    Check "personal：加了 .gitignore 后 verify 仍通过" { (Run-Script $Verify @($PP)) -eq 0 }
    Remove-Item -LiteralPath (Join-Path $PP ".gitignore") -Force
    $code = Run-Script $Install @($PP, "-Profile", "team", "-AgentNums", "1", "-Yes")
    Check "personal → team：显式覆盖档位" { $code -eq 0 }
    $ppEvidence = Raw (Join-Path $PP ".vibe-rules/installed")
    Check "覆盖后模式变 embedded" { $ppEvidence.Contains("mode=embedded") }
    Check "覆盖后档位变 team" { $ppEvidence.Contains("profile=team") }
    Check "覆盖后 verify 通过" { (Run-Script $Verify @($PP)) -eq 0 }

    # hybrid 档：副本进仓库（不含 personal\），个人层走本机外链
    $PH = Join-Path $TmpRoot "proj-hybrid"
    New-Item -ItemType Directory -Path $PH -Force | Out-Null
    $code = Run-Script $Install @($PH, "-Profile", "hybrid", "-AgentNums", "1", "-Yes")
    Check "install -Profile hybrid 退出码 0" { $code -eq 0 }
    $hyEvidence = Raw (Join-Path $PH ".vibe-rules/installed")
    Check "hybrid：证据文件 profile=hybrid" { $hyEvidence.Contains("profile=hybrid") }
    Check "hybrid：副本进仓库（mode=embedded）" { $hyEvidence.Contains("mode=embedded") }
    Refute "hybrid：副本不含 personal\" { Test-Path (Join-Path $PH ".vibe-rules/personal") }
    Check "hybrid：引用块标注个人层本机外链" { (Raw (Join-Path $PH "AGENTS.md")).Contains("本机外链") }
    Check "hybrid：AGENTS.md 第 3 条指向本机 personal\" { (Raw (Join-Path $PH "AGENTS.md")).Contains(((Join-Path $R1 "personal") -replace '\\', '/')) }
    Check "hybrid：verify 通过" { (Run-Script $Verify @($PH)) -eq 0 }
    $c4 = Run-Script $Install @((Join-Path $TmpRoot "proj-h1"), "-Profile", "hybrid", "-Link", "-Yes")
    Check "-Profile hybrid 与 -Link 冲突被拒绝" { $c4 -ne 0 }
    $c5 = Run-Script $Install @((Join-Path $TmpRoot "proj-h2"), "-Profile", "hybrid", "-NoPersonal", "-Yes")
    Check "-Profile hybrid 与 -NoPersonal 冲突被拒绝" { $c5 -ne 0 }

    # update 要沿用 hybrid 档（不能把 personal\ 带进副本）
    $code = Run-Script $Update @($PH)
    Check "hybrid：update 退出码 0" { $code -eq 0 }
    Check "hybrid：update 沿用档位（profile=hybrid）" { (Raw (Join-Path $PH ".vibe-rules/installed")).Contains("profile=hybrid") }
    Refute "hybrid：update 后仍然不含 personal\" { Test-Path (Join-Path $PH ".vibe-rules/personal") }
    Check "hybrid：update 后引用块仍指向本机 personal\" { (Raw (Join-Path $PH "AGENTS.md")).Contains(((Join-Path $R1 "personal") -replace '\\', '/')) }

    # 混合档同样要求副本能进仓库：.gitignore 排除掉 = 队友/云端读不到
    Add-Content -Path (Join-Path $PH ".gitignore") ".vibe-rules/`n"
    $hyOut = Run-ScriptOut $Install @($PH, "-Profile", "hybrid", "-AgentNums", "1", "-Yes")
    Check "hybrid：装的时候提醒副本被 .gitignore 排除" { $hyOut.Contains("混合档提醒") }
    Refute "hybrid：.gitignore 忽略副本 → verify 报错" { (Run-Script $Verify @($PH)) -eq 0 }
    Remove-Item -LiteralPath (Join-Path $PH ".gitignore") -Force

    Write-Host "== 14. uninstall =="
    $code = Run-Script $Uninst @($P1)
    Check "uninstall 退出码 0" { $code -eq 0 }
    Refute "CLAUDE.md 已删除" { Test-Path (Join-Path $P1 "CLAUDE.md") }
    Refute "Cursor 规则文件已删除" { Test-Path (Join-Path $P1 ".cursor/rules/00-project-entry.mdc") }
    Refute "CodeBuddy RULE.mdc 已删除" { Test-Path (Join-Path $P1 ".codebuddy/rules/project-entry/RULE.mdc") }
    Refute "Copilot 指令文件已删除" { Test-Path (Join-Path $P1 ".github/copilot-instructions.md") }
    Refute "副本规则本体已删除" { Test-Path (Join-Path $P1 ".vibe-rules/global") }
    Refute "副本证据文件已删除" { Test-Path (Join-Path $P1 ".vibe-rules/installed") }
    Check "AGENTS.md 保留" { Test-Path $Agents1 }
    Refute "引用块已移除" { (Raw $Agents1).Contains("<!-- vibe-rules:begin") }
    Check "项目专属笔记默认保留" { Test-Path (Join-Path $P1 ".vibe-rules/project/README.md") }
    Refute "verify 正确报未接入" { (Run-Script $Verify @($P1)) -eq 0 }
    # 旧版可能把运行时垃圾带进副本：-PurgeProject 必须能整个删净
    Write-Text (Join-Path $P1 ".vibe-rules/ModuleAnalysisCache-stale") "junk"
    $code = Run-Script $Uninst @($P1, "-PurgeProject")
    Check "uninstall -PurgeProject 退出码 0" { $code -eq 0 }
    Refute "-PurgeProject 删掉项目笔记目录" { Test-Path (Join-Path $P1 ".vibe-rules") }
    Refute "-PurgeProject 删净副本（无残留垃圾）" { Test-Path (Join-Path $P1 ".vibe-rules/ModuleAnalysisCache-stale") }

    Write-Host "== 15. CI 接入（-WithCi） =="
    $CI  = Join-Path $TmpRoot "proj-withci"
    $CIL = Join-Path $TmpRoot "proj-withci-link"
    New-Item -ItemType Directory -Path $CI, $CIL -Force | Out-Null
    $code = Run-Script $Install @($CI, "-AgentNums", "1", "-Yes", "-WithCi")
    Check "install -WithCi 退出码 0" { $code -eq 0 }
    $CIYml = Join-Path $CI ".github/workflows/vibe-rules-verify.yml"
    Check "生成了 CI workflow" { Test-Path $CIYml }
    Check "占位符已全部替换（无 @VIBE_REPO@ / @VIBE_SHA@）" {
        $t = Raw $CIYml
        (-not $t.Contains("@VIBE_REPO@")) -and (-not $t.Contains("@VIBE_SHA@"))
    }
    Check "workflow 调 check-copy.sh（副本漂移）" { (Raw $CIYml).Contains("check-copy.sh") }
    Check "workflow 调 verify.sh（接入完整性）" { (Raw $CIYml).Contains("verify.sh") }
    Check "副本不带规则库自己的 pre-commit" { -not (Test-Path (Join-Path $CI ".vibe-rules/.pre-commit-config.yaml")) }
    Check "副本不带 RELEASE-NOTES.md" { -not (Test-Path (Join-Path $CI ".vibe-rules/RELEASE-NOTES.md")) }
    Check "带 CI 的副本仍能 verify" { (Run-Script $Verify @($CI)) -eq 0 }

    if (Get-Command git -ErrorAction SilentlyContinue) {
        # 有 git 的规则库副本：git@ 地址转 https、SHA 钉成 40 位 commit
        $R1G = Join-Path $TmpRoot "rules-git"
        New-Item -ItemType Directory -Path $R1G -Force | Out-Null
        Get-ChildItem -Path $R1 -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $R1G -Recurse -Force }
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"   # git 的 stderr 在 Stop 下会变成终止错误
        & git -C $R1G init -q . 2>$null
        & git -C $R1G remote add origin git@github.com:handsongice/vibe-rules.git 2>$null
        & git -C $R1G add -A 2>$null
        & git -C $R1G -c user.email=smoke@example.com -c user.name=smoke commit -qm init 2>$null
        $ErrorActionPreference = $prevEap
        $CIG = Join-Path $TmpRoot "proj-withci-git"
        New-Item -ItemType Directory -Path $CIG -Force | Out-Null
        $code = Run-Script (Join-Path $R1G "scripts/install.ps1") @($CIG, "-AgentNums", "1", "-Yes", "-WithCi")
        Check "有 git 的规则库：install -WithCi 退出码 0" { $code -eq 0 }
        $CIGYml = Join-Path $CIG ".github/workflows/vibe-rules-verify.yml"
        Check "git@ 远端地址转成 https" { (Raw $CIGYml).Contains("VIBE_RULES_REPO: https://github.com/handsongice/vibe-rules.git") }
        Check "SHA 钉成 40 位 commit" { (Raw $CIGYml) -match 'VIBE_RULES_SHA: [0-9a-f]{40}' }
    } else {
        Ok "跳过 git 相关 CI 断言（本机没有 git）"
    }

    # 用户自己的同名 workflow：不许覆盖
    Write-Text $CIYml "# 我自己的`nname: mine`n"
    $out = Run-ScriptOut $Install @($CI, "-AgentNums", "1", "-Yes", "-WithCi")
    Check "同名用户 workflow 保留不动" { (Raw $CIYml).Contains("name: mine") }
    Check "并打印保留提示" { $out.Contains("保留不动") }

    # 我们的文件：update -WithCi 重新钉 commit
    Remove-Item $CIYml -Force
    Run-Script $Install @($CI, "-AgentNums", "1", "-Yes", "-WithCi") | Out-Null
    Write-Text $CIYml ((Raw $CIYml).Replace("VIBE_RULES_SHA: main", "VIBE_RULES_SHA: 0000000000000000000000000000000000000000"))
    $code = Run-Script $Update @($CI, "-WithCi", "-Yes")
    Check "update -WithCi 退出码 0" { $code -eq 0 }
    Refute "SHA 已刷新（不再是 0000…）" { (Raw $CIYml).Contains("VIBE_RULES_SHA: 0000") }

    # 外链模式不生成 CI（规则库在本机，CI 跑不了）
    $out = Run-ScriptOut $Install @($CIL, "-Link", "-AgentNums", "1", "-Yes", "-WithCi")
    Refute "外链模式不生成 CI workflow" { Test-Path (Join-Path $CIL ".github/workflows/vibe-rules-verify.yml") }
    Check "外链模式说明为什么跳过" { $out.Contains("CI 里读不到") }

    # uninstall：只删本工具生成的，用户自己的 workflow 一律不动
    Write-Text (Join-Path $CI ".github/workflows/keep.yml") "# 别动我`nname: keepme`n"
    $code = Run-Script $Uninst @($CI)
    Check "uninstall 退出码 0" { $code -eq 0 }
    Refute "uninstall 删掉本工具生成的 workflow" { Test-Path $CIYml }
    Check "uninstall 保留用户自己的 workflow" { Test-Path (Join-Path $CI ".github/workflows/keep.yml") }
}
finally {
    Remove-Item -LiteralPath $TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "smoke(ps)：$script:Pass 通过，$script:Fail 失败"
if ($script:Fail -gt 0) { exit 1 }
Write-Host "全部通过"

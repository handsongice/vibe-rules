# tests/smoke.ps1 —— PowerShell 版端到端冒烟测试（与 tests/smoke.sh 对齐）
#
# 用法：
#   pwsh tests/smoke.ps1
#
# 覆盖 install/verify/uninstall/new-project/update 的：
#   自包含副本模式（默认）、外链模式（-Link）、引用块注入、幂等、旧模板迁移、
#   -Copy 复制模式、-NoPersonal、项目笔记保留、-PurgeProject、-Help、无效编号拒绝。
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
    Check "副本无 pwsh 运行时垃圾文件" { -not (Test-Path (Join-Path $P1 ".vibe-rules/StartupProfileData-NonInteractive")) }
    Check "证据文件在副本内" { Test-Path (Join-Path $P1 ".vibe-rules/installed") }
    Check "证据文件记录 mode=embedded" { (Raw (Join-Path $P1 ".vibe-rules/installed")).Contains("mode=embedded") }
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

    Write-Host "== 13. uninstall =="
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
    $code = Run-Script $Uninst @($P1, "-PurgeProject")
    Check "uninstall -PurgeProject 退出码 0" { $code -eq 0 }
    Refute "-PurgeProject 删掉项目笔记目录" { Test-Path (Join-Path $P1 ".vibe-rules") }
}
finally {
    Remove-Item -LiteralPath $TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "smoke(ps)：$script:Pass 通过，$script:Fail 失败"
if ($script:Fail -gt 0) { exit 1 }
Write-Host "全部通过"

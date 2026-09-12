#!/usr/bin/env bash
# tests/smoke.sh —— vibe-rules 端到端冒烟测试（bash 3.2+，无第三方依赖）
#
# 用法：bash tests/smoke.sh
#
# 覆盖：
#   1. bash 语法检查
#   2. 全新项目安装（默认自包含副本模式）+ 入口文件 + verify 通过
#   3. 幂等：重复安装不重复注入、副本不重复堆积
#   4. 已有 / 空 / 旧版模板 AGENTS.md 的迁移
#   5. 规则库搬家：embedded 用相对路径不受影响；link 模式重跑刷新绝对路径
#   6. --all 全量安装 / 无效编号拒绝 / --help
#   7. --copy 复制模式（无 symlink 场景，含 Copilot ../AGENTS.md 路径）
#   8. --no-personal：个人偏好不进项目副本
#   9. new-project：项目内 .vibe-rules/project/ 建档
#  10. update：副本刷新 + 项目笔记不被覆盖
#  11. uninstall：入口清干净、AGENTS.md 正文保留、项目笔记保留（--purge-project 才删）
#  12. migrate：跨项目迁移（含 bash 3.2 重复运行回归）
#  13. 带空格路径
#  14. 插件打包：skill 结构 / 清单一致性 / 版本同步 / pre-commit 与 preflight
#  15. 策略档位 --profile：team（副本进仓库 + 无个人层）/ personal（外链不进仓库）+ 冲突拒绝

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/vibe-rules-test.XXXXXX")"
TMP_ROOT="$(cd "$TMP_ROOT" && pwd)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}
refute() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then bad "$desc"; else ok "$desc"; fi
}
has() {
  # 输出里包含某段文字（用于断言脚本的提示语）
  case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac
}
copy_repo() {
  local dest="$1"
  mkdir -p "$dest"
  (cd "$REPO_ROOT" && tar -cf - --exclude .git --exclude projects --exclude project .) | (cd "$dest" && tar -xf -)
}

echo "== 1. bash 语法检查 =="
for f in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/tests/*.sh; do
  check "bash -n $(basename "$f")" bash -n "$f"
done

echo "== 2. 全新项目安装（默认自包含副本模式） =="
R1="$TMP_ROOT/rules1"
copy_repo "$R1"
# 模拟 pwsh 在只读 HOME 环境落到工作目录的运行时垃圾：不该被复制进项目副本
touch "$R1/ModuleAnalysisCache-TESTONLY" "$R1/StartupProfileData-NonInteractive"
P1="$TMP_ROOT/proj-empty"
mkdir -p "$P1"
check "install --agents 1,4,7,12 --yes" "$R1/scripts/install.sh" "$P1" --agents "1,4,7,12" --yes
check "AGENTS.md 生成" test -f "$P1/AGENTS.md"
check "引用块已注入" grep -q '<!-- vibe-rules:begin' "$P1/AGENTS.md"
check "引用块用相对路径（指向项目内副本）" grep -qF '.vibe-rules/README.md' "$P1/AGENTS.md"
refute "引用块不含本机绝对路径" grep -qF "$R1" "$P1/AGENTS.md"
check "副本入口 README.md 存在" test -f "$P1/.vibe-rules/README.md"
check "副本含 global/iron-rules.md" test -f "$P1/.vibe-rules/global/iron-rules.md"
check "副本含 languages/" test -d "$P1/.vibe-rules/languages"
check "副本含 skills/README.md" test -f "$P1/.vibe-rules/skills/README.md"
check "副本不含 scripts/（工具不进项目）" test ! -e "$P1/.vibe-rules/scripts"
check "副本不含插件清单（打包产物不跟着项目走）" test ! -e "$P1/.vibe-rules/.codex-plugin"
check "副本不含 VERSION/CHANGELOG" test ! -e "$P1/.vibe-rules/VERSION"
check "副本不含 pwsh 运行时垃圾（ModuleAnalysisCache）" test ! -e "$P1/.vibe-rules/ModuleAnalysisCache-TESTONLY"
check "副本不含 pwsh 运行时垃圾（StartupProfileData）" test ! -e "$P1/.vibe-rules/StartupProfileData-NonInteractive"
check "证据文件在副本内" test -f "$P1/.vibe-rules/installed"
check "证据文件记录 mode=embedded" grep -q '^mode=embedded$' "$P1/.vibe-rules/installed"
check "证据文件记录 profile=default" grep -q '^profile=default$' "$P1/.vibe-rules/installed"
check "项目文档约定：docs/specs/README.md 建档" test -f "$P1/docs/specs/README.md"
check "项目文档约定：docs/plans/README.md 建档" test -f "$P1/docs/plans/README.md"
check "文档约定 README 带项目名（specs）" grep -q 'proj-empty' "$P1/docs/specs/README.md"
check "引用块含文档约定（第 7 条）" grep -q 'docs/plans/YYYY-MM-DD' "$P1/AGENTS.md"
check "CLAUDE.md symlink" test -L "$P1/CLAUDE.md"
check "Cursor 规则文件" test -f "$P1/.cursor/rules/00-project-entry.mdc"
check "CodeBuddy RULE.mdc" test -f "$P1/.codebuddy/rules/project-entry/RULE.mdc"
check "Copilot 指令文件" test -f "$P1/.github/copilot-instructions.md"
check "证据文件记录 4 个 agent" grep -q '^agents=1,4,7,12$' "$P1/.vibe-rules/installed"
check "verify 通过（只装 4 个不误报）" "$R1/scripts/verify.sh" "$P1"

echo "== 3. 幂等 =="
"$R1/scripts/install.sh" "$P1" --agents "1,4,7,12" --yes >/dev/null 2>&1
COUNT="$(grep -c '<!-- vibe-rules:begin' "$P1/AGENTS.md" || true)"
check "引用块只有一份（实际 ${COUNT}）" test "$COUNT" = "1"
check "副本入口没有被复制嵌套" test ! -e "$P1/.vibe-rules/.vibe-rules"
check "verify 仍然通过" "$R1/scripts/verify.sh" "$P1"

echo "== 4. 已有 AGENTS.md 的老项目 =="
P2="$TMP_ROOT/proj-existing"
mkdir -p "$P2"
printf '# 我的项目规则\n\n- 不要动 legacy/ 目录\n' > "$P2/AGENTS.md"
"$R1/scripts/install.sh" "$P2" --agents "2" --yes >/dev/null 2>&1
check "原有正文保留" grep -q '不要动 legacy/ 目录' "$P2/AGENTS.md"
check "引用块已注入" grep -q '<!-- vibe-rules:begin' "$P2/AGENTS.md"
FIRST_LINE="$(head -n 1 "$P2/AGENTS.md")"
case "$FIRST_LINE" in
  *vibe-rules:begin*) ok "引用块在文件最顶部" ;;
  *) bad "引用块不在顶部：$FIRST_LINE" ;;
esac
check "verify 通过" "$R1/scripts/verify.sh" "$P2"

echo "== 4b. 空 AGENTS.md =="
P2B="$TMP_ROOT/proj-empty-agents"
mkdir -p "$P2B"
: > "$P2B/AGENTS.md"
"$R1/scripts/install.sh" "$P2B" --agents "2" --yes >/dev/null 2>&1
check "空文件被写入引用块" grep -q '<!-- vibe-rules:begin' "$P2B/AGENTS.md"
check "空文件引用块完整（有结束标记）" grep -q '<!-- vibe-rules:end -->' "$P2B/AGENTS.md"
check "verify 通过" "$R1/scripts/verify.sh" "$P2B"

echo "== 4c. 旧版模板迁移 =="
P2C="$TMP_ROOT/proj-legacy"
mkdir -p "$P2C"
cat > "$P2C/AGENTS.md" <<'LEGACY'
# AGENTS.md

## 0. 必须先读
1. `~/.vibe/README.md`

---

## 1. 项目说明
正文必须保留
LEGACY
"$R1/scripts/install.sh" "$P2C" --agents "2" --yes >/dev/null 2>&1
refute "旧 ~/.vibe 硬编码已被替换" grep -q '~/\.vibe' "$P2C/AGENTS.md"
refute "旧「0. 必须先读」章节已删除" grep -q '^## 0\. 必须先读' "$P2C/AGENTS.md"
check "原有正文保留" grep -q '正文必须保留' "$P2C/AGENTS.md"
check "verify 通过" "$R1/scripts/verify.sh" "$P2C"

echo "== 5. 规则库搬家 =="
R2="$TMP_ROOT/rules-moved"
mv "$R1" "$R2"
# embedded：相对路径，规则库搬家后项目副本不受影响
check "搬家后 verify 仍通过（embedded 相对路径）" "$R2/scripts/verify.sh" "$P1"
# link：绝对路径，重跑 install 刷新
PL="$TMP_ROOT/proj-link"
"$R2/scripts/install.sh" "$PL" --agents "2" --link --yes >/dev/null 2>&1
check "link 模式记录 mode=link" grep -q '^mode=link$' "$PL/.vibe-rules"
check "link 模式 AGENTS.md 指向规则库" grep -qF "$R2" "$PL/AGENTS.md"
refute "link 模式不复制副本" test -d "$PL/.vibe-rules/global"
check "link 模式 verify 通过" "$R2/scripts/verify.sh" "$PL"
R3="$TMP_ROOT/rules-moved-again"
mv "$R2" "$R3"
"$R3/scripts/install.sh" "$PL" --link --yes >/dev/null 2>&1
check "link 重跑后指向新路径" grep -qF "$R3" "$PL/AGENTS.md"
refute "link 重跑后不含旧路径" grep -qF "$R2/" "$PL/AGENTS.md"
check "搬家后 link verify 通过" "$R3/scripts/verify.sh" "$PL"
R2="$R3"

echo "== 5b. 老版本升级（旧证据文件 → 副本目录） =="
PUP="$TMP_ROOT/proj-upgrade"
mkdir -p "$PUP"
cat > "$PUP/.vibe-rules" <<LEGACY
rules_home=$R2
rules_version=old
installed_at=2026-01-01
project=$PUP
agents=2
LEGACY
check "旧项目重跑 install（默认升级为副本模式）" "$R2/scripts/install.sh" "$PUP" --yes
check "升级后 .vibe-rules 变成目录" test -d "$PUP/.vibe-rules"
check "升级后证据文件就位" test -f "$PUP/.vibe-rules/installed"
check "升级后副本入口就位" test -f "$PUP/.vibe-rules/README.md"
check "升级后引用块用相对路径" grep -qF '.vibe-rules/README.md' "$PUP/AGENTS.md"
check "升级后 verify 通过" "$R2/scripts/verify.sh" "$PUP"
PUP2="$TMP_ROOT/proj-unknown-dotfile"
mkdir -p "$PUP2"
printf 'my own notes\n' > "$PUP2/.vibe-rules"
refute "未知 .vibe-rules 文件被拒绝（不误删用户文件）" "$R2/scripts/install.sh" "$PUP2" --yes
check "被拒绝后用户文件原样保留" grep -q 'my own notes' "$PUP2/.vibe-rules"

echo "== 6. --all / 无效编号 / --help =="
P3="$TMP_ROOT/proj-all"
"$R2/scripts/install.sh" "$P3" --all --yes >/dev/null 2>&1
AGENT_COUNT="$(sed -n 's/^agents=//p' "$P3/.vibe-rules/installed" | tr ',' '\n' | wc -l | tr -d ' ')"
check "12 个 agent 全部记录（实际 ${AGENT_COUNT}）" test "$AGENT_COUNT" = "12"
check "verify 通过" "$R2/scripts/verify.sh" "$P3"
refute "无效编号被拒绝" "$R2/scripts/install.sh" "$TMP_ROOT/proj-bad" --agents "99" --yes
check "--help 正常工作" "$R2/scripts/install.sh" --help
check "update --help 正常工作" "$R2/scripts/update.sh" --help

echo "== 7. --copy 复制模式 =="
P4="$TMP_ROOT/proj-copy"
"$R2/scripts/install.sh" "$P4" --agents "1,12" --copy --yes >/dev/null 2>&1
refute "CLAUDE.md 不是 symlink" test -L "$P4/CLAUDE.md"
check "CLAUDE.md 是真实文件" test -f "$P4/CLAUDE.md"
check "复制文件含引用块" grep -q '<!-- vibe-rules:begin' "$P4/CLAUDE.md"
check "Copilot 复制文件含引用块（../AGENTS.md 路径）" grep -q '<!-- vibe-rules:begin' "$P4/.github/copilot-instructions.md"
check "verify 通过" "$R2/scripts/verify.sh" "$P4"

echo "== 8. --no-personal =="
P8="$TMP_ROOT/proj-no-personal"
"$R2/scripts/install.sh" "$P8" --agents "2" --yes --no-personal >/dev/null 2>&1
refute "副本不含 personal/" test -d "$P8/.vibe-rules/personal"
check "引用块标注个人层跳过" grep -q '未包含' "$P8/AGENTS.md"
check "verify 通过（personal 缺失只警告）" "$R2/scripts/verify.sh" "$P8"

echo "== 9. new-project =="
P5="$TMP_ROOT/newproj"
check "new-project.sh --agents 2 --yes" "$R2/scripts/new-project.sh" "$P5" --agents "2" --yes
check "项目专属笔记建在项目内" test -f "$P5/.vibe-rules/project/README.md"
check "笔记含项目名" grep -q 'newproj' "$P5/.vibe-rules/project/README.md"
check "AGENTS.md 指向项目内笔记" grep -qF '.vibe-rules/project/README.md' "$P5/AGENTS.md"
check "verify 通过" "$R2/scripts/verify.sh" "$P5"

echo "== 10. update =="
printf '\n我的项目专属决策\n' >> "$P5/.vibe-rules/project/README.md"
printf '\n# 规则库后来加的新章节\n' >> "$R2/global/anti-patterns.md"
"$R2/scripts/update.sh" "$P5" >/dev/null 2>&1
check "update 后新规则进副本" grep -q '规则库后来加的新章节' "$P5/.vibe-rules/global/anti-patterns.md"
check "update 不覆盖项目笔记" grep -q '我的项目专属决策' "$P5/.vibe-rules/project/README.md"
check "update 不会误删 project/ 目录" test -f "$P5/.vibe-rules/project/README.md"
check "update 后 verify 通过" "$R2/scripts/verify.sh" "$P5"

echo "== 11. uninstall =="
"$R2/scripts/uninstall.sh" "$P1" >/dev/null 2>&1
refute "CLAUDE.md 已删除" test -e "$P1/CLAUDE.md"
refute "Cursor 规则文件已删除" test -e "$P1/.cursor/rules/00-project-entry.mdc"
refute "CodeBuddy RULE.mdc 已删除" test -e "$P1/.codebuddy/rules/project-entry/RULE.mdc"
refute "Copilot 指令文件已删除" test -e "$P1/.github/copilot-instructions.md"
refute "副本规则本体已删除" test -e "$P1/.vibe-rules/global"
refute "副本证据文件已删除" test -e "$P1/.vibe-rules/installed"
check "AGENTS.md 保留" test -f "$P1/AGENTS.md"
refute "引用块已移除" grep -q '<!-- vibe-rules:begin' "$P1/AGENTS.md"
check "项目专属笔记默认保留" test -f "$P1/.vibe-rules/project/README.md"
check "项目笔记跟项目名建档" grep -q 'proj-empty' "$P1/.vibe-rules/project/README.md"
refute "verify 正确报未接入" "$R2/scripts/verify.sh" "$P1"
# 旧版可能把运行时垃圾带进副本：--purge-project 必须能整个删净
touch "$P1/.vibe-rules/ModuleAnalysisCache-stale"
"$R2/scripts/uninstall.sh" "$P1" --purge-project >/dev/null 2>&1
refute "--purge-project 删掉项目笔记目录" test -d "$P1/.vibe-rules"
refute "--purge-project 删净副本（无残留垃圾）" test -e "$P1/.vibe-rules"

echo "== 12. migrate（含 bash 3.2 重复运行回归） =="
MAR="$R2/projects/mig-a"
mkdir -p "$MAR"
printf '# mig-a\n' > "$MAR/README.md"
check "第一次迁移" "$R2/scripts/migrate.sh" mig-a mig-b
check "文件已复制" test -f "$R2/projects/mig-b/README.md"
if "$R2/scripts/migrate.sh" mig-a mig-b < /dev/null >/dev/null 2>&1; then
  ok "第二次迁移（相同文件，走「跳过」分支）"
else
  bad "第二次迁移（相同文件，走「跳过」分支）"
fi

echo "== 13. 带空格路径 =="
P6="$TMP_ROOT/proj with space"
check "install 带空格路径" "$R2/scripts/install.sh" "$P6" --agents "1" --yes
check "verify 带空格路径" "$R2/scripts/verify.sh" "$P6"

echo "== 14. 插件打包 =="
check "validate-package.sh 通过" "$R2/scripts/validate-package.sh"
check "RELEASE-NOTES.md 存在" test -f "$R2/RELEASE-NOTES.md"
check ".pre-commit-config.yaml 存在" test -f "$R2/.pre-commit-config.yaml"
check "pre-commit 挂了 validate-package" grep -q 'scripts/validate-package.sh' "$R2/.pre-commit-config.yaml"
check "pre-commit 挂了 smoke" grep -q 'tests/smoke.sh' "$R2/.pre-commit-config.yaml"
check "preflight.sh 可执行" test -x "$R2/scripts/preflight.sh"
check "preflight.sh --help 正常" bash "$R2/scripts/preflight.sh" --help
check "preflight 里挂了 pwsh 冒烟（无 pwsh 时自动跳过）" grep -q 'smoke.ps1' "$R2/scripts/preflight.sh"
check "Codex 清单 skills 指向目录（官方规范）" grep -q '"skills": "./skills/"' "$R2/.codex-plugin/plugin.json"
check "Claude 清单 skills 列出全部 skill" grep -q './skills/code-review' "$R2/.claude-plugin/plugin.json"
check "每个 skill 有 agents/openai.yaml" test -f "$R2/skills/code-review/agents/openai.yaml"
check "Codex marketplace 收录 vibe-rules" grep -q 'vibe-rules' "$R2/.agents/plugins/marketplace.json"
check "Claude marketplace 收录 vibe-rules" grep -q 'vibe-rules' "$R2/.claude-plugin/marketplace.json"

mkdir -p "$R2/skills/fake-skill/agents"
printf -- '---\nname: fake-skill\ndescription: 测试用\nmetadata:\n  short-description: 测试\n---\n\n# fake\n' > "$R2/skills/fake-skill/SKILL.md"
printf 'interface:\n  display_name: "Fake"\n  short_description: "测试"\n  default_prompt: "Use $fake-skill now."\n' > "$R2/skills/fake-skill/agents/openai.yaml"
refute "新增 skill 后未同步 → 检查失败" "$R2/scripts/sync-plugin-skills.sh" --check
"$R2/scripts/sync-plugin-skills.sh" >/dev/null 2>&1
check "同步后 Claude 清单跟上" grep -q './skills/fake-skill' "$R2/.claude-plugin/plugin.json"
check "Codex 清单保持目录写法" grep -q '"skills": "./skills/"' "$R2/.codex-plugin/plugin.json"
check "同步后整体校验通过" "$R2/scripts/validate-package.sh"

printf -- '---\nname: wrong-name\ndescription: 名字不一致\n---\n\n# wrong\n' > "$R2/skills/fake-skill/SKILL.md"
refute "frontmatter name 与目录不一致 → 检查失败" "$R2/scripts/validate-package.sh"
printf -- '---\nname: fake-skill\ndescription: 测试用\nwhen_to_use:\n  - 测试\n---\n\n# fake\n' > "$R2/skills/fake-skill/SKILL.md"
refute "frontmatter 混入旧字段 → 检查失败" "$R2/scripts/validate-package.sh"
rm -rf "$R2/skills/fake-skill"
"$R2/scripts/sync-plugin-skills.sh" >/dev/null 2>&1
check "移除 skill 后清单回同步" "$R2/scripts/validate-package.sh"

echo "== 15. 策略档位 --profile =="
refute "--profile team 与 --link 冲突被拒绝" "$R2/scripts/install.sh" "$TMP_ROOT/proj-c1" --profile team --link --yes
refute "--profile personal 与 --no-personal 冲突被拒绝" "$R2/scripts/install.sh" "$TMP_ROOT/proj-c2" --profile personal --no-personal --yes
refute "--profile 非法值被拒绝" "$R2/scripts/install.sh" "$TMP_ROOT/proj-c3" --profile nope --yes
check "被拒绝的档位没有在项目里留垃圾" test ! -e "$TMP_ROOT/proj-c1/.vibe-rules"

PT="$TMP_ROOT/proj-team"
mkdir -p "$PT"
printf 'node_modules/\n' > "$PT/.gitignore"
check "install --profile team" "$R2/scripts/install.sh" "$PT" --profile team --agents "1" --yes
check "team：证据文件 profile=team" grep -q '^profile=team$' "$PT/.vibe-rules/installed"
check "team：模式仍是 embedded" grep -q '^mode=embedded$' "$PT/.vibe-rules/installed"
refute "team：副本不含 personal/" test -d "$PT/.vibe-rules/personal"
check "team：引用块标注个人层跳过" grep -q '未包含' "$PT/AGENTS.md"
check "team：verify 通过" "$R2/scripts/verify.sh" "$PT"

# update 要沿用档位，不能把团队档刷成默认档
printf '\n# 档位沿用测试\n' >> "$R2/global/anti-patterns.md"
"$R2/scripts/update.sh" "$PT" >/dev/null 2>&1
check "team：update 后新规则进副本" grep -q '档位沿用测试' "$PT/.vibe-rules/global/anti-patterns.md"
check "team：update 沿用档位（profile=team）" grep -q '^profile=team$' "$PT/.vibe-rules/installed"
refute "team：update 后仍然不含 personal/" test -d "$PT/.vibe-rules/personal"

# team 档 + .gitignore 把副本排除掉 = 违背团队档，安装时提醒、verify 报错
printf '.vibe-rules/\n' >> "$PT/.gitignore"
TEAM_OUT="$("$R2/scripts/install.sh" "$PT" --profile team --agents "1" --yes 2>&1)"
check "team：装的时候提醒副本被 .gitignore 排除" has "$TEAM_OUT" "团队档提醒"
refute "team：.gitignore 忽略副本 → verify 报错" "$R2/scripts/verify.sh" "$PT"

PP="$TMP_ROOT/proj-personal"
mkdir -p "$PP"
check "install --profile personal" "$R2/scripts/install.sh" "$PP" --profile personal --agents "1" --yes
check "personal：证据文件 profile=personal" grep -q '^profile=personal$' "$PP/.vibe-rules"
check "personal：模式是 link" grep -q '^mode=link$' "$PP/.vibe-rules"
refute "personal：规则本体没进项目" test -d "$PP/.vibe-rules"
check "personal：规则没进项目（项目里只有证据文件）" test -f "$PP/.vibe-rules"
check "personal：verify 通过（未忽略只警告）" "$R2/scripts/verify.sh" "$PP"
"$R2/scripts/update.sh" "$PP" >/dev/null 2>&1
check "personal：update 沿用档位（profile=personal）" grep -q '^profile=personal$' "$PP/.vibe-rules"
printf '.vibe-rules\n' > "$PP/.gitignore"
check "personal：加了 .gitignore 后 verify 仍通过" "$R2/scripts/verify.sh" "$PP"

# 显式选项可以覆盖沿用（把 personal 档切回团队档）
# 先摘掉 .gitignore 里的 .vibe-rules——团队档要求副本能进仓库，留着 verify 就该报错
rm -f "$PP/.gitignore"
check "personal → team：显式 --profile team 覆盖沿用" "$R2/scripts/install.sh" "$PP" --profile team --agents "1" --yes
check "覆盖后模式变 embedded" grep -q '^mode=embedded$' "$PP/.vibe-rules/installed"
check "覆盖后档位变 team" grep -q '^profile=team$' "$PP/.vibe-rules/installed"
check "覆盖后 verify 通过" "$R2/scripts/verify.sh" "$PP"

chmod 644 "$R2/CHANGELOG.md" 2>/dev/null || true
check "bump-version.sh 可执行" test -x "$R2/scripts/bump-version.sh"
check "bump-version.sh 1.0.1" bash "$R2/scripts/bump-version.sh" 1.0.1
check "VERSION 已更新" grep -q '^1.0.1$' "$R2/VERSION"
check "插件清单版本已同步" grep -q '"version": "1.0.1"' "$R2/.codex-plugin/plugin.json"
check "CHANGELOG 插入新版本段" grep -q '## \[1.0.1\]' "$R2/CHANGELOG.md"

echo ""
echo "📊 smoke：$PASS 通过，$FAIL 失败"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "🎉 全部通过"

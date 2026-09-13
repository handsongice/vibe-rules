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
#  15. 策略档位 --profile：team（副本进仓库 + 无个人层）/ hybrid（副本进仓库 + personal 本机外链）/ personal（外链不进仓库）+ 冲突拒绝
#  16. 文档状态管理：docs-status.sh 汇总 / --stale / --check / --archive（含 git 仓库 git mv）
#  17. 脚本 lint：lint.sh 全绿 + 六类问题各自能报错（变量紧贴非 ASCII / 缺 ps1 / 选项不对称（双向）/ 缺触发条件 / 语法错 / README 漂移（双向））
#  18. 副本漂移检查 check-copy.sh（一致 / 手改 / 缺文件 / 多文件 / 外链跳过 / 用法错）
#  19. CI 接入 --with-ci（生成 workflow、占位符替换、钉 commit、不吃用户同名文件、uninstall 只删自己的）
#  20. README 断言数字自检（bash 实测数 = README 写的数，防「加了断言忘改 README」）

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
check "引用块自称自包含副本（默认档不谎称混合档）" grep -qF '**自包含副本**' "$P1/AGENTS.md"
refute "默认档引用块不提混合档" grep -qF '**混合档**' "$P1/AGENTS.md"
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
check "13 个条目全部记录（12 agent + 0 通用，实际 ${AGENT_COUNT}）" test "$AGENT_COUNT" = "13"
check "verify 通过" "$R2/scripts/verify.sh" "$P3"
refute "无效编号被拒绝" "$R2/scripts/install.sh" "$TMP_ROOT/proj-bad" --agents "99" --yes
check "--help 正常工作" "$R2/scripts/install.sh" --help
check "update --help 正常工作" "$R2/scripts/update.sh" --help

echo "== 6b. --agents 0（通用：不建额外入口文件） =="
P0="$TMP_ROOT/proj-common-only"
"$R2/scripts/install.sh" "$P0" --agents 0 --yes >/dev/null 2>&1
check "0 号写入了 AGENTS.md 引用块" grep -q '<!-- vibe-rules:begin' "$P0/AGENTS.md"
check "0 号证据文件记 agents=0" grep -q '^agents=0$' "$P0/.vibe-rules/installed"
check "0 号 verify 通过" "$R2/scripts/verify.sh" "$P0"
refute "0 号不建 CLAUDE.md" test -e "$P0/CLAUDE.md"
refute "0 号不建 .cursorrules" test -e "$P0/.cursorrules"
refute "0 号不建 .cursor/" test -e "$P0/.cursor"
refute "0 号不建 .qoder/" test -e "$P0/.qoder"
refute "0 号不建 .trae/" test -e "$P0/.trae"
refute "0 号不建 .codebuddy/" test -e "$P0/.codebuddy"
refute "0 号不建 .windsurfrules" test -e "$P0/.windsurfrules"
refute "0 号不建 Copilot 指令文件" test -e "$P0/.github/copilot-instructions.md"

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

P5T="$TMP_ROOT/newproj-team"
check "new-project.sh --profile team 退出码 0" "$R2/scripts/new-project.sh" "$P5T" --agents "2" --profile team --yes
check "new-project.sh 档位写进证据文件" grep -q '^profile=team$' "$P5T/.vibe-rules/installed"
check "new-project.sh team 档 verify 通过" "$R2/scripts/verify.sh" "$P5T"

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
check "pre-commit 挂了 lint" grep -q 'scripts/lint.sh' "$R2/.pre-commit-config.yaml"
check "preflight 里挂了 lint" grep -q 'scripts/lint.sh' "$R2/scripts/preflight.sh"
check "CI 里挂了 lint（含 macOS bash 3.2 一档）" bash -c "grep -c 'scripts/lint.sh' '$R2/.github/workflows/smoke.yml' | grep -qx 2"
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


# hybrid 档：副本进仓库（不含 personal/），个人层走本机外链
PH="$TMP_ROOT/proj-hybrid"
mkdir -p "$PH"
check "install --profile hybrid" "$R2/scripts/install.sh" "$PH" --profile hybrid --agents "1" --yes
check "hybrid：证据文件 profile=hybrid" grep -q '^profile=hybrid$' "$PH/.vibe-rules/installed"
check "hybrid：副本进仓库（mode=embedded）" grep -q '^mode=embedded$' "$PH/.vibe-rules/installed"
refute "hybrid：副本不含 personal/" test -d "$PH/.vibe-rules/personal"
check "hybrid：引用块标注个人层本机外链" grep -q '本机外链' "$PH/AGENTS.md"
check "hybrid：AGENTS.md 第 3 条指向本机 personal/" grep -qF "$R2/personal" "$PH/AGENTS.md"
check "hybrid：引用块自称混合档" grep -qF '**混合档**' "$PH/AGENTS.md"
check "hybrid：verify 通过" "$R2/scripts/verify.sh" "$PH"
refute "hybrid 与 --link 冲突被拒绝" "$R2/scripts/install.sh" "$TMP_ROOT/proj-h1" --profile hybrid --link --yes
refute "hybrid 与 --no-personal 冲突被拒绝" "$R2/scripts/install.sh" "$TMP_ROOT/proj-h2" --profile hybrid --no-personal --yes

# update 要沿用 hybrid 档（不能刷成默认档把 personal/ 带进副本）
"$R2/scripts/update.sh" "$PH" >/dev/null 2>&1
check "hybrid：update 沿用档位（profile=hybrid）" grep -q '^profile=hybrid$' "$PH/.vibe-rules/installed"
refute "hybrid：update 后仍然不含 personal/" test -d "$PH/.vibe-rules/personal"
check "hybrid：update 后引用块仍指向本机 personal/" grep -qF "$R2/personal" "$PH/AGENTS.md"

# 混合档同样要求副本能进仓库：.gitignore 排除掉 = 队友/云端读不到
printf '.vibe-rules/\n' >> "$PH/.gitignore"
HYB_OUT="$("$R2/scripts/install.sh" "$PH" --profile hybrid --agents "1" --yes 2>&1)"
check "hybrid：装的时候提醒副本被 .gitignore 排除" has "$HYB_OUT" "混合档提醒"
refute "hybrid：.gitignore 忽略副本 → verify 报错" "$R2/scripts/verify.sh" "$PH"
rm -f "$PH/.gitignore"

chmod 644 "$R2/CHANGELOG.md" 2>/dev/null || true
check "bump-version.sh 可执行" test -x "$R2/scripts/bump-version.sh"
BADVER_OUT="$(bash "$R2/scripts/bump-version.sh" nope 2>&1 || true)"
check "bump-version.sh 拒绝非 semver（提示语完整，没被全角括号吃掉变量）" has "$BADVER_OUT" "不是 semver：nope"
check "bump-version.sh 1.0.1" bash "$R2/scripts/bump-version.sh" 1.0.1
check "VERSION 已更新" grep -q '^1.0.1$' "$R2/VERSION"
check "插件清单版本已同步" grep -q '"version": "1.0.1"' "$R2/.codex-plugin/plugin.json"
check "CHANGELOG 插入新版本段" grep -q '## \[1.0.1\]' "$R2/CHANGELOG.md"
SAMEVER_OUT="$(bash "$R2/scripts/bump-version.sh" 1.0.1 2>&1)"
check "bump-version.sh 同版本提示完整" has "$SAMEVER_OUT" "版本没变（仍是 1.0.1）"

echo "== 16. 文档状态管理 docs-status.sh =="
check "docs-status.sh --help 正常" bash "$R2/scripts/docs-status.sh" --help
refute "docs-status.sh 未知参数被拒绝" bash "$R2/scripts/docs-status.sh" --nope
refute "docs-status.sh --stale 非数字被拒绝" bash "$R2/scripts/docs-status.sh" "$TMP_ROOT" --stale abc

DS="$TMP_ROOT/proj-docs-status"
mkdir -p "$DS/docs/specs" "$DS/docs/plans"
printf '# 旧规格\n\n> status: done · updated: 2026-01-01\n' > "$DS/docs/specs/2026-01-01-old.md"
printf '# 活跃计划\n\n> status: active · updated: 2026-01-01\n' > "$DS/docs/plans/2026-01-01-active.md"
printf '# 无状态行\n' > "$DS/docs/specs/no-status.md"
printf '# 草稿\n\n> status: draft · updated: 2026-01-01\n' > "$DS/docs/plans/draft.md"

DS_OUT="$(bash "$R2/scripts/docs-status.sh" "$DS" 2>&1)"
check "汇总：共 4 份文档" has "$DS_OUT" "共 4 份文档"
check "汇总：已完成 1 份" has "$DS_OUT" "已完成 1"
check "汇总：未标注状态 1 份" has "$DS_OUT" "未标注状态 1"
check "汇总：列出 done 文档" has "$DS_OUT" "2026-01-01-old.md"
check "汇总：默认列过期清单（active 未完成）" has "$DS_OUT" "2026-01-01-active.md"
refute "--check：有未标注文档时退出 1" bash "$R2/scripts/docs-status.sh" "$DS" --check
DS_OUT0="$(bash "$R2/scripts/docs-status.sh" "$DS" --stale 0 2>&1)"
refute "--stale 0 不列过期清单" has "$DS_OUT0" "天没更新、且还没完成"

check "--archive 正常退出" bash "$R2/scripts/docs-status.sh" "$DS" --archive
check "--archive：done 进 archive/" test -f "$DS/docs/specs/archive/2026-01-01-old.md"
refute "--archive：原位置清空" test -e "$DS/docs/specs/2026-01-01-old.md"
check "--archive：不碰没完成的 active 文档" test -e "$DS/docs/plans/2026-01-01-active.md"
check "--archive：不归档 draft" test -e "$DS/docs/plans/draft.md"
DS_OUT2="$(bash "$R2/scripts/docs-status.sh" "$DS" 2>&1)"
check "归档后汇总变 3 份" has "$DS_OUT2" "共 3 份文档"

printf '# 无状态行\n\n> status: active · updated: %s\n' "$(date +%Y-%m-%d)" > "$DS/docs/specs/no-status.md"
check "--check：状态行补齐后通过" bash "$R2/scripts/docs-status.sh" "$DS" --check

# git 仓库里归档要走 git mv（保留历史），不能当普通文件删
DSG="$TMP_ROOT/proj-docs-status-git"
mkdir -p "$DSG/docs/plans"
printf '# 完成计划\n\n> status: done · updated: 2026-02-02\n' > "$DSG/docs/plans/2026-02-02-done.md"
(
  cd "$DSG" || exit 1
  git init -q .
  git add -A
  git -c user.email=smoke@example.com -c user.name=smoke commit -qm init
) >/dev/null 2>&1
check "docs-status：git 仓库 --archive 正常" bash "$R2/scripts/docs-status.sh" "$DSG" --archive
check "docs-status：git 归档文件到位" test -f "$DSG/docs/plans/archive/2026-02-02-done.md"
check "docs-status：git 里是改名（归档文件仍被跟踪）" bash -c "git -C '$DSG' ls-files --error-unmatch docs/plans/archive/2026-02-02-done.md"
refute "docs-status：git 原路径已不再跟踪" bash -c "git -C '$DSG' ls-files --error-unmatch docs/plans/2026-02-02-done.md"

echo "== 17. 脚本 lint（lint.sh） =="
check "lint.sh --help 正常" bash "$R2/scripts/lint.sh" --help
check "lint.sh 在规则库副本上全绿" bash "$R2/scripts/lint.sh" "$R2"
refute "lint.sh 对不存在的目录报错" bash "$R2/scripts/lint.sh" "$TMP_ROOT/definitely-not-here"

# 负例 1：$VAR 后紧跟全角标点（bash 3.2 会连字节一起吞成变量名 → unbound variable）
L1="$TMP_ROOT/lint-neg1"
mkdir -p "$L1/scripts"
# 用 %s 拼出 "$X（…"：本文件自身不能出现这种写法，否则会被 lint ① 抓到（自证有效）
printf '#!/usr/bin/env bash\nX=1\necho "$%s（测试）"\n' "X" > "$L1/scripts/demo.sh"
printf 'param()\n' > "$L1/scripts/demo.ps1"
refute "lint 抓到 \$VAR 紧贴非 ASCII" bash "$R2/scripts/lint.sh" "$L1"
L1_OUT="$(bash "$R2/scripts/lint.sh" "$L1" 2>&1 || true)"
check "lint 报错点名具体文件" has "$L1_OUT" "scripts/demo.sh"
check "lint 给出修法（花括号）" has "$L1_OUT" "花括号"
refute "① 命中时不打印全绿（假绿回归）" has "$L1_OUT" "全部通过"
check "① 命中计入失败数" has "$L1_OUT" "1 失败"

# 正例：位置参数 $1 后接全角不触发 ①（bash 不会把它当变量名，但仍建议 ${1}）
# 提示语里不放引号包着的 --flag，避免 ③ 的选项提取把用例本身当选项（单一成因）
L2="$TMP_ROOT/lint-pos"
mkdir -p "$L2/scripts"
printf '#!/usr/bin/env bash\necho "未知参数：$1（只支持 check）" >&2\n' > "$L2/scripts/pos-demo.sh"
printf 'param()\n' > "$L2/scripts/pos-demo.ps1"
check "lint 不误报位置参数 \$1 后接全角" bash "$R2/scripts/lint.sh" "$L2"

# 负例 2：sh 有、ps1 缺
L3="$TMP_ROOT/lint-neg2"
mkdir -p "$L3/scripts"
printf '#!/usr/bin/env bash\necho hi\n' > "$L3/scripts/pair-demo.sh"
refute "lint 抓到缺 ps1 的成对脚本" bash "$R2/scripts/lint.sh" "$L3"

# 负例 3：选项不对称（sh 认 --foo，ps1 没有 -Foo）
L4="$TMP_ROOT/lint-neg3"
mkdir -p "$L4/scripts"
printf '#!/usr/bin/env bash\ncase "${1:-}" in\n  --foo) echo foo ;;\nesac\n' > "$L4/scripts/opt-demo.sh"
printf 'param([switch]$Bar)\n' > "$L4/scripts/opt-demo.ps1"
refute "lint 抓到选项不对称" bash "$R2/scripts/lint.sh" "$L4"
L4_OUT="$(bash "$R2/scripts/lint.sh" "$L4" 2>&1 || true)"
check "选项不对称报错含选项名" has "$L4_OUT" "--foo"

# 负例 4：单侧白名单与双扩展名矛盾（lint.ps1 不该出现）
L5="$TMP_ROOT/lint-neg4"
mkdir -p "$L5/scripts"
printf '#!/usr/bin/env bash\necho hi\n' > "$L5/scripts/lint.sh"
printf 'param()\n' > "$L5/scripts/lint.ps1"
refute "lint 抓到白名单里出现双扩展名" bash "$R2/scripts/lint.sh" "$L5"

# 负例 5：反向不对称——ps1 顶层多出的参数 sh 侧不认，也不在白名单（只加了 Windows 侧）
L6="$TMP_ROOT/lint-neg5"
mkdir -p "$L6/scripts"
printf '#!/usr/bin/env bash\necho hi\n' > "$L6/scripts/opt-both.sh"
printf 'param(\n  [switch]$Extra\n)\n' > "$L6/scripts/opt-both.ps1"
refute "lint 抓到 ps1 单侧多出的参数" bash "$R2/scripts/lint.sh" "$L6"
L6_OUT="$(bash "$R2/scripts/lint.sh" "$L6" 2>&1 || true)"
check "反向不对称报错含参数名" has "$L6_OUT" "-Extra"

# 正例：ps1 原生约定（-Help）在白名单里，不报（反向检查别矫枉过正）
L7="$TMP_ROOT/lint-extra-ok"
mkdir -p "$L7/scripts"
printf '#!/usr/bin/env bash\necho hi\n' > "$L7/scripts/opt-both.sh"
printf 'param(\n  [switch]$Help\n)\n' > "$L7/scripts/opt-both.ps1"
check "lint 放行白名单里的 ps1 原生参数（-Help）" bash "$R2/scripts/lint.sh" "$L7"

# 负例 6：skill 缺 ## 触发条件 段 / 段落为空（agent 靠它决定什么时候加载）
L8="$TMP_ROOT/lint-neg6"
mkdir -p "$L8/skills/demo"
printf '# Demo\n\n## 步骤\n1. echo\n' > "$L8/skills/demo/SKILL.md"
refute "lint 抓到 skill 缺触发条件段" bash "$R2/scripts/lint.sh" "$L8"
L8_OUT="$(bash "$R2/scripts/lint.sh" "$L8" 2>&1 || true)"
check "缺触发条件报错点名 skill" has "$L8_OUT" "skills/demo/SKILL.md"
check "缺触发条件报错说明原因" has "$L8_OUT" "什么时候加载"
printf '# Demo\n\n## 触发条件\n\n## 步骤\n1. echo\n' > "$L8/skills/demo/SKILL.md"
refute "空的触发条件段也算失败" bash "$R2/scripts/lint.sh" "$L8"
printf '# Demo\n\n## 触发条件\n用户说"来做 X"时加载。\n\n## 步骤\n1. echo\n' > "$L8/skills/demo/SKILL.md"
check "lint 放行写了触发条件的 skill" bash "$R2/scripts/lint.sh" "$L8"

# 负例 7：未闭合引号（bash -n 直接拒绝，不靠肉眼）
L9="$TMP_ROOT/lint-neg7"
mkdir -p "$L9/scripts"
printf '#!/usr/bin/env bash\necho "没关引号\n' > "$L9/scripts/syn-demo.sh"
printf 'param()\n' > "$L9/scripts/syn-demo.ps1"
refute "lint 抓到未闭合引号（bash -n）" bash "$R2/scripts/lint.sh" "$L9"
L9_OUT="$(bash "$R2/scripts/lint.sh" "$L9" 2>&1 || true)"
check "语法错误报错点名文件" has "$L9_OUT" "scripts/syn-demo.sh"

# 负例 8：README 提到的选项没有任何脚本认（改了选项忘改文档）
L10="$TMP_ROOT/lint-neg8"
mkdir -p "$L10/scripts"
printf '#!/usr/bin/env bash\necho hi\n' > "$L10/scripts/noop.sh"
printf 'param()\n' > "$L10/scripts/noop.ps1"
printf '# 用法\n\n用 --ghost-flag 打开新行为。\n' > "$L10/README.md"
refute "lint 抓到 README 选项漂移" bash "$R2/scripts/lint.sh" "$L10"
L10_OUT="$(bash "$R2/scripts/lint.sh" "$L10" 2>&1 || true)"
check "README 漂移报错含选项名" has "$L10_OUT" "--ghost-flag"
printf '#!/usr/bin/env bash\ncase "${1:-}" in\n  --demo) echo demo ;;\nesac\n' > "$L10/scripts/noop.sh"
printf 'param([switch]$Demo)\n' > "$L10/scripts/noop.ps1"
printf '# 用法\n\n用 --demo 打开。\n' > "$L10/README.md"
check "lint 放行 README 里脚本认的选项" bash "$R2/scripts/lint.sh" "$L10"

# 负例 9：反方向——脚本认的选项 README 从没提（加了选项忘写文档）
printf '#!/usr/bin/env bash\ncase "${1:-}" in\n  --ghost2-flag) echo hi ;;\nesac\n' > "$L10/scripts/noop.sh"
printf 'param([switch]$Ghost2Flag)\n' > "$L10/scripts/noop.ps1"
printf '# 用法\n\n没有选项说明。\n' > "$L10/README.md"
refute "lint 抓到脚本选项没写进 README" bash "$R2/scripts/lint.sh" "$L10"
L10_OUT="$(bash "$R2/scripts/lint.sh" "$L10" 2>&1 || true)"
check "反向漂移报错含选项名" has "$L10_OUT" "--ghost2-flag"

# 正例：维护者内部选项（--no-changelog）白名单放行，README 不提也不报
printf '#!/usr/bin/env bash\ncase "${1:-}" in\n  --no-changelog) echo hi ;;\nesac\n' > "$L10/scripts/noop.sh"
printf 'param([switch]$NoChangelog)\n' > "$L10/scripts/noop.ps1"
printf '# 用法\n\n没有选项说明。\n' > "$L10/README.md"
check "lint 放行白名单里的内部选项（--no-changelog）" bash "$R2/scripts/lint.sh" "$L10"

# 负例 10：透传脚本（new-project / update）的 ps1 漏声明 install 选项——Windows 侧少功能
L11="$TMP_ROOT/lint-neg10"
mkdir -p "$L11/scripts"
printf '#!/usr/bin/env bash\ncase "${1:-}" in\n  --link) echo link ;;\n  --foo) echo foo ;;\nesac\n' > "$L11/scripts/install.sh"
printf 'param(\n  [switch]$Link,\n  [switch]$Foo\n)\n' > "$L11/scripts/install.ps1"
printf '#!/usr/bin/env bash\necho hi\n' > "$L11/scripts/new-project.sh"
printf 'param(\n  [switch]$Link\n)\n' > "$L11/scripts/new-project.ps1"
refute "lint 抓到透传脚本 ps1 漏转发 install 选项" bash "$R2/scripts/lint.sh" "$L11"
L11_OUT="$(bash "$R2/scripts/lint.sh" "$L11" 2>&1 || true)"
check "漏转发报错含选项名" has "$L11_OUT" "--foo"
# 正例：透传脚本把 install 选项声明齐了就不报
printf '#!/usr/bin/env bash\ncase "${1:-}" in\n  --link) echo link ;;\nesac\n' > "$L11/scripts/install.sh"
printf 'param(\n  [switch]$Link\n)\n' > "$L11/scripts/install.ps1"
check "lint 放行声明齐了的透传脚本" bash "$R2/scripts/lint.sh" "$L11"

echo "== 18. 副本漂移检查（check-copy.sh） =="
CC="$TMP_ROOT/proj-checkcopy"
mkdir -p "$CC"
"$R2/scripts/install.sh" "$CC" --agents 1 --yes >/dev/null 2>&1
check "check-copy：干净副本全绿" bash "$R2/scripts/check-copy.sh" "$CC"
CC_OUT="$(bash "$R2/scripts/check-copy.sh" "$CC" 2>&1)"
check "check-copy：报告比对文件数 + 0 漂移" has "$CC_OUT" "0 处漂移"
check "check-copy：--rules-home 指到规则库通过" bash "$R2/scripts/check-copy.sh" "$CC" --rules-home "$R2"
check "check-copy：--help 正常" bash "$R2/scripts/check-copy.sh" --help
check "check-copy：不传参数时查当前目录（在项目里跑）" bash -c "cd '$CC' && bash '$R2/scripts/check-copy.sh'"
refute "check-copy：目录不存在报错" bash "$R2/scripts/check-copy.sh" "$TMP_ROOT/definitely-not-here"
refute "check-copy：没接入的项目报错" bash "$R2/scripts/check-copy.sh" "$TMP_ROOT"
refute "check-copy：--rules-home 缺参报错" bash "$R2/scripts/check-copy.sh" "$CC" --rules-home
refute "check-copy：未知参数报错" bash "$R2/scripts/check-copy.sh" "$CC" --bogus
check "check-copy：用法错退出码是 2" bash -c "bash '$R2/scripts/check-copy.sh' '$CC' --nope >/dev/null 2>&1; test \$? -eq 2"
refute "check-copy：规则库路径 = 项目路径时报错" bash "$R2/scripts/check-copy.sh" "$CC" --rules-home "$CC"

# 手改副本：必须报漂移（不然 CI 装了也拦不住）
printf '\n# 手改，规则库没有这一行\n' >> "$CC/.vibe-rules/global/anti-patterns.md"
refute "check-copy：手改副本报漂移（退出码非 0）" bash "$R2/scripts/check-copy.sh" "$CC"
CC_OUT="$(bash "$R2/scripts/check-copy.sh" "$CC" 2>&1 || true)"
check "check-copy：点名被改的文件" has "$CC_OUT" "global/anti-patterns.md"
check "check-copy：给出修法（改规则库不改副本）" has "$CC_OUT" "别改副本"

# 副本缺文件 / 多文件
rm "$CC/.vibe-rules/global/anti-patterns.md"
refute "check-copy：副本缺文件报漂移" bash "$R2/scripts/check-copy.sh" "$CC"
"$R2/scripts/install.sh" "$CC" --agents 1 --yes >/dev/null 2>&1
printf 'x\n' > "$CC/.vibe-rules/global/mine-only.md"
refute "check-copy：副本多出文件报漂移" bash "$R2/scripts/check-copy.sh" "$CC"
rm -f "$CC/.vibe-rules/global/mine-only.md"
check "check-copy：刷新后恢复全绿" bash "$R2/scripts/check-copy.sh" "$CC"

# 外链模式：规则库在本机，没副本可比，跳过而不是误报
CCL="$TMP_ROOT/proj-checkcopy-link"
mkdir -p "$CCL"
"$R2/scripts/install.sh" "$CCL" --link --agents 1 --yes >/dev/null 2>&1
check "check-copy：外链模式跳过（退出码 0）" bash "$R2/scripts/check-copy.sh" "$CCL"
CCL_OUT="$(bash "$R2/scripts/check-copy.sh" "$CCL" 2>&1)"
check "check-copy：外链模式说明是「跳过漂移检查」" has "$CCL_OUT" "跳过漂移检查"

echo "== 19. CI 接入（install --with-ci） =="
# 规则库副本先建成一个 git 仓库（带 git@ 远端）：验证地址转换 + commit 钉死
R2G="$TMP_ROOT/rules-withci"
copy_repo "$R2G"
(
  cd "$R2G" || exit 1
  git init -q .
  git remote add origin git@github.com:handsongice/vibe-rules.git
  git add -A
  git -c user.email=smoke@example.com -c user.name=smoke commit -qm init
) >/dev/null 2>&1
CI="$TMP_ROOT/proj-withci"
mkdir -p "$CI"
check "install --with-ci 正常退出" bash "$R2G/scripts/install.sh" "$CI" --agents 1 --yes --with-ci
CI_YML="$CI/.github/workflows/vibe-rules-verify.yml"
check "生成了 CI workflow" test -f "$CI_YML"
refute "workflow 里没有未替换的占位符" grep -q '@VIBE_REPO@\|@VIBE_SHA@' "$CI_YML"
check "git@ 远端地址转成 https" grep -q 'VIBE_RULES_REPO: https://github.com/handsongice/vibe-rules.git' "$CI_YML"
check "workflow 钉的是 commit（不是浮动 main）" grep -qE 'VIBE_RULES_SHA: [0-9a-f]{40}' "$CI_YML"
check "workflow 调 check-copy.sh（副本漂移）" grep -q 'check-copy.sh' "$CI_YML"
check "workflow 调 verify.sh（接入完整性）" grep -q 'verify.sh' "$CI_YML"
check "装了 CI 的项目 verify 仍通过" bash "$R2G/scripts/verify.sh" "$CI"
check "CI workflow 不进副本" test ! -e "$CI/.vibe-rules/templates"
check "副本不带规则库自己的 pre-commit（引用的 scripts/ 不存在）" test ! -e "$CI/.vibe-rules/.pre-commit-config.yaml"
check "副本不带 RELEASE-NOTES.md" test ! -e "$CI/.vibe-rules/RELEASE-NOTES.md"

# 规则库没有 git 时：地址与 commit 都有兜底，不能写出空占位符
R2N="$TMP_ROOT/rules-nogit"
copy_repo "$R2N"
CIN="$TMP_ROOT/proj-withci-nogit"
mkdir -p "$CIN"
"$R2N/scripts/install.sh" "$CIN" --agents 1 --yes --with-ci >/dev/null 2>&1
CIN_YML="$CIN/.github/workflows/vibe-rules-verify.yml"
check "无 git 的规则库：地址兜底成默认远端" grep -q 'VIBE_RULES_REPO: https://github.com/handsongice/vibe-rules.git' "$CIN_YML"
check "无 git 的规则库：SHA 兜底成 main" grep -q 'VIBE_RULES_SHA: main' "$CIN_YML"

# 用户自己的同名 workflow：不许覆盖
printf '# 我自己的\nname: mine\n' > "$CI_YML"
"$R2G/scripts/install.sh" "$CI" --agents 1 --yes --with-ci >/dev/null 2>&1
check "同名用户 workflow 保留不动" grep -q 'name: mine' "$CI_YML"
CI_OUT="$(bash "$R2G/scripts/install.sh" "$CI" --agents 1 --yes --with-ci 2>&1)"
check "并打印保留提示" has "$CI_OUT" "保留不动"

# 我们的文件：update --with-ci 重新钉 commit
rm -f "$CI_YML"
"$R2G/scripts/install.sh" "$CI" --agents 1 --yes --with-ci >/dev/null 2>&1
sed -e 's/^      VIBE_RULES_SHA: .*/      VIBE_RULES_SHA: 0000000000000000000000000000000000000000/' "$CI_YML" > "$CI_YML.tmp"
mv "$CI_YML.tmp" "$CI_YML"
check "update --with-ci 正常退出" bash "$R2G/scripts/update.sh" "$CI" --with-ci --yes
refute "update --with-ci 把 SHA 钉回当前 commit" grep -q 'VIBE_RULES_SHA: 0000' "$CI_YML"

# 外链模式不生成 CI（规则库在本机，CI 跑不了）
CCL_OUT="$(bash "$R2G/scripts/install.sh" "$CCL" --link --with-ci --agents 1 --yes 2>&1)"
refute "外链模式不生成 CI workflow" test -e "$CCL/.github/workflows/vibe-rules-verify.yml"
check "外链模式说明为什么跳过" has "$CCL_OUT" "CI 里读不到"

# uninstall：只删本工具生成的，用户自己的 workflow 一律不动
printf '# 别动我\nname: keepme\n' > "$CI/.github/workflows/keep.yml"
check "uninstall 正常退出" bash "$R2G/scripts/uninstall.sh" "$CI"
refute "uninstall 删掉本工具生成的 workflow" test -e "$CI_YML"
check "uninstall 保留用户自己的 workflow" test -f "$CI/.github/workflows/keep.yml"

# 20. README 断言数字自检：本测试的总数（含这一条）必须等于 README 里写的数
README_BASH_NUM="$(grep -oE 'bash 版目前 [0-9]+ 项断言' "$REPO_ROOT/README.md" | grep -oE '[0-9]+' | head -n 1 || true)"
check "README 写的 bash 断言数与实测一致" test "$README_BASH_NUM" = "$((PASS+1))"

echo ""
echo "📊 smoke：$PASS 通过，$FAIL 失败"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "🎉 全部通过"

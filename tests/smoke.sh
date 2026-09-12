#!/usr/bin/env bash
# tests/smoke.sh —— vibe-rules 端到端冒烟测试（bash 3.2+，无第三方依赖）
#
# 用法：bash tests/smoke.sh
#
# 覆盖：
#   1. bash 语法检查
#   2. 全新项目安装（--agents / --yes）+ 入口文件 + verify 通过
#   3. 幂等：重复安装不重复注入
#   4. 已有 AGENTS.md 的老项目：正文保留 + 顶部注入引用块
#  4b. 空 AGENTS.md：不丢引用块
#  4c. 旧版模板迁移：~/.vibe 硬编码 + 「必须先读」章节被清理
#   5. 规则库搬家：重跑 install 自动刷新路径
#   6. --all 全量安装 / 无效编号拒绝 / --help
#   7. --copy 复制模式（无 symlink 场景，含 Copilot ../AGENTS.md 路径）
#   8. new-project：projects/<slug>/ 建档 + 引用接通
#   9. uninstall：入口清干净、AGENTS.md 正文保留
#  10. migrate：跨项目迁移（含 bash 3.2 重复运行回归）
#  11. 带空格路径

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
copy_repo() {
  local dest="$1"
  mkdir -p "$dest"
  (cd "$REPO_ROOT" && tar -cf - --exclude .git .) | (cd "$dest" && tar -xf -)
}

echo "== 1. bash 语法检查 =="
for f in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/tests/*.sh; do
  check "bash -n $(basename "$f")" bash -n "$f"
done

echo "== 2. 全新项目安装 =="
R1="$TMP_ROOT/rules1"
copy_repo "$R1"
P1="$TMP_ROOT/proj-empty"
mkdir -p "$P1"
check "install --agents 1,4,7,12 --yes" "$R1/scripts/install.sh" "$P1" --agents "1,4,7,12" --yes
check "AGENTS.md 生成" test -f "$P1/AGENTS.md"
check "引用块已注入" grep -q '<!-- vibe-rules:begin' "$P1/AGENTS.md"
check "引用块指向本机规则库" grep -qF "$R1" "$P1/AGENTS.md"
check "CLAUDE.md symlink" test -L "$P1/CLAUDE.md"
check "Cursor 规则文件" test -f "$P1/.cursor/rules/00-project-entry.mdc"
check "CodeBuddy RULE.mdc" test -f "$P1/.codebuddy/rules/project-entry/RULE.mdc"
check "Copilot 指令文件" test -f "$P1/.github/copilot-instructions.md"
check "证据文件记录 4 个 agent" grep -q '^agents=1,4,7,12$' "$P1/.vibe-rules"
check "verify 通过（只装 4 个不误报）" "$R1/scripts/verify.sh" "$P1"

echo "== 3. 幂等 =="
"$R1/scripts/install.sh" "$P1" --agents "1,4,7,12" --yes >/dev/null 2>&1
COUNT="$(grep -c '<!-- vibe-rules:begin' "$P1/AGENTS.md" || true)"
check "引用块只有一份（实际 ${COUNT}）" test "$COUNT" = "1"
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
"$R2/scripts/install.sh" "$P1" --agents "1,4,7,12" --yes >/dev/null 2>&1
check "AGENTS.md 指向新路径" grep -qF "$R2" "$P1/AGENTS.md"
refute "AGENTS.md 不含旧路径" grep -qF "$R1" "$P1/AGENTS.md"
check "verify 通过" "$R2/scripts/verify.sh" "$P1"

echo "== 6. --all / 无效编号 / --help =="
P3="$TMP_ROOT/proj-all"
"$R2/scripts/install.sh" "$P3" --all --yes >/dev/null 2>&1
AGENT_COUNT="$(sed -n 's/^agents=//p' "$P3/.vibe-rules" | tr ',' '\n' | wc -l | tr -d ' ')"
check "12 个 agent 全部记录（实际 ${AGENT_COUNT}）" test "$AGENT_COUNT" = "12"
check "verify 通过" "$R2/scripts/verify.sh" "$P3"
refute "无效编号被拒绝" "$R2/scripts/install.sh" "$TMP_ROOT/proj-bad" --agents "99" --yes
check "--help 正常工作" "$R2/scripts/install.sh" --help

echo "== 7. --copy 复制模式 =="
P4="$TMP_ROOT/proj-copy"
"$R2/scripts/install.sh" "$P4" --agents "1,12" --copy --yes >/dev/null 2>&1
refute "CLAUDE.md 不是 symlink" test -L "$P4/CLAUDE.md"
check "CLAUDE.md 是真实文件" test -f "$P4/CLAUDE.md"
check "复制文件含引用块" grep -q '<!-- vibe-rules:begin' "$P4/CLAUDE.md"
check "Copilot 复制文件含引用块（../AGENTS.md 路径）" grep -q '<!-- vibe-rules:begin' "$P4/.github/copilot-instructions.md"
check "verify 通过" "$R2/scripts/verify.sh" "$P4"

echo "== 8. new-project =="
P5="$TMP_ROOT/newproj"
check "new-project.sh --agents 2 --yes" "$R2/scripts/new-project.sh" "$P5" --agents "2" --yes
check "项目专属层建档" test -f "$R2/projects/newproj/README.md"
check "AGENTS.md 指向项目专属层" grep -q 'projects/newproj' "$P5/AGENTS.md"
check "verify 通过" "$R2/scripts/verify.sh" "$P5"

echo "== 9. uninstall =="
"$R2/scripts/uninstall.sh" "$P1" >/dev/null 2>&1
refute "CLAUDE.md 已删除" test -e "$P1/CLAUDE.md"
refute "Cursor 规则文件已删除" test -e "$P1/.cursor/rules/00-project-entry.mdc"
refute "CodeBuddy RULE.mdc 已删除" test -e "$P1/.codebuddy/rules/project-entry/RULE.mdc"
refute "Copilot 指令文件已删除" test -e "$P1/.github/copilot-instructions.md"
refute ".vibe-rules 已删除" test -f "$P1/.vibe-rules"
check "AGENTS.md 保留" test -f "$P1/AGENTS.md"
refute "引用块已移除" grep -q '<!-- vibe-rules:begin' "$P1/AGENTS.md"
refute "verify 正确报未接入" "$R2/scripts/verify.sh" "$P1"

echo "== 10. migrate（含 bash 3.2 重复运行回归） =="
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

echo "== 11. 带空格路径 =="
P6="$TMP_ROOT/proj with space"
check "install 带空格路径" "$R2/scripts/install.sh" "$P6" --agents "1" --yes
check "verify 带空格路径" "$R2/scripts/verify.sh" "$P6"

echo ""
echo "📊 smoke：$PASS 通过，$FAIL 失败"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "🎉 全部通过"

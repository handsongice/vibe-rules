#!/usr/bin/env bash
# uninstall.sh —— 从项目中移除 vibe-rules 的所有入口文件
#
# 用法：
#   /path/to/vibe-rules/scripts/uninstall.sh [项目路径]
#
# 会删除：
#   - 所有 agent 入口 symlink / wrapper / 复制文件（只删 vibe-rules 建的）
#   - .vibe-rules 证据文件
#   - AGENTS.md 顶部的 vibe-rules 引用块（正文保留）
# 不会删除：
#   - AGENTS.md 正文
#   - 项目里原有的真实文件

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
CONF_FILE="$VIBE_HOME/scripts/agents.conf"
PROJECT_ROOT="${1:-$(pwd)}"

if [ "$PROJECT_ROOT" = "-h" ] || [ "$PROJECT_ROOT" = "--help" ]; then
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "❌ 目录不存在：$PROJECT_ROOT"
  exit 1
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

echo "🗑️  从 $PROJECT_ROOT 移除 vibe-rules 入口文件..."
echo ""

cd "$PROJECT_ROOT"

TMP="$(mktemp "${TMPDIR:-/tmp}/vibe-uninstall.XXXXXX")"
cleanup() { rm -f "${TMP:-}"; }
trap cleanup EXIT

removed=0
skipped=0

remove_link() {
  local path="$1" dest
  if [ -L "$path" ]; then
    dest="$(readlink "$path")"
    case "$dest" in
      AGENTS.md|../AGENTS.md|"$PROJECT_ROOT/AGENTS.md")
        rm "$path"
        echo "  ✅ 删除 symlink: $path"
        removed=$((removed+1))
        ;;
      *)
        echo "  ⚠️  保留 ${path}（symlink 指向别处：${dest}）"
        skipped=$((skipped+1))
        ;;
    esac
  elif [ -f "$path" ]; then
    if [ -f "AGENTS.md" ] && cmp -s "$path" "AGENTS.md"; then
      rm "$path"
      echo "  ✅ 删除复制文件: $path"
      removed=$((removed+1))
    elif grep -q 'vibe-rules:begin' "$path" 2>/dev/null; then
      rm "$path"
      echo "  ✅ 删除含引用块的文件: $path"
      removed=$((removed+1))
    else
      echo "  ⚠️  保留真实文件: ${path}（不是 vibe-rules 建的）"
      skipped=$((skipped+1))
    fi
  fi
}

remove_wrapper() {
  local path="$1"
  if [ -f "$path" ]; then
    if grep -q 'vibe-rules' "$path" 2>/dev/null; then
      rm "$path"
      echo "  ✅ 删除 wrapper: $path"
      removed=$((removed+1))
    else
      echo "  ⚠️  保留: ${path}（不是 vibe-rules 生成的）"
      skipped=$((skipped+1))
    fi
  fi
}

# ---------- 按单一数据源清理入口文件 ----------
if [ -f "$CONF_FILE" ]; then
  while IFS='|' read -r num name type path doc; do
    case "$num" in
      ''|'#'*) continue ;;
    esac
    case "$type" in
      single) remove_link "$path" ;;
      dir) remove_wrapper "$path" ;;
    esac
  done < "$CONF_FILE"
fi

# ---------- 移除 AGENTS.md 引用块（正文保留） ----------
if [ -f "AGENTS.md" ] && grep -q '<!-- vibe-rules:begin' AGENTS.md 2>/dev/null; then
  awk '
    index($0, "<!-- vibe-rules:begin") == 1 { inblock=1; next }
    inblock && index($0, "<!-- vibe-rules:end -->") == 1 { inblock=0; next }
    inblock { next }
    { print }
  ' AGENTS.md > "$TMP"
  awk 'BEGIN { started=0 } { if (!started && $0 ~ /^[[:space:]]*$/) next; started=1; print }' "$TMP" > "${TMP}.2"
  mv "${TMP}.2" AGENTS.md
  echo "  ✅ AGENTS.md 引用块已移除（正文保留）"
  removed=$((removed+1))
fi

# ---------- 证据文件 ----------
if [ -f ".vibe-rules" ]; then
  rm ".vibe-rules"
  echo "  ✅ 删除 .vibe-rules"
  removed=$((removed+1))
fi

# ---------- 清理空目录 ----------
if [ -f "$CONF_FILE" ]; then
  while IFS='|' read -r num name type path doc; do
    case "$num" in
      ''|'#'*) continue ;;
    esac
    if [ "$type" = "dir" ]; then
      dir="$(dirname "$path")"
      if [ -d "$dir" ] && [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        rmdir "$dir" 2>/dev/null && echo "  ✅ 删除空目录: $dir"
      fi
    fi
  done < "$CONF_FILE"
fi
if [ -d ".github" ] && [ -z "$(ls -A .github 2>/dev/null)" ]; then
  rmdir ".github" 2>/dev/null && echo "  ✅ 删除空目录: .github"
fi

echo ""
echo "🎉 完成。删除 $removed 个文件，保留 $skipped 个真实文件。"
echo "   AGENTS.md 正文保留不动。"
echo "   规则库 projects/ 下的注册记录保留，想删手动去 $VIBE_HOME/projects/ 下删。"

#!/usr/bin/env bash
# uninstall.sh —— 从项目中移除 vibe-rules 的所有入口文件
#
# 用法：
#   /path/to/vibe-rules/scripts/uninstall.sh [项目路径] [--purge-project]
#
# 会删除：
#   - 所有 agent 入口 symlink / wrapper / 复制文件（只删 vibe-rules 建的）
#   - .vibe-rules 证据文件
#   - 自包含副本 .vibe-rules/ 的规则部分（global / languages / skills / personal / README.md）
#   - AGENTS.md 顶部的 vibe-rules 引用块（正文保留）
# 不会删除（默认）：
#   - AGENTS.md 正文
#   - 项目里原有的真实文件
#   - .vibe-rules/project/（你的项目专属笔记；要一起删加 --purge-project）

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
CONF_FILE="$VIBE_HOME/scripts/agents.conf"
PROJECT_ROOT="${1:-$(pwd)}"
PURGE_PROJECT=false

if [ "$PROJECT_ROOT" = "--purge-project" ]; then
  PROJECT_ROOT="$(pwd)"
  PURGE_PROJECT=true
elif [ "${2:-}" = "--purge-project" ]; then
  PURGE_PROJECT=true
fi

if [ "$PROJECT_ROOT" = "-h" ] || [ "$PROJECT_ROOT" = "--help" ]; then
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
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

# ---------- 证据文件 + 规则副本 ----------
MODE=""
EVIDENCE=""
if [ -f ".vibe-rules" ]; then
  EVIDENCE=".vibe-rules"
elif [ -f ".vibe-rules/installed" ]; then
  EVIDENCE=".vibe-rules/installed"
fi
if [ -n "$EVIDENCE" ]; then
  MODE="$(sed -n 's/^mode=//p' "$EVIDENCE" | head -n 1)"
  rm "$EVIDENCE"
  echo "  ✅ 删除 ${EVIDENCE}（证据文件）"
  removed=$((removed+1))
fi

# 删掉副本里的规则部分，保留 project/ 项目笔记；--purge-project 直接把整个副本目录删掉
if [ -d ".vibe-rules" ] && [ "$PURGE_PROJECT" = true ]; then
  rm -rf -- ".vibe-rules"
  echo "  ✅ 删除 .vibe-rules/（含 project/ 项目笔记，--purge-project）"
  removed=$((removed+1))
elif [ -d ".vibe-rules" ]; then
  # .agents/.claude-plugin/.codex-plugin 是旧版曾进过副本的打包产物，一并清掉
  for sub in global languages skills personal project .agents .claude-plugin .codex-plugin; do
    [ -d ".vibe-rules/$sub" ] || continue
    if [ "$sub" = "project" ] && [ "$PURGE_PROJECT" != true ]; then
      echo "  ℹ️  保留 .vibe-rules/project/（项目专属笔记；要删加 --purge-project）"
      continue
    fi
    rm -r ".vibe-rules/$sub"
    echo "  ✅ 删除 .vibe-rules/$sub/"
    removed=$((removed+1))
  done
  for f in README.md LICENSE .gitignore VERSION CHANGELOG.md .gitattributes AGENTS.md installed; do
    if [ -f ".vibe-rules/$f" ]; then
      rm -f ".vibe-rules/$f"
      echo "  ✅ 删除 .vibe-rules/$f"
      removed=$((removed+1))
    fi
  done
  # pwsh 运行时缓存（旧版可能被复制进副本）也一并清掉
  for junk in ".vibe-rules"/ModuleAnalysisCache* ".vibe-rules"/StartupProfileData*; do
    if [ -f "$junk" ]; then
      rm -f -- "$junk"
      echo "  ✅ 删除 ${junk}（运行时垃圾）"
      removed=$((removed+1))
    fi
  done
  if [ -z "$(ls -A ".vibe-rules" 2>/dev/null)" ]; then
    rmdir ".vibe-rules" 2>/dev/null && echo "  ✅ 删除空目录: .vibe-rules"
  else
    echo "  ℹ️  .vibe-rules/ 仍留有内容（项目笔记），未整个删除"
  fi
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
if [ "$PURGE_PROJECT" = true ]; then
  echo "   .vibe-rules/project/ 项目笔记已按 --purge-project 一起删除。"
else
  echo "   .vibe-rules/project/ 项目笔记保留；确认不要了再跑 --purge-project。"
fi

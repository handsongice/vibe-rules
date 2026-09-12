#!/usr/bin/env bash
# uninstall.sh —— 从项目中移除 vibe-rules 的所有入口文件
#
# 用法：
#   /path/to/vibe-rules/scripts/uninstall.sh [项目路径]
#
# 会删除：
#   - 所有 agent 入口 symlink / wrapper 文件
#   - .vibe-rules 证据文件
# 不会删除：
#   - AGENTS.md（你自己的项目文件，保留）
#   - 项目里原有的真实文件（只删我们建的）

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="${1:-$(pwd)}"

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "❌ 目录不存在：$PROJECT_ROOT"
  exit 1
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

echo "🗑️  从 $PROJECT_ROOT 移除 vibe-rules 入口文件..."
echo ""

cd "$PROJECT_ROOT"

removed=0
skipped=0

# 删除 symlink 文件（只删指向 AGENTS.md 的 symlink，不删真实文件）
remove_link() {
  local path="$1"
  if [ -L "$path" ]; then
    rm "$path"
    echo "  ✅ 删除 symlink: $path"
    removed=$((removed+1))
  elif [ -e "$path" ] && [ ! -L "$path" ]; then
    echo "  ⚠️  保留真实文件: $path（不是我们建的 symlink）"
    skipped=$((skipped+1))
  fi
}

# 删除 wrapper 文件
remove_wrapper() {
  local path="$1"
  if [ -f "$path" ]; then
    # 检查是不是我们建的（内容里有 vibe-rules 标记）
    if grep -q "vibe-rules" "$path" 2>/dev/null || grep -q "AGENTS.md" "$path" 2>/dev/null; then
      rm "$path"
      echo "  ✅ 删除 wrapper: $path"
      removed=$((removed+1))
    else
      echo "  ⚠️  保留: $path（不是 vibe-rules 建的）"
      skipped=$((skipped+1))
    fi
  fi
}

# —— 单文件型 symlink ——
remove_link "CLAUDE.md"
remove_link "CODEBUDDY.md"
remove_link "GEMINI.md"
remove_link "CONVENTIONS.md"
remove_link ".cursorrules"
remove_link ".windsurfrules"
remove_link ".clinerules"
remove_link ".roorules"
remove_link ".github/copilot-instructions.md"

# —— 目录型 wrapper ——
remove_wrapper ".cursor/rules/00-project-entry.mdc"
remove_wrapper ".windsurf/rules/00-project-entry.md"
remove_wrapper ".trae/rules/00-project-entry.md"
remove_wrapper ".qoder/rules/00-project-entry.md"
remove_wrapper ".codebuddy/rules/00-project-entry.md"
remove_wrapper ".continue/rules/00-project-entry.md"
remove_wrapper ".roo/rules/00-project-entry.md"
remove_wrapper ".kiro/steering/00-project-entry.md"
remove_wrapper ".amazonq/rules/00-project-entry.md"
remove_wrapper ".hermes/rules/00-project-entry.md"
remove_wrapper ".kimi/rules/00-project-entry.md"
remove_wrapper ".dsh/rules/00-project-entry.md"

# —— 证据文件 ——
if [ -f ".vibe-rules" ]; then
  rm ".vibe-rules"
  echo "  ✅ 删除 .vibe-rules"
  removed=$((removed+1))
fi

# 清理空目录（只删我们建的空目录）
for dir in .cursor/rules .windsurf/rules .trae/rules .qoder/rules .codebuddy/rules \
           .continue/rules .roo/rules .kiro/steering .amazonq/rules \
           .hermes/rules .kimi/rules .dsh/rules; do
  if [ -d "$dir" ] && [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
    rmdir "$dir" 2>/dev/null && echo "  ✅ 删除空目录: $dir"
  fi
done

echo ""
echo "🎉 完成。删除 $removed 个文件，保留 $skipped 个真实文件。"
echo "   AGENTS.md 保留不动（你的项目文件）。"
echo "   规则库 projects/ 下的注册记录保留，想删手动去 $VIBE_HOME/projects/ 下删。"

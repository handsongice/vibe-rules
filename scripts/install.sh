#!/usr/bin/env bash
# install.sh —— 在项目根目录运行，把 AGENTS.md 链接成各 agent 认识的入口文件
# 用法：cd /path/to/project && ~/.vibe/scripts/install.sh
# 幂等：可重复运行。不会覆盖已存在的非符号链接文件。

set -euo pipefail

VIBE_HOME="${VIBE_HOME:-$HOME/.vibe}"
PROJECT_ROOT="${1:-$(pwd)}"

# —— AGENTS.md 兜底：没有就从模板复制，有了就检查是否引用全局库 ——
if [ ! -f "$PROJECT_ROOT/AGENTS.md" ]; then
  cp "$VIBE_HOME/templates/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
  echo "📝 从模板创建 $PROJECT_ROOT/AGENTS.md（记得填项目信息）"
else
  # 已有 AGENTS.md，检查是否已经引用了全局库
  if ! grep -q '\.vibe' "$PROJECT_ROOT/AGENTS.md" 2>/dev/null; then
    echo "⚠️  $PROJECT_ROOT/AGENTS.md 已存在，但没引用 ~/.vibe 全局库。"
    echo "   在文件开头加一行：先读全局规范库 ~/.vibe/README.md"
  fi
fi

cd "$PROJECT_ROOT"
echo "🔗 在 $PROJECT_ROOT 创建 agent 入口链接..."

# 工具：建 symlink，保护已有真实文件
link() {
  local target="$1"   # 指向哪（相对项目根）
  local linkpath="$2" # 链接放哪
  if [ -e "$linkpath" ] && [ ! -L "$linkpath" ]; then
    echo "  ⚠️  跳过 $linkpath（已存在且是真实文件，未覆盖）"
    return
  fi
  rm -f "$linkpath"
  ln -s "$target" "$linkpath"
  echo "  ✅ $linkpath -> $target"
}

# —— 根目录级 symlink（指向 AGENTS.md）——
link "AGENTS.md" "CLAUDE.md"
link "AGENTS.md" "CODEBUDDY.md"
link "AGENTS.md" "GEMINI.md"
link "AGENTS.md" ".cursorrules"
link "AGENTS.md" ".windsurfrules"
link "AGENTS.md" ".github/copilot-instructions.md" 2>/dev/null || {
  mkdir -p .github
  link "AGENTS.md" ".github/copilot-instructions.md"
}

# —— 目录型 rules（Trae / Qoder / CodeBuddy）——
mkdir -p .trae/rules .qoder/rules .codebuddy/rules

# 这些目录型 agent 需要一个包装文件，内容是"先读 AGENTS.md 和全局库"
write_wrapper() {
  local path="$1"
  local note="$2"
  if [ -e "$path" ] && [ ! -L "$path" ]; then
    echo "  ⚠️  跳过 $path（已存在真实文件）"
    return
  fi
  rm -f "$path"
  cat > "$path" <<EOF
---
trigger: always_on
description: $note
---

# 项目入口

先读项目根目录的 \`AGENTS.md\`，再读全局规范库 \`~/.vibe/README.md\`。
不要凭记忆猜测项目约定，按这两个文件里写的来。
EOF
  echo "  ✅ $path"
}

write_wrapper ".trae/rules/00-project-entry.md" "项目入口规则，始终加载"
write_wrapper ".qoder/rules/00-project-entry.md" "项目入口规则，始终加载"
write_wrapper ".codebuddy/rules/00-project-entry.md" "项目入口规则，始终加载"

# —— pi 的全局 instructions 软链接（pi 会读 ~/.pi/agent/AGENTS.md）——
if [ -d "$HOME/.pi/agent" ] && [ ! -e "$HOME/.pi/agent/AGENTS.md" ]; then
  ln -s "$VIBE_HOME/README.md" "$HOME/.pi/agent/AGENTS.md" 2>/dev/null && \
    echo "  ✅ ~/.pi/agent/AGENTS.md -> $VIBE_HOME/README.md (pi 全局)"
fi

echo ""
echo "🎉 完成。各 agent 现在都会读到项目根 AGENTS.md。"
echo "   新增 agent 入口约定变了就重跑本脚本。"

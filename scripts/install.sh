#!/usr/bin/env bash
# install.sh —— 在你的开发项目里接入 vibe-rules
#
# 用法：
#   /path/to/vibe-rules/scripts/install.sh /path/to/your-project
#
# 规则库放哪都行，脚本会自动定位。项目里的入口文件会写入
# 规则库的实际绝对路径。规则库挪了位置？重新跑一次本脚本。
#
# 幂等：可重复运行。不会覆盖你已有的真实文件。

set -euo pipefail

# 从脚本位置反推规则库根目录（scripts/ 的上一级）
VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"

# 项目根目录：第一个参数，否则当前目录
PROJECT_ROOT="${1:-$(pwd)}"

# 安全检查：目录不存在就自动创建
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "📁 目录不存在，自动创建：$PROJECT_ROOT"
  mkdir -p "$PROJECT_ROOT"
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

echo "📦 规则库位置：$VIBE_HOME"
echo "🎯 目标项目：$PROJECT_ROOT"

if [ ! -f "$VIBE_HOME/README.md" ] || [ ! -d "$VIBE_HOME/global" ]; then
  echo "❌ $VIBE_HOME 看起来不像 vibe-rules 目录"
  exit 1
fi

# —— AGENTS.md：没有就从模板生成 ——
AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"

if [ ! -f "$AGENTS_FILE" ]; then
  sed "s|~/\.vibe|$VIBE_HOME|g" "$VIBE_HOME/templates/AGENTS.md" > "$AGENTS_FILE"
  echo "📝 生成 ${AGENTS_FILE}（已写入规则库实际路径，记得填项目信息）"
else
  echo "ℹ️  ${AGENTS_FILE} 已存在，保留不动"
fi

cd "$PROJECT_ROOT"
echo "🔗 创建 agent 入口文件..."

# —— 工具函数 ——

# 建 symlink，保护已有真实文件
link() {
  local target="$1"
  local linkpath="$2"
  if [ -e "$linkpath" ] && [ ! -L "$linkpath" ]; then
    echo "  ⚠️  跳过 $linkpath（已存在真实文件）"
    return
  fi
  rm -f "$linkpath"
  ln -s "$target" "$linkpath"
  echo "  ✅ $linkpath -> $target"
}

# 目录型 rules：写一个 wrapper 文件，告诉 agent 读 AGENTS.md 和规则库
write_wrapper() {
  local path="$1"
  local note="$2"
  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir"
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

先读项目根目录的 \`AGENTS.md\`，再读规则库 \`$VIBE_HOME/README.md\`。
不要凭记忆猜测项目约定，按这两个文件里写的来。
EOF
  echo "  ✅ $path"
}

# —— 单文件型：symlink 指向 AGENTS.md ——
# 这些 agent 读根目录下的单个文件，建 symlink 就行

link "AGENTS.md" "CLAUDE.md"              # Claude Code
link "AGENTS.md" "CODEBUDDY.md"           # CodeBuddy（旧版单文件）
link "AGENTS.md" "GEMINI.md"              # Gemini CLI
link "AGENTS.md" "CONVENTIONS.md"         # Aider
link "AGENTS.md" ".cursorrules"          # Cursor（旧版）
link "AGENTS.md" ".windsurfrules"        # Windsurf（旧版）
link "AGENTS.md" ".clinerules"           # Cline
link "AGENTS.md" ".roorules"             # Roo Code（旧版）

# GitHub Copilot（在 .github/ 下）
mkdir -p .github
link "AGENTS.md" ".github/copilot-instructions.md"

# —— 目录型：写 wrapper 文件 ——
# 这些 agent 读目录下的规则文件，建一个 wrapper 告诉它们读 AGENTS.md

write_wrapper ".cursor/rules/00-project-entry.mdc" "项目入口规则，始终加载"     # Cursor 新版
write_wrapper ".windsurf/rules/00-project-entry.md" "项目入口规则，始终加载"   # Windsurf 新版
write_wrapper ".trae/rules/00-project-entry.md" "项目入口规则，始终加载"       # Trae
write_wrapper ".qoder/rules/00-project-entry.md" "项目入口规则，始终加载"      # Qoder
write_wrapper ".codebuddy/rules/00-project-entry.md" "项目入口规则，始终加载"  # CodeBuddy 新版
write_wrapper ".continue/rules/00-project-entry.md" "项目入口规则，始终加载"    # Continue
write_wrapper ".roo/rules/00-project-entry.md" "项目入口规则，始终加载"        # Roo Code 新版
write_wrapper ".kiro/steering/00-project-entry.md" "项目入口规则，始终加载"     # Kiro
write_wrapper ".amazonq/rules/00-project-entry.md" "项目入口规则，始终加载"     # Amazon Q

echo ""
echo "🎉 完成。已为以下 agent 创建入口文件："
echo "   Claude Code, Cursor, Windsurf, GitHub Copilot, Cline, Roo Code,"
echo "   Continue, Aider, Gemini CLI, Trae, Qoder, CodeBuddy, Kiro, Amazon Q"
echo "   规则库挪了位置？重新跑一次本脚本即可。"

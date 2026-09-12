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
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

echo "📦 规则库位置：$VIBE_HOME"
echo "🎯 目标项目：$PROJECT_ROOT"

# 安全检查
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "❌ 项目目录不存在：$PROJECT_ROOT"
  exit 1
fi

if [ ! -f "$VIBE_HOME/README.md" ] || [ ! -d "$VIBE_HOME/global" ]; then
  echo "❌ $VIBE_HOME 看起来不像 vibe-rules 目录"
  exit 1
fi

# —— AGENTS.md：没有就从模板生成，有了就检查 ——
AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"

if [ ! -f "$AGENTS_FILE" ]; then
  # 从模板复制，并把 ~/.vibe 占位替换成实际路径
  sed "s|~/\.vibe|$VIBE_HOME|g" "$VIBE_HOME/templates/AGENTS.md" > "$AGENTS_FILE"
  echo "📝 生成 $AGENTS_FILE（已写入规则库实际路径，记得填项目信息）"
else
  echo "ℹ️  $AGENTS_FILE 已存在，保留不动"
fi

cd "$PROJECT_ROOT"
echo "🔗 创建 agent 入口链接..."

# 工具：建 symlink，保护已有真实文件
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

# 根目录级 symlink
link "AGENTS.md" "CLAUDE.md"
link "AGENTS.md" "CODEBUDDY.md"
link "AGENTS.md" "GEMINI.md"
link "AGENTS.md" ".cursorrules"
link "AGENTS.md" ".windsurfrules"
link "AGENTS.md" ".github/copilot-instructions.md" 2>/dev/null || {
  mkdir -p .github
  link "AGENTS.md" ".github/copilot-instructions.md"
}

# 目录型 rules（Trae / Qoder / CodeBuddy）
mkdir -p .trae/rules .qoder/rules .codebuddy/rules

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

先读项目根目录的 \`AGENTS.md\`，再读规则库 \`$VIBE_HOME/README.md\`。
不要凭记忆猜测项目约定，按这两个文件里写的来。
EOF
  echo "  ✅ $path"
}

write_wrapper ".trae/rules/00-project-entry.md" "项目入口规则，始终加载"
write_wrapper ".qoder/rules/00-project-entry.md" "项目入口规则，始终加载"
write_wrapper ".codebuddy/rules/00-project-entry.md" "项目入口规则，始终加载"

echo ""
echo "🎉 完成。各 agent 现在都会读到项目根 AGENTS.md。"
echo "   规则库挪了位置？重新跑一次本脚本即可。"

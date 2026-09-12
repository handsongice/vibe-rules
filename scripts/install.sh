#!/usr/bin/env bash
# install.sh —— 在你的开发项目里接入 vibe-rules
#
# 用法：
#   /path/to/vibe-rules/scripts/install.sh [项目路径]
#
# 交互式：列出所有支持的 agent，你选哪个就生成哪个入口文件。
# 加 --all 参数直接生成全部（老用户批量接入用）。

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="${1:-$(pwd)}"

# 支持的 agent 列表：编号 | 名称 | 类型 | 文件/目录 | 说明
# 类型：single = symlink 到 AGENTS.md；dir = 目录型 wrapper 文件
AGENTS=(
  "1|Claude Code|single|CLAUDE.md|根目录 CLAUDE.md"
  "2|Codex CLI|single|AGENTS.md|原生读 AGENTS.md（已生成，无需额外操作）"
  "3|Cursor|single|.cursorrules|根目录 .cursorrules"
  "4|Cursor（新版规则）|dir|.cursor/rules/.mdc|.cursor/rules/ 目录"
  "5|Qoder|dir|.qoder/rules/.md|.qoder/rules/ 目录"
  "6|Trae|dir|.trae/rules/.md|.trae/rules/ 目录"
  "7|CodeBuddy|single|CODEBUDDY.md|根目录 CODEBUDDY.md"
  "8|Hermes|dir|.hermes/rules/.md|.hermes/rules/ 目录"
  "9|Kimi Code|dir|.kimi/rules/.md|.kimi/rules/ 目录"
  "10|DeepSeek Harness|dir|.dsh/rules/.md|.dsh/rules/ 目录"
  "11|Windsurf|single|.windsurfrules|根目录 .windsurfrules"
  "12|GitHub Copilot|single|.github/copilot-instructions.md|.github/ 下"
  "13|Cline|single|.clinerules|根目录 .clinerules"
  "14|Roo Code|single|.roorules|根目录 .roorules"
  "15|Aider|single|CONVENTIONS.md|根目录 CONVENTIONS.md"
  "16|Gemini CLI|single|GEMINI.md|根目录 GEMINI.md"
  "17|Continue|dir|.continue/rules/.md|.continue/rules/ 目录"
)

# 解析参数
ALL_MODE=false
if [ "$PROJECT_ROOT" = "--all" ]; then
  ALL_MODE=true
  PROJECT_ROOT="${1:-$(pwd)}"
fi

# 目录不存在就创建
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "📁 目录不存在，自动创建：$PROJECT_ROOT"
  mkdir -p "$PROJECT_ROOT"
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

echo "📦 规则库：$VIBE_HOME"
echo "🎯 项目：$PROJECT_ROOT"
echo ""

# AGENTS.md（基础文件，总是生成）
AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"
if [ ! -f "$AGENTS_FILE" ]; then
  sed "s|~/\.vibe|$VIBE_HOME|g" "$VIBE_HOME/templates/AGENTS.md" > "$AGENTS_FILE"
  echo "📝 生成 AGENTS.md"
else
  echo "ℹ️  AGENTS.md 已存在"
fi

cd "$PROJECT_ROOT"

# 交互选择 agent
if [ "$ALL_MODE" = true ]; then
  SELECTION="all"
else
  echo "你用哪个 agent？输入编号（空格分隔多选），或输入 all 全选："
  echo ""
  for entry in "${AGENTS[@]}"; do
    IFS='|' read -r num name type path desc <<< "$entry"
    printf "  %2s. %-20s (%s)\n" "$num" "$name" "$desc"
  done
  echo ""
  read -r -p "选择: " SELECTION
fi

# 解析选择
SELECTED_NUMS=""
if [ "$SELECTION" = "all" ]; then
  for entry in "${AGENTS[@]}"; do
    IFS='|' read -r num name type path desc <<< "$entry"
    SELECTED_NUMS="$SELECTED_NUMS $num"
  done
else
  SELECTED_NUMS=" $SELECTION "
fi
# 确保结尾也有空格，方便 case 匹配
SELECTED_NUMS="$SELECTED_NUMS "

echo ""
echo "🔗 创建入口文件..."

# 工具函数
link() {
  local target="$1" linkpath="$2"
  if [ -e "$linkpath" ] && [ ! -L "$linkpath" ]; then
    echo "  ⚠️  跳过 $linkpath（已存在）"
    return
  fi
  rm -f "$linkpath"
  ln -s "$target" "$linkpath"
  echo "  ✅ $linkpath"
}

write_wrapper() {
  local path="$1" note="$2"
  local dir; dir="$(dirname "$path")"
  mkdir -p "$dir"
  if [ -e "$path" ] && [ ! -L "$path" ]; then
    echo "  ⚠️  跳过 $path（已存在）"
    return
  fi
  rm -f "$path"

  # 根据文件类型用不同的 frontmatter 格式
  if [[ "$path" == *.mdc ]]; then
    # Cursor .mdc 格式
    cat > "$path" <<EOF
---
description: $note
alwaysApply: true
---

# 项目入口

先读项目根目录的 \`AGENTS.md\`，再读规则库 \`$VIBE_HOME/README.md\`。
不要凭记忆猜测项目约定，按这两个文件里写的来。
EOF
  else
    # Trae / Qoder / Continue 等用 trigger 格式
    cat > "$path" <<EOF
---
trigger: always_on
description: $note
---

# 项目入口

先读项目根目录的 \`AGENTS.md\`，再读规则库 \`$VIBE_HOME/README.md\`。
不要凭记忆猜测项目约定，按这两个文件里写的来。
EOF
  fi
  echo "  ✅ $path"
}

# 根据选择执行
for entry in "${AGENTS[@]}"; do
  IFS='|' read -r num name type path desc <<< "$entry"
  case "$SELECTED_NUMS" in
    *" $num "*) ;; # 选中了
    *) continue ;;
  esac

  if [ "$type" = "single" ]; then
    if [ "$path" = ".github/copilot-instructions.md" ]; then
      mkdir -p .github
      link "../AGENTS.md" "$path"
    else
      link "AGENTS.md" "$path"
    fi
  elif [ "$type" = "dir" ]; then
    # 取目录名，建 wrapper
    dir_path=$(dirname "$path")
    fname=$(basename "$path")
    ext="${fname##*.}"
    wrapper="$dir_path/00-project-entry.$ext"
    write_wrapper "$wrapper" "$name 项目入口规则"
  fi
done

# 证据文件
VIBE_VERSION="$(cd "$VIBE_HOME" && git rev-parse --short HEAD 2>/dev/null || echo unknown)"
cat > ".vibe-rules" <<EOF
rules_home=$VIBE_HOME
rules_version=$VIBE_VERSION
installed_at=$(date +%Y-%m-%d)
agents=$(echo $SELECTED_NUMS | tr ' ' ',')
EOF
echo "  ✅ .vibe-rules（证据文件）"

echo ""
echo "🎉 完成。"
echo "   验证：$VIBE_HOME/scripts/verify.sh $PROJECT_ROOT"

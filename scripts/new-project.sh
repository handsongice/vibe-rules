#!/usr/bin/env bash
# new-project.sh —— 初始化一个新项目的 vibecoding 骨架
# 用法: ~/.vibe/scripts/new-project.sh /path/to/new-project
set -euo pipefail

VIBE_HOME="${VIBE_HOME:-$HOME/.vibe}"

if [ $# -lt 1 ]; then
  echo "用法: $0 <project-path>"
  exit 1
fi

PROJECT_ROOT="$1"
SLUG="$(basename "$PROJECT_ROOT")"

# 1. 创建项目目录
mkdir -p "$PROJECT_ROOT"

# 2. 复制 AGENTS.md 模板（如果还没有）
if [ ! -f "$PROJECT_ROOT/AGENTS.md" ]; then
  cp "$VIBE_HOME/templates/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
  echo "✅ 写入 $PROJECT_ROOT/AGENTS.md"
else
  echo "ℹ️  $PROJECT_ROOT/AGENTS.md 已存在，保留不动"
fi

# 3. 在全局库 projects/ 下建项目专属目录
PROJECT_SPECIFIC="$VIBE_HOME/projects/$SLUG"
mkdir -p "$PROJECT_SPECIFIC"
if [ ! -f "$PROJECT_SPECIFIC/README.md" ]; then
  cat > "$PROJECT_SPECIFIC/README.md" <<EOF
# $SLUG 项目专属规范

> 这个文件记录 $SLUG 项目特有的架构决策、历史坑、约定。
> 通用规则去 ~/.vibe/global/ 和 ~/.vibe/languages/。

## 架构
<!-- TODO: 核心模块、数据流、关键依赖 -->

## 关键决策记录（ADR 风格）
### [YYYY-MM-DD] 决策标题
- **背景**：
- **决策**：
- **为什么**：
- **后果**：

## 本项目踩坑
<!-- 每次踩坑在这里追加，格式见 ~/.vibe/global/anti-patterns.md 头部 -->
EOF
  echo "✅ 写入 $PROJECT_SPECIFIC/README.md"
fi

# 4. 跑 install.sh 建各 agent 入口
"$VIBE_HOME/scripts/install.sh" "$PROJECT_ROOT"

echo ""
echo "🎉 项目 $SLUG 初始化完成。"
echo "   下一步："
echo "   1. 编辑 $PROJECT_ROOT/AGENTS.md 填项目信息"
echo "   2. 在 $PROJECT_SPECIFIC/README.md 记录架构决策"
echo "   3. 任何 agent 现在都能自动读到这些规则"

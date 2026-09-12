#!/usr/bin/env bash
# new-project.sh —— 初始化一个新项目的 vibe-rules 骨架
#
# 用法：
#   /path/to/vibe-rules/scripts/new-project.sh /path/to/new-project
set -euo pipefail

# 从脚本位置反推规则库根目录
VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"

if [ $# -lt 1 ]; then
  echo "用法: $0 <project-path>"
  exit 1
fi

PROJECT_ROOT="$1"
SLUG="$(basename "$PROJECT_ROOT")"

# 1. 创建项目目录
mkdir -p "$PROJECT_ROOT"

# 2. 生成 AGENTS.md（把模板里的 ~/.vibe 替换成实际路径）
AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"
if [ ! -f "$AGENTS_FILE" ]; then
  sed "s|~/\.vibe|$VIBE_HOME|g" "$VIBE_HOME/templates/AGENTS.md" > "$AGENTS_FILE"
  echo "✅ 写入 $AGENTS_FILE"
else
  echo "ℹ️  $AGENTS_FILE 已存在，保留不动"
fi

# 3. 在规则库 projects/ 下建项目专属目录
PROJECT_SPECIFIC="$VIBE_HOME/projects/$SLUG"
mkdir -p "$PROJECT_SPECIFIC"
if [ ! -f "$PROJECT_SPECIFIC/README.md" ]; then
  cat > "$PROJECT_SPECIFIC/README.md" <<EOF
# $SLUG 项目专属规范

> 这个文件记录 $SLUG 项目特有的架构决策、历史坑、约定。
> 通用规则去 $VIBE_HOME/global/ 和 $VIBE_HOME/languages/。

## 架构
<!-- TODO: 核心模块、数据流、关键依赖 -->

## 关键决策记录（ADR 风格）
### [YYYY-MM-DD] 决策标题
- **背景**：
- **决策**：
- **为什么**：
- **后果**：

## 本项目踩坑
<!-- 每次踩坑在这里追加，格式见 $VIBE_HOME/global/anti-patterns.md 头部 -->
EOF
  echo "✅ 写入 $PROJECT_SPECIFIC/README.md"
fi

# 4. 跑 install.sh 建各 agent 入口
"$VIBE_HOME/scripts/install.sh" "$PROJECT_ROOT"

echo ""
echo "🎉 项目 $SLUG 初始化完成。"
echo "   下一步："
echo "   1. 编辑 $AGENTS_FILE 填项目信息"
echo "   2. 在 $PROJECT_SPECIFIC/README.md 记录架构决策"
echo "   3. 任何 agent 现在都能自动读到这些规则"

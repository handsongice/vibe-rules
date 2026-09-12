#!/usr/bin/env bash
# new-project.sh —— 初始化一个新项目的 vibe-rules 骨架
#
# 用法：
#   /path/to/vibe-rules/scripts/new-project.sh <项目路径> [install 选项]
#
# 做的事：
#   1. 建项目目录 + AGENTS.md（来自模板；引用块由 install.sh 注入）
#   2. 在规则库 projects/<slug>/ 建项目专属沉淀文件
#   3. 跑 install.sh 建各 agent 入口 + 证据文件
#
# 例：
#   ./scripts/new-project.sh ~/code/new-app --agents 1,3,12 --yes

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"

if [ $# -lt 1 ]; then
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

PROJECT_ROOT="$1"
shift
SLUG="$(basename "$PROJECT_ROOT")"

if [ ! -d "$PROJECT_ROOT" ]; then
  mkdir -p "$PROJECT_ROOT"
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

# ---------- 项目专属沉淀 ----------
PROJECT_SPECIFIC="$VIBE_HOME/projects/$SLUG"
mkdir -p "$PROJECT_SPECIFIC"
if [ ! -f "$PROJECT_SPECIFIC/README.md" ]; then
  cat > "$PROJECT_SPECIFIC/README.md" <<EOF
# $SLUG 项目专属规范

> 这个文件记录 $SLUG 项目特有的架构决策、历史坑、约定。
> 通用规则去 $VIBE_HOME/global/ 和 $VIBE_HOME/languages/。
> 项目根 AGENTS.md 的引用块里已经指向本文件，agent 每次开工都会读。

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
else
  echo "ℹ️  $PROJECT_SPECIFIC/README.md 已存在，保留不动"
fi

# ---------- 生成 AGENTS.md + 入口文件（交给 install.sh，单一实现） ----------
"$VIBE_HOME/scripts/install.sh" "$PROJECT_ROOT" "$@"

echo ""
echo "🎉 项目 $SLUG 初始化完成。"
echo "   下一步："
echo "   1. 编辑 $PROJECT_ROOT/AGENTS.md 填项目信息（顶部引用块不用动）"
echo "   2. 在 $PROJECT_SPECIFIC/README.md 记录架构决策"
echo "   3. 任何 agent 打开这个项目都能读到这些规则"

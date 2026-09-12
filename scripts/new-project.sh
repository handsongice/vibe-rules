#!/usr/bin/env bash
# new-project.sh —— 初始化一个新项目的 vibe-rules 骨架
#
# 用法：
#   /path/to/vibe-rules/scripts/new-project.sh <项目路径> [install 选项]
#
# 做的事：
#   1. 建项目目录
#   2. 跑 install.sh：生成 AGENTS.md + 各 agent 入口 + 规则副本
#      （项目专属笔记由 install 在 .vibe-rules/project/README.md 建档，
#        只在不存在时创建，之后永不覆盖）
#
# 例：
#   ./scripts/new-project.sh ~/code/new-app --agents 1,3,12 --yes
#   ./scripts/new-project.sh ~/code/new-app --link --agents 2 --yes

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

if [ $# -lt 1 ]; then
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

PROJECT_ROOT="$1"
shift
SLUG="$(basename "$PROJECT_ROOT")"

if [ ! -d "$PROJECT_ROOT" ]; then
  mkdir -p "$PROJECT_ROOT"
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

# ---------- 生成 AGENTS.md + 规则副本 + 入口文件（交给 install.sh，单一实现） ----------
"$VIBE_HOME/scripts/install.sh" "$PROJECT_ROOT" "$@"

echo ""
echo "🎉 项目 $SLUG 初始化完成。"
echo "   下一步："
echo "   1. 编辑 $PROJECT_ROOT/AGENTS.md 填项目信息（顶部引用块不用动）"
echo "   2. 编辑 $PROJECT_ROOT/.vibe-rules/project/README.md 记录架构决策和历史坑"
echo "   3. 把 AGENTS.md 和 .vibe-rules/ 一起提交，任何 agent、任何机器打开都能读到这些规则"

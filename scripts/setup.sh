#!/usr/bin/env bash
# setup.sh —— 在你 clone 下来的 vibe-rules 目录里跑一次
#
# 作用：
#   1. 建 ~/.vibe 软链指向你的实际 clone 路径
#   2. 这样所有项目里的 AGENTS.md 都写 ~/.vibe/...，永远不用改
#
# 用法：
#   cd ~/wherever/you/cloned/vibe-rules
#   ./scripts/setup.sh
#
# 想换到别的路径？把 ~/.vibe 软链删了重新跑一遍就行。

set -euo pipefail

# 脚本所在目录的上级 = 规则库根目录
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "📍 规则库位置：$REPO_ROOT"

# 检查这是不是一个合法的规则库目录
if [ ! -f "$REPO_ROOT/README.md" ] || [ ! -d "$REPO_ROOT/global" ]; then
  echo "❌ $REPO_ROOT 看起来不像 vibe-rules 目录（缺 README.md 或 global/）"
  echo "   请在 clone 下来的 vibe-rules 根目录里跑这个脚本"
  exit 1
fi

# 建 ~/.vibe 软链
LINK_PATH="$HOME/.vibe"

if [ -L "$LINK_PATH" ]; then
  OLD_TARGET="$(readlink "$LINK_PATH")"
  if [ "$OLD_TARGET" = "$REPO_ROOT" ]; then
    echo "✅ ~/.vibe 已经指向 $REPO_ROOT，不用重复 setup"
    exit 0
  fi
  echo "🔄 ~/.vibe 之前指向 $OLD_TARGET，重新链接到 $REPO_ROOT"
  rm "$LINK_PATH"
elif [ -e "$LINK_PATH" ]; then
  echo "❌ $LINK_PATH 已存在且不是软链（是真实目录或文件）"
  echo "   请手动备份后删除，再重跑 setup.sh"
  exit 1
fi

ln -s "$REPO_ROOT" "$LINK_PATH"
echo "✅ ~/.vibe -> $REPO_ROOT"

# 给两个脚本加可执行权限
chmod +x "$REPO_ROOT/scripts/"*.sh 2>/dev/null || true

echo ""
echo "🎉 安装完成。"
echo ""
echo "接下来在你的开发项目里跑："
echo "   ~/.vibe/scripts/install.sh /path/to/your-project"
echo ""
echo "或者初始化新项目："
echo "   ~/.vibe/scripts/new-project.sh /path/to/new-project"

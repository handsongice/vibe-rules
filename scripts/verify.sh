#!/usr/bin/env bash
# verify.sh —— 检查项目是否正确接入 vibe-rules
#
# 用法：
#   /path/to/vibe-rules/scripts/verify.sh /path/to/your-project

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="${1:-$(pwd)}"

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "❌ 目录不存在：$PROJECT_ROOT"
  exit 1
fi

cd "$PROJECT_ROOT"
echo "🔍 检查 $PROJECT_ROOT"
echo ""

PASS=0
FAIL=0

check() {
  local desc="$1"
  local condition="$2"
  if eval "$condition"; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc"
    FAIL=$((FAIL+1))
  fi
}

# 1. AGENTS.md（核心）
check "项目根有 AGENTS.md" "[ -f AGENTS.md ]"
check "AGENTS.md 引用了规则库" "grep -q 'vibe' AGENTS.md 2>/dev/null"

# 2. 证据文件
check ".vibe-rules 证据文件存在" "[ -f .vibe-rules ]"

# 3. 单文件型（有官方文档的）
check "CLAUDE.md 存在" "[ -e CLAUDE.md ]"
check ".cursorrules 存在" "[ -e .cursorrules ]"
check ".windsurfrules 存在" "[ -e .windsurfrules ]"
check ".github/copilot-instructions.md 存在" "[ -e .github/copilot-instructions.md ]"

# 4. 目录型
check ".cursor/rules/ 存在" "[ -d .cursor/rules ]"
check ".qoder/rules/ 存在" "[ -d .qoder/rules ]"
check ".trae/rules/ 存在" "[ -d .trae/rules ]"
check ".codebuddy/rules/ 存在" "[ -d .codebuddy/rules ]"

echo ""
echo "📊 结果：$PASS 通过，$FAIL 未通过"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "🔧 修复：重新跑 install.sh"
  echo "   $VIBE_HOME/scripts/install.sh $PROJECT_ROOT"
  exit 1
else
  echo ""
  echo "🎉 项目已正确接入 vibe-rules。"
fi

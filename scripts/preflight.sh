#!/usr/bin/env bash
# preflight.sh —— 提交 / 发版前，一条命令跑完所有本地检查
#
# 用法：
#   bash scripts/preflight.sh
#
# 依次跑：打包校验 → 插件清单同步检查 → bash 冒烟 → pwsh 冒烟（本机没装 pwsh 就跳过）。
# CI 跑的是同样的内容（外加 macOS bash 3.2 / Windows pwsh 两档），本地先跑一遍能省一次红。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  awk 'NR > 1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
  exit 0
fi

echo "== 1/4 打包校验（skill 结构 + 插件清单 + 版本） =="
bash scripts/validate-package.sh
echo ""
echo "== 2/4 插件清单同步检查 =="
bash scripts/sync-plugin-skills.sh --check
echo ""
echo "== 3/4 bash 冒烟（端到端） =="
bash tests/smoke.sh
echo ""
echo "== 4/4 pwsh 冒烟（端到端） =="
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -File tests/smoke.ps1
else
  echo "⏭️  本机没有 pwsh，跳过（CI 的 Windows 一档会跑，不是漏测）"
fi
echo ""
echo "🎉 preflight 全绿"

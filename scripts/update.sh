#!/usr/bin/env bash
# update.sh —— 把项目里的 vibe-rules 规则副本刷新到规则库最新版
#
# 用法：
#   /path/to/vibe-rules/scripts/update.sh [项目路径] [install 选项]
#
# 做的事：
#   - 重新复制规则本体到 <项目>/.vibe-rules/（embedded 模式，默认）
#   - 刷新 AGENTS.md 顶部的引用块
#   - 保留 .vibe-rules/project/ 里的项目专属笔记（永不覆盖）
#
# 注意：
#   - 更新前先把规则库本身拉到最新：git -C <规则库> pull
#   - 模式、策略档位（profile）和 agent 选择会自动沿用证据文件（.vibe-rules/installed）
#     里的记录，不用重新选；想改，直接把对应选项传给 install.sh（显式传 --link /
#     --no-personal / --profile 会覆盖沿用值）

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  awk 'NR > 1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

PROJECT_ROOT="$1"
shift

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "❌ 目录不存在：$PROJECT_ROOT"
  exit 1
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

EVIDENCE=""
if [ -f "$PROJECT_ROOT/.vibe-rules/installed" ]; then
  EVIDENCE="$PROJECT_ROOT/.vibe-rules/installed"
elif [ -f "$PROJECT_ROOT/.vibe-rules" ] && [ ! -d "$PROJECT_ROOT/.vibe-rules" ]; then
  EVIDENCE="$PROJECT_ROOT/.vibe-rules"
fi
if [ -z "$EVIDENCE" ]; then
  echo "❌ 项目还没接入 vibe-rules：$PROJECT_ROOT"
  echo "   先跑：$VIBE_HOME/scripts/install.sh $PROJECT_ROOT"
  exit 1
fi

echo "🔄 更新规则副本：$PROJECT_ROOT"

# 没显式指定模式/agent 时，沿用证据文件里的记录（更新不该逼用户重新选一遍）
MODE_FROM_EVIDENCE="$(sed -n 's/^mode=//p' "$EVIDENCE" | head -n 1)"
AGENTS_FROM_EVIDENCE="$(sed -n 's/^agents=//p' "$EVIDENCE" | head -n 1)"
PROFILE_FROM_EVIDENCE="$(sed -n 's/^profile=//p' "$EVIDENCE" | head -n 1)"

# 显式传了 --link / --no-personal / --profile 就按用户的来，不再沿用档位
EXPLICIT_OVERRIDE=false
case " $* " in
  *" --link "*|*" --no-personal "*|*" --profile "*) EXPLICIT_OVERRIDE=true ;;
esac

if [ "$EXPLICIT_OVERRIDE" = false ]; then
  case "$PROFILE_FROM_EVIDENCE" in
    team|hybrid|personal)
      # 档位是装的时候定的策略，更新时原样沿用（team/hybrid 会顺带带上 --no-personal 的语义）
      set -- "$@" --profile "$PROFILE_FROM_EVIDENCE"
      ;;
    *)
      case " $* " in
        *" --link "*) ;;
        *)
          if [ "$MODE_FROM_EVIDENCE" = "link" ]; then
            set -- "$@" --link
          fi
          ;;
      esac
      ;;
  esac
fi

case " $* " in
  *" --agents"*|*" --all "*)
    ;;
  *)
    if [ -n "$AGENTS_FROM_EVIDENCE" ]; then
      set -- "$@" --agents "$AGENTS_FROM_EVIDENCE" --yes
    fi
    ;;
esac

"$VIBE_HOME/scripts/install.sh" "$PROJECT_ROOT" "$@"

echo ""
echo "🎉 规则副本已刷新到最新版。"
echo "   项目专属笔记 .vibe-rules/project/README.md 未被改动。"

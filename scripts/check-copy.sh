#!/usr/bin/env bash
# check-copy.sh —— 校验项目里的规则副本跟规则库是不是逐文件一致（漂移检测）
#
# 用法：
#   /path/to/vibe-rules/scripts/check-copy.sh [项目路径] [--rules-home 规则库路径]
#
# 用途：放进项目自己的 CI（配合 templates/CI-VERIFY.yml），拦住两类漂移：
#   - 有人手改了 .vibe-rules/ 里的规则，但没同步回规则库（下次 update 会被刷掉，白改）
#   - 副本没跟上规则库（仓库里躺着旧规则，agent 读到的是过期的）
#
# 比对范围：.vibe-rules/ 里已有的顶层条目（目录递归）。不参与的只有三样：
#   installed（证据文件）、README.md（由 templates/ENTRY.md 生成）、project/（项目专属笔记）。
#   规则库新增的顶层目录不在这里报（那是 scripts/update 的事）。
#
# 退出码：0 = 一致（或外链模式，没副本可比）；1 = 有漂移 / 项目没接入；2 = 用法错。

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
RULES_HOME="$VIBE_HOME"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  awk 'NR > 1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
  exit 0
fi

PROJECT_ROOT="${1:-$(pwd)}"
if [ $# -gt 0 ]; then shift; fi

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --rules-home)
      if [ $# -lt 2 ]; then
        echo "❌ --rules-home 后面要给规则库目录" >&2
        exit 2
      fi
      RULES_HOME="$2"
      shift 2
      ;;
    *)
      echo "❌ 未知参数：${1}（只支持 --rules-home）" >&2
      exit 2
      ;;
  esac
done

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "❌ 目录不存在：${PROJECT_ROOT}" >&2
  exit 1
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

RULES_DIR="$PROJECT_ROOT/.vibe-rules"
EVIDENCE=""
if [ -f "$RULES_DIR/installed" ]; then
  EVIDENCE="$RULES_DIR/installed"
elif [ -f "$RULES_DIR" ] && [ ! -d "$RULES_DIR" ]; then
  EVIDENCE="$RULES_DIR"
fi
if [ -z "$EVIDENCE" ]; then
  echo "❌ 项目没接入 vibe-rules：${PROJECT_ROOT}"
  echo "   先跑：${VIBE_HOME}/scripts/install.sh \"${PROJECT_ROOT}\""
  exit 1
fi

MODE="$(sed -n 's/^mode=//p' "$EVIDENCE" | head -n 1)"
if [ "$MODE" = "link" ]; then
  echo "⏭️  外链模式（mode=link）：规则库在本机，项目里没有副本可比对，跳过漂移检查"
  exit 0
fi

if [ ! -d "$RULES_HOME" ]; then
  echo "❌ 规则库目录不存在：${RULES_HOME}" >&2
  exit 1
fi
RULES_HOME="$(cd "$RULES_HOME" && pwd)"
if [ "$RULES_HOME" = "$PROJECT_ROOT" ]; then
  echo "❌ 规则库路径和项目路径相同，没法比对：${RULES_HOME}" >&2
  exit 1
fi

echo "🔍 副本漂移检查：${RULES_DIR}"
echo "   规则库：${RULES_HOME}"
echo ""

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

# 副本里有的文件，规则库里也得有、且内容一样
compare_file() {
  local rel="$1"
  if [ ! -e "$RULES_HOME/$rel" ]; then
    bad "${rel}：规则库里没有这个文件（手加进来的？还是上游已经删了？）"
  elif ! cmp -s "$RULES_DIR/$rel" "$RULES_HOME/$rel"; then
    bad "${rel}：内容与规则库不一致（手改过 / 副本没跟上）"
  else
    ok
  fi
}

while IFS= read -r top; do
  [ -e "$top" ] || continue
  name="${top#"$RULES_DIR"/}"
  case "$name" in
    installed|README.md|project) continue ;;
  esac
  if [ -d "$top" ]; then
    while IFS= read -r f; do
      compare_file "${f#"$RULES_DIR"/}"
    done < <(find "$top" -type f -print | sort)
    # 反向：规则库同一目录下多出来的文件 = 副本没跟上
    # （只查副本已有的目录，不猜规则库的顶层：scripts/、tests/ 这些本来就不进副本）
    if [ -d "$RULES_HOME/$name" ]; then
      while IFS= read -r f; do
        rel="${f#"$RULES_HOME"/}"
        if [ ! -e "$RULES_DIR/$rel" ]; then
          bad "${rel}：副本里没有（副本没跟上这版规则库）"
        fi
      done < <(find "$RULES_HOME/$name" -type f -print | sort)
    fi
  else
    compare_file "$name"
  fi
done < <(find "$RULES_DIR" -mindepth 1 -maxdepth 1 -print | sort)

echo ""
echo "📊 check-copy：比对 ${PASS} 个文件，${FAIL} 处漂移"
if [ "$FAIL" -gt 0 ]; then
  echo "🔧 修复：在项目里跑 update 刷新副本；要改规则请改规则库，别改副本"
  exit 1
fi
echo "🎉 副本与规则库一致"

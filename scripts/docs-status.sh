#!/usr/bin/env bash
# docs-status.sh —— 汇总项目里的 spec / plan 状态，找出过期文档，归档已完成文档
#
# 用法：
#   /path/to/vibe-rules/scripts/docs-status.sh [项目路径] [选项]
#
# 选项：
#   --stale N     列出超过 N 天没更新、且还没完成的文档（默认 30；0 = 不列）
#   --check       发现缺「状态行」的文档就报错退出（给 CI / 提交前检查用）
#   --archive     把 status: done / abandoned 的文档移到同目录的 archive/
#   -h, --help    显示帮助
#
# 状态行约定（每份文档开头，见模板 templates/DOCS-SPECS.md）：
#   > status: active · updated: 2026-09-13
#   status ∈ draft | active | done | abandoned
#
# 说明：这个脚本在规则库里，不在项目副本里（副本只带规则本体）。

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  awk 'NR > 1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
}

PROJECT_ROOT=""
STALE_DAYS=30
CHECK_ONLY=false
ARCHIVE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --stale)
      shift
      if [ $# -eq 0 ]; then
        echo "❌ --stale 需要天数，例如 --stale 30"
        exit 1
      fi
      STALE_DAYS="$1"
      ;;
    --stale=*) STALE_DAYS="${1#--stale=}" ;;
    --check) CHECK_ONLY=true ;;
    --archive) ARCHIVE=true ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "❌ 未知参数：$1"
      echo ""
      usage
      exit 1
      ;;
    *) PROJECT_ROOT="$1" ;;
  esac
  shift
done

case "$STALE_DAYS" in
  ''|*[!0-9]*)
    echo "❌ --stale 需要非负整数，收到：$STALE_DAYS"
    exit 1
    ;;
esac

if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(pwd)"
fi
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "❌ 目录不存在：$PROJECT_ROOT"
  exit 1
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

# 今天距某个 YYYY-MM-DD 多少天；日期不合法或没有 python3 时输出空
days_ago() {
  python3 -c 'import sys, datetime
try:
    d = datetime.date.fromisoformat(sys.argv[1])
except Exception:
    print("")
    raise SystemExit
print((datetime.date.today() - d).days)' "$1" 2>/dev/null || true
}

# 文档最后修改日期（YYYY-MM-DD）；macOS/GNU 的 date -r 都支持
file_date() {
  date -r "$1" +%Y-%m-%d 2>/dev/null || true
}

echo "🔍 文档状态：$PROJECT_ROOT"
echo ""

TOTAL=0
UNMARKED=0
DONE_COUNT=0
STALE_LIST=""
ARCHIVE_LIST=""
FOUND_ANY_DIR=false

for dir in docs/specs docs/plans; do
  [ -d "$PROJECT_ROOT/$dir" ] || continue
  FOUND_ANY_DIR=true
  echo "📁 $dir/"

  DIR_COUNT=0
  for f in "$PROJECT_ROOT/$dir"/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    [ "$base" = "README.md" ] && continue
    DIR_COUNT=$((DIR_COUNT + 1))
    TOTAL=$((TOTAL + 1))

    status_line="$(head -n 10 "$f" | grep -m 1 -E '^[[:space:]]*>[[:space:]]*status[[:space:]]*:' || true)"
    status=""
    if [ -n "$status_line" ]; then
      status="$(printf '%s\n' "$status_line" | sed -E 's/.*status[[:space:]]*:[[:space:]]*([A-Za-z_-]+).*/\1/')"
    fi
    updated="$(printf '%s\n' "$status_line" | sed -nE 's/.*updated[[:space:]]*:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/p')"
    if [ -z "$updated" ]; then
      updated="$(file_date "$f")"
    fi
    age="$(days_ago "$updated")"

    title="$(grep -m 1 '^# ' "$f" 2>/dev/null | sed 's/^# //' || true)"
    [ -n "$title" ] || title="（无标题）"

    case "$status" in
      draft)     mark="📝" ;;
      active)    mark="🚧" ;;
      done)      mark="✅" ; DONE_COUNT=$((DONE_COUNT + 1)) ;;
      abandoned) mark="🗑"  ; DONE_COUNT=$((DONE_COUNT + 1)) ;;
      *)
        mark="⚪"
        UNMARKED=$((UNMARKED + 1))
        ;;
    esac

    if [ -n "$age" ]; then
      age_text="${age} 天前"
    else
      age_text="天数未知"
    fi

    printf '  %s %-9s %s（%s）  %s — %s\n' "$mark" "${status:-未标注}" "${updated:-无日期}" "$age_text" "$base" "$title"

    # 过期检查：没写完（draft/active/未标注）且超过 N 天没更新
    if [ "$STALE_DAYS" -gt 0 ] && [ -n "$age" ] && [ "$age" -ge "$STALE_DAYS" ]; then
      case "$status" in
        done|abandoned) ;;
        *) STALE_LIST="$STALE_LIST  $dir/${base}（${status:-未标注}，${age} 天没更新）\n" ;;
      esac
    fi

    # 归档候选：已完成 / 已放弃
    case "$status" in
      done|abandoned) ARCHIVE_LIST="$ARCHIVE_LIST$dir|$base\n" ;;
    esac
  done

  if [ "$DIR_COUNT" -eq 0 ]; then
    echo "  （还没有文档）"
  fi
  echo ""
done

if [ "$FOUND_ANY_DIR" = false ]; then
  echo "⚠️  项目里没有 docs/specs/ 或 docs/plans/——重跑 install.sh 会建档，且不会覆盖已有内容"
  echo ""
fi

echo "📊 共 ${TOTAL} 份文档：已完成 ${DONE_COUNT}，未标注状态 ${UNMARKED}"
echo ""

if [ -n "$STALE_LIST" ]; then
  echo "⚠️  超过 $STALE_DAYS 天没更新、且还没完成："
  printf "%b" "$STALE_LIST"
  echo "   → 要么推进，要么把状态改成 done / abandoned（别让下一个 agent 猜）"
  echo ""
fi

if [ "$ARCHIVE" = true ]; then
  if [ -z "$ARCHIVE_LIST" ]; then
    echo "📦 没有可归档的文档（没有 status: done / abandoned 的 spec/plan）"
  else
    echo "📦 归档已完成的文档："
    printf "%b" "$ARCHIVE_LIST" | while IFS='|' read -r dir base; do
      [ -n "$base" ] || continue
      src="$PROJECT_ROOT/$dir/$base"
      [ -f "$src" ] || continue
      mkdir -p "$PROJECT_ROOT/$dir/archive"
      rel="$dir/$base"
      target_rel="$dir/archive/$base"
      if [ -e "$PROJECT_ROOT/$target_rel" ]; then
        target_rel="$dir/archive/$(basename "$base" .md)-$(date +%s).md"
      fi
      if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1 && \
         git -C "$PROJECT_ROOT" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
        git -C "$PROJECT_ROOT" mv "$rel" "$target_rel"
      else
        mv "$src" "$PROJECT_ROOT/$target_rel"
      fi
      echo "   $rel → $target_rel"
    done
    echo "   （归档的文件不再出现在上面的汇总里；git 历史仍在）"
  fi
  echo ""
fi

if [ "$CHECK_ONLY" = true ] && [ "$UNMARKED" -gt 0 ]; then
  echo "❌ 有 $UNMARKED 份文档没写状态行——在文件开头加一行："
  echo "   > status: active · updated: $(date +%Y-%m-%d)"
  echo "   （status ∈ draft | active | done | abandoned）"
  exit 1
fi

echo "✅ 状态检查通过"

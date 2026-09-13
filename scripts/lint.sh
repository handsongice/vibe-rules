#!/usr/bin/env bash
# lint.sh —— 规则库自身的静态检查（开发工具，不随副本进项目）
#
# 用法：
#   scripts/lint.sh [目录]        # 不传目录就检查本仓库
#
# 查三类"已经真出过事"的问题：
#   1. $VAR 后紧跟非 ASCII 字符 —— bash 3.2 / 5.x 都会把变量名吞进后续字节（必须写 ${VAR}）
#      只查命名变量（$1 这类位置参数不会 unbound，但输出仍可能乱，属另一类）；只查 .sh
#   2. sh / ps1 配对 —— 成对的安装类脚本不能只改一半
#   3. 选项对称 —— sh 里认识的每个 --flag，ps1 里必须有对应参数（--no-personal ↔ -NoPersonal）
#
# 退出码：0 = 全过；1 = 有发现。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-$REPO_ROOT}"

if [ "$TARGET" = "-h" ] || [ "$TARGET" = "--help" ]; then
  awk 'NR > 1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
  exit 0
fi
if [ ! -d "$TARGET" ]; then
  echo "❌ 目录不存在：$TARGET"
  exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

# 只在 sh 一侧做的工具（不是 sh/ps1 成对脚本）：都是规则库自己的开发工具，
# 不随副本进项目，Windows 上跑不了属预期。往这里加名字 = 显式承认单侧。
SH_ONLY_TOOLS="bump-version docs-status preflight sync-plugin-skills validate-package lint check-copy"

# ---------- 小工具 ----------

# sh 里认识的 --flag：只看 case 分支标签、case 模式、引号里的字面量，
# 避免把注释和 rsync 自己的参数（--exclude=…）当成选项
sh_flags() {
  {
    grep -hE '^[[:space:]]*--[a-z][a-z-]*([|].*)?\)' "$1" || true
    grep -hE '^[[:space:]]*\*.*--' "$1" || true
    grep -hE '"--[a-z][a-z-]*"' "$1" | grep -vE '^[[:space:]]*#' || true
    # || true：set -e + pipefail 下，没有匹配时 grep 的退出码 1 会直接干掉整个 lint
  } | grep -oE -- '--[a-z][a-z-]*' | sed 's/^--//' | sort -u || true
}

# ps1 里声明的参数：param() 里 [switch]/[string]/… 后面跟的 $Name
ps1_params() {
  grep -oE '\[(switch|string|int|bool)\][[:space:]]*\$[A-Za-z][A-Za-z0-9]*' "$1" \
    | sed 's/.*\$//' | tr '[:upper:]' '[:lower:]' | sort -u || true   # 同上：param() 为空不能拖垮整个 lint
}

# 归一化：去掉减号；两边用词不同的个别选项在这里对齐
normalize_flag() {
  local name
  name="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '-')"
  case "$name" in
    agents) name="agentnums" ;;   # sh: --agents 1,3  ↔  ps1: -AgentNums 1,3
  esac
  printf '%s' "$name"
}

echo "🔍 检查 $TARGET"
echo ""

# ---------- ① $VAR 后接非 ASCII ----------
echo "① \$VAR 后紧跟非 ASCII 字符（命名变量，位置参数不会 unbound）"
VAR_HIT=0
while IFS= read -r f; do
  rel="${f#"$TARGET"/}"
  # 注释行跳过：注释里的字面量不会被执行，属误报
  hits="$(LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~]' "$f" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
  if [ -n "$hits" ]; then
    VAR_HIT=1
    FAIL=$((FAIL+1))            # 记进总数：只打印不计数的话汇总会假绿
    echo "  ❌ $rel"
    printf '%s\n' "$hits" | sed 's/^/       /'
    echo "     → 写成 \${VAR}（加花括号），bash 3.2 也不会吞"
  fi
done < <(find "$TARGET" -name '*.sh' -not -path '*/.git/*' -print | sort)
if [ "$VAR_HIT" -eq 0 ]; then ok "没有 \$VAR 紧贴非 ASCII 的写法"; fi

# ---------- ② sh / ps1 配对 ----------
echo ""
echo "② sh / ps1 配对"
PAIR_HIT=0
for f in "$TARGET"/scripts/*.sh; do
  [ -e "$f" ] || continue
  base="$(basename "$f" .sh)"
  case " $SH_ONLY_TOOLS " in *" $base "*) continue ;; esac
  if [ ! -f "$TARGET/scripts/$base.ps1" ]; then
    bad "scripts/$base.sh 缺对应的 scripts/$base.ps1（改一半两边行为就不一样了；确认单侧就写进 lint.sh 的 SH_ONLY_TOOLS）"
    PAIR_HIT=1
  fi
done
for f in "$TARGET"/scripts/*.ps1; do
  [ -e "$f" ] || continue
  base="$(basename "$f" .ps1)"
  case " $SH_ONLY_TOOLS " in
    *" $base "*)
      if [ -f "$TARGET/scripts/$base.sh" ]; then
        bad "scripts/$base 两个扩展名都有了，请从 lint.sh 的 SH_ONLY_TOOLS 里去掉"
        PAIR_HIT=1
      fi
      continue
      ;;
  esac
  if [ ! -f "$TARGET/scripts/$base.sh" ]; then
    bad "scripts/$base.ps1 缺对应的 scripts/$base.sh（改一半两边行为就不一样了）"
    PAIR_HIT=1
  fi
done
if [ "$PAIR_HIT" -eq 0 ]; then ok "成对脚本两边都在（单侧工具：${SH_ONLY_TOOLS}）"; fi

# ---------- ③ 选项对称 ----------
echo ""
echo "③ 选项对称（sh 的 --flag ⊆ ps1 的参数）"
OPT_HIT=0
for f in "$TARGET"/scripts/*.sh; do
  [ -e "$f" ] || continue
  base="$(basename "$f" .sh)"
  case " $SH_ONLY_TOOLS " in *" $base "*) continue ;; esac
  ps1="$TARGET/scripts/$base.ps1"
  [ -f "$ps1" ] || continue          # 配对缺失上一条已经报过
  flags="$(sh_flags "$f")"
  [ -n "$flags" ] || continue
  params="$(ps1_params "$ps1")"
  while IFS= read -r flag; do
    [ -n "$flag" ] || continue
    want="$(normalize_flag "$flag")"
    if ! printf '%s\n' "$params" | grep -qx "$want"; then
      bad "scripts/$base.sh 认 --${flag}，scripts/$base.ps1 里没有对应参数"
      OPT_HIT=1
    fi
  done <<EOF
$flags
EOF
done
if [ "$OPT_HIT" -eq 0 ]; then ok "sh 侧认的选项在 ps1 侧都有对应参数"; fi

# ---------- 汇总 ----------
echo ""
echo "📊 lint：$PASS 通过，$FAIL 失败"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "🎉 全部通过"

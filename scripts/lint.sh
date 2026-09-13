#!/usr/bin/env bash
# lint.sh —— 规则库自身的静态检查（开发工具，不随副本进项目）
#
# 用法：
#   scripts/lint.sh [目录]        # 不传目录就检查本仓库
#
# 查六类"已经真出过事"的问题：
#   1. $VAR 后紧跟非 ASCII 字符 —— bash 3.2 / 5.x 都会把变量名吞进后续字节（必须写 ${VAR}）
#      只查命名变量（$1 这类位置参数不会 unbound，但输出仍可能乱，属另一类）；只查 .sh
#   2. sh / ps1 配对 —— 成对的安装类脚本不能只改一半
#   3. 选项对称（双向）—— sh 里认识的每个 --flag，ps1 顶层 param() 必须有对应参数
#      （--no-personal ↔ -NoPersonal）；ps1 多出来的参数同样要报，ps1 原生约定走白名单。
#      另外：new-project / update 是"原样透传 install 选项"的脚本，ps1 必须覆盖 install.sh
#      的全部选项——漏一个就是 Windows 侧少个功能（sh 侧 "$@" 转发看不出来）
#   4. skills/*/SKILL.md 的 ## 触发条件 段存在且非空 —— agent 靠它决定什么时候加载
#      （frontmatter 字段 / 打包契约由 validate-package.sh 查，这里只管内容质量）
#   5. bash -n 语法 —— 未闭合的引号 / 反引号会被 bash 吞掉半段脚本，肉眼 review 最容易漏
#   6. README 选项同步（双向）—— README 提到、但所有脚本都不认的 --flag；反过来脚本认、
#      README 从没提的也报（维护者内部选项，如 bump-version 的 --no-changelog，走白名单）
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

# "原样透传 install 选项"的脚本：sh 侧用 "$@" 转发，sh_flags 看不到它们的选项，
# 所以单独校验：ps1 顶层 param() 必须覆盖 install.sh 的每个选项
PASSTHROUGH_TOOLS="new-project update"

# ---------- 小工具 ----------

# sh 里认识的 --flag：只看 case 分支标签、case 模式、引号里的字面量，
# 避免把注释和 rsync 自己的参数（--exclude=…）当成选项
sh_flags() {
  # 选项名允许数字（--sha1 / --2fa 这类）：[a-z0-9] 打头、后面 [a-z0-9-]，
  # 少写这个数字的话，带数字的选项会被静默漏掉——比误报危险
  {
    # 放行 -h|--help) 这种带短参的 case 标签（install / update / verify 都这么写）
    grep -hE '^[[:space:]]*([-][a-zA-Z][|])?--[a-z0-9][a-z0-9-]*([|].*)?\)' "$1" || true
    grep -hE '^[[:space:]]*\*.*--' "$1" || true
    grep -hE '"--[a-z0-9][a-z0-9-]*"' "$1" | grep -vE '^[[:space:]]*#' || true
    # || true：set -e + pipefail 下，没有匹配时 grep 的退出码 1 会直接干掉整个 lint
  } | grep -oE -- '--[a-z0-9][a-z0-9-]*' | sed 's/^--//' | sort -u || true
}

# ps1 顶层 param() 块里声明的参数（保留原大小写，报错时给用户看）—— 只认脚本级，
# 不扫内部小函数的 param()，否则 install.ps1 里 Function X { param([string]$File) } 会误报成脚本选项
ps1_script_params_raw() {
  awk '
    begun == 0 && match($0, /^[[:space:]]*param[[:space:]]*\(/) {
      begun = 1
      rest = substr($0, RSTART + RLENGTH)
      if (rest ~ /\)/) { print rest; exit }   # 单行 param(...)，只取本行
      next
    }
    begun == 1 && $0 ~ /^[[:space:]]*\)[[:space:]]*$/ { exit }
    begun == 1 { print }
  ' "$1" \
    | grep -oE '\[(switch|string|int|bool)\][[:space:]]*\$[A-Za-z][A-Za-z0-9]*' \
    | sed 's/.*\$//' | sort -u || true   # 同上：没有 param() 不能拖垮整个 lint
}

# 比对用的小写清单
ps1_script_params() {
  ps1_script_params_raw "$1" | tr '[:upper:]' '[:lower:]'
}

# 反向白名单：ps1 顶层参数里允许 sh 侧没有的（"脚本名:参数"，参数已归一化）
#   - help / projectroot：sh 版用行内 -h|--help 与位置参数，天生没有对应的 --flag
#   - update / new-project：sh 版把整串参数原样透传给 install.sh，不自己解析这些选项
#   - migrate：sh 版收 $1/$2 位置参数，ps1 版用 -SrcSlug / -DstSlug
ps1_extra_allowed() {
  case "$1:$2" in
    *:help|*:projectroot) return 0 ;;
    update:all|update:agentnums|update:link|update:nopersonal|update:copy|update:withci|update:yes) return 0 ;;
    new-project:all|new-project:agentnums|new-project:link|new-project:nopersonal|new-project:profile|new-project:copy|new-project:withci|new-project:yes) return 0 ;;
    migrate:srcslug|migrate:dstslug) return 0 ;;
  esac
  return 1
}

# README 反向检查的白名单：脚本认、但故意不写进 README 的维护者内部选项
#   no-changelog：bump-version.sh 的发版用法，使用者抄不到这个命令，写进 README 只是噪音
flag_doc_allowed() {
  case "$1" in
    no-changelog) return 0 ;;
  esac
  return 1
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

# ---------- ③ 选项对称（双向） ----------
echo ""
echo "③ 选项对称（sh→ps1；ps1 多出按白名单；new-project/update 覆盖 install 全量选项）"
OPT_HIT=0
for f in "$TARGET"/scripts/*.sh; do
  [ -e "$f" ] || continue
  base="$(basename "$f" .sh)"
  case " $SH_ONLY_TOOLS " in *" $base "*) continue ;; esac
  ps1="$TARGET/scripts/$base.ps1"
  [ -f "$ps1" ] || continue          # 配对缺失上一条已经报过
  flags="$(sh_flags "$f")"
  params_raw="$(ps1_script_params_raw "$ps1")"
  params="$(ps1_script_params "$ps1")"
  # 归一化后的 sh 清单（--no-personal → nopersonal），反向检查要拿它跟 ps1 参数比
  flags_norm="$(printf '%s\n' "$flags" | while IFS= read -r x; do [ -n "$x" ] || continue; normalize_flag "$x"; echo; done)"
  # 正向：sh 认的每个选项，ps1 顶层 param() 必须有
  if [ -n "$flags" ]; then
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
  fi
  # 反向：ps1 顶层 param() 多出来的（白名单之外）= 只加了 Windows 侧
  if [ -n "$params_raw" ]; then
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      want="$(normalize_flag "$p")"
      if ! printf '%s\n' "$flags_norm" | grep -qx "$want"; then
        if ! ps1_extra_allowed "$base" "$want"; then
          bad "scripts/$base.ps1 有参数 -${p}，sh 侧没有对应 --${p}，也不在白名单（只加了 Windows 侧？）"
          OPT_HIT=1
        fi
      fi
    done <<EOF
$params_raw
EOF
  fi
  # 透传脚本：ps1 顶层参数必须覆盖 install.sh 的全部选项
  # （sh 侧用 "$@" 原样转发，sh_flags 看不到选项；漏声明的后果只在 Windows 上炸）
  case " $PASSTHROUGH_TOOLS " in *" $base "*)
    if [ -f "$TARGET/scripts/install.sh" ]; then
      install_flags="$(sh_flags "$TARGET/scripts/install.sh")"
      while IFS= read -r iflag; do
        [ -n "$iflag" ] || continue
        want="$(normalize_flag "$iflag")"
        if ! printf '%s\n' "$params" | grep -qx "$want"; then
          bad "scripts/$base.ps1 少了 install.sh --${iflag} 对应的参数（Windows 侧漏转发一个选项）"
          OPT_HIT=1
        fi
      done <<EOF
$install_flags
EOF
    fi
    ;;
  esac
done
if [ "$OPT_HIT" -eq 0 ]; then ok "sh / ps1 选项双向对齐（ps1 原生约定走白名单）"; fi

# ---------- ④ SKILL.md 触发条件 ----------
# frontmatter 字段 / 打包契约归 validate-package.sh；这里查内容质量里最容易漏的"什么时候加载"
echo ""
echo "④ SKILL.md 的 ## 触发条件 段（存在且非空）"
SKILL_HIT=0
SKILL_COUNT=0
for f in "$TARGET"/skills/*/SKILL.md; do
  [ -e "$f" ] || continue
  SKILL_COUNT=$((SKILL_COUNT+1))
  rel="${f#"$TARGET"/}"
  if ! grep -qE '^##[[:space:]]+.*触发条件' "$f"; then
    bad "$rel 没有 ## 触发条件 段（agent 靠它决定什么时候加载这个 skill）"
    SKILL_HIT=1
    continue
  fi
  body="$(awk '/^##[[:space:]]+.*触发条件/{inside=1; next} /^##[[:space:]]/{inside=0} inside{print}' "$f" | tr -d '[:space:]')"
  if [ "${#body}" -lt 10 ]; then
    bad "$rel 的触发条件段是空的（写清：用户说什么 / 什么任务下加载）"
    SKILL_HIT=1
  fi
done
if [ "$SKILL_HIT" -eq 0 ]; then
  if [ "$SKILL_COUNT" -eq 0 ]; then
    ok "没有 skills/ 目录，跳过（目标不是规则库）"
  else
    ok "${SKILL_COUNT} 个 skill 的触发条件都写了"
  fi
fi

# ---------- ⑤ bash -n 语法 ----------
# 未闭合的引号 / 反引号会改掉整个脚本的解析，肉眼 review 很难发现，交给 bash 自己的解析器
echo ""
echo "⑤ bash -n 语法检查（引号 / 反引号配对）"
SYN_HIT=0
SYN_COUNT=0
while IFS= read -r f; do
  SYN_COUNT=$((SYN_COUNT+1))
  rel="${f#"$TARGET"/}"
  err="$(bash -n "$f" 2>&1)" || {
    bad "$rel 语法错误（bash -n 没过——多半是引号 / 反引号没配对）"
    printf '%s\n' "$err" | sed 's/^/       /'
    SYN_HIT=1
  }
done < <(find "$TARGET" -name '*.sh' -not -path '*/.git/*' -print | sort)
if [ "$SYN_HIT" -eq 0 ]; then ok "$SYN_COUNT 个 sh 脚本语法通过"; fi

# ---------- ⑥ README 选项同步（双向） ----------
# 方向一：README 写了、但没有任何脚本认（改了选项忘改文档）
# 方向二：脚本认了、README 从没提（加了选项忘写文档；维护者内部选项走白名单）
echo ""
echo "⑥ README 与脚本选项双向同步"
README_HIT=0
if [ -f "$TARGET/README.md" ]; then
  known=""
  for f in "$TARGET"/scripts/*.sh; do
    [ -e "$f" ] || continue
    known="$known$(sh_flags "$f")"$'\n'
  done
  doc_flags="$(grep -oE -- '--[a-z0-9][a-z0-9-]*' "$TARGET/README.md" | sed 's/^--//' | sort -u || true)"
  while IFS= read -r flag; do
    [ -n "$flag" ] || continue
    if ! printf '%s\n' "$known" | grep -qx "$flag"; then
      bad "README 提到 --${flag}，但没有任何脚本认这个选项（改了选项忘改文档？）"
      README_HIT=1
    fi
  done <<EOF
$doc_flags
EOF
  # 反向：脚本认的选项，README 得提（白名单除外）
  while IFS= read -r flag; do
    [ -n "$flag" ] || continue
    if ! LC_ALL=C grep -qE -- "--${flag}([^a-z0-9-]|$)" "$TARGET/README.md"; then
      if ! flag_doc_allowed "$flag"; then
        bad "scripts 认 --${flag}，但 README 从没提（加了选项忘写文档？内部选项请进 lint.sh 白名单）"
        README_HIT=1
      fi
    fi
  done <<EOF
$known
EOF
  if [ "$README_HIT" -eq 0 ]; then ok "README 与脚本选项双向同步"; fi
else
  ok "没有 README.md，跳过"
fi

# ---------- 汇总 ----------
echo ""
echo "📊 lint：$PASS 通过，$FAIL 失败"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "🎉 全部通过"

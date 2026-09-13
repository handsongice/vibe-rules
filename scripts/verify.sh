#!/usr/bin/env bash
# verify.sh —— 检查项目是否正确接入 vibe-rules
#
# 用法：
#   /path/to/vibe-rules/scripts/verify.sh [项目路径]
#
# 不传项目路径时检查当前目录。
# 只检查 .vibe-rules 证据文件里记录过的 agent，不会因为「没装某个 agent」报错。

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
CONF_FILE="$VIBE_HOME/scripts/agents.conf"
PROJECT_ROOT="${1:-$(pwd)}"

if [ "$PROJECT_ROOT" = "-h" ] || [ "$PROJECT_ROOT" = "--help" ]; then
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "❌ 目录不存在：$PROJECT_ROOT"
  exit 1
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
cd "$PROJECT_ROOT"

echo "🔍 检查 $PROJECT_ROOT"
echo ""

PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
warn() { echo "  ⚠️  $1"; }

# ---------- 1. 证据文件 ----------
EVIDENCE=""
if [ -f ".vibe-rules/installed" ]; then
  EVIDENCE=".vibe-rules/installed"
elif [ -f ".vibe-rules" ] && [ ! -d ".vibe-rules" ]; then
  EVIDENCE=".vibe-rules"
fi
if [ -z "$EVIDENCE" ]; then
  echo "  ❌ 未接入：缺少 .vibe-rules/installed 证据文件"
  echo ""
  echo "🔧 修复："
  echo "   $VIBE_HOME/scripts/install.sh $PROJECT_ROOT"
  exit 1
fi
ok "证据文件存在：$EVIDENCE"

MODE="$(sed -n 's/^mode=//p' "$EVIDENCE" | head -n 1)"
RULES_HOME="$(sed -n 's/^rules_home=//p' "$EVIDENCE" | head -n 1)"
RULES_VERSION="$(sed -n 's/^rules_version=//p' "$EVIDENCE" | head -n 1)"
INSTALLED="$(sed -n 's/^agents=//p' "$EVIDENCE" | head -n 1 | tr ',' ' ')"

# 兼容旧版证据文件（没有 mode 字段）：一律按外链模式校验
if [ -z "$MODE" ]; then
  MODE="link"
fi

if [ "$MODE" = "embedded" ] || [ "$MODE" = "link" ]; then
  ok "模式：$MODE"
else
  bad "证据文件 mode 值无效：${MODE}（应为 embedded 或 link）"
fi

# 策略档位提前读出来：第 2 节的个人层说明和第 2b 节的档位校验都要用
PROFILE="$(sed -n 's/^profile=//p' "$EVIDENCE" | head -n 1)"
if [ -z "$PROFILE" ]; then
  PROFILE="default"   # 兼容旧版证据文件（没有 profile 字段）
fi

# ---------- 2. 规则本体 ----------
if [ "$MODE" = "embedded" ]; then
  if [ -f "$PROJECT_ROOT/.vibe-rules/README.md" ]; then
    ok "副本入口存在：.vibe-rules/README.md"
  else
    bad "副本入口缺失：.vibe-rules/README.md（重跑 install.sh 刷新副本）"
  fi

  for extra in global/iron-rules.md global/anti-patterns.md skills/README.md; do
    if [ -f "$PROJECT_ROOT/.vibe-rules/$extra" ]; then
      ok "副本含 $extra"
    else
      bad "副本缺少 $extra"
    fi
  done
  if [ -d "$PROJECT_ROOT/.vibe-rules/languages" ]; then
    ok "副本含 languages/（技术栈规范）"
  else
    bad "副本缺少 languages/"
  fi

  if [ -f "$PROJECT_ROOT/.vibe-rules/project/README.md" ]; then
    ok "项目专属笔记存在：.vibe-rules/project/README.md"
  else
    warn "缺少 .vibe-rules/project/README.md（重跑 install.sh 会建档，且不会覆盖已有内容）"
  fi

  if [ -f "$PROJECT_ROOT/.vibe-rules/personal/preferences.md" ]; then
    ok "副本含 personal/（个人偏好与记忆）"
  elif [ "$PROFILE" = "hybrid" ]; then
    ok "副本不含 personal/（混合档：个人层走本机外链，符合预期）"
  else
    warn "副本不含 personal/（安装时用了 --no-personal，属正常）"
  fi
else
  if [ -n "$RULES_HOME" ] && [ -d "$RULES_HOME" ]; then
    ok "规则库路径有效：$RULES_HOME"
  else
    bad "规则库路径失效：${RULES_HOME:-（空）}（被移动或删除？重跑 install.sh）"
  fi

  if [ -n "$RULES_HOME" ] && [ -f "$RULES_HOME/README.md" ]; then
    ok "规则库入口存在：README.md"
  else
    bad "规则库入口缺失：${RULES_HOME:-?}/README.md"
  fi

  for extra in personal/preferences.md personal/memory.md global/anti-patterns.md; do
    if [ -n "$RULES_HOME" ] && [ -f "$RULES_HOME/$extra" ]; then
      :
    else
      warn "规则库中缺少 ${extra}（AGENTS.md 引用块会指向空路径）"
    fi
  done
fi

# ---------- 2b. 策略档位（本地/团队策略有没有真的落实） ----------
IGNORES_VIBE=false
if [ -f ".gitignore" ] && grep -qE '^[[:space:]]*/?\.vibe-rules/?[[:space:]]*$' .gitignore; then
  IGNORES_VIBE=true
fi

case "$PROFILE" in
  default)
    ok "策略档位：default（未指定，按细粒度选项走）"
    ;;
  team)
    ok "策略档位：team（团队共享）"
    if [ "$MODE" != "embedded" ]; then
      bad "团队档要求自包含副本模式，实际是 ${MODE}（重跑 install.sh --profile team）"
    fi
    if [ -d "$PROJECT_ROOT/.vibe-rules/personal" ]; then
      bad "团队档副本里不该有 personal/（个人偏好会跟着进仓库；重跑 install.sh --profile team）"
    else
      ok "团队档：副本不含 personal/"
    fi
    if [ "$IGNORES_VIBE" = true ]; then
      bad "团队档：.gitignore 忽略了 .vibe-rules/，副本进不了仓库（队友/云端/CI 读不到）"
    else
      ok "团队档：.vibe-rules/ 没有被 .gitignore 排除"
    fi
    ;;
  hybrid)
    ok "策略档位：hybrid（副本进仓库 + personal/ 本机外链）"
    if [ "$MODE" != "embedded" ]; then
      bad "混合档要求自包含副本模式，实际是 ${MODE}（重跑 install.sh --profile hybrid）"
    fi
    if [ -d "$PROJECT_ROOT/.vibe-rules/personal" ]; then
      bad "混合档副本里不该有 personal/（个人偏好会跟着进仓库；重跑 install.sh --profile hybrid）"
    else
      ok "混合档：副本不含 personal/"
    fi
    if [ "$IGNORES_VIBE" = true ]; then
      bad "混合档：.gitignore 忽略了 .vibe-rules/，副本进不了仓库（队友/云端/CI 读不到）"
    else
      ok "混合档：.vibe-rules/ 没有被 .gitignore 排除"
    fi
    if [ -n "$RULES_HOME" ] && [ -d "$RULES_HOME/personal" ]; then
      ok "混合档：本机个人层存在（$RULES_HOME/personal）"
    else
      warn "混合档：本机规则库里没有 personal/（换台机器就读不到个人偏好）"
    fi
    if [ -f "$PROJECT_ROOT/AGENTS.md" ] && grep -qF "$RULES_HOME/personal" "$PROJECT_ROOT/AGENTS.md" 2>/dev/null; then
      ok "混合档：AGENTS.md 第 3 条指向本机 personal/"
    else
      bad "混合档：AGENTS.md 没指向本机 personal/（重跑 install.sh --profile hybrid）"
    fi
    ;;
  personal)
    ok "策略档位：personal（个人自用）"
    if [ "$MODE" != "link" ]; then
      bad "个人档要求外链模式，实际是 ${MODE}（重跑 install.sh --profile personal）"
    fi
    if [ "$IGNORES_VIBE" = false ]; then
      warn "个人档：.vibe-rules 没被 .gitignore 忽略，本机路径会被提交（加一行 .vibe-rules 即可）"
    else
      ok "个人档：.vibe-rules 已被 .gitignore 忽略"
    fi
    ;;
  *)
    bad "证据文件 profile 值无效：${PROFILE}（应为 team / hybrid / personal / default）"
    ;;
esac

# 项目文档约定（规格驱动）：副本模式下由 install 建档
if [ "$MODE" = "embedded" ]; then
  for docdir in docs/specs docs/plans; do
    if [ -f "$PROJECT_ROOT/$docdir/README.md" ]; then
      ok "文档约定已就位：$docdir/README.md"
    else
      warn "缺少 $docdir/README.md（重跑 install.sh 会建档，且不会覆盖已有内容）"
    fi
  done
fi

# ---------- 3. AGENTS.md 引用块 ----------
if [ -f "AGENTS.md" ]; then
  ok "项目根有 AGENTS.md"
  if grep -q '<!-- vibe-rules:begin' AGENTS.md 2>/dev/null; then
    ok "AGENTS.md 含 vibe-rules 引用块"
    if [ "$MODE" = "embedded" ]; then
      if grep -qF '.vibe-rules/README.md' AGENTS.md 2>/dev/null; then
        ok "引用块指向项目内副本（.vibe-rules/）"
      else
        bad "引用块不是指向项目内副本（重跑 install.sh 刷新）"
      fi
    else
      if [ -n "$RULES_HOME" ] && grep -qF "$RULES_HOME" AGENTS.md 2>/dev/null; then
        ok "引用块指向当前规则库路径"
      else
        bad "引用块里的规则库路径不是当前路径（重跑 install.sh 即可刷新）"
      fi
    fi
  else
    bad "AGENTS.md 缺少 vibe-rules 引用块（重跑 install.sh 注入）"
  fi
else
  bad "项目根没有 AGENTS.md"
fi

# ---------- 4. 入口文件（只查装过的） ----------
if [ ! -f "$CONF_FILE" ]; then
  bad "缺少 agent 清单：$CONF_FILE"
else
  NUMS=()
  NAMES=()
  TYPES=()
  PATHS=()
  while IFS='|' read -r num name type path doc; do
    case "$num" in
      ''|'#'*) continue ;;
    esac
    NUMS+=("$num")
    NAMES+=("$name")
    TYPES+=("$type")
    PATHS+=("$path")
  done < "$CONF_FILE"

  INSTALLED_SELECTED=" "
  for token in $INSTALLED; do
    found=false
    i=0
    while [ $i -lt "${#NUMS[@]}" ]; do
      if [ "$token" = "${NUMS[$i]}" ]; then
        found=true
        break
      fi
      i=$((i+1))
    done
    if [ "$found" = true ]; then
      INSTALLED_SELECTED="$INSTALLED_SELECTED$token "
    else
      bad "证据文件里的 agent 编号无效：$token"
    fi
  done

  if [ "$INSTALLED_SELECTED" = " " ]; then
    bad "证据文件没有记录任何 agent（重跑 install.sh）"
  fi

  echo ""
  echo "🔗 已安装 agent 的入口文件："
  i=0
  while [ $i -lt "${#NUMS[@]}" ]; do
    num="${NUMS[$i]}"
    name="${NAMES[$i]}"
    type="${TYPES[$i]}"
    path="${PATHS[$i]}"
    i=$((i+1))

    case "$INSTALLED_SELECTED" in
      *" $num "*) ;;
      *) continue ;;
    esac

    case "$type" in
      native)
        ok "${name}：原生读 AGENTS.md"
        ;;
      single)
        if [ -L "$path" ]; then
          dest="$(readlink "$path")"
          case "$dest" in
            AGENTS.md|../AGENTS.md|"$PROJECT_ROOT/AGENTS.md")
              ok "${path}（symlink → AGENTS.md）"
              ;;
            *)
              bad "$path 是指向别处的 symlink：$dest"
              ;;
          esac
        elif [ -f "$path" ]; then
          if grep -q '<!-- vibe-rules:begin' "$path" 2>/dev/null; then
            ok "${path}（复制文件，含引用块）"
          else
            bad "$path 是真实文件且不含 vibe-rules 引用块"
          fi
        else
          bad "$path 不存在"
        fi
        ;;
      dir)
        if [ ! -f "$path" ]; then
          bad "$path 不存在"
        elif grep -q 'vibe-rules' "$path" 2>/dev/null; then
          ok "$path"
        else
          bad "$path 存在但不是 vibe-rules 生成的文件"
        fi
        ;;
    esac
  done
fi

# ---------- 汇总 ----------
echo ""
echo "📊 结果：$PASS 通过，$FAIL 未通过"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "🔧 修复：重跑 install（幂等，不会覆盖你的 AGENTS.md 正文）"
  echo "   $VIBE_HOME/scripts/install.sh $PROJECT_ROOT"
  exit 1
fi

echo ""
echo "🎉 项目已正确接入 vibe-rules。"

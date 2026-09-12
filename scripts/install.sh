#!/usr/bin/env bash
# install.sh —— 在你的开发项目里接入 vibe-rules
#
# 用法：
#   /path/to/vibe-rules/scripts/install.sh [项目路径] [选项]
#
# 选项：
#   --all            安装所有 agent 入口（老用户批量接入用）
#   --agents 1,3,5   只安装指定编号（逗号或空格分隔）
#   --copy           用真实文件复制代替 symlink（云端 agent / 无 symlink 环境）
#   --yes            非交互模式（配合 --all / --agents / --copy）
#   -h, --help       显示帮助
#
# 幂等：可重复执行。已有 AGENTS.md 不会被覆盖，只在顶部注入/刷新
#       「vibe-rules 引用块」；规则库搬家后重跑即可自动更新路径。

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
CONF_FILE="$VIBE_HOME/scripts/agents.conf"

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
}

# ---------- 参数解析 ----------
PROJECT_ROOT=""
ALL_MODE=false
COPY_MODE=false
ASSUME_YES=false
SELECTION_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --all) ALL_MODE=true ;;
    --agents)
      shift
      if [ $# -eq 0 ]; then
        echo "❌ --agents 需要参数，例如：--agents 1,3,5"
        exit 1
      fi
      SELECTION_ARG="$1"
      ;;
    --agents=*) SELECTION_ARG="${1#--agents=}" ;;
    --copy) COPY_MODE=true ;;
    --yes|-y) ASSUME_YES=true ;;
    -h|--help) usage; exit 0 ;;
    --)
      shift
      if [ $# -gt 0 ]; then PROJECT_ROOT="$1"; fi
      break
      ;;
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

if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(pwd)"
fi

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "📁 目录不存在，自动创建：$PROJECT_ROOT"
  mkdir -p "$PROJECT_ROOT"
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
SLUG="$(basename "$PROJECT_ROOT")"

# ---------- 读取 agent 清单（单一数据源） ----------
if [ ! -f "$CONF_FILE" ]; then
  echo "❌ 缺少 agent 清单：$CONF_FILE"
  exit 1
fi

NUMS=()
NAMES=()
TYPES=()
PATHS=()
DOCS=()
while IFS='|' read -r num name type path doc; do
  case "$num" in
    ''|'#'*) continue ;;
  esac
  NUMS+=("$num")
  NAMES+=("$name")
  TYPES+=("$type")
  PATHS+=("$path")
  DOCS+=("$doc")
done < "$CONF_FILE"

if [ "${#NUMS[@]}" -eq 0 ]; then
  echo "❌ agent 清单是空的：$CONF_FILE"
  exit 1
fi

echo "📦 规则库：$VIBE_HOME"
echo "🎯 项目：$PROJECT_ROOT"
echo ""

# ---------- 交互选择 ----------
if [ "$ALL_MODE" = true ]; then
  SELECTION="all"
elif [ -n "$SELECTION_ARG" ]; then
  SELECTION="$SELECTION_ARG"
elif [ "$ASSUME_YES" = true ]; then
  SELECTION="all"
else
  echo "你用哪个 agent？输入编号（空格或逗号分隔多选），或输入 all 全选："
  echo ""
  i=0
  while [ $i -lt "${#NUMS[@]}" ]; do
    printf "  %2s. %-24s %s\n" "${NUMS[$i]}" "${NAMES[$i]}" "${DOCS[$i]}"
    i=$((i+1))
  done
  echo ""
  read -r -p "选择: " SELECTION
fi

# ---------- 解析选择 ----------
SELECTION="$(printf '%s' "$SELECTION" | tr ',' ' ')"
SELECTED=" "
if [ "$SELECTION" = "all" ] || [ "$SELECTION" = "ALL" ]; then
  i=0
  while [ $i -lt "${#NUMS[@]}" ]; do
    SELECTED="$SELECTED${NUMS[$i]} "
    i=$((i+1))
  done
else
  for token in $SELECTION; do
    found=false
    i=0
    while [ $i -lt "${#NUMS[@]}" ]; do
      if [ "$token" = "${NUMS[$i]}" ]; then
        found=true
        break
      fi
      i=$((i+1))
    done
    if [ "$found" != true ]; then
      echo "❌ 无效的 agent 编号：$token"
      echo "   可用编号：$(printf '%s ' "${NUMS[@]}")"
      exit 1
    fi
    SELECTED="$SELECTED$token "
  done
fi
if [ "$SELECTED" = " " ]; then
  echo "❌ 没有选择任何 agent"
  exit 1
fi

# ---------- 生成引用块 ----------
TMP_BLOCK="$(mktemp "${TMPDIR:-/tmp}/vibe-block.XXXXXX")"
TMP_WORK="$(mktemp "${TMPDIR:-/tmp}/vibe-work.XXXXXX")"
cleanup() {
  rm -f "${TMP_BLOCK:-}" "${TMP_WORK:-}"
}
trap cleanup EXIT

cat > "$TMP_BLOCK" <<EOF
<!-- vibe-rules:begin（本块由 vibe-rules 自动维护，勿手改；重跑 install.sh 即可刷新） -->
## 全局规则库（vibe-rules）

开始任何工作前，按下面的顺序读（路径是本机路径，不存在就跳过）：

1. **全局规则库入口**：\`$VIBE_HOME/README.md\` —— 六条铁律 + 索引
2. **个人偏好层**：\`$VIBE_HOME/personal/preferences.md\`
3. **个人记忆（最新 10 条）**：\`$VIBE_HOME/personal/memory.md\`
4. **全局踩坑库（最新 10 条）**：\`$VIBE_HOME/global/anti-patterns.md\`
5. **本项目专属沉淀**：\`$VIBE_HOME/projects/$SLUG/README.md\`（存在就读；没有可跑 new-project.sh 建档）
6. **技术栈规范**：\`$VIBE_HOME/languages/<tech>.md\`（按本项目实际栈读，不要全读）

> 规则优先级：项目内约定 > 个人偏好 > 全局规范。冲突时以更具体的一层为准，并在回复里指出冲突。
<!-- vibe-rules:end -->
EOF

cd "$PROJECT_ROOT"

# ---------- AGENTS.md ----------
AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"
if [ ! -f "$AGENTS_FILE" ]; then
  cp "$VIBE_HOME/templates/AGENTS.md" "$AGENTS_FILE"
  echo "📝 生成 AGENTS.md（来自模板）"
fi

# 兼容旧版模板：把残留的 ~/.vibe 硬编码换成当前实际路径
if grep -q '~/\.vibe' "$AGENTS_FILE" 2>/dev/null; then
  sed -i.bak "s|~/\.vibe|$VIBE_HOME|g" "$AGENTS_FILE"
  rm -f "$AGENTS_FILE.bak"
  echo "🧹 已刷新 AGENTS.md 里的旧版规则库路径"
fi

# 兼容旧版模板：删掉旧的「0. 必须先读」章节（职责已由顶部引用块接管）
if grep -q '^## 0\. 必须先读' "$AGENTS_FILE" 2>/dev/null; then
  awk '
    /^## 0\. 必须先读/ { skip=1; next }
    skip && /^---[[:space:]]*$/ { skip=0; next }
    !skip { print }
  ' "$AGENTS_FILE" > "$TMP_WORK"
  mv "$TMP_WORK" "$AGENTS_FILE"
  echo "🧹 已清理旧版模板的「必须先读」章节（由顶部引用块接管）"
fi

# 注入 / 刷新引用块（幂等）
if [ ! -s "$AGENTS_FILE" ]; then
  # 空文件：awk 对空输入不会进入任何规则分支，必须单独处理
  cat "$TMP_BLOCK" > "$AGENTS_FILE"
  echo "📝 已向空 AGENTS.md 写入规则库引用块"
elif grep -q '<!-- vibe-rules:begin' "$AGENTS_FILE" 2>/dev/null; then
  awk -v blockfile="$TMP_BLOCK" '
    index($0, "<!-- vibe-rules:begin") == 1 {
      while ((getline line < blockfile) > 0) print line
      close(blockfile)
      inblock=1
      next
    }
    inblock && index($0, "<!-- vibe-rules:end -->") == 1 { inblock=0; next }
    inblock { next }
    { print }
  ' "$AGENTS_FILE" > "$TMP_WORK"
  mv "$TMP_WORK" "$AGENTS_FILE"
  echo "🔄 AGENTS.md 引用块已刷新"
else
  awk -v blockfile="$TMP_BLOCK" '
    BEGIN { fm=0; done=0 }
    {
      if (done) { print; next }
      if (NR==1 && $0=="---") { fm=1; print; next }
      if (fm==1 && $0=="---") {
        fm=0; done=1
        print
        print ""
        while ((getline line < blockfile) > 0) print line
        close(blockfile)
        next
      }
      if (fm==1) { print; next }
      done=1
      while ((getline line < blockfile) > 0) print line
      close(blockfile)
      print ""
      print
    }
  ' "$AGENTS_FILE" > "$TMP_WORK"
  mv "$TMP_WORK" "$AGENTS_FILE"
  echo "📝 已向 AGENTS.md 注入规则库引用块"
fi

# ---------- 工具函数 ----------
link() {
  local target="$1" linkpath="$2" dir src current
  dir="$(dirname "$linkpath")"
  if [ "$dir" != "." ]; then
    mkdir -p "$dir"
  fi
  if [ -L "$linkpath" ]; then
    current="$(readlink "$linkpath")"
    if [ "$current" != "$target" ] && [ "$current" != "$PROJECT_ROOT/AGENTS.md" ]; then
      echo "  ⚠️  跳过 ${linkpath}（已是指向别处的 symlink：${current}）"
      return
    fi
  elif [ -e "$linkpath" ]; then
    echo "  ⚠️  跳过 ${linkpath}（已存在真实文件，不动它）"
    return
  fi
  rm -f "$linkpath"
  if [ "$COPY_MODE" = true ]; then
    if [ "$dir" = "." ]; then
      src="$target"
    else
      src="$dir/$target"
    fi
    cp "$src" "$linkpath"
    echo "  ✅ ${linkpath}（复制）"
  else
    ln -s "$target" "$linkpath"
    echo "  ✅ ${linkpath}"
  fi
}

write_wrapper() {
  local path="$1" note="$2" dir
  dir="$(dirname "$path")"
  if [ "$dir" != "." ]; then
    mkdir -p "$dir"
  fi
  if [ -e "$path" ] && [ ! -L "$path" ]; then
    if ! grep -q 'vibe-rules' "$path" 2>/dev/null; then
      echo "  ⚠️  跳过 ${path}（已存在且不是 vibe-rules 生成的文件）"
      return
    fi
  fi
  rm -f "$path"
  cat > "$path" <<EOF
---
description: $note
alwaysApply: true
---

<!-- vibe-rules:managed（本文件由 vibe-rules 自动生成，勿手改；重跑 install.sh 刷新） -->

# 项目入口

先读项目根目录 \`AGENTS.md\` 顶部的 vibe-rules 引用块，按其中顺序加载规则库。
不要凭记忆猜测项目约定，按规则库和 AGENTS.md 里写的来。
EOF
  echo "  ✅ ${path}"
}

# ---------- 创建入口文件 ----------
echo ""
echo "🔗 创建入口文件..."
i=0
while [ $i -lt "${#NUMS[@]}" ]; do
  num="${NUMS[$i]}"
  name="${NAMES[$i]}"
  type="${TYPES[$i]}"
  path="${PATHS[$i]}"
  i=$((i+1))

  case "$SELECTED" in
    *" $num "*) ;;
    *) continue ;;
  esac

  if [ "$type" = "native" ]; then
    echo "  ℹ️  ${name} 原生读 AGENTS.md，无需额外入口文件"
  elif [ "$type" = "single" ]; then
    case "$path" in
      .github/*) link "../AGENTS.md" "$path" ;;
      *) link "AGENTS.md" "$path" ;;
    esac
  elif [ "$type" = "dir" ]; then
    write_wrapper "$path" "${name} 项目入口规则"
  fi
done

# ---------- 证据文件 ----------
VIBE_VERSION="$(git -C "$VIBE_HOME" rev-parse --short HEAD 2>/dev/null || echo unknown)"
AGENTS_LIST="$(echo $SELECTED | tr ' ' ',')"
cat > "$PROJECT_ROOT/.vibe-rules" <<EOF
rules_home=$VIBE_HOME
rules_version=$VIBE_VERSION
installed_at=$(date +%Y-%m-%d)
project=$PROJECT_ROOT
agents=$AGENTS_LIST
EOF
echo "  ✅ .vibe-rules（证据文件，agents=${AGENTS_LIST}）"

echo ""
echo "🎉 完成。"
echo "   验证：$VIBE_HOME/scripts/verify.sh $PROJECT_ROOT"
echo ""
echo "   提示："
echo "   - .vibe-rules 记录的是本机绝对路径，建议加入项目 .gitignore（不要提交）"
echo "   - AGENTS.md 里的引用块是自动生成的；团队/云端环境每人跑一次 install 即可"
echo "   - 规则库搬家后，重跑本脚本会自动刷新路径"

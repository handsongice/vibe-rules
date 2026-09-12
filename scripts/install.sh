#!/usr/bin/env bash
# install.sh —— 在你的开发项目里接入 vibe-rules
#
# 用法：
#   /path/to/vibe-rules/scripts/install.sh [项目路径] [选项]
#
# 选项：
#   --all            安装所有 agent 入口（老用户批量接入用）
#   --agents 1,3,5   只安装指定编号（逗号或空格分隔）
#   --link           外链模式：项目里只放入口 + 引用块，规则本体留在本机规则库
#                    （合规敏感、规则不便进仓库时用；默认是自包含副本模式）
#   --no-personal    副本里不含 personal/（个人偏好与记忆不进项目仓库）
#   --copy           入口用真实文件复制代替 symlink（云端 agent / 无 symlink 环境）
#   --yes            非交互模式（配合 --all / --agents）
#   -h, --help       显示帮助
#
# 默认行为（自包含副本模式）：把规则副本复制进项目的 .vibe-rules/，
# AGENTS.md 引用块用相对路径指向副本。队友 clone、云端 agent、CI 都能直接读到，
# 不依赖任何人的本机路径。项目专属笔记写在 .vibe-rules/project/README.md，
# 只在不存在时建档，之后永不覆盖。
#
# 幂等：可重复执行。已有 AGENTS.md 不会被覆盖，只在顶部注入/刷新
#       「vibe-rules 引用块」；重跑即刷新副本，也可用 scripts/update.sh。

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
CONF_FILE="$VIBE_HOME/scripts/agents.conf"

usage() {
  sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
}

# ---------- 参数解析 ----------
PROJECT_ROOT=""
ALL_MODE=false
COPY_MODE=false
ASSUME_YES=false
LINK_MODE=false
WITH_PERSONAL=true
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
    --link) LINK_MODE=true ;;
    --no-personal) WITH_PERSONAL=false ;;
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

VIBE_VERSION="$(git -C "$VIBE_HOME" rev-parse --short HEAD 2>/dev/null || echo unknown)"
INSTALLED_AT="$(date +%Y-%m-%d)"

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

# ---------- 模式与本体 ----------
if [ "$LINK_MODE" = true ]; then
  MODE="link"
else
  MODE="embedded"
fi

RULES_DIR="$PROJECT_ROOT/.vibe-rules"
PERSONAL_NOTE="（有就读）"

if [ "$MODE" = "embedded" ]; then
  echo "📦 模式：自包含副本（规则复制进 ${RULES_DIR}，引用块用相对路径）"
else
  echo "📦 模式：外链（规则留在本机，引用块指向 ${VIBE_HOME}）"
fi

if [ "$MODE" = "embedded" ]; then
  if [ "$VIBE_HOME" = "$PROJECT_ROOT" ]; then
    echo "❌ 项目路径不能是规则库本身（会把副本复制进自己）"
    exit 1
  fi
  if ! command -v rsync >/dev/null 2>&1; then
    echo "❌ 自包含副本模式需要 rsync（macOS/Linux 自带；Windows 请用 install.ps1，或加 --link）"
    exit 1
  fi

  echo "📄 复制规则副本 → $RULES_DIR"
  mkdir -p "$RULES_DIR"
  # project/ 是项目专属笔记，必须排除在 --delete 之外（否则更新会把笔记删掉）
  RSYNC_ARGS=(-a --delete --exclude=.git --exclude=.github --exclude=.gitignore
              --exclude=scripts --exclude=tests --exclude=templates
              --exclude=projects --exclude=project --exclude=inbox)
  if [ "$WITH_PERSONAL" = true ]; then
    rsync "${RSYNC_ARGS[@]}" "$VIBE_HOME/" "$RULES_DIR/"
  else
    # --delete-excluded：上一次安装带进去的 personal/ 也要一并清掉
    rsync "${RSYNC_ARGS[@]}" --exclude=personal --delete-excluded "$VIBE_HOME/" "$RULES_DIR/"
    PERSONAL_NOTE="（副本里未包含，跳过）"
  fi
  echo "   ✅ 规则本体（global / languages / skills）"

  # 入口指南：覆盖上游 README，写清副本内的阅读顺序和维护方式
  sed -e "s|@VIBE_VERSION@|${VIBE_VERSION}|g" -e "s|@INSTALLED_AT@|${INSTALLED_AT}|g" \
      "$VIBE_HOME/templates/ENTRY.md" > "$RULES_DIR/README.md"
  echo "   ✅ README.md（副本入口指南）"

  # 项目专属笔记：只在不存在时建档，之后永不覆盖
  if [ ! -f "$RULES_DIR/project/README.md" ]; then
    mkdir -p "$RULES_DIR/project"
    sed -e "s|@SLUG@|${SLUG}|g" "$VIBE_HOME/templates/PROJECT-NOTES.md" \
        > "$RULES_DIR/project/README.md"
    echo "   ✅ project/README.md（项目专属笔记，之后不会被覆盖）"
  else
    echo "   ℹ️  project/README.md 已存在，保留不动"
  fi
else
  # 外链模式：项目笔记留在规则库 projects/<slug>/（多项目互不覆盖）
  LINK_NOTES_DIR="$VIBE_HOME/projects/$SLUG"
  if [ ! -f "$LINK_NOTES_DIR/README.md" ]; then
    mkdir -p "$LINK_NOTES_DIR"
    sed -e "s|@SLUG@|${SLUG}|g" "$VIBE_HOME/templates/PROJECT-NOTES.md" \
        > "$LINK_NOTES_DIR/README.md"
    echo "📝 规则库里建了项目专属笔记：$LINK_NOTES_DIR/README.md"
  fi
fi

# ---------- 生成引用块 ----------
TMP_BLOCK="$(mktemp "${TMPDIR:-/tmp}/vibe-block.XXXXXX")"
TMP_WORK="$(mktemp "${TMPDIR:-/tmp}/vibe-work.XXXXXX")"
cleanup() {
  rm -f "${TMP_BLOCK:-}" "${TMP_WORK:-}"
}
trap cleanup EXIT

# embedded 模式用相对路径（换机器/换目录都有效）；link 模式只能绝对路径
if [ "$MODE" = "embedded" ]; then
  RULES_REF=".vibe-rules"
  NOTES_REF="$RULES_REF/project/README.md"
else
  RULES_REF="$VIBE_HOME"
  NOTES_REF="$VIBE_HOME/projects/$SLUG/README.md"
fi

if [ "$MODE" = "embedded" ]; then
  BLOCK_INTRO="开始任何工作前，按下面的顺序读（**自包含副本**，路径相对项目根，不需要访问项目外的任何文件）："
else
  BLOCK_INTRO="开始任何工作前，按下面的顺序读（**外链模式**，路径是本机规则库的绝对路径，不存在就跳过）："
fi

cat > "$TMP_BLOCK" <<EOF
<!-- vibe-rules:begin（本块由 vibe-rules 自动维护，勿手改；重跑 install.sh / update.sh 即可刷新） -->
## 全局规则库（vibe-rules）

$BLOCK_INTRO

1. **规则库入口**：\`$RULES_REF/README.md\` —— 六条铁律 + 索引
2. **全局踩坑库（最新 10 条）**：\`$RULES_REF/global/anti-patterns.md\`
3. **个人偏好与记忆**：\`$RULES_REF/personal/preferences.md\`、\`$RULES_REF/personal/memory.md\`$PERSONAL_NOTE
4. **本项目专属沉淀**：\`$NOTES_REF\` —— 最具体，冲突时优先
5. **技术栈规范**：\`$RULES_REF/languages/<tech>.md\`（按本项目实际栈读，不要全读）
6. **可复用工作流**：\`$RULES_REF/skills/README.md\`，再按当前任务挑一个 \`$RULES_REF/skills/<name>/SKILL.md\`

> 规则优先级：项目内约定（AGENTS.md + project/README.md）> 个人偏好 > 全局规范。冲突时以更具体的一层为准，并在回复里指出冲突。
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
  if [ "$MODE" = "embedded" ]; then
    sed -i.bak "s|~/\.vibe|.vibe-rules/|g" "$AGENTS_FILE"
  else
    sed -i.bak "s|~/\.vibe|$VIBE_HOME|g" "$AGENTS_FILE"
  fi
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
AGENTS_LIST="$(echo $SELECTED | tr ' ' ',')"
if [ "$MODE" = "embedded" ]; then
  EVIDENCE_FILE="$RULES_DIR/installed"
  EVIDENCE_LABEL=".vibe-rules/installed"
else
  EVIDENCE_FILE="$PROJECT_ROOT/.vibe-rules"
  EVIDENCE_LABEL=".vibe-rules"
fi
cat > "$EVIDENCE_FILE" <<EOF
mode=$MODE
rules_home=$VIBE_HOME
rules_version=$VIBE_VERSION
installed_at=$INSTALLED_AT
project=$PROJECT_ROOT
agents=$AGENTS_LIST
EOF
echo "  ✅ ${EVIDENCE_LABEL}（mode=${MODE}，agents=${AGENTS_LIST}）"

echo ""
echo "🎉 完成。"
echo "   验证：$VIBE_HOME/scripts/verify.sh $PROJECT_ROOT"
echo ""
if [ "$MODE" = "embedded" ]; then
  echo "   提示："
  echo "   - 规则副本已进项目：.vibe-rules/（整目录提交进仓库，团队/云端/CI 都能直接读到，不依赖任何人的本机路径）"
  echo "   - 项目专属笔记在 .vibe-rules/project/README.md，也建议提交；重装/更新都不会覆盖它"
  if [ "$WITH_PERSONAL" = true ]; then
    echo "   - 副本里含 personal/（个人偏好与记忆）。不想带进仓库：用 --no-personal 装，或把 .vibe-rules/personal/ 加进 .gitignore"
  fi
  echo "   - 规则库以后改了：$VIBE_HOME/scripts/update.sh $PROJECT_ROOT"
else
  echo "   提示："
  echo "   - 外链模式：规则本体留在本机，${VIBE_HOME} 搬家后重跑 install/update 即可刷新"
  echo "   - .vibe-rules 里记录的是本机路径，建议加进项目 .gitignore（不要提交）"
fi

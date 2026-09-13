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
#   --profile team     团队档：强制自包含副本 + 不含 personal/，并要求副本真的能进仓库
#   --profile hybrid   混合档：副本进仓库，但 personal/ 不进仓库、只在本机外链
#   --profile personal 个人档：强制外链模式（规则不落进仓库），个人层照常带上
#   --copy           入口用真实文件复制代替 symlink（云端 agent / 无 symlink 环境）
#   --with-ci        同一条命令生成 .github/workflows/vibe-rules-verify.yml
#                    （PR 上校验副本漂移 + 接入完整性；只对副本模式有意义）
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
  # 打印文件开头的注释块（不用写死行号，以后加选项不会漏）
  awk 'NR > 1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
}

# ---------- 参数解析 ----------
PROJECT_ROOT=""
ALL_MODE=false
COPY_MODE=false
ASSUME_YES=false
LINK_MODE=false
WITH_PERSONAL=true
PROFILE="default"
PERSONAL_REF=""                 # 空 = 个人层跟着规则本体；hybrid 档指向本机规则库
SELECTION_ARG=""
WITH_CI=false

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
    --profile)
      shift
      if [ $# -eq 0 ]; then
        echo "❌ --profile 需要参数：team 或 personal"
        exit 1
      fi
      PROFILE="$1"
      ;;
    --profile=*) PROFILE="${1#--profile=}" ;;
    --copy) COPY_MODE=true ;;
    --with-ci) WITH_CI=true ;;
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

# ---------- 策略档位（本地/团队策略在脚本层收口，不靠人记） ----------
case "$PROFILE" in
  default) ;;
  team)
    if [ "$LINK_MODE" = true ]; then
      echo "❌ --profile team 与 --link 矛盾：团队档要求规则副本进仓库，外链模式做不到"
      exit 1
    fi
    WITH_PERSONAL=false
    ;;
  hybrid)
    if [ "$LINK_MODE" = true ]; then
      echo "❌ --profile hybrid 与 --link 矛盾：混合档要求规则副本进仓库（只有 personal/ 走外链）"
      exit 1
    fi
    if [ "$WITH_PERSONAL" = false ]; then
      echo "❌ --profile hybrid 与 --no-personal 矛盾：混合档就是要把个人层接上（本机外链）"
      exit 1
    fi
    # 副本里不含 personal/，改用本机规则库的 personal/（绝对路径）
    WITH_PERSONAL=false
    PERSONAL_REF="$VIBE_HOME/personal"
    ;;
  personal)
    if [ "$WITH_PERSONAL" = false ]; then
      echo "❌ --profile personal 与 --no-personal 矛盾：个人档就是要把个人层带上"
      exit 1
    fi
    LINK_MODE=true
    ;;
  *)
    echo "❌ --profile 只支持 team / hybrid / personal，收到：$PROFILE"
    exit 1
    ;;
esac

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
# CI 校验用：规则库远端地址 + 这次安装钉住的 commit（--with-ci 写进 workflow）
RULES_REPO="$(git -C "$VIBE_HOME" remote get-url origin 2>/dev/null || true)"
[ -n "$RULES_REPO" ] || RULES_REPO="https://github.com/handsongice/vibe-rules.git"
case "$RULES_REPO" in
  git@github.com:*) RULES_REPO="https://github.com/${RULES_REPO#git@github.com:}" ;;
esac
RULES_SHA="$(git -C "$VIBE_HOME" rev-parse HEAD 2>/dev/null || true)"
[ -n "$RULES_SHA" ] || RULES_SHA="main"
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

case "$PROFILE" in
  team)     echo "🧭 策略档位：team（团队共享：副本进仓库 + 不含 personal/）" ;;
  hybrid)   echo "🧭 策略档位：hybrid（副本进仓库；personal/ 不进仓库，只在本机外链）" ;;
  personal) echo "🧭 策略档位：personal（个人自用：外链模式，规则不进仓库）" ;;
  *)        echo "🧭 策略档位：default（未指定，按上面选的模式走）" ;;
esac

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

  # 旧版把证据文件写成项目根的 .vibe-rules（普通文件），会挡住副本目录：识别并升级掉
  if [ -e "$RULES_DIR" ] && [ ! -d "$RULES_DIR" ]; then
    if grep -q '^rules_home=' "$RULES_DIR" 2>/dev/null; then
      echo "🧹 检测到旧版证据文件 .vibe-rules（外链时代遗留），升级为副本目录"
      rm -f "$RULES_DIR"
    else
      echo "❌ ${RULES_DIR} 已存在且不是 vibe-rules 生成的证据文件，请先手动处理后重试"
      exit 1
    fi
  fi

  echo "📄 复制规则副本 → $RULES_DIR"
  mkdir -p "$RULES_DIR"
  # project/ 是项目专属笔记，必须排除在 --delete 之外（否则更新会把笔记删掉）
  # 排除清单：工具与打包清单不跟着项目走（项目只需要规则本体）
  # 注意：不要用 --delete-excluded —— 它会连 .vibe-rules/project/ 项目笔记一起删掉。
  # 这里用普通 --delete（只删源里没有的），旧版装进来的残留单独精确清理。
  RSYNC_ARGS=(-a --delete
              --exclude=/.git --exclude=/.github --exclude=/.gitignore --exclude=/.gitattributes
              --exclude=/scripts --exclude=/tests --exclude=/templates
              --exclude=/projects --exclude=/project --exclude=/inbox
              --exclude=/.agents --exclude=/.claude-plugin --exclude=/.codex-plugin
              --exclude=/VERSION --exclude=/CHANGELOG.md
              --exclude=/.pre-commit-config.yaml --exclude=/RELEASE-NOTES.md
              --exclude=/ModuleAnalysisCache* --exclude=/StartupProfileData*)
  # 旧版曾把打包产物复制进副本：精确清掉，避免遗留（project/ 绝不在此列）
  for stale in .agents .claude-plugin .codex-plugin; do
    if [ -e "$RULES_DIR/$stale" ] && [ "$RULES_DIR" != "/" ] && [ "$RULES_DIR" != "$HOME" ]; then
      rm -rf -- "$RULES_DIR/$stale"
    fi
  done
  for stale in VERSION CHANGELOG.md .gitattributes .pre-commit-config.yaml RELEASE-NOTES.md; do
    rm -f -- "$RULES_DIR/$stale"
  done
  # pwsh 在只读 HOME 环境会把运行时缓存落到工作目录；旧版可能被复制进副本，一并清掉
  for stale in "$RULES_DIR"/ModuleAnalysisCache* "$RULES_DIR"/StartupProfileData*; do
    if [ -f "$stale" ]; then
      rm -f -- "$stale"
    fi
  done

  # rsync 无条件跑：--no-personal 只是多一条排除 + 清掉上一轮遗留的 personal/
  if [ "$WITH_PERSONAL" = false ]; then
    RSYNC_ARGS+=(--exclude=/personal)
  fi
  rsync "${RSYNC_ARGS[@]}" "$VIBE_HOME/" "$RULES_DIR/"
  if [ "$WITH_PERSONAL" = false ]; then
    rm -rf -- "$RULES_DIR/personal"
    if [ -n "$PERSONAL_REF" ]; then
      PERSONAL_NOTE="（**本机外链**，不进仓库、换机器读不到）"
    else
      PERSONAL_NOTE="（副本里未包含，跳过）"
    fi
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

  # 项目文档约定（规格驱动）：设计文档 docs/specs/、实现计划 docs/plans/
  # 同样只在不存在时建档，永不覆盖用户已有的内容
  mkdir -p "$PROJECT_ROOT/docs/specs" "$PROJECT_ROOT/docs/plans"
  if [ ! -f "$PROJECT_ROOT/docs/specs/README.md" ]; then
    sed -e "s|@SLUG@|${SLUG}|g" "$VIBE_HOME/templates/DOCS-SPECS.md" \
        > "$PROJECT_ROOT/docs/specs/README.md"
    echo "   ✅ docs/specs/README.md（设计文档约定）"
  fi
  if [ ! -f "$PROJECT_ROOT/docs/plans/README.md" ]; then
    sed -e "s|@SLUG@|${SLUG}|g" "$VIBE_HOME/templates/DOCS-PLANS.md" \
        > "$PROJECT_ROOT/docs/plans/README.md"
    echo "   ✅ docs/plans/README.md（实现计划约定）"
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

# ---------- GitHub Action（可选）：PR 上校验副本漂移 + 接入完整性 ----------
if [ "$WITH_CI" = true ]; then
  if [ "$MODE" != "embedded" ]; then
    echo "⏭️  --with-ci 跳过：外链模式的规则库在本机，CI 里读不到（要 CI 校验请用副本模式）"
  else
    CI_FILE="$PROJECT_ROOT/.github/workflows/vibe-rules-verify.yml"
    if [ -f "$CI_FILE" ] && ! grep -q 'vibe-rules install --with-ci 生成' "$CI_FILE" 2>/dev/null; then
      echo "   ℹ️  .github/workflows/vibe-rules-verify.yml 已存在且不是 vibe-rules 生成的，保留不动"
      echo "       （想换成模板：手动复制 ${VIBE_HOME}/templates/CI-VERIFY.yml）"
    else
      if [ "$RULES_SHA" != "main" ] && ! git -C "$VIBE_HOME" branch -r --contains HEAD 2>/dev/null | grep -q .; then
        echo "   ⚠️  本机规则库的 HEAD 还没推到远端：CI 里可能拉不到这个 commit（先 push，或改 workflow 里的 VIBE_RULES_SHA）"
      fi
      mkdir -p "$PROJECT_ROOT/.github/workflows"
      sed -e "s|@VIBE_REPO@|${RULES_REPO}|g" -e "s|@VIBE_SHA@|${RULES_SHA}|g" \
          "$VIBE_HOME/templates/CI-VERIFY.yml" > "$CI_FILE"
      echo "   ✅ .github/workflows/vibe-rules-verify.yml（PR 上校验副本漂移 + 接入完整性）"
    fi
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
# hybrid 档：个人层走本机绝对路径；其余情况个人层跟着规则本体
# 注意顺序：判断「是不是混合档」必须在默认填充之前——填过之后 PERSONAL_REF 恒非空，
# 默认安装的引用块就会谎称自己是「混合档」（ps1 侧顺序本来就是对的，这次补齐对齐）。
if [ "$MODE" = "embedded" ] && [ -n "$PERSONAL_REF" ]; then
  BLOCK_INTRO="开始任何工作前，按下面的顺序读（**混合档**：规则副本在项目内、路径相对项目根；第 3 条个人层在本机绝对路径，不存在就跳过）："
elif [ "$MODE" = "embedded" ]; then
  BLOCK_INTRO="开始任何工作前，按下面的顺序读（**自包含副本**，路径相对项目根，不需要访问项目外的任何文件）："
else
  BLOCK_INTRO="开始任何工作前，按下面的顺序读（**外链模式**，路径是本机规则库的绝对路径，不存在就跳过）："
fi
if [ -z "$PERSONAL_REF" ]; then
  PERSONAL_REF="$RULES_REF/personal"
fi

cat > "$TMP_BLOCK" <<EOF
<!-- vibe-rules:begin（本块由 vibe-rules 自动维护，勿手改；重跑 install.sh / update.sh 即可刷新） -->
## 全局规则库（vibe-rules）

$BLOCK_INTRO

1. **规则库入口**：\`$RULES_REF/README.md\` —— 六条铁律 + 索引
2. **全局踩坑库（最新 10 条）**：\`$RULES_REF/global/anti-patterns.md\`
3. **个人偏好与记忆**：\`$PERSONAL_REF/preferences.md\`、\`$PERSONAL_REF/memory.md\`$PERSONAL_NOTE
4. **本项目专属沉淀**：\`$NOTES_REF\` —— 最具体，冲突时优先
5. **技术栈规范**：\`$RULES_REF/languages/<tech>.md\`（按本项目实际栈读，不要全读）
6. **可复用工作流**：\`$RULES_REF/skills/README.md\`，再按当前任务挑一个 \`$RULES_REF/skills/<name>/SKILL.md\`
7. **本项目文档约定**：设计文档 → \`docs/specs/YYYY-MM-DD-<topic>.md\`，实现计划 → \`docs/plans/YYYY-MM-DD-<feature>.md\`；每份文档开头写 \`> status: draft|active|done|abandoned · updated: YYYY-MM-DD\`（\`done\` 的不用重读全文；汇总见规则库 scripts/docs-status.sh）

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
profile=$PROFILE
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

# ---------- 档位自查：team 必须真的能进仓库，personal 不该被提交 ----------
IGNORES_VIBE=false
if [ -f "$PROJECT_ROOT/.gitignore" ] && \
   grep -qE '^[[:space:]]*/?\.vibe-rules/?[[:space:]]*$' "$PROJECT_ROOT/.gitignore"; then
  IGNORES_VIBE=true
fi
PROFILE_LABEL=""
if [ "$PROFILE" = "team" ]; then
  PROFILE_LABEL="团队档"
elif [ "$PROFILE" = "hybrid" ]; then
  PROFILE_LABEL="混合档"
fi
if [ -n "$PROFILE_LABEL" ] && [ "$IGNORES_VIBE" = true ]; then
  echo "⚠️  ${PROFILE_LABEL}提醒：本项目 .gitignore 忽略了 .vibe-rules/，副本不会进仓库，"
  echo "   队友 / 云端 agent / CI 都读不到——这正是这个档位要拦住的情况。"
  echo "   修：把该条从 .gitignore 删掉（或加一行 !.vibe-rules/ 例外）；"
  echo "   如果你就是不想让规则进仓库，改用 --profile personal 重装。"
  echo ""
fi
if [ "$PROFILE" = "personal" ] && [ "$IGNORES_VIBE" = false ]; then
  echo "⚠️  个人档提醒：建议把 .vibe-rules 加进项目 .gitignore——"
  echo "   外链模式的证据文件里记的是本机规则库绝对路径，提交上去对别人没用。"
  echo ""
fi
if [ "$MODE" = "embedded" ]; then
  echo "   提示："
  echo "   - 规则副本已进项目：.vibe-rules/（整目录提交进仓库，团队/云端/CI 都能直接读到，不依赖任何人的本机路径）"
  echo "   - 项目专属笔记在 .vibe-rules/project/README.md，也建议提交；重装/更新都不会覆盖它"
  if [ "$WITH_PERSONAL" = true ]; then
    echo "   - 副本里含 personal/（个人偏好与记忆）。不想带进仓库：用 --no-personal 装，或把 .vibe-rules/personal/ 加进 .gitignore"
  elif [ -n "$PERSONAL_REF" ] && [ "$PERSONAL_REF" != "$RULES_REF/personal" ]; then
    echo "   - 个人层走本机外链：$PERSONAL_REF/（不会进仓库；换机器想继续用，记得在那边也放一份）"
  fi
  echo "   - 规则库以后改了：$VIBE_HOME/scripts/update.sh $PROJECT_ROOT"
else
  echo "   提示："
  echo "   - 外链模式：规则本体留在本机，${VIBE_HOME} 搬家后重跑 install/update 即可刷新"
  echo "   - .vibe-rules 里记录的是本机路径，建议加进项目 .gitignore（不要提交）"
fi

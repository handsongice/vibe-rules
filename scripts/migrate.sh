#!/usr/bin/env bash
# migrate.sh —— 把源项目的沉淀内容迁移到目标项目
#
# 用法：
#   /path/to/vibe-rules/scripts/migrate.sh <源项目slug> <目标项目slug>
#
# 例：把 old-app 的沉淀迁移到 new-app
#   ./scripts/migrate.sh old-app new-app
#
# 处理方式：
#   - 目标不存在的文件：直接复制
#   - 目标已存在的文件：diff 后让你选（覆盖/跳过/查看差异）

set -euo pipefail

VIBE_HOME="$(cd "$(dirname "$0")/.." && pwd)"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

if [ $# -lt 2 ]; then
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

SRC_SLUG="$1"
DST_SLUG="$2"

SRC_DIR="$VIBE_HOME/projects/$SRC_SLUG"
DST_DIR="$VIBE_HOME/projects/$DST_SLUG"

# 检查源项目
if [ ! -d "$SRC_DIR" ]; then
  echo "❌ 源项目不存在：$SRC_SLUG"
  echo "   可用项目："
  ls "$VIBE_HOME/projects/" 2>/dev/null | sed 's/^/     /'
  exit 1
fi

# 目标项目目录不存在就创建
mkdir -p "$DST_DIR"

echo "📤 源项目：$SRC_DIR"
echo "📥 目标项目：$DST_DIR"
echo ""

# 遍历源项目下所有文件
copied=0
skipped=0
overwritten=0

while IFS= read -r -d '' file; do
  rel="${file#$SRC_DIR/}"
  dst_file="$DST_DIR/$rel"
  dst_parent="$(dirname "$dst_file")"
  mkdir -p "$dst_parent"

  if [ ! -e "$dst_file" ]; then
    # 目标不存在，直接复制
    cp "$file" "$dst_file"
    echo "  ✅ 新增: $rel"
    copied=$((copied+1))
  else
    # 目标已存在，diff 一下
    if diff -q "$file" "$dst_file" > /dev/null 2>&1; then
      echo "  ⏭️  相同: ${rel}（跳过）"
      skipped=$((skipped+1))
    else
      echo "  ⚠️  冲突: $rel"
      echo "     源文件和目标都存在但内容不同"
      echo "     [o]verwrite 覆盖  [s]kip 跳过  [d]iff 查看差异"
      read -r -p "     选择 [o/s/d]: " choice
      case "$choice" in
        o|O)
          cp "$file" "$dst_file"
          echo "     ✅ 已覆盖"
          overwritten=$((overwritten+1))
          ;;
        d|D)
          echo "     --- diff（< 源  > 目标）---"
          diff "$file" "$dst_file" | head -30 || true
          echo "     ---"
          read -r -p "     覆盖吗？[y/N]: " confirm
          if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            cp "$file" "$dst_file"
            echo "     ✅ 已覆盖"
            overwritten=$((overwritten+1))
          else
            echo "     ⏭️  已跳过"
            skipped=$((skipped+1))
          fi
          ;;
        *)
          echo "     ⏭️  已跳过"
          skipped=$((skipped+1))
          ;;
      esac
    fi
  fi
done < <(find "$SRC_DIR" -type f -print0)

echo ""
echo "🎉 迁移完成。"
echo "   新增: $copied  覆盖: $overwritten  跳过: $skipped"
echo ""
echo "📝 提醒："
echo "   - 项目专属 README.md 里的项目名可能要手动改"
echo "   - 如果源项目有特殊技术栈配置，记得检查"
echo "   - 跑 install.sh 让新项目接入规则库："
echo "     $VIBE_HOME/scripts/install.sh /path/to/$DST_SLUG"

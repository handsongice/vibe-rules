#!/usr/bin/env bash
# bump-version.sh —— 发版：同步 VERSION 到各插件清单，并在 CHANGELOG 插入新版本段
#
# 用法：
#   scripts/bump-version.sh 1.1.0            # 更新 VERSION + 插件清单 + CHANGELOG 骨架
#   scripts/bump-version.sh 1.1.0 --no-changelog
#
# 涉及的文件：
#   VERSION、.claude-plugin/plugin.json、.codex-plugin/plugin.json
#   （插件清单里版本行带 "vibe-rules-version-marker" 标记，方便以后加平台不用改脚本）

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

NEW=""
NO_CHANGELOG=0
for arg in "$@"; do
  case "$arg" in
    --no-changelog) NO_CHANGELOG=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "❌ 未知参数：$arg" >&2; exit 2 ;;
    *) NEW="$arg" ;;
  esac
done

if [ -z "$NEW" ]; then
  echo "用法：scripts/bump-version.sh <新版本号> [--no-changelog]" >&2
  exit 2
fi
case "$NEW" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "❌ 不是 semver：${NEW}（应为 1.2.3 形式）" >&2; exit 2 ;;
esac

OLD="$(cat VERSION | tr -d '[:space:]')"
if [ "$OLD" = "$NEW" ]; then
  echo "ℹ️  版本没变（仍是 ${OLD}），只做同步检查"
fi

echo "$NEW" > VERSION

# 用 python3 改 JSON（sed 改 JSON 在换行/转义上太容易踩坑），改完校验 JSON 仍合法
python3 - "$NEW" <<'PY'
import json, pathlib, sys

new = sys.argv[1]
for f in (".claude-plugin/plugin.json", ".codex-plugin/plugin.json"):
    p = pathlib.Path(f)
    data = json.loads(p.read_text(encoding="utf-8"))
    data["version"] = new
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    json.loads(p.read_text(encoding="utf-8"))
    print(f"✅ 已更新 {f} → {new}")
PY

if [ "$NO_CHANGELOG" -eq 0 ] && [ -f CHANGELOG.md ] && [ "$OLD" != "$NEW" ]; then
  TODAY="$(date +%Y-%m-%d)"
  TMP="$(mktemp "${TMPDIR:-/tmp}/vibe-changelog.XXXXXX")"
  awk -v ver="$NEW" -v day="$TODAY" '
    !done && /^## \[Unreleased\]/ {
      print
      print ""
      print "## [" ver "] - " day
      print ""
      print "### 变更"
      print ""
      print "- TODO：写清楚这一版改了什么（谁在用、要做什么、有什么破坏性变更）"
      done = 1
      next
    }
    { print }
  ' CHANGELOG.md > "$TMP"
  mv "$TMP" CHANGELOG.md
  echo "✅ CHANGELOG.md 已插入 [$NEW] 段，记得补内容"
fi

echo ""
bash scripts/sync-plugin-skills.sh
bash scripts/validate-package.sh | tail -3

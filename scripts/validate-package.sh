#!/usr/bin/env bash
# validate-package.sh —— 校验 skill 结构与插件打包是否完整
#
# 用法：scripts/validate-package.sh
#
# 检查项：
#   1. 每个 skills/<name>/ 都有 SKILL.md 与 agents/openai.yaml
#   2. SKILL.md frontmatter 有且仅有 name / description（+ 可选 metadata）
#   3. frontmatter 的 name 与目录名一致；description 非空
#   4. agents/openai.yaml 的 display_name / short_description / default_prompt 齐全，
#      且 default_prompt 里带 $<skill-name>（否则 UI 调用会失灵）
#   5. 插件清单 JSON 合法、name 一致、skills 列表与 skills/ 实况一致
#   6. 根目录 VERSION 与两处插件清单版本一致
#
# 不依赖 jq / yq，只用 bash + python3（脚本库其它地方本来就用 python3）。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

echo "🔍 校验 skill 结构"

SKILL_LIST=""
for d in skills/*/; do
  [ -d "$d" ] || continue
  NAME="$(basename "$d")"
  FILE="$d/SKILL.md"

  if [ ! -f "$FILE" ]; then
    bad "$NAME 缺少 SKILL.md"
    continue
  fi
  ok "$NAME 有 SKILL.md"

  FM="$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1 {print}' "$FILE")"
  if [ -z "$FM" ]; then
    bad "$NAME frontmatter 缺失（文件必须从 --- 开头）"
  else
    FM_NAME="$(printf '%s\n' "$FM" | sed -n 's/^name: *//p' | head -n 1)"
    FM_DESC="$(printf '%s\n' "$FM" | sed -n 's/^description: *//p' | head -n 1)"
    FM_KEYS="$(printf '%s\n' "$FM" | sed -n 's/^\([a-zA-Z_][a-zA-Z0-9_-]*\):.*/\1/p' | sort -u | tr '\n' ' ')"
    [ "$FM_NAME" = "$NAME" ] && ok "$NAME frontmatter name 与目录一致" \
      || bad "$NAME frontmatter name=「${FM_NAME}」与目录名不一致"
    [ -n "$FM_DESC" ] && ok "$NAME description 非空" \
      || bad "$NAME description 为空"
    case "$FM_KEYS" in
      "description metadata name "|"description name ") ok "$NAME frontmatter 字段精简（${FM_KEYS}）" ;;
      *) bad "$NAME frontmatter 有非标准字段：${FM_KEYS}（只允许 name/description/metadata）" ;;
    esac
  fi

  YAML="$d/agents/openai.yaml"
  if [ ! -f "$YAML" ]; then
    bad "$NAME 缺少 agents/openai.yaml"
    continue
  fi
  ok "$NAME 有 agents/openai.yaml"
  if grep -q '^  display_name: "[^"]' "$YAML"; then ok "$NAME display_name 已填"; else bad "$NAME display_name 缺失"; fi
  if grep -q '^  short_description: "[^"]' "$YAML"; then ok "$NAME short_description 已填"; else bad "$NAME short_description 缺失"; fi
  if grep -q 'default_prompt: ".*\$'"$NAME"' ' "$YAML"; then ok "$NAME default_prompt 带 \$$NAME"; else bad "$NAME default_prompt 缺失或没写 \$$NAME"; fi

  SKILL_LIST="$SKILL_LIST ./skills/$NAME"
done

echo ""
echo "🔍 校验插件清单"

if bash scripts/sync-plugin-skills.sh --check >/dev/null 2>&1; then
  ok "插件 skills 列表与 skills/ 实况一致"
else
  bad "插件 skills 列表与 skills/ 实况不一致（跑 bash scripts/sync-plugin-skills.sh）"
fi

PY_COUNT="$(mktemp "${TMPDIR:-/tmp}/vibe-rules-validate.XXXXXX")"
trap 'rm -f "$PY_COUNT"' EXIT
python3 - "$PY_COUNT" <<'PY'
import json, pathlib, re, sys

root = pathlib.Path(".")
ok, bad = [], []
def good(m): ok.append(m)
def blow(m): bad.append(m)

manifests = [root / ".claude-plugin/plugin.json", root / ".codex-plugin/plugin.json",
             root / ".agents/plugins/marketplace.json", root / ".claude-plugin/marketplace.json"]

version = (root / "VERSION").read_text(encoding="utf-8").strip()
if re.fullmatch(r"\d+\.\d+\.\d+", version):
    good(f"VERSION 格式合法：{version}")
else:
    blow(f"VERSION 不是 semver：{version!r}")

for p in manifests:
    if not p.is_file():
        blow(f"{p} 不存在")
        continue
    try:
        json.loads(p.read_text(encoding="utf-8"))
        good(f"{p} 是合法 JSON")
    except json.JSONDecodeError as e:
        blow(f"{p} JSON 解析失败：{e}")

for p in manifests[:2]:
    if not p.is_file():
        continue
    data = json.loads(p.read_text(encoding="utf-8"))
    if data.get("name") == "vibe-rules":
        good(f"{p} name=vibe-rules")
    else:
        blow(f"{p} name 不是 vibe-rules：{data.get('name')!r}")
    if data.get("version") in (version, "@VERSION@"):
        good(f"{p} 版本与 VERSION 一致（{data['version']}）")
    else:
        blow(f"{p} 版本 {data.get('version')!r} 与 VERSION {version!r} 不一致")

for p in manifests[2:]:
    if not p.is_file():
        continue
    data = json.loads(p.read_text(encoding="utf-8"))
    names = [e.get("name") for e in data.get("plugins", [])]
    if "vibe-rules" in names:
        good(f"{p} 收录 vibe-rules")
    else:
        blow(f"{p} 没有 vibe-rules 条目：{names}")

for m in ok:
    print(f"  ✅ {m}")
for m in bad:
    print(f"  ❌ {m}")
pathlib.Path(sys.argv[1]).write_text(f"{len(ok)} {len(bad)}\n", encoding="utf-8")
PY

PY_OK="$(cut -d' ' -f1 "$PY_COUNT")"
PY_BAD="$(cut -d' ' -f2 "$PY_COUNT")"
PASS=$((PASS + ${PY_OK:-0}))
FAIL=$((FAIL + ${PY_BAD:-0}))

echo ""
echo "📊 validate-package：$PASS 通过，$FAIL 失败"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "🎉 打包校验全部通过"

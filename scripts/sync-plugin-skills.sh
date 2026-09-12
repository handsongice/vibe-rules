#!/usr/bin/env bash
# sync-plugin-skills.sh —— 按 skills/ 实况刷新插件清单里的 skill 列表
#
# 用法：scripts/sync-plugin-skills.sh            # 刷新
#       scripts/sync-plugin-skills.sh --check    # 只检查，不写文件（不一致时退出 1，CI 用）
#
# 为什么不用手写：每加一个 skill 都要改两处 JSON，迟早漂移。这里以 skills/ 为唯一数据源。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CHECK=0
case "${1:-}" in
  --check) CHECK=1 ;;
  -h|--help)
    sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  "") ;;
  *) echo "❌ 未知参数：$1（只支持 --check）" >&2; exit 2 ;;
esac

PYTHON="${PYTHON:-python3}"
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "❌ 需要 python3 来更新 JSON 清单" >&2
  exit 1
fi

"$PYTHON" - "$CHECK" <<'PY'
import json, pathlib, sys

check_only = sys.argv[1] == "1"
root = pathlib.Path(".")
manifests = [pathlib.Path(".claude-plugin/plugin.json"), pathlib.Path(".codex-plugin/plugin.json")]

skills = [f"./skills/{d.name}" for d in sorted((root / "skills").iterdir())
          if d.is_dir() and (d / "SKILL.md").is_file()]
if not skills:
    print("❌ skills/ 下一个 skill 都没有", file=sys.stderr)
    sys.exit(1)

dirty = []
for p in manifests:
    data = json.loads(p.read_text(encoding="utf-8"))
    current = data.get("skills", [])
    if current == skills:
        continue
    if check_only:
        dirty.append((p, current, skills))
        continue
    data["skills"] = skills
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"✅ 已同步 {p}（{len(skills)} 个 skill）")

if dirty:
    for p, current, want in dirty:
        print(f"❌ {p} 的 skills 列表与 skills/ 实况不一致", file=sys.stderr)
        missing = [s for s in want if s not in current]
        extra = [s for s in current if s not in want]
        for s in missing:
            print(f"   缺少：{s}", file=sys.stderr)
        for s in extra:
            print(f"   多余：{s}", file=sys.stderr)
    print("   修复：bash scripts/sync-plugin-skills.sh", file=sys.stderr)
    sys.exit(1)

if check_only:
    print(f"✅ 插件 skill 列表一致（{len(skills)} 个）")
PY

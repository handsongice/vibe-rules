# 发布说明（Release Notes）

> 这份是给**使用者**看的：这次更新你拿到了什么、需要做什么、有没有破坏性变更。
> 逐条的技术改动在 [CHANGELOG.md](CHANGELOG.md)；当前版本号在 [VERSION](VERSION)。

## 1.1.0 — 2026-09-13

一句话：**"规则进不进仓库、个人层带不带"这件事，以前写在 README 里靠自觉，现在由脚本帮你把关。**

### 你会用到的两个新档位

| 场景 | 命令 |
|---|---|
| 团队项目 / 云端 agent / CI 要读到规则 | `scripts/install.sh <项目> --profile team` |
| 只有自己用，规则不想进仓库 | `scripts/install.sh <项目> --profile personal` |

- `team`：规则副本进项目 `.vibe-rules/`、跟着仓库走；**不含** `personal/`（个人偏好与记忆不会被提交）。
  装完脚本还会查一遍 `.gitignore`——如果你把 `.vibe-rules/` 排除掉了，它会当场提醒你"副本进不了仓库"。
- `personal`：规则留在本机规则库、走外链，项目里只有入口文件；个人层照常带上。

档位会被记下来：以后跑 `update.sh` 自动沿用，`verify.sh` 也会按档位体检
（team 档发现 `personal/` 混进副本、或副本被 `.gitignore` 排除 → 直接报错）。

### 项目里多了两个文档位置

install 现在会在项目里建这两个目录（**只在不存在时建档，已有内容绝不覆盖**）：

- `docs/specs/` —— 设计文档。动手改架构前，把"做什么、为什么、边界在哪"写这里
- `docs/plans/` —— 实现计划。多步任务动代码前，把任务拆到"照着做就行"写这里

两个目录的 `README.md` 里有完整结构模板和自审清单，`AGENTS.md` 的引用块也加了一条指向它们——
所以别的 agent（或三个月后的你）开工时会自己找到。

不想要这两个目录？直接删掉就行（下次 install 会在缺失时重建；`.vibe-rules/` 和 `docs/` 的内容都不会被覆盖）。

### 提交前自检变简单了

- 一条命令：`bash scripts/preflight.sh`（打包校验 + 清单同步 + bash 冒烟 + pwsh 冒烟，没装 pwsh 会自动跳过）
- 想自动化：装 [pre-commit](https://pre-commit.com/) 后 `pre-commit install`，
  仓库里 `.pre-commit-config.yaml` 已经配好，每次 `git commit` 自动跑（纯本地 hook，不联网）

### 破坏性变更

**没有。** 不传 `--profile` 时行为跟以前完全一样（还是按 `--link` / `--no-personal` 这些细粒度选项走），
老项目直接重跑 `install` 即可，不会覆盖你已有的文件。

唯一算"行为变化"的是：install 现在会多建 `docs/specs/`、`docs/plans/` 两个空目录和说明文件（见上一节）。
证据文件多了一行 `profile=default`，旧项目缺这行也能正常 verify。

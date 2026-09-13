# 发布说明（Release Notes）

> 这份是给**使用者**看的：这次更新你拿到了什么、需要做什么、有没有破坏性变更。
> 逐条的技术改动在 [CHANGELOG.md](CHANGELOG.md)；当前版本号在 [VERSION](VERSION)。

## 1.5.0 — 2026-09-13

一句话：**"文档漂移"检查现在双向查**——README 和脚本选项对不上，哪个方向漏都会被拦在提交前。

### 你需要做什么

- 只想用规则：**什么都不用做**，装机脚本行为跟 1.4.0 完全一样（这次只动了规则库自己的检查工具）
- 自己 fork 了这个库、给脚本加过选项：加了 `--flag` 就必须写进 README，否则 CI 红；
  故意不给使用者看的内部选项，写进 `scripts/lint.sh` 的 `flag_doc_allowed()` 白名单

### 顺带修掉一个静默漏检

选项提取的正则原来只认字母（`[a-z]`）：如果要给脚本加一个带数字的选项（比如 `--sha1`），
lint 根本看不见它——不报错，也不检查，是最坏的一种"绿"。现在三处正则都放宽到 `[a-z0-9]`，
冒烟里用 `--ghost2-flag` 把这个场景钉住了。

## 1.4.0 — 2026-09-13

一句话：**提交前检查从一个方向扩到六个方向**——规则库自己"改一半"越来越难溜进 main；
装机行为没变，`install / update / verify / uninstall` 的用法跟 1.3.0 完全一样。

### 你需要做什么

- 只想用规则：**什么都不用做**，重新 `update` 一遍拿最新规则即可；本次唯一的使用侧变化是
  5 个 skill 补了「触发条件」段（见下）
- 自己 fork 了这个库、往里加 skill：新 lint 要求每个 `skills/<名字>/SKILL.md` 有非空
  `## 触发条件` 段，缺了 CI 直接红——这正是它想拦的事

### 5 个 skill 补了「触发条件」

`systematic-debugging`、`test-driven-development`、`writing-plans`、`plain-writing`、`frontend-taste`
以前只有 frontmatter 里的一句话 description，agent 什么时候该加载全靠猜；现在每个都有一节写死：

```
## 触发条件
遇到 bug、测试失败、报错、行为和预期不一致时，先加载本 skill 再动手改。
```

### 规则库自己的检查变严了（3 类 → 6 类）

```
bash scripts/lint.sh        # 全绿 = 6 通过，0 失败
```

| 检查 | 拦的是什么 |
|---|---|
| ① `$VAR` 后紧跟全角字符 | bash 3.2 会把变量名连后面的字节一起吞掉 → `unbound variable` |
| ② sh / ps1 配对 | 成对脚本只改了一半（漏了 Windows 侧） |
| ③ 选项对称（双向，新） | sh → ps1 漏参数、ps1 单侧加参数都会报；ps1 原生约定走白名单 |
| ④ skill 触发条件（新） | `skills/*/SKILL.md` 缺 `## 触发条件` 段、或段落为空 |
| ⑤ bash -n 语法（新） | 引号 / 反引号没配对（肉眼看不出，解析器一看就中） |
| ⑥ README 选项漂移（新） | README 里写了、但没有任何脚本认的选项 |

一条命令全跑：`bash scripts/preflight.sh`。

## 1.3.0 — 2026-09-13

一句话：**规则副本"漂移"和脚本"改一半"这两类问题，现在提交前就会被拦住。**

### 项目里可以挂一条 CI 了（可选）

```
scripts/install.sh <项目> --with-ci        # Windows: pwsh scripts\install.ps1 <项目> -WithCi
```

装完多一个 `.github/workflows/vibe-rules-verify.yml`，PR 上自动查两件事：

1. **副本漂移**：项目 `.vibe-rules/` 里的规则被手改过、少文件、多文件（跟规则库逐文件比对）
2. **接入完整性**：证据文件、AGENTS.md 引用块、agent 入口文件、档位落实情况

为什么值得开：副本模式唯一的坑就是"规则躺久了会漂"——有人顺手改了副本里的规则，下次 `update` 一刷就白改；
规则库升级了副本没跟上，agent 读到的是旧规则。这两件事人盯不住，CI 一挂就省心。

几个要知道的点：

- workflow 里**钉的是你安装时的那个 commit**，规则库以后怎么演进都不会突然把你项目 CI 弄红；
  想跟着 main 走就把它改成 `main`，想重新钉就跑 `update.sh <项目> --with-ci`
- 规则库是私有仓库的话，给这个 job 加 token/权限，或把 `VIBE_RULES_REPO` 换成你 fork 的地址
- 你**自己写的**同名文件不会被覆盖（脚本只认自己生成的标记）；`uninstall` 也只删自己生成的那个
- 外链模式（`--link` / `--profile personal`）不受影响：规则库在你本机，CI 读不到，`--with-ci` 会跳过并说明

不想开 CI 也行，本地随时手动查：

```bash
bash <vibe-rules>/scripts/check-copy.sh .     # 漂移就退出 1，并点名是哪个文件
```

### 规则库自己多了个提交前检查

`scripts/lint.sh` 专拦三类"已经真出过事"的问题：bash 3.2 下 `$VAR` 紧跟中文导致的崩、sh/ps1 只改了一半、
sh 认的选项 ps1 没有。已经挂进 pre-commit、`scripts/preflight.sh` 和仓库自己的 CI——
你如果 fork 了这个库来改，`bash scripts/preflight.sh` 一条命令全跑。

### 顺带修掉的真 bug

- `update.ps1` 现在支持 `-All` / `-AgentNums` / `-Profile` / `-Yes`（此前只有 sh 版能传，Windows 上想换 agent 名单得重装）
- 项目副本里不再带规则库自己的 `.pre-commit-config.yaml`：它引用的 `scripts/` 根本不在副本里，
  装了 pre-commit 的项目会直接报错（老项目重跑一次 `update` 即可清掉）

### 破坏性变更

**没有。** 不传 `--with-ci` 时项目里不会多任何文件；重跑 `install` / `update` 与以前一致。
唯一算"变化"的是：副本里少了 `.pre-commit-config.yaml` 和 `RELEASE-NOTES.md`（本来就该被排除），
老项目重跑一次 `update` 会自动清掉它们。

## 1.2.0 — 2026-09-13

一句话：**多了个"中间档"（规则进仓库、个人偏好不进仓库），以及一条命令管 spec/plan 的状态与过期。**

### 三个档位怎么选

| 你的情况 | 命令 |
|---|---|
| 团队项目 / 云端 agent / CI 都要读规则，个人偏好也想接上 | `scripts/install.sh <项目> --profile hybrid`（新） |
| 团队项目，个人偏好不带进仓库 | `scripts/install.sh <项目> --profile team` |
| 只有自己用，规则不进仓库 | `scripts/install.sh <项目> --profile personal` |

- `hybrid`：规则副本仍然进项目 `.vibe-rules/`、跟着仓库走（队友 clone 下来就能用）；
  **`personal/` 不进仓库**——AGENTS.md 第 3 条写的是你本机规则库的绝对路径，只有你这台机器读得到。
  取舍：换机器 / 换同事，个人偏好不会跟着走；想跟着走就用不带 `--profile` 的默认装法（副本含 `personal/`，自己注意别提交）。
- 档位和 `--link`、`--no-personal` 冲突时会直接报错（比如 `--profile hybrid --link` 是自相矛盾的）。
- 档位记在证据文件里，`update.sh` 自动沿用，`verify.sh` 按档位体检。

### spec / plan 的时效管理

每份设计文档、实现计划，在**文件开头（标题下面一行）**写一行状态：

```markdown
> status: active · updated: 2026-09-13
```

`status` 四选一：`draft`（还在讨论，别照着做）/ `active`（在做）/ `done`（做完了，不用重读全文）/ `abandoned`（放弃了，写清为什么）。
`done` 和 `abandoned` 的文档，下一个 agent 直接跳过——这就是状态行的意义。

配套脚本在**规则库**里（不在项目副本里，副本只带规则本体）：

```bash
bash <vibe-rules>/scripts/docs-status.sh .              # 汇总：谁在写、谁做完了、多久没动
bash <vibe-rules>/scripts/docs-status.sh . --stale 30   # 列出超 30 天没更新且还没完成的
bash <vibe-rules>/scripts/docs-status.sh . --check      # 缺状态行就报错退出（可挂 CI）
bash <vibe-rules>/scripts/docs-status.sh . --archive    # 把 done/abandoned 移进同级 archive/（git 仓库走 git mv）
```

新装的项目，`docs/specs/README.md`、`docs/plans/README.md` 里已经写好了这份约定和模板；
老项目重跑一次 `install` 也会把 `AGENTS.md` 引用块第 7 条刷新成带状态行的版本。

### 破坏性变更

**没有。** 都是新增：不问就不用。老项目重跑 `install` / `update` 只会刷新引用块，不动你的正文和既有文档。

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

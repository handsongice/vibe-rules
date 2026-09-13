# 更新日志

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)；版本号写在仓库根目录的 `VERSION`，
并由 `scripts/bump-version.sh` 同步到插件清单（`.claude-plugin/plugin.json`、`.codex-plugin/plugin.json`）。

## [Unreleased]

## [1.3.0] - 2026-09-13

主题：**让"漂移"和"改一半"两类问题在提交前就被拦住**——规则库自身有静态检查（lint），
项目侧有副本漂移检查，一条 `--with-ci` 就能把后者挂进项目的 PR。

### 新增

- **`scripts/lint.sh`**——规则库自身的静态检查（工具在规则库里，不随副本进项目），查三类"已经真出过事"的问题：
  - ① `$VAR` 后紧跟非 ASCII 字符：bash 3.2 会把后面的字节一起吞进变量名 → `unbound variable`（要求写 `${VAR}`；
    只查命名变量，`$1（` 这类位置参数不误报；注释行跳过）
  - ② sh / ps1 配对：成对脚本不能只改一半（单侧开发工具写进 `SH_ONLY_TOOLS` 白名单，如 `preflight`、`lint`、`check-copy`）
  - ③ 选项对称：sh 里认识的每个 `--flag`，ps1 的 `param()` 里必须有对应参数（`--agents` ↔ `-AgentNums` 做归一化）
  - 接线：`.pre-commit-config.yaml`、`scripts/preflight.sh`（现在是 5 步）、`.github/workflows/smoke.yml`（Ubuntu + macOS bash 3.2 两档）
- **`scripts/check-copy.sh` + `templates/CI-VERIFY.yml` + `install --with-ci`**——项目侧副本漂移检查：
  - `check-copy.sh`：把项目 `.vibe-rules/` 跟规则库**逐文件比对**（排除 `installed`、`README.md`、`project/`），
    手改副本、副本缺文件、副本多文件都会退出 1；外链模式（`mode=link`）跳过并说明；支持 `--rules-home`
  - `install --with-ci`（PS：`-WithCi`）：顺手生成 `.github/workflows/vibe-rules-verify.yml`，PR 上先 `check-copy.sh` 再 `verify.sh`；
    规则库地址与 commit 在生成时替换进 workflow（`git@github.com:` 会转成 https），只对副本模式有意义
  - `update --with-ci`：把 workflow 重新钉到当前规则库 commit；`uninstall`（含 PS）按文件里的生成标记删掉它，
    自己写的同名文件不覆盖、自己写的别的 workflow 不动

### 修复

- **`update.ps1` 补齐 `-All` / `-AgentNums` / `-Profile` / `-Yes`**——此前 `update.sh` 能透传这些给 install，
  PS 版不能（lint ③ 抓到的真不对称：两边行为会不一样）
- **`scripts/sync-plugin-skills.sh`**：报错信息里的 `$1（` 在 bash 3.2 下会把后续字节吞进变量名（输出乱码），改成 `${1}`
- **副本不再带 `.pre-commit-config.yaml` / `RELEASE-NOTES.md`**——此前会把规则库自己的 pre-commit 配置复制进项目副本，
  而它引用的 `scripts/` 在副本里并不存在，装了 pre-commit 的项目会直接报错；`install` 的排除清单与清理清单同步更新
- **`scripts/lint.sh` 自身**：`set -e` + `pipefail` 下无匹配的 `grep` 会中断检查（补 `|| true`）；① 命中时只打印不计入失败数
  （假绿），已补计数

### 变更

- `README.md`：补 lint 三类检查说明表、`--with-ci` / `check-copy.sh` 用法与约定（钉 commit、私有库、重跑覆盖）、
  目录树补 `check-copy.sh` 与 `templates/CI-VERIFY.yml`、冒烟断言数更新
- `tests/smoke.sh`（新增第 17/18/19 节）与 `tests/smoke.ps1`（新增第 15 节）：覆盖 lint 负例、副本漂移检测、CI workflow 生成与清理

## [1.2.0] - 2026-09-13

主题：**补上"中间档"和文档的时效管理**——"规则要进仓库、个人偏好不进仓库"有档位可选；
spec / plan 不再越堆越多，谁在写、多久没动、能不能归档，一条命令看清。

### 新增

- **`--profile hybrid` 混合档**（PowerShell：`-Profile hybrid`）——副本进仓库，但 `personal/` 走本机外链：
  - 装法仍是自包含副本（`mode=embedded`），但安装时排除 `personal/`，AGENTS.md 第 3 条指向本机规则库的绝对路径
  - 与 `--link`（要外链就整个外链）、`--no-personal`（混合档就是要接上个人层）冲突时直接报错退出
  - 装完照旧自查 `.gitignore`；`verify.sh` / `verify.ps1` 按档位校验"副本能进仓库 + 副本无 `personal/` +
    本机规则库有 `personal/` + 引用块第 3 条指向本机路径"
- **`scripts/docs-status.sh`**——文档时效管理（工具在规则库里，不随副本进项目）：
  - 汇总 `docs/specs/`、`docs/plans/` 每份文档的状态行、更新日期与天数；`--stale N` 列出超 N 天没动且没完成的
  - `--check`：有文档缺状态行就退出 1（可挂 CI / 提交前检查）；`--archive`：把 `done` / `abandoned` 移进同目录 `archive/`
    （git 仓库里走 `git mv`，保留历史；重名自动加时间戳）
  - 状态行约定：`> status: draft|active|done|abandoned · updated: YYYY-MM-DD`，写在文件开头（标题下面一行），
    没写 `updated` 时按文件修改时间算

### 变更

- `install.sh` / `install.ps1`：`--profile` 取值扩到 `team|hybrid|personal`；团队档 / 混合档的 `.gitignore`
  提醒改用中文档位名（团队档提醒 / 混合档提醒）
- `templates/DOCS-SPECS.md` / `templates/DOCS-PLANS.md`：新增「状态行」章节（状态含义表 + 状态流转 + docs-status.sh 用法），
  结构模板头部补状态行；`templates/ENTRY.md` 与 AGENTS.md 引用块第 7 条同步写入约定
- `skills/brainstorming`、`skills/writing-plans`：写 spec/plan 时带上状态行，流转时改状态（draft → active → done）
- `README.md`：档位表补 `hybrid` 行与取舍说明、补 `docs-status.sh` 四条用法、日常沉淀表标注状态行

### 升级注意（行为变化）

- 都是新增：不传 `--profile hybrid`、不用 `docs-status.sh` 的老项目行为不变；重跑 `install` 只会把引用块第 7 条刷新成带状态行的版本

## [1.1.0] - 2026-09-13

主题：**把"策略"从文档约定变成脚本强制**，并补上规格驱动的文档位置与提交前自检。

### 新增

- **策略档位 `--profile team|personal`**（PowerShell：`-Profile`）——把"规则进不进仓库、个人层带不带"
  从 README 里的口头约定收进脚本，安装时记进证据文件（`profile=`）：
  - `team`：强制自包含副本 + 不含 `personal/`；装完自查 `.gitignore` 有没有把 `.vibe-rules/` 排除掉，排除了就报警
  - `personal`：强制外链模式（规则不落进仓库），个人层照常带上
  - 与 `--link` / `--no-personal` 冲突时直接报错退出，不猜用户意图
- `update.sh` / `update.ps1`：沿用证据文件里的档位；显式传 `--link` / `--no-personal` / `--profile` 可覆盖
- `verify.sh` / `verify.ps1`：按档位校验——team 档查"副本不含 `personal/` 且没被 `.gitignore` 排除"，
  personal 档查"规则没落进项目"；旧证据文件缺 `profile=` 时按 `default` 处理，不误报
- **项目文档约定（规格驱动）**：install 在项目里建 `docs/specs/README.md` 与 `docs/plans/README.md`
  （只在不存在时建档、永不覆盖），AGENTS.md 引用块新增第 7 条指向这两个位置
- `scripts/preflight.sh`：一条命令跑完打包校验 + 清单同步检查 + bash 冒烟 + pwsh 冒烟（没装 pwsh 自动跳过）
- `.pre-commit-config.yaml`：提交前自动跑 `bash -n`、`validate-package.sh`、`sync-plugin-skills.sh --check`、`tests/smoke.sh`
  （纯 `repo: local` hook，不联网、不依赖第三方 hook 仓库）
- `RELEASE-NOTES.md`：面向使用者的发布说明（改了什么、要做什么、有没有破坏性变更）
- `templates/DOCS-SPECS.md` / `templates/DOCS-PLANS.md`：把散在 skill 里的文档位置约定固化成项目内模板
  （结构模板 + 自审清单），install 建档时直接落这两份说明

### 变更

- `install.sh` / `update.sh --help` 改为打印整段注释头（不再写死行号，以后加选项不会漏）
- `templates/ENTRY.md`：补两种策略档位对照表、`docs/` 说明；卸载说明明确保留 `docs/`

### 升级注意（行为变化）

- `install.sh` / `install.ps1` 现在会在项目里创建 `docs/specs/`、`docs/plans/` 两个目录及其 `README.md`：
  **已存在的文件绝不覆盖**；不想要可以直接删（下次 install 会在缺失时重建）；`--link` 外链模式不建
- 证据文件新增一行 `profile=`；老项目没有这一行时一律按 `default` 走，verify 不会因此报错

## [1.0.0] - 2026-09-12

### 新增

- 插件打包：`.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`，Claude Code 可直接按插件安装
- 插件打包：`.codex-plugin/plugin.json` + `.agents/plugins/marketplace.json`，Codex 仓库市场（repo marketplace）可直接安装
- 每个 skill 增加 `agents/openai.yaml`（UI 展示名、一句话说明、默认提示词），可被 `$skill-name` 直接调用
- `scripts/sync-plugin-skills.sh`：以 `skills/` 为唯一数据源同步插件清单里的 skill 列表，不再手写、不会漂移
- `scripts/validate-package.sh`：校验 skill 结构、frontmatter、插件清单与版本号一致性
- `scripts/bump-version.sh`：一条命令同步 `VERSION`、插件清单、CHANGELOG
- `.gitattributes`：统一 LF 换行，避免 Windows 检出后脚本坏掉

### 修复

- 插件清单：Codex 的 `skills` 改为官方规范的目录字符串 `./skills/`（此前写成数组，实测能加载但不合规范）；
  Claude 保留显式 skill 列表——它的 marketplace 条目 `source` 指向仓库根，这种情形按官方文档要显式声明子目录
- `install.sh` / `install.ps1`：不再把 pwsh 在只读 HOME 环境落到工作目录的运行时缓存
  （`ModuleAnalysisCache*`、`StartupProfileData*`）复制进项目副本
- `uninstall.sh --purge-project` / `uninstall.ps1 -PurgeProject`：直接删净整个 `.vibe-rules/`，
  不再因残留文件删不掉；Windows 版补齐旧版打包产物（`.agents` / `.claude-plugin` / `.codex-plugin`）清理

### 说明

- 规则库本体（`global/`、`languages/`、`skills/`）与项目副本（`.vibe-rules/`）的使用方式不变；
  插件打包是**额外**多一条接入路径，不影响 `install.sh` / `install.ps1`。

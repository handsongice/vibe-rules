# 更新日志

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)；版本号写在仓库根目录的 `VERSION`，
并由 `scripts/bump-version.sh` 同步到插件清单（`.claude-plugin/plugin.json`、`.codex-plugin/plugin.json`）。

## [Unreleased]

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

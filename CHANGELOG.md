# 更新日志

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)；版本号写在仓库根目录的 `VERSION`，
并由 `scripts/bump-version.sh` 同步到插件清单（`.claude-plugin/plugin.json`、`.codex-plugin/plugin.json`）。

## [Unreleased]

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

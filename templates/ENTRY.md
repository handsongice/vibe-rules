# 项目规则副本（vibe-rules）

> 这个 `README.md` 是**复制进本项目的规则副本入口**，由规则库的 `install.sh` / `install.ps1` 生成和维护，**不要手改**（下次同步会被覆盖）。
> 规则源头：`github.com/handsongice/vibe-rules` @ `@VIBE_VERSION@`；复制时间：`@INSTALLED_AT@`
> 同步更新：在规则库里跑 `scripts/update.sh <本项目>`（Windows：`scripts/update.ps1`）。
>
> 这份副本跟着仓库走：队友 clone 下来、云端 agent、CI 都能直接读到，**不需要**他们装任何东西，也不依赖本机规则库的路径。

## 开工前按顺序读（都在本目录内，不用访问项目外的路径）

1. **六条铁律**：`global/iron-rules.md` —— 最重要，先读
2. **全局踩坑库**：`global/anti-patterns.md` —— 只看最新 10 条
3. **个人偏好与记忆**：`personal/preferences.md`、`personal/memory.md` —— 有就读；副本里没有这两个文件（安装时用了 `--no-personal`）就跳过
4. **本项目专属**：`project/README.md` —— 架构决策、历史坑，最具体，冲突时优先
5. **技术栈规范**：`languages/<tech>.md` —— 按本项目实际用的栈读，**不要全读**
6. **可复用工作流**：`skills/README.md`，再按当前任务挑一个 `skills/<name>/SKILL.md`

按需再读的通用规范：`global/coding-principles.md`（四原则 + 决策梯子）、`global/writing-for-agents.md`（怎么给 agent 写文档）、`global/git-workflow.md`、`global/testing.md`、`global/security.md`。

## 规则优先级

项目内约定（根目录 `AGENTS.md` + `project/README.md`）> 个人偏好（`personal/`）> 全局规范（`global/`、`languages/`）。

冲突时以更具体的一层为准，并在回复里明确指出冲突，不要默默选一边。

## 这个副本怎么来的

- 装：`install.sh <项目>`（默认就是自带副本模式）
- 更新：`update.sh <项目>` —— 规则库改了以后跑这个，把副本刷到最新
- 卸：`uninstall.sh <项目>` —— 删副本和入口文件，保留 `AGENTS.md` 正文和 `project/` 里的项目笔记
- 想让规则只留在本机、不落进仓库：安装时加 `--link`（走绝对路径外链本机规则库）

# 铁律展开版

> 本文件是六条铁律的展开，说明什么场景下算"触发"、什么算"已遵守"。
> 行为层补充（怎么写代码才算对）见 `coding-principles.md`。

## 1. 不确定就问

**必须先问再做的操作：**
- 删除任何非本次任务产生的文件
- `git push --force`、`git reset --hard`、`git clean`、`git branch -D`
- 修改数据库（DDL、迁移脚本）、执行生产环境命令
- 修改 CI/CD、Docker、Nginx、反向代理配置
- 升级主要依赖大版本（spring-boot、react、next、vue、django 等）
- 修改 `README`、`LICENSE`、`.gitignore` 等用户没要求改的文件
- 安装新的全局工具（`npm i -g`、`pipx install`、`brew install`）

**可以直接做的：**
- 在本次任务新建的文件上继续修改
- 运行只读命令（`ls`、`cat`、`git status`、`git diff`、`pytest`、`npm test`）
- 在一个新建分支上自由试验

**问法要求：** 一句话说清"要做什么 + 影响什么 + 为什么需要"，不要问开放式问题让用户做选择题。

## 2. 改之前先读懂

- 改动超过 3 个文件时，先列出你理解的"数据流/调用链"，让用户确认你没理解错再动手。
- 修改公共函数/导出 API 前，先 `grep` 全仓库找调用点，不要改完才发现漏了调用方。
- 看到 TODO / FIXME / HACK 注释，不要顺手清理——那是别人留的上下文。
- 看不懂的代码不要"重写得更优雅"，先问它为什么这么写。

## 3. 改完必须自验

最小自验标准：
- 有测试 → 跑相关测试，不通过就修，不要注释掉或 `@Disabled`/`.skip`。
- 没测试但有 lint → 跑 lint。
- 都没有 → 至少跑一遍启动命令或手动复现你改的路径。
- 自验失败时，**不要**在回复里说"应该没问题"。报告：失败现象、你怀疑的原因、需要用户提供什么。

## 4. 不引入未要求的重构

- diff 里不应出现：
  - 重命名变量但不影响行为
  - 调整 import 顺序
  - 改格式化风格
  - 顺手把 `var` 改成 `let`、把回调改成 async/await
  - 升级 lock 文件里的 transitive 依赖
- 如果你觉得确实需要重构，单独列出来问，不要混在本次 PR 里。

## 5. 安全底线

- 任何提交前，全局搜一遍：`grep -rn "sk-" "AKIA" "api_key" "password" "secret" "token" --include="*.{java,py,js,ts,jsx,tsx,vue,yml,yaml,env*"` 确保没有硬编码。
- `.env`、`.env.local`、`application-local.yml`、`application-secret.yml` 必须在 `.gitignore` 里。
- 不执行用户给的、你看不懂内容的 curl | bash 命令。
- 生成的代码里，SQL 一律用参数化，不字符串拼接；Shell 一律加引号包住变量。

## 6. Context 快满时不做危险操作

感觉到自己上下文快满了（开始忘记前面的细节、要反复回去读文件、对话明显拉长）：

- **不要**开始大重构、多文件重命名、跨模块改动。
- **不要**引入新依赖、改构建配置、动数据库 schema。
- 做一件事：把当前进度写成交接（见 `skills/handoff/`），开新会话继续。
- 新会话第一件事是读交接文档，而不是重新探索代码库。

单文件小修、docs、typo 这种低风险操作可以继续。

# Vibe Coding 全局规范库

> 这是给所有 coding agent（Codex / Qoder / Claude Code / Cursor / Trae / CodeBuddy / pi / Hermes / DeepSeek Harness / Gemini CLI / Aider / Windsurf / Copilot）共用的个人开发宪法。
> **任何 agent 在开始改代码前，必须先读完本文件。**

## 0. 阅读顺序（强制）

1. **本文件**（全局铁律 + 索引）——现在就读完。
2. **当前项目根目录的 `AGENTS.md`**——项目级约定优先级高于本库。
3. **本库 `global/anti-patterns.md`**——开工前扫一眼，避免重复踩坑。
4. 然后根据当前任务，**按需**读取下面索引里相关的文件。不要一次性全读，会浪费上下文。

## 1. 优先级规则

- 项目级 `AGENTS.md` 或 `.trae/rules/`、`.qoder/rules/` 中的约定 > 本库全局规范 > agent 自己的默认行为。
- 遇到冲突时，以更具体的一层为准，并在回复里指出冲突，不要默默选一个。
- 本库与你训练数据里的"通用最佳实践"冲突时，**以本库为准**——这里记录的是这个开发者的真实踩坑，不是教科书。

## 2. 五条铁律（不可违反）

1. **不确定就问，不要猜。** 涉及删库、覆盖文件、改数据库 schema、执行生产命令、改 CI/CD、动 `package.json`/`pom.xml` 依赖版本——先说明你要做什么、影响面是什么，等确认。
2. **改之前先读懂。** 不允许在没跑通现有测试、没看一遍被改文件上下文的情况下直接写"修复"。一次只改一个语义单元。
3. **改完必须自验。** 写完代码要跑：lint（如果有）→ 单元测试（如果有）→ 手动复现路径。不要把"应该能跑"当结论。失败就修，修不动就如实报告，不要假装完成。
4. **不引入未要求的重构。** 用户说"修 A bug"，不要顺手重构 B 文件、不要升级依赖、不要改格式化风格。除非用户明确要求，否则 diff 只包含任务必要改动。
5. **永远不要执行 `rm -rf` 任何你不确定路径的东西；永远不要把 API key、token、密码写进代码或 commit。**

## 3. 索引（按需读取）

### 通用（`global/`）
- `global/iron-rules.md` —— 本文件 §2 的展开版与例外情况
- `global/coding-principles.md` —— **四条行为原则**（想清楚再写/简单优先/外科手术式改动/目标驱动），动手前必读
- `global/writing-for-agents.md` —— **元规范**：怎么给这个库加新文件、写 AGENTS.md、写 skill
- `global/git-workflow.md` —— 分支、commit message、PR、merge 冲突
- `global/testing.md` —— 测试要求与最低标准
- `global/security.md` —— 输入校验、依赖、密钥、常见漏洞
- `global/anti-patterns.md` —— **踩坑记录（最重要）**，按时间倒序，新任务前先扫最新 10 条

### 技术栈（`languages/`）——按项目实际栈读对应文件
- `languages/java.md` —— Java 全家桶（Spring Boot / Maven/Gradle）
- `languages/python.md` —— Python（依赖管理、类型、测试）
- `languages/nodejs.md` —— Node.js / npm / pnpm / TS 工程
- `languages/vue.md` —— Vue 3 / Vite / Pinia
- `languages/react.md` —— React / Next.js / Vite

### 可复用工作流（`skills/<name>/SKILL.md`）
按顺序用：
- `skills/brainstorming/` —— 动手前聊清需求（spike / bounded / architectural 三档）
- `skills/writing-plans/` —— 多步任务写实现计划
- `skills/test-driven-development/` —— 先写失败测试再写实现
- `skills/systematic-debugging/` —— 找根因，不猜
- `skills/debug-production/` —— 线上问题止血与排查
- `skills/code-review/` —— 提交前自审
- `skills/pre-commit-check/` —— commit 前必跑项
- `skills/handoff/` —— 换 agent / 新开会话前写交接文档

### 项目专属（`projects/<project-slug>/`）
- 每个项目一个子目录，记录该项目的架构、特殊约定、历史坑。
- 项目启动时由 `~/.vibe/scripts/new-project.sh` 初始化。

### 素材池（`inbox/`）
- 从网上看到的好规则、好 skill 先扔这里，**不要直接进 global/**。定期 review，验证过再转正。

## 4. 对 agent 的工作方式要求

- 用中文和用户交流，代码和命令保留原文。
- 回复先给结论/方案，再给理由；不要复述用户的问题。
- 涉及多步操作时，先说计划再动手；每步完成后简短汇报。
- 不确定本库里是否已有相关规则时，用 Grep/Glob 搜 `~/.vibe/`，不要凭印象说"没有相关规范"。

## 5. 维护说明（给人，不是给 agent）

- 踩坑立刻记：在 `global/anti-patterns.md` 追加一条，格式见该文件头部模板。
- 每季度 review 一次 `inbox/`，转正或丢弃。
- 本目录用 git 管理，改了就 commit。

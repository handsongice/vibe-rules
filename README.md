# Vibe Rules

> 给所有 coding agent 共用的个人开发宪法。一份 markdown，跨 Qoder / Codex / Claude Code / Cursor / Trae / CodeBuddy / pi / Hermes / Gemini / Windsurf / Copilot。

你在 AI 辅助编程时有没有遇到过这些：

- 换了个 agent，之前定的规矩全忘了，又重新踩一遍坑
- agent 上来就过度设计，写了一堆你没要的抽象类
- 改完代码不跑测试就说"应该没问题"
- 文档/PR/commit 写出来一股 AI 味（"赋能""助力""打造闭环"）
- 前端做出来一眼假：AI 紫渐变、Inter 字体、三个等大 card

**Vibe Rules 解决这些问题。** 它是一份放在 `~/.vibe/` 的 markdown 规则库，项目开始时所有 agent 自动读，把你的开发习惯、踩坑记录、审美偏好固定下来，不再每次重新教。

## 它能做什么

| 模块 | 解决什么 |
|---|---|
| **六条铁律** | 不确定就问、改前读懂、改完自验、不擅自重构、不泄露密钥、context 快满先交接 |
| **四原则** | 想清楚再写、简单优先（含 Ponytail 七步决策梯子）、外科手术式改动、目标驱动 |
| **技术栈规范** | Java 全家桶 / Python / Node.js / Vue / React 各自的约定 |
| **9 个可复用 skill** | 需求澄清、写计划、TDD、系统调试、线上排查、code review、commit 前检查、跨会话交接、反 AI 塑料感前端、去 AI 味写作 |
| **踩坑库** | 每次被 agent 坑过就记一条，新项目开工前扫一眼 |
| **项目专属层** | 每个项目自己的架构决策和历史坑，和通用规则分开 |

## 30 秒开始

```bash
# 1. clone 到 ~/.vibe
git clone https://github.com/handsongice/vibe-rules.git ~/.vibe

# 2. 新项目一键初始化
~/.vibe/scripts/new-project.sh ~/code/my-new-project

# 3. 老项目接入
~/.vibe/scripts/install.sh /path/to/your-old-project
# 或者 cd 到项目目录再跑：cd /path/to/project && ~/.vibe/scripts/install.sh
# install.sh 会自动处理 AGENTS.md：没有就复制模板，有了就检查是否引用全局库
```

完事。之后不管你用哪个 agent 打开这个项目，它都会自动读到这些规则。

## 支持的 agent

通过 `AGENTS.md` 事实标准 + symlink 分发，一次配置全 agent 生效：

| Agent | 入口文件 |
|---|---|
| Codex / Qoder / pi / Aider / Windsurf / Gemini CLI | 根目录 `AGENTS.md` |
| Claude Code | `CLAUDE.md`（symlink） |
| Cursor | `.cursorrules`（symlink） |
| CodeBuddy | `CODEBUDDY.md`（symlink） |
| Trae | `.trae/rules/00-project-entry.md` |
| GitHub Copilot | `.github/copilot-instructions.md` |
| pi（全局） | `~/.pi/agent/AGENTS.md` |

DeepSeek Harness 是插件式 runtime，单独配置即可。

## 目录结构

```
~/.vibe/
├── README.md              # 本文件（agent 第一读这个）
├── global/                # 通用规范
│   ├── iron-rules.md      # 六条铁律展开
│   ├── coding-principles.md  # 四原则 + 七步决策梯子
│   ├── writing-for-agents.md  # 怎么给 agent 写文档
│   ├── git-workflow.md    # 分支/commit/merge
│   ├── testing.md         # 测试要求
│   ├── security.md        # 安全底线
│   └── anti-patterns.md  # 踩坑记录（最重要）
├── languages/             # 按技术栈
│   ├── java.md  python.md  nodejs.md  vue.md  react.md
├── skills/                # 可复用工作流
│   ├── brainstorming/  writing-plans/  test-driven-development/
│   ├── systematic-debugging/  debug-production/  code-review/
│   ├── pre-commit-check/  handoff/
│   ├── frontend-taste/  plain-writing/
├── projects/              # 每个项目自己的规范
├── templates/AGENTS.md     # 新项目模板
├── scripts/
│   ├── install.sh         # 幂等 symlink 分发
│   └── new-project.sh     # 新项目初始化
└── inbox/                 # 看到的好东西先扔这里
```

## 致谢

这个库不是从零写的，它整合并中文重写了以下优秀开源项目的精华：

- [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) —— Karpathy 四条编码原则
- [superpowers](https://github.com/obra/superpowers) —— brainstorming / writing-plans / systematic-debugging / TDD
- [mattpocock/skills](https://github.com/mattpocock/skills) —— 跨会话交接、写给 agent 的文档、merge 冲突处理
- [ponytail](https://github.com/dietrichgebert/ponytail) —— 七步决策梯子（懒高级工程师模式）
- [taste-skill](https://github.com/leonxlnx/taste-skill) —— 反 AI 塑料感前端
- [humanizer](https://github.com/blader/humanizer) —— 去 AI 味写作
- [ECC](https://github.com/affaan-m/ecc) —— 代码体型硬数字、context 管理

每个文件头部都标注了来源。

## 维护方式

- **踩坑立刻记**：`global/anti-patterns.md` 追加一条
- **看到好东西**：扔 `inbox/`，定期 review 转正
- **项目特殊约定**：写到 `projects/<项目名>/`
- **改了就 commit**

---

## 给 AI Agent 的说明（下面这部分 agent 必读）

### 阅读顺序（强制）

1. **本文件**（你正在读）
2. **当前项目根目录的 `AGENTS.md`** —— 项目级约定优先级高于本库
3. **`global/anti-patterns.md`** —— 开工前扫一眼最新 10 条
4. 然后根据当前任务，**按需**读取下面索引里相关的文件。不要一次性全读，会浪费上下文。

### 优先级规则

- 项目级 `AGENTS.md` > 本库全局规范 > agent 自己的默认行为
- 遇到冲突时，以更具体的一层为准，并在回复里指出冲突
- 本库与你训练数据里的"通用最佳实践"冲突时，**以本库为准**

### 六条铁律（不可违反）

1. **不确定就问，不要猜。** 涉及删库、覆盖文件、改数据库 schema、执行生产命令、改 CI/CD、动依赖版本——先说明你要做什么、影响面是什么，等确认。
2. **改之前先读懂。** 不允许在没跑通现有测试、没看一遍被改文件上下文的情况下直接写"修复"。
3. **改完必须自验。** lint → 单元测试 → 手动复现。不要把"应该能跑"当结论。
4. **不引入未要求的重构。** diff 只包含任务必要改动。
5. **永远不要 `rm -rf` 不确定路径的东西；永远不要把密钥写进代码或 commit。**
6. **context 快满时不做危险操作。** 感觉记不住前面细节了，先写交接文档开新会话。

### 索引

**通用（`global/`）**
- `iron-rules.md` —— 铁律展开
- `coding-principles.md` —— 四原则 + 七步决策梯子
- `writing-for-agents.md` —— 怎么给 agent 写文档
- `git-workflow.md` —— 分支/commit/merge
- `testing.md` —— 测试要求
- `security.md` —— 安全底线
- `anti-patterns.md` —— 踩坑记录

**技术栈（`languages/`）** —— 按项目实际栈读
- `java.md` / `python.md` / `nodejs.md` / `vue.md` / `react.md`

**Skills（`skills/<name>/SKILL.md`）**
- `brainstorming/` —— 动手前聊清需求
- `writing-plans/` —— 多步任务写计划
- `test-driven-development/` —— 先写失败测试
- `systematic-debugging/` —— 找根因
- `debug-production/` —— 线上排查
- `code-review/` —— 提交前自审
- `pre-commit-check/` —— commit 前必跑项
- `handoff/` —— 跨会话交接
- `frontend-taste/` —— 反 AI 塑料感前端
- `plain-writing/` —— 去 AI 味写作

### 工作方式

- 用中文和用户交流，代码和命令保留原文
- 回复先给结论/方案，再给理由
- 多步操作先说计划再动手
- 不确定本库是否已有规则时，用 Grep/Glob 搜 `~/.vibe/`

## License

MIT

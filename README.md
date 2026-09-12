# Vibe Rules

> 给所有 coding agent 共用的个人开发宪法。一份 markdown，跨 Codex / Claude Code / Cursor / Qoder / Trae / CodeBuddy / Hermes / Kimi Code / DeepSeek Harness / Windsurf / Copilot。

你在 AI 辅助编程时有没有遇到过这些：

- 换了个 agent，之前定的规矩全忘了，又重新踩一遍坑
- agent 上来就过度设计，写了一堆你没要的抽象类
- 改完代码不跑测试就说"应该没问题"
- 文档/PR/commit 写出来一股 AI 味（"赋能""助力""打造闭环"）
- 前端做出来一眼假：AI 紫渐变、Inter 字体、三个等大 card

**Vibe Rules 解决这些问题。** 它是一份放在任意路径的 markdown 规则库（脚本会自动定位并记住位置），项目开始时所有 agent 自动读，把你的开发习惯、踩坑记录、审美偏好固定下来，不再每次重新教。

## 它能做什么

| 模块 | 解决什么 |
|---|---|
| **六条铁律** | 不确定就问、改前读懂、改完自验、不擅自重构、不泄露密钥、context 快满先交接 |
| **四原则** | 想清楚再写、简单优先（含 Ponytail 七步决策梯子）、外科手术式改动、目标驱动 |
| **技术栈规范** | Java 全家桶 / Python / Node.js / Vue / React 各自的约定 |
| **10 个可复用 skill** | 需求澄清、写计划、TDD、系统调试、线上排查、code review、commit 前检查、跨会话交接、反 AI 塑料感前端、去 AI 味写作 |
| **踩坑库** | 每次被 agent 坑过就记一条，新项目开工前扫一眼 |
| **项目专属层** | 每个项目自己的架构决策和历史坑，和通用规则分开 |

## 30 秒开始

### macOS / Linux

```bash
# 1. clone 到任意路径
git clone https://github.com/handsongice/vibe-rules.git ~/code/vibe-rules

# 2. 老项目接入（直接调用规则库里的脚本）
~/code/vibe-rules/scripts/install.sh /path/to/your-project

# 3. 或者初始化新项目
~/code/vibe-rules/scripts/new-project.sh /path/to/new-project
```

### Windows（PowerShell）

```powershell
# 1. clone 到任意路径
git clone https://github.com/handsongice/vibe-rules.git C:\code\vibe-rules

# 2. 老项目接入
pwsh C:\code\vibe-rules\scripts\install.ps1 C:\path\to\your-project

# 3. 或者初始化新项目
pwsh C:\code\vibe-rules\scripts\new-project.ps1 C:\path\to\new-project
```

> Windows 上建 symlink 需要管理员权限或开启开发者模式。脚本会自动降级为复制文件，效果一样。
>
> PS 脚本的 `-Help`（等价于 sh 版的 `--help`）可以查看参数；`-Yes` 非交互，`-AgentNums 1,4,7` 选 agent，
> `-Copy` 强制复制模式。

完事。之后不管你用哪个 agent 打开这个项目，它都会自动读到这些规则。

规则库放哪都行，脚本会自动定位。挪了位置？重新跑一次 install 就行。

### 常用参数（install / new-project 通用）

```bash
scripts/install.sh <项目路径> [选项]

  --all            给 12 个 agent 全部建入口
  --agents 1,4,7   只装指定编号的 agent（编号见“支持的 agent”一节，装完记在项目 .vibe-rules 里）
  --copy           用复制文件代替 symlink（symlink 被 Windows/Git 限制时用）
  --yes            非交互（不带 --agents 时等价于 --all，CI / 批量接入用）
  --help           查看全部参数
```

不带任何选项时是交互式的：列出 12 个 agent，你输入编号或 `all`。

只装了 4 个 agent 也没关系：`verify` 只校验你装过的那些，不会拿没装的报错。换机器或挪了规则库，
重跑一次 install 就会自动刷新路径。

## 支持的 agent

每个 agent 的入口文件都来自官方文档，不是猜的。

编号就是 `--agents` 要填的数字（唯一数据源：`scripts/agents.conf`，所有脚本都读它，不需要改代码）。

### 原生读 AGENTS.md（无需额外文件）

| 编号 | Agent | 说明 | 出处 |
|---|---|---|---|
| 2 | Codex CLI | 根目录 AGENTS.md | https://github.com/openai/codex |
| 8 | Hermes | 根目录 AGENTS.md | https://hermes-agent.nousresearch.com/docs/user-guide/features/context-files |
| 9 | Kimi Code | 根目录 AGENTS.md | https://moonshotai.github.io/kimi-code/en/customization/agents |
| 10 | DeepSeek Harness | 根目录 AGENTS.md | https://github.com/deepseek-ai/deepseek-harness |

### 单文件型（symlink 指向 AGENTS.md）

| 编号 | Agent | 入口文件 | 出处 |
|---|---|---|---|
| 1 | Claude Code | `CLAUDE.md` | https://docs.anthropic.com/claude-code |
| 3 | Cursor | `.cursorrules` | https://cursor.com/help/customization/rules |
| 11 | Windsurf | `.windsurfrules` | https://docs.windsurf.com/windsurf/cascade/rules |
| 12 | GitHub Copilot | `.github/copilot-instructions.md` | https://docs.github.com/en/copilot |

### 目录型（wrapper 文件）

| 编号 | Agent | 路径 | 出处 |
|---|---|---|---|
| 4 | Cursor（新版） | `.cursor/rules/00-project-entry.mdc` | https://cursor.com/help/customization/rules |
| 5 | Qoder | `.qoder/rules/00-project-entry.md` | https://qoder.mintlify.app/user-guide/rules |
| 6 | Trae | `.trae/rules/00-project-entry.md` | https://docs.trae.cn/ide/rules |
| 7 | CodeBuddy | `.codebuddy/rules/project-entry/RULE.mdc` | https://www.codebuddy.cn/docs/ide/User-guide/Rules |

**换工具不用重配**：今天用 Cursor，明天换 Qoder，后天换 Claude Code，规则都在。脚本建的入口文件是幂等的，随时可重跑。

## 目录结构

```
vibe-rules/（你 clone 到的任意路径）
├── README.md              # 本文件（agent 第一读这个）
├── global/                # 通用规范（开源部分）
│   ├── iron-rules.md      # 六条铁律展开
│   ├── coding-principles.md  # 四原则 + 七步决策梯子
│   ├── writing-for-agents.md  # 怎么给 agent 写文档
│   ├── git-workflow.md    # 分支/commit/merge
│   ├── testing.md         # 测试要求
│   ├── security.md        # 安全底线
│   └── anti-patterns.md  # 踩坑记录
├── personal/              # 【你的沉淀】个人偏好和记忆点
│   ├── preferences.md     # 跨项目通用的开发偏好
│   ├── memory.md         # 跨项目踩坑和经验
│   └── notes.md          # 随手记
├── languages/             # 按技术栈
│   ├── java.md  python.md  nodejs.md  vue.md  react.md
├── skills/                # 可复用工作流（你自己加的也放这）
├── projects/              # 项目专属沉淀
│   └── <项目名>/          # 每个项目一个目录
├── inbox/                 # 还没归类的灵感/素材，定期 review 转正
├── templates/AGENTS.md    # 新项目的 AGENTS.md 模板
├── tests/                 # 端到端冒烟测试（smoke.sh + smoke.ps1）
└── scripts/               # 安装/迁移/验证脚本（sh + ps1 双份）
```

## 日常怎么沉淀

开发过程中积累的东西，按类型放：

| 类型 | 放哪 | 例子 |
|---|---|---|
| 跨项目通用的踩坑 | `personal/memory.md` | "Java 序列化要注意..." |
| 个人开发偏好 | `personal/preferences.md` | "函数名用动词开头" |
| 新项目或新发现的工作流 | `skills/` | "code-review 流程" |
| 某个项目特有的坑 | `projects/<项目名>/` | "这个项目的缓存策略" |
| 还没想好归哪 | `inbox/` | 稍后再整理 |

## 项目间迁移

把 A 项目沉淀好的内容迁到 B 项目：

**macOS / Linux：**
```bash
/path/to/vibe-rules/scripts/migrate.sh 旧项目slug 新项目slug
```

**Windows（PowerShell）：**
```powershell
pwsh C:\path\to\vibe-rules\scripts\migrate.ps1 旧项目slug 新项目slug
```

脚本会：
- 目标没有的文件：直接复制
- 目标已有但内容不同：diff 后让你选（覆盖/跳过/查看差异）
- 不会静默覆盖

## 验证安装

随时检查项目是否正确接入：

**macOS / Linux：**
```bash
/path/to/vibe-rules/scripts/verify.sh /path/to/project
```

**Windows（PowerShell）：**
```powershell
pwsh C:\path\to\vibe-rules\scripts\verify.ps1 C:\path\to\project
```

## 改了脚本先跑冒烟测试

这个库的安装/卸载/迁移是端到端的，改脚本前先跑一遍：

**macOS / Linux：**
```bash
bash tests/smoke.sh          # bash 版；Windows 上可用 Git Bash 跑
```

**Windows（PowerShell）：**
```powershell
pwsh tests\smoke.ps1
```

它会在临时目录里真实地装一遍、重装一遍、搬个家、再卸干净：幂等、已有 AGENTS.md、
空 AGENTS.md、旧版模板迁移、`--all`、`--copy`、无效编号、带空格路径，bash 版目前 58 项断言（会随测试增长），
PS 版覆盖 Windows 侧同类关键路径。改完 PR 前必须全绿。

CI（`.github/workflows/smoke.yml`）会跑三档：

| 环境 | 为什么 |
|---|---|
| Ubuntu + bash 5 | Linux 主路径 |
| macOS + 系统自带 bash 3.2 | 拦过 `$var` 后面跟全角字符导致 `unbound variable` 那类崩溃 |
| Windows + pwsh | PowerShell 脚本（symlink 权限、`../AGENTS.md` 相对路径这些只在 Windows 才真出问题） |

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
- 不确定本库是否已有规则时，用 Grep/Glob 搜规则库根目录（位置见 `AGENTS.md` 顶部的 vibe-rules 引用块）

## License

MIT

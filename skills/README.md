# Skills 目录说明

> Skill = 一个可复用的工作流。不是教程，不是知识条目，而是"遇到 X 场景，按 Y 步骤做，达到 Z 标准"。

## 什么时候该在这里加 skill

- 你已经在两个以上项目里手动走过一遍同样的流程。
- 你发现自己每次都要重新告诉 agent 同样的检查清单。
- 某个坑踩过两次以上。

**不要**把语言知识点、API 文档放这里——那些属于 `languages/`。

## 一个 skill 的标准结构

```
skills/<skill-name>/
  SKILL.md        # 唯一必需文件
  README.md       # 可选，给人看的背景
  examples/       # 可选，示例输入输出
  scripts/        # 可选，可执行脚本
```

## SKILL.md 模板

```markdown
---
name: <skill-name>
description: <一句话说明什么时候该用这个 skill>
when_to_use:
  - <触发场景 1>
  - <触发场景 2>
applies_to: [java, python, nodejs, vue, react]  # 或 all
---

# <Skill 标题>

## 触发条件
<明确写出：用户说什么、什么任务下应该自动加载这个 skill。不要让 agent 猜。>

## 步骤
1. ...
2. ...
3. ...

## 验收标准（全部满足才算完成）
- [ ] ...
- [ ] ...

## 常见坑
- ...
```

## 为什么要有 frontmatter

- Qoder、Trae、CodeBuddy 都支持 frontmatter 触发（`always_on` / `model_decision` / `glob`）。
- 这个文件里的 frontmatter 是给这些 IDE 用的；纯 markdown 部分对所有 agent 都可读。
- 不要在正文里写依赖特定 agent 的私有语法。

## 现有 skills

**需求 → 设计 → 实现（按顺序用）：**
- `brainstorming/` —— 动手前把需求聊清楚，三档分级（spike / bounded / architectural）
- `writing-plans/` —— 多步任务写实现计划，任务切到 2-5 分钟一步
- `test-driven-development/` —— RED-GREEN-REFACTOR，先写失败测试

**问题处理：**
- `systematic-debugging/` —— 本地/通用调试，四阶段找根因，3 次失败质疑架构
- `debug-production/` —— 线上问题排查（区别于本地调试）

**交付前：**
- `code-review/` —— 提交前自审
- `pre-commit-check/` —— commit 前必跑项

**跨会话：**
- `handoff/` —— 换 agent / 新开会话前，写紧凑交接文档

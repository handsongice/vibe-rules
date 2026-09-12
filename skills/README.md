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
  SKILL.md            # 唯一必需文件
  agents/openai.yaml  # 插件 UI 元数据：display_name / short_description / default_prompt
  references/         # 可选，按需加载的长文档
  scripts/            # 可选，可执行脚本
```

`agents/openai.yaml` 里的 `default_prompt` 必须带 `$<skill-name>`，否则在 agent 的
skill 列表里点名调用会失灵；`scripts/validate-package.sh` 会检查这一条。

## SKILL.md 模板

```markdown
---
# 标准字段只有 name + description：description 要写清"什么时候用"，agent 靠它决定加不加载
name: <skill-name>
description: <一句话说明什么时候该用这个 skill>
metadata:
  short-description: <UI 里显示的一句话，10-20 字>
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

- `name` + `description` 是 agent skill 的通用标准（Codex / Claude Code 都认），
  description 决定这个 skill 什么时候被选中加载。
- `metadata.short-description` 是 UI 里显示的一句话，不影响触发判断。
- 触发条件的正文写在 `SKILL.md` 的「触发条件」一节；不要在 frontmatter 里塞私有语法。

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

**前端视觉：**
- `frontend-taste/` —— 做落地页/作品集/营销页时，避免 AI 塑料感（黑名单 + 自检表）

**文字表达：**
- `plain-writing/` —— 写 README/技术文档/PR/博客时去 AI 味，写得像人话

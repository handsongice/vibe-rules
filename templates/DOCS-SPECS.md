# 设计文档（specs）

> 这个目录放 **@SLUG@ 的设计文档（spec）**：动手改架构之前，把「要做什么、为什么这么做、边界在哪」写清楚。
> 文件由 vibe-rules 的 `install.sh` 只在**不存在时**建档，之后归项目所有，随便改。
> 配套：`docs/plans/`（实现计划）；写法见规则库的 `skills/brainstorming/SKILL.md`。

## 什么时候写

- 新项目、新子系统、改组件之间的组合方式、改别人依赖的接口 → **必须写**
- 有界改动（加个 flag、改一条已有流程）→ 不用写，在对话里说清楚、拿到批准就行
- 拿不准档位时走更重的那档（`skills/brainstorming` 有完整的判档表）

## 命名与位置

```
docs/specs/YYYY-MM-DD-<topic>.md
```

写完 commit 进仓库——spec 是给下一个 agent（和三个月后的你）看的，不是聊天记录。

## 状态行（写在文件开头）

```markdown
> status: active · updated: 2026-09-13
```

| status | 意思 |
|---|---|
| `draft` | 还在讨论，**别照着做** |
| `active` | 正在做 / 准备做 |
| `done` | 已实现（文件末尾补一行「实现见 <commit/PR>」） |
| `abandoned` | 放弃（补一句为什么，省得下个人再试一遍） |

状态行是给下一个 agent（和三个月后的你）看的路标：**`done` 的文档不用重读全文**，
直接看实现就行；`active` 很长时间没动，就该重新评估。改状态时顺手把 `updated` 也改掉。

查状态 / 找过期文档 / 归档已完成（脚本在 vibe-rules 规则库里，不在项目副本里）：

```bash
bash <vibe-rules>/scripts/docs-status.sh .              # 汇总
bash <vibe-rules>/scripts/docs-status.sh . --stale 30   # 列出超 30 天没动且没完成的
bash <vibe-rules>/scripts/docs-status.sh . --archive    # 把 done/abandoned 移进 archive/
```

## 结构

```markdown
# <主题> 设计

> status: draft · updated: YYYY-MM-DD

**目标**：一句话说清要解决什么问题
**非目标**：明确不做什么（防范围膨胀）
**成功标准**：怎么判断做成了（可验证的条件）

## 背景与约束
（现状、技术栈版本下限、平台要求、合规/性能约束）

## 候选方案
### 方案 A：<名字>
- 做法：
- 优点：
- 缺点：

### 方案 B：<名字>
...

**选择**：选哪个 + 为什么（一句话）

## 设计
（分段写：数据流 / 模块边界 / 接口签名 / 错误处理 / 迁移方式）

## 风险与回滚
（哪里可能炸、怎么发现、怎么退回）
```

## 自审（写完自己过一遍）

- [ ] 占位符扫一遍：没有 "TBD"、"稍后补充"、"加合适的错误处理"
- [ ] 前后一致：术语、函数名、字段名不打架
- [ ] 范围没过大：一个 spec 对应一个能独立交付的东西
- [ ] 没有歧义：每句话只有一种读法

发现就改，不用再走一轮评审。

## 写完下一步

让用户 review spec → 批准后进 `skills/writing-plans`，把 spec 拆成 `docs/plans/` 里的实现计划。

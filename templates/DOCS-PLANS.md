# 实现计划（plans）

> 这个目录放 **@SLUG@ 的实现计划（plan）**：把 spec 拆成"照着做就行"的任务清单。
> 文件由 vibe-rules 的 `install.sh` 只在**不存在时**建档，之后归项目所有，随便改。
> 配套：`docs/specs/`（设计文档）；写法见规则库的 `skills/writing-plans/SKILL.md`。

## 什么时候写

- 多步任务、动代码前、需要别人（或别的 agent）照着执行 → 写
- 20 行以内的改动、一次 spike → 不写

## 命名与位置

```
docs/plans/YYYY-MM-DD-<feature>.md
```

commit。计划要能被一个**不了解这个代码库**的执行者照着做完。

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
# <功能名> 实现计划

> status: draft · updated: YYYY-MM-DD

**目标**：一句话
**架构**：2-3 句
**技术栈**：关键技术/库
**Spec**：docs/specs/YYYY-MM-DD-xxx.md

## 全局约束
（从 spec 抄：版本下限、依赖限制、命名规则、平台要求，一行一条，原值照抄）

---

### Task N: <组件名>

**文件：**
- 新建：`exact/path/to/file.py`
- 修改：`exact/path/to/existing.py:123-145`
- 测试：`tests/exact/path/test.py`

**接口：**
- 消费：用到前面任务产出的什么（精确签名）
- 产出：后面任务要靠本任务的什么

- [ ] **Step 1: 写失败测试**（贴实际测试代码）
- [ ] **Step 2: 跑测试确认失败**（命令 + 预期 FAIL 原因）
- [ ] **Step 3: 写最小实现**（贴实际代码）
- [ ] **Step 4: 跑测试确认通过**
- [ ] **Step 5: commit**（贴 git 命令和 message）
```

## 硬要求

- **一个任务 = 一个独立可测、值得一次 review 门的最小单元**；setup/配置/脚手架折进需要它的那个任务
- 每个步骤是一个 2-5 分钟的动作，写清命令和预期结果
- **禁止占位符**："TBD"、"加合适的错误处理"、"为 XX 写测试"（却不贴代码）、"类似 Task N"
- 引用到的类型/函数必须在某个任务里定义过

## 自审（写完自己过一遍）

- [ ] spec 里每条要求都能指到某个任务
- [ ] 红旗词扫一遍，发现就修
- [ ] 类型/命名前后一致（Task 3 叫 `clearLayers()`，Task 7 不能写成 `clearFullLayers()`）
- [ ] 每个任务都遵守了头部的全局约束

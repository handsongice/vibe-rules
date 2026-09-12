# Git 工作流

## 分支
- `main` / `master`：始终可部署。
- 功能分支命名：`feat/<短描述>`、`fix/<短描述>`、`chore/<短描述>`、`refactor/<短描述>`，全小写，用连字符。
- 不要从一个 feature 分支再拉一个 feature 分支；保持线性。

## Commit message
用 Conventional Commits：

```
<type>(<scope>): <subject>

<body>
```

- `type`：`feat` / `fix` / `docs` / `style` / `refactor` / `test` / `chore` / `perf` / `ci`
- `scope`：模块名（如 `auth`、`checkout`、`ui`），可省。
- `subject`：中文，一句话，不超过 50 字，结尾不加句号。
- `body`：写"为什么这么改"，不是"改了什么"（diff 已经说明了）。
- 一个 commit 只做一件事。超过 200 行 diff 就要考虑拆。

**反例（禁止）：**
- `update` / `fix bug` / `修改` / `wip` / `asdf`
- 把"加了一个按钮 + 升级了 lodash + 改了 CI"塞进一个 commit

## 提交前
- 见 `skills/pre-commit-check/SKILL.md`。
- `git status` 里不该有意外的文件（构建产物、`.env`、日志）。

## 不要做的事
- 不要 `git add .` 然后 commit，除非你确认过 `git status`。
- 不要在别人没让你 `git push` 的时候 push。
- 不要 `git commit --amend` 已经 push 到远端的 commit。
- 不要 rebase 别人正在用的共享分支。

## 解 merge / rebase 冲突

1. **先看状态**：`git status`、冲突文件、相关的 commit 历史。
2. **找源头**：每个冲突块背后为什么改？读 commit message、PR、issue。理解双方意图，不要凭代码猜。
3. **逐块解决**：尽量保留双方意图。真冲突时，按本次 merge 的目标选一边，并在 commit message 里记下 trade-off。**不要凭空发明新行为。**
4. **跑完自动化检查**：typecheck → 测试 → lint/format。merge 弄坏的都修。
5. **收尾**：`git add` + commit；rebase 的话继续 `git rebase --continue` 直到全部完。

**不要**：直接 `--abort` 就算了；不要选一边然后忽略另一边的意图；不要把冲突解决了但不跑测试就 commit。

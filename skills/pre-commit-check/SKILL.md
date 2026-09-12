---
name: pre-commit-check
description: 在 git commit 之前运行的检查清单，确保不把半成品提交进去
metadata:
  short-description: 提交前必跑检查清单
---

# Pre-commit 检查

## 触发条件
任何时候要执行 `git commit` 之前，必须按本清单走一遍。

## 步骤
1. **看一眼将要提交什么**：`git status` 和 `git diff --stat`。如果有意外文件（构建产物、`.env`、日志、IDE 配置），先处理。
2. **跑测试**：
   - Java：`./mvnw test` 或 `./gradlew test`
   - Python：`pytest -x -q`
   - Node：`pnpm test`（或 `npm test`，看项目 lock）
   - 没测试套件：跑 lint / typecheck（`tsc --noEmit` / `ruff check .`）
3. **grep 一遍敏感信息**：
   ```bash
   git diff --cached | grep -iE "(api[_-]?key|secret|password|token|AKIA|sk-)"
   ```
   命中要确认是不是硬编码。
4. **写 commit message**：按 `global/git-workflow.md` 的 Conventional Commits 规范。
5. **commit，但不要 push**。push 等用户明确说。

## 验收标准
- [ ] 测试全绿（或用户明确豁免）
- [ ] diff 里没有敏感信息
- [ ] commit message 符合规范
- [ ] `git status` 干净，没有误提交的文件

## 常见坑
- 改了代码但忘了重新生成 lock 文件（`pnpm install` / `pip install` 后没 commit lock）。
- 把调试用的 `console.log` / `print()` / `System.out.println` 留在代码里。
- 一次 commit 里混了多个不相关改动——拆。

# 测试要求

> 执行流程见规则库的 `skills/test-driven-development/SKILL.md`（RED-GREEN-REFACTOR，规则库路径见 `AGENTS.md` 顶部引用块）。本文件只讲测试本身的规范。

## 最低标准（按项目成熟度）
- **新功能**：必须有单元测试覆盖核心逻辑。边界条件（空、null、超长、非法输入）至少各一个 case。
- **修 bug**：先写一个复现这个 bug 的失败测试，再修。这是硬性要求——没复现测试的 bug fix 不算完成。
- **老项目没测试**：不要一口气补全套。只在你本次改到的函数周围补测试。
- **改完跑全量测试**，哪怕你觉得"只改了一行"。

## 测试代码规范
- 测试命名：`methodName_Condition_Expected`，例如 `getUser_WhenUserNotFound_ReturnsNull`（Java）/ `test_user_not_found_returns_none`（Python/pytest）/ `getUser_whenNotFound_returnsNull`（JS/Vitest/Jest）。
- 一个测试只断言一件事。一个测试超过 5 个 assert 就要拆。
- 不要在测试里 `sleep()`、不要依赖真实网络、不要依赖本地文件状态。用 mock/fixture。
- 测试之间不能有顺序依赖。可以单独跑任何一个测试文件。

## 各栈常用测试工具（详见 languages/）
- Java: JUnit 5 + Mockito（Spring Boot 用 `@SpringBootTest` 慎用，慢）
- Python: pytest + pytest-cov；mock 用 `unittest.mock`
- Node/TS: Vitest 优先；React Testing Library；E2E 用 Playwright
- Vue: Vitest + @vue/test-utils

## 覆盖率
- 不要为了凑覆盖率写没意义的测试。
- 新代码行覆盖率 ≥ 70%，核心业务路径 ≥ 90%。
- 覆盖率数字是结果，不是目标。

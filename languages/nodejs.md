# Node.js / TypeScript

## 包管理
- 一律用 **pnpm**。不要 `npm install`，不要 `yarn`，除非项目已有 lock 文件。
- lock 文件必须 commit。
- Node 版本用 `.nvmrc` 或 `engines` 字段锁定。新项目 Node 20 LTS+。

## 项目骨架
- 后端：NestJS / Fastify / Express 三选一。不要在 Express 项目里混 Nest 的装饰器风格。
- 纯库/工具：`src/` + `dist/`，用 tsup 或 tsx 构建。
- 配置文件统一放根目录，不要在 `src/` 里放 config。

## TypeScript 严格度
- `tsconfig.json` 必须开：
  ```json
  {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitReturns": true
  }
  ```
- 不要写 `any`。实在绕不过用 `unknown` + 类型守卫。
- 不要用 `@ts-ignore`，用 `@ts-expect-error`（这样如果错误不存在会报错提醒你删掉注释）。
- `type` 用 interface 还是 type：对象结构用 interface，联合/交叉/工具类型用 type。

## 代码风格
- ESM（`"type": "module"`），不用 CommonJS。
- 错误处理：async 函数要么 throw，要么显式返回 Result 类型，不要 `catch` 后返回 undefined。
- 不要把 secret 写进 `process.env` 后又在代码里到处 `process.env.XXX`，集中一个 `config.ts` 读取并校验（启动时缺变量直接抛错）。

## 测试
- Vitest。不要 Jest（新库）。
- E2E 用 Playwright，不要 Cypress。
- mock 用 `vi.mock()`，不要手搓 monkey patch。

## Agent 高频错误
- 给 CommonJS 项目写 ESM 语法，或反过来。
- 把 `==` 当 `===` 用。
- 在 `useEffect`（如果是 React）/ API route 里做重活但不处理错误。
- 装包时不看版本直接 `latest`，导致 major 版本跳跃。
- 用 `var` 或隐式全局。
- 忘了 `await` promise（类型系统会提醒，agent 经常忽略）。

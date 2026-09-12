# 安全规范

## 输入校验
- 所有外部输入（HTTP 参数、表单、消息队列 payload、文件上传）在入口处校验一次，不要在业务代码里到处判空。
- SQL 用参数化/ORM，禁止字符串拼接。
- Shell 命令拼参数时用数组形式，不用字符串拼接后 `shell=True`。
- 路径拼接用 `pathlib`（Python）/`path.join`（Node），不要手拼字符串防止目录穿越。

## 密钥与配置
- 密钥只从环境变量或密钥管理服务读，**绝不进代码、绝不进 git**。
- 配置分层：`application.yml`（默认）< `application-{env}.yml`（环境）< 环境变量（敏感）。
- `.env*`、`*.local.*`、`application-secret.*` 必须在 `.gitignore`。
- 生成新 token 时，提醒用户去对应平台 revoke 旧的。

## 依赖
- 升级依赖前先看 changelog / release notes，大版本升级必须单独 PR。
- 不要 `npm install` 一个不知名的包就直接用；先看 star 数、最近维护时间、`npm view <pkg>` 看 maintainer。
- 锁文件（`package-lock.json` / `pnpm-lock.yaml` / `poetry.lock` / `Pipfile.lock` / `mvn dependency:tree`）要 commit。

## Web 常见
- 输出到 HTML 前转义，防 XSS。React 默认转义，用 `dangerouslySetInnerHTML` 前必须消毒。
- 鉴权在中间件/拦截器层做，不要在每个 handler 里重复写。
- 错误响应不要把堆栈、SQL、内部路径返回给前端。
- CORS 不要直接 `*`，尤其带 cookie 的时候。

## 给 agent 的自我检查
提交前对照这张表过一遍：
- [ ] 没有硬编码密钥
- [ ] 外部输入有校验
- [ ] SQL/命令是参数化的
- [ ] 错误信息不泄露内部细节
- [ ] 新增依赖你知道它是干什么的

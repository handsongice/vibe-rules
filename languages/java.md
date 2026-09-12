# Java 全家桶

## 项目骨架（Spring Boot 3.x）
- 构建工具：Maven 优先（多数公司存量），新项目可考虑 Gradle Kotlin DSL。**不要在同一个项目里混用 Maven 和 Gradle**。
- 包结构按功能分包，不要按技术分包：
  ```
  com.yourapp.order/
    controller/
    service/
    repository/
    entity/
    dto/
    OrderApplication.java
  ```
- 不要把所有类塞一个 `controller` 包。

## 依赖与版本
- Spring Boot 3.x 要求 JDK 17+。不要写 `javax.*`，用 `jakarta.*`（`javax.persistence` → `jakarta.persistence`）。这是 agent 最容易写错的点。
- 不要手动写版本号，交给 `spring-boot-dependencies` BOM 管理。
- 加新依赖前先 `mvn dependency:tree | grep <artifactId>` 看有没有已存在的。

## 代码风格
- DTO / Entity / VO 分开，不要把 JPA Entity 直接返给前端。
- Service 层接口 + 实现是老规范，新代码如果没有多实现就直接写 class，不要为了"可扩展性"硬加接口。
- 异常：用 `@RestControllerAdvice` 统一处理，不要在每个 controller 里 try-catch 后返回错误 JSON。
- 日志用 SLF4J + Logback，不要 `System.out.println`，不要 `e.printStackTrace()`。
  ```java
  // 正确
  log.error("订单创建失败, orderId={}, userId={}", orderId, userId, e);
  // 错误
  log.error("失败" + e.getMessage());
  ```
- 时间：Java 8+ 用 `java.time`（LocalDateTime / Instant），不要用 `Date` / `SimpleDateFormat`。

## 测试
- 单元测试：JUnit 5 + Mockito，纯 POJO 测试不要加载 Spring。
- 切片测试：`@WebMvcTest`、`@DataJpaTest`，比 `@SpringBootTest` 快很多。
- 真要起容器用 Testcontainers，不要用 H2 假装 MySQL（行为不一致）。

## Agent 高频错误（重点防）
- 把 `javax.*` 包写进 Spring Boot 3 项目 → 编译不过。
- 在事务方法里 catch 了异常又不 rethrow，导致事务不回滚。
- 用 `==` 比较字符串、用 `Integer` 直接 `==` 比较（缓存池问题）。
- 给 `@Autowired` 字段注入而不是构造器注入（无法单测、final 失效）。

# Android（Kotlin 优先）

> 语言层面的约定（命名、异常、集合、并发）跟 `java.md` 共用；本篇只管平台层面的坑。
> 既有 Java 又有 Kotlin 的项目，两个文件都读。

## 项目骨架
- 新代码一律 Kotlin；存量 Java 只在改到它时顺手转 Kotlin，不要为转而转。
- 模块化按需拆：单模块起步，必须拆时按 `:app` / `:core:*` / `:feature:*`，不要一上来铺 20 个模块。
- Gradle 用 Kotlin DSL（`build.gradle.kts`），版本集中在 `gradle/libs.versions.toml`（version catalog），
  不要在模块里逐个写死版本号。
- 包结构按功能分层（`feature/order/` 自带 ui / data / domain），不要按类型铺平（一堆 `adapter/`、`bean/`）。

## SDK 与依赖
- `compileSdk` / `targetSdk` 用当前稳定版；`minSdk` 是产品决策，定了不要随意抬（抬了就是破坏性变更）。
- Compose 用 BOM 统一版本：`implementation(platform("androidx.compose:compose-bom:..."))`，单个 compose 库不写版本。
- 加依赖前先看依赖树：`./gradlew :app:dependencies`；AndroidX 优先，不要再用已废弃的 support 库。
- 新项目默认组合：Compose UI + Hilt + Retrofit/OkHttp + kotlinx.serialization + Room + DataStore + Coil。

## 代码风格
- `val` 优先；状态用 `data class`，互斥状态用 `sealed interface`（Loading / Success / Error），
  不要「四五个布尔值 + null 判断」拼状态。
- 协程：UI 里用 `viewModelScope` / `lifecycleScope`，IO 一律 `Dispatchers.IO`；
  `GlobalScope` 和 `runBlocking` 都不许用（测试除外）。
- Flow：UI 层用 `collectAsStateWithLifecycle()`；一次性事件用 `Channel` / `SharedFlow`，不要拿 LiveData 塞事件。
- 依赖注入用 Hilt：`@HiltViewModel` + `@Inject constructor`，不要在 Activity 里 `new` 仓储/网络层。
- Context：要长期持有就 `applicationContext`；Activity 上下文只在 UI 生命周期内用。
- 主线程不碰 IO / 数据库 / 大 JSON 解析，开发期开 StrictMode 查违规。

## UI（Compose 优先）
- 新界面用 Compose；Compose 项目里别再混 XML 布局，`findViewById` 一律不要，XML 场景用 ViewBinding。
- 状态提升：Composable 只渲染 `UiState` + 抛事件，网络/数据库只在 ViewModel 里调；
  副作用放 `LaunchedEffect` / `rememberCoroutineScope`。
- `LazyColumn` 的 item 要写 `key`；可变列表用 `mutableStateListOf`（`SnapshotStateList`），不要用普通 `List`。
- 高开销计算用 `remember` / `derivedStateOf` 包住，避免无谓重组。
- `@Preview` 用假数据，Preview 里不要依赖真实网络。

## 数据层
- Retrofit + OkHttp（`HttpLoggingInterceptor` 只在 debug 加）+ kotlinx.serialization；
  DTO 与 domain model 分开，不要一个类从接口解析用到 UI。
- Room：查询返回 Flow、写入用挂起函数；简单键值对用 DataStore，不要 SharedPreferences。
- 网络/数据库失败用 `Result` 或 sealed 类型往上传，不要在 UI 层 catch 所有异常然后 Toast。

## 测试
- 单元测试：JUnit4 + MockK + `kotlinx-coroutines-test`（`runTest`）；Flow 断言用 Turbine。
- UI 测试：Compose UI Test（`createComposeRule`）；Espresso / UI Automator 只留最关键的跨页面用例。
- 测试不依赖真实网络和设备状态；假数据放 test fixtures。

## 性能与稳定性
- 主线程只做 UI；网络、JSON、数据库、Bitmap 解码全部下放。
- 内存泄漏：单例/长生命周期对象里不存 Activity / View；Fragment 的 ViewBinding 在 `onDestroyView` 置空；
  监听器、回调要注销；开发期挂 LeakCanary。
- ANR：主线程不 `Thread.sleep`、不同步 IO；`SharedPreferences.commit()` 改 `apply()`。
- 启动：延后初始化、懒加载；大项目上 Baseline Profile。
- release 构建开 R8（`minifyEnabled true` + resource shrinking），混淆规则写 `proguard-rules.pro` 并实测验证。

## 权限与兼容
- 调高版本 API 必须 `Build.VERSION.SDK_INT` 判断或 `@RequiresApi`，不要无条件用（minSdk 设备直接崩）。
- targetSdk 升级要过一遍行为变更：13+ 通知权限 `POST_NOTIFICATIONS`、14+ 前台服务 `foregroundServiceType`、
  存储走 Scoped Storage（MediaStore / SAF），不要再用 `WRITE_EXTERNAL_STORAGE`。
- 运行时权限按需申请，拒绝后要有降级路径；不要一启动就把权限全申请一遍。
- 外部传入的数据（Intent / 深链 / 通知跳转）一律校验，隐式 Intent 不要透传敏感参数。

## 发布
- `versionCode` 单调递增，`versionName` 语义化；签名 keystore 和口令不进仓库（环境变量或本机
  `keystore.properties` + gitignore）。
- 上架产物用 AAB；`google-services.json` 里的密钥值不要在仓库里暴露。
- 线上崩溃/性能靠监控（Crashlytics / Sentry 这类），不要等用户反馈。

## Agent 高频错误（重点防）
- 主线程做网络/数据库/JSON，或包一层 `runBlocking` 假装解决。
- `GlobalScope.launch` 起协程；ViewModel 里存 Activity / View 导致泄漏。
- 用 `collectAsState()` 而不是 `collectAsStateWithLifecycle()`（退到后台还在收）。
- 用 `!!` 硬解包、到处 `lateinit`；Kotlin 里还写 `if (x != null) x!!.foo()` 这种双保险。
- 不做 `Build.VERSION.SDK_INT` 判断就调高版本 API；忘加运行时权限就用受保护接口。
- Compose 里直接改普通 `List` 期待刷新，`LazyColumn` 忘写 `key`，或在 Composable 里直接发请求。
- Gradle 里逐个写死 AndroidX / Compose 版本，不用 BOM 和 version catalog。
- 把 keystore、`google-services.json` 的敏感值提交进仓库。

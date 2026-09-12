---
name: frontend-taste
description: 做 landing page / portfolio / marketing 页 / redesign 时，避免 AI 生成前端那种千篇一律的塑料感
when_to_use:
  - 做落地页、作品集、品牌页、营销站
  - 改现有站点的视觉
  - 用户说"做个页面"、"搞个官网"
not_for: dashboard、数据表格、多步表单、后台管理系统（这些用官方设计系统，不用这个）
applies_to: [vue, react]
---

# 反 AI 塑料感前端

> 来源：leonxlnx/taste-skill（MIT），按中文精简。核心是：LLM 一写前端就长一个样，这个 skill 负责把那些"一眼 AI"的俗套砍掉。

## 0. 先读题，别上来就写

写代码前，先说一句"设计判读"：

> "这是一个给谁看的什么页面，走什么视觉语言。"

例：
- "B2B SaaS 落地页，给技术买家看，Linear 式极简，Tailwind + Geist 字体。"
- "设计师作品集，给招聘方看，编辑式排版 + 大字标题。"

拿不准就问**一个**问题（不要一次抛十个）："要偏 Linear 干净，还是偏 Awwwards 实验感？"

## 1. 三个旋钮

定了判读之后，心里设三个值（1-10）：

| 旋钮 | 1 | 10 |
|---|---|---|
| **VARIANCE**（变化度） | 完美对称、整齐网格 | 不对称、乱中有序 |
| **MOTION**（动效强度） | 纯静态 | 电影级滚动叙事 |
| **DENSITY**（密度） | 画廊式大留白 | 驾驶舱式塞满数据 |

- 落地页默认：VARIANCE 7 / MOTION 6 / DENSITY 4
- 极简/线性风：5 / 3 / 2
- 创意/agency/Awwwards：9 / 8 / 3
- 政务/可信/无障碍优先：3 / 2 / 5
- 后台/dashboard：**不要用这个 skill**

## 2. AI 默认审美黑名单（最重要）

下面这些是 LLM 一写前端就会犯的俗套，**除非用户明确要，否则禁止**：

### 颜色
- ❌ AI 紫渐变、紫色按钮发光、蓝紫 mesh 背景
- ❌ 一个页面里混多种 accent 色。**一个页面一个 accent**，全页用到底
- ❌ 纯 `#000` 和纯 `#fff`。用 zinc-950 当黑、off-white 当白
- ❌ 高端消费品默认配色：米色/奶油底 + 黄铜/赭石/牛血红 + 深棕文字（`#f5f1ea`、`#b08947`、`#1a1714` 这一族）。这是 LLM 做"高端手工感"的默认答案，做出来千篇一律。换冷灰、深绿、钴蓝+米白、赤陶+板岩等替代。

### 字体
- ❌ **Inter 当默认字体**。用 Geist、Outfit、Satoshi、Cabinet Grotesk，或者项目已有字体
- ❌ **衬线字体当默认**。"创意/编辑感"≠一定要衬线。除非品牌明确指定，或真的是编辑/奢侈/出版类项目，否则用 sans
- ❌ 特别点名：**Fraunces 和 Instrument Serif** 是 LLM 最爱的两个展示衬线，默认禁止
- ❌ 在 sans 标题里塞一个 serif 词做"强调"。要用粗体/斜体同字体强调，不要混字体家族

### 布局
- ❌ 三个等大 feature card 一排
- ❌ 居中 hero 下面接深色 mesh
- ❌ 连续三个左右图文 zigzag。最多两个，第三个换版式
- ❌ 每段上面都加 eyebrow（小写字距拉开的小标签）。**最多每 3 段一个 eyebrow**，数 `uppercase tracking` 出现次数
- ❌ "左大标题 + 右小段说明"的分栏标题。改成上下堆叠
- ❌ 整个页面一个布局重复 8 次。8 段至少 4 种布局
- ❌ bento 格里全是白卡+文字。至少 2-3 个格子有真实图片/渐变/纹理
- ❌ `h-screen`。用 `min-h-[100dvh]`（避免 iOS 地址栏跳动）
- ❌ `w-[calc(33%-1rem)]` 这种 flex 百分比。用 CSS Grid

### 文案（AI 味重灾区）
- ❌ **em-dash（—）完全禁止**。标题、正文、按钮、alt text 里一个都不许有。用普通连字符 `-` 或句号
- ❌ "Elevate / Seamless / Unleash / Next-Gen / Revolutionize" 这种空话动词
- ❌ "Quietly in use at"、"Field notes"、"On our desks" 这种故作文艺的标签
- ❌ "Acme / Nexus / SmartFlow / Cloudly" 这种假公司名
- ❌ "John Doe / Sarah Chan" 这种假名
- ❌ "99.99% / 4.1×" 这种编出来的精确数字。要么有真实出处，要么标 mock
- ❌ 版本号 footer（`v1.4.2`、`Build 0048`）——那是 CLI 工具的事，不是落地页
- ❌ "LIS 14:23 · 18°C" 这种地点时间天气条
- ❌ "Scroll ↓"、"向下滚动探索" 这种滚动提示
- ❌ "V0.6 / BETA / INVITE-ONLY" 版本号塞 hero 里（除非就是发布会）
- ❌ "001 · Capabilities" 这种带编号的 eyebrow
- ❌ hero 下面塞 "TRUSTED BY" logo 墙——logo 墙放 hero 下面独立一段，不要挤在 hero 里

### Hero 区
- hero 一屏内放下：标题最多 2 行，副文案 ≤ 20 词且 ≤ 4 行，CTA 不滚动可见
- hero 最多 4 个文本元素：eyebrow（可选）+ 标题 + 副文案 + CTA
- hero 顶部 padding ≤ `pt-24`。再多就是 bug
- CTA 按钮文字一行放下，桌面端不换行。主 CTA 最多 3 个词
- 两个 CTA 不要同一个意图："联系我们"和"开始项目"其实是一个意思，选一个全页统一

### 动效
- ❌ 每个 card 都无限循环动画。信息性段落就静止
- ❌ `window.addEventListener('scroll')`。用 Motion 的 `useScroll`、IntersectionObserver 或 CSS scroll-driven animation
- ❌ 用 `useState` 跟鼠标位置/滚动进度（每帧重渲染）。用 motion value
- 动效必须有理由：层级/叙事/反馈/状态变化。"看起来酷"不是理由
- 动了就要真动。声称 MOTION 6 但页面一动不动 = 失败
- `prefers-reduced-motion` 必须降级

### 图片与素材
- ❌ div 拼的假截图（假任务列表、假终端、假 dashboard）。这是 LLM 头号 Tell
- ❌ 手搓 SVG 图标。用 Phosphor / HugeIcons / Radix / Tabler
- ❌ 纯文字"极简"页面。再极简也要 2-3 张真实图片
- 真实图片优先：image-gen > picsum.photos seed > 明确标注的占位符

### 其他硬规则
- 一个项目一个设计系统。不要 Material + shadcn 混用
- 有官方设计系统就用官方包（Fluent / Carbon / Polaris / Primer / shadcn/ui），不要手搓它的 CSS
- 一个页面一个圆角系统。全直角 / 全 12-16px / 全 pill，定了就统一
- 按钮对比度 WCAG AA（正文 4.5:1，大字 3:1）
- 一项目一色系，不要冷暖灰混着用
- 整页一个主题（亮/暗/跟随系统），不要中段突然翻个色

## 3. 交付前自检

跑下面这张表，任何一项 fail 就不算完：

- [ ] 开头说了设计判读那句话
- [ ] **全页 0 个 em-dash**（搜一遍 `—` 和 `–`）
- [ ] 一个 accent 色、一个圆角系统、一个主题
- [ ] hero 一屏放下，CTA 不换行
- [ ] eyebrow 数 ≤ ceil(段数/3)
- [ ] 没有三个等大 card、没有连续 3 个 zigzag
- [ ] 没有 div 假截图、没有手搓 SVG 图标
- [ ] 按钮对比度过 WCAG AA
- [ ] 动效都有理由，reduced-motion 降级了
- [ ] 没有 AI 紫、没有 Inter 默认、没有 Fraunces/Instrument Serif
- [ ] 没有 "Quietly in use at"、"Field notes"、版本号 footer、地点天气条
- [ ] 图片是真的，不是占位 div
- [ ] 亮/暗两种模式都看过
- [ ] 移动端布局明确 collapse（不是"Tailwind 自己会处理"）

## 4. 什么时候不要用这个 skill

- 后台、dashboard、admin、数据密集型界面 → 用官方设计系统（Fluent/Carbon/Arressian/Polaris）
- 多步表单/wizard
- 代码编辑器类界面
- 这些场景应用这个 skill 的话，反而会做出"过度设计的后台"。

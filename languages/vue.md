# Vue 3

## 版本与构建
- Vue 3 + Vite，不要 Vue 2。不要 Webpack。
- 状态管理：Pinia，不要 Vuex。
- 路由：Vue Router 4。
- 语言统一用 `<script setup lang="ts">`，不要 Options API，不要混用。

## 项目骨架
```
src/
  components/      # 纯展示组件
  composables/     # use* 组合式函数
  stores/          # Pinia
  views/           # 路由级页面
  api/             # 接口层
  types/
  utils/
```

## 代码风格
- Props 必须带类型和默认值：
  ```ts
  const props = defineProps<{
    size?: 'sm' | 'md' | 'lg'
    items: Item[]
  }>({
    size: { default: 'md' }
  })
  ```
- Emits 用类型声明：`const emit = defineEmits<{ (e: 'change', v: string): void }>()`。
- 不要在模板里写复杂逻辑，抽到 computed。
- `v-for` 必须有稳定的 `:key`，不要用 index。
- 避免在 `v-for` 里用 `v-if`（Vue 3 里 v-if 优先级更高，行为反直觉）。

## 样式
- 用 UnoCSS / Tailwind 二选一。不要 element-ui/scoped css/tailwind 混用。
- scoped 样式只在必要时用；全局 token 放 `:root` 或 CSS variables。

## Agent 高频错误
- 写 Vue 2 的 Options API 或 `this.$xxx`。
- 在 `ref()` 上漏 `.value`（在 JS 逻辑里）。
- 把异步操作放 `onMounted` 里但不处理错误/loading。
- 直接修改 props（props 是只读的）。
- 忘记组件名/文件名用 PascalCase（文件系统上），但模板里用 kebab-case。
- Pinia store 里直接改 state 而不是用 action（小项目可直接改，大项目不行——看项目约定）。

# React

## 版本与构建
- React 18+。新项目直接 Next.js (App Router) 或 Vite + React。
- 不要 React 16/17。不要 Class Component（除非改老代码）。
- 不要在老的 Vite SPA 项目里突然引入 Next.js 路由。

## 代码风格
- 函数组件 + Hooks。
- 状态：
  - 本地 UI 状态：`useState`
  - 服务端状态：TanStack Query（不要手写 fetch + useState + useEffect 三件套）
  - 跨组件全局：Zustand 优先；Context 只用于真正需要广播的低频值
  - 表单：React Hook Form，不要自己管每个字段
- Effects：
  - 能用 derived state 算的就不要 `useEffect` + setState 同步。
  - `useEffect` 里的副作用必须能 cleanup（订阅、定时器、abort）。
  - 依赖数组要写全，不要用 eslint-disable 糊过去。
- key 用稳定 id，不要用 index。
- 不要在 render 里创建对象/函数再传给 memo 组件导致失效。

## Next.js (App Router)
- Server Components 是默认。需要交互的组件加 `"use client"`。
- 数据获取直接在 Server Component 里 `async function Page()`，不要 `useEffect` + fetch。
- Route Handler 里不要直接返回裸 Error 对象，要有统一错误处理。

## 样式
- Tailwind 优先。不要 CSS-in-JS（styled-components/emotion）除非项目已有。
- className 拼接用 `clsx` 或 `tailwind-merge`，不要字符串模板。

## Agent 高频错误
- 写 Class Component 或老的 HOC 风格。
- 在 useEffect 里 fetch 但不处理 abort/竞态（用 TanStack Query 或 AbortController）。
- 把对象/数组直接当 useEffect 依赖（每次渲染都变）。
- 直接修改 state（`obj.x = 1`），必须 setState 新对象。
- Next.js 里把 `"use client"` 加在最顶层导致整个树都变成客户端。
- 用 `<img>` 而不是 `next/image`（Next 项目里）。
- 在事件处理函数里写 async 但不 catch 错误。

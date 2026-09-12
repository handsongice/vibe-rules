---
name: test-driven-development
description: 写新功能或修 bug 时，先写失败测试再写实现代码
metadata:
  short-description: 先写失败测试再写实现
---

# TDD（测试驱动开发）

## 铁律

```
没写过一个失败的测试之前，不写生产代码。
```

写完实现才想起来写测试？**把实现删了重来**。不要"留着当参考"、不要"边写测试边改"、不要"参考一下"。删掉就是删掉，从测试重新写。

例外（要先问用户）：一次性原型、生成代码、配置文件。

想"这次先跳过 TDD"？停下来——这就是合理化借口。

## Red → Green → Refactor

### RED：写一个失败测试

一个最小测试，描述应该发生什么：

```typescript
test('失败操作会重试 3 次', async () => {
  let attempts = 0;
  const operation = () => {
    attempts++;
    if (attempts < 3) throw new Error('fail');
    return 'success';
  };

  const result = await retryOperation(operation);

  expect(result).toBe('success');
  expect(attempts).toBe(3);
});
```

要求：
- 一个测试只测一个行为。名字里有"and"就拆。
- 名字描述行为，不叫 `test1` / `works`。
- 测真实代码行为，不要只测 mock 的行为。

### 确认 RED：看它真的失败（必做，不许跳）

```bash
npm test path/to/test.test.ts
```

确认：
- 测试是**失败**（不是报错）
- 失败信息是你预期的
- 失败原因是"功能还没实现"，不是 typo

**测试直接过了？** 那你在测已有行为，测试写错了。
**测试报错？** 先修到它正确地失败。

### GREEN：写最小实现

写最简单的让测试通过的代码。不要加功能、不要顺手重构、不要"改进"。

```typescript
async function retryOperation<T>(fn: () => Promise<T>): Promise<T> {
  for (let i = 0; i < 3; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i === 2) throw e;
    }
  }
  throw new Error('unreachable');
}
```

不要写：可选参数、backoff 策略、onRetry 回调——YAGNI。

### 确认 GREEN：看它真的通过（必做）

```bash
npm test path/to/test.test.ts
```

确认：
- 这个测试过了
- **其他测试也都还过**
- 输出干净（没 warning、没 error）

挂了？改代码，不要改测试。其他测试挂了？立刻修。

### REFACTOR：清理

绿了之后才清理：去重、改名字、抽 helper。**保持绿**，不加新行为。

### 重复

下一个行为，再来一轮 RED。

## 修 bug 的流程

Bug：空邮箱被接受。

RED：
```typescript
test('拒绝空邮箱', async () => {
  const result = await submitForm({ email: '' });
  expect(result.error).toBe('Email required');
});
```

确认 RED：
```
FAIL: 预期 'Email required'，实际 undefined
```

GREEN：
```typescript
function submitForm(data: FormData) {
  if (!data.email?.trim()) {
    return { error: 'Email required' };
  }
  // ...
}
```

确认 GREEN：PASS。

## 红旗：你在合理化

| 借口 | 真相 |
|---|---|
| "太简单不用测" | 简单代码也会坏，测试 30 秒。 |
| "我先写完再补测试" | 后补的测试直接通过——证明不了它测对了。 |
| "精神到了就行不用形式" | 先写测试回答"应该做什么"，后写测试回答"这代码做了什么"。后者被你已经写好的代码带偏。 |
| "我手动测过了" | 手动测没有记录、不能回归、压力下漏 case。 |
| "删了我写的代码太浪费" | 沉没成本。留着一堆你不能信任的代码才是浪费。 |
| "留着当参考" | 你一定会忍不住对照着改，那就变成了后补测试。删掉就是删掉。 |
| "TDD 拖慢我" | TDD 是务实路径：bug 在 commit 前被抓住，重构不慌。"务实"的捷径是生产环境 debug，那才慢。 |
| "现有代码没测试" | 你在改它，就给它补测试。 |

## 完成前清单

- [ ] 每个新函数/方法都有测试
- [ ] 看过每个测试在实现前真的失败
- [ ] 每个测试失败原因正确（缺功能，不是 typo）
- [ ] 写的是最小实现
- [ ] 所有测试通过
- [ ] 输出干净
- [ ] 边界和错误路径有覆盖

有勾不上的？你跳了 TDD。重来。

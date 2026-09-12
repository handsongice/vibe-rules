# Python

## 项目骨架
- 包结构：
  ```
  src/myapp/
    __init__.py
    cli.py
    core/
  tests/
    test_core.py
  pyproject.toml
  README.md
  ```
- 不要把代码放在仓库根目录（除非是脚本小工具）。

## 依赖管理
- 新项目一律用 **uv** 或 **poetry**，不要 `pip install` 完不写 lock。
  - uv：`pyproject.toml` + `uv.lock`
  - poetry：`pyproject.toml` + `poetry.lock`
- 不使用 `requirements.txt` 作为唯一依赖文件（只能作为导出产物）。
- Python 版本：新项目 3.11+。在 `pyproject.toml` 里 `requires-python = ">=3.11"`。

## 代码风格
- 格式化用 ruff（lint + format），不要混用 black + isort + flake8。
- 类型注解：公共函数必须写，内部脚本可省。不要为了注解而注解。
- 绝对导入：`from myapp.core import x`，不要 `from ..core import x` 除非在包内相对结构清晰。
- 路径用 `pathlib.Path`，不要 `os.path.join`。
- 不要用 `print()` 做日志，用 `logging`。
- 异步代码：一个项目里不要混用 async 和 sync IO，要么全 async 要么全 sync。

## 测试
- pytest。配置在 `pyproject.toml` 的 `[tool.pytest.ini_options]`。
- fixture 放 `conftest.py`，不要在每个测试文件里重复写。
- mock 用 `unittest.mock`，不要引入额外的 mock 库。
- 测试文件命名 `test_*.py`，测试函数 `test_*`。

## Agent 高频错误
- 用 `pip install xxx` 然后让你自己记 requirements（必须走 uv/poetry）。
- 把 `except Exception:` 当默认异常处理，吞掉所有错误。
- 可变默认参数：`def f(x=[]):` —— 永远不要这样写。
- 在模块顶层执行 IO 操作（import 时就连数据库），应该放 `if __name__ == "__main__":` 或 main 函数里。
- 用 `== None` 而不是 `is None`。
- SQL 用 f-string 拼接而不是参数化。

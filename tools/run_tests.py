"""Run tests/test_*.lua under LuaJIT (via lupa).

Usage (repo root):  uv run --with lupa tools/run_tests.py
Each test file returns a Lua table mapping test name -> function. A test fails if it errors.
Modules are loaded with require('src.<name>') because the repo root is on package.path.
"""
import pathlib
import sys

try:
    from lupa import luajit21 as lupa
except ImportError:  # wheel without LuaJIT: fall back to lupa's default Lua
    import lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent


def main() -> int:
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(f'package.path = "{ROOT.as_posix()}/?.lua;" .. package.path')
    run = lua.eval('function(f) local ok, err = pcall(f); return ok, tostring(err) end')
    passed = failed = 0
    for path in sorted((ROOT / 'tests').glob('test_*.lua')):
        tests = lua.execute(path.read_text(encoding='utf-8'))
        for name in sorted(tests.keys()):
            ok, err = run(tests[name])
            if ok:
                passed += 1
            else:
                failed += 1
                print(f'FAIL {path.name} :: {name}\n     {err}')
    print(f'{passed} passed, {failed} failed')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())

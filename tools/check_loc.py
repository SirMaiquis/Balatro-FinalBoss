"""Validate localization files against localization/default.lua.

Usage (repo root):
  uv run --with lupa tools/check_loc.py              # all files
  uv run --with lupa tools/check_loc.py es_419 es_ES # only these
Checks: every misc.quips / misc.dictionary key of default.lua exists, no extra keys,
colour tags {X:..}...{} balanced, #n# placeholders identical to English.
"""
import pathlib
import re
import sys

try:
    from lupa import luajit21 as lupa
except ImportError:
    import lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
LOC = ROOT / 'localization'
TAG = re.compile(r'\{([^}]*)\}')
PLACEHOLDER = re.compile(r'#\d+#')
SECTIONS = ('quips', 'dictionary')


def load(lua, path):
    table = lua.execute(path.read_text(encoding='utf-8'))
    misc = table['misc'] if table is not None else None
    out = {}
    for section in SECTIONS:
        sec = misc[section] if misc is not None else None
        if sec is None:
            continue
        for key in sec.keys():
            val = sec[key]
            lines = [val] if isinstance(val, str) else [val[i] for i in sorted(val.keys())]
            out[f'{section}.{key}'] = lines
    return out


def unbalanced(line):
    tags = TAG.findall(line)
    opens = sum(1 for t in tags if t.strip())
    closes = sum(1 for t in tags if not t.strip())
    return opens != closes


def main(names):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    base = load(lua, LOC / 'default.lua')
    paths = [LOC / f'{n}.lua' for n in names] if names else sorted(LOC.glob('*.lua'))
    errors = []
    for path in paths:
        data = load(lua, path)
        for key, lines in data.items():
            for line in lines:
                if unbalanced(line):
                    errors.append(f'{path.name}: {key}: unbalanced tags in {line!r}')
        if path.name == 'default.lua':
            continue
        for key, base_lines in base.items():
            if key not in data:
                errors.append(f'{path.name}: missing {key}')
                continue
            want = sorted(PLACEHOLDER.findall(' '.join(base_lines)))
            got = sorted(PLACEHOLDER.findall(' '.join(data[key])))
            if want != got:
                errors.append(f'{path.name}: {key}: placeholders {got} != {want}')
        for key in data:
            if key not in base:
                errors.append(f'{path.name}: extra key {key} (not in default.lua)')
    for e in errors:
        print(e)
    print(f'{len(paths)} files checked, {len(errors)} problems')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

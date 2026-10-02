"""Validate localization files against localization/default.lua.

Usage (repo root):
  uv run --with lupa tools/check_loc.py              # all files
  uv run --with lupa tools/check_loc.py es_419 es_ES # only these
Checks: every misc.quips / misc.dictionary key of default.lua exists, no extra keys,
colour tags {X:..}...{} balanced (scanned in order), no empty values, #n# placeholders
identical to English, gloat lines (Jimbo says them on the game-over screen) are only the line:
no "Name:" header line, not wrapped in quotation marks. A name ending in .lua is used as a file
path (default.lua stays the base).
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
TAG = re.compile(r'\{([^{}]*)\}')
PLACEHOLDER = re.compile(r'#\d+#')
SECTIONS = ('quips', 'dictionary')
GLOAT_KEY = re.compile(r'^quips\.fb_(?:\w+_)?gloat(?:_\d+)?$')
OPEN_QUOTES = '"“„«‹「『‘'   # " “ „ « ‹ 「 『 ‘
CLOSE_QUOTES = '"”“»›」』’'  # " ” “ » › 」 』 ’


def load(lua, path):
    """Return (key -> list of lines, list of problem strings). Raises on syntax errors."""
    table = lua.execute(path.read_text(encoding='utf-8'))
    out, problems = {}, []
    if table is None or lupa.lua_type(table) != 'table':
        raise ValueError('file does not return a table')
    misc = table['misc']
    if misc is None or lupa.lua_type(misc) != 'table':
        return out, problems
    for section in SECTIONS:
        sec = misc[section]
        if sec is None or lupa.lua_type(sec) != 'table':
            continue
        for key in sec.keys():
            val = sec[key]
            name = f'{section}.{key}'
            if isinstance(val, str):
                lines = [val]
            elif lupa.lua_type(val) == 'table':
                lines = [val[i] for i in range(1, len(val) + 1)]
            else:
                problems.append(f'{name}: value must be a string or list of strings')
                continue
            if not lines:
                problems.append(f'{name}: empty list')
                continue
            if not all(isinstance(x, str) for x in lines):
                problems.append(f'{name}: value must be a string or list of strings')
                continue
            if any(not x.strip() for x in lines):
                problems.append(f'{name}: empty line')
            out[name] = lines
    return out, problems


def tag_problem(line):
    """Scan {..} tags in order. {} closes; a non-empty tag may replace an open one."""
    is_open = False
    for m in TAG.finditer(line):
        if m.group(1).strip():
            is_open = True
        elif is_open:
            is_open = False
        else:
            return 'closing {} with nothing open'
    if '{' in TAG.sub('', line) or '}' in TAG.sub('', line):
        return 'stray brace'
    if is_open:
        return 'tag left open'
    return None


def gloat_problem(lines):
    """A gloat is the boss's line as Jimbo says it: no 'Name:' header, no surrounding quotes."""
    if lines[0].rstrip().endswith((':', '：')):
        return 'gloat starts with a "Name:" header line'
    text = ' '.join(lines).strip()
    if text[:1] in OPEN_QUOTES and text[-1:] in CLOSE_QUOTES:
        return 'gloat is wrapped in quotation marks'
    return None


def main(names):
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    try:
        base, base_problems = load(lua, LOC / 'default.lua')
    except Exception as e:
        print(f'default.lua: load error: {e}')
        return 1
    paths = ([pathlib.Path(n) if n.endswith('.lua') else LOC / f'{n}.lua' for n in names]
             if names else sorted(LOC.glob('*.lua')))
    errors = []
    for path in paths:
        try:
            data, problems = load(lua, path)
        except Exception as e:
            errors.append(f'{path.name}: load error: {e}')
            continue
        errors.extend(f'{path.name}: {p}' for p in problems)
        for key, lines in data.items():
            for line in lines:
                why = tag_problem(line)
                if why:
                    errors.append(f'{path.name}: {key}: {why} in {ascii(line)}')
            if GLOAT_KEY.match(key):
                why = gloat_problem(lines)
                if why:
                    errors.append(f'{path.name}: {key}: {why}')
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

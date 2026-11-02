"""Validate localization files against localization/default.lua.

Usage (repo root):
  uv run --with lupa tools/check_loc.py              # all files
  uv run --with lupa tools/check_loc.py es_419 es_ES # only these
Checks: every misc.quips / misc.dictionary / misc.achievement_names / misc.achievement_descriptions
key of default.lua exists, no extra keys,
colour tags {X:..}...{} balanced (scanned in order), no empty values, #n# placeholders
identical to English, gloat lines (Jimbo says them on the game-over screen) are only the line:
no "Name:" header line, not wrapped in quotation marks. A name ending in .lua is used as a file
path (default.lua stays the base).
Every personality (src/logic.lua PERSONALITIES) has a line for every run moment (PERSONALITY_MOMENTS, with personality_variants of each).
Card lines: used_tarot_<group> (wheel_hit / _miss / _rigged too), used_spectral_<group>,
used_planet_waste and joker_created need #2#; used_planet_main needs #3#, and no other quip may use
#3#. In all card lines a string holding #2# has at most 9 other characters.
1.4 moments (NEW_MOMENTS_1_4): default.lua has fb_generic_<m>_1..2 and fb_<final>_<m>_1..2 for
every final boss (FINAL_BOSSES); the moments said outside the fight (OUTSIDE_MOMENTS) use no #2#/#3#.
Text effects (1.4), tags like {E:fb_rage}word{}, in every language and quip line:
  1. every {E:<key>} is in logic.TEXT_EFFECTS (or the built-ins 1 and 2);
  2. at most one punchline tag ({C:}, {E:} other than fb_grawlix, {u:}) per line;
  3. a fb_grawlix tag wraps a single word (no spaces).
  4. no FinalBoss quip keeps the old x* censor form (the raw-swear guard).
Rule 2 applies to quips keys only. A tag holding only s: or X: controls is not a punchline.
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
SECTIONS = ('quips', 'dictionary', 'achievement_names', 'achievement_descriptions')
JOKER_KEY = re.compile(r'_jab_(?:counter|famous|combo)_\d+$')
# Card-specific consumable lines (1.3): #2# names the card (tarot, spectral), the planet's hand
# (planet waste) or the new joker (joker_created); #3# is the planet hand's new level, only in
# used_planet_main, where it is required.
CARD_KEY = re.compile(r'_used_(?:tarot|spectral)_[a-z_]+_\d+$|_used_planet_waste_\d+$|_joker_created_\d+$')
LEVEL_KEY = re.compile(r'_used_planet_main_\d+$')
NAME_ROOM = 9  # card and hand names run long: a string holding #2# keeps at most 9 other characters
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


def personality_problems(lua, data):
    """Every personality has every run moment, with its variants (src/logic.lua is the source)."""
    logic = lua.execute((ROOT / 'src' / 'logic.lua').read_text(encoding='utf-8'))
    out = []
    for p in logic['PERSONALITIES'].values():
        for m in logic['PERSONALITY_MOMENTS'].values():
            for i in range(1, int(logic.personality_variants(m)) + 1):
                key = f'quips.fb_p_{p}_{m}_{i}'
                if key not in data:
                    out.append(f'missing personality line {key}')
    return out


NEW_MOMENT_VARIANTS = 2  # generic and final-boss lines per 1.4 moment


def new_moment_problems(logic, data):
    """default.lua: every 1.4 moment has generic lines and lines for each vanilla final boss."""
    out = []
    finals = list(logic['FINAL_BOSSES'].values())
    for m in logic['NEW_MOMENTS_1_4'].values():
        for prefix in [f'fb_generic_{m}'] + [f'fb_{b}_{m}' for b in finals]:
            for i in range(1, NEW_MOMENT_VARIANTS + 1):
                key = f'quips.{prefix}_{i}'
                if key not in data:
                    out.append(f'missing 1.4 line {key}')
    return out


def outside_key(logic):
    """Regex for the lines said outside the fight (no card, hand or level to name)."""
    names = '|'.join(re.escape(m) for m in logic['OUTSIDE_MOMENTS'].values())
    return re.compile(rf'^quips\.fb_\w+_(?:{names})_\d+$')


EFFECT_KEY = re.compile(r'^E:(.*)$')
BUILTIN_EFFECTS = ('1', '2')
GRAWLIX = 'fb_grawlix'
OLD_CENSOR = re.compile(r'[^\W\d_]\*')  # a letter then a star: the pre-1.4 "sh*t" form


def controls(tag):
    """The comma-separated controls of one tag body ('C:attention,u:attention')."""
    return [c.strip() for c in tag.split(',') if c.strip()]


def effect_problems(effects, line, quip=True):
    """Rules 1-3 for one line. effects: the allowed {E:} keys. Rule 2 (one punchline) only applies
    to quips (quip=True), not dictionary or achievement strings."""
    out, punchlines = [], 0
    matches = list(TAG.finditer(line))
    for i, m in enumerate(matches):
        cs = controls(m.group(1))
        keys = [EFFECT_KEY.match(c).group(1).strip() for c in cs if EFFECT_KEY.match(c)]
        for k in keys:
            if k not in effects and k not in BUILTIN_EFFECTS:
                out.append(f'unknown text effect {k!r}')
        if GRAWLIX in keys:
            end = matches[i + 1].start() if i + 1 < len(matches) else len(line)
            word = line[m.end():end]
            if not word.strip() or re.search(r'\s', word.strip()):
                out.append(f'{GRAWLIX} must wrap a single word, got {word!r}')
        elif any(c.startswith(('C:', 'u:')) for c in cs) or keys:
            punchlines += 1
    if quip and punchlines > 1:
        out.append(f'{punchlines} punchline tags in one line (at most 1)')
    return out


def grawlix_count(lines):
    """Number of fb_grawlix tags in a key's lines."""
    return sum(GRAWLIX in [c[2:].strip() for c in controls(m.group(1)) if c.startswith('E:')]
               for line in lines for m in TAG.finditer(line))


def old_censor_problems(key, lines):
    """Rule 4: FinalBoss's own quips no longer use x* (the tag is the censor)."""
    if key.startswith('quips.') and any(OLD_CENSOR.search(line) for line in lines):
        return ['old x* censor form (write the swear in full inside {E:fb_grawlix}...{})']
    return []


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
    logic = lua.execute((ROOT / 'src' / 'logic.lua').read_text(encoding='utf-8'))
    outside = outside_key(logic)
    effects = {str(v) for v in logic['TEXT_EFFECTS'].values()}
    errors = []
    for path in paths:
        try:
            data, problems = load(lua, path)
        except Exception as e:
            errors.append(f'{path.name}: load error: {e}')
            continue
        errors.extend(f'{path.name}: {p}' for p in problems)
        errors.extend(f'{path.name}: {p}' for p in personality_problems(lua, data))
        if path.name == 'default.lua':
            errors.extend(f'{path.name}: {p}' for p in new_moment_problems(logic, data))
        for key, lines in data.items():
            for line in lines:
                why = tag_problem(line)
                if why:
                    errors.append(f'{path.name}: {key}: {why} in {ascii(line)}')
                errors.extend(f'{path.name}: {key}: {p} in {ascii(line)}' for p in effect_problems(effects, line, key.startswith('quips.')))
            errors.extend(f'{path.name}: {key}: {p}' for p in old_censor_problems(key, lines))
            if JOKER_KEY.search(key) and '#2#' not in ' '.join(lines):
                errors.append(f'{path.name}: {key}: joker jab line needs #2#')
            if CARD_KEY.search(key) and '#2#' not in ' '.join(lines):
                errors.append(f'{path.name}: {key}: card line needs #2#')
            if CARD_KEY.search(key) or LEVEL_KEY.search(key):
                for line in lines:
                    if '#2#' in line and len(TAG.sub('', line)) - 3 > NAME_ROOM:
                        errors.append(f'{path.name}: {key}: more than {NAME_ROOM} characters '
                                      f'next to #2# in {ascii(line)}')
            if LEVEL_KEY.search(key) and '#3#' not in ' '.join(lines):
                errors.append(f'{path.name}: {key}: planet main line needs #3#')
            if '#3#' in ' '.join(lines) and key.startswith('quips.') and not LEVEL_KEY.search(key):
                errors.append(f'{path.name}: {key}: #3# is only for used_planet_main')
            if outside.match(key) and re.search(r'#[23]#', ' '.join(lines)):
                errors.append(f'{path.name}: {key}: lines said outside the fight take no #2#/#3#')
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

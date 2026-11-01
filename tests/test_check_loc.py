"""Tests for tools/check_loc.py's text-effect rules (1.4), on small fixture tables.

Run: uv run --with lupa --with pytest python -m pytest tests/test_check_loc.py
"""
import importlib.util
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('check_loc', ROOT / 'tools' / 'check_loc.py')
check_loc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check_loc)

lupa = check_loc.lupa
_lua = lupa.LuaRuntime(unpack_returned_tuples=True)
_logic = _lua.execute((ROOT / 'src' / 'logic.lua').read_text(encoding='utf-8'))
EFFECTS = {str(v) for v in _logic['TEXT_EFFECTS'].values()}


def problems(line):
    return check_loc.effect_problems(EFFECTS, line)


def test_effects_come_from_logic():
    assert len(EFFECTS) == 12 and 'fb_rage' in EFFECTS and 'fb_grawlix' in EFFECTS


def test_valid_lines_pass():
    for line in ['Plain line', 'You {E:fb_rage}fool{}', '{C:attention,u:attention}Smug{} one',
                 'Oh {E:fb_grawlix}shit{} that {C:mult}Mult{}', '{E:1}rainbow{} {E:fb_grawlix}damn{}',
                 'No {C:dark_edition}CLUTCH{}']:
        assert problems(line) == [], line


def test_rule1_unknown_key():
    assert any('unknown text effect' in p for p in problems('A {E:fb_nope}word{}'))
    assert any('unknown text effect' in p for p in problems('A {C:mult,E:bogus}word{}'))


def test_rule2_two_punchlines():
    assert any('punchline' in p for p in problems('{E:fb_rage}one{} and {E:fb_fall}two{}'))
    assert any('punchline' in p for p in problems('{C:mult}one{} {C:attention,u:attention}two{}'))


def test_rule2_grawlix_not_counted():
    assert problems('{E:fb_rage}one{} {E:fb_grawlix}shit{}') == []
    assert problems('{E:fb_grawlix}shit{} {E:fb_grawlix}damn{}') == []


def test_rule3_grawlix_single_word():
    assert any('single word' in p for p in problems('{E:fb_grawlix}holy shit{}'))
    assert any('single word' in p for p in problems('{E:fb_grawlix}{}'))
    assert problems('{E:fb_grawlix}shit{}!') == []


def test_rule4_old_censor_form():
    assert check_loc.old_censor_problems('quips.fb_x_1', ['What the sh*t'])
    assert check_loc.old_censor_problems('quips.fb_x_1', ['Oh', 'f***ing'])
    assert not check_loc.old_censor_problems('quips.fb_x_1', ['What the {E:fb_grawlix}shit{}', '5 * 3'])
    assert not check_loc.old_censor_problems('dictionary.k', ['sh*t'])


def test_rule5_language_missing_a_grawlix():
    base = {'quips.a': ['You {E:fb_grawlix}shit{}'], 'quips.b': ['plain'],
            'quips.c': ['{E:fb_grawlix}a{} {E:fb_grawlix}b{}']}
    lang = {'quips.a': ['Du Mist'], 'quips.b': ['{E:fb_grawlix}x{}'],
            'quips.c': ['{E:fb_grawlix}a{} {E:fb_grawlix}b{}']}
    out = check_loc.grawlix_parity_problems(base, lang)
    assert len(out) == 1 and out[0].startswith('quips.a')
    assert check_loc.grawlix_parity_problems(base, base) == []


def test_cjk_line_with_grawlix():
    assert problems('你这个{E:fb_grawlix}混蛋{}！') == []
    assert any('single word' in p for p in problems('你这个{E:fb_grawlix}混 蛋{}'))


def test_tag_around_placeholder():
    assert problems('Nice {C:attention}#2#{}') == []
    assert problems('Nice {E:fb_swell}#2#{}') == []


def test_size_and_background_tags_are_not_punchlines():
    assert problems('{s:1.2}big{} {E:fb_rage}one{}') == []


def test_rule2_only_for_quips():
    line = '{E:fb_rage}one{} {E:fb_fall}two{}'
    assert check_loc.effect_problems(EFFECTS, line, quip=False) == []
    assert check_loc.effect_problems(EFFECTS, line, quip=True)

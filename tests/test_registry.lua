local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

-- Fresh registry with fake game globals.
local function setup(quips, warnings)
  _G.G = {SETTINGS = {language = 'en-us'}, localization = {misc = {quips = quips or {}}}}
  _G.FinalBoss = {
    util = {log = function(level, msg) if warnings then warnings[#warnings + 1] = level .. ':' .. msg end end},
    logic = require('src.logic'),
  }
  package.loaded['src.personality'] = nil
  FinalBoss.personality = require('src.personality')
  package.loaded['src.registry'] = nil
  local R = require('src.registry')
  FinalBoss.registry = R
  return R
end

T['register normalizes defaults'] = function()
  local R = setup()
  local e = R.register{blind = 'bl_hook'}
  eq(e.tier, 'auto'); eq(e.voice.pitch, 1); eq(e.fx.intro, 'pulse'); eq(e.fx.defeat, 'shatter')
  eq(R.get('bl_hook'), e)
end

T['register rejects unknown tier and fx with warnings'] = function()
  local warnings = {}
  local R = setup(nil, warnings)
  local e = R.register{blind = 'bl_x', tier = 'epic', fx = {intro = 'laser', defeat = 'flash'}}
  eq(e.tier, 'auto'); eq(e.fx.intro, 'pulse'); eq(e.fx.defeat, 'flash')
  eq(#warnings, 2)
end

T['register ignores a non-table voice and a non-numeric pitch'] = function()
  local warnings = {}
  local R = setup(nil, warnings)
  local e1 = R.register{blind = 'bl_v1', voice = 'loud'}
  eq(e1.voice.pitch, 1)
  local e2 = R.register{blind = 'bl_v2', voice = {pitch = 'high'}}
  eq(e2.voice.pitch, 1)
  eq(#warnings, 1, 'one warn for the bad pitch')
  local e3 = R.register{blind = 'bl_v3', voice = {pitch = 1.25}}
  eq(e3.voice.pitch, 1.25)
end

T['register requires a blind key'] = function()
  local R = setup()
  assert(not pcall(R.register, {}), 'should error without blind')
end

T['get unknown blind returns auto default'] = function()
  local R = setup()
  local e = R.get('bl_some_mod_boss')
  eq(e.blind, 'bl_some_mod_boss'); eq(e.tier, 'auto'); eq(e.voice.pitch, 1)
end

T['count probes consecutive variants'] = function()
  local R = setup{fb_bl_hook_intro_1 = {'a'}, fb_bl_hook_intro_2 = {'b'}, fb_bl_hook_intro_4 = {'gap'}}
  eq(R.count('fb_bl_hook_intro'), 2)
  eq(R.count('fb_nothing'), 0)
end

T['count cache resets on language change'] = function()
  local R = setup{fb_nemesis_intro_1 = {'a'}}
  eq(R.count('fb_nemesis_intro'), 1)
  G.localization.misc.quips.fb_nemesis_intro_2 = {'b'}
  eq(R.count('fb_nemesis_intro'), 1, 'cached')
  G.SETTINGS.language = 'es_419'
  eq(R.count('fb_nemesis_intro'), 2, 'after language change')
end

T['resolve picks boss-specific key and records variant'] = function()
  local R = setup{fb_bl_hook_intro_1 = {'a'}}
  local last = {}
  eq(R.resolve('bl_hook', 'intro', last), 'fb_bl_hook_intro_1')
  eq(last.fb_bl_hook_intro, 1)
end

T['resolve falls back to generic'] = function()
  local R = setup{fb_generic_close_1 = {'a'}}
  eq(R.resolve('bl_mod_boss', 'close', {}), 'fb_generic_close_1')
end

T['resolve returns nil when nothing exists'] = function()
  local R = setup{}
  eq(R.resolve('bl_mod_boss', 'close', {}), nil)
end

T['resolve does not repeat the last variant'] = function()
  local R = setup{fb_nemesis_intro_1 = {'a'}, fb_nemesis_intro_2 = {'b'}}
  local last = {}
  local first = R.resolve('bl_hook', 'nemesis_intro', last)
  for _ = 1, 20 do
    local nxt = R.resolve('bl_hook', 'nemesis_intro', last)
    assert(nxt ~= first, 'repeated ' .. nxt)
    first = nxt
  end
end

T['vanilla encounters list has 28 bosses'] = function()
  _G.FinalBoss = nil
  package.loaded['src.encounters.vanilla'] = nil
  local bosses = require('src.encounters.vanilla')
  local n = 0
  for _ in pairs(bosses) do n = n + 1 end
  eq(n, 28)
  assert(bosses.bl_hook and bosses.bl_final_bell, 'missing expected keys')
end

T['register keeps cleaned moves and death'] = function()
  local R = setup()
  local e = R.register{blind = 'bl_mod', moves = {play = {{effect = 'burst'}}}, death = 'hearts'}
  eq(e.moves.play[1].effect, 'burst'); eq(e.death, 'hearts')
end

T['register warns about bad moves and death and drops them'] = function()
  local warnings = {}
  local R = setup(nil, warnings)
  local e = R.register{blind = 'bl_mod2', moves = {dance = {{effect = 'burst'}}}, death = 'fireworks'}
  eq(e.moves, nil); eq(e.death, nil)
  eq(#warnings, 2)
end

T['entries without moves have nil moves and death'] = function()
  local R = setup()
  local e = R.get('bl_unknown')
  eq(e.moves, nil); eq(e.death, nil)
end

T['resolve: nemesis lines are shared, never per boss'] = function()
  local R = setup{fb_nemesis_intro_1 = {'a'}, fb_bl_hook_nemesis_intro_1 = {'b'}, fb_nemesis_defeat_1 = {'c'}}
  eq(R.resolve('bl_hook', 'nemesis_intro', {}), 'fb_nemesis_intro_1')
  eq(R.resolve('bl_mod', 'nemesis_defeat', {}), 'fb_nemesis_defeat_1')
end

T['register: vanilla bosses get their personality, others bully'] = function()
  local R = setup()
  eq(R.register{blind = 'bl_psychic'}.personality, 'smug')
  eq(R.register{blind = 'bl_mymod_boss'}.personality, 'bully')
  eq(R.get('bl_unknown').personality, 'bully')
  eq(R.get('bl_final_bell').personality, 'royal')
end

T['register: a valid personality is kept, an invalid one warns and falls back'] = function()
  local warnings = {}
  local R = setup(nil, warnings)
  eq(R.register{blind = 'bl_m1', personality = 'chaos'}.personality, 'chaos')
  eq(#warnings, 0)
  eq(R.register{blind = 'bl_m2', personality = 'grumpy'}.personality, 'bully')
  eq(#warnings, 1)
  assert(warnings[1]:find('grumpy', 1, true), warnings[1])
end

T['resolve: personality lines before generic, skip_boss for another counter'] = function()
  local R = setup{fb_p_killer_idle_1 = {'a'}, fb_generic_idle_1 = {'b'}, fb_bl_hook_jab_counter_1 = {'c'},
    fb_p_killer_jab_counter_1 = {'d'}, fb_p_bully_idle_1 = {'e'}}
  eq(R.resolve('bl_hook', 'idle', {}), 'fb_p_killer_idle_1')
  eq(R.resolve('bl_mod', 'idle', {}), 'fb_p_bully_idle_1')
  eq(R.resolve('bl_hook', 'jab_counter', {}), 'fb_bl_hook_jab_counter_1')
  eq(R.resolve('bl_hook', 'jab_counter', {}, {skip_boss = true}), 'fb_p_killer_jab_counter_1')
end

T['personality.of reads the registry entry'] = function()
  local R = setup()
  R.register{blind = 'bl_m3', personality = 'venom'}
  FinalBoss.registry = R
  eq(FinalBoss.personality.of('bl_m3'), 'venom')
  eq(FinalBoss.personality.of('bl_wheel'), 'chaos')
  eq(FinalBoss.personality.of('bl_nobody'), 'bully')
end

-- 1.3.1 line hook ----------------------------------------------------------------------------------

T['line hook: a name with boss lines resolves to that key'] = function()
  local R = setup{fb_bl_mod_defeat_1 = {'a'}, fb_bl_mod_defeat_lasthand_1 = {'b'}}
  local seen
  R.register{blind = 'bl_mod', line = function(moment, info)
    seen = moment
    if moment == 'defeat' then return 'defeat_lasthand' end
  end}
  local last = {}
  eq(R.resolve('bl_mod', 'defeat', last), 'fb_bl_mod_defeat_lasthand_1')
  eq(seen, 'defeat')
  eq(last.fb_bl_mod_defeat_lasthand, 1, 'variant keyed by the custom prefix')
end

T['line hook: a name with no lines falls back to the normal key'] = function()
  local R = setup{fb_bl_mod_defeat_1 = {'a'}, fb_generic_defeat_lasthand_1 = {'g'}, fb_p_bully_nope_1 = {'p'}}
  R.register{blind = 'bl_mod', line = function() return 'defeat_lasthand' end}
  eq(R.resolve('bl_mod', 'defeat', {}), 'fb_bl_mod_defeat_1')
  R.register{blind = 'bl_mod', line = function() return 'nope' end}
  eq(R.resolve('bl_mod', 'defeat', {}), 'fb_bl_mod_defeat_1', 'no personality fallback for a custom name')
end

T['line hook: nil or a number falls back'] = function()
  local R = setup{fb_bl_mod_close_1 = {'a'}, fb_bl_mod_3_1 = {'n'}}
  R.register{blind = 'bl_mod', line = function() return nil end}
  eq(R.resolve('bl_mod', 'close', {}), 'fb_bl_mod_close_1')
  R.register{blind = 'bl_mod', line = function() return 3 end}
  eq(R.resolve('bl_mod', 'close', {}), 'fb_bl_mod_close_1')
end

T['line hook: an error falls back and logs once per blind'] = function()
  local warnings = {}
  local R = setup({fb_bl_mod_close_1 = {'a'}}, warnings)
  R.register{blind = 'bl_mod', line = function() error('boom') end}
  eq(R.resolve('bl_mod', 'close', {}), 'fb_bl_mod_close_1')
  eq(R.resolve('bl_mod', 'close', {}), 'fb_bl_mod_close_1')
  eq(#warnings, 1)
  assert(warnings[1]:find('boom', 1, true), warnings[1])
end

T['line hook: not called for shared moments nor skip_boss'] = function()
  local R = setup{fb_nemesis_intro_1 = {'a'}, fb_p_bully_jab_counter_1 = {'b'}, fb_bl_mod_custom_1 = {'c'}}
  local calls = 0
  R.register{blind = 'bl_mod', line = function() calls = calls + 1; return 'custom' end}
  eq(R.resolve('bl_mod', 'nemesis_intro', {}), 'fb_nemesis_intro_1')
  eq(R.resolve('bl_mod', 'jab_counter', {}, {skip_boss = true}), 'fb_p_bully_jab_counter_1')
  eq(calls, 0)
end

T['line hook: variants rotate within the custom prefix'] = function()
  local R = setup{fb_bl_mod_custom_1 = {'a'}, fb_bl_mod_custom_2 = {'b'}}
  R.register{blind = 'bl_mod', line = function() return 'custom' end}
  local last = {}
  local prev = R.resolve('bl_mod', 'defeat', last)
  for _ = 1, 20 do
    local nxt = R.resolve('bl_mod', 'defeat', last)
    assert(nxt:find('fb_bl_mod_custom_', 1, true) == 1, nxt)
    assert(nxt ~= prev, 'repeated ' .. nxt)
    prev = nxt
  end
end

T['line hook: a non-function line warns and is ignored'] = function()
  local warnings = {}
  local R = setup(nil, warnings)
  local e = R.register{blind = 'bl_mod', line = 'defeat_lasthand'}
  eq(e.line, nil)
  eq(#warnings, 1)
  local f = function() end
  eq(R.register{blind = 'bl_mod2', line = f}.line, f)
  eq(#warnings, 1)
end

T['line hook: info carries the live game state'] = function()
  local R = setup{fb_bl_mod_custom_1 = {'c'}}
  package.loaded['src.director'] = nil
  FinalBoss.director = require('src.director')
  G.GAME = {dollars = 12, chips = 900, last_hand_played = 'Flush', round_resets = {ante = 4},
    current_round = {hands_left = 0, discards_left = 2, hands_played = 3},
    blind = {chips = 800},
    FinalBoss = {lost_to = nil, encounter = {key = 'bl_mod', tier = 'full', showdown = true, win_hand = 3}}}
  local got
  R.register{blind = 'bl_mod', line = function(_, info) got = info; return 'custom' end}
  eq(R.resolve('bl_mod', 'defeat', {}), 'fb_bl_mod_custom_1')
  eq(got.blind, 'bl_mod'); eq(got.tier, 'full'); eq(got.showdown, true); eq(got.ante, 4)
  eq(got.hands_left, 0); eq(got.discards_left, 2); eq(got.hands_played, 3)
  eq(got.dollars, 12); eq(got.chips, 900); eq(got.required, 800); eq(got.hand_type, 'Flush')
  eq(got.won, true); eq(got.lost, false)
  local first = got
  R.resolve('bl_mod', 'defeat', {})
  assert(got ~= first, 'a fresh table each call')
  -- Another boss's encounter, a loss to this one, and no game at all: nil-safe.
  G.GAME.FinalBoss = {lost_to = 'bl_mod', encounter = {key = 'bl_other', tier = 'light', win_hand = 1}}
  R.resolve('bl_mod', 'gloat', {})
  eq(got.tier, nil); eq(got.won, false); eq(got.lost, true)
  G.GAME = nil
  eq(R.resolve('bl_mod', 'defeat', {}), 'fb_bl_mod_custom_1')
  eq(got.hands_left, nil); eq(got.dollars, 0); eq(got.lost, false)
end

return T

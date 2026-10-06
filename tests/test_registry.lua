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
  local R = setup{fb_opener_1 = {'a'}}
  eq(R.count('fb_opener'), 1)
  G.localization.misc.quips.fb_opener_2 = {'b'}
  eq(R.count('fb_opener'), 1, 'cached')
  G.SETTINGS.language = 'es_419'
  eq(R.count('fb_opener'), 2, 'after language change')
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
  local R = setup{fb_opener_1 = {'a'}, fb_opener_2 = {'b'}}
  local last = {}
  local first = R.resolve('bl_hook', 'opener', last)
  for _ = 1, 20 do
    local nxt = R.resolve('bl_hook', 'opener', last)
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

return T

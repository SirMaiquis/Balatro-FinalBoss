-- moments.lua under stubs (no game): the boss preview and the reroll protest/sneer on blind select.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local function logic()
  package.loaded['src.logic'] = nil
  return require('src.logic')
end

T['preview_due: once per ante, never for a silent boss'] = function()
  local L = logic()
  eq(L.preview_due{ante = 2, previewed_ante = nil, tier = 'light'}, true, 'new ante')
  eq(L.preview_due{ante = 3, previewed_ante = 2, tier = 'full'}, true, 'next ante')
  eq(L.preview_due{ante = 2, previewed_ante = 2, tier = 'light'}, false, 'same ante')
  eq(L.preview_due{ante = 2, previewed_ante = nil, tier = 'none'}, false, 'tier none')
  eq(L.preview_due{ante = 2, previewed_ante = nil, tier = nil}, false, 'unreadable boss')
end

T['preview_due: ante 1 is due like any other'] = function()
  eq(logic().preview_due{ante = 1, previewed_ante = nil, tier = 'light'}, true)
end

--- A blind-select boss UIBox stub: blind_desc holds the chip sprite before the stake sprite.
local function boss_box(sprite)
  local stake = {atlas = 'stake', sprite_pos = {x = 0, y = 0}}
  local desc = {config = {id = 'blind_desc'}, children = {
    {config = {}, children = {{config = {object = sprite}, children = {}}}},
  }}
  local root = {config = {}, children = {
    {config = {object = {string = 'name'}}, children = {}}, -- a DynaText: not a sprite
    desc,
    {config = {object = stake}, children = {}},
  }}
  return {UIRoot = root, get_UIE_by_ID = function(_, id) if id == 'blind_desc' then return desc end end}
end

local function setup(opts)
  opts = opts or {}
  local ctx = {said = {}, timers = {}}
  local L = logic()
  ctx.chip = {atlas = 'blind_chips', sprite_pos = {x = 0, y = 7}}
  _G.Event = function(def) return def end
  _G.localize = function(args) return 'Loc ' .. args.key end
  _G.G = {
    GAME = {round_resets = {ante = opts.ante or 2, blind_choices = {Boss = 'bl_hook'}}, FinalBoss = {}},
    STATE = 7, STATES = {BLIND_SELECT = 7},
    E_MANAGER = {add_event = function(_, e) ctx.timers[#ctx.timers + 1] = e end},
    P_BLINDS = {bl_hook = {name = 'The Hook', boss = {min = 1}}, bl_wall = {name = 'The Wall', boss = {min = 2}},
      bl_ox = {name = 'The Ox', boss = {min = 6}}, bl_final_leaf = {name = 'Verdant Leaf', boss = {showdown = true}}},
    blind_select = {},
    blind_select_opts = {boss = boss_box(ctx.chip)},
  }
  _G.FinalBoss = {
    logic = L,
    config = {dialogue = opts.dialogue ~= false, fx = true, min_ante = opts.min_ante or 1},
    util = {guard = function(_, fn, ...) return pcall(fn, ...) end,
      state = function() G.GAME.FinalBoss = G.GAME.FinalBoss or {}; return G.GAME.FinalBoss end},
    director = {enabled = function() return not G.GAME.FinalBoss.disabled_for_run end},
    registry = {
      get = function(key) return {tier = 'auto', voice = {pitch = key == 'bl_wall' and 0.7 or 1}} end,
      resolve = function(key, moment) return 'fb_' .. key .. '_' .. moment end,
    },
    dialogue = {say = function(host, key, vars, pitch, o)
      ctx.said[#ctx.said + 1] = {host = host, key = key, vars = vars, pitch = pitch, opts = o}
      return true
    end},
  }
  package.loaded['src.moments'] = nil
  ctx.M = require('src.moments')
  function ctx.fire_timers()
    local queued = ctx.timers
    ctx.timers = {}
    for _, e in ipairs(queued) do e.func() end
  end
  function ctx.keys()
    local out = {}
    for i, s in ipairs(ctx.said) do out[i] = s.key end
    return table.concat(out, ',')
  end
  return ctx
end

T['chip: the blind sprite inside blind_desc, not the stake or the name'] = function()
  local ctx = setup()
  eq(ctx.M.chip(), ctx.chip)
  G.blind_select_opts = nil
  eq(ctx.M.chip(), nil, 'no blind select')
end

T['on_blind_select: the upcoming boss previews once per ante, from its chip'] = function()
  local ctx = setup()
  ctx.M.on_blind_select()
  eq(#ctx.said, 0, 'waits for the screen to settle')
  ctx.fire_timers()
  eq(ctx.keys(), 'fb_bl_hook_preview')
  local s = ctx.said[1]
  eq(s.host, ctx.chip); eq(s.vars[1], 'Loc bl_hook'); eq(s.pitch, 1)
  eq(s.opts.late, true, 'drawn above the blind-select UI')
  eq(G.GAME.FinalBoss.previewed_ante, 2)
  ctx.M.on_blind_select() -- back from the shop, same ante (or a reload)
  ctx.fire_timers()
  eq(#ctx.said, 1)
  G.GAME.round_resets.ante = 3
  ctx.M.on_blind_select()
  ctx.fire_timers()
  eq(#ctx.said, 2, 'a new ante previews again')
end

T['on_blind_select: a light boss below min_ante says nothing; showdowns always speak'] = function()
  local ctx = setup{min_ante = 4}
  ctx.M.on_blind_select(); ctx.fire_timers()
  eq(#ctx.said, 0)
  G.GAME.round_resets.blind_choices.Boss = 'bl_final_leaf'
  ctx.M.on_blind_select(); ctx.fire_timers()
  eq(ctx.keys(), 'fb_bl_final_leaf_preview')
end

T['on_blind_select: ante 1 previews on its first screen, after the run-start wipe'] = function()
  local ctx = setup{ante = 1}
  ctx.M.on_blind_select()
  eq(#ctx.timers, 1)
  eq(ctx.timers[1].delay, ctx.M.FIRST_PREVIEW_DELAY, 'the longer wait')
  ctx.fire_timers()
  eq(ctx.keys(), 'fb_bl_hook_preview')
  eq(G.GAME.FinalBoss.previewed_ante, 1)
  ctx.M.on_blind_select(); ctx.fire_timers() -- back from the small blind's shop
  eq(#ctx.said, 1, 'once per ante')
  G.GAME.round_resets.ante = 2
  ctx.M.on_blind_select()
  eq(ctx.timers[1].delay, ctx.M.PREVIEW_DELAY, 'later screens wait the short delay')
  ctx.M.teardown(); G.GAME.round_resets.ante = 3
  ctx.M.on_blind_select()
  eq(ctx.timers[#ctx.timers].delay, ctx.M.FIRST_PREVIEW_DELAY, 'a new or loaded run waits for its wipe again')
end

T['on_blind_select: a blind picked before the line is due drops it'] = function()
  local ctx = setup()
  ctx.M.on_blind_select()
  G.STATE = 1; G.blind_select = nil
  ctx.fire_timers()
  eq(#ctx.said, 0)
  eq(G.GAME.FinalBoss.previewed_ante, nil, 'not counted: it was never seen')
end

T['on_reroll: protest, then the sneer, which counts as the preview'] = function()
  local ctx = setup()
  G.GAME.round_resets.blind_choices.Boss = 'bl_wall'
  ctx.M.on_reroll('bl_hook', 'bl_wall')
  eq(ctx.keys(), 'fb_bl_hook_rerolled_out')
  eq(G.GAME.FinalBoss.previewed_ante, 2)
  ctx.fire_timers()
  eq(ctx.keys(), 'fb_bl_hook_rerolled_out,fb_bl_wall_rerolled_in')
  eq(ctx.said[2].pitch, 0.7, 'the new boss voice'); eq(ctx.said[2].vars[1], 'Loc bl_wall')
  ctx.M.on_blind_select(); ctx.fire_timers()
  eq(#ctx.said, 2, 'no second preview this ante')
end

T['on_reroll: a pending preview gives way to the reroll'] = function()
  local ctx = setup()
  ctx.M.on_blind_select()
  G.GAME.round_resets.blind_choices.Boss = 'bl_wall'
  ctx.M.on_reroll('bl_hook', 'bl_wall')
  ctx.fire_timers(); ctx.fire_timers()
  eq(ctx.keys(), 'fb_bl_hook_rerolled_out,fb_bl_wall_rerolled_in')
end

T['on_reroll: two quick rerolls, only the latest sneer plays'] = function()
  local ctx = setup()
  ctx.M.on_reroll('bl_hook', 'bl_wall')
  G.GAME.round_resets.blind_choices.Boss = 'bl_ox'
  ctx.M.on_reroll('bl_wall', 'bl_ox')
  ctx.fire_timers()
  eq(ctx.keys(), 'fb_bl_hook_rerolled_out,fb_bl_wall_rerolled_out,fb_bl_ox_rerolled_in')
end

T['on_reroll: a silent outgoing boss lets the new one sneer at once'] = function()
  local ctx = setup{min_ante = 4}
  G.GAME.round_resets.blind_choices.Boss = 'bl_final_leaf'
  ctx.M.on_reroll('bl_hook', 'bl_final_leaf')
  eq(ctx.keys(), 'fb_bl_final_leaf_rerolled_in')
end

T['teardown: a pending sneer never plays'] = function()
  local ctx = setup()
  G.GAME.round_resets.blind_choices.Boss = 'bl_wall'
  ctx.M.on_reroll('bl_hook', 'bl_wall')
  ctx.M.teardown()
  ctx.fire_timers()
  eq(ctx.keys(), 'fb_bl_hook_rerolled_out')
  G.GAME.round_resets.ante = 3
  ctx.M.on_blind_select()
  ctx.M.teardown()
  ctx.fire_timers()
  eq(#ctx.said, 1, 'a pending preview neither')
end

T['gating: dialogue off, FinalBoss disabled for the run: nothing said'] = function()
  local ctx = setup{dialogue = false}
  ctx.M.on_blind_select(); ctx.M.on_reroll('bl_hook', 'bl_wall'); ctx.fire_timers()
  eq(#ctx.said, 0)
  ctx = setup()
  G.GAME.FinalBoss.disabled_for_run = true
  ctx.M.on_blind_select(); ctx.M.on_reroll('bl_hook', 'bl_wall'); ctx.fire_timers()
  eq(#ctx.said, 0)
end

T['speak: a boss with no line, or an unknown blind key, is skipped quietly'] = function()
  local ctx = setup()
  FinalBoss.registry.resolve = function() return nil end
  ctx.M.on_blind_select(); ctx.fire_timers()
  eq(#ctx.said, 0)
  eq(G.GAME.FinalBoss.previewed_ante, nil)
  ctx = setup()
  G.GAME.round_resets.blind_choices.Boss = 'bl_modded_gone'
  ctx.M.on_blind_select(); ctx.fire_timers()
  eq(#ctx.said, 0)
end

-- Early loss (1.4) ------------------------------------------------------------------------------------

--- A game over on the small blind: the overlay is not up yet; the avatar stub records the spawned
--- chip; memory and achievements record any call (none is allowed).
local function loss_setup(opts)
  local ctx = setup(opts)
  ctx.spawned, ctx.forbidden = {}, {}
  ctx.clock = 0
  G.GAME.blind = {config = {blind = {key = 'bl_small'}}}
  G.SETTINGS = {paused = true}
  G.OVERLAY_MENU = nil
  ctx.avatar = {obj = {name = 'gloat chip'}}
  FinalBoss.avatar = {
    on_game_over_screen = function() return G.OVERLAY_MENU ~= nil end,
    spawn_gloat = function(key, pitch)
      ctx.spawned[#ctx.spawned + 1] = {key = key, pitch = pitch}
      return true
    end,
    anchor = function() return ctx.avatar.obj end,
  }
  FinalBoss.util.now = function() return ctx.clock end
  local function forbid(name) return function() ctx.forbidden[#ctx.forbidden + 1] = name end end
  FinalBoss.memory = {on_loss = forbid('memory.on_loss'), on_fight = forbid('memory.on_fight')}
  FinalBoss.achievements = {award_from = forbid('achievements.award_from')}
  -- Repeating events (return false) stay queued, like the event manager.
  function ctx.run_timers()
    local queued = ctx.timers
    ctx.timers = {}
    for _, e in ipairs(queued) do
      if e.func() == false then ctx.timers[#ctx.timers + 1] = e end
    end
  end
  return ctx
end

T['on_early_loss: the upcoming boss comes out once the game-over screen is up, and mocks'] = function()
  local ctx = loss_setup()
  G.GAME.round_resets.blind_choices.Boss = 'bl_wall'
  ctx.M.on_early_loss()
  eq(#ctx.timers, 1, 'one waiting event')
  local w = ctx.timers[1]
  eq(w.pause_force, true, 'runs while the game-over screen pauses the game')
  eq(w.blocking, false); eq(w.blockable, false)
  ctx.run_timers()
  eq(#ctx.spawned, 0, 'no chip before the overlay')
  G.OVERLAY_MENU = {}
  ctx.run_timers()
  eq(#ctx.spawned, 1)
  eq(ctx.spawned[1].key, 'bl_wall'); eq(ctx.spawned[1].pitch, 0.7, 'the boss voice')
  eq(#ctx.said, 0, 'the line waits for the chip to land')
  for _ = 1, 3 do ctx.run_timers() end
  eq(ctx.keys(), 'fb_bl_wall_early_loss')
  local s = ctx.said[1]
  eq(s.host, G.GAME.blind, 'dialogue hosts it on the avatar chip (host_for)')
  eq(s.pitch, 0.7); eq(s.vars[1], 'Loc bl_wall')
  eq(s.opts.popup, true, 'drawn above the game-over dim')
  eq(s.opts.force, true); eq(s.opts.free, true)
  eq(#ctx.forbidden, 0, 'no memory, nemesis or achievements')
  eq(G.GAME.FinalBoss.lost_to, nil, 'not a loss to that boss')
end

T['on_early_loss: an unreadable or unknown boss says nothing and shows no chip'] = function()
  for _, key in ipairs({false, 'bl_modded_gone'}) do
    local ctx = loss_setup()
    G.GAME.round_resets.blind_choices.Boss = key or nil
    ctx.M.on_early_loss()
    G.OVERLAY_MENU = {}
    for _ = 1, 4 do ctx.run_timers() end
    eq(#ctx.spawned, 0, tostring(key)); eq(#ctx.said, 0, tostring(key))
  end
  local ctx = loss_setup()
  G.GAME.round_resets = nil
  ctx.M.on_early_loss()
  eq(#ctx.timers, 0, 'no round_resets')
end

T['on_early_loss: dialogue off, disabled for the run, a silent light boss, no line: nothing'] = function()
  local cases = {
    function() return loss_setup{dialogue = false} end,
    function() local c = loss_setup(); G.GAME.FinalBoss.disabled_for_run = true; return c end,
    function() return loss_setup{min_ante = 4} end,
    function() local c = loss_setup(); FinalBoss.registry.resolve = function() return nil end; return c end,
  }
  for i, make in ipairs(cases) do
    local ctx = make()
    ctx.M.on_early_loss()
    G.OVERLAY_MENU = {}
    for _ = 1, 4 do ctx.run_timers() end
    eq(#ctx.spawned, 0, 'case ' .. i); eq(#ctx.said, 0, 'case ' .. i)
  end
end

T['on_early_loss: leaving before the overlay, or no overlay at all, drops it'] = function()
  local ctx = loss_setup()
  ctx.M.on_early_loss()
  ctx.M.teardown()
  G.OVERLAY_MENU = {}
  for _ = 1, 4 do ctx.run_timers() end
  eq(#ctx.spawned, 0, 'teardown')
  ctx = loss_setup()
  ctx.M.on_early_loss()
  ctx.run_timers()
  ctx.clock = ctx.M.EARLY_LOSS_WAIT + 1
  ctx.run_timers()
  eq(#ctx.timers, 0, 'gives up')
  G.OVERLAY_MENU = {}
  ctx.run_timers()
  eq(#ctx.spawned, 0)
end

T['on_early_loss: the chip gone before its line (New Run) drops the line'] = function()
  local ctx = loss_setup()
  ctx.M.on_early_loss()
  G.OVERLAY_MENU = {}
  ctx.run_timers()
  eq(#ctx.spawned, 1)
  ctx.avatar.obj = nil
  for _ = 1, 3 do ctx.run_timers() end
  eq(#ctx.said, 0)
end

--- director.lua's on_round_end under stubs: which round ends call the early loss.
local function round_end_setup(o)
  local ctx = {early = 0, forbidden = {}}
  _G.Event = function(t) return t end
  local blind_proto = o.boss and {key = 'bl_hook', boss = {min = 1}} or {key = 'bl_small'}
  _G.G = {
    GAME = {FinalBoss = {encounter = o.enc}, blind = {config = {blind = blind_proto}}},
    E_MANAGER = {add_event = function() end},
    STATES = {GAME_OVER = 4, ROUND_EVAL = 5}, STATE = o.over and 4 or 5,
  }
  local noop = function() end
  package.loaded['src.logic'] = nil
  package.loaded['src.director'] = nil
  _G.FinalBoss = {
    logic = require('src.logic'),
    config = {dialogue = true},
    util = {now = function() return 0 end, log = noop, state = function() return G.GAME.FinalBoss end,
      guard = function(_, f, ...) return pcall(f, ...) end},
    phases = {reset = noop},
    memory = {on_loss = function() return true end, unpresent = noop},
    avatar = {set_hud_tremble = noop}, fx = {stop = noop}, arena = {stop = noop},
    dialogue = {end_intro = noop, hide = noop},
    moments = {on_early_loss = function() ctx.early = ctx.early + 1 end},
  }
  ctx.D = require('src.director')
  FinalBoss.director = ctx.D
  return ctx
end

T['on_round_end: a game over on a small or big blind calls the early loss once'] = function()
  local ctx = round_end_setup{over = true, enc = {key = 'bl_small', boss = false, tier = 'none', fired = {}}}
  ctx.D.on_round_end()
  eq(ctx.early, 1, 'with its (silent) encounter')
  ctx = round_end_setup{over = true, enc = nil}
  ctx.D.on_round_end()
  eq(ctx.early, 1, 'no encounter at all')
end

T['on_round_end: a boss loss or a won round is not an early loss'] = function()
  local ctx = round_end_setup{over = true, boss = true, enc = {key = 'bl_hook', boss = true, tier = 'light', fired = {}}}
  ctx.D.on_round_end()
  eq(ctx.early, 0, 'boss blind')
  ctx = round_end_setup{over = false, enc = {key = 'bl_small', boss = false, tier = 'none', fired = {}}}
  ctx.D.on_round_end()
  eq(ctx.early, 0, 'round won')
end

return T

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

T['preview_due: not over the first blind-select screen of ante 1'] = function()
  local L = logic()
  eq(L.preview_due{ante = 1, tier = 'light', first_select = true}, false)
  eq(L.preview_due{ante = 1, tier = 'light', first_select = false}, true)
  eq(L.preview_due{ante = 2, tier = 'light', first_select = true}, true, 'a loaded run past ante 1')
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

T['on_blind_select: ante 1 waits until the second blind-select screen'] = function()
  local ctx = setup{ante = 1}
  ctx.M.on_blind_select(); ctx.fire_timers()
  eq(#ctx.said, 0, 'not over the deck-select transition')
  ctx.M.on_blind_select(); ctx.fire_timers()
  eq(ctx.keys(), 'fb_bl_hook_preview')
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

return T

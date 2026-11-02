-- Near-miss losses (1.4) under stubs: director.on_round_end picks the moment, moments.on_near_miss
-- puts the boss's chip on the game-over screen, where it laughs and talks on its cue (after Jimbo).
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

-- moments.on_near_miss --------------------------------------------------------------------------------

--- The game-over screen (paused) for a loss to bl_hook; the overlay is not up yet unless opts.gloating
--- (a showdown avatar already gloating). The avatar stub records spawns, cues and laughs.
local function setup(opts)
  opts = opts or {}
  local ctx = {said = {}, timers = {}, spawned = {}, laughs = {}, clock = 0}
  _G.Event = function(def) return def end
  _G.localize = function(args) return 'Loc ' .. args.key end
  package.loaded['src.logic'] = nil
  local L = require('src.logic')
  _G.G = {
    GAME = {round_resets = {ante = 3, blind_choices = {Boss = 'bl_hook'}}, FinalBoss = {},
      blind = {config = {blind = {key = 'bl_hook', boss = {min = 1}}}}},
    SETTINGS = {paused = true, reduced_motion = false}, TIMERS = {REAL = 0}, OVERLAY_MENU = nil,
    P_BLINDS = {bl_hook = {name = 'The Hook', boss = {min = 1}},
      bl_final_leaf = {name = 'Verdant Leaf', boss = {showdown = true}}},
    E_MANAGER = {add_event = function(_, e) e.queued_at = ctx.clock; ctx.timers[#ctx.timers + 1] = e end},
  }
  local A = {obj = opts.gloating and {name = 'avatar'} or nil, gloating = opts.gloating or false, cue = nil}
  ctx.A = A
  _G.FinalBoss = {
    logic = L,
    config = {dialogue = opts.dialogue ~= false, fx = opts.fx ~= false, min_ante = 1},
    util = {guard = function(_, fn, ...) return pcall(fn, ...) end, log = function() end,
      now = function() return ctx.clock end,
      state = function() G.GAME.FinalBoss = G.GAME.FinalBoss or {}; return G.GAME.FinalBoss end},
    director = {enabled = function() return not G.GAME.FinalBoss.disabled_for_run end},
    registry = {get = function(key) return {voice = {pitch = key == 'bl_hook' and 0.8 or 1}} end,
      resolve = function(key, moment) return 'fb_' .. key .. '_' .. moment end},
    dialogue = {say = function(host, key, vars, pitch, o)
      ctx.said[#ctx.said + 1] = {host = host, key = key, vars = vars, pitch = pitch, opts = o}
      return true
    end},
    avatar = {
      anchor = function() return A.obj end,
      on_game_over_screen = function() return G.OVERLAY_MENU ~= nil end,
      spawn_gloat = function(key, pitch)
        ctx.spawned[#ctx.spawned + 1] = {key = key, pitch = pitch}
        A.obj, A.gloating = {name = 'chip ' .. key}, true
        return true
      end,
      gloat_cue = function(fn)
        if not (A.obj and A.gloating) then return false end
        A.cue = fn
        return true
      end,
      laugh = function(pitch, o)
        ctx.laughs[#ctx.laughs + 1] = {pitch = pitch, beats = o and o.beats, still = o and o.still}
        return 1.0
      end,
    },
  }
  package.loaded['src.moments'] = nil
  ctx.M = require('src.moments')
  --- Advance the REAL clock and run due events (a repeating one, returning false, stays queued).
  function ctx.run(t)
    ctx.clock = t or ctx.clock
    local queued = ctx.timers
    ctx.timers = {}
    for _, e in ipairs(queued) do
      local due = e.trigger ~= 'after' or (e.queued_at or 0) + (e.delay or 0) <= ctx.clock
      if not (due and e.func() ~= false) then ctx.timers[#ctx.timers + 1] = e end
    end
  end
  --- The avatar's cue fires (avatar.gloat_tick: a beat after Jimbo finishes).
  function ctx.cue()
    local fn = A.cue
    A.cue = nil
    if fn then fn() end
  end
  return ctx
end

T['on_near_miss: a regular boss comes out on the game-over screen, laughs on its cue, then talks'] = function()
  local ctx = setup()
  ctx.M.on_near_miss('bl_hook', 'near_miss')
  eq(#ctx.timers, 1, 'waits for the overlay')
  local w = ctx.timers[1]
  eq(w.pause_force, true, 'runs on the paused game-over screen'); eq(w.blocking, false); eq(w.blockable, false)
  ctx.run(0.1)
  eq(#ctx.spawned, 0, 'no chip before the overlay')
  G.OVERLAY_MENU = {}
  ctx.run(0.2)
  eq(#ctx.spawned, 1); eq(ctx.spawned[1].key, 'bl_hook'); eq(ctx.spawned[1].pitch, 0.8)
  eq(type(ctx.A.cue), 'function', 'the cue replaces the gloat laugh')
  eq(#ctx.laughs, 0, 'nothing until Jimbo is done')
  ctx.run(3.8); ctx.cue()
  eq(#ctx.laughs, 1, 'one laugh')
  eq(ctx.laughs[1].beats, FinalBoss.logic.LAUGH.beats); eq(ctx.laughs[1].still, false); eq(ctx.laughs[1].pitch, 0.8)
  eq(#ctx.said, 0, 'the line waits for the laugh')
  ctx.run(4.7)
  eq(#ctx.said, 0)
  ctx.run(4.8)
  eq(#ctx.said, 1)
  local s = ctx.said[1]
  eq(s.key, 'fb_bl_hook_near_miss'); eq(s.host, G.GAME.blind, 'dialogue hosts it on the chip')
  eq(s.opts.popup, true, 'above the dim'); eq(s.opts.force, true); eq(s.opts.free, true)
  eq(s.vars[1], 'Loc bl_hook'); eq(s.pitch, 0.8)
  eq(ctx.timers[1] and ctx.timers[1].pause_force, nil, 'nothing left queued')
end

T['on_near_miss: one_chip laughs longer and says its own line'] = function()
  local ctx = setup()
  ctx.M.on_near_miss('bl_hook', 'one_chip')
  G.OVERLAY_MENU = {}
  ctx.run(0.1); ctx.cue()
  eq(ctx.laughs[1].beats, FinalBoss.logic.ONE_CHIP_BEATS)
  ctx.run(5)
  eq(ctx.said[1].key, 'fb_bl_hook_one_chip')
end

T['on_near_miss: a showdown avatar already gloating gets the cue, no second chip'] = function()
  local ctx = setup{gloating = true}
  ctx.M.on_near_miss('bl_final_leaf', 'near_miss')
  eq(#ctx.spawned, 0)
  eq(type(ctx.A.cue), 'function')
  ctx.cue()
  eq(#ctx.laughs, 1); eq(ctx.laughs[1].pitch, 1)
  ctx.run(2)
  eq(ctx.said[1].key, 'fb_bl_final_leaf_near_miss')
end

T['on_near_miss: dialogue off laughs without a line; fx off laughs still'] = function()
  local ctx = setup{dialogue = false}
  ctx.M.on_near_miss('bl_hook', 'one_chip')
  G.OVERLAY_MENU = {}
  ctx.run(0.1); ctx.cue(); ctx.run(5)
  eq(#ctx.laughs, 1); eq(#ctx.said, 0)
  ctx = setup{fx = false}
  ctx.M.on_near_miss('bl_hook', 'near_miss')
  G.OVERLAY_MENU = {}
  ctx.run(0.1); ctx.cue()
  eq(ctx.laughs[1].still, true)
end

T['on_near_miss: disabled for the run, or an unknown boss: nothing'] = function()
  local ctx = setup()
  G.GAME.FinalBoss.disabled_for_run = true
  ctx.M.on_near_miss('bl_hook', 'near_miss')
  G.OVERLAY_MENU = {}
  ctx.run(0.1)
  eq(#ctx.timers, 0); eq(#ctx.spawned, 0)
  ctx = setup()
  ctx.M.on_near_miss('bl_modded_gone', 'near_miss')
  G.OVERLAY_MENU = {}
  ctx.run(0.1)
  eq(#ctx.spawned, 0)
  ctx = setup()
  ctx.M.on_near_miss(nil, 'near_miss')
  eq(#ctx.timers, 0)
end

T['on_near_miss: teardown cancels at every step'] = function()
  -- before the overlay
  local ctx = setup()
  ctx.M.on_near_miss('bl_hook', 'near_miss')
  ctx.M.teardown()
  G.OVERLAY_MENU = {}
  ctx.run(0.1)
  eq(#ctx.spawned, 0, 'before the overlay')
  -- after the chip, before its cue
  ctx = setup()
  ctx.M.on_near_miss('bl_hook', 'near_miss')
  G.OVERLAY_MENU = {}
  ctx.run(0.1)
  ctx.M.teardown()
  ctx.cue()
  eq(#ctx.laughs, 0, 'before the cue')
  -- between the laugh and the line
  ctx = setup()
  ctx.M.on_near_miss('bl_hook', 'near_miss')
  G.OVERLAY_MENU = {}
  ctx.run(0.1); ctx.cue()
  ctx.M.teardown()
  ctx.run(5)
  eq(#ctx.laughs, 1); eq(#ctx.said, 0, 'mid-laugh')
  -- the chip gone (New Run) before the line
  ctx = setup()
  ctx.M.on_near_miss('bl_hook', 'near_miss')
  G.OVERLAY_MENU = {}
  ctx.run(0.1); ctx.cue()
  ctx.A.obj = nil
  ctx.run(5)
  eq(#ctx.said, 0, 'chip gone')
  -- no overlay ever: gives up
  ctx = setup()
  ctx.M.on_near_miss('bl_hook', 'near_miss')
  ctx.run(ctx.M.EARLY_LOSS_WAIT + 1)
  eq(#ctx.timers, 0, 'gives up')
end

-- director.on_round_end ----------------------------------------------------------------------------------

--- A round end on bl_hook: over (game over) or not (Mr. Bones saved it, or a win), with the final round
--- score chips against required. o.enc overrides encounter fields.
local function round_end(o)
  local ctx = {calls = {}, order = {}}
  _G.Event = function(t) return t end
  local enc = {key = 'bl_hook', boss = true, tier = 'light', fired = {}}
  for k, v in pairs(o.enc or {}) do enc[k] = v end
  _G.G = {
    GAME = {FinalBoss = {encounter = enc, lost_to = o.lost_to == nil and 'bl_hook' or (o.lost_to or nil)},
      blind = {chips = o.required or 1000, config = {blind = {key = 'bl_hook', boss = {min = 1}}}},
      chips = o.chips},
    E_MANAGER = {add_event = function() end},
    STATES = {GAME_OVER = 4, ROUND_EVAL = 5}, STATE = o.over == false and 5 or 4,
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
    memory = {unpresent = noop, on_loss = function() return true end},
    avatar = {set_hud_tremble = noop}, fx = {stop = noop}, arena = {stop = noop},
    dialogue = {end_intro = noop, hide = noop},
    registry = {get = function() return {voice = {pitch = 1}} end},
    cinematic = {game_over = function() ctx.order[#ctx.order + 1] = 'gloat' end},
    moments = {on_early_loss = function() ctx.order[#ctx.order + 1] = 'early' end,
      on_near_miss = function(key, moment)
        ctx.calls[#ctx.calls + 1] = {key = key, moment = moment}
        ctx.order[#ctx.order + 1] = 'near_miss'
      end},
  }
  ctx.D = require('src.director')
  FinalBoss.director = ctx.D
  ctx.D.on_round_end()
  return ctx
end

T['on_round_end: losing the last hand at 96% is a near miss; 1 chip short is one_chip'] = function()
  local ctx = round_end{chips = 960}
  eq(#ctx.calls, 1); eq(ctx.calls[1].key, 'bl_hook'); eq(ctx.calls[1].moment, 'near_miss')
  ctx = round_end{chips = 999}
  eq(ctx.calls[1].moment, 'one_chip')
  ctx = round_end{chips = 950, enc = {tier = 'full'}}
  eq(ctx.calls[1].moment, 'near_miss', 'full tier too')
end

T['on_round_end: the showdown avatar gloats before the near miss hooks into it'] = function()
  local ctx = round_end{chips = 999, enc = {cinematic = true, showdown = true, tier = 'full'}}
  eq(table.concat(ctx.order, ','), 'gloat,near_miss')
end

T['on_round_end: no near miss when the run goes on, or nothing is readable'] = function()
  local cases = {
    {over = false, chips = 960},                -- Mr. Bones saved it (vanilla resolved it first)
    {chips = 940},                              -- below 95%
    {chips = 1000, over = false},               -- won
    {chips = {big = true}},                     -- unreadable (a big-number table, no to_number)
    {chips = nil},
    {chips = 960, enc = {unknown_hand = 3}},    -- the last hand's outcome was unknown
    {chips = 960, lost_to = false},             -- not lost on this boss's last hand
    {chips = 960, enc = {tier = 'none'}},       -- a silent boss
    {chips = 960, enc = {boss = false}},        -- not a boss
  }
  for i, c in ipairs(cases) do
    local ctx = round_end(c)
    eq(#ctx.calls, 0, 'case ' .. i)
  end
end

return T

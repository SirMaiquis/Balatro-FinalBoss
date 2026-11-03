-- avatar.lua under stubs: the gloating chip's near-miss cue (1.4) replaces its single laugh, and fires
-- a beat after Jimbo finishes his quip.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

--- A gloating chip on vanilla's game-over overlay; ctx.jimbo(talking) puts Jimbo in his spot.
local function setup()
  local ctx = {clock = 0, sounds = {}, events = {}}
  _G.Event = function(t) return t end
  _G.Moveable = {extend = function() return setmetatable({}, {__call = function() return {} end}) end}
  _G.play_sound = function(name, pitch) ctx.sounds[#ctx.sounds + 1] = {name = name, pitch = pitch} end
  package.loaded['src.logic'] = nil
  _G.FinalBoss = {logic = require('src.logic'),
    config = {fx = true},
    util = {now = function() return ctx.clock end, guard = function(_, f, ...) return pcall(f, ...) end,
      log = function() end}}
  local spot = {config = {object = {}}} -- before Jimbo: a plain Moveable
  ctx.spot = spot
  local menu = {UIRoot = {children = {}}, get_UIE_by_ID = function(_, id) if id == 'jimbo_spot' then return spot end end}
  _G.G = {SETTINGS = {reduced_motion = false, paused = true}, OVERLAY_MENU = menu, I = {MOVEABLE = {}, POPUP = {}},
    ROOM = {T = {w = 20, h = 11.5}},
    E_MANAGER = {add_event = function(_, e) ctx.events[#ctx.events + 1] = e end}}
  package.loaded['src.avatar'] = nil
  local V = require('src.avatar')
  ctx.V = V
  V.obj = {T = {x = 0, y = 0, w = 2, h = 2}, states = {collide = {}, click = {}, hover = {}},
    children = {sprite = {}}, velocity = {x = 0, y = 0}, hard_set_VT = function() end}
  V.gloat(1)
  function ctx.jimbo(talking)
    spot.config.object = {talking = talking, children = {speech_bubble = {}}}
  end
  function ctx.at(t) ctx.clock = t; V.tick(0) end
  function ctx.laughs() -- accent thuds: one per laugh
    local n = 0
    for _, s in ipairs(ctx.sounds) do if s.name == 'multhit1' then n = n + 1 end end
    return n
  end
  return ctx
end

T['gloat: without a cue, one laugh a beat after Jimbo starts (unchanged)'] = function()
  local ctx = setup()
  ctx.at(1); ctx.jimbo(true); ctx.at(2.6)
  eq(ctx.laughs(), 0)
  ctx.at(2.6 + ctx.V.GLOAT_LAUGH_DELAY)
  eq(ctx.laughs(), 1)
  ctx.at(8)
  eq(ctx.laughs(), 1, 'once')
end

T['gloat_cue: replaces the single laugh, fires a beat after Jimbo stops talking'] = function()
  local ctx = setup()
  local fired = 0
  eq(ctx.V.gloat_cue(function() fired = fired + 1 end), true)
  ctx.at(2.5); ctx.jimbo(true)
  ctx.at(2.5 + ctx.V.GLOAT_LAUGH_DELAY + 0.1)
  eq(ctx.laughs(), 0, 'no single laugh while a cue waits')
  eq(fired, 0, 'Jimbo still talking')
  ctx.spot.config.object.talking = false
  ctx.at(3.3)
  eq(fired, 0, 'not on his last syllable')
  ctx.at(3.3 + FinalBoss.logic.GLOAT_CUE.beat + 0.01)
  eq(fired, 1, 'a beat after he finished')
  ctx.at(9)
  eq(fired, 1); eq(ctx.laughs(), 0, 'the cue owns the laugh: no second one')
  eq(ctx.V.gloat_cue(function() end), false, 'too late for another cue')
end

T['gloat_cue: no Jimbo (past the win ante) fires at the late fallback'] = function()
  local ctx = setup()
  local fired = 0
  ctx.V.gloat_cue(function() fired = fired + 1 end)
  ctx.at(FinalBoss.logic.GLOAT_CUE.late - 0.1)
  eq(fired, 0)
  ctx.at(FinalBoss.logic.GLOAT_CUE.late)
  eq(fired, 1)
end

T['gloat_cue: not gloating, or the screen already went: false'] = function()
  local ctx = setup()
  ctx.V.gloating = nil
  eq(ctx.V.gloat_cue(function() end), false, 'not gloating')
  ctx = setup()
  ctx.V.gloating.leaving = true
  eq(ctx.V.gloat_cue(function() end), false, 'leaving')
end

T['laugh: beats lengthen it; still drops the motion window'] = function()
  local ctx = setup()
  local L = FinalBoss.logic
  local d = ctx.V.laugh(1, {beats = 10})
  eq(d, L.laugh_duration(10))
  eq(ctx.V.laugh_until - ctx.V.laugh_start, L.laugh_duration(10), 'motion window covers every beat')
  eq(ctx.V.laugh_beats, 10)
  local n = #ctx.events
  ctx.V.laugh_until = 0
  d = ctx.V.laugh(1, {beats = 10, still = true})
  eq(ctx.V.laugh_until, 0, 'still: no hop, tilt or shake')
  eq(#ctx.events - n, 10, 'still: every beat still sounds')
  eq(ctx.V.laugh(1), L.laugh_duration(), 'default laugh unchanged')
  eq(ctx.V.laugh_beats, L.LAUGH.beats)
end

return T

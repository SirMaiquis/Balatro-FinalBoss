-- phases.lua routing under stubs (no game): when a transformation starts, the weak-hit delay, the
-- timeline steps and their gates (reduced motion, Boss moves), Continue restore, F8 and reset.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

--- Fresh phases module with stubbed globals and a REAL-time event queue driven by ctx.advance(s).
local function setup(opts)
  opts = opts or {}
  local ctx = {calls = {}, args = {}, clock = 0, events = {}}
  local function rec(name, ret)
    return function(...)
      ctx.calls[#ctx.calls + 1] = name
      ctx.args[name] = {...}
      return ret
    end
  end
  function ctx.count(name)
    local n = 0
    for _, c in ipairs(ctx.calls) do if c == name then n = n + 1 end end
    return n
  end
  function ctx.advance(seconds)
    local stop = ctx.clock + seconds
    while true do
      local best
      for i, e in ipairs(ctx.events) do
        if e.at <= stop and (not best or e.at < ctx.events[best].at) then best = i end
      end
      if not best then break end
      local e = table.remove(ctx.events, best)
      ctx.clock = e.at
      e.func()
    end
    ctx.clock = stop
  end
  local enc = {key = 'bl_final_x', showdown = true, cinematic = true, fired = {}, ended = false}
  local blind = {config = {blind = {key = 'bl_final_x'}}}
  ctx.enc, ctx.blind = enc, blind
  _G.G = {SETTINGS = {reduced_motion = opts.reduced or false},
    GAME = {FinalBoss = {encounter = enc}, blind = blind},
    E_MANAGER = {add_event = function(_, ev) ctx.events[#ctx.events + 1] = {at = ctx.clock + (ev.delay or 0), func = ev.func} end}}
  _G.Event = function(t) return t end
  _G.play_sound = rec('sound')
  package.loaded['src.logic'] = nil
  _G.FinalBoss = {
    timescale = 1,
    logic = require('src.logic'),
    config = {cinematic = true, fx = true, moves = opts.moves ~= false},
    avatar = {exists = function() return not opts.no_avatar end, roar = rec('roar'), flash = rec('avatar_flash'),
      set_stance = rec('set_stance')},
    hpbar = {set_phase = rec('set_phase')},
    moves = {hold = rec('hold'), boss_colour = function() return {1, 0, 0, 1} end,
      performer = function() return {x = 0, y = 0, w = 1, h = 1} end, voice = function() return 1 end,
      signature = rec('signature')},
    effects = {ring = rec('ring')},
    fx = {play = rec('fx_flash')},
    music = {duck = rec('duck'), unduck = rec('unduck')},
    director = {fire = rec('fire', true)},
    arena = {state = {stage = 1}, on_hit = rec('arena_hit')},
    util = {guard = function(_, fn, ...) return pcall(fn, ...) end, log = function() end},
  }
  package.loaded['src.phases'] = nil
  return require('src.phases'), ctx
end

-- 1000 HP: a total of 600 leaves 40% (phase II), 800 leaves 20% (phase III).
local function hand(total, moment, hands_left)
  return {total = total, required = 1000, moment = moment, hands_left = hands_left or 2}
end

T['phases.check: crossing 50% starts phase II at once and records it'] = function()
  local P, ctx = setup()
  eq(P.check(ctx.enc, ctx.blind, hand(600)), true)
  eq(ctx.enc.phase, 2, 'enc.phase')
  eq(ctx.count('hold'), 1, 'moves held')
  eq(FinalBoss.timescale, P.SLOW, 'slow motion')
  ctx.advance(2)
  eq(FinalBoss.timescale, 1, 'time restored')
  eq(ctx.args.fire[1], 'phase2', 'phase line')
  eq(ctx.args.fire[2].force, true, 'forced')
  eq(ctx.args.set_stance[1], 2, 'stance')
  eq(ctx.args.set_phase[1], 2, 'marker')
  eq(ctx.count('signature'), 1, 'eruption')
  eq(ctx.count('roar'), 1, 'roar')
end

T['phases.check: no transformation above 50%, on the defeat hand or the last hand'] = function()
  local P, ctx = setup()
  eq(P.check(ctx.enc, ctx.blind, hand(300)), false, 'above 50%')
  eq(P.check(ctx.enc, ctx.blind, hand(1000, 'defeat')), false, 'defeat')
  eq(P.check(ctx.enc, ctx.blind, hand(600, nil, 0)), false, 'last hand')
  eq(ctx.enc.phase, nil, 'still phase I')
  eq(ctx.count('hold'), 0)
end

T['phases.check: both thresholds at once go straight to phase III, never back'] = function()
  local P, ctx = setup()
  eq(P.check(ctx.enc, ctx.blind, hand(800)), true)
  eq(ctx.enc.phase, 3)
  ctx.advance(2)
  eq(ctx.args.fire[1], 'phase3')
  eq(P.check(ctx.enc, ctx.blind, hand(600)), false, 'a heal never undoes a phase')
  eq(P.check(ctx.enc, ctx.blind, hand(900)), false, 'phase III is the last')
end

T['phases.check: a weak hit waits for the laugh before transforming'] = function()
  local P, ctx = setup()
  eq(P.check(ctx.enc, ctx.blind, hand(600), 1.2), true)
  eq(ctx.enc.phase, 2, 'recorded at once (a save keeps it)')
  eq(ctx.count('hold'), 0, 'not started yet')
  eq(FinalBoss.timescale, 1, 'no slow motion during the laugh')
  ctx.advance(1.1)
  eq(ctx.count('hold'), 0, 'still waiting')
  ctx.advance(0.2)
  eq(ctx.count('hold'), 1, 'started after the laugh')
  ctx.advance(2)
  eq(ctx.args.fire[1], 'phase2')
end

T['phases.check: a reset during the laugh cancels the pending transformation'] = function()
  local P, ctx = setup()
  P.check(ctx.enc, ctx.blind, hand(600), 1.2)
  P.reset()
  ctx.advance(3)
  eq(ctx.count('hold'), 0)
  eq(ctx.count('fire'), 0)
end

T['phases.check: needs a cinematic showdown with the avatar out'] = function()
  local P, ctx = setup({no_avatar = true})
  eq(P.check(ctx.enc, ctx.blind, hand(600)), false, 'no avatar')
  P, ctx = setup()
  FinalBoss.config.cinematic = false
  eq(P.check(ctx.enc, ctx.blind, hand(600)), false, 'cinematics off')
  P, ctx = setup()
  ctx.enc.showdown = false
  eq(P.check(ctx.enc, ctx.blind, hand(600)), false, 'not a showdown')
end

T['phases.transform: reduced motion keeps flash, line, stance and marker only'] = function()
  local P, ctx = setup({reduced = true})
  P.transform(ctx.enc, ctx.blind, 2, 1)
  eq(FinalBoss.timescale, 1, 'no slow motion')
  ctx.advance(2)
  eq(ctx.count('roar'), 0, 'roar')
  eq(ctx.count('ring'), 0, 'rings')
  eq(ctx.count('signature'), 0, 'eruption')
  eq(ctx.count('fx_flash'), 1, 'flash')
  eq(ctx.count('fire'), 1, 'line')
  eq(ctx.count('set_stance'), 1, 'stance')
  eq(ctx.count('set_phase'), 1, 'marker')
end

T['phases.transform: Boss moves off skips the eruption only'] = function()
  local P, ctx = setup({moves = false})
  P.transform(ctx.enc, ctx.blind, 2, 1)
  ctx.advance(2)
  eq(ctx.count('signature'), 0, 'eruption')
  eq(ctx.count('roar'), 1, 'roar')
  eq(ctx.count('fire'), 1, 'line')
end

T['phases.transform: the encounter ending stops the rest but restores time and music'] = function()
  local P, ctx = setup()
  P.transform(ctx.enc, ctx.blind, 2, 1)
  ctx.enc.ended = true
  ctx.advance(2)
  eq(ctx.count('fire'), 0, 'line')
  eq(ctx.count('set_stance'), 0, 'stance')
  eq(FinalBoss.timescale, 1, 'time')
  eq(ctx.count('unduck') >= 1, true, 'music')
end

T['phases.transform: the slow-motion restore never clobbers the finale'] = function()
  local P, ctx = setup()
  P.transform(ctx.enc, ctx.blind, 2, 1)
  FinalBoss.timescale = 0.2 -- someone else took the time over
  ctx.advance(2)
  eq(FinalBoss.timescale, 0.2)
end

T['phases.restore: stance and marker come back without replaying; 1.0 saves stay phase I'] = function()
  local P, ctx = setup()
  P.restore(ctx.enc, ctx.blind)
  eq(#ctx.calls, 0, 'no enc.phase: nothing')
  ctx.enc.phase = 3
  P.restore(ctx.enc, ctx.blind)
  eq(ctx.args.set_stance[1], 3)
  eq(ctx.args.set_phase[1], 3)
  eq(ctx.count('hold') + ctx.count('fire') + ctx.count('roar'), 0, 'no replay')
end

T['phases.force_next: II, then III, then nil'] = function()
  local P, ctx = setup()
  eq(P.force_next(), 2)
  ctx.advance(2)
  eq(P.force_next(), 3)
  ctx.advance(2)
  eq(P.force_next(), nil)
  eq(ctx.count('fire'), 2)
end

T['phases.reset: restores our slow motion and the music'] = function()
  local P, ctx = setup()
  P.transform(ctx.enc, ctx.blind, 2, 1)
  P.reset()
  eq(FinalBoss.timescale, 1)
  eq(ctx.count('unduck'), 1)
  ctx.advance(2)
  eq(ctx.count('fire'), 0, 'pending steps cancelled')
end

return T

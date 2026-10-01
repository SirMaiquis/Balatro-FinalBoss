--- Living arena (spec 2026-10-01 §8): boss-coloured background swirl for showdowns, darker and
--- faster as the boss loses HP, plus a final-stretch music pitch nudge. Vanilla hardcodes a
--- blue/red background for every showdown; hooks.lua re-applies ours after each vanilla refresh.
local A = {}
A.PULSE = 0.3        -- seconds of the per-hit contrast spike
A.PULSE_BOOST = 1.0
A.SHOWDOWN_SPIN = 0.5 -- vanilla G.ARGS.spin.real for a showdown (blind.lua set_blind)
A.state = nil        -- {colour, stage, base_spin, pulse_until, last_spin}

local function reduced() return G.SETTINGS.reduced_motion end

function A.active() return A.state ~= nil end

function A.apply()
  local s = A.state
  if not s then return end
  local p = FinalBoss.logic.arena_params(s.stage)
  local pulsing = (not reduced()) and FinalBoss.util.now() < s.pulse_until
  ease_background_colour{
    new_colour = mix_colours(s.colour, G.C.BLACK, 1 - p.black_mix),
    special_colour = s.colour,
    tertiary_colour = darken(G.C.BLACK, 0.4),
    contrast = p.contrast + (pulsing and A.PULSE_BOOST or 0),
  }
  if G.ARGS.spin and not reduced() then
    s.last_spin = s.base_spin * p.spin_mult
    G.ARGS.spin.real = s.last_spin
  end
end

--- base_spin: vanilla's showdown spin. Read from G.ARGS.spin.real on a fresh blind (set_blind has
--- just written it); on Continue vanilla never sets it (Blind:load), so the caller passes the constant.
function A.start(blind, stage, base_spin)
  if not FinalBoss.config.fx then return end
  local c = (blind.config.blind and blind.config.blind.boss_colour) or G.C.RED
  A.state = {colour = {c[1], c[2], c[3], 1}, stage = stage or 0,
    base_spin = base_spin or (G.ARGS.spin and G.ARGS.spin.real) or 0, pulse_until = 0}
  A.apply()
end

function A.resume(blind, stage)
  A.start(blind, stage, reduced() and 0 or A.SHOWDOWN_SPIN)
end

function A.on_hit(stage)
  local s = A.state
  if not s then return end
  s.stage = stage
  if not reduced() then s.pulse_until = FinalBoss.util.now() + A.PULSE end
  A.apply()
  if not reduced() then
    G.E_MANAGER:add_event(Event({trigger = 'after', delay = A.PULSE + 0.02, timer = 'REAL',
      blocking = false, blockable = false,
      func = function() FinalBoss.util.guard('arena_pulse_end', A.apply); return true end}))
  end
end

--- Final stretch: nudge the global pitch each frame (vanilla eases it back toward 1).
function A.tick(dt)
  local s = A.state
  if not s or not FinalBoss.config.music then return end
  local enc = G.GAME and G.GAME.FinalBoss and G.GAME.FinalBoss.encounter
  if not enc or enc.ended then return end
  local p = FinalBoss.logic.arena_params(s.stage)
  if p.pitch ~= 1 then G.PITCH_MOD = p.pitch end
end

--- Hand the spin back to vanilla, unless vanilla has since set its own (Blind:defeat sets the
--- win spin before blind_defeated fires: keep that).
local function restore_spin(s)
  if s and G.ARGS.spin and s.last_spin and G.ARGS.spin.real == s.last_spin then
    G.ARGS.spin.real = s.base_spin
  end
end

--- Encounter over (defeat or game over): hand the background back to vanilla.
function A.stop()
  local s = A.state
  if not s then return end
  A.state = nil
  restore_spin(s)
  local ok, err = pcall(ease_background_colour_blind, G.STATE)
  if not ok then FinalBoss.util.log('warn', 'arena restore failed: ' .. tostring(err)) end
end

--- Run teardown or guard failure: forget the arena (vanilla repaints on the next blind).
function A.reset()
  restore_spin(A.state)
  A.state = nil
end

return A

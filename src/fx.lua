--- Screen effects for full-tier encounters. Respects config.fx and the game's reduced-motion
--- setting (screen-shake strength is already scaled by vanilla from G.SETTINGS.screenshake).
local F = {}
F.PEAK = 0.8   -- vignette intensity during the intro
F.HOLD = 0.35  -- vignette intensity for the rest of the fight
F.vignette = {intensity = 0}
F.tint = {1, 1, 1}
F.gen = 0      -- bumped by stop() to cancel pending eases

SMODS.Shader{key = 'vignette', path = 'vignette.fs'}
SMODS.ScreenShader{
  key = 'vignette_screen',
  order = 1, -- after vanilla's CRT pass (order 0)
  shader = FinalBoss.mod.prefix .. '_vignette',
  should_apply = function(self) return FinalBoss.config.fx and F.vignette.intensity > 0.001 end,
  send_vars = function(self) return {fb_intensity = F.vignette.intensity, fb_tint = {array = {F.tint}}} end,
}

local function enabled() return FinalBoss.config.fx end
local function reduced() return G.SETTINGS.reduced_motion end

local function boss_colour(blind)
  return (blind and blind.config.blind and blind.config.blind.boss_colour) or G.C.RED
end

-- An ease started before a stop() must not fight the fade-out: once F.gen moves on, the stale
-- ease writes back the current value (a no-op) instead of its own interpolation.
local function ease_vignette(to, duration)
  local gen = F.gen
  G.E_MANAGER:add_event(Event({trigger = 'ease', ref_table = F.vignette, ref_value = 'intensity',
    ease_to = to, delay = duration, timer = 'REAL', blocking = false, blockable = false,
    func = function(t) if F.gen ~= gen then return F.vignette.intensity end; return t end}))
end

local function later(delay, gen, fn)
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = delay, timer = 'REAL', blocking = false, blockable = false,
    func = function() if F.gen == gen then fn() end; return true end}))
end

local function set_tint(blind)
  local c = boss_colour(blind)
  F.tint = {c[1], c[2], c[3]}
end

local EFFECTS = {}

function EFFECTS.pulse(blind)
  set_tint(blind)
  if reduced() then F.vignette.intensity = F.HOLD; return end
  local gen = F.gen
  ease_vignette(F.PEAK, 1.0)
  later(2.5, gen, function() ease_vignette(F.HOLD, 1.5) end)
end

function EFFECTS.shake(blind)
  if reduced() then return end
  G.ROOM.jiggle = G.ROOM.jiggle + 1.5
end

-- `restore_as` is vanilla's blind_override for the colour to go back to ('' = neutral Small Blind
-- colour, used when the boss was just defeated and vanilla is easing to neutral itself).
-- The restore is deliberately NOT cancelled by stop(): stop() runs right after shatter, and a
-- cancelled restore would leave the background stuck on the flash colour.
function EFFECTS.flash(blind, restore_as)
  local c = boss_colour(blind)
  ease_background_colour{new_colour = lighten(c, 0.2), special_colour = darken(c, 0.4), contrast = 2}
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = 0.5, timer = 'REAL', blocking = false, blockable = false,
    func = function()
      local ok, err = pcall(ease_background_colour_blind, G.STATE, restore_as)
      if not ok then FinalBoss.util.log('warn', 'flash restore failed: ' .. tostring(err)) end
      return true
    end}))
end

function EFFECTS.shatter(blind)
  if not blind then return end
  local p = Particles(1, 1, 0, 0, {timer = 0.01, scale = 0.3, speed = 4, lifespan = 1.2, attach = blind,
    colours = {G.C.WHITE, boss_colour(blind)}, fill = true})
  play_sound('glass1', 0.9, 0.6)
  EFFECTS.flash(blind, '')
  -- Unconditional (not gated by F.gen): the director calls stop() right after shatter.
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = 0.6, timer = 'REAL', blocking = false, blockable = false,
    func = function() p:fade(0.5); return true end}))
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = 1.4, timer = 'REAL', blocking = false, blockable = false,
    func = function() p:remove(); return true end}))
end

function EFFECTS.phase_shift(blind)
  EFFECTS.flash(blind)
  EFFECTS.shake(blind)
  set_tint(blind)
  if reduced() then F.vignette.intensity = F.HOLD; return end
  local gen = F.gen
  ease_vignette(1.0, 0.3)
  later(0.8, gen, function() ease_vignette(F.HOLD, 1.0) end)
end

function F.play(name, blind)
  if not enabled() or not name or not EFFECTS[name] then return end
  EFFECTS[name](blind)
end

function F.stop()
  F.gen = F.gen + 1
  if reduced() then F.vignette.intensity = 0 else ease_vignette(0, 1.0) end
end

--- Leaving a run (menu, restart, new run): vanilla clears the event queue, so reset the state here.
function F.reset()
  F.gen = F.gen + 1
  F.vignette.intensity = 0
  F.tint = {1, 1, 1}
end

--- Continuing a saved run mid-showdown: put the vignette back at its hold level.
function F.resume(blind)
  if not enabled() then return end
  set_tint(blind)
  F.vignette.intensity = F.HOLD
end

return F

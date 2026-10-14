--- Final-boss deaths (1.1): the explode step of the 1.0 finale (cinematic.play_finale) asks D.play
--- first. Slow motion, timing and the single-explosion guarantee (enc.finale) stay in cinematic.lua
--- and director.lua. A boss without a death (modded final bosses) keeps the 1.0 explosion, and so
--- does everyone when screen effects are off. Colours come from moves.boss_colour / moves.step_colour.
local D = {}
local DEATHS = {}
local common_ran = false -- set by common(): a failure after it must not play the 1.0 explosion on top

--- Effects a modder's death recipe may use (the others need targets a death does not have).
local SAFE = {burst = true, ring = true, crack = true, sweep = true}

local function E() return FinalBoss.effects end

local function later(delay, fn)
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = delay, timer = 'REAL', blocking = false,
    blockable = false, func = function() FinalBoss.util.guard('death_timer', fn); return true end}))
end

--- What every death shares with the 1.0 explosion: a flash back to the neutral colour vanilla eases
--- to after a win ('' restore) and a shake (smaller under reduced motion, as in 1.0).
local function common(blind, calm)
  FinalBoss.fx.play('flash', blind, '')
  common_ran = true
  G.ROOM.jiggle = G.ROOM.jiggle + (calm and 2 or 6)
end

--- Crimson Heart: shatters into heart-shaped bursts.
function DEATHS.hearts(blind, src, calm)
  common(blind, calm)
  E().scatter(src, {shape = 'heart', colour = src.colour, count = 14, spread = 3, size = 0.5})
  E().burst(src, nil, {colour = src.colour, scale = 1.5})
  play_sound('glass1', 0.8, 0.6)
  play_sound('explosion_release1', 1.1, 0.5)
end

--- Verdant Leaf: a gust of leaves blows the chip away (to the right).
function DEATHS.leaves(blind, src, calm)
  common(blind, calm)
  E().scatter(src, {shape = 'leaf', colour = src.colour, count = 18, spread = 1.5, dx = 5, dy = -1,
    size = 0.4, life = 1.4})
  if G.play and G.play.T then E().sweep(src, G.play, {colour = src.colour}) end
  play_sound('whoosh_long', 1.1, 0.6)
  play_sound('paper1', 0.8, 0.5)
end

--- Amber Acorn: cracks open (a split flash over the chip + shell shards).
function DEATHS.acorn(blind, src, calm)
  common(blind, calm)
  E().crack(src, {T = {x = src.x, y = src.y, w = src.w, h = src.h}}, {colour = src.colour, bare = true})
  E().scatter(src, {shape = 'glyph', glyph = 'crack', colour = darken(src.colour, 0.3), count = 10,
    spread = 2, size = 0.5})
  E().burst(src, nil, {colour = src.colour, scale = 1.2})
  play_sound('crumple5', 0.8, 0.6)
  play_sound('explosion_release1', 0.9, 0.5)
end

--- Violet Vessel: spills out in a purple flood across the play area (liquid droplets pouring from the
--- chip and a purple wave over the area; no solid rectangle).
function DEATHS.flood(blind, src, calm)
  common(blind, calm)
  E().pour(src, G.play, {colour = src.colour})
  if G.play and G.play.T then E().sweep(src, G.play, {colour = src.colour, scale = 1.5}) end
  E().burst(src, nil, {colour = src.colour, scale = 1.5})
  play_sound('whoosh_long', 0.6, 0.6)
  play_sound('explosion_release1', 0.8, 0.5)
end

--- Cerulean Bell: rings once more, then breaks.
function DEATHS.bell(blind, src, calm)
  E().ring(src, nil, {colour = src.colour, count = 3, scale = 1.5})
  play_sound('gong', 1.3, 0.5)
  later(0.35, function()
    common(blind, calm)
    E().scatter(src, {shape = 'glyph', glyph = 'crack', colour = src.colour, count = 10, spread = 2.5, size = 0.5})
    E().burst(src, nil, {colour = src.colour, scale = 1.5})
    play_sound('glass2', 1, 0.6)
  end)
end

--- The avatar has just been removed at (x, y, w, h). Returns true when a death ran. A built-in death
--- that fails before its shared flash returns false (cinematic.explode then plays the 1.0 explosion);
--- one that fails after it is only logged.
function D.play(blind, x, y, w, h, calm)
  if not FinalBoss.config.fx then return false end
  local key = blind and blind.config and blind.config.blind and blind.config.blind.key
  local death = key and FinalBoss.registry.get(key).death
  if not death then return false end
  local src = {x = x, y = y, w = w, h = h, colour = FinalBoss.moves.boss_colour(blind)}
  common_ran = false
  if type(death) == 'string' then
    if not DEATHS[death] then return false end
    local ok = FinalBoss.util.guard('death_' .. death, DEATHS[death], blind, src, calm)
    return ok or common_ran
  end
  -- A modder's recipe: every step plays from the boss's last position over the play area.
  common(blind, calm)
  for _, step in ipairs(death) do
    if not SAFE[step.effect] then
      FinalBoss.util.log('warn', 'death recipe: effect ' .. tostring(step.effect) .. ' is not death-safe, skipped')
    else
      local o = {}
      for k, v in pairs(step) do o[k] = v end
      o.colour = FinalBoss.moves.step_colour(step, blind, src)
      o.bare = true
      local target = (step.effect == 'sweep' and G.play)
        or (step.effect == 'crack' and {T = {x = x, y = y, w = w, h = h}}) or nil
      FinalBoss.util.guard('death_' .. step.effect, E()[step.effect], src, target, o)
    end
  end
  play_sound('explosion_release1', FinalBoss.moves.voice(blind), 0.6)
  return true
end

-- Tiered deaths (1.3) -----------------------------------------------------------------------------
-- A crushing win (logic.death_tier) makes the death bigger: 2x (1), 10x (2), 100x (3, after the boss's
-- last words). Final bosses: their own death (or the 1.0 explosion) with D.amplify on top. Regular
-- bosses: the HUD blind chip cracks and shatters (1), explodes into pieces with a screen shake (2), or
-- blows apart with a white-out (3), D.chip. Visual only, never blocking: vanilla's defeat and cash-out
-- go on underneath. Both need screen effects; reduced motion: flashes only (the white-out is a flash).

--- Extra layers per tier: bursts (scale), shards flung out, extra screen jiggle, rings, white-out.
D.AMPLIFY = {
  [1] = {burst = 2, shards = 10, spread = 3, jiggle = 3},
  [2] = {burst = 3.5, shards = 22, spread = 4.5, jiggle = 8, rings = 3},
  [3] = {burst = 5, shards = 36, spread = 7, jiggle = 16, rings = 4, whiteout = true},
}

--- The 100x blast's sound: two explosions, low and heavy, and breaking glass.
local function heavy_boom()
  play_sound('explosion1', 0.7, 0.9)
  play_sound('explosion_release1', 0.55, 0.8)
  play_sound('glass1', 0.6, 0.6)
end

--- A final boss's death, amplified: src = {x, y, w, h} where the avatar was. Returns true when it
--- added anything.
function D.amplify(blind, src, tier, calm)
  local a = D.AMPLIFY[tier]
  if not a or not FinalBoss.config.fx then return false end
  local s = {x = src.x, y = src.y, w = src.w, h = src.h, colour = FinalBoss.moves.boss_colour(blind)}
  if a.whiteout then E().whiteout() end
  if calm then -- reduced motion: one more flash over the chip, nothing flies
    E().flash_at(s.x, s.y, s.w, s.h, G.C.WHITE)
    return true
  end
  E().burst(s, nil, {colour = s.colour, scale = a.burst})
  E().scatter(s, {shape = 'shard', colour = s.colour, count = a.shards, spread = a.spread, size = 0.35,
    life = 1.4})
  if a.rings then E().ring(s, nil, {colour = s.colour, count = a.rings, scale = 2}) end
  G.ROOM.jiggle = G.ROOM.jiggle + a.jiggle
  if tier >= 3 then heavy_boom() else play_sound(tier >= 2 and 'explosion1' or 'glass4', 0.9, 0.6) end
  return true
end

--- The HUD chip's death (regular bosses), src = {x, y, w, h} of the chip. Tier 1: it cracks and
--- shatters; tier 2: it explodes into pieces with a screen shake and a flash; tier 3: more pieces
--- flung farther, a hard shake, a white-out and a heavy blast. Returns true when it played (needs
--- screen effects and a tier).
D.CHIP = {
  [1] = {shards = 12, spread = 2, size = 0.3, life = 1.1, burst = 1.2, jiggle = 2},
  [2] = {shards = 24, spread = 5, size = 0.45, life = 1.6, burst = 3, jiggle = 10, rings = 2},
  [3] = {shards = 40, spread = 8, size = 0.55, life = 2.0, burst = 5, jiggle = 18, rings = 4, whiteout = true},
}
function D.chip(blind, src, tier, calm)
  local c = D.CHIP[tier]
  if not c or not FinalBoss.config.fx then return false end
  local s = {x = src.x, y = src.y, w = src.w, h = src.h, colour = FinalBoss.moves.boss_colour(blind)}
  FinalBoss.fx.play('flash', blind, '') -- '' = the neutral colour vanilla eases to after a win
  if c.whiteout then E().whiteout() end
  if calm then
    E().flash_at(s.x, s.y, s.w, s.h, G.C.WHITE)
    return true
  end
  E().crack(s, {T = {x = s.x, y = s.y, w = s.w, h = s.h}}, {colour = s.colour, bare = true})
  E().scatter(s, {shape = 'shard', colour = s.colour, count = c.shards, spread = c.spread, size = c.size,
    life = c.life})
  E().burst(s, nil, {colour = s.colour, scale = c.burst})
  if c.rings then E().ring(s, nil, {colour = s.colour, count = c.rings, scale = tier >= 3 and 3.5 or 2.5}) end
  G.ROOM.jiggle = G.ROOM.jiggle + c.jiggle
  if tier >= 3 then
    heavy_boom()
  else
    if tier >= 2 then play_sound('explosion_release1', 1, 0.7) end
    play_sound('glass1', tier >= 2 and 0.8 or 1.1, 0.6)
  end
  return true
end

return D

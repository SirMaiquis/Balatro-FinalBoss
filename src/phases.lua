--- Phases (1.1): final bosses transform at 50% and 25% HP (the 1.0 wound stages) with a short
--- cinematic, a phase line, a new stance and an HP-bar marker. enc.phase is plain saved data;
--- visuals are rebuilt on Continue and the transformation is never replayed.
local P = {}
P.token = 0
P.slowing = false -- this module set FinalBoss.timescale (the finale's own slow motion is not ours)
P.slow_gen = 0    -- bumped by every freeze: only the latest freeze's timer restores the time
P.DURATION = 1.5  -- transformation length, REAL seconds
P.SLOW = 0.35     -- FinalBoss.timescale during the freeze
P.FREEZE = 0.6    -- REAL seconds of slow motion

local function reduced() return G.SETTINGS.reduced_motion end

--- Timer cancelled when P.token moves on (a new transformation, round end, reset).
local function after(delay, token, fn)
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = delay, timer = 'REAL', blocking = false,
    blockable = false, func = function()
      if P.token == token then FinalBoss.util.guard('phase_timer', fn) end
      return true
    end}))
end

--- The same encounter is still running (a new blind or the end of the fight stops the rest).
local function live(enc)
  local st = G.GAME and G.GAME.FinalBoss
  return (st and st.encounter == enc and not enc.ended) and true or false
end

--- Phases run in cinematic showdowns while the avatar is on the table (spec §3.6).
function P.active(enc)
  return (enc and enc.showdown and enc.cinematic and FinalBoss.config.cinematic
    and FinalBoss.avatar.exists()) and true or false
end

--- The director's deferred reaction (score landed). Returns true when a transformation started (or
--- is scheduled): its phase line then replaces this hand's moment line. delay: REAL seconds before
--- it starts (a weak hit's laugh, Dir.stage_hit), so laugh, roar and phase line never overlap.
--- enc.phase is recorded at once, so a save during the delay keeps the phase (Continue restores it).
function P.check(enc, blind, p, delay)
  if not P.active(enc) then return false end
  local L = FinalBoss.logic
  local from = enc.phase or 1
  local stage = L.wound_stage(L.hp_fraction(p.total, p.required))
  local target = L.should_transform{cinematic = true, moment = p.moment,
    target = L.phase_cross(from - 1, stage), hands_left = p.hands_left}
  if not target then return false end
  enc.phase = target
  if (delay or 0) <= 0 then
    P.transform(enc, blind, target, from)
    return true
  end
  P.token = P.token + 1
  after(delay, P.token, function()
    if live(enc) and P.active(enc) then P.transform(enc, blind, target, from) end
  end)
  return true
end

--- Transform to `phase` (2 or 3) from `from` (1 or 2).
function P.transform(enc, blind, phase, from)
  P.token = P.token + 1
  local token = P.token
  enc.phase = phase
  local M = FinalBoss.moves
  local c = M.boss_colour(blind)
  local calm = reduced()
  M.hold(P.DURATION)
  -- 1. Freeze: slow motion, a flash in the boss colour, the FinalBoss track ducks.
  if not calm then
    FinalBoss.timescale = P.SLOW
    P.slowing = true
    P.slow_gen = P.slow_gen + 1
    local gen = P.slow_gen
    -- Not tied to the token: the time always comes back, even if the rest is cancelled.
    G.E_MANAGER:add_event(Event({trigger = 'after', delay = P.FREEZE, timer = 'REAL', blocking = false,
      blockable = false, func = function()
        FinalBoss.util.guard('phase_slowmo', function()
          if P.slowing and P.slow_gen == gen then
            P.slowing = false
            if FinalBoss.timescale == P.SLOW then FinalBoss.timescale = 1 end -- never the finale's
          end
        end)
        return true
      end}))
  end
  FinalBoss.fx.play('flash', blind)
  FinalBoss.music.duck(P.DURATION - 0.2)
  play_sound('explosion_buildup1', 1.3, 0.35)
  if not calm then
    -- 2. Rise and roar.
    after(0.2, token, function()
      if not live(enc) then return end
      FinalBoss.avatar.roar(FinalBoss.logic.ROAR.duration)
      FinalBoss.avatar.flash(0.25, c)
      if FinalBoss.config.fx then
        FinalBoss.effects.ring(M.performer(blind), nil, {colour = c, count = 3, scale = 1.6})
      end
      play_sound('timpani', 0.9 * M.voice(blind), 0.6)
    end)
    -- 3. Signature eruption: the boss's own move, played big (needs Boss moves; M.signature also
    -- needs screen effects).
    after(0.55, token, function()
      if live(enc) and FinalBoss.config.moves then M.signature(blind) end
    end)
  end
  -- 4. Phase line (forced).
  after(0.9, token, function()
    if live(enc) then FinalBoss.director.fire('phase' .. phase, {force = true}) end
  end)
  -- 5. Return: the music comes back; stance, HP marker and an arena pulse.
  after(P.DURATION, token, function()
    FinalBoss.music.unduck()
    if not live(enc) then return end
    FinalBoss.avatar.set_stance(phase, c)
    FinalBoss.hpbar.set_phase(phase)
    local A = FinalBoss.arena
    if A.state then A.on_hit(A.state.stage) end
  end)
end

--- Continue mid-showdown (after the avatar and HP bar are rebuilt: H.create resets the marker and
--- V.spawn has no aura): stance and marker come back, the transformation does not replay. 1.0 saves
--- have no enc.phase: phase I.
function P.restore(enc, blind)
  if not (enc and enc.phase and enc.phase > 1) or not P.active(enc) then return end
  FinalBoss.avatar.set_stance(enc.phase, FinalBoss.moves.boss_colour(blind))
  FinalBoss.hpbar.set_phase(enc.phase)
end

--- Developer key F8: push the current final boss to its next phase.
function P.force_next()
  local st = G.GAME and G.GAME.FinalBoss
  local enc = st and st.encounter
  if not P.active(enc) or enc.ended then return nil end
  local from = enc.phase or 1
  if from >= 3 then return nil end
  P.transform(enc, G.GAME.blind, from + 1, from)
  return from + 1
end

--- Round end, teardown or a guard failure: cancel pending steps; restore time and music if ours.
function P.reset()
  P.token = P.token + 1
  if P.slowing then P.slowing = false; FinalBoss.timescale = 1 end
  FinalBoss.music.unduck()
end

return P

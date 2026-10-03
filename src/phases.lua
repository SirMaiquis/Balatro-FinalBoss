--- Phases (1.1): final bosses transform at 50% and 25% HP (the 1.0 wound stages) with a short
--- cinematic, a phase line, a new stance and an HP-bar marker; a disabled one gets mad instead.
--- enc.phase and enc.mad_phase are plain saved data; visuals are rebuilt on Continue and the
--- transformation is never replayed.
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

--- The same encounter is still running (a new blind, the end of the fight or the winning hand's
--- finale stops the rest).
local function live(enc)
  local st = G.GAME and G.GAME.FinalBoss
  return (st and st.encounter == enc and not enc.ended and not enc.finale) and true or false
end

--- The finale (cinematic.play_finale) owns FinalBoss.timescale while it plays, with the same 0.35.
local function finale_playing()
  local C = FinalBoss.cinematic
  return (C and C.phase == 'finale') and true or false
end

--- A disabled final boss (Chicot, Luchador) has lost its power: no transformation, no twist (it gets
--- mad at the thresholds instead, P.check). Verdant
--- Leaf disabled by a joker sale is the exception: that is its normal fight, and its twist is the
--- leaf regrowing after the sale (enc.twists.leaf_sold, P.on_disable).
local function powerless(enc, blind)
  if not (blind and blind.disabled) then return false end
  return not (enc.key == 'bl_final_leaf' and enc.twists and enc.twists.leaf_sold == true)
end

P.powerless = powerless -- also read by Dir.on_blind_defeated (a powerless win is not twisted)

--- A cinematic showdown with the avatar on the table (phases, or a powerless boss's anger).
local function staged(enc)
  return (enc and enc.showdown and enc.cinematic and FinalBoss.config.cinematic
    and FinalBoss.avatar.exists()) and true or false
end

--- Phases run in cinematic showdowns while the avatar is on the table and the boss has its power.
--- blind: default the current blind.
function P.active(enc, blind)
  blind = blind or (G.GAME and G.GAME.blind)
  return (staged(enc) and not powerless(enc, blind)) and true or false
end

--- A powerless final boss crossing 50% / 25%: no transformation, it gets mad instead (the interrupt
--- anger: red flash and a short shake, the flash only under reduced motion) and says its disabled
--- line again, forced.
function P.mad(enc, blind)
  FinalBoss.avatar.anger(blind)
  FinalBoss.director.fire('disabled', {force = true})
end

--- The director's deferred reaction (score landed). Returns true when a transformation started (or
--- is scheduled): its phase line then replaces this hand's moment line. delay: REAL seconds before
--- it starts (a weak hit's laugh, Dir.stage_hit), so laugh, roar and phase line never overlap.
--- enc.phase is recorded at once, so a save during the delay keeps the phase (Continue restores it).
--- A powerless boss gets mad instead (P.mad, also true: its disabled line replaces the moment line);
--- enc.mad_phase records the threshold at once, so it is mad once per threshold, Continue included.
function P.check(enc, blind, p, delay)
  if p.total >= p.required then return false end -- the winning hand: the death plays, never a phase
  if not staged(enc) then return false end
  local L = FinalBoss.logic
  local from = enc.phase or 1
  local kind, target = L.phase_reaction{cinematic = true, moment = p.moment, hands_left = p.hands_left,
    stage = L.wound_stage(L.hp_fraction(p.total, p.required)), phase = enc.phase,
    powerless = powerless(enc, blind), mad_phase = enc.mad_phase}
  if not kind then return false end
  if kind == 'mad' then
    enc.mad_phase = target
    if (delay or 0) <= 0 then
      P.mad(enc, blind)
      return true
    end
    P.token = P.token + 1
    after(delay, P.token, function()
      if live(enc) and staged(enc) then P.mad(enc, blind) end
    end)
    return true
  end
  enc.phase = target
  -- One-shot twists change the game now (the Vessel's requirement, the Acorn's joker order), while
  -- the player has no control: the next hand must read the new state even if it is played before
  -- the transformation's return step, which only plays their visuals.
  P.apply_upto(enc, blind, target)
  if (delay or 0) <= 0 then
    P.transform(enc, blind, target, from)
    return true
  end
  P.token = P.token + 1
  after(delay, P.token, function()
    if live(enc) and P.active(enc, blind) then P.transform(enc, blind, target, from) else P.fx_queue = {} end
  end)
  return true
end

--- Transform to `phase` (2 or 3) from `from` (1 or 2).
function P.transform(enc, blind, phase, from)
  P.token = P.token + 1
  local token = P.token
  enc.phase = phase
  P.apply_upto(enc, blind, phase) -- a no-op after P.check; F8 (P.force_next) comes straight here
  FinalBoss.achievements.award_from('phase', FinalBoss.logic.phase_achievements, from, phase) -- Phase Skipper
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
            -- never the finale's (it uses the same 0.35, so the value alone cannot tell)
            if FinalBoss.timescale == P.SLOW and not finale_playing() then FinalBoss.timescale = 1 end
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
    if not live(enc) then P.fx_queue = {}; return end
    FinalBoss.avatar.set_stance(phase, c)
    FinalBoss.hpbar.set_phase(phase)
    local A = FinalBoss.arena
    if A.state then A.on_hit(A.state.stage) end
    P.play_fx(blind) -- twist visuals: Acorn shuffle sounds, Vessel bar refill (others act per draw)
  end)
end

-- Twists (setting "Boss phases change the rules") ----------------------------------------------------

P.LEAF_SOURCE = 'FinalBoss_leaf' -- SMODS.debuff_card source of the Leaf's regrowth (saved with the card)

--- Twists run when the encounter enabled them (enc.twists_on, captured at blind set) and the blind
--- still has its power. Verdant Leaf is the exception: a joker sale disables it by design, and its
--- twist is the leaf regrowing after that sale. logic.TWISTS entries (twist_for) are read-only.
local function twists_live(enc, blind)
  if not (enc and enc.twists_on and enc.twists and (enc.phase or 1) > 1) then return false end
  if blind.disabled then return enc.key == 'bl_final_leaf' and enc.twists.leaf_sold == true end
  return true
end

--- One-shot twists come in two halves: `state` changes the game the moment the phase is recorded
--- (P.check, P.transform, P.restore); `fx` plays its visuals later (the transformation's return
--- step, or at once on Continue). Visuals never touch game state.
local ONCE, DRAW = {}, {}

P.fx_queue = {} -- one-shot twists whose visuals are still to play (never saved)

--- Amber Acorn: hide the jokers again and shuffle them three times (vanilla routine, blind.lua:190-205).
--- The order is decided at once; the visuals are the three card slides.
ONCE.acorn_shuffle = {
  state = function(enc, blind, t)
    local J = G.jokers
    if not (J and #J.cards > 0) then return end
    J:unhighlight_all()
    for _, j in ipairs(J.cards) do
      if j.facing == 'front' then j:flip() end
    end
    if #J.cards < 2 then return end
    for _ = 1, 3 do FinalBoss.logic.shuffle(J.cards, math.random) end
    J:set_ranks()
  end,
  fx = function(blind, t)
    local J = G.jokers
    if not (J and #J.cards > 1) then return end
    for i, pitch in ipairs({0.85, 1.15, 1}) do
      G.E_MANAGER:add_event(Event({trigger = 'after', delay = 0.15 * i, timer = 'REAL', blocking = false,
        blockable = false, func = function()
          FinalBoss.util.guard('twist_acorn_slide', function()
            for _, j in ipairs(G.jokers and G.jokers.cards or {}) do j:juice_up(0.1, 0.1) end
            play_sound('cardSlide1', pitch)
          end)
          return true
        end}))
    end
  end,
}

--- Violet Vessel: heal 10% of the original requirement; the HP bar refills visibly.
ONCE.vessel_heal = {
  state = function(enc, blind, t)
    local num = FinalBoss.director.num
    enc.twists.vessel_base = enc.twists.vessel_base or num(blind.chips) -- plain number: saved data
    -- Raw arithmetic on blind.chips on purpose: with Talisman it is a big number, and adding to it
    -- keeps that type (Blind:save, the HUD's chip_text and Talisman's own comparisons expect it).
    blind.chips = blind.chips + enc.twists.vessel_base * t.ratio
    blind.chip_text = number_format(blind.chips)
  end,
  -- Reads the requirement when it plays, so the bar always ends on the healed value (and on the
  -- latest one when two heals queued up).
  fx = function(blind, t)
    local num, L = FinalBoss.director.num, FinalBoss.logic
    local total, required = num(G.GAME.chips), num(blind.chips)
    local stage = L.wound_stage(L.hp_fraction(total, required))
    FinalBoss.hpbar.heal(total, required)
    FinalBoss.avatar.set_wound(stage)
    if FinalBoss.arena.state then FinalBoss.arena.on_hit(stage) end
    play_sound('magic_crumple3', 0.8, 0.5)
  end,
}

--- Verdant Leaf (after a joker sale): N random hand cards wither again, re-rolled every draw. They
--- carry the Leaf's own vine curse mark (src/curse.lua draws it while the LEAF_SOURCE debuff holds).
function DRAW.leaf_debuff(enc, blind, t)
  if not blind.disabled then return end -- with its power the leaf already debuffs every card
  P.clear_twists()
  local pool = {}
  for _, c in ipairs(G.hand and G.hand.cards or {}) do
    if not c.debuff then pool[#pool + 1] = c end
  end
  local picked = FinalBoss.logic.sample(pool, t.count, math.random)
  for _, c in ipairs(picked) do
    SMODS.debuff_card(c, true, P.LEAF_SOURCE)
    c.debuffed_by_blind = true
  end
  if #picked > 0 then
    -- fresh: a card picked again grows its vine in again
    FinalBoss.curse.mark(picked, 'vine', FinalBoss.moves.boss_colour(blind), blind, true)
    if FinalBoss.config.moves and FinalBoss.config.fx then play_sound('paper1', 0.9, 0.45) end
  end
end

--- Crimson Heart: one more joker disabled per hand (phase III: with a crack beam on it). It uses the
--- Heart's own smods mechanic (smods lovely/fixes.toml:265-360): the ability.crimson_heart_chosen
--- flag, applied by SMODS.recalc_debuff (smods src/utils.lua:479-481 -> Blind:debuff_card, which keeps
--- flagged jokers debuffed). So the next draw un-flags and re-enables it and leaves it out of that
--- pick, Blind:disable / Blind:defeat clear it, and the flag is saved with the joker.
function DRAW.heart_extra(enc, blind, t, snap)
  if not snap.prepped then return end -- the Heart only picks after a played hand (blind.lua:588)
  local pool = {}
  for _, j in ipairs(G.jokers and G.jokers.cards or {}) do
    if not j.debuff then pool[#pool + 1] = j end
  end
  local picked = FinalBoss.logic.sample(pool, t.count, math.random)
  for _, j in ipairs(picked) do
    j.ability.crimson_heart_chosen = true
    SMODS.recalc_debuff(j)
    j:juice_up()
  end
  if t.beam and #picked > 0 and FinalBoss.config.fx then
    local M = FinalBoss.moves
    FinalBoss.effects.glare(M.performer(blind), picked, {colour = M.boss_colour(blind), line = true})
  end
end

--- Select every forced card that is not selected. Vanilla only re-selects a forced card while nothing
--- is selected (CardArea update, cardarea.lua:253-257), so a second forced card (or both after
--- Continue: highlights are not saved) would stay unselected.
local function select_forced()
  for _, c in ipairs(G.hand and G.hand.cards or {}) do
    if c.ability.forced_selection and not c.highlighted then G.hand:add_to_highlighted(c) end
  end
end

--- Cerulean Bell: keep t.count cards forced (vanilla forces one per draw).
function DRAW.bell_force(enc, blind, t)
  local forced, pool = 0, {}
  for _, c in ipairs(G.hand and G.hand.cards or {}) do
    if c.ability.forced_selection then forced = forced + 1 else pool[#pool + 1] = c end
  end
  for _, c in ipairs(FinalBoss.logic.sample(pool, t.count - forced, math.random)) do
    c.ability.forced_selection = true
  end
  select_forced()
end

--- One-shot twist when a phase is reached (Acorn shuffle, Vessel heal): its game state now, its
--- visuals queued for P.play_fx. enc.twists.applied keeps it single (Continue, a later transform).
--- Its keys are strings ('2', '3'): plain saved data whatever the serializer does with number keys.
function P.apply_once(enc, blind, phase)
  if not twists_live(enc, blind) then return end
  local t = FinalBoss.logic.twist_for(enc.key, phase)
  local k = tostring(phase)
  if not (t and t.once and ONCE[t.once]) or enc.twists.applied[k] then return end
  enc.twists.applied[k] = true
  ONCE[t.once].state(enc, blind, t)
  P.fx_queue[#P.fx_queue + 1] = t
end

--- Every one-shot twist up to `phase` not applied yet: a hand that skips phase II applies II and III
--- (the Vessel heals another 10% at III), and P.restore applies any one still missing on Continue.
--- apply_once keeps each one single.
function P.apply_upto(enc, blind, phase)
  for ph = 2, phase or 1 do P.apply_once(enc, blind, ph) end
end

--- Play the queued twist visuals, each kind once (a skipped phase heals twice: one bar refill
--- shows both).
function P.play_fx(blind)
  local queue = P.fx_queue
  P.fx_queue = {}
  local seen = {}
  for _, t in ipairs(queue) do
    if not seen[t.once] then
      seen[t.once] = true
      FinalBoss.util.guard('twist_fx', ONCE[t.once].fx, blind, t)
    end
  end
end

--- hooks.lua, after vanilla's drawn_to_hand and moves.on_drawn: per-draw twists (Leaf, Heart, Bell).
--- They read enc.phase, so Continue restores them with no extra state.
function P.on_drawn(blind, snap)
  local st = G.GAME and G.GAME.FinalBoss
  local enc = st and st.encounter
  if not enc or enc.ended or not (blind.config and blind.config.blind) or blind.config.blind.key ~= enc.key then return end
  if not twists_live(enc, blind) then return end
  local t = FinalBoss.logic.twist_for(enc.key, enc.phase)
  if t and t.draw and DRAW[t.draw] then DRAW[t.draw](enc, blind, t, snap or {}) end
end

--- hooks.lua, after Blind:disable: a sale disabled Verdant Leaf, so its regrowth may begin.
function P.on_disable(blind, selling)
  local st = G.GAME and G.GAME.FinalBoss
  local enc = st and st.encounter
  if selling and enc and enc.twists and enc.key == 'bl_final_leaf'
      and blind.config and blind.config.blind and blind.config.blind.key == enc.key then
    enc.twists.leaf_sold = true
  end
end

--- The fight is over (defeat, round end) or FinalBoss stopped (Dir.reset_stage): remove the Leaf's
--- regrowth debuffs. Game-state cleanup: hooks.lua runs it even when FinalBoss is disabled for the
--- run. A no-op when no card carries the source; a removed card (run teardown) only loses the field.
function P.clear_twists()
  if not G then return end
  local can_recalc = G.GAME and G.GAME.blind and true or false
  for _, c in ipairs(G.playing_cards or {}) do
    local src = c.ability and c.ability.debuff_sources
    if src and src[P.LEAF_SOURCE] then
      if can_recalc and not c.REMOVED then SMODS.debuff_card(c, nil, P.LEAF_SOURCE) else src[P.LEAF_SOURCE] = nil end
    end
  end
end

--- Continue mid-showdown (after the avatar and HP bar are rebuilt: H.create resets the marker and
--- V.spawn has no aura): stance and marker come back, the transformation does not replay. 1.0 saves
--- have no enc.phase: phase I. Twists: a one-shot twist a save cut off is applied now, the Leaf's
--- vines (transient marks) come back on the cards that carry its debuff, and the Bell's forced cards
--- are selected again (highlights are not saved; queued until the load is complete).
function P.restore(enc, blind)
  if not (enc and enc.phase and enc.phase > 1) or not P.active(enc, blind) then return end
  local M = FinalBoss.moves
  FinalBoss.avatar.set_stance(enc.phase, M.boss_colour(blind))
  FinalBoss.hpbar.set_phase(enc.phase)
  P.apply_upto(enc, blind, enc.phase)
  P.play_fx(blind) -- the bar was just built with the old requirement: it refills to the healed one
  local withered = {}
  for _, c in ipairs(G.hand and G.hand.cards or {}) do
    local src = c.ability and c.ability.debuff_sources
    if src and src[P.LEAF_SOURCE] then withered[#withered + 1] = c end
  end
  if #withered > 0 then FinalBoss.curse.mark(withered, 'vine', M.boss_colour(blind), blind) end
  local t = twists_live(enc, blind) and FinalBoss.logic.twist_for(enc.key, enc.phase)
  if t and t.draw == 'bell_force' then
    G.E_MANAGER:add_event(Event({func = function()
      FinalBoss.util.guard('twist_bell_restore', function()
        if live(enc) then select_forced() end
      end)
      return true
    end}))
  end
end

--- Developer key F8: push the current final boss to its next phase (not while the finale plays).
function P.force_next()
  local st = G.GAME and G.GAME.FinalBoss
  local enc = st and st.encounter
  if not P.active(enc, G.GAME.blind) or enc.ended or enc.finale then return nil end
  local from = enc.phase or 1
  if from >= 3 then return nil end
  P.transform(enc, G.GAME.blind, from + 1, from)
  return from + 1
end

--- Round end, teardown or a guard failure: cancel pending steps; restore time and music if ours
--- (never the finale's slow motion, which uses the same 0.35).
function P.reset()
  P.token = P.token + 1
  P.fx_queue = {}
  if P.slowing then
    P.slowing = false
    if not finale_playing() then FinalBoss.timescale = 1 end
  end
  FinalBoss.music.unduck()
end

return P

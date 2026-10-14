--- Reading the run (1.2): the intro jab (from the run as the boss blind is set), the in-fight run
--- comments, the idle taunts and the live fear scale (1.3). Every decision is a logic.lua rule; this
--- module only reads the game. Saved state is plain data on the encounter (jab, jab_said, comments,
--- last_comment_hand, last_type, type_streak, idle_said, fear_said, fear_hand), st.reroll_mark and
--- st.last_jab; the idle clock is never saved.
local O = {}
O.idle_since = nil  -- REAL time the idle clock started (last input, or the last frame idling could not count)
O.highlighted = nil -- #G.hand.highlighted on the last frame (a change counts as input)

local function L() return FinalBoss.logic end

--- The run as the boss blind is set (logic.intro_jab's s), and vanilla's run reroll counter.
--- Skips: this ante's blind states (functions/button_callbacks.lua:2760, reset at
--- functions/common_events.lua:2327-2332). Rerolls: G.GAME.round_scores.times_rerolled.amt
--- (functions/button_callbacks.lua:2869) minus the mark taken at the previous boss blind. Joker row:
--- smods card_limits.total_slots and card_count (smods src/utils.lua:3936-3945); jokers lists only
--- the ones that can act (not card.debuff nor card.getting_sliced). Deck: G.playing_cards.
function O.run_state(blind_key)
  local st = FinalBoss.util.state()
  local jokers, count, slots = {}, 0, nil
  local J = G.jokers
  if J then
    for _, c in ipairs(J.cards or {}) do
      local key = c.config and c.config.center and c.config.center.key
      -- A joker that cannot act (debuffed, or being sliced by Ceremonial Dagger) is never jabbed at.
      if key and not c.debuff and not c.getting_sliced then jokers[#jokers + 1] = key end
    end
    local cfg = J.config or {}
    count = cfg.card_count or #(J.cards or {})
    slots = (cfg.card_limits and cfg.card_limits.total_slots) or cfg.card_limit
  end
  local states = (G.GAME.round_resets and G.GAME.round_resets.blind_states) or {}
  local skipped = (states.Small == 'Skipped' and 1 or 0) + (states.Big == 'Skipped' and 1 or 0)
  local counter = G.GAME.round_scores and G.GAME.round_scores.times_rerolled
  local rerolled = (counter and tonumber(counter.amt)) or 0
  local deck = G.playing_cards or {}
  local suits, suit_max = {}, 0
  for _, c in ipairs(deck) do
    local s = c.base and c.base.suit
    if s then
      suits[s] = (suits[s] or 0) + 1
      if suits[s] > suit_max then suit_max = suits[s] end
    end
  end
  return {jokers = jokers, joker_count = count, joker_slots = slots, skipped = skipped,
    rerolls = rerolled - (st.reroll_mark or 0), dollars = FinalBoss.director.num(G.GAME.dollars),
    deck_size = #deck, suit_max = suit_max, signature = L().signature_counter(blind_key),
    last_jab = st.last_jab}, rerolled
end

--- Whether an owned Chicot disables this boss blind: vanilla skips a debuffed joker and a Chicot
--- getting sliced (card.lua:2491-2493; smods utils.lua:1017). Mods are calculated after the jokers
--- (smods utils.lua:2201-2206), so Ceremonial Dagger has already marked its victim.
local function chicot_acts()
  for _, c in ipairs((G.jokers and G.jokers.cards) or {}) do
    local key = c.config and c.config.center and c.config.center.key
    if key == 'j_chicot' and not c.debuff and not c.getting_sliced then return true end
  end
  return false
end

--- Dir.on_blind_set, boss encounters (any tier): the intro jab as plain data on the encounter, the
--- reroll mark for the next boss, and a fresh idle count and clock. A Chicot that will disable the
--- boss is always the jab: no intro plays, so its disabled line (O.disabled_jab) is the only one said.
--- rand: math.random unless given (tests).
function O.on_blind_set(enc, rand)
  local s, rerolled = O.run_state(enc.key)
  FinalBoss.util.state().reroll_mark = rerolled
  enc.jab = L().intro_jab(s, rand or math.random)
  if chicot_acts() then enc.jab = {moment = 'jab_counter', joker = 'j_chicot'} end
  enc.jab_said = nil
  enc.idle_said = 0
  O.idle_since = nil
end

--- A joker's name in the current language (functions/misc_functions.lua:1744-1746); its key if that fails.
function O.joker_name(key)
  if not key then return nil end
  local ok, name = pcall(localize, {type = 'name_text', set = 'Joker', key = key})
  if ok and type(name) == 'string' and name ~= 'ERROR' then return name end
  return key
end

--- Vars of a jab line: #1# the boss name, #2# the joker (jab_counter, jab_famous), or "A & B" for a jab_combo.
function O.jab_vars(enc, blind)
  local v = FinalBoss.director.vars(blind)
  if enc.jab and enc.jab.combo then
    v[2] = O.joker_name(enc.jab.combo[1]) .. ' & ' .. O.joker_name(enc.jab.combo[2])
  elseif enc.jab and enc.jab.joker then v[2] = O.joker_name(enc.jab.joker) end
  return v
end

--- Resolve options of the jab: the boss's own counter line (fb_<blind>_jab_counter) is only for its
--- signature counter (logic.signature_counter); any other counter skips to the personality line.
function O.jab_opts(enc)
  local j = enc.jab
  if j and j.moment == 'jab_counter' then
    return {skip_boss = j.joker ~= L().signature_counter(enc.key)}
  end
  return nil
end

--- The encounter's jab is being said: once per encounter (enc.jab_said), and it is the run's last jab
--- (st.last_jab, plain saved data), which the next boss's jab skips (logic.intro_jab).
function O.mark_said(enc)
  enc.jab_said = true
  if enc.jab then FinalBoss.util.state().last_jab = enc.jab.moment end
end

--- Chicot disables the boss before any intro (card.lua:2491-2500; Dir.play_intro skips a disabled
--- boss), so a Chicot counter jab is said as the disabled line. Returns Dir.fire options, or nil.
function O.disabled_jab(enc, blind)
  local j = enc and enc.jab
  if not (j and j.moment == 'jab_counter' and j.joker == 'j_chicot') or enc.jab_said then return nil end
  O.mark_said(enc)
  return {line = 'jab_counter', vars = O.jab_vars(enc, blind), skip_boss = O.jab_opts(enc).skip_boss}
end

-- In-fight run comments (1.2) ---------------------------------------------------------------------

--- The run comment for a scored hand that fired nothing else (Dir react): the weak-hit line or a read
--- (logic.pick_comment: the light tier's spacing and single read, the full tier's cap, never on
--- consecutive hands). p: the director's pending reaction (plain numbers, Dir.num). Never on the
--- winning hand.
function O.comment_for(enc, p)
  if not p or p.total >= p.required then return nil end
  local size = L().hit_size(p.delta, p.required)
  return L().pick_comment{weak = size == 'weak', big = size == 'big', hand_type = p.hand_type,
    streak = p.streak, discards_left = p.discards_left, discards_used = p.discards_used,
    hands_left = p.hands_left, cards_played = p.cards_played, tier = enc.tier, fired = enc.fired,
    comments = enc.comments, last_comment_hand = enc.last_comment_hand,
    last_line_hand = enc.last_line_hand, hand = p.hand}
end

--- The winning hand's defeat line after the live fear scale (1.3, O.fear_tick). p: the director's
--- pending reaction; enc: its encounter (enc.fear_said, enc.fear_hand: plain saved data).
---   false   a fear line was already said live on this hand: the defeat line is skipped (the fear
---           line stands, the death follows);
---   'fear_N' the final total reached a tier the live scale never announced (a fallback, booked like a
---           live crossing): it replaces the defeat line;
---   nil     the boss says its own defeat line (below 2x, or the tier was said on an earlier hand).
--- Not the winning defeat hand: nil.
function O.fear_line(p, enc)
  if not (p and p.moment == 'defeat' and p.total >= p.required) then return nil end
  enc = enc or {}
  -- enc.fear_hand is the id Dir.on_hand_after booked (enc.last_hand_seen), the same as p.hand.
  if enc.fear_hand ~= nil and enc.fear_hand == p.hand then return false end
  local t = L().fear_step(enc.fear_said, L().fear_tier(p.total, p.required))
  if not t then return nil end
  enc.fear_said, enc.fear_hand = t, p.hand
  return 'fear_' .. t
end

-- The live fear scale (1.3) ----------------------------------------------------------------------

--- The encounter the fear scale watches right now, or nil (logic.fear_watch).
local function fear_encounter()
  if not (G.STATES and G.STATE == G.STATES.HAND_PLAYED) then return nil end
  local st = G.GAME and G.GAME.FinalBoss
  local enc = st and st.encounter
  local blind = G.GAME and G.GAME.blind
  if not (enc and blind) then return nil end
  local S = G.STATES
  if not L().fear_watch{boss = enc.boss, ended = enc.ended, tier = enc.tier,
      same_blind = blind.config and blind.config.blind and blind.config.blind.key == enc.key,
      hand_played = S and G.STATE == S.HAND_PLAYED,
      intro = FinalBoss.dialogue.intro_active(), cinematic = FinalBoss.cinematic.active()} then
    return nil
  end
  return enc, blind
end

--- Per frame (Dir.tick): while a hand scores, the boss watches the running total the player sees, the
--- round score before this hand plus the hand's displayed chips x mult (G.GAME.current_round.current_hand:
--- update_hand_text writes it card by card as the score animation reaches each card, and vanilla's
--- flames and organ read the same pair, functions/misc_functions.lua). The global hand_chips / mult
--- are computed ahead of the animation, so they would cross before the player sees it. At the end of
--- the hand vanilla zeroes the pair as it eases G.GAME.chips up to the new total, so the sum never
--- counts the hand twice. Crossing 2x, 10x or 100x the requirement says that tier's line at once,
--- forced over the current bubble (and starting the reaction gap, so a minor line cannot cut it)
--- but free of the fight's bookkeeping (Dir.fire nobook), and plays its visuals
--- (Dir.fear_fx; they also play with dialogue off). Each tier at most once per blind, only upwards
--- (logic.fear_step; enc.fear_said and enc.fear_hand are plain saved data).
function O.fear_tick()
  local enc, blind = fear_encounter()
  if not enc then return end
  local cr = G.GAME.current_round
  local shown = cr and cr.current_hand
  if not shown then return end
  local num = FinalBoss.director.num
  -- With Talisman's score animation off the pair may never show the climb: no live crossing, and
  -- the defeat fallback (O.fear_line) says the line instead.
  local total = L().live_total(num(G.GAME.chips), num(shown.chips), num(shown.mult))
  local t = L().fear_step(enc.fear_said, L().fear_tier(total, num(blind.chips)))
  if not t then return end
  -- The hand id Dir.on_hand_after booked for this hand: vanilla's hands_played +1 event is queued
  -- before evaluate_play queues the score display, so during the animation hands_played is already
  -- one ahead (functions/state_events.lua, G.FUNCS.play_cards_from_highlighted).
  enc.fear_said, enc.fear_hand = t, enc.last_hand_seen
  -- Visual only: a failure is logged, and the line is still said.
  local ok, err = pcall(FinalBoss.director.fear_fx, enc, blind, t)
  if not ok then FinalBoss.util.log('warn', 'fear visuals failed: ' .. tostring(err)) end
  FinalBoss.director.fire('fear_' .. t, {force = true, nobook = true})
end

-- Idle taunts (1.2) ------------------------------------------------------------------------------

--- The encounter an idle taunt may come from right now, or nil: a live boss encounter on this blind,
--- dialogue on, choosing cards (SELECTING_HAND), not paused, no menu or overlay, no intro or cinematic
--- running, no reaction waiting for its score.
local function idle_encounter()
  local st = G.GAME and G.GAME.FinalBoss
  local enc = st and st.encounter
  if not (enc and enc.boss and not enc.ended and (enc.tier == 'light' or enc.tier == 'full')) then return nil end
  local blind = G.GAME.blind
  if not (blind and blind.config and blind.config.blind and blind.config.blind.key == enc.key) then return nil end
  if not FinalBoss.config.dialogue then return nil end
  if not (G.STATES and G.STATE == G.STATES.SELECTING_HAND) then return nil end
  if (G.SETTINGS and G.SETTINGS.paused) or G.OVERLAY_MENU then return nil end
  if FinalBoss.cinematic.active() or FinalBoss.dialogue.intro_active() then return nil end
  if FinalBoss.director.pending then return nil end
  return enc
end

--- Any key, click or controller button (hooks.lua): the idle clock starts over.
function O.on_input()
  O.idle_since = FinalBoss.util.now()
end

--- Per frame (Dir.tick). The clock also starts over when the hand's highlighted cards change, on
--- every frame idling cannot count (idle_encounter) and when an idle line fires. After IDLE_FIRST,
--- then IDLE_SECOND more seconds without input: an idle line (at most IDLE_MAX per blind:
--- enc.idle_said, plain saved data).
function O.idle_tick()
  local now = FinalBoss.util.now()
  local n = (G.hand and G.hand.highlighted) and #G.hand.highlighted or 0
  if n ~= O.highlighted then O.highlighted, O.idle_since = n, now end
  local enc = idle_encounter()
  if not enc or not O.idle_since then O.idle_since = now; return end
  if not L().idle_due(now - O.idle_since, enc.idle_said or 0) then return end
  O.idle_since = now
  enc.idle_said = (enc.idle_said or 0) + 1
  FinalBoss.director.fire('idle')
end

-- Developer key (1.2) -----------------------------------------------------------------------------

--- A run no jab applies to; O.dev_jab layers one fake condition on it.
O.NEUTRAL = {jokers = {}, joker_count = 1, joker_slots = 5, skipped = 0, rerolls = 0, dollars = 10,
  deck_size = 52, suit_max = 13}

--- Developer key Shift+F6: the jab a faked run gives on the current boss, said now (forced); the
--- encounter keeps that jab. state overrides O.NEUTRAL; state.counter = own the boss's
--- signature counter; state.combo = own the first famous combo. Returns the jab moment, or nil (no live boss encounter, or no jab).
function O.dev_jab(state)
  local st = G.GAME and G.GAME.FinalBoss
  local enc = st and st.encounter
  local blind = G.GAME and G.GAME.blind
  if not (enc and enc.boss and not enc.ended and blind and blind.config and blind.config.blind
      and blind.config.blind.key == enc.key) then return nil end
  local s = {}
  for k, v in pairs(O.NEUTRAL) do s[k] = v end
  for k, v in pairs(state or {}) do s[k] = v end
  s.signature = L().signature_counter(enc.key)
  if s.counter then s.jokers, s.counter = {s.signature}, nil end
  if s.combo then s.jokers, s.combo = {L().COMBOS[1][1], L().COMBOS[1][2]}, nil end
  s.force = true -- the faked jab always comes, whatever the chance roll
  enc.jab = L().intro_jab(s, math.random)
  enc.jab_said = true
  if not enc.jab then return nil end
  O.mark_said(enc)
  local opts = O.jab_opts(enc) or {}
  FinalBoss.director.fire('intro', {force = true, line = enc.jab.moment, vars = O.jab_vars(enc, blind),
    skip_boss = opts.skip_boss})
  return enc.jab.moment
end

return O

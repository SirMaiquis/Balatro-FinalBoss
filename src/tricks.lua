--- Tricks (1.3): a tarot, spectral or planet used, or a joker created, during a boss fight gets a
--- line from the boss's personality (logic.trick_reaction decides; Dir.fire with free = true says it
--- without touching the fight's bookkeeping). Saved state: enc.tricks (plain data).
---
--- Engine notes (vanilla functions/button_callbacks.lua): G.FUNCS.use_card keeps the state it was
--- pressed in as G.TAROT_INTERRUPT and sets G.STATE to PLAY_TAROT outside booster packs (:2178-2185)
--- before it calls Card:use_consumeable (:2218); it restores the state in an event afterwards. A
--- consumable from the slots can only be used in SELECTING_HAND during a blind (card.lua:1528), so a
--- trick in the fight runs in PLAY_TAROT with TAROT_INTERRUPT = SELECTING_HAND, and so do the jokers a
--- tarot or spectral creates (its events run before the state comes back).
local R = {}
R.restoring = false -- a saved run is being restored (hooks.lua's Game:start_run wrap)

local function L() return FinalBoss.logic end

--- Whether the game is in the fight's play: a hand to pick, a hand scoring, or a consumable used from
--- the slots while a hand was being picked.
local function in_play()
  local S, state = G.STATES, G.STATE
  if not S then return false end
  if state == S.SELECTING_HAND or state == S.HAND_PLAYED then return true end
  return state == S.PLAY_TAROT and G.TAROT_INTERRUPT == S.SELECTING_HAND
end

--- The live encounter a trick may hit now, or nil (logic.trick_allowed).
function R.encounter()
  local st = G.GAME and G.GAME.FinalBoss
  local enc = st and st.encounter
  local blind = G.GAME and G.GAME.blind
  if not (enc and blind) then return nil end
  local ok = L().trick_allowed{boss = enc.boss, ended = enc.ended,
    won = enc.win_hand ~= nil or enc.finale == true, -- Dir.on_hand_after, Dir.stage_hit
    same_blind = blind.config and blind.config.blind and blind.config.blind.key == enc.key,
    tier = enc.tier, playing = in_play(),
    intro = FinalBoss.dialogue.intro_active(), cinematic = FinalBoss.cinematic.active(),
    overlay = G.OVERLAY_MENU and true or false, paused = G.SETTINGS and G.SETTINGS.paused}
  if not ok then return nil end
  return enc
end

--- Book the trick and, with dialogue on, say its line. Dialogue off: still booked, so turning it on
--- mid-blind does not replay an old trick. Dialogue on but the line not shown (dropped inside
--- dialogue's REACTION_GAP): the booking goes back (like logic.poke_unsaid), so the kind and the card
--- can still get their line later.
--- line(blind): the card's or joker's own moment and vars, or nil for the kind's plain moment.
--- key: the consumable's center key (once per turn, logic.trick_reaction), or nil.
local function react(kind, line, key)
  local enc = R.encounter()
  if not enc then return end
  local state = enc.tricks or {}
  enc.tricks = state
  local last = state.last
  local moment = L().trick_reaction(state, kind, FinalBoss.util.now(), key)
  if not (moment and FinalBoss.config.dialogue) then return end
  local opts = {free = true}
  if line then
    local m, vars = line(G.GAME.blind)
    if m then moment, opts.vars = m, vars end
  end
  local _, shown = FinalBoss.director.fire(moment, opts)
  if not shown then
    state.seen[kind], state.last = nil, last
    if key ~= nil and state.turn_keys then state.turn_keys[key] = nil end
  end
end

--- A consumable's name in the current language (functions/misc_functions.lua:1744-1746); its key if
--- that fails. Jokers too (set 'Joker').
local function card_name(set, key)
  local ok, name = pcall(localize, {type = 'name_text', set = set, key = key})
  if ok and type(name) == 'string' and name ~= 'ERROR' then return name end
  return key or '?'
end

--- A planet's hand history: {played, max_played} of its hand over G.GAME.hands, or nil.
local function planet_history(hand)
  local hands = G.GAME and G.GAME.hands
  local h = hand and hands and hands[hand]
  if not h then return nil end
  local max_played = 0
  for _, v in pairs(hands) do
    if type(v) == 'table' and (v.played or 0) > max_played then max_played = v.played end
  end
  return {played = h.played or 0, max_played = max_played}
end

--- The card's moment (logic.consumable_moment) and its vars: #1# the boss, #2# the card's name (tarot,
--- spectral) or its hand's name (planet), #3# the hand's level (planet).
---
--- Planets (vanilla card.lua:302, :1264-1266): the card keeps its center's config as
--- card.ability.consumeable, so its hand is card.ability.consumeable.hand_type (game.lua:557+). The
--- level goes up inside Card:use_consumeable: level_up_hand (functions/common_events.lua:464-466)
--- sets G.GAME.hands[hand].level at once and only queues the display. Our hook runs after the
--- original returns, so the level read here is already the new one.
local function center_key(card)
  local center = card.config and card.config.center
  return (center and center.key) or (card.config and card.config.center_key)
end

local function consumable_line(card, set)
  local key = center_key(card)
  local hand = set == 'Planet' and card.ability.consumeable and card.ability.consumeable.hand_type or nil
  local history = set == 'Planet' and planet_history(hand) or nil
  if set == 'Planet' and not history then return nil end -- a planet with no known hand: plain line
  local moment = L().consumable_moment(set, key, history)
  return function(blind)
    local vars = FinalBoss.director.vars(blind)
    if set == 'Planet' then
      local ok, name = pcall(localize, hand, 'poker_hands')
      vars[2] = (ok and type(name) == 'string' and name ~= 'ERROR') and name or hand
      vars[3] = G.GAME.hands[hand].level
    else
      vars[2] = card_name(set, key)
    end
    return moment, vars
  end
end

--- The joker_created line naming the new joker (#2#).
local function joker_line(joker)
  return function(blind)
    local vars = FinalBoss.director.vars(blind)
    vars[2] = card_name('Joker', center_key(joker))
    return 'joker_created', vars
  end
end

-- Wheel of Fortune (vanilla card.lua:1467-1530): the roll happens inside Card:use_consumeable, but
-- the edition lands in an event it queues (set_edition, :1484), and a miss only queues "Nope!"
-- (:1501-1517). So the jokers without an edition are noted before the use (R.snapshot, from
-- hooks.lua) and compared once the use's events have run (resolve, below).
R.WHEEL = 'c_wheel_of_fortune'

--- Before a consumable is used: for the Wheel of Fortune, the set of jokers with no edition (card
--- references, never saved); nil for any other card.
function R.snapshot(card)
  if not (card and card.ability and card.ability.set == 'Tarot' and center_key(card) == R.WHEEL) then
    return nil
  end
  local bare = {}
  for _, j in ipairs(G.jokers and G.jokers.cards or {}) do
    if not j.edition then bare[j] = true end
  end
  return bare
end

local function wheel_line(card, before)
  local probs = G.GAME and G.GAME.probabilities
  local normal = probs and probs.normal
  local extra = card.ability and card.ability.extra -- 4 (game.lua P_CENTERS c_wheel_of_fortune)
  return function(blind)
    local hit = false
    for j in pairs(before) do
      if j.edition then hit = true; break end
    end
    local vars = FinalBoss.director.vars(blind)
    vars[2] = card_name('Tarot', R.WHEEL)
    return L().wheel_moment(hit, normal, extra), vars
  end
end

-- A consumable's line waits until its own effects have run: vanilla makes jokers in events queued by
-- the use (Judgement and The Soul card.lua:1415-1425, Ankh :1426-1453, Wraith :1454-1466), so the
-- joker arrives after the use returns. R.pending marks the consumable whose effects are running (not
-- saved); a joker added meanwhile is noted on it instead of getting its own line. The resolve event is
-- queued after every event of the use, and before G.FUNCS.use_card's own state restore event
-- (functions/button_callbacks.lua:2218-2263), so the fight is still in PLAY_TAROT when it runs.
-- Known limit: a modded card whose queued event queues another event that adds the joker lands after
-- the resolve; that joker then gets its own line (or none inside the gap) and the card its card line.
-- PENDING_MAX: a pending card older than this is stale (its event was lost with a cleared queue). Its
-- age is measured on the game clock (G.TIMERS.TOTAL, the clock the event queue runs on); hooks.lua's
-- Game:start_run wrap also clears R.pending.
R.PENDING_MAX = 10
R.pending = nil

local function clock()
  local t = G.TIMERS and G.TIMERS.TOTAL
  if type(t) == 'number' then return t end
  return FinalBoss.util.now()
end

local function resolve(p, set, line)
  if R.pending == p then R.pending = nil end
  local enc = R.encounter()
  local said = enc and enc.tricks and enc.tricks.seen and enc.tricks.seen.Joker or false
  if L().joker_card_resolution(p.joker ~= nil, said) == 'Joker' then
    react('Joker', joker_line(p.joker), p.key)
  else
    react(set, line, p.key)
  end
end

--- A consumable was used (hooks.lua's Card:use_consumeable wrap, after the original). before: the
--- Wheel of Fortune's R.snapshot, or nil.
function R.on_consumable(card, before)
  local set = card and card.ability and card.ability.set
  if not (set == 'Tarot' or set == 'Spectral' or set == 'Planet') then return end
  if not R.encounter() then return end
  local line = before and wheel_line(card, before) or consumable_line(card, set)
  local p = {key = center_key(card), t = clock()}
  R.pending = p
  G.E_MANAGER:add_event(Event({func = function()
    FinalBoss.util.guard('trick_resolve', resolve, p, set, line)
    return true
  end}))
end

--- A card was added to the deck (hooks.lua's Card:add_to_deck wrap): a joker newly created. Not a
--- joker coming back from a debuff (from_debuff: Card:set_debuff, card.lua:535), not one already in
--- the deck (was_added: self.added_to_deck before the call), not a save being restored (R.restoring).
--- Vanilla's restore never calls add_to_deck (CardArea:load builds the cards and Card:load copies
--- added_to_deck from the save, card.lua:4706); R.restoring covers mods that do. in_jokers: the card
--- was already in G.jokers before the call (a joker transforming in place; new ones are emplaced after).
--- Riff-raff's jokers come in setting_blind, while the intro speaks: no line, on purpose.
--- A joker made by a consumable still resolving (R.pending) is left to that consumable's line.
function R.on_joker_added(card, from_debuff, was_added, in_jokers)
  if from_debuff or was_added or in_jokers or R.restoring then return end
  if not (card and card.ability and card.ability.set == 'Joker') then return end
  local p = R.pending
  if p then
    local age = clock() - p.t
    if age >= 0 and age <= R.PENDING_MAX then
      p.joker = p.joker or card
      return
    end
    R.pending = nil
  end
  react('Joker', joker_line(card))
end

return R

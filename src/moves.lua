--- Boss moves (1.1): a boss performs a visible signature move when its effect applies. hooks.lua
--- observes vanilla (blind.lua) and calls the on_* entry points; each looks up the boss's recipe
--- (registry entry.moves through logic.recipe_for) and plays it with effects.lua from the
--- performer: the showdown avatar when it is on the table, otherwise the HUD blind chip.
--- Visual only: never changes vanilla behaviour. Only enc.start_moved is saved (plain data).
--- Shared with deaths and phases: M.boss_colour, M.step_colour, M.resolve, M.performer, M.perform.
local M = {}
M.QUEUE_MAX = 2
M.gen = 0
M.last = {}      -- throttle: kind -> REAL time of the last move (logic.throttle_ok)
M.hold_until = 0 -- moves queue until this REAL time (a phase transformation is playing)
M.queue = {}     -- held moves {kind, blind, recipe, data}
M.batch = {}     -- cards that stayed face down during the current draw
M.dealing = false -- a live flipped recipe has started for the current draw (collect_flipped)
M.stamped = setmetatable({}, {__mode = 'k'}) -- cursed cards already stamped this blind

local function L() return FinalBoss.logic end
local function now() return FinalBoss.util.now() end

function M.enabled(blind, kind)
  local st = G.GAME and G.GAME.FinalBoss
  return L().move_allowed{moves = FinalBoss.config.moves, fx = FinalBoss.config.fx,
    disabled_run = st and st.disabled_for_run or false, is_boss = (blind and blind.boss) and true or false,
    blind_disabled = blind and blind.disabled or false, kind = kind}
end

--- The boss colour of a blind object or a blind key (G.P_BLINDS[key].boss_colour); red when unknown.
function M.boss_colour(blind)
  local def
  if type(blind) == 'string' then
    def = G.P_BLINDS and G.P_BLINDS[blind]
  else
    def = blind and blind.config and blind.config.blind
  end
  return (def and def.boss_colour) or G.C.RED
end

--- Who performs: the showdown avatar when it is on the table (cinematic showdowns), otherwise the
--- HUD blind chip.
function M.performer(blind)
  local c = M.boss_colour(blind)
  local V = FinalBoss.avatar
  if V.exists() then
    local x, y, w, h = V.position()
    return {x = x, y = y, w = w, h = h, obj = V.anchor(), colour = c, avatar = true}
  end
  local T = blind.T
  return {x = T.x, y = T.y, w = T.w, h = T.h, obj = blind, colour = c, avatar = false}
end

--- The hand's card-count label ("0/8" under the hand): the limit text of G.hand's area_uibox, built
--- by CardArea:draw (cardarea.lua:281-299) the first time the hand is drawn in a round state; smods
--- shows card_limits.display_slots there (lovely/card_limit.toml:187-196). nil until it exists.
function M.hand_limit_label()
  local box = G.hand and G.hand.children and G.hand.children.area_uibox
  if not (box and box.UIRoot) then return nil end
  local cfg = G.hand.config
  local lim = cfg.card_limits
  local function find(node)
    local c = node.config
    if c and ((lim and c.ref_table == lim and c.ref_value == 'display_slots')
        or (c.ref_table == cfg and c.ref_value == 'card_limit')) then return node end
    for _, child in ipairs(node.children or {}) do
      local f = find(child)
      if f then return f end
    end
    return nil
  end
  return find(box.UIRoot)
end

--- A step's target: the data lists, a CardArea, the hand's card-count label or the HUD element of a
--- hud_* target.
function M.resolve(target, data)
  if target == nil or target == 'source' then return nil end
  data = data or {}
  if target == 'cards' then return data.cards or {} end
  if target == 'played' then return data.played or {} end
  if target == 'hand' then return G.hand end
  if target == 'jokers' then return G.jokers end
  if target == 'hand_limit' then return M.hand_limit_label() end
  local id = L().HUD_IDS[target]
  if not id then return nil end
  local box = (target == 'hud_target') and G.HUD_blind or G.HUD
  return box and box:get_UIE_by_ID(id) or nil
end

--- step.colour: nil = boss colour (src.colour), 'suit' = the suit the blind debuffs (G.C.SUITS), or
--- a G.C name in lower case ('gold', 'blue', 'purple', 'green', 'red').
function M.step_colour(step, blind, src)
  local c = step.colour
  if c == 'suit' then
    local suit = blind.debuff and blind.debuff.suit
    return (suit and G.C.SUITS[suit]) or src.colour
  end
  if type(c) == 'string' and type(G.C[c:upper()]) == 'table' then return G.C[c:upper()] end
  return src.colour
end

--- The boss's voice pitch (registry entry.voice.pitch): recipe and step sounds are played times it.
function M.voice(blind)
  local key = blind and blind.config and blind.config.blind and blind.config.blind.key
  local e = key and FinalBoss.registry.get(key)
  return (e and e.voice and tonumber(e.voice.pitch)) or 1
end

local function play(s, pitch)
  if type(s) == 'table' and type(s[1]) == 'string' then play_sound(s[1], (s[2] or 1) * pitch, s[3] or 0.5) end
end

--- Run a recipe's (or a cue's) steps from src. opts.pass: 'once' skips the steps marked each, 'each'
--- runs only them (a live recipe: once at the first dealt card, each for every card). A step's sound
--- plays when it runs. A step with a cue (recount) gets o.on_count: the performer reacts and the cue
--- steps play when the count starts. A recount also gets o.locate, to find a target that does not
--- exist yet (the hand's card-count label).
local run_steps
run_steps = function(blind, steps, data, src, opts)
  local E = FinalBoss.effects
  local pitch = M.voice(blind)
  for _, step in ipairs(steps) do
    local skip = (opts.pass == 'once' and step.each) or (opts.pass == 'each' and not step.each)
    if skip then
      -- the other pass plays it
    elseif E[step.effect] then
      local o = {}
      for k, v in pairs(step) do o[k] = v end
      o.colour = M.step_colour(step, blind, src)
      o.blind, o.data = blind, data -- curse: the cursing blind; fist: data.queue_from; recount: before/after
      o.amount = FinalBoss.director.num(L().step_amount(step, data)) -- Talisman big numbers
      if opts.big then
        o.scale = (step.scale or 1) * 1.8
        o.count = (step.count or 2) + 1
      end
      if type(step.cue) == 'table' then
        local cue = step.cue
        o.on_count = function()
          local s = M.performer(blind)
          E.react(s, s.colour, opts.big)
          run_steps(blind, cue, data, s, {big = opts.big})
        end
      end
      if step.effect == 'recount' then
        local target = step.target
        o.locate = function() return M.resolve(target, data) end
      end
      FinalBoss.util.guard('effect_' .. tostring(step.effect), E[step.effect], src, M.resolve(step.target, data), o)
      play(step.sound, pitch)
    else
      -- A recipe typo skips its own step; it must not abort the run through the guard.
      FinalBoss.util.log('warn', 'moves: unknown effect ' .. tostring(step.effect) .. ', step skipped')
    end
  end
end

--- Play `recipe` now. opts.big (phase eruption): bigger juice, scaled effects, one more ring.
--- opts.pass ('once' / 'each'): see run_steps; the each pass neither reacts nor plays recipe.sound. A
--- recipe with a cue step reacts when its count starts instead of at once.
function M.perform(blind, recipe, data, opts)
  opts, data = opts or {}, data or {}
  local src = M.performer(blind)
  local each = opts.pass == 'each'
  local cued = false
  for _, step in ipairs(recipe) do
    if step.cue then cued = true end
  end
  if not (each or cued) then FinalBoss.effects.react(src, src.colour, opts.big) end
  run_steps(blind, recipe, data, src, opts)
  if not each then play(recipe.sound, M.voice(blind)) end
end

--- A boss effect just applied (hooks.lua through the on_* functions below). opts go to M.perform.
function M.trigger(kind, blind, data, opts)
  if not (blind and blind.config and blind.config.blind and blind.config.blind.key) then return end
  if not M.enabled(blind, kind) then return end
  local recipe = L().recipe_for(FinalBoss.registry.get(blind.config.blind.key).moves, kind)
  if not recipe then return end
  data = data or {}
  local t = now()
  if t < M.hold_until then
    L().queue_push(M.queue, {kind = kind, blind = blind, recipe = recipe, data = data, opts = opts}, M.QUEUE_MAX)
    return
  end
  if not L().throttle_ok(M.last, kind, t, L().THROTTLE_GAP) then return end
  M.perform(blind, recipe, data, opts)
end

--- A phase transformation plays for `seconds`: moves wait, then the held ones (at most QUEUE_MAX,
--- oldest dropped) play in order.
function M.hold(seconds)
  M.hold_until = now() + seconds
  local gen = M.gen
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = seconds, timer = 'REAL', blocking = false,
    blockable = false, func = function()
      if M.gen == gen then FinalBoss.util.guard('moves_release', M.release) end
      return true
    end}))
end

function M.release()
  local q = M.queue
  M.queue, M.hold_until = {}, 0
  for _, item in ipairs(q) do
    -- Queue positions recorded when the move was held are stale now (effects.fist must not insert
    -- events by them): a held fist slams at once.
    item.data.queue_from = nil
    if item.blind == (G.GAME and G.GAME.blind) and M.enabled(item.blind, item.kind) then
      M.perform(item.blind, item.recipe, item.data, item.opts)
    end
  end
end

--- The boss's 'start' move (recipes of kind 'start'; the vanilla blind-start bosses use 'set' and play
--- at once, M.on_set_blind): once per encounter, when the intro ends or INTRO_DELAY after the blind is
--- set when no intro plays (director). enc.start_moved is plain saved data, so Continue never replays it.
function M.start(blind_key)
  local st = G.GAME and G.GAME.FinalBoss
  local enc = st and st.encounter
  local blind = G.GAME and G.GAME.blind
  if not enc or enc.key ~= blind_key or enc.start_moved or enc.ended then return end
  if not (blind and blind.config and blind.config.blind and blind.config.blind.key == blind_key) then return end
  enc.start_moved = true
  M.trigger('start', blind, {})
end

--- The boss's own move played big (phase transformation, step 3): entry.moves.signature, or the
--- generic burst. Bypasses the hold (it is part of the transformation) but needs screen effects.
function M.signature(blind)
  if not FinalBoss.config.fx then return end
  if not (blind and blind.config and blind.config.blind and blind.config.blind.key) then return end
  local moves = FinalBoss.registry.get(blind.config.blind.key).moves
  M.perform(blind, (moves and moves.signature) or L().GENERIC_RECIPE, {}, {big = true})
end

-- Trigger entry points (hooks.lua) -----------------------------------------------------------------

--- Before vanilla's drawn_to_hand: what on_drawn compares against afterwards.
function M.snapshot(blind)
  local forced
  for _, c in ipairs(G.hand and G.hand.cards or {}) do
    if c.ability and c.ability.forced_selection then forced = c; break end
  end
  return {forced = forced, prepped = blind.prepped and true or false, disabled = blind.disabled and true or false}
end

--- Just before vanilla's Blind:set_blind applies the boss (hooks.lua): the counters the player sees.
--- new_round has already reset hands_left and discards_left (state_events.lua:296-297, before the
--- set_blind call at :333). hand_size is the hand label's number (smods card_limits.display_slots,
--- recomputed every CardArea:update, smods src/utils.lua:3919-3962); hand_mod is card_limits.mod, which
--- smods' CardArea:change_size changes at once (lovely/card_limit.toml:84-100). target is the normal
--- boss target (logic.normal_target; get_blind_amount is vanilla functions/misc_functions.lua).
function M.capture()
  local num = FinalBoss.director.num -- Talisman big numbers
  local cr = G.GAME.current_round or {}
  local hand = G.hand and G.hand.config
  local lim = hand and hand.card_limits
  local amount = (type(get_blind_amount) == 'function') and num(get_blind_amount(G.GAME.round_resets.ante)) or nil
  local scaling = G.GAME.starting_params and num(G.GAME.starting_params.ante_scaling or 1) or 1
  return {
    hands = tonumber(cr.hands_left), discards = tonumber(cr.discards_left),
    hand_size = tonumber((lim and lim.display_slots) or (hand and hand.card_limit)),
    hand_mod = lim and (tonumber(lim.mod) or 0) or nil,
    target = amount and L().normal_target(amount, scaling) or nil,
  }
end

--- After vanilla's Blind:set_blind (hooks.lua; before = M.capture's snapshot). The boss effect is
--- decided now (hands_sub, discards_sub: blind.lua:179-186; the Manacle's card_limits.mod; the real
--- target blind.chips: blind.lua:107) though ease_hands_played / ease_discard show it a moment later
--- (queued events, common_events.lua:111-190). The 'set' move plays at once with both snapshots.
function M.on_set_blind(blind, before)
  if not (blind and blind.boss and before) then return end
  local lim = G.hand and G.hand.config and G.hand.config.card_limits
  local delta = (lim and before.hand_mod) and ((tonumber(lim.mod) or 0) - before.hand_mod) or 0
  local after = L().recount_after(before, {hands_sub = blind.hands_sub, discards_sub = blind.discards_sub,
    mod_delta = delta, chips = FinalBoss.director.num(blind.chips)})
  M.trigger('set', blind, {before = before, after = after})
end

--- Blind:stay_flipped kept a card face down as it entered the hand during a draw (called just before
--- the card is emplaced: common_events.lua:402-408). A live recipe (The House) plays while the cards
--- are dealt: its once-steps at the first card of the draw, its each-steps for every card. Otherwise
--- the cards are collected and on_drawn plays the move once the draw is complete.
function M.collect_flipped(blind, card)
  if not M.enabled(blind, 'flipped') then return end
  local recipe = L().recipe_for(FinalBoss.registry.get(blind.config.blind.key).moves, 'flipped')
  if recipe and recipe.live then
    local data = {cards = {card}}
    if not M.dealing then
      M.dealing = true
      M.trigger('flipped', blind, data, {pass = 'once'})
    end
    M.perform(blind, recipe, data, {pass = 'each'})
    return
  end
  M.batch[#M.batch + 1] = card
end

--- G.FUNCS.draw_from_deck_to_hand has just queued a draw (hooks.lua); from = the first base-queue index
--- it queued. The Serpent's refill (only in DRAW_TO_HAND: smods lovely/card_limit.toml:325-338): an
--- event inserted where the draw starts (its delay(0.3), logic.draw_slots) starts the snake when the
--- queue reaches it; the snake crawls until the last card is in the hand (logic.serpent_lead).
function M.on_draw_start(blind, from)
  if not (G.STATES and G.STATE == G.STATES.DRAW_TO_HAND) then return end
  if not (blind and blind.config and blind.config.blind) then return end
  local cr = G.GAME.current_round
  if not L().serpent_draw{key = blind.config.blind.key, disabled = blind.disabled,
      hands_played = cr.hands_played, discards_used = cr.discards_used} then return end
  if not M.enabled(blind, 'draw') then return end
  local q = G.E_MANAGER and G.E_MANAGER.queues and G.E_MANAGER.queues.base
  if not q then return end
  local start, count = L().draw_slots(q, from)
  if not start then return end -- no card dealt (empty deck)
  local gen = M.gen
  -- blockable, not blocking: runs when the queue reaches the draw and holds nothing up
  table.insert(q, start, Event({blocking = false, func = function()
    if M.gen == gen then
      FinalBoss.util.guard('move_draw', M.trigger, 'draw', blind, {time = L().serpent_lead(count, G.SPEEDFACTOR)})
    end
    return true
  end}))
end

--- After vanilla's press_play. played = the cards being played. A recipe with `defer` (The Hook)
--- reads its cards in an event queued behind the one vanilla just queued (blind.lua:466-482): there
--- G.hand.highlighted holds exactly the two hooked cards, before their discard events move them.
function M.on_press_play(blind, played)
  if not M.enabled(blind, 'play') then return end
  local recipe = L().recipe_for(FinalBoss.registry.get(blind.config.blind.key).moves, 'play')
  if not recipe then return end
  if recipe.defer then
    G.E_MANAGER:add_event(Event({blocking = false, func = function()
      FinalBoss.util.guard('move_deferred', function()
        local hooked = {}
        for _, c in ipairs(G.hand and G.hand.highlighted or {}) do hooked[#hooked + 1] = c end
        M.trigger('play', blind, {cards = hooked, played = played})
      end)
      return true
    end}))
    return
  end
  M.trigger('play', blind, {cards = played, played = played})
end

function M.on_modify(blind) M.trigger('modify', blind, {}) end

--- After a real debuff_hand that fired. money_before: dollars before the call (the Ox empties them).
--- queued_before: events in vanilla's base queue before the call; the ones after it are the blind's
--- own (The Arm's level change: effects.fist syncs its slam with them).
function M.on_debuff_hand(blind, cards, money_before, queued_before)
  local num = FinalBoss.director.num -- Talisman big numbers
  local lost = math.max(0, num(money_before or 0) - num(G.GAME.dollars))
  M.trigger('hand_debuff', blind, {cards = cards, played = cards, money = lost,
    queue_from = queued_before and (queued_before + 1) or nil})
end

--- Curse marks stay on the cards (src/curse.lua): every newly cursed card is marked at once, so a
--- throttled or held move (the grow-in sound and juice) never loses a mark.
function M.mark_cursed(blind, cards)
  if not M.enabled(blind, 'card_debuff') then return end
  local recipe = L().recipe_for(FinalBoss.registry.get(blind.config.blind.key).moves, 'card_debuff')
  if not recipe then return end
  local src = {colour = M.boss_colour(blind)} -- step_colour reads only the colour
  for _, step in ipairs(recipe) do
    if step.effect == 'curse' then
      FinalBoss.curse.mark(cards, step.style, M.step_colour(step, blind, src), blind)
    end
  end
end

--- Cards debuffed by the blind (smods sets card.debuffed_by_blind, lovely/blind.toml:9-22) that are
--- in hand and were not stamped yet this blind.
local function newly_cursed()
  local out = {}
  for _, c in ipairs(G.hand and G.hand.cards or {}) do
    if L().blind_cursed(c.debuff, c.debuffed_by_blind, M.stamped[c]) then
      M.stamped[c] = true
      out[#out + 1] = c
    end
  end
  return out
end

--- Continue (Dir.on_blind_loaded): curse marks are visuals, never saved, so the cursed cards already in
--- hand get theirs back (no move plays). They count as stamped: the next draw does not curse them anew.
--- card.debuffed_by_blind is not saved (vanilla Card:load restores only debuff, card.lua:4704, and
--- CardArea:load skips debuff_card), so each debuffed hand card is recomputed first: SMODS.recalc_debuff
--- (smods src/utils.lua:479) runs Blind:debuff_card, which sets the flag when the blind is the cause.
function M.restore_marks(blind)
  if not (blind and blind.config and blind.config.blind and blind.config.blind.key) then return end
  local cursed = {}
  for _, c in ipairs(G.hand and G.hand.cards or {}) do
    if c.debuff and not M.stamped[c] then
      local ok, err = pcall(SMODS.recalc_debuff, c)
      if not ok then FinalBoss.util.log('warn', 'curse restore recalc failed: ' .. tostring(err)) end
      if ok and L().blind_cursed(c.debuff, c.debuffed_by_blind, M.stamped[c]) then
        M.stamped[c] = true
        cursed[#cursed + 1] = c
      end
    end
  end
  if #cursed > 0 then M.mark_cursed(blind, cursed) end
end

--- After vanilla's drawn_to_hand (the draw is complete): the face-down batch, newly cursed cards,
--- the Bell's newly forced card and the Heart's disabled jokers.
function M.on_drawn(blind, snap)
  local flipped = M.batch
  M.batch, M.dealing = {}, false
  if #flipped > 0 then M.trigger('flipped', blind, {cards = flipped}) end
  local cursed = newly_cursed()
  if #cursed > 0 then
    M.mark_cursed(blind, cursed)
    M.trigger('card_debuff', blind, {cards = cursed})
  end
  local drawn = {}
  local forced = M.snapshot(blind).forced
  if forced and forced ~= snap.forced then drawn[#drawn + 1] = forced end
  if snap.prepped and not blind.disabled then
    for _, j in ipairs(G.jokers and G.jokers.cards or {}) do
      if j.debuff then drawn[#drawn + 1] = j end
    end
  end
  if #drawn > 0 then M.trigger('drawn', blind, {cards = drawn}) end
end

--- After Blind:disable. selling: a card sale caused it (Verdant Leaf's joker_sold move).
function M.on_disable(blind, selling)
  if selling then M.trigger('joker_sold', blind, {}) end
end

function M.on_wiggle(blind) M.trigger('generic', blind, {}) end

--- A new blind: forget the previous blind's throttle, batches, queue and curse marks.
function M.on_blind_set()
  M.last, M.batch, M.queue, M.hold_until, M.dealing = {}, {}, {}, 0, false
  M.stamped = setmetatable({}, {__mode = 'k'})
  FinalBoss.curse.clear()
end

function M.reset()
  M.gen = M.gen + 1
  M.on_blind_set()
end

return M

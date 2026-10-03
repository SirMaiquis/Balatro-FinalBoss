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

--- A step's target: the data lists, a CardArea, or the HUD element of a hud_* target.
function M.resolve(target, data)
  if target == nil or target == 'source' then return nil end
  data = data or {}
  if target == 'cards' then return data.cards or {} end
  if target == 'played' then return data.played or {} end
  if target == 'hand' then return G.hand end
  if target == 'jokers' then return G.jokers end
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

--- Play `recipe` now. opts.big (phase eruption): bigger juice, scaled effects, one more ring.
function M.perform(blind, recipe, data, opts)
  opts, data = opts or {}, data or {}
  local E = FinalBoss.effects
  local src = M.performer(blind)
  E.react(src, src.colour, opts.big)
  for _, step in ipairs(recipe) do
    local o = {}
    for k, v in pairs(step) do o[k] = v end
    o.colour = M.step_colour(step, blind, src)
    o.amount = FinalBoss.director.num(L().step_amount(step, data)) -- Talisman big numbers
    if opts.big then
      o.scale = (step.scale or 1) * 1.8
      o.count = (step.count or 2) + 1
    end
    FinalBoss.util.guard('effect_' .. tostring(step.effect), E[step.effect], src, M.resolve(step.target, data), o)
  end
  local s = recipe.sound
  if s then
    local pitch = FinalBoss.registry.get(blind.config.blind.key).voice.pitch
    play_sound(s[1], (s[2] or 1) * pitch, s[3] or 0.5)
  end
end

--- A boss effect just applied (hooks.lua through the on_* functions below).
function M.trigger(kind, blind, data)
  if not (blind and blind.config and blind.config.blind and blind.config.blind.key) then return end
  if not M.enabled(blind, kind) then return end
  local recipe = L().recipe_for(FinalBoss.registry.get(blind.config.blind.key).moves, kind)
  if not recipe then return end
  data = data or {}
  local t = now()
  if t < M.hold_until then
    L().queue_push(M.queue, {kind = kind, blind = blind, recipe = recipe, data = data}, M.QUEUE_MAX)
    return
  end
  if not L().throttle_ok(M.last, kind, t, L().THROTTLE_GAP) then return end
  M.perform(blind, recipe, data)
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
    if item.blind == (G.GAME and G.GAME.blind) and M.enabled(item.blind, item.kind) then
      M.perform(item.blind, item.recipe, item.data)
    end
  end
end

--- The boss's 'start' move (Manacle, Wall, Needle, Water, Amber Acorn, Violet Vessel): once per
--- encounter, when the intro ends or INTRO_DELAY after the blind is set when no intro plays
--- (director). enc.start_moved is plain saved data, so Continue never replays it.
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

--- Blind:stay_flipped kept a card face down as it entered the hand during a draw.
function M.collect_flipped(blind, card)
  if M.enabled(blind, 'flipped') then M.batch[#M.batch + 1] = card end
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
function M.on_debuff_hand(blind, cards, money_before)
  local lost = math.max(0, (money_before or 0) - FinalBoss.director.num(G.GAME.dollars))
  M.trigger('hand_debuff', blind, {cards = cards, played = cards, money = lost})
end

--- Cards debuffed by the blind (smods sets card.debuffed_by_blind, lovely/blind.toml:9-22) that are
--- in hand and were not stamped yet this blind.
local function newly_cursed()
  local out = {}
  for _, c in ipairs(G.hand and G.hand.cards or {}) do
    if c.debuff and c.debuffed_by_blind and not M.stamped[c] then
      M.stamped[c] = true
      out[#out + 1] = c
    end
  end
  return out
end

--- After vanilla's drawn_to_hand (the draw is complete): the face-down batch, newly cursed cards,
--- the Serpent's refill, the Bell's newly forced card and the Heart's disabled jokers.
function M.on_drawn(blind, snap)
  local flipped = M.batch
  M.batch = {}
  if #flipped > 0 then M.trigger('flipped', blind, {cards = flipped}) end
  local cursed = newly_cursed()
  if #cursed > 0 then M.trigger('card_debuff', blind, {cards = cursed}) end
  local cr = G.GAME.current_round
  if L().serpent_draw{key = blind.config.blind.key, disabled = blind.disabled,
      hands_played = cr.hands_played, discards_used = cr.discards_used} then
    M.trigger('draw', blind, {})
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

--- A new blind: forget the previous blind's throttle, batches and queue.
function M.on_blind_set()
  M.last, M.batch, M.queue, M.hold_until = {}, {}, {}, 0
  M.stamped = setmetatable({}, {__mode = 'k'})
end

function M.reset()
  M.gen = M.gen + 1
  M.on_blind_set()
end

return M

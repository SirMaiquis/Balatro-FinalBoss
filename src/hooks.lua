--- The ONLY file that hooks game or smods functions. Each hook keeps the original
--- behaviour and runs FinalBoss code inside util.guard, so FinalBoss can never break a run.
local U = FinalBoss.util
local H = {}

local function director() return FinalBoss.director end

local showdown_error_logged = false

FinalBoss.mod.calculate = function(self, context)
  if not G.GAME then return end
  -- Game-state cleanup, not a visual: the Leaf twist's saved debuffs go with the blind even when
  -- FinalBoss disabled itself mid-fight (a guard failure: disabled_for_run).
  if context.blind_defeated then U.guard('twist_cleanup', FinalBoss.phases.clear_twists) end
  if not director().enabled() then return end
  if context.setting_blind then
    U.guard('setting_blind', director().on_blind_set, G.GAME.blind)
  elseif context.after then
    U.guard('hand_after', director().on_hand_after, context)
  elseif context.blind_disabled then
    U.guard('blind_disabled', director().on_blind_disabled)
  elseif context.blind_defeated then
    U.guard('blind_defeated', director().on_blind_defeated)
  end
end

local orig_blind_load = Blind.load
function Blind:load(...)
  local ret = orig_blind_load(self, ...)
  if G.GAME and director().enabled() then U.guard('blind_load', director().on_blind_loaded, self) end
  return ret
end

local orig_end_round = end_round
function end_round(...)
  local q = G.E_MANAGER.queues.base
  local n = #q
  local ret = orig_end_round(...)
  -- Vanilla end_round queues exactly one event (the 0.2 s end-of-round event that decides game
  -- over / Mr. Bones); smods only patches inside it. Ours runs after it has completed:
  -- * pause_force: on a loss that event sets GAME_OVER and update_game_over pauses the game in the
  --   same frame, before our turn. Events made before a pause are skipped while it lasts, so
  --   without pause_force the game-over branch of on_round_end would never run.
  -- * the gate: a pause-skipped event never sets `blocked`, so if the player pauses (options menu)
  --   before vanilla's event has run, ours could run first with the round undecided. It waits
  --   (returns false) until vanilla's event is complete; blocking = false so a waiting event never
  --   stalls events queued meanwhile.
  local ev = q[n + 1]
  G.E_MANAGER:add_event(Event({pause_force = true, blocking = false, func = function()
    if ev and not ev.complete then return false end
    U.guard('twist_cleanup', FinalBoss.phases.clear_twists) -- game state: runs even when disabled
    if director().enabled() then U.guard('end_round', director().on_round_end) end
    return true
  end}))
  return ret
end

local orig_keypressed = love.keypressed
function love.keypressed(key, ...)
  U.guard('input', FinalBoss.observe.on_input) -- 1.2: any key restarts the boss's idle clock
  if FinalBoss.cinematic.active() then U.guard('cinematic_skip', FinalBoss.cinematic.skip)
  elseif FinalBoss.dialogue.intro_active() then U.guard('skip', FinalBoss.dialogue.skip) end
  return orig_keypressed(key, ...)
end

-- Showdown schedule. The vanilla result is OR'd in, so the win-ante boss is always a showdown.
-- In smods 26.829.0 this function is the only showdown eligibility switch (src/utils/weights.lua).
local orig_is_showdown_ante = SMODS.is_showdown_ante
SMODS.is_showdown_ante = function(...)
  local vanilla = orig_is_showdown_ante(...)
  local sd = FinalBoss.config.showdown
  if vanilla or not (sd and sd.enabled) or not G.GAME then return vanilla end
  local ok, extra = pcall(FinalBoss.logic.is_extra_showdown, G.GAME.round_resets.ante, sd.start_ante, sd.every)
  if not ok then
    if not showdown_error_logged then
      U.log('error', 'showdown schedule failed: ' .. tostring(extra))
      showdown_error_logged = true
    end
    return vanilla
  end
  return extra or false
end

-- Game:delete_run (menu, restart, new run) clears the event queue, so pending fx eases never finish:
-- reset the vignette state here or it would draw on the menu and in the next run.
local orig_delete_run = Game.delete_run
function Game:delete_run(...)
  local ret = orig_delete_run(self, ...)
  U.guard('delete_run', function()
    director().reset_stage()
    FinalBoss.dialogue.drop_on_teardown()
  end)
  return ret
end

-- Vanilla paints every showdown blue/red (common_events.lua ease_background_colour_blind) and
-- re-runs it on every refresh, including fx.flash's restore: re-apply the arena palette after it.
local orig_ease_bg_blind = ease_background_colour_blind
-- Shop and booster packs keep vanilla's palette, so those refreshes are not re-themed.
local function neutral_state(state)
  local S = G.STATES
  if not (S and state) then return false end
  return state == S.SHOP or state == S.TAROT_PACK or state == S.PLANET_PACK
    or state == S.SPECTRAL_PACK or state == S.STANDARD_PACK or state == S.BUFFOON_PACK
end

function ease_background_colour_blind(state, ...)
  local ret = orig_ease_bg_blind(state, ...)
  if FinalBoss.arena.active() and not neutral_state(state) then
    U.guard('arena_apply', FinalBoss.arena.apply)
  end
  return ret
end

-- Per-frame stage tick (avatar idle/roam, HP bar trail, arena music pitch).
local orig_game_update = Game.update
function Game:update(dt, ...)
  local ret = orig_game_update(self, dt, ...)
  if G.GAME and director().enabled() then U.guard('stage_tick', director().tick, dt) end
  return ret
end

-- Boss moves (1.1) ---------------------------------------------------------------------------------
-- Observe where vanilla applies each boss effect (blind.lua) and tell moves.lua. Every wrap calls
-- the original first with the same arguments and returns all of its results unchanged.
local unpack = unpack or table.unpack
local function pack(...) return {n = select('#', ...), ...} end
local function moves() return FinalBoss.moves end
local function live() return G.GAME and director().enabled() end

-- Wall, Water, Needle and Manacle apply in set_blind (blind.lua:78-216: chips at :107, The Water at
-- :179-182, The Needle at :183-186, The Manacle at :187-189; smods routes change_size to
-- card_limits.mod, lovely/card_limit.toml:84-100). new_round calls it (state_events.lua:333) right
-- after resetting hands and discards (:296-297), so the counters read before the call are the ones the
-- player sees; the 'set' move plays right after it with both snapshots. Resets (reset = true) apply
-- nothing and are ignored.
local orig_set_blind = Blind.set_blind
function Blind:set_blind(blind, reset, ...)
  local before
  if blind and not reset and live() then
    U.guard('move_capture', function() before = moves().capture() end)
  end
  local r = pack(orig_set_blind(self, blind, reset, ...))
  if before then U.guard('move_set', moves().on_set_blind, self, before) end
  return unpack(r, 1, r.n)
end

-- The Serpent's refill: every draw to hand runs G.FUNCS.draw_from_deck_to_hand inside an event
-- (game.lua:3219-3222), which queues delay(0.3) and one draw_card event per card at the end of the base
-- queue (state_events.lua:369-376, smods lovely/card_limit.toml:283-338, lovely/better_calc.toml).
-- Observing this call is the reliable start: it is the one place the refill's size is decided and its
-- events are queued, so moves can start the snake exactly when the queue reaches them (a state watch in
-- Dir.tick would only see DRAW_TO_HAND begin, before the queue gets to the draw). The base queue's
-- length is read first: its events start right after it.
local orig_draw_to_hand = G.FUNCS and G.FUNCS.draw_from_deck_to_hand
if orig_draw_to_hand then
  G.FUNCS.draw_from_deck_to_hand = function(...)
    local base = live() and G.E_MANAGER and G.E_MANAGER.queues and G.E_MANAGER.queues.base
    local n = base and #base
    local r = pack(orig_draw_to_hand(...))
    if n then U.guard('move_draw_start', moves().on_draw_start, G.GAME.blind, n + 1) end
    return unpack(r, 1, r.n)
  end
end

-- Hook and Tooth act in press_play (blind.lua:464-505). The played cards are still
-- G.hand.highlighted here: vanilla moves them with queued draw events (state_events.lua:479-486).
local orig_press_play = Blind.press_play
function Blind:press_play(...)
  local played
  if live() then
    played = {}
    for _, c in ipairs(G.hand and G.hand.highlighted or {}) do played[#played + 1] = c end
  end
  local r = pack(orig_press_play(self, ...))
  if played and not self.disabled then U.guard('move_play', moves().on_press_play, self, played) end
  return unpack(r, 1, r.n)
end

-- Flint halves chips and mult: modify_hand returns modded = true (blind.lua:510-517). smods also ORs
-- joker modify_hand flags into it (overrides.lua:2641-2647); only Flint has a 'modify' recipe.
local orig_modify_hand = Blind.modify_hand
function Blind:modify_hand(...)
  local r = pack(orig_modify_hand(self, ...))
  if r[3] and not self.disabled and live() then U.guard('move_modify', moves().on_modify, self) end
  return unpack(r, 1, r.n)
end

-- Psychic, Eye, Mouth return true; Arm and Ox act and set triggered (blind.lua:519-570). Only the real
-- call counts (state_events.lua:614), not the highlight preview (cardarea.lua:168, check = true).
-- Money is read first: the Ox empties it instantly. The base queue's length is read first too: the
-- events after it are the blind's own (The Arm's level change, blind.lua:550-557), which the fist
-- move syncs its slam with (effects.fist).
local orig_debuff_hand = Blind.debuff_hand
function Blind:debuff_hand(cards, hand, handname, check, ...)
  local money = (not check and live()) and director().num(G.GAME.dollars) or nil
  local base = money and G.E_MANAGER and G.E_MANAGER.queues and G.E_MANAGER.queues.base
  local queued = base and #base or nil
  local r = pack(orig_debuff_hand(self, cards, hand, handname, check, ...))
  if money and FinalBoss.logic.hand_debuff_fired(r[1], self.triggered, check, self.disabled) then
    U.guard('move_hand_debuff', moves().on_debuff_hand, self, cards, money, queued)
  end
  return unpack(r, 1, r.n)
end

-- Wheel, House, Mark and Fish keep cards face down (blind.lua:605-622; called per card by draw_card,
-- common_events.lua:402, and CardArea:emplace, cardarea.lua:600). Collected during the draw and
-- flushed by drawn_to_hand as one batch; a live recipe (The House) plays as the cards are dealt.
local orig_stay_flipped = Blind.stay_flipped
function Blind:stay_flipped(area, card, ...)
  local r = pack(orig_stay_flipped(self, area, card, ...))
  if r[1] and area == G.hand and G.STATES and G.STATE == G.STATES.DRAW_TO_HAND and live() then
    U.guard('move_flipped', moves().collect_flipped, self, card)
  end
  return unpack(r, 1, r.n)
end

-- Runs once each draw to hand is complete (game.lua:3238): Cerulean Bell forces a card and Crimson
-- Heart disables a joker (blind.lua:572-603). moves.on_drawn also flushes the face-down batch and
-- marks newly cursed cards.
local orig_drawn_to_hand = Blind.drawn_to_hand
function Blind:drawn_to_hand(...)
  local snap
  if live() then U.guard('move_snapshot', function() snap = moves().snapshot(self) end) end
  local r = pack(orig_drawn_to_hand(self, ...))
  if snap then
    U.guard('move_drawn', moves().on_drawn, self, snap)
    U.guard('phase_drawn', FinalBoss.phases.on_drawn, self, snap) -- phase twists after the boss's move
  end
  return unpack(r, 1, r.n)
end

-- A joker sale disables Verdant Leaf: Card:sell_card sets G.CONTROLLER.locks.selling_card
-- (card.lua:1590) and calls G.GAME.blind:disable() inside the sale's event (card.lua:1616-1620),
-- with no `not disabled` check: every later joker sale calls it again, and Chicot or Luchador may have
-- disabled the blind first. Only a disable that takes effect now (was not disabled before) counts.
local orig_disable = Blind.disable
function Blind:disable(...)
  local selling = (G.CONTROLLER and G.CONTROLLER.locks and G.CONTROLLER.locks.selling_card) and true or false
  local was_disabled = self.disabled
  local r = pack(orig_disable(self, ...))
  if not was_disabled and live() then
    U.guard('move_disable', moves().on_disable, self, selling)
    U.guard('phase_disable', FinalBoss.phases.on_disable, self, selling)
  end
  return unpack(r, 1, r.n)
end

-- Bosses without a recipe (modded) burst when they wiggle (blind.lua:417-422).
local orig_wiggle = Blind.wiggle
function Blind:wiggle(...)
  local r = pack(orig_wiggle(self, ...))
  if live() then U.guard('move_generic', moves().on_wiggle, self) end
  return unpack(r, 1, r.n)
end

-- Idle taunts (1.2) ---------------------------------------------------------------------------------
-- A click or a controller button restarts the boss's idle clock (keys: the love.keypressed wrap above).
-- Vanilla's handlers are main.lua:154-176; each wrap calls the original first and returns its results.
local orig_mousepressed = love.mousepressed
if orig_mousepressed then
  function love.mousepressed(...)
    local r = pack(orig_mousepressed(...))
    U.guard('input', FinalBoss.observe.on_input)
    return unpack(r, 1, r.n)
  end
end

-- Poke the boss (1.2): a click on the HUD blind chip (poke.lua; the showdown avatar is FinalBoss's own
-- object, Avatar:click). Vanilla defines no Blind:click, so this wraps the no-op Node:click
-- (engine/node.lua:383) that G.CONTROLLER calls on a short press and release (engine/controller.lua:340-346,
-- :371-374). The intro's chip skip sets its own click on the blind instance (dialogue.lua), which
-- shadows this wrap while the intro runs. Drags are read from G.CONTROLLER in the tick (poke.tick).
local orig_blind_click = Blind.click
function Blind:click(...)
  local r = pack(orig_blind_click(self, ...))
  if live() then U.guard('poke', FinalBoss.poke.on_click, self) end
  return unpack(r, 1, r.n)
end

local orig_gamepadpressed = love.gamepadpressed
if orig_gamepadpressed then
  function love.gamepadpressed(...)
    local r = pack(orig_gamepadpressed(...))
    U.guard('input', FinalBoss.observe.on_input)
    return unpack(r, 1, r.n)
  end
end

return H

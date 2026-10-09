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
--- dialogue's REACTION_GAP): the booking goes back (like logic.poke_unsaid), so the kind can still
--- get its line later in the blind.
local function react(kind)
  local enc = R.encounter()
  if not enc then return end
  local state = enc.tricks or {}
  enc.tricks = state
  local last = state.last
  local moment = L().trick_reaction(state, kind, FinalBoss.util.now())
  if not (moment and FinalBoss.config.dialogue) then return end
  local _, shown = FinalBoss.director.fire(moment, {free = true})
  if not shown then state.seen[kind], state.last = nil, last end
end

--- A consumable was used (hooks.lua's Card:use_consumeable wrap).
function R.on_consumable(card)
  local set = card and card.ability and card.ability.set
  if set == 'Tarot' or set == 'Spectral' or set == 'Planet' then react(set) end
end

--- A card was added to the deck (hooks.lua's Card:add_to_deck wrap): a joker newly created. Not a
--- joker coming back from a debuff (from_debuff: Card:set_debuff, card.lua:535), not one already in
--- the deck (was_added: self.added_to_deck before the call), not a save being restored (R.restoring).
--- Vanilla's restore never calls add_to_deck (CardArea:load builds the cards and Card:load copies
--- added_to_deck from the save, card.lua:4706); R.restoring covers mods that do. in_jokers: the card
--- was already in G.jokers before the call (a joker transforming in place; new ones are emplaced after).
--- Riff-raff's jokers come in setting_blind, while the intro speaks: no line, on purpose.
function R.on_joker_added(card, from_debuff, was_added, in_jokers)
  if from_debuff or was_added or in_jokers or R.restoring then return end
  if card and card.ability and card.ability.set == 'Joker' then react('Joker') end
end

return R

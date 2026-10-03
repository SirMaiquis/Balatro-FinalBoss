--- Curse marks (1.1): a mark fitted to each card a card_debuff boss curses, drawn on the card for as
--- long as the curse holds: 'suit' (Club, Goad, Window, Head: a dark suit-coloured frame and the
--- suit's badge), 'vine' (The Plant) or 'crack' (The Pillar). A new mark fades in over
--- logic.CURSE_GROW seconds (at once under reduced motion), then stays as a quiet overlay.
---
--- Art: card-sized frames of the 'curse_marks' atlas (assets/1x|2x/curse_marks.png, tools/make_art.py;
--- cells: logic.MARK_FRAMES / logic.mark_frame), inside the card's own silhouette.
--- Drawing: an SMODS.DrawStep (smods src/card_draw.lua:64-104, run by Card:draw for every card at
--- src/card_draw.lua:570-577), so the mark is part of the card's own draw wherever the card is drawn
--- (hand, play, discard, deck view). Each mark is drawn exactly like a seal or a sticker - vanilla
--- card.lua:4474-4475 / smods src/card_draw.lua:339-340 and :352-353:
---   sprite:draw_shader('dissolve', nil, nil, nil, card.children.center)
--- Sprite:draw_shader (engine/sprite.lua:73-124) draws through Sprite:draw_from (:180-198), which takes
--- the transform of card.children.center (position, rotation, scale, juice, the flip pinch) and scales
--- the frame to the card, and the dissolve shader's vertex stage applies the card's hover tilt (from
--- the sprite's role.draw_major: tilt_var, hover_tilt). So the mark moves 1:1 with the card.
--- Fade-in: draw_from always paints in white (G.BRUTE_OVERLAY or G.C.WHITE, sprite.lua:186), so the
--- fade uses the shader's dissolve uniform, which draw_shader reads from role.draw_major.dissolve
--- (sprite.lua:99): role.draw_major is a proxy that copies the card's tilt fields and ID and carries
--- logic.mark_dissolve (1 - growth, or the card's own dissolve when it dissolves away).
---
--- State: card.fb_curse = {style, burn, suit, key, born, epoch, card} (transient: Card:save
--- only saves its own fields, card.lua:4625). Marks of an older epoch are stale (C.clear on a new
--- blind, the blind's defeat and run teardown). Deck-view copies share their card's params table
--- (copy_card, common_events.lua:2175), so C.by_params finds the original's mark for them.
local C = {}
C.epoch = 0
C.live = 0 -- marks made this epoch; the draw step returns at once while it is 0
C.by_params = setmetatable({}, {__mode = 'k'})
C.sprites = {} -- atlas cell -> Sprite, made on first use (a run's sprites go with the run: node.lua:85)

local function L() return FinalBoss.logic end
local function now() return FinalBoss.util.now() end

--- Forget every mark (a new blind, the blind is over, run teardown).
function C.clear()
  C.epoch = C.epoch + 1
  C.live = 0
  C.by_params = setmetatable({}, {__mode = 'k'})
end

--- Mark cards cursed by `blind` (default: the current blind). A card already marked this epoch keeps
--- its mark (and its birth time), unless `fresh` (a re-roll curses it anew: the mark grows in again).
--- Cards of one batch are born CURSE_STAGGER apart. Returns the number of new marks.
function C.mark(cards, style, colour, blind, fresh)
  blind = blind or (G.GAME and G.GAME.blind)
  local proto = blind and blind.config and blind.config.blind
  if not (proto and proto.key and L().CURSE_STYLES[style]) then return 0 end
  colour = colour or G.C.RED
  local suit = blind.debuff and blind.debuff.suit
  local burn = {colour, darken(colour, 0.35)} -- the dissolve shader's edge colours while it fades in
  local t, n = now(), 0
  for _, card in ipairs(cards or {}) do
    local old = type(card) == 'table' and card.fb_curse
    if type(card) == 'table' and not card.REMOVED and (fresh or not (old and old.epoch == C.epoch)) then
      local m = {style = style, burn = burn, suit = suit, key = proto.key,
        born = t + n * L().CURSE_STAGGER, epoch = C.epoch, card = card}
      card.fb_curse = m
      if type(card.params) == 'table' then C.by_params[card.params] = m end
      C.live = C.live + 1
      n = n + 1
    end
  end
  return n
end

-- Drawing ----------------------------------------------------------------------------------------------

--- The sprite of atlas cell (x, y): card-sized (G.CARD_W x G.CARD_H, like vanilla's shared seals,
--- game.lua:189-194), made through SMODS.create_sprite (smods src/utils.lua:3996-4005) and cached. A
--- sprite made during a run is removed with the run (Node:init registers it as a stage object,
--- engine/node.lua:85; Game:delete_run, game.lua:1144), so a removed one is made again.
local function sprite_at(x, y)
  local i = y * 16 + x
  local s = C.sprites[i]
  if s and not s.REMOVED then return s end
  local prefix = (FinalBoss.mod and FinalBoss.mod.prefix) or 'FinalBoss'
  s = SMODS.create_sprite(0, 0, G.CARD_W, G.CARD_H, prefix .. '_curse_marks', {x = x, y = y})
  s.states.collide.can, s.states.hover.can = false, false
  s.states.click.can, s.states.drag.can = false, false
  C.sprites[i] = s
  return s
end

--- The draw_major the shader reads (engine/sprite.lua:75-104): the card's tilt fields and ID, the
--- mark's dissolve and edge colours. One table, refilled for every draw.
local major = {}

local lg = love.graphics

--- Draw card's mark m (the DrawStep below, through util.guard). Visible only while the card (and, for
--- a deck-view copy, its original) is debuffed by the blind that cursed it, that blind is current and
--- not disabled (or the debuff is the Leaf regrowth twist's), the round is on, and moves and screen
--- effects are enabled.
function C.draw(card, m)
  if m.epoch ~= C.epoch then
    if card.fb_curse == m then card.fb_curse = nil end
    return
  end
  local owner = m.card
  local cfg, st = FinalBoss.config, G.GAME and G.GAME.FinalBoss
  local on = (cfg.moves and cfg.fx and not (st and st.disabled_for_run)) and true or false
  local b = G.GAME and G.GAME.blind
  local bkey = b and b.config and b.config.blind and b.config.blind.key
  -- the Verdant Leaf regrowth twist (phases.lua) debuffs through its own SMODS.debuff_card source on
  -- the blind a sale disabled: its vine shows while that source holds
  local src = owner.ability and owner.ability.debuff_sources
  local twist = (src and src[FinalBoss.phases.LEAF_SOURCE]) and true or false
  if not L().curse_visible(owner.debuff and card.debuff, owner.debuffed_by_blind, m.key, bkey,
      b and b.disabled, G.GAME and G.GAME.facing_blind, on, twist) then return end
  local center = card.children and card.children.center
  if not center then return end
  -- the suit's palette as smods picks it (G.FUNCS.update_suit_colours, smods src/utils.lua:1274-1286)
  local pal = m.suit and G.SETTINGS.colour_palettes and G.SETTINGS.colour_palettes[m.suit]
  local x, y = L().mark_frame(m.style, m.suit, pal == 'hc')
  if not x then return end
  local own = math.abs(card.dissolve or 0)
  local d = L().mark_dissolve(L().curse_grow(now() - m.born, G.SETTINGS.reduced_motion), own)
  if d >= 0.999 then return end
  local s = sprite_at(x, y)
  major.ID, major.tilt_var, major.hover_tilt, major.mouse_damping = card.ID, card.tilt_var, card.hover_tilt,
    card.mouse_damping
  major.dissolve = d
  major.dissolve_colours = (own > 0 and own >= d) and card.dissolve_colours or m.burn
  s.role.draw_major = major
  local depth = lg.getStackDepth and lg.getStackDepth()
  local ok, err
  if card.greyed then
    -- greyed like the card (smods' greyed step, src/card_draw.lua:471-483: the 'played' shader)
    ok, err = pcall(s.draw_shader, s, 'played', nil, card.ARGS.send_to_shader, nil, center)
  else
    ok, err = pcall(s.draw_shader, s, 'dissolve', nil, nil, nil, center)
  end
  major.tilt_var, major.dissolve_colours = nil, nil -- hold no card table between frames
  if not ok then
    lg.setShader()
    while depth and lg.getStackDepth() > depth do lg.pop() end -- balance draw_from's push
    error(err, 0)
  end
end

-- order 85: after smods' debuff (70) and greyed (80) shaders, which redraw the card over the seals and
-- stickers (30, 40), and before the card's children (others, 90): src/card_draw.lua:457-535.
-- Face-down cards show no mark.
SMODS.DrawStep{
  key = 'curse_mark',
  order = 85,
  conditions = {vortex = false, facing = 'front'},
  func = function(card)
    if C.live == 0 then return end
    local m = card.fb_curse or C.by_params[card.params]
    if m then FinalBoss.util.guard('curse_draw', C.draw, card, m) end
  end,
}

return C

--- Curse marks (1.1): a mark fitted to each card a card_debuff boss curses, drawn on the card for as
--- long as the curse holds: 'suit' (Club, Goad, Window, Head: a dark suit-coloured frame and the
--- suit's badge), 'vine' (The Plant) or 'crack' (The Pillar). A new mark grows in over
--- logic.CURSE_GROW seconds (at once under reduced motion), then stays as a quiet overlay.
---
--- Drawing: an SMODS.DrawStep (smods src/card_draw.lua:64-104, run by Card:draw for every card at
--- src/card_draw.lua:570-577), so the mark is part of the card's own draw wherever the card is drawn
--- (hand, play, discard, deck view) and uses the card sprite's transform (prep_draw on
--- card.children.center, the way vanilla draws seals and stickers from the card's center sprite).
---
--- State: card.fb_curse = {style, colour, dark, deep, suit, key, born, epoch, card} (transient: Card:save
--- only saves its own fields, card.lua:4625). Marks of an older epoch are stale (C.clear on a new
--- blind, the blind's defeat and run teardown). Deck-view copies share their card's params table
--- (copy_card, common_events.lua:2175), so C.by_params finds the original's mark for them.
local C = {}
C.epoch = 0
C.live = 0 -- marks made this epoch; the draw step returns at once while it is 0
C.by_params = setmetatable({}, {__mode = 'k'})
C.badges = {} -- suit -> {image, key, quad, px, py}: the suit's UI icon

local function L() return FinalBoss.logic end
local function now() return FinalBoss.util.now() end

--- Forget every mark (a new blind, the blind is over, run teardown).
function C.clear()
  C.epoch = C.epoch + 1
  C.live = 0
  C.by_params = setmetatable({}, {__mode = 'k'})
end

--- Mark cards cursed by `blind` (default: the current blind). A card already marked this epoch keeps
--- its mark (and its birth time). Cards of one batch are born CURSE_STAGGER apart. Returns the number
--- of new marks.
function C.mark(cards, style, colour, blind)
  blind = blind or (G.GAME and G.GAME.blind)
  local proto = blind and blind.config and blind.config.blind
  if not (proto and proto.key and L().CURSE_STYLES[style]) then return 0 end
  colour = colour or G.C.RED
  local suit = blind.debuff and blind.debuff.suit
  local dark, deep = darken(colour, 0.35), darken(colour, 0.6)
  local t, n = now(), 0
  for _, card in ipairs(cards or {}) do
    local old = type(card) == 'table' and card.fb_curse
    if type(card) == 'table' and not card.REMOVED and not (old and old.epoch == C.epoch) then
      local m = {style = style, colour = colour, dark = dark, deep = deep, suit = suit, key = proto.key,
        born = t + n * L().CURSE_STAGGER, epoch = C.epoch, card = card}
      card.fb_curse = m
      if type(card.params) == 'table' then C.by_params[card.params] = m end
      C.live = C.live + 1
      n = n + 1
    end
  end
  return n
end

-- Drawing (card-local units: the card spans 0..w x 0..h) --------------------------------------------

local lg = love.graphics

local function paint(c, a) lg.setColor(c[1], c[2], c[3], (c[4] or 1) * a) end

--- The suit's UI icon, as smods' deck view picks it (src/overrides.lua:817-823: the suit's lc/hc UI
--- atlas, vanilla ui_assets 'ui_1'/'ui_2', at SMODS.Suits[suit].ui_pos). The quad is built like
--- Sprite:set_sprite_pos (engine/sprite.lua:24-38) and rebuilt when the atlas image changes.
function C.badge(suit)
  local def = suit and SMODS.Suits and SMODS.Suits[suit]
  if not (def and def.ui_pos) then return nil end
  local pal = G.SETTINGS.colour_palettes and G.SETTINGS.colour_palettes[suit]
  local key = (pal == 'hc' and def.hc_ui_atlas) or def.lc_ui_atlas or 'ui_1'
  local atlas = SMODS.get_atlas(key) or G.ASSET_ATLAS['ui_1']
  if not (atlas and atlas.image) then return nil end
  local b = C.badges[suit]
  if b and b.image == atlas.image and b.key == key then return b end
  local pos = def.ui_pos
  b = {image = atlas.image, key = key, px = atlas.px, py = atlas.py,
    quad = lg.newQuad(pos.x * atlas.px, pos.y * atlas.py, atlas.px, atlas.py, atlas.image:getDimensions())}
  C.badges[suit] = b
  return b
end

--- A polyline (card units) revealed to growth g: whole segments, then part of the next one. Round
--- dots at the joints stand in for line joins (each segment is its own line: no allocation).
local function stroke(pts, w, h, g, lw)
  local n = #pts / 2 - 1
  local k, f = L().reveal(g, n)
  if k == 0 and f == 0 then return end
  local r = lw / 2
  lg.circle('fill', pts[1] * w, pts[2] * h, r)
  for i = 1, k do
    local x2, y2 = pts[2 * i + 1] * w, pts[2 * i + 2] * h
    lg.line(pts[2 * i - 1] * w, pts[2 * i] * h, x2, y2)
    lg.circle('fill', x2, y2, r)
  end
  if f > 0 and k < n then
    local i = k + 1
    local x1, y1 = pts[2 * i - 1] * w, pts[2 * i] * h
    local x2, y2 = x1 + (pts[2 * i + 1] * w - x1) * f, y1 + (pts[2 * i + 2] * h - y1) * f
    lg.line(x1, y1, x2, y2)
    lg.circle('fill', x2, y2, r)
  end
end

--- Club / Goad / Window / Head: a dark frame in the suit's colour hugging the card's rounded edge, a
--- thin inner line in the suit colour and the suit badge in the top-right corner (the corner the
--- card's own rank and pip leave free). Grows in by scale.
local function draw_suit(m, w, h, g, a)
  local s = 0.82 + 0.18 * g
  lg.translate(w / 2, h / 2)
  lg.scale(s)
  lg.translate(-w / 2, -h / 2)
  local lw, r = w * 0.06, w * 0.08
  paint(m.dark, 0.92 * a)
  lg.setLineWidth(lw)
  lg.rectangle('line', lw / 2, lw / 2, w - lw, h - lw, r, r)
  local i = lw * 1.25
  paint(m.colour, 0.85 * a)
  lg.setLineWidth(lw * 0.3)
  lg.rectangle('line', i, i, w - 2 * i, h - 2 * i, r * 0.7, r * 0.7)
  local br = w * 0.14
  local cx, cy = w - br - lw * 0.35, br + lw * 0.35
  paint(m.dark, a)
  lg.circle('fill', cx, cy, br)
  paint(m.colour, a)
  lg.setLineWidth(lw * 0.35)
  lg.circle('line', cx, cy, br)
  local b = C.badge(m.suit)
  if b then
    local sz = br * 1.35
    lg.setColor(1, 1, 1, a)
    lg.draw(b.image, b.quad, cx - sz / 2, cy - sz / 2, 0, sz / b.px, sz / b.py)
  end
end

--- The Plant: dark stems climb from the bottom corners and creep across the face, leaves in the boss
--- colour open as the stems pass them. Grows along the stems.
local function draw_vine(m, w, h, g, a)
  local shape = L().CURSE_SHAPES.vine
  local lw = w * 0.045
  paint(m.dark, 0.95 * a)
  lg.setLineWidth(lw)
  for _, pts in ipairs(shape.strokes) do stroke(pts, w, h, g, lw) end
  for _, leaf in ipairs(shape.leaves) do
    if g >= leaf[4] then
      local ls = (g >= 1) and 1 or math.min(1, (g - leaf[4]) / 0.12)
      lg.push()
      lg.translate(leaf[1] * w, leaf[2] * h)
      lg.rotate(leaf[3])
      paint(m.colour, a)
      lg.ellipse('fill', 0, 0, ls * w * 0.08, ls * w * 0.042)
      paint(m.dark, a)
      lg.setLineWidth(lw * 0.3)
      lg.line(-ls * w * 0.07, 0, ls * w * 0.07, 0)
      lg.pop()
    end
  end
end

--- The Pillar: dark fractures run across the card from top to bottom and edge to edge, each with a
--- pale highlight on one side so it reads as a split in the card, not a drawn line.
local function draw_crack(m, w, h, g, a)
  local strokes = L().CURSE_SHAPES.crack.strokes
  local lw = w * 0.038
  paint(m.deep, 0.95 * a)
  lg.setLineWidth(lw)
  for _, pts in ipairs(strokes) do stroke(pts, w, h, g, lw) end
  lg.push()
  lg.translate(lw * 0.6, lw * 0.45)
  lg.setColor(1, 1, 1, 0.55 * a)
  lg.setLineWidth(lw * 0.35)
  for _, pts in ipairs(strokes) do stroke(pts, w, h, g, lw * 0.35) end
  lg.pop()
end

local STYLES = {suit = draw_suit, vine = draw_vine, crack = draw_crack}

--- Draw card's mark m (the DrawStep below, through util.guard). Visible only while the card (and, for
--- a deck-view copy, its original) is debuffed by the blind that cursed it, that blind is current and
--- not disabled, the round is on, and moves and screen effects are enabled.
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
  if not L().curse_visible(owner.debuff and card.debuff, owner.debuffed_by_blind, m.key, bkey,
      b and b.disabled, G.GAME and G.GAME.facing_blind, on) then return end
  local sp = card.children and card.children.center
  local draw_style = STYLES[m.style]
  if not (sp and draw_style) then return end
  local g = L().curse_grow(now() - m.born, G.SETTINGS.reduced_motion)
  local a = g * (1 - math.min(1, math.abs(card.dissolve or 0))) * (card.greyed and 0.5 or 1)
  if a <= 0 then return end
  local lw0 = lg.getLineWidth()
  prep_draw(sp, 1) -- the card sprite's own transform: position, rotation, juice and flip pinch
  local ok, err = pcall(draw_style, m, sp.VT.w, sp.VT.h, g, a)
  lg.pop() -- always balance prep_draw's push, even when the style failed
  lg.setLineWidth(lw0)
  lg.setColor(1, 1, 1, 1)
  if not ok then error(err, 0) end
end

-- order 85: after smods' debuff (70) and greyed (80) shaders, which redraw the card opaquely, and
-- before the card's children (others, 90): src/card_draw.lua:457-535. Face-down cards show no mark.
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

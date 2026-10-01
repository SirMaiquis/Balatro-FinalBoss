--- Boss HP bar (spec 2026-10-01 §6): hangs under the avatar; damage trail, stage flashes and
--- damage numbers. Numbers only — no localized text beyond the game's own boss name.
local H = {}
H.W, H.H = 3.0, 0.22
H.GHOST_HOLD, H.GHOST_DRAIN = 0.4, 0.35
H.DARKEN = {[0] = 0, [1] = 0.2, [2] = 0.4}
H.bar, H.ui = nil, nil
H.view = {text = ''}
H.frac, H.ghost, H.ghost_until, H.flash_until, H.stage = 1, 1, 0, 0, 0
H.colour = {1, 0, 0, 1}

local function now() return FinalBoss.util.now() end

local Bar = Moveable:extend()

function Bar:init(W, Hh)
  Moveable.init(self, 0, 0, W, Hh)
  self.children = {}
  self.states.collide.can = false
  self.states.hover.can = false
  -- Not registered in G.I.MOVEABLE: the text UIBox hosts the bar as an object node and draws it.
end

function Bar:draw()
  if not self.states.visible then return end
  prep_draw(self, 1)
  local w, h = self.VT.w, self.VT.h
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.rectangle('fill', -0.05, -0.05, w + 0.1, h + 0.1, 0.06, 0.06)
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.rectangle('fill', 0, 0, w * H.ghost, h)
  local c = darken(H.colour, H.DARKEN[H.stage] or 0)
  love.graphics.setColor(c[1], c[2], c[3], 1)
  love.graphics.rectangle('fill', 0, 0, w * H.frac, h)
  if now() < H.flash_until then
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.rectangle('fill', 0, 0, w, h)
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.pop()
  add_to_drawhash(self)
end

local function text_ui(avatar, name)
  return UIBox{
    definition = {n = G.UIT.ROOT, config = {align = 'cm', colour = G.C.CLEAR, padding = 0.02}, nodes = {
      {n = G.UIT.R, config = {align = 'cm'}, nodes = {
        {n = G.UIT.T, config = {text = name, scale = 0.32, colour = G.C.WHITE, shadow = true}}}},
      {n = G.UIT.R, config = {align = 'cm', padding = 0.05}, nodes = {
        {n = G.UIT.O, config = {object = H.bar}}}},
      {n = G.UIT.R, config = {align = 'cm'}, nodes = {
        {n = G.UIT.T, config = {ref_table = H.view, ref_value = 'text', scale = 0.28, colour = G.C.WHITE, shadow = true}}}},
    }},
    config = {major = avatar, align = 'bm', offset = {x = 0, y = 0.05}, bond = 'Weak', r_bond = 'Weak',
      can_collide = false},
  }
end

function H.exists() return H.bar ~= nil end

function H.create(avatar, blind, total, required)
  H.remove()
  if not avatar or not blind then return end
  local c = (blind.config.blind and blind.config.blind.boss_colour) or G.C.RED
  H.colour = {c[1], c[2], c[3], 1}
  H.update(total, required, true) -- first: the first layout must see the real text
  H.bar = Bar(H.W, H.H) -- before the UI: the object node reads its size
  H.ui = text_ui(avatar, blind.loc_name or (blind.config.blind and blind.config.blind.name) or '')
  H.ui.attention_text = true -- drawn in vanilla's late pass, above cards (cf. boss_warning_text)
end

function H.update(total, required, instant)
  local frac = FinalBoss.logic.hp_fraction(total, required)
  local stage = FinalBoss.logic.wound_stage(frac)
  if stage ~= H.stage and not instant then H.flash_until = now() + 0.3 end
  H.stage, H.frac = stage, frac
  if instant then H.ghost = frac end
  H.ghost_until = now() + H.GHOST_HOLD
  local hp = math.max(0, (required or 0) - (total or 0))
  local text = number_format(hp) .. ' / ' .. number_format(required or 0)
  local relayout = H.ui and #text ~= #H.view.text
  H.view.text = text
  if relayout then
    H.ui:recalculate()
    H.ui.alignment.prev_type = '' -- forces align_to_major to re-centre on the next move
  end
end

function H.damage(delta, size)
  local anchor = FinalBoss.avatar.anchor()
  if not anchor or not delta or delta <= 0 then return end
  attention_text{
    text = '-' .. number_format(delta),
    scale = (size == 'big' and 1.6) or (size == 'weak' and 0.6) or 1.0,
    hold = 0.9,
    major = anchor,
    align = 'tm',
    offset = {x = 0, y = -0.3},
    colour = (size == 'weak') and G.C.UI.TEXT_INACTIVE or G.C.RED,
    silent = true,
  }
  if size == 'big' and not G.SETTINGS.reduced_motion then G.ROOM.jiggle = G.ROOM.jiggle + 2 end
end

function H.tick(dt)
  if not H.bar then return end
  if H.ghost > H.frac and now() >= H.ghost_until then
    H.ghost = math.max(H.frac, H.ghost - (dt or 0) / H.GHOST_DRAIN)
  end
end

function H.remove()
  -- UIElement:remove removes the O node's config.object, so removing the box removes the bar once.
  if H.ui then H.ui:remove(); H.ui = nil end
  H.bar = nil
  H.frac, H.ghost, H.stage = 1, 1, 0
  H.view.text, H.flash_until, H.ghost_until = '', 0, 0
end

return H

--- Effects library (1.1): ten visual primitives shared by boss moves, deaths and phase changes:
--- fling, drain, crack, stamp, sweep, glare, chain, ring, spin, burst (logic.EFFECTS).
--- E.<name>(src, target, opts):
---   src    = performer {x, y, w, h, obj, colour, avatar} (moves.performer) or any rectangle
---   target = list of cards | CardArea | UIElement | nil (each primitive says which it reads)
---   opts   = step options; opts.colour is resolved by the caller, opts.scale > 1 = played big
--- Everything runs on the REAL timer through guarded events and is visual only (never saved).
--- Reduced motion: nothing travels, jolts, slides or spins; flashes, marks and particles stay.
--- Callers check config.fx first (moves.enabled, deaths.play, phases).
local E = {}
E.host = nil -- invisible attention_text UIBox: its children draw in vanilla's late pass (above cards)
E.gen = 0    -- bumped by E.reset(): timers of a torn-down run do nothing

local function reduced() return G.SETTINGS.reduced_motion end
local function now() return FinalBoss.util.now() end
--- A colour list must never hold nil (vanilla Particles:draw does not guard it).
local function col(c) return c or G.C.WHITE end

local function after(delay, fn)
  local gen = E.gen
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = delay, timer = 'REAL', blocking = false,
    blockable = false, func = function()
      if E.gen == gen then FinalBoss.util.guard('effect_timer', fn) end
      return true
    end}))
end

-- Layer -------------------------------------------------------------------------------------------

local function host()
  if E.host and not E.host.REMOVED then return E.host end
  E.host = UIBox{
    definition = {n = G.UIT.ROOT, config = {align = 'cm', colour = G.C.CLEAR, minw = 0.01, minh = 0.01}, nodes = {}},
    config = {major = G.ROOM_ATTACH, align = 'tl', offset = {x = 0, y = 0}, bond = 'Weak', can_collide = false},
  }
  E.host.attention_text = true -- Game:draw draws attention_text UIBoxes after the cards
  return E.host
end

--- Give an effect object to the layer: UIBox:draw draws its children; the MOVEABLE draw pass skips
--- parented objects; G.MOVEABLES still moves and updates them every frame.
local function adopt(obj)
  local h = host()
  obj.parent = h
  h.children[obj] = obj
  return obj
end

local function drop(obj)
  if not obj or obj.REMOVED then return end
  if E.host and E.host.children then E.host.children[obj] = nil end
  obj.parent = nil
  obj:remove()
end

--- Remove obj after `life` seconds; particles fade over the last 0.3 s.
local function expire(obj, life)
  if obj.fade then
    after(math.max(0, life - 0.3), function() if not obj.REMOVED then obj:fade(0.3) end end)
  end
  after(life, function() drop(obj) end)
end

-- Marks: shapes drawn with love.graphics (no new art) ----------------------------------------------

local Mark = Moveable:extend()
E.Mark = Mark

--- args: shape ('ring', 'flash', 'coin', 'bar', 'fill', 'beam', 'glyph', 'heart', 'leaf', 'none'),
--- colour, alpha (bar), life (s), glyph (logic.GLYPHS key), width (line width, room units),
--- x2/y2 (beam end, room units), path {x0, y0, x1, y1} (top-left travels over `travel` seconds,
--- default life), follower (an object whose top-left follows this mark: a particle trail),
--- spin (radians per second).
function Mark:init(x, y, w, h, args)
  Moveable.init(self, x, y, w, h)
  self.states.collide.can, self.states.hover.can = false, false
  self.states.click.can, self.states.drag.can = false, false
  self.shape = args.shape or 'none'
  self.colour = args.colour or G.C.WHITE
  self.alpha = args.alpha or 0.9
  self.life = args.life or 0.6
  self.travel = args.travel or self.life
  self.glyph, self.width = args.glyph, args.width or 0.06
  self.x2, self.y2 = args.x2, args.y2
  self.path, self.follower, self.spin = args.path, args.follower, args.spin
  self.t0 = now()
  self:hard_set_VT()
end

function Mark:progress() return math.min(1, (now() - self.t0) / self.life) end

function Mark:move(dt)
  if self.path then
    local p = math.min(1, (now() - self.t0) / self.travel)
    local e = 1 - (1 - p) * (1 - p) -- ease out
    self.T.x = self.path[1] + (self.path[3] - self.path[1]) * e
    self.T.y = self.path[2] + (self.path[4] - self.path[2]) * e
  end
  if self.spin then self.T.r = self.spin * (now() - self.t0) end
  self.VT.x, self.VT.y, self.VT.r = self.T.x, self.T.y, self.T.r
  local f = self.follower
  if f and not f.REMOVED then f.T.x, f.T.y = self.T.x, self.T.y end
end

local function paint(c, a) love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * a) end

local function polyline(stroke, w, h)
  local pts = {}
  for i = 1, #stroke, 2 do
    pts[#pts + 1] = stroke[i] * w
    pts[#pts + 1] = stroke[i + 1] * h
  end
  love.graphics.line(pts)
end

function Mark:draw()
  if self.shape == 'none' then return end
  local p = self:progress()
  local a = 1 - p
  local w, h = self.VT.w, self.VT.h
  local lw = love.graphics.getLineWidth()
  prep_draw(self, 1)
  love.graphics.setLineWidth(self.width)
  local s = self.shape
  if s == 'ring' then
    paint(self.colour, a)
    love.graphics.circle('line', w / 2, h / 2, (w / 2) * (0.3 + 0.9 * p))
  elseif s == 'flash' then
    paint(self.colour, 0.75 * a)
    love.graphics.circle('fill', w / 2, h / 2, w * 0.45)
  elseif s == 'coin' then
    paint(G.C.MONEY, math.min(1, 3 * a))
    love.graphics.circle('fill', w / 2, h / 2, w / 2)
  elseif s == 'bar' then
    paint(self.colour, self.alpha * math.min(1, 4 * a))
    love.graphics.rectangle('fill', 0, 0, w, h)
  elseif s == 'fill' then
    local rise = reduced() and 1 or math.min(1, 2 * p)
    paint(self.colour, 0.65 * math.min(1, 3 * a))
    love.graphics.rectangle('fill', 0, h * (1 - rise), w, h * rise)
  elseif s == 'beam' then
    paint(self.colour, a)
    love.graphics.line(0, 0, self.x2 - self.VT.x, self.y2 - self.VT.y)
  elseif s == 'glyph' then
    paint(self.colour, math.min(1, 3 * a))
    for _, stroke in ipairs(FinalBoss.logic.GLYPHS[self.glyph] or {}) do polyline(stroke, w, h) end
  elseif s == 'heart' then
    paint(self.colour, math.min(1, 3 * a))
    love.graphics.circle('fill', w * 0.3, h * 0.35, w * 0.22)
    love.graphics.circle('fill', w * 0.7, h * 0.35, w * 0.22)
    love.graphics.polygon('fill', w * 0.1, h * 0.45, w * 0.9, h * 0.45, w * 0.5, h * 0.95)
  elseif s == 'leaf' then
    paint(self.colour, math.min(1, 3 * a))
    love.graphics.ellipse('fill', w / 2, h / 2, w / 2, h / 4)
  end
  love.graphics.pop()
  love.graphics.setLineWidth(lw)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Helpers -----------------------------------------------------------------------------------------

local function centre(T) return T.x + T.w / 2, T.y + T.h / 2 end

--- Live cards from a list of cards or a CardArea (G.hand, G.jokers).
local function cards_of(target)
  local list = (type(target) == 'table' and target.cards) or target or {}
  local out = {}
  for _, c in ipairs(list) do
    if type(c) == 'table' and c.T and not c.REMOVED then out[#out + 1] = c end
  end
  return out
end

function E.flash_at(x, y, w, h, colour)
  expire(adopt(Mark(x, y, w, h, {shape = 'flash', colour = colour, life = 0.35})), 0.35)
end

local function flash_rect(T, colour)
  expire(adopt(Mark(T.x, T.y, T.w, T.h, {shape = 'bar', colour = colour, alpha = 0.5, life = 0.3})), 0.3)
end

--- The performer reacts to its own move: juice (vanilla Moveable:juice_up is a no-op under reduced
--- motion) and a flash in its colour (the avatar's own flash, or a flash mark over the HUD chip).
function E.react(src, colour, big)
  local o = src.obj
  if o and o.juice_up then o:juice_up(big and 0.6 or 0.35, big and 0.3 or 0.15) end
  if src.avatar then FinalBoss.avatar.flash(0.2, colour or src.colour)
  else E.flash_at(src.x, src.y, src.w, src.h, colour or src.colour) end
end

-- The ten primitives ------------------------------------------------------------------------------

--- fling(cards): each card jolts and a trail streaks from it to the source; vanilla still moves the
--- card itself. Reduced motion: a flash on each card instead.
function E.fling(src, target, opts)
  local sx, sy = centre(src)
  for i, card in ipairs(cards_of(target)) do
    after((i - 1) * 0.08, function()
      if card.REMOVED then return end
      local T = card.T
      if reduced() then return E.flash_at(T.x, T.y, T.w, T.h, opts.colour) end
      card:juice_up(0.5, 0.4)
      local cx, cy = centre(T)
      local trail = adopt(Particles(cx, cy, 0.2, 0.2, {timer = 0.015, scale = 0.25, speed = 0.6,
        lifespan = 0.45, colours = {col(opts.colour), G.C.WHITE}, fill = true}))
      expire(adopt(Mark(cx, cy, 0, 0, {life = 0.35, path = {cx, cy, sx, sy}, follower = trail})), 0.35)
      expire(trail, 0.8)
    end)
  end
end

--- drain(amount): coins stream from the money counter to the source; the counter juices.
--- opts.amount = dollars taken (logic.coin_count caps the coins). Reduced motion: two flashes.
function E.drain(src, _, opts)
  local n = FinalBoss.logic.coin_count(opts.amount or 0, 12)
  local uie = G.HUD and G.HUD:get_UIE_by_ID('dollar_text_UI')
  if n <= 0 or not (uie and uie.T) then return end
  local o = uie.config and uie.config.object
  if o and o.juice_up then o:juice_up(0.4, 0.2) end
  local T = uie.T
  if reduced() then
    flash_rect(T, G.C.MONEY)
    return E.flash_at(src.x, src.y, src.w, src.h, G.C.MONEY)
  end
  local ux, uy = centre(T)
  local sx, sy = centre(src)
  for i = 1, n do
    after((i - 1) * 0.06, function()
      expire(adopt(Mark(ux - 0.1, uy - 0.1, 0.2, 0.2, {shape = 'coin', life = 0.45,
        path = {ux - 0.1, uy - 0.1, sx - 0.1, sy - 0.1}})), 0.45)
    end)
  end
end

--- crack(uie): a HUD element juices, flashes and shows a split. opts.style 'fill': a rising bar
--- (Violet Vessel); 'slam': a bar drops onto it first (The Arm; no drop under reduced motion).
function E.crack(src, uie, opts)
  if not (uie and uie.T) then return end
  local T = uie.T
  local o = uie.config and uie.config.object
  if o and o.juice_up then o:juice_up(0.6, 0.3)
  elseif uie.juice_up then uie:juice_up(0.6, 0.3) end
  if opts.style == 'fill' then
    return expire(adopt(Mark(T.x, T.y, T.w, T.h, {shape = 'fill', colour = opts.colour, life = 1.1})), 1.1)
  end
  if opts.style == 'slam' and not reduced() then
    expire(adopt(Mark(T.x, T.y - 1.2, T.w, 0.12, {shape = 'bar', colour = opts.colour, life = 0.3,
      path = {T.x, T.y - 1.2, T.x, T.y}})), 0.3)
  end
  flash_rect(T, opts.colour)
  expire(adopt(Mark(T.x, T.y, T.w, T.h, {shape = 'glyph', glyph = 'crack', colour = G.C.WHITE,
    life = 0.6, width = 0.05})), 0.6)
end

--- stamp(cards): a mark in the boss colour bursts onto each card (opts.glyph: x, hex, vine, crack),
--- staggered so a batch reads as one stroke.
function E.stamp(src, target, opts)
  for i, card in ipairs(cards_of(target)) do
    after((i - 1) * 0.05, function()
      if card.REMOVED then return end
      local T = card.T
      local s = math.min(T.w, T.h) * 0.8 * (opts.scale or 1)
      expire(adopt(Mark(T.x + (T.w - s) / 2, T.y + (T.h - s) / 2, s, s, {shape = 'glyph',
        glyph = opts.glyph or 'x', colour = opts.colour, life = 0.9, width = 0.08})), 0.9)
      card:juice_up(0.2, 0.1)
    end)
  end
end

--- sweep(area): a band of particles washes across a card area or HUD element, left to right.
--- Reduced motion: the band covers the whole area at once.
function E.sweep(src, area, opts)
  if not (area and area.T) then return end
  local T = area.T
  local life = 0.6
  local calm = reduced()
  local band = adopt(Particles(T.x, T.y, calm and T.w or 0.6, T.h, {timer = 0.01,
    scale = 0.3 * (opts.scale or 1), speed = 1.2, lifespan = 0.5, colours = {col(opts.colour), G.C.WHITE}, fill = true}))
  if not calm then
    expire(adopt(Mark(T.x - 0.3, T.y, 0, 0, {life = life, path = {T.x - 0.3, T.y, T.x + T.w - 0.3, T.y},
      follower = band})), life)
  end
  expire(band, life + 0.4)
end

--- glare(cards): rings travel from the source onto each card (opts.line: a beam too).
--- Reduced motion: the ring appears on the card without travelling.
function E.glare(src, target, opts)
  local sx, sy = centre(src)
  for i, card in ipairs(cards_of(target)) do
    after((i - 1) * 0.06, function()
      if card.REMOVED then return end
      local cx, cy = centre(card.T)
      if opts.line then
        expire(adopt(Mark(sx, sy, 0, 0, {shape = 'beam', colour = opts.colour, life = 0.45,
          x2 = cx, y2 = cy, width = 0.08})), 0.45)
      end
      if reduced() then
        return expire(adopt(Mark(cx - 0.5, cy - 0.5, 1, 1, {shape = 'ring', colour = opts.colour, life = 0.5})), 0.5)
      end
      expire(adopt(Mark(sx - 0.5, sy - 0.5, 1, 1, {shape = 'ring', colour = opts.colour, life = 0.4,
        path = {sx - 0.5, sy - 0.5, cx - 0.5, cy - 0.5}})), 0.4)
      after(0.4, function()
        if card.REMOVED then return end
        local hx, hy = centre(card.T)
        expire(adopt(Mark(hx - 0.6, hy - 0.6, 1.2, 1.2, {shape = 'ring', colour = opts.colour, life = 0.35})), 0.35)
        card:juice_up(0.3, 0.2)
      end)
    end)
  end
end

--- chain(area): dark bars slide in from both sides and clamp the area's edges for a moment.
function E.chain(src, area, opts)
  if not (area and area.T) then return end
  local T = area.T
  local bw, life = 0.22, 0.9
  local dark = darken(col(opts.colour), 0.5)
  local calm = reduced()
  for _, side in ipairs({{T.x - bw, T.x - bw - 1.5}, {T.x + T.w, T.x + T.w + 1.5}}) do
    local x, from = side[1], side[2]
    expire(adopt(Mark(calm and x or from, T.y - 0.1, bw, T.h + 0.2, {shape = 'bar', colour = dark,
      life = life, travel = 0.2, path = (not calm) and {from, T.y - 0.1, x, T.y - 0.1} or nil})), life)
  end
end

--- ring(): shockwave rings from the source (opts.count, default 2; opts.scale sizes them). With a
--- card target, the rings ripple around each of those cards instead.
function E.ring(src, target, opts)
  local count = opts.count or 2
  local function wave(T, size)
    local cx, cy = centre(T)
    for i = 1, count do
      after((i - 1) * 0.15, function()
        expire(adopt(Mark(cx - size / 2, cy - size / 2, size, size, {shape = 'ring', colour = opts.colour,
          life = 0.6, width = 0.08})), 0.6)
      end)
    end
  end
  local cards = target and cards_of(target) or {}
  if #cards > 0 then
    for _, c in ipairs(cards) do wave(c.T, math.max(c.T.w, c.T.h) * 1.6) end
  else
    wave(src, (src.w + src.h) * (opts.scale or 1))
  end
end

--- spin(cards): a face-down card spins as it lands (a big rotation juice). Reduced motion: a flash.
function E.spin(src, target, opts)
  for _, card in ipairs(cards_of(target)) do
    local T = card.T
    if reduced() then E.flash_at(T.x, T.y, T.w, T.h, opts.colour) else card:juice_up(0.3, 1.2) end
  end
end

--- burst(): a particle spray from the source in the boss colour (opts.scale grows it). One
--- Particles pulse holds at most 20 particles (engine/particles.lua), so big bursts use several.
function E.burst(src, _, opts)
  local s = opts.scale or 1
  for _ = 1, math.max(1, math.ceil(s)) do
    expire(adopt(Particles(src.x, src.y, src.w, src.h, {timer = 0.005, max = 0, pulse_max = 20,
      scale = 0.35 * s, speed = 5 * s, lifespan = 0.9, colours = {col(opts.colour), G.C.WHITE}, fill = true})), 1.0)
  end
end

-- Helpers for deaths, stances and the nemesis -------------------------------------------------------

--- opts.count shapes (opts.shape: heart, leaf, glyph with opts.glyph, ...) fly out of the source;
--- opts.dx / opts.dy push them one way (a gust). Reduced motion: they appear near the source, still.
function E.scatter(src, opts)
  local cx, cy = centre(src)
  local size, life = opts.size or 0.45, opts.life or 1.2
  local calm = reduced()
  for i = 1, opts.count or 10 do
    local ang = math.random() * 2 * math.pi
    local dist = (opts.spread or 2.5) * (0.5 + 0.5 * math.random())
    local tx = cx + math.cos(ang) * dist + (opts.dx or 0)
    local ty = cy + math.sin(ang) * dist + (opts.dy or 0)
    local x0 = calm and (cx + (tx - cx) * 0.3) or cx
    local y0 = calm and (cy + (ty - cy) * 0.3) or cy
    expire(adopt(Mark(x0 - size / 2, y0 - size / 2, size, size, {shape = opts.shape, glyph = opts.glyph,
      colour = (i % 3 == 0) and G.C.WHITE or opts.colour, life = life, width = 0.08,
      path = (not calm) and {cx - size / 2, cy - size / 2, tx - size / 2, ty - size / 2} or nil,
      spin = (not calm) and (math.random() - 0.5) * 8 or nil})), life)
  end
end

--- Aura particles attached to a chip (the avatar or the HUD blind): level 1 faint, 2 strong.
--- Avatar:draw and Blind:draw draw their children, so the owner draws it and removes it with itself.
function E.aura(obj, colour, level)
  if not obj or not FinalBoss.config.fx then return nil end
  local strong = (level or 1) >= 2
  return Particles(0, 0, 0, 0, {attach = obj, fill = true, timer = strong and 0.03 or 0.09,
    scale = strong and 0.3 or 0.2, speed = strong and 1.2 or 0.7, lifespan = 1.0,
    colours = {col(colour), lighten(col(colour), 0.3)}})
end

function E.remove_aura(p)
  if p and not p.REMOVED then p:remove() end
end

--- Run teardown or a guard failure: drop every live effect and cancel pending timers.
function E.reset()
  E.gen = E.gen + 1
  local h = E.host
  E.host = nil
  if not h or h.REMOVED then return end
  for k, v in pairs(h.children) do
    if type(k) == 'table' then
      h.children[k] = nil
      if not v.REMOVED then v:remove() end
    end
  end
  h:remove()
end

return E

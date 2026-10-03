--- Effects library (1.1): visual primitives shared by boss moves, deaths and phase changes:
--- fling, drain, crack, stamp, sweep, glare, chain, ring, spin, burst, plus curse (persistent card
--- marks, src/curse.lua), fist (The Arm), recount (a counter's old -> new value), land (a flash on a
--- card as it reaches its slot) and snake (The Serpent) (logic.EFFECTS).
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
E.reddened = nil -- {cfg, prev}: a HUD text the fist turned red, restored after a moment or by E.reset
E.hidden = {}    -- UI element -> true: counters a recount overlay hides, shown again when it ends or by E.reset

local function reduced() return G.SETTINGS.reduced_motion end
local function now() return FinalBoss.util.now() end
--- A colour list must never hold nil (vanilla Particles:draw does not guard it).
local function col(c) return c or G.C.WHITE end

--- The performing boss's voice pitch (registry entry.voice.pitch, through opts.blind); impact sounds
--- are played times it, like recipe sounds (moves.lua).
local function voice_pitch(opts)
  local b = opts and opts.blind
  local key = b and b.config and b.config.blind and b.config.blind.key
  local e = key and FinalBoss.registry.get(key)
  return (e and e.voice and tonumber(e.voice.pitch)) or 1
end

local function play(s, pitch)
  if type(s) == 'table' and type(s[1]) == 'string' then play_sound(s[1], (s[2] or 1) * (pitch or 1), s[3] or 0.5) end
end

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

--- args: shape ('ring', 'flash', 'coin', 'bar', 'fill', 'beam', 'glyph', 'heart', 'leaf', 'dot',
--- 'none'), colour, alpha (bar), life (s), glyph (logic.GLYPHS key), width (line width, room units),
--- x2/y2 (beam end, room units), path {x0, y0, x1, y1} (top-left travels over `travel` seconds,
--- default life; eased out, or steady with linear = true), wave {amplitude, waves} (the path snakes
--- side to side, back on the line at both ends), follower (an object whose top-left follows this
--- mark: a particle trail), spin (radians per second).
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
  self.linear, self.wave = args.linear, args.wave
  self.t0 = now()
  self:hard_set_VT()
end

function Mark:progress() return math.min(1, (now() - self.t0) / self.life) end

function Mark:move(dt)
  local P = self.path
  if P then
    local p = math.min(1, (now() - self.t0) / self.travel)
    local e = self.linear and p or 1 - (1 - p) * (1 - p) -- steady or ease out
    local x, y = P[1] + (P[3] - P[1]) * e, P[2] + (P[4] - P[2]) * e
    local wv = self.wave
    if wv then
      local dx, dy = P[3] - P[1], P[4] - P[2]
      local len = math.sqrt(dx * dx + dy * dy)
      if len > 0 then
        local o = wv[1] * math.sin(2 * math.pi * wv[2] * e)
        x, y = x - dy / len * o, y + dx / len * o
      end
    end
    self.T.x, self.T.y = x, y
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
    love.graphics.circle('line', w / 2, h / 2, (w / 2) * (0.3 + 0.9 * p), 24)
  elseif s == 'flash' then
    paint(self.colour, 0.75 * a)
    love.graphics.circle('fill', w / 2, h / 2, w * 0.45, 24)
  elseif s == 'coin' then
    paint(G.C.MONEY, math.min(1, 3 * a))
    love.graphics.circle('fill', w / 2, h / 2, w / 2, 24)
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
    love.graphics.circle('fill', w * 0.3, h * 0.35, w * 0.22, 24)
    love.graphics.circle('fill', w * 0.7, h * 0.35, w * 0.22, 24)
    love.graphics.polygon('fill', w * 0.1, h * 0.45, w * 0.9, h * 0.45, w * 0.5, h * 0.95)
  elseif s == 'leaf' then
    paint(self.colour, math.min(1, 3 * a))
    love.graphics.ellipse('fill', w / 2, h / 2, w / 2, h / 4, 16)
  elseif s == 'dot' then
    paint(self.colour, math.min(1, 5 * a))
    love.graphics.circle('fill', w / 2, h / 2, w / 2, 24)
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
--- (Violet Vessel); 'slam': a bar drops onto it first (recipe option for modded bosses; no drop under
--- reduced motion). The Arm now uses fist.
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

--- sweep(area): a band of particles washes across a card area or HUD element, left to right, over
--- opts.time seconds (default 0.6). Reduced motion: the band covers the whole area at once.
function E.sweep(src, area, opts)
  if not (area and area.T) then return end
  local T = area.T
  local life = tonumber(opts.time) or 0.6
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

--- curse(cards): persistent curse marks (src/curse.lua) on the cursed cards in opts.style ('suit',
--- 'vine', 'crack') and opts.colour; each card juices as its mark starts to grow. Marks already made
--- this blind (moves.on_drawn marks every newly cursed card, throttled or not) keep their birth time.
function E.curse(src, target, opts)
  local cards = cards_of(target)
  FinalBoss.curse.mark(cards, opts.style, opts.colour, opts.blind)
  local t = now()
  for _, card in ipairs(cards) do
    local m = card.fb_curse
    after(m and math.max(0, m.born - t) or 0, function()
      if not card.REMOVED then card:juice_up(0.25, 0.1) end
    end)
  end
end

-- The Arm's fist ----------------------------------------------------------------------------------

local FIST_W = 0.8     -- room units; the joker card art is 71 x 95 px
local FIST_DROP = 2.2  -- how far above its landing spot the fist starts to fall
local FIST_APPEAR = 0.12 -- seconds it takes to materialise (dissolve 1 -> 0)

--- The Raised Fist joker's own art as an effect object (adopted by the layer: E.reset removes it, and
--- Node:remove removes its sprite child, engine/node.lua:339-343). The sprite is glued to the fist like
--- a card's sprites are to the card (card.lua:159) and drawn with the dissolve shader, so it
--- materialises and fades the way vanilla cards do. Timeline (REAL seconds): born; t_fall..t_land
--- falls from y_from onto y_rest (accelerating); t_fade: dissolves over logic.FIST_FADE.
local Fist = Moveable:extend()
E.Fist = Fist

function Fist:init(x, y, w, h, sprite)
  Moveable.init(self, x, y, w, h)
  for _, o in ipairs({self, sprite}) do
    o.states.collide.can, o.states.hover.can = false, false
    o.states.click.can, o.states.drag.can = false, false
  end
  sprite:set_role({major = self, role_type = 'Glued', draw_major = self})
  self.children.sprite = sprite
  self.sprite = sprite
  self.y_rest, self.y_from = y, y
  self.born = now()
  self.t_fall, self.t_land, self.t_fade = self.born, self.born, nil
  self.dissolve = 1
  self.dissolve_colours = {G.C.RED, G.C.BLACK}
  self:hard_set_VT()
end

function Fist:move(dt)
  local t = now()
  local y = self.y_rest
  if not self.landed and t < self.t_land then
    local p = (t <= self.t_fall) and 0 or (t - self.t_fall) / (self.t_land - self.t_fall)
    y = self.y_from + (self.y_rest - self.y_from) * p * p
  end
  self.T.y = y
  if self.t_fade then
    self.dissolve = math.max(0, math.min(1, (t - self.t_fade) / FinalBoss.logic.FIST_FADE))
  else
    self.dissolve = math.max(0, 1 - (t - self.born) / FIST_APPEAR)
  end
  self:move_juice(dt) -- the impact squash (Moveable:juice_up is a no-op under reduced motion)
  local j = self.juice
  self.VT.x, self.VT.y, self.VT.w, self.VT.h = self.T.x, self.T.y, self.T.w, self.T.h
  self.VT.scale = 1 + (j and j.scale or 0)
  self.VT.r = j and j.r or 0
end

function Fist:draw()
  local s = self.sprite
  if not s or s.REMOVED then return end
  s:glue_to_major(self) -- this frame's position, whatever order G.MOVEABLES moved them in
  s:draw_shader('dissolve', nil, nil, true)
end

--- A HUD text (UIT.T config) flashes red for a moment; vanilla reads config.colour every frame.
local function redden(cfg)
  if not cfg or cfg.colour == G.C.RED then return end
  local mine = {cfg = cfg, prev = cfg.colour}
  E.reddened = mine
  cfg.colour = G.C.RED
  after(0.45, function()
    if E.reddened == mine then E.reddened = nil end
    if cfg.colour == G.C.RED then cfg.colour = mine.prev end
  end)
end

--- fist(uie): the Raised Fist joker (G.P_CENTERS.j_raised_fist, its own atlas art through
--- SMODS.create_sprite like the avatar) drops onto a HUD element - The Arm: the hand level - and slams
--- onto it as the game lowers the level: a red flash on the hand panel, a ring, a jiggle (not under
--- reduced motion), the level text flashes red, then the fist dissolves away.
--- Sync: vanilla's Arm calls level_up_hand(..., -1) inside debuff_hand (blind.lua:550-557); smods
--- queues the level change as events (logic.level_tick_slots). Two guarded events are inserted into
--- that queue: one where the 0.9 s wait before the level text starts (the fist falls to land 0.9 game
--- seconds later: logic.fist_timing), one right after the level-text event (the impact, in the same
--- frame as the level change). opts.data.queue_from = the first queue index of the Arm's own events
--- (hooks.lua); without it or the pattern, the fist falls and slams at once.
--- opts.impact = {sound, pitch, volume} played at the impact (times the boss voice pitch). Reduced
--- motion: no fall; the fist appears on the panel with the flash and dissolves.
function E.fist(src, uie, opts)
  if not (uie and uie.T) then return end
  local center = G.P_CENTERS and G.P_CENTERS.j_raised_fist
  if not (center and center.pos) then return end
  local LG = FinalBoss.logic
  local T = uie.T
  local w, h = FIST_W, FIST_W * 95 / 71
  local x, y = T.x + T.w / 2 - w / 2, T.y + T.h * 0.6 - h -- its base lands on the level text
  local state = {fist = nil, hit = false}

  local function appear(fall)
    if state.fist then return end
    local sprite = SMODS.create_sprite(x, y, w, h, center.atlas or 'Joker', center.pos)
    local f = adopt(Fist(x, y, w, h, sprite))
    if fall > 0 then
      local t = now()
      f.y_from, f.t_fall, f.t_land = y - FIST_DROP, t, t + fall
      f.T.y = f.y_from
      f:hard_set_VT()
    end
    state.fist = f
  end

  -- sync: called right after vanilla's level-text event (it has just set the level text and colour).
  local function hit(sync)
    if sync then redden(uie.config) end
    if state.hit then return end
    state.hit = true
    appear(0)
    local f = state.fist
    f.landed = true
    f:juice_up(0.5, 0.12)
    if not reduced() then G.ROOM.jiggle = G.ROOM.jiggle + 2 end
    local panel = G.HUD and G.HUD:get_UIE_by_ID('hand_text_area')
    if panel and panel.T then flash_rect(panel.T, G.C.RED) end
    if uie.juice_up then uie:juice_up(0.8, 0.4) end
    local cx, by = x + w / 2, y + h
    expire(adopt(Mark(cx - 0.7, by - 0.7, 1.4, 1.4, {shape = 'ring', colour = G.C.RED, life = 0.4, width = 0.08})), 0.4)
    play(opts.impact, voice_pitch(opts)) -- times the boss voice pitch, like recipe sounds
    f.t_fade = now() + LG.FIST_HOLD
    after(LG.FIST_HOLD + LG.FIST_FADE + 0.05, function() drop(f) end)
  end

  local q = G.E_MANAGER and G.E_MANAGER.queues and G.E_MANAGER.queues.base
  local from = opts.data and opts.data.queue_from
  local fall_at, hit_at
  if q and from then fall_at, hit_at = LG.level_tick_slots(q, from) end
  if not fall_at then
    local _, fall = LG.fist_timing(LG.FIST_FALL, reduced())
    appear(fall)
    return after(fall, function() hit(false) end)
  end
  local gen = E.gen
  local function queued(name, fn)
    -- blockable, not blocking: runs when the queue reaches it and holds nothing up
    return Event({blocking = false, func = function()
      if E.gen == gen then FinalBoss.util.guard(name, fn) end
      return true
    end})
  end
  table.insert(q, hit_at, queued('effect_fist_hit', function() hit(true) end)) -- first: fall_at < hit_at
  table.insert(q, fall_at, queued('effect_fist_fall', function()
    -- The 0.9 s wait starts now on the game clock (G.TIMERS.TOTAL runs at G.SPEEDFACTOR, game.lua).
    local lead = LG.LEVEL_WAIT / math.max(0.05, G.SPEEDFACTOR or 1)
    local wait, fall = LG.fist_timing(lead, reduced())
    if fall > 0 then after(wait, function() appear(fall) end) end
    after(lead + 1.5, function() hit(false) end) -- the queue was cleared or stalled: slam anyway
  end))
end

-- Recount: a counter shown going from its old value to its new one ------------------------------------

--- The overlay hides the real counter (UIElement:draw_self draws nothing, not even its object, while
--- states.visible is false: engine/ui.lua:663-666; vanilla itself hides HUD elements this way,
--- blind.lua:124-125) and draws its own number in the counter's place, font, scale and colour. The real
--- counter is shown again when the overlay ends (E.reset too).
local function hide(uie)
  if uie.states and uie.states.visible then
    uie.states.visible = false
    E.hidden[uie] = true
  end
end

local function reveal(uie)
  if uie and E.hidden[uie] then
    E.hidden[uie] = nil
    if not uie.REMOVED then uie.states.visible = true end
  end
end

--- Vanilla's own popup over the counter (ease_discard / ease_hands_played: attention_text with
--- cover = the counter's row, common_events.lua:128-135 and :167-174; its UIBox's config.major is the
--- cover, functions/UI_definitions.lua:903-907 and engine/ui.lua:31). The count waits until it is gone.
local function covered(uie)
  for _, b in ipairs(G.I and G.I.UIBOX or {}) do
    local m = b.attention_text and b ~= E.host and b.config and b.config.major
    if m and (m == uie or m == uie.parent) then return true end
  end
  return false
end

--- Whether uie's UIBox was drawn in the last frame (UIBox:draw stamps FRAME.DRAW first thing,
--- engine/ui.lua:283-285; Game:draw bumps G.FRAMES.DRAW, game.lua:2733). The hand's label is drawn only
--- while the hand is (CardArea:draw, cardarea.lua:270-313).
local function box_drawn(uie, slack)
  local box = uie.UIBox
  return (box and box.FRAME and box.FRAME.DRAW and box.FRAME.DRAW >= G.FRAMES.DRAW - (slack or 0)) and true or false
end

--- Font, scale and colour of the counter: a DynaText object (hands, discards: UI_definitions.lua:1290,
--- :1300) or a text node (the target, UI_definitions.lua:1240; the hand label, cardarea.lua:283-287).
local function text_style(uie)
  local o = uie.config.object
  if o and o.font and o.scale then return o.font, o.scale, (o.colours and o.colours[1]) or G.C.WHITE end
  local c = uie.config
  return (c.lang and c.lang.font) or G.LANG.font, c.scale or 0.4, c.colour or G.C.WHITE
end

local Recount = Moveable:extend()
E.Recount = Recount

--- args: from, to, hold, time, chips (format as a score: number_format), on_count (the cue), impact
--- (sound at the landing), pitch, locate (finds the counter), blind. Timeline: it waits (old value
--- shown) until the counter is drawn, on screen, still and not covered by vanilla's popup (at most
--- logic.RECOUNT_WAIT_MAX); then holds `hold` seconds, counts over `time` (cue at the start, impact at
--- the end) and keeps the new value logic.RECOUNT_LINGER seconds before the real counter shows again.
function Recount:init(args)
  Moveable.init(self, 0, 0, 0, 0)
  self.states.collide.can, self.states.hover.can = false, false
  self.states.click.can, self.states.drag.can = false, false
  self.args = args
  self.born = now()
  self.value = args.from
  self:set_text()
  self:hard_set_VT()
end

function Recount:set_text()
  local v = self.value or 0
  if self.args.chips and type(number_format) == 'function' then self.text = number_format(math.floor(v))
  else self.text = tostring(math.floor(v + 0.5)) end
end

--- Stop at the next event (never inside the MOVEABLE loop): show the counter, drop the overlay.
function Recount:finish()
  if self.finished then return end
  self.finished = true
  local uie = self.uie
  after(0, function()
    reveal(uie)
    drop(self)
  end)
end

--- An error in move/draw (run outside util.guard by the engine) goes through the guard in an event:
--- FinalBoss stops for the run and E.reset shows the counter again.
function Recount:fail(err)
  if self.failed then return end
  self.failed, self.finished = true, true
  G.E_MANAGER:add_event(Event({blocking = false, blockable = false, func = function()
    FinalBoss.util.guard('effect_recount', error, err, 0)
    return true
  end}))
end

function Recount:tick(dt)
  local a, LG, t = self.args, FinalBoss.logic, now()
  local cur = G.GAME and G.GAME.blind
  if a.blind and (cur ~= a.blind or a.blind.disabled) then return self:finish() end
  local uie = self.uie
  if not uie or uie.REMOVED then
    if uie then E.hidden[uie] = nil end
    uie = a.locate and a.locate() or nil
    self.uie = uie
    if uie then hide(uie) end
  end
  local waited = t - self.born
  if not uie then
    if waited > LG.RECOUNT_WAIT_MAX then
      -- the counter never showed up: the cue still plays, nothing is counted
      if a.on_count and not self.cued then self.cued = true; after(0, a.on_count) end
      self:finish()
    end
    return
  end
  local vt = uie.VT
  local moving = self.last_y ~= nil and math.abs(vt.y - self.last_y) > 0.002
  self.last_y = vt.y
  self.T.x, self.T.y, self.T.w, self.T.h = vt.x, vt.y, vt.w, vt.h
  self:move_juice(dt) -- Moveable:juice_up is a no-op under reduced motion
  local j = self.juice
  self.VT.x, self.VT.y, self.VT.w, self.VT.h = vt.x, vt.y, vt.w, vt.h
  self.VT.scale = 1 + (j and j.scale or 0)
  self.VT.r = j and j.r or 0
  local room = G.ROOM and G.ROOM.T
  local onscreen = vt.y + vt.h > 0 and (not room or vt.y < room.h)
  local ready = box_drawn(uie, 1) and onscreen and not moving and not covered(uie)
  local late = waited > LG.RECOUNT_WAIT_MAX
  if not self.t0 then
    if ready or late then self.t0 = t end
  elseif not self.cued and not ready and not late then
    self.t0 = nil -- covered or moving again while it holds: wait, then hold again
  end
  if not self.t0 then return end
  local el = t - self.t0
  local v = LG.recount_value(a.from, a.to, el, a.hold, a.time, reduced())
  if v ~= self.value then
    self.value = v
    self:set_text()
  end
  if not self.cued and el >= a.hold then
    self.cued = true
    self:juice_up(0.4, 0.2)
    if a.on_count then after(0, a.on_count) end
  end
  if not self.landed and el >= a.hold + a.time then
    self.landed = true
    self:juice_up(0.6, 0.3)
    if a.impact then after(0, function() play(a.impact, a.pitch) end) end
  end
  if self.landed and el >= a.hold + a.time + LG.RECOUNT_LINGER then self:finish() end
end

function Recount:move(dt)
  if self.finished then return end
  local ok, err = pcall(self.tick, self, dt)
  if not ok then self:fail(err) end
end

local function draw_number(self)
  local font, scale, colour = text_style(self.uie)
  if self.args.chips and type(scale_number) == 'function' then
    scale = scale_number(self.value, 0.7, 100000) -- as G.FUNCS.blind_chip_UI_scale (smods overrides.lua:2916-2924)
  end
  local f = font.FONT
  local k = scale * font.FONTSCALE / G.TILESIZE -- text node scale (engine/ui.lua UIElement:draw_self)
  local sx, sy = k * (font.squish or 1), k
  local w, h = f:getWidth(self.text) * sx, f:getHeight() * sy
  local off = font.TEXT_OFFSET or {x = 0, y = 0}
  local x = (self.VT.w - w) / 2 + off.x * k
  local y = (self.VT.h - h) / 2 + off.y * k
  if G.SETTINGS.GRAPHICS.shadows == 'On' then
    love.graphics.setColor(0, 0, 0, 0.3 * (colour[4] or 1))
    love.graphics.print(self.text, f, x - 0.015, y + 0.02, 0, sx, sy)
  end
  love.graphics.setColor(colour)
  love.graphics.print(self.text, f, x, y, 0, sx, sy)
end

function Recount:draw()
  local uie = self.uie
  if self.finished or not uie or uie.REMOVED or not box_drawn(uie, 0) then return end
  prep_draw(self, 1)
  local ok, err = pcall(draw_number, self)
  love.graphics.pop() -- always balance prep_draw's push
  love.graphics.setColor(1, 1, 1, 1)
  if not ok then self:fail(err) end
end

--- recount(uie): opts.value ('hands', 'discards', 'hand_size', 'target') read from opts.data.before
--- (just before the blind applied) and opts.data.after (moves.on_set_blind). The real counter is
--- hidden at once (vanilla has not shown the new value yet: its ease is a queued event) and an overlay
--- counts from the old value to the new one (Recount above); opts.on_count (moves: the performer's
--- react and the cue steps) runs as the count starts, opts.impact sounds as it lands. opts.locate finds
--- a counter that does not exist yet (the hand label). Nothing to show (unknown or equal values): the
--- cue plays at once. Reduced motion: no counting, the old value then the new one.
function E.recount(src, uie, opts)
  local d = opts.data or {}
  local from = d.before and d.before[opts.value]
  local to = d.after and d.after[opts.value]
  if from == nil or to == nil or from == to then
    if opts.on_count then opts.on_count() end
    return
  end
  local r = adopt(Recount({from = from, to = to, hold = tonumber(opts.hold) or 0.2, time = tonumber(opts.time) or 0.8,
    chips = opts.value == 'target', on_count = opts.on_count, impact = opts.impact, pitch = voice_pitch(opts),
    locate = opts.locate or function() return uie end, blind = opts.blind}))
  if uie and uie.states then
    r.uie = uie
    hide(uie)
  end
end

-- Land and snake (draw-timed moves) -----------------------------------------------------------------

local LAND_MAX = 0.8 -- seconds a card may take to reach its slot before it flashes anyway

--- land(cards): each card flashes (in the step colour) and juices when it reaches its slot in the hand.
--- Called as the card is dealt (moves.collect_flipped, before CardArea:emplace sets its slot,
--- common_events.lua:402-408), so it waits until the card is in G.hand and its drawn position has
--- caught up with its slot. Reduced motion: the flash only (juice_up is a no-op).
function E.land(src, target, opts)
  local gen = E.gen
  for _, card in ipairs(cards_of(target)) do
    local t0 = now()
    G.E_MANAGER:add_event(Event({blocking = false, blockable = false, timer = 'REAL', func = function()
      if E.gen ~= gen or card.REMOVED then return true end
      local T, VT, age = card.T, card.VT, now() - t0
      local there = age > 0.05 and card.area == G.hand and math.abs(VT.x - T.x) + math.abs(VT.y - T.y) < 0.15
      if not there and age < LAND_MAX then return false end
      FinalBoss.util.guard('effect_land', function()
        flash_rect(card.T, opts.colour)
        card:juice_up(0.25, 0.2)
      end)
      return true
    end}))
  end
end

--- snake(area): a snake (a head with a particle trail and a tapering body of dots) crawls from the deck
--- to the area (The Serpent: the hand) over opts.data.time seconds (moves.on_draw_start: until the last
--- card of the draw is in the hand), weaving side to side; a ring where it arrives. Reduced motion: a
--- flash on the area as the cards arrive instead.
function E.snake(src, area, opts)
  if not (area and area.T) then return end
  local time = math.max(0.3, tonumber(opts.data and opts.data.time) or 0.8)
  local H, deck = area.T, G.deck and G.deck.T
  if reduced() or not deck then
    return after(math.max(0, time - 0.2), function() flash_rect(H, opts.colour) end)
  end
  local x0, y0 = deck.x + deck.w / 2, deck.y + deck.h / 2
  local x1, y1 = H.x + H.w / 2, H.y + H.h / 2
  local c, dark = col(opts.colour), darken(col(opts.colour), 0.35)
  local segs, lag = 7, 0.045
  for i = 0, segs - 1 do
    after(i * lag, function()
      local s = 0.34 - i * 0.03
      local life = time + 0.15
      local m = adopt(Mark(x0 - s / 2, y0 - s / 2, s, s, {shape = 'dot', colour = (i % 2 == 0) and c or dark,
        life = life, travel = time, linear = true, wave = {0.35, 2},
        path = {x0 - s / 2, y0 - s / 2, x1 - s / 2, y1 - s / 2}}))
      if i == 0 then
        local trail = adopt(Particles(x0, y0, 0.2, 0.2, {timer = 0.02, scale = 0.2, speed = 0.4,
          lifespan = 0.4, colours = {c, G.C.WHITE}, fill = true}))
        m.follower = trail
        expire(trail, life + 0.3)
      end
      expire(m, life)
    end)
  end
  after(time, function()
    expire(adopt(Mark(x1 - 0.8, y1 - 0.8, 1.6, 1.6, {shape = 'ring', colour = c, life = 0.45, width = 0.08})), 0.45)
  end)
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
  local r = E.reddened
  E.reddened = nil
  if r and r.cfg.colour == G.C.RED then r.cfg.colour = r.prev end
  local hidden = E.hidden
  E.hidden = {}
  for uie in pairs(hidden) do
    if not uie.REMOVED and uie.states then uie.states.visible = true end
  end
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

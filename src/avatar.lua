--- Showdown boss avatar: a free-roaming copy of the boss chip that talks,
--- flinches, laughs and wears its wounds. Visual only: rebuilt on Continue, never saved.
local V = {}
V.SIZE = 2.1
V.ROAM_MIN, V.ROAM_MAX = 6, 9
V.KNOCKBACK = 0.5
V.PERCH_COUNT = 4
V.HUD_EASE = 0.3
V.DISSOLVE = {[0] = 0, [1] = 0.12, [2] = 0.25}
V.obj = nil
V.hud_blind = nil -- the blind whose HUD chip is dissolved while the avatar is out
V.perch = 2
V.next_roam = 0
V.talking = false
V.fading = false
V.tremble = false
V.wound = 0

local function now() return FinalBoss.util.now() end
local function reduced() return G.SETTINGS.reduced_motion end

local function after(delay, fn)
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = delay, timer = 'REAL', blocking = false,
    blockable = false, func = function() FinalBoss.util.guard('avatar_timer', fn); return true end}))
end

--- Ease a table field (REAL timer, non-blocking), or set it at once.
local function ease_field(ref, field, to, duration)
  if not duration or duration <= 0 then ref[field] = to; return end
  if ref[field] == nil then ref[field] = 0 end -- vanilla never initialises Blind.dissolve; ease reads it
  G.E_MANAGER:add_event(Event({trigger = 'ease', ref_table = ref, ref_value = field, ease_to = to,
    delay = duration, timer = 'REAL', blocking = false, blockable = false, func = function(t) return t end}))
end

local Avatar = Moveable:extend()

function Avatar:init(X, Y, W, H, sprite, colour)
  Moveable.init(self, X, Y, W, H)
  self.children = {}
  self.states.collide.can = true
  self.states.click.can = true
  self.states.hover.can = true -- the controller only presses the hovered object, so click needs hover
  self.states.drag.can = false
  self.dissolve = 0
  self.dissolve_colours = {G.C.BLACK, colour}
  self.flash_until = 0
  self.children.sprite = sprite
  self.children.sprite.states.collide.can = false
  self.children.sprite.states.hover.can = false
  self.children.sprite.states.drag.can = false
  table.insert(G.I.MOVEABLE, self) -- Moveable.init only registers plain Moveables
end

function Avatar:move(dt)
  Moveable.move(self, dt)
  local s = self.children.sprite
  if not s then return end
  local t = G.TIMERS.REAL
  local calm = reduced()
  local speed = V.wound >= 1 and 1.5 or 1
  local shaking = (V.tremble or V.wound >= 2) and not calm
  local jx = shaking and (math.random() - 0.5) * 0.06 or 0
  local jy = shaking and (math.random() - 0.5) * 0.06 or 0
  s.T.x = self.T.x + jx
  s.T.y = self.T.y + (calm and 0 or 0.08 * math.sin(t * speed * 2 * math.pi / 2.2)) + jy
  s.T.r = calm and 0 or 0.05 * math.sin(t * speed * 1.3)
  s.T.w, s.T.h = self.T.w, self.T.h
end

function Avatar:juice_up(amount, rot_amt)
  if self.children.sprite then self.children.sprite:juice_up(amount, rot_amt) end
end

function Avatar:draw()
  if not self.states.visible then return end
  local s = self.children.sprite
  s.role.draw_major = self -- the dissolve shader reads self.dissolve / dissolve_colours
  s:draw_shader('dissolve', 0.1)
  s:draw_shader('dissolve')
  if now() < self.flash_until then
    prep_draw(s, 1)
    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.circle('fill', s.VT.w / 2, s.VT.h / 2, s.VT.w * 0.42)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
  end
  for k, v in pairs(self.children) do
    if k ~= 'sprite' then v:draw() end -- speech bubble etc.
  end
  add_to_drawhash(self)
end

function Avatar:click()
  FinalBoss.util.guard('avatar_click', function()
    if FinalBoss.cinematic.active() then FinalBoss.cinematic.skip()
    elseif FinalBoss.dialogue.intro_active() then FinalBoss.dialogue.skip() end
  end)
end

function Avatar:remove()
  for _, v in pairs(self.children) do v:remove() end
  self.children = {}
  Moveable.remove(self)
end

--- Perch positions (top-left of the avatar) from the live table layout; fixed fallback.
local function perch_xy(i)
  local S = V.SIZE
  local p
  if i == 1 and G.consumeables then
    local a = G.consumeables.T
    p = {x = a.x + a.w / 2 - S / 2, y = a.y + a.h + 0.3}
  elseif i == 2 and G.play then
    local a = G.play.T
    p = {x = a.x + a.w + 0.6, y = a.y + a.h / 2 - S / 2}
  elseif i == 3 and G.deck then
    local a = G.deck.T
    p = {x = a.x + a.w - S * 0.6, y = a.y - S - 0.2}
  elseif i == 4 and G.play then
    local a = G.play.T
    p = {x = a.x + a.w / 2 - S / 2, y = a.y - S * 0.5}
  end
  if not p then p = {x = G.ROOM.T.w * 0.72, y = G.ROOM.T.h * 0.35} end
  return math.max(0, math.min(p.x, G.ROOM.T.w - V.SIZE)), p.y
end

local function go_to(i, instant)
  local o = V.obj
  if not o then return end
  V.perch = i
  o.T.x, o.T.y = perch_xy(i)
  if instant then o:hard_set_VT() end
end

function V.spawn(blind, opts)
  opts = opts or {}
  V.hud_blind = nil -- a respawn keeps the chip dissolved: no restore ease to fight the new one
  V.remove()
  local proto = blind and blind.config and blind.config.blind
  if not proto then return end
  local c = proto.boss_colour or G.C.RED
  local x, y = perch_xy(2)
  local start_y = opts.fall and (y - G.ROOM.T.h - V.SIZE) or y
  local sprite_pos = copy_table(proto.pos or {x = 0, y = 0})
  local sprite
  if SMODS and SMODS.create_sprite then -- exact art, frames and sprite class for modded bosses
    sprite = SMODS.create_sprite(x, start_y, V.SIZE, V.SIZE, proto.atlas or 'blind_chips', sprite_pos, proto.sprite_args)
  else
    sprite = AnimatedSprite(x, start_y, V.SIZE, V.SIZE,
      (proto.atlas and G.ANIMATION_ATLAS[proto.atlas]) or G.ANIMATION_ATLAS['blind_chips'], sprite_pos)
  end
  V.obj = Avatar(x, start_y, V.SIZE, V.SIZE, sprite, {c[1], c[2], c[3], 1})
  V.obj:hard_set_VT()
  -- The boss "steps out": dissolve its HUD chip while the avatar is on the table. The blind's own
  -- dissolve field is what Blind:draw reads; states.visible is re-shown every frame by the HUD.
  V.hud_blind = blind
  blind.dissolve_colours = {G.C.BLACK, c}
  ease_field(blind, 'dissolve', 1, not reduced() and V.HUD_EASE or 0)
  go_to(2, not opts.fall)
  V.next_roam = now() + math.random(V.ROAM_MIN, V.ROAM_MAX)
end

function V.exists() return V.obj ~= nil end
function V.anchor() return V.obj end

function V.side()
  if not V.obj then return 'right' end
  return (V.obj.T.x + V.obj.T.w / 2 > G.ROOM.T.w / 2) and 'right' or 'left'
end

function V.position()
  if not V.obj then return nil end
  local T = V.obj.T
  return T.x, T.y, T.w, T.h
end

function V.tick(dt)
  if not V.obj or V.talking or V.fading or reduced() then return end
  if now() >= V.next_roam then
    go_to(FinalBoss.logic.pick_variant(V.PERCH_COUNT, V.perch, math.random), false)
    V.next_roam = now() + math.random(V.ROAM_MIN, V.ROAM_MAX)
  end
end

function V.hit(size)
  local o = V.obj
  if not o then return end
  o.flash_until = now() + 0.15
  o:juice_up(size == 'big' and 0.6 or 0.4, 0.15)
  if reduced() then return end
  local dir = V.side() == 'right' and 1 or -1
  o.T.x = o.T.x + dir * V.KNOCKBACK * (size == 'big' and 1.6 or 1)
  local perch = V.perch
  after(0.3, function() if V.obj == o and V.perch == perch then go_to(perch, false) end end)
end

function V.laugh(pitch)
  local o = V.obj
  if not o then return end
  for i = 0, 2 do
    after(i * 0.14, function()
      if V.obj ~= o then return end
      play_sound('voice' .. math.random(1, 11), (pitch or 1) * 1.15, 0.5)
      o:juice_up(0.2, (i % 2 == 0) and 0.3 or -0.3)
    end)
  end
end

function V.set_wound(stage)
  V.wound = stage or 0
  if V.obj then V.obj.dissolve = V.DISSOLVE[V.wound] or 0 end
end

function V.set_talking(on)
  V.talking = on and true or false
  if not on then V.next_roam = math.max(V.next_roam, now() + 1.5) end
end

function V.talk_bump()
  if V.obj then V.obj:juice_up(0.15, 0.1) end
end

function V.set_tremble(on) V.tremble = on and true or false end

function V.flash(duration)
  if V.obj then V.obj.flash_until = now() + (duration or 0.15) end
end

function V.set_dissolve(amount, duration)
  local o = V.obj
  if not o then return end
  ease_field(o, 'dissolve', amount, duration)
end

function V.fade_out(duration)
  local o = V.obj
  if not o then return end
  V.fading = true -- no more roaming while it fades
  V.set_dissolve(1, duration)
  after(duration + 0.05, function() if V.obj == o then V.remove() end end)
end

--- Land instantly (cinematic skip mid-fall): no glide, no overshoot.
function V.snap()
  local o = V.obj
  if not o then return end
  o.velocity.x, o.velocity.y = 0, 0
  o:hard_set_VT()
  local s = o.children.sprite
  if s then
    s.T.x, s.T.y = o.T.x, o.T.y
    s.velocity.x, s.velocity.y = 0, 0
    s:hard_set_VT()
  end
end

--- Bring the HUD chip back (not when the encounter ended: vanilla's defeat dissolve or the
--- game-over screen owns the chip then). Never errors: it runs from teardown.
local function restore_hud_blind()
  local b = V.hud_blind
  V.hud_blind = nil
  if not b or not G.GAME or b ~= G.GAME.blind then return end
  if not (b.config and b.config.blind and b.config.blind.key) then return end
  local enc = G.GAME.FinalBoss and G.GAME.FinalBoss.encounter
  if not enc or enc.ended or enc.finale then return end -- finale: Blind:defeat owns the chip
  ease_field(b, 'dissolve', 0, not reduced() and V.HUD_EASE or 0)
end

function V.remove()
  local o = V.obj
  V.obj = nil
  restore_hud_blind()
  V.talking, V.fading, V.tremble, V.wound = false, false, false, 0
  if o then o:remove() end
end

return V

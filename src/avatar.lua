--- Showdown boss avatar: a free-roaming copy of the boss chip that talks,
--- flinches, laughs and wears its wounds. Visual only: rebuilt on Continue, never saved.
local V = {}
V.SIZE = 2.1
V.ROAM_MIN, V.ROAM_MAX = 6, 9
V.KNOCKBACK = 0.5
V.PERCH_COUNT = 4
-- Home perch: spawn, landing, scoring, and the only spot under reduced motion.
V.RINGSIDE = FinalBoss.logic.PERCH_RINGSIDE
V.HP_BOX_H = 1.05 -- estimated HP box height incl. its 0.05 gap, until the real box exists
V.HUD_EASE = 0.3
V.LAUGH_DURATION = FinalBoss.logic.laugh_duration() -- the director schedules the line after it
V.LAUGH_VOLUME = 0.75   -- louder than talking (0.5)
V.LAUGH_ACCENT = {sound = 'multhit1', pitch = 0.6, volume = 0.3} -- one low thud as the laugh starts
V.ROOM_MARGIN = 0.5 -- the window always shows at least this much of the room padding per side
V.DISSOLVE = {[0] = 0, [1] = 0.12, [2] = 0.25}
V.GLOAT_GAP = 0.3       -- game over: space kept between the chip and the panel / window edge
V.GLOAT_MIN = 1.4       -- game over: the chip shrinks to fit the free margin, never below this
V.GLOAT_FALLBACK_DX = 5.5 -- no panel found: this far right of the room's centre
V.GLOAT_LAUGH_DELAY = 1.0 -- laugh this long after Jimbo starts talking (not over his babble)
V.GLOAT_LAUGH_LATE = 3.5  -- laugh anyway this long after the game over if Jimbo never speaks
V.GLOAT_LEAVE = 0.25    -- dissolve time when the game-over screen goes
V.ANGER_TIME = 0.4      -- interrupted: sharp shake length
V.ANGER_SHAKE = 0.14    -- interrupted: shake amplitude at its start
V.RED = {1, 0.15, 0.1, 0.8}
V.obj = nil
V.hud_blind = nil -- the blind whose HUD chip is dissolved while the avatar is out
V.perch = V.RINGSIDE
V.next_roam = 0
V.scoring = false -- parked at ringside while a played hand resolves
V.talking = false
V.fading = false
V.tremble = false
V.wound = 0
V.laugh_id = 0 -- bumped per laugh: a newer laugh silences the older one's remaining beats
V.laugh_start, V.laugh_until = 0, 0 -- REAL-time window the update reads for hops, tilt and shake
V.anger_until = 0 -- REAL-time end of the interrupted shake
V.gloating = nil  -- game over: {pitch, laughed, t0}; the chip sits beside the panel and laughs once
V.stance = 1      -- 1.1 phase stance (logic.stance): roam speed and aura
V.auras = {}      -- slot ('stance' | 'nemesis') -> Particles attached to the chip
V.roar_start, V.roar_until = 0, 0 -- REAL-time window of the phase roar

local function now() return FinalBoss.util.now() end
local function reduced() return G.SETTINGS.reduced_motion end

--- Flash the chip for `duration` seconds (white unless a colour is given).
local function flash(o, duration, colour)
  o.flash_until = now() + duration
  o.flash_colour = colour
end

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
  self.states.hover.can = true -- G.CONTROLLER only clicks the hovered object, so click needs hover
  self.states.drag.can = false
  self.dissolve = 0
  self.dissolve_colours = {G.C.BLACK, colour}
  self.flash_until = 0
  self.flash_colour = nil -- nil = white
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
  local gloat = V.gloating ~= nil
  local shaking = (V.tremble or V.wound >= 2 or V.stance >= 3) and not calm and not gloat
  local jx = shaking and (math.random() - 0.5) * 0.06 or 0
  local jy = shaking and (math.random() - 0.5) * 0.06 or 0
  -- Interrupted: a sharp, quickly decaying shake (sprite only, like the laugh).
  local anger = (not calm and now() < V.anger_until) and V.ANGER_SHAKE * (V.anger_until - now()) / V.ANGER_TIME or 0
  if anger > 0 then
    jx = jx + (math.random() - 0.5) * 2 * anger
    jy = jy + (math.random() - 0.5) * 2 * anger
  end
  s.T.x = self.T.x + jx
  if gloat then -- game over: a slow, smug bob with a slight lean
    s.T.y = self.T.y + (calm and 0 or 0.06 * math.sin(t * 2 * math.pi / 3.4))
    s.T.r = calm and 0 or (0.07 + 0.035 * math.sin(t * 2 * math.pi / 4.6))
  else
    s.T.y = self.T.y + (calm and 0 or 0.08 * math.sin(t * speed * 2 * math.pi / 2.2)) + jy
    s.T.r = calm and 0 or 0.05 * math.sin(t * speed * 1.3)
  end
  s.T.w, s.T.h = self.T.w, self.T.h
  if anger > 0 then s.VT.x, s.VT.y = s.T.x, s.T.y end -- the sprite's spring would smooth the shake away
  -- Laughing: hop, tilt and shake on the sprite only (the avatar's T is the perch, so roaming
  -- never fights it), written straight to VT since the sprite's spring would smooth a 0.1 s hop
  -- away. Offsets are zero outside the window, so the chip ends exactly on its bob.
  if not calm and now() < V.laugh_until then
    local hop, tilt, shake = FinalBoss.logic.laugh_motion(now() - V.laugh_start)
    s.T.x = s.T.x + (shake > 0 and (math.random() - 0.5) * 2 * shake or 0)
    s.T.y = s.T.y - hop + (shake > 0 and (math.random() - 0.5) * 2 * shake or 0)
    s.T.r = s.T.r + tilt
    s.VT.x, s.VT.y, s.VT.r = s.T.x, s.T.y, s.T.r
  end
  -- Phase roar (1.1): the chip swells and shakes for a moment (never under reduced motion).
  if not calm and now() < V.roar_until then
    local R = FinalBoss.logic.ROAR
    local k = FinalBoss.logic.roar_scale(now() - V.roar_start, V.roar_until - V.roar_start)
    s.T.w, s.T.h = self.T.w * k, self.T.h * k
    s.T.x = s.T.x - (s.T.w - self.T.w) / 2 + (math.random() - 0.5) * 2 * R.shake
    s.T.y = s.T.y - (s.T.h - self.T.h) / 2 + (math.random() - 0.5) * 2 * R.shake
    s.VT.x, s.VT.y, s.VT.w, s.VT.h = s.T.x, s.T.y, s.T.w, s.T.h
  end
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
    local c = self.flash_colour
    if c then love.graphics.setColor(c[1], c[2], c[3], c[4] or 0.75)
    else love.graphics.setColor(1, 1, 1, 0.75) end
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

local function area(a)
  return a and a.T and {x = a.T.x, y = a.T.y, w = a.T.w, h = a.T.h} or nil
end

--- The HP box hanging under the avatar: measured once it exists, estimated before.
local function hp_box()
  local H = FinalBoss.hpbar
  local ui = H and H.ui
  if ui and ui.T and ui.T.h and ui.T.h > 0 then return ui.T.w, ui.T.h + 0.05 end -- 0.05 = its y offset
  return ((H and H.W) or 3) + 0.1, V.HP_BOX_H
end

--- Perch positions (top-left of the avatar) from the live table layout, chosen so the chip and
--- its HP box stay clear of cards (logic.perch_rect); fixed fallback.
local function perch_xy(i)
  local S = V.SIZE
  local bw, bh = hp_box()
  local r = FinalBoss.logic.perch_rect(i, {play = area(G.play), jokers = area(G.jokers),
    consumeables = area(G.consumeables), deck = area(G.deck), hand = area(G.hand),
    room = {x = -V.ROOM_MARGIN, y = 0, w = G.ROOM.T.w + 2 * V.ROOM_MARGIN, h = G.ROOM.T.h}}, S, bh, bw)
  if r then return r.x + (r.w - S) / 2, r.y end
  return math.max(0, math.min(G.ROOM.T.w * 0.72, G.ROOM.T.w - S)), G.ROOM.T.h * 0.35
end

local function go_to(i, instant)
  local o = V.obj
  if not o or V.gloating then return end -- game over: the chip belongs beside the panel
  V.perch = i
  o.T.x, o.T.y = perch_xy(i)
  if instant then o:hard_set_VT() end
  -- The avatar bubble follows the avatar (Weak bond): keep it on the inner side after a move.
  if FinalBoss.dialogue and FinalBoss.dialogue.follow_avatar then FinalBoss.dialogue.follow_avatar() end
end

function V.spawn(blind, opts)
  opts = opts or {}
  V.hud_blind = nil -- a respawn keeps the chip dissolved: no restore ease to fight the new one
  V.remove()
  local proto = blind and blind.config and blind.config.blind
  if not proto then return end
  local c = proto.boss_colour or G.C.RED
  local x, y = perch_xy(V.RINGSIDE)
  local start_y = opts.fall and (y - G.ROOM.T.h - V.SIZE) or y
  local sprite_pos = copy_table(proto.pos or {x = 0, y = 0})
  -- SMODS.create_sprite: exact art, frames and sprite class, also for modded bosses.
  local sprite = SMODS.create_sprite(x, start_y, V.SIZE, V.SIZE, proto.atlas or 'blind_chips', sprite_pos,
    proto.sprite_args)
  V.obj = Avatar(x, start_y, V.SIZE, V.SIZE, sprite, {c[1], c[2], c[3], 1})
  V.obj:hard_set_VT()
  -- The boss "steps out": dissolve its HUD chip while the avatar is on the table. The blind's own
  -- dissolve field is what Blind:draw reads; states.visible is re-shown every frame by the HUD.
  V.hud_blind = blind
  blind.dissolve_colours = {G.C.BLACK, c}
  ease_field(blind, 'dissolve', 1, not reduced() and V.HUD_EASE or 0)
  go_to(V.RINGSIDE, not opts.fall)
  V.next_roam = now() + V.roam_delay()
end

function V.exists() return V.obj ~= nil end
function V.anchor() return V.obj end

--- Seconds until the next glide: 6-9 s, shorter in phase II and III (logic.stance).
function V.roam_delay()
  return math.random(V.ROAM_MIN, V.ROAM_MAX) * FinalBoss.logic.stance(V.stance).roam
end

function V.side()
  if not V.obj then return 'right' end
  return (V.obj.T.x + V.obj.T.w / 2 > G.ROOM.T.w / 2) and 'right' or 'left'
end

function V.position()
  if not V.obj then return nil end
  local T = V.obj.T
  return T.x, T.y, T.w, T.h
end

--- Whether an overlay is vanilla's game-over screen (create_UIBox_game_over has 'jimbo_spot').
local function is_game_over_menu(m)
  return type(m) == 'table' and m.UIRoot and m.get_UIE_by_ID and m:get_UIE_by_ID('jimbo_spot') and true or false
end

--- The game-over panel's T. The overlay's ROOT is the full-screen dim; ROOT's first child is a row
--- {Jimbo's column ('jimbo_spot'), a column (padding 0.1) holding the panel} (UI_definitions.lua
--- create_UIBox_game_over, t.nodes[1]), so the panel is the last column's first child.
local function game_over_panel(m)
  local row = m and m.UIRoot and m.UIRoot.children and m.UIRoot.children[1]
  local col = row and row.children and row.children[#row.children]
  local panel = col and col.children and col.children[1] or col
  local T = panel and panel.T
  if T and T.w and T.w > 0 and T.h and T.h > 0 then return T end
  return nil
end

--- Game over: top-left and size of the gloating chip (logic.gloat_rect beside the live panel);
--- fixed spot right of centre when the panel is not found.
local function gloat_spot(m)
  local T = game_over_panel(m)
  if T then
    return FinalBoss.logic.gloat_rect({x = T.x, y = T.y, w = T.w, h = T.h}, G.ROOM.T.w + V.ROOM_MARGIN,
      V.SIZE, V.GLOAT_MIN, V.GLOAT_GAP)
  end
  local S = V.SIZE
  return math.min(G.ROOM.T.w / 2 + V.GLOAT_FALLBACK_DX, G.ROOM.T.w + V.ROOM_MARGIN - S), G.ROOM.T.h / 2 - S / 2, S
end

--- Jimbo has said his quip (vanilla puts a Card_Character with a speech bubble in 'jimbo_spot').
local function jimbo_speaking(m)
  local spot = m and m:get_UIE_by_ID('jimbo_spot')
  local j = spot and spot.config and spot.config.object
  return (j and j.children and j.children.speech_bubble) and true or false
end

local function place_gloat(o, x, y, size)
  if o.T.x == x and o.T.y == y and o.T.w == size then return end
  o.T.x, o.T.y, o.T.w, o.T.h = x, y, size, size -- Avatar:move sizes the sprite from T
  if reduced() then V.snap() end -- no glide under reduced motion
end

--- The boss won: it glides beside the game-over panel, above the overlay's dim, laughs once just
--- after Jimbo delivers its catchphrase, then idles smugly until the game-over screen goes (it then
--- dissolves away) or the run is torn down (V.remove).
--- The game-over screen pauses the game (G.SETTINGS.paused): moveables made before the pause stop
--- moving, so the chip and its sprite are marked pause-proof. Vanilla draws G.I.POPUP after
--- G.OVERLAY_MENU, so moving the chip from G.I.MOVEABLE to G.I.POPUP puts it above the dim
--- (Node:remove drops it from G.I.POPUP again).
function V.gloat(pitch)
  local o = V.obj
  if not o or V.gloating then return end
  -- menu: the game-over overlay this gloat belongs to; when another overlay replaces it (New Run
  -- opens the run setup), the chip leaves.
  V.gloating = {pitch = pitch, laughed = false, t0 = now(), laugh_at = nil, leaving = false,
    menu = is_game_over_menu(G.OVERLAY_MENU) and G.OVERLAY_MENU or nil}
  V.talking, V.tremble, V.scoring, V.fading = false, false, false, false
  V.anger_until = 0
  o.created_on_pause = true
  local s = o.children.sprite
  if s then s.created_on_pause = true end
  o.states.collide.can, o.states.click.can, o.states.hover.can = false, false, false
  for i = #G.I.MOVEABLE, 1, -1 do
    if G.I.MOVEABLE[i] == o then table.remove(G.I.MOVEABLE, i) end
  end
  table.insert(G.I.POPUP, o)
  place_gloat(o, gloat_spot(V.gloating.menu))
end

local function gloat_tick()
  local o, g = V.obj, V.gloating
  if g.leaving then return end
  local m = G.OVERLAY_MENU
  if not g.menu and is_game_over_menu(m) then g.menu = m end
  if g.menu and m ~= g.menu then -- the game-over screen is gone: dissolve away (REAL timer, runs paused)
    g.leaving = true
    V.fade_out(V.GLOAT_LEAVE)
    return
  end
  place_gloat(o, gloat_spot(g.menu)) -- live: the panel slides in, and the window may be resized
  -- Laugh once, a beat after Jimbo starts talking (not over his babble); without Jimbo (losses
  -- past the win ante) GLOAT_LAUGH_LATE after the game over.
  if not g.laugh_at and g.menu and jimbo_speaking(g.menu) then g.laugh_at = now() + V.GLOAT_LAUGH_DELAY end
  if not g.laughed and ((g.laugh_at and now() >= g.laugh_at)
      or (not g.laugh_at and now() - g.t0 >= V.GLOAT_LAUGH_LATE)) then
    g.laughed = true
    V.laugh(g.pitch)
  end
end

function V.tick(dt)
  if not V.obj then return end
  if V.gloating then return gloat_tick() end
  if V.fading then return end
  if reduced() then -- no roaming: live at ringside (snap there if the setting changed mid-fight)
    if V.perch ~= V.RINGSIDE then go_to(V.RINGSIDE, true); V.snap() end -- snap: sprite too
    return
  end
  -- Played cards fill the play area: park at ringside until the hand resolves. The bubble follows
  -- the avatar, so this move also happens mid-line.
  if G.STATES and G.STATE == G.STATES.HAND_PLAYED then
    V.scoring = true
    if V.perch ~= V.RINGSIDE then go_to(V.RINGSIDE, false) end
    return
  end
  if V.scoring then
    V.scoring = false
    V.next_roam = now() + V.ROAM_MIN * FinalBoss.logic.stance(V.stance).roam
  end
  if V.talking or now() < V.laugh_until then return end
  if now() >= V.next_roam then
    go_to(FinalBoss.logic.pick_variant(V.PERCH_COUNT, V.perch, math.random), false)
    V.next_roam = now() + V.roam_delay()
  end
end

function V.hit(size)
  local o = V.obj
  if not o then return end
  flash(o, 0.15)
  o:juice_up(size == 'big' and 0.6 or (size == 'weak' and 0.25 or 0.4), 0.15)
  if reduced() or size == 'weak' then return end -- a weak hit is a soft flinch: no knockback
  local dir = V.side() == 'right' and 1 or -1
  o.T.x = o.T.x + dir * V.KNOCKBACK * (size == 'big' and 1.6 or 1)
  local perch = V.perch
  after(0.3, function() if V.obj == o and V.perch == perch then go_to(perch, false) end end)
end

--- Laugh: ONE syllable (fixed for the whole laugh) repeated LAUGH.beats times at an even, fast
--- cadence, pitch stepping down, louder than talking, after a low accent. Not reduced: the chip hops,
--- tilts and shakes (see Avatar:move). Reduced: sound and a flash pulse on every other beat.
--- Returns the laugh's total duration in seconds.
function V.laugh(pitch)
  local o = V.obj
  if not o then return V.LAUGH_DURATION end
  local L = FinalBoss.logic.LAUGH
  V.laugh_id = V.laugh_id + 1
  local id = V.laugh_id
  local syllable = 'voice' .. math.random(1, 11)
  local calm = reduced()
  if not calm then
    V.laugh_start = now()
    V.laugh_until = V.laugh_start + V.LAUGH_DURATION
  end
  V.next_roam = math.max(V.next_roam, now() + V.LAUGH_DURATION + 1.5) -- no glide mid-laugh
  local a = V.LAUGH_ACCENT
  play_sound(a.sound, a.pitch, a.volume)
  for i = 0, L.beats - 1 do
    after(i * L.step, function()
      if V.obj ~= o or V.laugh_id ~= id then return end
      play_sound(syllable, (pitch or 1) * FinalBoss.logic.laugh_pitch(i), V.LAUGH_VOLUME)
      -- vanilla juice_up is a no-op under reduced motion: pulse with a brief flash instead
      if calm and i % 2 == 0 then flash(o, 0.08) end
    end)
  end
  return V.LAUGH_DURATION
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

--- Phase transformation (1.1): the chip swells and shakes for `duration` seconds. No-op under
--- reduced motion (no rise, no shake).
function V.roar(duration)
  if not V.obj or reduced() then return end
  V.roar_start = now()
  V.roar_until = V.roar_start + (duration or FinalBoss.logic.ROAR.duration)
  V.next_roam = math.max(V.next_roam, V.roar_until + 1)
end

--- Aura particles around the chip (1.1): slot 'stance' (phase II faint / III strong, boss colour)
--- or 'nemesis' (crimson). level 0 or nil removes the slot's aura.
function V.set_aura(slot, level, colour)
  local old = V.auras[slot]
  V.auras[slot] = nil
  if old then FinalBoss.effects.remove_aura(old) end
  if not V.obj or not level or level <= 0 then return end
  V.auras[slot] = FinalBoss.effects.aura(V.obj, colour, level)
end

--- Phase stance: roam interval and aura (logic.stance); phase III also trembles (Avatar:move).
function V.set_stance(phase, colour)
  V.stance = phase or 1
  V.set_aura('stance', FinalBoss.logic.stance(V.stance).aura, colour)
end

--- Flash the chip (white, or `colour`: a boss move flashes in the boss colour).
function V.flash(duration, colour)
  if V.obj then flash(V.obj, duration or 0.15, colour) end
end

--- No avatar: the HUD blind chip snaps instead (juice + a brief red burst drawn over the chip).
local function anger_chip(blind)
  if not (blind and blind.T and blind.children and blind.children.animatedSprite) then return end
  blind:juice_up(0.6, 0.4) -- vanilla juice_up is a no-op under reduced motion: the red flash stays
  local p = Particles(0, 0, 0, 0, {attach = blind, fill = true, timer = 0.008, scale = 0.35, speed = 1.2,
    lifespan = 0.4, colours = {V.RED, {0.85, 0.1, 0.1, 1}}})
  after(0.15, function() p:fade(0.25) end)
  after(0.45, function() p:remove() end)
end

--- Interrupted mid-speech: a red flash and a sharp ~0.4 s shake on the avatar, or on the HUD chip
--- when there is no avatar (reduced motion: the flash only).
function V.anger(blind)
  local o = V.obj
  if not o then return anger_chip(blind) end
  flash(o, 0.25, V.RED)
  if not reduced() then
    V.anger_until = now() + V.ANGER_TIME
    o:juice_up(0.5, 0.3)
  end
  V.next_roam = math.max(V.next_roam, now() + 2) -- stay put while snapping
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
  if V.gloating then return end -- the game-over screen owns the table
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
  V.talking, V.fading, V.tremble, V.wound, V.scoring = false, false, false, 0, false
  V.stance, V.auras, V.roar_start, V.roar_until = 1, {}, 0, 0 -- auras go with the chip's children
  V.laugh_start, V.laugh_until, V.anger_until = 0, 0, 0
  V.gloating = nil
  V.perch = V.RINGSIDE
  if o then o:remove() end
end

return V

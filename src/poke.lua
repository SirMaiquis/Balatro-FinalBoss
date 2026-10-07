--- Poke and grab the boss (1.2). A click on the boss chip pokes it, a quick run of clicks pokes it
--- hard, dragging it grabs it; the chip reacts by personality and the boss may say a line
--- (logic.poke / logic.grab decide; Dir.fire with free = true says it without touching the fight's
--- bookkeeping). The chip is the HUD blind chip, or the showdown avatar while it is out (the HUD chip
--- is dissolved then). Saved state: enc.poke (plain data, logic.poke); the grab being watched is
--- visual and never saved.
---
--- Engine notes (vanilla engine/controller.lua): a press on a node with states.click.can makes it
--- cursor_down.target, and if it also has states.drag.can it becomes dragging.target at once
--- (:321-329), so every click starts a drag. On release the drag stops (:333-336) and it is a click
--- when the cursor moved less than G.MIN_CLICK_DIST (:340-346), so a drag only counts as a grab once
--- the cursor has left that distance. The HUD chip (Blind) is clickable and draggable in vanilla
--- (blind.lua:20-22): dragging moves its sprite, which Blind:align pulls home once drag.is is off.
local K = {}
K.grab = nil -- {chip, t0}: the grab being watched (REAL time it started)
K.held = nil -- a chip let go by K.release while the button may still be down: never clicked until it is up

local function L() return FinalBoss.logic end
local function now() return FinalBoss.util.now() end

--- The encounter and blind a poke may hit right now, or nil (logic.poke_allowed).
function K.encounter()
  local st = G.GAME and G.GAME.FinalBoss
  local enc = st and st.encounter
  local blind = G.GAME and G.GAME.blind
  if not (enc and blind) then return nil end
  local S, state = G.STATES, G.STATE
  local ok = L().poke_allowed{boss = enc.boss, ended = enc.ended,
    same_blind = blind.config and blind.config.blind and blind.config.blind.key == enc.key,
    tier = enc.tier,
    playing = S and (state == S.SELECTING_HAND or state == S.HAND_PLAYED),
    intro = FinalBoss.dialogue.intro_active(), cinematic = FinalBoss.cinematic.active(),
    overlay = G.OVERLAY_MENU and true or false, paused = G.SETTINGS and G.SETTINGS.paused}
  if not ok then return nil end
  return enc, blind
end

--- Whether node is the boss chip of this blind: the avatar while it is out, else the HUD chip.
function K.is_chip(node, blind)
  local V = FinalBoss.avatar
  if V.exists() then return V.pokeable() and node == V.anchor() end
  return node == blind
end

local function personality(enc) return FinalBoss.personality.of(enc.key) end

--- The chip's reaction (kind: 'poked', 'poked_hard' or 'grabbed') and, for a moment, its line.
--- Dialogue off: the reaction only (Dir.fire says nothing then, so there is no bleep either).
local function react(enc, blind, kind, moment)
  local r = L().poke_reaction(personality(enc), kind, G.SETTINGS.reduced_motion)
  FinalBoss.avatar.poke(blind, r, FinalBoss.registry.get(enc.key).voice.pitch)
  if moment and FinalBoss.config.dialogue then FinalBoss.director.fire(moment, {free = true}) end
end

--- A click on a boss chip (hooks.lua's Blind:click wrap, Avatar:click). The release of a grab is never
--- a poke (a drag back to where it started can still end as a click).
function K.on_click(node)
  local enc, blind = K.encounter()
  if not enc or not K.is_chip(node, blind) then return end
  if K.grab and K.grab.chip == node then return end
  if K.held == node then return end
  enc.poke = enc.poke or {}
  local moment = L().poke(enc.poke, now())
  react(enc, blind, moment == 'poked_hard' and 'poked_hard' or 'poked', moment)
end

--- End the drag now, the way the controller does on release (engine/controller.lua:333-336). The
--- mouse may still be held: dragging only starts on a new press, and with no dragging target the
--- release is no drop (:347-351). cursor_down.target is still the chip, though, so a release back near
--- the press point would click it (:340-346): K.held ignores its clicks until the button is up
--- (G.CONTROLLER.is_cursor_down, :1047, :1070). The chip goes home by itself.
function K.release(chip)
  local c = G.CONTROLLER
  if c and c.dragging and c.dragging.target == chip then
    chip:stop_drag()
    chip.states.drag.is = false
    c.dragging.target = nil
  end
  K.grab = nil
  K.held = chip
end

--- Per frame (Dir.tick): the avatar may only be dragged while a poke is allowed; a drag of the chip
--- that leaves the click distance is a grab (reaction and line); GRAB_RETURN seconds later, or as soon
--- as pokes stop being allowed, the chip is let go and springs home, even while the button is held.
function K.tick()
  local enc, blind = K.encounter()
  local V = FinalBoss.avatar
  V.hud_tick(G.GAME and G.GAME.blind)
  local c = G.CONTROLLER
  if K.held and not (c and c.is_cursor_down) then K.held = nil end -- after the click pass of this frame
  local target = c and c.dragging and c.dragging.target
  local o = V.anchor()
  if o then
    o.states.drag.can = (enc ~= nil and V.pokeable())
    if target == o and not o.states.drag.can then K.release(o); return end -- never dragged outside a fight
  end
  local g = K.grab
  if g and target ~= g.chip then K.grab, g = nil, nil end -- released
  if not target then return end
  if not enc then
    if g then K.release(g.chip) end
    return
  end
  if not K.is_chip(target, blind) then return end
  if not g then
    local down = c.cursor_down and c.cursor_down.T
    local pos = c.cursor_position
    if not (down and pos) then return end
    local scale = G.TILESCALE * G.TILESIZE
    local cur = {x = pos.x / scale, y = pos.y / scale} -- the frame cursor_down.T uses (:1043)
    if Vector_Dist(down, cur) < (G.MIN_CLICK_DIST or 0.9) then return end
    K.grab = {chip = target, t0 = now()}
    enc.poke = enc.poke or {}
    react(enc, blind, 'grabbed', L().grab(enc.poke, now()))
    return
  end
  if now() - g.t0 >= L().GRAB_RETURN then K.release(g.chip) end
end

--- Run teardown: forget the watched grab.
function K.reset() K.grab, K.held = nil, nil end

return K

--- Lines said outside the fight (1.4, logic.OUTSIDE_MOMENTS): the boss preview and the reroll
--- protest/sneer from the blind-select boss chip, and the early loss from the upcoming boss's chip on
--- the game-over screen. Gated like the boss's intro (logic.decide_tier); needs config.dialogue,
--- never config.fx (config.fx only decides whether the reroll's copy is yanked away or just dissolves).
--- hooks.lua and the director call in.
local M = {}
M.PREVIEW_DELAY = 0.8 -- seconds after the blind-select screen is built (it slides up from below)
-- The first screen after a run starts or loads also waits out the screen wipe: G.FUNCS.start_run queues
-- G.FUNCS.wipe_off (button_callbacks.lua:3014-3035, 3186-3230): a 0.3 s delay, then 0.3 s fades of the
-- wipe and, from 0.55 s, its card dissolving; the blind-select UIBox is queued behind those events and
-- slides up from below the room (game.lua:3466-3470). 1.6 s clears the wipe plus the slide-in.
M.FIRST_PREVIEW_DELAY = 1.6
-- Reroll (M.on_reroll_click): a copy of the outgoing boss's chip protests where its chip was, then is
-- yanked off the nearest screen edge; the new boss sneers when it is gone. REAL seconds from the click.
M.YANK_HOLD = 0.15    -- the copy sits with its line (vanilla's panel drops away under it)
M.YANK_SHAKE = 0.25   -- then shakes (amplitude M.YANK_SHAKE_AMP, room units)
M.YANK_SHAKE_AMP = 0.06
M.YANK_SLIDE = 1.2    -- then slides out, accelerating
M.YANK_MARGIN = 1     -- room units past the edge the copy ends at
M.YANK_FADE = 0.4     -- reduced motion or fx off: no shake or slide, the copy dissolves over this, ending
M.PROTEST_TIME = M.YANK_HOLD + M.YANK_SHAKE + M.YANK_SLIDE -- the protest's length: the sneer follows
M.LINE_DURATION = 3.5 -- seconds a line stays up
M.copy = nil          -- the flying copy {box, sprite, key} while it is up
M.reroll = nil        -- the click's pending pair {token, old, ends}: M.on_reroll sneers at REAL time ends
M.EARLY_LOSS_WAIT = 10   -- seconds to wait for the game-over overlay before giving up
M.EARLY_LOSS_DELAY = 0.6 -- seconds from the chip's spawn to its line (it glides in first)
M.token = 0           -- bumped to cancel pending lines (a newer line, teardown)
M.last_variant = {}   -- per-prefix last variant (registry.resolve), session only
M.fresh = true        -- no blind-select screen yet since the run started or loaded (teardown resets it)

local function cfg() return FinalBoss.config end

--- Lines are on: a live run, FinalBoss not disabled for it, dialogue on.
local function active()
  return G.GAME and FinalBoss.director.enabled() and cfg().dialogue and true or false
end

local function bump()
  M.token = M.token + 1
  return M.token
end

--- pause_force: the timer also runs while the game is paused (the game-over screen).
local function after(delay, fn, pause_force)
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = delay, timer = 'REAL',
    blocking = false, blockable = false, pause_force = pause_force or nil,
    func = function() FinalBoss.util.guard('moments_timer', fn); return true end}))
end

local function boss_key()
  local rr = G.GAME and G.GAME.round_resets
  return rr and rr.blind_choices and rr.blind_choices.Boss
end

--- The tier this boss would get at its intro (Dir.on_blind_set's inputs); nil for an unknown key.
local function tier_of(key, st)
  local proto = key and G.P_BLINDS and G.P_BLINDS[key]
  if not proto then return nil end
  local entry = FinalBoss.registry.get(key)
  return FinalBoss.logic.decide_tier{
    is_boss = true,
    is_showdown = (proto.boss and proto.boss.showdown) and true or false,
    entry_tier = entry and entry.tier,
    ante = G.GAME.round_resets.ante,
    max_ante = st.max_ante,
    min_ante = cfg().min_ante,
  }
end

local function speaks(key, st)
  local t = tier_of(key, st)
  return t ~= nil and t ~= 'none'
end

--- The boss's localized name (Dir.vars style), so generic #1# lines fill in.
local function name_of(key)
  local ok, name = pcall(localize, {type = 'name_text', key = key, set = 'Blind'})
  if ok and type(name) == 'string' and name ~= '' and name ~= 'ERROR' then return name end
  local proto = G.P_BLINDS and G.P_BLINDS[key]
  return (proto and proto.name) or key
end

local function is_sprite(o)
  return type(o) == 'table' and o.atlas ~= nil and o.sprite_pos ~= nil
end

--- First sprite under a UIElement, in definition order.
local function first_sprite(node)
  if type(node) ~= 'table' then return nil end
  local obj = node.config and node.config.object
  if is_sprite(obj) then return obj end
  for _, child in ipairs(node.children or {}) do
    local found = first_sprite(child)
    if found then return found end
  end
  return nil
end

--- The Boss choice's blind chip sprite on the blind-select screen (create_UIBox_blind_choice: the
--- blind_choice.animation object inside the 'blind_desc' row; the stake sprite comes after it), or nil.
function M.chip()
  local box = G.blind_select_opts and G.blind_select_opts.boss
  if type(box) ~= 'table' then return nil end
  local desc = box.get_UIE_by_ID and box:get_UIE_by_ID('blind_desc')
  return first_sprite(desc) or first_sprite(box.UIRoot)
end

--- The blind-select screen is up (selecting a blind clears G.blind_select, button_callbacks.lua).
local function on_screen()
  if not G.blind_select then return false end
  return not (G.STATES and G.STATE ~= G.STATES.BLIND_SELECT)
end

local function pitch_of(key)
  local entry = FinalBoss.registry.get(key)
  return (entry and entry.voice and entry.voice.pitch) or 1.0
end

--- Say one outside line from the boss chip (or from host, the reroll's copy). True when it showed.
local function speak(key, moment, host)
  if not (active() and on_screen()) then return false end
  local chip = host or M.chip()
  if not chip then return false end
  local line = FinalBoss.registry.resolve(key, moment, M.last_variant)
  if not line then return false end
  local pitch = pitch_of(key)
  -- force: no in-fight cooldown here; free: never delays the next fight's lines; late: drawn above
  -- the blind-select UI (dialogue.show).
  return FinalBoss.dialogue.say(chip, line, {name_of(key)}, pitch,
    {force = true, free = true, late = true, duration = M.LINE_DURATION}) and true or false
end

--- The blind-select screen was built: the upcoming boss previews, once per ante.
function M.on_blind_select()
  if not G.GAME then return end
  local st = FinalBoss.util.state()
  local first = M.fresh
  M.fresh = false
  if not active() then return end
  local key = boss_key()
  local ante = G.GAME.round_resets.ante
  if not FinalBoss.logic.preview_due{ante = ante, previewed_ante = st.previewed_ante, tier = tier_of(key, st)}
    then return end
  local token = bump()
  after(first and M.FIRST_PREVIEW_DELAY or M.PREVIEW_DELAY, function()
    if M.token ~= token or boss_key() ~= key or st.previewed_ante == ante then return end
    -- Counted only once seen, so a blind picked or a quit before it shows leaves it for next time.
    if speak(key, 'preview') then st.previewed_ante = ante end
  end)
end

-- The reroll (1.4) ----------------------------------------------------------------------------------
-- Vanilla's reroll_boss (button_callbacks.lua:2845-2905) drops the Boss panel at the click and swaps the
-- boss ~0.3 game-seconds later, so a protest said after the swap would come from the NEW chip. At the
-- click (M.on_reroll_click) a copy of the OLD chip appears where it was and protests from there, then
-- is yanked off the nearest screen edge; after the swap (M.on_reroll) the new boss sneers from its real
-- chip once the copy is gone. The copy is its own late-drawn UIBox (never the showdown avatar, V.obj).

local function real_now() return G.TIMERS.REAL end

--- The window's edges in room units: left, top, right, bottom (main.lua sizes G.ROOM inside it).
local function screen_bounds()
  local R = G.ROOM and G.ROOM.T
  local s = (G.TILESIZE or 0) * (G.TILESCALE or 0)
  local ok, w, h = pcall(function() return love.graphics.getDimensions() end)
  if R and ok and type(w) == 'number' and type(h) == 'number' and s > 0 then
    return -R.x, -R.y, w / s - R.x, h / s - R.y
  end
  local rw, rh = (R and R.w) or 20, (R and R.h) or 11.5
  return -1, -1, rw + 1, rh + 1
end

--- The edge of bounds {left, top, right, bottom} nearest the rect (x, y, w, h) and the spot past it
--- (M.YANK_MARGIN beyond, fully off screen) where the copy ends: edge, x, y. Ties: right, left,
--- bottom, top.
function M.yank_target(x, y, w, h, bounds)
  local l, t, r, b = bounds[1], bounds[2], bounds[3], bounds[4]
  local cx, cy = x + w / 2, y + h / 2
  local best, edge
  for _, e in ipairs({{'right', r - cx}, {'left', cx - l}, {'bottom', b - cy}, {'top', cy - t}}) do
    if not best or e[2] < best then best, edge = e[2], e[1] end
  end
  local m = M.YANK_MARGIN
  if edge == 'right' then return edge, r + m, y end
  if edge == 'left' then return edge, l - w - m, y end
  if edge == 'bottom' then return edge, x, b + m end
  return edge, x, t - h - m
end

--- A copy of key's blind chip over chip (the Boss choice's sprite), built like vanilla's
--- (create_UIBox_blind_choice: SMODS.create_sprite from the blind's atlas and pos, dissolve draw steps),
--- in a late-drawn UIBox so it sits above the blind-select panel. nil for an unknown key.
local function build_copy(key, chip)
  local proto = G.P_BLINDS and G.P_BLINDS[key]
  local T = chip and chip.T
  if not (proto and T) then return nil end
  local x, y, w, h = T.x, T.y, T.w, T.h
  local atlas = (SMODS.get_atlas and proto.atlas and SMODS.get_atlas(proto.atlas)) or 'blind_chips'
  local pos = proto.pos or {x = 0, y = 0}
  local sprite = SMODS.create_sprite(x, y, w, h, atlas, {x = pos.x, y = pos.y})
  sprite:define_draw_steps({{shader = 'dissolve', shadow_height = 0.05}, {shader = 'dissolve'}})
  local box = UIBox{T = {x, y, w, h},
    definition = {n = G.UIT.ROOT, config = {align = 'cm', padding = 0, colour = G.C.CLEAR},
      nodes = {{n = G.UIT.O, config = {object = sprite}}}},
    config = {align = 'cm', offset = {x = 0, y = 0}, can_collide = false}}
  box.attention_text = true -- vanilla's late pass: above the panel; its bubble (made after) above it
  sprite.role.draw_major = sprite -- the dissolve shader reads sprite.dissolve / dissolve_colours
  sprite.dissolve = 0
  local c = proto.boss_colour or G.C.RED
  sprite.dissolve_colours = {G.C.BLACK, {c[1], c[2], c[3], 1}}
  return {box = box, sprite = sprite, key = key, x0 = x, y0 = y, w = w, h = h}
end

--- Remove the copy if it is up. Its bubble goes with it (the sneer replaces it anyway), except on
--- teardown, where dialogue.drop_on_teardown forgets it and the run's UI is already gone.
function M.remove_copy(teardown)
  local c = M.copy
  M.copy = nil
  if not c then return end
  local D = FinalBoss.dialogue
  if not teardown and D and D.host == c.sprite and D.hide then
    local ok, err = pcall(D.hide)
    if not ok then FinalBoss.util.log('error', 'reroll copy bubble: ' .. tostring(err)) end
  end
  if c.box and not c.box.REMOVED then
    local ok, err = pcall(c.box.remove, c.box)
    if not ok then FinalBoss.util.log('error', 'reroll copy remove: ' .. tostring(err)) end
  end
end

local function place(c, x, y)
  local T, VT = c.box.T, c.box.VT
  T.x, T.y = x, y
  if VT then VT.x, VT.y = x, y end -- a yank, not a glide: the spring would lag behind
end

--- One frame of the copy's exit; true when it is over. Still (reduced motion, fx off): it holds with its
--- line, then dissolves. Else it holds, shakes, then slides off the nearest edge, accelerating.
local function yank_frame(c)
  local t = real_now() - c.t0
  if t >= M.PROTEST_TIME then return true end
  if c.still then
    local f = t - (M.PROTEST_TIME - M.YANK_FADE)
    if f > 0 then c.sprite.dissolve = math.min(1, f / M.YANK_FADE) end
    return false
  end
  local s = t - M.YANK_HOLD
  if s <= 0 then return false end
  if s < M.YANK_SHAKE then
    local a = M.YANK_SHAKE_AMP
    place(c, c.x0 + (math.random() - 0.5) * 2 * a, c.y0 + (math.random() - 0.5) * 2 * a)
    return false
  end
  local p = math.min(1, (s - M.YANK_SHAKE) / M.YANK_SLIDE)
  local e = p * p * p
  place(c, c.x0 + (c.tx - c.x0) * e, c.y0 + (c.ty - c.y0) * e)
  return false
end

--- Run the copy's exit every frame on the REAL timer (pause_force: also if the game is paused).
local function start_yank(c)
  c.t0 = real_now()
  c.still = (G.SETTINGS and G.SETTINGS.reduced_motion) or not cfg().fx
  if not c.still then
    c.edge, c.tx, c.ty = M.yank_target(c.x0, c.y0, c.w, c.h, {screen_bounds()})
  end
  G.E_MANAGER:add_event(Event({timer = 'REAL', pause_force = true, blocking = false, blockable = false,
    func = function()
      if M.copy ~= c then return true end -- removed (a newer reroll, teardown)
      local ok, done = pcall(yank_frame, c)
      if not ok then FinalBoss.util.log('error', 'reroll yank failed: ' .. tostring(done)) end
      if done or not ok then M.remove_copy(); return true end
      return false
    end}))
end

--- The player clicked a boss reroll on the blind-select screen (hooks.lua, before vanilla's swap):
--- old_key is still the Boss choice and its chip is on screen. A copy of that chip protests
--- (rerolled_out) and is yanked away; M.on_reroll says the sneer when it is gone. This counts as the
--- ante's preview. A newer reroll cancels both (token) and removes a copy still up. An unknown or
--- silent old boss gets no copy and no line (the sneer still comes, at once).
function M.on_reroll_click(old_key)
  if not (G.GAME and active()) then return end
  local st = FinalBoss.util.state()
  st.previewed_ante = G.GAME.round_resets.ante
  M.remove_copy()
  local token = bump()
  M.reroll = {token = token, old = old_key, ends = real_now()}
  if not (speaks(old_key, st) and on_screen()) then return end
  local ok, c = pcall(build_copy, old_key, M.chip())
  if not ok then FinalBoss.util.log('error', 'reroll copy failed: ' .. tostring(c)) end
  if not (ok and c) then return end
  M.copy = c
  if not speak(old_key, 'rerolled_out', c.sprite) then M.remove_copy(); return end
  M.reroll.ends = real_now() + M.PROTEST_TIME
  local sok, err = pcall(start_yank, c)
  if not sok then
    FinalBoss.util.log('error', 'reroll yank failed: ' .. tostring(err))
    M.remove_copy()
  end
end

--- The boss was rerolled (old_key -> new_key, the new chip already built): the new one sneers once
--- the old one's protest (M.on_reroll_click) is over, or at once with no protest. The sneer is this
--- ante's preview. A newer reroll or teardown cancels a pending sneer.
function M.on_reroll(old_key, new_key)
  if not (G.GAME and active()) then return end
  local st = FinalBoss.util.state()
  st.previewed_ante = G.GAME.round_resets.ante
  local r = M.reroll
  M.reroll = nil
  local token, wait
  if r and r.token == M.token and r.old == old_key then
    token, wait = r.token, math.max(0, r.ends - real_now())
  else
    token, wait = bump(), 0 -- no click seen: no protest, the old chip is gone
  end
  local function sneer()
    if M.token ~= token or boss_key() ~= new_key then return end
    if speaks(new_key, st) then speak(new_key, 'rerolled_in') end
  end
  if wait > 0 then after(wait, sneer) else sneer() end
end

--- The run ended on a small or big blind (Dir.on_round_end): the upcoming boss's chip comes out
--- beside the game-over panel (avatar.spawn_gloat) and mocks the player for never reaching it.
--- Never a loss to that boss: nothing in memory, nemesis, achievements or stats, and st.lost_to
--- stays unset (Jimbo's quip stays vanilla). Skipped when the boss can't be read or would be silent
--- (the intro's tier gate), and as a whole with dialogue off (a silent chip has no point).
--- The game-over screen pauses the game (G.SETTINGS.paused) and its overlay may not be up yet: the
--- wait and the line are pause_force events on the REAL timer.
function M.on_early_loss()
  if not (G.GAME and active()) then return end
  local st = FinalBoss.util.state()
  local key = boss_key()
  if not speaks(key, st) then return end -- unreadable, unknown to G.P_BLINDS, or silent
  local line = FinalBoss.registry.resolve(key, 'early_loss', M.last_variant)
  if not line then return end
  local token = bump()
  local pitch = pitch_of(key)
  local give_up = FinalBoss.util.now() + M.EARLY_LOSS_WAIT
  local function say(chip)
    if M.token ~= token or FinalBoss.avatar.anchor() ~= chip then return end -- the screen went
    -- force: nothing to wait for; free: no fight cooldown; popup: drawn above the game-over dim,
    -- like the chip (avatar.gloat). dialogue hosts it on the avatar chip (G.GAME.blind is the lost blind).
    FinalBoss.dialogue.say(G.GAME.blind, line, {name_of(key)}, pitch,
      {force = true, free = true, popup = true, duration = M.LINE_DURATION})
  end
  G.E_MANAGER:add_event(Event({timer = 'REAL', pause_force = true, blocking = false, blockable = false,
    func = function()
      if M.token ~= token or FinalBoss.util.now() > give_up then return true end
      if not FinalBoss.avatar.on_game_over_screen() then return false end -- keep waiting
      FinalBoss.util.guard('early_loss', function()
        if FinalBoss.avatar.spawn_gloat(key, pitch) then
          local chip = FinalBoss.avatar.anchor()
          after(M.EARLY_LOSS_DELAY, function() say(chip) end, true)
        end
      end)
      return true
    end}))
end

--- Leaving a run (Game:delete_run, which removes every UIBox and clears the event queue): drop
--- pending lines. dialogue.drop_on_teardown forgets the bubble itself.
function M.teardown()
  bump()
  M.reroll = nil
  M.remove_copy(true) -- the reroll's flying copy goes with the run
  M.fresh = true -- the next run's first screen comes in behind the screen wipe
end

return M

--- Lines said outside the fight (1.4, logic.OUTSIDE_MOMENTS): the boss preview and the reroll
--- protest/sneer from the blind-select boss chip, and the early loss from the upcoming boss's chip on
--- the game-over screen. Gated like the boss's intro (logic.decide_tier); needs config.dialogue,
--- never config.fx. hooks.lua and the director call in.
local M = {}
M.PREVIEW_DELAY = 0.8 -- seconds after the blind-select screen is built (it slides up from below)
-- The first screen after a run starts or loads also waits out the screen wipe: G.FUNCS.start_run queues
-- G.FUNCS.wipe_off (button_callbacks.lua:3014-3035, 3186-3230): a 0.3 s delay, then 0.3 s fades of the
-- wipe and, from 0.55 s, its card dissolving; the blind-select UIBox is queued behind those events and
-- slides up from below the room (game.lua:3466-3470). 1.6 s clears the wipe plus the slide-in.
M.FIRST_PREVIEW_DELAY = 1.6
M.SNEER_DELAY = 2     -- seconds between the outgoing boss's protest and the new boss's sneer
M.LINE_DURATION = 3.5 -- seconds a line stays up
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

--- Say one outside line from the boss chip. True when it showed.
local function speak(key, moment)
  if not (active() and on_screen()) then return false end
  local chip = M.chip()
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

--- The boss was rerolled (old_key -> new_key, the new chip already built): the old boss protests,
--- then the new one sneers. The sneer is this ante's preview. A newer reroll cancels a pending sneer.
function M.on_reroll(old_key, new_key)
  if not (G.GAME and active()) then return end
  local st = FinalBoss.util.state()
  st.previewed_ante = G.GAME.round_resets.ante
  local token = bump()
  local protested = speaks(old_key, st) and speak(old_key, 'rerolled_out')
  local function sneer()
    if M.token ~= token or boss_key() ~= new_key then return end
    if speaks(new_key, st) then speak(new_key, 'rerolled_in') end
  end
  if protested then after(M.SNEER_DELAY, sneer) else sneer() end
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
  M.fresh = true -- the next run's first screen comes in behind the screen wipe
end

return M

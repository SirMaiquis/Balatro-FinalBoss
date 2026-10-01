--- The ONLY file that hooks game or smods functions. Each hook keeps the original
--- behaviour and runs FinalBoss code inside util.guard, so FinalBoss can never break a run.
local U = FinalBoss.util
local H = {}

local function director() return FinalBoss.director end

local showdown_error_logged = false

FinalBoss.mod.calculate = function(self, context)
  if not G.GAME or not director().enabled() then return end
  if context.setting_blind then
    U.guard('setting_blind', director().on_blind_set, G.GAME.blind)
  elseif context.after then
    U.guard('hand_after', director().on_hand_after)
  elseif context.blind_disabled then
    U.guard('blind_disabled', director().on_blind_disabled)
  elseif context.blind_defeated then
    U.guard('blind_defeated', director().on_blind_defeated)
  end
end

local orig_blind_load = Blind.load
function Blind:load(...)
  local ret = orig_blind_load(self, ...)
  if G.GAME and director().enabled() then U.guard('blind_load', director().on_blind_loaded, self) end
  return ret
end

local orig_end_round = end_round
function end_round(...)
  local ret = orig_end_round(...)
  -- Queued after vanilla's own end-of-round event, so game over / Mr. Bones is decided.
  G.E_MANAGER:add_event(Event({func = function()
    if director().enabled() then U.guard('end_round', director().on_round_end) end
    return true
  end}))
  return ret
end

local orig_keypressed = love.keypressed
function love.keypressed(key, ...)
  if FinalBoss.cinematic.active() then U.guard('cinematic_skip', FinalBoss.cinematic.skip)
  elseif FinalBoss.dialogue.intro_active() then U.guard('skip', FinalBoss.dialogue.skip) end
  return orig_keypressed(key, ...)
end

-- Showdown schedule. The vanilla result is OR'd in, so the win-ante boss is always a showdown.
-- In smods 26.829.0 this function is the only showdown eligibility switch (src/utils/weights.lua).
local orig_is_showdown_ante = SMODS.is_showdown_ante
SMODS.is_showdown_ante = function(...)
  local vanilla = orig_is_showdown_ante(...)
  local sd = FinalBoss.config.showdown
  if vanilla or not (sd and sd.enabled) or not G.GAME then return vanilla end
  local ok, extra = pcall(FinalBoss.logic.is_extra_showdown, G.GAME.round_resets.ante, sd.start_ante, sd.every)
  if not ok then
    if not showdown_error_logged then
      U.log('error', 'showdown schedule failed: ' .. tostring(extra))
      showdown_error_logged = true
    end
    return vanilla
  end
  return extra or false
end

-- Game:delete_run (menu, restart, new run) clears the event queue, so pending fx eases never finish:
-- reset the vignette state here or it would draw on the menu and in the next run.
local orig_delete_run = Game.delete_run
function Game:delete_run(...)
  local ret = orig_delete_run(self, ...)
  U.guard('delete_run', function()
    director().reset_stage()
    FinalBoss.dialogue.drop_on_teardown()
  end)
  return ret
end

-- Vanilla paints every showdown blue/red (common_events.lua ease_background_colour_blind) and
-- re-runs it on every refresh, including fx.flash's restore: re-apply the arena palette after it.
local orig_ease_bg_blind = ease_background_colour_blind
-- Shop and booster packs keep vanilla's palette, so those refreshes are not re-themed.
local function neutral_state(state)
  local S = G.STATES
  if not (S and state) then return false end
  return state == S.SHOP or state == S.TAROT_PACK or state == S.PLANET_PACK
    or state == S.SPECTRAL_PACK or state == S.STANDARD_PACK or state == S.BUFFOON_PACK
end

function ease_background_colour_blind(state, ...)
  local ret = orig_ease_bg_blind(state, ...)
  if FinalBoss.arena.active() and not neutral_state(state) then
    U.guard('arena_apply', FinalBoss.arena.apply)
  end
  return ret
end

-- Per-frame stage tick (avatar idle/roam, HP bar trail, arena music pitch).
local orig_game_update = Game.update
function Game:update(dt, ...)
  local ret = orig_game_update(self, dt, ...)
  if G.GAME and director().enabled() then U.guard('stage_tick', director().tick, dt) end
  return ret
end

return H

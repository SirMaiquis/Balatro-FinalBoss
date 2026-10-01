--- Showdown cinematics (spec 2026-10-01 §7): letterbox + title card + avatar fall-in before the
--- intro dialogue, and (Task 8) the slow-motion explosive finale. Owns FinalBoss.timescale.
local C = {}
C.BAR_H = 1.1
C.token = 0        -- bumped to cancel pending intro beats
C.phase = nil      -- 'intro' | 'dialogue' | 'finale' | nil
C.bars = nil       -- {top = UIBox, bottom = UIBox}
C.leaving = {}     -- bars sliding out, removed by a timer (or by reset if the queue is cleared)
C.title = nil
C.on_done, C.blind, C.nums = nil, nil, nil

local function reduced() return G.SETTINGS.reduced_motion end

--- Timer that is cancelled when C.token moves on (skip / reset / a new sequence).
local function after(delay, token, fn)
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = delay, timer = 'REAL', blocking = false,
    blockable = false, func = function()
      if C.token == token then FinalBoss.util.guard('cinematic_timer', fn) end
      return true
    end}))
end

--- Timer that always runs (cleanup that must survive skips).
local function later(delay, fn)
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = delay, timer = 'REAL', blocking = false,
    blockable = false, func = function() FinalBoss.util.guard('cinematic_cleanup', fn); return true end}))
end

local function make_bar(top)
  return UIBox{
    definition = {n = G.UIT.ROOT, config = {align = 'cm', colour = G.C.BLACK, minw = G.ROOM.T.w + 4,
      minh = C.BAR_H, r = 0}, nodes = {}},
    config = {major = G.ROOM_ATTACH, align = top and 'tm' or 'bm',
      offset = {x = 0, y = top and -C.BAR_H or C.BAR_H}, bond = 'Weak', can_collide = false},
  }
end

local function place_bars(bars, visible)
  for side, box in pairs(bars) do
    local hidden = (side == 'top') and -C.BAR_H or C.BAR_H
    box.alignment.offset = {x = 0, y = visible and 0 or hidden}
    if reduced() then box:align_to_major(); box:hard_set_VT() end -- T follows the offset next frame otherwise
  end
end

local function remove_title()
  if C.title then C.title:remove(); C.title = nil end
end

local function show_title(blind)
  local c = (blind.config.blind and blind.config.blind.boss_colour) or G.C.RED
  local name = blind.loc_name or (blind.config.blind and blind.config.blind.name) or ''
  C.title = UIBox{
    definition = {n = G.UIT.ROOT, config = {align = 'cm', colour = G.C.CLEAR, padding = 0.1}, nodes = {
      {n = G.UIT.R, config = {align = 'cm'}, nodes = {
        {n = G.UIT.O, config = {object = DynaText({string = {localize('fb_showdown_title')},
          colours = {G.C.WHITE}, scale = 0.6, shadow = true, pop_in = 0, pop_in_rate = 4, silent = true})}}}},
      {n = G.UIT.R, config = {align = 'cm'}, nodes = {
        {n = G.UIT.O, config = {object = DynaText({string = {name}, colours = {c}, scale = 1.4,
          shadow = true, bump = true, pop_in = 0.2, pop_in_rate = 3, silent = true})}}}},
    }},
    config = {major = G.ROOM_ATTACH, align = 'cm', offset = {x = 0, y = -1}, bond = 'Weak', can_collide = false},
  }
end

local function spawn_stage(fall)
  if FinalBoss.avatar.exists() or not C.blind then return end
  FinalBoss.avatar.spawn(C.blind, {fall = fall})
  FinalBoss.hpbar.create(FinalBoss.avatar.anchor(), C.blind, C.nums.total, C.nums.required)
end

local function land()
  if not FinalBoss.avatar.exists() then return end
  if not reduced() then G.ROOM.jiggle = G.ROOM.jiggle + 4 end
  local x, y, w, h = FinalBoss.avatar.position()
  local c = FinalBoss.avatar.anchor().dissolve_colours[2]
  local p = Particles(x, y + h * 0.7, w, h * 0.3, {timer = 0.01, scale = 0.3, speed = 3,
    lifespan = 0.8, colours = {c, G.C.WHITE}, fill = true})
  play_sound('slice1', 0.8, 0.6)
  later(0.5, function() p:fade(0.3) end)
  later(0.9, function() p:remove() end)
end

local function finish_intro()
  remove_title()
  C.phase = 'dialogue'
  local cb = C.on_done
  C.on_done = nil
  if cb then cb() end
end

function C.play_intro(blind, nums, on_done)
  C.reset()
  C.token = C.token + 1
  local token = C.token
  C.phase, C.on_done, C.blind, C.nums = 'intro', on_done, blind, nums
  C.bars = {top = make_bar(true), bottom = make_bar(false)}
  place_bars(C.bars, true)
  play_sound('whoosh_long', 1, 0.5)
  after(0.4, token, function()
    show_title(blind)
    play_sound('gong', 0.9, 0.5)
    play_sound('timpani', 1, 0.5)
  end)
  after(1.6, token, function()
    remove_title()
    spawn_stage(not reduced())
  end)
  after(1.95, token, land)
  after(2.4, token, finish_intro)
end

function C.active() return C.phase == 'intro' end

--- Any key / click during the intro beats: jump to the end state, then start the dialogue.
function C.skip()
  if C.phase ~= 'intro' then return end
  C.token = C.token + 1
  remove_title()
  spawn_stage(false)
  finish_intro()
end

--- Called when the intro dialogue ends (or is skipped / absent): letterbox slides away.
function C.retract_bars()
  if C.bars then
    local bars = C.bars
    C.bars = nil
    place_bars(bars, false)
    for _, b in pairs(bars) do C.leaving[#C.leaving + 1] = b end
    later(0.5, function()
      for _, b in pairs(bars) do
        for i = #C.leaving, 1, -1 do
          if C.leaving[i] == b then table.remove(C.leaving, i); b:remove() end
        end
      end
    end)
  end
  if C.phase == 'dialogue' then C.phase = nil end
end

function C.play_finale(blind) end
function C.game_over(pitch) end

function C.reset()
  C.token = C.token + 1
  FinalBoss.timescale = 1
  remove_title()
  if C.bars then for _, b in pairs(C.bars) do b:remove() end; C.bars = nil end
  for _, b in ipairs(C.leaving) do b:remove() end
  C.leaving = {}
  C.phase, C.on_done, C.blind, C.nums = nil, nil, nil, nil
end

return C

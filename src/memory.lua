--- Boss memory (1.1): per Balatro profile, in G.PROFILES[G.SETTINGS.profile].FinalBoss. Vanilla saves
--- it with the profile: Game:save_progress hands the whole profile table to the save thread
--- (game.lua:1193-1197), which writes <profile>/profile.jkr (engine/save_manager.lua:52), and
--- Game:load_profile copies every key back (game.lua:845-854). Records keep counting with the Boss
--- memory setting off; the setting only hides rematch lines and the nemesis presentation.
local Mem = {}

local RECORD_DEFAULTS = {fights = 0, wins = 0, losses = 0, last_loss = 0}

--- Saved data can come from an older or damaged profile: make every field the rules read the right
--- type (wrong types are replaced, never trusted).
local function repair(m)
  FinalBoss.util.fill_defaults(m, FinalBoss.logic.new_memory())
  for _, field in ipairs({'bosses', 'broken', 'interrupted', 'final_defeated', 'final_defeated_twisted'}) do
    if type(m[field]) ~= 'table' then m[field] = {} end
  end
  if type(m.loss_seq) ~= 'number' then m.loss_seq = 0 end
  if type(m.nemesis) ~= 'string' then m.nemesis = nil end
  for key, r in pairs(m.bosses) do
    if type(r) ~= 'table' then
      m.bosses[key] = nil
    else
      for field, default in pairs(RECORD_DEFAULTS) do
        if type(r[field]) ~= 'number' then r[field] = default end
      end
      if r.last ~= 'won' and r.last ~= 'lost' then r.last = nil end
    end
  end
end

--- The profile's memory, created or completed from logic.new_memory(). nil before profiles exist.
function Mem.data()
  local profiles = G and G.PROFILES
  local p = profiles and G.SETTINGS and profiles[G.SETTINGS.profile]
  if not p then return nil end
  if type(p.FinalBoss) ~= 'table' then p.FinalBoss = {} end
  repair(p.FinalBoss)
  return p.FinalBoss
end

--- Queue the profile write and force it. Game:save_progress only queues the request; Game:update
--- writes it when G.FILE_HANDLER.force is set (or on a stage change / every 30 s), and quitting does
--- not flush. Vanilla follows its own save_progress with force = true (state_events.lua:74-75).
function Mem.save()
  if not (G and G.save_progress) then return end
  G:save_progress()
  G.FILE_HANDLER = G.FILE_HANDLER or {}
  G.FILE_HANDLER.force = true
end

--- Memory is bookkeeping: an error here is logged and must never break the intro, the finale or the
--- game-over cleanup that called it (and never disables the mod for the run, unlike util.guard).
--- Returns fn's results, or nothing after an error.
local function safe(name, fn, ...)
  local res = {pcall(fn, ...)}
  if not res[1] then
    FinalBoss.util.log('error', ('memory.%s failed: %s'):format(name, tostring(res[2])))
    return
  end
  return res[2], res[3] -- (no function here returns more than two values)
end

--- Blind set (once per encounter; Continue does not call it).
function Mem.on_fight(key)
  return safe('on_fight', function()
    local m = Mem.data()
    if not m then return end
    FinalBoss.logic.record_result(m, key, 'fight')
    Mem.save()
  end)
end

--- The player's last result against this boss: 'won', 'lost' or nil.
function Mem.last(key)
  return safe('last', function()
    local m = Mem.data()
    local r = m and m.bosses[key]
    return r and r.last or nil
  end)
end

function Mem.is_nemesis(key)
  return safe('is_nemesis', function()
    local m = Mem.data()
    return (m and m.nemesis == key) and true or false
  end) or false
end

--- The player beat the encounter's boss. Returns the memory and whether it was the nemesis (it is
--- then broken until it beats the player again).
--- (nil, false) when there is no profile or the record failed.
function Mem.on_win(enc)
  local m, beaten = safe('on_win', function()
    local mem = Mem.data()
    if not mem then return nil, false end
    FinalBoss.logic.record_result(mem, enc.key, 'won')
    if enc.showdown then
      mem.final_defeated[enc.key] = true
      if enc.twists_on then mem.final_defeated_twisted[enc.key] = true end
    end
    local broke = mem.nemesis == enc.key
    if broke then FinalBoss.logic.break_nemesis(mem, enc.key) end
    Mem.save()
    return mem, broke
  end)
  return m, beaten or false
end

--- The boss ended the run. Returns the memory (nil: no profile or it failed).
function Mem.on_loss(key)
  return safe('on_loss', function()
    local m = Mem.data()
    if not m then return nil end
    FinalBoss.logic.record_result(m, key, 'lost')
    Mem.save()
    return m
  end)
end

--- The player interrupted this boss's intro. Returns the memory.
function Mem.on_interrupt(key)
  return safe('on_interrupt', function()
    local m = Mem.data()
    if not m then return nil end
    m.interrupted[key] = true
    Mem.save()
    return m
  end)
end

return Mem

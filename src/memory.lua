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

local function save()
  if G and G.save_progress then G:save_progress() end
end

--- Blind set (once per encounter; Continue does not call it).
function Mem.on_fight(key)
  local m = Mem.data()
  if not m then return end
  FinalBoss.logic.record_result(m, key, 'fight')
  save()
end

--- The player's last result against this boss: 'won', 'lost' or nil.
function Mem.last(key)
  local m = Mem.data()
  local r = m and m.bosses[key]
  return r and r.last or nil
end

function Mem.is_nemesis(key)
  local m = Mem.data()
  return (m and m.nemesis == key) and true or false
end

--- The player beat the encounter's boss. Returns the memory and whether it was the nemesis (it is
--- then broken until it beats the player again).
function Mem.on_win(enc)
  local m = Mem.data()
  if not m then return nil, false end
  FinalBoss.logic.record_result(m, enc.key, 'won')
  if enc.showdown then
    m.final_defeated[enc.key] = true
    if enc.twists_on then m.final_defeated_twisted[enc.key] = true end
  end
  local beaten = m.nemesis == enc.key
  if beaten then FinalBoss.logic.break_nemesis(m, enc.key) end
  save()
  return m, beaten
end

--- The boss ended the run.
function Mem.on_loss(key)
  local m = Mem.data()
  if not m then return end
  FinalBoss.logic.record_result(m, key, 'lost')
  save()
end

--- The player interrupted this boss's intro. Returns the memory.
function Mem.on_interrupt(key)
  local m = Mem.data()
  if not m then return nil end
  m.interrupted[key] = true
  save()
  return m
end

return Mem

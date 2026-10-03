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
      -- twisted: the twists were on and the boss kept its power (enc.powerless: Dir.on_blind_defeated)
      if enc.twists_on and not enc.powerless then mem.final_defeated_twisted[enc.key] = true end
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

-- Nemesis presentation (visual, rebuilt on Continue, hidden with the Boss memory setting off) --------

Mem.CRIMSON = {0.86, 0.08, 0.24, 1}
Mem.tag, Mem.hud_aura = nil, nil -- the NEMESIS tag and aura on the HUD blind chip (never saved)

--- enc.recorded: the result is in (a 'none' tier encounter is never marked ended).
local function presenting(enc)
  return enc and enc.nemesis and FinalBoss.config.memory and not enc.ended and not enc.recorded
end

-- The presentation (unpresent, present, celebrate) runs through safe too: a visual error is logged
-- and never aborts the record, the finale or the game-over cleanup around it.

function Mem.unpresent()
  safe('unpresent', function()
    local tag, aura = Mem.tag, Mem.hud_aura
    Mem.tag, Mem.hud_aura = nil, nil -- forgotten first: a failing removal is never retried
    if tag and not tag.REMOVED then tag:remove() end
    FinalBoss.effects.remove_aura(aura)
    if FinalBoss.avatar.exists() then FinalBoss.avatar.set_aura('nemesis', 0) end
  end)
end

--- How far the NEMESIS tag drops from its 'tm' spot (above the chip) onto the chip's top edge, so it
--- never covers the boss's effect text rows above the chip (UI_definitions.lua:1221-1232).
Mem.TAG_DROP = 0.2

--- Show that this boss is the player's nemesis: a crimson aura on the showdown avatar when it is on
--- the table (moves.performer), otherwise a red NEMESIS tag on the top edge of the HUD blind chip and
--- a faint crimson aura on it. Decided by enc.nemesis (set at blind set); nothing with Boss memory off.
function Mem.present(blind)
  safe('present', function()
    local st = G.GAME and G.GAME.FinalBoss
    local enc = st and st.encounter
    if not presenting(enc) then return end
    if not (blind and blind.config and blind.config.blind and blind.config.blind.key == enc.key) then return end
    Mem.unpresent()
    local p = FinalBoss.moves.performer(blind)
    if p.avatar then
      FinalBoss.avatar.set_aura('nemesis', 2, Mem.CRIMSON)
      return
    end
    Mem.hud_aura = FinalBoss.effects.aura(p.obj, Mem.CRIMSON, 1)
    Mem.tag = UIBox{
      definition = {n = G.UIT.ROOT, config = {align = 'cm', colour = Mem.CRIMSON, r = 0.1, padding = 0.05}, nodes = {
        {n = G.UIT.T, config = {text = localize('fb_nemesis_title'), scale = 0.3, colour = G.C.WHITE, shadow = true}}}},
      config = {major = p.obj, align = 'tm', offset = {x = 0, y = Mem.TAG_DROP}, bond = 'Weak', can_collide = false},
    }
    -- Drawn in vanilla's late pass (game.lua:2822-2829), so the HUD panel never covers it.
    Mem.tag.attention_text = true
  end)
end

--- The nemesis's own defeat line replaces its normal one (Dir.fire opts.line).
function Mem.defeat_line(enc, moment)
  if moment == 'defeat' and enc and enc.nemesis and FinalBoss.config.memory then return 'nemesis_defeat' end
  return nil
end

--- The nemesis fell: a gold burst over the play area (needs screen effects), a gold banner and a gong.
function Mem.celebrate()
  safe('celebrate', function()
    if FinalBoss.config.fx and G.play and G.play.T then
      local T = G.play.T
      FinalBoss.effects.burst({x = T.x, y = T.y, w = T.w, h = T.h}, nil, {colour = G.C.GOLD, scale = 1.6})
    end
    attention_text{text = localize('fb_nemesis_defeated'), scale = 1.1, hold = 2.5, major = G.play,
      align = 'cm', offset = {x = 0, y = -1.6}, colour = G.C.GOLD}
    play_sound('gong', 1.25, 0.45)
  end)
end

--- Developer key F9: make the current boss the profile's nemesis (saved like a real one) and
--- present it now. Returns the boss key, or nil when no boss fight is on. The encounter is marked
--- fake_nemesis (plain saved data): beating it does not earn Nemesis Slayer (a later encounter
--- with that boss, a nemesis read from the profile, does).
function Mem.fake_nemesis()
  local st = G.GAME and G.GAME.FinalBoss
  local enc = st and st.encounter
  local blind = G.GAME and G.GAME.blind
  if not (enc and enc.boss and not enc.ended and not enc.recorded and blind and blind.config
      and blind.config.blind and blind.config.blind.key == enc.key) then return nil end
  local m = Mem.data()
  if not m then return nil end
  m.nemesis = enc.key
  m.broken[enc.key] = nil
  if not enc.nemesis then enc.fake_nemesis = true end -- already the real nemesis: nothing was faked
  enc.nemesis = true
  Mem.save()
  Mem.present(blind)
  return enc.key
end

return Mem

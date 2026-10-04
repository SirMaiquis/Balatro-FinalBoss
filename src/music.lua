--- Showdown music. A track bids only while a full-tier encounter is active and it is the
--- encounter's chosen track; otherwise nothing bids and vanilla music plays.
local M = {}
M.BID = 10
M.FILES = {'showdown.ogg'} -- Adam Isiah's orchestral cover of the main theme, used with permission
M.POOL = {}

function M.bid(sound)
  if not FinalBoss.config.music then return nil end
  local st = G.GAME and G.GAME.FinalBoss
  if st and st.disabled_for_run then return nil end
  local enc = st and st.encounter
  if enc and enc.tier == 'full' and not enc.ended and enc.track == sound.key then return M.BID end
  return nil
end

for i, file in ipairs(M.FILES) do
  SMODS.Sound{
    key = 'music_showdown_' .. i, -- smods requires "music" in the key of music tracks
    path = file,
    volume = 0.6,
    pitch = 1,
    select_music_track = function(self) return M.bid(self) end,
  }
  M.POOL[#M.POOL + 1] = FinalBoss.mod.prefix .. '_music_showdown_' .. i
end

--- Silent companion track for the duck (see M.duck): a 10-minute silent stream, longer than any
--- music track, so its source is always playing when the sound thread's MODULATE looks for it.
--- It has no select_music_track, so it never bids; its key has "music" so smods streams it and the
--- thread starts it with the other music sources.
SMODS.Sound{
  key = 'music_duck',
  path = 'duck.ogg',
  volume = 1,
  pitch = 1,
}
M.DUCK_TRACK = FinalBoss.mod.prefix .. '_music_duck'
M.duck_gen = 0

--- Choose the encounter's track: the entry's own music (string or list) or the shared pool.
function M.pick_track(entry)
  local pool = M.POOL
  if type(entry.music) == 'string' then pool = {entry.music}
  elseif type(entry.music) == 'table' then pool = entry.music end
  if #pool == 0 then return nil end
  local st = FinalBoss.util.state()
  local idx = FinalBoss.logic.pick_variant(#pool, st.last_track_idx, math.random)
  st.last_track_idx = idx
  return pool[idx]
end

--- Phase transformation (1.1): duck the FinalBoss track for `seconds`. Per-track volume is fixed in
--- the sound thread (smods game_object.lua:658 pushes `vol` once), so vanilla's G.video_soundtrack
--- override (first term of desired_track, misc_functions.lua:725) points at the silent companion
--- track: every other music source eases toward 0 with the thread's own smoothing (sound_manager.lua
--- SET_SFX), and the companion eases up to its own silence. The companion must be a real, playing
--- source: smods' patched MODULATE (lovely/sound.toml, "fix looping") calls RESTART_MUSIC on every
--- tick when the desired track has no playing source, which an unknown name would trigger.
--- Only while the encounter's FinalBoss track plays; never when another override is active.
function M.duck(seconds)
  if not FinalBoss.config.music then return end
  if not (SMODS.Sounds and SMODS.Sounds[M.DUCK_TRACK]) then return end
  local st = G.GAME and G.GAME.FinalBoss
  local enc = st and st.encounter
  if not (enc and enc.track and not enc.ended) or st.disabled_for_run then return end -- as M.bid
  if G.video_soundtrack and G.video_soundtrack ~= M.DUCK_TRACK then return end
  G.video_soundtrack = M.DUCK_TRACK
  M.duck_gen = M.duck_gen + 1
  local gen = M.duck_gen
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = seconds, timer = 'REAL', blocking = false,
    blockable = false, pause_force = true, func = function()
      if M.duck_gen == gen then FinalBoss.util.guard('music_unduck', M.unduck) end
      return true
    end}))
end

--- Back to full volume (the arena keeps its stage pitch). Only clears our own override; safe when
--- not ducking (Dir.reset_stage calls it: quit/restart clear the event queue and delete the timer).
function M.unduck()
  if G.video_soundtrack == M.DUCK_TRACK then G.video_soundtrack = nil end
end

return M

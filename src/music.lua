--- Showdown music. A track bids only while a full-tier encounter is active and it is the
--- encounter's chosen track; otherwise nothing bids and vanilla music plays.
local M = {}
M.BID = 10
M.FILES = {'showdown_1.ogg', 'showdown_2.ogg'}
M.POOL = {}

function M.bid(sound)
  if not FinalBoss.config.music then return nil end
  local st = G.GAME and G.GAME.FinalBoss
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

--- Phase-based music changes are an M3 feature; M1 only records the phase.
function M.set_phase(n)
  local enc = (G.GAME and G.GAME.FinalBoss or {}).encounter
  if enc then enc.phase = n end
end

return M

-- logic.lua: the near-miss loss moments (1.4): which one, the longer laugh, when the game-over cue fires.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local function logic()
  package.loaded['src.logic'] = nil
  return require('src.logic')
end

T['near_miss_moment: 95% and up, below the requirement'] = function()
  local L = logic()
  eq(L.NEAR_MISS, 0.95)
  eq(L.near_miss_moment(950, 1000), 'near_miss', 'exactly 95%')
  eq(L.near_miss_moment(949, 1000), nil, '94.9%')
  eq(L.near_miss_moment(960, 1000), 'near_miss', '96%')
  eq(L.near_miss_moment(998, 1000), 'near_miss', '2 short')
  eq(L.near_miss_moment(100, 1000), nil, 'far off')
  eq(L.near_miss_moment(0, 1000), nil, 'nothing scored')
end

T['near_miss_moment: exactly one chip short is one_chip'] = function()
  local L = logic()
  eq(L.near_miss_moment(999, 1000), 'one_chip')
  eq(L.near_miss_moment(9, 10), 'one_chip', 'below 95% still: one chip is one chip')
  eq(L.near_miss_moment(999.5, 1000), 'near_miss', 'half a chip short')
end

T['near_miss_moment: a win, or unreadable numbers, is nothing'] = function()
  local L = logic()
  eq(L.near_miss_moment(1000, 1000), nil, 'exactly the requirement wins')
  eq(L.near_miss_moment(1200, 1000), nil, 'over')
  local nan = 0 / 0
  eq(L.near_miss_moment(nil, 1000), nil); eq(L.near_miss_moment(950, nil), nil)
  eq(L.near_miss_moment(nan, 1000), nil); eq(L.near_miss_moment(950, nan), nil)
  eq(L.near_miss_moment('999', 1000), nil, 'strings are not read here')
  eq(L.near_miss_moment(950, 0), nil); eq(L.near_miss_moment(-1, 0), nil)
  eq(L.near_miss_moment(950, math.huge), nil, 'infinite requirement')
  eq(L.near_miss_moment(math.huge, math.huge), nil)
  eq(L.near_miss_moment(-math.huge, 1000), nil)
end

T['near_miss beats: one_chip laughs longer than the plain laugh'] = function()
  local L = logic()
  eq(L.near_miss_beats('near_miss'), L.LAUGH.beats)
  assert(L.near_miss_beats('one_chip') > L.LAUGH.beats, 'one_chip laughs longer')
  eq(L.near_miss_beats('other'), L.LAUGH.beats)
end

T['laugh with more beats: longer, same cadence, pitch still falls to pitch_lo'] = function()
  local L = logic()
  local A = L.LAUGH
  eq(L.laugh_duration(), A.beats * A.step + A.shake, 'default unchanged')
  eq(L.laugh_duration(10), 10 * A.step + A.shake)
  eq(L.laugh_pitch(0, 10), A.pitch_hi)
  eq(L.laugh_pitch(9, 10), A.pitch_lo)
  assert(L.laugh_pitch(5, 10) < L.laugh_pitch(4, 10), 'falls every beat')
  eq(L.laugh_pitch(A.beats - 1), A.pitch_lo, 'default unchanged')
  -- motion: still hopping past the plain laugh's end, zero after the long one's
  local hop = L.laugh_motion((A.beats + 0.5) * A.step, 10)
  assert(hop > 0, 'hops on beat ' .. A.beats)
  local h, t, s = L.laugh_motion(L.laugh_duration(10), 10)
  eq(h, 0); eq(t, 0); eq(s, 0)
  local _, _, shake = L.laugh_motion(10 * A.step + 0.01, 10)
  assert(shake > 0, 'closing shake')
  eq(L.laugh_motion((A.beats + 0.5) * A.step), 0, 'the plain laugh is over by then')
end

T['gloat_cue_due: a beat after Jimbo finishes'] = function()
  local L = logic()
  local C = L.GLOAT_CUE
  eq(L.gloat_cue_due{elapsed = 1, started = false}, false, 'waiting for Jimbo')
  eq(L.gloat_cue_due{elapsed = 3, started = true}, false, 'Jimbo talking')
  eq(L.gloat_cue_due{elapsed = 3.3, started = true, done_for = C.beat / 2}, false, 'just finished')
  eq(L.gloat_cue_due{elapsed = 3.7, started = true, done_for = C.beat}, true, 'a beat later')
end

T['gloat_cue_due: no Jimbo (past the win ante), or Jimbo never stops: fallbacks'] = function()
  local L = logic()
  local C = L.GLOAT_CUE
  eq(L.gloat_cue_due{elapsed = C.late - 0.01, started = false}, false)
  eq(L.gloat_cue_due{elapsed = C.late, started = false}, true, 'no Jimbo by late')
  eq(L.gloat_cue_due{elapsed = C.late + 1, started = true}, false, 'Jimbo came: wait for him')
  eq(L.gloat_cue_due{elapsed = C.max, started = true}, true, 'cap')
  eq(L.gloat_cue_due{elapsed = nil, started = false}, false, 'no clock')
  -- the cue never lands before the director's 3 s tail hide (Dir.on_round_end) could cut its line
  assert(C.late >= 3, 'late fallback after the tail hide')
end

T['near_miss and one_chip: outside moments, 3 personality variants, not forced'] = function()
  local L = logic()
  for _, m in ipairs({'near_miss', 'one_chip'}) do
    local outside, new, listed = false, false, false
    for _, o in ipairs(L.OUTSIDE_MOMENTS) do outside = outside or o == m end
    for _, o in ipairs(L.NEW_MOMENTS_1_4) do new = new or o == m end
    for _, o in ipairs(L.PERSONALITY_MOMENTS) do listed = listed or o == m end
    eq(outside, true, m .. ' outside'); eq(new, true, m .. ' new'); eq(listed, true, m .. ' personality')
    eq(L.personality_variants(m), 3, m)
    eq(L.FORCED_MOMENTS[m], nil, m .. ' not forced')
  end
end

return T

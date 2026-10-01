local logic = require('src.logic')
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

T['hp_fraction: no score is full health'] = function() eq(logic.hp_fraction(0, 100), 1) end
T['hp_fraction: half'] = function() eq(logic.hp_fraction(50, 100), 0.5) end
T['hp_fraction: overkill clamps to 0'] = function() eq(logic.hp_fraction(150, 100), 0) end
T['hp_fraction: zero or missing requirement is 0'] = function()
  eq(logic.hp_fraction(10, 0), 0)
  eq(logic.hp_fraction(10, nil), 0)
end

T['wound_stage: thresholds at 50% and 25%'] = function()
  eq(logic.wound_stage(1), 0)
  eq(logic.wound_stage(0.5), 0)
  eq(logic.wound_stage(0.49), 1)
  eq(logic.wound_stage(0.25), 1)
  eq(logic.wound_stage(0.24), 2)
  eq(logic.wound_stage(0), 2)
end

T['hit_size: weak below 5%'] = function()
  eq(logic.hit_size(4, 100), 'weak')
  eq(logic.hit_size(5, 100), 'normal')
end
T['hit_size: big at 30% or more'] = function()
  eq(logic.hit_size(30, 100), 'big')
  eq(logic.hit_size(29, 100), 'normal')
end
T['hit_size: zero requirement is normal'] = function() eq(logic.hit_size(10, 0), 'normal') end

T['arena_params: stage 0'] = function()
  local p = logic.arena_params(0)
  eq(p.black_mix, 0.45); eq(p.contrast, 3.0); eq(p.spin_mult, 1.0); eq(p.pitch, 1.0)
end
T['arena_params: stage 2 is the final stretch'] = function()
  local p = logic.arena_params(2)
  eq(p.black_mix, 0.75); eq(p.contrast, 4.5); eq(p.spin_mult, 2.0); eq(p.pitch, 1.06)
end
T['arena_params: unknown stage falls back to stage 0'] = function()
  eq(logic.arena_params(7), logic.arena_params(0))
  eq(logic.arena_params(nil), logic.arena_params(0))
end
T['arena_params: darker and faster each stage'] = function()
  local a, b, c = logic.arena_params(0), logic.arena_params(1), logic.arena_params(2)
  assert(a.black_mix < b.black_mix and b.black_mix < c.black_mix, 'black_mix must increase')
  assert(a.spin_mult < b.spin_mult and b.spin_mult < c.spin_mult, 'spin must increase')
end

T['score_landed: positive hand waits for the round score to tick up'] = function()
  eq(logic.score_landed(100, 100, 50, 'Flush', 0.5), false)
  eq(logic.score_landed(100, 101, 50, 'Flush', 0.5), true)
  eq(logic.score_landed(100, 150, 50, '', 0.5), true)
end
T['score_landed: positive hand ignores the hand name'] = function()
  eq(logic.score_landed(100, 100, 50, '', 0.5), false)
end
T['score_landed: zero or negative hand waits for the hand name to clear'] = function()
  eq(logic.score_landed(100, 100, 0, 'Pair', 0.5), false)
  eq(logic.score_landed(100, 100, 0, '', 0.5), true)
  eq(logic.score_landed(100, 100, -5, '', 0.5), true)
  eq(logic.score_landed(100, 100, 0, nil, 0.5), false)
end
T['score_landed: long scoring sequences are not cut short'] = function()
  eq(logic.score_landed(100, 100, 50, 'Flush', 6), false)
  eq(logic.score_landed(100, 100, 50, 'Flush', 29.99), false)
end
T['score_landed: last-resort wall clock at 30 seconds'] = function()
  eq(logic.score_landed(100, 100, 50, 'Flush', 30), true)
  eq(logic.score_landed(100, 100, 0, 'Pair', 30), true)
end
T['score_landed: queued completion always lands'] = function()
  eq(logic.score_landed(100, 100, 50, 'Flush', 0.5, true), true)
  eq(logic.score_landed(100, 100, 0, 'Pair', 0.5, true), true)
  -- Talisman: a score converted to inf never satisfies chips > start
  eq(logic.score_landed(math.huge, math.huge, math.huge, 'Flush', 0.5, false), false)
  eq(logic.score_landed(math.huge, math.huge, math.huge, 'Flush', 0.5, true), true)
end
T['score_landed: missing numbers are treated as zero'] = function()
  eq(logic.score_landed(nil, nil, nil, '', nil), true)
  eq(logic.score_landed(nil, nil, nil, 'Pair', nil), false)
end

return T

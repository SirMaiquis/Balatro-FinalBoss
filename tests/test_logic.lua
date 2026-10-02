local logic = require('src.logic')
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

T['pick_variant: zero or nil count returns nil'] = function()
  eq(logic.pick_variant(0, nil, math.random), nil)
  eq(logic.pick_variant(nil, nil, math.random), nil)
end

T['pick_variant: single variant is always 1'] = function()
  eq(logic.pick_variant(1, 1, math.random), 1)
  eq(logic.pick_variant(1, nil, math.random), 1)
end

T['pick_variant: without last draws from the full range'] = function()
  local v = logic.pick_variant(3, nil, function(n) eq(n, 3, 'range'); return 3 end)
  eq(v, 3)
end

T['pick_variant: with last draws from count-1 and skips last'] = function()
  eq(logic.pick_variant(3, 2, function(n) eq(n, 2, 'range'); return 2 end), 3)
  eq(logic.pick_variant(3, 2, function() return 1 end), 1)
end

T['pick_variant: out-of-range last is treated as no last'] = function()
  eq(logic.pick_variant(3, 7, function(n) eq(n, 3, 'range'); return 2 end), 2)
end

T['pick_variant: never repeats over many draws'] = function()
  local last
  for _ = 1, 300 do
    local v = logic.pick_variant(4, last, math.random)
    assert(v >= 1 and v <= 4, 'out of range: ' .. tostring(v))
    if last then assert(v ~= last, 'repeated ' .. v) end
    last = v
  end
end

T['is_vanilla_showdown: multiples of win ante only'] = function()
  eq(logic.is_vanilla_showdown(8, 8), true)
  eq(logic.is_vanilla_showdown(16, 8), true)
  eq(logic.is_vanilla_showdown(7, 8), false)
  eq(logic.is_vanilla_showdown(0, 8), false)
end

T['is_extra_showdown: start and frequency'] = function()
  eq(logic.is_extra_showdown(4, 4, 2), true)
  eq(logic.is_extra_showdown(5, 4, 2), false)
  eq(logic.is_extra_showdown(6, 4, 2), true)
  eq(logic.is_extra_showdown(3, 4, 2), false)
  eq(logic.is_extra_showdown(1, 1, 1), true)
end

T['is_extra_showdown: invalid every is false'] = function()
  eq(logic.is_extra_showdown(4, 4, 0), false)
  eq(logic.is_extra_showdown(4, 4, nil), false)
end

T['preview_showdowns: disabled shows vanilla only'] = function()
  eq(table.concat(logic.preview_showdowns(false, 2, 2, 8, 3), ','), '8,16,24')
end

T['preview_showdowns: custom schedule merges with vanilla'] = function()
  eq(table.concat(logic.preview_showdowns(true, 4, 2, 8, 5), ','), '4,6,8,10,12')
  eq(table.concat(logic.preview_showdowns(true, 3, 4, 8, 4), ','), '3,7,8,11')
end

T['preview_showdowns: every ante'] = function()
  eq(table.concat(logic.preview_showdowns(true, 1, 1, 8, 5), ','), '1,2,3,4,5')
end

T['preview_showdowns: defaults equal vanilla'] = function()
  eq(table.concat(logic.preview_showdowns(true, 8, 8, 8, 3), ','), '8,16,24')
end

-- Lit antes of a showdown_track, as "a,b,c" (and checks the track covers exactly 1..last).
local function lit(track, last)
  eq(#track, last, 'track length')
  local out = {}
  for a = 1, last do
    eq(type(track[a]), 'boolean', 'ante ' .. a)
    if track[a] then out[#out + 1] = a end
  end
  return table.concat(out, ',')
end

T['showdown_track: schedule off lights the vanilla showdowns only'] = function()
  eq(lit(logic.showdown_track(false, 2, 2, 8, 16), 16), '8,16')
  eq(lit(logic.showdown_track(false, 2, 2, 6, 16), 16), '6,12')
end

T['showdown_track: custom schedule merges with vanilla, capped at last'] = function()
  eq(lit(logic.showdown_track(true, 4, 4, 8, 16), 16), '4,8,12,16')
  eq(lit(logic.showdown_track(true, 3, 4, 8, 16), 16), '3,7,8,11,15,16')
  eq(lit(logic.showdown_track(true, 5, 8, 8, 16), 16), '5,8,13,16')
end

T['showdown_track: every ante lights the whole track'] = function()
  eq(lit(logic.showdown_track(true, 1, 1, 8, 16), 16), '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16')
end

T['showdown_track: defaults equal vanilla'] = function()
  eq(lit(logic.showdown_track(true, 8, 8, 8, 16), 16), '8,16')
end

T['line_duration: slow normal fast, unknown is normal'] = function()
  eq(logic.line_duration(1), 6)
  eq(logic.line_duration(2), 4)
  eq(logic.line_duration(3), 2.5)
  eq(logic.line_duration(9), 4)
end

T['intro_sequence: per tier'] = function()
  eq(table.concat(logic.intro_sequence('full'), ','), 'opener,name,intro,closer')
  eq(table.concat(logic.intro_sequence('light'), ','), 'intro')
  eq(#logic.intro_sequence('none'), 0)
end

return T

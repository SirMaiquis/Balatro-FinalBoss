local logic = require('src.logic')
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

T['phase_cross: crossing 50% enters phase II'] = function() eq(logic.phase_cross(0, 1), 2) end
T['phase_cross: crossing 25% from phase II enters phase III'] = function() eq(logic.phase_cross(1, 2), 3) end
T['phase_cross: one hand through both thresholds returns III once'] = function() eq(logic.phase_cross(0, 2), 3) end
T['phase_cross: no crossing returns nil'] = function()
  eq(logic.phase_cross(0, 0), nil); eq(logic.phase_cross(1, 1), nil); eq(logic.phase_cross(2, 2), nil)
end
T['phase_cross: never goes back (a heal does not undo a phase)'] = function()
  eq(logic.phase_cross(2, 1), nil); eq(logic.phase_cross(1, 0), nil)
end
T['phase_cross: missing stages count as 0'] = function()
  eq(logic.phase_cross(nil, 1), 2); eq(logic.phase_cross(nil, nil), nil)
end

T['should_transform: cinematic, crossed, not the defeat hand, not the last hand'] = function()
  eq(logic.should_transform{cinematic = true, moment = 'big_hand', target = 2, hands_left = 3}, 2)
  eq(logic.should_transform{cinematic = true, moment = nil, target = 3, hands_left = 1}, 3)
  eq(logic.should_transform{cinematic = false, moment = nil, target = 2, hands_left = 3}, nil, 'no cinematic')
  eq(logic.should_transform{cinematic = true, moment = 'defeat', target = 3, hands_left = 3}, nil, 'defeat hand')
  eq(logic.should_transform{cinematic = true, moment = 'last_hand', target = 2, hands_left = 0}, nil, 'last hand')
  eq(logic.should_transform{cinematic = true, moment = nil, target = nil, hands_left = 3}, nil, 'no crossing')
end

T['twist_for: each final boss twist and its strength in phases II and III'] = function()
  eq(logic.twist_for('bl_final_acorn', 2).once, 'acorn_shuffle')
  eq(logic.twist_for('bl_final_acorn', 3).once, 'acorn_shuffle')
  eq(logic.twist_for('bl_final_leaf', 2).draw, 'leaf_debuff')
  eq(logic.twist_for('bl_final_leaf', 2).count, 1)
  eq(logic.twist_for('bl_final_leaf', 3).count, 2)
  eq(logic.twist_for('bl_final_vessel', 2).once, 'vessel_heal')
  eq(logic.twist_for('bl_final_vessel', 2).ratio, 0.10)
  eq(logic.twist_for('bl_final_vessel', 3).ratio, 0.10)
  eq(logic.twist_for('bl_final_heart', 2).draw, 'heart_extra')
  eq(logic.twist_for('bl_final_heart', 2).count, 1)
  eq(logic.twist_for('bl_final_heart', 2).beam, nil)
  eq(logic.twist_for('bl_final_heart', 3).beam, true)
  eq(logic.twist_for('bl_final_bell', 2).draw, 'bell_force')
  eq(logic.twist_for('bl_final_bell', 2).count, 2)
  eq(logic.twist_for('bl_final_bell', 3).count, 2)
end

T['twist_for: none in phase I, for regular or modded bosses'] = function()
  eq(logic.twist_for('bl_final_heart', 1), nil)
  eq(logic.twist_for('bl_hook', 2), nil)
  eq(logic.twist_for('bl_mymod_final', 3), nil)
  eq(logic.twist_for(nil, 2), nil)
end

T['sample: up to n distinct elements, input untouched'] = function()
  local list = {'a', 'b', 'c', 'd'}
  local seq, i = {4, 1}, 0
  local function rand(n) i = i + 1; return math.min(n, seq[i] or 1) end
  local out = logic.sample(list, 2, rand)
  eq(#out, 2); eq(out[1], 'd'); eq(out[2], 'a'); eq(#list, 4, 'input untouched')
  eq(#logic.sample(list, 10, math.random), 4, 'never more than the list')
  eq(#logic.sample(list, 0, math.random), 0)
  eq(#logic.sample({}, 2, math.random), 0)
  eq(#logic.sample(nil, 2, math.random), 0)
end

T['shuffle: a permutation, in place'] = function()
  local list = {1, 2, 3, 4, 5}
  eq(logic.shuffle(list, math.random), list, 'in place')
  eq(#list, 5)
  local seen = {}
  for _, v in ipairs(list) do seen[v] = true end
  for v = 1, 5 do assert(seen[v], 'lost ' .. v) end
end

T['stance: phase II roams faster with a faint aura, III a strong aura'] = function()
  eq(logic.stance(1).roam, 1); eq(logic.stance(1).aura, 0)
  assert(logic.stance(2).roam < 1, 'phase II roams faster'); eq(logic.stance(2).aura, 1)
  eq(logic.stance(3).aura, 2)
  eq(logic.stance(nil), logic.stance(1)); eq(logic.stance(7), logic.stance(1))
end

T['phase_marker: II and III, nothing in phase I'] = function()
  eq(logic.phase_marker(1), ''); eq(logic.phase_marker(2), 'II'); eq(logic.phase_marker(3), 'III')
  eq(logic.phase_marker(nil), '')
end

T['roar_scale: 1 outside the roar, peak in the middle'] = function()
  local R = logic.ROAR
  eq(logic.roar_scale(-0.1, 0.5), 1)
  eq(logic.roar_scale(0.5, 0.5), 1)
  eq(logic.roar_scale(nil, 0.5), 1)
  local peak = logic.roar_scale(0.25, 0.5)
  assert(math.abs(peak - (1 + R.grow)) < 1e-9, 'peak ' .. tostring(peak))
  assert(logic.roar_scale(0.1, 0.5) > 1 and logic.roar_scale(0.1, 0.5) < peak, 'grows toward the peak')
end

return T

-- The boss template in examples/ stays a working starting point for mod authors.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local BLIND = 'bl_mymod_my_boss'

local function template_loc()
  local f = assert(loadfile('examples/boss_template/localization/en-us.lua'))
  return f()
end

T['template: boss.lua parses'] = function()
  assert(loadfile('examples/boss_template/boss.lua'), 'boss.lua must parse')
end

T['template: misc sits next to descriptions, with the blind text and the quips'] = function()
  local loc = template_loc()
  assert(loc.misc and loc.misc.quips, 'misc.quips at the top level')
  assert(loc.descriptions and loc.descriptions.Blind and loc.descriptions.Blind[BLIND], 'the blind text')
  eq(loc.descriptions.misc, nil, 'misc is not inside descriptions')
end

T['template: every quip uses the full blind key and fits the bubble'] = function()
  local n = 0
  for key, lines in pairs(template_loc().misc.quips) do
    n = n + 1
    assert(key:sub(1, #('fb_' .. BLIND .. '_')) == 'fb_' .. BLIND .. '_', key .. ': full blind key')
    assert(key:match('_%d+$'), key .. ': ends with a variant number')
    assert(type(lines) == 'table' and #lines >= 1 and #lines <= 2, key .. ': 1 or 2 strings')
    for _, s in ipairs(lines) do assert(#s <= 24, key .. ': "' .. s .. '" is over 24 characters') end
  end
  assert(n >= 10, 'the template covers the main moments')
end

T['template: the lines its line hook returns exist'] = function()
  local quips = template_loc().misc.quips
  local src = assert(io.open('examples/boss_template/boss.lua')):read('*a')
  local names = 0
  for name in src:gmatch("return '([%w_]+)'") do
    names = names + 1
    assert(quips['fb_' .. BLIND .. '_' .. name .. '_1'], name .. ' has a line')
  end
  assert(names > 0, 'the template shows the line hook')
end

return T

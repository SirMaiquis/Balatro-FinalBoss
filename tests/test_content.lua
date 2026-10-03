local T = {}

local BOSS_MOMENTS = {'name', 'intro', 'big_hand', 'close', 'last_hand', 'disabled', 'defeat', 'gloat',
  'interrupted'}
local GENERIC_MOMENTS = {'name', 'intro', 'big_hand', 'close', 'last_hand', 'disabled', 'defeat', 'gloat',
  'interrupted'}
local MAX_LINE = 24

local function load()
  package.loaded['localization.default'] = nil
  _G.FinalBoss = nil
  package.loaded['src.encounters.vanilla'] = nil
  return require('localization.default').misc.quips, require('src.encounters.vanilla')
end

local function visible(line) return (line:gsub('{[^}]*}', '')) end

T['every vanilla boss has every moment'] = function()
  local quips, bosses = load()
  local missing = {}
  for blind in pairs(bosses) do
    for _, m in ipairs(BOSS_MOMENTS) do
      if not quips['fb_' .. blind .. '_' .. m .. '_1'] then missing[#missing + 1] = blind .. '.' .. m end
    end
    if not quips['fb_' .. blind .. '_intro_2'] then missing[#missing + 1] = blind .. '.intro_2' end
  end
  table.sort(missing)
  assert(#missing == 0, 'missing: ' .. table.concat(missing, ', '))
end

T['shared and generic sets have 3 variants'] = function()
  local quips = load()
  local missing = {}
  local prefixes = {'fb_opener', 'fb_closer'}
  for _, m in ipairs(GENERIC_MOMENTS) do prefixes[#prefixes + 1] = 'fb_generic_' .. m end
  for _, p in ipairs(prefixes) do
    for i = 1, 3 do if not quips[p .. '_' .. i] then missing[#missing + 1] = p .. '_' .. i end end
  end
  assert(#missing == 0, 'missing: ' .. table.concat(missing, ', '))
end

T['every fb quip is 1-2 short ascii lines'] = function()
  local quips = load()
  local bad = {}
  for key, lines in pairs(quips) do
    -- fb_cfg_header is config menu text (the header card), not a dialogue bubble
    if key:sub(1, 3) == 'fb_' and key ~= 'fb_cfg_header' then
      if type(lines) ~= 'table' or #lines < 1 or #lines > 2 then bad[#bad + 1] = key .. ' (line count)' end
      for _, line in ipairs(type(lines) == 'table' and lines or {}) do
        if #visible(line) > MAX_LINE then bad[#bad + 1] = key .. ' (too long: ' .. line .. ')' end
        if line:find('[\128-\255]') then bad[#bad + 1] = key .. ' (non-ascii)' end
      end
    end
  end
  table.sort(bad)
  assert(#bad == 0, table.concat(bad, '; '))
end

T['gloat lines have no placeholders'] = function()
  local quips = load()
  for key, lines in pairs(quips) do
    if key:find('_gloat_') then
      for _, line in ipairs(lines) do assert(not line:find('#'), key .. ' has a placeholder') end
    end
  end
end

T['gloat lines are only the line: no Name: header, no quotes'] = function()
  local quips = load()
  for key, lines in pairs(quips) do
    if key:find('gloat') then
      assert(not lines[1]:find(':%s*$'), key .. ' starts with a header line')
      local text = table.concat(lines, ' ')
      assert(not (text:sub(1, 1) == '"' and text:sub(-1) == '"'), key .. ' is wrapped in quotes')
    end
  end
end

T['no v1 keys remain'] = function()
  local quips = load()
  for key in pairs(quips) do assert(key:sub(1, 3) ~= 'ml_', 'leftover v1 key ' .. key) end
end

T['final bosses and the generic set have phase lines'] = function()
  local quips = load()
  local missing = {}
  for _, b in ipairs({'bl_final_acorn', 'bl_final_leaf', 'bl_final_vessel', 'bl_final_heart', 'bl_final_bell', 'generic'}) do
    for _, m in ipairs({'phase2', 'phase3'}) do
      local key = 'fb_' .. b .. '_' .. m .. '_1'
      if not quips[key] then missing[#missing + 1] = key end
    end
  end
  assert(#missing == 0, 'missing: ' .. table.concat(missing, ', '))
end

return T

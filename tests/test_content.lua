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

T['the generic set has 3 variants'] = function()
  local quips = load()
  local missing = {}
  for _, m in ipairs(GENERIC_MOMENTS) do
    local p = 'fb_generic_' .. m
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

T['every vanilla boss and the generic set have rematch lines'] = function()
  local quips, bosses = load()
  local missing = {}
  for blind in pairs(bosses) do
    for _, m in ipairs({'rematch_won', 'rematch_lost'}) do
      if not quips['fb_' .. blind .. '_' .. m .. '_1'] then missing[#missing + 1] = blind .. '.' .. m end
    end
  end
  for _, m in ipairs({'rematch_won', 'rematch_lost'}) do
    for i = 1, 3 do
      if not quips['fb_generic_' .. m .. '_' .. i] then missing[#missing + 1] = 'generic.' .. m .. '_' .. i end
    end
  end
  table.sort(missing)
  assert(#missing == 0, 'missing: ' .. table.concat(missing, ', '))
end

T['nemesis lines: three intros and three defeats, shared, with the boss name'] = function()
  local quips = load()
  for _, m in ipairs({'nemesis_intro', 'nemesis_defeat'}) do
    for i = 1, 3 do assert(quips['fb_' .. m .. '_' .. i], 'missing fb_' .. m .. '_' .. i) end
  end
  local named = 0
  for _, m in ipairs({'nemesis_intro', 'nemesis_defeat'}) do
    for i = 1, 3 do
      if table.concat(quips['fb_' .. m .. '_' .. i], ' '):find('#1#', 1, true) then named = named + 1 end
    end
  end
  assert(named >= 2, 'nemesis lines should use the boss name (#1#)')
end

T['nemesis title and banner strings exist'] = function()
  package.loaded['localization.default'] = nil
  local dict = require('localization.default').misc.dictionary
  assert(dict.fb_nemesis_title and dict.fb_nemesis_defeated, 'fb_nemesis_title / fb_nemesis_defeated')
  assert(dict.fb_cfg_dev_mode:find('F9', 1, true), 'dev label lists F9')
end

T['every memory intro plan resolves a line for each step (light nemesis included)'] = function()
  local quips, bosses = load()
  package.loaded['src.logic'] = nil
  local logic = require('src.logic')
  local function count_of(prefix)
    local n = 0
    while quips[prefix .. '_' .. (n + 1)] do n = n + 1 end
    return n
  end
  local missing = {}
  for blind in pairs(bosses) do
    for _, tier in ipairs({'full', 'light'}) do
      for _, a in ipairs({{nemesis = true}, {last = 'won', roll = 0}, {last = 'lost', roll = 0}}) do
        a.tier, a.memory = tier, true
        for _, m in ipairs(logic.intro_plan(a)) do
          if not logic.resolve_prefix(blind, m, count_of) then missing[#missing + 1] = blind .. '.' .. tier .. '.' .. m end
        end
      end
    end
  end
  table.sort(missing)
  assert(#missing == 0, 'no line for: ' .. table.concat(missing, ', '))
end

T['every achievement has a name and a description'] = function()
  package.loaded['localization.default'] = nil
  local misc = require('localization.default').misc
  local ids = require('src.logic').ACHIEVEMENTS
  assert(#ids == 10, 'ten achievements')
  for _, id in ipairs(ids) do
    local key = 'ach_FinalBoss_' .. id
    assert(misc.achievement_names and type(misc.achievement_names[key]) == 'string', 'name ' .. key)
    assert(misc.achievement_descriptions and type(misc.achievement_descriptions[key]) == 'string', 'description ' .. key)
  end
end

-- 1.2 key sets -----------------------------------------------------------------------------------

local NEW_BOSS_SETS = {intro = 3, big_hand = 3, gloat = 3, weak = 3, jab_counter = 1}

T['every vanilla boss has three intros, big hands, gloats and weak lines, and its counter line'] = function()
  local quips, bosses = load()
  local missing = {}
  for blind in pairs(bosses) do
    for m, n in pairs(NEW_BOSS_SETS) do
      for i = 1, n do
        local key = 'fb_' .. blind .. '_' .. m .. '_' .. i
        if not quips[key] then missing[#missing + 1] = key end
      end
    end
  end
  table.sort(missing)
  assert(#missing == 0, 'missing: ' .. table.concat(missing, ', '))
end

T['the generic set has three weak lines'] = function()
  local quips = load()
  for i = 1, 3 do assert(quips['fb_generic_weak_' .. i], 'missing fb_generic_weak_' .. i) end
end

T['every personality has every run moment'] = function()
  local quips = load()
  package.loaded['src.logic'] = nil
  local logic = require('src.logic')
  local missing = {}
  for _, p in ipairs(logic.PERSONALITIES) do
    for _, m in ipairs(logic.PERSONALITY_MOMENTS) do
      for i = 1, logic.personality_variants(m) do
        local key = 'fb_p_' .. p .. '_' .. m .. '_' .. i
        if not quips[key] then missing[#missing + 1] = key end
      end
    end
  end
  table.sort(missing)
  assert(#missing == 0, 'missing: ' .. table.concat(missing, ', '))
end

T['counter and famous lines name the joker (#2#); no other line does'] = function()
  local quips = load()
  local bad = {}
  for key, lines in pairs(quips) do
    local text = type(lines) == 'table' and table.concat(lines, ' ') or tostring(lines)
    local wants = key:find('_jab_counter_', 1, true) or key:find('_jab_famous_', 1, true)
    local has = text:find('#2#', 1, true)
    if wants and not has then bad[#bad + 1] = key .. ' needs #2#' end
    if has and not wants then bad[#bad + 1] = key .. ' must not use #2#' end
  end
  table.sort(bad)
  assert(#bad == 0, table.concat(bad, '; '))
end

T['every run moment and weak line resolves for every vanilla boss and a modded one'] = function()
  local quips, bosses = load()
  package.loaded['src.logic'] = nil
  local logic = require('src.logic')
  package.loaded['src.personality'] = nil
  local voice = require('src.personality').VANILLA
  local function count_of(prefix)
    local n = 0
    while quips[prefix .. '_' .. (n + 1)] do n = n + 1 end
    return n
  end
  local moments = {'weak'}
  for _, m in ipairs(logic.PERSONALITY_MOMENTS) do moments[#moments + 1] = m end
  local missing = {}
  local list = {bl_mymod_boss = logic.DEFAULT_PERSONALITY}
  for blind in pairs(bosses) do list[blind] = voice[blind] end
  for blind, p in pairs(list) do
    for _, m in ipairs(moments) do
      if not logic.resolve_prefix(blind, m, count_of, p) then missing[#missing + 1] = blind .. '.' .. m end
      if m == 'jab_counter' and not logic.resolve_prefix(blind, m, count_of, p, true) then
        missing[#missing + 1] = blind .. '.jab_counter (skip_boss)'
      end
    end
  end
  table.sort(missing)
  assert(#missing == 0, 'no line for: ' .. table.concat(missing, ', '))
end

-- 1.2 content rules ------------------------------------------------------------------------------------

-- Spelled-out swears (prefix match; a trailing '$' means the whole word) and the only censored words
-- the English lines may use (prefix match, so f***ing and a**hole pass).
local EN_SWEARS = {'fuck', 'shit', 'ass$', 'asses$', 'asshole', 'bitch', 'bastard', 'cunt', 'dick$',
  'cock$', 'piss', 'whore', 'slut', 'retard', 'fag'}
local EN_CENSORED = {'f***', 'sh*t', 'a**'}

local UTF8_PUNCT = {'¡', '¿', '«', '»', '…', '—', '–', '“', '”', '„', '‘', '’', '·'}

--- Lower-cased words of a line: letters, digits, '*' and UTF-8 bytes (vanilla's ASCII lower only).
local function words(line)
  local s = line:lower()
  for _, p in ipairs(UTF8_PUNCT) do s = s:gsub(p, ' ') end
  local out = {}
  for w in s:gmatch('[%w%*\128-\255]+') do out[#out + 1] = w end
  return out
end

local function swear_hit(word, entry)
  if entry:sub(-1) == '$' then return word == entry:sub(1, -2) end
  return word:sub(1, #entry) == entry
end

local function lines_of(v)
  if type(v) == 'table' then return v end
  return {tostring(v)}
end

T['English lines: no swear spelled out, only f***, sh*t and a** censored'] = function()
  local quips = load()
  local bad = {}
  for key, v in pairs(quips) do
    for _, line in ipairs(lines_of(v)) do
      for _, w in ipairs(words(line)) do
        for _, s in ipairs(EN_SWEARS) do
          if swear_hit(w, s) then bad[#bad + 1] = key .. ' (spelled out): ' .. line end
        end
        if w:find('*', 1, true) then
          local ok = false
          for _, c in ipairs(EN_CENSORED) do
            if w:sub(1, #c) == c then ok = true end
          end
          if not ok then bad[#bad + 1] = key .. ' (censored word not allowed): ' .. line end
        end
      end
    end
  end
  table.sort(bad)
  assert(#bad == 0, table.concat(bad, '; '))
end

--- True when any line of a quip carries a censored word (a letter next to '*').
local function censored(v)
  for _, line in ipairs(lines_of(v)) do
    for _, w in ipairs(words(line)) do
      if w:find('*', 1, true) then return true end
    end
  end
  return false
end

T['English gloat lines carry no censored swear (the game-over bubble has no bleep)'] = function()
  local quips = load()
  local bad = {}
  for key, v in pairs(quips) do
    if key:find('gloat', 1, true) and censored(v) then bad[#bad + 1] = key end
  end
  table.sort(bad)
  assert(#bad == 0, 'censored gloat: ' .. table.concat(bad, ', '))
end

T['English swearing density per personality'] = function()
  local quips = load()
  package.loaded['src.personality'] = nil
  local voice = require('src.personality').VANILLA
  local group = {}
  local bad = {}
  for blind, p in pairs(voice) do
    local prefix, n, total = 'fb_' .. blind .. '_', 0, 0
    for key, v in pairs(quips) do
      if key:sub(1, #prefix) == prefix then
        total = total + 1
        if censored(v) then n = n + 1 end
      end
    end
    group[p] = (group[p] or 0) + n
    if (p == 'bully' or p == 'chaos') and (n > 5 or n * 4 > total) then bad[#bad + 1] = blind .. ' ' .. n end
    if (p == 'smug' or p == 'royal') and n > 1 then bad[#bad + 1] = blind .. ' ' .. n end
  end
  for _, p in ipairs({'killer', 'venom'}) do
    if (group[p] or 0) > 1 then bad[#bad + 1] = p .. ' group ' .. group[p] end
  end
  table.sort(bad)
  assert(#bad == 0, 'too many censored lines: ' .. table.concat(bad, ', '))
end

return T

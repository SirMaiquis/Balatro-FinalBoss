-- Punchline text effects (1.4): the pure per-letter motion, colour and grawlix helpers in
-- src/logic.lua, and src/textfx.lua under stubs (registration keys, glyph cache, errors).
local logic = require('src.logic')
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local function ok(cond, msg)
  if not cond then error(msg or 'expected true', 2) end
end

local EXPECTED_KEYS = {'fb_rage', 'fb_fall', 'fb_sweet', 'fb_glitch', 'fb_royal', 'fb_flip', 'fb_drift',
  'fb_swell', 'fb_heartbeat', 'fb_toll', 'fb_tremble', 'fb_grawlix'}

local function in_list(list, v)
  for _, x in ipairs(list) do if x == v then return true end end
  return false
end

--- max |field| of letter_motion over t in [0, 1] (step 0.01) and letters 1..6.
local function max_abs(effect, field)
  local m = 0
  for i = 0, 100 do
    for index = 1, 6 do
      m = math.max(m, math.abs(logic.letter_motion(effect, i / 100, index, false, 6)[field]))
    end
  end
  return m
end

T['TEXT_EFFECTS: lists exactly the twelve fb_ effect keys'] = function()
  eq(#logic.TEXT_EFFECTS, #EXPECTED_KEYS, 'count')
  for _, k in ipairs(EXPECTED_KEYS) do ok(in_list(logic.TEXT_EFFECTS, k), 'missing ' .. k) end
end

T['letter_motion: every effect gives finite numbers at many t and indices'] = function()
  for _, e in ipairs(logic.TEXT_EFFECTS) do
    for _, t in ipairs({0, 0.013, 0.5, 1, 2.71, 17.3, 1234.567}) do
      for index = 1, 9 do
        local m = logic.letter_motion(e, t, index, false, 9)
        for _, f in ipairs({'dx', 'dy', 'r', 'scale'}) do
          ok(type(m[f]) == 'number' and m[f] == m[f] and math.abs(m[f]) < 10, e .. ' ' .. f .. ' not finite')
        end
        ok(m.scale > 0.5 and m.scale < 1.5, e .. ' scale out of range')
        ok(math.abs(m.dx) < 0.5 and math.abs(m.dy) < 0.5, e .. ' moves too far for the bubble')
      end
    end
  end
end

T['letter_motion: works without a letter count and for an unknown effect'] = function()
  local m = logic.letter_motion('fb_toll', 1.2, 3, false)
  ok(type(m.dy) == 'number', 'toll without count')
  local u = logic.letter_motion('nope', 1.2, 3, false)
  eq(u.dx, 0, 'dx'); eq(u.dy, 0, 'dy'); eq(u.r, 0, 'r'); eq(u.scale, 1, 'scale')
end

T['letter_motion: reduced motion is still for every effect'] = function()
  for _, e in ipairs(logic.TEXT_EFFECTS) do
    for _, t in ipairs({0, 0.3, 1.7, 99.1}) do
      for index = 1, 5 do
        local m = logic.letter_motion(e, t, index, true, 5)
        eq(m.dx, 0, e .. ' dx'); eq(m.dy, 0, e .. ' dy'); eq(m.r, 0, e .. ' r'); eq(m.scale, 1, e .. ' scale')
      end
    end
  end
end

T['letter_motion: fills and returns the out table when given'] = function()
  local out = {}
  local m = logic.letter_motion('fb_rage', 0.4, 2, false, 4, out)
  ok(m == out, 'same table')
end

T['letter_motion: every effect but royal actually moves'] = function()
  for _, e in ipairs(logic.TEXT_EFFECTS) do
    if e ~= 'fb_royal' then
      local moved = max_abs(e, 'dx') + max_abs(e, 'dy') + max_abs(e, 'r')
      for i = 0, 100 do moved = moved + math.abs(logic.letter_motion(e, i / 100, 1, false, 4).scale - 1) end
      -- glitch is still most of the time: sample a longer window for it
      if e == 'fb_glitch' then
        for i = 0, 600 do moved = moved + math.abs(logic.letter_motion(e, i / 100, 1, false, 4).dx) end
      end
      ok(moved > 0.01, e .. ' does not move')
    end
  end
end

T['letter_motion: rage shakes harder than tremble'] = function()
  ok(max_abs('fb_rage', 'dx') > max_abs('fb_tremble', 'dx'), 'rage amplitude > tremble amplitude')
end

T['letter_motion: heartbeat thumps above 1.1 and comes back to 1'] = function()
  local peak, low = 1, 2
  for i = 0, 200 do
    local s = logic.letter_motion('fb_heartbeat', i / 100, 1, false, 4).scale
    peak = math.max(peak, s); low = math.min(low, s)
  end
  ok(peak > 1.1, 'peak ' .. peak)
  eq(low, 1, 'rest scale')
end

T['letter_motion: fall sags downward, never up'] = function()
  local down = 0
  for i = 0, 300 do
    local m = logic.letter_motion('fb_fall', i / 100, 2, false, 4)
    ok(m.dy >= 0, 'fall moved up')
    down = math.max(down, m.dy)
  end
  ok(down > 0.1, 'fall sag ' .. down)
end

T['grawlix_symbol: cycles over time, fixed when reduced, always from GRAWLIX'] = function()
  eq(#logic.GRAWLIX, 7, 'symbol count')
  for index = 1, 8 do
    local seen, count = {}, 0
    for i = 0, 200 do
      local s = logic.grawlix_symbol(index, i / 100, false)
      ok(in_list(logic.GRAWLIX, s), 'symbol ' .. tostring(s))
      if not seen[s] then seen[s] = true; count = count + 1 end
    end
    ok(count > 1, 'does not cycle at index ' .. index)
    local fixed = logic.grawlix_symbol(index, 0, true)
    ok(in_list(logic.GRAWLIX, fixed), 'reduced symbol')
    for _, t in ipairs({0.1, 3.3, 77}) do eq(logic.grawlix_symbol(index, t, true), fixed, 'reduced is constant') end
  end
end

T['grawlix_symbol: neighbouring letters differ'] = function()
  for _, t in ipairs({0, 0.4, 2.2}) do
    for index = 1, 7 do
      ok(logic.grawlix_symbol(index, t, false) ~= logic.grawlix_symbol(index + 1, t, false), 'same symbol twice')
      ok(logic.grawlix_symbol(index, t, true) ~= logic.grawlix_symbol(index + 1, t, true), 'same reduced symbol')
    end
  end
end

T['glitch_glyph: real letters most of the time, scrambles sometimes, never when reduced'] = function()
  local real, scrambled = 0, 0
  for i = 0, 999 do
    for index = 1, 5 do
      local g = logic.glitch_glyph(index, i / 100, false)
      if g == nil then real = real + 1 else
        scrambled = scrambled + 1
        ok(in_list(logic.GLITCH_GLYPHS, g), 'glyph ' .. tostring(g))
      end
      eq(logic.glitch_glyph(index, i / 100, true), nil, 'reduced')
    end
  end
  ok(scrambled > 0, 'never scrambles')
  ok(real > 4 * scrambled, 'scrambles too often: ' .. scrambled .. ' of ' .. (real + scrambled))
end

T['effect_colour: pink, gold and red where given; nil keeps the line colour'] = function()
  eq(logic.effect_colour('fb_rage', 0.5), nil, 'rage')
  eq(logic.effect_colour('fb_tremble', 0.5), nil, 'tremble')
  eq(logic.effect_colour('nope', 0.5), nil, 'unknown')
  local pink = logic.effect_colour('fb_sweet', 0.5)
  ok(pink[1] > 0.8 and pink[3] > pink[2], 'sweet is pink')
  local red = logic.effect_colour('fb_grawlix', 0.5)
  ok(red[1] > 0.8 and red[2] < 0.5 and red[3] < 0.5, 'grawlix is red')
  local seen = {}
  for i = 0, 40 do
    local c = logic.effect_colour('fb_royal', i / 10, 1)
    ok(c[1] > 0.8 and c[2] > 0.6 and c[3] < c[2], 'royal is gold')
    eq(c[4], 1, 'alpha')
    seen[math.floor(c[3] * 100)] = true
  end
  local n = 0
  for _ in pairs(seen) do n = n + 1 end
  ok(n > 1, 'royal shimmers')
end

T['effect_colour: fills and returns the out table'] = function()
  local out = {}
  ok(logic.effect_colour('fb_sweet', 0, 1, out) == out, 'same table')
end

------------------------------------------------------------------------------------------------
-- src/textfx.lua under stubs

local function setup(opts)
  opts = opts or {}
  local registered, made = {}, {count = 0}
  _G.SMODS = {DynaTextEffects = {}}
  _G.SMODS.DynaTextEffect = function(t)
    registered[#registered + 1] = t
    if not (t.prefix_config and t.prefix_config.key == false) then t.key = 'FinalBoss_' .. t.key end
    _G.SMODS.DynaTextEffects[t.key] = t
    return t
  end
  _G.love = {graphics = {newText = function(font, s)
    made.count = made.count + 1
    return {font = font, text = s}
  end}}
  _G.G = {TIMERS = {REAL = opts.t or 0.37}, SETTINGS = {reduced_motion = opts.reduced or false}}
  local logs = {}
  _G.FinalBoss = {config = {fx = opts.fx ~= false}, logic = logic,
    util = {log = function(level, msg) logs[#logs + 1] = msg end}}
  package.loaded['src.textfx'] = nil
  local X = require('src.textfx')
  return X, registered, made, logs
end

local function dynatext(n)
  local font = {FONT = {}}
  local letters = {}
  for i = 1, n do
    letters[i] = {letter = {real = i}, char = 'a', r = 0, scale = 1, offset = {x = 0, y = 0}, dims = {x = 40, y = 60}}
  end
  return {font = font, strings = {{letters = letters}}, focused_string = 1, scale = 0.35}, letters
end

T['textfx: registers every key unprefixed with a func'] = function()
  local _, registered = setup()
  eq(#registered, #logic.TEXT_EFFECTS, 'registered count')
  for _, k in ipairs(logic.TEXT_EFFECTS) do
    local e = SMODS.DynaTextEffects[k]
    ok(e, 'missing ' .. k)
    eq(type(e.func), 'function', k .. ' func')
  end
end

T['textfx: rage moves the letter and leaves the colour alone'] = function()
  setup({t = 0.41})
  local d, letters = dynatext(4)
  SMODS.DynaTextEffects.fb_rage.func(d, 2, letters[2])
  ok(letters[2].offset.x ~= 0 or letters[2].offset.y ~= 0, 'moved')
  eq(letters[2].colour, nil, 'colour untouched')
end

T['textfx: reduced motion keeps letters still but keeps the colour'] = function()
  setup({reduced = true, t = 0.8})
  local d, letters = dynatext(3)
  SMODS.DynaTextEffects.fb_sweet.func(d, 1, letters[1])
  eq(letters[1].offset.x, 0, 'x'); eq(letters[1].offset.y, 0, 'y'); eq(letters[1].r, 0, 'r'); eq(letters[1].scale, 1, 's')
  ok(letters[1].colour and letters[1].colour[1] > 0.8, 'pink stays')
end

T['textfx: config.fx off also keeps letters still'] = function()
  setup({fx = false, t = 0.8})
  local d, letters = dynatext(3)
  SMODS.DynaTextEffects.fb_rage.func(d, 1, letters[1])
  eq(letters[1].offset.x, 0, 'x'); eq(letters[1].offset.y, 0, 'y')
end

T['textfx: grawlix swaps in cached symbol glyphs, never one per frame'] = function()
  local _, _, made = setup()
  local d, letters = dynatext(5)
  for frame = 0, 200 do
    G.TIMERS.REAL = frame / 60
    for k = 1, 5 do SMODS.DynaTextEffects.fb_grawlix.func(d, k, letters[k]) end
  end
  ok(made.count <= #logic.GRAWLIX, 'allocated ' .. made.count .. ' Text objects')
  for k = 1, 5 do
    ok(in_list(logic.GRAWLIX, letters[k].letter.text), 'letter shows a symbol')
    ok(letters[k].colour[1] > 0.8 and letters[k].colour[2] < 0.5, 'red')
  end
end

T['textfx: glitch settles back on the real letter glyph'] = function()
  local _, _, made = setup()
  local d, letters = dynatext(4)
  local real = letters[1].letter
  local swapped = false
  for frame = 0, 1200 do
    G.TIMERS.REAL = frame / 60
    SMODS.DynaTextEffects.fb_glitch.func(d, 1, letters[1])
    if letters[1].letter ~= real then swapped = true end
  end
  ok(swapped, 'never scrambled')
  ok(made.count <= #logic.GLITCH_GLYPHS, 'allocated ' .. made.count)
  -- find a calm moment and check the real glyph is back
  for frame = 0, 600 do
    G.TIMERS.REAL = frame / 60
    if logic.glitch_glyph(1, G.TIMERS.REAL, false) == nil then
      SMODS.DynaTextEffects.fb_glitch.func(d, 1, letters[1])
      ok(letters[1].letter == real, 'real glyph restored')
      return
    end
  end
  error('no calm moment found')
end

T['textfx: an error leaves the letter as is and is logged once'] = function()
  local _, _, _, logs = setup({t = 0.5})
  local d, letters = dynatext(2)
  FinalBoss.logic = {letter_motion = function() error('boom') end, effect_colour = logic.effect_colour,
    grawlix_symbol = logic.grawlix_symbol, glitch_glyph = logic.glitch_glyph}
  SMODS.DynaTextEffects.fb_rage.func(d, 1, letters[1])
  SMODS.DynaTextEffects.fb_rage.func(d, 2, letters[2])
  eq(letters[1].offset.x, 0, 'x'); eq(letters[1].offset.y, 0, 'y'); eq(letters[1].r, 0, 'r')
  eq(#logs, 1, 'logged once')
end

-- setup() replaces these globals; give every textfx test its own copy and put the originals back.
local function isolated(fn)
  return function()
    local saved = {SMODS = rawget(_G, 'SMODS'), G = rawget(_G, 'G'), love = rawget(_G, 'love'),
      FinalBoss = rawget(_G, 'FinalBoss'), textfx = package.loaded['src.textfx']}
    local good, err = pcall(fn)
    _G.SMODS, _G.G, _G.love, _G.FinalBoss = saved.SMODS, saved.G, saved.love, saved.FinalBoss
    package.loaded['src.textfx'] = saved.textfx
    if not good then error(err, 0) end
  end
end
for name, fn in pairs(T) do
  if name:find('^textfx:') then T[name] = isolated(fn) end
end

return T

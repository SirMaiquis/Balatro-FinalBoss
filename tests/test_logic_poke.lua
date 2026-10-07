local logic = require('src.logic')
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

T['poke: constants'] = function()
  eq(logic.POKE_HARD_CLICKS, 3); eq(logic.POKE_HARD_WINDOW, 2); eq(logic.POKE_HARD_COOLDOWN, 8)
  eq(logic.POKE_LINE_GAP, 4); eq(logic.GRAB_RETURN, 1.0)
end

T['poke: the first click says a line, the next ones wait for the line gap'] = function()
  local s = {}
  eq(logic.poke(s, 10), 'poked')
  eq(s.last_line, 10)
  eq(logic.poke(s, 12.5), nil, 'second click, gap not over')
  eq(logic.poke(s, 14), 'poked', 'gap over (4 s)')
  eq(s.last_line, 14)
end

T['poke: three clicks within the window poke hard, ignoring the line gap'] = function()
  local s = {}
  eq(logic.poke(s, 10), 'poked')
  eq(logic.poke(s, 10.5), nil)
  eq(logic.poke(s, 11), 'poked_hard')
  eq(s.last_hard, 11); eq(s.last_line, 11)
  eq(#s.clicks, 0, 'the window starts over')
end

T['poke: clicks outside the window do not count'] = function()
  local s = {}
  eq(logic.poke(s, 10), 'poked')
  eq(logic.poke(s, 11.5), nil)
  eq(logic.poke(s, 12.5), nil, 'the first click is 2.5 s old: only two in the window')
  eq(#s.clicks, 2)
  eq(logic.poke(s, 13), 'poked_hard', 'three within 2 s')
end

T['poke: the hard cooldown blocks a second hard poke'] = function()
  local s = {}
  logic.poke(s, 0); logic.poke(s, 0.2)
  eq(logic.poke(s, 0.4), 'poked_hard')
  eq(logic.poke(s, 1), nil); eq(logic.poke(s, 1.2), nil)
  eq(logic.poke(s, 1.4), nil, 'three clicks again, but the cooldown is on and the line gap too')
  eq(logic.poke(s, 4.5), 'poked', 'the line gap is over, the cooldown is not: a plain poke')
  logic.poke(s, 8.5); logic.poke(s, 8.6)
  eq(logic.poke(s, 8.7), 'poked_hard', 'the cooldown (8 s) is over')
end

T['poke: a hard poke in the cooldown falls back to the line gap'] = function()
  local s = {last_hard = 100, last_line = 100}
  logic.poke(s, 104); logic.poke(s, 104.1)
  -- 104 fired 'poked' (gap over), so 104.1 and 104.2 are inside the gap and the cooldown
  eq(logic.poke(s, 104.2), nil)
end

T['poke: a clock that went back counts as long ago'] = function()
  local s = {clicks = {500, 501}, last_line = 501, last_hard = 400}
  eq(logic.poke(s, 3), 'poked', 'saved times from an older session never block')
  eq(#s.clicks, 1, 'future clicks are dropped from the window')
end

T['poke: the state stays plain data'] = function()
  local s = {}
  for _, t in ipairs({1, 1.1, 1.2, 5, 9, 9.1, 9.2, 30}) do logic.poke(s, t) end
  logic.grab(s, 40)
  local function plain(v, depth)
    local ty = type(v)
    if ty == 'number' or ty == 'string' or ty == 'boolean' then return true end
    if ty ~= 'table' or depth > 3 then return false end
    for k, x in pairs(v) do
      if not (type(k) == 'string' or type(k) == 'number') or not plain(x, depth + 1) then return false end
    end
    return true
  end
  assert(plain(s, 0), 'only numbers and tables')
  assert(#s.clicks <= logic.POKE_HARD_CLICKS, 'the window stays small')
end

T['grab: says its line when the gap allows, and books it'] = function()
  local s = {}
  eq(logic.grab(s, 10), 'grabbed'); eq(s.last_line, 10)
  eq(logic.grab(s, 12), nil, 'inside the gap')
  eq(logic.poke(s, 13), nil, 'a poke shares the gap')
  eq(logic.grab(s, 14), 'grabbed')
end

T['grab: a poke line blocks a grab line inside the gap'] = function()
  local s = {}
  eq(logic.poke(s, 10), 'poked')
  eq(logic.grab(s, 11), nil)
  eq(logic.grab(s, 14), 'grabbed')
end

T['poke and grab never touch the fight bookkeeping'] = function()
  local enc = {fired = {close = true}, last_line_hand = 2, comments = 1, last_comment_hand = 2, idle_said = 1,
    poke = {}}
  logic.poke(enc.poke, 1); logic.poke(enc.poke, 1.1); logic.poke(enc.poke, 1.2); logic.grab(enc.poke, 9)
  eq(enc.fired.close, true); eq(enc.fired.poked, nil); eq(enc.fired.poked_hard, nil); eq(enc.fired.grabbed, nil)
  eq(enc.last_line_hand, 2); eq(enc.comments, 1); eq(enc.last_comment_hand, 2); eq(enc.idle_said, 1)
  for m in pairs(logic.POKE_MOMENTS) do
    eq(logic.SPACED[m], nil, m .. ' not spaced'); eq(logic.COMMENTS[m], nil, m .. ' not a comment')
  end
end

local function allowed(o)
  local a = {boss = true, ended = false, same_blind = true, tier = 'light', playing = true}
  for k, v in pairs(o or {}) do a[k] = v end
  return logic.poke_allowed(a)
end

T['poke_allowed: a live boss encounter while choosing or scoring'] = function()
  eq(allowed(), true)
  eq(allowed{tier = 'full'}, true)
end

T['poke_allowed: never outside a live boss encounter'] = function()
  eq(allowed{boss = false}, false); eq(allowed{ended = true}, false); eq(allowed{same_blind = false}, false)
  eq(allowed{tier = 'none'}, false); eq(allowed{playing = false}, false)
end

T['poke_allowed: never during the intro, a cinematic, an overlay or a pause'] = function()
  eq(allowed{intro = true}, false); eq(allowed{cinematic = true}, false)
  eq(allowed{overlay = true}, false); eq(allowed{paused = true}, false)
end

T['poke_reaction: every personality has both recipes, a hard poke is stronger'] = function()
  for _, p in ipairs(logic.PERSONALITIES) do
    local set = logic.POKE_REACTIONS[p]
    assert(set and set.poked and set.poked_hard, p .. ' recipes')
    assert(set.poked_hard.juice > set.poked.juice, p .. ' hard juice')
  end
end

T['poke_reaction: personality traits'] = function()
  local bully = logic.poke_reaction('bully', 'poked')
  eq(bully.flash, 'red'); assert(bully.shake and bully.shake > 0, 'bully shakes')
  local killer = logic.poke_reaction('killer', 'poked')
  eq(killer.flash, nil); assert(killer.juice <= 0.1, 'killer only twitches')
  assert(logic.poke_reaction('royal', 'poked').recoil > 0, 'royal recoils')
  eq(logic.poke_reaction('chaos', 'poked').giggle, 'short'); eq(logic.poke_reaction('chaos', 'poked_hard').giggle, 'full')
  assert(logic.poke_reaction('bully', 'poked_hard').jiggle, 'a hard poke on a bully shakes the screen')
end

T['poke_reaction: grabbed is the poked recipe without the recoil'] = function()
  local r = logic.poke_reaction('royal', 'grabbed')
  eq(r.recoil, nil); eq(r.juice, logic.POKE_REACTIONS.royal.poked.juice)
  eq(logic.POKE_REACTIONS.royal.poked.recoil, 0.25, 'the table is not changed')
end

T['poke_reaction: unknown personality reacts like the default'] = function()
  eq(logic.poke_reaction('mystery', 'poked').flash, logic.POKE_REACTIONS[logic.DEFAULT_PERSONALITY].poked.flash)
end

T['poke_reaction: reduced motion keeps flashes and sounds only'] = function()
  for _, p in ipairs(logic.PERSONALITIES) do
    for _, kind in ipairs({'poked', 'poked_hard', 'grabbed'}) do
      local r = logic.poke_reaction(p, kind, true)
      for _, k in ipairs({'juice', 'rot', 'shake', 'shake_amp', 'recoil', 'bounces', 'jiggle'}) do
        eq(r[k], nil, p .. ' ' .. kind .. ' ' .. k)
      end
      assert(r.flash, p .. ' ' .. kind .. ' still shows a flash')
    end
  end
  eq(logic.poke_reaction('bully', 'poked', true).flash, 'red', 'its own flash is kept')
  eq(logic.poke_reaction('chaos', 'poked', true).giggle, 'short', 'the giggle is a sound')
end

T['poke moments are personality moments with three variants'] = function()
  for _, m in ipairs({'poked', 'poked_hard', 'grabbed'}) do
    local found = false
    for _, x in ipairs(logic.PERSONALITY_MOMENTS) do if x == m then found = true end end
    assert(found, m .. ' listed')
    eq(logic.personality_variants(m), 3, m)
    eq(logic.POKE_MOMENTS[m], true)
  end
end

local function counts(map) return function(prefix) return map[prefix] or 0 end end

T['poke lines resolve through the personality, then the generic set'] = function()
  local c = counts{fb_p_bully_poked = 3, fb_generic_poked = 3, fb_generic_grabbed = 3}
  eq(logic.resolve_prefix('bl_ox', 'poked', c, 'bully'), 'fb_p_bully_poked')
  eq(logic.resolve_prefix('bl_mymod_boss', 'poked', c, 'bully'), 'fb_p_bully_poked')
  local p, generic = logic.resolve_prefix('bl_mymod_boss', 'grabbed', c, 'bully')
  eq(p, 'fb_generic_grabbed'); eq(generic, true)
  eq(logic.resolve_prefix('bl_mymod_boss', 'poked', c, nil), 'fb_generic_poked')
end

return T

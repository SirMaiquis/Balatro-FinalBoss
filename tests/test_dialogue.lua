-- dialogue.lua under stubs (no game): the bleep over censored lines.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local function setup(quips, dialogue_on)
  local ctx = {sounds = {}}
  _G.G = {localization = {misc = {quips = quips or {}}}}
  _G.play_sound = function(name, pitch, vol) ctx.sounds[#ctx.sounds + 1] = {name, pitch, vol} end
  package.loaded['src.logic'] = nil
  _G.FinalBoss = {logic = require('src.logic'), config = {dialogue = dialogue_on ~= false}}
  package.loaded['src.dialogue'] = nil
  ctx.D = require('src.dialogue')
  return ctx
end

T['bleep: a censored line bleeps once with the logic sound'] = function()
  local ctx = setup{fb_a = {'Sit down,', 'a**.'}}
  ctx.D.bleep('fb_a')
  eq(#ctx.sounds, 1)
  eq(ctx.sounds[1][1], FinalBoss.logic.BLEEP.sound); eq(ctx.sounds[1][2], FinalBoss.logic.BLEEP.pitch)
end

T['bleep: clean lines, missing keys and dialogue off stay silent'] = function()
  local ctx = setup{fb_b = {'Nice try.'}, fb_c = {'Holy', 'sh*t'}}
  ctx.D.bleep('fb_b'); ctx.D.bleep('fb_missing')
  eq(#ctx.sounds, 0)
  FinalBoss.config.dialogue = false
  ctx.D.bleep('fb_c')
  eq(#ctx.sounds, 0)
end

--- An intro sequence under stubs: bubbles recorded, timers queued (run with fire_timers).
local function intro_setup()
  local ctx = setup()
  ctx.shown, ctx.timers, ctx.ended = {}, {}, {}
  G.E_MANAGER = {add_event = function(_, e) ctx.timers[#ctx.timers + 1] = e end}
  _G.Event = function(def) return def end
  FinalBoss.util = {guard = function(_, fn, ...) return pcall(fn, ...) end, now = function() return 0 end}
  ctx.D.show = function(_, key) ctx.shown[#ctx.shown + 1] = key end
  ctx.D.hide = function() end
  ctx.blind = {states = {click = {can = false}}}
  function ctx.fire_timers()
    local queued = ctx.timers
    ctx.timers = {}
    for _, e in ipairs(queued) do e.func() end
  end
  function ctx.play(n)
    local steps = {}
    for i = 1, n do steps[i] = {key = 'fb_step_' .. i} end
    ctx.D.play_sequence(ctx.blind, steps, 4, 1, function(shown) ctx.ended[#ctx.ended + 1] = shown end)
  end
  return ctx
end

T['end_intro: on_end gets how many lines were shown'] = function()
  local ctx = intro_setup()
  ctx.play(2)
  eq(#ctx.shown, 1)
  ctx.D.end_intro() -- interrupted on the first line
  eq(ctx.ended[1], 1)
  ctx.play(2)
  ctx.fire_timers() -- second line
  ctx.fire_timers() -- past the last line: the intro ends by itself
  eq(ctx.ended[2], 2, 'every line shown, never more than there are')
  ctx.play(1)
  ctx.D.end_intro()
  eq(ctx.ended[3], 1, 'a one-line intro shows its line at once')
end

T['say: a poke line never swallows a reaction said right after it'] = function()
  local ctx = intro_setup()
  local t = 10
  FinalBoss.util.now = function() return t end
  eq(ctx.D.say(ctx.blind, 'fb_p_bully_poked_1', {}, 1, {free = true}), true)
  t = 11 -- 1 s later, inside REACTION_GAP
  eq(ctx.D.say(ctx.blind, 'fb_bl_ox_close_1', {}, 1, {}), true, 'the reaction still shows')
  eq(ctx.shown[#ctx.shown], 'fb_bl_ox_close_1')
  t = 12
  eq(ctx.D.say(ctx.blind, 'fb_p_bully_poked_2', {}, 1, {free = true}), false, 'a poke never cuts a fresh reaction')
  eq(ctx.D.say(ctx.blind, 'fb_bl_ox_big_hand_1', {}, 1, {}), false, 'real lines keep their gap')
  t = 13.5
  eq(ctx.D.say(ctx.blind, 'fb_p_bully_poked_2', {}, 1, {free = true}), true, 'after the gap')
end

T['say: a forced real line (a live fear line) is not cut by a poke or comment right after it'] = function()
  local ctx = intro_setup()
  local t = 10
  FinalBoss.util.now = function() return t end
  eq(ctx.D.say(ctx.blind, 'fb_bl_ox_close_1', {}, 1, {}), true)
  t = 10.5
  eq(ctx.D.say(ctx.blind, 'fb_generic_fear_2_1', {}, 1, {force = true}), true, 'forced over the bubble')
  t = 11
  eq(ctx.D.say(ctx.blind, 'fb_p_bully_poked_1', {}, 1, {free = true}), false, 'a poke waits')
  eq(ctx.D.say(ctx.blind, 'fb_bl_ox_big_hand_1', {}, 1, {}), false, 'a comment waits')
  eq(ctx.shown[#ctx.shown], 'fb_generic_fear_2_1', 'the fear line stands')
  t = 11.2
  eq(ctx.D.say(ctx.blind, 'fb_generic_fear_3_1', {}, 1, {force = true}), true, 'a higher tier still replaces it')
end

T['text_of: joins a list, passes a string, empty when missing'] = function()
  local ctx = setup{fb_a = {'one', 'two'}, fb_s = 'solo'}
  eq(ctx.D.text_of('fb_a'), 'one two'); eq(ctx.D.text_of('fb_s'), 'solo'); eq(ctx.D.text_of('fb_x'), '')
end

T['show late (1.4 blind-select chip): hosted on the chip, drawn late, even with an avatar up'] = function()
  local ctx = setup()
  local boxes = {}
  G.UIDEF = {speech_bubble = function() return {} end}
  G.E_MANAGER = {add_event = function() end}
  _G.Event = function(def) return def end
  _G.UIBox = function(args)
    local b = {args = args, states = {}, removed = false}
    function b:set_role(r) self.role = r end
    function b:remove() self.removed = true end
    boxes[#boxes + 1] = b
    return b
  end
  local talking = {}
  FinalBoss.avatar = {anchor = function() return {children = {}} end, side = function() return 'right' end,
    set_talking = function(on) talking[#talking + 1] = on end, talk_bump = function() end}
  local chip = {children = {}, juice_up = function(self) self.juiced = true end}
  ctx.D.show(chip, 'fb_x', {'Name'}, 1, {late = true})
  local b = boxes[1]
  eq(b.args.config.parent, nil, 'no parent: late draw pass')
  eq(b.attention_text, true)
  eq(b.role.major, chip, 'follows the chip')
  eq(b.args.config.align, 'bm')
  eq(ctx.D.avatar_bubble, b); eq(ctx.D.host, chip)
  eq(chip.children.fb_bubble, nil)
  eq(chip.juiced, true, 'the chip babbles')
  for _, on in ipairs(talking) do eq(on, false, 'the avatar is not made to talk') end
  ctx.D.hide(chip)
  eq(b.removed, true); eq(ctx.D.avatar_bubble, nil)
end

return T

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

T['text_of: joins a list, passes a string, empty when missing'] = function()
  local ctx = setup{fb_a = {'one', 'two'}, fb_s = 'solo'}
  eq(ctx.D.text_of('fb_a'), 'one two'); eq(ctx.D.text_of('fb_s'), 'solo'); eq(ctx.D.text_of('fb_x'), '')
end

return T

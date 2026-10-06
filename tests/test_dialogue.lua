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

T['text_of: joins a list, passes a string, empty when missing'] = function()
  local ctx = setup{fb_a = {'one', 'two'}, fb_s = 'solo'}
  eq(ctx.D.text_of('fb_a'), 'one two'); eq(ctx.D.text_of('fb_s'), 'solo'); eq(ctx.D.text_of('fb_x'), '')
end

return T

-- hype.lua under stubs (no game): the screen text, the sting and the meltdown.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

--- o: fx (default true), reduced, fail_text (attention_text throws), fail_sound.
local function setup(o)
  o = o or {}
  local ctx = {texts = {}, sounds = {}, pokes = {}, plays = {}, logs = 0}
  _G.G = {
    GAME = {blind = {config = {blind = {boss_colour = {0.1, 0.2, 0.3, 1}, key = 'bl_ox'}}}},
    SETTINGS = {reduced_motion = o.reduced or false}, play = {T = {}}, C = {RED = {1, 0, 0, 1}},
    UIT = {O = 'O'},
  }
  _G.DynaText = function(t) return t end
  _G.localize = function(key) return key == 'fb_hype_clutch' and 'CLUTCH LOC' or key end
  _G.attention_text = function(args)
    if o.fail_text then error('boom') end
    ctx.texts[#ctx.texts + 1] = args
  end
  _G.play_sound = function(name, pitch, vol)
    if o.fail_sound then error('boom') end
    ctx.sounds[#ctx.sounds + 1] = {name, pitch, vol}
  end
  package.loaded['src.logic'] = nil
  _G.FinalBoss = {
    logic = require('src.logic'),
    config = {fx = o.fx ~= false},
    util = {log = function() ctx.logs = ctx.logs + 1 end},
    avatar = {poke = function(blind, r, pitch) ctx.pokes[#ctx.pokes + 1] = {blind = blind, r = r, pitch = pitch} end},
    fx = {play = function(name, blind, amount)
      if FinalBoss.config.fx then ctx.plays[#ctx.plays + 1] = {name, amount} end
    end},
    registry = {get = function() return {voice = {pitch = 1.1}} end},
  }
  package.loaded['src.hype'] = nil
  ctx.H = require('src.hype')
  return ctx
end

T['hype: clutch meltdown shows text, two sounds, one poke and the shake'] = function()
  local c = setup()
  c.H.play('clutch', {meltdown = true, enc = {key = 'bl_ox'}})
  eq(#c.texts, 1, 'attention_text')
  eq(c.texts[1].text, 'CLUTCH LOC', 'localized text')
  eq(c.texts[1].major, G.play, 'centred on G.play')
  eq(c.texts[1].hold, 1.6, 'hold')
  eq(#c.sounds, 2, 'sounds')
  eq(c.sounds[1][1], 'gong', 'gong'); eq(c.sounds[1][2], 0.9, 'gong pitch'); eq(c.sounds[1][3], 0.6, 'volume')
  eq(c.sounds[2][1], 'multhit2', 'multhit2'); eq(c.sounds[2][2], 0.7, 'multhit2 pitch')
  eq(#c.pokes, 1, 'poke')
  eq(c.pokes[1].pitch, 1.1, 'voice pitch')
  eq(c.pokes[1].r.shake ~= nil, true, 'full meltdown recipe')
  eq(c.plays[1][1], 'shake', 'shake'); eq(c.plays[1][2], 10, 'shake amount')
end

T['hype: no meltdown means no poke and no shake'] = function()
  local c = setup()
  c.H.play('photo_finish', {})
  eq(#c.texts, 1, 'text'); eq(#c.sounds, 2, 'sounds'); eq(#c.pokes, 0, 'poke'); eq(#c.plays, 0, 'shake')
end

T['hype: fallback text when the dictionary has no entry'] = function()
  local c = setup()
  _G.localize = function() return 'ERROR' end
  c.H.play('lucky', {})
  eq(c.texts[1].text, 'LUCKY!', 'fallback')
end

T['hype: fx off keeps the sting but no text, poke or shake'] = function()
  local c = setup({fx = false})
  c.H.play('clutch', {meltdown = true})
  eq(#c.texts, 0, 'text'); eq(#c.pokes, 0, 'poke'); eq(#c.plays, 0, 'shake'); eq(#c.sounds, 2, 'sting')
end

T['hype: an erroring attention_text is caught and the sting still plays'] = function()
  local c = setup({fail_text = true})
  c.H.play('clutch', {meltdown = true})
  eq(#c.sounds, 2, 'sounds'); eq(c.logs >= 1, true, 'logged')
  eq(#c.pokes, 1, 'meltdown still runs')
end

T['hype: an erroring sound does not stop the text'] = function()
  local c = setup({fail_sound = true})
  c.H.play('clutch', {})
  eq(#c.texts, 1, 'text')
end

T['hype: unknown kind does nothing'] = function()
  local c = setup()
  c.H.play('nonsense', {meltdown = true})
  eq(#c.texts + #c.sounds + #c.pokes + #c.plays, 0, 'nothing')
  c.H.play(nil)
  eq(#c.texts + #c.sounds, 0, 'nil kind')
end

T['hype: reduced motion shows static text and a flash-only meltdown'] = function()
  local c = setup({reduced = true})
  c.H.play('clutch', {meltdown = true})
  eq(type(c.texts[1].text), 'table', 'prebuilt static node')
  eq(c.texts[1].text.config.object.pop_in, nil, 'no pop in')
  eq(c.texts[1].text.config.object.float, nil, 'no float')
  local r = c.pokes[1].r
  eq(r.juice, nil, 'no juice'); eq(r.shake, nil, 'no shake'); eq(r.jiggle, nil, 'no jiggle')
  eq(r.flash ~= nil, true, 'flash kept')
end

return T

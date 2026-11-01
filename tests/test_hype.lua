-- hype.lua under stubs (no game): the screen text, the sting and the meltdown.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

--- o: fx (default true), reduced, fail_text (UIBox throws), fail_sound.
local function setup(o)
  o = o or {}
  local ctx = {texts = {}, boxes = {}, events = {}, sounds = {}, pokes = {}, plays = {}, logs = 0}
  _G.G = {
    GAME = {blind = {config = {blind = {boss_colour = {0.1, 0.2, 0.3, 1}, key = 'bl_ox'}}}},
    SETTINGS = {reduced_motion = o.reduced or false, paused = false}, play = {T = {}}, C = {RED = {1, 0, 0, 1}},
    UIT = {O = 'O', ROOT = 'ROOT'}, TIMERS = {REAL = 100, TOTAL = 5},
    E_MANAGER = {add_event = function(_, e) ctx.events[#ctx.events + 1] = e end},
  }
  _G.Event = function(cfg) return cfg end
  _G.darken = function(c, p) return {c[1] * (1 - p), c[2] * (1 - p), c[3] * (1 - p), c[4]} end
  _G.DynaText = function(t)
    t.pulse = function(self, amt) self.pulsed = amt end
    t.pop_out = function(self, rate) self.popped = rate end
    return t
  end
  _G.UIBox = function(args)
    if o.fail_text then error('boom') end
    args.remove = function(self) self.removed = (self.removed or 0) + 1 end
    ctx.boxes[#ctx.boxes + 1] = args
    ctx.texts[#ctx.texts + 1] = args.definition.nodes[1].config.object
    return args
  end
  _G.localize = function(key) return key == 'fb_hype_clutch' and 'CLUTCH LOC' or key end
  _G.attention_text = function() error('attention_text runs on the game-speed timer') end
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

--- Run every queued event once (engine/event.lua, roughly): an 'after' event runs once its delay has
--- passed on its own timer (its start is taken on the first tick); done events leave the queue.
local function tick(ctx)
  local keep = {}
  for _, e in ipairs(ctx.events) do
    local now = G.TIMERS[e.timer or 'TOTAL']
    e.t0 = e.t0 or now
    local due = e.trigger ~= 'after' or e.t0 + (e.delay or 0) <= now
    if not (due and e.func()) then keep[#keep + 1] = e end
  end
  ctx.events = keep
end

T['hype: clutch meltdown shows text, two sounds, one poke and the shake'] = function()
  local c = setup()
  c.H.play('clutch', {meltdown = true, enc = {key = 'bl_ox'}})
  eq(#c.texts, 1, 'text')
  eq(c.texts[1].string, 'CLUTCH LOC', 'localized text')
  eq(c.boxes[1].config.major, G.play, 'centred on G.play')
  eq(c.boxes[1].config.align, 'cm', 'centre aligned')
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
  eq(c.texts[1].string, 'LUCKY!', 'fallback')
end

T['hype: fx off keeps the sting but no text, poke or shake'] = function()
  local c = setup({fx = false})
  c.H.play('clutch', {meltdown = true})
  eq(#c.texts, 0, 'text'); eq(#c.pokes, 0, 'poke'); eq(#c.plays, 0, 'shake'); eq(#c.sounds, 2, 'sting')
  eq(#c.events, 0, 'no timer')
end

T['hype: an erroring text box is caught and the sting still plays'] = function()
  local c = setup({fail_text = true})
  c.H.play('clutch', {meltdown = true})
  eq(#c.sounds, 2, 'sounds'); eq(c.logs >= 1, true, 'logged')
  eq(#c.pokes, 1, 'meltdown still runs')
  eq(c.H.box, nil, 'nothing left up')
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

T['hype: reduced motion shows static text, same hold, and a flash-only meltdown'] = function()
  local c = setup({reduced = true})
  c.H.play('clutch', {meltdown = true})
  eq(c.texts[1].pop_in, nil, 'no pop in')
  eq(c.texts[1].float, nil, 'no float')
  eq(c.texts[1].pulsed, nil, 'no pulse')
  eq(#c.events, 1, 'one timer')
  eq(c.events[1].delay, c.H.HOLD, 'same hold')
  tick(c)
  G.TIMERS.REAL = G.TIMERS.REAL + c.H.HOLD - 0.1; tick(c)
  eq(c.boxes[1].removed, nil, 'up for the hold')
  G.TIMERS.REAL = G.TIMERS.REAL + 0.11; tick(c)
  eq(c.texts[1].popped, nil, 'no pop out')
  eq(c.boxes[1].removed, 1, 'removed at the end of the hold: no shadow or emboss left lingering')
  eq(c.H.box, nil); eq(#c.events, 0, 'timer done')
  local r = c.pokes[1].r
  eq(r.juice, nil, 'no juice'); eq(r.shake, nil, 'no shake'); eq(r.jiggle, nil, 'no jiggle')
  eq(r.flash ~= nil, true, 'flash kept')
end

T['hype: white text on a dark boss-colour panel, popping in'] = function()
  local c = setup()
  c.H.play('overkill', {})
  local t, box = c.texts[1], c.boxes[1]
  eq(t.colours[1][1] == 1 and t.colours[1][2] == 1 and t.colours[1][3] == 1, true, 'white text')
  eq(t.scale, 2.2, 'big'); eq(t.shadow, true, 'shadow'); eq(t.pop_in, 0, 'pops in'); eq(t.pulsed, 0.5, 'pulse')
  local panel = box.definition.config.colour
  eq(math.abs(panel[2] - 0.2 * (1 - c.H.PANEL_DARKEN)) < 1e-9, true, 'darkened boss colour')
  eq(box.definition.config.emboss ~= nil, true, 'embossed')
  eq(box.attention_text, true, 'drawn above the cards')
end

T['hype: the text lives on REAL time, also while paused, and never blocks'] = function()
  local c = setup()
  c.H.play('clutch', {})
  eq(#c.events, 1, 'one timer')
  local e = c.events[1]
  eq(e.timer, 'REAL', 'REAL timer'); eq(e.pause_force, true, 'runs while paused')
  eq(e.blocking, false, 'not blocking'); eq(e.blockable, false, 'not blockable')
  eq(e.delay, 2.4, 'hold'); eq(c.H.HOLD, 2.4, 'H.HOLD')
end

T['hype: holds for H.HOLD real seconds whatever the game speed, then pops out and goes'] = function()
  local c = setup()
  c.H.play('clutch', {})
  local box, t = c.boxes[1], c.texts[1]
  tick(c)
  G.TIMERS.TOTAL = G.TIMERS.TOTAL + 1000 -- game speed / slow motion: irrelevant
  G.TIMERS.REAL = G.TIMERS.REAL + 2.3; tick(c)
  eq(box.removed, nil, 'still up at 2.3 s')
  eq(c.H.box, box, 'tracked')
  G.TIMERS.REAL = G.TIMERS.REAL + 0.15; tick(c)
  eq(t.popped ~= nil, true, 'pop out started')
  eq(box.removed, nil, 'fading')
  G.TIMERS.REAL = G.TIMERS.REAL + 0.2; tick(c)
  eq(t.colours[1][4] < 1 and t.colours[1][4] > 0, true, 'half faded')
  G.TIMERS.REAL = G.TIMERS.REAL + 0.2; tick(c)
  eq(box.removed, 1, 'removed'); eq(c.H.box, nil, 'forgotten'); eq(#c.events, 0, 'timer done')
end

T['hype: H.remove (teardown) removes a text that is up and cancels its timer'] = function()
  local c = setup()
  c.H.play('clutch', {})
  local box = c.boxes[1]
  c.H.remove()
  eq(box.removed, 1, 'removed'); eq(c.H.box, nil, 'forgotten')
  tick(c)
  G.TIMERS.REAL = G.TIMERS.REAL + 10; tick(c); tick(c)
  eq(box.removed, 1, 'never touched again'); eq(#c.events, 0, 'timer dropped')
  c.H.remove() -- nothing up: harmless
end

T['hype: a newer text replaces one still up'] = function()
  local c = setup()
  c.H.play('clutch', {})
  c.H.play('lucky', {})
  eq(c.boxes[1].removed, 1, 'old removed'); eq(c.H.box, c.boxes[2], 'new tracked')
end

T['hype: a failing fade is logged and the text removed'] = function()
  local c = setup()
  c.H.play('clutch', {})
  c.texts[1].pop_out = function() error('boom') end
  tick(c)
  G.TIMERS.REAL = G.TIMERS.REAL + 3; tick(c)
  eq(c.boxes[1].removed, 1, 'removed'); eq(c.logs >= 1, true, 'logged')
end

return T

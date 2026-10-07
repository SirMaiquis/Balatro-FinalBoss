-- poke.lua under stubs (no game): which clicks and drags hit the boss chip, the lines it says, and the
-- forced return of a grabbed chip.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local function node()
  local n = {states = {drag = {can = true, is = false}, click = {can = true}}, stopped = 0}
  function n:stop_drag() self.stopped = self.stopped + 1 end
  return n
end

--- o: enc (overrides), avatar (true: the showdown avatar is out), dialogue, state, reduced, intro, overlay.
local function setup(o)
  o = o or {}
  local ctx = {fired = {}, opts = {}, reactions = {}, now = 100}
  local enc = {key = 'bl_ox', boss = true, ended = false, tier = 'light', fired = {}, last_line_hand = 1,
    comments = 0, idle_said = 0}
  for k, v in pairs(o.enc or {}) do enc[k] = v end
  ctx.enc = enc
  ctx.blind = node()
  ctx.blind.config = {blind = {key = 'bl_ox'}}
  ctx.avatar = o.avatar and node() or nil
  _G.Vector_Dist = function(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end
  _G.G = {
    GAME = {FinalBoss = {encounter = enc}, blind = ctx.blind},
    STATES = {SELECTING_HAND = 1, HAND_PLAYED = 2, SHOP = 5}, STATE = o.state or 1,
    SETTINGS = {paused = false, reduced_motion = o.reduced or false},
    OVERLAY_MENU = o.overlay,
    CONTROLLER = {dragging = {target = nil}, cursor_down = {T = {x = 1, y = 1}}, cursor_position = {x = 1, y = 1}},
    TILESCALE = 1, TILESIZE = 1, MIN_CLICK_DIST = 0.9,
  }
  package.loaded['src.logic'] = nil
  local A = {}
  function A.exists() return ctx.avatar ~= nil end
  function A.anchor() return ctx.avatar end
  function A.pokeable() return ctx.avatar ~= nil end
  function A.poke(blind, r) ctx.reactions[#ctx.reactions + 1] = r end
  function A.hud_tick() end
  _G.FinalBoss = {
    logic = require('src.logic'),
    config = {dialogue = o.dialogue ~= false},
    util = {now = function() return ctx.now end},
    avatar = A,
    personality = {of = function() return 'bully' end},
    registry = {get = function() return {voice = {pitch = 1}} end},
    director = {fire = function(m, opts)
      ctx.fired[#ctx.fired + 1] = m; ctx.opts[#ctx.opts + 1] = opts
      return true, not ctx.drop -- ctx.drop: dialogue drops the line (its REACTION_GAP)
    end},
    cinematic = {active = function() return false end},
    dialogue = {intro_active = function() return o.intro or false end},
  }
  package.loaded['src.poke'] = nil
  ctx.K = require('src.poke')
  return ctx
end

local function chip(ctx) return ctx.avatar or ctx.blind end

--- Press on the chip and move the cursor to (x, y) (the press was at 1, 1).
local function drag_to(ctx, x, y)
  G.CONTROLLER.dragging.target = chip(ctx)
  chip(ctx).states.drag.is = true
  G.CONTROLLER.cursor_position = {x = x, y = y}
end

T['a click on the HUD chip pokes: reaction and a free line'] = function()
  local ctx = setup()
  ctx.K.on_click(ctx.blind)
  eq(#ctx.reactions, 1); eq(ctx.reactions[1].flash, 'red', 'bully reaction')
  eq(ctx.fired[1], 'poked'); eq(ctx.opts[1].free, true)
  eq(ctx.enc.poke.last_line, 100, 'plain data on the encounter')
end

T['spam clicks: the jiggle always, the lines by the rules'] = function()
  local ctx = setup()
  ctx.K.on_click(ctx.blind)
  ctx.now = 100.3; ctx.K.on_click(ctx.blind)
  ctx.now = 100.6; ctx.K.on_click(ctx.blind)
  ctx.now = 101; ctx.K.on_click(ctx.blind)
  eq(#ctx.reactions, 4, 'every click reacts')
  eq(#ctx.fired, 2); eq(ctx.fired[1], 'poked'); eq(ctx.fired[2], 'poked_hard')
  assert(ctx.reactions[3].juice > ctx.reactions[1].juice, 'the hard poke is stronger')
  assert(ctx.reactions[4].juice == ctx.reactions[1].juice, 'then plain jiggles')
end

T['pokes never touch the fight bookkeeping'] = function()
  local ctx = setup()
  for i = 0, 5 do ctx.now = 100 + i * 0.2; ctx.K.on_click(ctx.blind) end
  eq(next(ctx.enc.fired), nil); eq(ctx.enc.last_line_hand, 1); eq(ctx.enc.comments, 0); eq(ctx.enc.idle_said, 0)
end

T['dialogue off: the reaction plays, no line'] = function()
  local ctx = setup{dialogue = false}
  ctx.K.on_click(ctx.blind)
  eq(#ctx.reactions, 1); eq(#ctx.fired, 0)
end

T['no poke outside a live boss fight'] = function()
  for _, o in ipairs({{enc = {ended = true}}, {enc = {boss = false}}, {enc = {tier = 'none'}}, {state = 5},
      {intro = true}, {overlay = {}}}) do
    local ctx = setup(o)
    ctx.K.on_click(ctx.blind)
    eq(#ctx.reactions, 0); eq(#ctx.fired, 0)
  end
  local ctx = setup()
  G.SETTINGS.paused = true
  ctx.K.on_click(ctx.blind)
  eq(#ctx.reactions, 0, 'paused')
  ctx = setup()
  ctx.blind.config.blind.key = 'bl_wall'
  ctx.K.on_click(ctx.blind)
  eq(#ctx.reactions, 0, 'another blind')
end

T['while hands score the chip still reacts'] = function()
  local ctx = setup{state = 2}
  ctx.K.on_click(ctx.blind)
  eq(#ctx.reactions, 1)
end

T['showdown: the avatar is the chip, the dissolved HUD chip is not'] = function()
  local ctx = setup{avatar = true, enc = {tier = 'full'}}
  ctx.K.on_click(ctx.blind)
  eq(#ctx.reactions, 0, 'HUD chip')
  ctx.K.on_click(ctx.avatar)
  eq(#ctx.reactions, 1, 'avatar')
end

T['other nodes are ignored'] = function()
  local ctx = setup()
  ctx.K.on_click(node())
  eq(#ctx.reactions, 0)
end

T['a drag inside the click distance is not a grab'] = function()
  local ctx = setup()
  drag_to(ctx, 1.5, 1.2)
  ctx.K.tick()
  eq(#ctx.reactions, 0); eq(ctx.K.grab, nil)
end

T['a drag past the click distance grabs; the chip is let go, then the boss reacts'] = function()
  local ctx = setup()
  drag_to(ctx, 3, 1)
  ctx.K.tick()
  eq(#ctx.reactions, 0, 'nothing while it is held')
  ctx.now = 100.5; ctx.K.tick()
  eq(G.CONTROLLER.dragging.target, ctx.blind, 'still held')
  eq(#ctx.reactions, 0)
  ctx.now = 101; ctx.K.tick()
  eq(G.CONTROLLER.dragging.target, nil, 'let go after GRAB_RETURN')
  eq(ctx.blind.states.drag.is, false); eq(ctx.blind.stopped, 1)
  eq(ctx.K.grab, nil)
  eq(#ctx.reactions, 1); eq(ctx.fired[1], 'grabbed'); eq(ctx.opts[1].free, true)
  ctx.now = 101.1; ctx.K.tick()
  eq(#ctx.reactions, 1, 'one grab, one reaction')
end

T['the release of a grab is not a poke'] = function()
  local ctx = setup()
  drag_to(ctx, 3, 1)
  ctx.K.tick()
  ctx.K.on_click(ctx.blind) -- the controller clicks before the tick sees the drag end
  eq(#ctx.reactions, 0, 'no poke')
  G.CONTROLLER.dragging.target = nil -- the player let go early
  ctx.K.tick()
  eq(#ctx.reactions, 1, 'the grab reacts as the chip goes home'); eq(ctx.fired[1], 'grabbed')
end

T['a chip let go while the button is held is never clicked by that release'] = function()
  local ctx = setup()
  G.CONTROLLER.is_cursor_down = true
  drag_to(ctx, 3, 1)
  ctx.K.tick()
  ctx.now = 101; ctx.K.tick() -- forced release, button still down
  eq(G.CONTROLLER.dragging.target, nil)
  ctx.now = 101.5; ctx.K.tick()
  -- the player drags back near the press point and lets go: vanilla clicks cursor_down.target
  G.CONTROLLER.is_cursor_down = false
  ctx.K.on_click(ctx.blind) -- the controller's click pass runs before the tick
  eq(#ctx.reactions, 1, 'only the grab reacted')
  ctx.K.tick()
  eq(ctx.K.held, nil, 'cleared once the button is up')
  ctx.now = 106; ctx.K.on_click(ctx.blind)
  eq(#ctx.reactions, 2, 'the next real click pokes')
end

T['a grab after a poke: reaction, no line inside the gap'] = function()
  local ctx = setup()
  ctx.K.on_click(ctx.blind)
  ctx.now = 101
  drag_to(ctx, 3, 1)
  ctx.K.tick()
  ctx.now = 102; ctx.K.tick()
  eq(#ctx.reactions, 2); eq(#ctx.fired, 1)
end

T['a grab is let go at once when pokes stop being allowed'] = function()
  local ctx = setup()
  drag_to(ctx, 3, 1)
  ctx.K.tick()
  G.OVERLAY_MENU = {}
  ctx.K.tick()
  eq(G.CONTROLLER.dragging.target, nil); eq(ctx.K.grab, nil) ; eq(#ctx.reactions, 0, 'no reaction when a menu cuts it short')
end

T['no poke once the boss is beaten: the winning hand, the finale'] = function()
  for _, e in ipairs({{win_hand = 2}, {finale = true}}) do
    local ctx = setup{enc = e}
    ctx.K.on_click(ctx.blind)
    eq(#ctx.reactions, 0); eq(#ctx.fired, 0)
  end
end

T['a grab of the avatar is let go with no reaction when the winning hand lands'] = function()
  local ctx = setup{avatar = true, enc = {tier = 'full'}}
  drag_to(ctx, 3, 1)
  ctx.K.tick()
  assert(ctx.K.grab, 'grabbed')
  ctx.enc.win_hand = 3
  ctx.K.tick()
  eq(G.CONTROLLER.dragging.target, nil); eq(ctx.K.grab, nil); eq(ctx.avatar.states.drag.can, false)
  ctx.now = 105; ctx.K.tick()
  eq(#ctx.reactions, 0); eq(#ctx.fired, 0)
end

T['a dropped poke line spends neither the line gap nor the hard cooldown'] = function()
  local ctx = setup()
  ctx.drop = true
  ctx.K.on_click(ctx.blind)
  eq(#ctx.reactions, 1, 'the jiggle still plays'); eq(ctx.enc.poke.last_line, nil, 'gap not spent')
  ctx.now = 100.3; ctx.K.on_click(ctx.blind)
  ctx.now = 100.6; ctx.K.on_click(ctx.blind)
  eq(ctx.fired[3], 'poked_hard'); eq(ctx.enc.poke.last_hard, nil, 'cooldown not spent')
  ctx.drop = false
  ctx.now = 101; ctx.K.on_click(ctx.blind)
  ctx.now = 101.2; ctx.K.on_click(ctx.blind)
  ctx.now = 101.4; ctx.K.on_click(ctx.blind)
  eq(ctx.fired[#ctx.fired], 'poked_hard', 'the next hard poke still gets its line')
  eq(ctx.enc.poke.last_hard, 101.4); eq(ctx.enc.poke.last_line, 101.4)
end

T['a dropped grab line does not spend the line gap'] = function()
  local ctx = setup{enc = {poke = {last_line = 50}}}
  ctx.drop = true
  drag_to(ctx, 3, 1)
  ctx.K.tick()
  ctx.now = 102; ctx.K.tick()
  eq(ctx.fired[1], 'grabbed'); eq(ctx.enc.poke.last_line, 50, 'back to what it was')
end

T['dialogue off: the line gap and the hard cooldown stay booked'] = function()
  local ctx = setup{dialogue = false}
  ctx.K.on_click(ctx.blind)
  ctx.now = 100.2; ctx.K.on_click(ctx.blind)
  ctx.now = 100.4; ctx.K.on_click(ctx.blind)
  eq(ctx.enc.poke.last_hard, 100.4); eq(ctx.enc.poke.last_line, 100.4)
end

T['outside a fight a vanilla drag of the HUD chip is left alone'] = function()
  local ctx = setup{state = 5}
  drag_to(ctx, 3, 1)
  ctx.K.tick(); ctx.now = 105; ctx.K.tick()
  eq(G.CONTROLLER.dragging.target, ctx.blind); eq(#ctx.reactions, 0)
end

T['the avatar is draggable only while a poke is allowed'] = function()
  local ctx = setup{avatar = true, enc = {tier = 'full'}}
  ctx.K.tick()
  eq(ctx.avatar.states.drag.can, true)
  G.STATE = 5
  drag_to(ctx, 1.2, 1)
  ctx.K.tick()
  eq(ctx.avatar.states.drag.can, false)
  eq(G.CONTROLLER.dragging.target, nil, 'a drag in progress is let go')
end

return T

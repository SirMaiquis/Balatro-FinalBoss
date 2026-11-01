-- moments.lua under stubs (no game): the boss preview and the reroll protest/sneer on blind select.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local function logic()
  package.loaded['src.logic'] = nil
  return require('src.logic')
end

T['preview_due: once per ante, never for a silent boss'] = function()
  local L = logic()
  eq(L.preview_due{ante = 2, previewed_ante = nil, tier = 'light'}, true, 'new ante')
  eq(L.preview_due{ante = 3, previewed_ante = 2, tier = 'full'}, true, 'next ante')
  eq(L.preview_due{ante = 2, previewed_ante = 2, tier = 'light'}, false, 'same ante')
  eq(L.preview_due{ante = 2, previewed_ante = nil, tier = 'none'}, false, 'tier none')
  eq(L.preview_due{ante = 2, previewed_ante = nil, tier = nil}, false, 'unreadable boss')
end

T['preview_due: ante 1 is due like any other'] = function()
  eq(logic().preview_due{ante = 1, previewed_ante = nil, tier = 'light'}, true)
end

--- A blind-select boss UIBox stub: blind_desc holds the chip sprite before the stake sprite.
local function boss_box(sprite)
  local stake = {atlas = 'stake', sprite_pos = {x = 0, y = 0}}
  local desc = {config = {id = 'blind_desc'}, children = {
    {config = {}, children = {{config = {object = sprite}, children = {}}}},
  }}
  local root = {config = {}, children = {
    {config = {object = {string = 'name'}}, children = {}}, -- a DynaText: not a sprite
    desc,
    {config = {object = stake}, children = {}},
  }}
  return {UIRoot = root, get_UIE_by_ID = function(_, id) if id == 'blind_desc' then return desc end end}
end

local function setup(opts)
  opts = opts or {}
  local ctx = {said = {}, timers = {}}
  local L = logic()
  ctx.chip = {atlas = 'blind_chips', sprite_pos = {x = 0, y = 7}, T = {x = 14, y = 5, w = 1.4, h = 1.4}}
  ctx.copies, ctx.logs = {}, 0
  _G.Event = function(def) return def end
  _G.localize = function(args) return 'Loc ' .. args.key end
  -- The reroll's copy: SMODS.create_sprite and a UIBox wrapping it (the sprite is its O node's object).
  _G.SMODS = {create_sprite = function(x, y, w, h, atlas, pos)
    if opts.fail_sprite then error('boom') end
    return {T = {x = x, y = y, w = w, h = h}, atlas = atlas, pos = pos, role = {},
      define_draw_steps = function(self, steps) self.steps = steps end}
  end}
  -- Like vanilla's UIBox:init: args.T is ignored (ui.lua:20 passes {args.T} to Moveable.init, so T starts
  -- at 0,0) and the box sits where its alignment to config.major puts it (none: itself, so it stays at
  -- 0,0). Only 'tli' (top-left inside + offset) is modelled. box:frame() is align_to_major, run every frame.
  _G.UIBox = function(args)
    local sprite = args.definition.nodes[1].config.object
    local box = {T = {x = 0, y = 0, w = sprite.T.w, h = sprite.T.h}, VT = {x = 0, y = 0}, args = args,
      sprite = sprite}
    local cfg = args.config or {}
    if cfg.major then
      assert(cfg.align == 'tli', 'the stub models tli alignment only, got ' .. tostring(cfg.align))
      box.alignment = {offset = {x = cfg.offset.x, y = cfg.offset.y}}
    end
    function box.frame(self)
      if not cfg.major then return end
      self.T.x = cfg.major.T.x + self.alignment.offset.x
      self.T.y = cfg.major.T.y + self.alignment.offset.y
      self.VT.x, self.VT.y = self.T.x, self.T.y
    end
    box:frame()
    box.remove = function(self) self.removed = (self.removed or 0) + 1; self.REMOVED = true end
    ctx.copies[#ctx.copies + 1] = box
    return box
  end
  _G.G = {
    GAME = {round_resets = {ante = opts.ante or 2, blind_choices = {Boss = 'bl_hook'}}, FinalBoss = {}},
    STATE = 7, STATES = {BLIND_SELECT = 7},
    TIMERS = {REAL = 0}, SETTINGS = {reduced_motion = opts.reduced or false},
    ROOM = {T = {x = 0, y = 0, w = 20, h = 11.5}}, UIT = {ROOT = 'ROOT', O = 'O'},
    ROOM_ATTACH = {T = {x = 0, y = 0, w = 20, h = 11.5}},
    C = {CLEAR = {0, 0, 0, 0}, BLACK = {0, 0, 0, 1}, RED = {1, 0, 0, 1}},
    E_MANAGER = {add_event = function(_, e)
      e.queued_at = G.TIMERS.REAL
      ctx.timers[#ctx.timers + 1] = e
    end},
    P_BLINDS = {bl_hook = {name = 'The Hook', boss = {min = 1}, pos = {x = 0, y = 7}, boss_colour = {0.6, 0.3, 0.2, 1}},
      bl_wall = {name = 'The Wall', boss = {min = 2}},
      bl_ox = {name = 'The Ox', boss = {min = 6}}, bl_final_leaf = {name = 'Verdant Leaf', boss = {showdown = true}}},
    blind_select = {},
    blind_select_opts = {boss = boss_box(ctx.chip)},
  }
  _G.FinalBoss = {
    logic = L,
    config = {dialogue = opts.dialogue ~= false, fx = opts.fx ~= false, min_ante = opts.min_ante or 1},
    util = {guard = function(_, fn, ...) return pcall(fn, ...) end, log = function() ctx.logs = ctx.logs + 1 end,
      state = function() G.GAME.FinalBoss = G.GAME.FinalBoss or {}; return G.GAME.FinalBoss end},
    director = {enabled = function() return not G.GAME.FinalBoss.disabled_for_run end},
    registry = {
      get = function(key) return {tier = 'auto', voice = {pitch = key == 'bl_wall' and 0.7 or 1}} end,
      resolve = function(key, moment) return 'fb_' .. key .. '_' .. moment end,
    },
    dialogue = {say = function(host, key, vars, pitch, o)
      ctx.said[#ctx.said + 1] = {host = host, key = key, vars = vars, pitch = pitch, opts = o}
      FinalBoss.dialogue.host = host
      return true
    end, hide = function() ctx.hidden = (ctx.hidden or 0) + 1; FinalBoss.dialogue.host = nil end},
  }
  package.loaded['src.moments'] = nil
  ctx.M = require('src.moments')
  function ctx.fire_timers()
    local queued = ctx.timers
    ctx.timers = {}
    for _, e in ipairs(queued) do e.func() end
  end
  --- Advance the REAL clock to t and run the queue like the event manager: an 'after' event once its
  --- delay has passed since it was queued; a repeating one (returns false) stays queued.
  function ctx.run(t)
    G.TIMERS.REAL = t
    local queued = ctx.timers
    ctx.timers = {}
    for _, e in ipairs(queued) do
      local due = e.trigger ~= 'after' or (e.queued_at or 0) + (e.delay or 0) <= t
      if not (due and e.func() ~= false) then ctx.timers[#ctx.timers + 1] = e end
    end
    for _, box in ipairs(ctx.copies) do if not box.REMOVED then box:frame() end end -- then moveables move
  end
  function ctx.keys()
    local out = {}
    for i, s in ipairs(ctx.said) do out[i] = s.key end
    return table.concat(out, ',')
  end
  return ctx
end

T['chip: the blind sprite inside blind_desc, not the stake or the name'] = function()
  local ctx = setup()
  eq(ctx.M.chip(), ctx.chip)
  G.blind_select_opts = nil
  eq(ctx.M.chip(), nil, 'no blind select')
end

T['on_blind_select: the upcoming boss previews once per ante, from its chip'] = function()
  local ctx = setup()
  ctx.M.on_blind_select()
  eq(#ctx.said, 0, 'waits for the screen to settle')
  ctx.fire_timers()
  eq(ctx.keys(), 'fb_bl_hook_preview')
  local s = ctx.said[1]
  eq(s.host, ctx.chip); eq(s.vars[1], 'Loc bl_hook'); eq(s.pitch, 1)
  eq(s.opts.late, true, 'drawn above the blind-select UI')
  eq(G.GAME.FinalBoss.previewed_ante, 2)
  ctx.M.on_blind_select() -- back from the shop, same ante (or a reload)
  ctx.fire_timers()
  eq(#ctx.said, 1)
  G.GAME.round_resets.ante = 3
  ctx.M.on_blind_select()
  ctx.fire_timers()
  eq(#ctx.said, 2, 'a new ante previews again')
end

T['on_blind_select: a light boss below min_ante says nothing; showdowns always speak'] = function()
  local ctx = setup{min_ante = 4}
  ctx.M.on_blind_select(); ctx.fire_timers()
  eq(#ctx.said, 0)
  G.GAME.round_resets.blind_choices.Boss = 'bl_final_leaf'
  ctx.M.on_blind_select(); ctx.fire_timers()
  eq(ctx.keys(), 'fb_bl_final_leaf_preview')
end

T['on_blind_select: ante 1 previews on its first screen, after the run-start wipe'] = function()
  local ctx = setup{ante = 1}
  ctx.M.on_blind_select()
  eq(#ctx.timers, 1)
  eq(ctx.timers[1].delay, ctx.M.FIRST_PREVIEW_DELAY, 'the longer wait')
  ctx.fire_timers()
  eq(ctx.keys(), 'fb_bl_hook_preview')
  eq(G.GAME.FinalBoss.previewed_ante, 1)
  ctx.M.on_blind_select(); ctx.fire_timers() -- back from the small blind's shop
  eq(#ctx.said, 1, 'once per ante')
  G.GAME.round_resets.ante = 2
  ctx.M.on_blind_select()
  eq(ctx.timers[1].delay, ctx.M.PREVIEW_DELAY, 'later screens wait the short delay')
  ctx.M.teardown(); G.GAME.round_resets.ante = 3
  ctx.M.on_blind_select()
  eq(ctx.timers[#ctx.timers].delay, ctx.M.FIRST_PREVIEW_DELAY, 'a new or loaded run waits for its wipe again')
end

T['on_blind_select: a blind picked before the line is due drops it'] = function()
  local ctx = setup()
  ctx.M.on_blind_select()
  G.STATE = 1; G.blind_select = nil
  ctx.fire_timers()
  eq(#ctx.said, 0)
  eq(G.GAME.FinalBoss.previewed_ante, nil, 'not counted: it was never seen')
end

--- A reroll as hooks.lua drives it: the click (old chip still up), then vanilla's swap, then on_reroll.
local function reroll(ctx, old, new)
  ctx.M.on_reroll_click(old)
  G.GAME.round_resets.blind_choices.Boss = new
  ctx.M.on_reroll(old, new)
end

T['on_reroll: a copy of the OLD chip protests at the click, the NEW boss sneers once it is gone'] = function()
  local ctx = setup()
  ctx.M.on_reroll_click('bl_hook')
  eq(ctx.keys(), 'fb_bl_hook_rerolled_out', 'the protest, before the swap')
  eq(#ctx.copies, 1, 'one copy')
  local box = ctx.copies[1]
  eq(ctx.said[1].host, box.sprite, 'said from the copy, not the real chip')
  eq(ctx.said[1].opts.late, true, 'drawn on top')
  eq(box.sprite.atlas, 'blind_chips'); eq(box.sprite.pos.y, 7, 'the old boss sprite')
  eq(box.T.x, 14); eq(box.T.y, 5); eq(box.T.w, 1.4, 'where the old chip was, its size')
  eq(box.attention_text, true, 'late drawn, above the panel')
  eq(G.GAME.FinalBoss.previewed_ante, 2, 'counts as the preview')
  G.GAME.round_resets.blind_choices.Boss = 'bl_wall' -- vanilla's swap, ~0.3 game-seconds later
  ctx.M.on_reroll('bl_hook', 'bl_wall')
  eq(#ctx.said, 1, 'no sneer during the protest')
  eq(ctx.M.YANK_HOLD, 2.0, 'two short lines need ~2 s'); eq(ctx.M.PROTEST_TIME, 2.9, '~3 s in all')
  ctx.run(0.1)
  eq(box.T.x, 14, 'holds while the line is read')
  ctx.run(1.5)
  eq(box.T.x, 14, 'still holding at 1.5 s'); eq(ctx.hidden, nil, 'line still up')
  ctx.run(1.9)
  eq(math.abs(box.T.x - 14) <= ctx.M.YANK_SHAKE_AMP, true, 'shaking at the end of the hold, in place')
  eq(ctx.hidden, nil, 'line still up while it shakes')
  ctx.run(2.05)
  eq(ctx.hidden, 1, 'the bubble goes as the slide starts')
  ctx.run(2.6)
  eq(box.T.x > 14 + ctx.M.YANK_SHAKE_AMP, true, 'yanked toward the nearest edge (right)')
  eq(#ctx.said, 1, 'no sneer during the slide')
  ctx.run(ctx.M.PROTEST_TIME + 0.01)
  eq(box.removed, 1, 'the copy is gone'); eq(ctx.M.copy, nil)
  eq(ctx.hidden, 1, 'hidden once only')
  ctx.run(ctx.M.PROTEST_TIME + 0.02)
  eq(ctx.keys(), 'fb_bl_hook_rerolled_out,fb_bl_wall_rerolled_in', 'then the sneer')
  eq(ctx.said[2].host, ctx.chip, 'from the real (new) chip')
  eq(ctx.said[2].pitch, 0.7, 'the new boss voice'); eq(ctx.said[2].vars[1], 'Loc bl_wall')
  ctx.M.on_blind_select(); ctx.run(10); ctx.run(20)
  eq(#ctx.said, 2, 'no second preview this ante')
end

T['room_rect: where a node is drawn, in room units'] = function()
  local M = setup().M
  local x, y, w, h = M.room_rect({T = {x = 14, y = 5, w = 1.4, h = 1.4}})
  eq(x, 14); eq(y, 5); eq(w, 1.4); eq(h, 1.4, 'T alone')
  x, y, w, h = M.room_rect({T = {x = 14, y = 5, w = 1.4, h = 1.4}, VT = {x = 14, y = 5.6, w = 1.5, h = 1.5}})
  eq(x, 14); eq(y, 5.6, 'VT: where it is drawn this frame (still settling)'); eq(w, 1.4, 'T size, not a juiced VT')
  eq(M.room_rect(nil), nil); eq(M.room_rect({}), nil, 'no transform')
  eq(M.room_rect({T = {x = 1}}), nil, 'incomplete transform')
end

T['on_reroll: the copy starts exactly over a chip nested in the boss UIBox, not at the room origin'] = function()
  local ctx = setup()
  -- The boss UIBox at (12, 4); the chip's UIElement 2, 1 inside it; the sprite 0.3, 0.2 inside that.
  -- Role offsets are relative; T / VT are room positions (moveable.lua:370-375).
  local boss = {T = {x = 12, y = 4, w = 5, h = 6}}
  local uie = {T = {x = 14, y = 5, w = 2, h = 2}, role = {role_type = 'Minor', major = boss, offset = {x = 2, y = 1}}}
  local chip = {atlas = 'blind_chips', sprite_pos = {x = 0, y = 7},
    T = {x = 14.3, y = 5.2, w = 1.4, h = 1.4}, VT = {x = 14.3, y = 5.2, w = 1.4, h = 1.4},
    role = {role_type = 'Minor', major = uie, offset = {x = 0.3, y = 0.2}}}
  G.blind_select_opts.boss = boss_box(chip)
  ctx.M.on_reroll_click('bl_hook')
  local box = ctx.copies[1]
  eq(box.T.x, 14.3, 'copy x = the chip room x'); eq(box.T.y, 5.2, 'copy y = the chip room y')
  eq(box.VT.x, 14.3); eq(box.VT.y, 5.2, 'drawn there from the first frame')
  eq(box.T.w, 1.4); eq(box.T.h, 1.4, 'same size')
  eq(ctx.said[1].host, box.sprite, 'the line is anchored on the copy')
  ctx.run(0.1); ctx.run(1.5)
  eq(box.T.x, 14.3); eq(box.T.y, 5.2, 'stays over the chip through the hold (frames re-align it)')
  local c = ctx.M.copy
  eq(c.x0, 14.3); eq(c.y0, 5.2, 'the yank starts from the chip')
  eq(c.edge, 'right', 'off the nearest edge, away from the boss slot'); eq(c.ty, 5.2, 'level with the chip')
  ctx.run(2.6)
  eq(box.T.x > 14.3 + ctx.M.YANK_SHAKE_AMP, true, 'sliding right'); eq(box.T.y, 5.2, 'no drift up or down')
  ctx.run(ctx.M.PROTEST_TIME - 0.01)
  eq(box.T.x > 15, true, 'still going right at the end of the slide')
end

T['on_reroll: no room attach point, no copy (the sneer still comes)'] = function()
  local ctx = setup()
  G.ROOM_ATTACH = nil
  reroll(ctx, 'bl_hook', 'bl_wall')
  eq(#ctx.copies, 0, 'no copy'); ctx.run(0.1)
  eq(ctx.keys(), 'fb_bl_wall_rerolled_in', 'the sneer at once')
end

T['yank_target: the nearest window edge and a spot past it'] = function()
  local M = setup().M
  local b = {-1, -1, 21, 12.5}
  local edge, x, y = M.yank_target(14, 5, 1.4, 1.4, b)
  eq(edge, 'right'); eq(x, 21 + M.YANK_MARGIN); eq(y, 5)
  edge, x = M.yank_target(1, 5, 1.4, 1.4, b)
  eq(edge, 'left'); eq(x, -1 - 1.4 - M.YANK_MARGIN)
  edge, x, y = M.yank_target(9, 10, 1.4, 1.4, b)
  eq(edge, 'bottom'); eq(y, 12.5 + M.YANK_MARGIN); eq(x, 9)
  edge, x, y = M.yank_target(9, 0.5, 1.4, 1.4, b)
  eq(edge, 'top'); eq(y, -1 - 1.4 - M.YANK_MARGIN)
end

T['on_reroll: reduced motion or fx off, the copy stays put and dissolves after its line'] = function()
  for _, o in ipairs({{reduced = true}, {fx = false}}) do
    local ctx = setup(o)
    reroll(ctx, 'bl_hook', 'bl_wall')
    local box = ctx.copies[1]
    ctx.run(0.5); ctx.run(1.9)
    eq(box.T.x, 14, 'no slide'); eq(box.T.y, 5, 'no shake')
    eq(box.sprite.dissolve, 0, 'holds ~2 s'); eq(ctx.hidden, nil, 'line still up')
    ctx.run(ctx.M.YANK_HOLD + 0.2)
    eq(ctx.hidden, 1, 'the bubble goes as it dissolves')
    eq(box.sprite.dissolve > 0 and box.sprite.dissolve < 1, true, 'dissolving')
    eq(#ctx.said, 1, 'no sneer yet')
    ctx.run(ctx.M.STILL_TIME + 0.01); ctx.run(ctx.M.STILL_TIME + 0.02)
    eq(box.removed, 1); eq(ctx.keys(), 'fb_bl_hook_rerolled_out,fb_bl_wall_rerolled_in', 'then the sneer')
  end
end

T['on_reroll: a pending preview gives way to the reroll'] = function()
  local ctx = setup()
  ctx.M.on_blind_select()
  reroll(ctx, 'bl_hook', 'bl_wall')
  for t = 1, 5 do ctx.run(t) end
  eq(ctx.keys(), 'fb_bl_hook_rerolled_out,fb_bl_wall_rerolled_in')
end

T['on_reroll: two quick rerolls, only the latest sneer plays; the first copy goes'] = function()
  local ctx = setup()
  reroll(ctx, 'bl_hook', 'bl_wall')
  ctx.run(0.5)
  G.P_BLINDS.bl_wall.pos = {x = 0, y = 9}
  reroll(ctx, 'bl_wall', 'bl_ox')
  eq(ctx.copies[1].removed, 1, 'the first copy removed')
  eq(ctx.copies[2].sprite.pos.y, 9, 'the second copy is the Wall')
  for t = 1, 7 do ctx.run(t) end
  eq(ctx.keys(), 'fb_bl_hook_rerolled_out,fb_bl_wall_rerolled_out,fb_bl_ox_rerolled_in')
  eq(ctx.copies[2].removed, 1)
end

T['on_reroll: a silent outgoing boss has no copy and lets the new one sneer at once'] = function()
  local ctx = setup{min_ante = 4}
  reroll(ctx, 'bl_hook', 'bl_final_leaf')
  eq(ctx.keys(), 'fb_bl_final_leaf_rerolled_in')
  eq(#ctx.copies, 0)
end

T['on_reroll: an unknown old boss gets no copy and no line; the sneer still comes'] = function()
  local ctx = setup()
  reroll(ctx, 'bl_modded_gone', 'bl_wall')
  eq(#ctx.copies, 0); eq(ctx.keys(), 'fb_bl_wall_rerolled_in')
  eq(G.GAME.FinalBoss.previewed_ante, 2)
end

T['on_reroll: a copy that fails to build is logged and skipped; the sneer still comes'] = function()
  local ctx = setup{fail_sprite = true}
  reroll(ctx, 'bl_hook', 'bl_wall')
  eq(ctx.logs >= 1, true, 'logged'); eq(ctx.M.copy, nil)
  eq(ctx.keys(), 'fb_bl_wall_rerolled_in')
end

T['on_reroll: no line for the old boss, no copy left behind'] = function()
  local ctx = setup()
  FinalBoss.registry.resolve = function(key, moment)
    if moment == 'rerolled_out' then return nil end
    return 'fb_' .. key .. '_' .. moment
  end
  reroll(ctx, 'bl_hook', 'bl_wall')
  eq(ctx.copies[1].removed, 1); eq(ctx.keys(), 'fb_bl_wall_rerolled_in')
end

T['on_reroll: no click seen (no protest): the sneer comes at once'] = function()
  local ctx = setup()
  G.GAME.round_resets.blind_choices.Boss = 'bl_wall'
  ctx.M.on_reroll('bl_hook', 'bl_wall')
  eq(ctx.keys(), 'fb_bl_wall_rerolled_in'); eq(#ctx.copies, 0)
end

T['teardown: a pending sneer never plays and the flying copy is removed'] = function()
  local ctx = setup()
  reroll(ctx, 'bl_hook', 'bl_wall')
  ctx.run(0.6)
  ctx.M.teardown()
  eq(ctx.copies[1].removed, 1, 'copy removed'); eq(ctx.M.copy, nil)
  eq(ctx.hidden, nil, 'the bubble is left to dialogue.drop_on_teardown')
  for t = 1, 5 do ctx.run(t) end
  eq(ctx.keys(), 'fb_bl_hook_rerolled_out')
  eq(ctx.copies[1].removed, 1, 'never touched again')
  G.GAME.round_resets.ante = 3
  ctx.M.on_blind_select()
  ctx.M.teardown()
  ctx.fire_timers()
  eq(#ctx.said, 1, 'a pending preview neither')
end

T['gating: dialogue off, FinalBoss disabled for the run: nothing said'] = function()
  local ctx = setup{dialogue = false}
  ctx.M.on_blind_select(); reroll(ctx, 'bl_hook', 'bl_wall'); ctx.fire_timers()
  eq(#ctx.said, 0); eq(#ctx.copies, 0, 'dialogue off: no copy either')
  ctx = setup()
  G.GAME.FinalBoss.disabled_for_run = true
  ctx.M.on_blind_select(); reroll(ctx, 'bl_hook', 'bl_wall'); ctx.fire_timers()
  eq(#ctx.said, 0); eq(#ctx.copies, 0)
end

T['speak: a boss with no line, or an unknown blind key, is skipped quietly'] = function()
  local ctx = setup()
  FinalBoss.registry.resolve = function() return nil end
  ctx.M.on_blind_select(); ctx.fire_timers()
  eq(#ctx.said, 0)
  eq(G.GAME.FinalBoss.previewed_ante, nil)
  ctx = setup()
  G.GAME.round_resets.blind_choices.Boss = 'bl_modded_gone'
  ctx.M.on_blind_select(); ctx.fire_timers()
  eq(#ctx.said, 0)
end

-- Early loss (1.4) ------------------------------------------------------------------------------------

--- A game over on the small blind: the overlay is not up yet; the avatar stub records the spawned
--- chip; memory and achievements record any call (none is allowed).
local function loss_setup(opts)
  local ctx = setup(opts)
  ctx.spawned, ctx.forbidden = {}, {}
  ctx.clock = 0
  G.GAME.blind = {config = {blind = {key = 'bl_small'}}}
  G.SETTINGS = {paused = true}
  G.OVERLAY_MENU = nil
  ctx.avatar = {obj = {name = 'gloat chip'}}
  FinalBoss.avatar = {
    on_game_over_screen = function() return G.OVERLAY_MENU ~= nil end,
    spawn_gloat = function(key, pitch)
      ctx.spawned[#ctx.spawned + 1] = {key = key, pitch = pitch}
      return true
    end,
    anchor = function() return ctx.avatar.obj end,
  }
  FinalBoss.util.now = function() return ctx.clock end
  local function forbid(name) return function() ctx.forbidden[#ctx.forbidden + 1] = name end end
  FinalBoss.memory = {on_loss = forbid('memory.on_loss'), on_fight = forbid('memory.on_fight')}
  FinalBoss.achievements = {award_from = forbid('achievements.award_from')}
  -- Repeating events (return false) stay queued, like the event manager.
  function ctx.run_timers()
    local queued = ctx.timers
    ctx.timers = {}
    for _, e in ipairs(queued) do
      if e.func() == false then ctx.timers[#ctx.timers + 1] = e end
    end
  end
  return ctx
end

T['on_early_loss: the upcoming boss comes out once the game-over screen is up, and mocks'] = function()
  local ctx = loss_setup()
  G.GAME.round_resets.blind_choices.Boss = 'bl_wall'
  ctx.M.on_early_loss()
  eq(#ctx.timers, 1, 'one waiting event')
  local w = ctx.timers[1]
  eq(w.pause_force, true, 'runs while the game-over screen pauses the game')
  eq(w.blocking, false); eq(w.blockable, false)
  ctx.run_timers()
  eq(#ctx.spawned, 0, 'no chip before the overlay')
  G.OVERLAY_MENU = {}
  ctx.run_timers()
  eq(#ctx.spawned, 1)
  eq(ctx.spawned[1].key, 'bl_wall'); eq(ctx.spawned[1].pitch, 0.7, 'the boss voice')
  eq(#ctx.said, 0, 'the line waits for the chip to land')
  for _ = 1, 3 do ctx.run_timers() end
  eq(ctx.keys(), 'fb_bl_wall_early_loss')
  local s = ctx.said[1]
  eq(s.host, G.GAME.blind, 'dialogue hosts it on the avatar chip (host_for)')
  eq(s.pitch, 0.7); eq(s.vars[1], 'Loc bl_wall')
  eq(s.opts.popup, true, 'drawn above the game-over dim')
  eq(s.opts.force, true); eq(s.opts.free, true)
  eq(#ctx.forbidden, 0, 'no memory, nemesis or achievements')
  eq(G.GAME.FinalBoss.lost_to, nil, 'not a loss to that boss')
end

T['on_early_loss: an unreadable or unknown boss says nothing and shows no chip'] = function()
  for _, key in ipairs({false, 'bl_modded_gone'}) do
    local ctx = loss_setup()
    G.GAME.round_resets.blind_choices.Boss = key or nil
    ctx.M.on_early_loss()
    G.OVERLAY_MENU = {}
    for _ = 1, 4 do ctx.run_timers() end
    eq(#ctx.spawned, 0, tostring(key)); eq(#ctx.said, 0, tostring(key))
  end
  local ctx = loss_setup()
  G.GAME.round_resets = nil
  ctx.M.on_early_loss()
  eq(#ctx.timers, 0, 'no round_resets')
end

T['on_early_loss: dialogue off, disabled for the run, a silent light boss, no line: nothing'] = function()
  local cases = {
    function() return loss_setup{dialogue = false} end,
    function() local c = loss_setup(); G.GAME.FinalBoss.disabled_for_run = true; return c end,
    function() return loss_setup{min_ante = 4} end,
    function() local c = loss_setup(); FinalBoss.registry.resolve = function() return nil end; return c end,
  }
  for i, make in ipairs(cases) do
    local ctx = make()
    ctx.M.on_early_loss()
    G.OVERLAY_MENU = {}
    for _ = 1, 4 do ctx.run_timers() end
    eq(#ctx.spawned, 0, 'case ' .. i); eq(#ctx.said, 0, 'case ' .. i)
  end
end

T['on_early_loss: leaving before the overlay, or no overlay at all, drops it'] = function()
  local ctx = loss_setup()
  ctx.M.on_early_loss()
  ctx.M.teardown()
  G.OVERLAY_MENU = {}
  for _ = 1, 4 do ctx.run_timers() end
  eq(#ctx.spawned, 0, 'teardown')
  ctx = loss_setup()
  ctx.M.on_early_loss()
  ctx.run_timers()
  ctx.clock = ctx.M.EARLY_LOSS_WAIT + 1
  ctx.run_timers()
  eq(#ctx.timers, 0, 'gives up')
  G.OVERLAY_MENU = {}
  ctx.run_timers()
  eq(#ctx.spawned, 0)
end

T['on_early_loss: the chip gone before its line (New Run) drops the line'] = function()
  local ctx = loss_setup()
  ctx.M.on_early_loss()
  G.OVERLAY_MENU = {}
  ctx.run_timers()
  eq(#ctx.spawned, 1)
  ctx.avatar.obj = nil
  for _ = 1, 3 do ctx.run_timers() end
  eq(#ctx.said, 0)
end

--- director.lua's on_round_end under stubs: which round ends call the early loss.
local function round_end_setup(o)
  local ctx = {early = 0, forbidden = {}, events = {}, bubble = false, hides = 0}
  _G.Event = function(t) return t end
  local blind_proto = o.boss and {key = 'bl_hook', boss = {min = 1}} or {key = 'bl_small'}
  _G.G = {
    GAME = {FinalBoss = {encounter = o.enc}, blind = {config = {blind = blind_proto}}},
    E_MANAGER = {add_event = function(_, e) ctx.events[#ctx.events + 1] = e end},
    STATES = {GAME_OVER = 4, ROUND_EVAL = 5}, STATE = o.over and 4 or 5,
  }
  local noop = function() end
  package.loaded['src.logic'] = nil
  package.loaded['src.director'] = nil
  _G.FinalBoss = {
    logic = require('src.logic'),
    config = {dialogue = true},
    util = {now = function() return 0 end, log = noop, state = function() return G.GAME.FinalBoss end,
      guard = function(_, f, ...) return pcall(f, ...) end},
    phases = {reset = noop},
    memory = {unpresent = noop, on_loss = o.boss and function() return true end
      or function() ctx.forbidden[#ctx.forbidden + 1] = 'memory.on_loss' end},
    avatar = {set_hud_tremble = noop}, fx = {stop = noop}, arena = {stop = noop},
    -- The bubble: the early-loss line shows it; any hide removes it (dialogue.hide drops the late
    -- bubble whatever its host).
    dialogue = {end_intro = noop, hide = function() ctx.hides = ctx.hides + 1; ctx.bubble = false end},
    moments = {on_early_loss = function() ctx.early = ctx.early + 1; ctx.bubble = true end},
  }
  -- Every queued event, timers included (created on the paused game-over screen, they do run).
  function ctx.run_events()
    local queued = ctx.events
    ctx.events = {}
    for _, e in ipairs(queued) do e.func() end
  end
  ctx.D = require('src.director')
  FinalBoss.director = ctx.D
  return ctx
end

T['on_round_end: a game over on a small or big blind calls the early loss once'] = function()
  local ctx = round_end_setup{over = true, enc = {key = 'bl_small', boss = false, tier = 'none', fired = {}}}
  ctx.D.on_round_end()
  eq(ctx.early, 1, 'with its (silent) encounter')
  eq(#ctx.forbidden, 0, 'not a loss to anyone')
  ctx = round_end_setup{over = true, enc = nil}
  ctx.D.on_round_end()
  eq(ctx.early, 1, 'no encounter at all')
end

T['on_round_end: a boss loss or a won round is not an early loss'] = function()
  local ctx = round_end_setup{over = true, boss = true, enc = {key = 'bl_hook', boss = true, tier = 'light', fired = {}}}
  ctx.D.on_round_end()
  eq(ctx.early, 0, 'boss blind')
  ctx = round_end_setup{over = false, enc = {key = 'bl_small', boss = false, tier = 'none', fired = {}}}
  ctx.D.on_round_end()
  eq(ctx.early, 0, 'round won')
end

T['on_round_end: the early-loss line survives the director queued events until its own hide'] = function()
  local ctx = round_end_setup{over = true, enc = {key = 'bl_small', boss = false, tier = 'none', fired = {}}}
  ctx.D.on_round_end()
  eq(ctx.bubble, true)
  ctx.run_events()
  eq(ctx.hides, 0, 'no tail hide queued on an early loss')
  eq(ctx.bubble, true, 'the line stays for its LINE_DURATION')
  -- A boss loss still clears its own bubble after 3 s.
  ctx = round_end_setup{over = true, boss = true, enc = {key = 'bl_hook', boss = true, tier = 'light', fired = {}}}
  ctx.D.on_round_end()
  ctx.run_events()
  eq(ctx.hides, 1, 'boss loss: the tail hide runs')
  -- So does a won small blind.
  ctx = round_end_setup{over = false, enc = {key = 'bl_small', boss = false, tier = 'none', fired = {}}}
  ctx.D.on_round_end()
  ctx.run_events()
  eq(ctx.hides, 1, 'won round: the tail hide runs')
end

return T

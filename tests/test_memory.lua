-- memory.lua under stubs (no game): profile storage, saves, and damaged saved data.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

--- Fresh memory module with a stubbed profile; ctx.saves counts G:save_progress() calls.
local function setup(profile)
  local ctx = {saves = 0}
  local profiles = {p1 = profile}
  _G.G = {PROFILES = profiles, SETTINGS = {profile = 'p1'}}
  function _G.G:save_progress() ctx.saves = ctx.saves + 1 end
  ctx.G = _G.G
  ctx.logs = {}
  local function log(msg) ctx.logs[#ctx.logs + 1] = msg end
  _G.sendInfoMessage, _G.sendWarnMessage, _G.sendErrorMessage, _G.sendDebugMessage = log, log, log, log
  package.loaded['src.util'] = nil
  package.loaded['src.logic'] = nil
  _G.FinalBoss = {util = require('src.util'), logic = require('src.logic')}
  package.loaded['src.memory'] = nil
  ctx.mem = require('src.memory')
  ctx.profile = profiles.p1
  return ctx
end

T['memory: no profile, no data and no crash'] = function()
  local ctx = setup(nil)
  eq(ctx.mem.data(), nil)
  ctx.mem.on_fight('bl_x'); ctx.mem.on_loss('bl_x')
  eq(ctx.mem.on_interrupt('bl_x'), nil)
  local m, beaten = ctx.mem.on_win({key = 'bl_x'})
  eq(m, nil); eq(beaten, false)
  eq(ctx.mem.last('bl_x'), nil); eq(ctx.mem.is_nemesis('bl_x'), false)
end

T['memory: created in the profile, saved on each record'] = function()
  local ctx = setup({})
  ctx.mem.on_fight('bl_x')
  eq(ctx.profile.FinalBoss.bosses.bl_x.fights, 1)
  ctx.mem.on_loss('bl_x')
  eq(ctx.mem.last('bl_x'), 'lost')
  ctx.mem.on_interrupt('bl_x')
  eq(ctx.profile.FinalBoss.interrupted.bl_x, true)
  eq(ctx.saves, 3)
  eq(ctx.G.FILE_HANDLER.force, true, 'the profile write must be forced')
end

T['memory: every record forces the write'] = function()
  for _, record in ipairs({
      function(mem) mem.on_fight('bl_x') end, function(mem) mem.on_loss('bl_x') end,
      function(mem) mem.on_win({key = 'bl_x'}) end, function(mem) mem.on_interrupt('bl_x') end}) do
    local ctx = setup({})
    ctx.G.FILE_HANDLER = nil
    record(ctx.mem)
    eq(ctx.G.FILE_HANDLER and ctx.G.FILE_HANDLER.force, true)
  end
end

T['memory: a failing save is logged, not raised, and the record stays'] = function()
  local ctx = setup({})
  function ctx.G:save_progress() error('disk') end
  local m = ctx.mem.on_loss('bl_x')
  eq(m, nil, 'a failed record reports nothing')
  eq(ctx.profile.FinalBoss.bosses.bl_x.losses, 1)
  local mem, beaten = ctx.mem.on_win({key = 'bl_x'})
  eq(mem, nil); eq(beaten, false)
  eq(ctx.mem.on_interrupt('bl_x'), nil)
  ctx.mem.on_fight('bl_x')
  assert(#ctx.logs >= 4, 'each failure is logged')
end

T['memory: a win on a showdown records final_defeated (twisted only with twists)'] = function()
  local ctx = setup({})
  ctx.mem.on_win({key = 'bl_final_acorn', showdown = true, twists_on = false})
  eq(ctx.profile.FinalBoss.final_defeated.bl_final_acorn, true)
  eq(ctx.profile.FinalBoss.final_defeated_twisted.bl_final_acorn, nil)
  ctx.mem.on_win({key = 'bl_final_leaf', showdown = true, twists_on = true})
  eq(ctx.profile.FinalBoss.final_defeated_twisted.bl_final_leaf, true)
  ctx.mem.on_win({key = 'bl_goad'})
  eq(ctx.profile.FinalBoss.final_defeated.bl_goad, nil)
  eq(ctx.mem.last('bl_goad'), 'won')
end

T['memory: a win over a powerless boss (Chicot) never counts as twisted'] = function()
  local ctx = setup({})
  ctx.mem.on_win({key = 'bl_final_heart', showdown = true, twists_on = true, powerless = true})
  eq(ctx.profile.FinalBoss.final_defeated.bl_final_heart, true, 'still a final boss win')
  eq(ctx.profile.FinalBoss.final_defeated_twisted.bl_final_heart, nil, 'not twisted')
end

T['memory: three losses make a nemesis, beating it breaks it'] = function()
  local ctx = setup({})
  for _ = 1, 3 do ctx.mem.on_loss('bl_x') end
  eq(ctx.mem.is_nemesis('bl_x'), true)
  local _, beaten = ctx.mem.on_win({key = 'bl_x'})
  eq(beaten, true)
  eq(ctx.mem.is_nemesis('bl_x'), false)
end

T['memory: older profile data gets its missing fields'] = function()
  local ctx = setup({FinalBoss = {bosses = {bl_x = {fights = 2}}}})
  local m = ctx.mem.data()
  eq(type(m.broken), 'table'); eq(type(m.interrupted), 'table'); eq(m.loss_seq, 0)
  eq(m.bosses.bl_x.fights, 2); eq(m.bosses.bl_x.wins, 0); eq(m.bosses.bl_x.losses, 0)
  ctx.mem.on_loss('bl_x')
  eq(ctx.mem.last('bl_x'), 'lost')
end

T['memory: damaged saved data is repaired, not trusted'] = function()
  local ctx = setup({FinalBoss = {bosses = {bl_x = 'junk', bl_y = {losses = 'a', last = 7}},
    broken = 5, interrupted = false, final_defeated = 'x', nemesis = 42, loss_seq = 'z'}})
  local m = ctx.mem.data()
  eq(m.bosses.bl_x, nil)
  eq(m.bosses.bl_y.losses, 0); eq(m.bosses.bl_y.last, nil)
  eq(type(m.broken), 'table'); eq(type(m.interrupted), 'table'); eq(type(m.final_defeated), 'table')
  eq(m.nemesis, nil); eq(m.loss_seq, 0)
  ctx.mem.on_fight('bl_y'); ctx.mem.on_loss('bl_y'); ctx.mem.on_win({key = 'bl_z', showdown = true})
  eq(m.bosses.bl_y.losses, 1)
  eq(ctx.mem.on_interrupt('bl_z'), m)
end

T['memory: a non-table FinalBoss value is replaced'] = function()
  local ctx = setup({FinalBoss = 'junk'})
  eq(type(ctx.mem.data()), 'table')
  eq(ctx.profile.FinalBoss, ctx.mem.data())
end

-- Nemesis presentation under stubs ---------------------------------------------------------------

--- Adds a stubbed stage to ctx: the current blind (key bl_x), its encounter, the avatar (opts.avatar),
--- effects and UI calls recorded in ctx.calls.
local function stage(ctx, opts)
  opts = opts or {}
  local calls = {}
  ctx.calls = calls
  local function rec(...) calls[#calls + 1] = {...} end
  local blind = {config = {blind = {key = 'bl_x'}}, T = {x = 0, y = 0, w = 1, h = 1}}
  ctx.blind = blind
  ctx.enc = {key = 'bl_x', boss = true, nemesis = opts.nemesis ~= false, ended = opts.ended or false}
  ctx.G.GAME = {FinalBoss = {encounter = ctx.enc}, blind = blind}
  ctx.G.UIT = {ROOT = 0, T = 1}
  ctx.G.C = {WHITE = {1, 1, 1, 1}, GOLD = {1, 0.8, 0, 1}}
  ctx.G.play = {T = {x = 1, y = 2, w = 3, h = 4}}
  local avatar_on = opts.avatar and true or false
  FinalBoss.config = {memory = opts.memory ~= false, fx = opts.fx ~= false}
  FinalBoss.avatar = {exists = function() return avatar_on end,
    set_aura = function(slot, level, colour) rec('set_aura', slot, level, colour) end}
  FinalBoss.moves = {performer = function(b)
    return {obj = avatar_on and 'AVATAR' or b, avatar = avatar_on}
  end}
  FinalBoss.effects = {
    aura = function(obj, colour, level) local p = {}; rec('aura', obj, colour, level, p); return p end,
    remove_aura = function(p) if p then rec('remove_aura', p) end end,
    burst = function(src, _, o) rec('burst', src, o) end}
  _G.UIBox = function(args)
    local box = {args = args}
    function box:remove() self.REMOVED = true; rec('tag_removed') end
    rec('tag', args)
    return box
  end
  _G.localize = function(key) return key end
  _G.attention_text = function(args) rec('banner', args) end
  _G.play_sound = function(name) rec('sound', name) end
  return ctx
end

local function find(calls, name)
  for _, c in ipairs(calls) do if c[1] == name then return c end end
  return nil
end

T['nemesis: the HUD chip gets the NEMESIS tag and a faint crimson aura; unpresent clears both'] = function()
  local ctx = stage(setup({}))
  ctx.mem.present(ctx.blind)
  local aura = find(ctx.calls, 'aura')
  assert(aura, 'aura on the HUD chip')
  eq(aura[2], ctx.blind); eq(aura[3], ctx.mem.CRIMSON); eq(aura[4], 1)
  local tag = find(ctx.calls, 'tag')
  assert(tag, 'tag')
  eq(tag[2].config.major, ctx.blind, 'tag follows the blind chip')
  eq(tag[2].definition.nodes[1].config.text, 'fb_nemesis_title')
  assert(not find(ctx.calls, 'set_aura') or find(ctx.calls, 'set_aura')[3] == 0, 'no avatar aura')
  ctx.mem.unpresent()
  assert(find(ctx.calls, 'tag_removed'), 'tag removed')
  eq(find(ctx.calls, 'remove_aura')[2], aura[5], 'the HUD aura removed')
  eq(ctx.mem.tag, nil); eq(ctx.mem.hud_aura, nil)
end

T['nemesis: a showdown avatar gets the strong crimson aura instead of the tag'] = function()
  local ctx = stage(setup({}), {avatar = true})
  ctx.mem.present(ctx.blind)
  local last
  for _, c in ipairs(ctx.calls) do if c[1] == 'set_aura' then last = c end end
  eq(last[2], 'nemesis'); eq(last[3], 2); eq(last[4], ctx.mem.CRIMSON)
  eq(find(ctx.calls, 'tag'), nil, 'no HUD tag'); eq(find(ctx.calls, 'aura'), nil, 'no HUD aura')
end

T['nemesis: nothing is presented with Boss memory off, for another boss or after the fight'] = function()
  for _, opts in ipairs({{memory = false}, {nemesis = false}, {ended = true}, {memory = false, avatar = true}}) do
    local ctx = stage(setup({}), opts)
    ctx.mem.present(ctx.blind)
    eq(find(ctx.calls, 'tag'), nil); eq(find(ctx.calls, 'aura'), nil)
    local sa = find(ctx.calls, 'set_aura')
    assert(not sa or sa[3] == 0, 'no avatar aura')
  end
  local ctx = stage(setup({}))
  ctx.mem.present({config = {blind = {key = 'bl_other'}}})
  eq(find(ctx.calls, 'tag'), nil, 'a different blind is never tagged')
  ctx = stage(setup({}))
  ctx.enc.recorded = true -- won below the dialogue ante: the encounter is never marked ended
  ctx.mem.present(ctx.blind)
  eq(find(ctx.calls, 'tag'), nil, 'not once the result is recorded')
end

T['nemesis: its own defeat line replaces the normal one, only with Boss memory on'] = function()
  local ctx = stage(setup({}))
  eq(ctx.mem.defeat_line(ctx.enc, 'defeat'), 'nemesis_defeat')
  eq(ctx.mem.defeat_line(ctx.enc, 'close'), nil)
  eq(ctx.mem.defeat_line({key = 'bl_x', nemesis = false}, 'defeat'), nil)
  eq(ctx.mem.defeat_line(nil, 'defeat'), nil)
  FinalBoss.config.memory = false
  eq(ctx.mem.defeat_line(ctx.enc, 'defeat'), nil)
end

T['nemesis: the celebration bursts gold only with screen effects; banner and gong always'] = function()
  local ctx = stage(setup({}))
  ctx.mem.celebrate()
  local burst = find(ctx.calls, 'burst')
  assert(burst, 'gold burst'); eq(burst[3].colour, ctx.G.C.GOLD)
  eq(burst[2].w, 3, 'over the play area')
  local banner = find(ctx.calls, 'banner')
  eq(banner[2].text, 'fb_nemesis_defeated'); eq(banner[2].colour, ctx.G.C.GOLD)
  eq(find(ctx.calls, 'sound')[2], 'gong')
  ctx = stage(setup({}), {fx = false})
  ctx.mem.celebrate()
  eq(find(ctx.calls, 'burst'), nil)
  assert(find(ctx.calls, 'banner') and find(ctx.calls, 'sound'), 'banner and gong without fx')
end

T['nemesis: F9 makes the current boss the saved nemesis and presents it'] = function()
  local ctx = stage(setup({FinalBoss = {broken = {bl_x = true}}}), {nemesis = false})
  local saves = ctx.saves
  eq(ctx.mem.fake_nemesis(), 'bl_x')
  eq(ctx.profile.FinalBoss.nemesis, 'bl_x'); eq(ctx.profile.FinalBoss.broken.bl_x, nil)
  eq(ctx.enc.nemesis, true); eq(ctx.saves, saves + 1)
  eq(ctx.enc.fake_nemesis, true, 'this encounter is marked (no Nemesis Slayer for it)')
  assert(find(ctx.calls, 'tag'), 'presented at once')
  ctx.mem.fake_nemesis()
  eq(ctx.enc.fake_nemesis, true, 'a second press keeps the mark')
  ctx.enc.ended = true
  eq(ctx.mem.fake_nemesis(), nil, 'not after the fight')
  ctx = stage(setup({}))
  ctx.enc.boss = false
  eq(ctx.mem.fake_nemesis(), nil, 'small and big blinds are never a nemesis')
  ctx = stage(setup({}))
  eq(ctx.mem.fake_nemesis(), 'bl_x')
  eq(ctx.enc.fake_nemesis, nil, 'already the real nemesis: not marked')
end

T['nemesis: the HUD tag sits on the chip top edge, below the effect text rows'] = function()
  local ctx = stage(setup({}))
  ctx.mem.present(ctx.blind)
  local cfg = find(ctx.calls, 'tag')[2].config
  eq(cfg.align, 'tm')
  assert(cfg.offset.y > 0, 'pushed down onto the chip (tm alone puts it above the chip)')
end

T['nemesis: a failing presentation is logged, never raised'] = function()
  local ctx = stage(setup({}))
  _G.UIBox = function() error('ui boom') end
  local n = #ctx.logs
  ctx.mem.present(ctx.blind)
  _G.attention_text = function() error('banner boom') end
  ctx.mem.celebrate()
  FinalBoss.effects.remove_aura = function() error('aura boom') end
  ctx.mem.unpresent()
  eq(#ctx.logs, n + 3, 'three errors logged')
end

return T

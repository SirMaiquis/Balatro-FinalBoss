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

return T

-- deaths.play routing under stubs (no game): fx gate, unknown names, built-in deaths, failure handling
-- and the death-safe filter for modder recipes. Drawing itself is not testable without love.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

--- Fresh deaths module with stubbed globals. Returns D, ctx; ctx.calls is the ordered call log.
local function setup(death, opts)
  opts = opts or {}
  local ctx = {calls = {}, args = {}, logs = {}}
  local function rec(name)
    return function(...)
      ctx.calls[#ctx.calls + 1] = name
      ctx.args[name] = {...}
      if opts.fail == name then error('boom ' .. name) end
    end
  end
  _G.G = {ROOM = {jiggle = 0}, play = {T = {x = 1, y = 1, w = 5, h = 3}},
    E_MANAGER = {add_event = function() end}}
  _G.Event = function(t) return t end
  _G.play_sound = function() end
  _G.darken = function(c) return c end
  local effects = {}
  for _, name in ipairs({'scatter', 'burst', 'ring', 'sweep', 'crack', 'pour', 'curse', 'stamp'}) do
    effects[name] = rec(name)
  end
  _G.FinalBoss = {
    config = {fx = not opts.fx_off},
    registry = {get = function() return {death = death} end},
    effects = effects,
    fx = {play = rec('flash')},
    moves = {boss_colour = function() return {1, 0, 0, 1} end,
      step_colour = function(_, _, src) return src.colour end, voice = function() return 1 end},
    util = {
      guard = function(_, fn, ...) return pcall(fn, ...) end,
      log = function(level, msg) ctx.logs[#ctx.logs + 1] = level .. ':' .. msg end,
    },
  }
  package.loaded['src.deaths'] = nil
  return require('src.deaths'), ctx
end

local blind = {config = {blind = {key = 'bl_final_x'}}}

local function count(ctx, name)
  local n = 0
  for _, c in ipairs(ctx.calls) do if c == name then n = n + 1 end end
  return n
end

T['deaths.play: screen effects off keeps the 1.0 explosion'] = function()
  local D, ctx = setup('hearts', {fx_off = true})
  eq(D.play(blind, 0, 0, 2, 2, false), false)
  eq(#ctx.calls, 0, 'nothing should have played')
end

T['deaths.play: no death or unknown name keeps the 1.0 explosion'] = function()
  local D = setup(nil)
  eq(D.play(blind, 0, 0, 2, 2, false), false, 'no death')
  D = setup('kaboom')
  eq(D.play(blind, 0, 0, 2, 2, false), false, 'unknown name')
end

T['deaths.play: every built-in death runs and flashes once'] = function()
  for _, name in ipairs({'hearts', 'leaves', 'acorn', 'flood'}) do
    local D, ctx = setup(name)
    eq(D.play(blind, 0, 0, 2, 2, false), true, name)
    eq(count(ctx, 'flash'), 1, name .. ' flash')
  end
  local D, ctx = setup('bell') -- the bell flashes later, when it breaks
  eq(D.play(blind, 0, 0, 2, 2, false), true, 'bell')
  eq(count(ctx, 'ring'), 1)
end

T['acorn cracks with lines only (bare) and the flood pours, never fills'] = function()
  local D, ctx = setup('acorn')
  D.play(blind, 0, 0, 2, 2, false)
  eq(ctx.args.crack[3].bare, true, 'acorn crack must be bare')
  D, ctx = setup('flood')
  D.play(blind, 0, 0, 2, 2, false)
  eq(count(ctx, 'pour'), 1, 'flood pours')
  eq(count(ctx, 'sweep'), 1, 'flood sweeps')
  eq(count(ctx, 'crack'), 0, 'flood must not use the filled crack')
end

T['deaths.play: failure before the flash falls back, after it only logs'] = function()
  local D, ctx = setup('hearts', {fail = 'flash'})
  eq(D.play(blind, 0, 0, 2, 2, false), false, 'failed before common: 1.0 explosion')
  D, ctx = setup('hearts', {fail = 'scatter'})
  eq(D.play(blind, 0, 0, 2, 2, false), true, 'failed after common: no second explosion')
  eq(count(ctx, 'flash'), 1, 'flash is not doubled')
end

T['deaths.play: a recipe only runs death-safe effects'] = function()
  local D, ctx = setup({{effect = 'burst'}, {effect = 'curse'}, {effect = 'sweep'}, {effect = 'stamp'}})
  eq(D.play(blind, 0, 0, 2, 2, false), true)
  eq(count(ctx, 'burst'), 1)
  eq(count(ctx, 'sweep'), 1)
  eq(count(ctx, 'curse'), 0, 'curse is not death-safe')
  eq(count(ctx, 'stamp'), 0, 'stamp is not death-safe')
  local warns = 0
  for _, l in ipairs(ctx.logs) do if l:find('^warn:') then warns = warns + 1 end end
  eq(warns, 2, 'one warning per skipped effect')
end

return T

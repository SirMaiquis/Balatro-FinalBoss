-- The vignette screen shader under stubs: it must never ask Steamodded to send a uniform the
-- compiled shader does not report (Steamodded crashes on that; seen on Android GPU drivers).
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

--- Loads src/fx.lua with a compiled shader that reports the given uniforms. Returns F and the
--- registered ScreenShader.
local function setup(uniforms)
  local screen
  _G.SMODS = {Shader = function() end, ScreenShader = function(t) screen = t end}
  local shader = {hasUniform = function(_, name) return uniforms[name] == true end}
  _G.G = {SHADERS = {FinalBoss_vignette = shader}, GAME = {}, SETTINGS = {}}
  _G.FinalBoss = {mod = {prefix = 'FinalBoss'}, config = {fx = true}}
  package.loaded['src.fx'] = nil
  local F = require('src.fx')
  return F, screen
end

T['fx vignette: applies and sends both uniforms when the shader has them'] = function()
  local F, screen = setup({fb_intensity = true, fb_tint = true})
  F.vignette.intensity = 0.5
  eq(screen:should_apply(), true, 'should_apply')
  local vars = screen:send_vars()
  eq(vars.fb_intensity, 0.5, 'fb_intensity')
  eq(vars.fb_tint ~= nil, true, 'fb_tint sent')
end

T['fx vignette: skipped, and sends nothing, when the driver drops a uniform'] = function()
  local F, screen = setup({fb_tint = true})
  F.vignette.intensity = 0.5
  eq(screen:should_apply(), false, 'should_apply')
  eq(next(screen:send_vars()), nil, 'no uniforms sent')
end

T['fx vignette: skipped when the shader failed to load'] = function()
  local F, screen = setup({})
  _G.G.SHADERS = {}
  F.vignette.intensity = 0.5
  eq(screen:should_apply(), false, 'should_apply')
end

return T

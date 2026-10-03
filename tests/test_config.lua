local T = {}

local function defaults()
  package.loaded['config'] = nil
  return require('config')
end

T['config: boss moves are on by default'] = function()
  assert(defaults().moves == true, 'moves must default to true')
end

T['config: phase twists are off by default'] = function()
  assert(defaults().phase_twists == false, 'phase_twists must default to false')
end

return T

local T = {}

local function defaults()
  package.loaded['config'] = nil
  return require('config')
end

T['config: boss moves are on by default'] = function()
  assert(defaults().moves == true, 'moves must default to true')
end

return T

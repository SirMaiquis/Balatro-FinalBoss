--- FinalBoss 2.0 entry point: builds the FinalBoss namespace and loads src/ modules in order.
FinalBoss = {}
FinalBoss.mod = SMODS.current_mod
FinalBoss.config = SMODS.current_mod.config
FinalBoss.VERSION = SMODS.current_mod.version

local function load_file(path)
  local chunk, err = SMODS.load_file(path)
  assert(chunk, ('FinalBoss: failed to load %s: %s'):format(path, tostring(err)))
  return chunk()
end

-- Order matters: util and logic first; hooks last (it wires everything together).
local MODULES = {'util', 'logic', 'registry', 'music', 'fx', 'ui'}

for _, name in ipairs(MODULES) do
  FinalBoss[name] = load_file('src/' .. name .. '.lua')
  if name == 'util' then
    -- Saved configs from v1.0.0 or older 2.x builds may miss keys: fill them from defaults.
    FinalBoss.util.fill_defaults(FinalBoss.config, load_file('config.lua'))
  end
end

FinalBoss.register_encounter = FinalBoss.registry.register
FinalBoss.encounters = {vanilla = load_file('src/encounters/vanilla.lua')}

FinalBoss.util.log('info', 'FinalBoss ' .. tostring(FinalBoss.VERSION) .. ' loaded')

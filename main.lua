--- FinalBoss entry point: builds the FinalBoss namespace and loads src/ modules in order.
FinalBoss = {}
FinalBoss.mod = SMODS.current_mod
FinalBoss.config = SMODS.current_mod.config
FinalBoss.VERSION = SMODS.current_mod.version
FinalBoss.timescale = 1 -- slow-motion factor (lovely/timescale.toml); only cinematic.lua changes it

-- Mods list icon: Steamodded shows the atlas '<prefix>_modicon' (assets/1x|2x/icon.png, tools/make_art.py).
SMODS.Atlas{key = 'modicon', path = 'icon.png', px = 34, py = 34}

local function load_file(path)
  local chunk, err = SMODS.load_file(path)
  assert(chunk, ('FinalBoss: failed to load %s: %s'):format(path, tostring(err)))
  return chunk()
end

-- Order matters: util and logic first; hooks last (it wires everything together).
local MODULES = {'util', 'logic', 'registry', 'music', 'fx', 'effects', 'arena', 'avatar', 'hpbar', 'cinematic',
  'moves', 'ui', 'dialogue', 'director', 'quips', 'devtools', 'hooks'}

for _, name in ipairs(MODULES) do
  FinalBoss[name] = load_file('src/' .. name .. '.lua')
  if name == 'util' then
    -- Saved configs from older builds may miss keys: fill them from defaults.
    FinalBoss.util.fill_defaults(FinalBoss.config, load_file('config.lua'))
  end
end

FinalBoss.register_encounter = FinalBoss.registry.register
load_file('src/encounters/vanilla.lua') -- registers the vanilla bosses

FinalBoss.util.log('info', 'FinalBoss ' .. tostring(FinalBoss.VERSION) .. ' loaded')

--- FinalBoss entry point: builds the FinalBoss namespace and loads src/ modules in order.
FinalBoss = {}
FinalBoss.mod = SMODS.current_mod
FinalBoss.config = SMODS.current_mod.config
FinalBoss.VERSION = SMODS.current_mod.version
FinalBoss.timescale = 1 -- slow-motion factor (lovely/timescale.toml); only cinematic.lua and phases.lua change it

-- Mods list icon: Steamodded shows the atlas '<prefix>_modicon' (assets/1x|2x/icon.png, tools/make_art.py).
SMODS.Atlas{key = 'modicon', path = 'icon.png', px = 34, py = 34}
-- Curse marks and the Needle's needle (assets/1x|2x/curse_marks.png, tools/make_art.py): card-sized
-- frames, 71 x 95 like the vanilla card atlases (game.lua:1014-1016); cells: logic.MARK_FRAMES.
SMODS.Atlas{key = 'curse_marks', path = 'curse_marks.png', px = 71, py = 95}

local function load_file(path)
  local chunk, err = SMODS.load_file(path)
  assert(chunk, ('FinalBoss: failed to load %s: %s'):format(path, tostring(err)))
  return chunk()
end

-- Order matters: util and logic first; hooks last (it wires everything together).
local MODULES = {'util', 'logic', 'personality', 'registry', 'music', 'fx', 'effects', 'curse', 'arena', 'avatar',
  'hpbar', 'cinematic', 'moves', 'deaths', 'phases', 'memory', 'achievements', 'ui', 'dialogue', 'director',
  'quips', 'devtools', 'hooks'}

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

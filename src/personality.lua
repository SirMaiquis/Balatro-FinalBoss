--- Boss personalities (1.2): the voice of a boss's run comments (fb_p_<personality>_<moment>_N).
--- Vanilla bosses are listed here; bosses from other mods pass register_encounter{personality = ...}
--- (default bully, logic.DEFAULT_PERSONALITY). The registry stores it on each entry.
local P = {}

P.VANILLA = {
  bl_ox = 'bully', bl_wall = 'bully', bl_tooth = 'bully', bl_club = 'bully', bl_goad = 'bully',
  bl_psychic = 'smug', bl_eye = 'smug', bl_mark = 'smug', bl_window = 'smug',
  bl_needle = 'killer', bl_manacle = 'killer', bl_pillar = 'killer', bl_serpent = 'killer', bl_hook = 'killer',
  bl_final_heart = 'venom', bl_final_leaf = 'venom', bl_plant = 'venom', bl_head = 'venom',
  bl_wheel = 'chaos', bl_flint = 'chaos', bl_fish = 'chaos', bl_final_acorn = 'chaos',
  bl_house = 'royal', bl_arm = 'royal', bl_mouth = 'royal', bl_water = 'royal', bl_final_vessel = 'royal',
  bl_final_bell = 'royal',
}

--- The personality a boss's lines use (its registry entry: register_encounter, else this table, else bully).
function P.of(blind_key)
  return FinalBoss.registry.get(blind_key).personality
end

return P

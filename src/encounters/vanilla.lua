--- Vanilla boss encounters: blind key -> voice pitch. All use tier 'auto'
--- (showdowns become full tier, regular bosses light tier).
local BOSSES = {
  bl_hook = 0.95, bl_ox = 0.8, bl_house = 1.0, bl_wall = 0.75, bl_wheel = 1.15,
  bl_arm = 0.85, bl_club = 1.1, bl_fish = 1.2, bl_psychic = 1.25, bl_goad = 0.9,
  bl_water = 1.05, bl_window = 1.1, bl_manacle = 0.85, bl_eye = 1.2, bl_mouth = 1.0,
  bl_plant = 1.15, bl_serpent = 0.8, bl_pillar = 0.75, bl_needle = 1.3, bl_head = 1.05,
  bl_tooth = 0.95, bl_flint = 0.85, bl_mark = 1.1,
  bl_final_acorn = 0.8, bl_final_leaf = 0.9, bl_final_vessel = 0.7,
  bl_final_heart = 0.75, bl_final_bell = 1.0,
}

-- In unit tests FinalBoss is absent: only the data table is returned.
if FinalBoss and FinalBoss.register_encounter then
  for key, pitch in pairs(BOSSES) do
    FinalBoss.register_encounter{blind = key, tier = 'auto', voice = {pitch = pitch}}
  end
end

return BOSSES

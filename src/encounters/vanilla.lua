--- Vanilla boss encounters: voice pitch and boss moves (1.1). All use tier 'auto' (showdowns become
--- full tier, regular bosses light tier). A recipe is a list of effect steps for one trigger kind
--- (see src/moves.lua and README "Boss moves"): target = where it lands, colour = 'suit' or a
--- G.C name (default: the boss colour), sound = {vanilla sound, pitch, volume} (times the voice pitch).
local BOSSES = {
  -- The Hook: discards 2 random cards per hand. A chain whips the two hooked cards, which jolt.
  bl_hook = {pitch = 0.95, moves = {
    play = {defer = true, {effect = 'glare', target = 'cards', line = true}, {effect = 'fling', target = 'cards'},
      sound = {'slice1', 0.9, 0.5}},
  }},
  -- The Ox: playing the most played hand sets money to $0. Horn shake (the performer's juice) + drain.
  bl_ox = {pitch = 0.8, moves = {
    hand_debuff = {{effect = 'drain', target = 'source', amount = 'money'}, sound = {'crumple1', 0.7, 0.5}},
  }},
  -- The House: first hand drawn face down. A sweep over the hand.
  bl_house = {pitch = 1.0, moves = {
    flipped = {{effect = 'sweep', target = 'hand'}, sound = {'whoosh2', 0.8, 0.4}},
  }},
  -- The Wall: extra large blind. The target cracks and grows.
  bl_wall = {pitch = 0.75, moves = {
    start = {{effect = 'crack', target = 'hud_target'}, sound = {'multhit1', 0.6, 0.5}},
  }},
  -- The Wheel: 1 in 7 cards face down. The flipped card spins.
  bl_wheel = {pitch = 1.15, moves = {
    flipped = {{effect = 'spin', target = 'cards'}, sound = {'cardSlide1', 1.2, 0.4}},
  }},
  -- The Arm: lowers the played hand's level. The hand name is slammed.
  bl_arm = {pitch = 0.85, moves = {
    hand_debuff = {{effect = 'crack', target = 'hud_hand_name', style = 'slam'}, sound = {'multhit2', 0.7, 0.5}},
  }},
  -- The Club: Clubs debuffed. Club-coloured hexes on the cursed cards.
  bl_club = {pitch = 1.1, moves = {
    card_debuff = {{effect = 'stamp', target = 'cards', glyph = 'hex', colour = 'suit'}, sound = {'tarot1', 0.8, 0.35}},
  }},
  -- The Fish: cards drawn face down after each hand. A splash over the hand.
  bl_fish = {pitch = 1.2, moves = {
    flipped = {{effect = 'sweep', target = 'hand', colour = 'blue'}, sound = {'whoosh1', 1.1, 0.4}},
  }},
  -- The Psychic: must play 5 cards. Hypnotic rings on the played cards.
  bl_psychic = {pitch = 1.25, moves = {
    hand_debuff = {{effect = 'glare', target = 'cards'}, sound = {'magic_crumple', 1.2, 0.4}},
  }},
  -- The Goad: Spades debuffed.
  bl_goad = {pitch = 0.9, moves = {
    card_debuff = {{effect = 'stamp', target = 'cards', glyph = 'hex', colour = 'suit'}, sound = {'tarot1', 0.75, 0.35}},
  }},
  -- The Water: starts with 0 discards. A wash over the discards counter.
  bl_water = {pitch = 1.05, moves = {
    start = {{effect = 'sweep', target = 'hud_discards', colour = 'blue'}, {effect = 'crack', target = 'hud_discards'},
      sound = {'whoosh_long', 1.2, 0.35}},
  }},
  -- The Window: Diamonds debuffed.
  bl_window = {pitch = 1.1, moves = {
    card_debuff = {{effect = 'stamp', target = 'cards', glyph = 'hex', colour = 'suit'}, sound = {'tarot1', 0.85, 0.35}},
  }},
  -- The Manacle: -1 hand size. Chains clamp the hand.
  bl_manacle = {pitch = 0.85, moves = {
    start = {{effect = 'chain', target = 'hand'}, sound = {'cardSlide2', 0.6, 0.6}},
  }},
  -- The Eye: no repeated hand type. A piercing glare (beam + rings).
  bl_eye = {pitch = 1.2, moves = {
    hand_debuff = {{effect = 'glare', target = 'cards', line = true}, sound = {'magic_crumple2', 1.3, 0.4}},
  }},
  -- The Mouth: only one hand type. A chomp (the performer's juice) + glare.
  bl_mouth = {pitch = 1.0, moves = {
    hand_debuff = {{effect = 'glare', target = 'cards'}, sound = {'crumple3', 0.8, 0.5}},
  }},
  -- The Plant: face cards debuffed. Vines on them.
  bl_plant = {pitch = 1.15, moves = {
    card_debuff = {{effect = 'stamp', target = 'cards', glyph = 'vine'}, sound = {'paper1', 0.8, 0.4}},
  }},
  -- The Serpent: always draws 3. A snake trail over the hand.
  bl_serpent = {pitch = 0.8, moves = {
    draw = {{effect = 'sweep', target = 'hand'}, sound = {'whoosh1', 0.7, 0.45}},
  }},
  -- The Pillar: cards played this ante debuffed. Cracks on them.
  bl_pillar = {pitch = 0.75, moves = {
    card_debuff = {{effect = 'stamp', target = 'cards', glyph = 'crack'}, sound = {'crumple2', 0.7, 0.4}},
  }},
  -- The Needle: one hand only. A pierce flash on the hands counter.
  bl_needle = {pitch = 1.3, moves = {
    start = {{effect = 'crack', target = 'hud_hands'}, sound = {'slice1', 1.4, 0.45}},
  }},
  -- The Head: Hearts debuffed.
  bl_head = {pitch = 1.05, moves = {
    card_debuff = {{effect = 'stamp', target = 'cards', glyph = 'hex', colour = 'suit'}, sound = {'tarot1', 0.9, 0.35}},
  }},
  -- The Tooth: -$1 per card played. Bite marks on the played cards + coins drained.
  bl_tooth = {pitch = 0.95, moves = {
    play = {{effect = 'stamp', target = 'played', glyph = 'crack'}, {effect = 'drain', target = 'source', amount = 'played'},
      sound = {'coin3', 0.8, 0.5}},
  }},
  -- The Flint: base chips and mult halved. Sparks + both panels crack.
  bl_flint = {pitch = 0.85, moves = {
    modify = {{effect = 'burst', target = 'source'}, {effect = 'crack', target = 'hud_chips'},
      {effect = 'crack', target = 'hud_mult'}, sound = {'slice1', 1.3, 0.45}},
  }},
  -- The Mark: face cards drawn face down. An X on each.
  bl_mark = {pitch = 1.1, moves = {
    flipped = {{effect = 'stamp', target = 'cards', glyph = 'x'}, sound = {'tarot2', 0.8, 0.35}},
  }},
  bl_final_acorn = {pitch = 0.8},
  bl_final_leaf = {pitch = 0.9},
  bl_final_vessel = {pitch = 0.7},
  bl_final_heart = {pitch = 0.75},
  bl_final_bell = {pitch = 1.0},
}

-- In unit tests FinalBoss is absent: only the data table is returned.
if FinalBoss and FinalBoss.register_encounter then
  for key, def in pairs(BOSSES) do
    FinalBoss.register_encounter{blind = key, tier = 'auto', voice = {pitch = def.pitch}, moves = def.moves,
      death = def.death}
  end
end

return BOSSES

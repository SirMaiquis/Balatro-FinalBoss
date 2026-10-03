--- Vanilla boss encounters: voice pitch and boss moves (1.1). All use tier 'auto' (showdowns become
--- full tier, regular bosses light tier). A recipe is a list of effect steps for one trigger kind
--- (see src/moves.lua and README "Boss moves"): target = where it lands, colour = 'suit' or a
--- G.C name (default: the boss colour), sound = {vanilla sound, pitch, volume} (times the voice pitch;
--- on a step: played when that step runs). The blind-start bosses (kind 'set') play the moment the blind
--- is set: a recount overlay shows their counter going from its old value to its new one, and its cue
--- steps play as the count starts (src/effects.lua recount).
--- The card_debuff bosses leave curse marks (effect 'curse', style suit/vine/crack: src/curse.lua) that
--- stay on each cursed card while the curse holds.
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
  -- The House: first hand drawn face down. While the cards are dealt (live), a sweep runs over the
  -- hand and each face-down card flashes as it lands in its slot (each: once per card).
  bl_house = {pitch = 1.0, moves = {
    flipped = {live = true, {effect = 'sweep', target = 'hand', time = 1.0}, {effect = 'land', target = 'cards', each = true},
      sound = {'whoosh2', 0.8, 0.4}},
  }},
  -- The Wall: extra large blind. The target shows the normal boss target, a bar slams it, it cracks
  -- and counts up to the Wall's real target, landing with a thud.
  bl_wall = {pitch = 0.75, moves = {
    set = {{effect = 'recount', target = 'hud_target', value = 'target', hold = 0.3, time = 0.85,
      impact = {'multhit1', 0.55, 0.55}, cue = {{effect = 'crack', target = 'hud_target', style = 'slam',
      sound = {'glass1', 0.6, 0.35}}}}},
  }},
  -- The Wheel: 1 in 7 cards face down. The flipped card spins.
  bl_wheel = {pitch = 1.15, moves = {
    flipped = {{effect = 'spin', target = 'cards'}, sound = {'cardSlide1', 1.2, 0.4}},
  }},
  -- The Arm: lowers the played hand's level. The Raised Fist slams onto the level as it drops (the
  -- impact sound plays with the slam, in sync with the game's level change).
  bl_arm = {pitch = 0.85, moves = {
    hand_debuff = {{effect = 'fist', target = 'hud_hand_level', impact = {'multhit2', 0.7, 0.55}}},
  }},
  -- The Club: Clubs debuffed. A dark Club-coloured frame and a Club badge stay on each cursed card.
  bl_club = {pitch = 1.1, moves = {
    card_debuff = {{effect = 'curse', target = 'cards', style = 'suit', colour = 'suit'}, sound = {'tarot1', 0.8, 0.35}},
  }},
  -- The Fish: cards drawn face down after each hand. A splash over the hand.
  bl_fish = {pitch = 1.2, moves = {
    flipped = {{effect = 'sweep', target = 'hand', colour = 'blue'}, sound = {'whoosh1', 1.1, 0.4}},
  }},
  -- The Psychic: must play 5 cards. Hypnotic rings on the played cards.
  bl_psychic = {pitch = 1.25, moves = {
    hand_debuff = {{effect = 'glare', target = 'cards'}, sound = {'magic_crumple', 1.2, 0.4}},
  }},
  -- The Goad: Spades debuffed (suit frame and badge).
  bl_goad = {pitch = 0.9, moves = {
    card_debuff = {{effect = 'curse', target = 'cards', style = 'suit', colour = 'suit'}, sound = {'tarot1', 0.75, 0.35}},
  }},
  -- The Water: starts with 0 discards. The discards counter shows the old count, a wash drains it to 0.
  bl_water = {pitch = 1.05, moves = {
    set = {{effect = 'recount', target = 'hud_discards', value = 'discards', hold = 0.2, time = 0.8,
      cue = {{effect = 'sweep', target = 'hud_discards', colour = 'blue', time = 0.8, sound = {'whoosh_long', 1.2, 0.35}}}}},
  }},
  -- The Window: Diamonds debuffed (suit frame and badge).
  bl_window = {pitch = 1.1, moves = {
    card_debuff = {{effect = 'curse', target = 'cards', style = 'suit', colour = 'suit'}, sound = {'tarot1', 0.85, 0.35}},
  }},
  -- The Manacle: -1 hand size. The hand's card-count label shows the old size, chains clamp the hand
  -- and it drops by one.
  bl_manacle = {pitch = 0.85, moves = {
    set = {{effect = 'recount', target = 'hand_limit', value = 'hand_size', hold = 0.2, time = 0.8,
      cue = {{effect = 'chain', target = 'hand', sound = {'cardSlide2', 0.6, 0.6}}}}},
  }},
  -- The Eye: no repeated hand type. A piercing glare (beam + rings).
  bl_eye = {pitch = 1.2, moves = {
    hand_debuff = {{effect = 'glare', target = 'cards', line = true}, sound = {'magic_crumple2', 1.3, 0.4}},
  }},
  -- The Mouth: only one hand type. A chomp (the performer's juice) + glare.
  bl_mouth = {pitch = 1.0, moves = {
    hand_debuff = {{effect = 'glare', target = 'cards'}, sound = {'crumple3', 0.8, 0.5}},
  }},
  -- The Plant: face cards debuffed. Vines grow over them and stay.
  bl_plant = {pitch = 1.15, moves = {
    card_debuff = {{effect = 'curse', target = 'cards', style = 'vine'}, sound = {'paper1', 0.8, 0.4}},
  }},
  -- The Serpent: always draws 3. A snake crawls from the deck to the hand as the 3 cards are dealt,
  -- arriving with the last one.
  bl_serpent = {pitch = 0.8, moves = {
    draw = {{effect = 'snake', target = 'hand'}, sound = {'whoosh1', 0.7, 0.45}},
  }},
  -- The Pillar: cards played this ante debuffed. Cracks spread across them and stay.
  bl_pillar = {pitch = 0.75, moves = {
    card_debuff = {{effect = 'curse', target = 'cards', style = 'crack'}, sound = {'crumple2', 0.7, 0.4}},
  }},
  -- The Needle: one hand only. Above the game's "-N" popup, a needle stabs into the hands counter,
  -- which flashes red, shakes and drops one hand at a time (a tick per step) down to 1.
  bl_needle = {pitch = 1.3, moves = {
    set = {{effect = 'recount', target = 'hud_hands', value = 'hands', hold = 0.1, top = true, step = 0.18,
      lead = 0.3, tick = {'card1', 1.25, 0.5},
      cue = {{effect = 'needle', target = 'hud_hands', impact = {'slice1', 1.4, 0.5}}}}},
  }},
  -- The Head: Hearts debuffed (suit frame and badge).
  bl_head = {pitch = 1.05, moves = {
    card_debuff = {{effect = 'curse', target = 'cards', style = 'suit', colour = 'suit'}, sound = {'tarot1', 0.9, 0.35}},
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

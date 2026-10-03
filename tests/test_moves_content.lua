local logic = require('src.logic')
local T = {}

local function bosses()
  _G.FinalBoss = nil
  package.loaded['src.encounters.vanilla'] = nil
  return require('src.encounters.vanilla')
end

-- Spec §2.4: regular boss -> trigger kind of its recipe.
local REGULAR = {
  bl_hook = 'play', bl_tooth = 'play', bl_flint = 'modify',
  bl_arm = 'hand_debuff', bl_ox = 'hand_debuff', bl_psychic = 'hand_debuff', bl_eye = 'hand_debuff',
  bl_mouth = 'hand_debuff',
  bl_club = 'card_debuff', bl_goad = 'card_debuff', bl_window = 'card_debuff', bl_head = 'card_debuff',
  bl_plant = 'card_debuff', bl_pillar = 'card_debuff',
  bl_wheel = 'flipped', bl_house = 'flipped', bl_mark = 'flipped', bl_fish = 'flipped',
  bl_manacle = 'set', bl_wall = 'set', bl_needle = 'set', bl_water = 'set',
  bl_serpent = 'draw',
}

T['every vanilla boss has a numeric voice pitch'] = function()
  local n = 0
  for key, def in pairs(bosses()) do
    n = n + 1
    assert(type(def) == 'table' and type(def.pitch) == 'number', key .. ' needs {pitch = n}')
  end
  assert(n == 28, 'expected 28 vanilla bosses, got ' .. n)
end

T['the 23 regular bosses have their spec recipe kind'] = function()
  local b = bosses()
  local n = 0
  for key, kind in pairs(REGULAR) do
    n = n + 1
    assert(b[key] and b[key].moves and b[key].moves[kind], key .. ' needs a ' .. kind .. ' recipe')
  end
  assert(n == 23, 'spec lists 23 regular bosses, got ' .. n)
end

--- A recipe sounds when it plays (recipe.sound), when one of its steps runs (step.sound, also on a
--- recount's cue steps), at its impact (a fist's, needle's or recount's own impact sound: the fist
--- landing in sync with the game's level change, the needle stabbing in, the count landing on the new
--- value) or on each step of a stepwise count (step.tick).
local function is_sound(s) return type(s) == 'table' and type(s[1]) == 'string' end

local function has_sound(recipe)
  if is_sound(recipe.sound) then return true end
  for _, step in ipairs(recipe) do
    if is_sound(step.sound) or is_sound(step.impact) or is_sound(step.tick) then return true end
    for _, cue in ipairs(step.cue or {}) do
      if is_sound(cue.sound) or is_sound(cue.impact) then return true end
    end
  end
  return false
end

T['every vanilla recipe is valid, has a sound, known glyphs and curse styles'] = function()
  for key, def in pairs(bosses()) do
    if def.moves then
      local clean, warnings = logic.clean_moves(def.moves)
      assert(clean, key .. ' moves invalid')
      assert(#warnings == 0, key .. ': ' .. table.concat(warnings, '; '))
      for kind, recipe in pairs(def.moves) do
        assert(has_sound(recipe), key .. '.' .. kind .. ' needs a sound')
        for _, step in ipairs(recipe) do
          if step.effect == 'stamp' then
            assert(logic.GLYPHS[step.glyph], key .. '.' .. kind .. ': unknown glyph ' .. tostring(step.glyph))
          end
          if step.effect == 'curse' then
            assert(logic.CURSE_STYLES[step.style], key .. '.' .. kind .. ': unknown style ' .. tostring(step.style))
          end
        end
      end
    end
  end
end

T['card-debuff bosses leave persistent curse marks in the spec styles'] = function()
  local b = bosses()
  for _, k in ipairs({'bl_club', 'bl_goad', 'bl_window', 'bl_head'}) do
    local step = b[k].moves.card_debuff[1]
    assert(step.effect == 'curse' and step.style == 'suit' and step.colour == 'suit', k .. ': suit frame')
    assert(step.target == 'cards', k .. ': on the cursed cards')
  end
  local plant, pillar = b.bl_plant.moves.card_debuff[1], b.bl_pillar.moves.card_debuff[1]
  assert(plant.effect == 'curse' and plant.style == 'vine', 'Plant: vines')
  assert(pillar.effect == 'curse' and pillar.style == 'crack', 'Pillar: cracks')
  assert(b.bl_mark.moves.flipped[1].glyph == 'x', 'Mark: x')
end

T['the Arm slams a fist onto the hand level'] = function()
  local r = bosses().bl_arm.moves.hand_debuff
  assert(#r == 1 and r[1].effect == 'fist' and r[1].target == 'hud_hand_level', 'fist on the level')
  assert(type(r[1].impact) == 'table' and type(r[1].impact[1]) == 'string', 'impact sound')
  assert(r.sound == nil, 'the impact sound replaces the recipe sound (it would play before the slam)')
end

T['the Hook reads its hooked cards in a deferred event'] = function()
  local play = bosses().bl_hook.moves.play
  assert(play.defer == true, 'defer')
  assert(play[1].effect == 'glare' and play[1].line and play[2].effect == 'fling', 'chain whip + fling')
end

T['blind-start bosses recount their counter from the old value to the new one'] = function()
  local b = bosses()
  local want = {bl_wall = {'hud_target', 'target'}, bl_water = {'hud_discards', 'discards'},
    bl_needle = {'hud_hands', 'hands'}, bl_manacle = {'hand_limit', 'hand_size'}}
  for key, w in pairs(want) do
    local r = b[key].moves.set
    assert(b[key].moves.start == nil, key .. ': no delayed start move any more')
    local step = r[1]
    assert(step.effect == 'recount' and step.target == w[1] and step.value == w[2], key .. ': recount ' .. w[2])
    assert(type(step.cue) == 'table' and #step.cue >= 1, key .. ': a cue plays as the count starts')
    local total = (step.hold or 0) + (step.time or 0)
    if step.step then -- stepwise: the needle's fall, then one step per drop (4 -> 1 at the most hands)
      total = (step.hold or 0) + logic.NEEDLE_FALL + step.step * (#logic.count_steps(4, 1) - 1)
    end
    assert(total >= 0.5 and total <= 1.4, key .. ': about a second, got ' .. total)
  end
  local wall = b.bl_wall.moves.set[1]
  assert(wall.cue[1].effect == 'crack', 'the Wall cracks')
  assert(type(wall.impact) == 'table', 'the Wall lands with a thud')
  assert(b.bl_water.moves.set[1].cue[1].effect == 'sweep', 'the Water washes')
  assert(b.bl_manacle.moves.set[1].cue[1].effect == 'chain', 'the Manacle clamps')
  for _, key in ipairs({'bl_wall', 'bl_water', 'bl_manacle'}) do
    local step = b[key].moves.set[1]
    assert(not step.step and not step.top, key .. ': counts smoothly and waits for the popup, as before')
  end
end

T['the Needle stabs its needle into the hands counter, which drops one step at a time above the popup'] = function()
  local step = bosses().bl_needle.moves.set[1]
  assert(step.effect == 'recount' and step.target == 'hud_hands' and step.value == 'hands', 'recount hands')
  assert(step.top == true, 'drawn above the -N popup and starts at once')
  assert(type(step.step) == 'number' and step.step >= 0.12 and step.step <= 0.25, 'about 0.18 s per step')
  assert(type(step.tick) == 'table' and type(step.tick[1]) == 'string', 'a sound per step')
  assert(type(step.lead) == 'number' and step.lead >= logic.NEEDLE_FALL, 'waits for the needle to land')
  local cue = step.cue[1]
  assert(#step.cue == 1 and cue.effect == 'needle' and cue.target == 'hud_hands', 'the needle stabs the counter')
  assert(type(cue.impact) == 'table' and type(cue.impact[1]) == 'string', 'the stab sounds as it lands')
end

T['the House sweeps while the face-down cards are dealt, each flashes as it lands'] = function()
  local r = bosses().bl_house.moves.flipped
  assert(r.live == true, 'live: plays during the draw')
  local sweep, land
  for _, step in ipairs(r) do
    if step.effect == 'sweep' then sweep = step end
    if step.effect == 'land' then land = step end
  end
  assert(sweep and sweep.target == 'hand' and not sweep.each and (sweep.time or 0) >= 0.9, 'a ~1 s sweep, once')
  assert(land and land.each and land.target == 'cards', 'a flash on each card')
end

T['the Serpent delivers its cards with a snake'] = function()
  local r = bosses().bl_serpent.moves.draw
  assert(r[1].effect == 'snake' and r[1].target == 'hand', 'snake to the hand')
end

-- Spec §2.4: final boss -> trigger kinds of its recipes. The blind-start finals (Acorn, Vessel) play at
-- blind set ('set'), like The Wall; the Leaf curses cards like The Plant.
local FINAL = {
  bl_final_acorn = {'set'}, bl_final_leaf = {'card_debuff', 'joker_sold'}, bl_final_vessel = {'set'},
  bl_final_heart = {'drawn'}, bl_final_bell = {'drawn'},
}

T['the 5 final bosses have their spec kinds and a signature'] = function()
  local b = bosses()
  for key, kinds in pairs(FINAL) do
    local moves = b[key].moves
    assert(moves, key .. ' needs moves')
    for _, kind in ipairs(kinds) do assert(moves[kind], key .. ' needs a ' .. kind .. ' recipe') end
    assert(moves.start == nil, key .. ': no delayed start move (blind-start finals play at set)')
    assert(moves.signature, key .. ' needs a signature recipe')
    for _, step in ipairs(moves.signature) do
      assert(step.target ~= 'cards' and step.target ~= 'played', key .. ': a signature has no trigger cards')
    end
  end
end

T['final-boss recipes follow the spec'] = function()
  local b = bosses()
  local vessel = b.bl_final_vessel.moves.set[1]
  assert(vessel.effect == 'recount' and vessel.target == 'hud_target' and vessel.value == 'target',
    'Vessel counts its target from the normal one up to its own')
  assert(vessel.cue[1].effect == 'crack' and vessel.cue[1].target == 'hud_target' and vessel.cue[1].style == 'fill',
    'Vessel fills its target')
  assert(type(vessel.impact) == 'table', 'the count lands with a thud')
  local total = (vessel.hold or 0) + (vessel.time or 0)
  assert(total >= 0.5 and total <= 1.4, 'about a second, got ' .. total)
  assert(not vessel.step and not vessel.top, 'counts smoothly and waits for the popup, like the Wall')
  local heart = b.bl_final_heart.moves.drawn[1]
  assert(heart.effect == 'glare' and heart.target == 'cards' and heart.line, 'Heart beams onto the disabled joker')
  local bell = b.bl_final_bell.moves.drawn
  assert(bell[1].effect == 'ring' and bell[2].effect == 'ring' and bell[2].target == 'cards', 'Bell rings + forced card')
  local acorn = b.bl_final_acorn.moves.set
  assert(acorn[1].effect == 'sweep' and acorn[1].target == 'jokers' and acorn[2].effect == 'burst', 'Acorn sweeps jokers')
  local leaf = b.bl_final_leaf.moves.card_debuff[1]
  assert(leaf.effect == 'curse' and leaf.style == 'vine' and leaf.target == 'cards', 'Leaf vines stay on the cards')
  assert(b.bl_final_leaf.moves.joker_sold[1].effect == 'burst', 'Leaf leaves burst')
end

T['every vanilla final boss has its own death'] = function()
  local b = bosses()
  local want = {bl_final_heart = 'hearts', bl_final_leaf = 'leaves', bl_final_acorn = 'acorn',
    bl_final_vessel = 'flood', bl_final_bell = 'bell'}
  for key, death in pairs(want) do
    assert(b[key].death == death, key .. ' death should be ' .. death .. ', got ' .. tostring(b[key].death))
    assert(logic.DEATHS[death], death .. ' is not a built-in death')
  end
end

T['regular bosses keep no death (only final bosses explode)'] = function()
  for key, def in pairs(bosses()) do
    if not key:find('^bl_final_') then assert(def.death == nil, key .. ' should have no death') end
  end
end

return T

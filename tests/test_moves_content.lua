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
  bl_manacle = 'start', bl_wall = 'start', bl_needle = 'start', bl_water = 'start',
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

--- A recipe sounds when it plays (recipe.sound), or at its impact (a fist step's own impact sound,
--- played when the fist lands in sync with the game's level change).
local function has_sound(recipe)
  if recipe.sound and type(recipe.sound[1]) == 'string' then return true end
  for _, step in ipairs(recipe) do
    if step.effect == 'fist' and type(step.impact) == 'table' and type(step.impact[1]) == 'string' then return true end
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

return T

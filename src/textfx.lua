--- Punchline text effects (1.4): registers logic.TEXT_EFFECTS as Steamodded DynaText effects, so
--- localization lines can write {E:fb_rage}word{} (and so can other mods' boss lines).
--- smods 26.829.0: SMODS.localize_box turns an {E:<key>} part into a DynaText with
--- config.text_effect = <key>, and DynaText:update calls effect.func(dynatext, index, letter) for each
--- letter every frame, after resetting letter.r and letter.scale (lovely/text_effect.toml).
--- Letter fields used: offset {x, y} (font units; draw subtracts it, so +y is up), r, scale, dims,
--- colour, letter (the love Text drawn). The motion maths is pure, in logic.letter_motion /
--- effect_colour / grawlix_symbol / glitch_glyph. Motion stops under reduced motion or config.fx
--- off; colours stay. Each letter runs in pcall: on error it is left as is (logged once per effect).
local X = {}

local function L() return FinalBoss.logic end -- resolved per call (tests swap it)

-- Glyph cache: love Text objects keyed by font then symbol; built once, never per frame.
local glyphs = setmetatable({}, {__mode = 'k'})

local function glyph(font, s)
  local by_font = glyphs[font]
  if not by_font then
    by_font = {}
    glyphs[font] = by_font
  end
  local g = by_font[s]
  if not g then
    g = love.graphics.newText(font, s)
    by_font[s] = g
  end
  return g
end

local function still()
  return (G.SETTINGS and G.SETTINGS.reduced_motion) or not FinalBoss.config.fx
end

local motion, scratch = {}, {} -- reused every call
local logged = {}

--- The glyph string to show for this letter, or nil for its real glyph.
local function swap_for(key, index, t, reduced)
  if key == 'fb_grawlix' then return L().grawlix_symbol(index, t, reduced) end
  if key == 'fb_glitch' then return L().glitch_glyph(index, t, reduced) end
  return nil
end

local function apply(key, dynatext, index, letter)
  local t = G.TIMERS.REAL
  local reduced = still()
  local string_ = dynatext.strings and dynatext.strings[dynatext.focused_string]
  local count = string_ and string_.letters and #string_.letters or nil
  -- Work everything out first, then write: a failure leaves the letter untouched.
  local m = L().letter_motion(key, t, index, reduced, count, motion)
  local h = letter.dims and letter.dims.y or 0
  local colour = L().effect_colour(key, reduced and 0 or t, index, scratch)
  local s = swap_for(key, index, t, reduced)
  local real = letter.fb_real or letter.letter
  local shown = s and glyph(dynatext.font.FONT, s) or real

  letter.offset.x = -m.dx * h
  letter.offset.y = -m.dy * h
  letter.r = (letter.r or 0) + m.r
  letter.scale = (letter.scale or 1) * m.scale
  if colour then
    local own = letter.fb_colour or {} -- one table per letter, kept across frames
    own[1], own[2], own[3], own[4] = colour[1], colour[2], colour[3], colour[4]
    letter.fb_colour = own
    letter.colour = own
  end
  if s or letter.fb_real then
    letter.fb_real = real
    letter.letter = shown
  end
end

for _, key in ipairs(FinalBoss.logic.TEXT_EFFECTS) do
  SMODS.DynaTextEffect{
    key = key,
    prefix_config = {key = false}, -- the tag is exactly {E:fb_rage}, no mod prefix
    func = function(dynatext, index, letter)
      local ok, err = pcall(apply, key, dynatext, index, letter)
      if not ok and not logged[key] then
        logged[key] = true
        FinalBoss.util.log('warn', ('text effect %s failed: %s'):format(key, tostring(err)))
      end
    end,
  }
end

return X

--- Hype moments (1.4): a clutch, comeback, stacked luck, photo finish or 100x overkill gets big screen text,
--- a layered sting and, for a meltdown, the boss chip's jolt and a screen shake. The text, the jolt and the
--- shake are screen effects (config.fx); the sting is sound and plays without it. hype.play never says a line:
--- the director decides that. Every piece runs on its own, so a failing draw or sound is logged and skipped
--- (not util.guard: that disables the mod for the run, too harsh for a cosmetic).
local H = {}
H.HOLD = 1.6        -- seconds the text stays
H.SCALE = 1.8       -- big text
H.SHAKE = 10        -- fx.play('shake') amount of a meltdown
H.STING = {{'gong', 0.9}, {'multhit2', 0.7}} -- layered vanilla sounds
H.VOLUME = 0.6

local function safe(name, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then FinalBoss.util.log('error', ('hype.%s failed: %s'):format(name, tostring(err))) end
  return ok
end

local function reduced() return G.SETTINGS and G.SETTINGS.reduced_motion end

local function boss_colour(blind)
  return (blind and blind.config and blind.config.blind and blind.config.blind.boss_colour) or G.C.RED
end

--- The localized text of kind, or the English fallback when the dictionary has no entry.
local function text_of(kind)
  local fallback = FinalBoss.logic.HYPE_TEXT[kind]
  local key = 'fb_hype_' .. kind
  local s = localize(key)
  if type(s) ~= 'string' or s == '' or s == 'ERROR' or s == key then return fallback end
  return s
end

--- The text as a prebuilt static node: attention_text pops and pulses plain strings, but leaves a node alone.
local function static_text(s, colour)
  return {n = G.UIT.O, config = {object = DynaText({scale = H.SCALE, string = s, colours = {colour},
    shadow = true, silent = true})}}
end

local function show_text(kind, blind)
  local colour = boss_colour(blind)
  local s = text_of(kind)
  attention_text{text = reduced() and static_text(s, colour) or s, scale = H.SCALE, hold = H.HOLD, major = G.play,
    align = 'cm', offset = {x = 0, y = 0}, colour = colour}
end

local function sting()
  for _, s in ipairs(H.STING) do play_sound(s[1], s[2], H.VOLUME) end
end

local function meltdown(blind, enc)
  local r = FinalBoss.logic.meltdown_reaction(reduced())
  local reg = enc and enc.key and FinalBoss.registry.get(enc.key)
  FinalBoss.avatar.poke(blind, r, reg and reg.voice and reg.voice.pitch)
  FinalBoss.fx.play('shake', blind, H.SHAKE)
end

--- kind: 'clutch' | 'comeback' | 'photo_finish' | 'lucky' | 'overkill' (logic.HYPE_TEXT keys; others do
--- nothing). opts = {meltdown, blind, enc}: meltdown adds the chip's reaction and the shake (visuals only).
function H.play(kind, opts)
  if not (kind and FinalBoss.logic.HYPE_TEXT[kind]) then return end
  opts = opts or {}
  local blind = opts.blind or (G.GAME and G.GAME.blind)
  if FinalBoss.config.fx then
    safe('text', show_text, kind, blind)
    if opts.meltdown then safe('meltdown', meltdown, blind, opts.enc) end
  end
  safe('sting', sting)
end

return H

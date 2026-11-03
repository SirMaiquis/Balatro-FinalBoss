--- Hype moments (1.4): a clutch, comeback, stacked luck, photo finish or 100x overkill gets big screen text,
--- a layered sting and, for a meltdown, the boss chip's jolt and a screen shake. The text, the jolt and the
--- shake are screen effects (config.fx); the sting is sound and plays without it. hype.play never says a line:
--- the director decides that. Every piece runs on its own, so a failing draw or sound is logged and skipped
--- (not util.guard: that disables the mod for the run, too harsh for a cosmetic).
--- The text looks like vanilla's attention_text (floating, popping letters in the boss colour, a pulse, no box)
--- but is built here: attention_text times its hold and fade on the TOTAL timer, which runs at game speed
--- (and FinalBoss.timescale), so at a high speed it was gone in a quarter second. This one lives on REAL
--- time. A thin dark outline keeps it readable when the boss colour matches the felt (The Club on green).
local H = {}
H.HOLD = 2.0        -- REAL seconds the text stays fully up
H.FADE = 0.35       -- REAL seconds of the pop-out / fade, then it is removed
H.SCALE = 2.4       -- big text (the first version's attention_text was 1.8)
H.MAXW = 12         -- long translations shrink to fit
H.OUTLINE = {0.06, 0.06, 0.09, 0.9} -- DynaText text_outline colour (copied per text)
H.OUTLINE_SCALE = 1.4 -- text_outline_scale: ~0.07 room units, about a third of a letter pixel at H.SCALE
H.SHAKE = 10        -- fx.play('shake') amount of a meltdown
H.STING = {{'gong', 0.9}, {'multhit2', 0.7}} -- layered vanilla sounds
H.VOLUME = 0.6
H.box = nil         -- the text's UIBox while it is up
H.token = 0         -- bumped by H.remove: pending timers of a removed text do nothing

local function safe(name, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then FinalBoss.util.log('error', ('hype.%s failed: %s'):format(name, tostring(err))) end
  return ok
end

local function reduced() return G.SETTINGS and G.SETTINGS.reduced_motion end

--- A fresh {r, g, b, a}: the fade writes its alpha, never the blind's own colour.
local function copy_colour(c)
  return {c[1], c[2], c[3], c[4] or 1}
end

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

--- After delay REAL seconds, fn runs every frame until it returns true. pause_force: also while the game
--- is paused (engine/event.lua skips paused events not created on pause); never blocks or waits.
--- An error is logged and ends it (the text is removed).
local function every_frame(token, fn, delay)
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = delay, timer = 'REAL',
    pause_force = true, blocking = false, blockable = false,
    func = function()
      if H.token ~= token then return true end -- removed (teardown, or a newer text)
      local ok, done = pcall(fn)
      if not ok then
        FinalBoss.util.log('error', 'hype.text timer failed: ' .. tostring(done))
        H.remove()
        return true
      end
      return done and true or false
    end}))
end

--- Remove the text if it is up and cancel its timers (run teardown via Dir.reset_stage, a newer text).
function H.remove()
  H.token = H.token + 1
  local box = H.box
  H.box = nil
  if box and not box.REMOVED then -- delete_run may have removed it already (remove_all of the stage)
    local ok, err = pcall(box.remove, box)
    if not ok then FinalBoss.util.log('error', 'hype.remove failed: ' .. tostring(err)) end
  end
end

local function show_text(kind, blind)
  H.remove()
  local still = reduced()
  local colour = copy_colour(boss_colour(blind))
  local outline = copy_colour(H.OUTLINE)
  local fading = {colour, outline}
  local base = {}
  for i, c in ipairs(fading) do base[i] = c[4] end
  -- As attention_text builds its DynaText; reduced motion: no pop in, float or pulse; same hold, then
  -- removed at once (no fade).
  local text = DynaText({string = text_of(kind), scale = H.SCALE, maxw = H.MAXW, colours = {colour},
    shadow = true, silent = true, text_outline = outline, text_outline_scale = H.OUTLINE_SCALE,
    float = (not still) or nil, pop_in = (not still) and 0 or nil, pop_in_rate = (not still) and 6 or nil})
  local box = UIBox{
    definition = {n = G.UIT.ROOT, config = {align = 'cm', padding = 0.03, r = 0.1, colour = {0, 0, 0, 0}},
      nodes = {{n = G.UIT.O, config = {draw_layer = 1, object = text}}}},
    config = {major = G.play, align = 'cm', offset = {x = 0, y = 0}, can_collide = false},
  }
  box.attention_text = true -- drawn in vanilla's late pass, above the cards
  H.box = box
  if not still and text.pulse then text:pulse(0.5) end
  local token = H.token
  local start
  every_frame(token, function()
    -- Reduced motion: removed at the end of the hold. An alpha fade would leave the DynaText shadow
    -- at full strength until removal.
    if still then H.remove(); return true end
    if not start then
      start = G.TIMERS.REAL
      if text.pop_out then text:pop_out(1 / H.FADE) end
    end
    local a = math.max(0, 1 - (G.TIMERS.REAL - start) / H.FADE)
    for i, c in ipairs(fading) do c[4] = base[i] * a end
    if a > 0 then return false end
    H.remove()
    return true
  end, H.HOLD)
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
    if not safe('text', show_text, kind, blind) then pcall(H.remove) end -- never leave a half-built text up
    if opts.meltdown then safe('meltdown', meltdown, blind, opts.enc) end
  end
  safe('sting', sting)
end

return H

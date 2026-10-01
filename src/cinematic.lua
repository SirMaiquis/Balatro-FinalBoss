--- Showdown cinematics: letterbox + title card + avatar fall-in before the
--- intro dialogue, and the slow-motion explosive finale. Owns FinalBoss.timescale.
local C = {}
C.BAR_H = 1.1
C.token = 0        -- bumped to cancel pending intro beats
C.phase = nil      -- 'intro' | 'dialogue' | 'finale' | nil
C.bars = nil       -- {top = UIBox, bottom = UIBox}
C.leaving = {}     -- bars sliding out, removed by a timer (or by reset if the queue is cleared)
C.title = nil
C.title_texts = nil -- {sub, name} DynaTexts of the title band (pop out before removal)
C.on_done, C.blind = nil, nil

local function reduced() return G.SETTINGS.reduced_motion end

--- Timer that is cancelled when C.token moves on (skip / reset / a new sequence).
local function after(delay, token, fn)
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = delay, timer = 'REAL', blocking = false,
    blockable = false, func = function()
      if C.token == token then FinalBoss.util.guard('cinematic_timer', fn) end
      return true
    end}))
end

--- Timer that always runs (cleanup that must survive skips).
local function later(delay, fn)
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = delay, timer = 'REAL', blocking = false,
    blockable = false, func = function() FinalBoss.util.guard('cinematic_cleanup', fn); return true end}))
end

local function make_bar(top)
  return UIBox{
    definition = {n = G.UIT.ROOT, config = {align = 'cm', colour = G.C.BLACK, minw = G.ROOM.T.w + 4,
      minh = C.BAR_H, r = 0}, nodes = {}},
    config = {major = G.ROOM_ATTACH, align = top and 'tm' or 'bm',
      offset = {x = 0, y = top and -C.BAR_H or C.BAR_H}, bond = 'Weak', can_collide = false},
  }
end

local function place_bars(bars, visible)
  for side, box in pairs(bars) do
    local hidden = (side == 'top') and -C.BAR_H or C.BAR_H
    box.alignment.offset = {x = 0, y = visible and 0 or hidden}
    if reduced() then box:align_to_major(); box:hard_set_VT() end -- T follows the offset next frame otherwise
  end
end

local function remove_title()
  if C.title then C.title:remove(); C.title = nil end
  C.title_texts = nil
end

--- Centre the title band in the free strip between the joker row and the play area. Vanilla's
--- boss-effect text (Blind:alert_debuff) is centred 1 unit above the play area's centre, so a band
--- that ends above G.play never overlaps it. Offset is from the centre of G.ROOM_ATTACH.
C.TITLE_Y = -1.8 -- fallback offset (vanilla layout: (2.61 + 5.29) / 2 - 11.5 / 2)

local function title_offset_y()
  local j, p = G.jokers and G.jokers.T, G.play and G.play.T
  if j and p then return (j.y + j.h + p.y) / 2 - G.ROOM.T.h / 2 end
  return C.TITLE_Y
end

local function show_title(blind)
  local c = (blind.config.blind and blind.config.blind.boss_colour) or G.C.RED
  local name = blind.loc_name or (blind.config.blind and blind.config.blind.name) or ''
  local band = mix_colours(c, G.C.BLACK, 0.25)
  band[4] = 0.85
  local sub = DynaText({string = {localize('fb_showdown_title')},
    colours = {G.C.WHITE}, scale = 0.6, shadow = true, pop_in = 0, pop_in_rate = 4, silent = true})
  local big = DynaText({string = {name}, colours = {c}, scale = 1.4,
    shadow = true, bump = true, pop_in = 0.2, pop_in_rate = 3, silent = true})
  C.title = UIBox{
    definition = {n = G.UIT.ROOT, config = {align = 'cm', colour = band, minw = G.ROOM.T.w, padding = 0.15, r = 0},
      nodes = {
        {n = G.UIT.R, config = {align = 'cm'}, nodes = {{n = G.UIT.O, config = {object = sub}}}},
        {n = G.UIT.R, config = {align = 'cm'}, nodes = {{n = G.UIT.O, config = {object = big}}}},
      }},
    config = {major = G.ROOM_ATTACH, align = 'cm', offset = {x = 0, y = title_offset_y()}, bond = 'Weak',
      can_collide = false},
  }
  C.title.attention_text = true -- drawn in vanilla's late pass, above the cards (the bars stay under)
  C.title_texts = {sub = sub, name = big}
  -- Slam: shake + pop (not under reduced motion); the background flash always runs (needs fx).
  if not reduced() then
    G.ROOM.jiggle = G.ROOM.jiggle + 6
    big:juice_up(0.6, 0.4)
  end
  FinalBoss.fx.play('flash', blind)
end

local function pop_out_title()
  local t = C.title_texts
  if not t then return end
  t.sub:pop_out(4)
  t.name:pop_out(3)
end

local function spawn_stage(fall)
  if FinalBoss.avatar.exists() or not C.blind then return end
  -- Read the score live: the player can win (or lose) while the intro is still running.
  local enc = (G.GAME.FinalBoss or {}).encounter
  local num = FinalBoss.director.num
  local total, required = num(G.GAME.chips), num(C.blind.chips)
  if not enc or enc.ended or total >= required then return end
  FinalBoss.avatar.spawn(C.blind, {fall = fall})
  FinalBoss.hpbar.create(FinalBoss.avatar.anchor(), C.blind, total, required)
end

local function land()
  if not FinalBoss.avatar.exists() then return end
  if not reduced() then G.ROOM.jiggle = G.ROOM.jiggle + 4 end
  local x, y, w, h = FinalBoss.avatar.position()
  local c = FinalBoss.avatar.anchor().dissolve_colours[2]
  local p = Particles(x, y + h * 0.7, w, h * 0.3, {timer = 0.01, scale = 0.3, speed = 3,
    lifespan = 0.8, colours = {c, G.C.WHITE}, fill = true})
  play_sound('slice1', 0.8, 0.6)
  later(0.5, function() p:fade(0.3) end)
  later(0.9, function() p:remove() end)
end

local function finish_intro()
  remove_title()
  C.phase = 'dialogue'
  local cb = C.on_done
  C.on_done = nil
  if cb then cb() end
end

function C.play_intro(blind, on_done)
  C.reset()
  C.token = C.token + 1
  local token = C.token
  C.phase, C.on_done, C.blind = 'intro', on_done, blind
  C.bars = {top = make_bar(true), bottom = make_bar(false)}
  place_bars(C.bars, true)
  play_sound('whoosh_long', 1, 0.5)
  after(0.4, token, function()
    show_title(blind)
    play_sound('gong', 0.9, 0.5)
    play_sound('timpani', 1, 0.5)
  end)
  after(2.6, token, pop_out_title) -- title held ~2.2 s, then the letters pop out
  after(2.9, token, function()
    remove_title()
    spawn_stage(not reduced())
  end)
  after(3.25, token, land)
  after(3.7, token, finish_intro)
end

function C.active() return C.phase == 'intro' end

--- Any key / click during the intro beats: jump to the end state, then start the dialogue.
function C.skip()
  if C.phase ~= 'intro' then return end
  C.token = C.token + 1
  remove_title()
  spawn_stage(false)
  FinalBoss.avatar.snap() -- skipped mid-fall: land it instantly
  finish_intro()
end

--- Called when the intro dialogue ends (or is skipped / absent): letterbox slides away.
function C.retract_bars()
  if C.bars then
    local bars = C.bars
    C.bars = nil
    place_bars(bars, false)
    for _, b in pairs(bars) do C.leaving[#C.leaving + 1] = b end
    later(0.5, function()
      for _, b in pairs(bars) do
        for i = #C.leaving, 1, -1 do
          if C.leaving[i] == b then table.remove(C.leaving, i); b:remove() end
        end
      end
    end)
  end
  if C.phase == 'dialogue' then C.phase = nil end
end

local function explode(blind, calm)
  local x, y, w, h = FinalBoss.avatar.position()
  FinalBoss.hpbar.remove()
  FinalBoss.avatar.remove()
  if not x then return end
  local c = (blind.config.blind and blind.config.blind.boss_colour) or G.C.RED
  local p = Particles(x, y, w, h, {timer = 0.005, scale = 0.6, speed = 8, lifespan = 2.0,
    colours = {c, G.C.WHITE, darken(c, 0.3)}, fill = true})
  FinalBoss.fx.play('flash', blind, '') -- '' = restore to the neutral colour vanilla eases to after a win
  G.ROOM.jiggle = G.ROOM.jiggle + (calm and 2 or 6)
  play_sound('explosion_release1', 1, 0.7)
  play_sound('glass1', 0.9, 0.6)
  later(1.2, function() p:fade(0.6) end)
  later(2.2, function() p:remove() end)
end

--- Winning hand: slow motion, violent shake + flashes while the defeat line plays, then boom.
--- Returns true when the finale started (the director then skips its own defeat effect).
function C.play_finale(blind)
  if not FinalBoss.avatar.exists() then return false end
  C.token = C.token + 1
  local token = C.token
  remove_title()
  C.retract_bars()
  C.phase = 'finale'
  local calm = reduced()
  if not calm then FinalBoss.timescale = 0.35 end
  FinalBoss.avatar.set_tremble(true)
  FinalBoss.avatar.set_dissolve(0.5, 1.0)
  play_sound('explosion_buildup1', 1, 0.6)
  for i = 0, 6 do
    after(i * 0.15, token, function() FinalBoss.avatar.flash(0.08) end)
  end
  later(0.8, function() FinalBoss.timescale = 1 end) -- always restored, even if the token moves on
  after(1.2, token, function() explode(blind, calm) end)
  later(1.6, function()
    if C.phase == 'finale' then C.phase = nil end
    FinalBoss.fx.stop() -- vignette and arena revert with the explosion (spec 7.2); both are idempotent
    FinalBoss.arena.stop()
  end)
  return true
end

--- The boss won: a last laugh, then the avatar fades away (the gloat quip plays as before).
function C.game_over(pitch)
  C.token = C.token + 1
  FinalBoss.timescale = 1
  remove_title()
  C.retract_bars()
  C.phase = nil
  FinalBoss.hpbar.remove()
  if not FinalBoss.avatar.exists() then return end
  FinalBoss.avatar.laugh(pitch)
  later(0.5, function() FinalBoss.avatar.fade_out(0.8) end)
end

function C.reset()
  C.token = C.token + 1
  FinalBoss.timescale = 1
  remove_title()
  if C.bars then for _, b in pairs(C.bars) do b:remove() end; C.bars = nil end
  for _, b in ipairs(C.leaving) do b:remove() end
  C.leaving = {}
  C.phase, C.on_done, C.blind = nil, nil, nil
end

return C

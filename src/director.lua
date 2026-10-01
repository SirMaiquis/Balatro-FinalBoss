--- The director: turns game events into encounter decisions and drives dialogue, music and FX.
local Dir = {}
Dir.INTRO_DELAY = 1.5 -- seconds after the blind is set, so the chip has landed
Dir.pending = nil     -- reaction to the last scored hand, waiting for the score to land (never saved)

--- Scores may be Talisman big numbers (tables); logic.lua only ever sees plain numbers.
local function num(x)
  if type(x) == 'table' and type(to_number) == 'function' then return to_number(x) end
  return tonumber(x) or 0
end

Dir.num = num

local function fight_numbers(blind)
  return num(G.GAME.chips), num(blind.chips)
end

local function stage_of(total, required)
  return FinalBoss.logic.wound_stage(FinalBoss.logic.hp_fraction(total, required))
end

function Dir.enabled()
  local st = G.GAME and G.GAME.FinalBoss
  return not (st and st.disabled_for_run)
end

function Dir.vars(blind)
  return {blind.loc_name or (blind.config.blind and blind.config.blind.name) or '?'}
end

local function current(blind_key)
  local st = FinalBoss.util.state()
  local enc = st.encounter
  local blind = G.GAME.blind
  if not enc or enc.tier == 'none' or not blind or not blind.config.blind then return nil end
  if blind_key and blind.config.blind.key ~= blind_key then return nil end
  return enc, blind, st
end

function Dir.on_blind_set(blind)
  local st = FinalBoss.util.state()
  FinalBoss.dialogue.reset(blind)
  local proto = blind.config.blind or {}
  if not proto.key then st.encounter = nil; return end
  local entry = FinalBoss.registry.get(proto.key)
  local is_showdown = (proto.boss and proto.boss.showdown) and true or false
  local tier = FinalBoss.logic.decide_tier{
    is_boss = blind.boss and true or false,
    is_showdown = is_showdown,
    entry_tier = entry.tier,
    ante = G.GAME.round_resets.ante,
    min_ante = FinalBoss.config.min_ante,
  }
  st.encounter = {key = proto.key, tier = tier, fired = {}, reactions = 0, phase = 1, track = nil,
    last_variant = {}, ended = false, last_hand_seen = nil, showdown = is_showdown,
    cinematic = (tier == 'full' and is_showdown and FinalBoss.config.cinematic) and true or false}
  st.lost_to = nil
  if tier == 'none' then return end
  if tier == 'full' then
    st.encounter.track = FinalBoss.music.pick_track(entry)
    FinalBoss.fx.play(entry.fx.intro, blind)
    if is_showdown then FinalBoss.arena.start(blind, 0) end
    if st.encounter.cinematic then
      FinalBoss.cinematic.play_intro(blind,
        function() FinalBoss.util.guard('intro', Dir.play_intro, proto.key) end)
      return
    end
  end
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = Dir.INTRO_DELAY, timer = 'REAL',
    blocking = false, blockable = false,
    func = function() FinalBoss.util.guard('intro', Dir.play_intro, proto.key); return true end}))
end

function Dir.play_intro(blind_key)
  local enc, blind = current(blind_key)
  -- In a cinematic showdown the letterbox retracts when the intro dialogue ends (or never starts).
  -- retract_bars is a no-op without bars, so it is safe for every encounter.
  local on_end = enc and enc.cinematic and FinalBoss.cinematic.retract_bars or nil
  local function nothing_to_say() FinalBoss.cinematic.retract_bars() end
  if not enc or not FinalBoss.config.dialogue or blind.disabled then return nothing_to_say() end
  local steps = {}
  for _, moment in ipairs(FinalBoss.logic.intro_sequence(enc.tier)) do
    local key = FinalBoss.registry.resolve(enc.key, moment, enc.last_variant)
    if key then steps[#steps + 1] = {key = key, vars = Dir.vars(blind)} end
  end
  if #steps == 0 then return nothing_to_say() end
  local entry = FinalBoss.registry.get(enc.key)
  FinalBoss.dialogue.play_sequence(blind, steps,
    FinalBoss.logic.line_duration(FinalBoss.config.intro_speed), entry.voice.pitch, on_end)
end

--- Continuing a saved run: restore FX and stage for an unfinished full encounter, never replay the intro.
function Dir.on_blind_loaded(blind)
  FinalBoss.dialogue.reset(blind) -- a loaded blind never has a live bubble
  local enc = (G.GAME.FinalBoss or {}).encounter
  if not enc or enc.tier ~= 'full' or enc.ended then return end
  if not (blind.config.blind and blind.config.blind.key == enc.key) then return end
  FinalBoss.fx.resume(blind)
  if not enc.showdown then return end
  local total, required = fight_numbers(blind)
  if total >= required then return end -- saved in the round summary: the fight is already won
  local stage = stage_of(total, required)
  FinalBoss.arena.resume(blind, stage)
  if enc.cinematic and FinalBoss.config.cinematic then
    FinalBoss.avatar.spawn(blind, {fall = false})
    FinalBoss.avatar.set_wound(stage)
    FinalBoss.hpbar.create(FinalBoss.avatar.anchor(), blind, total, required)
  end
end

--- Runs after vanilla's end-of-round event, so Mr. Bones saves are resolved.
function Dir.on_round_end()
  Dir.flush_pending()
  local st = FinalBoss.util.state()
  local enc = st.encounter
  if not enc then return end
  if G.STATE == G.STATES.GAME_OVER then
    enc.ended = true
    FinalBoss.fx.stop()
    FinalBoss.arena.stop(true)
    if enc.cinematic then FinalBoss.cinematic.game_over(FinalBoss.registry.get(enc.key).voice.pitch) end
  else
    st.lost_to = nil
  end
  FinalBoss.dialogue.end_intro()
  local blind = G.GAME.blind
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = 3, timer = 'REAL', blocking = false, blockable = false,
    func = function() FinalBoss.util.guard('hide_bubble', FinalBoss.dialogue.hide, blind); return true end}))
end

-- Whether G.GAME.chips already includes the just-scored hand at context.after. False per smods source
-- (evaluate_play queues the chip ease; context.after runs before it); re-confirmed in game at playtest.
Dir.SCORE_INCLUDES_HAND = false

function Dir.fire(moment, opts)
  opts = opts or {}
  local enc, blind = current()
  if not enc then return false end
  if not opts.force and not FinalBoss.logic.can_fire(moment, enc.tier, enc.fired, enc.reactions) then return false end
  enc.fired[moment] = true
  if FinalBoss.logic.REACTIONS[moment] then enc.reactions = enc.reactions + 1 end
  if enc.tier == 'full' and (moment == 'big_hand' or moment == 'close') then
    FinalBoss.fx.play('shake', blind)
    FinalBoss.fx.play('flash', blind)
  end
  if not FinalBoss.config.dialogue then return true end
  local key = FinalBoss.registry.resolve(enc.key, moment, enc.last_variant)
  if not key then return true end
  local entry = FinalBoss.registry.get(enc.key)
  FinalBoss.dialogue.say(blind, key, Dir.vars(blind), entry.voice.pitch,
    {force = opts.force or moment == 'defeat'})
  return true
end

function Dir.on_hand_after()
  local enc, blind, st = current()
  if not enc or enc.ended then return end
  local hands_played = G.GAME.current_round.hands_played
  if enc.last_hand_seen == hands_played then return end -- defensive: one evaluation per hand
  if FinalBoss.config.dev_mode then
    FinalBoss.util.log('info', ('dev: at after chips=%s delta=%s'):format(
      tostring(G.GAME.chips), tostring(SMODS.last_hand_score)))
  end
  enc.last_hand_seen = hands_played
  local delta = num(SMODS.last_hand_score)
  local chips = num(G.GAME.chips)
  local total = Dir.SCORE_INCLUDES_HAND and chips or (chips + delta)
  local required = num(blind.chips)
  local hands_left = G.GAME.current_round.hands_left
  -- Set before the game-over screen picks its quip; cleared in on_round_end if the run continues.
  if hands_left == 0 and total < required then st.lost_to = enc.key end
  local moment = FinalBoss.logic.detect_moments{delta = delta, total = total, required = required,
    hands_left = hands_left, fired = enc.fired, tier = enc.tier, reactions = enc.reactions}
  -- The reaction waits until the game shows the score (Dir.tick -> logic.score_landed), or the
  -- boss would spoil it. Everything above is decided now.
  Dir.flush_pending()
  Dir.pending = {start = chips, delta = delta, total = total, required = required, moment = moment,
    enc = enc, blind = blind, t0 = FinalBoss.util.now()}
end

--- The deferred reaction to a scored hand; dropped if its encounter is gone or over.
local function react(p)
  local enc, blind = current()
  if not enc or enc ~= p.enc or enc.ended then return end
  if FinalBoss.config.dev_mode then
    FinalBoss.util.log('info', ('dev: score landed chips=%s after %.2fs'):format(
      tostring(G.GAME.chips), FinalBoss.util.now() - p.t0))
  end
  if enc.tier == 'full' and enc.showdown then
    Dir.stage_hit(enc, blind, p.delta, p.total, p.required, p.moment)
  end
  if p.moment then Dir.fire(p.moment) end
end

--- Run a pending reaction now (blind defeated, round end: keeps the finale / game-over order).
function Dir.flush_pending()
  local p = Dir.pending
  if not p then return end
  Dir.pending = nil
  react(p)
end

local function check_pending()
  local p = Dir.pending
  local hand = G.GAME.current_round and G.GAME.current_round.current_hand
  if not FinalBoss.logic.score_landed(p.start, num(G.GAME.chips), p.delta, hand and hand.handname,
      FinalBoss.util.now() - p.t0) then return end
  Dir.pending = nil
  FinalBoss.util.guard('score_landed', react, p)
end

--- Stage reactions to a scored hand in a showdown (arena always; avatar when cinematic).
function Dir.stage_hit(enc, blind, delta, total, required, moment)
  local stage = stage_of(total, required)
  FinalBoss.arena.on_hit(stage)
  if not enc.cinematic then return end
  local size = FinalBoss.logic.hit_size(delta, required)
  FinalBoss.hpbar.update(total, required)
  FinalBoss.hpbar.damage(delta, size)
  FinalBoss.avatar.set_wound(stage)
  if moment == 'defeat' then
    -- The defeat line (fired next) shows during the shake. The flag is plain data on the saved
    -- encounter: on_blind_defeated runs seconds later, so the finale's phase is no use there.
    enc.finale = FinalBoss.cinematic.play_finale(blind) and true or nil
    return
  end
  FinalBoss.avatar.hit(size)
  if size == 'weak' then FinalBoss.avatar.laugh(FinalBoss.registry.get(enc.key).voice.pitch) end
end

function Dir.on_blind_disabled()
  Dir.fire('disabled')
end

function Dir.on_blind_defeated()
  Dir.flush_pending()
  local enc, blind = current()
  if not enc then return end
  enc.ended = true
  if enc.tier ~= 'full' then return end
  if enc.cinematic then
    -- The finale (started on the winning hand) owns the explosion; clean up if it never ran.
    if not enc.finale then
      FinalBoss.fx.play(FinalBoss.registry.get(enc.key).fx.defeat, blind)
      FinalBoss.hpbar.remove()
      FinalBoss.avatar.remove()
    end
  else
    FinalBoss.fx.play(FinalBoss.registry.get(enc.key).fx.defeat, blind)
  end
  FinalBoss.fx.stop()
  FinalBoss.arena.stop()
end

--- Per-frame tick (hooks: Game:update wrap). Cheap when nothing is on stage or pending.
function Dir.tick(dt)
  local A, V, H = FinalBoss.arena, FinalBoss.avatar, FinalBoss.hpbar
  if not (Dir.pending or A.active() or V.exists() or H.exists()) then return end
  if Dir.pending then check_pending() end
  V.tick(dt)
  H.tick(dt)
  A.tick(dt)
end

--- Remove every stage element and restore time, background and vignette (run teardown or a
--- guard failure). Each step is isolated so one failure cannot skip the others.
local resetting = false -- re-entrancy guard: a failing step must not recurse via util.guard

function Dir.reset_stage()
  Dir.pending = nil -- dropped, never run
  if resetting then return end
  resetting = true
  local ok, err = pcall(function()
    for _, step in ipairs({FinalBoss.cinematic.reset, FinalBoss.hpbar.remove, FinalBoss.avatar.remove,
        FinalBoss.arena.reset, FinalBoss.fx.reset}) do
      local sok, serr = pcall(step)
      if not sok then FinalBoss.util.log('error', 'reset_stage step failed: ' .. tostring(serr)) end
    end
  end)
  resetting = false
  if not ok then FinalBoss.util.log('error', 'reset_stage failed: ' .. tostring(err)) end
end

return Dir

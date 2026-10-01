--- The director: turns game events into encounter decisions and drives dialogue, music and FX.
local Dir = {}
Dir.INTRO_DELAY = 1.5 -- seconds after the blind is set, so the chip has landed

--- Scores may be Talisman big numbers (tables); logic.lua only ever sees plain numbers.
local function num(x)
  if type(x) == 'table' and type(to_number) == 'function' then return to_number(x) end
  return tonumber(x) or 0
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
  local tier = FinalBoss.logic.decide_tier{
    is_boss = blind.boss and true or false,
    is_showdown = (proto.boss and proto.boss.showdown) and true or false,
    entry_tier = entry.tier,
    ante = G.GAME.round_resets.ante,
    min_ante = FinalBoss.config.min_ante,
  }
  st.encounter = {key = proto.key, tier = tier, fired = {}, reactions = 0, phase = 1, track = nil,
    last_variant = {}, ended = false, last_hand_seen = nil}
  st.lost_to = nil
  if tier == 'none' then return end
  if tier == 'full' then
    st.encounter.track = FinalBoss.music.pick_track(entry)
    FinalBoss.fx.play(entry.fx.intro, blind)
  end
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = Dir.INTRO_DELAY, timer = 'REAL',
    blocking = false, blockable = false,
    func = function() FinalBoss.util.guard('intro', Dir.play_intro, proto.key); return true end}))
end

function Dir.play_intro(blind_key)
  if not FinalBoss.config.dialogue then return end
  local enc, blind = current(blind_key)
  if not enc then return end
  if blind.disabled then return end -- Chicot/Luchador already fired the disabled line
  local steps = {}
  for _, moment in ipairs(FinalBoss.logic.intro_sequence(enc.tier)) do
    local key = FinalBoss.registry.resolve(enc.key, moment, enc.last_variant)
    if key then steps[#steps + 1] = {key = key, vars = Dir.vars(blind)} end
  end
  if #steps == 0 then return end
  local entry = FinalBoss.registry.get(enc.key)
  FinalBoss.dialogue.play_sequence(blind, steps,
    FinalBoss.logic.line_duration(FinalBoss.config.intro_speed), entry.voice.pitch)
end

--- Continuing a saved run: restore FX for an unfinished full encounter, never replay the intro.
function Dir.on_blind_loaded(blind)
  FinalBoss.dialogue.reset(blind) -- a loaded blind never has a live bubble
  local enc = (G.GAME.FinalBoss or {}).encounter
  if not enc or enc.tier ~= 'full' or enc.ended then return end
  if blind.config.blind and blind.config.blind.key == enc.key then FinalBoss.fx.resume(blind) end
end

--- Runs after vanilla's end-of-round event, so Mr. Bones saves are resolved.
function Dir.on_round_end()
  local st = FinalBoss.util.state()
  local enc = st.encounter
  if not enc then return end
  if G.STATE == G.STATES.GAME_OVER then
    enc.ended = true
    FinalBoss.fx.stop()
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
  if moment then Dir.fire(moment) end
end

function Dir.on_blind_disabled()
  Dir.fire('disabled')
end

function Dir.on_blind_defeated()
  local enc, blind = current()
  if not enc then return end
  enc.ended = true
  if enc.tier == 'full' then
    FinalBoss.fx.play(FinalBoss.registry.get(enc.key).fx.defeat, blind)
    FinalBoss.fx.stop()
  end
end

--- Per-frame tick (hooks: Game:update wrap). Cheap when nothing is on stage.
function Dir.tick(dt)
  local A, V, H = FinalBoss.arena, FinalBoss.avatar, FinalBoss.hpbar
  if not (A.active() or V.exists() or H.exists()) then return end
  V.tick(dt)
  H.tick(dt)
  A.tick(dt)
end

--- Remove every stage element and restore time, background and vignette (run teardown or a
--- guard failure). Each step is isolated so one failure cannot skip the others.
function Dir.reset_stage()
  for _, step in ipairs({FinalBoss.cinematic.reset, FinalBoss.hpbar.remove, FinalBoss.avatar.remove,
      FinalBoss.arena.reset, FinalBoss.fx.reset}) do
    pcall(step)
  end
end

return Dir

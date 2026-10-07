--- The director: turns game events into encounter decisions and drives dialogue, music and FX.
local Dir = {}
Dir.INTRO_DELAY = 1.5 -- seconds after the blind is set, so the chip has landed
Dir.WEAK_LAUGH_DELAY = 0.5 -- seconds between the flinch of a weak hit and the laugh
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
  FinalBoss.moves.on_blind_set()
  FinalBoss.memory.unpresent()
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
  local cinematic = (tier == 'full' and is_showdown and FinalBoss.config.cinematic) and true or false
  st.encounter = {key = proto.key, tier = tier, fired = {}, track = nil,
    last_variant = {}, ended = false, last_hand_seen = nil, showdown = is_showdown, cinematic = cinematic,
    -- 1.1 phases: enc.phase (nil = phase I) and the twist state are plain saved data. Twists need
    -- phases, so they follow cinematics.
    twists_on = (cinematic and FinalBoss.config.phase_twists) and true or false,
    twists = {applied = {}, leaf_sold = false}}
  -- 1.1 memory: one fight per boss encounter, recorded at blind set (Continue never re-records).
  local enc = st.encounter
  enc.boss = blind.boss and true or false
  if enc.boss then
    FinalBoss.memory.on_fight(proto.key)
    enc.last = FinalBoss.memory.last(proto.key)
    enc.nemesis = FinalBoss.memory.is_nemesis(proto.key)
    -- Cinematic showdowns present the nemesis when the avatar lands (cinematic.spawn_stage).
    if not cinematic then FinalBoss.memory.present(blind) end
    -- 1.2: the intro jab, from the run as it is now. Bookkeeping only: a failure loses the jab
    -- (logged), never the encounter.
    local ok, err = pcall(FinalBoss.observe.on_blind_set, enc)
    if not ok then
      enc.jab = nil
      FinalBoss.util.log('warn', 'run observation failed: ' .. tostring(err))
    end
  end
  st.lost_to = nil
  if tier == 'none' then Dir.schedule_start(proto.key); return end
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

--- No intro will play: the boss's start move comes INTRO_DELAY after the blind is set (the chip
--- has landed). With an intro, Dir.play_intro starts it when the intro ends.
function Dir.schedule_start(blind_key)
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = Dir.INTRO_DELAY, timer = 'REAL',
    blocking = false, blockable = false,
    func = function() FinalBoss.util.guard('start_move', FinalBoss.moves.start, blind_key); return true end}))
end

function Dir.play_intro(blind_key)
  local enc, blind = current(blind_key)
  local O = FinalBoss.observe
  local jab_step -- the intro step that says the run jab (nil: no jab in this intro)
  -- When the intro ends (or never starts): the letterbox retracts (a no-op without bars) and the
  -- boss performs its start move (moves.start runs once per encounter). shown: how many intro lines
  -- the player saw (dialogue.end_intro); the jab becomes the run's last jab only if it was one of them.
  local function finish(shown)
    if jab_step and (shown or 0) >= jab_step then O.mark_said(enc) end
    FinalBoss.cinematic.retract_bars()
    FinalBoss.moves.start(blind_key)
  end
  if not enc or not FinalBoss.config.dialogue or blind.disabled then return finish() end
  -- A hand is already being played (the delayed intro came late): skip the intro for this
  -- encounter rather than start it only to cut it at once.
  if G.STATES and G.STATE == G.STATES.HAND_PLAYED then return finish() end
  local steps = {}
  -- 1.1 memory: a rematch or nemesis line may replace the name line (full) or the intro (light).
  -- 1.2: the run jab replaces the threat.
  local jab_moment = (enc.jab and not enc.jab_said) and enc.jab.moment or nil
  local plan, threat = FinalBoss.logic.apply_jab(FinalBoss.logic.intro_plan{tier = enc.tier,
    memory = FinalBoss.config.memory, last = enc.last, nemesis = enc.nemesis, roll = math.random()}, jab_moment)
  for i, moment in ipairs(plan) do
    local jab = i == threat and moment ~= 'intro'
    local key = FinalBoss.registry.resolve(enc.key, moment, enc.last_variant, jab and O.jab_opts(enc) or nil)
    if not key and jab then -- no line for this jab: the threat after all
      jab = false
      key = FinalBoss.registry.resolve(enc.key, 'intro', enc.last_variant)
    end
    if key then
      steps[#steps + 1] = {key = key, vars = jab and O.jab_vars(enc, blind) or Dir.vars(blind)}
      -- Never replayed (a Continue never reruns the intro); booked as the last jab once shown (finish).
      if jab then enc.jab_said, jab_step = true, #steps end
    end
  end
  if #steps == 0 then return finish() end
  local entry = FinalBoss.registry.get(enc.key)
  FinalBoss.dialogue.play_sequence(blind, steps,
    FinalBoss.logic.line_duration(FinalBoss.config.intro_speed), entry.voice.pitch, finish)
end

--- Continuing a saved run: restore FX and stage for an unfinished full encounter, never replay the intro.
function Dir.on_blind_loaded(blind)
  FinalBoss.dialogue.reset(blind) -- a loaded blind never has a live bubble
  local enc = (G.GAME.FinalBoss or {}).encounter
  -- 1.1: the nemesis presentation is visual, so rebuild it (HUD now; the avatar's aura below).
  -- present() checks the encounter: this blind, nemesis, not over, Boss memory on.
  FinalBoss.memory.unpresent()
  FinalBoss.memory.present(blind)
  -- Curse marks (any tier) come back on the cursed cards already in hand. Visual only: a failure is
  -- logged and the rest of the restore still runs.
  local ok, err = pcall(FinalBoss.moves.restore_marks, blind)
  if not ok then FinalBoss.util.log('warn', 'curse mark restore failed: ' .. tostring(err)) end
  if not enc or enc.tier ~= 'full' or enc.ended then return end
  if not (blind.config.blind and blind.config.blind.key == enc.key) then return end
  FinalBoss.fx.resume(blind)
  if not enc.showdown then return end
  local total, required = fight_numbers(blind)
  if total >= required then return end -- saved in the round summary: the fight is already won
  local stage = stage_of(total, required)
  FinalBoss.arena.start(blind, stage)
  if enc.cinematic and FinalBoss.config.cinematic then
    FinalBoss.avatar.spawn(blind, {fall = false})
    FinalBoss.avatar.set_wound(stage)
    FinalBoss.hpbar.create(FinalBoss.avatar.anchor(), blind, total, required)
    FinalBoss.phases.restore(enc, blind) -- after spawn and create: stance aura and phase marker
    FinalBoss.memory.present(blind) -- the avatar is back: its crimson aura replaces the HUD tag
  end
end

--- Runs after vanilla's end-of-round event, so Mr. Bones saves are resolved.
function Dir.on_round_end()
  Dir.flush_pending()
  FinalBoss.phases.reset() -- (the twist clean-up runs ungated in hooks.lua's end_round wrap)
  local st = FinalBoss.util.state()
  local enc = st.encounter
  local over = G.STATE == G.STATES.GAME_OVER
  if enc and over then
    enc.ended = true
    if enc.boss and not enc.recorded then
      if FinalBoss.memory.on_loss(enc.key) then enc.recorded = true end -- this boss ended the run
    end
  end
  FinalBoss.memory.unpresent() -- after the loss is recorded (memory's safe: a visual error is only logged)
  if not enc then return end
  if over then
    FinalBoss.fx.stop()
    FinalBoss.arena.stop(true)
    if enc.cinematic then
      FinalBoss.dialogue.end_intro()
      FinalBoss.dialogue.hide(G.GAME.blind) -- no bubble at the game-over screen: Jimbo has the line
      FinalBoss.cinematic.game_over(FinalBoss.registry.get(enc.key).voice.pitch)
    end
  else
    st.lost_to = nil
  end
  FinalBoss.dialogue.end_intro()
  local blind = G.GAME.blind
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = 3, timer = 'REAL', blocking = false, blockable = false,
    func = function() FinalBoss.util.guard('hide_bubble', FinalBoss.dialogue.hide, blind); return true end}))
end

--- opts: force (no once-per-blind check, no cooldown), line (say another moment's line for this
--- moment: 1.1 the nemesis's defeat line; 1.2 the overkill line, a Chicot counter jab; it falls back to
--- the moment's own line when it has none), skip_boss (with line: logic.resolve_prefix skips the boss
--- level), vars (the line's vars; default Dir.vars), hand (the hand the line is said on; default the
--- current hand id, G.GAME.current_round.hands_played), free (1.2 poke and grab lines: no gate and no
--- bookkeeping at all, so fired, the light tier's spacing and the comment caps stay untouched; the line
--- is not forced, so it never cuts a line said in the last REACTION_GAP seconds, and it does not start
--- that gap itself, so a reaction right after it still shows: dialogue.say).
function Dir.fire(moment, opts)
  opts = opts or {}
  local enc, blind = current()
  if not enc then return false end
  local L = FinalBoss.logic
  local cr = G.GAME.current_round
  local hand = opts.hand or (cr and cr.hands_played)
  if not opts.force and not opts.free then
    -- 1.2 run comments have their own gate (the light tier's spacing and single read, the full-tier
    -- cap, no consecutive hands); every other moment: once per blind, the light tier's spacing.
    local ok
    if L.COMMENTS[moment] then
      ok = L.can_comment{moment = moment, tier = enc.tier, fired = enc.fired, comments = enc.comments,
        last_comment_hand = enc.last_comment_hand, last_line_hand = enc.last_line_hand, hand = hand}
    else
      ok = L.can_fire(moment, enc.tier, enc.fired, hand, enc.last_line_hand)
    end
    if not ok then return false end
  end
  if opts.free then -- nothing booked
  elseif L.COMMENTS[moment] then
    L.note_comment(enc, moment, hand) -- 1.2 run comments: the light tier's spacing, the caps
  else
    L.note_line(enc, moment, hand)
  end
  if enc.tier == 'full' and (moment == 'big_hand' or moment == 'close') then
    FinalBoss.fx.play('shake', blind)
    FinalBoss.fx.play('flash', blind)
  end
  if not FinalBoss.config.dialogue then return true end
  local key = FinalBoss.registry.resolve(enc.key, opts.line or moment, enc.last_variant,
    opts.line and {skip_boss = opts.skip_boss} or nil)
  if not key and opts.line then key = FinalBoss.registry.resolve(enc.key, moment, enc.last_variant) end
  if not key then return true end
  local entry = FinalBoss.registry.get(enc.key)
  FinalBoss.dialogue.say(blind, key, opts.vars or Dir.vars(blind), entry.voice.pitch,
    {force = opts.force or L.FORCED_MOMENTS[moment] or false, free = opts.free})
  return true
end

--- context: smods' context.after (scoring_name, full_hand: smods lovely/better_calc.toml:810).
function Dir.on_hand_after(context)
  local enc, blind, st = current()
  if not enc or enc.ended then return end
  local cr = G.GAME.current_round
  -- This hand's id: vanilla counts hands_played up on every play and resets it only at new_round
  -- (functions/state_events.lua:524, :298), so it is monotonic per blind.
  local hands_played = cr.hands_played
  if enc.last_hand_seen == hands_played then return end -- defensive: one evaluation per hand
  Dir.flush_pending() -- a previous hand's reaction updates enc.fired / last_line_hand, read below
  enc.last_hand_seen = hands_played
  local delta = num(SMODS.last_hand_score)
  local chips = num(G.GAME.chips)
  -- G.GAME.chips does not include this hand yet: evaluate_play queues the chip ease, and
  -- context.after runs before it.
  local total = chips + delta
  local required = num(blind.chips)
  local hands_left = cr.hands_left
  -- Set before the game-over screen picks its quip; cleared in on_round_end if the run continues.
  if hands_left == 0 and total < required then st.lost_to = enc.key end
  if total >= required then -- the winning hand (achievements read these at blind_defeated)
    enc.win_start, enc.win_hand, enc.win_hands_left = chips, hands_played, hands_left
  end
  local moment = FinalBoss.logic.detect_moments{delta = delta, total = total, required = required,
    hands_left = hands_left, fired = enc.fired, tier = enc.tier, hand = hands_played,
    last_line_hand = enc.last_line_hand}
  -- 1.2 run comments: the hand type (vanilla also sets G.GAME.last_hand_played,
  -- functions/state_events.lua:576), how many hands in a row used it, and the cards played.
  local hand_type = (context and context.scoring_name) or G.GAME.last_hand_played
  enc.type_streak = FinalBoss.logic.next_streak(enc.last_type, enc.type_streak, hand_type)
  enc.last_type = hand_type
  local played = context and context.full_hand
  -- The reaction waits until the game shows the score (Dir.tick -> logic.score_landed), or the
  -- boss would spoil it. Everything above is decided now.
  local p = {start = chips, delta = delta, total = total, required = required, moment = moment,
    enc = enc, blind = blind, t0 = FinalBoss.util.now(), queued_done = false, hand = hands_played,
    hands_left = hands_left, hand_type = hand_type, streak = enc.type_streak,
    cards_played = played and #played or (G.play and #G.play.cards or 0),
    discards_left = cr.discards_left, discards_used = cr.discards_used}
  Dir.pending = p
  -- Completion signal in queue order: context.after runs inside evaluate_play (state_events.lua)
  -- after it has queued the score display (delay, chips2, the G.GAME.chips ease, the blocking
  -- chip_total ease, the handname clear), so this event appended to the base queue runs after all
  -- of them, at game speed.
  G.E_MANAGER:add_event(Event({func = function()
    FinalBoss.util.guard('score_queued', function() if Dir.pending == p then p.queued_done = true end end)
    return true
  end}))
end

--- Fire a hand's line now, or after the boss's laugh (wait seconds), if the encounter is still on.
local function fire_after(enc, wait, moment, opts)
  if wait <= 0 then Dir.fire(moment, opts); return end
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = wait, timer = 'REAL', blocking = false,
    blockable = false, func = function()
      FinalBoss.util.guard('moment_after_laugh', function()
        local e = current()
        if e and e == enc and not e.ended then Dir.fire(moment, opts) end
      end)
      return true
    end}))
end

--- The deferred reaction to a scored hand; dropped if its encounter is gone or over.
local function react(p)
  local enc, blind = current()
  if not enc or enc ~= p.enc or enc.ended then return end
  if FinalBoss.config.dev_mode then
    FinalBoss.util.log('info', ('dev: score landed chips=%s after %.2fs'):format(
      tostring(G.GAME.chips), FinalBoss.util.now() - p.t0))
  end
  local wait = 0 -- a laugh is coming: the line must not overlap it
  if enc.tier == 'full' and enc.showdown then
    wait = Dir.stage_hit(enc, blind, p.delta, p.total, p.required, p.moment, p.hand)
    -- 1.1: crossing 50% / 25% transforms the boss. Its phase line replaces this hand's moment line
    -- (the moment stays unfired); the hit, damage number and laugh above still play, and a weak
    -- hit's transformation waits for the laugh (wait) so laugh, roar and line never overlap.
    -- A powerless (disabled) boss gets mad there instead: anger and its disabled line, same rules.
    if FinalBoss.phases.check(enc, blind, p, wait) then return end
  end
  -- This hand interrupted the intro: its interrupted line replaces the moment line (the moment
  -- stays unfired, so a later hand can still trigger it), except the defeat line, which always
  -- plays (and may replace the interrupted bubble). The stage hit above still played.
  if FinalBoss.logic.moment_replaced(enc.interrupt_hand, p.hand, p.moment) then return end
  if not p.moment then
    -- 1.2: a hand that fired nothing else may get a run comment: the weak-hit line (after the
    -- laugh, like a phase line) or a read of how you play. Dir.fire checks the comment gate again
    -- when the line is said.
    local comment = FinalBoss.observe.comment_for(enc, p)
    if comment then fire_after(enc, wait, comment, {hand = p.hand}) end
    return
  end
  -- The nemesis's own defeat line (1.1), else the overkill line (1.2: the winning hand only), may
  -- replace the defeat line. Either is said as the defeat moment, so it is forced like the defeat line.
  local line = FinalBoss.memory.defeat_line(enc, p.moment) or FinalBoss.observe.overkill_line(p)
  fire_after(enc, wait, p.moment, {line = line, hand = p.hand})
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
      FinalBoss.util.now() - p.t0, p.queued_done) then return end
  Dir.pending = nil
  FinalBoss.util.guard('score_landed', react, p)
end

--- Stage reactions to a scored hand in a showdown (arena always; avatar when cinematic).
--- Returns the seconds before the hand's dialogue line may start (0 unless the avatar laughs).
function Dir.stage_hit(enc, blind, delta, total, required, moment, hand)
  local stage = stage_of(total, required)
  FinalBoss.arena.on_hit(stage)
  if not enc.cinematic then return 0 end
  local size = FinalBoss.logic.hit_size(delta, required)
  FinalBoss.hpbar.update(total, required)
  FinalBoss.hpbar.damage(delta, size)
  FinalBoss.avatar.set_wound(stage)
  if moment == 'defeat' then
    -- The defeat line (fired next) shows during the shake. The flag is plain data on the saved
    -- encounter: on_blind_defeated runs seconds later, so the finale's phase is no use there.
    enc.finale = FinalBoss.cinematic.play_finale(blind) and true or nil
    return 0
  end
  FinalBoss.avatar.hit(size)
  if size ~= 'weak' then return 0 end
  -- Hit first, then laugh: a soft flinch now, the laugh WEAK_LAUGH_DELAY later (only if this very
  -- avatar is still on the table and the fight is still going).
  local V = FinalBoss.avatar
  local o = V.anchor()
  if not o then return 0 end -- no avatar to laugh: the line must not wait for nothing
  enc.laughed_hand = hand -- Last Laugh: winning with the very next hand earns it
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = Dir.WEAK_LAUGH_DELAY, timer = 'REAL',
    blocking = false, blockable = false, func = function()
      FinalBoss.util.guard('weak_laugh', function()
        local e = current()
        if V.anchor() ~= o or not e or e ~= enc or e.ended then return end
        V.laugh(FinalBoss.registry.get(enc.key).voice.pitch)
      end)
      return true
    end}))
  return Dir.WEAK_LAUGH_DELAY + V.LAUGH_DURATION
end

function Dir.on_blind_disabled()
  local enc, blind = current()
  -- 1.2: Chicot disables the boss before its intro, so a Chicot counter jab is its disabled line.
  Dir.fire('disabled', enc and FinalBoss.observe.disabled_jab(enc, blind) or nil)
end

function Dir.on_blind_defeated()
  FinalBoss.curse.clear() -- the curse marks go with the blind (any tier)
  Dir.flush_pending() -- (the twist clean-up runs ungated in hooks.lua's mod.calculate)
  -- 1.1 memory: the win, for any boss encounter (also below the dialogue ante, tier 'none').
  local raw = FinalBoss.util.state().encounter
  local gb = G.GAME.blind
  if raw and raw.boss and not raw.recorded and gb and gb.config.blind and gb.config.blind.key == raw.key then
    -- A disabled blind stays disabled until the next one is set (Blind:defeat keeps the flag), so a
    -- boss disabled at any point of the fight (Chicot, Luchador) is still disabled here.
    raw.powerless = FinalBoss.phases.powerless(raw, gb) or nil
    local m, beaten = FinalBoss.memory.on_win(raw)
    if m then raw.recorded = true end
    -- The nemesis fell (its own defeat line already played): burst, banner; it is now broken.
    if beaten and FinalBoss.config.memory then FinalBoss.memory.celebrate() end
    if m then -- profile achievements (win_* and laughed_hand: Dir.on_hand_after, Dir.stage_hit)
      FinalBoss.achievements.award_from('defeat', FinalBoss.logic.defeat_achievements, {showdown = raw.showdown,
        start = raw.win_start, hands_left = raw.win_hands_left, hand = raw.win_hand,
        laughed_hand = raw.laughed_hand, nemesis = beaten and not raw.fake_nemesis, -- F9 earns nothing
        final_defeated = m.final_defeated, final_defeated_twisted = m.final_defeated_twisted})
    end
  end
  FinalBoss.memory.unpresent()
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

--- The player pressed Play while the boss's intro (cinematic beats or intro lines) is still
--- running: the speech stops at once, the boss snaps (red flash + shake) and says its interrupted
--- line, which replaces this hand's moment line (react). Once per encounter; discards and
--- key / click skips never get here (only G.STATES.HAND_PLAYED counts).
function Dir.check_interrupt()
  if not (G.STATES and G.STATE == G.STATES.HAND_PLAYED) then return end
  local enc, blind = current()
  if not enc then return end
  local C, D = FinalBoss.cinematic, FinalBoss.dialogue
  local cine, talk = C.active(), D.intro_active()
  if not FinalBoss.logic.should_interrupt{hand_played = true, cinematic_intro = cine,
      dialogue_intro = talk, tier = enc.tier, ended = enc.ended, fired = enc.fired} then return end
  enc.fired.interrupted = true
  local mem = FinalBoss.memory.on_interrupt(enc.key) -- recorded before any visual work can fail
  if mem then
    FinalBoss.achievements.award_from('interrupt', FinalBoss.logic.interrupt_achievements, mem.interrupted)
  end
  enc.interrupt_hand = G.GAME.current_round.hands_played -- this hand's id at context.after
  if cine then C.interrupt() end
  D.end_intro() -- remaining lines dropped; its on_end (letterbox retract, start move) runs once
  -- An interrupted cinematic drops its on_done, so Dir.play_intro never runs: the start move must
  -- still play (moves.start runs once per encounter; a repeat call is a no-op).
  FinalBoss.util.guard('start_move', FinalBoss.moves.start, enc.key)
  FinalBoss.avatar.anger(blind)
  Dir.fire('interrupted', {force = true})
end

--- Per-frame tick (hooks: Game:update wrap). Cheap when nothing is on stage or pending.
function Dir.tick(dt)
  local A, V, H = FinalBoss.arena, FinalBoss.avatar, FinalBoss.hpbar
  if FinalBoss.cinematic.active() or FinalBoss.dialogue.intro_active() then Dir.check_interrupt() end
  FinalBoss.observe.idle_tick() -- 1.2 idle taunts (a few field reads per frame)
  FinalBoss.poke.tick() -- 1.2 poke and grab the boss chip
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
        FinalBoss.arena.reset, FinalBoss.fx.reset, FinalBoss.effects.reset, FinalBoss.moves.reset,
        FinalBoss.phases.reset, FinalBoss.phases.clear_twists, FinalBoss.music.unduck,
        FinalBoss.memory.unpresent, FinalBoss.poke.reset}) do
      local sok, serr = pcall(step)
      if not sok then FinalBoss.util.log('error', 'reset_stage step failed: ' .. tostring(serr)) end
    end
  end)
  resetting = false
  if not ok then FinalBoss.util.log('error', 'reset_stage failed: ' .. tostring(err)) end
end

return Dir

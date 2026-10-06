--- Reading the run (1.2): the intro jab (from the run as the boss blind is set), the in-fight run
--- comments and the idle taunts. Every decision is a logic.lua rule; this module only reads the game.
--- Saved state is plain data on the encounter (jab, jab_said, comments, last_comment_hand, last_type,
--- type_streak, idle_said) and st.reroll_mark; the idle clock is never saved.
local O = {}
O.idle_since = nil  -- REAL time the idle clock started (last input, or the last frame idling could not count)
O.highlighted = nil -- #G.hand.highlighted on the last frame (a change counts as input)

local function L() return FinalBoss.logic end

--- The run as the boss blind is set (logic.intro_jab's s), and vanilla's run reroll counter.
--- Skips: this ante's blind states (functions/button_callbacks.lua:2760, reset at
--- functions/common_events.lua:2327-2332). Rerolls: G.GAME.round_scores.times_rerolled.amt
--- (functions/button_callbacks.lua:2869) minus the mark taken at the previous boss blind. Joker row:
--- smods card_limits.total_slots and card_count (smods src/utils.lua:3936-3945). Deck: G.playing_cards.
function O.run_state(blind_key)
  local st = FinalBoss.util.state()
  local jokers, count, slots = {}, 0, nil
  local J = G.jokers
  if J then
    for _, c in ipairs(J.cards or {}) do
      local key = c.config and c.config.center and c.config.center.key
      if key then jokers[#jokers + 1] = key end
    end
    local cfg = J.config or {}
    count = cfg.card_count or #(J.cards or {})
    slots = (cfg.card_limits and cfg.card_limits.total_slots) or cfg.card_limit
  end
  local states = (G.GAME.round_resets and G.GAME.round_resets.blind_states) or {}
  local skipped = (states.Small == 'Skipped' and 1 or 0) + (states.Big == 'Skipped' and 1 or 0)
  local counter = G.GAME.round_scores and G.GAME.round_scores.times_rerolled
  local rerolled = (counter and tonumber(counter.amt)) or 0
  local deck = G.playing_cards or {}
  local suits, suit_max = {}, 0
  for _, c in ipairs(deck) do
    local s = c.base and c.base.suit
    if s then
      suits[s] = (suits[s] or 0) + 1
      if suits[s] > suit_max then suit_max = suits[s] end
    end
  end
  return {jokers = jokers, joker_count = count, joker_slots = slots, skipped = skipped,
    rerolls = rerolled - (st.reroll_mark or 0), dollars = FinalBoss.director.num(G.GAME.dollars),
    deck_size = #deck, suit_max = suit_max, signature = L().signature_counter(blind_key)}, rerolled
end

--- Dir.on_blind_set, boss encounters (any tier): the intro jab as plain data on the encounter, the
--- reroll mark for the next boss, and a fresh idle count and clock.
function O.on_blind_set(enc)
  local s, rerolled = O.run_state(enc.key)
  FinalBoss.util.state().reroll_mark = rerolled
  enc.jab = L().intro_jab(s, math.random)
  enc.jab_said = nil
  enc.idle_said = 0
  O.idle_since = nil
end

--- A joker's name in the current language (functions/misc_functions.lua:1744-1746); its key if that fails.
function O.joker_name(key)
  if not key then return nil end
  local ok, name = pcall(localize, {type = 'name_text', set = 'Joker', key = key})
  if ok and type(name) == 'string' and name ~= 'ERROR' then return name end
  return key
end

--- Vars of a jab line: #1# the boss name, #2# the joker (jab_counter, jab_famous).
function O.jab_vars(enc, blind)
  local v = FinalBoss.director.vars(blind)
  if enc.jab and enc.jab.joker then v[2] = O.joker_name(enc.jab.joker) end
  return v
end

--- Resolve options of the jab: the boss's own counter line (fb_<blind>_jab_counter) is only for its
--- signature counter (logic.signature_counter); any other counter skips to the personality line.
function O.jab_opts(enc)
  local j = enc.jab
  if j and j.moment == 'jab_counter' then
    return {skip_boss = j.joker ~= L().signature_counter(enc.key)}
  end
  return nil
end

--- Chicot disables the boss before any intro (card.lua:2491-2500; Dir.play_intro skips a disabled
--- boss), so a Chicot counter jab is said as the disabled line. Returns Dir.fire options, or nil.
function O.disabled_jab(enc, blind)
  local j = enc and enc.jab
  if not (j and j.moment == 'jab_counter' and j.joker == 'j_chicot') or enc.jab_said then return nil end
  enc.jab_said = true
  return {line = 'jab_counter', vars = O.jab_vars(enc, blind), skip_boss = O.jab_opts(enc).skip_boss}
end

return O

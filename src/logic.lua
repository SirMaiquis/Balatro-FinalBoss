--- Pure decision logic for FinalBoss.
--- No access to G, love or SMODS: everything arrives as arguments, so this file
--- is unit tested outside the game (tests/test_logic*.lua).
local logic = {}

--- Pick a variant index in [1, count] that is never `last` when count > 1.
--- rand(n) must return an integer in [1, n] (math.random signature).
function logic.pick_variant(count, last, rand)
  if not count or count <= 0 then return nil end
  if count == 1 then return 1 end
  if not last or last < 1 or last > count then return rand(count) end
  local i = rand(count - 1)
  if i >= last then i = i + 1 end
  return i
end

--- Mirrors SMODS.is_showdown_ante() in smods 26.829.0.
function logic.is_vanilla_showdown(ante, win_ante)
  return ante > 0 and ante % win_ante == 0
end

--- Extra showdown antes from the FinalBoss schedule: start, start+every, start+2*every, ...
function logic.is_extra_showdown(ante, start, every)
  if not (ante and start and every) or every < 1 then return false end
  return ante >= start and (ante - start) % every == 0
end

--- First n antes that will be showdowns under the given settings.
function logic.preview_showdowns(enabled, start, every, win_ante, n)
  local out, ante = {}, 1
  while #out < n and ante <= 200 do
    if logic.is_vanilla_showdown(ante, win_ante) or (enabled and logic.is_extra_showdown(ante, start, every)) then
      out[#out + 1] = ante
    end
    ante = ante + 1
  end
  return out
end

--- Ante track of the config menu: track[a] is true when ante a (1..last) is a showdown under the
--- given settings (the same schedule as preview_showdowns, cut at `last`).
function logic.showdown_track(enabled, start, every, win_ante, last)
  local track = {}
  for a = 1, last do track[a] = false end
  for _, a in ipairs(logic.preview_showdowns(enabled, start, every, win_ante, last)) do
    if a <= last then track[a] = true end
  end
  return track
end

local DURATIONS = {6, 4, 2.5} -- slow, normal, fast (seconds per intro line)

function logic.line_duration(speed)
  return DURATIONS[speed] or DURATIONS[2]
end

function logic.intro_sequence(tier)
  if tier == 'full' then return {'opener', 'name', 'intro', 'closer'} end
  if tier == 'light' then return {'intro'} end
  return {}
end

logic.BIG_HAND_RATIO = 0.30 -- one hand scoring >= 30% of the requirement
logic.CLOSE_RATIO = 0.75    -- running total >= 75% of the requirement (not yet won)

-- Mid-fight reactions: once each per blind. Light tier: an in-fight line (the spaced reactions below,
-- 'weak' and the reads) at most once per hand and never on two consecutive hands (logic.line_spaced);
-- disabled and defeat are not spaced.
logic.REACTIONS = {big_hand = true, close = true, last_hand = true, disabled = true}
logic.SPACED = {big_hand = true, close = true, last_hand = true}

local PRIORITY = {'last_hand', 'close', 'big_hand'}

-- Moments whose line always shows (no cooldown, cuts the current line). 'interrupted' is said
-- when the player plays a hand while the boss's intro is still running (once per encounter).
logic.FORCED_MOMENTS = {defeat = true, interrupted = true}

-- Moments that may fire more than once per blind (their own caps live elsewhere: idle, logic.IDLE_MAX).
logic.REPEATABLE = {idle = true}

--- Whether this frame interrupts the boss's intro. a: {hand_played (G.STATE is HAND_PLAYED),
--- cinematic_intro, dialogue_intro (either part of the intro is running), tier, ended, fired}.
function logic.should_interrupt(a)
  if not a.hand_played or a.ended then return false end
  if a.tier ~= 'light' and a.tier ~= 'full' then return false end
  if a.fired and a.fired.interrupted then return false end
  return (a.cinematic_intro or a.dialogue_intro) and true or false
end

--- Whether a scored hand's moment line is replaced by the interrupted line said for that hand.
--- The defeat line is never replaced: the boss always gets its last word.
function logic.moment_replaced(interrupt_hand, hand, moment)
  if moment == 'defeat' then return false end
  return interrupt_hand ~= nil and hand ~= nil and interrupt_hand == hand
end

--- Game over: top-left x, y and size of the gloating chip beside the game-over panel.
--- panel = {x, y, w, h}; room_right = the right edge the window always shows; S = normal chip size,
--- min_s = smallest chip that still reads; gap = space kept around the chip.
--- Right of the panel, vertically centred, shrunk to the free margin (floor min_s); if even min_s
--- does not fit, above the panel's top-right corner instead, so it never covers the panel.
function logic.gloat_rect(panel, room_right, S, min_s, gap)
  local right = panel.x + panel.w
  local free = room_right - right - 2 * gap -- gap to the panel and to the window edge
  if free >= min_s then
    local size = math.min(S, free)
    return right + gap, panel.y + panel.h / 2 - size / 2, size
  end
  local size = math.max(min_s, math.min(S, panel.y - 2 * gap))
  return right - size, panel.y - gap - size, size
end

--- args: {is_boss, is_showdown, entry_tier = 'auto'|'light'|'full', ante, min_ante}
function logic.decide_tier(a)
  if not a.is_boss then return 'none' end
  if a.entry_tier == 'light' or a.entry_tier == 'full' then return a.entry_tier end
  if a.is_showdown then return 'full' end
  if a.ante >= a.min_ante then return 'light' end
  return 'none'
end

--- Light tier: whether the boss may speak on hand (G.GAME.current_round.hands_played) after its last
--- in-fight line on last_line_hand: never twice on one hand nor on the next one.
function logic.line_spaced(hand, last_line_hand)
  return last_line_hand == nil or hand == nil or hand - last_line_hand >= 2
end

--- reactions: kept for callers, no longer read. hand, last_line_hand: this hand's id and the hand of
--- the light tier's last in-fight line (logic.line_spaced).
function logic.can_fire(moment, tier, fired, reactions, hand, last_line_hand)
  if tier ~= 'light' and tier ~= 'full' then return false end
  if fired[moment] and not logic.REPEATABLE[moment] then return false end
  if logic.SPACED[moment] and tier == 'light' and not logic.line_spaced(hand, last_line_hand) then return false end
  return true
end

--- Book a non-comment moment on the encounter (plain saved data): fired, the reaction count, and for
--- a spaced line the hand it was said on (enc.last_line_hand, read by the light tier only).
function logic.note_line(enc, moment, hand)
  enc.fired = enc.fired or {}
  enc.fired[moment] = true
  if logic.REACTIONS[moment] then enc.reactions = (enc.reactions or 0) + 1 end
  if logic.SPACED[moment] then enc.last_line_hand = hand end
end

--- Decide which moment (if any) a just-scored hand triggers.
--- a: {delta, total, required, hands_left, fired, tier, reactions, hand, last_line_hand}
function logic.detect_moments(a)
  if not a.required or a.required <= 0 then return nil end
  if a.total >= a.required then
    return logic.can_fire('defeat', a.tier, a.fired, a.reactions, a.hand, a.last_line_hand) and 'defeat' or nil
  end
  local hit = {
    last_hand = a.hands_left == 0,
    close = a.total >= logic.CLOSE_RATIO * a.required,
    big_hand = a.delta >= logic.BIG_HAND_RATIO * a.required,
  }
  for _, moment in ipairs(PRIORITY) do
    if hit[moment] and logic.can_fire(moment, a.tier, a.fired, a.reactions, a.hand, a.last_line_hand) then
      return moment
    end
  end
  return nil
end

-- generic_name: the generic set's name line (fb_generic_name_N) for a boss that has its own, said
-- after a rematch or nemesis opener (logic.intro_plan).
logic.SHARED_MOMENTS = {opener = true, closer = true, nemesis_intro = true, nemesis_defeat = true,
  generic_name = true}

--- Find the localization key prefix for a moment: boss-specific (skipped when skip_boss), then the
--- boss's personality (fb_p_<personality>_<moment>, 1.2), then generic. Shared moments have only
--- their shared key. count_of(prefix) returns how many variants (prefix_1, prefix_2, ...) exist.
--- Returns prefix, is_generic  -- or nil when nothing exists.
function logic.resolve_prefix(blind_key, moment, count_of, personality, skip_boss)
  if logic.SHARED_MOMENTS[moment] then
    local shared = 'fb_' .. moment
    if count_of(shared) > 0 then return shared, false end
    return nil
  end
  if not skip_boss then
    local specific = 'fb_' .. blind_key .. '_' .. moment
    if count_of(specific) > 0 then return specific, false end
  end
  if personality then
    local voiced = 'fb_p_' .. personality .. '_' .. moment
    if count_of(voiced) > 0 then return voiced, false end
  end
  local generic = 'fb_generic_' .. moment
  if count_of(generic) > 0 then return generic, true end
  return nil
end

-- Showdown stage maths.
logic.WEAK_HIT_RATIO = 0.10 -- a hand under 10% of the boss's max HP is shrugged off: a flinch, then a laugh

--- Remaining boss health as a fraction of the requirement, clamped to [0, 1].
function logic.hp_fraction(total, required)
  if not required or required <= 0 then return 0 end
  local f = 1 - (total or 0) / required
  if f < 0 then return 0 end
  if f > 1 then return 1 end
  return f
end

--- 0 = healthy, 1 = below 50%, 2 = below 25% (avatar, HP bar and arena share these stages).
function logic.wound_stage(fraction)
  if fraction < 0.25 then return 2 end
  if fraction < 0.5 then return 1 end
  return 0
end

function logic.hit_size(delta, required)
  if not required or required <= 0 then return 'normal' end
  if delta >= logic.BIG_HAND_RATIO * required then return 'big' end
  if delta < logic.WEAK_HIT_RATIO * required then return 'weak' end
  return 'normal'
end

--- The avatar's laugh: LAUGH.beats "ha"s at an even cadence, the pitch falling from pitch_hi to
--- pitch_lo, the chip hopping and tilting on every beat, then a short decaying shake.
logic.LAUGH = {beats = 5, step = 0.095, hop = 0.25, tilt = 0.2, shake = 0.25, shake_amp = 0.07,
  pitch_hi = 1.35, pitch_lo = 1.0}

--- Total length of the laugh in seconds (the beats plus the closing shake).
function logic.laugh_duration()
  return logic.LAUGH.beats * logic.LAUGH.step + logic.LAUGH.shake
end

--- Pitch multiplier of beat i (0-based): steps down evenly from pitch_hi to pitch_lo.
function logic.laugh_pitch(i)
  local L = logic.LAUGH
  if L.beats <= 1 then return L.pitch_hi end
  return L.pitch_hi - (L.pitch_hi - L.pitch_lo) * i / (L.beats - 1)
end

--- Offsets of the chip `elapsed` seconds into the laugh: (hop, tilt, shake). hop is how far up (>= 0,
--- table units), tilt the rotation (alternating direction per beat), shake the jitter amplitude.
--- All zero outside [0, duration): the chip is back exactly on its perch when the laugh is over.
function logic.laugh_motion(elapsed)
  local L = logic.LAUGH
  if not elapsed or elapsed < 0 or elapsed >= logic.laugh_duration() then return 0, 0, 0 end
  local beats_end = L.beats * L.step
  if elapsed < beats_end then
    local x = elapsed / L.step
    local b = math.floor(x)
    local lift = math.sin(math.pi * (x - b))
    return L.hop * lift, ((b % 2 == 0) and 1 or -1) * L.tilt * lift, 0
  end
  return 0, 0, L.shake_amp * (1 - (elapsed - beats_end) / L.shake)
end

--- Avatar perches. Each rectangle covers the chip (S x S, top-left at the perch) plus the HP box
--- hanging centred under it (box_w x box_h), so the whole thing can be kept clear of cards.
--- areas: {play, jokers, consumeables, deck, hand, room} as {x, y, w, h} (room optional: clamp).
--- 1 ringside (home: spawn, landing, scoring) right of the play area, above the deck;
--- 2 left-middle, 3 upper-centre band, 4 upper band under the consumables (2-4 idle only).
logic.PERCH_RINGSIDE = 1
logic.PERCH_GAP = 0.35 -- below the joker row for the upper-band perches

function logic.perch_rect(i, areas, S, box_h, box_w)
  local play, jok, cons = areas.play, areas.jokers, areas.consumeables
  local x, y
  if i == 1 and play then
    x, y = play.x + play.w + 1.2, play.y + play.h / 2 - S / 2 - 0.8 -- clear of the hand's right edge
  elseif i == 2 and play then
    x, y = play.x - 0.2, play.y - 0.1
  elseif i == 3 and play and jok then
    x, y = play.x + play.w / 2 - S / 2, jok.y + jok.h + logic.PERCH_GAP
  elseif i == 4 and cons and jok then
    x, y = cons.x + cons.w / 2 - S / 2, jok.y + jok.h + logic.PERCH_GAP
  else
    return nil
  end
  local w, h = math.max(S, box_w or S), S + (box_h or 0)
  local rx = x + S / 2 - w / 2
  local room = areas.room
  if room then
    rx = math.max(room.x, math.min(rx, room.x + room.w - w))
    y = math.max(room.y, math.min(y, room.y + room.h - h))
  end
  return {x = rx, y = y, w = w, h = h}
end

--- Whether a scored hand has visibly landed (so the boss may react without spoiling it).
--- queued_done: an event queued behind vanilla's score display has run (always lands);
--- delta > 0: the round score has started ticking up (vanilla's chips2 moment);
--- delta <= 0: vanilla has cleared the hand name;
--- elapsed (real seconds) >= SCORE_LAND_SAFETY: last resort only (queue stuck or cleared).
logic.SCORE_LAND_SAFETY = 30

function logic.score_landed(start, chips, delta, handname, elapsed, queued_done)
  if queued_done then return true end
  if (elapsed or 0) >= logic.SCORE_LAND_SAFETY then return true end
  if (delta or 0) > 0 then return (chips or 0) > (start or 0) end
  return handname == ''
end

local ARENA = {
  [0] = {black_mix = 0.45, contrast = 3.0, spin_mult = 1.0, pitch = 1.0},
  [1] = {black_mix = 0.60, contrast = 3.8, spin_mult = 1.5, pitch = 1.0},
  [2] = {black_mix = 0.75, contrast = 4.5, spin_mult = 2.0, pitch = 1.06},
}

function logic.arena_params(stage)
  return ARENA[stage] or ARENA[0]
end

-- Boss moves (1.1) --------------------------------------------------------------------------------

--- Effect primitives a recipe step may name (src/effects.lua). curse = a persistent mark on cursed
--- cards (step.style, logic.CURSE_STYLES); fist = the Raised Fist slams onto a HUD element;
--- recount = a counter shown going from its old value to its new one (step.value,
--- logic.RECOUNT_VALUES; step.cue = steps played as the count starts); land = a flash on each card as
--- it reaches its slot; snake = a snake crawls from the deck to the hand; needle = a needle stabs
--- into a HUD counter (The Needle's cue).
logic.EFFECTS = {fling = true, drain = true, crack = true, stamp = true, sweep = true, glare = true,
  chain = true, ring = true, spin = true, burst = true, curse = true, fist = true, recount = true,
  land = true, snake = true, needle = true}

--- Curse mark styles (src/curse.lua): a suit-coloured frame with the suit badge, vines, cracks.
logic.CURSE_STYLES = {suit = true, vine = true, crack = true}

--- Trigger kinds (hooks.lua -> moves.lua). 'signature' is no trigger: phases play it big. 'set' plays
--- the moment the blind is set (with the counters from just before); 'start' when the intro ends.
logic.MOVE_KINDS = {play = true, modify = true, hand_debuff = true, card_debuff = true, flipped = true,
  drawn = true, start = true, set = true, draw = true, joker_sold = true, generic = true, signature = true}

--- Where a step lands (resolved by moves.lua): the performer, the trigger's cards, the played
--- cards, a card area, a HUD element or the hand's card-count label (hand_limit: "0/8" under it).
logic.TARGETS = {source = true, cards = true, played = true, hand = true, jokers = true,
  hud_chips = true, hud_mult = true, hud_hand_name = true, hud_hand_level = true, hud_hands = true,
  hud_discards = true, hud_target = true, hud_dollars = true, hand_limit = true}

--- Counters a recount step can show (moves.lua snapshots them just before the blind applies).
logic.RECOUNT_VALUES = {hands = true, discards = true, hand_size = true, target = true}

--- Built-in final-boss deaths (src/deaths.lua).
logic.DEATHS = {hearts = true, leaves = true, acorn = true, flood = true, bell = true}

logic.THROTTLE_GAP = 0.6 -- seconds between two moves of the same kind (one per batch)

--- Bosses without a recipe (modded) burst on the generic trigger (Blind:wiggle).
logic.GENERIC_RECIPE = {{effect = 'burst', target = 'source'}, sound = {'tarot1', 1, 0.4}}

--- Why one step is invalid (nil when it is fine).
local function step_problem(step)
  if type(step) ~= 'table' or not logic.EFFECTS[step.effect] then
    return 'unknown effect ' .. tostring(type(step) == 'table' and step.effect or step)
  elseif step.target ~= nil and not logic.TARGETS[step.target] then
    return 'unknown target ' .. tostring(step.target)
  elseif step.effect == 'curse' and not logic.CURSE_STYLES[step.style] then
    return 'unknown curse style ' .. tostring(step.style)
  elseif step.effect == 'recount' and not logic.RECOUNT_VALUES[step.value] then
    return 'unknown recount value ' .. tostring(step.value)
  end
  return nil
end

--- Step options that must be numbers (effects do arithmetic on them every frame). amount may also
--- be a keyword (logic.step_amount).
local NUMERIC_OPTS = {'scale', 'count', 'time', 'hold', 'amount'}
local AMOUNT_WORDS = {played = true, money = true}

--- The step with its numeric options as numbers: a numeric string is converted, anything else is
--- dropped with a warning. Copies the step before changing it (recipe tables are shared).
local function fix_numbers(step, where, warnings)
  local copy = step
  for _, k in ipairs(NUMERIC_OPTS) do
    local v = step[k]
    if v ~= nil and type(v) ~= 'number' and not (k == 'amount' and AMOUNT_WORDS[v]) then
      if copy == step then
        copy = {}
        for kk, vv in pairs(step) do copy[kk] = vv end
      end
      copy[k] = tonumber(v)
      if copy[k] == nil then
        warnings[#warnings + 1] = ('%s: %s is not a number (%s), ignored'):format(where, k, tostring(v))
      end
    end
  end
  return copy
end

--- A recipe is a list of steps {effect = name, target = name, ...options} plus optional
--- recipe.sound = {key, pitch, volume}, recipe.defer (moves.lua reads the trigger's cards in a
--- queued event) and recipe.live (a flipped recipe plays while the cards are dealt). A step's cue (a
--- recount's steps played as the count starts) is cleaned the same way; a step with a cue is copied,
--- never edited (recipe tables are shared). Returns the cleaned recipe (nil when no step is valid) and
--- warning strings.
function logic.clean_recipe(recipe)
  if type(recipe) ~= 'table' then return nil, {'recipe is not a table'} end
  local out, warnings = {}, {}
  for i, step in ipairs(recipe) do
    local problem = step_problem(step)
    if problem then
      warnings[#warnings + 1] = ('step %d: %s'):format(i, problem)
    else
      step = fix_numbers(step, ('step %d'):format(i), warnings)
      if type(step.cue) == 'table' then
        local copy, cue = {}, {}
        for k, v in pairs(step) do copy[k] = v end
        for j, sub in ipairs(step.cue) do
          local p = step_problem(sub)
          if p then warnings[#warnings + 1] = ('step %d cue %d: %s'):format(i, j, p)
          else cue[#cue + 1] = fix_numbers(sub, ('step %d cue %d'):format(i, j), warnings) end
        end
        copy.cue = cue
        step = copy
      end
      out[#out + 1] = step
    end
  end
  if #out == 0 then return nil, warnings end
  if type(recipe.sound) == 'table' and type(recipe.sound[1]) == 'string' then out.sound = recipe.sound end
  if recipe.defer then out.defer = true end
  if recipe.live then out.live = true end
  return out, warnings
end

--- moves: kind -> recipe. Returns the cleaned table (nil when empty) and warning strings.
function logic.clean_moves(moves)
  if type(moves) ~= 'table' then return nil, {'moves is not a table'} end
  local out, warnings, any = {}, {}, false
  for kind, recipe in pairs(moves) do
    if not logic.MOVE_KINDS[kind] then
      warnings[#warnings + 1] = 'unknown kind ' .. tostring(kind)
    else
      local clean, w = logic.clean_recipe(recipe)
      for _, msg in ipairs(w) do warnings[#warnings + 1] = tostring(kind) .. ' ' .. msg end
      if clean then out[kind] = clean; any = true end
    end
  end
  return any and out or nil, warnings
end

--- death: a built-in name (logic.DEATHS) or a recipe.
function logic.clean_death(death)
  if type(death) == 'string' then
    if logic.DEATHS[death] then return death, {} end
    return nil, {'unknown death ' .. death}
  end
  return logic.clean_recipe(death)
end

--- Rate limit: true (and records now) when `key` last passed at least min_gap seconds ago.
--- last: key -> time, owned by the caller.
function logic.throttle_ok(last, key, now, min_gap)
  local t = last[key]
  if t and now - t < (min_gap or logic.THROTTLE_GAP) then return false end
  last[key] = now
  return true
end

--- Moves held while a phase transformation plays: keep at most max (default 2), oldest dropped.
function logic.queue_push(queue, item, max)
  queue[#queue + 1] = item
  if #queue > (max or 2) then return queue, table.remove(queue, 1) end
  return queue, nil
end

--- Whether a boss move may run. a: {moves, fx (settings), disabled_run, is_boss, blind_disabled, kind}.
--- joker_sold is the one move of a disabled blind (Verdant Leaf withers as the sale disables it).
function logic.move_allowed(a)
  if not (a.moves and a.fx) or a.disabled_run or not a.is_boss then return false end
  if a.blind_disabled and a.kind ~= 'joker_sold' then return false end
  return true
end

--- The recipe a trigger plays: the boss's own, or the generic burst for bosses without moves.
function logic.recipe_for(moves, kind)
  if moves then return moves[kind] end
  if kind == 'generic' then return logic.GENERIC_RECIPE end
  return nil
end

--- Stamp glyphs (effects.lua draws them with love.graphics, no new art): each glyph is a list of
--- polylines, flat x1, y1, x2, y2, ... in the unit square (scaled to the card).
logic.GLYPHS = {
  x = {{0.2, 0.2, 0.8, 0.8}, {0.8, 0.2, 0.2, 0.8}},
  hex = {{0.5, 0.1, 0.85, 0.3, 0.85, 0.7, 0.5, 0.9, 0.15, 0.7, 0.15, 0.3, 0.5, 0.1}},
  vine = {{0.15, 0.9, 0.35, 0.65, 0.3, 0.45, 0.5, 0.3, 0.55, 0.1}, {0.35, 0.65, 0.6, 0.6}, {0.5, 0.3, 0.75, 0.35}},
  crack = {{0.45, 0.05, 0.6, 0.3, 0.4, 0.5, 0.6, 0.7, 0.45, 0.95}, {0.4, 0.5, 0.2, 0.6}},
}

--- Coins in a drain: one per dollar taken, none under a dollar, capped (default 12).
function logic.coin_count(amount, max)
  amount = tonumber(amount) or 0
  if amount < 1 then return 0 end
  return math.min(max or 12, math.floor(amount))
end

--- HUD element ids of the hud_* targets (functions/UI_definitions.lua). hud_target lives in
--- G.HUD_blind, the others in G.HUD.
logic.HUD_IDS = {hud_chips = 'hand_chip_area', hud_mult = 'hand_mult_area', hud_hand_name = 'hand_name',
  hud_hand_level = 'hand_level', hud_hands = 'hand_UI_count', hud_discards = 'discard_UI_count',
  hud_dollars = 'dollar_text_UI', hud_target = 'HUD_blind_count'}

-- Curse marks (src/curse.lua) -----------------------------------------------------------------------

logic.CURSE_GROW = 0.5     -- seconds a new mark takes to grow onto its card
logic.CURSE_STAGGER = 0.06 -- seconds between two cards of one batch (reads as one stroke)

--- Columns of the curse marks atlas (assets/*/curse_marks.png, drawn by tools/make_art.py in this
--- order): a suit frame with its badge per vanilla suit (row 0: low-contrast colours, row 1:
--- high-contrast), a plain frame for any other suit, vines, cracks and the Needle's needle.
logic.MARK_FRAMES = {Hearts = 0, Diamonds = 1, Clubs = 2, Spades = 3, suit = 4, vine = 5, crack = 6, needle = 7}
local SUIT_FRAMES = {Hearts = true, Diamonds = true, Clubs = true, Spades = true}

--- The atlas cell (x, y) of a mark: style (logic.CURSE_STYLES), the cursed suit and whether that suit
--- uses its high-contrast palette. nil for an unknown style.
function logic.mark_frame(style, suit, hc)
  if style == 'suit' then
    if suit and SUIT_FRAMES[suit] then return logic.MARK_FRAMES[suit], hc and 1 or 0 end
    return logic.MARK_FRAMES.suit, 0
  end
  if style ~= 'needle' and logic.MARK_FRAMES[style] then return logic.MARK_FRAMES[style], 0 end
  return nil
end

--- The dissolve a mark is drawn with (the dissolve shader's mask, 0 = whole, 1 = gone): it fades in as
--- it grows (g, logic.curse_grow) and goes with its card when the card dissolves (card.dissolve,
--- which vanilla reads as math.abs, engine/sprite.lua:99).
function logic.mark_dissolve(g, card_dissolve)
  local d = 1 - math.max(0, math.min(1, g or 1))
  return math.max(d, math.min(1, math.abs(card_dissolve or 0)))
end

--- Growth of a mark born `elapsed` seconds ago, 0..1 (ease out over CURSE_GROW). A negative age is a
--- staggered card not shown yet. Reduced motion: whole at once.
function logic.curse_grow(elapsed, reduced)
  if reduced or elapsed == nil then return 1 end
  if elapsed <= 0 then return 0 end
  local p = elapsed / logic.CURSE_GROW
  if p >= 1 then return 1 end
  return 1 - (1 - p) ^ 3
end

--- Whether a curse mark is drawn this frame. debuff, by_blind: the card is debuffed and smods marks the
--- blind as the cause (card.debuffed_by_blind, smods lovely/blind.toml:9-35); mark_key: the blind
--- that cursed it; blind_key / blind_disabled: the current blind; facing: G.GAME.facing_blind (the
--- round is on); on: boss moves and screen effects are enabled and FinalBoss is live this run.
--- twist: the card is debuffed by a FinalBoss phase twist (the Verdant Leaf regrowth's
--- SMODS.debuff_card source, phases.LEAF_SOURCE); that debuff lives on the blind a sale disabled, so
--- it shows the mark without by_blind and while the blind is disabled, for as long as it lasts.
function logic.curse_visible(debuff, by_blind, mark_key, blind_key, blind_disabled, facing, on, twist)
  if not (on and facing and debuff) then return false end
  if blind_key == nil or mark_key ~= blind_key then return false end
  if twist then return true end
  return (by_blind and not blind_disabled) and true or false
end

-- The Arm's fist (effects.fist) -----------------------------------------------------------------------

logic.FIST_FALL = 0.35 -- seconds the fist falls onto the panel
logic.FIST_HOLD = 0.25 -- seconds it rests there after the impact
logic.FIST_FADE = 0.4  -- seconds it dissolves away
logic.LEVEL_WAIT = 0.9 -- game seconds between the level sound event and the level text (smods)

--- Where the fist syncs with a hand's level change in the event queue. smods routes level_up_hand to
--- SMODS.upgrade_poker_hands (lovely/scoring_calculation.toml:229-262), which queues for the level
--- (src/utils.lua:4089-4097): an 'after' 0.9 event (sound), a 'before' event (update_hand_text: the
--- level text changes) and delay(1.3). queue: event list (each {trigger, delay}); from: the first
--- index queued by the Arm's own call. Returns the insert positions (fall, hit): an event inserted at
--- `fall` runs when the queue reaches the 0.9 s wait, one inserted at `hit` (insert it first) runs in
--- the same frame as the level text change. nil when the pattern is not there.
function logic.level_tick_slots(queue, from)
  from = from or 1
  for j = math.max(from + 2, 3), #queue do
    local e = queue[j]
    if e.trigger == 'after' and e.delay == 1.3 then
      local text, wait = queue[j - 1], queue[j - 2]
      if text.trigger == 'before' and wait.trigger == 'after' and wait.delay == logic.LEVEL_WAIT then
        return j - 2, j
      end
    end
  end
  return nil
end

--- The fist's fall for a level change `lead` real seconds away: wait, then fall (seconds), so it lands
--- on the tick. A fast game shortens the fall; reduced motion: no fall.
function logic.fist_timing(lead, reduced)
  lead = math.max(0, lead or 0)
  if reduced then return lead, 0 end
  local fall = math.min(logic.FIST_FALL, lead)
  return lead - fall, fall
end

--- A step's amount (drain): 'played' = cards played, 'money' = dollars the blind took, or a number.
function logic.step_amount(step, data)
  local a = step.amount
  if a == 'played' then return #(data.played or {}) end
  if a == 'money' then return tonumber(data.money) or 0 end
  return tonumber(a) or 0
end

--- Whether a hand card gets a curse mark: debuffed, with smods naming the blind as the cause
--- (card.debuffed_by_blind, smods lovely/blind.toml:9-23), and not marked yet this blind (stamped).
--- On Continue the flag is recomputed first (moves.restore_marks), since it is not saved.
function logic.blind_cursed(debuff, by_blind, stamped)
  return (debuff and by_blind == true and not stamped) and true or false
end

--- hooks.lua: Blind:debuff_hand applied its effect in a real play (not the highlight preview):
--- it returned true (Psychic, Eye, Mouth) or set triggered (Arm, Ox act and return nil).
function logic.hand_debuff_fired(ret, triggered, check, disabled)
  if check or disabled then return false end
  return (ret or triggered) and true or false
end

--- The Serpent's refill: after the first play or discard it draws only 3 cards
--- (functions/state_events.lua draw_from_deck_to_hand). a: {key, disabled, hands_played, discards_used}
function logic.serpent_draw(a)
  return a.key == 'bl_serpent' and not a.disabled
    and ((a.hands_played or 0) > 0 or (a.discards_used or 0) > 0) or false
end

logic.CARD_SETTLE = 0.3 -- real seconds a dealt card takes to glide into its slot in the hand

--- Where the draw sits in the event queue after G.FUNCS.draw_from_deck_to_hand (from = the first index
--- it queued): its delay(0.3) (state_events.lua:369, an 'after' 0.3 event) and the draw_card events
--- that follow (common_events.lua:395-397: 'before', default delay 0.1, one per card; smods may add
--- 'immediate' events between them, lovely/better_calc.toml). Returns the delay's index and the number
--- of cards dealt; nil when no card is dealt.
function logic.draw_slots(queue, from)
  local start
  for j = math.max(1, from or 1), #queue do
    local e = queue[j]
    if e.trigger == 'after' and e.delay == 0.3 then start = j; break end
  end
  if not start then return nil end
  local n = 0
  for j = start + 1, #queue do
    local e = queue[j]
    if e.trigger == 'before' and e.delay == 0.1 then n = n + 1 end
  end
  if n == 0 then return nil end
  return start, n
end

--- Real seconds from the draw's start until its last card is in the hand: the 0.3 s delay and 0.1 s
--- per card before it run on the game clock (G.TIMERS.TOTAL, x speed), then the card glides in.
function logic.serpent_lead(count, speed)
  speed = math.max(0.05, tonumber(speed) or 1)
  return (0.3 + 0.1 * math.max(0, (count or 0) - 1)) / speed + logic.CARD_SETTLE
end

-- Blind-start before -> after (recount) ---------------------------------------------------------------

logic.RECOUNT_LINGER = 0.25  -- seconds the new value stays on the overlay before the real counter shows
logic.RECOUNT_WAIT_MAX = 2.5 -- the longest an overlay waits for its counter (hidden, moving, covered)

--- The score target the blind would have as a regular boss: vanilla Blind:set_blind computes
--- get_blind_amount(ante) * mult * ante_scaling (blind.lua:107) and a regular boss has mult 2.
function logic.normal_target(amount, scaling)
  return (tonumber(amount) or 0) * 2 * (tonumber(scaling) or 1)
end

--- The counters once the blind's effect has applied, from the ones just before it: a.hands_sub and
--- a.discards_sub (The Needle, The Water: blind.lua:179-186), a.mod_delta (The Manacle's change of the
--- hand's card_limits.mod, smods lovely/card_limit.toml:84-100) and a.chips (the real target).
function logic.recount_after(before, a)
  if type(before) ~= 'table' then return {} end
  a = a or {}
  local function sub(v, d)
    if v == nil then return nil end
    return math.max(0, v - (tonumber(d) or 0))
  end
  return {
    hands = sub(before.hands, a.hands_sub),
    discards = sub(before.discards, a.discards_sub),
    hand_size = sub(before.hand_size, -(tonumber(a.mod_delta) or 0)),
    target = tonumber(a.chips),
  }
end

--- The number a recount overlay shows `elapsed` seconds after it started: `from` while it holds, then
--- it counts to `to` over `time` (ease out, whole numbers: rounded towards `from`, so a drop by one lands
--- at the end). Reduced motion: no counting, `to` right after the hold.
function logic.recount_value(from, to, elapsed, hold, time, reduced)
  if from == nil then return to end
  if to == nil then return from end
  elapsed, hold, time = elapsed or 0, hold or 0, time or 0
  if elapsed < hold then return from end
  if reduced or time <= 0 then return to end
  local p = (elapsed - hold) / time
  if p >= 1 then return to end
  local v = from + (to - from) * (1 - (1 - p) * (1 - p))
  if to < from then return math.ceil(v) end
  return math.floor(v)
end

-- Stepwise recount and the Needle (effects.recount with step, effects.needle) -------------------------

logic.STEP_MAX = 8        -- a stepwise count takes at most this many steps
logic.NEEDLE_FALL = 0.15  -- seconds the needle takes to stab down into its counter
logic.NEEDLE_HOLD = 0.6   -- seconds it stays stuck when no count holds it there
logic.SHAKE = {time = 0.35, amp = 0.06, freq = 18} -- a counter's shake: seconds, room units, per second

local function whole(v) return math.floor(v + 0.5) end

--- The values a stepwise count shows after each of its steps, from `from` to `to`: one whole number at
--- a time (4 -> 1: 3, 2, 1), or, past `max` steps (default STEP_MAX), `max` even steps that land on `to`.
function logic.count_steps(from, to, max)
  local out = {}
  if from == nil or to == nil then return out end
  from, to = whole(from), whole(to)
  local n = math.abs(to - from)
  if n == 0 then return out end
  local k = math.min(n, math.max(1, max or logic.STEP_MAX))
  for i = 1, k do out[i] = from + whole((to - from) * i / k) end
  return out
end

--- How many of a count's n steps are done `elapsed` seconds after the first one (which lands at once),
--- one every `step` seconds.
function logic.step_index(elapsed, step, n)
  if not n or n <= 0 or not elapsed or elapsed < 0 then return 0 end
  if not step or step <= 0 then return n end
  return math.min(n, math.floor(elapsed / step) + 1)
end

--- A counter's sideways shake `elapsed` seconds after a hit (room units): fast, dying out over
--- SHAKE.time. Reduced motion: none.
function logic.shake_offset(elapsed, reduced)
  local S = logic.SHAKE
  if reduced or not elapsed or elapsed < 0 or elapsed >= S.time then return 0 end
  local fade = 1 - elapsed / S.time
  return S.amp * fade * fade * math.sin(2 * math.pi * S.freq * elapsed)
end

-- Phases (1.1) ------------------------------------------------------------------------------------

--- Phase I above 50% HP, II below 50%, III below 25% (the 1.0 wound stages + 1). old_stage is the
--- stage of the phase already reached (phase - 1): a hand through both thresholds returns 3 once,
--- and a phase is never undone (a Violet Vessel heal can lower the wound stage again).
function logic.phase_cross(old_stage, new_stage)
  old_stage, new_stage = old_stage or 0, new_stage or 0
  if new_stage > old_stage then return new_stage + 1 end
  return nil
end

--- Whether a scored hand transforms the boss. a: {cinematic, moment, target (phase_cross), hands_left}.
--- Never on the defeat hand (the death plays) or the last hand (the round ends right after).
function logic.should_transform(a)
  if not a.cinematic or not a.target then return nil end
  if a.moment == 'defeat' or (a.hands_left or 1) <= 0 then return nil end
  return a.target
end

--- What a scored hand's HP drop does to a final boss: 'transform' (it reaches a new phase), 'mad'
--- (a powerless boss crossed a threshold: anger and its disabled line, no transformation) or nil,
--- plus the phase reached. Same gates as should_transform. a: {cinematic, moment, hands_left,
--- stage (wound_stage), phase (enc.phase), powerless, mad_phase (thresholds a powerless boss
--- already got mad at)}. A boss that transformed before losing its power is not mad at those again.
function logic.phase_reaction(a)
  local reached = a.phase or 1
  if a.powerless then reached = math.max(reached, a.mad_phase or 1) end
  local target = logic.should_transform{cinematic = a.cinematic, moment = a.moment,
    target = logic.phase_cross(reached - 1, a.stage), hands_left = a.hands_left}
  if not target then return nil end
  return a.powerless and 'mad' or 'transform', target
end

--- Rule twists (setting "Boss phases change the rules"), always through the boss's own mechanic.
--- once: applied when the phase is reached; draw: applied after every draw while in that phase.
logic.TWISTS = {
  bl_final_acorn = {[2] = {once = 'acorn_shuffle'}, [3] = {once = 'acorn_shuffle'}},
  bl_final_leaf = {[2] = {draw = 'leaf_debuff', count = 1}, [3] = {draw = 'leaf_debuff', count = 2}},
  bl_final_vessel = {[2] = {once = 'vessel_heal', ratio = 0.10}, [3] = {once = 'vessel_heal', ratio = 0.10}},
  bl_final_heart = {[2] = {draw = 'heart_extra', count = 1}, [3] = {draw = 'heart_extra', count = 1, beam = true}},
  bl_final_bell = {[2] = {draw = 'bell_force', count = 2}, [3] = {draw = 'bell_force', count = 2}},
}

function logic.twist_for(boss, phase)
  local t = boss and logic.TWISTS[boss]
  return t and t[phase] or nil
end

--- Up to n distinct random elements of list (rand = math.random signature); list is not changed.
function logic.sample(list, n, rand)
  local pool = {}
  for i, v in ipairs(list or {}) do pool[i] = v end
  local out = {}
  for _ = 1, math.min(n or 0, #pool) do out[#out + 1] = table.remove(pool, rand(#pool)) end
  return out
end

--- Fisher-Yates shuffle in place (rand = math.random signature). Returns list.
function logic.shuffle(list, rand)
  for i = #list, 2, -1 do
    local j = rand(i)
    list[i], list[j] = list[j], list[i]
  end
  return list
end

--- Avatar stance per phase: roam interval factor and aura level (0 none, 1 faint, 2 strong).
logic.STANCES = {[1] = {roam = 1, aura = 0}, [2] = {roam = 0.6, aura = 1}, [3] = {roam = 0.6, aura = 2}}

function logic.stance(phase) return logic.STANCES[phase] or logic.STANCES[1] end

--- HP-bar phase marker (roman numerals, not localized).
function logic.phase_marker(phase)
  if phase == 2 then return 'II' end
  if phase == 3 then return 'III' end
  return ''
end

--- Transformation roar: the chip swells (and shakes) for ROAR.duration seconds.
logic.ROAR = {duration = 0.5, grow = 0.25, shake = 0.08}

function logic.roar_scale(elapsed, duration)
  if not elapsed or not duration or elapsed < 0 or elapsed >= duration then return 1 end
  return 1 + logic.ROAR.grow * math.sin(math.pi * elapsed / duration)
end

-- Memory, nemesis, intro plan, achievements (1.1) -------------------------------------------------------

logic.FINAL_BOSSES = {'bl_final_acorn', 'bl_final_leaf', 'bl_final_vessel', 'bl_final_heart', 'bl_final_bell'}
logic.NEMESIS_MIN_LOSSES = 3
logic.REMATCH_CHANCE = 0.5 -- regular bosses: chance the intro becomes the rematch line
logic.NO_MANNERS_COUNT = 10

--- Profile memory (saved with the Balatro profile, plain data).
function logic.new_memory()
  return {bosses = {}, nemesis = nil, broken = {}, interrupted = {}, final_defeated = {},
    final_defeated_twisted = {}, loss_seq = 0}
end

local function boss_record(mem, key)
  local r = mem.bosses[key]
  if not r then
    r = {fights = 0, wins = 0, losses = 0, last = nil, last_loss = 0}
    mem.bosses[key] = r
  end
  return r
end

--- result: 'fight' (blind set), 'won' (the player beat the boss), 'lost' (the boss ended the run).
--- A loss also counts toward the nemesis (recomputed here) and clears a broken flag.
function logic.record_result(mem, key, result)
  local r = boss_record(mem, key)
  if result == 'fight' then
    r.fights = r.fights + 1
  elseif result == 'won' then
    r.wins = r.wins + 1
    r.last = 'won'
  elseif result == 'lost' then
    r.losses = r.losses + 1
    r.last = 'lost'
    mem.loss_seq = (mem.loss_seq or 0) + 1
    r.last_loss = mem.loss_seq
    mem.broken[key] = nil -- it beat you again: the title can come back
    mem.nemesis = logic.pick_nemesis(mem.bosses, mem.broken)
  end
  return r
end

--- The boss with the most losses (at least NEMESIS_MIN_LOSSES), not broken; ties go to the most
--- recent loss (record.last_loss, from mem.loss_seq).
function logic.pick_nemesis(records, broken)
  local best, best_r
  for key, r in pairs(records or {}) do
    local losses = r.losses or 0
    if losses >= logic.NEMESIS_MIN_LOSSES and not (broken and broken[key]) then
      if not best_r or losses > best_r.losses
          or (losses == best_r.losses and (r.last_loss or 0) > (best_r.last_loss or 0)) then
        best, best_r = key, r
      end
    end
  end
  return best
end

--- The player defeated their nemesis: broken (no title until it beats the player again) and no
--- nemesis until the next loss recomputes it.
function logic.break_nemesis(mem, key)
  mem.broken[key] = true
  mem.nemesis = nil
end

--- Intro moments with memory. a: {tier, memory (setting), last ('won'|'lost'|nil: the player's
--- last result against this boss), nemesis (bool), roll (math.random() in [0, 1))}.
--- Full: nemesis_intro (nemesis) or rematch_<last> replaces the shared opener, and the name step
--- becomes generic_name: a boss's own name line ("But I'm The Hook") answers the shared opener.
--- Light: nemesis_intro, or on a REMATCH_CHANCE roll rematch_<last>, replaces the intro.
function logic.intro_plan(a)
  local seq = logic.intro_sequence(a.tier)
  if not a.memory or #seq == 0 then return seq end
  local slot = (a.tier == 'full') and 'opener' or 'intro'
  local swap
  if a.nemesis then
    swap = 'nemesis_intro'
  elseif a.last == 'won' or a.last == 'lost' then
    if a.tier == 'full' or (a.roll or 1) < logic.REMATCH_CHANCE then swap = 'rematch_' .. a.last end
  end
  if not swap then return seq end
  local out = {}
  for i, m in ipairs(seq) do
    if m == slot then out[i] = swap elseif m == 'name' then out[i] = 'generic_name' else out[i] = m end
  end
  return out
end

logic.ACHIEVEMENTS = {'fb_showdown_survivor', 'fb_clean_sweep', 'fb_rude', 'fb_no_manners', 'fb_last_laugh',
  'fb_overkill', 'fb_phase_skipper', 'fb_comeback', 'fb_nemesis_slayer', 'fb_twisted'}

local function has_all(set, keys)
  for _, k in ipairs(keys) do
    if not (set and set[k]) then return false end
  end
  return true
end

--- Achievements earned by defeating a boss. a: {showdown, start (score before the winning hand),
--- hands_left (after it), hand (its id), laughed_hand (id of the hand the boss laughed at),
--- nemesis (it was the profile nemesis), final_defeated, final_defeated_twisted (profile sets,
--- including this win)}.
function logic.defeat_achievements(a)
  local out = {}
  if a.showdown then
    out[#out + 1] = 'fb_showdown_survivor'
    if a.start ~= nil and a.start <= 0 then out[#out + 1] = 'fb_overkill' end
    if a.hands_left == 0 then out[#out + 1] = 'fb_comeback' end
  end
  if a.laughed_hand and a.hand and a.hand == a.laughed_hand + 1 then out[#out + 1] = 'fb_last_laugh' end
  if a.nemesis then out[#out + 1] = 'fb_nemesis_slayer' end
  if has_all(a.final_defeated, logic.FINAL_BOSSES) then out[#out + 1] = 'fb_clean_sweep' end
  if has_all(a.final_defeated_twisted, logic.FINAL_BOSSES) then out[#out + 1] = 'fb_twisted' end
  return out
end

--- Achievements for interrupting a boss. interrupted: profile set of interrupted boss keys.
function logic.interrupt_achievements(interrupted)
  local n = 0
  for _ in pairs(interrupted or {}) do n = n + 1 end
  local out = {'fb_rude'}
  if n >= logic.NO_MANNERS_COUNT then out[#out + 1] = 'fb_no_manners' end
  return out
end

--- Achievements for a phase change in one hand.
function logic.phase_achievements(from, to)
  if from == 1 and to == 3 then return {'fb_phase_skipper'} end
  return {}
end

-- Personalities (1.2) ------------------------------------------------------------------------------

logic.PERSONALITIES = {'bully', 'smug', 'killer', 'venom', 'chaos', 'royal'}
logic.DEFAULT_PERSONALITY = 'bully'

local PERSONALITY_SET = {}
for _, k in ipairs(logic.PERSONALITIES) do PERSONALITY_SET[k] = true end

--- A personality as given to register_encounter: the key when valid, otherwise the default and a
--- warning (nil means "not given": the default, no warning).
function logic.clean_personality(value)
  if value == nil then return logic.DEFAULT_PERSONALITY, nil end
  if PERSONALITY_SET[value] then return value, nil end
  return logic.DEFAULT_PERSONALITY,
    ('unknown personality %s, using %s'):format(tostring(value), logic.DEFAULT_PERSONALITY)
end

-- Reading the run: intro jabs, censor (1.2) -------------------------------------------------------

--- Jokers that beat a boss outright (the jab_counter jab names them as #2#).
logic.COUNTER_JOKERS = {'j_chicot', 'j_luchador', 'j_matador', 'j_mr_bones'}
--- Jokers every player knows (the jab_famous jab names them as #2#).
logic.FAMOUS_JOKERS = {'j_blueprint', 'j_brainstorm', 'j_baron', 'j_dna', 'j_mime', 'j_cavendish',
  'j_triboulet', 'j_perkeo', 'j_yorick', 'j_caino', 'j_sock_and_buskin', 'j_hologram'}
--- Jab thresholds: shop rerolls since the previous boss, dollars (broke / loaded), share of the deck in
--- one suit, deck size (tiny / huge).
logic.JAB = {rerolls = 5, broke = 3, loaded = 50, onesuit = 0.75, tiny = 30, huge = 70}
--- Chance that a non-counter jab replaces the boss's own threat (counter jokers always jab).
logic.JAB_CHANCE = 1 / 3

local FAMOUS_SET = {}
for _, k in ipairs(logic.FAMOUS_JOKERS) do FAMOUS_SET[k] = true end

--- A vanilla boss's main counter: Chicot for the five final bosses, Luchador for the rest. Its own
--- counter line (fb_<blind>_jab_counter) is said only for this joker.
function logic.signature_counter(blind_key)
  for _, k in ipairs(logic.FINAL_BOSSES) do
    if k == blind_key then return 'j_chicot' end
  end
  return 'j_luchador'
end

--- The intro jab (at most one per intro; it replaces the threat line), from the run as the blind is set.
--- s: {jokers (center keys owned), joker_count, joker_slots, skipped (blinds skipped this ante, 0-2),
--- rerolls (shop rerolls since the previous boss blind), dollars, deck_size, suit_max (cards of the
--- most common suit), signature (logic.signature_counter of the boss), last_jab (the moment of the
--- last jab said this run), force (skip the chance roll: the developer key)}.
--- A counter joker always jabs, with no chance roll: the boss's own signature counter first, else a
--- random owned counter. Every other jab that applies is one candidate in a flat list (no tiers),
--- minus the last jab said; with JAB_CHANCE (or force) one is picked uniformly. rand has the
--- math.random signature: rand() the chance roll, rand(n) the pick. Returns {moment, joker} (joker:
--- the center key said as #2# for jab_counter and jab_famous) or nil.
function logic.intro_jab(s, rand)
  local J = logic.JAB
  local jokers = s.jokers or {}
  local owned = {}
  for _, k in ipairs(jokers) do owned[k] = true end
  -- A counter joker (the boss's own signature counter first)
  if s.signature and owned[s.signature] then return {moment = 'jab_counter', joker = s.signature} end
  local counters = {}
  for _, k in ipairs(logic.COUNTER_JOKERS) do
    if owned[k] then counters[#counters + 1] = k end
  end
  if #counters > 0 then return {moment = 'jab_counter', joker = counters[rand(#counters)]} end
  -- Everything else: one flat list
  local list = {}
  local function add(moment, applies)
    if applies and moment ~= s.last_jab then list[#list + 1] = moment end
  end
  local skipped = s.skipped or 0
  add('jab_skipped', skipped == 1)
  add('jab_skipped_both', skipped >= 2)
  add('jab_rerolls', (s.rerolls or 0) >= J.rerolls)
  add('jab_broke', s.dollars ~= nil and s.dollars <= J.broke)
  add('jab_loaded', s.dollars ~= nil and s.dollars >= J.loaded)
  local n = s.deck_size or 0
  add('jab_onesuit', n > 0 and (s.suit_max or 0) >= J.onesuit * n)
  add('jab_tinydeck', n > 0 and n <= J.tiny)
  add('jab_hugedeck', n >= J.huge)
  local count = s.joker_count or #jokers
  add('jab_nojokers', count == 0)
  add('jab_fulljokers', count > 0 and s.joker_slots and s.joker_slots > 0 and count >= s.joker_slots)
  local famous = {}
  for _, k in ipairs(jokers) do
    if FAMOUS_SET[k] then famous[#famous + 1] = k end
  end
  add('jab_famous', #famous > 0)
  if #list == 0 then return nil end
  if not (s.force or rand() < logic.JAB_CHANCE) then return nil end
  local moment = list[rand(#list)]
  if moment == 'jab_famous' then return {moment = moment, joker = famous[rand(#famous)]} end
  return {moment = moment}
end

--- The intro plan (logic.intro_plan) with its threat replaced by the jab moment (nil: kept), and the
--- index of that threat-or-jab step (nil when a memory line kept the slot).
--- Priority: nemesis line > jab > rematch line > threat. The light tier's one step is the threat
--- ('intro'), a rematch line (the jab replaces it) or the nemesis line (kept); the full tier always
--- keeps its threat step, so the jab replaces it whatever the opener became.
function logic.apply_jab(plan, jab_moment)
  local out, at = {}, nil
  for i, m in ipairs(plan) do
    out[i] = m
    if m == 'intro' then
      out[i] = jab_moment or 'intro'
      at = i
    end
  end
  if at then return out, at end
  if jab_moment then
    for i, m in ipairs(out) do
      if m == 'rematch_won' or m == 'rematch_lost' then
        out[i] = jab_moment
        return out, i
      end
    end
  end
  return out, nil
end

--- The bleep over a line with a censored swear: vanilla's short generic1 blip, high and quiet.
logic.BLEEP = {sound = 'generic1', pitch = 2.4, volume = 0.45}

--- Whether a line holds a censored swear: a letter followed by one or more '*' ("f***", "sh*t",
--- "a**"). Any byte of a multi-byte UTF-8 character counts as a letter, so "ク*" and "г*вно" match.
function logic.has_censored(text)
  if type(text) ~= 'string' then return false end
  return text:find('[%a\128-\255]%*') ~= nil
end

-- Reading the run: in-fight comments, overkill, idle (1.2) ----------------------------------------

--- Moments said on a hand that fired nothing else. The reads are run comments (booked by
--- logic.note_comment, capped per blind). 'weak' is the boss's own line: it follows the light tier's
--- spacing and is outside the run-comment caps and the full tier's consecutive-hands rule.
logic.COMMENTS = {weak = true, read_weakhand = true, read_repeat = true, read_discardspam = true,
  read_onecard = true}
logic.READ_ORDER = {'read_repeat', 'read_discardspam', 'read_onecard', 'read_weakhand'}
logic.WEAK_HANDS = {['High Card'] = true, ['Pair'] = true} -- vanilla hand keys (game.lua:2012-2013)
logic.REPEAT_STREAK = 3     -- the same hand type this many hands in a row
logic.DISCARDSPAM_HANDS = 3 -- no discards left with at least this many hands to play, this one included
logic.OVERKILL_RATIO = 2    -- a winning total at least twice the requirement
logic.COMMENT_CAP = 3       -- run comments per blind for final bosses (full tier)
logic.IDLE_FIRST = 25       -- seconds without input before the first idle taunt
logic.IDLE_SECOND = 45      -- seconds after the first before the second
logic.IDLE_MAX = 2          -- idle taunts per blind

--- How many hands in a row (this one included) used hand_type.
function logic.next_streak(last_type, streak, hand_type)
  if hand_type == nil then return 0 end
  if hand_type == last_type then return (streak or 0) + 1 end
  return 1
end

--- The read a scored hand gives (first in READ_ORDER that applies and has not fired this blind).
--- s: {hand_type, big (hit_size 'big'), streak (logic.next_streak), discards_left, discards_used,
--- hands_left (after this hand), cards_played}. fired: the encounter's fired set.
function logic.fight_read(s, fired)
  fired = fired or {}
  local hit = {
    read_repeat = (s.streak or 0) >= logic.REPEAT_STREAK,
    read_discardspam = s.discards_left == 0 and (s.discards_used or 0) > 0
      and (s.hands_left or 0) + 1 >= logic.DISCARDSPAM_HANDS,
    read_onecard = s.cards_played == 1,
    read_weakhand = (logic.WEAK_HANDS[s.hand_type or ''] and not s.big) and true or false,
  }
  for _, m in ipairs(logic.READ_ORDER) do
    if hit[m] and not fired[m] then return m end
  end
  return nil
end

--- Whether a comment may be said. a: {moment, tier, fired, comments (run comments said this blind),
--- last_comment_hand, last_line_hand, hand (this hand's id)}. Never below the light tier, never twice
--- per blind. Light tier: spaced like every in-fight line (logic.line_spaced), and at most one read
--- per blind ('weak' is the boss's own line: not capped). Full tier: 'weak' is free; a read is
--- capped at COMMENT_CAP per blind and never on consecutive hands.
function logic.can_comment(a)
  if a.tier ~= 'light' and a.tier ~= 'full' then return false end
  if a.fired and a.fired[a.moment] then return false end
  if a.tier == 'light' then
    if not logic.line_spaced(a.hand, a.last_line_hand) then return false end
    return a.moment == 'weak' or (a.comments or 0) < 1
  end
  if a.moment == 'weak' then return true end
  if (a.comments or 0) >= logic.COMMENT_CAP then return false end
  if a.last_comment_hand and a.hand and a.hand - a.last_comment_hand <= 1 then return false end
  return true
end

--- The comment for a hand that fired nothing else: the weak-hit line (a.weak) first, then a read.
--- a: logic.fight_read's fields, logic.can_comment's fields (moment is filled in here) and weak.
function logic.pick_comment(a)
  local function allowed(moment)
    local c = {}
    for k, v in pairs(a) do c[k] = v end
    c.moment = moment
    return logic.can_comment(c)
  end
  if a.weak and allowed('weak') then return 'weak' end
  local r = logic.fight_read(a, a.fired)
  if r and allowed(r) then return r end
  return nil
end

--- Book a comment on the encounter (plain saved data): fired, the reaction count and the hand of the
--- last in-fight line (enc.last_line_hand, the light tier's spacing). A read also counts toward the
--- run-comment cap and marks the hand it was said on; 'weak' does not.
function logic.note_comment(enc, moment, hand)
  enc.fired = enc.fired or {}
  enc.fired[moment] = true
  enc.reactions = (enc.reactions or 0) + 1
  enc.last_line_hand = hand
  if moment == 'weak' then return end
  enc.comments = (enc.comments or 0) + 1
  enc.last_comment_hand = hand
end

--- The winning hand scored at least OVERKILL_RATIO times the requirement.
function logic.is_overkill(total, required)
  if not required or required <= 0 then return false end
  return (total or 0) >= logic.OVERKILL_RATIO * required
end

--- Whether an idle taunt is due after idle_for seconds without input; said = taunts said this blind.
function logic.idle_due(idle_for, said)
  said = said or 0
  if said >= logic.IDLE_MAX then return false end
  return (idle_for or 0) >= (said == 0 and logic.IDLE_FIRST or logic.IDLE_SECOND)
end

--- Every personality has a line for each of these (fb_p_<personality>_<moment>_N; tools/check_loc.py).
logic.PERSONALITY_MOMENTS = {'jab_counter', 'jab_skipped', 'jab_skipped_both', 'jab_rerolls', 'jab_broke',
  'jab_loaded', 'jab_onesuit', 'jab_tinydeck', 'jab_hugedeck', 'jab_nojokers', 'jab_fulljokers', 'jab_famous',
  'read_weakhand', 'read_repeat', 'read_discardspam', 'read_onecard', 'idle', 'overkill'}
logic.PERSONALITY_VARIANTS = {read_weakhand = 2, read_repeat = 2, read_discardspam = 2, read_onecard = 2,
  idle = 2, overkill = 2}

function logic.personality_variants(moment)
  return logic.PERSONALITY_VARIANTS[moment] or 1
end

return logic

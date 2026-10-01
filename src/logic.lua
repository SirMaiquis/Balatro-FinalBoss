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

-- Mid-fight reactions: once each per blind, max one per blind in the light tier.
logic.REACTIONS = {big_hand = true, close = true, last_hand = true, disabled = true}

local PRIORITY = {'last_hand', 'close', 'big_hand'}

--- args: {is_boss, is_showdown, entry_tier = 'auto'|'light'|'full', ante, min_ante}
function logic.decide_tier(a)
  if not a.is_boss then return 'none' end
  if a.entry_tier == 'light' or a.entry_tier == 'full' then return a.entry_tier end
  if a.is_showdown then return 'full' end
  if a.ante >= a.min_ante then return 'light' end
  return 'none'
end

function logic.can_fire(moment, tier, fired, reactions)
  if tier ~= 'light' and tier ~= 'full' then return false end
  if fired[moment] then return false end
  if logic.REACTIONS[moment] and tier == 'light' and reactions >= 1 then return false end
  return true
end

--- Decide which moment (if any) a just-scored hand triggers.
--- a: {delta, total, required, hands_left, fired, tier, reactions}
function logic.detect_moments(a)
  if not a.required or a.required <= 0 then return nil end
  if a.total >= a.required then
    return logic.can_fire('defeat', a.tier, a.fired, a.reactions) and 'defeat' or nil
  end
  local hit = {
    last_hand = a.hands_left == 0,
    close = a.total >= logic.CLOSE_RATIO * a.required,
    big_hand = a.delta >= logic.BIG_HAND_RATIO * a.required,
  }
  for _, moment in ipairs(PRIORITY) do
    if hit[moment] and logic.can_fire(moment, a.tier, a.fired, a.reactions) then return moment end
  end
  return nil
end

logic.SHARED_MOMENTS = {opener = true, closer = true}

--- Find the localization key prefix for a moment: boss-specific, then generic.
--- count_of(prefix) returns how many variants (prefix_1, prefix_2, ...) exist.
--- Returns prefix, is_generic  -- or nil when nothing exists.
function logic.resolve_prefix(blind_key, moment, count_of)
  if logic.SHARED_MOMENTS[moment] then
    local shared = 'fb_' .. moment
    if count_of(shared) > 0 then return shared, false end
    return nil
  end
  local specific = 'fb_' .. blind_key .. '_' .. moment
  if count_of(specific) > 0 then return specific, false end
  local generic = 'fb_generic_' .. moment
  if count_of(generic) > 0 then return generic, true end
  return nil
end

-- Showdown stage maths.
logic.WEAK_HIT_RATIO = 0.05 -- a hand under 5% of the boss's max HP makes the avatar laugh

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

local ARENA = {
  [0] = {black_mix = 0.45, contrast = 3.0, spin_mult = 1.0, pitch = 1.0},
  [1] = {black_mix = 0.60, contrast = 3.8, spin_mult = 1.5, pitch = 1.0},
  [2] = {black_mix = 0.75, contrast = 4.5, spin_mult = 2.0, pitch = 1.06},
}

function logic.arena_params(stage)
  return ARENA[stage] or ARENA[0]
end

return logic

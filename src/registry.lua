--- Encounter registry: per-boss presentation data, and line-key resolution against localization.
--- Public API: FinalBoss.register_encounter(def) (see README).
local R = {entries = {}, counts = {}, counts_lang = nil}

local VALID_TIERS = {auto = true, light = true, full = true}
local VALID_FX = {pulse = true, shake = true, flash = true, shatter = true, phase_shift = true}

local function new_entry(blind_key)
  local vanilla = FinalBoss.personality and FinalBoss.personality.VANILLA[blind_key]
  return {blind = blind_key, tier = 'auto', voice = {pitch = 1}, music = nil,
    fx = {intro = 'pulse', defeat = 'shatter'}, phases = nil, moves = nil, death = nil,
    personality = vanilla or FinalBoss.logic.DEFAULT_PERSONALITY}
end

function R.register(def)
  assert(type(def) == 'table' and type(def.blind) == 'string', 'register_encounter: def.blind (blind key) is required')
  local e = new_entry(def.blind)
  if def.tier ~= nil then
    if VALID_TIERS[def.tier] then e.tier = def.tier
    else FinalBoss.util.log('warn', ('register_encounter %s: unknown tier %s, using auto'):format(def.blind, tostring(def.tier))) end
  end
  if type(def.voice) == 'table' and def.voice.pitch ~= nil then
    local pitch = tonumber(def.voice.pitch)
    if pitch then e.voice.pitch = pitch
    else FinalBoss.util.log('warn', ('register_encounter %s: bad voice pitch %s, using 1'):format(def.blind, tostring(def.voice.pitch))) end
  end
  if def.personality ~= nil then
    local p, warning = FinalBoss.logic.clean_personality(def.personality)
    if warning then FinalBoss.util.log('warn', ('register_encounter %s: %s'):format(def.blind, warning)) end
    e.personality = p
  end
  e.music = def.music
  for slot, name in pairs(def.fx or {}) do
    if VALID_FX[name] then e.fx[slot] = name
    else FinalBoss.util.log('warn', ('register_encounter %s: unknown fx %s ignored'):format(def.blind, tostring(name))) end
  end
  e.phases = def.phases
  -- 1.3.1: the line hook lives on the entry only (never saved).
  if def.line ~= nil then
    if type(def.line) == 'function' then e.line = def.line
    else FinalBoss.util.log('warn', ('register_encounter %s: line must be a function, ignored'):format(def.blind)) end
  end
  if def.moves ~= nil then
    local moves, warnings = FinalBoss.logic.clean_moves(def.moves)
    for _, w in ipairs(warnings) do
      FinalBoss.util.log('warn', ('register_encounter %s: moves %s'):format(def.blind, w))
    end
    e.moves = moves
  end
  if def.death ~= nil then
    local death, warnings = FinalBoss.logic.clean_death(def.death)
    for _, w in ipairs(warnings) do
      FinalBoss.util.log('warn', ('register_encounter %s: death %s'):format(def.blind, w))
    end
    e.death = death
  end
  if R.entries[def.blind] then FinalBoss.util.log('info', 'register_encounter: overriding ' .. def.blind) end
  R.entries[def.blind] = e
  return e
end

function R.get(blind_key)
  return R.entries[blind_key] or new_entry(blind_key)
end

--- How many variants prefix_1, prefix_2, ... exist in the current language (stops at the first gap).
function R.count(prefix)
  local lang = G.SETTINGS and G.SETTINGS.language
  if R.counts_lang ~= lang then R.counts, R.counts_lang = {}, lang end
  local n = R.counts[prefix]
  if n == nil then
    local quips = (G.localization and G.localization.misc and G.localization.misc.quips) or {}
    n = 0
    while quips[prefix .. '_' .. (n + 1)] do n = n + 1 end
    R.counts[prefix] = n
  end
  return n
end

--- The boss's line hook (1.3.1): the prefix of the custom line it picked, or nil. The hook and the
--- info it reads run under a local pcall: an error logs one warning per blind and the moment resolves
--- as usual (never util.guard, so a bad hook never disables FinalBoss for the run).
R.line_warned = {}

local function custom_line(blind_key, moment)
  local e = R.entries[blind_key]
  if not (e and e.line) then return nil end
  local ok, name = pcall(function()
    local D = FinalBoss.director
    return e.line(moment, (D and D.line_info) and D.line_info(blind_key) or {})
  end)
  if not ok then
    if not R.line_warned[blind_key] then
      R.line_warned[blind_key] = true
      FinalBoss.util.log('warn', ('%s line hook failed: %s'):format(blind_key, tostring(name)))
    end
    return nil
  end
  return FinalBoss.logic.custom_prefix(blind_key, name, R.count)
end

--- Resolve a moment to a concrete quip key, avoiding the last variant used for that prefix.
--- Order: the boss's line hook (not for shared moments nor opts.skip_boss), boss-specific (unless
--- opts.skip_boss), the boss's personality, generic (logic.resolve_prefix).
function R.resolve(blind_key, moment, last_variant, opts)
  local skip_boss = opts and opts.skip_boss
  local prefix
  if not skip_boss and not FinalBoss.logic.SHARED_MOMENTS[moment] then prefix = custom_line(blind_key, moment) end
  prefix = prefix or FinalBoss.logic.resolve_prefix(blind_key, moment, R.count, FinalBoss.personality.of(blind_key),
    skip_boss)
  if not prefix then return nil end
  local idx = FinalBoss.logic.pick_variant(R.count(prefix), last_variant and last_variant[prefix], math.random)
  if last_variant then last_variant[prefix] = idx end
  return prefix .. '_' .. idx
end

return R

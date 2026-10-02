--- Encounter registry: per-boss presentation data, and line-key resolution against localization.
--- Public API: FinalBoss.register_encounter(def) (see README).
local R = {entries = {}, counts = {}, counts_lang = nil}

local VALID_TIERS = {auto = true, light = true, full = true}
local VALID_FX = {pulse = true, shake = true, flash = true, shatter = true, phase_shift = true}

local function new_entry(blind_key)
  return {blind = blind_key, tier = 'auto', voice = {pitch = 1}, music = nil,
    fx = {intro = 'pulse', defeat = 'shatter'}, phases = nil}
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
  e.music = def.music
  for slot, name in pairs(def.fx or {}) do
    if VALID_FX[name] then e.fx[slot] = name
    else FinalBoss.util.log('warn', ('register_encounter %s: unknown fx %s ignored'):format(def.blind, tostring(name))) end
  end
  e.phases = def.phases
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

--- Resolve a moment to a concrete quip key, avoiding the last variant used for that prefix.
function R.resolve(blind_key, moment, last_variant)
  local prefix = FinalBoss.logic.resolve_prefix(blind_key, moment, R.count)
  if not prefix then return nil end
  local idx = FinalBoss.logic.pick_variant(R.count(prefix), last_variant and last_variant[prefix], math.random)
  if last_variant then last_variant[prefix] = idx end
  return prefix .. '_' .. idx
end

return R

--- Small shared helpers. Loaded first; must not depend on other FinalBoss modules.
local U = {}

local LOGGERS = {
  debug = sendDebugMessage,
  info = sendInfoMessage,
  warn = sendWarnMessage,
  error = sendErrorMessage,
}

function U.log(level, msg)
  local fn = LOGGERS[level] or sendInfoMessage
  fn(tostring(msg), 'FinalBoss')
end

--- Run fn in pcall. On error: log it and disable FinalBoss for the rest of the run.
function U.guard(name, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    U.log('error', ('%s failed: %s'):format(name, tostring(err)))
    if G and G.GAME then U.state().disabled_for_run = true end
    -- Resolved at call time (util loads first): clear stage visuals that normal cleanup will never reach.
    pcall(function()
      if FinalBoss.director and FinalBoss.director.reset_stage then FinalBoss.director.reset_stage() end
    end)
  end
  return ok, err
end

--- Per-run state, saved with the run.
function U.state()
  G.GAME.FinalBoss = G.GAME.FinalBoss or {}
  return G.GAME.FinalBoss
end

function U.copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = type(v) == 'table' and U.copy(v) or v end
  return out
end

--- Fill missing keys of t from defaults (recursively). Keeps existing values.
function U.fill_defaults(t, defaults)
  for k, v in pairs(defaults) do
    if t[k] == nil then
      t[k] = type(v) == 'table' and U.copy(v) or v
    elseif type(v) == 'table' and type(t[k]) == 'table' then
      U.fill_defaults(t[k], v)
    end
  end
  return t
end

function U.dump(v, depth)
  depth = depth or 0
  if type(v) ~= 'table' then return tostring(v) end
  if depth > 4 then return '{...}' end
  local parts = {}
  for k, val in pairs(v) do parts[#parts + 1] = tostring(k) .. '=' .. U.dump(val, depth + 1) end
  table.sort(parts)
  return '{' .. table.concat(parts, ', ') .. '}'
end

function U.now()
  return love.timer.getTime()
end

return U

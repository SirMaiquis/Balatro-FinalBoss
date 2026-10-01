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

return logic

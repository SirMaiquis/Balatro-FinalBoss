--- Speech bubbles on the blind chip (blind.children.fb_bubble) or the showdown avatar:
--- one-off lines, intro sequences, skipping.
local D = {}
D.REACTION_GAP = 2   -- seconds between non-intro lines
D.DOUBLE_SKIP = 0.3  -- second key press within this window skips the whole intro
D.token = 0          -- bumped to cancel pending timers
D.intro = nil        -- {blind, steps, index, duration, pitch, token}
D.last_line_at = -1e9
D.last_skip_at = -1e9
D.saved_click_can = nil
D.avatar_bubble = nil -- avatar-hosted bubble (late-drawn attention_text UIBox, not a child)
D.host = nil         -- the object the current bubble hangs from (blind chip or avatar)

--- Bubbles come from the showdown avatar when it exists, otherwise from the HUD blind chip.
local function host_for(blind)
  return (FinalBoss.avatar and FinalBoss.avatar.anchor()) or blind
end

local function after(delay, fn)
  G.E_MANAGER:add_event(Event({trigger = 'after', delay = delay, timer = 'REAL',
    blocking = false, blockable = false,
    func = function() FinalBoss.util.guard('dialogue_timer', fn); return true end}))
end

local function babble(blind, n, pitch)
  if n <= 0 then return end
  play_sound('voice' .. math.random(1, 11), (pitch or 1) * (math.random() * 0.2 + 1), 0.5)
  if FinalBoss.avatar and blind == FinalBoss.avatar.anchor() then FinalBoss.avatar.talk_bump()
  else blind:juice_up() end
  after(0.13, function() babble(blind, n - 1, pitch) end)
end

function D.hide(blind)
  if D.avatar_bubble then
    D.avatar_bubble:remove()
    D.avatar_bubble = nil
  end
  if blind and blind.children and blind.children.fb_bubble then
    blind.children.fb_bubble:remove()
    blind.children.fb_bubble = nil
  end
  local h = D.host
  if h and h.children and h.children.fb_bubble then
    h.children.fb_bubble:remove()
    h.children.fb_bubble = nil
  end
  D.host = nil
  if FinalBoss.avatar then FinalBoss.avatar.set_talking(false) end
end

function D.show(blind, key, vars, pitch)
  D.hide(blind)
  local host = host_for(blind)
  local on_avatar = host ~= blind
  local align = on_avatar and ((FinalBoss.avatar.side() == 'right') and 'cl' or 'cr') or 'bm'
  local loc_vars = {quip = true}
  for i, v in ipairs(vars or {}) do loc_vars[i] = v end
  -- Avatar bubbles have no parent and are attention_text: vanilla's late draw pass draws them above
  -- cards, and they outlive the avatar's fade until their own hide timer.
  local bubble = UIBox{definition = G.UIDEF.speech_bubble(key, loc_vars),
    config = {align = align, offset = {x = 0, y = 0}, parent = (not on_avatar) and host or nil}}
  bubble:set_role{role_type = 'Minor', xy_bond = 'Weak', r_bond = 'Strong', major = host}
  bubble.states.visible = false -- shown once aligned (timer below)
  if on_avatar then
    bubble.attention_text = true
    D.avatar_bubble = bubble
  else
    host.children.fb_bubble = bubble
  end
  D.host = host
  if on_avatar then FinalBoss.avatar.set_talking(true) end
  after(0.1, function()
    local current = on_avatar and D.avatar_bubble or host.children.fb_bubble
    if current == bubble then
      bubble.states.visible = true
      D.bleep(key) -- 1.2: a censored swear gets its bleep as the bubble appears
    end
  end)
  D.last_line_at = FinalBoss.util.now()
  babble(host, 5, pitch)
end

--- The avatar moved (e.g. to ringside mid-line): the bubble follows it through its Weak bond, so
--- only its side needs updating, or a bubble on the outer side would leave the screen.
function D.follow_avatar()
  local b = D.avatar_bubble
  if not b or not FinalBoss.avatar then return end
  local want = (FinalBoss.avatar.side() == 'right') and 'cl' or 'cr'
  if b.alignment.type ~= want then b:set_alignment({type = want}) end
end

--- The text of a quip key in the current language (the lines speech_bubble shows,
--- functions/UI_definitions.lua:444-447), joined with spaces; '' when missing.
function D.text_of(key)
  local quips = G.localization and G.localization.misc and G.localization.misc.quips
  local lines = quips and quips[key]
  if type(lines) == 'table' then return table.concat(lines, ' ') end
  if type(lines) == 'string' then return lines end
  return ''
end

--- A line with a censored swear (logic.has_censored) gets a short high bleep over the babble.
--- play_sound follows the game's sound volume (functions/misc_functions.lua:695-718).
function D.bleep(key)
  if not FinalBoss.config.dialogue then return end
  if not FinalBoss.logic.has_censored(D.text_of(key)) then return end
  local b = FinalBoss.logic.BLEEP
  play_sound(b.sound, b.pitch, b.volume)
end

local function enable_chip_skip(blind)
  D.saved_click_can = blind.states.click.can
  blind.states.click.can = true
  blind.click = function() FinalBoss.util.guard('chip_skip', D.skip) end
end

local function disable_chip_skip(blind)
  blind.click = nil -- falls back to the class method
  if D.saved_click_can ~= nil then blind.states.click.can = D.saved_click_can end
  D.saved_click_can = nil
end

--- Run teardown (menu, new run) clears the event queue but not our state: forget an intro whose
--- blind is gone. Never touches the old blind's children or click handler.
local function drop_stale_intro()
  if D.intro and D.intro.blind ~= (G.GAME and G.GAME.blind) then
    D.intro = nil
    D.token = D.token + 1
    D.saved_click_can = nil
  end
end

local function advance(token)
  local it = D.intro
  if not it or it.token ~= token then return end
  it.index = it.index + 1
  local step = it.steps[it.index]
  if not step then return D.end_intro() end
  D.show(it.blind, step.key, step.vars, it.pitch)
  -- 1.2: a step may act as its bubble shows (the boss's flex on its threat line).
  if step.on_show then FinalBoss.util.guard('intro_step', step.on_show) end
  after(it.duration, function() advance(token) end)
end

function D.play_sequence(blind, steps, duration, pitch, on_end)
  D.end_intro()
  D.token = D.token + 1
  D.intro = {blind = blind, steps = steps, index = 0, duration = duration, pitch = pitch, token = D.token,
    on_end = on_end}
  enable_chip_skip(blind)
  advance(D.token)
end

function D.end_intro()
  local it = D.intro
  if not it then return end
  D.intro = nil
  D.token = D.token + 1
  disable_chip_skip(it.blind)
  D.hide(it.blind)
  if it.on_end then FinalBoss.util.guard('intro_end', it.on_end) end
end

function D.intro_active()
  drop_stale_intro()
  return D.intro ~= nil
end

--- First press: next line now. Second press within DOUBLE_SKIP: end the intro.
function D.skip()
  drop_stale_intro()
  local it = D.intro
  if not it then return end
  local now = FinalBoss.util.now()
  local double = now - D.last_skip_at < D.DOUBLE_SKIP
  D.last_skip_at = now
  if double then return D.end_intro() end
  D.token = D.token + 1
  it.token = D.token
  advance(it.token)
end

--- A one-off line (reactions, defeat). Dropped during the cooldown unless opts.force.
function D.say(blind, key, vars, pitch, opts)
  opts = opts or {}
  if not opts.force and FinalBoss.util.now() - D.last_line_at < D.REACTION_GAP then return false end
  D.end_intro()
  D.token = D.token + 1
  local token = D.token
  D.show(blind, key, vars, pitch)
  after(opts.duration or 4, function() if D.token == token then D.hide(blind) end end)
  return true
end

--- Clear everything (new blind).
function D.reset(blind)
  D.end_intro()
  D.token = D.token + 1
  D.hide(blind)
end

--- Leaving a run: drop dialogue state without touching any blind (the run is gone).
function D.drop_on_teardown() D.intro = nil; D.saved_click_can = nil; D.avatar_bubble = nil; D.host = nil; D.token = D.token + 1 end

return D

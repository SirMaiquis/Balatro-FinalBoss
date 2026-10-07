--- Developer keys, active only when config.dev_mode is on and a run is in progress.
---   F5: cycle the forced boss through the vanilla showdowns (6th press clears it). Press it during a
---       round or in the shop, before the blind-select screen appears (that screen reads its own ref_table).
---   Shift+F5: cycle the forced boss through the 23 regular vanilla bosses (step after the last clears it).
---   F6: fire the next moment (big_hand, close, last_hand, disabled, defeat)
---   Shift+F6: fake the next run state (skipped, rerolls, broke, loaded, one suit, counter, famous) and
---       say the jab it gives now
---   F7: dump FinalBoss state to the Lovely log
---   Shift+F7: an idle taunt now
---   F8: push the current final boss to its next phase (cinematic showdowns)
---   F9: make the current boss your nemesis (profile memory) and show it
local DT = {}
DT.SHOWDOWNS = {'bl_final_acorn', 'bl_final_leaf', 'bl_final_vessel', 'bl_final_heart', 'bl_final_bell'}
DT.force_idx = 0

function DT.on()
  return FinalBoss.config.dev_mode and G.GAME and G.STAGE == G.STAGES.RUN
end

SMODS.Keybind{key_pressed = 'f5', action = function()
  if not DT.on() then return end
  if G.CONTROLLER and G.CONTROLLER.held_keys and G.CONTROLLER.held_keys.lalt then return end -- smods Alt+F5 restart
  local held = G.CONTROLLER and G.CONTROLLER.held_keys or {}
  if held.lshift or held.rshift then return end -- Shift+F5 is the regular-boss cycle below
  DT.force_idx = DT.force_idx % (#DT.SHOWDOWNS + 1) + 1
  local key = DT.SHOWDOWNS[DT.force_idx] -- nil on the last step clears the force
  G.FORCE_BOSS = key
  if key and G.GAME.round_resets and G.GAME.round_resets.blind_choices then
    G.GAME.round_resets.blind_choices.Boss = key
  end
  FinalBoss.util.log('info', 'dev: forced boss = ' .. tostring(key))
end}

SMODS.Keybind{key_pressed = 'f7', action = function()
  if not DT.on() then return end
  local held = G.CONTROLLER and G.CONTROLLER.held_keys or {}
  if held.lshift or held.rshift then return end -- the Shift variant below
  local blind = G.GAME.blind
  FinalBoss.util.log('info', 'dev: state = ' .. FinalBoss.util.dump(G.GAME.FinalBoss))
  FinalBoss.util.log('info', 'dev: memory = ' .. FinalBoss.util.dump(FinalBoss.memory.data()))
  FinalBoss.util.log('info', ('dev: chips=%s blind.chips=%s last_hand_score=%s hands_left=%s'):format(
    tostring(G.GAME.chips), tostring(blind and blind.chips), tostring(SMODS.last_hand_score),
    tostring(G.GAME.current_round and G.GAME.current_round.hands_left)))
end}

DT.MOMENTS = {'big_hand', 'close', 'last_hand', 'disabled', 'defeat'}
DT.moment_idx = 0

--- F6: fire the next moment (forced, ignores once-per-blind and cooldown).
SMODS.Keybind{key_pressed = 'f6', action = function()
  if not DT.on() then return end
  local held = G.CONTROLLER and G.CONTROLLER.held_keys or {}
  if held.lshift or held.rshift then return end -- the Shift variant below
  DT.moment_idx = DT.moment_idx % #DT.MOMENTS + 1
  local moment = DT.MOMENTS[DT.moment_idx]
  -- 'defeat' says the nemesis's own defeat line when this boss is the nemesis, like the real one.
  local enc = G.GAME.FinalBoss and G.GAME.FinalBoss.encounter
  local opts = {force = true, line = FinalBoss.memory.defeat_line(enc, moment)}
  local ok, fired = FinalBoss.util.guard('dev_f6', FinalBoss.director.fire, moment, opts)
  FinalBoss.util.log('info', ('dev: fire %s -> %s'):format(moment, tostring(ok and fired)))
end}

DT.regular_idx = 0

local function regular_bosses()
  local list = {}
  for key, b in pairs(G.P_BLINDS) do
    if b.boss and not b.boss.showdown and key:sub(1, 3) == 'bl_' and not b.original_mod then list[#list + 1] = b end
  end
  table.sort(list, function(a, b) return (a.order or 0) < (b.order or 0) end)
  return list
end

--- Shift+F5: force the next regular vanilla boss (same timing rule as F5: press it in a round or the shop).
local function force_regular()
  if not DT.on() then return end
  local list = regular_bosses()
  DT.regular_idx = DT.regular_idx % (#list + 1) + 1
  local b = list[DT.regular_idx] -- nil on the last step clears the force
  local key = b and b.key
  G.FORCE_BOSS = key
  if key and G.GAME.round_resets and G.GAME.round_resets.blind_choices then
    G.GAME.round_resets.blind_choices.Boss = key
  end
  FinalBoss.util.log('info', ('dev: forced regular boss %d/%d = %s'):format(DT.regular_idx, #list, tostring(key)))
end

-- smods requires every listed held key (lovely/keybind.toml:18-23), so each Shift gets its own keybind.
SMODS.Keybind{key_pressed = 'f5', held_keys = {'lshift'}, action = force_regular}
SMODS.Keybind{key_pressed = 'f5', held_keys = {'rshift'}, action = force_regular}

--- F8: next phase (plays the transformation; needs a cinematic showdown with the avatar out).
SMODS.Keybind{key_pressed = 'f8', action = function()
  if not DT.on() then return end
  local ok, phase = FinalBoss.util.guard('dev_f8', FinalBoss.phases.force_next)
  FinalBoss.util.log('info', 'dev: next phase -> ' .. tostring(ok and phase))
end}

--- F9: fake a nemesis for the current boss (saved in the profile like a real one; this encounter
--- never earns Nemesis Slayer). Nothing once FinalBoss is disabled for the run.
SMODS.Keybind{key_pressed = 'f9', action = function()
  if not DT.on() or not FinalBoss.director.enabled() then return end
  local ok, key = FinalBoss.util.guard('dev_f9', FinalBoss.memory.fake_nemesis)
  FinalBoss.util.log('info', 'dev: fake nemesis -> ' .. tostring(ok and key))
end}

--- Shift+F6: the next fake run state, said as a jab now (observe.dev_jab).
DT.JABS = {
  {name = 'skipped', state = {skipped = 1}},
  {name = 'rerolls', state = {rerolls = 7}},
  {name = 'broke', state = {dollars = 0}},
  {name = 'loaded', state = {dollars = 99}},
  {name = 'onesuit', state = {suit_max = 45}},
  {name = 'counter', state = {counter = true}},
  {name = 'famous', state = {jokers = {'j_blueprint'}}},
}
DT.jab_idx = 0

local function fake_jab()
  if not DT.on() or not FinalBoss.director.enabled() then return end
  DT.jab_idx = DT.jab_idx % #DT.JABS + 1
  local fake = DT.JABS[DT.jab_idx]
  local ok, said = FinalBoss.util.guard('dev_jab', FinalBoss.observe.dev_jab, fake.state)
  FinalBoss.util.log('info', ('dev: jab %s -> %s'):format(fake.name, tostring(ok and said)))
end

SMODS.Keybind{key_pressed = 'f6', held_keys = {'lshift'}, action = fake_jab}
SMODS.Keybind{key_pressed = 'f6', held_keys = {'rshift'}, action = fake_jab}

--- Shift+F7: an idle taunt now (forced: no cooldown, no idle count).
local function force_idle()
  if not DT.on() or not FinalBoss.director.enabled() then return end
  local ok, fired = FinalBoss.util.guard('dev_idle', FinalBoss.director.fire, 'idle', {force = true})
  FinalBoss.util.log('info', 'dev: idle -> ' .. tostring(ok and fired))
end

SMODS.Keybind{key_pressed = 'f7', held_keys = {'lshift'}, action = force_idle}
SMODS.Keybind{key_pressed = 'f7', held_keys = {'rshift'}, action = force_idle}

return DT

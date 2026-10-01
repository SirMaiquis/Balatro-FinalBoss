--- Developer keys, active only when config.dev_mode is on and a run is in progress.
---   F5: cycle the forced boss through the vanilla showdowns (6th press clears it). Press it during a
---       round or in the shop, before the blind-select screen appears (that screen reads its own ref_table).
---   F6: fire the next moment (big_hand, close, last_hand, disabled, defeat)
---   F7: dump FinalBoss state to the Lovely log
local DT = {}
DT.SHOWDOWNS = {'bl_final_acorn', 'bl_final_leaf', 'bl_final_vessel', 'bl_final_heart', 'bl_final_bell'}
DT.force_idx = 0

function DT.on()
  return FinalBoss.config.dev_mode and G.GAME and G.STAGE == G.STAGES.RUN
end

SMODS.Keybind{key_pressed = 'f5', action = function()
  if not DT.on() then return end
  if G.CONTROLLER and G.CONTROLLER.held_keys and G.CONTROLLER.held_keys.lalt then return end -- smods Alt+F5 restart
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
  local blind = G.GAME.blind
  FinalBoss.util.log('info', 'dev: state = ' .. FinalBoss.util.dump(G.GAME.FinalBoss))
  FinalBoss.util.log('info', ('dev: chips=%s blind.chips=%s last_hand_score=%s hands_left=%s'):format(
    tostring(G.GAME.chips), tostring(blind and blind.chips), tostring(SMODS.last_hand_score),
    tostring(G.GAME.current_round and G.GAME.current_round.hands_left)))
end}

DT.MOMENTS = {'big_hand', 'close', 'last_hand', 'disabled', 'defeat'}
DT.moment_idx = 0

--- F6: fire the next moment (forced, ignores once-per-blind and cooldown).
SMODS.Keybind{key_pressed = 'f6', action = function()
  if not DT.on() then return end
  DT.moment_idx = DT.moment_idx % #DT.MOMENTS + 1
  local moment = DT.MOMENTS[DT.moment_idx]
  local ok, fired = FinalBoss.util.guard('dev_f6', FinalBoss.director.fire, moment, {force = true})
  FinalBoss.util.log('info', ('dev: fire %s -> %s'):format(moment, tostring(ok and fired)))
end}

return DT

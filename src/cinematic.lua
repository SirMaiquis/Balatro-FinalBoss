--- Showdown cinematics. Stub until Task 7 (final interface; never slows time).
local C = {}
C.phase = nil
function C.play_intro(blind, nums, on_done) if on_done then on_done() end end
function C.active() return false end
function C.skip() end
function C.retract_bars() end
function C.play_finale(blind) end
function C.game_over(pitch) end
function C.reset() FinalBoss.timescale = 1; C.phase = nil end
return C

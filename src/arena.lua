--- Living arena. Stub until Task 4 (final interface, does nothing).
local A = {}
function A.start(blind, stage) end
function A.resume(blind, stage) end
function A.on_hit(stage) end
function A.apply() end
function A.active() return false end
function A.tick(dt) end
function A.stop() end
function A.reset() end
return A

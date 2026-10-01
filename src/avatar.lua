--- Showdown boss avatar. Stub until Task 5 (final interface, does nothing).
local V = {}
function V.spawn(blind, opts) end
function V.exists() return false end
function V.anchor() return nil end
function V.side() return 'right' end
function V.position() return nil end
function V.tick(dt) end
function V.hit(size) end
function V.laugh(pitch) end
function V.set_wound(stage) end
function V.set_talking(on) end
function V.talk_bump() end
function V.set_tremble(on) end
function V.flash(duration) end
function V.set_dissolve(amount, duration) end
function V.fade_out(duration) end
function V.remove() end
return V

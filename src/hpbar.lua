--- Boss HP bar. Stub until Task 6 (final interface, does nothing).
local H = {}
function H.create(avatar, blind, total, required) end
function H.exists() return false end
function H.update(total, required, instant) end
function H.damage(delta, size) end
function H.tick(dt) end
function H.remove() end
return H

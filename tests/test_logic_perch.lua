local logic = require('src.logic')
local T = {}

-- Vanilla run layout (TILE 20 x 11.5, functions/common_events.lua set_screen_positions).
local function rect(x1, y1, x2, y2) return {x = x1, y = y1, w = x2 - x1, h = y2 - y1} end
local AREAS = {
  hand = rect(4.86, 8.89, 17.15, 11.5),
  play = rect(5.57, 5.29, 16.43, 7.90),
  jokers = rect(4.76, 0, 14.8, 2.61),
  consumeables = rect(15.0, 0, 19.7, 2.61),
  deck = rect(17.25, 8.89, 19.5, 11.5),
  room = rect(-0.5, 0, 20.5, 11.5), -- G.ROOM plus the 0.5 margin avatar.lua allows
}
local HUD_RIGHT = 4.6
local S = 2.1
local BOX_W = 3.1
local BOX_HS = {0.9, 1.05, 1.15} -- estimated HP box height plus margin either way

local function overlaps(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function fmt(r) return ('{%.2f, %.2f, %.2f, %.2f}'):format(r.x, r.y, r.w, r.h) end

local function each_perch(fn)
  for _, bh in ipairs(BOX_HS) do
    for i = 1, 4 do
      local r = logic.perch_rect(i, AREAS, S, bh, BOX_W)
      assert(r, 'perch ' .. i .. ' must exist')
      fn(i, r, bh)
    end
  end
end

T['perch_rect: every perch stays inside the room'] = function()
  each_perch(function(i, r)
    local room = AREAS.room
    assert(r.x >= room.x and r.y >= room.y and r.x + r.w <= room.x + room.w and r.y + r.h <= room.y + room.h,
      'perch ' .. i .. ' leaves the room: ' .. fmt(r))
  end)
end

T['perch_rect: no perch touches hand, deck, jokers or consumables'] = function()
  each_perch(function(i, r, bh)
    for _, name in ipairs({'hand', 'deck', 'jokers', 'consumeables'}) do
      assert(not overlaps(r, AREAS[name]), ('perch %d (box %.2f) overlaps %s: %s'):format(i, bh, name, fmt(r)))
    end
  end)
end

T['perch_rect: ringside clears the play area and ends above the deck'] = function()
  each_perch(function(i, r)
    if i ~= logic.PERCH_RINGSIDE then return end
    assert(not overlaps(r, AREAS.play), 'ringside overlaps play: ' .. fmt(r))
    assert(r.y + r.h <= AREAS.deck.y, 'ringside HP box reaches the deck: ' .. fmt(r))
  end)
end

T['perch_rect: no perch reaches the HUD'] = function()
  each_perch(function(i, r)
    assert(r.x >= HUD_RIGHT, 'perch ' .. i .. ' reaches the HUD: ' .. fmt(r))
  end)
end

T['perch_rect: chip sits at the top, HP box centred under it'] = function()
  local r = logic.perch_rect(1, AREAS, S, 1, BOX_W)
  local play = AREAS.play
  local ax = r.x + (r.w - S) / 2
  assert(math.abs(ax - (play.x + play.w + 1.2)) < 1e-9, 'ringside x')
  assert(math.abs(r.y - (play.y + play.h / 2 - S / 2 - 0.8)) < 1e-9, 'ringside y')
  assert(math.abs(r.h - (S + 1)) < 1e-9, 'height is chip + box')
  assert(r.w == BOX_W, 'width is the wider of chip and box')
end

T['perch_rect: left-middle matches the play corner'] = function()
  local r = logic.perch_rect(2, AREAS, S, 1, BOX_W)
  local ax = r.x + (r.w - S) / 2
  assert(math.abs(ax - (AREAS.play.x - 0.2)) < 1e-9, 'left-middle x')
  assert(math.abs(r.y - (AREAS.play.y - 0.1)) < 1e-9, 'left-middle y')
end

T['perch_rect: clamped into the room'] = function()
  local areas = {play = rect(15, 5, 19.5, 7.6), room = AREAS.room}
  local r = logic.perch_rect(1, areas, S, 1, BOX_W)
  assert(r.x + r.w <= 20.5 + 1e-9, 'clamped right: ' .. fmt(r))
end

T['perch_rect: unknown perch or missing area is nil'] = function()
  assert(logic.perch_rect(5, AREAS, S, 1, BOX_W) == nil, 'perch 5')
  assert(logic.perch_rect(1, {}, S, 1, BOX_W) == nil, 'no play area')
  assert(logic.perch_rect(4, {play = AREAS.play}, S, 1, BOX_W) == nil, 'no consumables')
end

return T

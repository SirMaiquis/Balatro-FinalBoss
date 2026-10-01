--- Boss HP bar: hangs under the avatar; damage trail, stage flashes and
--- damage numbers. Numbers only — no localized text beyond the game's own boss name.
local H = {}
H.W, H.H = 3.0, 0.28
H.GHOST_HOLD, H.GHOST_DRAIN = 0.4, 0.35
H.DARKEN = {[0] = 0, [1] = 0.2, [2] = 0.4}
H.ui = nil
H.view = {text = '', frac = 1, ghost = 1} -- read by the progress_bar nodes every frame
H.ghost_from, H.ghost_until, H.flash_until, H.stage = 1, 0, 0, 0
H.colour = {1, 0, 0, 1}
H.fill_col = {1, 0, 0, 1}
H.trail_col = {1, 1, 1, 0.85}

local function now() return FinalBoss.util.now() end

--- One bar row on vanilla progress_bar nodes (pixel-stepped rounded rects, like the profile
--- progress bars). The nodes keep references to H.view and the colour tables, so values and
--- colours are mutated in place. Padding 0 keeps the nested fill exactly over its parent.
local function bar_row()
  return {n = G.UIT.R, config = {align = 'cm', padding = 0.03}, nodes = {
    {n = G.UIT.C, config = {align = 'cl', padding = 0, minw = H.W, minh = H.H, r = 0.1, res = 0.6, colour = G.C.BLACK, emboss = 0.05,
      progress_bar = {max = 1, ref_table = H.view, ref_value = 'ghost', empty_col = G.C.BLACK, filled_col = H.trail_col}},
      nodes = {
        {n = G.UIT.C, config = {align = 'cl', padding = 0, minw = H.W, minh = H.H, r = 0.1, res = 0.6, colour = G.C.BLACK, -- alpha > 0.01 or draw_self skips it
          progress_bar = {max = 1, ref_table = H.view, ref_value = 'frac', empty_col = G.C.CLEAR, filled_col = H.fill_col}},
          nodes = {}},
      }},
  }}
end

local function text_ui(avatar, name)
  return UIBox{
    definition = {n = G.UIT.ROOT, config = {align = 'cm', colour = G.C.CLEAR, padding = 0.02}, nodes = {
      {n = G.UIT.R, config = {align = 'cm'}, nodes = {
        {n = G.UIT.T, config = {text = name, scale = 0.32, colour = G.C.WHITE, shadow = true}}}},
      bar_row(),
      {n = G.UIT.R, config = {align = 'cm'}, nodes = {
        {n = G.UIT.T, config = {ref_table = H.view, ref_value = 'text', scale = 0.28, colour = G.C.WHITE, shadow = true}}}},
    }},
    config = {major = avatar, align = 'bm', offset = {x = 0, y = 0.05}, bond = 'Weak', r_bond = 'Weak',
      can_collide = false},
  }
end

--- Write the stage colour (boss colour, darkened per stage) into the shared fill table.
local function paint_fill(flash)
  local c = flash and {1, 1, 1, 1} or darken(H.colour, H.DARKEN[H.stage] or 0)
  H.fill_col[1], H.fill_col[2], H.fill_col[3], H.fill_col[4] = c[1], c[2], c[3], 1
end

function H.exists() return H.ui ~= nil end

function H.create(avatar, blind, total, required)
  H.remove()
  if not avatar or not blind then return end
  local c = (blind.config.blind and blind.config.blind.boss_colour) or G.C.RED
  H.colour = {c[1], c[2], c[3], 1}
  H.fill_col, H.trail_col = {1, 0, 0, 1}, {1, 1, 1, 0.85} -- fresh tables: the nodes keep these references
  H.update(total, required, true) -- first: the first layout must see the real text
  -- Normal UIBox pass (no attention_text): drawn before card areas, so cards stay over the bar.
  H.ui = text_ui(avatar, blind.loc_name or (blind.config.blind and blind.config.blind.name) or '')
end

function H.update(total, required, instant)
  local frac = FinalBoss.logic.hp_fraction(total, required)
  local stage = FinalBoss.logic.wound_stage(frac)
  local flash = stage ~= H.stage and not instant
  if flash then H.flash_until = now() + 0.3 end
  H.stage, H.view.frac = stage, frac
  paint_fill(flash or now() < H.flash_until)
  if instant then H.view.ghost = frac end
  H.ghost_from = H.view.ghost -- the trail drains from here to the bar over GHOST_DRAIN
  H.ghost_until = now() + H.GHOST_HOLD
  local hp = math.max(0, (required or 0) - (total or 0))
  local text = number_format(hp) .. ' / ' .. number_format(required or 0)
  local relayout = H.ui and #text ~= #H.view.text
  H.view.text = text
  if relayout then
    H.ui:recalculate()
    H.ui.alignment.prev_type = '' -- forces align_to_major to re-centre on the next move
  end
end

function H.damage(delta, size)
  local anchor = FinalBoss.avatar.anchor()
  if not anchor or not delta or delta <= 0 then return end
  attention_text{
    text = '-' .. number_format(delta),
    scale = (size == 'big' and 1.6) or (size == 'weak' and 0.6) or 1.0,
    hold = 0.9,
    major = anchor,
    align = 'tm',
    offset = {x = 0, y = -0.3},
    colour = (size == 'weak') and G.C.UI.TEXT_INACTIVE or G.C.RED,
    silent = true,
  }
  if size == 'big' and not G.SETTINGS.reduced_motion then G.ROOM.jiggle = G.ROOM.jiggle + 2 end
end

function H.tick(dt)
  if not H.ui then return end
  local v = H.view
  if H.flash_until > 0 and now() >= H.flash_until then
    H.flash_until = 0
    paint_fill(false)
  end
  if v.ghost > v.frac and now() >= H.ghost_until then
    v.ghost = math.max(v.frac, v.ghost - (H.ghost_from - v.frac) * (dt or 0) / H.GHOST_DRAIN)
  end
end

function H.remove()
  -- UIElement:remove cascades through the nodes; the colour tables are rebuilt by the next create.
  if H.ui then H.ui:remove(); H.ui = nil end
  H.view.frac, H.view.ghost, H.ghost_from, H.stage = 1, 1, 1, 0
  H.view.text, H.flash_until, H.ghost_until = '', 0, 0
end

return H

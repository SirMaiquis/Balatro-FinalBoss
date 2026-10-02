--- Config menu: "Config" (config_tab: encounters), "Showdowns" and "Credits" (extra_tabs), and the
--- menu theme (ui_config) in the boss palette of the icon and thumbnail.
local UI = {}
UI.preview = {warn = ''}
UI.static = {note = ''}
UI.track = nil -- UIBox of the Showdowns tab's ante track, swapped in place on every settings change

local ANTES = {1, 2, 3, 4, 5, 6, 7, 8}
local TRACK_LAST, TRACK_ROW = 16, 8 -- antes on the track, boxes per row
local TRACK_CHIP = 'bl_final_heart' -- chip shown on the showdown antes
local URL = {
  github = 'https://github.com/SirMaiquis/Balatro-FinalBoss',
  music = 'https://www.youtube.com/watch?v=XCBC8oz8dfE',
  tip = 'https://ko-fi.com/sirmaiquis',
}

-- Boss palette: Crimson Heart, deep violet, near-black; group = violet over near-black.
local PALETTE = {crimson = 'ac3232', violet = '5a3a9e', night = '1a0f1f', group = '2e1f45', white = 'f2f2f2'}

--- A fresh colour table (never shared, so nothing can tint another element by mutating it).
local function col(name, alpha)
  local c = HEX(PALETTE[name])
  c[4] = alpha or 1
  return c
end

-- smods reads these in create_UIBox_mods / buildModDescTab and the collection pages (src/ui.lua).
FinalBoss.mod.ui_config = {
  colour = col('night'),
  bg_colour = col('night', 0.75),
  back_colour = col('crimson'),
  tab_button_colour = col('violet'),
  outline_colour = col('crimson'),
  author_colour = col('white'),
  author_bg_colour = col('violet', 0.85),
  author_outline_colour = col('crimson'),
  collection_bg_colour = col('night', 0.8),
  collection_back_colour = col('crimson'),
  collection_outline_colour = col('crimson'),
  collection_option_cycle_colour = col('violet'),
}

local function save() SMODS.save_mod_config(FinalBoss.mod) end

-- Generic node helpers ------------------------------------------------------------------------

local function text(str, colour, scale, extra)
  local config = {text = str, scale = scale or 0.4, colour = colour or G.C.UI.TEXT_LIGHT, shadow = true}
  for k, v in pairs(extra or {}) do config[k] = v end
  return {n = G.UIT.T, config = config}
end

local function row(nodes, padding)
  return {n = G.UIT.R, config = {align = 'cm', padding = padding or 0.03}, nodes = nodes}
end

local function text_row(ref_table, ref_value, colour)
  return row({{n = G.UIT.T, config = {ref_table = ref_table, ref_value = ref_value, scale = 0.35, colour = colour}}},
    0.05)
end

local function root(nodes)
  return {n = G.UIT.ROOT, config = {align = 'cm', padding = 0.1, colour = G.C.CLEAR, minw = 8}, nodes = nodes}
end

local function divider()
  return row({{n = G.UIT.B, config = {w = 6, h = 0.03, colour = {1, 1, 1, 0.12}}}}, 0.08)
end

--- Greys out every text of a node tree (used for the developer toggle).
local function dim(node)
  if node.n == G.UIT.T then node.config.colour = G.C.UI.TEXT_INACTIVE end
  for _, child in ipairs(node.nodes or {}) do dim(child) end
  return node
end

--- White rounded card from a localized quip (TagManager's custom_text_container).
local function quip_card(key)
  local lines = {}
  localize{type = 'quips', key = key, vars = {}, nodes = lines}
  local rows = {}
  for _, line in ipairs(lines) do rows[#rows + 1] = {n = G.UIT.R, config = {align = 'cm'}, nodes = line} end
  return {n = G.UIT.R, config = {align = 'cm', padding = 0.1, r = 0.2, colour = G.C.WHITE, emboss = 0.05},
    nodes = rows}
end

--- A dark rounded box with a crimson title pill on top and its controls under it.
local function group(title, controls)
  local nodes = {{n = G.UIT.R, config = {align = 'cm', padding = 0.06, r = 0.1, colour = col('crimson')},
    nodes = {text(title, G.C.UI.TEXT_LIGHT, 0.4)}}}
  for _, control in ipairs(controls) do nodes[#nodes + 1] = control end
  return {n = G.UIT.C, config = {align = 'tm', padding = 0.12, r = 0.15, colour = col('group'), emboss = 0.05},
    nodes = nodes}
end

local function button(label, func, colour)
  return row({UIBox_button{label = {label}, button = func, colour = colour, minw = 3.85, minh = 0.7, scale = 0.45}},
    0.08)
end

-- Settings controls -----------------------------------------------------------------------------

G.FUNCS.fb_cycle = function(args)
  local c = args.cycle_config
  c.fb_table[c.fb_field] = c.fb_values[args.to_key]
  UI.refresh_preview()
  save()
end

local function toggle(label_key, tbl, field, style)
  local args = {label = localize(label_key), ref_table = tbl, ref_value = field,
    callback = function() UI.refresh_preview(); save() end}
  for k, v in pairs(style or {}) do args[k] = v end
  return create_toggle(args)
end

local function cycle(label_key, tbl, field, values, labels)
  local current = 1
  for i, v in ipairs(values) do if v == tbl[field] then current = i end end
  return create_option_cycle{label = localize(label_key), options = labels or values, current_option = current,
    opt_callback = 'fb_cycle', w = 4, scale = 0.8, colour = col('crimson'),
    fb_table = tbl, fb_field = field, fb_values = values}
end

-- Ante track ------------------------------------------------------------------------------------

local function chip_sprite()
  local proto = G.P_BLINDS[TRACK_CHIP]
  local sprite = SMODS.create_sprite(0, 0, 0.5, 0.5, proto.atlas or 'blind_chips', copy_table(proto.pos))
  sprite.states.drag.can = false
  return sprite
end

--- One ante: lit crimson with the chip when it is a showdown, else a dim box with the number.
--- Every box has the same size, so swapping the track never resizes the tab.
local function ante_box(ante, showdown)
  local nodes
  if showdown then
    nodes = {row({{n = G.UIT.O, config = {object = chip_sprite()}}}, 0), row({text(tostring(ante), nil, 0.28)}, 0)}
  else
    nodes = {row({text(tostring(ante), G.C.UI.TEXT_INACTIVE, 0.35)}, 0)}
  end
  return {n = G.UIT.C, config = {align = 'cm', minw = 0.75, minh = 0.95, r = 0.1,
    colour = showdown and col('crimson') or {0, 0, 0, 0.3}}, nodes = nodes}
end

local function track_definition()
  local sd = FinalBoss.config.showdown
  local win_ante = (G.GAME and G.GAME.win_ante) or 8
  local track = FinalBoss.logic.showdown_track(sd.enabled, sd.start_ante, sd.every, win_ante, TRACK_LAST)
  local rows = {}
  for first = 1, TRACK_LAST, TRACK_ROW do
    local boxes = {}
    for ante = first, math.min(first + TRACK_ROW - 1, TRACK_LAST) do
      boxes[#boxes + 1] = ante_box(ante, track[ante])
    end
    rows[#rows + 1] = row(boxes, 0.05)
  end
  return {n = G.UIT.ROOT, config = {align = 'cm', padding = 0.02, colour = G.C.CLEAR}, nodes = rows}
end

local function new_track(parent)
  return UIBox{definition = track_definition(), config = {offset = {x = 0, y = 0}, parent = parent, type = 'cm'}}
end

--- Swap the track UIBox for a fresh one (TagManager's change_tags_page / vanilla change_tab).
--- No-op when the Showdowns tab is not open: its box was removed with the tab.
function UI.refresh_track()
  local box = UI.track
  local wrap = box and not box.REMOVED and box.parent
  if not wrap or wrap.REMOVED or wrap.config.object ~= box then return end
  box:remove()
  UI.track = new_track(wrap)
  wrap.config.object = UI.track
  wrap.UIBox:recalculate()
end

function UI.refresh_preview()
  local sd = FinalBoss.config.showdown
  UI.preview.warn = (sd.enabled and sd.start_ante < 4) and localize('fb_cfg_hard') or ''
  UI.refresh_track()
end

-- Tabs ------------------------------------------------------------------------------------------

function UI.encounters_tab()
  local cfg = FinalBoss.config
  return root{
    quip_card('fb_cfg_header'),
    {n = G.UIT.R, config = {align = 'tm', padding = 0.1}, nodes = {
      group(localize('fb_cfg_group_dialogue'), {
        toggle('fb_cfg_dialogue', cfg, 'dialogue'),
        cycle('fb_cfg_intro_speed', cfg, 'intro_speed', {1, 2, 3},
          {localize('fb_speed_slow'), localize('fb_speed_normal'), localize('fb_speed_fast')}),
        cycle('fb_cfg_min_ante', cfg, 'min_ante', ANTES),
      }),
      group(localize('fb_cfg_group_stage'), {
        toggle('fb_cfg_music', cfg, 'music'),
        toggle('fb_cfg_fx', cfg, 'fx'),
        toggle('fb_cfg_cinematic', cfg, 'cinematic'),
      }),
    }},
    divider(),
    dim(toggle('fb_cfg_dev_mode', cfg, 'dev_mode', {w = 2.5, scale = 0.75, label_scale = 0.3})),
  }
end

function UI.showdowns_tab()
  local sd = FinalBoss.config.showdown
  UI.track = new_track(nil) -- the O node below becomes its parent
  UI.refresh_preview()
  UI.static.note = localize('fb_cfg_next_ante')
  local start, every = cycle('fb_cfg_start_ante', sd, 'start_ante', ANTES), cycle('fb_cfg_every', sd, 'every', ANTES)
  start.n, every.n = G.UIT.C, G.UIT.C -- side by side
  return root{
    toggle('fb_cfg_showdown_enabled', sd, 'enabled'),
    {n = G.UIT.R, config = {align = 'cm', padding = 0.05}, nodes = {start, every}},
    row({group(localize('fb_cfg_preview'), {{n = G.UIT.O, config = {object = UI.track}}})}, 0.05),
    text_row(UI.preview, 'warn', G.C.RED),
    text_row(UI.static, 'note', G.C.UI.TEXT_INACTIVE),
  }
end

function UI.credits_tab()
  local s = 0.45
  return root{
    row({text(localize('fb_credits_thanks'), nil, s)}),
    row({text(localize('fb_credits_lead'), nil, s), text(' @SirMaiquis', G.C.GREEN, s, {bump = true, spacing = 1})}),
    row({text(localize('fb_credits_music'), nil, s), text(' ' .. localize('fb_credits_music_by'), G.C.GOLD, s)}, 0.1),
    button(localize('fb_credits_listen'), 'fb_open_music', col('crimson')),
    button(localize('fb_credits_github'), 'fb_open_github', col('violet')),
    row({text(localize('fb_tip_me_message_1'), nil, s)}),
    row({text(localize('fb_tip_me_message_2'), nil, s)}),
    row({text(localize('fb_tip_me_message_3'), nil, s)}),
    button(localize('fb_tip_me'), 'fb_tip_me', col('crimson')),
  }
end

G.FUNCS.fb_open_music = function() love.system.openURL(URL.music) end
G.FUNCS.fb_open_github = function() love.system.openURL(URL.github) end
G.FUNCS.fb_tip_me = function() love.system.openURL(URL.tip) end

FinalBoss.mod.config_tab = UI.encounters_tab
FinalBoss.mod.extra_tabs = function()
  return {
    {label = localize('fb_tab_showdowns'), tab_definition_function = UI.showdowns_tab},
    {label = localize('b_credits'), tab_definition_function = UI.credits_tab},
  }
end

return UI

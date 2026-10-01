--- Config menu: "Encounters" (config_tab) and "Showdowns" (extra_tabs).
local UI = {}
UI.preview = {text = '', warn = ''}
UI.static = {note = ''}

local ANTES = {1, 2, 3, 4, 5, 6, 7, 8}

local function save() SMODS.save_mod_config(FinalBoss.mod) end

function UI.refresh_preview()
  local sd = FinalBoss.config.showdown
  local win_ante = (G.GAME and G.GAME.win_ante) or 8
  local antes = FinalBoss.logic.preview_showdowns(sd.enabled, sd.start_ante, sd.every, win_ante, 5)
  UI.preview.text = localize('fb_cfg_preview') .. ' ' .. table.concat(antes, ', ') .. ', ...'
  UI.preview.warn = (sd.enabled and sd.start_ante < 4) and localize('fb_cfg_hard') or ''
end

G.FUNCS.fb_cycle = function(args)
  local c = args.cycle_config
  c.fb_table[c.fb_field] = c.fb_values[args.to_key]
  UI.refresh_preview()
  save()
end

local function toggle(label_key, tbl, field)
  return create_toggle{label = localize(label_key), ref_table = tbl, ref_value = field,
    callback = function() UI.refresh_preview(); save() end}
end

local function cycle(label_key, tbl, field, values, labels)
  local current = 1
  for i, v in ipairs(values) do if v == tbl[field] then current = i end end
  return create_option_cycle{label = localize(label_key), options = labels or values, current_option = current,
    opt_callback = 'fb_cycle', w = 4, scale = 0.8, fb_table = tbl, fb_field = field, fb_values = values}
end

local function text_row(ref_table, ref_value, colour)
  return {n = G.UIT.R, config = {align = 'cm', padding = 0.05}, nodes = {
    {n = G.UIT.T, config = {ref_table = ref_table, ref_value = ref_value, scale = 0.35, colour = colour}},
  }}
end

local function root(nodes)
  return {n = G.UIT.ROOT, config = {align = 'cm', padding = 0.1, colour = G.C.CLEAR, minw = 8}, nodes = nodes}
end

function UI.encounters_tab()
  local cfg = FinalBoss.config
  return root{
    toggle('fb_cfg_dialogue', cfg, 'dialogue'),
    toggle('fb_cfg_music', cfg, 'music'),
    toggle('fb_cfg_fx', cfg, 'fx'),
    cycle('fb_cfg_intro_speed', cfg, 'intro_speed', {1, 2, 3},
      {localize('fb_speed_slow'), localize('fb_speed_normal'), localize('fb_speed_fast')}),
    cycle('fb_cfg_min_ante', cfg, 'min_ante', ANTES),
    toggle('fb_cfg_dev_mode', cfg, 'dev_mode'),
  }
end

function UI.showdowns_tab()
  local sd = FinalBoss.config.showdown
  UI.refresh_preview()
  UI.static.note = localize('fb_cfg_next_ante')
  return root{
    toggle('fb_cfg_showdown_enabled', sd, 'enabled'),
    cycle('fb_cfg_start_ante', sd, 'start_ante', ANTES),
    cycle('fb_cfg_every', sd, 'every', ANTES),
    text_row(UI.preview, 'text', G.C.UI.TEXT_LIGHT),
    text_row(UI.preview, 'warn', G.C.RED),
    text_row(UI.static, 'note', G.C.UI.TEXT_INACTIVE),
  }
end

FinalBoss.mod.config_tab = UI.encounters_tab
FinalBoss.mod.extra_tabs = function()
  return {{label = localize('fb_tab_showdowns'), tab_definition_function = UI.showdowns_tab}}
end

return UI

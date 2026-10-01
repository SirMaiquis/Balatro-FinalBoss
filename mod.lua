local config = SMODS.current_mod.config
sendDebugMessage("Launching Final Boss!")
local final_boss_enabled = false
local final_boss_min_ante_reached = false

SMODS.current_mod.config_tab = function()
  local toggle_enabled = create_toggle({label = "Enable boss", ref_table = config, ref_value = 'enabled'})


  local min_ante = config['minimum_ante'];
  local min_ante_options = {1, 2, 3, 4, 5, 6, 7, 8};
  print("min_ante: "..min_ante)
  local optionCycle = create_option_cycle({
    w = 1,
    scale = 1,
    label = "Minimum Ante to start the final boss",
    options = min_ante_options,
    opt_callback = 'change_final_boss_min_ante',
    current_option = min_ante,
    identifier = "minimum_ante"
  })
  return {n = G.UIT.ROOT, config = {align = "cm", padding = 0.05, colour = G.C.CLEAR}, 
  nodes = {
		toggle_enabled,
		optionCycle
	}}
end

SMODS.Sound({
  vol = 1,
  pitch = 1,
  key = "music6",
  path = "music6.ogg",
  select_music_track = function ()
    return should_song_play("music6")
  end
})

SMODS.Sound({
  vol = 1,
  pitch = 1,
  key = "music7",
  path = "music7.ogg",
  select_music_track = function ()
    return should_song_play("music7")
  end
})

SMODS.Sound:register_global()

G.FUNCS.change_final_boss_min_ante = function(args)
  config[args.cycle_config.identifier] = args.to_val
end

function Blind:say_final_boss_message()
  G.E_MANAGER:add_event(Event({
      trigger = 'immediate',
      func = (function()
        local key = G.GAME.blind.config.blind.key
        
        local message_sequence = {
          function() self:say_final_boss_message_general(1) end,
          function() self:say_final_boss_message_name(key) end,
          function() self:say_final_boss_message_general(2) end,
          function() self:say_final_boss_message_description(key) end,
          function() self:say_final_boss_message_general(3) end
        }
        
        local function execute_message_sequence(index)
          if index > #message_sequence then
            G.E_MANAGER:add_event(Event({
              trigger = 'after',
              delay = 20,
              blockable = false,
              blocking = false,
              func = function()
                G.GAME.blind:remove_speech_bubble()
                return true
              end
            }))
            return true
          end
          
          message_sequence[index]()
          
          self:add_final_boss_message_event(function()
            return execute_message_sequence(index + 1)
          end)
          
          return true
        end
        
        execute_message_sequence(1)
        return true
      end)
  }))
end

function Blind:add_final_boss_message_event(func)
  G.E_MANAGER:add_event(Event({
    trigger = 'after',
    delay = 7,
    func = func,
    blockable = false,
    blocking = false,
  }))
end

function Blind:say_final_boss_message_general(number)
  local text_key = 'ml_final_boss_message_'..number
  self:say_message(text_key)
end

function Blind:say_final_boss_message_name(key)
  local text_key = 'ml_final_boss_message_name_'..key
  self:say_message(text_key)
end

function Blind:say_final_boss_message_description(key)
  local text_key = 'ml_final_boss_message_description_'..key
  self:say_message(text_key)
end

function Blind:say_message(text_key)
  self:remove_speech_bubble()
  self:add_speech_bubble(text_key, nil, {quip = true})
  self:say_stuff(5)
end

function Blind:add_speech_bubble(text_key, align, loc_vars)
    if self.children.speech_bubble then self.children.speech_bubble:remove() end
    self.config.speech_bubble_align = {align=align or 'bm', offset = {x=0,y=0},parent = self}
    self.children.speech_bubble = 
    UIBox{
        definition = G.UIDEF.speech_bubble(text_key, loc_vars),
        config = self.config.speech_bubble_align
    }
    self.children.speech_bubble:set_role{
        role_type = 'Minor',
        xy_bond = 'Weak',
        r_bond = 'Strong',
        major = self,
    }
    self.children.speech_bubble.states.visible = false
end

function Blind:say_stuff(n, not_first)
    self.talking = true
    if not not_first then 
        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.1,
            blockable = false,
            blocking = false,
            func = function()
                if self.children.speech_bubble then self.children.speech_bubble.states.visible = true end
                self:say_stuff(n, true)
              return true
            end
        }))
    else
        if n <= 0 then self.talking = false; return end
        local new_said = math.random(1, 11)
        while new_said == self.last_said do 
            new_said = math.random(1, 11)
        end
        self.last_said = new_said
        play_sound('voice'..math.random(1, 11), 1*(math.random()*0.2+1), 0.5)
        self:juice_up()
        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            blockable = false, blocking = false,
            delay = 0.13,
            func = function()
                self:say_stuff(n-1, true)
            return true
            end
        }), 'tutorial')
    end
end

function Blind:remove_speech_bubble()
    if self.children.speech_bubble then self.children.speech_bubble:remove(); self.children.speech_bubble = nil end
end

function is_final_boss_enabled()
  return config['enabled']
end

function is_final_boss_min_ante_reached()
  return G.GAME.round_resets.ante >= config['minimum_ante']
end

local original_select_blind = G.FUNCS.select_blind
function G.FUNCS.select_blind(e)
  if not check_final_boss_enabled() then
    return original_select_blind(e)
  end
  random_final_boss_song()
  local t = original_select_blind(e)
  G.E_MANAGER:add_event(Event({
    trigger = 'after',
    delay = 4,
    blockable = false,
    blocking = false,
    func = function()
      if (not is_in_final_boss()) then 
        final_boss_min_ante_reached = false
        return true
      end
      final_boss_min_ante_reached = true
      G.GAME.blind:say_final_boss_message()
      return true
    end
  }))
  return t
end

function get_current_final_boss_song()
  return config['current_final_boss_song']
end

function random_final_boss_song()
  local songs = {
    "music6",
    "music7",
  }
  local random_song = songs[math.random(1, #songs)]
  config['current_final_boss_song'] = random_song
  print("random_final_boss_song: "..random_song)
  return random_song
end

function should_song_play(song)
  if not final_boss_enabled then return false end
  local current_song = get_current_final_boss_song()
  if (current_song ~= song) then return false end
  return is_in_final_boss() and final_boss_min_ante_reached
end

function is_in_final_boss()
  return (G.GAME.blind and G.GAME.blind.boss and is_final_boss_min_ante_reached())
end

function check_final_boss_enabled()
  final_boss_enabled = is_final_boss_enabled()
  return final_boss_enabled
end

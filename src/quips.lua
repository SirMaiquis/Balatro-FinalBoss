--- Loss gloat: when a boss with an encounter beats the player, Jimbo delivers that boss's
--- gloat line on the game-over screen. Text key resolved at filter time (boss-specific -> generic).
local Q = {}

Q.gloat = SMODS.JimboQuip{
  key = 'fb_gloat',
  type = 'loss',
  prefix_config = {key = false},
  extra = {},
  filter = function(self, quip_type)
    if quip_type ~= 'loss' or not FinalBoss.config.dialogue then return false end
    local st = G.GAME and G.GAME.FinalBoss
    if not st or not st.lost_to then return false end
    local key = FinalBoss.registry.resolve(st.lost_to, 'gloat', st.encounter and st.encounter.last_variant)
    if not key then return false end
    self.extra.text_key = key
    return true, {weight = 100}
  end,
}

return Q

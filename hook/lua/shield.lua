local M27Events = import('/mods/M27AI/lua/AI/M27Events.lua')

do --Per Balthazaar - encasing the code in do .... end means that you dont have to worry about using unique variables
    local M27OldShield = Shield
    Shield = Class(M27OldShield) {
        OnDamage = function(self, instigator, amount, vector, dmgType)
            M27OldShield.OnDamage(self, instigator, amount, vector, dmgType)
            ForkThread(M27Events.OnShieldBubbleDamaged, self, instigator)
        end,
    }
end
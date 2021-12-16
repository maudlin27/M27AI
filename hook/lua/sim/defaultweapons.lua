--WARNING: CAREFUL with below hooks - caused spamming of error messages when T1 arti fired despite the event code being commented out
--[[local M27Events = import('/mods/M27AI/lua/AI/M27Events.lua')

M27DefaultProjectileWeapon = DefaultProjectileWeapon

DefaultProjectileWeapon = Class(M27DefaultProjectileWeapon) {
    OnWeaponFired = function(self)
        M27DefaultProjectileWeapon.OnWeaponFired(self)
        M27Events.OnWeaponFired(self)
    end,
    CreateProjectileAtMuzzle = function(self, muzzle)
        M27DefaultProjectileWeapon.CreateProjectileAtMuzzle(self, muzzle)
        M27Events.OnProjectileFired(self, muzzle)
    end,
}
--]]
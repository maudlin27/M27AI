--WARNING: CAREFUL with below hooks - caused spamming of error messages when T1 arti fired despite the event code being commented out
local M27Events = import('/mods/M27AI/lua/AI/M27Events.lua')

M27DefaultProjectileWeapon = DefaultProjectileWeapon

DefaultProjectileWeapon = Class(M27DefaultProjectileWeapon) {
    OnWeaponFired = function(self)
        M27DefaultProjectileWeapon.OnWeaponFired(self)
        M27Events.OnWeaponFired(self)
    end,
    CalculateBallisticAcceleration = function(self, projectile)
        --LOG('CalculateBallisticAcceleration: reprs of self='..reprs(self))
        --LOG('CalculateBallisticAcceleration: reprs of projectile='..reprs(projectile))
        ForkThread(M27Events.OnBombFired, self, projectile)
        return M27DefaultProjectileWeapon.CalculateBallisticAcceleration(self, projectile)
    end,
    --[[CreateProjectileAtMuzzle = function(self, muzzle)
        local oProjectile = M27DefaultProjectileWeapon.CreateProjectileAtMuzzle(self, muzzle)
        M27Events.OnProjectileFired(self, muzzle, oProjectile)
    end,--]]
}
---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by maudlin27.
--- DateTime: 20/03/2022 18:36
---

local M27Events = import('/mods/M27AI/lua/AI/M27Events.lua')

local M27CreateWreckage = CreateWreckage
function CreateWreckage(bp, position, orientation, mass, energy, time, deathHitBox)
    ForkThread(M27Events.OnCreateWreck, position, mass, energy)
    return M27CreateWreckage(bp, position, orientation, mass, energy, time, deathHitBox)
end
local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27OnFirstUpdate = OnFirstUpdate
function OnFirstUpdate()
    M27OnFirstUpdate()
    if M27Config.M27RunVeryFast == true then
        ConExecute("WLD_GameSpeed 10")
    end
end

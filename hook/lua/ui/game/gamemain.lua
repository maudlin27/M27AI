local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27OnFirstUpdate = OnFirstUpdate
function OnFirstUpdate()
    M27OnFirstUpdate()
    if M27Config.M27RunVeryFast == true then
        --ConExecute("WLD_GameSpeed 10")
        ConExecute("WLD_GameSpeed 20") --More recent versions allow for this
    end
end

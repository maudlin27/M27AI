--[[
    File    :   /lua/AI/AIBaseTemplates/M27AI.lua
    Author  :   SoftNoob
    Summary :
        Lists AIs to be included into the lobby, see /lua/AI/CustomAIs_v2/SorianAI.lua for another example.
        Loaded in by /lua/ui/lobby/aitypes.lua, this loads all lua files in /lua/AI/CustomAIs_v2/
]]

BaseBuilderTemplate {
    BaseTemplateName = 'M27AI',
    Builders = {
        -- List all our builder groups here
        'M27ACUBuildOrder',
        'M27AIEngineerBuilder',
        'M27AILandBuilder',
        'M27AIAirBuilder',
        'M27AIPlatoonBuilder',

        --'M27AI T1 Reclaim',
    },
    NonCheatBuilders = {
        -- Specify builders that are _only_ used by non-cheating AI (e.g. scouting)
    },
    BaseSettings = { },
    ExpansionFunction = function(aiBrain, location, markerType)
        -- This is used if you want to make stuff outside of the starting location.
        return 0
    end,
    
    FirstBaseFunction = function(aiBrain)
        local per = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        if per == 'm27ai' or per == 'm27aicheat' then
            return 1000, 'M27AI'
        end
        return -1
    end,
}
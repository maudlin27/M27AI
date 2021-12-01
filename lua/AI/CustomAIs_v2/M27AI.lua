--[[
    File    :   /lua/AI/CustomAIs_v2/M27AI.lua
    Author  :   SoftNoob
    Summary :
        Lists AIs to be included into the lobby, see /lua/AI/CustomAIs_v2/SorianAI.lua for another example.
        Loaded in by /lua/ui/lobby/aitypes.lua, this loads all lua files in /lua/AI/CustomAIs_v2/
]]

AI = {
	Name = 'M27AI',
	Version = '1',
	AIList = {
		{
			key = 'm27ai',
			name = '<LOC M27AI_0001>AI: M27',
		},
	},
	CheatAIList = {
		{
			key = 'm27aicheat',
			name = '<LOC M27AI_0003>AIx: M27',
		},
	},
}

--Loaded in by /lua/ui/lobby/aitypes.lua, this loads all lua files in /lua/AI/CustomAIs_v2/

AI = {
	Name = 'M27AI',
	Version = '1',
	AIList = {
		{
			key = 'm27ai',
			name = '<LOC M27AI_0001>AI: M27',
            rating = 775,
            ratingCheatMultiplier = 0.0,
            ratingBuildMultiplier = 0.0,
            ratingOmniBonus = 0,
            ratingMapMultiplier = {
                [256] = 0.90323,   -- 5x5
                [512] = 1,   -- 10x10
                [1024] = 1,  -- 20x20
                [2048] = 1, -- 40x40
                [4096] = 0.9,  -- 80x80
            }
		},
	},
	CheatAIList = {
		{
			key = 'm27aicheat',
			name = '<LOC M27AI_0003>AIx: M27',
            rating = 775,
            ratingCheatMultiplier = 1300.0, --This is multiplied to the value, so 1.0 will give this amount
            ratingBuildMultiplier = 1000.0,
            ratingNegativeThreshold = 200,
            ratingOmniBonus = 50,
            ratingMapMultiplier = {
                [256] = 0.90323,   -- 5x5
                [512] = 1,   -- 10x10
                [1024] = 1,  -- 20x20
                [2048] = 1, -- 40x40
                [4096] = 0.9,  -- 80x80
            }
		},
	},
}
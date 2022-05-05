---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by maudlin27.
--- DateTime: 26/10/2021 07:21
---
--Manually turn below off prior to release
M27ShowUnitNames = true --(Overseer will set this to true if game settings are to show platoon names for all as well)
M27ShowEnemyUnitNames = true --Will rename enemy units to reflect their ID and lifetime count
M27RunVeryFast = true --Game starts off at +10 speed if set to adjustable
M27StrategicLog = true --Affects the strategic overseer logs which give various stats re the AI's state during the game
M27ShowPathingGraphically = true --(also turns on log showing map name) - Will draw the pathing for land, amphibious and navy if set to true, but will make things very slow
M27RunProfiling = false --Records data on how long most functions are taking
M27ProfilingIgnoreFirst2Seconds = true --Means logic relating to pathing generation gets ignored
--M27ProfilingIgnoreFirstMin = true --Means logic relating to pathing generation gets ignored
M27RunSoftlesProfiling = false --Runs Softles profiling which tracks every function call (not just in my code but in the game) which allows calculation of the average tick length that a function occurs in (i.e. doesnt track time spent by each function but instead can use the correlation between function calls and how long a tick is taking)
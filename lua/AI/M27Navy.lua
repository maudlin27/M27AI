---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by maudlin27.
--- DateTime: 17/08/2022 19:03
---
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')

tPondDetails = {} --[a] = the naval pathing group; returns subtable of various information on ponds; Global information on ponds (requiring at least 200 space
subrefPondSize = 'PondSize'
subrefPondMinX = 'PondMinX'
subrefPondMinZ = 'PondMinZ'
subrefPondMaxX = 'PondMaxX'
subrefPondMaxZ = 'PondMaxZ'
subrefPondMidpoint = 'PondMidpoint'
subrefPondNearbyBrains = 'PondNearbyBrains'
subrefPondMexInfo = 'PondMexInfo'
subrefMexLocation = 'PondMexLocation'
subrefMexDistance = 'PondMexDistance'
subrefMexCanHitWithDF = 'PondMexDFDistance'
subrefMexCanHitWithIndirect = 'PondMexIndirectDistance'

function RecordPonds()
    --Call after recording all pathfinding for the map; intended to record key information on any ponds of interest
    local tiPondTempInfo = {}
    local tbUnderwaterGroup = {}

    if M27MapInfo.bMapHasWater then
        --Record the size and dimensions of every pond
        for iX, tSubtable in M27MapInfo.tPathingSegmentGroupBySegment[M27UnitInfo.refPathingTypeNavy] do
            for iZ, iPathingGroup in tSubtable do
                if not(tPondDetails[iPathingGroup]) then
                    tPondDetails[iPathingGroup] = {}
                    --Are we actually underwater?
                    tbUnderwaterGroup[iPathingGroup] = M27MapInfo.IsUnderwater(M27MapInfo.GetPositionFromPathingSegments(iX, iZ))
                    if tbUnderwaterGroup[iPathingGroup] then
                        tPondDetails[iPathingGroup][subrefPondMinX] = 100000
                        tPondDetails[iPathingGroup][subrefPondMinZ] = 100000
                        tPondDetails[iPathingGroup][subrefPondMaxX] = 0
                        tPondDetails[iPathingGroup][subrefPondMaxZ] = 0
                        tPondDetails[iPathingGroup][subrefPondSize] = 0
                        tPondDetails[iPathingGroup][subrefPondNearbyBrains] = {}
                        tPondDetails[iPathingGroup][subrefPondMidpoint] = {}
                    end
                end

                if tbUnderwaterGroup[iPathingGroup] then
                    tPondDetails[iPathingGroup][subrefPondSize] = tPondDetails[iPathingGroup][subrefPondSize] + 1
                    tPondDetails[iPathingGroup][subrefPondMinX] = math.min(tPondDetails[iPathingGroup][subrefPondMinX], iX)
                    tPondDetails[iPathingGroup][subrefPondMinZ] = math.min(tPondDetails[iPathingGroup][subrefPondMinZ], iZ)
                    tPondDetails[iPathingGroup][subrefPondMaxX] = math.max(tPondDetails[iPathingGroup][subrefPondMaxX], iX)
                    tPondDetails[iPathingGroup][subrefPondMaxZ] = math.max(tPondDetails[iPathingGroup][subrefPondMaxZ], iZ)
                end
            end
        end
        if M27Utilities.IsTableEmpty(tPondDetails) == false then
            local iMaxBrainDist = 175
            local iMaxMexDist = 200 --range of aeon missile ship
            local iPondMexCount
            local iCurMexDist
            local tiDistToTry = {24, 40, 56, 88, 120, 145, iMaxMexDist}
            local bInRange
            local iAngleInterval = 45
            local tNearbyWater
            local tPossibleWaterPosition
            for iPathingGroup, tPondSubtable in tPondDetails do
                if tPondSubtable[subrefPondSize] >= 200 then
                    --Pond is large enough for us to consider tracking; record information of interest for the pond:
                    iPondMexCount = 0
                    tPondSubtable[subrefPondMidpoint] = {(tPondDetails[iPathingGroup][subrefPondMinX] + tPondDetails[iPathingGroup][subrefPondMaxX]) * 0.5, M27MapInfo.iMapWaterHeight, (tPondDetails[iPathingGroup][subrefPondMinZ] + tPondDetails[iPathingGroup][subrefPondMaxZ]) * 0.5}

                    --Details of brains that are near to the pond
                    for iBrain, oBrain in ArmyBrains do
                        if not(M27Logic.IsCivilianBrain(oBrain)) then
                            --Are we within 175 of the square covering the pond?
                            if M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber][1] >= tPondSubtable[subrefPondMinX] - iMaxBrainDist and M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber][1] <= tPondSubtable[subrefPondMaxX] + iMaxBrainDist and M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber][3] >= tPondSubtable[subrefPondMinZ] - iMaxBrainDist and M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber][3] <= tPondSubtable[subrefPondMaxZ] + iMaxBrainDist then
                                table.insert(tPondSubtable[subrefPondSize][subrefPondNearbyBrains], oBrain)
                            end
                        end
                    end


                    --Details of all mexes near enough to the pond to be of interest
                    for iMex, tMex in M27MapInfo.MassPoints do
                        bInRange = false

                        if tMex[1] >= tPondSubtable[subrefPondMinX] - iMaxMexDist and tMex[1] <= tPondSubtable[subrefPondMaxX] + iMaxMexDist and tMex[3] >= tPondSubtable[subrefPondMinZ] - iMaxMexDist and tMex[3] <= tPondSubtable[subrefPondMaxZ] + iMaxMexDist then
                            --See how far away the water is
                            for iEntry, iDist in tiDistToTry do
                                for iAngleAdjust = iAngleInterval, 360, iAngleInterval do
                                    tPossibleWaterPosition = M27Utilities.MoveInDirection(tMex, iAngleAdjust, iDist, true)
                                    if M27MapInfo.IsUnderwater(tPossibleWaterPosition, false, 0.05) then
                                        M27Utilities.ErrorHandler('TO COMPELTE')
                                        --TODO - Finish off code
                                    end
                                end
                                if bInRange then break end
                            end
                            if bInRange then

                                iPondMexCount = iPondMexCount + 1
                                tPondSubtable[subrefMexLocation] = {tMex[1], tMex[2], tMex[3]}
                            end
                            --TODO - Finish off code - below were variables of interest
                            --subrefMexDistance
                            --subrefMexCanHitWithDF
                            --subrefMexCanHitWithIndirect
                        end
                    end
                end
            end
        end
    end
end
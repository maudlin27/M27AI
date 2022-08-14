local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Config = import('/mods/M27AI/lua/M27Config.lua')
TestProfilerIsActive = false
GamePerformanceTrackerIsActive = false

---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by maudlin27.
--- DateTime: 03/12/2021 14:53
---

--Below code from Balthazaar - to be included in blueprints.lua hook - to help identify redundant categories
--[[function GetCategoryStats(all_bbps)
--    local allCategories = {}
--    for id, bp in all_bbps do
--        if bp.Categories then
--            --table.insert(bp.Categories, 'GRIDBASEDMOTION')
--            for i, cat in bp.Categories do
--                allCategories[cat] = (allCategories[cat] or 0) + 1
--            end
--        end
--    end
--    _ALERT(repru(allCategories))
--end--]]

function ListAmphibiousUnitsMissingAmphibiousCategory()
    local sFunctionRef = 'ListCategoriesUsedByCount'
    local tsAmphibiousPathingMissingCategory = {}
    local tsIncorrectlyHasAmphibious = {}
    local iMissingCategoryCount = 0
    local iIncorrectCategoryCount = 0

    for iBP, oBP in __blueprints do
        if oBP.Physics.MotionType == 'RULEUMT_AmphibiousFloating' or oBP.Physics.MotionType == 'RULEUMT_Amphibious' or oBP.Physics.AltMotionType == 'RULEUMT_AmphibiousFloating' or oBP.Physics.AltMotionType == 'RULEUMT_Amphibious' then
            if not(EntityCategoryContains(categories.AMPHIBIOUS, oBP.BlueprintId)) then
                iMissingCategoryCount = iMissingCategoryCount + 1
                tsAmphibiousPathingMissingCategory[iMissingCategoryCount] = {oBP.BlueprintId, oBP.Description, LOCF(oBP.General.UnitName)}
            end
        elseif EntityCategoryContains(categories.AMPHIBIOUS, oBP.BlueprintId) then
            iIncorrectCategoryCount = iIncorrectCategoryCount + 1
            tsIncorrectlyHasAmphibious[iIncorrectCategoryCount] = {oBP.BlueprintId, oBP.Description, LOCF(oBP.General.UnitName)}
        end
    end
    LOG(sFunctionRef..': Categories missing AMPHIBIOUS category but having amphibious pathing='..repru(tsAmphibiousPathingMissingCategory))
    LOG(sFunctionRef..': Categories that incorrectly have AMPHIBIOUS category='..repru(tsIncorrectlyHasAmphibious))
end

--Alterantive - originally used with __blueprints - it gave numbers that looked to be double what they should be; therefore tried using Balthazaar's approach above, gave same result, so must just be blueprints file that list things multiple times
function ListCategoriesUsedByCount(tAllBlueprints)
    local sFunctionRef = 'ListCategoriesUsedByCount'
    local tCategoryUsage = {}

    LOG(sFunctionRef..': About to list category usage')
    if tAllBlueprints == nil then tAllBlueprints = __blueprints end

    local tIDOnlyOnce = {}
    local sCurID
    for iBP, oBP in tAllBlueprints do
        if oBP.Categories then
            sCurID = oBP.BlueprintId
            if tIDOnlyOnce[sCurID] == nil then
                tIDOnlyOnce[sCurID] = true
                local tOnlyListOnce = {}
                for iCat, sCat in oBP.Categories do
                    if tOnlyListOnce[sCat] == nil then
                        tCategoryUsage[sCat] = (tCategoryUsage[sCat] or 0) + 1
                        tOnlyListOnce[sCat] = true
                    end
                end
            end
        end
    end
    for iCategory, iCount in M27Utilities.SortTableByValue(tCategoryUsage, false) do
        LOG(iCategory..': '..iCount)
    end

    --List units with lowest count
    local iLowCountThreshold = 2
    local tUnitsWithLowUsageCategories = {}
    local sCurRef
    tIDOnlyOnce = {}
    for iBP, oBP in tAllBlueprints do
        if oBP.Categories then
            sCurID = oBP.BlueprintId
            if tIDOnlyOnce[sCurID] == nil then
                tIDOnlyOnce[sCurID] = true
                sCurRef = sCurID..': '..(LOCF(oBP.General.UnitName) or 'nil name')
                local tOnlyListOnce = {}

                for iCat, sCat in oBP.Categories do
                    if tCategoryUsage[sCat] <= iLowCountThreshold then
                        if tOnlyListOnce[sCat] == nil then
                            tOnlyListOnce[sCat] = true
                            if tUnitsWithLowUsageCategories[sCurRef] then table.insert(tUnitsWithLowUsageCategories[sCurRef], 1, sCat) else tUnitsWithLowUsageCategories[sCurRef] = {sCat} end
                        end
                    end
                end
            end
        end
    end
    LOG(repru(tUnitsWithLowUsageCategories))
end



function OptimisationComparisonDistanceToStart(aiBrain)
    local oACU = M27Utilities.GetACU(aiBrain)
    local iCycleCount = 1000000
    local iTimeStart

    --First compare for 1 unit (best case for alt approach)
    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('Normal get distance approach start', iTimeStart)
    for i1 = 1, iCycleCount do
        M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
    end
    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('Normal get distance approach end', iTimeStart)
    for i1 = 1, iCycleCount do
        M27UnitInfo.GetUnitDistanceFromOurStart(aiBrain, oACU)
    end
    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('UnitInfo get distance approach end', iTimeStart)
    --Not using custom function for distance
    local tStartPosition
    local tUnitPosition
    for i1 = 1, iCycleCount do
        tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        tUnitPosition = oACU:GetPosition()
        VDist2(tUnitPosition[1], tUnitPosition[3], tStartPosition[1], tStartPosition[3])
    end
    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('VDist End', iTimeStart)
    --Ultimate efficient approach
    for i1 = 1, iCycleCount do
        tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        tUnitPosition = oACU:GetPosition()
        VDist2Sq(tUnitPosition[1], tUnitPosition[3], tStartPosition[1], tStartPosition[3])
    end
    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('VDistSq End', iTimeStart)

    --Time taken if store the positions initially
    tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    tUnitPosition = oACU:GetPosition()
    for i1 = 1, iCycleCount do
        VDist2(tUnitPosition[1], tUnitPosition[3], tStartPosition[1], tStartPosition[3])
    end
    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('VDist predefined locations End', iTimeStart)
    for i1 = 1, iCycleCount do
        VDist2Sq(tUnitPosition[1], tUnitPosition[3], tStartPosition[1], tStartPosition[3])
    end
    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('VDistSq predefined locations End', iTimeStart)
    --Now compare for every unit we have
    local tAllUnits = aiBrain:GetListOfUnits(categories.ALLUNITS, false, true)
    iCycleCount = 10
    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('Normal get distance approach All units start', iTimeStart)
    for i1 = 1, iCycleCount do
        for iUnit, oUnit in tAllUnits do
            M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        end
    end
    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('Normal get distance approach All units end', iTimeStart)
    for i1 = 1, iCycleCount do
        for iUnit, oUnit in tAllUnits do
            M27UnitInfo.GetUnitDistanceFromOurStart(aiBrain, oUnit)
        end
    end
    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('Alt get distance approach All units end', iTimeStart)
end


function GetReclaimInRectVsCheckingTable()
    --Summary conclusion - checking reclaim segments in a 3x3 grid takes about 10-15% of the time of getting reclaim in the area if there's some low level reclaim that we're ignoring like trees; so if just interested in amount of reclaim then it's more efficient.  If using as a check for whether should do GetReclaimablesInRect then its only more efficient if c.50% or less of the time on the map a 3x3 reclaim segment would return no reclaim

    local iCycleCount = 250000
    local tReclaim
    local iSegmentX, iSegmentZ
    local rRect
    local iRadius = 6
    local iTimeStart
    local iAssumedPercentageOfSegmentsWithReclaim = 0.1
    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
    local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]

    local tLocation = {math.random(30, iMapSizeX - 30), 0, math.random(30, iMapSizeZ - 30)}
    tLocation[2] = GetSurfaceHeight(tLocation[1], tLocation[3])

    M27MapInfo.UpdateReclaimMarkers()

    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('GetReclaimInRectVsCheckingTable GetReclaimInRectangle each time start', iTimeStart)

    for i1 = 1, iCycleCount do
        tReclaim = M27MapInfo.GetReclaimInRectangle(4, Rect(tLocation[1] - iRadius, tLocation[3] - iRadius, tLocation[1] + iRadius, tLocation[3] + iRadius))
    end
    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('GetReclaimInRectangle each time end; Check of table start', iTimeStart)
    for i1 = 1, iCycleCount do
        iSegmentX, iSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tLocation)
        for iAdjX = -1, 1 do
            for iAdjZ = -1, 1 do
                if M27MapInfo.tReclaimAreas[iSegmentX + iAdjX][iSegmentZ + iAdjZ][M27MapInfo.refReclaimTotalMass] > 0 then
                end
            end
        end
    end
    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('Table check end before getting reclaim for '..iAssumedPercentageOfSegmentsWithReclaim..' of the times', iTimeStart)
    for i1 = 1, math.floor(iCycleCount * iAssumedPercentageOfSegmentsWithReclaim) do
        tReclaim = M27MapInfo.GetReclaimInRectangle(4, Rect(tLocation[1] - iRadius, tLocation[3] - iRadius, tLocation[1] + iRadius, tLocation[3] + iRadius))
    end
    iTimeStart = M27Utilities.ProfilerTimeSinceLastCall('Table check end after getting reclaim', iTimeStart)

    --What percentage of map has reclaim?

    local iReclaimMaxSegmentX = math.ceil(iMapSizeX / M27MapInfo.iReclaimSegmentSizeX)
    local iReclaimMaxSegmentZ = math.ceil(iMapSizeZ / M27MapInfo.iReclaimSegmentSizeZ)
    local iMinReclaim = 2.5
    local iSegmentsWithEnoughReclaim = 0
    local iSegmentsWithoutEnoughReclaim = 0
    for iSegmentX = 1, iReclaimMaxSegmentX do
        for iSegmentZ = 1, iReclaimMaxSegmentZ do
            if M27MapInfo.tReclaimAreas[iSegmentX][iSegmentZ][M27MapInfo.refReclaimTotalMass] >= iMinReclaim then
                iSegmentsWithEnoughReclaim = iSegmentsWithEnoughReclaim + 1
            else iSegmentsWithoutEnoughReclaim = iSegmentsWithoutEnoughReclaim + 1
            end
        end
    end
    LOG('% of map with reclaim='..iSegmentsWithEnoughReclaim / (iSegmentsWithEnoughReclaim + iSegmentsWithoutEnoughReclaim)..'; iSegmentsWithEnoughReclaim='..iSegmentsWithEnoughReclaim)
end

function LocalVariableInLoopBase()
    local iMaxCycleCount = 10000000
    for iCurCycleCount = 1, iMaxCycleCount do
        local iNewVariable = math.random(1, 100)
    end
end
function LocalVariableOutOfLoopBase()
    local iMaxCycleCount = 10000000
    local iNewVariable
    for iCurCycleCount = 1, iMaxCycleCount do
        iNewVariable = math.random(1, 100)
    end
end

function LocalVariableImpact()
    --Every second calls localvaraiblebase, and sends a log with the time from the last cycle

    --2m in, using LocalVariableInLoopBase at 100k cycle count: info: LocalVariableImpactGameTime=120; Last cycle time=0.010101318359375; Cumulative time=12.085174560547
    --Using option 2 LocalVariableOutOfLoopBase:                info: LocalVariableImpactGameTime=120; Last cycle time=0.01031494140625; Cumulative time=11.934707641602
    --Using option3 InFunctionNoVariable:                       info: LocalVariableImpactGameTime=120; Last cycle time=0.010402679443359; Cumulative time=11.880109786987

    --Results with a 10m cyclecount instead of 100k (to try and reduce impact of other things like pathing):
    --Option1: info: LocalVariableImpactGameTime=120; Last cycle time=0.42639923095703; Cumulative time=53.04044342041
    --Option2: info: LocalVariableImpactGameTime=120; Last cycle time=0.43112945556641; Cumulative time=55.540271759033
    --Option3: info: LocalVariableImpactGameTime=120; Last cycle time=0.47577667236328; Cumulative time=59.778469085693



    local sFunctionRef = 'LocalVariableImpact'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iCumulativeTime = 0
    local iCurCycleTime
    local iNewVariable
    if not(TestProfilerIsActive) then
        TestProfilerIsActive = true
        local iTimeCycleStart
        while (1 == 1) do
            iTimeCycleStart = GetSystemTimeSecondsOnlyForProfileUse()
            --ForkThread(LocalVariableInLoopBase) --(Option 1)
            ForkThread(LocalVariableOutOfLoopBase) --(Option 2)
            --Option3: InFunctionNoVariable
            --[[for iCurCycleCount = 1, 10000000 do
                iNewVariable = math.random(1, 100)
            end--]]
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitSeconds(1)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

            iCurCycleTime = GetSystemTimeSecondsOnlyForProfileUse() - iTimeCycleStart
            iCumulativeTime = iCumulativeTime + iCurCycleTime
            LOG(sFunctionRef..'GameTime='..math.floor(GetGameTimeSeconds())..'; Last cycle time='..iCurCycleTime..'; Cumulative time='..iCumulativeTime)
        end

    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end



function LogGamePerformanceData()
    --Call via forkthread at start of game (duplicate of performance check condition to be extra sure we only run this when intended)
    if M27Config.M27RunGamePerformanceCheck and not(GamePerformanceTrackerIsActive) then
        GamePerformanceTrackerIsActive = true
        local iTimeAtMainTickStart = 0
        local iIntervalInTicks = 100 --Every 10s
        local iCurUnitCount = 0

        local iCurTickCycle = iIntervalInTicks

        local iFreeze1Count = 0
        local iFreeze1Threshold = 0.1
        local iTimeAtSingleTickStart = 0



        while ArmyBrains do
            iTimeAtSingleTickStart = GetSystemTimeSecondsOnlyForProfileUse()
            WaitTicks(1)
            iCurTickCycle = iCurTickCycle - 1
            if GetSystemTimeSecondsOnlyForProfileUse() - iTimeAtSingleTickStart > iFreeze1Threshold then
                iFreeze1Count = iFreeze1Count + 1
            end

            if iCurTickCycle <= 0 then
                iCurUnitCount = 0
                for iBrain, oBrain in ArmyBrains do
                    iCurUnitCount = iCurUnitCount + oBrain:GetCurrentUnits(categories.ALLUNITS - categories.BENIGN)
                end
                LOG('LogGamePerformanceData: GameTime='..math.floor(GetGameTimeSeconds())..' Time taken='..GetSystemTimeSecondsOnlyForProfileUse() - iTimeAtMainTickStart..'; Unit Count='..iCurUnitCount..'; iFreeze1Count='..iFreeze1Count)
                iCurTickCycle = iIntervalInTicks
                iTimeAtMainTickStart = GetSystemTimeSecondsOnlyForProfileUse()
                iFreeze1Count = 0
            end
        end
    end
end
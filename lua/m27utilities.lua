
local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')

refProfilerStart = 0
refProfilerEnd = 1

--Debug variables
bGlobalDebugOverride = false

--Profiler variables

refProfilerStart = 0
refProfilerEnd = 1

tProfilerTimeTakenInTickByFunction = {}
tProfilerTimeTakenCumulative = {}
tProfilerStartCount = {}
tProfilerEndCount = {}
tProfilerFunctionStart = {}
tProfilerTimeTakenByCount = {}
tProfilerCumulativeTimeTakenInTick = {}
tProfilerActualTimeTakenInTick = {}
sProfilerActiveFunctionForThisTick = 'nil'
refiLongestTickAfterStartRef = 0
refiLongestTickAfterStartTime = 0
bFullOutputAlreadyDone = {} -- true if have done the full output for the nth time; n being based on how long an interval we want
iFullOutputIntervalInTicks = 10 --every second (will do a full output of every log every 10s, this will just do every 30 functions)
iFullOutputCount = 0 --increased each time do a full output
iFullOutputCycleCount = 0 --Increased each time do a full output, and reset to 0 when reach
tProfilerCountByTickByFunction = {}
tbProfilerOutputGivenForTick = {} --true if already given output for [iTick]
IssueCount = 0 --Used to track no. of times issuemove has been sent in game

tiProfilerStartCountByFunction = {} --[functionref] - Used if want to temporarily check how many times a function is called - have this update in the function itself, along with the end count
--example of usage of the above: --M27Utilities.tiProfilerStartCountByFunction[sFunctionRef] = (M27Utilities.tiProfilerStartCountByFunction[sFunctionRef] or 0) + 1 LOG(sFunctionRef..': M27Utilities.tiProfilerStartCountByFunction[sFunctionRef]='..M27Utilities.tiProfilerStartCountByFunction[sFunctionRef])
tiProfilerEndCountByFunction = {} --[functionref] - Used if want to temporarily check how many times a function is called - have this update in the function itself, along with the end count
--Example of usage of the above: M27Utilities.tiProfilerEndCountByFunction[sFunctionRef] = (M27Utilities.tiProfilerEndCountByFunction[sFunctionRef] or 0) + 1 LOG(sFunctionRef..': M27Utilities.tiProfilerEndCountByFunction[sFunctionRef]='..M27Utilities.tiProfilerEndCountByFunction[sFunctionRef])


function ErrorHandler(sErrorMessage, iOptionalWaitInSeconds, bWarningNotError)
    --Intended to be put in code wherever a condition isn't met that should be, so can debug it without the code crashing
    --Search for "error " in the log to find both these errors and normal lua errors, while not bringing up warnings
    if sErrorMessage == nil then sErrorMessage = 'Not specified' end
    local sErrorBase = 'M27ERROR '
    if bWarningNotError then sErrorBase = 'M27WARNING: ' end
    sErrorBase = sErrorBase..'GameTime '..math.floor(GetGameTimeSeconds())..': '
    sErrorMessage = sErrorBase..sErrorMessage
    local a, s = pcall(assert, false, sErrorMessage)
    WARN(a, s)
    if iOptionalWaitInSeconds then WaitSeconds(iOptionalWaitInSeconds) end
end

function IsTableEmpty(tTable, bEmptyIfNonTableWithValue)
    --bEmptyIfNonTableWithValue - Optional, defaults to true
    --E.g. if passed oUnit to a function that was expecting a table, then setting bEmptyIfNonTableWithValue = false means it will register the table isn't nil

    if (type(tTable) == "table") then
        if next (tTable) == nil then return true
        else
            for i1, v1 in pairs(tTable) do
                if IsTableEmpty(v1, false) == false then return false end
            end
            return true
        end
    else
        if tTable == nil then return true
        else
            if bEmptyIfNonTableWithValue == nil then return true
                else return bEmptyIfNonTableWithValue
            end
        end

    end
end

function IsTableArray(tTable)
    if tTable[1] == nil then
        --LOG('tTable[1] is a nil value')
        return false end
    return true
end

function GetTableSize(tTable)
    local count = 0
    for _ in pairs(tTable) do count = count + 1 end
    return count
end

function CombineTables(t1, t2)
    for _,v in ipairs(t2) do
        table.insert(t1, v)
    end
    return t1
end

function ConvertTableIntoUniqueList(t1DTable)
    --Assumes that table doesn't contain nil values in it
    --First check if is a table:
    local tUniqueTable = {}
    local iTableCount = table.getn(t1DTable)
    local iUniqueRefCount = 0
    for iCurEntry=1, iTableCount do
        if iCurEntry == 1 then
            iUniqueRefCount = iUniqueRefCount + 1
            tUniqueTable[iUniqueRefCount] = t1DTable[iCurEntry]
        else
            for iUniqueEntry = 1, iUniqueRefCount do
                if t1DTable[iCurEntry] == tUniqueTable[iUniqueEntry] then break end
                if iUniqueEntry == iUniqueRefCount then
                    --Not matched against any unique ref entries, so record this:
                    iUniqueRefCount = iUniqueRefCount + 1
                    tUniqueTable[iUniqueRefCount] = t1DTable[iCurEntry]
                    break
                end

            end
        end
    end
    return tUniqueTable
end

function spairs(t, order)
    --Required by the sort tables function
    --Code with thanks to Michal Kottman https://stackoverflow.com/questions/15706270/sort-a-table-in-lua
    -- collect the keys
    local keys = {}
    local iKeyCount = 0
    for k in pairs(t) do
        iKeyCount = iKeyCount+1
        keys[iKeyCount] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function SortTableBySubtable(tTableToSort, sSortByRef, bLowToHigh)
--NOTE: This doesnt update tTableToSort.  Instead it returns a 1-off table reference that you can use e.g. to loop through each entry.  Its returning function(table), which means if you try and store it as a table variable, then further references to it will re-run the function causing issues
    --[[ e.g. of a table where this will work:
    local tPreSortedThreatGroup = {}
    local sThreatGroup
    for i1 = 1, 4 do
        sThreatGroup = 'M27'..i1
        tPreSortedThreatGroup[sThreatGroup] = {}
        if i1 == 1 then
            tPreSortedThreatGroup[sThreatGroup][refiDistanceFromOurBase] = 100
        elseif i1 == 4 then tPreSortedThreatGroup[sThreatGroup][refiDistanceFromOurBase] = 200
        else tPreSortedThreatGroup[sThreatGroup][refiDistanceFromOurBase] = math.random(1, 99)
        end
    end
    for iEntry, tValue in SortTableBySubtable(tPreSortedThreatGroup, refiDistanceFromOurBase, true) then will iterate through the values from low to high
    ]]--

    if bLowToHigh == nil then bLowToHigh = true end
    if bLowToHigh == true then
        return spairs(tTableToSort, function(t,a,b) return t[b][sSortByRef] > t[a][sSortByRef] end)
    else return spairs(tTableToSort, function(t,a,b) return t[b][sSortByRef] < t[a][sSortByRef] end)
    end
end

function SortTableByValue(tTableToSort, bHighToLow)
    --e.g. for iCategory, iCount in M27Utilities.SortTableByValue(tCategoryUsage, true) do
    if bHighToLow then return spairs(tTableToSort, function(t,a,b) return t[b] < t[a] end)
    else return spairs(tTableToSort, function(t,a,b) return t[b] > t[a] end)
    end
end

function GetRectAroundLocation(tLocation, iRadius)
    --Looks iRadius left/right and up/down (e.g. if want 1x1 square centred on tLocation, iRadius should be 0.5)
    return Rect(tLocation[1] - iRadius, tLocation[3] - iRadius, tLocation[1] + iRadius, tLocation[3] + iRadius)
end

function DrawCircleAroundPoint(tLocation, iColour, iDisplayCount, iCircleSize)
    --Use DrawCircle which will call a forkthread to call this
    local sFunctionRef = 'DrawCircleAroundPoint'
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end

    if iCircleSize == nil then iCircleSize = 2 end
    if iDisplayCount == nil then iDisplayCount = 500
    elseif iDisplayCount <= 0 then iDisplayCount = 1
    elseif iDisplayCount >= 10000 then iDisplayCount = 10000
    end

    local sColour
    if iColour == nil then sColour = 'c00000FF' --dark blue
    elseif iColour == 1 then sColour = 'c00000FF' --dark blue
    elseif iColour == 2 then sColour = 'ffFF4040' --Red
    elseif iColour == 3 then sColour = 'c0000000' --Black (can be hard to see on some maps)
    elseif iColour == 4 then sColour = 'fff4a460' --Gold
    elseif iColour == 5 then sColour = 'ff27408b' --Light Blue
    elseif iColour == 6 then sColour = 'ff1e90ff' --Cyan (might actually be white as well?)
    elseif iColour == 7 then sColour = 'ffffffff' --white
    else sColour = 'ffFF6060' --Orangy pink
    end

    local iMaxDrawCount = iDisplayCount
    local iCurDrawCount = 0
    if bDebugMessages == true then LOG('About to draw circle at table location ='..repr(tLocation)) end
    while true do
        bFirstLocation = true
        DrawCircle(tLocation, iCircleSize, sColour)
        iCurDrawCount = iCurDrawCount + 1
        if iCurDrawCount > iMaxDrawCount then return end
        if bDebugMessages == true then LOG(sFunctionRef..': Will wait 2 ticks then refresh the drawing') end
        coroutine.yield(2) --Any more and circles will flash instead of being constant
    end
end


function OldDrawTableOfLocations(tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation, iCircleSize)
    --Draw circles around a table of locations to help with debugging - note that as this doesnt use ForkThread (might need to have global variables and no function pulled variables for forkthread to work beyond the first few seconds) this will pause all the AI code
    --If a table (i.e. bSingleLocation is false), then will draw lines between each position
    --All values are optional other than tableLocations
    --if relativeStart is blank then will treat as absolute co-ordinates
    --assumes tableLocations[x][y] where y is table of 3 values
    -- iColour: integer to allow easy selection of different colours (see below code)
    -- iDisplayCount - No. of times to cycle through drawing; limit of 500 (10s) for performance reasons
    --bSingleLocation - true if tableLocations is just 1 position
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    if iCircleSize == nil then iCircleSize = 2 end
    if iDisplayCount == nil then iDisplayCount = 500
    elseif iDisplayCount <= 0 then iDisplayCount = 1
    elseif iDisplayCount >= 10000 then iDisplayCount = 10000
    end
    if bSingleLocation == nil then bSingleLocation = false end
    local sColour
    if iColour == nil then sColour = 'c00000FF' --dark blue
    elseif iColour == 1 then sColour = 'c00000FF' --dark blue
    elseif iColour == 2 then sColour = 'ffFF4040' --Red
    elseif iColour == 3 then sColour = 'c0000000' --Black (can be hard to see on some maps)
    elseif iColour == 4 then sColour = 'fff4a460' --Gold
    elseif iColour == 5 then sColour = 'ff27408b' --Light Blue
    elseif iColour == 6 then sColour = 'ff1e90ff' --Cyan (might actually be white as well?)
    elseif iColour == 7 then sColour = 'ffffffff' --white
    else sColour = 'ffFF6060' --Orangy pink
    end


    if relativeStart == nil then relativeStart = {0,0,0} end
    local iMaxDrawCount = iDisplayCount
    local iCurDrawCount = 0
    if bDebugMessages == true then LOG('About to draw circle at table locations ='..repr(tableLocations)) end
    local bFirstLocation = true
    local tPrevLocation = {}
    local iCount = 0
    while true do
        bFirstLocation = true
        iCount = iCount + 1 if iCount > 10000 then ErrorHandler('Infinite loop') break end
        if bSingleLocation then DrawCircle(tableLocations, iCircleSize, sColour)
        else
            for i, tCurLocation in ipairs(tableLocations) do
                DrawCircle(tCurLocation, iCircleSize, sColour)
                if bFirstLocation == true then
                    bFirstLocation = false
                else
                    DrawLine(tPrevLocation, tCurLocation, sColour)
                end
                tPrevLocation = tCurLocation
            end
        end
        iCurDrawCount = iCurDrawCount + 1
        if iCurDrawCount > iMaxDrawCount then return end
        coroutine.yield(2) --Any more and circles will flash instead of being constant
    end
end

function DrawTableOfLocations(tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation, iCircleSize)
    if bSingleLocation then tableLocations = {tableLocations} end
    for iLocation, tLocation in tableLocations do
        DrawRectBase(Rect(tLocation[1] - 0.5, tLocation[3] - 0.5, tLocation[1] + 0.5, tLocation[3] + 0.5), iColour, iDisplayCount)
    end
end

function DrawRectBase(rRect, iColour, iDisplayCount)
    --Draws lines around rRect; rRect should be a rect table, with keys x0, x1, y0, y1
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DrawRectBase'
    if bDebugMessages == true then LOG(sFunctionRef..': rRect='..repr(rRect)) end
    local sColour
    if iColour == nil then sColour = 'c00000FF' --dark blue
    elseif iColour == 1 then sColour = 'c00000FF' --dark blue
    elseif iColour == 2 then sColour = 'ffFF4040' --Red
    elseif iColour == 3 then sColour = 'c0000000' --Black (can be hard to see on some maps)
    elseif iColour == 4 then sColour = 'fff4a460' --Gold
    elseif iColour == 5 then sColour = 'ff27408b' --Light Blue
    elseif iColour == 6 then sColour = 'ff1e90ff' --Cyan (might actually be white as well?)
    elseif iColour == 7 then sColour = 'ffffffff' --white
    else sColour = 'ffFF6060' --Orangy pink
    end


    if iDisplayCount == nil then iDisplayCount = 500
    elseif iDisplayCount <= 0 then iDisplayCount = 1
    elseif iDisplayCount >= 10000 then iDisplayCount = 10000 end
    local tPos1, tPos2
    local iValPos2ToUse
    local tCurPos, tLastPos
    local tAllX = {}
    local tAllZ = {}
    local iCurX, iCurZ
    local iRectKey = 0

    --[[for sRectKey, iRectVal in rRect do
        tAllX[iRectKey] = iRectVal
        else tAllZ[iRectKey - 2] = iRectVal end
    end--]]

    if bDebugMessages == true then LOG(sFunctionRef..'tAllX='..repr(tAllX)..'; tAllZ='..repr(tAllZ)..'; Rectx0='..rRect['x0']) end
    local iCurDrawCount = 0

    local iCount = 0
    while true do
        iCount = iCount + 1 if iCount > 10000 then ErrorHandler('Infinite loop') break end
        for iValX = 1, 2 do
            for iValZ = 1, 2 do
                if iValX == 1 then
                    iCurX = rRect['x0']
                    if iValZ == 1 then iCurZ = rRect['y0'] else iCurZ = rRect['y1'] end
                else
                    iCurX = rRect['x1']
                    if iValZ == 1 then iCurZ = rRect['y1'] else iCurZ = rRect['y0'] end
                end

                tLastPos = tCurPos
                tCurPos = {iCurX, GetTerrainHeight(iCurX, iCurZ), iCurZ}
                if tLastPos then
                    if bDebugMessages == true then LOG(sFunctionRef..': tLastPos='..repr(tLastPos)..'; tCurPos='..repr(tCurPos)) end
                    DrawLine(tLastPos, tCurPos, sColour)
                end
            end
        end
        iCurDrawCount = iCurDrawCount + 1
        if iCurDrawCount > iDisplayCount then return end
        coroutine.yield(2) --Any more and lines will flash instead of being constant
    end
end

function ConvertLocationToReference(tLocation)
    --Rounds tLocation down for X and Z, and uses these to provide a unique string reference (for use for table keys)
    return ('X'..math.floor(tLocation[1])..'Z'..math.floor(tLocation[3]))
end

function SteppingStoneForDrawLocations(tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation, iCircleSize)
    DrawTableOfLocations(tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation, iCircleSize)
end

function SteppingStoneForDrawRect(rRect, iColour, iDisplayCount)
    return DrawRectBase(rRect, iColour, iDisplayCount)
end

function SteppingStoneForDrawCircle(tLocation, iColour, iDisplayCount, iCircleSize)
    DrawCircleAroundPoint(tLocation, iColour, iDisplayCount, iCircleSize)
end

function DrawCircleAtTarget(tLocation, iColour, iDisplayCount, iCircleSize) --Dont call DrawCircle since this is a built in function
    ForkThread(SteppingStoneForDrawCircle, tLocation, iColour, iDisplayCount, iCircleSize)
end

function DrawLocations(tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation, iCircleSize)
    --fork thread doesnt seem to work - can't see the circle, even though teh code itself is called; using steppingstone seems to fix this
    --ForkThread(DrawTableOfLocations, tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation)
    --DrawTableOfLocations(tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation)
    --ErrorHandler('Shouldnt be drawing anything')
    ForkThread(SteppingStoneForDrawLocations, tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation, iCircleSize)
end

function DrawLocation(tLocation, relativeStart, iColour, iDisplayCount, iCircleSize)
    --ForkThread(DrawTableOfLocations, tableLocations, relativeStart, iColour, iDisplayCount, true)
    --DrawTableOfLocations(tableLocations, relativeStart, iColour, iDisplayCount, true)
    --ErrorHandler('Shouldnt be drawing anything')
    ForkThread(SteppingStoneForDrawLocations, tLocation, relativeStart, iColour, iDisplayCount, true, iCircleSize)
end

function DrawRectangle(rRect, iColour, iDisplayCount)
    --ErrorHandler('Shouldnt be drawing anything')
    ForkThread(SteppingStoneForDrawRect, rRect, iColour, iDisplayCount)
end


function GetAveragePosition(tUnits)
    --returns a table with the average position of tUnits
    local sFunctionRef = 'GetAveragePosition'
    local tTotalPos = {0,0,0}
    local iUnitCount = 0
    local tCurPos = {}
    for iUnit, oUnit in tUnits do
        tCurPos = oUnit:GetPosition()
        if not(tCurPos[1] == nil) then
            for iAxis = 1, 3 do
                tTotalPos[iAxis] = tTotalPos[iAxis] + tCurPos[iAxis]
            end
            iUnitCount = iUnitCount + 1
        end
    end
    return {tTotalPos[1]/iUnitCount, tTotalPos[2]/iUnitCount, tTotalPos[3]/iUnitCount}
end

function GetRoughDistanceBetweenPositions(tPosition1, tPosition2)
    --Intended to be slightly quicker version of the noraml getdistancebetweenspositions where CPU performance may be an issue and accuracy isnt an issue as much - it doesnt move in a straight line towards target so will return a further away distance than normal
    return math.abs(tPosition1[1] - tPosition2[1]) + math.abs(tPosition1[3] - tPosition2[3])
end

function GetDistanceBetweenPositions(Position1, Position2)
    return VDist2(Position1[1], Position1[3], Position2[1], Position2[3])
end

function GetDistanceBetweenBuildingPositions(Position1, Position2, iBuildingSize)
    -- Returns distance ignoring the y value and taking just x and z values
    --if iBuildingSize is set to a value, then will instead reduce the distance to determine the distance between 1 position and the nearest part of the other position with iBuildingSize
    --iBuildingSize should be the building size from its build location, in 'wall units' - so a land fac is an 8x8 size, and the build position will be the centre of it, making the building size 4, a T1 PGen a size of 1, etc.
    -- LOG('Position1='..Position1[1]..'-'..Position1[3]..'; Position2='..Position2[1]..'-'..Position2[3])
    if iBuildingSize == nil then
        return VDist2(Position1[1], Position1[3], Position2[1], Position2[3])
    else
        local ModPos1X = Position1[1]
        local ModPos1Z = Position1[3]
        if Position1[1] > Position2[1] then
            ModPos1X = Position1[1] - iBuildingSize
            if ModPos1X < Position2[1] then
                    ModPos1X = Position2[1]
            end
        elseif Position1[1] < Position2[1] then
            ModPos1X = Position1[1] + iBuildingSize
            if ModPos1X > Position2[1] then
                ModPos1X = Position2[1] end
        end
        if Position1[3] > Position2[3] then
            ModPos1Z = Position1[3] - iBuildingSize
            if ModPos1Z < Position2[3] then ModPos1Z = Position2[3] end
        elseif Position1[3] < Position2[3] then
            ModPos1Z = Position1[3] + iBuildingSize
            if ModPos1Z > Position2[3] then ModPos1Z = Position2[3] end
        end
        -- LOG('iBuildingSize was set so ModPos used; Position1='..Position1[1]..'-'..Position1[3]..'; Position2='..Position2[1]..'-'..Position2[3]..'iBuildingSize='..iBuildingSize..'iModPos1X='..ModPos1X..'iModPos1Z='..ModPos1Z)
        return VDist2(ModPos1X, ModPos1Z, Position2[1], Position2[3])

    end
end

function GetOwnedUnitsAroundPoint(aiBrain, iCategoryCondition, tTargetPos, iSearchRange, bCompletedConstructionOnly)
    --Only returns units that we own
    if bCompletedConstructionOnly == nil then bCompletedConstructionOnly = true end
    local tAllUnits = aiBrain:GetUnitsAroundPoint(iCategoryCondition, tTargetPos, iSearchRange, 'Ally')
    local tOwnedUnits
    local iOwnedCount = 0
    if IsTableEmpty(tAllUnits) == false then
        tOwnedUnits = {}
        for iUnit, oUnit in tAllUnits do
            if not(oUnit.Dead) and oUnit:GetAIBrain() == aiBrain then
                if bCompletedConstructionOnly == false or oUnit.GetFractionComplete and oUnit:GetFractionComplete() == 1 then
                    iOwnedCount = iOwnedCount + 1
                    tOwnedUnits[iOwnedCount] = oUnit
                end
            end
        end
        if iOwnedCount == 0 then tOwnedUnits = nil end
    end
    return tOwnedUnits
end


function MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
    --Returns the position that want to move iDistanceToTravel along the path from tStartPos to tTargetPos, ignoring height
    --iAngle: 0 = straight line; 90 and 270: right angle to the direction; 180 - opposite direction
    --For now as I'm too lazy to do the basic maths, iAngle must be 0, 90, 180 or 270

    --local rad = math.atan2(tLocation[1] - tBuilderLocation[1], tLocation[3] - tBuilderLocation[3])
    --local iBaseAngle = math.atan((tStartPos[1] - tTargetPos[1])/ (tStartPos[3] - tTargetPos[3]))
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MoveTowardsTarget'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    if iAngle == nil then iAngle = 0 end
    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
    local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]

    local iBaseAngle = math.atan((tStartPos[1] - tTargetPos[1])/ (tStartPos[3] - tTargetPos[3]))
    local iXChangeBase = math.sin(iBaseAngle) * iDistanceToTravel
    local iZChangeBase = math.cos(iBaseAngle) * iDistanceToTravel
    local iXMod = 1
    local iZMod = 1
    --[[if iDistanceToTravel < 0 then
        if iAngle < 180 then iAngle = iAngle + 180
        else iAngle = iAngle - 180 end
    end--]]

    if tTargetPos[1] <= tStartPos[1] and tTargetPos[3] <= tStartPos[3] then
        iXMod = -1
        iZMod = -1
    elseif tTargetPos[1] <= tStartPos[1] then --Z is >
        iXMod = 1
        iZMod = 1
    elseif tTargetPos[3] <= tStartPos[3] then
        iXMod = -1
        iZMod = -1
    else --TargetX > StartX, TargetZ > StartZ
        iXMod = 1
        iZMod = 1
    end

    if tTargetPos[3] < tStartPos[3] then iZMod = -1 end
    local iXChangeActual, iZChangeActual
    if iAngle == 0 or iAngle == 180 then
        iXChangeActual = iXChangeBase
        iZChangeActual = iZChangeBase
    else
        iXChangeActual = iZChangeBase
        iZChangeActual = iXChangeBase
    end
    iXChangeActual = iXChangeActual * iXMod
    iZChangeActual = iZChangeActual * iZMod
    if iAngle > 0 then
        if iAngle >= 180 then iXChangeActual = iXChangeActual * -1 end
        if iAngle <= 180 then iZChangeActual = iZChangeActual * -1 end
    end
    local iXPos, iZPos
    iXPos = tStartPos[1] + iXChangeActual
    iZPos = tStartPos[3] + iZChangeActual

    if iXPos < rPlayableArea[1] + 1 then iXPos = rPlayableArea[1] + 1
    elseif iXPos > (iMapSizeX - 1) then iXPos = (iMapSizeX - 1) end
    if iZPos < rPlayableArea[2] + 1 then iZPos = rPlayableArea[2] + 1
    elseif iZPos > (iMapSizeZ - 1) then iZPos = (iMapSizeZ - 1) end


    if bDebugMessages == true then
        LOG(sFunctionRef..': tTargetPos='..repr(tTargetPos)..'; tStartPos='..repr(tStartPos)..'; iAngle='..iAngle..'; iDistanceToTravel='..iDistanceToTravel..'; NewPos=XZ='..iXPos..','..iZPos)
        DrawLocations({{ iXPos, GetTerrainHeight(iXPos, iZPos), iZPos }, tStartPos, tTargetPos})
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, about to return value') end
    return { iXPos, GetTerrainHeight(iXPos, iZPos), iZPos }
end

function ConvertM27AngleToFAFAngle(iM27Angle)
    --Per FAF documentation on issueformmove:
    -- @param degrees The orientation the platoon should take when it reaches the position. South is 0 degrees, east is 90 degrees, etc.
    --Meanwhile M27: 0 is north, 90 is east, etc.
    local iFAFAngle = 180 - iM27Angle
    if iFAFAngle < 0 then iFAFAngle = iFAFAngle + 360 end
    return iFAFAngle
end

function GetAngleFromAToB(tLocA, tLocB)
    --Returns an angle 0 = north, 90 = east, etc. based on direction of tLocB from tLocA
    local iTheta = math.atan(math.abs(tLocA[3] - tLocB[3]) / math.abs(tLocA[1] - tLocB[1])) * 180 / math.pi
    if tLocB[1] > tLocA[1] then
        if tLocB[3] > tLocA[3] then
            return 90 + iTheta
        else return 90 - iTheta
        end
    else
        if tLocB[3] > tLocA[3] then
            return 270 - iTheta
        else return 270 + iTheta
        end
    end
end

function MoveInDirection(tStart, iAngle, iDistance, bKeepInMapBounds)
    --iAngle: 0 = north, 90 = east, etc.; use GetAngleFromAToB if need angle from 2 positions
    --tStart = {x,y,z} (y isnt used)
    --if bKeepInMapBounds is true then will limit to map bounds
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MoveInDirection'
    local iTheta
    local iFactor
    if iAngle > 360 then
        iAngle = iAngle - 360
    elseif iAngle < 0 then iAngle = iAngle + 360 end

    if iAngle >= 270 then iTheta = iAngle - 270 iFactor = {-1,-1}
    elseif iAngle >= 180 then iTheta = 270 - iAngle iFactor = {-1, 1}
    elseif iAngle >= 90 then iTheta = iAngle - 90 iFactor = {1, 1}
    else iTheta = 90 - iAngle iFactor = {1, -1}
    end
    iTheta = iTheta * math.pi / 180
    local iXAdj = math.cos(iTheta) * iDistance * iFactor[1]
    local iZAdj = math.sin(iTheta) * iDistance * iFactor[2]


    if not(bKeepInMapBounds) then
        return {tStart[1] + iXAdj, GetSurfaceHeight(tStart[1] + iXAdj, tStart[3] + iZAdj), tStart[3] + iZAdj}
    else
        local tTargetPosition = {tStart[1] + iXAdj, GetSurfaceHeight(tStart[1] + iXAdj, tStart[3] + iZAdj), tStart[3] + iZAdj}
        --Get actual distance required to keep within map bounds
        local iMaxDistanceFlat = 0
        local iNewDistWanted = 10000
        --rMapPlayableArea = 2 --{x1,z1, x2,z2} - Set at start of the game, use instead of the scenarioinfo method
        if tTargetPosition[1] < M27MapInfo.rMapPlayableArea[1] then iNewDistWanted = iDistance * (tStart[1] - M27MapInfo.rMapPlayableArea[1]) / (tStart[1] - tTargetPosition[1]) end
        if tTargetPosition[3] < M27MapInfo.rMapPlayableArea[2] then iNewDistWanted = math.min(iNewDistWanted, iDistance * (tStart[3] - M27MapInfo.rMapPlayableArea[2]) / (tStart[3] - tTargetPosition[3])) end
        if tTargetPosition[1] > M27MapInfo.rMapPlayableArea[3] then iNewDistWanted = math.min(iNewDistWanted, iDistance * (M27MapInfo.rMapPlayableArea[3] - tStart[1]) / (tTargetPosition[1] - tStart[1])) end
        if tTargetPosition[3] > M27MapInfo.rMapPlayableArea[4] then iNewDistWanted = math.min(iNewDistWanted, iDistance * (M27MapInfo.rMapPlayableArea[4] - tStart[3]) / (tTargetPosition[3] - tStart[3])) end

        if iNewDistWanted == 10000 then
            return tTargetPosition
        else
            --Are out of playable area, so adjust the position; Can use the ratio of the amount we have moved left/right or top/down vs the long line length to work out the long line length if we reduce the left/right so its within playable area
            return MoveInDirection(tStart, iAngle, iNewDistWanted - 0.1, false)
        end
        --Failed attempt below - mustve got maths wrong as didnt work properly
        --[[local tTargetPosition = {tStart[1] + iXAdj, GetSurfaceHeight(tStart[1] + iXAdj, tStart[3] + iZAdj), tStart[3] + iZAdj}
        --Get actual distance required to keep within map bounds
        local iOverBoundDistance = 0
        --rMapPlayableArea = 2 --{x1,z1, x2,z2} - Set at start of the game, use instead of the scenarioinfo method
        if tTargetPosition[1] < M27MapInfo.rMapPlayableArea[1] then iOverBoundDistance = tTargetPosition[1] - M27MapInfo.rMapPlayableArea[1] end
        if tTargetPosition[3] < M27MapInfo.rMapPlayableArea[2] then  iOverBoundDistance = math.min(tTargetPosition[3] - M27MapInfo.rMapPlayableArea[2], iOverBoundDistance) end
        if iOverBoundDistance == 0 then
            if tTargetPosition[1] > M27MapInfo.rMapPlayableArea[3] then iOverBoundDistance = tTargetPosition[1] - M27MapInfo.rMapPlayableArea[3] end
            if tTargetPosition[3] > M27MapInfo.rMapPlayableArea[4] then iOverBoundDistance = math.min(iOverBoundDistance, tTargetPosition[3] - M27MapInfo.rMapPlayableArea[4]) end
        end

        if iOverBoundDistance == 0 then
            return tTargetPosition
        else
            --Are out of playable area, so adjust the position; see diagram in v25 release notes which uses an example of moving 200 degrees from A to B by 14, and ending up 3 out of the map distance on the x axis
            local iNewAngle = (90-(180-(360-iAngle)))
            if iNewAngle < 0 then iNewAngle = iNewAngle+360 elseif iNewAngle > 360 then iNewAngle = iNewAngle - 360 end
            return MoveInDirection(tTargetPosition, iNewAngle, iOverBoundDistance + 0.1, false)
        end--]]
    end
end

function GetAIBrainArmyNumber(aiBrain)
    --note - this is different to aiBrain:GetArmyIndex() which returns the army index; e.g. if 2 players, will have army index 1 and 2; however if 4 start positions, then might have ARMY_2 and ARMY_4 for those 2 players
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    if aiBrain then
        --For reference - all the attempts using string.sub to get the last 2 digits - gave up in the end and used gsub
        --if bDebugMessages == true then LOG('GetAIBrainArmyNumber: aiBrain.Name='..aiBrain.Name..'; string.sub5='..string.sub(aiBrain.Name, (string.len(aiBrain.Name)-5))..'; string.sub7='..string.sub(aiBrain.Name, (string.len(aiBrain.Name)-7))..'; string.sub custom='..string.sub(aiBrain.Name, 6, string.len(aiBrain.Name) - 6)..'string.sub custom2='..string.sub(aiBrain.Name, 6, 1)..'; sub custom3='..string.sub(aiBrain.Name, 6, 2)..'; tostring'..string.sub(tostring(aiBrain.Name), 3, 2)..'; gsub='..string.gsub(aiBrain.Name, 'ARMY_', '')) end

        local sArmyNumber = string.gsub(aiBrain.Name, 'ARMY_', '')
        if bDebugMessages == true then LOG('GetAIBrainArmyNumber: sArmyNumber='..sArmyNumber) end
        if string.len(sArmyNumber) <= 2 then return tonumber(sArmyNumber) else return nil end
    else
        ErrorHandler('aiBrain is nil')
        return nil
    end
end

function IsACU(oUnit)
    if oUnit.Dead then return false else
        if oUnit.GetUnitId and EntityCategoryContains(categories.COMMAND, oUnit.UnitId) then return true else return false end
    end
    --if UnitID == 'ual0001' then -- Aeon
--        return true
--    elseif UnitID == 'uel0001' then -- UEF
--        return true
--    elseif UnitID == 'url0001' then -- Cybran
--        return true
--    elseif UnitID == 'xsl0001' then --Sera
--        return true
end

function GetACU(aiBrain)
    function GetSubstituteACU(aiBrain)
        --Get substitute
        local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
        local tSubstitutes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryAirFactory + M27UnitInfo.refCategoryLandFactory)
        if IsTableEmpty(tSubstitutes) then
            tSubstitutes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryEngineer)
            if IsTableEmpty(tSubstitutes) then
                tSubstitutes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryStructure)
                if IsTableEmpty(tSubstitutes) then
                    tSubstitutes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryLand)
                end
            end
        end
        if IsTableEmpty(tSubstitutes) then
            aiBrain.M27IsDefeated = true
        else
            aiBrain[M27Overseer.refoStartingACU] = GetNearestUnit(tSubstitutes, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain)
            if not(aiBrain[M27Overseer.refoStartingACU] and not(aiBrain[M27Overseer.refoStartingACU].Dead)) then
                ErrorHandler('Dont have a valid substitute ACU, will treat us as being defeated')
                aiBrain.M27IsDefeated = true
            else
                aiBrain[M27Overseer.refoStartingACU]['M27ACUSubstitute'] = true
            end
        end
    end

    if aiBrain[M27Overseer.refoStartingACU] == nil then
        if aiBrain == nil then
            ErrorHandler('aiBrain not specified - update function call')
        else
            local tACUUnits = aiBrain:GetListOfUnits(categories.COMMAND, false, true)
            if IsTableEmpty(tACUUnits) == false then
                for _, oCurACU in aiBrain:GetListOfUnits(categories.COMMAND, false, true) do
                    aiBrain[M27Overseer.refoStartingACU] = oCurACU
                    break
                end
            else
                if ScenarioInfo.Options.Victory == "demoralization" then
                    ErrorHandler('Cant find any ACUs that we own, and in assassination game mode, so will treat us as being defeated')
                    aiBrain.M27IsDefeated = true
                    M27Overseer.tAllActiveM27Brains[aiBrain:GetArmyIndex()] = nil

                else
                    GetSubstituteACU(aiBrain)
                    --WaitSeconds(30)
                    --ErrorHandler('ACU hasnt been set - finished waiting 30 seconds to try and avoid crash, then will return nil')
                end
            end
        end
    else
        if aiBrain[M27Overseer.refoStartingACU].Dead then
            if GetGameTimeSeconds() <= 10 then
                LOG('WARNING - GetACU failed to find alive AUC in first 10 seconds of game, will keep trying')
                WaitSeconds(1)
                return GetACU(aiBrain)
            else
                --is an error where if return the ACU then causes a hard crash (due to some of hte code that relies on this) - easiest way is to just return nil causing an error message that doesnt cause a hard crash
                --(have tested without waiting any seconds and it avoids the hard crash, but waiting just to be safe)
                --ErrorHandler('ACU is dead - will wait 1 second and then return nil', nil, true)
                --WaitSeconds(1)
                --ErrorHandler('ACU is dead - finished waiting 1 second to try and avoid crash', nil, true)
                M27Overseer.iACUAlternativeFailureCount = M27Overseer.iACUAlternativeFailureCount + 1
                ErrorHandler('ACU is dead, will return nil if in assination, or a substitute unit otherwise; M27Overseer.iACUAlternativeFailureCount='..M27Overseer.iACUAlternativeFailureCount)
                if ScenarioInfo.Options.Victory == "demoralization" then
                    aiBrain.M27IsDefeated = true
                elseif aiBrain:IsDefeated() then
                    aiBrain.M27IsDefeated = true
                else
                    GetSubstituteACU(aiBrain)
                end
            end
        elseif aiBrain[M27Overseer.refoStartingACU]['M27ACUSubstitute'] and aiBrain:IsDefeated() then aiBrain.M27IsDefeated = true
        end
    end
    if aiBrain.M27IsDefeated then aiBrain[M27Overseer.refoStartingACU] = nil end
    return aiBrain[M27Overseer.refoStartingACU]
end

function ConvertAbsolutePositionToRelative(tableAbsolutePositions, relativePosition, bIgnoreY)
    --NOTE: Not suitable for e.g. giving a build order location, since that appears to be affected by the direction the unit is facing as well?
    -- returns a table of relative positions based on the position of absoluteposition to the relativeposition
    -- if bIgnoreY is false then will do relative y position=0, otherwise will use relativePosition's y value
    local RelX, RelY, RelZ
    local tableRelative = {}
    if bIgnoreY == nil then bIgnoreY = true end
    --LOG('ConvertAbsolutePositionToRelative: tableAbsolutePositions[1]='..tostring(tableAbsolutePositions[1]))
    local bMultiDimensionalTable = IsTableArray(tableAbsolutePositions[1])
    if bMultiDimensionalTable == false then
        RelX = tableAbsolutePositions[1] - relativePosition[1]
        if bIgnoreY then RelY = 0
        else RelY = tableAbsolutePositions[2] - relativePosition[2]
        end
        RelZ = tableAbsolutePositions[3] - relativePosition[3]
        tableRelative = {RelX, RelY, RelZ}
    else
        for i, v in ipairs(tableAbsolutePositions) do
            RelX = tableAbsolutePositions[i][1] - relativePosition[1]
            if bIgnoreY then RelY = 0
            else RelY = tableAbsolutePositions[i][2] - relativePosition[2]
            end
            RelZ = tableAbsolutePositions[i][3] - relativePosition[3]
            tableRelative[i] = {RelX, RelY, RelZ}
            --LOG('Converting Abs to Rel: Abs='..tableAbsolutePositions[i][1]..'-'..tableAbsolutePositions[i][2]..'-'..tableAbsolutePositions[i][3]..'; RelPos='..RelX..RelY..RelZ..'; builderPos='..relativePosition[1]..'-'..relativePosition[2]..'-'..relativePosition[3])
        end

    end
    return tableRelative
end

function ConvertLocationsToBuildTemplate(tableUnits, tableRelativePositions)
    -- Returns a table that can be used as a baseTemplate by AIExecuteBuildStructure and similar functions
    local baseTemplate = {}
    baseTemplate[1] = {} --allows for different locations for different units, wont use this functionality though
    baseTemplate[1][1] = tableUnits -- Units that this applies to
    --baseTemplate[1][1+x] is the dif co-ordinates, each a 3 value table
    --LOG('About to attempt to convert tableRelativePositions into build template')
    local bMultiDimensionalTable = IsTableArray(tableRelativePositions[1])
    if bMultiDimensionalTable == true then
        for i, v in ipairs(tableRelativePositions) do
            baseTemplate[1][1+i] = {}
            baseTemplate[1][1 + i][1] = v[1]
            baseTemplate[1][1 + i][3] = v[2] -- basetemplate changes direction in first 2 of the 3 co-ords
            baseTemplate[1][1 + i][2] = v[3]
            --LOG('ConvertLocationsToBuildTemplate: i='..i..'; baseTemplate[1][1=i][1],2,3='..baseTemplate[1][1+i][1]..'-'..baseTemplate[1][1+i][2]..'-'..baseTemplate[1][1+i][3])
        end
    else
        baseTemplate[1][2] = {}
        baseTemplate[1][2][1] = tableRelativePositions[1]
        baseTemplate[1][2][3] = tableRelativePositions[2]
        baseTemplate[1][2][2] = tableRelativePositions[3]
    end
    return baseTemplate
end

function GetAllUnitPositions(tUnits)
    --Converts a table of units into a table of positions
    local tUnitPositions = {}
    local iUnitCount = 0
    for _, v in tUnits do
        iUnitCount = iUnitCount + 1
        tUnitPositions[iUnitCount] = v:GetPosition()
    end
    --LOG('GetAllUnitPositions: iUnitCount='..iUnitCount)
    return tUnitPositions
end

function GetNumberOfUnits(aiBrain, category)
    --returns the number of units of a particular category the aiBrain has
    --categories follow same appraoch as the builder groups, e.g. categories.STRUCTURE * categories.HYDROCARBON to return no. of hydrocarbons

    --local category = categories.STRUCTURE * categories.HYDROCARBON
    local numUnits = 0
    local testCat = category
    if type(category) == 'string' then
        testCat = ParseEntityCategory(category)
    end
    numUnits = aiBrain:GetCurrentUnits(testCat)
    return numUnits
end

function ConvertLocationToStringRef(tLocation)
    return ConvertLocationToReference(tLocation)
    --return 'X'..tLocation[1]..';Z'..tLocation[3]
end

function FactionIndexToCategory(iFactionIndex)
    --returns the categories.[FACTION] for iFactionIndex
    local tCategoryByIndex = {[1] = categories.UEF, [2] = categories.AEON, [3] = categories.CYBRAN, [4] = categories.SERAPHIM, [5] = categories.NOMADS, [6] = categories.ARM, [7] = categories.CORE }
    return tCategoryByIndex[iFactionIndex]
end

function GetFactionNameByIndex(iFactionIndex)
    --NOTE: Largely replaced by M27UnitInfo globally defining variables for each number, e.g. refFactionUEF = 1
    --e.g. if have oUnitBP, then can check faction name with .General.FactionName
    local tFactionNameByIndex = {[1] = 'UEF', [2]= 'Aeon', [3] = 'Cybran', [4] = 'Seraphim', [5] = 'Nomads'}
    return tFactionNameByIndex[iFactionIndex]
end

function GetUnitsInFactionCategory(aiBrain, category)
    --returns a table of the units that aiBrain's faction that meet category
    --Category is e.g. categories.LAND * categories.DIRECTFIRE (i.e. based on the categories {} data of unit blueprints)

    --local FactionIndexToCategory = {[1] = categories.UEF, [2] = categories.AEON, [3] = categories.CYBRAN, [4] = categories.SERAPHIM, [5] = categories.NOMADS, [6] = categories.ARM, [7] = categories.CORE }
    --[[local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    if bDebugMessages == true then
        LOG('FactionIndex='..aiBrain:GetFactionIndex())
        if FactionIndexToCategory[aiBrain:GetFactionIndex()] == nil then LOG('FactionIndexToCategory is nil') end
    end]]--
    local iFactionCat = FactionIndexToCategory(aiBrain:GetFactionIndex())
    --[[local tAllBlueprints = EntityCategoryGetUnitList(category)
    local tFactionBlueprints
    local iValidBlueprints
    for _, sBlueprint in tAllBlueprints do
        if EntityCategoryContains(iFactionCat, sBlueprint) then
            if tFactionBlueprints == nil then tFactionBlueprints = {} end
            iValidBlueprints = iValidBlueprints + 1
            tFactionBlueprints[iValidBlueprints] = sBlueprint
        end
    end
    return tFactionBlueprints]]--
    return EntityCategoryGetUnitList(category * iFactionCat)
end

function GetNearestUnit(tUnits, tCurPos, aiBrain, bHostileOnly, bOurAIOnly)
    --returns the nearest unit in tUnits from tCurPos
    --bHostile defaults to false; if true then unit must be hostile
    --aiBrain: Optional unless are setting bHostileOnly or bOurAIOnly to true
    --bOurAIOnly - only consider units that we own
    local sFunctionRef = 'GetNearestUnit'
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    FunctionProfiler(sFunctionRef, refProfilerStart)
    local iMinDist = 1000000
    local iCurDist
    local iNearestUnit
    local bValidUnit = false
    local iPlayerArmyIndex
    if not(aiBrain == nil) then iPlayerArmyIndex = aiBrain:GetArmyIndex() end
    local iUnitArmyIndex
    if bHostileOnly == nil then bHostileOnly = false end
    if bDebugMessages == true then LOG('GetNearestUnit: tUnits table size='..table.getn(tUnits)) end
    for iUnit, oUnit in tUnits do
        if not(oUnit.Dead) then
            bValidUnit = true
            if bHostileOnly == true then
                bValidUnit = false
                if oUnit.GetAIBrain then
                    iUnitArmyIndex = oUnit:GetAIBrain():GetArmyIndex()
                    if IsEnemy(iUnitArmyIndex, iPlayerArmyIndex) then
                        bValidUnit = true
                    end
                end
            elseif bOurAIOnly and not(aiBrain==oUnit:GetAIBrain()) then
                bValidUnit = false
            end
            if bValidUnit == true then
                iCurDist = GetDistanceBetweenPositions(oUnit:GetPosition(), tCurPos)
                if bDebugMessages == true then LOG('GetNearestUnit: iUnit='..iUnit..'; iCurDist='..iCurDist..'; iMinDist='..iMinDist) end
                if iCurDist < iMinDist then
                    iMinDist = iCurDist
                    iNearestUnit = iUnit
                end
            end
        end
    end

    if bDebugMessages == true then
        if iNearestUnit == nil then LOG('Nearest unit is nil')
        else LOG('Nearest unit ID='..tUnits[iNearestUnit].UnitId)
        end
    end
    FunctionProfiler(sFunctionRef, refProfilerEnd)
    if iNearestUnit then return tUnits[iNearestUnit]
    else return nil end
end

function CanSeeUnit(aiBrain, oUnit, bTrueIfOnlySeeBlip)
    --returns true if aiBrain can see oUnit
    --bTrueIfOnlySeeBlip - returns true if can see a blip
    if bTrueIfOnlySeeBlip == nil then bTrueIfOnlySeeBlip = false end
    local iUnitBrain = oUnit:GetAIBrain()
    if iUnitBrain == aiBrain then return true
    else
        local bCanSeeUnit = false
        local iArmyIndex = aiBrain:GetArmyIndex()
        if not(oUnit.Dead) then
            local oBlip = oUnit:GetBlip(iArmyIndex)
            if oBlip then
                if bTrueIfOnlySeeBlip then return true
                elseif oBlip:IsSeenEver(iArmyIndex) then return true end
            end
        end
    end
    return false
end

function CalculateDistanceDeviationOfPositions(tPositions, iOptionalCentreSize)
    --Returns the standard deviation for tPositions - used to assess how spread out a platoon is
    --reduces the gap from the centre by iOptionalCentreSize
    local sFunctionRef = 'CalculateDistanceDeviationOfPositions'
    FunctionProfiler(sFunctionRef, refProfilerStart)
    if iOptionalCentreSize == nil then iOptionalCentreSize = 0 end
    local iTotalX = 0
    local iTotalZ = 0
    local iCount = 0
    --Calculate average position:
    for i1, tCurPos in tPositions do
        iCount = iCount + 1
        iTotalX = iTotalX + tCurPos[1]
        iTotalZ = iTotalZ + tCurPos[3]
    end
    local iAverageX = iTotalX / iCount
    local iAverageZ = iTotalZ / iCount
    --Calc sum of squared differences:
    local iCurDistance = 0
    local iCurDifSquared = 0
    local iSquaredDifTotal = 0
    for i1, tCurPos in tPositions do
        iCurDistance = VDist2(tCurPos[1], tCurPos[3], iAverageX, iAverageZ)
        if iCurDistance > iOptionalCentreSize then iCurDistance = iCurDistance - iOptionalCentreSize
        else iCurDistance = 0 end
        iCurDifSquared = iCurDistance * iCurDistance
        iSquaredDifTotal = iSquaredDifTotal + iCurDifSquared
    end
    FunctionProfiler(sFunctionRef, refProfilerEnd)
    return math.sqrt(iSquaredDifTotal / iCount)
end

function FunctionProfiler(sFunctionRef, sStartOrEndRef)
    --sStartOrEndRef: refProfilerStart or refProfilerEnd (0 or 1)
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    if M27Config.M27RunProfiling then

        if sStartOrEndRef == refProfilerStart then
            --First ever time calling:
            --1-off for any function - already done via global variables above

            --1-off for this function
            if not(tProfilerStartCount[sFunctionRef]) then
                tProfilerStartCount[sFunctionRef] = 0
                tProfilerEndCount[sFunctionRef] = 0
                tProfilerFunctionStart[sFunctionRef] = {}
                tProfilerTimeTakenCumulative[sFunctionRef] = 0
                tProfilerTimeTakenByCount[sFunctionRef] = {}
            end

            --1-off for this tick
            local iGameTimeInTicks = math.floor(GetGameTimeSeconds()*10)
            if tProfilerTimeTakenInTickByFunction[iGameTimeInTicks] == nil then
                --if bDebugMessages == true then LOG('FunctionProfiler: '..sFunctionRef..': '..iGameTimeInTicks..': Resetting active profiler') end
                tProfilerTimeTakenInTickByFunction[iGameTimeInTicks] = {}
                tProfilerCumulativeTimeTakenInTick[iGameTimeInTicks] = 0
                sProfilerActiveFunctionForThisTick = 'nil'
                tProfilerCountByTickByFunction[iGameTimeInTicks] = {}
            end

            --Increase unique count
            local iCount = tProfilerStartCount[sFunctionRef] + 1
            tProfilerStartCount[sFunctionRef] = iCount
            tProfilerFunctionStart[sFunctionRef][iCount] = GetSystemTimeSecondsOnlyForProfileUse()
            if sProfilerActiveFunctionForThisTick == 'nil' then sProfilerActiveFunctionForThisTick = sFunctionRef end
            if tProfilerCountByTickByFunction[iGameTimeInTicks][sFunctionRef] == nil then tProfilerCountByTickByFunction[iGameTimeInTicks][sFunctionRef] = 0 end
            tProfilerCountByTickByFunction[iGameTimeInTicks][sFunctionRef] = tProfilerCountByTickByFunction[iGameTimeInTicks][sFunctionRef] + 1
            --if bDebugMessages == true then LOG('FunctionProfiler: '..sFunctionRef..': refProfilerStart; iCount='..iCount..'; iGameTimeInTicks='..iGameTimeInTicks..'; System time at start='..GetSystemTimeSecondsOnlyForProfileUse()..'; tProfilerFunctionStart[sFunctionRef][iCount]='..tProfilerFunctionStart[sFunctionRef][iCount]) end

        elseif sStartOrEndRef == refProfilerEnd then
            tProfilerEndCount[sFunctionRef] = tProfilerEndCount[sFunctionRef] + 1
            local iCount = tProfilerEndCount[sFunctionRef]
            local iGameTimeInTicks = math.floor(GetGameTimeSeconds()*10)
            if tProfilerFunctionStart[sFunctionRef][iCount] == nil then ErrorHandler('sFunctionRef='..sFunctionRef..'; iGameTimeInTicks='..iGameTimeInTicks..'; iCount='..(iCount or 'nil')) end
            local iCurTimeTaken = GetSystemTimeSecondsOnlyForProfileUse() - tProfilerFunctionStart[sFunctionRef][iCount]

            if M27Config.M27ProfilingIgnoreFirst2Seconds and iGameTimeInTicks <= 20 then iCurTimeTaken = 0 end
            --if bDebugMessages == true then LOG('FunctionProfiler: '..sFunctionRef..': refProfilerEnd; iCount='..iCount..'; iCurTimeTaken='..iCurTimeTaken..'; tProfilerFunctionStart[sFunctionRef][iCount]='..tProfilerFunctionStart[sFunctionRef][iCount]) end
            if not(tProfilerTimeTakenCumulative[sFunctionRef]) then tProfilerTimeTakenCumulative[sFunctionRef] = 0 end
            tProfilerTimeTakenCumulative[sFunctionRef] = tProfilerTimeTakenCumulative[sFunctionRef] + iCurTimeTaken
            tProfilerTimeTakenByCount[sFunctionRef][iCount] = iCurTimeTaken


            if not(tProfilerTimeTakenInTickByFunction[iGameTimeInTicks]) then
                tProfilerTimeTakenInTickByFunction[iGameTimeInTicks] = {}
                tProfilerCumulativeTimeTakenInTick[iGameTimeInTicks] = 0
                tProfilerCountByTickByFunction[iGameTimeInTicks] = {}
            end

            if not(tProfilerTimeTakenInTickByFunction[iGameTimeInTicks][sFunctionRef]) then tProfilerTimeTakenInTickByFunction[iGameTimeInTicks][sFunctionRef] = 0 end

            tProfilerTimeTakenInTickByFunction[iGameTimeInTicks][sFunctionRef] = tProfilerTimeTakenInTickByFunction[iGameTimeInTicks][sFunctionRef] + iCurTimeTaken

            --if bDebugMessages == true then LOG('FunctionProfiler: iGameTimeInTicks='..iGameTimeInTicks..'; sFunctionRef='..sFunctionRef..'; sProfilerActiveFunctionForThisTick='..sProfilerActiveFunctionForThisTick) end
            if sFunctionRef == sProfilerActiveFunctionForThisTick or sProfilerActiveFunctionForThisTick == 'nil' then
                tProfilerCumulativeTimeTakenInTick[iGameTimeInTicks] = tProfilerCumulativeTimeTakenInTick[iGameTimeInTicks] + iCurTimeTaken
                --if bDebugMessages == true then LOG('FunctionProfiler: iGameTimeInTicks='..iGameTimeInTicks..'; Clearing active function from profiler; iCurTimeTaken='..iCurTimeTaken..'; tProfilerCumulativeTimeTakenInTick[iGameTimeInTicks]='..tProfilerCumulativeTimeTakenInTick[iGameTimeInTicks]) end
                sProfilerActiveFunctionForThisTick = 'nil'
            end

            --Track longest tick (ignore first min due to mapping initialisation)
            if iGameTimeInTicks > 600 then
                if iCurTimeTaken > refiLongestTickAfterStartTime then
                    refiLongestTickAfterStartTime = iCurTimeTaken
                    refiLongestTickAfterStartRef = iGameTimeInTicks
                end
            end

        else ErrorHandler('FunctionProfiler: Unknown reference, wont record')
        end
    end
end

function FunctionProfilerOld(sFunctionRef, sStartOrEndRef)
    --sStartOrEndRef: refProfilerStart or refProfilerEnd (0 or 1)
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    if M27Config.M27RunProfiling then

        if sStartOrEndRef == refProfilerStart then
            --First ever time calling:
            --1-off for any function - already done via global variables above

            --1-off for this function
            if not(tProfilerStartCount[sFunctionRef]) then
                tProfilerStartCount[sFunctionRef] = 0
                tProfilerEndCount[sFunctionRef] = 0
                tProfilerFunctionStart[sFunctionRef] = {}
                tProfilerTimeTakenCumulative[sFunctionRef] = 0
                tProfilerTimeTakenByCount[sFunctionRef] = {}
            end

            --1-off for this tick
            local iGameTimeInTicks = math.floor(GetGameTimeSeconds()*10)
            if tProfilerTimeTakenInTickByFunction[iGameTimeInTicks] == nil then
                --if bDebugMessages == true then LOG('FunctionProfiler: '..sFunctionRef..': '..iGameTimeInTicks..': Resetting active profiler') end
                tProfilerTimeTakenInTickByFunction[iGameTimeInTicks] = {}
                tProfilerCumulativeTimeTakenInTick[iGameTimeInTicks] = 0
                sProfilerActiveFunctionForThisTick = 'nil'
                tProfilerCountByTickByFunction[iGameTimeInTicks] = {}
            end

            --Increase unique count
            local iCount = tProfilerStartCount[sFunctionRef] + 1
            tProfilerStartCount[sFunctionRef] = iCount
            tProfilerFunctionStart[sFunctionRef][iCount] = GetSystemTimeSecondsOnlyForProfileUse()
            if sProfilerActiveFunctionForThisTick == 'nil' then sProfilerActiveFunctionForThisTick = sFunctionRef end
            if tProfilerCountByTickByFunction[iGameTimeInTicks][sFunctionRef] == nil then tProfilerCountByTickByFunction[iGameTimeInTicks][sFunctionRef] = 0 end
            tProfilerCountByTickByFunction[iGameTimeInTicks][sFunctionRef] = tProfilerCountByTickByFunction[iGameTimeInTicks][sFunctionRef] + 1
            --if bDebugMessages == true then LOG('FunctionProfiler: '..sFunctionRef..': refProfilerStart; iCount='..iCount..'; iGameTimeInTicks='..iGameTimeInTicks..'; System time at start='..GetSystemTimeSecondsOnlyForProfileUse()..'; tProfilerFunctionStart[sFunctionRef][iCount]='..tProfilerFunctionStart[sFunctionRef][iCount]) end

        elseif sStartOrEndRef == refProfilerEnd then
            tProfilerEndCount[sFunctionRef] = tProfilerEndCount[sFunctionRef] + 1
            local iCount = tProfilerEndCount[sFunctionRef]
            local iGameTimeInTicks = math.floor(GetGameTimeSeconds()*10)
            if tProfilerFunctionStart[sFunctionRef][iCount] == nil then ErrorHandler('sFunctionRef='..sFunctionRef..'; iGameTimeInTicks='..iGameTimeInTicks..'; iCount='..(iCount or 'nil')) end
            local iCurTimeTaken = GetSystemTimeSecondsOnlyForProfileUse() - tProfilerFunctionStart[sFunctionRef][iCount]

            if M27Config.M27ProfilingIgnoreFirstMin and iGameTimeInTicks <= 20 then iCurTimeTaken = 0 end
            --if bDebugMessages == true then LOG('FunctionProfiler: '..sFunctionRef..': refProfilerEnd; iCount='..iCount..'; iCurTimeTaken='..iCurTimeTaken..'; tProfilerFunctionStart[sFunctionRef][iCount]='..tProfilerFunctionStart[sFunctionRef][iCount]) end
            if not(tProfilerTimeTakenCumulative[sFunctionRef]) then tProfilerTimeTakenCumulative[sFunctionRef] = 0 end
            tProfilerTimeTakenCumulative[sFunctionRef] = tProfilerTimeTakenCumulative[sFunctionRef] + iCurTimeTaken
            tProfilerTimeTakenByCount[sFunctionRef][iCount] = iCurTimeTaken


            if not(tProfilerTimeTakenInTickByFunction[iGameTimeInTicks]) then
                tProfilerTimeTakenInTickByFunction[iGameTimeInTicks] = {}
                tProfilerCumulativeTimeTakenInTick[iGameTimeInTicks] = 0
                tProfilerCountByTickByFunction[iGameTimeInTicks] = {}
            end

            if not(tProfilerTimeTakenInTickByFunction[iGameTimeInTicks][sFunctionRef]) then tProfilerTimeTakenInTickByFunction[iGameTimeInTicks][sFunctionRef] = 0 end

            tProfilerTimeTakenInTickByFunction[iGameTimeInTicks][sFunctionRef] = tProfilerTimeTakenInTickByFunction[iGameTimeInTicks][sFunctionRef] + iCurTimeTaken

            --if bDebugMessages == true then LOG('FunctionProfiler: iGameTimeInTicks='..iGameTimeInTicks..'; sFunctionRef='..sFunctionRef..'; sProfilerActiveFunctionForThisTick='..sProfilerActiveFunctionForThisTick) end
            if sFunctionRef == sProfilerActiveFunctionForThisTick or sProfilerActiveFunctionForThisTick == 'nil' then
                tProfilerCumulativeTimeTakenInTick[iGameTimeInTicks] = tProfilerCumulativeTimeTakenInTick[iGameTimeInTicks] + iCurTimeTaken
                --if bDebugMessages == true then LOG('FunctionProfiler: iGameTimeInTicks='..iGameTimeInTicks..'; Clearing active function from profiler; iCurTimeTaken='..iCurTimeTaken..'; tProfilerCumulativeTimeTakenInTick[iGameTimeInTicks]='..tProfilerCumulativeTimeTakenInTick[iGameTimeInTicks]) end
                sProfilerActiveFunctionForThisTick = 'nil'
            end

            --Track longest tick (ignore first min due to mapping initialisation)
            if iGameTimeInTicks > 600 then
                if iCurTimeTaken > refiLongestTickAfterStartTime then
                    refiLongestTickAfterStartTime = iCurTimeTaken
                    refiLongestTickAfterStartRef = iGameTimeInTicks
                end
            end

        else ErrorHandler('FunctionProfiler: Unknown reference, wont record')
        end
    end
end

function ProfilerOutput()
    local sFunctionRef = 'ProfilerOutput'
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end

    if M27Config.M27RunProfiling then
        --[[--Cumulative most intensive functions
        local iCount = 0
        for sFunctionName, iValue in SortTableByValue(tProfilerTimeTakenCumulative, true) do
            iCount = iCount + 1
            LOG(sFunctionRef..': Top10Cumulative No.'..iCount..'='..sFunctionName..'; Times run cumulative='..tProfilerStartCount[sFunctionName]..'; Time='..iValue)
            if iCount >= 10 then break end
        end--]]

        --[[local iThreshold = 0.01
        local iEntireTickThreshold = 0.02
        local iStartTick = math.floor(GetGameTimeSeconds()*10) - 10
        --if bDebugMessages == true then LOG(sFunctionRef..': iStartTick='..iStartTick..'; GetGameTimeSeconds='..GetGameTimeSeconds()..'; math.floor(GetGameTimeSeconds()='..math.floor(GetGameTimeSeconds())..'; same but *10='..math.floor(GetGameTimeSeconds()*10)) end
        for iCurTick = iStartTick, 10 do --]]
        --if bDebugMessages == true then LOG(sFunctionRef..': iCurTick='..iCurTick..'; tProfilerCumulativeTimeTakenInTick[iCurTick]='..(tProfilerCumulativeTimeTakenInTick[iCurTick] or 'Doesnt exist')) end
        --if tProfilerCumulativeTimeTakenInTick[iCurTick] >= iThreshold or iCurTick == refiLongestTickAfterStartRef or tProfilerActualTimeTakenInTick[iCurTick] >= iEntireTickThreshold then
        --local sReason = 'Over threshold of '..iThreshold
        --if iCurTick == refiLongestTickAfterStartRef then sReason = 'Highest tick we have on record'
        --elseif tProfilerActualTimeTakenInTick[iCurTick] >= iEntireTickThreshold then sReason = 'Actual tick time incl wider FAF code over threshold' end

        local iCurTick = math.floor(GetGameTimeSeconds()*10) - 1
        if not(tbProfilerOutputGivenForTick[iCurTick]) then
            tbProfilerOutputGivenForTick[iCurTick] = true
            LOG(sFunctionRef..': Tick='..iCurTick..'; Time taken='..(tProfilerCumulativeTimeTakenInTick[iCurTick] or 'nil')..'; Entire time for tick='..(tProfilerActualTimeTakenInTick[iCurTick] or 'nil')..'; About to list out top 10 functions in this tick')
            local iCount = 0
            if IsTableEmpty(tProfilerTimeTakenInTickByFunction[iCurTick]) == false then
                for sFunctionName, iValue in SortTableByValue(tProfilerTimeTakenInTickByFunction[iCurTick], true) do
                    iCount = iCount + 1
                    LOG(sFunctionRef..': iTick='..iCurTick..': No.'..iCount..'='..sFunctionName..'; TimesRun='..(tProfilerCountByTickByFunction[iCurTick][sFunctionName] or 'nil')..'; Total Time='..iValue)
                    if iCount >= 10 then break end
                end

                LOG(sFunctionRef..': About to list top 10 called functions in this tick')
                iCount = 0
                for sFunctionName, iValue in SortTableByValue(tProfilerCountByTickByFunction[iCurTick], true) do
                    iCount = iCount + 1
                    LOG(sFunctionRef..': iTick='..iCurTick..': No.'..iCount..'='..sFunctionName..'; TimesRun='..(tProfilerCountByTickByFunction[iCurTick][sFunctionName] or 'nil')..'; Total Time='..iValue)
                    if iCount >= 10 then break end
                end
                LOG(sFunctionRef..': IssueMove cumulative count='..IssueCount)
            end
            --else
            --LOG(sFunctionRef..': Tick='..iCurTick..'; Below threshold at '..(tProfilerCumulativeTimeTakenInTick[iCurTick] or 'missing'))
            --end
            --end

            --Include full output of function cumulative time taken every interval
            local bFullOutputNow = false

            if iCurTick > (iFullOutputCount + 1) * iFullOutputIntervalInTicks then bFullOutputNow = true end
            if bFullOutputNow then
                if bFullOutputAlreadyDone[iFullOutputCount + 1] then
                    --Already done
                else
                    iFullOutputCount = iFullOutputCount + 1
                    bFullOutputAlreadyDone[iFullOutputCount] = true
                    LOG(sFunctionRef..': About to print detailed output of all functions cumulative values')
                    iCount = 0
                    for sFunctionName, iValue in SortTableByValue(tProfilerTimeTakenCumulative, true) do
                        iCount = iCount + 1
                        if tProfilerStartCount[sFunctionName] == nil then LOG('ERROR somehow '..sFunctionName..' hasnt been recorded in the cumulative count despite having its time recorded.  iValue='..iValue)
                        else
                            LOG(sFunctionRef..': No.'..iCount..'='..sFunctionName..'; TimesRun='..tProfilerStartCount[sFunctionName]..'; Time='..iValue)
                        end
                    end
                    --Give the total time taken to get to this point based on time per tick
                    local iTotalTimeTakenToGetHere = 0
                    local iTotalDelayedTime = 0
                    local iLongestTickTime = 0
                    local iLongestTickRef
                    for iTick, iTime in tProfilerActualTimeTakenInTick do
                        iTotalTimeTakenToGetHere = iTotalTimeTakenToGetHere + iTime
                        iTotalDelayedTime = iTotalDelayedTime + math.max(0, iTime - 0.1)
                        if iTime > iLongestTickTime then
                            iLongestTickTime = iTime
                            iLongestTickRef = iTick
                        end
                    end
                    LOG(sFunctionRef..': Total time taken to get to '..iCurTick..'= '..iTotalTimeTakenToGetHere..'; Total time of any freezes = '..iTotalDelayedTime..'; Longest tick time='..iLongestTickTime..'; tick ref = '..((iLongestTickRef or 0) - 1)..' to '..(iLongestTickRef or 'nil'))

                end
            end
        end
    end
end


function ProfilerOutputAttemptedRework()
    --Temporarily saved attempted rework in v29 but led to strange results
    local sFunctionRef = 'ProfilerOutput'
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end

    if M27Config.M27RunProfiling then
        --[[--Cumulative most intensive functions
        local iCount = 0
        for sFunctionName, iValue in SortTableByValue(tProfilerTimeTakenCumulative, true) do
            iCount = iCount + 1
            LOG(sFunctionRef..': Top10Cumulative No.'..iCount..'='..sFunctionName..'; Times run cumulative='..tProfilerStartCount[sFunctionName]..'; Time='..iValue)
            if iCount >= 10 then break end
        end--]]

        --[[local iThreshold = 0.01
        local iEntireTickThreshold = 0.02
        local iStartTick = math.floor(GetGameTimeSeconds()*10) - 10
        --if bDebugMessages == true then LOG(sFunctionRef..': iStartTick='..iStartTick..'; GetGameTimeSeconds='..GetGameTimeSeconds()..'; math.floor(GetGameTimeSeconds()='..math.floor(GetGameTimeSeconds())..'; same but *10='..math.floor(GetGameTimeSeconds()*10)) end
        for iCurTick = iStartTick, 10 do --]]
            --if bDebugMessages == true then LOG(sFunctionRef..': iCurTick='..iCurTick..'; tProfilerCumulativeTimeTakenInTick[iCurTick]='..(tProfilerCumulativeTimeTakenInTick[iCurTick] or 'Doesnt exist')) end
            --if tProfilerCumulativeTimeTakenInTick[iCurTick] >= iThreshold or iCurTick == refiLongestTickAfterStartRef or tProfilerActualTimeTakenInTick[iCurTick] >= iEntireTickThreshold then
                --local sReason = 'Over threshold of '..iThreshold
                --if iCurTick == refiLongestTickAfterStartRef then sReason = 'Highest tick we have on record'
                --elseif tProfilerActualTimeTakenInTick[iCurTick] >= iEntireTickThreshold then sReason = 'Actual tick time incl wider FAF code over threshold' end

        local iCurTick = math.floor(GetGameTimeSeconds()*10) - 1
        if not(tbProfilerOutputGivenForTick[iCurTick]) then
            tbProfilerOutputGivenForTick[iCurTick] = true
            LOG(sFunctionRef..': Tick='..iCurTick..'; Time taken='..(tProfilerCumulativeTimeTakenInTick[iCurTick] or 'nil')..'; Entire time for tick='..(tProfilerActualTimeTakenInTick[iCurTick] or 'nil')..'; About to list out top 10 functions in this tick')
            local iCount = 0
            if IsTableEmpty(tProfilerTimeTakenInTickByFunction[iCurTick]) == false then
                for sFunctionName, iValue in SortTableByValue(tProfilerTimeTakenInTickByFunction[iCurTick], true) do
                    iCount = iCount + 1
                    LOG(sFunctionRef..': iTick='..iCurTick..': No.'..iCount..'='..sFunctionName..'; TimesRun='..(tProfilerCountByTickByFunction[iCurTick][sFunctionName] or 'nil')..'; Total Time='..iValue)
                    if iCount >= 10 then break end
                end

                LOG(sFunctionRef..': About to list top 10 called functions in this tick')
                iCount = 0
                for sFunctionName, iValue in SortTableByValue(tProfilerCountByTickByFunction[iCurTick], true) do
                    iCount = iCount + 1
                    LOG(sFunctionRef..': iTick='..iCurTick..': No.'..iCount..'='..sFunctionName..'; TimesRun='..(tProfilerCountByTickByFunction[iCurTick][sFunctionName] or 'nil')..'; Total Time='..iValue)
                    if iCount >= 10 then break end
                end
                LOG(sFunctionRef..': IssueMove cumulative count='..IssueCount)
            end
                --else
                    --LOG(sFunctionRef..': Tick='..iCurTick..'; Below threshold at '..(tProfilerCumulativeTimeTakenInTick[iCurTick] or 'missing'))
                --end
            --end

            --Include full output of function cumulative time taken every interval
            local bFullOutputNow = false
            local iFunctionsToPrint = 30

            if iCurTick > (iFullOutputCount + 1) * iFullOutputIntervalInTicks then bFullOutputNow = true end
            if bFullOutputNow then
                if bFullOutputAlreadyDone[iFullOutputCount + 1] then
                    --Already done
                else
                    iFullOutputCount = iFullOutputCount + 1
                    iFullOutputCycleCount = iFullOutputCycleCount + 1
                    bFullOutputAlreadyDone[iFullOutputCount] = true
                    iCount = 0
                    if iFullOutputCycleCount >= 10 then
                        iFunctionsToPrint = 10000
                        iFullOutputCycleCount = 0
                    else iFunctionsToPrint = 30 end
                    LOG(sFunctionRef..': About to print detailed output of functions cumulative values. Will print a max of '..iFunctionsToPrint..' functions.')

                    for sFunctionName, iValue in SortTableByValue(tProfilerTimeTakenCumulative, true) do
                        iCount = iCount + 1
                        if tProfilerStartCount[sFunctionName] == nil then LOG('ERROR somehow '..sFunctionName..' hasnt been recorded in the cumulative count despite having its time recorded.  iValue='..iValue)
                        else
                            LOG(sFunctionRef..': No.'..iCount..'='..sFunctionName..'; TimesRun='..tProfilerStartCount[sFunctionName]..'; Time='..iValue)
                        end
                        if iCount > iFunctionsToPrint then break end
                    end
                    --Give the total time taken to get to this point based on time per tick
                    local iTotalTimeTakenToGetHere = 0
                    local iTotalDelayedTime = 0
                    local iLongestTickTime = 0
                    local iLongestTickRef
                    for iTick, iTime in tProfilerActualTimeTakenInTick do
                        iTotalTimeTakenToGetHere = iTotalTimeTakenToGetHere + iTime
                        iTotalDelayedTime = iTotalDelayedTime + math.max(0, iTime - 0.1)
                        if iTime > iLongestTickTime then
                            iLongestTickTime = iTime
                            iLongestTickRef = iTick
                        end
                    end
                    LOG(sFunctionRef..': Total time taken to get to '..iCurTick..'= '..iTotalTimeTakenToGetHere..'; Total time of any freezes = '..iTotalDelayedTime..'; Longest tick time='..iLongestTickTime..'; tick ref = '..((iLongestTickRef or 0) - 1)..' to '..(iLongestTickRef or 'nil'))
                end
            end
        end
    end
end

function ProfilerActualTimePerTick()
    if M27Config.M27RunProfiling then
        local iGameTimeInTicks
        local iPrevGameTime = 0
        local iSystemTime = 0
        while true do
            iPrevGameTime = GetSystemTimeSecondsOnlyForProfileUse()
            WaitTicks(1)
            iSystemTime = GetSystemTimeSecondsOnlyForProfileUse()
            iGameTimeInTicks = math.floor(GetGameTimeSeconds()*10)
            if M27Config.M27ProfilingIgnoreFirst2Seconds and iGameTimeInTicks <= 20 then
                --Dont record
            else
                tProfilerActualTimeTakenInTick[iGameTimeInTicks] = iSystemTime - iPrevGameTime
            end
            ProfilerOutput()
        end

    end
end

function ProfilerActualTimePerTickOld()
    if M27Config.M27RunProfiling then
        local iGameTimeInTicks
        local iPrevGameTime = 0
        local iSystemTime = 0
        while true do
            iPrevGameTime = GetSystemTimeSecondsOnlyForProfileUse()
            WaitTicks(1)
            iSystemTime = GetSystemTimeSecondsOnlyForProfileUse()
            iGameTimeInTicks = math.floor(GetGameTimeSeconds()*10)
            if M27Config.M27ProfilingIgnoreFirstMin and iGameTimeInTicks <= 20 then
                --Dont record
            else
                tProfilerActualTimeTakenInTick[iGameTimeInTicks] = iSystemTime - iPrevGameTime
            end
            ProfilerOutput()
        end

    end
end

function ProfilerTimeSinceLastCall(sReference, iStartTime)
    --Sends a log with how much time has elapsed, and returns the current time
    if iStartTime == nil then iStartTime = 0 end
    local iTimeNow = GetSystemTimeSecondsOnlyForProfileUse()
    LOG(sReference..': Time elapsed='..iTimeNow-iStartTime)
    return iTimeNow
end

--Softles profiler - thanks to Softles for providing this as an alternative approach
local TIME_TABLE = {}
local COUNT_TABLE = {}

local function OnEvent(eventType, lineNo)
    local t = GetSystemTimeSecondsOnlyForProfileUse()
    local funcName = tostring(debug.getinfo(2).name)
    if eventType == "call" then
        if not COUNT_TABLE[funcName] then
            COUNT_TABLE[funcName] = 0
        end
        COUNT_TABLE[funcName] = COUNT_TABLE[funcName] + 1
    end
end
local amStarted = false

function StartSoftlesProfiling()
    if not amStarted then
        amStarted = true
        ForkThread(
                function()
                    coroutine.yield(1)
                    while true do
                        local last = GetSystemTimeSecondsOnlyForProfileUse()
                        debug.sethook(OnEvent,"c")
                        coroutine.yield(1)
                        local diff = math.round(1000*(GetSystemTimeSecondsOnlyForProfileUse() - last))/1000
                        debug.sethook()
                        local s = "PROFILING:"..tostring(diff)
                        for k, v in COUNT_TABLE do
                            s = s.." ("..k..", "..tostring(v)..")"
                        end
                        WARN(s)
                        TIME_TABLE = {}
                        COUNT_TABLE = {}
                    end
                end
        )
    end
end

function ForkedDelayedChangedVariable(oVariableOwner, sVariableName, vVariableValue, iDelayInSeconds, sOptionalOwnerConditionRef, iMustBeLessThanThisTimeValue, iMustBeMoreThanThisTimeValue, vMustNotEqualThisValue)
    --After waiting iDelayInSeconds, changes the variable to vVariableValue.
    WaitSeconds(iDelayInSeconds)
    if oVariableOwner then
        local bReset = true
        if sOptionalOwnerConditionRef then
            if iMustBeLessThanThisTimeValue and oVariableOwner[sOptionalOwnerConditionRef] >= iMustBeLessThanThisTimeValue then bReset = false
            elseif iMustBeMoreThanThisTimeValue and oVariableOwner[sOptionalOwnerConditionRef] <= iMustBeMoreThanThisTimeValue then bReset = false
            elseif vMustNotEqualThisValue and oVariableOwner[sOptionalOwnerConditionRef] == vMustNotEqualThisValue then bReset = false
            end
        end
        if bReset then oVariableOwner[sVariableName] = vVariableValue end
    end
end

function DelayChangeVariable(oVariableOwner, sVariableName, vVariableValue, iDelayInSeconds, sOptionalOwnerConditionRef, iMustBeLessThanThisTimeValue, iMustBeMoreThanThisTimeValue, vMustNotEqualThisValue)
    --sOptionalOwnerConditionRef - can specify a variable for oVariableOwner; if so then the value of this variable must be <= iMustBeLessThanThisTimeValue
    --e.g. if delay reset a variable, but are claling multiple times so want to only reset on the latest value, then this allows for that
    ForkThread(ForkedDelayedChangedVariable, oVariableOwner, sVariableName, vVariableValue, iDelayInSeconds, sOptionalOwnerConditionRef, iMustBeLessThanThisTimeValue, iMustBeMoreThanThisTimeValue, vMustNotEqualThisValue)
end


function DebugArray(Table)
    --Thanks to Uveso who gave me this as a solution for doing a repr of a large table such as a unit or aiBrain that would normally crash the game
    for Index, Array in Table do
        if type(Array) == 'thread' or type(Array) == 'userdata' then
            LOG('Index['..Index..'] is type('..type(Array)..'). I wont print that!')
        elseif type(Array) == 'table' then
            LOG('Index['..Index..'] is type('..type(Array)..'). I wont print that!')
        else
            LOG('Index['..Index..'] is type('..type(Array)..'). "', repr(Array),'".')
        end
    end
end
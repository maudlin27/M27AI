
local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Events = import('/mods/M27AI/lua/AI/M27Events.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')

refProfilerStart = 0
refProfilerEnd = 1

--Debug variables
bGlobalDebugOverride = false
bM27AIInGame = false
tErrorCountByMessage = {} --WHenever we have an error, then the error message is a key that gets included in this table
refiHumansInGame = -1 --Used to determine if some debug functionality like drawing circles is disabled; set to -1 initially so know if it has been run or not before



--Profiling variables
refiLastSystemTimeRecorded = 'M27ProfilingLastSystemTime' --Used for simple profiler to just measure how long something is taking without all the logs

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

tFunctionCallByName = {}
iFunctionCurCount = 0

tiProfilerStartCountByFunction = {} --[functionref] - Used if want to temporarily check how many times a function is called - have this update in the function itself, along with the end count
--example of usage of the above: --M27Utilities.tiProfilerStartCountByFunction[sFunctionRef] = (M27Utilities.tiProfilerStartCountByFunction[sFunctionRef] or 0) + 1 LOG(sFunctionRef..': M27Utilities.tiProfilerStartCountByFunction[sFunctionRef]='..M27Utilities.tiProfilerStartCountByFunction[sFunctionRef])
tiProfilerEndCountByFunction = {} --[functionref] - Used if want to temporarily check how many times a function is called - have this update in the function itself, along with the end count
--Example of usage of the above: M27Utilities.tiProfilerEndCountByFunction[sFunctionRef] = (M27Utilities.tiProfilerEndCountByFunction[sFunctionRef] or 0) + 1 LOG(sFunctionRef..': M27Utilities.tiProfilerEndCountByFunction[sFunctionRef]='..M27Utilities.tiProfilerEndCountByFunction[sFunctionRef])


function ErrorHandler(sErrorMessage, bWarningNotError)
    --Intended to be put in code wherever a condition isn't met that should be, so can debug it without the code crashing
    --Search for "error " in the log to find both these errors and normal lua errors, while not bringing up warnings
    if sErrorMessage == nil then sErrorMessage = 'Not specified' end
    local iCount = (tErrorCountByMessage[sErrorMessage] or 0) + 1
    tErrorCountByMessage[sErrorMessage] = iCount
    local iInterval = 1
    local bShowError = true
    if iCount > 3 then
        bShowError = false
        if iCount > 2187 then iInterval = 2187
        elseif iCount > 729 then iInterval = 729
        elseif iCount > 243 then iInterval = 243
        elseif iCount >= 81 then iInterval = 81
        elseif iCount >= 27 then iInterval = 27
        elseif iCount >= 9 then iInterval = 9
        else iInterval = 3
        end
            if math.floor(iCount / iInterval) == iCount/iInterval then bShowError = true end
    end
    if bShowError then
        local sErrorBase = 'M27ERROR '
        if bWarningNotError then sErrorBase = 'M27WARNING: ' end
        sErrorBase = sErrorBase..'Count='..iCount..': GameTime '..math.floor(GetGameTimeSeconds())..': '
        sErrorMessage = sErrorBase..sErrorMessage
        local a, s = pcall(assert, false, sErrorMessage)
        WARN(a, s)
    end

    --if iOptionalWaitInSeconds then WaitSeconds(iOptionalWaitInSeconds) end
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

    if refiHumansInGame <= 1 or M27Config.M27AllowDebugWithMultipleHumans then

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
        if bDebugMessages == true then LOG('About to draw circle at table location ='..repru(tLocation)) end
        while true do
            DrawCircle(tLocation, iCircleSize, sColour)
            iCurDrawCount = iCurDrawCount + 1
            if iCurDrawCount > iMaxDrawCount then return end
            if bDebugMessages == true then LOG(sFunctionRef..': Will wait 2 ticks then refresh the drawing') end
            coroutine.yield(2) --Any more and circles will flash instead of being constant
        end
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
    if refiHumansInGame <= 1 or M27Config.M27AllowDebugWithMultipleHumans then
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
        if bDebugMessages == true then LOG('About to draw circle at table locations ='..repru(tableLocations)) end
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
end

function DrawTableOfLocations(tableLocations, relativeStart, iColour, iDisplayCount, iCircleSize)
    --if bSingleLocation then tableLocations = {tableLocations} end
    --LOG('DrawTableOfLocations: tableLocations='..repru(tableLocations))
    if not(iCircleSize) then iCircleSize = 0.5 end
    for iLocation, tLocation in tableLocations do
        DrawRectBase(Rect(tLocation[1] - iCircleSize, tLocation[3] - iCircleSize, tLocation[1] + iCircleSize, tLocation[3] + iCircleSize), iColour, iDisplayCount)
    end
end

function DrawRectBase(rRect, iColour, iDisplayCount)
    --Draws lines around rRect; rRect should be a rect table, with keys x0, x1, y0, y1
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DrawRectBase'
    if bDebugMessages == true then LOG(sFunctionRef..': rRect='..repru(rRect)) end

    if refiHumansInGame <= 1 or M27Config.M27AllowDebugWithMultipleHumans then
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

        --if bDebugMessages == true then LOG(sFunctionRef..'tAllX='..repru(tAllX)..'; tAllZ='..repru(tAllZ)..'; Rectx0='..rRect['x0']) end
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
                        if bDebugMessages == true then LOG(sFunctionRef..': tLastPos='..repru(tLastPos)..'; tCurPos='..repru(tCurPos)) end
                        DrawLine(tLastPos, tCurPos, sColour)
                    end
                end
            end
            iCurDrawCount = iCurDrawCount + 1
            if iCurDrawCount > iDisplayCount then return end
            coroutine.yield(2) --Any more and lines will flash instead of being constant
        end
    end
end

function ConvertLocationToReference(tLocation)
    --Rounds tLocation down for X and Z, and uses these to provide a unique string reference (for use for table keys)
    return ('X'..math.floor(tLocation[1])..'Z'..math.floor(tLocation[3]))
end

function SteppingStoneForDrawLocations(tableLocations, relativeStart, iColour, iDisplayCount, iCircleSize)
    --LOG('SteppingStoneForDrawLocations: tableLocations='..repru(tableLocations))
    DrawTableOfLocations(tableLocations, relativeStart, iColour, iDisplayCount, iCircleSize)
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

function DrawLocations(tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation, iCircleSize, bCopyTable)
    --fork thread doesnt seem to work - can't see the circle, even though teh code itself is called; using steppingstone seems to fix this
    --ForkThread(DrawTableOfLocations, tableLocations, relativeStart, iColour, iDisplayCount)
    --DrawTableOfLocations(tableLocations, relativeStart, iColour, iDisplayCount)
    --bCopyTable - want to set this to true if the table sent to this might be changed afterwards due to forkthread meaning the table might become empty

    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DrawLocations'

    if refiHumansInGame <= 1 or M27Config.M27AllowDebugWithMultipleHumans then

        local tTableOfLocations
        if not(bCopyTable) then
            if bSingleLocation then tTableOfLocations = {tableLocations}
            else
                tTableOfLocations = tableLocations
            end
        else

            tTableOfLocations = {}
            local iCount = 0
            for iEntry, tEntry in tableLocations do
                iCount = iCount + 1
                tTableOfLocations[iCount] = {}
                tTableOfLocations[iCount] = {tEntry[1], tEntry[2], tEntry[3]}
            end
            if bSingleLocation then tTableOfLocations = {tTableOfLocations} end
            if bDebugMessages == true then LOG(sFunctionRef..': Finished hard copy of table, iCount='..iCount) end
        end


        if bDebugMessages == true then
            LOG(sFunctionRef..': About to fork threat, bCopyTable='..tostring(bCopyTable)..'; tTableOfLocations='..repru(tTableOfLocations)..'; bSingleLocation='..tostring(bSingleLocation))
        end
        if IsTableEmpty(tTableOfLocations) then ErrorHandler('Trying to draw an empty table')
        else
            --SteppingStoneForDrawLocations(tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation, iCircleSize)
            ForkThread(SteppingStoneForDrawLocations, tTableOfLocations, relativeStart, iColour, iDisplayCount, iCircleSize)--]]
        end
    end

end

function DrawLocation(tLocation, relativeStart, iColour, iDisplayCount, iCircleSize)
    --ForkThread(DrawTableOfLocations, tableLocations, relativeStart, iColour, iDisplayCount, true)
    --DrawTableOfLocations(tableLocations, relativeStart, iColour, iDisplayCount, true)
    --ErrorHandler('Shouldnt be drawing anything')
    if IsTableEmpty(tLocation) then ErrorHandler('tLocation is empty')
    else
        ForkThread(SteppingStoneForDrawLocations, {tLocation}, (relativeStart or false), iColour, iDisplayCount, iCircleSize)
    end
end

function DrawRectangle(rRect, iColour, iDisplayCount)
    --ErrorHandler('Shouldnt be drawing anything')
    ForkThread(SteppingStoneForDrawRect, rRect, iColour, iDisplayCount)
end

function GetAverageOfLocations(tAllLocations)
    local tTotalPos = {0,0,0}
    local iLocationCount = 0
    for iLocation, tLocation in tAllLocations do
        tTotalPos[1] = tTotalPos[1] + tLocation[1]
        tTotalPos[3] = tTotalPos[3] + tLocation[3]
        iLocationCount = iLocationCount + 1
    end
    local tAveragePos = {tTotalPos[1] / iLocationCount, 0, tTotalPos[3] / iLocationCount}
    tAveragePos[2] = GetSurfaceHeight(tAveragePos[1], tAveragePos[3])
    return tAveragePos
end

function GetAveragePosition(tUnits)
    --returns a table with the average position of tUnits
    --local sFunctionRef = 'GetAveragePosition'
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

function GetAveragePositionOfMultipleTablesOfUnits(tTablesOfUnits)
    local tTotalPos = {0,0,0}
    local iUnitCount = 0
    local tCurPos = {}
    for iUnitTable, tUnitTable in tTablesOfUnits do
        --LOG('GetAveragePositionOfMultipleTablesOfUnits: Size of tUnitTable='..table.getn(tUnitTable))
        if IsTableEmpty(tUnitTable) == false then
            for iUnit, oUnit in tUnitTable do
                --LOG('GetAveragePositionOfMultipleTablesOfUnits: considiring unit '..(oUnit.UnitId or 'nil')..(M27UnitInfo.GetUnitLifetimeCount(oUnit) or 'nil'))
                if oUnit.GetPosition then
                    tCurPos = oUnit:GetPosition()
                    if tCurPos[1] then
                        for iAxis = 1, 3 do
                            tTotalPos[iAxis] = tTotalPos[iAxis] + tCurPos[iAxis]
                        end
                        iUnitCount = iUnitCount + 1
                    end
                end
            end
        end
    end
    if iUnitCount == 0 then
        iUnitCount = 1
        ErrorHandler('No units in the tables of units')
    end --Avoid error
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




function ConvertM27AngleToFAFAngle(iM27Angle)
    --Per FAF documentation on issueformmove:
    -- @param degrees The orientation the platoon should take when it reaches the position. South is 0 degrees, east is 90 degrees, etc.
    --Meanwhile M27: 0 is north, 90 is east, etc.
    local iFAFAngle = 180 - iM27Angle
    if iFAFAngle < 0 then iFAFAngle = iFAFAngle + 360 end
    return iFAFAngle
end

function IsLineFromAToBInRangeOfCircleAtC(iDistFromAToB, iDistFromAToC, iDistFromBToC, iAngleFromAToB, iAngleFromAToC, iCircleRadius)
    --E.g. if TML is at point A, target is at point B, and TMD is at point C, does the TMD block the TML in a straight line?
    if iDistFromAToC <= iCircleRadius or iDistFromBToC <= iCircleRadius then
        --LOG('Dist within circle radius so are in range, returning true')
        return true
    --Note - have done circleradius*1.2 as was one scenario where the SMD just overlapped despite distAtoB+CircleRadius being less than DistAtoC (for SMD was about 82 vs 90)
    elseif (iDistFromAToC > iDistFromBToC and iDistFromAToB < iDistFromAToC) or iDistFromAToB + iCircleRadius*1.2 < iDistFromAToC then
        --LOG('Dist to circle further than target and not in range of circle radius, so returning false')
        return false
    else
        --Unclear so need more precise calculation
        --LOG('Unclear so doing more precise calculation.  iAngleFromAToB - iAngleFromAToC='..(iAngleFromAToB - iAngleFromAToC)..'; ConvertAngleToRadians(iAngleFromAToB - iAngleFromAToC)='..ConvertAngleToRadians(iAngleFromAToB - iAngleFromAToC)..'; math.tan(math.abs(ConvertAngleToRadians(iAngleFromAToB - iAngleFromAToC)))='..math.tan(math.abs(ConvertAngleToRadians(iAngleFromAToB - iAngleFromAToC)))..'; iDistFromAToC='..iDistFromAToC..'; iCircleRadius='..iCircleRadius..'; Calculation result='..math.tan(math.abs(ConvertAngleToRadians(iAngleFromAToB - iAngleFromAToC))) * iDistFromAToC)
        if math.abs(math.tan(ConvertAngleToRadians(iAngleFromAToB - iAngleFromAToC))) * iDistFromAToC <= iCircleRadius then
            --LOG('Are in range so returning true')
            return true
        else
            --LOG('Are out of range so returning false')
            return false
        end
    end
end
function GetAngleDifference(iAngle1, iAngle2)
    --returns the absolute difference between two angles.  Assumes angles are 0-360
    return 180 - math.abs(math.abs(iAngle1 - iAngle2) - 180)
end

function GetDistanceToBuildingEdgeTowardsEngineer(tEngineerPosition, tBuildingPosition, iBuildingSquareRadius)
    --Assumes building is a square, which simplifies the maths; might be a better way of doing this but couldn't figure it out so took the easy option
    local iAngleToEngi = GetAngleFromAToB(tBuildingPosition, tEngineerPosition)
    local iTheta
    if iAngleToEngi <= 45 then
        iTheta = iAngleToEngi
    elseif iAngleToEngi <= 90 then
        iTheta = 90 - iAngleToEngi
    elseif iAngleToEngi <= 135 then
        iTheta = iAngleToEngi - 90
    elseif iAngleToEngi <= 180 then
        iTheta = 180 - iAngleToEngi
    elseif iAngleToEngi <= 225 then
        iTheta = iAngleToEngi - 180
    elseif iAngleToEngi <= 270 then
        iTheta = 270 - iAngleToEngi
    elseif iAngleToEngi <= 315 then
        iTheta = iAngleToEngi - 270
    else
        iTheta = 360 - iAngleToEngi
    end

    return iBuildingSquareRadius / math.cos(ConvertAngleToRadians(iTheta))
end

function ConvertCounterclockwisePercentageToAngle(iPercent)
    --Assumes it is sent a percent where 0 = south, 50% = north, 25% = east, and we want 0 = north, 25% = east, 50% = south
    local iBaseAngle = (1-iPercent) * 360 - 180
    if iBaseAngle < 0 then
        iBaseAngle = iBaseAngle + 360
        if iBaseAngle < 0 then
            local iCount = 1
            while iBaseAngle < 0 do
                iBaseAngle = iBaseAngle + 360
                iCount = iCount + 1
                if iCount >= 10 then ErrorHandler('Infinite loop') break end
            end
        end
    end
    return iBaseAngle
end

function ConvertAngleToRadians(iAngle)
    return iAngle * math.pi / 180
end

function ConvertRadiansToAngle(iRadians)
    --Assumes radians when converted would result in north being 180 degrees, east 90 degrees, south 0 degrees, west 270 degrees

    --iRadians = iAngle * math.pi / 180
    --180 * iRadians = iAngle * math.pi
    --iAngle = 180 * iRadians / math.pi
    local iAngle = 360 - (180 * iRadians / math.pi) - 180
    if iAngle < 0 then iAngle = iAngle + 360 end
    return iAngle
end

function GetAngleDifference(iAngle1, iAngle2)
    --returns positive value from 0 to 180 for the difference between two positions (i.e. if turn by the angle closest to there)
    local iAngleDif = math.abs(iAngle1 - iAngle2)
    if iAngleDif > 180 then iAngleDif = math.abs(iAngleDif - 360) end
    return iAngleDif
end

function GetAngleFromAToB(tLocA, tLocB)
    --Returns an angle 0 = north, 90 = east, etc. based on direction of tLocB from tLocA
    local iTheta
    if tLocA[1] == tLocB[1] then
        --Will get infinite if try and use this; is [3] the same?
        if tLocA[3] >= tLocB[3] then --Start is below end, so End is north of start (or LocA == LocB and want 0)
            iTheta = 0
        else
            --Start Z value is lower than end, so start is above end, so if facing end from start we are facing south
            iTheta = 180
        end
    elseif tLocA[3] == tLocB[3] then
        --Have dif in X values but not Z values, so moving in straight line east or west:
        if tLocA[1] < tLocB[1] then --Start is to left of end, so if facing end from start we are facing 90 degrees (Moving east)
            iTheta = 90
        else --must be moving west
            iTheta = 270
        end
    else
        iTheta = math.atan(math.abs(tLocA[3] - tLocB[3]) / math.abs(tLocA[1] - tLocB[1])) * 180 / math.pi
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
    return iTheta
end

function MoveInDirection(tStart, iAngle, iDistance, bKeepInMapBounds, bTravelUnderwater)
    --iAngle: 0 = north, 90 = east, etc.; use GetAngleFromAToB if need angle from 2 positions
    --tStart = {x,y,z} (y isnt used)
    --if bKeepInMapBounds is true then will limit to map bounds
    --bTravelUnderwater - if true then will get the terrain height instead of the surface height

    --local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    --local sFunctionRef = 'MoveInDirection'
    local iTheta
    --local iFactor

    --[[if iAngle > 360 then
        iAngle = iAngle - 360
    elseif iAngle < 0 then iAngle = iAngle + 360 end

    if iAngle >= 270 then iTheta = iAngle - 270 iFactor = {-1,-1}
    elseif iAngle >= 180 then iTheta = 270 - iAngle iFactor = {-1, 1}
    elseif iAngle >= 90 then iTheta = iAngle - 90 iFactor = {1, 1}
    else iTheta = 90 - iAngle iFactor = {1, -1}
    end--]]

    iTheta = ConvertAngleToRadians(iAngle)
    --if bDebugMessages == true then LOG(sFunctionRef..': iAngle='..(iAngle or 'nil')..'; iTheta='..(iTheta or 'nil')..'; iDistance='..(iDistance or 'nil')) end
    local iXAdj = math.sin(iTheta) * iDistance
    local iZAdj = -(math.cos(iTheta) * iDistance)
    --local iXAdj = math.cos(iTheta) * iDistance * iFactor[1]
    --local iZAdj = math.sin(iTheta) * iDistance * iFactor[2]


    if not(bKeepInMapBounds) then
        --if bDebugMessages == true then LOG(sFunctionRef..': Are within map bounds, iXAdj='..iXAdj..'; iZAdj='..iZAdj..'; iTheta='..iTheta..'; position='..repru({tStart[1] + iXAdj, GetSurfaceHeight(tStart[1] + iXAdj, tStart[3] + iZAdj), tStart[3] + iZAdj})) end
        if bTravelUnderwater then
            return {tStart[1] + iXAdj, GetTerrainHeight(tStart[1] + iXAdj, tStart[3] + iZAdj), tStart[3] + iZAdj}
        else
            return {tStart[1] + iXAdj, GetSurfaceHeight(tStart[1] + iXAdj, tStart[3] + iZAdj), tStart[3] + iZAdj}
        end
    else
        local tTargetPosition
        if bTravelUnderwater then
            tTargetPosition = {tStart[1] + iXAdj, GetTerrainHeight(tStart[1] + iXAdj, tStart[3] + iZAdj), tStart[3] + iZAdj}
        else
            tTargetPosition = {tStart[1] + iXAdj, GetSurfaceHeight(tStart[1] + iXAdj, tStart[3] + iZAdj), tStart[3] + iZAdj}
        end
        --Get actual distance required to keep within map bounds
        --local iMaxDistanceFlat = 0
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

function MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
    --Returns the position that want to move iDistanceToTravel along the path from tStartPos to tTargetPos, ignoring height
    --iAngle: 0 = straight line; 90 and 270: right angle to the direction; 180 - opposite direction
    --For now as I'm too lazy to do the basic maths, iAngle must be 0, 90, 180 or 270

    --NOTE: Since converting to radians are having an issue with this not working, have therefore replaced code with the new moveindirection
    return MoveInDirection(tStartPos, GetAngleFromAToB(tStartPos, tTargetPos) + iAngle, iDistanceToTravel, true)

    --OLD CODE BELOW

    --local rad = math.atan2(tLocation[1] - tBuilderLocation[1], tLocation[3] - tBuilderLocation[3])
    --local iBaseAngle = math.atan((tStartPos[1] - tTargetPos[1])/ (tStartPos[3] - tTargetPos[3]))
    --[[local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MoveTowardsTarget'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    if iAngle == nil then iAngle = 0 end
    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
    local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]

    local iBaseAngle = math.atan((tStartPos[1] - tTargetPos[1])/ (tStartPos[3] - tTargetPos[3]))
    local iTheta = ConvertAngleToRadians(iBaseAngle)
    local iXChangeBase = math.sin(iTheta) * iDistanceToTravel
    local iZChangeBase = math.cos(iTheta) * iDistanceToTravel
    local iXMod = 1
    local iZMod = 1


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
        LOG(sFunctionRef..': tTargetPos='..repru(tTargetPos)..'; tStartPos='..repru(tStartPos)..'; iAngle='..iAngle..'; iDistanceToTravel='..iDistanceToTravel..'; NewPos=XZ='..iXPos..','..iZPos)
        DrawLocations({{ iXPos, GetTerrainHeight(iXPos, iZPos), iZPos }, tStartPos, tTargetPos})
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, about to return value') end
    return { iXPos, GetTerrainHeight(iXPos, iZPos), iZPos }
    --]]
end

function GetEdgeOfMapInDirection(tStart, iAngle)
    --Moves from tStart in iAngle, until reaches the edge of the playable area (or within 2 of the edge), and returns this position
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetEdgeOfMapInDirection'
    FunctionProfiler(sFunctionRef, refProfilerStart)

    local iCurInterval = math.max(M27MapInfo.rMapPlayableArea[3] - M27MapInfo.rMapPlayableArea[1], M27MapInfo.rMapPlayableArea[4] - M27MapInfo.rMapPlayableArea[2])
    local tInBounds = {tStart[1], tStart[2], tStart[3]}
    local tOutBounds = MoveInDirection(tStart, iAngle, iCurInterval, false)
    local iDifInDist = GetDistanceBetweenPositions(tInBounds, tOutBounds)
    local tMidpoint
    local bIsInBounds
    if bDebugMessages == true then LOG(sFunctionRef..': Pre start of loop, tStart='..repru(tStart)..'; tInBounds='..repru(tInBounds)..'; tOutBounds='..repru(tOutBounds)..'; iCurInterval='..iCurInterval..'; iAngle='..iAngle..'; iDifInDist='..iDifInDist..'; Playablearea='..repru(M27MapInfo.rMapPlayableArea)) end
    local iCycleCount = 0
    while iDifInDist > 2 do
        iCycleCount = iCycleCount + 1
        if iCycleCount > 1000 then ErrorHandler('Infinite loop') break end

        tMidpoint = MoveInDirection(tInBounds, iAngle, iDifInDist * 0.5, false)
        --Is this in or out of bounds?
        bIsInBounds = true
        if tMidpoint[1] < M27MapInfo.rMapPlayableArea[1] or tMidpoint[1] > M27MapInfo.rMapPlayableArea[3] or tMidpoint[3] < M27MapInfo.rMapPlayableArea[2] or tMidpoint[3] > M27MapInfo.rMapPlayableArea[4] then
            bIsInBounds = false
        end
        if bIsInBounds then tInBounds = tMidpoint
        else tOutBounds = tMidpoint
        end
        iDifInDist = GetDistanceBetweenPositions(tInBounds, tOutBounds)
        if bDebugMessages == true then LOG(sFunctionRef..': iCycleCount='..iCycleCount..'; tInBounds='..repru(tInBounds)..'; tOutBounds='..repru(tOutBounds)..'; iDifInDist='..iDifInDist..'; tMidpoint='..repru(tMidpoint)..'; bIsInBounds='..tostring(bIsInBounds)) end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, returning tInBounds='..repru(tInBounds)) end
    FunctionProfiler(sFunctionRef, refProfilerEnd)
    return tInBounds
end

function GetAIBrainArmyNumber(aiBrain)
    --note - this is different to aiBrain:GetArmyIndex() which returns the army index; e.g. if 2 players, will have army index 1 and 2; however if 4 start positions, then might have ARMY_2 and ARMY_4 for those 2 players
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    if aiBrain then
        --For reference - all the attempts using string.sub to get the last 2 digits - gave up in the end and used gsub
        --if bDebugMessages == true then LOG('GetAIBrainArmyNumber: aiBrain.Name='..aiBrain.Name..'; string.sub5='..string.sub(aiBrain.Name, (string.len(aiBrain.Name)-5))..'; string.sub7='..string.sub(aiBrain.Name, (string.len(aiBrain.Name)-7))..'; string.sub custom='..string.sub(aiBrain.Name, 6, string.len(aiBrain.Name) - 6)..'string.sub custom2='..string.sub(aiBrain.Name, 6, 1)..'; sub custom3='..string.sub(aiBrain.Name, 6, 2)..'; tostring'..string.sub(tostring(aiBrain.Name), 3, 2)..'; gsub='..string.gsub(aiBrain.Name, 'ARMY_', '')) end

        local sArmyNumber = string.gsub(aiBrain.Name, 'ARMY_', '')
        if bDebugMessages == true then LOG('GetAIBrainArmyNumber: Start of code. sArmyNumber='..sArmyNumber..'; M27MapInfo.bUsingArmyIndexForStartPosition='..tostring(M27MapInfo.bUsingArmyIndexForStartPosition)) end
        if not(M27MapInfo.bUsingArmyIndexForStartPosition) then
            if string.len(sArmyNumber) <= 2 then
                if M27MapInfo.bUsingArmyIndexForStartPosition then
                    ErrorHandler('Some brains are using numerical army indexes, others arent, will lead to errors; Brain name='..aiBrain.Name..'; will just use army index')
                    return aiBrain:GetArmyIndex()
                else
                    M27MapInfo.bUsingArmyIndexForStartPosition = false
                end
                return tonumber(sArmyNumber)
            end
        end
        if not(M27MapInfo.bUsingArmyIndexForStartPosition) then
            --Is this a non-civilian brain?
            if not(M27Logic.IsCivilianBrain(aiBrain)) or aiBrain[M27Overseer.refbNoEnemies] then
                ErrorHandler('Army reference for '..aiBrain.Name..' doesnt use numbers (or we have no enemies and are considering civilians), so will overwrite all brains start position number to be the army index number and hten use armyindex going forwards', true)
                M27MapInfo.bUsingArmyIndexForStartPosition = true
                for iBrain, oBrain in ArmyBrains do
                    oBrain.M27StartPositionNumber = oBrain:GetArmyIndex()
                end
            end
        end
        return aiBrain:GetArmyIndex()
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
    local sFunctionRef = 'GetACU'
    FunctionProfiler(sFunctionRef, refProfilerStart)
    function GetSubstituteACU(aiBrain)
        --Get substitute
        local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
        local tSubstitutes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryAirFactory + M27UnitInfo.refCategoryLandFactory, false, true)
        if IsTableEmpty(tSubstitutes) then
            tSubstitutes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryEngineer, false, true)
            if IsTableEmpty(tSubstitutes) then
                tSubstitutes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryStructure, false, true)
                if IsTableEmpty(tSubstitutes) then
                    tSubstitutes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryMobileLand, false, true)
                end
            end
        end
        if IsTableEmpty(tSubstitutes) then
            if not(M27Logic.IsCivilianBrain(aiBrain)) then
                --(if dealing with a civilian brian might be because have no enemies, hence only do the below if its a civilian brain)
                ErrorHandler('Dont have a valid substitute ACU so will treat aiBrain '..aiBrain:GetArmyIndex()..' as being defeated unless it is a civilian brain')
                M27Events.OnPlayerDefeated(aiBrain)
            end
        else
            aiBrain[M27Overseer.refoStartingACU] = GetNearestUnit(tSubstitutes, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain)
            if not(aiBrain[M27Overseer.refoStartingACU] and not(aiBrain[M27Overseer.refoStartingACU].Dead)) then
                --Retry with all of above categories
                aiBrain[M27Overseer.refoStartingACU] = GetNearestUnit(aiBrain:GetListOfUnits(M27UnitInfo.refCategoryStructure + M27UnitInfo.refCategoryMobileLand, false, true), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain)
                if not(aiBrain[M27Overseer.refoStartingACU] and not(aiBrain[M27Overseer.refoStartingACU].Dead)) then
                    ErrorHandler('Dont have a valid substitute ACU, will treat aiBrain '..aiBrain:GetArmyIndex()..' as being defeated')
                    M27Events.OnPlayerDefeated(aiBrain)
                end
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
                    ErrorHandler('Cant find any ACUs that we own for brain'..aiBrain:GetArmyIndex()..', and in assassination game mode, so will treat us as being defeated')
                    M27Events.OnPlayerDefeated(aiBrain)
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
                FunctionProfiler(sFunctionRef, refProfilerEnd)
                WaitSeconds(1)
                FunctionProfiler(sFunctionRef, refProfilerStart)
                FunctionProfiler(sFunctionRef, refProfilerEnd)
                return GetACU(aiBrain)
            else
                --is an error where if return the ACU then causes a hard crash (due to some of hte code that relies on this) - easiest way is to just return nil causing an error message that doesnt cause a hard crash
                --(have tested without waiting any seconds and it avoids the hard crash, but waiting just to be safe)
                --ErrorHandler('ACU is dead - will wait 1 second and then return nil', true)
                --WaitSeconds(1)
                --ErrorHandler('ACU is dead - finished waiting 1 second to try and avoid crash', true)
                M27Overseer.iACUAlternativeFailureCount = M27Overseer.iACUAlternativeFailureCount + 1
                if ScenarioInfo.Options.Victory == "demoralization" then
                    ErrorHandler('ACU is dead for brain'..aiBrain:GetArmyIndex()..', will return nil as are in assassination; M27Overseer.iACUAlternativeFailureCount='..M27Overseer.iACUAlternativeFailureCount)
                    M27Events.OnPlayerDefeated(aiBrain)
                elseif aiBrain:IsDefeated() then
                    ErrorHandler('AI brain '..aiBrain:GetArmyIndex()..' is showing as defeated; M27Overseer.iACUAlternativeFailureCount='..M27Overseer.iACUAlternativeFailureCount..'; Brain.M27IsDefeated='..tostring(aiBrain.M27IsDefeated or false))
                    M27Events.OnPlayerDefeated(aiBrain)
                else
                    ErrorHandler('ACU is dead for brain'..aiBrain:GetArmyIndex()..', so will try and get a substitute as arent in assassination; M27Overseer.iACUAlternativeFailureCount='..M27Overseer.iACUAlternativeFailureCount, true)
                    GetSubstituteACU(aiBrain)
                end
            end
        elseif aiBrain[M27Overseer.refoStartingACU]['M27ACUSubstitute'] and aiBrain:IsDefeated() then
            ErrorHandler('aiBrain '..aiBrain:GetArmyIndex()..' is showing as having been defeated. .M27isDefeated='..tostring(aiBrain.M27IsDefeated or false))
            M27Events.OnPlayerDefeated(aiBrain)
        end
    end
    if aiBrain.M27IsDefeated then aiBrain[M27Overseer.refoStartingACU] = nil end
    FunctionProfiler(sFunctionRef, refProfilerEnd)
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

function IsUnitVisibleSEEBELOW()  end --To help with finding canseeunit
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
            if not(oUnit.GetBlip) then
                ErrorHandler('oUnit with UnitID='..(oUnit.UnitId or 'nil')..' has no blip, will assume can see it')
                return true
            else
                local oBlip = oUnit:GetBlip(iArmyIndex)
                if oBlip then
                    if bTrueIfOnlySeeBlip then return true
                    elseif oBlip:IsSeenEver(iArmyIndex) then return true end
                end
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

function EveryFunctionHook()
    local sName = tostring(debug.getinfo(2, "n").name)
    if sName then tFunctionCallByName[sName] = (tFunctionCallByName[sName] or 0) + 1 end
    iFunctionCurCount = iFunctionCurCount + 1
    if iFunctionCurCount >= 250 then
        iFunctionCurCount = 0
        LOG('Every function hook: tFunctionCallByName='..repru(tFunctionCallByName)..'; sName='..(sName or 'nil')..'; Name='..tostring(debug.getinfo(2, "n").name))
    end
end

function OutputRecentFunctionCalls(sRef, iCycleSize)
--NOTE: Insert below commented out code into e.g. the overseer for the second that want it.  Also can adjust the threshold for iFunctionCurCount from 10000, but if setting to 1 then only do for an individual tick or likely will crash the game
    --[[if not(bSetHook) and GetGameTimeSeconds() >= 1459 then
        bDebugMessages = true
        bSetHook = true
        M27Utilities.bGlobalDebugOverride = true
        --debug.sethook(M27Utilities.AllFunctionHook, "c", 200)
        debug.sethook(M27Utilities.OutputRecentFunctionCalls, "c", 1)
    end--]]

    local sName = tostring(debug.getinfo(2, "n").name)
    if sName then tFunctionCallByName[sName] = (tFunctionCallByName[sName] or 0) + 1 end
    iFunctionCurCount = iFunctionCurCount + 1
    if iFunctionCurCount >= iCycleSize then
        iFunctionCurCount = 0
        LOG('Every function hook: tFunctionCallByName='..repru(tFunctionCallByName))
        tFunctionCallByName = {}
    end
end

function AllFunctionHook()
    --local tInfo = debug.getinfo(1,"n")
    --if tInfo.name or tInfo['name'] then LOG('AllFunctionHook: '..repru(tInfo)) end
    --if debug.getinfo(1,"n").name then LOG('AllFunctionHook: Name='.. debug.getinfo(1,"n").name) end
    --LOG('AllFunctionHook: '..repru(debug.getinfo(2,"n")))
    LOG('Table of functions by count='..repru(tFunctionCallByName)..' cur function='..repru(debug.getinfo(2, "n"))..'; name='..tostring(debug.getinfo(2, "n").name))
    tFunctionCallByName[tostring(debug.getinfo(2, "n").name)] = (tFunctionCallByName[tostring(debug.getinfo(2, "n").name)] or 0) + 1
    LOG('tFunctionCallByName='..repru(tFunctionCallByName))
end

function FunctionProfiler(sFunctionRef, sStartOrEndRef)
    --sStartOrEndRef: refProfilerStart or refProfilerEnd (0 or 1)
    local bDebugMessages = false if bGlobalDebugOverride == true then   bDebugMessages = true end
    if bDebugMessages == true then LOG('FunctionProfiler: Function '..sFunctionRef..'; sStartOrEndRef='..sStartOrEndRef) end
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
            if tProfilerStartCount[sFunctionRef] then --needed to support e.g. running this part-way through the game
                tProfilerEndCount[sFunctionRef] = (tProfilerEndCount[sFunctionRef] or 0) + 1
                local iCount = tProfilerEndCount[sFunctionRef]
                local iGameTimeInTicks = math.floor(GetGameTimeSeconds()*10)
                if tProfilerFunctionStart[sFunctionRef][iCount] == nil then
                    ErrorHandler('Didnt record a start for this count.  Will assume the start time was equal to the previous count, and will increase the start count by 1 to try and align.  sFunctionRef='..sFunctionRef..'; iGameTimeInTicks='..iGameTimeInTicks..'; iCount='..(iCount or 'nil'))
                    if not(tProfilerFunctionStart[sFunctionRef]) then tProfilerFunctionStart[sFunctionRef] = {} end
                    if iCount > 1 then
                        for iAdjust = 1, (iCount - 1), 1 do
                            if tProfilerFunctionStart[sFunctionRef][iCount - iAdjust] then
                                tProfilerFunctionStart[sFunctionRef][iCount] = tProfilerFunctionStart[sFunctionRef][iCount - iAdjust]
                                break
                            end
                        end
                    end
                    if not(tProfilerFunctionStart[sFunctionRef][iCount]) then
                        tProfilerFunctionStart[sFunctionRef][iCount] = 0
                    end
                    tProfilerStartCount[sFunctionRef] = iCount
                end
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
    local sFunctionRef = 'ForkedDelayedChangedVariable'
    FunctionProfiler(sFunctionRef, refProfilerStart)
    FunctionProfiler(sFunctionRef, refProfilerEnd)
    WaitSeconds(iDelayInSeconds)
    FunctionProfiler(sFunctionRef, refProfilerStart)
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
    FunctionProfiler(sFunctionRef, refProfilerEnd)
end

function DelayChangeVariable(oVariableOwner, sVariableName, vVariableValue, iDelayInSeconds, sOptionalOwnerConditionRef, iMustBeLessThanThisTimeValue, iMustBeMoreThanThisTimeValue, vMustNotEqualThisValue)
    --sOptionalOwnerConditionRef - can specify a variable for oVariableOwner; if so then the value of this variable must be <= iMustBeLessThanThisTimeValue
    --e.g. if delay reset a variable, but are claling multiple times so want to only reset on the latest value, then this allows for that
    ForkThread(ForkedDelayedChangedVariable, oVariableOwner, sVariableName, vVariableValue, iDelayInSeconds, sOptionalOwnerConditionRef, iMustBeLessThanThisTimeValue, iMustBeMoreThanThisTimeValue, vMustNotEqualThisValue)
end

function ForkedDelayedChangedSubtable(oVariableOwner, sPrimaryRef, vSubtable1Ref, vSubtable2Ref, iVariableChange, iDelayInSeconds)
    local sFunctionRef = 'ForkedDelayedChangedSubtable'
    FunctionProfiler(sFunctionRef, refProfilerStart)
    FunctionProfiler(sFunctionRef, refProfilerEnd)
    WaitSeconds(iDelayInSeconds)
    FunctionProfiler(sFunctionRef, refProfilerStart)
    if oVariableOwner and oVariableOwner[sPrimaryRef] and oVariableOwner[sPrimaryRef][vSubtable1Ref] then
        oVariableOwner[sPrimaryRef][vSubtable1Ref][vSubtable2Ref] = (oVariableOwner[vSubtable1Ref][vSubtable2Ref] or 0) + iVariableChange
    end
    FunctionProfiler(sFunctionRef, refProfilerEnd)
end

function DelayChangeSubtable(oVariableOwner, sPrimaryRef, vSubtable1Ref, vSubtable2Ref, iVariableChange, iDelayInSeconds)
    ForkThread(ForkedDelayedChangedSubtable, oVariableOwner, sPrimaryRef, vSubtable1Ref, vSubtable2Ref, iVariableChange, iDelayInSeconds)
end


function DebugArray(Table)
    --Thanks to Uveso who gave me this as a solution for doing a repr of a large table such as a unit or aiBrain that would normally crash the game
    --Note - largely superceded by Jip introducing reprs()
    for Index, Array in Table do
        if type(Array) == 'thread' or type(Array) == 'userdata' then
            LOG('Index['..Index..'] is type('..type(Array)..'). I wont print that!')
        elseif type(Array) == 'table' then
            LOG('Index['..Index..'] is type('..type(Array)..'). I wont print that!')
        else
            LOG('Index['..Index..'] is type('..type(Array)..'). "', repru(Array),'".')
        end
    end
end

function DoesCategoryContainCategory(iCategoryWanted, iCategoryToSearch, bOnlyContainsThisCategory)
    --Not very efficient so consider alternative such as recording variables if going to be running lots of times
    local tsUnitIDs = EntityCategoryGetUnitList(iCategoryToSearch)
    if bOnlyContainsThisCategory then
        for iRef, sRef in tsUnitIDs do
            if not(EntityCategoryContains(iCategoryWanted, sRef)) then return false end
        end
        return true
    else
        for iRef, sRef in tsUnitIDs do
            if EntityCategoryContains(iCategoryWanted, sRef) then return true end
        end
    end
end


--Thanks to Softles for this code, which is intended to help manage the number of functions being called in a particular tick/spread them out over time to give a smoother performance
--Softles: To use, it is as simple as calling local ticksWaited = _G.MyScheduler:WaitTicks(minWait, maxWait, cost), where you choose the cost based on how you want things to be spread across ticks (i.e. higher cost, less other stuff that tick).  Where minWait and maxWait are identical it just waits that amount, but it knows to move other things if possible.
M27Scheduler = Class({
    Init = function(self)
        -- Edit these two flags as you see fit
        self.trainingWheels = false
        self.logging = false

        -- Internal state, be careful when touching.  I highly recommend just using the interface functions.
        self.lastTick = 0
        self.totalCost = 0
        self.totalWait = 0
        self.meanCost = 0
        self.workQueue = {}
        self.workQueueLength = 0
        self.logs = {}
        self.numLogs = 0

        -- Behaviour modification stuff
        self.safetyModifier = 1.1
        self.loggingRate = 50
    end,

    AddStats = function(self, numItems, totalCost)
        self.numLogs = self.numLogs + 1
        self.logs[self.numLogs] = {totalCost, numItems}
    end,

    LogStats = function(self)
        -- Log Queue Length, Remaining Cost, Queue Waits, Min/Mean/Max work in logs, Min/Mean/Max items in logs
        local work = {self.logs[1][1],self.logs[1][1],self.logs[1][1]}
        local items = {self.logs[1][2],self.logs[1][2],self.logs[1][2]}
        for i=2, self.numLogs do
            local w = self.logs[i][1]
            local k = self.logs[i][2]
            work[2] = work[2] + w
            items[2] = items[2] + k
            if w > work[3] then
                work[3] = w
            elseif w < work[1] then
                work[1] = w
            end
            if k > items[3] then
                items[3] = k
            elseif k < items[1] then
                items[1] = k
            end
        end
        _ALERT("M27Scheduler Stats - Size:", self.workQueueLength, "In the last "..tostring(self.loggingRate).." ticks:",
                "Work (Min/Mean/Max/Total):", tostring(work[1]).."/"..tostring(work[2]/self.numLogs).."/"..tostring(work[3]).."/"..tostring(work[2]),
                "Items (Min/Mean/Max/Total):", tostring(items[1]).."/"..tostring(items[2]/self.numLogs).."/"..tostring(items[3]).."/"..tostring(items[2]))
        self.logs = {}
        self.numLogs = 0
    end,

    RemoveWork = function(self, i)
        local item = self.workQueue[i]
        -- Update own state
        self.workQueue[i] = self.workQueue[self.workQueueLength]
        self.workQueue[self.workQueueLength] = nil
        self.workQueueLength = self.workQueueLength - 1
        self.totalCost = self.totalCost - cost
        self.totalWait = self.totalWait - item[2] + item[1] - 1
    end,

    CheckTick = function(self)
        -- If the tick hasn't changed, then skip.
        if self.lastTick == GetGameTick() then
            return
        end
        -- New tick, firstly update our own state
        self.lastTick = GetGameTick()
        if self.logging and (math.mod(self.lastTick, self.loggingRate) == 0) then
            self:LogStats()
        end
        -- Sort work items, makes choosing stuff to do this tick more efficient later.
        table.sort(self.workQueue, function(a,b) return a[3] < b[3] end)

        -- Determine how much work we need to do to keep up.
        local desiredWork = self.safetyModifier * self.meanCost

        -- Now pick things to run this tick.  The algorithm here is pretty basic, but works as a quick starter.
        local workThisTick = 0
        local itemsThisTick = 0
        -- Step 1: Whatever has to be done this tick specifically
        local i = 1
        while i <= self.workQueueLength do
            if self.workQueue[i][2] == self.lastTick then
                self.workQueue[i][4] = true
                workThisTick = workThisTick + self.workQueue[i][3]
                itemsThisTick = itemsThisTick + 1
            end
            i = i+1
        end
        -- Step 2: Fill up to desired work amount with most expensive items first
        i = 1
        while (i <= self.workQueueLength) do
            local item = self.workQueue[i]
            if (not item[4]) and (self.lastTick >= item[1]) and (item[3] + workThisTick < desiredWork) then
                item[4] = true
                workThisTick = workThisTick + item[3]
                itemsThisTick = itemsThisTick + 1
            end
            i = i+1
        end
        -- Step 3: Clean up items we've completed
        i = 1
        while (i <= self.workQueueLength) do
            if self.workQueue[i][4] then
                local item = self.workQueue[i]
                self.workQueue[i] = self.workQueue[self.workQueueLength]
                self.workQueue[self.workQueueLength] = nil
                self.workQueueLength = self.workQueueLength - 1
                self.totalCost = self.totalCost - item[3]
                self.totalWait = self.totalWait - item[2] + item[1] - 1
                self.meanCost = self.meanCost - item[5]
            else
                i = i+1
            end
        end
        if self.logging then
            self:AddStats(itemsThisTick, workThisTick)
        end
    end,

    AddWork = function(self, earliest, latest, cost)
        -- Add an item of work
        item = {earliest, latest, cost, false, cost/(latest-earliest+1)}
        self.workQueueLength = self.workQueueLength + 1
        self.workQueue[self.workQueueLength] = item
        self.totalCost = self.totalCost + cost
        self.totalWait = self.totalWait + latest - earliest + 1
        self.meanCost = self.meanCost + item[5]
        return item
    end,

    WaitTicks = function(self, minTicksToWait, maxTicksToWait, costOfFunction)
        -- Wait at least minTicksToWait, and at most maxTicksToWait.
        if self.trainingWheels and ((minTicksToWait > maxTicksToWait) or (minTicksToWait <= 0) or (costOfFunction <= 0)) then
            -- Bad things might happen, so handle these cases gracefully (or throw a tantrum, idk).
            WARN("M27Scheduler.WaitTicks called with bad arguments, waiting 100 ticks and returning in order to punish you.")
            WaitTicks(100)
            return 100
        end
        local ticksWaited = 0
        self:CheckTick()
        local item = self:AddWork(self.lastTick+minTicksToWait, self.lastTick+maxTicksToWait, costOfFunction)
        while not item[4] do
            WaitTicks(1)
            ticksWaited = ticksWaited+1
            --if GetGameTimeSeconds() >= 2455 then bGlobalDebugOverride = true M27Config.M27ShowUnitNames = true end
            self:CheckTick()
        end
        return ticksWaited
    end,
})

_G.MyM27Scheduler = M27Scheduler()
_G.MyM27Scheduler:Init()

function Test()
    -- Stick this function into sim init to test the M27Scheduler
    ForkThread(
            function()
                coroutine.yield(10)
                -- Spawn 30 random cost things
                for i=1, 30 do
                    ForkThread(
                            function()
                                local w0 = Random(1,10)
                                local w1 = Random(1,10)
                                local cost = Random(1,10)
                                while true do
                                    _G.MyM27Scheduler:WaitTicks(math.min(w0,w1),math.max(w0,w1),cost)
                                end
                            end
                    )
                end
                -- Spawn 10 slightly more expensive, fixed time things
                for i=1, 10 do
                    ForkThread(
                            function()
                                local w = Random(5,10)
                                while true do
                                    _G.MyM27Scheduler:WaitTicks(w,w,20)
                                end
                            end
                    )
                end
                -- Spawn 1 very expensive thing
                ForkThread(
                        function()
                            while true do
                                _G.MyM27Scheduler:WaitTicks(1,Random(5,10),200)
                            end
                        end
                )
            end
    )
end

function IssueTrackedClearCommands(tUnits)
    --Intended so we can add logging to make it easier to confirm if we are clearing a unit's orders
    --Below is example if want to give an alert in the log when a unit has its orders cleared
    if tUnits[1].UnitId == 'url01053' and GetGameTimeSeconds() >= 180 then
        for iUnit, oUnit in tUnits do
            --if oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit) == 'uel01052' or oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit) == 'uel01054' or oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit) == 'uel01055' or oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit) == 'uel010516' then
                LOG('About to issue clear commands for unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' with unit state='..M27Logic.GetUnitState(oUnit))
                ErrorHandler('Audit trail game time='..GetGameTimeSeconds(), true)
            --end
        end
    end--]]
    --if GetGameTimeSeconds() >= 230 and tUnits[1].UnitId and tUnits[1].UnitId..M27UnitInfo.GetUnitLifetimeCount(tUnits[1]) == 'drl02043' then ErrorHandler('Audit trail game time='..GetGameTimeSeconds()) end


    IssueClearCommands(tUnits)
end
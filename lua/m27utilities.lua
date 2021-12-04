

local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')

bGlobalDebugOverride = false

function ErrorHandler(sErrorMessage, iOptionalWaitInSeconds, bWarningNotError)
    --Intended to be put in code wherever a condition isn't met that should be, so can debug it without the code crashing
    if sErrorMessage == nil then sErrorMessage = 'Not specified' end
    local sErrorBase = 'M27ERROR: '
    if bWarningNotError then sErrorBase = 'M27WARNING: ' end
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

function SortTableByValue(tTableToSort, bLowToHigh)
    if bLowToHigh then return spairs(tTableToSort, function(t,a,b) return t[b] < t[a] end)
    else return spairs(tTableToSort, function(t,a,b) return t[b] > t[a] end)
    end
end


function DrawTableOfLocations(tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation, iCircleSize)
    --Draw circles around a table of locations to help with debugging - note that as this doesnt use ForkThread (might need to have global variables and no function pulled variables for forkthread to work beyond the first few seconds) this will pause all the AI code
    --If a table (i.e. bSingleLocation is false), then will draw lines between each position
    --All values are optional other than tableLocations
    --if relativeStart is blank then will treat as absolute co-ordinates
    --assumes tableLocations[x][y] where y is table of 3 values
    -- iColour: integer to allow easy selection of different colours (see below code)
    -- iDisplayCount - No. of times to cycle through drawing; limit of 500 (10s) for performance reasons
    --bSingleLocation - true if tableLocations is just 1 position
    local bDebugMessages = false if bGlobalDebugOverride == true then bDebugMessages = true end
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
    elseif iColour == 6 then sColour = 'ff1e90ff' --Cyan
    elseif iColour == 7 then sColour = 'ffffffff' --white
    else sColour = 'ffFF6060' --Orangy pink
    end


    if relativeStart == nil then relativeStart = {0,0,0} end
    local iMaxDrawCount = iDisplayCount
    local iCurDrawCount = 0
    if bDebugMessages == true then LOG('About to draw circle at table locations') end
    local bFirstLocation = true
    local tPrevLocation = {}
    local iCount = 0
    while true do
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

function DrawRectBase(rRect, iColour, iDisplayCount)
    --Draws lines around rRect; rRect should be a rect table, with keys x0, x1, y0, y1
    local bDebugMessages = false if bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'DrawRectBase'
    if bDebugMessages == true then LOG(sFunctionRef..': rRect='..repr(rRect)) end
    local sColour
    if iColour == nil then sColour = 'c00000FF' --dark blue
    elseif iColour == 1 then sColour = 'c00000FF' --dark blue
    elseif iColour == 2 then sColour = 'ffFF4040' --Red
    elseif iColour == 3 then sColour = 'c0000000' --Black (can be hard to see on some maps)
    elseif iColour == 4 then sColour = 'fff4a460' --Gold
    elseif iColour == 5 then sColour = 'ff27408b' --Light Blue
    elseif iColour == 6 then sColour = 'ff1e90ff' --Cyan
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
        iCount = iCount + 1 if iCount > 200 then ErrorHandler('Infinite loop') break end
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

function DrawLocations(tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation, iCircleSize)
    --fork thread doesnt seem to work - can't see the circle, even though teh code itself is called; using steppingstone seems to fix this
    --ForkThread(DrawTableOfLocations, tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation)
    --DrawTableOfLocations(tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation)
    ForkThread(SteppingStoneForDrawLocations, tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation, iCircleSize)
end

function DrawLocation(tLocation, relativeStart, iColour, iDisplayCount, iCircleSize)
    --ForkThread(DrawTableOfLocations, tableLocations, relativeStart, iColour, iDisplayCount, true)
    --DrawTableOfLocations(tableLocations, relativeStart, iColour, iDisplayCount, true)
    ForkThread(SteppingStoneForDrawLocations, tLocation, relativeStart, iColour, iDisplayCount, true, iCircleSize)
end

function DrawRectangle(rRect, iColour, iDisplayCount)
    ForkThread(SteppingStoneForDrawRect, rRect, iColour, iDisplayCount)
end


function GetAveragePosition(tUnits)
    --returns a table with the average position of tUnits
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

function GetDistanceBetweenPositions(Position1, Position2, iBuildingSize)
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
    local bDebugMessages = false if bGlobalDebugOverride == true then bDebugMessages = true end
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
    if iDistanceToTravel < 0 then
        if iAngle < 180 then iAngle = iAngle + 180
        else iAngle = iAngle - 180 end
    end

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

function GetAIBrainArmyNumber(aiBrain)
    --note - this is different to aiBrain:GetArmyIndex() which returns the army index; e.g. if 2 players, will have army index 1 and 2; however if 4 start positions, then might have ARMY_2 and ARMY_4 for those 2 players
    local bDebugMessages = false if bGlobalDebugOverride == true then bDebugMessages = true end
    if aiBrain then
        if bDebugMessages == true then LOG('GetAIBrainArmyNumber: aiBrain.Name='..aiBrain.Name) end
        return tonumber(string.sub(aiBrain.Name, (string.len(aiBrain.Name)-7)))
    else
        ErrorHandler('aiBrain is nil')
        return nil
    end
end

function IsACU(oUnit)
    if oUnit.Dead then return false else
        if oUnit.GetUnitId and EntityCategoryContains(categories.COMMAND, oUnit:GetUnitId()) then return true else return false end
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
    local oACU = aiBrain[M27Overseer.refoStartingACU]
    if oACU == nil then
        if aiBrain == nil then
            ErrorHandler('aiBrain not specified - update function call')

        else
            ErrorHandler('ACU hasnt been set')
            --WaitSeconds(30)
            --ErrorHandler('ACU hasnt been set - finished waiting 30 seconds to try and avoid crash, then will return nil')

        end
    else
        if oACU.Dead then
            if GetGameTimeSeconds() <= 10 then
                LOG('WARNING - GetACU failed to find alive AUC in first 10 seconds of game, will keep trying')
                WaitSeconds(1)
                return GetACU(aiBrain)
            else
                --is an error where if return the ACU then causes a hard crash (due to some of hte code that relies on this) - easiest way is to just return nil causing an error message that doesnt cause a hard crash
                --(have tested without waiting any seconds and it avoids the hard crash, but waiting just to be safe)
                ErrorHandler('ACU is dead - will wait 30 seconds and then return nil')
                WaitSeconds(30)
                ErrorHandler('ACU is dead - finished waiting 30 seconds to try and avoid crash')

            end
        end
    end
    return oACU
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
    return 'X'..tLocation[1]..';Z'..tLocation[3]
end

function FactionIndexToCategory(iFactionIndex)
    --returns the categories.[FACTION] for iFactionIndex
    local tCategoryByIndex = {[1] = categories.UEF, [2] = categories.AEON, [3] = categories.CYBRAN, [4] = categories.SERAPHIM, [5] = categories.NOMADS, [6] = categories.ARM, [7] = categories.CORE }
    return tCategoryByIndex[iFactionIndex]
end

function GetFactionNameByIndex(iFactionIndex)
    --e.g. if have oUnitBP, then can check faction name with .General.FactionName
    local tFactionNameByIndex = {[1] = 'UEF', [2]= 'Aeon', [3] = 'Cybran', [4] = 'Seraphim', [5] = 'Nomads'}
    return tFactionNameByIndex[iFactionIndex]
end

function GetUnitsInFactionCategory(aiBrain, category)
    --returns a table of the units that aiBrain's faction that meet category
    --Category is e.g. categories.LAND * categories.DIRECTFIRE (i.e. based on the categories {} data of unit blueprints)

    --local FactionIndexToCategory = {[1] = categories.UEF, [2] = categories.AEON, [3] = categories.CYBRAN, [4] = categories.SERAPHIM, [5] = categories.NOMADS, [6] = categories.ARM, [7] = categories.CORE }
    --[[local bDebugMessages = false if bGlobalDebugOverride == true then bDebugMessages = true end
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

function GetNearestUnit(tUnits, tCurPos, aiBrain, bHostileOnly)
    --returns the nearest unit in tUnits from tCurPos
    --bHostile defaults to false; if true then unit must be hostile
    --aiBrain: Optional unless are setting bHostileOnly to true
    local bDebugMessages = false if bGlobalDebugOverride == true then bDebugMessages = true end
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
        else LOG('Nearest unit ID='..tUnits[iNearestUnit]:GetUnitId())
        end
    end
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
    return math.sqrt(iSquaredDifTotal / iCount)
end

function ProfilerTimeSinceLastCall(sReference, iStartTime)
    --Sends a log with how much time has elapsed, and returns the current time
    if iStartTime == nil then iStartTime = 0 end
    local iTimeNow = GetSystemTimeSecondsOnlyForProfileUse()
    LOG(sReference..': Time elapsed='..iTimeNow-iStartTime)
    return iTimeNow
end


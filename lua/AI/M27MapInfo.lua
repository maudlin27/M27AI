local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua') -- located in the lua.nx2 part of the FAF gamedata
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27FactoryOverseer = import('/mods/M27AI/lua/AI/M27FactoryOverseer.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')


MassPoints = {} -- Stores position of each mass point (as a position value, i.e. a table with 3 values, x, y, z
tMexPointsByLocationRef = {} --As per mass points, but the key is the locationref value, and it returns the position
tMexByPathingAndGrouping = {} --Stores position of each mex based on the segment that it's part of; [a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
tHydroByPathingAndGrouping = {}
HydroPoints = {} -- Stores position values i.e. a table with 3 values, x, y, z
PlayerStartPoints = {} -- Stores position values i.e. a table with 3 values, x, y, z; item 1 = ARMY_1 etc.
tResourceNearStart = {} --[iArmy][iResourceType (1=mex2=hydro)][iCount][tLocation] Stores location of mass extractors and hydrocarbons that are near to start locations; 1st value is the army number, 2nd value the resource type, 3rd the mex number, 4th value the position array (which itself is made up of 3 values)
MassCount = 0 -- used as a way of checking if have the core markers needed
HydroCount = 0
iHighestReclaimInASegment = 0 --WARNING - reference the higher of this and previoushighestreclaiminasegment, since this gets reset to 0 each time
iPreviousHighestReclaimInASegment = 0
refiPreviousThreatPercentCoverage = 'M27MapPreviousThreatPercentCoverage'
refiPreviousFrontUnitPercentFromOurBase = 'M27MapPreviousFrontUnitPercentFromOurBase'
tReclaimAreas = {} --Stores reclaim info for each segment: tReclaimAreas[iSegmentX][iSegmentZ][x]; if x=1 returns total mass in area; if x=2 then returns position of largest reclaim in the area, if x=3 returns how many platoons have been sent here since the game started
refReclaimTotalMass = 1
refReclaimSegmentMidpoint = 2
refReclaimHighestIndividualReclaim = 3
reftReclaimTimeOfLastEngineerDeathByArmyIndex = 4 --Table: [a] where a is the army index, and it returns the time the last engineer died
refReclaimTimeLastEnemySightedByArmyIndex = 5
refsSegmentMidpointLocationRef = 6
refiReclaimTotalPrev = 7 --Previous total reclaim in a segment
--tLastReclaimRefreshByGroup = {} --time that last refreshed reclaim positions for [x] group
iLastReclaimRefresh = 0 --stores time that last refreshed reclaim positions
refiLastRefreshOfReclaimAreasOfInterest = 'M27MapLastRefreshOfReclaim'
refiTotalReclaimAreasOfInterestByPriority = 'M27MapReclaimAreasOfInterestCount' --[1] = total for priority 1, etc.
reftReclaimAreasOfInterest = 'M27MapReclaimAreasOfInterest' --assigned to aiBrain, [1] = priority (1, 2, 3); [2] = {segmentx, segmentz}
reftReclaimAreaPriorityByLocationRef = 'M27MapReclaimAreaPriorityByLocationRef' --key is location ref
iReclaimSegmentSizeX = 0 --Updated separately
iReclaimSegmentSizeZ = 0 --Updated separately
iReclaimAreaOfInterestTickCount = 0 --Updated as part of may reclaim update loop, used to avoid excessive load on an individual tick
bReclaimRefreshActive = false --Used to avoid duplciating reclaim update logic
iMaxSegmentInterval = 1 --Updated by map pathing logic; constant - no. of times to divide the map by segments for X (and separately for Z) so will end up with this value squared as the no. of segments
tManualPathingChecks = {} --[Pathing][LocationRef]; returns true; lists any locations where we have already checked the pathing manually via canpathto
--iSegmentSizeX = 12
--iSegmentSizeZ = 12
--Experience significant slowdown of a couple of seconds at 100 (10k segments), so dont recommend much higher than 60s
--tSegmentGroupBySegment = {} --table [a][b][c] holding the groupings for each segment: [a] = pathing type (Land, etc.); [b] and [c] =  segment X and Z numbers; returns segment group number
tSegmentBySegmentGroup = {} --table holding the segment references in each grouping, split by pathing type:
--local tSegmentGroupAllSegmentsMapped = {} --table [a][b], [a] = pathing type, [b] = group number; returns true if have mapped all segments against the group (i.e. used for reclaim so dont call the reclaim script multiple times)
    --[a][b][c]: a = pathing type ('Land', 'Amphibious', 'Air', 'Water'); b = segment group; c = semgent count (within that group); the result will then be the [x][z] segment numbers
--iMaxGroups = {} --[sPathing] - returns the no. of groups currently have for a given pathing type
iMapTotalMass = 0 --Stores the total mass on the map
--tSegmentGroupReferencePos = {} --Table holding the engineer segment X and Z positions used for the group; e.g. [3][1] returns the X segment for group 3, [3][2] returns the Z position for group 3

tUnmappedMarker = {} --[sPathing][iResource]; iResource: 1=Mex, 2=Hydro, 3=PlayerStart; returns the marker location
refiStartingSegmentGroup = 'M27StartingSegmentGroup' --[sPathingType]  - returns the group number for the given pathing type
reftSortedMexesInOriginalGroup = 'M27SortedMexesInOriginalGroup' --Local to AI Brain, [iPathingGroup][iMexCount], returns mex location; ordered based on how close the mex is to our base and enemy (early entries are closest to our base)
reftMexesInPathingGroupFilteredByDistanceToEnemy = 'M27MexesInPathingGroupFilteredByDistanceToEnemy' --local to aiBrain; [sPathing][iPathingGroup][iMinRangeFromEnemy][iMaxRangeFromEnemy][iMexCount] returns Mex Location
reftHighPriorityMexes = 'M27HighPriorityMexes' --Local to aiBrain, list of mex locations
reftMexesToKeepScoutsBy = 'M27MapMexesToKeepScoutsBy'

--Nearest enemy related
refbCanPathToEnemyBaseWithLand = 'M27MapCanPathToEnemyWithLand' --True if can path to enemy base, false otherwise
refbCanPathToEnemyBaseWithAmphibious = 'M27MapCanPathToEnemyWithAmphibious'

--Rally points and mex patrol locations
reftMexPatrolLocations = 'M27MapMexPatrolLocations' --aiBrain variable, [x] = nth mex will be the locations e.g. top 3 locations to patrol between
reftRallyPoints = 'M27MapRallyPoints' --Location of all valid rally points to send units to - intended to be relatively safe locations closer to enemy base than our base but away from the frontline
reftMexesAndDistanceNearPathToNearestEnemy = 'M27MexesNearPathToNearestEnemy' --]{1,2}; 1 = mex location; 2 =- distance to our base; If do a line from our base to enemy base, this will record all mexes that would represent less than a 20% or 60 distance detour
reftMexLocation = 1
refiDistanceToOurBase = 2
refiLastRallyPointRefresh = 'M27MapLastRallyPointRefresh' --gametimeseconds that last updated our rally points
refiNearestEnemyIndexWhenLastCheckedRallyPoints = 'M27MapNearestEnemyLastRallyPointCheck'

--v3 Pathfinding specific
local iLandPathingGroupForWater = 1
bMapHasWater = true --true or false based on water % of map
bPathfindingAlreadyCommenced = false
bMapDrawingAlreadyCommenced = {}
bPathfindingComplete = false
rMapPlayableArea = 2 --{x1,z1, x2,z2} - Set at start of the game, use instead of the scenarioinfo method
iPathingIntervalSize = 0.5
iLowHeightDifThreshold = 0.007 --Used to trigger check for max height dif in an area
iHeightDifAreaSize = 0.2 --T1 engineer is 0.6 x 0.9, so this results in a 1x1 size box by searching +- iHeightDifAreaSize if this is set to 0.5; however given are using a 0.25 interval size dont want this to be too large or destroys the purpose of the interval size and makes the threshold unrealistic
iMaxHeightDif = 0.115 --NOTE: Map specific code should be added below in DetermineMaxTerrainHeightDif (hardcoded table with overrides by map name); Max dif in height allowed if move iPathingIntervalSize blocks away from current position in a straight line along x or z; Testing across 3 maps (africa, astro crater battles, open palms) a value of viable range across the 3 maps is a value between 0.11-0.119
local iChangeInHeightThreshold = 0.04 --Amount by which to change iMaxHeightDif if we have pathing inconsistencies
iMinWaterDepth = 1 --Ships cant move right up to shore, this is a guess at how much clearance is needed (testing on Africa, depth of 2 leads to some pathable areas being considered unpathable)
iWaterPathingIntervalSize = 1
tWaterAreaAroundTargetAdjustments = {} --Defined in map initialisation
iWaterMinArea = 3 --Square with x/z of this size must be underwater for the target position to be considered pathable; with value of 2 ships cant get as close to shore as expect them to
iBaseLevelSegmentCap = 750 --Max size of segments to use
iMapOutsideBoundSize = 3 --will treat positions within this size of map radius as being unpathable for pathing purposes
iSizeOfBaseLevelSegment = 1 --Is updated by pathfinding code
tPathingSegmentGroupBySegment = {} --[a][b][c]: a = pathing type; b = segment x, c = segment z
iMaxBaseSegmentX = 1 --Will be set by pathing, sets the maximum possible base segment X
iMaxBaseSegmentZ = 1

iMapWaterHeight = 0 --Surface height of water on the map

function DetermineMaxTerrainHeightDif()
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if M27Config.M27ShowPathingGraphically then bDebugMessages = true end
    --Manually specify the terrain height difference to use for certain maps (e.g. where there are ramps and the pathfinding default options return incorrect pathing)
    --To find out the map name, run with 'display pathing graphically' config option set to true, and search for the last entry containing "DetermineMaxTerrainHeightDif: sMapName="
    local sFunctionRef = 'DetermineMaxTerrainHeightDif'

    local tMapHeightOverride = {
    ['serenity desert'] = 0.15,
    ['serenity desert small'] = 0.15,
    ['serenity desert small - FAF version'] = 0.15,
    ['Adaptive Corona'] = 0.15,
    ['Corona'] = 0.15,
    ['Adaptive Flooded Corona'] = 0.15,
    ['Fields of Isis'] = 0.15, --minor for completeness - one of cliffs reclaim looks like its pathable but default settings show it as non-pathable
    }
    local sMapName = ScenarioInfo.name
    iMaxHeightDif = (tMapHeightOverride[sMapName] or iMaxHeightDif)
    if bDebugMessages == true then LOG(sFunctionRef..': sMapName='..sMapName..'; tMapHeightOverride='..(tMapHeightOverride[sMapName] or 'No override')) end
end


function GetPathingSegmentFromPosition(tPosition)
    --Base level segment numbers
    local rPlayableArea = rMapPlayableArea
    local iBaseSegmentSize = iSizeOfBaseLevelSegment
    return math.floor( (tPosition[1] - rPlayableArea[1]) / iBaseSegmentSize) + 1, math.floor((tPosition[3] - rPlayableArea[2]) / iBaseSegmentSize) + 1
end
function GetPositionFromPathingSegments(iSegmentX, iSegmentZ)
    --If given base level segment positions
    local rPlayableArea = rMapPlayableArea

    local iMidPointIncrease = iSizeOfBaseLevelSegment * 0.5
    local x = iSegmentX * iSizeOfBaseLevelSegment - iMidPointIncrease + rPlayableArea[1]
    local z = iSegmentZ * iSizeOfBaseLevelSegment - iMidPointIncrease + rPlayableArea[2]
    return {x, GetTerrainHeight(x, z), z}
end

function RecordResourcePoint(t,x,y,z,size)
    --called by hook into simInit, more reliable method of figuring out if have adaptive map
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordResourcePoint'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': t='..t..'; x='..x..'; y='..y..'; z='..z..'; size='..repr(size)) end

    if t == 'Mass' then
        MassCount = MassCount + 1
        MassPoints[MassCount] = {x,y,z}
    elseif t == 'Hydrocarbon' then
        HydroCount = HydroCount + 1
        HydroPoints[HydroCount] = {x,y,z}
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordResourceLocations(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordResourceLocations'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    M27Utilities.ErrorHandler('Deprecated, covered by RecordResourcePoint now')
    MassCount = 0
    HydroCount = 0
    local iMarkerType
    local iResourceCount, sPathingType, sLocationRef
    if bDebugMessages == true then LOG(sFunctionRef..': About to record resource locations') end
    local bHaveAdaptiveMap = ScenarioInfo.AdaptiveMap

    --local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
    local bCanBuildOnResourcePoint
    for _, v in ScenarioUtils.GetMarkers() do
        iMarkerType = 0
        if v.type == "Mass" then
            --Note: CanBuildStructureAt only works after 1 tick has passed following aiBrain creation for some reason
            if bHaveAdaptiveMap then bCanBuildOnResourcePoint = aiBrain:CanBuildStructureAt('uab1103', v.position)
            else bCanBuildOnResourcePoint = true end
            if bDebugMessages == true then LOG(sFunctionRef..': v.position='..repr(v.position)..'; bCanBuildMexOnmassPoint='..tostring(bCanBuildOnResourcePoint)) end
            if bCanBuildOnResourcePoint then -- or aiBrain:CanBuildStructureAt('URB1103', v.position) == true or moho.aibrain_methods.CanBuildStructureAt(aiBrain, 'ueb1103', v.position) then
                MassCount = MassCount + 1
                MassPoints[MassCount] = v.position
                if bDebugMessages == true then
                    local iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(MassPoints[MassCount])
                    LOG(sFunctionRef..': Recording masspoints: co-ordinates = ' ..repr(MassPoints[MassCount])..'; SegmentX-Z='..iSegmentX..'-'..iSegmentZ)
                end
                iMarkerType = 1
                iResourceCount = MassCount
                sLocationRef = M27Utilities.ConvertLocationToReference(v.position)
                tMexPointsByLocationRef[sLocationRef] = v.position
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Cant build a mex at mass marker so ignoring as might be adaptive map') end
            end
        end -- Mass
        if v.type == "Hydrocarbon" then
            if bHaveAdaptiveMap then bCanBuildOnResourcePoint = aiBrain:CanBuildStructureAt('uab1102', v.position)
            else bCanBuildOnResourcePoint = true end
            if bDebugMessages == true then LOG(sFunctionRef..': v.position='..repr(v.position)..'; bCanBuildMexOnmassPoint='..tostring(bCanBuildOnResourcePoint)) end
            if bCanBuildOnResourcePoint then
                HydroCount = HydroCount + 1
                HydroPoints[HydroCount] = v.position
                iMarkerType = 2
                iResourceCount = HydroCount
                if bDebugMessages == true then LOG(sFunctionRef..': Recording hydrocarbon points: co-ordinates = '..repr(HydroPoints[HydroCount])) end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Cant build hydro at hydro marker so ignoring as might be adaptive map') end
            end
        end -- Hydrocarbon
        --Update unmapped marker list:

        --[[for iPathingType = 1, iMaxPathingType do
            if iPathingType == 1 then sPathingType = M27UnitInfo.refPathingTypeAmphibious
            elseif iPathingType == 2 then sPathingType = M27UnitInfo.refPathingTypeNavy
            elseif iPathingType == 3 then sPathingType = M27UnitInfo.refPathingTypeAir
            else sPathingType = M27UnitInfo.refPathingTypeLand
            end ]]--
        if iMarkerType > 0 then
            for iPathingType, sPathingType in M27UnitInfo.refPathingTypeAll do
                if tUnmappedMarker[sPathingType] == nil then tUnmappedMarker[sPathingType] = {} end
                if tUnmappedMarker[sPathingType][iMarkerType] == nil then tUnmappedMarker[sPathingType][iMarkerType] = {} end
                tUnmappedMarker[sPathingType][iMarkerType][iResourceCount] = v.position
            end
        end
    end -- GetMarkers() loop
    if bDebugMessages == true then
        LOG(sFunctionRef..': Finished recording mass markers, total mass marker count='..MassCount..'; list of all mass points='..repr(MassPoints))
    end

    -- MapMexCount = MassCount
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordResourceNearStartPosition(iArmy, iMaxDistance, bCountOnly, bMexNotHydro)
    -- iArmy is the army number, e.g. 1 for ARMY_1; iMaxDistance is the max distance for a mex to be returned (this only works the first time ever this function is called)
    --bMexNotHydro - true if looking for nearby mexes, false if looking for nearby hydros; defaults to true

    -- Returns a table containing positions of any mex meeting the criteria, unless bCountOnly is true in which case returns the no. of such mexes
    local sFunctionRef = 'RecordResourceNearStartPosition'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if iMaxDistance == nil then iMaxDistance = 12 end --NOTE: As currently only run the actual code to locate nearby mexes once, the first iMaxDistance will determine what to use, and any subsequent uses it wont matter
    if bMexNotHydro == nil then bMexNotHydro = true end
    if bCountOnly == nil then bCountOnly = false end
    local iResourceCount = 0
    local iResourceType = 1 --1 = mex, 2 = hydro
    if bMexNotHydro == false then iResourceType = 2 end

    if tResourceNearStart[iArmy] == nil then tResourceNearStart[iArmy] = {} end
    if tResourceNearStart[iArmy][iResourceType] == nil then
        --Haven't determined nearby resource yet
        local iDistance = 0
        local pStartPos =  PlayerStartPoints[iArmy]

        tResourceNearStart[iArmy][iResourceType] = {}
        local AllResourcePoints = {}
        if bMexNotHydro then AllResourcePoints = MassPoints
        else AllResourcePoints = HydroPoints end

        if not(AllResourcePoints == nil) then
            for key,pResourcePos in AllResourcePoints do
                iDistance = M27Utilities.GetDistanceBetweenPositions(pStartPos, pResourcePos)
                if iDistance <= iMaxDistance then
                    if bDebugMessages == true then LOG('Found position near to start; iDistance='..iDistance..'; imaxDistance='..iMaxDistance..'; pStartPos[1][3]='..pStartPos[1]..'-'..pStartPos[3]..'; pResourcePos='..pResourcePos[1]..'-'..pResourcePos[3]..'; bMexNotHydro='..tostring(bMexNotHydro)) end
                    iResourceCount = iResourceCount + 1
                    if tResourceNearStart[iArmy][iResourceType][iResourceCount] == nil then tResourceNearStart[iArmy][iResourceType][iResourceCount] = {} end
                    tResourceNearStart[iArmy][iResourceType][iResourceCount] = pResourcePos
                end
            end
        end
    end
    if bCountOnly == false then
        --Create a table of nearby resource locations:
        local NearbyResourcePos = {}
        for iCurResource, v in tResourceNearStart[iArmy][iResourceType] do
            NearbyResourcePos[iResourceCount] = v
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return NearbyResourcePos
    else
        iResourceCount = 0
        for iCurResource, v in tResourceNearStart[iArmy][iResourceType] do
            iResourceCount = iResourceCount + 1
            if bDebugMessages == true then LOG('valid resource location iResourceCount='..iResourceCount..'; v[1-3]='..v[1]..'-'..v[2]..'-'..v[3]) end
        end
        if bDebugMessages == true then LOG('RecordResourceNearStartPosition: iResourceCount='..iResourceCount..'; bmexNotHydro='..tostring(bMexNotHydro)..'; iMaxDistance='..iMaxDistance) end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return iResourceCount
    end
end
function RecordMexNearStartPosition(iArmy, iMaxDistance, bCountOnly)
    return RecordResourceNearStartPosition(iArmy, iMaxDistance, bCountOnly, true)
end

function RecordHydroNearStartPosition(iArmy, iMaxDistance, bCountOnly)
    return RecordResourceNearStartPosition(iArmy, iMaxDistance, bCountOnly, false)
end

function RecordPlayerStartLocations()
    -- Updates PlayerStartPoints to Record all the possible player start points
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local iMarkerType = 3
    for i = 1, 16 do
        local tempPos = ScenarioUtils.GetMarker('ARMY_'..i).position
        if tempPos ~= nil then
            PlayerStartPoints[i] = tempPos
            if bDebugMessages == true then LOG('* M27AI: Recording Player start point, ARMY_'..i..' x=' ..PlayerStartPoints[i][1]..';y='..PlayerStartPoints[i][2]..';z='..PlayerStartPoints[i][3]) end
            for iPathingType, sPathingType in M27UnitInfo.refPathingTypeAll do
                if tUnmappedMarker[sPathingType] == nil then tUnmappedMarker[sPathingType] = {} end
                if tUnmappedMarker[sPathingType][iMarkerType] == nil then tUnmappedMarker[sPathingType][iMarkerType] = {} end
                tUnmappedMarker[sPathingType][iMarkerType][i] = tempPos
            end
        end
    end
end

function GetResourcesNearTargetLocation(tTargetPos, iMaxDistance, bMexNotHydro)
    --Returns a table of locations of the chosen resource within iMaxDistance of tTargetPos
    --returns nil if no matches

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetResourcesNearTargetLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if iMaxDistance == nil then iMaxDistance = 7 end
    if bMexNotHydro == nil then bMexNotHydro = true end
    local iResourceCount = 0
    local iResourceType = 1 --1 = mex, 2 = hydro
    if bMexNotHydro == false then iResourceType = 2 end

    local iDistance = 0
    local tAllResourcePoints = {}
    if bMexNotHydro then tAllResourcePoints = MassPoints
    else tAllResourcePoints = HydroPoints end
    local tNearbyResources = {}

    if not(tAllResourcePoints == nil) then
        for key,pResourcePos in tAllResourcePoints do
            if math.abs(pResourcePos[1]-tTargetPos[1]) <= iMaxDistance and math.abs(pResourcePos[3]-tTargetPos[3]) <= iMaxDistance then
                iDistance = M27Utilities.GetDistanceBetweenPositions(tTargetPos, pResourcePos)
                if bDebugMessages == true then LOG(sFunctionRef..': iDistance='..iDistance..'; pResourcePos='..repr(pResourcePos)) end
                if iDistance <= iMaxDistance then
                    if bDebugMessages == true then LOG('GetResourcesNearTarget: Found position near to target location; iDistance='..iDistance..'; imaxDistance='..iMaxDistance..'; tTargetPos[1][3]='..tTargetPos[1]..'-'..tTargetPos[3]..'; pResourcePos='..pResourcePos[1]..'-'..pResourcePos[3]..'; bMexNotHydro='..tostring(bMexNotHydro)) end
                    iResourceCount = iResourceCount + 1
                    tNearbyResources[iResourceCount] = {}
                    tNearbyResources[iResourceCount] = pResourcePos
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tNearbyResources
end

--[[function AddSegmentToGroup(sPathing, iGroup, iSegmentX, iSegmentZ)
    --Adds iSegmentX+Z to iGroup for sPathing (done so that can call this from multiple places)
    if tSegmentBySegmentGroup[sPathing] == nil then tSegmentBySegmentGroup[sPathing] = {} end
    local iExistingSegments
    if tSegmentBySegmentGroup[sPathing][iGroup] == nil then
        iExistingSegments = 0
        tSegmentBySegmentGroup[sPathing][iGroup] = {}
    else
        iExistingSegments = table.getn(tSegmentBySegmentGroup[sPathing][iGroup])
    end
    if iExistingSegments == nil then iExistingSegments = 0 end
    iExistingSegments = iExistingSegments + 1

    tSegmentBySegmentGroup[sPathing][iGroup][iExistingSegments] = {iSegmentX, iSegmentZ}

    if tSegmentGroupBySegment[sPathing] == nil then tSegmentGroupBySegment[sPathing] = {} end
    if tSegmentGroupBySegment[sPathing][iSegmentX] == nil then tSegmentGroupBySegment[sPathing][iSegmentX] = {} end
    tSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ] = iGroup
end--]]

function TEMPMAPTEST(sExtraRef)
    M27Utilities.ErrorHandler('This is meant for debugging only, disbale')
    --[[local iResult
    local tLocationsToSearch = {}
    local aiBrain
    local oACU
    for iBrain, oBrain in ArmyBrains do
        if oBrain.M27AI then
            aiBrain = oBrain
            oACU = M27Utilities.GetACU(aiBrain)
            break
        end
    end
    tLocationsToSearch[1] = {269.5, 47.585899353027, 250.5} --Central mex
    tLocationsToSearch[2] = {35.5, 46, 21.5} --Top-left
    tLocationsToSearch[3] = {51.5, 46, 489.5} --Bottom left
    local sPathing = 'Amphibious'

    local iSegmentX, iSegmentZ
    for iLocation, tCurLocation in tLocationsToSearch do
        iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(tCurLocation)
        iResult = tSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ]
        if iResult == nil then iResult = 'Nil' end
        LOG('TEMPMAPTEST: '..sExtraRef..': Result for position '..repr(tCurLocation)..' = '..iResult..'; Can ACU path to this location='..tostring(oACU:CanPathTo(tCurLocation))..'; GameTime='..GetGameTimeSeconds())
    end--]]
end

function InSameSegmentGroup(oUnit, tDestination, bReturnUnitGroupOnly, bReturnDestinationGroupOnly)
    local sFunctionRef = 'InSameSegmentGroup'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if oUnit and not(oUnit.Dead) and oUnit.GetUnitId then
        local sPathingType = M27UnitInfo.GetUnitPathingType(oUnit)
        local tCurPosition = oUnit:GetPosition()
        local iSegmentX, iSegmentZ, iUnitGroup, iTargetSegmentX, iTargetSegmentZ, iTargetGroup
        if not(bReturnDestinationGroupOnly) then
            iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(tCurPosition)
            iUnitGroup = tPathingSegmentGroupBySegment[sPathingType][iSegmentX][iSegmentZ]
        end
        if not(bReturnUnitGroupOnly) then
            iTargetSegmentX, iTargetSegmentZ = GetPathingSegmentFromPosition(tDestination)
            iTargetGroup = tPathingSegmentGroupBySegment[sPathingType][iTargetSegmentX][iTargetSegmentZ]
        end

        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        if bReturnUnitGroupOnly then
            return iUnitGroup
        elseif bReturnDestinationGroupOnly then
            return iTargetGroup
        end
        if iUnitGroup == iTargetGroup then return true else return false end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetSegmentGroupOfTarget(sPathing, iTargetSegmentX, iTargetSegmentZ)
    --Returns unit group for the target segment position, or nil if its not known; oUnit should be specified to allow it to see if oUnit can path there (in case we havent recorded the location yet)
    return tPathingSegmentGroupBySegment[sPathing][iTargetSegmentX][iTargetSegmentZ]
end

function GetSegmentGroupOfLocation(sPathing, tLocation)
    local iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(tLocation)
    return tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ]
end


function GetUnitSegmentGroup(oUnit)
    --Intended for convenience not optimisation - if going to be called alot of times use other approach
    local sPathing = M27UnitInfo.GetUnitPathingType(oUnit)
    local iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(oUnit:GetPosition())
    return tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ]
end

function FixSegmentPathingGroup(sPathingType, tLocation, iCorrectPathingGroup)
    --Called if CanPathTo identifies an inconsistency in our pathing logic - basic fix
    local iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(tLocation)
    local bUpdateAmphibiousWithSameGroup = false
    if sPathingType == M27UnitInfo.refPathingTypeLand and tPathingSegmentGroupBySegment[sPathingType][iSegmentX][iSegmentZ] == tPathingSegmentGroupBySegment[M27UnitInfo.refPathingTypeAmphibious][iSegmentX][iSegmentZ] then bUpdateAmphibiousWithSameGroup = true end
    tPathingSegmentGroupBySegment[sPathingType][iSegmentX][iSegmentZ] = iCorrectPathingGroup
    if bUpdateAmphibiousWithSameGroup then tPathingSegmentGroupBySegment[M27UnitInfo.refPathingTypeAmphibious][iSegmentX][iSegmentZ] = iCorrectPathingGroup end
    tManualPathingChecks[sPathingType][M27Utilities.ConvertLocationToReference(tLocation)] = true
end

function GetReclaimablesMassValue(tReclaimables, bAlsoReturnLargestReclaimPosition, iIgnoreReclaimIfNotMoreThanThis, bAlsoReturnAmountOfHighestIndividualReclaim)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetReclaimablesMassValue'
    --V14 and earlier would modify total mass value to reduce it by 25% if its small, and 50% if its medium; v15 removed this
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bAlsoReturnLargestReclaimPosition == nil then bAlsoReturnLargestReclaimPosition = false end
    if iIgnoreReclaimIfNotMoreThanThis == nil then iIgnoreReclaimIfNotMoreThanThis = 0 end
    if iIgnoreReclaimIfNotMoreThanThis < 0 then iIgnoreReclaimIfNotMoreThanThis = 0 end
    --local iMedMassThreshold = 20 --as per large mass threshold
    --local iLargeMassThreshold = 150 --any mass with a value more than iLargeMassTreshold gets increased in weighted value by iLargeMassMod
    --local iMedMassMod = 2 --increases value of mass over a particular threshold by this
    --local iLargeMassMod = 2 --increases value of mass over a particular threshold by this (multiplicative with iMedMassMod)

    local tWreckPos = {}
    local iCurMassValue
    local iTotalMassValue = 0
    local iLargestCurReclaim = 0
    local tReclaimPos = {}
    if tReclaimables and table.getn( tReclaimables ) > 0 then
        for _, v in tReclaimables do
            tWreckPos = v.CachePosition
            if not (tWreckPos[1]==nil) then
                if v.MaxMassReclaim > iIgnoreReclaimIfNotMoreThanThis then
                    if not(v:BeenDestroyed()) then
                        -- Determine mass - reduce low value mass value for weighting purposes (since it takes longer to get):
                        --if bDebugMessages == true then LOG('Have wrecks with a valid position and positive mass value within the segment iCurXZ='..iCurX..'-'..iCurZ..'; iWreckNo='.._) end
                        --iCurMassValue = v.MaxMassReclaim / (iMedMassMod * iLargeMassMod)
                        --if iCurMassValue >= iMedMassThreshold then iCurMassValue = iCurMassValue * iMedMassMod end
                        --if iCurMassValue >= iLargeMassThreshold then iCurMassValue = iCurMassValue * iLargeMassMod end
                        --iTotalMassValue = iTotalMassValue + iCurMassValue
                        iTotalMassValue = iTotalMassValue + v.MaxMassReclaim
                        if v.MaxMassReclaim > iLargestCurReclaim then
                            iLargestCurReclaim = v.MaxMassReclaim
                            tReclaimPos = {tWreckPos[1], tWreckPos[2], tWreckPos[3]}
                        end
                    end
                end
                --bIsProp = IsProp(v)
            else
                if not(v.MaxMassReclaim == nil) then
                    if v.MaxMassReclaim > 0 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Warning - have ignored wreck location despite it having a mass reclaim value') end
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if bAlsoReturnLargestReclaimPosition then
        if bAlsoReturnAmountOfHighestIndividualReclaim then return iTotalMassValue, tReclaimPos, iLargestCurReclaim
        else return iTotalMassValue, tReclaimPos end
    else
        if bAlsoReturnAmountOfHighestIndividualReclaim then return iTotalMassValue, iLargestCurReclaim
        else return iTotalMassValue end
    end
end

function GetNearestReclaim(tLocation, iSearchRadius, iMinReclaimValue)
    --Returns the object/wreck of the nearest reclaim that is more than iMinReclaimValue and within iSearchRadius of tLocation
    --returns nil if no valid locations
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetNearestReclaim'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if iMinReclaimValue == nil then iMinReclaimValue = 1 end
    if iSearchRadius == nil then iSearchRadius = 5 end
    local tRectangle = Rect(tLocation[1] - iSearchRadius, tLocation[3] - iSearchRadius, tLocation[1] + iSearchRadius, tLocation[3] + iSearchRadius)
    local tReclaimables = GetReclaimablesInRect(tRectangle)
    local tCurWreckPosition = {}
    local iCurWreckReclaim
    local iDistToPosition
    local iMinDistToPosition = 10000
    local iClosestWreck
    if bDebugMessages == true then
        if M27Utilities.IsTableEmpty(tReclaimables) then LOG(sFunctionRef..': tReclaimables is empty')
            else LOG(sFunctionRef..': tReclaimables size='..table.getn(tReclaimables)) end
    end
    if M27Utilities.IsTableEmpty(tReclaimables) == false then
        for iWreck, oWreck in tReclaimables do
            tCurWreckPosition = oWreck.CachePosition
            if not (tCurWreckPosition[1]==nil) then
                iCurWreckReclaim = oWreck.MaxMassReclaim
                if iCurWreckReclaim >= iMinReclaimValue then
                    if not(oWreck:BeenDestroyed()) then --For some reason a wreck can have been reclaimed but still show a mass reclaim value, so need this to make sure it still exists
                        iDistToPosition = M27Utilities.GetDistanceBetweenPositions(tLocation, tCurWreckPosition)
                        if bDebugMessages == true then LOG(sFunctionRef..': iWreck='..iWreck..'; iDistToPosition='..iDistToPosition..'; iCurWreckReclaim='..iCurWreckReclaim..'; iSearchRadius='..iSearchRadius..'; iMinDistToPosition='..iMinDistToPosition) end
                        if iDistToPosition <= iSearchRadius then
                            if iDistToPosition <= iMinDistToPosition then
                                iMinDistToPosition = iDistToPosition
                                iClosestWreck = iWreck
                            end
                        end
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if iClosestWreck == nil then
        if bDebugMessages == true then LOG(sFunctionRef..': No reclaimable objects found, returning nil') end
        return nil
    else
        if bDebugMessages == true then LOG(sFunctionRef..': returning reclaimable object') end
        return tReclaimables[iClosestWreck] end
end

function GetReclaimInRectangle(iReturnType, rRectangleToSearch)
    --iReturnType: 1 = true/false; 2 = number of wrecks; 3 = total mass, 4 = valid wrecks
    local sFunctionRef = 'GetReclaimInRectangle'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tReclaimables = GetReclaimablesInRect(rRectangleToSearch)
    local iCurMassValue = 0
    local iWreckCount = 0
    local iTotalMassValue
    local bHaveReclaim = false
    local tValidWrecks = {}
    if M27Utilities.IsTableEmpty(tReclaimables) == false then
        if iReturnType == 3 then
            iTotalMassValue = GetReclaimablesMassValue(tReclaimables, false, 0)
        else
            for _, v in tReclaimables do
                local WreckPos = v.CachePosition
                if not(WreckPos[1]==nil) then
                    iCurMassValue = v.MaxMassReclaim
                    if iCurMassValue > 0 then
                        if not(v:BeenDestroyed()) then
                            iWreckCount = iWreckCount + 1
                            bHaveReclaim = true
                            if iReturnType == 1 then break
                            elseif iReturnType == 4 then tValidWrecks[iWreckCount] = v end
                            --bIsProp = IsProp(v) --only used for log/testing
                            --if bDebugMessages == true then LOG('Reclaim position '..iWreckCount..'='..WreckPos[1]..'-'..WreckPos[2]..'-'..WreckPos[3]..'; iMassValue='..iMassValue) end
                            --DrawLocations(WreckPos, nil, 1, 20, true)
                        end
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if iReturnType == 1 then return bHaveReclaim
        elseif iReturnType == 2 then return iWreckCount
        elseif iReturnType == 3 then return iTotalMassValue
        elseif iReturnType == 4 then return tValidWrecks
        else M27Utilities.ErrorHandler('Invalid return type')
    end
end

function GetReclaimLocationFromSegment(iReclaimSegmentX, iReclaimSegmentZ)
    --e.g. segment (1,1) will be 0 to ReclaimSegmentSizeX and 0 to ReclaimSegmentSizeZ in size
    --This will return the midpoint
    local iX = (iReclaimSegmentX - 0.5) * iReclaimSegmentSizeX
    local iZ = (iReclaimSegmentZ - 0.5) * iReclaimSegmentSizeZ
    return {iX, GetSurfaceHeight(iX, iZ), iZ}
end

function GetReclaimSegmentsFromLocation(tLocation)
    return math.ceil(tLocation[1] / iReclaimSegmentSizeX), math.ceil(tLocation[3] / iReclaimSegmentSizeZ)
end

function UpdateReclaimSegmentAreaOfInterest(iReclaimSegmentX, iReclaimSegmentZ, tBrainsToUpdateFor)
    --The segment mass value has changed or the brain's % threats have changed


    --Sets out reclaim areas of interest to try and claim, e.g. with engineer
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --set to true for certain positions where want logs to print
    local sFunctionRef = 'UpdateReclaimSegmentAreaOfInterest'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart) --Want accurate assessment of how long this takes on average
    local iCurPriority
    local sLocationRef = tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refsSegmentMidpointLocationRef]
    iReclaimAreaOfInterestTickCount = iReclaimAreaOfInterestTickCount + 1
    for iArmyIndex, aiBrain in tBrainsToUpdateFor do
        iCurPriority = nil
        if bDebugMessages == true then LOG(sFunctionRef..': Considering segment '..iReclaimSegmentX..'-'..iReclaimSegmentZ..' for iArmyIndex='..iArmyIndex) end
        --Is there enough reclaim?
        if tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimTotalMass] >= 40 then

            local iStartPositionPathingGroup
            local tCurMidpoint, sLocationRef
            local bEngineerDiedOrSpottedEnemiesRecently, iCurDistToBase, iCurDistToEnemyBase
            local tACUPosition
            local iNearestEnemyStartNumber
            --local tNearbyEnemies

            iStartPositionPathingGroup = GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, PlayerStartPoints[aiBrain.M27StartPositionNumber])
            local oACU = M27Utilities.GetACU(aiBrain)
            if oACU then
                tACUPosition = oACU:GetPosition()
            else tACUPosition = PlayerStartPoints[aiBrain.M27StartPositionNumber] end
            iNearestEnemyStartNumber = M27Logic.GetNearestEnemyStartNumber(aiBrain)
            local iCurAirSegmentX, iCurAirSegmentZ, bUnassigned
            --Can an amphibious unit path here from our start
            tCurMidpoint = GetReclaimLocationFromSegment(iReclaimSegmentX, iReclaimSegmentZ)
            if bDebugMessages == true then LOG(sFunctionRef..': iReclaimSegmentX='..iReclaimSegmentX..'; iReclaimSegmentZ='..iReclaimSegmentZ..'; tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimTotalMass]='..tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimTotalMass]..'; tCurMidpoint='..repr(tCurMidpoint)..'; SegmentGroup='..(GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tCurMidpoint) or 'nil')..'; iStartPositionPathingGroup='..(iStartPositionPathingGroup or 'nil')) end
            if iStartPositionPathingGroup == GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tCurMidpoint) then
                --Has an engineer already been assigned to reclaim here?
                sLocationRef = M27Utilities.ConvertLocationToReference(tCurMidpoint)
                if not(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef]) or not(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaim]) or M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaim]) == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': Dont have a valid assigned engineer to this location for reclaim; will now check not assigned to adjacent location unless high reclaim') end
                    bUnassigned = true
                    if tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimTotalMass] >= 250 then
                        --do nothing as bUnassigned = true already
                    else
                        for iAdjX = - 1, 1 do
                            for iAdjZ = - 1, 1 do
                                sLocationRef = M27Utilities.ConvertLocationToReference(GetReclaimLocationFromSegment(iReclaimSegmentX + iAdjX, iReclaimSegmentZ + iAdjZ))
                                if aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] and aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaim] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaim]) == false then
                                    bUnassigned = false
                                    break
                                end
                            end
                            if bUnassigned then break end
                        end
                    end
                    if bUnassigned then
                        --Check no engineers died recently or had enemies spotted (priority 1-3)
                        for iAdjX = iReclaimSegmentX - 1, iReclaimSegmentX + 1, 1 do
                            for iAdjZ = iReclaimSegmentZ - 1, iReclaimSegmentZ + 1, 1 do
                                if tReclaimAreas[iReclaimSegmentX + iAdjX] and tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ] then
                                    if tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][reftReclaimTimeOfLastEngineerDeathByArmyIndex] and tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][reftReclaimTimeOfLastEngineerDeathByArmyIndex][iArmyIndex] and GetGameTimeSeconds() - tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][reftReclaimTimeOfLastEngineerDeathByArmyIndex][iArmyIndex] < 300 then
                                        bEngineerDiedOrSpottedEnemiesRecently = true
                                        break
                                    elseif tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimTimeLastEnemySightedByArmyIndex] and tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimTimeLastEnemySightedByArmyIndex][iArmyIndex] and GetGameTimeSeconds() - tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimTimeLastEnemySightedByArmyIndex][iArmyIndex] < 120 then
                                        bEngineerDiedOrSpottedEnemiesRecently = true
                                        break
                                    end
                                end
                            end
                            if bEngineerDiedOrSpottedEnemiesRecently then break end
                        end
                        if not(bEngineerDiedOrSpottedEnemiesRecently) then
                            if bDebugMessages == true then LOG(sFunctionRef..': No enemies have died recently and no enemies have been spotted recently around target; tCurMidpoint='..repr(tCurMidpoint)..'; iNearestEnemyStartNumber='..iNearestEnemyStartNumber) end

                            --Check no nearby enemies - decided not to implement for CPU performance reasons
                            --tNearbyEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, tCurMidpoint, 90, 'Enemy')
                            --if M27Utilities.IsTableEmpty(tNearbyEnemies) == true then
                                --if bDebugMessages == true then LOG(sFunctionRef..': No nearby enemies detected') end
                                --Check no t2 arti in range
                                --if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti, tCurMidpoint, 150, 'Enemy')) == true then


                            iCurDistToBase = M27Utilities.GetDistanceBetweenPositions(tCurMidpoint, PlayerStartPoints[aiBrain.M27StartPositionNumber])
                            iCurDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tCurMidpoint, PlayerStartPoints[iNearestEnemyStartNumber])
                            --if bDebugMessages == true then LOG(sFunctionRef..': No nearby T2 arti detected; iCurDistToBase='..iCurDistToBase..'; iCurDistToEnemyBase='..iCurDistToEnemyBase..'; aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy]='..aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy]..'; aiBrain[M27Overseer.refiPercentageOutstandingThreat]='..aiBrain[M27Overseer.refiPercentageOutstandingThreat]..'; iCurDistToBase / (iCurDistToBase + iCurDistToEnemyBase='..iCurDistToBase / (iCurDistToBase + iCurDistToEnemyBase)..'; M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tCurMidpoint, false)='..M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tCurMidpoint, false)..'; iDistanceFromStartToEnemy='..iDistanceFromStartToEnemy) end
                            --Within defence and front unit coverage?
                            if aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy] - 0.1 > iCurDistToBase / (iCurDistToBase + iCurDistToEnemyBase) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Are more than 10% closer to base than furthest front unit') end
                                if aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] - 0.1 * aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] > M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tCurMidpoint, false) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Are more than 10% closer to base than defence coverage') end
                                    --On our side of the map?
                                    if iCurDistToBase < iCurDistToEnemyBase then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Are on our side of map') end
                                        --Priority 1 - have current visual intel of location or intel coverage
                                        iCurAirSegmentX, iCurAirSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(tCurMidpoint)
                                        if GetGameTimeSeconds() - aiBrain[M27AirOverseer.reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][M27AirOverseer.refiLastScouted] <= 1.1 then
                                            iCurPriority = 1
                                            --Check if we have radar coverage (ignore visual sight and non-radar structure intel units for performance reasons)
                                        elseif M27Logic.GetIntelCoverageOfPosition(aiBrain, tCurMidpoint, 10, true) then iCurPriority = 1
                                        else
                                            iCurPriority = 2
                                        end
                                    else iCurPriority = 3
                                    end
                                end
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': enemies have died recently and/or enemies have been spotted recently around target') end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Engineers assigned to nearby segment and dont have at least 250 mass in current segment') end
                    end
                    if not(iCurPriority) then
                        --Consider if still suitable for an ACU location
                        if M27Utilities.GetDistanceBetweenPositions(tACUPosition, tCurMidpoint) <= 200 then
                            --if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti, tCurMidpoint, 150, 'Enemy')) == true then
                                --tNearbyEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, tCurMidpoint, 90, 'Enemy')
                                --if M27Logic.GetCombatThreatRating(aiBrain, tNearbyEnemies, true, nil, nil, false, false) < 200 then
                                    iCurPriority = 4
                                --end
                            --end
                        end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Already have a valid assigned engineer to this location for reclaim, table size='..table.getn(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaim])) end
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Difference in pathing groups; Start position group='..(iStartPositionPathingGroup or 'nil')..'; Group of segment='..(GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tCurMidpoint) or 'nil')..'; tCurMidpoint='..repr(tCurMidpoint)) end
            end
        end

        --Has the priority changed from before?
        if bDebugMessages == true then LOG(sFunctionRef..': About to consider if priority has changed from before; iCurPriority='..(iCurPriority or 'nil')..'; Priority before='..(aiBrain[reftReclaimAreaPriorityByLocationRef][sLocationRef] or 'nil')) end
        if not(aiBrain[reftReclaimAreaPriorityByLocationRef][sLocationRef] == iCurPriority) then
            aiBrain[reftReclaimAreaPriorityByLocationRef][sLocationRef] = iCurPriority
            for iPriority = 1, 4 do
                if iPriority == iCurPriority then
                    if bDebugMessages == true then LOG(sFunctionRef..': iPriority='..iPriority..'; Adding to table for this priority') end
                    aiBrain[refiTotalReclaimAreasOfInterestByPriority][iPriority] = aiBrain[refiTotalReclaimAreasOfInterestByPriority][iPriority] + 1
                    aiBrain[reftReclaimAreasOfInterest][iPriority][sLocationRef] = {iReclaimSegmentX, iReclaimSegmentZ}
                else
                    if aiBrain[reftReclaimAreasOfInterest][iPriority][sLocationRef] then
                        if bDebugMessages == true then LOG(sFunctionRef..': iPriority='..iPriority..'; Removing from table for this priority') end
                        aiBrain[refiTotalReclaimAreasOfInterestByPriority][iPriority] = aiBrain[refiTotalReclaimAreasOfInterestByPriority][iPriority] - 1
                        aiBrain[reftReclaimAreasOfInterest][iPriority][sLocationRef] = nil
                    end
                end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Finished going through all segments.  1staiBrain[refiTotalReclaimAreasOfInterestByPriority]='..repr(tBrainsToUpdateFor[1][refiTotalReclaimAreasOfInterestByPriority])..'; All segments by priority='..repr(tBrainsToUpdateFor[1][reftReclaimAreasOfInterest])..'; sLocationRef recorded for this segment='..(tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refsSegmentMidpointLocationRef] or 'nil')) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdateReclaimMarkers()
    --Divides map into segments, determines reclaim in each segment and stores this in tReclaimAreas along with the location of the highest reclaim in this segment
    --if oEngineer isn't nil then it will also determine if the segment is pathable
    --Updates the global variable tReclaimAreas{}
    --Config settings:
    --Note: iMaxSegmentInterval defined at the top as a global variable
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --set to true for certain positions where want logs to print
    local sFunctionRef = 'UpdateReclaimMarkers'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local iTimeBeforeFullRefresh = 10 --Will do a full refresh of reclaim every x seconds

    --Record all segments' mass information:
    if bReclaimRefreshActive == false and GetGameTimeSeconds() - (iLastReclaimRefresh or 0) >= iTimeBeforeFullRefresh then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart) --Want the profile coutn to reflect the number of times actually running the core code
        bReclaimRefreshActive = true
        local iMinValueOfIndividualReclaim = 2.5
        local tReclaimPos = {}
        local iLargestCurReclaim
        local rPlayableArea = rMapPlayableArea
        local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
        local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]
        --Make sure we have an up to date list of active aiBrains
        local bCheckBrains = true
        local iCurCount = 0
        local iMaxCount = 100

        local tM27Brains = {}
        local tBrainsWithChangedThreat = {}
        local bHaveBrainsWithChangedThreat = false
        for iArmyIndex, aiBrain in M27Overseer.tAllAIBrainsByArmyIndex do
            if aiBrain.M27AI and not(aiBrain:IsDefeated()) and not(aiBrain.M27IsDefeated) then
                tM27Brains[iArmyIndex] = aiBrain
                --Has the front position of the brain or threat range changed significantly since the previous cycle?

                if math.abs(math.min(aiBrain[refiPreviousThreatPercentCoverage], aiBrain[refiPreviousFrontUnitPercentFromOurBase]) - math.min(aiBrain[M27Overseer.refiPercentageOutstandingThreat], aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy])) > 0.02 then
                    bHaveBrainsWithChangedThreat = true
                    tBrainsWithChangedThreat[iArmyIndex] = aiBrain
                    --Only update the previous threat values here, as want to compare to the last time we refreshed based on this (otherwise we risk never refreshing if every change is say 1% every 10s)
                    aiBrain[refiPreviousThreatPercentCoverage] = aiBrain[M27Overseer.refiPercentageOutstandingThreat]
                    aiBrain[refiPreviousFrontUnitPercentFromOurBase] = aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy]
                end
            end
        end
        local iACUDeathCountWhenStarted = M27Overseer.iACUAlternativeFailureCount
        if bDebugMessages == true then LOG(sFunctionRef..': Pre start of main loop; iACUDeathCountWhenStarted='..iACUDeathCountWhenStarted) end



        if iReclaimSegmentSizeX == 0 then --Not yet determined reclaim sizes
            local iMinReclaimSegmentSize = 8.5 --Engineer build range is 6; means that a square of about 4.2 will fit inside this circle; If have 2 separate engineers assigned to adjacent reclaim segments, and want their build range to cover the two areas, then would want a gap twice this, so 8.4; will therefore go with min size of 8
            iReclaimSegmentSizeX = math.max(iMinReclaimSegmentSize, iMapSizeX / iMaxSegmentInterval)
            iReclaimSegmentSizeZ = math.max(iMinReclaimSegmentSize, iMapSizeZ / iMaxSegmentInterval)
        end

        local iReclaimMaxSegmentX = math.ceil(iMapSizeX / iReclaimSegmentSizeX)
        local iReclaimMaxSegmentZ = math.ceil(iMapSizeZ / iReclaimSegmentSizeZ)
        local iCurCount = 0
        local iWaitInterval = math.max(1, math.floor((iReclaimMaxSegmentX * iReclaimMaxSegmentZ) / (iTimeBeforeFullRefresh * 10)))


        local tReclaimables = {}
        local iTotalMassValue

        if bDebugMessages == true then LOG('ReclaimRefresh: About to do full refresh') end
        iLastReclaimRefresh = GetGameTimeSeconds()
        tReclaimPos = {}
        iMapTotalMass = 0
        iPreviousHighestReclaimInASegment = iHighestReclaimInASegment
        iHighestReclaimInASegment = 0
        for iCurX = 1, iReclaimMaxSegmentX do
            for iCurZ = 1, iReclaimMaxSegmentZ do
        --for iCurX = 1, math.floor(iMapSizeX / iSegmentSizeX) do
            --for iCurZ = 1, math.floor(iMapSizeZ / iSegmentSizeZ) do
                if bDebugMessages == true then LOG('Cycling through each segment; iCurX='..iCurX..'; iCurZ='..iCurZ) end

                iTotalMassValue = 0
                tReclaimables = GetReclaimablesInRect(Rect((iCurX - 1) * iReclaimSegmentSizeX, (iCurZ - 1) * iReclaimSegmentSizeZ, iCurX * iReclaimSegmentSizeX, iCurZ * iReclaimSegmentSizeZ))
                iLargestCurReclaim = 0
                if tReclaimables and table.getn( tReclaimables ) > 0 then
                    -- local iWreckCount = 0
                    --local bIsProp = nil  --only used for log/testing
                    if bDebugMessages == true then LOG('Have wrecks within the segment iCurXZ='..iCurX..'-'..iCurZ) end
                    iTotalMassValue, tReclaimPos, iLargestCurReclaim = GetReclaimablesMassValue(tReclaimables, true, iMinValueOfIndividualReclaim, true)

                    --Record this table:
                    if tReclaimAreas[iCurX] == nil then
                        tReclaimAreas[iCurX] = {}
                        if bDebugMessages == true then LOG('Setting table to nothing as is currently nil; iCurX='..iCurX) end
                    end
                    if tReclaimAreas[iCurX][iCurZ] == nil then
                        tReclaimAreas[iCurX][iCurZ] = {}
                        tReclaimAreas[iCurX][iCurZ][refReclaimSegmentMidpoint] = GetReclaimLocationFromSegment(iCurX, iCurZ)
                        tReclaimAreas[iCurX][iCurZ][refsSegmentMidpointLocationRef] = M27Utilities.ConvertLocationToReference(tReclaimAreas[iCurX][iCurZ][refReclaimSegmentMidpoint])
                    end
                    tReclaimAreas[iCurX][iCurZ][refiReclaimTotalPrev] = (tReclaimAreas[iCurX][iCurZ][refReclaimTotalMass] or 0)
                    tReclaimAreas[iCurX][iCurZ][refReclaimTotalMass] = iTotalMassValue
                    tReclaimAreas[iCurX][iCurZ][refReclaimHighestIndividualReclaim] = iLargestCurReclaim
                    iHighestReclaimInASegment = math.max(iHighestReclaimInASegment, iTotalMassValue)

                    --Determine reclaim areas of interest
                    if not(tReclaimAreas[iCurX][iCurZ][refiReclaimTotalPrev] == iTotalMassValue) then
                        UpdateReclaimSegmentAreaOfInterest(iCurX, iCurZ, tM27Brains)
                    elseif bHaveBrainsWithChangedThreat then
                        --Update for any brains where there has been a significant change
                        UpdateReclaimSegmentAreaOfInterest(iCurX, iCurZ, tBrainsWithChangedThreat)
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': iACUDeathCountWhenStarted='..iACUDeathCountWhenStarted..'; M27Overseer.iACUAlternativeFailureCount='..M27Overseer.iACUAlternativeFailureCount) end
                    if iACUDeathCountWhenStarted < M27Overseer.iACUAlternativeFailureCount then
                        --Need to update list of brains
                        tM27Brains = {}
                        --tBrainsWithChangedThreat = {}
                        --bHaveBrainsWithChangedThreat = false
                        for iArmyIndex, oBrain in M27Overseer.tAllAIBrainsByArmyIndex do
                            if oBrain.M27AI and not(oBrain:IsDefeated()) and not(oBrain.M27IsDefeated) then
                                tM27Brains[iArmyIndex] = oBrain
                            end
                        end
                        local bNeedToUpdateChangedBrains = not(M27Utilities.IsTableEmpty(tBrainsWithChangedThreat))
                        while bNeedToUpdateChangedBrains == true do
                            bNeedToUpdateChangedBrains = false
                            for iArmyIndex, oBrain in tBrainsWithChangedThreat do
                                if oBrain:IsDefeated() or oBrain.M27IsDefeated then
                                    bNeedToUpdateChangedBrains = true
                                    tBrainsWithChangedThreat[iArmyIndex] = nil
                                    break
                                end
                            end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': Finished removing brains who have lost their ACU from the list of brains to consider reclaim updates on') end
                end
                iMapTotalMass = iMapTotalMass + iTotalMassValue
                if bDebugMessages == true then LOG('iCurX='..iCurX..'; iCurZ='..iCurZ..'; iMapTotalMass='..iMapTotalMass..'; iTotalMassValue='..iTotalMassValue..'; Location of segment='..repr(GetReclaimLocationFromSegment(iCurX, iCurZ))) end
                iCurCount = iCurCount + 1
            end

            if iCurCount >= iWaitInterval or iReclaimAreaOfInterestTickCount > 50 then
                iCurCount = 0
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitTicks(1)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                iReclaimAreaOfInterestTickCount = 0
            end
        end
        if bDebugMessages == true then
            LOG('Finished updating reclaim areas; will now list the reclaim areas of interest for the first M27ai brain')
            for iArmyIndex, aiBrain in tM27Brains do
                repr(aiBrain[reftReclaimAreasOfInterest])
                break
            end
        end
        bReclaimRefreshActive = false
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
end

function UpdateReclaimAreasOfInterest(aiBrain)
    --Sets out reclaim areas of interest to try and claim, e.g. with engineer
    --NOTE: Introduced in v15, and replaced in v15 - this function never got to see the light of day...
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --set to true for certain positions where want logs to print
    local sFunctionRef = 'UpdateReclaimAreasOfInterest'
    M27Utilities.ErrorHandler('Obsolete code')
    if false then

        local iRefreshTimeInSeconds = 10
        ForkThread(UpdateReclaimMarkers) --Wont do anything if have already updated recently
        if GetGameTimeSeconds() - (aiBrain[refiLastRefreshOfReclaimAreasOfInterest] or 0) >= iRefreshTimeInSeconds then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart) --Want accurate assessment of how long this takes on average
            if bDebugMessages == true then LOG(sFunctionRef..': Are doing a detailed refresh of reclaim points of interest') end
            local iMinSegmentReclaim = 40 --Ignore if less than this
            local iCurPriority
            local iStartPositionPathingGroup = GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, PlayerStartPoints[aiBrain.M27StartPositionNumber])
            local tCurMidpoint, sLocationRef
            local tNearbyEnemies, bEngineerDiedOrSpottedEnemiesRecently, iCurDistToBase, iCurDistToEnemyBase
            local tACUPosition = M27Utilities.GetACU(aiBrain):GetPosition()
            local iNearestEnemyStartNumber = M27Logic.GetNearestEnemyStartNumber(aiBrain)
            local iCurAirSegmentX, iCurAirSegmentZ, bUnassigned
            local iArmyIndex = aiBrain:GetArmyIndex()

            aiBrain[reftReclaimAreasOfInterest] = {}
            aiBrain[refiTotalReclaimAreasOfInterestByPriority] = {}
            for iPriority = 1, 4 do
                aiBrain[reftReclaimAreasOfInterest][iPriority] = {}
                aiBrain[refiTotalReclaimAreasOfInterestByPriority][iPriority] = 0
            end



            --Refresh table with reclaim areas of interest
            if bDebugMessages == true then LOG(sFunctionRef..': About to loop through every reclaim segment; iStartPositionPathingGroup='..iStartPositionPathingGroup) end
            for iCurX, tSubtable in tReclaimAreas do
                for iCurZ, tSubtable in tReclaimAreas[iCurX] do
                    --First decide whether we should even consider the location for reclaim
                    iCurPriority = nil
                    bEngineerDiedOrSpottedEnemiesRecently = false
                    --if bDebugMessages == true then LOG(sFunctionRef..': iCurX='..iCurX..'; iCurZ='..iCurZ..'; tReclaimAreas[iCurX][iCurZ][refReclaimTotalMass]='..tReclaimAreas[iCurX][iCurZ][refReclaimTotalMass]..'; iMinSegmentReclaim='..iMinSegmentReclaim) end
                    if tReclaimAreas[iCurX][iCurZ][refReclaimTotalMass] >= iMinSegmentReclaim then
                        if bDebugMessages == true then LOG(sFunctionRef..': iCurX='..iCurX..'; iCurZ='..iCurZ..'; tReclaimAreas[iCurX][iCurZ][refReclaimTotalMass]='..tReclaimAreas[iCurX][iCurZ][refReclaimTotalMass]..'; iMinSegmentReclaim='..iMinSegmentReclaim) end
                        --Can an amphibious unit path here
                        tCurMidpoint = GetReclaimLocationFromSegment(iCurX, iCurZ)
                        if bDebugMessages == true then LOG(sFunctionRef..': tCurMidpoint='..repr(tCurMidpoint)..'; SegmentGroup='..(GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tCurMidpoint) or 'nil')..'; iStartPositionPathingGroup='..(iStartPositionPathingGroup or 'nil')) end
                        if iStartPositionPathingGroup == GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tCurMidpoint) then
                            --Has an engineer already been assigned to reclaim here?
                            sLocationRef = M27Utilities.ConvertLocationToReference(tCurMidpoint)
                            if not(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef]) or not(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaim]) or M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaim]) == true then
                                if bDebugMessages == true then LOG(sFunctionRef..': Dont have a valid assigned engineer to this location for reclaim; will now check not assigned to adjacent location unless high reclaim') end
                                bUnassigned = true
                                if tReclaimAreas[iCurX][iCurZ][refReclaimTotalMass] >= 250 then
                                    --do nothing as bUnassigned = true already
                                else
                                    for iAdjX = iCurX - 1, iCurX + 1, 1 do
                                        for iAdjZ = iCurZ - 1, iCurZ + 1, 1 do
                                            sLocationRef = M27Utilities.ConvertLocationToReference(GetReclaimLocationFromSegment(iCurX + iAdjX, iCurZ + iAdjZ))
                                            if aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] and aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaim] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaim]) == false then
                                                bUnassigned = false
                                                break
                                            end
                                        end
                                        if bUnassigned then break end
                                    end
                                end
                                if bUnassigned then
                                    --Check no engineers died recently or had enemies spotted (priority 1-3)
                                    for iAdjX = iCurX - 1, iCurX + 1, 1 do
                                        for iAdjZ = iCurZ - 1, iCurZ + 1, 1 do
                                            if tReclaimAreas[iCurX + iAdjX] and tReclaimAreas[iCurX + iAdjX][iCurZ + iAdjZ] then
                                                if tReclaimAreas[iCurX][iCurZ][reftReclaimTimeOfLastEngineerDeathByArmyIndex] and tReclaimAreas[iCurX][iCurZ][reftReclaimTimeOfLastEngineerDeathByArmyIndex][iArmyIndex] and GetGameTimeSeconds() - tReclaimAreas[iCurX][iCurZ][reftReclaimTimeOfLastEngineerDeathByArmyIndex][iArmyIndex] < 300 then
                                                    bEngineerDiedOrSpottedEnemiesRecently = true
                                                    break
                                                elseif tReclaimAreas[iCurX][iCurZ][refReclaimTimeLastEnemySightedByArmyIndex] and tReclaimAreas[iCurX][iCurZ][refReclaimTimeLastEnemySightedByArmyIndex][iArmyIndex] and GetGameTimeSeconds() - tReclaimAreas[iCurX][iCurZ][refReclaimTimeLastEnemySightedByArmyIndex][iArmyIndex] < 120 then
                                                    bEngineerDiedOrSpottedEnemiesRecently = true
                                                    break
                                                end
                                            end
                                        end
                                        if bEngineerDiedOrSpottedEnemiesRecently then break end
                                    end
                                    if not(bEngineerDiedOrSpottedEnemiesRecently) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': No enemies have died recently and no enemies have been spotted recently around target') end

                                        --Check no nearby enemies
                                        tNearbyEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, tCurMidpoint, 90, 'Enemy')
                                        if M27Utilities.IsTableEmpty(tNearbyEnemies) == true then
                                            if bDebugMessages == true then LOG(sFunctionRef..': No nearby enemies detected') end
                                            --Check no t2 arti in range
                                            if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti, tCurMidpoint, 150, 'Enemy')) == true then


                                                iCurDistToBase = M27Utilities.GetDistanceBetweenPositions(tCurMidpoint, PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                                iCurDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tCurMidpoint, PlayerStartPoints[iNearestEnemyStartNumber])
                                                if bDebugMessages == true then LOG(sFunctionRef..': No nearby T2 arti detected; iCurDistToBase='..iCurDistToBase..'; iCurDistToEnemyBase='..iCurDistToEnemyBase..'; aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy]='..aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy]..'; aiBrain[M27Overseer.refiPercentageOutstandingThreat]='..aiBrain[M27Overseer.refiPercentageOutstandingThreat]..'; iCurDistToBase / (iCurDistToBase + iCurDistToEnemyBase='..iCurDistToBase / (iCurDistToBase + iCurDistToEnemyBase)..'; M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tCurMidpoint, false)='..M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tCurMidpoint, false)..'; iDistanceFromStartToEnemy='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]) end
                                                --Within defence and front unit coverage?
                                                if aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy] - 0.1 > iCurDistToBase / (iCurDistToBase + iCurDistToEnemyBase) then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Are more than 10% closer to base than furthest front unit') end
                                                    if (aiBrain[M27Overseer.refiPercentageOutstandingThreat] - 0.1) * aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]  > M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tCurMidpoint, false) then
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Are more than 10% closer to base than defence coverage') end
                                                        --On our side of the map?
                                                        if iCurDistToBase < iCurDistToEnemyBase then
                                                            if bDebugMessages == true then LOG(sFunctionRef..': Are on our side of map') end
                                                            --Priority 1 - have current visual intel of location or intel coverage
                                                            iCurAirSegmentX, iCurAirSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(tCurMidpoint)
                                                            if GetGameTimeSeconds() - aiBrain[M27AirOverseer.reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][M27AirOverseer.refiLastScouted] <= 1.1 then
                                                                iCurPriority = 1
                                                                --Check if we have radar coverage (ignore visual sight and non-radar structure intel units for performance reasons)
                                                            elseif M27Logic.GetIntelCoverageOfPosition(aiBrain, tCurMidpoint, 10, true) then iCurPriority = 1
                                                            else
                                                                iCurPriority = 2
                                                            end
                                                        else iCurPriority = 3
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': enemies have died recently and/or enemies have been spotted recently around target') end
                                    end
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': Engineers assigned to nearby segment and dont have at least 250 mass in current segment') end
                                end
                                if not(iCurPriority) then
                                    --Consider if still suitable for an ACU location
                                    if M27Utilities.GetDistanceBetweenPositions(tACUPosition, tCurMidpoint) <= 200 then
                                        if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti, tCurMidpoint, 150, 'Enemy')) == true then
                                            tNearbyEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, tCurMidpoint, 90, 'Enemy')
                                            if M27Logic.GetCombatThreatRating(aiBrain, tNearbyEnemies, true, nil, nil, false, false) < 200 then
                                                iCurPriority = 4
                                            end
                                        end
                                    end
                                end

                                if iCurPriority then
                                    table.insert(aiBrain[reftReclaimAreasOfInterest][iCurPriority], {iCurX, iCurZ})
                                    aiBrain[refiTotalReclaimAreasOfInterestByPriority][iCurPriority] = aiBrain[refiTotalReclaimAreasOfInterestByPriority][iCurPriority] + 1
                                end
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Already have a valid assigned engineer to this location for reclaim, table size='..table.getn(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaim])) end
                            end
                        end
                    end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Finished going through all segments.  aiBrain[refiTotalReclaimAreasOfInterestByPriority]='..repr(aiBrain[refiTotalReclaimAreasOfInterestByPriority])) end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Have recently refreshed reclaim points of interest so will use those values') end
        end
    end


end

--GetUnclaimedMexes - contained within EngineerOverseer

function GetHydroLocationsForPathingGroup(oPathingUnit, sPathingType, iPathingGroup)
    --Return table of hydro locations for iPathingGroup
    --Return {} if no such table
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetHydroLocationsForPathingGroup'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tHydroForPathingGroup = {}
    local bNeedToRecord = false
    if bDebugMessages == true then LOG(sFunctionRef..': Checking for hydros in pathing group; HydroCount='..HydroCount) end
    if HydroCount > 0 then
        if tHydroByPathingAndGrouping[sPathingType] == nil then
            tHydroByPathingAndGrouping[sPathingType] = {}
            bNeedToRecord = true
        end
        if tHydroByPathingAndGrouping[sPathingType][iPathingGroup] == nil then
            tHydroByPathingAndGrouping[sPathingType][iPathingGroup] = {}
            bNeedToRecord = true
        end
        if bDebugMessages == true then LOG(sFunctionRef..': bNeedToRecord='..tostring(bNeedToRecord)..'; iPathingGroup='..iPathingGroup) end
        if bNeedToRecord == true then
            local iValidHydroCount = 0
            local iCurSegmentX, iCurSegmentZ, iCurSegmentGroup
            for iHydro, tHydro in HydroPoints do
                iCurSegmentX, iCurSegmentZ = GetPathingSegmentFromPosition(tHydro)
                iCurSegmentGroup = GetSegmentGroupOfTarget(sPathingType, iCurSegmentX, iCurSegmentZ)
                if iCurSegmentGroup == iPathingGroup then
                    iValidHydroCount = iValidHydroCount + 1
                    tHydroByPathingAndGrouping[sPathingType][iPathingGroup][iValidHydroCount] = tHydro
                end
            end
        end
        tHydroForPathingGroup = tHydroByPathingAndGrouping[sPathingType][iPathingGroup]
    end
    if bDebugMessages == true then
        if M27Utilities.IsTableEmpty(tHydroForPathingGroup) == true then
            LOG(sFunctionRef..': Couldnt find any hydros in pathing group')
        else LOG(sFunctionRef..': Found '..table.getn(tHydroForPathingGroup)..' hydros in pathing group') end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tHydroForPathingGroup
end

function RecordMexForPathingGroup()
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordMexForPathingGroup'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tsPathingTypes = {M27UnitInfo.refPathingTypeAmphibious, M27UnitInfo.refPathingTypeNavy, M27UnitInfo.refPathingTypeLand}
    local iCurResourceGroup
    local iValidCount = 0
    tMexByPathingAndGrouping = {}
    for iPathingType, sPathingType in tsPathingTypes do
        tMexByPathingAndGrouping[sPathingType] = {}
        iValidCount = 0

        for iCurMex, tMexLocation in MassPoints do
            iValidCount = iValidCount + 1
            iCurResourceGroup = GetSegmentGroupOfLocation(sPathingType, tMexLocation)
            if tMexByPathingAndGrouping[sPathingType][iCurResourceGroup] == nil then
                tMexByPathingAndGrouping[sPathingType][iCurResourceGroup] = {}
                iValidCount = 1
            else iValidCount = table.getn(tMexByPathingAndGrouping[sPathingType][iCurResourceGroup]) + 1
            end
            tMexByPathingAndGrouping[sPathingType][iCurResourceGroup][iValidCount] = tMexLocation
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..'; tMexByPathingAndGrouping='..repr(tMexByPathingAndGrouping)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordMexForPathingGroupOld(oPathingUnit, bForceRefresh)
    --Updates tMexByPathingAndGrouping to record the mex that are in the same pathing group as oPathingUnit
    --bForceRefresh - issue where not all mexes register as being pathable at start of game, so overseer will call this again after a short delay
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'RecordMexForPathingGroupOld'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if oPathingUnit and not(oPathingUnit.Dead) then
        local sPathingType = M27UnitInfo.GetUnitPathingType(oPathingUnit)
        local tUnitPosition = oPathingUnit:GetPosition()
        local iUnitSegmentX, iUnitSegmentZ = GetPathingSegmentFromPosition(tUnitPosition)
        --GetSegmentGroupOfTarget(sPathing, iSegmentX, iSegmentZ)
        local iUnitSegmentGroup = GetSegmentGroupOfTarget(sPathingType, iUnitSegmentX, iUnitSegmentZ)
        if bDebugMessages == true then LOG(sFunctionRef..': , sPathingType='..sPathingType..'; iUnitSegmentGroup='..iUnitSegmentGroup) end
        if tMexByPathingAndGrouping[sPathingType] == nil then tMexByPathingAndGrouping[sPathingType] = {} end
        if tMexByPathingAndGrouping[sPathingType][iUnitSegmentGroup] == nil or bForceRefresh == true then
            --Need to record mass locations for this:
            if tMexByPathingAndGrouping[sPathingType][iUnitSegmentGroup] == nil then tMexByPathingAndGrouping[sPathingType][iUnitSegmentGroup] = {} end
            local iCurSegmentX, iCurSegmentZ
            local iMexSegmentGroup
            local iValidCount = 0
            local iOriginalCount = 0
            if bForceRefresh == true then
                iValidCount = table.getn(tMexByPathingAndGrouping[sPathingType][iUnitSegmentGroup])
                iOriginalCount = iValidCount
            end
            local bIncludeMex = false
            if bDebugMessages == true then LOG(sFunctionRef..': ScenarioInfo='..repr(ScenarioInfo)..'; MassPoints='..repr(MassPoints)) end
            for iCurMex, tMexLocation in MassPoints do
                if bDebugMessages == true then LOG(sFunctionRef..': About to consider tMexLocation='..repr(tMexLocation)) end
                iCurSegmentX, iCurSegmentZ = GetPathingSegmentFromPosition(tMexLocation)
                --if bDebugMessages == true then TEMPMAPTEST(sFunctionRef..': About to get segment group') end
                iMexSegmentGroup = GetSegmentGroupOfTarget(sPathingType, iCurSegmentX, iCurSegmentZ)
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Considering mex location '..repr(tMexLocation))
                end
                if not(iMexSegmentGroup==nil) then
                    if bDebugMessages == true then LOG(sFunctionRef..': iMexSegmentGroup='..iMexSegmentGroup..'; iCurMex='..iCurMex) end
                    if iMexSegmentGroup == iUnitSegmentGroup then
                        --Mex is in the same pathing group, so record it (unless are forcing a refresh and have already recorded it)
                        bIncludeMex = true
                        if bForceRefresh then
                            for iExistingMex, tExistingMex in tMexByPathingAndGrouping[sPathingType][iUnitSegmentGroup] do
                                if iExistingMex > iOriginalCount then break end
                                if tExistingMex[1] == tMexLocation[1] and tExistingMex[3] == tMexLocation[3] then
                                    bIncludeMex = false
                                    break
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': bIncludeMex='..tostring(bIncludeMex)) end
                        if bIncludeMex == true then
                            --if bDebugMessages == true then TEMPMAPTEST(sFunctionRef..': About to record mex as being in same pathing group') end
                            iValidCount = iValidCount + 1
                            tMexByPathingAndGrouping[sPathingType][iUnitSegmentGroup][iValidCount] = {}
                            tMexByPathingAndGrouping[sPathingType][iUnitSegmentGroup][iValidCount] = tMexLocation
                            if bDebugMessages == true then LOG(sFunctionRef..': Pathing='..sPathingType..': Segment '..iCurSegmentX..'-'..iCurSegmentZ..' is in a pathing group, so adding it to recorded mexes; iMexSegmentGroup='..iMexSegmentGroup..';, iValidCount='..iValidCount) end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Segment '..iCurSegmentX..'-'..iCurSegmentZ..' isnt in pathing group '..iUnitSegmentGroup) end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Segment '..iCurSegmentX..'-'..iCurSegmentZ..' isnt in pathing group '..iUnitSegmentGroup) end
                end
            end
        end
        if bDebugMessages == true then
            LOG(sFunctionRef..': table.getn of mexbypathing for sPathingType='..sPathingType..'; iUnitSegmentGroup='..iUnitSegmentGroup..'; table.getn='..table.getn(tMexByPathingAndGrouping[sPathingType][iUnitSegmentGroup]))
            if iUnitSegmentGroup == 1 then
                M27Utilities.DrawLocations(tMexByPathingAndGrouping[sPathingType][iUnitSegmentGroup], nil, 2)
                LOG('List of all mex locations for iSegmentGroup='..iUnitSegmentGroup..' for '..sPathingType..'='..repr(tMexByPathingAndGrouping[sPathingType][iUnitSegmentGroup]))
            end
        end
    else
        M27Utilities.ErrorHandler('pathing unit is nil or dead so not recording mexes')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetNumberOfResource (aiBrain, bMexNotHydro, bUnclaimedOnly, bVisibleOnly, iType)
    --iType: 1 = mexes nearer to aiBrain than nearest enemy (in future can add more, e.g. entire map; mexes closer to us than ally, etc.)
    --bUnclaimedOnly - true if mex can't have an extractor on it
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetNumberOfResource'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if aiBrain then
        if bVisibleOnly == nil then bVisibleOnly = true end
        if M27Utilities.IsTableEmpty(PlayerStartPoints) then RecordPlayerStartLocations() end
        if bDebugMessages == true then LOG(sFunctionRef..': PlayerStartPoints='..repr(PlayerStartPoints)..'; aiBrain army index='..aiBrain:GetArmyIndex()) end
        local tOurStartPos = PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local iEnemyStartNumber = M27Logic.GetNearestEnemyStartNumber(aiBrain)
        local iResourceCount = 0
        if iEnemyStartNumber == nil then
            M27Utilities.ErrorHandler('iEnemyStartNumber is nil')
        else
            local tEnemyStartPosition = PlayerStartPoints[iEnemyStartNumber]
            local bIncludeResource
            local oPossibleBuildingsNearPosition = {}
            local oResourcesNearPosition = {}
            local iHalfSize = 2 * 0.5 + 1
            local tMapResources
            if bMexNotHydro == nil then bMexNotHydro = true end
            if bMexNotHydro == true then
                tMapResources = MassPoints
                iHalfSize = 6 * 0.5 + 1
            else tMapResources = HydroPoints end

            if bDebugMessages == true then LOG(sFunctionRef..': tOurStartPos='..tOurStartPos[1]..'-'..tOurStartPos[3]) end
            if bDebugMessages == true then LOG(sFunctionRef..': tEnemyStartPosition='..tEnemyStartPosition[1]..'-'..tEnemyStartPosition[3]) end
            for iCurMex, tResourcePosition in tMapResources do
                bIncludeResource = false
                --Check if is in a valid location based in iType:
                if bDebugMessages == true then LOG(sFunctionRef..': tResourcePosition='..tResourcePosition[1]..'-'..tResourcePosition[3]..'; tEnemyStartPosition='..tEnemyStartPosition[1]..'-'..tEnemyStartPosition[3]..'; tOurStartPos='..tOurStartPos[1]..'-'..tOurStartPos[3]) end
                if iType == 1 then
                    if bDebugMessages == true then LOG(sFunctionRef..': iType==1, checking distance between positions') end
                    if M27Utilities.IsTableEmpty(tEnemyStartPosition) == true then
                        M27Utilities.ErrorHandler('tEnemyStartPosition is nil')
                        bIncludeResource = true
                    else
                        if M27Utilities.GetDistanceBetweenPositions(tResourcePosition, tEnemyStartPosition) >= M27Utilities.GetDistanceBetweenPositions(tResourcePosition, tOurStartPos) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Mex is further from enemy start than our start') end
                            bIncludeResource = true
                        else if bDebugMessages == true then LOG(sFunctionRef..': Mex is further from our start than enemy') end
                        end
                    end
                else
                    bIncludeResource = true
                end

                --check if needs to be unclaimed:
                if bIncludeResource == true and bUnclaimedOnly == true then
                    bIncludeResource = false
                    oPossibleBuildingsNearPosition = GetUnitsInRect(Rect(tResourcePosition[1]-iHalfSize, tResourcePosition[3]-iHalfSize, tResourcePosition[1]+iHalfSize, tResourcePosition[3]+iHalfSize))
                    if oPossibleBuildingsNearPosition == nil then bIncludeResource = true
                    else
                        if table.getn(oPossibleBuildingsNearPosition) == 0 then bIncludeResource = true
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Have a unit near the mex, checking if its a mex') end
                            if bMexNotHydro == true then oResourcesNearPosition = EntityCategoryFilterDown(categories.MASSEXTRACTION, oPossibleBuildingsNearPosition)
                            else oResourcesNearPosition = EntityCategoryFilterDown(categories.HYDROCARBON, oPossibleBuildingsNearPosition) end
                        end
                    end
                    if oResourcesNearPosition == nil then bIncludeResource = true
                    else
                        if table.getn(oResourcesNearPosition) == 0 then bIncludeResource = true
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Have a mex/hydro building near the mex') end
                            --is a mex building here; check if can see it (if bVisibleOnly is true)
                            if bVisibleOnly == true then
                                --Check if can see the mex (or a radar blip on the mex), and set bIncludeResource to true if don't know about the building thats there
                                if M27Utilities.CanSeeUnit(aiBrain, oResourcesNearPosition[1], true) == false then bIncludeResource = true end
                                if bDebugMessages == true then LOG(sFunctionRef..': Have just checked if the mex/hydro is visible to us; bIncludeResource='..tostring(bIncludeResource)) end
                            else
                                bIncludeResource = true
                            end
                        end
                    end
                end
                if bIncludeResource == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': Mex/hydro is closer to us and not aware of enemy buildings on it, so recording') end
                    iResourceCount = iResourceCount + 1
                end
            end
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return iResourceCount
    else
        M27Utilities.ErrorHandler('aiBrain is nil')
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return 0
    end
end

function GetNearestMexToUnit(oBuilder, bCanBeBuiltOnByAlly, bCanBeBuiltOnByEnemy, bCanBeQueuedToBeBuilt, iMaxSearchRangeMod, tStartPositionOverride, tMexesToIgnore)
    --Gets the nearest mex to oBuilder based on oBuilder's build range+iMaxSearchRangeMod. Returns nil if no such mex.  Optional variables:
    --bCanBeBuiltOnByAlly - false if dont want it to have been built on by us
    --bCanBeBuiltOnByEnemy - false if dont want it to have been built on by enemy
    --iMaxSearchRangeMod - defaults to 0
    --tStartPositionOverride - use this instead of the builder start position if its specified
    --tMexesToIgnore - a table of locations to ignore if they're the nearest mex

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetNearestMexToUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bCanBeBuiltOnByAlly == nil then bCanBeBuiltOnByAlly = false end
    if bCanBeBuiltOnByEnemy == nil then bCanBeBuiltOnByEnemy = false end
    if iMaxSearchRangeMod == nil then iMaxSearchRangeMod = 0 end

    local tUnitPos = oBuilder:GetPosition()
    local tLocationToSearchFrom
    if tStartPositionOverride then tLocationToSearchFrom = tStartPositionOverride else tLocationToSearchFrom = tUnitPos end

    --local iUnitSegmentX, iUnitSegmentZ = GetPathingSegmentFromPosition(tLocationToSearchFrom)
    local iUnitPathGroup = GetUnitSegmentGroup(oBuilder)
    local sPathing = M27UnitInfo.GetUnitPathingType(oBuilder)
    local oUnitBP = oBuilder:GetBlueprint()
    local iBuildDistance = 0
    if oUnitBP.Economy and oUnitBP.Economy.MaxBuildDistance then iBuildDistance = oUnitBP.Economy.MaxBuildDistance end
    if iBuildDistance == nil and iMaxSearchRangeMod <= 0 then iBuildDistance = 5 else iBuildDistance = 0 end
    local iMaxDistanceFromUnit = iBuildDistance + iMaxSearchRangeMod
    local iMinDistanceFromUnit = 10000
    local iNearestMexFromUnit
    local iCurDistanceFromUnit
    local aiBrain = oBuilder:GetAIBrain()
    local bCheckListOfMexesToIgnore = false
    if M27Utilities.IsTableEmpty(tMexesToIgnore) == false then
        if M27Utilities.IsTableEmpty(tMexesToIgnore[1]) == true then
            M27Utilities.ErrorHandler('tMexesToIgnore first entry isnt a table, likely forgot to send a table of tables to the function and instead sent a single location')
        else
            bCheckListOfMexesToIgnore = true
        end
    end
    --local iSegmentX, iSegmentZ --for the mex
    local bValidMex
    if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through all mexes for sPathing='..sPathing..' and iUnitPathGroup='..iUnitPathGroup) end
    if M27Utilities.IsTableEmpty(tMexByPathingAndGrouping[sPathing][iUnitPathGroup]) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': List of mexes in pathing group='..repr(tMexByPathingAndGrouping[sPathing][iUnitPathGroup])) end
        for iCurMex, tMexLocation in tMexByPathingAndGrouping[sPathing][iUnitPathGroup] do
            bValidMex = false
            iCurDistanceFromUnit = M27Utilities.GetDistanceBetweenPositions(tMexLocation, tLocationToSearchFrom)
            if bDebugMessages == true then LOG(sFunctionRef..': Considering iCurMex='..iCurMex..'; tMexLocation='..repr(tMexLocation)..'; iCurDistanceFromUnit='..iCurDistanceFromUnit..'; iMaxDistanceFromUnit='..iMaxDistanceFromUnit..'; iMinDistanceFromUnit='..iMinDistanceFromUnit) end
            if iCurDistanceFromUnit <= iMaxDistanceFromUnit then
                if iCurDistanceFromUnit < iMinDistanceFromUnit then
                    --Is it valid (i.e. no-one has built on it)?
                    --M27Conditions.IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed)
                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if iCurMex is unclaimed, iCurMex='..iCurMex..'; MexLocation='..repr(tMexByPathingAndGrouping[sPathing][iUnitPathGroup][iCurMex])) end
                    --IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
                    if M27Conditions.IsMexUnclaimed(aiBrain, tMexLocation, bCanBeBuiltOnByEnemy, bCanBeBuiltOnByAlly, bCanBeQueuedToBeBuilt) == true then
                        bValidMex = true
                        if bDebugMessages == true then LOG(sFunctionRef..': Have a valid mex, seeing if its in the list of mexes to ignore.  tMexPosition='..repr(tMexLocation)..'; tMexesToIgnore='..repr(tMexesToIgnore)) end
                        if bCheckListOfMexesToIgnore == true then
                            for iAltMex, tAltMex in tMexesToIgnore do
                                if bDebugMessages == true then LOG(sFunctionRef..': tMexLocation='..repr(tMexLocation)..'; tAltMex='..repr(tAltMex)) end
                                if tAltMex[1] == tMexLocation[1] and tAltMex[3] == tMexLocation[3] then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Mexes are the same location') end
                                    bValidMex = false
                                    break
                                end
                            end
                        end
                        if bValidMex == true then
                            if bDebugMessages == true then LOG(sFunctionRef..'; iCurMex is unclaimed; iCurMex='..iCurMex) end
                            iMinDistanceFromUnit = iCurDistanceFromUnit
                            iNearestMexFromUnit = iCurMex
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': iCurMex is unclaimed but we want to ignore it') end
                        end
                    else if bDebugMessages == true then LOG(sFunctionRef..': iCurMex is claiemd already, iCurMex='..iCurMex) end
                    end
                end
            end
        end
    end
    if bDebugMessages == true then
        if iNearestMexFromUnit == nil then LOG(sFunctionRef..': Nearest mex is nil')
        else LOG(sFunctionRef..'iNearestMexFromUnit='..iNearestMexFromUnit) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if iNearestMexFromUnit == nil then return nil
    else return tMexByPathingAndGrouping[sPathing][iUnitPathGroup][iNearestMexFromUnit] end
end

function IsUnderwater(tPosition, bReturnSurfaceHeightInstead)
    --Returns true if tPosition underwater, otherwise returns false
    --bReturnSurfaceHeightInstead:: Return the actual height at which underwater, instead of true/false
    if bReturnSurfaceHeightInstead then return iMapWaterHeight
    else
        if M27Utilities.IsTableEmpty(tPosition) == true then
            M27Utilities.ErrorHandler('tPosition is empty')
        else
            if iMapWaterHeight > tPosition[2] then
                --Check we're not just under an arch but are actually underwater
                if not(GetTerrainHeight(tPosition[1], tPosition[3]) == iMapWaterHeight) then
                    return true
                end
            end
        end
        return false
    end
end

function GetNearestPathableLandPosition(oPathingUnit, tTravelTarget, iMaxSearchRange)
    --Looks for a position with >0 surface height within iMaxSearchRange of oPathingUnit
    --first looks in a straight line along tTravelTarget, and only if no match does it consider looking left, right and behind
    --Returns nil if cant find target
    local sFunctionRef = 'GetNearestPathableLandPosition'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tValidTarget
    if oPathingUnit and not(oPathingUnit.Dead) and M27Utilities.IsTableEmpty(tTravelTarget)==false and iMaxSearchRange then
        local iDistanceForEachCheckLow = 2.5
        local iDoublingDistanceCheckThreshold = 4
        local iHigherThanMaxDistanceCycle = iMaxSearchRange / iDistanceForEachCheckLow
        local iAngleToPath
        local tCurPosition
        local tStartPosition = oPathingUnit:GetPosition()
        local bFoundTarget = false
        for iAngleCycle = 1, 4 do
            if iAngleCycle == 1 then iAngleToPath = 0
                elseif iAngleCycle == 2 then iAngleToPath = 90
                elseif iAngleCycle == 3 then iAngleToPath = 270
                else iAngleToPath = 180
            end

            local iDistanceMod
            local bLastDistanceCycle = false
            local iLastDistanceMod = 0
            for iDistanceCycle = 1, iHigherThanMaxDistanceCycle do
                iDistanceMod = iLastDistanceMod + iDistanceForEachCheckLow
                if iDistanceCycle > iDoublingDistanceCheckThreshold then iDistanceMod = iDistanceMod + iDistanceForEachCheckLow end
                if iDistanceCycle > iMaxSearchRange then iDistanceCycle = iMaxSearchRange bLastDistanceCycle = true end

                tCurPosition = M27Utilities.MoveTowardsTarget(tStartPosition, tTravelTarget, iDistanceMod, iAngleToPath)
                if M27Utilities.IsTableEmpty(tCurPosition) == false then
                    if IsUnderwater(tCurPosition) == false then
                        bFoundTarget = true
                        tValidTarget = tCurPosition
                        break
                    end
                end

                iLastDistanceMod = iDistanceMod
                if bLastDistanceCycle == true then break end
            end
            if bFoundTarget == true then break end
        end
    else
        --Error handling:
        if oPathingUnit == nil then M27Utilities.ErrorHandler('Pathing unit is nil')
        elseif oPathingUnit.Dead then M27Utilities.ErrorHandler('Pathing unit is dead')
        elseif M27Utilities.IsTableEmpty(tTravelTarget) == true then M27Utilities.ErrorHandler('Travel target is empty')
        elseif iMaxSearchRange == nil then M27Utilities.ErrorHandler('iMaxSearchRange is nil')
        end
    end
    --Redundancy - check in same pathing group:
    if tValidTarget then if InSameSegmentGroup(oPathingUnit, tValidTarget, false) == false then tValidTarget = nil end end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tValidTarget
end

function FindEmptyPathableAreaNearTarget(aiBrain, oPathingUnit, tStartPosition, iAreaRadius)
    --Looks for an area that contains no buildings (that we know of) that oPathingUnit can path to
    --NOTE: Very similar in method to FindRandomPlaceToBuild

    --tries finding somewhere with enough space to build sBuildingBPToBuild - e.g. to be used as a backup when fail to find adjacency location
    --Can also be used for general movement
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'FindEmptyPathableAreaNearTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local rPlayableArea = rMapPlayableArea
    local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
    local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]
    local iMapBoundMaxX = iMapSizeX - 4
    local iMapBoundMaxZ = iMapSizeZ - 4
    local iMapBoundMinX = rPlayableArea[1] + 2
    local iMapBoundMinZ = rPlayableArea[2] + 2
    local tTargetLocation = {} --{tStartPosition[1], tStartPosition[2], tStartPosition[3]}
    local iSearchSize = 4
    local iRandomX, iRandomZ
    local iCycleSize = 8
    local iSignageX, iSignageZ
    local iMaxCycles = 5
    local iValidLocationCount = 0
    local tValidLocation = {}

    local sPathing
    local iGroupCycleCount = 0

    local tSignageX = {1, 1, 1, 0, -1, -1, -1, 0}
    local tSignageZ = {1, 0, -1, -1, -1, 0, 1, 1}
    local iRandomDistance

    if oPathingUnit and not(oPathingUnit.Dead) and oPathingUnit.GetUnitId then
        sPathing = M27UnitInfo.GetUnitPathingType(oPathingUnit)
        local tUnitPosition = oPathingUnit:GetPosition()
        local iUnitSegmentX, iUnitSegmentZ = GetPathingSegmentFromPosition(tUnitPosition)
        local iUnitPathingGroup = GetSegmentGroupOfTarget(sPathing, iUnitSegmentX, iUnitSegmentZ)
        local iTargetPathingGroup
        local iTargetSegmentX, iTargetSegmentZ
        local tNearbyStructures
        while iValidLocationCount == 0 do
            iGroupCycleCount = iGroupCycleCount + 1
            if bDebugMessages == true then LOG(sFunctionRef..': Start of main loop grouping, iGroupCycleCount='..iGroupCycleCount..'; iCycleSize='..iCycleSize) end
            if iGroupCycleCount > iMaxCycles then
                M27Utilities.ErrorHandler('Possible infinite loop - unable to find empty pathable area despite iSearchSizeMax='..iSearchSizeMax)
                break
            end
            iRandomDistance = iSearchSize
            for iCurSizeCycleCount = 1, iCycleSize do
                iSignageX = tSignageX[iCurSizeCycleCount]
                iSignageZ = tSignageZ[iCurSizeCycleCount]
                iRandomX = iRandomDistance * iSignageX + tStartPosition[1]
                iRandomZ = iRandomDistance * iSignageZ + tStartPosition[3]
                if iRandomX < iMapBoundMinX then iRandomX = iMapBoundMinX
                elseif iRandomX > iMapBoundMaxX then iRandomX = iMapBoundMaxX end
                if iRandomZ < iMapBoundMinZ then iRandomZ = iMapBoundMinZ
                elseif iRandomZ > iMapBoundMaxZ then iRandomZ = iMapBoundMaxZ end

                tTargetLocation = {iRandomX, GetTerrainHeight(iRandomX, iRandomZ), iRandomZ}
                iTargetSegmentX, iTargetSegmentZ = GetPathingSegmentFromPosition(tTargetLocation)
                iTargetPathingGroup = GetSegmentGroupOfTarget(sPathing, iTargetSegmentX, iTargetSegmentZ)
                if iTargetPathingGroup == iUnitPathingGroup then
                    --Check if any structures near here
                    tNearbyStructures = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, tTargetLocation, iAreaRadius, 'Enemy')
                    if M27Utilities.IsTableEmpty(tNearbyStructures) == true then
                        if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, tTargetLocation, iAreaRadius, 'Ally')) == true then
                            if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, tTargetLocation, iAreaRadius, 'Neutral')) == true then
                                iValidLocationCount = iValidLocationCount + 1
                                tValidLocation[1] = tTargetLocation[1]
                                tValidLocation[2] = tTargetLocation[2]
                                tValidLocation[3] = tTargetLocation[3]
                                break --Just interested in the first one for this (unlike construction variant where we prioritise locations)
                            end
                        end
                    end
                end
                if iCurSizeCycleCount == iCycleSize then
                    iSearchSize = math.max(iSearchSize * 1.25, iSearchSize + 10)
                end
                if bDebugMessages == true then M27Utilities.DrawLocation(tTargetLocation) end
            end
        end
    else
        M27Utilities.ErrorHandler('Invalid pathing unit, returning start position instead')
    end
    if M27Utilities.IsTableEmpty(tValidLocation) == true then
        tValidLocation = PlayerStartPoints[aiBrain.M27StartPositionNumber]
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tValidLocation
end

function RecordMexesInPathingGroupFilteredByEnemyDistance(aiBrain, sPathing, iPathingGroup, iMinDistanceFromEnemy, iMaxDistanceFromEnemy)
    --reftMexesInPathingGroupFilteredByDistanceToEnemy = 'M27MexesInPathingGroupFilteredByDistanceToEnemy' --local to aiBrain; [sPathing][iPathingGroup][iMinRangeFromEnemy][iMaxRangeFromEnemy][iMexCount] returns Mex Location
    local sFunctionRef = 'RecordMexesInPathingGroupFilteredByEnemyDistance'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iCurDistanceToEnemy
    if M27Utilities.IsTableEmpty(aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing]) == false
            and M27Utilities.IsTableEmpty(aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup]) == false
            and M27Utilities.IsTableEmpty(aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup][iMinDistanceFromEnemy]) == false
            and M27Utilities.IsTableEmpty(aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup][iMinDistanceFromEnemy][iMaxDistanceFromEnemy]) == false then
        --Do nothing
    else
        --Create new table
        if M27Utilities.IsTableEmpty(aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy]) == true then aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy] = {} end
        if M27Utilities.IsTableEmpty(aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing]) == true then aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing] = {} end
        if M27Utilities.IsTableEmpty(aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup]) == true then aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup] = {} end
        if M27Utilities.IsTableEmpty(aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup][iMinDistanceFromEnemy]) == true then aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup][iMinDistanceFromEnemy] = {} end
        aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup][iMinDistanceFromEnemy][iMaxDistanceFromEnemy] = {}
        local iValidMexCount = 0
        local tEnemyStartPosition = PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]
        for iMex, tMexLocation in tMexByPathingAndGrouping[sPathing][iPathingGroup] do
            iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tEnemyStartPosition, tMexLocation)
            if iCurDistanceToEnemy >= iMinDistanceFromEnemy and iCurDistanceToEnemy <= iMaxDistanceFromEnemy then
                iValidMexCount = iValidMexCount + 1
                aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup][iMinDistanceFromEnemy][iMaxDistanceFromEnemy][iValidMexCount] = tMexLocation
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordSortedMexesInOriginalPathingGroup(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordSortedMexesInOriginalPathingGroup'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tUnsortedMexDetails = {}
    local refiMexLocation = 1
    local refiMexDistance = 2

    local oACU = M27Utilities.GetACU(aiBrain)
    local sPathing = M27UnitInfo.GetUnitPathingType(oACU)
    local iPathingGroup = aiBrain[refiStartingSegmentGroup][sPathing]
    local iCurDistanceToOurStart, iCurDistanceToEnemy, iCurModDistanceValue
    local tOurStartPos = PlayerStartPoints[aiBrain.M27StartPositionNumber]
    local tEnemyStartPosition = PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]

    --First determine how far away each mex is from us and enemy:

    --tMexByPathingAndGrouping = {} --Stores position of each mex based on the segment that it's part of; [a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
    if bDebugMessages == true then
        LOG(sFunctionRef..'; sPathing='..sPathing)
        LOG('iPathingGroup='..iPathingGroup)
    end
    for iMex, tMexLocation in tMexByPathingAndGrouping[sPathing][iPathingGroup] do
        tUnsortedMexDetails[iMex] = {}
        tUnsortedMexDetails[iMex][refiMexLocation] = tMexLocation
        iCurDistanceToOurStart = M27Utilities.GetDistanceBetweenPositions(tMexLocation, tOurStartPos)
        iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tMexLocation, tEnemyStartPosition)
        iCurModDistanceValue = iCurDistanceToOurStart - math.min(iCurDistanceToEnemy, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase])
        tUnsortedMexDetails[iMex][refiMexDistance] = iCurModDistanceValue
    end

    --Now sort the above table and record as a new (sorted) table that can access more generally
    --SortTableBySubtable(tTableToSort, sSortByRef, bLowToHigh)
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
    local iSortedCount = 0
    aiBrain[reftSortedMexesInOriginalGroup] = {}
    for iEntry, tValue in M27Utilities.SortTableBySubtable(tUnsortedMexDetails, refiMexDistance, true) do
        iSortedCount = iSortedCount + 1
        aiBrain[reftSortedMexesInOriginalGroup][iSortedCount] = {}
        aiBrain[reftSortedMexesInOriginalGroup][iSortedCount] = tValue[refiMexLocation]
        if bDebugMessages == true then LOG(sFunctionRef..': iEntry='..iEntry..'; Distance='..tValue[refiMexDistance]..'; Location='..repr(tValue[refiMexLocation])) end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Have '..table.getn(tMexByPathingAndGrouping[sPathing][iPathingGroup])..' mexes in MexByPathingAndGrouping, and iSortedCount='..iSortedCount) end

    --Now record mexes that we want to maintain scouts for
    if M27Utilities.IsTableEmpty(aiBrain[reftMexesToKeepScoutsBy]) == true then
        aiBrain[reftMexesToKeepScoutsBy] = {}
        local sPathingType = M27UnitInfo.refPathingTypeLand
        local iStartPathingGroup = GetSegmentGroupOfLocation(sPathingType, PlayerStartPoints[aiBrain.M27StartPositionNumber])
        local sLocationRef
        local iMinDistanceFromBase = 40
        local tNearbyMexes
        local iNearbyMexSearchRange = 15 --Wont assign a scout to a mex if it's already covered by another mex within this range
        local bHaveNearbyAssignedMex
        local sNearbyLocationRef
        local iCurDistanceToEnemy, iCurDistanceToStart
        if bDebugMessages == true then LOG(sFunctionRef..': sPathingType='..sPathingType..'; iStartPathingGroup='..iStartPathingGroup..'; tMexByPathingAndGrouping='..repr(aiBrain[tMexByPathingAndGrouping])) end

        for iMex, tMex in tMexByPathingAndGrouping[sPathingType][iStartPathingGroup] do
            iCurDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tMex, tOurStartPos)
            if bDebugMessages == true then LOG(sFunctionRef..': iMex='..iMex..'; tMex='..repr(tMex)..'; iCurDistanceToStart='..iCurDistanceToStart) end
            if iCurDistanceToStart > iMinDistanceFromBase then
                --Are we closer to us than enemy?
                iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tMex, tEnemyStartPosition)
                if bDebugMessages == true then LOG(sFunctionRef..': iCurDistanceToEnemy='..iCurDistanceToEnemy) end
                if iCurDistanceToStart <= iCurDistanceToEnemy then
                    sLocationRef = M27Utilities.ConvertLocationToReference(tMex)
                    bHaveNearbyAssignedMex = false
                    if bDebugMessages == true then LOG(sFunctionRef..': About to check if near another mex that have already assigned') end
                    for iNearbyMex, tNearbyMex in tMexByPathingAndGrouping[sPathingType][iStartPathingGroup] do
                        sNearbyLocationRef = M27Utilities.ConvertLocationToReference(tNearbyMex)
                        if M27Utilities.IsTableEmpty(aiBrain[reftMexesToKeepScoutsBy][sNearbyLocationRef]) == false then
                            if M27Utilities.GetDistanceBetweenPositions(tNearbyMex, tMex) <= iNearbyMexSearchRange then
                                if bDebugMessages == true then LOG(sFunctionRef..': sLocationRef='..sLocationRef..'; sNearbyLocationRef='..sNearbyLocationRef..'; tNearbyMex='..repr(tNearbyMex)..'; already have an entry for this in reftMexesToKeepScoutsBy='..repr(aiBrain[reftMexesToKeepScoutsBy][sNearbyLocationRef])) end
                                bHaveNearbyAssignedMex = true
                                break
                            end
                        end
                    end
                    if bHaveNearbyAssignedMex == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': Dont have nearby mex so will record this one, sLocationRef='..sLocationRef) end
                        aiBrain[reftMexesToKeepScoutsBy][sLocationRef] = {}
                        aiBrain[reftMexesToKeepScoutsBy][sLocationRef][1] = tMex[1]
                        aiBrain[reftMexesToKeepScoutsBy][sLocationRef][2] = tMex[2]
                        aiBrain[reftMexesToKeepScoutsBy][sLocationRef][3] = tMex[3]
                    end
                end
            end
        end
    end

    if bDebugMessages == true then
        if M27Utilities.IsTableEmpty(aiBrain[reftMexesToKeepScoutsBy]) == true then
            M27Utilities.ErrorHandler('No mexes on our side of map in pathing group outside core mexes - likely error unless unusual map setup', nil, true)
        else
            LOG(sFunctionRef..': Finished recording mexes to keep scouts by='..repr(aiBrain[reftMexesToKeepScoutsBy])..'; count='..table.getn(aiBrain[reftMexesToKeepScoutsBy]))
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordStartingPathingGroups(aiBrain)
    --For now will just do amphibious
    aiBrain[refiStartingSegmentGroup] = {}
    aiBrain[refiStartingSegmentGroup][M27UnitInfo.refPathingTypeAmphibious] = GetUnitSegmentGroup(M27Utilities.GetACU(aiBrain))
end

function GetMexPatrolLocations(aiBrain, iMexRallyPointsToAdd, bIncludeRallyPoint)
    --Returns a table of mexes on our side of the map near middle of map to patrol; will add up to iMexRallyPointsToAdd, and also if bIncludeRallyPoint is true will include the last rally point
    local sFunctionRef = 'GetMexPatrolLocations'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if M27Utilities.IsTableEmpty(aiBrain[reftMexPatrolLocations]) then
        --Cycle through mexes on our side of the map:
        aiBrain[reftMexPatrolLocations] = {}
        local tStartPosition = PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local oACU = M27Utilities.GetACU(aiBrain)
        local sPathing = M27UnitInfo.GetUnitPathingType(oACU)
        local iSegmentGroup = GetSegmentGroupOfLocation(sPathing, tStartPosition)
        local iCurDistanceToEnemy, iCurDistanceToStart

        local tEnemyStartPosition = PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]
        local iMaxTotalDistance = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 1.3
        local iPossibleMexCount = 0
        local tPossibleMexDetails = {}
        local reftPossibleMexLocation = 'M27GetMexPatrolMexLocation'
        local refiMexDistanceToEnemy = 'M27GetMexPatrolMexDistanceToEnemy'
        local iMinDistanceFromBase = 50
        local iValidMexCount = 0
        if bDebugMessages == true then LOG(sFunctionRef..': Before loop through mexes; sPathing='..sPathing..'; iSegmentGroup='..iSegmentGroup) end
        if M27Utilities.IsTableEmpty(tMexByPathingAndGrouping[sPathing]) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': tMexByPathingAndGrouping[sPathing] isnt empty; table='..repr(tMexByPathingAndGrouping[sPathing])) end
            if M27Utilities.IsTableEmpty(tMexByPathingAndGrouping[sPathing][iSegmentGroup]) == false then
                if bDebugMessages == true then LOG(sFunctionRef..': List of mexes that are considering='..repr(tMexByPathingAndGrouping[sPathing][iSegmentGroup])) end
                for iMex, tMexLocation in tMexByPathingAndGrouping[sPathing][iSegmentGroup] do
                    iCurDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tStartPosition, tMexLocation)
                    iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tEnemyStartPosition, tMexLocation)
                    if bDebugMessages == true then LOG(sFunctionRef..': iCurDistanceToStart='..iCurDistanceToStart..'; iCurDistanceToEnemy='..iCurDistanceToEnemy..'; iMaxTotalDistance='..iMaxTotalDistance) end
                    if iCurDistanceToStart <= iCurDistanceToEnemy then
                        if iCurDistanceToStart + iCurDistanceToEnemy <= iMaxTotalDistance then --Want to be along midpoint of path from our base to enemy base
                            if iCurDistanceToStart >= iMinDistanceFromBase then
                                iPossibleMexCount = iPossibleMexCount + 1
                                tPossibleMexDetails[iPossibleMexCount] = {}
                                tPossibleMexDetails[iPossibleMexCount][reftPossibleMexLocation] = tMexLocation
                                tPossibleMexDetails[iPossibleMexCount][refiMexDistanceToEnemy] = iCurDistanceToEnemy
                            end
                        end
                    end
                end
            end
        end
        if iPossibleMexCount > 0 then
            --Filter to choose the iMexRallyPointsToAdd mexes closest to enemy (s.t. previous requirements that theyre closer to our base than enemy base)
            if bDebugMessages == true then LOG(sFunctionRef..': iPossibleMexCount='..iPossibleMexCount..'; tPossibleMexDetails='..repr(tPossibleMexDetails)) end
            for iEntry, tValue in M27Utilities.SortTableBySubtable(tPossibleMexDetails, refiMexDistanceToEnemy, true) do
                iValidMexCount = iValidMexCount + 1
                aiBrain[reftMexPatrolLocations][iValidMexCount] = tValue[reftPossibleMexLocation]
                if iValidMexCount >= iMexRallyPointsToAdd then break end
            end
        else
            M27Utilities.ErrorHandler('Couldnt find any mexes along the line from our base to enemy base, so will pick enemy start position as the patrol point')
            aiBrain[reftMexPatrolLocations][1] = tEnemyStartPosition
        end
    end

    local tPatrolLocations = {}
    --Copy the tables just in case we end up clearing them and it causes issues
    for iEntry, tEntry in aiBrain[reftMexPatrolLocations] do
        tPatrolLocations[iEntry] = {}
        tPatrolLocations[iEntry][1] = tEntry[1]
        tPatrolLocations[iEntry][2] = tEntry[2]
        tPatrolLocations[iEntry][3] = tEntry[3]
    end
    --Add the nearest rally poitn to the enemy base as a patrol location
    table.insert(tPatrolLocations, M27Logic.GetNearestRallyPoint(aiBrain, PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]))
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tPatrolLocations
end


--[[function RecordSegmentGroup(iSegmentX, iSegmentZ, sPathingType, iSegmentGroup)
    --Cycle through all adjacent cells, and then call this function on them as well
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordSegmentGroup'
    if bDebugMessages == true then LOG(sFunctionRef..': About to record iSegmentX='..iSegmentX..'; iSegmentZ='..iSegmentZ..'; iSegmentGroup='..iSegmentGroup..'; and then check if can path to adjacent segments') end
    tPathingSegmentGroupBySegment[sPathingType][iSegmentX][iSegmentZ] = iSegmentGroup

    local tAllAdjacentSegments = {
        {iSegmentX - 1, iSegmentZ},
        {iSegmentX + 1, iSegmentZ},
        {iSegmentX, iSegmentZ - 1},
        {iSegmentX, iSegmentZ + 1}
    }

    --Dont check if are at map edge
    if iSegmentX >= iMaxBaseSegmentX or iSegmentZ >= iMaxBaseSegmentZ or iSegmentX < 2 or iSegmentZ < 2 then
        tAllAdjacentSegments = {}
        tbPathingAlongZNotX = {}
        if iSegmentX > 2 then
            table.insert(tAllAdjacentSegments, {iSegmentX - 1, iSegmentZ})
        end
        if iSegmentX < iMaxBaseSegmentX then
            table.insert(tAllAdjacentSegments, {iSegmentX + 1, iSegmentZ})
        end
        if iSegmentZ > 2 then
            table.insert(tAllAdjacentSegments, {iSegmentX, iSegmentZ - 1})
        end
        if iSegmentZ < iMaxBaseSegmentZ then
            table.insert(tAllAdjacentSegments, {iSegmentX, iSegmentZ + 1})
        end
    end

    local tCurPosition = GetPositionFromPathingSegments(iSegmentX, iSegmentZ)
    local tTargetPosition
    LOG('Number of adjacent segments='..table.getn(tAllAdjacentSegments))
    for iEntry, tAdjacentSegment in tAllAdjacentSegments do
    --]]
        --if tPathingSegmentGroupBySegment[sPathingType][tAdjacentSegment[1]][tAdjacentSegment[2]] == nil then
--[[            if bDebugMessages == true then LOG(sFunctionRef..': Have no entry yet for XZ='..tAdjacentSegment[1]..'-'..tAdjacentSegment[2]..' so will see if we can path there') end
            tTargetPosition = GetPositionFromPathingSegments(tAdjacentSegment[1], tAdjacentSegment[2])
            if IsLandPathableAlongLine(tCurPosition[1], tTargetPosition[1], tCurPosition[3], tTargetPosition[3]) then
                RecordSegmentGroup(tAdjacentSegment[1], tAdjacentSegment[2], sPathingType, iSegmentGroup)
            end
        end
    end
end--]]

function RecordBaseLevelPathability()
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --Manually uncomment out logs that want - disabled for performance reasons for the most part
    local sFunctionRef = 'RecordBaseLevelPathability'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Setup some common logic used to see if it makes things faster
    local Max = math.max
    local Min = math.min
    local Ceil = math.ceil
    --local Floor = math.floor
    local Abs = math.abs

    --First determine the maximum height adjustment to use
    DetermineMaxTerrainHeightDif()


    local iSegmentBaseLevelCap = iBaseLevelSegmentCap --i.e. want up to this x this segments at base level
    local rPlayableArea = rMapPlayableArea
    local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
    local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]
    local iSegmentSizeBaseLevel
    local iHighestMapSize = Max(iMapSizeX, iMapSizeZ)
    if iHighestMapSize <= iSegmentBaseLevelCap then iSegmentSizeBaseLevel = 1
    else
        iSegmentSizeBaseLevel = Ceil(iHighestMapSize / iSegmentBaseLevelCap)
    end
    iSizeOfBaseLevelSegment = iSegmentSizeBaseLevel
    iMaxSegmentInterval = math.max(iMapSizeX, iMapSizeZ) / iSizeOfBaseLevelSegment

    local iMaxSegmentX = Ceil(iMapSizeX / iSegmentSizeBaseLevel)
    local iMaxSegmentZ = Ceil(iMapSizeZ / iSegmentSizeBaseLevel)
    iMaxBaseSegmentX = iMaxSegmentX
    iMaxBaseSegmentZ = iMaxSegmentZ



   --Land pathing
    --tPathingSegmentGroupBySegment = {} --[a][b][c]: a = pathing type; b = segment x, c = segment z
    --First set table varaibles
    --local sPathingType = M27UnitInfo.refPathingTypeLand




    --Start at first segment, and see what segments can be pathed to it
    local tRecursivePosition = {}
    table.setn(tRecursivePosition, iMaxSegmentX * iMaxSegmentZ)

    local iCurPathingGroup = iLandPathingGroupForWater
    local iCurRecursivePosition = 1
    local iSegmentX, iSegmentZ
    local tCurPosition, tTargetPosition
    local bHaveSubsequentPath
    --Its marginally quicker to check water height as part of the 'pathable moving in a line' function, testing on Africa map
    --[[for iBaseSegmentX = 1, iMaxSegmentX do
        for iBaseSegmentZ = 1, iMaxSegmentZ do
            tCurPosition = GetPositionFromPathingSegments(iBaseSegmentX, iBaseSegmentZ)
            iCurTerrainHeight = GetTerrainHeight(tCurPosition[1], tCurPosition[3])
            iCurSurfaceHeight = GetSurfaceHeight(tCurPosition[1], tCurPosition[3])
            if iCurTerrainHeight < iCurSurfaceHeight then
                tPathingSegmentGroupBySegment[sPathingType][iBaseSegmentX][iBaseSegmentZ] = iLandPathingGroupForWater
            end
        end
    end--]]

    if bDebugMessages == true then LOG(sFunctionRef..': iMaxSegmentX='..iMaxSegmentX..'; iMaxSegmentZ='..iMaxSegmentZ) end
    local sPathingLand = M27UnitInfo.refPathingTypeLand
    local sPathingAmphibious = M27UnitInfo.refPathingTypeAmphibious
    local sPathingNavy = M27UnitInfo.refPathingTypeNavy
    local sAllPathingTypes = {sPathingLand, sPathingAmphibious, sPathingNavy}
    --local sAllPathingTypes = {sPathingLand, sPathingAmphibious}
    local bCheckForWater, bCheckForLand, bLandPathing, bAmphibPathing, bNavyPathfinding
    local bWaterOrLandCheck
    local bMapContainsWater = bMapHasWater

    --Navy - want to search area around target to see if its underwater - predefine the table of entries to consider
    tGeneralAreaAroundTargetAdjustments = {}
    for iXAdj = -iHeightDifAreaSize, iHeightDifAreaSize, iHeightDifAreaSize * 2 do
        for iZAdj = -iHeightDifAreaSize, iHeightDifAreaSize, iHeightDifAreaSize * 2 do
            table.insert(tGeneralAreaAroundTargetAdjustments, {iXAdj, iZAdj})
        end
    end
    tWaterAreaAroundTargetAdjustments = {}
    for iXAdj = -iWaterMinArea, iWaterMinArea, iWaterMinArea * 2 do
        for iZAdj = -iWaterMinArea, iWaterMinArea, iWaterMinArea * 2 do
            if not(iXAdj == 0 and iZAdj ==0) then
                table.insert(tWaterAreaAroundTargetAdjustments, {iXAdj, iZAdj})
            end
        end
    end

    if bDebugMessages == true then
        LOG(sFunctionRef..': tGeneralAreaAroundTargetAdjustments='..repr(tGeneralAreaAroundTargetAdjustments))
        LOG(sFunctionRef..': tWaterAreaAroundTargetAdjustments='..repr(tWaterAreaAroundTargetAdjustments))
    end

    --Setup localised versions of global variables used by IsXPathableAlongLine
    local iMaxDifInHeight = iMaxHeightDif
    local iDifInHeightThreshold = iLowHeightDifThreshold
    local iIntervalSize = iPathingIntervalSize
    local iNavyMinWaterDepth = iMinWaterDepth
    local tAdjustmentsForArea = tGeneralAreaAroundTargetAdjustments
    local tAreaAdjToSearch = tWaterAreaAroundTargetAdjustments
    local iMinAreaSize = iWaterMinArea
    local iMapSizeX, iMapSizeZ = GetMapSize() --use map size instead of playable area as only interested in not causing error by trying to get non existent value


    function IsAmphibiousPathableAlongLine(xStartInteger, xEndInteger, zStartInteger, zEndInteger)--, bForceDebug)
        --This is mostly a copy of land pathing but with changes for water
        --local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        --local sFunctionRef = 'IsAmphibiousPathableAlongLine'
        --if bForceDebug then bDebugMessages = true end

        local iCurDifInHeight
        local iIntervalX = xEndInteger - xStartInteger
        local iIntervalZ = zEndInteger - zStartInteger
        local iCurTerrainHeight
        local iNextTerrainHeight

        local iXFactor = 0
        local iZFactor = 0
        local iIntervalMax = Max(Abs(iIntervalX), Abs(iIntervalZ))
        if iIntervalX < 0 then iXFactor = -1 elseif iIntervalX > 0 then iXFactor = 1 end
        if iIntervalZ < 0 then iZFactor = -1 elseif iIntervalZ > 0 then iZFactor = 1 end

        local iNextX, iNextZ
        local iCurX = xStartInteger
        local iCurZ = zStartInteger

        local sTerrainType

        --Are we moving from water to land?
        local bMovingBetweenLandAndWater = false
        local iCurSurfaceHeight = GetSurfaceHeight(iCurX, iCurZ)
        if GetTerrainHeight(iCurX, iCurZ) < iCurSurfaceHeight then --currently underwater
            if GetTerrainHeight(xEndInteger, zEndInteger) >= iCurSurfaceHeight then --surface height of water is same everywhere
                bMovingBetweenLandAndWater = true
            end
        else --currently on land
            if GetTerrainHeight(xEndInteger, zEndInteger) < GetSurfaceHeight(xEndInteger, zEndInteger) then
                bMovingBetweenLandAndWater = true
            end
        end
        --if bDebugMessages == true then LOG(sFunctionRef..': bMovingBetweenLandAndWater='..tostring(bMovingBetweenLandAndWater)..'; Terrain height at start='..GetTerrainHeight(iCurX, iCurZ)..'; surface height at start='..GetSurfaceHeight(iCurX, iCurZ)..'; terrain height at end='..GetTerrainHeight(xEndInteger, zEndInteger)..'; Surface height at end='..GetSurfaceHeight(xEndInteger, zEndInteger)) end
        local iAdjCurHeight, iAdjTargetHeight
        local iMaxHeight, iMinHeight
        --if bDebugMessages == true then LOG(sFunctionRef..': xStartInteger='..xStartInteger..'; xEndInteger='..xEndInteger..'; zStartInteger='..zStartInteger..';, zEndInteger='..zEndInteger) end
        for iInterval = iIntervalSize, iIntervalMax, iIntervalSize do
            if iInterval == iIntervalSize then
                --if bDebugMessages == true then LOG(sFunctionRef..': iCurX-Z pos='..iCurX..'-'..iCurZ..'; TerrainHeight='..GetTerrainHeight(iCurX, iCurZ)..'; Surface height='..GetSurfaceHeight(iCurX, iCurZ)) end
                iCurTerrainHeight = Max(GetTerrainHeight(iCurX, iCurZ), GetSurfaceHeight(iCurX, iCurZ))
                sTerrainType = GetTerrainType(iCurX,iCurZ)['Name']
                if sTerrainType == 'Dirt09' or sTerrainType == 'Lava01' then return false end
            else
                iCurTerrainHeight = iNextTerrainHeight
                iCurX = iNextX
                iCurZ = iNextZ
            end
            --if bDebugMessages == true then LOG(sFunctionRef..': CurPosition='..repr({iCurX, iCurTerrainHeight, iCurZ})) end
            iNextX = iCurX + iIntervalSize * iXFactor
            iNextZ = iCurZ + iIntervalSize * iZFactor
            iNextTerrainHeight = Max(GetTerrainHeight(iNextX, iNextZ), GetSurfaceHeight(iNextX, iNextZ))
            --if bDebugMessages == true then LOG(sFunctionRef..': NextPosition='..repr({iNextX, iNextTerrainHeight, iNextZ})..'; iMaxDifInHeight='..iMaxDifInHeight) end
            iCurDifInHeight = Abs(iCurTerrainHeight - iNextTerrainHeight)
            if iCurDifInHeight > iMaxDifInHeight then
                --if bDebugMessages == true then LOG(sFunctionRef..': Abs dif between current and next terrain height is greater than iMaxDifInHeight') end
                return false
            elseif bMovingBetweenLandAndWater and iCurDifInHeight > iDifInHeightThreshold then
                --Check for area around this to see if exceed the max dif in height threshold if we're moving from land to water or vice versa
                --if bDebugMessages == true then LOG(sFunctionRef..': iCurDifInHeight='..iCurDifInHeight..': Therefore considering height dif of all nearby segments') end
                iMaxHeight = Max(iNextTerrainHeight, iCurTerrainHeight)
                iMinHeight = Min(iNextTerrainHeight, iCurTerrainHeight)
                for iAdjustment, tAreaAdjustment in tAdjustmentsForArea do
                    iAdjCurHeight = Max(GetTerrainHeight(iCurX + tAreaAdjustment[1], iCurZ + tAreaAdjustment[2]), GetSurfaceHeight(iCurX + tAreaAdjustment[1], iCurZ + tAreaAdjustment[2]))
                    iAdjTargetHeight = Max(GetTerrainHeight(iNextX + tAreaAdjustment[1], iNextZ + tAreaAdjustment[2]), GetSurfaceHeight(iNextX + tAreaAdjustment[1], iNextZ + tAreaAdjustment[2]))
                    --if bDebugMessages == true then LOG(sFunctionRef..': iCurX-Z+Adj='..iCurX + tAreaAdjustment[1]..'-'..iCurZ + tAreaAdjustment[2]..'; iNextX-Z+Adj='..iNextX + tAreaAdjustment[1]..'-'..iNextZ + tAreaAdjustment[2]..'; iAdjCurHeight='..iAdjCurHeight..'; iAdjTargetHeight='..iAdjTargetHeight) end
                    iMaxHeight = Max(iMaxHeight, iAdjCurHeight, iAdjTargetHeight)
                    iMinHeight = Min(iMinHeight, iAdjCurHeight, iAdjTargetHeight)
                    if iMaxHeight - iMinHeight > iMaxDifInHeight then
                        --if bDebugMessages == true then LOG(sFunctionRef..': iMaxHeight='..iMaxHeight..'; iMinHeight='..iMinHeight) end
                        return false
                    end
                end
            end
            --if bDebugMessages == true then LOG(sFunctionRef..': No signif dif in height, iCurDifInHeight='..iCurDifInHeight) end
            --Check terrain type as some are unpathable
            sTerrainType = GetTerrainType(iNextX,iNextZ)['Name']
            if sTerrainType == 'Dirt09' or sTerrainType == 'Lava01' then
                --if bDebugMessages == true then LOG(sFunctionRef..': Terrain type is impassable') end
                return false
            end
        end
        --if bDebugMessages == true then LOG(sFunctionRef..': Can path to the position') end
        return true
    end

    function IsLandPathableAlongLine(xStartInteger, xEndInteger, zStartInteger, zEndInteger)
        --Assumes will call for positions in a straight line from each other
        --Can handle diagonals, but x and z differences must be identical (error handler re this can be uncommented out if come across issues)
        --local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        --if bForceDebug == true then bDebugMessages = true end
        --local sFunctionRef = 'IsLandPathableAlongLine'
        --if bDebugMessages == true then LOG(sFunctionRef..': Start of code, X Start-End='..xStartInteger..'-'..xEndInteger..'; Z='..zStartInteger..'-'..zEndInteger..'; iMaxDifInHeight='..iMaxDifInHeight) end
        local iCurTerrainHeight
        local iNextTerrainHeight
        local iXFactor = 0
        local iZFactor = 0
        local iIntervalX = xEndInteger - xStartInteger
        local iIntervalZ = zEndInteger - zStartInteger
        local iIntervalMax = Max(Abs(iIntervalX), Abs(iIntervalZ))
        if iIntervalX < 0 then iXFactor = -1 elseif iIntervalX > 0 then iXFactor = 1 end
        if iIntervalZ < 0 then iZFactor = -1 elseif iIntervalZ > 0 then iZFactor = 1 end

        --if bDebugMessages == true then LOG(sFunctionRef..': xStartInteger='..xStartInteger..'; xEndInteger='..xEndInteger..'; zStartInteger='..zStartInteger..';, zEndInteger='..zEndInteger) end
        local iNextX, iNextZ
        local iCurX = xStartInteger
        local iCurZ = zStartInteger

        local sTerrainType

        for iInterval = iIntervalSize, iIntervalMax, iIntervalSize do
            if iInterval == iIntervalSize then
                iCurTerrainHeight = GetTerrainHeight(iCurX, iCurZ)
                --Are we underwater currently? We still need to check for this as the prev function loop doesnt consider all water ahead of non water
                if GetSurfaceHeight(iCurX, iCurZ) > iCurTerrainHeight then
                    --if bDebugMessages == true then LOG(sFunctionRef..': Surface height is greater than current terrain height so are underwater') end
                    return false
                end
                sTerrainType = GetTerrainType(iCurX,iCurZ)['Name']
                if sTerrainType == 'Dirt09' or sTerrainType == 'Lava01' then return false end
            else
                iCurTerrainHeight = iNextTerrainHeight
                iCurX = iNextX
                iCurZ = iNextZ
            end
            --if bDebugMessages == true then LOG(sFunctionRef..': CurPosition='..repr({iNextX, iCurTerrainHeight, iNextZ})) end
            iNextX = iCurX + iIntervalSize * iXFactor
            iNextZ = iCurZ + iIntervalSize * iZFactor
            iNextTerrainHeight = GetTerrainHeight(iNextX, iNextZ)
            --if bDebugMessages == true then LOG(sFunctionRef..': NextPosition='..repr({iNextX, iNextTerrainHeight, iNextZ})..'; iMaxDifInHeight='..iMaxDifInHeight) end
            if Abs(iCurTerrainHeight - iNextTerrainHeight) > iMaxDifInHeight then
                --if bDebugMessages == true then LOG(sFunctionRef..': Abs dif between current and next terrain height is greater than iMaxDifInHeight') end
                return false
            else
                --Are we underwater at the next position? marginally faster to check in this function than upfront before doing the line path checks
                if GetSurfaceHeight(iNextX, iNextZ) > iNextTerrainHeight then
                    --if bDebugMessages == true then LOG(sFunctionRef..': Next position is underwater') end
                    return false
                end
            end
            --Check terrain type as some are unpathable
            sTerrainType = GetTerrainType(iNextX,iNextZ)['Name']
            if sTerrainType == 'Dirt09' or sTerrainType == 'Lava01' then
                --if bDebugMessages == true then LOG(sFunctionRef..': Terrain type is impassable') end
                return false
            end
        end
        --if bDebugMessages == true then LOG(sFunctionRef..': Can path to the position') end
        return true
    end

    function IsNavyPathableAlongLine(xStartInteger, xEndInteger, zStartInteger, zEndInteger)
        --local sFunctionRef = 'IsLandPathableAlongLine'

        --local iNavyMinWaterDepth = iMinWaterDepth

        local iIntervalX = xEndInteger - xStartInteger
        local iIntervalZ = zEndInteger - zStartInteger
        --local iHeightDif
        local iXFactor = 0
        local iZFactor = 0
        local iIntervalMax = Max(Abs(iIntervalX), Abs(iIntervalZ))
        if iIntervalX < 0 then iXFactor = -1 elseif iIntervalX > 0 then iXFactor = 1 end
        if iIntervalZ < 0 then iZFactor = -1 elseif iIntervalZ > 0 then iZFactor = 1 end



        --if bDebugMessages == true then LOG(sFunctionRef..': Start of code, X Start-End='..xStartInteger..'-'..xEndInteger..'; Z='..zStartInteger..'-'..zEndInteger..'; iMaxDifInHeight='..iMaxDifInHeight) end

        local iCurTerrainHeight
        local iNextTerrainHeight
        local iCurSurfaceHeight

        --local iIntervalSize = iWaterPathingIntervalSize
        local iNextX, iNextZ
        local iCurX = xStartInteger
        local iCurZ = zStartInteger

        local iBaseNextX = iCurX
        local iBaseNextZ = iCurZ
        local sTerrainType

        --local tAreaAdjToSearch = tWaterAreaAroundTargetAdjustments
        local iAdjX, iAdjZ
        local bMapEdgeChecks = false
        --local iMinAreaSize = iWaterMinArea
        local iMaxTerrainHeight
        --local iMapSizeX, iMapSizeZ = GetMapSize() --use map size instead of playable area as only interested in not causing error by trying to get non existent value
        if Min(xStartInteger, xEndInteger, zStartInteger, zEndInteger) < iMinAreaSize or Max(xStartInteger, xEndInteger, zStartInteger, zEndInteger) + iMinAreaSize > iMapSizeX then bMapEdgeChecks = true end
        --if bDebugMessages == true then LOG(sFunctionRef..': xStartInteger='..xStartInteger..'; xEndInteger='..xEndInteger..'; zStartInteger='..zStartInteger..';, zEndInteger='..zEndInteger) end
        --local iTotalIntervals = iIntervalMax / iIntervalSize
        for iInterval = iIntervalSize, iIntervalMax, iIntervalSize do
            if iInterval == iIntervalSize then
                iCurSurfaceHeight = GetSurfaceHeight(iCurX, iCurZ)
                iCurTerrainHeight = GetTerrainHeight(iCurX, iCurZ)
                iMaxTerrainHeight = iCurSurfaceHeight - iNavyMinWaterDepth
                --Are we underwater sufficiently currently?
                if iMaxTerrainHeight < iCurTerrainHeight then
                    --if bDebugMessages == true then LOG(sFunctionRef..': Cur position isnt sufficiently underwater') end
                    return false
                end
                sTerrainType = GetTerrainType(iCurX,iCurZ)['Name']
                if sTerrainType == 'Dirt09' or sTerrainType == 'Lava01' then return false end
            else iCurTerrainHeight = iNextTerrainHeight
            end


            iBaseNextX = iBaseNextX + iIntervalSize * iXFactor
            iBaseNextZ = iBaseNextZ + iIntervalSize * iZFactor

            --Check terrain type as some are unpathable
            sTerrainType = GetTerrainType(iBaseNextX,iBaseNextZ)['Name']
            if sTerrainType == 'Dirt09' or sTerrainType == 'Lava01' then
                --if bDebugMessages == true then LOG(sFunctionRef..': Terrain type is impassable') end
                return false
            end

            --Check for an area around the target if its underwater - surface height of water is unchanged so dont need to refresh it
            for iAdjEntry, tAdjTable in tAreaAdjToSearch do
                iAdjX = tAdjTable[1]
                iAdjZ = tAdjTable[2]
                iNextX = iBaseNextX + iAdjX
                iNextZ = iBaseNextZ + iAdjZ
                if bMapEdgeChecks == true then
                    iNextX = Min(Max(0, iNextX), iMapSizeX)
                    iNextZ = Min(Max(0, iNextZ), iMapSizeZ)
                end
                iNextTerrainHeight = GetTerrainHeight(iNextX, iNextZ)
                --Are we underwater at the next position?
                if iMaxTerrainHeight < iNextTerrainHeight then
                    --if bDebugMessages == true then LOG(sFunctionRef..': Next position is not underwater') end
                    return false
                end
            end
        end


        --if bDebugMessages == true then LOG(sFunctionRef..': Can path to the position') end
        return true
    end
    
    local function RecordPathingGroup(sPathingType, iSegmentX, iSegmentZ, iPathingGroup)
        tPathingSegmentGroupBySegment[sPathingType][iSegmentX][iSegmentZ] = iPathingGroup
        if tSegmentBySegmentGroup[sPathingType][iPathingGroup] == nil then tSegmentBySegmentGroup[sPathingType][iPathingGroup] = {} end
        table.insert(tSegmentBySegmentGroup[sPathingType][iPathingGroup], {iSegmentX, iSegmentZ})
    end

    for iPathingType, sPathingType in sAllPathingTypes do
        if sPathingType == M27UnitInfo.refPathingTypeNavy then iIntervalSize = iWaterPathingIntervalSize
        else iIntervalSize = iPathingIntervalSize end

        tPathingSegmentGroupBySegment[sPathingType] = {}
        tSegmentBySegmentGroup[sPathingType] = {}
        for iSegmentX = 1, iMaxSegmentX do
            tPathingSegmentGroupBySegment[sPathingType][iSegmentX] = {}
        end
        bNavyPathfinding = false
        bLandPathing = false
        bAmphibPathing = false
        bCheckForLand = false
        if sPathingType == sPathingLand then
            bCheckForWater = true
            bLandPathing = true
        elseif sPathingType == sPathingAmphibious then
            bCheckForWater = false
            bAmphibPathing = true
        elseif sPathingType == sPathingNavy then
            bCheckForWater = true
            bCheckForLand = true
            bNavyPathfinding = true
        else M27Utilities.ErrorHandler('Need to add code')
        end

        --LOG(sFunctionRef..'; bMapContainsWater='..tostring(bMapContainsWater)..'; bLandPathing='..tostring(bLandPathing)..'; sPathingType='..sPathingType..'; sPathingAmphibious='..sPathingAmphibious)
        for iBaseSegmentX = 1, iMaxSegmentX do
            for iBaseSegmentZ = 1, iMaxSegmentZ do
                if bMapContainsWater == false and bLandPathing == false then
                    if sPathingType == sPathingAmphibious then --Copy land pathing as no water
                        tPathingSegmentGroupBySegment[sPathingType][iBaseSegmentX][iBaseSegmentZ] = tPathingSegmentGroupBySegment[sPathingLand][iBaseSegmentX][iBaseSegmentZ]
                        tSegmentBySegmentGroup[sPathingType] = tSegmentBySegmentGroup[sPathingLand]
                    elseif sPathingType == sPathingNavy then --No water so everything just land
                        tPathingSegmentGroupBySegment[sPathingType][iBaseSegmentX][iBaseSegmentZ] = iLandPathingGroupForWater
                    end
                else
                    iCurRecursivePosition = 1
                    --Check not already determined this
                    if tPathingSegmentGroupBySegment[sPathingType][iBaseSegmentX][iBaseSegmentZ] == nil then
                        bWaterOrLandCheck = true
                        iSegmentX = iBaseSegmentX
                        iSegmentZ = iBaseSegmentZ
                        tCurPosition = GetPositionFromPathingSegments(iSegmentX, iSegmentZ)
                        --Check if water, in which case allocate to water pathing group
                        if bCheckForWater == true then
                            iCurTerrainHeight = GetTerrainHeight(tCurPosition[1], tCurPosition[3])
                            iCurSurfaceHeight = GetSurfaceHeight(tCurPosition[1], tCurPosition[3])
                            if iCurTerrainHeight < iCurSurfaceHeight then
                                --Have water
                                if not(bCheckForLand) then bWaterOrLandCheck = false end
                            elseif bCheckForLand then bWaterOrLandCheck = false end
                            if bWaterOrLandCheck == false then
                                RecordPathingGroup(sPathingType, iBaseSegmentX, iBaseSegmentZ, iLandPathingGroupForWater)
                            end
                        end
                        if bWaterOrLandCheck then
                            --Not on water (if looking at land pathing)/not on land (if looking at navy pathing)
                            iCurPathingGroup = iCurPathingGroup + 1
                            --RecordSegmentGroup(iSegmentX, iSegmentZ, sPathingType, iCurPathingGroup)
                            iCurRecursivePosition = iCurRecursivePosition + 1

                            while iCurRecursivePosition > 1 do
                                bHaveSubsequentPath = false
                                RecordPathingGroup(sPathingType, iSegmentX, iSegmentZ, iCurPathingGroup)
                                local tAllAdjacentSegments = {
                                    {iSegmentX - 1, iSegmentZ -1},
                                    {iSegmentX - 1, iSegmentZ},
                                    {iSegmentX - 1, iSegmentZ +1},

                                    {iSegmentX, iSegmentZ - 1},
                                    {iSegmentX, iSegmentZ + 1},

                                    {iSegmentX + 1, iSegmentZ - 1},
                                    {iSegmentX + 1, iSegmentZ},
                                    {iSegmentX + 1, iSegmentZ + 1},

                                }


                                --if bDebugMessages == true then LOG(sFunctionRef..': iSegmentX-Z='..iSegmentX..'-'..iSegmentZ..'; iCurRecursivePosition='..iCurRecursivePosition..': About to check if are at edge of map') end
                                --Dont check if are at map edge (if we really wanted to optimise this then I expect predefined tables of all the options would work but for now I'll leave it at this
                                if iSegmentX >= iMaxSegmentX or iSegmentZ >= iMaxSegmentZ or iSegmentX < 2 or iSegmentZ < 2 then
                                    --if bDebugMessages == true then LOG(sFunctionRef..': Are at map edge so limit the adjacent segments to consider') end
                                    tAllAdjacentSegments = {}
                                    local bCanDecreaseX, bCanIncreaseX, bCanDecreaseZ, bCanIncreaseZ
                                    if iSegmentX >= 2 then bCanDecreaseX = true end
                                    if iSegmentZ >= 2 then bCanDecreaseZ = true end
                                    if iSegmentX < iMaxSegmentX then bCanIncreaseX = true end
                                    if iSegmentZ < iMaxSegmentZ then bCanIncreaseZ = true end
                                    if bCanDecreaseX then
                                        if bCanDecreaseZ then table.insert(tAllAdjacentSegments, {iSegmentX - 1, iSegmentZ -1}) end
                                        if bCanIncreaseZ then table.insert(tAllAdjacentSegments, {iSegmentX - 1, iSegmentZ +1}) end
                                        table.insert(tAllAdjacentSegments, {iSegmentX - 1, iSegmentZ})
                                    end
                                    if bCanIncreaseX then
                                        if bCanDecreaseZ then table.insert(tAllAdjacentSegments, {iSegmentX + 1, iSegmentZ -1}) end
                                        if bCanIncreaseZ then table.insert(tAllAdjacentSegments, {iSegmentX + 1, iSegmentZ +1}) end
                                        table.insert(tAllAdjacentSegments, {iSegmentX + 1, iSegmentZ})
                                    end
                                    if bCanDecreaseZ then table.insert(tAllAdjacentSegments, {iSegmentX, iSegmentZ -1}) end
                                    if bCanIncreaseZ then table.insert(tAllAdjacentSegments, {iSegmentX, iSegmentZ +1}) end
                                end


                                --if bDebugMessages == true then LOG(sFunctionRef..': iSegmentX-Z='..iSegmentX..'-'..iSegmentZ..'; iCurRecursivePosition='..iCurRecursivePosition..': Number of adjacent locations to consider='..table.getn(tAllAdjacentSegments)) end
                                for iEntry, tAdjacentSegment in tAllAdjacentSegments do
                                    --if bDebugMessages == true then LOG(sFunctionRef..': Considering adjacent segment; iEntry='..iEntry..'; tAdjacentSegment='..repr(tAdjacentSegment)) end
                                    if tPathingSegmentGroupBySegment[sPathingType][tAdjacentSegment[1]][tAdjacentSegment[2]] == nil then
                                        tTargetPosition = GetPositionFromPathingSegments(tAdjacentSegment[1], tAdjacentSegment[2])
                                        --if bDebugMessages == true then LOG(sFunctionRef..': iEntry='..iEntry..': Have no entry yet for XZ='..tAdjacentSegment[1]..'-'..tAdjacentSegment[2]..' so will see if we can path there; tTargetPosition='..repr(tTargetPosition)..'; tCurPosition='..repr(tCurPosition)..'; iSegmentXZ='..iSegmentX..'-'..iSegmentZ) end
                                        if bLandPathing then
                                            if IsLandPathableAlongLine(tCurPosition[1], tTargetPosition[1], tCurPosition[3], tTargetPosition[3]) then
                                                bHaveSubsequentPath = true
                                            end
                                        elseif bAmphibPathing then
                                            if IsAmphibiousPathableAlongLine(tCurPosition[1], tTargetPosition[1], tCurPosition[3], tTargetPosition[3]) then
                                                --BELOW COMMENTED OUT SECTIONS ARE FOR DEBUG PURPOSES ONLY - allow highlighting of sections between land and sea that are pathable to each other, and enabling of logs
                                                --[[local bCurPositionUnderwater = true
                                                local bTargetPositionUnderwater = true
                                                local bMoveFromLandToWater = false
                                                local iTerrainHeightCur = GetTerrainHeight(tCurPosition[1], tCurPosition[3])
                                                local iTerrainHeightTarget = GetTerrainHeight(tTargetPosition[1], tTargetPosition[3])
                                                local iMapWaterHeightCur = GetSurfaceHeight(tCurPosition[1], tCurPosition[3])
                                                local iMapWaterHeightTarget = GetSurfaceHeight(tTargetPosition[1], tTargetPosition[3])

                                                if iTerrainHeightCur == iMapWaterHeightCur then bCurPositionUnderwater = false end
                                                if iTerrainHeightTarget == iMapWaterHeightTarget then bTargetPositionUnderwater = false end
                                                if bCurPositionUnderwater == true and bTargetPositionUnderwater == false then bMoveFromLandToWater = true
                                                elseif bCurPositionUnderwater == false and bTargetPositionUnderwater == true then bMoveFromLandToWater = true end
                                                if bMoveFromLandToWater == true then
                                                    LOG(sFunctionRef..': Moving from land to water, tCurPosition='..repr(tCurPosition)..'; tTargetPosition='..repr(tTargetPosition)..'; iTerrainHeightCur='..iTerrainHeightCur..'; iMapWaterHeightCur='..iMapWaterHeightCur..'; iTerrainHeightTarget='..iTerrainHeightTarget..'; iMapWaterHeightTarget='..iMapWaterHeightTarget..'; will redo the logic with logs enabled')
                                                    M27Utilities.DrawLocations({tCurPosition, tTargetPosition}, nil, 1, 500)
                                                    IsAmphibiousPathableAlongLine(tCurPosition[1], tTargetPosition[1], tCurPosition[3], tTargetPosition[3], true)
                                                end--]]

                                                bHaveSubsequentPath = true
                                            end
                                        elseif bNavyPathfinding then
                                            if IsNavyPathableAlongLine(tCurPosition[1], tTargetPosition[1], tCurPosition[3], tTargetPosition[3]) then
                                                bHaveSubsequentPath = true
                                                if iMapWaterHeight == 0 then iMapWaterHeight = GetSurfaceHeight(tCurPosition[1], tCurPosition[3]) end
                                            end
                                        end
                                        if bHaveSubsequentPath then
                                            iSegmentX = tAdjacentSegment[1]
                                            iSegmentZ = tAdjacentSegment[2]
                                            break
                                        end
                                    else
                                        --if bDebugMessages == true then LOG(sFunctionRef..': Already have a pathing group which is '..tPathingSegmentGroupBySegment[sPathingType][tAdjacentSegment[1]][tAdjacentSegment[2]]) end
                                    end
                                end
                                if bHaveSubsequentPath == true then
                                    tRecursivePosition[iCurRecursivePosition] = {iSegmentX, iSegmentZ}
                                    iCurRecursivePosition = iCurRecursivePosition + 1
                                    --if bDebugMessages == true then LOG(sFunctionRef..': Can path to the new segment so setting cur segment equal to the new segment') end
                                else
                                    iCurRecursivePosition = iCurRecursivePosition - 1
                                    iSegmentX = tRecursivePosition[iCurRecursivePosition][1]
                                    iSegmentZ = tRecursivePosition[iCurRecursivePosition][2]
                                    --if bDebugMessages == true then LOG(sFunctionRef..': Have nowhere that can path to that havent already considered, so moving recursive position back one, iCurRecursivePosition='..iCurRecursivePosition..'; New segment X-Z='..repr(tRecursivePosition[iCurRecursivePosition])) end
                                end
                                if iCurRecursivePosition > 1 then tCurPosition = GetPositionFromPathingSegments(iSegmentX, iSegmentZ) end
                            end
                        end
                    end
                end
            end
            --LOG(sFunctionRef..': Finished going through all Z values, size of table='..table.getn(tPathingSegmentGroupBySegment[sPathingType][iBaseSegmentX]))
        end

    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function MappingInitialisation(aiBrain)
    --aiBrain needed for waterpercent function
    local bProfiling = true
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MappingInitialisation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    if bPathfindingAlreadyCommenced == false then
        bPathfindingAlreadyCommenced = true
        local iProfileStartTime
        if bProfiling == true then iProfileStartTime = M27Utilities.ProfilerTimeSinceLastCall(sFunctionRef..': Pre start of while loop', iProfileStartTime) end
        --Determine playable area
        if ScenarioInfo.MapData.PlayableRect then
            rMapPlayableArea = ScenarioInfo.MapData.PlayableRect
        else
            rMapPlayableArea = {0, 0, ScenarioInfo.size[1], ScenarioInfo.size[2]}
        end


        --Check if any water on map
        local iWaterPercent = aiBrain:GetMapWaterRatio()
        if iWaterPercent and iWaterPercent > 0 then
            bMapHasWater = true
        else bMapHasWater = false end
        if bDebugMessages == true then LOG(sFunctionRef..': Playable area rec='..repr(rMapPlayableArea)..'; map size='..repr(GetMapSize())..'; iWaterPercent='..iWaterPercent..'; bMapHasWater='..tostring(bMapHasWater)) end
        RecordBaseLevelPathability()

        if bDebugMessages == true then
            LOG(sFunctionRef..': FInished recording base level pathability')
            --Record all entries in the first pathing group
            local iZForDebug = 1
            for iX = 1, iMaxBaseSegmentX do
                LOG(sFunctionRef..': iSegmentX='..iX..'; Land pathing group='..tPathingSegmentGroupBySegment[M27UnitInfo.refPathingTypeLand][iX][iZForDebug])
            end
        end
        if bProfiling == true then iProfileStartTime = M27Utilities.ProfilerTimeSinceLastCall(sFunctionRef..': End of pathing logic for base pathing', iProfileStartTime) end

        --Record mexes by pathing group
        RecordMexForPathingGroup()

        if bDebugMessages == true then
            local iMapSizeX, iMapSizeZ = GetMapSize()
            LOG(sFunctionRef..': iMapSizeX='..iMapSizeX..'; iMapSizeZ='..iMapSizeZ..'; iMaxBaseSegmentX-Z='..iMaxBaseSegmentX..'-'..iMaxBaseSegmentZ)
            LOG(sFunctionRef..': '..repr(rMapPlayableArea))
            --LOG('MapGroup='..repr(GetMapGroup()))
            LOG(sFunctionRef..': End of code')
        end
        bPathfindingComplete = true

        --Other variables used by all M27ai
        for iPathingType, sPathingType in M27UnitInfo.refPathingTypeAll do
            tManualPathingChecks[sPathingType] = {}
        end

    end

    --Reclaim varaibles
    aiBrain[reftReclaimAreasOfInterest] = {}
    aiBrain[refiTotalReclaimAreasOfInterestByPriority] = {}
    for iPriority = 1, 4 do
        aiBrain[reftReclaimAreasOfInterest][iPriority] = {}
        aiBrain[refiTotalReclaimAreasOfInterestByPriority][iPriority] = 0
    end
    aiBrain[reftReclaimAreaPriorityByLocationRef] = {}
    aiBrain[refiPreviousThreatPercentCoverage] = 0
    aiBrain[refiPreviousFrontUnitPercentFromOurBase] = 0


    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function SetWhetherCanPathToEnemy(aiBrain)
    --Set flag for whether AI can path to enemy base
    local sFunctionRef = 'SetWhetherCanPathToEnemy'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tEnemyStartPosition = PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]
    local tOurBase = PlayerStartPoints[aiBrain.M27StartPositionNumber]
    local sPathing = M27UnitInfo.refPathingTypeLand
    local iOurBaseGroup = GetSegmentGroupOfLocation(sPathing, tOurBase)
    local iEnemyBaseGroup = GetSegmentGroupOfLocation(sPathing, tEnemyStartPosition)
    if iOurBaseGroup == iEnemyBaseGroup then aiBrain[refbCanPathToEnemyBaseWithLand] = true
    else aiBrain[refbCanPathToEnemyBaseWithLand] = false end
    sPathing = M27UnitInfo.refPathingTypeAmphibious
    iOurBaseGroup = GetSegmentGroupOfLocation(sPathing, tOurBase)
    iEnemyBaseGroup = GetSegmentGroupOfLocation(sPathing, tEnemyStartPosition)
    if iOurBaseGroup == iEnemyBaseGroup then aiBrain[refbCanPathToEnemyBaseWithAmphibious] = true
    else aiBrain[refbCanPathToEnemyBaseWithAmphibious] = false end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function LogMapTerrainTypes()
    --Outputs to log the terrain types used and how often theyre used
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'LogMapTerrainTypes'
    WaitTicks(150)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code after waitticks') end
    local tTerrainTypeCount = {}
    local sTerrainType
    local iDirt9Count2 = 0
    local tWaterSurfaceHeightCount = {}
    local tLocation, iCurSurfaceHeight
    for iX = rMapPlayableArea[1], rMapPlayableArea[3] do
        for iZ = rMapPlayableArea[2], rMapPlayableArea[4] do
            sTerrainType = GetTerrainType(iX,iZ)
            if tTerrainTypeCount[sTerrainType] == nil then tTerrainTypeCount[sTerrainType] = 1
            else tTerrainTypeCount[sTerrainType] = tTerrainTypeCount[sTerrainType] + 1 end
            if sTerrainType['Name'] == 'Dirt09' then iDirt9Count2 = iDirt9Count2 + 1 end

            --Also record the height of water
            if tPathingSegmentGroupBySegment[M27UnitInfo.refPathingTypeLand][iX][iZ] == iLandPathingGroupForWater then
                tLocation = GetPositionFromPathingSegments(iX, iZ)
                iCurSurfaceHeight = GetSurfaceHeight(tLocation[1], tLocation[3])
                if tWaterSurfaceHeightCount[iCurSurfaceHeight] == nil then tWaterSurfaceHeightCount[iCurSurfaceHeight] = 1 else tWaterSurfaceHeightCount[iCurSurfaceHeight] = tWaterSurfaceHeightCount[iCurSurfaceHeight] + 1 end
            end
        end
    end
    LOG(sFunctionRef..': tTerrainTypeCount='..repr(tTerrainTypeCount))
    LOG(sFunctionRef..': End of table of terrain type, iDirt9Count2='..iDirt9Count2)
    LOG(sFunctionRef..': Surface height of water count table='..repr(tWaterSurfaceHeightCount))

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DrawAllMapPathing(aiBrain)
    while bPathfindingComplete == false do
        WaitTicks(10)
    end
    if not(bMapDrawingAlreadyCommenced[M27UnitInfo.refPathingTypeLand] == true) then
        DrawMapPathing(aiBrain, M27UnitInfo.refPathingTypeLand, true)
        while bMapDrawingAlreadyCommenced[M27UnitInfo.refPathingTypeLand] == true do
            WaitTicks(10)
        end
        WaitTicks(50)
        DrawMapPathing(aiBrain, M27UnitInfo.refPathingTypeAmphibious)
        while bMapDrawingAlreadyCommenced[M27UnitInfo.refPathingTypeAmphibious] == true do
            WaitTicks(10)
        end
        WaitTicks(50)
        DrawMapPathing(aiBrain, M27UnitInfo.refPathingTypeNavy, true)
    end
end

function DrawMapPathing(aiBrain, sPathingType, bDontDrawWaterIfPathingLand)
    if M27Utilities.IsTableEmpty(bMapDrawingAlreadyCommenced[sPathingType]) == true then
        bMapDrawingAlreadyCommenced[sPathingType] = true
        if bDontDrawWaterIfPathingLand == nil then
            if sPathingType == M27UnitInfo.refPathingTypeAmphibious then bDontDrawWaterIfPathingLand = false
            else bDontDrawWaterIfPathingLand = true end
        end
        --Draw core pathing group
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        local sFunctionRef = 'DrawMapPathing'
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code after waitticks') end
        local iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(PlayerStartPoints[aiBrain.M27StartPositionNumber])
        local iStartingGroup = tPathingSegmentGroupBySegment[sPathingType][iSegmentX][iSegmentZ]
        local iMatches = 0
        local tiMatchesPerSegmentGroup = {}
        local tiColourToUse = {}
        local iCurGroup, iColour
        local iCurColour = 2
        local iWaitCount = 0
        local iMaxSegments = math.max(iMaxBaseSegmentZ, iMaxBaseSegmentX)
        local iSegmentInterval = 1
        local bLandPathing = false
        local iResetColour = 2
        if sPathingType == M27UnitInfo.refPathingTypeLand then
            bLandPathing = true
            iResetColour = 3
        end

        if iMaxSegments > 500 then
            if bDontDrawWaterIfPathingLand and aiBrain:GetMapWaterRatio() >= 0.5 then iSegmentInterval = 2
            else iSegmentInterval = 4 end
        elseif iSegmentInterval > 250 then
            if bDontDrawWaterIfPathingLand and aiBrain:GetMapWaterRatio() >= 0.4 and aiBrain:GetMapWaterRatio() <= 0.6 then iSegmentInterval = 1
            else iSegmentInterval = 2 end
        end

        local iTimeToWait = (iMaxBaseSegmentX / 10 + 40)

        local iCurIntervalCount = 0
        if bDebugMessages == true then
            LOG(sFunctionRef..': iMaxBaseSegmentX='..iMaxBaseSegmentX..'; iMaxBaseSegmentZ='..iMaxBaseSegmentZ..'; size of tPathingSegmentGroupBySegment for land pathing='..table.getn(tPathingSegmentGroupBySegment[sPathingType])..'; player start point group='..iStartingGroup..'; player starting segments='..iSegmentX..'-'..iSegmentZ..'; start position location='..repr(PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; position of segment='..repr(GetPositionFromPathingSegments(iSegmentX, iSegmentZ)))
            LOG('Pathing groups of every segment around player start position about to be produced')
            for iAdjX = -1, 1, 1 do
                for iAdjZ = -1, 1, 1 do
                    LOG('iAdjX-Z='..iAdjX..'-'..iAdjZ..'; pathing group='..tPathingSegmentGroupBySegment[sPathingType][iSegmentX+iAdjX][iSegmentZ+iAdjZ])
                end
            end
        end
        for iSegmentX = 1, iMaxBaseSegmentX do
            for iSegmentZ = 1, iMaxBaseSegmentZ do
                iCurGroup = tPathingSegmentGroupBySegment[sPathingType][iSegmentX][iSegmentZ]
                if iCurGroup then
                    if tiMatchesPerSegmentGroup[iCurGroup] == nil then tiMatchesPerSegmentGroup[iCurGroup] = 1
                    else
                        if tiColourToUse[iCurGroup] == nil then
                            if iCurGroup == iStartingGroup then
                                tiColourToUse[iStartingGroup] = 1
                            elseif iCurGroup == 1 and bLandPathing then tiColourToUse[iCurGroup] = 2
                            elseif tiMatchesPerSegmentGroup[iCurGroup] > 5 then
                                iCurColour = iCurColour + 1
                                if iCurColour > 7 then iCurColour = iResetColour end
                                tiColourToUse[iCurGroup] = iCurColour
                            end
                        end
                        tiMatchesPerSegmentGroup[iCurGroup] = tiMatchesPerSegmentGroup[iCurGroup] + 1
                    end
                else
                    M27Utilities.ErrorHandler('iCurGroup is nil; iSegmentX='..iSegmentX..'; iSegmentZ='..iSegmentZ)
                end
            end
            iWaitCount = iWaitCount + 1
            if iWaitCount > 50 then
                WaitTicks(1)
                iWaitCount = 0
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Matches per segment group='..repr(tiMatchesPerSegmentGroup)) end
        for iSegmentX = 1, iMaxBaseSegmentX do
            for iSegmentZ = 1, iMaxBaseSegmentZ do
                iCurIntervalCount = iCurIntervalCount + 1
                --below line used for v.large maps like frostmill ruins if want to draw in greater detail around an area
                --if iSegmentX <= 380 and iSegmentX >= 280 and iSegmentZ <=380 and iSegmentZ >= 280 then iCurIntervalCount = iSegmentInterval end
                if iCurIntervalCount >= iSegmentInterval then
                    iCurIntervalCount = 0
                    iCurGroup = tPathingSegmentGroupBySegment[sPathingType][iSegmentX][iSegmentZ]
                    if tiMatchesPerSegmentGroup[iCurGroup] > 10 and (not(bDontDrawWaterIfPathingLand) or not(iCurGroup == iLandPathingGroupForWater)) then
                        M27Utilities.DrawLocation(GetPositionFromPathingSegments(iSegmentX, iSegmentZ), nil, tiColourToUse[iCurGroup], iTimeToWait)
                    end
                end
                if iCurGroup == iStartingGroup then iMatches = iMatches + 1 end
            end
            LOG('iMatches='..iMatches..'; iSegmentX-Z='..iSegmentX..'-'..iSegmentZ..'; Pathing group='..tPathingSegmentGroupBySegment[sPathingType][iSegmentX][iSegmentZ]..'; position='..repr(GetPositionFromPathingSegments(iSegmentX, iSegmentZ)))
            iWaitCount = iWaitCount + 1
            if iWaitCount > 10 then
                WaitTicks(1)
                iWaitCount = 0
            end
        end
    end
    bMapDrawingAlreadyCommenced[sPathingType] = false
end

function DrawWater()
    local rPlayableArea = rMapPlayableArea
    local iMaxX = rPlayableArea[3] - rPlayableArea[1]
    local iMaxZ = rPlayableArea[4] - rPlayableArea[2]

    local iCurTerrainHeight
    local iCurSurfaceHeight
    for iCurX = rPlayableArea[1], iMaxX do
        for iCurZ = rPlayableArea[2], iMaxZ do
            iCurTerrainHeight = GetTerrainHeight(iCurX, iCurZ)
            iCurSurfaceHeight = GetSurfaceHeight(iCurX, iCurZ)
            if iCurTerrainHeight < iCurSurfaceHeight then M27Utilities.DrawLocation({iCurX, iCurSurfaceHeight, iCurZ}, nil, 4, 1000) end
        end
    end
end

function TempCanPathToEveryMex(oUnit)
    local sFunctionRef = 'TempCanPathToEveryMex'

    local iCurTime = M27Utilities.ProfilerTimeSinceLastCall(sFunctionRef..': Start', nil)
    local bCanPath
    for iMex, tMex in MassPoints do
        bCanPath = oUnit:CanPathTo(tMex)
    end
    iCurTime = M27Utilities.ProfilerTimeSinceLastCall(sFunctionRef..': End', nil)
end

--[[function DrawHeightMapAstro()
    --Temp for astro craters to help figure out why amphibious pathing doesnt work
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DrawHeightMapAstro'
    local iCurSurfaceHeight, iCurTerrainHeight, tCurPosition
    local iCurHeight
    local iHeightThreshold
    local tCountByThreshold = {}
    local iWaitThreshold = 10
    local iWaitCount = 0
    for iSegmentX = 1, iMaxBaseSegmentX do
        for iSegmentZ = 1, iMaxBaseSegmentZ do
            tCurPosition = GetPositionFromPathingSegments(iSegmentX, iSegmentZ)
            iCurSurfaceHeight = GetSurfaceHeight(tCurPosition[1], tCurPosition[3])
            iCurTerrainHeight = GetTerrainHeight(tCurPosition[1], tCurPosition[3])
            iCurHeight = math.max(iCurSurfaceHeight, iCurTerrainHeight)
            if iCurHeight >= 25.1 then iHeightThreshold = 1
            else iHeightThreshold = math.ceil((25.1 - iCurHeight) / 0.02) end
            if tCountByThreshold[iHeightThreshold] == nil then tCountByThreshold[iHeightThreshold] = 1
            else tCountByThreshold[iHeightThreshold] = tCountByThreshold[iHeightThreshold] + 1 end
            M27Utilities.DrawLocation(tCurPosition, nil, iHeightThreshold, 250)
        end
        iWaitCount = iWaitCount + 1
        if iWaitCount >= iWaitThreshold then
            iWaitCount = 0
            WaitTicks(1)
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': tCountByThreshold='..repr(tCountByThreshold)) end
end--]]

function RedoPathingForGroup(iPathingGroupToRedo, iNewPathingHeightThreshold)
    M27Utilities.ErrorHandler('Need to add code')
end

function RecheckPathingToMexes(aiBrain)
    M27Utilities.ErrorHandler('Deprecated function')
    --[[
    local bDebugMessages = false
    local sFunctionRef = 'RecheckPathingToMexes'
    local oACU = M27Utilities.GetACU(aiBrain)
    local bInconsistentPathing
    local bHaveChangedPathingGroups = false
    local iTimeWaitedForACU = 0
    while not(oACU) do
        WaitTicks(1)
        oACU = M27Utilities.GetACU(aiBrain)
        iTimeWaitedForACU = iTimeWaitedForACU + 1
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Now have an ACU; iTimeWaitedForACU='..iTimeWaitedForACU) end

    local tACUPosition = oACU:GetPosition()
    local iACUPathingGroup = GetUnitSegmentGroup(oACU)
    local sPathing = M27UnitInfo.GetUnitPathingType(oACU)
    local iCurResourceGroup
    local bExpectedPathingResult
    local bActualPathingResult
    local iPathingGroupToRedo
    local iNewPathingHeightThreshold
    --local iHeightThresholdForLastRefresh = iMaxHeightDif
    local iLastHeightAdjustmentTotal = 0
    local iLastHeightAdjustmentChange = 0
    local iAdjToLastHeightAdjustment = 0
    local iCurHeightAdjustment = 0
    local iNewPathingHeightThreshold = iMaxHeightDif
    local iReworkCount = 0
    local iMaxReworkCount = 5 --Means will re-do pathing up to this nubmer of times
    --Reduce max rework count based on map size to avoid massive delays on larger maps
    local iMapSizeX, iMapSizeZ = GetMapSize()
    if iMapSizeX >= 2000 then iMaxReworkCount = 1
    elseif iMapSizeX >= 1000 then iMaxReworkCount = 3
    elseif iMapSizeX >= 500 then iMaxReworkCount = 4
    end

    local iWaitNeeded = 0

    for iType = 1, 2 do
        iReworkCount = 0
        local tAllMapResourceLocations
        if iType == 1 then tAllMapResourceLocations = MassPoints
        else tAllMapResourceLocations = HydroPoints
        end

        if bDebugMessages == true then LOG(sFunctionRef..': tAllMapResourceLocations for iType '..iType..'='..repr(tAllMapResourceLocations)) end

        if M27Utilities.IsTableEmpty(tAllMapResourceLocations) == false then
            bInconsistentPathing = true
            while bInconsistentPathing == true do
                iReworkCount = iReworkCount + 1
                if iReworkCount > iMaxReworkCount then
                    M27Utilities.ErrorHandler('Failed to determine correct mex pathing despite re-doing '..iReworkCount..' times - likely that will have suboptimal behaviour from AI')
                    break
                end
                iACUPathingGroup = GetUnitSegmentGroup(oACU)
                if bDebugMessages == true then LOG(sFunctionRef..': iType='..iType..'; iReworkCount='..iReworkCount..'; About to cycle through every mex to check its pathing group; iACUPathingGroup='..iACUPathingGroup) end
                bInconsistentPathing = false
                iLastHeightAdjustmentTotal = iCurHeightAdjustment
                iLastHeightAdjustmentChange = iAdjToLastHeightAdjustment
                
                for iResource, tLocation in tAllMapResourceLocations do
                    --Should we be able to path to ACU position?
                    iCurResourceGroup = GetSegmentGroupOfLocation(sPathing, tLocation)
                    if iCurResourceGroup == iACUPathingGroup then bExpectedPathingResult = true else bExpectedPathingResult = false end
                    bActualPathingResult = oACU:CanPathTo(tLocation)
                    --below is temp for testing to see how long of a delay we need - initially canpathto returned false but restarting application it was correctly true (on a map where could be pathed to) so commented out for now
                    while bActualPathingResult == false do
                        if bDebugMessages == true then LOG(sFunctionRef..': CanPathTo is false so will wait 1 tick to see if result changes') end
                        WaitTicks(1)
                        iWaitNeeded = iWaitNeeded + 1
                        if iWaitNeeded > 100 then break end
                        bActualPathingResult = oACU:CanPathTo(tLocation)
                    end
                    LOG(sFunctionRef..': iWaitNeeded='..iWaitNeeded)
                    if bDebugMessages == true then LOG(sFunctionRef..': About to check if pathing for iResource='..iResource..'; tLocation='..repr(tLocation)..' is consistent. iCurResourceGroup='..iCurResourceGroup..'; iACUPathingGroup='..iACUPathingGroup..'; bActualPathingResult='..tostring(bActualPathingResult)) end
                    if not(bActualPathingResult == bExpectedPathingResult) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Pathing is inconsistent, will determine adjustment to apply to height and rerun pathing groupings') end

                        bInconsistentPathing = true

                        if iCurResourceGroup == iACUPathingGroup then
                            --Pathing groups are expected to be equal but they shouldnt be, so we need to lower the threshold for detecting cliffs
                            --if iLastHeightAdjustmentTotal > 0 then
                            
                            --We were increasing the height adj from the time before but we presumably went too far so want to decrease, but by half of last adjustment
                            if iLastHeightAdjustmentChange > 0 then
                                iAdjToLastHeightAdjustment = -iLastHeightAdjustmentChange * 0.5
                            elseif iLastHeightAdjustmentChange < 0 then
                                --We tried going back slightly but still have gone too far
                                
                                iAdjToLastHeightAdjustment = iLastHeightAdjustmentChange
                            else --0, i.e. we havent run this yet
                                iAdjToLastHeightAdjustment = -iChangeInHeightThreshold
                            end
                            iCurHeightAdjustment = iLastHeightAdjustmentTotal + iAdjToLastHeightAdjustment
                            iNewPathingHeightThreshold = iMaxHeightDif + iCurHeightAdjustment
                        else
                            --Pathing groups aren't equal but they should be, so we need to raise the threshold for detecting cliffs
                            if iLastHeightAdjustmentChange < 0 then
                                --Were decreasing the height adj from the time before but we presumably went too far so want to increase
                                iAdjToLastHeightAdjustment = iLastHeightAdjustmentChange * 0.5
                            elseif iLastHeightAdjustmentChange > 0 then
                                --We tried increasing the threshold slightly but still not enough
                                iAdjToLastHeightAdjustment = iLastHeightAdjustmentChange
                            else
                                iAdjToLastHeightAdjustment = iChangeInHeightThreshold
                            end
                        end
                        M27Utilities.ErrorHandler('Actual pathing is different, will redo with iNewPathingHeightThreshold='..iNewPathingHeightThreshold, nil, true)
                        RedoPathingForGroup(iPathingGroupToRedo, iNewPathingHeightThreshold)
                        break
                    end

                end
                if bDebugMessages == true then LOG(sFunctionRef..': Finished checking pathing for iType='..iType..'; bInconsistentPathing='..tostring(bInconsistentPathing)) end
            end
        end
    end
    if bDebugMessages == true then
        local iUnpathableMexCount = 0
        for iResource, tLocation in MassPoints do
            if oACU:CanPathTo(tLocation) == false then
                M27Utilities.DrawLocation(tLocation, nil, 7, 200)
                LOG(sFunctionRef..': CanPathTo is false for location='..repr(tLocation))
                iUnpathableMexCount = iUnpathableMexCount + 1
            end
        end
        LOG('iUnpathableMexCount after first wait='..iUnpathableMexCount)
        WaitTicks(200)
        iUnpathableMexCount = 0
        for iResource, tLocation in MassPoints do
            if oACU:CanPathTo(tLocation) == false then
                M27Utilities.DrawLocation(tLocation, nil, 6, 200)
                LOG(sFunctionRef..': CanPathTo is false for location='..repr(tLocation))
                iUnpathableMexCount = iUnpathableMexCount + 1
            end
        end
        LOG('iUnpathableMexCount after 2nd wait='..iUnpathableMexCount)
        WaitTicks(200)
        iUnpathableMexCount = 0
        for iResource, tLocation in MassPoints do
            if oACU:CanPathTo(tLocation) == false then
                M27Utilities.DrawLocation(tLocation, nil, 5, 200)
                LOG(sFunctionRef..': CanPathTo is false for location='..repr(tLocation))
                iUnpathableMexCount = iUnpathableMexCount + 1
            end
        end
        LOG('iUnpathableMexCount after 3rd wait='..iUnpathableMexCount)
        WaitTicks(600)
        iUnpathableMexCount = 0
        for iResource, tLocation in MassPoints do
            if oACU:CanPathTo(tLocation) == false then
                M27Utilities.DrawLocation(tLocation, nil, 4, 200)
                if bDebugMessages == true then LOG(sFunctionRef..': CanPathTo is false for location='..repr(tLocation)) end
                iUnpathableMexCount = iUnpathableMexCount + 1
            end
        end
        LOG('iUnpathableMexCount after 4th wait='..iUnpathableMexCount)
        WaitTicks(2000)
        iUnpathableMexCount = 0
        for iResource, tLocation in MassPoints do
            if oACU:CanPathTo(tLocation) == false then
                M27Utilities.DrawLocation(tLocation, nil, 3, 200)
                if bDebugMessages == true then LOG(sFunctionRef..': CanPathTo is false for location='..repr(tLocation)) end
                iUnpathableMexCount = iUnpathableMexCount + 1
            end
        end
        LOG('iUnpathableMexCount after 5th wait='..iUnpathableMexCount)
    end




    if bHaveChangedPathingGroups == true then
        RecordMexForPathingGroup()
        RecordSortedMexesInOriginalPathingGroup(aiBrain)
    end --]]

end

function RecordIfSuitableRallyPoint(aiBrain, tPossibleRallyPoint, iCurRallyPoints, iOurBaseGroup)
    --Records the rally point and returns the current number of rally points

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordIfSuitableRallyPoint'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bAbortDueToIntelOrEnemies = false
    if M27Utilities.IsTableEmpty(tPossibleRallyPoint) == false and GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, tPossibleRallyPoint) == iOurBaseGroup then

        --Far enough away from last rally point?
        if M27Utilities.IsTableEmpty(tPossibleRallyPoint) then M27Utilities.ErrorHandler('No rally point specified')
        else
            --Closer to enemy base than last rally point?
            if M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]) < M27Utilities.GetDistanceBetweenPositions(aiBrain[reftRallyPoints][iCurRallyPoints], PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]) then
                if bDebugMessages == true then
                    LOG(sFunctionRef..': About to check if '..repr(tPossibleRallyPoint)..' is a valid rally point; iCurRallyPoints='..iCurRallyPoints..'; will draw a black circle around potential location')
                    M27Utilities.DrawLocation(tPossibleRallyPoint, nil, 3)
                end
                if M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, aiBrain[reftRallyPoints][iCurRallyPoints]) >= 40 then
                    --Within defence and closest friendly land unit?
                    bAbortDueToIntelOrEnemies = true
                    local iModDistToStart = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tPossibleRallyPoint)
                    if bDebugMessages == true then LOG(sFunctionRef..': iModDistToStart='..iModDistToStart..'; aiBrain[M27Overseer.refiModDistFromStartNearestThreat]='..aiBrain[M27Overseer.refiModDistFromStartNearestThreat]..'; aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] * 0.9='..aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] * 0.9..'; aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] - 50='..aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] - 50) end
                    if iModDistToStart < aiBrain[M27Overseer.refiModDistFromStartNearestThreat] and iModDistToStart < math.min(aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] * 0.9, aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] - 50) then
                        if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy] * 0.9='..aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy] * 0.9..'; M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, PlayerStartPoints[aiBrain.M27StartPositionNumber])='..M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]) end
                        if M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, PlayerStartPoints[aiBrain.M27StartPositionNumber]) / aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] < (aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy] * 0.9) then
                            local tNearbyPDAndT2Arti = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryT2PlusPD, tPossibleRallyPoint, 153, 'Enemy')
                            local bNearbyEnemyDefences = true
                            if M27Utilities.IsTableEmpty(tNearbyPDAndT2Arti) == false then
                                --T2 arti nearby?
                                local tNearbyDefences = EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedT2Arti, tNearbyPDAndT2Arti)
                                if M27Utilities.IsTableEmpty(tNearbyDefences) == true then
                                    --T3 PD nearby?
                                    tNearbyDefences = EntityCategoryFilterDown(M27UnitInfo.refCategoryPD * categories.TECH3, tNearbyPDAndT2Arti)
                                    if M27Utilities.IsTableEmpty(tNearbyDefences) == true or M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, M27Utilities.GetNearestUnit(tNearbyDefences, tPossibleRallyPoint, aiBrain, false, false):GetPosition()) > 90 then
                                        --T2 PD nearby?
                                        if bDebugMessages == true then LOG(sFunctionRef..': Nearest PD unit='..M27Utilities.GetNearestUnit(tNearbyPDAndT2Arti, tPossibleRallyPoint, aiBrain, false, false):GetUnitId()..'; Position='..repr(M27Utilities.GetNearestUnit(tNearbyPDAndT2Arti, tPossibleRallyPoint, aiBrain, false, false):GetPosition())..'; Rally point position='..repr(tPossibleRallyPoint)) end
                                        if M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, M27Utilities.GetNearestUnit(tNearbyPDAndT2Arti, tPossibleRallyPoint, aiBrain, false, false):GetPosition()) > 70 then
                                            bNearbyEnemyDefences = false
                                        end
                                    end
                                end
                            else
                                bNearbyEnemyDefences = false
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': bNearbyEnemyDefences='..tostring(bNearbyEnemyDefences)) end
                            if bNearbyEnemyDefences == false then
                                --Do we have intel coverage of at least 20?
                                --if M27Logic.GetIntelCoverageOfPosition(aiBrain, tPossibleRallyPoint, 20, false) then
                                    --Have a valid rally point
                                    bAbortDueToIntelOrEnemies = false
                                    iCurRallyPoints = iCurRallyPoints + 1
                                    aiBrain[reftRallyPoints][iCurRallyPoints] = {tPossibleRallyPoint[1], tPossibleRallyPoint[2], tPossibleRallyPoint[3]}
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have a valid rally point; iCurRallyPoints='..iCurRallyPoints..'; aiBrain[reftRallyPoints][iCurRallyPoints]='..repr(aiBrain[reftRallyPoints][iCurRallyPoints])) end
                                --elseif bDebugMessages == true then LOG(sFunctionRef..': DOnt have sufficient intel coverage; IntelCoverage='..M27Logic.GetIntelCoverageOfPosition(aiBrain, tPossibleRallyPoint, nil, false))
                                --end
                            end
                        elseif bDebugMessages == true then LOG(sFunctionRef..': Nearest unit to enemy base is too close to rally point distance')
                        end
                    elseif bDebugMessages == true then LOG(sFunctionRef..': Not far enough away from enemy threats')
                    end
                elseif bDebugMessages == true then LOG(sFunctionRef..': Are too close to the existing rally point; existing rally point='..repr(aiBrain[reftRallyPoints][iCurRallyPoints])..'; Distance to this='..M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, aiBrain[reftRallyPoints][iCurRallyPoints]))
                end
            elseif bDebugMessages == true then LOG(sFunctionRef..': Arent closer to enemy base than last rally point')
            end
        end
    elseif bDebugMessages == true then LOG(sFunctionRef..': Cant path to location or it is nil')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iCurRallyPoints, bAbortDueToIntelOrEnemies
end

function RecordAllRallyPoints(aiBrain)
    local bDebugMessages = true if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordAllRallyPoints'
    if GetGameTimeSeconds() - (aiBrain[refiLastRallyPointRefresh] or 0) >= 5 and aiBrain[M27Overseer.refbIntelPathsGenerated] then
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code to recalculate rally points') end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        local iOurBaseGroup = GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, PlayerStartPoints[aiBrain.M27StartPositionNumber])
        aiBrain[refiLastRallyPointRefresh] = GetGameTimeSeconds()

        if not(aiBrain[refiNearestEnemyIndexWhenLastCheckedRallyPoints] == M27Logic.GetNearestEnemyIndex(aiBrain)) then
            --Update list of mexes that are along a line from our base to enemy base
            --tMexByPathingAndGrouping = {} --Stores position of each mex based on the segment that it's part of; [a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
            aiBrain[reftMexesAndDistanceNearPathToNearestEnemy] = {}

            if M27Utilities.IsTableEmpty(tMexByPathingAndGrouping[M27UnitInfo.refPathingTypeLand][iOurBaseGroup]) == false then
                local iDistToOurBase, iDistToEnemyBase
                local iMaxDistToBeNearMiddle
                for iMex, tMex in tMexByPathingAndGrouping[M27UnitInfo.refPathingTypeLand][iOurBaseGroup] do

                    iDistToOurBase = M27Utilities.GetDistanceBetweenPositions(tMex, PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    iDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tMex, PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
                    iMaxDistToBeNearMiddle = math.min(60, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.2, iDistToOurBase * 0.3) + aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering if mex is near path to enemy base; iMex='..iMex..'; tMex='..repr(tMex)..'; iDistToOurBase='..iDistToOurBase..'; iDistToEnemyBase='..iDistToEnemyBase..'; iMaxDistToBeNearMiddle='..iMaxDistToBeNearMiddle) end

                    if iDistToOurBase + iDistToEnemyBase <= iMaxDistToBeNearMiddle then
                        table.insert(aiBrain[reftMexesAndDistanceNearPathToNearestEnemy], {[reftMexLocation] = tMex, [refiDistanceToOurBase] = iDistToOurBase})
                    end
                end
            end
        end
        local iCurRallyPoints = 1
        local iPrevRallyPoints = 1
        local bAbortedDueToEnemiesOrIntel
        aiBrain[reftRallyPoints] = {}
        local tPossibleRallyPoint
        local iAngleToEnemyBase = M27Utilities.GetAngleFromAToB(PlayerStartPoints[aiBrain.M27StartPositionNumber], PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
        local iFailedRallyPointChecks = 0


        local iCurDistToOurBase

        --Initial rally point: 1st base intel path
        if bDebugMessages == true then LOG(sFunctionRef..': About to add the first intel line position as a rally point; aiBrain[M27Overseer.reftIntelLinePositions][1][1]='..repr(aiBrain[M27Overseer.reftIntelLinePositions][1][1])..'; reftIntelLinePositions='..repr(aiBrain[M27Overseer.reftIntelLinePositions])) end
        aiBrain[reftRallyPoints][iCurRallyPoints] = aiBrain[M27Overseer.reftIntelLinePositions][1][1]

        --Do we have any mexes near the central line? If so then cycle through these and add rally points as long as theyre valid
        if M27Utilities.IsTableEmpty(aiBrain[reftMexesAndDistanceNearPathToNearestEnemy]) == false then
            local iLastRallyPointDistToStart
            if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through all mexes near the path to the nearest enemy') end
            for iMex, tSubtable in M27Utilities.SortTableBySubtable(aiBrain[reftMexesAndDistanceNearPathToNearestEnemy], refiDistanceToOurBase, true) do
                iPrevRallyPoints = iCurRallyPoints
                --Do we have any rally points already? if so how does the mex distance to start compare with the last rally point?
                if M27Utilities.IsTableEmpty(aiBrain[reftRallyPoints]) == false then
                     iLastRallyPointDistToStart = M27Utilities.GetDistanceBetweenPositions(aiBrain[reftRallyPoints][iCurRallyPoints], PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering if mex is far enoguh away from last rally to consider an intermediate rally point iMex='..iMex..'; Mex distance to base='..aiBrain[reftMexesAndDistanceNearPathToNearestEnemy][iMex][refiDistanceToOurBase]..'; iLastRallyPointDistToStart='..iLastRallyPointDistToStart) end
                    if (aiBrain[reftMexesAndDistanceNearPathToNearestEnemy][iMex][refiDistanceToOurBase] - iLastRallyPointDistToStart) > 100 then
                        --Add rally point inbetween these positions if can find a nearby area large enough to fit a land factory, that is at least 50 from the current mex
                        --FindRandomPlaceToBuild(aiBrain, oBuilder, tStartPosition, sBlueprintToBuild, iSearchSizeMin, iSearchSizeMax, bForcedDebug)
                        iCurDistToOurBase = math.min(aiBrain[reftMexesAndDistanceNearPathToNearestEnemy][iMex][refiDistanceToOurBase] - 50, (aiBrain[reftMexesAndDistanceNearPathToNearestEnemy][iMex][refiDistanceToOurBase] - iLastRallyPointDistToStart)*0.5)
                        tPossibleRallyPoint = M27EngineerOverseer.FindRandomPlaceToBuild(aiBrain, M27Utilities.GetACU(aiBrain), M27Utilities.MoveInDirection(PlayerStartPoints[aiBrain.M27StartPositionNumber], iAngleToEnemyBase, iCurDistToOurBase)
                                ,M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, M27UnitInfo.refCategoryLandFactory, M27Utilities.GetACU(aiBrain), false, false)
                                ,0, 10)
                        --if M27Utilities.IsTableEmpty(tPossibleRallyPoint) == false and GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, tPossibleRallyPoint) == iOurBaseGroup then

                            --Can path to the location, check if its far enough away from most recently added rally point and if any nearby enemies
                            if bDebugMessages == true then LOG(sFunctionRef..': About to consider if valid rally point; iCurRallyPoints before checking='..iCurRallyPoints) end
                            iCurRallyPoints, bAbortedDueToEnemiesOrIntel = RecordIfSuitableRallyPoint(aiBrain, tPossibleRallyPoint, iCurRallyPoints, iOurBaseGroup)
                            if bAbortedDueToEnemiesOrIntel == true then
                                iFailedRallyPointChecks = iFailedRallyPointChecks + 1
                                if iFailedRallyPointChecks > 5 then
                                    if bDebugMessages == true then LOG(sFunctionRef..': iFailedRallyPointChecks='..iFailedRallyPointChecks..' so wont consider any further mex based locations') end
                                    break end
                            end
                        --elseif bDebugMessages == true then LOG(sFunctionRef..': Possible rally point not being considered further; tPossibleRallyPoint='..repr(tPossibleRallyPoint)..'; Segment group='..GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, tPossibleRallyPoint)..'; iBaseGroup='..iOurBaseGroup)
                        --end
                    elseif bDebugMessages == true then LOG(sFunctionRef..': Less than 100 distance between mex and last rally point so wont conisder via point')
                    end
                end
                iPrevRallyPoints = iCurRallyPoints
                --Add the mex as a rally point unless we've already flagged to stop looking, or the mex is too close to the last rally point
                if bDebugMessages == true then LOG(sFunctionRef..': Consider whether to add a place near the mex as a rally point unless we have more than 5 failed checks') end
                if iFailedRallyPointChecks <= 5 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Difference in distances to start between mex and last rally point='..aiBrain[reftMexesAndDistanceNearPathToNearestEnemy][iMex][refiDistanceToOurBase] - iLastRallyPointDistToStart) end
                    if (aiBrain[reftMexesAndDistanceNearPathToNearestEnemy][iMex][refiDistanceToOurBase] - iLastRallyPointDistToStart) > 40 then
                        tPossibleRallyPoint = M27EngineerOverseer.FindRandomPlaceToBuild(aiBrain, M27Utilities.GetACU(aiBrain), aiBrain[reftMexesAndDistanceNearPathToNearestEnemy][iMex][reftMexLocation]
                        ,M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, M27UnitInfo.refCategoryLandFactory, M27Utilities.GetACU(aiBrain), false, false)
                        ,0, 10)

                        --if M27Utilities.IsTableEmpty(tPossibleRallyPoint) == false and GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, tPossibleRallyPoint) == iOurBaseGroup then
                            --Can path to the location, check if its far enough away from most recently added rally point and if any nearby enemies
                        if bDebugMessages == true then LOG(sFunctionRef..': Mex is far enough away; tPossibleRallyPoint='..repr(tPossibleRallyPoint)) end
                        iCurRallyPoints, bAbortedDueToEnemiesOrIntel = RecordIfSuitableRallyPoint(aiBrain, tPossibleRallyPoint, iCurRallyPoints, iOurBaseGroup)
                        --Did we add a rally point?
                        if bAbortedDueToEnemiesOrIntel then
                            iFailedRallyPointChecks = iFailedRallyPointChecks + 1
                            if iFailedRallyPointChecks > 5 then break end
                        end
                        --end
                    end
                end
            end
        elseif bDebugMessages == true then LOG(sFunctionRef..': reftMexesAndDistanceNearPathToNearestEnemy is empty')
        end

        --Have added for all mexes from start to base; If we have <= 1 rally point, then just use intel lines as potential rally points
        if iCurRallyPoints <= 1 and iFailedRallyPointChecks <= 5 then
            for iIntelLine, tIntelPath in aiBrain[M27Overseer.reftIntelLinePositions] do
                iPrevRallyPoints = iCurRallyPoints
                if iIntelLine > 1 then
                    iCurRallyPoints, bAbortedDueToEnemiesOrIntel = RecordIfSuitableRallyPoint(aiBrain, aiBrain[M27Overseer.reftIntelLinePositions][iIntelLine][1], iCurRallyPoints, iOurBaseGroup)
                    if bAbortedDueToEnemiesOrIntel then
                        iFailedRallyPointChecks = iFailedRallyPointChecks + 1
                        if iFailedRallyPointChecks > 5 then break end
                    end
                end
            end
        end


        aiBrain[refiNearestEnemyIndexWhenLastCheckedRallyPoints] = M27Logic.GetNearestEnemyIndex(aiBrain)

        if bDebugMessages == true then
            LOG(sFunctionRef..': End of code to recalculate rally points; will highlight all rally points in yellow; ALl rally points='..repr(aiBrain[reftRallyPoints]))
            M27Utilities.DrawLocations(aiBrain[reftRallyPoints], nil, 4, 40)
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
end
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
local M27Transport = import('/mods/M27AI/lua/AI/M27Transport.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27PlatoonTemplates = import('/mods/M27AI/lua/AI/M27PlatoonTemplates.lua')
local M27Team = import('/mods/M27AI/lua/AI/M27Team.lua')
local M27Chat = import('/mods/M27AI/lua/AI/M27Chat.lua')
local M27Navy = import('/mods/M27AI/lua/AI/M27Navy.lua')

bUsingArmyIndexForStartPosition = false --by default will assume armies are ARMY_1 etc.; this will be changed to true if any exceptions are found
MassPoints = {} -- Stores position of each mass point (as a position value, i.e. a table with 3 values, x, y, z
tMexPointsByLocationRef = {} --As per mass points, but the key is the locationref value, and it returns the position
tMexByPathingAndGrouping = {} --Stores position of each mex based on the segment that it's part of; [a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
tHydroByPathingAndGrouping = {}
HydroPoints = {} -- Stores position values i.e. a table with 3 values, x, y, z
PlayerStartPoints = {} -- Stores position values i.e. a table with 3 values, x, y, z; item 1 = ARMY_1 etc.
reftPrimaryEnemyBaseLocation = 'M27MapPrimaryEnemyBase'
reftMidpointToPrimaryEnemyBase = 'M27MapMidpointToPrimaryEnemyBase'
refiLastTimeCheckedEnemyBaseLocation = 'M27LastTimeChecked'
tResourceNearStart = {} --[Player start ponit/ARMY_x number (NOT ARMY INDEX)][iResourceType (1=mex2=hydro)][iCount][tLocation] Stores location of mass extractors and hydrocarbons that are near to start locations; 1st value is the army number, 2nd value the resource type, 3rd the mex number, 4th value the position array (which itself is made up of 3 values)
MassCount = 0 -- used as a way of checking if have the core markers needed
HydroCount = 0
iHighestReclaimInASegment = 0 --WARNING - reference the higher of this and previoushighestreclaiminasegment, since this gets reset to 0 each time
iPreviousHighestReclaimInASegment = 0
refiPreviousThreatPercentCoverage = 'M27MapPreviousThreatPercentCoverage'
refiPreviousFrontUnitPercentFromOurBase = 'M27MapPreviousFrontUnitPercentFromOurBase'
bStoppedSomePathingChecks = false

bReclaimManagerActive = false --used to spread updates of reclaim areas over each second
tReclaimSegmentsToUpdate = {} --[n] where n is the count, returns {segmentX,segmentZ} as value; i.e. update by using table.insert
tReclaimAreas = {} --Stores reclaim info for each segment: tReclaimAreas[iSegmentX][iSegmentZ][x]; if x=1 returns total mass in area; if x=2 then returns position of largest reclaim in the area, if x=3 returns how many platoons have been sent here since the game started
refReclaimTotalMass = 1
refReclaimSegmentMidpoint = 2
refReclaimHighestIndividualReclaim = 3
reftReclaimTimeOfLastEngineerDeathByArmyIndex = 4 --Table: [a] where a is the army index, and it returns the time the last engineer died
refReclaimTimeLastEnemySightedByArmyIndex = 5
refsSegmentMidpointLocationRef = 6
refiReclaimTotalPrev = 7 --Previous total reclaim in a segment
refReclaimTotalEnergy = 8
--tLastReclaimRefreshByGroup = {} --time that last refreshed reclaim positions for [x] group
iLastReclaimRefresh = 0 --stores time that last refreshed reclaim positions
refiLastRefreshOfReclaimAreasOfInterest = 'M27MapLastRefreshOfReclaim'
refiTotalReclaimAreasOfInterestByPriority = 'M27MapReclaimAreasOfInterestCount' --[1] = total for priority 1, etc.; up to 4 priority
reftReclaimAreasOfInterest = 'M27MapReclaimAreasOfInterest' --assigned to aiBrain, [1] = priority (1, 2, 3); [2] = {segmentx, segmentz}
reftReclaimAreaPriorityByLocationRef = 'M27MapReclaimAreaPriorityByLocationRef' --key is location ref
iReclaimSegmentSizeX = 0 --Updated separately
iReclaimSegmentSizeZ = 0 --Updated separately
iReclaimAreaOfInterestTickCount = 0 --Updated as part of may reclaim update loop, used to avoid excessive load on an individual tick
bReclaimRefreshActive = false --Used to avoid duplciating reclaim update logic
iMaxSegmentInterval = 1 --Updated by map pathing logic; constant - no. of times to divide the map by segments for X (and separately for Z) so will end up with this value squared as the no. of segments
tManualPathingChecks = {} --[Pathing][LocationRef]; returns the precise location checked
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
refiStartingSegmentGroup = 'M27StartingSegmentGroup' --[sPathing]  - returns the group number for the given pathing type
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
reftTheoreticalRallyPoints = 'M27MapTheroeticalRallyPoints' --SImilar to reftRallyPoints, but is calculated ignoring things like nearby enemies and intel, i.e. will generate this first whenever nearest enemy changes, and then only consider these when updating reftRallyPoints
reftMexesAndDistanceNearPathToNearestEnemy = 'M27MexesNearPathToNearestEnemy' --]{1,2}; 1 = mex location; 2 =- distance to our base; If do a line from our base to enemy base, this will record all mexes that would represent less than a 20% or 60 distance detour
reftMexLocation = 1
refiDistanceToOurBase = 2
refiLastRallyPointRefresh = 'M27MapLastRallyPointRefresh' --gametimeseconds that last updated our rally points
refiNearestEnemyIndexWhenLastCheckedRallyPoints = 'M27MapNearestEnemyLastRallyPointCheck'

--v3 Pathfinding specific
iLandPathingGroupForWater = 1
bMapHasWater = true --true or false based on water % of map
bPathfindingAlreadyCommenced = false
bMapDrawingAlreadyCommenced = {}
bPathfindingComplete = false
rMapPlayableArea = 2 --{x1,z1, x2,z2} - Set at start of the game, use instead of the scenarioinfo method
iPathingIntervalSize = 1
iLowHeightDifThreshold = 0.007 --Used to trigger check for max height dif in an area
iHeightDifAreaSize = 0.2 --T1 engineer is 0.6 x 0.9, so this results in a 1x1 size box by searching +- iHeightDifAreaSize if this is set to 0.5; however given are using a 0.25 interval size dont want this to be too large or destroys the purpose of the interval size and makes the threshold unrealistic
iMaxHeightDif = 0.75 --NOTE: Map specific code should be added below in DetermineMaxTerrainHeightDif (hardcoded table with overrides by map name); Max dif in height allowed if move iPathingIntervalSize blocks away from current position in a straight line along x or z; Testing across 3 maps (africa, astro crater battles, open palms) a value of viable range across the 3 maps is a value between 0.11-0.119.  Open palms: 0.074: Incorrect (middle not shown as pathable); 0.075: Correct; 0.119: Correct; 0.12: Incorrect (side cliffs shown as pathable).  Africa: Africa: 0.109: Incorrect (ramps at top and bottom not shown as pathable); 0.11: Correct mostly (some water areas show as unpathable when I think they’re pathable); 0.119: Correct; 0.25: Correct* (I’m not sure on the pathability of some of the island sections)
iAmphibiousMaxHeightDif = 0.75 --for when moving from land to water, will use this height threshold
bUseTerrainHeightForBeachCheck = false --If set to true for a map, then will compare terrain height of land to terrain height of water instead of surfaceheight
--Since then have had various maps where need a higher value to detect ramps - see below for manual overrides
local iChangeInHeightThreshold = 0.08 --Amount by which to change iMaxHeightDif if we have pathing inconsistencies
iMinWaterDepth = 1.5 --Ships cant move right up to shore, this is a guess at how much clearance is needed (testing on Africa, depth of 2 leads to some pathable areas being considered unpathable)
iWaterPathingIntervalSize = 1
tWaterAreaAroundTargetAdjustments = {} --Defined in map initialisation
iWaterMinArea = 3 --Square with x/z of this size must be underwater for the target position to be considered pathable; with value of 2 ships cant get as close to shore as expect them to
iBaseLevelSegmentCap = 512 --Max size of segments to use for 1 axis 20km map is 1024x1024 (i.e. 1024 means will only take shortcuts if map larger than 20km); at 1024 end up with really noticeable freezing on some maps (e.g. dark liver, pelagial) - not from any function profiling but more generlaly so presumably to do with the garbage handler/similar
iMapOutsideBoundSize = 3 --will treat positions within this size of map radius as being unpathable for pathing purposes
iSizeOfBaseLevelSegment = 1 --Is updated by pathfinding code
tPathingSegmentGroupBySegment = {} --[a][b][c]: a = pathing type; b = segment x, c = segment z
iMaxBaseSegmentX = 1 --Will be set by pathing, sets the maximum possible base segment X
iMaxBaseSegmentZ = 1

tCliffsAroundBaseChokepoint = 'M27CliffsAroundBaseChokepoint' --against aiBrain, [x][z] = {position of nearest end of cliff}, where x is the map position x, z is the map position z, and it returns the location of the point of the closest 'break' from the chokepoint (e.g. to the left or right of a cliff formation between the aibrain's base and the nearest enemy base)

iMapWaterHeight = 0 --Surface height of water on the map

--NoRush details
bNoRushActive = false --Global flag
iNoRushTimer = 0
iNoRushRange = 0
reftNoRushCentre = 'M27MapNoRushCentre' --Centrepoint of the norush radius, recorded against M27 aiBrains

--Plateaus
tAllPlateausWithMexes = {} --[x] = AmphibiousPathingGroup, [y]: subrefs, e.g. subrefPlateauMexes;
    --aibrain variables for plateaus:
reftPlateausOfInterest = 'M27PlateausOfInterest' --[x] = Amphibious pathing group; will record a table of the pathing groups we're interested in expanding to, returns the location of then earest mex
refiLastPlateausUpdate = 'M27LastTimeUpdatedPlateau' --gametime that we last updated the plateaus
reftOurPlateauInformation = 'M27OurPlateauInformation' --[x] = AmphibiousPathingGroup; [y] = subref, e.g. subrefPlateauLandFactories; Used to store details such as factories on the plateau
refiOurBasePlateauGroup = 'M27PlateausOurBaseGroup' --Segment group of our base (so can easily check somewhere is in a dif plateau)

    --subrefs for tables
    --tAllPlateausWithMexes subrefs
subrefPlateauMexes = 'M27PlateauMex' --[x] = mex count, returns mex position
subrefPlateauMinXZ = 'M27PlateauMinXZ' --{x,z} min values
subrefPlateauMaxXZ = 'M27PlateauMaxXZ' --{x,z} max values - i.e. can create a rectangle covering entire plateau using min and max xz values
subrefPlateauTotalMexCount = 'M27PlateauMexCount' --Number of mexes on the plateau
subrefPlateauReclaimSegments = 'M27PlateauReclaimSegments' --[x] = reclaim segment x, [z] = reclaim segment z, returns true if part of plateau
subrefPlateauMidpoint = 'M27PlateauMidpoint' --Location of the midpoint of the plateau
subrefPlateauMaxRadius = 'M27PlateauMaxRadius' --Radius to use to ensure the circle coveres the square of the plateau
subrefPlateauContainsActiveStart = 'M27PlateauContainsActiveStart' --True if the plateau is pathable amphibiously to a start position that was active at the start of the game

    --reftOurPlateauInformation subrefs (NOTE: If adding more info here need to update in several places, including ReRecordUnitsAndPlatoonsInPlateaus)
subrefPlateauLandFactories = 'M27PlateauLandFactories'
subrefPlateauMexBuildings = 'M27PlateauMexes' --table of mex buildings, similar to table of land factories

subrefPlateauLandCombatPlatoons = 'M27PlateauLandCombatPlatoons'
subrefPlateauIndirectPlatoons = 'M27PlateauIndirectPlatoons'
subrefPlateauMAAPlatoons = 'M27PlateauMAAPlatoons'
subrefPlateauScoutPlatoons = 'M27PlateauScoutPlatoons'

subrefPlateauEngineers = 'M27PlateauEngineers' --[x] is engineer unique ref (per m27engineeroverseer), returns engineer object


--Chokepoints:
refbConsideredChokepointsForTeam = 'M27TeamConsideredChokepoints' --Subref to Overseer.tTeamData, returns true if already considered chokepoints for our team
tPotentialChokepointsByDistFromStart = 'M27TeamChokepointsByDistFromStart' --subref to tTeamData. [x] is the dist from start for midpoint of a line from start to end, [y] is the chokepoint count (i.e. number [1], number[2], etc., returns subtable with info for that particular chokepoint
reftChokepointTeamStart = 'M27TeamChokepointTeamStart' --subref to tTeamData; the start point used for determining chokepoints
reftChokepointEnemyStart = 'M27TeamChokepointEnemyStart' --subref to tTeamData; the enemy point used for determining chokepoints
reftAngleFromTeamStartToEnemy = 'M27TeamChokepointAngleToEnemy' --subref to tTeamData; Angle from TeamStart to EnemyStart (stored for performacne reasons)
subrefChokepointSize = 'M27ChokepointSize' --Subref to tPotentialChokepointsByDistFromStart[x][y], returns Size of a chokepoint
subrefChokepointStart = 'M27ChokepointStart' --Subref to tPotentialChokepointsByDistFromStart[x][y], returns start position of the chokepoint
subrefChokepointEnd = 'M27ChokepointEnd' --Subref to tPotentialChokepointsByDistFromStart[x][y], returns end position of the chokepoint
reftChokepointBuildLocation = 'M27ChokepointBuildLocation' --aiBrain[], and also a subref to tPotentialChokepointsByDistFromStart[x][y], but only set for if the chokepoint has been picked as a preferred location to build at.  Returns a location
subrefChokepointMexesCovered = 'M27ChokepointMexesCovered' --Count of mexes in the same land pathing group estimated to be behind the chokepoint
tiPlannedChokepointsByDistFromStart = 'M27TeamChokepointsPlannedDistFromStart' --subref to tTeamData. [x] is  a count (1, 2, etc.), returns the dist from start for midpoint of line so can reference information from tPotentialChokepointsByDistFromStart
refiAssignedChokepointCount = 'M27AssignedChokepoint' --Against aiBrain, returns the chokepoint count number
refiAssignedChokepointFirebaseRef = 'M27AssignedFirebaseRef' --When a firebase is created, if its near the chokepoint then it will be assigned to this
reftClosestChokepoint = 'M27ChokepointClosest' --Assigned to all M27 brains, so even if arent defending a chokepoint will be able to tell where our closest chokepoitn (covered by a teammate) is



function DetermineMaxTerrainHeightDif()
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if M27Config.M27ShowPathingGraphically then bDebugMessages = true end --Based on config settings
    --Manually specify the terrain height difference to use for certain maps (e.g. where there are ramps and the pathfinding default options return incorrect pathing)
    --To find out the map name, run with 'display pathing graphically' config option set to true, and search for the last entry containing "DetermineMaxTerrainHeightDif: sMapName="
    local sFunctionRef = 'DetermineMaxTerrainHeightDif'

    local tMapHeightOverride = {
        --[[['serenity desert'] = 0.15,
        ['serenity desert small'] = 0.15,
        ['serenity desert small - FAF version'] = 0.15,
        ['Adaptive Corona'] = 0.15,
        ['Corona'] = 0.15,
        ['Adaptive Flooded Corona'] = 0.15,
        ['Fields of Isis'] = 0.15, --minor for completeness - one of cliffs reclaim looks like its pathable but default settings show it as non-pathable
        ['Selkie Mirror'] = 0.15,--]]
        --['Flooded Strip Mine'] = 1.2, --New 0.75 default approach: TerrainHeight beach: Use 1.2 as middle island and 4 corner islands by the middle should be pathable by amphibious; at 0.8 they arent; at 1.15 3/4 are, 1.2 all 4 are
        --['Dark Liver Mirrored'] = 2.5, --New 0.75 default approach: TerrainHeight beach: Even at 2.5 some of the 1 mex islands are considered plateaus incorrectly
        --[[['Adaptive Point of Reason'] = 0.26,
        ['Hyperion'] = 0.215, --0.213 results in apparant plateau with 2 mexes (that is actually pathable) being treated as a plateau incorrectly
        ['adaptive millennium'] = 0.16, --Default and 0.15 results in top right and bottom left being thought to be plateaus when theyre not, 0.17 shows them as pathable
        ['Pelagial v2'] = 0.18, --Fails to detect northern island as pathable at 0.17, succeeds at 0.18
        ['Battle Swamp'] = 0.19, --Fails to detect some at 0.15, locates at 0.18 although small sections showing as impathable
        ['Fuji Phantoms'] = 0.18, --0.17 - middle shows as impathable; 0.18 - might show a bit too much of cliffs as pathable, but is lowest value where mid shows as pathable
        ['Grave Wind'] = 0.26, --some of the ramps show as partially impathable at default, not critical issue but changed to reduce potential issues
        ['Exo 50-T testing ground'] = 0.2,--]]
    }
    local sMapName = ScenarioInfo.name
    --Specific map types - astro has issue with amphibious check so will set flag to use terrainheight instsead of surface height
    local i, j = string.find(sMapName, "Astro")
    if i and j then bUseTerrainHeightForBeachCheck = true end
    iAmphibiousMaxHeightDif = (tMapHeightOverride[sMapName] or iAmphibiousMaxHeightDif)
    if bDebugMessages == true then LOG(sFunctionRef..': sMapName='..sMapName..'; tMapHeightOverride='..(tMapHeightOverride[sMapName] or 'No override')..'; iMaxHeightDif='..iMaxHeightDif..'; Playable area='..repr(rMapPlayableArea)..'; bUseTerrainHeightForBeachCheck='..tostring(bUseTerrainHeightForBeachCheck)) end
end


function GetPathingSegmentFromPosition(tPosition)
    --Base level segment numbers
    local rPlayableArea = rMapPlayableArea
    local iBaseSegmentSize = iSizeOfBaseLevelSegment
    --LOG('Temp log for GetPathingSegmentFromPosition: tPosition='..repru((tPosition or {'nil'}))..'; rPlayableArea='..repru((rPlayableArea or {'nil'})))
    --LOG('iBaseSegmentSize='..(iBaseSegmentSize or 'nil'))
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
    if bDebugMessages == true then LOG(sFunctionRef..': t='..t..'; x='..x..'; y='..y..'; z='..z..'; size='..repru(size)) end

    if t == 'Mass' then
        MassCount = MassCount + 1
        MassPoints[MassCount] = {x,y,z}
    elseif t == 'Hydrocarbon' then
        HydroCount = HydroCount + 1
        HydroPoints[HydroCount] = {x,y,z}
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of hook') end
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
    local iResourceCount, sPathing, sLocationRef
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
            if bDebugMessages == true then LOG(sFunctionRef..': v.position='..repru(v.position)..'; bCanBuildMexOnmassPoint='..tostring(bCanBuildOnResourcePoint)) end
            if bCanBuildOnResourcePoint then -- or aiBrain:CanBuildStructureAt('URB1103', v.position) == true or moho.aibrain_methods.CanBuildStructureAt(aiBrain, 'ueb1103', v.position) then
                MassCount = MassCount + 1
                MassPoints[MassCount] = v.position
                if bDebugMessages == true then
                    local iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(MassPoints[MassCount])
                    LOG(sFunctionRef..': Recording masspoints: co-ordinates = ' ..repru(MassPoints[MassCount])..'; SegmentX-Z='..iSegmentX..'-'..iSegmentZ)
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
            if bDebugMessages == true then LOG(sFunctionRef..': v.position='..repru(v.position)..'; bCanBuildMexOnmassPoint='..tostring(bCanBuildOnResourcePoint)) end
            if bCanBuildOnResourcePoint then
                HydroCount = HydroCount + 1
                HydroPoints[HydroCount] = v.position
                iMarkerType = 2
                iResourceCount = HydroCount
                if bDebugMessages == true then LOG(sFunctionRef..': Recording hydrocarbon points: co-ordinates = '..repru(HydroPoints[HydroCount])) end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Cant build hydro at hydro marker so ignoring as might be adaptive map') end
            end
        end -- Hydrocarbon
        --Update unmapped marker list:

        --[[for iPathingType = 1, iMaxPathingType do
            if iPathingType == 1 then sPathing = M27UnitInfo.refPathingTypeAmphibious
            elseif iPathingType == 2 then sPathing = M27UnitInfo.refPathingTypeNavy
            elseif iPathingType == 3 then sPathing = M27UnitInfo.refPathingTypeAir
            else sPathing = M27UnitInfo.refPathingTypeLand
            end ]]--
        if iMarkerType > 0 then
            for iPathingType, sPathing in M27UnitInfo.refPathingTypeAll do
                if tUnmappedMarker[sPathing] == nil then tUnmappedMarker[sPathing] = {} end
                if tUnmappedMarker[sPathing][iMarkerType] == nil then tUnmappedMarker[sPathing][iMarkerType] = {} end
                tUnmappedMarker[sPathing][iMarkerType][iResourceCount] = v.position
            end
        end
    end -- GetMarkers() loop
    if bDebugMessages == true then
        LOG(sFunctionRef..': Finished recording mass markers, total mass marker count='..MassCount..'; list of all mass points='..repru(MassPoints))
    end

    -- MapMexCount = MassCount
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordResourceNearStartPosition(iStartPositionNumber, iMaxDistance, bCountOnly, bMexNotHydro)
    -- iStartPositionNumber is the .M27StartPositionNumber for the brain; iMaxDistance is the max distance for a mex to be returned (this only works the first time ever this function is called)
    --bMexNotHydro - true if looking for nearby mexes, false if looking for nearby hydros; defaults to true

    -- Returns a table containing positions of any mex meeting the criteria, unless bCountOnly is true in which case returns the no. of such mexes
    local sFunctionRef = 'RecordResourceNearStartPosition'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, iStartPositionNumber='..(iStartPositionNumber or 'nil')..'; iMaxDistance='..(iMaxDistance or 'nil')..'; bCountOnly='..tostring(bCountOnly or false)..'; bMexNotHydro='..tostring(bMexNotHydro or false)..'; Full PlayerStartPoints table='..repru(PlayerStartPoints)..'; GameTime='..GetGameTimeSeconds()..'; MassCount='..(MassCount or 'nil')) end
    if iMaxDistance == nil then iMaxDistance = 12 end --NOTE: As currently only run the actual code to locate nearby mexes once, the first iMaxDistance will determine what to use, and any subsequent uses it wont matter
    if bMexNotHydro == nil then bMexNotHydro = true end
    if bCountOnly == nil then bCountOnly = false end
    local iResourceCount = 0
    local iResourceType = 1 --1 = mex, 2 = hydro
    if bMexNotHydro == false then iResourceType = 2 end

    if tResourceNearStart[iStartPositionNumber] == nil then tResourceNearStart[iStartPositionNumber] = {} end

    if tResourceNearStart[iStartPositionNumber][iResourceType] == nil then
        --Haven't determined nearby resource yet
        local iDistance = 0
        local pStartPos =  PlayerStartPoints[iStartPositionNumber]

        tResourceNearStart[iStartPositionNumber][iResourceType] = {}
        local AllResourcePoints = {}
        if bMexNotHydro then AllResourcePoints = MassPoints
        else AllResourcePoints = HydroPoints end

        local iClosestResource = 1000000

        if not(AllResourcePoints == nil) then
            if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through all resource points to find mexes near start position='..repru(pStartPos)..' for start position number='..iStartPositionNumber..'; PlayerStartPoints='..repru(PlayerStartPoints)) end
            for key,pResourcePos in AllResourcePoints do
                iDistance = M27Utilities.GetDistanceBetweenPositions(pStartPos, pResourcePos)
                if iDistance <= iMaxDistance then
                    if bDebugMessages == true then LOG('Found position near to start; iDistance='..iDistance..'; imaxDistance='..iMaxDistance..'; pStartPos[1][3]='..pStartPos[1]..'-'..pStartPos[3]..'; pResourcePos='..pResourcePos[1]..'-'..pResourcePos[3]..'; bMexNotHydro='..tostring(bMexNotHydro)) end
                    iResourceCount = iResourceCount + 1
                    if tResourceNearStart[iStartPositionNumber][iResourceType][iResourceCount] == nil then tResourceNearStart[iStartPositionNumber][iResourceType][iResourceCount] = {} end
                    tResourceNearStart[iStartPositionNumber][iResourceType][iResourceCount] = pResourcePos
                end
                iClosestResource = math.min(iDistance, iClosestResource)
            end
            if bMexNotHydro and not(bCountOnly) and iResourceCount <= 1 then
                --Get the nearest mex to the start and then search here + 10
                for key, pResourcePos in AllResourcePoints do
                    iDistance = M27Utilities.GetDistanceBetweenPositions(pStartPos, pResourcePos)
                    if iDistance <= iClosestResource + 10 then
                        if bDebugMessages == true then LOG('Found position near to start; iDistance='..iDistance..'; imaxDistance='..iMaxDistance..'; pStartPos[1][3]='..pStartPos[1]..'-'..pStartPos[3]..'; pResourcePos='..pResourcePos[1]..'-'..pResourcePos[3]..'; bMexNotHydro='..tostring(bMexNotHydro)) end
                        iResourceCount = iResourceCount + 1
                        if tResourceNearStart[iStartPositionNumber][iResourceType][iResourceCount] == nil then tResourceNearStart[iStartPositionNumber][iResourceType][iResourceCount] = {} end
                        tResourceNearStart[iStartPositionNumber][iResourceType][iResourceCount] = pResourcePos
                    end
                end

            end
        end
    end
    if bCountOnly == false then
        --Create a table of nearby resource locations:
        local NearbyResourcePos = {}
        for iCurResource, v in tResourceNearStart[iStartPositionNumber][iResourceType] do
            NearbyResourcePos[iResourceCount] = v
        end
        if bDebugMessages == true then LOG(sFunctionRef..': End of code. tResourceNearStart='..repru(tResourceNearStart)) end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return NearbyResourcePos
    else
        iResourceCount = 0
        for iCurResource, v in tResourceNearStart[iStartPositionNumber][iResourceType] do
            iResourceCount = iResourceCount + 1
            if bDebugMessages == true then LOG('valid resource location iResourceCount='..iResourceCount..'; v[1-3]='..v[1]..'-'..v[2]..'-'..v[3]) end
        end
        if bDebugMessages == true then LOG('RecordResourceNearStartPosition: iResourceCount='..iResourceCount..'; bmexNotHydro='..tostring(bMexNotHydro)..'; iMaxDistance='..iMaxDistance..'; tResourceNearStart='..repru(tResourceNearStart)) end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return iResourceCount
    end
end
function RecordMexNearStartPosition(iStartPositionNumber, iMaxDistance, bCountOnly, bReturnCount)
    if bReturnCount then return RecordResourceNearStartPosition(iStartPositionNumber, iMaxDistance, bCountOnly, true)
    else RecordResourceNearStartPosition(iStartPositionNumber, iMaxDistance, bCountOnly, true)
    end

end

function RecordHydroNearStartPosition(iStartPositionNumber, iMaxDistance, bCountOnly, bReturnCount)
    if bReturnCount then
        return RecordResourceNearStartPosition(iStartPositionNumber, iMaxDistance, bCountOnly, false)
    else
        RecordResourceNearStartPosition(iStartPositionNumber, iMaxDistance, bCountOnly, false)
    end
end

function RecordPlayerStartLocations()
    -- Updates PlayerStartPoints to Record all the possible player start points
    --Note: The game allows for aiBrain:GetArmyStartPos(); M27 has its own function since this allows recording employ player start positions which gives an indication of if it's likely controlled by the enemy but o ther AI may want to just use GetArmyStartPos()
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordPlayerStartLocations'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iMarkerType = 3
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code. bUsingArmyIndexForStartPosition='..tostring((bUsingArmyIndexForStartPosition or false))) end
    if not(bUsingArmyIndexForStartPosition) then
        for i = 1, 16 do
            local tempPos = ScenarioUtils.GetMarker('ARMY_'..i).position
            if tempPos ~= nil then
                PlayerStartPoints[i] = tempPos
                if bDebugMessages == true then LOG('* M27AI: Recording Player start point, ARMY_'..i..' x=' ..PlayerStartPoints[i][1]..';y='..PlayerStartPoints[i][2]..';z='..PlayerStartPoints[i][3]) end
                for iPathingType, sPathing in M27UnitInfo.refPathingTypeAll do
                    if tUnmappedMarker[sPathing] == nil then tUnmappedMarker[sPathing] = {} end
                    if tUnmappedMarker[sPathing][iMarkerType] == nil then tUnmappedMarker[sPathing][iMarkerType] = {} end
                    tUnmappedMarker[sPathing][iMarkerType][i] = tempPos
                end
            end
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': Dont have ARMY references in a numerical format, so will revert to just recording the aiBrains start positions by their army index and ignore markers') end
        for iBrain, oBrain in ArmyBrains do

            PlayerStartPoints[oBrain:GetArmyIndex()] = {}
            PlayerStartPoints[oBrain:GetArmyIndex()][1], PlayerStartPoints[oBrain:GetArmyIndex()][3] = oBrain:GetArmyStartPos()
            PlayerStartPoints[oBrain:GetArmyIndex()][2] = GetTerrainHeight(PlayerStartPoints[oBrain:GetArmyIndex()][1], PlayerStartPoints[oBrain:GetArmyIndex()][3])
            if bDebugMessages == true then LOG(sFunctionRef..': Brain name='..oBrain.Name..'; iBrain='..iBrain..'; Start position='..repru(PlayerStartPoints[oBrain:GetArmyIndex()])) end
        end
    end

    --Record start groups
    for iBrain, oBrain in ArmyBrains do
        if M27Utilities.IsTableEmpty(PlayerStartPoints[oBrain.M27StartPositionNumber]) == false then
            RecordStartingPathingGroups(oBrain)
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, PlayerStartPoints='..repru(PlayerStartPoints)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
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
                if bDebugMessages == true then LOG(sFunctionRef..': iDistance='..iDistance..'; pResourcePos='..repru(pResourcePos)) end
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
        LOG('TEMPMAPTEST: '..sExtraRef..': Result for position '..repru(tCurLocation)..' = '..iResult..'; Can ACU path to this location='..tostring(oACU:CanPathTo(tCurLocation))..'; GameTime='..GetGameTimeSeconds())
    end--]]
end

function InSameSegmentGroup(oUnit, tDestination, bReturnUnitGroupOnly, bReturnDestinationGroupOnly)
    local sFunctionRef = 'InSameSegmentGroup'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if oUnit and not(oUnit.Dead) and oUnit.GetUnitId then
        local sPathing = M27UnitInfo.GetUnitPathingType(oUnit)
        if sPathing == M27UnitInfo.refPathingTypeAir then
            if bReturnUnitGroupOnly or bReturnDestinationGroupOnly then return 1 else return true end
        else
            if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
            local tCurPosition = oUnit:GetPosition()
            local iSegmentX, iSegmentZ, iUnitGroup, iTargetSegmentX, iTargetSegmentZ, iTargetGroup
            if not(bReturnDestinationGroupOnly) then
                iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(tCurPosition)
                iUnitGroup = tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ]
            end
            if not(bReturnUnitGroupOnly) then
                iTargetSegmentX, iTargetSegmentZ = GetPathingSegmentFromPosition(tDestination)
                iTargetGroup = tPathingSegmentGroupBySegment[sPathing][iTargetSegmentX][iTargetSegmentZ]
            end

            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            if bReturnUnitGroupOnly then
                return iUnitGroup
            elseif bReturnDestinationGroupOnly then
                return iTargetGroup
            end
            if iUnitGroup == iTargetGroup then return true else return false end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetSegmentGroupOfTarget(sPathing, iTargetSegmentX, iTargetSegmentZ)
    --Returns unit group for the target segment position, or nil if its not known; oUnit should be specified to allow it to see if oUnit can path there (in case we havent recorded the location yet)
    if sPathing == M27UnitInfo.refPathingTypeAmphibious or sPathing == M27UnitInfo.refPathingTypeLand or sPathing == M27UnitInfo.refPathingTypeNavy then
        return tPathingSegmentGroupBySegment[sPathing][iTargetSegmentX][iTargetSegmentZ]
    elseif sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then
        return tPathingSegmentGroupBySegment[M27UnitInfo.refPathingTypeLand][iTargetSegmentX][iTargetSegmentZ]
    elseif sPathing == M27UnitInfo.refPathingTypeAir then return 1
    else M27Utilities.ErrorHandler('Unrecognised pathing type, sPathing='..(sPathing or 'nil'))
    end
end

function GetSegmentGroupOfLocation(sPathing, tLocation)
    local iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(tLocation)
    if sPathing == M27UnitInfo.refPathingTypeAmphibious or sPathing == M27UnitInfo.refPathingTypeLand or sPathing == M27UnitInfo.refPathingTypeNavy then
        return tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ]
    elseif sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then
        return tPathingSegmentGroupBySegment[M27UnitInfo.refPathingTypeLand][iSegmentX][iSegmentZ]
    elseif sPathing == M27UnitInfo.refPathingTypeAir then return 1
    else M27Utilities.ErrorHandler('Unrecognised pathing type, sPathing='..(sPathing or 'nil'))
    end
end


function GetUnitSegmentGroup(oUnit)
    --Intended for convenience not optimisation - if going to be called alot of times use other approach
    local sPathing = M27UnitInfo.GetUnitPathingType(oUnit)
    local iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(oUnit:GetPosition())
    if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand
    elseif sPathing == M27UnitInfo.refPathingTypeAir then return 1
    end

    return tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ]
end

function FixSegmentPathingGroup(sPathing, tLocation, iCorrectPathingGroup)
    --Called if CanPathTo identifies an inconsistency in our pathing logic - basic fix
    --Try using RecheckPathingOfLocation in future which incorporates this

    --have commented out code re updating amphibious pathing based on land pathing check, as its flawed since the correctpathinggroup might be different for teh amphibious pathing
    if sPathing == M27UnitInfo.refPathingTypeAir then
        M27Utilities.ErrorHandler('Have air pathing so will ignore pathing inconsistency, but should check code history as should try and avoid fixing in the first place')
        --Do nothing
    else
        if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
        local iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(tLocation)
        --local bUpdateAmphibiousWithSameGroup = false
        local iOldPathingGroup = tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ]
        --if sPathing == M27UnitInfo.refPathingTypeLand and tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ] == tPathingSegmentGroupBySegment[M27UnitInfo.refPathingTypeAmphibious][iSegmentX][iSegmentZ] then bUpdateAmphibiousWithSameGroup = true end
        tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ] = iCorrectPathingGroup
        --if bUpdateAmphibiousWithSameGroup then tPathingSegmentGroupBySegment[M27UnitInfo.refPathingTypeAmphibious][iSegmentX][iSegmentZ] = iCorrectPathingGroup end
        tManualPathingChecks[sPathing][M27Utilities.ConvertLocationToReference(tLocation)] = {tLocation[1], tLocation[2], tLocation[3]}
        if M27Utilities.IsTableEmpty(tSegmentBySegmentGroup[sPathing][iOldPathingGroup]) == false then
            for iEntry, tSegments in tSegmentBySegmentGroup[sPathing][iOldPathingGroup] do
                --table.insert into this is tSegmentBySegmentGroup[sPathing][iPathingGroup], {iSegmentX, iSegmentZ}
                if tSegments == {iSegmentX, iSegmentZ} then
                    table.remove(tSegmentBySegmentGroup[sPathing][iOldPathingGroup], iEntry)
                    break
                end
            end
        end
        if not(tSegmentBySegmentGroup[sPathing][iCorrectPathingGroup]) then tSegmentBySegmentGroup[sPathing][iCorrectPathingGroup] = {} end
        table.insert(tSegmentBySegmentGroup[sPathing][iCorrectPathingGroup], {iSegmentX, iSegmentZ})
    end
end

function RecheckPathingAroundLocationIfUnitIsCorrect(sPathing, oPathingUnit, iUnitCorrectPathingGroup, tTargetLocation, iSegmentSizeAdjust)
    --Intended to be called if we identify an incorrect pathing, so the area around that pathing can also be checked/updated
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecheckPathingAroundLocationIfUnitIsCorrect'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if EntityCategoryContains(categories.MOBILE, oPathingUnit.UnitId) then --Hard crash of game if do :CanPathTo on a structure, which could happen given structures use some of the platoon logic e.g. for mobile shield assistance
        if iSegmentSizeAdjust == nil then iSegmentSizeAdjust = 4 end

        if iSegmentSizeAdjust > 0 then


            local iBaseSegmentX, iBaseSegmentZ = GetPathingSegmentFromPosition(tTargetLocation)
            local tCurTargetLocation

            for iSegmentX = -iSegmentSizeAdjust + iBaseSegmentX, iSegmentSizeAdjust + iBaseSegmentX, 1 do
                for iSegmentZ = -iSegmentSizeAdjust + iBaseSegmentZ, iSegmentSizeAdjust + iBaseSegmentZ, 1 do
                    if not(iSegmentX == iBaseSegmentX and iSegmentZ == iBaseSegmentZ) then
                        if not(GetSegmentGroupOfTarget(sPathing, iSegmentX, iSegmentZ) == iUnitCorrectPathingGroup) then
                            tCurTargetLocation = GetPositionFromPathingSegments(iSegmentX, iSegmentZ)
                            if not(tManualPathingChecks[sPathing][M27Utilities.ConvertLocationToReference(tCurTargetLocation)]) then
                                if oPathingUnit:CanPathTo(tCurTargetLocation) then
                                    FixSegmentPathingGroup(sPathing, tCurTargetLocation, iUnitCorrectPathingGroup)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end


function RecheckPathingOfLocation(sPathing, oPathingUnit, tTargetLocation, tOptionalComparisonKnownCorrectPoint, bPlateauCheckActive)
    --E.g. set tKnownCorrectPoint to the player start position; will update the pathing
    --return true if pathing has changed, or false if no change
    --tOptionalComparisonKnownCorrectPoint is optional
    --bPlateauCheckActive - called within this function if doing a check of all plateau mexes as a result - to avoid infinite loop

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecheckPathingOfLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if M27UnitInfo.IsUnitValid(oPathingUnit) and EntityCategoryContains(categories.MOBILE, oPathingUnit.UnitId) then --Hard crash of game if do :CanPathTo on a structure, which could happen given structures use some of the platoon logic e.g. for mobile shield assistance then
        local iEstimatedPathingTime = 0

        --Ignore the check if we have had too many slowdowns for this unit, or this brain
        local aiBrain = oPathingUnit:GetAIBrain()
        if (oPathingUnit[M27UnitInfo.refiPathingCheckCount] and oPathingUnit[M27UnitInfo.refiPathingCheckCount] >= 2 and ((oPathingUnit[M27UnitInfo.refiPathingCheckCount] >= 10 and oPathingUnit[M27UnitInfo.refiPathingCheckTime] >= 0.3) or oPathingUnit[M27UnitInfo.refiPathingCheckTime] >= 0.7))
            or (aiBrain[M27UnitInfo.refiPathingCheckCount] >= 4 and (aiBrain[M27UnitInfo.refiPathingCheckTime] >= 3.5 or aiBrain[M27UnitInfo.refiPathingCheckCount] >= 8 and aiBrain[M27UnitInfo.refiPathingCheckTime] >= 2.5))
            then

            --Do nothing, dont want to risk constant slowdowns which can happen on larger maps if a unit manages to break out of a plateau
            if not(oPathingUnit['M27UnitMapPathingCheckAbort']) then
                oPathingUnit['M27UnitMapPathingCheckAbort'] = true
                if not(bStoppedSomePathingChecks) then
                    M27Utilities.ErrorHandler('Wont do any more pathing checks for unit being considered as want to avoid major slowdowns', true)
                    bStoppedSomePathingChecks = true
                end
            end
        else

            oPathingUnit[M27UnitInfo.refiPathingCheckCount] = (oPathingUnit[M27UnitInfo.refiPathingCheckCount] or 0) + 1
            local iCurSystemTime = GetSystemTimeSecondsOnlyForProfileUse()

            local bHaveChangedPathing = false
            if sPathing == M27UnitInfo.refPathingTypeAir then
                --Do nothing
            else
                if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end

                if not(tOptionalComparisonKnownCorrectPoint) then
                    --[[if M27Utilities.IsTableEmpty(tResourceNearStart[oPathingUnit:GetAIBrain():GetArmyIndex()][1][1]) == false then
                        tOptionalComparisonKnownCorrectPoint = tResourceNearStart[oPathingUnit:GetAIBrain():GetArmyIndex()][1][1]
                    else--]]
                    tOptionalComparisonKnownCorrectPoint = PlayerStartPoints[oPathingUnit:GetAIBrain().M27StartPositionNumber]
                    --end
                end

                local iUnitPathingGroup = GetSegmentGroupOfLocation(sPathing, oPathingUnit:GetPosition())
                local iTargetPathingGroup = GetSegmentGroupOfLocation(sPathing, tTargetLocation)
                local iBasePathingGroup = GetSegmentGroupOfLocation(sPathing, tOptionalComparisonKnownCorrectPoint)

                local iCurManualCheckDist
                local sClosestManualCheckRef

                if bDebugMessages == true then LOG(sFunctionRef..': GameTIMe='..GetGameTimeSeconds()..'; Checking pathing for tTargetLocation='..repru(tTargetLocation)..' using oPathingUnit='..oPathingUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oPathingUnit)) end


                if not(tManualPathingChecks[sPathing][M27Utilities.ConvertLocationToReference(oPathingUnit:GetPosition())]) then
                    local iClosestManualCheck = M27Utilities.GetDistanceBetweenPositions(oPathingUnit:GetPosition(), tOptionalComparisonKnownCorrectPoint)
                    if bDebugMessages == true then LOG(sFunctionRef..': iClosestManualCheck='..iClosestManualCheck..'; Unit position='..repru(oPathingUnit:GetPosition())..'; targetposition='..repru(tTargetLocation)) end
                    if iClosestManualCheck > 50 then
                        --Find the closest location where have done a manual check that has the same pathing group as the comparison known correct point
                        if M27Utilities.IsTableEmpty(tManualPathingChecks[sPathing]) == false then
                            if bDebugMessages == true then LOG(sFunctionRef..'WIll go through every entry in tManualPathingChecks and see how close it is') end
                            for sLocationRef, tLocationChecked in tManualPathingChecks[sPathing] do
                                iCurManualCheckDist = M27Utilities.GetDistanceBetweenPositions(tLocationChecked, oPathingUnit:GetPosition())
                                if bDebugMessages == true then LOG(sFunctionRef..': tLocationChecked='..repru(tLocationChecked)..'; iCurManualCheckDist='..iCurManualCheckDist..'; iClosestManualCheck='..iClosestManualCheck) end
                                if iCurManualCheckDist < iClosestManualCheck and GetSegmentGroupOfLocation(sPathing, tLocationChecked) == iBasePathingGroup then
                                    sClosestManualCheckRef = sLocationRef
                                    iClosestManualCheck = iCurManualCheckDist
                                    if iClosestManualCheck <= 50 then break end
                                end
                            end
                        end
                    end
                end
                local tKnownCorrectPoint
                if sClosestManualCheckRef then
                    tKnownCorrectPoint = tManualPathingChecks[sPathing][sClosestManualCheckRef]
                else
                    tKnownCorrectPoint = tOptionalComparisonKnownCorrectPoint
                end

                local bCanPathToTarget = oPathingUnit:CanPathTo(tTargetLocation)
                local bCanPathToBase = oPathingUnit:CanPathTo(tKnownCorrectPoint)
                iEstimatedPathingTime = iEstimatedPathingTime + 0.05
                local bExpectedToPathToTarget = false
                if iUnitPathingGroup == iTargetPathingGroup then bExpectedToPathToTarget = true end
                local bExpectedToPathToBase = false
                if iUnitPathingGroup == iBasePathingGroup then bExpectedToPathToBase = true end
                local bTargetIsBase = false
                if tTargetLocation[1] == tKnownCorrectPoint[1] and tTargetLocation[3] == tKnownCorrectPoint[3] then bTargetIsBase = true
                elseif tTargetLocation[1] == PlayerStartPoints[oPathingUnit:GetAIBrain().M27StartPositionNumber][1] and tTargetLocation[3] == PlayerStartPoints[oPathingUnit:GetAIBrain().M27StartPositionNumber][3] then bTargetIsBase = true
                end

                if bDebugMessages == true then LOG(sFunctionRef..': About to start main checks, oPathingUnit='..oPathingUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oPathingUnit)..'; iUnitPathingGroup='..iUnitPathingGroup..'; iTargetPathingGroup='..iTargetPathingGroup..'; iBasePathingGroup='..iBasePathingGroup..'; manual check for engi position='..repru(tManualPathingChecks[sPathing][M27Utilities.ConvertLocationToReference(oPathingUnit:GetPosition())] or { 'nil'})..'; bCanPathToTarget='..tostring(bCanPathToTarget)..'; bCanPathToBase='..tostring(bCanPathToBase)..'; bExpectedToPathToBase='..tostring(bExpectedToPathToBase)..'; bExpectedToPathToTarget='..tostring(bExpectedToPathToTarget)) end

                --Have we not checked the pathing of either the engineer position or the target?
                if not(tManualPathingChecks[sPathing][M27Utilities.ConvertLocationToReference(oPathingUnit:GetPosition())]) or not(tManualPathingChecks[sPathing][M27Utilities.ConvertLocationToReference(tTargetLocation)]) then
                    local iAmphibiousOrigGroupOfTarget
                    local iAmphibiousOrigGroupOfPathingUnit
                    if sPathing == M27UnitInfo.refPathingTypeAmphibious then
                        iAmphibiousOrigGroupOfTarget = GetSegmentGroupOfLocation(sPathing, tTargetLocation)
                        iAmphibiousOrigGroupOfPathingUnit = GetSegmentGroupOfLocation(sPathing, oPathingUnit:GetPosition())
                        if bDebugMessages == true then LOG(sFunctionRef..': sPathing is amphibious so have recorded iAmphibiousOrigGroupOfTarget and iAmphibiousOrigGroupOfPathingUnit as '..iAmphibiousOrigGroupOfTarget..' and '..iAmphibiousOrigGroupOfPathingUnit) end
                    elseif bDebugMessages == true then LOG(sFunctionRef..': Pathing isnt amphibious. sPathing='..sPathing..'; M27UnitInfo.refPathingTypeAmphibious='..M27UnitInfo.refPathingTypeAmphibious)
                    end

                    if bDebugMessages == true then
                        LOG(sFunctionRef..': Will draw the 3 positions in red, with a line. sPathing='..sPathing..'; M27UnitInfo.refPathingTypeAmphibious='..M27UnitInfo.refPathingTypeAmphibious..'; iAmphibiousOrigGroupOfTarget='..(iAmphibiousOrigGroupOfTarget or 'nil')..'; iAmphibiousOrigGroupOfPathingUnit='..(iAmphibiousOrigGroupOfPathingUnit or 'nil'))
                        M27Utilities.DrawLocations({tKnownCorrectPoint, oPathingUnit:GetPosition(), tTargetLocation}, nil, 2, 200)
                        M27Utilities.ErrorHandler('Temp to see history of function call', true)
                    end

                    if bDebugMessages == true then LOG(sFunctionRef..': First time doing a manual check for this location') end
                    if bCanPathToBase then
                        if not(iUnitPathingGroup == iBasePathingGroup) then
                            bHaveChangedPathing = true
                            if bDebugMessages == true then LOG(sFunctionRef..': Can path to base but we didnt think we could, will change unit pathing group to '..iBasePathingGroup) end
                            iEstimatedPathingTime = iEstimatedPathingTime + 0.05
                            FixSegmentPathingGroup(sPathing, oPathingUnit:GetPosition(), iBasePathingGroup)
                            RecheckPathingAroundLocationIfUnitIsCorrect(sPathing, oPathingUnit, iBasePathingGroup, oPathingUnit:GetPosition(), 4)

                            if not(bTargetIsBase) and bCanPathToTarget and not(iTargetPathingGroup == iBasePathingGroup) then
                                if bDebugMessages == true then LOG(sFunctionRef..': target location cna path to base but we didnt think it could, will change target pathing group to '..iBasePathingGroup) end
                                iEstimatedPathingTime = iEstimatedPathingTime + 0.05
                                FixSegmentPathingGroup(sPathing, tTargetLocation, iBasePathingGroup)
                                --Check an area around the target (if its not really far away)
                                RecheckPathingAroundLocationIfUnitIsCorrect(sPathing, oPathingUnit, iBasePathingGroup, tTargetLocation, math.min(6, math.floor(250 / M27Utilities.GetDistanceBetweenPositions(oPathingUnit:GetPosition(), tTargetLocation))))
                            end
                        else
                            --Can path to base, and correctly think we can; can we path to the target?
                            if not(bTargetIsBase) and bCanPathToTarget then
                                if not(bExpectedToPathToTarget) then
                                    --can path to target but didnt think we could
                                    if bDebugMessages == true then LOG(sFunctionRef..': Incorrectly think we cant path to the target') end
                                    iEstimatedPathingTime = iEstimatedPathingTime + 0.05
                                    FixSegmentPathingGroup(sPathing, tTargetLocation, iBasePathingGroup)
                                    RecheckPathingAroundLocationIfUnitIsCorrect(sPathing, oPathingUnit, iBasePathingGroup, tTargetLocation, math.min(6, math.floor(250 / M27Utilities.GetDistanceBetweenPositions(oPathingUnit:GetPosition(), tTargetLocation))))
                                end
                            end
                        end
                    else
                        --Cant path to base - below updates to pathing group arent as accurate so will only update the target not the area around it
                        if bExpectedToPathToBase then
                            --Incorrectly think we can path to base, so change our pathing group to something else - add 1 to current size
                            bHaveChangedPathing = true
                            local iNewPathingGroup = table.getn(tSegmentBySegmentGroup[sPathing]) + 1
                            if bDebugMessages == true then LOG(sFunctionRef..': Incorrectly think we can path to base, will set engineer position group to '..iNewPathingGroup) end
                            iEstimatedPathingTime = iEstimatedPathingTime + 0.05
                            FixSegmentPathingGroup(sPathing, oPathingUnit:GetPosition(), iNewPathingGroup)
                            --Is there also an issue with the target?
                            if not(bTargetIsBase) and bCanPathToTarget and iTargetPathingGroup == iBasePathingGroup then
                                if bDebugMessages == true then LOG(sFunctionRef..': Incorrectly think the target can path to base, will set target location group to '..iNewPathingGroup) end
                                iEstimatedPathingTime = iEstimatedPathingTime + 0.05
                                FixSegmentPathingGroup(sPathing, tTargetLocation, iNewPathingGroup)
                            end
                        else
                            --cant path to base, and we correctly think we cant path to base; is the target ok?
                            if not(bTargetIsBase) then
                                if bCanPathToTarget then
                                    if bExpectedToPathToTarget then
                                        --Correctly think we can path to target so dont need to change anything
                                    else
                                        --Can path to target but werent expecting to be able to; Will assume our units pathing group is correct and will update target pathing group to be the engineers pathing group
                                        bHaveChangedPathing = true
                                        if bDebugMessages == true then LOG(sFunctionRef..': Incorrectly think we cant path to target, will set target location pathing group to '..iUnitPathingGroup) end
                                        iEstimatedPathingTime = iEstimatedPathingTime + 0.05
                                        FixSegmentPathingGroup(sPathing, tTargetLocation, iUnitPathingGroup)
                                    end
                                else
                                    if bExpectedToPathToTarget then
                                        --Cant path to target but thought we could; increase the targets pathing group
                                        bHaveChangedPathing = true
                                        if bDebugMessages == true then LOG(sFunctionRef..': Incorrectly think we can path to target, will set target location pathing group to '..(table.getn(tSegmentBySegmentGroup[sPathing]) + 1)) end
                                        iEstimatedPathingTime = iEstimatedPathingTime + 0.05
                                        FixSegmentPathingGroup(sPathing, tTargetLocation, table.getn(tSegmentBySegmentGroup[sPathing]) + 1)
                                    else
                                        --Dont have enough informatino to say antyhing more, since we cant path to base, or to the target, and we're correctly expecting to not path to either of them
                                    end
                                end
                            end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': Seeing if we have changed pathing of a plateau. bHaveChangedPathing='..tostring(bHaveChangedPathing)..'; iAmphibiousOrigGroupOfTarget='..(iAmphibiousOrigGroupOfTarget or 'nil')..'; iAmphibiousOrigGroupOfPathingUnit='..(iAmphibiousOrigGroupOfPathingUnit or 'nil')) end
                    if bHaveChangedPathing and (iAmphibiousOrigGroupOfTarget or iAmphibiousOrigGroupOfPathingUnit) and not(bPlateauCheckActive) then
                        --Have changed amphibious pathing, will see if this was a plateau that had mexes on it
                        if bDebugMessages == true then LOG(sFunctionRef..': M27Utilities.IsTableEmpty(tAllPlateausWithMexes[iAmphibiousOrigGroupOfTarget]='..tostring(M27Utilities.IsTableEmpty(tAllPlateausWithMexes[iAmphibiousOrigGroupOfTarget]))..'; is table empty based on orig amphib group of pathing unit='..tostring(M27Utilities.IsTableEmpty(tAllPlateausWithMexes[iAmphibiousOrigGroupOfPathingUnit]))..'; Pathing group of the pathing unit after update='..GetSegmentGroupOfLocation(sPathing, oPathingUnit:GetPosition())..'; group of target post update='..GetSegmentGroupOfLocation(sPathing, tTargetLocation)) end
                        local bChangedAnyMex = false
                        local iGroupAlreadyChecked
                        --Has the group of the pathing unit changed, and do we have plateau info recorded for the orig pathing group?
                        if iAmphibiousOrigGroupOfPathingUnit and not(GetSegmentGroupOfLocation(sPathing, oPathingUnit:GetPosition()) == iAmphibiousOrigGroupOfPathingUnit) and not(M27Utilities.IsTableEmpty(tAllPlateausWithMexes[iAmphibiousOrigGroupOfPathingUnit])) and not(M27Utilities.IsTableEmpty(tAllPlateausWithMexes[iAmphibiousOrigGroupOfPathingUnit][subrefPlateauMexes])) then
                            --Need to revise plateau logic - first check pathing of every mex on the plateau
                            if bDebugMessages == true then LOG(sFunctionRef..': The group of the pathing unit has changed, and there were mexes in the original pathing group, so will check all mexes in the orig pathing group') end
                            iGroupAlreadyChecked = iAmphibiousOrigGroupOfPathingUnit
                            for iMex, tMex in tAllPlateausWithMexes[iAmphibiousOrigGroupOfPathingUnit][subrefPlateauMexes] do
                                if bDebugMessages == true then LOG(sFunctionRef..': Checking for tMex='..repru(tMex)..'; with mex pathing group='..GetSegmentGroupOfLocation(sPathing, tMex)..'; iAmphibiousOrigGroupOfPathingUnit='..iAmphibiousOrigGroupOfPathingUnit) end
                                iEstimatedPathingTime = iEstimatedPathingTime + 0.05
                                if RecheckPathingOfLocation(sPathing, oPathingUnit, tMex, tOptionalComparisonKnownCorrectPoint, true) or not(GetSegmentGroupOfLocation(sPathing, tMex) == iAmphibiousOrigGroupOfPathingUnit) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Pathing was dif for iMex='..iMex..'; tMex='..repru(tMex)..' or the mex shouldnt be assigned to this plateau') end
                                    bChangedAnyMex = true
                                end
                            end
                        end
                        --Has the group of the target changed, and do we have plateau info recorded for the orig pathing group?
                        if not(bChangedAnyMex) and iAmphibiousOrigGroupOfTarget and not(iGroupAlreadyChecked == iAmphibiousOrigGroupOfTarget) and not(GetSegmentGroupOfLocation(sPathing, tTargetLocation) == iAmphibiousOrigGroupOfTarget) and not(M27Utilities.IsTableEmpty(tAllPlateausWithMexes[iAmphibiousOrigGroupOfTarget])) and not(M27Utilities.IsTableEmpty(tAllPlateausWithMexes[iAmphibiousOrigGroupOfTarget][subrefPlateauMexes])) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Amphibious group of the target is different to what we originally thought, and the original grouping had mexes in, so will recheck all mexes in the group') end
                            for iMex, tMex in tAllPlateausWithMexes[iAmphibiousOrigGroupOfTarget][subrefPlateauMexes] do
                                if RecheckPathingOfLocation(sPathing, oPathingUnit, tMex, tOptionalComparisonKnownCorrectPoint, true) or not(GetSegmentGroupOfLocation(sPathing, tMex) == iAmphibiousOrigGroupOfTarget) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Pathing was dif for iMex='..iMex..'; tMex='..repru(tMex)) end
                                    bChangedAnyMex = true
                                end
                            end
                        end
                        if bChangedAnyMex then
                            if bDebugMessages == true then LOG(sFunctionRef..': Have changed pathing of at least one mex, so will re-record all mexes for all pathing groups') end
                            RecordMexForPathingGroup()
                            RecordAllPlateaus()
                            for iBrain, oBrain in M27Overseer.tAllActiveM27Brains do
                                UpdatePlateausToExpandTo(oBrain, true, true)
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': Finished updating details of mexes and plateaus to expand to') end
                        end
                    end
                elseif bDebugMessages == true then LOG(sFunctionRef..': Have already done a manual check of this location')
                end
            end

            oPathingUnit[M27UnitInfo.refiPathingCheckTime] = (oPathingUnit[M27UnitInfo.refiPathingCheckTime] or 0) + iEstimatedPathingTime
            aiBrain[M27UnitInfo.refiPathingCheckTime] = (aiBrain[M27UnitInfo.refiPathingCheckTime] or 0) + iEstimatedPathingTime
            aiBrain[M27UnitInfo.refiPathingCheckCount] = (aiBrain[M27UnitInfo.refiPathingCheckCount] or 0) + 1
            if iEstimatedPathingTime > 0.3 then bDebugMessages = true end --Retain for audit trail - to show significant pathing related freezes we have had
            if bDebugMessages == true then LOG(sFunctionRef..': GameTime='..GetGameTimeSeconds()..'; bHaveChangedPathing='..tostring(bHaveChangedPathing)..'; Estimated time taken for this cycle='..iEstimatedPathingTime..'; Brain count='..aiBrain[M27UnitInfo.refiPathingCheckCount]..'; Brain total time='..aiBrain[M27UnitInfo.refiPathingCheckTime]) end
            if bDebugMessages == true and bHaveChangedPathing then M27Utilities.ErrorHandler('Have changed pathing', true) end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return bHaveChangedPathing
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetReclaimablesMassAndEnergy(tReclaimables, iMinMass, iMinEnergy)
    --Largely a copy of GetReclaimablesResourceValue, but focused specificaly on the reclaim segment update logic
    --Must have at least iMinMass or iMinEnergy to be recorded
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetReclaimablesMassAndEnergy'
    --V14 and earlier would modify total mass value to reduce it by 25% if its small, and 50% if its medium; v15 removed this
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local sMassRef = 'MaxMassReclaim'
    local sEnergyRef = 'MaxEnergyReclaim'

    local tWreckPos = {}
    local iTotalMass = 0
    local iTotalEnergy = 0

    local iLargestCurReclaim = 0
    local iLargestReclaimRef = 0

    if tReclaimables and table.getn( tReclaimables ) > 0 then
        for iReclaimRef, v in tReclaimables do
            tWreckPos = v.CachePosition
            if tWreckPos[1] then
                --if v.MaxMassReclaim > iIgnoreReclaimIfNotMoreThanThis then
                if v[sMassRef] > iMinMass or v[sEnergyRef] > iMinEnergy then
                    if not(v:BeenDestroyed()) then
                        -- Determine mass - reduce low value mass value for weighting purposes (since it takes longer to get):
                        --if bDebugMessages == true then LOG('Have wrecks with a valid position and positive mass value within the segment iCurXZ='..iCurX..'-'..iCurZ..'; iWreckNo='.._) end
                        --iCurMassValue = v.MaxMassReclaim / (iMedMassMod * iLargeMassMod)
                        --if iCurMassValue >= iMedMassThreshold then iCurMassValue = iCurMassValue * iMedMassMod end
                        --if iCurMassValue >= iLargeMassThreshold then iCurMassValue = iCurMassValue * iLargeMassMod end
                        --iTotalResourceValue = iTotalResourceValue + iCurMassValue
                        iTotalMass = iTotalMass + v[sMassRef]
                        iTotalEnergy = iTotalEnergy + v[sEnergyRef]
                        if v[sMassRef] > iLargestCurReclaim then
                            iLargestCurReclaim = v[sMassRef]
                            iLargestReclaimRef = iReclaimRef
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
    local tReclaimPos
    if iLargestReclaimRef then tReclaimPos = {tReclaimables[iLargestReclaimRef][1], tReclaimables[iLargestReclaimRef][2], tReclaimables[iLargestReclaimRef][3]} end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iTotalMass, tReclaimPos, iLargestCurReclaim, iTotalEnergy
end

function GetReclaimablesResourceValue(tReclaimables, bAlsoReturnLargestReclaimPosition, iIgnoreReclaimIfNotMoreThanThis, bAlsoReturnAmountOfHighestIndividualReclaim, bEnergyNotMass)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetReclaimablesResourceValue'
    --V14 and earlier would modify total mass value to reduce it by 25% if its small, and 50% if its medium; v15 removed this
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bAlsoReturnLargestReclaimPosition == nil then bAlsoReturnLargestReclaimPosition = false end
    if iIgnoreReclaimIfNotMoreThanThis == nil then iIgnoreReclaimIfNotMoreThanThis = 0 end
    if iIgnoreReclaimIfNotMoreThanThis < 0 then iIgnoreReclaimIfNotMoreThanThis = 0 end
    --local iMedMassThreshold = 20 --as per large mass threshold
    --local iLargeMassThreshold = 150 --any mass with a value more than iLargeMassTreshold gets increased in weighted value by iLargeMassMod
    --local iMedMassMod = 2 --increases value of mass over a particular threshold by this
    --local iLargeMassMod = 2 --increases value of mass over a particular threshold by this (multiplicative with iMedMassMod)
    local sResourceRef = 'MaxMassReclaim'
    if bEnergyNotMass then sResourceRef = 'MaxEnergyReclaim' end

    local tWreckPos = {}
    local iCurMassValue
    local iTotalResourceValue = 0
    local iLargestCurReclaim = 0
    local tReclaimPos = {}
    if tReclaimables and table.getn( tReclaimables ) > 0 then
        for _, v in tReclaimables do
            tWreckPos = v.CachePosition
            if tWreckPos[1] then
                --if v.MaxMassReclaim > iIgnoreReclaimIfNotMoreThanThis then
                if v[sResourceRef] > iIgnoreReclaimIfNotMoreThanThis then
                    if not(v:BeenDestroyed()) then
                        -- Determine mass - reduce low value mass value for weighting purposes (since it takes longer to get):
                        --if bDebugMessages == true then LOG('Have wrecks with a valid position and positive mass value within the segment iCurXZ='..iCurX..'-'..iCurZ..'; iWreckNo='.._) end
                        --iCurMassValue = v.MaxMassReclaim / (iMedMassMod * iLargeMassMod)
                        --if iCurMassValue >= iMedMassThreshold then iCurMassValue = iCurMassValue * iMedMassMod end
                        --if iCurMassValue >= iLargeMassThreshold then iCurMassValue = iCurMassValue * iLargeMassMod end
                        --iTotalResourceValue = iTotalResourceValue + iCurMassValue
                        iTotalResourceValue = iTotalResourceValue + v[sResourceRef]
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
        if bAlsoReturnAmountOfHighestIndividualReclaim then return iTotalResourceValue, tReclaimPos, iLargestCurReclaim
        else return iTotalResourceValue, tReclaimPos end
    else
        if bAlsoReturnAmountOfHighestIndividualReclaim then return iTotalResourceValue, iLargestCurReclaim
        else return iTotalResourceValue end
    end
end

function GetNearestReclaimSegmentLocation(tLocation, iSearchRadius, iMinReclaimValue, aiBrain)
    --Returns the segment with the nearest reclaim that is more than iMinReclaimValue and within iSearchRadius of tLocation
    --returns nil if no valid locations
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetNearestReclaimSegmentLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if iMinReclaimValue == nil then iMinReclaimValue = 1 end
    if iSearchRadius == nil then iSearchRadius = 5 end
    local iSegmentSearchRange = math.ceil(iSearchRadius / iReclaimSegmentSizeX)
    local iBaseReclaimSegmentX, iBaseReclaimSegmentZ = GetReclaimSegmentsFromLocation(tLocation)

    local iClosestAbsSegmentDif = 1000
    local iCurAbsSegmentDif
    local tClosestReclaimSegmentXZ

    for iReclaimSegmentX = math.max(0, iBaseReclaimSegmentX - iSegmentSearchRange), iBaseReclaimSegmentX + iSegmentSearchRange do
        for iReclaimSegmentZ = math.max(0, iBaseReclaimSegmentZ - iSegmentSearchRange), iBaseReclaimSegmentZ + iSegmentSearchRange do
            if bDebugMessages == true then LOG(sFunctionRef..': Segment '..iReclaimSegmentX..'-'..iReclaimSegmentZ..'; tLocation='..repru(tLocation)..'; highest individual reclaim='..(tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimHighestIndividualReclaim] or 'nil')..'; Total mass='..(tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimTotalMass] or 'nil')..'; iMinReclaimValue='..iMinReclaimValue) end
            if math.min((tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimHighestIndividualReclaim] or 0), (tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimTotalMass] or 0)) >= iMinReclaimValue then
                iCurAbsSegmentDif = math.abs(iBaseReclaimSegmentX - iReclaimSegmentX) + math.abs(iBaseReclaimSegmentZ - iReclaimSegmentZ)
                if iCurAbsSegmentDif < iClosestAbsSegmentDif then
                    tClosestReclaimSegmentXZ = {iReclaimSegmentX, iReclaimSegmentZ}
                    iClosestAbsSegmentDif = iCurAbsSegmentDif
                    if iClosestAbsSegmentDif <= 1 then break end
                end
            end
        end
    end
    if tClosestReclaimSegmentXZ then
        local tPossibleLocation = GetReclaimLocationFromSegment(tClosestReclaimSegmentXZ[1], tClosestReclaimSegmentXZ[2])
        if bNoRushActive and M27Utilities.GetDistanceBetweenPositions(PlayerStartPoints[aiBrain.M27StartPositionNumber], tPossibleLocation) > iNoRushRange then
            if bDebugMessages == true then LOG(sFunctionRef..': Reclaimable object is outside norush range') end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return nil
        else
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return tPossibleLocation
        end
    else
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return nil
    end
end

function GetNearestReclaimObject(tLocation, iSearchRadius, iMinReclaimValue)
    --Returns the object/wreck of the nearest reclaim that is more than iMinReclaimValue and within iSearchRadius of tLocation
    --returns nil if no valid locations
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetNearestReclaimObject'
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
        if bNoRushActive and iMinDistToPosition > iNoRushRange then
            if bDebugMessages == true then LOG(sFunctionRef..': Reclaimable object is outside norush range') end
            return nil
        else
            if bDebugMessages == true then LOG(sFunctionRef..': returning reclaimable object') end
            return tReclaimables[iClosestWreck]
        end
    end
end

function GetReclaimInRectangle(iReturnType, rRectangleToSearch, bForceDebug)
    --iReturnType: 1 = true/false; 2 = number of wrecks; 3 = total mass, 4 = valid wrecks, 5 = energy
    local sFunctionRef = 'GetReclaimInRectangle'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = bForceDebug if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    --NOTE: Best to try and debug via forcedebug, as dont want to run for everything due to how intensive the log of reclaim is
    --Have also commented out one of the logs to help with performance

    local tReclaimables = GetReclaimablesInRect(rRectangleToSearch)
    local iCurMassValue = 0
    local iWreckCount = 0
    local iTotalResourceValue
    local bHaveReclaim = false
    local tValidWrecks = {}
    if M27Utilities.IsTableEmpty(tReclaimables) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': iReturnType='..iReturnType..'; rRectangleToSearch='..repru(rRectangleToSearch)) end
        if iReturnType == 3 or iReturnType == 5 then
            --GetReclaimablesResourceValue(tReclaimables, bAlsoReturnLargestReclaimPosition, iIgnoreReclaimIfNotMoreThanThis, bAlsoReturnAmountOfHighestIndividualReclaim, bEnergyNotMass)
            if iReturnType == 3 then iTotalResourceValue = GetReclaimablesResourceValue(tReclaimables, false, 0, false, false)
            else iTotalResourceValue = GetReclaimablesResourceValue(tReclaimables, false, 0, false, true)
            end
            if bDebugMessages == true then LOG(sFunctionRef..': iTotalResourceValue='..iTotalResourceValue) end
        else
            for _, v in tReclaimables do
                --if bDebugMessages == true then LOG(sFunctionRef..': _='.._..'; repr of reclaimable='..repru(tReclaimables)) end
                local WreckPos = v.CachePosition
                if not(WreckPos[1]==nil) then
                    if bDebugMessages == true then LOG(sFunctionRef..': _='.._..'; Cur mass value='..(v.MaxMassReclaim or 0)..'; Energy value='..(v.MaxEnergyReclaim or 0)) end
                    if (v.MaxMassReclaim or 0) > 0 or (v.MaxEnergyReclaim or 0) > 0 then
                        if bDebugMessages == true then LOG('Been destroyed='..tostring(v:BeenDestroyed())) end
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
    elseif bDebugMessages == true then LOG(sFunctionRef..': tReclaimables is empty')
    end
    if bDebugMessages == true then LOG(sFunctionRef..': rRectangleToSearch='..repru(rRectangleToSearch)..'; bHaveReclaim='..tostring(bHaveReclaim)..'; iWreckCount='..iWreckCount) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if iReturnType == 1 then return bHaveReclaim
        elseif iReturnType == 2 then return iWreckCount
        elseif iReturnType == 3 or iReturnType == 5 then return iTotalResourceValue
        elseif iReturnType == 4 then return tValidWrecks
        else M27Utilities.ErrorHandler('Invalid return type')
    end
end

function GetReclaimLocationFromSegment(iReclaimSegmentX, iReclaimSegmentZ)
    --e.g. segment (1,1) will be 0 to ReclaimSegmentSizeX and 0 to ReclaimSegmentSizeZ in size
    --This will return the midpoint
    local iX = math.max(rMapPlayableArea[1], math.min(rMapPlayableArea[3], (iReclaimSegmentX - 0.5) * iReclaimSegmentSizeX))
    local iZ = math.max(rMapPlayableArea[2], math.min(rMapPlayableArea[4], (iReclaimSegmentZ - 0.5) * iReclaimSegmentSizeZ))
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
        if (tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimTotalMass] or 0) >= 40 then

            local iStartPositionPathingGroup
            local tCurMidpoint, sLocationRef
            local bEngineerDiedOrSpottedEnemiesRecently, iCurDistToBase, iCurDistToEnemyBase
            local tACUPosition
            --local tNearbyEnemies

            iStartPositionPathingGroup = GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, PlayerStartPoints[aiBrain.M27StartPositionNumber])
            local oACU = M27Utilities.GetACU(aiBrain)
            if not(aiBrain.M27IsDefeated) then
                if oACU then
                    tACUPosition = oACU:GetPosition()
                else tACUPosition = PlayerStartPoints[aiBrain.M27StartPositionNumber] end
                if M27Logic.GetNearestEnemyStartNumber(aiBrain) then
                    local iCurAirSegmentX, iCurAirSegmentZ, bUnassigned
                    --Can an amphibious unit path here from our start
                    tCurMidpoint = GetReclaimLocationFromSegment(iReclaimSegmentX, iReclaimSegmentZ)
                    if bDebugMessages == true then LOG(sFunctionRef..': iReclaimSegmentX='..iReclaimSegmentX..'; iReclaimSegmentZ='..iReclaimSegmentZ..'; tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimTotalMass]='..tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimTotalMass]..'; tCurMidpoint='..repru(tCurMidpoint)..'; SegmentGroup='..(GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tCurMidpoint) or 'nil')..'; iStartPositionPathingGroup='..(iStartPositionPathingGroup or 'nil')) end
                    if iStartPositionPathingGroup == GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tCurMidpoint) then
                        --Has an engineer already been assigned to reclaim here?
                        sLocationRef = M27Utilities.ConvertLocationToReference(tCurMidpoint)
                        if not(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef]) or not(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea]) or M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea]) == true then
                            if bDebugMessages == true then LOG(sFunctionRef..': Dont have a valid assigned engineer to this location for reclaim; will now check not assigned to adjacent location unless high reclaim') end
                            bUnassigned = true
                            if (tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refReclaimTotalMass] or 0) >= 250 then
                                --do nothing as bUnassigned = true already
                            else
                                for iAdjX = - 1, 1 do
                                    for iAdjZ = - 1, 1 do
                                        sLocationRef = M27Utilities.ConvertLocationToReference(GetReclaimLocationFromSegment(iReclaimSegmentX + iAdjX, iReclaimSegmentZ + iAdjZ))
                                        if aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] and aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea]) == false then
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
                                    if bDebugMessages == true then LOG(sFunctionRef..': No enemies have died recently and no enemies have been spotted recently around target; tCurMidpoint='..repru(tCurMidpoint)..'; NearestEnemyStartNumber='..M27Logic.GetNearestEnemyStartNumber(aiBrain)) end

                                    --Check no nearby enemies - decided not to implement for CPU performance reasons
                                    --tNearbyEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, tCurMidpoint, 90, 'Enemy')
                                    --if M27Utilities.IsTableEmpty(tNearbyEnemies) == true then
                                        --if bDebugMessages == true then LOG(sFunctionRef..': No nearby enemies detected') end
                                        --Check no t2 arti in range
                                        --if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti, tCurMidpoint, 150, 'Enemy')) == true then


                                    iCurDistToBase = M27Utilities.GetDistanceBetweenPositions(tCurMidpoint, PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                    iCurDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tCurMidpoint, GetPrimaryEnemyBaseLocation(aiBrain))
                                    --if bDebugMessages == true then LOG(sFunctionRef..': No nearby T2 arti detected; iCurDistToBase='..iCurDistToBase..'; iCurDistToEnemyBase='..iCurDistToEnemyBase..'; aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy]='..aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy]..'; aiBrain[M27Overseer.refiPercentageOutstandingThreat]='..aiBrain[M27Overseer.refiPercentageOutstandingThreat]..'; iCurDistToBase / (iCurDistToBase + iCurDistToEnemyBase='..iCurDistToBase / (iCurDistToBase + iCurDistToEnemyBase)..'; M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tCurMidpoint, false)='..M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tCurMidpoint, false)..'; iDistanceFromStartToEnemy='..iDistanceFromStartToEnemy) end
                                    --Within defence and front unit coverage or just very close to base?
                                    if iCurDistToBase <= 100 or aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy] - 0.1 > iCurDistToBase / (iCurDistToBase + iCurDistToEnemyBase) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Are more than 10% closer to base than furthest front unit') end
                                        if iCurDistToBase <= 100 or aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] - 0.1 * aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] > M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tCurMidpoint, false) then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Are more than 10% closer to base than defence coverage') end
                                            --On our side of the map?
                                            if iCurDistToBase < iCurDistToEnemyBase then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Are on our side of map') end
                                                --Priority 1 - have current visual intel of location or intel coverage
                                                --iCurAirSegmentX, iCurAirSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(tCurMidpoint)
                                                if M27AirOverseer.GetTimeSinceLastScoutedLocation(aiBrain, tCurMidpoint) <= 1.1 then
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
                            if bDebugMessages == true then LOG(sFunctionRef..': Already have a valid assigned engineer to this location for reclaim, table size='..table.getn(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea])) end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Difference in pathing groups; Start position group='..(iStartPositionPathingGroup or 'nil')..'; Group of segment='..(GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tCurMidpoint) or 'nil')..'; tCurMidpoint='..repru(tCurMidpoint)) end
                    end
                else
                    if M27Logic.iTimeOfLastBrainAllDefeated < 10 then M27Utilities.ErrorHandler('Nearest enemy is nil but havent triggered event for all enemies being dead') end
                end
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
    if bDebugMessages == true then LOG(sFunctionRef..': Finished going through all segments.  1staiBrain[refiTotalReclaimAreasOfInterestByPriority]='..repru(tBrainsToUpdateFor[1][refiTotalReclaimAreasOfInterestByPriority])..'; All segments by priority='..repru(tBrainsToUpdateFor[1][reftReclaimAreasOfInterest])..'; sLocationRef recorded for this segment='..(tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][refsSegmentMidpointLocationRef] or 'nil')) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordThatWeWantToUpdateReclaimSegment(iReclaimSegmentX, iReclaimSegmentZ)
    if iReclaimSegmentX >= 0 and iReclaimSegmentZ >= 0 then table.insert(tReclaimSegmentsToUpdate, {iReclaimSegmentX, iReclaimSegmentZ}) end
end

function RecordThatWeWantToUpdateReclaimAtLocation(tLocation, iNearbySegmentsToUpdate)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --set to true for certain positions where want logs to print
    local sFunctionRef = 'RecordThatWeWantToUpdateReclaimAtLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if iReclaimSegmentSizeX == 0 then
        M27Utilities.ErrorHandler('Dont have a reclaim segment size specified, will set it to 8.5, but something else has likely gone wrong')
        iReclaimSegmentSizeX = 8.5
        iReclaimSegmentSizeZ = 8.5
    end
    local iReclaimSegmentX, iReclaimSegmentZ = GetReclaimSegmentsFromLocation(tLocation)
    if iReclaimSegmentX >= 10000 or iNearbySegmentsToUpdate >= 10000 or iReclaimSegmentZ >= 10000 then M27Utilities.ErrorHandler('Likely infinite loop about to start. iReclaimSegmentX='..(iReclaimSegmentX or 'nil')..'; iNearbySegmentsToUpdate='..(iNearbySegmentsToUpdate or 'nil')..'; iReclaimSegmentSizeX='..(iReclaimSegmentSizeX or 'nil')..'; iReclaimSegmentSizeZ='..(iReclaimSegmentSizeX or 'nil')..'; rMapPlayableArea='..repru(rMapPlayableArea or {'nil'})..'; iMaxSegmentInterval='..(iMaxSegmentInterval or 'nil'))
    else

        if iNearbySegmentsToUpdate then
            for iSegmentX = iReclaimSegmentX - iNearbySegmentsToUpdate, iReclaimSegmentX + iNearbySegmentsToUpdate do
                for iSegmentZ = iReclaimSegmentZ - iNearbySegmentsToUpdate, iReclaimSegmentZ + iNearbySegmentsToUpdate do
                    RecordThatWeWantToUpdateReclaimSegment(iSegmentX, iSegmentZ)
                end
            end
        else
            RecordThatWeWantToUpdateReclaimSegment(iReclaimSegmentX, iReclaimSegmentZ)
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DelayedReclaimRecordAtLocation(tPosition, iNearbySegmentsToUpdate, iWaitInSeconds)
    local sFunctionRef = 'DelayedReclaimRecordAtLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitSeconds(iWaitInSeconds)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if M27Utilities.bM27AIInGame then
        RecordThatWeWantToUpdateReclaimAtLocation(tPosition, iNearbySegmentsToUpdate)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ReclaimManager()
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --set to true for certain positions where want logs to print
    local sFunctionRef = 'ReclaimManager'

    local tAreasToUpdateThisCycle
    local iUpdateCount = 0
    local iMaxUpdatesPerTick
    local iWaitCount
    local iLoopCount
    if not(bReclaimManagerActive) then
        bReclaimManagerActive = true
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart) --Want the profile coutn to reflect the number of times actually running the core code

        while bReclaimManagerActive do
            if bDebugMessages == true then LOG(sFunctionRef..': Start of main active loop') end

            tAreasToUpdateThisCycle = {}
            iUpdateCount = 0
            iWaitCount = 0
            if M27Utilities.IsTableEmpty(tReclaimSegmentsToUpdate) then
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitTicks(10)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            else
                --Copy table into tAreasToUpdateThisCycle
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Will list out all entries in tReclaimSegmentsToUpdate if it isnt nil')
                    if tReclaimSegmentsToUpdate then LOG(repru(tReclaimSegmentsToUpdate)) end
                end
                for iEntry, tSubtable in tReclaimSegmentsToUpdate do
                    if (tSubtable[2] or 0) > 0 and (tSubtable[1] or 0) > 0 then --Dont bother updating places right on map edge in case pathfinding issue
                        if not(tAreasToUpdateThisCycle[tSubtable[1]]) then tAreasToUpdateThisCycle[tSubtable[1]] = {} end
                        if not(tAreasToUpdateThisCycle[tSubtable[1]][tSubtable[2]]) then
                            iUpdateCount = iUpdateCount + 1
                            tAreasToUpdateThisCycle[tSubtable[1]][tSubtable[2]] = true
                        end
                    end
                end
                --Clear the table for the next cycle
                tReclaimSegmentsToUpdate = {}
                if iUpdateCount == 0 then
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    WaitTicks(10)
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                else
                    iMaxUpdatesPerTick = math.max(5, math.min(20, math.ceil(iUpdateCount / 10)))
                    iLoopCount = 0
                    if bDebugMessages == true then LOG(sFunctionRef..': About to update for iUpdateCount='..iUpdateCount..' entries; max updates per tick='..iMaxUpdatesPerTick..'; tAreasToUpdateThisCycle='..repru(tAreasToUpdateThisCycle)) end
                    for iSegmentX, tSubtable1 in tAreasToUpdateThisCycle do
                        for iSegmentZ, tSubtable2 in tAreasToUpdateThisCycle[iSegmentX] do
                            iLoopCount = iLoopCount + 1
                            if iLoopCount > iMaxUpdatesPerTick then
                                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                                WaitTicks(1)
                                iWaitCount = iWaitCount + 1
                                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                                iLoopCount = 1
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': About to update reclaim data for segments '..iSegmentX..'-'..iSegmentZ) end
                            UpdateReclaimDataNearSegments(iSegmentX, iSegmentZ, 0, nil)
                        end
                    end
                    if iWaitCount < 10 then
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                        WaitTicks(10 - iWaitCount)
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                    end
                end
            end
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
end


function UpdateReclaimDataNearSegments(iBaseSegmentX, iBaseSegmentZ, iSegmentRange, tBrainsToAlwaysUpdateFor)
    --Updates reclaim data for all segments within iSegmentRange of tLocation, and updates reclaim prioritisation for all brians specified in tBrainsToAlwaysUpdateFor

    --tBrainsToAlwaysUpdateFor - specify any brains to update even if reclaim hasnt changed; set to nil if only want to update M27 brains when reclaim has changed from before
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --set to true for certain positions where want logs to print
    local sFunctionRef = 'UpdateReclaimDataNearSegments'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart) --Want the profile coutn to reflect the number of times actually running the core code
    --M27Utilities.tiProfilerStartCountByFunction[sFunctionRef] = (M27Utilities.tiProfilerStartCountByFunction[sFunctionRef] or 0) + 1 LOG(sFunctionRef..': M27Utilities.tiProfilerStartCountByFunction[sFunctionRef]='..M27Utilities.tiProfilerStartCountByFunction[sFunctionRef])


    --if math.floor(GetGameTimeSeconds()*10) - 1 >= 3780 and math.floor(GetGameTimeSeconds()*10) - 1 <= 3781 then bDebugMessages = true end

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code; Systemtimeforprofileuse='..GetSystemTimeSecondsOnlyForProfileUse()) end
    local iMinValueOfIndividualReclaim = 2.5
    local iMinEnergyValue = 15

    --local iBaseSegmentX = tLocation[1] / iReclaimSegmentSizeX
    --local iBaseSegmentZ = tLocation[3] / iReclaimSegmentSizeZ

    --if not(tBrainsToAlwaysUpdateFor) then tBrainsToAlwaysUpdateFor = M27Overseer.tAllActiveM27Brains end
    local iTotalMassValue, tReclaimables, iLargestCurReclaim, tReclaimPos, iTotalEnergyValue
    local iCumulativeMassValue = 0

    if bDebugMessages == true then
        LOG(sFunctionRef..': About to update for iBaseSegmentX='..(iBaseSegmentX or 'nil')..'; iSegmentRange='..(iSegmentRange or 'nil')..'; iBaseSegmentZ='..(iBaseSegmentZ or 'nil'))
        if M27Utilities.IsTableEmpty(tBrainsToAlwaysUpdateFor) then LOG('tBrainsToAlwaysUpdateFor is empty')
        else LOG('tBrainsToAlwaysUpdateFor size='..table.getn(tBrainsToAlwaysUpdateFor)) end
        if M27Utilities.IsTableEmpty(M27Overseer.tAllActiveM27Brains) then LOG('tAllActiveM27Brains is empty')
        else LOG('size of tAllActiveM27Brains='..table.getn(M27Overseer.tAllActiveM27Brains))
        end
    end

    for iCurX = iBaseSegmentX - iSegmentRange, iBaseSegmentX + iSegmentRange do
        for iCurZ = iBaseSegmentZ - iSegmentRange, iBaseSegmentZ + iSegmentRange do
            iTotalMassValue = 0
            tReclaimables = GetReclaimablesInRect(Rect((iCurX - 1) * iReclaimSegmentSizeX, (iCurZ - 1) * iReclaimSegmentSizeZ, iCurX * iReclaimSegmentSizeX, iCurZ * iReclaimSegmentSizeZ))
            iLargestCurReclaim = 0

            if tReclaimables and table.getn( tReclaimables ) > 0 then
                -- local iWreckCount = 0
                --local bIsProp = nil  --only used for log/testing
                if bDebugMessages == true then LOG('Have wrecks within the segment iCurXZ='..iCurX..'-'..iCurZ) end
                iTotalMassValue, tReclaimPos, iLargestCurReclaim, iTotalEnergyValue = GetReclaimablesMassAndEnergy(tReclaimables, iMinValueOfIndividualReclaim, iMinEnergyValue)
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
                tReclaimAreas[iCurX][iCurZ][refReclaimTotalEnergy] = iTotalEnergyValue

                --Determine reclaim areas of interest
                if not(tReclaimAreas[iCurX][iCurZ][refiReclaimTotalPrev] == iTotalMassValue) then

                    UpdateReclaimSegmentAreaOfInterest(iCurX, iCurZ, M27Overseer.tAllActiveM27Brains)
                elseif tBrainsToAlwaysUpdateFor then
                    --Update for any brains where there has been a significant change
                    UpdateReclaimSegmentAreaOfInterest(iCurX, iCurZ, tBrainsToAlwaysUpdateFor)
                end
            end
            iCumulativeMassValue = iCumulativeMassValue + iTotalMassValue
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, iCumulativeMassValue='..iCumulativeMassValue..'; SystemTime='..GetSystemTimeSecondsOnlyForProfileUse()) end

    --M27Utilities.tiProfilerEndCountByFunction[sFunctionRef] = (M27Utilities.tiProfilerStartCountByFunction[sFunctionRef] or 0) + 1 LOG(sFunctionRef..': M27Utilities.tiProfilerEndCountByFunction[sFunctionRef]='..M27Utilities.tiProfilerEndCountByFunction[sFunctionRef])
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iCumulativeMassValue
end

function DelayedReclaimUpdateAtLocation(tLocation, iDelay)
    --Call via forkthread
    local sFunctionRef = 'DelayedReclaimUpdateAtLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicks(iDelay)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    --LOG('Temp log for debugging, DelayedReclaimUpdateAtLocation: tLocation='..repru((tLocation or {'nil'})))
    return UpdateReclaimDataNearLocation(tLocation, 0, nil)
end

function UpdateReclaimDataNearLocation(tLocation, iSegmentRange, tBrainsToAlwaysUpdateFor)
    --Updates reclaim data for all segments within iSegmentRange of tLocation, and updates reclaim prioritisation for all brians specified in tBrainsToAlwaysUpdateFor
    local iBaseSegmentX, iBaseSegmentZ = GetReclaimSegmentsFromLocation(tLocation)
    --LOG('Temp log for debugging, tLocation='..repru(tLocation)..'; iBaseSegmentX='..iBaseSegmentX..'; iBaseSegmentZ='..iBaseSegmentZ)
    return UpdateReclaimDataNearSegments(iBaseSegmentX, iBaseSegmentZ, iSegmentRange, tBrainsToAlwaysUpdateFor)
end

function DetermineReclaimSegmentSize()
    local iMinReclaimSegmentSize = 8.5 --Engineer build range is 6; means that a square of about 4.2 will fit inside this circle; If have 2 separate engineers assigned to adjacent reclaim segments, and want their build range to cover the two areas, then would want a gap twice this, so 8.4; will therefore go with min size of 8
    local iMapSizeX = rMapPlayableArea[3] - rMapPlayableArea[1]
    local iMapSizeZ = rMapPlayableArea[4] - rMapPlayableArea[2]
    iReclaimSegmentSizeX = math.max(iMinReclaimSegmentSize, iMapSizeX / iMaxSegmentInterval)
    iReclaimSegmentSizeZ = math.max(iMinReclaimSegmentSize, iMapSizeZ / iMaxSegmentInterval)
end

function UpdateReclaimMarkers()
    --v29 - trying new method, have copied original and set to old in case want to revert


    --Divides map into segments, determines reclaim in each segment and stores this in tReclaimAreas along with the location of the highest reclaim in this segment
    --if oEngineer isn't nil then it will also determine if the segment is pathable
    --Updates the global variable tReclaimAreas{}
    --Config settings:
    --Note: iMaxSegmentInterval defined at the top as a global variable
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --set to true for certain positions where want logs to print
    local sFunctionRef = 'UpdateReclaimMarkers'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code; bReclaimRefreshActive='..tostring(bReclaimRefreshActive)..'; iLastReclaimRefresh='..(iLastReclaimRefresh or 'nil')..'; GetGameTimeSeconds='..GetGameTimeSeconds()) end
    local iTimeBeforeFullRefresh = 100 --Will do a full refresh of reclaim every x seconds

    --Record all segments' mass information:
    if bReclaimRefreshActive == false and ((iLastReclaimRefresh or 0) == 0 or GetGameTimeSeconds() - iLastReclaimRefresh >= iTimeBeforeFullRefresh) then
        if bDebugMessages == true then LOG(sFunctionRef..': Setting bReclaimRefreshActive to true') end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart) --Want the profile coutn to reflect the number of times actually running the core code
        bReclaimRefreshActive = true
        --local iMinValueOfIndividualReclaim = 2.5
        local tReclaimPos = {}
        --local iLargestCurReclaim
        local rPlayableArea = rMapPlayableArea
        local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
        local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]
        --Make sure we have an up to date list of active aiBrains
        --[[local bCheckBrains = true
        local iCurCount = 0
        local iMaxCount = 100--]]

        local tM27Brains = {}
        local tBrainsWithChangedThreat = {}
        local bHaveBrainsWithChangedThreat = false
        if bDebugMessages == true then LOG(sFunctionRef..': Running a refresh of all reclaim segments on the map') end
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
        if M27Utilities.IsTableEmpty(tM27Brains) then tM27Brains = nil end
        local iACUDeathCountWhenStarted = M27Overseer.iACUAlternativeFailureCount
        if bDebugMessages == true then LOG(sFunctionRef..': Pre start of main loop; iACUDeathCountWhenStarted='..iACUDeathCountWhenStarted) end



        if iReclaimSegmentSizeX == 0 then --Not yet determined reclaim sizes
            DetermineReclaimSegmentSize()
            if bDebugMessages == true then LOG(sFunctionRef..': Have updated iReclaimSegmentSizeX and iReclaimSegmentSizeZ to '..iReclaimSegmentSizeX..'-'..iReclaimSegmentSizeZ) end
        end

        local iReclaimMaxSegmentX = math.ceil(iMapSizeX / iReclaimSegmentSizeX)
        local iReclaimMaxSegmentZ = math.ceil(iMapSizeZ / iReclaimSegmentSizeZ)
        local iCurCount = 0
        local iWaitInterval = math.max(1, math.floor((iReclaimMaxSegmentX * iReclaimMaxSegmentZ) / (iTimeBeforeFullRefresh * 10)))


        --local tReclaimables = {}

        if bDebugMessages == true then LOG('ReclaimRefresh: About to do full refresh') end
        iLastReclaimRefresh = GetGameTimeSeconds()
        tReclaimPos = {}
        iMapTotalMass = 0
        iPreviousHighestReclaimInASegment = iHighestReclaimInASegment
        iHighestReclaimInASegment = 0
        for iCurX = 1, iReclaimMaxSegmentX do
            for iCurZ = 1, iReclaimMaxSegmentZ do
                iMapTotalMass = iMapTotalMass + UpdateReclaimDataNearSegments(iCurX, iCurZ, 0, tM27Brains)
                --for iCurX = 1, math.floor(iMapSizeX / iSegmentSizeX) do
                --for iCurZ = 1, math.floor(iMapSizeZ / iSegmentSizeZ) do
                if bDebugMessages == true then LOG('iCurX='..iCurX..'; iCurZ='..iCurZ..'; iMapTotalMass='..iMapTotalMass..'; Location of segment='..repru(GetReclaimLocationFromSegment(iCurX, iCurZ))) end
                iCurCount = iCurCount + 1
            end

            if iCurCount >= iWaitInterval or iReclaimAreaOfInterestTickCount > 30 then
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
                repru(aiBrain[reftReclaimAreasOfInterest])
                break
            end
        end
        bReclaimRefreshActive = false
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
end

function UpdateReclaimMarkersOld()
    --v29 - set to old as want to see if new approach is quicker


    --Divides map into segments, determines reclaim in each segment and stores this in tReclaimAreas along with the location of the highest reclaim in this segment
    --if oEngineer isn't nil then it will also determine if the segment is pathable
    --Updates the global variable tReclaimAreas{}
    --Config settings:
    --Note: iMaxSegmentInterval defined at the top as a global variable
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --set to true for certain positions where want logs to print
    local sFunctionRef = 'UpdateReclaimMarkersOld'
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
                    iTotalMassValue, tReclaimPos, iLargestCurReclaim = GetReclaimablesResourceValue(tReclaimables, true, iMinValueOfIndividualReclaim, true)

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
                        local iLoopCount = 0
                        while bNeedToUpdateChangedBrains == true do
                            bNeedToUpdateChangedBrains = false
                            iLoopCount = iLoopCount + 1
                            if iLoopCount >= 20 then M27Utilities.ErrorHandler('Infinite loop') break end
                            if M27Utilities.IsTableEmpty(tBrainsWithChangedThreat) == false then
                                for iArmyIndex, oBrain in tBrainsWithChangedThreat do
                                    if oBrain:IsDefeated() or oBrain.M27IsDefeated then
                                        bNeedToUpdateChangedBrains = true
                                        tBrainsWithChangedThreat[iArmyIndex] = nil
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': Finished removing brains who have lost their ACU from the list of brains to consider reclaim updates on') end
                end
                iMapTotalMass = iMapTotalMass + iTotalMassValue
                if bDebugMessages == true then LOG('iCurX='..iCurX..'; iCurZ='..iCurZ..'; iMapTotalMass='..iMapTotalMass..'; iTotalMassValue='..iTotalMassValue..'; Location of segment='..repru(GetReclaimLocationFromSegment(iCurX, iCurZ))) end
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
                repru(aiBrain[reftReclaimAreasOfInterest])
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
                    if (tReclaimAreas[iCurX][iCurZ][refReclaimTotalMass] or 0) >= iMinSegmentReclaim then
                        if bDebugMessages == true then LOG(sFunctionRef..': iCurX='..iCurX..'; iCurZ='..iCurZ..'; tReclaimAreas[iCurX][iCurZ][refReclaimTotalMass]='..tReclaimAreas[iCurX][iCurZ][refReclaimTotalMass]..'; iMinSegmentReclaim='..iMinSegmentReclaim) end
                        --Can an amphibious unit path here
                        tCurMidpoint = GetReclaimLocationFromSegment(iCurX, iCurZ)
                        if bDebugMessages == true then LOG(sFunctionRef..': tCurMidpoint='..repru(tCurMidpoint)..'; SegmentGroup='..(GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tCurMidpoint) or 'nil')..'; iStartPositionPathingGroup='..(iStartPositionPathingGroup or 'nil')) end
                        if iStartPositionPathingGroup == GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tCurMidpoint) then
                            --Factor in norush:
                            if not(bNoRushActive) or M27Utilities.GetDistanceBetweenPositions(tCurMidpoint, aiBrain[reftNoRushCentre]) <= iNoRushRange then
                                --Has an engineer already been assigned to reclaim here?
                                sLocationRef = M27Utilities.ConvertLocationToReference(tCurMidpoint)
                                if not(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef]) or not(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea]) or M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea]) == true then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Dont have a valid assigned engineer to this location for reclaim; will now check not assigned to adjacent location unless high reclaim') end
                                    bUnassigned = true
                                    if (tReclaimAreas[iCurX][iCurZ][refReclaimTotalMass] or 0) >= 250 then
                                        --do nothing as bUnassigned = true already
                                    else
                                        for iAdjX = iCurX - 1, iCurX + 1, 1 do
                                            for iAdjZ = iCurZ - 1, iCurZ + 1, 1 do
                                                sLocationRef = M27Utilities.ConvertLocationToReference(GetReclaimLocationFromSegment(iCurX + iAdjX, iCurZ + iAdjZ))
                                                if aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] and aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea]) == false then
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
                                                    iCurDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tCurMidpoint, GetPrimaryEnemyBaseLocation(aiBrain))
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
                                                                --iCurAirSegmentX, iCurAirSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(tCurMidpoint)
                                                                if M27AirOverseer.GetTimeSinceLastScoutedLocation(aiBrain, tCurMidpoint) <= 1.1 then
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
                                    if bDebugMessages == true then LOG(sFunctionRef..': Already have a valid assigned engineer to this location for reclaim, table size='..table.getn(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea])) end
                                end
                            elseif bDebugMessages == true then LOG(sFunctionRef..': No rush is active and the location is outside norush range')
                            end
                        end
                    end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Finished going through all segments.  aiBrain[refiTotalReclaimAreasOfInterestByPriority]='..repru(aiBrain[refiTotalReclaimAreasOfInterestByPriority])) end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Have recently refreshed reclaim points of interest so will use those values') end
        end
    end


end

--GetUnclaimedMexes - contained within EngineerOverseer

function GetHydroLocationsForPathingGroup(sPathing, iPathingGroup)
    --Return table of hydro locations for iPathingGroup
    --Return {} if no such table
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetHydroLocationsForPathingGroup'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end

    local tHydroForPathingGroup = {}
    local bNeedToRecord = false
    if bDebugMessages == true then LOG(sFunctionRef..': Checking for hydros in pathing group; HydroCount='..HydroCount) end
    if HydroCount > 0 then
        if tHydroByPathingAndGrouping[sPathing] == nil then
            tHydroByPathingAndGrouping[sPathing] = {}
            bNeedToRecord = true
        end
        if tHydroByPathingAndGrouping[sPathing][iPathingGroup] == nil then
            tHydroByPathingAndGrouping[sPathing][iPathingGroup] = {}
            bNeedToRecord = true
        end
        if bDebugMessages == true then LOG(sFunctionRef..': bNeedToRecord='..tostring(bNeedToRecord)..'; iPathingGroup='..iPathingGroup) end
        if bNeedToRecord == true then
            local iValidHydroCount = 0
            local iCurSegmentX, iCurSegmentZ, iCurSegmentGroup
            for iHydro, tHydro in HydroPoints do
                iCurSegmentX, iCurSegmentZ = GetPathingSegmentFromPosition(tHydro)
                iCurSegmentGroup = GetSegmentGroupOfTarget(sPathing, iCurSegmentX, iCurSegmentZ)
                if iCurSegmentGroup == iPathingGroup then
                    iValidHydroCount = iValidHydroCount + 1
                    tHydroByPathingAndGrouping[sPathing][iPathingGroup][iValidHydroCount] = tHydro
                end
            end
        end
        tHydroForPathingGroup = tHydroByPathingAndGrouping[sPathing][iPathingGroup]
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
    if bDebugMessages == true then LOG(sFunctionRef..': About to record mexes for each pathing group. MassPoints='..repru(MassPoints)) end
    local tsPathingTypes = {M27UnitInfo.refPathingTypeAmphibious, M27UnitInfo.refPathingTypeNavy, M27UnitInfo.refPathingTypeLand}
    local iCurResourceGroup
    local iValidCount = 0
    tMexByPathingAndGrouping = {}
    for iPathingType, sPathing in tsPathingTypes do
        tMexByPathingAndGrouping[sPathing] = {}
        iValidCount = 0

        if bDebugMessages == true then
            LOG(sFunctionRef..': sPathing='..sPathing..'; Is table of pathing segment group empty='..tostring(M27Utilities.IsTableEmpty(tPathingSegmentGroupBySegment[sPathing])))
        end

        for iCurMex, tMexLocation in MassPoints do
            iValidCount = iValidCount + 1
            iCurResourceGroup = GetSegmentGroupOfLocation(sPathing, tMexLocation)
            if not(iCurResourceGroup) then M27Utilities.ErrorHandler('Dont have a resource group for mex location '..repru(tMexLocation)..'; This is expected if mexes are located outside the playable area', true)
            else
                if bDebugMessages == true then
                    LOG(sFunctionRef..': iCurMex='..iCurMex..'; About to get segment group for pathing='..sPathing..'; location='..repru((tMexLocation or {'nil'}))..'; iCurResourceGroup='..(iCurResourceGroup or 'nil'))
                    local iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(tMexLocation)
                    LOG(sFunctionRef..': Pathing segments='..(iSegmentX or 'nil')..'; iSegmentZ='..(iSegmentZ or 'nil')..'; rMapPlayableArea='..repru(rMapPlayableArea)..'; iSizeOfBaseLevelSegment='..(iSizeOfBaseLevelSegment or 'nil'))
                end
                if tMexByPathingAndGrouping[sPathing][iCurResourceGroup] == nil then
                    tMexByPathingAndGrouping[sPathing][iCurResourceGroup] = {}
                    iValidCount = 1
                else iValidCount = table.getn(tMexByPathingAndGrouping[sPathing][iCurResourceGroup]) + 1
                end
                tMexByPathingAndGrouping[sPathing][iCurResourceGroup][iValidCount] = tMexLocation
                if bDebugMessages == true then LOG(sFunctionRef..': iValidCount='..iValidCount..'; sPathing='..sPathing..'; iCurResourceGroup='..iCurResourceGroup..'; just added tMexLocation='..repru(tMexLocation)..' to this group') end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..'; tMexByPathingAndGrouping='..repru(tMexByPathingAndGrouping)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordMexForPathingGroupOld(oPathingUnit, bForceRefresh)
    --Updates tMexByPathingAndGrouping to record the mex that are in the same pathing group as oPathingUnit
    --bForceRefresh - issue where not all mexes register as being pathable at start of game, so overseer will call this again after a short delay
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'RecordMexForPathingGroupOld'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if oPathingUnit and not(oPathingUnit.Dead) then
        local sPathing = M27UnitInfo.GetUnitPathingType(oPathingUnit)
        if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
        local tUnitPosition = oPathingUnit:GetPosition()
        local iUnitSegmentX, iUnitSegmentZ = GetPathingSegmentFromPosition(tUnitPosition)
        --GetSegmentGroupOfTarget(sPathing, iSegmentX, iSegmentZ)
        local iUnitSegmentGroup = GetSegmentGroupOfTarget(sPathing, iUnitSegmentX, iUnitSegmentZ)
        if bDebugMessages == true then LOG(sFunctionRef..': , sPathing='..sPathing..'; iUnitSegmentGroup='..iUnitSegmentGroup) end
        if tMexByPathingAndGrouping[sPathing] == nil then tMexByPathingAndGrouping[sPathing] = {} end
        if tMexByPathingAndGrouping[sPathing][iUnitSegmentGroup] == nil or bForceRefresh == true then
            --Need to record mass locations for this:
            if tMexByPathingAndGrouping[sPathing][iUnitSegmentGroup] == nil then tMexByPathingAndGrouping[sPathing][iUnitSegmentGroup] = {} end
            local iCurSegmentX, iCurSegmentZ
            local iMexSegmentGroup
            local iValidCount = 0
            local iOriginalCount = 0
            if bForceRefresh == true then
                iValidCount = table.getn(tMexByPathingAndGrouping[sPathing][iUnitSegmentGroup])
                iOriginalCount = iValidCount
            end
            local bIncludeMex = false
            if bDebugMessages == true then LOG(sFunctionRef..': ScenarioInfo='..repru(ScenarioInfo)..'; MassPoints='..repru(MassPoints)) end
            for iCurMex, tMexLocation in MassPoints do
                if bDebugMessages == true then LOG(sFunctionRef..': About to consider tMexLocation='..repru(tMexLocation)) end
                iCurSegmentX, iCurSegmentZ = GetPathingSegmentFromPosition(tMexLocation)
                --if bDebugMessages == true then TEMPMAPTEST(sFunctionRef..': About to get segment group') end
                iMexSegmentGroup = GetSegmentGroupOfTarget(sPathing, iCurSegmentX, iCurSegmentZ)
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Considering mex location '..repru(tMexLocation))
                end
                if not(iMexSegmentGroup==nil) then
                    if bDebugMessages == true then LOG(sFunctionRef..': iMexSegmentGroup='..iMexSegmentGroup..'; iCurMex='..iCurMex) end
                    if iMexSegmentGroup == iUnitSegmentGroup then
                        --Mex is in the same pathing group, so record it (unless are forcing a refresh and have already recorded it)
                        bIncludeMex = true
                        if bForceRefresh then
                            for iExistingMex, tExistingMex in tMexByPathingAndGrouping[sPathing][iUnitSegmentGroup] do
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
                            tMexByPathingAndGrouping[sPathing][iUnitSegmentGroup][iValidCount] = {}
                            tMexByPathingAndGrouping[sPathing][iUnitSegmentGroup][iValidCount] = tMexLocation
                            if bDebugMessages == true then LOG(sFunctionRef..': Pathing='..sPathing..': Segment '..iCurSegmentX..'-'..iCurSegmentZ..' is in a pathing group, so adding it to recorded mexes; iMexSegmentGroup='..iMexSegmentGroup..';, iValidCount='..iValidCount) end
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
            LOG(sFunctionRef..': table.getn of mexbypathing for sPathing='..sPathing..'; iUnitSegmentGroup='..iUnitSegmentGroup..'; table.getn='..table.getn(tMexByPathingAndGrouping[sPathing][iUnitSegmentGroup]))
            if iUnitSegmentGroup == 1 then
                M27Utilities.DrawLocations(tMexByPathingAndGrouping[sPathing][iUnitSegmentGroup], nil, 2)
                LOG('List of all mex locations for iSegmentGroup='..iUnitSegmentGroup..' for '..sPathing..'='..repru(tMexByPathingAndGrouping[sPathing][iUnitSegmentGroup]))
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
        if bDebugMessages == true then LOG(sFunctionRef..': PlayerStartPoints='..repru(PlayerStartPoints)..'; aiBrain army index='..aiBrain:GetArmyIndex()) end
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

function GetNearestMexToUnit(oBuilder, bCanBeBuiltOnByAlly, bCanBeBuiltOnByEnemy, bCanBeQueuedToBeBuilt, iMaxSearchRangeMod, tStartPositionOverride, tMexesToIgnore, bCanBePartBuilt)
    --Gets the nearest mex to oBuilder based on oBuilder's build range+iMaxSearchRangeMod. Returns nil if no such mex.  Optional variables:
    --bCanBeBuiltOnByAlly - false if dont want it to have been built on by us
    --bCanBeBuiltOnByEnemy - false if dont want it to have been built on by enemy
    --iMaxSearchRangeMod - defaults to 0
    --tStartPositionOverride - use this instead of the builder start position if its specified
    --tMexesToIgnore - a table of locations to ignore if they're the nearest mex
    --bCanBePartBuilt - true if location is part built by us, or by an ally if have set it can be be built on by ally

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
    if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
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
        if bDebugMessages == true then LOG(sFunctionRef..': List of mexes in pathing group='..repru(tMexByPathingAndGrouping[sPathing][iUnitPathGroup])) end
        for iCurMex, tMexLocation in tMexByPathingAndGrouping[sPathing][iUnitPathGroup] do
            bValidMex = false
            iCurDistanceFromUnit = M27Utilities.GetDistanceBetweenPositions(tMexLocation, tLocationToSearchFrom)
            if bDebugMessages == true then LOG(sFunctionRef..': Considering iCurMex='..iCurMex..'; tMexLocation='..repru(tMexLocation)..'; iCurDistanceFromUnit='..iCurDistanceFromUnit..'; iMaxDistanceFromUnit='..iMaxDistanceFromUnit..'; iMinDistanceFromUnit='..iMinDistanceFromUnit) end
            if iCurDistanceFromUnit <= iMaxDistanceFromUnit then
                if iCurDistanceFromUnit < iMinDistanceFromUnit then
                    --Is it valid (i.e. no-one has built on it)?
                    --M27Conditions.IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed)
                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if iCurMex is unclaimed, iCurMex='..iCurMex..'; MexLocation='..repru(tMexByPathingAndGrouping[sPathing][iUnitPathGroup][iCurMex])) end
                    --IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
                    if M27Conditions.IsMexUnclaimed(aiBrain, tMexLocation, bCanBeBuiltOnByEnemy, bCanBeBuiltOnByAlly, bCanBeQueuedToBeBuilt, bCanBePartBuilt) == true then
                        bValidMex = true
                        if bDebugMessages == true then LOG(sFunctionRef..': Have a valid mex, seeing if its in the list of mexes to ignore.  tMexPosition='..repru(tMexLocation)..'; tMexesToIgnore='..repru(tMexesToIgnore)) end
                        if bCheckListOfMexesToIgnore == true then
                            for iAltMex, tAltMex in tMexesToIgnore do
                                if bDebugMessages == true then LOG(sFunctionRef..': tMexLocation='..repru(tMexLocation)..'; tAltMex='..repru(tAltMex)) end
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

function IsUnderwater(tPosition, bReturnSurfaceHeightInstead, iOptionalAmountToBeUnderwater)
    --Returns true if tPosition underwater, otherwise returns false
    --bReturnSurfaceHeightInstead:: Return the actual height at which underwater, instead of true/false
    if bReturnSurfaceHeightInstead then return iMapWaterHeight
    else
        if M27Utilities.IsTableEmpty(tPosition) == true then
            M27Utilities.ErrorHandler('tPosition is empty')
        else
            if iMapWaterHeight > tPosition[2] + (iOptionalAmountToBeUnderwater or 0) then
                --Check we're not just under an arch but are actually underwater
                if not(GetTerrainHeight(tPosition[1], tPosition[3]) == iMapWaterHeight) then
                    return true
                end
            end
        end
        return false
    end
end

function IsWaterOrFlatAlongLine(tStart, tEnd)
    --Intended e.g. for battleships to decide if their shot is likely to be blocked, so they wont ground fire, as a more performant version of isshotblocked
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsWaterOrFlatAlongLine'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iWaterHeight = iMapWaterHeight + 0.01 --ensure rounding doesnt cause issues (not actually tested to see if it would have caused issues, more just a precaution)
    if GetTerrainHeight(tStart[1], tStart[3]) <= iWaterHeight and GetTerrainHeight(tEnd[1], tEnd[3]) <= iWaterHeight then
        local iTotalDistance = math.floor(M27Utilities.GetDistanceBetweenPositions(tStart, tEnd))
        if iTotalDistance < 1 then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return true
        else
            local iXAdjust = (tEnd[1] - tStart[1]) / iTotalDistance
            local iZAdjust = (tEnd[3] - tStart[3]) / iTotalDistance
            local iInterval = 1
            if iTotalDistance >= 100 then
                iInterval = 3
                iTotalDistance = math.floor(iTotalDistance / iInterval) * iInterval
            elseif iTotalDistance >= 50 then
                iInterval = 2
                iTotalDistance = math.floor(iTotalDistance / iInterval) * iInterval
            end
            if bDebugMessages == true then LOG(sFunctionRef..': tStart='..repru(tStart)..'; tEnd='..repru(tEnd)..'; Total distance rounded down='..iTotalDistance..'; iXAdjust='..iXAdjust..'; iZAdjust='..iZAdjust..'; iInterval='..iInterval) end
            local iCurX, iCurZ
            for iEntry = iInterval, iTotalDistance, iInterval do
                iCurX = tStart[1] + iXAdjust * iEntry
                iCurZ = tStart[3] + iZAdjust * iEntry
                if bDebugMessages == true then
                    LOG(sFunctionRef..': iInterval='..iInterval..'; Considering position X-Z='..iCurX..'-'..iCurZ..'; iWaterHeight='..iWaterHeight..'; Terrain height='..GetTerrainHeight(iCurX, iCurZ))
                    M27Utilities.DrawLocation({ iCurX, GetTerrainHeight(iCurX, iCurZ), iCurZ })
                end
                if GetTerrainHeight(iCurX, iCurZ) > iWaterHeight then
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    return false
                end
            end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return true
        end

    else
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return false
    end

end

function GetNearestPathableLandPosition(oPathingUnit, tTravelTarget, iMaxSearchRange)
    --Looks for a position with >0 surface height within iMaxSearchRange of oPathingUnit
    --first looks in a straight line along tTravelTarget, and only if no match does it consider looking left, right and behind
    --Returns nil if cant find target
    local sFunctionRef = 'GetNearestPathableLandPosition'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
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
        if bDebugMessages == true then LOG(sFunctionRef..': tStartPosition='..repru(tStartPosition)..'; tTravelTarget='..repru(tTravelTarget)..'; iMaxSearchRange='..iMaxSearchRange..'; iHigherThanMaxDistanceCycle='..iHigherThanMaxDistanceCycle) end
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
                tCurPosition[2] = GetTerrainHeight(tCurPosition[1], tCurPosition[3])
                if M27Utilities.IsTableEmpty(tCurPosition) == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': Trying to find position that isnt underwater. iDistanceCycle='..iDistanceCycle..'; iDistanceMod='..iDistanceMod..'; iAngleToPath='..iAngleToPath..'; tCurPosition='..repru(tCurPosition)..'; Terrain height='..GetTerrainHeight(tCurPosition[1], tCurPosition[3])..'; GetSurfaceHeight='..GetSurfaceHeight(tCurPosition[1], tCurPosition[3])..'; IsUnderwater(tCurPosition)='..tostring(IsUnderwater(tCurPosition))..'; iMapWaterHeight='..iMapWaterHeight) end
                    if IsUnderwater(tCurPosition) == false then
                        bFoundTarget = true
                        tValidTarget = tCurPosition
                        if bDebugMessages == true then LOG(sFunctionRef..': Found target so will stop searching') end
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
        if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
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
                M27Utilities.ErrorHandler('Possible infinite loop - unable to find empty pathable area despite searching more than '..iMaxCycles..' times')
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
                    tNearbyStructures = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, tTargetLocation, iAreaRadius, 'Enemy')
                    if M27Utilities.IsTableEmpty(tNearbyStructures) == true then
                        if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, tTargetLocation, iAreaRadius, 'Ally')) == true then
                            if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, tTargetLocation, iAreaRadius, 'Neutral')) == true then
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
        local tEnemyStartPosition = GetPrimaryEnemyBaseLocation(aiBrain)
        if M27Utilities.IsTableEmpty(tMexByPathingAndGrouping[sPathing][iPathingGroup]) == false then
            for iMex, tMexLocation in tMexByPathingAndGrouping[sPathing][iPathingGroup] do
                iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tEnemyStartPosition, tMexLocation)
                if iCurDistanceToEnemy >= iMinDistanceFromEnemy and iCurDistanceToEnemy <= iMaxDistanceFromEnemy then
                    iValidMexCount = iValidMexCount + 1
                    aiBrain[reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup][iMinDistanceFromEnemy][iMaxDistanceFromEnemy][iValidMexCount] = tMexLocation
                end
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
    if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
    local iPathingGroup = aiBrain[refiStartingSegmentGroup][sPathing]
    local iCurDistanceToOurStart, iCurDistanceToEnemy, iCurModDistanceValue
    local tOurStartPos = PlayerStartPoints[aiBrain.M27StartPositionNumber]
    local tEnemyStartPosition = GetPrimaryEnemyBaseLocation(aiBrain)

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
        if bDebugMessages == true then LOG(sFunctionRef..': iEntry='..iEntry..'; Distance='..tValue[refiMexDistance]..'; Location='..repru(tValue[refiMexLocation])) end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Have '..table.getn(tMexByPathingAndGrouping[sPathing][iPathingGroup])..' mexes in MexByPathingAndGrouping, and iSortedCount='..iSortedCount) end

    --Now record mexes that we want to maintain scouts for
    if M27Utilities.IsTableEmpty(aiBrain[reftMexesToKeepScoutsBy]) == true then
        aiBrain[reftMexesToKeepScoutsBy] = {}
        local sPathing = M27UnitInfo.refPathingTypeLand
        local iStartPathingGroup = GetSegmentGroupOfLocation(sPathing, PlayerStartPoints[aiBrain.M27StartPositionNumber])
        local sLocationRef
        local iMinDistanceFromBase = 40
        local tNearbyMexes
        local iNearbyMexSearchRange = 15 --Wont assign a scout to a mex if it's already covered by another mex within this range
        local bHaveNearbyAssignedMex
        local sNearbyLocationRef
        local iCurDistanceToEnemy, iCurDistanceToStart
        if bDebugMessages == true then LOG(sFunctionRef..': sPathing='..sPathing..'; iStartPathingGroup='..iStartPathingGroup..'; tMexByPathingAndGrouping='..repru(aiBrain[tMexByPathingAndGrouping])) end

        for iMex, tMex in tMexByPathingAndGrouping[sPathing][iStartPathingGroup] do
            iCurDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tMex, tOurStartPos)
            if bDebugMessages == true then LOG(sFunctionRef..': iMex='..iMex..'; tMex='..repru(tMex)..'; iCurDistanceToStart='..iCurDistanceToStart) end
            if iCurDistanceToStart > iMinDistanceFromBase then
                --Are we closer to us than enemy?
                iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tMex, tEnemyStartPosition)
                if bDebugMessages == true then LOG(sFunctionRef..': iCurDistanceToEnemy='..iCurDistanceToEnemy) end
                if iCurDistanceToStart <= iCurDistanceToEnemy then
                    sLocationRef = M27Utilities.ConvertLocationToReference(tMex)
                    bHaveNearbyAssignedMex = false
                    if bDebugMessages == true then LOG(sFunctionRef..': About to check if near another mex that have already assigned') end
                    for iNearbyMex, tNearbyMex in tMexByPathingAndGrouping[sPathing][iStartPathingGroup] do
                        sNearbyLocationRef = M27Utilities.ConvertLocationToReference(tNearbyMex)
                        if M27Utilities.IsTableEmpty(aiBrain[reftMexesToKeepScoutsBy][sNearbyLocationRef]) == false then
                            if M27Utilities.GetDistanceBetweenPositions(tNearbyMex, tMex) <= iNearbyMexSearchRange then
                                if bDebugMessages == true then LOG(sFunctionRef..': sLocationRef='..sLocationRef..'; sNearbyLocationRef='..sNearbyLocationRef..'; tNearbyMex='..repru(tNearbyMex)..'; already have an entry for this in reftMexesToKeepScoutsBy='..repru(aiBrain[reftMexesToKeepScoutsBy][sNearbyLocationRef])) end
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
            M27Utilities.ErrorHandler('No mexes on our side of map in pathing group outside core mexes - likely error unless unusual map setup', true)
        else
            LOG(sFunctionRef..': Finished recording mexes to keep scouts by='..repru(aiBrain[reftMexesToKeepScoutsBy])..'; count='..table.getn(aiBrain[reftMexesToKeepScoutsBy]))
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordStartingPathingGroups(aiBrain)
    --For now will just do amphibious and land
    aiBrain[refiStartingSegmentGroup] = {}
    aiBrain[refiStartingSegmentGroup][M27UnitInfo.refPathingTypeAmphibious] = GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, PlayerStartPoints[aiBrain.M27StartPositionNumber])
    aiBrain[refiStartingSegmentGroup][M27UnitInfo.refPathingTypeLand] = GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, PlayerStartPoints[aiBrain.M27StartPositionNumber])
end

function GetMexPatrolLocations(aiBrain, iMexRallyPointsToAdd, bIncludeRallyPoint)
    --Returns a table of land pathable mexes on our side of the map near middle of map to patrol; will add up to iMexRallyPointsToAdd, and also if bIncludeRallyPoint is true will include the last rally point

    --If are turtling, then instead will return the chokepoint location and a random point near it

    local sFunctionRef = 'GetMexPatrolLocations'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    if M27Utilities.IsTableEmpty(aiBrain[reftMexPatrolLocations]) then

        aiBrain[reftMexPatrolLocations] = {}
        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle and aiBrain[reftChokepointBuildLocation] then

            aiBrain[reftMexPatrolLocations][1] = aiBrain[reftChokepointBuildLocation]
            if iMexRallyPointsToAdd >= 2 then
                local iSegmentGroup = GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, aiBrain[reftChokepointBuildLocation])
                for iRandomPoint = 2, iMexRallyPointsToAdd do
                    aiBrain[reftMexPatrolLocations][iRandomPoint] = M27Logic.GetRandomPointInAreaThatCanPathTo(M27UnitInfo.refPathingTypeAmphibious, iSegmentGroup, aiBrain[reftChokepointBuildLocation], 15, 5, false)
                end
            end
        else
            --Cycle through mexes on our side of the map:
            local tStartPosition = PlayerStartPoints[aiBrain.M27StartPositionNumber]
            --local oACU = M27Utilities.GetACU(aiBrain)
            local sPathing = M27UnitInfo.refPathingTypeLand
            --if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
            local iSegmentGroup = GetSegmentGroupOfLocation(sPathing, tStartPosition)
            local iCurDistanceToEnemy, iCurDistanceToStart

            local tEnemyStartPosition = GetPrimaryEnemyBaseLocation(aiBrain)
            local iMaxTotalDistance = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 1.3
            local iPossibleMexCount = 0
            local tPossibleMexDetails = {}
            local reftPossibleMexLocation = 'M27GetMexPatrolMexLocation'
            local refiMexDistanceToEnemy = 'M27GetMexPatrolMexDistanceToEnemy'
            local iMinDistanceFromBase = 50
            local iValidMexCount = 0
            if bDebugMessages == true then LOG(sFunctionRef..': Before loop through mexes; sPathing='..sPathing..'; iSegmentGroup='..iSegmentGroup) end
            if M27Utilities.IsTableEmpty(tMexByPathingAndGrouping[sPathing]) == false then
                if bDebugMessages == true then LOG(sFunctionRef..': tMexByPathingAndGrouping[sPathing] isnt empty; table='..repru(tMexByPathingAndGrouping[sPathing])) end
                if M27Utilities.IsTableEmpty(tMexByPathingAndGrouping[sPathing][iSegmentGroup]) == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': List of mexes that are considering='..repru(tMexByPathingAndGrouping[sPathing][iSegmentGroup])) end
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
                if bDebugMessages == true then LOG(sFunctionRef..': iPossibleMexCount='..iPossibleMexCount..'; tPossibleMexDetails='..repru(tPossibleMexDetails)) end
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
    if not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle) then table.insert(tPatrolLocations, M27Logic.GetNearestRallyPoint(aiBrain, GetPrimaryEnemyBaseLocation(aiBrain))) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tPatrolLocations
end


--[[function RecordSegmentGroup(iSegmentX, iSegmentZ, sPathing, iSegmentGroup)
    --Cycle through all adjacent cells, and then call this function on them as well
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordSegmentGroup'
    if bDebugMessages == true then LOG(sFunctionRef..': About to record iSegmentX='..iSegmentX..'; iSegmentZ='..iSegmentZ..'; iSegmentGroup='..iSegmentGroup..'; and then check if can path to adjacent segments') end
    tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ] = iSegmentGroup

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
        --if tPathingSegmentGroupBySegment[sPathing][tAdjacentSegment[1]][tAdjacentSegment[2]] == nil then
--[[            if bDebugMessages == true then LOG(sFunctionRef..': Have no entry yet for XZ='..tAdjacentSegment[1]..'-'..tAdjacentSegment[2]..' so will see if we can path there') end
            tTargetPosition = GetPositionFromPathingSegments(tAdjacentSegment[1], tAdjacentSegment[2])
            if IsLandPathableAlongLine(tCurPosition[1], tTargetPosition[1], tCurPosition[3], tTargetPosition[3]) then
                RecordSegmentGroup(tAdjacentSegment[1], tAdjacentSegment[2], sPathing, iSegmentGroup)
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
    --local sPathing = M27UnitInfo.refPathingTypeLand




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
                tPathingSegmentGroupBySegment[sPathing][iBaseSegmentX][iBaseSegmentZ] = iLandPathingGroupForWater
            end
        end
    end--]]

    if bDebugMessages == true then LOG(sFunctionRef..': iMaxSegmentX='..iMaxSegmentX..'; iMaxSegmentZ='..iMaxSegmentZ) end
    local sPathingLand = M27UnitInfo.refPathingTypeLand
    local sPathingAmphibious = M27UnitInfo.refPathingTypeAmphibious
    local sPathingNavy = M27UnitInfo.refPathingTypeNavy
    local sAllPathingTypes = {sPathingNavy, sPathingLand, sPathingAmphibious}
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
        LOG(sFunctionRef..': tGeneralAreaAroundTargetAdjustments='..repru(tGeneralAreaAroundTargetAdjustments))
        LOG(sFunctionRef..': tWaterAreaAroundTargetAdjustments='..repru(tWaterAreaAroundTargetAdjustments))
    end

    --Setup localised versions of global variables used by IsXPathableAlongLine
    local iMaxDifInHeight = iMaxHeightDif
    local iMaxDifForLandToSea = iAmphibiousMaxHeightDif
    local iDifInHeightThreshold = iLowHeightDifThreshold
    local bUseTerrainHeightNotSurfaceHeight = bUseTerrainHeightForBeachCheck

    local iIntervalSize = math.floor(iPathingIntervalSize)
    local iNavyMinWaterDepth = iMinWaterDepth --Dif between terrain and surface height required to be pathable to most ships
    local tAdjustmentsForArea = tGeneralAreaAroundTargetAdjustments
    local tAreaAdjToSearch = tWaterAreaAroundTargetAdjustments
    local iMinAreaSize = iWaterMinArea
    local iMapSizeX, iMapSizeZ = GetMapSize() --use map size instead of playable area as only interested in not causing error by trying to get non existent value


    function IsAmphibiousPathableAlongLine(xStartInteger, xEndInteger, zStartInteger, zEndInteger)--, bForceDebug)
        --Thanks to Balthazar for figuring out a more accurate test for pathability (look in whole integer intervals of 1 and compare height dif to see if it's >0.75)  - have used this idea to update my previous code

        --This is mostly a copy of land pathing but with changes for water
        --local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        --local sFunctionRef = 'IsAmphibiousPathableAlongLine'
        --if bForceDebug then bDebugMessages = true end
        local sTerrainType
        local tiSurfaceHeights = {}
        local tiTerrainHeights = {}
        local iFloorStartX = math.floor(xStartInteger)
        local iFloorStartZ = math.floor(zStartInteger)
        local iFloorEndX = math.floor(xEndInteger)
        local iFloorEndZ = math.floor(zEndInteger)
        local bLineIncludesLand = false
        for iCurX = math.min(iFloorStartX, iFloorEndX), math.max(iFloorStartX, iFloorEndX), 1 do
            for iCurZ = math.min(iFloorStartZ, iFloorEndZ), math.max(iFloorStartZ, iFloorEndZ), 1 do
                sTerrainType = GetTerrainType(iCurX,iCurZ)['Name']
                if sTerrainType == 'Dirt09' or sTerrainType == 'Lava01' then
                    --if bDebugMessages == true then LOG(sFunctionRef..': Terrain type is impassable') end
                    return false
                else
                    --Are we on land?
                    --if GetTerrainHeight(iCurX, iCurZ) > iMapWaterHeight then bLineIncludesLand = true end
                    if bUseTerrainHeightNotSurfaceHeight and not(bLineIncludesLand) and GetTerrainHeight(iCurX, iCurZ) > iMapWaterHeight then bLineIncludesLand = true end
                    if bLineIncludesLand then
                        --Compare height difference of surface
                        tiTerrainHeights[1] = GetTerrainHeight(iCurX - 1, iCurZ - 1)
                        tiTerrainHeights[2] = GetTerrainHeight(iCurX - 1, iCurZ)
                        if math.abs(tiTerrainHeights[1]-tiTerrainHeights[2]) > iMaxDifForLandToSea then return false
                        else
                            tiTerrainHeights[3] = GetTerrainHeight(iCurX, iCurZ)
                            if math.abs(tiTerrainHeights[2] - tiTerrainHeights[3]) > iMaxDifForLandToSea then return false
                            else
                                tiTerrainHeights[4] = GetTerrainHeight(iCurX, iCurZ - 1)
                                if math.abs(tiTerrainHeights[3] - tiTerrainHeights[4]) > iMaxDifForLandToSea then return false
                                elseif math.abs(tiTerrainHeights[4] - tiTerrainHeights[1]) > iMaxDifForLandToSea then return false
                                else
                                    for _, iHeight in tiTerrainHeights do
                                        if iHeight < iMapWaterHeight then return false end
                                    end
                                end
                            end
                        end
                    else
                        --Compare height difference of surface
                        tiSurfaceHeights[1] = GetSurfaceHeight(iCurX - 1, iCurZ - 1)
                        tiSurfaceHeights[2] = GetSurfaceHeight(iCurX - 1, iCurZ)
                        if math.abs(tiSurfaceHeights[1]-tiSurfaceHeights[2]) > iMaxDifInHeight then return false
                        else
                            tiSurfaceHeights[3] = GetSurfaceHeight(iCurX, iCurZ)
                            if math.abs(tiSurfaceHeights[2] - tiSurfaceHeights[3]) > iMaxDifInHeight then return false
                            else
                                tiSurfaceHeights[4] = GetSurfaceHeight(iCurX, iCurZ - 1)
                                if math.abs(tiSurfaceHeights[3] - tiSurfaceHeights[4]) > iMaxDifInHeight then return false
                                elseif math.abs(tiSurfaceHeights[4] - tiSurfaceHeights[1]) > iMaxDifInHeight then return false
                                end
                            end
                        end
                    end
                end
            end
        end
        return true

        --[[local iCurDifInHeight
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
            --if bDebugMessages == true then LOG(sFunctionRef..': CurPosition='..repru({iCurX, iCurTerrainHeight, iCurZ})) end
            iNextX = iCurX + iIntervalSize * iXFactor
            iNextZ = iCurZ + iIntervalSize * iZFactor
            iNextTerrainHeight = Max(GetTerrainHeight(iNextX, iNextZ), GetSurfaceHeight(iNextX, iNextZ))
            --if bDebugMessages == true then LOG(sFunctionRef..': NextPosition='..repru({iNextX, iNextTerrainHeight, iNextZ})..'; iMaxDifInHeight='..iMaxDifInHeight) end
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
        return true--]]
    end

    function IsLandPathableAlongLine(xStartInteger, xEndInteger, zStartInteger, zEndInteger)
        --Thanks to Balthazar for figuring out a more accurate test for pathability (look in whole integer intervals of 1 and compare height dif to see if it's >0.75) - have used this idea to update my previous code

        --Assumes will call for positions in a straight line from each other
        --Can handle diagonals, but x and z differences must be identical (error handler re this can be uncommented out if come across issues)
        --local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        --if bForceDebug == true then bDebugMessages = true end
        --local sFunctionRef = 'IsLandPathableAlongLine'
        --if xStartInteger >= 150 and xEndInteger <= 350 and zStartInteger >= 150 and zEndInteger <= 350 then bDebugMessages = true end
        --if bDebugMessages == true then LOG(sFunctionRef..': Start of code, X Start-End='..xStartInteger..'-'..xEndInteger..'; Z='..zStartInteger..'-'..zEndInteger..'; iMaxDifInHeight='..iMaxDifInHeight) end

        local sTerrainType
        local tiTerrainHeights = {}
        local iFloorStartX = math.floor(xStartInteger)
        local iFloorStartZ = math.floor(zStartInteger)
        local iFloorEndX = math.floor(xEndInteger)
        local iFloorEndZ = math.floor(zEndInteger)
        --if bDebugMessages == true then LOG(sFunctionRef..': xStartInteger='..xStartInteger..'; xEndInteger='..xEndInteger..'; zStartInteger='..zStartInteger..';, zEndInteger='..zEndInteger) end
        for iCurX = math.min(iFloorStartX, iFloorEndX), math.max(iFloorStartX, iFloorEndX), 1 do
            for iCurZ = math.min(iFloorStartZ, iFloorEndZ), math.max(iFloorStartZ, iFloorEndZ), 1 do
                sTerrainType = GetTerrainType(iCurX,iCurZ)['Name']
                if sTerrainType == 'Dirt09' or sTerrainType == 'Lava01' then
                    --if bDebugMessages == true then LOG(sFunctionRef..': Terrain type is impassable') end
                    return false
                else
                    --Compare height difference of surface
                    tiTerrainHeights[1] = GetTerrainHeight(iCurX - 1, iCurZ - 1)
                    tiTerrainHeights[2] = GetTerrainHeight(iCurX - 1, iCurZ)
                    if math.abs(tiTerrainHeights[1]-tiTerrainHeights[2]) > iMaxDifInHeight then return false
                    else
                        tiTerrainHeights[3] = GetTerrainHeight(iCurX, iCurZ)
                        if math.abs(tiTerrainHeights[2] - tiTerrainHeights[3]) > iMaxDifInHeight then return false
                        else
                            tiTerrainHeights[4] = GetTerrainHeight(iCurX, iCurZ - 1)
                            if math.abs(tiTerrainHeights[3] - tiTerrainHeights[4]) > iMaxDifInHeight then return false
                            elseif math.abs(tiTerrainHeights[4] - tiTerrainHeights[1]) > iMaxDifInHeight then return false
                            else
                                for _, iHeight in tiTerrainHeights do
                                    if iHeight < iMapWaterHeight then return false end
                                end
                            end
                        end
                    end
                end
            end
        end
        return true

        --[[
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
            --if bDebugMessages == true then LOG(sFunctionRef..': CurPosition='..repru({iNextX, iCurTerrainHeight, iNextZ})) end
            iNextX = iCurX + iIntervalSize * iXFactor
            iNextZ = iCurZ + iIntervalSize * iZFactor
            iNextTerrainHeight = GetTerrainHeight(iNextX, iNextZ)
            --if bDebugMessages == true then LOG(sFunctionRef..': NextPosition='..repru({iNextX, iNextTerrainHeight, iNextZ})..'; iMaxDifInHeight='..iMaxDifInHeight) end
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
        return true--]]
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
    
    local function RecordPathingGroup(sPathing, iSegmentX, iSegmentZ, iPathingGroup)
        tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ] = iPathingGroup
        if tSegmentBySegmentGroup[sPathing][iPathingGroup] == nil then
            tSegmentBySegmentGroup[sPathing][iPathingGroup] = {}
        end
        table.insert(tSegmentBySegmentGroup[sPathing][iPathingGroup], {iSegmentX, iSegmentZ})
    end

    local iCurTerrainHeight, iCurSurfaceHeight

    for iPathingType, sPathing in sAllPathingTypes do
        if sPathing == M27UnitInfo.refPathingTypeNavy then iIntervalSize = iWaterPathingIntervalSize
        else iIntervalSize = iPathingIntervalSize end

        tPathingSegmentGroupBySegment[sPathing] = {}
        tSegmentBySegmentGroup[sPathing] = {}
        for iSegmentX = 1, iMaxSegmentX do
            tPathingSegmentGroupBySegment[sPathing][iSegmentX] = {}
        end
        bNavyPathfinding = false
        bLandPathing = false
        bAmphibPathing = false
        bCheckForLand = false
        if sPathing == sPathingLand then
            bCheckForWater = true
            bLandPathing = true
        elseif sPathing == sPathingAmphibious then
            bCheckForWater = false
            bAmphibPathing = true
        elseif sPathing == sPathingNavy then
            bCheckForWater = true
            bCheckForLand = true
            bNavyPathfinding = true
        else M27Utilities.ErrorHandler('Need to add code') --Redundancy
        end

        --LOG(sFunctionRef..'; bMapContainsWater='..tostring(bMapContainsWater)..'; bLandPathing='..tostring(bLandPathing)..'; sPathing='..sPathing..'; sPathingAmphibious='..sPathingAmphibious)
        for iBaseSegmentX = 1, iMaxSegmentX do
            for iBaseSegmentZ = 1, iMaxSegmentZ do
                if bMapContainsWater == false and bLandPathing == false then
                    if sPathing == sPathingAmphibious then --Copy land pathing as no water
                        tPathingSegmentGroupBySegment[sPathing][iBaseSegmentX][iBaseSegmentZ] = tPathingSegmentGroupBySegment[sPathingLand][iBaseSegmentX][iBaseSegmentZ]
                        tSegmentBySegmentGroup[sPathing] = tSegmentBySegmentGroup[sPathingLand]
                    elseif sPathing == sPathingNavy then --No water so everything just land
                        tPathingSegmentGroupBySegment[sPathing][iBaseSegmentX][iBaseSegmentZ] = iLandPathingGroupForWater
                    end
                else
                    iCurRecursivePosition = 1
                    --Check not already determined this
                    if tPathingSegmentGroupBySegment[sPathing][iBaseSegmentX][iBaseSegmentZ] == nil then
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
                                RecordPathingGroup(sPathing, iBaseSegmentX, iBaseSegmentZ, iLandPathingGroupForWater)
                            end
                        end
                        if bWaterOrLandCheck then
                            --Not on water (if looking at land pathing)/not on land (if looking at navy pathing)
                            iCurPathingGroup = iCurPathingGroup + 1
                            --RecordSegmentGroup(iSegmentX, iSegmentZ, sPathing, iCurPathingGroup)
                            iCurRecursivePosition = iCurRecursivePosition + 1

                            while iCurRecursivePosition > 1 do
                                bHaveSubsequentPath = false
                                RecordPathingGroup(sPathing, iSegmentX, iSegmentZ, iCurPathingGroup)
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
                                    --if bDebugMessages == true then LOG(sFunctionRef..': Considering adjacent segment; iEntry='..iEntry..'; tAdjacentSegment='..repru(tAdjacentSegment)) end
                                    if tPathingSegmentGroupBySegment[sPathing][tAdjacentSegment[1]][tAdjacentSegment[2]] == nil then
                                        tTargetPosition = GetPositionFromPathingSegments(tAdjacentSegment[1], tAdjacentSegment[2])
                                        --if bDebugMessages == true then LOG(sFunctionRef..': iEntry='..iEntry..': Have no entry yet for XZ='..tAdjacentSegment[1]..'-'..tAdjacentSegment[2]..' so will see if we can path there; tTargetPosition='..repru(tTargetPosition)..'; tCurPosition='..repru(tCurPosition)..'; iSegmentXZ='..iSegmentX..'-'..iSegmentZ) end
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
                                                    LOG(sFunctionRef..': Moving from land to water, tCurPosition='..repru(tCurPosition)..'; tTargetPosition='..repru(tTargetPosition)..'; iTerrainHeightCur='..iTerrainHeightCur..'; iMapWaterHeightCur='..iMapWaterHeightCur..'; iTerrainHeightTarget='..iTerrainHeightTarget..'; iMapWaterHeightTarget='..iMapWaterHeightTarget..'; will redo the logic with logs enabled')
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
                                        --if bDebugMessages == true then LOG(sFunctionRef..': Already have a pathing group which is '..tPathingSegmentGroupBySegment[sPathing][tAdjacentSegment[1]][tAdjacentSegment[2]]) end
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
                                    --if bDebugMessages == true then LOG(sFunctionRef..': Have nowhere that can path to that havent already considered, so moving recursive position back one, iCurRecursivePosition='..iCurRecursivePosition..'; New segment X-Z='..repru(tRecursivePosition[iCurRecursivePosition])) end
                                end
                                if iCurRecursivePosition > 1 then tCurPosition = GetPositionFromPathingSegments(iSegmentX, iSegmentZ) end
                            end
                        end
                    end
                end
            end
            --LOG(sFunctionRef..': Finished going through all Z values, size of table='..table.getn(tPathingSegmentGroupBySegment[sPathing][iBaseSegmentX]))
        end

    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function IdentifyCliffsAroundBase(aiBrain)
    --Uses similar approach to original pathing, but on the assumption that pathing has already been generated
    --Is only interested in impathable areas near our base on the way from our base to enemy base
    --Main reason is for emergency PD placement

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IdentifyCliffsAroundBase'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if aiBrain[refbCanPathToEnemyBaseWithAmphibious] and M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart]) then
        if bDebugMessages == true then LOG(sFunctionRef..': About to identify cliffs around our base on the way to the nearest enemy') end

        --Identify all cliffs on the way to the enemy base into their own 'groups' based on whether the group is the same amphibious pathing group as the ACU or not
        local tLineStartPoint
        local iAngleToEnemy = M27Utilities.GetAngleFromAToB(PlayerStartPoints[aiBrain.M27StartPositionNumber], GetPrimaryEnemyBaseLocation(aiBrain))
        local sPathing = M27UnitInfo.refPathingTypeAmphibious
        local iSegmentGroupWanted = GetSegmentGroupOfLocation(sPathing, PlayerStartPoints[aiBrain.M27StartPositionNumber])
        local iCurRecursivePosition
        local tRecursivePosition
        local bHaveSubsequentPath

        local iCurX, iCurZ
        local iLowestX = 10000
        local iHighestX = 0
        local iLowestZ = 10000
        local iHighestZ = 0

        local iInterval = 2
        local iCliffCount = 0
        local tiCliffBoundaries = {} --[x] = iCliffCount; returns {x1, z1, x2, z2}

        local iMaxSize = 220
        local bAbortRecordingCliff = false



        function RecordCliff()
            if not(aiBrain[tCliffsAroundBaseChokepoint][iCurX]) then
                aiBrain[tCliffsAroundBaseChokepoint][iCurX] = {}
                aiBrain[tCliffsAroundBaseChokepoint][iCurX][iCurZ] = {}
            else
                aiBrain[tCliffsAroundBaseChokepoint][iCurX][iCurZ] = {}
            end
            --May have already recorded a value when going through cliffs earlier, so dont want to overwrite in case we decide to abort recording this specific cliff
            if M27Utilities.IsTableEmpty(aiBrain[tCliffsAroundBaseChokepoint][iCurX][iCurZ], true) then aiBrain[tCliffsAroundBaseChokepoint][iCurX][iCurZ] = true end
            iLowestX = math.min(iCurX, iLowestX)
            iLowestZ = math.min(iCurZ, iLowestZ)
            iHighestX = math.max(iCurX, iHighestX)
            iHighestZ = math.max(iCurZ, iHighestZ)
        end
        aiBrain[tCliffsAroundBaseChokepoint] = {}

        --First record all locations that have cliffs around them
        for iDistToEnemy = iInterval, math.min(126, math.floor((aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.4 / iInterval))*iInterval), iInterval do
            tLineStartPoint = M27Utilities.MoveInDirection(PlayerStartPoints[aiBrain.M27StartPositionNumber], iAngleToEnemy, iDistToEnemy, false)
            --if bDebugMessages == true then LOG(sFunctionRef..': Our start point='..repru(PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; iAngleToEnemy='..iAngleToEnemy..'; iDistToEnemy='..iDistToEnemy..'; tLineStartPoint='..repru(tLineStartPoint)..'; iSegmentGroupWanted='..iSegmentGroupWanted) end
            --Check we haven't already recorded this in the cliffs around base
            iCurX = math.floor(tLineStartPoint[1])
            iCurZ = math.floor(tLineStartPoint[3])

            if not(aiBrain[tCliffsAroundBaseChokepoint][iCurX]) or not(aiBrain[tCliffsAroundBaseChokepoint][iCurX][iCurZ]) then
                --Can we path here from main base?
                --if bDebugMessages == true then LOG(sFunctionRef..': Segment group of line start point='..GetSegmentGroupOfLocation(sPathing, tLineStartPoint)) end
                if not(iSegmentGroupWanted == GetSegmentGroupOfLocation(sPathing, tLineStartPoint)) then
                    --Record all locations in a different pathing group from this position
                    --[[if bDebugMessages == true then
                        LOG(sFunctionRef..': Have a different pathing group, will draw line base in black')
                        M27Utilities.DrawLocation(tLineStartPoint, false, 3, 250, 1)
                    end--]]
                    tRecursivePosition = {}
                    iCurRecursivePosition = 1
                    iLowestX = 10000
                    iHighestX = 0
                    iLowestZ = 10000
                    iHighestZ = 0
                    iCliffCount = iCliffCount + 1
                    while iCurRecursivePosition > 0 do
                        --if bDebugMessages == true then LOG(sFunctionRef..': iCurRecursivePosition='..iCurRecursivePosition..'; iCurX='..iCurX..'; iCurZ='..iCurZ) end
                        bHaveSubsequentPath = false
                        RecordCliff()
                        if iHighestX - iLowestX > iMaxSize or iHighestZ - iLowestZ > iMaxSize then
                            if bDebugMessages == true then LOG(sFunctionRef..': Have too big a range of valeus so will abort recording for this cliff.  iLowestX='..iLowestX..'; iHighestX='..iHighestX..'; iLowestZ='..iLowestZ..'; iHighestZ='..iHighestZ) end
                            bAbortRecordingCliff = true
                            break
                        end
                        local tAllAdjacentPositions = {
                            {iCurX - iInterval, iCurZ -iInterval},
                            {iCurX - iInterval, iCurZ},
                            {iCurX - iInterval, iCurZ +iInterval},

                            {iCurX, iCurZ - iInterval},
                            {iCurX, iCurZ + iInterval},

                            {iCurX + iInterval, iCurZ - iInterval},
                            {iCurX + iInterval, iCurZ},
                            {iCurX + iInterval, iCurZ + iInterval},
                        }


                        --if bDebugMessages == true then LOG(sFunctionRef..': iCurX-Z='..iCurX..'-'..iCurZ..'; iCurRecursivePosition='..iCurRecursivePosition..': About to check if are at edge of map') end
                        --Dont check if are at map edge (if we really wanted to optimise this then I expect predefined tables of all the options would work but for now I'll leave it at this
                        if iCurX >= rMapPlayableArea[3] or iCurZ >= rMapPlayableArea[4] or iCurX < iInterval or iCurZ < iInterval then
                            --if bDebugMessages == true then LOG(sFunctionRef..': Are at map edge so limit the adjacent segments to consider') end
                            tAllAdjacentPositions = {}
                            local bCanDecreaseX, bCanIncreaseX, bCanDecreaseZ, bCanIncreaseZ
                            if iCurX > iInterval then bCanDecreaseX = true end
                            if iCurZ > iInterval then bCanDecreaseZ = true end
                            if iCurX < rMapPlayableArea[3] then bCanIncreaseX = true end
                            if iCurZ < rMapPlayableArea[4] then bCanIncreaseZ = true end
                            if bCanDecreaseX then
                                if bCanDecreaseZ then table.insert(tAllAdjacentPositions, {iCurX - iInterval, iCurZ -iInterval}) end
                                if bCanIncreaseZ then table.insert(tAllAdjacentPositions, {iCurX - iInterval, iCurZ +iInterval}) end
                                table.insert(tAllAdjacentPositions, {iCurX - iInterval, iCurZ})
                            end
                            if bCanIncreaseX then
                                if bCanDecreaseZ then table.insert(tAllAdjacentPositions, {iCurX + iInterval, iCurZ -iInterval}) end
                                if bCanIncreaseZ then table.insert(tAllAdjacentPositions, {iCurX + iInterval, iCurZ +iInterval}) end
                                table.insert(tAllAdjacentPositions, {iCurX + iInterval, iCurZ})
                            end
                            if bCanDecreaseZ then table.insert(tAllAdjacentPositions, {iCurX, iCurZ -iInterval}) end
                            if bCanIncreaseZ then table.insert(tAllAdjacentPositions, {iCurX, iCurZ +iInterval}) end
                        end


                        --if bDebugMessages == true then LOG(sFunctionRef..': iSegmentX-Z='..iSegmentX..'-'..iSegmentZ..'; iCurRecursivePosition='..iCurRecursivePosition..': Number of adjacent locations to consider='..table.getn(tAllAdjacentSegments)) end
                        for iEntry, tAdjacentXZ in tAllAdjacentPositions do
                            --Have we already considered this location?
                            if not(aiBrain[tCliffsAroundBaseChokepoint][tAdjacentXZ[1]]) or not(aiBrain[tCliffsAroundBaseChokepoint][tAdjacentXZ[1]][tAdjacentXZ[2]]) then

                                --Is this position also unapthable from main base?
                                if not(iSegmentGroupWanted == GetSegmentGroupOfLocation(sPathing, {tAdjacentXZ[1], 0, tAdjacentXZ[2] })) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Adjacent segment '..repru(tAdjacentXZ)..' has a pathing group '..(GetSegmentGroupOfLocation(sPathing, {tAdjacentXZ[1], 0, tAdjacentXZ[2] }) or 'nil')..' so will continue searching') end
                                    bHaveSubsequentPath = true
                                    iCurX = tAdjacentXZ[1]
                                    iCurZ = tAdjacentXZ[2]
                                    break
                                end
                            end
                        end
                        if bHaveSubsequentPath == true then
                            tRecursivePosition[iCurRecursivePosition] = {iCurX, iCurZ}
                            iCurRecursivePosition = iCurRecursivePosition + 1
                            --if bDebugMessages == true then LOG(sFunctionRef..': Can path to the new segment so setting cur segment equal to the new segment') end
                        else
                            iCurRecursivePosition = iCurRecursivePosition - 1
                            if bDebugMessages == true then LOG(sFunctionRef..': Dont have adjacent segment so reducing recursive position to '..iCurRecursivePosition) end
                            if iCurRecursivePosition <= 0 then break
                            else
                                iCurX = tRecursivePosition[iCurRecursivePosition][1]
                                iCurZ = tRecursivePosition[iCurRecursivePosition][2]
                                --if bDebugMessages == true then LOG(sFunctionRef..': Have nowhere that can path to that havent already considered, so moving recursive position back one, iCurRecursivePosition='..iCurRecursivePosition..'; New segment X-Z='..repru(tRecursivePosition[iCurRecursivePosition])) end
                            end
                        end
                    end
                    tiCliffBoundaries[iCliffCount] = {iLowestX, iLowestZ, iHighestX, iHighestZ}
                end
            elseif bDebugMessages == true then
                LOG(sFunctionRef..': Have the same pathing group, will draw line base in white')
                --M27Utilities.DrawLocation(tLineStartPoint, false, 7, 250, 1)
            end
        end
        --[[if bDebugMessages == true then
            if bDebugMessages == true then LOG(sFunctionRef..': Will draw all cliffs in red. tiCliffBoundaries='..repru(tiCliffBoundaries)) end
            if M27Utilities.IsTableEmpty(aiBrain[tCliffsAroundBaseChokepoint]) == false then
                for iX, tSubtable in aiBrain[tCliffsAroundBaseChokepoint] do
                    for iZ, vResult in aiBrain[tCliffsAroundBaseChokepoint][iX] do
                        M27Utilities.DrawLocation({ iX, GetTerrainHeight(iX, iZ), iZ }, false, 2, 250, 1)
                    end
                end
            end
        end--]]

        if bAbortRecordingCliff then
            --Clear any values we just added
            if M27Utilities.IsTableEmpty(aiBrain[tCliffsAroundBaseChokepoint]) == false then
                for iX, tSubtable in aiBrain[tCliffsAroundBaseChokepoint] do
                    if M27Utilities.IsTableEmpty(tSubtable) == false then
                        for iZ, vResult in aiBrain[tCliffsAroundBaseChokepoint][iX] do
                            if (aiBrain[tCliffsAroundBaseChokepoint][iX][iZ] == true or aiBrain[tCliffsAroundBaseChokepoint][iX][iZ] == 0) and M27Utilities.IsTableEmpty(aiBrain[tCliffsAroundBaseChokepoint][iX][iZ], true) then
                                aiBrain[tCliffsAroundBaseChokepoint][iX][iZ] = nil
                            end
                        end
                    end
                end
            end
        else

            --Increase min and max sizes for each cliff, and then pick the 2 corner points with the smallest mod distance to our base
            local tCorner1, tCorner2, tCurCorner
            local tCornerPositions = {}
            local tiDistToCorners = {}
            local iClosestDist = 100000
            local iSecondClosestDist = 10000
            local iClosestCorner
            local iSecondClosestCorner
            local iCurDist

            local bIntersectsMapEdge

            for iCliff, tBoundaries in tiCliffBoundaries do
                bIntersectsMapEdge = false
                iClosestDist = 100000
                iSecondClosestDist = 10000
                iClosestCorner = nil
                iSecondClosestCorner = nil

                if tBoundaries[1] - 4 <= rMapPlayableArea[1] then bIntersectsMapEdge = true
                elseif tBoundaries[2] - 4 <= rMapPlayableArea[2] then bIntersectsMapEdge = true
                elseif tBoundaries[3] + 4 >= rMapPlayableArea[3] then bIntersectsMapEdge = true
                elseif tBoundaries[4] + 4 >= rMapPlayableArea[4] then bIntersectsMapEdge = true
                end

                local iBoundaryMod = 10
                if bIntersectsMapEdge then iBoundaryMod = 2 end



                tBoundaries[1] = math.floor(math.max(rMapPlayableArea[1] + iInterval, tBoundaries[1] - iBoundaryMod))
                tBoundaries[2] = math.floor(math.max(rMapPlayableArea[2] + iInterval, tBoundaries[2] - iBoundaryMod))
                tBoundaries[3] = math.floor(math.min(rMapPlayableArea[3] - iInterval, tBoundaries[3] + iBoundaryMod))
                tBoundaries[4] = math.floor(math.min(rMapPlayableArea[4] - iInterval, tBoundaries[4] + iBoundaryMod))



                --Calculate the 2 points we want to build PD at for each cliff:
                for iCorner = 1, 4 do
                    if iCorner == 1 then tCurCorner = {tBoundaries[1], GetTerrainHeight(tBoundaries[1], tBoundaries[2]), tBoundaries[2]}
                    elseif iCorner == 2 then tCurCorner = {tBoundaries[3], GetTerrainHeight(tBoundaries[3], tBoundaries[2]), tBoundaries[2]}
                    elseif iCorner == 3 then tCurCorner = {tBoundaries[3], GetTerrainHeight(tBoundaries[3], tBoundaries[4]), tBoundaries[4]}
                    else tCurCorner = {tBoundaries[1], GetTerrainHeight(tBoundaries[1], tBoundaries[4]), tBoundaries[4]}
                    end
                    tCornerPositions[iCorner] = {tCurCorner[1], tCurCorner[2], tCurCorner[3]}
                    --tiAngleDifFromBase[iCorner] = iAngleToEnemy - M27Utilities.GetAngleFromAToB(PlayerStartPoints[aiBrain.M27StartPositionNumber], tCurCorner)
                    --if tiAngleDifFromBase[iCorner] < 0 then tiAngleDifFromBase[iCorner] = tiAngleDifFromBase[iCorner] + 360 end
                    iCurDist = math.cos(M27Utilities.ConvertAngleToRadians(math.abs(M27Utilities.GetAngleFromAToB(PlayerStartPoints[aiBrain.M27StartPositionNumber], tCurCorner) - iAngleToEnemy))) * M27Utilities.GetDistanceBetweenPositions(PlayerStartPoints[aiBrain.M27StartPositionNumber], tCurCorner)
                    tiDistToCorners[iCorner] = iCurDist
                    if bDebugMessages == true then LOG(sFunctionRef..': Before updating closest corners: iCurDist='..iCurDist..'; iClosestDist='..iClosestDist..'; iClosestCorner='..(iClosestCorner or 'nil')..'; iSecondClosestDist='..iSecondClosestDist..'; iSecondClosestCorner='..(iSecondClosestCorner or 'nil')) end
                    if iCurDist < iClosestDist then
                        iSecondClosestDist = iClosestDist
                        iSecondClosestCorner = iClosestCorner
                        iClosestDist = iCurDist
                        iClosestCorner = iCorner

                    elseif iCurDist < iSecondClosestDist then
                        iSecondClosestDist = iCurDist
                        iSecondClosestCorner = iCorner
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': After updating closest corners: iCurDist='..iCurDist..'; iClosestDist='..iClosestDist..'; iClosestCorner='..(iClosestCorner or 'nil')..'; iSecondClosestDist='..iSecondClosestDist..'; iSecondClosestCorner='..(iSecondClosestCorner or 'nil')) end
                end

                --[[if bDebugMessages == true then
                    LOG(sFunctionRef..': iCliff='..iCliff..'; tBoundaries='..repru(tBoundaries)..'; will draw in gold, and will draw the corners in blue. iClosestCorner='..iClosestCorner..'; iClosestDist='..iClosestDist..'; iSecondClosestCorner='..iSecondClosestCorner..'; iSecondClosestDist='..iSecondClosestDist..'; table of corners='..repru(tCornerPositions))
                    M27Utilities.DrawRectangle(Rect(tBoundaries[1], tBoundaries[2], tBoundaries[3], tBoundaries[4]), 4, 500)
                    M27Utilities.DrawLocation(tCornerPositions[iClosestCorner], nil, 1, 500)
                    M27Utilities.DrawLocation(tCornerPositions[iSecondClosestCorner], nil, 1, 500)
                end--]]

                --Adjust if are intersecting a map edge - only need 1 corner point
                local tSinglePointOverride
                local iAdjustMax = math.max(1, iInterval * 0.5)

                if bIntersectsMapEdge then
                    --Fill in all the cliff positions since they're currently only at intervals of 2
                    for iX = tBoundaries[1], tBoundaries[3] do
                        --if bDebugMessages == true then LOG(sFunctionRef..': repru of tCliffsAroundBaseChokepoint for this iX of '..iX..' before filling in='..repru(aiBrain[tCliffsAroundBaseChokepoint][iX])) end
                        if M27Utilities.IsTableEmpty(aiBrain[tCliffsAroundBaseChokepoint][iX]) == false then
                            for iZ = tBoundaries[2], tBoundaries[4] do
                                --if bDebugMessages == true then LOG(sFunctionRef..': Updating entries around iX-Z='..iX..'-'..iZ) end
                                if aiBrain[tCliffsAroundBaseChokepoint][iX][iZ] == true then
                                    for iAdjustValueX = -iAdjustMax, iAdjustMax, 1 do
                                        for iAdjustValueZ = -iAdjustMax, iAdjustMax, 1 do
                                            if M27Utilities.IsTableEmpty(aiBrain[tCliffsAroundBaseChokepoint][iX + iAdjustValueX]) then aiBrain[tCliffsAroundBaseChokepoint][iX + iAdjustValueX] = {} end
                                            if not(aiBrain[tCliffsAroundBaseChokepoint][iX + iAdjustValueX][iZ + iAdjustValueZ]) then aiBrain[tCliffsAroundBaseChokepoint][iX + iAdjustValueX][iZ + iAdjustValueZ] = 0 end
                                            --if bDebugMessages == true then LOG(sFunctionRef..': Adjusted X-Z='..iX + iAdjustValueX..'-'..iZ + iAdjustValueZ..'; value of table for this='..tostring(aiBrain[tCliffsAroundBaseChokepoint][iX + iAdjustValueX][iZ + iAdjustValueZ])) end
                                        end
                                    end
                                end
                            end
                        end
                        --if bDebugMessages == true then LOG(sFunctionRef..': Finished filling in entries for iX='..iX..' repru of table for this iX='..repru(aiBrain[tCliffsAroundBaseChokepoint][iX])) end
                    end


                    local iMaxDistToCorner = iInterval
                    for iCorner = 1, 4 do
                        iMaxDistToCorner = math.max(iMaxDistToCorner, M27Utilities.GetDistanceBetweenPositions(PlayerStartPoints[aiBrain.M27StartPositionNumber], tCornerPositions[iCorner]))
                    end
                    iMaxDistToCorner = math.floor(iMaxDistToCorner / iInterval) * iInterval
                    local iAnglePoints = 8 --Pick a number that results in iangleinterval being an integer, otherwise might need to rework code to reference angle point instead of angle
                    local iAngleInterval = math.floor(360 / iAnglePoints)
                    local tiAnglesWithNoCliffs = {}
                    local tiAngleSquareIntersectPosition = {} --[x] is the angle (45, 90 etc); returns the location where moving at angle interval * angle point we intersect the edge of the cliff box
                    for iCurAngle = iAngleInterval, 360, iAngleInterval do
                        tiAnglesWithNoCliffs[iCurAngle] = true
                    end

                    local tCurPoint, iX, iZ

                    local bAreWithinX = false
                    local bAreWithinZ = false
                    if PlayerStartPoints[aiBrain.M27StartPositionNumber][1] > tBoundaries[1] and PlayerStartPoints[aiBrain.M27StartPositionNumber][1] < tBoundaries[3] then bAreWithinX = true end
                    if PlayerStartPoints[aiBrain.M27StartPositionNumber][3] > tBoundaries[2] and PlayerStartPoints[aiBrain.M27StartPositionNumber][3] < tBoundaries[4] then bAreWithinZ = true end


                    for iCurAngle = iAngleInterval, 360, iAngleInterval do
                        --There's probably a mathematical formula that achieves this, but as this is only run once I'm just going to brute force it...
                        for iCurDist = iInterval, iMaxDistToCorner, iInterval do
                            tCurPoint = M27Utilities.MoveInDirection(PlayerStartPoints[aiBrain.M27StartPositionNumber], iCurAngle, iCurDist, false)
                            iX = math.floor(tCurPoint[1])
                            iZ = math.floor(tCurPoint[3])
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering if iX-Z='..iX..'-'..iZ..' is intersecting with the box.') end
                            if aiBrain[tCliffsAroundBaseChokepoint][iX] and aiBrain[tCliffsAroundBaseChokepoint][iX][iZ] then
                                tiAnglesWithNoCliffs[iCurAngle] = false
                                --if bDebugMessages == true then M27Utilities.DrawLocation(tCurPoint, false, 5, 200) end --black
                                --if bDebugMessages == true then LOG(sFunctionRef..': iCurAngle='..iCurAngle..'; Interesects box at iX='..iX..'; iZ='..iZ..'; will draw in black') end
                                break
                            else
                                --Have we intersected with X part of the box?
                                if (bAreWithinX and (iX >= tBoundaries[3] or iX <= tBoundaries[1])) or (not(bAreWithinX) and (iX <= tBoundaries[3] or iX >= tBoundaries[1])) or (bAreWithinZ and (iZ >= tBoundaries[4] or iZ <= tBoundaries[2])) or (not(bAreWithinZ) and (iZ <= tBoundaries[4] or iZ >= tBoundaries[2])) then

                                    --We have reached the edge of the square
                                    tiAngleSquareIntersectPosition[iCurAngle] = {iX, GetTerrainHeight(iX, iZ), iZ}
                                    --if bDebugMessages == true then M27Utilities.DrawLocation(tCurPoint, false, 1, 200) end --dark blue
                                    break
                                --elseif bDebugMessages == true then M27Utilities.DrawLocation(tCurPoint, false, 6, 200) --Cyan
                                end
                            end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': Cliff='..iCliff..'; Finished recording angles that dont intersect with the cliff. tiAnglesWithNoCliffs='..repru(tiAnglesWithNoCliffs)..'; tiAngleSquareIntersectPosition='..repru(tiAngleSquareIntersectPosition)) end

                    local iCurDistToEnemy
                    local iClosestDistToEnemy = 10000
                    local iClosestAngle
                    local iDistToClosest

                    if M27Utilities.IsTableEmpty(tiAngleSquareIntersectPosition) == false then
                        for iAngle, tPosition in tiAngleSquareIntersectPosition do
                            iCurDistToEnemy = M27Utilities.GetDistanceBetweenPositions(tPosition, GetPrimaryEnemyBaseLocation(aiBrain))
                            if iCurDistToEnemy < iClosestDistToEnemy then
                                iClosestDistToEnemy = iCurDistToEnemy
                                iClosestAngle = iAngle
                            end
                        end
                        --See if have a second closest to enemy within 30 of this
                        if iClosestAngle then
                            for iAngle, tPosition in tiAngleSquareIntersectPosition do
                                if not(iAngle == iClosestAngle) then
                                    iDistToClosest = M27Utilities.GetDistanceBetweenPositions(tPosition, tiAngleSquareIntersectPosition[iClosestAngle])
                                    if bDebugMessages == true then LOG(sFunctionRef..': Considering iAngle='..iAngle..'; Dist to closest='..iDistToClosest..'; iClosestAngle='..iClosestAngle) end
                                    if iDistToClosest <= 30 then
                                        tSinglePointOverride = {tPosition[1], tPosition[2], tPosition[3]}
                                        if bDebugMessages == true then LOG(sFunctionRef..': Setting target position as the second closest, iAngle='..iAngle..'; iClosestAngle='..iClosestAngle..'; Dist to closest='..iDistToClosest) end
                                        break
                                    end
                                end
                            end
                            if not(tSinglePointOverride) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Couldnt find any close angles to the closest so picking the closest') end
                                tSinglePointOverride = {tiAngleSquareIntersectPosition[iClosestAngle][1], tiAngleSquareIntersectPosition[iClosestAngle][2], tiAngleSquareIntersectPosition[iClosestAngle][3]}
                            end
                        end
                    end
                end

                --Adjust the corner position to be a midpoint if it's behind the base (e.g. maps like forbidden pass)
                local bUseSinglePoint = false
                if M27Utilities.IsTableEmpty(tSinglePointOverride) == false then bUseSinglePoint = true end

                if not(bUseSinglePoint) then
                    local iCurCorner
                    local iCurDistToEnemy
                    local iAngleFromStartToCorner
                    local iAngleFromOurBaseToEnemy = M27Utilities.GetAngleFromAToB(PlayerStartPoints[aiBrain.M27StartPositionNumber], GetPrimaryEnemyBaseLocation(aiBrain))
                    local iAngleDif
                    local iClosestUnclaimedCorner
                    local iClosestDistToUnclaimedCorner = 100000
                    local iCurDistToUnclaimedCorner
                    for iCornerOption = 1, 2 do
                        if iCornerOption == 1 then iCurCorner = iClosestCorner else iCurCorner = iSecondClosestCorner end
                        --Are we further from enemy base than our base?
                        iCurDistToEnemy = M27Utilities.GetDistanceBetweenPositions(tCornerPositions[iCurCorner], GetPrimaryEnemyBaseLocation(aiBrain))
                        if iCurDistToEnemy > aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] then
                            iAngleFromStartToCorner = M27Utilities.GetAngleFromAToB(PlayerStartPoints[aiBrain.M27StartPositionNumber], tCornerPositions[iCurCorner])
                            iAngleDif = M27Utilities.GetAngleDifference(iAngleFromStartToCorner, iAngleFromOurBaseToEnemy) --Gives value from 0 to 180
                            if iAngleDif > 90 then
                                --Move towards the closest other corner
                                for iCorner = 1, 4 do
                                    if not(iCorner == iClosestCorner) and not(iCorner == iSecondClosestCorner) then
                                        iCurDistToUnclaimedCorner = M27Utilities.GetDistanceBetweenPositions(tCornerPositions[iCurCorner], tCornerPositions[iCorner])
                                        if iCurDistToUnclaimedCorner < iClosestDistToUnclaimedCorner then
                                            iClosestUnclaimedCorner = iCorner
                                            iClosestDistToUnclaimedCorner = iCurDistToUnclaimedCorner
                                        end
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': iCurCorner='..iCurCorner..'; iClosestUnclaiemdCorner='..iClosestUnclaimedCorner..'; Dist to closest unclaimed='..iClosestDistToUnclaimedCorner..'; Corner position of closest unclaimed='..repru(tCornerPositions[iClosestUnclaimedCorner])..'; Corner position before we adjust='..repru(tCornerPositions[iCurCorner])) end
                                tCornerPositions[iCurCorner] = M27Utilities.MoveTowardsTarget(tCornerPositions[iCurCorner], tCornerPositions[iClosestUnclaimedCorner], math.min(iClosestDistToUnclaimedCorner * 0.5, math.max(50, M27Utilities.GetDistanceBetweenPositions(tCornerPositions[iCurCorner], PlayerStartPoints[aiBrain.M27StartPositionNumber]))), 0)
                                tCornerPositions[iCurCorner][1] = math.floor(tCornerPositions[iCurCorner][1])
                                tCornerPositions[iCurCorner][3] = math.floor(tCornerPositions[iCurCorner][3])
                                tCornerPositions[iCurCorner][2] = GetTerrainHeight(tCornerPositions[iCurCorner][1], tCornerPositions[iCurCorner][3])
                                if bDebugMessages == true then LOG(sFunctionRef..': Corner position after adjust='..repru(tCornerPositions[iCurCorner])..'; Dist to the unclaimed corner='..M27Utilities.GetDistanceBetweenPositions(tCornerPositions[iCurCorner], tCornerPositions[iClosestUnclaimedCorner])) end
                            end

                        end

                    end
                end

                --Are the corners too far from our base? If so then only move part-way towards them
                local iMaxDistance = math.min(math.max(125, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.4), 200)


                if bUseSinglePoint then
                    if M27Utilities.GetDistanceBetweenPositions(tSinglePointOverride, PlayerStartPoints[aiBrain.M27StartPositionNumber]) > iMaxDistance then
                        tSinglePointOverride = M27Utilities.MoveInDirection(PlayerStartPoints[aiBrain.M27StartPositionNumber], M27Utilities.GetAngleFromAToB(PlayerStartPoints[aiBrain.M27StartPositionNumber], tSinglePointOverride), iMaxDistance, false)
                    end
                else
                    if M27Utilities.GetDistanceBetweenPositions(tCornerPositions[iClosestCorner], PlayerStartPoints[aiBrain.M27StartPositionNumber]) > iMaxDistance then
                        tSinglePointOverride = M27Utilities.MoveInDirection(PlayerStartPoints[aiBrain.M27StartPositionNumber], M27Utilities.GetAngleFromAToB(PlayerStartPoints[aiBrain.M27StartPositionNumber], tCornerPositions[iClosestCorner]), iMaxDistance, false)
                    end
                    if M27Utilities.GetDistanceBetweenPositions(tCornerPositions[iSecondClosestCorner], PlayerStartPoints[aiBrain.M27StartPositionNumber]) > iMaxDistance then
                        tSinglePointOverride = M27Utilities.MoveInDirection(PlayerStartPoints[aiBrain.M27StartPositionNumber], M27Utilities.GetAngleFromAToB(PlayerStartPoints[aiBrain.M27StartPositionNumber], tCornerPositions[iSecondClosestCorner]), iMaxDistance, false)
                    end
                end



                --Cycle through every position in this square, work out the closest of the 2 corners, and record this corner

                for iX = tBoundaries[1], tBoundaries[3] do
                    if not(aiBrain[tCliffsAroundBaseChokepoint][iX]) then
                        aiBrain[tCliffsAroundBaseChokepoint][iX] = {}
                    end

                    for iZ = tBoundaries[2], tBoundaries[4] do
                        if bDebugMessages == true and iZ == tBoundaries[2] then LOG(sFunctionRef..': iX='..iX..'; iZ='..iZ..'; Dist to corner1='..M27Utilities.GetDistanceBetweenPositions({iX, 0, iZ}, tCornerPositions[iClosestCorner])..'; Dist to corner2='..M27Utilities.GetDistanceBetweenPositions({iX, 0, iZ}, tCornerPositions[iSecondClosestCorner])) end
                        if bUseSinglePoint then aiBrain[tCliffsAroundBaseChokepoint][iX][iZ] = {tSinglePointOverride[1], tSinglePointOverride[2], tSinglePointOverride[3]}
                        else
                            if M27Utilities.GetDistanceBetweenPositions({iX, 0, iZ}, tCornerPositions[iClosestCorner]) < M27Utilities.GetDistanceBetweenPositions({iX, 0, iZ}, tCornerPositions[iSecondClosestCorner]) then
                                --Closest corner is closest to this position
                                aiBrain[tCliffsAroundBaseChokepoint][iX][iZ] = {tCornerPositions[iClosestCorner][1], tCornerPositions[iClosestCorner][2], tCornerPositions[iClosestCorner][3]}
                                if bDebugMessages == true and iZ == tBoundaries[2] then LOG(sFunctionRef..': iX-Z='..iX..'-'..iZ..'; are near the closest corner '..iClosestCorner..'; Corner position='..repru(tCornerPositions[iClosestCorner])..'; aiBrain[tCliffsAroundBaseChokepoint][iX][iZ]='..repru(aiBrain[tCliffsAroundBaseChokepoint][iX][iZ])) end
                            else
                                --Second closest corner to start is closest to this position
                                aiBrain[tCliffsAroundBaseChokepoint][iX][iZ] = {tCornerPositions[iSecondClosestCorner][1], tCornerPositions[iSecondClosestCorner][2], tCornerPositions[iSecondClosestCorner][3]}
                            end
                        end
                    end
                end

                --bDebugMessages = false

                if bDebugMessages == true and false then
                    LOG(sFunctionRef..': Will give result of the first row of x values at the lowest Z boundary')
                    for iX = tBoundaries[1], tBoundaries[3] do
                        LOG('Result of table for iX='..iX..'; iZ='..tBoundaries[2]..'='..repru(aiBrain[tCliffsAroundBaseChokepoint][iX][tBoundaries[2]]))
                    end
                    LOG(sFunctionRef..': WIll draw all locations using the closest corner in light blue, and all locations using the second closest in red. If using single point will use gold if equals single point, and will use dark blue if dont recognise the location recorded. tBoundaries='..repru(tBoundaries))
                    local iColour
                    for iX = tBoundaries[1], tBoundaries[3] do
                        for iZ = tBoundaries[2], tBoundaries[4] do
                            if aiBrain[tCliffsAroundBaseChokepoint][iX][iZ][1] == tCornerPositions[iClosestCorner][1] and aiBrain[tCliffsAroundBaseChokepoint][iX][iZ][3] == tCornerPositions[iClosestCorner][3] then
                                iColour = 5 --light blue
                            elseif aiBrain[tCliffsAroundBaseChokepoint][iX][iZ][1] == tCornerPositions[iSecondClosestCorner][1] and aiBrain[tCliffsAroundBaseChokepoint][iX][iZ][3] == tCornerPositions[iSecondClosestCorner][3] then
                                iColour = 2 --red
                            elseif bUseSinglePoint and aiBrain[tCliffsAroundBaseChokepoint][iX][iZ][1] == tSinglePointOverride[1] and aiBrain[tCliffsAroundBaseChokepoint][iX][iZ][3] == tSinglePointOverride[3] then
                                iColour = 4 --Gold
                            else
                                iColour = 1 --Dark blue
                            end
                            if iZ == tBoundaries[2] then LOG(sFunctionRef..': About to draw location '..repru({iX, GetTerrainHeight(iX, iZ), iZ})..' in colour '..iColour..'; corner recorded as closest='..repru(aiBrain[tCliffsAroundBaseChokepoint][iX][iZ])..'; closest corner position='..repru(tCornerPositions[iClosestCorner])) end
                            M27Utilities.DrawLocation({iX, GetTerrainHeight(iX, iZ), iZ}, false, iColour, 200)
                        end
                    end
                    --Draw the corners again as larger circles
                    LOG(sFunctionRef..': WIll now redraw the corners as circles in black')
                    if bUseSinglePoint then
                        LOG(sFunctionRef..': Using single point, location='..repru(tSinglePointOverride)..'; Our base location='..repru(PlayerStartPoints[aiBrain.M27StartPositionNumber]))
                        M27Utilities.DrawLocation(tSinglePointOverride, false, 3, 500, 5)
                    else
                        M27Utilities.DrawLocation(tCornerPositions[iClosestCorner], false, 3, 500, 5)
                        M27Utilities.DrawLocation(tCornerPositions[iSecondClosestCorner], false, 3, 500, 5)
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': End of loop for iCliff='..iCliff..'; aiBrain index='..aiBrain:GetArmyIndex()) end
            end
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)


end

function SetupNoRushDetails(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'SetupNoRushDetails'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end

    if ScenarioInfo.Options.NoRushOption  and not(ScenarioInfo.Options.NoRushOption == 'Off') then
        if bDebugMessages == true then LOG(sFunctionRef..': No rush isnt active, will record details') end
        if not(bNoRushActive) then --This is the first time for any AI that this is run
            if bDebugMessages == true then LOG(sFunctionRef..': Log of ScenarioInfo='..repru(ScenarioInfo)) end
            bNoRushActive = true
            iNoRushTimer = tonumber(ScenarioInfo.Options.NoRushOption) * 60
            ForkThread(NoRushMonitor)
            if bDebugMessages == true then LOG(sFunctionRef..': First time have run this so ahve set bNoRushActive='..tostring(bNoRushActive)..' and started iNoRushTimer for '..iNoRushTimer..' to change norush back to false') end
        end
        --Setup details of norush range for each M27AI
        if bNoRushActive then
            local tMapInfo = ScenarioInfo
            aiBrain[reftNoRushCentre] = {PlayerStartPoints[aiBrain.M27StartPositionNumber][1], 0, PlayerStartPoints[aiBrain.M27StartPositionNumber][3]}
            local sXRef = 'norushoffsetX_ARMY_'..aiBrain:GetArmyIndex()
            local sZRef = 'norushoffsetY_ARMY_'..aiBrain:GetArmyIndex()
            if bDebugMessages == true then LOG(sFunctionRef..': Checking norush adjustments, sXRef='..sXRef..'; sZRef='..sZRef..'; MapInfoX='..(tMapInfo[sXRef] or 'nil')..'; MapInfoZ='..(tMapInfo[sZRef] or 'nil')..'; aiBrain[reftNoRushCentre] before adjustment='..repru(aiBrain[reftNoRushCentre])) end
            if tMapInfo[sXRef] then aiBrain[reftNoRushCentre][1] = aiBrain[reftNoRushCentre][1] + (tMapInfo[sXRef] or 0) end
            if tMapInfo[sZRef] then aiBrain[reftNoRushCentre][3] = aiBrain[reftNoRushCentre][3] + (tMapInfo[sZRef] or 0) end
            aiBrain[reftNoRushCentre][2] = GetTerrainHeight(aiBrain[reftNoRushCentre][1], aiBrain[reftNoRushCentre][3])
            iNoRushRange = tMapInfo.norushradius
            if bDebugMessages == true then
                LOG(sFunctionRef..': Have recorded key norush details for the ai with index='..aiBrain:GetArmyIndex()..'; iNoRushRange='..iNoRushRange..'; aiBrain[reftNoRushCentre]='..repru(aiBrain[reftNoRushCentre])..'; will draw a circle now in white around the area')
                M27Utilities.DrawCircleAtTarget(aiBrain[reftNoRushCentre], 7, 500, iNoRushRange)
            end

        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': No rush isnt active') end
        bNoRushActive = false --(redundancy)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function NoRushMonitor()
    local sFunctionRef = 'NoRushMonitor'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitSeconds(iNoRushTimer)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    bNoRushActive = false
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordAllPlateaus()
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordAllPlateaus'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Records any plateaus that contain mexes, along with info on the plateau such as a rectangle that covers the entire plateau

    --tMexByPathingAndGrouping --[a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
    --tAllPlateausWithMexes = {} --v41 - decided to take this out to see if it helps with issue where plateau number changes and all existing platoons become invalid


    local iCurPlateauMex, iMinX, iMaxX, iMinZ, iMaxZ, iSegmentCount
    local iMinSegmentX, iMinSegmentZ, iMaxSegmentX, iMaxSegmentZ, iCurSegmentGroup

    if bDebugMessages == true then LOG(sFunctionRef..': About to get max map segment X and Z based on rMapPlayableArea='..repru(rMapPlayableArea)) end
    local iMapMaxSegmentX, iMapMaxSegmentZ = GetPathingSegmentFromPosition({rMapPlayableArea[3], 0, rMapPlayableArea[4]})
    local iStartSegmentX, iStartSegmentZ
    local bSearchingForBoundary
    local iCurCount
    local tSegmentPosition
    local iReclaimSegmentStartX, iReclaimSegmentStartZ, iReclaimSegmentEndX, iReclaimSegmentEndZ
    local sPathing = M27UnitInfo.refPathingTypeAmphibious




    for iSegmentGroup, tSubtable in tMexByPathingAndGrouping[sPathing] do
        if not(tAllPlateausWithMexes[iSegmentGroup]) then

            --if not(tiBasePathingGroups[iSegmentGroup]) and not(tAllPlateausWithMexes[iSegmentGroup]) then
            --Have a plateau with mexes that havent already recorded
            tAllPlateausWithMexes[iSegmentGroup] = {}
            tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMexes] = {}
            iCurPlateauMex = 0
            for iMex, tMex in tMexByPathingAndGrouping[sPathing][iSegmentGroup] do
                iCurPlateauMex = iCurPlateauMex + 1
                tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMexes][iCurPlateauMex] = tMex
            end
            tAllPlateausWithMexes[iSegmentGroup][subrefPlateauTotalMexCount] = iCurPlateauMex
            if iCurPlateauMex > 0 then
                --Record size information

                --Start from mex, and move up on map to determine top point; then move left to determine left point, and right to determine right point
                --i.e. dont want to go through every segment on map every time since could take ages if lots of plateaus and may only be dealing with small area
                iStartSegmentX, iStartSegmentZ = GetPathingSegmentFromPosition(tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMexes][1])

                --First find the smallest z (so go up)
                bSearchingForBoundary = true
                iCurCount = 0
                while bSearchingForBoundary do
                    iCurCount = iCurCount + 1
                    if iCurCount > 10000 then
                        M27Utilities.ErrorHandler('Infinite loop')
                        break
                    end
                    --Stop if we will exceed map bounds
                    if iCurCount > iStartSegmentZ then break end
                    --Are we still in the same pathing group?
                    iCurSegmentGroup = tPathingSegmentGroupBySegment[sPathing][iStartSegmentX][iStartSegmentZ - iCurCount]
                    if not(iCurSegmentGroup == iSegmentGroup) then
                        --Can we find anywhere else with the same Z value in the pathing group?
                        bSearchingForBoundary = false
                        for iAltStartX = 1, iMapMaxSegmentX do
                            iCurSegmentGroup = tPathingSegmentGroupBySegment[sPathing][iAltStartX][iStartSegmentZ - iCurCount]
                            if iCurSegmentGroup == iSegmentGroup then
                                iStartSegmentX = iAltStartX
                                bSearchingForBoundary = true
                                break
                            end
                        end
                    end
                end
                --Will have the min Z value now
                iMinSegmentZ = iStartSegmentZ - iCurCount + 1


                --Now check for the min X value
                bSearchingForBoundary = true
                iCurCount = 0
                while bSearchingForBoundary do
                    iCurCount = iCurCount + 1
                    if iCurCount > 10000 then
                        M27Utilities.ErrorHandler('Infinite loop')
                        break
                    end
                    --Stop if we will exceed map bounds
                    if iCurCount > iStartSegmentX then break end
                    --Are we still in the same pathing group?
                    iCurSegmentGroup = tPathingSegmentGroupBySegment[sPathing][iStartSegmentX - iCurCount][iStartSegmentZ]
                    if not(iCurSegmentGroup == iSegmentGroup) then
                        --Can we find anywhere else with the same X value in the pathing group?
                        bSearchingForBoundary = false
                        for iAltStartZ = iMinSegmentZ, iMapMaxSegmentZ do
                            iCurSegmentGroup = tPathingSegmentGroupBySegment[sPathing][iStartSegmentX - iCurCount][iAltStartZ]
                            if iCurSegmentGroup == iSegmentGroup then
                                iStartSegmentZ = iAltStartZ
                                bSearchingForBoundary = true
                                break
                            end
                        end
                    end
                end

                --Will now have the min X value
                iMinSegmentX = iStartSegmentX - iCurCount + 1

                --Now get max Z value
                bSearchingForBoundary = true
                iCurCount = 0
                while bSearchingForBoundary do
                    iCurCount = iCurCount + 1
                    if iCurCount > 10000 then
                        M27Utilities.ErrorHandler('Infinite loop')
                        break
                    end
                    --Stop if we will exceed map bounds
                    if iCurCount + iStartSegmentZ > iMapMaxSegmentZ then break end
                    --Are we still in the same pathing group?
                    iCurSegmentGroup = tPathingSegmentGroupBySegment[sPathing][iStartSegmentX][iStartSegmentZ + iCurCount]
                    if not(iCurSegmentGroup == iSegmentGroup) then
                        --Can we find anywhere else with the same Z value in the pathing group?
                        bSearchingForBoundary = false
                        for iAltStartX = iMinSegmentX, iMapMaxSegmentX do
                            iCurSegmentGroup = tPathingSegmentGroupBySegment[sPathing][iAltStartX][iStartSegmentZ + iCurCount]
                            if iCurSegmentGroup == iSegmentGroup then
                                iStartSegmentX = iAltStartX
                                bSearchingForBoundary = true
                                break
                            end
                        end
                    end
                end
                iMaxSegmentZ = iStartSegmentZ + iCurCount - 1

                --Now get the max X value
                bSearchingForBoundary = true
                iCurCount = 0
                while bSearchingForBoundary do
                    iCurCount = iCurCount + 1
                    if iCurCount > 10000 then
                        M27Utilities.ErrorHandler('Infinite loop')
                        break
                    end
                    --Stop if we will exceed map bounds
                    if iCurCount + iStartSegmentX > iMapMaxSegmentX then break end
                    --Are we still in the same pathing group?
                    iCurSegmentGroup = tPathingSegmentGroupBySegment[sPathing][iStartSegmentX + iCurCount][iStartSegmentZ]
                    if not(iCurSegmentGroup == iSegmentGroup) then
                        --Can we find anywhere else with the same Z value in the pathing group?
                        bSearchingForBoundary = false
                        for iAltStartZ = iMinSegmentZ, iMaxSegmentZ do
                            iCurSegmentGroup = tPathingSegmentGroupBySegment[sPathing][iStartSegmentX + iCurCount][iAltStartZ]
                            if iCurSegmentGroup == iSegmentGroup then
                                iStartSegmentZ = iAltStartZ
                                bSearchingForBoundary = true
                                break
                            end
                        end
                    end
                end
                iMaxSegmentX = iStartSegmentX + iCurCount - 1

                tSegmentPosition = GetPositionFromPathingSegments(iMinSegmentX, iMinSegmentZ)
                tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMinXZ] = {tSegmentPosition[1], tSegmentPosition[3]}
                iReclaimSegmentStartX, iReclaimSegmentStartZ = GetReclaimSegmentsFromLocation(tSegmentPosition)

                tSegmentPosition = GetPositionFromPathingSegments(iMaxSegmentX, iMaxSegmentZ)
                tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMaxXZ] = {tSegmentPosition[1], tSegmentPosition[3]}
                iReclaimSegmentEndX, iReclaimSegmentEndZ = GetReclaimSegmentsFromLocation(tSegmentPosition)


                --Record all reclaim segments that are part of the plateau
                tAllPlateausWithMexes[iSegmentGroup][subrefPlateauReclaimSegments] = {}
                for iCurReclaimSegmentX = iReclaimSegmentStartX, iReclaimSegmentEndX do
                    tAllPlateausWithMexes[iSegmentGroup][subrefPlateauReclaimSegments][iCurReclaimSegmentX] = {}
                    for iCurReclaimSegmentZ = iReclaimSegmentStartZ, iReclaimSegmentEndZ do
                        if iSegmentGroup == GetSegmentGroupOfLocation(sPathing, GetReclaimLocationFromSegment(iCurReclaimSegmentX, iCurReclaimSegmentZ)) then
                            tAllPlateausWithMexes[iSegmentGroup][subrefPlateauReclaimSegments][iCurReclaimSegmentX][iCurReclaimSegmentZ] = true
                        end
                    end
                end
                --Clear any empty values
                for iCurReclaimSegmentX = iReclaimSegmentStartX, iReclaimSegmentEndX do
                    if tAllPlateausWithMexes[iSegmentGroup][subrefPlateauReclaimSegments][iCurReclaimSegmentX] and M27Utilities.IsTableEmpty(tAllPlateausWithMexes[iSegmentGroup][subrefPlateauReclaimSegments][iCurReclaimSegmentX]) then tAllPlateausWithMexes[iSegmentGroup][subrefPlateauReclaimSegments][iCurReclaimSegmentX] = nil end
                end

                --Record midpoint
                local iXRadius = (tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMaxXZ][1] - tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMinXZ][1])*0.5
                local iZRadius = (tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMaxXZ][2] - tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMinXZ][2])*0.5
                tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMidpoint] = {tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMinXZ][1] + iXRadius, 0, tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMinXZ][2] + iZRadius}
                tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMidpoint][2] = GetTerrainHeight(tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMidpoint][1], tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMidpoint][3])
                --CIrcle radius will be the square/rectangle diagonal, so (square radius^2*2)^0.5 for a square, or (x^2+z^2)^0.5

                tAllPlateausWithMexes[iSegmentGroup][subrefPlateauMaxRadius] = (iXRadius^2+iZRadius^2)^0.5
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, listing tAllPlateausWithMexes='..repru(tAllPlateausWithMexes)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function MappingInitialisation(aiBrain)
    --aiBrain needed for waterpercent function.  This is only called once; other 'one globally' things like bNoRushActive are also referenced here
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
        if bDebugMessages == true then LOG(sFunctionRef..': Playable area rec='..repru(rMapPlayableArea)..'; map size='..repru(GetMapSize())..'; iWaterPercent='..iWaterPercent..'; bMapHasWater='..tostring(bMapHasWater)) end
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
            LOG(sFunctionRef..': '..repru(rMapPlayableArea))
            --LOG('MapGroup='..repru(GetMapGroup()))
            LOG(sFunctionRef..': End of code')
        end

        --Record ponds
        M27Navy.RecordPonds()

        bPathfindingComplete = true

        --Other variables used by all M27ai
        for iPathingType, sPathing in M27UnitInfo.refPathingTypeAll do
            tManualPathingChecks[sPathing] = {}
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

    --Reclaim segment size (as use for plateaus):
    DetermineReclaimSegmentSize()

    --Plateau info
    RecordAllPlateaus()


    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function SetWhetherCanPathToEnemy(aiBrain)
    --Set flag for whether AI can path to enemy base
    --Also updates other values that are based on the nearest enemy

    local sFunctionRef = 'SetWhetherCanPathToEnemy'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if not(aiBrain[M27Logic.refbAllEnemiesDead]) then
        local tEnemyStartPosition = GetPrimaryEnemyBaseLocation(aiBrain)
        local tOurBase = PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local sPathing = M27UnitInfo.refPathingTypeLand
        local iOurBaseGroup = GetSegmentGroupOfLocation(sPathing, tOurBase)
        local iEnemyBaseGroup = GetSegmentGroupOfLocation(sPathing, tEnemyStartPosition)
        if iOurBaseGroup == iEnemyBaseGroup and not(IsUnderwater({tOurBase[1], GetTerrainHeight(tOurBase[1], tOurBase[3]), tOurBase[3]})) then aiBrain[refbCanPathToEnemyBaseWithLand] = true
        else aiBrain[refbCanPathToEnemyBaseWithLand] = false end
        sPathing = M27UnitInfo.refPathingTypeAmphibious
        iOurBaseGroup = GetSegmentGroupOfLocation(sPathing, tOurBase)
        iEnemyBaseGroup = GetSegmentGroupOfLocation(sPathing, tEnemyStartPosition)
        if iOurBaseGroup == iEnemyBaseGroup then aiBrain[refbCanPathToEnemyBaseWithAmphibious] = true
        else aiBrain[refbCanPathToEnemyBaseWithAmphibious] = false end

        aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] = M27Utilities.GetDistanceBetweenPositions(PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[reftPrimaryEnemyBaseLocation])
        aiBrain[M27AirOverseer.refiMaxScoutRadius] = math.max(1500, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 1.5)

        if aiBrain[refbCanPathToEnemyBaseWithAmphibious] then
            aiBrain[M27FactoryOverseer.refiMinimumTanksWanted] = 5
        else aiBrain[M27FactoryOverseer.refiMinimumTanksWanted] = 0 end

        --Record mitpoint between base (makes it easier to calc mod distance
        aiBrain[reftMidpointToPrimaryEnemyBase] = M27Utilities.MoveInDirection(PlayerStartPoints[aiBrain.M27StartPositionNumber], M27Utilities.GetAngleFromAToB(PlayerStartPoints[aiBrain.M27StartPositionNumber], tEnemyStartPosition), aiBrain[M27Overseer.refiDistanceToNearestEnemyBase], false)
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function LogMapTerrainTypes()
    --Outputs to log the terrain types used and how often theyre used
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'LogMapTerrainTypes'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
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
    LOG(sFunctionRef..': tTerrainTypeCount='..repru(tTerrainTypeCount))
    LOG(sFunctionRef..': End of table of terrain type, iDirt9Count2='..iDirt9Count2)
    LOG(sFunctionRef..': Surface height of water count table='..repru(tWaterSurfaceHeightCount))

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DrawAllMapPathing(aiBrain)
    local sFunctionRef = 'DrawAllMapPathing'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    while bPathfindingComplete == false do
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(10)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    end
    if not(bMapDrawingAlreadyCommenced[M27UnitInfo.refPathingTypeLand] == true) then
        DrawMapPathing(aiBrain, M27UnitInfo.refPathingTypeLand, true)
        while bMapDrawingAlreadyCommenced[M27UnitInfo.refPathingTypeLand] == true do
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitTicks(10)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(50)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        DrawMapPathing(aiBrain, M27UnitInfo.refPathingTypeAmphibious)
        while bMapDrawingAlreadyCommenced[M27UnitInfo.refPathingTypeAmphibious] == true do
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitTicks(10)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(50)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        DrawMapPathing(aiBrain, M27UnitInfo.refPathingTypeNavy, true)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DrawMapPathing(aiBrain, sPathing, bDontDrawWaterIfPathingLand)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --set to true for certain positions where want logs to print
    local sFunctionRef = 'DrawMapPathing'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if M27Utilities.IsTableEmpty(bMapDrawingAlreadyCommenced[sPathing]) == true then
        bMapDrawingAlreadyCommenced[sPathing] = true
        if bDontDrawWaterIfPathingLand == nil then
            if sPathing == M27UnitInfo.refPathingTypeAmphibious then bDontDrawWaterIfPathingLand = false
            else bDontDrawWaterIfPathingLand = true end
        end
        --Draw core pathing group
        local sFunctionRef = 'DrawMapPathing'
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code after waitticks') end
        local iSegmentX, iSegmentZ = GetPathingSegmentFromPosition(PlayerStartPoints[aiBrain.M27StartPositionNumber])
        local iStartingGroup = tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ]
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
        if sPathing == M27UnitInfo.refPathingTypeLand then
            bLandPathing = true
            iResetColour = 3
        end

        if iMaxSegments > 500 then
            if bDontDrawWaterIfPathingLand and aiBrain:GetMapWaterRatio() >= 0.5 then iSegmentInterval = 6
            else iSegmentInterval = 8 end
        elseif iSegmentInterval > 250 then
            if bDontDrawWaterIfPathingLand and aiBrain:GetMapWaterRatio() >= 0.4 and aiBrain:GetMapWaterRatio() <= 0.6 then iSegmentInterval = 1
            else iSegmentInterval = 2 end
        end

        local iTimeToWait = (iMaxBaseSegmentX / 10 + 40)

        local iCurIntervalCount = 0
        if bDebugMessages == true then
            LOG(sFunctionRef..': iMaxBaseSegmentX='..iMaxBaseSegmentX..'; iMaxBaseSegmentZ='..iMaxBaseSegmentZ..'; size of tPathingSegmentGroupBySegment for land pathing='..table.getn(tPathingSegmentGroupBySegment[sPathing])..'; player start point group='..iStartingGroup..'; player starting segments='..iSegmentX..'-'..iSegmentZ..'; start position location='..repru(PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; position of segment='..repru(GetPositionFromPathingSegments(iSegmentX, iSegmentZ)))
            LOG('Pathing groups of every segment around player start position about to be produced')
            for iAdjX = -1, 1, 1 do
                for iAdjZ = -1, 1, 1 do
                    LOG('iAdjX-Z='..iAdjX..'-'..iAdjZ..'; pathing group='..tPathingSegmentGroupBySegment[sPathing][iSegmentX+iAdjX][iSegmentZ+iAdjZ])
                end
            end
        end
        for iSegmentX = 1, iMaxBaseSegmentX do
            for iSegmentZ = 1, iMaxBaseSegmentZ do
                iCurGroup = tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ]
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
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitTicks(1)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                iWaitCount = 0
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Matches per segment group='..repru(tiMatchesPerSegmentGroup)) end
        for iSegmentX = 1, iMaxBaseSegmentX do
            for iSegmentZ = 1, iMaxBaseSegmentZ do
                iCurIntervalCount = iCurIntervalCount + 1
                --below line used for v.large maps like frostmill ruins if want to draw in greater detail around an area
                --if iSegmentX <= 380 and iSegmentX >= 280 and iSegmentZ <=380 and iSegmentZ >= 280 then iCurIntervalCount = iSegmentInterval end
                if iCurIntervalCount >= iSegmentInterval then
                    iCurIntervalCount = 0
                    iCurGroup = tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ]
                    if tiMatchesPerSegmentGroup[iCurGroup] > 10 and (not(bDontDrawWaterIfPathingLand) or not(iCurGroup == iLandPathingGroupForWater)) then
                        M27Utilities.DrawLocation(GetPositionFromPathingSegments(iSegmentX, iSegmentZ), nil, tiColourToUse[iCurGroup], iTimeToWait)
                    end
                end
                if iCurGroup == iStartingGroup then iMatches = iMatches + 1 end
            end
            if bDebugMessages == true then LOG('iMatches='..iMatches..'; iSegmentX-Z='..iSegmentX..'-'..iSegmentZ..'; Pathing group='..tPathingSegmentGroupBySegment[sPathing][iSegmentX][iSegmentZ]..'; position='..repru(GetPositionFromPathingSegments(iSegmentX, iSegmentZ))) end
            iWaitCount = iWaitCount + 1
            if iWaitCount > 10 then
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitTicks(1)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                iWaitCount = 0
            end
        end
    end
    bMapDrawingAlreadyCommenced[sPathing] = false
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DrawWater()
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --set to true for certain positions where want logs to print
    local sFunctionRef = 'DrawWater'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

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

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function TempCanPathToEveryMex(oUnit)
    local sFunctionRef = 'TempCanPathToEveryMex'
    --For testing purposes

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
    if bDebugMessages == true then LOG(sFunctionRef..': tCountByThreshold='..repru(tCountByThreshold)) end
end--]]

function RedoPathingForGroup(iPathingGroupToRedo, iNewPathingHeightThreshold)
    M27Utilities.ErrorHandler('Need to add code') --Not being used currently
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

        if bDebugMessages == true then LOG(sFunctionRef..': tAllMapResourceLocations for iType '..iType..'='..repru(tAllMapResourceLocations)) end

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
                    if bDebugMessages == true then LOG(sFunctionRef..': About to check if pathing for iResource='..iResource..'; tLocation='..repru(tLocation)..' is consistent. iCurResourceGroup='..iCurResourceGroup..'; iACUPathingGroup='..iACUPathingGroup..'; bActualPathingResult='..tostring(bActualPathingResult)) end
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
                LOG(sFunctionRef..': CanPathTo is false for location='..repru(tLocation))
                iUnpathableMexCount = iUnpathableMexCount + 1
            end
        end
        LOG('iUnpathableMexCount after first wait='..iUnpathableMexCount)
        WaitTicks(200)
        iUnpathableMexCount = 0
        for iResource, tLocation in MassPoints do
            if oACU:CanPathTo(tLocation) == false then
                M27Utilities.DrawLocation(tLocation, nil, 6, 200)
                LOG(sFunctionRef..': CanPathTo is false for location='..repru(tLocation))
                iUnpathableMexCount = iUnpathableMexCount + 1
            end
        end
        LOG('iUnpathableMexCount after 2nd wait='..iUnpathableMexCount)
        WaitTicks(200)
        iUnpathableMexCount = 0
        for iResource, tLocation in MassPoints do
            if oACU:CanPathTo(tLocation) == false then
                M27Utilities.DrawLocation(tLocation, nil, 5, 200)
                LOG(sFunctionRef..': CanPathTo is false for location='..repru(tLocation))
                iUnpathableMexCount = iUnpathableMexCount + 1
            end
        end
        LOG('iUnpathableMexCount after 3rd wait='..iUnpathableMexCount)
        WaitTicks(600)
        iUnpathableMexCount = 0
        for iResource, tLocation in MassPoints do
            if oACU:CanPathTo(tLocation) == false then
                M27Utilities.DrawLocation(tLocation, nil, 4, 200)
                if bDebugMessages == true then LOG(sFunctionRef..': CanPathTo is false for location='..repru(tLocation)) end
                iUnpathableMexCount = iUnpathableMexCount + 1
            end
        end
        LOG('iUnpathableMexCount after 4th wait='..iUnpathableMexCount)
        WaitTicks(2000)
        iUnpathableMexCount = 0
        for iResource, tLocation in MassPoints do
            if oACU:CanPathTo(tLocation) == false then
                M27Utilities.DrawLocation(tLocation, nil, 3, 200)
                if bDebugMessages == true then LOG(sFunctionRef..': CanPathTo is false for location='..repru(tLocation)) end
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

function RecordIfSuitableRallyPoint(aiBrain, tPossibleRallyPoint, iCurRallyPoints, iOurBaseGroup, bTheoreticalRallyPoints)
    --Records the rally point and returns the current number of rally points

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordIfSuitableRallyPoint'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetGameTimeSeconds() >= 1060 then bDebugMessages = true end

    local bAbortDueToIntelOrEnemies = false
    local sRallyPointRef = reftRallyPoints
    if bTheoreticalRallyPoints then sRallyPointRef = reftTheoreticalRallyPoints end
    local tComparisonRallyPoint
    if M27Utilities.IsTableEmpty(aiBrain[sRallyPointRef]) then tComparisonRallyPoint = {PlayerStartPoints[aiBrain.M27StartPositionNumber][1], PlayerStartPoints[aiBrain.M27StartPositionNumber][2], PlayerStartPoints[aiBrain.M27StartPositionNumber][3]}
    else
        tComparisonRallyPoint = {aiBrain[sRallyPointRef][iCurRallyPoints][1], aiBrain[sRallyPointRef][iCurRallyPoints][2], aiBrain[sRallyPointRef][iCurRallyPoints][3]}
    end
    if M27Utilities.IsTableEmpty(tPossibleRallyPoint) == false and GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, tPossibleRallyPoint) == iOurBaseGroup then

        --Far enough away from last rally point?
        if M27Utilities.IsTableEmpty(tPossibleRallyPoint) then M27Utilities.ErrorHandler('No rally point specified')
        else
            --Closer to enemy base than last rally point?
            if bDebugMessages == true then LOG(sFunctionRef..': Will consider if are closer to enemy base than last rally point. iCurRallyPoints='..iCurRallyPoints..'; tPossibleRallyPoint='..repru(tPossibleRallyPoint)..'; sRallyPointRef='..sRallyPointRef..'; repru of all rally points='..repru(aiBrain[sRallyPointRef])) end
            if iCurRallyPoints == 0 or (M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, GetPrimaryEnemyBaseLocation(aiBrain)) < M27Utilities.GetDistanceBetweenPositions(tComparisonRallyPoint, GetPrimaryEnemyBaseLocation(aiBrain))) then
                if bDebugMessages == true then
                    LOG(sFunctionRef..': About to check if '..repru(tPossibleRallyPoint)..' is a valid rally point; iCurRallyPoints='..iCurRallyPoints..'; will draw a black circle around potential location')
                    M27Utilities.DrawLocation(tPossibleRallyPoint, nil, 3)
                end
                if iCurRallyPoints == 0 or (M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, tComparisonRallyPoint) >= 40) then
                    --Within defence and closest friendly land unit?
                    bAbortDueToIntelOrEnemies = true
                    local bNearbyEnemyDefences = true
                    local iModDistToStart = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tPossibleRallyPoint)
                    if bDebugMessages == true then LOG(sFunctionRef..': iModDistToStart='..iModDistToStart..'; aiBrain[M27Overseer.refiModDistFromStartNearestThreat]='..aiBrain[M27Overseer.refiModDistFromStartNearestThreat]..'; aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] * 0.9='..aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] * 0.9..'; aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] - 50='..aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] - 50) end
                    if iCurRallyPoints == 0 then
                        bAbortDueToIntelOrEnemies = false
                        bNearbyEnemyDefences = false
                        if bDebugMessages == true then LOG(sFunctionRef..': First rally point so wont consider nearby enemies') end
                    elseif iModDistToStart < aiBrain[M27Overseer.refiModDistFromStartNearestThreat] and iModDistToStart < math.min(aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] * 0.9, aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] - math.max(50, aiBrain[M27Overseer.refiHighestMobileLandEnemyRange] + 15)) then
                        --Check if unseen PD nearby
                        local bNearbyUnseenPD = false
                        if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftUnseenPD]) == false then
                            for iUnit, oUnit in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftUnseenPD] do
                                if M27UnitInfo.IsUnitValid(oUnit) and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tPossibleRallyPoint) <= 75 then
                                    bNearbyUnseenPD = true
                                    break
                                end
                            end
                        end



                        if bDebugMessages == true then LOG(sFunctionRef..': bNearbyUnseenPD='..tostring(bNearbyUnseenPD)..'; aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy] * 0.9='..aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy] * 0.9..'; M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, PlayerStartPoints[aiBrain.M27StartPositionNumber])='..M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]) end
                        if not(bNearbyUnseenPD) and M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, PlayerStartPoints[aiBrain.M27StartPositionNumber]) / aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] < (aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy] * 0.9) then
                            local tNearbyPDAndT2Arti = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryT2PlusPD, tPossibleRallyPoint, 153, 'Enemy')
                            if M27Utilities.IsTableEmpty(tNearbyPDAndT2Arti) == false then
                                --T2 arti nearby?
                                local tNearbyDefences = EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedT2Arti, tNearbyPDAndT2Arti)
                                if bDebugMessages == true then LOG(sFunctionRef..': Have nearby T2 arti or T2 PD. Is table filtered to just t2 arti empty='..tostring(M27Utilities.IsTableEmpty(tNearbyDefences))) end
                                if M27Utilities.IsTableEmpty(tNearbyDefences) == true then
                                    --T3 PD nearby?
                                    tNearbyDefences = EntityCategoryFilterDown(M27UnitInfo.refCategoryPD * categories.TECH3, tNearbyPDAndT2Arti)
                                    if M27Utilities.IsTableEmpty(tNearbyDefences) == true or M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, M27Utilities.GetNearestUnit(tNearbyDefences, tPossibleRallyPoint, aiBrain, false, false):GetPosition()) > 90 then
                                        --T2 PD nearby?
                                        if bDebugMessages == true then LOG(sFunctionRef..': Nearest PD unit='..M27Utilities.GetNearestUnit(tNearbyPDAndT2Arti, tPossibleRallyPoint, aiBrain, false, false).UnitId..'; Position='..repru(M27Utilities.GetNearestUnit(tNearbyPDAndT2Arti, tPossibleRallyPoint, aiBrain, false, false):GetPosition())..'; Rally point position='..repru(tPossibleRallyPoint)) end
                                        if M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, M27Utilities.GetNearestUnit(tNearbyPDAndT2Arti, tPossibleRallyPoint, aiBrain, false, false):GetPosition()) > 70 then
                                            bNearbyEnemyDefences = false
                                        end
                                    elseif bDebugMessages == true then LOG(sFunctionRef..': Nearby T3 PD')
                                    end
                                elseif bDebugMessages == true then LOG(sFunctionRef..': Nearby T2 arti')
                                end
                            else
                                bNearbyEnemyDefences = false
                                if bDebugMessages == true then LOG(sFunctionRef..': Table of nearby PD and T2 arti is empty, so no nearby enemy defences') end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': bNearbyEnemyDefences='..tostring(bNearbyEnemyDefences)) end
                            if not(bNearbyEnemyDefences) then bAbortDueToIntelOrEnemies = false end
                        elseif bDebugMessages == true then LOG(sFunctionRef..': Nearest unit to enemy base is too close to rally point distance')
                        end
                    elseif bDebugMessages == true then LOG(sFunctionRef..': Not far enough away from enemy threats')
                    end

                    if (not(bAbortDueToIntelOrEnemies) and bNearbyEnemyDefences == false) or bTheoreticalRallyPoints then
                        --Do we have intel coverage of at least 20?
                        --if M27Logic.GetIntelCoverageOfPosition(aiBrain, tPossibleRallyPoint, 20, false) then
                        --Have a valid rally point
                        iCurRallyPoints = iCurRallyPoints + 1

                        aiBrain[sRallyPointRef][iCurRallyPoints] = {tPossibleRallyPoint[1], tPossibleRallyPoint[2], tPossibleRallyPoint[3]}
                        if bDebugMessages == true then LOG(sFunctionRef..': Have a valid rally point; iCurRallyPoints='..iCurRallyPoints..'; aiBrain[sRallyPointRef][iCurRallyPoints]='..repru(aiBrain[sRallyPointRef][iCurRallyPoints])..'; sRallyPointRef='..sRallyPointRef) end


                    --elseif bDebugMessages == true then LOG(sFunctionRef..': DOnt have sufficient intel coverage; IntelCoverage='..M27Logic.GetIntelCoverageOfPosition(aiBrain, tPossibleRallyPoint, nil, false))
                    --end
                    end
                elseif bDebugMessages == true then LOG(sFunctionRef..': Are too close to the existing rally point; existing rally point tComparisonRallyPoint='..repru(tComparisonRallyPoint)..'; Distance to this='..M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, tComparisonRallyPoint))
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
    --V43 - have rewritten how this works to try and optimise
    --If logs are enabled, then will draw large square (aqua) for all the theoretical rally points, then yellow inner square for if it's a valid rally point (i.e. no nearby threats).  Black smallest square relates to the mex location

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordAllRallyPoints'
    --if GetGameTimeSeconds() >= 1060 then bDebugMessages = true end
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code to recalculate rally points. Time since last refresh='..GetGameTimeSeconds() - (aiBrain[refiLastRallyPointRefresh] or 0)) end
    if GetGameTimeSeconds() - (aiBrain[refiLastRallyPointRefresh] or 0) >= 5 and aiBrain[M27Overseer.refbIntelPathsGenerated] then

        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        local iOurBaseGroup = GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, PlayerStartPoints[aiBrain.M27StartPositionNumber])
        aiBrain[refiLastRallyPointRefresh] = GetGameTimeSeconds()

        if not(aiBrain[refiNearestEnemyIndexWhenLastCheckedRallyPoints] == M27Logic.GetNearestEnemyIndex(aiBrain)) then
            --Update list of mexes that are along a line from our base to enemy base
            --tMexByPathingAndGrouping = {} --Stores position of each mex based on the segment that it's part of; [a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
            aiBrain[reftTheoreticalRallyPoints] = {}
            aiBrain[reftMexesAndDistanceNearPathToNearestEnemy] = {}

            if M27Utilities.IsTableEmpty(tMexByPathingAndGrouping[M27UnitInfo.refPathingTypeLand][iOurBaseGroup]) == false then
                local iDistToOurBase, iDistToEnemyBase
                local iMaxDistToBeNearMiddle
                for iMex, tMex in tMexByPathingAndGrouping[M27UnitInfo.refPathingTypeLand][iOurBaseGroup] do

                    iDistToOurBase = M27Utilities.GetDistanceBetweenPositions(tMex, PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    iDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tMex, GetPrimaryEnemyBaseLocation(aiBrain))
                    iMaxDistToBeNearMiddle = math.min(60, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.2, iDistToOurBase * 0.3) + aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering if mex is near path to enemy base; iMex='..iMex..'; tMex='..repru(tMex)..'; iDistToOurBase='..iDistToOurBase..'; iDistToEnemyBase='..iDistToEnemyBase..'; iMaxDistToBeNearMiddle='..iMaxDistToBeNearMiddle) end

                    if iDistToOurBase + iDistToEnemyBase <= iMaxDistToBeNearMiddle then
                        table.insert(aiBrain[reftMexesAndDistanceNearPathToNearestEnemy], {[reftMexLocation] = tMex, [refiDistanceToOurBase] = iDistToOurBase})
                    end
                end
            end



            --Update all potential rally point locations if ignored enemy threat
            local iCurRallyPoints = 0
            local iPrevRallyPoints = 0
            local bAbortedDueToEnemiesOrIntel
            local tPossibleRallyPoint
            local iAngleToEnemyBase = M27Utilities.GetAngleFromAToB(PlayerStartPoints[aiBrain.M27StartPositionNumber], GetPrimaryEnemyBaseLocation(aiBrain))
            local iFailedRallyPointChecks = 0


            local iCurDistToOurBase

            --Initial rally point: 1st base intel path
            if bDebugMessages == true then LOG(sFunctionRef..': About to add the first intel line position as a rally point; aiBrain[M27Overseer.reftIntelLinePositions][1][1]='..repru(aiBrain[M27Overseer.reftIntelLinePositions][1][1])..'; reftIntelLinePositions='..repru(aiBrain[M27Overseer.reftIntelLinePositions])) end
            iCurRallyPoints, bAbortedDueToEnemiesOrIntel = RecordIfSuitableRallyPoint(aiBrain, aiBrain[M27Overseer.reftIntelLinePositions][1][1], iCurRallyPoints, iOurBaseGroup, true)

            --Do we have any mexes near the central line? If so then cycle through these and add rally points as long as theyre valid
            local iDistTowardsEnemyBaseThreshold = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.75
            if M27Utilities.IsTableEmpty(aiBrain[reftMexesAndDistanceNearPathToNearestEnemy]) == false then
                local iLastRallyPointDistToStart = M27Utilities.GetDistanceBetweenPositions(PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.reftIntelLinePositions][1][1])
                --local tEnemyBase = GetPrimaryEnemyBaseLocation(aiBrain)
                --local iDistToEnemyBase

                if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through all mexes near the path to the nearest enemy') end
                for iMex, tSubtable in M27Utilities.SortTableBySubtable(aiBrain[reftMexesAndDistanceNearPathToNearestEnemy], refiDistanceToOurBase, true) do
                    --Add the mex as a theoretical rally point unless wthe mex is too close to the last rally point
                    if bDebugMessages == true then LOG(sFunctionRef..': Consider whether to add a place near the mex as a rally point unless we have more than 5 failed checks') end
                    --if iFailedRallyPointChecks <= 5 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Difference in distances to start between mex and last rally point='..aiBrain[reftMexesAndDistanceNearPathToNearestEnemy][iMex][refiDistanceToOurBase] - iLastRallyPointDistToStart) end
                    if (aiBrain[reftMexesAndDistanceNearPathToNearestEnemy][iMex][refiDistanceToOurBase] - iLastRallyPointDistToStart) > 40 then
                        if aiBrain[reftMexesAndDistanceNearPathToNearestEnemy][iMex][refiDistanceToOurBase] <= iDistTowardsEnemyBaseThreshold then
                            --FindRandomPlaceToBuild(aiBrain, oBuilder, tStartPosition, sBlueprintToBuild, iSearchSizeMin, iSearchSizeMax, bForcedDebug, iOptionalMaxCycleOverride)
                            tPossibleRallyPoint = M27EngineerOverseer.FindRandomPlaceToBuild(aiBrain, M27Utilities.GetACU(aiBrain), aiBrain[reftMexesAndDistanceNearPathToNearestEnemy][iMex][reftMexLocation]
                            ,(M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, M27UnitInfo.refCategoryLandFactory, M27Utilities.GetACU(aiBrain), false, false) or 'ueb0101')
                            ,2, 10, false, 2)

                            --if M27Utilities.IsTableEmpty(tPossibleRallyPoint) == false and GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, tPossibleRallyPoint) == iOurBaseGroup then
                            --Can path to the location, check if its far enough away from most recently added rally point and if any nearby enemies
                            if bDebugMessages == true then LOG(sFunctionRef..': Mex is far enough away; tPossibleRallyPoint='..repru(tPossibleRallyPoint)) end
                            if M27Utilities.IsTableEmpty(tPossibleRallyPoint) == false then
                                iCurRallyPoints, bAbortedDueToEnemiesOrIntel = RecordIfSuitableRallyPoint(aiBrain, tPossibleRallyPoint, iCurRallyPoints, iOurBaseGroup, true)
                                if iCurRallyPoints > iPrevRallyPoints then
                                    iLastRallyPointDistToStart = M27Utilities.GetDistanceBetweenPositions(tPossibleRallyPoint, PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                    iPrevRallyPoints = iCurRallyPoints
                                end
                            end
                        end
                        --end
                    end
                    --end
                end
            elseif bDebugMessages == true then LOG(sFunctionRef..': reftMexesAndDistanceNearPathToNearestEnemy is empty')
            end

            --Have added for all mexes from start to base; If we have <= 1 rally point, then just use intel lines as potential rally points
            if iCurRallyPoints <= 1 and iFailedRallyPointChecks <= 5 then
                for iIntelLine, tIntelPath in aiBrain[M27Overseer.reftIntelLinePositions] do
                    iPrevRallyPoints = iCurRallyPoints
                    if iIntelLine > 1 then
                        iCurRallyPoints, bAbortedDueToEnemiesOrIntel = RecordIfSuitableRallyPoint(aiBrain, aiBrain[M27Overseer.reftIntelLinePositions][iIntelLine][1], iCurRallyPoints, iOurBaseGroup, true)
                    end
                end
            end
        end
        if bDebugMessages == true then
            LOG(sFunctionRef..': Finished recording theoretically rally points, repr='..repru(aiBrain[reftTheoreticalRallyPoints])..'; will draw in aqua in a larger rectangle')
            M27Utilities.DrawLocations(aiBrain[reftTheoreticalRallyPoints], false, 5, 200, false, 4)
        end

        --Record actual rally points factoring in nearby enemy threats and intel
        local iCurRallyPoints = 0
        local bAbortedDueToEnemiesOrIntel
        aiBrain[reftRallyPoints] = {}
        local tPossibleRallyPoint
        local iFailedRallyPointChecks = 0


        if M27Utilities.IsTableEmpty(aiBrain[reftTheoreticalRallyPoints]) then
            iCurRallyPoints = 1
            aiBrain[reftRallyPoints][iCurRallyPoints] = {aiBrain[M27Overseer.reftIntelLinePositions][1][1][1], aiBrain[M27Overseer.reftIntelLinePositions][1][1][2], aiBrain[M27Overseer.reftIntelLinePositions][1][1][3]}
        else

            for iEntry, tTheoreticalLocation in aiBrain[reftTheoreticalRallyPoints] do
                if bDebugMessages == true then LOG(sFunctionRef..': About to consider if tTheoreticalLocation='..repru(tTheoreticalLocation)..' is a valid rally point; iCurRallyPoints before checking='..iCurRallyPoints..'; Dist from theoretical location to base='..M27Utilities.GetDistanceBetweenPositions(tTheoreticalLocation, PlayerStartPoints[aiBrain.M27StartPositionNumber])) end
                tPossibleRallyPoint = {tTheoreticalLocation[1], tTheoreticalLocation[2], tTheoreticalLocation[3]}
                iCurRallyPoints, bAbortedDueToEnemiesOrIntel = RecordIfSuitableRallyPoint(aiBrain, tPossibleRallyPoint, iCurRallyPoints, iOurBaseGroup)
                if bAbortedDueToEnemiesOrIntel == true then
                    iFailedRallyPointChecks = iFailedRallyPointChecks + 1
                    if iFailedRallyPointChecks > 5 then
                        if bDebugMessages == true then LOG(sFunctionRef..': iFailedRallyPointChecks='..iFailedRallyPointChecks..' so wont consider any further mex based locations') end
                        break end
                end
            end
            if iCurRallyPoints == 0 then
                iCurRallyPoints = 1
                aiBrain[reftRallyPoints][iCurRallyPoints] = {aiBrain[M27Overseer.reftIntelLinePositions][1][1][1], aiBrain[M27Overseer.reftIntelLinePositions][1][1][2], aiBrain[M27Overseer.reftIntelLinePositions][1][1][3]}
                if bDebugMessages == true then LOG(sFunctionRef..': No rally points using normal logic so will just set first equal to the intel path first line') end
            end
        end
        if M27Utilities.IsTableEmpty(aiBrain[reftRallyPoints]) then
            aiBrain[reftRallyPoints][iCurRallyPoints] = aiBrain[M27Overseer.reftIntelLinePositions][1][1]
        end

        aiBrain[refiNearestEnemyIndexWhenLastCheckedRallyPoints] = M27Logic.GetNearestEnemyIndex(aiBrain)

        if bDebugMessages == true then
            LOG(sFunctionRef..': End of code to recalculate rally points; iCurRallyPoints='..iCurRallyPoints..'; will highlight all actual rally points in yellow; ALl rally points='..repru(aiBrain[reftRallyPoints]))
            M27Utilities.DrawLocations(aiBrain[reftRallyPoints], nil, 4, 40, false, 2)
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
end

function CanWeMoveInSameGroupInLineToTarget(sPathing, tStart, tEnd)
    --If we move in a line to the target, are there any pathing issues? Use front unit rather than pathing unit
    local iStartingGroup = GetSegmentGroupOfLocation(sPathing, tStart)
    local iAngle = M27Utilities.GetAngleFromAToB(tStart, tEnd)
    for iCurPoint = 1, math.floor(M27Utilities.GetDistanceBetweenPositions(tStart, tEnd)) - 1 do
        if not(iStartingGroup == GetSegmentGroupOfLocation(sPathing, M27Utilities.MoveInDirection(tStart, iAngle, iCurPoint, true))) then
            return false
        end
    end
    return true
end

function IsEnemyStartPositionValid(aiBrain, tEnemyBase)
    --local iAirSegmentX, iAirSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(tEnemyBase)
    --Have we had sight of the enemy start position in the last 6 mins?
    if M27AirOverseer.GetTimeSinceLastScoutedLocation(aiBrain, tEnemyBase) <= 360 then
        --Are there any enemy structures within 50 of the base?
        local tEnemyStructures = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, tEnemyBase, 50, 'Enemy')
        if M27Utilities.IsTableEmpty(tEnemyStructures) then
            return false
        end
    end
    return true
end

function GetOppositeLocation(tLocation)
    --Returns a point on the opposite side of the map to tLocation
    local tOpposite = {rMapPlayableArea[3] - tLocation[1] + rMapPlayableArea[1], 0, rMapPlayableArea[4] - tLocation[3] + rMapPlayableArea[2]}
    tOpposite[2] = GetSurfaceHeight(tOpposite[1], tOpposite[3])
    return tOpposite
end

function UpdateNewPrimaryBaseLocation(aiBrain)
    --Updates reftPrimaryEnemyBaseLocation to the nearest enemy start position (unless there are no structures there in which case it searches for a better start position)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateNewPrimaryBaseLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --local refiTimeOfLastUpdate = 'M27RefTimeOfLastLocationUpdate'
    --LOG('UpdateNewPrimaryBaseLocation: aiBrain='..aiBrain:GetArmyIndex()..'; Start position='..(aiBrain.M27StartPositionNumber or 'nil'))
    if not(M27Logic.IsCivilianBrain(aiBrain)) and not(aiBrain.M27IsDefeated) and not(aiBrain:IsDefeated()) then
        local tPrevPosition
        if aiBrain[reftPrimaryEnemyBaseLocation] then tPrevPosition = {aiBrain[reftPrimaryEnemyBaseLocation][1], aiBrain[reftPrimaryEnemyBaseLocation][2], aiBrain[reftPrimaryEnemyBaseLocation][3]} end

        if aiBrain[M27Overseer.refbNoEnemies] then
            local tFriendlyBrainStartPoints = {}
            local iFriendlyBrainCount = 1
            tFriendlyBrainStartPoints[iFriendlyBrainCount] = {PlayerStartPoints[aiBrain.M27StartPositionNumber][1], PlayerStartPoints[aiBrain.M27StartPositionNumber][2], PlayerStartPoints[aiBrain.M27StartPositionNumber][3]}
            if bDebugMessages == true then LOG(sFunctionRef..': Have no enemies, so will get average of friendly brain start points provided not the centre of the map. Is table of ally brains empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27Overseer.toAllyBrains]))) end

            local bUseOurStart = false



            if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.toAllyBrains]) == false then
                for iBrain, oBrain in aiBrain[M27Overseer.toAllyBrains] do
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering ally brain index='..oBrain:GetArmyIndex()..'; Nickname='..(oBrain.Nickname or 'nil')..'; Start point='..repru((PlayerStartPoints[oBrain.M27StartPositionNumber] or {'nil'}))) end
                    if not(oBrain == aiBrain) then
                        iFriendlyBrainCount = iFriendlyBrainCount + 1
                        tFriendlyBrainStartPoints[iFriendlyBrainCount] = {PlayerStartPoints[oBrain.M27StartPositionNumber][1], PlayerStartPoints[oBrain.M27StartPositionNumber][2], PlayerStartPoints[oBrain.M27StartPositionNumber][3]}
                    end
                end
                local tAverageTeamPosition = M27Utilities.GetAverageOfLocations(tFriendlyBrainStartPoints)
                if bDebugMessages == true then LOG(sFunctionRef..': iFriendlyBrainCount='..iFriendlyBrainCount..'; Friendly brain start points='..repru((tFriendlyBrainStartPoints or {'nil'}))..'; tAverageTeamPosition='..repru(tAverageTeamPosition)..'; rMapPlayableArea='..repru(rMapPlayableArea)) end

                if M27Utilities.GetDistanceBetweenPositions(tAverageTeamPosition, {rMapPlayableArea[1] + (rMapPlayableArea[3] - rMapPlayableArea[1])*0.5, 0, rMapPlayableArea[2] + (rMapPlayableArea[4] - rMapPlayableArea[2])*0.5}) > 50 then
                    --Average isnt really close to middle of the map, so assume enemy base is in the opposite direction to average
                    aiBrain[reftPrimaryEnemyBaseLocation] = GetOppositeLocation(tAverageTeamPosition)
                else
                    --Average is really close to mid of map, so assume enemy base is in opposite directino to our start
                    bUseOurStart = true
                end
            else
                bUseOurStart = true
            end
            if bUseOurStart then
                aiBrain[reftPrimaryEnemyBaseLocation] = GetOppositeLocation(PlayerStartPoints[aiBrain.M27StartPositionNumber])
            end
        else
            local tEnemyBase = PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]
            --Is this different from the current location we are using?
            if not(tEnemyBase[1] == aiBrain[reftPrimaryEnemyBaseLocation][1]) or not(tEnemyBase[3] == aiBrain[reftPrimaryEnemyBaseLocation][3]) then aiBrain[refiLastTimeCheckedEnemyBaseLocation] = -1000 end
            aiBrain[reftPrimaryEnemyBaseLocation] = {tEnemyBase[1], tEnemyBase[2], tEnemyBase[3]} --Default
            if aiBrain.M27AI then
                --Consider if we want to check for alternative locations to the actual enemy start:
                --Have we recently checked for a base location; --Do we have at least T2 (as a basic guide that this isn't the start of the game), has at least 3m of gametime elapsed, and have scouted the enemy base location recently, and have built at least 1 air scout this game?
                if GetGameTimeSeconds() - (aiBrain[refiLastTimeCheckedEnemyBaseLocation] or -1000) >= 10 and GetGameTimeSeconds() >= 180 then
                    --(below includes alternative condition just in case there are strange unit restrictions)
                    if (aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 2 and not(M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryAirScout, 2))) or (M27Utilities.IsTableEmpty(ScenarioInfo.Options.RestrictedCategories) == false and GetGameTimeSeconds() >= 600) then
                        if not(IsEnemyStartPositionValid(aiBrain, tEnemyBase)) then
                            aiBrain[reftPrimaryEnemyBaseLocation] = nil
                            local iNearestEnemyBase = 10000
                            local tNearestEnemyBase
                            --Cycle through every valid enemy brain and pick the nearest one, if there is one
                            if bDebugMessages == true then LOG(sFunctionRef..': Will cycle through each brain to identify nearest enemy base') end
                            for iCurBrain, brain in ArmyBrains do
                                if not(brain == aiBrain) and not(M27Logic.IsCivilianBrain(brain)) and IsEnemy(brain:GetArmyIndex(), aiBrain:GetArmyIndex()) and (not(brain:IsDefeated() and not(brain.M27IsDefeated)) or not(ScenarioInfo.Options.Victory == "demoralization")) then
                                    if M27Utilities.GetDistanceBetweenPositions(PlayerStartPoints[brain.M27StartPositionNumber], PlayerStartPoints[aiBrain.M27StartPositionNumber]) < iNearestEnemyBase then
                                        if IsEnemyStartPositionValid(aiBrain, PlayerStartPoints[brain.M27StartPositionNumber]) then
                                            iNearestEnemyBase = M27Utilities.GetDistanceBetweenPositions(PlayerStartPoints[brain.M27StartPositionNumber], PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                            tNearestEnemyBase = {PlayerStartPoints[brain.M27StartPositionNumber][1], PlayerStartPoints[brain.M27StartPositionNumber][2], PlayerStartPoints[brain.M27StartPositionNumber][3]}
                                        end
                                    end
                                end
                            end
                            aiBrain[reftPrimaryEnemyBaseLocation] = tNearestEnemyBase
                            if not(aiBrain[reftPrimaryEnemyBaseLocation]) then
                                local tiCategoriesToConsider = {M27UnitInfo.refCategoryExperimentalStructure + M27UnitInfo.refCategorySML + M27UnitInfo.refCategoryFixedT3Arti, M27UnitInfo.refCategoryT3Mex, M27UnitInfo.refCategoryT2Mex, M27UnitInfo.refCategoryAirFactory + M27UnitInfo.refCategoryLandFactory}
                                local tEnemyUnits
                                tNearestEnemyBase = nil
                                for iRef, iCategory in tiCategoriesToConsider do
                                    tEnemyUnits = aiBrain:GetUnitsAroundPoint(iCategory, PlayerStartPoints[aiBrain.M27StartPositionNumber], 10000, 'Enemy')
                                    if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                                        tNearestEnemyBase = M27Utilities.GetNearestUnit(tEnemyUnits, PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain, nil, nil):GetPosition()
                                        break
                                    end
                                end
                                if tNearestEnemyBase then aiBrain[reftPrimaryEnemyBaseLocation] = tNearestEnemyBase
                                else
                                    --Cant find anywhere so just pick the furthest away enemy start location
                                    iNearestEnemyBase = 10000
                                    for iCurBrain, brain in ArmyBrains do
                                        if not(brain == aiBrain) and not(M27Logic.IsCivilianBrain(brain)) and IsEnemy(brain:GetArmyIndex(), aiBrain:GetArmyIndex()) then
                                            if M27Utilities.GetDistanceBetweenPositions(PlayerStartPoints[brain.M27StartPositionNumber], PlayerStartPoints[aiBrain.M27StartPositionNumber]) < iNearestEnemyBase then
                                                iNearestEnemyBase = M27Utilities.GetDistanceBetweenPositions(PlayerStartPoints[brain.M27StartPositionNumber], PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                                tNearestEnemyBase = {PlayerStartPoints[brain.M27StartPositionNumber][1], PlayerStartPoints[brain.M27StartPositionNumber][2], PlayerStartPoints[brain.M27StartPositionNumber][3]}
                                            end
                                        end
                                    end
                                    aiBrain[reftPrimaryEnemyBaseLocation] = tNearestEnemyBase
                                end
                            end
                        end
                    end
                end
            end
        end
        --Have we changed position and are dealing with an M27 brain?
        if aiBrain.M27AI and not(tPrevPosition[1] == aiBrain[reftPrimaryEnemyBaseLocation][1] and tPrevPosition[3] == aiBrain[reftPrimaryEnemyBaseLocation][3]) then
            --We have changed position so update any global variables that reference this
            if bDebugMessages == true then LOG(sFunctionRef..': Will update whether we can path to enemy') end
            ForkThread(SetWhetherCanPathToEnemy, aiBrain)
        end
    elseif bDebugMessages == true then LOG(sFunctionRef..': Dealing with a civilian brain')
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, primary enemy base location='..repru(aiBrain[reftPrimaryEnemyBaseLocation])) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetPrimaryEnemyBaseLocation(aiBrain)
    --Returns a table {x,y,z} - usually this is the start position of the nearest enemy base.  However in certain cases it will be different
    --Used as the main location for the AI to evaluate things such as threats and make decisions; by default will be the nearest enemy start position

    --Done as a function so easier to adjust in the future if decide we want to
    if not(aiBrain[reftPrimaryEnemyBaseLocation]) then UpdateNewPrimaryBaseLocation(aiBrain) end
    return aiBrain[reftPrimaryEnemyBaseLocation]
end

function GetMidpointToPrimaryEnemyBase(aiBrain)
    return aiBrain[reftMidpointToPrimaryEnemyBase]
end

function ReRecordUnitsAndPlatoonsInPlateaus(aiBrain)
    --Updates aiBrain[reftOurPlateauInformation] manually
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReRecordUnitsAndPlatoonsInPlateaus'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, Brain army index='..aiBrain:GetArmyIndex()..'; GameTime='..GetGameTimeSeconds()) end

    local oFrontUnit
    local iPlateauGroup
    local sPlatoonSubref
    local sPlan
    aiBrain[reftOurPlateauInformation] = {}
    if M27Utilities.IsTableEmpty(tAllPlateausWithMexes) == false then
        --Record platoons
        for iPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
            if not(oPlatoon[M27PlatoonTemplates.refbIdlePlatoon]) then
                sPlatoonSubref = nil
                if oPlatoon[M27PlatoonUtilities.refiCurrentUnits] > 0 then
                    oFrontUnit = nil
                    if M27UnitInfo.IsUnitValid(oPlatoon[M27PlatoonUtilities.refoFrontUnit]) then
                        oFrontUnit = oPlatoon[M27PlatoonUtilities.refoFrontUnit]
                    else
                        for iUnit, oUnit in oPlatoon[M27PlatoonUtilities.reftCurrentUnits] do
                            if M27UnitInfo.IsUnitValid(oUnit) then
                                oFrontUnit = oUnit
                                break
                            end
                        end
                    end
                    if oFrontUnit then
                        iPlateauGroup = GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oFrontUnit:GetPosition())
                        oPlatoon[M27Transport.refiAssignedPlateau] = iPlateauGroup
                        if not(iPlateauGroup == aiBrain[refiOurBasePlateauGroup]) then
                            sPlan = oPlatoon:GetPlan()
                            if sPlan == 'M27PlateauLandCombat' then
                                sPlatoonSubref = subrefPlateauLandCombatPlatoons
                            elseif sPlan == 'M27PlateauIndirect' then
                                sPlatoonSubref = subrefPlateauIndirectPlatoons
                            elseif sPlan == 'M27PlateauMAA' then
                                sPlatoonSubref = subrefPlateauMAAPlatoons
                            elseif sPlan == 'M27PlateauScout' then
                                sPlatoonSubref = subrefPlateauScoutPlatoons
                            else
                                --Not sure want to add a pathing check due to the risk of an infinite loop/massive slowdown
                                M27Utilities.ErrorHandler('Couldnt identify a plateau plan for the platoon, so will ignore from record of plateau units')
                                if bDebugMessages == true then LOG(sFunctionRef..': Platoon ref='..sPlan..oPlatoon[M27PlatoonUtilities.refiPlatoonCount]..'; aiBrain[refiOurBasePlateauGroup]='..aiBrain[refiOurBasePlateauGroup]) end
                            end
                        end
                        if sPlatoonSubref then
                            if M27Utilities.IsTableEmpty(aiBrain[reftOurPlateauInformation][iPlateauGroup]) then aiBrain[reftOurPlateauInformation][iPlateauGroup] = {} end
                            if M27Utilities.IsTableEmpty(aiBrain[reftOurPlateauInformation][iPlateauGroup][sPlatoonSubref]) then aiBrain[reftOurPlateauInformation][iPlateauGroup][sPlatoonSubref] = {} end
                            aiBrain[reftOurPlateauInformation][iPlateauGroup][sPlatoonSubref][sPlan..oPlatoon[M27PlatoonUtilities.refiPlatoonCount]] = oPlatoon
                        end
                    end
                end
            end
        end

        --Record plateau engineers
        local tEngineers = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryEngineer, false, true)
        local bInSamePlateau
        if M27Utilities.IsTableEmpty(tEngineers) == false then
            for iEngineer, oEngineer in tEngineers do
                bInSamePlateau = false
                iPlateauGroup = GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oEngineer:GetPosition())
                if not(oEngineer:IsUnitState('Attached')) and not(oEngineer[M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionLoadOnTransport) then
                    oEngineer[M27Transport.refiAssignedPlateau] = iPlateauGroup
                end
                if oEngineer[M27Transport.refiAssignedPlateau] and not(oEngineer[M27Transport.refiAssignedPlateau] == aiBrain[refiOurBasePlateauGroup]) then
                    if M27Utilities.IsTableEmpty(aiBrain[reftOurPlateauInformation][iPlateauGroup]) then aiBrain[reftOurPlateauInformation][iPlateauGroup] = {} end
                    if M27Utilities.IsTableEmpty(aiBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauEngineers]) then aiBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauEngineers] = {} end
                    aiBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauEngineers][M27EngineerOverseer.GetEngineerUniqueCount(oEngineer)] = oEngineer
                end
            end
        end

        --Record factories
        local tFactories = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryLandFactory, false, true)
        if M27Utilities.IsTableEmpty(tFactories) == false then
            for iUnit, oUnit in tFactories do
                iPlateauGroup = GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition())
                oUnit[M27Transport.refiAssignedPlateau] = iPlateauGroup
                if bDebugMessages == true then LOG(sFunctionRef..': Considering land factory '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iPlateauGroup='..iPlateauGroup..'; aiBrain[refiOurBasePlateauGroup]='..aiBrain[refiOurBasePlateauGroup]) end
                if not(iPlateauGroup == aiBrain[refiOurBasePlateauGroup]) then
                    if M27Utilities.IsTableEmpty(aiBrain[reftOurPlateauInformation][iPlateauGroup]) then aiBrain[reftOurPlateauInformation][iPlateauGroup] = {} end
                    if M27Utilities.IsTableEmpty(aiBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauLandFactories]) then aiBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauLandFactories] = {} end
                    aiBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauLandFactories][oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)] = oUnit
                end
            end
        end

        --Record mexes
        local tMexes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryMex, false, true)
        if M27Utilities.IsTableEmpty(tMexes) == false then
            for iUnit, oUnit in tMexes do
                iPlateauGroup = GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition())
                oUnit[M27Transport.refiAssignedPlateau] = iPlateauGroup
                if bDebugMessages == true then LOG(sFunctionRef..': Considering mex '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iPlateauGroup='..iPlateauGroup..'; aiBrain[refiOurBasePlateauGroup]='..aiBrain[refiOurBasePlateauGroup]) end
                if not(iPlateauGroup == aiBrain[refiOurBasePlateauGroup]) then
                    if M27Utilities.IsTableEmpty(aiBrain[reftOurPlateauInformation][iPlateauGroup]) then aiBrain[reftOurPlateauInformation][iPlateauGroup] = {} end
                    if M27Utilities.IsTableEmpty(aiBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauMexBuildings]) then aiBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauMexBuildings] = {} end
                    aiBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauMexBuildings][oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)] = oUnit
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdatePlateausToExpandTo(aiBrain, bForceRefresh, bPathingChange, oTransportRefreshingFor)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdatePlateausToExpandTo'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    --if aiBrain:GetArmyIndex() == 1 or aiBrain:GetArmyIndex() == 3 then bDebugMessages = true end

    --Records table with the amphibious pathing group of plateaus that we are interested in expanding to
    --tAllPlateausWithMexes = 'M27PlateausWithMexes' --[x] = AmphibiousPathingGroup
    --reftPlateausOfInterest = 'M27PlateausOfInterest' --[x] = Amphibious pathing group
    --refiLastPlateausUpdate = 'M27LastTimeUpdatedPlateau' --gametime that we last updated the plateaus

    --First time calling - update variables for all plateaus that require aibrain info
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code for game time of '..GetGameTimeSeconds()..' for brain '..aiBrain.Nickname..'; bForceRefresh='..tostring(bForceRefresh or false)..'; bPathingChange='..tostring(bPathingChange or false)) end
    if not(aiBrain[refiLastPlateausUpdate]) or bPathingChange then
        local iCurPathingGroup
        local tiBasePathingGroups = {}
        local sPathing = M27UnitInfo.refPathingTypeAmphibious
        for iRefBrain, oBrain in M27Overseer.tAllAIBrainsByArmyIndex do
            if not(M27Logic.IsCivilianBrain(oBrain)) then
                iCurPathingGroup = GetSegmentGroupOfLocation(sPathing, PlayerStartPoints[oBrain.M27StartPositionNumber])
                if bDebugMessages == true then LOG(sFunctionRef..': Considering brain with armyindex='..oBrain:GetArmyIndex()..'; iCurPathingGroup') end
                if not(tiBasePathingGroups[iCurPathingGroup]) then
                    tiBasePathingGroups[iCurPathingGroup] = true
                end
            end
        end
        --Record if active start position in this plateau
        for iPlateauGroup, tSubtable in tAllPlateausWithMexes do
            if bDebugMessages == true then LOG(sFunctionRef..': if iPlateauGroup'..iPlateauGroup..' contains a base pathing group then will set the flag for this to true. tiBasePathingGroups='..repru(tiBasePathingGroups)..'; tiBasePathingGroups[iPlateauGroup]='..tostring(tiBasePathingGroups[iPlateauGroup] or false)) end
            if tiBasePathingGroups[iPlateauGroup] then
                tAllPlateausWithMexes[iPlateauGroup][subrefPlateauContainsActiveStart] = true
                if bDebugMessages == true then LOG(sFunctionRef..': Have set '..iPlateauGroup..' as having an active start') end
            end
        end
    end

    if bDebugMessages == true then LOG(sFunctionRef..': bForceRefresh='..tostring((bForceRefresh or false))..'; Time since last updated plateaus of interest='..GetGameTimeSeconds() - (aiBrain[refiLastPlateausUpdate] or -100)..'; Cur gametime='..GetGameTimeSeconds()) end

    if bForceRefresh or GetGameTimeSeconds() - (aiBrain[refiLastPlateausUpdate] or -100) > 10 then
        if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains]) == false then
            M27Utilities.FunctionProfiler(sFunctionRef..'Main loop', M27Utilities.refProfilerStart)
            aiBrain[refiLastPlateausUpdate] = GetGameTimeSeconds()

            --Cycle through each plateau and check if we already control it, and if not if it is safe
            aiBrain[reftPlateausOfInterest] = {}
            if M27Utilities.IsTableEmpty(tAllPlateausWithMexes) == false then

                local iCurModDistance
                local tClosestMex
                local iCurDist
                local tStartPos = PlayerStartPoints[aiBrain.M27StartPositionNumber]
                local iClosestMexRef, iClosestMexDist
                local iClosestDangerousPlateauDist = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] --Dont want to try and go to a plateau if further away than nearest enemy if we lack intel of it
                local iClosestDangerousPlateauRef
                local tClosestDangerousPlateauMex
                local tEnemyAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, tStartPos, aiBrain[M27AirOverseer.refiMaxScoutRadius], 'Enemy')
                local tEnemyGround
                local bNearbyEnemyLand
                local sLocationRef
                local iExistingEngis
                local iExistingFactories
                local bAlreadyOwnOrAssignedPlateau
                local tAlliedUnits
                local iAlliedMexes
                local iExistingTransports
                local bCheckForAlliedUnits = false
                local sPathing = M27UnitInfo.refPathingTypeAmphibious
                local bHaveNonM27Allies = false


                for iBrain, oBrain in aiBrain[M27Overseer.toAllyBrains] do
                    if not(oBrain == aiBrain) then bCheckForAlliedUnits = true end
                    if not(oBrain.M27AI) then bHaveNonM27Allies = true end
                end

                if M27Utilities.IsTableEmpty(aiBrain[reftOurPlateauInformation]) then
                    aiBrain[reftOurPlateauInformation] = {}
                end

                if bPathingChange then ReRecordUnitsAndPlatoonsInPlateaus(aiBrain) end --This will also reset aiBrain[reftOurPlateauInformation
                for iPlateauGroup, tSubtable in tAllPlateausWithMexes do
                    if M27Utilities.IsTableEmpty(tSubtable[subrefPlateauMexes]) == false then
                        --Ignore plateaus that we already have engies or factories on

                        iExistingEngis = 0
                        iExistingFactories = 0
                        iAlliedMexes = 0
                        iExistingTransports = 0
                        bAlreadyOwnOrAssignedPlateau = false
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering plateaugroup='..iPlateauGroup..'; with '..table.getn(tSubtable[subrefPlateauMexes])..' mexes which is '..M27Utilities.GetDistanceBetweenPositions(tAllPlateausWithMexes[iPlateauGroup][subrefPlateauMidpoint], tStartPos)..' away from brain '..aiBrain.Nickname..' start position '..repru(tStartPos)..'; considering if we have friendly units in the plateau already') end

                        for iBrain, oBrain in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] do
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering brain '..oBrain.Nickname..'; is its table of plateau info empty for group '..iPlateauGroup..'='..tostring(M27Utilities.IsTableEmpty(oBrain[reftOurPlateauInformation][iPlateauGroup]))..'; is table of assigned transports empty='..tostring(M27Utilities.IsTableEmpty(oBrain[M27Transport.reftTransportsAssignedByPlateauGroup][iPlateauGroup]))) end

                            if M27Utilities.IsTableEmpty(oBrain[reftOurPlateauInformation][iPlateauGroup]) == false then
                                if bDebugMessages == true then LOG(sFunctionRef..': Is table of engineers assigned to plateau empty='..tostring(M27Utilities.IsTableEmpty(oBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauEngineers]))..'; is table of land factories empty='..tostring(M27Utilities.IsTableEmpty(oBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauLandFactories]))..'; is table of transports empty='..tostring(M27Utilities.IsTableEmpty(oBrain[M27Transport.reftTransportsAssignedByPlateauGroup][iPlateauGroup]))) end
                                if M27Utilities.IsTableEmpty(oBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauEngineers]) == false then
                                    for iEngi, oEngi in oBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauEngineers] do
                                        if bDebugMessages == true then LOG(sFunctionRef..': Considering engineer '..oEngi.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi)..'; is unit valid='..tostring(M27UnitInfo.IsUnitValid(oEngi))) end
                                        if M27UnitInfo.IsUnitValid(oEngi) then iExistingEngis = iExistingEngis + 1 end
                                    end
                                end
                                if M27Utilities.IsTableEmpty(oBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauLandFactories]) == false then
                                    for iFactory, oFactory in oBrain[reftOurPlateauInformation][iPlateauGroup][subrefPlateauLandFactories] do
                                        if M27UnitInfo.IsUnitValid(oFactory) and oFactory:GetFractionComplete() == 1 then iExistingFactories = iExistingFactories + 1 end
                                    end
                                end
                            end
                            --Do allied M27 brains other than ourselves already have transports assigned to this plateau?
                            if M27Utilities.IsTableEmpty(oBrain[M27Transport.reftTransportsAssignedByPlateauGroup][iPlateauGroup]) == false and not(oBrain == aiBrain) then
                                for iTransport, oTransport in oBrain[M27Transport.reftTransportsAssignedByPlateauGroup][iPlateauGroup] do
                                    if M27UnitInfo.IsUnitValid(oTransport) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Transport '..oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)..' owend by '..oTransport:GetAIBrain().Nickname..' is recorded as being assigned already to plateau group '..iPlateauGroup..'; oTransportRefreshingFor='..(oTransportRefreshingFor.UnitId or 'nil')..(M27UnitInfo.GetUnitLifetimeCount(oTransportRefreshingFor) or 'nil')..'; oTransport[M27AirOverseer.refbOnAssignment]='..tostring(oTransport[M27AirOverseer.refbOnAssignment] or false)) end
                                        if not(oTransport == oTransportRefreshingFor) and (not(oTransportRefreshingFor) or oTransport[M27AirOverseer.refbOnAssignment]) then
                                            iExistingTransports = iExistingTransports + 1
                                            if bDebugMessages == true then LOG(sFunctionRef..': Transport assigned here already') end
                                        end
                                    end
                                end
                            end
                        end

                        if iExistingFactories > 0 or iExistingEngis >= 2 or (iExistingEngis == 1 and tAllPlateausWithMexes[iPlateauGroup][subrefPlateauTotalMexCount] <= 4) or iExistingTransports > 0 then
                            bAlreadyOwnOrAssignedPlateau = true
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': Will draw midpoint of plateau that we think we already have covered')
                                M27Utilities.DrawLocation(tAllPlateausWithMexes[iPlateauGroup][subrefPlateauMidpoint])
                            end

                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': iExistingEngis='..iExistingEngis..'; iExistingFactories='..iExistingFactories..'; Mexes on plateau='..tAllPlateausWithMexes[iPlateauGroup][subrefPlateauTotalMexCount]..'; bAlreadyOwnOrAssignedPlateau='..tostring(bAlreadyOwnOrAssignedPlateau)) end
                        if not(bAlreadyOwnOrAssignedPlateau) then
                            --Look for non-M27 allied units on the plateau that wont have been picked up from above


                            if bCheckForAlliedUnits and bHaveNonM27Allies then
                                tAlliedUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandFactory + M27UnitInfo.refCategoryEngineer + M27UnitInfo.refCategoryMex, tSubtable[subrefPlateauMidpoint], tSubtable[subrefPlateauMaxRadius], 'Ally')
                                if M27Utilities.IsTableEmpty(tAlliedUnits) == false then
                                    for iUnit, oUnit in tAlliedUnits do
                                        --Is it an allied unit not our own?
                                        if oUnit:GetFractionComplete() == 1 and not(oUnit:GetAIBrain().M27AI) and GetSegmentGroupOfLocation(sPathing, oUnit:GetPosition()) == iPlateauGroup then
                                            if EntityCategoryContains(M27UnitInfo.refCategoryMex, oUnit.UnitId) then
                                                iAlliedMexes = iAlliedMexes + 1
                                            elseif EntityCategoryContains(M27UnitInfo.refCategoryLandFactory, oUnit.UnitId) then
                                                iExistingFactories = iExistingFactories + 1
                                            else iExistingEngis = iExistingEngis + 1
                                            end
                                        end
                                    end
                                    if iExistingFactories > 0 or iExistingEngis >= 2 or (iExistingEngis == 1 and tAllPlateausWithMexes[iPlateauGroup][subrefPlateauTotalMexCount] <= 4) or iAlliedMexes >= tAllPlateausWithMexes[iPlateauGroup][subrefPlateauTotalMexCount] * 0.75 then
                                        bAlreadyOwnOrAssignedPlateau = true
                                    end
                                end
                            end

                            if bDebugMessages == true then LOG(sFunctionRef..': Finished checking for allied units on the plateau, bAlreadyOwnOrAssignedPlateau='..tostring(bAlreadyOwnOrAssignedPlateau)) end

                            if not(bAlreadyOwnOrAssignedPlateau) then
                                --Ignore plateaus that contain an enemy base
                                if bDebugMessages == true then LOG(sFunctionRef..': Will ignore plateaus containing an active start point. tSubtable[subrefPlateauContainsActiveStart]='..tostring(tSubtable[subrefPlateauContainsActiveStart])) end
                                if not(tSubtable[subrefPlateauContainsActiveStart]) then
                                    --Is the location safe? First check if the nearest mex is closer than the nearest enemy threat
                                    if M27Utilities.IsTableEmpty (aiBrain[reftOurPlateauInformation][iPlateauGroup]) then
                                        aiBrain[reftOurPlateauInformation][iPlateauGroup] = {}
                                    end

                                    iClosestMexDist = 10000
                                    for iMex, tMex in tSubtable[subrefPlateauMexes] do
                                        iCurDist = M27Utilities.GetDistanceBetweenPositions(tMex, tStartPos)
                                        if iCurDist < iClosestMexDist then
                                            iClosestMexDist = iCurDist
                                            iClosestMexRef = iMex
                                        end
                                    end


                                    tClosestMex = tSubtable[subrefPlateauMexes][iClosestMexRef]

                                    iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tClosestMex, false)
                                    if bDebugMessages == true then LOG(sFunctionRef..': Considering if nearest threat is too close to risk sending transport. aiBrain[M27Overseer.refiModDistFromStartNearestThreat]='..aiBrain[M27Overseer.refiModDistFromStartNearestThreat]..'; iCurModDistance='..(iCurModDistance or 'nil')..'; will allow a threshold above this.  Will also allow if have radar coverage of the plateau.  Have radar coverage='..tostring(M27Logic.GetIntelCoverageOfPosition(aiBrain, tClosestMex, nil, true))) end
                                    --Are we outside norush range?
                                    if not(bNoRushActive) or M27Utilities.GetDistanceBetweenPositions(tClosestMex, aiBrain[reftNoRushCentre]) <= iNoRushRange then

                                        --Is there any enemy AA in range of this mex?
                                        local bIgnoreEnemies = false
                                        if ((M27Team.tTeamData[aiBrain.M27Team][M27Team.reftTimeOfTransportLastLocationAttempt][sLocationRef] or 0) == 0 and iCurModDistance <= math.max(175, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.25)) then bIgnoreEnemies = true end
                                        if bDebugMessages == true then LOG(sFunctionRef..': Is target position for closest mex covered by AA='..tostring(M27AirOverseer.IsTargetPositionCoveredByAA(tClosestMex, tEnemyAA, tStartPos, false))) end
                                        if bIgnoreEnemies or not (M27AirOverseer.IsTargetPositionCoveredByAA(tClosestMex, tEnemyAA, tStartPos, false)) then
                                            bNearbyEnemyLand = false
                                            tEnemyGround = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, tClosestMex, 100, 'Enemy')
                                            if M27Utilities.IsTableEmpty(tEnemyGround) == false then
                                                for iEnemy, oEnemy in tEnemyGround do
                                                    if GetSegmentGroupOfLocation(sPathing, tClosestMex) == iPlateauGroup then
                                                        bNearbyEnemyLand = true
                                                        break
                                                    end
                                                end
                                            end
                                            if bDebugMessages == true then LOG(sFunctionRef..': bNearbyEnemyLand='..tostring(bNearbyEnemyLand)) end
                                            if bIgnoreEnemies or not (bNearbyEnemyLand) then
                                                --Have we tried targeting this mex recently?
                                                sLocationRef = M27Utilities.ConvertLocationToStringRef(tClosestMex)
                                                if bDebugMessages == true then LOG(sFunctionRef..': Time since we last tried targeting this mex='..GetGameTimeSeconds() - (M27Team.tTeamData[aiBrain.M27Team][M27Team.reftTimeOfTransportLastLocationAttempt][sLocationRef] or -300)) end
                                                if GetGameTimeSeconds() - (M27Team.tTeamData[aiBrain.M27Team][M27Team.reftTimeOfTransportLastLocationAttempt][sLocationRef] or -300) >= 300 then
                                                    --Add to shortlist of locations to try and expand to; either the 'dangerous' shortlist if no intel and far away mod distance, or both shortlists
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Add to shortlist of locations, either dangerous or both; iCurModDistance='..iCurModDistance..'; nearest threat from start='..aiBrain[M27Overseer.refiModDistFromStartNearestThreat]..'; have Intel coverage of mex='..tostring(M27Logic.GetIntelCoverageOfPosition(aiBrain, tClosestMex, nil, true))) end
                                                    if iCurModDistance <= (aiBrain[M27Overseer.refiModDistFromStartNearestThreat] + 60) or M27Logic.GetIntelCoverageOfPosition(aiBrain, tClosestMex, nil, true) then
                                                        aiBrain[reftPlateausOfInterest][iPlateauGroup] = tClosestMex
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Recorded plateau '..iPlateauGroup..'; in plateaus of interest') end
                                                    end
                                                    if iCurModDistance <= iClosestDangerousPlateauDist then
                                                        iClosestDangerousPlateauDist = iCurModDistance
                                                        iClosestDangerousPlateauRef = iPlateauGroup
                                                        tClosestDangerousPlateauMex = {tClosestMex[1], tClosestMex[2], tClosestMex[3]}
                                                    end
                                                end
                                            end
                                        elseif bDebugMessages == true then LOG(sFunctionRef..': Enemy AA is covering the closest mex, at position '..repru(tClosestMex)..'; size of tEnemyAA='..table.getn(tEnemyAA))
                                        end
                                    end

                                end
                            end
                        end
                    end
                end

                --If plateau table is empty but we have a transport then record the closest dangerous plateau
                if M27Utilities.IsTableEmpty(aiBrain[reftPlateausOfInterest]) and iClosestDangerousPlateauRef and M27Conditions.GetLifetimeBuildCount(aiBrain, M27UnitInfo.refCategoryTransport) == 1 then
                    aiBrain[reftPlateausOfInterest][iClosestDangerousPlateauRef] = tClosestDangerousPlateauMex
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Finished determining all plateaus of interest.  Will cycle through them and list them out (but not full repr due to units potentially being in here. Is table empty='..tostring(aiBrain[reftPlateausOfInterest]))
                    if M27Utilities.IsTableEmpty(aiBrain[reftPlateausOfInterest]) == false then
                        for iPlateauGroup, tSubtable in aiBrain[reftPlateausOfInterest] do
                            LOG(sFunctionRef..': iPlateauGroup='..iPlateauGroup)
                        end
                    end
                end
            end
            M27Utilities.FunctionProfiler(sFunctionRef..'Main loop', M27Utilities.refProfilerEnd)
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RefreshPlateauPlatoons(aiBrain, iPlateauGroup)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --set to true for certain positions where want logs to print
    local sFunctionRef = 'RefreshPlateauPlatoons'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tsPlatoonRefs = { subrefPlateauLandCombatPlatoons, subrefPlateauIndirectPlatoons, subrefPlateauMAAPlatoons, subrefPlateauScoutPlatoons }
    for iRef, sRef in tsPlatoonRefs do
        if M27Utilities.IsTableEmpty(aiBrain[reftOurPlateauInformation][iPlateauGroup][sRef]) == false then
            for iPlatoon, oPlatoon in aiBrain[reftOurPlateauInformation][iPlateauGroup][sRef] do
                if not (aiBrain:PlatoonExists(oPlatoon)) then
                    aiBrain[reftOurPlateauInformation][iPlateauGroup][sRef][iRef] = nil
                end
            end
        end
    end
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --set to true for certain positions where want logs to print
    local sFunctionRef = 'RecordThatWeWantToUpdateReclaimAtLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end


function GetModChokepointDistance(aiBrain, tTarget)
    --Returns the position along the line from team start to enemy start that was used for chokepoints based on a right angle intersection from this line to tTarget
    local tStartPos = M27Team.tTeamData[aiBrain.M27Team][reftChokepointTeamStart]
    return math.floor(math.cos(math.abs(M27Utilities.ConvertAngleToRadians(M27Utilities.GetAngleFromAToB(tStartPos, tTarget) - M27Team.tTeamData[aiBrain.M27Team][reftAngleFromTeamStartToEnemy]))) * M27Utilities.GetDistanceBetweenPositions(tStartPos, tTarget))
end

function IdentifyTeamChokepoints(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --set to true for certain positions where want logs to print
    local sFunctionRef = 'IdentifyTeamChokepoints'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if not(M27Team.tTeamData[aiBrain.M27Team][refbConsideredChokepointsForTeam]) then
        if bDebugMessages == true then LOG(sFunctionRef..': Considering chokepoints for aiBrain army index='..aiBrain:GetArmyIndex()..' with M27Team='..(aiBrain.M27Team or 'nil')..'; Total team count='..(M27Team.iTotalTeamCount or 'nil')..'; can path to enemy base ='..tostring(aiBrain[refbCanPathToEnemyBaseWithLand] or false)..'; Starting segment group for land ='..(aiBrain[refiStartingSegmentGroup][M27UnitInfo.refPathingTypeLand] or 'nil')..'; starting segment if recalculate='..GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, PlayerStartPoints[aiBrain.M27StartPositionNumber])) end
        M27Team.tTeamData[aiBrain.M27Team][refbConsideredChokepointsForTeam] = true
        if M27Team.iTotalTeamCount == 2 and aiBrain[refbCanPathToEnemyBaseWithLand] then --Dont want to try turtling up if have 3+ teams as gets too complicated to try and identify a chokepoint that protects from all enemies
            local tAllM27TeamStartPoints = {}
            local tAllEnemyStartPoints = {}
            local iFriendlyM27AI = 0
            local iEnemyCount = 0
            local iLandPathingGroupWanted = (aiBrain[refiStartingSegmentGroup][M27UnitInfo.refPathingTypeLand] or GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, PlayerStartPoints[aiBrain.M27StartPositionNumber]))
            local iOurAngleToNearestEnemy = M27Utilities.GetAngleFromAToB(PlayerStartPoints[aiBrain.M27StartPositionNumber], GetPrimaryEnemyBaseLocation(aiBrain))
            local iAngleToNearestEnemy
            local bPlayersAreGroupedTogether = true
            local iCurBrainAngleToEnemy

            --Get all friendly M27AI (including htis one) who are in the same land pathing group and on a similar part of the map
            for iBrain, oBrain in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] do
                if not(oBrain:IsDefeated()) and not(oBrain.M27IsDefeated) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering oBrain with index='..oBrain:GetArmyIndex()..'; .M27AI='..tostring(oBrain.M27AI or false)..'; pathing group='..GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, PlayerStartPoints[oBrain.M27StartPositionNumber])..'; land pathing group='..GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, PlayerStartPoints[oBrain.M27StartPositionNumber])..'; iLandPathingGroupWanted='..iLandPathingGroupWanted) end
                    if bPlayersAreGroupedTogether and GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, PlayerStartPoints[oBrain.M27StartPositionNumber]) == iLandPathingGroupWanted then
                        iAngleToNearestEnemy = M27Utilities.GetAngleFromAToB(PlayerStartPoints[oBrain.M27StartPositionNumber], GetPrimaryEnemyBaseLocation(oBrain))
                        if bDebugMessages == true then LOG(sFunctionRef..': iAngleToNearestEnemy='..iAngleToNearestEnemy..'; iOurAngleToNearestEnemy='..iOurAngleToNearestEnemy) end
                        if M27Utilities.GetAngleDifference(iAngleToNearestEnemy, iOurAngleToNearestEnemy) > 90 then
                            bPlayersAreGroupedTogether = false
                            break
                        else
                            for iEnemyBrain, oEnemyBrain in oBrain[M27Overseer.toEnemyBrains] do
                                iCurBrainAngleToEnemy = M27Utilities.GetAngleFromAToB(PlayerStartPoints[oBrain.M27StartPositionNumber], PlayerStartPoints[oEnemyBrain.M27StartPositionNumber])
                                if bDebugMessages == true then LOG(sFunctionRef..': Considering oEnemyBrain='..oEnemyBrain:GetArmyIndex()..'; Angle from our start to their start='..iCurBrainAngleToEnemy..'; iAngleToNearestEnemy='..iAngleToNearestEnemy..'; M27Utilities.GetAngleDifference(iAngleToNearestEnemy, iCurBrainAngleToEnemy)='..M27Utilities.GetAngleDifference(iAngleToNearestEnemy, iCurBrainAngleToEnemy)) end
                                if M27Utilities.GetAngleDifference(iAngleToNearestEnemy, iCurBrainAngleToEnemy) > 135 then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Dif in angles for enemy brains is too great, treating players as not grouped together') end
                                    bPlayersAreGroupedTogether = false
                                    break
                                end
                            end
                            if not(bPlayersAreGroupedTogether) then break end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': bPlayersAreGroupedTogether='..tostring(bPlayersAreGroupedTogether)) end

                        if bPlayersAreGroupedTogether then --redundancy
                            iFriendlyM27AI = iFriendlyM27AI + 1
                            tAllM27TeamStartPoints[iFriendlyM27AI] = {PlayerStartPoints[oBrain.M27StartPositionNumber][1], PlayerStartPoints[oBrain.M27StartPositionNumber][2], PlayerStartPoints[oBrain.M27StartPositionNumber][3]}
                        end
                    end
                else
                    M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains][iBrain] = nil
                end
            end

            if bDebugMessages == true then LOG(sFunctionRef..': bPlayersAreGroupedTogether='..tostring(bPlayersAreGroupedTogether)..'; iFriendlyM27AI='..iFriendlyM27AI) end

            if bPlayersAreGroupedTogether then

                for iBrain, oBrain in aiBrain[M27Overseer.toEnemyBrains] do
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': Considering brain '..oBrain.Name..' with index='..oBrain:GetArmyIndex()..'; Start position number='..(oBrain.M27StartPositionNumber or 'nil')..'; Start point='..repru(PlayerStartPoints[oBrain.M27StartPositionNumber])..'; pathing group='..GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, PlayerStartPoints[oBrain.M27StartPositionNumber])..'; land pathing group='..GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, PlayerStartPoints[oBrain.M27StartPositionNumber])..'; iLandPathingGroupWanted='..iLandPathingGroupWanted)
                        if aiBrain[M27Overseer.refbNoEnemies] then
                            LOG(sFunctionRef..': No enemies so will draw the brain start point in Cyan')
                            M27Utilities.DrawLocation(PlayerStartPoints[oBrain.M27StartPositionNumber], nil, 6, 1000)
                        end
                    end
                    --Include all enemies who are in the same land pathing group
                    if GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, PlayerStartPoints[oBrain.M27StartPositionNumber]) == iLandPathingGroupWanted then
                        iEnemyCount = iEnemyCount + 1
                        tAllEnemyStartPoints[iEnemyCount] = {PlayerStartPoints[oBrain.M27StartPositionNumber][1], PlayerStartPoints[oBrain.M27StartPositionNumber][2], PlayerStartPoints[oBrain.M27StartPositionNumber][3]}
                        --Special logic for where no enemies and are fighting against a civilian - check points around the start position to see if any of these are in the same pathing group
                    elseif aiBrain[M27Overseer.refbNoEnemies] then
                        local tAdjustedStartPosition
                        for iAngle = 0, 360, 45 do
                            tAdjustedStartPosition = M27Utilities.MoveInDirection(PlayerStartPoints[oBrain.M27StartPositionNumber], iAngle, 30, true)
                            if GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, tAdjustedStartPosition) == iLandPathingGroupWanted then
                                iEnemyCount = iEnemyCount + 1
                                tAllEnemyStartPoints[iEnemyCount] = {tAdjustedStartPosition[1], tAdjustedStartPosition[2], tAdjustedStartPosition[3]}
                                if bDebugMessages == true then
                                    LOG(sFunctionRef..': Found valid alternative start point='..repru(tAdjustedStartPosition)..'; will draw in white')
                                    M27Utilities.DrawLocation(PlayerStartPoints[oBrain.M27StartPositionNumber], nil, 7, 1000)
                                    break
                                end
                            elseif bDebugMessages == true then
                                LOG(sFunctionRef..': tAdjustedStartPosition isnt in the same pathing group either, position='..repru(tAdjustedStartPosition)..'; will draw in red')
                                M27Utilities.DrawLocation(PlayerStartPoints[oBrain.M27StartPositionNumber], nil, 2, 1000)
                            end
                        end
                    end
                end

                if M27Utilities.IsTableEmpty(tAllM27TeamStartPoints) or M27Utilities.IsTableEmpty(tAllEnemyStartPoints) or iFriendlyM27AI == 0 then
                    M27Utilities.ErrorHandler('tAllM27TeamStartPoints or tAllEnemyStartPoints is empty or no friendly M27AI so will abort trying to find a chokepoint. Is tAllM27TeamStartPoitns empty='..tostring(M27Utilities.IsTableEmpty(tAllM27TeamStartPoints))..'; is allenemystartpoints empty='..tostring(M27Utilities.IsTableEmpty(tAllEnemyStartPoints))..'; iFriendlyM27AI='..iFriendlyM27AI)
                else
                    --Record all valid chokepoints
                    M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart] = {}


                    M27Team.tTeamData[aiBrain.M27Team][reftChokepointTeamStart] = M27Utilities.GetAverageOfLocations(tAllM27TeamStartPoints)
                    M27Team.tTeamData[aiBrain.M27Team][reftChokepointEnemyStart] = M27Utilities.GetAverageOfLocations(tAllEnemyStartPoints)

                    local tTeamStart = M27Team.tTeamData[aiBrain.M27Team][reftChokepointTeamStart]
                    local tEnemyStart = M27Team.tTeamData[aiBrain.M27Team][reftChokepointEnemyStart]
                    M27Team.tTeamData[aiBrain.M27Team][reftAngleFromTeamStartToEnemy] = M27Utilities.GetAngleFromAToB(tTeamStart, tEnemyStart)
                    local iMaxChokepointsNeeded = math.min(iFriendlyM27AI, 2)
                    local iAngleFromStartToEnd = M27Utilities.GetAngleFromAToB(tTeamStart, tEnemyStart)
                    local iDistToMidFromTeamStart = M27Utilities.GetDistanceBetweenPositions(tTeamStart, tEnemyStart) * 0.5
                    local tLineMidpoint
                    local tLineSidepoint
                    local iMaxDistAdjust = math.max(rMapPlayableArea[3] - rMapPlayableArea[1], rMapPlayableArea[4] - rMapPlayableArea[2])
                    local iFirstSamePathingLinePoint
                    local sPathing = M27UnitInfo.refPathingTypeLand
                    local bLookForSameGroup
                    local tLineStart
                    local iAngleToMoveToEdgeOfMap = iAngleFromStartToEnd - 90
                    local iAngleToMoveAlongLine = iAngleFromStartToEnd + 90
                    local iMaxPointAlongLine
                    local iIntervalToUse = 2

                    local iChokepointCount = 0
                    local iCurChokepointSize = 0
                    local iMaxChokepointSize = 125

                    local iChokepointDistFromStart

                    local iBestChokepointBuildDistModTowardsStart = 0



                    if bDebugMessages == true then LOG(sFunctionRef..': About to move along a line from start point to midpoint. tTeamStart='..repru(tTeamStart)..'; tEnemyStart='..repru(tEnemyStart)..'; iDistToMidFromTeamStart='..iDistToMidFromTeamStart..'; iIntervalToUse='..iIntervalToUse..'; iMaxChokepointsNeeded='..iMaxChokepointsNeeded..'; iAngleFromStartToEnd='..iAngleFromStartToEnd) end

                    for iDistAdjust = 0, math.floor((iDistToMidFromTeamStart - 30)/iIntervalToUse) * iIntervalToUse, iIntervalToUse do
                        iChokepointCount = 0
                        iCurChokepointSize = 0

                        tLineMidpoint = M27Utilities.MoveInDirection(tTeamStart, iAngleFromStartToEnd, iDistToMidFromTeamStart - iDistAdjust, false)
                        --Get the point at which it intersects with the map playable area at a right angle
                        tLineStart = M27Utilities.GetEdgeOfMapInDirection(tLineMidpoint, iAngleToMoveToEdgeOfMap)
                        iMaxPointAlongLine = M27Utilities.GetDistanceBetweenPositions(tLineStart, M27Utilities.GetEdgeOfMapInDirection(tLineMidpoint, iAngleToMoveAlongLine))
                        iMaxPointAlongLine = math.floor(iMaxPointAlongLine / iIntervalToUse) * iIntervalToUse

                        if bDebugMessages == true then
                            LOG(sFunctionRef..': iDistAdjust='..iDistAdjust..'; tLineStart='..repru(tLineStart)..'; iMaxPointAlongLine='..iMaxPointAlongLine..'; iIntervalToUse='..iIntervalToUse..'; Playablearea='..repru(rMapPlayableArea)..'; will draw in white')
                            --Draw the line (and all its sidepoints) in red if its at the middle of the map to help check it is working as intended
                            if iDistAdjust == 0 then M27Utilities.DrawLocation(tLineStart, nil, 7, 100) end
                        end

                        for iPointAlongLine = iIntervalToUse, iMaxPointAlongLine, iIntervalToUse do
                            iChokepointDistFromStart = math.floor(iDistToMidFromTeamStart - iDistAdjust)
                            tLineSidepoint = M27Utilities.MoveInDirection(tLineStart, iAngleToMoveAlongLine, iPointAlongLine)
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': tLineSidepoint='..repru(tLineSidepoint)..'; GetSegmentGroupOfLocation(sPathing, tLineSidepoint)='..GetSegmentGroupOfLocation(sPathing, tLineSidepoint)..'; iLandPathingGroupWanted='..iLandPathingGroupWanted..'; iCurChokepointSize='..iCurChokepointSize..'; iChokepointCount='..iChokepointCount)
                            end

                            if GetSegmentGroupOfLocation(sPathing, tLineSidepoint) == iLandPathingGroupWanted then
                                if bDebugMessages == true then M27Utilities.DrawLocation(tLineSidepoint, nil, 1, 100) end
                                if iCurChokepointSize <= 0 then
                                    iChokepointCount = iChokepointCount + 1
                                    if iChokepointCount == 1 then
                                        M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iChokepointDistFromStart] = {}
                                    end
                                    M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iChokepointDistFromStart][iChokepointCount] = {}
                                    M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iChokepointDistFromStart][iChokepointCount][subrefChokepointStart] = tLineSidepoint
                                    M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iChokepointDistFromStart][iChokepointCount][subrefChokepointMexesCovered] = 0
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef..': Found a new chokepoint, Dist='..iChokepointDistFromStart..'; iChokepointCount='..iChokepointCount..'; iDistAdjust='..iDistAdjust..'; Dist from start='..iChokepointDistFromStart..'; tLineSidepoint='..repru(tLineSidepoint)..'; will draw this point in white')
                                        M27Utilities.DrawLocation(tLineSidepoint, false, 7)
                                    end
                                end
                                iCurChokepointSize = iCurChokepointSize + iIntervalToUse
                                if iChokepointCount > iMaxChokepointsNeeded and iCurChokepointSize >= iIntervalToUse * 2 then
                                    --Clear tracking of this chokepoint
                                    M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iChokepointDistFromStart] = nil
                                    if bDebugMessages == true then LOG(sFunctionRef..': iChokepointCount='..iChokepointCount..'; Dist='..iChokepointDistFromStart..'; too many chokepoints so wont try and defend') end
                                    break
                                elseif iCurChokepointSize >= iMaxChokepointSize then --A T2 PD has a range of 50, so will cover 2 times this
                                    --Clear tracking of this chokepoint
                                    M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iChokepointDistFromStart] = nil
                                    if bDebugMessages == true then LOG(sFunctionRef..': iCurChokepointSize='..iCurChokepointSize..'; Dist='..iChokepointDistFromStart..'; too large so wont try and defend') end
                                    break
                                end
                            else
                                if bDebugMessages == true then M27Utilities.DrawLocation(tLineSidepoint, nil, 2, 100) end
                                if iChokepointCount > 0 then
                                    if iCurChokepointSize > iIntervalToUse then
                                        M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iChokepointDistFromStart][iChokepointCount][subrefChokepointEnd] = tLineSidepoint
                                        M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iChokepointDistFromStart][iChokepointCount][subrefChokepointSize] = iCurChokepointSize
                                        if bDebugMessages == true then LOG(sFunctionRef..': Reached end of chokepoint, iChokepointCount='..iChokepointCount..'; tLineSidepoint='..repru(tLineSidepoint)..'; iChokepointDistFromStart='..iChokepointDistFromStart..'; iCurChokepointSize of valid chokepoint='..iCurChokepointSize..'; M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iChokepointDistFromStart][iChokepointCount][subrefChokepointSize]='..M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iChokepointDistFromStart][iChokepointCount][subrefChokepointSize]) end
                                        iCurChokepointSize = 0
                                    elseif iCurChokepointSize > 0 then
                                        --Very small chokepoint - likely a pathing error, so ignore
                                        if iChokepointCount == 1 then
                                            M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iChokepointDistFromStart] = nil
                                        else
                                            M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iChokepointDistFromStart][iChokepointCount] = nil
                                        end
                                        if bDebugMessages == true then LOG(sFunctionRef..': Have very small chokepoint size '..iCurChokepointSize..'; iIntervalToUse='..iIntervalToUse..'; so likely pathing error, will reduce iChokepointCount '..iChokepointCount..' by 1. iCurChokepointSize='..iCurChokepointSize) end
                                        iChokepointCount = iChokepointCount - 1
                                        iCurChokepointSize = 0
                                    end
                                end
                            end
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Finished checking along the line for iDistAdjust='..iDistAdjust..'; iChokepointCount='..iChokepointCount..'; Is team data info for this dist adjust empty='..tostring(M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iChokepointDistFromStart])))
                        end
                    end

                    if bDebugMessages == true then LOG(sFunctionRef..': Finished trying all distadjust values. Is the table of choekpoints empty for all distances='..tostring(M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart]))) end
                    if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart]) == false then
                        --------------------->>>>>>>>>>>>>>>>RECORD RECLAIM<<<<<<<<<<<<<----------------------
                        --Record the closest and furthest chokepoints from team start for later reclaim checks
                        local iClosestChokepointToTeamStart = 10000
                        local iFurthestChokepointToTeamStart = 0
                        for iChokepointDistFromStart, tChokepointDetails in  M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart] do
                            if iChokepointDistFromStart > iFurthestChokepointToTeamStart then
                                iFurthestChokepointToTeamStart = iChokepointDistFromStart
                            end
                            if iChokepointDistFromStart < iClosestChokepointToTeamStart then
                                iClosestChokepointToTeamStart = iChokepointDistFromStart
                            end
                        end

                        --Calculate all relevant reclaim

                        local tAllReclaimOnMap = GetReclaimInRectangle(4, Rect(rMapPlayableArea[1], rMapPlayableArea[2], rMapPlayableArea[3], rMapPlayableArea[4]), false)
                        if bDebugMessages == true then LOG(sFunctionRef..': iClosestChokepointToTeamStart='..iClosestChokepointToTeamStart..'; iFurthestChokepointToTeamStart='..iFurthestChokepointToTeamStart..'; Map playable area='..repru(rMapPlayableArea)..'; Is all reclaim on map table empty='..tostring(M27Utilities.IsTableEmpty(tAllReclaimOnMap))) end
                        local iReclaimPointOnLine
                        local iMinChokepointDist = iClosestChokepointToTeamStart + 30
                        local iMaxChokepointDist = iFurthestChokepointToTeamStart + 50
                        local tReclaimMassValueByChokepointDistance = {}
                        if M27Utilities.IsTableEmpty(tAllReclaimOnMap) == false then
                            for iWreck, oWreck in tAllReclaimOnMap do
                                --Is it significant reclaim in the same land pathing group as the chokepoint?
                                if oWreck.MaxMassReclaim >= 50 then
                                    if iLandPathingGroupWanted == GetSegmentGroupOfLocation(sPathing, oWreck.CachePosition) then
                                        --Calculate the distance along the chokepoint line:
                                        iReclaimPointOnLine = GetModChokepointDistance(aiBrain, oWreck.CachePosition)
                                        if bDebugMessages == true then LOG(sFunctionRef..': iReclaimPointOnLine='..iReclaimPointOnLine..'; Wreck value='..oWreck.MaxMassReclaim..'; Wreck position='..repru(oWreck.CachePosition)) end
                                        if iReclaimPointOnLine >= iMinChokepointDist and iReclaimPointOnLine <= iMaxChokepointDist then
                                            --Reclaim is within the range wanted
                                            tReclaimMassValueByChokepointDistance[iReclaimPointOnLine] = (tReclaimMassValueByChokepointDistance[iReclaimPointOnLine] or 0) + oWreck.MaxMassReclaim
                                        end
                                    end
                                end
                            end
                        end

                        local tCumulativeReclaimMassValueByDistance = {}
                        for iCurReclaimChokepointDistance = iMinChokepointDist, iMaxChokepointDist do
                            tCumulativeReclaimMassValueByDistance[iCurReclaimChokepointDistance] = (tCumulativeReclaimMassValueByDistance[iCurReclaimChokepointDistance - 1] or 0) + (tReclaimMassValueByChokepointDistance[iCurReclaimChokepointDistance] or 0)
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Finished recording cumulative reclaim values by chokepoint distance. repr of table='..reprs(tCumulativeReclaimMassValueByDistance)) end



                        --------------------->>>>>>>>>>>>>>>>RECORD MEXES<<<<<<<<<<<<<----------------------
                        --Will need to update each chokepoint with details of mex number covered by it - do in one go, as could e.g. cycle through mexes, work out the distance, and then cycle through chokepoint locations and update each of them to increase mex count by 1
                        local iMexDistAlongLine
                        local iTotalDistToEnd = iDistToMidFromTeamStart * 2
                        local iDistToEnemy, iDistToStart

                        local tRelevantMexDistAlongLine = {}


                        for iMex, tMex in tMexByPathingAndGrouping[sPathing][iLandPathingGroupWanted] do
                            --if dist to enemy start point is greater than dist from start to end, and is closer to start tahn end, then is presumably behind the start point
                            iDistToEnemy = M27Utilities.GetDistanceBetweenPositions(tMex, tEnemyStart)
                            iDistToStart = M27Utilities.GetDistanceBetweenPositions(tTeamStart, tMex)
                            if iDistToEnemy > iTotalDistToEnd and iDistToStart < iDistToEnemy then
                                iMexDistAlongLine = 0
                            else
                                iMexDistAlongLine = math.cos(math.abs(M27Utilities.ConvertAngleToRadians(M27Utilities.GetAngleFromAToB(tTeamStart, tMex) - M27Utilities.GetAngleFromAToB(tTeamStart, tEnemyStart)))) * iDistToStart
                            end
                            tRelevantMexDistAlongLine[iMex] = iMexDistAlongLine

                            for iChokepointDistFromStart, tChokepointDetails in  M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart] do
                                if iChokepointDistFromStart >= iMexDistAlongLine then
                                    for iChokepointCount, tChokepointSubtables in tChokepointDetails do
                                        tChokepointSubtables[subrefChokepointMexesCovered] = tChokepointSubtables[subrefChokepointMexesCovered] + 1
                                    end
                                end
                            end
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Finished identifying all chokepoints and how many mexes they cover, will cycle through each chokepoint and list the mexes covered by it, and draw the chokepoint with a large blue circle')
                            for iChokepointDistFromStart, tChokepointDetails in  M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart] do
                                for iChokepointCount, tChokepointSubtables in tChokepointDetails do
                                    LOG(sFunctionRef..': iChokepointDistFromStart='..iChokepointDistFromStart..'; iChokepointCount='..iChokepointCount..'; Mexes covered='..tChokepointSubtables[subrefChokepointMexesCovered])
                                    M27Utilities.DrawLocation(M27Utilities.GetAverageOfLocations({ tChokepointSubtables[subrefChokepointStart], tChokepointSubtables[subrefChokepointEnd] }), nil, nil, 200, tChokepointSubtables[subrefChokepointSize])
                                end
                            end
                        end


                        --------------------->>>>>>>>>>>>>>>>CALCULATE VALUE OF CHOKEPOITN LOCATION<<<<<<<<<<<<<----------------------

                        --Decide if we want a chokepoint, and if so what chokepoint
                        local iTotalActivePlayers = 1
                        for iBrain, oBrain in aiBrain[M27Overseer.toAllyBrains] do
                            iTotalActivePlayers = iTotalActivePlayers + 1
                        end
                        for iBrain, oBrain in aiBrain[M27Overseer.toEnemyBrains] do
                            iTotalActivePlayers = iTotalActivePlayers + 1
                        end
                        local iOurShareOfMexesOnMap = table.getsize(tMexByPathingAndGrouping[sPathing][iLandPathingGroupWanted]) / iTotalActivePlayers
                        local iMinMexCoverageNeeded = math.floor(iOurShareOfMexesOnMap * 0.66)
                        local iHighestPriority = 0
                        local iCurPriority = 0
                        local iBestChokepointDistFromStart
                        local iGreatestChokepointSize
                        local iCurMexDistFromChokepoint
                        local tChokepointMidpoint
                        local iClosestDistToChokepoint

                        local iDistTowardsBaseThatWillMove

                        local iDistToMidFromChokepoint

                        if bDebugMessages == true then LOG(sFunctionRef..': iTotalActivePlayers='..iTotalActivePlayers..'; iOurShareOfMexesOnMap='..iOurShareOfMexesOnMap..'; iMinMexCoverageNeeded='..iMinMexCoverageNeeded) end
                        local iChokepointCountWeighting = math.random(2, 4) --e.g. on fields of isis, a value of 3 means will just get 1 chokepoint, 4 means will get 2.  I.e. the higher the value the less of a penalty is applied to needing a second chokepoint
                        for iChokepointDistFromStart, tChokepointDetails in  M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart] do
                            if tChokepointDetails[1][subrefChokepointMexesCovered] >= iMinMexCoverageNeeded then
                                iDistToMidFromChokepoint = iDistToMidFromTeamStart - iChokepointDistFromStart

                                --Calculate current priority
                                --iCurPriority = tChokepointDetails[1][subrefChokepointMexesCovered]
                                iCurPriority = tChokepointDetails[1][subrefChokepointMexesCovered] * iChokepointCountWeighting / (iChokepointCountWeighting + table.getn(tChokepointDetails))

                                --Increase priority for reclaim
                                iCurPriority = iCurPriority + (tCumulativeReclaimMassValueByDistance[iChokepointDistFromStart] or 0) * iChokepointCountWeighting / (250 * (iChokepointCountWeighting + table.getn(tChokepointDetails)))


                                --Reduce priority by size
                                iGreatestChokepointSize = 0
                                if bDebugMessages == true then LOG(sFunctionRef..': iChokepointDistFromStart='..iChokepointDistFromStart..'; Full table='..repru(tChokepointDetails)..'; iCurPriority based on mexes and number of chokepoints='..iCurPriority..'; number of chokepoints='..table.getn(tChokepointDetails)..'; iChokepointCountWeighting='..iChokepointCountWeighting..'; Reclaim value covered by this chokepoitn dist='..(tCumulativeReclaimMassValueByDistance[iChokepointDistFromStart] or 0)) end
                                for iChokepointCount, tChokepointSubtables in tChokepointDetails do
                                    if tChokepointSubtables[subrefChokepointSize] > iGreatestChokepointSize then iGreatestChokepointSize = tChokepointSubtables[subrefChokepointSize] end
                                    if bDebugMessages == true then LOG(sFunctionRef..': iChokepointCount='..iChokepointCount..'; tChokepointDetails[subrefChokepointSize]='..(tChokepointSubtables[subrefChokepointSize] or 'nil')..'; tChokepointSubtables='..repru(tChokepointSubtables)) end
                                end



                                --Adjust chokepoint based on if T2 PD can easily cover the chokepoint
                                if iGreatestChokepointSize <= 80 then
                                    iCurPriority = iCurPriority + 4
                                elseif iGreatestChokepointSize <= 100 then
                                    iCurPriority = iCurPriority + 3
                                else
                                    iCurPriority = iCurPriority + math.min(2.5, 2.5 * (1 - (iGreatestChokepointSize - 100) / (iMaxChokepointSize - 100)))
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': iGreatestChokepointSize='..iGreatestChokepointSize..'; iCurPriority='..iCurPriority) end

                                iDistTowardsBaseThatWillMove = 25 --Drafted for 25 If increase too much (e.g. above 40) then check the conditiosn for mexes below as it might mess up the logic
                                if iGreatestChokepointSize >= 80 then
                                    if iGreatestChokepointSize > 100 then iDistTowardsBaseThatWillMove = 0
                                    else iDistTowardsBaseThatWillMove = 10
                                    end
                                end

                                --Reduce distance towards base if means reclaim will fall out of range
                                if iDistTowardsBaseThatWillMove > 0 then
                                    local iReclaimBeforeMove = (tCumulativeReclaimMassValueByDistance[iChokepointDistFromStart] or 0)
                                    local iReclaimAfterMove
                                    if iReclaimBeforeMove > 0 then
                                        for iCurDistAdj = 1, iDistTowardsBaseThatWillMove do
                                            iReclaimAfterMove = (tCumulativeReclaimMassValueByDistance[iChokepointDistFromStart - iCurDistAdj] or 0)
                                            if bDebugMessages == true then LOG(sFunctionRef..': Considering moving towards base. iCurDistAdj='..iCurDistAdj..'; iReclaimBeforeMove='..iReclaimBeforeMove..'; iReclaimAfterMove='..iReclaimAfterMove) end
                                            if iReclaimBeforeMove - iReclaimAfterMove >= 100 then
                                                iDistTowardsBaseThatWillMove = iCurDistAdj - 1
                                                if bDebugMessages == true then LOG(sFunctionRef..': Will lose too much reclaim by moving back further so will stop with iDistTowardsBaseThatWillMove='..iDistTowardsBaseThatWillMove) end
                                                break
                                            end
                                        end
                                    end
                                end
                                if iDistToMidFromChokepoint <= 20 then iDistTowardsBaseThatWillMove = math.max(15, iDistTowardsBaseThatWillMove) end


                                if bDebugMessages == true then LOG(sFunctionRef..': iChokepointDistFromStart='..iChokepointDistFromStart..'; Finished adjusting priority for chokepoint size. iDistTowardsBaseThatWillMove='..iDistTowardsBaseThatWillMove..'; iCurPriority='..iCurPriority..'; iGreatestChokepointSize='..iGreatestChokepointSize..'; iMaxChokepointSize='..iMaxChokepointSize..'; iDistToMidFromTeamStart='..iDistToMidFromTeamStart) end


                                --Are we at least 50 from the centre of the map (so we likely will have time to upgrade and build some T2 PD before the enemy gets to us)?
                                if iDistToMidFromChokepoint  < 50 then
                                    iCurPriority = iCurPriority + 3 + (1 - (iChokepointDistFromStart / iDistToMidFromTeamStart)) * 0.4
                                else
                                    iCurPriority = iCurPriority + 2.5 * (1 - (iChokepointDistFromStart - (iDistToMidFromTeamStart - 50)) / 50)
                                end

                                if bDebugMessages == true then LOG(sFunctionRef..': iCurPriority after adjusting for dist from centre of map='..iCurPriority..'; iChokepointDistFromStart='..iChokepointDistFromStart..'; Finished adjusting priority for dist to mid. iDistToMidFromTeamStart='..iDistToMidFromTeamStart..'; iCurPriority='..iCurPriority) end

                                --Adjust for number of mexes not covered by the chokepoint that would be within T2 PD or T2 Arti range
                                for iMexRef, iMexDistFromStart in tRelevantMexDistAlongLine do
                                    if iMexDistFromStart > iChokepointDistFromStart then
                                        iClosestDistToChokepoint = 10000
                                        for iChokepointCount, tChokepointSubtables in tChokepointDetails do
                                            tChokepointMidpoint = M27Utilities.GetAverageOfLocations({ tChokepointSubtables[subrefChokepointStart], tChokepointSubtables[subrefChokepointEnd]})
                                            iCurMexDistFromChokepoint = M27Utilities.GetDistanceBetweenPositions(tMexByPathingAndGrouping[sPathing][iLandPathingGroupWanted][iMexRef], tChokepointMidpoint)
                                            if iCurMexDistFromChokepoint <  iClosestDistToChokepoint then
                                                iClosestDistToChokepoint = iCurMexDistFromChokepoint
                                            end
                                        end
                                        if iClosestDistToChokepoint <= (130 - iDistTowardsBaseThatWillMove) then
                                            if iClosestDistToChokepoint <= 5 then
                                                iCurPriority = iCurPriority + 0.75
                                            elseif iClosestDistToChokepoint <= (50 - iDistTowardsBaseThatWillMove) then
                                                iCurPriority = iCurPriority + 0.5
                                            elseif iClosestDistToChokepoint <= (65 - iDistTowardsBaseThatWillMove) then
                                                iCurPriority = iCurPriority + 0.4
                                            elseif iClosestDistToChokepoint <= (110 - iDistTowardsBaseThatWillMove) then
                                                iCurPriority = iCurPriority + 0.2
                                            else
                                                iCurPriority = iCurPriority + 0.1 --On edge of likely T2 arti range
                                            end
                                        end
                                    end
                                end

                                if bDebugMessages == true then LOG(sFunctionRef..': iCurPriority after increasing for mexes that are within range='..iCurPriority..'; Finished considering chokepoint with iChokepointDistFromStart='..iChokepointDistFromStart..'; iCurPriority='..iCurPriority..'; iHighestPriority='..iHighestPriority..'; size of chokepoint details table='..table.getn(tChokepointDetails)..'; iDistToMidFromTeamStart='..iDistToMidFromTeamStart..'; iGreatestChokepointSize='..iGreatestChokepointSize..'; iMaxChokepointSize='..iMaxChokepointSize) end
                                --Record if is the best priority
                                if iCurPriority > iHighestPriority then
                                    iHighestPriority = iCurPriority
                                    iBestChokepointDistFromStart = iChokepointDistFromStart
                                    iBestChokepointBuildDistModTowardsStart = iDistTowardsBaseThatWillMove
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have new highest priority, iChokepointDistFromStart='..iChokepointDistFromStart..'; iHighestPriority='..iHighestPriority..'; iBestChokepointBuildDistModTowardsStart='..iBestChokepointBuildDistModTowardsStart) end
                                end
                            end
                        end
                        M27Team.tTeamData[aiBrain.M27Team][tiPlannedChokepointsByDistFromStart] = {}
                        local bAbort = false
                        if not(iBestChokepointDistFromStart) or M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iBestChokepointDistFromStart]) then
                            bAbort = true
                        else
                            --------------------->>>>>>>>>>>>>>>>Decide on build locations for chokepoints and then assign to M27 AI<<<<<<<<<<<<<----------------------
                            for iChokepointCount, tChokepointSubtables in M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iBestChokepointDistFromStart] do
                                M27Team.tTeamData[aiBrain.M27Team][tiPlannedChokepointsByDistFromStart][iChokepointCount] = iBestChokepointDistFromStart

                                --Set build location (move towards start position slightly):
                                tChokepointMidpoint = M27Utilities.GetAverageOfLocations({ tChokepointSubtables[subrefChokepointStart], tChokepointSubtables[subrefChokepointEnd]})

                                --M27Team.tTeamData[aiBrain.M27Team][reftAngleFromTeamStartToEnemy] = M27Utilities.GetAngleFromAToB(tTeamStart, tEnemyStart)

                                local tBuildLocationWanted = M27Utilities.MoveInDirection(tChokepointMidpoint, M27Team.tTeamData[aiBrain.M27Team][reftAngleFromTeamStartToEnemy] - 180, iBestChokepointBuildDistModTowardsStart, true)
                                tBuildLocationWanted = M27EngineerOverseer.FindRandomPlaceToBuild(aiBrain, M27Utilities.GetACU(aiBrain), tBuildLocationWanted, 'ueb0101', 0, 4, false, 10, false, false)
                                if not(tBuildLocationWanted) then tBuildLocationWanted = M27EngineerOverseer.FindRandomPlaceToBuild(aiBrain, M27Utilities.GetACU(aiBrain), tChokepointMidpoint, 'ueb0101', 0, 4, false, 10, false, false)
                                    if not(tBuildLocationWanted) then
                                        M27Utilities.ErrorHandler('Couldnt find a valid location for the firebase, so will clear all trackers and abort trying to setup a firebase')
                                        M27Team.tTeamData[aiBrain.M27Team][tiPlannedChokepointsByDistFromStart] = nil
                                        bAbort = true
                                        break
                                    end
                                end
                                M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iBestChokepointDistFromStart][iChokepointCount][reftChokepointBuildLocation] = tBuildLocationWanted

                                if bDebugMessages == true then
                                    LOG(sFunctionRef..': iBestChokepointDistFromStart='..iBestChokepointDistFromStart..'; iChokepointCount='..iChokepointCount..'; tChokepointSubtables[subrefChokepointStart]='..repru(tChokepointSubtables[subrefChokepointStart])..'; tChokepointSubtables[subrefChokepointEnd]='..repru(tChokepointSubtables[subrefChokepointEnd])..'; average='..repru(M27Utilities.GetAverageOfLocations({ tChokepointSubtables[subrefChokepointStart], tChokepointSubtables[subrefChokepointEnd]}))..'; our base start point='..repru(PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; tChokepointMidpoint='..repru(tChokepointMidpoint)..'; tBuildLocationWanted='..repru(tBuildLocationWanted)..'; iDistToMidFromTeamStart='..iDistToMidFromTeamStart..'; tChokepointSubtables[subrefChokepointSize]='..tChokepointSubtables[subrefChokepointSize]..'; Will draw chokepoint midpoint in gold, and build location in white. iBestChokepointBuildDistModTowardsStart='..iBestChokepointBuildDistModTowardsStart)
                                    --M27Utilities.DrawLocation(M27Utilities.GetAverageOfLocations({ tChokepointSubtables[subrefChokepointStart], tChokepointSubtables[subrefChokepointEnd] }), nil, 1, 200, tChokepointSubtables[subrefChokepointSize])
                                    M27Utilities.DrawLocation(tChokepointMidpoint, nil, 4, 1000, tChokepointSubtables[subrefChokepointSize])
                                    M27Utilities.DrawLocation(M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iBestChokepointDistFromStart][iChokepointCount][reftChokepointBuildLocation], nil, 7, 1000, tChokepointSubtables[subrefChokepointSize])
                                end
                            end
                        end
                        --Assign chokepoint to M27AI
                        if not(bAbort) then
                            local iCurDist
                            local iClosestDist = 10000
                            local oClosestBrain
                            for iChokepointCount, tChokepointSubtables in M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iBestChokepointDistFromStart] do
                                iClosestDist = 10000
                                for iBrain, oBrain in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] do
                                    if not(oBrain[refiAssignedChokepointCount]) and GetSegmentGroupOfLocation(sPathing, PlayerStartPoints[oBrain.M27StartPositionNumber]) == iLandPathingGroupWanted then
                                        iCurDist = M27Utilities.GetDistanceBetweenPositions(PlayerStartPoints[oBrain.M27StartPositionNumber], tChokepointSubtables[reftChokepointBuildLocation])
                                        if bDebugMessages == true then LOG(sFunctionRef..': Looking for nearest M27 near the chokepoint at position '..repru(tChokepointSubtables[reftChokepointBuildLocation])..'; aiBrain='..aiBrain:GetArmyIndex()..'; iCurDist='..iCurDist..'; iClosestDist='..iClosestDist) end
                                        if iCurDist <= iClosestDist then
                                            iClosestDist = iCurDist
                                            oClosestBrain = oBrain
                                        end
                                    end
                                end
                                if not(oClosestBrain) then M27Utilities.ErrorHandler('no oClosestBrain')
                                else
                                    oClosestBrain[refiAssignedChokepointCount] = iChokepointCount
                                    oClosestBrain[M27Overseer.refiAIBrainCurrentStrategy] = M27Overseer.refStrategyTurtle
                                    oClosestBrain[M27Overseer.refiDefaultStrategy] = M27Overseer.refStrategyTurtle
                                    oClosestBrain[reftChokepointBuildLocation] = tChokepointSubtables[reftChokepointBuildLocation]
                                    ForkThread(M27Overseer.DetermineInitialBuildOrder, aiBrain) --Need to run again as before we set values without realising we were turtling
                                    --Make location between chokepoint and enemy base a high priority for scouting
                                    local iAirSegmentX, iAirSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(M27Utilities.MoveInDirection(oClosestBrain[reftChokepointBuildLocation], M27Utilities.GetAngleFromAToB(oClosestBrain[reftChokepointBuildLocation], tEnemyStart), 110, true))
                                    oClosestBrain[M27AirOverseer.reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][M27AirOverseer.refiNormalScoutingIntervalWanted] = math.min(oClosestBrain[M27AirOverseer.reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][M27AirOverseer.refiNormalScoutingIntervalWanted], aiBrain[M27AirOverseer.refiIntervalChokepoint])
                                end
                            end
                            --Update each team brain to record the closest chokepoint (or the assigned one if it has one assigned)
                            local iClosestChokepointRef
                            for iBrain, oBrain in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] do
                                iClosestDist = 10000
                                if not(oBrain[refiAssignedChokepointCount]) then
                                    for iChokepointCount, tChokepointSubtables in M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iBestChokepointDistFromStart] do
                                        iCurDist = M27Utilities.GetDistanceBetweenPositions(PlayerStartPoints[oBrain.M27StartPositionNumber], tChokepointSubtables[reftChokepointBuildLocation])
                                        if iCurDist < iClosestDist then
                                            iClosestChokepointRef = iChokepointCount
                                            iClosestDist = iCurDist
                                        end
                                    end
                                else
                                    iClosestChokepointRef = oBrain[refiAssignedChokepointCount]
                                end
                                oBrain[reftClosestChokepoint] = {M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iBestChokepointDistFromStart][iClosestChokepointRef][reftChokepointBuildLocation][1], M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iBestChokepointDistFromStart][iClosestChokepointRef][reftChokepointBuildLocation][2], M27Team.tTeamData[aiBrain.M27Team][tPotentialChokepointsByDistFromStart][iBestChokepointDistFromStart][iClosestChokepointRef][reftChokepointBuildLocation][3]}
                                M27Chat.SendMessage(aiBrain, 'Chokepoint assignment', 'Ill try and fortify the chokepoint near me', 10, 0, true)
                            end
                        end
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end


function GetRandomPathablePriorityMex(aiBrain, sPathing, iPathingGroupWanted)
    local tPathablePriorityMexes = {}

    if M27Utilities.IsTableEmpty(aiBrain[reftHighPriorityMexes]) == false then
        for iMex, tMex in aiBrain[reftHighPriorityMexes] do
            if GetSegmentGroupOfLocation(sPathing, tMex) == iPathingGroupWanted then
                table.insert(tPathablePriorityMexes, tMex)
            end
        end
    end
    local tPriorityMex
    if M27Utilities.IsTableEmpty(tPathablePriorityMexes) == false then
        local iCurrentMexPriorities = table.getn(tPathablePriorityMexes)
        local iMexWanted = math.random(1, iCurrentMexPriorities)
        tPriorityMex = {tPathablePriorityMexes[iMexWanted][1], tPathablePriorityMexes[iMexWanted][2], tPathablePriorityMexes[iMexWanted][3]}
    end
    return tPriorityMex

end
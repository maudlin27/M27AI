--Manages building upgrades

local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27FactoryOverseer = import('/mods/M27AI/lua/AI/M27FactoryOverseer.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27PlatoonFormer = import('/mods/M27AI/lua/AI/M27PlatoonFormer.lua')

--Tracking variables:
refbWantMoreFactories = 'M27UpgraderWantMoreFactories'

reftMassStorageLocations = 'M27UpgraderMassStorageLocations' --List of all locations where we want a mass storage to be built
reftStorageSubtableLocation = 'M27UpgraderStorageLocationSubtable'
refiStorageSubtableModDistance = 'M27UpgraderStorageModDistance'
local refbWantToUpgradeMoreBuildings = 'M27UpgraderWantToUpgradeMore'
reftUnitsToReclaim = 'M27UnitReclaimShortlist' --list of units we want engineers to reclaim
reftMexesToCtrlK = 'M27EconomyMexesToCtrlK' --Mexes that we want to destroy to rebuild with better ones
reftT2MexesNearBase = 'M27EconomyT2MexesNearBase' --Amphib pathable near base and not upgrading; NOTE - this isnt kept up to date, instead engineer will only refresh the mexes in this if its empty; for now just used by engineer overseer but makes sense to have variable in this code
refoNearestT2MexToBase = 'M27EconomyNearestT2MexToBase' --As per t2mexesnearbase
refbWillCtrlKMex = 'M27EconomyWillCtrlKMex' --true if mex is marked for ctrl-k

local reftUpgrading = 'M27UpgraderUpgrading' --[x] is the nth building upgrading, returns the object upgrading
local refiPausedUpgradeCount = 'M27UpgraderPausedCount' --Number of units where have paused the upgrade
local refbUpgradePaused = 'M27UpgraderUpgradePaused' --flags on particular unit if upgrade has been paused or not

local refiEnergyStoredLastCycle = 'M27EnergyStoredLastCycle'

--ECONOMY VARIABLES - below 4 are to track values based on base production, ignoring reclaim. Provide per tick values so 10% of per second)
refiEnergyGrossBaseIncome = 'M27EnergyGrossIncome'
refiEnergyNetBaseIncome = 'M27EnergyNetIncome'
refiMassGrossBaseIncome = 'M27MassGrossIncome'
refiMassNetBaseIncome = 'M27MassNetIncome'

refiMexesUpgrading = 'M27EconomyMexesUpgrading'
refiMexesAvailableForUpgrade = 'M27EconomyMexesAvailableToUpgrade'

refbStallingEnergy = 'M27EconomyStallingEnergy'
reftPausedUnits = 'M27EconomyPausedUnits'


--Other variables:
local refCategoryLandFactory = M27UnitInfo.refCategoryLandFactory
local refCategoryAirFactory = M27UnitInfo.refCategoryAirFactory
local refCategoryT1Mex = M27UnitInfo.refCategoryT1Mex
local refCategoryT2Mex = M27UnitInfo.refCategoryT2Mex
local refCategoryT3Mex = M27UnitInfo.refCategoryT3Mex
local refCategoryMex = M27UnitInfo.refCategoryMex
local refCategoryHydro = M27UnitInfo.refCategoryHydro
local refCategoryT1Power = M27UnitInfo.refCategoryT1Power
local refCategoryT2Power = M27UnitInfo.refCategoryT2Power
local refCategoryT3Power = M27UnitInfo.refCategoryT3Power

local reftMexOnOurSideOfMap = 'M27MexOnOurSideOfMap'
local refbPauseForPowerStall = 'M27PauseForPowerStall'

function GetMexCountOnOurSideOfMap(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetMexCountOnOurSideOfMap'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iCount = 0
    if aiBrain[reftMexOnOurSideOfMap] then iCount = table.getn(aiBrain[reftMexOnOurSideOfMap]) end
    if iCount == 0 then
        --Update/refresh the count:
        aiBrain[reftMexOnOurSideOfMap] = {}
        local tOurStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local iEnemyStartPosition = M27Logic.GetNearestEnemyStartNumber(aiBrain)
        local tEnemyStartPosition = M27MapInfo.PlayerStartPoints[iEnemyStartPosition]

        local iSegmentX, iSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tOurStartPosition)
        local oACU = M27Utilities.GetACU(aiBrain)
        local sPathing = M27UnitInfo.GetUnitPathingType(oACU)
        local iSegmentGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iSegmentX, iSegmentZ)
        local iCurDistanceToStart
        local iCurDistanceToEnemy


        --tMexByPathingAndGrouping = {} --Stores position of each mex based on the segment that it's part of; [a][b][x,y,z]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [x,y,z] = Mex position
        if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing]) == false then
            if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup]) == false then
                for iMex, tMexLocation in M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup] do
                    iCurDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tOurStartPosition, tMexLocation)
                    iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tEnemyStartPosition, tMexLocation)
                    if iCurDistanceToStart <= iCurDistanceToEnemy then
                        iCount = iCount + 1
                        aiBrain[reftMexOnOurSideOfMap][iCount] = tMexLocation
                    end
                end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Mexes on our side='..iCount) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iCount
end

function GetUnitReclaimTargets(aiBrain)
    --Prepares a shortlist of targets we want engineers to reclaim
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetUnitReclaimTargets'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    aiBrain[reftUnitsToReclaim] = {}

    local tNearbyAdjacencyUnits
    --NOTE: DONT ADD conditions above here as T2 power assumes the table is empty

    --Add any old power to the table - T1 and T2 if we have lots of power and T3
    local iT3Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Power)
    if iT3Power >= 1 and aiBrain[refiEnergyGrossBaseIncome] >= 500 then
        --Add all T2 power
        aiBrain[reftUnitsToReclaim] = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT2Power, false, true)
    end

    --Reclaim T1 power if we have T2+ power and enough gross income, unless we also have T2 arti
    if (iT3Power >= 1 or aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Power) >= 2) and aiBrain[refiEnergyGrossBaseIncome] >= 110 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryFixedT2Arti) <= 0 then
        --All T1 power
        for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT1Power, false, true) do
            --Check not near to an air factory - will do slightly larger than actual radius needed to be prudent
            tNearbyAdjacencyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirFactory, oUnit:GetPosition(), 6, 'Ally')
            if M27Utilities.IsTableEmpty(tNearbyAdjacencyUnits) == true then
                table.insert(aiBrain[reftUnitsToReclaim], oUnit)
            end
        end
    end

    local tT3Radar = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT3Radar, false, true)
    local tT2Radar = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT2Radar, false, true)
    local bRadarInsideOtherRadarRange
    --T2 radar if in range of T3
    if M27Utilities.IsTableEmpty(tT3Radar) == false and M27Utilities.IsTableEmpty(tT2Radar) == false then
        for iUnit, oUnit in tT2Radar do
            bRadarInsideOtherRadarRange = false
            for iT3Radar, oT3Radar in tT3Radar do
                if M27Utilities.GetDistanceBetweenPositions(oT3Radar:GetPosition(), oUnit:GetPosition()) <= (oT3Radar:GetBlueprint().Intel.RadarRadius - oUnit:GetBlueprint().Intel.RadarRadius) then
                    bRadarInsideOtherRadarRange = true
                    break
                end
            end
            if bRadarInsideOtherRadarRange then table.insert(aiBrain[reftUnitsToReclaim], oUnit) end
        end
    end

    --T1 radar
    if M27Utilities.IsTableEmpty(tT3Radar) == false or M27Utilities.IsTableEmpty(tT2Radar) == false then
        for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT1Radar, false, true) do
            bRadarInsideOtherRadarRange = false
            if M27Utilities.IsTableEmpty(tT3Radar) == false then
                for iT3Radar, oT3Radar in tT3Radar do
                    if M27Utilities.GetDistanceBetweenPositions(oT3Radar:GetPosition(), oUnit:GetPosition()) <= (oT3Radar:GetBlueprint().Intel.RadarRadius - oUnit:GetBlueprint().Intel.RadarRadius) then
                        bRadarInsideOtherRadarRange = true
                        break
                    end
                end
            end
            if bRadarInsideOtherRadarRange == false and M27Utilities.IsTableEmpty(tT2Radar) == false then
                for iT2Radar, oT2Radar in tT2Radar do
                    if M27Utilities.GetDistanceBetweenPositions(oT2Radar:GetPosition(), oUnit:GetPosition()) <= (oT2Radar:GetBlueprint().Intel.RadarRadius - oUnit:GetBlueprint().Intel.RadarRadius) then
                        bRadarInsideOtherRadarRange = true
                        break
                    end
                end
            end
            if bRadarInsideOtherRadarRange then table.insert(aiBrain[reftUnitsToReclaim], oUnit) end
        end
    end

    --Civilian buildings on our side of the map that can be pathed to amphibiously with no enemy units nearby
    local tCivilianBuildings = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 500, 'Neutral')
    local iBasePathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
    if M27Utilities.IsTableEmpty(tCivilianBuildings) == false then
        for iUnit, oUnit in tCivilianBuildings do
            --Are we closer to our base than enemy?
            if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]) then
                --Can we path here with an amphibious unit?
                if iBasePathingGroup == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition()) then
                    table.insert(aiBrain[reftUnitsToReclaim], oUnit)
                end
            end

        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetMassStorageTargets(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetMassStorageTargets'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Goes through all mexes and records any available locations for mass storage
    local iDistanceModForEachAdjacentMex = -60
    local iDistanceModForEachT1AdjacentMex = -35 --NOTE: If changing this value, then also update engineer overseer's threshold for ignoring a location based on difference in distance
    local iDistanceModForTech2 = 120
    local sLocationRef, tCurLocation
    local tAdjustedPosition = {}

    local tAllMexes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryMex, false, true)
    local tAllT2PlusMexes = EntityCategoryFilterDown(M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryT3Mex, tAllMexes)
    local tAllT1Mexes = EntityCategoryFilterDown(M27UnitInfo.refCategoryT1Mex, tAllMexes)
    aiBrain[reftMassStorageLocations] = {}
    local tStorageLocationsForTech1 = {} --[sLocationRef]; true if the location is by a t1 mex
    local iValidCount = 0
    local tPositionAdjustments = {
        {-2, 0},
        {2, 0},
        {0, -2},
        {0, 2},
    }

    for iT1Mex, oT1Mex in tAllT1Mexes do
        for _, tModPosition in tPositionAdjustments do
            tCurLocation = oT1Mex:GetPosition()
            tAdjustedPosition = {tCurLocation[1] + tModPosition[1], GetSurfaceHeight(tCurLocation[1] + tModPosition[1], tCurLocation[3] + tModPosition[2]), tCurLocation[3] + tModPosition[2]}
            if bDebugMessages == true then LOG(sFunctionRef..': Storage by T1Mex: tCurLocation='..repr(tCurLocation)..'; tModPosition='..repr(tModPosition)..'; adjusted position='..repr(tAdjustedPosition)) end
            sLocationRef = M27Utilities.ConvertLocationToReference(tAdjustedPosition)
            if tStorageLocationsForTech1[sLocationRef] == nil then
                tStorageLocationsForTech1[sLocationRef] = true
            end
        end
    end

    local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    local iDistanceFromOurBase, iCurPositionTechAdjust, iCurPositionStartedConstructionAdjust, iCurPositionAdjacencyAdjust
    local sStorageBP = 'ueb1106'
    local iMexesNearStart = table.getn(M27MapInfo.tResourceNearStart[aiBrain.M27StartPositionNumber][1])
    if M27Utilities.IsTableEmpty(tAllT2PlusMexes) == false then
        --Only want to consider storage if have already upgraded easy T1 mexes to T2
        local iMinSingleMexForStorage = math.min(iMexesNearStart, 6)
        local iMinDoubleMexForStorage = math.min(iMexesNearStart, 2)
        local bOnlyConsiderDoubleOrT3 = false
        local iMexesForStorage = table.getn(tAllT2PlusMexes)
        local tStorageAtLocation
        local iStorageRadius = 1
        local bStorageFinishedConstruction
        local iCurAdjustedDistance
        if iMexesForStorage >= iMinDoubleMexForStorage then
            if iMexesForStorage < iMinSingleMexForStorage then bOnlyConsiderDoubleOrT3 = true end
            for iMex, oMex in tAllT2PlusMexes do
                if not(oMex.Dead) and oMex:GetFractionComplete() >= 1 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering mex with unique ref='..oMex:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oMex)) end
                    tCurLocation = oMex:GetPosition()
                    for _, tModPosition in tPositionAdjustments do
                        tAdjustedPosition = {tCurLocation[1] + tModPosition[1], GetSurfaceHeight(tCurLocation[1] + tModPosition[1], tCurLocation[3] + tModPosition[2]), tCurLocation[3] + tModPosition[2]}
                        if bDebugMessages == true then LOG(sFunctionRef..': tCurLocation='..repr(tCurLocation)..'; tModPosition='..repr(tModPosition)..'; adjusted position='..repr(tAdjustedPosition)) end
                        sLocationRef = M27Utilities.ConvertLocationToReference(tAdjustedPosition)
                        if aiBrain:CanBuildStructureAt(sStorageBP, tAdjustedPosition) or (aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionBuildMassStorage]) == false) then
                            --Check the building hasnt finished construction
                            bStorageFinishedConstruction = false
                            if not(aiBrain:CanBuildStructureAt(sStorageBP, tAdjustedPosition)) then
                                tStorageAtLocation = GetUnitsInRect(Rect(tAdjustedPosition[1]-iStorageRadius, tAdjustedPosition[3]-iStorageRadius, tAdjustedPosition[1]+iStorageRadius, tAdjustedPosition[3]+iStorageRadius))
                                if M27Utilities.IsTableEmpty(tStorageAtLocation) == false then
                                    tStorageAtLocation = EntityCategoryFilterDown(M27UnitInfo.refCategoryMassStorage, tStorageAtLocation)
                                    if M27Utilities.IsTableEmpty(tStorageAtLocation) == false then
                                        for iUnit, oUnit in tStorageAtLocation do
                                            if oUnit:GetFractionComplete() >= 1 then bStorageFinishedConstruction = true break end
                                        end
                                    end
                                end
                            end
                            if bStorageFinishedConstruction == false then

                                --sLocationRef = M27Utilities.ConvertLocationToReference(tAdjustedPosition)
                                iDistanceFromOurBase = M27Utilities.GetDistanceBetweenPositions(tAdjustedPosition, tStartPosition)
                                iCurPositionTechAdjust = 0
                                iCurPositionStartedConstructionAdjust = 0
                                iCurPositionAdjacencyAdjust = 0
                                --Reduce distance by 100 if already have it assigned to an engineer (as want to continue existing structure)
                                if aiBrain:CanBuildStructureAt(sStorageBP, tAdjustedPosition) == false then iCurPositionStartedConstructionAdjust = -100 end
                                if EntityCategoryContains(categories.TECH2, oMex:GetUnitId()) then iCurPositionTechAdjust = iDistanceModForTech2 end
                                if bDebugMessages == true then LOG(sFunctionRef..': Can build storage at the position, so will record; sLocationRef='..sLocationRef..'; iDistanceFromOurBase='..iDistanceFromOurBase..'; iCurPositionTechAdjust='..iCurPositionTechAdjust..'; iDistanceModForEachAdjacentMex='..iDistanceModForEachAdjacentMex) end
                                if aiBrain[reftMassStorageLocations][sLocationRef] then
                                    iCurPositionAdjacencyAdjust = iDistanceModForEachAdjacentMex
                                    --[[--Already have a position, so choose the lower of it reduced by 50, or the current value reduced by 50
                                    if bDebugMessages == true then LOG(sFunctionRef..': Already have a position so will reduce current distance by iDistanceModForEachAdjacentMex='..iDistanceModForEachAdjacentMex..'; current distance='..aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance]) end

                                    aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance] = math.min(aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance] + iDistanceModForEachAdjacentMex, iDistanceFromOurBase + iCurPositionTechAdjust + iDistanceModForEachAdjacentMex + iCurPositionStartedConstructionAdjust)
                                    if bDebugMessages == true then LOG(sFunctionRef..': Distance after modification='..aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance]) end--]]
                                elseif tStorageLocationsForTech1[sLocationRef] then
                                    iCurPositionAdjacencyAdjust = iDistanceModForEachT1AdjacentMex
                                end
                                iCurAdjustedDistance = iDistanceFromOurBase + iCurPositionTechAdjust + iCurPositionAdjacencyAdjust + iCurPositionStartedConstructionAdjust
                                if aiBrain[reftMassStorageLocations][sLocationRef] then
                                    aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance] = math.min(iCurAdjustedDistance, aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance] + iCurPositionAdjacencyAdjust)
                                else
                                    aiBrain[reftMassStorageLocations][sLocationRef] = {}
                                    aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance] = iCurAdjustedDistance
                                    aiBrain[reftMassStorageLocations][sLocationRef][reftStorageSubtableLocation] = tAdjustedPosition
                                end
                            end
                        else
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': Cant build mass storage at this location')
                                M27Utilities.DrawLocation(tAdjustedPosition, nil, 3, 200)
                            end
                        end
                                        end
                end
            end
            --Now go through again and remove entries that are too far away so that we're not getting storage when we still have t1 nearby mexes to upgrade
            if bOnlyConsiderDoubleOrT3 and M27Utilities.IsTableEmpty(aiBrain[reftMassStorageLocations]) == false then
                local iMaxDistance = iDistanceModForTech2 - 1
                for iEntry, tSubtable in aiBrain[reftMassStorageLocations] do
                    if tSubtable[refiStorageSubtableModDistance] > iMaxDistance then aiBrain[reftMassStorageLocations][sLocationRef] = nil end
                end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Storage locations='..repr(aiBrain[reftMassStorageLocations])) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RefreshT2MexesNearBase(aiBrain)
    --Updates list of T2 mexes that are near to base and pathable by amphibious units, and arent upgrading, along with the varaible with the nearest one to our base
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RefreshT2MexesNearBase'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    aiBrain[reftT2MexesNearBase] = {}
    aiBrain[reftMexesToCtrlK] = {} --Not ideal that reset here, but for now hopefully the scenario where we order an engineer to ctrl-K a mex, and then change our mind about wanting to do that and it leads to the mex being upgraded is low?
    local iT2MexCount = 0
    local iT2NearBaseCount = 0
    local tAllT2Mexes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT2Mex, false, true)
    local iCurDistToBase
    local iMinDistToBase = 10000
    local iBasePathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
    aiBrain[refoNearestT2MexToBase] = nil
    if bDebugMessages == true then LOG(sFunctionRef..': Is tAllT2Mexes empty='..tostring(M27Utilities.IsTableEmpty(tAllT2Mexes))) end
    if M27Utilities.IsTableEmpty(tAllT2Mexes) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': Size of tAllT2Mexes='..table.getn(tAllT2Mexes)) end
        for iMex, oMex in tAllT2Mexes do
            if M27UnitInfo.IsUnitValid(oMex) then
                iT2MexCount = iT2MexCount + 1
                tAllT2Mexes[iT2MexCount] = oMex
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Considering mex with position='..repr(oMex:GetPosition()))
                    LOG('Player start position='..repr(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]))
                    LOG('VDist2 between these positions='..VDist2(oMex:GetPosition()[1], oMex:GetPosition()[3], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]))
                end


                iCurDistToBase = M27Utilities.GetDistanceBetweenPositions(oMex:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                if bDebugMessages == true then LOG(sFunctionRef..': Considering mex '..oMex:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oMex)..'; iCurDistanceToBase='..iCurDistToBase) end
                if iCurDistToBase <= 80 then
                    --Ignore mexes which are upgrading
                    if not(oMex:IsUnitState('Upgrading') or (oMex.GetWorkProgress and oMex:GetWorkProgress() < 1 and oMex:GetWorkProgress() > 0.01)) then
                        --Mex must be in same pathing group
                        if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oMex:GetPosition()) == iBasePathingGroup then
                            iT2NearBaseCount = iT2NearBaseCount + 1
                            aiBrain[reftT2MexesNearBase][iT2NearBaseCount] = oMex
                            if bDebugMessages == true then LOG(sFunctionRef..': Added mex to table of T2 mexes near base, iT2NearBaseCount='..iT2NearBaseCount) end
                            if iCurDistToBase < iMinDistToBase then
                                aiBrain[refoNearestT2MexToBase] = oMex
                                iMinDistToBase = iCurDistToBase
                                if bDebugMessages == true then LOG(sFunctionRef..': Mex is the current closest to base') end
                            end
                        elseif bDebugMessages == true then LOG(sFunctionRef..': Mex isnt in same pathing group')
                        end
                    elseif bDebugMessages == true then LOG(sFunctionRef..': Mex is upgrading or workprogress<1')
                    end
                end
            elseif bDebugMessages == true then LOG(sFunctionRef..': Mex isnt valid')
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, iUnitCategory)
    --Doesnt factor in if a unit is paused
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iUpgradingCount = 0
    local iAvailableToUpgradeCount = 0
    local tAllUnits = aiBrain:GetListOfUnits(iUnitCategory, false, true)
    local oUnitBP
    local bAreAlreadyUpgradingToHQ = false
    local iHighestTech = 1
    local iHighestFactoryBeingUpgraded = 0
    local iCurTech

    for iUnit, oUnit in tAllUnits do
        if not(oUnit.Dead) and oUnit.GetFractionComplete and oUnit:GetFractionComplete() == 1 then
            iCurTech = M27UnitInfo.GetUnitTechLevel(oUnit)
            if iCurTech > iHighestTech then iHighestTech = iCurTech end
            if oUnit:IsUnitState('Upgrading') then
                iUpgradingCount = iUpgradingCount + 1
                if iCurTech > iHighestFactoryBeingUpgraded then iHighestFactoryBeingUpgraded = iCurTech end
            else
                if M27Conditions.SafeToUpgradeUnit(oUnit) and not(oUnit[refbWillCtrlKMex]) then
                    iAvailableToUpgradeCount = iAvailableToUpgradeCount + 1
                    if bDebugMessages == true then LOG(sFunctionRef..': iUnit in tAllUnits='..iUnit..'; iAvailableToUpgradeCount='..iAvailableToUpgradeCount..'; Have unit available to upgrading whose unit state isnt upgrading.  UnitId='..oUnit:GetUnitId()..'; Unit State='..M27Logic.GetUnitState(oUnit)..': Upgradesto='..(oUnitBP.General.UpgradesTo or 'nil')) end
                end
            end
        end
    end
    if iHighestFactoryBeingUpgraded >= iHighestTech then bAreAlreadyUpgradingToHQ = true end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, iUpgradingCount='..iUpgradingCount..'; iAvailableToUpgradeCount='..iAvailableToUpgradeCount) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iUpgradingCount, iAvailableToUpgradeCount, bAreAlreadyUpgradingToHQ
end

function UpgradeUnit(oUnitToUpgrade, bUpdateUpgradeTracker)
    --Work out the upgrade ID wanted; if bUpdateUpgradeTracker is true then records upgrade against unit's aiBrain
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpgradeUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Do we have any HQs of the same factory type of a higher tech level?
    local sUpgradeID = M27UnitInfo.GetUnitUpgradeBlueprint(oUnitToUpgrade, true) --If not a factory or dont recognise the faction then just returns the normal unit ID
    --local oUnitBP = oUnitToUpgrade:GetBlueprint()
    --local iFactoryTechLevel = GetUnitTechLevel(oUnitBP.BlueprintId)

    --GetUnitUpgradeBlueprint(oFactoryToUpgrade, bGetSupportFactory)


    --local sUpgradeID = oUnitBP.General.UpgradesTo


    if sUpgradeID then
        --Issue upgrade
        IssueUpgrade({oUnitToUpgrade}, sUpgradeID)
        if bUpdateUpgradeTracker then
            local aiBrain = oUnitToUpgrade:GetAIBrain()
            table.insert(aiBrain[reftUpgrading], oUnitToUpgrade)
            if bDebugMessages == true then LOG(sFunctionRef..': Have issued upgrade to unit and recorded it') end
        end
    else M27Utilities.ErrorHandler('Dont have a valid upgrade ID; UnitID='..oUnitToUpgrade:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade))
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetUnitToUpgrade(aiBrain, iUnitCategory, tStartPoint)
    --Looks for the nearest non-upgrading unit of iunitcategory to tStartPoint
    --Returns nil if cant find one
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetUnitToUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    local tAllUnits = aiBrain:GetListOfUnits(iUnitCategory, false, true)
    local oUnitToUpgrade, tCurPosition, iCurDistanceToStart, iCurDistanceToEnemy, iCurCombinedDist
    local iMaxCombinedDist = -100000
    local tOurStartPosition
    if tStartPoint then tOurStartPosition = tStartPoint else tOurStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber] end
    --local iEnemyStartPosition = M27Logic.GetNearestEnemyStartNumber(aiBrain)
    --local tEnemyStartPosition = M27MapInfo.PlayerStartPoints[iEnemyStartPosition]
    --local iEnemySearchRange = 60
    --local tNearbyEnemies
    if bDebugMessages == true then LOG(sFunctionRef..': About to loop through units to find one to upgrade; size of tAllUnits='..table.getn(tAllUnits)) end
    local tPotentialUnits = {}
    local iPotentialUnits = 0
    --local iDistFromOurStartToEnemy = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]
    --local iDistanceBufferToEnemy = iDistFromOurStartToEnemy * 0.15

    --First create a shortlist of units that we could upgrade: - must be closer to us than enemy base by at least 10% of distance between us and enemy; Must have defence coverage>=10% of the % between us and enemy (or have it behind our base)
    if M27Utilities.IsTableEmpty(tAllUnits) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': Have shortlist of potential units, size='..table.getn(tAllUnits)) end
        for iUnit, oUnit in tAllUnits do
            if bDebugMessages == true then LOG(sFunctionRef..': iUnit in tAllUnits='..iUnit..'; checking if its valid') end
            if M27UnitInfo.IsUnitValid(oUnit) and not(M27UnitInfo.GetUnitUpgradeBlueprint(oUnit, true) == nil) and not(oUnit:IsUnitState('Upgrading')) then
                if bDebugMessages == true then LOG(sFunctionRef..': Have a unit that is available for upgrading; iUnit='..iUnit..'; Unit ref='..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                if M27Conditions.SafeToUpgradeUnit(oUnit) and not(oUnit[refbWillCtrlKMex]) then
                    iPotentialUnits = iPotentialUnits + 1
                    tPotentialUnits[iPotentialUnits] = oUnit
                    if bDebugMessages == true then LOG(sFunctionRef..': Have a potential unit to upgrade, iPotentialUnits='..iPotentialUnits) end
                end
            end
        end
        if iPotentialUnits > 0 then
            --FilterLocationsBasedOnDefenceCoverage(aiBrain, tLocationsToFilter, bAlsoNeedIntelCoverage, bNOTYETCODEDAlsoReturnClosest, bTableOfObjectsNotLocations)
            if bDebugMessages == true then LOG(sFunctionRef..': About to check if we have any safe units; defence coverage='..aiBrain[M27Overseer.refiPercentageOutstandingThreat]) end
            local tSafeUnits = M27EngineerOverseer.FilterLocationsBasedOnDefenceCoverage(aiBrain, tPotentialUnits, true, nil, true)
            if M27Utilities.IsTableEmpty(tSafeUnits) == false then
                local tTech1SafeUnits = EntityCategoryFilterDown(categories.TECH1, tSafeUnits)
                if M27Utilities.IsTableEmpty(tTech1SafeUnits) == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have tech 1 safe units, will get the nearest one to our start') end
                    --GetNearestUnit(tUnits, tCurPos, aiBrain, bHostileOnly)
                    oUnitToUpgrade = M27Utilities.GetNearestUnit(tTech1SafeUnits, tOurStartPosition, aiBrain, false)
                else
                    oUnitToUpgrade = M27Utilities.GetNearestUnit(tSafeUnits, tOurStartPosition, aiBrain, false)
                    if bDebugMessages == true then LOG(sFunctionRef..': no tech 1 safe units so will just get the nearest safe unit to our start') end
                end

            elseif bDebugMessages == true then LOG(sFunctionRef..': No safe units based on intel and defence coverage')
            end
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': Dont have any units of the desired category') end
    end

    if oUnitToUpgrade and EntityCategoryContains(M27UnitInfo.refCategoryMex, oUnitToUpgrade:GetUnitId()) and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyTML]) == false then
        aiBrain[M27PlatoonFormer.refbUsingMobileShieldsForPlatoons] = true
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oUnitToUpgrade
end

function DecideWhatToUpgrade(aiBrain, iMaxToBeUpgrading)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DecideWhatToUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --iMexesUpgrading, iMexesAvailableForUpgrade = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryT1Mex + refCategoryT2Mex, true)
    local iT1Mexes = aiBrain:GetCurrentUnits(refCategoryT1Mex)
    local iT2Mexes = aiBrain:GetCurrentUnits(refCategoryT2Mex)
    local iT3Mexes = aiBrain:GetCurrentUnits(refCategoryT3Mex)
    local iLandFactoryUpgrading, iLandFactoryAvailable, bAlreadyUpgradingLandHQ = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryLandFactory, true)
    local iAirFactoryUpgrading, iAirFactoryAvailable, bAlreadyUpgradingAirHQ = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryAirFactory, true)

    local iT1LandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.TECH1)
    local iT2LandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.TECH2)
    local iT3LandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.TECH3)
    local iT1AirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.TECH1)
    local iT2AirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.TECH2)
    local iT3AirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.TECH3)
    local iUnitUpgrading, iUnitAvailable
    local iCategoryToUpgrade
    local iRatioOfMexToFactory = 1
    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then iRatioOfMexToFactory = 3 end

    --Special logic for if trying to snipe ACU
    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and M27UnitInfo.IsUnitUnderwater(aiBrain[M27Overseer.refoLastNearestACU]) and (iT2AirFactories + iT3AirFactories) == 0 then
        iCategoryToUpgrade = refCategoryAirFactory
    else
        if iMaxToBeUpgrading > (iLandFactoryUpgrading + aiBrain[refiMexesUpgrading] + iAirFactoryUpgrading) then
            if aiBrain[refiMexesAvailableForUpgrade] > 0 then
                iCategoryToUpgrade = refCategoryT1Mex + refCategoryT2Mex --Default
            end
            if aiBrain[refiMexesUpgrading] == 0 and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech and aiBrain[refiMexesAvailableForUpgrade] > 0 then
                --Just stick with upgrading a mex, no change
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Have enough available units to upgrade; have started by setting upgrade to mex as default') end
                --Do we need torpedo bombers and cant build them fast enough?
                if iT2AirFactories + iT3AirFactories + iAirFactoryUpgrading == 0 and aiBrain[M27AirOverseer.refiTorpBombersWanted] > 0 then
                    iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryLandFactory * categories.TECH2
                elseif aiBrain[M27AirOverseer.refiTorpBombersWanted] > 5 and iAirFactoryUpgrading == 0 and (iAirFactoryAvailable - iT2AirFactories) > 0 then iCategoryToUpgrade = refCategoryAirFactory
                else
                    --Do we want to improve build power instead of getting mexes?
                    if (iLandFactoryUpgrading + iT2LandFactories + iAirFactoryUpgrading + iT2AirFactories) + (iT3LandFactories + iT3AirFactories) * 1.5 < ((aiBrain[refiMexesUpgrading] + iT2Mexes) + iT3Mexes * 3)*iRatioOfMexToFactory then
                        if bDebugMessages == true then LOG(sFunctionRef..': Want to upgrade build power if we have factories available. bAlreadyUpgradingLandHQ='..tostring(bAlreadyUpgradingLandHQ)..'; bAlreadyUpgradingAirHQ='..tostring(bAlreadyUpgradingAirHQ)) end
                        --Want to upgrade build power
                        local iFactoryToAirRatio = (iLandFactoryUpgrading * 2 + iT1LandFactories + iT2LandFactories * 2 + iT3LandFactories * 3) / math.max(1, iAirFactoryUpgrading * 2 + iT1AirFactories + iT2AirFactories * 2 + iT3AirFactories * 3)
                        local iDesiredFactoryToAirRatio = aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] / math.max(1, aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir])
                        if iAirFactoryAvailable > 0 and iFactoryToAirRatio > iDesiredFactoryToAirRatio and aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir] > (iAirFactoryUpgrading + iAirFactoryAvailable) and not(bAlreadyUpgradingAirHQ) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Want to upgrade air factory') end
                            iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryAirFactory * categories.TECH2
                        elseif iLandFactoryAvailable > 0 and not(bAlreadyUpgradingLandHQ) and (iLandFactoryAvailable + iT3LandFactories + iT3AirFactories + iAirFactoryAvailable) > 1 then --Dont want to upgrade our only land factory taht can produce units if we have no other available factories (including air, to allow for maps where we go for only 1 land fac)
                            if bDebugMessages == true then LOG(sFunctionRef..': Want to upgrade land factory') end
                            iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1 + refCategoryLandFactory * categories.TECH2
                        end
                    end
                end
            end
        end
    end

    if bDebugMessages == true then
        if iCategoryToUpgrade == nil then LOG(sFunctionRef..': Dont have a category to upgrade')
        else
            LOG(sFunctionRef..': Have a category to upgrade, number of untis of that category='..aiBrain:GetCurrentUnits(iCategoryToUpgrade))
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iCategoryToUpgrade
end

function ClearOldRecords(aiBrain, iOldRecordsExpected)
    --iOldRecordsExpected - optional - allows optimisation by having this called from loops which can already determine this for minimal extra cost
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ClearOldRecords'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iLoopCount = 0
    local iLoopMax = 100
    local sUnitReasonForClear, sUnitState
    local iOldRecordCount = 0
    if M27Utilities.IsTableEmpty(aiBrain[reftUpgrading]) == false then
        if iOldRecordsExpected == nil then
           for iRef, oUnit in aiBrain[reftUpgrading] do
               if M27UnitInfo.IsUnitValid(oUnit) == false or oUnit:IsUnitState('Upgrading') == false then
                   iOldRecordCount = iOldRecordCount + 1
               end
           end
        else iOldRecordCount = iOldRecordsExpected
        end
        if bDebugMessages == true then LOG(sFunctionRef..': iOldRecordCount='..iOldRecordCount..'; will clean up trackers') end
        while iOldRecordCount > 0 do
            iLoopCount = iLoopCount + 1
            if iLoopCount > iLoopMax then M27Utilities.ErrorHandler('Infinite loop') break end

            for iRef, oUnit in aiBrain[reftUpgrading] do
                if M27UnitInfo.IsUnitValid(oUnit) == false then
                    if bDebugMessages == true then
                        sUnitReasonForClear = 'Unknown'
                        if oUnit.Dead then sUnitReasonForClear = 'Unit is dead'
                        elseif oUnit.GetFractionComplete == nil then sUnitReasonForClear = 'Unit doesnt have a fraction complete, likely error'
                            --Commented out to avoid desyncs:
                        --elseif oUnit:GetFractionComplete() < 1 then sUnitReasonForClear = 'Unit fraction complete isnt 100%'
                        --elseif oUnit:IsUnitState('Upgrading') == false then sUnitReasonForClear = 'Unit state isnt upgrading'
                        end
                        --if oUnit.GetUnitId then sUnitReasonForClear = oUnit:GetUnitId()..':'..sUnitReasonForClear end
                        LOG(sFunctionRef..': iRef='..iRef..': clearing from tracker, reason for clearing: '..sUnitReasonForClear)
                        --sUnitState = 'UnknownState'
                        --if oUnit.IsUnitState then sUnitState = M27Logic.GetUnitState(oUnit) end
                    end

                    if oUnit[refbUpgradePaused] == true then aiBrain[refiPausedUpgradeCount] = aiBrain[refiPausedUpgradeCount] - 1 end
                    table.remove(aiBrain[reftUpgrading], iRef)
                    iOldRecordCount = iOldRecordCount - 1
                    if bDebugMessages == true then LOG(sFunctionRef..': Just removed an old record; iOldRecordCount='..iOldRecordCount) end
                    break
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UnpauseUpgrades(aiBrain, iMaxToUnpause)
    --Note - this will try and unpause any units that have been paused previously.  However, in some cases there may not be a unit to unpause e.g. if engineers have assisted it while its paused
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UnpauseUpgrades'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iAmountToUnpause = math.min(iMaxToUnpause, aiBrain[refiPausedUpgradeCount])
    local iOldRecordCount = 0
    local iLoopCount = 0
    local iMaxLoopCount = 20
    local bNoUnitsFound = true
    if bDebugMessages == true then LOG(sFunctionRef..': iAmountToUnpause='..iAmountToUnpause..'; aiBrain[refiPausedUpgradeCount]='..aiBrain[refiPausedUpgradeCount]) end
    while iAmountToUnpause > 0 do
        iLoopCount = iLoopCount + 1
        if iLoopCount > iMaxLoopCount then M27Utilities.ErrorHandler('Infinite loop detected') break end
        if M27Utilities.IsTableEmpty(aiBrain[reftUpgrading]) == false then
            bNoUnitsFound = true
            for iRef, oUnit in aiBrain[reftUpgrading] do
                if bDebugMessages == true then LOG(sFunctionRef..': Cycling through units in reftUpgrading; iRef='..iRef) end
                if M27UnitInfo.IsUnitValid(oUnit) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have a valid unit, checking if it has a paused upgrade, oUnit[refbUpgradePaused]='..tostring(oUnit[refbUpgradePaused])) end
                    if oUnit[refbUpgradePaused] == true then
                        if bDebugMessages == true then LOG(sFunctionRef..': Units upgrade is paused, will unpause now') end
                        iAmountToUnpause = iAmountToUnpause - 1
                        oUnit:SetPaused(false)
                        oUnit[refbUpgradePaused] = false
                        aiBrain[refiPausedUpgradeCount] = aiBrain[refiPausedUpgradeCount] - 1
                        bNoUnitsFound = false
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Unit not valid so must be an old record') end
                    iOldRecordCount = iOldRecordCount + 1
                end
            end
            if bNoUnitsFound == true then
                if bDebugMessages == true then LOG(sFunctionRef..': NoUnits found; iOldRecordCount='..iOldRecordCount) end
                aiBrain[reftUpgrading] = {}
                break
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Table of upgrading units is empty but we should have paused units in it; maybe they died?') end
            break
        end
        if iOldRecordCount > 0 then
            if bDebugMessages == true then LOG(sFunctionRef..': iOldRecordCount='..iOldRecordCount..'; will clear old records before continuing loop') end
            ClearOldRecords(aiBrain, iOldRecordCount) iOldRecordCount = 0
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function PauseLastUpgrade(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'PauseLastUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local oLastUnpausedUpgrade
    local oLastUnpausedNonMex
    local iOldRecordCount = 0
    local iMexThresholdToIgnorePausing = 0.9
    local iGeneralThresholdToIgnorePausing = 0.9
    local sUnitId
    if aiBrain[refbPauseForPowerStall] == false then
        iMexThresholdToIgnorePausing = 0.6
        iGeneralThresholdToIgnorePausing = 0.8
    end
    local iThresholdToIgnorePausing
    local bHaveMex = false
    if M27Utilities.IsTableEmpty(aiBrain[reftUpgrading]) == false then
        for iRef, oUnit in aiBrain[reftUpgrading] do
            if bDebugMessages == true then LOG(sFunctionRef..': iRef='..iRef..' Considering if unit is alive and part-complete') end
            if M27UnitInfo.IsUnitValid(oUnit) then
                if not(oUnit[refbUpgradePaused]) then
                    if oUnit:IsUnitState('Upgrading') == true then
                        sUnitId = oUnit:GetUnitId()
                        if bDebugMessages == true then LOG(sFunctionRef..': Unit ID='..sUnitId..'; Unit is valid and not paused so will pause it unless theres a later upgrade or its a mex and almost complete') end
                        if not(EntityCategoryContains(refCategoryMex, sUnitId)) then
                            iThresholdToIgnorePausing = iGeneralThresholdToIgnorePausing
                        else
                            bHaveMex = true
                            iThresholdToIgnorePausing = iMexThresholdToIgnorePausing
                        end

                        if bDebugMessages == true then
                            LOG(sFunctionRef..': oUnit='..sUnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit))
                            if oUnit.UnitBeingBuilt then
                                LOG(sFunctionRef..': Have a unit being built')
                                if oUnit.UnitBeingBuilt.GetUnitId then LOG(sFunctionRef..': ID of unit being built='..oUnit.UnitBeingBuilt:GetUnitId()) end
                                if oUnit.UnitBeingBuilt.GetFractionComplete then LOG(sFunctionRef..': Fraction complete='..oUnit.UnitBeingBuilt:GetFractionComplete()) else LOG('Fraction complete is nil') end
                            elseif oUnit.unitBeingBuilt then
                                M27Utilities.ErrorHandler('UnitBeingBuilt sometimes is lower case so need to revise code')
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': unitBeingBuilt is nil') end
                            end
                        end
                        if oUnit.UnitBeingBuilt and oUnit.UnitBeingBuilt.GetFractionComplete and oUnit.UnitBeingBuilt:GetFractionComplete() < iThresholdToIgnorePausing then
                            oLastUnpausedUpgrade = oUnit
                            if not(bHaveMex) then oLastUnpausedNonMex = oLastUnpausedUpgrade end
                        end
                    end
                end
            else
                iOldRecordCount = iOldRecordCount + 1
                if bDebugMessages == true then LOG(sFunctionRef..': Unit was dead or complete, will call separate function to remove from tracker') end
            end
        end
        if oLastUnpausedUpgrade then

            if oLastUnpausedNonMex then
                oLastUnpausedNonMex:SetPaused(true)
            else
                oLastUnpausedUpgrade:SetPaused(true)
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Pausing upgrade') end
            aiBrain[refiPausedUpgradeCount] = aiBrain[refiPausedUpgradeCount] + 1
            oLastUnpausedUpgrade[refbUpgradePaused] = true
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': We have no buildings recorded that we are upgrading, so nothing to pause') end
    end

    if iOldRecordCount > 0 then
        if iOldRecordCount > 0 then ClearOldRecords(aiBrain, iOldRecordCount) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DecideMaxAmountToBeUpgrading(aiBrain)
    --Returns max number to upgrade
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DecideMaxAmountToBeUpgrading'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iMassStored, iMassNetIncome, iEnergyStored, iEnergyNetIncome
    local bHaveHighMass, bHaveEnoughEnergy
    local iMaxToUpgrade = 0

    --Get economy values:
    iMassStored = aiBrain:GetEconomyStored('MASS')
    iEnergyStored = aiBrain:GetEconomyStored('ENERGY')
    iMassNetIncome = aiBrain:GetEconomyTrend('MASS')
    iEnergyNetIncome = aiBrain:GetEconomyTrend('ENERGY')
    local iEnergyChangeFromLastCycle = iEnergyStored - aiBrain[refiEnergyStoredLastCycle]
    local iEnergyPercentStorage = aiBrain:GetEconomyStoredRatio('ENERGY')

    bHaveHighMass = false
    bHaveEnoughEnergy = false
    local bHaveLotsOfResources = false

    if bDebugMessages == true then LOG(sFunctionRef..': iMassStored='..iMassStored..'; iEnergyStored='..iEnergyStored..'; iMassNetIncome='..iMassNetIncome..'; iEnergyNetIncome='..iEnergyNetIncome) end

    local bHaveLotsOfFactories = false
    local iMexCount = aiBrain:GetCurrentUnits(refCategoryMex)
    local iMexesOnOurSideOfMap = GetMexCountOnOurSideOfMap(aiBrain)
    local iLandFactoryCount = aiBrain:GetCurrentUnits(refCategoryLandFactory)
    local iAirFactoryCount = aiBrain:GetCurrentUnits(refCategoryAirFactory)
    if iLandFactoryCount >= 10 then bHaveLotsOfFactories = true end
    local bWantMoreFactories = false
    if iLandFactoryCount < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] then bWantMoreFactories = true
    elseif iAirFactoryCount < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir] then bWantMoreFactories = true end

    local iFactoriesWanted
    local iMexesToBaseFactoryCalcOn = math.min(iMexesOnOurSideOfMap, iMexCount)


    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then iFactoriesWanted = math.max(2, math.ceil(iMexesToBaseFactoryCalcOn * 0.2))
    else iFactoriesWanted = math.max(4, 10, iMexesToBaseFactoryCalcOn * 0.7) end

    local bNormalLogic = true
    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill then
        bNormalLogic = false
        --Pause upgrades unlessd ACU is underwater and we dont ahve T2+ air
        if M27UnitInfo.IsUnitUnderwater(aiBrain[M27Overseer.refoLastNearestACU]) and aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.TECH2 + refCategoryAirFactory * categories.TECH3) == 0 then
            bWantMoreFactories = true
            iMaxToUpgrade = 2
        elseif aiBrain[M27Overseer.refbIncludeACUInAllOutAttack] == true then
            iMaxToUpgrade = -1
        else
            bNormalLogic = true
        end
    end
    if bNormalLogic then
        if iLandFactoryCount < iFactoriesWanted then
            if bDebugMessages == true then LOG(sFunctionRef..': We want more land factories; iLandFactoryCount='..iLandFactoryCount..'; iFactoriesWanted='..iFactoriesWanted) end
            bWantMoreFactories = true
            -- if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then bWantMoreFactories = false end
        end

        local tMassThresholds = {}
        aiBrain[refiMexesUpgrading], aiBrain[refiMexesAvailableForUpgrade] = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryT1Mex + refCategoryT2Mex, true)

        if aiBrain[refiPausedUpgradeCount] == 1 and table.getn(aiBrain[reftUpgrading]) <= 1 then --Want to resume unless we're energy stalling
            tMassThresholds[1] = {0, -2.0}
            tMassThresholds[2] = {2000, -20}
            tMassThresholds[3] = {4000, -40}
            tMassThresholds[4] = {5000,-200}
        elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech and aiBrain[refiMexesUpgrading] == 0 and aiBrain[refiMexesAvailableForUpgrade] > 0 then
            tMassThresholds[1] = {0, -2.0}
            tMassThresholds[2] = {2000, -20}
            tMassThresholds[3] = {4000, -40}
            tMassThresholds[4] = {5000,-200}
        elseif aiBrain[refiPausedUpgradeCount] > 1 or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
            tMassThresholds[1] = {100, 0.1}
            tMassThresholds[2] = {150, 0}
            tMassThresholds[3] = {750, -0.5}
            tMassThresholds[4] = {1500, -1.5}
            tMassThresholds[5] = {3000, -2.5}
            tMassThresholds[6] = {4000, -5}
            tMassThresholds[7] = {5000,-200}
        else
            if bHaveLotsOfFactories == false and bWantMoreFactories == true then
                tMassThresholds[1] = {300, 0.3}
                tMassThresholds[2] = {700, 0}
                tMassThresholds[3] = {1500, -0.4}
                tMassThresholds[4] = {2000, -1.0}
                tMassThresholds[5] = {3000, -2.5}
                tMassThresholds[6] = {4000, -5}
                tMassThresholds[7] = {5000,-200}
            else
                if bHaveLotsOfFactories == true and bWantMoreFactories == false then
                    tMassThresholds[1] = {100, 0.2}
                    tMassThresholds[2] = {200, 0}
                    tMassThresholds[3] = {800, -0.5}
                    tMassThresholds[4] = {1600, -1.4}
                    tMassThresholds[5] = {3000, -2.5}
                    tMassThresholds[6] = {4000, -5}
                    tMassThresholds[7] = {5000,-200}
                else
                    tMassThresholds[1] = {150, 0.2}
                    tMassThresholds[2] = {350, 0}
                    tMassThresholds[3] = {900, -0.4}
                    tMassThresholds[4] = {1600, -1.3}
                    tMassThresholds[5] = {3000, -2.5}
                    tMassThresholds[6] = {4000, -5}
                    tMassThresholds[7] = {5000,-200}
                end
            end
        end

        --Increase thresholds if we're trying to build a missile
        if aiBrain[M27EngineerOverseer.refbNeedResourcesForMissile] then
            for iThresholdRef, tThreshold in tMassThresholds do
                tMassThresholds[iThresholdRef][1] = tMassThresholds[iThresholdRef][1] + math.max(500, tMassThresholds[iThresholdRef][1] * 0.5)
                tMassThresholds[iThresholdRef][2] = tMassThresholds[iThresholdRef][2] + 1
            end
        end

        --Increase thresholds if we are trying to ctrl-K a mex
        if aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildT3MexOverT2]) == false then
            for iThresholdRef, tThreshold in tMassThresholds do
                tMassThresholds[iThresholdRef][1] = tMassThresholds[iThresholdRef][1] + 2000
            end
        end

        aiBrain[refbWantMoreFactories] = bWantMoreFactories

        for _, tThreshold in tMassThresholds do
            if iMassStored >= tThreshold[1] and iMassNetIncome >= tThreshold[2] then bHaveHighMass = true break end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': bWantMoreFactories='..tostring(bWantMoreFactories)..'; iLandFactoryCount='..iLandFactoryCount..'; iMexesOnOurSideOfMap='..iMexesOnOurSideOfMap..'; bHaveHighMass='..tostring(bHaveHighMass)..'; iMassStored='..iMassStored..'; iMassNetIncome='..iMassNetIncome) end

        --Low mass override
        if M27Conditions.HaveLowMass(aiBrain) == true and aiBrain[refiMexesUpgrading] >= 2 then bHaveHighMass = false end

        if bHaveHighMass == true then
            if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                --Want more energy if in air dominance to avoid risk we start upgrading and cant produce bombers
                if iEnergyPercentStorage > 0.8 and iEnergyStored > 3500 and iEnergyNetIncome > 4 and iEnergyChangeFromLastCycle > 0 then bHaveEnoughEnergy = true
                elseif iEnergyPercentStorage >= 0.99 then bHaveEnoughEnergy = true end
            else
                if  iEnergyChangeFromLastCycle > 0 then
                    if iEnergyNetIncome > 4 and iEnergyStored > 1500 and iEnergyPercentStorage > 0.4 then bHaveEnoughEnergy = true
                    elseif iEnergyNetIncome > 2 and iEnergyStored > 2500 and iEnergyPercentStorage > 0.5 then bHaveEnoughEnergy = true
                    end
                elseif iEnergyNetIncome > 5 and iEnergyStored > 2500 and iEnergyPercentStorage > 0.8 then bHaveEnoughEnergy = true
                elseif iEnergyPercentStorage >= 0.99 then bHaveEnoughEnergy = true
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Have high mass, bHaveEnoughEnergy='..tostring(bHaveEnoughEnergy)) end
            if bHaveEnoughEnergy then
                local iGameTime = GetGameTimeSeconds()
                --Do we have lots of resources?
                if iMassStored > 800 and iMassNetIncome > 0.2 and iEnergyNetIncome > 4 and iEnergyStored > 1000 then bHaveLotsOfResources = true
                elseif iMassStored > 2000 and iEnergyPercentStorage >= 0.99 then bHaveLotsOfResources = true
                end
                if iGameTime > 180 then --Dont consider upgrading at start of game
                    iMaxToUpgrade = 1
                    if bHaveLotsOfResources == true then
                        iMaxToUpgrade = 20
                    elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech and aiBrain[refiMexesUpgrading] <= 0 then iMaxToUpgrade = 2
                    end
                end
                --Backup for unusual scenarios - are we about to overflow mass and have high energy stored and have positive mass and energy income? then upgrade with no limit
                if (iEnergyPercentStorage >= 0.99 or iEnergyNetIncome > 5) and (aiBrain:GetEconomyStoredRatio('MASS') >= 0.8 or iMassStored >= 2000) then iMaxToUpgrade = 100
                elseif bHaveLotsOfResources == true and aiBrain:GetEconomyStoredRatio('ENERGY') > 0.9 and aiBrain:GetEconomyStoredRatio('MASS') > 0.7 then iMaxToUpgrade = 1000
                end
            end
        end

        if iMaxToUpgrade == 0 then
            if bDebugMessages == true then LOG(sFunctionRef..': Dont have enough resources to upgrade, checking if should pause upgrades') end
            --Check for low energy amounts
            local bLowEnergy = false
            if iEnergyStored <= 250 and iEnergyNetIncome < 0 then bLowEnergy = true
            elseif iEnergyStored <= 50 then bLowEnergy = true end

            if bLowEnergy == true then
                if bDebugMessages == true then LOG(sFunctionRef..': Have low energy so will flag we want to pause an upgrade') end
                iMaxToUpgrade = -1
                aiBrain[refbPauseForPowerStall] = true
            else
                --Check for mass stall if we have more than 1 mex or any factories upgrading, or have nearby enemy
                local iLandFactoryUpgrading, iLandFactoryAvailable, bAlreadyUpgradingLandHQ = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryLandFactory, true)
                local iAirFactoryUpgrading, iAirFactoryAvailable, bAlreadyUpgradingAirHQ = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryAirFactory, true)

                if aiBrain[refiMexesUpgrading] > 1 or iLandFactoryUpgrading + iAirFactoryUpgrading > 0 or aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= 100 or aiBrain[M27Overseer.refiPercentageOutstandingThreat] <= 0.3 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if stalling mass; iMassStored='..iMassStored..'; aiBrain:GetEconomyStoredRatio(MASS)='..aiBrain:GetEconomyStoredRatio('MASS')..'; iMassNetIncome='..iMassNetIncome) end
                    if (M27Conditions.HaveLowMass(aiBrain) and aiBrain[refiMexesUpgrading] + iLandFactoryUpgrading + iAirFactoryUpgrading >= 2) or (iMassStored <= 60 or aiBrain:GetEconomyStoredRatio('MASS') <= 0.06) and iMassNetIncome < 0.2 then
                        aiBrain[refbPauseForPowerStall] = false
                        iMaxToUpgrade = -1
                    end
                end
            end

        end
    end

    aiBrain[refiEnergyStoredLastCycle] = iEnergyStored

    if bDebugMessages == true then LOG(sFunctionRef..': End of code, iMaxToUpgrade='..iMaxToUpgrade..'; iMassStored='..iMassStored..'; bHaveHighMass='..tostring(bHaveHighMass)..'; iMassNetIncome='..iMassNetIncome..'; iEnergyNetIncome='..iEnergyNetIncome..'; iEnergyStored='..iEnergyStored..'; iEnergyPercentStorage='..iEnergyPercentStorage..'; iEnergyChangeFromLastCycle='..iEnergyChangeFromLastCycle..'; bHaveEnoughEnergy='..tostring(bHaveEnoughEnergy)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iMaxToUpgrade
end

function RefreshEconomyData(aiBrain)
    --Yes, hardcoding resource values will make it really hard to support mods or patches that change these values
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RefreshEconomyData'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iACUMass = 1
    local iACUEnergy = 20
    local iEnergyT3Power = 2500
    local iEnergyT2Power = 500
    local iEnergyT1Power = 20
    local iEnergyHydro = 100
    local iT1MexMass = 2
    local iT2MexMass = 6
    local iT3MexMass = 18

    local iT3PowerCount, iT2PowerCount, iT1PowerCount, iHydroCount ,iT1MexCount, iT2MexCount, iT3MexCount

    iT1PowerCount = aiBrain:GetCurrentUnits(refCategoryT1Power)
    iT2PowerCount = aiBrain:GetCurrentUnits(refCategoryT2Power)
    iT3PowerCount = aiBrain:GetCurrentUnits(refCategoryT3Power)
    iHydroCount = aiBrain:GetCurrentUnits(refCategoryHydro)
    iT1MexCount = aiBrain:GetCurrentUnits(refCategoryT1Mex)
    iT2MexCount = aiBrain:GetCurrentUnits(refCategoryT2Mex)
    iT3MexCount = aiBrain:GetCurrentUnits(refCategoryT3Mex)
    local tMassStorage = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryMassStorage, false, true)
    local iStorageIncomeBoost = 0
    local tMexByStorage
    local tCurPos
    local tMexMidpoint
    local iMexSize = 0.5
    local oCurBP
    if M27Utilities.IsTableEmpty(tMassStorage) == false then
        local tPositionAdj = {
            {-1, -1},
            {-1, 1},
            {1, -1},
            {1, 1}
        }

        for iStorage, oStorage in tMassStorage do
            --Check nearby mex adjacency
            tCurPos = oStorage:GetPosition()
            for iCurAdj = 1, 4 do
                tMexMidpoint = {tCurPos[1] + tPositionAdj[iCurAdj][1], 0, tCurPos[3] + tPositionAdj[iCurAdj][2]}
                tMexMidpoint[2] = GetSurfaceHeight(tMexMidpoint[1], tMexMidpoint[3])
                tMexByStorage = GetUnitsInRect(Rect(tMexMidpoint[1] - iMexSize, tMexMidpoint[3] - iMexSize, tMexMidpoint[1] + iMexSize, tMexMidpoint[3] + iMexSize))
                if M27Utilities.IsTableEmpty(tMexByStorage) == false then
                    tMexByStorage = EntityCategoryFilterDown(M27UnitInfo.refCategoryMex, tMexByStorage)
                    if M27Utilities.IsTableEmpty(tMexByStorage) == false then
                        if tMexByStorage[1].GetBlueprint and not(tMexByStorage[1].Dead) and tMexByStorage[1].GetAIBrain and tMexByStorage[1]:GetAIBrain() == aiBrain then
                            oCurBP = tMexByStorage[1]:GetBlueprint()
                            if oCurBP.Economy and oCurBP.Economy.ProductionPerSecondMass then
                                iStorageIncomeBoost = iStorageIncomeBoost + oCurBP.Economy.ProductionPerSecondMass * 0.125
                            end
                        end
                    end
                end
            end
        end
    end

    local iMassUsage = -(aiBrain:GetEconomyTrend('MASS') - aiBrain:GetEconomyIncome('MASS'))
    local iEnergyUsage = -(aiBrain:GetEconomyTrend('ENERGY') - aiBrain:GetEconomyIncome('ENERGY'))
    local iPerTickFactor = 0.1



    aiBrain[refiEnergyGrossBaseIncome] = (iACUEnergy + iT3PowerCount * iEnergyT3Power + iT2PowerCount * iEnergyT2Power + iT1PowerCount * iEnergyT1Power + iHydroCount * iEnergyHydro)*iPerTickFactor
    aiBrain[refiEnergyNetBaseIncome] = aiBrain[refiEnergyGrossBaseIncome] - iEnergyUsage
    aiBrain[refiMassGrossBaseIncome] = (iACUMass + iT3MexMass * iT3MexCount + iT2MexMass * iT2MexCount + iT1MexMass * iT1MexCount + iStorageIncomeBoost)*iPerTickFactor
    aiBrain[refiMassNetBaseIncome] = aiBrain[refiMassGrossBaseIncome] - iMassUsage

    if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[refiEnergyGrossBaseIncome]='..aiBrain[refiEnergyGrossBaseIncome]..'; aiBrain[refiEnergyNetBaseIncome]='..aiBrain[refiEnergyNetBaseIncome]..'; iT2PowerCount='..iT2PowerCount..'; iEnergyT1Power='..iEnergyT1Power..'; iEnergyUsage='..iEnergyUsage) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpgradeMainLoop(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpgradeManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if (M27Logic.iTimeOfLastBrainAllDefeated or 0) < 10 then

        local iCategoryToUpgrade, oUnitToUpgrade
        local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local iMaxToBeUpgrading, iAmountToUpgradeAfterUnpausing


        aiBrain[refbWantToUpgradeMoreBuildings] = false --default

        iMaxToBeUpgrading = DecideMaxAmountToBeUpgrading(aiBrain)
        if bDebugMessages == true then LOG(sFunctionRef..': iMaxToBeUpgrading='..iMaxToBeUpgrading) end

        if iMaxToBeUpgrading >= 1 then
            --Unpause any already upgrading units first
            iAmountToUpgradeAfterUnpausing = math.max(iMaxToBeUpgrading - aiBrain[refiPausedUpgradeCount],0)
            if bDebugMessages == true then LOG(sFunctionRef..': Checking if upgrades to be unpaused') end
            UnpauseUpgrades(aiBrain, iMaxToBeUpgrading)
            if bDebugMessages == true then LOG(sFunctionRef..'; iAmountToUpgradeAfterUnpausing='..iAmountToUpgradeAfterUnpausing) end
            if iAmountToUpgradeAfterUnpausing > 0 then

                iCategoryToUpgrade = DecideWhatToUpgrade(aiBrain, iMaxToBeUpgrading)

                if iCategoryToUpgrade then
                    if bDebugMessages == true then LOG(sFunctionRef..': Got category to upgrade') end
                    oUnitToUpgrade = GetUnitToUpgrade(aiBrain, iCategoryToUpgrade, tStartPosition)
                    if oUnitToUpgrade == nil then
                        --One likely explanation for htis is that there are enemies near the units of the category wanted
                        if bDebugMessages == true then LOG(sFunctionRef..': Couldnt find unit to upgrade, will revert to default categories, starting with T1 mex') end
                        oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryT1Mex, tStartPosition)
                        if oUnitToUpgrade == nil then
                            if bDebugMessages == true then LOG(sFunctionRef..': Will look for T1 land factory') end
                            oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryLandFactory * categories.TECH1, tStartPosition)
                            if oUnitToUpgrade == nil then
                                if bDebugMessages == true then LOG(sFunctionRef..': Will look for T1 air factory') end
                                oUnitToUpgrade = GetUnitToUpgrade(aiBrain, M27UnitInfo.refCategoryAirFactory * categories.TECH1, tStartPosition)
                                if oUnitToUpgrade == nil then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Will look for T2 mex') end
                                    oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryT2Mex, tStartPosition)
                                    if oUnitToUpgrade == nil then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Will look for T2 land factory') end
                                        oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryLandFactory * categories.TECH2, tStartPosition)
                                        if oUnitToUpgrade == nil then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Will look for T2 air factory') end
                                            oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryAirFactory * categories.TECH2, tStartPosition)
                                            if oUnitToUpgrade == nil then
                                                --Do we have enemies within 100 of our base? if so then this is probably why we cant find anything to upgrade as buildings check no enemies within 90
                                                if aiBrain[M27Overseer.refiModDistFromStartNearestThreat] > 100 then
                                                    M27Utilities.ErrorHandler('Couldnt find unit to upgrade after trying all backup options; nearest enemy to base='..aiBrain[M27Overseer.refiModDistFromStartNearestThreat],nil, true)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if oUnitToUpgrade and not(oUnitToUpgrade.Dead) then
                        if bDebugMessages == true then LOG(sFunctionRef..': About to try and upgrade unit ID='..oUnitToUpgrade:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade)) end
                        UpgradeUnit(oUnitToUpgrade, true)
                        if bDebugMessages == true then LOG(sFunctionRef..': Finished sending order to upgrade unit') end
                    else
                        if bDebugMessages == true then LOG('Couldnt get a unit to upgrade despite trying alternative categories.  Likely cause is that we have enemies near our base meaning poor defence coverage. UnitToUpgrade='..(oUnitToUpgrade:GetUnitId() or 'nil')) end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Dont have anything to upgrade') end
                end
                if iAmountToUpgradeAfterUnpausing > 2 then aiBrain[refbWantToUpgradeMoreBuildings] = true end
            end
        elseif iMaxToBeUpgrading < 0 then
            --Need to pause
            if bDebugMessages == true then LOG(sFunctionRef..': We need to pause an upgrade') end
            PauseLastUpgrade(aiBrain)
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)

end

function ManageEnergyStalls(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ManageEnergyStalls'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    local bPauseNotUnpause = true
    local bChangeRequired = false
    if GetGameTimeSeconds() >= 90 then --Only consider power stall management after 1.5m, otherwise risk pausing things when we would probably be ok
        if bDebugMessages == true then LOG(sFunctionRef..': About to consider if we have an energy stall or not. aiBrain:GetEconomyStoredRatio(ENERGY)='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; aiBrain[refiEnergyNetBaseIncome]='..aiBrain[refiEnergyNetBaseIncome]..'; aiBrain:GetEconomyTrend(ENERGY)='..aiBrain:GetEconomyTrend('ENERGY')..'; aiBrain[refbStallingEnergy]='..tostring(aiBrain[refbStallingEnergy])) end
        --First consider unpausing
        if bDebugMessages == true then LOG(sFunctionRef..': If we have flagged that we are stalling energy then will check if we have enough to start unpausing things') end
        if aiBrain[refbStallingEnergy] and (aiBrain:GetEconomyStoredRatio('ENERGY') > 0.8 or (aiBrain:GetEconomyStoredRatio('ENERGY') > 0.7 and aiBrain[refiEnergyNetBaseIncome] > 1) or (aiBrain:GetEconomyStoredRatio('ENERGY') > 0.5 and aiBrain[refiEnergyNetBaseIncome] > 4) or (GetGameTimeSeconds() <= 180 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.3)) then
            --aiBrain[refbStallingEnergy] = false
            if bDebugMessages == true then LOG(sFunctionRef..': Have enough energy stored or income to start unpausing things') end
            bChangeRequired = true
            bPauseNotUnpause = false
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Checking if we shoudl flag that we are energy stalling') end
        --Check if should manage energy stall
        if bChangeRequired == false and (aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.08 or (aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.6 and aiBrain[refiEnergyNetBaseIncome] < 2) or (aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.4 and aiBrain[refiEnergyNetBaseIncome] < 0.5)) then
            if bDebugMessages == true then LOG(sFunctionRef..': We are stalling energy, will look for units to pause') end
            --If this is early game then add extra check
            if GetGameTimeSeconds() >= 180 or aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.04 then
                aiBrain[refbStallingEnergy] = true
                bChangeRequired = true
            end
        end

        if bChangeRequired then
            --Decide on order to pause/unpause

            local tCategoriesByPriority
            local tEngineerActionsByPriority
            if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
                tCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, M27UnitInfo.refCategoryEngineer}
                tEngineerActionsByPriority = {{M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildLandExperimental, M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionBuildAirFactory, M27EngineerOverseer.refActionBuildLandFactory, M27EngineerOverseer.refActionBuildMassStorage, M27EngineerOverseer.refActionUpgradeBuilding, M27EngineerOverseer.refActionBuildMex, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildSecondPower, M27EngineerOverseer.refActionBuildSMD},
                                              {M27EngineerOverseer.refActionBuildPower, M27EngineerOverseer.refActionBuildHydro} }
            elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill then
                tCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, M27UnitInfo.refCategoryEngineer}
                tEngineerActionsByPriority = {{M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildLandExperimental, M27EngineerOverseer.refActionBuildMassStorage, M27EngineerOverseer.refActionUpgradeBuilding, M27EngineerOverseer.refActionBuildSMD, M27EngineerOverseer.refActionBuildLandFactory},
                                              {M27EngineerOverseer.refActionAssistSMD, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildMex, M27EngineerOverseer.refActionBuildSecondPower},
                                              {M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionBuildPower, M27EngineerOverseer.refActionBuildHydro}}
            elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                tCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryEngineer}
                tEngineerActionsByPriority = {{M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildLandExperimental, M27EngineerOverseer.refActionBuildMassStorage},
                                              {M27EngineerOverseer.refActionUpgradeBuilding, M27EngineerOverseer.refActionBuildSMD, M27EngineerOverseer.refActionBuildLandFactory, M27EngineerOverseer.refActionAssistSMD},
                                              {M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildMex, M27EngineerOverseer.refActionBuildSecondPower, M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionBuildPower, M27EngineerOverseer.refActionBuildHydro}}
            else --Land attack mode/normal logic
                tCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, M27UnitInfo.refCategoryEngineer}
                tEngineerActionsByPriority = {{M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildLandExperimental, M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionBuildAirFactory, M27EngineerOverseer.refActionBuildLandFactory, M27EngineerOverseer.refActionBuildMassStorage, M27EngineerOverseer.refActionUpgradeBuilding},
                                              {M27EngineerOverseer.refActionBuildMex, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildSecondPower, M27EngineerOverseer.refActionBuildSMD},
                                              {M27EngineerOverseer.refActionBuildPower, M27EngineerOverseer.refActionBuildHydro} }
            end

            local iEnergyPerTickSavingNeeded
            if aiBrain[refbStallingEnergy] then iEnergyPerTickSavingNeeded = math.max(1, -aiBrain[refiEnergyNetBaseIncome])
            else iEnergyPerTickSavingNeeded = math.min(-1, -aiBrain[refiEnergyNetBaseIncome]) end

            local iEnergySavingManaged = 0
            local iEngineerSubtableCount = 0
            local tEngineerActionSubtable
            local tRelevantUnits, oUnit

            local bAbort = false
            local iTotalUnits = 0
            local iCategoryStartPoint, iIntervalChange, iCategoryEndPoint, iCategoryRef
            if bPauseNotUnpause then iCategoryStartPoint = 1 iIntervalChange = 1 iCategoryEndPoint = table.getn(tCategoriesByPriority)
            else iCategoryStartPoint = table.getn(tCategoriesByPriority) iIntervalChange = -1 iCategoryEndPoint = 1 end

            if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through every category, bPauseNotUnpause='..tostring(bPauseNotUnpause)..'; iCategoryStartPoint='..iCategoryStartPoint..'; iCategoryEndPoint='..iCategoryEndPoint..'; strategy='..aiBrain[M27Overseer.refiAIBrainCurrentStrategy]) end
            for iCategoryCount = iCategoryStartPoint, iCategoryEndPoint, iIntervalChange do
                iCategoryRef =  tCategoriesByPriority[iCategoryCount]
                if bPauseNotUnpause then tRelevantUnits = aiBrain:GetListOfUnits(iCategoryRef, false, true)
                else tRelevantUnits = EntityCategoryFilterDown(iCategoryRef, aiBrain[reftPausedUnits])
                end

                local iCurUnitEnergyUsage
                local bApplyActionToUnit
                if M27Utilities.IsTableEmpty(tRelevantUnits) == false then
                    iTotalUnits = table.getn(tRelevantUnits)
                    if bDebugMessages == true then LOG(sFunctionRef..': iCategoryCount='..iCategoryCount..'; iTotalUnits='..iTotalUnits..'; bPauseNotUnpause='..tostring(bPauseNotUnpause)) end
                    if iCategoryRef == M27UnitInfo.refCategoryEngineer then
                        iEngineerSubtableCount = iEngineerSubtableCount + 1
                        tEngineerActionSubtable = tEngineerActionsByPriority[iEngineerSubtableCount]
                    end
                    for iUnit = iTotalUnits, 1, -1 do
                        oUnit = tRelevantUnits[iUnit]
                        --for iUnit, oUnit in tRelevantUnits do
                        bApplyActionToUnit = false
                        iCurUnitEnergyUsage = 0
                        if M27UnitInfo.IsUnitValid(oUnit) then
                            if bDebugMessages == true then LOG(sFunctionRef..': About to pause/unpause unit '..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; will first check category specific logic for if we want to go ahead with pausing4') end
                            --Do we want to pause the unit? check any category specific logic
                            bApplyActionToUnit = true
                            --SMD LOGIC - Check if already have 1 missile loaded before pausing
                            if iCategoryRef == M27UnitInfo.refCategorySMD and oUnit.GetTacticalSiloAmmoCount and oUnit:GetTacticalSiloAmmoCount() >= 1 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Have SMD with at least 1 missile so will pause it') end
                                bApplyActionToUnit = false
                            elseif iCategoryRef == M27UnitInfo.refCategoryEngineer then
                                if bDebugMessages == true then LOG(sFunctionRef..': Have an engineer with action='..(oUnit[M27EngineerOverseer.refiEngineerCurrentAction] or 'nil')..'; tEngineerActionSubtable='..repr(tEngineerActionSubtable)) end
                                bApplyActionToUnit = false
                                for iActionCount, iActionRef in tEngineerActionSubtable do
                                    if iActionRef == oUnit[M27EngineerOverseer.refiEngineerCurrentAction] then bApplyActionToUnit = true break end
                                end
                            elseif iCategoryRef == M27UnitInfo.refCategoryPersonalShield or iCategoryRef == M27UnitInfo.refCategoryFixedShield or iCategoryRef == M27UnitInfo.refCategoryMobileLandShield then
                                --Dont disable shield if unit has enemies nearby
                                if bPauseNotUnpause and M27UnitInfo.IsUnitShieldEnabled(oUnit) and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, oUnit:GetPosition(), 40, 'Enemy')) == false then bApplyActionToUnit = false end
                            end
                            if iCategoryRef == categories.COMMAND then --want in addition to above as ACU might have personal shield
                                if bPauseNotUnpause then
                                    if not(oUnit:IsUnitState('Upgrading')) then bApplyActionToUnit = false
                                    elseif oUnit.GetWorkProgress and oUnit:GetWorkProgress() >= 0.85 then bApplyActionToUnit = false
                                    end
                                end
                            end

                            if bApplyActionToUnit then
                                iCurUnitEnergyUsage = oUnit:GetBlueprint().Economy.MaintenanceConsumptionPerSecondEnergy
                                if (iCurUnitEnergyUsage or 0) == 0 or iCategoryRef == M27UnitInfo.refCategoryEngineer or iCategoryRef == M27UnitInfo.refCategoryMex or iCategoryRef == categories.COMMAND then
                                    --Approximate energy usage based on build rate as a very rough guide
                                    --examples: Upgrading mex to T3 costs 11E per BP; T3 power is 8.4; T1 power is 6; Guncom is 30; Laser is 178; Strat bomber is 15
                                    local iEnergyPerBP = 9
                                    if iCategoryRef == categories.COMMAND and oUnit[M27UnitInfo.refsUpgradeRef] then
                                        --Determine energy cost per BP
                                        iEnergyPerBP = M27UnitInfo.GetUpgradeEnergyCost(oUnit, oUnit[M27UnitInfo.refsUpgradeRef]) / M27UnitInfo.GetUpgradeBuildTime(oUnit, oUnit[M27UnitInfo.refsUpgradeRef])
                                    end
                                    if oUnit:GetBlueprint().Economy.BuildRate then iCurUnitEnergyUsage = oUnit:GetBlueprint().Economy.BuildRate * iEnergyPerBP end
                                end
                                --We're working in ticks so adjust energy usage accordingly
                                iCurUnitEnergyUsage = iCurUnitEnergyUsage * 0.1
                                if bDebugMessages == true then LOG(sFunctionRef..': Estimated energy usage='..iCurUnitEnergyUsage) end

                                --Jamming - check via blueprint since no reliable category
                                if oUnit:GetBlueprint().Intel.JamRadius then
                                    if bPauseNotUnpause then M27UnitInfo.DisableUnitJamming(oUnit)
                                    else M27UnitInfo.EnableUnitJamming(oUnit)
                                    end
                                end

                                --Want to pause unit, check for any special logic for pausing
                                oUnit[M27UnitInfo.refbPaused] = bPauseNotUnpause
                                if iCategoryRef == M27UnitInfo.refCategoryPersonalShield or iCategoryRef == M27UnitInfo.refCategoryFixedShield or iCategoryRef == M27UnitInfo.refCategoryMobileLandShield then
                                    if M27UnitInfo.IsUnitShieldEnabled(oUnit) == bPauseNotUnpause then
                                        if bPauseNotUnpause then M27UnitInfo.DisableUnitShield(oUnit)
                                        else M27UnitInfo.EnableUnitShield(oUnit) end
                                    end
                                elseif iCategoryRef == M27UnitInfo.refCategoryRadar then
                                    if bPauseNotUnpause then M27UnitInfo.DisableUnitIntel(oUnit)
                                    else M27UnitInfo.EnableUnitIntel(oUnit)
                                    end
                                elseif iCategoryRef == M27UnitInfo.refCategoryStealthGenerator or iCategoryRef == M27UnitInfo.refCategoryStealthAndCloakPersonal then
                                    if bPauseNotUnpause then M27UnitInfo.DisableUnitStealth(oUnit)
                                    else M27UnitInfo.EnableUnitStealth(oUnit)
                                    end
                                else
                                    --Normal logic - just pause unit
                                    oUnit:SetPaused(bPauseNotUnpause)
                                    if bDebugMessages == true then LOG(sFunctionRef..': Just set paused to '..tostring(bPauseNotUnpause)) end
                                end
                                if bPauseNotUnpause then
                                    table.insert(aiBrain[reftPausedUnits], oUnit)
                                    if bDebugMessages == true then LOG(sFunctionRef..': Added unit to tracker table, size='..table.getn(aiBrain[reftPausedUnits])) end
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': Will remove unit from reftPausedUnits. Size of table before removal='..table.getn(aiBrain[reftPausedUnits])) end
                                    for iPausedUnit, oPausedUnit in aiBrain[reftPausedUnits] do
                                        if oPausedUnit == oUnit then table.remove(aiBrain[reftPausedUnits], iPausedUnit) end
                                    end
                                    if bDebugMessages == true then LOG(sFunctionRef..': Size of table after removal ='..table.getn(aiBrain[reftPausedUnits])) end
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': iEnergySavingManaged='..iEnergySavingManaged..'; iEnergyPerTickSavingNeeded='..iEnergyPerTickSavingNeeded..'; aiBrain[refbStallingEnergy]='..tostring(aiBrain[refbStallingEnergy])) end
                        if aiBrain[refbStallingEnergy] then
                            iEnergySavingManaged = iEnergySavingManaged + iCurUnitEnergyUsage
                            if iEnergySavingManaged > iEnergyPerTickSavingNeeded then
                                bAbort = true
                                break
                            end
                        else
                            iEnergySavingManaged = iEnergySavingManaged - iCurUnitEnergyUsage

                            if iEnergySavingManaged < iEnergyPerTickSavingNeeded then
                                bAbort = true
                                break
                            end
                        end
                    end
                elseif bDebugMessages == true then LOG(sFunctionRef..': We have no units for iCategoryCount='..iCategoryCount)
                end
                if bAbort then break end
            end
            if bDebugMessages == true then LOG(sFunctionRef..'If we have no paused units then will set us as not having an energy stall') end
            if M27Utilities.IsTableEmpty(aiBrain[reftPausedUnits]) == true then
                aiBrain[refbStallingEnergy] = false
                if bDebugMessages == true then LOG(sFunctionRef..': We are no longer stalling energy') end
            elseif bDebugMessages == true then LOG(sFunctionRef..': Size of table='..table.getn(aiBrain[reftPausedUnits]))
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpgradeManager(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpgradeManager'


    local iCycleWaitTime = 40
    local iReducedWaitTime = 20
    local iCurCycleTime

    aiBrain[refbWantMoreFactories] = true
    aiBrain[reftUpgrading] = {}
    aiBrain[refiPausedUpgradeCount] = 0
    aiBrain[refiEnergyStoredLastCycle] = 0
    aiBrain[refbPauseForPowerStall] = false
    aiBrain[reftMassStorageLocations] = {}
    aiBrain[refbWantToUpgradeMoreBuildings] = false
    aiBrain[reftPausedUnits] = {}
    aiBrain[refbStallingEnergy] = false
    aiBrain[reftUnitsToReclaim] = {}
    aiBrain[reftMexesToCtrlK] = {}
    aiBrain[reftT2MexesNearBase] = {}
    aiBrain[refoNearestT2MexToBase] = nil

    --Initial wait:
    WaitTicks(300)
    while(not(aiBrain:IsDefeated())) do
        if aiBrain.M27IsDefeated or M27Logic.iTimeOfLastBrainAllDefeated > 10 then break end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        iCurCycleTime = iCycleWaitTime --default (is shortened if have lots to upgrade)
        ForkThread(UpgradeMainLoop, aiBrain)
        if aiBrain[refbWantToUpgradeMoreBuildings] then iCurCycleTime = iReducedWaitTime end

        ForkThread(GetMassStorageTargets, aiBrain)
        ForkThread(GetUnitReclaimTargets, aiBrain)
        if bDebugMessages == true then LOG(sFunctionRef..': End of loop about to wait '..iCycleWaitTime..' ticks') end

        ForkThread(ManageEnergyStalls, aiBrain)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(iCycleWaitTime)
        if bDebugMessages == true then LOG(sFunctionRef..': End of loop after waiting ticks') end
    end
end

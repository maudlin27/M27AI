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
refbWantForAdjacency = 'M27UnitWantForAdjacency' --Local unit variable; if true then wont reclaim unit even if obsolete

reftMassStorageLocations = 'M27UpgraderMassStorageLocations' --List of all locations where we want a mass storage to be built
reftStorageSubtableLocation = 'M27UpgraderStorageLocationSubtable'
refiStorageSubtableModDistance = 'M27UpgraderStorageModDistance'
local refbWantToUpgradeMoreBuildings = 'M27UpgraderWantToUpgradeMore'
reftUnitsToReclaim = 'M27UnitReclaimShortlist' --list of units we want engineers to reclaim
reftMexesToCtrlK = 'M27EconomyMexesToCtrlK' --Mexes that we want to destroy to rebuild with better ones
reftT2MexesNearBase = 'M27EconomyT2MexesNearBase' --Amphib pathable near base and not upgrading; NOTE - this isnt kept up to date, instead engineer will only refresh the mexes in this if its empty; for now just used by engineer overseer but makes sense to have variable in this code
refoNearestT2MexToBase = 'M27EconomyNearestT2MexToBase' --As per t2mexesnearbase
refbWillCtrlKMex = 'M27EconomyWillCtrlKMex' --true if mex is marked for ctrl-k
refbReclaimNukes = 'M27EconomyReclaimNukes' --true if want to add nuke silos to the reclaim shortlist
reftoTMLToReclaim = 'M27EconomyTMLToReclaim' --any TML flagged to be reclaimed
refbWillReclaimUnit = 'M27EconomyWillReclaimUnit' --Set against a unit, true if will reclaim it

local reftUpgrading = 'M27UpgraderUpgrading' --[x] is the nth building upgrading, returns the object upgrading
refiPausedUpgradeCount = 'M27UpgraderPausedCount' --Number of units where have paused the upgrade
local refbUpgradePaused = 'M27UpgraderUpgradePaused' --flags on particular unit if upgrade has been paused or not

local refiEnergyStoredLastCycle = 'M27EnergyStoredLastCycle'

--ECONOMY VARIABLES - below 4 are to track values based on base production, ignoring reclaim. Provide per tick values so 10% of per second)
refiEnergyGrossBaseIncome = 'M27EnergyGrossIncome'
refiEnergyNetBaseIncome = 'M27EnergyNetIncome'
refiMassGrossBaseIncome = 'M27MassGrossIncome'
refiMassNetBaseIncome = 'M27MassNetIncome'

refiMexesUpgrading = 'M27EconomyMexesUpgrading'
refiMexesAvailableForUpgrade = 'M27EconomyMexesAvailableToUpgrade'
reftActiveHQUpgrades = 'M27EconomyHQActiveUpgrades'

refbStallingEnergy = 'M27EconomyStallingEnergy'
refiLastEnergyStall = 'M27EconomyLastEnergyStall' --Game time in seconds of last power stall
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
        local tEnemyStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)

        local iSegmentX, iSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tOurStartPosition)
        local sPathing = M27UnitInfo.GetUnitPathingType(M27Utilities.GetACU(aiBrain))
        if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
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

    --Dont have any power in shortlist if we are powerstalling (or have in last 10s) or dont have >=99% energy stored
    if not(aiBrain[refbStallingEnergy]) and aiBrain:GetEconomyStoredRatio('ENERGY') > 0.99 and GetGameTimeSeconds() - aiBrain[refiLastEnergyStall] >= 10 then

        --NOTE: DONT ADD conditions above here as T2 power assumes the table is empty

        --Add any old power to the table - T1 and T2 if we have lots of power and T3
        local iT3Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Power)
        if iT3Power >= 1 and aiBrain[refiEnergyGrossBaseIncome] >= 500 then
            --Add all t2 power (unless using it for T3 arti)
            for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT2Power, false, true) do
                if not(oUnit[refbWantForAdjacency]) then
                    oUnit[refbWantForAdjacency] = M27Conditions.IsBuildingWantedForAdjacency(oUnit)
                    if not(oUnit[refbWantForAdjacency]) then
                        table.insert(aiBrain[reftUnitsToReclaim], oUnit)
                    end
                end
            end
        end

        --Reclaim T1 power if we have T2+ power and enough gross income, unless we also have T2 arti
        if (iT3Power >= 1 or aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Power) >= 2) and aiBrain[refiEnergyGrossBaseIncome] >= 110 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryFixedT2Arti) <= 0 then
            --All T1 power
            for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT1Power, false, true) do
                --Check not near to an air factory - will do slightly larger than actual radius needed to be prudent
                tNearbyAdjacencyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirFactory, oUnit:GetPosition(), 6, 'Ally')
                if M27Utilities.IsTableEmpty(tNearbyAdjacencyUnits) == true then
                    if not(oUnit[refbWantForAdjacency]) then
                        oUnit[refbWantForAdjacency] = M27Conditions.IsBuildingWantedForAdjacency(oUnit)
                        if not(oUnit[refbWantForAdjacency]) then
                            table.insert(aiBrain[reftUnitsToReclaim], oUnit)
                        end
                    end
                end
            end
        end
    end

    local tT3Radar = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT3Radar, false, true)
    local tT2Radar = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT2Radar, false, true)
    local bRadarInsideOtherRadarRange
    local bRadarIsConstructed
    --T2 radar if in range of T3
    if M27Utilities.IsTableEmpty(tT3Radar) == false and M27Utilities.IsTableEmpty(tT2Radar) == false then
        --Check T3 radar is constructed
        bRadarIsConstructed = false
        for iUnit, oUnit in tT3Radar do
            if oUnit:GetFractionComplete() == 1 then
                bRadarIsConstructed = true
                break
            end
        end
        if bRadarIsConstructed then
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
    end

    --T1 radar
    if M27Utilities.IsTableEmpty(tT3Radar) == false or M27Utilities.IsTableEmpty(tT2Radar) == false then
        bRadarIsConstructed = false
        if M27Utilities.IsTableEmpty(tT3Radar) == false then
            for iUnit, oUnit in tT3Radar do
                if oUnit:GetFractionComplete() == 1 then
                    bRadarIsConstructed = true
                    break
                end
            end
        end
        if not(bRadarIsConstructed) and M27Utilities.IsTableEmpty(tT2Radar) == false then
            for iUnit, oUnit in tT2Radar do
                if oUnit:GetFractionComplete() == 1 then
                    bRadarIsConstructed = true
                    break
                end
            end
        end
        if bRadarIsConstructed then
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
    end

    --T1 Sonar
    if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT1Sonar) > 0 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Sonar + M27UnitInfo.refCategoryT3Sonar) > 0 then
        --Do we have T1 sonar within range of T2 sonar?
        local tT1Sonar
        for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT2Sonar + M27UnitInfo.refCategoryT3Sonar, false, true) do
            if oUnit:GetFractionComplete() == 1 then
                if bDebugMessages == true then LOG(sFunctionRef..': oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; .Intel='..repr((oUnit:GetBlueprint().Intel or {'nil'}))..'; .Intel.SonarRadius='..(oUnit:GetBlueprint().Intel.SonarRadius or 'nil')) end
                tT1Sonar = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT1Sonar, oUnit:GetPosition(), oUnit:GetBlueprint().Intel.SonarRadius - 115, 'Ally')
                if M27Utilities.IsTableEmpty(tT1Sonar) == false then
                    for iT1Sonar, oT1Sonar in tT1Sonar do
                        if oT1Sonar:GetAIBrain() == aiBrain then
                            table.insert(aiBrain[reftUnitsToReclaim], oT1Sonar)
                        end
                    end
                end
            end
        end
    end

    --Civilian buildings on our side of the map that can be pathed to amphibiously with no enemy units nearby
    local tCivilianBuildings = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 500, 'Neutral')
    local iBasePathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
    if M27Utilities.IsTableEmpty(tCivilianBuildings) == false then
        for iUnit, oUnit in tCivilianBuildings do
            --Are we closer to our base than enemy?
            if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) then
                --Can we path here with an amphibious unit?
                if iBasePathingGroup == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition()) then
                    table.insert(aiBrain[reftUnitsToReclaim], oUnit)
                end
            end

        end
    end

    --Nukes
    if aiBrain[refbReclaimNukes] then
        for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategorySML, false, false) do
            table.insert(aiBrain[reftUnitsToReclaim], oUnit)
        end
    end

    --TML - units are added to a table to be reclaimed when we decide we no longer want to use them
    if M27Utilities.IsTableEmpty(aiBrain[reftoTMLToReclaim]) == false then
        for iUnit, oUnit in aiBrain[reftoTMLToReclaim] do
            if M27UnitInfo.IsUnitValid(oUnit) then
                table.insert(aiBrain[reftUnitsToReclaim], oUnit)
                if bDebugMessages == true then LOG(sFunctionRef..': Adding TML unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to list of units to reclaim') end
            end
        end
    end

    --TMD if no longer up against TML and have low mass
    if aiBrain[M27Overseer.refbEnemyTMLSightedBefore] and M27Utilities.IsTableEmpty(M27Overseer.reftEnemyTML) and M27Conditions.HaveLowMass(aiBrain) then
        for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategoryTMD, false, false) do
            table.insert(aiBrain[reftUnitsToReclaim], oUnit)
        end
    end

    --Flag any units set to be reclaimed
    if M27Utilities.IsTableEmpty(aiBrain[reftUnitsToReclaim]) == false then
        for iUnit, oUnit in aiBrain[reftUnitsToReclaim] do
            oUnit[refbWillReclaimUnit] = true
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
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering mex with unique ref='..oMex.UnitId..M27UnitInfo.GetUnitLifetimeCount(oMex)) end
                    tCurLocation = oMex:GetPosition()
                    for _, tModPosition in tPositionAdjustments do
                        tAdjustedPosition = {tCurLocation[1] + tModPosition[1], GetSurfaceHeight(tCurLocation[1] + tModPosition[1], tCurLocation[3] + tModPosition[2]), tCurLocation[3] + tModPosition[2]}
                        if bDebugMessages == true then LOG(sFunctionRef..': tCurLocation='..repr(tCurLocation)..'; tModPosition='..repr(tModPosition)..'; adjusted position='..repr(tAdjustedPosition)) end
                        sLocationRef = M27Utilities.ConvertLocationToReference(tAdjustedPosition)
                        if M27EngineerOverseer.CanBuildAtLocation(aiBrain, sStorageBP, tAdjustedPosition, M27EngineerOverseer.refActionBuildMassStorage, false) then
                        --if aiBrain:CanBuildStructureAt(sStorageBP, tAdjustedPosition) or (aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionBuildMassStorage]) == false) then
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
                                if EntityCategoryContains(categories.TECH2, oMex.UnitId) then iCurPositionTechAdjust = iDistanceModForTech2 end
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
            if M27UnitInfo.IsUnitValid(oMex) and oMex:GetFractionComplete() == 1 then
                iT2MexCount = iT2MexCount + 1
                tAllT2Mexes[iT2MexCount] = oMex
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Considering mex with position='..repr(oMex:GetPosition()))
                    LOG('Player start position='..repr(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]))
                    LOG('VDist2 between these positions='..VDist2(oMex:GetPosition()[1], oMex:GetPosition()[3], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]))
                end


                iCurDistToBase = M27Utilities.GetDistanceBetweenPositions(oMex:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                if bDebugMessages == true then LOG(sFunctionRef..': Considering mex '..oMex.UnitId..M27UnitInfo.GetUnitLifetimeCount(oMex)..'; iCurDistanceToBase='..iCurDistToBase) end
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

function GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, iUnitCategory, bIgnoreT2SupportFactories)
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
    local iIgnoredSupportCategory

    if bIgnoreT2SupportFactories then
        iIgnoredSupportCategory = categories.SUPPORTFACTORY * categories.TECH2
    end

    for iUnit, oUnit in tAllUnits do
        if not(oUnit.Dead) and oUnit.GetFractionComplete and oUnit:GetFractionComplete() == 1 then
            if not(iIgnoredSupportCategory and EntityCategoryContains(iIgnoredSupportCategory, oUnit.UnitId)) then
                iCurTech = M27UnitInfo.GetUnitTechLevel(oUnit)
                if iCurTech > iHighestTech then iHighestTech = iCurTech end
                if oUnit:IsUnitState('Upgrading') then
                    iUpgradingCount = iUpgradingCount + 1
                    if iCurTech > iHighestFactoryBeingUpgraded then iHighestFactoryBeingUpgraded = iCurTech end
                else
                    if M27Conditions.SafeToUpgradeUnit(oUnit) and not(oUnit[refbWillCtrlKMex]) then
                        iAvailableToUpgradeCount = iAvailableToUpgradeCount + 1
                        if bDebugMessages == true then LOG(sFunctionRef..': iUnit in tAllUnits='..iUnit..'; iAvailableToUpgradeCount='..iAvailableToUpgradeCount..'; Have unit available to upgrading whose unit state isnt upgrading.  UnitId='..oUnit.UnitId..'; Unit State='..M27Logic.GetUnitState(oUnit)..': Upgradesto='..(oUnitBP.General.UpgradesTo or 'nil')) end
                    end
                end
            end
        end
    end
    if iHighestFactoryBeingUpgraded >= iHighestTech then bAreAlreadyUpgradingToHQ = true end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, iUpgradingCount='..iUpgradingCount..'; iAvailableToUpgradeCount='..iAvailableToUpgradeCount) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iUpgradingCount, iAvailableToUpgradeCount, bAreAlreadyUpgradingToHQ
end

function TrackHQUpgrade(oUnitUpgradingToHQ)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'TrackHQUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local aiBrain = oUnitUpgradingToHQ:GetAIBrain()
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code for unit '..oUnitUpgradingToHQ.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitUpgradingToHQ)..'; Game time='..GetGameTimeSeconds()..'; is the table of units upgrading to HQ empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]))) end


    --Check not already in the table
    local bAlreadyRecorded = false
    if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
        for iHQ, oHQ in  aiBrain[reftActiveHQUpgrades] do
            if oHQ == oUnitUpgradingToHQ then
                bAlreadyRecorded = true
                break
            end
        end
    end

    if not(bAlreadyRecorded) then
        table.insert(aiBrain[reftActiveHQUpgrades], oUnitUpgradingToHQ)
        if bDebugMessages == true then LOG(sFunctionRef..': Added unit to table of active HQ upgrades; is table empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]))) end
    elseif bDebugMessages == true then LOG(sFunctionRef..': Already recorded unit in the table of active HQ upgrades so wont add')
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Finished checking if already recorded unit, bAlreadyRecorded='..tostring(bAlreadyRecorded)..'; Size of activeHQUpgrades='..table.getn(aiBrain[reftActiveHQUpgrades])) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicks(10)
    while M27UnitInfo.IsUnitValid(oUnitUpgradingToHQ) do
        if not(oUnitUpgradingToHQ.GetWorkProgress) or oUnitUpgradingToHQ:GetWorkProgress() == 1 then
            if bDebugMessages == true then LOG(sFunctionRef..': Unit '..oUnitUpgradingToHQ.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitUpgradingToHQ)..' either has no work progress or it is 1') end
            break
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Unit '..oUnitUpgradingToHQ.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitUpgradingToHQ)..' hasnt finished upgrade so will continue to monitor.  Work progress='..oUnitUpgradingToHQ:GetWorkProgress()) end
            WaitTicks(1)
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Remove from table of upgrading HQs
    if bDebugMessages == true then LOG(sFunctionRef..': Unit has finished upgrading, so will remove from the list of active HQ upgrades; size of table before removal='..table.getn(aiBrain[reftActiveHQUpgrades])..'; is table empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]))..'; Game time='..GetGameTimeSeconds()) end
    local oHQ
    if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
        for iHQ = table.getn(aiBrain[reftActiveHQUpgrades]), 1, -1 do
            oHQ = aiBrain[reftActiveHQUpgrades][iHQ]
            if not(M27UnitInfo.IsUnitValid(oHQ)) then
                if bDebugMessages == true then LOG(sFunctionRef..': Removing unit from table of active HQ upgrades as it is no longer valid') end
                table.remove(aiBrain[reftActiveHQUpgrades], iHQ)
            --[[else
                if not(oUnitUpgradingToHQ:IsUnitState('Upgrading')) and (not(oUnitUpgradingToHQ.GetWorkProgress) or oUnitUpgradingToHQ:GetWorkProgress() == 1) then
                    table.remove(aiBrain[reftActiveHQUpgrades], iHQ)
                end--]]
            end
        end
    end
    --Update our highest factory tech
    M27Overseer.UpdateHighestFactoryTechTracker(aiBrain)
    if bDebugMessages == true then LOG(sFunctionRef..': Finished removal from the table and calling the UpdateHighestFactoryTechTracker, is table empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]))) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
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
            if bDebugMessages == true then LOG(sFunctionRef..': Have issued upgrade '..sUpgradeID..' to unit '..oUnitToUpgrade.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade)..' and recorded it') end
        end
        --Are we upgrading to a factory HQ? If so then record this as will prioritise it with spare engineers
        --oBlueprint = __blueprints[string.lower(sBlueprintID)]
        --EntityCategoryContains
        if EntityCategoryContains(M27UnitInfo.refCategoryAllFactories, sUpgradeID) then
            if bDebugMessages == true then LOG(sFunctionRef..': sUpgradeID is a factory') end
            if not(EntityCategoryContains(categories.SUPPORTFACTORY, sUpgradeID)) then
                if bDebugMessages == true then LOG(sFunctionRef..': sUpgradeID is not a support factory') end
                ForkThread(TrackHQUpgrade, oUnitToUpgrade)
            end
        end

    else M27Utilities.ErrorHandler('Dont have a valid upgrade ID; UnitID='..oUnitToUpgrade.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade))
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
    --local tEnemyStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
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
            if bDebugMessages == true then
                LOG(sFunctionRef..': iUnit in tAllUnits='..iUnit..'; checking if its valid')
                if M27UnitInfo.IsUnitValid(oUnit) then LOG('Unit is valid, ID='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Unit status='..M27Logic.GetUnitState(oUnit)..'; GameTime='..GetGameTimeSeconds()) end
            end
            if M27UnitInfo.IsUnitValid(oUnit) and not(M27UnitInfo.GetUnitUpgradeBlueprint(oUnit, true) == nil) and not(oUnit:IsUnitState('Upgrading')) then
                if bDebugMessages == true then LOG(sFunctionRef..': Have a unit that is available for upgrading; iUnit='..iUnit..'; Unit ref='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                if M27Conditions.SafeToUpgradeUnit(oUnit) and not(oUnit[refbWillCtrlKMex]) then
                    iPotentialUnits = iPotentialUnits + 1
                    tPotentialUnits[iPotentialUnits] = oUnit
                    if bDebugMessages == true then LOG(sFunctionRef..': Have a potential unit to upgrade, iPotentialUnits='..iPotentialUnits) end
                end
            end
        end
        --Re-do without the safe to upgrade check if we are overflowing mass
        if iPotentialUnits == 0 and M27Utilities.IsTableEmpty(tAllUnits) == false and aiBrain:GetEconomyStoredRatio('MASS') >= 0.9 and aiBrain:GetEconomyStored('MASS') >= 2000 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and not(aiBrain[refbStallingEnergy]) and aiBrain[refiEnergyNetBaseIncome] >= 10 * aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] and aiBrain[refiMassNetBaseIncome] >= 0.5 then
            if bDebugMessages == true then LOG(sFunctionRef..': Are overflowing mass so will redo check without checking if its safe to upgrade the mex') end
            for iUnit, oUnit in tAllUnits do
                if M27UnitInfo.IsUnitValid(oUnit) and not(M27UnitInfo.GetUnitUpgradeBlueprint(oUnit, true) == nil) and not(oUnit:IsUnitState('Upgrading')) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have a unit that is available for upgrading; iUnit='..iUnit..'; Unit ref='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                    if not(oUnit[refbWillCtrlKMex]) then
                        iPotentialUnits = iPotentialUnits + 1
                        tPotentialUnits[iPotentialUnits] = oUnit
                        if bDebugMessages == true then LOG(sFunctionRef..': Have a potential unit to upgrade, iPotentialUnits='..iPotentialUnits) end
                    end
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

            else
                if bDebugMessages == true then LOG(sFunctionRef..': No safe units based on intel and defence coverage; will only include nearest unit if we are overflowing mass') end
                if aiBrain:GetEconomyStoredRatio('MASS') >= 0.9 and aiBrain:GetEconomyStored('MASS') >= 2000 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and not(aiBrain[refbStallingEnergy]) and aiBrain[refiEnergyNetBaseIncome] >= 10 * aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] and aiBrain[refiMassNetBaseIncome] >= 0.5 then
                    oUnitToUpgrade = M27Utilities.GetNearestUnit(tPotentialUnits, tOurStartPosition, aiBrain, false)
                end
            end
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': Dont have any units of the desired category') end
    end

    if oUnitToUpgrade and EntityCategoryContains(M27UnitInfo.refCategoryMex, oUnitToUpgrade.UnitId) and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyTML]) == false then
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
    local bIgnoreT2LandSupport = false
    local bIgnoreT2AirSupport = false

    if aiBrain[M27Overseer.refiOurHighestLandFactoryTech] < 3 then
        if aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 1 and aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.SUPPORTFACTORY) > 0 then bIgnoreT2LandSupport = true
        elseif aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.SUPPORTFACTORY * categories.TECH3) > 0 then   bIgnoreT2LandSupport = true
        end
    end
    if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 then
        if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 1 and aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.SUPPORTFACTORY) > 0 then bIgnoreT2AirSupport = true
        elseif aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.SUPPORTFACTORY * categories.TECH3) > 0 then   bIgnoreT2AirSupport = true
        end
    end




    local iLandFactoryUpgrading, iLandFactoryAvailable, bAlreadyUpgradingLandHQ = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryLandFactory, bIgnoreT2LandSupport)
    local iAirFactoryUpgrading, iAirFactoryAvailable, bAlreadyUpgradingAirHQ = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryAirFactory, bIgnoreT2AirSupport)
    --Double check air factory HQ upgrade due to potential bug
    if bAlreadyUpgradingAirHQ == false and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
        for iUnit, oUnit in aiBrain[reftActiveHQUpgrades] do
            if EntityCategoryContains(refCategoryAirFactory, oUnit.UnitId) then
                bAlreadyUpgradingAirHQ = true
                break
            end
        end
    end


    local iT1LandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.TECH1)
    local iT2LandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.TECH2)
    local iT3LandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.TECH3)
    local iT1AirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.TECH1)
    local iT2AirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.TECH2)
    local iT3AirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.TECH3)
    local iCategoryToUpgrade

    --Special logic for upgrading HQs that takes priority
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Is table of active HQ upgrades empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])) .. '; Highest land fac=' .. aiBrain[M27Overseer.refiOurHighestLandFactoryTech] .. '; highest air fac=' .. aiBrain[M27Overseer.refiOurHighestAirFactoryTech] .. '; T1,2,3 land fac=' .. iT1LandFactories .. '-' .. iT2LandFactories .. '-' .. iT3LandFactories .. '; T1-2-3 air facs=' .. iT1AirFactories .. '-' .. iT2AirFactories .. '-' .. iT3AirFactories)
    end
    if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) then
        if aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 1 and (iT2LandFactories + iT3LandFactories) > 0 then
            --Have lower tech level than we have in factories
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Only have T1 land factory tech available, but have T2 and T3 factories so assuming we lost our HQ')
            end
            if iT1LandFactories > 0 then
                iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1
            end
        elseif aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 2 and iT3LandFactories > 0 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Only have T2 land factory tech available, but have T3 factories so assuming we lost our HQ')
            end
            local iT2LandHQs = aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.TECH2 - categories.SUPPORTFACTORY)
            if iT2LandHQs > 0 then
                iCategoryToUpgrade = refCategoryLandFactory * categories.TECH2 - categories.SUPPORTFACTORY
            elseif iT1LandFactories > 0 then
                iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1
            end
        elseif aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 1 and (iT2AirFactories + iT3AirFactories) > 0 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Only have T1 Air factory tech available, but have T2 and T3 factories so assuming we lost our HQ')
            end
            if iT1AirFactories > 0 then
                iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
            end
        elseif aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 2 and iT3AirFactories > 0 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Only have T2 Air factory tech available, but have T3 factories so assuming we lost our HQ')
            end
            local iT2AirHQs = aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.TECH2 - categories.SUPPORTFACTORY)
            if iT2AirHQs > 0 then
                iCategoryToUpgrade = refCategoryAirFactory * categories.TECH2 - categories.SUPPORTFACTORY
            elseif iT1AirFactories > 0 then
                iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
            end
        end
        -- if have factories of a type that are higher than our recorded highest tech level, it suggests we have lost our HQ and need to get a new one

        --Special logic - upgrade HQ if we have air or land below our highest tech and have 4+ T3 mexes
        if not (iCategoryToUpgrade) then
            if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) and aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 and (aiBrain[M27Overseer.refiOurHighestLandFactoryTech] < 3 and iLandFactoryAvailable > 0) or (aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 and iAirFactoryAvailable > 0) and (iT3Mexes >= 4 or (aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 and iAirFactoryAvailable > 0 and aiBrain[refiEnergyGrossBaseIncome] >= 500 and aiBrain[refiMassGrossBaseIncome] >= 4)) then
                --Want to ugprade either land or air
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Want to upgrade an air or land factory HQ as its below our highest tech level')
                end
                if aiBrain[M27Overseer.refiOurHighestLandFactoryTech] < aiBrain[M27Overseer.refiOurHighestAirFactoryTech] and iLandFactoryAvailable > 0 then
                    --Want a land fac - do we want to upgrade t2, or t1?
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Will upgrade a land factory')
                    end
                    if iT2LandFactories > 0 then
                        iCategoryToUpgrade = refCategoryLandFactory * categories.TECH2
                        if bDebugMessages == true then LOG(sFunctionRef..': Will upgrade a T2 land factory') end
                    else
                        iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1
                        if bDebugMessages == true then LOG(sFunctionRef..': Will upgrade a T1 land factory') end
                    end
                elseif iAirFactoryAvailable > 0 then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Will upgrade an air factory')
                    end
                    if iT2AirFactories > 0 then
                        iCategoryToUpgrade = refCategoryAirFactory * categories.TECH2
                    else
                        iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
                    end
                end
                --Get Air HQ upgrade at same time as land HQ if we have loads of resources and no nearby enemies
            elseif M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false and aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 and iAirFactoryAvailable > 0 then
                local bAirFacUpgrading = false
                for iUnit, oUnit in aiBrain[reftActiveHQUpgrades] do
                    if EntityCategoryContains(M27UnitInfo.refCategoryAirFactory, oUnit.UnitId) then
                        bAirFacUpgrading = true
                        break
                    end
                end
                if not (bAirFacUpgrading) and aiBrain[refiEnergyGrossBaseIncome] >= 500 and aiBrain[refiEnergyNetBaseIncome] >= 100 and aiBrain[refiMassGrossBaseIncome] >= 15 and aiBrain[refiMassNetBaseIncome] >= 1 and aiBrain:GetEconomyStored('MASS') >= 2000 and aiBrain[M27Overseer.refiModDistFromStartNearestThreat] >= 150 then
                    if iT2AirFactories > 0 then
                        iCategoryToUpgrade = refCategoryAirFactory * categories.TECH2
                    else
                        iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
                    end
                end
            end
        elseif bDebugMessages == true then LOG(sFunctionRef..': Have HQ category to upgrade after checking if our factory level is higher than what is recorded suggesting we have lost our HQ')
        end
    else
        if bDebugMessages == true then
            LOG(sFunctionRef..': Already have active HQ upgrades, will list out the units and their work progress')
            for iUnit, oUnit in aiBrain[reftActiveHQUpgrades] do
                if M27UnitInfo.IsUnitValid(oUnit) then
                    LOG(sFunctionRef..': HQ unit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Workpgoress='..oUnit:GetWorkProgress())
                else
                    LOG(sFunctionRef..': HQ Unit isnt valid. iUnit='..iUnit)
                end
            end
        end
    end
    if not (iCategoryToUpgrade) then

        local iUnitUpgrading, iUnitAvailable
        local iRatioOfMexToFactory = 1.1
        --[[if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 then
            if iT3AirFactories > 0 then aiBrain[M27Overseer.refiOurHighestAirFactoryTech] = 3
            elseif iT2AirFactories + iT3AirFactories > 0 then aiBrain[M27Overseer.refiOurHighestAirFactoryTech] = 2 end
        end--]]
        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
            iRatioOfMexToFactory = 3
        end

        function DecideOnFirstHQ()
            --Assumes ahve already checked we have factories available to upgrade and arent upgrading an HQ already
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Deciding on first HQ and if want it to be land or air')
            end
            local iFactoryToUpgrade
            if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 1 then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Deciding whether to upgrade from T1 to T2; aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes]=' .. aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes] .. '; aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat]=' .. aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] .. '; aiBrain[M27Overseer.refiModDistFromStartNearestThreat]=' .. aiBrain[M27Overseer.refiModDistFromStartNearestThreat])
                end
                if iT1AirFactories <= 0 then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Want to upgrade land factory as no T1 factories available to upgrade')
                    end
                    iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH1
                elseif iT1LandFactories <= 0 then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Want to upgrade air factory as no T1 land factories available to upgrade')
                    end
                    iFactoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH1
                else
                    local iEnergyIncomeAdjustForReclaim = 0
                    local iNearbyEnergyReclaim = 0
                    local iBaseSegmentX, iBaseSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    local iMaxAdjust = 13
                    if aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 300 then
                        iMaxAdjust = 4
                    end
                    for iXAdj = -iMaxAdjust, iMaxAdjust do
                        for iZAdj = -iMaxAdjust, iMaxAdjust do
                            iNearbyEnergyReclaim = iNearbyEnergyReclaim + (M27MapInfo.tReclaimAreas[iBaseSegmentX + iXAdj][iBaseSegmentZ + iZAdj][M27MapInfo.refReclaimTotalEnergy] or 0)
                        end

                    end
                    if iNearbyEnergyReclaim >= 1000 then
                        iEnergyIncomeAdjustForReclaim = math.max(-iNearbyEnergyReclaim / 500, -12)
                    end

                    if aiBrain[refiEnergyGrossBaseIncome] <= (42 + iEnergyIncomeAdjustForReclaim) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Energy income too low to support air fac')
                        end
                        if not (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]) and aiBrain[refiMexesAvailableForUpgrade] > 0 then
                            iFactoryToUpgrade = M27UnitInfo.refCategoryT1Mex --Better to not upgrade factory yet and e.g. upgrade a mex than to upgrade land
                        else
                            iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH1
                        end
                    elseif aiBrain[M27AirOverseer.refiTorpBombersWanted] > 0 then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Want to upgrade air factory as need torp bombers')
                        end
                        iFactoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH1 + M27UnitInfo.refCategoryAirFactory * categories.TECH2
                    else
                        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] and (aiBrain[refiEnergyGrossBaseIncome] <= (46 + iEnergyIncomeAdjustForReclaim) or aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes] > 1 or aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] <= math.min(300, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.4) or aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= math.min(200, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.32)) then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Want to upgrade land factory as no T1 factories available to upgrade')
                            end
                            iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH1 + M27UnitInfo.refCategoryLandFactory * categories.TECH2
                        else
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Want to upgrade air factory as either cant path to enemy with land, or only want 1 land fac and nearest enemy is far away')
                            end
                            iFactoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH1 + M27UnitInfo.refCategoryAirFactory * categories.TECH2
                        end
                    end
                end
            else
                local iEnergyIncomeAdjustForReclaim = 0
                local iNearbyEnergyReclaim = 0
                local iBaseSegmentX, iBaseSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                local iMaxAdjust = 13
                if aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 300 then
                    iMaxAdjust = 4
                end
                for iXAdj = -iMaxAdjust, iMaxAdjust do
                    for iZAdj = -iMaxAdjust, iMaxAdjust do
                        iNearbyEnergyReclaim = iNearbyEnergyReclaim + (M27MapInfo.tReclaimAreas[iBaseSegmentX + iXAdj][iBaseSegmentZ + iZAdj][M27MapInfo.refReclaimTotalEnergy] or 0)
                    end
                end
                if iNearbyEnergyReclaim >= 1000 then
                    iEnergyIncomeAdjustForReclaim = math.max(-iNearbyEnergyReclaim / 500, -30)
                end

                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Want to upgrade to T3, will decide if want land or air')
                end
                --Must be wanting to upgrade to T3
                if iT2AirFactories <= 0 then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Have no T2 air facs or <=1.25k energy income gross so will upgrade land fac')
                    end
                    iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH2
                elseif iT2LandFactories <= 0 then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Have no T2 land facs so will upgrade air HQ')
                    end
                    iFactoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH2
                elseif iT2LandFactories > 0 and aiBrain[refiEnergyGrossBaseIncome] <= (120 + iEnergyIncomeAdjustForReclaim) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Gross energy income is below 1.2k so will upgrade land')
                    end
                    iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH2

                elseif M27UnitInfo.IsUnitUnderwater(M27Utilities.GetACU(aiBrain)) and M27Utilities.GetACU(aiBrain)[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage] and GetGameTimeSeconds() - M27Utilities.GetACU(aiBrain)[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage] <= 30 then
                    --Upgrade land if we need torp bombers to help the ACU
                    iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH2
                elseif not (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand]) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Cant path to enemy base with land so will focus on air')
                    end
                    iFactoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH2
                else
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Could go for land or air, consider if enough targets for bomber and no nearby land threats')
                    end
                    --Want to get land normally, but first check if enough targets of opportunity for bombers and enemy has no airAA, in which case get air
                    --Go for air if enemy has no tech3 AA and we dont have nearby enemy land threats
                    local bGetAirNotLand = false
                    if not (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand]) then
                        bGetAirNotLand = true
                    else
                        --Are there nearby land threats?
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Checking if have nearby enemy land threats')
                        end
                        if aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] <= math.min(350, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.4) or aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= math.min(200, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.32) then
                            --Do they have T3 AA or cruisers?
                            local tEnemyBigAirThreats = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3 + M27UnitInfo.refCategoryStructureAA * categories.TECH3 + M27UnitInfo.refCategoryAirAA * categories.TECH3 + M27UnitInfo.refCategoryAirAA * categories.TECH2 * M27Utilities.FactionIndexToCategory(M27UnitInfo.refFactionAeon) + M27UnitInfo.refCategoryCruiserCarrier, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27AirOverseer.refiMaxScoutRadius], 'Enemy')
                            if M27Utilities.IsTableEmpty(tEnemyBigAirThreats) == true and aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] <= math.min(200, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.3) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Enemy has no T3 AA so will check if they have enough unshielded mexes to warrant an early strat bomber')
                                end
                                --Are there enough enemy T2+ mexes that arent shielded?
                                local tEnemyMexes = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryT3Mex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27AirOverseer.refiMaxScoutRadius], 'Enemy')
                                if M27Utilities.IsTableEmpty(tEnemyMexes) == false then
                                    local iPriorityTargets = 0
                                    for iMex, oMex in tEnemyMexes do
                                        if M27Logic.IsTargetUnderShield(aiBrain, oMex, 4000) == false then
                                            iPriorityTargets = iPriorityTargets + 1
                                            if iPriorityTargets >= 5 then
                                                bGetAirNotLand = true
                                                break
                                            end
                                        end
                                    end
                                end
                            elseif bDebugMessages == true then
                                LOG(sFunctionRef .. ': Enemy has T3 AA')
                            end
                        elseif bDebugMessages == true then
                            LOG(sFunctionRef .. ': Nearest enemy land threat is too close; aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat]=' .. aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] .. '; aiBrain[M27Overseer.refiModDistFromStartNearestThreat]=' .. aiBrain[M27Overseer.refiModDistFromStartNearestThreat])
                        end
                    end
                    if bGetAirNotLand then
                        iFactoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH2
                        if bDebugMessages == true then LOG(sFunctionRef..': Will upgrade T2 air factory') end
                    else
                        iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH2
                        if bDebugMessages == true then LOG(sFunctionRef..': Will upgrade T2 land factory') end
                    end
                end
            end
            return iFactoryToUpgrade
        end


        --Special logic for if trying to snipe ACU
        if iAirFactoryAvailable > 0 and iT1AirFactories > 0 and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and M27UnitInfo.IsUnitUnderwater(aiBrain[M27Overseer.refoLastNearestACU]) and (iT2AirFactories + iT3AirFactories) == 0 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Will upgrade air factory. iAirFactoryAvailable='..iAirFactoryAvailable..'; strategy is to kill ACU and enemy aCU is underwater and we dont ahve T2 or T3 air factory yet')
            end
            iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryAirFactory * categories.TECH2
        else
            --Do we have T2 land but not T2 air? If so get T2 air as a high priority if map has water (as may want torp bombers)
            if iAirFactoryAvailable > 0 and iT1AirFactories > 0 and not (bAlreadyUpgradingAirHQ) and aiBrain[M27Overseer.refiOurHighestLandFactoryTech] >= 2 and aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 1 and aiBrain[refiEnergyGrossBaseIncome] >= 60 and
                    ((M27MapInfo.bMapHasWater and (aiBrain[refiMassGrossBaseIncome] >= 6 or (aiBrain:GetEconomyStoredRatio('MASS') > 0.01 and aiBrain[refiMassGrossBaseIncome] >= 4))) or (aiBrain[refiEnergyGrossBaseIncome] >= 75 and (aiBrain[refiMassGrossBaseIncome] >= 8.5 or (aiBrain:GetEconomyStoredRatio('MASS') > 0.05 and aiBrain[refiMassGrossBaseIncome] >= 6.5)))) then
                iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
                if bDebugMessages == true then LOG(sFunctionRef..': Will upgrade T1 air factory') end
            else
                if iMaxToBeUpgrading > (iLandFactoryUpgrading + aiBrain[refiMexesUpgrading] + iAirFactoryUpgrading) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Arent already upgrading the max amount wanted; iMaxToBeUpgrading=' .. iMaxToBeUpgrading .. '; iLandFactoryUpgrading=' .. iLandFactoryUpgrading .. '; aiBrain[refiMexesUpgrading]=' .. aiBrain[refiMexesUpgrading] .. '; iAirFactoryUpgrading=' .. iAirFactoryUpgrading .. '; will check if want to prioritise HQ upggrades; M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])) .. '; aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]=' .. aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] .. '; iLandFactoryUpgrading=' .. iLandFactoryUpgrading .. '; iAirFactoryUpgrading=' .. iAirFactoryUpgrading .. '; iT1AirFactories=' .. iT1AirFactories .. '; iT2AirFactories=' .. iT2AirFactories .. '; iT1LandFactories=' .. iT1LandFactories .. '; iT2LandFactories=' .. iT2LandFactories .. '; iT2Mexes=' .. iT2Mexes .. '; iT3Mexes=' .. iT3Mexes .. '; aiBrain[refiMassGrossBaseIncome]=' .. aiBrain[refiMassGrossBaseIncome] .. '; aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes]=' .. aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes])
                    end
                    --Get T2 HQ so can get T2 as soon as start having significant mass income, regardless of strategy
                    if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 1 and (aiBrain[refiMassGrossBaseIncome] >= 4 or iT2Mexes + iT3Mexes >= 2) and iAirFactoryAvailable + iLandFactoryAvailable > 0 and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == true and iT2AirFactories + iT3AirFactories + iT2LandFactories + iT3LandFactories == 0 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Will get HQ upgrade') end
                        iCategoryToUpgrade = DecideOnFirstHQ()
                        --Get T3 HQ with similar scenario
                    elseif aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 2 and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == true and iT3LandFactories + iT3AirFactories == 0 and iT2LandFactories + iT2AirFactories > 0 and (aiBrain[refiMassGrossBaseIncome] >= 11 or iT3Mexes >= 4) and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Power + M27UnitInfo.refCategoryT3Power) > 0 then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Want to get T3 factory upgrade, will decide if want ot get land or air factory')
                        end
                        iCategoryToUpgrade = DecideOnFirstHQ()
                    else
                        if aiBrain[refiMexesAvailableForUpgrade] > 0 then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Setting unit to upgrade to be T1+T2 mex as default, will now consider changing this')
                            end
                            iCategoryToUpgrade = refCategoryT1Mex + refCategoryT2Mex --Default
                        end
                        if aiBrain[refiMexesUpgrading] == 0 and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech and aiBrain[refiMexesAvailableForUpgrade] > 0 then
                            --Just stick with upgrading a mex, no change
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': No change will stick with mexes')
                            end
                        else
                            --Dont upgrade factory if we have an HQ upgrade going on
                            if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
                                local bClearUpgrades = true
                                for iHQ, oHQ in aiBrain[reftActiveHQUpgrades] do
                                    if M27UnitInfo.IsUnitValid(oHQ) then
                                        bClearUpgrades = false
                                        break
                                    end
                                end
                                if bClearUpgrades then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Clearing all active HQ upgrades as none of them are of a valid unit any more')
                                    end
                                    aiBrain[reftActiveHQUpgrades] = {}
                                end
                            end
                            if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == true then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Dont have any active HQ upgrades; Have enough available units to upgrade; have started by setting upgrade to mex as default')
                                end
                                --Do we need torpedo bombers and cant build them fast enough?
                                if iAirFactoryAvailable > 0 and iT2AirFactories + iT3AirFactories + iAirFactoryUpgrading == 0 and aiBrain[M27AirOverseer.refiTorpBombersWanted] > 0 then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Will look to upgrade air fac')
                                    end
                                    iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryAirFactory * categories.TECH2
                                elseif aiBrain[M27AirOverseer.refiTorpBombersWanted] > 5 and iAirFactoryUpgrading == 0 and (iAirFactoryAvailable - iT2AirFactories) > 0 then
                                    iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryAirFactory * categories.TECH2
                                else
                                    --Get t2 mex before T2 HQ
                                    local iMinT2MexesWanted = 2
                                    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
                                        iMinT2MexesWanted = 4
                                    end
                                    if aiBrain[refiMexesAvailableForUpgrade] == 0 or aiBrain[refiMexesUpgrading] + iT2Mexes + iT3Mexes >= 2 then
                                        --Do we want to improve build power instead of getting mexes?
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Deciding if want to improve build power instead of mexes. Factory value=' .. (iLandFactoryUpgrading + iT2LandFactories + iAirFactoryUpgrading + iT2AirFactories) + (iT3LandFactories + iT3AirFactories) * 1.5 .. '; Mex value=' .. ((aiBrain[refiMexesUpgrading] + iT2Mexes) + iT3Mexes * 3) .. '; iRatioOfMexToFactory=' .. iRatioOfMexToFactory .. '; aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused]=' .. aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused])
                                        end
                                        if (iLandFactoryUpgrading + iT2LandFactories + iAirFactoryUpgrading + iT2AirFactories) + (iT3LandFactories + iT3AirFactories) * 1.5 < ((aiBrain[refiMexesUpgrading] + iT2Mexes) + iT3Mexes * 3) * iRatioOfMexToFactory and aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused] == 0 then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Want to upgrade build power if we have factories available and enough engis of our highest tech level. bAlreadyUpgradingLandHQ=' .. tostring((bAlreadyUpgradingLandHQ or false)) .. '; bAlreadyUpgradingAirHQ=' .. tostring((bAlreadyUpgradingAirHQ or false)) .. '; Number of engis of current tech level=' .. table.getn(aiBrain:GetListOfUnits(M27UnitInfo.refCategoryEngineer * M27UnitInfo.ConvertTechLevelToCategory(aiBrain[M27Overseer.refiOurHighestFactoryTechLevel])), false, true) .. '; Gross energy income=' .. aiBrain[refiEnergyGrossBaseIncome] .. '; Mexes near start=' .. table.getn(M27MapInfo.GetResourcesNearTargetLocation(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 30, true)))
                                            end
                                            --Want to upgrade build power; do we want an HQ?

                                            if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] < 2 and aiBrain:GetListOfUnits(M27UnitInfo.refCategoryEngineer * M27UnitInfo.ConvertTechLevelToCategory(aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]), false, true) >= 3 and aiBrain[refiEnergyGrossBaseIncome] >= 50 then
                                                iCategoryToUpgrade = DecideOnFirstHQ()
                                            elseif aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 2 and (iT2Mexes + iT3Mexes) >= math.min(8, table.getn(M27MapInfo.GetResourcesNearTargetLocation(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 30, true))) and aiBrain[refiEnergyGrossBaseIncome] >= 100 then
                                                iCategoryToUpgrade = DecideOnFirstHQ()
                                            elseif aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 2 then
                                                --Dont want to upgrade an HQ, consider upgrading a support factory as well providing it wont be upgraded to an HQ
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Dont want to upgrade an HQ yet, want more engineers or power first')
                                                end
                                                --Are at T2 going to T3, so can upgrade T1 factories
                                                if iT2LandFactories > 0 and iT2AirFactories == 0 then
                                                    iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1
                                                elseif iT2LandFactories > 0 and iT2AirFactories > 0 then
                                                    iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryLandFactory * categories.TECH1
                                                elseif iT2AirFactories > 0 then
                                                    iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
                                                end
                                            else
                                                --Already at tech 3
                                                if iAirFactoryAvailable == 0 then
                                                    iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1 + refCategoryLandFactory * categories.TECH2
                                                elseif iLandFactoryAvailable == 0 then
                                                    iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryAirFactory * categories.TECH2
                                                else
                                                    --Have both land and air available so pick the best one
                                                    if (iT3AirFactories > 0 and iT3LandFactories == 0) or (iT3AirFactories > iT3LandFactories and aiBrain[refiEnergyGrossBaseIncome] <= 300) then
                                                        iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1 + refCategoryLandFactory * categories.TECH2
                                                    else
                                                        local iFactoryToAirRatio = (iLandFactoryUpgrading * 2 + iT1LandFactories + iT2LandFactories * 2 + iT3LandFactories * 3) / math.max(1, iAirFactoryUpgrading * 2 + iT1AirFactories + iT2AirFactories * 2 + iT3AirFactories * 3)
                                                        local iDesiredFactoryToAirRatio = aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] / math.max(1, aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir])
                                                        if iAirFactoryAvailable > 0 and iFactoryToAirRatio > iDesiredFactoryToAirRatio and aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir] > (iAirFactoryUpgrading + iAirFactoryAvailable) and not (bAlreadyUpgradingAirHQ) then
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': Want to upgrade air factory')
                                                            end
                                                            iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryAirFactory * categories.TECH2
                                                        elseif iLandFactoryAvailable > 0 and not (bAlreadyUpgradingLandHQ) and (iLandFactoryAvailable + iT3LandFactories + iT3AirFactories + iAirFactoryAvailable) > 1 then
                                                            --Dont want to upgrade our only land factory taht can produce units if we have no other available factories (including air, to allow for maps where we go for only 1 land fac)
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': Want to upgrade land factory')
                                                            end
                                                            iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1 + refCategoryLandFactory * categories.TECH2
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            elseif bDebugMessages == true then LOG(sFunctionRef..': Have active HQ upgrade so wont get a factory to upgrade (meaning will go with default of upgrading a mex')
                            end
                        end
                    end
                    if not(iCategoryToUpgrade) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Not determined any category to upgrade from the preceding logic, so will upgrade mex if we have any, or if not then T2 factory, or if not then T1 factory') end
                        if aiBrain[refiMexesAvailableForUpgrade] > 0 then iCategoryToUpgrade = M27UnitInfo.refCategoryT1Mex + M27UnitInfo.refCategoryT2Mex
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Dont have any mexes available for upgrade so will try a factory instead') end
                            if iLandFactoryUpgrading == 0 and iLandFactoryAvailable > 0 then
                                if aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 3 then
                                    if iT2LandFactories > 0 then iCategoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH2
                                    else iCategoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH1
                                    end
                                else
                                    if iT1LandFactories > 0 then iCategoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH1
                                    elseif iT2LandFactories > 0 then iCategoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH2
                                    end
                                end
                            elseif iAirFactoryUpgrading == 0 and iAirFactoryAvailable > 0 then
                                if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 3 then
                                    if iT2AirFactories > 0 then iCategoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH2
                                    else iCategoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH1
                                    end
                                else
                                    if iT1AirFactories > 0 then iCategoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH1
                                    elseif iT2AirFactories > 0 then iCategoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH2
                                    end
                                end
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Cant find anything to upgrade, will just say to upgrade a mex, so then the backup logic should kick in to try and upgrade soemthing else instead') end
                                iCategoryToUpgrade = M27UnitInfo.refCategoryT1Mex + M27UnitInfo.refCategoryT2Mex
                            end
                        end
                    end
                end
            end
        end
    end
    if not(iCategoryToUpgrade) then M27Utilities.ErrorHandler('No category to upgrade specified', true) end
    if bDebugMessages == true then
        if iCategoryToUpgrade == nil then

            LOG(sFunctionRef .. ': Dont have a category to upgrade')
        else
            LOG(sFunctionRef .. ': Have a category to upgrade, number of untis of that category=' .. aiBrain:GetCurrentUnits(iCategoryToUpgrade)..'; Blueprints that meet that category='..repr(EntityCategoryGetUnitList(iCategoryToUpgrade)))
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
                        --if oUnit.GetUnitId then sUnitReasonForClear = oUnit.UnitId..':'..sUnitReasonForClear end
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

    function InternalUnpauseUpgrade(oUnit)
        if bDebugMessages == true then LOG(sFunctionRef..': Units upgrade is paused, will unpause now') end
        iAmountToUnpause = iAmountToUnpause - 1
        oUnit:SetPaused(false)
        oUnit[refbUpgradePaused] = false
        aiBrain[refiPausedUpgradeCount] = aiBrain[refiPausedUpgradeCount] - 1
        bNoUnitsFound = false
    end
    while iAmountToUnpause > 0 do
        iLoopCount = iLoopCount + 1
        if iLoopCount > iMaxLoopCount then M27Utilities.ErrorHandler('Infinite loop detected') break end
        if M27Utilities.IsTableEmpty(aiBrain[reftUpgrading]) == false then
            bNoUnitsFound = true
            --First unpause any HQs that are paused
            if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
                for iHQ, oHQ in aiBrain[reftActiveHQUpgrades] do
                    if M27UnitInfo.IsUnitValid(oHQ) and oHQ[refbUpgradePaused] then
                        InternalUnpauseUpgrade(oHQ)
                    end
                end
            end

            if bNoUnitsFound then
                for iRef, oUnit in aiBrain[reftUpgrading] do
                    if bDebugMessages == true then LOG(sFunctionRef..': Cycling through units in reftUpgrading; iRef='..iRef) end
                    if M27UnitInfo.IsUnitValid(oUnit) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have a valid unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..';, checking if it has a paused upgrade, oUnit[refbUpgradePaused]='..tostring(oUnit[refbUpgradePaused])) end
                        if oUnit[refbUpgradePaused] == true then
                            InternalUnpauseUpgrade(oUnit)
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Unit not valid so must be an old record') end
                        iOldRecordCount = iOldRecordCount + 1
                    end
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
                        local bIsHQUpgrade = false
                        --Dont pause if is an HQ
                        if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
                            for iHQ, oHQ in  aiBrain[reftActiveHQUpgrades] do
                                if oHQ == oUnit then
                                    bIsHQUpgrade = true
                                    break
                                end
                            end
                        end
                        if not(bIsHQUpgrade) then

                            sUnitId = oUnit.UnitId
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
                                    if oUnit.UnitBeingBuilt.GetUnitId then LOG(sFunctionRef..': ID of unit being built='..oUnit.UnitBeingBuilt.UnitId) end
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

    if bDebugMessages == true then LOG(sFunctionRef..': iMassStored='..iMassStored..'; iEnergyStored='..iEnergyStored..'; iMassNetIncome='..iMassNetIncome..'; iEnergyNetIncome='..iEnergyNetIncome..'; Time of last power stall='..aiBrain[refiLastEnergyStall]..'; Game time='..GetGameTimeSeconds()) end

    local bHaveLotsOfFactories = false
    local iMexCount = aiBrain:GetCurrentUnits(refCategoryMex)
    local iMexesOnOurSideOfMap = GetMexCountOnOurSideOfMap(aiBrain)
    local iLandFactoryCount = aiBrain:GetCurrentUnits(refCategoryLandFactory)
    local iAirFactoryCount = aiBrain:GetCurrentUnits(refCategoryAirFactory)
    if iLandFactoryCount >= 10 then bHaveLotsOfFactories = true end
    local bWantMoreFactories = false
    if iLandFactoryCount < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] then bWantMoreFactories = true
    elseif iAirFactoryCount < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir] then bWantMoreFactories = true end

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
        local tMassThresholds = {}
        aiBrain[refiMexesUpgrading], aiBrain[refiMexesAvailableForUpgrade] = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryT1Mex + refCategoryT2Mex)

        local iT1MexesNearBase = 0
        local tAllT1Mexes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT1Mex, false, true)
        if M27Utilities.IsTableEmpty(tAllT1Mexes) == false then
           for iT1Mex, oT1Mex in tAllT1Mexes do
               if M27UnitInfo.IsUnitValid(oT1Mex) and M27Utilities.GetDistanceBetweenPositions(oT1Mex:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 90 and M27Conditions.SafeToUpgradeUnit(oT1Mex) then
                   iT1MexesNearBase = iT1MexesNearBase + 1
               end
           end
        end
        local iT2MexesUpgrading, iT2MexesAvailableForUpgrade = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryT2Mex)

        local bWantHQEvenWithLowMass = false
        --Alternative to mass threshold - try and get an HQ even if we have low mass in certain cases
        if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == true then
            --Not got an existing HQ upgrade in progress; Do we already have a t3 factory but have another factory type of a lower tech level, and have 3+ T3 mexes?
            if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 and (aiBrain[M27Overseer.refiOurHighestLandFactoryTech] < 3 and iLandFactoryCount > 0) or (aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 and iAirFactoryCount > 0) then
                if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex) >= 3 or (aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 and iAirFactoryCount > 0 and aiBrain[refiEnergyGrossBaseIncome] >= 500 and aiBrain[refiMassGrossBaseIncome] >= 4) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Want to ugprade factory that has lower HQ to our highest HQ level; M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]))) end
                    bWantHQEvenWithLowMass = true
                end
            end
        end

        local iPausedMexes = 0
        if M27Utilities.IsTableEmpty(aiBrain[reftUpgrading]) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Have paused units; size of table='..table.getn(aiBrain[reftPausedUnits])) end
            for iUnit, oUnit in aiBrain[reftUpgrading] do
                if M27UnitInfo.IsUnitValid(oUnit) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Upgrading unit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Unit state='..M27Logic.GetUnitState(oUnit)..'; IsPaused='..tostring(oUnit:IsPaused())..'; refbUpgradePaused='..tostring(oUnit[refbUpgradePaused])) end
                    if oUnit[refbUpgradePaused] then
                        if EntityCategoryContains(M27UnitInfo.refCategoryMex, oUnit.UnitId) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Unit is a mex so noting it as paused') end
                            iPausedMexes = iPausedMexes + 1
                        end
                    end
                end
            end
        elseif bDebugMessages == true then LOG(sFunctionRef..': aiBrain[reftPausedUnits] is empty')
        end




        --Ecoing strategy - want to have a mex ugprading at all times regardless of mass income if we have mexes available to upgrade and arent getting an HQ upgrade and have at least 6 T1 mexes
        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech and aiBrain[refiMassGrossBaseIncome] >= 1.4 and aiBrain[refiMexesUpgrading] - iPausedMexes <= 0 and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildT3MexOverT2]) and (aiBrain[refiMexesAvailableForUpgrade] > 0 or iPausedMexes > 0) and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) then
            tMassThresholds[1] = {0, -10}
        elseif bWantHQEvenWithLowMass or (aiBrain[refiPausedUpgradeCount] >= 1 and table.getn(aiBrain[reftUpgrading]) <= 1) then --Want to resume unless we're energy stalling
            if bDebugMessages == true then LOG(sFunctionRef..': Have paused upgrades, and nothing is currently upgrading, so want to resume one of the upgrades hence setting mass thresholds really low') end
            tMassThresholds[1] = {0, -2.0}
            tMassThresholds[2] = {500, -8}
            tMassThresholds[3] = {1000, -25}
            tMassThresholds[4] = {2500,-200}
        elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech and ((aiBrain[refiPausedUpgradeCount] >= 1 and iPausedMexes == aiBrain[refiMexesUpgrading]) or (aiBrain[refiMexesUpgrading] <= 0 and aiBrain[refiMexesAvailableForUpgrade] > 0 and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildT3MexOverT2]) == true)) then
            if bDebugMessages == true then LOG(sFunctionRef..': Want to eco but dont have any active mex upgrades') end
            tMassThresholds[1] = {0, -100.0}
            tMassThresholds[2] = {1000, -200}
        elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech and iT2MexesUpgrading <= 0 and (iPausedMexes > 0 or (M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildT3MexOverT2]) == true and aiBrain[refiMexesUpgrading] <= iT1MexesNearBase and aiBrain[refiMexesAvailableForUpgrade] > 0)) then
            if bDebugMessages == true then LOG(sFunctionRef..': Want to eco, dont have any active t2 upgrades, so will either unpause paused mex upgrades, or will start a new upgrade if we arent planning to ctrl-K a T2 mex') end
            local iFullStorageAmount = 1000 --Base value for if we have 0% stored ratio
            tMassThresholds[1] = {math.min(400, iFullStorageAmount * 0.1), 0.0}
            tMassThresholds[2] = {math.min(800, iFullStorageAmount * 0.15), -0.3}
            tMassThresholds[3] = {math.min(1300, iFullStorageAmount * 0.35), -1}
            tMassThresholds[4] = {math.min(1500, iFullStorageAmount * 0.45), -2}
            tMassThresholds[5] = {math.min(2000, iFullStorageAmount * 0.55), -3}
            tMassThresholds[6] = {iFullStorageAmount * 0.8, -4}
            tMassThresholds[7] = {iFullStorageAmount * 0.98,-10}
        else
            if aiBrain[refiMassGrossBaseIncome] <= 15 then
                if bDebugMessages == true then LOG(sFunctionRef..': Arent ecoing and our mass income is less tahn 150') end
                tMassThresholds[1] = {400, 1}
                tMassThresholds[2] = {500, 0.5}
                tMassThresholds[3] = {600, 0.1}
                tMassThresholds[4] = {700, -0.1}
                tMassThresholds[5] = {750, -0.2}
            else
                local iFullStorageAmount = 1000 --Base value for if we have 0% stored ratio
                if aiBrain:GetEconomyStoredRatio('MASS') > 0 then iFullStorageAmount = aiBrain:GetEconomyStored('MASS') / aiBrain:GetEconomyStoredRatio('MASS') end

                --Are we already upgrading a T2 mex, and either have recently powerstalled, or dont have much gross mass income (so we probably cant support multiple mex upgrades)
                if iT2MexesUpgrading > 0 and (GetGameTimeSeconds() - aiBrain[refiLastEnergyStall] <= 45 or aiBrain[refiMassGrossBaseIncome] <= 7.5) then
                    tMassThresholds[1] = {math.min(750, iFullStorageAmount * 0.1), 2.4}
                    tMassThresholds[2] = {math.min(1500, iFullStorageAmount * 0.15), 1.2}
                    tMassThresholds[3] = {math.min(2000, iFullStorageAmount * 0.35), 0.6}
                    tMassThresholds[4] = {math.min(2500, iFullStorageAmount * 0.45), 0.2}
                    tMassThresholds[5] = {math.min(3000, iFullStorageAmount * 0.55), 0}
                    tMassThresholds[6] = {iFullStorageAmount * 0.8, -0.2}
                    tMassThresholds[7] = {iFullStorageAmount * 0.9,-1.5}
                else
                    --if aiBrain[refiPausedUpgradeCount] > 1 or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
                    tMassThresholds[1] = {math.min(500, iFullStorageAmount * 0.1), 0.1}
                    tMassThresholds[2] = {math.min(1000, iFullStorageAmount * 0.15), 0}
                    tMassThresholds[3] = {math.min(1500, iFullStorageAmount * 0.35), -0.5}
                    tMassThresholds[4] = {math.min(1750, iFullStorageAmount * 0.45), -1.5}
                    tMassThresholds[5] = {math.min(3000, iFullStorageAmount * 0.55), -2.5}
                    tMassThresholds[6] = {iFullStorageAmount * 0.8, -4}
                    tMassThresholds[7] = {iFullStorageAmount * 0.98,-10}
                end
            end
        end

        --Increase thresholds if we're trying to build a missile
        if aiBrain[M27EngineerOverseer.refbNeedResourcesForMissile] then
            if bDebugMessages == true then LOG(sFunctionRef..': Are trying to buidl a missile so will decrease thresholds') end
            for iThresholdRef, tThreshold in tMassThresholds do
                tMassThresholds[iThresholdRef][1] = tMassThresholds[iThresholdRef][1] + math.max(500, tMassThresholds[iThresholdRef][1] * 0.5)
                tMassThresholds[iThresholdRef][2] = tMassThresholds[iThresholdRef][2] + 1
            end
        end

        --Increase thresholds if we are trying to ctrl-K a mex
        if aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildT3MexOverT2]) == false then
            if bDebugMessages == true then
                LOG(sFunctionRef..': Trying to ctrlK a mex so increasing mass thresholds; will produce tMassThresholds below')
                if M27Utilities.IsTableEmpty(tMassThresholds) then M27Utilities.ErrorHandler('tMassThresholds is empty')
                else LOG(repr(tMassThresholds))
                end
            end

            for iThresholdRef, tThreshold in tMassThresholds do
                tMassThresholds[iThresholdRef][1] = tMassThresholds[iThresholdRef][1] + 2000
            end
        end


        aiBrain[refbWantMoreFactories] = bWantMoreFactories

        for _, tThreshold in tMassThresholds do
            if iMassStored >= tThreshold[1] and iMassNetIncome >= tThreshold[2] then bHaveHighMass = true break end
        end

        if bDebugMessages == true then
            LOG(sFunctionRef..': Finished calculating mass thresholds='..repr(tMassThresholds)..'; bHaveHighmass='..tostring(bHaveHighMass)..'; iPausedMexes='..iPausedMexes..'; aiBrain[refiMexesUpgrading]='..aiBrain[refiMexesUpgrading])
            LOG(sFunctionRef..': bWantMoreFactories='..tostring(bWantMoreFactories)..'; iLandFactoryCount='..iLandFactoryCount..'; iMexesOnOurSideOfMap='..iMexesOnOurSideOfMap..'; bHaveHighMass='..tostring(bHaveHighMass)..'; iMassStored='..iMassStored..'; iMassNetIncome='..iMassNetIncome)
        end

        --Low mass override
        if M27Conditions.HaveLowMass(aiBrain) == true and (aiBrain[refiMexesUpgrading] - iPausedMexes) >= 2 then
            if bDebugMessages == true then LOG(sFunctionRef..': Low mass override - standard low mass condition is failed, and are upgrading more than 1 mex at once, so want to pause one of them') end
            bHaveHighMass = false
        end


        if bHaveHighMass == true then
            if not(aiBrain[refbStallingEnergy]) or (aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and aiBrain[refiEnergyNetBaseIncome] >= 25)  then
                --Do we have any power plants of the current tech level? If not, then hold off on upgrades until we do, unless we have lots of power already
                if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] <= 1 or aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * M27UnitInfo.ConvertTechLevelToCategory(aiBrain[M27Overseer.refiOurHighestFactoryTechLevel])) > 0 or (aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and aiBrain[refiEnergyGrossBaseIncome] > 25 * aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] * (aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] - 1)) then
                    --Have we powerstalled at T2+ in last 15s?
                    if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] <= 1 or GetGameTimeSeconds() - aiBrain[refiLastEnergyStall] >= 15 then
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
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Are at T2+ and have powerstalled in last 15m')
                        --still ok to upgrade a max of 1 if we have good power (500 net at T2, 1k net at T3)
                            if iEnergyPercentStorage >= 0.99 and aiBrain[refiEnergyNetBaseIncome] >= 25 * aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] * (aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] - 1) then
                                iMaxToUpgrade = 1
                            end
                        end
                    end
                elseif bDebugMessages == true then LOG(sFunctionRef..': Are stalling energy and dont have 100% stored with decent net income')
                end
            elseif bDebugMessages == true then LOG(sFunctionRef..': Are stalling energy so wont upgrade more')
            end
        end



        if iMaxToUpgrade == 0 then
            if bDebugMessages == true then LOG(sFunctionRef..': Dont have enough resources to upgrade, checking if should pause upgrades') end
            --Check for low energy amounts
            local bLowEnergy = aiBrain[refbStallingEnergy]
            if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 1 then
                if iEnergyStored <= 250 and iEnergyNetIncome < 0 then bLowEnergy = true
                elseif iEnergyStored <= 50 then bLowEnergy = true
                end
            elseif (aiBrain:GetEconomyStoredRatio('ENERGY') < 0.4 and iEnergyNetIncome < 0) or aiBrain:GetEconomyStoredRatio('ENERGY') < 0.2 then
                bLowEnergy = true
            end

            if bLowEnergy == true then
                if bDebugMessages == true then LOG(sFunctionRef..': Have low energy so will flag we want to pause an upgrade') end
                iMaxToUpgrade = -1
                aiBrain[refbPauseForPowerStall] = true
            else
                --Check for mass stall if we have more than 1 mex or any factories upgrading, or have nearby enemy
                local iLandFactoryUpgrading, iLandFactoryAvailable, bAlreadyUpgradingLandHQ = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryLandFactory)
                local iAirFactoryUpgrading, iAirFactoryAvailable, bAlreadyUpgradingAirHQ = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryAirFactory)

                if (aiBrain[refiMexesUpgrading] - iPausedMexes) > 1 or iLandFactoryUpgrading + iAirFactoryUpgrading > 0 or aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= 100 or aiBrain[M27Overseer.refiPercentageOutstandingThreat] <= 0.3 then
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


    local iCheatMod = 1
    if aiBrain.CheatEnabled then iCheatMod = tonumber(ScenarioInfo.Options.CheatMult) or 2 end
    aiBrain[refiEnergyGrossBaseIncome] = (iACUEnergy + iT3PowerCount * iEnergyT3Power + iT2PowerCount * iEnergyT2Power + iT1PowerCount * iEnergyT1Power + iHydroCount * iEnergyHydro)*iPerTickFactor*iCheatMod
    aiBrain[refiEnergyNetBaseIncome] = aiBrain[refiEnergyGrossBaseIncome] - iEnergyUsage
    aiBrain[refiMassGrossBaseIncome] = (iACUMass + iT3MexMass * iT3MexCount + iT2MexMass * iT2MexCount + iT1MexMass * iT1MexCount + iStorageIncomeBoost)*iPerTickFactor*iCheatMod
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
            if bDebugMessages == true then LOG(sFunctionRef..': Checking if upgrades to be unpaused; iPausedUpgradeCount='..(aiBrain[refiPausedUpgradeCount] or 0)) end
            UnpauseUpgrades(aiBrain, iMaxToBeUpgrading)
            if bDebugMessages == true then LOG(sFunctionRef..'; iAmountToUpgradeAfterUnpausing='..iAmountToUpgradeAfterUnpausing..'; Paused upgrade count='..(aiBrain[refiPausedUpgradeCount] or 0)) end
            if iAmountToUpgradeAfterUnpausing > 0 then
                if bDebugMessages == true then LOG(sFunctionRef..': WIll look for a category to start upgrading as well') end
                iCategoryToUpgrade = DecideWhatToUpgrade(aiBrain, iMaxToBeUpgrading)

                if iCategoryToUpgrade then
                    if bDebugMessages == true then LOG(sFunctionRef..': Got category to upgrade') end
                    oUnitToUpgrade = GetUnitToUpgrade(aiBrain, iCategoryToUpgrade, tStartPosition)
                    if oUnitToUpgrade == nil then
                        --One likely explanation for htis is that there are enemies near the units of the category wanted
                        if bDebugMessages == true then LOG(sFunctionRef..': Couldnt find unit to upgrade, will revert to default categories, starting with T1 mex') end
                        oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryT1Mex, tStartPosition)
                        if oUnitToUpgrade == nil then
                            if bDebugMessages == true then LOG(sFunctionRef..': Will look for T2 mex') end
                            oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryT2Mex, tStartPosition)
                            if oUnitToUpgrade == nil then
                                if bDebugMessages == true then LOG(sFunctionRef..': Will look for T1 land factory') end
                                oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryLandFactory * categories.TECH1, tStartPosition)
                                if oUnitToUpgrade == nil then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Will look for T1 air factory') end
                                    oUnitToUpgrade = GetUnitToUpgrade(aiBrain, M27UnitInfo.refCategoryAirFactory * categories.TECH1, tStartPosition)
                                    if oUnitToUpgrade == nil then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Will look for T2 land factory') end
                                        oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryLandFactory * categories.TECH2, tStartPosition)
                                        if oUnitToUpgrade == nil then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Will look for T2 air factory') end
                                            oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryAirFactory * categories.TECH2, tStartPosition)
                                            if oUnitToUpgrade == nil then
                                                --Do we have enemies within 100 of our base? if so then this is probably why we cant find anything to upgrade as buildings check no enemies within 90
                                                if aiBrain[M27Overseer.refiModDistFromStartNearestThreat] > 100 then
                                                    --Do we have any T1 or T2 factories or mexes within 100 of our base? If not, then we have presumably run out of units to upgrade
                                                    local tNearbyUpgradables = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAllFactories + M27UnitInfo.refCategoryMex - categories.TECH3 - categories.EXPERIMENTAL, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 100, 'Ally')
                                                    if M27Utilities.IsTableEmpty(tNearbyUpgradables) == false then
                                                        --Do we own any of these
                                                        for iUpgradable, oUpgradable in tNearbyUpgradables do
                                                            if oUpgradable:GetAIBrain() == aiBrain and not(oUpgradable:IsUnitState('Upgrading')) then
                                                                M27Utilities.ErrorHandler('Couldnt find unit to upgrade after trying all backup options; nearest enemy to base='..math.floor(aiBrain[M27Overseer.refiModDistFromStartNearestThreat])..'; Have a T2 or below mex or factory within 100 of our base, which includes '..oUpgradable.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUpgradable),nil, true)
                                                                break
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if oUnitToUpgrade and not(oUnitToUpgrade.Dead) then
                        if bDebugMessages == true then LOG(sFunctionRef..': About to try and upgrade unit ID='..oUnitToUpgrade.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade)) end
                        UpgradeUnit(oUnitToUpgrade, true)
                        if bDebugMessages == true then LOG(sFunctionRef..': Finished sending order to upgrade unit') end
                    else
                        if bDebugMessages == true then LOG('Couldnt get a unit to upgrade despite trying alternative categories.  Likely cause is that we have enemies near our base meaning poor defence coverage') end
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
    local iUnitsAdjusted = 0
    if GetGameTimeSeconds() >= 120 or (GetGameTimeSeconds() >= 40 and aiBrain[refiEnergyGrossBaseIncome] >= 15) then --Only consider power stall management after 2m, otherwise risk pausing things such as early microbots when we would probably be ok after a couple of seconds; lower time limit put in as a theroetical possibility due to AIX
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
            aiBrain[refiLastEnergyStall] = GetGameTimeSeconds()
            --Decide on order to pause/unpause

            local tCategoriesByPriority
            local tEngineerActionsByPriority
            local iSpecialHQCategory
            if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
                if aiBrain[M27AirOverseer.refiAirAANeeded] <= 0 then
                    tCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, iSpecialHQCategory, M27UnitInfo.refCategoryEngineer}
                else
                    tCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, iSpecialHQCategory, M27UnitInfo.refCategoryEngineer}
                end

                tEngineerActionsByPriority = {{M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildT2Sonar, M27EngineerOverseer.refActionBuildT1Sonar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildTML, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionBuildShield, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildExperimental, M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionBuildSecondAirFactory, M27EngineerOverseer.refActionBuildAirFactory, M27EngineerOverseer.refActionBuildSecondLandFactory, M27EngineerOverseer.refActionBuildLandFactory, M27EngineerOverseer.refActionBuildMassStorage, M27EngineerOverseer.refActionUpgradeBuilding, M27EngineerOverseer.refActionBuildMex, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildSecondPower, M27EngineerOverseer.refActionBuildTMD, M27EngineerOverseer.refActionBuildSMD},
                                              {M27EngineerOverseer.refActionBuildPower, M27EngineerOverseer.refActionBuildHydro} }
            elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill then
                tCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, iSpecialHQCategory, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, M27UnitInfo.refCategoryEngineer}
                tEngineerActionsByPriority = {{M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildT2Sonar, M27EngineerOverseer.refActionBuildT1Sonar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildTML, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionBuildShield, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildExperimental, M27EngineerOverseer.refActionBuildMassStorage, M27EngineerOverseer.refActionUpgradeBuilding, M27EngineerOverseer.refActionBuildTMD, M27EngineerOverseer.refActionBuildSMD, M27EngineerOverseer.refActionBuildSecondLandFactory, M27EngineerOverseer.refActionBuildLandFactory},
                                              {M27EngineerOverseer.refActionAssistSMD, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildMex, M27EngineerOverseer.refActionBuildSecondPower},
                                              {M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionBuildPower, M27EngineerOverseer.refActionBuildHydro}}
            elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                tCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryEngineer, iSpecialHQCategory, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryEngineer}
                tEngineerActionsByPriority = {{M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildT2Sonar, M27EngineerOverseer.refActionBuildT1Sonar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildTML, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildShield, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildExperimental, M27EngineerOverseer.refActionBuildMassStorage},
                                              {M27EngineerOverseer.refActionUpgradeBuilding, M27EngineerOverseer.refActionBuildTMD, M27EngineerOverseer.refActionBuildSMD, M27EngineerOverseer.refActionBuildSecondLandFactory, M27EngineerOverseer.refActionBuildLandFactory, M27EngineerOverseer.refActionAssistSMD},
                                              {M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildMex, M27EngineerOverseer.refActionBuildSecondPower, M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionBuildPower, M27EngineerOverseer.refActionBuildHydro}}
            else --Land attack mode/normal logic
                if aiBrain[M27AirOverseer.refiAirAANeeded] <= 0 then
                    tCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryEngineer, iSpecialHQCategory, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, M27UnitInfo.refCategoryEngineer}
                else
                    tCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryAirFactory, iSpecialHQCategory, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, M27UnitInfo.refCategoryEngineer}
                end

                tEngineerActionsByPriority = {{M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildT2Sonar, M27EngineerOverseer.refActionBuildT1Sonar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildTML, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionBuildShield, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildExperimental, M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionBuildSecondAirFactory, M27EngineerOverseer.refActionBuildAirFactory, M27EngineerOverseer.refActionBuildSecondLandFactory, M27EngineerOverseer.refActionBuildLandFactory, M27EngineerOverseer.refActionBuildMassStorage, M27EngineerOverseer.refActionUpgradeBuilding},
                                              {M27EngineerOverseer.refActionBuildMex, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildSecondPower, M27EngineerOverseer.refActionBuildTMD, M27EngineerOverseer.refActionBuildSMD},
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
            local bWasUnitPaused
            if bPauseNotUnpause then iCategoryStartPoint = 1 iIntervalChange = 1 iCategoryEndPoint = table.getn(tCategoriesByPriority)
            else iCategoryStartPoint = table.getn(tCategoriesByPriority) iIntervalChange = -1 iCategoryEndPoint = 1 end

            local bConsideringHQ
            local bNoRelevantUnits = true

            if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through every category, bPauseNotUnpause='..tostring(bPauseNotUnpause)..'; iCategoryStartPoint='..iCategoryStartPoint..'; iCategoryEndPoint='..iCategoryEndPoint..'; strategy='..aiBrain[M27Overseer.refiAIBrainCurrentStrategy]) end
            for iCategoryCount = iCategoryStartPoint, iCategoryEndPoint, iIntervalChange do
                iCategoryRef =  tCategoriesByPriority[iCategoryCount]

                --Are we considering upgrading factory HQs?
                if iCategoryRef == iSpecialHQCategory then
                    iCategoryRef = M27UnitInfo.refCategoryAllHQFactories
                    bConsideringHQ = true
                else bConsideringHQ = false
                end

                if bPauseNotUnpause then tRelevantUnits = aiBrain:GetListOfUnits(iCategoryRef, false, true)
                else tRelevantUnits = EntityCategoryFilterDown(iCategoryRef, aiBrain[reftPausedUnits])
                end

                local iCurUnitEnergyUsage
                local bApplyActionToUnit
                if M27Utilities.IsTableEmpty(tRelevantUnits) == false then
                    bNoRelevantUnits = false
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
                            if bDebugMessages == true then LOG(sFunctionRef..': About to consider pausing/unpausingunit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; will first check category specific logic for if we want to go ahead with pausing4') end


                            --Do we actually want to pause the unit? check any category specific logic
                            bApplyActionToUnit = true
                            if bDebugMessages == true then LOG(sFunctionRef..': UnitState='..M27Logic.GetUnitState(oUnit)..'; Is ActiveHQUpgrades Empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]))) end
                            --SMD LOGIC - Check if already have 1 missile loaded before pausing
                            if iCategoryRef == M27UnitInfo.refCategorySMD and oUnit.GetTacticalSiloAmmoCount and oUnit:GetTacticalSiloAmmoCount() >= 1 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Have SMD with at least 1 missile so will pause it') end
                                bApplyActionToUnit = false
                            elseif iCategoryRef == M27UnitInfo.refCategoryEngineer then
                                if bDebugMessages == true then LOG(sFunctionRef..': Have an engineer with action='..(oUnit[M27EngineerOverseer.refiEngineerCurrentAction] or 'nil')..'; tEngineerActionSubtable='..repr(tEngineerActionSubtable)) end
                                bApplyActionToUnit = false
                                for iActionCount, iActionRef in tEngineerActionSubtable do
                                    if iActionRef == oUnit[M27EngineerOverseer.refiEngineerCurrentAction] then
                                        bApplyActionToUnit = true
                                        --Dont pause the last engi building power
                                        if bPauseNotUnpause and iActionRef == M27EngineerOverseer.refActionBuildPower and (oUnit[M27EngineerOverseer.refbPrimaryBuilder] or aiBrain:GetEconomyStoredRatio('MASS') >= 0.8) then
                                            bApplyActionToUnit = false
                                        end
                                        break
                                    end
                                end
                            elseif iCategoryRef == M27UnitInfo.refCategoryPersonalShield or iCategoryRef == M27UnitInfo.refCategoryFixedShield or iCategoryRef == M27UnitInfo.refCategoryMobileLandShield then
                                --Dont disable shield if unit has enemies nearby
                                if bPauseNotUnpause and M27UnitInfo.IsUnitShieldEnabled(oUnit) and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, oUnit:GetPosition(), 40, 'Enemy')) == false then bApplyActionToUnit = false end
                            elseif iCategoryRef == M27UnitInfo.refCategoryAirFactory or iCategoryRef == M27UnitInfo.refCategoryLandFactory then
                                --Dont want to pause an HQ upgrade since it will give us better power
                                if bPauseNotUnpause and not(bConsideringHQ) and oUnit:IsUnitState('Upgrading') and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false and EntityCategoryContains(categories.FACTORY, oUnit) then
                                    for iFactory, oFactory in aiBrain[reftActiveHQUpgrades] do
                                        if oUnit == oFactory then bApplyActionToUnit = false break end
                                    end
                                elseif not(bPauseNotUnpause) and bConsideringHQ then
                                    --Only unpause HQs
                                    bApplyActionToUnit = false
                                    if oUnit:IsUnitState('Upgrading') and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
                                        for iFactory, oFactory in aiBrain[reftActiveHQUpgrades] do
                                            if oUnit == oFactory then bApplyActionToUnit = true break end
                                        end
                                    end
                                end
                                if bApplyActionToUnit and bPauseNotUnpause then
                                    --Dont pause factory that is building an engineer or is an air factory that isnt building an air unit, if its our highest tech level and we dont have at least 5 engis of that tech level
                                    if M27UnitInfo.GetUnitTechLevel(oUnit) >= math.max(2, aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]) and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * M27UnitInfo.ConvertTechLevelToCategory(M27UnitInfo.GetUnitTechLevel(oUnit))) < 2 then
                                        --Dont pause factory as have too few engis and want to build power with those engis
                                        if bDebugMessages == true then LOG(sFunctionRef..': Have too few engineers so wont pause factory') end
                                        bApplyActionToUnit = false
                                    end
                                end
                            end


                            if iCategoryRef == categories.COMMAND then --want in addition to above as ACU might have personal shield
                                if bPauseNotUnpause then
                                    if not(oUnit:IsUnitState('Upgrading')) then bApplyActionToUnit = false
                                    elseif oUnit.GetWorkProgress and oUnit:GetWorkProgress() >= 0.85 then bApplyActionToUnit = false
                                    end
                                end
                            end


                            --Pause the unit

                            if bApplyActionToUnit then
                                iCurUnitEnergyUsage = oUnit:GetBlueprint().Economy.MaintenanceConsumptionPerSecondEnergy
                                if (iCurUnitEnergyUsage or 0) == 0 or iCategoryRef == M27UnitInfo.refCategoryEngineer or iCategoryRef == M27UnitInfo.refCategoryMex or iCategoryRef == categories.COMMAND then
                                    --Approximate energy usage based on build rate as a very rough guide
                                    --examples: Upgrading mex to T3 costs 11E per BP; T3 power is 8.4; T1 power is 6; Guncom is 30; Laser is 178; Strat bomber is 15
                                    local iEnergyPerBP = 9
                                    if iCategoryRef == categories.COMMAND and oUnit[M27UnitInfo.refsUpgradeRef] then
                                        --Determine energy cost per BP
                                        iEnergyPerBP = M27UnitInfo.GetUpgradeEnergyCost(oUnit, oUnit[M27UnitInfo.refsUpgradeRef]) / (M27UnitInfo.GetUpgradeBuildTime(oUnit, oUnit[M27UnitInfo.refsUpgradeRef]) or 1)
                                    end
                                    if oUnit:GetBlueprint().Economy.BuildRate then iCurUnitEnergyUsage = oUnit:GetBlueprint().Economy.BuildRate * iEnergyPerBP end
                                end
                                --We're working in ticks so adjust energy usage accordingly
                                iCurUnitEnergyUsage = iCurUnitEnergyUsage * 0.1
                                if bDebugMessages == true then LOG(sFunctionRef..': Estimated energy usage='..iCurUnitEnergyUsage) end
                                iUnitsAdjusted = iUnitsAdjusted + 1
                                M27UnitInfo.PauseOrUnpauseEnergyUsage(aiBrain, oUnit, bPauseNotUnpause)
                                --Cant move the below into unitinfo as get a crash if unitinfo tries to refernce the table of paused units
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
                        if not(bWasUnitPaused) and bPauseNotUnpause then iEnergySavingManaged = iEnergySavingManaged + iCurUnitEnergyUsage
                        elseif bWasUnitPaused and not(bPauseNotUnpause) then iEnergySavingManaged = iEnergySavingManaged - iCurUnitEnergyUsage
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': iEnergySavingManaged='..iEnergySavingManaged..'; iEnergyPerTickSavingNeeded='..iEnergyPerTickSavingNeeded..'; aiBrain[refbStallingEnergy]='..tostring(aiBrain[refbStallingEnergy])) end

                        if aiBrain[refbStallingEnergy] then
                            if iEnergySavingManaged > iEnergyPerTickSavingNeeded then
                                if bDebugMessages == true then LOG(sFunctionRef..': Estimate we have saved '..iEnergySavingManaged..' which is more tahn we wanted so will pause') end
                                bAbort = true
                                break
                            end
                        else
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
            else
                if bDebugMessages == true then LOG(sFunctionRef..': About to check if we wanted to unpause units but havent unpaused anything; Size of table='..table.getn(aiBrain[reftPausedUnits])..'; iUnitsAdjusted='..iUnitsAdjusted..'; bNoRelevantUnits='..tostring(bNoRelevantUnits)..'; aiBrain[refbStallingEnergy]='..tostring(aiBrain[refbStallingEnergy])) end
                --Backup - sometimes we still have units in the table listed as being paused (e.g. if an engineer changes action to one that isnt listed as needing pausing) - unpause them if we couldnt find via category search
                if aiBrain[refbStallingEnergy] and not(bPauseNotUnpause) and (iUnitsAdjusted == 0 or bNoRelevantUnits) and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.95 then
                    --Have a decent amount of power, are flagged as stalling energy, but couldnt find any categories to unpause
                    if bDebugMessages == true then LOG(sFunctionRef..': werent able to find any units to unpause with normal approach so will unpause all remaining units') end
                    local iLoopCountCheck = 0
                    local iMaxLoop = math.max(20, table.getn(aiBrain[reftPausedUnits]) + 1)
                    while M27Utilities.IsTableEmpty(aiBrain[reftPausedUnits]) == false do
                        iLoopCountCheck = iLoopCountCheck + 1
                        if iLoopCountCheck >= iMaxLoop then M27Utilities.ErrorHandler('Infinite loop likely') break end
                        if M27Utilities.IsTableEmpty(aiBrain[reftPausedUnits]) == false then
                            for iUnit, oUnit in aiBrain[reftPausedUnits] do
                                if bDebugMessages == true then
                                    if M27UnitInfo.IsUnitValid(oUnit) then LOG(sFunctionRef..': About to unpause '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit))
                                    else LOG('Removing iUnit='..iUnit..' which is no longer valid')
                                    end
                                    LOG('Size of aiBrain[reftPausedUnits] before removal='..table.getn(aiBrain[reftPausedUnits])..'; will double check this size')
                                    local iActualSize = 0
                                    for iAltUnit, oAltUnit in aiBrain[reftPausedUnits] do
                                        iActualSize = iActualSize + 1
                                    end
                                    LOG('Actual size='..iActualSize)
                                end
                                if M27UnitInfo.IsUnitValid(oUnit) then M27UnitInfo.PauseOrUnpauseEnergyUsage(aiBrain, oUnit, false) end
                                table.remove(aiBrain[reftPausedUnits], iUnit)
                                break
                            end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': FInished unpausing units') end
                end
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': End of code, aiBrain[refbStallingEnergy]='..tostring(aiBrain[refbStallingEnergy])..'; bPauseNotUnpause='..tostring(bPauseNotUnpause)..'; iUnitsAdjusted='..iUnitsAdjusted..'; Game time='..GetGameTimeSeconds()..'; Energy stored %='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; Net energy income='..aiBrain[refiEnergyNetBaseIncome]..'; gross energy income='..aiBrain[refiEnergyGrossBaseIncome]) end
        if aiBrain[refbStallingEnergy] then aiBrain[refiLastEnergyStall] = GetGameTimeSeconds() end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpgradeManager(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpgradeManager'


    local iCycleWaitTime = 40
    local iReducedWaitTime = 20
    local iShortestWaitTime = 10
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
    aiBrain[refiLastEnergyStall] = 0
    aiBrain[reftUnitsToReclaim] = {}
    aiBrain[reftoTMLToReclaim] = {}
    aiBrain[reftMexesToCtrlK] = {}
    aiBrain[reftT2MexesNearBase] = {}
    aiBrain[refoNearestT2MexToBase] = nil
    aiBrain[reftActiveHQUpgrades] = {}

    --Economy - placeholder
    aiBrain[refiEnergyGrossBaseIncome] = 2
    aiBrain[refiMassGrossBaseIncome] = 0.1
    aiBrain[refiEnergyNetBaseIncome] = 2
    aiBrain[refiMassNetBaseIncome] = 0.1

    --Initial wait:
    WaitTicks(300)
    while(not(aiBrain:IsDefeated())) do
        if aiBrain.M27IsDefeated or M27Logic.iTimeOfLastBrainAllDefeated > 10 then break end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        iCurCycleTime = iCycleWaitTime --default (is shortened if have lots to upgrade)
        ForkThread(UpgradeMainLoop, aiBrain)
        if aiBrain[refbWantToUpgradeMoreBuildings] then
            iCurCycleTime = iReducedWaitTime
            if aiBrain:GetEconomyStoredRatio('MASS') >= 0.9 and aiBrain:GetEconomyStored('MASS') >= 1000 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and aiBrain[refiEnergyNetBaseIncome] >= 5 and aiBrain[refiMassNetBaseIncome] > 0 then
                iCurCycleTime = iShortestWaitTime
            end
        end


        ForkThread(GetMassStorageTargets, aiBrain)
        ForkThread(GetUnitReclaimTargets, aiBrain)
        if bDebugMessages == true then LOG(sFunctionRef..': End of loop about to wait '..iCycleWaitTime..' ticks. aiBrain[refbWantToUpgradeMoreBuildings]='..tostring(aiBrain[refbWantToUpgradeMoreBuildings])..'; Mass stored %='..aiBrain:GetEconomyStoredRatio('MASS')..'; Mass stored='..aiBrain:GetEconomyStored('MASS')..'; Energy stored %='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; aiBrain[refiEnergyNetBaseIncome]='..aiBrain[refiEnergyNetBaseIncome]..'; aiBrain[refiMassNetBaseIncome]='..aiBrain[refiMassNetBaseIncome]) end

        ForkThread(ManageEnergyStalls, aiBrain)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(iCycleWaitTime)
        if bDebugMessages == true then LOG(sFunctionRef..': End of loop after waiting ticks') end
    end
end

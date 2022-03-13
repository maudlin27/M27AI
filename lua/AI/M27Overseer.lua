--Houses the main code/logic for the overseer AI functionality
--Overseer is aimed to be a strategic AI that can override localised tactical AI (such as platoons)
tTEMPTEST = {}
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27MiscProfiling = import('/mods/M27AI/lua/MiscProfiling.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27FactoryOverseer = import('/mods/M27AI/lua/AI/M27FactoryOverseer.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27PlatoonFormer = import('/mods/M27AI/lua/AI/M27PlatoonFormer.lua')
local M27EconomyOverseer = import('/mods/M27AI/lua/AI/M27EconomyOverseer.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27PlatoonTemplates = import('/mods/M27AI/lua/AI/M27PlatoonTemplates.lua')
local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27Chat = import('/mods/M27AI/lua/AI/M27Chat.lua')

--Semi-Global for this code:
refbACUOnInitialBuildOrder = 'M27ACUOnInitialBuildOrder' --local variable for ACU, determines whether ACUmanager is running or not
local iLandThreatSearchRange = 1000
refbACUHelpWanted = 'M27ACUHelpWanted' --flags if we want teh ACU to stay in army pool platoon so its available for defence
refoStartingACU = 'M27PlayerStartingACU' --NOTE: Use M27Utilities.GetACU(aiBrain) instead of getting this directly (to help with crash control)
tAllAIBrainsByArmyIndex = {} --Stores table of all aiBrains, used as sometimes are getting errors when trying to use ArmyBrains
refiDistanceToNearestEnemyBase = 'M27DistanceToNearestEnemy' --Distance from our base to the nearest enemy base
--AnotherAIBrainsBackup = {}
toEnemyBrains = 'M27OverseerEnemyBrains'
toAllyBrains = 'M27OverseerAllyBrains'
iACUDeathCount = 0
iACUAlternativeFailureCount = 0
iDistanceFromBaseToBeSafe = 55 --If ACU wants to run (<50% health) then will think its safe once its this close to our base
iDistanceFromBaseWhenVeryLowHealthToBeSafe = 25 --As above but when ACU on lower health
iDistanceToEnemyEcoThreshold = 450 --Point to nearest enemy base after which will be more likely to favour eco based actions

refiACUHealthToRunOn = 'M27ACUHealthToRunOn'
iACUEmergencyHealthPercentThreshold = 0.3
iACUGetHelpPercentThreshold = 0.6
reftACURecentHealth = 'M27ACURecentHealth' --Records the ACU health every second - attached to ACU object
reftACURecentUpgradeProgress = 'M27ACURecentUpgradeProgress' --[gametimesecond] - Records the % upgrade every second the ACU is upgrading, by gametimesecond

refiUnclaimedMexesInBasePathingGroup = 'M27UnclaimedMexesInBaseGroup'
refiAllMexesInBasePathingGroup = 'M27AllMexesInBaseGroup'
iPlayersAtGameStart = 2

--Threat groups:

local reftEnemyThreatGroup = 'M27EnemyThreatGroupObject'
refsEnemyThreatGroup = 'M27EnemyThreatGroupRef'
    --Threat group subtable refs:
    local refiThreatGroupCategory = 'M27EnemyGroupCategory'
    local refiThreatGroupHighestTech = 'M27EnemyGroupHighestTech'
    local refoEnemyGroupUnits = 'M27EnemyGroupUnits'
    local refsEnemyGroupName = 'M27EnemyThreatGroupName'
    local refiEnemyThreatGroupUnitCount = 'M27EnemyThreatGroupUnitCount'
    local refiHighestThreatRecorded = 'M27EnemyThreatGroupHighestThreatRecorded'
    local refiTotalThreat = 'M27TotalThreat'
    local reftAveragePosition = 'M27AveragePosition'
    local refiDistanceFromOurBase = 'M27DistanceFromOurBase'
    local refiModDistanceFromOurStart = 'M27ModDistanceFromEnemy' --Distance that enemy threat group is from our start (adjusted to factor in distance from mid as well)
    local refiActualDistanceFromEnemy = 'M27ActualDistanceFromEnemy'
refstPrevEnemyThreatGroup = 'M27PrevEnemyThreatRefTable'
refbUnitAlreadyConsidered = 'M27UnitAlreadyConsidered'
refiAssignedThreat = 'M27OverseerUnitAssignedThreat' --recorded against oEnemyUnit[iOurBrainArmyIndex]
refiUnitNavalAAThreat = 'M27OverseerUnitThreat' --Recored against individual oEnemyUnit[iOurBrainArmyIndex]
local reftUnitGroupPreviousReferences = 'M27UnitGroupPreviousReferences'
refiModDistFromStartNearestOutstandingThreat = 'M27NearestOutstandingThreat' --Mod distance of the closest enemy threat (using GetDistanceFromStartAdjustedForDistanceFromMid)
refiModDistFromStartNearestThreat = 'M27OverseerNearestThreat' --Mod distance of the closest enemy, even if we have enough defenders to deal with it
reftLocationFromStartNearestThreat = 'M27OverseerLocationNearestLandThreat' --Distance of closest enemy
refiPercentageOutstandingThreat = 'M27PercentageOutstandingThreat' --% of moddistance
refiPercentageClosestFriendlyFromOurBaseToEnemy = 'M27OverseerPercentageClosestFriendly'
refiMaxDefenceCoverageWanted = 'M27OverseerMaxDefenceCoverageWanted'

local iMaxACUEmergencyThreatRange = 150 --If ACU is more than this distance from our base then won't help even if an emergency threat

--Big enemy threats (impact on strategy and/or engineer build order)
reftEnemyLandExperimentals = 'M27OverseerEnemyGroundExperimentals'
reftEnemyArti = 'M27OverseerEnemyT3Arti'
reftEnemyNukeLaunchers = 'M27OverseerEnemyNukeLaunchers'
reftEnemyTML = 'M27OverseerEnemyTML'
refbEnemyTMLSightedBefore = 'M27OverseerEnemyTMLSightedBefore'
refiEnemyHighestTechLevel = 'M27OverseerEnemyHighestTech'

--Platoon references
--local bArmyPoolInAvailablePlatoons = false
sDefenderPlatoonRef = 'M27DefenderAI'
sIntelPlatoonRef = 'M27IntelPathAI'

--Build condition related - note that overseer start shoudl set these to false to avoid error messages when build conditions check their status
refbNeedDefenders = 'M27NeedDefenders'
refbNeedIndirect = 'M27NeedIndirect'
refiMinIndirectTechLevel = 'M27OverseerMinIndirectTech'
refbNeedScoutPlatoons = 'M27NeedScoutPlatoons'
refbNeedMAABuilt = 'M27NeedMAABuilt'
refbEmergencyMAANeeded = 'M27OverseerNeedEmergencyMAA'
refbUnclaimedMexNearACU = 'M27UnclaimedMexNearACU'
refoReclaimNearACU = 'M27ReclaimObjectNearACU'
refiScoutShortfallInitialRaider = 'M27ScoutShortfallRaider'
refiScoutShortfallACU = 'M27ScoutShortfallACU'
refiScoutShortfallPriority = 'M27ScoutShortfallPriority'
refiScoutShortfallIntelLine = 'M27ScoutShortfallIntelLine'
refiScoutShortfallLargePlatoons = 'M27ScoutShortfallLargePlatoon'
refiScoutShortfallAllPlatoons = 'M27ScoutShortfallAllPlatoon'
refiScoutShortfallMexes = 'M27ScoutShortfallMexes'
reftPriorityLandScoutTargets = 'M27ScoutPriorityTargets'

refiMAAShortfallACUPrecaution = 'M27MAAShortfallACUPrecaution'
refiMAAShortfallACUCore = 'M27MAAShortfallACUCore'
refiMAAShortfallLargePlatoons = 'M27MAAShortfallLarge'
refiMAAShortfallBase = 'M27MAAShortfallBase'

local iScoutLargePlatoonThreshold = 8 --Platoons >= this size are considered large
local iSmallPlatoonMinSizeForScout = 3 --Wont try and assign scouts to platoons that have fewer than 3 units in them
local iMAALargePlatoonThresholdAirThreat = 10
local iMAALargePlatoonThresholdNoThreat = 20
refsLastScoutPathingType = 'M27OverseerLastScoutPathingType'

--Factories wanted
reftiMaxFactoryByType = 'M27OverseerMaxFactoryByType' -- table {land, air, navy} with the max no. wanted
refiMinLandFactoryBeforeOtherTypes = 'M27OverseerMinLandFactoryFirst'
refFactoryTypeLand = 1
refFactoryTypeAir = 2
refFactoryTypeNavy = 3

--Other ACU related
refiACULastTakenUnseenOrTorpedoDamage = 'M27OverseerACULastTakenUnseenDamage' --Used to determine if ACU should run or not
refoUnitDealingUnseenDamage = 'M27OverseerACUUnitDealingUnseenDamage' --so can see if it was a T2+ PD that should run away from
refbACUWasDefending = 'M27ACUWasDefending'
iACUMaxTravelToNearbyMex = 20 --ACU will go up to this distance out of its current position to build a mex (i.e. add 10 to this for actual range)
local refiCyclesThatACUHasNoPlatoon = 'M27ACUCyclesWithNoPlatoon'
local refiCyclesThatACUInArmyPool = 'M27ACUCyclesInArmyPool'

--Intel related
--local sIntelPlatoonRef = 'M27IntelPathAI' - included above
refiInitialRaiderPlatoonsWanted = 'M27InitialRaidersWanted'
tScoutAssignedToMexLocation = 'M27ScoutsAssignedByMex' --[sLocationRef] - returns scout unit if one has been assigned to that location; used to track scouts assigned by mex
--refiInitialEngineersWanted = 'M27InitialEngineersWanted' --This is in FactoryOverseer

refbConfirmedInitialRaidersHaveScouts = 'M27InitialRaidersHaveScouts'
refbIntelPathsGenerated = 'M27IntelPathsGenerated'
reftIntelLinePositions = 'M27IntelLinePositions' --x = line; y = point on that line, returns position
refiCurIntelLineTarget = 'M27CurIntelLineTarget'
reftiSubpathModFromBase = 'M27SubpathModFromBase' --i.e. no. of steps forward that can move for the particular subpath; is aiBrain[this ref][Intel path no.][Subpath No.]
local reftScoutsNeededPerPathPosition = 'M27ScoutsNeededPerPathPosition' --table[x] - x is path position, returns no. of scouts needed for that path position - done to save needing to call table.getn
local refiMinScoutsNeededForAnyPath = 'M27MinScoutsNeededForAnyPath'
local refiMaxIntelBasePaths = 'M27MaxIntelPaths'

refiSearchRangeForEnemyStructures = 'M27EnemyStructureSearchRange'
refbEnemyHasTech2PD = 'M27EnemyHasTech2PD'

refiOurHighestFactoryTechLevel = 'M27OverseerOurHighestFactoryTech'
refiOurHighestAirFactoryTech = 'M27OverseerOurHighestAirFactoryTech'
refiOurHighestLandFactoryTech = 'M27OverseerOurHighestLandFactoryTech'



--Helper related
refoScoutHelper = 'M27UnitsScoutHelper'
refoUnitsMAAHelper = 'M27UnitsMAAHelper' --MAA platoon assigned to help a unit (e.g. the ACU)



--Grand strategy related
refiAIBrainCurrentStrategy = 'M27GrandStrategyRef'
refStrategyLandEarly = 1 --initial build order and pre-ACU gun upgrade approach
refStrategyAirDominance = 2 --All-out air attack on enemy, targetting any AA they have first
refStrategyProtectACU = 3 --Similar to ACUKill, but will focus units on our ACU
--refStrategyLandAttackBase = 2 --e.g. for when have got gun upgrade on ACU
--refStrategyLandConsolidate = 3 --e.g. for if ACU retreating after gun upgrade and want to get map control and eco
refStrategyACUKill = 4 --all-out attack on enemy ACU
refStrategyEcoAndTech = 5 --Focus on upgrading buildings
refbIncludeACUInAllOutAttack = 'M27OverseerIncludeACUInAllOutAttack'
refbStopACUKillStrategy = 'M27OverseerStopACUKillStrat'
refoLastNearestACU = 'M27OverseerLastACUObject'
reftLastNearestACU = 'M27OverseerLastACUPosition' --Position of the last ACU we saw
refiLastNearestACUDistance = 'M27OverseerLastNearestACUDistance'
refbEnemyACUNearOurs = 'M27OverseerACUNearOurs'

reftiMexIncomePrevCheck = 'M27OverseerMexIncome3mAgo' --x = prev check number; returns gross mass income
refiTimeOfLastMexIncomeCheck = 'M27OverseerTimeOfLastMexIncomeCheck'
iLongTermMassIncomeChangeInterval = 180 --3m

refiIgnoreMexesUntilThisManyUnits = 'M27ThresholdToAttackMexes'



function DebugPrintACUPlatoon(aiBrain, bReturnPlanOnly)
    --for debugging - sends log of acu platoons plan (and action if it has one and bReturnPlanOnly is false)
    local oACUUnit = M27Utilities.GetACU(aiBrain)
    local oACUPlatoon = oACUUnit.PlatoonHandle
    local sPlan
    local iCount
    local iAction = 0
    if oACUPlatoon == nil then
        sPlan = 'nil'
        if bReturnPlanOnly == true then return sPlan
        else
            iCount = 0
        end
    else
        local oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
        if oACUPlatoon == oArmyPoolPlatoon then
            sPlan = 'ArmyPool'
            if bReturnPlanOnly == true then return sPlan
            else iCount = 1
            end
        else
            sPlan = oACUPlatoon:GetPlan()
            if bReturnPlanOnly == true then return sPlan
            else
                iCount = oACUPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                if iCount == nil then iCount = 0 end
                iAction = oACUPlatoon[M27PlatoonUtilities.refiCurrentAction]
                if iAction == nil then iAction = 0 end
            end
        end
    end
    LOG('DebugPrintACUPlatoon: ACU platoon ref='..sPlan..iCount..': Action='..iAction..'; UnitState='..M27Logic.GetUnitState(oACUUnit))
end

function GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tLocationTarget, bUseEnemyStartInstead)
    --Instead of the actual distance, it reduces the distance based on how far away it is from the centre of the map
    --bUseEnemyStartInstead - instead of basing on dist from our start, uses from enemy start
    local sFunctionRef = 'GetDistanceFromStartAdjustedForDistanceFromMid'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iModDistance = 0
    local iMidDistanceFactor = 0.6 --e.g. at 1 then will treat the midpoint between 2 bases as equal in distance as a corner point thats equal distance between 2 bases and also the same distance to mid.  If <1 then will instead treat the actual mid position as being closer
    if M27Utilities.IsTableEmpty(tLocationTarget) == true then
        M27Utilities.ErrorHandler('tLocationTarget is empty')
    else
        local tStartPosition, tEnemyStartPosition

        if bUseEnemyStartInstead then
            tStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
            tEnemyStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        else
            tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
            tEnemyStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
        end
        local iDistanceFromEnemyToUs = aiBrain[refiDistanceToNearestEnemyBase]
        --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
        local tMidpointBetweenUsAndEnemy = M27Utilities.MoveTowardsTarget(tStartPosition, tEnemyStartPosition, iDistanceFromEnemyToUs / 2, 0)
        local iActualDistance = M27Utilities.GetDistanceBetweenPositions(tStartPosition, tLocationTarget)
        local iDistanceToMid = M27Utilities.GetDistanceBetweenPositions(tMidpointBetweenUsAndEnemy, tLocationTarget)
        iModDistance = iActualDistance - iDistanceToMid * 0.6
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iModDistance
end

function RecordIntelPaths(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordIntelPaths'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if not(aiBrain.M27IsDefeated) and M27Logic.iTimeOfLastBrainAllDefeated < 10 then
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
        local refCategoryLandScout = M27UnitInfo.refCategoryLandScout
        aiBrain[refiMinScoutsNeededForAnyPath] = 1 --Default so wont have a nil value
        --First check we have finished map pathing:
        if M27MapInfo.bPathfindingComplete == true then
            --if aiBrain:GetCurrentUnits(refCategoryLandScout) > 0 then
            --Determine our scout range based on our faction
            local iDefaultScoutRange = 40 --default
            local iFactionCat = M27Utilities.FactionIndexToCategory[aiBrain:GetFactionIndex()] or categories.ALLUNITS
            local tScoutsToBuild = EntityCategoryGetUnitList(refCategoryLandScout * iFactionCat)
            local oScoutBP, iScoutRange
            if M27Utilities.IsTableEmpty(tScoutsToBuild) == false then
                for iScout, sScoutBP in tScoutsToBuild do
                    iScoutRange = __blueprints[sScoutBP].Intel.RadarRadius
                    if iScoutRange > 20 then break end
                end
            end
            if iScoutRange == nil or iScoutRange <= 20 then iScoutRange = iDefaultScoutRange end
            local iSubpathGap = iScoutRange * 1.7
            local sPathingType = M27UnitInfo.refPathingTypeLand --want land even for aeon so dont have massive scout lines across large oceans
            local iStartingGroup = M27MapInfo.GetSegmentGroupOfLocation(sPathingType, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])

            --Get a table of all enemy start locations
            if M27Utilities.IsTableEmpty(aiBrain[toEnemyBrains]) == true and GetGameTimeSeconds() > 20 then
                M27Utilities.ErrorHandler('No nearby enemies')
            else
                if aiBrain:IsDefeated() == false then --Already have M27IsDefeated check above
                    local tEnemyStartPositions = {}
                    local iCount = 0
                    for iBrain, oBrain in aiBrain[toEnemyBrains] do
                        if not(oBrain.M27IsDefeated) then
                            iCount = iCount + 1
                            tEnemyStartPositions[oBrain:GetArmyIndex()] = M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]
                        end
                    end
                    if iCount > 0 then
                        local tNearestEnemyStart = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
                        local iAngleToEnemy = M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tNearestEnemyStart)

                        if bDebugMessages == true then LOG(sFunctionRef..': Our army index='..aiBrain:GetArmyIndex()..'; Our start number='..aiBrain.M27StartPositionNumber..'; Nearest enemy index='..M27Logic.GetNearestEnemyIndex(aiBrain)..'; Nearest enemy start number='..M27Logic.GetNearestEnemyStartNumber(aiBrain)..'; Our start position='..repr(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; Nearest enemy startp osition='..repr(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))) end

                        local iMinX = M27MapInfo.rMapPlayableArea[1] + 5
                        local iMinZ = M27MapInfo.rMapPlayableArea[2] + 5
                        local iMaxX = M27MapInfo.rMapPlayableArea[3] - 5
                        local iMaxZ = M27MapInfo.rMapPlayableArea[4] - 5

                        --First determine all the base intel path positions
                        local bStillDeterminingBaseIntelPaths = true
                        local bStillDeterminingSubpaths = true
                        iCount = 0
                        local iMaxCount = 200
                        local tPossibleBasePosition
                        local tiAdjToDistanceAlongPathByAngle = { } --adjustment if going towards enemy base (rather than moving at right angle)
                        local iBaseDistanceAlongPath
                        local iValidIntelPaths = 0
                        local iValidSubpaths = 0
                        local iCurAngleAdjust
                        local iAltCount
                        local iMaxAltCount = 1000
                        local iAdjustIncrement
                        local bCanPathToLocation = false
                        aiBrain[reftIntelLinePositions] = {}
                        aiBrain[refiCurIntelLineTarget] = 1
                        local tStartingPointForSearch

                        local tbStopMovingInDirection = {[0]=false, [90]=false, [270] = false}

                        if bDebugMessages == true then LOG(sFunctionRef..': About to start main loop to determine all base intel paths') end
--=======BASE PATHS
                        --Find the base points on each intel path by moving towards enemy base and seeing if we can path there
                        while bStillDeterminingBaseIntelPaths == true do
                            iCurAngleAdjust = 0
                            tiAdjToDistanceAlongPathByAngle = {[0]=0,[90]=0,[270]=0}
                            tbStopMovingInDirection = {[0]=false, [90]=false, [270] = false}
                            iCount = iCount + 1
                            if iCount > iMaxCount then
                                M27Utilities.ErrorHandler('Likely infinite loop')
                                break
                            end
                            iBaseDistanceAlongPath = (iValidIntelPaths + 1) * iDefaultScoutRange * 0.5
                            tStartingPointForSearch = M27Utilities.MoveInDirection(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iAngleToEnemy, iBaseDistanceAlongPath + tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust])
                            tPossibleBasePosition = {tStartingPointForSearch[1], tStartingPointForSearch[2], tStartingPointForSearch[3]}
                            if bDebugMessages == true then
                                LOG('Base path attempt that cant path to; Will draw tStartingPointForSearch='..repr(tStartingPointForSearch)..' in red')
                                M27Utilities.DrawLocation(tStartingPointForSearch, nil, 2, 200)
                            end --red
                            iAltCount = 0
                            iAdjustIncrement = 0
                            bCanPathToLocation = false
                            if M27MapInfo.GetSegmentGroupOfLocation(sPathingType, tPossibleBasePosition) == iStartingGroup then bCanPathToLocation = true end
                            --Check if we can path to the target; if we cant then search at 0, 90 and 270 degrees to the normal direction in ever increasing distances until we either go off-map or get near an enemy base
                            while bCanPathToLocation == false do
                                if bDebugMessages == true then LOG(sFunctionRef..': iValidIntelPaths='..iValidIntelPaths..'; tStartingPointForSearch='..repr(tStartingPointForSearch)..'; tPossibleBasePosition='..repr(tPossibleBasePosition)..' tbStopMovingInDirection[iCurAngleAdjust]='..tostring(tbStopMovingInDirection[iCurAngleAdjust])..'; iCurAngleAdjust='..iCurAngleAdjust..'; iBaseDistanceAlongPath='..iBaseDistanceAlongPath..'; tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust]='..tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust]) end
                                if tbStopMovingInDirection[iCurAngleAdjust] == false then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Cant path to location so will consider alternative points; iAltCount='..iAltCount) end
                                    iAltCount = iAltCount + 1
                                    if iAltCount > iMaxAltCount then
                                        M27Utilities.ErrorHandler('Likely infinite loop')
                                        bStillDeterminingBaseIntelPaths = false
                                        break
                                    end

                                    --alternate between moving from this position, first forwards by 1, then to the side by 1, then the other side by 1; then by 3; then by 6, then by 10, then 15, then 21, then 28
                                    if iCurAngleAdjust == 0 then
                                        iAdjustIncrement = math.min(iAdjustIncrement + 1, 30)
                                    end
                                    tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust] = tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust] + iAdjustIncrement
                                    tPossibleBasePosition = M27Utilities.MoveInDirection(tStartingPointForSearch, iAngleToEnemy + iCurAngleAdjust, tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust])
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef..': tPossibleBasePosition='..repr(tPossibleBasePosition)..'; iCurAngleAdjust='..iCurAngleAdjust..'; iBaseDistanceAlongPath='..iBaseDistanceAlongPath..'; tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust]='..tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust]..'; will draw in red')
                                        M27Utilities.DrawLocation(tPossibleBasePosition, nil, 2, 200)
                                    end --red

                                    --Check we're still within map bounds
                                    if tPossibleBasePosition[1] <= iMinX or tPossibleBasePosition[1] >= iMaxX or tPossibleBasePosition[3] <= iMinZ or tPossibleBasePosition[3] >= iMaxZ then
                                        if bDebugMessages == true then LOG(sFunctionRef..': tPossibleBasePosition='..repr(tPossibleBasePosition)..'; are out of map bounds so will stop looking in this direction. iCurAngleAdjust='..iCurAngleAdjust) end
                                        --Out of map bounds, flag to ignore angles of this type in the future
                                        tbStopMovingInDirection[iCurAngleAdjust] = true
                                        --Are all the others flagged to be true?
                                        bStillDeterminingBaseIntelPaths = false
                                        for _, bValue in tbStopMovingInDirection do
                                            if bValue == false then bStillDeterminingBaseIntelPaths = true break end
                                        end
                                        if bStillDeterminingBaseIntelPaths == false then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Are stopping looking for all angles so will abort; tbStopMovingInDirection='..repr(tbStopMovingInDirection)) end
                                            break
                                        end
                                    end
                                end

                                if not(tbStopMovingInDirection[iCurAngleAdjust]) and M27MapInfo.GetSegmentGroupOfLocation(sPathingType, tPossibleBasePosition) == iStartingGroup then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Can path to location') end
                                    bCanPathToLocation = true
                                    break
                                else

                                    --Change angle for next attempt
                                    if iCurAngleAdjust == 0 then iCurAngleAdjust = 90
                                    elseif iCurAngleAdjust == 90 then iCurAngleAdjust = 270
                                    else iCurAngleAdjust = 0
                                    end
                                end
                            end
                            if bCanPathToLocation == false then
                                --Couldnt find any valid locations, so stop looking
                                bStillDeterminingBaseIntelPaths = false
                            else
                                --Check the target location isn't too close to an enemy base
                                if bDebugMessages == true then LOG(sFunctionRef..': Checking we arent too close to an enemy base') end
                                for iEnemy, tEnemyBase in tEnemyStartPositions do
                                    if M27Utilities.GetDistanceBetweenPositions(tEnemyBase, tPossibleBasePosition) < 40 then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Are too close to an enemy. tPossibleBasePosition='..repr(tPossibleBasePosition)..'; tEnemyBase='..repr(tEnemyBase)) end
                                        bCanPathToLocation = false
                                        break
                                    end
                                end
                                if bCanPathToLocation == true then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Can path to location so will record as valid intel path') end
                                    --Record base point of intel path
                                    iValidIntelPaths = iValidIntelPaths + 1
                                    aiBrain[reftIntelLinePositions][iValidIntelPaths] = {}
                                    aiBrain[reftIntelLinePositions][iValidIntelPaths][1] = {tPossibleBasePosition[1], tPossibleBasePosition[2], tPossibleBasePosition[3]}
                                    if bDebugMessages == true then
                                        LOG('Base path that can path to; Will draw tPossibleBasePosition='..repr(tPossibleBasePosition)..' in white')
                                        M27Utilities.DrawLocation(tPossibleBasePosition, nil, 7, 200)
                                    end --white
                                else
                                    --We've got too near enemy base so stop creating new base points
                                    if bDebugMessages == true then LOG(sFunctionRef..': Got too near enemy base so will stop creating new base points in intel path') end
                                    bStillDeterminingBaseIntelPaths = false
                                end
                            end
                        end
                        --Backup - if no intel paths found then use the first point from our base to enemy even if it cant be pathed to
                        if iValidIntelPaths == 0 then
                            M27Utilities.ErrorHandler('Couldnt find any valid base intel paths, will just set one thats near our base as backup; error unless map has very small land pathable base. ArmyIndex='..aiBrain:GetArmyIndex()..'; Nearest enemy army index='..M27Logic.GetNearestEnemyIndex(aiBrain))
                            iValidIntelPaths = 1
                            aiBrain[reftIntelLinePositions][iValidIntelPaths] = {}
                            aiBrain[reftIntelLinePositions][iValidIntelPaths][1] = M27Utilities.MoveInDirection(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iAngleToEnemy, 20)
                        end
--=====SUBPATHS
                        --Determine subpaths for each main path
                        local tiCyclesSinceLastMatch
                        local iInitialInterval = 2
                        local iPointToSwitchToPositiveAdj = (iScoutRange * 0.7)
                        local iSubpathDistAdjust
                        local iSubpathAngleAdjust
                        local tbSubpathOptionOffMap = {}


                        for iIntelPath = 1, iValidIntelPaths, 1  do
                            iValidSubpaths = 0
                            bStillDeterminingSubpaths = true
                            if bDebugMessages == true then LOG(sFunctionRef..': Start of loop, iIntelPath='..iIntelPath) end
                            tiAdjToDistanceAlongPathByAngle = {[90] = 0, [270] = 0}
                            iAltCount = 0
                            tbStopMovingInDirection = {[90] = false, [270] = false}
                            tiCyclesSinceLastMatch = {[90] = 0, [270] = 0}

                            while bStillDeterminingSubpaths == true do
                                iAltCount = iAltCount + 1
                                if iAltCount >= 1000 then
                                    M27Utilities.ErrorHandler('Infinite loop, iIntelPath='..iIntelPath)
                                    bStillDeterminingSubpaths = false
                                    break
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': iIntelPath='..iIntelPath..'; iAltCount='..iAltCount) end
                                for iCurAngleAdjust = 90, 270, 180 do
                                    if not(tbStopMovingInDirection[iCurAngleAdjust]) then
                                        tbSubpathOptionOffMap = { [1] = false, [2] = false }
                                        if tiCyclesSinceLastMatch[iCurAngleAdjust] > 1000 then
                                            M27Utilities.ErrorHandler('Infinite loop, iCurAngleAdjust='..iCurAngleAdjust..'; iIntelPath='..iIntelPath)
                                            bStillDeterminingSubpaths = false
                                            break
                                        end

                                        tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust] = tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust] + iScoutRange * 1.7
                                        tStartingPointForSearch = M27Utilities.MoveInDirection(aiBrain[reftIntelLinePositions][iIntelPath][1], iAngleToEnemy + iCurAngleAdjust, tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust])
                                        tPossibleBasePosition = {tStartingPointForSearch[1], tStartingPointForSearch[2], tStartingPointForSearch[3]}
                                        if M27MapInfo.GetSegmentGroupOfLocation(sPathingType, tPossibleBasePosition) == iStartingGroup then
                                            bCanPathToLocation = true
                                        else bCanPathToLocation = false
                                        end
                                        iSubpathDistAdjust = 0

                                        --Check we're still within map bounds for the starting point
                                        if tPossibleBasePosition[1] <= iMinX or tPossibleBasePosition[1] >= iMaxX or tPossibleBasePosition[3] <= iMinZ or tPossibleBasePosition[3] >= iMaxZ then
                                            --Out of map bounds, flag to ignore angles of this type in the future
                                            tbStopMovingInDirection[iCurAngleAdjust] = true
                                            --Are all the others flagged to be true (i.e. is any one flagged as false)?
                                            bStillDeterminingSubpaths = false
                                            for _, bValue in tbStopMovingInDirection do
                                                if bValue == false then bStillDeterminingSubpaths = true break end
                                            end
                                            if bStillDeterminingSubpaths == false then break end
                                        end
                                        if bCanPathToLocation == false then
                                            --Check if we dont go as far in the normal direction first, can we find somwhere to path to
                                            for iOppositeAngleDistAdjust = -1, -iPointToSwitchToPositiveAdj, -1 do
                                                tPossibleBasePosition = M27Utilities.MoveInDirection(aiBrain[reftIntelLinePositions][iIntelPath][1], iAngleToEnemy + iCurAngleAdjust, tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust] + iOppositeAngleDistAdjust)
                                                if M27MapInfo.GetSegmentGroupOfLocation(sPathingType, tPossibleBasePosition) == iStartingGroup then
                                                    bCanPathToLocation = true
                                                end
                                            end
                                        end

                                        if bDebugMessages == true then LOG(sFunctionRef..': Just finished checking starting point for search is within map bounds; iCurAngleAdjust='..iCurAngleAdjust..'; tiAdjToDistanceAlongPathByAngle='..repr(tiAdjToDistanceAlongPathByAngle)..'; tStartingPointForSearch='..repr(tStartingPointForSearch)..'; bCanPathToLocation='..tostring(bCanPathToLocation)) end

                                        while bCanPathToLocation == false do
                                            for iSubpathAngleOption = 1, 2 do
                                                if tiCyclesSinceLastMatch[iCurAngleAdjust] > 1000 then M27Utilities.ErrorHandler('Infinite loop, iIntelPath='..iIntelPath..'; iCurAngleAdjust='..iCurAngleAdjust) bStillDeterminingSubpaths = false break end
                                                if iSubpathAngleOption == 1 then
                                                    tiCyclesSinceLastMatch[iCurAngleAdjust] = tiCyclesSinceLastMatch[iCurAngleAdjust] + 1
                                                    iSubpathAngleAdjust = iCurAngleAdjust
                                                    iSubpathDistAdjust = iSubpathDistAdjust + 1
                                                    --Increase distance if been searhcing a while for performance reasons, e.g. might be dealing with large ocean
                                                    if tiCyclesSinceLastMatch[iCurAngleAdjust] >= 5 then
                                                        iSubpathDistAdjust = iSubpathDistAdjust + math.min(35, iSubpathDistAdjust + tiCyclesSinceLastMatch[iCurAngleAdjust] * 0.4)
                                                    end
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Increased iSubpathDistAdjust to '..iSubpathDistAdjust) end
                                                else iSubpathAngleAdjust = 180
                                                end
                                                if bDebugMessages == true then LOG(sFunctionRef..': iSubpathAngleOption='..iSubpathAngleOption..'; iSubpathDistAdjust='..iSubpathDistAdjust..'; tbSubpathOptionOffMap[iSubpathAngleOption]='..tostring(tbSubpathOptionOffMap[iSubpathAngleOption])) end
                                                if not(tbSubpathOptionOffMap[iSubpathAngleOption]) then
                                                    tPossibleBasePosition = M27Utilities.MoveInDirection(tStartingPointForSearch, iAngleToEnemy + iSubpathAngleAdjust, iSubpathDistAdjust)
                                                    if bDebugMessages == true then LOG(sFunctionRef..': tPossibleBasePosition='..repr(tPossibleBasePosition)..'; will check if within map bounds; iSubpathAngleAdjust='..iSubpathAngleAdjust..'; iSubpathDistAdjust='..iSubpathDistAdjust) end
                                                    --Check we're still within map bounds
                                                    if tPossibleBasePosition[1] <= iMinX or tPossibleBasePosition[1] >= iMaxX or tPossibleBasePosition[3] <= iMinZ or tPossibleBasePosition[3] >= iMaxZ then
                                                        --Out of map bounds, flag to ignore angles of this type in the future
                                                        tbSubpathOptionOffMap[iSubpathAngleOption] = true
                                                        --Are all the others flagged to be true? (i.e. is any one flagged as false)?
                                                        tbStopMovingInDirection[iCurAngleAdjust] = true
                                                        if bDebugMessages == true then LOG(sFunctionRef..': iSubpathAngleOption '..iSubpathAngleOption..' is out of map bounds; if other one is as well then will abort. tbSubpathOptionOffMap='..repr(tbSubpathOptionOffMap)) end
                                                        for _, bValue in tbSubpathOptionOffMap do
                                                            if bValue == false then
                                                                tbStopMovingInDirection[iCurAngleAdjust] = false
                                                                if bDebugMessages == true then LOG(sFunctionRef..': _='.._..'; not true so continue with main loop') end
                                                                break
                                                            end
                                                        end
                                                        if tbStopMovingInDirection[iCurAngleAdjust] == true then
                                                            if bDebugMessages == true then LOG(sFunctionRef..': Both angle options are offmap so abort main loop; will check if should abort entire loop') end
                                                            bStillDeterminingSubpaths = false
                                                            for _, bValue in tbStopMovingInDirection do
                                                                if bValue == false then bStillDeterminingSubpaths = true end
                                                            end
                                                            if bDebugMessages == true then LOG(sFunctionRef..': tbStopMovingInDirection='..repr(tbStopMovingInDirection)..'; bStillDeterminingSubpaths='..tostring(bStillDeterminingSubpaths)) end
                                                            break
                                                        end
                                                    end

                                                    --Can we path to the location? if so then record as a subpath entry
                                                    if M27MapInfo.GetSegmentGroupOfLocation(sPathingType, tPossibleBasePosition) == iStartingGroup then
                                                        bCanPathToLocation = true
                                                        break
                                                    elseif bDebugMessages == true then
                                                        LOG('Attempted subpath that cant path to; Will draw tPossibleBasePosition='..repr(tPossibleBasePosition)..' in gold')
                                                        M27Utilities.DrawLocation(tPossibleBasePosition, nil, 4, 200) --Gold
                                                    end
                                                elseif bDebugMessages == true then LOG(sFunctionRef..': tbSubpathOptionOffMap for '..iSubpathAngleOption..'='..tostring(tbSubpathOptionOffMap[iSubpathAngleOption]))
                                                end
                                            end
                                            if bStillDeterminingSubpaths == false then
                                                if bDebugMessages == true then LOG(sFunctionRef..': No longer determining subpaths so will abort') end
                                                break
                                            elseif tbStopMovingInDirection[iCurAngleAdjust] == true then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Dont want to keep going in this direction so exiting this part of loop') end
                                                break
                                            end
                                        end
                                        if bCanPathToLocation and not(tbStopMovingInDirection[iCurAngleAdjust]) then
                                            iValidSubpaths = iValidSubpaths + 1
                                            aiBrain[reftIntelLinePositions][iIntelPath][iValidSubpaths + 1] = {tPossibleBasePosition[1], tPossibleBasePosition[2], tPossibleBasePosition[3]}
                                            tiCyclesSinceLastMatch[iCurAngleAdjust] = 0
                                            if bDebugMessages == true then
                                                LOG('Subpath that can path to; Will draw tPossibleBasePosition='..repr(tPossibleBasePosition)..' in Dark blue')
                                                M27Utilities.DrawLocation(tPossibleBasePosition, nil, 1, 200)
                                            end --Dark blue
                                        end
                                    elseif bDebugMessages == true then LOG(sFunctionRef..': tbStopMovingInDirection is true for iCurAngleAdjust='..iCurAngleAdjust..'; tbStopMovingInDirection='..repr(tbStopMovingInDirection)..'; bStillDeterminingSubpaths='..tostring(bStillDeterminingSubpaths))
                                    end
                                    if bStillDeterminingSubpaths == false then
                                        if bDebugMessages == true then LOG(sFunctionRef..': No longer determining subpaths so will abort2') end
                                        break
                                    end
                                end
                            end
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': Finished doing intel path '..iIntelPath..'; will move on to next one')
                            end
                        end




                        --Record the number of scouts needed for each intel path:
                        aiBrain[reftScoutsNeededPerPathPosition] = {}
                        aiBrain[refiMinScoutsNeededForAnyPath] = 10000
                        for iCurIntelLine = 1, iValidIntelPaths do
                            aiBrain[reftScoutsNeededPerPathPosition][iCurIntelLine] = table.getn(aiBrain[reftIntelLinePositions][iCurIntelLine])
                            if aiBrain[reftScoutsNeededPerPathPosition][iCurIntelLine] < aiBrain[refiMinScoutsNeededForAnyPath] then aiBrain[refiMinScoutsNeededForAnyPath] = aiBrain[reftScoutsNeededPerPathPosition][iCurIntelLine] end
                        end
                        aiBrain[refiMaxIntelBasePaths] = table.getn(aiBrain[reftIntelLinePositions])
                        aiBrain[refbIntelPathsGenerated] = true
                        if bDebugMessages == true then LOG(sFunctionRef..'; just set intelpathsgenerated to be true') end


                        if bDebugMessages == true then
                            LOG(sFunctionRef..': End of calculating intel paths; aiBrain[refbIntelPathsGenerated]='..tostring(aiBrain[refbIntelPathsGenerated])..'; Full output of intel paths:')
                            for iIntelPath = 1, table.getn(aiBrain[reftIntelLinePositions]) do
                                LOG('iIntelPath='..iIntelPath..'; Subpaths Size='..table.getn(aiBrain[reftIntelLinePositions][iIntelPath])..'; Full subpath listing='..repr(aiBrain[reftIntelLinePositions][iIntelPath]))
                            end
                        end
                    end
                end
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Pathing not complete yet, so will assume we need a scout for every category') end
            aiBrain[refiScoutShortfallInitialRaider] = 1
            aiBrain[refiScoutShortfallACU] = 1
            aiBrain[refiScoutShortfallPriority] = 1
            aiBrain[refiScoutShortfallIntelLine] = 1
            aiBrain[refbNeedScoutPlatoons] = true
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetNearestMAAOrScout(aiBrain, tPosition, bScoutNotMAA, bDontTakeFromInitialRaiders, bOnlyConsiderAvailableHelpers, oRelatedUnitOrPlatoon)
    --Looks for the nearest specified support unit - if bScoutNotMAA is true then scout, toherwise MAA;, ignoring scouts/MAA in initial raider platoons if bDontTakeFromInitialRaiders is true
    --if bOnlyConsiderAvailableHelpers is true then won't consider units in any other existing platoons (unless they're a helper platoon with no helper)
    --returns nil if no such scout/MAA
    --oRelatedUnitOrPlatoon - use to check that aren't dealing with a support unit already assigned to the unit/platoon that are getting this for
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetNearestMAAOrScout'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bOnlyConsiderAvailableHelpers == nil then bOnlyConsiderAvailableHelpers = false end
    if bDontTakeFromInitialRaiders == nil then bDontTakeFromInitialRaiders = true end
    local iUnitCategoryWanted, sPlatoonHelperRef
    if bScoutNotMAA == true then
        iUnitCategoryWanted = M27UnitInfo.refCategoryLandScout
        sPlatoonHelperRef = refoScoutHelper
    else
        iUnitCategoryWanted = M27UnitInfo.refCategoryMAA
        sPlatoonHelperRef = refoUnitsMAAHelper
    end

    local tSupportToChooseFrom = aiBrain:GetListOfUnits(iUnitCategoryWanted, false, true)
    local oNearestSupportUnit
    if M27Utilities.IsTableEmpty(tSupportToChooseFrom) == false then
        local oTargetPlatoon
        local oExistingHelperPlatoon
        if oRelatedUnitOrPlatoon then
            if oRelatedUnitOrPlatoon.GetPlan then oTargetPlatoon = oRelatedUnitOrPlatoon
            else
                if oRelatedUnitOrPlatoon.PlatoonHandle then oTargetPlatoon = oRelatedUnitOrPlatoon.PlatoonHandle end
            end
            if oRelatedUnitOrPlatoon[sPlatoonHelperRef] then oExistingHelperPlatoon = oRelatedUnitOrPlatoon[sPlatoonHelperRef] end
        end


        local bValidSupport, iCurDistanceToPosition, oCurPlatoon
        local iMinDistanceToPosition = 100000
        if bDebugMessages == true then LOG(sFunctionRef..': Total support (scouts or MAA) to choose from='..table.getn(tSupportToChooseFrom)) end
        local oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
        local oIdleScoutPlatoon = aiBrain[M27PlatoonTemplates.refoIdleScouts]
        local oIdleMAAPlatoon = aiBrain[M27PlatoonTemplates.refoIdleMAA]
        local oCurPlatoon
        for iUnit, oUnit in tSupportToChooseFrom do
            if bDebugMessages == true then LOG(sFunctionRef..': Considering if iUnit '..iUnit..' is valid for assignment') end
            bValidSupport = false
            if not(oUnit.Dead) then
                if oUnit.GetFractionComplete and oUnit:GetFractionComplete() < 1 then
                    if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': Still being constructed') end
                else
                    if not(oUnit[M27PlatoonFormer.refbJustBuilt] == true) then
                        bValidSupport = true
                        if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': Is alive and constructed, checking if has a platoon handle') end
                        oCurPlatoon = oUnit.PlatoonHandle
                        if oCurPlatoon then
                            if bOnlyConsiderAvailableHelpers == true then
                                if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': Only want units from army pool, checking if is from army pool') end
                                if not(oCurPlatoon == oArmyPoolPlatoon) and not(oCurPlatoon == oIdleScoutPlatoon) and not(oCurPlatoon == oIdleMAAPlatoon) and not(oCurPlatoon:GetPlan() == 'M27MAAPatrol') then
                                    bValidSupport = false
                                    if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': Isnt army pool so dont want this unit unless its a helper platoon without a target') end
                                    --If it a helper platoon that has no helper target?
                                    if oCurPlatoon.GetPlan then
                                        local sPlan = oCurPlatoon:GetPlan()
                                        if sPlan == 'M27ScoutAssister' or sPlan == 'M27MAAAssister' then
                                            if oCurPlatoon[M27PlatoonUtilities.refoSupportHelperUnitTarget] == nil and oCurPlatoon[M27PlatoonUtilities.refoSupportHelperPlatoonTarget] == nil then
                                                bValidSupport = true
                                                if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': Helper platoon without a target so can use') end
                                            end
                                        end
                                    end
                                end
                            --Looking in all platoons - check we're not looking in one already assigned for the purpose wanted
                            elseif oCurPlatoon == oTargetPlatoon or oCurPlatoon == oExistingHelperPlatoon then
                                if bDebugMessages == true then LOG(sFunctionRef..': Platoon handle equals the target platoon or existing helper platoon handle') end
                                bValidSupport = false
                            else
                                if bDontTakeFromInitialRaiders == true then
                                    --Check the current platoon reference, or the assisitng platoon reference if current platoon is assisting another platoon
                                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if its in initial raider platoon or assisting them') end
                                    if oCurPlatoon then
                                        if oCurPlatoon[M27PlatoonUtilities.refoSupportHelperPlatoonTarget] then oCurPlatoon = oCurPlatoon[M27PlatoonUtilities.refoSupportHelperPlatoonTarget] end

                                        local bRaiderPlatoon = false
                                        if oCurPlatoon and oCurPlatoon.GetPlan and oCurPlatoon:GetPlan() == 'M27MexRaiderAI' then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Is in raider platoon') end
                                            bRaiderPlatoon = true
                                            --[[elseif oCurPlatoon and oCurPlatoon[sPlatoonHelperRef] and oCurPlatoon[sPlatoonHelperRef].GetPlan and oCurPlatoon[sPlatoonHelperRef].GetPlan() == 'M27MexRaiderAI' then
                                                bRaiderPlatoon = true
                                                oCurPlatoon = oCurPlatoon[sPlatoonHelperRef] --]]
                                        else
                                            if bDebugMessages == true then LOG(sFunctionRef..': Isnt in raider platoon directly or indirectly; sPlatoonHelperRef='..sPlatoonHelperRef) end
                                        end
                                        if bRaiderPlatoon == true and oCurPlatoon[M27PlatoonUtilities.refiPlatoonCount] <= aiBrain[refiInitialRaiderPlatoonsWanted] then
                                            if bDebugMessages == true then LOG(sFunctionRef..': iUnit is in raider platoon number '..oCurPlatoon[M27PlatoonUtilities.refiPlatoonCount]..'; aiBrain[refiInitialRaiderPlatoonsWanted]='..aiBrain[refiInitialRaiderPlatoonsWanted]) end
                                            bValidSupport = false
                                        end
                                    end
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': Are happy to take the unit from all existing platoons') end
                                end
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': Unit has no platoon handle so ok to use') end
                        end
                    end
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': iUnit '..iUnit..' is dead') end
            end
            if bValidSupport == true then
                --have a valid unit, record how close it is
                --GetDistanceBetweenPositions(Position1, Position2, iBuildingSize)
                iCurDistanceToPosition = M27Utilities.GetDistanceBetweenPositions(tPosition, oUnit:GetPosition())
                if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': Have a valid unit, so checking how far away it is, iCurDistanceToPosition='..iCurDistanceToPosition) end
                if iCurDistanceToPosition <= iMinDistanceToPosition then
                    iMinDistanceToPosition = iCurDistanceToPosition
                    oNearestSupportUnit = oUnit
                end
            end
        end
        if bDebugMessages == true then
            if oNearestSupportUnit == nil then LOG(sFunctionRef..': Finished cycling through all relevant units, didnt find any that can use')
            else LOG(sFunctionRef..': Finished cycling through all relevant units and found one that can use') end
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': No support units owned') end
    end
    if oNearestSupportUnit and oNearestSupportUnit[M27PlatoonFormer.refbJustBuilt] == true then M27Utilities.ErrorHandler('nearest unit was just built') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oNearestSupportUnit
end

function AssignHelperToLocation(aiBrain, oHelperToAssign, tLocation)
    local sFunctionRef = 'AssignHelperToLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oNewPlatoon = aiBrain:MakePlatoon('', '')
    aiBrain:AssignUnitsToPlatoon(oNewPlatoon, {oHelperToAssign}, 'Attack', 'GrowthFormation')
    oNewPlatoon[M27PlatoonUtilities.reftLocationToGuard] = tLocation
    oNewPlatoon:SetAIPlan('M27LocationAssister')
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function AssignHelperToPlatoonOrUnit(oHelperToAssign, oPlatoonOrUnitNeedingHelp, bScoutNotMAA)
    --Checks if the platoon/unit already has a helper, in which case adds to that, otherwise creates a new helper platoon
    --bScoutNotMAA - true if scout, false if MAA
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AssignHelperToPlatoonOrUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local aiBrain = oHelperToAssign:GetAIBrain()
    local sPlanWanted = 'M27ScoutAssister'
    local refHelper = refoScoutHelper
    local bUnitNotPlatoon = false
    if oPlatoonOrUnitNeedingHelp.PlatoonHandle or oPlatoonOrUnitNeedingHelp.GetUnitId then bUnitNotPlatoon = true end
    if bScoutNotMAA == false then
        refHelper = refoUnitsMAAHelper
        sPlanWanted = 'M27MAAAssister'
    end

    local bNeedNewHelperPlatoon = true
    local oExistingHelperPlatoon = oPlatoonOrUnitNeedingHelp[refHelper]
    if oExistingHelperPlatoon and aiBrain:PlatoonExists(oExistingHelperPlatoon) and oExistingHelperPlatoon.GetPlan and oExistingHelperPlatoon:GetPlan() == sPlanWanted then bNeedNewHelperPlatoon = false end

    if bNeedNewHelperPlatoon == true then
        oExistingHelperPlatoon = aiBrain:MakePlatoon('', '')
        oPlatoonOrUnitNeedingHelp[refHelper] = oExistingHelperPlatoon
    end
    if oHelperToAssign.PlatoonHandle and aiBrain:PlatoonExists(oHelperToAssign.PlatoonHandle) then
        M27PlatoonUtilities.RemoveUnitsFromPlatoon(oHelperToAssign.PlatoonHandle, {oHelperToAssign}, false, oExistingHelperPlatoon)
    else
        --Redundancy in case there's a scenario where you dont have a platoon handle for a MAA
        aiBrain:AssignUnitsToPlatoon(oExistingHelperPlatoon, {oHelperToAssign}, 'Attack', 'GrowthFormation')
    end
    if bDebugMessages == true then LOG(sFunctionRef..': sPlanWanted='..sPlanWanted..'; bNeedNewHelperPlatoon='..tostring(bNeedNewHelperPlatoon)) end
    if oExistingHelperPlatoon then
        if bUnitNotPlatoon == true then
            if bDebugMessages == true then LOG(sFunctionRef..': Dealing with unit not platoon') end
            oExistingHelperPlatoon[M27PlatoonUtilities.refoSupportHelperUnitTarget] = oPlatoonOrUnitNeedingHelp
            oExistingHelperPlatoon[M27PlatoonUtilities.refoSupportHelperPlatoonTarget] = nil
        else
            if bDebugMessages == true then
                --LOG(sFunctionRef..': Units in new platoon='..table.getn(oExistingHelperPlatoon:GetPlatoonUnits()))
                if oPlatoonOrUnitNeedingHelp.GetPlan then LOG('Helping platoon with a plan')
                else M27Utilities.ErrorHandler('Helping platoon that has no plan') end
            end
            oExistingHelperPlatoon[M27PlatoonUtilities.refoSupportHelperUnitTarget] = nil
            oExistingHelperPlatoon[M27PlatoonUtilities.refoSupportHelperPlatoonTarget] = oPlatoonOrUnitNeedingHelp
        end

        if bNeedNewHelperPlatoon == true then
            oExistingHelperPlatoon:SetAIPlan(sPlanWanted)
            if bDebugMessages == true then
                local iPlatoonCount = oExistingHelperPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                if iPlatoonCount == nil then
                    iPlatoonCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount][sPlanWanted]
                    if iPlatoonCount == nil then iPlatoonCount = 1
                    else iPlatoonCount = iPlatoonCount + 1 end
                end
                LOG(sFunctionRef..': Created new platoon with Plan name and count='..sPlanWanted..iPlatoonCount)
            end
        end
    else
        M27Utilities.ErrorHandler('oExistingHelperPlatoon is nil')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function AssignMAAToPreferredPlatoons(aiBrain)
    --Similar to assigning scouts, but for MAA - for now just focus on having MAA helping ACU and any platoon of >20 size that doesnt contain MAA
    --===========ACU MAA helper--------------------------
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AssignMAAToPreferredPlatoons'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iACUMinMAAThreatWantedWithAirThreat = 84 --Equivalent to 3 T1 MAA
    if aiBrain[refiOurHighestFactoryTechLevel] > 1 then
        if aiBrain[refiOurHighestFactoryTechLevel] == 2 then iACUMinMAAThreatWantedWithAirThreat = 320 --2 T2 MAA
        elseif iACUMinMAAThreatWantedWithAirThreat == 3 then iACUMinMAAThreatWantedWithAirThreat = 800 --1 T3 MAA
        end
    end
    local iAirThreatMAAFactor = 0.2 --approx mass value of MAA wanted with ACU as a % of the total air threat
    local iMaxMAAThreatForACU = 2400 --equivalent to 3 T3 MAA
    local iACUMinMAAThreatWantedWithNoAirThreat = 28 --Equivalent to 1 T1 maa
    local iMAAThreatWanted = 0
    local iMinACUMAAThreatWanted = iACUMinMAAThreatWantedWithNoAirThreat
    local iMaxMAAWantedForACUAtOnce = 2
    local tiMAAMassValue = {55, 160, 800, 800}
    local iSingleMAAMassValue = tiMAAMassValue[aiBrain[refiOurHighestFactoryTechLevel]]
    if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] <= 1000 and aiBrain[refiOurHighestFactoryTechLevel] >= 3 then iMaxMAAWantedForACUAtOnce = 1 end

    local function GetMAAThreat(tMAAUnits)
        return M27Logic.GetAirThreatLevel(aiBrain, tMAAUnits, false, false, true, false, false)
    end

    local refCategoryMAA = M27UnitInfo.refCategoryMAA
    if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] == nil then aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] = 0 end
    if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] > 0 then
        iMAAThreatWanted = math.min(iMaxMAAThreatForACU, math.max(iACUMinMAAThreatWantedWithAirThreat, math.floor(aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] * iAirThreatMAAFactor)))
        iMinACUMAAThreatWanted = iACUMinMAAThreatWantedWithAirThreat
    else
        iMAAThreatWanted = iACUMinMAAThreatWantedWithNoAirThreat
    end


    local sMAAPlatoonName = 'M27MAAAssister'
    local bNeedMoreMAA = false
    local bACUNeedsMAAHelper = true
    local oNewMAAPlatoon
    local oExistingMAAPlatoon = M27Utilities.GetACU(aiBrain)[refoUnitsMAAHelper]
    if bDebugMessages == true then LOG(sFunctionRef..': About to check if ACU needs MAA; iMAAWanted='..iMAAThreatWanted) end
    if not(oExistingMAAPlatoon == nil) then
        --A helper was assigned, check if it still exists
        if oExistingMAAPlatoon and aiBrain:PlatoonExists(oExistingMAAPlatoon) then
            --Platoon still exists; does it have the right aiplan?
            local sMAAHelperName = oExistingMAAPlatoon:GetPlan()
            if sMAAHelperName and sMAAHelperName == sMAAPlatoonName then
                if bDebugMessages == true then LOG(sFunctionRef..': sMAAHelperName='..sMAAHelperName) end
                if M27Utilities.IsTableEmpty(oExistingMAAPlatoon[M27PlatoonUtilities.reftCurrentUnits]) == false then
                    local iCurMAAHelperThreat = GetMAAThreat(oExistingMAAPlatoon[M27PlatoonUtilities.reftCurrentUnits])
                    iMAAThreatWanted = iMAAThreatWanted - iCurMAAHelperThreat
                    iMinACUMAAThreatWanted = iMinACUMAAThreatWanted - iCurMAAHelperThreat
                    if bDebugMessages == true then LOG(sFunctionRef..': iCurMAAHelperThreat='..iCurMAAHelperThreat..'; iMAAThreatWanted after factorign in this='..iMAAThreatWanted) end
                end
                --oNewMAAPlatoon = oExistingMAAPlatoon
                --does it have an MAA in it?
                --[[local tACUMAA = oExistingMAAPlatoon:GetPlatoonUnits()
                if M27Utilities.IsTableEmpty(tACUMAA) == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': MAAHelper has units') end
                    iMAAThreatWanted = iMAAThreatWanted -
                    local tExistingMAA = EntityCategoryFilterDown(refCategoryMAA, tACUMAA)
                    if M27Utilities.IsTableEmpty(tExistingMAA) == false then
                        local iExistingMAA = table.getn(tExistingMAA)
                        iMAAWanted = iMAAWanted - table.getn(tExistingMAA)
                        iCoreACUMAAWanted = iCoreACUMAAWanted - table.getn(tExistingMAA)
                        if bDebugMessages == true then LOG(sFunctionRef..': MAAHelper has units, reducing iMAAWanted to '..iMAAWanted) end
                    end
                end--]]
            else
                if bDebugMessages == true then
                    if sMAAHelperName == nil then LOG(sFunctionRef..': MAA Helper has a nil plan; changing')
                    else LOG(sFunctionRef..': MAAHelper doesnt have the right plan; changing') end
                end
                oExistingMAAPlatoon:SetAIPlan(sMAAPlatoonName)
            end
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': No MAA helper assigned previously') end
    end
    if iMAAThreatWanted <= 0 then
        bACUNeedsMAAHelper = false
    end


    if bDebugMessages == true then LOG(sFunctionRef..': iMAAThreatWanted='..iMAAThreatWanted..'; bACUNeedsMAAHelper='..tostring(bACUNeedsMAAHelper)) end
    if bACUNeedsMAAHelper == true then
        local iCurMAAUnitThreat = 0
        --Assign MAA if we have any available; as its the ACU we want the nearest MAA of any platoon
        if bDebugMessages == true then LOG(sFunctionRef..': Checking for nearest mobileMAA; iMAAThreatWanted='..iMAAThreatWanted) end
        local oMAAToGive
        local iCurLoopCount = 0
        local iMaxLoopCount = 100
        local oACU = M27Utilities.GetACU(aiBrain)
        while iMAAThreatWanted > 0 do
            iCurLoopCount = iCurLoopCount + 1
            if iCurLoopCount > iMaxLoopCount then M27Utilities.ErrorHandler('likely infinite loop') break end

            oMAAToGive = GetNearestMAAOrScout(aiBrain, oACU:GetPosition(), false, true, false, oACU)
            if oMAAToGive == nil or oMAAToGive.Dead then
                if bDebugMessages == true then LOG(sFunctionRef..': oMAAToGive is nil or dead') end
                bNeedMoreMAA = true
                break
            else
                iCurMAAUnitThreat = GetMAAThreat({oMAAToGive})
                iMAAThreatWanted = iMAAThreatWanted - iCurMAAUnitThreat
                iMinACUMAAThreatWanted = iMinACUMAAThreatWanted - iCurMAAUnitThreat

                if bDebugMessages == true then LOG(sFunctionRef..': oMAAToGive is valid, will create new platoon (if dont already have one) and assign it if havent already created') end
                AssignHelperToPlatoonOrUnit(oMAAToGive, M27Utilities.GetACU(aiBrain), false)
            end
        end

        if iMAAThreatWanted <= 0 then
            aiBrain[refiMAAShortfallACUPrecaution] = 0
            aiBrain[refiMAAShortfallACUCore] = 0
        else
            if iMinACUMAAThreatWanted <= 0 then
                aiBrain[refiMAAShortfallACUCore] = 0
                aiBrain[refiMAAShortfallACUPrecaution] = iMaxMAAWantedForACUAtOnce
            else
                aiBrain[refiMAAShortfallACUCore] = iMaxMAAWantedForACUAtOnce
                aiBrain[refiMAAShortfallACUPrecaution] = 0 --Dont want to produce more than the max wanted at once
            end

        end
    else
        --ACU doesnt need more MAA
        aiBrain[refiMAAShortfallACUPrecaution] = 0
        aiBrain[refiMAAShortfallACUCore] = 0
    end

    if iMAAThreatWanted <= 0 then --Have more than enough MAA to cover ACU, move on to considering if large platoons can get MAA support
        --=================Large platoons - ensure they have MAA in them, and if not then add MAA
        local tPlatoonUnits, iPlatoonUnits, tPlatoonCurrentMAAs, oMAAToAdd, oMAAOldPlatoon

        local iThresholdForAMAA
        if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] == nil then aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] = 0 end
        if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] > 0 then
            iThresholdForAMAA = 250 + (500 * (aiBrain[refiOurHighestFactoryTechLevel] - 1))
        else iThresholdForAMAA = 750 + (1500 * (aiBrain[refiOurHighestFactoryTechLevel] - 1))
        end
        local iMAAWanted = 0
        local iTotalMAAWanted = 0
        local iMAAAlreadyHave
        local iCurLoopCount
        local iMaxLoopCount = 50

        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] then
            for iCurPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
                if not(oPlatoon[M27PlatoonTemplates.refbIdlePlatoon]) and not(oPlatoon[M27PlatoonTemplates.refbRequiresUnitToFollow]) and not(oPlatoon[M27PlatoonTemplates.refbRunFromAllEnemies]) then
                    if (oPlatoon[M27PlatoonUtilities.refiPlatoonMassValue] or 0) >= iThresholdForAMAA then
                        --Can we path here with land from our base?
                        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] or M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)) == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then
                            iMAAWanted = math.floor(oPlatoon[M27PlatoonUtilities.refiPlatoonMassValue] / iThresholdForAMAA)
                            tPlatoonCurrentMAAs = EntityCategoryFilterDown(refCategoryMAA, oPlatoon:GetPlatoonUnits())
                            if M27Utilities.IsTableEmpty(tPlatoonCurrentMAAs) == true then iMAAAlreadyHave = 0
                                --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride, bIncludeAirTorpedo)
                                else iMAAAlreadyHave = GetAirThreatLevel(aiBrain, tPlatoonCurrentMAAs, false, false, true, false, false, nil, nil, nil, nil, nil) end
                            if oPlatoon[refoUnitsMAAHelper] then
                                --tPlatoonCurrentMAAs = oPlatoon[refoUnitsMAAHelper]:GetPlatoonUnits()
                                --if M27Utilities.IsTableEmpty(tPlatoonCurrentMAAs) == false then
                                    iMAAAlreadyHave = iMAAAlreadyHave + oPlatoon[refoUnitsMAAHelper][M27PlatoonUtilities.refiPlatoonMassValue]
                                --end
                            end
                            iCurLoopCount = 0

                            --Convert to number of units
                            iMAAWanted = math.floor(iMAAWanted / iSingleMAAMassValue)
                            iMAAAlreadyHave = math.ceil(iMAAAlreadyHave / iSingleMAAMassValue)

                            while iMAAWanted > iMAAAlreadyHave do
                                iCurLoopCount = iCurLoopCount + 1
                                if iCurLoopCount > iMaxLoopCount then
                                    M27Utilities.ErrorHandler('likely infinite loop')
                                    break
                                end
                                --Need MAAs in the platoon
                                oMAAToAdd = GetNearestMAAOrScout(aiBrain, tPlatoonUnits[1]:GetPosition(), false, true, true, oPlatoon)
                                if oMAAToAdd == nil then
                                    bNeedMoreMAA = true
                                    break
                                else
                                    --Have a valid MAA - add it to the platoon
                                    iMAAAlreadyHave = iMAAAlreadyHave + 1

                                    AssignHelperToPlatoonOrUnit(oMAAToAdd, oPlatoon, false)
                                    --[[oMAAOldPlatoon = oMAAToAdd.PlatoonHandle
                                    if oMAAOldPlatoon then
                                        --RemoveUnitsFromPlatoon(oPlatoon, tUnits, bReturnToBase, oPlatoonToAddTo)
                                        M27PlatoonUtilities.RemoveUnitsFromPlatoon(oMAAOldPlatoon, { oMAAToAdd}, false, oPlatoon)
                                    else
                                        --Dont have platoon for the MAA so add manually (backup for unexpected scenarios)
                                        aiBrain:AssignUnitsToPlatoon(oPlatoon, { oMAAToAdd}, 'Unassigned', 'None')
                                    end--]]

                                end
                            end
                        end
                        if iMAAWanted > iMAAAlreadyHave then
                            iTotalMAAWanted = iMAAWanted - iMAAAlreadyHave
                            break
                        end
                    end
                end
            end
        end
        aiBrain[refiMAAShortfallLargePlatoons] = iTotalMAAWanted
        if aiBrain[refiMAAShortfallLargePlatoons] > 0 then aiBrain[refiMAAShortfallBase] = 1
        else aiBrain[refiMAAShortfallBase] = 0 end
    end


    --========Build order related TODO longer term - update the current true/false flag in the factory overseer to differentiate between the MAA wanted
    if aiBrain[refiMAAShortfallACUPrecaution] + aiBrain[refiMAAShortfallACUCore] + aiBrain[refiMAAShortfallLargePlatoons] > 0 then bNeedMoreMAA = true
    else bNeedMoreMAA = false end
    aiBrain[refbNeedMAABuilt] = bNeedMoreMAA
    if bDebugMessages == true then LOG(sFunctionRef..': End of MAA assignment logic; aiBrain[refiMAAShortfallACUPrecaution]='..aiBrain[refiMAAShortfallACUPrecaution]..'; aiBrain[refiMAAShortfallACUCore]='..aiBrain[refiMAAShortfallACUCore]..'; aiBrain[refiMAAShortfallLargePlatoons]='..aiBrain[refiMAAShortfallLargePlatoons]) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetEnemyNetThreatAlongIntelPath(aiBrain, iIntelPathBaseNumber, iIntelPathEnemySearchRange, iAllySearchRange)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetEnemyNetThreatAlongIntelPath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iCurEnemyThreat = 0
    local iCurAllyThreat = 0
    local iTotalEnemyNetThreat = 0
    local bScoutNearAllMexes = true
    local tNearbyScouts
    local tEnemyUnitsNearPoint, tEnemyStructuresNearPoint
    if bDebugMessages == true then LOG(sFunctionRef..': About to loop through subpath positions. aiBrain[refiCurIntelLineTarget]='..aiBrain[refiCurIntelLineTarget]) end
    local iLoopCount1 = 0
    local iLoopMax1 = 100
    local tNearbyAllies, tNearbyEnemies

    for iSubPath, tSubPathPosition in aiBrain[reftIntelLinePositions][iIntelPathBaseNumber] do
        --GetCombatThreatRating(aiBrain, tUnits, bUseBlip, iMassValueOfBlipsOverride)
        --To keep things simple will look for units within iIntelPathEnemySearchRange of each path position;
        --Some niche cases where this will be inaccurate: Pathing results in 2 path positions being closer together, and units get counted twice
        --Also this is looking at circles around the point - units that are in the middle of 2 points may not be counted
        --20 is used because the lowest scout intel range is 40, but some are higher
        iLoopCount1 = iLoopCount1 + 1
        if iLoopCount1 > iLoopMax1 then
            M27Utilities.ErrorHandler('Likely infinite loop, iIntelPathBaseNumber='..iIntelPathBaseNumber..'; iSubpath='..iSubPath..'; iLoopCount1='..iLoopCount1..'; size of subpath table='..table.getn(aiBrain[reftIntelLinePositions][iIntelPathBaseNumber]))
            break
        end
        if aiBrain == nil then M27Utilities.ErrorHandler('aiBrain is nil') end
        tNearbyEnemies = aiBrain:GetUnitsAroundPoint(categories.MOBILE + M27UnitInfo.refCategoryStructure, tSubPathPosition, iIntelPathEnemySearchRange, 'Enemy')
        tNearbyAllies = aiBrain:GetUnitsAroundPoint(categories.MOBILE + M27UnitInfo.refCategoryStructure, tSubPathPosition, iAllySearchRange, 'Ally')
        if bDebugMessages == true then LOG(sFunctionRef..'; iSubPath='..iSubPath..'; about to get enemy and ally threat around point') end
        if bDebugMessages == true then LOG(sFunctionRef..': tSubPathPosition='..repr(tSubPathPosition)) end
        if bDebugMessages == true then LOG(sFunctionRef..': is tNearbyEnemies empty?='..tostring(M27Utilities.IsTableEmpty(tNearbyEnemies))) end


        if M27Utilities.IsTableEmpty(tNearbyEnemies) == true then iCurEnemyThreat = 0 else
            iCurEnemyThreat = M27Logic.GetCombatThreatRating(aiBrain, tNearbyEnemies, true) end
        if bDebugMessages == true then LOG(sFunctionRef..': About to get threat for nearby allies') end
        if M27Utilities.IsTableEmpty(tNearbyAllies) == true then iCurAllyThreat = 0 else
            iCurAllyThreat = M27Logic.GetCombatThreatRating(aiBrain, tNearbyAllies, false) end
        iTotalEnemyNetThreat = math.max(iCurEnemyThreat - iCurAllyThreat, 0) + iTotalEnemyNetThreat
        if bDebugMessages == true then LOG(sFunctionRef..'; iSubPath='..iSubPath..'; iCurEnemyThreat='..iCurEnemyThreat..'; iCurAllyThreat='..iCurAllyThreat..'; iTotalEnemyNetThreat='..iTotalEnemyNetThreat) end
        if iTotalEnemyNetThreat > 170 then
            if bDebugMessages == true then LOG(sFunctionRef..': enemy threat is more than 170 so dont want to advance path, treat it as not having scouts near every location') end
            bScoutNearAllMexes = false
            break
        else
            --Is the scout assigned to this position on a further subpath?
            if bDebugMessages == true then LOG(sFunctionRef..': Will see if scout modification is <= 0') end
            if (aiBrain[reftiSubpathModFromBase][iIntelPathBaseNumber][iSubPath] or 0) <= 0 then
                tNearbyScouts = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandScout, tSubPathPosition, iIntelPathEnemySearchRange, 'Ally')
                if M27Utilities.IsTableEmpty(tNearbyScouts) then
                    --Do we have intel or visual coverage?
                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if have intel coverage of tSubPathPosition='..repr(tSubPathPosition)) end
                    if not(M27Logic.GetIntelCoverageOfPosition(aiBrain, tSubPathPosition, 25, false)) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Dont have intel coverage of the target position; will draw gold circle around it')
                            M27Utilities.DrawLocation(tSubPathPosition, nil, 4, 20, nil)
                        end
                        bScoutNearAllMexes = false
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iTotalEnemyNetThreat, bScoutNearAllMexes
end

function AssignScoutsToPreferredPlatoons(aiBrain)
    --Goes through all scouts we have, and assigns them to highest priority tasks
    --Tries to form an intel line (and manages the location of this), and requests more scouts are built if dont have enough to form an intel line platoon;
    --Also records the number of scouts needed to complete things
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AssignScoutsToPreferredPlatoons'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Rare error - AI mass produces scouts - logs enabled for if this happens
    local refCategoryLandScout = M27UnitInfo.refCategoryLandScout
    local tAllScouts = aiBrain:GetListOfUnits(refCategoryLandScout, false, true)
    local iScouts = 0
    local iIntelPathEnemySearchRange = 35 --min scout range is 40, some are higher, this gives a bit of leeway
    local bAbort = false

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end

    local sScoutPathing = (aiBrain[refsLastScoutPathingType] or M27UnitInfo.refPathingTypeLand)

    if M27Utilities.IsTableEmpty(tAllScouts) == false then iScouts = table.getn(tAllScouts) end
    if iScouts >= 25 then
        local iNonScouts = aiBrain:GetCurrentUnits(categories.MOBILE * categories.LAND - categories.SCOUT)
        if iScouts > 80 then
            LOG('Have 80 scouts, seems higher than would expect')
            if iScouts > 120 and iScouts > iNonScouts then
                M27Utilities.ErrorHandler('Warning possible error unless large map or lots of small platoons - more than 25 scouts, but only '..iNonScouts..' non-scouts; iScouts='..iScouts..'; turning on debug messages.  Still stop producing scouts if get to 100')
                aiBrain[refiScoutShortfallInitialRaider] = 0
                aiBrain[refiScoutShortfallACU] = 0
                aiBrain[refiScoutShortfallPriority] = 0
                aiBrain[refiScoutShortfallIntelLine] = 0
                aiBrain[refiScoutShortfallLargePlatoons] = 0
                aiBrain[refiScoutShortfallAllPlatoons] = 0
                aiBrain[refiScoutShortfallMexes] = 0
                bAbort = true
            end
        end
    end
    if bAbort == false then
        local oArmyPoolPlatoon, tArmyPoolScouts
        if iScouts > 0 then
            local oScoutToGive
            --============Initial mex raider scouts-----------------------
            --Check initial raiders have scouts (1-off at start of game)
            if aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] == nil then aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] = {} end
            local iRaiderCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27MexRaiderAI']
            if iRaiderCount == nil then
                iRaiderCount = 0
                aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27MexRaiderAI'] = 0
            end
            --local iMinScoutsWantedInPool = 0 --This is also changed several times below
            if bDebugMessages == true then LOG(sFunctionRef..': Have iScouts='..iScouts..'; About to check if raiders have been checked for scouts; iScouts='..iScouts..'; iRaiderCount='..iRaiderCount..'; aiBrain[refbConfirmedInitialRaidersHaveScouts]='..tostring(aiBrain[refbConfirmedInitialRaidersHaveScouts])) end

            local iAvailableScouts = iScouts
            local iRaiderScoutsMissing = 0
            if iRaiderCount > 0 then
                --Have we checked that the raiders have scouts in them?  If not, then as a 1-off add scouts to them
                if aiBrain[refbConfirmedInitialRaidersHaveScouts] == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': About to check if we have enough scouts to assign to the raider platoons if they need them') end
                    if iScouts >= 1 then --we should have a scout for the raider platoon
                        --if iScouts >= aiBrain[refiInitialRaiderPlatoonsWanted] and iRaiderCount >= aiBrain[refiInitialRaiderPlatoonsWanted] then aiBrain[refbConfirmedInitialRaidersHaveScouts] = true end --will be giving scouts in later step
                        --iMinScoutsWantedInPool = 0
                        if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through each platoon to get the initialraider platoons') end
                        for iCurPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
                            if not(oPlatoon == oArmyPoolPlatoon) then
                                if oPlatoon:GetPlan() == 'M27MexRaiderAI' then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have found a raider platoon, oPlatoon[M27PlatoonUtilities.refiPlatoonCount]='..oPlatoon[M27PlatoonUtilities.refiPlatoonCount]) end
                                    if oPlatoon[M27PlatoonUtilities.refiPlatoonCount] <= aiBrain[refiInitialRaiderPlatoonsWanted] then
                                        local tRaiders = oPlatoon:GetPlatoonUnits()
                                        if M27Utilities.IsTableEmpty(tRaiders) == false then
                                            local tRaiderScouts = EntityCategoryFilterDown(refCategoryLandScout, tRaiders)
                                            local bHaveScout = false
                                            if M27Utilities.IsTableEmpty(tRaiderScouts) == false then bHaveScout = true
                                            elseif oPlatoon[refoScoutHelper] then
                                                tRaiderScouts = oPlatoon[refoScoutHelper]:GetPlatoonUnits()
                                                if M27Utilities.IsTableEmpty(tRaiderScouts) == false then bHaveScout = true end
                                            end
                                            if bHaveScout == false then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Raider platoon'..oPlatoon[M27PlatoonUtilities.refiPlatoonCount]..' doesnt have any scouts, seeing if we can give it a scout') end
                                                --Platoon doesnt have a scout - can we give it one?
                                                local tPlatoonPosition = M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)
                                                oScoutToGive = GetNearestMAAOrScout(aiBrain, tPlatoonPosition, true, true, true)
                                                if oScoutToGive == nil then oScoutToGive = GetNearestMAAOrScout(aiBrain, tPlatoonPosition, true, true, false) end
                                                if oScoutToGive == nil then iRaiderScoutsMissing = iRaiderScoutsMissing + 1
                                                else
                                                    iAvailableScouts = iAvailableScouts - 1

                                                    AssignHelperToPlatoonOrUnit(oScoutToGive, oPlatoon, true)

                                                end
                                                oPlatoon:SetPlatoonFormationOverride('AttackFormation') --want raider bots and scouts to stick together
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        --Available scouts will include those under construction; if are already constructing the scouts we need then update flag so we dont produce more:
                        if iRaiderScoutsMissing == 0 and iRaiderCount >= aiBrain[refiInitialRaiderPlatoonsWanted] then
                            aiBrain[refbConfirmedInitialRaidersHaveScouts] = true
                            aiBrain[refiScoutShortfallInitialRaider] = 0
                        else aiBrain[refiScoutShortfallInitialRaider] = math.max(aiBrain[refiInitialRaiderPlatoonsWanted] - iRaiderCount, 0) + iRaiderScoutsMissing
                        end
                    end
                end
            end
            iAvailableScouts = iAvailableScouts - iRaiderScoutsMissing
            if iAvailableScouts < 0 then
                if bDebugMessages == true then LOG(sFunctionRef..': iAvailableScouts='..iAvailableScouts..'; not enough for intiial raider so will flag as having shortfall') end
                if aiBrain[refiScoutShortfallInitialRaider] < 1 then aiBrain[refiScoutShortfallInitialRaider] = -iAvailableScouts end --redundancy/backup - shouldnt need due to above
                aiBrain[refiScoutShortfallACU] = 1
                aiBrain[refiScoutShortfallPriority] = 1
                aiBrain[refiScoutShortfallIntelLine] = aiBrain[refiMinScoutsNeededForAnyPath]
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Have enough scouts for initial raiders so will set shortfall to 0; if available scouts is 0 then will flag acu has shortfall. iAvailableScouts='..iAvailableScouts) end
                aiBrain[refiScoutShortfallInitialRaider] = 0
                if iAvailableScouts == 0 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Dont ahve any more available scouts so setting shortfall to 1 for ACU') end
                    aiBrain[refiScoutShortfallACU] = 1
                    aiBrain[refiScoutShortfallPriority] = 1
                    aiBrain[refiScoutShortfallIntelLine] = aiBrain[refiMinScoutsNeededForAnyPath]
                else --Have at least 1 available scout
                    if bDebugMessages == true then LOG(sFunctionRef..': Have at least 1 available scout so will assign to ACU') end

                    --===========ACU Scout helper--------------------------
                    --We have more than enough scouts to cover initial raiders; next priority is the ACU
                    local bACUNeedsScoutHelper = true
                    if not(M27Utilities.GetACU(aiBrain)[refoScoutHelper] == nil) then
                        --A scout helper was assigned, check if it still exists
                        if M27Utilities.GetACU(aiBrain)[refoScoutHelper] and aiBrain:PlatoonExists(M27Utilities.GetACU(aiBrain)[refoScoutHelper]) then
                            --Platoon still exists; does it have the right aiplan?
                            local sScoutHelperName = M27Utilities.GetACU(aiBrain)[refoScoutHelper]:GetPlan()
                            if sScoutHelperName and sScoutHelperName == 'M27ScoutAssister' then
                                --does it have a scout in it?
                                local tACUScout = M27Utilities.GetACU(aiBrain)[refoScoutHelper]:GetPlatoonUnits()
                                if M27Utilities.IsTableEmpty(tACUScout) == false then
                                    if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(refCategoryLandScout, tACUScout)) == false then
                                        bACUNeedsScoutHelper = false
                                    end
                                end
                            end
                        end
                    end
                    if bACUNeedsScoutHelper == true then
                        --Assign a scout if we have any available; as its the ACU we want the nearest scout of any platoon (except initial raiders with count of 1 or 2)
                        oScoutToGive = GetNearestMAAOrScout(aiBrain, M27Utilities.GetACU(aiBrain):GetPosition(), true, true, false)

                        if not(oScoutToGive == nil) then
                            AssignHelperToPlatoonOrUnit(oScoutToGive, M27Utilities.GetACU(aiBrain), true)

                        end
                    end
                    iAvailableScouts = iAvailableScouts - 1
                    aiBrain[refiScoutShortfallACU] = 0
                    if bDebugMessages == true then LOG(sFunctionRef..': Finished assining to ACU, aiBrain[refiScoutShortfallACU]='..aiBrain[refiScoutShortfallACU]) end

                    --Priority scout locations (e.g. mexes under attack from unseen enemy) - update the list
                    local iPriorityTargets = 0
                    if M27Utilities.IsTableEmpty(aiBrain[reftPriorityLandScoutTargets]) == false then
                        for iPriorityTarget, oPriorityTarget in aiBrain[reftPriorityLandScoutTargets] do
                            if M27UnitInfo.IsUnitValid(oPriorityTarget) then
                                iPriorityTargets = iPriorityTargets + 1
                            else
                                aiBrain[reftPriorityLandScoutTargets][iPriorityTarget] = nil
                            end
                        end
                    end


                    if iAvailableScouts > 0 then
                        if iPriorityTargets == 0 then aiBrain[refiScoutShortfallPriority] = 0
                        else
                            --do all of the priority targets have a scout assigned?
                            for iPriorityTarget, oPriorityTarget in aiBrain[reftPriorityLandScoutTargets] do
                                if not(M27UnitInfo.IsUnitValid(oPriorityTarget[refoScoutHelper])) then
                                    --Need a scout, can take from most places
                                    oScoutToGive = GetNearestMAAOrScout(aiBrain, oPriorityTarget:GetPosition(), true, true, false)
                                    if oScoutToGive then
                                        AssignHelperToPlatoonOrUnit(oScoutToGive, oPriorityTarget, true)
                                        iAvailableScouts = iAvailableScouts - 1
                                        iPriorityTargets = iPriorityTargets - 1
                                    else
                                        aiBrain[refiScoutShortfallPriority] = iPriorityTargets
                                        break
                                    end
                                end
                            end
                        end
                    else
                        aiBrain[refiScoutShortfallPriority] = iPriorityTargets
                    end

                    --==========Intel Line manager
                    if iAvailableScouts <= 0 then
                        if bDebugMessages == true then LOG(sFunctionRef..': No available scouts so will flag intel path shortfall') end
                        aiBrain[refiScoutShortfallIntelLine] = aiBrain[refiMinScoutsNeededForAnyPath]
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': iAvailableScouts='..iAvailableScouts..'; will now assign to intel path') end
                        --Do we have an intel platoon yet?
                        local tIntelPlatoons = {}
                        local iIntelPlatoons = 0
                        --local oFirstIntelPlatoon
                        local tCurIntelScouts = {}
                        local iCurIntelScouts = 0
                        local iIntelScouts = 0
                        if bDebugMessages == true then LOG(sFunctionRef..': Cycling through all platoons to identify intel platoons. aiBrain[refiScoutShortfallACU]='..aiBrain[refiScoutShortfallACU]) end
                        for iPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
                            if oPlatoon:GetPlan() == sIntelPlatoonRef then
                                tCurIntelScouts = EntityCategoryFilterDown(refCategoryLandScout, oPlatoon:GetPlatoonUnits())
                                if not(tCurIntelScouts == nil) then
                                    iCurIntelScouts = table.getn(tCurIntelScouts)
                                    if iCurIntelScouts > 0 then
                                        iIntelScouts = iIntelScouts + iCurIntelScouts
                                        iIntelPlatoons = iIntelPlatoons + 1
                                        tIntelPlatoons[iIntelPlatoons] = oPlatoon
                                    end
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Intel platoons identified; aiBrain[refiScoutShortfallACU]='..aiBrain[refiScoutShortfallACU]..'; iIntelPlatoons='..iIntelPlatoons) end
                        --if iIntelPlatoons > 0 then

                        --First determine what intel path line we want, and if we have enough scouts to achieve this
                        local bRefreshPath = false
                        local iPrevIntelLineTarget = aiBrain[refiCurIntelLineTarget]
                        if aiBrain[refiCurIntelLineTarget] == nil then aiBrain[refiCurIntelLineTarget] = 1 bRefreshPath = true end
                        --Determine the point on the path that we want:
                        --Do we have at least the minimum number of scouts needed for any intel path to be covered in full? Otherwise will stick with the first path
                        if iAvailableScouts >= (aiBrain[refiMinScoutsNeededForAnyPath] - 2) then
                            --Determine the preferred path, if we ignore the number of scouts needed for now:
                            --Is the ACU further forwards than the central path point?
                            local tACUPos = M27Utilities.GetACU(aiBrain):GetPosition()

                            if M27Logic.GetNearestEnemyStartNumber(aiBrain) then
                                local iACUDistToEnemy = M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                                local iACUDistToHome = M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                local iPathDistToEnemy = M27Utilities.GetDistanceBetweenPositions(aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]][1], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                                local iPathDistToHome = M27Utilities.GetDistanceBetweenPositions(aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]][1], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                local bACUNeedsSupport = false
                                if iACUDistToEnemy < iPathDistToEnemy then
                                    if iACUDistToHome > iPathDistToHome then
                                        bACUNeedsSupport = true
                                        --Does the ACU have nearby scout support?
                                        local tScoutsNearACU = aiBrain:GetUnitsAroundPoint(refCategoryLandScout, tACUPos, iIntelPathEnemySearchRange, 'Ally')
                                        if not(tScoutsNearACU == nil) then
                                            if table.getn(tScoutsNearACU) > 0 then
                                                bACUNeedsSupport = false
                                            end
                                        end
                                    end
                                end
                                if bACUNeedsSupport == true then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Want to move scouts forward so ACU has better intel') end
                                    aiBrain[refiCurIntelLineTarget] = aiBrain[refiCurIntelLineTarget] + 1
                                else
                                    --Cycle through each point on the current path, and check various conditions:

                                    if bDebugMessages == true then LOG(sFunctionRef..': About to loop through subpath positions to see if we can move the line forward. aiBrain[refiCurIntelLineTarget]='..aiBrain[refiCurIntelLineTarget]) end
                                    local iTotalEnemyNetThreat, bScoutNearAllMexes = GetEnemyNetThreatAlongIntelPath(aiBrain, aiBrain[refiCurIntelLineTarget], iIntelPathEnemySearchRange, 35)
                                    if bDebugMessages == true then LOG(sFunctionRef..': Finished looping through subpath positions, iTotalEnemyNetThreat='..iTotalEnemyNetThreat..'; bScoutNearAllMexes='..tostring(bScoutNearAllMexes)) end
                                    if iTotalEnemyNetThreat > 170 then
                                        aiBrain[refiCurIntelLineTarget] = aiBrain[refiCurIntelLineTarget] - 1
                                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy net threat of '..iTotalEnemyNetThreat..' exceeds 170 so reducing current intel line target by 1 to '..aiBrain[refiCurIntelLineTarget]) end
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': iTotalEnemyNetThreat='..iTotalEnemyNetThreat..'; If 0 or less and scouts are in position then will increase intel base path') end
                                        if iTotalEnemyNetThreat <= 0 then
                                            --Are all scouts in position?
                                            if bDebugMessages == true then LOG(sFunctionRef..': Checking if all scouts are in position. bScoutNearAllMexes='..tostring(bScoutNearAllMexes)..'; table.getn(aiBrain[reftIntelLinePositions])='..table.getn(aiBrain[reftIntelLinePositions])..'; aiBrain[refiCurIntelLineTarget='..aiBrain[refiCurIntelLineTarget]) end
                                            if bScoutNearAllMexes == true and table.getn(aiBrain[reftIntelLinePositions]) > aiBrain[refiCurIntelLineTarget] then
                                                --If we move the intel line up by 1 will we have too much enemy threat?
                                                iTotalEnemyNetThreat = GetEnemyNetThreatAlongIntelPath(aiBrain, aiBrain[refiCurIntelLineTarget] + 1, iIntelPathEnemySearchRange, 35)
                                                if bDebugMessages == true then LOG(sFunctionRef..': If we increase the intel path by 1, then the total enemy net threat is '..iTotalEnemyNetThreat..'; will only increase if this is <= 0') end
                                                if iTotalEnemyNetThreat <= 0 then
                                                    aiBrain[refiCurIntelLineTarget] = aiBrain[refiCurIntelLineTarget] + 1
                                                    if bDebugMessages == true then LOG(sFunctionRef..': All scouts are in position so increasing intel path by 1 to '..aiBrain[refiCurIntelLineTarget]) end
                                                end
                                            end
                                        end
                                    end
                                end
                            else
                                if not(M27Logic.iTimeOfLastBrainAllDefeated) or M27Logic.iTimeOfLastBrainAllDefeated < 10 then
                                    M27Utilities.ErrorHandler('M27Logic.GetNearestEnemyStartNumber(aiBrain) is nil')
                                end
                            end
                        else --Dont have enough scouts to cover any path, to stick with initial base path
                            if bDebugMessages == true then LOG(sFunctionRef..': Dont have enough scouts to cover any intel path, stay at base path; aiBrain[refiMinScoutsNeededForAnyPath]='..aiBrain[refiMinScoutsNeededForAnyPath]..'; iIntelPlatoons='..iIntelPlatoons) end
                            aiBrain[refiCurIntelLineTarget] = 1
                        end
                        --Keep within min and max (this is repeated as needed here to make sure iscoutswanted doesnt cause error)
                        if aiBrain[refiCurIntelLineTarget] <= 0 then aiBrain[refiCurIntelLineTarget] = 1
                        elseif aiBrain[refiCurIntelLineTarget] > aiBrain[refiMaxIntelBasePaths] then aiBrain[refiCurIntelLineTarget] = aiBrain[refiMaxIntelBasePaths] end

                        if bDebugMessages == true then LOG('aiBrain[refiScoutShortfallACU]='..aiBrain[refiScoutShortfallACU]..'; aiBrain[refiCurIntelLineTarget]='..aiBrain[refiCurIntelLineTarget]..'; table.getn(aiBrain[reftIntelLinePositions])='..table.getn(aiBrain[reftIntelLinePositions])..'; aiBrain[refiMaxIntelBasePaths]='..aiBrain[refiMaxIntelBasePaths]) end
                        local iScoutsWanted = table.getn(aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]])
                        local iScoutsForNextPath = aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]+1]
                        if iScoutsForNextPath then iScoutsForNextPath = table.getn(iScoutsForNextPath) end
                        if iScoutsForNextPath == nil then iScoutsForNextPath = iScoutsWanted end

                        if iAvailableScouts <= iScoutsWanted or iAvailableScouts <= iScoutsForNextPath then
                            local iScoutsToBuild = iScoutsWanted - iAvailableScouts
                            if iScoutsForNextPath > iScoutsWanted then iScoutsToBuild = iScoutsForNextPath - iScoutsWanted end
                            iScoutsToBuild = iScoutsToBuild + 1
                            aiBrain[refiScoutShortfallIntelLine] = iScoutsToBuild
                        else aiBrain[refiScoutShortfallIntelLine] = 0
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[refiScoutShortfallACU]='..aiBrain[refiScoutShortfallACU]..'; iScoutsWanted='..iScoutsWanted..'; iScoutsForNextPath='..iScoutsForNextPath..'aiBrain[refiScoutShortfallIntelLine]='..aiBrain[refiScoutShortfallIntelLine]) end

                        local iLoopCount = 0
                        local iLoopMax = 100
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': refiCurIntelLineTarget='..aiBrain[refiCurIntelLineTarget]..'; About to loop through scouts wanted; iScoutsWanted='..iScoutsWanted..'; iIntelScouts='..iIntelScouts)
                            LOG('About to log every path in the current line:')
                            for iCurSubPath, tPath in aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]] do
                                LOG('iCurSubPath='..iCurSubPath..'; repr='..repr(tPath))
                            end
                        end
                        while iAvailableScouts < (iScoutsWanted - 2) do
                            --Too few to try and maintain intel path, so fall back 1 position
                            iLoopCount = iLoopCount + 1
                            if iLoopCount > iLoopMax then
                                M27Utilities.ErrorHandler('likely infinite loop - exceeded iLoopMax of '..iLoopMax..'; refiCurIntelLineTarget='..aiBrain[refiCurIntelLineTarget])
                                break
                            end
                            aiBrain[refiCurIntelLineTarget] = aiBrain[refiCurIntelLineTarget] - 1
                            if aiBrain[refiCurIntelLineTarget] <= 1 then break end
                            iScoutsWanted = table.getn(aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]])
                        end
                        --Keep within min and max possible targets:
                        if aiBrain[refiCurIntelLineTarget] <= 0 then aiBrain[refiCurIntelLineTarget] = 1
                        elseif aiBrain[refiCurIntelLineTarget] > aiBrain[refiMaxIntelBasePaths] then aiBrain[refiCurIntelLineTarget] = aiBrain[refiMaxIntelBasePaths] end

                        --Consider moving forwards at individual points if already have a scout near the current position and no enemies:
                        if aiBrain[refiCurIntelLineTarget] <= 0 then aiBrain[refiCurIntelLineTarget] = 1
                        elseif aiBrain[refiCurIntelLineTarget] > aiBrain[refiMaxIntelBasePaths] then aiBrain[refiCurIntelLineTarget] = aiBrain[refiMaxIntelBasePaths] end


                        --If we have enough scouts for the current path, then consider each individual point on the path and whether it can go further forwards than the base, provided we have enough scouts to
                        if aiBrain[refiScoutShortfallIntelLine] == 0 then
                            local tNearbyEnemiesBase
                            local tNearbyEnemiesPlus1, tSubPathPlus1
                            local tNearbyEnemiesPlus2, tSubPathPlus2
                            local iIncreaseInSubpath, iMaxIncreaseInSubpath, iNextMaxIncrease
                            local iCurIntelLineTarget = aiBrain[refiCurIntelLineTarget]
                            if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[refiScoutShortfallACU]='..aiBrain[refiScoutShortfallACU]..'; aiBrain[refiCurIntelLineTarget]='..aiBrain[refiCurIntelLineTarget]..'; size of intel paths='..table.getn(aiBrain[reftIntelLinePositions])) end

                            for iSubPath, tSubPathPosition in aiBrain[reftIntelLinePositions][iCurIntelLineTarget] do
                                iIncreaseInSubpath = 0
                                iMaxIncreaseInSubpath = 0

                                --Determine max subpath that can use based on neighbours:
                                if bDebugMessages == true then LOG(sFunctionRef..': Determining subpath modification from base to apply for iSubPath='..iSubPath) end
                                if aiBrain[reftiSubpathModFromBase] == nil then aiBrain[reftiSubpathModFromBase] = {} end
                                if aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget] == nil then aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget] = {} end
                                if aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath] == nil then aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath] = 0 end
                                if aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath - 1] == nil then aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath-1] = 0 end
                                if aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath + 1] == nil then aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath+1] = 0 end

                                if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget]='..repr(aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget])) end
                                --Get for -1 subpath:
                                if iSubPath > 1 then iMaxIncreaseInSubpath = aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath - 1] + 1 end
                                --Get for +1 subpath if it exists
                                if iSubPath < aiBrain[reftScoutsNeededPerPathPosition][iCurIntelLineTarget] then
                                    if aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath + 1] then
                                        iNextMaxIncrease = aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath + 1] + 1
                                    else iNextMaxIncrease = 1
                                    end
                                end
                                if iNextMaxIncrease > iMaxIncreaseInSubpath then iMaxIncreaseInSubpath = iNextMaxIncrease end
                                if bDebugMessages == true then LOG(sFunctionRef..': iSubPath='..iSubPath..'; iMaxIncreaseInSubpath ='..iMaxIncreaseInSubpath) end

                                tNearbyEnemiesBase = aiBrain:GetUnitsAroundPoint(categories.MOBILE + M27UnitInfo.refCategoryStructure, tSubPathPosition, iIntelPathEnemySearchRange, 'Enemy')
                                if M27Utilities.IsTableEmpty(tNearbyEnemiesBase) == true then
                                    tSubPathPlus1 = aiBrain[reftIntelLinePositions][iCurIntelLineTarget + 1][iSubPath]
                                    if M27Utilities.IsTableEmpty(tSubPathPlus1) == false then
                                        tNearbyEnemiesPlus1 = aiBrain:GetUnitsAroundPoint(categories.MOBILE + M27UnitInfo.refCategoryStructure, tSubPathPlus1, iIntelPathEnemySearchRange, 'Enemy')
                                        if M27Utilities.IsTableEmpty(tNearbyEnemiesPlus1) == true then
                                            iIncreaseInSubpath = 1
                                            tSubPathPlus2 = aiBrain[reftIntelLinePositions][iCurIntelLineTarget + 2][iSubPath]
                                            if M27Utilities.IsTableEmpty(tSubPathPlus2) == false then
                                                tNearbyEnemiesPlus2 = aiBrain:GetUnitsAroundPoint(categories.MOBILE + M27UnitInfo.refCategoryStructure, tSubPathPlus2, iIntelPathEnemySearchRange, 'Enemy')
                                                if M27Utilities.IsTableEmpty(tNearbyEnemiesPlus2) == true then
                                                    iIncreaseInSubpath = 2
                                                end
                                            end
                                        end
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[refiScoutShortfallACU='..aiBrain[refiScoutShortfallACU]..'; iSubPath='..iSubPath..'; iMaxIncreaseInSubpath ='..iMaxIncreaseInSubpath..'; iIncrease wnated before applying max='..iIncreaseInSubpath) end
                                if iIncreaseInSubpath > iMaxIncreaseInSubpath then iIncreaseInSubpath = iMaxIncreaseInSubpath end
                                local tCurPathPos
                                tCurPathPos = aiBrain[reftIntelLinePositions][iCurIntelLineTarget + iIncreaseInSubpath][iSubPath]
                                while M27Utilities.IsTableEmpty(tCurPathPos) == true do
                                    if bDebugMessages == true then LOG(sFunctionRef..': iSubPath='..iSubPath..'; iIncreaseInSubpath='..iIncreaseInSubpath..'; position given by this is invalid, so decreasing by 1') end
                                    iIncreaseInSubpath = iIncreaseInSubpath - 1
                                    if iIncreaseInSubpath <= 0 then break end
                                    tCurPathPos = aiBrain[reftIntelLinePositions][iCurIntelLineTarget + iIncreaseInSubpath][iSubPath]
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': iSubPath='..iSubPath..'; tCurPathPos='..repr(tCurPathPos)) end

                                aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath] = iIncreaseInSubpath
                            end
                        end


                        --Create intel platoons if needed (choosing scouts nearest to the start point of the intel path for simplicity)
                        local tBasePathPosition = aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]][1]
                        local iNewIntelPlatoonsNeeded = iScoutsWanted - iIntelPlatoons
                        if iNewIntelPlatoonsNeeded > iAvailableScouts then iNewIntelPlatoonsNeeded = iAvailableScouts end
                        local oNewScoutPlatoon
                        local iCount = 0
                        while iNewIntelPlatoonsNeeded > 0 do
                            iCount = iCount + 1 if iCount > 100 then M27Utilities.ErrorHandler('Infinite loop') break end
                            oScoutToGive = GetNearestMAAOrScout(aiBrain, tBasePathPosition, true, true, true)
                            if oScoutToGive then
                                local oNewScoutPlatoon = aiBrain:MakePlatoon('', '')
                                if oScoutToGive.PlatoonHandle and aiBrain:PlatoonExists(oScoutToGive.PlatoonHandle) then
                                    M27PlatoonUtilities.RemoveUnitsFromPlatoon(oScoutToGive.PlatoonHandle, {oScoutToGive}, false, oNewScoutPlatoon)
                                else
                                    --Redundancy in case there's a scenario where you dont have a platoon handle for a scout
                                    aiBrain:AssignUnitsToPlatoon(oNewScoutPlatoon, {oScoutToGive}, 'Attack', 'GrowthFormation')
                                end
                                oNewScoutPlatoon:SetAIPlan('M27IntelPathAI')
                                iIntelPlatoons = iIntelPlatoons + 1
                                tIntelPlatoons[iIntelPlatoons] = oNewScoutPlatoon
                                if bDebugMessages == true then
                                    local iPlatoonCount = oNewScoutPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                    if iPlatoonCount == nil then iPlatoonCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27IntelPathAI']
                                        if iPlatoonCount == nil then iPlatoonCount = 1
                                        else iPlatoonCount = iPlatoonCount + 1 end
                                    end
                                    LOG(sFunctionRef..': aiBrain[refiScoutShortfallACU]='..aiBrain[refiScoutShortfallACU]..'; Created new platoon with Plan name and count='..oNewScoutPlatoon:GetPlan()..iPlatoonCount)
                                end
                            else
                                --Any remaining scouts must still be being constructed
                                break
                            end

                            iNewIntelPlatoonsNeeded = iNewIntelPlatoonsNeeded - 1

                        end
                        --Sort platoons by distance, and check if their current path target is different from what we want
                        --SortTableBySubtable(tTableToSort, sSortByRef, bLowToHigh)
                        local iDistFromCurPath
                        local iMinDistFromCurPath
                        local oClosestPlatoon
                        local iClosestPlatoon
                        local tCurPathPos
                        local iSubpathMod
                        if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[refiScoutShortfallACU]='..aiBrain[refiScoutShortfallACU]..'; About to loop subpaths in current target') end
                        if iIntelPlatoons >= 1 then
                            for iCurSubpath = 1, table.getn(aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]]) do
                                iMinDistFromCurPath = 100000
                                oClosestPlatoon = nil
                                iClosestPlatoon = 0
                                iSubpathMod = aiBrain[reftiSubpathModFromBase][aiBrain[refiCurIntelLineTarget]][iCurSubpath]
                                if iSubpathMod == nil then iSubpathMod = 0 end --e.g. if not got enough scouts for a full path wont have set subpath mods yet
                                tCurPathPos = aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget] + iSubpathMod][iCurSubpath]
                                if M27Utilities.IsTableEmpty(tCurPathPos) == true then
                                    M27Utilities.ErrorHandler('tCurPathPos is empty for iCurSubpath='..iCurSubpath..'; iIntelLineTarget='..aiBrain[refiCurIntelLineTarget]..'; iSubpathMod='..iSubpathMod)
                                else
                                    if bDebugMessages == true then
                                       LOG(sFunctionRef..': iCurSubpath='..iCurSubpath..'; iSubpathMod = '..iSubpathMod..': tCurPathPos='..repr(tCurPathPos))
                                        M27Utilities.DrawLocation(tCurPathPos)
                                    end
                                    for iPlatoon, oPlatoon in tIntelPlatoons do
                                        if bDebugMessages == true then
                                            local iPlatoonCount = oPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                            if iPlatoonCount == nil then iPlatoonCount = 'nil' end
                                            LOG(sFunctionRef..': Cycling through all platoons in tIntelPlatoons, iPlatoon='..iPlatoon..'; oPlatoon count='..iPlatoonCount) end
                                        iDistFromCurPath = M27Utilities.GetDistanceBetweenPositions(M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), tCurPathPos)
                                        if bDebugMessages == true then LOG(sFunctionRef..': iDistFromCurPath='..iDistFromCurPath) end
                                        if iDistFromCurPath < iMinDistFromCurPath then
                                            iMinDistFromCurPath = iDistFromCurPath
                                            oClosestPlatoon = oPlatoon
                                            iClosestPlatoon = iPlatoon
                                        end
                                    end
                                    if oClosestPlatoon == nil then break
                                    else
                                        table.remove(tIntelPlatoons, iClosestPlatoon)
                                        if oClosestPlatoon[M27PlatoonUtilities.reftMovementPath] == nil then
                                            oClosestPlatoon[M27PlatoonUtilities.reftMovementPath] = {}
                                            oClosestPlatoon[M27PlatoonUtilities.reftMovementPath][1] = {}
                                        end
                                        if not(oClosestPlatoon[M27PlatoonUtilities.reftMovementPath][1][1] == tCurPathPos[1] and oClosestPlatoon[M27PlatoonUtilities.reftMovementPath][1][3] == tCurPathPos[3]) then
                                            if bDebugMessages == true and oClosestPlatoon.GetPlan then LOG(sFunctionRef..': Giving override action to oClosestPlatoon '..oClosestPlatoon:GetPlan()..(oClosestPlatoon[M27PlatoonUtilities.refiPlatoonCount] or 'nil')..': tCurPathPosition='..repr(tCurPathPos)..'; movement path='..repr((oClosestPlatoon[M27PlatoonUtilities.reftMovementPath][1] or {'nil'}))..' unless its prev action was to run; platoon prevaction='..(oClosestPlatoon[M27PlatoonUtilities.reftPrevAction][1] or 'nil')) end
                                            if not(oClosestPlatoon[M27PlatoonUtilities.reftPrevAction][1] == M27PlatoonUtilities.refActionRun) and not(oClosestPlatoon[M27PlatoonUtilities.reftPrevAction][1] == M27PlatoonUtilities.refActionTemporaryRetreat) and not(oClosestPlatoon[M27PlatoonUtilities.reftPrevAction][1] == M27PlatoonUtilities.refActionReturnToBase) then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Prev action wasnt to run so updating movement path, will force a refresh of this if we havent given an override in last 5s; oClosestPlatoon[M27PlatoonUtilities.refiLastPrevActionOverride]='..(oClosestPlatoon[M27PlatoonUtilities.refiLastPrevActionOverride] or 'nil')) end
                                                if oClosestPlatoon[M27PlatoonUtilities.refiLastPrevActionOverride] >= 5 and M27Utilities.GetDistanceBetweenPositions(((oClosestPlatoon[M27PlatoonUtilities.reftMovementPath] or {0,0,0})[(oClosestPlatoon[M27PlatoonUtilities.refiCurrentPathTarget] or 1)] or {0,0,0}), tCurPathPos) > 10 then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Forcing a refresh of the platoon') end
                                                    M27PlatoonUtilities.ForceActionRefresh(oClosestPlatoon)
                                                    oClosestPlatoon[M27PlatoonUtilities.reftMovementPath] = {}
                                                    oClosestPlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionReissueMovementPath
                                                end
                                                oClosestPlatoon[M27PlatoonUtilities.reftMovementPath][1] = tCurPathPos
                                            end
                                        end
                                        iIntelPlatoons = iIntelPlatoons - 1
                                    end
                                end
                            end
                        end

                        --If we have too many scouts then remove excess ones (unless we had to fall back because we didn't have enough)
                        if not(tIntelPlatoons == nil) and iIntelPlatoons > 0 then
                            local iRemainingScouts = table.getn(tIntelPlatoons)
                            if iRemainingScouts >= 2 then
                                local iSpareScoutsWanted
                                local iMaxScoutsWanted = iScoutsWanted
                                local iFirstPathToCheck = math.max(1, aiBrain[refiCurIntelLineTarget] - 2)
                                local iLastPathToCheck = math.min(table.getn(aiBrain[reftIntelLinePositions]), aiBrain[refiCurIntelLineTarget] + 2)
                                local iCurScoutsWanted
                                --Cycle through previous and next intel paths to see if they need more scouts than current path
                                if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[refiScoutShortfallACU]='..aiBrain[refiScoutShortfallACU]..'; About to loop through previous and next intel paths') end
                                for iCurPathToCheck = iFirstPathToCheck, iLastPathToCheck do
                                    iCurScoutsWanted = table.getn(aiBrain[reftIntelLinePositions][iCurPathToCheck])
                                    if iCurScoutsWanted > iMaxScoutsWanted then iMaxScoutsWanted = iCurScoutsWanted end
                                end
                                iSpareScoutsWanted = iMaxScoutsWanted - iScoutsWanted
                                if iSpareScoutsWanted < iRemainingScouts then
                                    --Have too many scouts - remove spare ones
                                    local iScoutsToRemove = iRemainingScouts - iSpareScoutsWanted

                                    for iCurRemoval = 1, iScoutsToRemove do
                                        tIntelPlatoons[iCurRemoval][M27PlatoonUtilities.refiCurrentAction] = M27PlatoonUtilities.refActionDisband
                                        tIntelPlatoons[iCurRemoval][M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionDisband
                                        tIntelPlatoons[iCurRemoval][M27PlatoonUtilities.refbOverseerAction] = true
                                    end
                                end


                            end
                        end
                    end
                end
            end


            if aiBrain[refiScoutShortfallIntelLine] > 0 then
                if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[refiScoutShortfallACU]='..aiBrain[refiScoutShortfallACU]..'; Have a shortfall of scouts for intel line='..aiBrain[refiScoutShortfallIntelLine]) end
                --Defaults for other scouts wanted - just set to 1 for simplicity

                aiBrain[refiScoutShortfallLargePlatoons] = 1
                aiBrain[refiScoutShortfallAllPlatoons] = 1
                aiBrain[refiScoutShortfallMexes] = 0
                aiBrain[refbNeedScoutPlatoons] = true
            else
                if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[refiScoutShortfallACU]='..aiBrain[refiScoutShortfallACU]..'; Dont have a shortfall of scouts for intel line so will consider large platoons') end
                aiBrain[refbNeedScoutPlatoons] = false

                --=================Large platoons - ensure they have scouts available, and if not then add scout to them

                local iLargePlatoonsMissingScouts = 0
                local iSmallPlatoonMissingScouts = 0

                local tPlatoonUnits, iPlatoonUnits, tPlatoonCurrentScouts, oScoutToAdd, oScoutOldPlatoon
                local iPlatoonSizeMin, iPlatoonSizeMissingScouts
                if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == true or (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] and sScoutPathing == M27UnitInfo.refPathingTypeAmphibious) then
                    for iPlatoonCurSize = 1, 2 do
                        if iPlatoonCurSize == 1 then
                            iPlatoonSizeMin = iScoutLargePlatoonThreshold
                        else
                            iPlatoonSizeMin = iSmallPlatoonMinSizeForScout
                        end
                        iPlatoonSizeMissingScouts = 0

                        for iCurPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
                            if not(oPlatoon[M27PlatoonTemplates.refbIdlePlatoon]) then
                                tPlatoonUnits = oPlatoon:GetPlatoonUnits()
                                if M27Utilities.IsTableEmpty(tPlatoonUnits) == false then
                                    iPlatoonUnits = table.getn(tPlatoonUnits)
                                    if iPlatoonUnits >= iPlatoonSizeMin and aiBrain:PlatoonExists(oPlatoon) then
                                        local bPlatoonHasScouts = false
                                        tPlatoonCurrentScouts = EntityCategoryFilterDown(refCategoryLandScout, tPlatoonUnits)
                                        if M27Utilities.IsTableEmpty(tPlatoonCurrentScouts) == false then bPlatoonHasScouts = true
                                        elseif oPlatoon[refoScoutHelper] and oPlatoon[refoScoutHelper].GetPlatoonUnits then
                                            tPlatoonCurrentScouts = oPlatoon[refoScoutHelper]:GetPlatoonUnits()
                                            if M27Utilities.IsTableEmpty(tPlatoonCurrentScouts) == false then bPlatoonHasScouts = true end
                                        end
                                        if bPlatoonHasScouts == false then
                                            --Need scouts in the platoon
                                            if iPlatoonSizeMissingScouts > 0 or iAvailableScouts <= 0 then
                                                --Wont find any more scouts, so just increase
                                                iPlatoonSizeMissingScouts = iPlatoonSizeMissingScouts + 1
                                            else
                                                if bDebugMessages == true then LOG(sFunctionRef..': About to get a scout to assign to a large platoon.  Large platoon count='..oPlatoon[M27PlatoonUtilities.refiPlatoonCount]) end
                                                oScoutToAdd = GetNearestMAAOrScout(aiBrain, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), true, true, true)
                                                if oScoutToAdd == nil then
                                                    iPlatoonSizeMissingScouts = iPlatoonSizeMissingScouts + 1
                                                else
                                                    iAvailableScouts = iAvailableScouts - 1

                                                    AssignHelperToPlatoonOrUnit(oScoutToAdd, oPlatoon, true)
                                                    --[[--Have a valid scout - add it to the platoon
                                                    oScoutOldPlatoon = oScoutToAdd.PlatoonHandle
                                                    if oScoutOldPlatoon then
                                                        --RemoveUnitsFromPlatoon(oPlatoon, tUnits, bReturnToBase, oPlatoonToAddTo)
                                                        M27PlatoonUtilities.RemoveUnitsFromPlatoon(oScoutOldPlatoon, { oScoutToAdd}, false, oPlatoon)
                                                    else
                                                        --Dont have platoon for the scout so add manually (backup for unexpected scenarios)
                                                        aiBrain:AssignUnitsToPlatoon(oPlatoon, { oScoutToAdd}, 'Unassigned', 'None')
                                                    end--]]
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if iPlatoonCurSize == 1 then
                            iLargePlatoonsMissingScouts = iPlatoonSizeMissingScouts
                        else iSmallPlatoonMissingScouts = iPlatoonSizeMissingScouts end
                    end
                end
                aiBrain[refiScoutShortfallLargePlatoons] = iLargePlatoonsMissingScouts
                aiBrain[refiScoutShortfallAllPlatoons] = iSmallPlatoonMissingScouts
                if iLargePlatoonsMissingScouts + iSmallPlatoonMissingScouts > 0 then
                    aiBrain[refiScoutShortfallMexes] = 1
                else
--========MEXES (non-urgent)
                    --Assign scouts to every mex on our side of the map that is land pathable to our start
                    --local iStartPathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    --local sLocationRef
                    local oCurScout
                    local iScoutShortfall = 0
                    local bNoMoreScouts = false
                    --Get positions of any omni sensors (as we dont need a scout if we have omni coverage)
                    local tFriendlyOmni = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT3Radar, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 1000, 'Ally')
                    local bConsiderOmni = not(M27Utilities.IsTableEmpty(tFriendlyOmni))
                    local bCurPositionInOmniRange
                    local iCurOmniRange
                    local iDistanceWithinOmniWanted = 30
                    local oCurBlueprint
                    local sLocationRef

                    if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftMexesToKeepScoutsBy]) == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': have some mexes in the table of mexes that want scouts (tablegetn wont work for this variable)') end
                        for iMex, tMex in aiBrain[M27MapInfo.reftMexesToKeepScoutsBy] do
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering tMex='..repr(tMex)..'; iMex='..iMex) end
                            if M27Utilities.GetDistanceBetweenPositions(tMex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) > 40 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Mex is at least 40 away from start') end
                                sLocationRef = iMex --M27Utilities.ConvertLocationToReference(tMex)
                                --Do we have a scout assigned that is still alive?
                                oCurScout = aiBrain[tScoutAssignedToMexLocation][sLocationRef]
                                if oCurScout and not(oCurScout.Dead) and oCurScout.GetUnitId then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Already have a scout assigned to the mex') end
                                    --Do nothing
                                else
                                    aiBrain[tScoutAssignedToMexLocation][sLocationRef] = nil
                                    --Do we have omni coverage?
                                    bCurPositionInOmniRange = false
                                    if bConsiderOmni then
                                        for iOmni, oOmni in tFriendlyOmni do
                                            iCurOmniRange = 0
                                            if oOmni.GetBlueprint and not(oOmni.Dead) and oOmni.GetFractionComplete and oOmni:GetFractionComplete() == 1 then
                                                oCurBlueprint = oOmni:GetBlueprint()
                                                if oCurBlueprint.Intel and oCurBlueprint.Intel.OmniRadius then iCurOmniRange = oCurBlueprint.Intel.OmniRadius end
                                            end
                                            if iCurOmniRange > 0 then
                                                 if M27Utilities.GetDistanceBetweenPositions(oOmni:GetPosition(), tMex) - iCurOmniRange <= iDistanceWithinOmniWanted then bCurPositionInOmniRange = true break end
                                            end
                                        end
                                    end
                                    if not(bCurPositionInOmniRange) then
                                        --Try to find a scout to assign
                                        if bNoMoreScouts == false then oCurScout = GetNearestMAAOrScout(aiBrain, tMex, true, true, true)
                                        else oCurScout = nil end
                                        if oCurScout then
                                            aiBrain[tScoutAssignedToMexLocation][sLocationRef] = oCurScout
                                            local iAngleToEnemyBase = M27Utilities.GetAngleFromAToB(tMex, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                                            local tPositionToGuard = M27Utilities.MoveInDirection(tMex, iAngleToEnemyBase, 6) --dont want to block mex or storage, and want to get slight advance warning of enemies
                                            AssignHelperToLocation(aiBrain, oCurScout, tPositionToGuard)
                                        else
                                            bNoMoreScouts = true
                                            iScoutShortfall = iScoutShortfall + 1
                                        end
                                    end
                                end
                            elseif bDebugMessages == true then LOG(sFunctionRef..': Mex is within 40 of start so dont want a scout')
                            end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': No mexes that want scouts by') end
                    end
                    aiBrain[refiScoutShortfallMexes] = iScoutShortfall
                end
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': No scouts so will set as needing more scouts for ACU and initial raider') end
            aiBrain[refiScoutShortfallInitialRaider] = aiBrain[refiInitialRaiderPlatoonsWanted]
            aiBrain[refiScoutShortfallACU] = 1
            aiBrain[refiScoutShortfallPriority] = 1
            aiBrain[refiScoutShortfallIntelLine] = aiBrain[refiMinScoutsNeededForAnyPath]
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..':End of code, gametime='..GetGameTimeSeconds()..'; aiBrain[refiScoutShortfallACU]='..aiBrain[refiScoutShortfallACU]..'; aiBrain[refiScoutShortfallInitialRaider]='..aiBrain[refiScoutShortfallInitialRaider]..'; aiBrain[refiScoutShortfallIntelLine]='..aiBrain[refiScoutShortfallIntelLine]) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end


function RemoveSpareNonCombatUnits(oPlatoon)

    --Removes surplus scouts/MAA from oPlatoon
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RemoveSpareTypeOfUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tAllUnits = oPlatoon:GetPlatoonUnits()
    local tCombatUnits = EntityCategoryFilterDown(categories.DIRECTFIRE + categories.INDIRECTFIRE - categories.SCOUT - categories.ANTIAIR, tAllUnits)
    local tScouts = EntityCategoryFilterDown(categories.SCOUT, tAllUnits)
    local tMAA = EntityCategoryFilterDown(categories.ANTIAIR, tAllUnits)
    local iCombatUnits = 0
    if not(tCombatUnits == nil) then iCombatUnits = table.getn(tCombatUnits) end
    local iScouts = 0
    if not(tScouts==nil) then iScouts = table.getn(tScouts) end
    local iMAA = 0
    if not(tMAA==nil) then iMAA = table.getn(tMAA) end
    local iMaxScouts = 1 + math.min(iCombatUnits / 16)
    local iMaxMAA = 1 + math.min(iCombatUnits / 6)
    if bDebugMessages == true then LOG(sFunctionRef..': iMaxScouts='..iMaxScouts..'; iScouts='..iScouts..'; oPlatoon count='..oPlatoon[M27PlatoonUtilities.refiPlatoonCount]) end

    local iMaxType, tUnitsOfType, iUnitsOfType
    for iType = 1, 2 do
        if iType == 1 then iMaxType = iMaxScouts iUnitsOfType = iScouts tUnitsOfType = tScouts
        else iMaxType = iMaxMAA iUnitsOfType = iMAA tUnitsOfType = tMAA end
        if bDebugMessages == true then LOG('start of removal cycle, iType='..iType..'; iMaxType='..iMaxType..'; iUnitsOfType='..iUnitsOfType) end
        if iMaxType < iUnitsOfType then
            --Remove the scout that's furthest away, and repeat until no scouts
            local iMaxDistToPlatoon
            local tPlatoonPos = M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)
            local iCurDistToPlatoon
            local iFurthestUnit
            for iRemovalCount = 1, iUnitsOfType - iMaxType do
                iMaxDistToPlatoon = 0
                for iCurUnit, oCurUnit in tUnitsOfType do
                    if not(oCurUnit.Dead or oCurUnit:BeenDestroyed()) then
                        iCurDistToPlatoon = M27Utilities.GetDistanceBetweenPositions(oCurUnit:GetPosition(), tPlatoonPos)
                        if iCurDistToPlatoon > iMaxDistToPlatoon then
                            iMaxDistToPlatoon = iCurDistToPlatoon
                            iFurthestUnit = iCurUnit
                        end
                    end
                end
                iUnitsOfType = iUnitsOfType - 1
                M27PlatoonUtilities.RemoveUnitsFromPlatoon(oPlatoon, {tUnitsOfType[iFurthestUnit]}, false)
                table.remove(tUnitsOfType, iFurthestUnit)
                if bDebugMessages == true then LOG(sFunctionRef..': Removed unit type '..iType..' from the platoon. iMaxUnitsOfType='..iMaxType..'; iUnitsOfType='..iUnitsOfType) end
                if iMaxType >= iUnitsOfType then break end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ResetEnemyThreatGroups(aiBrain, iSearchRange, tCategoriesToSearch)
    --[[ Background:
        Overseer code will have assigned [iArmyIndex][refsThreatGroup] for each visible enemy unit, grouped the units into threat groups, and recorded the threat groups in aiBrain[reftEnemyThreatGroup].
        Friendly platoons will then have been sent to intercept the nearest threat group, and will ahve recorded that threat group's reference
        when enemy units are combined into a threat group, any recent platoon group references should be checked, and then any aiBrain defender platoons targetting those enemy groups should have their references updated
    This Reset function therefore sets the current target to nil, and updates the previous target reference - updates both enemy unit references, and own platoon target references
    ]]
    local sFunctionRef = 'ResetEnemyThreatGroups'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iThreatGroupMemory = 30
    local iArmyIndex = aiBrain:GetArmyIndex()
    aiBrain[reftEnemyThreatGroup] = {}
    --Reset platoon and aiBrain details:
    --local oPlatoons = aiBrain:GetPlatoonsList()
    --if not(oPlatoons==nil) then
        for iCurPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
            if oPlatoon[refstPrevEnemyThreatGroup] == nil then oPlatoon[refstPrevEnemyThreatGroup] = {} end
            table.insert(oPlatoon[refstPrevEnemyThreatGroup], 1, oPlatoon[refsEnemyThreatGroup])
            if table.getn(oPlatoon[refstPrevEnemyThreatGroup]) > 10 then table.remove(oPlatoon[refstPrevEnemyThreatGroup], 11) end
            oPlatoon[refsEnemyThreatGroup] = nil
        end
    --end
    local sOldRef
    local iAllRelevantCategories = tCategoriesToSearch[1]
    for iEntry, iCategory in tCategoriesToSearch do
        if iEntry > 1 then
            iAllRelevantCategories = iAllRelevantCategories + iCategory
        end
    end

    for iCurEnemy, oEnemyUnit in aiBrain:GetUnitsAroundPoint(iAllRelevantCategories, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iSearchRange, 'Enemy') do
        if oEnemyUnit[iArmyIndex] == nil then oEnemyUnit[iArmyIndex] = {} end
        sOldRef = oEnemyUnit[iArmyIndex][refsEnemyThreatGroup]
        if sOldRef == nil then oEnemyUnit[iArmyIndex][refsEnemyThreatGroup] = {} end
        if oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup] == nil then oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup] = {} end
        table.insert(oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup], 1, sOldRef)
        if table.getn(oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup]) > iThreatGroupMemory then table.remove(oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup], iThreatGroupMemory + 1) end
        oEnemyUnit[iArmyIndex][refsEnemyThreatGroup] = nil
        oEnemyUnit[iArmyIndex][refbUnitAlreadyConsidered] = nil
        if oEnemyUnit[iArmyIndex][refiAssignedThreat] == nil then oEnemyUnit[iArmyIndex][refiAssignedThreat] = 0 end --Used for torp bombers; not reset since torp bombers are assigned once
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function AddNearbyUnitsToThreatGroup(aiBrain, oEnemyUnit, sThreatGroup, iRadius, iCategory, bMustBeOnLand, bMustBeOnWater, iNavalBlipThreat, bNotFirstTime)
    --Adds oEnemyUnit to sThreatGroup and calls this function on itself again for any units within iRadius that are visible
    --also updates previous threat group references so they know to refer to this threat group
    --if iRadius is 0 then will only add oEnemyUnit to the threat group
    --Add oEnemyUnit to sThreatGroup:
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AddNearbyUnitsToThreatGroup'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iArmyIndex = aiBrain:GetArmyIndex()
    --Only call this if haven't already called this on a unit:
    if oEnemyUnit[iArmyIndex] == nil then oEnemyUnit[iArmyIndex] = {} end
    if oEnemyUnit[iArmyIndex][refbUnitAlreadyConsidered] == nil then
        if bDebugMessages == true then LOG(sFunctionRef..': sThreatGroup='..sThreatGroup..': oEnemyUnit='..oEnemyUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oEnemyUnit)) end

        local bNewUnitIsOnRightTerrain
        local bIsOnWater
        local tCurPosition

        if bMustBeOnLand == nil then
            bMustBeOnLand = true
            if bMustBeOnWater == nil then bMustBeOnLand = false end
        end
        if bMustBeOnWater == nil then bMustBeOnWater = false end

        --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride, bIncludeAirTorpedo)
        local iCurThreat
        if bMustBeOnWater == true then
            iCurThreat = M27Logic.GetAirThreatLevel(aiBrain, { oEnemyUnit }, true, false, true, false, false, 50, 20, iNavalBlipThreat, iNavalBlipThreat, false)
            oEnemyUnit[iArmyIndex][refiUnitNavalAAThreat] = iCurThreat
            if bDebugMessages == true then LOG(sFunctionRef..': bMustBeOnWater is true; Unit='..oEnemyUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oEnemyUnit)..': iCurThreat='..iCurThreat) end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': refbUnitAlreadyConsidered is false, recording unit.  sThreatGroup='..sThreatGroup) end
        oEnemyUnit[iArmyIndex][refsEnemyThreatGroup] = sThreatGroup
        oEnemyUnit[iArmyIndex][refbUnitAlreadyConsidered] = true

        if aiBrain[reftEnemyThreatGroup][sThreatGroup] == nil then
            aiBrain[reftEnemyThreatGroup][sThreatGroup] = {}
            --aiBrain[reftEnemyThreatGroup][sThreatGroup][refsEnemyGroupName] = sThreatGroup
            aiBrain[reftEnemyThreatGroup][sThreatGroup][refoEnemyGroupUnits] = {}
            aiBrain[reftEnemyThreatGroup][sThreatGroup][refiEnemyThreatGroupUnitCount] = 0
            aiBrain[reftEnemyThreatGroup][sThreatGroup][refiThreatGroupHighestTech] = 1
        elseif aiBrain[reftEnemyThreatGroup][sThreatGroup][refoEnemyGroupUnits] == nil then
            aiBrain[reftEnemyThreatGroup][sThreatGroup][refoEnemyGroupUnits] = {}
            aiBrain[reftEnemyThreatGroup][sThreatGroup][refiEnemyThreatGroupUnitCount] = 0
        end
        if bMustBeOnWater == true then
            if aiBrain[reftEnemyThreatGroup][sThreatGroup][refiTotalThreat] == nil then aiBrain[reftEnemyThreatGroup][sThreatGroup][refiTotalThreat] = 0 end
            aiBrain[reftEnemyThreatGroup][sThreatGroup][refiTotalThreat] = aiBrain[reftEnemyThreatGroup][sThreatGroup][refiTotalThreat] + iCurThreat
        end

        table.insert(aiBrain[reftEnemyThreatGroup][sThreatGroup][refoEnemyGroupUnits], oEnemyUnit)
        aiBrain[reftEnemyThreatGroup][sThreatGroup][refiEnemyThreatGroupUnitCount] = aiBrain[reftEnemyThreatGroup][sThreatGroup][refiEnemyThreatGroupUnitCount] + 1
        aiBrain[reftEnemyThreatGroup][sThreatGroup][refiThreatGroupCategory] = iCategory
        local sBP = oEnemyUnit:GetUnitId()
        local iTechLevel = 1
        if EntityCategoryContains(categories.TECH2, sBP) then iTechLevel = 2
        elseif EntityCategoryContains(categories.TECH3, sBP) then iTechLevel = 3
        elseif EntityCategoryContains(categories.EXPERIMENTAL, sBP) then iTechLevel = 4
        end
        if iTechLevel > aiBrain[reftEnemyThreatGroup][sThreatGroup][refiThreatGroupHighestTech] then aiBrain[reftEnemyThreatGroup][sThreatGroup][refiThreatGroupHighestTech] = iTechLevel end
        if iTechLevel > aiBrain[refiEnemyHighestTechLevel] then aiBrain[refiEnemyHighestTechLevel] = iTechLevel end

        if bDebugMessages == true then LOG(sFunctionRef..': Added '..sThreatGroup..' to aiBrain. refiEnemyThreatGroupUnitCount='..aiBrain[reftEnemyThreatGroup][sThreatGroup][refiEnemyThreatGroupUnitCount]..'; iTechLevel='..iTechLevel..'; bMustBeOnWater='..tostring(bMustBeOnWater)..'; Unit ref='..sBP..M27UnitInfo.GetUnitLifetimeCount(oEnemyUnit)) end

        --Record details of old enemy threat group references, and the new threat group that they now belong to
        if not(oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup] == nil) then
            local sOldRef
            for iPrevRef, sRef in oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup] do
                if not(sRef == nil) then
                    sOldRef = sRef break
                end
            end
            if not(sOldRef == nil) then aiBrain[reftUnitGroupPreviousReferences][sOldRef] = sThreatGroup end
        end

        --look for nearby units: v15 - removed the recursive part of the logic to see if improves CPU performance
        if not(bNotFirstTime) then
            if iRadius and iRadius > 0 then
                tCurPosition = oEnemyUnit:GetPosition()
                local tNearbyUnits = aiBrain:GetUnitsAroundPoint(iCategory, tCurPosition, iRadius, 'Enemy')
                for iUnit, oUnit in tNearbyUnits do
                    bNewUnitIsOnRightTerrain = true
                    if bMustBeOnLand or bMustBeOnWater then
                        if GetTerrainHeight(tCurPosition[1], tCurPosition[3]) < M27MapInfo.iMapWaterHeight then bIsOnWater = true else bIsOnWater = false end
                        if bIsOnWater == true and bMustBeOnLand == true then bNewUnitIsOnRightTerrain = false
                        elseif bIsOnWater == false and bMustBeOnWater == true then bNewUnitIsOnRightTerrain = false
                        end
                    end

                    if bNewUnitIsOnRightTerrain and M27Utilities.CanSeeUnit(aiBrain, oUnit, true) == true then AddNearbyUnitsToThreatGroup(aiBrain, oUnit, sThreatGroup, iRadius, iCategory, bMustBeOnLand, bMustBeOnWater, iNavalBlipThreat, true) end
                end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code; threat group threat='..(aiBrain[reftEnemyThreatGroup][sThreatGroup][refiTotalThreat] or 'nil')) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdatePreviousPlatoonThreatReferences(aiBrain, tEnemyThreatGroup)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdatePreviousPlatoonThreatReferences'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local sPlatoonCurTarget
    for iPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
        if bDebugMessages == true then LOG(sFunctionRef..': iPlatoon='..iPlatoon) end
        sPlatoonCurTarget = oPlatoon[refsEnemyThreatGroup]
        if sPlatoonCurTarget == nil then
            if bDebugMessages == true then LOG(sFunctionRef..': iPlatoon='..iPlatoon..'; sPlatoonCurTarget is nil, checking previous references') end
            if not(oPlatoon[refstPrevEnemyThreatGroup] == nil) then
                if bDebugMessages == true then LOG(sFunctionRef..': iPlatoon='..iPlatoon..'; refstPrevEnemyThreatGroup size='..table.getn(oPlatoon[refstPrevEnemyThreatGroup])) end
                for iPrevRef, sPrevRef in oPlatoon[refstPrevEnemyThreatGroup] do
                    if not(sPrevRef == nil) then
                        if bDebugMessages == true then LOG(sFunctionRef..': iPlatoon='..iPlatoon..'; Have located a previous reference, sPrevRef='..sPrevRef) end
                        --Have located a previous ref - check if we have a new reference for this:
                        oPlatoon[refsEnemyThreatGroup] = aiBrain[reftUnitGroupPreviousReferences][sPrevRef]
                        break
                    end
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': iPlatoon='..iPlatoon..'; refstPrevEnemyThreatGroup is nil') end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RemoveSpareUnits(oPlatoon, iThreatNeeded, iMinScouts, iMinMAA, oPlatoonToAddTo, bIgnoreIfNearbyEnemies)
    --Remove any units not needed for iThreatNeeded, on assumption remaining units will be merged into oPlatoonToAddTo (so will remove units furthest from that platoon)
    --bIgnoreIfNearbyEnemies (default is yes) is true then won't remove units if have nearby enemies (based on the localised platoon enemy detection)
    --if oPlatoon is army pool then wont remove any of the units

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RemoveSpareUnits'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iCurUnitThreat = 0
    local iRemainingThreatNeeded = iThreatNeeded
    local bRemoveRemainingUnits = false
    local iScoutsWanted = iMinScouts
    local iMAAWanted = iMinMAA
    local bRemoveCurUnit = false
    local iRetainedThreat = oPlatoon[refiTotalThreat]
    if iRetainedThreat == nil then iRetainedThreat = 0 end
    if oPlatoon and oPlatoon.GetBrain then
        local aiBrain = oPlatoon:GetBrain()
        local oArmyPool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
        if bDebugMessages == true then LOG(sFunctionRef..': Start pre removal, size of platoon='..table.getn(oPlatoon:GetPlatoonUnits())) end
        if oPlatoon == oArmyPool then
            M27Utilities.ErrorHandler('Are trying to remove units from the army pool - ignoring')
        else
            if bIgnoreIfNearbyEnemies == nil then bIgnoreIfNearbyEnemies = true end
            --Do we have any nearby enemies?
            if bDebugMessages == true then
                local sEnemiesInRange = oPlatoon[M27PlatoonUtilities.refiEnemiesInRange]
                if sEnemiesInRange == nil then sEnemiesInRange = 'Unknown' end
                LOG(sFunctionRef..': EnemiesInRange='..sEnemiesInRange)
            end
            if bIgnoreIfNearbyEnemies == false or not(oPlatoon[M27PlatoonUtilities.refiEnemiesInRange] > 0 or oPlatoon[M27PlatoonUtilities.refiEnemyStructuresInRange] > 0) then
                --local iSearchRange = M27Logic.GetUnitMaxGroundRange(oPlatoon[M27PlatoonUtilities.reftCurrentUnits]) * 1.4
                --if iSearchRange < 40 then iSearchRange = 40 end

                local tTargetMergePoint

                local bUseArmyPool = false
                if oPlatoonToAddTo == nil then
                    if bDebugMessages == true then LOG(sFunctionRef..': Are making use of army pool') end
                    bUseArmyPool = true
                else
                    local iPlatoonToAddToUnits = oPlatoonToAddTo[M27PlatoonUtilities.refiCurrentUnits]
                    if iPlatoonToAddToUnits and iPlatoonToAddToUnits > 0 then
                        local tPlatoonUnits = oPlatoonToAddTo:GetPlatoonUnits()
                        if M27Utilities.IsTableEmpty(tPlatoonUnits) == true then
                            if bDebugMessages == true then LOG(sFunctionRef..': will be making use of army pool') end
                            bUseArmyPool = true end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': so will use army pool') end
                        bUseArmyPool = true
                    end
                end
                if bUseArmyPool == true then
                    oPlatoonToAddTo = oArmyPool
                    tTargetMergePoint = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                else
                    tTargetMergePoint = oPlatoonToAddTo:GetPlatoonPosition()
                end

                if tTargetMergePoint == nil then
                    local sPlan = 'None'
                    if oPlatoonToAddTo and oPlatoonToAddTo.GetPlan then sPlan = oPlatoonToAddTo:GetPlan() end
                    LOG(sFunctionRef..': '..sPlan..': Warning - PlatoonPosition is nil, attempting custom getaverageposition if platoon has any units')
                    if oPlatoonToAddTo.GetPlatoonUnits then
                        local tNewPlatoonUnits = oPlatoonToAddTo:GetPlatoonUnits()
                        if M27Utilities.IsTableEmpty(tNewPlatoonUnits) == false then
                            LOG(sFunctionRef..': '..sPlan..': About to get average position')
                            tTargetMergePoint = GetAveragePosition(tNewPlatoonUnits)
                        else
                            LOG(sFunctionRef..': tNewPlatoonUnits is empty, so platoon doesnt have any units in it')
                        end
                    end
                    if tTargetMergePoint == nil then
                        M27Utilities.ErrorHandler('tTargetMergePoint is nil; will replace with player start position')
                        if oPlatoonToAddTo and oPlatoonToAddTo.GetPlan then LOG(sFunctionRef..': Platoon to add to='..oPlatoonToAddTo:GetPlan()) end
                        if oPlatoonToAddTo[M27PlatoonUtilities.refiPlatoonCount] then LOG(sFunctionRef..': PlatoonCount='..oPlatoonToAddTo[M27PlatoonUtilities.refiPlatoonCount]) end
                        if oPlatoonToAddTo == aiBrain:GetPlatoonUniquelyNamed('ArmyPool') then LOG(sFunctionRef..' Trying to merge into Armypool - maybe ArmyPool doesnt work for get platoon position')  end
                        if not(oPlatoonToAddTo) then LOG(sFunctionRef..': oPlatoonToAddTo is nil') end
                        tTargetMergePoint = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                    else
                        LOG(sFunctionRef..': Warning - oPlatoonToAddTo:GetPlatoonPosition returned nil value, but GetAveragePosition gave a value; if this triggers lots then investigate further why')
                    end
                end
                --First remove spare scouts (duplicates later call in overseer to help reduce cases where get into constant cycle of removing scout, falling below threat threshold, re-adding scout to go above, then removing again)
                RemoveSpareNonCombatUnits(oPlatoon)
                local tUnits = oPlatoon:GetPlatoonUnits()
                local tUnitPos = {}
                if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through units in platoon to remove spare ones; size of tUnits='..table.getn(tUnits)) end
                if M27Utilities.IsTableEmpty(tUnits) == false then
                    for iCurUnit, oUnit in tUnits do
                        if oUnit == M27Utilities.GetACU(aiBrain) then
                            if bDebugMessages == true then LOG(sFunctionRef..': oPlatoon includes ACU') end
                        end
                        tUnitPos = oUnit:GetPosition()
                        if not(tUnitPos == nil) then
                            oUnit[refiActualDistanceFromEnemy] = M27Utilities.GetDistanceBetweenPositions(tTargetMergePoint, oUnit:GetPosition())
                            else
                            M27Utilities.ErrorHandler('tUnitPos is nil; iCurUnit='..iCurUnit..'; oPlatoon plan+count='..oPlatoon:GetPlan()..oPlatoon[M27PlatoonUtilities.refiPlatoonCount])
                            oUnit[refiActualDistanceFromEnemy] = 10000 end
                    end
                    for iCurUnit, oUnit in M27Utilities.SortTableBySubtable(tUnits, refiActualDistanceFromEnemy, true) do
                        if bDebugMessages == true then LOG(sFunctionRef..': iCurUnit='..iCurUnit..'; checking if unit is valid') end
                        --GetCombatThreatRating(aiBrain, tUnits, bUseBlip, iMassValueOfBlipsOverride)
                        if oUnit.GetUnitId and not(oUnit.Dead) and not(oUnit:BeenDestroyed()) then
                            if bDebugMessages == true then LOG(sFunctionRef..': iCurUnit='..iCurUnit..'; Distance from platoon='..oUnit[refiActualDistanceFromEnemy]) end
                            if bRemoveRemainingUnits == false then
                                iCurUnitThreat = M27Logic.GetCombatThreatRating(oPlatoon:GetBrain(), {oUnit}, false)
                                iRemainingThreatNeeded = iRemainingThreatNeeded - iCurUnitThreat
                                iRetainedThreat = iRetainedThreat + iCurUnitThreat
                                if iRemainingThreatNeeded < 0 then bRemoveRemainingUnits = true end
                                if bDebugMessages == true then LOG(sFunctionRef..': Retaining unit with ID='..oUnit:GetUnitId()..'and iCurUnitThreat='..iCurUnitThreat..'; iRemainingThreatNeeded='..iRemainingThreatNeeded..'; bRemoveRemainingUnits='..tostring(bRemoveRemainingUnits)) end
                            else
                                bRemoveCurUnit = true
                                if iScoutsWanted > 0 then
                                    if EntityCategoryContains(categories.SCOUT, oUnit:GetUnitId()) == true then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Not removing unit as its a scout and we need a scout') end
                                        iScoutsWanted = iScoutsWanted - 1
                                        iRetainedThreat = iRetainedThreat + M27Logic.GetCombatThreatRating(oPlatoon:GetBrain(), {oUnit}, false)
                                        bRemoveCurUnit = false
                                    end
                                end
                                if iMAAWanted > 0 then
                                    if EntityCategoryContains(categories.ANTIAIR, oUnit:GetUnitId()) == true then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Not removing unit as its a MAA and we need a MAA') end
                                        iMAAWanted = iMAAWanted - 1
                                        iRetainedThreat = iRetainedThreat + M27Logic.GetCombatThreatRating(oPlatoon:GetBrain(), {oUnit}, false)
                                        bRemoveCurUnit = false
                                    end
                                end
                                if bRemoveCurUnit == true then M27PlatoonUtilities.RemoveUnitsFromPlatoon(oPlatoon, {oUnit}, false, oPlatoonToAddTo) end
                            end
                        end
                    end
                end
                oPlatoon[refiTotalThreat] = iRetainedThreat
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function TransferPlatoonTrackers(oCopyFromPlatoon, oCopyToPlatoon)
    oCopyToPlatoon[refiTotalThreat] = oCopyFromPlatoon[refiTotalThreat]
    oCopyToPlatoon[reftAveragePosition] = oCopyFromPlatoon[reftAveragePosition]
    oCopyToPlatoon[refiActualDistanceFromEnemy] = oCopyFromPlatoon[refiActualDistanceFromEnemy]
    oCopyToPlatoon[refiDistanceFromOurBase] = oCopyFromPlatoon[refiDistanceFromOurBase]
    oCopyToPlatoon[refiModDistanceFromOurStart] = oCopyFromPlatoon[refiModDistanceFromOurStart]
end

function RecordAvailablePlatoonAndReturnValues(aiBrain, oPlatoon, iAvailableThreat, iCurAvailablePlatoons, tCurPos, iDistFromEnemy, iDistToOurBase, tAvailablePlatoons, tNilDefenderPlatoons, bIndirectThreatOnly)
    --Used by ThreatAssessAndRespond - Split out into this function as used in 2 places so want to make sure any changes are reflected in both
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordAvailablePlatoonAndReturnValues'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local oRecordedPlatoon
    local bIgnore = false
    if oPlatoon == oArmyPoolPlatoon then
        bIgnore = true
    else
        oRecordedPlatoon = oPlatoon
        --if oRecordedPlatoon[M27PlatoonTemplates.refbIdlePlatoon] then bIgnore = true end
    end

    if bIgnore == false and oPlatoon and aiBrain:PlatoonExists(oPlatoon) then
                                                 --GetCombatThreatRating(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, iMassValueOfBlipsOverride, iSoloBlipMassOverride, bIndirectFireThreatOnly)
        oRecordedPlatoon[refiTotalThreat] = M27Logic.GetCombatThreatRating(aiBrain, oRecordedPlatoon:GetPlatoonUnits(), false, nil, nil, bIndirectThreatOnly) --returns 0 rather than nil if no threat/any issue
        if bDebugMessages == true then LOG(sFunctionRef..'; Platoon='..oPlatoon:GetPlan()..': Total threat of platoon='..oRecordedPlatoon[refiTotalThreat]..'; number of units in platoon='..table.getn(oRecordedPlatoon:GetPlatoonUnits())) end
        iAvailableThreat = iAvailableThreat + oRecordedPlatoon[refiTotalThreat]
        iCurAvailablePlatoons = iCurAvailablePlatoons + 1
        tAvailablePlatoons[iCurAvailablePlatoons] = {}
        tAvailablePlatoons[iCurAvailablePlatoons] = oRecordedPlatoon
        --if oRecordedPlatoon == oArmyPoolPlatoon then
            --[[--Create new defenderAI platoon that includes mobile land combat units from oArmyPoolPlatoon
            oRecordedPlatoon[reftAveragePosition] = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
            oRecordedPlatoon[refiActualDistanceFromEnemy] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
            oRecordedPlatoon[refiModDistanceFromOurStart] = 0
            bArmyPoolInAvailablePlatoons = true]]--
        --else
            oRecordedPlatoon[reftAveragePosition] = tCurPos
            oRecordedPlatoon[refiActualDistanceFromEnemy] = iDistFromEnemy
            oRecordedPlatoon[refiDistanceFromOurBase] = iDistToOurBase
            oRecordedPlatoon[refiModDistanceFromOurStart] = GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tCurPos)
            if oRecordedPlatoon[refsEnemyThreatGroup] == nil then
                local iNilPlatoonCount = table.getn(tNilDefenderPlatoons)
                if iNilPlatoonCount == nil then iNilPlatoonCount = 0 end
                tNilDefenderPlatoons[iNilPlatoonCount + 1] = {}
                tNilDefenderPlatoons[iNilPlatoonCount + 1] = oRecordedPlatoon
            end
        --end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iAvailableThreat, iCurAvailablePlatoons
end

function ThreatAssessAndRespond(aiBrain)
    --Identifies enemy threats, and organises platoons which are sent to deal with them
    --NOTE: Doesnt handle naval units
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ThreatAssessAndRespond'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Key config variables:
    --v14 and earlier values:
    --local iLandThreatGroupDistance = 20 --Units this close to each other get included in the same threat group
    --local iNavyThreatGroupDistance = 30
    --v15 values since moving to a simpler (less accurate) threat detection approach
    local iLandThreatGroupDistance = 50
    local iNavyThreatGroupDistance = 80
    local iThreatGroupDistance
    if aiBrain[refiEnemyHighestTechLevel] > 1 then iNavyThreatGroupDistance = 60 end
    local iACUDistanceToConsider = 30 --If enemy within this distance of ACU, and within iACUEnemyDistanceFromBase distance of our base, ACU will consider helping (subject to also helping in emergency situation)
    local iACUEnemyDistanceFromBase = 80
    local iEmergencyExcessEnemyThreatNearBase = 200 --If >this much threat near our base ACU will consider helping from a much further distance away
    local iThreatMaxFactor = 1.5 --i.e. will send up to iThreatMaxFactor * enemy threat to deal with the platoon --v14 was 1.35; v15 changed to 1.5 given change to how threat groups work
    local iNavalThreatMaxFactor = 1.2
    local iThresholdToRemoveSpareUnitsPercent = 1.35 --When cycling through platoons, will reduce the threat wanted by the closest platoon threat; if then come to a platoon that has more threat than remaining balance, spare units get removed.  This % means this only happens if that platoons threat exceeds the remaining threat wanted by this percent
    local iThresholdToRemoveSpareUnitsAbsolute = 120 --Wont remove spare units if only exceed threat wanted by this amount
    --Other variables
    local sPlan
    local sThreatGroup, iCurThreatGroup
    local iGameTime = math.floor(GetGameTimeSeconds())
    local bGetACUHelp, oACU, sACUPlan
    local tACUPos = {}
    local tEnemyDistanceForSorting = {}
    local iArmyIndex = aiBrain:GetArmyIndex()

    local tRallyPoint = {}
    local tCurPos = {}
    local iDistToOurBase
    local tAvailablePlatoons
    local tNilDefenderPlatoons
    local oCombatPlatoonToMergeInto
    local bNoMorePlatoons
    local sPlatoonRef, iPlatoonNumber
    local oCurEnemyUnit, iAvailableThreat, iCurAvailablePlatoons, bPlatoonIsAvailable
    local iDistFromEnemy, iThreatNeeded, iThreatWanted
    local oDefenderPlatoon, oBasePlatoon
    local iMinScouts, iMinMAA, bIsFirstPlatoon
    local bAddedUnitsToPlatoon = false
    local iDistanceToEnemyFromStart = aiBrain[refiDistanceToNearestEnemyBase]
    local iNavySearchRange = math.min(iDistanceToEnemyFromStart, aiBrain[refiModDistFromStartNearestOutstandingThreat] + 120)
    --Do we have air control/immediate air threats? If not, then limit search range to 200
    if not(aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill) and aiBrain[M27AirOverseer.refiAirAANeeded] > 0 then
        iNavySearchRange = math.min(iNavySearchRange, 200)
    end

    local oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')

    local refCategoryMobileLand = categories.LAND * categories.MOBILE

    if bDebugMessages == true then LOG(sFunctionRef..': About to reset enemy threat groups') end
    if bDebugMessages == true then LOG(sFunctionRef..': Getting ACU platoon and action') DebugPrintACUPlatoon(aiBrain) end
    iCurThreatGroup = 0
    local tEnemyUnits
    local iTMDAndShieldSearchRange = 25 --If dealing with T2+ PD will look for nearby shields and TMD
    local iT2ArtiSearchRange = 50 --Will look for nearby T2 arti within this range
    local iNavyUnitCategories = M27UnitInfo.refCategoryNavyThatCanBeTorpedoed
    local tCategoriesToSearch = {refCategoryMobileLand, M27UnitInfo.refCategoryPD}
    if M27MapInfo.bMapHasWater == true then
        tCategoriesToSearch = {refCategoryMobileLand, M27UnitInfo.refCategoryPD, iNavyUnitCategories}
    end
    ResetEnemyThreatGroups(aiBrain, math.max(iNavySearchRange, iLandThreatSearchRange), tCategoriesToSearch)
    local bConsideringNavy
    local bUnitOnWater, tEnemyUnitPos
    local iCurThreat, iSearchRange
    local iCumulativeTorpBomberThreatShortfall = 0
    local bFirstUnassignedNavyThreat = true
    local iNavalBlipThreat = 300 --Frigate

    local bFirstThreatGroup = true
    local tiOurBasePathingGroup = {[M27UnitInfo.refPathingTypeLand] = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]), [M27UnitInfo.refPathingTypeAmphibious] = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])}
    if bDebugMessages == true then LOG(sFunctionRef..': tiOurBasePathingGroup='..repr(tiOurBasePathingGroup)) end
    local sPathingType
    local bCanPathToTarget



    if aiBrain[refiEnemyHighestTechLevel] > 1 then
        iNavalBlipThreat = 2000 --Cruiser
    end
    for iEntry, iCategory in tCategoriesToSearch do
        bConsideringNavy = false
        iSearchRange = iLandThreatSearchRange
        if iCategory == iNavyUnitCategories then
            bConsideringNavy = true
            iSearchRange = iNavySearchRange
        elseif iCategory == M27UnitInfo.refCategoryPD then
            sPathingType = M27UnitInfo.refPathingTypeLand
        else
            if aiBrain[refiOurHighestFactoryTechLevel] >= 2 or aiBrain:GetFactionIndex() == M27UnitInfo.refFactionAeon or aiBrain:GetFactionIndex() == M27UnitInfo.refFactionSeraphim then --shoudl have access to amphibious units
                sPathingType = M27UnitInfo.refPathingTypeAmphibious
            else sPathingType = M27UnitInfo.refPathingTypeLand
            end
        end
        iThreatGroupDistance = iLandThreatGroupDistance
        if bConsideringNavy == true then iThreatGroupDistance = iNavyThreatGroupDistance end

        tEnemyUnits = aiBrain:GetUnitsAroundPoint(iCategory, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iSearchRange, 'Enemy')
        if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
            for iCurEnemy, oEnemyUnit in tEnemyUnits do
                tEnemyUnitPos = oEnemyUnit:GetPosition()
                bUnitOnWater = false
                if GetTerrainHeight(tEnemyUnitPos[1], tEnemyUnitPos[3]) < M27MapInfo.iMapWaterHeight then bUnitOnWater = true end

                --Are we on/not on water?
                if bUnitOnWater == bConsideringNavy then --either on water and considering navy, or not on water and not considering navy
                    --Can we see enemy unit/blip:
                    --function CanSeeUnit(aiBrain, oUnit, bBlipOnly)
                    if bDebugMessages == true then LOG(sFunctionRef..': iCurEnemy='..iCurEnemy..' - about to see if can see the unit and get its threat. Enemy Unit ID='..oEnemyUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oEnemyUnit)..'; Position='..repr(oEnemyUnit:GetPosition())) end
                    if M27Utilities.CanSeeUnit(aiBrain, oEnemyUnit, true) == true then
                        if oEnemyUnit[iArmyIndex] == nil then oEnemyUnit[iArmyIndex] = {} end
                        if oEnemyUnit[iArmyIndex][refsEnemyThreatGroup] == nil then
                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy unit doesnt have a threat group') end
                            --enemy unit hasn't been assigned a threat group - assign it to one now if it's not already got a threat group:
                            if not(oEnemyUnit[iArmyIndex][refbUnitAlreadyConsidered] == true) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Havent already considered the unit; sPathingType='..sPathingType..'; position='..repr(oEnemyUnit:GetPosition())..'; Pathing group='..M27MapInfo.GetSegmentGroupOfLocation(sPathingType, oEnemyUnit:GetPosition())) end
                                --Can we path to the threat group?
                                bCanPathToTarget = false
                                if bConsideringNavy or tiOurBasePathingGroup[sPathingType] == M27MapInfo.GetSegmentGroupOfLocation(sPathingType, oEnemyUnit:GetPosition()) then bCanPathToTarget = true
                                elseif iCategory == M27UnitInfo.refCategoryPD then
                                    --If we travel from the target towards our base and at 45 degree angles (checking 5 points in total) can any of them path there?
                                    local iRangeToCheck = 30 + 2
                                    if aiBrain[refiMinIndirectTechLevel] == 2 then iRangeToCheck = 60 + 2
                                    elseif aiBrain[refiMinIndirectTechLevel] >= 3 then iRangeToCheck = 90 + 2 end
                                    local iBaseAngle = M27Utilities.GetAngleFromAToB(oEnemyUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                    local tPossibleFiringPoint


                                    for iAngleOffset = -90, 90, 45 do
                                        tPossibleFiringPoint = M27Utilities.MoveInDirection(oEnemyUnit:GetPosition(), iBaseAngle + iAngleOffset, iRangeToCheck)
                                        if M27MapInfo.GetSegmentGroupOfLocation(sPathingType, tPossibleFiringPoint) == tiOurBasePathingGroup[sPathingType] then
                                            bCanPathToTarget = true
                                            break
                                        end
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef..': Cant path to tPossibleFiringPoint='..repr(tPossibleFiringPoint))
                                            M27Utilities.DrawLocation(tPossibleFiringPoint)
                                        end
                                    end
                                end
                                if bCanPathToTarget then
                                    iCurThreatGroup = iCurThreatGroup + 1
                                    sThreatGroup = 'M27'..iGameTime..'No'..iCurThreatGroup
                                    oEnemyUnit[iArmyIndex][refsEnemyThreatGroup] = sThreatGroup
                                    if bDebugMessages == true then LOG(sFunctionRef..': iCurEnemy='..iCurEnemy..' - about to add unit to threat group '..sThreatGroup) end
                                    AddNearbyUnitsToThreatGroup(aiBrain, oEnemyUnit, sThreatGroup, iThreatGroupDistance, iCategory, not(bConsideringNavy), bConsideringNavy, iNavalBlipThreat)
                                    --Add nearby structures to threat rating if dealing with structures and enemy has T2+ PD near them
                                    if iCategory == M27UnitInfo.refCategoryPD and oEnemyUnit[iArmyIndex][refsEnemyThreatGroup][refiThreatGroupHighestTech] >= 2 then
                                        local tNearbyDefensiveStructures = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryTMD * categories.STRUCTURE + M27UnitInfo.refCategoryFixedShield, tEnemyUnitPos, iTMDAndShieldSearchRange, 'Enemy')
                                        if M27Utilities.IsTableEmpty(tNearbyDefensiveStructures) == false then
                                            for iDefence, oDefenceUnit in tNearbyDefensiveStructures do
                                                if not(oDefenceUnit.Dead) then
                                                    --AddNearbyUnitsToThreatGroup(aiBrain, oEnemyUnit, sThreatGroup, iRadius, iCategory, bMustBeOnLand, bMustBeOnWater, iNavalBlipThreat, bNotFirstTime)
                                                    AddNearbyUnitsToThreatGroup(aiBrain, oDefenceUnit, sThreatGroup, 0, iCategory)
                                                end
                                            end
                                        end
                                        local tNearbyT2Arti = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti, tEnemyUnitPos, iT2ArtiSearchRange, 'Enemy')
                                        if M27Utilities.IsTableEmpty(tNearbyT2Arti) == false then
                                            for iDefence, oDefenceUnit in tNearbyT2Arti do
                                                if not(oDefenceUnit.Dead) then
                                                    --AddNearbyUnitsToThreatGroup(aiBrain, oEnemyUnit, sThreatGroup, iRadius, iCategory, bMustBeOnLand, bMustBeOnWater, iNavalBlipThreat, bNotFirstTime)
                                                    AddNearbyUnitsToThreatGroup(aiBrain, oDefenceUnit, sThreatGroup, 0, iCategory)
                                                end
                                            end
                                        end
                                    end
                                elseif bDebugMessages == true then LOG(sFunctionRef..': Cant path to enemy unit='..oEnemyUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oEnemyUnit))
                                end
                            elseif bDebugMessages == true then LOG(sFunctionRef..': Unit already has a threat group')
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy unit already has a threat group='..oEnemyUnit[iArmyIndex][refsEnemyThreatGroup]) end
                        end
                    else if bDebugMessages == true then LOG(sFunctionRef..': Cant see the unit') end
                    end
                end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Finished going through enemy units, iCurThreatGroup='..iCurThreatGroup) end

    --Cycle through each threat group, record threat, average position, and distance to our base
    if iCurThreatGroup > 0 then
        --oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
        oACU = M27Utilities.GetACU(aiBrain)
        tACUPos = oACU:GetPosition()
        if bDebugMessages == true then LOG(sFunctionRef..': tACUPos='..repr(tACUPos)) end
        --if bDebugMessages == true then LOG(sFunctionRef..': ACU ID='..oACU:GetUnitId()) end
        for iCurGroup, tEnemyThreatGroup in aiBrain[reftEnemyThreatGroup] do
            UpdatePreviousPlatoonThreatReferences(aiBrain, tEnemyThreatGroup)
            bConsideringNavy = false
            if tEnemyThreatGroup[refiThreatGroupCategory] == iNavyUnitCategories then bConsideringNavy = true end
            --function GetCombatThreatRating(aiBrain, tUnits, bUseBlip, iMassValueOfBlipsOverride)
            if bDebugMessages == true then LOG(sFunctionRef..': Finished updating previous platoon threat references; iCurGroup='..iCurGroup..';  through enemy units, iCurThreatGroup='..iCurThreatGroup..'; bConsideringNavy='..tostring(bConsideringNavy)) end
            if bDebugMessages == true then LOG('Units in tEnemyThreatGroup='..table.getn(tEnemyThreatGroup[refoEnemyGroupUnits])..'; reference of first unit='..tEnemyThreatGroup[refoEnemyGroupUnits][1]:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(tEnemyThreatGroup[refoEnemyGroupUnits][1])) end
            --GetCombatThreatRating(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, iMassValueOfBlipsOverride, iSoloBlipMassOverride, bIndirectFireThreatOnly, bJustGetMassValue)
            if bConsideringNavy == true then
                --Already recorded naval AA threat when added individual units to the threat group
                iCurThreat = tEnemyThreatGroup[refiTotalThreat]
                if bDebugMessages == true then LOG(sFunctionRef..': Considering navy, so will use the enemy threat group total threat already recorded='..(tEnemyThreatGroup[refiTotalThreat] or 0)) end
            else
                iCurThreat = M27Logic.GetCombatThreatRating(aiBrain, tEnemyThreatGroup[refoEnemyGroupUnits], true)
            end

            tEnemyThreatGroup[refiTotalThreat] = math.max(10, iCurThreat)
            tEnemyThreatGroup[reftAveragePosition] = M27Utilities.GetAveragePosition(tEnemyThreatGroup[refoEnemyGroupUnits])
            tEnemyThreatGroup[refiDistanceFromOurBase] = M27Utilities.GetDistanceBetweenPositions(tEnemyThreatGroup[reftAveragePosition], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            tEnemyThreatGroup[refiModDistanceFromOurStart] = GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tEnemyThreatGroup[reftAveragePosition])
            if tEnemyThreatGroup[refiHighestThreatRecorded] == nil or tEnemyThreatGroup[refiHighestThreatRecorded] < tEnemyThreatGroup[refiTotalThreat] then tEnemyThreatGroup[refiHighestThreatRecorded] = tEnemyThreatGroup[refiTotalThreat] end
            if bDebugMessages == true then LOG(sFunctionRef..': iCurGroup='..iCurGroup..'; refiHighestThreatRecorded='..tEnemyThreatGroup[refiHighestThreatRecorded]..'; refiTotalThreat='..tEnemyThreatGroup[refiTotalThreat]) end

            tEnemyDistanceForSorting[iCurGroup] = {}
            tEnemyDistanceForSorting[iCurGroup] = tEnemyThreatGroup[refiModDistanceFromOurStart]
        end

        --Sort threat groups by distance to our base:
        if bDebugMessages == true then LOG(sFunctionRef..': About to sort table of enemy threat groups') end
        if bDebugMessages == true then
            LOG('Threat groups before sorting:')
            for i1, o1 in aiBrain[reftEnemyThreatGroup] do
                LOG('i1='..i1..'; o1.refiModDistanceFromOurStart='..o1[refiModDistanceFromOurStart]..'; threat group threat='..o1[refiTotalThreat]) end
        end

        aiBrain[refbNeedDefenders] = false
        aiBrain[refbNeedIndirect] = false
        aiBrain[refiMinIndirectTechLevel] = 1
        local iTotalEnemyThreatGroups = table.getn(aiBrain[reftEnemyThreatGroup])
        local bPlatoonHasRelevantUnits
        local bIndirectThreatOnly
        local bIgnoreRemainingLandThreats = false

        for iEnemyGroup, tEnemyThreatGroup in M27Utilities.SortTableBySubtable(aiBrain[reftEnemyThreatGroup], refiModDistanceFromOurStart, true) do
            if bFirstThreatGroup then
                bFirstThreatGroup = false
                aiBrain[refiModDistFromStartNearestThreat] = tEnemyThreatGroup[refiModDistanceFromOurStart]
                aiBrain[reftLocationFromStartNearestThreat] = M27Utilities.GetNearestUnit(tEnemyThreatGroup[refoEnemyGroupUnits], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain, nil, nil):GetPosition()
            end
            bIndirectThreatOnly = false
            bConsideringNavy = false
            if tEnemyThreatGroup[refiThreatGroupCategory] == M27UnitInfo.refCategoryPD then bIndirectThreatOnly = true
            elseif tEnemyThreatGroup[refiThreatGroupCategory] == iNavyUnitCategories then bConsideringNavy = true end
            if bConsideringNavy == true or bIgnoreRemainingLandThreats == false then
                if bDebugMessages == true then LOG(sFunctionRef..': Start of cycle through sorted table of each enemy threat group; iEnemyGroup='..iEnemyGroup..'; distance from our base='..tEnemyThreatGroup[refiModDistanceFromOurStart]..'; bIndirectThreatOnly='..tostring(bIndirectThreatOnly)..'; bConsideringNavy='..tostring(bConsideringNavy)) end

                bNoMorePlatoons = false
                --Get total threat of non-committed platoons closer to our base than enemy:
                iAvailableThreat = 0
                iCurAvailablePlatoons = 0
                tAvailablePlatoons = {}
                tNilDefenderPlatoons = {}
                --bArmyPoolInAvailablePlatoons = false

                --Ensure enemy engis will have a unit capable of killing them quickly
                if tEnemyThreatGroup[refiTotalThreat] < 20 then tEnemyThreatGroup[refiTotalThreat] = 20 end
                -- Do we have enough threat available? If not, add ACU if enemy is near
                iThreatNeeded = tEnemyThreatGroup[refiTotalThreat]
                iThreatWanted = tEnemyThreatGroup[refiHighestThreatRecorded] * iThreatMaxFactor
                if bIndirectThreatOnly then

                    iThreatNeeded = math.max(iThreatNeeded * 0.12, math.min(iThreatNeeded * 0.2, 400)) --i.e. 2 MMLs
                    iThreatWanted = iThreatWanted * 0.7 --Structures are given double threat, so really this is saying send up to 140% of the mass value of enemy PD in indirect fire units
                elseif bConsideringNavy == true then
                    iThreatWanted = iThreatNeeded * iNavalThreatMaxFactor
                    iThreatNeeded = iThreatNeeded * 0.75
                end
                if bDebugMessages == true then LOG(sFunctionRef..': iThreatNeeded='..iThreatNeeded..'; iThreatWanted='..iThreatWanted) end

                --Land based threats: send platoons to deal with them
                if bConsideringNavy == false then
                    for iPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
                        if bDebugMessages == true then LOG(sFunctionRef..': iPlatoon='..iPlatoon..'; Platoon unit count='..table.getn(oPlatoon:GetPlatoonUnits())) end
                        if oPlatoon[M27PlatoonTemplates.refbUsedByThreatDefender] == true then
                            --if not(oPlatoon == oArmyPoolPlatoon) then
                                bPlatoonIsAvailable = false
                                sPlan = oPlatoon:GetPlan()
                                iPlatoonNumber = oPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                if iPlatoonNumber == nil then iPlatoonNumber = 0 end
                                sPlatoonRef = sPlan..iPlatoonNumber

                                --If dealing with a structure threat then dont include platoons with DF units; if dealing with a mobile threat dont include platoons with only indirect units
                                bPlatoonHasRelevantUnits = false
                                if bIndirectThreatOnly then
                                    if oPlatoon[M27PlatoonUtilities.refiIndirectUnits] and oPlatoon[M27PlatoonUtilities.refiIndirectUnits] > 0 then bPlatoonHasRelevantUnits = true end
                                    --[[
                                    if sPlan == M27PlatoonTemplates.refoIdleIndirect or sPlan == 'M27IndirectSpareAttacker' then bPlatoonHasRelevantUnits = true
                                    elseif oPlatoon[M27PlatoonUtilities.refiIndirectUnits] and oPlatoon[M27PlatoonUtilities.refiIndirectUnits] > 0 then
                                        bPlatoonHasRelevantUnits = true
                                    end--]]
                                    --Check that have units of the desired tech level
                                    if tEnemyThreatGroup[refiThreatGroupHighestTech] > 1 and bPlatoonHasRelevantUnits == true then
                                        bPlatoonHasRelevantUnits = false
                                        if oPlatoon[M27PlatoonUtilities.refiIndirectUnits] > 0 then
                                            --Check we have at least 1 T2 unit in here
                                            if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryIndirectT2Plus, oPlatoon[M27PlatoonUtilities.reftIndirectUnits])) == false then
                                                bPlatoonHasRelevantUnits = true
                                            end
                                        end
                                    end
                                else
                                    if oPlatoon[M27PlatoonUtilities.refiDFUnits] and oPlatoon[M27PlatoonUtilities.refiDFUnits] > 0 then bPlatoonHasRelevantUnits = true end
                                    --[[if sPlan == M27PlatoonTemplates.refoIdleCombat then bPlatoonHasRelevantUnits = true
                                    elseif oPlatoon[M27PlatoonUtilities.refiDFUnits] and oPlatoon[M27PlatoonUtilities.refiDFUnits] > 0 then bPlatoonHasRelevantUnits = true end--]]
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonRef='..sPlatoonRef..'; finished checking if have relevant units for the threat type, bPlatoonHasRelevantUnits='..tostring(bPlatoonHasRelevantUnits)) end
                                if bPlatoonHasRelevantUnits == true then
                                    --Only include defender platoons that are closer to our base than enemy threat, and which aren't already dealing with a threat
                                    if oPlatoon[M27PlatoonUtilities.refiPlatoonCount] == nil then oPlatoon[M27PlatoonUtilities.refiPlatoonCount] = 0 end
                                    if bDebugMessages == true then LOG(sFunctionRef..': Considering available platoons; iPlatoon='..iPlatoon..'; sPlatoonRef='..sPlatoonRef..'; iEnemyGroup='..iEnemyGroup) end
                                    --if sPlan == sDefenderPlatoonRef or sPlan == 'M27AttackNearestUnits' or sPlan == M27PlatoonTemplates.refoIdleIndirect or sPlan == 'M27IndirectSpareAttacker' or sPlan == 'M27IndirectDefender' or sPlan == 'M27CombatPatrolAI' then
                                        tCurPos = M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)
                                        iDistToOurBase = M27Utilities.GetDistanceBetweenPositions(tCurPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                        if iDistToOurBase <= tEnemyThreatGroup[refiDistanceFromOurBase] then
                                            if oPlatoon[refsEnemyThreatGroup] == nil then
                                                bPlatoonIsAvailable = true
                                                if bDebugMessages == true then LOG(sFunctionRef..': Platoons current target is nil so platoon is available; iPlatoon='..iPlatoon) end
                                            else
                                                if bDebugMessages == true then LOG(sFunctionRef..': iPlatoon='..iPlatoon..'; Is busy targetting '..oPlatoon[refsEnemyThreatGroup]..'; curent threat group considering is: '..iEnemyGroup) end
                                                if sThreatGroup == nil then LOG(repr(aiBrain[reftEnemyThreatGroup])) end
                                                --aiBrain[reftEnemyThreatGroup][sThreatGroup][refsEnemyGroupName] = sThreatGroup
                                                if oPlatoon[refsEnemyThreatGroup] == iEnemyGroup then bPlatoonIsAvailable = true end
                                            end
                                        else
                                            if bDebugMessages == true then LOG(sFunctionRef..': Platoon is too far away to be of help; iPlatoon='..iPlatoon..'; sPlatoonRef='..sPlatoonRef..'; iEnemyGroup='..iEnemyGroup..'; iDistToOurBase='..iDistToOurBase..'; tEnemyThreatGroup[refiDistanceFromOurBase]='..tEnemyThreatGroup[refiDistanceFromOurBase]) end
                                        end
                                    --else
                                        --if bDebugMessages == true then LOG(sFunctionRef..': Platoon plan isnt equal to defender plan. iPlatoon='..iPlatoon..'; sPlatoonRef='..sPlatoonRef..'; iEnemyGroup='..iEnemyGroup) end
                                    --end
                                    if bPlatoonIsAvailable == true then
                                        --Does the platoon have the ACU in it? If so remove it (it can get re-added later if an emergency response is required)
                                        if oPlatoon[M27PlatoonUtilities.refbACUInPlatoon] == true then
                                            if not(oPlatoon[refsEnemyThreatGroup] == iEnemyGroup) then
                                                if bDebugMessages == true then LOG(sFunctionRef..': ACU is in platoon so will only make platoon available for threat response if ACU is targetting the same threat group') end
                                                bPlatoonIsAvailable = false
                                            end
                                        end
                                        if bPlatoonIsAvailable == true then
                                            --Does the platoon have DF units in it but we're targetting structures?
                                            if oPlatoon[M27PlatoonUtilities.refiDFUnits] > 0 and bIndirectThreatOnly then
                                                --RemoveUnitsFromPlatoon(oPlatoon, tUnits, bReturnToBase, oPlatoonToAddTo)
                                                M27PlatoonUtilities.RemoveUnitsFromPlatoon(oPlatoon, oPlatoon[M27PlatoonUtilities.reftDFUnits], false, nil)
                                            end
                                            --Add current platoon details:
                                            iDistFromEnemy = M27Utilities.GetDistanceBetweenPositions(tCurPos, tEnemyThreatGroup[reftAveragePosition])
                                            if bDebugMessages == true then LOG(sFunctionRef..': Platoon is available, will record the threat; iAvailableThreat pre updating='..iAvailableThreat) end
                                            iAvailableThreat, iCurAvailablePlatoons = RecordAvailablePlatoonAndReturnValues(aiBrain, oPlatoon, iAvailableThreat, iCurAvailablePlatoons, tCurPos, iDistFromEnemy, iDistToOurBase, tAvailablePlatoons, tNilDefenderPlatoons, bIndirectThreatOnly)
                                            if bDebugMessages == true then LOG(sFunctionRef..': Platoon is available, have recorded the threat; iAvailableThreat post updating='..iAvailableThreat) end
                                        end
                                    end
                                end
                            --end
                        end
                    end

                    if bDebugMessages == true then LOG(sFunctionRef..': Considering action based on our threat vs enemy; EnemyThreat='..tEnemyThreatGroup[refiTotalThreat]..'; iAvailableThreat='..iAvailableThreat) end

                    if iAvailableThreat < iThreatNeeded and not(bIndirectThreatOnly) and not(bConsideringNavy) then
                        --Check if should add ACU to help fight - is enemy relatively close to ACU, relatively close to our start, and ACU is closer to start than enemy?
                        bGetACUHelp = false
                        iDistFromEnemy = M27Utilities.GetDistanceBetweenPositions(tACUPos, tEnemyThreatGroup[reftAveragePosition])
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering whether should get ACU to help; iDistFromEnemy ='..iDistFromEnemy) end
                        if iDistFromEnemy < iACUDistanceToConsider then
                            if tEnemyThreatGroup[refiDistanceFromOurBase] < iACUEnemyDistanceFromBase then
                                iDistToOurBase = M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                if iDistToOurBase < tEnemyThreatGroup[refiDistanceFromOurBase] then
                                    --are we closer to our base than enemy?
                                    if M27Logic.GetNearestEnemyStartNumber(aiBrain) then
                                        local iDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                                        if iDistToEnemyBase > 0 and iDistToOurBase / iDistToEnemyBase < 0.85 then bGetACUHelp = true end
                                    end
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': bGetACUHelp='..tostring(bGetACUHelp)..'; if this is false then will check if emergency response required') end
                        --Check if emergency response required:
                        if bGetACUHelp == false then
                            if tEnemyThreatGroup[refiDistanceFromOurBase] < iACUEnemyDistanceFromBase then
                                if iThreatNeeded - iAvailableThreat > iEmergencyExcessEnemyThreatNearBase and iThreatNeeded > 0 and iAvailableThreat / iThreatNeeded < 0.85 then
                                    if iDistToOurBase <= iMaxACUEmergencyThreatRange then
                                        bGetACUHelp = true
                                        if bDebugMessages == true then LOG(sFunctionRef..': bGetACUHelp='..tostring(bGetACUHelp)..'; Emergency response is required') end
                                    end
                                end
                            end
                        end


                        --Check ACU isn't upgrading
                        if bGetACUHelp == true then
                            if bDebugMessages == true then LOG(sFunctionRef..': checking if ACU is upgrading') end
                            if oACU:IsUnitState('Upgrading') == true then
                                if bDebugMessages == true then LOG(sFunctionRef..': ACU is upgrading so dont want it to help') end
                                bGetACUHelp = false
                            end
                        end
                        --Check ACU hasn't finished its gun upgrade (want both for aeon):
                        if bGetACUHelp == true then
                            if M27Conditions.DoesACUHaveGun(aiBrain, true) == true then
                                if bDebugMessages == true then LOG(sFunctionRef..': ACU has gun upgrade so dont want it to help as it should be attacking') end
                                bGetACUHelp = false end
                        end
                        --Check ACU doesnt have nearby enemies
                        if bGetACUHelp == true then
                            if oACU.PlatoonHandle and oACU.PlatoonHandle[M27PlatoonUtilities.refiEnemiesInRange] > 0 then
                                local iEnemySearchRange = math.max(22, M27Logic.GetUnitMaxGroundRange({oACU}))
                                local tEnemiesNearACU = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, oACU:GetPosition(), iEnemySearchRange, 'Enemy')
                                if M27Utilities.IsTableEmpty(tEnemiesNearACU) == false then bGetACUHelp = false end
                            end
                        end

                        oACU[refbACUHelpWanted] = bGetACUHelp
                        -- v15 - decided to instead use the ACUMain platoon logic and just change the movement path as having too many issues with ACU logic getting messed up
                        --[[
                        if bGetACUHelp == true then

                            --Check if ACU not already in a defender platoon:
                            sACUPlan = DebugPrintACUPlatoon(aiBrain, true)
                            if not(sACUPlan == sDefenderPlatoonRef) then
                                --Flag that ACU has been added to defenders if its using the main AI
                                aiBrain[refbACUWasDefending] = true
                                --Add ACU to defenders


                                if bDebugMessages == true then LOG(sFunctionRef..': Getting ACU threat rating before adding to defenders; iAvailableThreat before adding ACU='..iAvailableThreat) end
                                local oACUPlatoon = oACU.PlatoonHandle
                                if oACUPlatoon == nil then
                                    if bDebugMessages == true then LOG(sFunctionRef..': oACUs platoon handle is nil, creating new plan for ACU') end
                                    oACUPlatoon = aiBrain:MakePlatoon('', '')
                                    aiBrain:AssignUnitsToPlatoon(oACUPlatoon, {oACU},'Attack', 'None')
                                    oACUPlatoon:SetAIPlan(sDefenderPlatoonRef)

                                    if bDebugMessages == true then
                                        local iPlatoonCount = oACUPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                        if iPlatoonCount == nil then iPlatoonCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['sDefenderPlatoonRef']
                                            if iPlatoonCount == nil then iPlatoonCount = 1
                                            else iPlatoonCount = iPlatoonCount + 1 end
                                        end
                                        LOG(sFunctionRef..': Created new defender platoon to be used, platoon name+count='..sDefenderPlatoonRef..iPlatoonCount)
                                    end
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': ACU will help so have enough threat; iAvailableThreat before adding ACU='..iAvailableThreat..'; changing ACUs plan to use defender plan') end
                                    oACU.PlatoonHandle:SetAIPlan(sDefenderPlatoonRef)
                                end
                                iAvailableThreat, iCurAvailablePlatoons = RecordAvailablePlatoonAndReturnValues(aiBrain, oACU.PlatoonHandle, iAvailableThreat, iCurAvailablePlatoons, tACUPos, iDistFromEnemy, iDistToOurBase, tAvailablePlatoons, tNilDefenderPlatoons, bIndirectThreatOnly)
                                if bDebugMessages == true then LOG(sFunctionRef..': iAvailableThreat after adding ACU to available platoons='..iAvailableThreat) end
                                --iAvailableThreat = iAvailableThreat + M27Logic.GetCombatThreatRating(aiBrain, {oACU}, false)

                            end
                        end --]]
                        if bDebugMessages == true then LOG(sFunctionRef..': Finished considering if ACU should help; bGetACUHelp='..tostring(bGetACUHelp)) end
                    else
                        --Threat higher than needed, so flag that don't need ACU help
                        oACU[refbACUHelpWanted] = false
                    end

                    if bDebugMessages == true then LOG(sFunctionRef..': Finished identifying all platoons/units that can help deal with the threat, now will decide on what action to take; iAvailableThreat='..iAvailableThreat..'; iThreatNeeded='..iThreatNeeded) end
                    --Now that have all available units, decide on action based on enemy threat
                    --First update trackers - want to base on whether we have all the units we want to respond to the threat (rather than whether we have just enough units to attack)
                    if iAvailableThreat < iThreatWanted then
                        local iCurModDistToEnemyBase = GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tEnemyThreatGroup[reftAveragePosition], true)
                        --M27Utilities.GetDistanceBetweenPositions(tEnemyThreatGroup[reftAveragePosition], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                        aiBrain[refiModDistFromStartNearestOutstandingThreat] = tEnemyThreatGroup[refiModDistanceFromOurStart]
                        aiBrain[refiPercentageOutstandingThreat] = tEnemyThreatGroup[refiModDistanceFromOurStart] / (tEnemyThreatGroup[refiModDistanceFromOurStart] + iCurModDistToEnemyBase)
                        aiBrain[refiMinIndirectTechLevel] = 1 --default
                        if bIndirectThreatOnly then
                            aiBrain[refbNeedIndirect] = true
                            aiBrain[refbNeedDefenders] = false
                            if tEnemyThreatGroup[refiThreatGroupHighestTech] >= 2 then aiBrain[refiMinIndirectTechLevel] = math.min(tEnemyThreatGroup[refiThreatGroupHighestTech], 3) end
                        else
                            aiBrain[refbNeedDefenders] = true --will assign more units to defender platoon
                            aiBrain[refbNeedIndirect] = false
                        end
                    else
                        if iEnemyGroup >= iTotalEnemyThreatGroups then
                            --is the furthest away enemy threat group and we can beat it, so we have full defensive coverage; will set to 90% to avoid trying to e.g. get mexes in the enemy base itself
                            aiBrain[refiPercentageOutstandingThreat] = 0.9
                            aiBrain[refiModDistFromStartNearestOutstandingThreat] = aiBrain[refiDistanceToNearestEnemyBase]
                        end
                    end

                    --Now decide whether we will attack with the platoon, based on whether we have the minimum threat needed
                    if iAvailableThreat < iThreatNeeded and bGetACUHelp == false then

                        --Dont have enough units yet, so get units in position so when have enough can respond
                        --Go to midpoint, or if enemy too close then to base
                        if bDebugMessages == true then LOG(sFunctionRef..': Dont have enough threat to deal with enemy - iAvailableThreat='..iAvailableThreat..'; iThreatNeeded='..iThreatNeeded..'; set refbNeedDefenders to true; getting rally point for any available platoons to retreat to') end
                        --if bDebugMessages == true then LOG(sFunctionRef..': ACU state='..M27Logic.GetUnitState(M27Utilities.GetACU(aiBrain))) end
                        tRallyPoint = {}
                        if tEnemyThreatGroup[refiDistanceFromOurBase] > 60 then
                            tRallyPoint[1] = (tEnemyThreatGroup[reftAveragePosition][1] + M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1]) / 2
                            tRallyPoint[3] = (tEnemyThreatGroup[reftAveragePosition][3] + M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]) / 2
                            tRallyPoint[2] = GetTerrainHeight(tRallyPoint[1], tRallyPoint[3])
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy is clsoe to our base, so rally point is our base') end
                            tRallyPoint = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber] end
                        for iPlatoon, oPlatoon in tAvailablePlatoons do
                            oPlatoon[refsEnemyThreatGroup] = nil
                            if not(oPlatoon==oArmyPoolPlatoon) then --redundancy/from old code - armypool shouldnt be in availableplatoons any more
                                oPlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionReissueMovementPath
                                if M27Utilities.IsTableEmpty(oPlatoon[M27PlatoonUtilities.reftMovementPath]) == false and M27Utilities.GetDistanceBetweenPositions((oPlatoon[M27PlatoonUtilities.reftMovementPath][(oPlatoon[M27PlatoonUtilities.refiCurrentPathTarget] or 1)] or {0,0,0}), (tRallyPoint or {0,0,0})) > 10 then
                                    M27PlatoonUtilities.ForceActionRefresh(oPlatoon)
                                    oPlatoon[M27PlatoonUtilities.reftMovementPath] = {}
                                elseif M27Utilities.IsTableEmpty(oPlatoon[M27PlatoonUtilities.reftMovementPath]) then oPlatoon[M27PlatoonUtilities.reftMovementPath] = {}
                                end
                                oPlatoon[M27PlatoonUtilities.reftMovementPath][1] = tRallyPoint
                                oPlatoon[M27PlatoonUtilities.refiCurrentPathTarget] = 1
                                --oPlatoon[M27PlatoonUtilities.refiLastPathTarget] = 1
                                oPlatoon[M27PlatoonUtilities.refbOverseerAction] = true
                                --IssueClearCommands(oPlatoon:GetPlatoonUnits())
                                if bDebugMessages == true then
                                    local iPlatoonCount = oPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                    if iPlatoonCount == nil then iPlatoonCount = 'nil' end
                                    LOG(sFunctionRef..': Given override action and Set tMovementPath[1] to tRallyPoint='..tRallyPoint[1]..'-'..tRallyPoint[3]..' and then stop looking at remaining threats; iPlatoon='..iPlatoon..'; PlatoonCount='..iPlatoonCount) end
                            else
                                M27Utilities.ErrorHandler('oPlatoon is army pool')
                                --Armypool platoon - do nothing - shouldve already had combat units added to an available platoon; rely on new platoons being created soon that get sent commands (as if try issuing commands to army pool it can stop platoons being created)
                            end
                        end
                        bIgnoreRemainingLandThreats = true
                    else

                        --Can beat enemy (or for indirect may be able to beat them, or if ACU helping then we have to try to beat them) so attack them - filter to just those platoons that need to deal with the threat if we have more than what is needed:
                        --if iAvailableThreat >= iThreatWanted then
                        --Only need some of the platoon units, pick the ones nearest the enemy
                        --tAvailablePlatoons =
                        --M27Utilities.SortTableBySubtable(tAvailablePlatoons, refiActualDistanceFromEnemy, true)
                        --end
                        iMinScouts = 1 --Want to make sure defender platoon has at least 1 scout if one is available
                        iMinMAA = 1 --as per scouts
                        bIsFirstPlatoon = true
                        --TODO - if run into performance issues could see if it works by setting a new variable equal to the sorted table where need sorting, and not where don't need sorting; however may not work as repeated calls to a variable that uses the sorttables causes errors since sorttables is a function of a table
                        local bNeedBasePlatoon = true
                        bAddedUnitsToPlatoon = false
                        if bDebugMessages == true then LOG(sFunctionRef..': Have enough threat to respond, will now sort platoons to find the nearest one; available platoon size='..table.getn(tAvailablePlatoons)) end
                        local bRefreshPlatoonAction
                        for iPlatoonRef, oAvailablePlatoon in M27Utilities.SortTableBySubtable(tAvailablePlatoons, refiActualDistanceFromEnemy, true) do
                            --for iCurPlatoon = 1, iCurAvailablePlatoons do
                            bRefreshPlatoonAction = false
                            if bDebugMessages == true then LOG(sFunctionRef..': iPlatoonRef='..iPlatoonRef..'; platoon unit count='..table.getn(oAvailablePlatoon:GetPlatoonUnits())) end
                            sPlan = oAvailablePlatoon:GetPlan()
                            iPlatoonNumber = oAvailablePlatoon[M27PlatoonUtilities.refiPlatoonCount]
                            if iPlatoonNumber == nil then iPlatoonNumber = 0 end
                            sPlatoonRef = sPlan..iPlatoonNumber

                            oDefenderPlatoon = oAvailablePlatoon--tAvailablePlatoons[iPlatoonRef]
                            if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonRef='..sPlatoonRef..'; iThreatWanted='..iThreatWanted..'; bNeedBasePlatoon='..tostring(bNeedBasePlatoon)..'; units in platoon='..table.getn(oAvailablePlatoon:GetPlatoonUnits())) end
                            if iThreatWanted <= 0 then
                                --Ensure platoon is available to target other platoons as it's not needed for this one
                                if bDebugMessages == true then LOG(sFunctionRef..': Threat wanted is <= 0 so making platoon available for other threat groups') end
                                oAvailablePlatoon[refsEnemyThreatGroup] = nil
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': bNeedBasePlatoon='..tostring(bNeedBasePlatoon)) end
                                if bNeedBasePlatoon == true then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Need a base platoon, checking if we dont ahve an army pool platoon; bIndirectThreatOnly='..tostring(bIndirectThreatOnly)) end
                                    if not(oBasePlatoon == oArmyPoolPlatoon) then
                                        oBasePlatoon = oAvailablePlatoon
                                        bNeedBasePlatoon = false
                                        if bIndirectThreatOnly then
                                            if not(sPlan == 'M27IndirectDefender') then
                                                if bDebugMessages == true then LOG(sFunctionRef..': sPlan='..sPlan..'; refbIdlePlatoon='..tostring(oBasePlatoon[M27PlatoonTemplates.refbIdlePlatoon])) end
                                                if oBasePlatoon[M27PlatoonTemplates.refbIdlePlatoon] then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Have an idle platoon so will create a new platoon as the base platoon and assign it the cufrrent indirectdefenders units') end
                                                    local tPlatoonUnits = oBasePlatoon:GetPlatoonUnits()
                                                    if M27Utilities.IsTableEmpty(tPlatoonUnits) == false then

                                                        oBasePlatoon = M27PlatoonFormer.CreatePlatoon(aiBrain, 'M27IndirectDefender', tPlatoonUnits)
                                                        if bDebugMessages == true then LOG(sFunctionRef..'oBasePlatoon plan='..oBasePlatoon:GetPlan()..'; iPlatoonRef='..iPlatoonRef..'; size of base platoon units='..table.getn(tPlatoonUnits)) end
                                                        TransferPlatoonTrackers(oAvailablePlatoon, oBasePlatoon)
                                                    else
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Base platoon units is empty') end
                                                        bNeedBasePlatoon = true
                                                    end
                                                else
                                                    oBasePlatoon:SetAIPlan('M27IndirectDefender')
                                                end
                                                oDefenderPlatoon = oBasePlatoon
                                            end
                                            oBasePlatoon[M27PlatoonUtilities.refbShouldHaveEscort] = true
                                        else oBasePlatoon[M27PlatoonUtilities.refbShouldHaveEscort] = false
                                        end
                                    else
                                        M27Utilities.ErrorHandler('The first platoon considered wasnt suitable as a base platoon')
                                    end
                                end

                                if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonRef='..sPlatoonRef..'; Totalthreat group IDd = '..iCurThreatGroup..'; Cur threat group iEnemyGroup='..iEnemyGroup..'iPlatoonRef='..iPlatoonRef..'; iThreatNeeded='..iThreatNeeded..'; iThreatWanted='..iThreatWanted) end
                                if bNeedBasePlatoon == false then
                                    --Check if have at least 1 T1 tank too many (otherwise ignore) - 52 is lowest mass cost of a tank (56 is highest)
                                    if oDefenderPlatoon[refiTotalThreat] == nil then --e.g. army pool will be nil
                                        --GetCombatThreatRating(aiBrain, tUnits, bUseBlip, iMassValueOfBlipsOverride)
                                        oDefenderPlatoon[refiTotalThreat] = M27Logic.GetCombatThreatRating(aiBrain, oDefenderPlatoon:GetPlatoonUnits(), false)
                                    end
                                    if bDebugMessages == true then LOG('sPlatoonRef='..sPlatoonRef..'; oDefenderPlatoon[refiTotalThreat]='..oDefenderPlatoon[refiTotalThreat]..'; Defender platoon units='..table.getn(oDefenderPlatoon:GetPlatoonUnits())) end
                                    if oDefenderPlatoon[refiTotalThreat] - iThreatWanted >= iThresholdToRemoveSpareUnitsAbsolute and oDefenderPlatoon[refiTotalThreat] > (iThreatWanted * iThresholdToRemoveSpareUnitsPercent) then
                                        --Determine the first nil platoon that hasn't been assigned to merge units into:
                                        if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonRef='..sPlatoonRef..'; Dont need all of the platoon, locate the first different nil defender platoon so spare units can be assigned to this; iPlatoonRef='..iPlatoonRef) end
                                        oCombatPlatoonToMergeInto = nil
                                        for iNilPlatoon, oNilPlatoon in tNilDefenderPlatoons do
                                            if oNilPlatoon[refsEnemyThreatGroup] == nil then
                                                if not(oNilPlatoon == oDefenderPlatoon) then oCombatPlatoonToMergeInto = oNilPlatoon break end
                                            end
                                        end
                                        if oCombatPlatoonToMergeInto == nil then
                                            if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonRef='..sPlatoonRef..'; About to merge into the army pool platoon') end
                                            oCombatPlatoonToMergeInto = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
                                        end
                                        if oDefenderPlatoon == oArmyPoolPlatoon then
                                            M27Utilities.ErrorHandler('Defender platoon is army pool')
                                            if bDebugMessages == true then LOG('oDefenderPlatoon is army pool already, so dont want to try and remove') end
                                        else
                                            if bDebugMessages == true then
                                                local iPlatoonCount = oDefenderPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                                if iPlatoonCount == nil then iPlatoonCount = 'nil' end
                                                LOG('sPlatoonRef='..sPlatoonRef..'; oDefenderPlatoon count='..iPlatoonCount) end
                                            if bDebugMessages == true then LOG(sFunctionRef..': Removing spare units from oDefenderPlatoon; iThreatNeeded='..iThreatNeeded..'; oDefenderPlatoon[refiTotalThreat]='..oDefenderPlatoon[refiTotalThreat]..'; size of platoon='..table.getn(oDefenderPlatoon:GetPlatoonUnits())) end
                                            RemoveSpareUnits(oDefenderPlatoon, iThreatWanted, iMinScouts, iMinMAA, oCombatPlatoonToMergeInto, true)
                                            if bDebugMessages == true then LOG(sFunctionRef..': Finished removing spare units from oDefenderPlatoon; Platoon Total threat='..oDefenderPlatoon[refiTotalThreat]..'; size of platoon='..table.getn(oDefenderPlatoon:GetPlatoonUnits())) end
                                            if bIsFirstPlatoon == false then
                                                --function MergePlatoons(oPlatoonToMergeInto, oPlatoonToBeMerged)
                                                if bDebugMessages == true then
                                                    local iPlatoonCount = oBasePlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                                    if iPlatoonCount == nil then iPlatoonCount = 'nil' end
                                                    LOG(sFunctionRef..': About to merge remaining units in defender platoon into base platoon; oBasePlatoon Count='..iPlatoonCount) end
                                                M27PlatoonUtilities.MergePlatoons(oBasePlatoon, oDefenderPlatoon)
                                                bAddedUnitsToPlatoon = true
                                            end
                                        end
                                        iThreatWanted = 0
                                        iThreatNeeded = 0
                                        bIgnoreRemainingLandThreats = true
                                    else
                                        --need all of platoon:
                                        if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonRef='..sPlatoonRef..'; About to adjust threat needed for the threat of the available platoon that have just used; iEnemyThreat='..iEnemyGroup..'; iPlatoonRef='..iPlatoonRef..'; iThreatNeeded='..iThreatNeeded..'; oDefenderPlatoon[refiTotalThreat]='..oDefenderPlatoon[refiTotalThreat]) end
                                        iThreatNeeded = iThreatNeeded - oDefenderPlatoon[refiTotalThreat]
                                        iThreatWanted = iThreatWanted - oDefenderPlatoon[refiTotalThreat]
                                        if iThreatWanted <= 0 then bNoMorePlatoons = true end
                                        if bIsFirstPlatoon == false then
                                            M27PlatoonUtilities.MergePlatoons(oBasePlatoon, oDefenderPlatoon)
                                            bAddedUnitsToPlatoon = true
                                        end
                                    end
                                end
                            end
                            if bIgnoreRemainingLandThreats == false and oBasePlatoon and oBasePlatoon.GetPlatoonUnits then
                                local tBasePlatoonUnits = oBasePlatoon:GetPlatoonUnits()
                                if M27Utilities.IsTableEmpty(tBasePlatoonUnits) == false then
                                    if iMinScouts > 0 then
                                        if not(EntityCategoryFilterDown(categories.SCOUT, tBasePlatoonUnits) == nil) then iMinScouts = 0 end
                                    end
                                    if iMinMAA > 0 then
                                        if not(EntityCategoryFilterDown(categories.ANTIAIR, tBasePlatoonUnits) == nil) then iMinMAA = 0 end
                                    end
                                    if not(oBasePlatoon == oArmyPoolPlatoon) then bIsFirstPlatoon = false end
                                else iMinScouts = 0 iMinMAA = 0 end
                            else iMinScouts = 0 iMinMAA = 0 end
                        end
                        --Base platoon should now be able to beat enemy (or shoudl at least try to if ACU is helping)
                        if bIgnoreRemainingLandThreats == false and oBasePlatoon == nil then
                            if bGetACUHelp == false then M27Utilities.ErrorHandler('oBasePlatoon is nil but had thought could beat the enemy, and ACU isnt part of attack - likely error') end
                        elseif bIgnoreRemainingLandThreats == false then
                            if oBasePlatoon == oArmyPoolPlatoon then
                                M27Utilities.ErrorHandler('WARNING - oArmyPoolPlatoon is oBasePlatoon - will abort threat intereception logic and flag that want defender platoons to be created')
                                if table.getn(tAvailablePlatoons) <= 1 then aiBrain[refbNeedDefenders] = true end
                            else
                                if (oBasePlatoon[refiTotalThreat] or 0) > 0 and M27Utilities.IsTableEmpty(oBasePlatoon:GetPlatoonUnits()) == false then
                                    if oBasePlatoon:GetPlan() == nil then
                                        LOG(sFunctionRef..': ERROR - oBasePlatoons plan is nil, will set to be the defender AI, bIndirectThreatOnly='..tostring(bIndirectThreatOnly))
                                        if bIndirectThreatOnly then
                                            oBasePlatoon:SetAIPlan('M27IndirectDefender')
                                            oBasePlatoon[M27PlatoonUtilities.refbShouldHaveEscort] = true
                                        else oBasePlatoon:SetAIPlan(sDefenderPlatoonRef) end
                                    end
                                    sPlan = oBasePlatoon:GetPlan()
                                    iPlatoonNumber = oBasePlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                    if iPlatoonNumber == nil then iPlatoonNumber = 0 end
                                    sPlatoonRef = sPlan..iPlatoonNumber
                                    oBasePlatoon[reftAveragePosition] = oBasePlatoon:GetPlatoonPosition()
                                    if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonRef='..sPlatoonRef..'; Base platoon av position='..repr(oBasePlatoon[reftAveragePosition])..'; tEnemyThreatGroup[reftAveragePosition]='..repr(tEnemyThreatGroup[reftAveragePosition])) end
                                    oBasePlatoon[refiActualDistanceFromEnemy] = M27Utilities.GetDistanceBetweenPositions(oBasePlatoon[reftAveragePosition], tEnemyThreatGroup[reftAveragePosition])
                                    bRefreshPlatoonAction = true
                                    if bDebugMessages == true then LOG(sFunctionRef..': BasePlatoonRef='..sPlatoonRef..': Considering whether base platoon should have an overseer action override. bAddedUnitsToPlatoon='..tostring(bAddedUnitsToPlatoon)..'; base platoon size='..table.getn(oBasePlatoon:GetPlatoonUnits())) end
                                    --if not(bAddedUnitsToPlatoon) then
                                    local iOverseerRefreshCountThreshold = 4
                                    if oBasePlatoon[M27PlatoonUtilities.refbHoverInPlatoon] then iOverseerRefreshCountThreshold = iOverseerRefreshCountThreshold + 5 end
                                    if bIndirectThreatOnly == true then iOverseerRefreshCountThreshold = 9 end
                                    if M27Utilities.IsTableEmpty(oBasePlatoon[M27PlatoonUtilities.reftPrevAction]) == false then
                                        local iPrevAction = oBasePlatoon[M27PlatoonUtilities.reftPrevAction][1]
                                        if iPrevAction == M27PlatoonUtilities.refActionRun or iPrevAction == M27PlatoonUtilities.refActionTemporaryRetreat or iPrevAction == M27PlatoonUtilities.refActionAttack then
                                            bRefreshPlatoonAction = false
                                        elseif oBasePlatoon[M27PlatoonUtilities.refiLastPrevActionOverride] and oBasePlatoon[M27PlatoonUtilities.refiLastPrevActionOverride] <= iOverseerRefreshCountThreshold then
                                            bRefreshPlatoonAction = false
                                        end
                                        if bDebugMessages == true then LOG(sFunctionRef..': Base platoon has at least 1 previous action, iPrevAction='..iPrevAction..'; bRefreshPlatoonAction='..tostring(bRefreshPlatoonAction)..'; oBasePlatoon[M27PlatoonUtilities.refbOverseerAction]='..tostring(oBasePlatoon[M27PlatoonUtilities.refbOverseerAction])) end
                                    end
                                    --end

                                    if bRefreshPlatoonAction == true then
                                        oBasePlatoon[M27PlatoonUtilities.refbOverseerAction] = true
                                        if bDebugMessages == true then
                                            local iPlatoonCount = oBasePlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                            if iPlatoonCount == nil then iPlatoonCount = 'nil' end
                                            LOG(sFunctionRef..': Given override action to Base platoon sPlatoonRef='..sPlatoonRef..'; About to issue new orders to oBasePlatoon; oBasePlatoon count='..iPlatoonCount..'; oBasePlatoon[refiActualDistanceFromEnemy]='..oBasePlatoon[refiActualDistanceFromEnemy])
                                        end
                                        if oBasePlatoon[refiActualDistanceFromEnemy] <= 30 then
                                            --if bDebugMessages == true then LOG(sFunctionRef..': Base platoon sPlatoonRef='..sPlatoonRef..'; Telling base platoon to have actionattack') end
                                            oBasePlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionAttack
                                            --oBasePlatoon[M27PlatoonUtilities.refiEnemiesInRange] = tEnemyThreatGroup[refiEnemyThreatGroupUnitCount]
                                            --oBasePlatoon[M27PlatoonUtilities.reftEnemiesInRange] = tEnemyThreatGroup[refoEnemyGroupUnits]
                                            if bAddedUnitsToPlatoon == true then M27PlatoonUtilities.ForceActionRefresh(oBasePlatoon) end
                                        else
                                            if bDebugMessages == true then LOG(sFunctionRef..': Base platoon sPlatoonRef='..sPlatoonRef..'; Telling base platoon to refresh its movement path') end
                                            M27PlatoonUtilities.ForceActionRefresh(oBasePlatoon)
                                            oBasePlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionReissueMovementPath
                                        end
                                    end
                                    --IssueClearCommands(oBasePlatoon:GetPlatoonUnits())
                                    oBasePlatoon[M27PlatoonUtilities.reftMovementPath] = {}
                                    oBasePlatoon[M27PlatoonUtilities.reftMovementPath][1] = tEnemyThreatGroup[reftAveragePosition]
                                    if bDebugMessages == true then LOG(sFunctionRef..': Base platoon sPlatoonRef='..sPlatoonRef..'; oBasePlatoon now has movementpath='..repr(oBasePlatoon[M27PlatoonUtilities.reftMovementPath])) end
                                    oBasePlatoon[M27PlatoonUtilities.refiCurrentPathTarget] = 1
                                    --oBasePlatoon[M27PlatoonUtilities.refiLastPathTarget] = 1
                                    oBasePlatoon[refsEnemyThreatGroup] = iEnemyGroup
                                    --Free up any spare scouts and MAA post-platoon merger:
                                    RemoveSpareNonCombatUnits(oBasePlatoon)
                                    --Remove DF units if are attacking a structure
                                    if sPlan == 'M27IndirectDefender' and oBasePlatoon[M27PlatoonUtilities.refiDFUnits] and oBasePlatoon[M27PlatoonUtilities.refiDFUnits] > 0 then M27PlatoonUtilities.RemoveUnitsFromPlatoon(oBasePlatoon, oBasePlatoon[M27PlatoonUtilities.reftDFUnits], nil, nil) end
                                    --Set whether should move in formation or rush towards enemy
                                    local sCurFormation = 'AttackFormation'
                                    if tEnemyThreatGroup[refiDistanceFromOurBase] <= 60 then sCurFormation = 'GrowthFormation'
                                    elseif oBasePlatoon[refiActualDistanceFromEnemy] <= 35 then sCurFormation = 'GrowthFormation'
                                    end
                                    oBasePlatoon:SetPlatoonFormationOverride(sCurFormation)
                                else
                                    if bGetACUHelp == false then M27Utilities.ErrorHandler('oBasePlatoon is nil but had thought could beat the enemy, and ACU isnt part of attack - likely error') end
                                end
                            end
                        end
                        if bGetACUHelp then
                            --Make sure ACU is moving where we want already; if not then tell it to
                            local oACUPlatoon = M27Utilities.GetACU(aiBrain).PlatoonHandle
                            if oACUPlatoon then
                                if M27Utilities.GetDistanceBetweenPositions(oACUPlatoon[M27PlatoonUtilities.reftMovementPath][oACUPlatoon[M27PlatoonUtilities.refiCurrentPathTarget]], tEnemyThreatGroup[reftAveragePosition]) > 10 then
                                    --ACU isnt moving near where we want it to, update its movement path if it doesnt have nearby enemies
                                    if oACUPlatoon[M27PlatoonUtilities.refiEnemiesInRange] == 0 or M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE, M27Utilities.GetACU(aiBrain):GetPosition(), 23, 'Enemy')) == true then --ACU range is 22
                                        oACUPlatoon[M27PlatoonUtilities.reftMovementPath][1] = tEnemyThreatGroup[reftAveragePosition]
                                        oACUPlatoon[M27PlatoonUtilities.refiCurrentPathTarget] = 1
                                        oACUPlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionReissueMovementPath
                                        oACUPlatoon[M27PlatoonUtilities.refbOverseerAction] = true
                                    end
                                end
                            end
                        end
                    end --Available threat vs enemy threat
                else
--NAVAL THREAT RESPONSE
                    --Dealing with navy; Torpedo bombers are only made available if they have current targets; therefore in contrast to land appraoch which always updates, torp bomber response to navy threat is 1-off
                    --However, to make sure we only build torp bombers when we need them, we still need to go through the full process of working out how large a threat we havent dealt with
                    --Alreayd determiend above:
                    --iThreatNeeded = tEnemyThreatGroup[refiTotalThreat]
                    --iThreatWanted = tEnemyThreatGroup[refiHighestThreatRecorded] * iThreatMaxFactor
                    --tEnemyThreatGroup[reftAveragePosition]
                    local tTorpBombersByDistance = {}
                    local iAvailableTorpBombers = 0
                    local refoTorpUnit = 'M27OTorp'
                    local refiCurThreat = 'M27OTorThreat'
                    if bDebugMessages == true then LOG(sFunctionRef..': About to consider if we have any available torp bombers and if so assign them to enemy naval threat') end
                    --tAvailablePlatoons, refiActualDistanceFromEnemy



                    if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableTorpBombers]) == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': Number of available torp bombers='..table.getn(aiBrain[M27AirOverseer.reftAvailableTorpBombers])) end
                        --Determine closest available torpedo bombers (unless we should only target ACU)
                        if aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill and M27UnitInfo.IsUnitUnderwater(aiBrain[refoLastNearestACU]) == true then
                            --Do nothing (logic is in air overseer)
                        else
                            for iUnit, oUnit in aiBrain[M27AirOverseer.reftAvailableTorpBombers] do
                                if not(oUnit.Dead) and not(oUnit[M27AirOverseer.refbOnAssignment]) then
                                    iAvailableTorpBombers = iAvailableTorpBombers + 1
                                    tTorpBombersByDistance[iAvailableTorpBombers] = {}
                                    tTorpBombersByDistance[iAvailableTorpBombers][refoTorpUnit] = oUnit
                                    tTorpBombersByDistance[iAvailableTorpBombers][refiActualDistanceFromEnemy] = M27Utilities.GetDistanceBetweenPositions(tEnemyThreatGroup[reftAveragePosition], oUnit:GetPosition())
                                                                                        --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride, bIncludeAirTorpedo)
                                    tTorpBombersByDistance[iAvailableTorpBombers][refiCurThreat] = M27Logic.GetAirThreatLevel(aiBrain, { oUnit }, false, false, false, false, false, nil, nil, nil, nil, true)
                                    iAvailableThreat = iAvailableThreat + tTorpBombersByDistance[iAvailableTorpBombers][refiCurThreat]
                                end
                            end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': After going through any available torp bombers iAvailableThreat='..iAvailableThreat..'; iThreatNeeded='..iThreatNeeded) end
                    if iAvailableThreat >= iThreatNeeded then
                        for iEntry, tTorpSubtable in M27Utilities.SortTableBySubtable(tTorpBombersByDistance, refiActualDistanceFromEnemy, true) do
                            --Cycle through each enemy unit in the threat group
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering torp bomber '..tTorpSubtable[refoTorpUnit]:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(tTorpSubtable[refoTorpUnit])..'; tTorpSubtable[refiCurThreat]='..(tTorpSubtable[refiCurThreat] or 0)..'; about to cycle through every enemy unit in threat group to see if should attack one of them') end
                            for iUnit, oUnit in tEnemyThreatGroup[refoEnemyGroupUnits] do
                                if bDebugMessages == true then LOG(sFunctionRef..': Enemy Unit='..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iAssignedThreat='..(oUnit[iArmyIndex][refiAssignedThreat] or 0)..'; oUnit[iArmyIndex][refiUnitNavalAAThreat]='..(oUnit[iArmyIndex][refiUnitNavalAAThreat] or 0)..'; iNavalThreatMaxFactor='..iNavalThreatMaxFactor) end
                                if oUnit[iArmyIndex][refiAssignedThreat] <= iNavalThreatMaxFactor * oUnit[iArmyIndex][refiUnitNavalAAThreat] then
                                    oUnit[iArmyIndex][refiAssignedThreat] = oUnit[iArmyIndex][refiAssignedThreat] + tTorpSubtable[refiCurThreat]
                                    IssueClearCommands({tTorpSubtable[refoTorpUnit]})
                                    IssueAttack({tTorpSubtable[refoTorpUnit]}, oUnit)
                                    M27AirOverseer.TrackBomberTarget(tTorpSubtable[refoTorpUnit], oUnit, 1)
                                    for iUnit, oUnit in tEnemyThreatGroup[refoEnemyGroupUnits] do
                                        IssueAttack({tTorpSubtable[refoTorpUnit]}, oUnit)
                                    end
                                    IssueAggressiveMove({tTorpSubtable[refoTorpUnit]}, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                    tTorpSubtable[refoTorpUnit][M27AirOverseer.refbOnAssignment] = true
                                    if bDebugMessages == true then LOG(sFunctionRef..': Clearing torp bomber and then Telling torpedo bomber with ID ref='..tTorpSubtable[refoTorpUnit]:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(tTorpSubtable[refoTorpUnit])..' to attack '..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; GameTime='..GetGameTimeSeconds()) end
                                    break
                                end
                            end
                        end
                    else
                        iCumulativeTorpBomberThreatShortfall = iCumulativeTorpBomberThreatShortfall + iThreatNeeded
                        if bFirstUnassignedNavyThreat == true then
                            bFirstUnassignedNavyThreat = false
                            iCumulativeTorpBomberThreatShortfall = iCumulativeTorpBomberThreatShortfall - iAvailableThreat
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Dont have enough torp bombers; iCumulativeTorpBomberThreatShortfall='..iCumulativeTorpBomberThreatShortfall) end
                    end
                end --Not dealing with navy
            end
        end --for each tEnemyThreatGroup

        if bDebugMessages == true then LOG(sFunctionRef..': Finished cycling through all tEnemyThreatGroups; end of overseer cycle') end
        --if bDebugMessages == true then LOG(sFunctionRef..': End of code - ACU state='..M27Logic.GetUnitState(M27Utilities.GetACU(aiBrain))) end
    else
        if bFirstThreatGroup == true then --Redundancy - dont think we actually need this check as iCurThreatGroup gets increased for threats of any category
            --No threat groups of any kind
            M27Utilities.GetACU(aiBrain)[refbACUHelpWanted] = false
            aiBrain[refiPercentageOutstandingThreat] = 1
            aiBrain[refiModDistFromStartNearestOutstandingThreat] = aiBrain[refiDistanceToNearestEnemyBase]
            aiBrain[refbNeedDefenders] = false
            aiBrain[refbNeedIndirect] = false
            aiBrain[refiModDistFromStartNearestThreat] = 10000
            aiBrain[reftLocationFromStartNearestThreat] = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
        end
    end -->0 enemy threat groups

    --Disband any indirect defenders that havent just been assigned
    if M27Utilities.IsTableEmpty(aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts]) == false then
        local sPlatoonName
        local bAssignedCurrentThreatGroup, iHighestThreatTech, tTech1Units
        for iPlatoon, oPlatoon in aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts] do
            if oPlatoon[M27PlatoonUtilities.refiPlatoonCount] and oPlatoon.GetPlan then
                sPlatoonName = oPlatoon:GetPlan()
                if sPlatoonName == 'M27IndirectDefender' then
                    if aiBrain:PlatoonExists(oPlatoon) then
                        bAssignedCurrentThreatGroup = false
                        sPlatoonRef = sPlatoonName..oPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                        if oPlatoon[refsEnemyThreatGroup] then
                            if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonRef='..sPlatoonRef..'; oPlatoon[refsEnemyThreatGroup]='..oPlatoon[refsEnemyThreatGroup]..'; checking if refsEnemyThreatGroup is in table of threat groups') end
                            if aiBrain[reftEnemyThreatGroup][oPlatoon[refsEnemyThreatGroup]] then
                                bAssignedCurrentThreatGroup = true
                                --Do we have any units below the desired tech level?
                                iHighestThreatTech = aiBrain[reftEnemyThreatGroup][oPlatoon[refsEnemyThreatGroup]][refiThreatGroupHighestTech]
                                if iHighestThreatTech > 1 and oPlatoon[M27PlatoonUtilities.refiCurrentUnits] > 0 then
                                    tTech1Units = EntityCategoryFilterDown(categories.TECH1, oPlatoon[M27PlatoonUtilities.reftCurrentUnits])
                                    if M27Utilities.IsTableEmpty(tTech1Units) == false then
                                        if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonRef..': Have t1 units in platoon but targetting a threat group with T2, so removing them and assigning to the idle indirect platoon instead') end
                                        --RemoveUnitsFromPlatoon(oPlatoon, tUnits, bReturnToBase, oPlatoonToAddTo)
                                        M27PlatoonUtilities.RemoveUnitsFromPlatoon(oPlatoon, tTech1Units, true, aiBrain[M27PlatoonTemplates.refoIdleIndirect])
                                    end
                                end
                            end
                        end
                        if bAssignedCurrentThreatGroup == false then
                            if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonRef..': Dont have a current threat group target so telling platoon to disband') end
                            oPlatoon[M27PlatoonUtilities.refiCurrentAction] = M27PlatoonUtilities.refActionDisband
                        end
                    end
                end
            end
        end
    end

    --Record how many torp bombers we want
    if iCumulativeTorpBomberThreatShortfall > 0 then
        aiBrain[M27AirOverseer.refiTorpBombersWanted] = math.ceil(iCumulativeTorpBomberThreatShortfall / 240)
    else
        aiBrain[M27AirOverseer.refiTorpBombersWanted] = 0
    end

    --if bDebugMessages == true then LOG(sFunctionRef..': End of code, getting ACU debug plan and action') DebugPrintACUPlatoon(aiBrain) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ACUManager(aiBrain)
    --A lot of the below code is a hangover from when the ACU would use the built in AIBuilders and platoons;
    --Almost all the functionality has now been integrated into the M27ACUMain platoon logic, with a few exceptions (such as calling for help), although these could probably be moved over as well
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ACUManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if not(aiBrain.M27IsDefeated) and M27Logic.iTimeOfLastBrainAllDefeated < 10 then
        local oACU = M27Utilities.GetACU(aiBrain)

        --Track ACU health over time
        if not(oACU[reftACURecentHealth]) then oACU[reftACURecentHealth] = {} end
        local iCurShield, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oACU)
        local iCurTime = math.floor(GetGameTimeSeconds())
        oACU[reftACURecentHealth][iCurTime] = oACU:GetHealth() + iCurShield

        if oACU[refbACUOnInitialBuildOrder] == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Start of code - ACU isnt on initial build order') end
            --Config related
            local iBuildDistance = oACU:GetBlueprint().Economy.MaxBuildDistance

            local iDistanceToLookForMexes = iBuildDistance + iACUMaxTravelToNearbyMex --Note The starting build order uses a condition which references whether ACU has mexes this far away, so factor in if changing this
            local iDistanceToLookForReclaim = iBuildDistance + iACUMaxTravelToNearbyMex
            local iMinReclaimValue = 16
            local iRangeForEmergencyEscort = 150
            local iRangeForACUToBeNearBase = 150

            local tACUPos = oACU:GetPosition()



            local oACUPlatoon = oACU.PlatoonHandle
            local sPlatoonName = 'None'
            if oACUPlatoon and oACUPlatoon.GetPlan then sPlatoonName = oACUPlatoon:GetPlan() end
            local oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')

            if oACUPlatoon then
                aiBrain[refiCyclesThatACUHasNoPlatoon] = 0
                if oACUPlatoon == oArmyPoolPlatoon then
                    sPlatoonName = 'ArmyPool'
                    aiBrain[refiCyclesThatACUInArmyPool] = aiBrain[refiCyclesThatACUInArmyPool] + 1
                elseif sPlatoonName == 'M27ACUMain' then
                    --Clear engineer trackers if have an action assigned that doesnt correspond to platoon action
                    if oACU[M27EngineerOverseer.refiEngineerCurrentAction] and oACUPlatoon[M27PlatoonUtilities.refiCurrentAction] then
                        if not(oACU:IsUnitState('Building') or oACU:IsUnitState('Repairing')) then
                            local iCurAction = oACUPlatoon[M27PlatoonUtilities.refiCurrentAction]
                            if not(iCurAction == M27PlatoonUtilities.refActionBuildFactory or iCurAction == M27PlatoonUtilities.refActionBuildInitialPower) then
                                --Have an engineer action assigned but the platoon we're in doesnt, need to clear engineer tracker to free up any guarding units
                                M27EngineerOverseer.ClearEngineerActionTrackers(aiBrain, oACU, true)
                            end
                        end
                    end
                elseif sPlatoonName == sDefenderPlatoonRef then
                    --ACU should only be in defender platoon if there are land enemies near base
                    local tEnemiesNearBase = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iMaxACUEmergencyThreatRange, 'Enemy')
                    if M27Utilities.IsTableEmpty(tEnemiesNearBase) then
                        --Check we're not upgrading
                        if not(oACU:IsUnitState('Upgrading')) then
                            oACU.PlatoonHandle[M27PlatoonUtilities.refiCurrentAction] = M27PlatoonUtilities.refActionDisband
                            local oNewPlatoon = aiBrain:MakePlatoon('','')
                            aiBrain:AssignUnitsToPlatoon(oNewPlatoon, {oACU}, 'Attack', 'None')
                            oNewPlatoon:SetAIPlan('M27ACUMain')
                        end
                    end
                end
            else
                aiBrain[refiCyclesThatACUHasNoPlatoon] = aiBrain[refiCyclesThatACUHasNoPlatoon] + 1
                aiBrain[refiCyclesThatACUInArmyPool] = 0
            end

            --=======ACU Idle override
            local iIdleCount = 0
            local iIdleThreshold = 3
            if M27Logic.IsUnitIdle(oACU, false, true) == true then
                if bDebugMessages == true then LOG(sFunctionRef..': ACU is idle, iIdleCount='..iIdleCount) end
                iIdleCount = iIdleCount + 1
                if iIdleCount > iIdleThreshold then
                    local oNewPlatoon = aiBrain:MakePlatoon('', '')
                    aiBrain:AssignUnitsToPlatoon(oNewPlatoon, {oACU},'Attack', 'None')
                    oNewPlatoon:SetAIPlan('M27ACUMain')
                    if oACUPlatoon and not(oACUPlatoon == oArmyPoolPlatoon) and oACUPlatoon.PlatoonDisband then
                        if bDebugMessages == true then LOG(sFunctionRef..': Disbanding ACU current platoon') end
                        oACUPlatoon:PlatoonDisband()
                    end
                    if bDebugMessages == true then
                        local iPlatoonCount = oNewPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                        if iPlatoonCount == nil then iPlatoonCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27ACUMain']
                            if iPlatoonCount == nil then iPlatoonCount = 1
                            else iPlatoonCount = iPlatoonCount + 1 end
                        end
                        LOG(sFunctionRef..': Changed ACU platoon back to ACU main, platoon name+count='..'M27ACUMain'..iPlatoonCount)
                    end
                end
            else
                iIdleCount = 0
            end

            --==============ACU PLATOON FORM OVERRIDES==========------------
            --Check to try and ensure ACU gets put in a platoon when its gun upgrade has finished (sometimes this doesnt happen)
            if bDebugMessages == true then LOG(sFunctionRef..'oACU[refbACUHelpWanted]='..tostring(oACU[refbACUHelpWanted])) end
            if not(sPlatoonName == 'M27ACUMain') then

                if M27Conditions.DoesACUHaveGun(aiBrain, true) == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': ACU has gun, switching it to the ACUMain platoon if its not using it') end
                    local bReplacePlatoon = true
                    if sPlatoonName == 'M27ACUMain' then
                        if bDebugMessages == true then LOG(sFunctionRef..': ACU is using M27ACUMain already so dont refresh platoon') end
                        bReplacePlatoon = false
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': ACU is using '..sPlatoonName..': Will refresh unless are building') end
                        --Check if are building something
                        local bLetACUFinishBuilding = false
                        if oACU:IsUnitState('Building') == true then
                            local oUnitBeingBuilt = oACU:GetFocusUnit()
                            if oUnitBeingBuilt:GetFractionComplete() <= 0.25 then
                                --Only keep building if is a mex
                                local sBeingBuilt = oUnitBeingBuilt:GetUnitId()
                                if EntityCategoryContains(categories.MASSEXTRACTION, sBeingBuilt) == true then bLetACUFinishBuilding = true end
                            else bLetACUFinishBuilding = true
                            end
                        end

                        if bLetACUFinishBuilding == true then bReplacePlatoon = true end
                    end
                    if bReplacePlatoon == true then
                        if bDebugMessages == true then LOG(sFunctionRef..': ACU is using '..sPlatoonName..': Are creating a new AI for ACU') end
                        local oNewPlatoon = aiBrain:MakePlatoon('', '')
                        aiBrain:AssignUnitsToPlatoon(oNewPlatoon, {oACU},'Attack', 'None')
                        oNewPlatoon:SetAIPlan('M27ACUMain')
                        if bDebugMessages == true then
                            local iPlatoonCount = oNewPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                            if iPlatoonCount == nil then iPlatoonCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27ACUMain']
                                if iPlatoonCount == nil then iPlatoonCount = 1
                                else iPlatoonCount = iPlatoonCount + 1 end
                            end
                            LOG(sFunctionRef..': Changed ACU platoon back to ACU main, platoon name+count='..'M27ACUMain'..iPlatoonCount)
                        end
                    end
                else
                    --NOTE: Rare error where ACU would start upgrade and then cancel straight away - if happens again, expand the code where are disbanding to get upgrade so that it also assigns the command to get the upgrade
                    local bCreateNewPlatoon = false
                    local bDisbandExistingPlatoon = false
                    if oACUPlatoon == nil then
                        if bDebugMessages == true then LOG(sFunctionRef..': ACU has no gun and no platoon') end
                        if aiBrain[refiCyclesThatACUHasNoPlatoon] > 4 then --5 cycles where no platoon, so create a new one unless ACU is busy
                            if GetGameTimeSeconds() > 30 then --at start of game is a wait of longer than 4 seconds before ACU is able to do anything
                                bCreateNewPlatoon = true
                                if bDebugMessages == true then LOG(sFunctionRef..': ACU been in no platoon for '..aiBrain[refiCyclesThatACUHasNoPlatoon]..' cycles so giving it a platoon unless its reclaiming/repairing/upgrading/building') end
                                --Dont create if ACU is doing somethign likely useful
                                if oACU:IsUnitState('Building') == true or oACU:IsUnitState('Reclaiming') == true or oACU:IsUnitState('Repairing') == true or oACU:IsUnitState('Upgrading') == true or oACU:IsUnitState('Guarding') then bCreateNewPlatoon = false end
                            end
                        end
                    else
                        if oACUPlatoon == oArmyPoolPlatoon then
                            if bDebugMessages == true then LOG(sFunctionRef..': ACU has no gun is in army pool, will try and create a new platoon if no help needed from ACU') end
                            if oACU[refbACUHelpWanted] == false then
                                bCreateNewPlatoon = true
                            else
                                if aiBrain[refiCyclesThatACUInArmyPool] > 9 then
                                    if GetGameTimeSeconds() > 30 then
                                        if bDebugMessages == true then LOG(sFunctionRef..': ACU been in army pool for '..aiBrain[refiCyclesThatACUInArmyPool]..' cycles so giving it a platoon unless its reclaiming/repairing/upgrading/building/guarding') end
                                        if oACU:IsUnitState('Building') == true or oACU:IsUnitState('Reclaiming') == true or oACU:IsUnitState('Repairing') == true or oACU:IsUnitState('Upgrading') == true or oACU:IsUnitState('Guarding') then bCreateNewPlatoon = false end
                                        bCreateNewPlatoon = true --Dont want ACU staying in army pool if its still not been used
                                    end
                                end
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': ACU has no gun and is in platoon '..sPlatoonName) end
                            --ACU is in a platoon but its not the army pool; disband if meet the conditions for gun upgrade and ACU not building
                            bDisbandExistingPlatoon = true
                            if oACU:IsUnitState('Building') == true or oACU:IsUnitState('Repairing') == true or oACU:IsUnitState('Upgrading') == true then bDisbandExistingPlatoon = false
                            else
                                bDisbandExistingPlatoon = M27Conditions.WantToGetGunUpgrade(aiBrain)
                            end
                            if bDisbandExistingPlatoon == true then
                                --Check no nearby enemies first
                                bDisbandExistingPlatoon = false
                                if oACUPlatoon[M27PlatoonUtilities.refiEnemiesInRange] == nil or oACUPlatoon[M27PlatoonUtilities.refiEnemiesInRange] == 0 then
                                    local tNearbyEnemyUnits = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.DIRECTFIRE + categories.LAND*categories.INDIRECTFIRE, tACUPos, aiBrain[refiSearchRangeForEnemyStructures], 'Enemy')
                                    if M27Utilities.IsTableEmpty(tNearbyEnemyUnits) == true then
                                        if bDebugMessages == true then LOG(sFunctionRef..': ACU has no nearby enemies so about to disband so it can upgrade to gun, but first checking if it needs to heal') end
                                        --Check not injured and wanting to heal
                                        if not(oACUPlatoon[M27PlatoonUtilities.refbNeedToHeal]==true) then
                                            if bDebugMessages == true then LOG(sFunctionRef..': ACU needs to heal') end
                                            bDisbandExistingPlatoon = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if bDisbandExistingPlatoon == true then
                        if bDebugMessages == true then LOG(sFunctionRef..': ACU ready to get gun so disbanding') end
                        if oACUPlatoon and aiBrain:PlatoonExists(oACUPlatoon) then
                            oACUPlatoon:PlatoonDisband()
                            M27EngineerOverseer.ClearEngineerActionTrackers(aiBrain, oACU, true)
                        end
                    elseif bCreateNewPlatoon == true then
                        local oNewPlatoon = aiBrain:MakePlatoon('', '')
                        aiBrain:AssignUnitsToPlatoon(oNewPlatoon, {oACU},'Support', 'None')
                        oNewPlatoon:SetAIPlan('M27ACUMain')
                        aiBrain[refiCyclesThatACUInArmyPool] = 0
                        aiBrain[refiCyclesThatACUHasNoPlatoon] = 0
                        if bDebugMessages == true then
                            local iPlatoonCount = oNewPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                            if iPlatoonCount == nil then iPlatoonCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27ACUMain']
                                if iPlatoonCount == nil then iPlatoonCount = 1
                                else iPlatoonCount = iPlatoonCount + 1 end
                            end
                            LOG(sFunctionRef..': Changed ACU platoon back to ACU main, platoon name+count='..'M27ACUMain'..iPlatoonCount)
                        end
                    end
                end
            end

            --==============BUILD ORDER RELATED=============
            --Update the build condition flag for if ACU is near an unclaimed mex or has nearby reclaim, unless ACU is part of the main acu platoon ai (which already has this logic in it)
            local sACUPlan = DebugPrintACUPlatoon(aiBrain, true)
            local bPlatoonAlreadyChecks = false
            if sACUPlan == 'M27ACUMain' then
                if not(oACUPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionDisband) then bPlatoonAlreadyChecks = true end
            end
            if bPlatoonAlreadyChecks == false then
                --Check for nearby mexes:
                local sPathing = M27UnitInfo.GetUnitPathingType(oACU)
                --GetSegmentGroupOfTarget(sPathing, iSegmentX, iSegmentZ)
                local iACUSegmentX, iACUSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tACUPos)
                local iSegmentGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iACUSegmentX, iACUSegmentZ)
                local tNearbyUnits = {}
                --M27MapInfo.RecordMexForPathingGroup(oACU) --Makes sure we can reference tMexByPathingAndGrouping
                local iCurDistToACU
                local iBuildingSizeRadius = 0.5
                local bNearbyUnclaimedMex = false
                if bDebugMessages == true then LOG(sFunctionRef..': sPathing='..sPathing..'; iSegmentGroup='..iSegmentGroup..'; No. of mexes in tMexByPathingAndGrouping='..table.getn(M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup])) end
                --tMexByPathingAndGrouping[a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
                local tPossibleMexes = M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup]
                if M27Utilities.IsTableEmpty(tPossibleMexes) == false then
                    for iMex, tMexPosition in M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup] do
                        iCurDistToACU = M27Utilities.GetDistanceBetweenPositions(tMexPosition, tACUPos)
                        --if bDebugMessages == true then LOG(sFunctionRef..': iMex='..iMex..'; iCurDistToACU='..iCurDistToACU..'; iDistanceToLookForMexes='..iDistanceToLookForMexes) end
                        if iCurDistToACU <= iDistanceToLookForMexes then
                            --Check if any building on mex (won't bother with seeing if its an enemy building as AI should be attacking any such building anyway so not worth the effort to code in a 'hold fire and capture' type logic at this stage)
                            --if bDebugMessages == true then LOG(sFunctionRef..'; Mex is within distance to look for, checking if any nearby units') end
                            --IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
                            bNearbyUnclaimedMex = M27Conditions.IsMexUnclaimed(aiBrain, tMexPosition, false, false, false)
                            break
                        end
                    end
                end
                aiBrain[refbUnclaimedMexNearACU] = bNearbyUnclaimedMex
            else
                --Set flags to false as will need refreshing before know if there's still nearby mex
                aiBrain[refbUnclaimedMexNearACU] = false
            end


        --=============Enemy ACU all-in attack with ACU
            local iEnemyACUSearchRange = 50
            local tEnemyACUs = aiBrain:GetUnitsAroundPoint(categories.COMMAND, tACUPos, 1000, 'Enemy')
            local bAllInAttack = false
            local bIncludeACUInAttack = false
            local iHealthThresholdAdjIfAlreadyAllIn = 0
            local iHealthAbsoluteThresholdIfAlreadyAllIn = 750
            local bCheckThreatBeforeCommitting = true
            local iEnemyThreat, iAlliedThreat, tEnemyUnitsNearEnemy, tAlliedUnitsNearEnemy
            local iThreatFactor = 1.1 --We need this much more threat than threat around enemy ACU to commit to ACU kill
            local iNearbyThreatSearchRange = 60 --Search range for threat around enemy ACU
            if aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill then iHealthThresholdAdjIfAlreadyAllIn = 0.05 end
            local iACUCurShield, iACUMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oACU)
            local bWantEscort = oACU:IsUnitState('Upgrading')
            if bWantEscort and oACU:GetHealthPercent() >= 0.95 and iACUCurShield >= iACUMaxShield * 0.95 and M27Conditions.DoesACUHaveGun(aiBrain, false, oACU) then
                bWantEscort = false
            end

            local bEmergencyRequisition = false
            local iLastDistanceToACU = 10000
            if aiBrain[reftLastNearestACU] then iLastDistanceToACU = M27Utilities.GetDistanceBetweenPositions(aiBrain[reftLastNearestACU], tACUPos) end

            if M27Utilities.IsTableEmpty(tEnemyACUs) == false then
                local oNearestACU = M27Utilities.GetNearestUnit(tEnemyACUs, tACUPos, aiBrain, false, false)
                local tNearestACU = oNearestACU:GetPosition()
                local iDistanceToACU = M27Utilities.GetDistanceBetweenPositions(tNearestACU, tACUPos)
                if aiBrain[refoLastNearestACU] and not(aiBrain[refoLastNearestACU].Dead) then
                    if oNearestACU == aiBrain[refoLastNearestACU] then
                        aiBrain[reftLastNearestACU] = tNearestACU
                        iLastDistanceToACU = iDistanceToACU
                    else
                        if iDistanceToACU < aiBrain[refiLastNearestACUDistance] then
                            aiBrain[refoLastNearestACU] = oNearestACU
                            aiBrain[reftLastNearestACU] = tNearestACU
                            iLastDistanceToACU = iDistanceToACU
                        else
                            --Nearest ACU may just be temporarily hidden so dont want to revise the value
                        end
                    end
                else
                    aiBrain[refoLastNearestACU] = oNearestACU
                    aiBrain[reftLastNearestACU] = tNearestACU
                    iLastDistanceToACU = iDistanceToACU
                end
            end

            --Are we near the last ACU's known position?
            aiBrain[refbEnemyACUNearOurs] = false
            if iLastDistanceToACU <= iEnemyACUSearchRange and M27UnitInfo.IsUnitValid(aiBrain[refoLastNearestACU]) then
                if bDebugMessages == true then LOG(sFunctionRef..': Are near last ACU known position, iLastDistanceToACU='..iLastDistanceToACU..'; iEnemyACUSearchRange='..iEnemyACUSearchRange) end
                aiBrain[refbEnemyACUNearOurs] = true
                bWantEscort = true
                --Extra health buffer for some of below checks
                local iExtraHealthCheck = 0
                if M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tACUPos) > M27Utilities.GetDistanceBetweenPositions(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), tACUPos) then iExtraHealthCheck = 1000 end
                local iACURange = M27Logic.GetUnitMaxGroundRange({ oACU })
                --Do we have a big gun, or is the enemy ACU low on health?
                if M27Conditions.DoesACUHaveBigGun(aiBrain, oACU) == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': Our ACU has a big gun') end
                    bAllInAttack = true
                    bIncludeACUInAttack = true
                else
                    --Attack if we're close to ACU and have a notable health advantage, and are on our side of the map or are already in attack mode
                    if iLastDistanceToACU <= (iACURange + 15) and aiBrain[refoLastNearestACU]:GetHealthPercent() < (0.5 + iHealthThresholdAdjIfAlreadyAllIn) and aiBrain[refoLastNearestACU]:GetHealth() + iExtraHealthCheck + 2500 < (oACU:GetHealth() + iHealthAbsoluteThresholdIfAlreadyAllIn) and (M27Utilities.GetDistanceBetweenPositions(aiBrain[reftLastNearestACU], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(aiBrain[reftLastNearestACU], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) or aiBrain[refbIncludeACUInAllOutAttack] == true) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy ACU is almost in range of us and is on low health so will do all out attack') end
                        bAllInAttack = true
                        bIncludeACUInAttack = true
                        bCheckThreatBeforeCommitting = true
                    --Attack if enemy ACU is in range and could die to an explosion (so we either win or draw)
                    elseif iLastDistanceToACU <= iACURange and aiBrain[refoLastNearestACU]:GetHealth() < (1800 + iHealthAbsoluteThresholdIfAlreadyAllIn) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy ACU will die to explaosion so want to stay close to ensure draw or win') end
                        bAllInAttack = true
                        bIncludeACUInAttack = true
                    --Attack if we have gun and enemy ACU doesnt, and we have at least as much health (or more health if are on enemy side of map)
                        --DoesACUHaveGun(aiBrain, bROFAndRange, oAltACU)
                    elseif M27Conditions.DoesACUHaveGun(aiBrain, false, aiBrain[refoLastNearestACU]) == false and M27Conditions.DoesACUHaveGun(aiBrain, false, oACU) == true and aiBrain[refoLastNearestACU]:GetHealth() + iExtraHealthCheck < oACU:GetHealth() then
                        if bDebugMessages == true then LOG(sFunctionRef..': We have gun, enemy ACU doesnt, and we haver more health') end
                        bAllInAttack = true
                        bIncludeACUInAttack = true
                        bCheckThreatBeforeCommitting = true
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': bAllInAttack after considering our ACU vs their ACU='..tostring(bAllInAttack)) end

                if bAllInAttack == false and aiBrain[refbEnemyACUNearOurs] and iLastDistanceToACU <= (iACURange + 15) then
                    --Do we need to request emergency help?
                    local iHealthModForGun = 0
                    local iHealthPercentModForGun = 0
                    if M27Conditions.DoesACUHaveGun(aiBrain, false, aiBrain[refoLastNearestACU]) then
                        if not(M27Conditions.DoesACUHaveGun(aiBrain, false, oACU)) then
                            iHealthModForGun = -6000
                            iHealthPercentModForGun = 0.2
                        end
                    else
                        if M27Conditions.DoesACUHaveGun(aiBrain, false, oACU) then
                            iHealthModForGun = math.min(2000, oACU:GetHealth() * 0.25)
                            iHealthPercentModForGun = -0.1
                        end
                    end

                    if aiBrain[refoLastNearestACU]:GetHealth() > (oACU:GetHealth() + iHealthModForGun) and aiBrain[refoLastNearestACU]:GetHealth() > 2500 and oACU:GetHealthPercent() < (0.75 + iHealthPercentModForGun) then
                        bWantEscort = true
                        bEmergencyRequisition = true
                        if not(aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance) and not(aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill) then
                            aiBrain[refiAIBrainCurrentStrategy] = refStrategyProtectACU
                        end
                    end
                end
            end
            if bAllInAttack == false and M27UnitInfo.IsUnitValid(aiBrain[refoLastNearestACU]) then
                if bDebugMessages == true then LOG(sFunctionRef..': Will consider if want all out attack even if our ACU isnt in much stronger position') end
                if aiBrain[refoLastNearestACU]:GetHealthPercent() < (0.1 + iHealthThresholdAdjIfAlreadyAllIn) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Enemy ACU is almost dead') end
                    bAllInAttack = true
                elseif aiBrain[refoLastNearestACU]:GetHealthPercent() < (0.75 + iHealthThresholdAdjIfAlreadyAllIn) then
                    --Do we have more threat near the ACU than the ACU has?
                    tAlliedUnitsNearEnemy = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, aiBrain[reftLastNearestACU], iNearbyThreatSearchRange, 'Ally')

                    if M27Utilities.IsTableEmpty(tAlliedUnitsNearEnemy) == false then
                        tEnemyUnitsNearEnemy = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, aiBrain[reftLastNearestACU], iNearbyThreatSearchRange, 'Enemy')
                        iThreatFactor = 2.5
                        if aiBrain[refoLastNearestACU]:GetHealthPercent() < (0.4 + iHealthThresholdAdjIfAlreadyAllIn) then iThreatFactor = 1.25 end
                        if aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill then iThreatFactor = 1 end
                        iAlliedThreat = M27Logic.GetCombatThreatRating(aiBrain, tAlliedUnitsNearEnemy, false, nil, nil, false, false)
                        iEnemyThreat = M27Logic.GetCombatThreatRating(aiBrain, tEnemyUnitsNearEnemy, false, nil, nil, false, false)
                        if iAlliedThreat > (iEnemyThreat * iThreatFactor) then
                            if bDebugMessages == true then LOG(sFunctionRef..': We have much more threat than the enemy ACU') end
                            bAllInAttack = true
                        end
                    end
                end


                if bAllInAttack and not(oACU:IsUnitState('Upgrading')) and oACU:GetHealthPercent() > 0.5 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Include ACU in all out attack as it has more than 50% health') end
                    bIncludeACUInAttack = true
                end
                if bDebugMessages == true then LOG(sFunctionRef..': bAllInAttack='..tostring(bAllInAttack)) end
            end

            --Override decision if enemy ACU has significantly more threat than us
            if bAllInAttack then
                if aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill then iThreatFactor = 0.9 end
                if not(iAlliedThreat) then
                    tAlliedUnitsNearEnemy = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, aiBrain[reftLastNearestACU], iNearbyThreatSearchRange, 'Ally')
                    iAlliedThreat =  M27Logic.GetCombatThreatRating(aiBrain, tAlliedUnitsNearEnemy, false, nil, nil, false, false)
                end

                if not(iEnemyThreat) then
                    tEnemyUnitsNearEnemy = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, aiBrain[reftLastNearestACU], iNearbyThreatSearchRange, 'Enemy')
                    iEnemyThreat = M27Logic.GetCombatThreatRating(aiBrain, tEnemyUnitsNearEnemy, false, nil, nil, false, false)
                end
                if iAlliedThreat < (iEnemyThreat * iThreatFactor) then
                    if bDebugMessages == true then LOG(sFunctionRef..': iAlliedThreat='..iAlliedThreat..'; iEnemyThreat='..iEnemyThreat..'; iThreatFactor='..iThreatFactor..'; therefore aborting All in attack') end
                    bAllInAttack = false
                    bIncludeACUInAttack = false
                end
            end






    --==========ACU Run away and cancel upgrade logic
            --Is the ACU upgrading?
            if oACU:IsUnitState('Upgrading') then
                local bCancelUpgradeAndRun = false
                if not(oACU[reftACURecentUpgradeProgress]) then oACU[reftACURecentUpgradeProgress] = {} end
                oACU[reftACURecentUpgradeProgress][iCurTime] = oACU:GetWorkProgress()

                --Did we start the upgrade <10s ago but have lost a significant amount of health?
                if oACU[reftACURecentUpgradeProgress][iCurTime - 10] == nil and oACU[reftACURecentHealth][iCurTime - 10] - oACU[reftACURecentHealth][iCurTime] > 1000 and oACU[reftACURecentUpgradeProgress][iCurTime] < 0.7 then
                    if bDebugMessages == true then LOG(sFunctionRef..': ACU has lost a lot of health recently, oACU[reftACURecentHealth][iCurTime - 10]='..oACU[reftACURecentHealth][iCurTime - 10]..'; oACU[reftACURecentHealth][iCurTime]='..oACU[reftACURecentHealth][iCurTime]..'; oACU[reftACURecentUpgradeProgress][iCurTime]='..oACU[reftACURecentUpgradeProgress][iCurTime]) end
                    bCancelUpgradeAndRun = true
                    --Is the reason for the health loss because we removed T2 upgrade (e.g. sera)? Note - if changing the time frame from 10s above, need to change the delay variable reset on the upgrade in platoonutilities (currently 11s)
                    if oACU[M27UnitInfo.refbRecentlyRemovedHealthUpgrade] and (oACU:GetHealthPercent() >= 0.99 or oACU[reftACURecentHealth][iCurTime - 10] - oACU[reftACURecentHealth][iCurTime] < 3000) then
                        if bDebugMessages == true then LOG(sFunctionRef..': We recently removed an upgrade that increased our health and have good health or health loss less than 3k') end
                        bCancelUpgradeAndRun = false
                    end

                elseif oACU[reftACURecentUpgradeProgress][iCurTime] < 0.9 then

                    --Based on how our health has changed over the last 10s vs the upgrade progress, are we likely to die?
                    local iHealthLossPerSec = (oACU[reftACURecentHealth][iCurTime-10] - oACU[reftACURecentHealth][iCurTime])/10
                    if iHealthLossPerSec > 50 then --If changing these values, consider updating the SafeToGetACUUpgrade thresholds
                        local iTimeToComplete = (1 - oACU[reftACURecentUpgradeProgress][iCurTime]) / ((oACU[reftACURecentUpgradeProgress][iCurTime] - oACU[reftACURecentUpgradeProgress][iCurTime - 10]) / 10)
                        if iTimeToComplete * iHealthLossPerSec > math.min(oACU[reftACURecentHealth][iCurTime] * 0.9, oACU:GetMaxHealth() * 0.7) then
                            --ACU will be really low health or die if it keeps upgrading
                            bCancelUpgradeAndRun = true
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': iHealthLossPerSec='..iHealthLossPerSec..'; iTimeToComplete='..iTimeToComplete..'; iTimeToComplete * iHealthLossPerSec='..iTimeToComplete * iHealthLossPerSec..'; oACU[reftACURecentHealth][iCurTime - 10]='..oACU[reftACURecentHealth][iCurTime - 10]..'; oACU[reftACURecentHealth][iCurTime]='..oACU[reftACURecentHealth][iCurTime]..'; oACU[reftACURecentUpgradeProgress][iCurTime]='..oACU[reftACURecentUpgradeProgress][iCurTime]) end
                    elseif bDebugMessages == true then LOG(sFunctionRef..': iHealthLossPerSec='..iHealthLossPerSec)
                    end

                end
                if bCancelUpgradeAndRun == false then
                    --if >=3 TML nearby, then cancel upgrade
                    if M27Utilities.IsTableEmpty(aiBrain[reftEnemyTML]) == false then
                        --Abort ACU upgrade if >=3 TML and its not safe to upgrade
                        local iEnemyTML = 0
                        for iUnit, oUnit in aiBrain[reftEnemyTML] do
                            if M27UnitInfo.IsUnitValid(oUnit) then
                                iEnemyTML = iEnemyTML + 1
                            end
                        end
                        if iEnemyTML >= 3 then
                            if M27Conditions.SafeToGetACUUpgrade(aiBrain) == false and oACU:GetWorkProgress() < 0.85 then
                                --Double-check all 3 TML are in-range, since safetoget upgrade only uses threshold of 2
                                iEnemyTML = 0
                                for iUnit, oUnit in aiBrain[reftEnemyTML] do
                                    if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tACUPos) <= 259 then
                                        iEnemyTML = iEnemyTML + 1
                                    end
                                end
                                if iEnemyTML >= 3 then
                                    --Abort upgrade
                                    bCancelUpgradeAndRun = true
                                end
                            end
                        end
                    end
                else
                    --Want to cancel but not because of TML
                    if not(aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance) and not(aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill) then
                        aiBrain[refiAIBrainCurrentStrategy] = refStrategyProtectACU
                    end
                end

                if bCancelUpgradeAndRun then
                    if bDebugMessages == true then LOG(sFunctionRef..': Want to cancel upgrade and run') end
                    --Only actually cancel if we're not close to our base as if we're close to base then will probably die if cancel as well
                    if M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) > iDistanceFromBaseWhenVeryLowHealthToBeSafe then
                        if bDebugMessages == true then LOG(sFunctionRef..': Clearing commands for ACU') end
                        IssueClearCommands({M27Utilities.GetACU(aiBrain)})
                        IssueMove({oACU}, M27Logic.GetNearestRallyPoint(aiBrain, tACUPos))
                    end


                end
            end


            local iHealthPercentage = oACU:GetHealthPercent()
            --[[local bRunAway = false
            local bNewPlatoon = true
            local oNewPlatoon--]]

            if bIncludeACUInAttack == false and iHealthPercentage <= iACUGetHelpPercentThreshold then
                bWantEscort = true
                bEmergencyRequisition = true
            end
            --Below code superceded now that we use ACUMainAI for everything which has its built in logic to run
            --[[
                if bDebugMessages == true then LOG(sFunctionRef..': ACU low on health so forcing it to run to base unless its already there') end

                local iPlayerStartNumber = aiBrain.M27StartPositionNumber
                --Is the ACU within 25 of our base? If so then no point overriding
                if M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[iPlayerStartNumber]) > iDistanceFromBaseWhenVeryLowHealthToBeSafe then
                    bRunAway = true
                    --Is ACU upgrading and almost done?
                    if oACU:IsUnitState('Upgrading') and oACU.GetWorkProgress then
                        if not(oACU:GetWorkProgress() <= 0.9) or iHealthPercentage > iACUEmergencyHealthPercentThreshold then bRunAway = false end
                    end
                end
            else
                --Not low health so no longer want escort
                if not(oACU:IsUnitState('Upgrading')) and iHealthPercentage >= 0.8 and oACUPlatoon then oACUPlatoon[M27PlatoonUtilities.refbShouldHaveEscort] = false end
            end

            if bRunAway == true and not(sACUPlan == 'M27ACUMain') then --M27ACUMain now has logic for the ACU to run built into it (so this isnt needed if runing M27ACUMain); have also replaced almost all uses of non-M27Main logic for ACU (including defender and initial build order) so below likely no longer relevant
                --Make platoon cancel any upgrade and run
                if bDebugMessages == true then
                    LOG(sFunctionRef..': iHealthPercentage='..iHealthPercentage..'; GetFractionComplete='..oACU:GetFractionComplete())
                    if oACU.GetWorkProgress then LOG('GetWorkProgress='..oACU:GetWorkProgress()) end
                    if oACU.UnitBeingBuilt then LOG('UnitBeingBuilt='..oACU.UnitBeingBuilt:GetUnitId()..'; FractionComplete='..oACU.UnitBeingBuilt:GetFractionComplete())
                    else LOG('No unit being built') end
                end



                if oACUPlatoon and oACUPlatoon.GetPlan and oACUPlatoon:GetPlan() == 'M27ACUMain' then bNewPlatoon = false end
                if bNewPlatoon == true then
                    oNewPlatoon = aiBrain:MakePlatoon('', '')
                    aiBrain:AssignUnitsToPlatoon(oNewPlatoon, {oACU}, 'Support', 'None')
                    oNewPlatoon:SetAIPlan('M27ACUMain')
                    oNewPlatoon[M27PlatoonUtilities.reftMovementPath] = {}
                    oNewPlatoon[M27PlatoonUtilities.reftMovementPath][1] = {}
                    if bDebugMessages == true then
                        local iPlatoonCount = oNewPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                        if iPlatoonCount == nil then iPlatoonCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27ACUMain']
                            if iPlatoonCount == nil then iPlatoonCount = 1
                            else iPlatoonCount = iPlatoonCount + 1 end
                        end
                        LOG(sFunctionRef..': Changed ACU platoon back to ACU main, platoon name+count='..'M27ACUMain'..iPlatoonCount)
                    end
                else oNewPlatoon = oACUPlatoon
                end

                if not(oNewPlatoon[M27PlatoonUtilities.reftMovementPath][1] == M27MapInfo.PlayerStartPoints[aiBrain.M27StartPosition]) then
                    oNewPlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionReturnToBase
                    if bDebugMessages == true then LOG(sFunctionRef..': Forcing action refresh') end
                    M27PlatoonUtilities.ForceActionRefresh(oNewPlatoon, 5)
                end
            end--]]
            if oACUPlatoon then
                oACUPlatoon[M27PlatoonUtilities.refbShouldHaveEscort] = bWantEscort

                --If we dont want an escort and we last wanted an escort 15+ seconds ago, then disband the escort platoon
                if bWantEscort then
                    if bDebugMessages == true then LOG(sFunctionRef..': ACU wants an escort') end
                    oACUPlatoon[M27PlatoonUtilities.refiLastTimeWantedEscort] = math.floor(GetGameTimeSeconds())
                else
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': ACU doesnt want an escort any more, will check if it hasnt wanted one for a while now, and if it has an escorting platoon. oACUPlatoon[M27PlatoonUtilities.refiLastTimeWantedEscort]='..(oACUPlatoon[M27PlatoonUtilities.refiLastTimeWantedEscort] or 'nil'))
                        if oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon] then LOG('Have an escorting platoon, number of units in platoon='..(oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon][M27PlatoonUtilities.refiCurrentUnits] or 'nil'))
                        else LOG('Dont have an escorting platoon')
                        end
                    end

                    if oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon] and oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon][M27PlatoonUtilities.refiCurrentUnits] > 1 then
                        if GetGameTimeSeconds() - oACUPlatoon[M27PlatoonUtilities.refiLastTimeWantedEscort] >= 15 then
                            if bDebugMessages == true then LOG(sFunctionRef..': Will tell escorting platoon to disband') end
                            oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon][M27PlatoonUtilities.refiCurrentAction] = M27PlatoonUtilities.refActionDisband
                        end
                    end
                end
                if bEmergencyRequisition and not(bAllInAttack) then
                    --Is the ACU close to our base? If so then only do emergency response if very low health
                    if M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) > iRangeForACUToBeNearBase or iHealthPercentage < iACUEmergencyHealthPercentThreshold then
                        if not(aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance) and not(aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill) then
                            --If ACU not taken damage in a while and no nearby enemy units, then dont adopt protectACU strategy
                            if not(oACU[reftACURecentHealth][iCurTime - 30] < oACU[reftACURecentHealth][iCurTime] and M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, tACUPos, 50, 'Enemy'))) then
                                aiBrain[refiAIBrainCurrentStrategy] = refStrategyProtectACU
                            end
                        end

                        --Get all nearby combat units we own
                        local tNearbyCombat = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, tACUPos, iRangeForEmergencyEscort, 'Ally')
                        if M27Utilities.IsTableEmpty(tNearbyCombat) == false then
                            --Check we have at least 1 unit that can be assigned
                            local bHaveAUnit = false
                            for iUnit, oUnit in tNearbyCombat do
                                if M27UnitInfo.IsUnitValid(oUnit) and oUnit:GetAIBrain() == aiBrain and not(M27Utilities.IsACU(oUnit)) then
                                    bHaveAUnit = true
                                    break
                                end
                            end

                            if bHaveAUnit == true then
                                local oEscortingPlatoon = oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon]
                                if not(oEscortingPlatoon) or not(aiBrain:PlatoonExists(oEscortingPlatoon)) then
                                    oEscortingPlatoon = M27PlatoonFormer.CreatePlatoon(aiBrain, 'M27EscortAI', nil)
                                    oEscortingPlatoon[M27PlatoonUtilities.refoPlatoonOrUnitToEscort] = oACUPlatoon
                                    oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon] = oEscortingPlatoon
                                end


                                --Filter to only units we control that arent already in this platoon
                                local tNearbyOwnedCombat = {}
                                local iNearbyOwnedCombatCount = 0
                                for iUnit, oUnit in tNearbyCombat do
                                    if M27UnitInfo.IsUnitValid(oUnit) and oUnit:GetAIBrain() == aiBrain and not(M27Utilities.IsACU(oUnit)) then
                                        if not(oUnit.PlatoonHandle) or not(oUnit.PlatoonHandle == oEscortingPlatoon) then
                                            iNearbyOwnedCombatCount = iNearbyOwnedCombatCount + 1
                                            tNearbyOwnedCombat[iNearbyOwnedCombatCount] = oUnit
                                        end
                                    end
                                end
                                if iNearbyOwnedCombatCount > 0 then
                                    --Add combat units to this
                                    aiBrain:AssignUnitsToPlatoon(oEscortingPlatoon, tNearbyOwnedCombat, 'Attack', 'GrowthFormation')
                                end
                            end
                        end
                    end
                end
                --Reset flag for ACU having run (normally platoons reset when they reach their destination, but for ACU it will revert to going to enemy start if we have gun upgrade)
                if oACU:GetHealthPercent() >= 0.95 and oACU.PlatoonHandle[M27PlatoonUtilities.refbHavePreviouslyRun] and M27Conditions.DoesACUHaveGun(aiBrain, false) then
                    if iACUMaxShield == 0 or iACUCurShield >= iACUMaxShield * 0.7 then
                        --Large threat near ACU?
                        local iNearbyThreat = 0
                                                                                --GetCombatThreatRating(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, iMassValueOfBlipsOverride, iSoloBlipMassOverride, bIndirectFireThreatOnly, bJustGetMassValue)
                        if oACU.PlatoonHandle[M27PlatoonUtilities.refiEnemiesInRange] then iNearbyThreat = iNearbyThreat + M27Logic.GetCombatThreatRating(aiBrain,oACU.PlatoonHandle[M27PlatoonUtilities.reftEnemiesInRange], true) end
                        if oACU.PlatoonHandle[M27PlatoonUtilities.refiEnemyStructuresInRange] then iNearbyThreat = iNearbyThreat + M27Logic.GetCombatThreatRating(aiBrain,oACU.PlatoonHandle[M27PlatoonUtilities.reftEnemyStructuresInRange], true) end
                        if iNearbyThreat <= oACU.PlatoonHandle[M27PlatoonUtilities.refiPlatoonThreatValue] * 0.5 then
                            oACU.PlatoonHandle[M27PlatoonUtilities.refbHavePreviouslyRun] = false
                        end
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': oACUPlatoon[M27PlatoonUtilities.refbShouldHaveEscort]='..tostring(oACUPlatoon[M27PlatoonUtilities.refbShouldHaveEscort])) end
            end

            if bAllInAttack == true then
                if bDebugMessages == true then LOG(sFunctionRef..': Are doing all in attack, will consider if want to suicide our ACU') end
                aiBrain[refiAIBrainCurrentStrategy] = refStrategyACUKill
                aiBrain[refbStopACUKillStrategy] = false
                aiBrain[refbIncludeACUInAllOutAttack] = bIncludeACUInAttack
                --Consider Ctrl-K of ACU
                local bSuicide = false
                if oACU:GetHealth() <= 275 and M27UnitInfo.IsUnitValid(aiBrain[refoLastNearestACU]) then
                    local iEnemyACUHealth = aiBrain[refoLastNearestACU]:GetHealth()
                    if iEnemyACUHealth <= 2000 then
                        local iDistanceToEnemyACU = M27Utilities.GetDistanceBetweenPositions(tACUPos, aiBrain[refoLastNearestACU]:GetPosition())
                        if iDistanceToEnemyACU <= 30 then
                            bSuicide = true
                        elseif iDistanceToEnemyACU <= 40 and iEnemyACUHealth <= 500 then
                            bSuicide = true
                        end
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': bSuicide='..tostring(bSuicide)..'; ACU Health='..oACU:GetHealth()..'; LastACUHealth='..aiBrain[refoLastNearestACU]:GetHealth()..'; distance between ACUs='..M27Utilities.GetDistanceBetweenPositions(tACUPos, aiBrain[refoLastNearestACU]:GetPosition())) end
                if bSuicide then
                    M27Chat.SendSuicideMessage(aiBrain)
                    oACU:Kill()
                    if bDebugMessages == true then LOG(sFunctionRef..': Have just told our ACU to self destruct') end
                end
            else
                aiBrain[refbIncludeACUInAllOutAttack] = false
                aiBrain[refbStopACUKillStrategy] = true
                if oACU.PlatoonHandle then oACU.PlatoonHandle[M27PlatoonUtilities.reftPlatoonDFTargettingCategories] = M27UnitInfo.refWeaponPriorityNormal end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function PlatoonNameUpdater(aiBrain, bUpdateCustomPlatoons)
    --Every second cycles through every platoon and updates its name to reflect its plan and platoon count
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'PlatoonNameUpdater'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': checking if want to update platoon names') end
    if M27Config.M27ShowUnitNames == true then
        if bUpdateCustomPlatoons == nil then bUpdateCustomPlatoons = true end
        local sPlatoonName, iPlatoonCount
        local oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
        local bPlatoonUsesM27Platoon = true
        local refsPrevPlatoonName = 'M27PrevPlatoonName'
        if M27Utilities.IsTableEmpty(aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]) == true then aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] = {} end
        if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through each platoon') end
        for iPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
            if oPlatoon == oArmyPoolPlatoon then
                sPlatoonName = 'ArmyPool'
                bPlatoonUsesM27Platoon = false
            else
                if oPlatoon.GetPlan then
                    sPlatoonName = oPlatoon:GetPlan()
                    if oPlatoon[M27PlatoonUtilities.refiPlatoonCount] == nil then bPlatoonUsesM27Platoon = false end
                else sPlatoonName = 'None'
                    bPlatoonUsesM27Platoon = false
                end
            end
            if sPlatoonName == nil then sPlatoonName = 'None' end
            if aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount][sPlatoonName] == nil then aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount][sPlatoonName] = 0 end
            if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonName='..sPlatoonName..'; bPlatoonUsesM27Platoon='..tostring(bPlatoonUsesM27Platoon)) end
            if bPlatoonUsesM27Platoon == false then
                if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonName='..sPlatoonName..'; Platoon doesnt use M27Platoon, checking if have updated name before') end
                --Have we already updated this platoon before?
                local bHaveUpdatedBefore = false
                if oPlatoon[refsPrevPlatoonName] == nil then
                    oPlatoon[refsPrevPlatoonName] = sPlatoonName
                else
                    if oPlatoon[refsPrevPlatoonName] == sPlatoonName then bHaveUpdatedBefore = true end
                end

                --if bHaveUpdatedBefore == false then
                    aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount][sPlatoonName] = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount][sPlatoonName] + 1
                    oPlatoon[M27PlatoonUtilities.refiPlatoonCount] = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount][sPlatoonName]
                    M27PlatoonUtilities.UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[M27PlatoonUtilities.refiPlatoonCount])
                --end
            else
                if bUpdateCustomPlatoons == true then
                    local iPlatoonCount = oPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                    if iPlatoonCount == nil then iPlatoonCount = 0 end
                    local iPlatoonAction = oPlatoon[M27PlatoonUtilities.refiCurrentAction]
                    if iPlatoonAction == nil then iPlatoonAction = 0
                    M27PlatoonUtilities.UpdatePlatoonName(oPlatoon, sPlatoonName..iPlatoonCount..':Action='..iPlatoonAction) end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function WaitTicksSpecial(aiBrain, iTicksToWait)
    --calls the GetACU function since that will check if ACU is alive, and if not will delay to avoid a crash
    --Returns false if ACU no longer valid or all enemies are defeated
    if aiBrain.M27IsDefeated or M27Logic.iTimeOfLastBrainAllDefeated > 10 then
        return false
    else
        WaitTicks(iTicksToWait)
        local oACU = M27Utilities.GetACU(aiBrain)
        if oACU.M27IsDefeated or M27Logic.iTimeOfLastBrainAllDefeated > 10 then return false end
    end
    return true
end

function EnemyThreatRangeUpdater(aiBrain)
    --Updates range to look for enemies based on if any T2 PD detected
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'EnemyThreatRangeUpdater'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if aiBrain[refbEnemyHasTech2PD] == false then
        local tEnemyTech2 = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH2, M27Utilities.GetACU(aiBrain):GetPosition(), 1000, 'Enemy')
        if M27Utilities.IsTableEmpty(tEnemyTech2) == false then
            aiBrain[refbEnemyHasTech2PD] = true
            aiBrain[refiSearchRangeForEnemyStructures] = 85 --Tech 2 is 50, ravager 70, so will go for 80 range; want to factor it into decisions on whether to attack if are near it
            if bDebugMessages == true then LOG(sFunctionRef..': Enemy T2 PD detected - increasing range to look for nearby enemies on platoons') end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function SetMaximumFactoryLevels(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'SetMaximumFactoryLevels'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local iAirFactoriesOwned = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory)
    local iPrimaryFactoriesWanted
    local iPrimaryFactoryType = refFactoryTypeLand
    if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] == false then
        iPrimaryFactoryType = refFactoryTypeAir
        aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = 1
    elseif aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance then
        iPrimaryFactoryType = refFactoryTypeAir
        aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = 1
    end
    --local iMexCount = aiBrain:GetCurrentUnits(refCategoryMex)

    local iMexesToBaseCalculationOn
    if aiBrain[refiOurHighestFactoryTechLevel] >= 3 then
        iMexesToBaseCalculationOn = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex) + aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Mex) * 0.25
    elseif aiBrain[refiOurHighestFactoryTechLevel] == 2 then
        iMexesToBaseCalculationOn = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex) * 3 + aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Mex) + aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT1Mex) / 3
    else
        iMexesToBaseCalculationOn = math.min(M27EconomyOverseer.GetMexCountOnOurSideOfMap(aiBrain), aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex) * 9 + aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Mex) * 3 + aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT1Mex))
    end

    if aiBrain[refiAIBrainCurrentStrategy] == refStrategyEcoAndTech then
        if not(M27Conditions.HaveLowMass(aiBrain)) and aiBrain:GetEconomyStoredRatio('MASS') > 0.2 then
            iPrimaryFactoriesWanted = math.max(5 - aiBrain[refiOurHighestFactoryTechLevel], math.ceil(iMexesToBaseCalculationOn * 0.25))
        elseif not(M27Conditions.HaveLowMass(aiBrain)) then iPrimaryFactoriesWanted = math.max(4 - aiBrain[refiOurHighestFactoryTechLevel], math.ceil(iMexesToBaseCalculationOn * 0.20))
        else
            --Have low mass
            iPrimaryFactoriesWanted = math.max(1, math.ceil(iMexesToBaseCalculationOn * 0.15))
        end
    else
        if M27Conditions.HaveLowMass(aiBrain) then
            iPrimaryFactoriesWanted = math.max(5 - aiBrain[refiOurHighestFactoryTechLevel], math.ceil(iMexesToBaseCalculationOn * 0.5))
        else
            iPrimaryFactoriesWanted = math.max(6 - aiBrain[refiOurHighestFactoryTechLevel], math.ceil(iMexesToBaseCalculationOn * 0.7))
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': iPrimaryFactoriesWanted before considering other factors='..iPrimaryFactoriesWanted) end

    aiBrain[reftiMaxFactoryByType][iPrimaryFactoryType] = iPrimaryFactoriesWanted
    local iAirFactoryMin = 1
    if iPrimaryFactoryType == refFactoryTypeAir then iAirFactoryMin = iPrimaryFactoriesWanted end
    local iTorpBomberShortfall = aiBrain[M27AirOverseer.refiTorpBombersWanted]
    if aiBrain[refiOurHighestAirFactoryTech] < 2 then
        if iTorpBomberShortfall > 0 then aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1 end
        iTorpBomberShortfall = 0 --Dont want to build more factories for torp bombers until have access to T2 (since T1 cant build them)
    end
    if iPrimaryFactoryType == refFactoryTypeAir then aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1 end
    if bDebugMessages== true then LOG(sFunctionRef..': aiBrain[M27AirOverseer.refiAirAANeeded]='..aiBrain[M27AirOverseer.refiAirAANeeded]..'; aiBrain[M27AirOverseer.refiExtraAirScoutsWanted]='..aiBrain[M27AirOverseer.refiExtraAirScoutsWanted]..'; aiBrain[M27AirOverseer.refiBombersWanted]='..aiBrain[M27AirOverseer.refiBombersWanted]..'; iTorpBomberShortfall='..iTorpBomberShortfall) end
    local iModBombersWanted = math.min(aiBrain[M27AirOverseer.refiBombersWanted], 3)
    --reftBomberEffectiveness = 'M27AirBomberEffectiveness' --[x][y]: x = unit tech level, y = nth entry; returns subtable {refiBomberMassCost}{refiBomberMassKilled}
    if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftBomberEffectiveness][aiBrain[refiOurHighestAirFactoryTech]]) == false then
        if aiBrain[M27AirOverseer.reftBomberEffectiveness][aiBrain[refiOurHighestAirFactoryTech]][1][M27AirOverseer.refiBomberMassKilled] >= aiBrain[M27AirOverseer.reftBomberEffectiveness][aiBrain[refiOurHighestAirFactoryTech]][1][M27AirOverseer.refiBomberMassCost] then
            --Last bomber that died at this tech levle killed more than it cost
            iModBombersWanted = math.min(aiBrain[M27AirOverseer.refiBombersWanted], 6)
        end
    end
    local iAirUnitsWanted = math.max(aiBrain[M27AirOverseer.refiAirAANeeded], aiBrain[M27AirOverseer.refiAirAAWanted]) + math.min(3, math.ceil(aiBrain[M27AirOverseer.refiExtraAirScoutsWanted]/10)) + math.min(5, aiBrain[M27AirOverseer.refiBombersWanted]) + iTorpBomberShortfall
    aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = math.max(iAirFactoryMin, iAirFactoriesOwned + math.floor((iAirUnitsWanted - iAirFactoriesOwned * 4)))
    if bDebugMessages == true then LOG(sFunctionRef..': iAirUnitsWanted='..iAirUnitsWanted..'; aiBrain[reftiMaxFactoryByType][refFactoryTypeAir]='..aiBrain[reftiMaxFactoryByType][refFactoryTypeAir]..'; aiBrain[reftiMaxFactoryByType][refFactoryTypeLand]='..aiBrain[reftiMaxFactoryByType][refFactoryTypeLand]) end

    if aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill or aiBrain[refiAIBrainCurrentStrategy] == refStrategyProtectACU then
        --Just build air factories if we have mass (assuming we have enough energy)
        aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1
        if aiBrain:GetEconomyStoredRatio('MASS') > 0.1 and aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] > 1 then
            aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = iAirFactoriesOwned + 1
        else
            aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = math.max(1, iAirFactoriesOwned)
        end
        aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = 1
    end

    --Cap the number of land factories if we are building an experimental
    local bActiveExperimental = false
    if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildExperimental]) == false then
        for iRef, tSubtable in  aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildExperimental] do
            if tSubtable[M27EngineerOverseer.refEngineerAssignmentEngineerRef]:IsUnitState('Building') then
                bActiveExperimental = true
                break
            end
        end
    end
    if bActiveExperimental then aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.min(aiBrain[reftiMaxFactoryByType][refFactoryTypeLand], 4) end
    if aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused] > 0 then aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.min(2, aiBrain[reftiMaxFactoryByType][refFactoryTypeLand]) end
    if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildExperimental]) == false then aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.min(2, aiBrain[reftiMaxFactoryByType][refFactoryTypeLand]) end

    if aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused] > 0 then
        aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.min(aiBrain[reftiMaxFactoryByType][refFactoryTypeLand], 1)
    end
    if bDebugMessages == true then LOG(sFunctionRef..': bActiveExperimental='..tostring(bActiveExperimental)..'; Idle factories='..aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused]) end


    if bDebugMessages == true then LOG(sFunctionRef..': End of code, aiBrain[reftiMaxFactoryByType][refFactoryTypeLand]='..aiBrain[reftiMaxFactoryByType][refFactoryTypeLand]..'; aiBrain[refiMinLandFactoryBeforeOtherTypes]='..aiBrain[refiMinLandFactoryBeforeOtherTypes]..'; aiBrain[reftiMaxFactoryByType][refFactoryTypeAir]='..aiBrain[reftiMaxFactoryByType][refFactoryTypeAir]) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DetermineInitialBuildOrder(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DetermineInitialBuildOrder'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == true then
        aiBrain[refiInitialRaiderPlatoonsWanted] = 2
        aiBrain[refiMinLandFactoryBeforeOtherTypes] = 2
        --How many mexes are there nearby?
        local iPathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        --tMexByPathingAndGrouping = {} --Stores position of each mex based on the segment that it's part of; [a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
        local iNearbyMexCount = 0

        if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping) == false then
            for iMexNumber, tMex in M27MapInfo.tMexByPathingAndGrouping[M27UnitInfo.refPathingTypeAmphibious][iPathingGroup] do
                if M27Utilities.GetDistanceBetweenPositions(tMex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 70 then
                    iNearbyMexCount = iNearbyMexCount + 1
                end
            end
        end
        if iNearbyMexCount >= 12 then
            aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = 7
        elseif iNearbyMexCount >= 8 or aiBrain[refiDistanceToNearestEnemyBase] >= 300 then aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = 5 --e.g. Theta passage is less than 300 I think
        else
            aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = 4
        end

        if aiBrain[refiDistanceToNearestEnemyBase] > iDistanceToEnemyEcoThreshold then
            if aiBrain[refiDistanceToNearestEnemyBase] > iDistanceToEnemyEcoThreshold * 2 then
                aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = math.max(aiBrain[M27FactoryOverseer.refiInitialEngineersWanted], 12)
            else
                aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = math.max(aiBrain[M27FactoryOverseer.refiInitialEngineersWanted], 8)
            end
        end


        --Calc dist to enemy base - dont manually here rather than referencing the variable as not sure on timing whether the variable will be calcualted yet - ideally want to go 2nd air on larger maps
        if M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) >= 350 then
            aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1
        end
    else
        aiBrain[refiInitialRaiderPlatoonsWanted] = 0
        aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1
        aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = 10
        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] == false then aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = 12 end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, aiBrain[M27FactoryOverseer.refiInitialEngineersWanted]='..aiBrain[M27FactoryOverseer.refiInitialEngineersWanted]..'; aiBrain[reftiMaxFactoryByType][refFactoryTypeAir]='..aiBrain[reftiMaxFactoryByType][refFactoryTypeLand]) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdateHighestFactoryTechTracker(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateHighestFactoryTechTracker'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, gametime='..GetGameTimeSeconds()) end

    local iHighestTechLevel = 1
    if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllFactories * categories.TECH3) > 0 then iHighestTechLevel = 3
    elseif aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllFactories * categories.TECH2) > 0 then iHighestTechLevel = 2 end
    aiBrain[refiOurHighestFactoryTechLevel] = iHighestTechLevel
    if iHighestTechLevel > 1 then
        if bDebugMessages == true then LOG(sFunctionRef..': iHighestTechLevel='..iHighestTechLevel..'; will consider how many air and land factories we have') end
        if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory * categories.TECH3) > 0 then aiBrain[refiOurHighestAirFactoryTech] = 3
        elseif aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory * categories.TECH2) > 0 then aiBrain[refiOurHighestAirFactoryTech] = 2
        else
            aiBrain[refiOurHighestAirFactoryTech] = 1
        end
        if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryLandFactory * categories.TECH3) > 0 then
            if bDebugMessages == true then LOG(sFunctionRef..': We have T3 land factories') end
            aiBrain[refiOurHighestLandFactoryTech] = 3
        elseif aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryLandFactory * categories.TECH2) > 0 then
            if bDebugMessages == true then LOG(sFunctionRef..': We dont have T3 land factories but do have T2') end
            aiBrain[refiOurHighestLandFactoryTech] = 2
        else aiBrain[refiOurHighestLandFactoryTech] = 1
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': Highest of any factory tech is only tech 1') end
        aiBrain[refiOurHighestAirFactoryTech] = 1
        aiBrain[refiOurHighestLandFactoryTech] = 1
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Number of tech2 factories='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllFactories * categories.TECH2)..'; Number of tech3 factories='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllFactories * categories.TECH3)..'; iHighestTechLevel='..iHighestTechLevel..'; aiBrain[refiOurHighestFactoryTechLevel]='..aiBrain[refiOurHighestFactoryTechLevel]..'; aiBrain[refiOurHighestAirFactoryTech]='..aiBrain[refiOurHighestAirFactoryTech]..'; Number of T3 land factories='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryLandFactory * categories.TECH3)..'; Highest land factory tech='..aiBrain[refiOurHighestLandFactoryTech]) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function StrategicOverseer(aiBrain, iCurCycleCount) --also features 'state of game' logs
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    --local bDebugMessages = M27Config.M27StrategicLog
    local sFunctionRef = 'StrategicOverseer'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Super enemy threats that need a big/unconventional response - check every second as some e.g. nuke require immediate response
    local iBigThreatSearchRange = 10000

    local tEnemyBigThreatCategories = {M27UnitInfo.refCategoryLandExperimental, M27UnitInfo.refCategoryFixedT3Arti, M27UnitInfo.refCategoryExperimentalStructure, M27UnitInfo.refCategorySML, M27UnitInfo.refCategoryTML}
    local tCurCategoryUnits
    local tReferenceTable, bRemovedUnit
    local sUnitUniqueRef

    for _, iCategory in tEnemyBigThreatCategories do
        tCurCategoryUnits = aiBrain:GetUnitsAroundPoint(iCategory, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iBigThreatSearchRange, 'Enemy')
        if iCategory == M27UnitInfo.refCategoryExperimentalStructure or iCategory == M27UnitInfo.refCategoryFixedT3Arti then tReferenceTable = aiBrain[reftEnemyArti]
        elseif iCategory == M27UnitInfo.refCategorySML then
            tReferenceTable = aiBrain[reftEnemyNukeLaunchers]
            if bDebugMessages == true then LOG(sFunctionRef..': Looking for enemy nukes') end
        elseif iCategory == M27UnitInfo.refCategoryTML then
            tReferenceTable = aiBrain[reftEnemyTML]
            if bDebugMessages == true then LOG(sFunctionRef..': Looking for enemy TML') end
        elseif iCategory == M27UnitInfo.refCategoryLandExperimental then
            tReferenceTable = aiBrain[reftEnemyLandExperimentals]
        elseif iCategory == M27UnitInfo.M27UnitInfo.refCategoryFixedT3Arti or iCategory == M27UnitInfo.refCategoryExperimentalStructure then
            tReferenceTable = aiBrain[reftEnemyArti]
        else
            M27Utilities.ErrorHandler('Unrecognised enemy super threat category, wont be recorded')
            break
        end
        if M27Utilities.IsTableEmpty(tCurCategoryUnits) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Have some units for experimental threat category _='.._..'; will check if its dead and if not add it to the table of threats') end
            for iUnit, oUnit in tCurCategoryUnits do
                if M27Utilities.CanSeeUnit(aiBrain, oUnit, false) == true then
                    sUnitUniqueRef = oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)
                    if tReferenceTable[sUnitUniqueRef] == nil then
                        tReferenceTable[sUnitUniqueRef] = oUnit
                        if bDebugMessages == true then LOG(sFunctionRef..': Added Unit with uniqueref='..sUnitUniqueRef..' to the threat table') end
                    end
                end
            end
        end
        --Update the table in case any existing entries have been killed:
        if M27Utilities.IsTableEmpty(tReferenceTable) == false then
            bRemovedUnit = true
            while bRemovedUnit == true do
                bRemovedUnit = false
                for iUnit, oUnit in tReferenceTable do
                    if not(oUnit.GetUnitId) or oUnit.Dead then
                        if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': No longer alive or has unit ID so removing from the reference table') end
                        bRemovedUnit = true
                        tReferenceTable[iUnit] = nil
                        break
                    end
                end
            end
        end
    end
    if M27Utilities.IsTableEmpty(aiBrain[reftEnemyTML]) == false and aiBrain[refbEnemyTMLSightedBefore] == false then
        aiBrain[M27PlatoonFormer.refbUsingMobileShieldsForPlatoons] = true
        aiBrain[refbEnemyTMLSightedBefore] = true
    end





    if iCurCycleCount <= 0 then
        --Update list of nearby enemies if any are dead
        local bCheckBrains = true
        local iCurCount = 0
        local iMaxCount = 20

        while bCheckBrains == true do
            iCurCount = iCurCount + 1
            if iCurCount > iMaxCount then M27Utilities.ErrorHandler('Infinite loop') break end
            bCheckBrains = false
            for iArmyIndex, oBrain in tAllAIBrainsByArmyIndex do
                if oBrain:IsDefeated() or oBrain.M27IsDefeated then
                    tAllAIBrainsByArmyIndex[iArmyIndex] = nil
                    bCheckBrains = true
                    break
                end
            end
        end

        local iNearestEnemyArmyIndex = M27Logic.GetNearestEnemyIndex(aiBrain)
        if not(iNearestEnemyArmyIndex == iPreviousNearestEnemyIndex) then
            aiBrain[refiDistanceToNearestEnemyBase] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[M27Logic.IndexToStartNumber(iNearestEnemyArmyIndex)])
            ForkThread(M27Logic.DetermineEnemyScoutSpeed, aiBrain)
        end
        iPreviousNearestEnemyIndex = iNearestEnemyArmyIndex


        ForkThread(M27MapInfo.UpdateReclaimMarkers)

        ForkThread(M27AirOverseer.UpdateMexScoutingPriorities, aiBrain)

        SetMaximumFactoryLevels(aiBrain)

        --STATE OF GAME LOG BELOW------------------

        --Check if we need to refresh our mass income
        local bTimeForLongRefresh = false
        local iCurTime = math.floor(GetGameTimeSeconds())
        --if iCurTime >= 913 then M27Utilities.bGlobalDebugOverride = true end --use this if e.g. come across a hard crash and want to figure out what's causing it; will cause every log to be enabled so will take a long time to just run 1s of game time
        if aiBrain[refiTimeOfLastMexIncomeCheck] == nil then bTimeForLongRefresh = true
        elseif iCurTime - aiBrain[refiTimeOfLastMexIncomeCheck] >= iLongTermMassIncomeChangeInterval then bTimeForLongRefresh = true end
        local iMassAtLeast3mAgo = aiBrain[reftiMexIncomePrevCheck][2]
        if iMassAtLeast3mAgo == nil then iMassAtLeast3mAgo = 0 end
        if bTimeForLongRefresh == true then
            table.insert(aiBrain[reftiMexIncomePrevCheck], 1, aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome])
            aiBrain[refiTimeOfLastMexIncomeCheck] = iCurTime
        end


        --Values which want to know even if logs not enabled
        --Get unclaimed mex figures
        local oACU = M27Utilities.GetACU(aiBrain)
        local sPathing = M27UnitInfo.refPathingTypeAmphibious
        local iFaction = aiBrain:GetFactionIndex()

        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == false and not(iFaction == M27UnitInfo.refFactionSeraphim or iFaction == M27UnitInfo.refFactionAeon) then sPathing = M27UnitInfo.refPathingTypeLand end


        --GetSegmentGroupOfTarget(sPathing, iTargetSegmentX, iTargetSegmentZ)
        local iPathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        local iAllMexesInPathingGroup = 0
        if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing][iPathingGroup]) == false then
            iAllMexesInPathingGroup = table.getn(M27MapInfo.tMexByPathingAndGrouping[sPathing][iPathingGroup])
        end
        local iAllUnclaimedMexesInPathingGroup = 0

        local tAllUnclaimedMexesInPathingGroup = M27EngineerOverseer.GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, false, false, true)
        if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInPathingGroup) == false then iAllUnclaimedMexesInPathingGroup = table.getn(tAllUnclaimedMexesInPathingGroup) end
        if bDebugMessages == true then LOG(sFunctionRef..': About to get all mexes in pathing group that we havent claimed') end
        --GetUnclaimedMexes(aiBrain, oPathingUnitBackup, sPathing, iPathingGroup, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
        local tAllMexesInPathingGroupWeHaventClaimed = M27EngineerOverseer.GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, true, false, true)
        local iAllMexesInPathingGroupWeHaventClaimed = 0
        if M27Utilities.IsTableEmpty(tAllMexesInPathingGroupWeHaventClaimed) == false then iAllMexesInPathingGroupWeHaventClaimed = table.getn(tAllMexesInPathingGroupWeHaventClaimed) end
        aiBrain[refiUnclaimedMexesInBasePathingGroup] = iAllMexesInPathingGroupWeHaventClaimed
        aiBrain[refiAllMexesInBasePathingGroup] = iAllMexesInPathingGroup

        local tLandCombatUnits = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryLandCombat, false, true)
        local iLandCombatUnits = 0
        if M27Utilities.IsTableEmpty(tLandCombatUnits) == false then iLandCombatUnits = table.getn(tLandCombatUnits) end



        --Our highest tech level
        UpdateHighestFactoryTechTracker(aiBrain)

        --Want below variables for both the game state table and to decide whether to eco:
        local iMexesNearStart = table.getn(M27MapInfo.tResourceNearStart[aiBrain.M27StartPositionNumber][1])
        local iT3Mexes = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex)
--=========DECIDE ON GRAND STRATEGY
        --Get details on how close friendly units are to enemy
        --(Want to run below regardless as we use the distance to base for other logic)

        local tFriendlyLandCombat = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryLandCombat, false, true)
        --M27Utilities.GetNearestUnit(tUnits, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), aiBrain, false)
        local oNearestFriendlyCombatUnitToEnemyBase = M27Utilities.GetNearestUnit(tFriendlyLandCombat, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), aiBrain, false)
        local tFurthestFriendlyPosition = oNearestFriendlyCombatUnitToEnemyBase:GetPosition()
        local iFurthestFriendlyDistToOurBase = M27Utilities.GetDistanceBetweenPositions(tFurthestFriendlyPosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        local iFurthestFriendlyDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tFurthestFriendlyPosition, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))

        aiBrain[refiPercentageClosestFriendlyFromOurBaseToEnemy] = iFurthestFriendlyDistToOurBase / (iFurthestFriendlyDistToOurBase + iFurthestFriendlyDistToEnemyBase)

        local iPrevStrategy = aiBrain[refiAIBrainCurrentStrategy]
        --Are we in ACU kill mode and want to stay in it (determined b y ACU manager)?
        if aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill and not(aiBrain[refbStopACUKillStrategy]) then --set as part of ACU manager
            --Stick with this strategy
        else
            --Should we be in air dominance mode?
            local bWantAirDominance = false
            --Have we recently scouted the enemy base?
            local iBaseScoutingTime = 20
            local iEnemyGroundAAFactor = 0.1
            if aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance then
                iBaseScoutingTime = aiBrain[M27AirOverseer.refiIntervalEnemyBase] + 30
                iEnemyGroundAAFactor = 0.2
            end
            local iAirSegmentX, iAirSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
            local bEnemyHasEnoughAA = false
            if math.max(iBaseScoutingTime + 30, GetGameTimeSeconds()) - aiBrain[M27AirOverseer.reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][M27AirOverseer.refiLastScouted] <= iBaseScoutingTime then
                if bDebugMessages == true then LOG(sFunctionRef..': Time since last scouted enemy base='..(GetGameTimeSeconds() - aiBrain[M27AirOverseer.reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][M27AirOverseer.refiLastScouted])..'; Scouting interval='..iBaseScoutingTime..'; therefore considering whether to switch to air dominance') end
                --Have we either had no bombers die, or the last bomber was effective?
                if not(aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance) and (M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.refbBombersAreEffective]) == true or aiBrain[M27AirOverseer.refbBombersAreEffective][aiBrain[refiOurHighestAirFactoryTech]] == false) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Bombers have been ineffective at our current tech level so wont try air dominance') end
                    bEnemyHasEnoughAA = true
                else
                    if GetGameTimeSeconds() <= 360 then --first 6m of game - do they have any air at all?
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy highest air threat='..(aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] or 'nil')) end
                        if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] > 0 then
                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy has air units so as early in game dont want air dominance') end
                            bEnemyHasEnoughAA = true
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy air threat='..aiBrain[M27AirOverseer.refiHighestEnemyAirThreat]..'; our air threat='..aiBrain[M27AirOverseer.refiOurMassInAirAA]) end
                        if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] / 0.7 > aiBrain[M27AirOverseer.refiOurMassInAirAA] then
                            if bDebugMessages == true then LOG(sFunctionRef..': Dont want to go for air dominance due to enemy highest ever air threat being >75% of ours') end
                            bEnemyHasEnoughAA = true
                        elseif not(aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance) and aiBrain[M27AirOverseer.refiAirAANeeded] > 0 then
                            if bDebugMessages == true then LOG(sFunctionRef..': Dont want air dominance as still need airAA') end
                            bEnemyHasEnoughAA = true
                        end
                    end
                    if bEnemyHasEnoughAA == false then
                        --Do we have bombers?
                        local tBombers = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryBomber, false, true)
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy doesnt have enough AA, will check we have some bombers alive') end
                        if M27Utilities.IsTableEmpty(tBombers) == true then
                            if bDebugMessages == true then LOG(sFunctionRef..': We dont have any bombers, so dont switch to air dominance yet') end
                            bEnemyHasEnoughAA = true
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy mass in ground AA='..(aiBrain[M27AirOverseer.refiEnemyMassInGroundAA] or 'nil')..'; table size of bombers='..table.getn(tBombers)) end
                            if aiBrain[M27AirOverseer.refiEnemyMassInGroundAA] > 0 and aiBrain[M27AirOverseer.refiEnemyMassInGroundAA] * 10 > M27Logic.GetAirThreatLevel(aiBrain, tBombers, false, false, false, true, false, nil, nil, nil, nil, false) then
                                bEnemyHasEnoughAA = true
                            end
                        end
                    end
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Havent scouted enemy base recently so assuming they have some AA there') end
                bEnemyHasEnoughAA = true
            end

            if bEnemyHasEnoughAA == false then
                --Does enemy have ground AA that is shielded?
                if bDebugMessages == true then LOG(sFunctionRef..': Enemy doesnt have enough AA, checking if they have any AA that is under fixed shields') end
                local tEnemyFixedShields = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedShield, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27AirOverseer.refiMaxScoutRadius], 'Enemy')
                local bHaveAAUnderShield = false
                if M27Utilities.IsTableEmpty(tEnemyFixedShields) == false then
                    local tNearbyGroundAA, iShieldRadius
                    for iShield, oShield in tEnemyFixedShields do
                        if M27UnitInfo.IsUnitValid(oShield) then
                            tNearbyGroundAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, oShield:GetPosition(), oShield:GetBlueprint().Defense.Shield.ShieldSize * 0.5 + 1, 'Enemy')
                            if M27Utilities.IsTableEmpty(tNearbyGroundAA) == false then
                                for iGroundAA, oGroundAA in tNearbyGroundAA do
                                    if M27UnitInfo.IsUnitValid(oGroundAA) then
                                        bHaveAAUnderShield = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': bHaveAAUnderShield='..tostring(bHaveAAUnderShield)) end
                if bHaveAAUnderShield == false then bWantAirDominance = true end
            elseif bDebugMessages == true then LOG(sFunctionRef..': Enemy has enough AA or we have too few bombers so wont switch to air dominance')
            end


            if bWantAirDominance == true then
                if bDebugMessages == true then LOG(sFunctionRef..': Setting strategy as air dominance') end
                aiBrain[refiAIBrainCurrentStrategy] = refStrategyAirDominance
            else
                --Are we protecting the ACU? If so then stay in this mode unless we think ACU is safe
                local bKeepProtectingACU = false
                if aiBrain[refiAIBrainCurrentStrategy] == refStrategyProtectACU then
                    bKeepProtectingACU = true
                    local oACU = M27Utilities.GetACU(aiBrain)
                    --Stop protecting ACU if it has gun upgrade and ok health, or isnt upgrading and has good health, or is near our base
                    if M27Conditions.DoesACUHaveGun(aiBrain, false, oACU) and oACU:GetHealthPercent() >= 0.5 then
                        bKeepProtectingACU = false
                    elseif oACU:GetHealthPercent() >= 0.8 and not(oACU:IsUnitState('Upgrading')) and not(oACU.GetWorkProgress and oACU:GetWorkProgress() > 0 and oACU:GetWorkProgress() < 1) and not(oACU.PlatoonHandle[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionUpgrade) then
                        bKeepProtectingACU = false
                    elseif M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iDistanceFromBaseToBeSafe then
                        bKeepProtectingACU = false
                    elseif oACU[reftACURecentHealth][iCurTime - 30] < oACU[reftACURecentHealth][iCurTime] and M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, oACU:GetPosition(), 50, 'Enemy')) then
                        bKeepProtectingACU = false
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': In protect ACU mode, bKeepProtectingACU='..tostring(bKeepProtectingACU)) end
                end

                --Should we switch to eco?

                local bWantToEco = false
                if bKeepProtectingACU == false then
                    --How far away is the enemy?
                    local bBigEnemyThreat = false
                    if M27Utilities.IsTableEmpty(aiBrain[reftEnemyLandExperimentals]) == false or M27Utilities.IsTableEmpty(aiBrain[reftEnemyArti]) == false then bBigEnemyThreat = true end
                    if bDebugMessages == true then LOG(sFunctionRef..'Not protecting ACU, seeing whether to eco; bBigEnemyTHreat='..tostring(bBigEnemyThreat)..'; aiBrain[refbEnemyACUNearOurs]='..tostring(aiBrain[refbEnemyACUNearOurs])) end





                    --Dont eco if enemy ACU near ours as likely will need backup
                    if aiBrain[refbEnemyACUNearOurs] == false then
                        if aiBrain[M27EconomyOverseer.refiMexesAvailableForUpgrade] > 0 and aiBrain:GetEconomyStoredRatio('MASS') < 0.9 and aiBrain:GetEconomyStoredRatio('MASS') < 12000 then
                            if bBigEnemyThreat == false and aiBrain[refiPercentageOutstandingThreat] > 0.55 and (iAllMexesInPathingGroupWeHaventClaimed <= iAllMexesInPathingGroup * 0.6 or aiBrain[refiDistanceToNearestEnemyBase] >= iDistanceToEnemyEcoThreshold) and not(iT3Mexes >= math.min(iMexesNearStart, 4) and aiBrain[refiOurHighestFactoryTechLevel] >= 3) then
                                if bDebugMessages == true then LOG(sFunctionRef..': No big enemy threats and good defence and mex coverage so will eco') end
                                bWantToEco = true
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Dont want to eco based on initial tests: bBigEnemyThreat='..tostring(bBigEnemyThreat)..'; %threat='..aiBrain[refiPercentageOutstandingThreat]..'; UnclaimedMex%='..iAllMexesInPathingGroupWeHaventClaimed / iAllMexesInPathingGroup..'; EnemyDist='..aiBrain[refiDistanceToNearestEnemyBase]) end
                                --Has our mass income not changed recently, but we dont appear to be losing significantly on the battlefield?
                                if iCurTime > 100 and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] - iMassAtLeast3mAgo < 1 and aiBrain[refiPercentageOutstandingThreat] > 0.55 and iLandCombatUnits >= 30 then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Ok defence coverage and income not changed in a while so will eco') end
                                    bWantToEco = true
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if we are making use of tanks - if not then will switch to eco if have a decent number of tanks. aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons]='..tostring(aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons])) end
                                    if aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons] == false then
                                        --Are sending tanks into an attacknearest platoon so want to eco if we have a significant number of tanks, unless enemy has a big threat
                                        local iMinTanksWanted = math.max(8, 2 * (iAllMexesInPathingGroupWeHaventClaimed - iAllMexesInPathingGroup * 0.6))
                                        if bDebugMessages == true then LOG(sFunctionRef..': iMinTanksWanted='..iMinTanksWanted..'; iLandCombatUnits='..iLandCombatUnits) end
                                        if iLandCombatUnits >= iMinTanksWanted and aiBrain[refiOurHighestFactoryTechLevel] <= 2 and aiBrain[refiModDistFromStartNearestThreat] > aiBrain[refiDistanceToNearestEnemyBase] * 0.4 and aiBrain[refiPercentageOutstandingThreat] > 0.5 then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Dont have tech 3 and/or have 2 combat land units for each unclaimed mex on our side of the map with no big threats and not making use of land factories so will eco') end
                                            bWantToEco = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if bWantToEco == true then
                        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == true and aiBrain[refiPercentageClosestFriendlyFromOurBaseToEnemy] < 0.4 then bWantToEco = false end

                        --Check in case ACU health is low or we dont have any units near enemy (which might be why we think there's no enemy threat)
                        if oACU:GetHealthPercent() < 0.45 then bWantToEco = false end
                    end
                    if bWantToEco == true then
                        aiBrain[M27FactoryOverseer.refiLastPriorityCategoryToBuild] = nil
                        aiBrain[refiAIBrainCurrentStrategy] = refStrategyEcoAndTech
                    else
                        aiBrain[M27FactoryOverseer.refiLastPriorityCategoryToBuild] = M27UnitInfo.refCategoryDFTank
                        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == false and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] == true then aiBrain[M27FactoryOverseer.refiLastPriorityCategoryToBuild] = M27UnitInfo.refCategoryAmphibiousCombat end
                        aiBrain[refiAIBrainCurrentStrategy] = refStrategyLandEarly
                    end
                end

            end
        end

        --Are we no longer protecting the ACU? If so then disband any escort it has - decided to take this out and just rely on acu manager's flag for if ACU needs an escort
        --[[if iPrevStrategy == refStrategyProtectACU and not(aiBrain[refiAIBrainCurrentStrategy] == refStrategyProtectACU) then
            if oACU.PlatoonHandle then
                oACU.PlatoonHandle[M27PlatoonUtilities.refbShouldHaveEscort] = false
                if oACU.PlatoonHandle[M27PlatoonUtilities.refoEscortingPlatoon] then oACU.PlatoonHandle[M27PlatoonUtilities.refoEscortingPlatoon][M27PlatoonUtilities.refiCurrentAction] = M27PlatoonUtilities.refActionDisband end
            end
        end--]]


        --Max target defence coverage for strategy
        if aiBrain[refiAIBrainCurrentStrategy] == refStrategyEcoAndTech then aiBrain[refiMaxDefenceCoverageWanted] = 0.65
        elseif aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance then aiBrain[refiMaxDefenceCoverageWanted] = 0.4
        else aiBrain[refiMaxDefenceCoverageWanted] = 0.9 end


        --Reduce air scouting threshold for enemy base if likely to be considering whether to build a nuke or not
        if aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 7 and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 250 and aiBrain[refiOurHighestFactoryTechLevel] >= 3 and (not(aiBrain[M27EngineerOverseer.refiLastExperimentalCategory]) or aiBrain[M27EngineerOverseer.refiLastExperimentalCategory] == M27UnitInfo.refCategorySML) then
            local iAirSegmentX, iAirSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
            aiBrain[M27AirOverseer.reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][M27AirOverseer.refiCurrentScoutingInterval] = math.min(45, aiBrain[M27AirOverseer.reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][M27AirOverseer.refiCurrentScoutingInterval])
        end



        --Get key values relating to game state (for now only done if debugmessages, but coudl move some to outside of debugmessages)
        if M27Config.M27StrategicLog == true then
            local tsGameState = {}
            local tTempUnitList, iTempUnitCount

            tsGameState['CurTimeInSecondsRounded'] = iCurTime

            --Player
            tsGameState['Start position'] = aiBrain.M27StartPositionNumber

            --Grand Strategy
            tsGameState[refiAIBrainCurrentStrategy] = aiBrain[refiAIBrainCurrentStrategy]

            --Economy:
            tsGameState['iMassGrossIncome'] = aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]
            tsGameState['iMassNetIncome'] = aiBrain:GetEconomyTrend('MASS')
            tsGameState['iEnergyNetIncome'] = aiBrain:GetEconomyTrend('ENERGY')
            tsGameState['iMassStored'] = aiBrain:GetEconomyStored('MASS')
            tsGameState['iEnergyStored'] = aiBrain:GetEconomyStored('ENERGY')
            tsGameState['PausedUpgrades'] = aiBrain[M27EconomyOverseer.refiPausedUpgradeCount]
            tsGameState['PowerStall active'] = tostring(aiBrain[M27EconomyOverseer.refbStallingEnergy])


            --Key unit counts:
            tTempUnitList = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryLandFactory, false, true)
            iTempUnitCount = 0
            if M27Utilities.IsTableEmpty(tTempUnitList) == false then iTempUnitCount = table.getn(tTempUnitList) end
            tsGameState['iLandFactories'] = iTempUnitCount

            tsGameState['Highest factory tech level'] = aiBrain[refiOurHighestFactoryTechLevel]

            tTempUnitList = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryEngineer, false, true)
            iTempUnitCount = 0
            if M27Utilities.IsTableEmpty(tTempUnitList) == false then iTempUnitCount = table.getn(tTempUnitList) end
            tsGameState['iEngineers'] = iTempUnitCount


            tsGameState['iLandCombatUnits'] = iTempUnitCount

            --Build orders: Engineers wanted
            tsGameState['InitialEngisShortfall'] = aiBrain[M27EngineerOverseer.refiBOInitialEngineersWanted]
            tsGameState['PreReclaimEngisWanted'] = aiBrain[M27EngineerOverseer.refiBOPreReclaimEngineersWanted]
            tsGameState['refiBOPreSpareEngineersWanted'] = aiBrain[M27EngineerOverseer.refiBOPreSpareEngineersWanted]
            tsGameState['refiBOActiveSpareEngineers'] = aiBrain[M27EngineerOverseer.refiBOActiveSpareEngineers]
            tsGameState['SpareEngisByTechLevel'] = aiBrain[M27EngineerOverseer.refiBOActiveSpareEngineers]
            --MAA wanted:
            tsGameState['MAAShortfallACUPrecaution'] = aiBrain[refiMAAShortfallACUPrecaution]
            tsGameState['MAAShortfallACUCore'] = aiBrain[refiMAAShortfallACUCore]
            tsGameState['MAAShortfallLargePlatoons'] = aiBrain[refiMAAShortfallLargePlatoons]
            tsGameState['MAAShortfallBase'] = aiBrain[refiMAAShortfallBase]

            --Scouts wanted:
            tsGameState['ScoutShortfallInitialRaider'] = aiBrain[refiScoutShortfallInitialRaider]
            tsGameState['ScoutShortfallACU'] = aiBrain[refiScoutShortfallACU]
            tsGameState['ScoutShortfallIntelLine'] = aiBrain[refiScoutShortfallIntelLine]
            tsGameState['ScoutShortfallLargePlatoons'] = aiBrain[refiScoutShortfallLargePlatoons]
            tsGameState['ScoutShortfallAllPlatoons'] = aiBrain[refiScoutShortfallAllPlatoons]

            --Air:
            tsGameState['AirAANeeded'] = aiBrain[M27AirOverseer.refiAirAANeeded]
            tsGameState['AirAAWanted'] = aiBrain[M27AirOverseer.refiAirAAWanted]
            tsGameState['OurMassInAirAA'] = aiBrain[M27AirOverseer.refiOurMassInAirAA]
            local iAvailableAirAA = 0
            if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableAirAA]) == false then for iUnit, oUnit in aiBrain[M27AirOverseer.reftAvailableAirAA] do iAvailableAirAA = iAvailableAirAA + 1 end end
            tsGameState['AvailableAirAA'] = iAvailableAirAA
            tsGameState['AvailableBombers'] = 0

            if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableBombers]) == false then tsGameState['AvailableBombers'] = table.getn(aiBrain[M27AirOverseer.reftAvailableBombers]) end
            tsGameState['RemainingBomberTargets'] = 0
            if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftBomberTargetShortlist]) == false then tsGameState['RemainingBomberTargets'] = table.getn(aiBrain[M27AirOverseer.reftBomberTargetShortlist]) end
            tsGameState['TorpBombersWanted'] = aiBrain[M27AirOverseer.refiTorpBombersWanted]

                --Factories wanted
            tsGameState['WantMoreLandFactories'] = tostring(aiBrain[M27EconomyOverseer.refbWantMoreFactories])

            --Mobile shields
            tsGameState['WantMoreMobileSHields'] = tostring(aiBrain[M27PlatoonFormer.refbUsingMobileShieldsForPlatoons])

            --Threat values:
            --Intel path % to enemy
            if aiBrain[refiCurIntelLineTarget] then
                local iIntelPathPosition = aiBrain[refiCurIntelLineTarget]
                local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                --reftIntelLinePositions = 'M27IntelLinePositions' --x = line; y = point on that line, returns position
                local tIntelPathCurBase = aiBrain[reftIntelLinePositions][iIntelPathPosition][1]
                local iIntelDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tIntelPathCurBase, tStartPosition)
                local iIntelDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tIntelPathCurBase, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                tsGameState['iIntelPathPosition'] = iIntelPathPosition
                tsGameState['iIntelDistancePercent'] = iIntelDistanceToStart / (iIntelDistanceToStart + iIntelDistanceToEnemy)
            end
            if aiBrain[refiModDistFromStartNearestOutstandingThreat] then tsGameState['NearestOutstandingThreat'] = aiBrain[refiModDistFromStartNearestOutstandingThreat] end
            if aiBrain[refiPercentageOutstandingThreat] then tsGameState['PercentageOutstandingThreat'] = aiBrain[refiPercentageOutstandingThreat] end
            tsGameState['PercentDistOfOurUnitClosestToEnemyBase'] = (aiBrain[refiPercentageClosestFriendlyFromOurBaseToEnemy] or 'nil')

            if aiBrain[M27AirOverseer.refiOurMassInMAA] then tsGameState['OurMAAThreat'] = aiBrain[M27AirOverseer.refiOurMassInMAA] end
            if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] then tsGameState['EnemyAirThreat'] = aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] end
            tsGameState['EmergencyMAANeeded'] = aiBrain[refbEmergencyMAANeeded]

            --Get other unclaimed mex details
            local iUnclaimedMexesOnOurSideOfMap = 0
            local iUnclaimedMexesWithinDefenceCoverage = 0
            local iUnclaimedMexesWithinIntelAndDefence = 0
            if iAllUnclaimedMexesInPathingGroup > 0 then

                local tUnclaimedMexesOnOurSideOfMap = M27EngineerOverseer.FilterLocationsBasedOnDistanceToEnemy(aiBrain, tAllUnclaimedMexesInPathingGroup, 0.5)
                if M27Utilities.IsTableEmpty(tUnclaimedMexesOnOurSideOfMap) == false then iUnclaimedMexesOnOurSideOfMap = table.getn(tUnclaimedMexesOnOurSideOfMap) end
                local tUnclaimedMexesWithinDefenceCoverage = M27EngineerOverseer.FilterLocationsBasedOnDefenceCoverage(aiBrain, tAllUnclaimedMexesInPathingGroup, false)
                if M27Utilities.IsTableEmpty(tUnclaimedMexesWithinDefenceCoverage) == false then iUnclaimedMexesWithinDefenceCoverage = table.getn(tUnclaimedMexesWithinDefenceCoverage) end
                local tUncalimedMexesWithinIntelAndDefence = M27EngineerOverseer.FilterLocationsBasedOnDefenceCoverage(aiBrain, tAllUnclaimedMexesInPathingGroup, true)
                if M27Utilities.IsTableEmpty(tUncalimedMexesWithinIntelAndDefence) == false then iUnclaimedMexesWithinIntelAndDefence = table.getn(tUncalimedMexesWithinIntelAndDefence) end
            end
            tsGameState['AllMexesInACUPathingGroup'] = iAllMexesInPathingGroup
            tsGameState['AllMexesInPathingGroupWeHaventClaimed'] = iAllMexesInPathingGroupWeHaventClaimed
            tsGameState['UnclaimedUnqueuedMexesByAnyoneInACUPathingGroup'] = iAllUnclaimedMexesInPathingGroup
            tsGameState['UnclaimedMexesOnOurSideOfMap'] = iUnclaimedMexesOnOurSideOfMap
            tsGameState['UnclaimedMexesWithinDefenceCoverage'] = iUnclaimedMexesWithinDefenceCoverage
            tsGameState['UnclaimedMexesWithinIntelAndDefence'] = iUnclaimedMexesWithinIntelAndDefence
            tsGameState['MexesNearBase'] = iMexesNearStart
            tsGameState['T3MexesOwned'] = iT3Mexes
            tsGameState['MexesUpgrading'] = aiBrain[M27EconomyOverseer.refiMexesUpgrading]


            --Air:
            tsGameState['BomberEffectiveness'] = aiBrain[M27AirOverseer.refbBombersAreEffective]


            LOG(repr(tsGameState))
        end

        aiBrain[refiACUHealthToRunOn] = math.max(5250, oACU:GetMaxHealth() * 0.45)
        if iAllMexesInPathingGroupWeHaventClaimed <= iAllMexesInPathingGroup * 0.5 then
            if M27Conditions.DoesACUHaveGun(aiBrain, false) then aiBrain[refiACUHealthToRunOn] = math.max(8000, oACU:GetMaxHealth() * 0.7)
            else
                --ACU doesnt have gun so be very careful
                aiBrain[refiACUHealthToRunOn] = math.max(9000, oACU:GetMaxHealth() * 0.8)
            end
        end --We have majority of mexes so play safe with ACU
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function InitiateLandFactoryConstructionManager(aiBrain)
    --Creates monitor for what land factories should build
    ForkThread(M27FactoryOverseer.SetPreferredUnitsByCategory, aiBrain)
    ForkThread(M27FactoryOverseer.FactoryOverseer, aiBrain)
end

function InitiateEngineerManager(aiBrain)
    WaitTicks(3)
    ForkThread(M27EngineerOverseer.EngineerManager, aiBrain)
end

function InitiateUpgradeManager(aiBrain)
    ForkThread(M27EconomyOverseer.UpgradeManager, aiBrain)
end

function SwitchSoMexesAreNeverIgnored(aiBrain, iDelayInSeconds)
    --Initially want raiders to hunt engis, after a set time want to switch to attack mexes even if few units in platoon
    WaitSeconds(iDelayInSeconds)
    aiBrain[refiIgnoreMexesUntilThisManyUnits] = 0
end

function RecordAllEnemiesAndAllies(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordAllEnemiesAndAllies'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of attempt to get backup list of enemies, called for brain with armyindex='..aiBrain:GetArmyIndex()..'; will wait 5 seconds first') end
    WaitSeconds(5)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Finished waiting 1s for brain with armyindex='..aiBrain:GetArmyIndex()..'; will proceed with updating enemy and ally list') end
    local iOurIndex = aiBrain:GetArmyIndex()
    local iEnemyCount = 0
    local iAllyCount = 0
    local iArmyIndex
    if M27Utilities.IsTableEmpty(ArmyBrains) == false then
        aiBrain[toEnemyBrains] = {}
        aiBrain[toAllyBrains] = {}
        for iCurBrain, oBrain in ArmyBrains do
            if bDebugMessages == true then LOG(sFunctionRef..': Considering whether brain with armyindex ='..oBrain:GetArmyIndex()..' is defeated and is enemy or ally') end
            if not(oBrain:IsDefeated()) then
                --if not(oBrain:IsDefeated()) and not(oBrain.M27IsDefeated) then
                if bDebugMessages == true then LOG(sFunctionRef..': Brain isnt defeated') end
                iArmyIndex = oBrain:GetArmyIndex()
                tAllAIBrainsByArmyIndex[iArmyIndex] = oBrain
                if IsEnemy(iOurIndex, oBrain:GetArmyIndex()) and not(M27Logic.IsCivilianBrain(oBrain)) then
                    iEnemyCount = iEnemyCount + 1
                    aiBrain[toEnemyBrains][iArmyIndex] = oBrain
                    if bDebugMessages == true then LOG(sFunctionRef..': aiBrain Index='..aiBrain:GetArmyIndex()..'; enemy index='..iArmyIndex..'; recording as an enemy; start position number='..oBrain.M27StartPositionNumber..'; start position='..repr(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber])) end
                elseif IsAlly(iOurIndex, oBrain:GetArmyIndex()) and not(oBrain == aiBrain) then
                    iAllyCount = iAllyCount + 1
                    aiBrain[toAllyBrains][iArmyIndex] = oBrain
                    if bDebugMessages == true then LOG(sFunctionRef..': Added brain with army index='..iArmyIndex..' as an ally for the brain with an army index '..aiBrain:GetArmyIndex()) end
                end
                if oBrain.M27StartPositionNumber then
                    M27MapInfo.UpdateNewPrimaryBaseLocation(oBrain)
                end
            elseif bDebugMessages == true then LOG(sFunctionRef..': Brain is defeated')
            end
        end
        iPlayersAtGameStart = iAllyCount + iEnemyCount
    else
        for iCurBrain, oBrain in tAllAIBrainsByArmyIndex do
            if IsEnemy(iOurIndex, oBrain:GetArmyIndex()) then
                iEnemyCount = iEnemyCount + 1
                aiBrain[toEnemyBrains][oBrain:GetArmyIndex()] = oBrain
                if bDebugMessages == true then LOG(sFunctionRef..': aiBrain Index='..aiBrain:GetArmyIndex()..'; enemy index='..iArmyIndex..'; recording as an enemy; start position number='..oBrain.M27StartPositionNumber..'; start position='..repr(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber])) end
            elseif IsAlly(iOurIndex, oBrain:GetArmyIndex()) and not(oBrain == aiBrain) then
                iAllyCount = iAllyCount + 1
                aiBrain[toAllyBrains][iArmyIndex] = oBrain
            end
            if oBrain.M27StartPositionNumber then
                M27MapInfo.UpdateNewPrimaryBaseLocation(oBrain)
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RefreshMexPositions(aiBrain)
    WaitTicks(80)
    --Force refresh of mexes to try and fix bug where not all mexes recorded as being pathable
    --M27MapInfo.RecheckPathingToMexes(aiBrain)
    ForkThread(M27MapInfo.RecordMexForPathingGroup)

    --Create sorted listing of mexes
    ForkThread(M27MapInfo.RecordSortedMexesInOriginalPathingGroup, aiBrain)
    --[[WaitTicks(400)
    ForkThread(M27MapInfo.RecordMexForPathingGroup, M27Utilities.GetACU(aiBrain), true)
    ForkThread(M27MapInfo.RecordSortedMexesInOriginalPathingGroup, aiBrain)--]]
end

function ACUInitialisation(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ACUInitialisation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local oACU = M27Utilities.GetACU(aiBrain)
    oACU[refbACUOnInitialBuildOrder] = true
    local iCategoryToBuild = M27UnitInfo.refCategoryLandFactory
    local iMaxAreaToSearch = 14
    local iCategoryToBuildBy = M27UnitInfo.refCategoryT1Mex
    M27EngineerOverseer.BuildStructureAtLocation(aiBrain, oACU, iCategoryToBuild, iMaxAreaToSearch, iCategoryToBuildBy, nil)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    while aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllFactories) == 0 do
        WaitTicks(1)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Have a factory unit now, so will set ACU platoon to use ACUMain') end


    local oNewPlatoon = aiBrain:MakePlatoon('', '')
    aiBrain:AssignUnitsToPlatoon(oNewPlatoon, {oACU}, 'Support', 'None')
    oNewPlatoon:SetAIPlan('M27ACUMain')
    oACU[refbACUOnInitialBuildOrder] = false
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RevealCiviliansToAI(aiBrain)
    --On some maps like burial mounds civilians are revealed to human players but not AI; meanwhile on other maps even if theyre not revealed to humans, the humans will likely know where the buildings are having played the map before
    --Thanks to Relent0r for providing code that achieved this

    local iOurIndex = aiBrain:GetArmyIndex()
    local iBrainIndex
    local sRealState
    for i,v in ArmyBrains do
        iBrainIndex = v:GetArmyIndex()
        if ArmyIsCivilian(iBrainIndex) then
            sRealState = IsAlly(iOurIndex, iBrainIndex) and 'Ally' or IsEnemy(iOurIndex, iBrainIndex) and 'Enemy' or 'Neutral'
            SetAlliance(iOurIndex, iBrainIndex, 'Ally')
            WaitTicks(5)
            SetAlliance(iOurIndex, iBrainIndex, sRealState)
        end
    end
end

function OverseerInitialisation(aiBrain)
    --Below may get overwritten by later functions - this is just so we have a default/non nil value
    local sFunctionRef = 'OverseerInitialisation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Config settings
    if ScenarioInfo.Options.AIPLatoonNameDebug == 'all' then M27Config.M27ShowUnitNames = true end

    aiBrain[refiSearchRangeForEnemyStructures] = 36 --T1 PD has range of 26, want more than this
    aiBrain[refbEnemyHasTech2PD] = false
    aiBrain[refbNeedScoutPlatoons] = false
    aiBrain[refbNeedDefenders] = false
    aiBrain[refiInitialRaiderPlatoonsWanted] = 2
    aiBrain[refbIntelPathsGenerated] = false
    aiBrain[refbConfirmedInitialRaidersHaveScouts] = false

    --Intel BO related:
    aiBrain[refiScoutShortfallInitialRaider] = 1
    aiBrain[refiScoutShortfallACU] = 1
    aiBrain[refiScoutShortfallPriority] = 1
    aiBrain[refiScoutShortfallIntelLine] = 1
    aiBrain[refiScoutShortfallLargePlatoons] = 1
    aiBrain[refiScoutShortfallAllPlatoons] = 1
    aiBrain[refiMAAShortfallACUPrecaution] = 1
    aiBrain[refiMAAShortfallACUCore] = 0
    aiBrain[refiMAAShortfallLargePlatoons] = 0
    aiBrain[refiMAAShortfallBase] = 0
    aiBrain[reftiMaxFactoryByType] = {1,1,0}
    aiBrain[refiMinLandFactoryBeforeOtherTypes] = 2

    --Scout related - other
    aiBrain[tScoutAssignedToMexLocation] = {}


    aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = 4
    aiBrain[M27FactoryOverseer.refiEngineerCap] = 70 --Max engis of any 1 tech level even if have spare mass (note will manually increase for tech3)
    aiBrain[M27FactoryOverseer.refiDFCap] = 150 --Max direct fire units of any 1 tech level
    aiBrain[M27FactoryOverseer.refiIndirectCap] = 150 --Max indirect fire units of any 1 tech level
    aiBrain[M27FactoryOverseer.refiMAACap] = 150 --Max MAA of any 1 tech level
    aiBrain[M27FactoryOverseer.reftiEngineerLowMassCap] = {35, 20, 20, 20} --Max engis to get if have low mass
    aiBrain[M27FactoryOverseer.refiMinimumTanksWanted] = 5
    aiBrain[M27FactoryOverseer.refiAirAACap] = 250
    aiBrain[M27FactoryOverseer.refiAirScoutCap] = 35

    aiBrain[M27PlatoonFormer.refbUsingMobileShieldsForPlatoons] = true
    aiBrain[refiCyclesThatACUHasNoPlatoon] = 0
    aiBrain[refiCyclesThatACUInArmyPool] = 0
    aiBrain[reftUnitGroupPreviousReferences] = {}

    aiBrain[refiOurHighestFactoryTechLevel] = 1
    aiBrain[refiOurHighestAirFactoryTech] = 1

    aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons] = true

    aiBrain[refiIgnoreMexesUntilThisManyUnits] = 3 --Platoons wont attack lone structures if fewer than this many units (initially)

    --ACU specific
    local oACU = M27Utilities.GetACU(aiBrain)
    oACU[refbACUHelpWanted] = false
    aiBrain[refbEnemyACUNearOurs] = false


    --Grand strategy:
    aiBrain[refiAIBrainCurrentStrategy] = refStrategyLandEarly
    aiBrain[reftiMexIncomePrevCheck] = {}
    aiBrain[reftiMexIncomePrevCheck][1] = 0
    aiBrain[reftEnemyNukeLaunchers] = {}
    aiBrain[reftEnemyLandExperimentals] = {}
    aiBrain[reftEnemyTML] = {}
    aiBrain[reftEnemyArti] = {}
    aiBrain[refbEnemyTMLSightedBefore] = false
    aiBrain[refbStopACUKillStrategy] = false

    --Nearest enemy and ACU and threat
    aiBrain[toEnemyBrains] = {}
    aiBrain[toAllyBrains] = {}
    iPreviousNearestEnemyIndex = M27Logic.GetNearestEnemyIndex(aiBrain, false)
    aiBrain[refiDistanceToNearestEnemyBase] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[M27Logic.IndexToStartNumber(iPreviousNearestEnemyIndex)])
    aiBrain[reftLastNearestACU] = M27MapInfo.PlayerStartPoints[M27Logic.IndexToStartNumber(iPreviousNearestEnemyIndex)]
    aiBrain[refoLastNearestACU] = M27Utilities.GetACU(tAllAIBrainsByArmyIndex[iPreviousNearestEnemyIndex])
    aiBrain[refiLastNearestACUDistance] = M27Utilities.GetDistanceBetweenPositions(aiBrain[reftLastNearestACU], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])

    aiBrain[refiPercentageOutstandingThreat] = 0.5
    aiBrain[refiPercentageClosestFriendlyFromOurBaseToEnemy] = 0.5
    aiBrain[refiModDistFromStartNearestOutstandingThreat] = 1000
    aiBrain[refiModDistFromStartNearestThreat] = 1000
    aiBrain[reftLocationFromStartNearestThreat] = {0,0,0}
    aiBrain[refiEnemyHighestTechLevel] = 1


    M27MapInfo.SetWhetherCanPathToEnemy(aiBrain)

    ForkThread(M27Utilities.ProfilerActualTimePerTick)
    InitiateLandFactoryConstructionManager(aiBrain)

    ForkThread(InitiateEngineerManager, aiBrain)
    WaitTicksSpecial(aiBrain, 1)

    InitiateUpgradeManager(aiBrain)
    WaitTicksSpecial(aiBrain, 1)
    ForkThread(M27PlatoonFormer.PlatoonIdleUnitOverseer, aiBrain)
    WaitTicksSpecial(aiBrain, 1)

    ForkThread(SwitchSoMexesAreNeverIgnored, aiBrain, 210) --e.g. on theta passage around the 3m mark raiders might still be coming across engis, so this gives extra 30s of engi hunting time

    ForkThread(RecordAllEnemiesAndAllies, aiBrain)

    ForkThread(RefreshMexPositions, aiBrain)

    ForkThread(M27AirOverseer.SetupAirOverseer, aiBrain)

    ForkThread(M27MapInfo.RecordStartingPathingGroups, aiBrain)

    ForkThread(ACUInitialisation, aiBrain) --Gets ACU to build its first building and then form ACUMain platoon once its done

    ForkThread(RevealCiviliansToAI, aiBrain)

    ForkThread(M27Logic.DetermineEnemyScoutSpeed, aiBrain) --Will figure out the speed of scouts (except seraphim)

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

--[[function ArmyPoolContainsLandFacTest(aiBrain)
    local sFunctionRef = 'ArmyPoolContainsLandFacTest'
    local oArmyPool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local tPoolUnits = oArmyPool:GetPlatoonUnits()
    if tPoolUnits then
        LOG(sFunctionRef..': Army pool has '..table.getn(tPoolUnits)..' units in it')
        local tStructures = EntityCategoryFilterDown(categories.STRUCTURE, tPoolUnits)
        if M27Utilities.IsTableEmpty(tStructures) == false then
            LOG(sFunctionRef..': Army pool has '..table.getn(tStructures)..' structures in it')
        end
    else LOG(sFunctionRef..': Army pool is empty')
    end

end--]]

--[[function EmptyTableTest()
    local tEmpty1 = {}
    local tEmpty2 = {{}}
    local tEmpty3 = {{{}}}
    local tNotEmpty1 = {1}
    local tNotEmpty2 = {{1}}
    local tNotEmpty3 = {{{1}}}
    local tNotEmpty4 = {{{},{1}}}

    local tAllTables = {tEmpty1, tEmpty2, tEmpty3, tNotEmpty1, tNotEmpty2, tNotEmpty3, tNotEmpty4}
    for iTable, tTable in tAllTables do
       LOG('TemptyTableTest: iTable='..iTable..': tTable='..repr(tTable)..'; IsTableEmpty='..tostring(M27Utilities.IsTableEmpty(tTable)))
    end

    M27Utilities.ErrorHandler('For testing only')
end--]]


--[[
function TestLoopWithinLoop1(iStart, iTrackerCount)
    if tTEMPTEST[iStart] == nil then
        tTEMPTEST[iStart] = iStart
        for i = 1, 5000 do
            ForkThread(TestLoopWithinLoop1, i, iTrackerCount)
        end
    end
end

function RunLotsOfLoopsPreStart()
    WaitTicks(5)
    TestLoopWithinLoop1(1, 1)
end

function Tester()
    ForkThread(RunLotsOfLoopsPreStart)
    WaitTicks(10)
    LOG('TEMPTEST REPR after 10 ticks='..repr(tTEMPTEST))
end--]]
function TEMPUNITPOSITIONLOG(aiBrain)
    local tAllUnits = aiBrain:GetListOfUnits(categories.ALLUNITS - categories.COMMAND, false, true)
    local iSegmentX, iSegmentZ
    local tPosition
    if M27Utilities.IsTableEmpty(tAllUnits) == false then
        for iUnit, oUnit in tAllUnits do
            tPosition = oUnit:GetPosition()
            LOG('TEMPUNITPOSITIONLOG: iUnit='..iUnit..'; oUnit='..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; postiion='..repr(oUnit:GetPosition()))
            iSegmentX, iSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tPosition)
            LOG('Segment position X-Z='..iSegmentX..'-'..iSegmentZ..'; TerrainHeight='..GetTerrainHeight(tPosition[1], tPosition[3])..'; Surface height='..GetSurfaceHeight(tPosition[1], tPosition[3]))
        end
    end
end

function TempEnemyACUDirection(aiBrain)
    while aiBrain do
        WaitTicks(1)
        local tAllACUs = EntityCategoryFilterDown(categories.COMMAND, GetUnitsInRect(Rect(0, 0, 1000, 1000)))
        local oEnemyACU
        for iACU, oACU in tAllACUs do
            if IsEnemy(aiBrain:GetArmyIndex(), oACU:GetAIBrain():GetArmyIndex()) then
                oEnemyACU = oACU
            end
        end
        local sBone = 'Left_Foot'
        --LOG('Position of Left foot='..repr(oEnemyACU:GetPosition(sBone)))
        LOG('ACU orientation='..repr(oEnemyACU:GetOrientation()))
        LOG('ACU Heading='..repr(oEnemyACU:GetHeading()))
        LOG('ACU Angle direction='..M27UnitInfo.GetUnitFacingAngle(oEnemyACU))
        LOG('ACU position='..repr(oEnemyACU:GetPosition()))
    end
end

function TestNewMovementCommands(aiBrain)
    local tOurStart = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    local tEnemyStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
    local iDistBetweenBases = M27Utilities.GetDistanceBetweenPositions(tOurStart, tEnemyStartPosition)
    LOG('Our start pos='..repr(tOurStart)..'; Enemy start pos='..repr(tEnemyStartPosition)..'; OurACUPos='..repr(M27Utilities.GetACU(aiBrain):GetPosition())..'; Distance between start points='..iDistBetweenBases)
    local tMapMidPointMethod1 = M27Utilities.MoveTowardsTarget(tOurStart, tEnemyStartPosition, iDistBetweenBases * 0.5, 0)
    local iAngle = M27Utilities.GetAngleFromAToB(tOurStart, tEnemyStartPosition)
    local tMapMidPointMethod2 = M27Utilities.MoveInDirection(tOurStart, iAngle, iDistBetweenBases * 0.5)

    LOG('tMapMidPointMethod1='..repr(tMapMidPointMethod1)..'; tMapMidPointMethod2='..repr(tMapMidPointMethod2))
end

function TestCustom(aiBrain)
    --List out all experimental unit BPs
    --[[
    for iUnit, oUnit in aiBrain:GetListOfUnits(categories.EXPERIMENTAL, false, true) do
        LOG('Experimental='..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit))
    end
    LOG('About to print out blueprint for unit xsl04021')
    LOG(repr(__blueprints['xsl0402']))
    LOG('About to print out categories')
    LOG(repr(__blueprints['xsl04021'].Categories))
    for iCat, sCat in __blueprints['xsl0402'].Categories do
       LOG('iCat='..iCat..'; sCat='..sCat)
    end--]]


    --Draw a circle (new logic)
    --M27Utilities.DrawLocation(M27Utilities.GetACU(aiBrain):GetPosition(), nil, 4, 100)
    --Locate Zthue with LC 35
    --[[local tT1Arti = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryIndirect * categories.TECH1, false, true)
    if M27Utilities.IsTableEmpty(tT1Arti) == false then
       for iArti, oArti in tT1Arti do
          if M27UnitInfo.IsUnitValid(oArti) and M27UnitInfo.GetUnitLifetimeCount(oArti) == 34 then
              LOG('Located T1 arti with LC=34; UnitState='..M27Logic.GetUnitState(oArti))
              if oArti.PlatoonHandle then LOG('Has platoon handle with plan and count='..oArti.PlatoonHandle:GetPlan()..oArti.PlatoonHandle[M27PlatoonUtilities.refiPlatoonCount]..'; PlatoonUC='..oArti.PlatoonHandle[M27PlatoonUtilities.refiPlatoonUniqueCount]..'; Shoudl the platoon have an active cycler='..tostring(oArti.PlatoonHandle[M27PlatoonUtilities.refbPlatoonLogicActive]))
              else LOG('Doesnt have a platoon handle')
              end
          end
       end
    end--]]
end



function OverseerManager(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OverseerManager'



    --[[ForkThread(RunLotsOfLoopsPreStart)
    WaitTicks(10)
    LOG('TEMPTEST REPR after 10 ticks='..repr(tTEMPTEST))--]]
    ForkThread(M27MapInfo.MappingInitialisation, aiBrain)

    if bDebugMessages == true then LOG(sFunctionRef..': Pre fork thread of player start locations') end
    ForkThread(M27MapInfo.RecordPlayerStartLocations, aiBrain)
    --ForkThread(M27MapInfo.RecordResourceLocations, aiBrain) --need to do after 1 tick for adaptive maps - superceded by hook into siminit
    if bDebugMessages == true then LOG(sFunctionRef..': aiBrain:GetArmyIndex()='..aiBrain:GetArmyIndex()..'; aiBrain start position='..(aiBrain.M27StartPositionNumber or 'nil')) end
    ForkThread(M27MapInfo.RecordMexNearStartPosition, aiBrain.M27StartPositionNumber, 26) --similar to the range of T1 PD


    if M27Config.M27ShowPathingGraphically == true then
        ForkThread(M27MapInfo.DrawAllMapPathing, aiBrain)
        --if bDebugMessages == true then DrawWater() end
        --ForkThread(M27MapInfo.DrawHeightMapAstro)
        --ForkThread(M27MapInfo.LogMapTerrainTypes)
    end

    if bDebugMessages == true then LOG(sFunctionRef..': Pre wait 10 ticks') end

    WaitTicks(10)

    --Hopefully have ACU now so can re-check pathing
    --if bDebugMessages == true then LOG(sFunctionRef..': About to check pathing to mexes') end
    --ForkThread(M27MapInfo.RecheckPathingToMexes, aiBrain) --Note that this includes waitticks, so dont make any big decisions on the map until it has finished

    if bDebugMessages == true then LOG(sFunctionRef..': Post wait 10 ticks') end
    OverseerInitialisation(aiBrain) --sets default values for variables, and starts the factory construction manager

    if bDebugMessages == true then LOG(sFunctionRef..': Pre record resource locations fork thread') end

    local iSlowerCycleThreshold = 10
    local iSlowerCycleCount = 0

    --ForkThread(TempEnemyACUDirection, aiBrain)
    if M27Config.M27ShowPathingGraphically then M27MapInfo.TempCanPathToEveryMex(M27Utilities.GetACU(aiBrain)) end
    ForkThread(DetermineInitialBuildOrder, aiBrain)
    local iTempProfiling
    --TestCustom(aiBrain)

    --ForkThread(M27MiscProfiling.LocalVariableImpact)




    while(not(aiBrain:IsDefeated())) do
        --if GetGameTimeSeconds() >= 954 and GetGameTimeSeconds() <= 1000 then M27Utilities.bGlobalDebugOverride = true else M27Utilities.bGlobalDebugOverride = false end
        if aiBrain.M27IsDefeated then break end

        --ForkThread(TestNewMovementCommands, aiBrain)

        if bDebugMessages == true then
            LOG(sFunctionRef..': Start of cycle')
            --ForkThread(TEMPUNITPOSITIONLOG, aiBrain)

            --ArmyPoolContainsLandFacTest(aiBrain)
          --M27EngineerOverseer.TEMPTEST(aiBrain)
        end


        if bDebugMessages == true then
            LOG(sFunctionRef..': refbIntelPathsGenerated='..tostring(aiBrain[refbIntelPathsGenerated]))
            --ArmyPoolContainsLandFacTest(aiBrain)
        end
        if aiBrain[refbIntelPathsGenerated] == false then
            ForkThread(RecordIntelPaths, aiBrain)
        end
        if aiBrain[refbIntelPathsGenerated] == true then
            ForkThread(AssignScoutsToPreferredPlatoons, aiBrain)
        end
        if bDebugMessages == true then
            --ArmyPoolContainsLandFacTest(aiBrain)
          --M27EngineerOverseer.TEMPTEST(aiBrain)
        end
        if not(WaitTicksSpecial(aiBrain, 1)) then break end
        ForkThread(AssignMAAToPreferredPlatoons, aiBrain) --No point running logic for MAA helpers if havent created any scouts
        if bDebugMessages == true then
            LOG(sFunctionRef..': pre threat assessment')
            --ArmyPoolContainsLandFacTest(aiBrain)
          --M27EngineerOverseer.TEMPTEST(aiBrain)
            DebugPrintACUPlatoon(aiBrain)
        end

        if not(WaitTicksSpecial(aiBrain, 1)) then break end
        ForkThread(ThreatAssessAndRespond, aiBrain)
        --if bDebugMessages == true then ArmyPoolContainsLandFacTest(aiBrain) end

        if bDebugMessages == true then
            LOG(sFunctionRef..': post threat assessment pre ACU manager')
            --ArmyPoolContainsLandFacTest(aiBrain)
          --M27EngineerOverseer.TEMPTEST(aiBrain)
        end

        if not(WaitTicksSpecial(aiBrain, 1)) then break end
        ForkThread(ACUManager, aiBrain)
        if bDebugMessages == true then
            LOG(sFunctionRef..': post ACU manager, pre wait 10 ticks')
            DebugPrintACUPlatoon(aiBrain)
            --ArmyPoolContainsLandFacTest(aiBrain)
          --M27EngineerOverseer.TEMPTEST(aiBrain)
        end

        if bDebugMessages == true then
            LOG(sFunctionRef..': Waited 1 tick; platoon name is:') DebugPrintACUPlatoon(aiBrain)
            --ArmyPoolContainsLandFacTest(aiBrain)
          --M27EngineerOverseer.TEMPTEST(aiBrain)
        end

        if not(WaitTicksSpecial(aiBrain, 1)) then break end
        iSlowerCycleCount = iSlowerCycleCount - 1
        ForkThread(StrategicOverseer, aiBrain, iSlowerCycleCount)
        if iSlowerCycleCount <= 0 then
            iSlowerCycleCount = iSlowerCycleThreshold
            ForkThread(EnemyThreatRangeUpdater, aiBrain)
            ForkThread(PlatoonNameUpdater, aiBrain)
            if bDebugMessages == true then
                --ArmyPoolContainsLandFacTest(aiBrain)
              --M27EngineerOverseer.TEMPTEST(aiBrain)
            end
        end

        if not(WaitTicksSpecial(aiBrain, 1)) then break end
        ForkThread(M27EconomyOverseer.RefreshEconomyData, aiBrain)

        --NOTE: We dont have the number of ticks below as 'available' for use, since on initialisation we're waiting ticks as well when initialising things such as the engineer and upgrade overseers which work off their own loops
        --therefore the actual available tick count will be the below number less the number of ticks we're already waiting
        if not(WaitTicksSpecial(aiBrain, 4)) then break end


        if bDebugMessages == true then
            --ArmyPoolContainsLandFacTest(aiBrain)
          --M27EngineerOverseer.TEMPTEST(aiBrain)
            if M27Utilities.GetACU(aiBrain).GetNavigator and M27Utilities.GetACU(aiBrain):GetNavigator().GetCurrentTargetPos then LOG('ACU has a target in its navigator (wont reproduce to avoid desync)') end
            LOG(sFunctionRef..': End of overseer cycle code (about to start new cycle) ACU platoon=')
            DebugPrintACUPlatoon(aiBrain)
        end

        --iTempProfiling = M27Utilities.ProfilerTimeSinceLastCall('End of overseer', iTempProfiling)

        --M27Utilities.ProfilerOutput() --Handled via the time per tick
    end
end
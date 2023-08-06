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
local M27Transport = import('/mods/M27AI/lua/AI/M27Transport.lua')
local M27Events = import('/mods/M27AI/lua/AI/M27Events.lua')
local M27Team = import('/mods/M27AI/lua/AI/M27Team.lua')
local M27Navy = import('/mods/M27AI/lua/AI/M27Navy.lua')


--Semi-Global for this code:
refbACUOnInitialBuildOrder = 'M27ACUOnInitialBuildOrder' --local variable for ACU, determines whether ACUmanager is running or not
local iLandThreatSearchRange = 1000
refbACUHelpWanted = 'M27ACUHelpWanted' --flags if we want teh ACU to stay in army pool platoon so its available for defence
refoStartingACU = 'M27PlayerStartingACU' --NOTE: Use M27Utilities.GetACU(aiBrain) instead of getting this directly (to help with crash control)
tAllAIBrainsByArmyIndex = {} --Stores table of all aiBrains, used as sometimes are getting errors when trying to use ArmyBrains
tAllActiveM27Brains = {} --As per tAllAIBrainsByArmyIndex but just for M27 brains - defined for quick reference when updating reclaim
refiDistanceToNearestEnemyBase = 'M27DistanceToNearestEnemy' --Distance from our base to the nearest enemy base

--AnotherAIBrainsBackup = {}
toEnemyBrains = 'M27OverseerEnemyBrains'
refiActiveEnemyBrains = 'M27OverseerActiveEnemyBrains' --Against aibrain, number of active enemy brains
toAllyBrains = 'M27OverseerAllyBrains' --Against aiBrain
tiDistToPlayerByIndex = 'M27OverseerDistToPlayerByIndex' --Against aiBrain, [x] is the player index, returns the distance to their start position
refbNoEnemies = 'M27OverseerNoEnemyBrains' --against aiBrain, true if no enemy brains detected
iACUDeathCount = 0
iACUAlternativeFailureCount = 0
iDistanceFromBaseToBeSafe = 55 --If ACU wants to run (<50% health) then will think its safe once its this close to our base
iDistanceFromBaseWhenVeryLowHealthToBeSafe = 20 --As above but when ACU on lower health
iDistanceToEnemyEcoThreshold = 450 --Point to nearest enemy base after which will be more likely to favour eco based actions

refiACUHealthToRunOn = 'M27ACUHealthToRunOn'
iACUEmergencyHealthPercentThreshold = 0.3
iACUGetHelpPercentThreshold = 0.6
reftACURecentHealth = 'M27ACURecentHealth' --Records the ACU health every second - attached to ACU object
reftACURecentUpgradeProgress = 'M27ACURecentUpgradeProgress' --[gametimesecond] - Records the % upgrade every second the ACU is upgrading, by gametimesecond
refbACUCantPathAwayFromBase = 'M27OverseerACUCantPathAwayFromBase' --e.g. used to decide if should ignore gun upgrade on ACU

refiUnclaimedMexesInBasePathingGroup = 'M27UnclaimedMexesInBaseGroup' --Mexes we havent claimed, so includes enemy mexes
refiAllMexesInBasePathingGroup = 'M27AllMexesInBaseGroup'
iPlayersAtGameStart = 2
refiTemporarilySetAsAllyForTeam = 'M27TempSetAsAlly' --against brain, e.g. a civilian brain, returns the .M27Team number that the brain has been set as an ally of temporarily (to reveal civilians at start of game)

--Threat groups:

reftEnemyThreatGroup = 'M27EnemyThreatGroupObject'
refsEnemyThreatGroup = 'M27EnemyThreatGroupRef'
    --Threat group subtable refs:
    local refiThreatGroupCategory = 'M27EnemyGroupCategory'
    local refiThreatGroupHighestTech = 'M27EnemyGroupHighestTech'
    refoEnemyGroupUnits = 'M27EnemyGroupUnits'
    local refsEnemyGroupName = 'M27EnemyThreatGroupName'
    local refiEnemyThreatGroupUnitCount = 'M27EnemyThreatGroupUnitCount'
    local refiHighestThreatRecorded = 'M27EnemyThreatGroupHighestThreatRecorded'
    local refiTotalThreat = 'M27TotalThreat'
    local reftFrontPosition = 'M27TrheatFrontPosition'
    local refiDistanceFromOurBase = 'M27DistanceFromOurBase'
    local refiModDistanceFromOurStart = 'M27ModDistanceFromEnemy' --Distance that enemy threat group is from our start (adjusted to factor in distance from mid as well)
    local refiActualDistanceFromEnemy = 'M27ActualDistanceFromEnemy'
refstPrevEnemyThreatGroup = 'M27PrevEnemyThreatRefTable'
refbUnitAlreadyConsidered = 'M27UnitAlreadyConsidered'
refiAssignedThreat = 'M27OverseerUnitAssignedThreat' --recorded against oEnemyUnit[iOurBrainArmyIndex]
refiUnitNavalAAThreat = 'M27OverseerUnitThreat' --Recored against individual oEnemyUnit[iOurBrainArmyIndex]
local reftUnitGroupPreviousReferences = 'M27UnitGroupPreviousReferences'
reftoNearestEnemyBrainByGroup = 'M27NearestEnemyBrainsByGroup' --groups enemies based on the angle to our base so enemies in a similar part of the map are grouped togehter; used for mod distance calculation
refiModDistFromStartNearestOutstandingThreat = 'M27NearestOutstandingThreat' --Mod distance of the closest enemy threat (using GetDistanceFromStartAdjustedForDistanceFromMid)
refiModDistFromStartNearestThreat = 'M27OverseerNearestThreat' --Mod distance of the closest enemy, even if we have enough defenders to deal with it
refiModDistEmergencyRange = 'M27OverseerModDistEmergencyRange'
reftLocationFromStartNearestThreat = 'M27OverseerLocationNearestLandThreat' --Location of closest enemy
refoNearestThreat = 'M27overseerNearestLandThreat' --Unit of nearest land threat
refoNearestEnemyT2PlusStructure = 'M27OverseerNearestEnemyT2PlusStructure' --against aibrain, nearest enemy T2+ structure
refiNearestEnemyT2PlusStructure = 'M27OverseerNearestEnemyT2PlusStructureDistance' --against aibrain, distance to our base of nearest enemy T2+ structure
refiPercentageOutstandingThreat = 'M27PercentageOutstandingThreat' --% of moddistance
refiPercentageClosestFriendlyFromOurBaseToEnemy = 'M27OverseerPercentageClosestFriendly'
refiPercentageClosestFriendlyLandFromOurBaseToEnemy = 'M27OverseerClosestLandFromOurBaseToEnemy' --as above, but not limited to combat units, e.g. includes mexes
refiMaxDefenceCoveragePercentWanted = 'M27OverseerMaxDefenceCoverageWanted'
refiHighestEnemyGroundUnitHealth = 'M27OverseerHighestEnemyGroundUnitHealth' --Against aiBrain, used to track how much we want to deal in damage via overcharge
refiHighestMobileLandEnemyRange = 'M27overseerHighestMobileEnemyRange' --Against aiBrain, used to track the longest range unit the enemy has had

refbGroundCombatEnemyNearBuilding = 'M27OverseerGroundCombatNearMexCur' --against aibrain, true/false
reftEnemyGroupsThreateningBuildings = 'M27OverseerGroundCombatLocations' --against aiBrain, [x] is count, returns location of threat group average position
refbInDangerOfBeingFlanked = 'M27OverseerInDangerBeingFlanked' --Against ACU object, true or false
reftPotentialFlankingUnits = 'M27OverseerFlankingUnits' --Against ACU object, table of units we think could flank ACU


local iMaxACUEmergencyThreatRange = 150 --If ACU is more than this distance from our base then won't help even if an emergency threat

--Big enemy threats (impact on strategy and/or engineer build order)
reftEnemyLandExperimentals = 'M27OverseerEnemyGroundExperimentals'
reftEnemyArtiAndExpStructure = 'M27OverseerEnemyT3Arti' --T3 arti, and experimental structures
reftEnemyNukeLaunchers = 'M27OverseerEnemyNukeLaunchers'
reftEnemySMD = 'M27OverseerEnemySMD'
reftEnemyTML = 'M27OverseerEnemyTML'
tEnemyBigThreatCategories = { [reftEnemyLandExperimentals] = M27UnitInfo.refCategoryLandExperimental, [reftEnemyArtiAndExpStructure] = M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategoryExperimentalStructure, [reftEnemyNukeLaunchers] = M27UnitInfo.refCategorySML, [reftEnemyTML] = M27UnitInfo.refCategoryTML + M27UnitInfo.refCategoryMissileShip, [reftEnemySMD] = M27UnitInfo.refCategorySMD }
iAllBigThreatCategories = M27UnitInfo.refCategoryLandExperimental + M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategoryExperimentalStructure + M27UnitInfo.refCategorySML + M27UnitInfo.refCategoryTML + M27UnitInfo.refCategoryMissileShip + M27UnitInfo.refCategorySMD


refbEnemyTMLSightedBefore = 'M27OverseerEnemyTMLSightedBefore'
refiEnemyHighestTechLevel = 'M27OverseerEnemyHighestTech'
refbAreBigThreats = 'M27OverseerAreBigThreats'
refbEnemyFiredNuke = 'M27OverseerEnemyFiredNuke' --against aiBrain, true if an enemy has fired a nuke
refbDefendAgainstArti = 'M27OverseerDefendAgainstArti' --set to true if have activated logic to defend against enemy arti or novax
refbCloakedEnemyACU = 'M27OverseerCloakedACU'

refoNearestRangeAdjustedLandExperimental = 'M27OverseerNearestLandExperiObject' --against aiBrain, distance less unit's range
refiNearestRangeAdjustedLandExperimental = 'M27OverseerNearestLandExperiDistance' --against aibrain, nearest based on distance less range (i.e. distance until it is in range of our startp osition)


--Total threat values e.g. used for firebase chokepoints
refiTotalEnemyLongRangeThreat = 'M27OverseerLongRangeThreat' --against aiBrain, returns the mass value, even if under construction
refiTotalEnemyShortRangeThreat = 'M27OverseerShortRangeThreat' --as above
refbT2NavyNearOurBase = 'M27OverseerT2NavyNearBase' --Against aiBrain, true if enemy has T2 navy near our base
refiNearestT2PlusNavalThreat = 'M27OverseerNearestT2PlusNavalThreat' --against aibrain, returns absolute (not mod) distance of nearest enemy naval threat
refbEnemyHasSeraDestroyers = 'M27OverseerEnemyHasT2Sera'
refbEnemyHasBuiltSniperbots = 'M27OverseerEnemyHasSniperbots' --against aibrain, true if enemy has built sniperbots at any time


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
iMAAMinExperimentalLevelWithoutAir = 1500 --Mass value of MAA wanted as a minimum for experimental if we lack air control (referenced in a few places)
refbACUVulnerableToAirSnipe = 'M27OverseerACUVulnerableToAirSnipe'
refbUnclaimedMexNearACU = 'M27UnclaimedMexNearACU'
refoReclaimNearACU = 'M27ReclaimObjectNearACU'
refiScoutShortfallInitialRaiderOrSkirmisher = 'M27ScoutShortfallRaider'
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
refiMAAShortfallHighMass = 'M27MAAShortfallHighMass' --E.g. if have platoons such as experimentals with high mass value that lack sufficient MAA; note that MAA in here are also included in shortfalllarge
refiMAAShortfallBase = 'M27MAAShortfallBase'

local iScoutLargePlatoonThreshold = 8 --Platoons >= this size are considered large
local iSmallPlatoonMinSizeForScout = 3 --Wont try and assign scouts to platoons that have fewer than 3 units in them
local iMAALargePlatoonThresholdAirThreat = 10
local iMAALargePlatoonThresholdNoThreat = 20
refbMAABuiltOrDied = 'M27OverseerMAABuiltOrDied' --against aibrain, true if MAA has been built or died since last ran
refiLastCheckedMAAAssignments = 'M27OverseerLastCheckedMAAAssignments' --against aiBrain, returns gametime
refsLastScoutPathingType = 'M27OverseerLastScoutPathingType'

--Factories wanted
reftiMaxFactoryByType = 'M27OverseerMaxFactoryByType' -- table {land, air, navy} with the max no. wanted
refiMinLandFactoryBeforeOtherTypes = 'M27OverseerMinLandFactoryFirst'
refFactoryTypeLand = 1
refFactoryTypeAir = 2
refFactoryTypeNavy = 3

--Other ACU related
refiACULastTakenUnseenOrTorpedoDamage = 'M27OverseerACULastTakenUnseenDamage' --Used to determine if ACU should run or not
refoUnitDealingUnseenDamage = 'M27OverseerACUUnitDealingUnseenDamage' --Against oUnit; so can see if it was a T2+ PD that should run away from
refoLastUnitDealingDamage = 'M27OverseerLastUnitDealingDamage' --oUnit[], returns unit that last dealt damage - currently just used for ACU
refbACUWasDefending = 'M27ACUWasDefending'
iACUMaxTravelToNearbyMex = 35 --ACU will go up to this distance out of its current position to build a mex (i.e. add 10 to this for actual range)
local refiCyclesThatACUHasNoPlatoon = 'M27ACUCyclesWithNoPlatoon'
local refiCyclesThatACUInArmyPool = 'M27ACUCyclesInArmyPool'

--Intel related
--local sIntelPlatoonRef = 'M27IntelPathAI' - included above
refiInitialRaiderPlatoonsWanted = 'M27InitialRaidersWanted'
--tScoutAssignedToMexLocation = 'M27ScoutsAssignedByMex' --[sLocationRef] - returns scout unit if one has been assigned to that location; used to track scouts assigned by mex
--refiInitialEngineersWanted = 'M27InitialEngineersWanted' --This is in FactoryOverseer

refbConfirmedInitialRaidersHaveScouts = 'M27InitialRaidersHaveScouts'
refbIntelPathsGenerated = 'M27IntelPathsGenerated'
reftIntelLinePositions = 'M27IntelLinePositions' --x = line; y = point on that line, returns position
refiCurIntelLineTarget = 'M27CurIntelLineTarget'
reftiSubpathModFromBase = 'M27SubpathModFromBase' --i.e. no. of steps forward that can move for the particular subpath; is aiBrain[this ref][Intel path no.][Subpath No.]
local reftScoutsNeededPerPathPosition = 'M27ScoutsNeededPerPathPosition' --table[x] - x is path position, returns no. of scouts needed for that path position - done to save needing to call table.getn
local refiMinScoutsNeededForAnyPath = 'M27MinScoutsNeededForAnyPath'
refiMaxIntelBasePaths = 'M27MaxIntelPaths'
refbScoutBuiltOrDied = 'M27OverseerScoutBuiltOrDied' --against aiBrain, true if scout has been built or died since last ran the code for scout assignment
refiLastCheckedScoutAssignments = 'M27OverseerLastCheckedScoutAssignments' --against aiBrain, gametime that last updated scout assignments

refiSearchRangeForEnemyStructures = 'M27EnemyStructureSearchRange'
refbEnemyHasTech2PD = 'M27EnemyHasTech2PD'
refbEnemyHasMobileT2PlusStealth = 'M27EnemyHasMobileStealth' --against aiBrain, true if enemy has mobile T2+ stealth

refiOurHighestFactoryTechLevel = 'M27OverseerOurHighestFactoryTech'
refiOurHighestAirFactoryTech = 'M27OverseerOurHighestAirFactoryTech'
refiOurHighestLandFactoryTech = 'M27OverseerOurHighestLandFactoryTech'
refiOurHighestNavalFactoryTech = 'M27OverseerOurHighestNavalFactoryTech'


--Helper related
refoScoutHelper = 'M27UnitsScoutHelper'
refoUnitsMAAHelper = 'M27UnitsMAAHelper' --MAA platoon assigned to help a unit (e.g. the ACU)

--Skirmisher
refiSkirmisherMassDeathsFromLand = 'M27OverseerSkirmisherDeathsFromDF'
refiSkirmisherMassDeathsAll = 'M27OverseerSkirmisherAllDeaths'
refiSkirmisherMassKills = 'M27OverseerSkirmisherAllKills'
refiSkirmisherMassBuilt = 'M27OverseerSkirmisherMassBuilt'


--Grand strategy related
refiAIBrainCurrentStrategy = 'M27GrandStrategyRef'
refiDefaultStrategy = 'M27OverseerDefaultStrategy' --i.e. what will default to as a non-eco strat (e.g. landmain, or turtle)
refStrategyLandMain = 1 --Standard all round that has a greater focus on land on smaller maps
refStrategyAirDominance = 2 --All-out air attack on enemy, targetting any AA they have first
refStrategyProtectACU = 3 --Similar to ACUKill, but will focus units on our ACU
--refStrategyLandAttackBase = 2 --e.g. for when have got gun upgrade on ACU
--refStrategyLandConsolidate = 3 --e.g. for if ACU retreating after gun upgrade and want to get map control and eco
refStrategyACUKill = 4 --all-out attack on enemy ACU
refStrategyEcoAndTech = 5 --Focus on upgrading buildings
refStrategyTurtle = 6 --Focuses on building a firebase at a chokepoint
refStrategyLandRush = 7 --Intended for early game, focuses on mass t1 spam

--Substrategy - prioritise experimental - works similar to a strategy but largely affects builders
refbPrioritiseExperimental = 'M27OverseerPrioritiseExperimental' --against aibrian, true if want to conserve resources for experimentals

refbIncludeACUInAllOutAttack = 'M27OverseerIncludeACUInAllOutAttack'
refbStopACUKillStrategy = 'M27OverseerStopACUKillStrat'
refoLastNearestACU = 'M27OverseerLastACUObject'
reftLastNearestACU = 'M27OverseerLastACUPosition' --Position of the last ACU we saw
refiLastNearestACUDistance = 'M27OverseerLastNearestACUDistance'
refbEnemyGuncomApproachingBase = 'M27OverseerEnemyGuncomNear' --true if nearest enemy ACU to our base is near and is a guncom

refiFurthestValuableBuildingModDist = 'M27OverseerFurthestValuableBuildingModDist' --against aiBrain, includes under construction (incl experimentals being built)
refiFurthestValuableBuildingActualDist = 'M27OverseerFurthestValuableBuildingActualDist' --against aiBrain, includes under construction (incl experimentals being built)
refbEnemyACUNearOurs = 'M27OverseerACUNearOurs'
refoACUKillTarget = 'M27OverseerACUKillTarget'
reftACUKillTarget = 'M27OverseerACUKillPosition'

reftiMexIncomePrevCheck = 'M27OverseerMexIncome3mAgo' --x = prev check number; returns gross mass income
refiTimeOfLastMexIncomeCheck = 'M27OverseerTimeOfLastMexIncomeCheck'
iLongTermMassIncomeChangeInterval = 180 --3m

refiIgnoreMexesUntilThisManyUnits = 'M27ThresholdToAttackMexes'

--Other
bUnitNameUpdateActive = false --true if are cycling through every unit and updating the name
refbCloseToUnitCap = 'M27OverseerCloseToUnitCap' --True if are about to hit unit cap
refiTeamsWithSameAmphibiousPathingGroup = 'M27OverseerTeamsWithSameAmphibiousPathingGroup' --Against aiBrain, number of teams including our own one that have this amphibious pathing group
iSystemTimeBeforeStartOverseerLoop = 0 --Set just before main overseer loop started



function DebugPrintACUPlatoon(aiBrain, bReturnPlanOnly)
    --for debugging - sends log of acu platoons plan (and action if it has one and bReturnPlanOnly is false)
    local oACUUnit = M27Utilities.GetACU(aiBrain)
    local oACUPlatoon = oACUUnit.PlatoonHandle
    local sPlan
    local iCount
    local iAction = 0
    if oACUPlatoon == nil then
        sPlan = 'nil'
        if bReturnPlanOnly == true then
            return sPlan
        else
            iCount = 0
        end
    else
        local oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
        if oACUPlatoon == oArmyPoolPlatoon then
            sPlan = 'ArmyPool'
            if bReturnPlanOnly == true then
                return sPlan
            else
                iCount = 1
            end
        else
            sPlan = oACUPlatoon:GetPlan()
            if bReturnPlanOnly == true then
                return sPlan
            else
                iCount = oACUPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                if iCount == nil then
                    iCount = 0
                end
                iAction = oACUPlatoon[M27PlatoonUtilities.refiCurrentAction]
                if iAction == nil then
                    iAction = 0
                end
            end
        end
    end
    LOG('DebugPrintACUPlatoon: ACU platoon ref=' .. sPlan .. iCount .. ': Action=' .. iAction .. '; UnitState=' .. M27Logic.GetUnitState(oACUUnit))
end

function GetDistanceFromChokepointStartAdjustedForDistanceFromMid(aiBrain, tTarget)
    --Done in case struggle to locate later - just use the map info function
    return M27MapInfo.GetModChokepointDistance(aiBrain, tTarget)
end

function GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tTarget, bUseEnemyStartInstead)
    local sFunctionRef = 'GetDistanceFromStartAdjustedForDistanceFromMid'
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code, GameTime=' .. GetGameTimeSeconds() .. '; aiBrain army index=' .. aiBrain:GetArmyIndex() .. '; tTarget=' .. repru(tTarget) .. '; bUseEnemyStartInstead=' .. tostring((bUseEnemyStartInstead or false)) .. '; will draw the location in white')
        M27Utilities.DrawLocation(tTarget, false, 7, 20, nil)
    end

    local tStartPos
    local tEnemyBase
    if bUseEnemyStartInstead then
        tStartPos = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
        tEnemyBase = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    else
        tStartPos = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        tEnemyBase = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
    end

    local iDistStartToTarget = M27Utilities.GetDistanceBetweenPositions(tStartPos, tTarget)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': tStartPos=' .. repru(tStartPos) .. '; iDistStartToTarget=' .. iDistStartToTarget .. '; aiBrain[refiModDistEmergencyRange]=' .. aiBrain[refiModDistEmergencyRange])
    end
    if iDistStartToTarget <= aiBrain[refiModDistEmergencyRange] then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Are within emergency range so will just return actual dist, iDistStartToTarget=' .. iDistStartToTarget .. '; if instead we only had 1 enemy and got mod dist for this the result would be ' .. math.cos(math.abs(M27Utilities.ConvertAngleToRadians(M27Utilities.GetAngleFromAToB(tStartPos, tTarget) - M27Utilities.GetAngleFromAToB(tStartPos, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))))) * iDistStartToTarget)
        end
        return iDistStartToTarget
    else
        --If only 1 enemy group then treat anywhere behind us as the emergency range
        if bUseEnemyStartInstead then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': will ignore multiple enemies since have flagged to use enemy start instead, will return ' .. math.cos(M27Utilities.ConvertAngleToRadians(math.abs(M27Utilities.GetAngleFromAToB(tStartPos, tTarget) - M27Utilities.GetAngleFromAToB(tStartPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])))) * iDistStartToTarget)
            end
            return aiBrain[refiModDistEmergencyRange], math.cos(math.abs(M27Utilities.ConvertAngleToRadians(M27Utilities.GetAngleFromAToB(tStartPos, tTarget) - M27Utilities.GetAngleFromAToB(tStartPos, tEnemyBase)))) * iDistStartToTarget
        else
            local bIsBehindUs = true
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Is table of enemy brains empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftoNearestEnemyBrainByGroup])))
            end
            if M27Utilities.IsTableEmpty(aiBrain[reftoNearestEnemyBrainByGroup]) then
                if M27Utilities.GetDistanceBetweenPositions(tTarget, tEnemyBase) < M27Utilities.GetDistanceBetweenPositions(tStartPos, tEnemyBase) or M27Utilities.GetDistanceBetweenPositions(tTarget, tStartPos) > M27Utilities.GetDistanceBetweenPositions(tStartPos, tEnemyBase) then
                    bIsBehindUs = false
                end
            else
                for iEnemyGroup, oBrain in aiBrain[reftoNearestEnemyBrainByGroup] do
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Distance from target to start=' .. M27Utilities.GetDistanceBetweenPositions(tTarget, tStartPos) .. '; Distance from start to enemy base=' .. M27Utilities.GetDistanceBetweenPositions(tStartPos, M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]))
                    end
                    if M27Utilities.GetDistanceBetweenPositions(tTarget, M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(tStartPos, M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]) or M27Utilities.GetDistanceBetweenPositions(tTarget, tStartPos) > M27Utilities.GetDistanceBetweenPositions(tStartPos, M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]) then
                        bIsBehindUs = false
                        break
                    end
                end
            end

            if bIsBehindUs then
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Will return emergency range as enemy is behind us, so returning ' .. aiBrain[refiModDistEmergencyRange])
                end
                return aiBrain[refiModDistEmergencyRange]
            else
                --Cycle through each enemy group and get lowest value, but stop if <= emergency range
                local iCurDist
                local iLowestDist = 10000
                if M27Utilities.IsTableEmpty(aiBrain[reftoNearestEnemyBrainByGroup]) then
                    iLowestDist = math.cos(M27Utilities.ConvertAngleToRadians(math.abs(M27Utilities.GetAngleFromAToB(tStartPos, tTarget) - M27Utilities.GetAngleFromAToB(tStartPos, tEnemyBase)))) * iDistStartToTarget
                else
                    for iBrain, oBrain in aiBrain[reftoNearestEnemyBrainByGroup] do
                        iCurDist = math.cos(M27Utilities.ConvertAngleToRadians(math.abs(M27Utilities.GetAngleFromAToB(tStartPos, tTarget) - M27Utilities.GetAngleFromAToB(tStartPos, M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber])))) * iDistStartToTarget
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': iCurDist for enemy oBrain index ' .. oBrain:GetArmyIndex() .. ' = ' .. iCurDist .. '; Enemy base=' .. repru(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]) .. '; tEnemyBase=' .. repru(tEnemyBase) .. '; Angle from start to target=' .. M27Utilities.GetAngleFromAToB(tStartPos, tTarget) .. '; Angle from Start to enemy base=' .. M27Utilities.GetAngleFromAToB(tStartPos, M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]) .. '; iDistStartToTarget=' .. iDistStartToTarget)
                        end
                        if iCurDist < iLowestDist then
                            iLowestDist = iCurDist
                            if iLowestDist < aiBrain[refiModDistEmergencyRange] then
                                iLowestDist = aiBrain[refiModDistEmergencyRange]
                                break
                            end
                        end
                    end
                end

                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iLowestDist=' .. iLowestDist)
                end
                return iLowestDist
            end
        end
    end
end

function GetDistanceFromStartAdjustedForDistanceFromMidOld(aiBrain, tLocationTarget, bUseEnemyStartInstead)
    --Instead of the actual distance, it reduces the distance based on how far away it is from the centre of the map
    --bUseEnemyStartInstead - instead of basing on dist from our start, uses from enemy start
    local sFunctionRef = 'GetDistanceFromStartAdjustedForDistanceFromMid'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iModDistance = 0
    local iMidDistanceFactor = 0.3 --Intended as a very rough approximation - although in theory coudl come up with an equation to calcualte precisely, it'd be flawed for 1v1s
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
        --local iDistanceFromEnemyToUs = aiBrain[refiDistanceToNearestEnemyBase]
        --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
        local tMidpointBetweenUsAndEnemy = M27MapInfo.GetMidpointToPrimaryEnemyBase(aiBrain)
        local iActualDistance = M27Utilities.GetDistanceBetweenPositions(tStartPosition, tLocationTarget)
        local iDistanceToMid = M27Utilities.GetDistanceBetweenPositions(tMidpointBetweenUsAndEnemy, tLocationTarget)
        iModDistance = math.max(iActualDistance * 0.5, iActualDistance - iDistanceToMid * iMidDistanceFactor)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iModDistance
end

function RecordIntelPaths(aiBrain)
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordIntelPaths'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if not (aiBrain.M27IsDefeated) and M27Logic.iTimeOfLastBrainAllDefeated < 10 then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Start of code')
        end
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
                    if iScoutRange > 20 then
                        break
                    end
                end
            end
            if iScoutRange == nil or iScoutRange <= 20 then
                iScoutRange = iDefaultScoutRange
            end
            local iSubpathGap = iScoutRange * 1.7
            local sPathing = M27UnitInfo.refPathingTypeLand --want land even for aeon so dont have massive scout lines across large oceans
            local iStartingGroup = M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])

            --Get a table of all enemy start locations
            if M27Utilities.IsTableEmpty(aiBrain[toEnemyBrains]) == true and GetGameTimeSeconds() > 20 then
                M27Utilities.ErrorHandler('No nearby enemies')
            else
                if aiBrain:IsDefeated() == false then
                    --Already have M27IsDefeated check above
                    local tEnemyStartPositions = {}
                    local iCount = 0
                    for iBrain, oBrain in aiBrain[toEnemyBrains] do
                        if not (oBrain.M27IsDefeated) then
                            iCount = iCount + 1
                            tEnemyStartPositions[oBrain:GetArmyIndex()] = M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]
                        end
                    end
                    if iCount > 0 then
                        local tNearestEnemyStart = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
                        local iAngleToEnemy = M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tNearestEnemyStart)

                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Our army index=' .. aiBrain:GetArmyIndex() .. '; Our start number=' .. aiBrain.M27StartPositionNumber .. '; Nearest enemy index=' .. M27Logic.GetNearestEnemyIndex(aiBrain) .. '; Nearest enemy start number=' .. M27Logic.GetNearestEnemyStartNumber(aiBrain) .. '; Our start position=' .. repru(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) .. '; Nearest enemy startp osition=' .. repru(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)))
                        end

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

                        local tbStopMovingInDirection = { [0] = false, [90] = false, [270] = false }

                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': About to start main loop to determine all base intel paths')
                        end
                        --=======BASE PATHS
                        --Find the base points on each intel path by moving towards enemy base and seeing if we can path there
                        while bStillDeterminingBaseIntelPaths == true do
                            iCurAngleAdjust = 0
                            tiAdjToDistanceAlongPathByAngle = { [0] = 0, [90] = 0, [270] = 0 }
                            tbStopMovingInDirection = { [0] = false, [90] = false, [270] = false }
                            iCount = iCount + 1
                            if iCount > iMaxCount then
                                M27Utilities.ErrorHandler('Likely infinite loop')
                                break
                            end
                            iBaseDistanceAlongPath = (iValidIntelPaths + 1) * iDefaultScoutRange * 0.5
                            tStartingPointForSearch = M27Utilities.MoveInDirection(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iAngleToEnemy, iBaseDistanceAlongPath + tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust])
                            tPossibleBasePosition = { tStartingPointForSearch[1], tStartingPointForSearch[2], tStartingPointForSearch[3] }
                            if bDebugMessages == true then
                                LOG('Base path attempt that cant path to; Will draw tStartingPointForSearch=' .. repru(tStartingPointForSearch) .. ' in red')
                                M27Utilities.DrawLocation(tStartingPointForSearch, nil, 2, 200)
                            end --red
                            iAltCount = 0
                            iAdjustIncrement = 0
                            bCanPathToLocation = false
                            if M27MapInfo.GetSegmentGroupOfLocation(sPathing, tPossibleBasePosition) == iStartingGroup then
                                bCanPathToLocation = true
                            end
                            --Check if we can path to the target; if we cant then search at 0, 90 and 270 degrees to the normal direction in ever increasing distances until we either go off-map or get near an enemy base
                            while bCanPathToLocation == false do
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': iValidIntelPaths=' .. iValidIntelPaths .. '; tStartingPointForSearch=' .. repru(tStartingPointForSearch) .. '; tPossibleBasePosition=' .. repru(tPossibleBasePosition) .. ' tbStopMovingInDirection[iCurAngleAdjust]=' .. tostring(tbStopMovingInDirection[iCurAngleAdjust]) .. '; iCurAngleAdjust=' .. iCurAngleAdjust .. '; iBaseDistanceAlongPath=' .. iBaseDistanceAlongPath .. '; tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust]=' .. tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust])
                                end
                                if tbStopMovingInDirection[iCurAngleAdjust] == false then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Cant path to location so will consider alternative points; iAltCount=' .. iAltCount)
                                    end
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
                                        LOG(sFunctionRef .. ': tPossibleBasePosition=' .. repru(tPossibleBasePosition) .. '; iCurAngleAdjust=' .. iCurAngleAdjust .. '; iBaseDistanceAlongPath=' .. iBaseDistanceAlongPath .. '; tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust]=' .. tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust] .. '; will draw in red')
                                        M27Utilities.DrawLocation(tPossibleBasePosition, nil, 2, 200)
                                    end --red

                                    --Check we're still within map bounds
                                    if tPossibleBasePosition[1] <= iMinX or tPossibleBasePosition[1] >= iMaxX or tPossibleBasePosition[3] <= iMinZ or tPossibleBasePosition[3] >= iMaxZ then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': tPossibleBasePosition=' .. repru(tPossibleBasePosition) .. '; are out of map bounds so will stop looking in this direction. iCurAngleAdjust=' .. iCurAngleAdjust)
                                        end
                                        --Out of map bounds, flag to ignore angles of this type in the future
                                        tbStopMovingInDirection[iCurAngleAdjust] = true
                                        --Are all the others flagged to be true?
                                        bStillDeterminingBaseIntelPaths = false
                                        for _, bValue in tbStopMovingInDirection do
                                            if bValue == false then
                                                bStillDeterminingBaseIntelPaths = true
                                                break
                                            end
                                        end
                                        if bStillDeterminingBaseIntelPaths == false then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Are stopping looking for all angles so will abort; tbStopMovingInDirection=' .. repru(tbStopMovingInDirection))
                                            end
                                            break
                                        end
                                    end
                                end

                                if not (tbStopMovingInDirection[iCurAngleAdjust]) and M27MapInfo.GetSegmentGroupOfLocation(sPathing, tPossibleBasePosition) == iStartingGroup then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Can path to location')
                                    end
                                    bCanPathToLocation = true
                                    break
                                else

                                    --Change angle for next attempt
                                    if iCurAngleAdjust == 0 then
                                        iCurAngleAdjust = 90
                                    elseif iCurAngleAdjust == 90 then
                                        iCurAngleAdjust = 270
                                    else
                                        iCurAngleAdjust = 0
                                    end
                                end
                            end
                            if bCanPathToLocation == false then
                                --Couldnt find any valid locations, so stop looking
                                bStillDeterminingBaseIntelPaths = false
                            else
                                --Check the target location isn't too close to an enemy base
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Checking we arent too close to an enemy base')
                                end
                                for iEnemy, tEnemyBase in tEnemyStartPositions do
                                    if M27Utilities.GetDistanceBetweenPositions(tEnemyBase, tPossibleBasePosition) < 40 then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Are too close to an enemy. tPossibleBasePosition=' .. repru(tPossibleBasePosition) .. '; tEnemyBase=' .. repru(tEnemyBase))
                                        end
                                        bCanPathToLocation = false
                                        break
                                    end
                                end
                                if bCanPathToLocation == true then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Can path to location so will record as valid intel path')
                                    end
                                    --Record base point of intel path
                                    iValidIntelPaths = iValidIntelPaths + 1
                                    aiBrain[reftIntelLinePositions][iValidIntelPaths] = {}
                                    aiBrain[reftIntelLinePositions][iValidIntelPaths][1] = { tPossibleBasePosition[1], tPossibleBasePosition[2], tPossibleBasePosition[3] }
                                    if bDebugMessages == true then
                                        LOG('Base path that can path to; Will draw tPossibleBasePosition=' .. repru(tPossibleBasePosition) .. ' in white')
                                        M27Utilities.DrawLocation(tPossibleBasePosition, nil, 7, 200)
                                    end --white
                                else
                                    --We've got too near enemy base so stop creating new base points
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Got too near enemy base so will stop creating new base points in intel path')
                                    end
                                    bStillDeterminingBaseIntelPaths = false
                                end
                            end
                        end
                        --Backup - if no intel paths found then use the first point from our base to enemy even if it cant be pathed to
                        if iValidIntelPaths == 0 then
                            M27Utilities.ErrorHandler('Couldnt find any valid base intel paths, will just set one thats near our base as backup; error unless map has very small land pathable base. ArmyIndex=' .. aiBrain:GetArmyIndex() .. '; Nearest enemy army index=' .. M27Logic.GetNearestEnemyIndex(aiBrain))
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

                        for iIntelPath = 1, iValidIntelPaths, 1 do
                            iValidSubpaths = 0
                            bStillDeterminingSubpaths = true
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Start of loop, iIntelPath=' .. iIntelPath)
                            end
                            tiAdjToDistanceAlongPathByAngle = { [90] = 0, [270] = 0 }
                            iAltCount = 0
                            tbStopMovingInDirection = { [90] = false, [270] = false }
                            tiCyclesSinceLastMatch = { [90] = 0, [270] = 0 }

                            while bStillDeterminingSubpaths == true do
                                iAltCount = iAltCount + 1
                                if iAltCount >= 1000 then
                                    M27Utilities.ErrorHandler('Infinite loop, iIntelPath=' .. iIntelPath)
                                    bStillDeterminingSubpaths = false
                                    break
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': iIntelPath=' .. iIntelPath .. '; iAltCount=' .. iAltCount)
                                end
                                for iCurAngleAdjust = 90, 270, 180 do
                                    if not (tbStopMovingInDirection[iCurAngleAdjust]) then
                                        tbSubpathOptionOffMap = { [1] = false, [2] = false }
                                        if tiCyclesSinceLastMatch[iCurAngleAdjust] > 1000 then
                                            M27Utilities.ErrorHandler('Infinite loop, iCurAngleAdjust=' .. iCurAngleAdjust .. '; iIntelPath=' .. iIntelPath)
                                            bStillDeterminingSubpaths = false
                                            break
                                        end

                                        tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust] = tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust] + iScoutRange * 1.7
                                        tStartingPointForSearch = M27Utilities.MoveInDirection(aiBrain[reftIntelLinePositions][iIntelPath][1], iAngleToEnemy + iCurAngleAdjust, tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust])
                                        tPossibleBasePosition = { tStartingPointForSearch[1], tStartingPointForSearch[2], tStartingPointForSearch[3] }
                                        if M27MapInfo.GetSegmentGroupOfLocation(sPathing, tPossibleBasePosition) == iStartingGroup then
                                            bCanPathToLocation = true
                                        else
                                            bCanPathToLocation = false
                                        end
                                        iSubpathDistAdjust = 0

                                        --Check we're still within map bounds for the starting point
                                        if tPossibleBasePosition[1] <= iMinX or tPossibleBasePosition[1] >= iMaxX or tPossibleBasePosition[3] <= iMinZ or tPossibleBasePosition[3] >= iMaxZ then
                                            --Out of map bounds, flag to ignore angles of this type in the future
                                            tbStopMovingInDirection[iCurAngleAdjust] = true
                                            --Are all the others flagged to be true (i.e. is any one flagged as false)?
                                            bStillDeterminingSubpaths = false
                                            for _, bValue in tbStopMovingInDirection do
                                                if bValue == false then
                                                    bStillDeterminingSubpaths = true
                                                    break
                                                end
                                            end
                                            if bStillDeterminingSubpaths == false then
                                                break
                                            end
                                        end
                                        if bCanPathToLocation == false then
                                            --Check if we dont go as far in the normal direction first, can we find somwhere to path to
                                            for iOppositeAngleDistAdjust = -1, -iPointToSwitchToPositiveAdj, -1 do
                                                tPossibleBasePosition = M27Utilities.MoveInDirection(aiBrain[reftIntelLinePositions][iIntelPath][1], iAngleToEnemy + iCurAngleAdjust, tiAdjToDistanceAlongPathByAngle[iCurAngleAdjust] + iOppositeAngleDistAdjust)
                                                if M27MapInfo.GetSegmentGroupOfLocation(sPathing, tPossibleBasePosition) == iStartingGroup then
                                                    bCanPathToLocation = true
                                                end
                                            end
                                        end

                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Just finished checking starting point for search is within map bounds; iCurAngleAdjust=' .. iCurAngleAdjust .. '; tiAdjToDistanceAlongPathByAngle=' .. repru(tiAdjToDistanceAlongPathByAngle) .. '; tStartingPointForSearch=' .. repru(tStartingPointForSearch) .. '; bCanPathToLocation=' .. tostring(bCanPathToLocation))
                                        end

                                        while bCanPathToLocation == false do
                                            for iSubpathAngleOption = 1, 2 do
                                                if tiCyclesSinceLastMatch[iCurAngleAdjust] > 1000 then
                                                    M27Utilities.ErrorHandler('Infinite loop, iIntelPath=' .. iIntelPath .. '; iCurAngleAdjust=' .. iCurAngleAdjust)
                                                    bStillDeterminingSubpaths = false
                                                    break
                                                end
                                                if iSubpathAngleOption == 1 then
                                                    tiCyclesSinceLastMatch[iCurAngleAdjust] = tiCyclesSinceLastMatch[iCurAngleAdjust] + 1
                                                    iSubpathAngleAdjust = iCurAngleAdjust
                                                    iSubpathDistAdjust = iSubpathDistAdjust + 1
                                                    --Increase distance if been searhcing a while for performance reasons, e.g. might be dealing with large ocean
                                                    if tiCyclesSinceLastMatch[iCurAngleAdjust] >= 5 then
                                                        iSubpathDistAdjust = iSubpathDistAdjust + math.min(35, iSubpathDistAdjust + tiCyclesSinceLastMatch[iCurAngleAdjust] * 0.4)
                                                    end
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Increased iSubpathDistAdjust to ' .. iSubpathDistAdjust)
                                                    end
                                                else
                                                    iSubpathAngleAdjust = 180
                                                end
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': iSubpathAngleOption=' .. iSubpathAngleOption .. '; iSubpathDistAdjust=' .. iSubpathDistAdjust .. '; tbSubpathOptionOffMap[iSubpathAngleOption]=' .. tostring(tbSubpathOptionOffMap[iSubpathAngleOption]))
                                                end
                                                if not (tbSubpathOptionOffMap[iSubpathAngleOption]) then
                                                    tPossibleBasePosition = M27Utilities.MoveInDirection(tStartingPointForSearch, iAngleToEnemy + iSubpathAngleAdjust, iSubpathDistAdjust)
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': tPossibleBasePosition=' .. repru(tPossibleBasePosition) .. '; will check if within map bounds; iSubpathAngleAdjust=' .. iSubpathAngleAdjust .. '; iSubpathDistAdjust=' .. iSubpathDistAdjust)
                                                    end
                                                    --Check we're still within map bounds
                                                    if tPossibleBasePosition[1] <= iMinX or tPossibleBasePosition[1] >= iMaxX or tPossibleBasePosition[3] <= iMinZ or tPossibleBasePosition[3] >= iMaxZ then
                                                        --Out of map bounds, flag to ignore angles of this type in the future
                                                        tbSubpathOptionOffMap[iSubpathAngleOption] = true
                                                        --Are all the others flagged to be true? (i.e. is any one flagged as false)?
                                                        tbStopMovingInDirection[iCurAngleAdjust] = true
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': iSubpathAngleOption ' .. iSubpathAngleOption .. ' is out of map bounds; if other one is as well then will abort. tbSubpathOptionOffMap=' .. repru(tbSubpathOptionOffMap))
                                                        end
                                                        for _, bValue in tbSubpathOptionOffMap do
                                                            if bValue == false then
                                                                tbStopMovingInDirection[iCurAngleAdjust] = false
                                                                if bDebugMessages == true then
                                                                    LOG(sFunctionRef .. ': _=' .. _ .. '; not true so continue with main loop')
                                                                end
                                                                break
                                                            end
                                                        end
                                                        if tbStopMovingInDirection[iCurAngleAdjust] == true then
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': Both angle options are offmap so abort main loop; will check if should abort entire loop')
                                                            end
                                                            bStillDeterminingSubpaths = false
                                                            for _, bValue in tbStopMovingInDirection do
                                                                if bValue == false then
                                                                    bStillDeterminingSubpaths = true
                                                                end
                                                            end
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': tbStopMovingInDirection=' .. repru(tbStopMovingInDirection) .. '; bStillDeterminingSubpaths=' .. tostring(bStillDeterminingSubpaths))
                                                            end
                                                            break
                                                        end
                                                    end

                                                    --Can we path to the location? if so then record as a subpath entry
                                                    if M27MapInfo.GetSegmentGroupOfLocation(sPathing, tPossibleBasePosition) == iStartingGroup then
                                                        bCanPathToLocation = true
                                                        break
                                                    elseif bDebugMessages == true then
                                                        LOG('Attempted subpath that cant path to; Will draw tPossibleBasePosition=' .. repru(tPossibleBasePosition) .. ' in gold')
                                                        M27Utilities.DrawLocation(tPossibleBasePosition, nil, 4, 200) --Gold
                                                    end
                                                elseif bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': tbSubpathOptionOffMap for ' .. iSubpathAngleOption .. '=' .. tostring(tbSubpathOptionOffMap[iSubpathAngleOption]))
                                                end
                                            end
                                            if bStillDeterminingSubpaths == false then
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': No longer determining subpaths so will abort')
                                                end
                                                break
                                            elseif tbStopMovingInDirection[iCurAngleAdjust] == true then
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Dont want to keep going in this direction so exiting this part of loop')
                                                end
                                                break
                                            end
                                        end
                                        if bCanPathToLocation and not (tbStopMovingInDirection[iCurAngleAdjust]) then
                                            iValidSubpaths = iValidSubpaths + 1
                                            aiBrain[reftIntelLinePositions][iIntelPath][iValidSubpaths + 1] = { tPossibleBasePosition[1], tPossibleBasePosition[2], tPossibleBasePosition[3] }
                                            tiCyclesSinceLastMatch[iCurAngleAdjust] = 0
                                            if bDebugMessages == true then
                                                LOG('Subpath that can path to; Will draw tPossibleBasePosition=' .. repru(tPossibleBasePosition) .. ' in Dark blue')
                                                M27Utilities.DrawLocation(tPossibleBasePosition, nil, 1, 200)
                                            end --Dark blue
                                        end
                                    elseif bDebugMessages == true then
                                        LOG(sFunctionRef .. ': tbStopMovingInDirection is true for iCurAngleAdjust=' .. iCurAngleAdjust .. '; tbStopMovingInDirection=' .. repru(tbStopMovingInDirection) .. '; bStillDeterminingSubpaths=' .. tostring(bStillDeterminingSubpaths))
                                    end
                                    if bStillDeterminingSubpaths == false then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': No longer determining subpaths so will abort2')
                                        end
                                        break
                                    end
                                end
                            end
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Finished doing intel path ' .. iIntelPath .. '; will move on to next one')
                            end
                        end




                        --Record the number of scouts needed for each intel path:
                        aiBrain[reftScoutsNeededPerPathPosition] = {}
                        aiBrain[refiMinScoutsNeededForAnyPath] = 10000
                        for iCurIntelLine = 1, iValidIntelPaths do
                            aiBrain[reftScoutsNeededPerPathPosition][iCurIntelLine] = table.getn(aiBrain[reftIntelLinePositions][iCurIntelLine])
                            if aiBrain[reftScoutsNeededPerPathPosition][iCurIntelLine] < aiBrain[refiMinScoutsNeededForAnyPath] then
                                aiBrain[refiMinScoutsNeededForAnyPath] = aiBrain[reftScoutsNeededPerPathPosition][iCurIntelLine]
                            end
                        end
                        aiBrain[refiMaxIntelBasePaths] = table.getn(aiBrain[reftIntelLinePositions])
                        aiBrain[refbIntelPathsGenerated] = true
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. '; just set intelpathsgenerated to be true')
                        end

                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': End of calculating intel paths; aiBrain[refbIntelPathsGenerated]=' .. tostring(aiBrain[refbIntelPathsGenerated]) .. '; Full output of intel paths:')
                            for iIntelPath = 1, table.getn(aiBrain[reftIntelLinePositions]) do
                                LOG('iIntelPath=' .. iIntelPath .. '; Subpaths Size=' .. table.getn(aiBrain[reftIntelLinePositions][iIntelPath]) .. '; Full subpath listing=' .. repru(aiBrain[reftIntelLinePositions][iIntelPath]))
                            end
                        end
                    end
                end
            end
        else
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Pathing not complete yet, so will assume we need a scout for every category')
            end
            aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] = 1
            aiBrain[refiScoutShortfallACU] = 1
            aiBrain[refiScoutShortfallPriority] = 1
            aiBrain[refiScoutShortfallIntelLine] = 1
            aiBrain[refbNeedScoutPlatoons] = true
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetNearestMAAOrScout(aiBrain, tPosition, bScoutNotMAA, bDontTakeFromInitialRaiders, bOnlyConsiderAvailableHelpers, oRelatedUnitOrPlatoon)
    --Looks for the nearest specified support unit - if bScoutNotMAA is true then scout, toherwise MAA;, ignoring scouts/MAA in initial raider platoons if bDontTakeFromInitialRaiders is true
    --if bOnlyConsiderAvailableHelpers is true then won't consider units in any other existing platoons (unless they're a helper platoon with no helper)
    --returns nil if no such scout/MAA
    --oRelatedUnitOrPlatoon - use to check that aren't dealing with a support unit already assigned to the unit/platoon that are getting this for
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetNearestMAAOrScout'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bOnlyConsiderAvailableHelpers == nil then
        bOnlyConsiderAvailableHelpers = false
    end
    if bDontTakeFromInitialRaiders == nil then
        bDontTakeFromInitialRaiders = true
    end
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
            if oRelatedUnitOrPlatoon.GetPlan then
                oTargetPlatoon = oRelatedUnitOrPlatoon
            else
                if oRelatedUnitOrPlatoon.PlatoonHandle then
                    oTargetPlatoon = oRelatedUnitOrPlatoon.PlatoonHandle
                end
            end
            if oRelatedUnitOrPlatoon[sPlatoonHelperRef] then
                oExistingHelperPlatoon = oRelatedUnitOrPlatoon[sPlatoonHelperRef]
            end
        end

        local bValidSupport, iCurDistanceToPosition, oCurPlatoon
        local iMinDistanceToPosition = 100000
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Total support (scouts or MAA) to choose from=' .. table.getn(tSupportToChooseFrom))
        end
        local oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
        local oIdleScoutPlatoon = aiBrain[M27PlatoonTemplates.refoIdleScouts]
        local oIdleMAAPlatoon = aiBrain[M27PlatoonTemplates.refoIdleMAA]
        local oCurPlatoon
        for iUnit, oUnit in tSupportToChooseFrom do
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Considering if iUnit ' .. iUnit .. ' is valid for assignment')
            end
            bValidSupport = false
            if not (oUnit.Dead) then
                if oUnit.GetFractionComplete and oUnit:GetFractionComplete() < 1 then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': iUnit=' .. iUnit .. ': Still being constructed')
                    end
                else
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Considering whether unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' is available as a scout/MAA. oUnit[M27PlatoonFormer.refbJustBuilt]=' .. tostring((oUnit[M27PlatoonFormer.refbJustBuilt] or false)) .. '; oUnit[M27Transport.refiAssignedPlateau]=' .. (oUnit[M27Transport.refiAssignedPlateau] or 'nil') .. '; aiBrain[M27MapInfo.refiOurBasePlateauGroup]=' .. aiBrain[M27MapInfo.refiOurBasePlateauGroup])
                    end
                    --Ignore if scout/MAA waiting to be released for duty or is assigned to a plateau
                    if not (oUnit[M27Transport.refiAssignedPlateau]) then
                        oUnit[M27Transport.refiAssignedPlateau] = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition())
                    end
                    if not (oUnit[M27PlatoonFormer.refbJustBuilt] == true) and oUnit[M27Transport.refiAssignedPlateau] == aiBrain[M27MapInfo.refiOurBasePlateauGroup] then
                        bValidSupport = true
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': iUnit=' .. iUnit .. ': Is alive and constructed, checking if has a platoon handle')
                        end
                        oCurPlatoon = oUnit.PlatoonHandle
                        if oCurPlatoon then
                            if bOnlyConsiderAvailableHelpers == true then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': iUnit=' .. iUnit .. ': Only want units from army pool, checking if is from army pool')
                                end
                                if not (oCurPlatoon == oArmyPoolPlatoon) and not (oCurPlatoon == oIdleScoutPlatoon) and not (oCurPlatoon == oIdleMAAPlatoon) and not (oCurPlatoon:GetPlan() == 'M27MAAPatrol') then
                                    bValidSupport = false
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': iUnit=' .. iUnit .. ': Isnt army pool so dont want this unit unless its a helper platoon without a target')
                                    end
                                    --If it a helper platoon that has no helper target?
                                    if oCurPlatoon.GetPlan then
                                        local sPlan = oCurPlatoon:GetPlan()
                                        if sPlan == 'M27ScoutAssister' or sPlan == 'M27MAAAssister' then
                                            if oCurPlatoon[M27PlatoonUtilities.refoSupportHelperUnitTarget] == nil and oCurPlatoon[M27PlatoonUtilities.refoSupportHelperPlatoonTarget] == nil then
                                                bValidSupport = true
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': iUnit=' .. iUnit .. ': Helper platoon without a target so can use')
                                                end
                                            end
                                        end
                                    end
                                end
                                --Looking in all platoons - check we're not looking in one already assigned for the purpose wanted
                            elseif oCurPlatoon == oTargetPlatoon or oCurPlatoon == oExistingHelperPlatoon then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Platoon handle equals the target platoon or existing helper platoon handle')
                                end
                                bValidSupport = false
                            else
                                if bDontTakeFromInitialRaiders == true then
                                    --Check the current platoon reference, or the assisitng platoon reference if current platoon is assisting another platoon
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Checking if its in initial raider platoon or assisting them')
                                    end
                                    if oCurPlatoon then
                                        if oCurPlatoon[M27PlatoonUtilities.refoSupportHelperPlatoonTarget] then
                                            oCurPlatoon = oCurPlatoon[M27PlatoonUtilities.refoSupportHelperPlatoonTarget]
                                        end

                                        local bRaiderPlatoon = false
                                        if oCurPlatoon and oCurPlatoon.GetPlan and oCurPlatoon:GetPlan() == 'M27MexRaiderAI' then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Is in raider platoon')
                                            end
                                            bRaiderPlatoon = true
                                            --[[elseif oCurPlatoon and oCurPlatoon[sPlatoonHelperRef] and oCurPlatoon[sPlatoonHelperRef].GetPlan and oCurPlatoon[sPlatoonHelperRef].GetPlan() == 'M27MexRaiderAI' then
                                                bRaiderPlatoon = true
                                                oCurPlatoon = oCurPlatoon[sPlatoonHelperRef] --]]
                                        else
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Isnt in raider platoon directly or indirectly; sPlatoonHelperRef=' .. sPlatoonHelperRef)
                                            end
                                        end
                                        if bRaiderPlatoon == true and oCurPlatoon[M27PlatoonUtilities.refiPlatoonCount] <= aiBrain[refiInitialRaiderPlatoonsWanted] then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': iUnit is in raider platoon number ' .. oCurPlatoon[M27PlatoonUtilities.refiPlatoonCount] .. '; aiBrain[refiInitialRaiderPlatoonsWanted]=' .. aiBrain[refiInitialRaiderPlatoonsWanted])
                                            end
                                            bValidSupport = false
                                        end
                                    end
                                else
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Are happy to take the unit from all existing platoons')
                                    end
                                end
                            end
                        else
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': iUnit=' .. iUnit .. ': Unit has no platoon handle so ok to use')
                            end
                        end
                    end
                end
            else
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iUnit ' .. iUnit .. ' is dead')
                end
            end
            if bValidSupport == true then
                --have a valid unit, record how close it is
                --GetDistanceBetweenPositions(Position1, Position2, iBuildingSize)
                iCurDistanceToPosition = M27Utilities.GetDistanceBetweenPositions(tPosition, oUnit:GetPosition())
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iUnit=' .. iUnit .. ': Have a valid unit, so checking how far away it is, iCurDistanceToPosition=' .. iCurDistanceToPosition)
                end
                if iCurDistanceToPosition <= iMinDistanceToPosition then
                    iMinDistanceToPosition = iCurDistanceToPosition
                    oNearestSupportUnit = oUnit
                end
            end
        end
        if bDebugMessages == true then
            if oNearestSupportUnit == nil then
                LOG(sFunctionRef .. ': Finished cycling through all relevant units, didnt find any that can use')
            else
                LOG(sFunctionRef .. ': Finished cycling through all relevant units and found one that can use')
            end
        end
    else
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': No support units owned')
        end
    end
    if oNearestSupportUnit and oNearestSupportUnit[M27PlatoonFormer.refbJustBuilt] == true then
        M27Utilities.ErrorHandler('nearest unit was just built')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oNearestSupportUnit
end

function AssignHelperToLocation(aiBrain, oHelperToAssign, tLocation)
    local sFunctionRef = 'AssignHelperToLocation'

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oNewPlatoon = aiBrain:MakePlatoon('', '')
    aiBrain:AssignUnitsToPlatoon(oNewPlatoon, { oHelperToAssign }, 'Attack', 'GrowthFormation')
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
    if oPlatoonOrUnitNeedingHelp.PlatoonHandle or oPlatoonOrUnitNeedingHelp.GetUnitId then
        bUnitNotPlatoon = true
    end
    if bScoutNotMAA == false then
        refHelper = refoUnitsMAAHelper
        sPlanWanted = 'M27MAAAssister'
    end

    local bNeedNewHelperPlatoon = true
    local oExistingHelperPlatoon = oPlatoonOrUnitNeedingHelp[refHelper]
    if oExistingHelperPlatoon and aiBrain:PlatoonExists(oExistingHelperPlatoon) and oExistingHelperPlatoon.GetPlan and oExistingHelperPlatoon:GetPlan() == sPlanWanted then
        bNeedNewHelperPlatoon = false
    end

    if bNeedNewHelperPlatoon == true then
        oExistingHelperPlatoon = aiBrain:MakePlatoon('', '')
        oPlatoonOrUnitNeedingHelp[refHelper] = oExistingHelperPlatoon
    end
    if oHelperToAssign.PlatoonHandle and aiBrain:PlatoonExists(oHelperToAssign.PlatoonHandle) then
        M27PlatoonUtilities.RemoveUnitsFromPlatoon(oHelperToAssign.PlatoonHandle, { oHelperToAssign }, false, oExistingHelperPlatoon)
    else
        --Redundancy in case there's a scenario where you dont have a platoon handle for a MAA
        aiBrain:AssignUnitsToPlatoon(oExistingHelperPlatoon, { oHelperToAssign }, 'Attack', 'GrowthFormation')
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': sPlanWanted=' .. sPlanWanted .. '; bNeedNewHelperPlatoon=' .. tostring(bNeedNewHelperPlatoon))
    end
    if oExistingHelperPlatoon then
        if bUnitNotPlatoon == true then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Dealing with unit not platoon')
            end
            oExistingHelperPlatoon[M27PlatoonUtilities.refoSupportHelperUnitTarget] = oPlatoonOrUnitNeedingHelp
            oExistingHelperPlatoon[M27PlatoonUtilities.refoSupportHelperPlatoonTarget] = nil
        else
            if bDebugMessages == true then
                --LOG(sFunctionRef..': Units in new platoon='..table.getn(oExistingHelperPlatoon:GetPlatoonUnits()))
                if oPlatoonOrUnitNeedingHelp.GetPlan then
                    LOG('Helping platoon with a plan')
                else
                    M27Utilities.ErrorHandler('Helping platoon that has no plan')
                end
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
                    if iPlatoonCount == nil then
                        iPlatoonCount = 1
                    else
                        iPlatoonCount = iPlatoonCount + 1
                    end
                end
                LOG(sFunctionRef .. ': Created new platoon with Plan name and count=' .. sPlanWanted .. iPlatoonCount)
            end
        end
    else
        M27Utilities.ErrorHandler('oExistingHelperPlatoon is nil')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetMAAFactoryAdjustForLargePlatoons(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetMAAFactoryAdjustForLargePlatoons'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iMAAIncreaseFactor = 1
    if bDebugMessages == true then LOG(sFunctionRef..': Enemy air to ground='..  aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat]..'; Far behind on air='..tostring(aiBrain[M27AirOverseer.refbFarBehindOnAir] or false)) end
    if aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 10000 then
        iMAAIncreaseFactor = 1.7
        if aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 20000 then
            iMAAIncreaseFactor = 2.4
        end
    end
    if aiBrain[M27AirOverseer.refbFarBehindOnAir] then iMAAIncreaseFactor = math.min(iMAAIncreaseFactor + 1.75, iMAAIncreaseFactor * 1.75) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iMAAIncreaseFactor
end

function AssignMAAToPreferredPlatoons(aiBrain)
    --Similar to assigning scouts, but for MAA - for now just focus on having MAA helping ACU and any platoon of >20 size that doesnt contain MAA
    --===========ACU MAA helper--------------------------
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AssignMAAToPreferredPlatoons'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetGameTimeSeconds() >= 300 and aiBrain:GetArmyIndex() == 4 then bDebugMessages = true end

    if aiBrain[refbMAABuiltOrDied] or GetGameTimeSeconds() - (aiBrain[refiLastCheckedMAAAssignments] or -100) >= 4 then
        aiBrain[refbMAABuiltOrDied] = false
        aiBrain[refiLastCheckedMAAAssignments] = GetGameTimeSeconds()

        local iACUMinMAAThreatWantedWithAirThreat = 110 --Equivalent to 2 T1 MAA
        if aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][3] > 0 then
            iACUMinMAAThreatWantedWithAirThreat = 800 --1 T3 MAA
        elseif aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][2] > 0 or aiBrain[refiOurHighestFactoryTechLevel] >= 3 then
            iACUMinMAAThreatWantedWithAirThreat = 320 --2 T2 MAA
        elseif aiBrain[refiOurHighestFactoryTechLevel] >= 2 then
            iACUMinMAAThreatWantedWithAirThreat = 160 --1 T2 MAA
        end
        --[[if aiBrain[refiOurHighestFactoryTechLevel] > 1 then
            if aiBrain[refiOurHighestFactoryTechLevel] == 2 then
                iACUMinMAAThreatWantedWithAirThreat = 320 --2 T2 MAA
            elseif aiBrain[refiOurHighestFactoryTechLevel] >= 3 then
                iACUMinMAAThreatWantedWithAirThreat = 800 --1 T3 MAA
            end
        end--]]
        local iAirThreatMAAFactor = 0.2 --approx mass value of MAA wanted with ACU as a % of the total air to ground threat
        local iMaxMAAThreatForACU = iACUMinMAAThreatWantedWithAirThreat * 3 --equivalent to 3 T3 MAA at T3
        local iACUMinMAAThreatWantedWithNoAirThreat = iACUMinMAAThreatWantedWithAirThreat * 0.5
        local iMAAThreatWanted = 0
        local iMinACUMAAThreatWanted = iACUMinMAAThreatWantedWithNoAirThreat
        local iMaxMAAWantedForACUAtOnce = 2
        local tiMAAMassValue = { 55, 160, 400, 400 } --Will have mixture of T2 and T3 at T3+
        local iSingleMAAMassValue = tiMAAMassValue[aiBrain[refiOurHighestFactoryTechLevel]]

        local oACU = M27Utilities.GetACU(aiBrain)

        --Adjust MAA based on enemy air threat
        if aiBrain[M27AirOverseer.refbHaveAirControl] then
            iAirThreatMAAFactor = 0.1
            iMaxMAAWantedForACUAtOnce = 1
        else
            --Increase minimum MAA slightly if enemy has a notable air threat
            if bDebugMessages == true then LOG(sFunctionRef..': Dont have air control, will increase MAA wanted. aiBrain[M27AirOverseer.refiHighestEnemyAirThreat]='..aiBrain[M27AirOverseer.refiHighestEnemyAirThreat]..'; iACUMinMAAThreatWantedWithAirThreat pre adjust='..iACUMinMAAThreatWantedWithAirThreat..'; ACU dist from base='..M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; Is ACU underwater='..tostring(M27UnitInfo.IsUnitUnderwater(oACU))..'; Enemy T2+ air factories='..(aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][2] + aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][3])..'; Enemy air to ground threat='..aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat]) end
            if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] > 250 then iACUMinMAAThreatWantedWithAirThreat = iACUMinMAAThreatWantedWithAirThreat + 55 * aiBrain[refiOurHighestFactoryTechLevel] end


            --Further increase AA wanted if ACU is far from base
            if M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) >= 200 and not(M27UnitInfo.IsUnitUnderwater(oACU)) then

                if (aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] or 0) > 0 then

                    if aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] > 500 and (aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][2] + aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][3]) > 0 then
                        iAirThreatMAAFactor = iAirThreatMAAFactor * 1.6
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy has significant air to ground threat so increasing iAirThreatMAAFactor to '..iAirThreatMAAFactor) end
                    else
                        iAirThreatMAAFactor = iAirThreatMAAFactor * 1.4
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy has some air to ground threat so increasing iAirThreatMAAFactor to '..iAirThreatMAAFactor) end
                    end
                else
                    iAirThreatMAAFactor = iAirThreatMAAFactor * 1.2
                    if bDebugMessages == true then LOG(sFunctionRef..': Enemy has no air to ground threat so only increasing MAA factor to '..iAirThreatMAAFactor) end
                end
            end
        end
        if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] > 0 then
            if (aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] or 0) > 0 then
                iMinACUMAAThreatWanted = iACUMinMAAThreatWantedWithAirThreat
            else
                iMinACUMAAThreatWanted = iACUMinMAAThreatWantedWithAirThreat * 0.7
            end
        end






        local function GetMAAThreat(tMAAUnits)
            return M27Logic.GetAirThreatLevel(aiBrain, tMAAUnits, false, false, true, false, false)
        end

        local refCategoryMAA = M27UnitInfo.refCategoryMAA

        iMAAThreatWanted = math.min(iMaxMAAThreatForACU, math.max(iMinACUMAAThreatWanted, math.floor((aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] or 0) * iAirThreatMAAFactor)))

        --If ACU is near base or chokepoint and we own T2+ fixed AA near it, then reduce MAA threat wanted

        if M27UnitInfo.IsUnitValid(oACU) then
            --If ACU near base and has nearby SAM then reduce max MAA wanted for it significantly
            if M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= math.max(iDistanceFromBaseToBeSafe, 80) and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructureAA * categories.TECH3, oACU:GetPosition(), 50, 'Ally')) == false then
                iMAAThreatWanted = math.min(800, iMAAThreatWanted)
                iMinACUMAAThreatWanted = math.min(iMinACUMAAThreatWanted * 0.35, iMAAThreatWanted * 0.7)
                if bDebugMessages == true then LOG(sFunctionRef..': ACU near SAM so capping iMAAThreatWanted='..iMAAThreatWanted..'; iMinACUMAAThreatWanted='..iMinACUMAAThreatWanted) end
            end

            if bDebugMessages == true then LOG(sFunctionRef..': If we have at least T2 and ACU has decent health then will limit the MAA to get for it. aiBrain[refiOurHighestFactoryTechLevel]='..aiBrain[refiOurHighestFactoryTechLevel]..'; M27UnitInfo.GetUnitHealthPercent(oACU)='..M27UnitInfo.GetUnitHealthPercent(oACU)) end
            if aiBrain[refiOurHighestFactoryTechLevel] >= 2 and M27UnitInfo.GetUnitHealthPercent(oACU) >= 0.75 then
                local iAACategory
                if aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][3] > 0 then iAACategory = M27UnitInfo.refCategoryStructureAA * categories.TECH3
                elseif aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][2] > 0 then iAACategory = M27UnitInfo.refCategoryStructureAA * categories.TECH3 + M27UnitInfo.refCategoryStructureAA * categories.TECH2
                else iAACategory = M27UnitInfo.refCategoryStructureAA
                end
                local tNearbyGroundAA = aiBrain:GetUnitsAroundPoint(iAACategory, oACU:GetPosition(), 60, 'Ally')
                local iDistToBase = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                if M27Utilities.IsTableEmpty(tNearbyGroundAA) == false then
                    if iDistToBase <= iDistanceFromBaseToBeSafe + 5 then

                        iMAAThreatWanted = math.min(iMinACUMAAThreatWanted, iMAAThreatWanted)
                        iMinACUMAAThreatWanted = iMinACUMAAThreatWanted * 0.4
                    elseif iDistToBase <= 125 then
                        iMAAThreatWanted = math.min(iMAAThreatWanted, iMinACUMAAThreatWanted * 1.2)
                        iMinACUMAAThreatWanted = iMinACUMAAThreatWanted * 0.6
                    elseif iDistToBase <= 200 then
                        iMAAThreatWanted = math.min(iMAAThreatWanted, iMinACUMAAThreatWanted * 1.5)
                        iMinACUMAAThreatWanted = iMinACUMAAThreatWanted * 0.8
                        if bDebugMessages == true then LOG(sFunctionRef..': ACU isnt that close to base so iMAAThreatWanted='..iMAAThreatWanted..'; iMinACUMAAThreatWanted='..iMinACUMAAThreatWanted) end
                    else
                        iMAAThreatWanted = math.min(iMAAThreatWanted, iMinACUMAAThreatWanted * 2.5, math.max(iMinACUMAAThreatWanted * 1.75, 500 + 250 * (aiBrain[refiOurHighestLandFactoryTech] - 1)))
                        iMinACUMAAThreatWanted = iMinACUMAAThreatWanted
                        if bDebugMessages == true then LOG(sFunctionRef..': ACU far away so greatly increasing the cap on the min MAA wanted. iMAAThreatWanted='..iMAAThreatWanted..'; iMinACUMAAThreatWanted='..iMinACUMAAThreatWanted) end
                    end
                end
            end

            if iMAAThreatWanted > 400 then
                --Cap based on eco, and also if only have t1 land fac
                iMAAThreatWanted = math.min(aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] * 20 + 400 * aiBrain[refiOurHighestFactoryTechLevel] + 400 * (aiBrain[refiOurHighestFactoryTechLevel] - 1), 420 + 3000 * (aiBrain[refiOurHighestFactoryTechLevel] - 1), iMAAThreatWanted)
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Added overall cap for ACU MAA wanted based on our eco. iMAAThreatWanted post cap='..iMAAThreatWanted..'; Gross mass income='..aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome]) end
        end
        local oExistingMAAPlatoon = oACU[refoUnitsMAAHelper]

        --Increase MAA threat wanted if vulnerable to air snipe and we have T2+ land factory
        if aiBrain[refbACUVulnerableToAirSnipe] and aiBrain[refiOurHighestLandFactoryTech] >= 2 then
            iMAAThreatWanted = iMAAThreatWanted + 200
            iMinACUMAAThreatWanted = iMinACUMAAThreatWanted + 200
            if  oExistingMAAPlatoon and oExistingMAAPlatoon[M27PlatoonUtilities.reftCurrentUnits] and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryMAA * categories.TECH2,oExistingMAAPlatoon[M27PlatoonUtilities.reftCurrentUnits])) and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryMAA * categories.TECH2) > 0 then
                iMAAThreatWanted = iMAAThreatWanted + 200
                iMinACUMAAThreatWanted = iMinACUMAAThreatWanted + 200
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Are vulnerable to air snipe so increasing MAA wanted, iMAAThreatWanted='..iMAAThreatWanted..'; iMinACUMAAThreatWanted='..iMinACUMAAThreatWanted..'; iAirThreatMAAFactor='..iAirThreatMAAFactor) end
        end


        local sMAAPlatoonName = 'M27MAAAssister'
        local bNeedMoreMAA = false
        local bACUNeedsMAAHelper = true
        local oNewMAAPlatoon

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': About to check if ACU needs MAA; iMAAWanted=' .. iMAAThreatWanted..'; iMinACUMAAThreatWanted='..iMinACUMAAThreatWanted..'; Enemy air to ground threat='..(aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] or 0)..'; Enemy air factories='..repru(aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech])..'; aiBrain[refbACUVulnerableToAirSnipe]='..tostring(aiBrain[refbACUVulnerableToAirSnipe])..'; ')
            if oExistingMAAPlatoon then LOG(sFunctionRef..': oExistingMAAPlatoon mass value='..oExistingMAAPlatoon[M27PlatoonUtilities.refiPlatoonMassValue]..'; current units='..oExistingMAAPlatoon[M27PlatoonUtilities.refiCurrentUnits]) end
        end
        if not (oExistingMAAPlatoon == nil) then
            --A helper was assigned, check if it still exists
            if oExistingMAAPlatoon and aiBrain:PlatoonExists(oExistingMAAPlatoon) then
                --Platoon still exists; does it have the right aiplan?
                local sMAAHelperName = oExistingMAAPlatoon:GetPlan()
                if sMAAHelperName and sMAAHelperName == sMAAPlatoonName then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': sMAAHelperName=' .. sMAAHelperName)
                    end
                    if M27Utilities.IsTableEmpty(oExistingMAAPlatoon[M27PlatoonUtilities.reftCurrentUnits]) == false then
                        local iCurMAAHelperThreat = GetMAAThreat(oExistingMAAPlatoon[M27PlatoonUtilities.reftCurrentUnits])
                        if oExistingMAAPlatoon[M27PlatoonUtilities.refiCurrentUnits] >= 10 then
                            iMAAThreatWanted = math.min(iMAAThreatWanted, iCurMAAHelperThreat)
                        end
                        iMAAThreatWanted = iMAAThreatWanted - iCurMAAHelperThreat
                        iMinACUMAAThreatWanted = iMinACUMAAThreatWanted - iCurMAAHelperThreat
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': iCurMAAHelperThreat=' .. iCurMAAHelperThreat .. '; iMAAThreatWanted after factorign in this=' .. iMAAThreatWanted)
                        end
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
                        if sMAAHelperName == nil then
                            LOG(sFunctionRef .. ': MAA Helper has a nil plan; changing')
                        else
                            LOG(sFunctionRef .. ': MAAHelper doesnt have the right plan; changing')
                        end
                    end
                    oExistingMAAPlatoon:SetAIPlan(sMAAPlatoonName)
                end
            end
        else
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': No MAA helper assigned previously')
            end
        end
        if iMAAThreatWanted <= 0 then
            bACUNeedsMAAHelper = false
        end

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': iMAAThreatWanted=' .. iMAAThreatWanted .. '; bACUNeedsMAAHelper=' .. tostring(bACUNeedsMAAHelper))
        end
        if bACUNeedsMAAHelper == true then
            local iCurMAAUnitThreat = 0
            --Assign MAA if we have any available; as its the ACU we want the nearest MAA of any platoon
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Checking for nearest mobileMAA; iMAAThreatWanted=' .. iMAAThreatWanted)
            end
            local oMAAToGive
            local iCurLoopCount = 0
            local iMaxLoopCount = 100
            while iMAAThreatWanted > 0 do
                iCurLoopCount = iCurLoopCount + 1
                if iCurLoopCount > iMaxLoopCount then
                    M27Utilities.ErrorHandler('likely infinite loop')
                    break
                end

                oMAAToGive = GetNearestMAAOrScout(aiBrain, oACU:GetPosition(), false, true, false, oACU)
                if oMAAToGive == nil or oMAAToGive.Dead then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': oMAAToGive is nil or dead')
                    end
                    bNeedMoreMAA = true
                    break
                else
                    iCurMAAUnitThreat = GetMAAThreat({ oMAAToGive })
                    iMAAThreatWanted = iMAAThreatWanted - iCurMAAUnitThreat
                    iMinACUMAAThreatWanted = iMinACUMAAThreatWanted - iCurMAAUnitThreat

                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': oMAAToGive is valid, will create new platoon (if dont already have one) and assign it if havent already created')
                    end
                    AssignHelperToPlatoonOrUnit(oMAAToGive, oACU, false)
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

        if iMAAThreatWanted <= 0 then
            --Have more than enough MAA to cover ACU, move on to considering if large platoons can get MAA support
            --=================Large platoons - ensure they have MAA in them, and if not then add MAA
            local tPlatoonUnits, iPlatoonUnits, tPlatoonCurrentMAAs, oMAAToAdd, oMAAOldPlatoon

            local iThresholdForAMAA --MAA wanted will be platoon mass value divided by this
            if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] == nil then
                aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] = 0
            end
            if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] > 0 then
                iThresholdForAMAA = 250 + (500 * (aiBrain[refiOurHighestFactoryTechLevel] - 1))
            else
                iThresholdForAMAA = 750 + (1500 * (aiBrain[refiOurHighestFactoryTechLevel] - 1))
            end
            local iMaxMAASize = 10

            if aiBrain[M27AirOverseer.refbHaveAirControl] == false then
                iThresholdForAMAA = iThresholdForAMAA * 0.5
                iMaxMAASize = 20
            end

            local iMAAWanted = 0
            local iTotalMAAWanted = 0
            local iMAAAlreadyHave
            local iCurLoopCount
            local iMaxLoopCount = 50
            --If the last cycle we didnt have enough MAA to cover our high mass platoons then want to prioritise these first
            if aiBrain[refiMAAShortfallHighMass] > 0 then
                iThresholdForAMAA = 10000
            end
            aiBrain[refiMAAShortfallHighMass] = 0

            if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] then
                local iOurBaseLandPathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                for iCurPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
                    if oPlatoon.GetPlan and not (oPlatoon[M27PlatoonTemplates.refbIdlePlatoon]) and not(oPlatoon[M27PlatoonTemplates.refbDoesntWantMAA]) and not (oPlatoon[M27PlatoonTemplates.refbRequiresUnitToFollow]) and not (oPlatoon[M27PlatoonTemplates.refbRunFromAllEnemies]) and not(oPlatoon[M27PlatoonUtilities.refbACUInPlatoon]) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Considering platoon ' .. (oPlatoon:GetPlan() or 'nil') .. (oPlatoon[M27PlatoonUtilities.refiPlatoonCount] or 'nil') .. '; Land pathing segment=' .. M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)) .. '; Our base segment=' .. iOurBaseLandPathingGroup .. '; Mass value=' .. (oPlatoon[M27PlatoonUtilities.refiPlatoonMassValue] or 'nil') .. '; iThresholdForAMAA=' .. (iThresholdForAMAA or 'nil'))
                        end
                        if (oPlatoon[M27PlatoonUtilities.refiPlatoonMassValue] or 0) >= iThresholdForAMAA then
                            --Can we path here with land from our base?
                            if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] or M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)) == iOurBaseLandPathingGroup then
                                iMAAWanted = math.min(iMaxMAASize, math.floor(oPlatoon[M27PlatoonUtilities.refiPlatoonMassValue] / iThresholdForAMAA))
                                if oPlatoon[M27PlatoonUtilities.refiPlatoonMassValue] or 0 <= 10000 then
                                    iMAAWanted = math.min(iMAAWanted, 8)
                                else
                                    iMAAWanted = math.max(iMAAWanted, iMAAMinExperimentalLevelWithoutAir * GetMAAFactoryAdjustForLargePlatoons(aiBrain))
                                end
                                tPlatoonCurrentMAAs = EntityCategoryFilterDown(refCategoryMAA, oPlatoon:GetPlatoonUnits())
                                if M27Utilities.IsTableEmpty(tPlatoonCurrentMAAs) == true then
                                    iMAAAlreadyHave = 0
                                    --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride, bIncludeAirTorpedo)
                                else
                                    iMAAAlreadyHave = M27Logic.GetAirThreatLevel(aiBrain, tPlatoonCurrentMAAs, false, false, true, false, false, nil, nil, nil, nil, nil)
                                end
                                if oPlatoon[refoUnitsMAAHelper] then
                                    --tPlatoonCurrentMAAs = oPlatoon[refoUnitsMAAHelper]:GetPlatoonUnits()
                                    --if M27Utilities.IsTableEmpty(tPlatoonCurrentMAAs) == false then
                                    iMAAAlreadyHave = iMAAAlreadyHave + (oPlatoon[refoUnitsMAAHelper][M27PlatoonUtilities.refiPlatoonMassValue] or 0)
                                    --end
                                end
                                iCurLoopCount = 0

                                --Convert to number of units
                                --iMAAWanted = math.floor(iMAAWanted / iSingleMAAMassValue) --MAAWanted is divided by the MAA threshold so effectively already is a number of units
                                iMAAAlreadyHave = math.ceil(iMAAAlreadyHave / iSingleMAAMassValue)

                                while iMAAWanted > iMAAAlreadyHave do
                                    iCurLoopCount = iCurLoopCount + 1
                                    if iCurLoopCount > iMaxLoopCount then
                                        M27Utilities.ErrorHandler('likely infinite loop')
                                        break
                                    end
                                    --Need MAAs in the platoon
                                    oMAAToAdd = GetNearestMAAOrScout(aiBrain, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), false, true, true, oPlatoon)
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
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Can path to platoon with land. iMAAWanted=' .. iMAAWanted .. '; iMAAAlreadyHave=' .. iMAAAlreadyHave)
                                end

                            end

                            if iMAAWanted > iMAAAlreadyHave then
                                iTotalMAAWanted = iMAAWanted - iMAAAlreadyHave
                                if oPlatoon[M27PlatoonUtilities.refiPlatoonMassValue] or 0 >= 10000 then
                                    aiBrain[refiMAAShortfallHighMass] = aiBrain[refiMAAShortfallHighMass] + (iMAAWanted - iMAAAlreadyHave)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Have high value platoon ' .. oPlatoon:GetPlan() .. oPlatoon[M27PlatoonUtilities.refiPlatoonCount] .. ' with mass value ' .. oPlatoon[M27PlatoonUtilities.refiPlatoonMassValue] .. ' that lacks sufficient MAA. iTotalMAAWanted=' .. iTotalMAAWanted .. '; iMAAAlreadyHave=' .. iMAAAlreadyHave .. '; aiBrain[refiMAAShortfallHighMass]=' .. aiBrain[refiMAAShortfallHighMass])
                                    end
                                end
                                break
                            end
                        end
                    end
                end
            end
            aiBrain[refiMAAShortfallLargePlatoons] = iTotalMAAWanted
            if aiBrain[refiMAAShortfallLargePlatoons] > 0 then
                aiBrain[refiMAAShortfallBase] = 1
            else
                aiBrain[refiMAAShortfallBase] = 0
            end
        else
            --Dont have enough MAA for any platoons
            aiBrain[refiMAAShortfallLargePlatoons] = 10
            aiBrain[refiMAAShortfallHighMass] = 10
        end


        --========Build order related TODO longer term - update the current true/false flag in the factory overseer to differentiate between the MAA wanted
        if aiBrain[refiMAAShortfallACUPrecaution] + aiBrain[refiMAAShortfallACUCore] + aiBrain[refiMAAShortfallLargePlatoons] + aiBrain[refiMAAShortfallHighMass] > 0 then
            bNeedMoreMAA = true
        else
            bNeedMoreMAA = false
        end
        aiBrain[refbNeedMAABuilt] = bNeedMoreMAA

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': End of MAA assignment logic; aiBrain[refiMAAShortfallACUPrecaution]=' .. aiBrain[refiMAAShortfallACUPrecaution] .. '; aiBrain[refiMAAShortfallACUCore]=' .. aiBrain[refiMAAShortfallACUCore] .. '; aiBrain[refiMAAShortfallLargePlatoons]=' .. aiBrain[refiMAAShortfallLargePlatoons] .. '; aiBrain[refiMAAShortfallHighMass]=' .. aiBrain[refiMAAShortfallHighMass])
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetEnemyNetThreatAlongIntelPath(aiBrain, iIntelPathBaseNumber, iIntelPathEnemySearchRange, iAllySearchRange)
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetEnemyNetThreatAlongIntelPath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iCurEnemyThreat = 0
    local iCurAllyThreat = 0
    local iTotalEnemyNetThreat = 0
    local bScoutNearAllMexes = true
    local tNearbyScouts
    local tEnemyUnitsNearPoint, tEnemyStructuresNearPoint
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': About to loop through subpath positions. aiBrain[refiCurIntelLineTarget]=' .. aiBrain[refiCurIntelLineTarget])
    end
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
            M27Utilities.ErrorHandler('Likely infinite loop, iIntelPathBaseNumber=' .. iIntelPathBaseNumber .. '; iSubpath=' .. iSubPath .. '; size of subpath table=' .. table.getn(aiBrain[reftIntelLinePositions][iIntelPathBaseNumber]))
            break
        end
        if aiBrain == nil then
            M27Utilities.ErrorHandler('aiBrain is nil')
        end
        tNearbyEnemies = aiBrain:GetUnitsAroundPoint(categories.MOBILE + M27UnitInfo.refCategoryStructure, tSubPathPosition, iIntelPathEnemySearchRange, 'Enemy')
        tNearbyAllies = aiBrain:GetUnitsAroundPoint(categories.MOBILE + M27UnitInfo.refCategoryStructure, tSubPathPosition, iAllySearchRange, 'Ally')
        if bDebugMessages == true then
            LOG(sFunctionRef .. '; iSubPath=' .. iSubPath .. '; about to get enemy and ally threat around point')
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': tSubPathPosition=' .. repru(tSubPathPosition))
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': is tNearbyEnemies empty?=' .. tostring(M27Utilities.IsTableEmpty(tNearbyEnemies)))
        end

        if M27Utilities.IsTableEmpty(tNearbyEnemies) == true then
            iCurEnemyThreat = 0
        else
            iCurEnemyThreat = M27Logic.GetCombatThreatRating(aiBrain, tNearbyEnemies, true)
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': About to get threat for nearby allies')
        end
        if M27Utilities.IsTableEmpty(tNearbyAllies) == true then
            iCurAllyThreat = 0
        else
            iCurAllyThreat = M27Logic.GetCombatThreatRating(aiBrain, tNearbyAllies, false)
        end
        iTotalEnemyNetThreat = math.max(iCurEnemyThreat - iCurAllyThreat, 0) + iTotalEnemyNetThreat
        if bDebugMessages == true then
            LOG(sFunctionRef .. '; iSubPath=' .. iSubPath .. '; iCurEnemyThreat=' .. iCurEnemyThreat .. '; iCurAllyThreat=' .. iCurAllyThreat .. '; iTotalEnemyNetThreat=' .. iTotalEnemyNetThreat)
        end
        if iTotalEnemyNetThreat > 170 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': enemy threat is more than 170 so dont want to advance path, treat it as not having scouts near every location')
            end
            bScoutNearAllMexes = false
            break
        else
            --Is the scout assigned to this position on a further subpath?
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Will see if scout modification is <= 0')
            end
            if (aiBrain[reftiSubpathModFromBase][iIntelPathBaseNumber][iSubPath] or 0) <= 0 then
                tNearbyScouts = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandScout, tSubPathPosition, iIntelPathEnemySearchRange, 'Ally')
                if M27Utilities.IsTableEmpty(tNearbyScouts) then
                    --Do we have intel or visual coverage?
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Checking if have intel coverage of tSubPathPosition=' .. repru(tSubPathPosition))
                    end
                    if not (M27Logic.GetIntelCoverageOfPosition(aiBrain, tSubPathPosition, 25, false)) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Dont have intel coverage of the target position; will draw gold circle around it')
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
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AssignScoutsToPreferredPlatoons'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if aiBrain[refbScoutBuiltOrDied] or GetGameTimeSeconds() - (aiBrain[refiLastCheckedScoutAssignments] or -100) >= 10 then
        aiBrain[refiLastCheckedScoutAssignments] = GetGameTimeSeconds()
        aiBrain[refbScoutBuiltOrDied] = false
        --Rare error - AI mass produces scouts - logs enabled for if this happens
        local refCategoryLandScout = M27UnitInfo.refCategoryLandScout
        local tAllScouts = aiBrain:GetListOfUnits(refCategoryLandScout, false, true)
        local iScouts = 0
        local iIntelPathEnemySearchRange = 35 --min scout range is 40, some are higher, this gives a bit of leeway

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Start of code')
        end

        local sScoutPathing = (aiBrain[refsLastScoutPathingType] or M27UnitInfo.refPathingTypeLand)

        if M27Utilities.IsTableEmpty(tAllScouts) == false then
            iScouts = table.getn(tAllScouts)
        end

        --Set scout shortfalls to 0 for everything (but still calculate how many we want later) to reduce risk we no logner need scout but keep producing
        if iScouts >= 6 then
            aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] = 0
            aiBrain[refiScoutShortfallACU] = 0
            aiBrain[refiScoutShortfallPriority] = 0
            aiBrain[refiScoutShortfallIntelLine] = 0
            aiBrain[refiScoutShortfallLargePlatoons] = 0
            aiBrain[refiScoutShortfallAllPlatoons] = 0
            aiBrain[refiScoutShortfallMexes] = 0
        end

        local oArmyPoolPlatoon, tArmyPoolScouts
        if iScouts > 0 then
            local oScoutToGive
            --============Initial mex raider scouts and skirmishers-----------------------
            --Check initial raiders have scouts (1-off at start of game)
            if aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] == nil then
                aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] = {}
            end
            local iRaiderCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27MexRaiderAI']
            if iRaiderCount == nil then
                iRaiderCount = 0
                aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27MexRaiderAI'] = 0
            end
            --local iMinScoutsWantedInPool = 0 --This is also changed several times below
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Have iScouts=' .. iScouts .. '; About to check if raiders have been checked for scouts; iScouts=' .. iScouts .. '; iRaiderCount=' .. iRaiderCount .. '; aiBrain[refbConfirmedInitialRaidersHaveScouts]=' .. tostring(aiBrain[refbConfirmedInitialRaidersHaveScouts]))
            end

            local iAvailableScouts = iScouts
            local iRaiderScoutsMissing = 0
            if iRaiderCount > 0 then
                --Have we checked that the raiders have scouts in them?  If not, then as a 1-off add scouts to them
                if aiBrain[refbConfirmedInitialRaidersHaveScouts] == false then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': About to check if we have enough scouts to assign to the raider platoons if they need them')
                    end
                    if iScouts >= 1 then
                        --we should have a scout for the raider platoon
                        --if iScouts >= aiBrain[refiInitialRaiderPlatoonsWanted] and iRaiderCount >= aiBrain[refiInitialRaiderPlatoonsWanted] then aiBrain[refbConfirmedInitialRaidersHaveScouts] = true end --will be giving scouts in later step
                        --iMinScoutsWantedInPool = 0
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': About to cycle through each platoon to get the initialraider platoons')
                        end
                        for iCurPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
                            if not (oPlatoon == oArmyPoolPlatoon) then
                                if oPlatoon:GetPlan() == 'M27MexRaiderAI' then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Have found a raider platoon, oPlatoon[M27PlatoonUtilities.refiPlatoonCount]=' .. oPlatoon[M27PlatoonUtilities.refiPlatoonCount])
                                    end
                                    if oPlatoon[M27PlatoonUtilities.refiPlatoonCount] <= aiBrain[refiInitialRaiderPlatoonsWanted] then
                                        local tRaiders = oPlatoon:GetPlatoonUnits()
                                        if M27Utilities.IsTableEmpty(tRaiders) == false then
                                            local tRaiderScouts = EntityCategoryFilterDown(refCategoryLandScout, tRaiders)
                                            local bHaveScout = false
                                            if M27Utilities.IsTableEmpty(tRaiderScouts) == false then
                                                bHaveScout = true
                                            elseif oPlatoon[refoScoutHelper] then
                                                tRaiderScouts = oPlatoon[refoScoutHelper]:GetPlatoonUnits()
                                                if M27Utilities.IsTableEmpty(tRaiderScouts) == false then
                                                    bHaveScout = true
                                                end
                                            end
                                            if bHaveScout == false then
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Raider platoon' .. oPlatoon[M27PlatoonUtilities.refiPlatoonCount] .. ' doesnt have any scouts, seeing if we can give it a scout')
                                                end
                                                --Platoon doesnt have a scout - can we give it one?
                                                local tPlatoonPosition = M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)
                                                oScoutToGive = GetNearestMAAOrScout(aiBrain, tPlatoonPosition, true, true, true)
                                                if oScoutToGive == nil then
                                                    oScoutToGive = GetNearestMAAOrScout(aiBrain, tPlatoonPosition, true, true, false)
                                                end
                                                if oScoutToGive == nil then
                                                    iRaiderScoutsMissing = iRaiderScoutsMissing + 1
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
                            aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] = 0
                        else
                            aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] = math.max(aiBrain[refiInitialRaiderPlatoonsWanted] - iRaiderCount, 0) + iRaiderScoutsMissing
                        end
                    end
                end
            end
            iAvailableScouts = iAvailableScouts - iRaiderScoutsMissing
            if iAvailableScouts < 0 then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iAvailableScouts=' .. iAvailableScouts .. '; not enough for intiial raider so will flag as having shortfall')
                end
                if aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] < 1 then
                    aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] = -iAvailableScouts
                end --redundancy/backup - shouldnt need due to above
                aiBrain[refiScoutShortfallACU] = 1
                aiBrain[refiScoutShortfallPriority] = 1
                aiBrain[refiScoutShortfallIntelLine] = aiBrain[refiMinScoutsNeededForAnyPath]
            else
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Have enough scouts for initial raiders, will now consider skirmishers. iAvailableScouts=' .. iAvailableScouts)
                end
                if M27Utilities.IsTableEmpty(aiBrain[M27PlatoonUtilities.reftSkirmisherPlatoonWantingIntel]) == false then
                    local iSkirmishersNeedingScouts = 0
                    for iPlatoon, oPlatoon in aiBrain[M27PlatoonUtilities.reftSkirmisherPlatoonWantingIntel] do
                        if aiBrain:PlatoonExists(oPlatoon) then
                            if not (oPlatoon[refoScoutHelper]) or oPlatoon[refoScoutHelper][M27PlatoonUtilities.refiCurrentUnits] <= 0 then
                                iSkirmishersNeedingScouts = iSkirmishersNeedingScouts + 1
                                if iAvailableScouts > 0 then
                                    oScoutToGive = GetNearestMAAOrScout(aiBrain, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), true, true, true)
                                    if oScoutToGive then
                                        iAvailableScouts = iAvailableScouts - 1
                                        iSkirmishersNeedingScouts = iSkirmishersNeedingScouts - 1
                                        AssignHelperToPlatoonOrUnit(oScoutToGive, oPlatoon, true)
                                    end
                                end
                            end
                        else
                            aiBrain[M27PlatoonUtilities.reftSkirmisherPlatoonWantingIntel][iPlatoon] = nil
                        end
                    end
                    aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] = aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] + iSkirmishersNeedingScouts
                else
                    aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] = 0
                end

                if iAvailableScouts <= 0 then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Dont ahve any more available scouts so setting shortfall to 1 for ACU')
                    end
                    aiBrain[refiScoutShortfallACU] = 1
                    aiBrain[refiScoutShortfallPriority] = 1
                    aiBrain[refiScoutShortfallIntelLine] = aiBrain[refiMinScoutsNeededForAnyPath]
                else
                    --Have at least 1 available scout
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Have at least 1 available scout so will assign to ACU')
                    end

                    --===========ACU Scout helper--------------------------
                    --We have more than enough scouts to cover initial raiders; next priority is the ACU
                    local bACUNeedsScoutHelper = true
                    if not (M27Utilities.GetACU(aiBrain)[refoScoutHelper] == nil) then
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

                        if not (oScoutToGive == nil) then
                            AssignHelperToPlatoonOrUnit(oScoutToGive, M27Utilities.GetACU(aiBrain), true)

                        end
                    end
                    iAvailableScouts = iAvailableScouts - 1
                    aiBrain[refiScoutShortfallACU] = 0
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Finished assining to ACU, aiBrain[refiScoutShortfallACU]=' .. aiBrain[refiScoutShortfallACU])
                    end

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
                        if iPriorityTargets == 0 then
                            aiBrain[refiScoutShortfallPriority] = 0
                        else
                            --do all of the priority targets have a scout assigned?
                            for iPriorityTarget, oPriorityTarget in aiBrain[reftPriorityLandScoutTargets] do
                                if not (M27UnitInfo.IsUnitValid(oPriorityTarget[refoScoutHelper])) then
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
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': No available scouts so will flag intel path shortfall')
                        end
                        aiBrain[refiScoutShortfallIntelLine] = aiBrain[refiMinScoutsNeededForAnyPath]
                    else
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': iAvailableScouts=' .. iAvailableScouts .. '; will now assign to intel path')
                        end
                        --Do we have an intel platoon yet?
                        local tIntelPlatoons = {}
                        local iIntelPlatoons = 0
                        --local oFirstIntelPlatoon
                        local tCurIntelScouts = {}
                        local iCurIntelScouts = 0
                        local iIntelScouts = 0
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Cycling through all platoons to identify intel platoons. aiBrain[refiScoutShortfallACU]=' .. aiBrain[refiScoutShortfallACU])
                        end
                        for iPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
                            if oPlatoon:GetPlan() == sIntelPlatoonRef then
                                tCurIntelScouts = EntityCategoryFilterDown(refCategoryLandScout, oPlatoon:GetPlatoonUnits())
                                if not (tCurIntelScouts == nil) then
                                    iCurIntelScouts = table.getn(tCurIntelScouts)
                                    if iCurIntelScouts > 0 then
                                        iIntelScouts = iIntelScouts + iCurIntelScouts
                                        iIntelPlatoons = iIntelPlatoons + 1
                                        tIntelPlatoons[iIntelPlatoons] = oPlatoon
                                    end
                                end
                            end
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Intel platoons identified; aiBrain[refiScoutShortfallACU]=' .. aiBrain[refiScoutShortfallACU] .. '; iIntelPlatoons=' .. iIntelPlatoons)
                        end
                        --if iIntelPlatoons > 0 then

                        --First determine what intel path line we want, and if we have enough scouts to achieve this
                        local bRefreshPath = false
                        local iPrevIntelLineTarget = aiBrain[refiCurIntelLineTarget]
                        if aiBrain[refiCurIntelLineTarget] == nil then
                            aiBrain[refiCurIntelLineTarget] = 1
                            bRefreshPath = true
                        end
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
                                        if not (tScoutsNearACU == nil) then
                                            if table.getn(tScoutsNearACU) > 0 then
                                                bACUNeedsSupport = false
                                            end
                                        end
                                    end
                                end
                                if bACUNeedsSupport == true then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Want to move scouts forward so ACU has better intel')
                                    end
                                    aiBrain[refiCurIntelLineTarget] = aiBrain[refiCurIntelLineTarget] + 1
                                else
                                    --Cycle through each point on the current path, and check various conditions:

                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': About to loop through subpath positions to see if we can move the line forward. aiBrain[refiCurIntelLineTarget]=' .. aiBrain[refiCurIntelLineTarget])
                                    end
                                    local iTotalEnemyNetThreat, bScoutNearAllMexes = GetEnemyNetThreatAlongIntelPath(aiBrain, aiBrain[refiCurIntelLineTarget], iIntelPathEnemySearchRange, 35)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Finished looping through subpath positions, iTotalEnemyNetThreat=' .. iTotalEnemyNetThreat .. '; bScoutNearAllMexes=' .. tostring(bScoutNearAllMexes))
                                    end
                                    if iTotalEnemyNetThreat > 170 then
                                        aiBrain[refiCurIntelLineTarget] = aiBrain[refiCurIntelLineTarget] - 1
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Enemy net threat of ' .. iTotalEnemyNetThreat .. ' exceeds 170 so reducing current intel line target by 1 to ' .. aiBrain[refiCurIntelLineTarget])
                                        end
                                    else
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': iTotalEnemyNetThreat=' .. iTotalEnemyNetThreat .. '; If 0 or less and scouts are in position then will increase intel base path')
                                        end
                                        if iTotalEnemyNetThreat <= 0 then
                                            --Are all scouts in position?
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Checking if all scouts are in position. bScoutNearAllMexes=' .. tostring(bScoutNearAllMexes) .. '; table.getn(aiBrain[reftIntelLinePositions])=' .. table.getn(aiBrain[reftIntelLinePositions]) .. '; aiBrain[refiCurIntelLineTarget=' .. aiBrain[refiCurIntelLineTarget])
                                            end
                                            if bScoutNearAllMexes == true and table.getn(aiBrain[reftIntelLinePositions]) > aiBrain[refiCurIntelLineTarget] then
                                                --If we move the intel line up by 1 will we have too much enemy threat?
                                                iTotalEnemyNetThreat = GetEnemyNetThreatAlongIntelPath(aiBrain, aiBrain[refiCurIntelLineTarget] + 1, iIntelPathEnemySearchRange, 35)
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': If we increase the intel path by 1, then the total enemy net threat is ' .. iTotalEnemyNetThreat .. '; will only increase if this is <= 0')
                                                end
                                                if iTotalEnemyNetThreat <= 0 then
                                                    aiBrain[refiCurIntelLineTarget] = aiBrain[refiCurIntelLineTarget] + 1
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': All scouts are in position so increasing intel path by 1 to ' .. aiBrain[refiCurIntelLineTarget])
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            else
                                if not (M27Logic.iTimeOfLastBrainAllDefeated) or M27Logic.iTimeOfLastBrainAllDefeated < 10 then
                                    M27Utilities.ErrorHandler('M27Logic.GetNearestEnemyStartNumber(aiBrain) is nil')
                                end
                            end
                        else
                            --Dont have enough scouts to cover any path, to stick with initial base path
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Dont have enough scouts to cover any intel path, stay at base path; aiBrain[refiMinScoutsNeededForAnyPath]=' .. aiBrain[refiMinScoutsNeededForAnyPath] .. '; iIntelPlatoons=' .. iIntelPlatoons)
                            end
                            aiBrain[refiCurIntelLineTarget] = 1
                        end
                        --Keep within min and max (this is repeated as needed here to make sure iscoutswanted doesnt cause error)
                        if aiBrain[refiCurIntelLineTarget] <= 0 then
                            aiBrain[refiCurIntelLineTarget] = 1
                        elseif aiBrain[refiCurIntelLineTarget] > aiBrain[refiMaxIntelBasePaths] then
                            aiBrain[refiCurIntelLineTarget] = aiBrain[refiMaxIntelBasePaths]
                        end

                        if bDebugMessages == true then
                            LOG('aiBrain[refiScoutShortfallACU]=' .. aiBrain[refiScoutShortfallACU] .. '; aiBrain[refiCurIntelLineTarget]=' .. aiBrain[refiCurIntelLineTarget] .. '; table.getn(aiBrain[reftIntelLinePositions])=' .. table.getn(aiBrain[reftIntelLinePositions]) .. '; aiBrain[refiMaxIntelBasePaths]=' .. aiBrain[refiMaxIntelBasePaths])
                        end
                        local iScoutsWanted = table.getn(aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]])
                        local iScoutsForNextPath = aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget] + 1]
                        if iScoutsForNextPath then
                            iScoutsForNextPath = table.getn(iScoutsForNextPath)
                        end
                        if iScoutsForNextPath == nil then
                            iScoutsForNextPath = iScoutsWanted
                        end

                        if iAvailableScouts <= iScoutsWanted or iAvailableScouts <= iScoutsForNextPath then
                            local iScoutsToBuild = iScoutsWanted - iAvailableScouts
                            if iScoutsForNextPath > iScoutsWanted then
                                iScoutsToBuild = iScoutsForNextPath - iScoutsWanted
                            end
                            iScoutsToBuild = iScoutsToBuild + 1
                            aiBrain[refiScoutShortfallIntelLine] = iScoutsToBuild
                        else
                            aiBrain[refiScoutShortfallIntelLine] = 0
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': aiBrain[refiScoutShortfallACU]=' .. aiBrain[refiScoutShortfallACU] .. '; iScoutsWanted=' .. iScoutsWanted .. '; iScoutsForNextPath=' .. iScoutsForNextPath .. 'aiBrain[refiScoutShortfallIntelLine]=' .. aiBrain[refiScoutShortfallIntelLine])
                        end

                        local iLoopCount = 0
                        local iLoopMax = 100
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': refiCurIntelLineTarget=' .. aiBrain[refiCurIntelLineTarget] .. '; About to loop through scouts wanted; iScoutsWanted=' .. iScoutsWanted .. '; iIntelScouts=' .. iIntelScouts)
                            LOG('About to log every path in the current line:')
                            for iCurSubPath, tPath in aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]] do
                                LOG('iCurSubPath=' .. iCurSubPath .. '; repr=' .. repru(tPath))
                            end
                        end
                        while iAvailableScouts < (iScoutsWanted - 2) do
                            --Too few to try and maintain intel path, so fall back 1 position
                            iLoopCount = iLoopCount + 1
                            if iLoopCount > iLoopMax then
                                M27Utilities.ErrorHandler('likely infinite loop - exceeded iLoopMax of ' .. iLoopMax .. '; refiCurIntelLineTarget=' .. aiBrain[refiCurIntelLineTarget])
                                break
                            end
                            aiBrain[refiCurIntelLineTarget] = aiBrain[refiCurIntelLineTarget] - 1
                            if aiBrain[refiCurIntelLineTarget] <= 1 then
                                break
                            end
                            iScoutsWanted = table.getn(aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]])
                        end
                        --Keep within min and max possible targets:
                        if aiBrain[refiCurIntelLineTarget] <= 0 then
                            aiBrain[refiCurIntelLineTarget] = 1
                        elseif aiBrain[refiCurIntelLineTarget] > aiBrain[refiMaxIntelBasePaths] then
                            aiBrain[refiCurIntelLineTarget] = aiBrain[refiMaxIntelBasePaths]
                        end

                        --Consider moving forwards at individual points if already have a scout near the current position and no enemies:
                        if aiBrain[refiCurIntelLineTarget] <= 0 then
                            aiBrain[refiCurIntelLineTarget] = 1
                        elseif aiBrain[refiCurIntelLineTarget] > aiBrain[refiMaxIntelBasePaths] then
                            aiBrain[refiCurIntelLineTarget] = aiBrain[refiMaxIntelBasePaths]
                        end


                        --If we have enough scouts for the current path, then consider each individual point on the path and whether it can go further forwards than the base, provided we have enough scouts to
                        if aiBrain[refiScoutShortfallIntelLine] == 0 then
                            local tNearbyEnemiesBase
                            local tNearbyEnemiesPlus1, tSubPathPlus1
                            local tNearbyEnemiesPlus2, tSubPathPlus2
                            local iIncreaseInSubpath, iMaxIncreaseInSubpath, iNextMaxIncrease
                            local iCurIntelLineTarget = aiBrain[refiCurIntelLineTarget]
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': aiBrain[refiScoutShortfallACU]=' .. aiBrain[refiScoutShortfallACU] .. '; aiBrain[refiCurIntelLineTarget]=' .. aiBrain[refiCurIntelLineTarget] .. '; size of intel paths=' .. table.getn(aiBrain[reftIntelLinePositions]))
                            end

                            for iSubPath, tSubPathPosition in aiBrain[reftIntelLinePositions][iCurIntelLineTarget] do
                                iIncreaseInSubpath = 0
                                iMaxIncreaseInSubpath = 0

                                --Determine max subpath that can use based on neighbours:
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Determining subpath modification from base to apply for iSubPath=' .. iSubPath)
                                end
                                if aiBrain[reftiSubpathModFromBase] == nil then
                                    aiBrain[reftiSubpathModFromBase] = {}
                                end
                                if aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget] == nil then
                                    aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget] = {}
                                end
                                if aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath] == nil then
                                    aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath] = 0
                                end
                                if aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath - 1] == nil then
                                    aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath - 1] = 0
                                end
                                if aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath + 1] == nil then
                                    aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath + 1] = 0
                                end

                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget]=' .. repru(aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget]))
                                end
                                --Get for -1 subpath:
                                if iSubPath > 1 then
                                    iMaxIncreaseInSubpath = aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath - 1] + 1
                                end
                                --Get for +1 subpath if it exists
                                if iSubPath < aiBrain[reftScoutsNeededPerPathPosition][iCurIntelLineTarget] then
                                    if aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath + 1] then
                                        iNextMaxIncrease = aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath + 1] + 1
                                    else
                                        iNextMaxIncrease = 1
                                    end
                                end
                                if iNextMaxIncrease > iMaxIncreaseInSubpath then
                                    iMaxIncreaseInSubpath = iNextMaxIncrease
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': iSubPath=' .. iSubPath .. '; iMaxIncreaseInSubpath =' .. iMaxIncreaseInSubpath)
                                end

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
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': aiBrain[refiScoutShortfallACU=' .. aiBrain[refiScoutShortfallACU] .. '; iSubPath=' .. iSubPath .. '; iMaxIncreaseInSubpath =' .. iMaxIncreaseInSubpath .. '; iIncrease wnated before applying max=' .. iIncreaseInSubpath)
                                end
                                if iIncreaseInSubpath > iMaxIncreaseInSubpath then
                                    iIncreaseInSubpath = iMaxIncreaseInSubpath
                                end
                                local tCurPathPos
                                tCurPathPos = aiBrain[reftIntelLinePositions][iCurIntelLineTarget + iIncreaseInSubpath][iSubPath]
                                while M27Utilities.IsTableEmpty(tCurPathPos) == true do
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': iSubPath=' .. iSubPath .. '; iIncreaseInSubpath=' .. iIncreaseInSubpath .. '; position given by this is invalid, so decreasing by 1')
                                    end
                                    iIncreaseInSubpath = iIncreaseInSubpath - 1
                                    if iIncreaseInSubpath <= 0 then
                                        break
                                    end
                                    tCurPathPos = aiBrain[reftIntelLinePositions][iCurIntelLineTarget + iIncreaseInSubpath][iSubPath]
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': iSubPath=' .. iSubPath .. '; tCurPathPos=' .. repru(tCurPathPos))
                                end

                                aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath] = iIncreaseInSubpath
                            end
                        end


                        --Create intel platoons if needed (choosing scouts nearest to the start point of the intel path for simplicity)
                        local tBasePathPosition = aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]][1]
                        local iNewIntelPlatoonsNeeded = iScoutsWanted - iIntelPlatoons
                        if iNewIntelPlatoonsNeeded > iAvailableScouts then
                            iNewIntelPlatoonsNeeded = iAvailableScouts
                        end
                        local oNewScoutPlatoon
                        local iCount = 0
                        while iNewIntelPlatoonsNeeded > 0 do
                            iCount = iCount + 1
                            if iCount > 100 then
                                M27Utilities.ErrorHandler('Infinite loop')
                                break
                            end
                            oScoutToGive = GetNearestMAAOrScout(aiBrain, tBasePathPosition, true, true, true)
                            if oScoutToGive then
                                local oNewScoutPlatoon = aiBrain:MakePlatoon('', '')
                                if oScoutToGive.PlatoonHandle and aiBrain:PlatoonExists(oScoutToGive.PlatoonHandle) then
                                    M27PlatoonUtilities.RemoveUnitsFromPlatoon(oScoutToGive.PlatoonHandle, { oScoutToGive }, false, oNewScoutPlatoon)
                                else
                                    --Redundancy in case there's a scenario where you dont have a platoon handle for a scout
                                    aiBrain:AssignUnitsToPlatoon(oNewScoutPlatoon, { oScoutToGive }, 'Attack', 'GrowthFormation')
                                end
                                oNewScoutPlatoon:SetAIPlan('M27IntelPathAI')
                                iIntelPlatoons = iIntelPlatoons + 1
                                tIntelPlatoons[iIntelPlatoons] = oNewScoutPlatoon
                                if bDebugMessages == true then
                                    local iPlatoonCount = oNewScoutPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                    if iPlatoonCount == nil then
                                        iPlatoonCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27IntelPathAI']
                                        if iPlatoonCount == nil then
                                            iPlatoonCount = 1
                                        else
                                            iPlatoonCount = iPlatoonCount + 1
                                        end
                                    end
                                    LOG(sFunctionRef .. ': aiBrain[refiScoutShortfallACU]=' .. aiBrain[refiScoutShortfallACU] .. '; Created new platoon with Plan name and count=' .. oNewScoutPlatoon:GetPlan() .. iPlatoonCount)
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
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': aiBrain[refiScoutShortfallACU]=' .. aiBrain[refiScoutShortfallACU] .. '; About to loop subpaths in current target')
                        end
                        if iIntelPlatoons >= 1 then
                            for iCurSubpath = 1, table.getn(aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]]) do
                                iMinDistFromCurPath = 100000
                                oClosestPlatoon = nil
                                iClosestPlatoon = 0
                                iSubpathMod = aiBrain[reftiSubpathModFromBase][aiBrain[refiCurIntelLineTarget]][iCurSubpath]
                                if iSubpathMod == nil then
                                    iSubpathMod = 0
                                end --e.g. if not got enough scouts for a full path wont have set subpath mods yet
                                tCurPathPos = aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget] + iSubpathMod][iCurSubpath]
                                if M27Utilities.IsTableEmpty(tCurPathPos) == true then
                                    M27Utilities.ErrorHandler('tCurPathPos is empty for iCurSubpath=' .. iCurSubpath .. '; iIntelLineTarget=' .. aiBrain[refiCurIntelLineTarget] .. '; iSubpathMod=' .. iSubpathMod)
                                else
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': iCurSubpath=' .. iCurSubpath .. '; iSubpathMod = ' .. iSubpathMod .. ': tCurPathPos=' .. repru(tCurPathPos))
                                        M27Utilities.DrawLocation(tCurPathPos)
                                    end
                                    for iPlatoon, oPlatoon in tIntelPlatoons do
                                        if bDebugMessages == true then
                                            local iPlatoonCount = oPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                            if iPlatoonCount == nil then
                                                iPlatoonCount = 'nil'
                                            end
                                            LOG(sFunctionRef .. ': Cycling through all platoons in tIntelPlatoons, iPlatoon=' .. iPlatoon .. '; oPlatoon count=' .. iPlatoonCount)
                                        end
                                        iDistFromCurPath = M27Utilities.GetDistanceBetweenPositions(M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), tCurPathPos)
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': iDistFromCurPath=' .. iDistFromCurPath)
                                        end
                                        if iDistFromCurPath < iMinDistFromCurPath then
                                            iMinDistFromCurPath = iDistFromCurPath
                                            oClosestPlatoon = oPlatoon
                                            iClosestPlatoon = iPlatoon
                                        end
                                    end
                                    if oClosestPlatoon == nil then
                                        break
                                    else
                                        table.remove(tIntelPlatoons, iClosestPlatoon)
                                        if oClosestPlatoon[M27PlatoonUtilities.reftMovementPath] == nil then
                                            oClosestPlatoon[M27PlatoonUtilities.reftMovementPath] = {}
                                            oClosestPlatoon[M27PlatoonUtilities.reftMovementPath][1] = {}
                                        end
                                        if not (oClosestPlatoon[M27PlatoonUtilities.reftMovementPath][1][1] == tCurPathPos[1] and oClosestPlatoon[M27PlatoonUtilities.reftMovementPath][1][3] == tCurPathPos[3]) then
                                            if bDebugMessages == true and oClosestPlatoon.GetPlan then
                                                LOG(sFunctionRef .. ': Giving override action to oClosestPlatoon ' .. oClosestPlatoon:GetPlan() .. (oClosestPlatoon[M27PlatoonUtilities.refiPlatoonCount] or 'nil') .. ': tCurPathPosition=' .. repru(tCurPathPos) .. '; movement path=' .. repru((oClosestPlatoon[M27PlatoonUtilities.reftMovementPath][1] or { 'nil' })) .. ' unless its prev action was to run; platoon prevaction=' .. (oClosestPlatoon[M27PlatoonUtilities.reftPrevAction][1] or 'nil'))
                                            end
                                            if not (oClosestPlatoon[M27PlatoonUtilities.reftPrevAction][1] == M27PlatoonUtilities.refActionRun) and not (oClosestPlatoon[M27PlatoonUtilities.reftPrevAction][1] == M27PlatoonUtilities.refActionTemporaryRetreat) and not (oClosestPlatoon[M27PlatoonUtilities.reftPrevAction][1] == M27PlatoonUtilities.refActionReturnToBase) then
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Prev action wasnt to run so updating movement path, will force a refresh of this if we havent given an override in last 5s; oClosestPlatoon[M27PlatoonUtilities.refiLastPrevActionOverride]=' .. (oClosestPlatoon[M27PlatoonUtilities.refiLastPrevActionOverride] or 'nil'))
                                                end
                                                if oClosestPlatoon[M27PlatoonUtilities.refiLastPrevActionOverride] >= 5 and M27Utilities.GetDistanceBetweenPositions(((oClosestPlatoon[M27PlatoonUtilities.reftMovementPath] or { 0, 0, 0 })[(oClosestPlatoon[M27PlatoonUtilities.refiCurrentPathTarget] or 1)] or { 0, 0, 0 }), tCurPathPos) > 10 then
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Forcing a refresh of the platoon')
                                                    end
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
                        if not (tIntelPlatoons == nil) and iIntelPlatoons > 0 then
                            local iRemainingScouts = table.getn(tIntelPlatoons)
                            if iRemainingScouts >= 2 then
                                local iSpareScoutsWanted
                                local iMaxScoutsWanted = iScoutsWanted
                                local iFirstPathToCheck = math.max(1, aiBrain[refiCurIntelLineTarget] - 2)
                                local iLastPathToCheck = math.min(table.getn(aiBrain[reftIntelLinePositions]), aiBrain[refiCurIntelLineTarget] + 2)
                                local iCurScoutsWanted
                                --Cycle through previous and next intel paths to see if they need more scouts than current path
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': aiBrain[refiScoutShortfallACU]=' .. aiBrain[refiScoutShortfallACU] .. '; About to loop through previous and next intel paths')
                                end
                                for iCurPathToCheck = iFirstPathToCheck, iLastPathToCheck do
                                    iCurScoutsWanted = table.getn(aiBrain[reftIntelLinePositions][iCurPathToCheck])
                                    if iCurScoutsWanted > iMaxScoutsWanted then
                                        iMaxScoutsWanted = iCurScoutsWanted
                                    end
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
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': aiBrain[refiScoutShortfallACU]=' .. aiBrain[refiScoutShortfallACU] .. '; Have a shortfall of scouts for intel line=' .. aiBrain[refiScoutShortfallIntelLine])
                end
                --Defaults for other scouts wanted - just set to 1 for simplicity

                aiBrain[refiScoutShortfallLargePlatoons] = 1
                aiBrain[refiScoutShortfallAllPlatoons] = 1
                aiBrain[refiScoutShortfallMexes] = 0
                aiBrain[refbNeedScoutPlatoons] = true
            else
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': aiBrain[refiScoutShortfallACU]=' .. aiBrain[refiScoutShortfallACU] .. '; Dont have a shortfall of scouts for intel line so will consider large platoons')
                end
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
                            if not (oPlatoon[M27PlatoonTemplates.refbIdlePlatoon]) then
                                tPlatoonUnits = oPlatoon:GetPlatoonUnits()
                                if M27Utilities.IsTableEmpty(tPlatoonUnits) == false then
                                    iPlatoonUnits = table.getn(tPlatoonUnits)
                                    if (oPlatoon:GetPlan() == 'M27MobileStealth' or oPlatoon:GetPlan() == 'M27Skirmisher' or iPlatoonUnits >= iPlatoonSizeMin) and aiBrain:PlatoonExists(oPlatoon) then
                                        local bPlatoonHasScouts = false
                                        tPlatoonCurrentScouts = EntityCategoryFilterDown(refCategoryLandScout, tPlatoonUnits)
                                        if M27Utilities.IsTableEmpty(tPlatoonCurrentScouts) == false then
                                            bPlatoonHasScouts = true
                                        elseif oPlatoon[refoScoutHelper] and oPlatoon[refoScoutHelper].GetPlatoonUnits then
                                            tPlatoonCurrentScouts = oPlatoon[refoScoutHelper]:GetPlatoonUnits()
                                            if M27Utilities.IsTableEmpty(tPlatoonCurrentScouts) == false then
                                                bPlatoonHasScouts = true
                                            end
                                        end
                                        if bPlatoonHasScouts == false then
                                            --Need scouts in the platoon
                                            if iPlatoonSizeMissingScouts > 0 or iAvailableScouts <= 0 then
                                                --Wont find any more scouts, so just increase
                                                iPlatoonSizeMissingScouts = iPlatoonSizeMissingScouts + 1
                                            else
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': About to get a scout to assign to a large platoon.  Large platoon count=' .. oPlatoon[M27PlatoonUtilities.refiPlatoonCount])
                                                end
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
                        else
                            iSmallPlatoonMissingScouts = iPlatoonSizeMissingScouts
                        end
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
                    local bConsiderOmni = not (M27Utilities.IsTableEmpty(tFriendlyOmni))
                    local bCurPositionInOmniRange
                    local iCurOmniRange
                    local iDistanceWithinOmniWanted = 30
                    local oCurBlueprint
                    local sLocationRef

                    if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftMexesToKeepScoutsBy]) == false then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': have some mexes in the table of mexes that want scouts (tablegetn wont work for this variable)')
                        end
                        for iMex, tMex in aiBrain[M27MapInfo.reftMexesToKeepScoutsBy] do
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Considering tMex=' .. repru(tMex) .. '; iMex=' .. iMex)
                            end
                            if M27Utilities.GetDistanceBetweenPositions(tMex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) > 40 then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Mex is at least 40 away from start')
                                end
                                sLocationRef = iMex --M27Utilities.ConvertLocationToReference(tMex)
                                --Do we have a scout assigned that is still alive?
                                oCurScout = M27Team.tTeamData[aiBrain.M27Team][M27Team.tScoutAssignedToMexLocation][sLocationRef]
                                if oCurScout and not (oCurScout.Dead) and oCurScout.GetUnitId then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Already have a scout assigned to the mex')
                                    end
                                    --Do nothing
                                else
                                    M27Team.tTeamData[aiBrain.M27Team][M27Team.tScoutAssignedToMexLocation][sLocationRef] = nil
                                    --Do we have omni coverage?
                                    bCurPositionInOmniRange = false
                                    if bConsiderOmni then
                                        for iOmni, oOmni in tFriendlyOmni do
                                            iCurOmniRange = 0
                                            if oOmni.GetBlueprint and not (oOmni.Dead) and oOmni.GetFractionComplete and oOmni:GetFractionComplete() == 1 then
                                                oCurBlueprint = oOmni:GetBlueprint()
                                                if oCurBlueprint.Intel and oCurBlueprint.Intel.OmniRadius then
                                                    iCurOmniRange = oCurBlueprint.Intel.OmniRadius
                                                end
                                            end
                                            if iCurOmniRange > 0 then
                                                if M27Utilities.GetDistanceBetweenPositions(oOmni:GetPosition(), tMex) - iCurOmniRange <= iDistanceWithinOmniWanted then
                                                    bCurPositionInOmniRange = true
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    if not (bCurPositionInOmniRange) then
                                        --Try to find a scout to assign
                                        if bNoMoreScouts == false then
                                            oCurScout = GetNearestMAAOrScout(aiBrain, tMex, true, true, true)
                                        else
                                            oCurScout = nil
                                        end
                                        if oCurScout then
                                            M27Team.tTeamData[aiBrain.M27Team][M27Team.tScoutAssignedToMexLocation][sLocationRef] = oCurScout
                                            local iAngleToEnemyBase = M27Utilities.GetAngleFromAToB(tMex, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                                            local tPositionToGuard = M27Utilities.MoveInDirection(tMex, iAngleToEnemyBase, 6) --dont want to block mex or storage, and want to get slight advance warning of enemies
                                            AssignHelperToLocation(aiBrain, oCurScout, tPositionToGuard)
                                        else
                                            bNoMoreScouts = true
                                            iScoutShortfall = iScoutShortfall + 1
                                        end
                                    end
                                end
                            elseif bDebugMessages == true then
                                LOG(sFunctionRef .. ': Mex is within 40 of start so dont want a scout')
                            end
                        end
                    else
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': No mexes that want scouts by')
                        end
                    end
                    aiBrain[refiScoutShortfallMexes] = iScoutShortfall
                end
            end
        else
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': No scouts so will set as needing more scouts for ACU and initial raider')
            end
            aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] = aiBrain[refiInitialRaiderPlatoonsWanted]
            aiBrain[refiScoutShortfallACU] = 1
            aiBrain[refiScoutShortfallPriority] = 1
            aiBrain[refiScoutShortfallIntelLine] = aiBrain[refiMinScoutsNeededForAnyPath]
        end


        if iScouts >= 25 then
            local iNonScouts = aiBrain:GetCurrentUnits(categories.MOBILE * categories.LAND - categories.SCOUT)
            if iScouts > 80 then
                LOG('Have 80 scouts, seems higher than would expect')
                if iScouts > 120 and iScouts > iNonScouts then
                    M27Utilities.ErrorHandler('Warning possible error unless large map or lots of small platoons - more than 25 scouts, but only ' .. iNonScouts .. ' non-scouts; iScouts=' .. iScouts .. '; turning on debug messages.  Still stop producing scouts if get to 100')
                    aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] = 0
                    aiBrain[refiScoutShortfallACU] = 0
                    aiBrain[refiScoutShortfallPriority] = 0
                    aiBrain[refiScoutShortfallIntelLine] = 0
                    aiBrain[refiScoutShortfallLargePlatoons] = 0
                    aiBrain[refiScoutShortfallAllPlatoons] = 0
                    aiBrain[refiScoutShortfallMexes] = 0
                end
            end
        end
        if aiBrain[M27AirOverseer.refbHaveOmniVision] then
            aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] = 0
            aiBrain[refiScoutShortfallACU] = 0
            aiBrain[refiScoutShortfallPriority] = 0
            aiBrain[refiScoutShortfallIntelLine] = 0
            aiBrain[refiScoutShortfallLargePlatoons] = 0
            aiBrain[refiScoutShortfallAllPlatoons] = 0
            aiBrain[refiScoutShortfallMexes] = 0
        end
    end

    if bDebugMessages == true then
        LOG(sFunctionRef .. ':End of code, gametime=' .. GetGameTimeSeconds() .. '; aiBrain[refiScoutShortfallACU]=' .. aiBrain[refiScoutShortfallACU] .. '; aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher]=' .. aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] .. '; aiBrain[refiScoutShortfallIntelLine]=' .. aiBrain[refiScoutShortfallIntelLine])
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RemoveSpareNonCombatUnits(oPlatoon)

    --Removes surplus scouts/MAA from oPlatoon
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RemoveSpareTypeOfUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tAllUnits = oPlatoon:GetPlatoonUnits()
    local tCombatUnits = EntityCategoryFilterDown(categories.DIRECTFIRE + categories.INDIRECTFIRE - categories.SCOUT - M27UnitInfo.refCategoryGroundAA, tAllUnits)
    local tScouts = EntityCategoryFilterDown(categories.SCOUT, tAllUnits)
    local tMAA = EntityCategoryFilterDown(M27UnitInfo.refCategoryMAA, tAllUnits)
    local iCombatUnits = 0
    if not (tCombatUnits == nil) then
        iCombatUnits = table.getn(tCombatUnits)
    end
    local iScouts = 0
    if not (tScouts == nil) then
        iScouts = table.getn(tScouts)
    end
    local iMAA = 0
    if not (tMAA == nil) then
        iMAA = table.getn(tMAA)
    end
    local iMaxScouts = 1 + math.min(iCombatUnits / 16)
    local iMaxMAA = 1 + math.min(iCombatUnits / 6)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': iMaxScouts=' .. iMaxScouts .. '; iScouts=' .. iScouts .. '; oPlatoon count=' .. oPlatoon[M27PlatoonUtilities.refiPlatoonCount])
    end

    local iMaxType, tUnitsOfType, iUnitsOfType
    for iType = 1, 2 do
        if iType == 1 then
            iMaxType = iMaxScouts
            iUnitsOfType = iScouts
            tUnitsOfType = tScouts
        else
            iMaxType = iMaxMAA
            iUnitsOfType = iMAA
            tUnitsOfType = tMAA
        end
        if bDebugMessages == true then
            LOG('start of removal cycle, iType=' .. iType .. '; iMaxType=' .. iMaxType .. '; iUnitsOfType=' .. iUnitsOfType)
        end
        if iMaxType < iUnitsOfType then
            --Remove the scout that's furthest away, and repeat until no scouts
            local iMaxDistToPlatoon
            local tPlatoonPos = M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)
            local iCurDistToPlatoon
            local iFurthestUnit
            for iRemovalCount = 1, iUnitsOfType - iMaxType do
                iMaxDistToPlatoon = 0
                for iCurUnit, oCurUnit in tUnitsOfType do
                    if not (oCurUnit.Dead or oCurUnit:BeenDestroyed()) then
                        iCurDistToPlatoon = M27Utilities.GetDistanceBetweenPositions(oCurUnit:GetPosition(), tPlatoonPos)
                        if iCurDistToPlatoon > iMaxDistToPlatoon then
                            iMaxDistToPlatoon = iCurDistToPlatoon
                            iFurthestUnit = iCurUnit
                        end
                    end
                end
                iUnitsOfType = iUnitsOfType - 1
                M27PlatoonUtilities.RemoveUnitsFromPlatoon(oPlatoon, { tUnitsOfType[iFurthestUnit] }, false)
                table.remove(tUnitsOfType, iFurthestUnit)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Removed unit type ' .. iType .. ' from the platoon. iMaxUnitsOfType=' .. iMaxType .. '; iUnitsOfType=' .. iUnitsOfType)
                end
                if iMaxType >= iUnitsOfType then
                    break
                end
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
        if oPlatoon[refstPrevEnemyThreatGroup] == nil then
            oPlatoon[refstPrevEnemyThreatGroup] = {}
        end
        table.insert(oPlatoon[refstPrevEnemyThreatGroup], 1, oPlatoon[refsEnemyThreatGroup])
        if table.getn(oPlatoon[refstPrevEnemyThreatGroup]) > 10 then
            table.remove(oPlatoon[refstPrevEnemyThreatGroup], 11)
        end
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
        if oEnemyUnit[iArmyIndex] == nil then
            oEnemyUnit[iArmyIndex] = {}
        end
        sOldRef = oEnemyUnit[iArmyIndex][refsEnemyThreatGroup]
        if sOldRef == nil then
            oEnemyUnit[iArmyIndex] = {} --redundancy - once (v64) got error with setting the below line on a boolean
            oEnemyUnit[iArmyIndex][refsEnemyThreatGroup] = {}
        end
        if oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup] == nil then
            oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup] = {}
        end
        table.insert(oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup], 1, sOldRef)
        if table.getn(oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup]) > iThreatGroupMemory then
            table.remove(oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup], iThreatGroupMemory + 1)
        end
        oEnemyUnit[iArmyIndex][refsEnemyThreatGroup] = nil
        oEnemyUnit[iArmyIndex][refbUnitAlreadyConsidered] = nil
        if oEnemyUnit[iArmyIndex][refiAssignedThreat] == nil then
            oEnemyUnit[iArmyIndex][refiAssignedThreat] = 0
        end --Used for torp bombers; not reset since torp bombers are assigned once
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function AddNearbyUnitsToThreatGroup(aiBrain, oEnemyUnit, sThreatGroup, iRadius, iCategory, bMustBeOnLand, bMustBeOnWater, iNavalBlipThreat, bNotFirstTime)
    --Adds oEnemyUnit to sThreatGroup and calls this function on itself again for any units within iRadius that are visible
    --also updates previous threat group references so they know to refer to this threat group
    --if iRadius is 0 then will only add oEnemyUnit to the threat group
    --Add oEnemyUnit to sThreatGroup:
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AddNearbyUnitsToThreatGroup'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iArmyIndex = aiBrain:GetArmyIndex()
    --Only call this if haven't already called this on a unit:
    if oEnemyUnit[iArmyIndex] == nil then
        oEnemyUnit[iArmyIndex] = {}
    end
    if oEnemyUnit[iArmyIndex][refbUnitAlreadyConsidered] == nil then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': sThreatGroup=' .. sThreatGroup .. ': oEnemyUnit=' .. oEnemyUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oEnemyUnit))
        end

        local bNewUnitIsOnRightTerrain
        local bIsOnWater
        local tCurPosition

        if bMustBeOnLand == nil then
            bMustBeOnLand = true
            if bMustBeOnWater == nil then
                bMustBeOnLand = false
            end
        end
        if bMustBeOnWater == nil then
            bMustBeOnWater = false
        end

        --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride, bIncludeAirTorpedo)
        local iCurThreat
        if bMustBeOnWater == true then
            iCurThreat = M27Logic.GetAirThreatLevel(aiBrain, { oEnemyUnit }, true, false, true, false, false, 50, 20, iNavalBlipThreat, iNavalBlipThreat, false)
            oEnemyUnit[iArmyIndex][refiUnitNavalAAThreat] = iCurThreat
            if EntityCategoryContains(M27UnitInfo.refCategoryStructureAA, oEnemyUnit.UnitId) then oEnemyUnit[iArmyIndex][refiUnitNavalAAThreat] = oEnemyUnit[iArmyIndex][refiUnitNavalAAThreat] * 2
            elseif EntityCategoryContains(M27UnitInfo.refCategoryGroundAA, oEnemyUnit.UnitId) then oEnemyUnit[iArmyIndex][refiUnitNavalAAThreat] = oEnemyUnit[iArmyIndex][refiUnitNavalAAThreat] * 1.5
            end
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': bMustBeOnWater is true; Unit=' .. oEnemyUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oEnemyUnit) .. ': iCurThreat=' .. iCurThreat)
            end
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': refbUnitAlreadyConsidered is false, recording unit.  sThreatGroup=' .. sThreatGroup)
        end
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
            if aiBrain[reftEnemyThreatGroup][sThreatGroup][refiTotalThreat] == nil then
                aiBrain[reftEnemyThreatGroup][sThreatGroup][refiTotalThreat] = 0
            end
            aiBrain[reftEnemyThreatGroup][sThreatGroup][refiTotalThreat] = aiBrain[reftEnemyThreatGroup][sThreatGroup][refiTotalThreat] + iCurThreat
        end

        table.insert(aiBrain[reftEnemyThreatGroup][sThreatGroup][refoEnemyGroupUnits], oEnemyUnit)
        aiBrain[reftEnemyThreatGroup][sThreatGroup][refiEnemyThreatGroupUnitCount] = aiBrain[reftEnemyThreatGroup][sThreatGroup][refiEnemyThreatGroupUnitCount] + 1
        aiBrain[reftEnemyThreatGroup][sThreatGroup][refiThreatGroupCategory] = iCategory
        local sBP = oEnemyUnit.UnitId
        local iTechLevel = 1
        if EntityCategoryContains(categories.TECH2, sBP) then
            iTechLevel = 2
        elseif EntityCategoryContains(categories.TECH3, sBP) then
            iTechLevel = 3
        elseif EntityCategoryContains(categories.EXPERIMENTAL, sBP) then
            iTechLevel = 4
        end
        if iTechLevel > aiBrain[reftEnemyThreatGroup][sThreatGroup][refiThreatGroupHighestTech] then
            aiBrain[reftEnemyThreatGroup][sThreatGroup][refiThreatGroupHighestTech] = iTechLevel
        end
        if iTechLevel > aiBrain[refiEnemyHighestTechLevel] then
            aiBrain[refiEnemyHighestTechLevel] = iTechLevel
        end

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Added ' .. sThreatGroup .. ' to aiBrain. refiEnemyThreatGroupUnitCount=' .. aiBrain[reftEnemyThreatGroup][sThreatGroup][refiEnemyThreatGroupUnitCount] .. '; iTechLevel=' .. iTechLevel .. '; bMustBeOnWater=' .. tostring(bMustBeOnWater) .. '; Unit ref=' .. sBP .. M27UnitInfo.GetUnitLifetimeCount(oEnemyUnit))
        end

        --Record details of old enemy threat group references, and the new threat group that they now belong to
        if not (oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup] == nil) then
            local sOldRef
            for iPrevRef, sRef in oEnemyUnit[iArmyIndex][refstPrevEnemyThreatGroup] do
                if not (sRef == nil) then
                    sOldRef = sRef
                    break
                end
            end
            if not (sOldRef == nil) then
                aiBrain[reftUnitGroupPreviousReferences][sOldRef] = sThreatGroup
            end
        end

        --look for nearby units: v15 - removed the recursive part of the logic to see if improves CPU performance
        if not (bNotFirstTime) then
            if iRadius and iRadius > 0 then
                tCurPosition = oEnemyUnit:GetPosition()
                local tNearbyUnits = aiBrain:GetUnitsAroundPoint(iCategory, tCurPosition, iRadius, 'Enemy')
                for iUnit, oUnit in tNearbyUnits do
                    bNewUnitIsOnRightTerrain = true
                    if bMustBeOnLand or bMustBeOnWater then
                        if GetTerrainHeight(tCurPosition[1], tCurPosition[3]) < M27MapInfo.iMapWaterHeight then
                            bIsOnWater = true
                        else
                            bIsOnWater = false
                        end
                        if bIsOnWater == true and bMustBeOnLand == true then
                            bNewUnitIsOnRightTerrain = false
                        elseif bIsOnWater == false and bMustBeOnWater == true then
                            bNewUnitIsOnRightTerrain = false
                        end
                    end

                    if bNewUnitIsOnRightTerrain and M27Utilities.CanSeeUnit(aiBrain, oUnit, true) == true then
                        AddNearbyUnitsToThreatGroup(aiBrain, oUnit, sThreatGroup, iRadius, iCategory, bMustBeOnLand, bMustBeOnWater, iNavalBlipThreat, true)
                    end
                end
                if bMustBeOnLand and M27Utilities.IsTableEmpty(tNearbyUnits) == false then
                    --Get highest range
                    local tMobileLand = EntityCategoryFilterDown(M27UnitInfo.refCategoryLandCombat + M27UnitInfo.refCategoryIndirect, tNearbyUnits)
                    if M27Utilities.IsTableEmpty(tMobileLand) == false then
                        for iUnit, oUnit in tMobileLand do
                            aiBrain[refiHighestMobileLandEnemyRange] = math.max(aiBrain[refiHighestMobileLandEnemyRange], M27UnitInfo.GetUnitMaxGroundRange(oUnit))
                        end
                        if not(aiBrain[refbEnemyHasBuiltSniperbots]) and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategorySniperBot, tMobileLand)) == false then
                            aiBrain[refbEnemyHasBuiltSniperbots] = true
                        end
                    end
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code; threat group threat=' .. (aiBrain[reftEnemyThreatGroup][sThreatGroup][refiTotalThreat] or 'nil'))
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdatePreviousPlatoonThreatReferences(aiBrain, tEnemyThreatGroup)
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdatePreviousPlatoonThreatReferences'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local sPlatoonCurTarget
    for iPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': iPlatoon=' .. iPlatoon)
        end
        sPlatoonCurTarget = oPlatoon[refsEnemyThreatGroup]
        if sPlatoonCurTarget == nil then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': iPlatoon=' .. iPlatoon .. '; sPlatoonCurTarget is nil, checking previous references')
            end
            if not (oPlatoon[refstPrevEnemyThreatGroup] == nil) then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iPlatoon=' .. iPlatoon .. '; refstPrevEnemyThreatGroup size=' .. table.getn(oPlatoon[refstPrevEnemyThreatGroup]))
                end
                for iPrevRef, sPrevRef in oPlatoon[refstPrevEnemyThreatGroup] do
                    if not (sPrevRef == nil) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': iPlatoon=' .. iPlatoon .. '; Have located a previous reference, sPrevRef=' .. sPrevRef)
                        end
                        --Have located a previous ref - check if we have a new reference for this:
                        oPlatoon[refsEnemyThreatGroup] = aiBrain[reftUnitGroupPreviousReferences][sPrevRef]
                        break
                    end
                end
            else
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iPlatoon=' .. iPlatoon .. '; refstPrevEnemyThreatGroup is nil')
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RemoveSpareUnits(oPlatoon, iThreatNeeded, iMinScouts, iMinMAA, oPlatoonToAddTo, bIgnoreIfNearbyEnemies)
    --Remove any units not needed for iThreatNeeded, on assumption remaining units will be merged into oPlatoonToAddTo (so will remove units furthest from that platoon)
    --bIgnoreIfNearbyEnemies (default is yes) is true then won't remove units if have nearby enemies (based on the localised platoon enemy detection)
    --if oPlatoon is army pool then wont remove any of the units

    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RemoveSpareUnits'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iCurUnitThreat = 0
    local iRemainingThreatNeeded = iThreatNeeded
    local bRemoveRemainingUnits = false
    local iScoutsWanted = iMinScouts
    local iMAAWanted = iMinMAA
    local bRemoveCurUnit = false
    local iRetainedThreat = oPlatoon[refiTotalThreat]
    if iRetainedThreat == nil then
        iRetainedThreat = 0
    end
    if oPlatoon and oPlatoon.GetBrain then
        local aiBrain = oPlatoon:GetBrain()
        local oArmyPool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Start pre removal, size of platoon=' .. table.getn(oPlatoon:GetPlatoonUnits()))
        end
        if oPlatoon == oArmyPool then
            M27Utilities.ErrorHandler('Are trying to remove units from the army pool - ignoring')
        else
            if bIgnoreIfNearbyEnemies == nil then
                bIgnoreIfNearbyEnemies = true
            end
            --Do we have any nearby enemies?
            if bDebugMessages == true then
                local sEnemiesInRange = oPlatoon[M27PlatoonUtilities.refiEnemiesInRange]
                if sEnemiesInRange == nil then
                    sEnemiesInRange = 'Unknown'
                end
                LOG(sFunctionRef .. ': EnemiesInRange=' .. sEnemiesInRange)
            end
            if bIgnoreIfNearbyEnemies == false or not (oPlatoon[M27PlatoonUtilities.refiEnemiesInRange] > 0 or oPlatoon[M27PlatoonUtilities.refiEnemyStructuresInRange] > 0) then
                --local iSearchRange = M27Logic.GetUnitMaxGroundRange(oPlatoon[M27PlatoonUtilities.reftCurrentUnits]) * 1.4
                --if iSearchRange < 40 then iSearchRange = 40 end

                local tTargetMergePoint

                local bUseArmyPool = false
                if oPlatoonToAddTo == nil then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Are making use of army pool')
                    end
                    bUseArmyPool = true
                else
                    local iPlatoonToAddToUnits = oPlatoonToAddTo[M27PlatoonUtilities.refiCurrentUnits]
                    if iPlatoonToAddToUnits and iPlatoonToAddToUnits > 0 then
                        local tPlatoonUnits = oPlatoonToAddTo:GetPlatoonUnits()
                        if M27Utilities.IsTableEmpty(tPlatoonUnits) == true then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': will be making use of army pool')
                            end
                            bUseArmyPool = true
                        end
                    else
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': so will use army pool')
                        end
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
                    if oPlatoonToAddTo and oPlatoonToAddTo.GetPlan then
                        sPlan = oPlatoonToAddTo:GetPlan()
                    end
                    LOG(sFunctionRef .. ': ' .. sPlan .. ': Warning - PlatoonPosition is nil, attempting custom getaverageposition if platoon has any units')
                    if oPlatoonToAddTo.GetPlatoonUnits then
                        local tNewPlatoonUnits = oPlatoonToAddTo:GetPlatoonUnits()
                        if M27Utilities.IsTableEmpty(tNewPlatoonUnits) == false then
                            LOG(sFunctionRef .. ': ' .. sPlan .. ': About to get average position')
                            tTargetMergePoint = GetAveragePosition(tNewPlatoonUnits)
                        else
                            LOG(sFunctionRef .. ': tNewPlatoonUnits is empty, so platoon doesnt have any units in it')
                        end
                    end
                    if tTargetMergePoint == nil then
                        M27Utilities.ErrorHandler('tTargetMergePoint is nil; will replace with player start position')
                        if oPlatoonToAddTo and oPlatoonToAddTo.GetPlan then
                            LOG(sFunctionRef .. ': Platoon to add to=' .. oPlatoonToAddTo:GetPlan())
                        end
                        if oPlatoonToAddTo[M27PlatoonUtilities.refiPlatoonCount] then
                            LOG(sFunctionRef .. ': PlatoonCount=' .. oPlatoonToAddTo[M27PlatoonUtilities.refiPlatoonCount])
                        end
                        if oPlatoonToAddTo == aiBrain:GetPlatoonUniquelyNamed('ArmyPool') then
                            LOG(sFunctionRef .. ' Trying to merge into Armypool - maybe ArmyPool doesnt work for get platoon position')
                        end
                        if not (oPlatoonToAddTo) then
                            LOG(sFunctionRef .. ': oPlatoonToAddTo is nil')
                        end
                        tTargetMergePoint = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                    else
                        LOG(sFunctionRef .. ': Warning - oPlatoonToAddTo:GetPlatoonPosition returned nil value, but GetAveragePosition gave a value; if this triggers lots then investigate further why')
                    end
                end
                --First remove spare scouts (duplicates later call in overseer to help reduce cases where get into constant cycle of removing scout, falling below threat threshold, re-adding scout to go above, then removing again)
                RemoveSpareNonCombatUnits(oPlatoon)
                local tUnits = oPlatoon:GetPlatoonUnits()
                local tUnitPos = {}
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': About to cycle through units in platoon to remove spare ones; size of tUnits=' .. table.getn(tUnits))
                end
                if M27Utilities.IsTableEmpty(tUnits) == false then
                    for iCurUnit, oUnit in tUnits do
                        if oUnit == M27Utilities.GetACU(aiBrain) then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': oPlatoon includes ACU')
                            end
                        end
                        tUnitPos = oUnit:GetPosition()
                        if not (tUnitPos == nil) then
                            oUnit[refiActualDistanceFromEnemy] = M27Utilities.GetDistanceBetweenPositions(tTargetMergePoint, oUnit:GetPosition())
                        else
                            M27Utilities.ErrorHandler('tUnitPos is nil; iCurUnit=' .. iCurUnit .. '; oPlatoon plan+count=' .. oPlatoon:GetPlan() .. oPlatoon[M27PlatoonUtilities.refiPlatoonCount])
                            oUnit[refiActualDistanceFromEnemy] = 10000
                        end
                    end
                    for iCurUnit, oUnit in M27Utilities.SortTableBySubtable(tUnits, refiActualDistanceFromEnemy, true) do
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': iCurUnit=' .. iCurUnit .. '; checking if unit is valid')
                        end
                        --GetCombatThreatRating(aiBrain, tUnits, bUseBlip, iMassValueOfBlipsOverride)
                        if oUnit.GetUnitId and not (oUnit.Dead) and not (oUnit:BeenDestroyed()) then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': iCurUnit=' .. iCurUnit .. '; Distance from platoon=' .. oUnit[refiActualDistanceFromEnemy])
                            end
                            if bRemoveRemainingUnits == false then
                                iCurUnitThreat = M27Logic.GetCombatThreatRating(oPlatoon:GetBrain(), { oUnit }, false)
                                iRemainingThreatNeeded = iRemainingThreatNeeded - iCurUnitThreat
                                iRetainedThreat = iRetainedThreat + iCurUnitThreat
                                if iRemainingThreatNeeded < 0 then
                                    bRemoveRemainingUnits = true
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Retaining unit with ID=' .. oUnit.UnitId .. 'and iCurUnitThreat=' .. iCurUnitThreat .. '; iRemainingThreatNeeded=' .. iRemainingThreatNeeded .. '; bRemoveRemainingUnits=' .. tostring(bRemoveRemainingUnits))
                                end
                            else
                                bRemoveCurUnit = true
                                if iScoutsWanted > 0 then
                                    if EntityCategoryContains(categories.SCOUT, oUnit.UnitId) == true then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Not removing unit as its a scout and we need a scout')
                                        end
                                        iScoutsWanted = iScoutsWanted - 1
                                        iRetainedThreat = iRetainedThreat + M27Logic.GetCombatThreatRating(oPlatoon:GetBrain(), { oUnit }, false)
                                        bRemoveCurUnit = false
                                    end
                                end
                                if iMAAWanted > 0 then
                                    if EntityCategoryContains(M27UnitInfo.refCategoryMAA, oUnit.UnitId) == true then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Not removing unit as its a MAA and we need a MAA')
                                        end
                                        iMAAWanted = iMAAWanted - 1
                                        iRetainedThreat = iRetainedThreat + M27Logic.GetCombatThreatRating(oPlatoon:GetBrain(), { oUnit }, false)
                                        bRemoveCurUnit = false
                                    end
                                end
                                if bRemoveCurUnit == true then
                                    M27PlatoonUtilities.RemoveUnitsFromPlatoon(oPlatoon, { oUnit }, false, oPlatoonToAddTo)
                                end
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
    oCopyToPlatoon[reftFrontPosition] = oCopyFromPlatoon[reftFrontPosition]
    oCopyToPlatoon[refiActualDistanceFromEnemy] = oCopyFromPlatoon[refiActualDistanceFromEnemy]
    oCopyToPlatoon[refiDistanceFromOurBase] = oCopyFromPlatoon[refiDistanceFromOurBase]
    oCopyToPlatoon[refiModDistanceFromOurStart] = oCopyFromPlatoon[refiModDistanceFromOurStart]
end

function RecordAvailablePlatoonAndReturnValues(aiBrain, oPlatoon, iAvailableThreat, iCurAvailablePlatoons, tCurPos, iDistFromEnemy, iDistToOurBase, tAvailablePlatoons, tNilDefenderPlatoons, bIndirectThreatOnly)
    --Used by ThreatAssessAndRespond - Split out into this function as used in 2 places so want to make sure any changes are reflected in both
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
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
        if bDebugMessages == true then
            LOG(sFunctionRef .. '; Platoon=' .. oPlatoon:GetPlan() .. ': Total threat of platoon=' .. oRecordedPlatoon[refiTotalThreat] .. '; number of units in platoon=' .. table.getn(oRecordedPlatoon:GetPlatoonUnits()))
        end
        iAvailableThreat = iAvailableThreat + oRecordedPlatoon[refiTotalThreat]
        iCurAvailablePlatoons = iCurAvailablePlatoons + 1
        tAvailablePlatoons[iCurAvailablePlatoons] = {}
        tAvailablePlatoons[iCurAvailablePlatoons] = oRecordedPlatoon
        --if oRecordedPlatoon == oArmyPoolPlatoon then
        --[[--Create new defenderAI platoon that includes mobile land combat units from oArmyPoolPlatoon
            oRecordedPlatoon[reftFrontPosition] = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
            oRecordedPlatoon[refiActualDistanceFromEnemy] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
            oRecordedPlatoon[refiModDistanceFromOurStart] = 0
            bArmyPoolInAvailablePlatoons = true]]--
        --else
        oRecordedPlatoon[reftFrontPosition] = tCurPos
        oRecordedPlatoon[refiActualDistanceFromEnemy] = iDistFromEnemy
        oRecordedPlatoon[refiDistanceFromOurBase] = iDistToOurBase
        oRecordedPlatoon[refiModDistanceFromOurStart] = GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tCurPos)
        if oRecordedPlatoon[refsEnemyThreatGroup] == nil then
            local iNilPlatoonCount = table.getn(tNilDefenderPlatoons)
            if iNilPlatoonCount == nil then
                iNilPlatoonCount = 0
            end
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

    --if aiBrain:GetArmyIndex() == 3 then bDebugMessages = true end

    --if GetGameTimeSeconds() >= 245 then bDebugMessages = true end

    --Key config variables:
    --v14 and earlier values:
    --local iLandThreatGroupDistance = 20 --Units this close to each other get included in the same threat group
    --local iNavyThreatGroupDistance = 30
    --v15 values since moving to a simpler (less accurate) threat detection approach
    local iLandThreatGroupDistance = 50
    local iNavyThreatGroupDistance = 80
    local iThreatGroupDistance
    if aiBrain[refiEnemyHighestTechLevel] > 1 then
        iNavyThreatGroupDistance = 100
    end
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
    aiBrain[refbEnemyHasSeraDestroyers] = false
    --Do we have air control/immediate air threats? If not, then limit search range to 200
    if not (aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill) and aiBrain[M27AirOverseer.refiAirAANeeded] > 0 then
        iNavySearchRange = math.min(iNavySearchRange, 200)
    end
    --If have a chokepoint firebase then increase navy search range to be 150 above this
    if aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef] then
        iNavySearchRange = math.max(iNavySearchRange, M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27MapInfo.reftChokepointBuildLocation]) + 150)
    end

    --Reset check of locations of threat groups threatening mexes and naval threat
    aiBrain[reftEnemyGroupsThreateningBuildings] = {}
    aiBrain[refbT2NavyNearOurBase] = false
    aiBrain[refiNearestT2PlusNavalThreat] = 10000

    local oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')

    local refCategoryMobileLand = categories.LAND * categories.MOBILE

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': About to reset enemy threat groups')
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Getting ACU platoon and action')
        DebugPrintACUPlatoon(aiBrain)
    end
    iCurThreatGroup = 0
    local tEnemyUnits
    local iTMDAndShieldSearchRange = 25 --If dealing with T2+ PD will look for nearby shields and TMD
    local iT2ArtiSearchRange = 50 --Will look for nearby T2 arti within this range
    local iNavyUnitCategories = M27UnitInfo.refCategoryNavyThatCanBeTorpedoed
    local tCategoriesToSearch = { refCategoryMobileLand, M27UnitInfo.refCategoryPD + (M27UnitInfo.refCategoryStructure - categories.TECH1) }
    if M27MapInfo.bMapHasWater == true then
        tCategoriesToSearch = { refCategoryMobileLand, M27UnitInfo.refCategoryPD + (M27UnitInfo.refCategoryStructure - categories.TECH1), iNavyUnitCategories }
    end

    local iCategoryTypeLand = 1
    local iCategoryTypeStructure = 2
    local iCategoryTypeNavy = 3
    ResetEnemyThreatGroups(aiBrain, math.max(iNavySearchRange, iLandThreatSearchRange), tCategoriesToSearch)
    local bConsideringNavy
    local bUnitOnWater, tEnemyUnitPos
    local iCurThreat, iSearchRange
    local iCumulativeTorpBomberThreatShortfall = 0
    --Record how many torp bombers we want
    local oACU = M27Utilities.GetACU(aiBrain)
    local bACUNeedsTorpSupport = false
    if GetGameTimeSeconds() - (oACU[refiACULastTakenUnseenOrTorpedoDamage] or -100) <= 60 and M27UnitInfo.IsUnitUnderwater(oACU) and M27UnitInfo.IsUnitValid(oACU[refoUnitDealingUnseenDamage]) and EntityCategoryContains(categories.ANTINAVY + categories.OVERLAYANTINAVY, oACU[refoUnitDealingUnseenDamage].UnitId) then
        iCumulativeTorpBomberThreatShortfall = iCumulativeTorpBomberThreatShortfall + 1500
        bACUNeedsTorpSupport = true
    end
    local iTorpBomberThreatNotUsed = 0 --If skip attacking units due to being too far away then record here so we dont think we have no shortfall
    local tiMaxTorpBomberRangeByPond = {}
    local oPondNavalFac
    local bHaveValidLocation
    local iHardCapOnTorpRange = 10000

    local tAllRecentlySeenCruisers = {}
    local iClosestRecentlySeenCruiser = 10000
    local iRangeReduction = 50



    --Do we have a naval factory in the pond? If so then limit torp bomber range
    if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.refiEnemyNavalThreatByPond]) == false then
        for iPond, iThreat in M27Team.tTeamData[aiBrain.M27Team][M27Team.refiEnemyNavalThreatByPond] do
            bHaveValidLocation = false
            if iThreat > 0 then
                oPondNavalFac = M27Navy.GetPrimaryNavalFactory(aiBrain, iPond)
                if not(M27UnitInfo.IsUnitValid(oPondNavalFac)) then
                    --We have lost navy so dont want to cap torp bomber range
                    tiMaxTorpBomberRangeByPond[iPond] = 10000
                else
                    --We have a naval fac so cap range - take hte midpoint between enemy fac and our fac, and then cap range at dist from here to our base

                    if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyBaseLocationByPond][iPond]) == false then
                        bHaveValidLocation = true
                        tiMaxTorpBomberRangeByPond[iPond] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27Utilities.MoveTowardsTarget(oPondNavalFac:GetPosition(), M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyBaseLocationByPond][iPond], M27Utilities.GetDistanceBetweenPositions(oPondNavalFac:GetPosition(), M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyBaseLocationByPond][iPond]), 0))
                    end
                    if not(bHaveValidLocation) then
                        tiMaxTorpBomberRangeByPond[iPond] = 10000
                    end
                end
            end


            --Add any pond AA recently seen but not currently visible to this
            if bDebugMessages == true then LOG(sFunctionRef..': Is table of enemy untis by pond empty='..tostring(M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond]))) end
            if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond]) == false then
                local tEnemyUnits = M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond][iPond]
                if bDebugMessages == true then LOG(sFunctionRef..': Considering iPond='..iPond..'; is table of enemy units empty for this='..tostring(M27Utilities.IsTableEmpty(tEnemyUnits))) end
                if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                    local tEnemyT2PlusNavalAA = EntityCategoryFilterDown(M27UnitInfo.refCategoryCruiserCarrier, M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond][iPond])
                    if bDebugMessages == true then LOG(sFunctionRef..': Is table of cruisers and carriers empty='..tostring(M27Utilities.IsTableEmpty(tEnemyT2PlusNavalAA))) end
                    if M27Utilities.IsTableEmpty(tEnemyT2PlusNavalAA) == false then
                        for iUnit, oUnit in tEnemyT2PlusNavalAA do
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering enemy unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Is valid='..tostring(M27UnitInfo.IsUnitValid(oUnit))..'; Is last known position empty='..tostring(M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftLastKnownPosition]))..'; Can see unit='..tostring(M27Utilities.CanSeeUnit(aiBrain, oUnit, true))) end
                            if M27UnitInfo.IsUnitValid(oUnit) and M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftLastKnownPosition]) == false and not(M27Utilities.CanSeeUnit(aiBrain, oUnit, true)) then
                                if M27Utilities.GetDistanceBetweenPositions(oUnit[M27UnitInfo.reftLastKnownPosition], oUnit:GetPosition()) <= iRangeReduction then --approximation for human memory
                                    iClosestRecentlySeenCruiser = math.min(iClosestRecentlySeenCruiser, GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit[M27UnitInfo.reftLastKnownPosition]))
                                end
                                table.insert( tAllRecentlySeenCruisers, oUnit) --Include even if distance is further from last known position as we sitll know they have the unit so want to build more torp bombers, even if we dont want to limit our combat range
                            end
                        end
                    end
                end
            end


            if bHaveValidLocation then
                tiMaxTorpBomberRangeByPond[iPond] = math.min(iClosestRecentlySeenCruiser - iRangeReduction, math.max(tiMaxTorpBomberRangeByPond[iPond], 200, aiBrain[refiDistanceToNearestEnemyBase] * 0.25))
                --Increase range if ACU needs torp support
                if bACUNeedsTorpSupport then tiMaxTorpBomberRangeByPond[iPond] = math.max(50 + M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]), tiMaxTorpBomberRangeByPond[iPond]) end
            end
        end
    end





    if bDebugMessages == true then
        LOG(sFunctionRef .. ': bACUNeedsTorpSupport=' .. tostring(bACUNeedsTorpSupport) .. '; Time ACU last took torp damage=' .. GetGameTimeSeconds() - (oACU[refiACULastTakenUnseenOrTorpedoDamage] or -100)..'; riMaxTorpBomberRangeByPond='..repru(tiMaxTorpBomberRangeByPond))
    end

    local bFirstUnassignedNavyThreat = true
    local iNavalBlipThreat = 300 --Frigate

    local bFirstThreatGroup = true
    local tiOurBasePathingGroup = { [M27UnitInfo.refPathingTypeLand] = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]), [M27UnitInfo.refPathingTypeAmphibious] = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) }
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': tiOurBasePathingGroup=' .. repru(tiOurBasePathingGroup))
    end
    local sPathing
    local bCanPathToTarget

    aiBrain[refoNearestThreat] = nil
    aiBrain[refoNearestEnemyT2PlusStructure] = nil
    aiBrain[refiNearestEnemyT2PlusStructure] = 10000

    if aiBrain[refiEnemyHighestTechLevel] > 1 then
        iNavalBlipThreat = 2000 --Cruiser
    end
    for iEntry, iCategory in tCategoriesToSearch do
        bConsideringNavy = false
        iSearchRange = iLandThreatSearchRange
        if iEntry == iCategoryTypeNavy then
            bConsideringNavy = true
            iSearchRange = iNavySearchRange
        elseif iEntry == iCategoryTypeStructure then
            sPathing = M27UnitInfo.refPathingTypeLand
        else
            if aiBrain[refiOurHighestFactoryTechLevel] >= 2 or aiBrain:GetFactionIndex() == M27UnitInfo.refFactionAeon or aiBrain:GetFactionIndex() == M27UnitInfo.refFactionSeraphim then
                --shoudl have access to amphibious units
                sPathing = M27UnitInfo.refPathingTypeAmphibious
            else
                sPathing = M27UnitInfo.refPathingTypeLand
            end
        end
        iThreatGroupDistance = iLandThreatGroupDistance
        if bConsideringNavy == true then
            iThreatGroupDistance = iNavyThreatGroupDistance
        end

        --Ignore threats if norush is active
        if M27MapInfo.bNoRushActive then
            tEnemyUnits = nil
        else
            tEnemyUnits = aiBrain:GetUnitsAroundPoint(iCategory, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iSearchRange, 'Enemy')
        end

        if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
            for iCurEnemy, oEnemyUnit in tEnemyUnits do
                tEnemyUnitPos = oEnemyUnit:GetPosition()
                bUnitOnWater = false
                if GetTerrainHeight(tEnemyUnitPos[1], tEnemyUnitPos[3]) < M27MapInfo.iMapWaterHeight then
                    bUnitOnWater = true
                end

                --Are we on/not on water?
                if bUnitOnWater == bConsideringNavy then
                    --either on water and considering navy, or not on water and not considering navy
                    --Can we see enemy unit/blip:
                    --function CanSeeUnit(aiBrain, oUnit, bBlipOnly)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': iCurEnemy=' .. iCurEnemy .. ' - about to see if can see the unit and get its threat. Enemy Unit ID=' .. oEnemyUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oEnemyUnit) .. '; Position=' .. repru(oEnemyUnit:GetPosition()))
                    end
                    if M27Utilities.CanSeeUnit(aiBrain, oEnemyUnit, true) == true then
                        if oEnemyUnit[iArmyIndex] == nil then
                            oEnemyUnit[iArmyIndex] = {}
                        end
                        if oEnemyUnit[iArmyIndex][refsEnemyThreatGroup] == nil then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Enemy unit doesnt have a threat group')
                            end
                            --enemy unit hasn't been assigned a threat group - assign it to one now if it's not already got a threat group:
                            if not (oEnemyUnit[iArmyIndex][refbUnitAlreadyConsidered] == true) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Havent already considered the unit; sPathing=' .. sPathing .. '; position=' .. repru(oEnemyUnit:GetPosition()) .. '; Pathing group=' .. M27MapInfo.GetSegmentGroupOfLocation(sPathing, oEnemyUnit:GetPosition()))
                                end
                                --Can we path to the threat group?
                                bCanPathToTarget = false
                                if bConsideringNavy or tiOurBasePathingGroup[sPathing] == M27MapInfo.GetSegmentGroupOfLocation(sPathing, oEnemyUnit:GetPosition()) then
                                    bCanPathToTarget = true
                                elseif iEntry == iCategoryTypeStructure then
                                    --If we travel from the target towards our base and at 45 degree angles (checking 5 points in total) can any of them path there?
                                    local iRangeToCheck = 30 + 2
                                    if aiBrain[refiMinIndirectTechLevel] == 2 then
                                        iRangeToCheck = 60 + 2
                                    elseif aiBrain[refiMinIndirectTechLevel] >= 3 then
                                        iRangeToCheck = 90 + 2
                                    end
                                    local iBaseAngle = M27Utilities.GetAngleFromAToB(oEnemyUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                    local tPossibleFiringPoint

                                    for iAngleOffset = -90, 90, 45 do
                                        tPossibleFiringPoint = M27Utilities.MoveInDirection(oEnemyUnit:GetPosition(), iBaseAngle + iAngleOffset, iRangeToCheck)
                                        if M27MapInfo.GetSegmentGroupOfLocation(sPathing, tPossibleFiringPoint) == tiOurBasePathingGroup[sPathing] then
                                            bCanPathToTarget = true
                                            break
                                        end
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Cant path to tPossibleFiringPoint=' .. repru(tPossibleFiringPoint))
                                            M27Utilities.DrawLocation(tPossibleFiringPoint)
                                        end
                                    end
                                end
                                if bCanPathToTarget then
                                    iCurThreatGroup = iCurThreatGroup + 1
                                    sThreatGroup = 'M27' .. iGameTime .. 'No' .. iCurThreatGroup
                                    oEnemyUnit[iArmyIndex][refsEnemyThreatGroup] = sThreatGroup
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': iCurEnemy=' .. iCurEnemy .. ' - about to add unit to threat group ' .. sThreatGroup)
                                    end
                                    AddNearbyUnitsToThreatGroup(aiBrain, oEnemyUnit, sThreatGroup, iThreatGroupDistance, iCategory, not (bConsideringNavy), bConsideringNavy, iNavalBlipThreat)
                                    --Add nearby structures to threat rating if dealing with structures and enemy has T2+ PD near them
                                    --v59 - removed as have expanded initial threat to cover T2 structures not just T2 PD
                                    --[[if iEntry == iCategoryTypeStructure and oEnemyUnit[iArmyIndex][refsEnemyThreatGroup][refiThreatGroupHighestTech] >= 2 then
                                        local tNearbyDefensiveStructures = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryTMD * categories.STRUCTURE + M27UnitInfo.refCategoryFixedShield, tEnemyUnitPos, iTMDAndShieldSearchRange, 'Enemy')
                                        if M27Utilities.IsTableEmpty(tNearbyDefensiveStructures) == false then
                                            for iDefence, oDefenceUnit in tNearbyDefensiveStructures do
                                                if not (oDefenceUnit.Dead) then
                                                    --AddNearbyUnitsToThreatGroup(aiBrain, oEnemyUnit, sThreatGroup, iRadius, iCategory, bMustBeOnLand, bMustBeOnWater, iNavalBlipThreat, bNotFirstTime)
                                                    AddNearbyUnitsToThreatGroup(aiBrain, oDefenceUnit, sThreatGroup, 0, iCategory)
                                                end
                                            end
                                        end
                                        local tNearbyT2Arti = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti, tEnemyUnitPos, iT2ArtiSearchRange, 'Enemy')
                                        if M27Utilities.IsTableEmpty(tNearbyT2Arti) == false then
                                            for iDefence, oDefenceUnit in tNearbyT2Arti do
                                                if not (oDefenceUnit.Dead) then
                                                    --AddNearbyUnitsToThreatGroup(aiBrain, oEnemyUnit, sThreatGroup, iRadius, iCategory, bMustBeOnLand, bMustBeOnWater, iNavalBlipThreat, bNotFirstTime)
                                                    AddNearbyUnitsToThreatGroup(aiBrain, oDefenceUnit, sThreatGroup, 0, iCategory)
                                                end
                                            end
                                        end
                                    end--]]
                                elseif bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Cant path to enemy unit=' .. oEnemyUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oEnemyUnit))
                                end
                            elseif bDebugMessages == true then
                                LOG(sFunctionRef .. ': Unit already has a threat group')
                            end
                        else
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Enemy unit already has a threat group=' .. oEnemyUnit[iArmyIndex][refsEnemyThreatGroup])
                            end
                        end
                    else
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Cant see the unit')
                        end
                    end
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Finished going through enemy units, iCurThreatGroup=' .. iCurThreatGroup)
    end

    --Cycle through each threat group, record threat, average position, and distance to our base
    if iCurThreatGroup > 0 then
        --oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
        oACU = M27Utilities.GetACU(aiBrain)
        if oACU then
            tACUPos = oACU:GetPosition()
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': tACUPos=' .. repru(tACUPos))
            end

            local bCheckForACUFlanking = false
            local iThreatThresholdHigh, iThreatThresholdLow
            oACU[reftPotentialFlankingUnits] = {}
            oACU[refbInDangerOfBeingFlanked] = false
            local iACUModDistFromBase = GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oACU:GetPosition())
            local iACUActualDistFromBase = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            local iDistFromThreatGroupToACU
            if not(aiBrain[refiDefaultStrategy] == refStrategyTurtle) and iACUModDistFromBase > 100 and oACU.PlatoonHandle[M27PlatoonUtilities.refiEnemySearchRadius] <= 100 and iACUActualDistFromBase >= math.min(200, aiBrain[refiDistanceToNearestEnemyBase] * 0.35) then
                if not(M27Conditions.DoesACUHaveBigGun(aiBrain, oACU)) then
                    bCheckForACUFlanking = true
                    if M27Conditions.DoesACUHaveGun(aiBrain, false, oACU) then
                        if M27UnitInfo.GetNumberOfUpgradesObtained(oACU) >= 3 then
                            iThreatThresholdHigh = 2400
                            iThreatThresholdLow = 2000
                        else
                            iThreatThresholdHigh = 1000
                            iThreatThresholdLow = 800
                        end
                    else
                        iThreatThresholdHigh = 500
                        iThreatThresholdLow = 400
                    end
                end

                if bCheckForACUFlanking then
                end
            end
            --if bDebugMessages == true then LOG(sFunctionRef..': ACU ID='..oACU.UnitId) end
            for iCurGroup, tEnemyThreatGroup in aiBrain[reftEnemyThreatGroup] do
                UpdatePreviousPlatoonThreatReferences(aiBrain, tEnemyThreatGroup)
                bConsideringNavy = false
                if tEnemyThreatGroup[refiThreatGroupCategory] == iNavyUnitCategories then
                    bConsideringNavy = true
                end
                --function GetCombatThreatRating(aiBrain, tUnits, bUseBlip, iMassValueOfBlipsOverride)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Finished updating previous platoon threat references; iCurGroup=' .. iCurGroup .. ';  through enemy units, iCurThreatGroup=' .. iCurThreatGroup .. '; bConsideringNavy=' .. tostring(bConsideringNavy))
                end
                if bDebugMessages == true then
                    LOG('Units in tEnemyThreatGroup=' .. table.getn(tEnemyThreatGroup[refoEnemyGroupUnits]) .. '; reference of first unit=' .. tEnemyThreatGroup[refoEnemyGroupUnits][1].UnitId .. M27UnitInfo.GetUnitLifetimeCount(tEnemyThreatGroup[refoEnemyGroupUnits][1]))
                end
                --GetCombatThreatRating(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, iMassValueOfBlipsOverride, iSoloBlipMassOverride, bIndirectFireThreatOnly, bJustGetMassValue)
                if bConsideringNavy == true then
                    --Already recorded naval AA threat when added individual units to the threat group
                    iCurThreat = tEnemyThreatGroup[refiTotalThreat]
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Considering navy, so will use the enemy threat group total threat already recorded=' .. (tEnemyThreatGroup[refiTotalThreat] or 0))
                    end
                else
                    iCurThreat = M27Logic.GetCombatThreatRating(aiBrain, tEnemyThreatGroup[refoEnemyGroupUnits], true)

                    --Note: This gets adjusted further below
                end

                tEnemyThreatGroup[refiTotalThreat] = math.max(10, iCurThreat)
                --tEnemyThreatGroup[reftFrontPosition] = M27Utilities.GetAveragePosition(tEnemyThreatGroup[refoEnemyGroupUnits])
                tEnemyThreatGroup[reftFrontPosition] = M27Utilities.GetNearestUnit(tEnemyThreatGroup[refoEnemyGroupUnits], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]):GetPosition()

                --Increase threat for non-navy non-structure groups if we've seen the enemy ACU and think it's near and threat group doesn't include ACU
                if not(bConsideringNavy) and iCurThreat > 0 and M27Utilities.IsTableEmpty(aiBrain[reftLastNearestACU]) == false and M27UnitInfo.IsUnitValid(aiBrain[refoLastNearestACU]) and EntityCategoryContains(categories.COMMAND + categories.STRUCTURE, aiBrain[refoLastNearestACU].UnitId) and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.COMMAND, tEnemyThreatGroup[refoEnemyGroupUnits])) then
                    if M27Utilities.GetDistanceBetweenPositions(tEnemyThreatGroup[reftFrontPosition], aiBrain[reftLastNearestACU]) <= 60 then
                        iCurThreat = iCurThreat + M27Logic.GetCombatThreatRating(aiBrain, { aiBrain[refoLastNearestACU] }, false)
                    end
                end

                tEnemyThreatGroup[refiDistanceFromOurBase] = M27Utilities.GetDistanceBetweenPositions(tEnemyThreatGroup[reftFrontPosition], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                tEnemyThreatGroup[refiModDistanceFromOurStart] = GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tEnemyThreatGroup[reftFrontPosition])
                if tEnemyThreatGroup[refiHighestThreatRecorded] == nil or tEnemyThreatGroup[refiHighestThreatRecorded] < tEnemyThreatGroup[refiTotalThreat] then
                    tEnemyThreatGroup[refiHighestThreatRecorded] = tEnemyThreatGroup[refiTotalThreat]
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iCurGroup=' .. iCurGroup .. '; refiHighestThreatRecorded=' .. tEnemyThreatGroup[refiHighestThreatRecorded] .. '; refiTotalThreat=' .. tEnemyThreatGroup[refiTotalThreat] .. '; Actual distance to base=' .. M27Utilities.GetDistanceBetweenPositions(tEnemyThreatGroup[reftFrontPosition], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) .. '; Mod distance=' .. tEnemyThreatGroup[refiModDistanceFromOurStart])
                end

                tEnemyDistanceForSorting[iCurGroup] = {}
                tEnemyDistanceForSorting[iCurGroup] = tEnemyThreatGroup[refiModDistanceFromOurStart]

            end

            --Sort threat groups by distance to our base:
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': About to sort table of enemy threat groups')
            end
            if bDebugMessages == true then
                LOG('Threat groups before sorting:')
                for i1, o1 in aiBrain[reftEnemyThreatGroup] do
                    LOG('i1=' .. i1 .. '; o1.refiModDistanceFromOurStart=' .. o1[refiModDistanceFromOurStart] .. '; threat group threat=' .. o1[refiTotalThreat])
                end
            end

            aiBrain[refbNeedDefenders] = false
            aiBrain[refbNeedIndirect] = false
            aiBrain[refiMinIndirectTechLevel] = 1
            local iTotalEnemyThreatGroups = table.getn(aiBrain[reftEnemyThreatGroup])
            local bPlatoonHasRelevantUnits
            local bIndirectThreatOnly
            local bIgnoreRemainingLandThreats = false

            local iDefaultEnemySearchRange = math.min(105, math.max(20 + 15 * aiBrain[refiEnemyHighestTechLevel], aiBrain[refiHighestMobileLandEnemyRange]))

            for iEnemyGroup, tEnemyThreatGroup in M27Utilities.SortTableBySubtable(aiBrain[reftEnemyThreatGroup], refiModDistanceFromOurStart, true) do
                if bDebugMessages == true then LOG(sFunctionRef..': Considering threat group '..iEnemyGroup..'; Do we already have a valid refoNearestEnemyT2PlusStructure='..tostring(M27UnitInfo.IsUnitValid(aiBrain[refoNearestEnemyT2PlusStructure]))..'; Does threat group contain t2 buildings='..tostring(M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryStructure - categories.TECH1, tEnemyThreatGroup[refoEnemyGroupUnits])))) end
                if not(aiBrain[refoNearestEnemyT2PlusStructure]) then
                    local tEnemyT2PlusBuildings = EntityCategoryFilterDown(M27UnitInfo.refCategoryStructure - categories.TECH1, tEnemyThreatGroup[refoEnemyGroupUnits])
                    if M27Utilities.IsTableEmpty(tEnemyT2PlusBuildings) == false then
                        aiBrain[refoNearestEnemyT2PlusStructure] = M27Utilities.GetNearestUnit(tEnemyT2PlusBuildings, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain)
                        if not(aiBrain[refoNearestEnemyT2PlusStructure].IsCivilian) and not(M27Logic.IsCivilianBrain(aiBrain[refoNearestEnemyT2PlusStructure]:GetAIBrain())) then
                            aiBrain[refiNearestEnemyT2PlusStructure] = M27Utilities.GetDistanceBetweenPositions(aiBrain[refoNearestEnemyT2PlusStructure]:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                        else
                            aiBrain[refoNearestEnemyT2PlusStructure] = nil --Nearest building is civilian so ignore
                        end
                    end
                    --M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryStructure - categories.TECH1, tEnemyThreatGroup[
                end
                if bFirstThreatGroup then
                    bFirstThreatGroup = false
                    aiBrain[refiModDistFromStartNearestThreat] = tEnemyThreatGroup[refiModDistanceFromOurStart]
                    local oFirstUnit = M27Utilities.GetNearestUnit(tEnemyThreatGroup[refoEnemyGroupUnits], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain, nil, nil)
                    aiBrain[reftLocationFromStartNearestThreat] = oFirstUnit:GetPosition()
                    aiBrain[refoNearestThreat] = oFirstUnit
                    if bDebugMessages == true then LOG(sFunctionRef..': First enemy threat group, mod dist from our start='..tEnemyThreatGroup[refiModDistanceFromOurStart]..'; first unit='..oFirstUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oFirstUnit)..'; dist from first unit to our start='..M27Utilities.GetDistanceBetweenPositions(oFirstUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) end
                end
                bIndirectThreatOnly = false
                bConsideringNavy = false
                if tEnemyThreatGroup[refiThreatGroupCategory] == tCategoriesToSearch[iCategoryTypeStructure] then
                    bIndirectThreatOnly = true
                elseif tEnemyThreatGroup[refiThreatGroupCategory] == iNavyUnitCategories then
                    bConsideringNavy = true
                end
                if bConsideringNavy == true or bIgnoreRemainingLandThreats == false then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Start of cycle through sorted table of each enemy threat group; iEnemyGroup=' .. iEnemyGroup .. '; distance from our base=' .. tEnemyThreatGroup[refiModDistanceFromOurStart] .. '; bIndirectThreatOnly=' .. tostring(bIndirectThreatOnly) .. '; bConsideringNavy=' .. tostring(bConsideringNavy))
                    end

                    bNoMorePlatoons = false
                    --Get total threat of non-committed platoons closer to our base than enemy:
                    iAvailableThreat = 0
                    iCurAvailablePlatoons = 0
                    tAvailablePlatoons = {}
                    tNilDefenderPlatoons = {}
                    --bArmyPoolInAvailablePlatoons = false

                    --Ensure enemy engis will have a unit capable of killing them quickly (e.g. 2 selen equivalents)
                    if tEnemyThreatGroup[refiTotalThreat] < 20 then
                        tEnemyThreatGroup[refiTotalThreat] = 20
                    end
                    -- Do we have enough threat available? If not, add ACU if enemy is near
                    iThreatNeeded = tEnemyThreatGroup[refiTotalThreat]
                    iThreatWanted = tEnemyThreatGroup[refiHighestThreatRecorded] * iThreatMaxFactor
                    if bIndirectThreatOnly then

                        iThreatNeeded = math.max(iThreatNeeded * 0.12, math.min(iThreatNeeded * 0.2, 400)) --i.e. 2 MMLs
                        iThreatWanted = iThreatWanted * 0.7 --Structures are given double threat, so really this is saying send up to 140% of the mass value of enemy PD in indirect fire units
                        if tEnemyThreatGroup[refiThreatGroupHighestTech] == 1 then
                            iThreatWanted = iThreatWanted * 0.7
                            iThreatNeeded = math.min(36, iThreatNeeded) --if t1 pd then in theory 1 t1 arti can take on any number
                        end --Further reduction for t1 pd since it dies easily to T1 arti
                    elseif bConsideringNavy == true then
                        if bDebugMessages == true then LOG(sFunctionRef..': iThreatNeeded before AA structure uplift='..iThreatNeeded..'; Is enemy threat group filter for structureAA or groundAA empty='..tostring(M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryStructureAA + M27UnitInfo.refCategoryGroundAA, tEnemyThreatGroup[refoEnemyGroupUnits])))) end
                        if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryStructureAA + M27UnitInfo.refCategoryGroundAA, tEnemyThreatGroup[refoEnemyGroupUnits])) == false then
                            if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryStructureAA - categories.TECH1, tEnemyThreatGroup[refoEnemyGroupUnits])) == false then iThreatNeeded = iThreatNeeded * 3
                            else iThreatNeeded = iThreatNeeded * 2
                            end
                        end

                        iThreatWanted = iThreatNeeded * iNavalThreatMaxFactor
                        iThreatNeeded = iThreatNeeded * 0.5


                    end
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': iThreatNeeded=' .. iThreatNeeded .. '; iThreatWanted=' .. iThreatWanted)
                    end

                    --Land based threats: send platoons to deal with them
                    if bConsideringNavy == false then
                        --ACU flanking check
                        --Check for ACU flanking
                        if bCheckForACUFlanking and not(bIndirectThreatOnly) and tEnemyThreatGroup[refiTotalThreat] > iThreatThresholdHigh then
                            --How close is threat group to ACU?
                            if tEnemyThreatGroup[refiModDistanceFromOurStart] < iACUActualDistFromBase and math.abs(tEnemyThreatGroup[refiDistanceFromOurBase] - iACUActualDistFromBase) < 125 then
                                iDistFromThreatGroupToACU = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), tEnemyThreatGroup[reftFrontPosition])
                                if iDistFromThreatGroupToACU >= 25 and iDistFromThreatGroupToACU <= 125 then
                                    local iACUEnemySearchRange = oACU.PlatoonHandle[M27PlatoonUtilities.refiEnemySearchRadius]
                                    local tUnitsToAdd = {}
                                    for iUnit, oUnit in tEnemyThreatGroup[refoEnemyGroupUnits] do
                                        iDistFromThreatGroupToACU = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oACU:GetPosition())
                                        if iDistFromThreatGroupToACU <= 125 and iDistFromThreatGroupToACU > iACUEnemySearchRange then
                                            table.insert(tUnitsToAdd, oUnit)
                                        end
                                    end
                                    if M27Logic.GetCombatThreatRating(aiBrain, tUnitsToAdd) >= iThreatThresholdLow then
                                        oACU[refbInDangerOfBeingFlanked] = true
                                        for iUnit, oUnit in tUnitsToAdd do
                                            table.insert(oACU[reftPotentialFlankingUnits], oUnit)
                                        end
                                    end
                                end
                            end
                        end

                        --Check for friendly mexes that have enemies near them (so bombers can prioritise them)
                        if bDebugMessages == true then LOG(sFunctionRef..': Threat group mod dist from our start='..tEnemyThreatGroup[refiModDistanceFromOurStart]..'; bomber defence mod dist='..aiBrain[M27AirOverseer.refiBomberDefenceModDistance]..'; aiBrain[refiHighestMobileLandEnemyRange]='..aiBrain[refiHighestMobileLandEnemyRange]) end
                        if tEnemyThreatGroup[refiModDistanceFromOurStart] <= (aiBrain[M27AirOverseer.refiBomberDefenceModDistance] + aiBrain[refiHighestMobileLandEnemyRange]) then
                            --Check for mexes near the group
                            local iEnemySearchRange = iDefaultEnemySearchRange
                            if iDefaultEnemySearchRange >= 50 then
                                local iHighestThreatGroupRange = 0
                                for iUnit, oUnit in tEnemyThreatGroup[refoEnemyGroupUnits] do
                                    iHighestThreatGroupRange = math.max(iHighestThreatGroupRange, M27UnitInfo.GetUnitMaxGroundRange(oUnit))
                                end
                                iEnemySearchRange = math.min(iDefaultEnemySearchRange, iHighestThreatGroupRange + 15)
                            end

                            local tNearbyBuildings = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMex + M27UnitInfo.refCategoryStructure * categories.TECH2 + M27UnitInfo.refCategoryStructure * categories.TECH3 + M27UnitInfo.refCategoryExperimentalStructure, tEnemyThreatGroup[reftFrontPosition], iEnemySearchRange, 'Ally')
                            if bDebugMessages == true then LOG(sFunctionRef..': iEnemySearchRange='..iEnemySearchRange..'; Is table of nearby buildings empty='..tostring(M27Utilities.IsTableEmpty(tNearbyBuildings))) end
                            if M27Utilities.IsTableEmpty(tNearbyBuildings) == false then
                                if tEnemyThreatGroup[refiModDistanceFromOurStart] <= aiBrain[M27AirOverseer.refiBomberDefenceModDistance] or M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryStructure - categories.TECH1, tNearbyBuildings)) == false then
                                    --Include if within max bomber range, or we own the first building
                                    if tNearbyBuildings[1]:GetAIBrain():GetArmyIndex() == aiBrain:GetArmyIndex() or tEnemyThreatGroup[refiDistanceFromOurBase] <= aiBrain[M27AirOverseer.refiBomberDefenceDistanceCap] then
                                        --if GetGameTimeSeconds() >= 960 then bDebugMessages = true end
                                        if bDebugMessages == true then LOG(sFunctionRef..': Threat group '..iEnemyGroup..' is threatening our buildings. Is table of untis in this threat group empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEnemyThreatGroup][iEnemyGroup]))) end
                                        table.insert(aiBrain[reftEnemyGroupsThreateningBuildings], iEnemyGroup)
                                        aiBrain[refbGroundCombatEnemyNearBuilding] = true
                                    end
                                end
                            end
                        end

                        for iPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': iPlatoon=' .. iPlatoon .. '; Platoon unit count=' .. table.getn(oPlatoon:GetPlatoonUnits()))
                            end
                            if oPlatoon[M27PlatoonTemplates.refbUsedByThreatDefender] == true then
                                --if not(oPlatoon == oArmyPoolPlatoon) then
                                bPlatoonIsAvailable = false
                                sPlan = oPlatoon:GetPlan()
                                iPlatoonNumber = oPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                if iPlatoonNumber == nil then
                                    iPlatoonNumber = 0
                                end
                                sPlatoonRef = sPlan .. iPlatoonNumber

                                --If dealing with a structure threat then dont include platoons with DF units; if dealing with a mobile threat dont include platoons with only indirect units
                                bPlatoonHasRelevantUnits = false
                                if bIndirectThreatOnly then
                                    if oPlatoon[M27PlatoonUtilities.refiIndirectUnits] and oPlatoon[M27PlatoonUtilities.refiIndirectUnits] > 0 then
                                        bPlatoonHasRelevantUnits = true
                                    elseif oPlatoon[M27PlatoonUtilities.refiDFUnits] > 0 and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryLongRangeDFLand, oPlatoon[M27PlatoonUtilities.reftDFUnits])) == false then
                                        --e.g. shield disruptors, sniperbots (although sniperbots should be going ot skirmisher which doesnt get used by defender)
                                        bPlatoonHasRelevantUnits = true
                                    end
                                    --[[
                                    if sPlan == M27PlatoonTemplates.refoIdleIndirect or sPlan == 'M27IndirectSpareAttacker' then bPlatoonHasRelevantUnits = true
                                    elseif oPlatoon[M27PlatoonUtilities.refiIndirectUnits] and oPlatoon[M27PlatoonUtilities.refiIndirectUnits] > 0 then
                                        bPlatoonHasRelevantUnits = true
                                    end--]]
                                    --Check that have units of the desired tech level
                                    if tEnemyThreatGroup[refiThreatGroupHighestTech] > 1 and bPlatoonHasRelevantUnits == true then
                                        bPlatoonHasRelevantUnits = false
                                        --Check we have at least 1 T2 unit in here
                                        if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryIndirectT2Plus + M27UnitInfo.refCategoryLongRangeDFLand - categories.TECH1, oPlatoon[M27PlatoonUtilities.reftCurrentUnits])) == false then
                                            bPlatoonHasRelevantUnits = true
                                        end
                                    end
                                else
                                    if oPlatoon[M27PlatoonUtilities.refiDFUnits] and oPlatoon[M27PlatoonUtilities.refiDFUnits] > 0 then
                                        bPlatoonHasRelevantUnits = true
                                    end
                                    --[[if sPlan == M27PlatoonTemplates.refoIdleCombat then bPlatoonHasRelevantUnits = true
                                    elseif oPlatoon[M27PlatoonUtilities.refiDFUnits] and oPlatoon[M27PlatoonUtilities.refiDFUnits] > 0 then bPlatoonHasRelevantUnits = true end--]]
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': sPlatoonRef=' .. sPlatoonRef .. '; finished checking if have relevant units for the threat type, bPlatoonHasRelevantUnits=' .. tostring(bPlatoonHasRelevantUnits))
                                end
                                if bPlatoonHasRelevantUnits == true then
                                    --Only include defender platoons that are closer to our base than enemy threat, and which aren't already dealing with a threat
                                    if oPlatoon[M27PlatoonUtilities.refiPlatoonCount] == nil then
                                        oPlatoon[M27PlatoonUtilities.refiPlatoonCount] = 0
                                    end

                                    --if sPlan == sDefenderPlatoonRef or sPlan == 'M27AttackNearestUnits' or sPlan == M27PlatoonTemplates.refoIdleIndirect or sPlan == 'M27IndirectSpareAttacker' or sPlan == 'M27IndirectDefender' or sPlan == 'M27CombatPatrolAI' then
                                    tCurPos = M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)
                                    iDistToOurBase = M27Utilities.GetDistanceBetweenPositions(tCurPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Considering available platoons; iPlatoon=' .. iPlatoon .. '; sPlatoonRef=' .. sPlatoonRef .. '; iEnemyGroup=' .. iEnemyGroup..'; dist from our platoon to base='..iDistToOurBase..'; dist of enemy threat group to our base='..tEnemyThreatGroup[refiDistanceFromOurBase])
                                    end
                                    if iDistToOurBase <= oPlatoon[M27PlatoonUtilities.refiPlatoonMaxRange] + tEnemyThreatGroup[refiDistanceFromOurBase] then
                                        if oPlatoon[refsEnemyThreatGroup] == nil then
                                            bPlatoonIsAvailable = true
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Platoons current target is nil so platoon is available; iPlatoon=' .. iPlatoon)
                                            end
                                        else
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': iPlatoon=' .. iPlatoon .. '; Is busy targetting ' .. oPlatoon[refsEnemyThreatGroup] .. '; curent threat group considering is: ' .. iEnemyGroup)
                                            end
                                            if sThreatGroup == nil then
                                                LOG(repru(aiBrain[reftEnemyThreatGroup]))
                                            end
                                            --aiBrain[reftEnemyThreatGroup][sThreatGroup][refsEnemyGroupName] = sThreatGroup
                                            if oPlatoon[refsEnemyThreatGroup] == iEnemyGroup then
                                                bPlatoonIsAvailable = true
                                            end
                                        end
                                    else
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Platoon is too far away to be of help; iPlatoon=' .. iPlatoon .. '; sPlatoonRef=' .. sPlatoonRef .. '; iEnemyGroup=' .. iEnemyGroup .. '; iDistToOurBase=' .. iDistToOurBase .. '; tEnemyThreatGroup[refiDistanceFromOurBase]=' .. tEnemyThreatGroup[refiDistanceFromOurBase])
                                        end
                                    end
                                    --else
                                    --if bDebugMessages == true then LOG(sFunctionRef..': Platoon plan isnt equal to defender plan. iPlatoon='..iPlatoon..'; sPlatoonRef='..sPlatoonRef..'; iEnemyGroup='..iEnemyGroup) end
                                    --end
                                    if bPlatoonIsAvailable == true then
                                        --Does the platoon have the ACU in it? If so remove it (it can get re-added later if an emergency response is required)
                                        if oPlatoon[M27PlatoonUtilities.refbACUInPlatoon] == true then
                                            if not (oPlatoon[refsEnemyThreatGroup] == iEnemyGroup) then
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': ACU is in platoon so will only make platoon available for threat response if ACU is targetting the same threat group')
                                                end
                                                bPlatoonIsAvailable = false
                                            end
                                        end
                                        if bPlatoonIsAvailable == true then
                                            --Does the platoon have non-long range DF units in it but we're targetting structures?
                                            if oPlatoon[M27PlatoonUtilities.refiDFUnits] > 0 and bIndirectThreatOnly then
                                                --RemoveUnitsFromPlatoon(oPlatoon, tUnits, bReturnToBase, oPlatoonToAddTo)
                                                local tUnitsToRemove = EntityCategoryFilterDown(categories.ALLUNITS - M27UnitInfo.refCategoryLongRangeDFLand, oPlatoon[M27PlatoonUtilities.reftDFUnits])
                                                if M27Utilities.IsTableEmpty(tUnitsToRemove) == false then M27PlatoonUtilities.RemoveUnitsFromPlatoon(oPlatoon, oPlatoon[M27PlatoonUtilities.reftDFUnits], false, nil) end
                                            end
                                            --Add current platoon details:
                                            iDistFromEnemy = M27Utilities.GetDistanceBetweenPositions(tCurPos, tEnemyThreatGroup[reftFrontPosition])
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Platoon is available, will record the threat; iAvailableThreat pre updating=' .. iAvailableThreat)
                                            end
                                            iAvailableThreat, iCurAvailablePlatoons = RecordAvailablePlatoonAndReturnValues(aiBrain, oPlatoon, iAvailableThreat, iCurAvailablePlatoons, tCurPos, iDistFromEnemy, iDistToOurBase, tAvailablePlatoons, tNilDefenderPlatoons, bIndirectThreatOnly)
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Platoon is available, have recorded the threat; iAvailableThreat post updating=' .. iAvailableThreat)
                                            end
                                        end
                                    end
                                end
                                --end
                            end
                        end

                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Considering action based on our threat vs enemy; EnemyThreat=' .. tEnemyThreatGroup[refiTotalThreat] .. '; iAvailableThreat=' .. iAvailableThreat)
                        end

                        if iAvailableThreat < iThreatNeeded and not (bIndirectThreatOnly) and not (bConsideringNavy) then
                            --Check if should add ACU to help fight - is enemy relatively close to ACU, relatively close to our start, and ACU is closer to start than enemy?
                            bGetACUHelp = false
                            iDistFromEnemy = M27Utilities.GetDistanceBetweenPositions(tACUPos, tEnemyThreatGroup[reftFrontPosition])
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Considering whether should get ACU to help; iDistFromEnemy =' .. iDistFromEnemy)
                            end
                            if iDistFromEnemy < iACUDistanceToConsider then
                                if tEnemyThreatGroup[refiDistanceFromOurBase] < iACUEnemyDistanceFromBase then
                                    iDistToOurBase = M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                    if iDistToOurBase < tEnemyThreatGroup[refiDistanceFromOurBase] then
                                        --are we closer to our base than enemy?
                                        if M27Logic.GetNearestEnemyStartNumber(aiBrain) then
                                            local iDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                                            if iDistToEnemyBase > 0 and iDistToOurBase / iDistToEnemyBase < 0.85 then
                                                bGetACUHelp = true
                                            end
                                        end
                                    end
                                end
                            end
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': bGetACUHelp=' .. tostring(bGetACUHelp) .. '; if this is false then will check if emergency response required')
                            end
                            --Check if emergency response required:
                            if bGetACUHelp == false then
                                if tEnemyThreatGroup[refiDistanceFromOurBase] < iACUEnemyDistanceFromBase then
                                    if iThreatNeeded - iAvailableThreat > iEmergencyExcessEnemyThreatNearBase and iThreatNeeded > 0 and iAvailableThreat / iThreatNeeded < 0.85 then
                                        if iDistToOurBase <= iMaxACUEmergencyThreatRange then
                                            bGetACUHelp = true
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': bGetACUHelp=' .. tostring(bGetACUHelp) .. '; Emergency response is required')
                                            end
                                        end
                                    end
                                end
                            end


                            --Check ACU isn't upgrading
                            if bGetACUHelp == true then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': checking if ACU is upgrading')
                                end
                                if oACU:IsUnitState('Upgrading') == true then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': ACU is upgrading so dont want it to help')
                                    end
                                    bGetACUHelp = false
                                end
                            end
                            --Check ACU hasn't finished its gun upgrade (want both for aeon):
                            if bGetACUHelp == true then
                                if M27Conditions.DoesACUHaveGun(aiBrain, true) == true then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': ACU has gun upgrade so dont want it to help as it should be attacking')
                                    end
                                    bGetACUHelp = false
                                end
                            end
                            --Check ACU doesnt have nearby enemies
                            if bGetACUHelp == true then
                                if oACU.PlatoonHandle and oACU.PlatoonHandle[M27PlatoonUtilities.refiEnemiesInRange] > 0 then
                                    local iEnemySearchRange = math.max(22, M27Logic.GetUnitMaxGroundRange({ oACU }))
                                    local tEnemiesNearACU = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, oACU:GetPosition(), iEnemySearchRange, 'Enemy')
                                    if M27Utilities.IsTableEmpty(tEnemiesNearACU) == false then
                                        bGetACUHelp = false
                                    end
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
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Finished considering if ACU should help; bGetACUHelp=' .. tostring(bGetACUHelp))
                            end
                        else
                            --Threat higher than needed, so flag that don't need ACU help
                            oACU[refbACUHelpWanted] = false
                        end

                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Finished identifying all platoons/units that can help deal with the threat, now will decide on what action to take; iAvailableThreat=' .. iAvailableThreat .. '; iThreatNeeded=' .. iThreatNeeded .. '; bGetACUHelp=' .. tostring(bGetACUHelp))
                        end
                        --Now that have all available units, decide on action based on enemy threat
                        --First update trackers - want to base on whether we have all the units we want to respond to the threat (rather than whether we have just enough units to attack)
                        if iAvailableThreat < iThreatWanted then
                            --local iCurModDistToEnemyBase = GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tEnemyThreatGroup[reftFrontPosition], true)
                            --M27Utilities.GetDistanceBetweenPositions(tEnemyThreatGroup[reftFrontPosition], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                            aiBrain[refiModDistFromStartNearestOutstandingThreat] = tEnemyThreatGroup[refiModDistanceFromOurStart]
                            aiBrain[refiPercentageOutstandingThreat] = tEnemyThreatGroup[refiModDistanceFromOurStart] / aiBrain[refiDistanceToNearestEnemyBase]
                            if bDebugMessages == true then LOG(sFunctionRef..': Dont have enough available threat to defeat the platoon. mod dist to our start='..tEnemyThreatGroup[refiModDistanceFromOurStart]..'; Dist to enemy base='..aiBrain[refiDistanceToNearestEnemyBase]..'; Outstanding threat %='..aiBrain[refiPercentageOutstandingThreat]..'; refiDistanceFromOurBase='..tEnemyThreatGroup[refiDistanceFromOurBase]..'; actual dist to our base='..M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tEnemyThreatGroup[reftFrontPosition])..'; Dist to enemy base='..M27Utilities.GetDistanceBetweenPositions(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), tEnemyThreatGroup[reftFrontPosition])..'; angle from our base to threat='..M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tEnemyThreatGroup[reftFrontPosition])) end
                            aiBrain[refiMinIndirectTechLevel] = 1 --default
                            if bIndirectThreatOnly then
                                aiBrain[refbNeedIndirect] = true
                                aiBrain[refbNeedDefenders] = false
                                if tEnemyThreatGroup[refiThreatGroupHighestTech] >= 2 then
                                    aiBrain[refiMinIndirectTechLevel] = math.min(tEnemyThreatGroup[refiThreatGroupHighestTech], 3)
                                end
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
                        if iAvailableThreat < iThreatNeeded and not (bGetACUHelp) then

                            --Dont have enough units yet, so get units in position so when have enough can respond
                            --Go to midpoint, or if enemy too close then to base
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Dont have enough threat to deal with enemy - iAvailableThreat=' .. iAvailableThreat .. '; iThreatNeeded=' .. iThreatNeeded .. '; set refbNeedDefenders to true; getting rally point for any available platoons to retreat to')
                            end
                            --if bDebugMessages == true then LOG(sFunctionRef..': ACU state='..M27Logic.GetUnitState(M27Utilities.GetACU(aiBrain))) end
                            tRallyPoint = {}
                            if tEnemyThreatGroup[refiDistanceFromOurBase] > 60 then
                                tRallyPoint[1] = (tEnemyThreatGroup[reftFrontPosition][1] + M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1]) / 2
                                tRallyPoint[3] = (tEnemyThreatGroup[reftFrontPosition][3] + M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]) / 2
                                tRallyPoint[2] = GetTerrainHeight(tRallyPoint[1], tRallyPoint[3])
                                if bDebugMessages == true then LOG(sFunctionRef..': Rally point is half way between our start and the enemy threat='..repru(tRallyPoint)..'; Dist to rally point from our base='..M27Utilities.GetDistanceBetweenPositions(tRallyPoint, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; Dist to platoon='..M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tEnemyThreatGroup[reftFrontPosition])..'; our base='..repru(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; threat group pos='..repru(tEnemyThreatGroup[reftFrontPosition])) end
                            else
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Enemy is clsoe to our base, so rally point is our base')
                                end
                                tRallyPoint = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                            end
                            for iPlatoon, oPlatoon in tAvailablePlatoons do
                                oPlatoon[refsEnemyThreatGroup] = nil
                                if not (oPlatoon == oArmyPoolPlatoon) then
                                    --redundancy/from old code - armypool shouldnt be in availableplatoons any more
                                    oPlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionReissueMovementPath
                                    if M27Utilities.IsTableEmpty(oPlatoon[M27PlatoonUtilities.reftMovementPath]) == false and M27Utilities.GetDistanceBetweenPositions((oPlatoon[M27PlatoonUtilities.reftMovementPath][(oPlatoon[M27PlatoonUtilities.refiCurrentPathTarget] or 1)] or { 0, 0, 0 }), (tRallyPoint or { 0, 0, 0 })) > 10 then
                                        M27PlatoonUtilities.ForceActionRefresh(oPlatoon)
                                        oPlatoon[M27PlatoonUtilities.reftMovementPath] = {}
                                    elseif M27Utilities.IsTableEmpty(oPlatoon[M27PlatoonUtilities.reftMovementPath]) then
                                        oPlatoon[M27PlatoonUtilities.reftMovementPath] = {}
                                    end
                                    oPlatoon[M27PlatoonUtilities.reftMovementPath][1] = tRallyPoint
                                    oPlatoon[M27PlatoonUtilities.refiCurrentPathTarget] = 1
                                    --oPlatoon[M27PlatoonUtilities.refiLastPathTarget] = 1
                                    oPlatoon[M27PlatoonUtilities.refbOverseerAction] = true
                                    --M27Utilities.IssueTrackedClearCommands(oPlatoon:GetPlatoonUnits())
                                    if bDebugMessages == true then
                                        local iPlatoonCount = oPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                        if iPlatoonCount == nil then
                                            iPlatoonCount = 'nil'
                                        end
                                        LOG(sFunctionRef .. ': Given override action and Set tMovementPath[1] to tRallyPoint=' .. tRallyPoint[1] .. '-' .. tRallyPoint[3] .. ' and then stop looking at remaining threats; iPlatoon=' .. iPlatoon .. '; PlatoonCount=' .. iPlatoonCount)
                                    end
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
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Have enough threat to respond, will now sort platoons to find the nearest one; available platoon size=' .. table.getn(tAvailablePlatoons))
                            end
                            local bRefreshPlatoonAction
                            for iPlatoonRef, oAvailablePlatoon in M27Utilities.SortTableBySubtable(tAvailablePlatoons, refiActualDistanceFromEnemy, true) do
                                --for iCurPlatoon = 1, iCurAvailablePlatoons do
                                bRefreshPlatoonAction = false
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': iPlatoonRef=' .. iPlatoonRef .. '; platoon unit count=' .. table.getn(oAvailablePlatoon:GetPlatoonUnits()))
                                end
                                sPlan = oAvailablePlatoon:GetPlan()
                                iPlatoonNumber = oAvailablePlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                if iPlatoonNumber == nil then
                                    iPlatoonNumber = 0
                                end
                                sPlatoonRef = sPlan .. iPlatoonNumber

                                oDefenderPlatoon = oAvailablePlatoon--tAvailablePlatoons[iPlatoonRef]
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': sPlatoonRef=' .. sPlatoonRef .. '; iThreatWanted=' .. iThreatWanted .. '; bNeedBasePlatoon=' .. tostring(bNeedBasePlatoon) .. '; units in platoon=' .. table.getn(oAvailablePlatoon:GetPlatoonUnits()))
                                end
                                if iThreatWanted <= 0 then
                                    --Ensure platoon is available to target other platoons as it's not needed for this one
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Threat wanted is <= 0 so making platoon available for other threat groups')
                                    end
                                    oAvailablePlatoon[refsEnemyThreatGroup] = nil
                                else
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': bNeedBasePlatoon=' .. tostring(bNeedBasePlatoon))
                                    end
                                    if bNeedBasePlatoon == true then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Need a base platoon, checking if we dont ahve an army pool platoon; bIndirectThreatOnly=' .. tostring(bIndirectThreatOnly))
                                        end
                                        if not (oBasePlatoon == oArmyPoolPlatoon) then
                                            oBasePlatoon = oAvailablePlatoon
                                            bNeedBasePlatoon = false
                                            if bIndirectThreatOnly then
                                                if not (sPlan == 'M27IndirectDefender') then
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': sPlan=' .. sPlan .. '; refbIdlePlatoon=' .. tostring(oBasePlatoon[M27PlatoonTemplates.refbIdlePlatoon]))
                                                    end
                                                    if oBasePlatoon[M27PlatoonTemplates.refbIdlePlatoon] then
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': Have an idle platoon so will create a new platoon as the base platoon and assign it the cufrrent indirectdefenders units')
                                                        end
                                                        local tPlatoonUnits = oBasePlatoon:GetPlatoonUnits()
                                                        if M27Utilities.IsTableEmpty(tPlatoonUnits) == false then

                                                            oBasePlatoon = M27PlatoonFormer.CreatePlatoon(aiBrain, 'M27IndirectDefender', tPlatoonUnits)
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. 'oBasePlatoon plan=' .. oBasePlatoon:GetPlan() .. '; iPlatoonRef=' .. iPlatoonRef .. '; size of base platoon units=' .. table.getn(tPlatoonUnits))
                                                            end
                                                            TransferPlatoonTrackers(oAvailablePlatoon, oBasePlatoon)
                                                        else
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': Base platoon units is empty')
                                                            end
                                                            bNeedBasePlatoon = true
                                                        end
                                                    else
                                                        oBasePlatoon:SetAIPlan('M27IndirectDefender')
                                                    end
                                                    oDefenderPlatoon = oBasePlatoon
                                                end
                                                oBasePlatoon[M27PlatoonUtilities.refbShouldHaveEscort] = true
                                            else
                                                oBasePlatoon[M27PlatoonUtilities.refbShouldHaveEscort] = false
                                            end
                                        else
                                            M27Utilities.ErrorHandler('The first platoon considered wasnt suitable as a base platoon')
                                        end
                                    end

                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': sPlatoonRef=' .. sPlatoonRef .. '; Totalthreat group IDd = ' .. iCurThreatGroup .. '; Cur threat group iEnemyGroup=' .. iEnemyGroup .. 'iPlatoonRef=' .. iPlatoonRef .. '; iThreatNeeded=' .. iThreatNeeded .. '; iThreatWanted=' .. iThreatWanted)
                                    end
                                    if bNeedBasePlatoon == false then
                                        --Check if have at least 1 T1 tank too many (otherwise ignore) - 52 is lowest mass cost of a tank (56 is highest)
                                        if oDefenderPlatoon[refiTotalThreat] == nil then
                                            --e.g. army pool will be nil
                                            --GetCombatThreatRating(aiBrain, tUnits, bUseBlip, iMassValueOfBlipsOverride)
                                            oDefenderPlatoon[refiTotalThreat] = M27Logic.GetCombatThreatRating(aiBrain, oDefenderPlatoon:GetPlatoonUnits(), false)
                                        end
                                        if bDebugMessages == true then
                                            LOG('sPlatoonRef=' .. sPlatoonRef .. '; oDefenderPlatoon[refiTotalThreat]=' .. oDefenderPlatoon[refiTotalThreat] .. '; Defender platoon units=' .. table.getn(oDefenderPlatoon:GetPlatoonUnits()))
                                        end
                                        if oDefenderPlatoon[refiTotalThreat] - iThreatWanted >= iThresholdToRemoveSpareUnitsAbsolute and oDefenderPlatoon[refiTotalThreat] > (iThreatWanted * iThresholdToRemoveSpareUnitsPercent) then
                                            --Determine the first nil platoon that hasn't been assigned to merge units into:
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': sPlatoonRef=' .. sPlatoonRef .. '; Dont need all of the platoon, locate the first different nil defender platoon so spare units can be assigned to this; iPlatoonRef=' .. iPlatoonRef)
                                            end
                                            oCombatPlatoonToMergeInto = nil
                                            for iNilPlatoon, oNilPlatoon in tNilDefenderPlatoons do
                                                if oNilPlatoon[refsEnemyThreatGroup] == nil then
                                                    if not (oNilPlatoon == oDefenderPlatoon) then
                                                        oCombatPlatoonToMergeInto = oNilPlatoon
                                                        break
                                                    end
                                                end
                                            end
                                            if oCombatPlatoonToMergeInto == nil then
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': sPlatoonRef=' .. sPlatoonRef .. '; About to merge into the army pool platoon')
                                                end
                                                oCombatPlatoonToMergeInto = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
                                            end
                                            if oDefenderPlatoon == oArmyPoolPlatoon then
                                                M27Utilities.ErrorHandler('Defender platoon is army pool')
                                                if bDebugMessages == true then
                                                    LOG('oDefenderPlatoon is army pool already, so dont want to try and remove')
                                                end
                                            else
                                                if bDebugMessages == true then
                                                    local iPlatoonCount = oDefenderPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                                    if iPlatoonCount == nil then
                                                        iPlatoonCount = 'nil'
                                                    end
                                                    LOG('sPlatoonRef=' .. sPlatoonRef .. '; oDefenderPlatoon count=' .. iPlatoonCount)
                                                end
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Removing spare units from oDefenderPlatoon; iThreatNeeded=' .. iThreatNeeded .. '; oDefenderPlatoon[refiTotalThreat]=' .. oDefenderPlatoon[refiTotalThreat] .. '; size of platoon=' .. table.getn(oDefenderPlatoon:GetPlatoonUnits()))
                                                end
                                                RemoveSpareUnits(oDefenderPlatoon, iThreatWanted, iMinScouts, iMinMAA, oCombatPlatoonToMergeInto, true)
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Finished removing spare units from oDefenderPlatoon; Platoon Total threat=' .. oDefenderPlatoon[refiTotalThreat] .. '; size of platoon=' .. table.getn(oDefenderPlatoon:GetPlatoonUnits()))
                                                end
                                                if bIsFirstPlatoon == false then
                                                    --function MergePlatoons(oPlatoonToMergeInto, oPlatoonToBeMerged)
                                                    if bDebugMessages == true then
                                                        local iPlatoonCount = oBasePlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                                        if iPlatoonCount == nil then
                                                            iPlatoonCount = 'nil'
                                                        end
                                                        LOG(sFunctionRef .. ': About to merge remaining units in defender platoon into base platoon; oBasePlatoon Count=' .. iPlatoonCount)
                                                    end
                                                    M27PlatoonUtilities.MergePlatoons(oBasePlatoon, oDefenderPlatoon)
                                                    bAddedUnitsToPlatoon = true
                                                end
                                            end
                                            iThreatWanted = 0
                                            iThreatNeeded = 0
                                            bIgnoreRemainingLandThreats = true
                                        else
                                            --need all of platoon:
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': sPlatoonRef=' .. sPlatoonRef .. '; About to adjust threat needed for the threat of the available platoon that have just used; iEnemyThreat=' .. iEnemyGroup .. '; iPlatoonRef=' .. iPlatoonRef .. '; iThreatNeeded=' .. iThreatNeeded .. '; oDefenderPlatoon[refiTotalThreat]=' .. oDefenderPlatoon[refiTotalThreat])
                                            end
                                            iThreatNeeded = iThreatNeeded - oDefenderPlatoon[refiTotalThreat]
                                            iThreatWanted = iThreatWanted - oDefenderPlatoon[refiTotalThreat]
                                            if iThreatWanted <= 0 then
                                                bNoMorePlatoons = true
                                            end
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
                                            if not (EntityCategoryFilterDown(categories.SCOUT, tBasePlatoonUnits) == nil) then
                                                iMinScouts = 0
                                            end
                                        end
                                        if iMinMAA > 0 then
                                            if not (EntityCategoryFilterDown(M27UnitInfo.refCategoryMAA, tBasePlatoonUnits) == nil) then
                                                iMinMAA = 0
                                            end
                                        end
                                        if not (oBasePlatoon == oArmyPoolPlatoon) then
                                            bIsFirstPlatoon = false
                                        end
                                    else
                                        iMinScouts = 0
                                        iMinMAA = 0
                                    end
                                else
                                    iMinScouts = 0
                                    iMinMAA = 0
                                end
                            end
                            --Base platoon should now be able to beat enemy (or shoudl at least try to if ACU is helping)
                            if bIgnoreRemainingLandThreats == false and oBasePlatoon == nil then
                                if bGetACUHelp == false then
                                    M27Utilities.ErrorHandler('oBasePlatoon is nil but had thought could beat the enemy, and ACU isnt part of attack - likely error')
                                end
                            elseif bIgnoreRemainingLandThreats == false then
                                if oBasePlatoon == oArmyPoolPlatoon then
                                    M27Utilities.ErrorHandler('WARNING - oArmyPoolPlatoon is oBasePlatoon - will abort threat intereception logic and flag that want defender platoons to be created')
                                    if table.getn(tAvailablePlatoons) <= 1 then
                                        aiBrain[refbNeedDefenders] = true
                                    end
                                else
                                    if (oBasePlatoon[refiTotalThreat] or 0) > 0 and M27Utilities.IsTableEmpty(oBasePlatoon:GetPlatoonUnits()) == false then
                                        if oBasePlatoon:GetPlan() == nil then
                                            LOG(sFunctionRef .. ': ERROR - oBasePlatoons plan is nil, will set to be the defender AI, bIndirectThreatOnly=' .. tostring(bIndirectThreatOnly))
                                            if bIndirectThreatOnly then
                                                oBasePlatoon:SetAIPlan('M27IndirectDefender')
                                                oBasePlatoon[M27PlatoonUtilities.refbShouldHaveEscort] = true
                                            else
                                                oBasePlatoon:SetAIPlan(sDefenderPlatoonRef)
                                                if bDebugMessages == true then LOG(sFunctionRef..': Have set base platoon to sue defender AI') end
                                            end
                                        end
                                        sPlan = oBasePlatoon:GetPlan()
                                        iPlatoonNumber = oBasePlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                        if iPlatoonNumber == nil then
                                            iPlatoonNumber = 0
                                        end
                                        sPlatoonRef = sPlan .. iPlatoonNumber
                                        --oBasePlatoon[reftFrontPosition] = oBasePlatoon:GetPlatoonPosition()
                                        oBasePlatoon[reftFrontPosition] = M27PlatoonUtilities.GetPlatoonFrontPosition(oBasePlatoon)
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': sPlatoonRef=' .. sPlatoonRef .. '; Base platoon av position=' .. repru(oBasePlatoon[reftFrontPosition]) .. '; tEnemyThreatGroup[reftFrontPosition]=' .. repru(tEnemyThreatGroup[reftFrontPosition]))
                                        end
                                        oBasePlatoon[refiActualDistanceFromEnemy] = M27Utilities.GetDistanceBetweenPositions(oBasePlatoon[reftFrontPosition], tEnemyThreatGroup[reftFrontPosition])
                                        bRefreshPlatoonAction = true
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': BasePlatoonRef=' .. sPlatoonRef .. ': Considering whether base platoon should have an overseer action override. bAddedUnitsToPlatoon=' .. tostring(bAddedUnitsToPlatoon) .. '; base platoon size=' .. table.getn(oBasePlatoon:GetPlatoonUnits()))
                                        end
                                        --if not(bAddedUnitsToPlatoon) then
                                        local iOverseerRefreshCountThreshold = 4
                                        if oBasePlatoon[M27PlatoonUtilities.refbHoverInPlatoon] then
                                            iOverseerRefreshCountThreshold = iOverseerRefreshCountThreshold + 5
                                        end
                                        if bIndirectThreatOnly == true then
                                            iOverseerRefreshCountThreshold = 9
                                        end
                                        if M27Utilities.IsTableEmpty(oBasePlatoon[M27PlatoonUtilities.reftPrevAction]) == false then
                                            local iPrevAction = oBasePlatoon[M27PlatoonUtilities.reftPrevAction][1]
                                            if iPrevAction == M27PlatoonUtilities.refActionRun or iPrevAction == M27PlatoonUtilities.refActionTemporaryRetreat or iPrevAction == M27PlatoonUtilities.refActionAttack or iPrevAction == M27PlatoonUtilities.refActionKitingRetreat or iPrevAction == M27PlatoonUtilities.refActionMoveDFToNearestEnemy then
                                                bRefreshPlatoonAction = false
                                            elseif oBasePlatoon[M27PlatoonUtilities.refiLastPrevActionOverride] and oBasePlatoon[M27PlatoonUtilities.refiLastPrevActionOverride] <= iOverseerRefreshCountThreshold then
                                                bRefreshPlatoonAction = false
                                            end
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Base platoon has at least 1 previous action, iPrevAction=' .. iPrevAction .. '; bRefreshPlatoonAction=' .. tostring(bRefreshPlatoonAction) .. '; oBasePlatoon[M27PlatoonUtilities.refbOverseerAction]=' .. tostring(oBasePlatoon[M27PlatoonUtilities.refbOverseerAction]))
                                            end
                                        end
                                        --end

                                        if bRefreshPlatoonAction == true then
                                            oBasePlatoon[M27PlatoonUtilities.refbOverseerAction] = true
                                            if bDebugMessages == true then
                                                local iPlatoonCount = oBasePlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                                if iPlatoonCount == nil then
                                                    iPlatoonCount = 'nil'
                                                end
                                                LOG(sFunctionRef .. ': Given override action to Base platoon sPlatoonRef=' .. sPlatoonRef .. '; About to issue new orders to oBasePlatoon; oBasePlatoon count=' .. iPlatoonCount .. '; oBasePlatoon[refiActualDistanceFromEnemy]=' .. oBasePlatoon[refiActualDistanceFromEnemy])
                                            end
                                            if oBasePlatoon[refiActualDistanceFromEnemy] <= 30 then
                                                --if bDebugMessages == true then LOG(sFunctionRef..': Base platoon sPlatoonRef='..sPlatoonRef..'; Telling base platoon to have actionattack') end
                                                oBasePlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionAttack
                                                --oBasePlatoon[M27PlatoonUtilities.refiEnemiesInRange] = tEnemyThreatGroup[refiEnemyThreatGroupUnitCount]
                                                --oBasePlatoon[M27PlatoonUtilities.reftEnemiesInRange] = tEnemyThreatGroup[refoEnemyGroupUnits]
                                                if bAddedUnitsToPlatoon == true then
                                                    M27PlatoonUtilities.ForceActionRefresh(oBasePlatoon)
                                                end
                                            else
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Base platoon sPlatoonRef=' .. sPlatoonRef .. '; Telling base platoon to refresh its movement path')
                                                end
                                                M27PlatoonUtilities.ForceActionRefresh(oBasePlatoon)
                                                oBasePlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionReissueMovementPath
                                            end
                                        else
                                            --oBasePlatoon[M27PlatoonUtilities.refbOverseerAction] = false --Got wierd results when put this tofalse with aeon (v45 WIP - e.g. combat patrol platoons would stop and start and barely move) so would need to spend more time looking into if did decide to change
                                        end
                                        --M27Utilities.IssueTrackedClearCommands(oBasePlatoon:GetPlatoonUnits())
                                        oBasePlatoon[M27PlatoonUtilities.reftMovementPath] = {}
                                        oBasePlatoon[M27PlatoonUtilities.reftMovementPath][1] = tEnemyThreatGroup[reftFrontPosition]
                                        oBasePlatoon[M27PlatoonUtilities.refiCurrentPathTarget] = 1
                                        --oBasePlatoon[M27PlatoonUtilities.refiLastPathTarget] = 1
                                        oBasePlatoon[refsEnemyThreatGroup] = iEnemyGroup
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Base platoon sPlatoonRef=' .. sPlatoonRef .. '; oBasePlatoon now has movementpath=' .. repru(oBasePlatoon[M27PlatoonUtilities.reftMovementPath]) .. '; oBasePlatoon[refsEnemyThreatGroup]=' .. oBasePlatoon[refsEnemyThreatGroup])
                                        end
                                        --Free up any spare scouts and MAA post-platoon merger:
                                        RemoveSpareNonCombatUnits(oBasePlatoon)
                                        --Remove DF units if are attacking a structure
                                        if sPlan == 'M27IndirectDefender' and oBasePlatoon[M27PlatoonUtilities.refiDFUnits] and oBasePlatoon[M27PlatoonUtilities.refiDFUnits] > 0 then
                                            M27PlatoonUtilities.RemoveUnitsFromPlatoon(oBasePlatoon, oBasePlatoon[M27PlatoonUtilities.reftDFUnits], nil, nil)
                                        end
                                        --Set whether should move in formation or rush towards enemy
                                        local sCurFormation = 'AttackFormation'
                                        if tEnemyThreatGroup[refiDistanceFromOurBase] <= 60 then
                                            sCurFormation = 'GrowthFormation'
                                        elseif oBasePlatoon[refiActualDistanceFromEnemy] <= 35 then
                                            sCurFormation = 'GrowthFormation'
                                        end
                                        oBasePlatoon:SetPlatoonFormationOverride(sCurFormation)
                                    else
                                        if bGetACUHelp == false then
                                            M27Utilities.ErrorHandler('oBasePlatoon is nil but had thought could beat the enemy, and ACU isnt part of attack - likely error')
                                        end
                                    end
                                end
                            end
                            if bGetACUHelp then
                                --Make sure ACU is moving where we want already; if not then tell it to
                                local oACUPlatoon = M27Utilities.GetACU(aiBrain).PlatoonHandle
                                if oACUPlatoon and M27Utilities.IsACU(M27Utilities.GetACU(aiBrain)) then
                                    if M27Utilities.IsTableEmpty(oACUPlatoon[M27PlatoonUtilities.reftMovementPath][oACUPlatoon[M27PlatoonUtilities.refiCurrentPathTarget]]) or M27Utilities.GetDistanceBetweenPositions(oACUPlatoon[M27PlatoonUtilities.reftMovementPath][oACUPlatoon[M27PlatoonUtilities.refiCurrentPathTarget]], tEnemyThreatGroup[reftFrontPosition]) > 10 then
                                        --ACU isnt moving near where we want it to, update its movement path if it doesnt have nearby enemies
                                        if oACUPlatoon[M27PlatoonUtilities.refiEnemiesInRange] == 0 or M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE, M27Utilities.GetACU(aiBrain):GetPosition(), 23, 'Enemy')) == true then
                                            --ACU range is 22
                                            oACUPlatoon[M27PlatoonUtilities.reftMovementPath] = {}
                                            oACUPlatoon[M27PlatoonUtilities.reftMovementPath][1] = tEnemyThreatGroup[reftFrontPosition]
                                            oACUPlatoon[M27PlatoonUtilities.refiCurrentPathTarget] = 1
                                            oACUPlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionReissueMovementPath
                                            oACUPlatoon[M27PlatoonUtilities.refbOverseerAction] = true
                                            if bDebugMessages == true then LOG(sFunctionRef..': ACU not moving where we want it to, updating movement path to enemy threat group front position='..repru(tEnemyThreatGroup[reftFrontPosition])..'; Distance to ACU='..M27Utilities.GetDistanceBetweenPositions(tEnemyThreatGroup[reftFrontPosition], M27PlatoonUtilities.GetPlatoonFrontPosition(oACUPlatoon))) end
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
                        --tEnemyThreatGroup[reftFrontPosition]

                        local tTorpBombersByDistance = {}
                        local iAvailableTorpBombers = 0
                        local refoTorpUnit = 'M27OTorp'
                        local refiCurThreat = 'M27OTorThreat'
                        local iAssignedThreatWanted
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': About to consider if we have any available torp bombers and if so assign them to enemy naval threat. Is table of available torp bombers empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableTorpBombers])))
                        end

                        --Does the enemy have sera t2 destroyers? (flag will determine whether to run platoon logic to look for unsubmerged destroyers)
                        if not(aiBrain[refbEnemyHasSeraDestroyers]) then
                            if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategorySeraphimDestroyer, tEnemyThreatGroup[refoEnemyGroupUnits])) == false then
                                aiBrain[refbEnemyHasSeraDestroyers] = true
                            end
                        end

                        --Do we have a T2+ naval threat near our base that is close to being in firing range?

                        if tEnemyThreatGroup[refiDistanceFromOurBase] < aiBrain[refiNearestT2PlusNavalThreat] or (not(aiBrain[refiNearestT2PlusNavalThreat]) and tEnemyThreatGroup[refiDistanceFromOurBase] <= 260) then
                            for iUnit, oUnit in tEnemyThreatGroup[refoEnemyGroupUnits] do
                                if EntityCategoryContains(M27UnitInfo.refCategoryAllNavy - categories.TECH1, oUnit.UnitId) then
                                    aiBrain[refiNearestT2PlusNavalThreat] = math.min(aiBrain[refiNearestT2PlusNavalThreat], tEnemyThreatGroup[refiDistanceFromOurBase])
                                    if not(aiBrain[refbT2NavyNearOurBase]) and 65 + math.max(130, M27UnitInfo.GetUnitIndirectRange(oUnit), M27Logic.GetUnitMaxGroundRange({ oUnit })) >= tEnemyThreatGroup[refiDistanceFromOurBase] then
                                        aiBrain[refbT2NavyNearOurBase] = true
                                        break
                                    end
                                end
                            end
                        end


                        --tAvailablePlatoons, refiActualDistanceFromEnemy




                        if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableTorpBombers]) == false then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Number of available torp bombers=' .. table.getn(aiBrain[M27AirOverseer.reftAvailableTorpBombers]))
                            end
                            --Determine closest available torpedo bombers (unless we should only target ACU)
                            if aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill and M27UnitInfo.IsUnitUnderwater(aiBrain[refoACUKillTarget]) == true then
                                --Do nothing (logic is in air overseer)
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Enemy ACU is underwater and we are trying to kill it, so wont use normal torp defence logic (as we handle ACU kill elsewhere)')
                                end
                            else
                                for iUnit, oUnit in aiBrain[M27AirOverseer.reftAvailableTorpBombers] do
                                    if not (oUnit.Dead) and not (oUnit[M27AirOverseer.refbOnAssignment]) then
                                        iAvailableTorpBombers = iAvailableTorpBombers + 1
                                        tTorpBombersByDistance[iAvailableTorpBombers] = {}
                                        tTorpBombersByDistance[iAvailableTorpBombers][refoTorpUnit] = oUnit
                                        tTorpBombersByDistance[iAvailableTorpBombers][refiActualDistanceFromEnemy] = M27Utilities.GetDistanceBetweenPositions(tEnemyThreatGroup[reftFrontPosition], oUnit:GetPosition())
                                        --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride, bIncludeAirTorpedo)
                                        tTorpBombersByDistance[iAvailableTorpBombers][refiCurThreat] = M27Logic.GetAirThreatLevel(aiBrain, { oUnit }, false, false, false, false, false, nil, nil, nil, nil, true)
                                        iAvailableThreat = iAvailableThreat + tTorpBombersByDistance[iAvailableTorpBombers][refiCurThreat]
                                    end
                                end
                            end
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': After going through any available torp bombers. threatgroup='..iEnemyGroup..'; iAvailableThreat=' .. iAvailableThreat .. '; iThreatNeeded=' .. iThreatNeeded .. '; iAvailableTorpBombers=' .. iAvailableTorpBombers .. '; bACUNeedsTorpSupport=' .. tostring(bACUNeedsTorpSupport))
                        end
                        if not (bACUNeedsTorpSupport) and (iAvailableThreat >= iThreatNeeded or iAvailableTorpBombers >= 30 or (aiBrain[refbT2NavyNearOurBase] and iAvailableTorpBombers >= 8)) or (bACUNeedsTorpSupport and iAvailableTorpBombers > 1) then
                            --and (not(bACUNeedsTorpSupport) or iAvailableTorpBombers >= 3) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy threat gorup distance from base='..tEnemyThreatGroup[refiDistanceFromOurBase]..'; Max torp bomber range by pond='..(tiMaxTorpBomberRangeByPond[M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeNavy, tEnemyThreatGroup[reftFrontPosition])] or 10000)) end
                            if tEnemyThreatGroup[refiDistanceFromOurBase] >= (tiMaxTorpBomberRangeByPond[M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeNavy, tEnemyThreatGroup[reftFrontPosition])] or 10000) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Threat group too far away so wont attack it. tEnemyThreatGroup[refiDistanceFromOurBase]='..tEnemyThreatGroup[refiDistanceFromOurBase]..'; iMaxTorpBomberRange='..(tiMaxTorpBomberRangeByPond[M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeNavy, tEnemyThreatGroup[reftFrontPosition])] or 10000)) end
                                iTorpBomberThreatNotUsed = math.max(iTorpBomberThreatNotUsed, iAvailableThreat)
                                iCumulativeTorpBomberThreatShortfall = iCumulativeTorpBomberThreatShortfall + iThreatNeeded
                            else

                                for iEntry, tTorpSubtable in M27Utilities.SortTableBySubtable(tTorpBombersByDistance, refiActualDistanceFromEnemy, true) do
                                    --Cycle through each enemy unit in the threat group
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Considering torp bomber ' .. tTorpSubtable[refoTorpUnit].UnitId .. M27UnitInfo.GetUnitLifetimeCount(tTorpSubtable[refoTorpUnit]) .. '; tTorpSubtable[refiCurThreat]=' .. (tTorpSubtable[refiCurThreat] or 0) .. '; about to cycle through every enemy unit in threat group to see if should attack one of them')
                                    end
                                    local iMaxRangeToSendTorps = 10000
                                    local iMaxAngleDifToSendTorps
                                    local iAngleFromBaseToACU
                                    if bACUNeedsTorpSupport then
                                        iMaxRangeToSendTorps = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27Utilities.GetACU(aiBrain):GetPosition()) + 90
                                        iAngleFromBaseToACU = M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27Utilities.GetACU(aiBrain):GetPosition())
                                        iMaxAngleDifToSendTorps = 25
                                    end

                                    --First try AirAA units in the threat group
                                    local tEnemyUnits
                                    if bDebugMessages == true then LOG(sFunctionRef..': Is table of tEnemyThreatGroup[refoEnemyGroupUnits] empty='..tostring(M27Utilities.IsTableEmpty(tEnemyUnits))) end

                                    if M27Utilities.IsTableEmpty(tEnemyThreatGroup[refoEnemyGroupUnits]) == false then
                                        local tEnemyPriorityUnits = {}
                                        local tEnemyMedPriorityUnits = {}
                                        local tEnemyLowPriorityUnits = {}
                                        --Manually create tables as having issues with entitycategoryfilterdown
                                        for iUnit, oUnit in tEnemyThreatGroup[refoEnemyGroupUnits] do
                                            if M27UnitInfo.IsUnitValid(oUnit) then
                                                if EntityCategoryContains(M27UnitInfo.refCategoryGroundAA + categories.SHIELD + M27UnitInfo.refCategoryStealthBoat, oUnit.UnitId) then table.insert(tEnemyPriorityUnits, oUnit)
                                                elseif EntityCategoryContains(M27UnitInfo.refCategorySubmarine + M27UnitInfo.refCategoryFrigate, oUnit.UnitId) then table.insert(tEnemyMedPriorityUnits, oUnit)
                                                else table.insert(tEnemyLowPriorityUnits, oUnit)
                                                end
                                            end
                                        end

                                        for iPriority = 1, 3 do
                                            if iPriority == 1 then tEnemyUnits = tEnemyPriorityUnits
                                            elseif iPriority == 2 then tEnemyUnits = tEnemyMedPriorityUnits
                                            else tEnemyUnits = tEnemyLowPriorityUnits end
                                            --[[if iPriority == 1 then tEnemyUnits = EntityCategoryFilterDown(M27UnitInfo.refCategoryGroundAA + categories.SHIELD, tEnemyThreatGroup[refoEnemyGroupUnits])
                                            else tEnemyUnits = tEnemyThreatGroup[refoEnemyGroupUnits]
                                            end--]]
                                            if bDebugMessages == true then LOG(sFunctionRef..': iPriority being considered='..iPriority..'; Is table empty='..tostring(M27Utilities.IsTableEmpty(tEnemyUnits))) end

                                            if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                                                for iUnit, oUnit in tEnemyUnits do
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Considering oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' within the curernt threat group. tTorpSubtable[refiActualDistanceFromEnemy]=' .. (tTorpSubtable[refiActualDistanceFromEnemy] or 'nil') .. '; iMaxRangeToSendTorps=' .. (iMaxRangeToSendTorps or 'nil') .. '; Does unit contain groundAA category=' .. tostring(EntityCategoryContains(M27UnitInfo.refCategoryGroundAA, oUnit.UnitId)))
                                                    end
                                                    --If need to protect ACU then ignore other naval threats
                                                    if not (bACUNeedsTorpSupport) or (tTorpSubtable[refiActualDistanceFromEnemy] <= iMaxRangeToSendTorps and (tTorpSubtable[refiActualDistanceFromEnemy] <= 120 or math.abs(M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) - iAngleFromBaseToACU) <= iMaxAngleDifToSendTorps)) then
                                                        if iPriority == 2 then
                                                            --Not dealing with dedicated AA units, assign torp bombers based on strike damage, or AA threat if higher
                                                            iAssignedThreatWanted = math.max(iNavalThreatMaxFactor * (oUnit[iArmyIndex][refiUnitNavalAAThreat] or 0), (tTorpSubtable[refiCurThreat] or 270) / 750 * oUnit:GetHealth())
                                                            if EntityCategoryContains(M27UnitInfo.refCategoryGroundAA, oUnit.UnitId) then
                                                                iAssignedThreatWanted = iAssignedThreatWanted * 1.34
                                                            end
                                                        else
                                                            --T2 torp bomber should have threat of 270 and a strike damage of 750; however some may die on the way, so try to assign enough to kill the target and a bit more; during testing, if enemy cruiser isnt doing kiting retreat then 5 torp bombers can kill 1 cruiser of most factions (not seraphim)
                                                            iAssignedThreatWanted = 270 / 750 * oUnit:GetMaxHealth() * 1.5
                                                            if oUnit:GetMaxHealth() > 2500 then
                                                                iAssignedThreatWanted = iAssignedThreatWanted + 270
                                                            end
                                                        end
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': Enemy Unit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; iAssignedThreat=' .. (oUnit[iArmyIndex][refiAssignedThreat] or 0) .. '; oUnit[iArmyIndex][refiUnitNavalAAThreat]=' .. (oUnit[iArmyIndex][refiUnitNavalAAThreat] or 0) .. '; iNavalThreatMaxFactor=' .. iNavalThreatMaxFactor .. '; iAssignedThreatWanted=' .. iAssignedThreatWanted)
                                                        end

                                                        if oUnit[iArmyIndex][refiAssignedThreat] <= iAssignedThreatWanted then
                                                            oUnit[iArmyIndex][refiAssignedThreat] = oUnit[iArmyIndex][refiAssignedThreat] + tTorpSubtable[refiCurThreat]
                                                            M27Utilities.IssueTrackedClearCommands({ tTorpSubtable[refoTorpUnit] })
                                                            IssueAttack({ tTorpSubtable[refoTorpUnit] }, oUnit)
                                                            M27AirOverseer.TrackBomberTarget(tTorpSubtable[refoTorpUnit], oUnit, 1, true)
                                                            if M27Utilities.IsTableEmpty(tEnemyPriorityUnits) == false then
                                                                for iUnit, oUnit in tEnemyPriorityUnits do
                                                                    IssueAttack({ tTorpSubtable[refoTorpUnit] }, oUnit)
                                                                    M27AirOverseer.TrackBomberTarget(tTorpSubtable[refoTorpUnit], oUnit, 1, false)
                                                                end
                                                            end
                                                            IssueAggressiveMove({ tTorpSubtable[refoTorpUnit] }, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                                            tTorpSubtable[refoTorpUnit][M27AirOverseer.refbOnAssignment] = true
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': Clearing torp bomber and then Telling torpedo bomber with ID ref=' .. tTorpSubtable[refoTorpUnit].UnitId .. M27UnitInfo.GetUnitLifetimeCount(tTorpSubtable[refoTorpUnit]) .. ' to attack ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; GameTime=' .. GetGameTimeSeconds())
                                                            end
                                                            iAvailableTorpBombers = iAvailableTorpBombers - 1
                                                            break
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            iCumulativeTorpBomberThreatShortfall = iCumulativeTorpBomberThreatShortfall + iThreatNeeded
                            if bFirstUnassignedNavyThreat == true then
                                bFirstUnassignedNavyThreat = false
                                iCumulativeTorpBomberThreatShortfall = iCumulativeTorpBomberThreatShortfall - iAvailableThreat
                                --[[if bACUNeedsTorpSupport then
                                    for iUnit, oUnit in aiBrain[M27AirOverseer.reftAvailableTorpBombers] do
                                        if not(oUnit[M27AirOverseer.refbOnAssignment]) then
                                            M27Utilities.IssueTrackedClearCommands({oUnit})
                                            IssueAggressiveMove({oUnit}, oACU:GetPosition())
                                            oUnit[M27AirOverseer.refbOnAssignment] = true
                                            --oUnit[M27AirOverseer.refbTorpBomberProtectingACU] = true
                                            M27Utilities.DelayChangeVariable(oUnit, M27AirOverseer.refbOnAssignment, false, 45)
                                        end
                                    end
                                end--]]
                            end
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Dont have enough torp bombers; iCumulativeTorpBomberThreatShortfall=' .. iCumulativeTorpBomberThreatShortfall)
                            end
                        end
                    end --Not dealing with navy
                end
            end --for each tEnemyThreatGroup
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Finished cycling through all tEnemyThreatGroups; end of overseer cycle')
        end
        --if bDebugMessages == true then LOG(sFunctionRef..': End of code - ACU state='..M27Logic.GetUnitState(M27Utilities.GetACU(aiBrain))) end
    else
        if bFirstThreatGroup == true then
            --Redundancy - dont think we actually need this check as iCurThreatGroup gets increased for threats of any category
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

    --Do we have sniper bots near our base? then will flag that we want indirect fire units
    if not (aiBrain[refbNeedIndirect]) and aiBrain[refiOurHighestLandFactoryTech] >= 3 and aiBrain[refiModDistFromStartNearestThreat] <= 200 and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategorySniperBot, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 200, 'Enemy')) == false then
        aiBrain[refbNeedIndirect] = true
    end

    --Expand nearest structure to include those damaging/killing our units that havent been revealed yet
    local iCurDist
    if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyArtiToAvoid]) == false then
        for iUnit, oUnit in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyArtiToAvoid] do
            iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            if iCurDist < aiBrain[refiNearestEnemyT2PlusStructure] then
                aiBrain[refiNearestEnemyT2PlusStructure] = iCurDist
                aiBrain[refoNearestEnemyT2PlusStructure] = oUnit
            end
        end
    end
    if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftUnseenPD]) == false then
        for iUnit, oUnit in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftUnseenPD] do
            iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            if iCurDist < aiBrain[refiNearestEnemyT2PlusStructure] then
                aiBrain[refiNearestEnemyT2PlusStructure] = iCurDist
                aiBrain[refoNearestEnemyT2PlusStructure] = oUnit
            end
        end
    end

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
                        sPlatoonRef = sPlatoonName .. oPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                        if oPlatoon[refsEnemyThreatGroup] then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': sPlatoonRef=' .. sPlatoonRef .. '; oPlatoon[refsEnemyThreatGroup]=' .. oPlatoon[refsEnemyThreatGroup] .. '; checking if refsEnemyThreatGroup is in table of threat groups')
                            end
                            if aiBrain[reftEnemyThreatGroup][oPlatoon[refsEnemyThreatGroup]] then
                                bAssignedCurrentThreatGroup = true
                                --Do we have any units below the desired tech level?
                                iHighestThreatTech = aiBrain[reftEnemyThreatGroup][oPlatoon[refsEnemyThreatGroup]][refiThreatGroupHighestTech]
                                if iHighestThreatTech > 1 and oPlatoon[M27PlatoonUtilities.refiCurrentUnits] > 0 then
                                    tTech1Units = EntityCategoryFilterDown(categories.TECH1, oPlatoon[M27PlatoonUtilities.reftCurrentUnits])
                                    if M27Utilities.IsTableEmpty(tTech1Units) == false then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': ' .. sPlatoonRef .. ': Have t1 units in platoon but targetting a threat group with T2, so removing them')
                                        end
                                        --RemoveUnitsFromPlatoon(oPlatoon, tUnits, bReturnToBase, oPlatoonToAddTo)
                                        M27PlatoonUtilities.RemoveUnitsFromPlatoon(oPlatoon, tTech1Units, true, aiBrain[M27PlatoonTemplates.refoIdleIndirect])
                                    end
                                end
                            end
                        end
                        if bAssignedCurrentThreatGroup == false then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': ' .. sPlatoonRef .. ': Dont have a current threat group target so telling platoon to disband')
                            end
                            oPlatoon[M27PlatoonUtilities.refiCurrentAction] = M27PlatoonUtilities.refActionDisband
                        end
                    end
                end
            end
        end
    end

    --Do we have land experimentals that are underwater and have taken damage from an unseen enemy in the last 30s?
    local oFurthestExperimentalNeedingHelp
    if M27MapInfo.bMapHasWater then
        local tLandExperimentals = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryLandExperimental, false, true)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Is table of land experimentals empty=' .. tostring(M27Utilities.IsTableEmpty(tLandExperimentals)))
        end
        if M27Utilities.IsTableEmpty(tLandExperimentals) == false then
            local iClosestDistToEnemy = 10000
            local iCurDist
            for iUnit, oUnit in tLandExperimentals do
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Considering land experimental ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; oUnit[refiACULastTakenUnseenOrTorpedoDamage]=' .. (oUnit[refiACULastTakenUnseenOrTorpedoDamage] or 'nil') .. '; GetGameTimeSeconds()=' .. GetGameTimeSeconds() .. '; Is underwater=' .. tostring(M27UnitInfo.IsUnitUnderwater(oUnit)))
                end
                if oUnit[refiACULastTakenUnseenOrTorpedoDamage] and GetGameTimeSeconds() - oUnit[refiACULastTakenUnseenOrTorpedoDamage] <= 30 and M27UnitInfo.IsUnitUnderwater(oUnit) and M27UnitInfo.IsUnitValid(oUnit[refoUnitDealingUnseenDamage]) and EntityCategoryContains(categories.ANTINAVY + categories.OVERLAYANTINAVY, oUnit[refoUnitDealingUnseenDamage].UnitId) then
                    iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': iCurDist=' .. iCurDist)
                    end
                    if iCurDist < iClosestDistToEnemy then
                        iClosestDistToEnemy = iCurDist
                        oFurthestExperimentalNeedingHelp = oUnit
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Recording unit as the experimental closest to the enemy')
                        end
                    end
                end
            end
        end
    end
    if oFurthestExperimentalNeedingHelp then
        iCumulativeTorpBomberThreatShortfall = iCumulativeTorpBomberThreatShortfall + 2000
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Have an experimental needing torp bomber support, havei ncreased shortfall by 2k to ' .. iCumulativeTorpBomberThreatShortfall)
        end
    end

    --Increase torp bomber threat shortfall for unseen enemy cruisers
    if M27Utilities.IsTableEmpty(tAllRecentlySeenCruisers) == false then
        local iRemainingAvailableTorps = 0 --Calculate again here due to risk that we have no naval threats to consider in main logic above but have hidden cruisers leading to always producing torps
        if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableTorpBombers]) == false then
            for iUnit, oUnit in aiBrain[M27AirOverseer.reftAvailableTorpBombers] do
                if not (oUnit.Dead) and not (oUnit[M27AirOverseer.refbOnAssignment]) then
                    iRemainingAvailableTorps = iRemainingAvailableTorps + 1
                end
            end
        end
        iCumulativeTorpBomberThreatShortfall = iCumulativeTorpBomberThreatShortfall + math.max(0, (table.getn(tAllRecentlySeenCruisers) * 7 - iRemainingAvailableTorps) * 240)
    end

    iCumulativeTorpBomberThreatShortfall = math.max(0, iCumulativeTorpBomberThreatShortfall - iTorpBomberThreatNotUsed)
    if iCumulativeTorpBomberThreatShortfall > 0 then
        aiBrain[M27AirOverseer.refiTorpBombersWanted] = math.ceil(iCumulativeTorpBomberThreatShortfall / 240)
        --Cap based on how many torp bombers we already have
        local iExistingTorpBombers = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryTorpBomber)
        if iExistingTorpBombers >= 70 then
            aiBrain[M27AirOverseer.refiTorpBombersWanted] = math.max(0, math.min(80 - iExistingTorpBombers, aiBrain[M27AirOverseer.refiTorpBombersWanted]))
        end
    else
        aiBrain[M27AirOverseer.refiTorpBombersWanted] = 0
    end


    --Send any idle torp bombers on attack move to base if they're not already headed there
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': is table of available torp bombers empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableTorpBombers]))..'; iTorpBomberThreatNotUsed='..iTorpBomberThreatNotUsed..'; iCumulativeTorpBomberThreatShortfall after adjusting for torp bomber threat not used='..iCumulativeTorpBomberThreatShortfall)
    end
    if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableTorpBombers]) == false then
        local tRallyPoint
        if bACUNeedsTorpSupport then
            tRallyPoint = M27Utilities.MoveInDirection(oACU:GetPosition(), M27Utilities.GetAngleFromAToB(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]), 15, true)
        else
            --Do we have any underwater experimentals?
            if oFurthestExperimentalNeedingHelp then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Making rally point the position of the experimental that needs help, which is ' .. repru(oFurthestExperimentalNeedingHelp:GetPosition()))
                end
                tRallyPoint = oFurthestExperimentalNeedingHelp:GetPosition()
            else
                tRallyPoint = M27AirOverseer.GetAirRallyPoint(aiBrain)
            end
        end
        local tCurDestination, oNavigator
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Rally point to use=' .. repru(tRallyPoint))
        end
        for iUnit, oUnit in aiBrain[M27AirOverseer.reftAvailableTorpBombers] do
            tCurDestination = nil
            if not (oUnit[M27AirOverseer.refbOnAssignment]) then
                if oUnit.GetNavigator and M27UnitInfo.IsUnitValid(oUnit) then
                    oNavigator = oUnit:GetNavigator()
                    if oNavigator and oNavigator.GetCurrentTargetPos then
                        tCurDestination = oNavigator:GetCurrentTargetPos()
                    end
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': TorpBomber=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; tCurDestination=' .. repru((tCurDestination or { 'nil' })) .. '; will attackmove to rally point if destination is too far from rally point. Rallypoint=' .. repru(tRallyPoint) .. '; dist to rallypoint=' .. M27Utilities.GetDistanceBetweenPositions((tCurDestination or { 0, 0, 0 }), tRallyPoint) .. '; oUnit[M27AirOverseer.refbOnAssignment]=' .. tostring(oUnit[M27AirOverseer.refbOnAssignment]))
                end
                if not (tCurDestination) or M27Utilities.GetDistanceBetweenPositions(tCurDestination, tRallyPoint) >= 10 then
                    M27Utilities.IssueTrackedClearCommands({ oUnit })
                    IssueAggressiveMove({ oUnit }, tRallyPoint)
                end
            end
        end
    end



    --if bDebugMessages == true then LOG(sFunctionRef..': End of code, getting ACU debug plan and action') DebugPrintACUPlatoon(aiBrain) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ACUManager(aiBrain)
    --A lot of the below code is a hangover from when the ACU would use the built in AIBuilders and platoons;
    --Almost all the functionality has now been integrated into the M27ACUMain platoon logic, with a few exceptions (such as calling for help), although these could probably be moved over as well
    --Decided to add more global based ACU logic here, e.g. if we want to attack enemy ACU, or if we want to retreat to base immediately rather than waiting for platoon, or if want to cancel upgrade

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ACUManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetGameTimeSeconds() >= 960 and (aiBrain:GetArmyIndex() == 4 or aiBrain:GetArmyIndex() == 6) then bDebugMessages = true M27Config.M27ShowUnitNames = true end

    if not (aiBrain.M27IsDefeated) and M27Logic.iTimeOfLastBrainAllDefeated < 10 then
        local oACU = M27Utilities.GetACU(aiBrain)
        --if oACU:IsUnitState('Upgrading') and aiBrain:GetArmyIndex() == 4 then bDebugMessages = true end

        --Track ACU health over time
        if not (oACU[reftACURecentHealth]) then
            oACU[reftACURecentHealth] = {}
        end
        local iACUCurShield, iACUMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oACU)
        local iCurTime = math.floor(GetGameTimeSeconds())
        oACU[reftACURecentHealth][iCurTime] = oACU:GetHealth() + iACUCurShield
        --Update prev health if no value
        if not(oACU[reftACURecentHealth][iCurTime]) then
            for iTimeAdj = 1, 10, 1 do
                if not(oACU[reftACURecentHealth][iCurTime - iTimeAdj]) then
                    oACU[reftACURecentHealth][iCurTime - iTimeAdj] = oACU[reftACURecentHealth][iCurTime]
                else
                    break
                end
            end
        end

        --Clear entries from more than 1m ago
        if oACU[reftACURecentHealth][iCurTime - 60] then
            local iCurAdjust = 60
            while oACU[reftACURecentHealth][iCurTime - iCurAdjust] do

                oACU[reftACURecentHealth][iCurTime - iCurAdjust] = nil
                iCurAdjust = iCurAdjust + 1
            end
        end

        --if M27Utilities.IsACU(oACU) then

        if not (oACU[refbACUOnInitialBuildOrder]) then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Start of code - ACU isnt on initial build order')
            end
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
            if oACUPlatoon and oACUPlatoon.GetPlan then
                sPlatoonName = oACUPlatoon:GetPlan()
            end
            local oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')

            --Variables used later that want to reference regardless of whether have an ACU or not
            local bIncludeACUInAttack
            local bWantEscort
            local bEmergencyRequisition
            local bAllInAttack
            local bACUAirSnipe

            local oEnemyACUToConsiderAttacking

            --ACU platoon and idle overrides
            local iOurACUDistToOurBase = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tACUPos)
            local iOurACUDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), tACUPos)
            if M27Utilities.IsACU(oACU) then

                if oACUPlatoon then
                    aiBrain[refiCyclesThatACUHasNoPlatoon] = 0
                    if oACUPlatoon == oArmyPoolPlatoon then
                        sPlatoonName = 'ArmyPool'
                        aiBrain[refiCyclesThatACUInArmyPool] = aiBrain[refiCyclesThatACUInArmyPool] + 1
                    elseif sPlatoonName == 'M27ACUMain' then
                        --Clear engineer trackers if have an action assigned that doesnt correspond to platoon action
                        if oACU[M27EngineerOverseer.refiEngineerCurrentAction] and oACUPlatoon[M27PlatoonUtilities.refiCurrentAction] then
                            if not (oACU:IsUnitState('Building') or oACU:IsUnitState('Repairing')) then
                                local iCurAction = oACUPlatoon[M27PlatoonUtilities.refiCurrentAction]
                                if not (iCurAction == M27PlatoonUtilities.refActionBuildFactory or iCurAction == M27PlatoonUtilities.refActionBuildInitialPower) then
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
                            if not (oACU:IsUnitState('Upgrading')) then
                                oACU.PlatoonHandle[M27PlatoonUtilities.refiCurrentAction] = M27PlatoonUtilities.refActionDisband
                                local oNewPlatoon = aiBrain:MakePlatoon('', '')
                                aiBrain:AssignUnitsToPlatoon(oNewPlatoon, { oACU }, 'Attack', 'None')
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
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': ACU is idle, iIdleCount=' .. iIdleCount)
                    end
                    iIdleCount = iIdleCount + 1
                    if iIdleCount > iIdleThreshold then
                        local oNewPlatoon = aiBrain:MakePlatoon('', '')
                        aiBrain:AssignUnitsToPlatoon(oNewPlatoon, { oACU }, 'Attack', 'None')
                        oNewPlatoon:SetAIPlan('M27ACUMain')
                        if oACUPlatoon and not (oACUPlatoon == oArmyPoolPlatoon) and oACUPlatoon.PlatoonDisband then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Disbanding ACU current platoon')
                            end
                            oACUPlatoon:PlatoonDisband()
                        end
                        if bDebugMessages == true then
                            local iPlatoonCount = oNewPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                            if iPlatoonCount == nil then
                                iPlatoonCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27ACUMain']
                                if iPlatoonCount == nil then
                                    iPlatoonCount = 1
                                else
                                    iPlatoonCount = iPlatoonCount + 1
                                end
                            end
                            LOG(sFunctionRef .. ': Changed ACU platoon back to ACU main, platoon name+count=' .. 'M27ACUMain' .. iPlatoonCount)
                        end
                    end
                else
                    iIdleCount = 0
                end

                --==============ACU PLATOON FORM OVERRIDES==========------------
                --Check to try and ensure ACU gets put in a platoon when its gun upgrade has finished (sometimes this doesnt happen)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. 'oACU[refbACUHelpWanted]=' .. tostring(oACU[refbACUHelpWanted]))
                end
                if not (sPlatoonName == 'M27ACUMain') then

                    if M27Conditions.DoesACUHaveUpgrade(aiBrain) == true then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': ACU has gun, switching it to the ACUMain platoon if its not using it')
                        end
                        local bReplacePlatoon = true
                        if sPlatoonName == 'M27ACUMain' then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': ACU is using M27ACUMain already so dont refresh platoon')
                            end
                            bReplacePlatoon = false
                        else
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': ACU is using ' .. sPlatoonName .. ': Will refresh unless are building')
                            end
                            --Check if are building something
                            local bLetACUFinishBuilding = false
                            if oACU:IsUnitState('Building') == true then
                                local oUnitBeingBuilt = oACU:GetFocusUnit()
                                if oUnitBeingBuilt:GetFractionComplete() <= 0.25 then
                                    --Only keep building if is a mex
                                    local sBeingBuilt = oUnitBeingBuilt.UnitId
                                    if EntityCategoryContains(categories.MASSEXTRACTION, sBeingBuilt) == true then
                                        bLetACUFinishBuilding = true
                                    end
                                else
                                    bLetACUFinishBuilding = true
                                end
                            end

                            if bLetACUFinishBuilding == true then
                                bReplacePlatoon = true
                            end
                        end
                        if bReplacePlatoon == true then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': ACU is using ' .. sPlatoonName .. ': Are creating a new AI for ACU')
                            end
                            local oNewPlatoon = aiBrain:MakePlatoon('', '')
                            aiBrain:AssignUnitsToPlatoon(oNewPlatoon, { oACU }, 'Attack', 'None')
                            oNewPlatoon:SetAIPlan('M27ACUMain')
                            if bDebugMessages == true then
                                local iPlatoonCount = oNewPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                if iPlatoonCount == nil then
                                    iPlatoonCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27ACUMain']
                                    if iPlatoonCount == nil then
                                        iPlatoonCount = 1
                                    else
                                        iPlatoonCount = iPlatoonCount + 1
                                    end
                                end
                                LOG(sFunctionRef .. ': Changed ACU platoon back to ACU main, platoon name+count=' .. 'M27ACUMain' .. iPlatoonCount)
                            end
                        end
                    else
                        --NOTE: Rare error where ACU would start upgrade and then cancel straight away - if happens again, expand the code where are disbanding to get upgrade so that it also assigns the command to get the upgrade
                        local bCreateNewPlatoon = false
                        local bDisbandExistingPlatoon = false
                        if oACUPlatoon == nil then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': ACU has no gun and no platoon')
                            end
                            if aiBrain[refiCyclesThatACUHasNoPlatoon] > 4 then
                                --5 cycles where no platoon, so create a new one unless ACU is busy
                                if GetGameTimeSeconds() > 30 then
                                    --at start of game is a wait of longer than 4 seconds before ACU is able to do anything
                                    bCreateNewPlatoon = true
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': ACU been in no platoon for ' .. aiBrain[refiCyclesThatACUHasNoPlatoon] .. ' cycles so giving it a platoon unless its reclaiming/repairing/upgrading/building')
                                    end
                                    --Dont create if ACU is doing somethign likely useful
                                    if oACU:IsUnitState('Building') == true or oACU:IsUnitState('Reclaiming') == true or oACU:IsUnitState('Repairing') == true or oACU:IsUnitState('Upgrading') == true or oACU:IsUnitState('Guarding') then
                                        bCreateNewPlatoon = false
                                    end
                                end
                            end
                        else
                            if oACUPlatoon == oArmyPoolPlatoon then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': ACU has no gun is in army pool, will try and create a new platoon if no help needed from ACU')
                                end
                                if oACU[refbACUHelpWanted] == false then
                                    bCreateNewPlatoon = true
                                else
                                    if aiBrain[refiCyclesThatACUInArmyPool] > 9 then
                                        if GetGameTimeSeconds() > 30 then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': ACU been in army pool for ' .. aiBrain[refiCyclesThatACUInArmyPool] .. ' cycles so giving it a platoon unless its reclaiming/repairing/upgrading/building/guarding')
                                            end
                                            if oACU:IsUnitState('Building') == true or oACU:IsUnitState('Reclaiming') == true or oACU:IsUnitState('Repairing') == true or oACU:IsUnitState('Upgrading') == true or oACU:IsUnitState('Guarding') then
                                                bCreateNewPlatoon = false
                                            end
                                            bCreateNewPlatoon = true --Dont want ACU staying in army pool if its still not been used
                                        end
                                    end
                                end
                            else
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': ACU has no gun and is in platoon ' .. sPlatoonName)
                                end
                                --ACU is in a platoon but its not the army pool; disband if meet the conditions for gun upgrade and ACU not building
                                bDisbandExistingPlatoon = true
                                if oACU:IsUnitState('Building') == true or oACU:IsUnitState('Repairing') == true or oACU:IsUnitState('Upgrading') == true then
                                    bDisbandExistingPlatoon = false
                                else
                                    bDisbandExistingPlatoon = M27Conditions.WantToGetFirstACUUpgrade(aiBrain)
                                end
                                if bDisbandExistingPlatoon == true then
                                    --Check no nearby enemies first
                                    bDisbandExistingPlatoon = false
                                    if oACUPlatoon[M27PlatoonUtilities.refiEnemiesInRange] == nil or oACUPlatoon[M27PlatoonUtilities.refiEnemiesInRange] == 0 then
                                        local tNearbyEnemyUnits = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.DIRECTFIRE + categories.LAND * categories.INDIRECTFIRE, tACUPos, aiBrain[refiSearchRangeForEnemyStructures], 'Enemy')
                                        if M27Utilities.IsTableEmpty(tNearbyEnemyUnits) == true then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': ACU has no nearby enemies so about to disband so it can upgrade to gun, but first checking if it needs to heal')
                                            end
                                            --Check not injured and wanting to heal
                                            if not (oACUPlatoon[M27PlatoonUtilities.refbNeedToHeal] == true) then
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': ACU needs to heal')
                                                end
                                                bDisbandExistingPlatoon = true
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if bDisbandExistingPlatoon == true then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': ACU ready to get gun so disbanding')
                            end
                            if oACUPlatoon and aiBrain:PlatoonExists(oACUPlatoon) then
                                oACUPlatoon:PlatoonDisband()
                                M27EngineerOverseer.ClearEngineerActionTrackers(aiBrain, oACU, true)
                            end
                        elseif bCreateNewPlatoon == true then
                            local oNewPlatoon = aiBrain:MakePlatoon('', '')
                            aiBrain:AssignUnitsToPlatoon(oNewPlatoon, { oACU }, 'Support', 'None')
                            oNewPlatoon:SetAIPlan('M27ACUMain')
                            aiBrain[refiCyclesThatACUInArmyPool] = 0
                            aiBrain[refiCyclesThatACUHasNoPlatoon] = 0
                            if bDebugMessages == true then
                                local iPlatoonCount = oNewPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                                if iPlatoonCount == nil then
                                    iPlatoonCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27ACUMain']
                                    if iPlatoonCount == nil then
                                        iPlatoonCount = 1
                                    else
                                        iPlatoonCount = iPlatoonCount + 1
                                    end
                                end
                                LOG(sFunctionRef .. ': Changed ACU platoon back to ACU main, platoon name+count=' .. 'M27ACUMain' .. iPlatoonCount)
                            end
                        end
                    end
                end

                --==============BUILD ORDER RELATED=============
                --Update the build condition flag for if ACU is near an unclaimed mex or has nearby reclaim, unless ACU is part of the main acu platoon ai (which already has this logic in it)
                local sACUPlan = DebugPrintACUPlatoon(aiBrain, true)
                local bPlatoonAlreadyChecks = false
                if sACUPlan == 'M27ACUMain' then
                    if not (oACUPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionDisband) then
                        bPlatoonAlreadyChecks = true
                    end
                end
                if bPlatoonAlreadyChecks == false then
                    --Check for nearby mexes:
                    local sPathing = M27UnitInfo.GetUnitPathingType(oACU)
                    if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then
                        sPathing = M27UnitInfo.refPathingTypeLand
                    end
                    --GetSegmentGroupOfTarget(sPathing, iSegmentX, iSegmentZ)
                    local iACUSegmentX, iACUSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tACUPos)
                    local iSegmentGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iACUSegmentX, iACUSegmentZ)
                    local tNearbyUnits = {}
                    --M27MapInfo.RecordMexForPathingGroup(oACU) --Makes sure we can reference tMexByPathingAndGrouping
                    local iCurDistToACU
                    local iBuildingSizeRadius = 0.5
                    local bNearbyUnclaimedMex = false
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': sPathing=' .. sPathing .. '; iSegmentGroup=' .. iSegmentGroup .. '; No. of mexes in tMexByPathingAndGrouping=' .. table.getn(M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup]))
                    end
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
                bAllInAttack = false
                bIncludeACUInAttack = false
                local iHealthThresholdAdjIfAlreadyAllIn = 0
                local iHealthAbsoluteThresholdIfAlreadyAllIn = 750
                local bCheckThreatBeforeCommitting = true
                local iEnemyThreat, iAlliedThreat, tEnemyUnitsNearEnemy, tAlliedUnitsNearEnemy
                local iThreatFactor = 1.1 --We need this much more threat than threat around enemy ACU to commit to ACU kill
                local iNearbyThreatSearchRange = 60 --Search range for threat around enemy ACU
                if aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill then
                    iHealthThresholdAdjIfAlreadyAllIn = 0.05
                end
                iACUCurShield, iACUMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oACU)
                bWantEscort = oACU:IsUnitState('Upgrading')
                if bWantEscort and M27UnitInfo.GetUnitHealthPercent(oACU) >= 0.95 and iACUCurShield >= iACUMaxShield * 0.95 and M27Conditions.DoesACUHaveGun(aiBrain, false, oACU) then
                    bWantEscort = false
                end

                bEmergencyRequisition = false
                local iLastDistanceToACU = 10000
                if aiBrain[reftLastNearestACU] then
                    iLastDistanceToACU = M27Utilities.GetDistanceBetweenPositions(aiBrain[reftLastNearestACU], tACUPos)
                end



                if M27Utilities.IsTableEmpty(tEnemyACUs) == false then
                    local oNearestACU = M27Utilities.GetNearestUnit(tEnemyACUs, tACUPos, aiBrain, false, false)
                    local tNearestACU = oNearestACU:GetPosition()
                    local iDistanceToACU = M27Utilities.GetDistanceBetweenPositions(tNearestACU, tACUPos)
                    if M27UnitInfo.IsUnitValid(aiBrain[refoLastNearestACU]) then
                        if not (aiBrain[refbCloakedEnemyACU]) and oNearestACU:HasEnhancement('CloakingGenerator') then
                            aiBrain[refbCloakedEnemyACU] = true
                        end

                        if oNearestACU == aiBrain[refoLastNearestACU] then
                            aiBrain[reftLastNearestACU] = tNearestACU
                            iLastDistanceToACU = iDistanceToACU
                        else
                            if iDistanceToACU < aiBrain[refiLastNearestACUDistance] or not(M27UnitInfo.IsUnitValid(aiBrain[refoLastNearestACU])) or iDistanceToACU < M27Utilities.GetDistanceBetweenPositions(aiBrain[refoLastNearestACU]:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then
                                aiBrain[refoLastNearestACU] = oNearestACU
                                aiBrain[reftLastNearestACU] = tNearestACU
                                iLastDistanceToACU = iDistanceToACU
                                aiBrain[refiLastNearestACUDistance] = iDistanceToACU
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
                local iACURange = M27Logic.GetUnitMaxGroundRange({ oACU })


                for iEnemyACU, oEnemyACU in tEnemyACUs do
                    if M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), oEnemyACU:GetPosition()) <= iEnemyACUSearchRange then
                        aiBrain[refbEnemyACUNearOurs] = true
                        bWantEscort = true
                    end
                end

                --Set the ACU that will consider when deciding whether to launch an all-out attack - normally will be the closest enemy ACU, but in some cases will consider a different ACU
                if M27UnitInfo.IsUnitValid(aiBrain[refoACUKillTarget]) then
                    --Is there an enemy ACU near to this one that has more than 50% health and is closer to us? If so then only consider the original target if it's really low health
                    if not(aiBrain[refoLastNearestACU] == aiBrain[refoACUKillTarget]) then
                        local iHealthThreshold = 6000
                        --Decrease threshold if enemy ACUs near the actual target
                        for iEnemyACU, oEnemyACU in tEnemyACUs do
                            if not(oEnemyACU == aiBrain[refoACUKillTarget]) then
                                if M27Utilities.GetDistanceBetweenPositions(oEnemyACU:GetPosition(), aiBrain[refoACUKillTarget]:GetPosition()) <= iEnemyACUSearchRange then
                                    iHealthThreshold = 2500
                                    if oACU:GetHealth() <= 6000 then iHealthThreshold = 2000 end
                                    break
                                end
                            end
                        end
                        if aiBrain[refoACUKillTarget]:GetHealth() <= iHealthThreshold then
                            oEnemyACUToConsiderAttacking = aiBrain[refoACUKillTarget]
                        end
                    else
                        --No dif between nearest ACU and ACU kill target
                        oEnemyACUToConsiderAttacking = aiBrain[refoACUKillTarget]
                    end
                else
                    --Do we have a teammate in ACU kill mode and teh ACU is within 400 of our base? If so then consider that ACU provided the nearest ACU to our base is more than max(100, ACU kill target's dist to our base + 30)
                    if M27Utilities.IsTableEmpty(aiBrain[toAllyBrains]) == false and not(aiBrain[refbEnemyACUNearOurs]) and aiBrain[refiModDistFromStartNearestThreat] > aiBrain[M27AirOverseer.refiBomberDefenceCriticalThreatDistance] then
                        local iOtherACUDistToOurBase
                        local iClosestACUDistToOurBase = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[reftLastNearestACU])
                        for iBrain, oBrain in aiBrain[toAllyBrains] do
                            if oBrain.M27AI and oBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill and M27UnitInfo.IsUnitValid(oBrain[refoACUKillTarget]) then
                                iOtherACUDistToOurBase = M27Utilities.GetDistanceBetweenPositions(oBrain[refoACUKillTarget]:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                if bDebugMessages == true then LOG(sFunctionRef..': Deciding whether to target an ACU target of an allied M27. AI ally='..oBrain.Nickname..'; iOtherACUDistToOurBase='..iOtherACUDistToOurBase..'; iClosestACUDistToOurBase='..iClosestACUDistToOurBase..'; 65% towards enemy base='..aiBrain[refiDistanceToNearestEnemyBase]*0.65) end
                                if iClosestACUDistToOurBase > math.max(100, iOtherACUDistToOurBase - 20) and iOtherACUDistToOurBase <= math.max(400, aiBrain[refiDistanceToNearestEnemyBase] * 0.65) then
                                    oEnemyACUToConsiderAttacking = oBrain[refoACUKillTarget]
                                    break
                                end
                            end
                        end
                    end


                end
                if not(oEnemyACUToConsiderAttacking) then oEnemyACUToConsiderAttacking = aiBrain[refoLastNearestACU] end
                if M27UnitInfo.IsUnitValid(oEnemyACUToConsiderAttacking) then
                    iLastDistanceToACU = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), oEnemyACUToConsiderAttacking:GetPosition())
                else
                    iLastDistanceToACU = aiBrain[refiDistanceToNearestEnemyBase]
                end

                --If the ACU is near to us consider attacking with our ACU and/or doing all-out attack
                if iLastDistanceToACU <= iEnemyACUSearchRange and M27UnitInfo.IsUnitValid(oEnemyACUToConsiderAttacking) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Are near last ACU known position, iLastDistanceToACU=' .. iLastDistanceToACU .. '; iEnemyACUSearchRange=' .. iEnemyACUSearchRange)
                    end
                    aiBrain[refbEnemyACUNearOurs] = true
                    bWantEscort = true
                    --Extra health buffer for some of below checks
                    local iExtraHealthCheck = 0
                    if iOurACUDistToOurBase > iOurACUDistToEnemyBase then
                        iExtraHealthCheck = 1000
                    end
                    --Do we have a big gun, or is the enemy ACU low on health?
                    if M27Conditions.DoesACUHaveBigGun(aiBrain, oACU) == true then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Our ACU has a big gun')
                        end
                        bAllInAttack = true
                        bIncludeACUInAttack = true
                    else
                        --Attack if we're close to ACU and have a notable health advantage, and are on our side of the map or are already in attack mode
                        if iLastDistanceToACU <= (iACURange + 15) and M27UnitInfo.GetUnitHealthPercent(oEnemyACUToConsiderAttacking) < (0.5 + iHealthThresholdAdjIfAlreadyAllIn) and oEnemyACUToConsiderAttacking:GetHealth() + iExtraHealthCheck + 2500 < (oACU:GetHealth() + iHealthAbsoluteThresholdIfAlreadyAllIn) and (M27Utilities.GetDistanceBetweenPositions(oEnemyACUToConsiderAttacking:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(oEnemyACUToConsiderAttacking:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) or aiBrain[refbIncludeACUInAllOutAttack] == true) then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Enemy ACU is almost in range of us and is on low health so will do all out attack')
                            end
                            bAllInAttack = true
                            bIncludeACUInAttack = true
                            bCheckThreatBeforeCommitting = true
                            --Attack if enemy ACU is in range and could die to an explosion (so we either win or draw)
                        elseif iLastDistanceToACU <= iACURange and oEnemyACUToConsiderAttacking:GetHealth() < (1800 + iHealthAbsoluteThresholdIfAlreadyAllIn) then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Enemy ACU will die to explaosion so want to stay close to ensure draw or win')
                            end
                            bAllInAttack = true
                            bIncludeACUInAttack = true
                            --Attack if we have gun and enemy ACU doesnt, and we have at least as much health (or more health if are on enemy side of map)
                            --DoesACUHaveGun(aiBrain, bROFAndRange, oAltACU)
                        elseif M27Conditions.DoesACUHaveGun(aiBrain, false, oEnemyACUToConsiderAttacking) == false and M27Conditions.DoesACUHaveGun(aiBrain, false, oACU) == true and oEnemyACUToConsiderAttacking:GetHealth() + iExtraHealthCheck < oACU:GetHealth() then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': We have gun, enemy ACU doesnt, and we haver more health')
                            end
                            bAllInAttack = true
                            bIncludeACUInAttack = true
                            bCheckThreatBeforeCommitting = true
                        end
                        if bIncludeACUInAttack then
                            if GetGameTimeSeconds() - (oACU[refiACULastTakenUnseenOrTorpedoDamage] or -100) <= 20 and M27UnitInfo.IsUnitValid(oACU[refoUnitDealingUnseenDamage]) and EntityCategoryContains(categories.STRUCTURE + categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL, oACU[refoUnitDealingUnseenDamage].UnitId) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': ACU taking damage from T2 PD')
                                end
                                bIncludeACUInAttack = false
                            else
                                --Is there complete T2 PD nearby?
                                local tNearbyPD
                                if oACU.PlatoonHandle and oACU.PlatoonHandle[M27PlatoonUtilities.refiEnemyStructuresInRange] > 0 then
                                    tNearbyPD = EntityCategoryFilterDown(M27UnitInfo.refCategoryT2PlusPD, oACU.PlatoonHandle[M27PlatoonUtilities.reftEnemyStructuresInRange])
                                    if M27Utilities.IsTableEmpty(tNearbyPD) == false then
                                        for iPD, oPD in tNearbyPD do
                                            if oPD:GetFractionComplete() >= 0.9 and M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), oPD:GetPosition()) <= 56 then
                                                bIncludeACUInAttack = false
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': bAllInAttack after considering our ACU vs their ACU=' .. tostring(bAllInAttack))
                    end

                    if bAllInAttack == false and aiBrain[refbEnemyACUNearOurs] and iLastDistanceToACU <= (iACURange + 15) then
                        --Do we need to request emergency help?
                        local iHealthModForGun = 0
                        local iHealthPercentModForGun = 0
                        if M27Conditions.DoesACUHaveGun(aiBrain, false, oEnemyACUToConsiderAttacking) then
                            if not (M27Conditions.DoesACUHaveGun(aiBrain, false, oACU)) then
                                iHealthModForGun = -6000
                                iHealthPercentModForGun = 0.2
                            end
                        else
                            if M27Conditions.DoesACUHaveGun(aiBrain, false, oACU) then
                                iHealthModForGun = math.min(2000, oACU:GetHealth() * 0.25)
                                iHealthPercentModForGun = -0.1
                            end
                        end

                        if oEnemyACUToConsiderAttacking:GetHealth() > (oACU:GetHealth() + iHealthModForGun) and oEnemyACUToConsiderAttacking:GetHealth() > 2500 and M27UnitInfo.GetUnitHealthPercent(oACU) < (0.75 + iHealthPercentModForGun) then
                            bWantEscort = true
                            bEmergencyRequisition = true

                            if not (aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance) and not (aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill) then
                                if M27Conditions.CanWeStopProtectingACU(aiBrain, oACU) then
                                    bEmergencyRequisition = false
                                    if aiBrain[refiAIBrainCurrentStrategy] == refStrategyProtectACU then
                                        aiBrain[refiAIBrainCurrentStrategy] = aiBrain[refiDefaultStrategy]
                                    end
                                else
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Can stop protecting ACU is false and we want an escort with emergency requisition so will make sure strategy is to protect ACU')
                                    end
                                    aiBrain[refiAIBrainCurrentStrategy] = refStrategyProtectACU
                                end
                            end
                        end
                    end
                end
                if bAllInAttack == false and M27UnitInfo.IsUnitValid(oEnemyACUToConsiderAttacking) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Will consider if want all out attack even if our ACU isnt in much stronger position')
                    end
                    if M27UnitInfo.GetUnitHealthPercent(oEnemyACUToConsiderAttacking) < (0.1 + iHealthThresholdAdjIfAlreadyAllIn) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Enemy ACU is almost dead')
                        end
                        bAllInAttack = true
                    elseif M27UnitInfo.GetUnitHealthPercent(oEnemyACUToConsiderAttacking) < (0.75 + iHealthThresholdAdjIfAlreadyAllIn) then
                        --Do we have more threat near the ACU than the ACU has?
                        tAlliedUnitsNearEnemy = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, oEnemyACUToConsiderAttacking:GetPosition(), iNearbyThreatSearchRange, 'Ally')

                        if M27Utilities.IsTableEmpty(tAlliedUnitsNearEnemy) == false then
                            tEnemyUnitsNearEnemy = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, oEnemyACUToConsiderAttacking:GetPosition(), iNearbyThreatSearchRange, 'Enemy')
                            iThreatFactor = 2.5
                            if M27UnitInfo.GetUnitHealthPercent(oEnemyACUToConsiderAttacking) < (0.4 + iHealthThresholdAdjIfAlreadyAllIn) then
                                iThreatFactor = 1.25
                            end
                            if aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill then
                                iThreatFactor = 1
                            end
                            iAlliedThreat = M27Logic.GetCombatThreatRating(aiBrain, tAlliedUnitsNearEnemy, false, nil, nil, false, false)
                            iEnemyThreat = M27Logic.GetCombatThreatRating(aiBrain, tEnemyUnitsNearEnemy, false, nil, nil, false, false)
                            if iAlliedThreat > (iEnemyThreat * iThreatFactor) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': We have much more threat than the enemy ACU')
                                end
                                bAllInAttack = true
                            end
                        end
                        if not(bAllInAttack) then
                            --Is ACU low enough health that we might kill it with bombers alone?
                            if oEnemyACUToConsiderAttacking:GetHealth() <= 6000 and aiBrain[M27AirOverseer.refbHaveAirControl] then
                                --If enemy ACU not shielded, and doesnt have AA nearby, then consider switching just to kill it with bombers, if we have close to enough strike damage already
                                if not (M27Logic.IsTargetUnderShield(aiBrain, oEnemyACUToConsiderAttacking, 0, false, false, true)) then
                                    local iBomberStrikeDamage = 0
                                    local iCurAOE, iCurStrike
                                    local tOurBombers = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryBomber, false, true)
                                    if M27Utilities.IsTableEmpty(tOurBombers) == false then
                                        for iUnit, oUnit in tOurBombers do
                                            iCurAOE, iCurStrike = M27UnitInfo.GetBomberAOEAndStrikeDamage(oUnit)
                                            iBomberStrikeDamage = iBomberStrikeDamage + iCurStrike
                                        end
                                    end
                                    local iHealthPercentWanted = 0.5
                                    if aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill then iHealthPercentWanted = 0.4 end
                                    if bDebugMessages == true then LOG(sFunctionRef..': Considering if we have enough strike damage to just kill the enemy ACU with air. iBomberStrikeDamage='..iBomberStrikeDamage..'; iHealthPercentWanted='..iHealthPercentWanted..'; Enemy ACU health='..aiBrain[refoLastNearestACU]:GetHealth()) end
                                    if iBomberStrikeDamage >= oEnemyACUToConsiderAttacking:GetHealth() * iHealthPercentWanted then
                                        bIncludeACUInAttack = false
                                        bCheckThreatBeforeCommitting = false
                                        bAllInAttack = true
                                        bACUAirSnipe = true
                                        if bDebugMessages == true then LOG(sFunctionRef..': Will laucnh all out attack as we think we might be able to kill their ACU with air') end
                                    end
                                end
                            end

                        end
                    end

                    if bAllInAttack and not (oACU:IsUnitState('Upgrading')) and M27UnitInfo.GetUnitHealthPercent(oACU) > 0.5 then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Include ACU in all out attack as it has more than 50% health')
                        end
                        if not(bACUAirSnipe) then
                            bIncludeACUInAttack = true
                        end
                    end
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': bAllInAttack=' .. tostring(bAllInAttack))
                    end
                end

                --Override decision if enemy ACU has significantly more threat than us
                if bAllInAttack and not(bACUAirSnipe) then
                    if aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill then
                        iThreatFactor = 0.9
                    end
                    if not (iAlliedThreat) then
                        tAlliedUnitsNearEnemy = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, oEnemyACUToConsiderAttacking:GetPosition(), iNearbyThreatSearchRange, 'Ally')
                        iAlliedThreat = M27Logic.GetCombatThreatRating(aiBrain, tAlliedUnitsNearEnemy, false, nil, nil, false, false)
                    end

                    if not (iEnemyThreat) then
                        tEnemyUnitsNearEnemy = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, oEnemyACUToConsiderAttacking:GetPosition(), iNearbyThreatSearchRange, 'Enemy')
                        iEnemyThreat = M27Logic.GetCombatThreatRating(aiBrain, tEnemyUnitsNearEnemy, false, nil, nil, false, false)
                    end
                    if iAlliedThreat < (iEnemyThreat * iThreatFactor) then
                        --Do we want to abort, or press ahead even if it means a likely draw?
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': We are outnumbered, will decide whether to abort the attack. Enemy ACU health=' .. oEnemyACUToConsiderAttacking:GetHealth() .. '; Distance between ACUs=' .. iLastDistanceToACU .. '; iACURange=' .. iACURange)
                        end
                        if oEnemyACUToConsiderAttacking:GetHealth() <= 2500 and iLastDistanceToACU < (iACURange - 1) then
                            --Our ACU is in range of theirs, and theirs will die to ACU explosion; if are far ahead on eco then want to play safe though
                            if oEnemyACUToConsiderAttacking:GetHealth() <= 300 then
                                --Their ACU is about to die so press attack and just hope we live
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': THeir ACU is about to die so will proceed with attack')
                                end
                            else
                                --Do we have more than our share of mexes?

                                local iOurTeamsShareOfMexesOnMap = aiBrain[refiAllMexesInBasePathingGroup] / aiBrain[refiTeamsWithSameAmphibiousPathingGroup]
                                local bAheadOnEco = false
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': iOurTeamsShareOfMexesOnMap=' .. iOurTeamsShareOfMexesOnMap .. '; aiBrain[refiAllMexesInBasePathingGroup] =' .. aiBrain[refiAllMexesInBasePathingGroup] .. '; aiBrain[refiUnclaimedMexesInBasePathingGroup]=' .. aiBrain[refiUnclaimedMexesInBasePathingGroup]..'; iTeamsWithSamePathingGroup='..aiBrain[refiTeamsWithSameAmphibiousPathingGroup]..'; Total team count='..M27Team.iTotalTeamCount)
                                end
                                --refiUnclaimedMexesInBasePathingGroup doesn't include mexes claimed by teammates, i.e. below looks at things overall on a team basis rather than us individually
                                if (aiBrain[refiAllMexesInBasePathingGroup] - aiBrain[refiUnclaimedMexesInBasePathingGroup]) > iOurTeamsShareOfMexesOnMap then
                                    --Are ahead on eco so play safe
                                    bAheadOnEco = true
                                else

                                    local tEnemyMexes = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMex + M27UnitInfo.refCategoryMassStorage, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27AirOverseer.refiMaxScoutRadius], 'Enemy')
                                    local iEnemyT1Mex = 0
                                    local iEnemyT2Mex = 0
                                    local iEnemyT3Mex = 0
                                    local iEnemyStorage = 0
                                    if M27Utilities.IsTableEmpty(tEnemyMexes) == false then
                                        local tEnemyT1Mex = EntityCategoryFilterDown(categories.TECH1 - M27UnitInfo.refCategoryMassStorage, tEnemyMexes)
                                        if M27Utilities.IsTableEmpty(tEnemyT1Mex) == false then
                                            iEnemyT1Mex = table.getn(tEnemyT1Mex)
                                        end
                                        local tEnemyT2Mex = EntityCategoryFilterDown(categories.TECH2, tEnemyMexes)
                                        if M27Utilities.IsTableEmpty(tEnemyT2Mex) == false then
                                            iEnemyT2Mex = table.getn(tEnemyT2Mex)
                                        end

                                        local tEnemyT3Mex = EntityCategoryFilterDown(categories.TECH3, tEnemyMexes)
                                        if M27Utilities.IsTableEmpty(tEnemyT3Mex) == false then
                                            iEnemyT3Mex = table.getn(tEnemyT3Mex)
                                        end
                                        local tEnemyStorage = EntityCategoryFilterDown(M27UnitInfo.refCategoryMassStorage, tEnemyMexes)
                                        if M27Utilities.IsTableEmpty(tEnemyStorage) == false then
                                            iEnemyStorage = table.getn(tEnemyStorage)
                                        end
                                    end

                                    local iEnemyMass = (1 + iEnemyT1Mex * 2 + iEnemyT2Mex * 6 + iEnemyT3Mex * 18 + iEnemyStorage) * 0.1
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': iEnemyMass=' .. iEnemyMass .. '; our gross mass income=' .. aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] .. '; will inflate enemy mass income since we may lack good intel')
                                    end
                                    if iEnemyMass * 1.3 + 0.5 < aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] then
                                        bAheadOnEco = true
                                    end
                                end

                                if bAheadOnEco then
                                    --We are probably ahead on eco, so only attack if enemy ACU within our ACU range and we have a big advantage

                                    if M27Conditions.DoesACUHaveBigGun(aiBrain, oACU) or M27UnitInfo.IsUnitValid(oEnemyACUToConsiderAttacking) and iLastDistanceToACU <= iACURange and oACU:GetHealth() - 4000 >= oEnemyACUToConsiderAttacking:GetHealth() and (oEnemyACUToConsiderAttacking:GetHealth() <= 500 or M27UnitInfo.GetUnitMaxGroundRange(oEnemyACUToConsiderAttacking) < iACURange or (oEnemyACUToConsiderAttacking:GetHealth() <= 2000 and oACU:GetHealth() >= 9500)) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': We are ahead on eco but still shoudl be able to kill the ACU quickly so wont abort the all in attack with our ACU') end
                                    else
                                        bAllInAttack = false
                                        bIncludeACUInAttack = false
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': We are ahead on eco so will abort the all in attack and play safe')
                                        end
                                    end
                                end
                            end
                        else
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': iAlliedThreat=' .. iAlliedThreat .. '; iEnemyThreat=' .. iEnemyThreat .. '; iThreatFactor=' .. iThreatFactor .. '; Enemy ACU health >=2.5k at ' .. oEnemyACUToConsiderAttacking:GetHealth() .. ', so therefore aborting All in attack')
                            end
                            bAllInAttack = false
                            bIncludeACUInAttack = false
                        end
                    end
                end
                --Override - dont include ACU in attack if we are massively ahead on eco or is significant air threat
                if bIncludeACUInAttack then
                    if (iLastDistanceToACU > iACURange or M27UnitInfo.GetUnitHealthPercent(oACU) <= 0.75) and iOurACUDistToOurBase > aiBrain[refiDistanceToNearestEnemyBase] * 0.6 and aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 16 and not (M27Conditions.DoesACUHaveBigGun(aiBrain, oACU)) then
                        bIncludeACUInAttack = false
                        --Dont include ACU in attack if there are nearby enemy T1 PD and not about to kill their ACU
                    elseif oACU.PlatoonHandle[M27PlatoonUtilities.refiEnemyStructuresInRange] > 0 and oEnemyACUToConsiderAttacking:GetHealth() >= 600 then
                        local tNearbyT1PD = EntityCategoryFilterDown(M27UnitInfo.refCategoryPD * categories.TECH1, oACU.PlatoonHandle[M27PlatoonUtilities.reftEnemyStructuresInRange])
                        if M27Utilities.IsTableEmpty(tNearbyT1PD) == false then
                            local iNearestPD = 10000
                            local iCurDist
                            for iUnit, oUnit in tNearbyT1PD do
                                if M27UnitInfo.IsUnitValid(oUnit) and oUnit:GetFractionComplete() >= 1 then
                                    iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oACU:GetPosition())
                                    if iCurDist < iNearestPD then iNearestPD = iCurDist end
                                end
                            end
                            --T1 PD range is 26 - this hopefully gives enough time to move out of their range most of the time
                            if iCurDist <= 28 then
                                bIncludeACUInAttack = false
                            end
                        end
                    end
                    if bIncludeACUInAttack then
                        --Does the enemy have significant air threat nearby?
                        if bDebugMessages == true then LOG(sFunctionRef..': Brain='..aiBrain.Nickname..'; Checking enemy air threat to see if we want to leave ACU behind. refbFarBehindOnAir='..tostring(aiBrain[M27AirOverseer.refbFarBehindOnAir])..'; refiEnemyAirToGroundThreat='..aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat]..'; ACU MAA='..(oACU[refoUnitsMAAHelper][M27PlatoonUtilities.refiPlatoonMassValue] or 'nil')..'; airaa needed='..aiBrain[M27AirOverseer.refiAirAANeeded]..'; iLastDistanceToACU='..iLastDistanceToACU..'; Enemy ACU to consider attacking health='..oEnemyACUToConsiderAttacking:GetHealth()..'; Enemy highest tech='..aiBrain[refiEnemyHighestTechLevel]) end
                        if aiBrain[M27AirOverseer.refbFarBehindOnAir] or (not(aiBrain[M27AirOverseer.refbHaveAirControl]) and aiBrain[M27AirOverseer.refiAirAANeeded] > 2) then
                            --If we die we are unlikely to kill the enemy ACU:
                            if bDebugMessages == true then LOG(sFunctionRef..': iLastDistanceToACU='..iLastDistanceToACU..'; iACURange='..iACURange..'; oEnemyACUToConsiderAttacking:GetHealth()='..oEnemyACUToConsiderAttacking:GetHealth()) end
                            if iLastDistanceToACU > iACURange or oEnemyACUToConsiderAttacking:GetHealth() >= 2000 then
                                --We lack enough AirAA, does the enough have a large enough air to ground threat and T2+ tech (wont check for air fac in case we havent scouted it)?
                                if bDebugMessages == true then LOG(sFunctionRef..': Enemy air to ground threat='..aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat]..'; aiBrain[refiEnemyHighestTechLevel]='..aiBrain[refiEnemyHighestTechLevel]..'; Does enemy have >=800 threat='..tostring(aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 800)..'; Does enemy have >=1500 threat='..tostring(aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 1500)..'; Does enemy have >=tech2='..tostring(aiBrain[refiEnemyHighestTechLevel] >= 2)..'; Does enemy meet the below condition='..tostring(aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 800 and (aiBrain[refiEnemyHighestTechLevel] >= 2 or aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 1500))) end
                                if aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 800 and (aiBrain[refiEnemyHighestTechLevel] >= 2 or aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 1500) then
                                    --Do we likely lack sufficient MAA?
                                    local tNearbyMAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMAA, oACU:GetPosition(), 50, 'Ally')
                                    local iNearbyMAAThreat = 0
                                    if M27Utilities.IsTableEmpty(tNearbyMAA) == false then iNearbyMAAThreat = (M27Logic.GetAirThreatLevel(aiBrain, tNearbyMAA, false, false, true, false, false) or 0) end
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef..': About to see if we have sufficient MAA; mass value of MAA assigned to ACU='..(oACU[refoUnitsMAAHelper][M27PlatoonUtilities.refiPlatoonMassValue] or 0))
                                        LOG(sFunctionRef..': is tNearbyMAA empty='..tostring(M27Utilities.IsTableEmpty(tNearbyMAA)))
                                        LOG(sFunctionRef..': Threat of tNearbyMAA='..iNearbyMAAThreat)
                                    end

                                    if iNearbyMAAThreat == 0 or (oACU[refoUnitsMAAHelper][M27PlatoonUtilities.refiPlatoonMassValue] or 0) <= math.max(250, aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] / 8) or iNearbyMAAThreat <= math.max(150, (oACU[refoUnitsMAAHelper][M27PlatoonUtilities.refiPlatoonMassValue] or 0) * 0.5, aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] / 8) then
                                        --Is our ACU relatively far from our base?
                                        if bDebugMessages == true then LOG(sFunctionRef..': ACU dist from base='..iOurACUDistToOurBase..'; 75% of dist to enemy base='..iOurACUDistToEnemyBase * 0.75) end
                                        if iOurACUDistToOurBase > math.max(125, iOurACUDistToEnemyBase * 0.75) then
                                            --Do we lack radar coverage and enemy has significant air to ground threat, or alternatively we have radar coverage but enemy has air to ground nearby?
                                            if bDebugMessages == true then LOG(sFunctionRef..': Intel coverage of position='..M27Logic.GetIntelCoverageOfPosition(aiBrain, oACU:GetPosition(), nil, true)) end
                                            local tNearbyEnemyAirToGround = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirNonScout - M27UnitInfo.refCategoryAirAA, oACU:GetPosition(), 100, 'Enemy')
                                            local iNearbyAirToGroundThreat = 0
                                            if M27Utilities.IsTableEmpty(tNearbyEnemyAirToGround) == false then iNearbyAirToGroundThreat = (M27Logic.GetAirThreatLevel(aiBrain, tNearbyEnemyAirToGround, false, false, false, true, true) or 0) end
                                            if iNearbyAirToGroundThreat >= 400 or (aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 1500 and not(M27Logic.GetIntelCoverageOfPosition(aiBrain, oACU:GetPosition(), 100, true))) or
                                                    iNearbyAirToGroundThreat >= 250 then
                                                bIncludeACUInAttack = false
                                                if bDebugMessages == true then LOG(sFunctionRef..': Enemy air is too dangerous, wont continue attack with ACU') end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end


                end



                --==========ACU Run away and cancel upgrade logic



                --Is the ACU upgrading?
                if oACU:IsUnitState('Upgrading') then
                    local bCancelUpgradeAndRun = false
                    local bNeedProtecting = false
                    if M27Conditions.ACUShouldRunFromBigThreat(aiBrain) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': ACU should run from a big threat so will cancel upgrade')
                        end
                        bCancelUpgradeAndRun = true
                    else
                        if not (oACU[reftACURecentUpgradeProgress]) then
                            oACU[reftACURecentUpgradeProgress] = {}
                        end
                        oACU[reftACURecentUpgradeProgress][iCurTime] = oACU:GetWorkProgress()
                        if oACU[reftACURecentUpgradeProgress][iCurTime - 10] and not(oACU[reftACURecentUpgradeProgress][iCurTime - 1]) then
                            for iTimeAdjust = -1, -9, -1 do
                                if oACU[reftACURecentUpgradeProgress][iCurTime + iTimeAdjust] then
                                    break
                                else
                                    oACU[reftACURecentUpgradeProgress][iCurTime + iTimeAdjust] = oACU[reftACURecentUpgradeProgress][iCurTime]
                                end
                            end
                        end

                        --Did we start the upgrade <10s ago but have lost a significant amount of health?
                        if oACU[reftACURecentUpgradeProgress][iCurTime - 10] == nil and (oACU[reftACURecentHealth][iCurTime - 10] or oACU[reftACURecentHealth][iCurTime - 11]) - (oACU[reftACURecentHealth][iCurTime] or oACU[reftACURecentHealth][iCurTime-1] or oACU[reftACURecentHealth][iCurTime-2] or oACU[reftACURecentHealth][iCurTime-3]) > 1000 and oACU[reftACURecentUpgradeProgress][iCurTime] < 0.7 then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': ACU has lost a lot of health recently, oACU[reftACURecentHealth][iCurTime - 10]=' .. oACU[reftACURecentHealth][iCurTime - 10] .. '; oACU[reftACURecentHealth][iCurTime]=' .. oACU[reftACURecentHealth][iCurTime] .. '; oACU[reftACURecentUpgradeProgress][iCurTime]=' .. oACU[reftACURecentUpgradeProgress][iCurTime])
                            end
                            bCancelUpgradeAndRun = true
                            --Is the reason for the health loss because we removed T2 upgrade (e.g. sera)? Note - if changing the time frame from 10s above, need to change the delay variable reset on the upgrade in platoonutilities (currently 11s)
                            if oACU[M27UnitInfo.refbRecentlyRemovedHealthUpgrade] and (M27UnitInfo.GetUnitHealthPercent(oACU) >= 0.99 or oACU[reftACURecentHealth][iCurTime - 10] - oACU[reftACURecentHealth][iCurTime] < 3000) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': We recently removed an upgrade that increased our health and have good health or health loss less than 3k')
                                end
                                bCancelUpgradeAndRun = false
                            end

                        elseif oACU[reftACURecentUpgradeProgress][iCurTime] < 0.9 then

                            --Based on how our health has changed over the last 10s vs the upgrade progress, are we likely to die?
                            local iHealthLossPerSec = ((oACU[reftACURecentHealth][iCurTime - 10] or oACU[reftACURecentHealth][iCurTime - 11]) - (oACU[reftACURecentHealth][iCurTime] or oACU[reftACURecentHealth][iCurTime-1] or oACU[reftACURecentHealth][iCurTime-2])) / 10
                            if iHealthLossPerSec > 50 then
                                --If changing these values, consider updating the SafeToGetACUUpgrade thresholds
                                local iTimeToComplete = (1 - (oACU[reftACURecentUpgradeProgress][iCurTime] or 0.01)) / (math.max(((oACU[reftACURecentUpgradeProgress][iCurTime] or 0.01) - (oACU[reftACURecentUpgradeProgress][iCurTime - 10] or 0)), 0.01) / 10)
                                local iHealthReduction = 0
                                if not (M27Conditions.DoesACUHaveGun(aiBrain, true, oACU)) then
                                    iHealthReduction = 1000
                                end --If we are getting gun upgrade then we need some health post-upgrade to have any chance of surviving
                                if aiBrain[refbEnemyACUNearOurs] then
                                    iHealthReduction = iHealthReduction + 1000
                                end
                                local iTurtleFurtherAdjust = 1
                                if aiBrain[refiDefaultStrategy] == refStrategyTurtle and M27UnitInfo.GetNumberOfUpgradesObtained(oACU) == 0 then
                                    iHealthReduction = iHealthReduction - 2000
                                    iTurtleFurtherAdjust = 0.75 --This just acts as a true/false flag currently based on whether it is less than 1
                                    if GetGameTimeSeconds() - (oACU[M27UnitInfo.refiTimeLastFired] or 0) <= 8 and iOurACUDistToOurBase <= 225 then
                                        iHealthReduction = iHealthReduction - 1500
                                    end
                                    if bDebugMessages == true then LOG(sFunctionRef..': Are turtling and have no upgrade so really want to complete, iHealthReduction='..(iHealthReduction or 'nil')..'; iTurtleFurtherAdjust='..(iTurtleFurtherAdjust or 'nil')..'; Time since our ACU last fired='..GetGameTimeSeconds() - (oACU[M27UnitInfo.refiTimeLastFired] or 0)..'; Dist to our base='..iOurACUDistToOurBase) end
                                end --If are turtling then really important we get the upgrade, will also get a health boost from T2
                                if iOurACUDistToOurBase <= 125 then
                                    iHealthReduction = math.max(math.min(iHealthReduction, 0), iHealthReduction * 0.5)
                                end
                                if iTimeToComplete * iHealthLossPerSec > math.min(oACU[reftACURecentHealth][iCurTime] * 0.9 - iHealthReduction, oACU:GetMaxHealth() * 0.7 - iHealthReduction) then
                                    --ACU will be really low health or die if it keeps upgrading
                                    bCancelUpgradeAndRun = true
                                    bNeedProtecting = true
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': We will be really low health if we finish the upgrade; consider if we are near base/if expect we might be able to reduce the damage taken where the upgrade is at least 50% done. % done=' .. oACU[reftACURecentUpgradeProgress][iCurTime] .. '; Dist to base=' .. iOurACUDistToOurBase .. '; oACU[reftACURecentHealth][iCurTime] * 1.1=' .. oACU[reftACURecentHealth][iCurTime] * 1.1 .. '; iTimeToComplete * iHealthLossPerSec=' .. iTimeToComplete * iHealthLossPerSec .. '; iHealthReduction=' .. iHealthReduction .. '; ACU Max health=' .. oACU:GetMaxHealth())
                                    end
                                    if oACU[reftACURecentUpgradeProgress][iCurTime] > 0.225 or iTurtleFurtherAdjust < 1 or iOurACUDistToOurBase <= math.min(200, math.max(125, aiBrain[refiDistanceToNearestEnemyBase] * 0.333)) then
                                        if iTimeToComplete * iHealthLossPerSec < oACU[reftACURecentHealth][iCurTime] * 1.1 - iHealthReduction then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Will try and finish upgrade and hope units can save us')
                                            end
                                            bCancelUpgradeAndRun = false
                                        else
                                            --are we taking damage from t1 bombers but have MAA or AirAA nearby?
                                            local tNearbyEnemyBombers = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryBomber * categories.TECH1, oACU:GetPosition(), 60, 'Enemy')
                                            local iNearbyEnemyBombers = 0
                                            if M27Utilities.IsTableEmpty(tNearbyEnemyBombers) == false then
                                                iNearbyEnemyBombers = table.getn(tNearbyEnemyBombers)
                                            end
                                            if iNearbyEnemyBombers <= 4 and (EntityCategoryContains(M27UnitInfo.refCategoryBomber, oACU[refoLastUnitDealingDamage].UnitId) or iNearbyEnemyBombers >= 1 and M27Utilities.GetDistanceBetweenPositions(aiBrain[reftLastNearestACU], oACU:GetPosition()) >= 60) and oACU[refoUnitsMAAHelper] and M27Utilities.IsTableEmpty(oACU[refoUnitsMAAHelper][M27PlatoonUtilities.reftCurrentUnits]) == false and M27UnitInfo.GetUnitHealthPercent(oACU) > (1 - oACU:GetWorkProgress()) then
                                                bCancelUpgradeAndRun = false
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Health % is better tahn % to complete, and 4 or fewer t1 bombers and we have MAA assigned to us, so hopefully will kill the bombers soon')
                                                end
                                            end
                                        end
                                    end
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': iHealthLossPerSec=' .. (iHealthLossPerSec or 'nil') .. '; iTimeToComplete=' .. (iTimeToComplete or 'nil') .. '; iTimeToComplete * iHealthLossPerSec=' .. (iTimeToComplete or 0) * (iHealthLossPerSec or 0) .. '; oACU[reftACURecentHealth][iCurTime - 10]=' .. (oACU[reftACURecentHealth][iCurTime - 10] or 'nil') .. '; oACU[reftACURecentHealth][iCurTime]=' .. (oACU[reftACURecentHealth][iCurTime] or 'nil') .. '; oACU[reftACURecentUpgradeProgress][iCurTime]=' .. (oACU[reftACURecentUpgradeProgress][iCurTime] or 'nil') .. '; bCancelUpgradeAndRun=' .. tostring(bCancelUpgradeAndRun) .. ';  aiBrain[refiDistanceToNearestEnemyBase]=' .. (aiBrain[refiDistanceToNearestEnemyBase] or 'nil'))
                                end
                            elseif bDebugMessages == true then
                                LOG(sFunctionRef .. ': Health loss less than 50 so wont cancel for this. iHealthLossPerSec=' .. iHealthLossPerSec)
                            end

                        end
                        if bCancelUpgradeAndRun == false then
                            --if >=3 TML nearby, then cancel upgrade
                            bCancelUpgradeAndRun = M27Conditions.DoWeWantToAbortUpgradeForTML(aiBrain, oACU)
                        else
                            --Want to cancel but not because of TML, so need to protect ACU
                            if not (aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance) and not (aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill) then
                                if M27Conditions.CanWeStopProtectingACU(aiBrain, oACU) then
                                    bEmergencyRequisition = false
                                    if aiBrain[refiAIBrainCurrentStrategy] == refStrategyProtectACU then
                                        aiBrain[refiAIBrainCurrentStrategy] = aiBrain[refiDefaultStrategy]
                                    end
                                else
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Want to cancel upgrade but not because of TML; will set strategy to protect ACU')
                                    end
                                    aiBrain[refiAIBrainCurrentStrategy] = refStrategyProtectACU
                                end
                            end
                        end
                    end

                    if bCancelUpgradeAndRun then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Want to cancel upgrade and run')
                        end
                        --Only actually cancel if we're not close to our base as if we're close to base then will probably die if cancel as well
                        if iOurACUDistToOurBase > iDistanceFromBaseWhenVeryLowHealthToBeSafe then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Clearing commands for ACU')
                            end
                            M27Utilities.IssueTrackedClearCommands({ M27Utilities.GetACU(aiBrain) })
                            IssueMove({ oACU }, M27Logic.GetNearestRallyPoint(aiBrain, tACUPos, oACU))
                        end
                    else
                        --We are upgrading, but dont want to cancel - still switch to protect ACU mode if enemy ACU is near since it can survive long enough once the upgrade is complete to kill us if we are low on health
                        if aiBrain[refbEnemyACUNearOurs] and not (M27UnitInfo.IsUnitUnderwater(oACU)) then
                            bNeedProtecting = true
                        end
                        if bNeedProtecting then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Enemy ACU is near ours and we arent underwater, or we have taken lots of damage and are likely to die, so will switch strategy to protect ACU while we are upgrading')
                            end
                            aiBrain[refiAIBrainCurrentStrategy] = refStrategyProtectACU
                        end
                    end
                else
                    --ACU not upgrading; check its owrk progress is 0 or 100 and if so then clear table
                    if oACU[reftACURecentUpgradeProgress] then
                        if oACU:GetWorkProgress() == 0 or oACU:GetWorkProgress() == 1 then
                            oACU[reftACURecentUpgradeProgress] = nil
                        end
                    end

                end
            end

            --ACU run logic regardless of whether have an ACU or have replaced it with an engineer/structure


            local iHealthPercentage = M27UnitInfo.GetUnitHealthPercent(oACU)
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
                    if oACU.UnitBeingBuilt then LOG('UnitBeingBuilt='..oACU.UnitBeingBuilt.UnitId..'; FractionComplete='..oACU.UnitBeingBuilt:GetFractionComplete())
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
                --Having escort - further tests
                if not(bWantEscort) then
                    if iOurACUDistToOurBase >= math.max(125, aiBrain[refiDistanceToNearestEnemyBase] * 0.35) and not(aiBrain[refiDefaultStrategy] == refStrategyTurtle) then
                        if not(M27Conditions.DoesACUHaveBigGun(aiBrain, oACU) or oACU:HasEnhancement('CloakingGenerator')) then
                            if aiBrain[refiTotalEnemyShortRangeThreat] >= 2700 or (aiBrain[refiTotalEnemyShortRangeThreat] >= 1800 and not(M27Conditions.DoesACUHaveGun(aiBrain, false, oACU))) then
                                bWantEscort = true
                                if bDebugMessages == true then LOG(sFunctionRef..': ACU is away from our base so want to give it an escort') end
                            end
                        end
                    end
                end

                oACUPlatoon[M27PlatoonUtilities.refbShouldHaveEscort] = bWantEscort

                --If we dont want an escort and we last wanted an escort 15+ seconds ago, then disband the escort platoon
                if bWantEscort then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': ACU wants an escort')
                    end
                    oACUPlatoon[M27PlatoonUtilities.refiLastTimeWantedEscort] = math.floor(GetGameTimeSeconds())
                else
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': ACU doesnt want an escort any more, will check if it hasnt wanted one for a while now, and if it has an escorting platoon. oACUPlatoon[M27PlatoonUtilities.refiLastTimeWantedEscort]=' .. (oACUPlatoon[M27PlatoonUtilities.refiLastTimeWantedEscort] or 'nil'))
                        if oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon] then
                            LOG('Have an escorting platoon, number of units in platoon=' .. (oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon][M27PlatoonUtilities.refiCurrentUnits] or 'nil'))
                        else
                            LOG('Dont have an escorting platoon')
                        end
                    end

                    if oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon] and oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon][M27PlatoonUtilities.refiCurrentUnits] > 1 then
                        if GetGameTimeSeconds() - (oACUPlatoon[M27PlatoonUtilities.refiLastTimeWantedEscort] or 0) >= 15 then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Will tell escorting platoon to disband')
                            end
                            oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon][M27PlatoonUtilities.refiCurrentAction] = M27PlatoonUtilities.refActionDisband
                        end
                    end
                end
                if bEmergencyRequisition and not (bAllInAttack) then
                    --Is the ACU close to our base? If so then only do emergency response if very low health
                    if iOurACUDistToOurBase > iRangeForACUToBeNearBase or iHealthPercentage < iACUEmergencyHealthPercentThreshold then
                        if not (aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance) and not (aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill) then
                            --If ACU not taken damage in a while and no nearby enemy units, then dont adopt protectACU strategy
                            if M27Conditions.CanWeStopProtectingACU(aiBrain, oACU) then
                                if aiBrain[refiAIBrainCurrentStrategy] == refStrategyProtectACU then
                                    aiBrain[refiAIBrainCurrentStrategy] = aiBrain[refiDefaultStrategy]
                                end
                            else
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Are either away from base or below emergency response; have flagged we want emergency requisition so will set strategy to protect ACU')
                                end
                                aiBrain[refiAIBrainCurrentStrategy] = refStrategyProtectACU
                                --ask for help if we are far from base (if closer then assume teammates can already tell we need help
                                if iOurACUDistToOurBase >= 150 then M27Chat.SendMessage(aiBrain, 'Protect ACU', 'My ACU could use some help', 0, 300, true) end
                            end
                        end

                        --Get all nearby non-skirmisher combat units we own
                        local tNearbyCombat = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat - M27UnitInfo.refCategorySkirmisher, tACUPos, iRangeForEmergencyEscort, 'Ally')
                        if M27Utilities.IsTableEmpty(tNearbyCombat) == false then
                            --Check we have at least 1 unit that can be assigned
                            local bHaveAUnit = false
                            for iUnit, oUnit in tNearbyCombat do
                                if M27UnitInfo.IsUnitValid(oUnit) and oUnit:GetAIBrain() == aiBrain and not (M27Utilities.IsACU(oUnit)) then
                                    bHaveAUnit = true
                                    break
                                end
                            end

                            if bHaveAUnit == true then
                                local oEscortingPlatoon = oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon]
                                if not (oEscortingPlatoon) or not (aiBrain:PlatoonExists(oEscortingPlatoon)) then
                                    oEscortingPlatoon = M27PlatoonFormer.CreatePlatoon(aiBrain, 'M27EscortAI', nil)
                                    oEscortingPlatoon[M27PlatoonUtilities.refoPlatoonOrUnitToEscort] = oACUPlatoon
                                    oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon] = oEscortingPlatoon
                                end


                                --Filter to only units we control that arent already in this platoon
                                local tNearbyOwnedCombat = {}
                                local iNearbyOwnedCombatCount = 0
                                for iUnit, oUnit in tNearbyCombat do
                                    if M27UnitInfo.IsUnitValid(oUnit) and oUnit:GetAIBrain() == aiBrain and not (M27Utilities.IsACU(oUnit)) and not(EntityCategoryContains(categories.EXPERIMENTAL, oUnit.UnitId)) then
                                        if not (oUnit.PlatoonHandle) or not (oUnit.PlatoonHandle == oEscortingPlatoon) then
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
                if M27UnitInfo.GetUnitHealthPercent(oACU) >= 0.95 and oACU.PlatoonHandle[M27PlatoonUtilities.refbHavePreviouslyRun] and M27Conditions.DoesACUHaveUpgrade(aiBrain) then
                    if iACUMaxShield == 0 or iACUCurShield >= iACUMaxShield * 0.7 then
                        --Large threat near ACU?
                        local iNearbyThreat = 0
                        --GetCombatThreatRating(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, iMassValueOfBlipsOverride, iSoloBlipMassOverride, bIndirectFireThreatOnly, bJustGetMassValue)
                        if oACU.PlatoonHandle[M27PlatoonUtilities.refiEnemiesInRange] then
                            iNearbyThreat = iNearbyThreat + M27Logic.GetCombatThreatRating(aiBrain, oACU.PlatoonHandle[M27PlatoonUtilities.reftEnemiesInRange], true)
                        end
                        if oACU.PlatoonHandle[M27PlatoonUtilities.refiEnemyStructuresInRange] then
                            iNearbyThreat = iNearbyThreat + M27Logic.GetCombatThreatRating(aiBrain, oACU.PlatoonHandle[M27PlatoonUtilities.reftEnemyStructuresInRange], true)
                        end
                        if iNearbyThreat <= oACU.PlatoonHandle[M27PlatoonUtilities.refiPlatoonThreatValue] * 0.5 then
                            oACU.PlatoonHandle[M27PlatoonUtilities.refbHavePreviouslyRun] = false
                        end
                    end
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': oACUPlatoon[M27PlatoonUtilities.refbShouldHaveEscort]=' .. tostring(oACUPlatoon[M27PlatoonUtilities.refbShouldHaveEscort]))
                end
            end

            --Dont do all in attack if enemy ACU underwater and we dont have T2 air
            if bAllInAttack and aiBrain[refiOurHighestAirFactoryTech] == 1 and M27UnitInfo.IsUnitUnderwater(oEnemyACUToConsiderAttacking) then
                bAllInAttack = false
            end

            if bAllInAttack == true then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Are doing all in attack, will consider if want to suicide our ACU. bIncludeACUInAttack before upgrade override='..tostring(bIncludeACUInAttack)..'; ACU unit state='..M27Logic.GetUnitState(oACU))
                end
                if bIncludeACUInAttack and oACU:IsUnitState('Upgrading') and (oACU:GetWorkProgress() >= 0.5 or (not(M27Conditions.DoesACUHaveUpgrade(aiBrain, oACU)) and oACU:GetWorkProgress() >= 0.25)) then
                    bIncludeACUInAttack = false
                end
                if not(oEnemyACUToConsiderAttacking) then oEnemyACUToConsiderAttacking = aiBrain[refoLastNearestACU] end

                aiBrain[refoACUKillTarget] = oEnemyACUToConsiderAttacking
                aiBrain[reftACUKillTarget] = oEnemyACUToConsiderAttacking:GetPosition()

                aiBrain[refiAIBrainCurrentStrategy] = refStrategyACUKill
                aiBrain[refbStopACUKillStrategy] = false
                aiBrain[refbIncludeACUInAllOutAttack] = bIncludeACUInAttack

                if EntityCategoryContains(categories.COMMAND, aiBrain[refoACUKillTarget].UnitId) and ScenarioInfo.Options.Victory == "demoralization" then M27Chat.SendMessage(aiBrain, 'Kill ACU', 'Targeting '..aiBrain[refoACUKillTarget]:GetAIBrain().Nickname..' ACU', 0, 300, true) end
                --Consider Ctrl-K of ACU
                local bSuicide = false
                if oACU:GetHealth() <= 275 and M27UnitInfo.IsUnitValid(oEnemyACUToConsiderAttacking) then
                    local iEnemyACUHealth = oEnemyACUToConsiderAttacking:GetHealth()
                    if iEnemyACUHealth <= 2000 then
                        local iDistanceToEnemyACU = M27Utilities.GetDistanceBetweenPositions(tACUPos, oEnemyACUToConsiderAttacking:GetPosition())
                        if iDistanceToEnemyACU <= 30 then
                            bSuicide = true
                        elseif iDistanceToEnemyACU <= 40 and iEnemyACUHealth <= 500 then
                            bSuicide = true
                        end
                    end
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': bSuicide=' .. tostring(bSuicide) .. '; ACU Health=' .. oACU:GetHealth() .. '; LastACUHealth=' .. oEnemyACUToConsiderAttacking:GetHealth() .. '; distance between ACUs=' .. M27Utilities.GetDistanceBetweenPositions(tACUPos, oEnemyACUToConsiderAttacking:GetPosition()))
                end
                if bSuicide then
                    M27Chat.SendSuicideMessage(aiBrain)
                    oACU:Kill()
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Have just told our ACU to self destruct')
                    end
                end
            else
                aiBrain[refbIncludeACUInAllOutAttack] = false
                aiBrain[refbStopACUKillStrategy] = true
                aiBrain[refoACUKillTarget] = nil
                aiBrain[reftACUKillTarget] = nil
                if oACU.PlatoonHandle then
                    oACU.PlatoonHandle[M27PlatoonUtilities.reftPlatoonDFTargettingCategories] = M27UnitInfo.refWeaponPriorityNormal
                end
            end
        end
        --Flag if enemy has a guncom approaching our base:
        aiBrain[refbEnemyGuncomApproachingBase] = false
        if bDebugMessages == true then
            LOG(sFunctionRef..': About to check if have approaching guncom, M27UnitInfo.IsUnitValid(aiBrain[refoLastNearestACU])='..tostring(M27UnitInfo.IsUnitValid(aiBrain[refoLastNearestACU]))..'; aiBrain[refoLastNearestACU]='..(aiBrain[refoLastNearestACU].UnitId or 'nil')..(M27UnitInfo.GetUnitLifetimeCount(aiBrain[refoLastNearestACU]) or 'nil')..' aiBrain[refiLastNearestACUDistance]='..aiBrain[refiLastNearestACUDistance]..'; Actual dist='..M27Utilities.GetDistanceBetweenPositions(aiBrain[refoLastNearestACU]:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; Dist to enemy base from our base='..aiBrain[refiDistanceToNearestEnemyBase])
            if M27UnitInfo.IsUnitValid(aiBrain[refoLastNearestACU]) then LOG(sFunctionRef..': Nearest ACU is owned by '..aiBrain[refoLastNearestACU]:GetAIBrain().Nickname..' and is at position '..repru(aiBrain[refoLastNearestACU]:GetPosition())..'; our start pos='..repru(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) end
        end
        if M27UnitInfo.IsUnitValid(aiBrain[refoLastNearestACU]) and aiBrain[refiLastNearestACUDistance] <= 250 and M27Utilities.GetDistanceBetweenPositions(aiBrain[refoLastNearestACU]:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= math.max(140, math.min(250, aiBrain[refiDistanceToNearestEnemyBase] * 0.25), math.min(175, aiBrain[refiDistanceToNearestEnemyBase] * 0.4)) then
            --Is this a guncom or at risk of being a guncom?
            if bDebugMessages == true then LOG(sFunctionRef..': Does ACU '..aiBrain[refoLastNearestACU].UnitId..M27UnitInfo.GetUnitLifetimeCount(aiBrain[refoLastNearestACU])..' owned by '..aiBrain[refoLastNearestACU]:GetAIBrain().Nickname..' have a gun='..tostring(M27Conditions.DoesACUHaveGun(aiBrain[refoLastNearestACU]:GetAIBrain(), false, aiBrain[refoLastNearestACU]))..'; Enemy ACU unit state='..M27Logic.GetUnitState(aiBrain[refoLastNearestACU])) end
            if M27Conditions.DoesACUHaveGun(aiBrain[refoLastNearestACU]:GetAIBrain(), false, aiBrain[refoLastNearestACU]) or ((aiBrain[refoLastNearestACU]:IsUnitState('Upgrading') or aiBrain[refoLastNearestACU]:IsUnitState('Immobile')) and not(oACU:IsUnitState('Upgrading')) and not(M27Conditions.DoesACUHaveGun(aiBrain, false, oACU))) then
                aiBrain[refbEnemyGuncomApproachingBase] = true
                if bDebugMessages == true then LOG(sFunctionRef..': Time='..GetGameTimeSeconds()..'; Brain='..aiBrain.Nickname..'; Enemy has guncom approaching our base') end
            end
        end

    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function PlatoonNameUpdater(aiBrain, bUpdateCustomPlatoons)
    --Every second cycles through every platoon and updates its name to reflect its plan and platoon count
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'PlatoonNameUpdater'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': checking if want to update platoon names')
    end
    if M27Config.M27ShowUnitNames == true then
        if bUpdateCustomPlatoons == nil then
            bUpdateCustomPlatoons = true
        end
        local sPlatoonName, iPlatoonCount
        local oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
        local bPlatoonUsesM27Platoon = true
        local refsPrevPlatoonName = 'M27PrevPlatoonName'
        if M27Utilities.IsTableEmpty(aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]) == true then
            aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] = {}
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': About to cycle through each platoon')
        end
        for iPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
            if oPlatoon == oArmyPoolPlatoon then
                sPlatoonName = 'ArmyPool'
                bPlatoonUsesM27Platoon = false
            else
                if oPlatoon.GetPlan then
                    sPlatoonName = oPlatoon:GetPlan()
                    if oPlatoon[M27PlatoonUtilities.refiPlatoonCount] == nil then
                        bPlatoonUsesM27Platoon = false
                    end
                else
                    sPlatoonName = 'None'
                    bPlatoonUsesM27Platoon = false
                end
            end
            if sPlatoonName == nil then
                sPlatoonName = 'None'
            end
            if aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount][sPlatoonName] == nil then
                aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount][sPlatoonName] = 0
            end
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': sPlatoonName=' .. sPlatoonName .. '; bPlatoonUsesM27Platoon=' .. tostring(bPlatoonUsesM27Platoon))
            end
            if bPlatoonUsesM27Platoon == false then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': sPlatoonName=' .. sPlatoonName .. '; Platoon doesnt use M27Platoon, checking if have updated name before')
                end
                --Have we already updated this platoon before?
                local bHaveUpdatedBefore = false
                if oPlatoon[refsPrevPlatoonName] == nil then
                    oPlatoon[refsPrevPlatoonName] = sPlatoonName
                else
                    if oPlatoon[refsPrevPlatoonName] == sPlatoonName then
                        bHaveUpdatedBefore = true
                    end
                end

                --if bHaveUpdatedBefore == false then
                aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount][sPlatoonName] = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount][sPlatoonName] + 1
                oPlatoon[M27PlatoonUtilities.refiPlatoonCount] = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount][sPlatoonName]
                M27PlatoonUtilities.UpdatePlatoonName(oPlatoon, sPlatoonName .. oPlatoon[M27PlatoonUtilities.refiPlatoonCount])
                --end
            else
                if bUpdateCustomPlatoons == true then
                    local iPlatoonCount = oPlatoon[M27PlatoonUtilities.refiPlatoonCount]
                    if iPlatoonCount == nil then
                        iPlatoonCount = 0
                    end
                    local iPlatoonAction = oPlatoon[M27PlatoonUtilities.refiCurrentAction]
                    if iPlatoonAction == nil and not(oPlatoon[M27PlatoonTemplates.refbIdlePlatoon]) then
                        iPlatoonAction = 0
                        M27PlatoonUtilities.UpdatePlatoonName(oPlatoon, sPlatoonName .. iPlatoonCount .. ':Action=' .. iPlatoonAction)
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function WaitTicksSpecial(aiBrain, iTicksToWait)
    --calls the GetACU function since that will check if ACU is alive, and if not will delay to avoid a crash
    --Returns false if ACU no longer valid or all enemies are defeated
    local sFunctionRef = 'WaitTicksSpecial'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if aiBrain.M27IsDefeated or M27Logic.iTimeOfLastBrainAllDefeated > 10 then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return false
    else
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(iTicksToWait)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        local oACU = M27Utilities.GetACU(aiBrain)
        if oACU.M27IsDefeated or M27Logic.iTimeOfLastBrainAllDefeated > 10 then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return false
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return true
end

function EnemyThreatRangeUpdater(aiBrain)
    --Updates range to look for enemies based on if any T2 PD detected
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'EnemyThreatRangeUpdater'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if aiBrain[refbEnemyHasTech2PD] == false then
        local tEnemyTech2 = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH2, M27Utilities.GetACU(aiBrain):GetPosition(), 1000, 'Enemy')
        if M27Utilities.IsTableEmpty(tEnemyTech2) == false then
            aiBrain[refbEnemyHasTech2PD] = true
            aiBrain[refiSearchRangeForEnemyStructures] = 85 --Tech 2 is 50, ravager 70, so will go for 80 range; want to factor it into decisions on whether to attack if are near it
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Enemy T2 PD detected - increasing range to look for nearby enemies on platoons')
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function SetMaximumFactoryLevels(aiBrain)
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'SetMaximumFactoryLevels'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if aiBrain[M27AirOverseer.refiAirAAWanted] >= 100 then bDebugMessages = true end
    --if aiBrain:GetEconomyStoredRatio('MASS') >= 0.6 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 1 then bDebugMessages = true end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code')
    end

    --NoRush - set factories wanted to 1
    if M27MapInfo.bNoRushActive then
        aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = 1
        aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = 1
        aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1
    else

        local iAirFactoriesOwned = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory)
        local iLandFactoriesOwned = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryLandFactory)

        if aiBrain[refiAIBrainCurrentStrategy] == refStrategyLandRush then
            aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = 1
            aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.max(5, (aiBrain[refiMinLandFactoryBeforeOtherTypes] or 4), (1 + 0.5 * (aiBrain[refiAllMexesInBasePathingGroup] or 1)) / (aiBrain[refiTeamsWithSameAmphibiousPathingGroup] or 1), aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] / 4.5 )
            --Cap land factories at 16
            aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.min(16, aiBrain[reftiMaxFactoryByType][refFactoryTypeLand])
        else
            local iPrimaryFactoriesWanted
            local iPrimaryFactoryType = refFactoryTypeLand
            if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] == false then
                iPrimaryFactoryType = refFactoryTypeAir
                if aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused] > 0 then
                    aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = 1
                else
                    aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.min(3, math.max(1, math.ceil(aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] / 17)))
                end

            elseif aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance then
                iPrimaryFactoryType = refFactoryTypeAir
                aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = 1
            elseif aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == false and aiBrain[refiDistanceToNearestEnemyBase] >= 400 then
                iPrimaryFactoryType = refFactoryTypeAir
                if aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused] > 0 then
                    aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = 1
                else
                    aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.min(5, math.max(1, math.ceil(aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] / 10)))
                end
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

            if aiBrain[refiAIBrainCurrentStrategy] == refStrategyEcoAndTech or aiBrain[refiAIBrainCurrentStrategy] == refStrategyTurtle then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Are in eco or turtle mode so will adjust factory ratios accordingly. M27Conditions.HaveLowMass(aiBrain)=' .. tostring(M27Conditions.HaveLowMass(aiBrain)) .. '; iMexesToBaseCalculationOn=' .. iMexesToBaseCalculationOn)
                end
                if not (M27Conditions.HaveLowMass(aiBrain)) and aiBrain:GetEconomyStoredRatio('MASS') > 0.2 then
                    iPrimaryFactoriesWanted = math.max(5 - aiBrain[refiOurHighestFactoryTechLevel], math.ceil(iMexesToBaseCalculationOn * 0.35))
                    if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 15 then
                        iPrimaryFactoriesWanted = math.max(iPrimaryFactoriesWanted, math.ceil(aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] / 6.5))
                    end
                elseif not (M27Conditions.HaveLowMass(aiBrain)) then
                    iPrimaryFactoriesWanted = math.max(4 - aiBrain[refiOurHighestFactoryTechLevel], math.ceil(iMexesToBaseCalculationOn * 0.25))
                    if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 15 then
                        iPrimaryFactoriesWanted = math.max(iPrimaryFactoriesWanted, math.ceil(aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] / 8))
                    end
                else
                    --Have low mass
                    iPrimaryFactoriesWanted = math.max(1, math.floor(iMexesToBaseCalculationOn * 0.175))
                    if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 15 then
                        iPrimaryFactoriesWanted = math.max(iPrimaryFactoriesWanted, math.ceil(aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] / 5))
                    end
                end

            else
                if M27Conditions.HaveLowMass(aiBrain) then
                    iPrimaryFactoriesWanted = math.max(5 - aiBrain[refiOurHighestFactoryTechLevel], math.ceil(iMexesToBaseCalculationOn * 0.5))
                    if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 15 then
                        iPrimaryFactoriesWanted = math.max(iPrimaryFactoriesWanted, math.ceil(aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] / 8))
                    end
                    if aiBrain[M27AirOverseer.refbBomberDefenceRestrictedByAA] then
                        iPrimaryFactoriesWanted = iPrimaryFactoriesWanted + 1
                    end
                else
                    iPrimaryFactoriesWanted = math.max(6 - aiBrain[refiOurHighestFactoryTechLevel], math.ceil(iMexesToBaseCalculationOn * 0.7))
                    if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 15 then
                        iPrimaryFactoriesWanted = math.max(iPrimaryFactoriesWanted, math.ceil(aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] / 6))
                    end
                    --Do we have lots of air factories and are restricted by enemy AA?
                    if aiBrain[M27AirOverseer.refbBomberDefenceRestrictedByAA] then
                        iPrimaryFactoriesWanted = math.max(iPrimaryFactoriesWanted + 1, aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory))
                    end
                end
            end
            --Overall cap of 15 factories if are land factories
            if iPrimaryFactoryType == refFactoryTypeLand then
                iPrimaryFactoriesWanted = math.min(iPrimaryFactoriesWanted, 15)
            end

            if bDebugMessages == true then
                LOG(sFunctionRef .. ': iPrimaryFactoriesWanted before considering other factors=' .. iPrimaryFactoriesWanted)
            end

            aiBrain[reftiMaxFactoryByType][iPrimaryFactoryType] = iPrimaryFactoriesWanted
            local iAirFactoryMin = 1
            if iPrimaryFactoryType == refFactoryTypeAir then
                iAirFactoryMin = iPrimaryFactoriesWanted
            end
            local iTorpBomberShortfall = aiBrain[M27AirOverseer.refiTorpBombersWanted]
            if aiBrain[refiOurHighestAirFactoryTech] < 2 then
                if iTorpBomberShortfall > 0 then
                    aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1
                end
                iTorpBomberShortfall = 0 --Dont want to build more factories for torp bombers until have access to T2 (since T1 cant build them)
            end
            if iPrimaryFactoryType == refFactoryTypeAir then
                aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1
            end
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': aiBrain[M27AirOverseer.refiAirAANeeded]=' .. aiBrain[M27AirOverseer.refiAirAANeeded] .. '; aiBrain[M27AirOverseer.refiExtraAirScoutsWanted]=' .. aiBrain[M27AirOverseer.refiExtraAirScoutsWanted] .. '; iTorpBomberShortfall=' .. iTorpBomberShortfall)
            end
            local iModBombersWanted = 1 --math.min(aiBrain[M27AirOverseer.refiBombersWanted], 3)
            --reftBomberEffectiveness = 'M27AirBomberEffectiveness' --[x][y]: x = unit tech level, y = nth entry; returns subtable {refiBomberMassCost}{refiBomberMassKilled}
            if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftBomberEffectiveness][aiBrain[refiOurHighestAirFactoryTech]]) == false then
                if aiBrain[M27AirOverseer.reftBomberEffectiveness][aiBrain[refiOurHighestAirFactoryTech]][1][M27AirOverseer.refiBomberMassKilled] >= aiBrain[M27AirOverseer.reftBomberEffectiveness][aiBrain[refiOurHighestAirFactoryTech]][1][M27AirOverseer.refiBomberMassCost] then
                    --Last bomber that died at this tech levle killed more than it cost
                    iModBombersWanted = 1 --math.min(aiBrain[M27AirOverseer.refiBombersWanted], 6)
                end
            end
            local iAirUnitsWanted = math.max(aiBrain[M27AirOverseer.refiAirAANeeded], aiBrain[M27AirOverseer.refiAirAAWanted]) + math.min(3, math.ceil(aiBrain[M27AirOverseer.refiExtraAirScoutsWanted] / 10)) + 1 + iTorpBomberShortfall
            if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftPlateausOfInterest]) == false and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryTransport) == 0 then
                iAirUnitsWanted = iAirUnitsWanted + 1
            end
            aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = math.max(iAirFactoryMin, iAirFactoriesOwned + math.floor((iAirUnitsWanted - iAirFactoriesOwned * 4)))
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': iAirUnitsWanted=' .. iAirUnitsWanted .. '; aiBrain[reftiMaxFactoryByType][refFactoryTypeAir]=' .. aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] .. '; aiBrain[reftiMaxFactoryByType][refFactoryTypeLand]=' .. aiBrain[reftiMaxFactoryByType][refFactoryTypeLand])
            end

            --Increase air factories wanted if enemy has significant land threat and we have the economy to support more air factories (so we can better respond if enemy tries to attack us) providing we arent saving eco to get t3 arti
            if (aiBrain[refiTotalEnemyShortRangeThreat] >= 20000 or aiBrain[refiTotalEnemyLongRangeThreat] >= 20000) and aiBrain[M27AirOverseer.refiPreviousAvailableBombers] <= 80 and not (aiBrain[refbDefendAgainstArti]) then
                aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = math.max(aiBrain[reftiMaxFactoryByType][refFactoryTypeAir], math.min(15, (aiBrain[refiTotalEnemyShortRangeThreat] + aiBrain[refiTotalEnemyLongRangeThreat]) / 5000, aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] / 2))
            end

            if aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill or aiBrain[refiAIBrainCurrentStrategy] == refStrategyProtectACU then
                --aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1
                if aiBrain:GetEconomyStoredRatio('MASS') > 0.1 and aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome] > 1 then
                    aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = iAirFactoriesOwned + 1
                else
                    aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = math.max(1, iAirFactoriesOwned)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Have less than 10% mass stored so capping number of air factories at the number we already own')
                    end
                end
                aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = aiBrain[refiMinLandFactoryBeforeOtherTypes]
            end

            --Increase land factories wanted if we have a significant MAA shortfall
            if aiBrain[refiMAAShortfallHighMass] >= 4 and aiBrain[refiMAAShortfallHighMass] >= 2 * iLandFactoriesOwned and iLandFactoriesOwned <= 5 then
                aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.max(2, aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] + 1)
            end

            --Cap the number of land factories if we are building an experimental and have low mass
            local bActiveExperimental = false
            if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildExperimental]) == false then
                for iRef, tSubtable in aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildExperimental] do
                    if tSubtable[M27EngineerOverseer.refEngineerAssignmentEngineerRef]:IsUnitState('Building') then
                        bActiveExperimental = true
                        break
                    end
                end
            end
            if bActiveExperimental and M27Conditions.HaveLowMass(aiBrain) then
                aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.min(aiBrain[reftiMaxFactoryByType][refFactoryTypeLand], 4)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Active experimental so capping the number of factories will try to build to 4')
                end
            end
            if aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused] > 0 and aiBrain:GetEconomyStoredRatio('MASS') < 0.75 then
                aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.min(2, aiBrain[reftiMaxFactoryByType][refFactoryTypeLand])
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Have land factories temporarily stored so capping number at 2')
                end
            else
                --Do we need indirect units and can path to enemy by land?
                if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] and aiBrain[refbNeedIndirect] and not (M27Conditions.HaveLowMass(aiBrain)) and aiBrain[refiOurHighestLandFactoryTech] == 3 then
                    --Increase number of land factories wanted by 1 from what we currently have
                    aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.max(aiBrain[reftiMaxFactoryByType][refFactoryTypeLand], aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryLandFactory) + 1)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Want 1 more land factory as need indirect')
                    end
                end
            end

            if aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused] > 0 then
                aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.min(aiBrain[reftiMaxFactoryByType][refFactoryTypeLand], 1)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Have factories temporarily paused so only want 1 land factory max')
                end
            end

            --Reduce air factories wanted based on gross energy and mass.  Air fac uses 90 energy for intercepter (T1); Mass usage by air fac and tehc: T1: 2; T2: 5.2; T3: 14
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Factory wanted before reducing based on gross energy and mass: aiBrain[reftiMaxFactoryByType][refFactoryTypeAir]=' .. (aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] or 'nil'))
                LOG(sFunctionRef .. ': aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome]=' .. (aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] or 'nil'))
                LOG(sFunctionRef .. ': aiBrain[refiOurHighestAirFactoryTech]=' .. (aiBrain[refiOurHighestAirFactoryTech] or 'nil'))
            end
            local iAirFactoriesPerMass
            if aiBrain[refiOurHighestAirFactoryTech] >= 3 then
                --A t3 air fac needs 14 mass/s to build an asf; assuming we devote 25% of our mass to air, that would mean wanting 1.7 air facs for every 100 gross mass; note this is the amount before various caps which will also factor in our eco

                --T2 air fac building inties uses 4 mass per sec; building t1 bombers it is 7.2
                --T1 air fac is half this
                local iMassProportionToSpendOnAir = 0.15 --assumed amount to spend on air as a minimum
                if not (aiBrain[M27AirOverseer.refbHaveAirControl]) or aiBrain[M27AirOverseer.refiAirAANeeded] >= 3 or aiBrain[M27AirOverseer.refiAirAAWanted] >= 8 then
                    iMassProportionToSpendOnAir = 0.25
                    if not (aiBrain[M27AirOverseer.refbHaveAirControl]) and aiBrain[M27AirOverseer.refiAirAAWanted] >= 10 then
                        iMassProportionToSpendOnAir = 0.4
                        if aiBrain[M27AirOverseer.refiAirAAWanted] >= 15 and aiBrain[M27AirOverseer.refiAirAANeeded] >= 3 then
                            iMassProportionToSpendOnAir = 0.5
                        end
                    end
                end
                iAirFactoriesPerMass = iMassProportionToSpendOnAir / 1.4
            elseif aiBrain[refiOurHighestAirFactoryTech] == 2 then
                iAirFactoriesPerMass = 0.2 / 0.7
            else
                iAirFactoriesPerMass = 0.2 / 0.35
            end

            aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = math.max(1, math.min((aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] or 1), math.floor(iAirFactoriesPerMass * aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome]), math.floor(aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] / (13 * aiBrain[refiOurHighestAirFactoryTech] * aiBrain[refiOurHighestAirFactoryTech]))))

            if bDebugMessages == true then
                LOG(sFunctionRef .. ': bActiveExperimental=' .. tostring(bActiveExperimental) .. '; Idle factories=' .. aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused] .. '; iAirFactoriesPerMass=' .. iAirFactoriesPerMass .. '; Mass income=' .. aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] .. '; Energy base income=' .. aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] .. '; aiBrain[reftiMaxFactoryByType][refFactoryTypeAir]=' .. (aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] or 'nil'))
            end

            aiBrain[refiMinLandFactoryBeforeOtherTypes] = math.min(aiBrain[refiMinLandFactoryBeforeOtherTypes], aiBrain[reftiMaxFactoryByType][refFactoryTypeLand])

            --Early game - if enemy air detected and we dont ahve an air fac, then buidl air fac as high priority
            if iAirFactoriesOwned == 0 and aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] > 0 then
                aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Dont have any air factories and enemy has air threat so reducing min land factor ybefore other tyopes to 1')
                end
            end

            --Cap factories if we are nearing unit cap
            if aiBrain[refbCloseToUnitCap] then
                aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = math.min(10, aiBrain[reftiMaxFactoryByType][refFactoryTypeAir])
                aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] = math.min(3, aiBrain[reftiMaxFactoryByType][refFactoryTypeLand])
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Close to unit cap so capping air at 10 factories, and land at 3')
                end
            end

            --Cap air factories if have 4 and low mass and dont have T3 yet
            if aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] > 4 and aiBrain[refiOurHighestAirFactoryTech] < 3 then
                if M27Conditions.HaveLowMass(aiBrain) then
                    aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = 4
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Capping air factories at 4 as dont ahve t3 yet and have low mass')
                    end
                else
                    aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = 5
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Capping air factories at 5 as dont ahve t3 yet')
                    end
                end
            end
        end
    end

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code, aiBrain[reftiMaxFactoryByType][refFactoryTypeLand]=' .. aiBrain[reftiMaxFactoryByType][refFactoryTypeLand] .. '; aiBrain[refiMinLandFactoryBeforeOtherTypes]=' .. aiBrain[refiMinLandFactoryBeforeOtherTypes] .. '; aiBrain[reftiMaxFactoryByType][refFactoryTypeAir]=' .. aiBrain[reftiMaxFactoryByType][refFactoryTypeAir])
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DetermineInitialBuildOrder(aiBrain)
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DetermineInitialBuildOrder'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Distance to enemy base examples:
    --Floraris: 200
    --Theta passage: 321
    --Open palms: 361
    --Astro craters: 362
    --Polar depression: 361
    --Forbidden pass: 570
    --Eye of the storm: 598
    --Burial mounds: 832

    --Redundancy as not sure order this is called - should already have been determined but will do this to be safe
    aiBrain[refiDistanceToNearestEnemyBase] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
    --First check if we can path to enemy with amphibious, and if not flag for rest of the game that our ACU will be helping out at base
    local bCantPathOutsideBase = false

    local iNearbyMexCount = 0

    if aiBrain[refiDefaultStrategy] == refStrategyTurtle then
        aiBrain[refiInitialRaiderPlatoonsWanted] = 1
        aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = 8
        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] and aiBrain[refiDistanceToNearestEnemyBase] <= 400 then
            aiBrain[refiMinLandFactoryBeforeOtherTypes] = 2
        else
            aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1
        end
        if aiBrain[refiDistanceToNearestEnemyBase] >= 400 then
            aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = 12
        end

        aiBrain[M27AirOverseer.refiEngiHuntersToGet] = 1
    else

        if not (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]) then
            --Cycle through all mexes and find the furthest one in our pathing group from our base
            local iBasePathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            local iFurthestDistance = 0
            local iCurDistance
            --tMexByPathingAndGrouping - Stores position of each mex based on the segment that it's part of; [a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
            for iMex, tMex in M27MapInfo.tMexByPathingAndGrouping[M27UnitInfo.refPathingTypeAmphibious][iBasePathingGroup] do
                iCurDistance = M27Utilities.GetDistanceBetweenPositions(tMex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                if iCurDistance > iFurthestDistance then
                    iFurthestDistance = iCurDistance
                end
            end
            if iFurthestDistance <= math.min(125, aiBrain[refiDistanceToNearestEnemyBase] * 0.25) then
                bCantPathOutsideBase = true
            end
        end
        M27Utilities.GetACU(aiBrain)[refbACUCantPathAwayFromBase] = bCantPathOutsideBase
        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == true then
            aiBrain[refiInitialRaiderPlatoonsWanted] = 2
            if M27MapInfo.bNoRushActive then
                aiBrain[refiInitialRaiderPlatoonsWanted] = 0
            end


            --How many mexes are there nearby?
            local iPathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            --tMexByPathingAndGrouping = {} --Stores position of each mex based on the segment that it's part of; [a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position


            if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping) == false then
                for iMexNumber, tMex in M27MapInfo.tMexByPathingAndGrouping[M27UnitInfo.refPathingTypeAmphibious][iPathingGroup] do
                    if M27Utilities.GetDistanceBetweenPositions(tMex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 70 then
                        iNearbyMexCount = iNearbyMexCount + 1
                    end
                end
            end
            if iNearbyMexCount >= 12 then
                aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = 7
            elseif iNearbyMexCount >= 8 or aiBrain[refiDistanceToNearestEnemyBase] >= 375 then
                aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = 5
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

            if aiBrain[refiDistanceToNearestEnemyBase] >= 380 then
                if aiBrain[refiDistanceToNearestEnemyBase] <= 425 then
                    aiBrain[refiMinLandFactoryBeforeOtherTypes] = 2
                else
                    aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1
                end
                aiBrain[M27AirOverseer.refiEngiHuntersToGet] = 2
            else
                aiBrain[M27AirOverseer.refiEngiHuntersToGet] = 1
                aiBrain[refiMinLandFactoryBeforeOtherTypes] = 3
            end

        else
            --Cant path to enemy base with land
            aiBrain[refiInitialRaiderPlatoonsWanted] = 0
            aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1
            aiBrain[M27AirOverseer.refiEngiHuntersToGet] = 2
            aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = 10
            if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] == false then
                aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = 12
            end
        end

        --Reduce raiders if map is very small (e.g. winter dual small)
        if aiBrain[refiInitialRaiderPlatoonsWanted] > 1 or aiBrain[M27AirOverseer.refiEngiHuntersToGet] > 1 then
            if math.min(M27MapInfo.rMapPlayableArea[3] - M27MapInfo.rMapPlayableArea[1], M27MapInfo.rMapPlayableArea[4] - M27MapInfo.rMapPlayableArea[2]) <= 150 then
                aiBrain[refiInitialRaiderPlatoonsWanted] = math.min(1, aiBrain[refiInitialRaiderPlatoonsWanted])
                aiBrain[M27AirOverseer.refiEngiHuntersToGet] = math.min(aiBrain[M27AirOverseer.refiEngiHuntersToGet], 1)
            end
        end


        --Override all of the above if are adopting land spam strategy
        --Land spam strategy
        local iLandSpamThreshold = M27Config.iLandSpamChance
        if aiBrain[refiDistanceToNearestEnemyBase] <= 325 then
            if aiBrain[refiDistanceToNearestEnemyBase] <= 225 then iLandSpamThreshold = 1 - (1 - iLandSpamThreshold) * (1 - iLandSpamThreshold) * (1 - iLandSpamThreshold)
            else iLandSpamThreshold = 1 - (1 - iLandSpamThreshold) * (1 - iLandSpamThreshold) end
        end
        --Adjust for number of players and AiX
        local iEnemyBrains = 0
        local iAllyBrains = 1
        if M27Utilities.IsTableEmpty(aiBrain[toEnemyBrains]) == false then
            for iBrain, oBrain in aiBrain[toEnemyBrains] do
                iEnemyBrains = iEnemyBrains + 1
            end
        end
        if M27Utilities.IsTableEmpty(aiBrain[toAllyBrains]) == false then
            for iBrain, oBrain in aiBrain[toAllyBrains] do
                if not(oBrain == aiBrain) then
                    iAllyBrains = iAllyBrains + 1
                end
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Considering whether to increase land rush chance based on number of AI. iAllyBrains='..iAllyBrains..'; iEnemyBrains='..iEnemyBrains) end
        if iAllyBrains > iEnemyBrains or (iAllyBrains == iEnemyBrains and aiBrain.CheatEnabled and tonumber(ScenarioInfo.Options.CheatMult) > 1) then
            iLandSpamThreshold = 1 - (1 - iLandSpamThreshold) * (1 - iLandSpamThreshold)
        end

        iLandSpamThreshold = iLandSpamThreshold * 100
        if bDebugMessages == true then LOG(sFunctionRef..': iLandSpamThreshold chance% * 100='..iLandSpamThreshold) end
        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] and aiBrain[refiDistanceToNearestEnemyBase] <= 380 and iNearbyMexCount <= 8 and math.random(1, 100) <= iLandSpamThreshold then
            aiBrain[refiDefaultStrategy] = refStrategyLandRush
            aiBrain[refiAIBrainCurrentStrategy] = refStrategyLandRush
            aiBrain[refiMinLandFactoryBeforeOtherTypes] = 4


            if aiBrain[refiDistanceToNearestEnemyBase] <= 325 then
                aiBrain[refiInitialRaiderPlatoonsWanted] = 1
                aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = math.random(2,3)
                if math.random(0,1) == 0 then aiBrain[M27AirOverseer.refiEngiHuntersToGet] = math.random(0, 1) end --25% chance of t1 bomber engi raider
            else
                aiBrain[refiInitialRaiderPlatoonsWanted] = 2
                aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = math.random(3,4)
                --75% chance of t1 bomber engi raider
                if math.random(0,1) == 0 then aiBrain[M27AirOverseer.refiEngiHuntersToGet] = math.random(0, 1)
                else aiBrain[M27AirOverseer.refiEngiHuntersToGet] = 1
                end
            end

        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code, aiBrain[M27FactoryOverseer.refiInitialEngineersWanted]=' .. aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] .. '; aiBrain[reftiMaxFactoryByType][refFactoryTypeAir]=' .. aiBrain[reftiMaxFactoryByType][refFactoryTypeLand]..'; aiBrain[refiAIBrainCurrentStrategy]='..aiBrain[refiAIBrainCurrentStrategy])
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdateHighestFactoryTechTracker(aiBrain)
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateHighestFactoryTechTracker'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code, gametime=' .. GetGameTimeSeconds())
    end

    local iHighestTechLevel = 1
    if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllHQFactories * categories.TECH3 - categories.SUPPORTFACTORY) > 0 then
        iHighestTechLevel = 3
    elseif aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllHQFactories * categories.TECH2 - categories.SUPPORTFACTORY) > 0 then
        iHighestTechLevel = 2
    end
    aiBrain[refiOurHighestFactoryTechLevel] = iHighestTechLevel
    if iHighestTechLevel > 1 then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': iHighestTechLevel=' .. iHighestTechLevel .. '; will consider how many air and land factories we have')
        end
        if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory * categories.TECH3 - categories.SUPPORTFACTORY) > 0 then
            aiBrain[refiOurHighestAirFactoryTech] = 3
        elseif aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory * categories.TECH2 - categories.SUPPORTFACTORY) > 0 then
            aiBrain[refiOurHighestAirFactoryTech] = 2
        else
            aiBrain[refiOurHighestAirFactoryTech] = 1
        end
        if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryLandFactory * categories.TECH3 - categories.SUPPORTFACTORY) > 0 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': We have T3 land factories')
            end
            aiBrain[refiOurHighestLandFactoryTech] = 3
        elseif aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryLandFactory * categories.TECH2 - categories.SUPPORTFACTORY) > 0 then
            aiBrain[refiOurHighestLandFactoryTech] = 2
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': We dont have T3 land factories but do have T2, setting highest land fac tech to 2. aiBrain[refiOurHighestLandFactoryTech] after update='..aiBrain[refiOurHighestLandFactoryTech])
            end
        else
            aiBrain[refiOurHighestLandFactoryTech] = 1
            if bDebugMessages == true then LOG(sFunctionRef..': Set our highest land fac tech to 1') end
        end

        if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryNavalFactory * categories.TECH3 - categories.SUPPORTFACTORY) > 0 then
            aiBrain[refiOurHighestNavalFactoryTech] = 3
        elseif aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryNavalFactory * categories.TECH2 - categories.SUPPORTFACTORY) > 0 then
            aiBrain[refiOurHighestNavalFactoryTech] = 2
        else
            aiBrain[refiOurHighestNavalFactoryTech] = 1
        end
    else
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Highest of any factory tech is only tech 1')
        end
        aiBrain[refiOurHighestAirFactoryTech] = 1
        aiBrain[refiOurHighestLandFactoryTech] = 1
        aiBrain[refiOurHighestNavalFactoryTech] = 1
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Number of tech2 factories=' .. aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllHQFactories * categories.TECH2) .. '; Number of tech3 factories=' .. aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllHQFactories * categories.TECH3) .. '; iHighestTechLevel=' .. iHighestTechLevel .. '; aiBrain[refiOurHighestFactoryTechLevel]=' .. aiBrain[refiOurHighestFactoryTechLevel] .. '; aiBrain[refiOurHighestAirFactoryTech]=' .. aiBrain[refiOurHighestAirFactoryTech] .. '; Number of T3 land factories=' .. aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryLandFactory * categories.TECH3) .. '; Highest land factory tech=' .. aiBrain[refiOurHighestLandFactoryTech])
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdateAllNonM27Names()
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateAllNonM27Names'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code. bUnitNameUpdateActive=' .. tostring(bUnitNameUpdateActive) .. '; M27Config.M27ShowEnemyUnitNames=' .. tostring(M27Config.M27ShowEnemyUnitNames))
    end
    if not (bUnitNameUpdateActive) and M27Config.M27ShowEnemyUnitNames then
        bUnitNameUpdateActive = true
        local iMaxUpdatePerTick = 10
        local iCurUpdateCount = 0

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': About to cycle through every unit owned by a player and update its name if its not an M27AI brain.  Size of table of brains=' .. table.getn(tAllAIBrainsByArmyIndex))
        end
        for iBrain, oBrain in tAllAIBrainsByArmyIndex do
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Considering iBrain=' .. iBrain .. '; armyindex=' .. oBrain:GetArmyIndex() .. '; .M27AI=' .. tostring((oBrain.M27AI or false)))
            end
            if not (oBrain.M27AI) then
                local tAllUnits = oBrain:GetListOfUnits(categories.ALLUNITS - categories.BENIGN, false, false)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Size of tAllUnits=' .. table.getn(tAllUnits))
                end
                if not (M27Utilities.IsTableEmpty(tAllUnits)) then
                    for iUnit, oUnit in tAllUnits do
                        if oUnit.SetCustomName and M27UnitInfo.IsUnitValid(oUnit) then
                            oUnit:SetCustomName(oUnit.UnitId .. ':LC=' .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
                        end
                        iCurUpdateCount = iCurUpdateCount + 1
                        if iCurUpdateCount >= iMaxUpdatePerTick then
                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                            WaitTicks(1)
                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                            iCurUpdateCount = 0
                        end
                    end
                end

            end
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': End of code')
        end

        bUnitNameUpdateActive = false
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)

end

function CheckUnitCap(aiBrain)
    local sFunctionRef = 'CheckUnitCap'
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetGameTimeSeconds() >= 2100 then bDebugMessages = true end

    local iUnitCap = tonumber(ScenarioInfo.Options.UnitCap)
    local iCurUnits = aiBrain:GetCurrentUnits(categories.ALLUNITS - M27UnitInfo.refCategoryWall) + aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryWall) * 0.25
    local iThreshold = math.ceil(iUnitCap * 0.02)
    if bDebugMessages == true then LOG(sFunctionRef..': iCurUnits='..iCurUnits..'; iUnitCap='..iUnitCap..'; iThreshold='..iThreshold) end
    if iCurUnits > (iUnitCap - iThreshold * 5) then
        aiBrain[refbCloseToUnitCap] = true
        local iMaxToDestroy = math.ceil(iUnitCap * 0.01)
        local iCurUnitsDestroyed = 0
        local tUnitsToDestroy
        local tiCategoryToDestroy = {
            [0] = categories.TECH1 - categories.COMMAND,
            [1] = M27UnitInfo.refCategoryAllAir * categories.TECH1,
            [2] = M27UnitInfo.refCategoryMobileLand * categories.TECH2 - categories.COMMAND - M27UnitInfo.refCategoryMAA + M27UnitInfo.refCategoryAirScout + M27UnitInfo.refCategoryAirAA * categories.TECH1 + categories.NAVAL * categories.MOBILE * categories.TECH1,
            [3] = M27UnitInfo.refCategoryMobileLand * categories.TECH1 - categories.COMMAND,
            [4] = M27UnitInfo.refCategoryWall + M27UnitInfo.refCategoryEngineer - categories.TECH3,
        }
        if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer) > iUnitCap * 0.35 then tiCategoryToDestroy[0] = tiCategoryToDestroy[0] + M27UnitInfo.refCategoryEngineer end
        for iAdjustmentLevel = 4, 0, -1 do
            if bDebugMessages == true then LOG(sFunctionRef..': iCurUnitsDestroyed so far='..iCurUnitsDestroyed..'; iMaxToDestroy='..iMaxToDestroy..'; iAdjustmentLevel='..iAdjustmentLevel..'; iCurUnits='..iCurUnits..'; Unit cap='..iUnitCap..'; iThreshold='..iThreshold) end
            if iCurUnits > (iUnitCap - iThreshold * iAdjustmentLevel) then
                tUnitsToDestroy = aiBrain:GetListOfUnits(tiCategoryToDestroy[iAdjustmentLevel], false, false)
                if M27Utilities.IsTableEmpty(tUnitsToDestroy) == false then
                    for iUnit, oUnit in tUnitsToDestroy do
                        if oUnit.Kill then
                            if bDebugMessages == true then LOG(sFunctionRef..': iCurUnitsDestroyed so far='..iCurUnitsDestroyed..'; Will destroy unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to avoid going over unit cap') end
                            oUnit:Kill()
                            iCurUnitsDestroyed = iCurUnitsDestroyed + 1
                            if iCurUnitsDestroyed >= iMaxToDestroy then break end
                        end
                    end
                end
                if iCurUnitsDestroyed >= iMaxToDestroy then break end
            else
                break
            end
        end
    else
        aiBrain[refbCloseToUnitCap] = false
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdateFurthestBuildingDistances(aiBrain)
    --Records the high value buildings we have furthest from our base, used to help decide on bomber and land defence ranges as well as potential eco decisions

    local iHighValueCategories = categories.EXPERIMENTAL + M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategorySML + M27UnitInfo.refCategoryT3Mex + M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryT2Power + M27UnitInfo.refCategoryT3Power + M27UnitInfo.refCategoryAirFactory
    if aiBrain[refiOurHighestFactoryTechLevel] < 3 and aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] <= 4 then
        local iCategoryToSearchFor
        if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] < 3 then
            if aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] < 100 then
                iCategoryToSearchFor = M27UnitInfo.refCategoryHydro + M27UnitInfo.refCategoryT1Mex
            else
                iCategoryToSearchFor = M27UnitInfo.refCategoryT1Mex
            end
        elseif aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] < 100 then
            iCategoryToSearchFor = M27UnitInfo.refCategoryHydro
        end

        if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] < 3 then
            iHighValueCategories = iHighValueCategories + M27UnitInfo.refCategoryT1Mex
        end
        if aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] < 100 then
            iHighValueCategories = iHighValueCategories + M27UnitInfo.refCategoryHydro
        end
    end

    local tOurHighValueBuildings = aiBrain:GetListOfUnits(iHighValueCategories, false, false)
    local iMinRange = 50
    aiBrain[refiFurthestValuableBuildingModDist] = iMinRange
    aiBrain[refiFurthestValuableBuildingActualDist] = iMinRange
    if M27Utilities.IsTableEmpty(tOurHighValueBuildings) == false then
        --local iFurthestModDistance
        --local iFurthestActualDistance
        local iCurDistance
        local iCurModDistance
        for iUnit, oUnit in tOurHighValueBuildings do
            if oUnit:GetFractionComplete() < 1 or EntityCategoryContains(categories.STRUCTURE + M27UnitInfo.refCategoryExperimentalArti, oUnit.UnitId) then --Dont include expeirmentals once constructed
                iCurDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                if iCurDistance > aiBrain[refiFurthestValuableBuildingModDist] then
                    iCurModDistance = GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false)
                    aiBrain[refiFurthestValuableBuildingModDist] = math.max(iCurModDistance, aiBrain[refiFurthestValuableBuildingModDist])
                    aiBrain[refiFurthestValuableBuildingActualDist] = math.max(iCurDistance, aiBrain[refiFurthestValuableBuildingActualDist])
                end
            end
        end
    end
end

function AddUnitToBigThreatTable(aiBrain, oUnit)
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    --local bDebugMessages = M27Config.M27StrategicLog
    local sFunctionRef = 'AddUnitToBigThreatTable'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if not(oUnit[M27UnitInfo.reftbInArmyIndexBigThreatTable] and oUnit[M27UnitInfo.reftbInArmyIndexBigThreatTable][aiBrain:GetArmyIndex()]) then




        local bAlreadyInTable = false
        local bConsiderChatWarning = true
        local bWantACUToReturnToBase = false


        for sReferenceTable, iCategory in tEnemyBigThreatCategories do
            if EntityCategoryContains(iCategory, oUnit.UnitId) then
                for iExistingUnit, oExistingUnit in aiBrain[sReferenceTable] do
                    if oExistingUnit == oUnit then

                        bAlreadyInTable = true --redundancy
                        if not(oUnit[M27UnitInfo.reftbInArmyIndexBigThreatTable]) then oUnit[M27UnitInfo.reftbInArmyIndexBigThreatTable] = {} end
                        oUnit[M27UnitInfo.reftbInArmyIndexBigThreatTable][aiBrain:GetArmyIndex()] = true
                        break
                    end
                end
                if not(bAlreadyInTable) then
                    if bDebugMessages == true then LOG(sFunctionRef..': About to add unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to reference table. Is table empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[sReferenceTable]))..'; bConsiderChatWarning='..tostring(bConsiderChatWarning)..'; Unit fraction complete='..oUnit:GetFractionComplete()..'; T3 resource generation units held by owner='..oUnit:GetAIBrain():GetCurrentUnits(M27UnitInfo.refCategoryT3Mex + M27UnitInfo.refCategoryRASSACU + M27UnitInfo.refCategoryParagon)) end
                    if sReferenceTable == reftEnemySMD or sReferenceTable == reftEnemyTML then
                        bConsiderChatWarning = false
                    elseif sReferenceTable == reftEnemyLandExperimentals then
                        bWantACUToReturnToBase = true
                    end

                    if bConsiderChatWarning and M27Utilities.IsTableEmpty(aiBrain[sReferenceTable]) then
                        if sReferenceTable == reftEnemyArtiAndExpStructure then
                            if EntityCategoryContains(M27UnitInfo.refCategoryNovaxCentre, oUnit.UnitId) then
                                M27Chat.SendMessage(aiBrain, oUnit.UnitId, 'Enemy Novax detected', 0, 1000, true)
                            elseif EntityCategoryContains(M27UnitInfo.refCategoryFixedT3Arti, oUnit.UnitId) then
                                M27Chat.SendMessage(aiBrain, oUnit.UnitId, 'Enemy T3 arti detected', 0, 1000, true)
                            elseif EntityCategoryContains(M27UnitInfo.refCategoryExperimentalStructure, oUnit.UnitId) then
                                if oUnit:GetFractionComplete() <= 0.2 and oUnit:GetAIBrain():GetCurrentUnits(M27UnitInfo.refCategoryT3Mex + M27UnitInfo.refCategoryRASSACU + M27UnitInfo.refCategoryParagon) <= 20 then
                                    M27Chat.SendMessage(aiBrain, sReferenceTable, 'LOL theyre building a '..LOCF(oUnit:GetBlueprint().General.UnitName), 0, 1000, true)
                                else
                                    M27Chat.SendMessage(aiBrain, sReferenceTable, 'Enemy '..LOCF(oUnit:GetBlueprint().General.UnitName)..' detected', 0, 1000, true)
                                end
                            end
                        elseif sReferenceTable == reftEnemyLandExperimentals then
                            M27Chat.SendMessage(aiBrain, oUnit.UnitId, 'Enemy '..LOCF(oUnit:GetBlueprint().General.UnitName)..' detected', 0, 1000, true)
                        else
                            M27Chat.SendMessage(aiBrain, sReferenceTable, 'Enemy '..sReferenceTable..' detected', 0, 1000, true)
                        end
                    end

                    table.insert(aiBrain[sReferenceTable], oUnit)
                    if not(oUnit[M27UnitInfo.reftbInArmyIndexBigThreatTable]) then oUnit[M27UnitInfo.reftbInArmyIndexBigThreatTable] = {} end
                    oUnit[M27UnitInfo.reftbInArmyIndexBigThreatTable][aiBrain:GetArmyIndex()] = true

                    if bWantACUToReturnToBase and M27Utilities.IsTableEmpty(aiBrain[sReferenceTable]) == false then
                        aiBrain[refbAreBigThreats] = true
                    end
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Have some units for experimental threat category sReferenceTable=' .. sReferenceTable .. '; is tReferenceTableEmpty after considering if civilian or pathable to us='..tostring(M27Utilities.IsTableEmpty(aiBrain[sReferenceTable]))..'; aiBrain[refbAreBigThreats]='..tostring(aiBrain[refbAreBigThreats]))
                    end
                end
                break
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end


function StrategicOverseer(aiBrain, iCurCycleCount)
    --also features 'state of game' logs
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    --local bDebugMessages = M27Config.M27StrategicLog
    local sFunctionRef = 'StrategicOverseer'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if not(aiBrain[M27Logic.refbAllEnemiesDead]) then
        --Super enemy threats that need a big/unconventional response - check every second as some e.g. nuke require immediate response
        local iBigThreatSearchRange = 10000

        --local tEnemyBigThreatCategories = { ['Land experimental'] = M27UnitInfo.refCategoryLandExperimental, ['T3 arti'] = M27UnitInfo.refCategoryFixedT3Arti, ['Experimental building'] = M27UnitInfo.refCategoryExperimentalStructure, ['Nuke'] = M27UnitInfo.refCategorySML, ['TML'] = M27UnitInfo.refCategoryTML, ['Missile ships'] = M27UnitInfo.refCategoryMissileShip, ['SMD'] = M27UnitInfo.refCategorySMD }
        local tCurCategoryUnits
        local tReferenceTable, bRemovedUnit
        local sUnitUniqueRef
        local bWantACUToReturnToBase = false --Affects whether ACU will run or not
        local bAlreadyInTable
        local iPathingGroupWanted = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        local bConsiderChatWarning = false

        --if GetGameTimeSeconds() >= 790 and aiBrain:GetArmyIndex() == 2 then bDebugMessages = true end





        for sReferenceTable, iCategory in tEnemyBigThreatCategories do
            --Update the table in case any existing entries have been killed, and to remove civilians
            if M27Utilities.IsTableEmpty(aiBrain[sReferenceTable]) == false then
                bRemovedUnit = true
                while bRemovedUnit == true do
                    bRemovedUnit = false
                    for iUnit, oUnit in aiBrain[sReferenceTable] do
                        if not (oUnit.GetUnitId) or oUnit.Dead or oUnit.IsCivilian then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': iUnit=' .. iUnit .. ': No longer alive or has unit ID so removing from the reference table')
                            end
                            table.remove(aiBrain[sReferenceTable], iUnit)
                            bRemovedUnit = true
                            break
                        end
                    end
                end
            end



            --[[bWantACUToReturnToBase = false
            bConsiderChatWarning = false
            tCurCategoryUnits = aiBrain:GetUnitsAroundPoint(iCategory, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iBigThreatSearchRange, 'Enemy')
            if bDebugMessages == true then LOG(sFunctionRef..': sCategoryDesc='..sCategoryDesc..'; Is table of enemy units in a range of '..iBigThreatSearchRange..' empty='..tostring(M27Utilities.IsTableEmpty(tCurCategoryUnits))) end
            tReferenceTable = aiBrain[sCategoryDesc]
            bConsiderChatWarning = true
            if sCategoryDesc == reftEnemySMD or sCategoryDesc == reftEnemyTML then
                bConsiderChatWarning = false
            elseif sCategoryDesc == reftEnemyLandExperimentals then
                bWantACUToReturnToBase = true
            end

            if sCategoryDesc ==  == M27UnitInfo.refCategoryExperimentalStructure or iCategory == M27UnitInfo.refCategoryFixedT3Arti then
                tReferenceTable = aiBrain[reftEnemyArtiAndExpStructure]
                bConsiderChatWarning = true
            elseif iCategory == M27UnitInfo.refCategorySML then
                tReferenceTable = aiBrain[reftEnemyNukeLaunchers]
                bConsiderChatWarning = true
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Looking for enemy nukes')
                end
                bWantACUToReturnToBase = true
            elseif iCategory == M27UnitInfo.refCategoryTML or iCategory == M27UnitInfo.refCategoryMissileShip then
                tReferenceTable = aiBrain[reftEnemyTML]
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Looking for enemy TML')
                end
            elseif iCategory == M27UnitInfo.refCategoryLandExperimental then
                tReferenceTable = aiBrain[reftEnemyLandExperimentals]
                bConsiderChatWarning = true
                bWantACUToReturnToBase = true
            elseif iCategory == M27UnitInfo.refCategoryFixedT3Arti or iCategory == M27UnitInfo.refCategoryExperimentalStructure then
                tReferenceTable = aiBrain[reftEnemyArtiAndExpStructure]
                bConsiderChatWarning = true
            elseif iCategory == M27UnitInfo.refCategorySMD then
                tReferenceTable = aiBrain[reftEnemySMD]
            else
                M27Utilities.ErrorHandler('Unrecognised enemy super threat category, wont be recorded')
                break
            end


            if M27Utilities.IsTableEmpty(tCurCategoryUnits) == false then
                for iUnit, oUnit in tCurCategoryUnits do
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; .IsCivilian='..tostring(oUnit.IsCivilian or false)..'; Can see unit='..tostring(M27Utilities.CanSeeUnit(aiBrain, oUnit, false))..'; iPathingGroupWanted='..iPathingGroupWanted..'; unit pathing group='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition())..'; Is civilian brain='..tostring(M27Logic.IsCivilianBrain(oUnit:GetAIBrain()))..'; is unit mobile land='..tostring(EntityCategoryContains(categories.MOBILE * categories.LAND, oUnit.UnitId))) end
                    if (not(oUnit.IsCivilian) or aiBrain[refbNoEnemies]) and M27Utilities.CanSeeUnit(aiBrain, oUnit, false) == true and
                            (not(EntityCategoryContains(categories.MOBILE * categories.LAND, oUnit.UnitId)) or iPathingGroupWanted == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition())) and
                            not(oUnit.UnitId == 'xab1401' and M27Logic.IsCivilianBrain(oUnit:GetAIBrain())) then

                        if bDebugMessages == true then LOG(sFunctionRef..': Have a non-civilian enemy experimental level threat, unit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                        --Check unit not already in reference table
                        bAlreadyInTable = false
                        for iExistingUnit, oExistingUnit in tReferenceTable do
                            if oExistingUnit == oUnit then
                                bAlreadyInTable = true
                                break
                            end
                        end
                        if not(bAlreadyInTable) then

                            if bDebugMessages == true then LOG(sFunctionRef..': About to add unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to reference table. Is table empty='..tostring(M27Utilities.IsTableEmpty(tReferenceTable))..'; bConsiderChatWarning='..tostring(bConsiderChatWarning)..'; Unit fraction complete='..oUnit:GetFractionComplete()..'; T3 resource generation units held by owner='..oUnit:GetAIBrain():GetCurrentUnits(M27UnitInfo.refCategoryT3Mex + M27UnitInfo.refCategoryRASSACU + M27UnitInfo.refCategoryParagon)) end
                            if bConsiderChatWarning and M27Utilities.IsTableEmpty(tReferenceTable) then
                                if sCategoryDesc == 'Experimental building' then
                                    if EntityCategoryContains(M27UnitInfo.refCategoryNovaxCentre, oUnit.UnitId) then
                                        M27Chat.SendMessage(aiBrain, oUnit.UnitId, 'Enemy Novax detected', 0, 1000, true)
                                    else
                                        if oUnit:GetFractionComplete() <= 0.2 and oUnit:GetAIBrain():GetCurrentUnits(M27UnitInfo.refCategoryT3Mex + M27UnitInfo.refCategoryRASSACU + M27UnitInfo.refCategoryParagon) <= 20 then
                                            M27Chat.SendMessage(aiBrain, sCategoryDesc, 'LOL theyre building a '..LOCF(oUnit:GetBlueprint().General.UnitName), 0, 1000, true)
                                        else
                                            M27Chat.SendMessage(aiBrain, sCategoryDesc, 'Enemy '..LOCF(oUnit:GetBlueprint().General.UnitName)..' detected', 0, 1000, true)
                                        end
                                    end
                                elseif sCategoryDesc == 'Land experimental' then
                                    M27Chat.SendMessage(aiBrain, oUnit.UnitId, 'Enemy '..LOCF(oUnit:GetBlueprint().General.UnitName)..' detected', 0, 1000, true)
                                else
                                    M27Chat.SendMessage(aiBrain, sCategoryDesc, 'Enemy '..sCategoryDesc..' detected', 0, 1000, true)
                                end
                            end

                            table.insert(tReferenceTable, oUnit)
                        end
                        sUnitUniqueRef = oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)
                        if tReferenceTable[sUnitUniqueRef] == nil then
                            tReferenceTable[sUnitUniqueRef] = oUnit
                            if bDebugMessages == true then LOG(sFunctionRef..': Added Unit with uniqueref='..sUnitUniqueRef..' to the threat table') end
                        end
                    end
                end
                if bWantACUToReturnToBase and M27Utilities.IsTableEmpty(tReferenceTable) == false then
                    aiBrain[refbAreBigThreats] = true
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Have some units for experimental threat category sCategoryDesc=' .. sCategoryDesc .. '; is tReferenceTableEmpty after considering if civilian or pathable to us='..tostring(M27Utilities.IsTableEmpty(tReferenceTable))..'; aiBrain[refbAreBigThreats]='..tostring(aiBrain[refbAreBigThreats]))
                end
            end

        end
        --]]
        end
        local tBigThreats = aiBrain:GetUnitsAroundPoint(iAllBigThreatCategories, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iBigThreatSearchRange, 'Enemy')
        if M27Utilities.IsTableEmpty(tBigThreats) == false then
            for iUnit, oUnit in tBigThreats do
                AddUnitToBigThreatTable(aiBrain, oUnit)
            end
        end

        --TML - also update ACUs and SACUs with TML upgrade
        local tEnemyACUAndSACUs = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryUnitsWithTMLUpgrade, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iBigThreatSearchRange, 'Enemy')
        if M27Utilities.IsTableEmpty(tEnemyACUAndSACUs) == false then
            for iUnit, oUnit in tEnemyACUAndSACUs do
                bAlreadyInTable = false
                for iUpgrade, sUpgrade in M27Conditions.tTMLUpgrades do
                    if oUnit:HasEnhancement(sUpgrade) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Enemy has an ACU or SACU with TML upgrade, unit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; sUpgrade=' .. sUpgrade)
                        end
                        for iExistingUnit, oExistingUnit in aiBrain[reftEnemyTML] do
                            if oExistingUnit == oUnit then
                                bAlreadyInTable = true
                                break
                            end
                        end
                        if not(bAlreadyInTable) then
                            table.insert(aiBrain[reftEnemyTML], oUnit)
                        end
                        --aiBrain[reftEnemyTML][oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)] = oUnit
                        break
                    end
                end
            end
        end

        if M27Utilities.IsTableEmpty(aiBrain[reftEnemyTML]) == false then
            for iUnit, oUnit in aiBrain[reftEnemyTML] do
                if not (oUnit[M27UnitInfo.refbTMDChecked]) or (EntityCategoryContains(categories.MOBILE, oUnit.UnitId) and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oUnit[M27UnitInfo.reftPositionWhenTMDChecked]) > 50) then
                    oUnit[M27UnitInfo.refbTMDChecked] = true
                    oUnit[M27UnitInfo.reftPositionWhenTMDChecked] = {}
                    oUnit[M27UnitInfo.reftPositionWhenTMDChecked][1], oUnit[M27UnitInfo.reftPositionWhenTMDChecked][2], oUnit[M27UnitInfo.reftPositionWhenTMDChecked][3] = oUnit:GetPositionXYZ()
                    ForkThread(M27Logic.DetermineTMDWantedForTML, aiBrain, oUnit)
                end
            end


            --Mobile shield to protect temporarily:
            if aiBrain[refbEnemyTMLSightedBefore] == false then
                aiBrain[M27PlatoonFormer.refbUsingMobileShieldsForPlatoons] = true
                aiBrain[refbEnemyTMLSightedBefore] = true
            end
            if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryTML, aiBrain[reftEnemyTML])) == false then
                --SendMessage(aiBrain, sMessageType, sMessage, iOptionalDelayBeforeSending, iOptionalTimeBetweenMessageType, bOnlySendToTeam)
                M27Chat.SendMessage(aiBrain, 'TML sighted', 'They have TML, get TMD', 0, 100000, true)
            end
        else
            --No TML - remove the flag that we need TMD from units
            aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau] = {}
        end

        --Record when we have first had sight of SMD (so can factor in if we decide to fire a nuke)
        if M27Utilities.IsTableEmpty(aiBrain[reftEnemySMD]) == false then
            for iUnit, oUnit in aiBrain[reftEnemySMD] do
                if not (oUnit[M27UnitInfo.refiTimeOfLastCheck]) and oUnit:GetFractionComplete() == 1 then
                    oUnit[M27UnitInfo.refiTimeOfLastCheck] = GetGameTimeSeconds()
                end
            end

        end

        --Does enemy have a large air threat?
        if not (aiBrain[refbAreBigThreats]) and (aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] >= 30000 or (aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] >= 15000 and (aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] * 0.8 > aiBrain[M27AirOverseer.refiOurMassInAirAA] or aiBrain[M27AirOverseer.refiAirAANeeded] >= 10))) then
            aiBrain[refbAreBigThreats] = true
        end

        --are there any cloaked ACUs or SACUs? (will also check for cloacked ACUs in the acu manager for the nearest ACU)
        if not (aiBrain[refbCloakedEnemyACU]) then
            local tCybranSACUs = aiBrain:GetUnitsAroundPoint(categories.COMMAND * categories.CYBRAN + categories.SUBCOMMANDER * categories.CYBRAN, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iBigThreatSearchRange, 'Enemy')
            if M27Utilities.IsTableEmpty(tCybranSACUs) == false then
                for iSACU, oSACU in tCybranSACUs do
                    if oSACU:HasEnhancement('CloakingGenerator') then
                        aiBrain[refbCloakedEnemyACU] = true
                        break
                    end
                end
            end
        end
        if aiBrain[refbCloakedEnemyACU] then
            aiBrain[refbAreBigThreats] = true
        elseif aiBrain[refbEnemyFiredNuke] then
            aiBrain[refbAreBigThreats] = true
        end

        --Coordinate friendly experimentals if enemy has land experimentals, and record nearest enemy land experimental
        if bDebugMessages == true then LOG(sFunctionRef..': Is table of enemy land experimentals empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEnemyLandExperimentals]))) end
        if M27Utilities.IsTableEmpty(aiBrain[reftEnemyLandExperimentals]) == false then
            local bEnemyHasLandExperimental = false
            local iClosestExperimentalDistLessRange = 10000
            local iCurDist
            local iCurRange
            local oClosestExperimental


            for iUnit, oUnit in aiBrain[reftEnemyLandExperimentals] do
                if M27UnitInfo.IsUnitValid(oUnit) then
                    if oUnit:GetFractionComplete() >= 0.9 then
                        bEnemyHasLandExperimental = true
                        iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                        iCurRange = M27UnitInfo.GetUnitMaxGroundRange(oUnit)
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iCurDist='..(iCurDist or 'nil')..'; iCurRange='..(iCurRange or 'nil')) end
                        if iCurDist - iCurRange < iClosestExperimentalDistLessRange then
                            iClosestExperimentalDistLessRange = iCurDist - iCurRange
                            oClosestExperimental = oUnit
                        end
                    end
                end
            end
            if bEnemyHasLandExperimental then
                ForkThread(CoordinateLandExperimentals, aiBrain)
                aiBrain[refoNearestRangeAdjustedLandExperimental] = oClosestExperimental
                aiBrain[refiNearestRangeAdjustedLandExperimental] = iClosestExperimentalDistLessRange
                if bDebugMessages == true then LOG(sFunctionRef..': Enemy has land experimental, oClosestExperimental='..oClosestExperimental.UnitId..M27UnitInfo.GetUnitLifetimeCount(oClosestExperimental)..'; iClosestExperimentalDistLessRange='..iClosestExperimentalDistLessRange..'; Is unit valid='..tostring(M27UnitInfo.IsUnitValid(aiBrain[refoNearestRangeAdjustedLandExperimental])))
                    if aiBrain[refoNearestRangeAdjustedLandExperimental] then LOG(sFunctionRef..': aiBrain[refoNearestRangeAdjustedLandExperimental].UnitId='..(aiBrain[refoNearestRangeAdjustedLandExperimental].UnitId or 'nil')) end
                end
            else
                --Clear if unit is no longer valid (otherwise want to retain so we know the threat is there)
                if not(M27UnitInfo.IsUnitValid(aiBrain[refoNearestRangeAdjustedLandExperimental])) then
                    aiBrain[refoNearestRangeAdjustedLandExperimental] = nil
                    aiBrain[refiNearestRangeAdjustedLandExperimental] = nil
                    if bDebugMessages == true then LOG(sFunctionRef..': Clearing values for nearest land experimental') end
                end
            end
        else
            if not(M27UnitInfo.IsUnitValid(aiBrain[refoNearestRangeAdjustedLandExperimental])) then
                aiBrain[refoNearestRangeAdjustedLandExperimental] = nil
                aiBrain[refiNearestRangeAdjustedLandExperimental] = nil
                if bDebugMessages == true then LOG(sFunctionRef..': Clearing values for nearest land experimental') end
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Finished recording nearest land experimental, is unit valid='..tostring(M27UnitInfo.IsUnitValid(aiBrain[refoNearestRangeAdjustedLandExperimental]))) end
        --Coordinate novax
        if M27Utilities.IsTableEmpty(aiBrain[reftEnemyArtiAndExpStructure]) == false then
            local bEnemyHasAlmostCompleteArti = false
            for iUnit, oUnit in aiBrain[reftEnemyArtiAndExpStructure] do
                if oUnit:GetFractionComplete() >= 0.5 then
                    bEnemyHasAlmostCompleteArti = true
                end
            end
            if bEnemyHasAlmostCompleteArti then
                ForkThread(CoordinateNovax, aiBrain)
            end

            --Protect against arti - 1-off event to udpate shielding, and then flag going forwards to keep shields updated
            if not (aiBrain[refbDefendAgainstArti]) then
                local bWantToDefend = false
                for iUnit, oUnit in aiBrain[reftEnemyArtiAndExpStructure] do
                    if oUnit:GetFractionComplete() >= 0.2 then
                        --Check it isnt a paragon or mavor (since no point shielding against either of these)
                        if not (EntityCategoryContains(categories.EXPERIMENTAL * categories.MASSFABRICATION + categories.ARTILLERY * categories.STRUCTURE * categories.UEF * categories.EXPERIMENTAL, oUnit.UnitId)) then
                            bWantToDefend = true
                            break
                        end
                    end
                end
                if bWantToDefend then
                    aiBrain[refbDefendAgainstArti] = true
                    ForkThread(M27EngineerOverseer.UpdateShieldingToDefendAgainstArti, aiBrain)
                end
            end
        end

        --Decide if we want to prioritise experimentals
        if not(aiBrain[refbPrioritiseExperimental]) then
            if aiBrain[refbDefendAgainstArti] then aiBrain[refbPrioritiseExperimental] = true
            else
                --Get LC for our team
                local iSubteamLC = 0
                local iLCThresholdHigh = 4
                local iLCThresholdLow = 2
                local iActiveSubteamExperimentalLevel = 0
                for iBrain, oBrain in M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subreftoFriendlyBrains] do
                    if not(oBrain.M27IsDefeated) then
                        iSubteamLC = iSubteamLC + M27Conditions.GetLifetimeBuildCount(oBrain, M27UnitInfo.refCategoryExperimentalLevel)
                        if iSubteamLC > iLCThresholdHigh or iActiveSubteamExperimentalLevel >= iLCThresholdLow then break end
                        iActiveSubteamExperimentalLevel = iActiveSubteamExperimentalLevel + oBrain:GetCurrentUnits(M27UnitInfo.refCategoryExperimentalLevel)
                    end
                end
                if iSubteamLC >= iLCThresholdHigh then
                    aiBrain[refbPrioritiseExperimental] = true
                elseif iSubteamLC >= iLCThresholdLow and iActiveSubteamExperimentalLevel > 0 then
                    aiBrain[refbPrioritiseExperimental] = true
                elseif iActiveSubteamExperimentalLevel >= 1 then
                    aiBrain[refbPrioritiseExperimental] = true
                end
            end
        end


        if bDebugMessages == true then LOG(sFunctionRef..': Finished considering potential big threats. aiBrain[refbAreBigThreats]='..tostring(aiBrain[refbAreBigThreats])) end






        --[[bDebugMessages = true
        if bDebugMessages == true then LOG(repru(ScenarioInfo)) end bDebugMessages = false--]]



        if iCurCycleCount <= 0 then --runs once every 10 cycles (seconds)
            --Update list of nearby enemies if any are dead
            local bCheckBrains = true
            local iCurCount = 0
            local iMaxCount = 20

            while bCheckBrains == true do
                iCurCount = iCurCount + 1
                if iCurCount > iMaxCount then
                    M27Utilities.ErrorHandler('Infinite loop')
                    break
                end
                bCheckBrains = false
                for iArmyIndex, oBrain in tAllAIBrainsByArmyIndex do
                    if oBrain:IsDefeated() or oBrain.M27IsDefeated then
                        tAllAIBrainsByArmyIndex[iArmyIndex] = nil
                        bCheckBrains = true
                        break
                    end
                end
            end

            ForkThread(M27Team.UpdateTeamDataForEnemyUnits, aiBrain, true) --Currently updates number of wall units but could add other logic to this

            --Below should be updated as part of the SetWhetherCanPathToEnemy function in M27MapInfo now
            --[[local iNearestEnemyArmyIndex = M27Logic.GetNearestEnemyIndex(aiBrain)
            if not(iNearestEnemyArmyIndex == iPreviousNearestEnemyIndex) then
                aiBrain[refiDistanceToNearestEnemyBase] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[M27Logic.IndexToStartNumber(iNearestEnemyArmyIndex)])
                ForkThread(M27Logic.DetermineEnemyScoutSpeed, aiBrain)
            end
            iPreviousNearestEnemyIndex = iNearestEnemyArmyIndex--]]

            ForkThread(M27MapInfo.UpdateReclaimMarkers)

            ForkThread(M27AirOverseer.UpdateMexScoutingPriorities, aiBrain)

            SetMaximumFactoryLevels(aiBrain)

            --Consider if should update enemy start location
            ForkThread(M27MapInfo.UpdateNewPrimaryBaseLocation, aiBrain)

            ForkThread(CheckUnitCap, aiBrain)

            --Record the furthest 'high value' building we have (used to adjust bomber and land defence ranges)
            --Dont do via forked threat as rely on these numbers below
            UpdateFurthestBuildingDistances(aiBrain)






            --Info wanted for grand strategy

            --Check if we need to refresh our mass income
            local bTimeForLongRefresh = false
            local iCurTime = math.floor(GetGameTimeSeconds())
            --if iCurTime >= 913 then M27Utilities.bGlobalDebugOverride = true end --use this if e.g. come across a hard crash and want to figure out what's causing it; will cause every log to be enabled so will take a long time to just run 1s of game time
            if aiBrain[refiTimeOfLastMexIncomeCheck] == nil then
                bTimeForLongRefresh = true
            elseif iCurTime - aiBrain[refiTimeOfLastMexIncomeCheck] >= iLongTermMassIncomeChangeInterval then
                bTimeForLongRefresh = true
            end
            local iMassAtLeast3mAgo = aiBrain[reftiMexIncomePrevCheck][2]
            if iMassAtLeast3mAgo == nil then
                iMassAtLeast3mAgo = 0
            end
            if bTimeForLongRefresh == true then
                table.insert(aiBrain[reftiMexIncomePrevCheck], 1, aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome])
                aiBrain[refiTimeOfLastMexIncomeCheck] = iCurTime
            end


            --Values which want to know even if logs not enabled
            --Get unclaimed mex figures
            local oACU = M27Utilities.GetACU(aiBrain)
            local sPathing = M27UnitInfo.refPathingTypeAmphibious
            local iFaction = aiBrain:GetFactionIndex()

            if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == false and aiBrain[refiOurHighestLandFactoryTech] == 1 and not (iFaction == M27UnitInfo.refFactionSeraphim or iFaction == M27UnitInfo.refFactionAeon) then
                sPathing = M27UnitInfo.refPathingTypeLand
            end


            --GetSegmentGroupOfTarget(sPathing, iTargetSegmentX, iTargetSegmentZ)
            local iPathingGroup = M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            local iAllMexesInPathingGroup = 0
            if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing][iPathingGroup]) == false then
                iAllMexesInPathingGroup = table.getn(M27MapInfo.tMexByPathingAndGrouping[sPathing][iPathingGroup])
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iAllMexesInPathingGroup=' .. iAllMexesInPathingGroup .. '; full list of mexes for all pathing=' .. repru(M27MapInfo.tMexByPathingAndGrouping))
                end
            elseif bDebugMessages == true then
                M27Utilities.ErrorHandler('No mexes in our starting pathing group detected. iPathingGroup=' .. iPathingGroup .. '; sPathing=' .. sPathing)
            end
            local iAllUnclaimedMexesInPathingGroup = 0

            local tAllUnclaimedMexesInPathingGroup = M27EngineerOverseer.GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, false, false, true)
            if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInPathingGroup) == false then
                iAllUnclaimedMexesInPathingGroup = table.getn(tAllUnclaimedMexesInPathingGroup)
            end
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': About to get all mexes in pathing group that we havent claimed. iPathingGroup=' .. iPathingGroup)
            end
            --GetUnclaimedMexes(aiBrain, oPathingUnitBackup, sPathing, iPathingGroup, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
            local tAllMexesInPathingGroupWeHaventClaimed = M27EngineerOverseer.GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, true, false, true)
            local iAllMexesInPathingGroupWeHaventClaimed = 0
            if M27Utilities.IsTableEmpty(tAllMexesInPathingGroupWeHaventClaimed) == false then
                iAllMexesInPathingGroupWeHaventClaimed = table.getn(tAllMexesInPathingGroupWeHaventClaimed)
            end
            aiBrain[refiUnclaimedMexesInBasePathingGroup] = iAllMexesInPathingGroupWeHaventClaimed
            aiBrain[refiAllMexesInBasePathingGroup] = iAllMexesInPathingGroup


            local iOurTeamsShareOfMexesOnMap = iAllMexesInPathingGroup / aiBrain[refiTeamsWithSameAmphibiousPathingGroup]
            local iMexesInPathingGroupWeHaveClaimed = iAllMexesInPathingGroup - iAllMexesInPathingGroupWeHaventClaimed
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Pre determining grand strategy, iMexesInPathingGroupWeHaveClaimed=' .. iMexesInPathingGroupWeHaveClaimed .. '; iOurTeamsShareOfMexesOnMap=' .. iOurTeamsShareOfMexesOnMap .. '; iAllMexesInPathingGroupWeHaventClaimed=' .. iAllMexesInPathingGroupWeHaventClaimed)
            end

            local tLandCombatUnits = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryLandCombat, false, true)
            local iLandCombatUnits = 0
            if M27Utilities.IsTableEmpty(tLandCombatUnits) == false then
                iLandCombatUnits = table.getn(tLandCombatUnits)
            end



            --Our highest tech level
            UpdateHighestFactoryTechTracker(aiBrain)

            --Want below variables for both the game state table and to decide whether to eco:
            local iMexesNearStart = table.getn(M27MapInfo.tResourceNearStart[aiBrain.M27StartPositionNumber][1])
            local iT3Mexes = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex)
            local iT2Mexes = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Mex)
            --=========DECIDE ON GRAND STRATEGY
            --Get details on how close friendly units are to enemy
            --(Want to run below regardless as we use the distance to base for other logic)

            local tFriendlyLandCombat = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryLandCombat, false, true)
            --M27Utilities.GetNearestUnit(tUnits, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), aiBrain, false)
            local oNearestFriendlyUnitToEnemyBase = M27Utilities.GetNearestUnit(tFriendlyLandCombat, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), aiBrain, false)
            local tFurthestFriendlyPosition = { 'nil' }
            local iFurthestFriendlyDistToOurBase = 0
            local iFurthestFriendlyDistToEnemyBase = 0
            aiBrain[refiPercentageClosestFriendlyFromOurBaseToEnemy] = 0.5
            aiBrain[refiPercentageClosestFriendlyLandFromOurBaseToEnemy] = 0.5
            local tFriendlyLand = aiBrain:GetListOfUnits(categories.LAND + M27UnitInfo.refCategoryStructure - categories.BENIGN, false, true)
            if oNearestFriendlyUnitToEnemyBase then
                tFurthestFriendlyPosition = oNearestFriendlyUnitToEnemyBase:GetPosition()
                iFurthestFriendlyDistToOurBase = M27Utilities.GetDistanceBetweenPositions(tFurthestFriendlyPosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                iFurthestFriendlyDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tFurthestFriendlyPosition, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                aiBrain[refiPercentageClosestFriendlyFromOurBaseToEnemy] = iFurthestFriendlyDistToOurBase / (iFurthestFriendlyDistToOurBase + iFurthestFriendlyDistToEnemyBase)
            end
            if M27Utilities.IsTableEmpty(tFriendlyLand) == false then
                oNearestFriendlyUnitToEnemyBase = M27Utilities.GetNearestUnit(tFriendlyLand, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), aiBrain, false)
                if oNearestFriendlyUnitToEnemyBase then
                    tFurthestFriendlyPosition = oNearestFriendlyUnitToEnemyBase:GetPosition()
                    iFurthestFriendlyDistToOurBase = M27Utilities.GetDistanceBetweenPositions(tFurthestFriendlyPosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    iFurthestFriendlyDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tFurthestFriendlyPosition, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                    aiBrain[refiPercentageClosestFriendlyLandFromOurBaseToEnemy] = iFurthestFriendlyDistToOurBase / (iFurthestFriendlyDistToOurBase + iFurthestFriendlyDistToEnemyBase)
                end
            end


            --------------DETERMINE MAIN STRATEGY----------------------
            local iPrevStrategy = aiBrain[refiAIBrainCurrentStrategy]
            local bChokepointsAreProtected = M27Conditions.AreAllChokepointsCoveredByTeam(aiBrain)

            --Consider whether to adopt temporary turtle mode (meaning we will temporarily eco):
            local bTemporaryTurtleMode = false --If true then will try and eco even with nearby threats if think are behind on eco and have lots of PD/T2 arti and enemy has no big threats
            local iTemporaryTurtleDefenceRange --Limit defence range based on this

            --Only consider temporary turtle if we have a firebase, provided the firebase itself isnt too far from us (to avoid risk e.g. of inheriting ally base that contains firebase)
            if bDebugMessages == true then LOG(sFunctionRef..': About to check if we should temporarily turtle. Is table of firebases empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef]))..'; are there big threats='..tostring(aiBrain[refbAreBigThreats] or false)..'; GameTime='..GetGameTimeSeconds()..'; Nearest threat from start mod='..(aiBrain[refiModDistFromStartNearestThreat] or 'nil')..'; Mexes available for upgrade='..(aiBrain[M27EconomyOverseer.refiMexesAvailableForUpgrade] or 'nil')..'; Furthest valuable building mod dist='..(aiBrain[refiFurthestValuableBuildingModDist] or 'nil')..'; Enemy best mobile range='..(aiBrain[refiHighestMobileLandEnemyRange] or 'nil')..'; Is table of planned chokepoints empty='..tostring(M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27MapInfo.tiPlannedChokepointsByDistFromStart]))..'; Enemy highest tech level='..(aiBrain[refiEnemyHighestTechLevel] or 'nil')) end
            if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef]) == false then
                --Are we a non-chokepoint map, with enemies more than 80 from our base, and multiple mexes available to upgrade, and it's not the first 10m of the game (when we want to focus more on map control), and havent got to experimental stage of game yet?
                if GetGameTimeSeconds() >= 600 and aiBrain[M27EconomyOverseer.refiMexesAvailableForUpgrade] >= 2 and aiBrain[refiModDistFromStartNearestThreat] >= 80 and not(bChokepointsAreProtected) and M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27MapInfo.tiPlannedChokepointsByDistFromStart]) then
                    --If the enemy's closest unit had its best range, would it threaten our high value buildings?
                    if aiBrain[refiHighestMobileLandEnemyRange] + aiBrain[refiModDistFromStartNearestThreat] > aiBrain[refiFurthestValuableBuildingModDist] and aiBrain[refiEnemyHighestTechLevel] >= 2 then
                        --Does the enemy have any land experimentals that have been constructed? (dont need to worry about nuke launchers as we shouldnt be checking eco conditions/strategy to defend against them)
                        local bEnemyHasActiveLandExperimental = false
                        if M27Utilities.IsTableEmpty(aiBrain[reftEnemyLandExperimentals]) == false then
                            for iUnit, oUnit in aiBrain[reftEnemyLandExperimentals] do
                                if oUnit:GetFractionComplete() >= 0.95 then
                                    bEnemyHasActiveLandExperimental = true
                                    break
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Does enemy have active land experimental='..tostring(bEnemyHasActiveLandExperimental)) end
                        if not(bEnemyHasActiveLandExperimental) then
                            --Are at least 3 of the mexes near our start position at the same level as the enemy's highest factory level?
                            local iMexesOfDesiredTech = 0
                            if aiBrain[refiEnemyHighestTechLevel] >= 3 then iMexesOfDesiredTech = iT3Mexes
                            else iMexesOfDesiredTech = iT2Mexes + iT3Mexes
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': iMexesOfDesiredTech='..iMexesOfDesiredTech..'; iMexesNearStart='..iMexesNearStart) end
                            if iMexesOfDesiredTech < math.min(4, iMexesNearStart - 1) then

                                local iOverallDistanceCap = math.max(80, math.min(250, aiBrain[refiDistanceToNearestEnemyBase] * 0.4)) --Dont want to risk inheriting ally base containing firebase, and also dont want to assume firebase can cover valuable buildings the further we get from our base
                                if bDebugMessages == true then LOG(sFunctionRef..': Furthest valuable building actual dist='..aiBrain[refiFurthestValuableBuildingActualDist]..'; Overall distance cap='..iOverallDistanceCap) end
                                if aiBrain[refiFurthestValuableBuildingActualDist] <= iOverallDistanceCap then
                                    --Does our furthest firebase range suggest it will cover our most valuable building?
                                    local iFurthestFirebaseDist = 0
                                    local iFurthestFirebaseRef
                                    local iCurFirebaseDist
                                    --reftFirebasePosition = 'M27EngineerFirebasePosition' --aiBrain, [x] is the firebase unique count, returns midpoint of the firebase based on average of all units within it
                                    for iFirebaseRef, tFirebaseUnits in aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef] do
                                        if M27Utilities.IsTableEmpty(tFirebaseUnits) == false then
                                            iCurFirebaseDist = M27Utilities.GetDistanceBetweenPositions(aiBrain[M27EngineerOverseer.reftFirebasePosition][iFirebaseRef], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                            if iCurFirebaseDist > iFurthestFirebaseDist and iCurFirebaseDist <= iOverallDistanceCap then
                                                iFurthestFirebaseDist = iCurFirebaseDist
                                                iFurthestFirebaseRef = iFirebaseRef
                                            end
                                        end
                                    end
                                    if bDebugMessages == true then LOG(sFunctionRef..': Finished checking if we have a firebase and if so which firebase is furthest from us. iFurthestFirebaseRef='..(iFurthestFirebaseRef or 'nil')..'; iFurthestFirebaseDist='..(iFurthestFirebaseDist or 'nil')) end
                                    if iFurthestFirebaseRef and iFurthestFirebaseDist + 25 > aiBrain[refiFurthestValuableBuildingActualDist] then
                                        --Does the enemy have units that will soon be able to attack our firebase?
                                        local iNearestEnemyActualDist = M27Utilities.GetDistanceBetweenPositions(aiBrain[reftLocationFromStartNearestThreat], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                        if bDebugMessages == true then LOG(sFunctionRef..': iNearestEnemyActualDist='..(iNearestEnemyActualDist)..'; iFurthestFirebaseDist='..iFurthestFirebaseDist..'; aiBrain[refiHighestMobileLandEnemyRange]='..aiBrain[refiHighestMobileLandEnemyRange]) end
                                        if iFurthestFirebaseDist + aiBrain[refiHighestMobileLandEnemyRange] < iNearestEnemyActualDist then

                                            --We have a firebase that should be able to cover the nearest building and isnt under current attack; now consider the enemy threat within 50 of the nearest enemy unit

                                            local tNearbyEnemyMobileThreats = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat + M27UnitInfo.refCategoryIndirect, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iNearestEnemyActualDist + 50, 'Enemy')
                                            local iNearbyEnemyThreat = M27Logic.GetCombatThreatRating(aiBrain, tNearbyEnemyMobileThreats, false, nil, nil, false)
                                            local iFirebaseThreat = M27Logic.GetCombatThreatRating(aiBrain, aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef][iFurthestFirebaseRef], false, nil, nil, false)
                                            if bDebugMessages == true then LOG(sFunctionRef..': iFirebaseThreat='..iFirebaseThreat..'; iNearbyEnemyThreat='..iNearbyEnemyThreat) end
                                            if iFirebaseThreat > iNearbyEnemyThreat * 1.25 then
                                                --Should have enough threat to deal with enemy
                                                bTemporaryTurtleMode = true
                                                iTemporaryTurtleDefenceRange = iFurthestFirebaseDist + 45
                                                if bDebugMessages == true then LOG(sFunctionRef..': Will adopt temporary turtle mode, wiht iTemporaryTurtleDefenceRange='..iTemporaryTurtleDefenceRange) end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end


            --Are we in ACU kill mode and want to stay in it (determined b y ACU manager)?
            if aiBrain[refiAIBrainCurrentStrategy] == refStrategyACUKill and not (aiBrain[refbStopACUKillStrategy]) then
                --set as part of ACU manager
                --Stick with this strategy
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Are in ACU kill mode and dont want to stop so wont change strategy')
                end
            else
                if iPrevStrategy == refStrategyACUKill then
                    aiBrain[refiAIBrainCurrentStrategy] = aiBrain[refiDefaultStrategy]
                    if M27Utilities.GetACU(aiBrain).PlatoonHandle then
                        --We were trying to kill their ACU but aren't now - replace ACU's current movement destination with a new one
                        ForkThread(M27PlatoonUtilities.GetNewMovementPath, M27Utilities.GetACU(aiBrain).PlatoonHandle, true)
                    end
                    M27Chat.SendMessage(aiBrain, 'No longer attacking ACU', 'Im giving up on attacking their ACU for now', 0, 150, true)
                end

                --Should we be in air dominance mode?
                local bWantAirDominance = false
                --Have we recently scouted the enemy base?
                local iBaseScoutingTime = 30
                local iEnemyGroundAAFactor = 0.1
                if aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance then
                    iBaseScoutingTime = aiBrain[M27AirOverseer.refiIntervalEnemyBase] + 60
                    iEnemyGroundAAFactor = 0.2
                end
                --Tripple groundAA needed if we have strats and enemy doesnt have AirAA
                if not(aiBrain[M27AirOverseer.refbEnemyHasHadCruisersOrT3AA]) and aiBrain[refiOurHighestAirFactoryTech] >= 3 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryBomber * categories.TECH3) >= 2 then
                    iEnemyGroundAAFactor = iEnemyGroundAAFactor * 2
                end
                --local iAirSegmentX, iAirSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                local bEnemyHasEnoughAA = false
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iBaseScoutingTime=' .. iBaseScoutingTime .. '; CurTime=' .. GetGameTimeSeconds() .. '; Time last scouted enemy base=' .. M27AirOverseer.GetTimeSinceLastScoutedLocation(aiBrain, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)))
                end
                if math.max(iBaseScoutingTime + 30 - GetGameTimeSeconds(),0) + M27AirOverseer.GetTimeSinceLastScoutedLocation(aiBrain, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) <= iBaseScoutingTime or M27Logic.GetIntelCoverageOfPosition(aiBrain, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), 30, true) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Time since last scouted enemy base=' .. M27AirOverseer.GetTimeSinceLastScoutedLocation(aiBrain, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) .. '; Scouting interval=' .. iBaseScoutingTime .. '; intel coverage='..M27Logic.GetIntelCoverageOfPosition(aiBrain, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), nil, true)..'; therefore considering whether to switch to air dominance')
                    end
                    --Have we either had no bombers die, or the last bomber was effective?
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Is table of bomber effectiveness empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.refbBombersAreEffective])) .. '; Effectiveness of our highest air factory tech=' .. tostring(aiBrain[M27AirOverseer.refbBombersAreEffective][aiBrain[refiOurHighestAirFactoryTech]] or false))
                    end
                    if not (aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance) and (M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.refbBombersAreEffective]) == true or aiBrain[M27AirOverseer.refbBombersAreEffective][aiBrain[refiOurHighestAirFactoryTech]] == false) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Bombers have been ineffective at our current tech level so wont try air dominance')
                        end
                        bEnemyHasEnoughAA = true
                    else
                        if GetGameTimeSeconds() <= 360 then
                            --first 6m of game - do they have any air at all?
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Enemy highest air threat=' .. (aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] or 'nil'))
                            end
                            if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] > 0 then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Enemy has air units so as early in game dont want air dominance')
                                end
                                bEnemyHasEnoughAA = true
                            end
                        else
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Enemy ever air AA threat=' .. aiBrain[M27AirOverseer.refiHighestEverEnemyAirAAThreat]..'; Cur airaa threat='..aiBrain[M27AirOverseer.refiEnemyAirAAThreat] .. '; our air threat=' .. aiBrain[M27AirOverseer.refiOurMassInAirAA]..'; have air control='..tostring(aiBrain[M27AirOverseer.refbHaveAirControl]))
                            end
                            if aiBrain[M27AirOverseer.refiHighestEverEnemyAirAAThreat] / 0.9 > aiBrain[M27AirOverseer.refiOurMassInAirAA] and not(aiBrain[M27AirOverseer.refbHaveAirControl] and aiBrain[M27AirOverseer.refiHighestEverEnemyAirAAThreat] <= 3000 and aiBrain[M27AirOverseer.refiEnemyAirAAThreat] / 0.7 < aiBrain[M27AirOverseer.refiOurMassInAirAA]) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Dont want to go for air dominance due to enemy highest ever air threat being >90% of ours')
                                end
                                bEnemyHasEnoughAA = true
                            elseif not (aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance) and aiBrain[M27AirOverseer.refiAirAANeeded] > 0 and (aiBrain[M27AirOverseer.refiAirAANeeded] >= 5 or not(aiBrain[M27AirOverseer.refbHaveAirControl]) or aiBrain[M27AirOverseer.refiHighestEverEnemyAirAAThreat] / 0.9 > aiBrain[M27AirOverseer.refiOurMassInAirAA] or aiBrain[M27AirOverseer.refiEnemyAirAAThreat] / 0.7 > aiBrain[M27AirOverseer.refiOurMassInAirAA]) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Dont want air dominance as still need airAA, aiBrain[M27AirOverseer.refiAirAANeeded]='..aiBrain[M27AirOverseer.refiAirAANeeded])
                                end
                                bEnemyHasEnoughAA = true
                            end
                        end
                        if bEnemyHasEnoughAA == false then
                            --Do we have bombers?
                            local tBombers = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryBomber, false, true)
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Enemy doesnt have enough AA, will check we have some bombers alive')
                            end
                            if M27Utilities.IsTableEmpty(tBombers) == true and M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableGunships]) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': We dont have any bombers, so dont switch to air dominance yet')
                                end
                                bEnemyHasEnoughAA = true
                            else
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Enemy mass in ground AA=' .. (aiBrain[M27AirOverseer.refiEnemyMassInGroundAA] or 'nil') .. '; table size of bombers=' .. table.getn(tBombers) .. '; Threat of bombers=' .. M27Logic.GetAirThreatLevel(aiBrain, tBombers, false, false, false, true, false, nil, nil, nil, nil, false))
                                end
                                --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride, bIncludeAirTorpedo)
                                if aiBrain[M27AirOverseer.refiEnemyMassInGroundAA] > 0 and aiBrain[M27AirOverseer.refiEnemyMassInGroundAA] * 10 > (M27Logic.GetAirThreatLevel(aiBrain, tBombers, false, false, false, true, false, nil, nil, nil, nil, false) + M27Logic.GetAirThreatLevel(aiBrain, aiBrain[M27AirOverseer.reftAvailableGunships], false, false, false, true, false, nil, nil, nil, nil, false)) then
                                    --Further override - if have 3+ strats, and enemy has no cruisers or T3+ AA, then do air dom mode
                                    bEnemyHasEnoughAA = true
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': aiBrain[M27AirOverseer.refiPreviousAvailableBombers=' .. aiBrain[M27AirOverseer.refiPreviousAvailableBombers] .. '; M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableBombers]=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableBombers])) .. '; size of tBombers=' .. table.getn(tBombers))
                                    end
                                    if aiBrain[refiOurHighestAirFactoryTech] >= 3 and aiBrain[M27AirOverseer.refiEnemyMassInGroundAA] <= 6000 and aiBrain[M27AirOverseer.refiPreviousAvailableBombers] >= 3 and M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableBombers]) == false then
                                        local tT3PlusBombers = EntityCategoryFilterDown(categories.TECH3 + categories.EXPERIMENTAL, tBombers)
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Is table of T3PlusBombers empty=' .. tostring(M27Utilities.IsTableEmpty(tT3PlusBombers)) .. '; refiPreviousAvailableBombers=' .. aiBrain[M27AirOverseer.refiPreviousAvailableBombers] .. '; Availalbe bombers empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableBombers])))
                                        end
                                        if M27Utilities.IsTableEmpty(tT3PlusBombers) == false and table.getn(tT3PlusBombers) >= 2 then
                                            local tEnemyT3PlusAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryCruiserCarrier + M27UnitInfo.refCategoryGroundAA * categories.TECH3, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiDistanceToNearestEnemyBase] + 40, 'Enemy')
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Is table of Enemy T3PlusAA empty=' .. tostring(M27Utilities.IsTableEmpty(tEnemyT3PlusAA)))
                                            end
                                            if M27Utilities.IsTableEmpty(tEnemyT3PlusAA) then
                                                bEnemyHasEnoughAA = false
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                else
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Havent scouted enemy base recently so assuming they have some AA there. Intel coverage='..M27Logic.GetIntelCoverageOfPosition(aiBrain, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), nil, true))
                    end
                    bEnemyHasEnoughAA = true
                end

                if bEnemyHasEnoughAA == false then
                    --Does enemy have ground AA that is shielded?
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Enemy doesnt have enough AA, checking if they have any AA that is under fixed shields. aiBrain[refiOurHighestAirFactoryTech]=' .. aiBrain[refiOurHighestAirFactoryTech])
                    end
                    local tEnemyFixedShields = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedShield, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27AirOverseer.refiMaxScoutRadius], 'Enemy')
                    local bHaveAAUnderShield = false
                    local iAACategoryToSearchFor
                    if aiBrain[refiOurHighestAirFactoryTech] >= 3 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryBomber * categories.TECH3) >= 2 then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Have at least 2 T3 bombers so will search only for T3 AA and cruisers')
                        end
                        iAACategoryToSearchFor = M27UnitInfo.refCategoryGroundAA * categories.TECH3 + M27UnitInfo.refCategoryCruiserCarrier
                    else
                        iAACategoryToSearchFor = M27UnitInfo.refCategoryGroundAA + M27UnitInfo.refCategoryCruiserCarrier
                    end
                    if M27Utilities.IsTableEmpty(tEnemyFixedShields) == false then
                        local tNearbyGroundAA, iShieldRadius
                        for iShield, oShield in tEnemyFixedShields do
                            if M27UnitInfo.IsUnitValid(oShield) then
                                tNearbyGroundAA = aiBrain:GetUnitsAroundPoint(iAACategoryToSearchFor, oShield:GetPosition(), oShield:GetBlueprint().Defense.Shield.ShieldSize * 0.5 + 1, 'Enemy')
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
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': bHaveAAUnderShield=' .. tostring(bHaveAAUnderShield))
                    end
                    if bHaveAAUnderShield == false then
                        bWantAirDominance = true
                    end
                elseif bDebugMessages == true then
                    LOG(sFunctionRef .. ': Enemy has enough AA or we have too few bombers so wont switch to air dominance')
                end

                if bWantAirDominance == true then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Setting strategy as air dominance')
                    end
                    aiBrain[refiAIBrainCurrentStrategy] = refStrategyAirDominance
                    M27Chat.SendMessage(aiBrain, 'Air domination', 'Im going to try and win with bombers', 0, 150, true)
                else
                    if aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance then
                        M27Chat.SendMessage(aiBrain, 'Not Air domination', 'Nevermind, they have too much AA now so Im reducing the bomber attacks', 0, 150, true)
                    end
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Dont want air dom strategy so will consider alternatives')
                    end
                    --Are we protecting the ACU? If so then stay in this mode unless we think ACU is safe
                    local bKeepProtectingACU = false
                    if aiBrain[refiAIBrainCurrentStrategy] == refStrategyProtectACU then
                        bKeepProtectingACU = true
                        local oACU = M27Utilities.GetACU(aiBrain)
                        if M27Utilities.IsACU(oACU) == false then
                            bKeepProtectingACU = false
                        else
                            --Stop protecting ACU if it has gun upgrade and ok health, or isnt upgrading and has good health, or is near our base
                            bKeepProtectingACU = not (M27Conditions.CanWeStopProtectingACU(aiBrain, oACU))
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': In protect ACU mode, bKeepProtectingACU=' .. tostring(bKeepProtectingACU))
                            end
                        end
                    end

                    --Should we switch to eco?
                    if not(aiBrain[M27Logic.refbAllEnemiesDead]) then
                        if M27MapInfo.bNoRushActive and M27MapInfo.iNoRushTimer - GetGameTimeSeconds() >= 60 then
                            aiBrain[refiAIBrainCurrentStrategy] = refStrategyEcoAndTech
                        else
                            if bKeepProtectingACU == false then
                                if aiBrain[refiDefaultStrategy] == refStrategyTurtle then
                                    aiBrain[refiAIBrainCurrentStrategy] = refStrategyTurtle
                                else


                                    -------LAND RUSH LOGIC-----------------------------------
                                    --Land rush strategy override
                                    if aiBrain[refiDefaultStrategy] == refStrategyLandRush then
                                        --Do we still want to land rush?
                                        local bCancelLandRush = false
                                        if GetGameTimeSeconds() >= 840 then --Wont consider after minute 14
                                            bCancelLandRush = true
                                        else
                                            if aiBrain[refiEnemyHighestTechLevel] >= 3 or aiBrain[refiOurHighestFactoryTechLevel] >= 3 or aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 6 then
                                                bCancelLandRush = true
                                                if bDebugMessages == true then LOG(sFunctionRef..': Either we have at least 6 mass income or enemy or us have t3. aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome]='..aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome]..'; aiBrain[refiEnemyHighestTechLevel]='..aiBrain[refiEnemyHighestTechLevel]..'; aiBrain[refiOurHighestFactoryTechLevel]='..aiBrain[refiOurHighestFactoryTechLevel]) end
                                            elseif aiBrain[refiEnemyHighestTechLevel] == 2 then
                                                --Does enemy have at least 1 T2 PD, or >=5 T2 land combat units, or a nearby ACU with T2 upgrade?
                                                local tEnemyPD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2PlusPD, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27AirOverseer.refiMaxScoutRadius], 'Enemy')
                                                if M27Utilities.IsTableEmpty(tEnemyPD) == false then
                                                    bCancelLandRush = true
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Is tEnemyPD empty='..tostring(M27Utilities.IsTableEmpty(tEnemyPD))) end
                                                else
                                                    local tEnemyT2Combat = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27AirOverseer.refiMaxScoutRadius], 'Enemy')
                                                    if M27Utilities.IsTableEmpty(tEnemyT2Combat) == false and table.getn(tEnemyT2Combat) >= 5 then
                                                        bCancelLandRush = true
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy has '..table.getn(tEnemyT2Combat)..' T2 combat units so will cancel land rush mode') end
                                                    elseif M27UnitInfo.IsUnitValid(aiBrain[refoLastNearestACU]) and aiBrain[refoLastNearestACU]:HasEnhancement('AdvancedEngineering') and aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 1 and M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.refoLastNearestACU]:GetPosition()) <= 325 then
                                                        bCancelLandRush = true
                                                    end
                                                end
                                            end
                                        end
                                        if bDebugMessages == true then LOG(sFunctionRef..': bCancelLandRush='..tostring(bCancelLandRush)..'; Time='..GetGameTimeSeconds()..'; Enemy highest tech level='..aiBrain[refiEnemyHighestTechLevel]) end
                                        if bCancelLandRush then
                                            aiBrain[refiDefaultStrategy] = refStrategyLandMain
                                            aiBrain[refiAIBrainCurrentStrategy] = refStrategyLandMain --will be updated further on
                                        else
                                            aiBrain[refiAIBrainCurrentStrategy] = refStrategyLandRush
                                        end
                                    end

                                    if not(aiBrain[refiDefaultStrategy] == refStrategyLandRush) then
                                        --Consider alternatives


                                        local bWantToEco = false
                                        --Dont eco if nearby naval threat
                                        if not(aiBrain[refbT2NavyNearOurBase]) then



                                            --How far away is the enemy?
                                            local bBigEnemyThreat = false
                                            if M27Utilities.IsTableEmpty(aiBrain[reftEnemyLandExperimentals]) == false or M27Utilities.IsTableEmpty(aiBrain[reftEnemyArtiAndExpStructure]) == false then
                                                bBigEnemyThreat = true
                                            end
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. 'Not protecting ACU, seeing whether to eco; bBigEnemyTHreat=' .. tostring(bBigEnemyThreat or false) .. '; aiBrain[refbEnemyACUNearOurs]=' .. tostring(aiBrain[refbEnemyACUNearOurs] or false)..'; ACU health 1s ago='..(oACU[reftACURecentHealth][math.floor(GetGameTimeSeconds()) - 1] or 'nil')..'; ACU health 11s ago='..(oACU[reftACURecentHealth][math.floor(GetGameTimeSeconds()) - 11] or 'nil')..'; Are all chokepoitns covered='..tostring((M27Conditions.AreAllChokepointsCoveredByTeam(aiBrain)) or false))
                                            end




                                            --Do we have teammates who are all closer to the nearest enemy than us?
                                            local bAlliesAreCloserToEnemy = false
                                            if M27Utilities.IsTableEmpty(aiBrain[toAllyBrains]) == false then
                                                local tEnemyBase = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
                                                for iBrain, oBrain in aiBrain[toAllyBrains] do
                                                    if M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber], tEnemyBase) + 50 < aiBrain[refiDistanceToNearestEnemyBase] then
                                                        bAlliesAreCloserToEnemy = true
                                                        break
                                                    end
                                                end
                                            end



                                            --Dont eco if enemy ACU near ours as likely will need backup, unless we are on a chokepoint map and our ACU hasnt taken any damage recently (or if it has, it's less than 5 per sec)
                                            if bDebugMessages == true then LOG(sFunctionRef..': Start of logic for checking if should eco. aiBrain[refbEnemyACUNearOurs]='..tostring((aiBrain[refbEnemyACUNearOurs] or false))..'; bChokepointsAreProtected='..tostring((bChokepointsAreProtected or false))..'; Our ACU health='..(M27Utilities.GetACU(aiBrain):GetHealth() or 'nil')..'; M27UnitInfo.GetUnitHealthPercent(oACU)='..(M27UnitInfo.GetUnitHealthPercent(oACU) or 'nil')..'; ACU most recent recorded health='..((oACU[reftACURecentHealth][math.floor(GetGameTimeSeconds()) - 1] or oACU[reftACURecentHealth][math.floor(GetGameTimeSeconds()) - 2] or oACU[reftACURecentHealth][math.floor(GetGameTimeSeconds()) - 3] or 0) + 50)..'; ACU health 11s ago='..(oACU[reftACURecentHealth][math.floor(GetGameTimeSeconds()) - 11] or 'nil')..'; bAlliesAreCloserToEnemy='..tostring(bAlliesAreCloserToEnemy or false)..'; bTemporaryTurtleMode='..tostring(bTemporaryTurtleMode or false)) end
                                            if aiBrain[refbEnemyACUNearOurs] == false or (bChokepointsAreProtected and M27Utilities.GetACU(aiBrain):GetHealth() >= 7000 and (M27UnitInfo.GetUnitHealthPercent(oACU) >= 0.8 or (oACU[reftACURecentHealth][math.floor(GetGameTimeSeconds()) - 1] or oACU[reftACURecentHealth][math.floor(GetGameTimeSeconds()) - 2] or oACU[reftACURecentHealth][math.floor(GetGameTimeSeconds()) - 3] or 0) + 50 >= oACU[reftACURecentHealth][math.floor(GetGameTimeSeconds()) - 11]))  then
                                                if bChokepointsAreProtected then
                                                    bWantToEco = true
                                                elseif bAlliesAreCloserToEnemy then
                                                    bWantToEco = true
                                                elseif bTemporaryTurtleMode then
                                                    bWantToEco = true
                                                else
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Considering mex control and if have lots of mass to use. Mexes available for upgrade='..(aiBrain[M27EconomyOverseer.refiMexesAvailableForUpgrade] or 'nil')..'; Stored mass%='..aiBrain:GetEconomyStoredRatio('MASS')..'; Stored mass val='..aiBrain:GetEconomyStored('MASS')) end
                                                    if aiBrain[M27EconomyOverseer.refiMexesAvailableForUpgrade] > 0 and aiBrain:GetEconomyStoredRatio('MASS') < 0.9 and aiBrain:GetEconomyStored('MASS') < 12000 then
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Considering enemy threat. Percentage outstanding threat='..aiBrain[refiPercentageOutstandingThreat]..'; bBigEnemyThreat='..tostring(bBigEnemyThreat or false)..'; aiBrain[refiModDistFromStartNearestThreat]='..aiBrain[refiModDistFromStartNearestThreat]..'; aiBrain[refiDistanceToNearestEnemyBase]='..aiBrain[refiDistanceToNearestEnemyBase]..'; iMexesInPathingGroupWeHaveClaimed='..iMexesInPathingGroupWeHaveClaimed..'; iOurTeamsShareOfMexesOnMap='..iOurTeamsShareOfMexesOnMap..'; iDistanceToEnemyEcoThreshold='..iDistanceToEnemyEcoThreshold..'; iT3Mexes='..iT3Mexes..'; aiBrain[refiOurHighestFactoryTechLevel]='..aiBrain[refiOurHighestFactoryTechLevel]) end
                                                        if aiBrain[refiPercentageOutstandingThreat] > 0.55 and (bBigEnemyThreat == false or aiBrain[refiModDistFromStartNearestThreat] >= aiBrain[refiDistanceToNearestEnemyBase] * 0.5) and (iMexesInPathingGroupWeHaveClaimed >= iOurTeamsShareOfMexesOnMap * 0.8 or aiBrain[refiDistanceToNearestEnemyBase] >= iDistanceToEnemyEcoThreshold) and not (iT3Mexes >= math.min(iMexesNearStart, 7) and aiBrain[refiOurHighestFactoryTechLevel] >= 3) then
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': No big enemy threats and good defence and mex coverage so will eco')
                                                            end
                                                            bWantToEco = true
                                                        else
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': Dont want to eco based on initial tests. Still eco if havent increased mass income for a while unless nearby threat. aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome]='..aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome]..'; iMassAtLeast3mAgo='..iMassAtLeast3mAgo..'; aiBrain[refiPercentageOutstandingThreat]='..aiBrain[refiPercentageOutstandingThreat]..'; iLandCombatUnits='..iLandCombatUnits)
                                                            end
                                                            --Has our mass income not changed recently, but we dont appear to be losing significantly on the battlefield?
                                                            if iCurTime > 100 and aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] - iMassAtLeast3mAgo < 1 and aiBrain[refiPercentageOutstandingThreat] > 0.55 and iLandCombatUnits >= 30 then
                                                                if bDebugMessages == true then
                                                                    LOG(sFunctionRef .. ': Ok defence coverage and income not changed in a while so will eco')
                                                                end
                                                                bWantToEco = true
                                                            else
                                                                if bDebugMessages == true then
                                                                    LOG(sFunctionRef .. ': Checking if we are making use of tanks - if not then will switch to eco if have a decent number of tanks. aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons]=' .. tostring(aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons]))
                                                                end
                                                                if aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons] == false then
                                                                    --Are sending tanks into an attacknearest platoon so want to eco if we have a significant number of tanks, unless enemy has a big threat
                                                                    local iMinTanksWanted = math.max(8, 2 * (iAllMexesInPathingGroupWeHaventClaimed - iAllMexesInPathingGroup * 0.6))
                                                                    if bDebugMessages == true then
                                                                        LOG(sFunctionRef .. ': iMinTanksWanted=' .. iMinTanksWanted .. '; iLandCombatUnits=' .. iLandCombatUnits)
                                                                    end
                                                                    if iLandCombatUnits >= iMinTanksWanted and aiBrain[refiOurHighestFactoryTechLevel] <= 2 and aiBrain[refiModDistFromStartNearestThreat] > aiBrain[refiDistanceToNearestEnemyBase] * 0.4 and aiBrain[refiPercentageOutstandingThreat] > 0.5 then
                                                                        if bDebugMessages == true then
                                                                            LOG(sFunctionRef .. ': Dont have tech 3 and/or have 2 combat land units for each unclaimed mex on our side of the map with no big threats and not making use of land factories so will eco')
                                                                        end
                                                                        bWantToEco = true
                                                                    end
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                            --Eco even if enemy has big threats if we cant path to enemy base with amphibious and we have all mexes in our pathing group
                                            if bDebugMessages == true then LOG(sFunctionRef..': Might still eco if cant get to enemy with land and have control of our island or have protected chokepoints. aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]='..tostring(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious])..'; aiBrain[refiModDistFromStartNearestThreat]='..aiBrain[refiModDistFromStartNearestThreat]..'; bChokepointsAreProtected='..tostring(bChokepointsAreProtected or false)) end
                                            if not (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]) and iAllMexesInPathingGroupWeHaventClaimed == 0 and aiBrain[refiModDistFromStartNearestThreat] >= aiBrain[refiDistanceToNearestEnemyBase] * 0.3 then
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Want to eco as we cant reach enemy base except by air and we have all mexes in our pathing group')
                                                end
                                                bWantToEco = true
                                            end

                                            if bChokepointsAreProtected then
                                                --Eco if chokepoint is fine, unless enemies are nearby
                                                if bDebugMessages == true then LOG(sFunctionRef..': CHokepoitns are protected, will eco unless mod dist is too close. Mod dist of nearest threat='..aiBrain[refiModDistFromStartNearestThreat]..'; Dist threshold='..math.min(150, aiBrain[refiDistanceToNearestEnemyBase] * 0.35)) end
                                                if aiBrain[refiModDistFromStartNearestThreat] >= math.min(150, aiBrain[refiDistanceToNearestEnemyBase] * 0.35) then
                                                    bWantToEco = true
                                                end
                                            end

                                            --Eco if enemy has T3 arti/novax and we dont have all t3 mexes at our base and have low mass and units that need shielding (as we may not have the mass needed to shield/defend against the arti)
                                            if not(bWantToEco) and aiBrain[refbDefendAgainstArti] and math.min(aiBrain[M27EconomyOverseer.refiMexPointsNearBase], 6) > aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex) and M27Conditions.HaveLowMass(aiBrain) and aiBrain[refiModDistFromStartNearestThreat] >= math.min(150, aiBrain[refiDistanceToNearestEnemyBase] * 0.35) then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Want to defend against arti but we dont have good eco so will try and improve eco to support things like shields') end
                                                bWantToEco = true
                                            end


                                            if bDebugMessages == true then LOG(sFunctionRef..': Do we want to eco based on initial logic (will change this to false in a moment in certain cases)='..tostring(bWantToEco)) end
                                            if bWantToEco == true then
                                                if not (bChokepointsAreProtected) and not(bAlliesAreCloserToEnemy) and not(bTemporaryTurtleMode) and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == true and aiBrain[refiPercentageClosestFriendlyFromOurBaseToEnemy] < 0.4 then
                                                    bWantToEco = false
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Chokepoints arent protected, can path to enemy base with land, and dont have friendly units on enemy side of map') end
                                                    --Dont eco if enemy has AA structure within our bomber emergency range, as will likely want ground units to push them out
                                                elseif aiBrain[M27AirOverseer.refbBomberDefenceRestrictedByAA] and ((not(bChokepointsAreProtected) and not(bTemporaryTurtleMode)) or (aiBrain[refiModDistFromStartNearestThreat] <= aiBrain[M27AirOverseer.refiBomberDefenceCriticalThreatDistance] and M27UnitInfo.IsUnitValid(aiBrain[refoNearestThreat]) and M27Utilities.GetDistanceBetweenPositions(aiBrain[refoNearestThreat]:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= math.max(math.min(150, iTemporaryTurtleDefenceRange or 150), aiBrain[M27AirOverseer.refiBomberDefenceCriticalThreatDistance]))) then
                                                    bWantToEco = false
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Bomber defence restricted by AA so will stop ecoing. aiBrain[M27AirOverseer.refiBomberDefenceCriticalThreatDistance]='..aiBrain[M27AirOverseer.refiBomberDefenceCriticalThreatDistance]..'; Bomber def range='..aiBrain[M27AirOverseer.refiBomberDefenceModDistance]) end
                                                    --Check in case ACU health is low or we dont have any units near enemy (which might be why we think there's no enemy threat)
                                                elseif M27UnitInfo.GetUnitHealthPercent(oACU) < 0.45 and (M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) >= 125 or (oACU.PlatoonHandle[M27PlatoonUtilities.refiEnemiesInRange] > 0 and not(bTemporaryTurtleMode))) then
                                                    bWantToEco = false
                                                    if bDebugMessages == true then LOG(sFunctionRef..': ACU is low health and has nearby enemies so wont eco') end
                                                    --•	Don’t eco if our ACU is within 60 of the enemy base (on the expectation the game will be over soon if it is), unless the enemy has at least 4 T2 PD and 1 T2 Arti.
                                                elseif M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]) <= 80 then
                                                    bWantToEco = false
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Our ACU is near enemy base') end
                                                elseif not(bChokepointsAreProtected) and not(bAlliesAreCloserToEnemy) and not(bTemporaryTurtleMode) and aiBrain[refiTotalEnemyShortRangeThreat] >= 2500 and iMexesInPathingGroupWeHaveClaimed < iOurTeamsShareOfMexesOnMap * 1.3 and not(aiBrain[refbNeedIndirect]) then
                                                    --Does the enemy have more mobile threat than us and our allies, and we have < 65% mex control, and have gained income recently
                                                    if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] - iMassAtLeast3mAgo >= 1 then
                                                        local iSearchRange = math.min(600, aiBrain[refiDistanceToNearestEnemyBase] + 60, aiBrain[M27AirOverseer.refiMaxScoutRadius])
                                                        local tAllThreatUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryShortRangeMobile, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iSearchRange, 'Ally')

                                                        --For performance reasons will just get mass cost total
                                                        local iCurMassTotal = 0
                                                        if M27Utilities.IsTableEmpty(tAllThreatUnits) == false then
                                                            for iUnit, oUnit in tAllThreatUnits do
                                                                iCurMassTotal = iCurMassTotal + oUnit:GetBlueprint().Economy.BuildCostMass
                                                            end
                                                        end
                                                        if iCurMassTotal < aiBrain[refiTotalEnemyShortRangeThreat] then
                                                            bWantToEco = false
                                                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy has significant mobile threat and we are behind on eco and have just gained some eco, so want to try and build more units to regain map control') end
                                                        end
                                                        if bDebugMessages == true then LOG(sFunctionRef..': iCurMassTotal of our and ally shortrange threat='..iCurMassTotal..'; Enemy short range threat='..aiBrain[refiTotalEnemyShortRangeThreat]..'; bWantToEco='..tostring(bWantToEco)) end
                                                    end

                                                end
                                            end
                                        end
                                        if bDebugMessages == true then LOG(sFunctionRef..': Do we want to eco (end of decision)='..tostring(bWantToEco)) end

                                        if bWantToEco == true then
                                            aiBrain[M27FactoryOverseer.refiLastPriorityCategoryToBuild] = nil
                                            aiBrain[refiAIBrainCurrentStrategy] = refStrategyEcoAndTech
                                        else
                                            aiBrain[M27FactoryOverseer.refiLastPriorityCategoryToBuild] = M27UnitInfo.refCategoryDFTank
                                            if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == false then
                                                if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] == true then
                                                    aiBrain[M27FactoryOverseer.refiLastPriorityCategoryToBuild] = M27UnitInfo.refCategoryAmphibiousCombat
                                                else
                                                    aiBrain[refiAIBrainCurrentStrategy] = M27UnitInfo.refCategoryEngineer
                                                end
                                            end
                                            aiBrain[refiAIBrainCurrentStrategy] = aiBrain[refiDefaultStrategy]
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            --Abort plan to try and hold chokepoitns if we no longer have them covered after a significant amount of time
            if not(bChokepointsAreProtected) and aiBrain[refiDefaultStrategy] == refStrategyTurtle then
                --Is it late enough that we should abort?
                if GetGameTimeSeconds() >= 660 or (aiBrain[refiOurHighestFactoryTechLevel] >= 3 and aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 4 and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] >= 250) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Will give up on holding chokepoint') end
                    for iBrain, oBrain in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] do
                        if oBrain[refiDefaultStrategy] == refStrategyTurtle then
                            oBrain[refiDefaultStrategy] = refStrategyLandMain
                            if bDebugMessages == true then LOG(sFunctionRef..': Changed default strategy to land main for brain '..oBrain.Nickname) end
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
            if aiBrain[refiAIBrainCurrentStrategy] == refStrategyEcoAndTech then
                if bChokepointsAreProtected then
                    aiBrain[refiMaxDefenceCoveragePercentWanted] = math.min(0.65, (30 + GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, aiBrain[M27MapInfo.reftClosestChokepoint]) / aiBrain[refiDistanceToNearestEnemyBase]))
                    if bDebugMessages == true then LOG(sFunctionRef..': Have chokepoint and are ecoing so will set defence coverage to '..aiBrain[refiMaxDefenceCoveragePercentWanted]) end
                else
                    aiBrain[refiMaxDefenceCoveragePercentWanted] = 0.65
                end
            elseif aiBrain[refiAIBrainCurrentStrategy] == refStrategyAirDominance then
                aiBrain[refiMaxDefenceCoveragePercentWanted] = 0.4
            elseif aiBrain[refiAIBrainCurrentStrategy] == refStrategyTurtle then
                aiBrain[refiMaxDefenceCoveragePercentWanted] = (30 + M27Utilities.GetDistanceBetweenPositions(aiBrain[M27MapInfo.reftChokepointBuildLocation], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) / aiBrain[refiDistanceToNearestEnemyBase]
            else
                aiBrain[refiMaxDefenceCoveragePercentWanted] = 0.9
            end
            --Reduce defence coverage if are temporarily turtling
            if bTemporaryTurtleMode then aiBrain[refiMaxDefenceCoveragePercentWanted] = math.min(aiBrain[refiMaxDefenceCoveragePercentWanted], (iTemporaryTurtleDefenceRange / aiBrain[refiDistanceToNearestEnemyBase] or aiBrain[refiMaxDefenceCoveragePercentWanted])) end


            --Reduce air scouting threshold for enemy base if likely to be considering whether to build a nuke or not
            if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 7 and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] >= 250 and aiBrain[refiOurHighestFactoryTechLevel] >= 3 and (not (aiBrain[M27EngineerOverseer.refiLastExperimentalReference]) or aiBrain[M27EngineerOverseer.refiLastExperimentalReference] == M27EngineerOverseer.refiExperimentalNuke) then
                local iAirSegmentX, iAirSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                aiBrain[M27AirOverseer.reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][M27AirOverseer.refiCurrentScoutingInterval] = math.min(45, aiBrain[M27AirOverseer.reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][M27AirOverseer.refiCurrentScoutingInterval])
            end

            --Record highest threat values of certain types of units
            local tiCategoriesWanted = { [refiTotalEnemyLongRangeThreat] = M27UnitInfo.refCategoryLongRangeMobile, [refiTotalEnemyShortRangeThreat] = M27UnitInfo.refCategoryShortRangeMobile }
            --local tsThreatVariableRef = {refiTotalEnemyLongRangeThreat, refiTotalEnemyShortRangeThreat}
            local tAllThreatUnits
            local iCurMassTotal
            local iSearchRange = math.min(600, aiBrain[refiDistanceToNearestEnemyBase] + 60, aiBrain[M27AirOverseer.refiMaxScoutRadius])
            for sThreatVariableRef, iCategory in tiCategoriesWanted do
                tAllThreatUnits = aiBrain:GetUnitsAroundPoint(iCategory, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iSearchRange, 'Enemy')
                --For performance reasons will just get mass cost total
                iCurMassTotal = 0
                if M27Utilities.IsTableEmpty(tAllThreatUnits) == false then
                    for iUnit, oUnit in tAllThreatUnits do
                        if EntityCategoryContains(categories.COMMAND, oUnit.UnitId) then
                            iCurMassTotal = iCurMassTotal + M27Logic.GetCombatThreatRating(aiBrain, { oUnit})
                        else
                            --NOTE: If updating how calcualte this, then also update events since we reduce mass based on mass cost for experimentals
                            iCurMassTotal = iCurMassTotal + oUnit:GetBlueprint().Economy.BuildCostMass
                        end
                    end
                end
                aiBrain[sThreatVariableRef] = math.max(aiBrain[sThreatVariableRef], iCurMassTotal)
            end

            if not(aiBrain[refiAIBrainCurrentStrategy]) then
                M27Utilities.ErrorHandler('We didnt have a strategy set for brain '..aiBrain.Nickname..'; so will set it to the default strategy '..(aiBrain[refiDefaultStrategy] or 'nil'))
                if not(aiBrain[refiDefaultStrategy]) then
                    M27Utilities.ErrorHandler('We dont have a default strategy set so will set it to land main')
                    aiBrain[refiDefaultStrategy] = refStrategyLandMain
                end
                aiBrain[refiAIBrainCurrentStrategy] = aiBrain[refiDefaultStrategy]
            end


            --TestCustom(aiBrain)

            --STATE OF GAME LOG BELOW------------------



            --Get key values relating to game state (for now only done if debugmessages, but coudl move some to outside of debugmessages)
            if M27Config.M27StrategicLog == true or bDebugMessages == true then
                local tsGameState = {}
                local tTempUnitList, iTempUnitCount

                --Brain
                tsGameState['01. aiBrain'] = 'Name=' .. aiBrain.Nickname .. '; Index=' .. aiBrain:GetArmyIndex() .. 'Start=' .. aiBrain.M27StartPositionNumber

                --Time
                tsGameState['02.GameTime'] = iCurTime
                tsGameState['02.SystemTimeSinceLastLog'] = GetSystemTimeSecondsOnlyForProfileUse() - (aiBrain[M27Utilities.refiLastSystemTimeRecorded] or 0)
                aiBrain[M27Utilities.refiLastSystemTimeRecorded] = GetSystemTimeSecondsOnlyForProfileUse()
                tsGameState['02.SystemTimeTotal'] = aiBrain[M27Utilities.refiLastSystemTimeRecorded] - iSystemTimeBeforeStartOverseerLoop

                --Grand Strategy and enemy base
                tsGameState['03.' .. refiAIBrainCurrentStrategy] = aiBrain[refiAIBrainCurrentStrategy]
                tsGameState['03. NearestEnemyStartNumber'] = M27Logic.GetNearestEnemyStartNumber(aiBrain)
                tsGameState['03. EnemyT2PlusNavyNearBase'] = aiBrain[refbT2NavyNearOurBase]

                --Economy:
                tsGameState['04.iMassGrossIncome'] = aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome]
                tsGameState['04.iMassNetIncome'] = aiBrain:GetEconomyTrend('MASS')
                tsGameState['04.iEnergyNetIncome'] = aiBrain:GetEconomyTrend('ENERGY')
                tsGameState['04.iMassStored'] = aiBrain:GetEconomyStored('MASS')
                tsGameState['04.iEnergyStored'] = aiBrain:GetEconomyStored('ENERGY')
                tsGameState['04.PausedUpgrades'] = aiBrain[M27EconomyOverseer.refiPausedUpgradeCount]
                tsGameState['04.PowerStall active'] = tostring(aiBrain[M27EconomyOverseer.refbStallingEnergy])

                --Get other unclaimed mex details
                local iUnclaimedMexesOnOurSideOfMap = 0
                local iUnclaimedMexesWithinDefenceCoverage = 0
                local iUnclaimedMexesWithinIntelAndDefence = 0
                if iAllUnclaimedMexesInPathingGroup > 0 then

                    local tUnclaimedMexesOnOurSideOfMap = M27EngineerOverseer.FilterLocationsBasedOnDistanceToEnemy(aiBrain, tAllUnclaimedMexesInPathingGroup, 0.5)
                    if M27Utilities.IsTableEmpty(tUnclaimedMexesOnOurSideOfMap) == false then
                        iUnclaimedMexesOnOurSideOfMap = table.getn(tUnclaimedMexesOnOurSideOfMap)
                    end
                    local tUnclaimedMexesWithinDefenceCoverage = M27EngineerOverseer.FilterLocationsBasedOnDefenceCoverage(aiBrain, tAllUnclaimedMexesInPathingGroup, false)
                    if M27Utilities.IsTableEmpty(tUnclaimedMexesWithinDefenceCoverage) == false then
                        iUnclaimedMexesWithinDefenceCoverage = table.getn(tUnclaimedMexesWithinDefenceCoverage)
                    end
                    local tUncalimedMexesWithinIntelAndDefence = M27EngineerOverseer.FilterLocationsBasedOnDefenceCoverage(aiBrain, tAllUnclaimedMexesInPathingGroup, true)
                    if M27Utilities.IsTableEmpty(tUncalimedMexesWithinIntelAndDefence) == false then
                        iUnclaimedMexesWithinIntelAndDefence = table.getn(tUncalimedMexesWithinIntelAndDefence)
                    end
                end

                tsGameState['04.AllMexesInACUPathingGroup'] = iAllMexesInPathingGroup
                tsGameState['04.AllMexesInPathingGroupWeHaventClaimed'] = iAllMexesInPathingGroupWeHaventClaimed
                tsGameState['04.UnclaimedUnqueuedMexesByAnyoneInACUPathingGroup'] = iAllUnclaimedMexesInPathingGroup
                tsGameState['04.UnclaimedMexesOnOurSideOfMap'] = iUnclaimedMexesOnOurSideOfMap
                tsGameState['04.UnclaimedMexesWithinDefenceCoverage'] = iUnclaimedMexesWithinDefenceCoverage
                tsGameState['04.UnclaimedMexesWithinIntelAndDefence'] = iUnclaimedMexesWithinIntelAndDefence
                tsGameState['04.MexesNearBase'] = iMexesNearStart
                tsGameState['04.T3MexesOwned'] = iT3Mexes
                tsGameState['04.MexesUpgrading'] = aiBrain[M27EconomyOverseer.refiMexesUpgrading]


                --Key unit counts:
                tTempUnitList = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryLandFactory, false, true)
                iTempUnitCount = 0
                if M27Utilities.IsTableEmpty(tTempUnitList) == false then
                    iTempUnitCount = table.getn(tTempUnitList)
                end
                tsGameState['05.iLandFactories'] = iTempUnitCount

                tsGameState['05.Highest factory tech level'] = aiBrain[refiOurHighestFactoryTechLevel]

                tTempUnitList = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryEngineer, false, true)
                iTempUnitCount = 0
                if M27Utilities.IsTableEmpty(tTempUnitList) == false then
                    iTempUnitCount = table.getn(tTempUnitList)
                end
                tsGameState['05.iEngineers'] = iTempUnitCount

                tsGameState['05.iLandCombatUnits'] = iTempUnitCount

                --Build orders: Engineers wanted
                tsGameState['05.InitialEngisShortfall'] = aiBrain[M27EngineerOverseer.refiBOInitialEngineersWanted]
                tsGameState['05.PreReclaimEngisWanted'] = aiBrain[M27EngineerOverseer.refiBOPreReclaimEngineersWanted]
                tsGameState['05.refiBOPreSpareEngineersWanted'] = aiBrain[M27EngineerOverseer.refiBOPreSpareEngineersWanted]
                tsGameState['05.SpareEngisByTechLevel'] = aiBrain[M27EngineerOverseer.reftiBOActiveSpareEngineersByTechLevel]

                --Factories wanted
                tsGameState['05.WantMoreLandFactories'] = tostring(aiBrain[M27EconomyOverseer.refbWantMoreFactories])

                --MAA wanted:
                tsGameState['06.MAAShortfallACUPrecaution'] = aiBrain[refiMAAShortfallACUPrecaution]
                tsGameState['06.MAAShortfallACUCore'] = aiBrain[refiMAAShortfallACUCore]
                tsGameState['06.MAAShortfallLargePlatoons'] = aiBrain[refiMAAShortfallLargePlatoons]
                tsGameState['06.MAAShortfallBase'] = aiBrain[refiMAAShortfallBase]

                if aiBrain[M27AirOverseer.refiOurMassInMAA] then
                    tsGameState['06.OurMAAThreat'] = aiBrain[M27AirOverseer.refiOurMassInMAA]
                end
                tsGameState['06.EmergencyMAANeeded'] = aiBrain[refbEmergencyMAANeeded]

                --Scouts wanted:
                tsGameState['07.ScoutShortfallInitialRaider'] = aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher]
                tsGameState['07.ScoutShortfallACU'] = aiBrain[refiScoutShortfallACU]
                tsGameState['07.ScoutShortfallIntelLine'] = aiBrain[refiScoutShortfallIntelLine]
                tsGameState['07.ScoutShortfallLargePlatoons'] = aiBrain[refiScoutShortfallLargePlatoons]
                tsGameState['07.ScoutShortfallAllPlatoons'] = aiBrain[refiScoutShortfallAllPlatoons]

                --Air:
                tsGameState['08.BomberEffectiveness'] = aiBrain[M27AirOverseer.refbBombersAreEffective]
                tsGameState['08.AirAANeeded'] = aiBrain[M27AirOverseer.refiAirAANeeded]
                tsGameState['08.AirAAWanted'] = aiBrain[M27AirOverseer.refiAirAAWanted]
                tsGameState['08.OurMassInAirAA'] = aiBrain[M27AirOverseer.refiOurMassInAirAA]
                if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] then
                    tsGameState['08.EnemyAirThreat'] = aiBrain[M27AirOverseer.refiHighestEnemyAirThreat]
                end
                tsGameState['08.EnemyAirAAThreat'] = (aiBrain[M27AirOverseer.refiEnemyAirAAThreat] or 0)
                tsGameState['08.EnemyAirToGroundThreat'] = (aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] or 0)
                local iAvailableAirAA = 0
                if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableAirAA]) == false then
                    for iUnit, oUnit in aiBrain[M27AirOverseer.reftAvailableAirAA] do
                        iAvailableAirAA = iAvailableAirAA + 1
                    end
                end
                tsGameState['08.AvailableAirAA'] = iAvailableAirAA
                tsGameState['08.AvailableBombers'] = 0

                if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableBombers]) == false then
                    tsGameState['08.AvailableBombers'] = table.getn(aiBrain[M27AirOverseer.reftAvailableBombers])
                end
                tsGameState['08.RemainingBomberTargets'] = 0
                if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftBomberTargetShortlist]) == false then
                    tsGameState['08.RemainingBomberTargets'] = table.getn(aiBrain[M27AirOverseer.reftBomberTargetShortlist])
                end
                tsGameState['08.TorpBombersWanted'] = aiBrain[M27AirOverseer.refiTorpBombersWanted]
                tsGameState['08.HaveAirControl'] = aiBrain[M27AirOverseer.refbHaveAirControl]

                --Mobile shields
                tsGameState['09.WantMoreMobileShields'] = tostring(aiBrain[M27PlatoonFormer.refbUsingMobileShieldsForPlatoons])

                --Threat values:
                --Intel path % to enemy
                if aiBrain[refiCurIntelLineTarget] then
                    local iIntelPathPosition = aiBrain[refiCurIntelLineTarget]
                    local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                    --reftIntelLinePositions = 'M27IntelLinePositions' --x = line; y = point on that line, returns position
                    local tIntelPathCurBase = aiBrain[reftIntelLinePositions][iIntelPathPosition][1]
                    local iIntelDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tIntelPathCurBase, tStartPosition)
                    local iIntelDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tIntelPathCurBase, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                    tsGameState['10.iIntelPathPosition'] = iIntelPathPosition
                    tsGameState['10.iIntelDistancePercent'] = iIntelDistanceToStart / (iIntelDistanceToStart + iIntelDistanceToEnemy)
                end
                tsGameState['10.DistanceToNearestEnemyBase'] = aiBrain[refiDistanceToNearestEnemyBase]
                if aiBrain[refiModDistFromStartNearestOutstandingThreat] then
                    tsGameState['10.NearestOutstandingThreat'] = aiBrain[refiModDistFromStartNearestOutstandingThreat]
                end
                if aiBrain[refiPercentageOutstandingThreat] then
                    tsGameState['10.PercentageOutstandingThreat'] = aiBrain[refiPercentageOutstandingThreat]
                end
                if aiBrain[refiModDistFromStartNearestThreat] then
                    tsGameState['10.ModDistNearestThreat'] = aiBrain[refiModDistFromStartNearestThreat]
                end
                tsGameState['10.PercentDistOfOurCombatUnitClosestToEnemyBase'] = (aiBrain[refiPercentageClosestFriendlyFromOurBaseToEnemy] or 'nil')
                tsGameState['10.PercentDistOfLandUnitClosestToEnemyBase'] = (aiBrain[refiPercentageClosestFriendlyLandFromOurBaseToEnemy] or 'nil')
                tsGameState['10.NearestEnemyStartPoint'] = aiBrain[M27MapInfo.reftPrimaryEnemyBaseLocation]
                tsGameState['10.LongRangeEnemyMobileThreat'] = aiBrain[refiTotalEnemyLongRangeThreat]
                tsGameState['10.ShortRangeEnemyMobileThreat'] = aiBrain[refiTotalEnemyShortRangeThreat]

                LOG(repru(tsGameState))
            end



            if bDebugMessages == true then
                LOG(sFunctionRef .. ': iMexesInPathingGroupWeHaveClaimed=' .. iMexesInPathingGroupWeHaveClaimed .. '; iOurTeamsShareOfMexesOnMap=' .. iOurTeamsShareOfMexesOnMap .. '; iAllMexesInPathingGroupWeHaventClaimed=' .. iAllMexesInPathingGroupWeHaventClaimed..'; iAllMexesInPathingGroup='..iAllMexesInPathingGroup)
            end

            --Update flag for if we are behind on eco
            local iEstimatedNearestEnemyEco = 0
            local tiMassByTech = {2, 6, 18, 180}
            local tNearestEnemyMexes = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMex + M27UnitInfo.refCategoryMassStorage, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 10000, 'Enemy')
            if M27Utilities.IsTableEmpty(tNearestEnemyMexes) == false then
                for iMex, oMex in tNearestEnemyMexes do
                    iEstimatedNearestEnemyEco = iEstimatedNearestEnemyEco + tiMassByTech[M27UnitInfo.GetUnitTechLevel(oMex)]
                end
            end
            --Reduce by enemy team number
            local iEnemyBrains = 0
            if M27Utilities.IsTableEmpty(aiBrain[toEnemyBrains]) == false then
                for iBrain, oBrain in aiBrain[toEnemyBrains] do
                    iEnemyBrains = iEnemyBrains + 1
                end
            end
            iEnemyBrains = math.max(1, iEnemyBrains * 0.9)

            iEstimatedNearestEnemyEco = iEstimatedNearestEnemyEco / iEnemyBrains


            if iMexesInPathingGroupWeHaveClaimed < iOurTeamsShareOfMexesOnMap then
                if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] <= iEstimatedNearestEnemyEco * 1.5 then
                    aiBrain[M27EconomyOverseer.refbBehindOnEco] = true
                else
                    aiBrain[M27EconomyOverseer.refbBehindOnEco] = false
                end
            else
                --We have more than our team's share of mexes
                if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] <= iEstimatedNearestEnemyEco * 1.1 then
                    aiBrain[M27EconomyOverseer.refbBehindOnEco] = true
                else
                    aiBrain[M27EconomyOverseer.refbBehindOnEco] = false
                end
            end


            -------->>>>>>>>>>>>Set ACU health to run on<<<<<<<<<<<----------------
            --NOTE: Platoon utilities nearby enemies logic will adjust this slightly, in particular see the variable bCapHealthToRunOn, which reduces health to run on from 100% to 98% in most cases
            --if GetGameTimeSeconds() >= 1080 and aiBrain:GetArmyIndex() == 2 then bDebugMessages = true M27Config.M27ShowUnitNames = true end

            aiBrain[refiACUHealthToRunOn] = math.max(5250, oACU:GetMaxHealth() * 0.45)
            --Play safe with ACU if we have almost half or more of mexes
            local iUpgradeCount = M27UnitInfo.GetNumberOfUpgradesObtained(oACU)
            local iKeyUpgradesWanted = 1
            if bDebugMessages == true then LOG(sFunctionRef..': About to determine adjustments to the ACU health to run on. iUpgradeCount='..iUpgradeCount..'; ACU max health='..oACU:GetMaxHealth()) end

            if iMexesInPathingGroupWeHaveClaimed >= iOurTeamsShareOfMexesOnMap * 0.9 then
                if iMexesInPathingGroupWeHaveClaimed >= iOurTeamsShareOfMexesOnMap * 1.1 then
                    --We have 55% of mexes on map so shoudl be ahead on eco


                    if iMexesInPathingGroupWeHaveClaimed >= iOurTeamsShareOfMexesOnMap * 1.2 or not(M27Conditions.DoesACUHaveGun(aiBrain, false)) then
                        aiBrain[refiACUHealthToRunOn] = oACU:GetMaxHealth() * 0.95
                    else
                        aiBrain[refiACUHealthToRunOn] = oACU:GetMaxHealth() * 0.8
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': Have 10% more than our share of mexes, so setting health to run at 95% of max health') end
                    --if iMexesInPathingGroupWeHaveClaimed >= iOurTeamsShareOfMexesOnMap * 1.2 then
                    --Set equal to max health (so run) if we dont have a supporting upgrade as we are ahead on eco so can afford to drop back for an upgrade

                    if EntityCategoryContains(categories.AEON, oACU.UnitId) then
                        iKeyUpgradesWanted = 2
                    end
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': iUpgradeCount=' .. iUpgradeCount .. '; iKeyUpgradesWanted=' .. iKeyUpgradesWanted)
                    end
                    if iUpgradeCount < iKeyUpgradesWanted and M27Conditions.HaveEnoughGrossIncomeToForceFirstUpgrade(aiBrain) then
                        aiBrain[refiACUHealthToRunOn] = oACU:GetMaxHealth()
                        if bDebugMessages == true then LOG(sFunctionRef..': Want to force an upgrade so will set health to run at max health') end
                    end
                    --end

                else
                    --We have almost half of the mexes on the map.  Given the delay in claiming mexes it's likely we're at least even with the enemy
                    if M27Conditions.DoesACUHaveGun(aiBrain, false) then
                        aiBrain[refiACUHealthToRunOn] = math.max(8000, oACU:GetMaxHealth() * 0.7)
                        if bDebugMessages == true then LOG(sFunctionRef..': Have almost half of map mexes, and acu has gun, so setting health to retreat to be 70%') end
                    else
                        --ACU doesnt have gun so be very careful
                        aiBrain[refiACUHealthToRunOn] = math.max(9000, oACU:GetMaxHealth() * 0.8)
                    end
                end
            elseif iMexesInPathingGroupWeHaveClaimed <= iOurTeamsShareOfMexesOnMap * 0.7 then
                aiBrain[refiACUHealthToRunOn] = math.max(4250, oACU:GetMaxHealth() * 0.35)
            end
            --Do we have a firebase? if so increase health to run on
            if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef]) == false then
                aiBrain[refiACUHealthToRunOn] = math.min(oACU:GetMaxHealth() * 0.9, aiBrain[refiACUHealthToRunOn] + 2000)
            end

            if oACU[refbInDangerOfBeingFlanked] then
                aiBrain[refiACUHealthToRunOn] = math.max(oACU:GetMaxHealth() * 0.9, aiBrain[refiACUHealthToRunOn])
                if bDebugMessages == true then LOG(sFunctionRef..': ACU is in danger of being flanked. Size of flanking units table='..table.getn(oACU[reftPotentialFlankingUnits])) end
            end

            --Also set health to run as a high value if we have high mass and energy income and enemy is at tech 3
            if (aiBrain[M27AirOverseer.refbFarBehindOnAir] or aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 30 or (aiBrain[refiEnemyHighestTechLevel] >= 3 and (aiBrain[refiHighestEnemyGroundUnitHealth] >= 5000 or aiBrain[refiTotalEnemyShortRangeThreat] >= 10000))) and aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 10 and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] >= 50 then
                if bDebugMessages == true then LOG(sFunctionRef..': Enemy has access to tech 3, and we have at least 100 mass per second income') end
                if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 13 and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] >= 100 then
                    if not (M27Conditions.DoesACUHaveBigGun(aiBrain, oACU)) then
                        --Increase health to run above max health (so even with mobile shields we will run) if dont have gun upgrade or v.high economy
                        if not (M27Conditions.DoesACUHaveGun(aiBrain, true, oACU)) or aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 26 or aiBrain[refiEnemyHighestTechLevel] >= 4 then
                            aiBrain[refiACUHealthToRunOn] = oACU:GetMaxHealth() + 15000
                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy has T4 or we dont have gun or have lots of mass so will force ACU to run') end
                        else
                            --Enemy has t3, and we have decent eco; run if we dont have lots of enhancements
                            if iUpgradeCount < 3 or aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 20 then
                                aiBrain[refiACUHealthToRunOn] = oACU:GetMaxHealth()
                                if bDebugMessages == true then LOG(sFunctionRef..': Have high mass income and not many upgrades so will force ACU to run') end

                            else    --Have 3+ enhancements and dont have at least 200 gross mass income so will allow a bit of health damage
                                aiBrain[refiACUHealthToRunOn] = oACU:GetMaxHealth() * 0.95
                                if bDebugMessages == true then LOG(sFunctionRef..': Have at least 3 upgrades so will only retreat if ACU not at full health') end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': iUpgradeCount='..iUpgradeCount..'; aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome]='..aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome]..'; health to run on after adjusting for this='..aiBrain[refiACUHealthToRunOn]) end
                        end
                    else
                        aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], oACU:GetMaxHealth() * 0.95)
                    end
                else
                    if iUpgradeCount < 1 then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Dont have any ugprade on ACU yet so want to retreat it')
                        end
                        aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], oACU:GetMaxHealth() + 5000)
                    elseif iUpgradeCount < iKeyUpgradesWanted then
                        aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], oACU:GetMaxHealth() * 0.95)
                    end
                end
            end

            if bDebugMessages == true then LOG(sFunctionRef..': Health to run on before further adjustments='..aiBrain[refiACUHealthToRunOn]) end

            --Increase health to run on if enemy has air nearby and we lack AA
            if aiBrain[M27AirOverseer.refiAirAANeeded] > 0 then
                local bHaveNearbyMAA = false
                if oACU[refoUnitsMAAHelper] and M27Utilities.IsTableEmpty(oACU[refoUnitsMAAHelper][M27PlatoonUtilities.reftCurrentUnits]) == false then
                    local oNearestMAA = M27Utilities.GetNearestUnit(oACU[refoUnitsMAAHelper][M27PlatoonUtilities.reftCurrentUnits], oACU:GetPosition(), aiBrain)
                    if M27UnitInfo.IsUnitValid(oNearestMAA) then
                        if M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), oNearestMAA:GetPosition()) <= 30 then
                            bHaveNearbyMAA = true
                        end
                    end
                end
                if not (bHaveNearbyMAA) then
                    if aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][3] > 0 and aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] >= 2000 and not(oACU:HasEnhancement('CloakingGenerator')) and not(aiBrain[M27AirOverseer.refbHaveAirControl]) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Lack air control and enemy has T3 air so setting ACU health to run at ACU max health') end
                        aiBrain[refiACUHealthToRunOn] = oACU:GetMaxHealth()
                    else
                        local tEnemyAirThreats = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGunship + M27UnitInfo.refCategoryBomber + M27UnitInfo.refCategoryTorpBomber, oACU:GetPosition(), 40, 'Enemy')
                        if M27Utilities.IsTableEmpty(tEnemyAirThreats) == false then
                            aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], oACU:GetMaxHealth() * 0.85)
                            if bDebugMessages == true then LOG(sFunctionRef..': Nearby enemy air threats so setting health to run at 95% of ACU health') end
                        end
                    end
                end
            end

            --Increase health to run on if ACU has recently taken torpedo damage
            if GetGameTimeSeconds() - (oACU[refiACULastTakenUnseenOrTorpedoDamage] or -100) <= 60 and not(oACU:HasEnhancement('NaniteTorpedoTube')) then
                aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], oACU:GetMaxHealth() * 0.85)
                if bDebugMessages == true then LOG(sFunctionRef..': ACU recently taken unseen or torpedo damage so setting health to run to 85% of its health') end
            end
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Finished setting ACU health to run on. ACU max health=' .. oACU:GetMaxHealth() .. '; ACU health to run on=' .. aiBrain[refiACUHealthToRunOn])
            end

            --Increase health to run if we are on enemy side of the map
            local iDistToOurBase = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            local iDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))


            --Flag we need AirAA as an emergency and set ACU health to run equal to max health if we fear an air snipe
            if bDebugMessages == true then LOG(sFunctionRef..': Considering if vulnerable to air snipe. iDistToOurBase='..iDistToOurBase..'; have air control='..tostring(aiBrain[M27AirOverseer.refbHaveAirControl])..'; aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat]='..aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat]..'; aiBrain[M27AirOverseer.refiOurMassInAirAA]='..aiBrain[M27AirOverseer.refiOurMassInAirAA]..'; Enemy AirAA threat='..aiBrain[M27AirOverseer.refiEnemyAirAAThreat]) end
            if iDistToOurBase >= 200 and aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 1800 and not(oACU:HasEnhancement('CloakingGenerator')) then
                --(1500 threshold as have seen replays where Gun+T2 ACU with mobile shield and T2 MAA escort dies to T1 bombers
                local tNearbyEnemyAir = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAllAir * categories.EXPERIMENTAL + M27UnitInfo.refCategoryBomber + M27UnitInfo.refCategoryGunship, oACU:GetPosition(), 130, 'Enemy')
                aiBrain[refbACUVulnerableToAirSnipe] = true
                if bDebugMessages == true then LOG(sFunctionRef..': Set ACU as being vulnerable to an air snipe. Is table of nearby enemy air to ground empty='..tostring(M27Utilities.IsTableEmpty(tNearbyEnemyAir))) end

                --Also retreat if nearby enemy air threat nearby and ACU not close to base
                if M27Utilities.IsTableEmpty(tNearbyEnemyAir) == false then
                    aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], oACU:GetMaxHealth())
                end
                --Potential air threat; will distinguish between the following scenarios:
                --High risk of air snipe requiring emergency AA production
                --Risk of air snipe due to being far away from AirAA support

                if not(aiBrain[M27AirOverseer.refbHaveAirControl]) and aiBrain[M27AirOverseer.refiOurMassInAirAA] <= math.max(2000, aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] * 0.5) then
                    --High risk of air snipe.  Set health to run equal to 75% normally, or 100% if we have weak MAA nearby

                    --aiBrain[refbACUVulnerableToAirSnipe] = true
                    aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], oACU:GetMaxHealth() * 0.75)
                    local tNearbyMAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMAA, oACU:GetPosition(), 60, 'Ally')
                    local iNearbyMAAThreat = 0
                    if M27Utilities.IsTableEmpty(tNearbyMAA) == false then
                        iNearbyMAAThreat = M27Logic.GetAirThreatLevel(aiBrain, tNearbyMAA, false, false, true, false, false, nil, nil, nil, nil, nil)
                    end
                    if iNearbyMAAThreat <= 400 or (iNearbyMAAThreat <= 750 and aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 1500 and aiBrain[M27AirOverseer.refbFarBehindOnAir]) then
                        aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], oACU:GetMaxHealth())
                        if bDebugMessages == true then LOG(sFunctionRef..': ACU very vulnerable to Air snipe, will retreat even if on full health') end
                    elseif iNearbyMAAThreat <= 750 and aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 2500 then
                        if bDebugMessages == true then LOG(sFunctionRef..': ACU vulnerable to air snipe, but not massively, so will just retreat if not quite full health') end
                        aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], oACU:GetMaxHealth() * 0.9)
                    end
                else
                    --Are we far away from the air rally point, and lack much MAA support? If so then set health to run on between 90-100%
                    if M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27AirOverseer.GetAirRallyPoint(aiBrain)) >= 150 then
                        local iACUShield, iACUMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oACU, true)
                        if oACU:GetHealth() + iACUShield < 19000 then

                            local tNearbyMAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMAA, oACU:GetPosition(), 60, 'Ally')
                            local iNearbyMAAThreat = 0
                            if M27Utilities.IsTableEmpty(tNearbyMAA) == false then
                                iNearbyMAAThreat = M27Logic.GetAirThreatLevel(aiBrain, tNearbyMAA, false, false, true, false, false, nil, nil, nil, nil, nil)
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': More than 150 from nearest air rally point. iNearbyMAAThreat='..iNearbyMAAThreat..'; Enemy air to ground threat='..aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat]) end
                            if iNearbyMAAThreat <= math.min(400, math.max(200, aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] * 0.1)) then
                                if aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 3000 then
                                    aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], oACU:GetMaxHealth())
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have little MAA nearby and AirAA is a long way away so will run even if on full health') end
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': Is table of nearby enemy air empty='..tostring(M27Utilities.IsTableEmpty(tNearbyEnemyAir))) end
                                    if M27Utilities.IsTableEmpty(tNearbyEnemyAir) == false then
                                        aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], oACU:GetMaxHealth())
                                        if bDebugMessages == true then LOG(sFunctionRef..': Have little MAA nearby, enemy has nearby air threats, and AirAA is a long way away so will run even if on full health') end
                                    elseif iNearbyMAAThreat <= 400 and aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 4000 then
                                        if bDebugMessages == true then LOG(sFunctionRef..': have some MAA but still not much and enemy has high overall air threat so will run if take much damage') end
                                        aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], oACU:GetMaxHealth() * 0.9)
                                    end
                                end
                            end
                        end
                    end

                end


            else
                aiBrain[refbACUVulnerableToAirSnipe] = false
            end


            if bDebugMessages == true then LOG(sFunctionRef..': aiBrain='..aiBrain.Nickname..'; iDistToOurBase='..iDistToOurBase..'; End of deciding if vulnerable to air snipe, is ACU vulnerable='..tostring(aiBrain[refbACUVulnerableToAirSnipe])..'; Current ACU health to run on before further adjustment='..aiBrain[refiACUHealthToRunOn]..'; Has enemy built torpedo bombers='..tostring(aiBrain[M27AirOverseer.refbEnemyHasBuiltTorpedoBombers] or false)..'; iUpgradeCount='..iUpgradeCount..'; Enemy air to ground threat='..(aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] or 'nil')..'; Can path to enemy with land='..tostring(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand])..'; can path to enemy with amphib='..tostring(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious])..'; Is ACU underwater='..tostring(M27UnitInfo.IsUnitUnderwater(oACU))) end
            --If ACU far from base and is amphibious map and ACU is in big pond, without many upgrades, and enemy has built at least 1 torpedo bomber this game, then have it run if the enemy has torp bombers
            if iDistToOurBase > 175 and (aiBrain[M27AirOverseer.refbEnemyHasBuiltTorpedoBombers] or aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][3] > 0) and iUpgradeCount < 3 and aiBrain[M27AirOverseer.refiEnemyAirToGroundThreat] >= 200 and not(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand]) and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] and M27UnitInfo.IsUnitUnderwater(oACU) then
                --is the ACU in a large pond (10k+ in size)?
                local iPond = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeNavy, oACU:GetPosition())
                if bDebugMessages == true then LOG(sFunctionRef..': ACU pond='..iPond..'; is pond details empty for this pond='..tostring(M27Utilities.IsTableEmpty(M27Navy.tPondDetails[iPond])))
                    if M27Navy.tPondDetails[iPond] then LOG(sFunctionRef..': Pond size='..(M27Navy.tPondDetails[iPond][M27Navy.subrefPondSize] or 'nil')) end
                end
                if M27Navy.tPondDetails[iPond] and M27Navy.tPondDetails[iPond][M27Navy.subrefPondSize] >= 10000 then
                    aiBrain[refiACUHealthToRunOn] = oACU:GetMaxHealth()
                    if bDebugMessages == true then LOG(sFunctionRef..': Enemy has built torp bombers and our ACU is vulnerable so want to retreat it') end
                end
            end


            if iDistToOurBase > iDistToEnemyBase then aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], math.min(aiBrain[refiACUHealthToRunOn] + oACU:GetMaxHealth() * 0.05, oACU:GetMaxHealth() * 0.975)) end

            --Increase health to run if we lack basic intel coverage
            if not(M27Logic.GetIntelCoverageOfPosition(aiBrain, oACU:GetPosition(), 30, false)) then aiBrain[refiACUHealthToRunOn] = math.max(aiBrain[refiACUHealthToRunOn], math.min(aiBrain[refiACUHealthToRunOn] + oACU:GetMaxHealth() * 0.05, oACU:GetMaxHealth() * 0.975)) end

            --Decrease health to run if we are in land rush mode
            if aiBrain[refiAIBrainCurrentStrategy] == refStrategyLandRush and aiBrain[refiACUHealthToRunOn] >= 4000 then aiBrain[refiACUHealthToRunOn] = math.max(4000, aiBrain[refiACUHealthToRunOn] * 0.8) end

            if bDebugMessages == true then LOG(sFunctionRef..': Finished calculating health for ACU to run on. aiBrain[refiACUHealthToRunOn]='..aiBrain[refiACUHealthToRunOn]..'; refbACUVulnerableToAirSnipe='..tostring(aiBrain[refbACUVulnerableToAirSnipe])) end


        else
            --Still want AirAA to update every second
            ForkThread(M27Team.UpdateTeamDataForEnemyUnits, aiBrain, false) --Currently updates number of wall units but could add other logic to this
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function InitiateLandFactoryConstructionManager(aiBrain)
    --Creates monitor for what land factories should build
    ForkThread(M27FactoryOverseer.SetPreferredUnitsByCategory, aiBrain)
    ForkThread(M27FactoryOverseer.FactoryOverseer, aiBrain)
end

function InitiateEngineerManager(aiBrain)
    local sFunctionRef = 'InitiateEngineerManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicks(3)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    ForkThread(M27EngineerOverseer.EngineerManager, aiBrain)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function InitiateUpgradeManager(aiBrain)
    ForkThread(M27EconomyOverseer.UpgradeManager, aiBrain)
end

function SwitchSoMexesAreNeverIgnored(aiBrain, iDelayInSeconds)
    --Initially want raiders to hunt engis, after a set time want to switch to attack mexes even if few units in platoon
    local sFunctionRef = 'SwitchSoMexesAreNeverIgnored'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitSeconds(iDelayInSeconds)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    aiBrain[refiIgnoreMexesUntilThisManyUnits] = 0
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordAllEnemiesAndAllies(aiBrain)
    --Call via forkthread
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordAllEnemiesAndAllies'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of attempt to get backup list of enemies for aiBrain with army index=' .. aiBrain:GetArmyIndex() .. ', called for brain with armyindex=' .. aiBrain:GetArmyIndex() .. '; will wait 2 seconds first')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitSeconds(1) --Note - when waited 4 seconds this would run after the strategic overseer code, which would be checking things like unclaimedm exes and lead to an error
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Finished waiting 1.5s for brain with armyindex=' .. aiBrain:GetArmyIndex() .. '; will proceed with updating enemy and ally list. GameTime=' .. GetGameTimeSeconds()..'; refbAllEnemiesDead='..tostring(aiBrain[M27Logic.refbAllEnemiesDead] or false))
    end

    if not(aiBrain[M27Logic.refbAllEnemiesDead]) then
        local iOurIndex = aiBrain:GetArmyIndex()
        local iEnemyCount = 0
        local iAllyCount = 0
        local iArmyIndex

        tAllActiveM27Brains = {}
        if M27Utilities.IsTableEmpty(ArmyBrains) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Army brains isnt empty so will cycle through all of these brains') end
            local bUpdateStartOfGameCount = false

            aiBrain[toEnemyBrains] = {}
            aiBrain[toAllyBrains] = {}

            for iCurBrain, oBrain in ArmyBrains do
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Considering whether brain with armyindex =' .. oBrain:GetArmyIndex() .. ' is defeated and is enemy or ally.')
                end
                if not (oBrain:IsDefeated()) and not(oBrain.M27IsDefeated) then
                    --if not(oBrain:IsDefeated()) and not(oBrain.M27IsDefeated) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Brain isnt defeated. IsEnemy='..tostring(IsEnemy(iOurIndex, oBrain:GetArmyIndex()))..'; IsCivilian='..tostring(M27Logic.IsCivilianBrain(oBrain))..'; NoEnemies='..tostring((aiBrain[refbNoEnemies] or false)))
                    end
                    iArmyIndex = oBrain:GetArmyIndex()
                    tAllAIBrainsByArmyIndex[iArmyIndex] = oBrain
                    if oBrain.M27AI then
                        tAllActiveM27Brains[iArmyIndex] = oBrain
                    end
                    if IsEnemy(iOurIndex, oBrain:GetArmyIndex()) and (not (M27Logic.IsCivilianBrain(oBrain)) or aiBrain[refbNoEnemies]) then
                        iEnemyCount = iEnemyCount + 1
                        aiBrain[toEnemyBrains][iArmyIndex] = oBrain
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': aiBrain Index=' .. aiBrain:GetArmyIndex() .. '; enemy index=' .. iArmyIndex .. '; recording as an enemy; start position number=' .. oBrain.M27StartPositionNumber .. '; start position=' .. repru(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]))
                        end
                    elseif IsAlly(iOurIndex, oBrain:GetArmyIndex()) and not (oBrain == aiBrain) and not(M27Logic.IsCivilianBrain(oBrain)) then
                        iAllyCount = iAllyCount + 1
                        aiBrain[toAllyBrains][iArmyIndex] = oBrain
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Added brain with army index=' .. iArmyIndex .. ' as an ally for the brain with an army index ' .. aiBrain:GetArmyIndex())
                        end
                    end
                    if oBrain.M27StartPositionNumber then
                        M27MapInfo.UpdateNewPrimaryBaseLocation(oBrain)
                    end

                    --Update details of each enemy distance to us
                    if oBrain.M27StartPositionNumber and M27Utilities.IsTableEmpty(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]) == false then
                        oBrain[tiDistToPlayerByIndex] = {}
                        for iOtherBrain, oOtherBrain in ArmyBrains do
                            if not(oOtherBrain:IsDefeated()) and not(oOtherBrain.M27IsDefeated) and oOtherBrain.M27StartPositionNumber and M27Utilities.IsTableEmpty(M27MapInfo.PlayerStartPoints[oOtherBrain.M27StartPositionNumber]) == false  then
                                if bDebugMessages == true then LOG(sFunctionRef..': Considering distance between oBrain '..oBrain:GetArmyIndex()..' and oOtherBrain '..oOtherBrain:GetArmyIndex()..'; oBrain start number='..(oBrain.M27StartPositionNumber or 'nil')..'; oOtherBrain start number='..(oOtherBrain.M27StartPositionNumber or 'nil')..'; oBrain start position='..repru(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber])..'; oOtherBrain start position='..repru(M27MapInfo.PlayerStartPoints[oOtherBrain.M27StartPositionNumber])) end
                                oBrain[tiDistToPlayerByIndex][oOtherBrain:GetArmyIndex()] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[oOtherBrain.M27StartPositionNumber])
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Finished updating tiDistToPlayerByIndex for brain '..oBrain.Nickname..'; result='..repru(oBrain[tiDistToPlayerByIndex])) end
                    end



                elseif bDebugMessages == true then
                    LOG(sFunctionRef .. ': Brain is defeated')
                end
            end
            if not(aiBrain['M27StartOfGameCountDone']) then
                iPlayersAtGameStart = iAllyCount + iEnemyCount
                aiBrain['M27StartOfGameCountDone'] = true
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Will cycle through tAllAIBrainsByArmyIndex brains') end
            for iCurBrain, oBrain in tAllAIBrainsByArmyIndex do
                if not (oBrain:IsDefeated()) and not(oBrain.M27IsDefeated) then
                    if IsEnemy(iOurIndex, oBrain:GetArmyIndex()) then
                        iEnemyCount = iEnemyCount + 1
                        aiBrain[toEnemyBrains][oBrain:GetArmyIndex()] = oBrain
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': aiBrain Index=' .. aiBrain:GetArmyIndex() .. '; enemy index=' .. iArmyIndex .. '; recording as an enemy; start position number=' .. oBrain.M27StartPositionNumber .. '; start position=' .. repru(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]))
                        end
                    elseif IsAlly(iOurIndex, oBrain:GetArmyIndex()) and not (oBrain == aiBrain) then
                        iAllyCount = iAllyCount + 1
                        aiBrain[toAllyBrains][iArmyIndex] = oBrain
                    end
                    if oBrain.M27StartPositionNumber then
                        M27MapInfo.UpdateNewPrimaryBaseLocation(oBrain)
                    end
                end
            end
        end
        aiBrain[refiActiveEnemyBrains] = iEnemyCount
        --Do we have a team set?
        if not (aiBrain.M27Team) then
            M27Team.iTotalTeamCount = M27Team.iTotalTeamCount + 1
            aiBrain.M27Team = M27Team.iTotalTeamCount
            if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team]) then
                M27Team.tTeamData[aiBrain.M27Team] = {}
            end
            M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] = {}
            M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains][aiBrain:GetArmyIndex()] = aiBrain

            for iCurBrain, oBrain in aiBrain[toAllyBrains] do
                oBrain.M27Team = M27Team.iTotalTeamCount
                if oBrain.M27AI then
                    M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains][oBrain:GetArmyIndex()] = oBrain
                end
            end

            M27Team.TeamInitialisation(M27Team.iTotalTeamCount)
        end

        if iEnemyCount == 0 and not(aiBrain[refbNoEnemies]) then
            M27Logic.CheckIfAllEnemiesDead(aiBrain)
        end


        --Record if we have omni vision for every AI in our team; want to do here so this re-runs whenever an AI dies
        local bHaveOmniVision = false
        if bDebugMessages == true then LOG(sFunctionRef..': Omni cheat setting='..ScenarioInfo.Options.OmniCheat..'; Does this equal on='..tostring(ScenarioInfo.Options.OmniCheat == 'on')) end
        if ScenarioInfo.Options.OmniCheat == 'on' then
            if aiBrain.CheatEnabled then
                bHaveOmniVision = true
            else
                for iCurBrain, oBrain in aiBrain[toAllyBrains] do
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering AI '..oBrain.Nickname..'; .CheatEnabled='..tostring( oBrain.CheatEnabled)) end
                    if oBrain.CheatEnabled then
                        bHaveOmniVision = true
                        break
                    end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Do any of our team have omni vision='..tostring(bHaveOmniVision)) end
            for iCurBrain, oBrain in aiBrain[toAllyBrains] do
                oBrain[M27AirOverseer.refbHaveOmniVision] = bHaveOmniVision
            end
            aiBrain[M27AirOverseer.refbHaveOmniVision] = bHaveOmniVision
            if bDebugMessages == true then LOG(sFunctionRef..': Brain '..aiBrain.Nickname..': Has Omni Vision='..tostring(aiBrain[M27AirOverseer.refbHaveOmniVision])) end
        end

        --Group enemies
        aiBrain[reftoNearestEnemyBrainByGroup] = {}
        local iCurAngle, iNearestAngle, iCurDistance, iNearestDistance
        local iLastGroup = 0
        local iCurGroup = 1
        local iNearestBrainRef
        --local tEnemyBrainsByGroup = {}
        local tOurBase = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local tBrainsNeedingAGroup = {}
        for iEnemy, oBrain in aiBrain[toEnemyBrains] do
            if not (oBrain:IsDefeated()) and not(aiBrain.M27IsDefeated) then
                tBrainsNeedingAGroup[iEnemy] = oBrain

            end
        end

        --Determine if any enemy brains have map wide omni vision
        local bEnemyHaveOmni = false
        if ScenarioInfo.Options.OmniCheat == 'on' then
            for iEnemyBrain, oBrain in tBrainsNeedingAGroup do
                if oBrain.CheatEnabled then
                    bEnemyHaveOmni = true
                    break
                end
            end
        end
        for iBrain, oBrain in aiBrain[toAllyBrains] do
            oBrain[M27AirOverseer.refbEnemyHasOmniVision] = bEnemyHaveOmni
        end
        aiBrain[M27AirOverseer.refbEnemyHasOmniVision] = bEnemyHaveOmni


        while iLastGroup < iCurGroup do
            --[[if iCurGroup > 1 then
                    for iEnemy, oBrain in tEnemyBrainsByGroup[iLastGroup] do
                        tBrainsNeedingAGroup[iEnemy] = nil
                    end
                end--]]

            iLastGroup = iCurGroup
            --tEnemyBrainsByGroup[iCurGroup] = {}
            iNearestDistance = 10000
            iNearestBrainRef = nil
            for iEnemy, oBrain in tBrainsNeedingAGroup do
                --Get nearest enemy
                iCurDistance = M27Utilities.GetDistanceBetweenPositions(tOurBase, M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber])
                if iCurDistance < iNearestDistance then
                    iNearestDistance = iCurDistance
                    iNearestBrainRef = iEnemy
                end
            end
            local tNearestEnemyBase = M27MapInfo.PlayerStartPoints[tBrainsNeedingAGroup[iNearestBrainRef].M27StartPositionNumber]
            if M27Utilities.IsTableEmpty(tNearestEnemyBase) then
                if not(aiBrain[M27Logic.refbAllEnemiesDead]) then
                    M27Utilities.ErrorHandler('Dont have a nearby enemy base set, will abort')
                    break
                end
            else

                aiBrain[reftoNearestEnemyBrainByGroup][iLastGroup] = tBrainsNeedingAGroup[iNearestBrainRef]
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Nearest enemy brain for group ' .. iLastGroup .. '=' .. tBrainsNeedingAGroup[iNearestBrainRef]:GetArmyIndex())
                end
                --Calc angle to nearest enemy and if any remaining enemies outside this
                iNearestAngle = M27Utilities.GetAngleFromAToB(tOurBase, tNearestEnemyBase)
                for iEnemy, oBrain in tBrainsNeedingAGroup do
                    iCurAngle = M27Utilities.GetAngleFromAToB(tOurBase, M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber])
                    if M27Utilities.GetAngleDifference(iNearestAngle, iCurAngle) > 45 then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': oBrain with index ' .. oBrain:GetArmyIndex() .. ' has iCurAngle=' .. iCurAngle .. '; iNearestAngle=' .. iNearestAngle .. '; >45 so need another group after this one.  Cur group=' .. iLastGroup)
                        end
                        if iCurGroup == iLastGroup then
                            iCurGroup = iCurGroup + 1
                        end
                    else
                        --Dont need to keep looking for this brain
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Dont need to keep looking for brain ' .. oBrain:GetArmyIndex() .. ' as it is close to this group so removing it from list of brains needing a group')
                        end
                        tBrainsNeedingAGroup[iEnemy] = nil
                    end
                end
                if bDebugMessages == true then
                    local iRemainingBrains = 0
                    if M27Utilities.IsTableEmpty(tBrainsNeedingAGroup) == false then
                        for iBrain, oBrain in tBrainsNeedingAGroup do
                            iRemainingBrains = iRemainingBrains + 1
                            LOG(sFunctionRef .. ': Remaining brain: iBrain=' .. iBrain .. '; ArmyIndex=' .. oBrain:GetArmyIndex() .. '; total remaining brains so far=' .. iRemainingBrains)
                        end
                    end
                end
            end
        end
        if M27Utilities.IsTableEmpty(aiBrain[reftoNearestEnemyBrainByGroup]) then
            M27Utilities.ErrorHandler('No enemy brains detected for any group')
        end

        --Group allies into subteams based on nearest enemy
        if not(aiBrain.M27Subteam) then
            M27Team.iTotalSubteamCount = M27Team.iTotalSubteamCount + 1
            aiBrain.M27Subteam = M27Team.iTotalSubteamCount
            M27Team.SubteamInitialisation(aiBrain.M27Subteam) --Dont fork thread

            table.insert(M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subreftoFriendlyBrains], aiBrain)
            if bDebugMessages == true then LOG(sFunctionRef..': Is table of allied brains empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[toAllyBrains]))) end
            if M27Utilities.IsTableEmpty(aiBrain[toAllyBrains]) == false then
                local tNearestEnemyBase = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
                local iOurAngleToNearestEnemy = M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tNearestEnemyBase)
                local bSameSubteam
                --Low threshold - if within this dist will be grouped regardless of angle difference
                --High threshold - if within certain angle differential then will group if satisfy this distance
                local iDistThresholdLow = math.max(math.min(aiBrain[refiDistanceToNearestEnemyBase] * 0.8, 100), aiBrain[refiDistanceToNearestEnemyBase] * 0.3)
                local iDistThresholdHigh = math.max(math.min(aiBrain[refiDistanceToNearestEnemyBase] * 0.9, 130), aiBrain[refiDistanceToNearestEnemyBase] * 0.5)
                if bDebugMessages == true then LOG(sFunctionRef..': Our dist to enemy='..aiBrain[refiDistanceToNearestEnemyBase]..'; Low threshold='..iDistThresholdLow..'; High threshold='..iDistThresholdHigh..'; Angle to nearest enemy='..iOurAngleToNearestEnemy) end



                for iBrain, oBrain in aiBrain[toAllyBrains] do
                    if not(oBrain.M27Subteam) then
                        bSameSubteam = false
                        local iBaseDistDif = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering ally brain '..oBrain.Nickname..'; iBaseDistDif='..iBaseDistDif..'; iAngleDif='..M27Utilities.GetAngleDifference(iOurAngleToNearestEnemy, M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber], tNearestEnemyBase))) end
                        if iBaseDistDif <= iDistThresholdLow then
                            bSameSubteam = true
                        else
                            local iAngleDif = M27Utilities.GetAngleDifference(iOurAngleToNearestEnemy, M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber], tNearestEnemyBase))
                            if iAngleDif <= 40 or (iAngleDif <= 60 and iBaseDistDif <= iDistThresholdHigh) then
                                bSameSubteam = true
                            else
                                --Are we close to the start position of any of the other brains already recorded in this subteam?
                                for iSubteamBrain, oSubteamBrain in M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subreftoFriendlyBrains] do
                                    if not(oSubteamBrain == aiBrain) and not(oSubteamBrain == oBrain) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Dist to alternative subteam member '..oSubteamBrain.Nickname..' = '..M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[oSubteamBrain.M27StartPositionNumber])) end
                                        if M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[oSubteamBrain.M27StartPositionNumber]) <= iDistThresholdLow then
                                            bSameSubteam = true
                                        end
                                    end
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': On same subteam='..tostring(bSameSubteam)) end
                        if bSameSubteam then
                            oBrain.M27Subteam = aiBrain.M27Subteam
                            table.insert(M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subreftoFriendlyBrains], oBrain)
                        end
                    end
                end
            end
        end

        if bDebugMessages == true then
            LOG(sFunctionRef..': Finished recording subteams, aiBrain '..aiBrain.Nickname..' subteam='..aiBrain.M27Subteam..'; Listing out every brain in the subteam')
            for iBrain, oBrain in M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subreftoFriendlyBrains] do
                LOG(sFunctionRef..': iBrain='..iBrain..'; oBrain Nickname='..oBrain.Nickname..'; Subteam='..oBrain.M27Subteam)
            end
        end


        --Set mod distance emergency range
        aiBrain[refiModDistEmergencyRange] = math.max(math.min(aiBrain[refiDistanceToNearestEnemyBase] * 0.4, 150), aiBrain[refiDistanceToNearestEnemyBase] * 0.15)
        if bDebugMessages == true then LOG(sFunctionRef..': Have set emergency range='..(aiBrain[refiModDistEmergencyRange] or 'nil')) end

        --Update nearest ACU
        aiBrain[reftLastNearestACU] = M27MapInfo.PlayerStartPoints[M27Logic.IndexToStartNumber(M27Logic.GetNearestEnemyIndex(aiBrain, false))]
        aiBrain[refoLastNearestACU] = M27Utilities.GetACU(tAllAIBrainsByArmyIndex[M27Logic.GetNearestEnemyIndex(aiBrain, false)])

        --Force refresh of plateaus to consider expanding to since those of interest may have changed
        ForkThread(M27MapInfo.UpdatePlateausToExpandTo, aiBrain, true, true)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(1) --wait 1 tick before checking enemy brains, so any M27brains can run the above function themselves
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

        --REDUNDANCY (code in overseer initialisation triggers first)
        if aiBrain.M27AI and M27Utilities.IsTableEmpty(aiBrain[toEnemyBrains]) then
            if GetGameTimeSeconds() <= 10 then
                --REDUNDANCY (code in overseer initialisation triggers first)
                M27Chat.SendMessage(aiBrain, 'SendGameCompatibilityWarning', 'No enemies detected for '..(aiBrain.Nickname or '')..'; The AI may not function as expected', 0, 10)
                aiBrain[refbNoEnemies] = true
                if bDebugMessages == true then LOG(sFunctionRef..': Rdundancy as no enemybrains, Setting no enemies to be true') end
            end
        else
            --Assign enemies to a team if not already
            for iEnemyBrain, oEnemyBrain in aiBrain[toEnemyBrains] do
                if not (oEnemyBrain.M27Team) then
                    M27Team.iTotalTeamCount = M27Team.iTotalTeamCount + 1
                    oEnemyBrain.M27Team = M27Team.iTotalTeamCount
                    if M27Utilities.IsTableEmpty(M27Team.tTeamData[oEnemyBrain.M27Team]) then
                        M27Team.tTeamData[oEnemyBrain.M27Team] = {}
                    end
                    M27Team.tTeamData[oEnemyBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] = {}
                    if oEnemyBrain.M27AI then
                        M27Team.tTeamData[oEnemyBrain.M27Team][M27Team.reftFriendlyActiveM27Brains][oEnemyBrain:GetArmyIndex()] = oEnemyBrain
                    end
                    for iCurBrain, oBrain in aiBrain[toEnemyBrains] do
                        if not (oBrain.M27Team) and IsAlly(oBrain:GetArmyIndex(), oEnemyBrain:GetArmyIndex()) then
                            oBrain.M27Team = M27Team.iTotalTeamCount
                            if oBrain.M27AI then
                                --redundancy - should have already recorded
                                M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains][oBrain:GetArmyIndex()] = oBrain
                            end
                        end
                    end
                end
            end
        end

        --Send warning of large numbers of M27AI in a game
        if bDebugMessages == true then LOG(sFunctionRef..': Number of M27 in the game='..table.getn(tAllActiveM27Brains)) end
        if table.getn(tAllActiveM27Brains) > 4 then
            --SendMessage(aiBrain, sMessageType, sMessage,                                                                                                                                                      iOptionalDelayBeforeSending, iOptionalTimeBetweenMessageType, bOnlySendToTeam)
            if bDebugMessages == true then LOG(sFunctionRef..': About to call SendMessage') end
            M27Chat.SendMessage(aiBrain, 'SendGameCompatibilityAILimit', 'More than 4 M27AI are being used, there is the risk of a crash  on large maps or late game due to RAM limitations.  Try reducing the number and using an AiX modifier instead.', 0, 1000000, false)
        end

        --Update chokepoints (note for now this will only call once per game)
        ForkThread(M27MapInfo.IdentifyTeamChokepoints, aiBrain)

        --Record impathable area around base if no chokepoint
        ForkThread(M27MapInfo.IdentifyCliffsAroundBase, aiBrain)

        --Reset nearest base if no enemies, since the logic for nearest enemy runs before identifying all allies (but needs details of all allies to work)
        if aiBrain[refbNoEnemies] and GetGameTimeSeconds() <= 10 then
            aiBrain[M27MapInfo.reftPrimaryEnemyBaseLocation] = nil
            M27MapInfo.UpdateNewPrimaryBaseLocation(aiBrain)
        end

        --Record teams that share our pathing group
        local tiTeamsWithSamePathingGroup = {}
        function IsBrainInSamePathingGroup(oBrain)
            if not(M27Logic.IsCivilianBrain(oBrain)) and oBrain[M27MapInfo.refiStartingSegmentGroup][M27UnitInfo.refPathingTypeAmphibious] == aiBrain[M27MapInfo.refiStartingSegmentGroup][M27UnitInfo.refPathingTypeAmphibious] then
                return true
            else
                return false
            end

        end
        for iBrain, oBrain in tAllAIBrainsByArmyIndex do
            if IsBrainInSamePathingGroup(oBrain) then
                if bDebugMessages == true then LOG(sFunctionRef..': Considering brain '..oBrain.Nickname..' with index '..oBrain:GetArmyIndex()..'; Brain team='..(oBrain.M27Team or 'nil')) end
                tiTeamsWithSamePathingGroup[oBrain.M27Team] = true
            end
        end
        local iCountOfTeamsWithSamePathingGroup = 0
        for iEntry, bEntry in tiTeamsWithSamePathingGroup do
            if bEntry then
                iCountOfTeamsWithSamePathingGroup = iCountOfTeamsWithSamePathingGroup + 1
            end
        end

        --Update pathing and check have recorded nearby resources
        for iBrain, oBrain in tAllAIBrainsByArmyIndex do
            if IsBrainInSamePathingGroup(oBrain) then
                oBrain[refiTeamsWithSameAmphibiousPathingGroup] = iCountOfTeamsWithSamePathingGroup
            end
            if GetGameTimeSeconds() <= 20 and not(M27Logic.IsCivilianBrain(oBrain)) and (not(M27MapInfo.tResourceNearStart[oBrain.M27StartPositionNumber]) or M27Utilities.IsTableEmpty(M27MapInfo.tResourceNearStart[oBrain.M27StartPositionNumber][1])) then
                if bDebugMessages == true then LOG(sFunctionRef..': About to update nearby mex locations for brain '..oBrain.Nickname..'; Army index='..oBrain:GetArmyIndex()..'; Start pos='..oBrain.M27StartPositionNumber) end
                ForkThread(M27MapInfo.RecordMexNearStartPosition, oBrain.M27StartPositionNumber, 26)
            end
        end

        --Record ponds of interest
        ForkThread(M27Navy.RecordPondToExpandTo, aiBrain)
    else
        aiBrain[refiActiveEnemyBrains] = 0
    end



    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RefreshMexPositions(aiBrain)
    local sFunctionRef = 'RefreshMexPositions'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicks(80)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Force refresh of mexes to try and fix bug where not all mexes recorded as being pathable
    --M27MapInfo.RecheckPathingToMexes(aiBrain)
    ForkThread(M27MapInfo.RecordMexForPathingGroup)

    --Create sorted listing of mexes
    ForkThread(M27MapInfo.RecordSortedMexesInOriginalPathingGroup, aiBrain)
    --[[WaitTicks(400)
    ForkThread(M27MapInfo.RecordMexForPathingGroup, M27Utilities.GetACU(aiBrain), true)
    ForkThread(M27MapInfo.RecordSortedMexesInOriginalPathingGroup, aiBrain)--]]
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ACUInitialisation(aiBrain)
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ACUInitialisation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Wait until 4.5s have elapsed as humans cant start building before 4.5-5s it seems
    while GetGameTimeSeconds() <= 4.5 do
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(1)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code')
    end
    local oACU = M27Utilities.GetACU(aiBrain)
    oACU[refbACUOnInitialBuildOrder] = true


    local oNewPlatoon = aiBrain:MakePlatoon('', '')
    aiBrain:AssignUnitsToPlatoon(oNewPlatoon, { oACU }, 'Support', 'None')
    --Set movement path to current position so wont force a new movement path as the first action, but will update once have done initial construction
    oNewPlatoon[M27PlatoonUtilities.reftMovementPath] = {}
    oNewPlatoon[M27PlatoonUtilities.reftMovementPath][1] = oACU:GetPosition()
    oNewPlatoon[M27PlatoonUtilities.refiCurrentPathTarget] = 1
    oNewPlatoon:SetAIPlan('M27ACUBuildOrder')

    local iCategoryToBuild = M27UnitInfo.refCategoryLandFactory
    local iMaxAreaToSearch = 14
    local iCategoryToBuildBy = M27UnitInfo.refCategoryT1Mex
    --BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tAlternativePositionToLookFrom, bLookForPartCompleteBuildings, bLookForQueuedBuildings, oUnitToBuildBy, bNeverBuildRandom, iOptionalCategoryForStructureToBuild)
    local tInitialBuildLocation = M27EngineerOverseer.BuildStructureAtLocation(aiBrain, oACU, iCategoryToBuild, iMaxAreaToSearch, iCategoryToBuildBy, nil, false, false, nil, false, M27UnitInfo.refCategoryEngineer)
    if bDebugMessages == true then LOG(sFunctionRef..': Have just send order to try and build structure at location for ACU; tInitialBuildLocation='..repru(tInitialBuildLocation)) end
    if M27Utilities.IsTableEmpty(tInitialBuildLocation) then
        M27Utilities.ErrorHandler('Couldnt find anywhere to build initial land factory, will search for a new base location')
        --Search for the nearest location where we can build a land factory and pick this as the new base
        local sBlueprint = 'ueb0101'
        local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local iMinX = M27MapInfo.rMapPlayableArea[1]
        local iMaxX = M27MapInfo.rMapPlayableArea[3]
        local iMinZ = M27MapInfo.rMapPlayableArea[2]
        local iMaxZ = M27MapInfo.rMapPlayableArea[4]
        local tPossiblePosition
        local tActualLocation
        local bHaveBuildLocation = false
        local sPathing = M27UnitInfo.refPathingTypeAmphibious
        local iPathingGroupWanted = M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        if bDebugMessages == true then LOG(sFunctionRef..': Will consider places near tStartPosition='..repru(tStartPosition)..' if they are withi nM27MapInfo.rMapPlayableArea='..repru(M27MapInfo.rMapPlayableArea)) end
        for iMaxAdjust = 2, 250, 2 do
            for iAdjustXValue = 0, iMaxAdjust, 2 do
            --for iAdjustXValue = 2, iMaxAdjust, 2 do
                for iXFactor = -1, 1, 2 do
                    for iAdjustZValue = 0, iMaxAdjust, 2 do
                        for iZFactor = -1, 1, 2 do
                            if iAdjustXValue == iMaxAdjust or iAdjustZValue == iMaxAdjust then
                                tPossiblePosition = {tStartPosition[1] + iAdjustXValue * iXFactor, 0, tStartPosition[3] + iAdjustZValue * iZFactor}
                                if bDebugMessages == true then LOG(sFunctionRef..': Will consider tPossiblePosition='..repru(tPossiblePosition)..' if it is within map bounds') end
                                --Is this locaiton within map bounds?
                                if tPossiblePosition[1] > iMinX and tPossiblePosition[3] > iMinZ and tPossiblePosition[1] < iMaxX and tPossiblePosition[3] < iMaxZ then
                                    --Adjust the y value
                                    tPossiblePosition[2] = GetTerrainHeight(tPossiblePosition[1], tPossiblePosition[3])
                                    if bDebugMessages == true then LOG(sFunctionRef..': CanBuildStructure at tPossiblePosition='..tostring(aiBrain:CanBuildStructureAt(sBlueprint, tPossiblePosition))) end
                                    if aiBrain:CanBuildStructureAt(sBlueprint, tPossiblePosition) then
                                        --BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tAlternativePositionToLookFrom, bLookForPartCompleteBuildings, bLookForQueuedBuildings, oUnitToBuildBy, bNeverBuildRandom, iOptionalCategoryForStructureToBuild, bBuildCheapestStructure, iOptionalEngiActionRef)
                                        if M27MapInfo.GetSegmentGroupOfLocation(sPathing, tPossiblePosition) == iPathingGroupWanted then

                                            tActualLocation = M27EngineerOverseer.BuildStructureAtLocation(aiBrain, oACU, iCategoryToBuild, iMaxAreaToSearch, iCategoryToBuildBy, tPossiblePosition, false, false, nil, false, M27UnitInfo.refCategoryEngineer)
                                            if bDebugMessages == true then LOG(sFunctionRef..': Found location where we think can build a land factory, tPossiblePosition='..repru(tPossiblePosition)..'; sent order to try and build here, tActualLocation='..repru(tActualLocation)..'; iAdjustXValue'..iAdjustXValue..'; iAdjustZValue='..iAdjustZValue) end
                                            if M27Utilities.IsTableEmpty(tActualLocation) == false then
                                                bHaveBuildLocation = true
                                                break
                                            end
                                        end
                                    elseif bDebugMessages == true then
                                        LOG(sFunctionRef..': Couldnt build structure here, will draw in red')
                                        M27Utilities.DrawLocation(tPossiblePosition, nil, 2)
                                    end
                                end
                            end
                        end
                        if bHaveBuildLocation then break end
                    end
                    if bHaveBuildLocation then break end
                end
                if bHaveBuildLocation then break end
            end
            if bHaveBuildLocation then break end
        end

        if bHaveBuildLocation then
            --We couldn't bild at our original location so want to change our start position if it is far away
            if bDebugMessages == true then LOG(sFunctionRef..': Will change our start position if it is far away from the location where we are building our land factory. Distance='..M27Utilities.GetDistanceBetweenPositions(tActualLocation, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) end
            if M27Utilities.GetDistanceBetweenPositions(tActualLocation, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) >= 50 then
                if bDebugMessages == true then LOG(sFunctionRef..': About to change start position from '..repru(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])..' to '..repru(tActualLocation)) end
                M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber] = {tActualLocation[1], tActualLocation[2], tActualLocation[3]}
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    while aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllHQFactories) == 0 do
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(1)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        if bDebugMessages == true then LOG(sFunctionRef..': Still waiting for ACU to get a factory. ACU unit state='..M27Logic.GetUnitState(oACU)) end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Have a factory unit now, so will set ACU platoon to use ACUMain')
    end

    local oNewPlatoon = aiBrain:MakePlatoon('', '')
    aiBrain:AssignUnitsToPlatoon(oNewPlatoon, { oACU }, 'Support', 'None')
    --Set movement path to current position so wont force a new movement path as the first action, but will update once have done initial construction
    oNewPlatoon[M27PlatoonUtilities.reftMovementPath] = {}
    oNewPlatoon[M27PlatoonUtilities.reftMovementPath][1] = oACU:GetPosition()
    oNewPlatoon[M27PlatoonUtilities.refiCurrentPathTarget] = 1
    oNewPlatoon:SetAIPlan('M27ACUMain')
    oACU[refbACUOnInitialBuildOrder] = false
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ResetCivilianAllianceForBrain(iOurIndex, iCivilianIndex, sRealState, oCivilianBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ResetCivilianAllianceForBrain'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Call via forkthread
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, Time='..GetGameTimeSeconds()..'; iOurIndex='..iOurIndex..'; iCivilianIndex='..iCivilianIndex..'; Is ally='..tostring(IsAlly(iOurIndex, iCivilianIndex))..'; IsEnemy='..tostring(IsEnemy(iOurIndex, iCivilianIndex))) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicks(11)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Finished waiting for some ticks, iOurIndex='..iOurIndex..'; iCivilianIndex='..iCivilianIndex..'; Is ally='..tostring(IsAlly(iOurIndex, iCivilianIndex))..'; IsEnemy='..tostring(IsEnemy(iOurIndex, iCivilianIndex))) end
    SetAlliance(iOurIndex, iCivilianIndex, sRealState)
    oCivilianBrain[refiTemporarilySetAsAllyForTeam] = nil
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if bDebugMessages == true then LOG(sFunctionRef..': Have now set alliance back to real state, Time='..GetGameTimeSeconds()..' Have just set civilian brain '..oCivilianBrain.Nickname..' back to being '..sRealState..' for iOurIndex='..iOurIndex) end
end

function RevealCiviliansToAI(aiBrain)
    --On some maps like burial mounds civilians are revealed to human players but not AI; meanwhile on other maps even if theyre not revealed to humans, the humans will likely know where the buildings are having played the map before
    --Thanks to Relent0r for providing code that I used as a starting point to achieve this
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RevealCiviliansToAI'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    WaitTicks(70) --Waiting only 5 ticks or less resulted in a strange bug where on one map when ahd 2 ACUs on the same team, the code would run for both of htem as expected, but the civilians would only be visible for one of the AI (as though making the civilian an ally had no effect for hte other); This went away when put a delay of 50 ticks; however have compatibility issues with RNG so want to wait a bit longer; waiting 60 meant it worked for M27 but didnt look like it worked for RNG (wiating 50 meant it worked for RNG but not for M27); waiting 70 meant it worked for both
    --if aiBrain:GetArmyIndex() == 3 then
    if bDebugMessages == true then LOG(sFunctionRef..': Have finished waiting, will loop throguh all brians now to look for civilians, aiBrain='..aiBrain.Nickname..' with index ='..aiBrain:GetArmyIndex()..'; M27 team='..(aiBrain.M27Team or 'nil')) end
    local tiCivilianBrains = {}
    local toCivilianBrains = {}
    local iOurIndex = aiBrain:GetArmyIndex()
    local iBrainIndex
    local sRealState
    local iTotalWait = 0
    for i, oBrain in ArmyBrains do
        iBrainIndex = oBrain:GetArmyIndex()
        if bDebugMessages == true then LOG(sFunctionRef..': Considering brain '..(oBrain.Nickname or 'nil')..' with index '..oBrain:GetArmyIndex()..' for aiBrain '..aiBrain.Nickname..'; Is enemy='..tostring(IsEnemy(iOurIndex, iBrainIndex))..'; ArmyIsCivilian(iBrainIndex)='..tostring(ArmyIsCivilian(iBrainIndex))..'; oBrain[refiTemporarilySetAsAllyForTeam]='..(oBrain[refiTemporarilySetAsAllyForTeam] or 'nil')..'; Our team='..aiBrain.M27Team) end
        if ArmyIsCivilian(iBrainIndex) then
            while(oBrain[refiTemporarilySetAsAllyForTeam] and not(oBrain[refiTemporarilySetAsAllyForTeam] == aiBrain.M27Team)) do
                WaitTicks(1)
                iTotalWait = iTotalWait + 1
                if iTotalWait >= 12 then
                    break
                end
            end
            if not(oBrain[refiTemporarilySetAsAllyForTeam]) then
                oBrain[refiTemporarilySetAsAllyForTeam] = aiBrain.M27Team
                sRealState = IsAlly(iOurIndex, iBrainIndex) and 'Ally' or IsEnemy(iOurIndex, iBrainIndex) and 'Enemy' or 'Neutral'
                SetAlliance(iOurIndex, iBrainIndex, 'Ally')
                if bDebugMessages == true then LOG(sFunctionRef..': Time='..GetGameTimeSeconds()..'; Temporarily set the brain as an ally of team '..aiBrain.M27Team..', sRealState='..sRealState) end
                table.insert(tiCivilianBrains, iBrainIndex)
                table.insert(toCivilianBrains, oBrain)
                ForkThread(ResetCivilianAllianceForBrain, iOurIndex, iBrainIndex, sRealState, oBrain)
            elseif oBrain[refiTemporarilySetAsAllyForTeam] == aiBrain.M27Team then
                table.insert(tiCivilianBrains, iBrainIndex)
                table.insert(toCivilianBrains, oBrain)
            end
            --[[M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitTicks(5)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            SetAlliance(iOurIndex, iBrainIndex, sRealState)--]]
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicks(8) --When did with just 4 tick delay had issues where getunitsaroundpoint didnt work properly; increasing to 8 tick solved this
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    M27EconomyOverseer.GetCivilianCaptureTargets(aiBrain, tiCivilianBrains, toCivilianBrains) --dont do via fork thread or wait - must be run after have made all civilians allies, but before we have reset
    --end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordTotalHumanPlayers()
    if M27Utilities.refiHumansInGame < 0 then
        M27Utilities.refiHumansInGame = 0
        for iBrain, oBrain in ArmyBrains do
            if oBrain.BrainType == 'Human' then M27Utilities.refiHumansInGame = M27Utilities.refiHumansInGame + 1 end
            --LOG('reprs of brain='..reprs(oBrain))
        end
        LOG('RecordTotalHumanPlayers: Total humans detected='..M27Utilities.refiHumansInGame)
    end
end


function OverseerInitialisation(aiBrain)
    --Below may get overwritten by later functions - this is just so we have a default/non nil value
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OverseerInitialisation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code')
    end

    --Config settings
    if ScenarioInfo.Options.AIPLatoonNameDebug == 'all' then
        M27Config.M27ShowUnitNames = true
    end



    aiBrain[refiSearchRangeForEnemyStructures] = 36 --T1 PD has range of 26, want more than this
    aiBrain[refbEnemyHasTech2PD] = false
    aiBrain[refbNeedScoutPlatoons] = false
    aiBrain[refbNeedDefenders] = false
    aiBrain[refiInitialRaiderPlatoonsWanted] = 2
    aiBrain[refbIntelPathsGenerated] = false
    aiBrain[refbConfirmedInitialRaidersHaveScouts] = false
    aiBrain[refiHighestEnemyGroundUnitHealth] = 300
    aiBrain[refiHighestMobileLandEnemyRange] = 30 --i.e. t1 arti

    --Intel BO related:
    aiBrain[refiScoutShortfallInitialRaiderOrSkirmisher] = 1
    aiBrain[refiScoutShortfallACU] = 1
    aiBrain[refiScoutShortfallPriority] = 1
    aiBrain[refiScoutShortfallIntelLine] = 1
    aiBrain[refiScoutShortfallLargePlatoons] = 1
    aiBrain[refiScoutShortfallAllPlatoons] = 1
    aiBrain[refiMAAShortfallACUPrecaution] = 1
    aiBrain[refiMAAShortfallACUCore] = 0
    aiBrain[refiMAAShortfallLargePlatoons] = 0
    aiBrain[refiMAAShortfallHighMass] = 0
    aiBrain[refiMAAShortfallBase] = 0
    aiBrain[reftiMaxFactoryByType] = { 1, 1, 0 }
    aiBrain[refiMinLandFactoryBeforeOtherTypes] = 2

    --Scout related - other
    --aiBrain[tScoutAssignedToMexLocation] = {} --now handled by m27team

    --Skirmisher
    aiBrain[refiSkirmisherMassDeathsFromLand] = 0
    aiBrain[refiSkirmisherMassDeathsAll] = 0
    aiBrain[refiSkirmisherMassKills] = 0
    aiBrain[refiSkirmisherMassBuilt] = 0

    aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] = 4
    aiBrain[M27FactoryOverseer.refiEngineerCap] = 70 --Max engis of any 1 tech level even if have spare mass (note will manually increase for tech3)
    aiBrain[M27FactoryOverseer.refiDFCap] = 150 --Max direct fire units of any 1 tech level
    aiBrain[M27FactoryOverseer.refiIndirectCap] = 150 --Max indirect fire units of any 1 tech level
    aiBrain[M27FactoryOverseer.refiMAACap] = 150 --Max MAA of any 1 tech level
    aiBrain[M27FactoryOverseer.reftiEngineerLowMassCap] = { 35, 20, 20, 20 } --Max engis to get if have low mass
    aiBrain[M27FactoryOverseer.refiMinimumTanksWanted] = 5 --SetWhetherCanPathToEnemy will update this based on pathing
    aiBrain[M27FactoryOverseer.refiAirAACap] = 250
    aiBrain[M27FactoryOverseer.refiAirScoutCap] = 35
    aiBrain[M27FactoryOverseer.refiNavalT2AndBelowCap] = 100 --max T2 and lower naval units

    aiBrain[M27PlatoonFormer.refbUsingMobileShieldsForPlatoons] = true
    aiBrain[M27PlatoonFormer.reftPriorityUnitsForShielding] = {}
    aiBrain[M27PlatoonUtilities.reftSkirmisherPlatoonWantingIntel] = {}
    aiBrain[refiCyclesThatACUHasNoPlatoon] = 0
    aiBrain[refiCyclesThatACUInArmyPool] = 0
    aiBrain[reftUnitGroupPreviousReferences] = {}

    aiBrain[refiOurHighestFactoryTechLevel] = 1
    aiBrain[refiOurHighestAirFactoryTech] = 1
    aiBrain[refiOurHighestNavalFactoryTech] = 1

    aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons] = true

    aiBrain[refiIgnoreMexesUntilThisManyUnits] = 3 --Platoons wont attack lone structures if fewer than this many units (initially)

    --ACU specific
    local oACU = M27Utilities.GetACU(aiBrain)
    while not(oACU) do
        WaitSeconds(1)
        oACU = M27Utilities.GetACU(aiBrain)
        if GetGameTimeSeconds() >= 30 then break end
    end
    if oACU then oACU[refbACUHelpWanted] = false end
    aiBrain[refbEnemyACUNearOurs] = false


    --Grand strategy:
    aiBrain[refiDefaultStrategy] = refStrategyLandMain
    aiBrain[refiAIBrainCurrentStrategy] = aiBrain[refiDefaultStrategy]
    aiBrain[reftiMexIncomePrevCheck] = {}
    aiBrain[reftiMexIncomePrevCheck][1] = 0
    aiBrain[reftEnemyNukeLaunchers] = {}
    aiBrain[reftEnemyLandExperimentals] = {}
    aiBrain[reftEnemyTML] = {}
    aiBrain[reftEnemyArtiAndExpStructure] = {}
    aiBrain[reftEnemySMD] = {}
    aiBrain[refbEnemyTMLSightedBefore] = false
    aiBrain[refbStopACUKillStrategy] = false

    --Nearest enemy and ACU and threat
    aiBrain[toEnemyBrains] = {}
    aiBrain[toAllyBrains] = {}
    local iNearestEnemyIndex = M27Logic.GetNearestEnemyIndex(aiBrain, false)
    if (not(iNearestEnemyIndex) and M27Utilities.IsTableEmpty(aiBrain[toEnemyBrains])) or aiBrain[refbNoEnemies] then
        M27Chat.SendMessage(aiBrain, 'SendGameCompatibilityWarning', 'No enemies detected for '..(aiBrain.Nickname or '')..'; The AI may not function as expected.', 0, 10)
        aiBrain[refbNoEnemies] = true
        if bDebugMessages == true then LOG(sFunctionRef..': No enemies detected for the brain so sent compatibility message, Setting no enemies to be true') end
        local tEnemyBase = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
        aiBrain[refiDistanceToNearestEnemyBase] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tEnemyBase)
        aiBrain[reftLastNearestACU] = tEnemyBase
        aiBrain[refoLastNearestACU] = nil
    else
        aiBrain[refiDistanceToNearestEnemyBase] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[M27Logic.IndexToStartNumber(iNearestEnemyIndex)])
        aiBrain[reftLastNearestACU] = M27MapInfo.PlayerStartPoints[M27Logic.IndexToStartNumber(iNearestEnemyIndex)]
        aiBrain[refoLastNearestACU] = M27Utilities.GetACU(tAllAIBrainsByArmyIndex[iNearestEnemyIndex])
    end
    aiBrain[refiLastNearestACUDistance] = M27Utilities.GetDistanceBetweenPositions(aiBrain[reftLastNearestACU], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])

    aiBrain[refiPercentageOutstandingThreat] = 0.5
    aiBrain[refiPercentageClosestFriendlyFromOurBaseToEnemy] = 0.5
    aiBrain[refiModDistFromStartNearestOutstandingThreat] = 1000
    aiBrain[refiModDistFromStartNearestThreat] = 1000
    aiBrain[reftLocationFromStartNearestThreat] = { 0, 0, 0 }
    aiBrain[refiNearestT2PlusNavalThreat] = 10000
    aiBrain[refiEnemyHighestTechLevel] = 1


    aiBrain[refiTotalEnemyLongRangeThreat] = 0
    aiBrain[refiTotalEnemyShortRangeThreat] = 1000

    M27MapInfo.SetWhetherCanPathToEnemy(aiBrain)

    ForkThread(M27Utilities.ProfilerActualTimePerTick)
    ForkThread(M27Logic.CalculateUnitThreatsByType) --Records unit threat values against the blueprint
    InitiateLandFactoryConstructionManager(aiBrain)

    ForkThread(InitiateEngineerManager, aiBrain)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicksSpecial(aiBrain, 1)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    InitiateUpgradeManager(aiBrain)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicksSpecial(aiBrain, 1)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    ForkThread(M27PlatoonFormer.PlatoonIdleUnitOverseer, aiBrain)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicksSpecial(aiBrain, 1)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    ForkThread(SwitchSoMexesAreNeverIgnored, aiBrain, 210) --e.g. on theta passage around the 3m mark raiders might still be coming across engis, so this gives extra 30s of engi hunting time

    ForkThread(RecordAllEnemiesAndAllies, aiBrain)

    ForkThread(RefreshMexPositions, aiBrain)

    ForkThread(M27AirOverseer.SetupAirOverseer, aiBrain)

    --ForkThread(M27MapInfo.RecordStartingPathingGroups, aiBrain)

    --Record base plateau pathing gropu
    aiBrain[M27MapInfo.refiOurBasePlateauGroup] = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])

    ForkThread(ACUInitialisation, aiBrain) --Gets ACU to build its first building and then form ACUMain platoon once its done

    ForkThread(RevealCiviliansToAI, aiBrain)

    ForkThread(M27Logic.DetermineEnemyScoutSpeed, aiBrain) --Will figure out the speed of scouts (except seraphim)
    ForkThread(M27MapInfo.UpdateReclaimMarkers)
    ForkThread(M27MapInfo.ReclaimManager)
    ForkThread(M27MapInfo.UpdatePlateausToExpandTo, aiBrain)
    ForkThread(M27Transport.TransportInitialisation, aiBrain)

    ForkThread(M27Chat.ConsiderPlayerSpecificMessages, aiBrain)

    ForkThread(RecordTotalHumanPlayers)

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code')
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function SendWarningIfNoM27(aiBrain)
    --Whenever an aiBrain is initialised this should be called as a fork thread
    local sFunctionRef = 'SendWarningIfNoM27'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitSeconds(5)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if not (M27Utilities.bM27AIInGame) then
        M27Chat.SendMessage(aiBrain, 'SendGameCompatibilityWarning', 'No Active M27 AI detected, disable M27AI mod to make the game run faster', 0, 1)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GameSettingWarningsAndChecks(aiBrain)
    --If unsupported settings then note at start of the game
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GameSettingWarningsAndChecks'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of compatibility check.  Size of tAllActiveM27Brains=' .. table.getsize(tAllActiveM27Brains))
    end
    local sIncompatibleMessage = ''
    local bIncompatible = false
    local bHaveOtherAIMod = false
    if not (ScenarioInfo.Options.Victory == "demoralization") then
        bIncompatible = true
        sIncompatibleMessage = sIncompatibleMessage .. ' Victory setting (non-assassination). '
    end
    if M27Utilities.IsTableEmpty(ScenarioInfo.Options.RestrictedCategories) == false then
        bIncompatible = true
        sIncompatibleMessage = sIncompatibleMessage .. ' Unit restrictions. '
    end
    if not (ScenarioInfo.Options.NoRushOption == "Off") then
        bIncompatible = true
        sIncompatibleMessage = sIncompatibleMessage .. ' No rush timer. '
    end
    if not (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]) then
        bIncompatible = true
        sIncompatibleMessage = sIncompatibleMessage .. ' Cant path to enemy base. '
    end
    --Check for non-AI sim-mods.  Thanks to Softles for pointing me towards the __active_mods variable
    local tSimMods = __active_mods or {}
    local tAIModNameWhitelist = {
        'M27AI', 'AI-Swarm', 'AI-Uveso', 'AI: DilliDalli', 'Dalli AI', 'Dilli AI', 'M20AI', 'Marlo\'s Sorian AI edit', 'RNGAI', 'SACUAI', 'M28AI'
    }

    local tAIModNameWhereExpectAI = {
        'AI-Swarm', 'AI-Uveso', 'AI: DilliDalli', 'Dalli AI', 'Dilli AI', 'M20AI', 'Marlo\'s Sorian AI edit', 'RNGAI', 'M28AI'
    }
    local tModIsOk = {}
    local bHaveOtherAI = false
    local sUnnecessaryAIMod
    local iUnnecessaryAIModCount = 0
    for iAI, sAI in tAIModNameWhitelist do
        tModIsOk[sAI] = true
    end

    local iSimModCount = 0
    local bFlyingEngineers
    for iMod, tModData in tSimMods do
        if not (tModIsOk[tModData.name]) and tModData.enabled and not (tModData.ui_only) then
            iSimModCount = iSimModCount + 1
            bIncompatible = true
            if iSimModCount == 1 then
                sIncompatibleMessage = sIncompatibleMessage .. ' SIM mods '
            else
                sIncompatibleMessage = sIncompatibleMessage .. '; '
            end
            sIncompatibleMessage = sIncompatibleMessage .. ' ' .. (tModData.name or 'UnknownName')
            if bDebugMessages == true then
                LOG('Whitelist of mod names=' .. repru(tModIsOk))
                LOG(sFunctionRef .. ' About to debug the tModData for mod ' .. (tModData.name or 'nil'))
                M27Utilities.DebugArray(tModData)
            end

            if string.find(tModData.name, 'Flying engineers') then
                bFlyingEngineers = true
                if bDebugMessages == true then LOG(sFunctionRef..': Have flying engineers mod enabled so will adjust engineer categories') end
            end
        elseif tModIsOk[tModData.name] then
            if not(bHaveOtherAIMod) then
                for iAIMod, sAIMod in tAIModNameWhereExpectAI do
                    if sAIMod == tModData.name then
                        bHaveOtherAIMod = true
                        break
                    end
                end
                if bHaveOtherAIMod then
                    --Do we have non-M27 AI?
                    for iBrain, oBrain in ArmyBrains do
                        if bDebugMessages == true then LOG(sFunctionRef..': Have another AI mod enabled. reprs of oBrain='..reprs(oBrain)..'; is BrainType empty='..tostring(oBrain.BrainType == 'nil')..'; is brian type an empty string='..tostring(oBrain.BrainType == '')) end
                        if ((oBrain.BrainType == 'AI' and not(oBrain.M27AI)) or oBrain.DilliDalli) and not(M27Logic.IsCivilianBrain(oBrain)) then
                            bHaveOtherAI = true
                            if bDebugMessages == true then LOG('Have an AI for a brain') end
                            break
                        end
                    end
                end
            end
            if bHaveOtherAIMod and not(bHaveOtherAI) then
                local bUnnecessaryMod = false
                for iAIMod, sAIMod in tAIModNameWhereExpectAI do
                    if sAIMod == tModData.name then
                        bUnnecessaryMod = true
                        break
                    end
                end
                if bUnnecessaryMod then

                    iUnnecessaryAIModCount = iUnnecessaryAIModCount + 1
                    if iUnnecessaryAIModCount == 1 then
                        sUnnecessaryAIMod = tModData.name
                    else
                        sUnnecessaryAIMod = sUnnecessaryAIMod..', '..tModData.name
                    end
                end
            end
        end
    end

    if iSimModCount > 0 then
        sIncompatibleMessage = sIncompatibleMessage .. '. '
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Finished checking compatibility; compatibility message=' .. sIncompatibleMessage .. '; iSimModCount=' .. iSimModCount)
    end

    if iSimModCount > 0 then
        --Compatibility settings - check for ACU upgrades, and change the list of preferred upgrades if a change is expected
        local iACUEnhancementCount = 0
        local tACUBPs = EntityCategoryGetUnitList(categories.COMMAND)
        local oBP
        for iBP, sUnitID in tACUBPs do
            oBP = __blueprints[sUnitID]
            if oBP.Enhancements then
                for sEnhancement, tEnhancement in oBP.Enhancements do
                    iACUEnhancementCount = iACUEnhancementCount + 1
                    if bDebugMessages == true then
                        LOG('oBP=' .. oBP.BlueprintId .. '; sEnhancement=' .. sEnhancement .. '; tEnhancement=' .. repru(tEnhancement))
                    end
                end
            end
        end
        local iExpectedCount = 92 --Use TempListAllEnhancementsForACU() function to get details
        if not (iACUEnhancementCount == iExpectedCount) then
            --Use bigger list of ACU gun upgrades
            M27Conditions.tGunUpgrades = { 'HeavyAntiMatterCannon',
                                           'CrysalisBeam', --Range
                                           'HeatSink', --Aeon
                                           'CoolingUpgrade',
                                           'RateOfFire',
                --Blackops:
                                           'JuryRiggedDisruptor',
                                           'AntiMatterCannon',
                                           'JuryRiggedZephyr',
                                           'JuryRiggedRipper',
                                           'JuryRiggedChronotron',
                                           'HeavyAntiMatterCannon',
                                           'DisruptorAmplifier',
            }
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': iACUEnhancementCount=' .. iACUEnhancementCount .. '; iExpectedCount=' .. iExpectedCount .. '; tGunUpgrades=' .. repru(M27Conditions.tGunUpgrades))
        end

        --Basic compatibiltiy with flying engineers mod - allow air engineers to be treated as engineers; also work on mods with similar effect but different name
        if not(bFlyingEngineers) and M27Utilities.IsTableEmpty(EntityCategoryGetUnitList(M27UnitInfo.refCategoryEngineer * categories.TECH1)) then bFlyingEngineers = true end
        if bFlyingEngineers then
            M27UnitInfo.refCategoryEngineer = M27UnitInfo.refCategoryEngineer + categories.ENGINEER * categories.AIR * categories.CONSTRUCTION - categories.EXPERIMENTAL
            --Update other references in case they use the old reference
            M27EngineerOverseer.refCategoryEngineer = M27UnitInfo.refCategoryEngineer
            M27Events.refCategoryEngineer = M27UnitInfo.refCategoryEngineer
            M27FactoryOverseer.refCategoryEngineer = M27UnitInfo.refCategoryEngineer
            M27PlatoonFormer.refCategoryEngineer = M27UnitInfo.refCategoryEngineer
        end
    end

    --Is our start position underwater?
    local sUnderwaterM27Brains
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Size of tAllActiveM27Brains=' .. table.getsize(tAllActiveM27Brains))
    end
    for iBrain, oBrain in tAllActiveM27Brains do
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Considering start point ' .. oBrain.M27StartPositionNumber .. ' for iBrain=' .. iBrain .. ' Nickname=' .. aiBrain.Nickname .. '; Position=' .. repru(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]) .. '; Is underwater=' .. tostring(M27MapInfo.IsUnderwater(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber])))
        end
        if M27MapInfo.IsUnderwater(M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]) then
            sUnderwaterM27Brains = (sUnderwaterM27Brains or ' ') .. oBrain.Nickname .. ' '
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Have underwater brain')
            end
        end
    end
    if sUnderwaterM27Brains then
        sIncompatibleMessage = sIncompatibleMessage .. ' Start point underwater for: ' .. sUnderwaterM27Brains
    end

    if bIncompatible then
        M27Chat.SendMessage(aiBrain, 'SendGameCompatibilityWarning', 'Less testing has been done with M27 on the following settings: ' .. sIncompatibleMessage .. ' report any issues to maudlin27 via Discord or the M27 forum thread, and include the replay ID.', 0, 10)
    end
    if bHaveOtherAIMod and not(bHaveOtherAI) and sUnnecessaryAIMod then
        M27Chat.SendMessage(aiBrain, 'UnnecessaryMods', 'No other AI detected, These AI mods can be disabled: '..sUnnecessaryAIMod, 1, 10)
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function CoordinateNovax(aiBrain)
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CoordinateNovax'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code, does our team have an active coordinator=' .. tostring((M27Team.tTeamData[aiBrain.M27Team][M27Team.refbActiveNovaxCoordinator] or false)))
    end

    if not (M27Team.tTeamData[aiBrain.M27Team][M27Team.refbActiveNovaxCoordinator]) then
        --Do we have any novax to coordinate?
        local bWantToCoordinate = true
        while bWantToCoordinate do
            bWantToCoordinate = false
            local tFriendlyNovax = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategorySatellite, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 1500, 'Ally')
            if bDebugMessages == true then LOG(sFunctionRef..': Is table of friendly novax empty='..tostring(M27Utilities.IsTableEmpty(tFriendlyNovax))) end
            if M27Utilities.IsTableEmpty(tFriendlyNovax) == false then
                local tFriendlyT3Arti = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategoryExperimentalArti, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 1000, 'Ally')
                --What is the shield power of M27 controlled units?
                local iAvailableNovax = 0
                local tAvailableNovax = {}
                for iUnit, oUnit in tFriendlyNovax do
                    if oUnit:GetFractionComplete() == 1 then
                        if oUnit:GetAIBrain().M27AI then
                            iAvailableNovax = iAvailableNovax + 1
                            tAvailableNovax[iAvailableNovax] = oUnit
                        end
                    end
                end
                --Do we have a likely shield power of at least 2?
                if M27Utilities.IsTableEmpty(tFriendlyT3Arti) == false or iAvailableNovax > 1 then
                    --Cycle through each enemy T3 arti, and pick the one with the most friendly M27 T3 arti in-range
                    local oBestPriorityTarget
                    local tFriendlyM27T3Arti = {}
                    local iFriendlyM27T3Arti = 0
                    if M27Utilities.IsTableEmpty(tFriendlyT3Arti) == false then
                        for iUnit, oUnit in tFriendlyT3Arti do
                            if oUnit:GetFractionComplete() == 1 then
                                if oUnit:GetAIBrain().M27AI then
                                    iFriendlyM27T3Arti = iFriendlyM27T3Arti + 1
                                    tFriendlyM27T3Arti[iFriendlyM27T3Arti] = oUnit
                                end
                            end
                        end
                    end
                    if iFriendlyM27T3Arti > 0 then
                        local iInRangeArti, iCurDistance
                        local iMostInRangeArti = 0
                        for iUnit, oUnit in aiBrain[reftEnemyArtiAndExpStructure] do
                            iInRangeArti = 0

                            if bDebugMessages == true then LOG(sFunctionRef..': Considering whether to target Exp structure/arti='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; fraction complete='..oUnit:GetFractionComplete()) end

                            if oUnit:GetFractionComplete() >= 0.35 then
                                for iFriendlyArti, oFriendlyArti in tFriendlyM27T3Arti do
                                    if oFriendlyArti[M27UnitInfo.refoLastTargetUnit] == oUnit then
                                        iCurDistance = M27Utilities.GetDistanceBetweenPositions(oFriendlyArti:GetPosition(), oUnit:GetPosition())
                                        if bDebugMessages == true then LOG(sFunctionRef..': Considering if in range of oFriendlyArti='..oFriendlyArti.UnitId..M27UnitInfo.GetUnitLifetimeCount(oFriendlyArti)..'; Distance='..iCurDistance) end
                                        if iCurDistance <= 825 and iCurDistance >= 150 then
                                            iInRangeArti = iInRangeArti + 1
                                        end
                                    end
                                end
                            end
                            if iInRangeArti > iMostInRangeArti then
                                oBestPriorityTarget = oUnit
                                iMostInRangeArti = iInRangeArti
                                if bDebugMessages == true then LOG(sFunctionRef..': Setting best priority target to '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                            end
                        end
                    end
                    if not (oBestPriorityTarget) then
                        --Do we have any T3 arti targets that have too few shields to handle the novax on their own?
                        local tNearbyShields
                        local iFewestShields = 10000
                        local iNearestNovax = 10000
                        local iCurDistance, iAltNearestNovax

                        for iUnit, oUnit in aiBrain[reftEnemyArtiAndExpStructure] do
                            if oUnit:GetFractionComplete() >= 0.3 then
                                tNearbyShields = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedShield, oUnit:GetPosition(), 23, 'Enemy')
                                if table.getn(tNearbyShields) <= math.min(iAvailableNovax - 1, iFewestShields) then
                                    if table.getn(tNearbyShields) < iFewestShields then
                                        iFewestShields = table.getn(tNearbyShields)
                                        oBestPriorityTarget = oUnit
                                        --Calculate the nearest novax
                                        for iNovax, oNovax in tAvailableNovax do
                                            iCurDistance = M27Utilities.GetDistanceBetweenPositions(oNovax:GetPosition(), oUnit:GetPosition())
                                            if iCurDistance < iNearestNovax then
                                                iNearestNovax = iCurDistance
                                            end
                                        end
                                    else
                                        --same number of shields as existing target, which has the closest novax
                                        for iNovax, oNovax in tAvailableNovax do
                                            iCurDistance = M27Utilities.GetDistanceBetweenPositions(oNovax:GetPosition(), oUnit:GetPosition())
                                            if iCurDistance < iNearestNovax then
                                                iNearestNovax = iCurDistance
                                                oBestPriorityTarget = oUnit
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end

                    if oBestPriorityTarget then
                        --We have a target that we want to co-ordinate an attack on
                        bWantToCoordinate = true
                        if bDebugMessages == true then LOG(sFunctionRef..': Want to coordinate attack on the target, will tell novac it has a priority target override') end
                        --Get all novax to move near the target if they are far away

                        for iNovax, oNovax in tAvailableNovax do
                            oNovax[M27AirOverseer.refoPriorityTargetOverride] = oBestPriorityTarget
                            oNovax[M27AirOverseer.refiTimeOfLastOverride] = GetGameTimeSeconds()
                        end
                    end
                end
            end
            M27Team.tTeamData[aiBrain.M27Team][M27Team.refbActiveNovaxCoordinator] = true
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitSeconds(10)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            M27Team.tTeamData[aiBrain.M27Team][M27Team.refbActiveNovaxCoordinator] = false
        end
        M27Team.tTeamData[aiBrain.M27Team][M27Team.refbActiveNovaxCoordinator] = false --redundancy
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
end

function CoordinateLandExperimentals(aiBrain)

    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CoordinateLandExperimentals'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code, refbActiveLandExperimentalCoordinator=' .. tostring((M27Team.tTeamData[aiBrain.M27Team][M27Team.refbActiveLandExperimentalCoordinator] or false)))
    end

    if not (M27Team.tTeamData[aiBrain.M27Team][M27Team.refbActiveLandExperimentalCoordinator]) then
        --Dont coordinate if we have chokepoints
        local bHaveChokepoint = false
        if not (M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27MapInfo.tiPlannedChokepointsByDistFromStart])) then
            for iBrain, oBrain in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] do
                if oBrain[refiDefaultStrategy] == refStrategyTurtle then
                    bHaveChokepoint = true
                    break
                end
            end
        end
        if not (bHaveChokepoint) then
            local bCoordinateFatboys = false
            --Only coordinate fatboys if enemy has a fatboy (otherwise we want to kite with 1 fatboy if enemy has experimental)
            if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFatboy, aiBrain[reftEnemyLandExperimentals])) == false then
                bCoordinateFatboys = true
            end

            M27Team.tTeamData[aiBrain.M27Team][M27Team.refbActiveLandExperimentalCoordinator] = true
            local tM27LandExperimentals = {}
            local iM27LandExperimentals = 0
            local tAlliedLandExperimentals = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandExperimental, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 1000, 'Ally')

            local bExperimentalsAreFarApart = true
            if bDebugMessages == true then
                if M27Utilities.IsTableEmpty(tAlliedLandExperimentals) then
                    LOG(sFunctionRef .. ': tAlliedLandExperimentals is empty')
                else
                    LOG(sFunctionRef .. ': Size of tAlliedLandExperimentals=' .. table.getn(tAlliedLandExperimentals))
                end
            end
            while bExperimentalsAreFarApart do
                bExperimentalsAreFarApart = false
                if M27Utilities.IsTableEmpty(tAlliedLandExperimentals) == false and table.getn(tAlliedLandExperimentals) >= 2 then
                    local oBrain
                    local bNearbyEnemyExperimental
                    local bCoordinateUnit
                    for iUnit, oUnit in tAlliedLandExperimentals do
                        if M27UnitInfo.IsUnitValid(oUnit) and oUnit:GetAIBrain().M27AI and (bCoordinateFatboys or not(EntityCategoryContains(M27UnitInfo.refCategoryFatboy, oUnit.UnitId))) then
                            --Only coordinate if experimental is within 150 of enemy experimental or on our side of map
                            bCoordinateUnit = false
                            bNearbyEnemyExperimental = false
                            oBrain = oUnit:GetAIBrain()
                            if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]) < oBrain[refiDistanceToNearestEnemyBase] then
                                bCoordinateUnit = true
                            else
                                --Is there a nearby enemy experimental? If not, dont coordinate as might be about to damage enemy base
                                for iEnemyExperimental, oEnemyExperimental in oBrain[reftEnemyLandExperimentals] do
                                    if M27Utilities.GetDistanceBetweenPositions(oEnemyExperimental:GetPosition(), oUnit:GetPosition()) <= 150 then
                                        bCoordinateUnit = true
                                        break
                                    end
                                end
                            end
                            if bCoordinateUnit then
                                iM27LandExperimentals = iM27LandExperimentals + 1
                                tM27LandExperimentals[iM27LandExperimentals] = oUnit
                            end
                        end
                    end
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': iM27LandExperimentals=' .. iM27LandExperimentals)
                    end

                    if iM27LandExperimentals >= 2 then
                        local tDistanceByBase = {}
                        local iClosestStartPointDistance = 100000000
                        local iClosestStartPointNumber = aiBrain.M27StartPositionNumber
                        local oClosestBrain = aiBrain

                        --Work out the closest base to the experimentals to use

                        for iBrain, oBrain in aiBrain[toAllyBrains] do
                            if oBrain.M27AI then
                                tDistanceByBase[oBrain.M27StartPositionNumber] = 0
                                for iUnit, oUnit in tM27LandExperimentals do
                                    if M27UnitInfo.IsUnitValid(oUnit) then
                                        tDistanceByBase[oBrain.M27StartPositionNumber] = tDistanceByBase[oBrain.M27StartPositionNumber] + M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber])
                                    else
                                        tM27LandExperimentals[iUnit] = nil
                                    end
                                end
                                if tDistanceByBase[oBrain.M27StartPositionNumber] < iClosestStartPointDistance then
                                    iClosestStartPointDistance = tDistanceByBase[oBrain.M27StartPositionNumber]
                                    iClosestStartPointNumber = oBrain.M27StartPositionNumber
                                    oClosestBrain = oBrain
                                end
                            end
                        end


                        --Only consider experimentals within 400 of this location, that aren't already within 50 of another experimental
                        local tRallyPoint = M27Logic.GetNearestRallyPoint(oClosestBrain, M27MapInfo.GetPrimaryEnemyBaseLocation(oClosestBrain))

                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Will be considering experimentals close to tRallyPoint=' .. repru(tRallyPoint)..'; Dist from rally point to oClosestBrain base='..M27Utilities.GetDistanceBetweenPositions(tRallyPoint, M27MapInfo.PlayerStartPoints[oClosestBrain.M27StartPositionNumber]))
                        end

                        for iUnit, oUnit in tM27LandExperimentals do
                            if M27UnitInfo.IsUnitValid(oUnit) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Considering M27 experimental ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' with aiBrain owner army index=' .. oUnit:GetAIBrain():GetArmyIndex() .. '; Position=' .. repru(oUnit:GetPosition()) .. '; Distance to rally point=' .. M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tRallyPoint) .. '; Dist to base=' .. M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[iClosestStartPointNumber]))
                                end
                                if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[iClosestStartPointNumber]) <= 400 and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tRallyPoint) >= 50 then
                                    --Do we not have allied land experimentals within 50?
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Checking there are no friendly experimentals within 40 of us; Is table empty=' .. tostring(M27Utilities.IsTableEmpty(M27UnitInfo.refCategoryLandExperimental, oUnit:GetPosition(), 40, 'Ally')))
                                    end
                                    if M27Utilities.IsTableEmpty(M27UnitInfo.refCategoryLandExperimental, oUnit:GetPosition(), 40, 'Ally') then
                                        --Update movement path to be the rally point
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Will update movement path to send it to the rally point tRallyPoint ' .. repru(tRallyPoint))
                                        end
                                        if oUnit.PlatoonHandle then
                                            bExperimentalsAreFarApart = true
                                            oUnit.PlatoonHandle[M27PlatoonUtilities.reftMovementPath] = { tRallyPoint }
                                            oUnit.PlatoonHandle[M27PlatoonUtilities.refiCurrentPathTarget] = 1
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitSeconds(10)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            end

            M27Team.tTeamData[aiBrain.M27Team][M27Team.refbActiveLandExperimentalCoordinator] = false
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function TEMPUNITPOSITIONLOG(aiBrain)
    local tAllUnits = aiBrain:GetListOfUnits(categories.ALLUNITS - categories.COMMAND, false, true)
    local iSegmentX, iSegmentZ
    local tPosition
    if M27Utilities.IsTableEmpty(tAllUnits) == false then
        for iUnit, oUnit in tAllUnits do
            tPosition = oUnit:GetPosition()
            LOG('TEMPUNITPOSITIONLOG: iUnit=' .. iUnit .. '; oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; postiion=' .. repru(oUnit:GetPosition()))
            iSegmentX, iSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tPosition)
            LOG('Segment position X-Z=' .. iSegmentX .. '-' .. iSegmentZ .. '; TerrainHeight=' .. GetTerrainHeight(tPosition[1], tPosition[3]) .. '; Surface height=' .. GetSurfaceHeight(tPosition[1], tPosition[3]))
        end
    end
end

function TempEnemyACUDirection(aiBrain)
    local sFunctionRef = 'TempEnemyACUDirection'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    while aiBrain do
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(1)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        local tAllACUs = EntityCategoryFilterDown(categories.COMMAND, GetUnitsInRect(Rect(0, 0, 1000, 1000)))
        local oEnemyACU
        for iACU, oACU in tAllACUs do
            if IsEnemy(aiBrain:GetArmyIndex(), oACU:GetAIBrain():GetArmyIndex()) then
                oEnemyACU = oACU
            end
        end
        local sBone = 'Left_Foot'
        --LOG('Position of Left foot='..repru(oEnemyACU:GetPosition(sBone)))
        LOG('ACU orientation=' .. repru(oEnemyACU:GetOrientation()))
        LOG('ACU Heading=' .. repru(oEnemyACU:GetHeading()))
        LOG('ACU Angle direction=' .. M27UnitInfo.GetUnitFacingAngle(oEnemyACU))
        LOG('ACU position=' .. repru(oEnemyACU:GetPosition()))
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function TestNewMovementCommands(aiBrain)
    local tOurStart = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    local tEnemyStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
    local iDistBetweenBases = M27Utilities.GetDistanceBetweenPositions(tOurStart, tEnemyStartPosition)
    LOG('Our start pos=' .. repru(tOurStart) .. '; Enemy start pos=' .. repru(tEnemyStartPosition) .. '; OurACUPos=' .. repru(M27Utilities.GetACU(aiBrain):GetPosition()) .. '; Distance between start points=' .. iDistBetweenBases)
    local tMapMidPointMethod1 = M27Utilities.MoveTowardsTarget(tOurStart, tEnemyStartPosition, iDistBetweenBases * 0.5, 0)
    local iAngle = M27Utilities.GetAngleFromAToB(tOurStart, tEnemyStartPosition)
    local tMapMidPointMethod2 = M27Utilities.MoveInDirection(tOurStart, iAngle, iDistBetweenBases * 0.5)

    LOG('tMapMidPointMethod1=' .. repru(tMapMidPointMethod1) .. '; tMapMidPointMethod2=' .. repru(tMapMidPointMethod2))
end

function TestCustom(aiBrain)
    WaitSeconds(5)
    local NavUtils = import("/lua/sim/navutils.lua")
    LOG('Test custoM: ScenarioInfo.size[1]='..(ScenarioInfo.size[1] or 'nil'))
    NavUtils.Generate()
    while GetGameTimeSeconds() <= 30 do
        WaitSeconds(1)
    end
    M27MapInfo.DrawAllMapPathing(aiBrain)

    --[[
    --Call T3 arti logic when first spawn via cheat
    local tAlliedT3Arti = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT3Arti, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 1000, 'Ally')
    LOG('GameTime='..GetGameTimeSeconds())
    if M27Utilities.IsTableEmpty(tAlliedT3Arti) == false then
        for iUnit, oUnit in tAlliedT3Arti do
            LOG('T3 arti turret facing direction raw output='..oUnit:GetBoneDirection('Turret'))
            local oWeapon = oUnit:GetWeapon(1)
            local oManipulator = oWeapon:GetAimManipulator()
            LOG('Aim manipulator pitch='..oManipulator:GetHeadingPitch())
            LOG('Unit info angle facing result='..M27UnitInfo.GetUnitFacingAngle(oUnit))
        end
    end
    local tEnemyT3Engineers = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryEngineer * categories.TECH3, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 1000, 'Enemy')
    if M27Utilities.IsTableEmpty(tEnemyT3Engineers) == false then
        LOG('Enemy T3 engi count='..table.getn(tEnemyT3Engineers))
    end--]]


    --Calc range of SACUs - test
    --[[local tEnemySACU = aiBrain:GetUnitsAroundPoint(categories.SUBCOMMANDER, {0,0,0}, 1000, 'Enemy')
    if M27Utilities.IsTableEmpty(tEnemySACU) == false then
        for iUnit, oUnit in tEnemySACU do
            LOG('Getting SACU range, oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; GetBlueprintMaxGroundRange(oBP)='..M27UnitInfo.GetBlueprintMaxGroundRange(oUnit:GetBlueprint())..'; GetUnitMaxGroundRange(oUnit)='..M27UnitInfo.GetUnitMaxGroundRange(oUnit)..'; GetNavalDirectAndSubRange(oUnit)='..M27UnitInfo.GetNavalDirectAndSubRange(oUnit)..'; GetUnitMaxGroundRange(tUnits)='..M27Logic.GetUnitMaxGroundRange({oUnit}))
            for sEnhancement, tEnhancement in oUnit:GetBlueprint().Enhancements do
                LOG('Does unit have enhancement '..sEnhancement..'='..tostring(oUnit:HasEnhancement(sEnhancement)))
                if oUnit:HasEnhancement(sEnhancement) then
                    LOG('NewMaxRadius='..(tEnhancement['NewMaxRadius'] or 'nil'))
                end
            end
        end
    end--]]

    --[[local tFriendlyACU = aiBrain:GetListOfUnits(ParseEntityCategory('COMMAND'))
    LOG('Is table empty='..tostring(M27Utilities.IsTableEmpty(tFriendlyACU)))
    local tAltACU = aiBrain:GetListOfUnits(ParseEntityCategory(categories.COMMAND))
    LOG('Is 2nd table empty='..tostring(M27Utilities.IsTableEmpty(tAltACU)))--]]

    --[[local tMissileShips = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryMissileShip)
    if M27Utilities.IsTableEmpty(tMissileShips) == false then
        for iUnit, oUnit in tMissileShips do
            ForkThread(M27UnitInfo.SetUnitTargetPriorities, oUnit, M27UnitInfo.refWeaponPriorityMissileShip)
            for i =1, oUnit:GetWeaponCount() do
                local wep = oUnit:GetWeapon(i)
                wep:SetTargetingPriorities(M27UnitInfo.refWeaponPriorityMissileShip)
            end
        end
    end--]]

    --M27Utilities.DrawLocation({640.69580078125, 18.948984146118, 367.01770019531}, nil, 3, 200, 4)


    --[[LOG('Table with table key will get printed to give reference')
    local tTempTable = {1,2,3}
    local tTableWithTable = {}
    tTableWithTable[tTempTable] = 1
    reprsl(tTableWithTable) --This will present as something like: info:  - table: 202107A8: 1

    if GetGameTimeSeconds() >= 1124 and GetGameTimeSeconds() <= 1126 then
        --Do reprs of certain tables
        LOG('About to start reprs. Starting with engineer reprs ')
        local E = M27EngineerOverseer
        reprsl(aiBrain[E.reftiBOActiveSpareEngineersByTechLevel])
        reprsl(aiBrain[E.reftEngineerAssignmentsByLocation])
        reprsl(aiBrain[E.reftEngineerAssignmentsByActionRef])
        reprsl(aiBrain[E.reftEngineerActionsByEngineerRef])
        reprsl(aiBrain[E.reftEngineersHelpingACU])
        reprsl(aiBrain[E.reftSpareEngineerAttackMoveTimeByLocation])
        reprsl(aiBrain[E.reftLastSuccessfulLargeBuildingLocation])
        reprsl(aiBrain[E.reftFriendlyScathis])
        reprsl(aiBrain[E.reftUnclaimedMexOrHydroByCondition])
        reprsl(aiBrain[E.reftResourceLocations])
        reprsl(aiBrain[E.reftUnitsWantingTMDByPlateau])
        reprsl(aiBrain[E.reftFirebaseUnitsByFirebaseRef])
        reprsl(aiBrain[E.reftFirebasesWantingFortification])
        reprsl(aiBrain[E.reftFirebasePosition])
        reprsl(aiBrain[E.reftFirebaseFrontPDPosition])
        reprsl(aiBrain[E.reftiFirebaseDeadPDMassCost])
        reprsl(aiBrain[E.reftiFirebaseDeadPDMassKills])
        reprsl(aiBrain[E.reftUnitsWantingFixedShield])
        reprsl(aiBrain[E.reftUnitsWithFixedShield])
        reprsl(aiBrain[E.reftFailedShieldLocations])
        reprsl(aiBrain[E.reftShieldsWantingHives])
        reprsl(aiBrain[E.reftPriorityShieldsToAssist])

        --Now do navy tables
        local N = M27Navy
        reprsl(aiBrain[N.reftiPondThreatToUs])
        reprsl(aiBrain[N.reftiPondValueToUs])
        reprsl(aiBrain[N.tPondDetails])

        --Team dta
        reprsl(M27Team.tTeamData[aiBrain.M27Team])

        reprsl(aiBrain[tiDistToPlayerByIndex])
        reprsl(aiBrain[reftACURecentHealth])
        reprsl(aiBrain[reftACURecentUpgradeProgress])
        reprsl(aiBrain[reftEnemyThreatGroup])
        reprsl(aiBrain[refsEnemyThreatGroup])
        reprsl(aiBrain[refstPrevEnemyThreatGroup])
        reprsl(aiBrain[reftoNearestEnemyBrainByGroup])
        reprsl(aiBrain[reftLocationFromStartNearestThreat])
        reprsl(aiBrain[reftEnemyGroupsThreateningBuildings])

        --ACU unit
        reprsl(M27Utilities.GetACU(aiBrain)[reftPotentialFlankingUnits])

    end--]]

    --Spawn monkeylord for enemy at certain point in game
    --[[if aiBrain:GetArmyIndex() == 4 then
        local EnemyBrain
        for iBrain, oBrain in ArmyBrains do
            if oBrain:GetArmyIndex() == 1 then
                EnemyBrain = oBrain
                break
            end
        end
        local iExistingMonkeylord = EnemyBrain:GetCurrentUnits(M27UnitInfo.refCategoryLandExperimental)
        if iExistingMonkeylord == 0 and GetGameTimeSeconds() >= 1320 then
            local tPos = M27Utilities.MoveInDirection(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[EnemyBrain.M27StartPositionNumber]), aiBrain[refiDistanceToNearestEnemyBase] * 0.35, true, false)
            local oUnitToSpawn = CreateUnit('url0402', M27Utilities.GetACU(EnemyBrain).Army, tPos[1], tPos[2], tPos[3], 0, 0, 0, 0, 'Air')
        end
    end--]]

    --Monitor location of E8 and draw it
    --[[local tEngineers = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryEngineer, false, true)
    if M27Utilities.IsTableEmpty(tEngineers) == false then
        local oEngiToMonitor
        for iEngi, oEngi in tEngineers do
            if M27EngineerOverseer.GetEngineerUniqueCount(oEngi) == 8 then
                oEngiToMonitor = oEngi
                break
            end
        end
        if oEngiToMonitor then
            local tCurNavigatorTarget
            local oNavigator = oEngiToMonitor:GetNavigator()
            if oNavigator and oNavigator.GetCurrentTargetPos then
                local tUnitTarget = oNavigator:GetCurrentTargetPos()
                if M27Utilities.IsTableEmpty(tUnitTarget) == false then
                    LOG(sFunctionRef..': GameTime='..GetGameTimeSeconds()..'; Engineer has a navigator target='..repru(tUnitTarget)..'; will draw in blue')
                    M27Utilities.DrawLocation(tUnitTarget)
                end
            end
        end
    end--]]


    --Send team chat message
    --M27Chat.SendMessage(aiBrain, 'Test', 'Hi there team', 1, 5, true)

    --[[

    if aiBrain:GetArmyIndex() == 1 or aiBrain:GetArmyIndex() == 2 then
        --Spawn a hoplie and gift it to an ally
        local tPos = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local oUnitToSpawn = CreateUnit('drl0204', M27Utilities.GetACU(aiBrain).Army, tPos[1], tPos[2], tPos[3], 0, 0, 0, 0, 'Air')

        if M27Utilities.IsTableEmpty(aiBrain[toAllyBrains]) == false then
            for iBrain, oBrain in aiBrain[toAllyBrains] do
                if not(oBrain == aiBrain) and not(iBrain == 1) and not(iBrain == 2) then
                LOG(sFunctionRef..': About to transfer unit '..oUnitToSpawn.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitToSpawn)..' from brain '..aiBrain.Nickname..' to brain '..oBrain.Nickname)
                M27Team.TransferUnitsToPlayer({ oUnitToSpawn }, oBrain:GetArmyIndex(), false)
                break
            end
            end
        end
    end--]]

    --Give resources
    --[[local oBrainToGive

    if not(aiBrain:GetArmyIndex() == 3) then
        for iBrain, oBrain in aiBrain[toAllyBrains] do
            if oBrain:GetArmyIndex() == 3 then
                oBrainToGive = oBrain
                break
            end
        end
        if aiBrain:GetEconomyStored('MASS') >= 100 then
            M27Team.GiveResourcesToPlayer(aiBrain, oBrainToGive, 100, 100)
        end
    end--]]


    --Spawn an experimental
    --local tPos = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    --CreateUnit('url0402', M27Utilities.GetACU(aiBrain).Army, tPos[1], tPos[2], tPos[3], 0, 0, 0, 0, 'Air')

    --M27MiscProfiling.ListAmphibiousUnitsMissingAmphibiousCategory()
    --LOG('Log of ScenarioInfo='..repru(ScenarioInfo))
    --[[
    --Test new GetUnitMaxGroundRange function
    local tOurUnits = aiBrain:GetListOfUnits(categories.DIRECTFIRE + categories.INDIRECTFIRE + categories.ANTIAIR, false, true)
    if M27Utilities.IsTableEmpty(tOurUnits) == false then
        for iUnit, oUnit in tOurUnits do
            LOG('Range of unit '..oUnit.UnitId..'='..M27UnitInfo.GetUnitMaxGroundRange(oUnit))
        end
    end
--]]
    --Check if experimental isnt moving
    --[[local tEnemyExperimentals = aiBrain:GetUnitsAroundPoint(categories.EXPERIMENTAL * categories.LAND, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 1000, 'Enemy')
    LOG(sFunctionRef..': table of enemy experimentals empty='..tostring(M27Utilities.IsTableEmpty(tEnemyExperimentals)))
    if M27Utilities.IsTableEmpty(tEnemyExperimentals) == false then
        for iUnit, oUnit in tEnemyExperimentals do
            LOG(sFunctionRef..': considering enemy unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; is Civilian based on flag='..tostring(oUnit.IsCivilian or false)..'; brain army index='..oUnit:GetAIBrain():GetArmyIndex()..'; function isCivilian='..tostring(M27Logic.IsCivilianBrain(oUnit:GetAIBrain()))..'; Unit state='..M27Logic.GetUnitState(oUnit))
        end
    end--]]

    --[[
    --Change a unit's speed
    local oACU = M27Utilities.GetACU(aiBrain)
    if oACU.SetSpeed then
        LOG(sFunctionRef..': Use SetSpeed')
    elseif oACU.SetSpeedMult then
        LOG(sFunctionRef..': UseSetSpeedMult')
    elseif oACU.SetMaxSpeed then
        LOG(sFunctionRef..': Use SetMaxSpeed')
    elseif oACU.Speed then
        LOG(sFunctionRef..': ACU has .speed value=' .. oACU.Speed)
    end
    --Above works for SetSpeedMult but not for the others (even if commenting out setspeedmult)
    oACU:SetSpeedMult(0.1)--]]

    --[[
    --Get the blueprint for a projectile of an SMD
    local oBP = __blueprints['ueb4302']
    local sProjectileBP = oBP.Weapon[1].ProjectileId
    LOG(sFunctionRef..': ProjectileBP='..sProjectileBP)
    local oProjectileBP = __blueprints[sProjectileBP]
    LOG('ProjectileBP mass cost='..oProjectileBP.Economy.BuildCostMass)
    local iCurUnitEnergyUsage = 0
    if EntityCategoryContains(categories.SILO, 'ueb4302') and oBP.Economy.BuildRate then
        --Dealing with a silo so need to calculate energy usage differently
        iCurUnitEnergyUsage = 0
        for iWeapon, tWeapon in oBP.Weapon do
            LOG('Considering iWeapon='..iWeapon)
            if tWeapon.MaxProjectileStorage and tWeapon.ProjectileId then
                LOG('Weapon has max projectile storage and a projectileID')
                local oProjectileBP = __blueprints[tWeapon.ProjectileId]
                if oProjectileBP.Economy and oProjectileBP.Economy.BuildCostEnergy and oProjectileBP.Economy.BuildTime > 0 and oBP.Economy.BuildRate > 0 then
                    iCurUnitEnergyUsage = oProjectileBP.Economy.BuildCostEnergy * oBP.Economy.BuildRate / oProjectileBP.Economy.BuildTime
                    break
                else
                    LOG('Weapon doesnt have economy or build cost energy or time or unit BP isnt >0')
                end
            end
        end
    end
    LOG(sFunctionRef..': iCurUnitEnergyUsage='..iCurUnitEnergyUsage)
    --]]

    --Check GetEdgeOfMapInDirection(tStart, iAngle) works:
    --[[local tEndPoint
    for iAngleRef = 1, 7 do
        tEndPoint = M27Utilities.GetEdgeOfMapInDirection(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iAngleRef * 45)
        LOG('TEST: iAngleRef='..iAngleRef..'; tEndPoint='..repru(tEndPoint)..'; Playable bounds='..repru(M27MapInfo.rMapPlayableArea)..'; will draw in coloru basedi n angle ref '..iAngleRef)
        M27Utilities.DrawLocation(tEndPoint, nil, iAngleRef, 100, nil)
    end--]]

    --[[
    --GetCategoryConditionFromUnitID(sUnitId) test

    local oACU = M27Utilities.GetACU(aiBrain)
    local iACUCategory = M27UnitInfo.GetCategoryConditionFromUnitID(oACU.UnitId)
    local tACUs = aiBrain:GetUnitsAroundPoint(iACUCategory, oACU:GetPosition(), 1000, 'Ally')
    LOG(sFunctionRef..' - is table of tACUs empty='..tostring(M27Utilities.IsTableEmpty(tACUs)))--]]

    --[[
    --EntityCategoryFilterDown test
    local tACU = aiBrain:GetListOfUnits(categories.COMMAND, false, false)
    local tFilteredList = EntityCategoryFilterDown(categories.COMMAND * categories.DIRECTFIRE, tACU)
    local tSpecialKey = {}
    tSpecialKey['abc'] = tFilteredList[1]
    local tOtherSpecialKey = {}
    tOtherSpecialKey[1] = tFilteredList[1]
    LOG('Is tACU empty='..tostring(M27Utilities.IsTableEmpty(tACU))..'; Is filtered list empty='..tostring(M27Utilities.IsTableEmpty(tFilteredList))..'; is filtered list without variable empty='..tostring(M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.COMMAND, tACU)))..'; Is filtered down of custom key empty='..tostring(M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.COMMAND, tSpecialKey)))..'; is tOtherSpecialKey[1] empty='..tostring(M27Utilities.IsTableEmpty(tOtherSpecialKey[1])))
    for iEntry, oEntry in EntityCategoryFilterDown(categories.COMMAND, tSpecialKey) do
        LOG('oEntry='..oEntry.UnitId)
    end--]]


    --[[
    --Cos testing as giving strange results
    local iDistStartToTarget = 708
    local iAngleStartToTarget = 88.045585632324
    local iAngleStartToEnemy = 90
    local iAbsAngleDif = math.abs(iAngleStartToTarget - iAngleStartToEnemy)
    LOG('iAbsAngleDif='..iAbsAngleDif..'; cos this='..math.cos(M27Utilities.ConvertAngleToRadians(iAbsAngleDif))..'; math.cos * dist='..math.cos(M27Utilities.ConvertAngleToRadians(iAbsAngleDif)) * iDistStartToTarget)
    --]]

    --List out all experimental unit BPs
    --[[
    for iUnit, oUnit in aiBrain:GetListOfUnits(categories.EXPERIMENTAL, false, true) do
        LOG('Experimental='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit))
    end
    LOG('About to print out blueprint for unit xsl04021')
    LOG(repru(__blueprints['xsl0402']))
    LOG('About to print out categories')
    LOG(repru(__blueprints['xsl04021'].Categories))
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
    M27Utilities.ErrorHandler('SHould disable for final, only for testing')
end

function TempBomberLocation(aiBrain)
    for iBrain, oBrain in aiBrain[toEnemyBrains] do
        local tStratBomber = oBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryBomber * categories.TECH3, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 10000, 'Ally')
        if M27Utilities.IsTableEmpty(tStratBomber) == false then
            local oNavigator
            local tMoveTarget
            for iBomber, oBomber in tStratBomber do
                tMoveTarget = nil
                oNavigator = oBomber:GetNavigator()
                if oNavigator and oNavigator.GetCurrentTargetPos then
                    tMoveTarget = oNavigator:GetCurrentTargetPos()
                end
                if not (tMoveTarget) then
                    tMoveTarget = { 'nil' }
                end

                LOG('iBomber=' .. iBomber .. '; oBomber position=' .. repru(oBomber:GetPosition()) .. '; bomber angle=' .. M27UnitInfo.GetUnitFacingAngle(oBomber) .. '; navigation target=' .. repru(tMoveTarget) .. '; angle to nav target=' .. M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), tMoveTarget) .. '; dist between them=' .. M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), tMoveTarget))
            end
        end
    end
end

function ConstantBomberLocation(aiBrain)
    local sFunctionRef = 'ConstantBomberLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    while not (aiBrain:IsDefeated()) and not(aiBrain.M27IsDefeated) do
        ForkThread(TempBomberLocation, aiBrain)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(1)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function TempCreateReclaim(aiBrain)
    local bp, position, orientation, mass, energy, time, deathHitBox
    bp = __blueprints['xel0305'] --percie

    position = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    orientation = M27Utilities.GetACU(aiBrain):GetOrientation()
    mass = 1000
    energy = 10
    time = 1000
    deathHitBox = 1000

    local wreck = bp.Wreckage
    local bpWreck = bp.Wreckage.Blueprint

    local prop = CreateProp(position, bpWreck)
    prop:SetOrientation(orientation, true)
    prop:SetScale(bp.Display.UniformScale)

    -- take the default center (cx, cy, cz) and size (sx, sy, sz)
    local cx, cy, cz, sx, sy, sz;
    cx = bp.CollisionOffsetX
    cy = bp.CollisionOffsetY
    cz = bp.CollisionOffsetZ
    sx = bp.SizeX
    sy = bp.SizeY
    sz = bp.SizeZ

    -- if a death animation is played the wreck hitbox may need some changes
    if deathHitBox then
        cx = deathHitBox.CollisionOffsetX or cx
        cy = deathHitBox.CollisionOffsetY or cy
        cz = deathHitBox.CollisionOffsetZ or cz
        sx = deathHitBox.SizeX or sx
        sy = deathHitBox.SizeY or sy
        sz = deathHitBox.SizeZ or sz
    end

    -- adjust the size, these dimensions are in both directions based on the center
    sx = sx * 0.5
    sy = sy * 0.5
    sz = sz * 0.5

    -- create the collision box
    prop:SetPropCollision('Box', cx, cy, cz, sx, sy, sz)

    prop:SetMaxHealth(bp.Defense.Health)
    prop:SetHealth(nil, bp.Defense.Health * (bp.Wreckage.HealthMult or 1))
    prop:SetMaxReclaimValues(time, mass, energy)

    --FIXME: SetVizToNeurals('Intel') is correct here, so you can't see enemy wreckage appearing
    -- under the fog. However the engine has a bug with prop intel that makes the wreckage
    -- never appear at all, even when you drive up to it, so this is disabled for now.
    --prop:SetVizToNeutrals('Intel')
    if not bp.Wreckage.UseCustomMesh then
        prop:SetMesh(bp.Display.MeshBlueprintWrecked)
    end

    -- This field cannot be renamed or the magical native code that detects rebuild bonuses breaks.
    prop.AssociatedBP = bp.Wreckage.IdHook or bp.BlueprintId

    LOG('TempCreateReclaim - will do a debugarray of the prop variable that gets returned')
    M27Utilities.DebugArray(prop)

    return prop
end

function TempListAllEnhancementsForACU()
    --Use e.g. for mods so can see what upgrades they have for ACUs
    --leave in but dont use rather than removing
    local tACUBPs = EntityCategoryGetUnitList(categories.COMMAND)
    local oBP
    local iEnhancementCount = 0
    for iBP, sUnitID in tACUBPs do
        oBP = __blueprints[sUnitID]
        if oBP.Enhancements then
            for sEnhancement, tEnhancement in oBP.Enhancements do
                iEnhancementCount = iEnhancementCount + 1
                LOG('oBP=' .. oBP.BlueprintId .. '; sEnhancement=' .. sEnhancement .. '; tEnhancement=' .. repru(tEnhancement))
            end
        end
    end
    LOG('TempListAllEnhancementsForACU: iEnhancementCount=' .. iEnhancementCount)
end

function OverseerManager(aiBrain)
    local bDebugMessages = false
    if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OverseerManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --With thanks to Balthazar for suggesting the below for where e.g. FAF develop has a function that isnt yet in FAF main
    _G.repru = rawget(_G, 'repru') or repr

    LOG('Start of overseer manager, personality='..(ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality or 'nil')..'; Cheat enabled='..tostring(aiBrain.CheatEnabled or false)..'; cheat pos='..(string.find(ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality, 'cheat') or 'nil')..'; reprs of aiBrain='..reprs(aiBrain))


    --[[ForkThread(RunLotsOfLoopsPreStart)
    WaitTicks(10)
    LOG('TEMPTEST REPR after 10 ticks='..repru(tTEMPTEST))--]]

    ForkThread(M27MapInfo.MappingInitialisation, aiBrain)

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Pre fork thread of player start locations')
    end
    ForkThread(M27MapInfo.RecordPlayerStartLocations, aiBrain)

    --ForkThread(M27MapInfo.RecordResourceLocations, aiBrain) --need to do after 1 tick for adaptive maps - superceded by hook into siminit
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': aiBrain:GetArmyIndex()=' .. aiBrain:GetArmyIndex() .. '; aiBrain start position=' .. (aiBrain.M27StartPositionNumber or 'nil'))
    end
    ForkThread(M27MapInfo.RecordMexNearStartPosition, aiBrain.M27StartPositionNumber, 26) --similar to the range of T1 PD


    if M27Config.M27ShowPathingGraphically == true then
        ForkThread(M27MapInfo.DrawAllMapPathing, aiBrain)
        --if bDebugMessages == true then DrawWater() end
        --ForkThread(M27MapInfo.DrawHeightMapAstro)
        --ForkThread(M27MapInfo.LogMapTerrainTypes)
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicks(1)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    ForkThread(M27MapInfo.SetupNoRushDetails, aiBrain)

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Pre wait 9 ticks')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicks(9)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Hopefully have ACU now so can re-check pathing
    --if bDebugMessages == true then LOG(sFunctionRef..': About to check pathing to mexes') end
    --ForkThread(M27MapInfo.RecheckPathingToMexes, aiBrain) --Note that this includes waitticks, so dont make any big decisions on the map until it has finished

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Post wait 10 ticks')
    end
    OverseerInitialisation(aiBrain) --sets default values for variables, and starts the factory construction manager

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Pre record resource locations fork thread')
    end

    local iSlowerCycleThreshold = 10
    local iSlowerCycleCount = 0

    --ForkThread(TempEnemyACUDirection, aiBrain)
    if M27Config.M27ShowPathingGraphically then
        M27MapInfo.TempCanPathToEveryMex(M27Utilities.GetACU(aiBrain))
    end
    ForkThread(DetermineInitialBuildOrder, aiBrain)

    ForkThread(GameSettingWarningsAndChecks, aiBrain)


    --ForkThread(M27MiscProfiling.LocalVariableImpact)

    --Log of basic info to help with debugging any replays we are sent (want this enabled/running as standard)
    local sBrainInfo = 'M27Brain overseer logic is active. Nickname=' .. aiBrain.Nickname .. '; ArmyIndex=' .. aiBrain:GetArmyIndex() .. '; Start position number=' .. aiBrain.M27StartPositionNumber .. '; Start position=' .. repru(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) .. '; Nearest enemy brain details: Name=' .. tAllAIBrainsByArmyIndex[M27Logic.GetNearestEnemyIndex(aiBrain)].Nickname .. '; ArmyIndex=' .. M27Logic.GetNearestEnemyIndex(aiBrain) .. '; Start position=' .. M27Logic.GetNearestEnemyStartNumber(aiBrain) .. '; Start position=' .. repru(M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])..'; Plateau '..(M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) or 'nil')
    if bDebugMessages == true then LOG(sFunctionRef..': reprs of brain='..reprs(aiBrain)) end

    if aiBrain.CheatEnabled then
        sBrainInfo = sBrainInfo..' Cheating AI with modifier '..(ScenarioInfo.Options.CheatMult or 1)..'; HasMapOmni='..tostring(ScenarioInfo.Options.OmniCheat == 'on')
    else
        sBrainInfo = sBrainInfo..' Non-cheating AI'
    end
    LOG(sBrainInfo)


    --ForkThread(TempCreateReclaim, aiBrain)

    --Start of game - wait until units can build (seems to be around 4.5-5s)
    while (GetGameTimeSeconds() <= 4.5) do
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(1)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    end

    --Start team resource monitor (need to do after overseer initialisation, as need the forked thread recording allies and enemies to have run so we know if we have teammates or not)
    if bDebugMessages == true then LOG(sFunctionRef..': About to start a forked thread for team resource sharing monitor if we have ally brains. Is table of ally brains empty for brain '..aiBrain.Nickname..'='..tostring(M27Utilities.IsTableEmpty(aiBrain[toAllyBrains]))) end
    if M27Utilities.IsTableEmpty(aiBrain[toAllyBrains]) == false then
        ForkThread(M27Team.TeamResourceSharingMonitor, aiBrain.M27Team)
        if bDebugMessages == true then LOG(sFunctionRef..': Started team resource sharing monitor for team='..aiBrain.M27Team) end
    end

    --ForkThread(ConstantBomberLocation, aiBrain)
    --ForkThread(TestCustom, aiBrain)



    local bSetHook = false
    local iTicksWaitedThisCycle = 0
    local iTicksToWait
    local iCost

    iSystemTimeBeforeStartOverseerLoop = GetSystemTimeSecondsOnlyForProfileUse()

    while (not (aiBrain:IsDefeated())) do
        --M27IsDefeated check is below

        --TestCustom(aiBrain)
        --if GetGameTimeSeconds() >= 300 then bDebugMessages = true M27Config.M27ShowUnitNames = true M27Config.M27ShowEnemyUnitNames = true LOG('GameTime='..GetGameTimeSeconds()) bDebugMessages = false end
        --if GetGameTimeSeconds() >= 149 then bDebugMessages = true M27Config.M27RunProfiling = true ForkThread(M27Utilities.ProfilerActualTimePerTick) end
        --[[if not(bSetHook) and GetGameTimeSeconds() >= 149 then
            bDebugMessages = true
            bSetHook = true
            M27Utilities.bGlobalDebugOverride = true
            debug.sethook(M27Utilities.OutputRecentFunctionCalls, "c", 200)
            LOG('Have started the main hook of function calls')
        end--]]


        if aiBrain.M27IsDefeated then
            break
        end

        iTicksWaitedThisCycle = 0

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Start of cycle, GameTIme=' .. GetGameTimeSeconds())
        end

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': refbIntelPathsGenerated=' .. tostring(aiBrain[refbIntelPathsGenerated]))
        end
        if aiBrain[refbIntelPathsGenerated] == false then
            ForkThread(RecordIntelPaths, aiBrain)
        end
        if aiBrain[refbIntelPathsGenerated] == true then
            ForkThread(AssignScoutsToPreferredPlatoons, aiBrain)
        end
        if aiBrain.M27IsDefeated then break end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        iTicksToWait = _G.MyM27Scheduler:WaitTicks(1, 2, 0.08) --MAA wait
        --[[if not (WaitTicksSpecial(aiBrain, iTicksToWait)) then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            break
        end--]]
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        iTicksWaitedThisCycle = iTicksWaitedThisCycle + iTicksToWait

        ForkThread(AssignMAAToPreferredPlatoons, aiBrain) --No point running logic for MAA helpers if havent created any scouts
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': pre threat assessment. GameTime=' .. GetGameTimeSeconds())
            --ArmyPoolContainsLandFacTest(aiBrain)
            --M27EngineerOverseer.TEMPTEST(aiBrain)
            DebugPrintACUPlatoon(aiBrain)
        end
        if aiBrain.M27IsDefeated then break end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        iTicksToWait = _G.MyM27Scheduler:WaitTicks(1, 2, 2) --Threat assess

        --[[if not (WaitTicksSpecial(aiBrain, iTicksToWait)) then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            break
        end--]]
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        iTicksWaitedThisCycle = iTicksWaitedThisCycle + iTicksToWait
        ForkThread(ThreatAssessAndRespond, aiBrain)
        --if bDebugMessages == true then ArmyPoolContainsLandFacTest(aiBrain) end

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': post threat assessment pre ACU manager. GameTime=' .. GetGameTimeSeconds())
            --ArmyPoolContainsLandFacTest(aiBrain)
            --M27EngineerOverseer.TEMPTEST(aiBrain)
        end

        if aiBrain.M27IsDefeated then break end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        iTicksToWait = _G.MyM27Scheduler:WaitTicks(1, 2, 0.2) --ACU manager

        --[[if not (WaitTicksSpecial(aiBrain, iTicksToWait)) then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            break
        end--]]
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        iTicksWaitedThisCycle = iTicksWaitedThisCycle + iTicksToWait
        ForkThread(ACUManager, aiBrain)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': post ACU manager, pre wait 10 ticks. GameTime=' .. GetGameTimeSeconds())
            DebugPrintACUPlatoon(aiBrain)
            --ArmyPoolContainsLandFacTest(aiBrain)
            --M27EngineerOverseer.TEMPTEST(aiBrain)
        end

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Waited 1 tick; platoon name is:')
            DebugPrintACUPlatoon(aiBrain)
            --ArmyPoolContainsLandFacTest(aiBrain)
            --M27EngineerOverseer.TEMPTEST(aiBrain)
        end

        iCost = 1
        if iSlowerCycleCount <= 1 then iCost = iCost + 0.15 end
        if aiBrain.M27IsDefeated then break end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        iTicksToWait = _G.MyM27Scheduler:WaitTicks(1, 2, iCost) --Strategic overseer

        --[[if not (WaitTicksSpecial(aiBrain, iTicksToWait)) then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            break
        end--]]
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        iTicksWaitedThisCycle = iTicksWaitedThisCycle + iTicksToWait
        iSlowerCycleCount = iSlowerCycleCount - 1
        ForkThread(StrategicOverseer, aiBrain, iSlowerCycleCount)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Just called strategic overseer. GetGameTimeSeconds()=' .. GetGameTimeSeconds())
        end
        if iSlowerCycleCount <= 0 then
            iSlowerCycleCount = iSlowerCycleThreshold
            ForkThread(EnemyThreatRangeUpdater, aiBrain)
            ForkThread(PlatoonNameUpdater, aiBrain)
            if bDebugMessages == true then
                --ArmyPoolContainsLandFacTest(aiBrain)
                --M27EngineerOverseer.TEMPTEST(aiBrain)
            end
        end
        if aiBrain.M27IsDefeated then break end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        iTicksToWait = _G.MyM27Scheduler:WaitTicks(1, 2, 0.22) --Refresh economy data

        --[[if not (WaitTicksSpecial(aiBrain, iTicksToWait)) then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            break
        end--]]
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        iTicksWaitedThisCycle = iTicksWaitedThisCycle + iTicksToWait
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Just waited 1 tick, about to call refresheconomydata.  GetGameTimeSeconds()=' .. GetGameTimeSeconds())
        end
        ForkThread(M27EconomyOverseer.RefreshEconomyData, aiBrain)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Just sent forked request to refresh economy data. GetGameTimeSeconds()=' .. GetGameTimeSeconds())
        end

        --Update enemy unit names (only does if the config setting is set, and caps the number of units that will be updated; also ignores if are already in the process of updating)
        ForkThread(UpdateAllNonM27Names)

        --Update team data (will check to avoid updating multiple times each cycle):
        ForkThread(M27Team.UpdateSubteamDataForFriendlyUnits, aiBrain)

        --NOTE: We dont have the number of ticks below as 'available' for use, since on initialisation we're waiting ticks as well when initialising things such as the engineer and upgrade overseers which work off their own loops
        --therefore the actual available tick count will be the below number less the number of ticks we're already waiting
        if aiBrain.M27IsDefeated then break end

        --Call separate code to run navy (note this has its own wait ticks incorporated):
        ForkThread(M27Navy.ManageNavyMainLoop, aiBrain)

        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        iTicksToWait = _G.MyM27Scheduler:WaitTicks(math.max(1, 10 - iTicksWaitedThisCycle), 5, 1) --wait for the start of the loop (scout scheduler)

        --[[if not (WaitTicksSpecial(aiBrain, 4)) then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            break
        end--]]
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Just waited 4 ticks. GetGameTimeSeconds()=' .. GetGameTimeSeconds())
        end

        if bDebugMessages == true then
            --ArmyPoolContainsLandFacTest(aiBrain)
            --M27EngineerOverseer.TEMPTEST(aiBrain)
            if M27Utilities.GetACU(aiBrain).GetNavigator and M27Utilities.GetACU(aiBrain):GetNavigator().GetCurrentTargetPos then
                LOG('ACU has a target in its navigator (wont reproduce to avoid desync)')
            end
            LOG(sFunctionRef .. ': End of overseer cycle code (about to start new cycle) ACU platoon=')
            DebugPrintACUPlatoon(aiBrain)
        end

        --iTempProfiling = M27Utilities.ProfilerTimeSinceLastCall('End of overseer', iTempProfiling)

        --M27Utilities.ProfilerOutput() --Handled via the time per tick
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end
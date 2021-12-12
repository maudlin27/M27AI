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

--Semi-Global for this code:
local bACUIsDefending
refbACUOnInitialBuildOrder = 'M27ACUOnInitialBuildOrder' --local variable for ACU, determines whether ACUmanager is running or not
local iLandThreatSearchRange = 1000
refbACUHelpWanted = 'M27ACUHelpWanted' --flags if we want teh ACU to stay in army pool platoon so its available for defence
refoStartingACU = 'M27PlayerStartingACU' --NOTE: Use M27Utilities.GetACU(aiBrain) instead of getting this directly (to help with crash control)
AllAIBrainsBackup = {} --Stores table of all aiBrains, used as sometimes are getting errors when trying to use ArmyBrains
--AnotherAIBrainsBackup = {}
toEnemyBrains = {}
iACUDeathCount = 0
iDistanceFromBaseToBeSafe = 55 --If ACU wants to run (<50% health) then will think its safe once its this close to our base
iDistanceFromBaseWhenVeryLowHealthToBeSafe = 25 --As above but when ACU on lower health

refiACUHealthToRunOn = 'M27ACUHealthToRunOn'
iACUEmergencyHealthPercentThreshold = 0.3

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
    local refiModDistanceFromEnemy = 'M27ModDistanceFromEnemy' --Distance that enemy threat group is from our start (adjusted to factor in distance from mid as well)
    local refiActualDistanceFromEnemy = 'M27ActualDistanceFromEnemy'
refstPrevEnemyThreatGroup = 'M27PrevEnemyThreatRefTable'
refbUnitAlreadyConsidered = 'M27UnitAlreadyConsidered'
refiAssignedThreat = 'M27OverseerUnitAssignedThreat' --recorded against oEnemyUnit[iOurBrainArmyIndex]
refiUnitNavalAAThreat = 'M27OverseerUnitThreat' --Recored against individual oEnemyUnit[iOurBrainArmyIndex]
local reftUnitGroupPreviousReferences = 'M27UnitGroupPreviousReferences'
refiNearestOutstandingThreat = 'M27NearestOutstandingThreat' --Mod distance of the closest enemy threat (using GetDistanceFromStartAdjustedForDistanceFromMid)
refiPercentageOutstandingThreat = 'M27PercentageOutstandingThreat' --% of moddistance
refiPercentageClosestFriendlyToEnemyBase = 'M27OverseerPercentageClosestFriendly'
refiMaxDefenceCoverageWanted = 'M27OverseerMaxDefenceCoverageWanted'

--Big enemy threats (impact on strategy and/or engineer build order)
reftEnemyGroundExperimentals = 'M27OverseerEnemyGroundExperimentals'
reftEnemyNukeLaunchers = 'M27OverseerEnemyNukeLaunchers'
refiEnemyHighestTechLevel = 'M27OverseerEnemyHighestTech'

--Platoon references
--local bArmyPoolInAvailablePlatoons = false
sDefenderPlatoonRef = 'M27DefenderAI'
sIntelPlatoonRef = 'M27IntelPathAI'

--Build condition related - note that overseer start shoudl set these to false to avoid error messages when build conditions check their status
refbNeedDefenders = 'M27NeedDefenders'
refbNeedIndirect = 'M27NeedIndirect'
refbNeedT2PlusIndirect = 'M27NeedT2PlusIndirect'
refbNeedScoutPlatoons = 'M27NeedScoutPlatoons'
refbNeedMAABuilt = 'M27NeedMAABuilt'
refbEmergencyMAANeeded = 'M27OverseerNeedEmergencyMAA'
refbUnclaimedMexNearACU = 'M27UnclaimedMexNearACU'
refbReclaimNearACU = 'M27M27IsReclaimNearACU'
refoReclaimNearACU = 'M27ReclaimObjectNearACU'
refiScoutShortfallInitialRaider = 'M27ScoutShortfallRaider'
refiScoutShortfallACU = 'M27ScoutShortfallRaider'
refiScoutShortfallIntelLine = 'M27ScoutShortfallRaider'
refiScoutShortfallLargePlatoons = 'M27ScoutShortfallRaider'
refiScoutShortfallAllPlatoons = 'M27ScoutShortfallRaider'
refiScoutShortfallMexes = 'M27ScoutShortfallMexes'

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
refiACULastTakenUnseenDamage = 'M27OverseerACULastTakenUnseenDamage' --Used to determine if ACU should run or not
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



--Helper related
refoUnitsScoutHelper = 'M27UnitsScoutHelper'
refoUnitsMAAHelper = 'M27UnitsMAAHelper' --MAA platoon assigned to help a unit (e.g. the ACU)



--Grand strategy related
refiAIBrainCurrentStrategy = 'M27GrandStrategyRef'
refStrategyLandEarly = 1 --initial build order and pre-ACU gun upgrade approach
refStrategyLandAttackBase = 2 --e.g. for when have got gun upgrade on ACU
refStrategyLandConsolidate = 3 --e.g. for if ACU retreating after gun upgrade and want to get map control and eco
refStrategyLandKillACU = 4 --all-out attack on enemy ACU
refStrategyEcoAndTech = 5 --Focus on upgrading buildings

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
    local iModDistance = 0
    local iMidDistanceFactor = 0.6 --e.g. at 1 then will treat the midpoint between 2 bases as equal in distance as a corner point thats equal distance between 2 bases and also the same distance to mid.  If <1 then will instead treat the actual mid position as being closer
    if M27Utilities.IsTableEmpty(tLocationTarget) == true then
        M27Utilities.ErrorHandler('tLocationTarget is empty')
    else
        local iEnemyStartNumber, iOurStartNumber
        if bUseEnemyStartInstead == true then
            iOurStartNumber = M27Logic.GetNearestEnemyStartNumber(aiBrain)
            iEnemyStartNumber = aiBrain.M27StartPositionNumber
        else
            iOurStartNumber = aiBrain.M27StartPositionNumber
            iEnemyStartNumber = M27Logic.GetNearestEnemyStartNumber(aiBrain)
        end
        local tStartPosition = M27MapInfo.PlayerStartPoints[iOurStartNumber]
        local tEnemyPosition = M27MapInfo.PlayerStartPoints[iEnemyStartNumber]
        local iDistanceFromEnemyToUs = M27Utilities.GetDistanceBetweenPositions(tEnemyPosition, tStartPosition)
        --function MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
        local tMidpointBetweenUsAndEnemy = M27Utilities.MoveTowardsTarget(tStartPosition, tEnemyPosition, iDistanceFromEnemyToUs / 2, 0)
        local iActualDistance = M27Utilities.GetDistanceBetweenPositions(tStartPosition, tLocationTarget)
        local iDistanceToMid = M27Utilities.GetDistanceBetweenPositions(tMidpointBetweenUsAndEnemy, tLocationTarget)
        iModDistance = iActualDistance - iDistanceToMid * 0.6
    end
    return iModDistance
end

function RecordIntelPaths(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'RecordIntelPaths'
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
            for iScout, oScoutBP in tScoutsToBuild do
                iScoutRange = oScoutBP.Intel.RadarRadius
                if iScoutRange > 20 then break end
            end
        end
        if iScoutRange == nil or iScoutRange <= 20 then iScoutRange = iDefaultScoutRange end
        local sPathingType = M27UnitInfo.refPathingTypeLand --want land even for aeon so dont have massive scout lines across large oceans
        local iSegmentX, iSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        local iStartingGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathingType, iSegmentX, iSegmentZ)

        local iPlayerStartNumber = aiBrain.M27StartPositionNumber
        local iEnemyStartNumber = M27Logic.GetNearestEnemyStartNumber(aiBrain)
        if iEnemyStartNumber == nil then
            M27Utilities.ErrorHandler('iEnemyStartNumber is nil')
        else
            if bDebugMessages == true then LOG(sFunctionRef..': iPlayerStartNumber='..iPlayerStartNumber) end
            if bDebugMessages == true then LOG(sFunctionRef..'; iEnemyStartNumber='..iEnemyStartNumber) end
            if bDebugMessages == true then LOG(sFunctionRef..': PlayerStartPos repr='..repr(M27MapInfo.PlayerStartPoints[iPlayerStartNumber])) end
            if bDebugMessages == true then LOG(sFunctionRef..': Enemy Start Pos repr='..repr(M27MapInfo.PlayerStartPoints[iEnemyStartNumber])) end
            local iDistToEnemy = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[iPlayerStartNumber], M27MapInfo.PlayerStartPoints[iEnemyStartNumber])
            if bDebugMessages == true then LOG(sFunctionRef..': iPlayerStartNumber='..iPlayerStartNumber..'; iEnemyStartNumber='..iEnemyStartNumber..'; iDistToEnemy from our start='..iDistToEnemy) end
            local iIntelLineTotal = (iDistToEnemy - iScoutRange * 2) / iScoutRange - 1 + 2 --Number of points that will be plotting for intel lines
            if iIntelLineTotal <= 0 then iIntelLineTotal = 1 end
            local rPlayableArea = M27MapInfo.rMapPlayableArea
            local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
            local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]

            --Determine co-ordinates for the midpoints for each intel line:
            aiBrain[reftIntelLinePositions] = {}
            local iDistanceAlongPath
            local iDistanceAlongSubpath
            local bContinueSubpath
            local iSubpathCount
            local iValidSubpathCount
            local iSubpathLoopCheck = 1000 --Code will abort if >1000 (large maps like frostmill ruins can go above 100 if doing amphibious pathing)
            local iSubpathAngle
            local bContinueFor90, bContinueFor270, bContinueCombined
            local tPossiblePosition = {}
            local iCorePathDistanceMod = 0
            local iSubpathTempDistanceMod
            local bSubpathIsValid
            local iMaxLoop = iMapSizeX
            if iMapSizeX < iMapSizeZ then iMaxLoop = iMapSizeZ end
            local iLoopCount
            local bInSameGroup
            if bDebugMessages == true then LOG(sFunctionRef..'; Map size (only used now to determine max loop - i.e. the size of playable area end-playable area start): iMapSizeX='..iMapSizeX..'; iMapSizeZ='..iMapSizeZ) end
            local iCurPathingGroup, iTargetSegmentX, iTargetSegmentZ, iSubpathPathingGroup, iSubpathSegmentX, iSubpathSegmentZ
            local tLastSubpathDistanceFromStartByAngle = {} --[x] = 90 or 270;
            tLastSubpathDistanceFromStartByAngle[90] = 0
            tLastSubpathDistanceFromStartByAngle[270] = 0
            for iCurIntelLine = 1, iIntelLineTotal do
                --if iCurIntelLine == 6 then bDebugMessages = true else bDebugMessages = false end
                iDistanceAlongPath = iScoutRange * iCurIntelLine
                aiBrain[reftIntelLinePositions][iCurIntelLine] = {}
                aiBrain[reftIntelLinePositions][iCurIntelLine][1] = {}
                tPossiblePosition = M27Utilities.MoveTowardsTarget(M27MapInfo.PlayerStartPoints[iPlayerStartNumber], M27MapInfo.PlayerStartPoints[iEnemyStartNumber], iDistanceAlongPath)
                --Check if can path to tPossiblePosition; if can't, then need to move down path until mod is half of intel range, and if still not valid then move up path
                --InSameSegmentGroup(oUnit, tDestination, bReturnUnitGroupOnly)
                iLoopCount = 0
                iTargetSegmentX, iTargetSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tPossiblePosition)
                iCurPathingGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathingType, iTargetSegmentX, iTargetSegmentZ)
                if iCurPathingGroup == iStartingGroup then bInSameGroup = true else bInSameGroup = false end
                if bDebugMessages == true then LOG(sFunctionRef..' start of iCurIntelLine; iCurIntelLine='..iCurIntelLine..'; iCurPathingGroup='..iCurPathingGroup..'; iStartingGroup='..iStartingGroup..'; InSameGroup='..tostring(bInSameGroup)) end
                local btMaxMapSizeCount = {}
                local iType = 0
                while bInSameGroup == false do
                    if bDebugMessages == true then LOG(sFunctionRef..': '..iLoopCount..': intel path for iCurIntelLine='..iCurIntelLine..' isnt in same segment group as possible location='..repr(tPossiblePosition)..'; will try adjusting; iCorePathDistanceMod='..iCorePathDistanceMod..'; iLoopCount='..iLoopCount..'; iMaxLoop='..iMaxLoop) end
                    iLoopCount = iLoopCount + 1
                    if iLoopCount > iMaxLoop then
                        M27Utilities.ErrorHandler('Exceeded max loop count; iCurIntelLine='..iCurIntelLine)
                        break
                    end

                    if iCorePathDistanceMod < 0 and not(btMaxMapSizeCount[iType] == true) then
                        iType = 1
                        iCorePathDistanceMod = iCorePathDistanceMod - 1
                        if iCorePathDistanceMod < -(iScoutRange / 2) then iCorePathDistanceMod = 1 end
                    else
                        iCorePathDistanceMod = iCorePathDistanceMod + 1
                        iType = 2
                        if btMaxMapSizeCount[iType] == true then break end
                    end

                    tPossiblePosition = M27Utilities.MoveTowardsTarget(M27MapInfo.PlayerStartPoints[iPlayerStartNumber], M27MapInfo.PlayerStartPoints[iEnemyStartNumber], iDistanceAlongPath + iCorePathDistanceMod)

                    iTargetSegmentX, iTargetSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tPossiblePosition)
                    iCurPathingGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathingType, iTargetSegmentX, iTargetSegmentZ)
                    if iCurPathingGroup == iStartingGroup then bInSameGroup = true else bInSameGroup = false end

                    if tPossiblePosition[1] >= rPlayableArea[3] - 1 or tPossiblePosition[1] <= rPlayableArea[1] + 1 or tPossiblePosition[3] >= rPlayableArea[4] - 1 or tPossiblePosition[3] <= rPlayableArea[2] + 1 then
                        btMaxMapSizeCount[iType] = true
                    end
                end
                aiBrain[reftIntelLinePositions][iCurIntelLine][1] = tPossiblePosition

                if bDebugMessages == true then LOG(sFunctionRef..': About to reset subpathdistancefromstart and other variables; reftIntelLinePositions[Cur][1]='..repr(aiBrain[reftIntelLinePositions][iCurIntelLine][1])) end
                if bDebugMessages == true then M27Utilities.DrawLocations({aiBrain[reftIntelLinePositions][iCurIntelLine][1]}) end
                bContinueSubpath = true
                iSubpathCount = 0
                iValidSubpathCount = 0
                iSubpathAngle = 90
                bContinueFor90 = true bContinueFor270 = true
                local iInfiniteLoopCheck = 100
                iSubpathTempDistanceMod = 0
                tLastSubpathDistanceFromStartByAngle[90] = 0
                tLastSubpathDistanceFromStartByAngle[270] = 0

                while bContinueSubpath == true do
                    iSubpathCount = iSubpathCount + 1
                    bSubpathIsValid = false
                    if iSubpathCount > iSubpathLoopCheck then
                        M27Utilities.ErrorHandler('Likely infinite loop, iSubpathCount > '..iSubpathLoopCheck..'; iCurIntelLine='..iCurIntelLine)
                        break
                    end
                    if iSubpathAngle == 90 then
                        bContinueCombined = bContinueFor90
                    else
                        bContinueCombined = bContinueFor270
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..' Intel Path'..iCurIntelLine..': iSubpathCount='..iSubpathCount..': bContinueFor90='..tostring(bContinueFor90)..'; bContinueFor270='..tostring(bContinueFor270)..'; bContinueCombined='..tostring(bContinueCombined)..'; tLastSubpathDistanceFromStartByAngle='..repr(tLastSubpathDistanceFromStartByAngle)) end
                    if bContinueCombined == true then
                        bSubpathIsValid = true
                        iValidSubpathCount = iValidSubpathCount + 1
                        iDistanceAlongSubpath = iScoutRange + tLastSubpathDistanceFromStartByAngle[iSubpathAngle]
                        tPossiblePosition = M27Utilities.MoveTowardsTarget(aiBrain[reftIntelLinePositions][iCurIntelLine][1], M27MapInfo.PlayerStartPoints[iEnemyStartNumber], iDistanceAlongSubpath, iSubpathAngle)

                        iLoopCount = 0

                        iSubpathSegmentX, iSubpathSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tPossiblePosition)
                        iSubpathPathingGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathingType, iSubpathSegmentX, iSubpathSegmentZ)
                        iSubpathTempDistanceMod = 0
                        if bDebugMessages == true then LOG(sFunctionRef..': iSubpathPathingGroup='..iSubpathPathingGroup..'; tPossiblePosition='..repr(tPossiblePosition)..'; iDistanceAlongSubpath='..iDistanceAlongSubpath..'; tPossiblePosition='..repr(tPossiblePosition)..'; tLastSubpathDistanceFromStartByAngle='..repr(tLastSubpathDistanceFromStartByAngle)..'; iSubpathTempDistanceMod='..iSubpathTempDistanceMod) end
                        while not(iSubpathPathingGroup == iStartingGroup) do
                            if bDebugMessages == true then LOG(sFunctionRef..': '..iLoopCount..': Subpath intel path for iCurIntelLine='..iCurIntelLine..' isnt in same segment group as possible location='..repr(tPossiblePosition)..'; will try adjusting; iCorePathDistanceMod='..iCorePathDistanceMod) end
                            iLoopCount = iLoopCount + 1
                            if iLoopCount > iMaxLoop then
                                M27Utilities.ErrorHandler('Exceeded max loop count; iCurIntelLine='..iCurIntelLine)
                                break
                            end

                            if iSubpathTempDistanceMod <= 0 then
                                iSubpathTempDistanceMod = iSubpathTempDistanceMod - 1
                                if iSubpathTempDistanceMod < -(iScoutRange / 2) then iSubpathTempDistanceMod = 1 end
                            else iSubpathTempDistanceMod = iSubpathTempDistanceMod + 1 end


                            tPossiblePosition = M27Utilities.MoveTowardsTarget(aiBrain[reftIntelLinePositions][iCurIntelLine][1], M27MapInfo.PlayerStartPoints[iEnemyStartNumber], iDistanceAlongSubpath + iSubpathTempDistanceMod, iSubpathAngle)
                            if tPossiblePosition[1] <= rPlayableArea[1] + 1 or tPossiblePosition[3] <= rPlayableArea[2] + 1 or tPossiblePosition[1] >= (rPlayableArea[3]-1) or tPossiblePosition[3] >= (rPlayableArea[4]-1) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Are outside playable area='..repr(rPlayableArea)) end
                                break
                            end

                            iSubpathSegmentX, iSubpathSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tPossiblePosition)
                            iSubpathPathingGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathingType, iSubpathSegmentX, iSubpathSegmentZ)
                        end
                        if iSubpathPathingGroup == nil then
                            M27Utilities.ErrorHandler('iSubpathingGroup is nil; tPossiblePosition='..repr(tPossiblePosition)..'; iSubpathSegmentX-Z='..iSubpathSegmentX..'-'..iSubpathSegmentZ..'; sPathingType='..sPathingType..'; iStartingGroup='..iStartingGroup..'; iSubpathCount='..iSubpathCount..'; iSubpathAngle='..iSubpathAngle..'; iScoutRange='..iScoutRange..'; tLastSubpathDistanceFromStartByAngle='..repr(tLastSubpathDistanceFromStartByAngle)..'; rPlayableArea='..repr(rPlayableArea))
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Should have a valid location for next point on subpath now; tPossiblePosition='..repr(tPossiblePosition)..'; iSubpathPathingGroup='..iSubpathPathingGroup..'; iStartingGroup='..iStartingGroup..'; will update the tLastSubpathDistanceFromStartByAngle value for this angle, iSubpathAngle='..iSubpathAngle..'; distance along path that resulted in this pre mod='..iDistanceAlongSubpath..'; iSubpathTempDistanceMod='..iSubpathTempDistanceMod) end
                        tLastSubpathDistanceFromStartByAngle[iSubpathAngle] = iDistanceAlongSubpath + iSubpathTempDistanceMod
                        if bDebugMessages == true then LOG(sFunctionRef..': tLastSubpathDistanceFromStartByAngle[iSubpathAngle] post update='..repr(tLastSubpathDistanceFromStartByAngle[iSubpathAngle])) end

                        --aiBrain[reftIntelLinePositions][iCurIntelLine][iValidSubpathCount + 1] = tPossiblePosition
                        --if bDebugMessages == true then LOG(sFunctionRef..'; iValidSupbathCount='..iValidSubpathCount..'; about to consider if should remove valid supbath; Pos='..repr(aiBrain[reftIntelLinePositions][iCurIntelLine][iValidSubpathCount + 1])) end
                        if tPossiblePosition[1] >= (rPlayableArea[3]-1) or tPossiblePosition[1] <= rPlayableArea[1] + 1 or tPossiblePosition[3] >= (rPlayableArea[4] - 1) or tPossiblePosition[3] <= rPlayableArea[2] + 1 then
                            bSubpathIsValid = false
                            if bDebugMessages == true then LOG(sFunctionRef..': Subpath is not valid as outside playable area; tPossiblePosition='..repr(tPossiblePosition)..'; iValidSubpathCount+1 pos after removal='..repr(aiBrain[reftIntelLinePositions][iCurIntelLine][iValidSubpathCount + 1])) end
                            iValidSubpathCount = iValidSubpathCount - 1
                            if bDebugMessages == true then LOG(sFunctionRef..'; Subpath wasnt valid so ahve removed; iValidSupbathCount='..iValidSubpathCount) end
                            if iSubpathAngle == 90 then
                                bContinueFor90 = false
                                if bContinueFor270 == false then
                                    bContinueSubpath = false
                                    if bDebugMessages == true then LOG(sFunctionRef..': Aborting subpath for both 90 and 270 angles so still stop looking for subpaths now') end
                                    break
                                end
                            elseif iSubpathAngle == 270 then
                                bContinueFor270 = false
                                if bContinueFor90 == false then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Aborting subpath for both 270 and 90 angles so still stop looking for subpaths now') end
                                    bContinueSubpath = false
                                    break
                                end
                            elseif iSubpathCount >= iInfiniteLoopCheck then bContinueSubpath = false break
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Subpath was in playable area so not removed; iValidSubpathCount='..iValidSubpathCount) end
                            aiBrain[reftIntelLinePositions][iCurIntelLine][iValidSubpathCount + 1] = {}
                            aiBrain[reftIntelLinePositions][iCurIntelLine][iValidSubpathCount + 1] = tPossiblePosition
                            if bDebugMessages == true then LOG(sFunctionRef..': iSubpathCount='..iSubpathCount..'; iValidSubpathCount='..iValidSubpathCount..'; iDistanceAlongSubpath='..iDistanceAlongSubpath..'; aiBrain[reftIntelLinePositions][iCurIntelLine][iValidSubpathCount + 1] ='..repr(aiBrain[reftIntelLinePositions][iCurIntelLine][iValidSubpathCount + 1])) end
                            if bDebugMessages == true then M27Utilities.DrawLocations({aiBrain[reftIntelLinePositions][iCurIntelLine][iValidSubpathCount + 1]}, false, 2) end
                        end
                    end

                    if iSubpathAngle == 90 then iSubpathAngle = 270
                    elseif iSubpathAngle == 270 then iSubpathAngle = 90 end



                end
            end
            --Record the number of scouts needed for each intel path:
            aiBrain[reftScoutsNeededPerPathPosition] = {}
            aiBrain[refiMinScoutsNeededForAnyPath] = 10000
            for iCurIntelLine = 1, iIntelLineTotal do
                aiBrain[reftScoutsNeededPerPathPosition][iCurIntelLine] = table.getn(aiBrain[reftIntelLinePositions][iCurIntelLine])
                if aiBrain[reftScoutsNeededPerPathPosition][iCurIntelLine] < aiBrain[refiMinScoutsNeededForAnyPath] then aiBrain[refiMinScoutsNeededForAnyPath] = aiBrain[reftScoutsNeededPerPathPosition][iCurIntelLine] end
            end
            aiBrain[refiMaxIntelBasePaths] = table.getn(aiBrain[reftIntelLinePositions])
            aiBrain[refbIntelPathsGenerated] = true
        end
    else
        aiBrain[refiScoutShortfallInitialRaider] = 1
        aiBrain[refiScoutShortfallACU] = 1
        aiBrain[refiScoutShortfallIntelLine] = 1
        aiBrain[refbNeedScoutPlatoons] = true
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code; aiBrain[refbIntelPathsGenerated]='..tostring(aiBrain[refbIntelPathsGenerated])) end
end

function GetNearestMAAOrScout(aiBrain, tPosition, bScoutNotMAA, bDontTakeFromInitialRaiders, bOnlyConsiderAvailableHelpers, oRelatedUnitOrPlatoon)
    --Looks for the nearest specified support unit - if bScoutNotMAA is true then scout, toherwise MAA;, ignoring scouts/MAA in initial raider platoons if bDontTakeFromInitialRaiders is true
    --if bOnlyConsiderAvailableHelpers is true then won't consider units in any other existing platoons (unless they're a helper platoon with no helper)
    --returns nil if no such scout/MAA
    --oRelatedUnitOrPlatoon - use to check that aren't dealing with a support unit already assigned to the unit/platoon that are getting this for
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'GetNearestMAAOrScout'
    if bOnlyConsiderAvailableHelpers == nil then bOnlyConsiderAvailableHelpers = false end
    if bDontTakeFromInitialRaiders == nil then bDontTakeFromInitialRaiders = true end
    local iUnitCategoryWanted, sPlatoonHelperRef
    if bScoutNotMAA == true then
        iUnitCategoryWanted = M27UnitInfo.refCategoryLandScout
        sPlatoonHelperRef = refoUnitsScoutHelper
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
                                if not(oCurPlatoon == oArmyPoolPlatoon) and not(oCurPlatoon == oIdleScoutPlatoon) and not(oCurPlatoon == oIdleMAAPlatoon) then
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
    return oNearestSupportUnit
end

function AssignHelperToLocation(aiBrain, oHelperToAssign, tLocation)
    local oNewPlatoon = aiBrain:MakePlatoon('', '')
    aiBrain:AssignUnitsToPlatoon(oNewPlatoon, {oHelperToAssign}, 'Attack', 'GrowthFormation')
    oNewPlatoon[M27PlatoonUtilities.reftLocationToGuard] = tLocation
    oNewPlatoon:SetAIPlan('M27LocationAssister')
end

function AssignHelperToPlatoonOrUnit(oHelperToAssign, oPlatoonOrUnitNeedingHelp, bScoutNotMAA)
    --Checks if the platoon/unit already has a helper, in which case adds to that, otherwise creates a new helper platoon
    --bScoutNotMAA - true if scout, false if MAA
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'AssignHelperToPlatoonOrUnit'
    local aiBrain = oHelperToAssign:GetAIBrain()
    local sPlanWanted = 'M27ScoutAssister'
    local refHelper = refoUnitsScoutHelper
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
end

function AssignMAAToPreferredPlatoons(aiBrain)
    --Similar to assigning scouts, but for MAA - for now just focus on having MAA helping ACU and any platoon of >20 size that doesnt contain MAA
    --===========ACU MAA helper--------------------------
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'AssignMAAToPreferredPlatoons'
    local iACUMinMAAThreatWantedWithAirThreat = 84 --Equivalent to 3 T1 MAA
    if aiBrain[refiOurHighestFactoryTechLevel] > 1 then
        if aiBrain[refiOurHighestFactoryTechLevel] == 2 then iACUMinMAAThreatWantedWithAirThreat = 320 --2 T2 MAA
        elseif iACUMinMAAThreatWantedWithAirThreat == 3 then iACUMinMAAThreatWantedWithAirThreat = 800 --1 T3 MAA
        end
    end
    local iAirThreatMAAFactor = 0.16 --approx mass value of MAA wanted with ACU as a % of the total air threat
    local iMaxMAAThreatForACU = 2400 --equivalent to 3 T3 MAA
    local iACUMinMAAThreatWantedWithNoAirThreat = 28 --Equivalent to 1 T1 maa
    local iMAAThreatWanted = 0
    local iMinACUMAAThreatWanted = iACUMinMAAThreatWantedWithNoAirThreat
    local iMaxMAAWantedForACUAtOnce = 2

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
            if iMinACUMAAThreatWanted <= 0 then aiBrain[refiMAAShortfallACUCore] = 0 else aiBrain[refiMAAShortfallACUCore] = iMaxMAAWantedForACUAtOnce end
            aiBrain[refiMAAShortfallACUPrecaution] = iMaxMAAWantedForACUAtOnce
        end
    else
        --ACU doesnt need more MAA
        aiBrain[refiMAAShortfallACUPrecaution] = 0
        aiBrain[refiMAAShortfallACUCore] = 0
    end

    if iMAAThreatWanted <= 0 then --Have more than enough MAA to cover ACU, move on to considering if large platoons can get MAA support
        --=================Large platoons - ensure they have MAA in them, and if not then add MAA
        local tPlatoonUnits, iPlatoonUnits, tPlatoonCurrentMAAs, oMAAToAdd, oMAAOldPlatoon
        local iThresholdForAMAA = iMAALargePlatoonThresholdNoThreat --Any platoons with this many units should have a MAA in them
        if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] == nil then aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] = 0 end
        if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] > 0 then iThresholdForAMAA = iMAALargePlatoonThresholdAirThreat end
        local iMAAWanted = 0
        local iTotalMAAWanted = 0
        local iMAAAlreadyHave
        local iCurLoopCount
        local iMaxLoopCount = 50
        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] then
            for iCurPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
                if not(oPlatoon[M27PlatoonTemplates.refbIdlePlatoon]) then
                    tPlatoonUnits = oPlatoon:GetPlatoonUnits()
                    if M27Utilities.IsTableEmpty(tPlatoonUnits) == false then
                        iPlatoonUnits = table.getn(tPlatoonUnits)
                        if iPlatoonUnits >= iThresholdForAMAA then
                            iMAAWanted = math.floor(iPlatoonUnits / iThresholdForAMAA)
                            tPlatoonCurrentMAAs = EntityCategoryFilterDown(refCategoryMAA, tPlatoonUnits)
                            if M27Utilities.IsTableEmpty(tPlatoonCurrentMAAs) == true then iMAAAlreadyHave = 0
                                else iMAAAlreadyHave = table.getn(tPlatoonCurrentMAAs) end
                            if oPlatoon[refoUnitsMAAHelper] then
                                tPlatoonCurrentMAAs = oPlatoon[refoUnitsMAAHelper]:GetPlatoonUnits()
                                if M27Utilities.IsTableEmpty(tPlatoonCurrentMAAs) == false then
                                    iMAAAlreadyHave = iMAAAlreadyHave + table.getn(tPlatoonCurrentMAAs)
                                end
                            end
                            iCurLoopCount = 0
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
                            if iMAAWanted > iMAAAlreadyHave then
                                iTotalMAAWanted = iMAAWanted - iMAAAlreadyHave
                                break
                            end
                        end
                    end
                end
            end
        end
        aiBrain[refiMAAShortfallLargePlatoons] = iTotalMAAWanted
    end


    --========Build order related TODO longer term - update the current true/false flag in the factory overseer to differentiate between the MAA wanted
    if aiBrain[refiMAAShortfallACUPrecaution] + aiBrain[refiMAAShortfallACUCore] + aiBrain[refiMAAShortfallLargePlatoons] > 0 then bNeedMoreMAA = true
    else bNeedMoreMAA = false end
    aiBrain[refbNeedMAABuilt] = bNeedMoreMAA
    if bDebugMessages == true then LOG(sFunctionRef..': End of MAA assignment logic; aiBrain[refiMAAShortfallACUPrecaution]='..aiBrain[refiMAAShortfallACUPrecaution]..'; aiBrain[refiMAAShortfallACUCore]='..aiBrain[refiMAAShortfallACUCore]..'; aiBrain[refiMAAShortfallLargePlatoons]='..aiBrain[refiMAAShortfallLargePlatoons]) end
end

function AssignScoutsToPreferredPlatoons(aiBrain)
    --Goes through all scouts we have, and assigns them to highest priority tasks
    --Tries to form an intel line (and manages the location of this), and requests more scouts are built if dont have enough to form an intel line platoon;
    --Also records the number of scouts needed to complete things
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'AssignScoutsToPreferredPlatoons'

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
        if iScouts > 50 then
            LOG('Have 50 scouts, seems higher than would expect so enabling logs')
            bDebugMessages = true --For error identification
        end
        if iScouts > iNonScouts or iScouts >= 100 then
            bDebugMessages = true --For errors
            M27Utilities.ErrorHandler('Warning possible error unless large map or lots of small platoons - more than 25 scouts, but only '..iNonScouts..' non-scouts; iScouts='..iScouts..'; turning on debug messages.  Still stop producing scouts if get to 100')
            aiBrain[refiScoutShortfallInitialRaider] = 0
            aiBrain[refiScoutShortfallACU] = 0
            aiBrain[refiScoutShortfallIntelLine] = 0
            aiBrain[refiScoutShortfallLargePlatoons] = 0
            aiBrain[refiScoutShortfallAllPlatoons] = 0
            aiBrain[refiScoutShortfallMexes] = 0
            bAbort = true
        end
    end
    if bAbort == false then
        local oArmyPoolPlatoon, tArmyPoolScouts
        if iScouts > 0 then
            --============Initial mex raider scouts-----------------------
            --Check initial raiders have scouts (1-off at start of game)
            if aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] == nil then aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] = {} end
            local iRaiderCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27MexRaiderAI']
            if iRaiderCount == nil then
                iRaiderCount = 0
                aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27MexRaiderAI'] = 0
            end
            --local iMinScoutsWantedInPool = 0 --This is also changed several times below
            if bDebugMessages == true then LOG(sFunctionRef..': About to check if raiders have been checked for scouts; iScouts='..iScouts..'; iRaiderCount='..iRaiderCount..'; aiBrain[refbConfirmedInitialRaidersHaveScouts]='..tostring(aiBrain[refbConfirmedInitialRaidersHaveScouts])) end

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
                                            elseif oPlatoon[refoUnitsScoutHelper] then
                                                tRaiderScouts = oPlatoon[refoUnitsScoutHelper]:GetPlatoonUnits()
                                                if M27Utilities.IsTableEmpty(tRaiderScouts) == false then bHaveScout = true end
                                            end
                                            if bHaveScout == false then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Raider platoon'..oPlatoon[M27PlatoonUtilities.refiPlatoonCount]..' doesnt have any scouts, seeing if we can give it a scout') end
                                                --Platoon doesnt have a scout - can we give it one?
                                                local tPlatoonPosition = M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)
                                                local oScoutToGive = GetNearestMAAOrScout(aiBrain, tPlatoonPosition, true, true, true)
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
                if aiBrain[refiScoutShortfallInitialRaider] < 1 then aiBrain[refiScoutShortfallInitialRaider] = -iAvailableScouts end --redundancy/backup - shouldnt need due to above
                aiBrain[refiScoutShortfallACU] = 1
                aiBrain[refiScoutShortfallIntelLine] = aiBrain[refiMinScoutsNeededForAnyPath]
            else
                aiBrain[refiScoutShortfallInitialRaider] = 0
                if iAvailableScouts == 0 then
                    aiBrain[refiScoutShortfallACU] = 1
                    aiBrain[refiScoutShortfallIntelLine] = aiBrain[refiMinScoutsNeededForAnyPath]
                else --Have at least 1 available scout

                    --===========ACU Scout helper--------------------------
                    --We have more than enough scouts to cover initial raiders; next priority is the ACU
                    local bACUNeedsScoutHelper = true
                    if not(M27Utilities.GetACU(aiBrain)[refoUnitsScoutHelper] == nil) then
                        --A scout helper was assigned, check if it still exists
                        if M27Utilities.GetACU(aiBrain)[refoUnitsScoutHelper] and aiBrain:PlatoonExists(M27Utilities.GetACU(aiBrain)[refoUnitsScoutHelper]) then
                            --Platoon still exists; does it have the right aiplan?
                            local sScoutHelperName = M27Utilities.GetACU(aiBrain)[refoUnitsScoutHelper]:GetPlan()
                            if sScoutHelperName and sScoutHelperName == 'M27ScoutAssister' then
                                --does it have a scout in it?
                                local tACUScout = M27Utilities.GetACU(aiBrain)[refoUnitsScoutHelper]:GetPlatoonUnits()
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
                        local oScoutToGive = GetNearestMAAOrScout(aiBrain, M27Utilities.GetACU(aiBrain):GetPosition(), true, true, false)

                        if not(oScoutToGive == nil) then
                            AssignHelperToPlatoonOrUnit(oScoutToGive, M27Utilities.GetACU(aiBrain), true)

                        end
                    end
                    iAvailableScouts = iAvailableScouts - 1
                    aiBrain[refiScoutShortfallACU] = 0


                    --==========Intel Line manager
                    if iAvailableScouts <= 0 then
                        aiBrain[refiScoutShortfallIntelLine] = aiBrain[refiMinScoutsNeededForAnyPath]
                    else
                        --Do we have an intel platoon yet?
                        local tIntelPlatoons = {}
                        local iIntelPlatoons = 0
                        --local oFirstIntelPlatoon
                        local tCurIntelScouts = {}
                        local iCurIntelScouts = 0
                        local iIntelScouts = 0
                        if bDebugMessages == true then LOG(sFunctionRef..': Cycling through all platoons to identify intel platoons') end
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
                        if bDebugMessages == true then LOG(sFunctionRef..': Intel platoons identified='..iIntelPlatoons) end
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

                            local iEnemyStartNumber = M27Logic.GetNearestEnemyStartNumber(aiBrain)
                            local iOurStartNumber = aiBrain.M27StartPositionNumber
                            if iEnemyStartNumber then
                                local iACUDistToEnemy = M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[iEnemyStartNumber])
                                local iACUDistToHome = M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[iOurStartNumber])
                                local iPathDistToEnemy = M27Utilities.GetDistanceBetweenPositions(aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]][1], M27MapInfo.PlayerStartPoints[iEnemyStartNumber])
                                local iPathDistToHome = M27Utilities.GetDistanceBetweenPositions(aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]][1], M27MapInfo.PlayerStartPoints[iOurStartNumber])
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
                                    local iCurEnemyThreat = 0
                                    local iCurAllyThreat = 0
                                    local iTotalEnemyNetThreat = 0
                                    local bScoutNearAllMexes = true
                                    local tNearbyScouts
                                    local tEnemyUnitsNearPoint, tEnemyStructuresNearPoint
                                    if bDebugMessages == true then LOG(sFunctionRef..': About to loop through subpath positions') end
                                    local iLoopCount1 = 0
                                    local iLoopMax1 = 100
                                    local tNearbyAllies, tNearbyEnemies
                                    for iSubPath, tSubPathPosition in aiBrain[reftIntelLinePositions][aiBrain[refiCurIntelLineTarget]] do
                                        --GetCombatThreatRating(aiBrain, tUnits, bUseBlip, iMassValueOfBlipsOverride)
                                        --To keep things simple will look for units within iIntelPathEnemySearchRange of each path position;
                                        --Some niche cases where this will be inaccurate: Pathing results in 2 path positions being closer together, and units get counted twice
                                        --Also this is looking at circles around the point - units that are in the middle of 2 points may not be counted
                                        --20 is used because the lowest scout intel range is 40, but some are higher
                                        iLoopCount1 = iLoopCount1 + 1
                                        if iLoopCount1 > iLoopMax1 then
                                            M27Utilities.ErrorHandler('Likely infinite loop, iSubpath='..iSubpath..'; iLoopCount1='..iLoopCount1)
                                            break
                                        end
                                        if aiBrain == nil then M27Utilities.ErrorHandler('aiBrain is nil') end
                                        tNearbyEnemies = aiBrain:GetUnitsAroundPoint(categories.MOBILE + categories.STRUCTURE, tSubPathPosition, iIntelPathEnemySearchRange, 'Enemy')
                                        tNearbyAllies = aiBrain:GetUnitsAroundPoint(categories.MOBILE + categories.STRUCTURE, tSubPathPosition, 35, 'Ally')
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
                                            bScoutNearAllMexes = false
                                            break
                                        else
                                            tNearbyScouts = aiBrain:GetUnitsAroundPoint(refCategoryLandScout, tSubPathPosition, iIntelPathEnemySearchRange, 'Ally')
                                            if tNearbyScouts == nil then bScoutNearAllMexes = false
                                            elseif table.getn(tNearbyScouts) == 0 then bScoutNearAllMexes = false
                                            end
                                        end
                                    end
                                    if bDebugMessages == true then LOG(sFunctionRef..': Finished looping through subpath positions') end
                                    if iTotalEnemyNetThreat > 170 then
                                        aiBrain[refiCurIntelLineTarget] = aiBrain[refiCurIntelLineTarget] - 1
                                    else
                                        if iTotalEnemyNetThreat == 0 then
                                            --Are all scouts in position?
                                            if bScoutNearAllMexes == true then
                                                aiBrain[refiCurIntelLineTarget] = aiBrain[refiCurIntelLineTarget] + 1
                                            end
                                        end
                                    end
                                end
                            else
                                M27Utilities.ErrorHandler('iEnemyStartNumber is nil')
                            end
                        else --Dont have enough scouts to cover any path, to stick with initial base path
                            if bDebugMessages == true then LOG(sFunctionRef..': Dont have enough scouts to cover any intel path, stay at base path; aiBrain[refiMinScoutsNeededForAnyPath]='..aiBrain[refiMinScoutsNeededForAnyPath]..'; iIntelPlatoons='..iIntelPlatoons) end
                            aiBrain[refiCurIntelLineTarget] = 1
                        end
                        --Keep within min and max (this is repeated as needed here to make sure iscoutswanted doesnt cause error)
                        if aiBrain[refiCurIntelLineTarget] <= 0 then aiBrain[refiCurIntelLineTarget] = 1
                        elseif aiBrain[refiCurIntelLineTarget] > aiBrain[refiMaxIntelBasePaths] then aiBrain[refiCurIntelLineTarget] = aiBrain[refiMaxIntelBasePaths] end

                        if bDebugMessages == true then LOG('aiBrain[refiCurIntelLineTarget]='..aiBrain[refiCurIntelLineTarget]..'; table.getn(aiBrain[reftIntelLinePositions])='..table.getn(aiBrain[reftIntelLinePositions])) end
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
                        if bDebugMessages == true then LOG(sFunctionRef..': iScoutsWanted='..iScoutsWanted..'; iScoutsForNextPath='..iScoutsForNextPath..'aiBrain[refiScoutShortfallIntelLine]='..aiBrain[refiScoutShortfallIntelLine]) end

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
                            for iSubPath, tSubPathPosition in aiBrain[reftIntelLinePositions][iCurIntelLineTarget] do
                                iIncreaseInSubpath = 0
                                iMaxIncreaseInSubpath = 0

                                --Determine max subpath that can use based on neighbours:
                                if bDebugMessages == true then LOG(sFunctionRef..': Determining subpath modification from base to apply for iSubPath='..iSubPath) end
                                if aiBrain[reftiSubpathModFromBase] == nil then aiBrain[reftiSubpathModFromBase] = {} end
                                if aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget] == nil then aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget] = {} end
                                if aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath] == nil then aiBrain[reftiSubpathModFromBase][iCurIntelLineTarget][iSubPath] = 0 end
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

                                tNearbyEnemiesBase = aiBrain:GetUnitsAroundPoint(categories.MOBILE + categories.STRUCTURE, tSubPathPosition, iIntelPathEnemySearchRange, 'Enemy')
                                if M27Utilities.IsTableEmpty(tNearbyEnemiesBase) == true then
                                    tSubPathPlus1 = aiBrain[reftIntelLinePositions][iCurIntelLineTarget + 1][iSubPath]
                                    if M27Utilities.IsTableEmpty(tSubPathPlus1) == false then
                                        tNearbyEnemiesPlus1 = aiBrain:GetUnitsAroundPoint(categories.MOBILE + categories.STRUCTURE, tSubPathPlus1, iIntelPathEnemySearchRange, 'Enemy')
                                        if M27Utilities.IsTableEmpty(tNearbyEnemiesPlus1) == true then
                                            iIncreaseInSubpath = 1
                                            tSubPathPlus2 = aiBrain[reftIntelLinePositions][iCurIntelLineTarget + 2][iSubPath]
                                            if M27Utilities.IsTableEmpty(tSubPathPlus2) == false then
                                                tNearbyEnemiesPlus2 = aiBrain:GetUnitsAroundPoint(categories.MOBILE + categories.STRUCTURE, tSubPathPlus2, iIntelPathEnemySearchRange, 'Enemy')
                                                if M27Utilities.IsTableEmpty(tNearbyEnemiesPlus2) == true then
                                                    iIncreaseInSubpath = 2
                                                end
                                            end
                                        end
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': iSubPath='..iSubPath..'; iMaxIncreaseInSubpath ='..iMaxIncreaseInSubpath..'; iIncrease wnated before applying max='..iIncreaseInSubpath) end
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
                        local oScoutToGive, oNewScoutPlatoon
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
                                    LOG(sFunctionRef..': Created new platoon with Plan name and count='..oNewScoutPlatoon:GetPlan()..iPlatoonCount)
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
                        if bDebugMessages == true then LOG(sFunctionRef..': About to loop subpaths in current target') end
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
                                        if not(oClosestPlatoon[M27PlatoonUtilities.reftMovementPath][1] == tCurPathPos) then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Giving override action to oClosestPlatoon: tCurPathPosition='..repr(tCurPathPos)..'; movement path='..repr(oClosestPlatoon[M27PlatoonUtilities.reftMovementPath][1])) end
                                            oClosestPlatoon[M27PlatoonUtilities.reftMovementPath][1] = tCurPathPos
                                            oClosestPlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionReissueMovementPath
                                            --oClosestPlatoon[M27PlatoonUtilities.refiCurrentAction] = M27PlatoonUtilities.refActionReissueMovementPath
                                            M27PlatoonUtilities.ForceActionRefresh(oClosestPlatoon)
                                            oClosestPlatoon[M27PlatoonUtilities.refbOverseerAction] = true
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
                                if bDebugMessages == true then LOG(sFunctionRef..': About to loop through previous and next intel paths') end
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
                --Defaults for other scouts wanted - just set to 1 for simplicity
                aiBrain[refiScoutShortfallLargePlatoons] = 1
                aiBrain[refiScoutShortfallAllPlatoons] = 1
                aiBrain[refiScoutShortfallMexes] = 0
                aiBrain[refbNeedScoutPlatoons] = true
            else
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
                                        elseif oPlatoon[refoUnitsScoutHelper] and oPlatoon[refoUnitsScoutHelper].GetPlatoonUnits then
                                            tPlatoonCurrentScouts = oPlatoon[refoUnitsScoutHelper]:GetPlatoonUnits()
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

                    for iMex, tMex in aiBrain[M27MapInfo.reftMexesToKeepScoutsBy] do
                        if M27Utilities.GetDistanceBetweenPositions(tMex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) > 40 then
                            sLocationRef = iMex --M27Utilities.ConvertLocationToReference(tMex)
                            --Do we have a scout assigned that is still alive?
                            oCurScout = aiBrain[tScoutAssignedToMexLocation][sLocationRef]
                            if oCurScout and not(oCurScout.Dead) and oCurScout.GetUnitId then
                                --Do nothing
                            else
                                aiBrain[tScoutAssignedToMexLocation][sLocationRef] = nil
                                --Do we have omni coverage?
                                bCurPositionInOmniRange = false
                                if not(bConsiderOmni) then bCurPositionInOmniRange = true
                                else
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
                                        AssignHelperToLocation(aiBrain, oCurScout, tMex)
                                    else
                                        bNoMoreScouts = true
                                        iScoutShortfall = iScoutShortfall + 1
                                    end
                                end
                            end
                        end
                    end
                    aiBrain[refiScoutShortfallMexes] = iScoutShortfall
                end
            end
        else
            aiBrain[refiScoutShortfallInitialRaider] = aiBrain[refiInitialRaiderPlatoonsWanted]
            aiBrain[refiScoutShortfallACU] = 1
            aiBrain[refiScoutShortfallIntelLine] = aiBrain[refiMinScoutsNeededForAnyPath]
        end
    end
end


function RemoveSpareNonCombatUnits(oPlatoon)

    --Removes surplus scouts/MAA from oPlatoon
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'RemoveSpareTypeOfUnit'
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
end

function ResetEnemyThreatGroups(aiBrain, iSearchRange, tCategoriesToSearch)
    --[[ Background:
        Overseer code will have assigned [iArmyIndex][refsThreatGroup] for each visible enemy unit, grouped the units into threat groups, and recorded the threat groups in aiBrain[reftEnemyThreatGroup].
        Friendly platoons will then have been sent to intercept the nearest threat group, and will ahve recorded that threat group's reference
        when enemy units are combined into a threat group, any recent platoon group references should be checked, and then any aiBrain defender platoons targetting those enemy groups should have their references updated
    This Reset function therefore sets the current target to nil, and updates the previous target reference - updates both enemy unit references, and own platoon target references
    ]]

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
end

function AddNearbyUnitsToThreatGroup(aiBrain, oEnemyUnit, sThreatGroup, iRadius, iCategory, bMustBeOnLand, bMustBeOnWater, iNavalBlipThreat)
    --Adds oEnemyUnit to sThreatGroup and calls this function on itself again for any units within iRadius that are visible
    --also updates previous threat group references so they know to refer to this threat group
    --if iRadius is 0 then will only add oEnemyUnit to the threat group
    --Add oEnemyUnit to sThreatGroup:
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'AddNearbyUnitsToThreatGroup'
    local iArmyIndex = aiBrain:GetArmyIndex()

    local bNewUnitIsOnRightTerrain
    local bIsOnWater
    local tCurPosition

    if bMustBeOnLand == nil then
        bMustBeOnLand = true
        if bMustBeOnWater == nil then bMustBeOnLand = false end
    end
    if bMustBeOnWater == nil then bMustBeOnWater = false end

    --Only call this if haven't already called this on a unit:
    if oEnemyUnit[iArmyIndex] == nil then oEnemyUnit[iArmyIndex] = {} end
    if oEnemyUnit[iArmyIndex][refbUnitAlreadyConsidered] == nil then
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

        --look for nearby units:
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

                if bNewUnitIsOnRightTerrain and M27Utilities.CanSeeUnit(aiBrain, oUnit, true) == true then AddNearbyUnitsToThreatGroup(aiBrain, oUnit, sThreatGroup, iRadius, iCategory, bMustBeOnLand, bMustBeOnWater) end
            end
        end
    end
end

function UpdatePreviousPlatoonThreatReferences(aiBrain, tEnemyThreatGroup)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'UpdatePreviousPlatoonThreatReferences'
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
end

function RemoveSpareUnits(oPlatoon, iThreatNeeded, iMinScouts, iMinMAA, oPlatoonToAddTo, bIgnoreIfNearbyEnemies)
    --Remove any units not needed for iThreatNeeded, on assumption remaining units will be merged into oPlatoonToAddTo (so will remove units furthest from that platoon)
    --bIgnoreIfNearbyEnemies (default is yes) is true then won't remove units if have nearby enemies (based on the localised platoon enemy detection)
    --if oPlatoon is army pool then wont remove any of the units

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'RemoveSpareUnits'
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
end

function TransferPlatoonTrackers(oCopyFromPlatoon, oCopyToPlatoon)
    oCopyToPlatoon[refiTotalThreat] = oCopyFromPlatoon[refiTotalThreat]
    oCopyToPlatoon[reftAveragePosition] = oCopyFromPlatoon[reftAveragePosition]
    oCopyToPlatoon[refiActualDistanceFromEnemy] = oCopyFromPlatoon[refiActualDistanceFromEnemy]
    oCopyToPlatoon[refiDistanceFromOurBase] = oCopyFromPlatoon[refiDistanceFromOurBase]
    oCopyToPlatoon[refiModDistanceFromEnemy] = oCopyFromPlatoon[refiModDistanceFromEnemy]
end

function RecordAvailablePlatoonAndReturnValues(aiBrain, oPlatoon, iAvailableThreat, iCurAvailablePlatoons, tCurPos, iDistFromEnemy, iDistToOurBase, tAvailablePlatoons, tNilDefenderPlatoons, bIndirectThreatOnly)
    --Used by ThreatAssessAndRespond - Split out into this function as used in 2 places so want to make sure any changes are reflected in both
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'RecordAvailablePlatoonAndReturnValues'
    local oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local oRecordedPlatoon
    local bIgnore = false
    if oPlatoon == oArmyPoolPlatoon then
        bIgnore = true
    else
        oRecordedPlatoon = oPlatoon
        --if oRecordedPlatoon[M27PlatoonTemplates.refbIdlePlatoon] then bIgnore = true end
    end

    if bIgnore == false then
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
            oRecordedPlatoon[refiActualDistanceFromEnemy] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
            oRecordedPlatoon[refiModDistanceFromEnemy] = 0
            bArmyPoolInAvailablePlatoons = true]]--
        --else
            oRecordedPlatoon[reftAveragePosition] = tCurPos
            oRecordedPlatoon[refiActualDistanceFromEnemy] = iDistFromEnemy
            oRecordedPlatoon[refiDistanceFromOurBase] = iDistToOurBase
            oRecordedPlatoon[refiModDistanceFromEnemy] = GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tCurPos)
            if oRecordedPlatoon[refsEnemyThreatGroup] == nil then
                local iNilPlatoonCount = table.getn(tNilDefenderPlatoons)
                if iNilPlatoonCount == nil then iNilPlatoonCount = 0 end
                tNilDefenderPlatoons[iNilPlatoonCount + 1] = {}
                tNilDefenderPlatoons[iNilPlatoonCount + 1] = oRecordedPlatoon
            end
        --end
    end
    return iAvailableThreat, iCurAvailablePlatoons
end

function ThreatAssessAndRespond(aiBrain)
    --Identifies enemy threats, and organises platoons which are sent to deal with them
    --NOTE: Doesnt handle naval units
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'ThreatAssessAndRespond'

    --Key config variables:
    local iLandThreatGroupDistance = 20 --Units this close to each other get included in the same threat group
    local iNavyThreatGroupDistance = 30
    local iThreatGroupDistance
    if aiBrain[refiEnemyHighestTechLevel] > 1 then iNavyThreatGroupDistance = 60 end
    local iACUDistanceToConsider = 30 --If enemy within this distance of ACU, and within iACUEnemyDistanceFromBase distance of our base, ACU will consider helping (subject to also helping in emergency situation)
    local iACUEnemyDistanceFromBase = 80
    local iEmergencyExcessEnemyThreatNearBase = 200 --If >this much threat near our base ACU will consider helping from a much further distance away
    local iMaxACUEmergencyThreatRange = 150 --If ACU is more than this distance from our base then won't help even if an emergency threat
    local iThreatMaxFactor = 1.35 --i.e. will send up to iThreatMaxFactor * enemy threat to deal with the platoon
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
    local iEnemyStartPoint = M27Logic.GetNearestEnemyStartNumber(aiBrain)
    local iDistanceToEnemyFromStart = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
    local iNavySearchRange = math.min(iDistanceToEnemyFromStart, aiBrain[refiNearestOutstandingThreat])

    local oArmyPoolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')

    local refCategoryMobileLand = categories.LAND * categories.MOBILE
    local refCategoryPointDefence = categories.DIRECTFIRE * categories.STRUCTURE

    if bDebugMessages == true then LOG(sFunctionRef..': About to reset enemy threat groups') end
    if bDebugMessages == true then LOG(sFunctionRef..': Getting ACU platoon and action') DebugPrintACUPlatoon(aiBrain) end
    iCurThreatGroup = 0
    local tEnemyUnits
    local iTMDAndShieldSearchRange = 25 --If dealing with T2+ PD will look for nearby shields and TMD
    local iT2ArtiSearchRange = 50 --Will look for nearby T2 arti within this range
    local iNavyUnitCategories = M27UnitInfo.refCategoryAllAmphibiousAndNavy
    local tCategoriesToSearch = {refCategoryMobileLand, refCategoryPointDefence}
    if M27MapInfo.bMapHasWater == true then
        tCategoriesToSearch = {refCategoryMobileLand, refCategoryPointDefence, iNavyUnitCategories}
    end
    ResetEnemyThreatGroups(aiBrain, math.max(iNavySearchRange, iLandThreatSearchRange), tCategoriesToSearch)
    local bConsideringNavy
    local bUnitOnWater, tEnemyUnitPos
    local iCurThreat, iSearchRange
    local iCumulativeTorpBomberThreatShortfall = 0
    local bFirstUnassignedNavyThreat = true
    local iNavalBlipThreat = 300 --Frigate
    if aiBrain[refiEnemyHighestTechLevel] > 1 then
        iNavalBlipThreat = 2000 --Cruiser
    end
    for iEntry, iCategory in tCategoriesToSearch do
        bConsideringNavy = false
        iSearchRange = iLandThreatSearchRange
        if iCategory == iNavyUnitCategories then
            bConsideringNavy = true
            iSearchRange = iNavySearchRange
        end
        iThreatGroupDistance = iLandThreatGroupDistance
        if bConsideringNavy == true then iThreatGroupDistance = iNavyThreatGroupDistance end

        tEnemyUnits = aiBrain:GetUnitsAroundPoint(iCategory, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iSearchRange, 'Enemy')
        for iCurEnemy, oEnemyUnit in tEnemyUnits do
            tEnemyUnitPos = oEnemyUnit:GetPosition()
            bUnitOnWater = false
            if GetTerrainHeight(tEnemyUnitPos[1], tEnemyUnitPos[3]) < M27MapInfo.iMapWaterHeight then bUnitOnWater = true end

            --Are we on/not on water?
            if bUnitOnWater == bConsideringNavy then --either on water and considering navy, or not on water and not considering navy
                --Can we see enemy unit/blip:
                --function CanSeeUnit(aiBrain, oUnit, bBlipOnly)
                if bDebugMessages == true then LOG(sFunctionRef..': iCurEnemy='..iCurEnemy..' - about to see if can see the unit and get its threat. Enemy Unit ID='..oEnemyUnit:GetUnitId()) end
                if M27Utilities.CanSeeUnit(aiBrain, oEnemyUnit, true) == true then
                    if oEnemyUnit[iArmyIndex] == nil then oEnemyUnit[iArmyIndex] = {} end
                    if oEnemyUnit[iArmyIndex][refsEnemyThreatGroup] == nil then
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy unit doesnt have a threat group') end
                        --enemy unit hasn't been assigned a threat group - assign it to one now if it's not already got a threat group:
                        if not(oEnemyUnit[iArmyIndex][refbUnitAlreadyConsidered] == true) then
                            iCurThreatGroup = iCurThreatGroup + 1
                            sThreatGroup = 'M27'..iGameTime..'No'..iCurThreatGroup
                            oEnemyUnit[iArmyIndex][refsEnemyThreatGroup] = sThreatGroup
                            if bDebugMessages == true then LOG(sFunctionRef..': iCurEnemy='..iCurEnemy..' - about to add unit to threat group '..sThreatGroup) end
                            AddNearbyUnitsToThreatGroup(aiBrain, oEnemyUnit, sThreatGroup, iThreatGroupDistance, iCategory, not(bConsideringNavy), bConsideringNavy, iNavalBlipThreat)
                            --Add nearby structures to threat rating if dealing with structures and enemy has T2+ PD near them
                            if iCategory == refCategoryPointDefence and oEnemyUnit[iArmyIndex][refsEnemyThreatGroup][refiThreatGroupHighestTech] >= 2 then

                                local tNearbyDefensiveStructures = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryTMD * categories.STRUCTURE + M27UnitInfo.refCategoryFixedShield, tEnemyUnitPos, iTMDAndShieldSearchRange, 'Enemy')
                                if M27Utilities.IsTableEmpty(tNearbyDefensiveStructures) == false then
                                    for iDefence, oDefenceUnit in tNearbyDefensiveStructures do
                                        if not(oDefenceUnit.Dead) then
                                            AddNearbyUnitsToThreatGroup(aiBrain, oDefenceUnit, sThreatGroup, 0, iCategory)
                                        end
                                    end
                                end
                                local tNearbyT2Arti = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti, tEnemyUnitPos, iT2ArtiSearchRange, 'Enemy')
                                if M27Utilities.IsTableEmpty(tNearbyT2Arti) == false then
                                    for iDefence, oDefenceUnit in tNearbyT2Arti do
                                        if not(oDefenceUnit.Dead) then
                                            AddNearbyUnitsToThreatGroup(aiBrain, oDefenceUnit, sThreatGroup, 0, iCategory)
                                        end
                                    end
                                end
                            end

                        end
                        --Can see the unit, if its experimental add to the list of identified experimentals

                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy unit already has a threat group='..oEnemyUnit[iArmyIndex][refsEnemyThreatGroup]) end
                    end
                else if bDebugMessages == true then LOG(sFunctionRef..': Cant see the unit') end
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
            else
                iCurThreat = M27Logic.GetCombatThreatRating(aiBrain, tEnemyThreatGroup[refoEnemyGroupUnits], true)
            end

            tEnemyThreatGroup[refiTotalThreat] = math.max(10, iCurThreat)
            tEnemyThreatGroup[reftAveragePosition] = M27Utilities.GetAveragePosition(tEnemyThreatGroup[refoEnemyGroupUnits])
            tEnemyThreatGroup[refiDistanceFromOurBase] = M27Utilities.GetDistanceBetweenPositions(tEnemyThreatGroup[reftAveragePosition], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            tEnemyThreatGroup[refiModDistanceFromEnemy] = GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tEnemyThreatGroup[reftAveragePosition])
            if tEnemyThreatGroup[refiHighestThreatRecorded] == nil or tEnemyThreatGroup[refiHighestThreatRecorded] < tEnemyThreatGroup[refiTotalThreat] then tEnemyThreatGroup[refiHighestThreatRecorded] = tEnemyThreatGroup[refiTotalThreat] end
            if bDebugMessages == true then LOG(sFunctionRef..': iCurGroup='..iCurGroup..'; refiHighestThreatRecorded='..tEnemyThreatGroup[refiHighestThreatRecorded]..'; refiTotalThreat='..tEnemyThreatGroup[refiTotalThreat]) end

            tEnemyDistanceForSorting[iCurGroup] = {}
            tEnemyDistanceForSorting[iCurGroup] = tEnemyThreatGroup[refiModDistanceFromEnemy]
        end

        --Sort threat groups by distance to our base:
        if bDebugMessages == true then LOG(sFunctionRef..': About to sort table of enemy threat groups') end
        if bDebugMessages == true then
            LOG('Threat groups before sorting:')
            for i1, o1 in aiBrain[reftEnemyThreatGroup] do
                LOG('i1='..i1..'; o1.refiModDistanceFromEnemy='..o1[refiModDistanceFromEnemy]..'; threat group threat='..o1[refiTotalThreat]) end
        end

        aiBrain[refbNeedDefenders] = false
        aiBrain[refbNeedIndirect] = false
        aiBrain[refbNeedT2PlusIndirect] = false
        local iTotalEnemyThreatGroups = table.getn(aiBrain[reftEnemyThreatGroup])
        local bPlatoonHasRelevantUnits
        local bIndirectThreatOnly
        local bIgnoreRemainingLandThreats = false
        for iEnemyGroup, tEnemyThreatGroup in M27Utilities.SortTableBySubtable(aiBrain[reftEnemyThreatGroup], refiModDistanceFromEnemy, true) do
            bIndirectThreatOnly = false
            bConsideringNavy = false
            if tEnemyThreatGroup[refiThreatGroupCategory] == refCategoryPointDefence then bIndirectThreatOnly = true
            elseif tEnemyThreatGroup[refiThreatGroupCategory] == iNavyUnitCategories then bConsideringNavy = true end
            if bConsideringNavy == true or bIgnoreRemainingLandThreats == false then
                if bDebugMessages == true then LOG(sFunctionRef..': Start of cycle through sorted table of each enemy threat group; iEnemyGroup='..iEnemyGroup..'; distance from our base='..tEnemyThreatGroup[refiModDistanceFromEnemy]..'; bIndirectThreatOnly='..tostring(bIndirectThreatOnly)..'; bConsideringNavy='..tostring(bConsideringNavy)) end

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
                    iThreatNeeded = math.min(iThreatNeeded * 0.2, 400) --i.e. 2 MMLs
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

                    if iAvailableThreat < iThreatNeeded and not(bIndirectThreatOnly) then
                        --Check if should add ACU to help fight - is enemy relatively close to ACU, relatively close to our start, and ACU is closer to start than enemy?
                        bGetACUHelp = false
                        iDistFromEnemy = M27Utilities.GetDistanceBetweenPositions(tACUPos, tEnemyThreatGroup[reftAveragePosition])
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering whether should get ACU to help; iDistFromEnemy ='..iDistFromEnemy) end
                        if iDistFromEnemy < iACUDistanceToConsider then
                            if tEnemyThreatGroup[refiDistanceFromOurBase] < iACUEnemyDistanceFromBase then
                                iDistToOurBase = M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                if iDistToOurBase < tEnemyThreatGroup[refiDistanceFromOurBase] then
                                    --are we closer to our base than enemy?
                                    if iEnemyStartPoint then
                                        local iDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[iEnemyStartPoint])
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

                        oACU[refbACUHelpWanted] = bGetACUHelp
                        if bGetACUHelp == true then
                            --Check if ACU not already in a defender platoon:
                            sACUPlan = DebugPrintACUPlatoon(aiBrain, true)
                            if not(sACUPlan == sDefenderPlatoonRef) then
                                --Flag that ACU has been added to defenders if its using the main AI
                                if DebugPrintACUPlatoon(aiBrain, true) == 'M27ACUMain' then aiBrain[refbACUWasDefending] = true end
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
                                    bACUIsDefending = true
                                end
                                iAvailableThreat, iCurAvailablePlatoons = RecordAvailablePlatoonAndReturnValues(aiBrain, oACU.PlatoonHandle, iAvailableThreat, iCurAvailablePlatoons, tACUPos, iDistFromEnemy, iDistToOurBase, tAvailablePlatoons, tNilDefenderPlatoons, bIndirectThreatOnly)
                                if bDebugMessages == true then LOG(sFunctionRef..': iAvailableThreat after adding ACU to available platoons='..iAvailableThreat) end
                                --iAvailableThreat = iAvailableThreat + M27Logic.GetCombatThreatRating(aiBrain, {oACU}, false)

                            end
                        end
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
                        --M27Utilities.GetDistanceBetweenPositions(tEnemyThreatGroup[reftAveragePosition], M27MapInfo.PlayerStartPoints[iEnemyStartPoint])
                        aiBrain[refiNearestOutstandingThreat] = tEnemyThreatGroup[refiModDistanceFromEnemy]
                        aiBrain[refiPercentageOutstandingThreat] = tEnemyThreatGroup[refiModDistanceFromEnemy] / (tEnemyThreatGroup[refiModDistanceFromEnemy] + iCurModDistToEnemyBase)
                        aiBrain[refbNeedT2PlusIndirect] = false --default
                        if bIndirectThreatOnly then
                            aiBrain[refbNeedIndirect] = true
                            aiBrain[refbNeedDefenders] = false
                            if tEnemyThreatGroup[refiThreatGroupHighestTech] >= 2 then aiBrain[refbNeedT2PlusIndirect] = true end
                        else
                            aiBrain[refbNeedDefenders] = true --will assign more units to defender platoon
                            aiBrain[refbNeedIndirect] = false
                        end
                    else
                        if iEnemyGroup >= iTotalEnemyThreatGroups then
                            --is the furthest away enemy threat group and we can beat it, so we have full defensive coverage; will set to 90% to avoid trying to e.g. get mexes in the enemy base itself
                            aiBrain[refiPercentageOutstandingThreat] = 0.9
                            aiBrain[refiNearestOutstandingThreat] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
                        end
                    end

                    --Now decide whether we will attack with the platoon, based on whether we have the minimum threat needed
                    if iAvailableThreat < iThreatNeeded then

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
                                M27PlatoonUtilities.ForceActionRefresh(oPlatoon)
                                oPlatoon[M27PlatoonUtilities.reftMovementPath] = {}
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

                        --Can beat enemy (or for indirect may be able to beat them) so attack them - filter to just those platoons that need to deal with the threat if we have more than what is needed:
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
                        --Base platoon should now be able to beat enemy
                        if bIgnoreRemainingLandThreats == false and oBasePlatoon == nil then
                            LOG(sFunctionRef..': ERROR - oBasePlatoon is nil but had thought could beat the enemy - unless down to just ACU and no defenders likely error')
                        elseif bIgnoreRemainingLandThreats == false then
                            if oBasePlatoon == oArmyPoolPlatoon then
                                M27Utilities.ErrorHandler('WARNING - oArmyPoolPlatoon is oBasePlatoon - will abort threat intereception logic and flag that want defender platoons to be created')
                                if table.getn(tAvailablePlatoons) <= 1 then aiBrain[refbNeedDefenders] = true end
                            else
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
                                oBasePlatoon[refiActualDistanceFromEnemy] = M27Utilities.GetDistanceBetweenPositions(oBasePlatoon[reftAveragePosition], tEnemyThreatGroup[reftAveragePosition])
                                bRefreshPlatoonAction = true
                                if bDebugMessages == true then LOG(sFunctionRef..': BasePlatoonRef='..sPlatoonRef..': Considering whether base platoon should have an overseer action override. bAddedUnitsToPlatoon='..tostring(bAddedUnitsToPlatoon)..'; base platoon size='..table.getn(oBasePlatoon:GetPlatoonUnits())) end
                                --if not(bAddedUnitsToPlatoon) then
                                local iOverseerRefreshCountThreshold = 4
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
                        --Determine closest available torpedo bombers:
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
                    if bDebugMessages == true then LOG(sFunctionRef..': After going through any available torp bombers iAvailableThreat='..iAvailableThreat..'; iThreatNeeded='..iThreatNeeded) end
                    if iAvailableThreat >= iThreatNeeded then
                        for iEntry, tTorpSubtable in M27Utilities.SortTableBySubtable(tTorpBombersByDistance, refiActualDistanceFromEnemy, true) do
                            --Cycle through each enemy unit in the threat group
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering torp bomber '..tTorpSubtable[refoTorpUnit]:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(tTorpSubtable[refoTorpUnit])..'; tTorpSubtable[refiCurThreat]='..(tTorpSubtable[refiCurThreat] or 0)..'; about to cycle through every enemy unit in threat group to see if should attack one of them') end
                            for iUnit, oUnit in tEnemyThreatGroup[refoEnemyGroupUnits] do
                                if bDebugMessages == true then LOG(sFunctionRef..': Enemy Unit='..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iAssignedThreat='..(oUnit[iArmyIndex][refiAssignedThreat] or 0)..'; oUnit[iArmyIndex][refiUnitNavalAAThreat]='..(oUnit[iArmyIndex][refiUnitNavalAAThreat] or 0)..'; iNavalThreatMaxFactor='..iNavalThreatMaxFactor) end
                                if oUnit[iArmyIndex][refiAssignedThreat] <= iNavalThreatMaxFactor * oUnit[iArmyIndex][refiUnitNavalAAThreat] then
                                    oUnit[iArmyIndex][refiAssignedThreat] = oUnit[iArmyIndex][refiAssignedThreat] + tTorpSubtable[refiCurThreat]
                                    IssueClearCommands(tTorpSubtable[refoTorpUnit])
                                    IssueAttack({tTorpSubtable[refoTorpUnit]}, oUnit)
                                    M27AirOverseer.TrackBomberTarget(tTorpSubtable[refoTorpUnit], oUnit)
                                    for iUnit, oUnit in tEnemyThreatGroup[refoEnemyGroupUnits] do
                                        IssueAttack({tTorpSubtable[refoTorpUnit]}, oUnit)
                                    end
                                    IssueMove({tTorpSubtable[refoTorpUnit]}, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                    tTorpSubtable[refoTorpUnit][M27AirOverseer.refbOnAssignment] = true
                                    if bDebugMessages == true then LOG(sFunctionRef..': Clearing torpp bomber and then Telling torpedo bomber with ID ref='..tTorpSubtable[refoTorpUnit]:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(tTorpSubtable[refoTorpUnit])..' to attack') end
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
        --No threat groups
        M27Utilities.GetACU(aiBrain)[refbACUHelpWanted] = false
        aiBrain[refiPercentageOutstandingThreat] = 1
        aiBrain[refiNearestOutstandingThreat] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
        aiBrain[refbNeedDefenders] = false
        aiBrain[refbNeedIndirect] = false
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
        aiBrain[M27AirOverseer.refiTorpBombersWanted] = iCumulativeTorpBomberThreatShortfall / 240
    else
        aiBrain[M27AirOverseer.refiTorpBombersWanted] = 0
    end

    --if bDebugMessages == true then LOG(sFunctionRef..': End of code, getting ACU debug plan and action') DebugPrintACUPlatoon(aiBrain) end
end

function ACUManager(aiBrain)
    --A lot of the below code is a hangover from when the ACU would use the built in AIBuilders and platoons;
    --Almost all the functionality has now been integrated into the M27ACUMain platoon logic, with a few exceptions (such as calling for help), although these could probably be moved over as well
    local bDebugMessages = true if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'ACUManager'

    local oACU = M27Utilities.GetACU(aiBrain)
    if oACU[refbACUOnInitialBuildOrder] == false then
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code - ACU isnt on initial build order') end
        --Config related
        local iBuildDistance = oACU:GetBlueprint().Economy.MaxBuildDistance

        local iDistanceToLookForMexes = iBuildDistance + iACUMaxTravelToNearbyMex --Note The starting build order uses a condition which references whether ACU has mexes this far away, so factor in if changing this
        local iDistanceToLookForReclaim = iBuildDistance + iACUMaxTravelToNearbyMex
        local iMinReclaimValue = 16

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
                        if not(iCurAction == M27PlatoonUtilities.refActionBuildLandFactory or iCurAction == M27PlatoonUtilities.refActionBuildInitialPower) then
                            --Have an engineer action assigned but the platoon we're in doesnt, need to clear engineer tracker to free up any guarding units
                            M27EngineerOverseer.ClearEngineerActionTrackers(aiBrain, oACU, true)
                        end
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
            iIdleCount = iIdleCount + 1
            if iIdleCount > iIdleThreshold then
                local oNewPlatoon = aiBrain:MakePlatoon('', '')
                aiBrain:AssignUnitsToPlatoon(oNewPlatoon, {oACU},'Attack', 'None')
                oNewPlatoon:SetAIPlan('M27ACUMain')
                if oACUPlatoon and not(oACUPlatoon == oArmyPoolPlatoon) and oACUPlatoon.PlatoonDisband then oACUPlatoon:PlatoonDisband() end
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

            --Check for nearby reclaim
            --GetNearestReclaim(tLocation, iSearchRadius, iMinReclaimValue)
            local oReclaim = M27MapInfo.GetNearestReclaim(tACUPos, iDistanceToLookForReclaim, iMinReclaimValue)
            if not(oReclaim == nil) then
                aiBrain[refbReclaimNearACU] = true
                aiBrain[refoReclaimNearACU] = oReclaim
            end
        else
            --Set flags to false as will need refreshing before know if there's still nearby mex/reclaim
            aiBrain[refbReclaimNearACU] = false
            aiBrain[refbUnclaimedMexNearACU] = false
        end

        --==========ACU Run away logic
        local iHealthPercentage = oACU:GetHealthPercent()
        local bRunAway = false
        local bNewPlatoon = true
        local oNewPlatoon
        local bWantEscort = false
        local bEmergencyRequisition = false
        if iHealthPercentage <= iACUEmergencyHealthPercentThreshold then
            bWantEscort = true
            bEmergencyRequisition = true
            if bDebugMessages == true then LOG(sFunctionRef..': ACU low on health so forcing it to run to base unless its already there') end

            local iPlayerStartNumber = aiBrain.M27StartPositionNumber
            --Is the ACU within 25 of our base? If so then no point overriding
            if M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[iPlayerStartNumber]) > iDistanceFromBaseWhenVeryLowHealthToBeSafe then
                bRunAway = true
                --Is ACU upgrading and almost done?
                if oACU:IsUnitState('Upgrading') and oACU.GetWorkProgress and oACU:GetWorkProgress() <= 0.9 then bRunAway = false end
            end
        else
            --Not emergency health
            if oACU:IsUnitState('Upgrading') then bWantEscort = true
            else
                if iHealthPercentage >= 0.8 then
                    if oACUPlatoon then oACUPlatoon[M27PlatoonUtilities.refbShouldHaveEscort] = false end
                elseif iHealthPercentage <= 0.7 then
                    if oACUPlatoon then oACUPlatoon[M27PlatoonUtilities.refbShouldHaveEscort] = true end
                end
            end
        end

        if bRunAway == true and not(sACUPlan == 'M27ACUMain') then --M27ACUMain now has logic for the ACU to run built into it
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

            if not(oNewPlatoon[M27PlatoonUtilities.reftMovementPath][1] == M27MapInfo.PlayerStartPoints[iPlayerStartNumber]) then
                oNewPlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionReturnToBase
                if bDebugMessages == true then LOG(sFunctionRef..': Forcing action refresh') end
                M27PlatoonUtilities.ForceActionRefresh(oNewPlatoon, 5)
            end
        end

        if oACUPlatoon then
            oACUPlatoon[M27PlatoonUtilities.refbShouldHaveEscort] = bWantEscort
            local oEscortingPlatoon = oACUPlatoon[M27PlatoonUtilities.refoEscortingPlatoon]
            if oEscortingPlatoon then
                if bEmergencyRequisition then
                    oEscortingPlatoon[M27PlatoonTemplates.reftPlatoonsToAmalgamate] = { 'M27MexLargerRaiderAI', 'M27MexRaiderAI', 'M27AttackNearestUnits', 'M27CombatPatrolAI', 'M27LargeAttackForce', 'M27DefenderAI', 'M27EscortAI'}
                    oEscortingPlatoon[M27PlatoonTemplates.refiPlatoonAmalgamationRange] = 100
                    oEscortingPlatoon[M27PlatoonTemplates.refiPlatoonAmalgamationMaxSize] = 50
                else
                    oEscortingPlatoon[M27PlatoonTemplates.reftPlatoonsToAmalgamate] = nil
                    oEscortingPlatoon[M27PlatoonTemplates.refiPlatoonAmalgamationRange] = nil
                    oEscortingPlatoon[M27PlatoonTemplates.refiPlatoonAmalgamationMaxSize] = nil
                end
            end
        end
    end
end

function PlatoonNameUpdater(aiBrain, bUpdateCustomPlatoons)
    --Every second cycles through every platoon and updates its name to reflect its plan and platoon count
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'PlatoonNameUpdater'
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
end

function WaitTicksSpecial(aiBrain, iTicksToWait)
    --calls the GetACU function since that will check if ACU is alive, and if not will delay to avoid a crash
    local oACU = M27Utilities.GetACU(aiBrain)
    WaitTicks(iTicksToWait)
    oACU = M27Utilities.GetACU(aiBrain)
end

function EnemyThreatRangeUpdater(aiBrain)
    --Updates range to look for enemies based on if any T2 PD detected
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'EnemyThreatRangeUpdater'
    if aiBrain[refbEnemyHasTech2PD] == false then
        local tEnemyTech2 = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH2, M27Utilities.GetACU(aiBrain):GetPosition(), 1000, 'Enemy')
        if M27Utilities.IsTableEmpty(tEnemyTech2) == false then
            aiBrain[refbEnemyHasTech2PD] = true
            aiBrain[refiSearchRangeForEnemyStructures] = 85 --Tech 2 is 50, ravager 70, so will go for 80 range; want to factor it into decisions on whether to attack if are near it
            if bDebugMessages == true then LOG(sFunctionRef..': Enemy T2 PD detected - increasing range to look for nearby enemies on platoons') end
        end
    end
end

function SetMaximumFactoryLevels(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'SetMaximumFactoryLevels'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local iAirFactoriesOwned = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory)
    local iPrimaryFactoriesWanted
    local iPrimaryFactoryType = refFactoryTypeLand
    if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] == false then iPrimaryFactoryType = refFactoryTypeAir end
    --local iMexCount = aiBrain:GetCurrentUnits(refCategoryMex)
    local iMexesOnOurSideOfMap = M27EconomyOverseer.GetMexCountOnOurSideOfMap(aiBrain)
    if aiBrain[refiAIBrainCurrentStrategy] == refStrategyEcoAndTech then iPrimaryFactoriesWanted = math.max(3, math.ceil(iMexesOnOurSideOfMap * 0.25))
    else iPrimaryFactoriesWanted = math.max(5, math.ceil(iMexesOnOurSideOfMap * 0.7)) end

    aiBrain[reftiMaxFactoryByType][iPrimaryFactoryType] = iPrimaryFactoriesWanted
    local iAirFactoryMin = 1
    if iPrimaryFactoryType == refFactoryTypeAir then iAirFactoryMin = iPrimaryFactoriesWanted end
    local iTorpBomberShortfall = aiBrain[M27AirOverseer.refiTorpBombersWanted]
    if aiBrain[refiOurHighestFactoryTechLevel] < 2 then
        if iTorpBomberShortfall > 0 then aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1 end
        iTorpBomberShortfall = 0
    end
    if iPrimaryFactoryType == refFactoryTypeAir then aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1 end
    if bDebugMessages== true then LOG(sFunctionRef..': aiBrain[M27AirOverseer.refiAirAANeeded]='..aiBrain[M27AirOverseer.refiAirAANeeded]..'; aiBrain[M27AirOverseer.refiExtraAirScoutsWanted]='..aiBrain[M27AirOverseer.refiExtraAirScoutsWanted]..'; aiBrain[M27AirOverseer.refiBombersWanted]='..aiBrain[M27AirOverseer.refiBombersWanted]..'; iTorpBomberShortfall='..iTorpBomberShortfall) end

    local iAirUnitsWanted = aiBrain[M27AirOverseer.refiAirAANeeded] + math.min(1, aiBrain[M27AirOverseer.refiExtraAirScoutsWanted]) + aiBrain[M27AirOverseer.refiBombersWanted] + iTorpBomberShortfall
    aiBrain[reftiMaxFactoryByType][refFactoryTypeAir] = math.max(iAirFactoryMin, iAirFactoriesOwned + math.floor((iAirUnitsWanted - iAirFactoriesOwned * 4) / 5))
    if bDebugMessages == true then LOG(sFunctionRef..': iAirUnitsWanted='..iAirUnitsWanted..'; aiBrain[reftiMaxFactoryByType][refFactoryTypeAir]='..aiBrain[reftiMaxFactoryByType][refFactoryTypeAir]..'; aiBrain[reftiMaxFactoryByType][refFactoryTypeLand]='..aiBrain[reftiMaxFactoryByType][refFactoryTypeLand]) end
end

function DetermineInitialBuildOrder(aiBrain)
    if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == true then
        aiBrain[refiInitialRaiderPlatoonsWanted] = 2
        aiBrain[refiMinLandFactoryBeforeOtherTypes] = 2
    else
        aiBrain[refiInitialRaiderPlatoonsWanted] = 0
        aiBrain[refiMinLandFactoryBeforeOtherTypes] = 1
    end
end

function StrategicOverseer(aiBrain, iCurCycleCount) --also features 'state of game' logs
    local bDebugMessages = M27Config.M27StrategicLog
    local sFunctionRef = 'StrategicOverseer'

    local iDistanceToEnemyEcoThreshold = 450 --If enemy is >= this then more likely to switch to eco mode instead of ground attack
    --Super enemy threats that need a big/unconventional response - check every second as some e.g. nuke require immediate response
    local iBigThreatSearchRange = 10000

    local tEnemyBigThreatCategories = {M27UnitInfo.refCategoryGroundExperimental, M27UnitInfo.refCategoryFixedT3Arti, M27UnitInfo.refCategorySML}
    local tCurCategoryUnits
    local tReferenceTable, bRemovedUnit
    local sUnitUniqueRef

    for _, iCategory in tEnemyBigThreatCategories do
        tCurCategoryUnits = aiBrain:GetUnitsAroundPoint(iCategory, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iBigThreatSearchRange, 'Enemy')
        if iCategory == M27UnitInfo.refCategoryGroundExperimental or iCategory == M27UnitInfo.refCategoryFixedT3Arti then tReferenceTable = aiBrain[reftEnemyGroundExperimentals]
        elseif iCategory == M27UnitInfo.refCategorySML then tReferenceTable = aiBrain[reftEnemyNukeLaunchers]
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

    if iCurCycleCount <= 0 then

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

        local tAllUnclaimedMexesInPathingGroup = M27EngineerOverseer.GetUnclaimedMexes(aiBrain, oACU, sPathing, iPathingGroup, false, false, true)
        if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInPathingGroup) == false then iAllUnclaimedMexesInPathingGroup = table.getn(tAllUnclaimedMexesInPathingGroup) end
        if bDebugMessages == true then LOG(sFunctionRef..': About to get all mexes in pathing group that we havent claimed') end
        --GetUnclaimedMexes(aiBrain, oPathingUnitBackup, sPathing, iPathingGroup, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
        local tAllMexesInPathingGroupWeHaventClaimed = M27EngineerOverseer.GetUnclaimedMexes(aiBrain, oACU, sPathing, iPathingGroup, true, false, true)
        local iAllMexesInPathingGroupWeHaventClaimed = 0
        if M27Utilities.IsTableEmpty(tAllMexesInPathingGroupWeHaventClaimed) == false then iAllMexesInPathingGroupWeHaventClaimed = table.getn(tAllMexesInPathingGroupWeHaventClaimed) end

        local tLandCombatUnits = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryLandCombat, false, true)
        local iLandCombatUnits = 0
        if M27Utilities.IsTableEmpty(tLandCombatUnits) == false then iLandCombatUnits = table.getn(tLandCombatUnits) end



        --Our highest tech level
        local iHighestTechLevel = 1
        if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllFactories * categories.TECH3) > 0 then iHighestTechLevel = 3
        elseif aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllFactories * categories.TECH2) > 0 then iHighestTechLevel = 2 end
        aiBrain[refiOurHighestFactoryTechLevel] = iHighestTechLevel

        --Should we switch to eco?
            --How far away is the enemy?
        local iDistanceFromEnemyToUs = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])

        local bWantToEco = false
        local bBigEnemyThreat = false
        local iMexesNearStart = table.getn(M27MapInfo.tResourceNearStart[aiBrain.M27StartPositionNumber][1])
        local iT3Mexes = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex)

        if M27Utilities.IsTableEmpty(aiBrain[reftEnemyGroundExperimentals]) == false then bBigEnemyThreat = true end

        if aiBrain[M27EconomyOverseer.refiMexesAvailableForUpgrade] > 0 then
            if bBigEnemyThreat == false and aiBrain[refiPercentageOutstandingThreat] > 0.55 and (iAllMexesInPathingGroupWeHaventClaimed <= iAllMexesInPathingGroup * 0.5 or iDistanceFromEnemyToUs >= iDistanceToEnemyEcoThreshold) and not(iT3Mexes >= math.min(iMexesNearStart, 4) and aiBrain[refiOurHighestFactoryTechLevel] >= 3) then
                if bDebugMessages == true then LOG(sFunctionRef..': No big enemy threats and good defence and mex coverage so will eco') end
                bWantToEco = true
            else
                --Has our mass income not changed recently, but we dont appear to be losing significantly on the battlefield?
                if iCurTime > 100 and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] - iMassAtLeast3mAgo < 1 and aiBrain[refiPercentageOutstandingThreat] > 0.55 and iLandCombatUnits >= 30 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Ok defence coverage and income not changed in a while so will eco') end
                    bWantToEco = true
                else
                    if aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons] == false then
                        --Are sending tanks into an attacknearest platoon so want to eco if we have a significant number of tanks
                        if iLandCombatUnits >= 40 then
                            if bWantToEco == false or aiBrain[refiOurHighestFactoryTechLevel] <= 2 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Dont have tech 3 and/or have lots of land with no big threats and not making use of land factories so will eco') end
                                bWantToEco = true
                            end
                        end
                    end
                end
            end
        end

        --Check in case ACU health is low or we dont have any units near enemy (which might be why we think there's no enemy threat)
        local tFriendlyLandCombat = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryLandCombat + categories.COMMAND, false, true)
        --M27Utilities.GetNearestUnit(tUnits, M27MapInfo.PlayerStartPoints[GetNearestEnemyStartNumber(aiBrain)], aiBrain, false)
        local oNearestFriendlyCombatUnitToEnemyBase = M27Utilities.GetNearestUnit(tFriendlyLandCombat, M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)], aiBrain, false)
        local tFurthestFriendlyPosition = oNearestFriendlyCombatUnitToEnemyBase:GetPosition()
        local iFurthestFriendlyDistToOurBase = M27Utilities.GetDistanceBetweenPositions(tFurthestFriendlyPosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        local iFurthestFriendlyDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tFurthestFriendlyPosition, M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])

        aiBrain[refiPercentageClosestFriendlyToEnemyBase] = iFurthestFriendlyDistToOurBase / (iFurthestFriendlyDistToOurBase + iFurthestFriendlyDistToEnemyBase)
        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == true and aiBrain[refiPercentageClosestFriendlyToEnemyBase] < 0.4 then bWantToEco = false end
        if oACU:GetHealthPercent() < 0.45 then bWantToEco = false end



        if bWantToEco == true then --Land factory units to build for 'else' condition
            aiBrain[M27FactoryOverseer.refiLastPriorityCategoryToBuild] = nil
            aiBrain[refiAIBrainCurrentStrategy] = refStrategyEcoAndTech
        else
            aiBrain[M27FactoryOverseer.refiLastPriorityCategoryToBuild] = M27UnitInfo.refCategoryDFTank
            if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == false and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] == true then aiBrain[M27FactoryOverseer.refiLastPriorityCategoryToBuild] = M27UnitInfo.refCategoryAmphibiousCombat end
            aiBrain[refiAIBrainCurrentStrategy] = refStrategyLandEarly
        end
        --Max target defence coverage for strategy
        if aiBrain[refiAIBrainCurrentStrategy] == refStrategyEcoAndTech then aiBrain[refiMaxDefenceCoverageWanted] = 0.65
        else aiBrain[refiMaxDefenceCoverageWanted] = 0.9 end





        --Get key values relating to game state (for now only done if debugmessages, but coudl move some to outside of debugmessages)
        if bDebugMessages == true then
            local tsGameState = {}
            local tTempUnitList, iTempUnitCount

            tsGameState['CurTimeInSecondsRounded'] = iCurTime

            --Player
            tsGameState['Start position'] = aiBrain.M27StartPositionNumber

            --Grand Strategy
            tsGameState[refiAIBrainCurrentStrategy] = aiBrain[refiAIBrainCurrentStrategy]

            --Economy:
            tsGameState['iMassNetIncome'] = aiBrain:GetEconomyTrend('MASS')
            tsGameState['iEnergyNetIncome'] = aiBrain:GetEconomyTrend('ENERGY')
            tsGameState['iMassStored'] = aiBrain:GetEconomyStored('MASS')
            tsGameState['iEnergyStored'] = aiBrain:GetEconomyStored('ENERGY')


            --Key unit counts:
            tTempUnitList = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryLandFactory, false, true)
            iTempUnitCount = 0
            if M27Utilities.IsTableEmpty(tTempUnitList) == false then iTempUnitCount = table.getn(tTempUnitList) end
            tsGameState['iLandFactories'] = iTempUnitCount

            tsGameState['Highest factory tech level'] = iHighestTechLevel

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
            tsGameState['AvailableBombers'] = 0
            if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableBombers]) == false then tsGameState['AvailableBombers'] = table.getn(aiBrain[M27AirOverseer.reftAvailableBombers]) end
            tsGameState['RemainingBomberTargets'] = 0
            if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftBomberTargetShortlist]) == false then tsGameState['RemainingBomberTargets'] = table.getn(aiBrain[M27AirOverseer.reftBomberTargetShortlist]) end
            tsGameState['TorpBombersWanted'] = aiBrain[M27AirOverseer.refiTorpBombersWanted]

                --Factories wanted
            tsGameState['WantMoreLandFactories'] = tostring(aiBrain[M27EconomyOverseer.refbWantMoreFactories])

            --Threat values:
            --Intel path % to enemy
            if aiBrain[refiCurIntelLineTarget] then
                local iIntelPathPosition = aiBrain[refiCurIntelLineTarget]
                local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                local iEnemyStartPosition = M27Logic.GetNearestEnemyStartNumber(aiBrain)
                local tEnemyPosition = M27MapInfo.PlayerStartPoints[iEnemyStartPosition]
                --reftIntelLinePositions = 'M27IntelLinePositions' --x = line; y = point on that line, returns position
                local tIntelPathCurBase = aiBrain[reftIntelLinePositions][iIntelPathPosition][1]
                local iIntelDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tIntelPathCurBase, tStartPosition)
                local iIntelDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tIntelPathCurBase, tEnemyPosition)
                tsGameState['iIntelPathPosition'] = iIntelPathPosition
                tsGameState['iIntelDistancePercent'] = iIntelDistanceToStart / (iIntelDistanceToStart + iIntelDistanceToEnemy)
            end
            if aiBrain[refiNearestOutstandingThreat] then tsGameState['NearestOutstandingThreat'] = aiBrain[refiNearestOutstandingThreat] end
            if aiBrain[refiPercentageOutstandingThreat] then tsGameState['PercentageOutstandingThreat'] = aiBrain[refiPercentageOutstandingThreat] end
            tsGameState['PercentDistOfOurUnitClosestToEnemyBase'] = (aiBrain[refiPercentageClosestFriendlyToEnemyBase] or 'nil')

            if aiBrain[M27AirOverseer.refiOurMassInMAA] then tsGameState['OurMAAThreat'] = aiBrain[M27AirOverseer.refiOurMassInMAA] end
            if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] then tsGameState['EnemyAirThreat'] = aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] end

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

        aiBrain[refiACUHealthToRunOn] = 5250
        if iAllMexesInPathingGroupWeHaventClaimed <= iAllMexesInPathingGroup * 0.5 then aiBrain[refiACUHealthToRunOn] = 8000 end --We have majority of mexes so play safe with ACU
    end
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

function RecordAllEnemies(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'RecordAllEnemies'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of attempt to get backup list of enemies, will wait 5 seconds first') end
    WaitSeconds(5)
    local iOurIndex = aiBrain:GetArmyIndex()
    local iEnemyCount = 0
    if M27Utilities.IsTableEmpty(ArmyBrains) == false then
        for iCurBrain, oBrain in ArmyBrains do
            AllAIBrainsBackup[iCurBrain] = oBrain
            if IsEnemy(iOurIndex, oBrain:GetArmyIndex()) then
                iEnemyCount = iEnemyCount + 1
                toEnemyBrains[iEnemyCount] = oBrain
            end
        end
    else
        for iCurBrain, oBrain in AllAIBrainsBackup do
            if IsEnemy(iOurIndex, oBrain:GetArmyIndex()) then
                iEnemyCount = iEnemyCount + 1
                toEnemyBrains[iEnemyCount] = oBrain
            end
        end
    end
end

function RefreshMexPositions(aiBrain)
    WaitTicks(80)
    --Force refresh of mexes to try and fix bug where not all mexes recorded as being pathable
    M27MapInfo.RecheckPathingToMexes(aiBrain)
    ForkThread(M27MapInfo.RecordMexForPathingGroup)

    --Create sorted listing of mexes
    ForkThread(M27MapInfo.RecordSortedMexesInOriginalPathingGroup, aiBrain)
    --[[WaitTicks(400)
    ForkThread(M27MapInfo.RecordMexForPathingGroup, M27Utilities.GetACU(aiBrain), true)
    ForkThread(M27MapInfo.RecordSortedMexesInOriginalPathingGroup, aiBrain)--]]
end

function ACUInitialisation(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'ACUInitialisation'

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local oACU = M27Utilities.GetACU(aiBrain)
    oACU[refbACUOnInitialBuildOrder] = true
    local iCategoryToBuild = M27UnitInfo.refCategoryLandFactory
    local iMaxAreaToSearch = 14
    local iCategoryToBuildBy = M27UnitInfo.refCategoryT1Mex
    M27EngineerOverseer.BuildStructureAtLocation(aiBrain, oACU, iCategoryToBuild, iMaxAreaToSearch, iCategoryToBuildBy, nil)
    while aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllFactories) == 0 do
        WaitTicks(1)
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Have a factory unit now, so will set ACU platoon to use ACUMain') end


    local oNewPlatoon = aiBrain:MakePlatoon('', '')
    aiBrain:AssignUnitsToPlatoon(oNewPlatoon, {oACU}, 'Support', 'None')
    oNewPlatoon:SetAIPlan('M27ACUMain')
    oACU[refbACUOnInitialBuildOrder] = false
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
end

function OverseerInitialisation(aiBrain)
    --Below may get overwritten by later functions - this is just so we have a default/non nil value

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
    aiBrain[M27FactoryOverseer.refiEngineerCap] = 70 --Max engis of any 1 tech level even if have spare mass
    aiBrain[M27FactoryOverseer.reftiEngineerLowMassCap] = {35, 20, 20, 20} --Max engis to get if have low mass
    aiBrain[M27FactoryOverseer.refiMinimumTanksWanted] = 5
    aiBrain[M27PlatoonFormer.refbUsingMobileShieldsForPlatoons] = true
    aiBrain[refiCyclesThatACUHasNoPlatoon] = 0
    aiBrain[refiCyclesThatACUInArmyPool] = 0
    aiBrain[reftUnitGroupPreviousReferences] = {}

    aiBrain[refiOurHighestFactoryTechLevel] = 1

    aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons] = true

    aiBrain[refiIgnoreMexesUntilThisManyUnits] = 3 --Platoons wont attack lone structures if fewer than this many units (initially)

    --ACU specific
    local oACU = M27Utilities.GetACU(aiBrain)
    oACU[refbACUHelpWanted] = false


    --Grand strategy:
    aiBrain[refiAIBrainCurrentStrategy] = refStrategyLandEarly
    aiBrain[reftiMexIncomePrevCheck] = {}
    aiBrain[reftiMexIncomePrevCheck][1] = 0
    aiBrain[reftEnemyNukeLaunchers] = {}
    aiBrain[reftEnemyGroundExperimentals] = {}

    aiBrain[refiPercentageOutstandingThreat] = 0.5
    aiBrain[refiPercentageClosestFriendlyToEnemyBase] = 0.5
    aiBrain[refiNearestOutstandingThreat] = 1000
    aiBrain[refiEnemyHighestTechLevel] = 1

    M27MapInfo.SetWhetherCanPathToEnemy(aiBrain)

    InitiateLandFactoryConstructionManager(aiBrain)

    InitiateEngineerManager(aiBrain)
    WaitTicksSpecial(aiBrain, 1)

    InitiateUpgradeManager(aiBrain)
    WaitTicksSpecial(aiBrain, 1)
    ForkThread(M27PlatoonFormer.PlatoonIdleUnitOverseer, aiBrain)
    WaitTicksSpecial(aiBrain, 1)

    ForkThread(SwitchSoMexesAreNeverIgnored, aiBrain, 210) --e.g. on theta passage around the 3m mark raiders might still be coming across engis, so this gives extra 30s of engi hunting time

    ForkThread(RecordAllEnemies, aiBrain)

    ForkThread(RefreshMexPositions, aiBrain)

    ForkThread(M27AirOverseer.SetupAirOverseer, aiBrain)

    ForkThread(M27MapInfo.RecordStartingPathingGroups, aiBrain)

    ForkThread(ACUInitialisation, aiBrain) --Gets ACU to build its first building and then form ACUMain platoon once its done

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



function OverseerManager(aiBrain)
    local bDebugMessages = true if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'OverseerManager'


    --CONFIG
    M27ShowUnitNames = true

    --[[ForkThread(RunLotsOfLoopsPreStart)
    WaitTicks(10)
    LOG('TEMPTEST REPR after 10 ticks='..repr(tTEMPTEST))--]]
    ForkThread(M27MapInfo.MappingInitialisation, aiBrain)

    if bDebugMessages == true then LOG(sFunctionRef..': Pre fork thread of player start locations') end
    ForkThread(M27MapInfo.RecordPlayerStartLocations)
    --ForkThread(M27MapInfo.RecordResourceLocations, aiBrain) --need to do after 1 tick for adaptive maps - superceded by hook into siminit
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
    if bDebugMessages == true then LOG(sFunctionRef..': About to check pathing to mexes') end
    ForkThread(M27MapInfo.RecheckPathingToMexes, aiBrain) --Note that this includes waitticks, so dont make any big decisions on the map until it has finished

    if bDebugMessages == true then LOG(sFunctionRef..': Post wait 10 ticks') end
    OverseerInitialisation(aiBrain) --sets default values for variables, and starts the factory construction manager

    if bDebugMessages == true then LOG(sFunctionRef..': Pre record resource locations fork thread') end

    local iSlowerCycleThreshold = 10
    local iSlowerCycleCount = 0

    --ForkThread(M27MiscProfiling.ListCategoriesUsedByCount)

    if M27Config.M27ShowPathingGraphically then M27MapInfo.TempCanPathToEveryMex(M27Utilities.GetACU(aiBrain)) end

    DetermineInitialBuildOrder(aiBrain)
    local iTempProfiling

    while(not(aiBrain:IsDefeated())) do
        --M27MiscProfiling.OptimisationComparisonDistanceToStart(aiBrain)

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
        if aiBrain[refbIntelPathsGenerated] == false then RecordIntelPaths(aiBrain) end
        if aiBrain[refbIntelPathsGenerated] == true then
            ForkThread(AssignScoutsToPreferredPlatoons, aiBrain)
        end
        if bDebugMessages == true then
            --ArmyPoolContainsLandFacTest(aiBrain)
          --M27EngineerOverseer.TEMPTEST(aiBrain)
        end
        WaitTicksSpecial(aiBrain, 1)
        ForkThread(AssignMAAToPreferredPlatoons, aiBrain) --No point running logic for MAA helpers if havent created any scouts
        if bDebugMessages == true then
            LOG(sFunctionRef..': pre threat assessment')
            --ArmyPoolContainsLandFacTest(aiBrain)
          --M27EngineerOverseer.TEMPTEST(aiBrain)
            DebugPrintACUPlatoon(aiBrain)
        end

        WaitTicksSpecial(aiBrain, 1)
        ForkThread(ThreatAssessAndRespond, aiBrain)
        --if bDebugMessages == true then ArmyPoolContainsLandFacTest(aiBrain) end

        if bDebugMessages == true then
            LOG(sFunctionRef..': post threat assessment pre ACU manager')
            --ArmyPoolContainsLandFacTest(aiBrain)
          --M27EngineerOverseer.TEMPTEST(aiBrain)
        end

        WaitTicksSpecial(aiBrain, 1)
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

        WaitTicksSpecial(aiBrain, 1)
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

        WaitTicksSpecial(aiBrain, 1)
        ForkThread(M27EconomyOverseer.RefreshEconomyData, aiBrain)

        --NOTE: We dont have the number of ticks below as 'available' for use, since on initialisation we're waiting ticks as well when initialising things such as the engineer and upgrade overseers which work off their own loops
        --therefore the actual available tick count will be the below number less the number of ticks we're already waiting
        WaitTicksSpecial(aiBrain, 4) --Number of ticks should be based on how many ticks have waited in above code, so are refreshing every second


        if bDebugMessages == true then
            --ArmyPoolContainsLandFacTest(aiBrain)
          --M27EngineerOverseer.TEMPTEST(aiBrain)
            if M27Utilities.GetACU(aiBrain).GetNavigator and M27Utilities.GetACU(aiBrain):GetNavigator().GetCurrentTargetPos then LOG('ACU has a target in its navigator (wont reproduce to avoid desync)') end
            LOG(sFunctionRef..': End of overseer cycle code (about to start new cycle) ACU platoon=')
            DebugPrintACUPlatoon(aiBrain)
        end
        iTempProfiling = M27Utilities.ProfilerTimeSinceLastCall('End of overseer', iTempProfiling)
    end
end
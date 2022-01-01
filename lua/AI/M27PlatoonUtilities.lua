local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local AIBuildStructures = import('/lua/AI/aibuildstructures.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27PlatoonTemplates = import('/mods/M27AI/lua/AI/M27PlatoonTemplates.lua')
local M27PlatoonFormer = import('/mods/M27AI/lua/AI/M27PlatoonFormer.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27FactoryOverseer = import('/mods/M27AI/lua/AI/M27FactoryOverseer.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27UnitMicro = import('/mods/M27AI/lua/AI/M27UnitMicro.lua')
local M27EconomyOverseer = import('/mods/M27AI/lua/AI/M27EconomyOverseer.lua')

--    Platoon variables and constants:
--1) Action related
refiCurrentAction = 'M27CurrentAction'
reftPrevAction = 'M27PrevAction'
refbHavePreviouslyRun = 'M27HavePreviouslyRun'
refbForceActionRefresh = 'M27ForceActionRefresh' --E.g. used by overseer the first time a platoon is given a command
refiGameTimeOfLastRefresh = 'M27ForceActionRefresh' --so other code can reference to avoid forcing a refresh too often
refActionAttack = 1
refActionRun = 2
refActionContinueMovementPath = 3
refActionReissueMovementPath = 4 --as per refActionContinueMovementPath but ignores the 'dont refresh continue movementpath' check, and forces re-issuing of movement path even if prev action was a new movement path
refActionNewMovementPath = 5
refActionUseAttackAI = 6
refActionDisband = 7
refActionMoveDFToNearestEnemy = 8 --Direct fire units in the platoon move to the nearest enemy (doesnt affect scouts, T1 arti, and MAA)
refActionReturnToBase = 9
refActionReclaimTarget = 10 --Reclaim a specific target
refActionBuildMex = 11
refActionAssistConstruction = 12
refActionMoveJustWithinRangeOfNearestPD = 13
refActionMoveToTemporaryLocation = 14 --uses reftTemporaryMoveTarget
refActionAttackSpecificUnit = 15
refActionBuildLandFactory = 16
refActionBuildInitialPower = 17 --NOTE: I(f adding more build actions that the ACU will use, then update the overseer acu manager as it will clear engineer t rackers if the ACU switches to a different non-building action
refActionTemporaryRetreat = 18 --similar to actionrun, but wont clear movement path
refActionUpgrade = 19 --Either gets a new upgrade, or continues existing upgrade if we have one
refActionKillACU = 20 --Units will target enemy ACU if they have combat units, regardless of overrides
refActionReclaimAllNearby = 21 --Use normal engineer logic for reclaiming wrecks nearby

--Extra actions (i.e. performed in addition to main action)
refiExtraAction = 'M27ExtraActionRef'
refExtraActionOvercharge = 1
refExtraActionTargetUnit = 'M27ExtraActionTargetUnit'

local refiRefreshActionCount = 'M27RefreshActionCount' --used to track no. of times action has been skipped
refbOverseerAction = 'M27OverseerActionOverrideFlag'
refiOverseerAction = 'M27OverseerActionOverrideAction'
refiLastPrevActionOverride = 'M27PlatoonLastPrevActionOverride' --Used to track the most recent prev action number that used an overseer override
refbConsiderReclaim = 'M27ConsiderNearbyReclaim'
refbConsiderMexes = 'M27ConsiderNearbyMexes'
refbNeedToHeal = 'M27NeedToHeal'

--2) Pathing related
--refiLastPathTarget = 'M27LastPathTarget' --Replaced with table.getn due to too high a risk of error if this wasnt updated
refiCurrentPathTarget = 'M27CurrentPathTarget'
reftMovementPath = 'M27MovementPath'
refiCyclesForLastStuckAction = 'M27CyclesForLastStuckAction'
reftTemporaryMoveTarget = 'M27TemporaryMoveTarget'
refoTemporaryAttackTarget = 'M27TemporaryAttackTarget'
refoPrevTemporaryAttackTarget = 'M27PrevTemporaryAttackTarget'
reftMergeLocation = 'M27MergeLocation' --Temporarily stores the location for merged platoons to head to
reftFrontPosition = 'M27PlatoonFrontPosition' --Records position of the unit in the platoon nearest to the enemy base
refoFrontUnit = 'M27PlatoonFrontUnit' --Records the unit in the platoon nearest the enemy base
refiFrontUnitRefreshCount = 'M27PlatoonFrontRefreshCount' --Tracks how many cycles since we last refreshed the front unit
reftRearPosition = 'M27PlatoonRearPosition'
refoRearUnit = 'M27PlatoonRearUnit'
refiRearUnitRefreshCount = 'M27PlatoonRearRefreshCount'
refoPathingUnit = 'M27PlatoonPathingUnit'

--3) Unit related
reftCurrentUnits = 'M27CurrentUnitsTable'
refiCurrentUnits = 'M27CurrentUnitsCount'
refiPrevCurrentUnits = 'M27PrevUnitsCount'
reftDFUnits = 'M27DFUnitsTable'
reftIndirectUnits = 'M27IndirectUnitsTable'
reftScoutUnits = 'M27ScoutUnitsTable'
reftBuilders = 'M27BuilderUnitsTable'
reftReclaimers = 'M27ReclaimerUnitsTable'
reftUnitsWithShields = 'M27UnitsWithShieldTable'
refiDFUnits = 'M27DFUnitsCount'
refiIndirectUnits = 'M27IndirectUnitsCount'
refiScoutUnits = 'M27ScoutUnitsCount'
refiBuilders = 'M27BuilderUnitsCount'
refiReclaimers = 'M27ReclaimerUnitsCount'
refiUnitsWithShields = 'M27UnitsWithShieldCount'
refbACUInPlatoon = 'M27ACUInPlatoon'
refbCombatHoverInPlatoon = 'M27HoverInPlatoon'
refbPlatoonHasUnderwaterLand = 'M27PlatoonHasUnderwaterLand'
refbPlatoonHasOverwaterLand = 'M27PlatoonHasOverwaterLand'

reftFriendlyNearbyCombatUnits = 'M27FriendlyUnitsTable'
refiOverrideDistanceToReachDestination = 'M27OverrideDistanceToReachDestination'

refiEnemySearchRadius = 'M27EnemySearchRadius' --distance that have looked for nearby enemies when getting nearby enemy data
refiEnemiesInRange = 'M27EnemiesInRangeCount'
reftEnemiesInRange = 'M27EnemiesInRangeTable'
refiEnemyStructuresInRange = 'M27EnemiesInRangeStructureCount'
reftEnemyStructuresInRange = 'M27EnemiesInRangeStructureTable'
reftVisibleEnemyIndirect = 'M27EnemyIndirectInRangeTable'
refiVisibleEnemyIndirect = 'M27EnemyIndirectInRangeCount'
refiACUNearestEnemy = 'M27PlatoonACUNearestEnemy' --Nearest enemy to ACU platoon

reftPlatoonDFTargettingCategories = 'M27PlatoonTargettingReference' --variable name in unit info that contains the DF targetting for the platoon to use

--escort related
refoSupportHelperUnitTarget = 'M27ScoutHelperUnitTarget'
refoSupportHelperPlatoonTarget = 'M27ScoutHelperPlatoonTarget'
refiSupportHelperFollowDistance = 'M27ScoutHelperFollowDistance'
refoPlatoonOrUnitToEscort = 'M27PlatoonEscortPlatoon'
refoEscortingPlatoon = 'M27PlatoonEscortingPlatoon' --platoon that is escorting oPlatoon
refbShouldHaveEscort = 'M27PlatoonShouldHaveEscort'
refiNeedingEscortUniqueCount = 'M27NeedingEscortUniqueCount'
reftPlatoonsOrUnitsNeedingEscorts = 'M27TablePlatoonsNeedingEscorts'
refiEscortThreatWanted = 'M27PlatoonEscortThreatWanted'
refiCurrentEscortThreat = 'M27PlatoonCurEscortThreat'
refbNeedEscortUnits = 'M27PlatoonBrainNeedEscortUnits' --flag for the brain to say if any untis need an escort, used to determine what to produce at factories
refoSupportingShieldPlatoon = 'M27PlatoonSupportingShield' --if have a platoon with mobile shield units assigned to protect the platoon
reftLocationToGuard = 'M27LocationToGuard' --e.g. for scouts to stay by a mex

--5) Misc
refbPlatoonLogicActive = 'M27PlatoonLogicActive' --will toggle backup code to ensure platoon cycler is active in the event the normal platoon.lua fails to work
refbMovingToBuild = 'M27MovingToBuild'
refiMMLCountWhenLastSynchronised = 'M27PlatoonMMLsWhenLastSynchronised'
refiTimeOfLastSyncronisation = 'M27PlatoonTimeOfLastSyncronisation'
reftNearestTMDWhenLastSynchronised = 'M27PlatoonNearestTMDWhenLastSynchronised'
refiPlatoonThreatValue = 'M27PlatoonThreatValue'
refiPlatoonMassValue = 'M27PlatoonMassValue' --Used by escorts (if need to use for non-escort then need to update the function that records platoon information as for cpu optimisation reasons it only does this if the platoon has a flag that it needs an esecort
refiLifetimePlatoonCount = 'M27LifetimePlatoonCount'
refiPlatoonCount = 0 --Count of how many times a particular platoonAI has been initiated
reftNearbyMexToBuildOn = 'M27NearbyMexBuildTarget'
refoNearbyReclaimTarget = 'M27NearbyReclaimTarget'
refoConstructionToAssist = 'M27NearbyConstructionTarget'
refbHasBeenGivenExpansionOrder = 'M27HasBeenGivenExpansionOrder' --used for ACU platoon so can add extra checks if its not the first time its expanding
refbKiteEnemies = 'M27KiteEnemies' --True/false; set to true if want combat units to try and kite the enemy
refbKitingLogicActive = 'M27CurrentlyKiting'
refiPrevNearestEnemyDistance = 'M27PrevNearestEnemyDistance'
refoBrain = 'M27PlatoonBrain'

function UpdateUnitNames(tUnits, sNewName, bAddLifetimeCount)
    local sUnitNewName = sNewName
    for iUnit, oUnit in tUnits do
        if not(oUnit.Dead) then
            if oUnit.SetCustomName then
                if bAddLifetimeCount then sUnitNewName = sNewName..':LC='..M27UnitInfo.GetUnitLifetimeCount(oUnit) end
                oUnit:SetCustomName(sUnitNewName)
            else
                M27Utilities.ErrorHandler('oUnit cant have a custom name set, so likely isnt a unit')
            end
        end
    end
end

function UpdatePlatoonName(oPlatoon, sNewName)
    local sFunctionRef = 'UpdatePlatoonName'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if oPlatoon.GetPlan then
        local sPlan = oPlatoon:GetPlan()
        if sPlan == M27PlatoonTemplates.refoAllEngineers then
            --Do nothing - handled via engineer overseer
        elseif oPlatoon[M27PlatoonTemplates.refbIdlePlatoon] then
            --Update each name individually instead to note the Unit ref
            local tPlatoonUnits = oPlatoon:GetPlatoonUnits()
            if M27Utilities.IsTableEmpty(tPlatoonUnits) == false then
                for iUnit, oUnit in tPlatoonUnits do
                    if not(oUnit.Dead) then UpdateUnitNames({oUnit}, sNewName..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                end
            end
        else
            --Add details of who we are assisting if we're an assister/escort platoon
            if oPlatoon[refoPlatoonOrUnitToEscort] or oPlatoon[refoSupportHelperUnitTarget] or oPlatoon[refoSupportHelperPlatoonTarget] then
                local oUnitHelping
                local oPlatoonHelping

                if oPlatoon[refoPlatoonOrUnitToEscort] and oPlatoon[refoPlatoonOrUnitToEscort].GetUnitId then oUnitHelping = oPlatoon[refoPlatoonOrUnitToEscort]
                elseif oPlatoon[refoSupportHelperUnitTarget] and oPlatoon[refoSupportHelperUnitTarget].GetUnitId then
                    oUnitHelping = oPlatoon[refoSupportHelperUnitTarget]
                elseif oPlatoon[refoPlatoonOrUnitToEscort] and oPlatoon[refoPlatoonOrUnitToEscort].GetPlan then oPlatoonHelping = oPlatoon[refoPlatoonOrUnitToEscort]
                elseif oPlatoon[refoSupportHelperPlatoonTarget] and oPlatoon[refoSupportHelperPlatoonTarget].GetPlan then oPlatoonHelping = oPlatoon[refoSupportHelperPlatoonTarget]
                end
                if oUnitHelping and not(oUnitHelping.Dead) and oUnitHelping.GetUnitId then
                    sNewName = sNewName..': '..oUnitHelping:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnitHelping)
                elseif oPlatoonHelping then sNewName = sNewName..': '..oPlatoonHelping:GetPlan()..(oPlatoonHelping[refiPlatoonCount] or '0') end
            end
            UpdateUnitNames(GetPlatoonUnits(oPlatoon), sNewName, true)
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetPlatoonFrontPosition(oPlatoon)
    --M27Utilities.ErrorHandler('Temp To help ID crash')
    if oPlatoon[reftFrontPosition] then return oPlatoon[reftFrontPosition]
    else
        if oPlatoon.GetUnitId then return oPlatoon:GetPosition()
        else
            return oPlatoon:GetPlatoonPosition() end
    end
end

function GetPlatoonRearPosition(oPlatoon)
    --M27Utilities.ErrorHandler('Temp To help ID crash')
    if oPlatoon[reftRearPosition] then return oPlatoon[reftRearPosition]
    else
        if oPlatoon.GetUnitId then return oPlatoon:GetPosition()
        else
            return oPlatoon:GetPlatoonPosition() end
    end
end

function GetActivePlatoonCount(aiBrain, sPlatoonPlan)
    --Returns the number of platoons using sPlatoonPlan that contain alive units
    local sFunctionRef = 'GetActivePlatoonCount'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iMatchingPlatoonCount = 0
    if sPlatoonPlan then
        for iPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
            if oPlatoon.GetPlan and oPlatoon:GetPlan() == sPlatoonPlan then
                iMatchingPlatoonCount = iMatchingPlatoonCount + 1
            end
        end
    else M27Utilities.ErrorHandler('sPlatoonPlan is nil')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iMatchingPlatoonCount
end

function GetPlatoonUnitsOrUnitCount(oPlatoon, sFriendlyUnitTableVariableWanted, bReturnCountNotTable, bOnlyGetIfUnitAvailable)
    --if bOnlyGetIfUnitAvailable is true then will check if unit is microing on special task and exclude it
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetPlatoonUnitsOrUnitCount'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tBaseVariable = oPlatoon[sFriendlyUnitTableVariableWanted]
    local tNewVariable = {}
    local iCount = 0
    if bDebugMessages == true then LOG(sFunctionRef..': '..oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]..': Start of code') end
    if not(bOnlyGetIfUnitAvailable) or not(oPlatoon[M27UnitInfo.refbSpecialMicroActive]) then
        if bDebugMessages == true then LOG(sFunctionRef..': Either no micro active or not interested in checking if its active') end
        if oPlatoon[M27UnitInfo.refbSpecialMicroActive] then LOG('refbSpecialMicroActive='..tostring(oPlatoon[M27UnitInfo.refbSpecialMicroActive])) end
        if not(bOnlyGetIfUnitAvailable==nil) and bDebugMessages == true then LOG('bOnlyGetIfUnitAvailable='..tostring(bOnlyGetIfUnitAvailable)) end
        if bReturnCountNotTable then
            if M27Utilities.IsTableEmpty(tBaseVariable) == true then iCount = 0 else iCount = table.getn(tBaseVariable) end
            return iCount
        else
            return tBaseVariable
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': Want to exclude any units on micro duty') end
        --Want to exclude units on micro duty
        if M27Utilities.IsTableEmpty(tBaseVariable) == true then
            if bReturnCountNotTable then return 0 else return tBaseVariable end
        else

            for iUnit, oUnit in tBaseVariable do
                if bDebugMessages == true then LOG(sFunctionRef..': Considering if micro active for oUnit='..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                if not(oUnit[M27UnitInfo.refbSpecialMicroActive]) then
                    iCount = iCount + 1
                    if not(bReturnCountNotTable) then tNewVariable[iCount] = oUnit end
                    if bDebugMessages == true then LOG(sFunctionRef..': Micro isnt active for this unit so will include in the table variable') end
                end
            end
            if bReturnCountNotTable then return iCount else return tNewVariable end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ShouldPlatoonMoveInFormation(oPlatoon, bAttackMove)
    local sFunctionRef = 'ShouldPlatoonMoveInFormation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bMoveInFormation = false
    if oPlatoon[M27PlatoonTemplates.refbFormMoveIfCloseTogetherAndNoEnemies] and oPlatoon[refiEnemiesInRange] == 0 and oPlatoon[refiEnemyStructuresInRange] == 0 then
        --Are the front and rear platoon units close together?
        if M27Utilities.GetDistanceBetweenPositions(GetPlatoonFrontPosition(oPlatoon), GetPlatoonRearPosition(oPlatoon)) <= oPlatoon[M27PlatoonTemplates.refiFormMoveCloseDistanceThreshold] then
            bMoveInFormation = true
        end
    end
    if bMoveInFormation == false then
        local sFormation = oPlatoon.PlatoonData.UseFormation
        if sFormation == nil then sFormation = 'GrowthFormation' end
        if bAttackMove == false and not(sFormation == 'GrowthFormation') then
            if bDebugMessages == true then LOG(sFunctionRef..': Not attack-moving and not using growth formation so will move in formation') end
            bMoveInFormation = true
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bMoveInFormation
end

function MoveAlongPath(oPlatoon, tMovementPath, bAttackMove, iPathStartPoint, bDontClearActions)
    --iPathStartPoint - defaults to 1 (first entry in tMovementPath); otherwise will ignore earlier entries in tMovementPath
    if iPathStartPoint == nil then iPathStartPoint = 1 end
    if bAttackMove == nil then bAttackMove = false end
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end
    --if oPlatoon:GetPlan() == 'M27MAAAssister' then bDebugMessages = true end
    local sFunctionRef = 'MoveAlongPath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tCurrentUnits = {}
    --tCurrentUnits = oPlatoon[reftCurrentUnits]

    tCurrentUnits = GetPlatoonUnitsOrUnitCount(oPlatoon, reftCurrentUnits, false, true)
    if M27Utilities.IsTableEmpty(tCurrentUnits) == false then
        local tLocation = {}
        if bDebugMessages == true then LOG(sFunctionRef..': '..oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]..': Start of function; iPathStartPoint='..iPathStartPoint..'; tMovementPath size='..table.getn(tMovementPath)..'; currentunits='..table.getn(oPlatoon[reftCurrentUnits])) end
        local bMoveInFormation = ShouldPlatoonMoveInFormation(oPlatoon, bAttackMove)
        for iCurPath = iPathStartPoint, table.getn(tMovementPath) do
            --for iLoc, tLocation in tMovementPath do
            tLocation = tMovementPath[iCurPath]
            if iCurPath == iPathStartPoint then
                if bDebugMessages == true then LOG(sFunctionRef..': Clearing existing actions') end
                --tCurrentUnits = GetPlatoonUnits(oPlatoon)
                if bDontClearActions == false then IssueClearCommands(tCurrentUnits) end
            end

            if bDebugMessages == true then LOG(sFunctionRef..': Moving to tLocationXZ='..tLocation[1]..'-'..tLocation[3]..'; deciding whether will be in formation.  oPlatoon[M27PlatoonTemplates.refbFormMoveIfCloseTogetherAndNoEnemies]='..tostring(oPlatoon[M27PlatoonTemplates.refbFormMoveIfCloseTogetherAndNoEnemies] or false)..'; oPlatoon[refiEnemiesInRange]='..oPlatoon[refiEnemiesInRange]..'oPlatoon[refiEnemyStructuresInRange]='..oPlatoon[refiEnemyStructuresInRange]..'; distance between front and rear position='..M27Utilities.GetDistanceBetweenPositions(GetPlatoonFrontPosition(oPlatoon), GetPlatoonRearPosition(oPlatoon))..'; oPlatoon[M27PlatoonTemplates.refiFormMoveCloseDistanceThreshold]='..(oPlatoon[M27PlatoonTemplates.refiFormMoveCloseDistanceThreshold] or 'nil')..'; bMoveInFormation='..tostring(bMoveInFormation)) end
            local sFormation = oPlatoon.PlatoonData.UseFormation
            if sFormation == nil then sFormation = 'GrowthFormation' end

            if bAttackMove == true then
                if bMoveInFormation then IssueFormAggressiveMove(tCurrentUnits, tLocation, sFormation, 0)
                else IssueAggressiveMove(tCurrentUnits, tLocation) end

            else
                if bDebugMessages == true then LOG(sFunctionRef..': '..oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]..': sFormation='..sFormation..': Will issue form move if its growth; tLocation='..repr(tLocation)) end
                if bMoveInFormation == true then IssueFormMove(tCurrentUnits, tLocation, sFormation, 0)
                else IssueMove(tCurrentUnits, tLocation) end
            end
        end
        --oPlatoon[refiLastPathTarget] = table.getn(tMovementPath)
        if iPathStartPoint > table.getn(oPlatoon[reftMovementPath]) then iPathStartPoint = table.getn(oPlatoon[reftMovementPath]) end --redundancy just in case
        oPlatoon[refiCurrentPathTarget] = iPathStartPoint
    else
        if oPlatoon[refiCurrentUnits] == 0 then
            if bDebugMessages == true then LOG(sFunctionRef..': Disbanding platoon') end
            oPlatoon[refiCurrentAction] = refActionDisband
        else
            if bDebugMessages == true then LOG(sFunctionRef..': All units in platoon are microing so not doing anything') end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    --[[if bDebugMessages == true then
        LOG(sFunctionRef..'TEMP ERROR - Platoon not moving - delaying code 5s')
        WaitSeconds(5)
    end]]--
end

function GetPlatoonPositionDeviation(oPlatoon)
    --Returns the standard deviation in positions of oPlatoon; will target a centre point whose size increases based on the platoon size
    --very approximate guide: <3 is close, >10 spread out, >30 very spread out, >100 likely on different parts of the map altogether
    local sFunctionRef = 'GetPlatoonPositionDeviation'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tPositions = {}
    local iCount = 0
    if oPlatoon[refiCurrentUnits] > 0 then
        for iCurUnit=1, oPlatoon[refiCurrentUnits] do
            tPositions[iCurUnit] = oPlatoon[reftCurrentUnits][iCurUnit]:GetPosition()
        end
        local iCentreSize = math.sqrt(oPlatoon[refiCurrentUnits])*3
        if bDebugMessages == true then LOG(oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]..': GetPlatoonPositionDeviation: CentreSize='..iCentreSize..'; UnitCount='..oPlatoon[refiCurrentUnits]) end
        if bDebugMessages == true then LOG(oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]..': Deviation='..M27Utilities.CalculateDistanceDeviationOfPositions(tPositions, iCentreSize)) end
        local iDeviation = M27Utilities.CalculateDistanceDeviationOfPositions(tPositions, iCentreSize)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return iDeviation
    else
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return 0
    end
end

function TestAltMostRestriveLayer(platoon)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'TestAltMostRestriveLayer'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    -- in case the platoon is already destroyed return false.
    if not platoon then
        if bDebugMessages == true then LOG(sFunctionRef..': platoon is nil, returning false') end
        return false
    end
    local unit = false
    platoon.MovementLayer = 'Air'
    for k,v in platoon:GetPlatoonUnits() do
        if not v.Dead then
            local mType = v:GetBlueprint().Physics.MotionType
            if bDebugMessages == true then LOG(sFunctionRef..': MotionType for Unit '..v:GetUnitId()..' is '..mType) end
            if (mType == 'RULEUMT_AmphibiousFloating' or mType == 'RULEUMT_Hover' or mType == 'RULEUMT_Amphibious') and (platoon.MovementLayer == 'Air' or platoon.MovementLayer == 'Water') then
                platoon.MovementLayer = 'Amphibious'
                unit = v
            elseif (mType == 'RULEUMT_Water' or mType == 'RULEUMT_SurfacingSub') and (platoon.MovementLayer ~= 'Water') then
                platoon.MovementLayer = 'Water'
                unit = v
                break   --Nothing more restrictive than water, since there should be no mixed land/water platoons
            elseif mType == 'RULEUMT_Air' and platoon.MovementLayer == 'Air' then
                platoon.MovementLayer = 'Air'
                unit = v
            elseif (mType == 'RULEUMT_Biped' or mType == 'RULEUMT_Land') and platoon.MovementLayer ~= 'Land' then
                platoon.MovementLayer = 'Land'
                unit = v
                break   --Nothing more restrictive than land, since there should be no mixed land/water platoons
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return unit
end


function GetPathingUnit(oPlatoon, oExistingPathingUnit, bRecheckAllUnits)
    --if oExistingPathingUnit is specified, then returns this if it's still alive
    --otherwise, returns the most restrictive pathing unit in the platoon
    --returns nil if no valid units
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetPathingUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if oPlatoon:GetPlan() == 'M27LargeAttackForce' then bDebugMessages = true end
    local bGetNewUnit = false
    local oNewPathingUnit
    if oExistingPathingUnit == nil then oExistingPathingUnit = oPlatoon[refoPathingUnit] end
    if oExistingPathingUnit == nil or bRecheckAllUnits then bGetNewUnit = true
    elseif oExistingPathingUnit.Dead then bGetNewUnit = true end

    if bGetNewUnit == true then
        if bDebugMessages == true then LOG(sFunctionRef..': Get unit with worst pathing in platoon') end
        if bDebugMessages == true then oNewPathingUnit = TestAltMostRestriveLayer(oPlatoon)
            else oNewPathingUnit = AIAttackUtils.GetMostRestrictiveLayer(oPlatoon)
        end
        if oNewPathingUnit == false then
            if bDebugMessages == true then LOG(sFunctionRef..': aiAttackUtils returned false') end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return nil
        elseif oNewPathingUnit == nil then
            if bDebugMessages == true then LOG(sFunctionRef..': aiAttackUtils returned nil') end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return nil
        elseif oNewPathingUnit.Dead then
            if bDebugMessages == true then LOG(sFunctionRef..': aiAttackUtils returned dead unit') end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return nil
        end
    else oNewPathingUnit = oExistingPathingUnit
    end
    if oNewPathingUnit.Dead then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return nil
    else
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return oNewPathingUnit
    end
end

function RemoveUnitsFromPlatoon(oPlatoon, tUnits, bReturnToBase, oPlatoonToAddTo)
    --if bReturnToBase is true then units will be told to move to aiBrain's base
    --if tUnits isnt in oPlatoon then does nothing
    --If try to assign to armypool platoon then instead tries to form a platoon
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RemoveUnitsFromPlatoon'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if oPlatoon and oPlatoon.GetBrain and oPlatoon.GetPlan and not(oPlatoon.Dead) then
        local aiBrain = oPlatoon:GetBrain()

        --if tUnits[1] == M27Utilities.GetACU(aiBrain) then bDebugMessages = true LOG(sFunctionRef..': ACU is about to be removed from its current platoon='..M27Overseer.DebugPrintACUPlatoon(aiBrain, true)) end
        if bDebugMessages == true then
            LOG(sFunctionRef..': About to list out every unit that is about to be removed')
            for iUnit, oUnit in tUnits do
                if oUnit.GetUnitId then LOG('iUnit='..iUnit..'; oUnitId='..oUnit:GetUnitId())
                else LOG('iUnit='..iUnit..'; Unit has no unitId') end
            end
        end
        if not(oPlatoonToAddTo == oPlatoon) then
            local oArmyPool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
            --if not(oPlatoon==oArmyPool) then if oPlatoon:GetPlan() == 'M27ACUMain' then bDebugMessages = true end end
            local sName
            if oPlatoonToAddTo == nil then
                if bDebugMessages == true then LOG(sFunctionRef..': Will add units to army pool') end
                oPlatoonToAddTo = oArmyPool
                sName = 'ArmyPool'
            else
                if oPlatoonToAddTo == oArmyPool then sName = 'ArmyPool'
                else
                    if oPlatoonToAddTo.GetPlan then
                        sName = oPlatoonToAddTo:GetPlan()
                    end
                    if sName == nil then sName = 'nil' end
                    if oPlatoonToAddTo[refiPlatoonCount] == nil then sName = sName..0
                    else sName = sName..oPlatoonToAddTo[refiPlatoonCount]
                    end
                    oPlatoonToAddTo[refbForceActionRefresh] = true
                    if bDebugMessages == true then LOG(sFunctionRef..': Adding unit to '..sName..'; oPlatoonToAddTo[refbForceActionRefresh] = '..tostring(oPlatoonToAddTo[refbForceActionRefresh])) end
                end
            end
            if oPlatoonToAddTo == nil then
                LOG(sFunctionRef..': WARNING: oPlatoonToAddTo is nil')
            else
                local sCurPlatoonName
                if oPlatoon == oArmyPool then
                    sCurPlatoonName = 'ArmyPool'
                else
                    sCurPlatoonName = oPlatoon:GetPlan()
                    if sCurPlatoonName == nil then sCurPlatoonName = 'None' end
                    if oPlatoon[refiPlatoonCount] == nil then sCurPlatoonName = sCurPlatoonName..0
                    else sCurPlatoonName = sCurPlatoonName..oPlatoon[refiPlatoonCount] end
                    if bDebugMessages == true then LOG(sFunctionRef..': sCurPlatoonName='..sCurPlatoonName) end
                end

                if not(sCurPlatoonName == sName) then
                    if bDebugMessages == true then
                        if oPlatoon == oArmyPool then
                            M27Utilities.ErrorHandler('ideally shouldnt have any units using armypool platoon now, see if can figure out where this came from')
                            LOG(sFunctionRef..': About to remove units from ArmyPool platoon and add to platoon '..sName)
                        else
                            LOG(sFunctionRef..': About to remove units from platoon '..oPlatoon:GetPlan())
                            if oPlatoon[refiPlatoonCount] == nil then LOG('which has nil count') else LOG('which has count='..oPlatoon[refiPlatoonCount]) end
                        end
                    end
                    IssueClearCommands(tUnits)
                    if bReturnToBase == true then
                        if bDebugMessages == true then LOG(sFunctionRef..': Issuing move command to tUnits') end
                        IssueMove(tUnits, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) end

                    if oPlatoonToAddTo == oArmyPool then
                        if bDebugMessages == true then
                            LOG(sFunctionRef..'; tUnits size='..table.getn(tUnits)..'; IsTableEmpty='..tostring(M27Utilities.IsTableEmpty(tUnits)))
                        end

                        M27PlatoonFormer.AllocateUnitsToIdlePlatoons(aiBrain, tUnits)
                        M27PlatoonFormer.AllocateNewUnitsToPlatoonNotFromFactory(tUnits)
                    else
                        aiBrain:AssignUnitsToPlatoon(oPlatoonToAddTo, tUnits, 'Unassigned', 'None')
                        if M27Config.M27ShowUnitNames == true then
                            if bDebugMessages == true then LOG(sFunctionRef..': About to update name to '..sName) end
                            UpdatePlatoonName(oPlatoonToAddTo, sName)
                        end
                        if oPlatoonToAddTo == oArmyPool then
                            M27PlatoonFormer.AllocateNewUnitsToPlatoonNotFromFactory(tUnits)
                        end
                        --Update basic platoon tracker details
                        RecordPlatoonUnitsByType(oPlatoon)
                    end
                end
            end
        end
        if bDebugMessages == true then if tUnits[1] == M27Utilities.GetACU(aiBrain) then LOG(sFunctionRef..': end of function; ACU current platoon='..M27Overseer.DebugPrintACUPlatoon(aiBrain, true)) end end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end


function GetCyclesSinceLastMoved(oUnit, bIsPlatoonNotUnit, iTriggerDistance)
    --returns the number of times this function has been called where oUnit hasnt moved by more than x spaces
    local sFunctionRef = 'GetCyclesSinceLastMoved'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bIsPlatoonNotUnit == nil then bIsPlatoonNotUnit = false end

    local iDistTreatedAsStuck = iTriggerDistance
    if iDistTreatedAsStuck == nil then
        if bIsPlatoonNotUnit == true and oUnit.GetPlatoonUnits then
            iDistTreatedAsStuck = 4 + math.floor(oUnit[refiCurrentUnits] / 4)
            if iDistTreatedAsStuck > 15 then iDistTreatedAsStuck = 15 end
        else iDistTreatedAsStuck = 5 end
    end
    local sLastX = 'M27LastX'
    local sLastZ = 'M27LastZ'
    local sCyclesSinceMoved = 'M27CyclesSinceMoved'
    local iLastX = oUnit[sLastX]
    local iLastZ = oUnit[sLastZ]
    local tCurPos = {}
    if oUnit == nil then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return 0
    elseif oUnit.Dead then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return 0
    else
        if bIsPlatoonNotUnit then tCurPos = GetPlatoonFrontPosition(oUnit)
        else tCurPos = oUnit:GetPosition() end
        local iCyclesSinceMoved
        if iLastX == nil or iLastZ == nil then iCyclesSinceMoved = 0
        else
            if M27Utilities.GetDistanceBetweenPositions(tCurPos, { iLastX, 0, iLastZ }) <= iDistTreatedAsStuck then
                iCyclesSinceMoved = oUnit[sCyclesSinceMoved]
                if iCyclesSinceMoved == nil then iCyclesSinceMoved = 0 end
                iCyclesSinceMoved = iCyclesSinceMoved + 1
            else
                iCyclesSinceMoved = 0
            end
        end
        if iCyclesSinceMoved == 0 then
            oUnit[sLastX] = tCurPos[1]
            oUnit[sLastZ]= tCurPos[3]
        end
        oUnit[sCyclesSinceMoved] = iCyclesSinceMoved
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return iCyclesSinceMoved
    end
end

function IsDestinationAwayFromNearbyEnemies(aiBrain, tCurPos, tCurDestination, iEnemySearchRadius, bAlsoRunFromEnemyStartLocation)
    --Used for running away from enemies (if they have a threat rating)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsDestinationAwayFromNearbyEnemies'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bIsAwayFromNearbyEnemies = false
    local bStoppedLoop = false
    local tNearbyEnemies = aiBrain:GetUnitsAroundPoint(categories.ALLUNITS, tCurPos, iEnemySearchRadius, 'Enemy')
    local iClosestEnemyDist = 100000
    local iEnemyDistFromTarget
    if tNearbyEnemies == nil then bIsAwayFromNearbyEnemies = true
    else
        if table.getn(tNearbyEnemies) == 0 then bIsAwayFromNearbyEnemies = true
        else
            --Filter to just show units with a threat rating:
            local tEnemiesWithThreat = {}
            for iCurUnit, oCurUnit in tNearbyEnemies do
                if M27Logic.GetCombatThreatRating(aiBrain, { oCurUnit}, true) > 0 then
                    table.insert(tEnemiesWithThreat, oCurUnit)
                end
            end
            if table.getn(tEnemiesWithThreat) == 0 then bIsAwayFromNearbyEnemies = true
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Have nearby enemies with threat, so about to check if are moving away') end
                local tRunAwayComparisonPos = {}
                local iComparisonDistance = 5
                if M27Utilities.GetDistanceBetweenPositions(tCurPos, tCurDestination) <= iComparisonDistance then
                    if bDebugMessages == true then LOG(sFunctionRef..': Current destination is less than 5 from current position so will use current destination instead of getting comparison location') end
                    tRunAwayComparisonPos = tCurDestination
                    --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
                else
                    tRunAwayComparisonPos =  M27Utilities.MoveTowardsTarget(tCurPos, tCurDestination, iComparisonDistance, 0)
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': Only want to move 5 along the current destination to see if its further from enemy; tRunAwayComparisonPos='..repr(tRunAwayComparisonPos))
                        M27Utilities.DrawLocation(tRunAwayComparisonPos, nil, 2)
                    end
                end


                local iDistFromComparison, iDistFromStart
                local tUnitCurPos
                bIsAwayFromNearbyEnemies = true
                for iCurUnit, oCurUnit in tEnemiesWithThreat do
                    tUnitCurPos = oCurUnit:GetPosition()
                    iDistFromStart = M27Utilities.GetDistanceBetweenPositions(tCurPos, tUnitCurPos)
                    iDistFromComparison = M27Utilities.GetDistanceBetweenPositions(tRunAwayComparisonPos, tUnitCurPos)
                    iEnemyDistFromTarget = M27Utilities.GetDistanceBetweenPositions(tUnitCurPos, tCurDestination)
                    if bDebugMessages == true then LOG(sFunctionRef..': iCurUnit='..iCurUnit..': iDistFromStart='..iDistFromStart..'; iDistFromComparison='..iDistFromComparison..'; iEnemyDistFromTarget='..iEnemyDistFromTarget) end
                    if iDistFromComparison < iDistFromStart then
                        if bDebugMessages == true then LOG(sFunctionRef..': iCurUnit='..iCurUnit..': The location to run to is closer to this enemy than where the unit currently is') end
                        bIsAwayFromNearbyEnemies = false
                        bStoppedLoop = true
                        break
                    --[[elseif iEnemyDistFromTarget < iClosestEnemyDist then

                        iClosestEnemyDist = iEnemyDistFromTarget

                        if iClosestEnemyDist > iEnemySearchRadius then
                            --No need to keep looking as this position is further away than we're interested in
                            bStoppedLoop = true
                            break
                        end--]]
                    end
                end
                if bStoppedLoop == false then bIsAwayFromNearbyEnemies = true end
            end
        end
    end
    if bIsAwayFromNearbyEnemies == true then
        --Do we also want to be away from the enemy start?
        if bAlsoRunFromEnemyStartLocation == nil or bAlsoRunFromEnemyStartLocation == false then

            bIsAwayFromNearbyEnemies = true
        else
            if bDebugMessages == true then LOG('IsDestinationAwayFromEnemy: Is away from nearest enemy, checking if away from enemy start pos') end
            local bEnemyStartXLessThanTarget = false
            local bEnemyStartZLessThanTarget = false
            local bEnemyStartXLessThanOurs = false
            local bEnemyStartZLessThanOurs = false
            local iEnemyStartNumber = M27Logic.GetNearestEnemyStartNumber(aiBrain)
            if iEnemyStartNumber == nil then
                M27Utilities.ErrorHandler('iEnemyStartNumber=nil')
            else
                local tEnemyStartPosition = M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]
                if tEnemyStartPosition[1] < tCurDestination[1] then bEnemyStartXLessThanTarget = true end
                if tEnemyStartPosition[3] < tCurDestination[3] then bEnemyStartZLessThanTarget = true end
                if tEnemyStartPosition[1] < tCurPos[1] then bEnemyStartXLessThanOurs = true end
                if tEnemyStartPosition[3] < tCurPos[3] then bEnemyStartZLessThanOurs = true end
                if bEnemyStartXLessThanOurs == bEnemyStartXLessThanTarget and bEnemyStartZLessThanOurs == bEnemyStartZLessThanTarget then
                    if bDebugMessages == true then LOG('IsDestinationAwayFromEnemy: Is away from enemy start as well') end
                    bIsAwayFromNearbyEnemies = true
                else
                    if bDebugMessages == true then LOG('IsDestinationAwayFromEnemy: Isnt away from enemystart; tCurPos[1][3]='..tCurPos[1]..'-'..tCurPos[3]..'tCurDestination='..tCurDestination[1]..'-'..tCurDestination[3]..'; tEnemyStartPosition='..tEnemyStartPosition[1]..'-'..tEnemyStartPosition[3]) end
                    bIsAwayFromNearbyEnemies = false end
            end
        end
    else
        bIsAwayFromNearbyEnemies = false
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bIsAwayFromNearbyEnemies
end


function IsDestinationAwayFromNearbyEnemy(tCurPos, tCurDestination, oNearestEnemy, bAlsoRunFromEnemyStartLocation)
    --Quicker but more limited version of 'NearbyEnemies' - will only consider the nearest enemy
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsDestinationAwayFromNearbyEnemy'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tNearestEnemy = oNearestEnemy:GetPosition()
    --Does the current target move us away from the enemy in both directions? If so then dont change it
    local bXLessThanOurs = false
    local bZLessThanOurs = false
    local bTargetXLessThanOurs = false
    local bTargetZLessThanOurs = false


    if tCurPos[1] > tNearestEnemy[1] then bXLessThanOurs = true end
    if tCurPos[3] > tNearestEnemy[3] then bZLessThanOurs = true end
    if tCurPos[1] > tCurDestination[1] then bTargetXLessThanOurs = true end
    if tCurPos[3] > tCurDestination[3] then bTargetZLessThanOurs = true end
    if bDebugMessages == true then LOG(sFunctionRef..': Choosing location to run away to; tCurPos='..tCurPos[1]..'-'..tCurPos[3]) end
    if bDebugMessages == true then LOG('tNearestEnemy='..tNearestEnemy[1]..'-'..tNearestEnemy[3]) end
    if bDebugMessages == true then LOG('bTargetXLessThanOurs='..tostring(bTargetXLessThanOurs)..'; bTargetZLessThanOurs='..tostring(bTargetXLessThanOurs)) end
    if bTargetXLessThanOurs == bXLessThanOurs or bTargetZLessThanOurs == bZLessThanOurs then
        if bDebugMessages == true then LOG(sFunctionRef..': Isnt away from oNearestEnemy; tCurPos[1][3]='..tCurPos[1]..'-'..tCurPos[3]..'tNearestEnemy='..tNearestEnemy[1]..'-'..tNearestEnemy[3]..'; tCurDestination='..tCurDestination[1]..'-'..tCurDestination[3]) end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return false
    else
        if bAlsoRunFromEnemyStartLocation == nil or bAlsoRunFromEnemyStartLocation == false then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return true
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Is away from nearest enemy, checking if away from enemy start pos') end
            local bEnemyStartXLessThanTarget = false
            local bEnemyStartZLessThanTarget = false
            local bEnemyStartXLessThanOurs = false
            local bEnemyStartZLessThanOurs = false
            local tEnemyStartPosition = M27MapInfo.PlayerStartPoints[oNearestEnemy:GetAIBrain().M27StartPositionNumber]
            if tEnemyStartPosition[1] < tCurDestination[1] then bEnemyStartXLessThanTarget = true end
            if tEnemyStartPosition[3] < tCurDestination[3] then bEnemyStartZLessThanTarget = true end
            if tEnemyStartPosition[1] < tCurPos[1] then bEnemyStartXLessThanOurs = true end
            if tEnemyStartPosition[3] < tCurPos[3] then bEnemyStartZLessThanOurs = true end
            if bEnemyStartXLessThanOurs == bEnemyStartXLessThanTarget and bEnemyStartZLessThanOurs == bEnemyStartZLessThanTarget then
                if bDebugMessages == true then LOG(sFunctionRef..': Is away from enemy start as well') end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return true
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Isnt awway from enemystart; tCurPos[1][3]='..tCurPos[1]..'-'..tCurPos[3]..'tCurDestination='..tCurDestination[1]..'-'..tCurDestination[3]..'; tEnemyStartPosition='..tEnemyStartPosition[1]..'-'..tEnemyStartPosition[3]) end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return false
            end
        end
    end
end


function MergePlatoons(oPlatoonToMergeInto, oPlatoonToBeMerged)
    --Adds all units from oPlatoonToBeMerged into oPlatoonToMergeInto unless they're dead or attached
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MergePlatoons'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tMergingUnits = oPlatoonToBeMerged:GetPlatoonUnits()
    local tValidUnits = {}
    local bValidUnits = false
    local aiBrain = oPlatoonToMergeInto:GetBrain()
    local oArmyPool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    if oPlatoonToMergeInto == oArmyPool then
        M27PlatoonFormer.AllocateUnitsToIdlePlatoons(aiBrain, tMergingUnits)
    else
        for iCurUnit, oUnit in tMergingUnits do
            if not oUnit.Dead and not oUnit:IsUnitState('Attached') then
                if bDebugMessages == true then
                    if oUnit == M27Utilities.GetACU(aiBrain) then
                        LOG(sFunctionRef..': oPlatoon includes ACU; oPlatoonTo mergeInto plan='..oPlatoonToMergeInto:GetPlan()..oPlatoonToMergeInto[refiPlatoonCount])
                        if oPlatoonToBeMerged == aiBrain:GetPlatoonUniquelyNamed('ArmyPool') then LOG('oPlatoonToBeMerged is army pool')
                        else LOG('oPlatoonToBeMerged='..oPlatoonToBeMerged:GetPlan()..oPlatoonToBeMerged[refiPlatoonCount])
                        end
                    end
                end
                table.insert(tValidUnits, oUnit)
                bValidUnits = true
            end
        end
        if bValidUnits == true then
            if bDebugMessages == true then LOG('MergePlatoons: have units in tMergingUnits; table.getn(tMergingUnits)='..table.getn(tMergingUnits)) end
            if M27Config.M27ShowUnitNames == true then
                local sPlanOfNewPlatoon = oPlatoonToMergeInto:GetPlan()
                if sPlanOfNewPlatoon == nil then sPlanOfNewPlatoon = 'UnknownPlan' end
                local iPlanOfNewPlatoon = oPlatoonToMergeInto[refiPlatoonCount]
                if iPlanOfNewPlatoon == nil then iPlanOfNewPlatoon = 0 end
                UpdatePlatoonName(oPlatoonToBeMerged, 'MergeInto:'..sPlanOfNewPlatoon..iPlanOfNewPlatoon) end
            local sFormation = oPlatoonToMergeInto.PlatoonData.UseFormation
            if sFormation == nil then sFormation = 'GrowthFormation' end
            aiBrain:AssignUnitsToPlatoon(oPlatoonToMergeInto, tValidUnits, 'Attack', sFormation)
            --Reissue movement path to just these units
            if M27Utilities.IsTableEmpty(oPlatoonToMergeInto[reftMovementPath]) == false then
                MoveAlongPath(oPlatoonToMergeInto, oPlatoonToMergeInto[reftMovementPath], oPlatoonToMergeInto[M27PlatoonTemplates.refbAttackMove], oPlatoonToMergeInto[refiCurrentPathTarget], false)
                ForceActionRefresh(oPlatoonToMergeInto)
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Disbanding oPlatoonToBeMerged') end
    oPlatoonToBeMerged[refiCurrentAction] = refActionDisband
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetMergeLocation(oPlatoonToMergeInto, iPercentOfWayToDestination)
    --Returns a pathable location as close to iPercentOfWayToDestination% of the way to oPlatoonToMergeInto's first movement path position as possible, or nil if a pathable location can't be found
    --iPercentOfWayToDestination - default 0.4; % of the way between current location and target location; suggested <=0.5
    --Returns the platoon current position if an error occurs
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetMergeLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if oPlatoonToMergeInto:GetPlan() == 'M27LargeAttackForce' then bDebugMessages = true end
    local iDistanceFactor
    if iPercentOfWayToDestination == nil then iDistanceFactor = 0.4
    else iDistanceFactor = iPercentOfWayToDestination end
    local tCurPos = GetPlatoonFrontPosition(oPlatoonToMergeInto)
    local tTargetPos = oPlatoonToMergeInto[reftMovementPath][1]

    if bDebugMessages == true then LOG('about to get merge location; platoon to merge into='..oPlatoonToMergeInto:GetPlan()..oPlatoonToMergeInto[refiPlatoonCount]..'; Position of platoon to merge into='..repr(tCurPos)..' platoontomergeinto movement path='..repr(oPlatoonToMergeInto[reftMovementPath])) end
    local tBaseMergePosition = {}
    for iAxis = 1, 3 do
        if not(iAxis == 2) then tBaseMergePosition[iAxis] = tCurPos[iAxis] + (tTargetPos[iAxis] - tCurPos[iAxis]) * iDistanceFactor end
    end
    tBaseMergePosition[2] = GetTerrainHeight(tBaseMergePosition[1], tBaseMergePosition[3])
    --Check we can path here:
    local oPathingUnit = GetPathingUnit(oPlatoonToMergeInto)
    if oPathingUnit then
        if bDebugMessages == true then LOG(sFunctionRef..': platoon unit count='..table.getn(oPlatoonToMergeInto:GetPlatoonUnits())) end
        local iCurSegmentX, iCurSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tCurPos)
        local sPathingType = M27UnitInfo.GetUnitPathingType(oPathingUnit)


        if oPathingUnit == nil or oPathingUnit.Dead or not(oPathingUnit.GetUnitId) then
            M27Utilities.ErrorHandler(oPlatoonToMergeInto:GetPlan()..oPlatoonToMergeInto[refiPlatoonCount]..':'..sFunctionRef..': Pathing unit is nil or dead or has no unit Id')
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return tCurPos
        elseif sPathingType == nil then
            M27Utilities.ErrorHandler(oPlatoonToMergeInto:GetPlan()..oPlatoonToMergeInto[refiPlatoonCount]..':'..sFunctionRef..': sPathingType is nil')
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return tCurPos
        else
            local iSegmentGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathingType, iCurSegmentX, iCurSegmentZ)
            local iMergePositionGroup, iMergeSegmentX, iMergeSegmentZ
            local tMergePosition = {}
            local iAttemptCount = 0
            local iDistanceMod = 0
            local iDistanceCount = 0
            local iXSign = 1
            local iZSign = 1
            if bDebugMessages == true then LOG('oPathingUnit='..oPathingUnit:GetUnitId()..' sPathingType='..sPathingType..'; iCurSegmentXZ='..iCurSegmentX..'-'..iCurSegmentZ) end
            if iSegmentGroup == nil then
                M27Utilities.ErrorHandler(oPlatoonToMergeInto:GetPlan()..oPlatoonToMergeInto[refiPlatoonCount]..': GetMergeLocation: iSegmentGroup is nil')
                if oPathingUnit == nil then LOG('oPathingUnilt is nil')
                else
                    if iCurSegmentX == nil then LOG('iCurSegmentX is nil')
                    else LOG('iCurSegmentX='..iCurSegmentX..'; iCurSegmentZ='..iCurSegmentZ)
                    end
                end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return tCurPos
            end
            local bNearbySegmentsSameGroup = false
            local iNearbySegmentSize = 1
            local iPlatoonUnits = oPlatoonToMergeInto[refiCurrentUnits]
            iNearbySegmentSize = math.ceil( iPlatoonUnits / 10)
            if iNearbySegmentSize >= 5 then iNearbySegmentSize = 5 end
            local iSegmentStart = -iNearbySegmentSize
            local iSegmentEnd = iNearbySegmentSize
            local iCount = 0
            while bNearbySegmentsSameGroup == false do
                iCount = iCount + 1 if iCount > 100 then M27Utilities.ErrorHandler('Infinite loop') break end
                --Modify position so are cycling between 4 corners of a square around the position that steadily increases in size
                if iAttemptCount == 0 then iDistanceMod = 0
                else
                    iDistanceCount = iDistanceCount + 1
                    if iDistanceMod == 0 then iDistanceMod = 1 end
                    if iDistanceCount > 4 then
                        iDistanceCount = 0
                        iDistanceMod = iDistanceMod * 2.
                    end
                    if iDistanceCount == 1 then iXSign = 1 iZSign = 1
                    elseif iDistanceCount == 2 then iXSign = 1 iZSign = -1
                    elseif iDistanceCount == 3 then iXSign = -1 iZSign = 1
                    elseif iDistanceCount == 4 then iXSign = -1 iZSign = -1 end
                end
                tMergePosition = {tBaseMergePosition[1] + iDistanceMod * iXSign, 0, tBaseMergePosition[3] + iDistanceMod * iZSign}
                iMergeSegmentX, iMergeSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tMergePosition)
                iMergePositionGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathingType, iMergeSegmentX, iMergeSegmentZ)
                iAttemptCount = iAttemptCount + 1
                if bDebugMessages == true then M27Utilities.DrawLocation(tMergePosition) end

                if iMergePositionGroup == iSegmentGroup then
                    --Are the nearby segments the same group?
                    bNearbySegmentsSameGroup = true
                    --Cycle from -1 to +1 segments (or -x/+x for larger platoon)
                    for iXMod = iSegmentStart, iSegmentEnd do
                        for iZMod = iSegmentStart, iSegmentEnd do
                            if not(M27MapInfo.GetSegmentGroupOfTarget(sPathingType, iMergeSegmentX + iXMod, iMergeSegmentZ + iZMod) == iSegmentGroup) then bNearbySegmentsSameGroup = false break end
                        end
                        if bNearbySegmentsSameGroup == false then break end
                    end
                end
                if iAttemptCount > 32 then
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    return nil
                end --Infinite loop protection
            end
            if tMergePosition[1] == nil or tMergePosition[3] == nil then
                M27Utilities.ErrorHandler(oPlatoonToMergeInto:GetPlan()..oPlatoonToMergeInto[refiPlatoonCount]..': GetMergeLocation: tMergePosition is nil')
                if iMergePositionGroup == nil then LOG('iMergePositionGroup is nil')
                else LOG('iMergePositionGroup='..iMergePositionGroup) end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return tCurPos
            else
                if iMergePositionGroup == iSegmentGroup then tMergePosition[2] = GetTerrainHeight(tMergePosition[1], tMergePosition[3]) end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return tMergePosition
            end
        end
    end
end

function MergeWithPlatoonsOnPath(oPlatoonToMergeInto, sTargetPlatoonPlanName, bOnlyOnOurSideOfMap)
    --Cycle through all platoons using sTargetPlatoonPlanName and if they're <= same distance from the merge location (based on the first movement path point) then will merge with it
    --bOnlyOnOurSideOfMap - will ignore platoons closer to enemy base than our base if this is true
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MergeWithPlatoonsOnPath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bOnlyOnOurSideOfMap == nil then bOnlyOnOurSideOfMap = false end
    local aiBrain = oPlatoonToMergeInto:GetBrain()
    local tFriendlyPlatoons = aiBrain:GetPlatoonsList()
    local bNearToPath, iCurDistFromMerge
    local tBasePlatoonPos = {}
    tBasePlatoonPos = GetPlatoonFrontPosition(oPlatoonToMergeInto)
    local tMergePosition = GetMergeLocation(oPlatoonToMergeInto, 0.35)
    oPlatoonToMergeInto[reftMergeLocation] = tMergePosition
    local tCurPlatoonPos = {}
    if M27Utilities.IsTableEmpty(tMergePosition) == false then
        local iCorePlatoonDistFromMerge = M27Utilities.GetDistanceBetweenPositions(tBasePlatoonPos, tMergePosition)
        local iArmyStartNumber = aiBrain.M27StartPositionNumber
        local iNearestEnemyStartNumber = M27Logic.GetNearestEnemyStartNumber(aiBrain)
        if iNearestEnemyStartNumber == nil then
            M27Utilities.ErrorHandler('iNearestEnemyStartNumber is nil')
        else
            if bDebugMessages == true then LOG('MergeWithplatoonsOnPath: getn(tFriendlyPlatoons)='..table.getn(tFriendlyPlatoons)) end
            for iCurPlan, oCurPlatoon in tFriendlyPlatoons do
                if not(oCurPlatoon == oPlatoonToMergeInto) then
                    if oCurPlatoon:GetPlan() == sTargetPlatoonPlanName then
                        if not oCurPlatoon.UsingTransport then
                            --Check if near enough
                            bNearToPath = false
                            tCurPlatoonPos = GetPlatoonFrontPosition(oCurPlatoon)
                            iCurDistFromMerge = M27Utilities.GetDistanceBetweenPositions(tMergePosition, tCurPlatoonPos)
                            if iCurDistFromMerge <= iCorePlatoonDistFromMerge then
                                if bOnlyOnOurSideOfMap == false then bNearToPath = true
                                else
                                    --Check if closer to our start base than enemy
                                    if M27Utilities.GetDistanceBetweenPositions(tCurPlatoonPos, M27MapInfo.PlayerStartPoints[iArmyStartNumber]) <= M27Utilities.GetDistanceBetweenPositions(tCurPlatoonPos, M27MapInfo.PlayerStartPoints[iNearestEnemyStartNumber]) then bNearToPath = true end
                                end
                            end
                            if bDebugMessages == true then LOG('MergeWithplatoonsOnPath: iCurPlatoonPos='..tCurPlatoonPos[1]..'-'..tCurPlatoonPos[3]..'; tBasePlatoonPos='..tBasePlatoonPos[1]..'-'..tBasePlatoonPos[3]..'; iCurDistFromMerge='..iCurDistFromMerge) end
                            if bNearToPath == true then
                                if bDebugMessages == true then LOG('MergeWithPlatoonsOnPath: oCurPlatoon '..oCurPlatoon:GetPlan()..' is near to a destination, about to merge with '..oPlatoonToMergeInto:GetPlan()) end
                                MergePlatoons(oPlatoonToMergeInto, oCurPlatoon) end
                        end
                    end
                end
            end
        end
    else
        M27Utilities.ErrorHandler('Merge location is nil - only scenarios where expect this are if map has lots of water or impassable areas')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ForceActionRefresh(oPlatoon, iMinGapBetweenForces)
    --Flags to force a refresh when choosing platoon action, if last refresh >=5 seconds ago
    if iMinGapBetweenForces == nil then iMinGapBetweenForces = 5 end
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ForceActionRefresh'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iTimeOfLastRefresh = oPlatoon[refiGameTimeOfLastRefresh]
    if iTimeOfLastRefresh == nil then iTimeOfLastRefresh = 2 end
    local iCurGameTime = GetGameTimeSeconds()
    if iTimeOfLastRefresh == true or iTimeOfLastRefresh== false then
        iTimeOfLastRefresh = 2
        if bDebugMessages == true then LOG(sFunctionRef..': Warning: Platoons iTimeOfLastRefresh was a boolean - logs enabled in case its in unexpected scenario.  This somehow happens when a new platoon is created using a unit that formed part of a prev platoon') end
    end

    if bDebugMessages == true then
        if oPlatoon[refiPlatoonCount] == nil then oPlatoon[refiPlatoonCount] = 0 end
        local sPlatoonRef
        if not(oPlatoon.GetPlan) then
            sPlatoonRef='NoPlan'
        else
            sPlatoonRef = oPlatoon:GetPlan()
        end
        sPlatoonRef = sPlatoonRef..oPlatoon[refiPlatoonCount]
        LOG(sFunctionRef..': iCurGameTime='..iCurGameTime..'; iLastForcedRefresh='..tostring(iTimeOfLastRefresh)..'; sPlatoonRef='..sPlatoonRef)
    end

    if iCurGameTime - iTimeOfLastRefresh >= iMinGapBetweenForces then
        oPlatoon[refbForceActionRefresh] = true
        oPlatoon[refiGameTimeOfLastRefresh] = iCurGameTime
        if bDebugMessages == true then LOG(sFunctionRef..': Updated time of last refresh, oPlatoon[refiGameTimeOfLastRefresh]='..oPlatoon[refiGameTimeOfLastRefresh]) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

--[[function GetFollowerTargetPosition(oPlatoon)
    --oPlatoon should be the platoon that is following another platoon
    local tTargetPosition
    local oUnitToFollow,
    oPlatoonToFollow = oPlatoon[refoSupportHelperPlatoonTarget]
    if oPlatoonToFollow then
        tTargetPosition = GetPlatoonFrontPosition(oPlatoonToFollow)
    else
        oUnitToFollow = oPlatoon[refoSupportHelperUnitTarget]
        if oUnitToFollow and not(oUnitToFollow.Dead) then
            tTargetPosition = oUnitToFollow:GetPosition()
        else M27Utilities.ErrorHandler('Dont have a valid target')
        end
    end
    return tTargetPosition
end--]]

function HasPlatoonReachedDestination(oPlatoon)
    --Returns true if have reached current movement point destination, false otherwise
    --also updates
    --Have we reached the current move destination?
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'HasPlatoonReachedDestination'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local sPlatoonName = oPlatoon:GetPlan()
    --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end
    --if oPlatoon[refbOverseerAction] == true then bDebugMessages = true end
    local iCurrentUnits = oPlatoon[refiCurrentUnits]
    if iCurrentUnits == nil then
        oPlatoon[refiCurrentUnits] = table.getn(oPlatoon:GetPlatoonUnits())
        iCurrentUnits = oPlatoon[refiCurrentUnits] end
    local iReachedTargetDist
    if oPlatoon[refiOverrideDistanceToReachDestination] == nil then
        local iBase = 7
        if oPlatoon[refiBuilders] > 0 then iBase = 3 end --redundancy - have put this in the platoon initial setup as well
        iReachedTargetDist = iBase + iCurrentUnits * 0.25
        if iReachedTargetDist > 25 then iReachedTargetDist = 25 end
    else
        iReachedTargetDist = oPlatoon[refiOverrideDistanceToReachDestination]
    end

    if oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]] == nil then
        --Rare error - debug messages and backup put in place for when this occurs, along with code to disband platoon if cant switch to valid movement path:
        M27Utilities.ErrorHandler(sPlatoonName..oPlatoon[refiPlatoonCount]..sFunctionRef..': oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]] is nil; iCurrentUnits='..iCurrentUnits)
        if oPlatoon[refiCurrentPathTarget] == nil then LOG('refiCurrentPathTarget is nil') else LOG('refiCurrentPathTarget='..oPlatoon[refiCurrentPathTarget]) end
        if oPlatoon[reftMovementPath] == nil then
            LOG('reftMovementPath is nil, will disband platoon')
            oPlatoon[refiCurrentAction] = refActionDisband
        else
            local iMoveTableSize = table.getn(oPlatoon[reftMovementPath])
            LOG('reftMovementPath table size='..iMoveTableSize)
            --Try to fix:
            if iMoveTableSize > 0 then
                LOG('tMovementPath repr='..repr(oPlatoon[reftMovementPath]))
                if oPlatoon[refiCurrentPathTarget] > iMoveTableSize then oPlatoon[refiCurrentPathTarget] = iMoveTableSize end
                if M27Utilities.IsTableEmpty(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]]) == true then
                    if iMoveTableSize == 0 then
                        LOG('MoveTableSize is 0 so disbanding')
                        oPlatoon[refiCurrentAction] = refActionDisband
                    else
                        oPlatoon[refiCurrentPathTarget] = oPlatoon[refiCurrentPathTarget] - 1
                    end
                end
            else LOG('reftMovementPath size isnt >0, disbanding platoon')
                oPlatoon[refiCurrentAction] = refActionDisband
            end
        end
        --Output prior actions:
        local sPrevAction = ''
        for iCount, iPrevActionRef in oPlatoon[reftPrevAction] do
            sPrevAction = sPrevAction .. iPrevActionRef .. '-'
        end
        LOG('sPrevAction='..sPrevAction)

    end

    local iCurDistToTarget = M27Utilities.GetDistanceBetweenPositions(GetPlatoonFrontPosition(oPlatoon), oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]])
    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..sFunctionRef..': iCurDistToTarget='..iCurDistToTarget..'; iReachedTargetDist='..iReachedTargetDist) end
    if iCurDistToTarget <= iReachedTargetDist then
        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..sFunctionRef..': Are close enough to the target, iCurDistToTarget='..iCurDistToTarget..'; iReachedTargetDist='..iReachedTargetDist) end
        oPlatoon[refiCurrentPathTarget] = oPlatoon[refiCurrentPathTarget] + 1
        --[[if oPlatoon[refiCurrentPathTarget] > table.getn(oPlatoon[reftMovementPath]) then
            oPlatoon[refiCurrentPathTarget] = table.getn(oPlatoon[reftMovementPath])
            oPlatoon[refiCurrentAction] = refActionNewMovementPath
        end--]]
        if oPlatoon[refbACUInPlatoon] == true and oPlatoon[refiCurrentPathTarget] <= table.getn(oPlatoon[reftMovementPath]) then
            local aiBrain = oPlatoon:GetBrain()
            M27EngineerOverseer.UpdateActionsForACUMovementPath(oPlatoon[reftMovementPath], aiBrain, M27Utilities.GetACU(aiBrain), oPlatoon[refiCurrentPathTarget])
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return true
    else
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return false end
end

function DeterminePlatoonCompletionAction(oPlatoon)
    --Updates oPlatoon's action if have completed movement path
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DeterminePlatoonCompletionAction'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local aiBrain = oPlatoon:GetBrain()
    local sPlatoonName = oPlatoon:GetPlan()
    --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end
    --if oPlatoon[refbOverseerAction] == true then bDebugMessages = true end
    --if sPlatoonName == 'M27CombatPatrolAI' then bDebugMessages = true end
    --if sPlatoonName == 'M27IndirectDefender' then bDebugMessages = true end
    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Determining platoon completion action') end
    if oPlatoon[M27PlatoonTemplates.refbDisbandIfReachDestination] == true then
        if bDebugMessages == true then LOG(sFunctionRef..': Platoon set to disband if reaches destination so will disband') end
        oPlatoon[refiCurrentAction] = refActionDisband
    else
        --Have we previously run away?
        if oPlatoon[refbHavePreviouslyRun] == true then

            --Default: New movement path.  Large attack platoons disband
            if oPlatoon[M27PlatoonTemplates.refbDisbandAfterRunningAway] == true then
                if bDebugMessages == true then LOG(sFunctionRef..': Disbanding large attack platoon as has reached destination and previously run') end
                oPlatoon[refiCurrentAction] = refActionDisband
            else oPlatoon[refiCurrentAction] = refActionNewMovementPath end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Havent previously run,, will use attack AI if flagged to attack once reach destination; '..tostring(oPlatoon[M27PlatoonTemplates.refbSwitchToAttackIfReachDestination])) end
            --Default: New movement path.  Large attack platoons switch to attack AI (since we havent run away previously meaning we've presumably successfully reached our original target)
            if oPlatoon[M27PlatoonTemplates.refbSwitchToAttackIfReachDestination] == true then
                oPlatoon[refiCurrentAction] = refActionUseAttackAI
            else oPlatoon[refiCurrentAction] = refActionNewMovementPath end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end



function GetNearbyEnemyData(oPlatoon, iEnemySearchRadius, bPlatoonIsAUnit)
    --Updates the platoon to record details of nearby enemies
    --iEnemySearchRadius - used for mobile units (not structures)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef='GetNearbyEnemyData'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tCurPos = GetPlatoonFrontPosition(oPlatoon)
    local aiBrain, sPlatoonName
    local bAbort = false
    if bPlatoonIsAUnit then
        if oPlatoon.Dead or not(oPlatoon.GetUnitId) then
            bAbort = true
        else
            aiBrain = oPlatoon:GetAIBrain()
            sPlatoonName = oPlatoon:GetUnitId()
        end
    else
        aiBrain = oPlatoon:GetBrain()
        sPlatoonName = oPlatoon:GetPlan()
    end
    --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end
    --if sPlatoonName == 'M27IndirectDefender' then bDebugMessages = true end
    --if sPlatoonName == 'M27MexLargerRaiderAI' then bDebugMessages = true end
    --if sPlatoonName == 'M27EscortAI' then bDebugMessages = true end
    --if sPlatoonName == 'M27CombatPatrolAI' then bDebugMessages = true end
    if bAbort == false then
        oPlatoon[M27Overseer.refiSearchRangeForEnemyStructures] = math.max(aiBrain[M27Overseer.refiSearchRangeForEnemyStructures], iEnemySearchRadius)
        oPlatoon[refiEnemySearchRadius] = iEnemySearchRadius
        --if oPlatoon[reftEnemiesInRange] == nil then oPlatoon[reftEnemiesInRange] = {} end
        local iMobileEnemyCategories = categories.LAND * categories.MOBILE
        if oPlatoon[refbPlatoonHasOverwaterLand] == true then iMobileEnemyCategories = categories.LAND * categories.MOBILE + categories.NAVAL * categories.MOBILE end
        oPlatoon[reftEnemiesInRange] = aiBrain:GetUnitsAroundPoint(iMobileEnemyCategories, tCurPos, iEnemySearchRadius, 'Enemy')
        if M27Utilities.IsTableEmpty(oPlatoon[reftEnemiesInRange]) == true then
            oPlatoon[refiEnemiesInRange] = 0
        else oPlatoon[refiEnemiesInRange] = table.getn(oPlatoon[reftEnemiesInRange]) end
        oPlatoon[reftEnemyStructuresInRange] = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE - categories.STRUCTURE * categories.BENIGN, tCurPos, oPlatoon[M27Overseer.refiSearchRangeForEnemyStructures], 'Enemy')
        if oPlatoon[reftEnemyStructuresInRange] == nil then
            oPlatoon[refiEnemyStructuresInRange] = 0
        else oPlatoon[refiEnemyStructuresInRange] = table.getn(oPlatoon[reftEnemyStructuresInRange]) end
        if oPlatoon[refiEnemiesInRange] + oPlatoon[refiEnemyStructuresInRange] > 0 then
            --get all friendly units around a point for threat detection - use slightly larger area
            oPlatoon[reftFriendlyNearbyCombatUnits] = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, tCurPos, iEnemySearchRadius + 5, 'Ally')
            --Exclude combat units that are in a retreating platoon
            if M27Utilities.IsTableEmpty(oPlatoon[reftFriendlyNearbyCombatUnits]) == false then
                for iUnit, oUnit in oPlatoon[reftFriendlyNearbyCombatUnits] do
                    if oUnit.PlatoonHandle and oUnit.PlatoonHandle[M27PlatoonTemplates.refbRunFromAllEnemies] == true then
                        oPlatoon[reftFriendlyNearbyCombatUnits][iUnit] = nil
                    end
                end
            end

            --Record enemy indirect units that can see
            oPlatoon[reftVisibleEnemyIndirect] = M27Logic.GetVisibleUnitsOnly(aiBrain, EntityCategoryFilterDown(categories.INDIRECTFIRE, oPlatoon[reftEnemiesInRange]))
            if oPlatoon[reftVisibleEnemyIndirect] == nil then oPlatoon[refiVisibleEnemyIndirect] = 0
            else oPlatoon[refiVisibleEnemyIndirect] = table.getn(oPlatoon[reftVisibleEnemyIndirect]) end
        end
        --Record nearest enemy to ACU (used by other platoons to decide if they should help out if theyre nearby)
        if oPlatoon[refbACUInPlatoon] == true and (oPlatoon[refiEnemiesInRange] + oPlatoon[refiEnemyStructuresInRange]) > 0 then
            local oMobileEnemyNearestACU, oStructureNearestACU
            local iNearestUnitDistance = 10000
            local oACUUnit = M27Utilities.GetACU(aiBrain)
            local tACUPosition = oACUUnit:GetPosition()
            if oPlatoon[refiEnemiesInRange] > 0 then
                oMobileEnemyNearestACU = M27Utilities.GetNearestUnit(oPlatoon[reftEnemiesInRange], tACUPosition, aiBrain, true)
                if oMobileEnemyNearestACU then iNearestUnitDistance = M27Utilities.GetDistanceBetweenPositions(oMobileEnemyNearestACU:GetPosition(), tACUPosition) end
            end
            if oPlatoon[refiEnemyStructuresInRange] > 0 then
                oStructureNearestACU = M27Utilities.GetNearestUnit(oPlatoon[reftEnemyStructuresInRange], tACUPosition, aiBrain, true)
                if oStructureNearestACU then iNearestUnitDistance = math.min(iNearestUnitDistance, M27Utilities.GetDistanceBetweenPositions(oStructureNearestACU:GetPosition(), tACUPosition)) end
            end
            oPlatoon[refiACUNearestEnemy] = iNearestUnitDistance
        else oPlatoon[refiACUNearestEnemy] = nil
        end
        if bDebugMessages == true then
            LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': iEnemySearchRadius='..iEnemySearchRadius..'; iEnemiesInRange='..oPlatoon[refiEnemiesInRange]..'; refiEnemyStructuresInRange='..oPlatoon[refiEnemyStructuresInRange]..'; refiSearchRangeForEnemyStructure='..oPlatoon[M27Overseer.refiSearchRangeForEnemyStructures])
            LOG('About to draw average platoon location')
            M27Utilities.DrawLocation(tCurPos, nil, 2, 50)
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdatePlatoonActionIfStuck(oPlatoon)
    --Considers if oPlatoon is likely to be stuck, and if so then updates oPlatoon's action
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdatePlatoonActionIfStuck'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    --if oPlatoon[refbOverseerAction] == true then bDebugMessages = true LOG('UpdatePlatoonActionIfStuck: Start') end
    local sPlatoonName = oPlatoon:GetPlan()
    --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end
    --if sPlatoonName == 'M27ScoutAssister' then bDebugMessages = true end
    --if sPlatoonName == 'M27MAAAssister' then bDebugMessages = true end
    --if sPlatoonName == 'M27IndirectDefender' then bDebugMessages = true end
    --if sPlatoonName == 'M27LargeAttackForce' then bDebugMessages = true end
    --if sPlatoonName == 'M27CombatPatrolAI' then bDebugMessages = true end

    local aiBrain = oPlatoon:GetBrain()
    local iNearTargetForSupport = 20 --if are within this range of destination then will ignore isstuck action)

    --Assister and Intel platoons - ignore if they're near their destination
    local bIgnoreAssister = false
    local iAssisterDistanceFromDestination

    if oPlatoon[M27PlatoonTemplates.refbIgnoreStuckAction] == true then
        local tPlatoonPosition = GetPlatoonFrontPosition(oPlatoon)
        iAssisterDistanceFromDestination = M27Utilities.GetDistanceBetweenPositions(tPlatoonPosition, oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]])
        if iAssisterDistanceFromDestination <= iNearTargetForSupport then bIgnoreAssister = true end
    end
    if bIgnoreAssister == false then
        --Check we're not busy reclaiming, building, upgrading:
        local bBusyBuildingOrReclaiming = false
        if bDebugMessages == true then
            LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': About to check if platoon is stuck; oPlatoon[refbConsiderMexes]='..tostring(oPlatoon[refbConsiderMexes])..'; platoon current action before running this:')
            if oPlatoon[refiCurrentAction] == nil then LOG('action is nil')
            else LOG('action is '..oPlatoon[refiCurrentAction]) end
        end
        if oPlatoon[refbConsiderMexes] == true then
            if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': Platoon considers building on mexes, will check unit state') end
            for iBuilder, oBuilder in oPlatoon[reftBuilders] do
                if oBuilder:IsUnitState('Building') == true then bBusyBuildingOrReclaiming = true break end
                if oBuilder:IsUnitState('Capturing') == true then bBusyBuildingOrReclaiming = true break end
                if oBuilder:IsUnitState('Upgrading') == true then bBusyBuildingOrReclaiming = true break end
                if oBuilder:IsUnitState('Repairing') == true then bBusyBuildingOrReclaiming = true break end
                if oBuilder:IsUnitState('Guarding') == true then
                    --Get the unit being guarded, and see if its constructing something:
                    local oGuardedUnit = oBuilder:GetFocusUnit()
                    if oGuardedUnit and not(oGuardedUnit.Dead) then
                        if oGuardedUnit.GetFocusUnit then
                            local oPossibleBuilding = oGuardedUnit:GetFocusUnit()
                            if oPossibleBuilding and not(oPossibleBuilding.Dead) and oPossibleBuilding.GetFractionComplete then
                                if oPossibleBuilding:GetFractionComplete() < 1 then
                                    bBusyBuildingOrReclaiming = true break
                                end
                            end
                        end
                    end
                end
            end


            if bBusyBuildingOrReclaiming == false then
                if oPlatoon[refbConsiderReclaim] == true then
                    for iReclaimer, oReclaimer in oPlatoon[reftReclaimers] do
                        if oReclaimer:IsUnitState('Reclaiming') == true then bBusyBuildingOrReclaiming = true break end
                    end
                end
            end
        end
        if bBusyBuildingOrReclaiming == false then
            --Check we dont have a temporary movement path order that is the current intel path, or a temporary movement path that are close to
            local bHaveTemporaryIntelPathLocation = false
            local bAreNearTemporaryMoveLocation = false
            if oPlatoon[reftPrevAction][1] == refActionMoveToTemporaryLocation then
                local tIntelPathLocation = aiBrain[M27Overseer.reftIntelLinePositions][aiBrain[M27Overseer.refiCurIntelLineTarget]][1]
                if oPlatoon[reftTemporaryMoveTarget][1] == tIntelPathLocation[1] and oPlatoon[reftTemporaryMoveTarget][3] == tIntelPathLocation[3] then
                    --Are we close to this location?
                    if M27Utilities.GetDistanceBetweenPositions(GetPlatoonFrontPosition(oPlatoon), oPlatoon[reftTemporaryMoveTarget]) <= 30 then
                        bHaveTemporaryIntelPathLocation = true
                    end
                end
                if bHaveTemporaryIntelPathLocation == false and M27Utilities.IsTableEmpty(oPlatoon[reftTemporaryMoveTarget]) == false then
                    if M27Utilities.GetDistanceBetweenPositions(GetPlatoonFrontPosition(oPlatoon), oPlatoon[reftTemporaryMoveTarget]) <= math.max(6, oPlatoon[refiCurrentUnits]) then bAreNearTemporaryMoveLocation = true end
                end
            end
            if bHaveTemporaryIntelPathLocation == false and bAreNearTemporaryMoveLocation == false then
                --If indirect fire platoon whose action is to attack then dont treat as being stuck
                local bIndirectAttacking = false
                if oPlatoon[refiIndirectUnits] > 0 then
                    if oPlatoon[reftPrevAction] then
                        if oPlatoon[reftPrevAction][1] == refActionAttack or oPlatoon[reftPrevAction][1] == refActionAttackSpecificUnit then
                            if bDebugMessages == true then LOG(sFunctionRef..': Indirect fire platoon is attacking something so will ignore is stuck action') end
                            bIndirectAttacking = true
                        end
                    end
                end
                if bIndirectAttacking == false then
                    --Escort specific exclusion
                    local bEscortingPlatoonAndNearIt = false
                    if oPlatoon[refoPlatoonOrUnitToEscort] and oPlatoon[refoPlatoonOrUnitToEscort].GetPlatoonPosition and M27Utilities.GetDistanceBetweenPositions(GetPlatoonFrontPosition(oPlatoon), GetPlatoonFrontPosition(oPlatoon[refoPlatoonOrUnitToEscort])) <= 20 then bEscortingPlatoonAndNearIt = true end
                    if bEscortingPlatoonAndNearIt == false then
                        local iTriggerDistance = 5
                        if oPlatoon[refbACUInPlatoon] then iTriggerDistance = 2.5 end
                        local iCyclesSinceLastMoved = GetCyclesSinceLastMoved(oPlatoon, true, 5)
                        local iCycleThreshold = 13
                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionIfStuck: iCyclesSinceLastMoved='..iCyclesSinceLastMoved) end
                        if iCyclesSinceLastMoved >= iCycleThreshold then
                            if oPlatoon[refiCyclesForLastStuckAction] == nil then oPlatoon[refiCyclesForLastStuckAction] = 0 end
                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionIfStuck: iCyclesSinceLastMoved='..iCyclesSinceLastMoved..'; refiCyclesForLastStuckAction='..oPlatoon[refiCyclesForLastStuckAction]) end
                            if iCyclesSinceLastMoved - oPlatoon[refiCyclesForLastStuckAction] >= iCycleThreshold then
                                --Are we still stuck despite trying to get unstuck before?
                                if oPlatoon[refiCyclesForLastStuckAction] >= iCycleThreshold * 6 then
                                    --Are still stuck despite attempting to return to base; switch to attack AI
                                    oPlatoon[refiCurrentAction] = refActionUseAttackAI
                                else
                                    --Still stuck despite trying preferred 'unstick' strategy; now try to return to base (unless are a defender)
                                    if oPlatoon[refiCyclesForLastStuckAction] >= iCycleThreshold * 3 then
                                        if sPlatoonName == M27Overseer.sDefenderPlatoonRef or sPlatoonName == 'M27IndirectDefender' then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Platoon is a defender and is very stuck so disbanding') end
                                            oPlatoon[refiCurrentAction] = refActionDisband
                                        else
                                            oPlatoon[refiCurrentAction] = refActionReturnToBase
                                        end
                                    else
                                        --First time the platoon is stuck; get preferred unsticking approach

                                        --Is the platoon in combat? If so it might be killing units hence why its not moving.  It might also be attacking cliffs
                                        local bAttackingForAWhile = false
                                        if not(oPlatoon[reftPrevAction] == nil) then
                                            local iPrevActionCount = table.getn(oPlatoon[reftPrevAction])
                                            if iPrevActionCount >= iCycleThreshold then
                                                --Consider if all of the last iCycleThreshold actions have been attacking:
                                                bAttackingForAWhile = true
                                                for iPrevAction = 1, iPrevActionCount do
                                                    if not(oPlatoon[reftPrevAction][iPrevAction] == refActionAttack) then
                                                        if not(oPlatoon[reftPrevAction][iPrevAction] == nil) then
                                                            bAttackingForAWhile = false
                                                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionIfStuck: bAttackingForAWhile just changed to false due to iPrevAction='..iPrevAction..'; iActionRef='..oPlatoon[reftPrevAction][iPrevAction]) end
                                                            break
                                                        end
                                                    end
                                                    if iPrevAction >= iCycleThreshold then break end
                                                end
                                            end
                                        end

                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionIfStuck: bAttackingForAWhile='..tostring(bAttackingForAWhile)..'; CyclesForLastStuckAction='..oPlatoon[refiCyclesForLastStuckAction]..'; iCyclesSinceLastMoved='..iCyclesSinceLastMoved) end
                                        if bAttackingForAWhile == true then
                                            if oPlatoon[refiDFUnits] > 0 then
                                                oPlatoon[refiCurrentAction] = refActionMoveDFToNearestEnemy
                                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionIfStuck: Been attacking for a while so will move DF to nearest enemy') end
                                            else
                                                --Move to a random location nearby (if cant find one then get a new movement path)
                                                local tModPosition = {}
                                                local iLoopCount = 0
                                                local iMaxLoop = 10
                                                local oPathingUnit = GetPathingUnit(oPlatoon)
                                                if oPathingUnit then

                                                    while M27Utilities.IsTableEmpty(tModPosition) == true do
                                                        iLoopCount = iLoopCount + 1
                                                        if iLoopCount > iMaxLoop then break end
                                                        local iRandXFactor = math.random(0, 1)
                                                        local iRandZFactor = math.random(0,1)
                                                        local iRandXDistance = math.random(15,25)
                                                        local iRandZDistance = math.random(15,25)
                                                        if iRandXFactor == 1 then iRandXDistance = -iRandXDistance end
                                                        if iRandZFactor == 1 then iRandZDistance = -iRandZDistance end
                                                        tModPosition = GetPlatoonFrontPosition(oPlatoon)
                                                        tModPosition[1] = tModPosition[1] + iRandXFactor
                                                        tModPosition[3] = tModPosition[3] + iRandZFactor
                                                        local rPlayableArea = M27MapInfo.rMapPlayableArea
                                                        local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
                                                        local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]
                                                        if tModPosition[1] < rPlayableArea[1] + 1 then tModPosition[1] = rPlayableArea[1] + 1
                                                        elseif tModPosition[1] > (iMapSizeX-1) then tModPosition[1] = iMapSizeX - 1 end
                                                        if tModPosition[3] < rPlayableArea[2] + 1 then tModPosition[3] = rPlayableArea[2] + 1
                                                        elseif tModPosition[3] > (iMapSizeZ - 1) then tModPosition[3] = iMapSizeZ - 1 end
                                                        --GetPositionNearTargetInSamePathingGroup(tStartPos, tTargetPos, iDistanceFromTarget, iAngleBase, oPathingUnit, iNearbyMethodIfBlocked, bTrySidePositions, bCheckAgainstExistingCommandTarget, iMinDistanceFromCurrentBuilderMoveTarget)
                                                        tModPosition = GetPositionNearTargetInSamePathingGroup(GetPlatoonFrontPosition(oPlatoon), tModPosition, 1, 0, oPathingUnit, 3, true, false, 0)


                                                    end
                                                    if M27Utilities.IsTableEmpty(tModPosition) == false then
                                                        oPlatoon[reftTemporaryMoveTarget] = tModPosition
                                                        oPlatoon[refiCurrentAction] = refActionMoveToTemporaryLocation
                                                    else
                                                        oPlatoon[refiCurrentAction] = refActionNewMovementPath
                                                    end
                                                else
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Dont have a pathing unit so likely that all units are dead') end
                                                    oPlatoon[refiCurrentAction] = refActionDisband
                                                end
                                            end
                                        else
                                            --Have we just started attacking? If so then give slightly more time to do this
                                            if oPlatoon[reftPrevAction][1] == refActionAttack then
                                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionIfStuck: Recently started attacking so will give more time before stuck action') end
                                                --Do nothing
                                            else
                                                --Are we moving along the path? If so skip the current path if we can
                                                if oPlatoon[reftPrevAction][1] == refActionContinueMovementPath then
                                                    if oPlatoon[refiCurrentPathTarget] < table.getn(oPlatoon[reftMovementPath]) then
                                                        oPlatoon[refiCurrentPathTarget] = oPlatoon[refiCurrentPathTarget] + 1
                                                        oPlatoon[refiCurrentAction] = refActionReissueMovementPath
                                                    else
                                                        --We're moving but we're already trying to reach the end destination - get new move orders
                                                        --Exception - ACU defender - want to disband instead
                                                        local bDisbandNotNewPath = false
                                                        if oPlatoon[refbACUInPlatoon] and sPlatoonName == M27Overseer.sDefenderPlatoonRef then
                                                            if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonName='..sPlatoonName..': Disbanding') end
                                                            oPlatoon[refiCurrentAction] = refActionDisband
                                                            bDisbandNotNewPath = true
                                                        else
                                                            --Exception - large attack AI That has run back to base and stuck near to base - want it to disband instead
                                                            if oPlatoon[M27PlatoonTemplates.refbDisbandAfterRunningAway] == true then
                                                                if oPlatoon[refbHavePreviouslyRun] == true then
                                                                    --Are we relatively close to our start?
                                                                    local tPlatoonPosition = GetPlatoonFrontPosition(oPlatoon)
                                                                    if M27Utilities.GetDistanceBetweenPositions(tPlatoonPosition, M27MapInfo.PlayerStartPoints[M27Utilities.GetAIBrainArmyNumber(aiBrain)]) <= 50 then
                                                                        bDisbandNotNewPath = true
                                                                        if bDebugMessages == true then LOG(sFunctionRef..': platoon is stuck-disbanding') end
                                                                        oPlatoon[refiCurrentAction] = refActionDisband
                                                                    end
                                                                end
                                                            end
                                                        end
                                                        if bDisbandNotNewPath == false then oPlatoon[refiCurrentAction] = refActionNewMovementPath end
                                                    end
                                                else

                                                    --We're not moving along a path, and aren't attacking an enemy
                                                    --Are there nearby enemies? If so then attack them
                                                    if oPlatoon[refiEnemiesInRange] + oPlatoon[refiEnemyStructuresInRange] > 0 then
                                                        oPlatoon[refiCurrentAction] = refActionAttack
                                                    else
                                                        oPlatoon[refiCurrentAction] = refActionContinueMovementPath
                                                    end
                                                end --Prev action refActionContinueMovementPath
                                            end --Prev action refActionAttack
                                        end --bAttackingForAWhile
                                    end
                                end
                                oPlatoon[refiCyclesForLastStuckAction] = iCyclesSinceLastMoved
                                --Force a refresh in the platoon action (redundancy for unforseen impact of the 'ignore refresh' logic)
                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Stuck action forced refresh enabled') end
                                ForceActionRefresh(oPlatoon)
                            end
                        end
                    end
                end
            end
        else
            oPlatoon[refiCyclesForLastStuckAction] = 0
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': Platoon action following checking if stuck is:')
        if oPlatoon[refiCurrentAction] == nil then LOG('action is nil')
        else LOG('action is '..oPlatoon[refiCurrentAction]) end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetUnderwaterActionForLandUnit(oPlatoon)
    --Checks if platoon is underwater, and if so decides on action
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetUnderwaterActionForLandUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end
    local tPlatoonPosition = GetPlatoonFrontPosition(oPlatoon)
    local iHeightAtWhichConsideredUnderwater = M27MapInfo.IsUnderwater(tPlatoonPosition, true)
    local iMaxDistanceForLandSearch = 20
    if bDebugMessages == true then LOG(sFunctionRef..': Checking if underwater; iHeightAtWhichConsideredUnderwater='..iHeightAtWhichConsideredUnderwater..'; Cur Position height='..tPlatoonPosition[2]..'; Surface height='..GetSurfaceHeight(tPlatoonPosition[1], tPlatoonPosition[3])..'; terrain height='..GetTerrainHeight(tPlatoonPosition[1], tPlatoonPosition[3])) end
    if tPlatoonPosition[2] < iHeightAtWhichConsideredUnderwater then
        if bDebugMessages == true then LOG(sFunctionRef..': Are underwater, Checking if DF units in platoon') end
        if oPlatoon[refiDFUnits] > 0 then
            --Get blueprint for the first unit in the platoon that is underwater
            local oUnderwaterUnit
            if bDebugMessages == true then LOG(sFunctionRef..': Getting first amphibious unit in platoon') end
            for iUnit, oUnit in oPlatoon[reftDFUnits] do
                if M27UnitInfo.IsUnitUnderwaterAmphibious(oUnit) == true then
                    oUnderwaterUnit = oUnit
                    break
                end
            end
            if oUnderwaterUnit and not(oUnderwaterUnit.Dead) then
                --run away if we have nearby enemy units that have torpedos and we dont have antinavy in our platoon
                local aiBrain = oPlatoon:GetBrain()
                local iSearchRange = 80
                local tNearbyAntiNavy = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryTorpedoLandAndNavy, oUnderwaterUnit:GetPosition(), iSearchRange, 'Enemy')
                local bAbort = false
                if M27Utilities.IsTableEmpty(tNearbyAntiNavy) == false then
                    --Do we have any antinavy units in our platoon?
                    local tOurAntiNavy = EntityCategoryFilterDown(M27UnitInfo.refCategoryTorpedoLandAndNavy, GetPlatoonUnitsOrUnitCount(oPlatoon, reftCurrentUnits, false))
                    if M27Utilities.IsTableEmpty(tOurAntiNavy) == true then
                        oPlatoon[refiCurrentAction] = refActionRun
                        bAbort = true
                    end
                end
                if bAbort == false then




                    if bDebugMessages == true then LOG(sFunctionRef..': Have amphibious unit, checking firing position') end
                    local tFiringPositionStart = M27Logic.GetDirectFireWeaponPosition(oUnderwaterUnit)
                    if tFiringPositionStart then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have firing position, checking if its below water') end
                        local iFiringHeight = tFiringPositionStart[2]
                        if iFiringHeight <= (iHeightAtWhichConsideredUnderwater + 0.2) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Gun is below water, checking if have reclaimers; refiReclaimers='..oPlatoon[refiReclaimers]) end
                            local bMoveToNearbyLand, tNearbyLandPosition
                            --Do we contain reclaimers?
                            if oPlatoon[refiReclaimers] > 0 then
                                local aiBrain = oPlatoon:GetBrain()
                                local oReclaimer = oPlatoon[reftReclaimers][1]
                                if oReclaimer == nil or oReclaimer.Dead then
                                    M27Utilities.ErrorHandler('Reclaimer is nil or dead')
                                else
                                    local iBuildDistance = oReclaimer:GetBlueprint().Economy.MaxBuildDistance
                                    local tNearbyEnemiesThatCanReclaim = aiBrain:GetUnitsAroundPoint(categories.RECLAIMABLE, tPlatoonPosition, iBuildDistance + 10, 'Enemy')
                                    local oReclaimTarget
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have alive reclaimer in platoon, checking if enemy units nearby that can reclaim') end
                                    if M27Utilities.IsTableEmpty(tNearbyEnemiesThatCanReclaim) == false then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Are nearby enemies that can reclaim') end
                                        oReclaimTarget = M27Utilities.GetNearestUnit(tNearbyEnemiesThatCanReclaim, tPlatoonPosition, aiBrain, true)
                                        if oReclaimTarget then
                                            local iDistanceToPlatoon = M27Utilities.GetDistanceBetweenPositions(oReclaimTarget:GetPosition(), tPlatoonPosition)
                                            if bDebugMessages == true then LOG(sFunctionRef..': Have a reclaim target, iDistanceToPlatoon='..iDistanceToPlatoon..'; iBuildDistance='..iBuildDistance) end
                                            if iDistanceToPlatoon <= iBuildDistance then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Trying to target nearby enemy for reclaim') end
                                                oPlatoon[refoNearbyReclaimTarget] = oReclaimTarget
                                                oPlatoon[refiCurrentAction] = refActionReclaimTarget
                                            else
                                                --first see if nearby land that can move to
                                                --GetNearestPathableLandPosition(oPathingUnit, tTravelTarget, iMaxSearchRange)
                                                tNearbyLandPosition = M27MapInfo.GetNearestPathableLandPosition(oUnderwaterUnit, oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]], iMaxDistanceForLandSearch)
                                                if M27Utilities.IsTableEmpty(tNearbyLandPosition) == false then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Have nearby land that can move to') end
                                                    bMoveToNearbyLand = true
                                                else
                                                    --Reclaim the unit that is further away than our build distance
                                                    if bDebugMessages == true then LOG(sFunctionRef..': No nearby land so will move to enemy and try and reclaim') end
                                                    oPlatoon[refoNearbyReclaimTarget] = oReclaimTarget
                                                    oPlatoon[refiCurrentAction] = refActionReclaimTarget
                                                end
                                            end
                                        else
                                            if bDebugMessages == true then LOG(sFunctionRef..': Are no nearby enemies that can reclaim') end
                                        end
                                    end
                                end
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': No nearby enemies so will see if have nearby land') end
                                tNearbyLandPosition = M27MapInfo.GetNearestPathableLandPosition(oUnderwaterUnit, oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]], iMaxDistanceForLandSearch)
                                if M27Utilities.IsTableEmpty(tNearbyLandPosition) == false then
                                    if bDebugMessages == true then LOG(sFunctionRef..': No nearby enemies but nearby land so will move there') end
                                    bMoveToNearbyLand = true
                                end
                            end
                            if bMoveToNearbyLand == true then
                                oPlatoon[refiCurrentAction] = refActionMoveToTemporaryLocation
                                oPlatoon[reftTemporaryMoveTarget] = tNearbyLandPosition
                            else
                                if oPlatoon[refiCurrentAction] == nil then oPlatoon[refiCurrentAction] = refActionContinueMovementPath end
                            end
                        end
                    else
                        M27Utilities.ErrorHandler('couldnt locate position value for direct fire weapon on oUnderwater unit')
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Nearby antinavy enemy units and we dont ahve antinavy ourself') end
                end
            else
                M27Utilities.ErrorHandler('platoon is registered as having underwater amphibious units, but couldnt locate any with a direct fire weapon')
            end
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': tPlatoonPosition[2]='..tPlatoonPosition[2]..'; terrain height='..GetTerrainHeight(tPlatoonPosition[1], tPlatoonPosition[3])..'; surface height='..GetSurfaceHeight(tPlatoonPosition[1], tPlatoonPosition[3])) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdatePlatoonActionForNearbyEnemies(oPlatoon, bAlreadyHaveAttackActionFromOverseer)
    --Decides what to do based on what enemies the platoon has recorded as being nearby
    --assumes GetNearbyEnemyData has already been run
    --A number of different things get considered here - whether ACU is low on health and should run; whether we're underwater and can't hit the unit; whether we should issue an overcharge command; whether (for ACU) our shot is blocked; whether we should kite the enemy; and then the more conventional 'do we attack or run' based on enemy threat
    if bAlreadyHaveAttackActionFromOverseer == nil then bAlreadyHaveAttackActionFromOverseer = false end
    local iExistingAction = oPlatoon[refiCurrentAction]
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdatePlatoonActionForNearbyEnemies'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --ACU run away if low on health (regardless of whether enemies are in range, although put here since at some point will want T1 arti micro)
    local sPlatoonName = oPlatoon:GetPlan()
    local aiBrain = oPlatoon:GetBrain()
    local bProceed = true
    --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end
    --if sPlatoonName == 'M27LargeAttackForce' then bDebugMessages = true end
    --if sPlatoonName == 'M27IntelPathAI' then bDebugMessages = true end
    --if sPlatoonName == 'M27IndirectDefender' then bDebugMessages = true end
    --if sPlatoonName == 'M27MexRaiderAI' then bDebugMessages = true end
    --if sPlatoonName == 'M27MexLargerRaiderAI' then bDebugMessages = true end
    --if sPlatoonName == 'M27EscortAI' then bDebugMessages = true end
    --if sPlatoonName == 'M27CombatPatrolAI' then bDebugMessages = true end

    if bDebugMessages == true then LOG(sFunctionRef..':'..sPlatoonName..oPlatoon[refiPlatoonCount]..': Start of code') end

    --Mobile shield normal platoon - will be assisting a unit so dont care about whether are nearby enemies, instead only care if shield is failing (handled via separate logic)
    if not(sPlatoonName == 'M27MobileShield') then
        --ACU RunAway logic (highest priority):
        if oPlatoon[refbACUInPlatoon] == true then
            --Run back to base if low health (unless are already near our base); reset movement path if regained health
            local iHealthToRunOn = aiBrain[M27Overseer.refiACUHealthToRunOn]
            if iHealthToRunOn == nil then iHealthToRunOn = 5250 end
            local iCurrentHealth = M27Utilities.GetACU(aiBrain):GetHealth()
            --If have mobile shield coverage treat health as being 2k more than it is
            if M27Conditions.HaveNearbyMobileShield(oPlatoon) then iCurrentHealth = iCurrentHealth + 2000 end
            if oPlatoon[refbNeedToHeal] == true then iHealthToRunOn = math.max(6250, iHealthToRunOn + 750) end
            if iCurrentHealth <= iHealthToRunOn then
                oPlatoon[refbNeedToHeal] = true
                --Check if we're already near our base - use iDistanceFromBaseToBeSafe for below, and then m27overseer has a lower threshold for if <30% health
                if M27Utilities.GetDistanceBetweenPositions(GetPlatoonFrontPosition(oPlatoon), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) > M27Overseer.iDistanceFromBaseToBeSafe then
                    oPlatoon[refiCurrentAction] = refActionReturnToBase
                    bProceed = false
                else
                    --Proceed with normal logic
                end
            else
                oPlatoon[refbNeedToHeal] = false
            end
            if bDebugMessages == true then LOG(sFunctionRef..': iACUHealth='..iCurrentHealth..'; finished checking if should run due to low health, bProceed='..tostring(bProceed)) end
            if bProceed == true then
                local bACUNeedsToRun = false
                --Have we recently taken damage from an unseen source?
                local oACU = M27Utilities.GetACU(aiBrain)
                if bDebugMessages == true then
                    local iLastTimeTakenDamage = oACU[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage]
                    if iLastTimeTakenDamage == nil then iLastTimeTakenDamage = 0 end
                    LOG(sFunctionRef..': Checking last time ACU took damage, iLastTimeTakenDamage='..iLastTimeTakenDamage..'; CurGameTime='..GetGameTimeSeconds())
                end

                if oACU[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage] and GetGameTimeSeconds() - oACU[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage] <= 25 then
                    local oUnseenDamageDealer = oACU[M27Overseer.refoUnitDealingUnseenDamage]
                    if oUnseenDamageDealer and not(oUnseenDamageDealer.Dead) and oUnseenDamageDealer.GetUnitId then
                        if M27Logic.GetUnitMaxGroundRange({oUnseenDamageDealer}) >= 35 or EntityCategoryContains(M27UnitInfo.refCategoryTorpedoLandAndNavy, oUnseenDamageDealer:GetUnitId()) then
                            if bDebugMessages == true then LOG(sFunctionRef..': ACU taken unseem damage from a unit with a range of at least 35 so want to run') end
                            bACUNeedsToRun = true
                        end
                    end
                end
                if bACUNeedsToRun == false then
                    --Are we significantly outnumbered in threat and/or up against alot of T2+ PD?
                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if ACU significantly outnumbered or lots of T2 PD nearby') end
                    local iEnemyThreatRating = 0
                    if oPlatoon[refiEnemyStructuresInRange] > 0 then
                        local tEnemyT2PlusPD = EntityCategoryFilterDown(M27UnitInfo.refCategoryT2PlusPD, oPlatoon[reftEnemyStructuresInRange])
                        if M27Utilities.IsTableEmpty(tEnemyT2PlusPD) == false then
                            if table.getn(tEnemyT2PlusPD) >= 3 then
                                if bDebugMessages == true then LOG(sFunctionRef..': ACU against at least 3 T2 PD so need to run') end
                                bACUNeedsToRun = true
                            end
                        end
                    end
                    if bACUNeedsToRun == false then
                        if oPlatoon[refiEnemiesInRange] > 0 then iEnemyThreatRating = M27Logic.GetCombatThreatRating(aiBrain, oPlatoon[reftEnemiesInRange], true) end
                        if oPlatoon[refiEnemyStructuresInRange] > 0 then iEnemyThreatRating = iEnemyThreatRating + M27Logic.GetCombatThreatRating(aiBrain, oPlatoon[reftEnemyStructuresInRange], true) end
                        if iEnemyThreatRating > 0 then
                            local iOurThreatRating = 0
                            if bDebugMessages == true then
                                --Reproduce every unit in tFriendlyNearbyCombatUnits:
                                LOG('Size of oPlatoon[reftFriendlyNearbyCombatUnits]='..table.getn(oPlatoon[reftFriendlyNearbyCombatUnits])..'; about to list out every unit')
                                for iUnit, oUnit in oPlatoon[reftFriendlyNearbyCombatUnits] do
                                    LOG('iUnit='..iUnit..'; oUnit='..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit))
                                end
                            end
                            iOurThreatRating = M27Logic.GetCombatThreatRating(aiBrain, oPlatoon[reftFriendlyNearbyCombatUnits], false)
                            if bDebugMessages == true then LOG(sFunctionRef..': iOurThreatRating='..iOurThreatRating..'; iEnemyThreatRating='..iEnemyThreatRating..'; will run if our threat rating less than 80% of enemy') end
                            if iOurThreatRating / iEnemyThreatRating <= 1.2 then
                                bACUNeedsToRun = true
                            end
                        end
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Finished considering if too many PD or enemy threat nearby, bACUNeedsToRun='..tostring(bACUNeedsToRun)) end
                if bACUNeedsToRun == true then
                    oPlatoon[refiCurrentAction] = refActionRun
                    bProceed = false
                end
            end
        end

        --If underwater unit then check for navy units here (aren't checking all the time as only want to include enemy actions re them if are underwater - dont want units chasing them into the water; navy already gets included in nearbyenemies for overwater units
        local iNearbyEnemies = oPlatoon[refiEnemyStructuresInRange] + oPlatoon[refiEnemiesInRange]
        local tPlatoonPos = GetPlatoonFrontPosition(oPlatoon)
        local tEnemyNavyIfUnderwater
        if iNearbyEnemies == 0 and oPlatoon[refbPlatoonHasUnderwaterLand] == true then
            tEnemyNavyIfUnderwater = aiBrain:GetUnitsAroundPoint(categories.NAVAL * categories.MOBILE, tPlatoonPos, oPlatoon[refiEnemySearchRadius], 'Enemy')
            if M27Utilities.IsTableEmpty(tEnemyNavyIfUnderwater) == false then iNearbyEnemies = table.getn(tEnemyNavyIfUnderwater) end
        end
        local bDontConsiderFurtherOrders = false
        local bWillWinAttack = false
        local bHaveRunRecently = false
        if oPlatoon[refiCurrentAction] then bProceed = false end
        if iNearbyEnemies > 0 then
            if bProceed == true then
                --Intel specific - just run unless only structures and known to be hostile:
                if oPlatoon[M27PlatoonTemplates.refbRunFromAllEnemies] == true then
                    if oPlatoon[refiEnemiesInRange] > 0 then
                        --Are any enemy units >5 inside our intel range (if M27ScoutAssister or M27MAAAssister, then this is increased to 10)?
                        local bCloseThreat = false
                        local iMinIntelRange = 40
                        local iIntelRange
                        local tPlatoonUnits = oPlatoon:GetPlatoonUnits()
                        --if sPlatoonName == 'M27MAAAssister' then iIntelRange = 40 else
                            for iCurUnit, oUnit in tPlatoonUnits do
                                if not(oUnit.Dead) then
                                    iIntelRange = oUnit:GetBlueprint().Intel.RadarRadius
                                    break
                                end
                            end
                        --end
                        if iIntelRange < iMinIntelRange then iIntelRange = iMinIntelRange end
                        --function GetUnitSpeedData(tUnits, aiBrain, bNeedToHaveBlipOrVisual, iReturnType, iOptionalSpeedThreshold)
                        local iPlatoonSpeed = M27Logic.GetUnitSpeedData(tPlatoonUnits, aiBrain, false, 1)
                        local iDistanceWithinIntelBeforeRun = 5
                        if iPlatoonSpeed > 3.5 then iDistanceWithinIntelBeforeRun = 10 end


                        local tMobileUnitsInIntelRange = aiBrain:GetUnitsAroundPoint(categories.MOBILE, tPlatoonPos, iIntelRange - iDistanceWithinIntelBeforeRun, 'Enemy')
                        --GetCombatThreatRating(aiBrain, tUnits, bUseBlip, iMassValueOfBlipsOverride)
                        if not(tMobileUnitsInIntelRange == nil) then
                            if table.getn(tMobileUnitsInIntelRange) > 0 then
                                if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonName='..sPlatoonName..oPlatoon[refiPlatoonCount]..': mobile units in intel range='..table.getn(tMobileUnitsInIntelRange)) end
                                if M27Logic.GetCombatThreatRating(aiBrain, tMobileUnitsInIntelRange, true, 50) > 0 then
                                    bCloseThreat = true
                                else
                                    --still return true if structure in range that has a threat:
                                    if oPlatoon[refiEnemyStructuresInRange] > 0 then
                                        --GetCombatThreatRating(aiBrain, tUnits, bUseBlip, iMassValueOfBlipsOverride)
                                        if M27Logic.GetCombatThreatRating(aiBrain, oPlatoon[reftEnemyStructuresInRange], true) > 0 then
                                            bCloseThreat = true
                                        end
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonName='..sPlatoonName..oPlatoon[refiPlatoonCount]..': enemy threat='..M27Logic.GetCombatThreatRating(aiBrain, tMobileUnitsInIntelRange, true, 50)) end
                            end
                        end
                        if bCloseThreat == true then
                            --Have enemies in intel range - run away (but not too far)
                            if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonName='..sPlatoonName..oPlatoon[refiPlatoonCount]..':  setting platoon action to run away') end
                            oPlatoon[refiCurrentAction] = refActionTemporaryRetreat
                        else
                            --Do nothing
                        end
                    else
                        --Only have structures nearby - only run if know are hostile:
                        if M27Logic.GetCombatThreatRating(aiBrain, oPlatoon[reftEnemyStructuresInRange], true) > 0 then
                            oPlatoon[refiCurrentAction] = refActionTemporaryRetreat
                        end
                    end
                else

                    --============Non-Intel logic--------

                    --=========Underwater platoon unit logic (higher priority than kiting and overcharge)
                    if bDebugMessages == true then LOG(sFunctionRef..': About to check for underwater if platoon has underwater unit in it') end
                    if oPlatoon[refbPlatoonHasUnderwaterLand] == true then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have an underwater unit, about to run code to check for underwater action') end
                        GetUnderwaterActionForLandUnit(oPlatoon)
                    end
                    --Soemtimes may already ahve had action (e.g. from override) before running the logic, so this checks if action has changed following underwater logic
                    if not(oPlatoon[refiCurrentAction] == iExistingAction) then bDontConsiderFurtherOrders = true end
                    if bDontConsiderFurtherOrders == false then


                        --======ACU Enemy units cant be hit - BLOCKED LOGIC-------
                        bDontConsiderFurtherOrders = false
                        local iPlatoonMaxRange
                        if oPlatoon[refbACUInPlatoon] == true then
                            iPlatoonMaxRange = M27Logic.GetDirectFireUnitMinOrMaxRange(oPlatoon:GetPlatoonUnits(), 2)
                            local bShotIsBlockedForAnyUnit = false
                            local bShotIsBlockedForAllUnits = true
                            local iClosestUnitWhereShotNotBlocked = 1000
                            local iClosestMobileUnit = 1000
                            local oClosestMobileUnit
                            local oClosestUnitWhereShotNotBlocked
                            local sEnemyRef, sEnemyCountRef, iCurDistance
                            local tACUPosition = GetPlatoonFrontPosition(oPlatoon)
                            local oACU = M27Utilities.GetACU(aiBrain)
                            if bDebugMessages == true then LOG(sFunctionRef..': About to check if any nearby enemies are blocked') end
                            --Do we have a current target, and if so is the shot blocked?
                            local iWeaponCount = oACU:GetWeaponCount()
                            local oWeapon
                            local oCurTarget
                            local bShotBlockedForCurTarget = false
                            for i = 1, iWeaponCount do
                                oWeapon = oACU:GetWeapon(i)
                                if oWeapon.GetCurrentTarget then
                                    oCurTarget = oWeapon:GetCurrentTarget()
                                    if oCurTarget and not(oCurTarget.Dead) then
                                        bShotBlockedForCurTarget = M27Logic.IsShotBlocked(oACU, oCurTarget)
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef..': Found a target for ACUs current weapon, checking if shot is blocked. bShotBlockedForCurTarget='..tostring(bShotBlockedForCurTarget))
                                            M27Utilities.DrawLocation(oCurTarget:GetPosition())
                                        end

                                        break
                                    end
                                end
                            end

                            if bShotBlockedForCurTarget == true then
                                bShotIsBlockedForAnyUnit = true
                                for iEnemyType = 1, 2 do
                                    if iEnemyType == 1 then sEnemyRef = reftEnemiesInRange sEnemyCountRef = refiEnemiesInRange
                                    else sEnemyRef = reftEnemyStructuresInRange sEnemyCountRef = refiEnemyStructuresInRange end
                                    if oPlatoon[sEnemyCountRef] > 0 then
                                        for iUnit, oUnit in oPlatoon[sEnemyRef] do
                                            if not(oUnit.Dead) then
                                                iCurDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tACUPosition)
                                                if iCurDistance <= iPlatoonMaxRange then
                                                    local bUnitExists = false
                                                    --if iEnemyType == 1 then bUnitExists = true
                                                    --elseif oUnit.GetFractionComplete and oUnit:GetFractionComplete() > 0 then bUnitExists = true end
                                                    --if bUnitExists == true then
                                                        if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': Is within range of platoon, iCurDistance='..iCurDistance..' checking if its blocked') end
                                                        if M27Logic.IsShotBlocked(oACU, oUnit) == false then
                                                            if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': Shot is not blocked') end
                                                            bShotIsBlockedForAllUnits = false
                                                            if iCurDistance < iClosestUnitWhereShotNotBlocked then
                                                                iClosestUnitWhereShotNotBlocked = iCurDistance
                                                                oClosestUnitWhereShotNotBlocked = oUnit
                                                            end

                                                        else
                                                            if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': Shot is blocked') end
                                                            --bShotIsBlockedForAnyUnit = true
                                                            if iEnemyType == 1 then
                                                                if iClosestMobileUnit > iCurDistance then
                                                                    iClosestMobileUnit = iCurDistance
                                                                    oClosestMobileUnit = oUnit
                                                                end
                                                            end
                                                        end
                                                    --end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': Finished checking if nearby units are blocked, bShotIsBlockedForAllUnits='..tostring(bShotIsBlockedForAllUnits)..'; bShotIsBlockedForAnyUnit='..tostring(bShotIsBlockedForAnyUnit)) end
                            --Update action if some or all units nearby are blocked
                            if bShotBlockedForCurTarget == true then
                                if bShotIsBlockedForAllUnits == true and oPlatoon[refiReclaimers] > 0 then

                                    local iBuildDistance = oPlatoon[reftReclaimers][1]:GetBlueprint().Economy.MaxBuildDistance
                                    if bDebugMessages == true then LOG(sFunctionRef..': Shot is blocked for all units. iBuildDistance='..iBuildDistance..'; iClosestMobileUnit='..iClosestMobileUnit) end
                                    if iClosestMobileUnit <= (iBuildDistance + 1) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Units are blocked but in build range so will reclaim') end
                                        oPlatoon[refoNearbyReclaimTarget] = oClosestMobileUnit
                                        oPlatoon[refiCurrentAction] = refActionReclaimTarget
                                    else
                                        oPlatoon[refiCurrentAction] = refActionMoveDFToNearestEnemy
                                    end
                                    bDontConsiderFurtherOrders = true
                                --elseif bShotIsBlockedForAnyUnit == true then
                                else
                                    oPlatoon[refiCurrentAction] = refActionAttackSpecificUnit
                                    oPlatoon[refoTemporaryAttackTarget] = oClosestUnitWhereShotNotBlocked
                                    if oClosestUnitWhereShotNotBlocked == nil then
                                        M27Utilities.ErrorHandler('Trying to assign attack command when no unit, will clear action instead')
                                        oPlatoon[refiCurrentAction] = nil
                                    end
                                end
                            end
                            if bDebugMessages == true then
                                if oPlatoon[refiCurrentAction] == nil then LOG('Action after checking for blocked units is nil')
                                else LOG('Action after checking for blocked units='..oPlatoon[refiCurrentAction]) end
                            end
                        end
                        --Check we dont already have an action:
                        if oPlatoon[refiCurrentAction] == nil then bDontConsiderFurtherOrders = false
                        else --Already have an action - only consider remaining logic if were assigned action by overseer override
                            if bAlreadyHaveAttackActionFromOverseer == true and oPlatoon[refiCurrentAction] == iExistingAction then bDontConsiderFurtherOrders = false end
                        end
                        if bDontConsiderFurtherOrders == false then
                            --=========KITING LOGIC-------------
                            if oPlatoon[refiEnemiesInRange] > 0 then
                                if oPlatoon[refbKiteEnemies] == true then
                                    if oPlatoon[refbACUInPlatoon] == true or oPlatoon[refiDFUnits] > 0 then
                                        if bDebugMessages == true then LOG(sFunctionRef..sPlatoonName..': Considering kiting action; iEnemiesInRange='..oPlatoon[refiEnemiesInRange]) end
                                        --if ACU in platoon then we already got its range in previous step
                                        if oPlatoon[refbACUInPlatoon] == false then iPlatoonMaxRange = M27Logic.GetDirectFireUnitMinOrMaxRange(oPlatoon:GetPlatoonUnits(), 2) end
                                        --Get nearest enemy
                                        local tPlatoonPosition = GetPlatoonFrontPosition(oPlatoon)
                                        local tNearbyPD = {}
                                        local oNearestPD
                                        if oPlatoon[refiEnemyStructuresInRange] > 0 then
                                            tNearbyPD = EntityCategoryFilterDown(categories.DIRECTFIRE, oPlatoon[reftEnemyStructuresInRange])
                                            if M27Utilities.IsTableEmpty(tNearbyPD) == false then
                                                oNearestPD = M27Utilities.GetNearestUnit(tNearbyPD, tPlatoonPosition, aiBrain, true)
                                            end
                                        end
                                        local oNearestEnemy = M27Utilities.GetNearestUnit(oPlatoon[reftEnemiesInRange], tPlatoonPosition, aiBrain, true)
                                        local iEnemyMaxRange = 0
                                        if oNearestEnemy or oNearestPD then
                                            local iNearestEnemyDistance = 1000
                                            local iNearestPDDistance = 1000
                                            local tNearestPD, tNearestEnemy
                                            if oNearestPD then
                                                tNearestPD = oNearestPD:GetPosition()
                                                iNearestPDDistance = M27Utilities.GetDistanceBetweenPositions(tNearestPD, tPlatoonPosition)
                                            end
                                            if oNearestEnemy then
                                                tNearestEnemy = oNearestEnemy:GetPosition()
                                                iNearestEnemyDistance = M27Utilities.GetDistanceBetweenPositions(tNearestEnemy, tPlatoonPosition)
                                            end
                                            if iNearestPDDistance < iNearestEnemyDistance then
                                                oNearestEnemy = oNearestPD
                                            end
                                            --CanSeeUnit(aiBrain, oUnit, bTrueIfOnlySeeBlip)
                                            if oNearestEnemy == oNearestPD then
                                                --Dont need CanSeeUnit, as in reality will have visual effect from enemy PD that is distinctive such that will know if there's an enemy PD nearby
                                                iEnemyMaxRange = M27Logic.GetDirectFireUnitMinOrMaxRange({oNearestEnemy}, 2)
                                            else
                                                if M27Utilities.CanSeeUnit(aiBrain, oNearestEnemy, false) then iEnemyMaxRange = M27Logic.GetDirectFireUnitMinOrMaxRange({oNearestEnemy}, 2) end
                                            end
                                            if bDebugMessages == true then LOG(sFunctionRef..sPlatoonName..': iPlatoonMaxRange='..iPlatoonMaxRange..'; iEnemyMaxRange='..iEnemyMaxRange) end
                                            if iPlatoonMaxRange >= iEnemyMaxRange then --if have same max range may still be benefit to kiting if enemy lacks intel
                                                if oNearestEnemy == oNearestPD then
                                                    bDontConsiderFurtherOrders = true
                                                    oPlatoon[refiCurrentAction] = refActionMoveJustWithinRangeOfNearestPD
                                                else
                                                    --GetIntelCoverageOfPosition(aiBrain, tTargetPosition, iMinCoverageWanted)
                                                    --    --Look for the nearest intel coverage for tTargetPosition
                                                    --    --if iMinCoverageWanted isn't specified then will return the highest amount, otherwise returns true/false
                                                    if iNearestEnemyDistance > iPlatoonMaxRange then
                                                        bDontConsiderFurtherOrders = true
                                                        oPlatoon[refiCurrentAction] = refActionMoveDFToNearestEnemy
                                                    else
                                                        local iIntelCoverage
                                                        --If ACU in platoon, then check if it has a scout assigned that is close enough (for CPU performance reasons only want to call getintelcoverage if we dont)
                                                        if oPlatoon[refbACUInPlatoon] and oPlatoon[refoFrontUnit] and M27UnitInfo.IsUnitValid(oPlatoon[refoFrontUnit][M27Overseer.refoUnitsScoutHelper]) then iIntelCoverage = oPlatoon[refoFrontUnit][M27Overseer.refoUnitsScoutHelper]:GetBlueprint().Intel.RadarRadius - M27Utilities.GetDistanceBetweenPositions(oPlatoon[refoFrontUnit][M27Overseer.refoUnitsScoutHelper]:GetPosition(), GetPlatoonFrontPosition(oPlatoon)) end
                                                        if not(iIntelCoverage) or iIntelCoverage < math.max(iEnemyMaxRange, 22) then iIntelCoverage = M27Logic.GetIntelCoverageOfPosition(aiBrain, tPlatoonPosition, nil) end
                                                        if bDebugMessages == true then LOG(sFunctionRef..sPlatoonName..': We outrange nearest enemy, checking our intel coverage, iIntelCoverage='..iIntelCoverage) end
                                                        if iIntelCoverage >= math.max(iEnemyMaxRange, 22) then --ACU has range of 22 (no gun) and vision of 26, so want to have intel coverage of at least this before consider other actions
                                                            local iDistanceInsideOurRange = iPlatoonMaxRange - iNearestEnemyDistance
                                                            local iPrevDistanceInsideOurRange = oPlatoon[refiPrevNearestEnemyDistance]
                                                            oPlatoon[refiPrevNearestEnemyDistance] = iDistanceInsideOurRange
                                                            if bDebugMessages == true then LOG(sFunctionRef..sPlatoonName..': iDistanceInsideOurRange='..iDistanceInsideOurRange) end
                                                            if iDistanceInsideOurRange > 5 then
                                                                bDontConsiderFurtherOrders = true
                                                                oPlatoon[refiCurrentAction] = refActionTemporaryRetreat
                                                            else
                                                                if iPrevDistanceInsideOurRange == nil or iPrevDistanceInsideOurRange < iDistanceInsideOurRange then --Enemy getting close
                                                                    bDontConsiderFurtherOrders = true
                                                                    oPlatoon[refiCurrentAction] = refActionTemporaryRetreat
                                                                else
                                                                    bDontConsiderFurtherOrders = true
                                                                    oPlatoon[refiCurrentAction] = refActionMoveDFToNearestEnemy
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            else
                                                --We either dont outrange enemy or dont know if we do - revert to normal logic
                                                --bDontConsiderFurtherOrders = true
                                                --oPlatoon[refiCurrentAction] = refActionMoveDFToNearestEnemy
                                            end
                                            --Kiting override - if have >1 unit closer to enemy than us, then want to just attack-move rather than running away
                                            if oPlatoon[refiCurrentAction] == refActionTemporaryRetreat then
                                                local iCloserAllyCount = 0
                                                local tCloserAllies = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.DIRECTFIRE + categories.LAND * categories.INDIRECTFIRE, tPlatoonPosition, iNearestEnemyDistance, 'Ally')
                                                if M27Utilities.IsTableEmpty(tCloserAllies) == false then
                                                    local iCloserAllyCount = table.getn(tCloserAllies)
                                                    if iCloserAllyCount >= 3 then --in reality 2 as ACU should be included
                                                        oPlatoon[refiCurrentAction] = refActionAttack
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                if bDebugMessages == true then if oPlatoon[refiCurrentAction]==nil then LOG(sFunctionRef..sPlatoonName..': Action after running kiting logic is nil')
                                else LOG(sFunctionRef..sPlatoonName..': Action after running kiting logic='..oPlatoon[refiCurrentAction])end
                                end
                            end
                            if oPlatoon[refbKiteEnemies] == true then
                                if oPlatoon[refiCurrentAction] == nil then
                                    if oPlatoon[refbKitingLogicActive] == true then
                                        --Were previously kiting, now have no action re kiting - e.g. enemy destroyed, or run away
                                        if bDebugMessages == true then LOG(sFunctionRef..': Kiting logic has no action, but previously did; reissuing movement path') end
                                        oPlatoon[refiCurrentAction] = refActionReissueMovementPath
                                    end
                                    oPlatoon[refbKitingLogicActive] = false
                                else
                                    oPlatoon[refbKitingLogicActive] = true
                                end
                            end
                        else
                            --Already have an action from running or units blocked
                            bDontConsiderFurtherOrders = true
                        end
                    end
                end
            end





            --=================ACU Overcharge logic (still OC if are running away):
            if oPlatoon[refbACUInPlatoon] == true then
                if bDebugMessages == true then LOG(sFunctionRef..' about to see if can overcharge') end
                --Assumes ACU will be in table of builders - check if only have 1, in which case should be ACU
                local oPlayerACU = M27Utilities.GetACU(aiBrain) --check in case ACU dies and causes crash
                if oPlatoon[reftBuilders][1] then if M27Conditions.CanUnitUseOvercharge(aiBrain, oPlatoon[reftBuilders][1]) == true then M27UnitMicro.GetOverchargeExtraAction(aiBrain, oPlatoon, oPlatoon[reftBuilders][1]) end end
            end
            --if oPlatoon[refbKitingLogicActive] == true and not(oPlatoon[refiCurrentAction] == nil) then bDontConsiderFurtherOrders = true end



            if oPlatoon[refiCurrentAction] == nil then bDontConsiderFurtherOrders = false
            else
                if bAlreadyHaveAttackActionFromOverseer == true and oPlatoon[refiCurrentAction] == iExistingAction then bDontConsiderFurtherOrders = false
                else bDontConsiderFurtherOrders = true
                end
            end

            if bProceed == true and bDontConsiderFurtherOrders == false then
                --Have we recently given a move DF untis order? If so then dont override it for a while unless have reacehd destination as likely gave the order as were stuck
                if bDebugMessages == true then
                    if oPlatoon[refiEnemyStructuresInRange] > 0 then
                        LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdatePlatoonActionForNearbyEnemies: EnemyStructuresInRange='..oPlatoon[refiEnemyStructuresInRange]..'; Platoon location='..GetPlatoonFrontPosition(oPlatoon)[1]..'-'..GetPlatoonFrontPosition(oPlatoon)[3]..'; location of first enemy structure='..oPlatoon[reftEnemyStructuresInRange][1]:GetPosition()[1]..'-'..oPlatoon[reftEnemyStructuresInRange][1]:GetPosition()[3])
                        LOG('Distance to nearest structure='..M27Utilities.GetDistanceBetweenPositions(GetPlatoonFrontPosition(oPlatoon), oPlatoon[reftEnemyStructuresInRange][1]:GetPosition()))
                        LOG('Platoon max range='..M27Logic.GetUnitMaxGroundRange(oPlatoon[reftCurrentUnits]))
                    end
                end


                local bDontChangeCurrentAction = false
                if not(oPlatoon[reftPrevAction][10] == nil) then
                    if oPlatoon[reftPrevAction][1] == refActionMoveDFToNearestEnemy then
                        if bDebugMessages == true then LOG(sFunctionRef..': prev action was for DF units to move to nearest enemy, so wont consider changing unless we are an escort platoon') end
                        if not(oPlatoon[refoEscortingPlatoon]) then
                            bDontChangeCurrentAction = true
                            for iPrevAction = 1, 10 do
                                if not(oPlatoon[reftPrevAction][iPrevAction] == refActionMoveDFToNearestEnemy) then
                                    --Haven't been targetting DF for 10 cycles yet, so dont change
                                    break
                                end
                                if iPrevAction == 10 then
                                    --Have been targetting DF for 10 cycles now
                                    bDontChangeCurrentAction = false
                                end
                            end
                            if bDontChangeCurrentAction == false then
                                --Check if have reached the target:
                                local tDFUnits = EntityCategoryFilterDown(categories.DIRECTFIRE, oPlatoon[reftCurrentUnits])
                                if tDFUnits == nil then bDontChangeCurrentAction = false
                                else
                                    if table.getn(tDFUnits) == 0 then bDontChangeCurrentAction = false
                                    else
                                        if M27Utilities.GetDistanceBetweenPositions(M27Utilities.GetAveragePosition(tDFUnits), oPlatoon[reftTemporaryMoveTarget]) <= 10 then bDontChangeCurrentAction = false end
                                    end
                                end
                            end
                        end
                    end
                end
                --[[if oPlatoon[refbACUInPlatoon] == true and not(oPlatoon[refiCurrentAction] == nil) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have already determined action for ACU platoon, so dont want to proceed with normal logic for determining action') end
                    bDontChangeCurrentAction = true
                end--]]

                if oPlatoon[refiCurrentAction] == nil then bDontConsiderFurtherOrders = false
                else
                    if bAlreadyHaveAttackActionFromOverseer == true and oPlatoon[refiCurrentAction] == iExistingAction then bDontConsiderFurtherOrders = false
                    else bDontConsiderFurtherOrders = true
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': Have an action now, refiCurrentAction='..oPlatoon[refiCurrentAction]) end
                end
                --Note - reason why might still want to consider action is if overseer has given an override action saying to attack as a general order; the below should then hopefully get more optimal commands for how to attack





                --=======normal determining action for enemies
                if bDebugMessages == true then LOG(sFunctionRef..': Finished considering special cases, now check if should use core logic, bDontChangeCurrentAction='..tostring(bDontChangeCurrentAction)) end
                if bDontChangeCurrentAction == false then
                    if oPlatoon[refbACUInPlatoon] == true then
                        if oPlatoon[refiEnemiesInRange] + oPlatoon[refiEnemyStructuresInRange] > 0 and oPlatoon[refiCurrentAction] == nil then
                            if bDebugMessages == true then LOG(sFunctionRef..': About to issue attack order to ACU as bDontChangeCurrentAction is false') end
                            oPlatoon[refiCurrentAction] = refActionAttack
                        end
                    else
                        if oPlatoon[M27PlatoonTemplates.refbAlwaysAttack] == true then
                            --Dont care about threat etc. with this AI - just attack - only exception is if up against multiple T2+ PD, as dont want to feed enemy kills
                            local bAttack = true
                            if oPlatoon[refiEnemyStructuresInRange] >= 2 then
                                local tEnemyT2PlusPD = EntityCategoryFilterDown(M27UnitInfo.refCategoryT2PlusPD, oPlatoon[reftEnemyStructuresInRange])
                                if M27Utilities.IsTableEmpty(tEnemyT2PlusPD) == false then
                                    local iEnemyT2PlusPD = table.getn(tEnemyT2PlusPD)
                                    if iEnemyT2PlusPD >= 2 then
                                        --Do we have indirect fire units nearby?
                                        local tNearbyMML = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryIndirectT2Plus, GetPlatoonFrontPosition(oPlatoon), oPlatoon[M27Overseer.refiSearchRangeForEnemyStructures])
                                        if M27Utilities.IsTableEmpty(tNearbyMML) == false then
                                            bAttack = false
                                        else
                                            if oPlatoon[refiCurrentUnits] < iEnemyT2PlusPD * 15 then
                                                local tT3PlusUnits = EntityCategoryFilterDown(categories.TECH3 + categories.EXPERIMENTAL, oPlatoon[reftCurrentUnits])
                                                if M27Utilities.IsTableEmpty(tT3PlusUnits) == true then
                                                    bAttack = false
                                                else
                                                    local iT3PlusUnits = table.getn(tT3PlusUnits)
                                                    if iT3PlusUnits < iEnemyT2PlusPD then
                                                        if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.EXPERIMENTAL, tT3PlusUnits)) == true then
                                                            bAttack = false
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            if bAttack == true then oPlatoon[refiCurrentAction] = refActionAttack
                            else oPlatoon[refiCurrentAction] = refActionTemporaryRetreat
                            end
                        else
                            --Is the ACU nearby?
                            local tNearbyACU
                            local bProtectACU = false
                            if M27Utilities.IsTableEmpty(oPlatoon[reftFriendlyNearbyCombatUnits]) == false then
                                tNearbyACU = EntityCategoryFilterDown(categories.COMMAND, oPlatoon[reftFriendlyNearbyCombatUnits])
                                if M27Utilities.IsTableEmpty(tNearbyACU) == false then
                                    if bDebugMessages == true then LOG(sFunctionRef..': ACU is nearby so probably just want to attack') end
                                    --Case where always want to - enemy unit within 25 of ACU
                                    local oACU = tNearbyACU[1]
                                    local oACUPlatoon = oACU.PlatoonHandle
                                    local iNearestUnitDistance = oACUPlatoon[refiACUNearestEnemy]
                                    if iNearestUnitDistance == nil then iNearestUnitDistance = 10000 end
                                    --[[local tACUPosition = oACU:GetPosition()

                                    if oACUPlatoon == nil then oACUPlatoon = oPlatoon end
                                    local oMobileEnemyNearestACU, oStructureNearestACU
                                    local iNearestUnitDistance = 10000
                                    if oACUPlatoon[refiEnemiesInRange] > 0 then
                                        oMobileEnemyNearestACU = M27Utilities.GetNearestUnit(oACUPlatoon[reftEnemiesInRange], tACUPosition, aiBrain, true)
                                        if oMobileEnemyNearestACU then iNearestUnitDistance = M27Utilities.GetDistanceBetweenPositions(oMobileEnemyNearestACU:GetPosition(), tACUPosition) end
                                    end
                                    if oACUPlatoon[refiEnemyStructuresInRange] > 0 then
                                        oStructureNearestACU = M27Utilities.GetNearestUnit(oACUPlatoon[reftEnemyStructuresInRange], tACUPosition, aiBrain, true)
                                        if oStructureNearestACU then iNearestUnitDistance = math.min(iNearestUnitDistance, M27Utilities.GetDistanceBetweenPositions(oStructureNearestACU:GetPosition(), tACUPosition)) end
                                    end --]]
                                    local iACUHealthPercent = oACU:GetHealthPercent()
                                    if iACUHealthPercent < 0.9 then
                                        if iNearestUnitDistance <= 20 then
                                            bProtectACU = true
                                        elseif iNearestUnitDistance <= 30 and oACUPlatoon[refiCurrentAction] == refActionRun then
                                            bProtectACU = true
                                        elseif iNearestUnitDistance <= 35 and oACU:GetHealthPercent() <= 0.55 then
                                            bProtectACU = true
                                        end
                                    end
                                end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': Have just considered whether we have a friendly ACU nearby and if so if it needs protecting; bProtectACU='..tostring(bProtectACU)) end
                            if bProtectACU == true then
                                oPlatoon[refiCurrentAction] = refActionAttack
                            else
        --INDIRECT FIRE PD ATTACKER PLATOON LOGIC
                                if sPlatoonName == 'M27IndirectDefender' or sPlatoonName == 'M27IndirectSpareAttacker' then
                                    local bAttackACU = false
                                    if oPlatoon[refiEnemiesInRange] > 0 then
                                        --Is there an enemy ACU upgrading in-range but no mobile units <=30 of distance between us and the enemy ACU?
                                        local tEnemyACUs = EntityCategoryFilterDown(categories.COMMAND, oPlatoon[reftEnemiesInRange])
                                        local bACUUpgrading = false
                                        local oNearestUpgradingACU, iCurACUDistance
                                        local iNearestUpgradingACUDistance = 10000
                                        if M27Utilities.IsTableEmpty(tEnemyACUs) == false then
                                            for iACU, oACU in tEnemyACUs do
                                                if oACU:IsUnitState('Upgrading') then
                                                    bACUUpgrading = true
                                                    iCurACUDistance = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), GetPlatoonFrontPosition(oPlatoon))
                                                    if iCurACUDistance < iNearestUpgradingACUDistance then
                                                        iNearestUpgradingACUDistance = iCurACUDistance
                                                        oNearestUpgradingACU = oACU
                                                    end
                                                end
                                            end
                                        end
                                        if bACUUpgrading == true then
                                            local oNearestMobileUnit = M27Utilities.GetNearestUnit(oPlatoon[reftEnemiesInRange], GetPlatoonFrontPosition(oPlatoon), aiBrain)
                                            local iNearestMobileUnit = M27Utilities.GetDistanceBetweenPositions(GetPlatoonFrontPosition(oPlatoon), oNearestMobileUnit:GetPosition())
                                            if iNearestMobileUnit > 30 then
                                                local oNearestStructure, iNearestStructure
                                                if oPlatoon[refiEnemyStructuresInRange] > 0 then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': refiEnemyStructuresInRange='..oPlatoon[refiEnemyStructuresInRange]) end
                                                    oNearestStructure = M27Utilities.GetNearestUnit(oPlatoon[reftEnemyStructuresInRange], GetPlatoonFrontPosition(oPlatoon), aiBrain)
                                                    if oNearestStructure == nil then M27Utilities.ErrorHandler('Nearest structure is nil') iNearestStructure = 1000
                                                    else
                                                        iNearestStructure = M27Utilities.GetDistanceBetweenPositions(GetPlatoonFrontPosition(oPlatoon), oNearestStructure:GetPosition())
                                                    end
                                                else iNearestStructure = 1000
                                                end
                                                if iNearestStructure > iNearestUpgradingACUDistance then
                                                    bAttackACU = true
                                                    oPlatoon[refiCurrentAction] = refActionAttackSpecificUnit
                                                    oPlatoon[refoTemporaryAttackTarget] = oNearestUpgradingACU
                                                end
                                            end
                                        end
                                    end
                                    --No upgrading ACU or nearby enemies so want to retreat:
                                    if not(bAttackACU) then
                                        if oPlatoon[refiEnemyStructuresInRange] > 0 then oPlatoon[refiCurrentAction] = refActionAttack
                                        elseif oPlatoon[refiEnemiesInRange] > 0 then oPlatoon[refiCurrentAction] = refActionTemporaryRetreat
                                        else
                                            --Are there still structures near our end destination?
                                            if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, oPlatoon[reftMovementPath][table.getn(oPlatoon[reftMovementPath])], oPlatoon[refiEnemySearchRadius], 'Enemy')) == true then
                                                if bDebugMessages == true then LOG(sFunctionRef..': No nearby structures so disbanding') end
                                                oPlatoon[refiCurrentAction] = refActionDisband
                                            else
                                                --Do we have an escort that still has units in it (if not then there may be nearby enemies even if we cant see them)
                                                if oPlatoon[refiCurrentEscortThreat] < oPlatoon[refiEscortThreatWanted] * 0.3 then
                                                    oPlatoon[refiCurrentAction] = refActionMoveToTemporaryLocation
                                                    oPlatoon[reftTemporaryMoveTarget] = aiBrain[M27Overseer.reftIntelLinePositions][aiBrain[M27Overseer.refiCurIntelLineTarget]][1]
                                                end
                                            end
                                        end
                                    end
                                else
        --ESCORT PLATOON LOGIC
                                    --For escorts dont want to run away if up against a larger threat, as in some cases htem attacking might be enough to save the unit they're escorting
                                    --However, if up against enemy PD then do want to fall back
                                    if sPlatoonName == 'M27EscortAI' then
                                        if bDebugMessages == true then LOG(sFunctionRef..': We are an escort platoon so considering best action for the escort to take') end
                                        if oPlatoon[refiEnemyStructuresInRange] > 0 and M27Logic.GetCombatThreatRating(aiBrain, oPlatoon[reftEnemyStructuresInRange], false) > 100 then
                                            --Run back to indirect fire units
                                            if oPlatoon[refoPlatoonOrUnitToEscort] then
                                                local iNearestEnemyUnit = 10000
                                                local tPlatoonToEscortPosition = GetPlatoonFrontPosition(oPlatoon[refoPlatoonOrUnitToEscort])
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef..': tPlatoonToEscortPosition='..repr(tPlatoonToEscortPosition))
                                                    if oPlatoon[refoPlatoonOrUnitToEscort].GetUnitId then LOG('Are escorting unit with ID='..oPlatoon[refoPlatoonOrUnitToEscort]:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oPlatoon[refoPlatoonOrUnitToEscort]))
                                                    elseif oPlatoon[refoPlatoonOrUnitToEscort].GetPlan then LOG('Are escorting a platoon with plan='..oPlatoon[refoPlatoonOrUnitToEscort]:GetPlan()..oPlatoon[refoPlatoonOrUnitToEscort][refiPlatoonCount]..' and current units='..oPlatoon[refoPlatoonOrUnitToEscort][refiCurrentUnits])
                                                    else
                                                        M27Utilities.ErrorHandler('Are escorting a unit that is neither a unit nor a platoon')
                                                        --oPlatoon[refiCurrentAction] = refActionReturnToBase
                                                    end
                                                end
                                                if oPlatoon[refoPlatoonOrUnitToEscort][refiEnemiesInRange] > 0 then
                                                    local oNearestEnemyUnit = M27Utilities.GetNearestUnit(oPlatoon[refoPlatoonOrUnitToEscort][reftEnemiesInRange], tPlatoonToEscortPosition, aiBrain, true)
                                                    if oNearestEnemyUnit then iNearestEnemyUnit = M27Utilities.GetDistanceBetweenPositions(oNearestEnemyUnit:GetPosition(), tPlatoonToEscortPosition) end
                                                end
                                                if iNearestEnemyUnit <= 25 then
                                                    oPlatoon[refiCurrentAction] = refActionAttack
                                                else
                                                    oPlatoon[refiCurrentAction] = refActionMoveToTemporaryLocation
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Nearest enemy unit isnt within 25 of indirect platoon so moving to temporary position instead') end
                                                    if iNearestEnemyUnit <= 35 then
                                                        oPlatoon[reftTemporaryMoveTarget] = tPlatoonToEscortPosition
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Nearest enemy unit is within 30 so moving to the front of the platoon='..repr(tPlatoonToEscortPosition)) end
                                                    else
                                                        --Go behind the indirect fire units so we dont get in the way/cause our indirect fire units to slowly creep forwards
                                                        local iDistanceBehindEscortedPlatoon = math.min(12, math.max(5, oPlatoon[refiCurrentUnits] / 2))
                                                        oPlatoon[reftTemporaryMoveTarget] = M27Utilities.MoveTowardsTarget(tPlatoonToEscortPosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iDistanceBehindEscortedPlatoon, 0)
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Nearest enemy unit is more than 35 from escorted platoon so will get a position behind the escorted platoon; tPlatoonToEscortPosition='..repr(tPlatoonToEscortPosition)..'; position to move to='..repr(oPlatoon[reftTemporaryMoveTarget])) end
                                                    end
                                                end
                                            else
                                                oPlatoon[refiCurrentAction] = refActionTemporaryRetreat
                                            end
                                        else
                                            if oPlatoon[refiEnemiesInRange] + oPlatoon[refiEnemyStructuresInRange] > 0 then oPlatoon[refiCurrentAction] = refActionAttack end
                                        end
                                    else
                                        --(no longer assume will lose if more enemies as might have ACU in platoon)
                                --                  if oPlatoon[refiEnemiesInRange] - oPlatoon[refiCurrentUnits] <= 5 or oPlatoon[refiEnemiesInRange] <= oPlatoon[refiCurrentUnits]*1.5 then
    --NON-ESCORT LOGIC
                                        --Are there lots of T2+ PD nearby? If so run (even if we have a similar threat) unless we're already in range
                                        local bRunFromPD = false
                                        local bInRangeOfT2PlusPD = false
                                        if oPlatoon[refiEnemyStructuresInRange] > 0 then
                                            local tEnemyT2PlusPD = EntityCategoryFilterDown(M27UnitInfo.refCategoryT2PlusPD, oPlatoon[reftEnemyStructuresInRange])
                                            if M27Utilities.IsTableEmpty(tEnemyT2PlusPD) == false then
                                                local iMaxRangeToUse = math.max(15, M27Logic.GetUnitMaxGroundRange({ oPlatoon[refoFrontUnit] })) --striker has range of 18
                                                --if table.getn(tEnemyT2PlusPD) >= 3 then
                                                    --Are we already within range of any of the PD?

                                                    --Do we have T1 indirect fire units in the platoon?
                                                    if oPlatoon[refiIndirectUnits] > 0 and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryIndirectT2Plus, oPlatoon[reftIndirectUnits])) == true then iMaxRangeToUse = math.max(iMaxRangeToUse, 30)
                                                    else iMaxRangeToUse = math.max(iMaxRangeToUse, M27Logic.GetDirectFireUnitMinOrMaxRange({oPlatoon[refoFrontUnit]}, 2)) end
                                                    local oNearestPD = M27Utilities.GetNearestUnit(tEnemyT2PlusPD, GetPlatoonFrontPosition(oPlatoon), aiBrain)
                                                    if oNearestPD and M27Utilities.GetDistanceBetweenPositions(oNearestPD:GetPosition(), GetPlatoonFrontPosition(oPlatoon)) <= iMaxRangeToUse + 3 then
                                                        bInRangeOfT2PlusPD = true
                                                    else
                                                        if table.getn(tEnemyT2PlusPD) >= 3 then
                                                            bRunFromPD = true
                                                        end
                                                    end
                                                --end
                                            end
                                        end
                                        if bRunFromPD == true then
                                            oPlatoon[refiCurrentAction] = refActionRun
                                        elseif bInRangeOfT2PlusPD == true then --If we've just got in range of T2 PD then better to fight and die than try to run
                                            oPlatoon[refiCurrentAction] = refActionAttack
                                        else

                                    --Are we likely to win a battle? consider all units near platoon position
                                            local iOurThreatRating = M27Logic.GetCombatThreatRating(aiBrain, oPlatoon[reftFriendlyNearbyCombatUnits], false)
                                            if M27Conditions.HaveNearbyMobileShield(oPlatoon) then iOurThreatRating = iOurThreatRating + math.min(iOurThreatRating * 0.5, oPlatoon[refoSupportingShieldPlatoon][refiPlatoonMassValue] * 0.5) end
                                            local iMassValueOfBlipsOverride = nil
                                            if oPlatoon[refiEnemiesInRange] <= 5 then iMassValueOfBlipsOverride = 8 end
                                            local iEnemyThreatRating = 0
                                            if oPlatoon[refiEnemiesInRange] > 0 then iEnemyThreatRating = iEnemyThreatRating + M27Logic.GetCombatThreatRating(aiBrain, oPlatoon[reftEnemiesInRange], true, iMassValueOfBlipsOverride) end
                                            if oPlatoon[refiEnemyStructuresInRange] > 0 then iEnemyThreatRating = iEnemyThreatRating + M27Logic.GetCombatThreatRating(aiBrain, oPlatoon[reftEnemyStructuresInRange], true) end

                                            if iOurThreatRating * 0.95 >= iEnemyThreatRating then
                                                bWillWinAttack = true
                                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionForNearbyEnemies - our threat is better than theirs; iEnemyThreatRating='..iEnemyThreatRating..'; iOurThreatRating='..iOurThreatRating) end
                                            end
                                            --end
                                            if bWillWinAttack == true then
                                                --Check aren't already running away from a threat (and we think we'll win just because some of enemy have dropped out of intel range
                                                if oPlatoon[refbHavePreviouslyRun] == true then
                                                    --we've previously run away - check how recently:
                                                    local iMaxCyclesToCheck = 20
                                                    local iCyclesToCheck = table.getn(oPlatoon[reftPrevAction])
                                                    if iCyclesToCheck >= 1 then
                                                        for iRunCycle = 1, iCyclesToCheck do
                                                            if not(oPlatoon[reftPrevAction][iRunCycle] == nil) then
                                                                if oPlatoon[reftPrevAction][iRunCycle] == refActionRun then
                                                                    bHaveRunRecently = true
                                                                    break
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                            if bWillWinAttack == true then
                                                if bHaveRunRecently == false then
                                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionForNearbyEnemies - will win attack and havent previously run') end
                                                    --Large attack AI - Check we're not about to run after a small number of units with a massive attack force
                                                    if oPlatoon[refiCurrentUnits] >= 18 then
                                                        local bDontChaseEnemy = false
                                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionForNearbyEnemies - Large attack so considering if small number of enemies nearby') end
                                                        if oPlatoon[refiCurrentUnits] >= 10 then
                                                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionForNearbyEnemies - Large attack AI - we have at least 10 units') end
                                                            if oPlatoon[refiEnemyStructuresInRange] == 0 then
                                                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionForNearbyEnemies - Large attack AI - no structures in range') end
                                                                if oPlatoon[refiEnemiesInRange] <= 3 then
                                                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionForNearbyEnemies - Large attack AI - <=3 enemy units') end
                                                                    --Only 3 mobile enemies and no structures in range, and we have a large attack force; check if we're faster
                                                                    local iPossibleEnemySpeed = M27Logic.GetUnitMinSpeed(oPlatoon[reftEnemiesInRange], aiBrain, true)
                                                                    if iPossibleEnemySpeed == nil then
                                                                        --Dont know how fast any of the enemy is, so dont chase
                                                                        bDontChaseEnemy = true
                                                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionForNearbyEnemies - Large attack AI - dont know enemy speed, wont chase') end
                                                                    else
                                                                        local iOurMinSpeed = M27Logic.GetUnitMinSpeed(oPlatoon[reftCurrentUnits], aiBrain, false)
                                                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionForNearbyEnemies - Large attack AI - Know enemy speed, iOurMinSpeed='..iOurMinSpeed..'; iPossibleEnemySpeed='..iPossibleEnemySpeed) end
                                                                        if iOurMinSpeed < iPossibleEnemySpeed then bDontChaseEnemy = true end
                                                                    end
                                                                end
                                                            end
                                                        end
                                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionForNearbyEnemies - Large attack AI - bDontChaseEnemy='..tostring(bDontChaseEnemy)) end
                                                        if bDontChaseEnemy == false then oPlatoon[refiCurrentAction] = refActionAttack end
                                                    else
                                                        --Raider AI/small platoons - dont want to attack structures unless we're a larger raiding group since will spend too long trying to kill a mex
                                                        if oPlatoon[refbACUInPlatoon] == false and oPlatoon[refiCurrentUnits] < aiBrain[M27Overseer.refiIgnoreMexesUntilThisManyUnits] then
                                                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': MexRaider custom: refiCurrentUnits='..oPlatoon[refiCurrentUnits]) end
                                                            if oPlatoon[refiCurrentUnits] >= 5 then
                                                                oPlatoon[refiCurrentAction] = refActionAttack
                                                            else --Smaller platoon, so only attack mobile enemies and not structures:
                                                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Checking if are enemies in range') end
                                                                if oPlatoon[refiEnemiesInRange] > 0 then
                                                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': UpdateActionForNearbyEnemies iEnemiesInRange='..oPlatoon[refiEnemiesInRange]) end
                                                                    oPlatoon[refiCurrentAction] = refActionAttack
                                                                end
                                                            end
                                                        else
                                                            --Other attack AI - just attack enemy if we'll win (dont worry about chasing small groups)
                                                            oPlatoon[refiCurrentAction] = refActionAttack
                                                        end
                                                    end
                                                else
                                                    --Do nothing - will already have assigned a run away command in a previous cycle, dont need to change things now
                                                end
                                            else
                                                --Will lose attack - run
                                                oPlatoon[refiCurrentAction] = refActionRun
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        else
            oPlatoon[refiPrevNearestEnemyDistance] = nil
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function MergeNearbyPlatoons(oBasePlatoon)
--Merges nearby platoons, and updates current platoons current units
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MergeNearbyPlatoons'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oPlatoonToMergeInto
    if oBasePlatoon[M27PlatoonTemplates.refbAmalgamateIntoEscort] then oPlatoonToMergeInto = oBasePlatoon[refoEscortingPlatoon]
    else oPlatoonToMergeInto = oBasePlatoon end
    if oPlatoonToMergeInto then
        if bDebugMessages == true then LOG(sFunctionRef..': '..oPlatoonToMergeInto:GetPlan()..oPlatoonToMergeInto[refiPlatoonCount]..': Start of code') end
        local iMergeRefreshPoint = 15 --Once get to the xth cycle will refresh
        local refiMergeCycleCount = 'M27MergeCycleCount'
        local bHavePlatoonToMergeInto
        local iMergeCycleCount = oPlatoonToMergeInto[refiMergeCycleCount]
        if iMergeCycleCount == nil then iMergeCycleCount = 1
        else iMergeCycleCount = iMergeCycleCount + 1 end


        if iMergeCycleCount >= iMergeRefreshPoint then
            local iMaxGroundPlatoonSize = oPlatoonToMergeInto[M27PlatoonTemplates.refiPlatoonAmalgamationMaxSize]
            if iMaxGroundPlatoonSize == nil then
                M27Utilities.ErrorHandler('No max size specified for amalgamation - will default to 10')
                iMaxGroundPlatoonSize = 10
            end
            if oPlatoonToMergeInto[refiCurrentUnits] < iMaxGroundPlatoonSize then
                local aiBrain = oPlatoonToMergeInto:GetBrain()
                local iSearchDistance = oPlatoonToMergeInto[M27PlatoonTemplates.refiPlatoonAmalgamationRange]
                local tMergeIntoPlatoonPosition = GetPlatoonFrontPosition(oPlatoonToMergeInto)
                if M27Utilities.IsTableEmpty(tMergeIntoPlatoonPosition) == false then
                    local tCurPlatoonPos, iCurDistance
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': '..oPlatoonToMergeInto:GetPlan()..oPlatoonToMergeInto[refiPlatoonCount]..': About to check for nearby platoons to merge into this; drawing circle for merge range of '..iSearchDistance)
                        M27Utilities.DrawLocation(tMergeIntoPlatoonPosition, false, 2, 20, iSearchDistance)
                    end
                    --Cycle through all platoons, see if any of the desired type, and if so if they're close enough to this platoon
                    if M27Utilities.IsTableEmpty(oPlatoonToMergeInto[M27PlatoonTemplates.reftPlatoonsToAmalgamate]) == false then
                        local tAllPlatoons = aiBrain:GetPlatoonsList()
                        local sCurPlan, bMergePlatoon
                        for iPlatoon, oPlatoon in tAllPlatoons do
                            bMergePlatoon = false
                            if oPlatoon.GetPlan then
                                if bDebugMessages == true then LOG(sFunctionRef..':'..oPlatoonToMergeInto:GetPlan()..oPlatoonToMergeInto[refiPlatoonCount]..': Found a possible platoon, iPlatoon='..iPlatoon..'; platoon name='..oPlatoon:GetPlan()) end
                                if not(oPlatoon == oPlatoonToMergeInto) then
                                    if not(oPlatoon[refiCurrentAction] == refActionDisband) then
                                        sCurPlan = oPlatoon:GetPlan()
                                        if bDebugMessages == true then LOG(sFunctionRef..':'..oPlatoonToMergeInto:GetPlan()..oPlatoonToMergeInto[refiPlatoonCount]..'iPlatoon='..iPlatoon..'; sCurPlan='..sCurPlan..' About to see if platoon plan is one of the ones we can merge into') end
                                        for iMergeType, sMergePlan in oPlatoonToMergeInto[M27PlatoonTemplates.reftPlatoonsToAmalgamate] do
                                            if bDebugMessages == true then LOG('Currently looking to see if its equal to sMergePlan='..sMergePlan) end
                                            if sCurPlan == sMergePlan then
                                                bMergePlatoon = true break
                                            end
                                        end
                                    end
                                end
                            end

                            if bMergePlatoon == true then
                                tCurPlatoonPos = GetPlatoonFrontPosition(oPlatoon)
                                if M27Utilities.IsTableEmpty(tCurPlatoonPos) == false then
                                    iCurDistance = M27Utilities.GetDistanceBetweenPositions(tCurPlatoonPos, tMergeIntoPlatoonPosition)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef..': '..oPlatoonToMergeInto:GetPlan()..oPlatoonToMergeInto[refiPlatoonCount])
                                        LOG('(cont): Found a valid platoon to merge into this one, iPlatoon='..iPlatoon..'; platoon name='..oPlatoon:GetPlan()..'; Checking distance, iCurDistance='..iCurDistance)
                                    end
                                    if iCurDistance <= iSearchDistance then
                                        MergePlatoons(oPlatoonToMergeInto, oPlatoon)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            iMergeCycleCount = 0
        end
        oPlatoonToMergeInto[refiMergeCycleCount] = iMergeCycleCount
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)

    --(Decided wont update platoon unit data this cycle, as if wait then next cycle it will force a refresh due to the change in units)
end

function DoesPlatoonStillHaveSupportTarget(oPlatoon)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DoesPlatoonStillHaveSupportTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bStillHaveTarget = true

    if bDebugMessages == true then LOG(sFunctionRef..': '..oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]..': Start of code') end

    if not(oPlatoon[refoSupportHelperUnitTarget]) and not(oPlatoon[refoSupportHelperPlatoonTarget]) and not(oPlatoon[refoPlatoonOrUnitToEscort]) then
        if bDebugMessages == true then LOG(sFunctionRef..': Dont have a valid unit or platoon target') end
        bStillHaveTarget = false
    else
        if oPlatoon[refoSupportHelperPlatoonTarget] or oPlatoon[refoPlatoonOrUnitToEscort] then
            bStillHaveTarget = false
            local aiBrain = oPlatoon:GetBrain()
            local bPlatoonStillExists = false
            local oTargetPlatoon
            if bDebugMessages == true then LOG(sFunctionRef..': Have a helperplatoon target or a platoon/unit to escort, will check if theyre still valid') end
            if oPlatoon[refoSupportHelperPlatoonTarget] and aiBrain:PlatoonExists(oPlatoon[refoSupportHelperPlatoonTarget]) then
                bPlatoonStillExists = true
                oTargetPlatoon = oPlatoon[refoSupportHelperPlatoonTarget]
            elseif oPlatoon[refoPlatoonOrUnitToEscort] and M27PlatoonFormer.PlatoonOrUnitNeedingEscortIsStillValid(aiBrain, oPlatoon[refoPlatoonOrUnitToEscort]) == true then
                bPlatoonStillExists = true
                oTargetPlatoon = oPlatoon[refoPlatoonOrUnitToEscort]
            end
            if bDebugMessages == true then LOG(sFunctionRef..': bPlatoonStillExists='..tostring(bPlatoonStillExists)) end
            if bPlatoonStillExists == true then
                --Check it has units in it
                if oTargetPlatoon.GetPlan and oTargetPlatoon.GetPlatoonPosition then
                    if oTargetPlatoon[refiCurrentUnits] > 0 or M27Utilities.IsTableEmpty(oTargetPlatoon:GetPlatoonUnits()) == false then
                        bStillHaveTarget = true
                    end
                else
                    --Are we dealing with a unit?
                    if oTargetPlatoon.GetUnitId then
                        bStillHaveTarget = true --Alreayd checked if dead as part of PlatoonOrUnitNeedingEscortIsStillValid
                    end
                end
                --[[if bPlatoonStillExists == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have a platoon target and it either has units or no prev actionbut platoon either doesnt exist or doesnt have any current units, will make sure platoon has no units in it') end
                    bStillHaveTarget = true
                    if not(oTargetPlatoon.GetPlan) or not(oTargetPlatoon.GetPlatoonPosition) then M27Utilities.ErrorHandler('Have a target platoon but it doesnt have a plan and/or platoon position')
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Platoon does exist and has a plan') end
                        local tTargetPlatoonUnits = oTargetPlatoon:GetPlatoonUnits()
                        if M27Utilities.IsTableEmpty(tTargetPlatoonUnits) == false then
                            for iUnit, oUnit in tTargetPlatoonUnits do
                                if not(oUnit.Dead) and oUnit.GetUnitId then
                                    if M27Utilities.IsTableEmpty(oPlatoon[refoSupportHelperPlatoonTarget][reftCurrentUnits]) == true then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Will temporarily update the supporting platoon unit details to record the first alive unit') end
                                        oPlatoon[refoSupportHelperPlatoonTarget][reftCurrentUnits] = {}
                                        oPlatoon[refoSupportHelperPlatoonTarget][reftCurrentUnits][1] = oUnit
                                        oPlatoon[refoSupportHelperPlatoonTarget][refiCurrentUnits] = 1
                                        break
                                    else
                                        M27Utilities.ErrorHandler('Target platoon has current units in a table, but no value for how many current units it has')
                                    end
                                end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': Platoon has units in it, so may just be a delay with setting the curunits value') end
                            bStillHaveTarget = true
                        end
                    end
                end--]]
            end
        elseif oPlatoon[refoSupportHelperUnitTarget].Dead == true then
            if bDebugMessages == true then
                LOG(sFunctionRef..': Were trying to help a unit but that unit is dead now')
                LOG(sFunctionRef..': Unit ID that were trying to help='..oPlatoon[refoSupportHelperUnitTarget]:GetUnitId())
                local iUniqueCount = M27UnitInfo.GetUnitLifetimeCount(oPlatoon[refoSupportHelperUnitTarget])
                LOG(sFunctionRef..': Unit count that were trying to help='..iUniqueCount)
                if oPlatoon[refoSupportHelperUnitTarget] == M27Utilities.GetACU(oPlatoon:GetBrain()) then
                    LOG(sFunctionRef..': Were trying to help ACU; ACU.Dead='..tostring(M27Utilities.GetACU(oPlatoon:GetBrain()).Dead))
                    M27Utilities.ErrorHandler('Assisting unit but that unit is dead and is an ACU')
                end
            end
            bStillHaveTarget = false
        end

        if bDebugMessages == true then
            LOG(sFunctionRef..': bStillHaveTarget='..tostring(bStillHaveTarget))
            if bStillHaveTarget == true then
                local iHelperUnitCount = M27UnitInfo.GetUnitLifetimeCount(oPlatoon[refoSupportHelperUnitTarget])
                if oPlatoon[refoSupportHelperUnitTarget] then LOG(sFunctionRef..': refoSupportHelperUnitTarget='..oPlatoon[refoSupportHelperUnitTarget]:GetUnitId()..iHelperUnitCount) end
                if oPlatoon[refoSupportHelperPlatoonTarget] then LOG(sFunctionRef..': refoSupportHelperPlatoonTarget='..oPlatoon[refoSupportHelperPlatoonTarget]:GetPlan()..oPlatoon[refoSupportHelperPlatoonTarget][refiPlatoonCount]) end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, bStillHaveTarget='..tostring(bStillHaveTarget)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bStillHaveTarget
end

function UpdateEscortDetails(oPlatoonOrUnitToBeEscorted)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateEscortDetails'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local sPlatoonName, aiBrain
    local bAbort = false
    if oPlatoonOrUnitToBeEscorted.GetUnitId then
        if oPlatoonOrUnitToBeEscorted.Dead then bAbort = true
        else
            sPlatoonName = oPlatoonOrUnitToBeEscorted:GetUnitId()
            aiBrain = oPlatoonOrUnitToBeEscorted:GetAIBrain()
        end
    else
        sPlatoonName = oPlatoonOrUnitToBeEscorted:GetPlan()
        aiBrain = oPlatoonOrUnitToBeEscorted:GetBrain()
    end

    if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..oPlatoonOrUnitToBeEscorted[refiPlatoonCount]..': Start of function, Updating details for platoon; bAbort='..tostring(bAbort)) end
    if bAbort == false then
        local iEscortSizeDefaultFactor = 1
        local bEscortingLowHealthACU = false
        if oPlatoonOrUnitToBeEscorted[refbACUInPlatoon] and M27Utilities.GetACU(aiBrain):GetHealthPercent() <= M27Overseer.iACUEmergencyHealthPercentThreshold then bEscortingLowHealthACU = true end
        local oEscortingPlatoon = oPlatoonOrUnitToBeEscorted[refoEscortingPlatoon]
        --Get larger escort if we're escorting the ACU (factor in nearby enemies and ACU upgrades when deciding how large an escort to send)
        if bEscortingLowHealthACU then oPlatoonOrUnitToBeEscorted[refiEscortThreatWanted] = 100000
        else

            if oPlatoonOrUnitToBeEscorted[refbACUInPlatoon] then
                oPlatoonOrUnitToBeEscorted[refiEscortThreatWanted] = math.max(2000, oPlatoonOrUnitToBeEscorted[refiPlatoonMassValue] * iEscortSizeDefaultFactor, M27Logic.GetCombatThreatRating(aiBrain, {M27Utilities.GetACU(aiBrain)}, false, nil, nil, false, false))
                if oPlatoonOrUnitToBeEscorted[refiEnemiesInRange] > 0 then
                    oPlatoonOrUnitToBeEscorted[refiEscortThreatWanted] = math.max(oPlatoonOrUnitToBeEscorted[refiEscortThreatWanted], M27Logic.GetCombatThreatRating(aiBrain, oPlatoonOrUnitToBeEscorted[reftEnemiesInRange]))
                end
            else oPlatoonOrUnitToBeEscorted[refiEscortThreatWanted] = oPlatoonOrUnitToBeEscorted[refiPlatoonMassValue] * iEscortSizeDefaultFactor end
        end

        oPlatoonOrUnitToBeEscorted[refiCurrentEscortThreat] = 0
        if bDebugMessages == true then
            LOG(sFunctionRef..': oPlatoonOrUnitToBeEscorted[refiEscortThreatWanted]='..oPlatoonOrUnitToBeEscorted[refiEscortThreatWanted]..'; oPlatoonOrUnitToBeEscorted[refiPlatoonMassValue]='..oPlatoonOrUnitToBeEscorted[refiPlatoonMassValue]..'; iEscortSizeDefaultFactor='..iEscortSizeDefaultFactor)
            if oEscortingPlatoon then
                LOG('Have escorting platoon with plan, will check its threat. oPlatoonOrUnitToBeEscorted[refiEscortThreatWanted]='..oPlatoonOrUnitToBeEscorted[refiEscortThreatWanted])
                if oEscortingPlatoon[refiPlatoonThreatValue] then
                    LOG('Escorting platoon threat value='..oEscortingPlatoon[refiPlatoonThreatValue])
                end
            end
        end
        if oEscortingPlatoon and oEscortingPlatoon[refiPlatoonThreatValue] then
            if oEscortingPlatoon[refiPlatoonThreatValue] - oPlatoonOrUnitToBeEscorted[refiEscortThreatWanted] > 60 and oEscortingPlatoon[refiPlatoonThreatValue] > oPlatoonOrUnitToBeEscorted[refiEscortThreatWanted] * 1.5 then
                if aiBrain:PlatoonExists(oEscortingPlatoon) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Threat value of escorting platoon pre removal of spare units='..oEscortingPlatoon[refiPlatoonThreatValue]) end
                    M27Overseer.RemoveSpareUnits(oEscortingPlatoon, oPlatoonOrUnitToBeEscorted[refiEscortThreatWanted] * 1.2, 0, 0, nil, true)
                end
            end
            --The remove units from platoon function includes an update of the platoon values so the platoon threat value should be updated now:
            oPlatoonOrUnitToBeEscorted[refiCurrentEscortThreat] = oEscortingPlatoon[refiPlatoonThreatValue]
            if bDebugMessages == true then LOG(sFunctionRef..': Threat value of escorting platoon='..oPlatoonOrUnitToBeEscorted[refiCurrentEscortThreat]) end

        end
        if oPlatoonOrUnitToBeEscorted[refiNeedingEscortUniqueCount] == nil then
            if aiBrain[refiNeedingEscortUniqueCount] == nil then
                aiBrain[refiNeedingEscortUniqueCount] = 1
                aiBrain[reftPlatoonsOrUnitsNeedingEscorts] = {}
            else aiBrain[refiNeedingEscortUniqueCount] = aiBrain[refiNeedingEscortUniqueCount] + 1
            end
            oPlatoonOrUnitToBeEscorted[refiNeedingEscortUniqueCount] = aiBrain[refiNeedingEscortUniqueCount]
            aiBrain[reftPlatoonsOrUnitsNeedingEscorts][oPlatoonOrUnitToBeEscorted[refiNeedingEscortUniqueCount]] = oPlatoonOrUnitToBeEscorted
        end
        if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..oPlatoonOrUnitToBeEscorted[refiPlatoonCount]..': End of function, oPlatoonOrUnitToBeEscorted[refiNeedingEscortUniqueCount]='..oPlatoonOrUnitToBeEscorted[refiNeedingEscortUniqueCount]..'; size of aibrain of tables='..table.getn(aiBrain[reftPlatoonsOrUnitsNeedingEscorts])) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordPlatoonUnitsByType(oPlatoon, bPlatoonIsAUnit)
    --Update oPlatoon's unittable and count variables

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordPlatoonUnitsByType'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local sPlatoonName, aiBrain
    local bAbort = false
    if bPlatoonIsAUnit == true then
        if oPlatoon.GetUnitId and not(oPlatoon.Dead) then
            sPlatoonName = oPlatoon:GetUnitId()
            aiBrain = oPlatoon:GetAIBrain()
            oPlatoon[refiPlatoonCount] = oPlatoon.M27LifetimeUnitCount
            if oPlatoon[refiPlatoonCount] == nil then oPlatoon[refiPlatoonCount] = 0 end
        else
            bAbort = true
        end
    else sPlatoonName = oPlatoon:GetPlan()
        aiBrain = oPlatoon:GetBrain()
    end
    if oPlatoon[refiPlatoonCount] == nil then
        if aiBrain[refiLifetimePlatoonCount][sPlatoonName] == nil then aiBrain[refiLifetimePlatoonCount][sPlatoonName] = 1
        else aiBrain[refiLifetimePlatoonCount][sPlatoonName] = aiBrain[refiLifetimePlatoonCount][sPlatoonName] + 1 end
        oPlatoon[refiPlatoonCount] = aiBrain[refiLifetimePlatoonCount][sPlatoonName]
    end

    if bDebugMessages == true then LOG(sFunctionRef..sPlatoonName..oPlatoon[refiPlatoonCount]..': Start of code') end
    --if sPlatoonName == 'M27ACUMain' then bDebugMessages = true end
    --if sPlatoonName == 'M27IndirectDefender' then bDebugMessages = true end
    --if sPlatoonName == 'M27CombatPatrolAI' then bDebugMessages = true end
    --if sPlatoonName == 'M27EscortAI' then bDebugMessages = true end
    --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end

    local oPathingUnit
    if bAbort == false then
        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..':bAbort isnt true, so starting to RecordPlatoonUnitsByType') end
        --store previous number for current units (for efficiency purposes):
        if oPlatoon[refiCurrentUnits] == nil then oPlatoon[refiCurrentUnits] = 0 end
        oPlatoon[refiPrevCurrentUnits] = oPlatoon[refiCurrentUnits]
        --Update list of current units:
        if bPlatoonIsAUnit then
            oPlatoon[reftCurrentUnits] = {oPlatoon}
        else
            oPlatoon[reftCurrentUnits] = oPlatoon:GetPlatoonUnits()
        end
        if oPlatoon[reftCurrentUnits] == nil then
            oPlatoon[refiCurrentUnits] = 0
            oPlatoon[refbACUInPlatoon] = false
            oPlatoon[refbCombatHoverInPlatoon] = false
            oPlatoon[refiPlatoonMassValue] = 0
            oPlatoon[refiPlatoonThreatValue] = 0
            oPlatoon[refiCurrentAction] = refActionDisband
            if bDebugMessages == true then LOG(sFunctionRef..': Platoon with plan='..sPlatoonName..' has no units in it so disbanding') end
        else
            if M27Utilities.IsTableEmpty(oPlatoon[reftCurrentUnits]) == true then
                oPlatoon[refiCurrentUnits] = 0
                oPlatoon[refbACUInPlatoon] = false
                oPlatoon[refbCombatHoverInPlatoon] = false
                oPlatoon[refiPlatoonMassValue] = 0
                oPlatoon[refiPlatoonThreatValue] = 0
                oPlatoon[refiCurrentAction] = refActionDisband
                if bDebugMessages == true then LOG(sFunctionRef..': Platoon with name='..sPlatoonName..': units is an empty table so disbanding') end
            else
                --Check for friendly platoons to merge into this one (done every 5 cycles for optimisation purposes):
                if oPlatoon[M27PlatoonTemplates.refiPlatoonAmalgamationRange] then MergeNearbyPlatoons(oPlatoon) end
                local tACUs = EntityCategoryFilterDown(categories.COMMAND, oPlatoon[reftCurrentUnits])
                local bACUInPlatoon = false
                if not(M27Utilities.IsTableEmpty(tACUs)) then
                    local oACU = M27Utilities.GetACU(aiBrain)
                    for iUnit, oUnit in tACUs do
                        if oUnit == oACU then
                            bACUInPlatoon = true
                            break
                        end
                    end
                end
                oPlatoon[refbACUInPlatoon] = bACUInPlatoon
                if bACUInPlatoon then oPlatoon[refiReclaimers] = 1 end --Default, as later on the code will treat us as not having any reclaimers if there are nearby enemies
                oPlatoon[refiCurrentUnits] = table.getn(oPlatoon[reftCurrentUnits])
                --Update list of units by type if current unit number has changed or we have dead units in platoon
                local bUpdateByUnitType = false
                if oPlatoon[refiPrevCurrentUnits] == nil then bUpdateByUnitType = true
                elseif not(oPlatoon[refiPrevCurrentUnits] == oPlatoon[refiCurrentUnits]) then bUpdateByUnitType = true
                end

                if bUpdateByUnitType == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': Refreshing details of units in platoon as the number of units has changed') end
                    if oPlatoon[refiPrevCurrentUnits] < oPlatoon[refiCurrentUnits] then
                        if bDebugMessages == true then LOG(sFunctionRef..': Units in platoon has increased so refreshing platoon action') end
                        oPlatoon[refbForceActionRefresh] = true end
                    oPlatoon[reftDFUnits] = EntityCategoryFilterDown(categories.DIRECTFIRE - categories.SCOUT, oPlatoon[reftCurrentUnits])
                    oPlatoon[reftScoutUnits] = EntityCategoryFilterDown(categories.SCOUT, oPlatoon[reftCurrentUnits])
                    oPlatoon[reftIndirectUnits] = EntityCategoryFilterDown(categories.INDIRECTFIRE, oPlatoon[reftCurrentUnits])
                    oPlatoon[reftBuilders] = EntityCategoryFilterDown(categories.CONSTRUCTION, oPlatoon[reftCurrentUnits])
                    oPlatoon[reftReclaimers] = EntityCategoryFilterDown(categories.RECLAIM, oPlatoon[reftCurrentUnits])
                    oPlatoon[reftUnitsWithShields] = EntityCategoryFilterDown(M27UnitInfo.refCategoryMobileLandShield + M27UnitInfo.refCategoryPersonalShield, oPlatoon[reftCurrentUnits])
                    if oPlatoon[reftDFUnits] == nil then
                        oPlatoon[refiDFUnits] = 0
                        oPlatoon[refbCombatHoverInPlatoon] = false
                    else
                        oPlatoon[refiDFUnits] = table.getn(oPlatoon[reftDFUnits])
                        oPlatoon[refbCombatHoverInPlatoon] = not(M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.HOVER, oPlatoon[reftDFUnits])))
                    end
                    if oPlatoon[reftScoutUnits] == nil then oPlatoon[refiScoutUnits] = 0
                    else oPlatoon[refiScoutUnits] = table.getn(oPlatoon[reftScoutUnits]) end
                    if oPlatoon[reftIndirectUnits] == nil then oPlatoon[refiIndirectUnits] = 0
                    else oPlatoon[refiIndirectUnits] = table.getn(oPlatoon[reftIndirectUnits]) end
                    if oPlatoon[reftBuilders] == nil then oPlatoon[refiBuilders] = 0
                    else oPlatoon[refiBuilders] = table.getn(oPlatoon[reftBuilders]) end
                    if oPlatoon[reftReclaimers] == nil then oPlatoon[refiReclaimers] = 0
                    else oPlatoon[refiReclaimers] = table.getn(oPlatoon[reftReclaimers]) end
                    if oPlatoon[reftUnitsWithShields] == nil then oPlatoon[refiUnitsWithShields] = 0 else oPlatoon[refiUnitsWithShields] = table.getn(oPlatoon[reftUnitsWithShields]) end
                    --GetCombatThreatRating(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, iMassValueOfBlipsOverride, iSoloBlipMassOverride, bIndirectFireThreatOnly, bJustGetMassValue)
                    oPlatoon[refiPlatoonThreatValue] = M27Logic.GetCombatThreatRating(aiBrain, oPlatoon[reftCurrentUnits], nil, nil)
                    oPlatoon[refiPlatoonMassValue] = M27Logic.GetCombatThreatRating(aiBrain, oPlatoon[reftCurrentUnits], nil, nil, false, false, true)
                    --[[if oPlatoon[refbShouldHaveEscort] then oPlatoon[refiPlatoonMassValue] = M27Logic.GetCombatThreatRating(aiBrain, oPlatoon[reftCurrentUnits], nil, nil, false, false, true)
                    else oPlatoon[refiPlatoonMassValue] = oPlatoon[refiPlatoonThreatValue] end--]]
                    if bDebugMessages == true then LOG(sFunctionRef..': Just got mass value for platoon='..oPlatoon[refiPlatoonMassValue]..'; oPlatoon[refbShouldHaveEscort]='..tostring(oPlatoon[refbShouldHaveEscort])) end


                    --Does the platoon contain underwater or overwater land units? (for now assumes will only have 1 or the other)
                    if oPlatoon[refiCurrentUnits] > 0 then

                        if oPlatoon[refiDFUnits] > 0 then
                            if oPlatoon[reftPlatoonDFTargettingCategories] == nil then oPlatoon[reftPlatoonDFTargettingCategories] = M27UnitInfo.refWeaponPriorityNormal end
                            for iUnit, oUnit in oPlatoon[reftDFUnits] do
                                M27UnitInfo.SetUnitTargetPriorities(oUnit, oPlatoon[reftPlatoonDFTargettingCategories])
                            end
                        end
                        if bPlatoonIsAUnit == true then oPathingUnit = oPlatoon
                        else
                            oPathingUnit = GetPathingUnit(oPlatoon)
                        end
                        if oPathingUnit == nil or oPathingUnit.Dead then
                            --all units must be dead if not got a valid pathing unit
                            oPlatoon[refiCurrentAction] = refActionDisband
                            if bDebugMessages == true then LOG(sFunctionRef..': Pathing unit nil or dead so disbanding') end
                        else
                            oPlatoon[refbPlatoonHasUnderwaterLand] = false
                            oPlatoon[refbPlatoonHasOverwaterLand] = false
                            if not(oPathingUnit.Dead) then
                                local sPathingType = M27UnitInfo.GetUnitPathingType(oPathingUnit)
                                if sPathingType == M27UnitInfo.refPathingTypeAmphibious then
                                    for iUnit, oUnit in oPlatoon[reftCurrentUnits] do
                                        if M27UnitInfo.IsUnitUnderwaterAmphibious(oUnit) == true then
                                            oPlatoon[refbPlatoonHasUnderwaterLand] = true
                                            break
                                        else
                                            oPlatoon[refbPlatoonHasOverwaterLand] = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': iBuilders='..oPlatoon[refiBuilders]..'; iReclaimers='..oPlatoon[refiReclaimers]) end

                    --Get the front unit in the platoon
                    oPlatoon[refoFrontUnit] = M27Logic.GetUnitNearestEnemy(aiBrain, oPlatoon[reftCurrentUnits])
                    oPlatoon[refoRearUnit] = M27Utilities.GetNearestUnit(oPlatoon[reftCurrentUnits], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain, false)
                    oPlatoon[refiFrontUnitRefreshCount] = 0
                    oPlatoon[refiRearUnitRefreshCount] = 0
                else
                    if not(oPlatoon[refoPathingUnit]) or oPlatoon[refoPathingUnit].Dead then oPathingUnit = GetPathingUnit(oPlatoon) else oPathingUnit = oPlatoon[refoPathingUnit] end
                    --No change in platoon units so no need to refresh most variables (other than the front unit if it's been a while since the last refresh)
                    if oPlatoon[refoFrontUnit] and not(oPlatoon[refoFrontUnit].Dead) and oPlatoon[refoFrontUnit].GetUnitId and oPlatoon[refiFrontUnitRefreshCount] <= 9 then
                        --No need to refresh front unit
                        oPlatoon[refiFrontUnitRefreshCount] = oPlatoon[refiFrontUnitRefreshCount] + 1
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Refreshing front unit; refiCurrentUnits='..oPlatoon[refiCurrentUnits]) end
                        if oPlatoon[refiCurrentUnits] > 0 then
                            oPlatoon[refoFrontUnit] = M27Logic.GetUnitNearestEnemy(aiBrain, oPlatoon[reftCurrentUnits])
                            oPlatoon[refiFrontUnitRefreshCount] = 0
                        end
                    end
                    if oPlatoon[refoRearUnit] and not(oPlatoon[refoRearUnit].Dead) and oPlatoon[refoRearUnit].GetUnitId and oPlatoon[refiRearUnitRefreshCount] <= 9 then
                        --No need to refresh front unit
                        oPlatoon[refiRearUnitRefreshCount] = oPlatoon[refiRearUnitRefreshCount] + 1
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Refreshing front unit; refiCurrentUnits='..oPlatoon[refiCurrentUnits]) end
                        if oPlatoon[refiCurrentUnits] > 0 then
                            oPlatoon[refoRearUnit] = M27Utilities.GetNearestUnit(oPlatoon[reftCurrentUnits], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain, false)
                            oPlatoon[refiRearUnitRefreshCount] = 0
                        end
                    end
                end
                --Update flag for if special micro active
                if M27Utilities.IsTableEmpty(oPlatoon[reftCurrentUnits]) == false then
                    local bActiveMicro = false
                    local bOldMicroFlag = oPlatoon[M27UnitInfo.refbSpecialMicroActive]

                    for iUnit, oUnit in oPlatoon[reftCurrentUnits] do
                        if oUnit[M27UnitInfo.refbSpecialMicroActive] then bActiveMicro = true break end
                    end
                    oPlatoon[M27UnitInfo.refbSpecialMicroActive] = bActiveMicro
                    if bOldMicroFlag and not(bActiveMicro) then ForceActionRefresh(oPlatoon, 2) end
                end

                if oPlatoon[refoFrontUnit] then
                    oPlatoon[reftFrontPosition] = oPlatoon[refoFrontUnit]:GetPosition()
                else
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Platoon has no valid front unit so will record our start position as the front position') end
                    oPlatoon[reftFrontPosition] = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                end
                if oPlatoon[refoRearUnit] then
                    oPlatoon[reftRearPosition] = oPlatoon[refoRearUnit]:GetPosition()
                else
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Platoon has no valid rear unit so will record our start position as the rear position') end
                    oPlatoon[reftRearPosition] = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                end
                if oPlatoon[refoFrontUnit] and oPathingUnit and M27UnitInfo.GetUnitPathingType(oPlatoon[refoFrontUnit]) == M27UnitInfo.GetUnitPathingType(oPathingUnit) then
                    oPlatoon[refoPathingUnit] = oPathingUnit
                else
                    if oPathingUnit then oPlatoon[refoPathingUnit] = oPathingUnit end
                end
                if bDebugMessages == true then
                    M27Utilities.DrawLocation(oPlatoon[reftFrontPosition], nil, 2, 50)
                    if oPlatoon[refoFrontUnit] then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..'RecordPlatoonUnitsByType: end of code; oPlatoon[reftFrontPosition]='..repr(oPlatoon[reftFrontPosition])..'; oPlatoon[refoFrontUnit]='..oPlatoon[refoFrontUnit]:GetUnitId()..'; iCurrentUnits='..oPlatoon[refiCurrentUnits]..'; iDFUnits='..oPlatoon[refiDFUnits]..'; iScouts='..oPlatoon[refiScoutUnits]..'; iArti='..oPlatoon[refiIndirectUnits]) end
                else if bDebugMessages == true then LOG(sPlatoonName..': No front unit exists') end
                end
                if bDebugMessages == true then
                    if oPlatoon[reftReclaimers] == nil then LOG('tReclaimers is nil')
                    else LOG('tReclaimers size='..table.getn(oPlatoon[reftReclaimers])) end
                    if oPlatoon[reftBuilders] == nil then LOG('tReclaimers is nil')
                    else LOG('tBuilders size='..table.getn(oPlatoon[reftBuilders])) end
                end

                --Update details of any escorts
                if bDebugMessages == true then LOG(sFunctionRef..': About to update escort details if flagged to have escort; oPlatoon[refbShouldHaveEscort]='..tostring(oPlatoon[refbShouldHaveEscort])) end
                if oPlatoon[refbShouldHaveEscort] == true then UpdateEscortDetails(oPlatoon) end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DetermineActionForNearbyMex(oPlatoon)
    --Double-check we can still build a mex
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DetermineActionForNearbyMex'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': About to check have builders in platoon and get first builder') end
    if oPlatoon[refiBuilders] > 0 then
        local oFirstBuilder
        for _, oBuilder in oPlatoon[reftBuilders] do
            if not(oBuilder.Dead) then
                oFirstBuilder = oBuilder break
            end
        end
        if not(oFirstBuilder==nil) then
            --If we dont have enough power, limit the number of mexes we get
            local bHaveEnoughPower = false

            local aiBrain = oPlatoon:GetBrain()
            if not(M27Utilities.IsACU(oFirstBuilder)) or not(M27Conditions.DoesACUHaveBigGun(aiBrain)) then
                --Early game: Only build max 1 mex if no nearby hydro, max 3 mex if nearby Hydro, until have got hydro/power in place
                if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 11 then bHaveEnoughPower = true
                elseif M27Conditions.HydroNearACUAndBase(aiBrain, true, false) then
                    if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT1Mex) < 3 then bHaveEnoughPower = true end
                elseif aiBrain:GetEconomyIncome('MASS') <= 0.2 then bHaveEnoughPower = true
                end
                if bHaveEnoughPower == true then

                    --Are there any unclaimed mexes nearby:
                    --GetNearestMexToUnit(oBuilder, bCanBeBuiltOnByAlly, bCanBeBuiltOnByEnemy, bCanBeQueuedToBeBuilt, iMaxSearchRangeMod, tStartPositionOverride, tMexesToIgnore)
                    local tNearbyMex = M27MapInfo.GetNearestMexToUnit(oFirstBuilder, false, false, true, M27Overseer.iACUMaxTravelToNearbyMex) --allows a slight detour from current position
                    if bDebugMessages == true then
                        if M27Utilities.IsTableEmpty(tNearbyMex) then LOG(sFunctionRef..': tNearbyMex is empty')
                            else LOG(sFunctionRef..': tNearbyMex='..repr(tNearbyMex)) end
                    end
                    if M27Utilities.IsTableEmpty(tNearbyMex) == false then
                        oPlatoon[refiCurrentAction] = refActionBuildMex
                        if oPlatoon[reftNearbyMexToBuildOn] == nil then oPlatoon[reftNearbyMexToBuildOn] = {} end
                        oPlatoon[reftNearbyMexToBuildOn] = tNearbyMex
                        if bDebugMessages == true then LOG(sFunctionRef..': Have updated for nearby mex='..repr(oPlatoon[reftNearbyMexToBuildOn])) end
                    end
                end
            end
        else
            oPlatoon[refiBuilders] = 0
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DetermineIfACUShouldBuildPower(oPlatoon)
    local sFunctionRef = 'DetermineIfACUShouldBuildPower'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Only call if ACU in platoon
    if oPlatoon:GetPlan() == 'M27ACUMain' then
        local aiBrain = oPlatoon:GetBrain()
        if oPlatoon[reftPrevAction] and oPlatoon[reftPrevAction][1] == refActionBuildInitialPower then
            local oACU = M27Utilities.GetACU(aiBrain)
            if oACU:IsUnitState('Building') or oACU:IsUnitState('Repairing') then
                oPlatoon[refiCurrentAction] = refActionBuildInitialPower
            end
        end
        if oPlatoon[refiCurrentAction] == nil then
            local iGrossEnergy = aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]
            if iGrossEnergy <= 11 then
                local iGameTime = GetGameTimeSeconds()
                if iGameTime <= 150 then
                    if not(M27Conditions.HydroNearACUAndBase(aiBrain, true, false)) then
                        oPlatoon[refiCurrentAction] = refActionBuildInitialPower
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DetermineIfACUShouldBuildLandFactory(oPlatoon)
    --Allows ACU to build land factory in certain cases
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DetermineIfACUShouldBuildLandFactory'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if oPlatoon[refbACUInPlatoon] == true then --Already have this in the determine platoon action function, and might want to use this function for another unit
    local aiBrain = oPlatoon:GetBrain()
    local iFactoryCount = aiBrain:GetCurrentUnits(categories.STRUCTURE * categories.FACTORY)
    if bDebugMessages == true then LOG(sFunctionRef..': About to see if want to build a land factory. EnergyIncome='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; MassNetIncome='..aiBrain:GetEconomyTrend('MASS')..'Stored energy='..aiBrain:GetEconomyStored('ENERGY')..'; StoredMass='..aiBrain:GetEconomyStored('MASS')..'; LandFactoryCount='..iFactoryCount) end

    if not(M27Conditions.DoesACUHaveBigGun(aiBrain)) then
        --Is the engineer already building and its previous action was to build a land factory or power?
        local bAlreadyBuilding = false
        local bAlreadyTryingToBuild = false
        if oPlatoon[reftPrevAction] and oPlatoon[reftPrevAction][1] == refActionBuildLandFactory then
            bAlreadyTryingToBuild = true
            local oACU = M27Utilities.GetACU(aiBrain)
            if oACU:IsUnitState('Building') or oACU:IsUnitState('Repairing') then
                oPlatoon[refiCurrentAction] = refActionBuildLandFactory
                bAlreadyBuilding = true
                oPlatoon[refbMovingToBuild] = false
            end
        end
        if bAlreadyBuilding == false then
            --do we want more factories than we already have?
            if iFactoryCount < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] then
                --Are we closer to enemy than base?
                local tCurPosition = GetPlatoonFrontPosition(oPlatoon)
                local iEnemyStartPosition = M27Logic.GetNearestEnemyStartNumber(aiBrain)
                local iDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tCurPosition, M27MapInfo.PlayerStartPoints[iEnemyStartPosition])
                local iDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tCurPosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                if bDebugMessages == true then LOG(sFunctionRef..': iDistanceToEnemy='..iDistanceToEnemy..'; iDistanceToStart='..iDistanceToStart) end
                if iDistanceToEnemy >= iDistanceToStart then
                    local iStoredEnergy = aiBrain:GetEconomyStored('ENERGY')
                    if bAlreadyTryingToBuild and iStoredEnergy >= 250 and oPlatoon[refbMovingToBuild] == true then
                        oPlatoon[refiCurrentAction] = refActionBuildLandFactory
                    else
                        if iFactoryCount < 2 then
                            if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 10 then --Have at least 100 gross energy income per second
                                if aiBrain:GetEconomyTrend('MASS') >= 0.2 then --At least 2 net mass income per second
                                    if iStoredEnergy >= 250 then
                                        if aiBrain:GetEconomyStored('MASS') >= 20 then
                                            if bDebugMessages == true then LOG(sFunctionRef..': We have the resources to build a land factory so will try to') end
                                            oPlatoon[refiCurrentAction] = refActionBuildLandFactory
                                        end
                                    end
                                end
                            end
                        elseif iFactoryCount < 4 then
                            if M27Conditions.DoesACUHaveGun(aiBrain, false, nil) == false then
                                if aiBrain:GetEconomyTrend('ENERGY') >= 5 then -->=50 energy income
                                    if aiBrain:GetEconomyStored('MASS') >= 400 then
                                        if iStoredEnergy >= 750 then
                                            if aiBrain:GetEconomyTrend('MASS') >= 0.4 then --At least 4 net mass income per second
                                                if bDebugMessages == true then LOG(sFunctionRef..': Want to build another land fac with ACU to stop overflow') end
                                                oPlatoon[refiCurrentAction] = refActionBuildLandFactory
                                            end
                                        end
                                    end
                                end
                            end
                        elseif iFactoryCount < 6 then
                            if M27Conditions.DoesACUHaveGun(aiBrain, false, nil) == false then
                                if aiBrain:GetEconomyTrend('ENERGY') >= 5 then -->=50 energy income
                                    if aiBrain:GetEconomyStored('MASS') >= 600 then
                                        if iStoredEnergy >= 1000 then
                                            if aiBrain:GetEconomyTrend('MASS') >= 0.4 then --At least 4 net mass income per second
                                                if bDebugMessages == true then LOG(sFunctionRef..': Want to build another land fac with ACU to stop overflow') end
                                                oPlatoon[refiCurrentAction] = refActionBuildLandFactory
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if oPlatoon[refiCurrentAction] then oPlatoon[refbMovingToBuild] = true end
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    --end
end

--[[function AssignACUInitialBuildOrder(oPlatoon)
    --Gives the ACU an initial build order based on what has been built
    --Initial land factory
    local aiBrain = oPlatoon:GetBrain()
    local iFactoryCount = aiBrain:GetCurrentUnits(categories.STRUCTURE * categories.FACTORY)
    local iMexCount = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT1Mex)
    local iActionToAssign
    local tTargetLocation = oACU:GetPosition()
    local bFirstAction = true
    local oACU = M27Utilities.GetACU(aiBrain)
    local iMaxInitialMex = 3
    --Initial factory
    if iFactoryCount < 1 then
        --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber)
        --AssignActionToEngineer(aiBrain, oEngineer, iActionToAssign, tActionTargetLocation, oActionTargetObject, iConditionNumber, sBuildingBPRef)
        bFirstAction = false
        iActionToAssign = M27EngineerOverseer.refActionBuildLandFactory
        M27EngineerOverseer.UpdateEngineerActionTrackers(aiBrain, oACU, iActionToAssign, tTargetLocation, false, 0)
        M27EngineerOverseer.AssignActionToEngineer(aiBrain, oACU, iActionToAssign, tTargetLocation, nil, 0)
    end
    if iMexCount < iMaxInitialMex then

    end
end --]]

function DetermineActionForNearbyHydro(oPlatoon)
    --Tries to assist any hydro being constructed
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DetermineActionForNearbyHydro'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iMaxDistanceToMove = M27Overseer.iACUMaxTravelToNearbyMex
    if bDebugMessages == true then LOG(sFunctionRef..': About to check have builders in platoon and get first builder') end
    if oPlatoon[refiBuilders] > 0 then
        local oFirstBuilder
        for _, oBuilder in oPlatoon[reftBuilders] do
            if not(oBuilder.Dead) then
                oFirstBuilder = oBuilder break
            end
        end
        if not(oFirstBuilder==nil) then
            --Are there any Hydro buildings nearby:

            --GetNearestMexToUnit(oBuilder, bCanBeBuiltOnByAlly, bCanBeBuiltOnByEnemy, bCanBeQueuedToBeBuilt, iMaxSearchRangeMod, tStartPositionOverride, tMexesToIgnore)
            local aiBrain = oFirstBuilder:GetAIBrain()
            local iBuildDistance = oFirstBuilder:GetBlueprint().Economy.MaxBuildDistance
            local tNearbyHydro = aiBrain:GetUnitsAroundPoint(categories.HYDROCARBON, oFirstBuilder:GetPosition(), iMaxDistanceToMove + iBuildDistance, 'Ally')
            if bDebugMessages == true then LOG(sFunctionRef..': Have a builder, seeing if nearby hydro') end
            if M27Utilities.IsTableEmpty(tNearbyHydro) == false then
                --Is this an ACU that has the gun?
                if bDebugMessages == true then LOG(sFunctionRef..': Have a nearby hydro, seeing if ACU has gun') end
                if oFirstBuilder == M27Utilities.GetACU(aiBrain) and M27Conditions.DoesACUHaveGun(aiBrain, true) == true then
                    --do nothing
                else
                    --Is the building still being constructed?
                    local oHydro = tNearbyHydro[1]
                    local tHydroLocation, sLocationRef
                    if oHydro.GetFractionComplete then
                        local iFractionComplete = oHydro:GetFractionComplete()
                        if bDebugMessages == true then LOG(sFunctionRef..': iFractionComplete='..iFractionComplete) end
                        if iFractionComplete < 1 and iFractionComplete > 0 then
                            if bDebugMessages == true then LOG(sFunctionRef..': Building started but not complete, assigning action') end
                            --Is there an engineer already building it?
                            tHydroLocation = oHydro:GetPosition()
                            sLocationRef = M27Utilities.ConvertLocationToReference(tHydroLocation)
                            if aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation] and aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionBuildHydro]) == false then
                                for iUniqueRef, oEngi in aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionBuildHydro] do
                                    if not(oEngi.Dead) and oEngi.GetPosition then
                                        oPlatoon[refoConstructionToAssist] = oEngi
                                        break
                                    end
                                end
                                if not(oPlatoon[refoConstructionToAssist]) then
                                    M27Utilities.ErrorHandler('Tracker says engi shoudl be building hydro but no living engi could be found, will assist hydro building instead but should investigate')
                                    oPlatoon[refoConstructionToAssist] = oHydro
                                end
                            else
                                oPlatoon[refoConstructionToAssist] = oHydro
                            end
                            oPlatoon[refiCurrentAction] = refActionAssistConstruction

                        end
                    end
                end
            end
        else
            oPlatoon[refiBuilders] = 0
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DetermineActionForNearbyReclaim(oPlatoon)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DetermineActionForNearbyReclaim'

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, oPlatoon[refiReclaimers]='..oPlatoon[refiReclaimers]) end
    if oPlatoon[refiReclaimers] > 0 then
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code for '..oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]) end
        --Check we aren't full with mass
        local aiBrain = oPlatoon:GetBrain()
        local bProceed = true
        if oPlatoon[refbACUInPlatoon] and M27Conditions.DoesACUHaveBigGun(aiBrain, oPlatoon[reftReclaimers][1]) then bProceed = false end
        if bProceed then
            local iSpareStorage = (1 - aiBrain:GetEconomyStoredRatio('MASS')) * aiBrain:GetEconomyStored('MASS')

            if iSpareStorage > 50 then --v14 and earlier - was 1 as In some cases will want to finish reclaiming if are already reclaiming; v15: Changed to be 50 as approx (since reclaim at 5*buildpower, so ACU would reclaim up to 50/s)
                if bDebugMessages == true then LOG(sFunctionRef..': About to get first unit with reclaim function') end
                --if oPlatoon[refoNearbyReclaimTarget] == nil then oPlatoon[refoNearbyReclaimTarget] = {} end
                local oFirstReclaimer
                for _, oReclaimer in oPlatoon[reftReclaimers] do
                    if not(oReclaimer.Dead) then
                        oFirstReclaimer = oReclaimer break
                    end
                end
                if not(oFirstReclaimer==nil) and not(oFirstReclaimer:IsUnitState('Building')) and not(oFirstReclaimer:IsUnitState('Repairing')) then
                    --If ACU then will ahve called this before checking for nearby enemies, so check if any within 30
                    local bHaveNearbyEnemies = false
                    if oPlatoon[refiEnemyStructuresInRange] > 0 then bHaveNearbyEnemies = true
                    else
                        if oPlatoon[refbACUInPlatoon] and oPlatoon[refiEnemiesInRange] > 0 then
                            local oNearestMobileEnemy = M27Utilities.GetNearestUnit(oPlatoon[reftEnemiesInRange], GetPlatoonFrontPosition(oPlatoon), aiBrain, nil)
                            if oNearestMobileEnemy and M27Utilities.GetDistanceBetweenPositions(oNearestMobileEnemy:GetPosition(), GetPlatoonFrontPosition(oPlatoon)) <= 30 then bHaveNearbyEnemies = true end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': bHaveNearbyEnemies='..tostring(bHaveNearbyEnemies)) end
                    if bHaveNearbyEnemies == false then
                        --New approach for v14
                        --Are we in a segment with reclaim or near a segment with reclaim?
                        --IsReclaimNearby(tLocation, iAdjacentSegmentSize, iMinTotal, iMinIndividual)
                        if M27Conditions.IsReclaimNearby(GetPlatoonFrontPosition(oPlatoon), 1, 15, 5) then
                            --check we have reclaim in range of the ACU itself
                            local iMaxRange = oFirstReclaimer:GetBlueprint().Economy.MaxBuildDistance + 0.5
                            local oNearestReclaim = M27MapInfo.GetNearestReclaim(GetPlatoonFrontPosition(oPlatoon), iMaxRange, 5)
                            if oNearestReclaim and oNearestReclaim.CachePosition and M27Utilities.GetDistanceBetweenPositions(oNearestReclaim.CachePosition, GetPlatoonFrontPosition(oPlatoon)) <= iMaxRange then
                                oPlatoon[refiCurrentAction] = refActionReclaimAllNearby
                                oPlatoon[refoNearbyReclaimTarget] = nil
                                if bDebugMessages == true then LOG(sFunctionRef..': Have nearby reclaim, so will try to get') end
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Reclaim is close but not in build range') end
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': No nearby reclaim') end
                        end

                        --Old approach pre v15 below
                        --[[


                        local oReclaimerBP = oFirstReclaimer:GetBlueprint()

                        local iBuildDistance = oReclaimerBP.Economy.MaxBuildDistance
                        if iBuildDistance <= 5 then iBuildDistance = 5 end
                        if bDebugMessages == true then LOG(sFunctionRef..': Found a reclaimer, about to locate any nearby reclaim; iBuildDistance='..iBuildDistance) end
                        --Do we already have a reclaim target that we're reclaiming?
                        local bAlreadyHaveValidTarget = false
                        local bHaveValidTarget = false
                        local oReclaimTarget
                        local tReclaimLocation = {}

                        if oFirstReclaimer:IsUnitState('Reclaiming') == true then
                            oReclaimTarget = oPlatoon[refoNearbyReclaimTarget]
                            if not(oReclaimTarget == nil) then
                                if oReclaimTarget.MaxMassReclaim > 0 then
                                    if not(oReclaimTarget:BeenDestroyed()) then
                                        tReclaimLocation = oReclaimTarget.CachePosition
                                        if M27Utilities.IsTableEmpty(tReclaimLocation) == false then
                                            if M27Utilities.GetDistanceBetweenPositions(tReclaimLocation, oFirstReclaimer:GetPosition()) <= iBuildDistance then
                                                bAlreadyHaveValidTarget = true
                                                bHaveValidTarget = true
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        if bAlreadyHaveValidTarget == false then
                            --GetNearestReclaim(tLocation, iSearchRadius, iMinReclaimValue)
                            if bDebugMessages == true then LOG(sFunctionRef..': Dont have an existing reclaim target so will look for nearest reclaim') end
                            oReclaimTarget = M27MapInfo.GetNearestReclaim(GetPlatoonFrontPosition(oPlatoon), iBuildDistance + 2, 10)

                            if not(oReclaimTarget == nil) and oReclaimTarget.MaxMassReclaim > 0 and not(oReclaimTarget:BeenDestroyed()) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Found a reclaim target, changing action') end
                                oPlatoon[refoNearbyReclaimTarget] = oReclaimTarget
                                bHaveValidTarget = true
                            elseif bDebugMessages == true then
                                LOG(sFunctionRef..': oReclaimTarget is nil or has 0 max mass reclaim or has been destroyed')
                                if oReclaimTarget then LOG('Reclaim target isnt nil; maxmassreclaim='..oReclaimTarget.MaxMassReclaim..'; oReclaimTarget:BeenDestroyed='..tostring(oReclaimTarget:BeenDestroyed())) end
                            end
                        end
                        if bHaveValidTarget == true then
                            if not(oPlatoon[refoNearbyReclaimTarget]) then M27Utilities.ErrorHandler('Thought had valid target but dont') end
                            local bWillOverflowMass = false
                            --Are we overflowing mass (or about to)?
                            --Get reclaim rate: From testing looks like the reclaim per second is roughly 5 * build power
                            local iBuildPower = oReclaimerBP.Economy.BuildRate
                            if iBuildPower == nil then iBuildPower = 5 end
                            local iReclaimRate = 5 * iBuildPower
                            local iMassReclaimed = math.min(oPlatoon[refoNearbyReclaimTarget].MaxMassReclaim, iReclaimRate)
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering if will overflow mass, iReclaimRate='..iReclaimRate..'; iMassReclaimed='..iMassReclaimed..'; iBuildPower='..iBuildPower..'; iSpareStorage='..iSpareStorage) end
                            if bAlreadyHaveValidTarget == true then
                                --Finish reclaim unless >=5 mass wasted
                                if iSpareStorage < 50 and iMassReclaimed > (iSpareStorage + 5) then bWillOverflowMass = true end
                            else
                                if iSpareStorage < 50 and iMassReclaimed > iSpareStorage then bWillOverflowMass = true end
                            end
                            if bWillOverflowMass == false then
                                if bDebugMessages == true then LOG(sFunctionRef..': wont overflow mass so proceed with reclaim') end
                                oPlatoon[refiCurrentAction] = refActionReclaimTarget
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Will overflow mass so wont issue action to reclaim') end
                                oPlatoon[refoNearbyReclaimTarget] = nil
                            end
                        end --]]
                    end
                else
                    oPlatoon[refiReclaimers] = 0
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': iSpareStorage='..iSpareStorage) end
            end
            --[[if bDebugMessages == true and oPlatoon[refoNearbyReclaimTarget] then
                if oPlatoon[refiCurrentAction] == nil then LOG(sFunctionRef..': '..oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]..': Have a reclaim target but no action')
                else
                    LOG(sFunctionRef..': '..oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]..': Have a reclaim target; action='..oPlatoon[refiCurrentAction]..': mass on reclaim='..oPlatoon[refoNearbyReclaimTarget].MaxMassReclaim)
                    if oPlatoon[refoNearbyReclaimTarget]:BeenDestroyed() then M27Utilities.ErrorHandler('Reclaim has been destroyed') end
                end
            end--]]
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DecideWhetherToGetACUUpgrade(aiBrain, oPlatoon)
    local sFunctionRef = 'DecideWhetherToGetACUUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    if M27Conditions.DoesACUHaveGun(aiBrain, true) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': ACU doesnt have gun, checking if we want to get the upgrade now') end
        if M27Conditions.WantToGetGunUpgrade(aiBrain) == true then
            if bDebugMessages == true then LOG(sFunctionRef..': Want to get the gun upgrade now') end
            oPlatoon[refiCurrentAction] = refActionUpgrade
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': Have gun upgrade, checking if we want to get the next upgrade') end
        local bWantUpgrade, bSafeToUpgrade = M27Conditions.WantToGetAnotherACUUpgrade(aiBrain)
        if bWantUpgrade then
            if bDebugMessages == true then LOG(sFunctionRef..': Want to get the next upgrade') end
            oPlatoon[refiCurrentAction] = refActionUpgrade
        elseif bSafeToUpgrade == false then
            --Only reason we're not upgrading is because its not safe - return towards base
            oPlatoon[refiCurrentAction] = refActionReturnToBase
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetACUUpgradeWanted(aiBrain, oACU)
    --Returns nil if cantr find anything
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetACUUpgradeWanted'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Assumes have already decided want to get an upgrade
    local sUpgradeID
    if M27Conditions.DoesACUHaveGun(aiBrain, true) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': ACU doesnt have gun upgrade yet so will get this') end
        --Get gun upgrade
        for sEnhancement, tEnhancement in oACU:GetBlueprint().Enhancements do
            if bDebugMessages == true then LOG(sFunctionRef..': sEnhancement='..sEnhancement..'; tEnhancement='..repr(tEnhancement)) end
            if M27UnitInfo.GetUnitFaction(oACU) == M27UnitInfo.refFactionAeon and not(oACU:HasEnhancement('CrysalisBeam')) then return 'CrysalisBeam' else
                for iGunEnhancement, sGunEnhancement in M27Conditions.tGunUpgrades do
                    if sEnhancement == sGunEnhancement and not(oACU:HasEnhancement(sGunEnhancement)) then
                        return sEnhancement
                    end
                end
            end
        end
        M27Utilities.ErrorHandler('Failed to find a gun upgrade for ACU')
    else
        --Already have a gun upgrade; decide what we want next

        local iFactionRef = M27UnitInfo.GetUnitFaction(oACU)
        local tUpgradesWanted = {}
        if iFactionRef == M27UnitInfo.refFactionUEF then
            --Want t2 and then personal shield
            tUpgradesWanted = {'AdvancedEngineering', 'Shield'}
        elseif iFactionRef == M27UnitInfo.refFactionCybran then
            tUpgradesWanted = {'StealthGenerator', 'MicrowaveLaserGenerator', 'CloakingGenerator'}
        elseif iFactionRef == M27UnitInfo.refFactionAeon then
            tUpgradesWanted = {'Shield'}
        elseif iFactionRef == M27UnitInfo.refFactionSeraphim then
            tUpgradesWanted = {'AdvancedEngineering', 'DamageStabilization', 'BlastAttack', 'DamageStabilizationAdvanced'}
        else M27Utilities.ErrorHandler('Dont recognise the ACU faction so wont be getting any further upgrades', nil, true)
        end

        if bDebugMessages == true then LOG(sFunctionRef..': ACU has gun; tUpgradesWanted='..repr(tUpgradesWanted)..'; iFactionRef='..iFactionRef) end
        for iUpgrade, sPossibleUpgrade in tUpgradesWanted do
            --Do we already have the upgrade?
            if not(oACU:HasEnhancement(sPossibleUpgrade)) then
                if bDebugMessages == true then LOG(sFunctionRef..': ACU doesnt have the upgrade '..sPossibleUpgrade) end
                sUpgradeID = sPossibleUpgrade
                break
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return sUpgradeID
end

function RetreatLowHealthShields(oPlatoon, aiBrain)
    --Called by onunitdamage as well as every second on platoon cycle
    --Will retreat either if low health collectively, or if the platoon we're escorting is almost dead

    --Will check that the platoon has prev actions to reduce risk of infinite loop occurring

    --Mobile shield bubbles - will assign to retreating platoon based on collective shield %
    --Units with personal shield - will assign to retreating platoon based on individual unit health and shield %
    local sFunctionRef = 'RetreatLowHealthShields'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if aiBrain:PlatoonExists(oPlatoon) then
        local sPlan = oPlatoon:GetPlan()
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code for Platoon='..sPlan..(oPlatoon[refiPlatoonCount] or 'nil')..'; GameTime='..GetGameTimeSeconds()) end
        local iTotalMobileShieldCurHealth = 0
        local iTotalMobileShieldMaxHealth = 0
        local iCurShieldHealth, iMaxShieldHealth
        local oBP, sBP
        local tMobileShields = {}
        local iMobileShieldCount = 0
        local tUnitsToRun = {}
        local iUnitsToRun = 0
        local tUnitsToFight = {}
        local iUnitsToFight = 0
        --local aiBrain = oPlatoon:GetBrain()
        local sRetreatingShieldPlatoon = 'M27RetreatingShieldUnits'
        local bHaveChangedPlatoonComposition = false
        local iMaxShieldsBeforeStartCycling = 2 --If have more than this then will start shield cycling
        local iLowShieldPercent = 0.5
        local iOverlappingShield
        local tBasePosition
        local oNearbyBP, sNearbyBP, iOverlappingShieldRangeThreshold
        local iCurDistanceToPlatoonFront
        local iMaxDistanceToPlatoonFront = 20 --If further away than this then wont consider when deciding if we need to retreat
        local iFrontlineMobileShieldCount = 0
        local bConsiderLowShieldIndividually = false

        if M27Utilities.IsTableEmpty(oPlatoon[reftUnitsWithShields]) == false then
            if oPlatoon[reftPrevAction] and oPlatoon[reftPrevAction][2] then
                if oPlatoon[refbACUInPlatoon] then
                    if M27Utilities.IsACU(oPlatoon[refoFrontUnit]) then
                        iCurShieldHealth, iMaxShieldHealth = M27UnitInfo.GetCurrentAndMaximumShield(oPlatoon[refoFrontUnit])
                        if iCurShieldHealth == 0 and iMaxShieldHealth > 0 then
                            oPlatoon[refiCurrentAction] = refActionRun
                        end
                    end
                else

                    for iUnit, oUnit in oPlatoon[reftUnitsWithShields] do
                        if not(oUnit.Dead) and oUnit.MyShield then
                            bConsiderLowShieldIndividually = true
                            oBP = oUnit:GetBlueprint()
                            sBP = oUnit:GetUnitId()
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering unit with shield sBP='..sBP..M27UnitInfo.GetUnitLifetimeCount(oUnit))
                                if oUnit.PlatoonHandle then LOG(sFunctionRef..': Units platoon handle='..oUnit.PlatoonHandle:GetPlan()..(oUnit.PlatoonHandle[refiPlatoonCount] or 'nil')) end
                            end
                            iCurShieldHealth, iMaxShieldHealth = M27UnitInfo.GetCurrentAndMaximumShield(oUnit)

                            if EntityCategoryContains(M27UnitInfo.refCategoryMobileLandShield, sBP) == true and not(oPlatoon:GetPlan() == sRetreatingShieldPlatoon) then
                                bConsiderLowShieldIndividually = false
                                iMobileShieldCount = iMobileShieldCount + 1
                                tMobileShields[iMobileShieldCount] = oUnit
                                tBasePosition = oUnit:GetPosition()
                                iCurDistanceToPlatoonFront = M27Utilities.GetDistanceBetweenPositions(tBasePosition, GetPlatoonFrontPosition(oPlatoon))
                                if iCurDistanceToPlatoonFront <= iMaxDistanceToPlatoonFront then
                                    iFrontlineMobileShieldCount = iFrontlineMobileShieldCount + 1
                                    iTotalMobileShieldCurHealth = iTotalMobileShieldCurHealth + iCurShieldHealth
                                    iTotalMobileShieldMaxHealth = iTotalMobileShieldMaxHealth + iMaxShieldHealth
                                    --Go through remaining units in platoon and see if they're near this one, have their shield enabled, and have high health on their shield

                                    iOverlappingShield = 0
                                    for iNearbyUnit, oNearbyUnit in oPlatoon[reftUnitsWithShields] do
                                        if not(oNearbyUnit == oUnit) and not(oNearbyUnit.Dead) then
                                            oNearbyBP = oNearbyUnit:GetBlueprint()
                                            sNearbyBP = oNearbyUnit:GetUnitId()
                                            if EntityCategoryContains(M27UnitInfo.refCategoryMobileLandShield, sBP) then
                                                if oNearbyUnit:GetShieldRatio(true) >= iLowShieldPercent and M27UnitInfo.IsUnitShieldEnabled(oNearbyUnit) and oNearbyUnit.MyShield:GetHealth() >= 1000 then
                                                    iOverlappingShieldRangeThreshold = oNearbyBP.Defense.Shield.ShieldSize - 6
                                                    if M27Utilities.GetDistanceBetweenPositions(oNearbyUnit:GetPosition(), tBasePosition) < iOverlappingShieldRangeThreshold then
                                                        iOverlappingShield = iOverlappingShield + 1
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    if iOverlappingShield > iMaxShieldsBeforeStartCycling then
                                        M27UnitInfo.DisableUnitShield(oUnit)
                                    elseif iOverlappingShield < iMaxShieldsBeforeStartCycling and M27UnitInfo.IsUnitShieldEnabled(oUnit) == false then M27UnitInfo.EnableUnitShield(oUnit)
                                    end
                                else
                                    --Are we due to get to the front soon?
                                    if iCurDistanceToPlatoonFront >= iMaxDistanceToPlatoonFront * 1.5 then bConsiderLowShieldIndividually = true end
                                end
                            end
                            if bConsiderLowShieldIndividually == true then
                                if iCurShieldHealth <= math.min(100, iMaxShieldHealth * 0.1) and M27UnitInfo.IsUnitShieldEnabled(oUnit) == true then
                                    iUnitsToRun = iUnitsToRun + 1
                                    tUnitsToRun[iUnitsToRun] = oUnit
                                elseif iCurShieldHealth >= iMaxShieldHealth * 0.9 then --WARNING: Careful when changing this -
                                    iUnitsToFight = iUnitsToFight + 1
                                    tUnitsToFight[iUnitsToFight] = oUnit
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': Unit '..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' has personal shield; iUnitsToRun='..iUnitsToRun..'; iUnitsToFight='..iUnitsToFight..'; iCurShieldHealth='..iCurShieldHealth..'; iMaxShieldHealth='..iMaxShieldHealth) end
                            end
                        end
                    end
                    if iMobileShieldCount > 0 then
                        --Are we assisting something that should no longer be assisted?
                        local bStopAssistingPlatoon = false
                        if oPlatoon and oPlatoon[refoPlatoonOrUnitToEscort] then
                            if not(oPlatoon[refoPlatoonOrUnitToEscort][refbACUInPlatoon]) and M27PlatoonFormer.DoesPlatoonWantAnotherMobileShield(oPlatoon[refoPlatoonOrUnitToEscort], 0, true) == false then bStopAssistingPlatoon = true end
                        end
                        if bStopAssistingPlatoon then
                            bHaveChangedPlatoonComposition = true
                            M27PlatoonFormer.CreatePlatoon(aiBrain, sRetreatingShieldPlatoon, tMobileShields, true)
                            oPlatoon[refiCurrentAction] = refActionDisband
                        else
                            if iFrontlineMobileShieldCount > 0 then
                                if iTotalMobileShieldCurHealth < iTotalMobileShieldMaxHealth * iLowShieldPercent and not(sPlan==sRetreatingShieldPlatoon) then
                                    bHaveChangedPlatoonComposition = true
                                    M27PlatoonFormer.CreatePlatoon(aiBrain, sRetreatingShieldPlatoon, tMobileShields, true)
                                    if bDebugMessages == true then LOG(sFunctionRef..': Created new retreating shield platoon') end
                                elseif sPlan == sRetreatingShieldPlatoon and iTotalMobileShieldCurHealth > iTotalMobileShieldMaxHealth * 0.95 then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Platoon has mobile shields that have recovered so reassigning by disbanding platoon') end
                                    oPlatoon[refiCurrentAction] = refActionDisband
                                end
                            end
                        end
                    end
                    if iUnitsToRun > 0 and not(sPlan == sRetreatingShieldPlatoon) then
                        bHaveChangedPlatoonComposition = true
                        M27PlatoonFormer.CreatePlatoon(aiBrain, sRetreatingShieldPlatoon, tUnitsToRun, true)
                        if bDebugMessages == true then LOG(sFunctionRef..': Created new platoon '..sRetreatingShieldPlatoon..'; for tUnitsToRun which have a size of'..table.getn(tUnitsToRun)) end
                    elseif sPlan == sRetreatingShieldPlatoon and iUnitsToFight > 0 then
                        bHaveChangedPlatoonComposition = true
                        RemoveUnitsFromPlatoon(oPlatoon, tUnitsToFight, false, nil)
                        if bDebugMessages == true then LOG(sFunctionRef..': Have units to fight that are in a retreating platoon so removing them from that platoon') end
                    end

                    if bHaveChangedPlatoonComposition then
                        if bDebugMessages == true then LOG(sFunctionRef..': Platoon has changed so will update its trackers') end
                        RecordPlatoonUnitsByType(oPlatoon)
                    end
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..':'..sPlan..(oPlatoon[refiPlatoonCount] or 'nil')..': Platoon doesnt have 2+ prev actions so not considering mobile shields due to infinite loop risk') end
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': End of code for platoon '..sPlan..(oPlatoon[refiPlatoonCount] or 'nil')..'; iUnitsToFight='..iUnitsToFight..'; iUnitsToRun='..iUnitsToRun..'; iMobileShieldCount='..iMobileShieldCount) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RetreatToMobileShields(oPlatoon)
    local sFunctionRef = 'RetreatToMobileShields'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = true if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    --If the platoon has a mobile shield assisting platoon whose front units are far away, then fall back to it
    if oPlatoon[refoSupportingShieldPlatoon] and oPlatoon[refoSupportingShieldPlatoon][refiUnitsWithShields] > 0 then
        local iDistanceToShieldHelper = M27Utilities.GetDistanceBetweenPositions(GetPlatoonFrontPosition(oPlatoon), GetPlatoonFrontPosition(oPlatoon[refoSupportingShieldPlatoon]))
        if bDebugMessages == true then LOG(sFunctionRef..': iDistanceToShieldHelper='..iDistanceToShieldHelper) end
        if iDistanceToShieldHelper > 50 and iDistanceToShieldHelper <= 250 then
            oPlatoon[refiCurrentAction] = refActionMoveToTemporaryLocation
            if M27Utilities.IsTableEmpty(oPlatoon[refoSupportingShieldPlatoon][reftMovementPath][1]) == true then
                oPlatoon[refoSupportingShieldPlatoon][reftMovementPath] = {}
                oPlatoon[refoSupportingShieldPlatoon][reftMovementPath][1] = GetPlatoonFrontPosition(oPlatoon)
            end

            oPlatoon[reftTemporaryMoveTarget] = GetMergeLocation(oPlatoon[refoSupportingShieldPlatoon], 0.5)
            if bDebugMessages == true then LOG(sFunctionRef..': Just got merge location; result='..repr(oPlatoon[reftTemporaryMoveTarget] or {'nil'})) end
            if M27Utilities.IsTableEmpty(oPlatoon[reftTemporaryMoveTarget]) == true then
                if bDebugMessages == true then LOG(sFunctionRef..': No merge location so will move to shield platoon position instead if we can path there and its not too far away') end
                if iDistanceToShieldHelper <= 150 then
                    if oPlatoon[refoFrontUnit]:CanPathTo(GetPlatoonFrontPosition(oPlatoon[refoSupportingShieldPlatoon])) then
                        oPlatoon[reftTemporaryMoveTarget] = GetPlatoonFrontPosition(oPlatoon[refoSupportingShieldPlatoon])
                    else
                        --cant move to supporting shield platoon so cancel action
                        if bDebugMessages == true then LOG(sFunctionRec..': Cant path to shield platoon so will cancel action') end
                        oPlatoon[refiCurrentAction] = nil
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Supporting shield platoon too far away so will ignore action') end
                    oPlatoon[refiCurrentAction] = nil
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DeterminePlatoonAction(oPlatoon)
    --Record current action as previous action
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DeterminePlatoonAction'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if oPlatoon[refbOverseerAction] == true then bDebugMessages = true end
    if oPlatoon and oPlatoon.GetBrain then
        local aiBrain = oPlatoon[refoBrain]
        if aiBrain and aiBrain.PlatoonExists and aiBrain:PlatoonExists(oPlatoon) then
            local sPlatoonName = oPlatoon:GetPlan()

            --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end
            --if sPlatoonName == 'M27DefenderAI' then bDebugMessages = true end
            --if sPlatoonName == 'M27MexRaiderAI' then bDebugMessages = true end
            --if sPlatoonName == 'M27ScoutAssister' then bDebugMessages = true end
            --if sPlatoonName == M27Overseer.sIntelPlatoonRef then bDebugMessages = true end
            --if sPlatoonName == 'M27MAAAssister' then bDebugMessages = true end
            --if sPlatoonName == 'M27LargeAttackForce' then bDebugMessages = true end
            --if sPlatoonName == 'M27IntelPathAI' then bDebugMessages = true end
            --if sPlatoonName == 'M27IndirectDefender' then bDebugMessages = true end
            --if sPlatoonName == 'M27MexLargerRaiderAI' then bDebugMessages = true end
            --if sPlatoonName == 'M27CombatPatrolAI' then bDebugMessages = true end
            --if sPlatoonName == 'M27EscortAI' then bDebugMessages = true end
            --if sPlatoonName == 'M27IndirectDefender' then bDebugMessages = true end
            --if sPlatoonName == 'M27RetreatingShieldUnits' then bDebugMessages = true end
            --if sPlatoonName == 'M27MobileShield' then bDebugMessages = true end

            if bDebugMessages == true then
                LOG(sFunctionRef..': Start of code')
              --M27EngineerOverseer.TEMPTEST(aiBrain, 'Determine platoon action - start of code')
                if sPlatoonName == 'M27IndirectDefender' then LOG(sFunctionRef..': Platoon name and count='..sPlatoonName..oPlatoon[refiPlatoonCount]..': refbShouldHaveEscort='..tostring(oPlatoon[refbShouldHaveEscort])) end
            end

            if not(oPlatoon[reftPrevAction][15]==nil) then table.remove(oPlatoon[reftPrevAction], 15) end
            if not(oPlatoon[refiCurrentAction] == nil) then
                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': DeterminePlatoonAction: Current action isnt nil') end
                if oPlatoon[reftPrevAction] == nil then
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': DeterminePlatoonAction: Prev action table is completely nil so setting it equal to current action') end
                    oPlatoon[reftPrevAction] = {oPlatoon[refiCurrentAction]}
                    if oPlatoon[reftPrevAction] == nil then
                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': DeterminePlatoonAction: Prev action table is still completely nil') end
                    end
                else
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': DeterminePlatoonAction: Inserting new prev action into table; action to insert='..oPlatoon[refiCurrentAction]) end
                    table.insert(oPlatoon[reftPrevAction], 1, oPlatoon[refiCurrentAction])
                end
            else --Dont have a current action so won't make any change; set prev action to whatever was there before
                --Exception - have added in override to make current action nil if it was continue movement path and prev action was new movement path; therefore set prev action to continuemovementpath
                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': '..sFunctionRef..': Current action is nil') end
                if not(oPlatoon[reftPrevAction] == nil) then
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': '..sFunctionRef..': No change to preva ction, inserting the prev action to itself; Action to insert='..oPlatoon[reftPrevAction][1]) end
                    if oPlatoon[reftPrevAction][1] == refActionNewMovementPath then
                        table.insert(oPlatoon[reftPrevAction], 1, refActionContinueMovementPath)
                    else
                        table.insert(oPlatoon[reftPrevAction], 1, oPlatoon[reftPrevAction][1])
                    end

                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': '..sFunctionRef..': No change to preva ction, inserting the prev action to itself; Finished inserting='..oPlatoon[reftPrevAction][1]) end
                end
            end

            --Update pref targets where we need to track them:
            oPlatoon[refoPrevTemporaryAttackTarget] = oPlatoon[refoTemporaryAttackTarget]


            --[[if bDebugMessages == true then
                if oPlatoon[reftPrevAction] == nil then
                    LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': DeterminePlatoonAction: Prev Action is nil')
                else
                    LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': DeterminePlatoonAction: Prev Action is now '..oPlatoon[reftPrevAction][1])
                    if table.getn(oPlatoon[reftPrevAction]) > 1 then
                        LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': DeterminePlatoonAction: total prev actions='..table.getn(oPlatoon[reftPrevAction]))
                        if oPlatoon[reftPrevAction][2] == nil then
                            LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': DeterminePlatoonAction: 2nd prev action is nil')
                        else
                            LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': DeterminePlatoonAction: 2nd prev action is '..oPlatoon[reftPrevAction][2])
                        end
                    else
                        LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': DeterminePlatoonAction: Only 1 prev action exists')
                    end
                end
            end ]]--
            oPlatoon[refiCurrentAction] = nil
            oPlatoon[refiExtraAction] = nil
            --Setup:
            if bDebugMessages == true then LOG(sFunctionRef..sPlatoonName..oPlatoon[refiPlatoonCount]..': about to call RecordPlatoonUnitsByType') end
            RecordPlatoonUnitsByType(oPlatoon)
            if bDebugMessages == true then LOG(sFunctionRef..': Checking platoon has units') end
            if oPlatoon[refiCurrentUnits] == 0 then
                if bDebugMessages == true then LOG('oPlatoon has nil units, so moving to action disband; Platoon ref='..sPlatoonName..oPlatoon[refiPlatoonCount]) end
                oPlatoon[refiCurrentAction] = refActionDisband
            else
                if oPlatoon[refiUnitsWithShields] > 0 then RetreatLowHealthShields(oPlatoon, aiBrain) end
                if oPlatoon[refiCurrentUnits] == 0 then
                    if bDebugMessages == true then LOG('oPlatoon has no units after retreating shields, so disbanding; Platoon ref='..sPlatoonName..oPlatoon[refiPlatoonCount]) end
                    oPlatoon[refiCurrentAction] = refActionDisband
                else
                    local bDoNothing = false
                    if oPlatoon[refbACUInPlatoon] and oPlatoon[reftBuilders][1] and oPlatoon[reftBuilders][1][M27UnitInfo.refbOverchargeOrderGiven] then
                        bDoNothing = true
                    end
                    if not(bDoNothing) then
                        --Get details on nearby enemies
                        if bDebugMessages == true then LOG(sFunctionRef..': Checking nearby enemy data and checking if we have an escort platoon') end
                        local iPlatoonMaxRange = M27Logic.GetUnitMaxGroundRange(oPlatoon[reftCurrentUnits])
                        local iEnemySearchRadius = iPlatoonMaxRange * 2 --Will consider responses if any enemies get within 2 times the max range of platoon
                        if iEnemySearchRadius < 40 then iEnemySearchRadius = 40 end
                        --Check this is also >= intel size:
                        local iIntelRange = oPlatoon[reftCurrentUnits][1]:GetBlueprint().Intel.RadarRadius
                        if iEnemySearchRadius < iIntelRange then iEnemySearchRadius = iIntelRange end
                        GetNearbyEnemyData(oPlatoon, iEnemySearchRadius)

                --SPECIAL MODE - attack ACU - ignore most logic
                        local bAttackACULogic = false
                        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill then
                            if oPlatoon[refbACUInPlatoon] then
                                if aiBrain[M27Overseer.refbIncludeACUInAllOutAttack] then
                                    bAttackACULogic = true
                                    local oACU = oPlatoon[reftBuilders][1]
                                    if not(oACU) then oACU = M27Utilities.GetACU(aiBrain) end
                                    if M27Conditions.CanUnitUseOvercharge(aiBrain, oACU) == true then M27UnitMicro.GetOverchargeExtraAction(aiBrain, oPlatoon, oACU) end
                                end
                            else
                                 if M27Utilities.IsTableEmpty(GetPlatoonUnitsOrUnitCount(oPlatoon, reftDFUnits, false, false)) == false or M27Utilities.IsTableEmpty(GetPlatoonUnitsOrUnitCount(oPlatoon, reftIndirectUnits, false, false)) == false then
                                     bAttackACULogic = true
                                 end
                            end
                            if bAttackACULogic == true then oPlatoon[refiCurrentAction] = refActionKillACU end
                        end
                        if bAttackACULogic == false then
                            --Escort platoons - if escorting an individual unit as a 'platoon' such as an engineer, then need to update the tracker for that as well
                            if oPlatoon[M27PlatoonTemplates.refbRequiresUnitToFollow] == true and oPlatoon[refoPlatoonOrUnitToEscort] then
                                if oPlatoon[refoPlatoonOrUnitToEscort].GetUnitId then
                                    --Check the unit we're meant to be escorting is still alive
                                    if oPlatoon[refoPlatoonOrUnitToEscort].Dead then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Unit that were escorting is dead so disbanding') end
                                        oPlatoon[refiCurrentAction] = refActionDisband
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': Are escorting a unit and its still alive, will refresh escort details') end
                                        RecordPlatoonUnitsByType(oPlatoon[refoPlatoonOrUnitToEscort], true)
                                        GetNearbyEnemyData(oPlatoon[refoPlatoonOrUnitToEscort], M27EngineerOverseer.iEngineerEnemySearchRange, true)
                                        UpdateEscortDetails(oPlatoon[refoPlatoonOrUnitToEscort]) -- need to call from the unit itself as well, e.g. engineers call this as part of the action tracker assignment
                                    end
                                elseif oPlatoon[refoPlatoonOrUnitToEscort].GetPlan then
                                    if not(aiBrain:PlatoonExists(oPlatoon[refoPlatoonOrUnitToEscort])) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Platoon that were escorting no longer exists so disbanding') end
                                        oPlatoon[refiCurrentAction] = refActionDisband
                                    end
                                else
                                    M27Utilities.ErrorHandler(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..' escorting platoon has a unit or platoon to escort that doesnt have a unitid or platoon handle')
                                    local sPlatoonCount, sUnitsInPlatoon, tFrontPosition
                                    sPlatoonCount = oPlatoon[refoPlatoonOrUnitToEscort][refiPlatoonCount]
                                    if sPlatoonCount == nil then sPlatoonCount = 'nil' end
                                    sUnitsInPlatoon = oPlatoon[refoPlatoonOrUnitToEscort][refiCurrentUnits]
                                    if sUnitsInPlatoon == nil then sUnitsInPlatoon = 'nil' end
                                    tFrontPosition = GetPlatoonFrontPosition(oPlatoon[refoPlatoonOrUnitToEscort])
                                    if tFrontPosition == nil then tFrontPosition = {'nil'} end
                                    LOG('Details of unit or platoon escorting: sPlatoonCount='..sPlatoonCount..'; sUnitsInPlatoon='..sUnitsInPlatoon..'; tFrontPosition='..repr(tFrontPosition))
                                    oPlatoon[refiCurrentAction] = refActionDisband
                                end
                            end

                            --Special override for start of game:
                            local bStartingBuildOrder = false
                            if oPlatoon[refbACUInPlatoon] == true then
                                if GetGameTimeSeconds() <= 100 then
                                    local tFactories = aiBrain:GetListOfUnits(categories.CONSTRUCTION * categories.FACTORY, false, true)
                                    local iFactoryCount = 0
                                    if M27Utilities.IsTableEmpty(tFactories) == false then
                                        for iFactory, oFactory in tFactories do
                                            if oFactory.GetFractionComplete and oFactory:GetFractionComplete() == 1 then
                                                iFactoryCount = iFactoryCount + 1
                                                break
                                            end
                                        end
                                    end
                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': iFactoryCount='..iFactoryCount) end
                                    if iFactoryCount == 0 then
                                        oPlatoon[refiCurrentAction] = refActionBuildLandFactory
                                        bStartingBuildOrder = true
                                    end
                                end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': Special override for ACU platoon at start of the game (first 100 seconds); bStartingBuildOrder='..tostring(bStartingBuildOrder)) end
                            if bStartingBuildOrder == false then
                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': platoon has units') end
                                if M27Utilities.IsTableEmpty(oPlatoon[reftMovementPath]) then
                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Platoon has no movement path') end
                                    oPlatoon[refiCurrentAction] = refActionNewMovementPath
                                else
                                    if M27Utilities.IsTableEmpty(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]]) == true then
                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Current path target is nil, getting new movement path') end
                                        oPlatoon[refiCurrentAction] = refActionNewMovementPath
                                    else
                                        --INITIAL ACU SPECIFIC ACTIONS
                                        --If ACU on low health then run; if ACU upgrading then do nothing
                                        if bDebugMessages == true then LOG(sFunctionRef..'; oPlatoon[refbACUInPlatoon]='..tostring(oPlatoon[refbACUInPlatoon])) end
                                        if oPlatoon[refbACUInPlatoon] == true then
                                            local oACU = M27Utilities.GetACU(aiBrain)
                                            local iHealthPercentage = oACU:GetHealthPercent()
                                            local bRun = false

                                            if oACU:IsUnitState('Upgrading') then
                                                if bDebugMessages == true then LOG(sFunctionRef..': ACU unit state is upgrading') end
                                                local iUpgradePercent = oACU:GetWorkProgress()
                                                if iHealthPercentage <= 0.5 and iUpgradePercent < (1 - iHealthPercentage) then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': ACU needs to run as iHealthPercentage='..iHealthPercentage..' and iUpgradePercent='..iUpgradePercent) end
                                                    bRun = true
                                                else
                                                    if bDebugMessages == true then LOG(sFunctionRef..': ACU shoudl continue with its upgrade') end
                                                    oPlatoon[refiCurrentAction] = refActionUpgrade
                                                end
                                            else
                                                if bDebugMessages == true then LOG(sFunctionRef..': ACU not upgrading, will see if low health') end
                                                if iHealthPercentage <= 0.35 then bRun = true end
                                            end
                                            if bRun == true then
                                                if bDebugMessages == true then LOG(sFunctionRef..': ACU needs to run so will set action to return to base') end
                                                oPlatoon[refbNeedToHeal] = true
                                                oPlatoon[refiCurrentAction] = refActionReturnToBase
                                            end
                                        end
                                        if oPlatoon[refiCurrentAction] == nil then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Platoon doesnt have an action yet, will check for whether we have an overseer override action now') end
                                            --Apply overseer override action if there is one
                                            if oPlatoon[refbOverseerAction] == true then
                                                oPlatoon[refiLastPrevActionOverride] = 0
                                                local bIgnoreOverseerOverride = false
                                                oPlatoon[refbOverseerAction] = false
                                                --first Check if reached final destination (in which case will ignore the override except for scouts)
                                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Overseer action active; checking if reached current or final destination') end
                                                if HasPlatoonReachedDestination(oPlatoon) == true then
                                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Overseer action active; Have reached current destination, considering if final') end
                                                    if oPlatoon[refiCurrentPathTarget] > table.getn(oPlatoon[reftMovementPath]) then
                                                        if sPlatoonName == M27Overseer.sIntelPlatoonRef then
                                                            oPlatoon[refiCurrentPathTarget] = table.getn(oPlatoon[reftMovementPath])
                                                        else
                                                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Overseer action active; Have reached final destination, getting completion action instead') end
                                                            DeterminePlatoonCompletionAction(oPlatoon)
                                                            bIgnoreOverseerOverride = true
                                                        end
                                                    end
                                                end
                                                if bIgnoreOverseerOverride == false then
                                                    oPlatoon[refiCurrentAction] = oPlatoon[refiOverseerAction]
                                                    if oPlatoon[refiCurrentAction] == nil then
                                                        M27Utilities.ErrorHandler(sPlatoonName..oPlatoon[refiPlatoonCount]..': Likely error - Platoon current action is still nil so override flag set without specifying action')
                                                    else
                                                        if bDebugMessages == true then LOG('Overseer action override: Platoon current action is:'..oPlatoon[refiCurrentAction]) end
                                                    end
                                                    --Get more refined enemy targetting commands:
                                                    if oPlatoon[refiCurrentAction] == refActionAttack or oPlatoon[refiCurrentAction] == refActionMoveDFToNearestEnemy then
                                                        --local iPlatoonMaxRange = M27Logic.GetUnitMaxGroundRange(oPlatoon[reftCurrentUnits])
                                                        --local iEnemySearchRadius = math.min(math.max(iPlatoonMaxRange * 2, iPlatoonMaxRange + 5), iPlatoonMaxRange + 25) --Will consider responses if any enemies get within 2 times the max range of platoon
                                                        --GetNearbyEnemyData(oPlatoon, iEnemySearchRadius)
                                                        local iOriginalAction = oPlatoon[refiCurrentAction]
                                                        UpdatePlatoonActionForNearbyEnemies(oPlatoon, true)
                                                        if oPlatoon[refiCurrentAction] == nil then oPlatoon[refiCurrentAction] = iOriginalAction end
                                                    end
                                                end
                                                oPlatoon[refiOverseerAction] = nil
                                            else
                                                oPlatoon[refiLastPrevActionOverride] = oPlatoon[refiLastPrevActionOverride] + 1
                                                --Check not just had a platoon disband action (in which case wouldve been from other code):
                                                if not(oPlatoon[reftPrevAction][1] == nil) then
                                                    if oPlatoon[reftPrevAction][1] == refActionDisband then
                                                        if bDebugMessages == true then LOG('Determineplatoon action: Prev action was to disband so making that our current action') end
                                                        oPlatoon[refiCurrentAction] = refActionDisband
                                                    end
                                                end
                                                if oPlatoon[refiCurrentAction] == nil then
                                                    --Still have units in platoon; do basic setup for checks:
                                                    --local iPlatoonMaxRange = M27Logic.GetUnitMaxGroundRange(oPlatoon[reftCurrentUnits])
                                                    --local iEnemySearchRadius = iPlatoonMaxRange * 2 --Will consider responses if any enemies get within 2 times the max range of platoon
                                                    --if iEnemySearchRadius < 40 then iEnemySearchRadius = 40 end
                                                    --Check this is also >= intel size:
                                                    --local iIntelRange = oPlatoon[reftCurrentUnits][1]:GetBlueprint().Intel.RadarRadius
                                                    --if iEnemySearchRadius < iIntelRange then iEnemySearchRadius = iIntelRange end
                                                    --GetNearbyEnemyData(oPlatoon, iEnemySearchRadius) --needed here for action if stuck to work

                                                    --Go through action determinants in order of priority (highest priority first):
                                                    --Check if platoon is stuck (unless are an intel platoon where would expect to be stationery)
                                                    if not(sPlatoonName == M27Overseer.sIntelPlatoonRef) then UpdatePlatoonActionIfStuck(oPlatoon) end
                                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Finished checking action for if stuck') end
                                                    if oPlatoon[refiCurrentAction] == nil then
                                                        --ACU specific: Get nearby reclaim if no enemies within ACU gun range (even if dont have gun)
                                                        if bDebugMessages == true then LOG(sFunctionRef..': will check for recliam if are an ACU platoon; oPlatoon[refbACUInPlatoon]='..tostring(oPlatoon[refbACUInPlatoon])..'; oPlatoon[refbConsiderReclaim]='..tostring(oPlatoon[refbConsiderReclaim])) end
                                                        if oPlatoon[refbACUInPlatoon] and oPlatoon[refbConsiderReclaim] == true then DetermineActionForNearbyReclaim(oPlatoon) end
                                                        --if oPlatoon[refiCurrentAction] == nil then
                                                            UpdatePlatoonActionForNearbyEnemies(oPlatoon)
                                                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Finished getting action for nearby enemies; action='..(oPlatoon[refiCurrentAction] or 'nil')) end
                                                            if oPlatoon[refiCurrentAction] == nil then
                                                                if not(sPlatoonName == M27Overseer.sIntelPlatoonRef) then --Dont want completion action for intel when it reaches the target path
                                                                    --Check for nearby reclaim and/or unclaimed mexes if are a builder platoon (e.g. ACU)
                                                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': About to check action for nearby mex, oPlatoon[refbConsiderMexes]='..tostring(oPlatoon[refbConsiderMexes])) end
                                                                    if oPlatoon[refbConsiderMexes] == true then DetermineActionForNearbyMex(oPlatoon) end
                                                                    if oPlatoon[refiCurrentAction] == nil then
                                                                        DetermineActionForNearbyHydro(oPlatoon)
                                                                        if oPlatoon[refiCurrentAction] == nil then
                                                                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': About to check action for nearby reclaim if non-ACU platoon, oPlatoon[refbConsiderReclaim]='..tostring(oPlatoon[refbConsiderReclaim])) end
                                                                            --Consider reclaim if non-ACU platoon (ACU platoon considered earlier)
                                                                            if not(oPlatoon[refbACUInPlatoon]) and oPlatoon[refbConsiderReclaim] == true then DetermineActionForNearbyReclaim(oPlatoon) end
                                                                            if oPlatoon[refiCurrentAction] == nil then
                                                                                if oPlatoon[refbACUInPlatoon] == true and not(oPlatoon[M27PlatoonTemplates.refbUsedByThreatDefender]) then
                                                                                    local bACUUnderwater = M27UnitInfo.IsUnitUnderwater(oPlatoon[refoFrontUnit])
                                                                                    if not(bACUUnderwater) then
                                                                                        DetermineIfACUShouldBuildPower(oPlatoon)
                                                                                        if oPlatoon[refiCurrentAction] == nil then DetermineIfACUShouldBuildLandFactory(oPlatoon) end
                                                                                    end
                                                                                    if bDebugMessages == true then LOG(sFunctionRef..': ACU is in platoon, action after checking to build power or land factory='..(oPlatoon[refiCurrentAction] or 'nil')) end
                                                                                    if oPlatoon[refiCurrentAction] == nil then
                                                                                        --Have we been assigned a mobile shield defender platoon whose nearest units are far away? If so fall back to meet up with them
                                                                                        RetreatToMobileShields(oPlatoon)
                                                                                        if bDebugMessages == true then LOG(sFunctionRef..': ACU is in platoon, action after checking if want to retreat to meet up with mobile shields='..(oPlatoon[refiCurrentAction] or 'nil')) end
                                                                                        if oPlatoon[refiCurrentAction] == nil then
                                                                                            --Do we want to get an upgrade?
                                                                                            DecideWhetherToGetACUUpgrade(aiBrain, oPlatoon)
                                                                                            if bDebugMessages == true then LOG(sFunctionRef..': Action after checking if want to get an upgrade='..(oPlatoon[refiCurrentAction] or 'nil')) end
                                                                                        end
                                                                                    end
                                                                                end
                                                                                if oPlatoon[refiCurrentAction] == nil then
                                                                                    --Check if have reached current or final destination (also update refiCurrentUnits and refiCurrentPathTarget):
                                                                                    if HasPlatoonReachedDestination(oPlatoon) == true then
                                                                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Platoon has reached current destination; oPlatoon[refiCurrentPathTarget] after reaching destination='..oPlatoon[refiCurrentPathTarget]..'; size of movement path='..table.getn(oPlatoon[reftMovementPath])) end
                                                                                        --Check if reached final destination:
                                                                                        if oPlatoon[refiCurrentPathTarget] > table.getn(oPlatoon[reftMovementPath]) then
                                                                                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': refiCurrentPathTarget='..oPlatoon[refiCurrentPathTarget]..'; movement path table size='..table.getn(oPlatoon[reftMovementPath])..'; have reached final destination') end
                                                                                            DeterminePlatoonCompletionAction(oPlatoon)
                                                                                        else
                                                                                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Not reached final destination, will reissue movement path') end
                                                                                            oPlatoon[refiCurrentAction] = refActionReissueMovementPath
                                                                                            ForceActionRefresh(oPlatoon)
                                                                                        end
                                                                                    end
                                                                                end
                                                                            end
                                                                        end
                                                                    end
                                                                end
                                                                if oPlatoon[refiCurrentAction] == nil then
                                                                    --[[
                                                                    --Check if deviated from normal action previously and so now need to reset
                                                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': no current action after cehcking if reached destination and for nearby enemies; will resume movement path') end
                                                                    if not(oPlatoon[reftPrevAction][1] == nil) then
                                                                        if oPlatoon[reftPrevAction][1] == refActionAttack or oPlatoon[reftPrevAction][1] == refActionMoveDFToNearestEnemy then
                                                                            --Were previously attacking; if no units nearby then cancel
                                                                            if oPlatoon[refiEnemiesInRange] + oPlatoon[refiEnemyStructuresInRange] == 0 then
                                                                                oPlatoon[refiCurrentAction] = refActionContinueMovementPath
                                                                            end
                                                                        end
                                                                    end ]]
                                                                    --If not stuck, no nearby enemies (that warrant an action) and not reached destination then continue movement path:
                                                                    oPlatoon[refiCurrentAction] = refActionContinueMovementPath

                                                                end
                                                            end
                                                        --end
                                                    else
                                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Current actoin is:'..oPlatoon[refiCurrentAction]) end
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

            --Action changes in specific scenarios:
            --Get a new movement path if ACU is returning to base and was running previously
            if oPlatoon[refbACUInPlatoon] and (oPlatoon[refiCurrentAction] == refActionReissueMovementPath or oPlatoon[refiCurrentAction] == refActionContinueMovementPath) then
                if oPlatoon[refbNeedToHeal] == false and oPlatoon[refbHavePreviouslyRun] == true and oPlatoon[reftMovementPath][1] == M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber] then
                    oPlatoon[refiCurrentAction] = refActionNewMovementPath
                end
            end

--==========REFRESH DELAY LOGIC
            --No need to re-issue command if just gave it (will refresh slower instead) - helps both with performance and to guard against stuttering:
            --DEBUG ONLY
            if bDebugMessages == true then
                LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': End of choosing action, will now ignore if action is unchanged from before')
                if oPlatoon[refiCurrentAction] == nil then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': iCurrentAction is nil')
                else LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': iCurrentAction='..oPlatoon[refiCurrentAction]) end

                if oPlatoon[reftPrevAction][1] == nil then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': 1st prev action is nil')
                else LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': 1st prev action='..oPlatoon[reftPrevAction][1]) end
            end

            local bRefreshAction = true
            local iRefreshActionThreshold = 1 --If < this then won't refresh (subject to specific logic that might make this to always have a refresh); resets to 0 meaning will be this number + 1 cycles
            if oPlatoon[refbCombatHoverInPlatoon] then iRefreshActionThreshold = 5 end
            local bConsideredRefreshAlready = false
            --=======Ignore action in certain cases (e.g. we only just gave that action)
            if oPlatoon[refiCurrentAction] == refActionUpgrade then iRefreshActionThreshold = 10 end

            --special case for movement paths:
            if oPlatoon[refiCurrentAction] == refActionContinueMovementPath then
                if oPlatoon[reftPrevAction][1] == refActionNewMovementPath or oPlatoon[reftPrevAction][1] == refActionReissueMovementPath then
                    --Refresh every 6 cycles (instead of default of 2)
                    if bDebugMessages == true then
                        local iCurCycle = oPlatoon[refiRefreshActionCount]
                        if iCurCycle == nil then iCurCycle = 'nil' end
                        LOG(sFunctionRef..': Prev action was new movement path or refresh so only refresh on a much slower basis; oPlatoon[refiRefreshActionCount]='..iCurCycle)
                    end
                    iRefreshActionThreshold = 5
                    if oPlatoon[refbCombatHoverInPlatoon] then iRefreshActionThreshold = 10 end
                    if oPlatoon[M27PlatoonTemplates.refbRequiresUnitToFollow] == true or oPlatoon[M27PlatoonTemplates.refbRequiresSingleLocationToGuard] == true then
                        if oPlatoon[M27PlatoonTemplates.refbRequiresUnitToFollow] == true then
                            iRefreshActionThreshold = 1
                            if oPlatoon[refbCombatHoverInPlatoon] then iRefreshActionThreshold = 5 end
                        else iRefreshActionThreshold = 20 end
                    end
                    if oPlatoon[refiRefreshActionCount] < iRefreshActionThreshold then bRefreshAction = false end
                end
            end
            if oPlatoon[reftPrevAction][1] == oPlatoon[refiCurrentAction] then
                if oPlatoon[M27PlatoonTemplates.refbRequiresUnitToFollow] == true or oPlatoon[M27PlatoonTemplates.refbRequiresSingleLocationToGuard] == true then
                    if oPlatoon[refiCurrentAction] == refActionRun or oPlatoon[refiCurrentAction] == refActionTemporaryRetreat then
                       iRefreshActionThreshold = 1
                        if oPlatoon[refbCombatHoverInPlatoon] then iRefreshActionThreshold = 5 end
                    else
                        if oPlatoon[M27PlatoonTemplates.refbRequiresSingleLocationToGuard] == true then iRefreshActionThreshold = 20
                        else
                            bRefreshAction = true
                        end
                    end
                else
                    if bDebugMessages == true then LOG('Prev action is same as current action, will set refreshaction to false unless due a refresh') end
                    if oPlatoon[refiCurrentAction] == refActionContinueMovementPath then
                        --Don't refresh if are continuing movement path unless are escorting
                        bRefreshAction = false
                    else
                        local bBuildingOrReclaimingLogic = false
                        --Building and reclaiming - base refresh on whether any units are building/reclaiming
                        if oPlatoon[refiCurrentAction] == refActionBuildMex or oPlatoon[refiCurrentAction] == refActionAssistConstruction or oPlatoon[refiCurrentAction] == refActionBuildLandFactory or oPlatoon[refiCurrentAction] == refActionBuildInitialPower then
                            bBuildingOrReclaimingLogic = true
                            bRefreshAction = true
                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Checking if any buidlers ahve unit state building') end
                            for iBuilder, oBuilder in oPlatoon[reftBuilders] do
                                --Units can build something by 'repairing' it, so check for both unit states:
                                if oBuilder:IsUnitState('Building') == true or oBuilder:IsUnitState('Repairing') == true then
                                    oPlatoon[refbMovingToBuild] = false
                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Builder is building, so dont refresh action') end
                                    bRefreshAction = false
                                    break
                                elseif oBuilder:IsUnitState('Guarding') == true then
                                    --might be assisting construction of a unit/building, or just assisting an engineer - bellow will jsut check for the former
                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Builder is guarding - check the unit being guarded') end
                                    if oBuilder.GetGuardedUnit then
                                        local oBeingBuilt = oBuilder:GetGuardedUnit()
                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Obtained valid reference to guarded unit') end
                                        if oBeingBuilt.GetFractionComplete then
                                            if oBeingBuilt:GetFractionComplete() < 1 then
                                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Builder is assisting something that is being built, so dont refresh action') end
                                                bRefreshAction = false
                                                break
                                            end
                                        end
                                    end
                                elseif oBuilder:IsUnitState('Moving') == true then
                                    iRefreshActionThreshold = 10 --Might be trying to build ontop of current position
                                else
                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Considering whether to ignore refresh - unit state='..M27Logic.GetUnitState(oBuilder)) end
                                end
                            end
                        elseif oPlatoon[refiCurrentAction] == refActionReclaimTarget or oPlatoon[refiCurrentAction] == refActionReclaimAllNearby then
                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Action is to reclaim, First reclaimer in platoon status='..M27Logic.GetUnitState(oPlatoon[reftReclaimers][1])) end
                            bBuildingOrReclaimingLogic = true
                            bRefreshAction = true
                            iRefreshActionThreshold = 1
                            if oPlatoon[refiCurrentAction] == refActionReclaimAllNearby then iRefreshActionThreshold = 0 end --The reclaimallnearby logic already checks if position has moved so dont need a delay
                            for iReclaimer, oReclaimer in oPlatoon[reftReclaimers] do
                                if not(oReclaimer.Dead) then
                                    if oReclaimer:IsUnitState('Reclaiming') == true then
                                        if bDebugMessages == true then LOG(sFunctionRef..sPlatoonName..oPlatoon[refiPlatoonCount]..': Unit is reclaiming so dont want to refresh') end
                                        bRefreshAction = false
                                        break
                                    end
                                end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': bRefreshAction after checking if unit state is reclaiming='..tostring(bRefreshAction)) end
                        elseif oPlatoon[refiCurrentAction] == refActionAttackSpecificUnit then
                            --Has the unit changed?
                            if oPlatoon[refoTemporaryAttackTarget] == oPlatoon[refoPrevTemporaryAttackTarget] then
                                bRefreshAction = false
                            else
                                bRefreshAction = true
                                oPlatoon[refiRefreshActionCount] = iRefreshActionThreshold --to make sure we refresh
                            end
                        end

                        if bRefreshAction == true then
                            --Refresh every 2 cycles:
                            if oPlatoon[refiRefreshActionCount] < iRefreshActionThreshold then bRefreshAction = false end

                            if bDebugMessages == true then
                                if oPlatoon[refiRefreshActionCount] == nil then oPlatoon[refiRefreshActionCount] = 0 end
                                LOG('RefreshCount='..oPlatoon[refiRefreshActionCount]..'; bRefreshAction='..tostring(bRefreshAction))
                            end
                        end
                    end
                end
            else
                if bDebugMessages == true then LOG('Prev action is different to current action, so will refresh; bRefreshAction='..tostring(bRefreshAction)) end
            end


            --Check for forced refresh:
            if bRefreshAction == false then
                if oPlatoon[refbForceActionRefresh] == true then
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Forced refresh of platoon action activated') end
                    oPlatoon[refbForceActionRefresh] = false
                    oPlatoon[refiGameTimeOfLastRefresh] = GetGameTimeSeconds()
                    bRefreshAction = true
                end
            end


            --Action the decision on whether to refresh or not
            if bRefreshAction == true then
                oPlatoon[refiRefreshActionCount] = 0
                if oPlatoon[refiCurrentAction] == refActionContinueMovementPath then oPlatoon[refiCurrentAction] = refActionReissueMovementPath end
            else
                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': '..sFunctionRef..': Ignoring current action as is same as prev action so setting to nil') end
                oPlatoon[refiCurrentAction] = nil
                if oPlatoon[refiRefreshActionCount] == nil then oPlatoon[refiRefreshActionCount] = 0 end
                oPlatoon[refiRefreshActionCount] = oPlatoon[refiRefreshActionCount] + 1
            end



            if bDebugMessages == true then
              --M27EngineerOverseer.TEMPTEST(aiBrain, 'Determineplatoon action - end of code')
                if oPlatoon[refiCurrentAction] == nil then
                    LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': '..sFunctionRef..': End of code; refiCurrentAction=nil')
                else LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': '..sFunctionRef..': End of code; refiCurrentAction='..oPlatoon[refiCurrentAction])
                end
                if oPlatoon[refiExtraAction] == nil then
                    LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..':'..sFunctionRef..': End of code, refiExtraAction is nil')
                else LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..':'..sFunctionRef..': End of code, refiExtraAction is '..oPlatoon[refiExtraAction])
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ReturnToBase(oPlatoon, iOnlyGoThisFarTowardsBase, bDontClearActions, bUseTemporaryMoveLocation)
    --Resets movement path so it is only going to return to base (meaning it will be treated as reaching final destination when it gets there)
    --iOnlyGoThisFarTowardsBase - if nil then go all the way to base, otherwise go x distance from current position
    --bUseTemporaryMoveLocation - if true then will assign a temporary move location instead of replacing the current move location
    local sFunctionRef = 'ReturnToBase'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local sPlatoonName = oPlatoon:GetPlan()
    --if sPlatoonName == 'M27ScoutAssister' then bDebugMessages = true end
    --if sPlatoonName == 'M27MAAAssister' then bDebugMessages = true end
    local aiBrain = oPlatoon:GetBrain()
    local iArmyStartNumber = aiBrain.M27StartPositionNumber
    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': 1s loop: Running away - moving to start position') end
    if bDontClearActions == nil then bDontClearActions = false end
    if bDontClearActions == false then IssueClearCommands(GetPlatoonUnitsOrUnitCount(oPlatoon, reftCurrentUnits, false, true)) end
    if bUseTemporaryMoveLocation == nil then bUseTemporaryMoveLocation = false end
    oPlatoon:SetPlatoonFormationOverride('GrowthFormation')

    oPlatoon[reftTemporaryMoveTarget] = {}
    if not(bUseTemporaryMoveLocation) then oPlatoon[reftMovementPath] = {} end
    local tNewDestination = {}
    if iOnlyGoThisFarTowardsBase == nil then
        if bDebugMessages == true then LOG(sPlatoonName..': Going to go all the way back to base') end
        tNewDestination = M27MapInfo.PlayerStartPoints[iArmyStartNumber]
    else
        local tPlatoonPosition = GetPlatoonFrontPosition(oPlatoon)
        local iDistToStart = M27Utilities.GetDistanceBetweenPositions(tPlatoonPosition, M27MapInfo.PlayerStartPoints[iArmyStartNumber])
        if bDebugMessages == true then LOG(sPlatoonName..': iDistToStart='..iDistToStart..'; iOnlyGoThisFarTowardsBase='..iOnlyGoThisFarTowardsBase) end
        if iOnlyGoThisFarTowardsBase >= iDistToStart then tNewDestination = M27MapInfo.PlayerStartPoints[iArmyStartNumber]
        else
            --GetPositionNearTargetInSamePathingGroup(tStartPos, tTargetPos, iDistanceFromTarget, iAngleBase, oPathingUnit, iNearbyMethodIfBlocked, bTrySidePositions)
            --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
            local oPathingUnit = GetPathingUnit(oPlatoon, oPlatoon[refoPathingUnit], true)
            if oPathingUnit and not(oPathingUnit.Dead) then
                tNewDestination = GetPositionNearTargetInSamePathingGroup(tPlatoonPosition, M27MapInfo.PlayerStartPoints[iArmyStartNumber], iDistToStart - iOnlyGoThisFarTowardsBase, 0, oPathingUnit, 1, true)
                --M27Utilities.MoveTowardsTarget(tPlatoonPosition, M27MapInfo.PlayerStartPoints[iArmyStartNumber], iOnlyGoThisFarTowardsBase, 0)
                if tNewDestination == nil then tNewDestination =  M27MapInfo.PlayerStartPoints[iArmyStartNumber] end
                if bDebugMessages == true then LOG(sPlatoonName..': Sent order to only go part of the way back towawrds base') end
            else
                if oPlatoon then
                    if bDebugMessages == true then LOG(sPlatoonName..': ReturnToBase: Were returning to base but pathing unit is nil or dead so disbanding') end
                    oPlatoon[refiCurrentAction] = refActionDisband end
            end
        end
    end
    if oPlatoon[M27PlatoonTemplates.refbAttackMove] == true then
        IssueAggressiveMove(GetPlatoonUnitsOrUnitCount(oPlatoon, reftCurrentUnits, false, true), tNewDestination)
    else
        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Sending MoveToLocation to player start') end
        --oPlatoon:MoveToLocation(M27MapInfo.PlayerStartPoints[iArmyStartNumber], false) end
        IssueMove(GetPlatoonUnitsOrUnitCount(oPlatoon, reftCurrentUnits, false, true), tNewDestination)
    end

    if bUseTemporaryMoveLocation == true then
        oPlatoon[reftTemporaryMoveTarget] = tNewDestination
    else
        oPlatoon[reftMovementPath] = {}
        oPlatoon[reftMovementPath][1] = tNewDestination
        oPlatoon[refiCurrentPathTarget] = 1
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    --oPlatoon[refiLastPathTarget] = 1
    --WaitSeconds(2)
end

function GetNewMovementPath(oPlatoon, bDontClearActions)
    --Sets the movement path variable for oPlatoon and then tells it to move along this
    --bDontClearActions: Set to true if want to add the movement actions to existing orders (e.g. if have issued secondary action such as overcharge)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetNewMovementPath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bPlatoonNameDisplay = false
    if M27Config.M27ShowUnitNames == true then bPlatoonNameDisplay = true end
    local sPlatoonName = oPlatoon:GetPlan()

    --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end
    --if sPlatoonName == 'M27ScoutAssister' then bDebugMessages = true end
    --if sPlatoonName == 'M27MAAAssister' then bDebugMessages = true end
    --if sPlatoonName == 'M27EscortAI' then bDebugMessages = true end
    --if sPlatoonName == 'M27CombatPatrolAI' then bDebugMessages = true end
    --if sPlatoonName == 'M27IndirectDefender' then bDebugMessages = true end
    --if sPlatoonName == 'M27RetreatingShieldUnits' then bDebugMessages = true end
    --if sPlatoonName == 'M27MobileShield' then bDebugMessages = true end

    local aiBrain = oPlatoon:GetBrain()
  --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Start of code') end
    local bDisbandAsNoUnits = false
    local bDontActuallyMove = false
    oPlatoon[refiCurrentPathTarget] = 1 --Redundancy, think put this elsewhere as well
    --If have ACU in the platoon then remove it unless its the ACU platoon
    if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': A'..refActionNewMovementPath) end
    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': GettingNewMovementPath') end
    local tCurPosition = GetPlatoonFrontPosition(oPlatoon)
    local bDontGetNewPath = false

    if oPlatoon[M27PlatoonTemplates.refbRequiresUnitToFollow] == true or oPlatoon[M27PlatoonTemplates.refbRequiresSingleLocationToGuard] == true then
        if bDebugMessages == true then LOG(sFunctionRef..':'..sPlatoonName..': About to refresh support platoon movement path') end
        RefreshSupportPlatoonMovementPath(oPlatoon)
    else

        local bHaveEmptyMovementPath = true
        if M27Utilities.IsTableEmpty(oPlatoon[reftMovementPath]) == false then
            for iPath, tPath in oPlatoon[reftMovementPath] do
                if M27Utilities.IsTableEmpty(tPath) == false then
                    bHaveEmptyMovementPath = false
                    break
                end
            end
        end
        if bHaveEmptyMovementPath == true then
            if oPlatoon[reftMovementPath] == nil then oPlatoon[reftMovementPath] = {} end
            if oPlatoon[reftMovementPath][1] == nil then oPlatoon[reftMovementPath][1] = {} end
        else
            --Have we already got a movement path and no previous action (e.g. defender platoon created and assigned its movement path)
            if M27Utilities.IsTableEmpty(oPlatoon[reftPrevAction]) == true then
              --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Changing action to reissue movement path') end
                bDontGetNewPath = true
                oPlatoon[refiCurrentAction] = refActionReissueMovementPath
                if bDebugMessages == true then LOG(sFunctionRef..':'..sPlatoonName..oPlatoon[refiPlatoonCount]..': Have no prev action and ahve a valid movement path='..repr(oPlatoon[reftMovementPath])) end
            end
        end

        if bDontGetNewPath == false then
            if sPlatoonName == 'M27LargeAttackForce' then
                --Choose mex in enemy base as the end destination
                oPlatoon[reftMovementPath] = M27Logic.GetMexRaidingPath(oPlatoon, 0, 15, 50, true)
                --oPlatoon[refiLastPathTarget] = table.getn(oPlatoon[reftMovementPath])
            elseif sPlatoonName == 'M27AttackNearestUnits' then
                local iEnemyStartNumber = M27Logic.GetNearestEnemyStartNumber(aiBrain)
                if iEnemyStartNumber == nil then
                    LOG(sFunctionRef..':'..sPlatoonName..': EnemyStartNumber=nil, ERROR unless enemy dead')
                    oPlatoon[reftMovementPath][1] = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                else
                    local tTargetBase = M27MapInfo.PlayerStartPoints[iEnemyStartNumber]
                    if oPlatoon[reftMovementPath][1] == tTargetBase then
                        --Already targeting nearest enemy - go back to own base instead
                        oPlatoon[reftMovementPath][1] = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                    else
                        oPlatoon[reftMovementPath][1] = tTargetBase
                    end
                end
                oPlatoon[refiCurrentPathTarget] = 1
            elseif sPlatoonName == 'M27IndirectSpareAttacker' then
                local tTargetBase = M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]
                oPlatoon[refiCurrentPathTarget] = 1
                if oPlatoon[reftMovementPath] and oPlatoon[reftMovementPath][1] and oPlatoon[reftMovementPath][1][1] == tTargetBase[1] and oPlatoon[reftMovementPath][1][3] == tTargetBase[3] then
                    --Are already targetting enemy base - check if we're close to it
                    if M27Utilities.GetDistanceBetweenPositions(GetPlatoonFrontPosition(oPlatoon), tTargetBase) <= 15 then
                        --Close to enemy base so switch to attack nearest units
                        oPlatoon[reftMovementPath][1] = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                        if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': A'..refActionUseAttackAI) end
                        if bDebugMessages == true then LOG(sFunctionRef..': Updating indirect spare attacker to use attacknearest AI as are near enemy base') end
                        oPlatoon:SetAIPlan('M27AttackNearestUnits')
                    else
                        --No need to change path as already targetting enemy base but not near it
                    end
                else
                    --Not targetting enemy base, so target it
                    if bDebugMessages == true then LOG(sFunctionRef..': Targetting enemy base') end
                    oPlatoon[reftMovementPath][1] = tTargetBase
                end
        --oPlatoon[refiLastPathTarget] = 1

            elseif sPlatoonName == M27Overseer.sIntelPlatoonRef then
                --Overseer sets movement path for itnel platoons, so just set initial move position to current position if this is called
                if M27Utilities.IsTableEmpty(oPlatoon[reftMovementPath][1]) == true then
                    oPlatoon[reftMovementPath][1] = tCurPosition
                end
            elseif sPlatoonName == 'M27CombatPatrolAI' then
                --patrol near midpoint of map/mex near there
                oPlatoon[reftMovementPath] = M27MapInfo.GetMexPatrolLocations(aiBrain)
            elseif oPlatoon[refbACUInPlatoon] == true then
              --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Have got new path, about to update platoon units') end
                if sPlatoonName == M27Overseer.sDefenderPlatoonRef or sPlatoonName == 'M27IndirectDefender' then
                    --Want to disband ACU platoon/have it use the ACU main platoon
                    RemoveUnitsFromPlatoon(oPlatoon, { M27Utilities.GetACU(aiBrain)}, false)
                    local oPlatoonUnits = oPlatoon:GetPlatoonUnits()
                    if M27Utilities.IsTableEmpty(oPlatoonUnits) == true then
                        if bDebugMessages == true then LOG(sFunctionRef..':'..sPlatoonName..': Disbanding platoon instead of new path as no units in it') end
                        bDisbandAsNoUnits = true
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': setting new movement path for M27ACUMain') end
                    --Do we want to assist a hydro?
                    local bMoveToHydro = false
                    --Check if is a hydro near the ACU
                    if M27Conditions.ACUShouldAssistEarlyHydro(aiBrain) == true then
                        --Do we have power already? Check have >= 10 per tick (so 100)
                        if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] <= 10 then
                            bMoveToHydro = true
                        end
                    end
                  --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Considered whether should assist hydro') end
                    if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..': bMoveToHydro='..tostring(bMoveToHydro)) end
                    if bMoveToHydro == true then
                        --Get nearest hydro location:
                        local tNearestHydro = {}
                        local iMinHydroDistance = 1000
                        local iCurHydroDistance
                        for iHydro, tHydroPos in M27MapInfo.HydroPoints do
                            iCurHydroDistance = M27Utilities.GetDistanceBetweenPositions(tHydroPos, tCurPosition)
                            if iCurHydroDistance < iMinHydroDistance then
                                tNearestHydro = tHydroPos
                                iMinHydroDistance = iCurHydroDistance
                            end
                        end
                        --Are we already in range of the hydro?
                        local iBuildDistance = M27Utilities.GetACU(aiBrain):GetBlueprint().Economy.MaxBuildDistance
                        local iHydroSize = M27UnitInfo.GetBuildingSize('UAB1102')[1]
                        if iMinHydroDistance <= (iBuildDistance + iHydroSize*0.5) then
                            --Give a dummy path so dont call this again immediately
                            oPlatoon[reftMovementPath] = {}
                            oPlatoon[reftMovementPath][1] = tCurPosition
                            oPlatoon[refiCurrentPathTarget] = 1
                            if M27Utilities.GetACU(aiBrain):IsUnitState('Building') == true or M27Utilities.GetACU(aiBrain):IsUnitState('Repairing') == true then
                                --Do nothing
                                bDontActuallyMove = true
                                if bDebugMessages == true then LOG(sFunctionRef..': ACU is already busy building or assisting so wont do anything') end
                            else
                                --Is the hydro being constructed? If so then assist it
                                local tHydrosInArea = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryHydro, tNearestHydro,  iHydroSize, 'Ally')
                                local oNearestHydro
                                if M27Utilities.IsTableEmpty(tHydrosInArea) == false then
                                    oNearestHydro = tHydrosInArea[1]
                                    if oNearestHydro.GetFractionComplete and oNearestHydro:GetFractionComplete() < 1 then
                                        IssueGuard(oPlatoon[reftBuilders], oNearestHydro)
                                    end
                                end
                                bDontActuallyMove = true
                            end
                        else
                            oPlatoon[reftMovementPath] = {}
                            oPlatoon[reftMovementPath][1] = {}

                            if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..': about to call MoveNearConstruction') end
                            --MoveNearConstruction(aiBrain, oBuilder, tLocation, sBlueprintID, iBuildDistanceMod, bReturnMovePathInstead, bUpdatePlatoonMovePath, bReturnNilIfAlreadyMovingNearConstruction)
                            oPlatoon[reftMovementPath][1] = MoveNearConstruction(aiBrain, M27Utilities.GetACU(aiBrain), tNearestHydro, 'UAB1102', 0, true, false, false)
                            if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..': Moving to hydro, reftMovementPath='..repr(oPlatoon[reftMovementPath])..'; platoon position='..repr(tCurPosition)) end
                        end
                    else
                        --Are we before the gun upgrade? then Choose priority expansion target
                        if M27Conditions.DoesACUHaveGun(aiBrain, true) == false then
                          --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Considered whether ACU has gun yet') end
                            if bDebugMessages == true then LOG(sFunctionRef..': ACU doesnt have gun yet, will get expansion movement path') end
                            oPlatoon[reftMovementPath] = M27Logic.GetPriorityExpansionMovementPath(aiBrain, GetPathingUnit(oPlatoon))
                            if oPlatoon[reftMovementPath] == nil then
                                refiCurrentAction = refActionDisband
                                if bDebugMessages == true then LOG(sFunctionRef..': Expansion movement path is nil so disbanding') end
                            else
                              --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Will be expanding with ACU') end
                                if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..': Expanding, reftMovementPath='..repr(oPlatoon[reftMovementPath])..'; platoon position='..repr(tCurPosition)) end
                            end
                        else
                            --Get enemy base
                            local iEnemyStartNumber = M27Logic.GetNearestEnemyStartNumber(aiBrain)
                            if iEnemyStartNumber == nil then
                                LOG(sFunctionRef..': ERROR unless enemy dead as iEnemyStartNumber is nil')
                                oPlatoon[reftMovementPath][1] = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                            else
                                local tTargetBase = M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]
                                local bSwitchToHome = false
                                if oPlatoon[reftMovementPath][1] == tTargetBase then
                                    --Already targeting nearest enemy - if we're within 5 of it then go back to own base instead
                                    if M27Utilities.GetDistanceBetweenPositions(tTargetBase, M27Utilities.GetACU(aiBrain):GetPosition()) <= 5 then bSwitchToHome = true end
                                end
                                if bSwitchToHome == true then oPlatoon[reftMovementPath][1] = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                                else oPlatoon[reftMovementPath][1] = tTargetBase
                                end
                            end
                            oPlatoon[refiCurrentPathTarget] = 1
                        end
                    end
                end
            elseif sPlatoonName == 'M27RetreatingShieldUnits' then
                oPlatoon[reftMovementPath][1] = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                oPlatoon[refiCurrentPathTarget] = 1
                if bDebugMessages == true then LOG(sFunctionRef..': Have retreating shield units so setting movement path to player start') end
            else
                if bDisbandAsNoUnits == false and oPlatoon[refbACUInPlatoon] == false then
                    --Choose mexes away from enemy base
                    oPlatoon[reftMovementPath] = M27Logic.GetMexRaidingPath(oPlatoon, 50)
                    if M27Utilities.IsTableEmpty(oPlatoon[reftMovementPath]) then
                        bDisbandAsNoUnits = true
                        LOG('WARNING -  RaidingPath returned nil movement path so disbanding platoon')
                    end
                    --oPlatoon[refiLastPathTarget] = table.getn(oPlatoon[reftMovementPath])
                end
            end
        end
        if bDisbandAsNoUnits == true then
            if bDebugMessages == true then LOG(sFunctionRef..':'..sPlatoonName..oPlatoon[refiPlatoonCount]..': disbanding') end
            if oPlatoon then oPlatoon[refiCurrentAction] = refActionDisband end --if oPlatoon and oPlatoon.PlatoonDisband then oPlatoon:PlatoonDisband() end
        else
            --Large attack AI: get nearby raiders, attackers and defenders to merge (unless theyre closer to enemy base than ours)
            if sPlatoonName == 'M27LargeAttackForce' then
                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': About to call platoon mergers; ReftMovementPath[1][1]='..oPlatoon[reftMovementPath][1][1]) end
                MergeWithPlatoonsOnPath(oPlatoon, 'M27MexRaiderAI', true)
                MergeWithPlatoonsOnPath(oPlatoon, M27Overseer.sDefenderPlatoonRef, true)
                MergeWithPlatoonsOnPath(oPlatoon, sPlatoonName, true)
                --Update move order with the merge location
                table.insert(oPlatoon[reftMovementPath], 1, oPlatoon[reftMergeLocation])
                --oPlatoon[refiLastPathTarget] = table.getn(oPlatoon[reftMovementPath])
                oPlatoon:Stop()
                oPlatoon:SetPlatoonFormationOverride('AttackFormation')
            end
          --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Getting near end of code now') end
            if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': A'..refActionNewMovementPath) end
            if bDebugMessages == true then LOG(sFunctionRef..sPlatoonName..oPlatoon[refiPlatoonCount]..': bDontActuallyMove='..tostring(bDontActuallyMove)..'; considering whether to move along path') end
            if bDontActuallyMove == false then
                if M27Utilities.IsTableEmpty(oPlatoon[reftMovementPath]) == true then
                    LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': WARNING - about to issue a movealongpath order, but there is no movement path; will set movement destination to a random priority mex, or (if there is none) the enemy base')
                    oPlatoon[reftMovementPath] = {}
                    oPlatoon[reftMovementPath][1] = {}
                    oPlatoon[refiCurrentPathTarget] = 1
                    if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftHighPriorityMexes]) == false then
                        local iMaxMexPriorityTargets = table.getn(aiBrain[M27MapInfo.reftHighPriorityMexes])
                        oPlatoon[reftMovementPath][1] = aiBrain[M27MapInfo.reftHighPriorityMexes][math.random(1, iMaxMexPriorityTargets)]
                    else
                        local iEnemyStartNumber = M27Logic.GetNearestEnemyStartNumber(aiBrain)
                        if iEnemyStartNumber == nil then
                            LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..':ERROR - enemy start number is nil if theyre not dead then something is wrong')
                            oPlatoon[reftMovementPath][1] = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                        else
                            oPlatoon[reftMovementPath][1] = M27MapInfo.PlayerStartPoints[iEnemyStartNumber]
                        end
                    end
                end


                --move (or attack-move if specified for hte platoon)
                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': About to move along path, oPlatoon[reftMovementPath]='..repr(oPlatoon[reftMovementPath])..'; bDontClearActions='..tostring(bDontClearActions)) end
                MoveAlongPath(oPlatoon, oPlatoon[reftMovementPath], oPlatoon[M27PlatoonTemplates.refbAttackMove], 1, bDontClearActions)
            end
        end
        --DoesACUHaveGun(aiBrain, bROFAndRange, oAltACU)
        if oPlatoon[refbACUInPlatoon] == true and M27Conditions.DoesACUHaveGun(aiBrain, false) == false then
            --Update engineer tracker varaibles to factor in that ACU expected to build mexes
          --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to call function to ACU action tracker') end
            M27EngineerOverseer.UpdateActionsForACUMovementPath(oPlatoon[reftMovementPath], aiBrain, M27Utilities.GetACU(aiBrain), oPlatoon[refiCurrentPathTarget])
          --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Finished calling function to ACU action tracker') end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ReissueMovementPath(oPlatoon, bDontClearActions)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReissueMovementPath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bPlatoonNameDisplay = false
    if M27Config.M27ShowUnitNames == true then bPlatoonNameDisplay = true end
    local sPlatoonName = oPlatoon:GetPlan()

    --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end
    --if sPlatoonName == 'M27LargeAttackForce' then bDebugMessages = true end
    --if sPlatoonName == 'M27ScoutAssister' then bDebugMessages = true end
    --if sPlatoonName == 'M27MAAAssister' then bDebugMessages = true end
    --if sPlatoonName == 'M27EscortAI' then bDebugMessages = true end

    if M27Utilities.IsTableEmpty(oPlatoon[reftMovementPath]) == true then LOG(sFunctionRef..': WARNING - have been told to reissue movement path but tmovementpath is empty; will get new movement path instead')
        GetNewMovementPath(oPlatoon, bDontClearActions)
    else
        if oPlatoon[M27PlatoonTemplates.refbRequiresUnitToFollow] == true or oPlatoon[M27PlatoonTemplates.refbRequiresSingleLocationToGuard] == true then
            if bDebugMessages == true then LOG(sFunctionRef..': about to refresh support movement path') end
            RefreshSupportPlatoonMovementPath(oPlatoon)
        else
            if oPlatoon[refiCurrentPathTarget] == nil then
                LOG(sFunctionRef..': WARNING - have been told to reissue movement path but CurrentPathTarget is nil; will get first entry in movement path instead')
                oPlatoon[refiCurrentPathTarget] = 1
            end
            if oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]] == nil then
                LOG(sFunctionRef..': WARNING - have been told to reissue movement path, but movement path for iCurrentPathTarget'..oPlatoon[refiCurrentPathTarget]..' is nil, will get new movement path instead')
                GetNewMovementPath(oPlatoon, bDontClearActions)
            else
                if bDebugMessages == true then
                    if sPlatoonName == nil then LOG(sFunctionRef..': Warning - sPlatoonName is nil') end
                    if oPlatoon[refiPlatoonCount] == nil then LOG(sFunctionRef..': Warning: PlatoonCount is nil') end
                end

                --General (all platoons) - are we closer to the current point on the path or the 2nd?
                local bGetNewPathInstead = false
                local iPossibleMovementPaths = table.getn(oPlatoon[reftMovementPath])
                local tPlatoonCurPos = {}
                local iDistToCurrent, iDistToNext, iDistBetween1and2
                local iLoopCount = 0
                local iMaxLoopCount = 100
                if bDebugMessages == true then LOG(sFunctionRef..': About to check if we are closer to the next path than the current path target; iPossibleMovementPaths='..iPossibleMovementPaths..'; oPlatoon[refiCurrentPathTarget]='..oPlatoon[refiCurrentPathTarget]) end
                if iPossibleMovementPaths <= oPlatoon[refiCurrentPathTarget] then
                    --Only 1 movement path point left - if are ACU then get a new movement path unless are in defender platoon or prev action was movement related
                    if oPlatoon[refbACUInPlatoon] == true and not(sPlatoonName==M27Overseer.sDefenderPlatoonRef) then
                        if bDebugMessages == true then
                            local iCount = oPlatoon[refiPlatoonCount]
                            if iCount == nil then iCount = 0 end
                            local iPrevAction = oPlatoon[reftPrevAction][1]
                            if iPrevAction == nil then iPrevAction = 0 end
                            LOG(sPlatoonName..iCount..':'..sFunctionRef..': ACU in platoon with only 1 movement path, so will get new movement path depending on if cur target is closer to our base ir not, prevAction='..iPrevAction)
                        end
                        local aiBrain = oPlatoon:GetBrain()
                        tPlatoonCurPos = GetPlatoonFrontPosition(oPlatoon)
                        local iACUDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tPlatoonCurPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                        local iTargetDistanceToStart = M27Utilities.GetDistanceBetweenPositions(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                        if iACUDistanceToStart > iTargetDistanceToStart then
                            bGetNewPathInstead = true
                        end
                    end
                else
                    tPlatoonCurPos = GetPlatoonFrontPosition(oPlatoon)
                    --If we check the next point in the movement path, is it closer than the current point?
                    while iPossibleMovementPaths > oPlatoon[refiCurrentPathTarget] do
                        iLoopCount = iLoopCount + 1
                        if iLoopCount > iMaxLoopCount then M27Utilities.ErrorHandler('Infinite loop') break end

                        iDistToCurrent = M27Utilities.GetDistanceBetweenPositions(tPlatoonCurPos, oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]])
                        iDistToNext = M27Utilities.GetDistanceBetweenPositions(tPlatoonCurPos, oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget] + 1])
                        iDistBetween1and2 = M27Utilities.GetDistanceBetweenPositions(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]], oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget] + 1])
                        if bDebugMessages == true then
                            LOG(sFunctionRef..'iLoopCount='..iLoopCount..'; tPlatoonCurPos='..repr(tPlatoonCurPos)..'; CurMovePath='..repr(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]]))
                            LOG('Next movement path='..repr(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget] + 1]))
                            LOG('iDistToCurrent='..iDistToCurrent..'; iDistToNext='..iDistToNext..'; iDistBetween1and2='..iDistBetween1and2)
                        end
                        if iDistToNext < iDistBetween1and2 then
                            if bDebugMessages == true then LOG(sFunctionRef..': Next target is closer than current so skipping current') end
                            oPlatoon[refiCurrentPathTarget] = oPlatoon[refiCurrentPathTarget] + 1
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Next target isnt closer than target so will stop looking') end
                            break
                        end
                    end
                end
                if bGetNewPathInstead == true then
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..':'..sFunctionRef..': Are getting new movement path instead') end
                    GetNewMovementPath(oPlatoon, bDontClearActions)
                else
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': refActionReissueMovementPath: About to update platoon name and movement path, current target='..oPlatoon[refiCurrentPathTarget]..'; position of this='..repr(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]])..'PlatoonUnitCount='..table.getn(oPlatoon[reftCurrentUnits])..'; plaotonaction='..oPlatoon[refiCurrentAction]) end
                    if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': A'..refActionReissueMovementPath) end
                    MoveAlongPath(oPlatoon, oPlatoon[reftMovementPath], oPlatoon[M27PlatoonTemplates.refbAttackMove], oPlatoon[refiCurrentPathTarget], bDontClearActions)
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function HoldAndReenableFire(tUnitsToSynchronise, iMaxTimeToHold, iTimeToSpreadOver)
    --Hold fire to ensure are aligned
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'HoldAndReenableFire'
    local iHoldFireState = 1
    local iReturnFireState = 0

    local iLowestWeaponPercent = 1
    local iCurWeaponPercent
    local oCurWeapon
    local oCurBP

    for iUnit, oUnit in tUnitsToSynchronise do
        --oCurBP = oUnit:GetBlueprint()
        --[[
            if oUnit.GetWeapon then
            oCurWeapon = oUnit:GetWeapon(1)
            iCurWeaponPercent = oCurWeapon:GetFireClockPct()
            if iCurWeaponPercent < iLowestWeaponPercent then iCurWeaponPercent = iLowestWeaponPercent end
            if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..'; iCurWeaponPercent='..iCurWeaponPercent..'; can weapon fire='..tostring(oCurWeapon:CanFire())) end
        end --]]

        oUnit:SetFireState(iHoldFireState)
        if bDebugMessages == true then M27Utilities.DrawLocation(oUnit:GetPosition(), nil, 1, 50) end
    end
    --local iTimeToHold = iMaxTimeToHold * (1 - iLowestWeaponPercent)
    --if bDebugMessages == true then LOG(sFunctionRef..': iTimeToHold='..iTimeToHold..'; iMaxTimeToHold='..iMaxTimeToHold) end

    local iCurSecondsWaited = 0
    local iInterval = 1
    local bAllReadyToFire
    local iCount = 0
    while not(bAllReadyToFire) do
        iCount = iCount + 1 if iCount > 100 then M27Utilities.ErrorHandler('Infinite loop') break end
        WaitSeconds(iInterval)
        iCurSecondsWaited = iCurSecondsWaited + iInterval
        --Check if all units can fire yet
        bAllReadyToFire = true
        for iUnit, oUnit in tUnitsToSynchronise do
            if not(oUnit.Dead) then
                oCurWeapon = oUnit:GetWeapon(1)
                if not(oCurWeapon:CanFire()) then bAllReadyToFire = false break end
            end
        end
        if iCurSecondsWaited + iInterval >= iMaxTimeToHold then
            if iCurSecondsWaited < iMaxTimeToHold then
                iInterval = iMaxTimeToHold - iCurSecondsWaited
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Ended up waiting the maximum time') end
                break
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': iCurSecondsWaited='..iCurSecondsWaited..'; bAllReadyToFire='..tostring(bAllReadyToFire)) end
    end
    --WaitSeconds(iTimeToHold)
    if iTimeToSpreadOver == 0 then
        for iUnit, oUnit in tUnitsToSynchronise do
            if not(oUnit.Dead) then
                if bDebugMessages == true then M27Utilities.DrawLocation(oUnit:GetPosition(), nil, 2, 50) end
                oUnit:SetFireState(iReturnFireState)
            end
        end
    else
        --E.g. Aeon TMD - want to spread out
        local iUnitsToSynchronise = table.getn(tUnitsToSynchronise)
        local iDelayAfterFirstShot = 1.5 --e.g. for Aeon TMD
        if iTimeToSpreadOver <= 1.5 then iDelayAfterFirstShot = iTimeToSpreadOver / iUnitsToSynchronise end
        local iDelayBetweenUnit = 1
        if iUnitsToSynchronise > 2 then iDelayBetweenUnit = (iTimeToSpreadOver - iDelayAfterFirstShot) / (iUnitsToSynchronise - 2) end
        for iUnit, oUnit in tUnitsToSynchronise do
            if not(oUnit.Dead) then
                oUnit:SetFireState(iReturnFireState)
                if iUnit == 1 then
                    WaitSeconds(iDelayAfterFirstShot)
                else WaitSeconds(iDelayBetweenUnit) end
            end
        end
    end
end


function SynchroniseUnitFiring(tUnitsToSynchronise, iTimeToSpreadOver)
    local sFunctionRef = 'SynchroniseUnitFiring'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oBP = tUnitsToSynchronise[1]:GetBlueprint()
    if oBP and oBP.Weapon and oBP.Weapon[1] and oBP.Weapon[1].RateOfFire > 0 then
        local iFiringCycle = 1 / oBP.Weapon[1].RateOfFire
        if bDebugMessages == true then LOG(sFunctionRef..': About to synchronise firing for '..table.getn(tUnitsToSynchronise)..' units, iFiringCycle='..iFiringCycle..'; iTimeToSpreadOver='..iTimeToSpreadOver) end
        ForkThread(HoldAndReenableFire, tUnitsToSynchronise, iFiringCycle, iTimeToSpreadOver)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function IssueIndirectAttack(oPlatoon, bDontClearActions)
    --Targets structures first, if no structures then spread attack on units
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IssueIndirectAttack'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..':'..oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]..': Start of code: iIndirectUnites='..oPlatoon[refiIndirectUnits]) end
    if oPlatoon[refiIndirectUnits] > 0 then
        local sPlatoonName = oPlatoon:GetPlan()
        --if sPlatoonName == 'M27IndirectDefender' then bDebugMessages = true end
        local sPlatoonUniqueRef = sPlatoonName..oPlatoon[refiPlatoonCount]
        local sTargetedRef = sPlatoonUniqueRef..'Indirect'
        local iMinTargetsInRange
        local iMinTargetsAll
        local iCurUnitRange
        local bCurUnitInRange
        local oFirstUnitWithMinTargetsInRange
        local tCurPos
        local tUnitsInRange
        local iUnitsInRange

        local tPriorityEnemiesNearFiringRange
        local tStructuresCloseToMaxPlatoonRange
        local bSpreadAttack = false
        local bAreNearbyT2PlusPD = false

        if M27Utilities.IsTableEmpty(oPlatoon[reftIndirectUnits]) == true then
            M27Utilities.ErrorHandler('No indirect fire units in platoon despite iIndirectUnits = '..oPlatoon[refiIndirectUnits])
        else
            local iPlatoonAttackRange = M27Logic.GetUnitMaxGroundRange(oPlatoon[reftIndirectUnits])
            local aiBrain = oPlatoon:GetBrain()
            local iUnitRangeMod = 0 --Will treat any units within range+mod as being in range of the unit for choosing attack orders
            local iRevisedSearchRangeForBuildlings = oPlatoon[M27Overseer.refiSearchRangeForEnemyStructures]
            local tPlatoonPosition = GetPlatoonFrontPosition(oPlatoon)
            if bDebugMessages == true then LOG(sFunctionRef..': oPlatoon[refiEnemyStructuresInRange]='..oPlatoon[refiEnemyStructuresInRange]..'; oPlatoon[refiIndirectUnits]='..oPlatoon[refiIndirectUnits]) end
            local tNearbyEnemyT2PlusPD
            local bNearbyAeonTMD, bNearbyNonAeonTMD, tNearbyTMD
            local bNearbyShieldOrTMD = false
            local oNearestT2PlusPD
            if oPlatoon[refiEnemyStructuresInRange] > 0 then
                --Check if there are nearby enemy PD, in which case want to only look for buildings within a smaller range
                tNearbyEnemyT2PlusPD = EntityCategoryFilterDown(categories.DIRECTFIRE * categories.TECH2 + categories.DIRECTFIRE * categories.TECH3, oPlatoon[reftEnemyStructuresInRange])
                local iNearestT2PlusPD
                bAreNearbyT2PlusPD = not(M27Utilities.IsTableEmpty(tNearbyEnemyT2PlusPD))
                if bAreNearbyT2PlusPD == true then
                    --Get nearest enemy PD
                    oNearestT2PlusPD = M27Utilities.GetNearestUnit(tNearbyEnemyT2PlusPD, tPlatoonPosition, aiBrain, true)
                    iNearestT2PlusPD = M27Utilities.GetDistanceBetweenPositions(oNearestT2PlusPD:GetPosition(), tPlatoonPosition)
                    if iNearestT2PlusPD <= 70 then iRevisedSearchRangeForBuildlings = math.min(iNearestT2PlusPD + 5, iRevisedSearchRangeForBuildlings) end
                end

                if iRevisedSearchRangeForBuildlings < (iPlatoonAttackRange - 3) then iRevisedSearchRangeForBuildlings = iPlatoonAttackRange end
                iRevisedSearchRangeForBuildlings = math.min(iRevisedSearchRangeForBuildlings, iPlatoonAttackRange + 10)
                tStructuresCloseToMaxPlatoonRange = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, tPlatoonPosition, iRevisedSearchRangeForBuildlings, 'Enemy')
                if bDebugMessages == true then
                    if iNearestT2PlusPD == nil then iNearestT2PlusPD = 'nil' end
                    LOG(sFunctionRef..': iRevisedSearchRangeForBuildlings='..iRevisedSearchRangeForBuildlings..'; Platoon.refiSearchRangeForEnemyStructures='..oPlatoon[M27Overseer.refiSearchRangeForEnemyStructures]..'; iPlatoonAttackRange='..iPlatoonAttackRange..'; iNearestT2PlusPD='..iNearestT2PlusPD)
                end
                if M27Utilities.IsTableEmpty(tStructuresCloseToMaxPlatoonRange) == false then
                    if oPlatoon[refiIndirectUnits] >= 4 then
                        bSpreadAttack = true
                        iUnitRangeMod = 4
                        if oPlatoon[refiIndirectUnits] > 10 then iUnitRangeMod = 6 end
                    end

                    --Prioritise any shields and TMD
                    bNearbyAeonTMD = false
                    bNearbyNonAeonTMD = false
                    tPriorityEnemiesNearFiringRange = EntityCategoryFilterDown(categories.ANTIMISSILE + categories.SHIELD, tStructuresCloseToMaxPlatoonRange)
                    if M27Utilities.IsTableEmpty(tPriorityEnemiesNearFiringRange) == true then
                        --Target PD if no shields or TMD
                        tPriorityEnemiesNearFiringRange = EntityCategoryFilterDown(categories.DIRECTFIRE, tStructuresCloseToMaxPlatoonRange)
                        if M27Utilities.IsTableEmpty(tPriorityEnemiesNearFiringRange) == true then
                            --Target other structures
                            tPriorityEnemiesNearFiringRange = tStructuresCloseToMaxPlatoonRange
                        end
                    else
                        bNearbyShieldOrTMD = true
                        tNearbyTMD = EntityCategoryFilterDown(categories.AEON * M27UnitInfo.refCategoryTMD, tPriorityEnemiesNearFiringRange)
                        if M27Utilities.IsTableEmpty(tNearbyTMD) == false then
                            bNearbyAeonTMD = true
                        else
                            tNearbyTMD = EntityCategoryFilterDown(M27UnitInfo.refCategoryTMD, tPriorityEnemiesNearFiringRange)
                            if M27Utilities.IsTableEmpty(tNearbyTMD) == false then
                                bNearbyNonAeonTMD = true
                            end
                        end
                    end
                end
            end
            if M27Utilities.IsTableEmpty(tPriorityEnemiesNearFiringRange) == true then
                tPriorityEnemiesNearFiringRange = aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE + categories.NAVAL, tPlatoonPosition, math.min(iRevisedSearchRangeForBuildlings, iPlatoonAttackRange), 'Enemy')
                if M27Utilities.IsTableEmpty(tPriorityEnemiesNearFiringRange) == true then
                    tPriorityEnemiesNearFiringRange = oPlatoon[reftEnemiesInRange]
                    if M27Utilities.IsTableEmpty(oPlatoon[reftEnemiesInRange]) then tPriorityEnemiesNearFiringRange = oPlatoon[reftEnemyStructuresInRange] end
                end
                if oPlatoon[refiIndirectUnits] > 1 then bSpreadAttack = true end --1 arti shell can kill 1 tank in some cases so want to spraed attack
            end
            if M27Utilities.IsTableEmpty(tPriorityEnemiesNearFiringRange) == true then
                M27Utilities.ErrorHandler('No units to target for indirect attack, will resume movement path instead')
                ReissueMovementPath(oPlatoon, bDontClearActions)
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Have some enemies that can attack, will go through each unit in platoon and allocate targets') end
                --IssueAttack(oPlatoon[reftIndirectUnits], M27Utilities.GetNearestUnit(oPlatoon[reftEnemyStructuresInRange], GetPlatoonFrontPosition(oPlatoon)))



                --Track no. of times a unit has been targetted - first reset variables
                if bDebugMessages == true then LOG(sFunctionRef..':'..sPlatoonUniqueRef..': No nearby structures so attacking nearest units') end
                for iEnemyUnit, oEnemyUnit in tPriorityEnemiesNearFiringRange do
                    oEnemyUnit[sTargetedRef] = 0
                end
                --Cycle through each indirect fire unit, and then check for each enemy unit in its range
                --Default target in case can't find one: the closest unit:
                local oNearestEnemyUnit
                local iNearestEnemyUnitDistance
                local iCurDistanceToEnemy
                local oNearestEnemyT2PlusPD, iNearestT2PlusPD
                local bCurUnitSpreadAttack
                local bQueueUpOtherAttacks

                local bSynchroniseFiring = false
                local iMMLs = 0
                local tMMLNearFront = {}
                local iMMLNearFront = 0
                local tCurMMLPosition, oNearestTMD, tNearestTMD, iDistanceToNearestTMD
                --Check if should consider using Synchronised firing
                if bDebugMessages == true then LOG(sFunctionRef..': About to consider if should synchronise fire; oPlatoon[refiIndirectUnits]='..oPlatoon[refiIndirectUnits]) end
                if oPlatoon[refiIndirectUnits] >= 3 then
                    local tMMLs = EntityCategoryFilterDown(categories.SILO, oPlatoon[reftIndirectUnits])
                    if M27Utilities.IsTableEmpty(tMMLs) == false then iMMLs = table.getn(tMMLs) end
                    if bDebugMessages == true then LOG(sFunctionRef..': iMMLs='..iMMLs) end
                    if iMMLs >= 3 then
                        --More than 30s since we last Synchronised?
                        local iCurGameTime = GetGameTimeSeconds()
                        if bDebugMessages == true then
                            local iTimeOfLastRefresh = oPlatoon[refiTimeOfLastSyncronisation]
                            if iTimeOfLastRefresh == nil then iTimeOfLastRefresh = 'nil' end
                            LOG(sFunctionRef..': iTimeOfLastRefresh='..iTimeOfLastRefresh..'; iCurGameTime='..iCurGameTime..'; bNearbyAeonTMD='..tostring(bNearbyAeonTMD)..'; bNearbyNonAeonTMD='..tostring(bNearbyNonAeonTMD))
                        end
                        if oPlatoon[refiTimeOfLastSyncronisation] == nil or iCurGameTime - oPlatoon[refiTimeOfLastSyncronisation] > 9 then
                            --Only 9s, since hte way this works will be turning off once, and then turning on once; therefore even if this runs several times in the same cycle we should avoid units being permanently stuck waiting to attack
                            --Are there any nearby TMD?
                            if bNearbyAeonTMD == false and bNearbyNonAeonTMD == false then
                                --Check in a larger search range
                                local iTMDSearchRange = math.max(iPlatoonAttackRange, 70)
                                tNearbyTMD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryTMD, tPlatoonPosition, iTMDSearchRange, 'Enemy')
                                if M27Utilities.IsTableEmpty(tNearbyTMD) == false then
                                    if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.AEON, tNearbyTMD)) == false then
                                        bNearbyAeonTMD = true
                                    else
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef..': Size of table='..table.getn(tNearbyTMD))
                                            for iUnit, oUnit in tNearbyTMD do
                                                LOG('TMD iUnit='..iUnit)
                                            end
                                        end
                                        bNearbyNonAeonTMD = true
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': iNearbyTMD='..table.getn(tNearbyTMD)..'bNearbyAeonTMD='..tostring(bNearbyAeonTMD)..'; bNearbyNonAeonTMD='..tostring(bNearbyNonAeonTMD)) end
                            end
                            if bNearbyAeonTMD == true or bNearbyNonAeonTMD == true then
                                --Get nearest TMD or PD or shield to front platoon unit; Do we have at least 3 MMLs within range of this?

                                local oNearestPriorityUnit = M27Utilities.GetNearestUnit(tPriorityEnemiesNearFiringRange, GetPlatoonFrontPosition(oPlatoon), aiBrain, true)
                                local tNearestUnit = oNearestPriorityUnit:GetPosition()
                                local iNearestPriorityUnit = M27Utilities.GetDistanceBetweenPositions(tNearestUnit, GetPlatoonFrontPosition(oPlatoon))
                                local oNearestUnit = oNearestPriorityUnit
                                local tNearestT2PlusPD
                                if M27Utilities.IsTableEmpty(tNearbyEnemyT2PlusPD) == false then
                                    oNearestEnemyT2PlusPD = M27Utilities.GetNearestUnit(tNearbyEnemyT2PlusPD, GetPlatoonFrontPosition(oPlatoon), aiBrain, nil)
                                    tNearestT2PlusPD = oNearestEnemyT2PlusPD:GetPosition()
                                    iNearestT2PlusPD = M27Utilities.GetDistanceBetweenPositions(tNearestT2PlusPD, GetPlatoonFrontPosition(oPlatoon))
                                    if iNearestPriorityUnit > iNearestT2PlusPD then
                                        oNearestUnit = oNearestT2PlusPD
                                        iNearestPriorityUnit = iNearestT2PlusPD
                                        tNearestUnit = tNearestT2PlusPD
                                    end
                                end
                                for iUnit, oUnit in tMMLs do
                                    if not(oUnit.Dead) and oUnit.GetPosition then
                                        tCurMMLPosition = oUnit:GetPosition()
                                        if M27Utilities.GetDistanceBetweenPositions(tCurMMLPosition, tNearestUnit) <= iPlatoonAttackRange then
                                            iMMLNearFront = iMMLNearFront + 1
                                            tMMLNearFront[iMMLNearFront] = oUnit
                                        end
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': iMMLNearFront='..iMMLNearFront) end
                                if iMMLNearFront >= 3 then
                                    if bDebugMessages == true then
                                        LOG('Size of tNearbyTMD='..table.getn(tNearbyTMD))
                                        for iUnit, oUnit in tNearbyTMD do
                                            LOG('iUnit='..iUnit)
                                        end
                                    end
                                    --Has the TMD moved since we last Synchronised?
                                    oNearestTMD = M27Utilities.GetNearestUnit(tNearbyTMD, tPlatoonPosition, aiBrain)
                                    if oNearestTMD then
                                        tNearestTMD = oNearestTMD:GetPosition()
                                        if bDebugMessages == true then
                                            local iDistanceToLastTMD = 0
                                            local iMMLFromLastSynchronisation = oPlatoon[refiMMLCountWhenLastSynchronised]
                                            if iMMLFromLastSynchronisation == nil then iMMLFromLastSynchronisation = 'nil' end
                                            if oPlatoon[reftNearestTMDWhenLastSynchronised] then iDistanceToLastTMD = M27Utilities.GetDistanceBetweenPositions(tNearestTMD, oPlatoon[reftNearestTMDWhenLastSynchronised]) end
                                            LOG(sFunctionRef..': iDistanceToLastTMD='..iDistanceToLastTMD..'; iMMLFromLastSynchronisation='..iMMLFromLastSynchronisation)
                                        end
                                        if oPlatoon[reftNearestTMDWhenLastSynchronised] == nil or M27Utilities.GetDistanceBetweenPositions(tNearestTMD, oPlatoon[reftNearestTMDWhenLastSynchronised]) >3 then
                                            bSynchroniseFiring = true
                                        else
                                            if oPlatoon[refiMMLCountWhenLastSynchronised] == nil or iMMLNearFront - oPlatoon[refiMMLCountWhenLastSynchronised] >= 2 then
                                                bSynchroniseFiring = true
                                            end
                                        end
                                        if bSynchroniseFiring == true then
                                            oPlatoon[refiTimeOfLastSyncronisation] = iCurGameTime
                                            oPlatoon[reftNearestTMDWhenLastSynchronised] = tNearestTMD
                                            oPlatoon[refiMMLCountWhenLastSynchronised] = iMMLNearFront
                                            local iTimeToSpreadOver = 0
                                            if bNearbyAeonTMD == true then iTimeToSpreadOver = 3.1 end
                                            if bDebugMessages == true then LOG(sFunctionRef..': About to call function to synchronise unit firing') end
                                            SynchroniseUnitFiring(tMMLNearFront, iTimeToSpreadOver)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end


                if M27Utilities.IsTableEmpty(oPlatoon[reftIndirectUnits]) == false and GetPlatoonUnitsOrUnitCount(oPlatoon, reftIndirectUnits, true, true) > 0 then
                    for iUnit, oUnit in GetPlatoonUnitsOrUnitCount(oPlatoon, reftIndirectUnits, false, true) do
                        if not(oUnit.Dead) then
                            iMinTargetsAll = 100000
                            iMinTargetsInRange = 100000
                            iCurUnitRange = M27Logic.GetUnitMaxGroundRange({oUnit}) + iUnitRangeMod
                            tCurPos = oUnit:GetPosition()
                            iUnitsInRange = 0
                            tUnitsInRange = {}
                            iNearestEnemyUnitDistance = 10000
                            oNearestEnemyT2PlusPD = nil
                            iNearestT2PlusPD = 10000
                            bCurUnitSpreadAttack = bSpreadAttack
                            bQueueUpOtherAttacks = true
                            if bAreNearbyT2PlusPD then
                                oNearestEnemyT2PlusPD = M27Utilities.GetNearestUnit(tNearbyEnemyT2PlusPD, tCurPos, aiBrain, nil)
                                iNearestT2PlusPD = M27Utilities.GetDistanceBetweenPositions(oNearestEnemyT2PlusPD:GetPosition(), tCurPos)
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': iNearestT2PlusPD='..iNearestT2PlusPD..': Will either pick the nearest T2 PD if <=56, or will cycle through priority targets') end
                            if iNearestT2PlusPD <= 56 then
                                bCurUnitSpreadAttack = false
                                bQueueUpOtherAttacks = false
                                --Do we have TMD within our range? If so then attack them first
                                if bNearbyShieldOrTMD == true then
                                    local tWithinRangeTMDAndShield = {}
                                    local iWithinRangeTMDAndShield = 0
                                    for iEnemy, oEnemy in tPriorityEnemiesNearFiringRange do
                                        if M27Utilities.GetDistanceBetweenPositions(tCurPos, oUnit:GetPosition()) <= iCurUnitRange then
                                            IssueAttack({oUnit}, oEnemy)
                                        end
                                    end
                                end
                                oNearestEnemyUnit = oNearestEnemyT2PlusPD
                            else
                                for iEnemyUnit, oEnemyUnit in tPriorityEnemiesNearFiringRange do
                                    if not(oEnemyUnit.Dead) then
                                        bCurUnitInRange = false
                                        iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tCurPos, oEnemyUnit:GetPosition())
                                        if iCurDistanceToEnemy <= iCurUnitRange then bCurUnitInRange = true end
                                        if iCurDistanceToEnemy <= iNearestEnemyUnitDistance then
                                            iNearestEnemyUnitDistance = iCurDistanceToEnemy
                                            oNearestEnemyUnit = oEnemyUnit
                                        end
                                        if bCurUnitInRange == true then
                                            table.insert(tUnitsInRange, 1,oEnemyUnit)
                                            iUnitsInRange = iUnitsInRange + 1
                                            if oEnemyUnit[sTargetedRef] == nil then oEnemyUnit[sTargetedRef] = 0 end
                                            if oEnemyUnit[sTargetedRef] < iMinTargetsInRange then
                                                iMinTargetsInRange = oEnemyUnit[sTargetedRef]
                                                oFirstUnitWithMinTargetsInRange = oEnemyUnit
                                            end
                                        end
                                    end
                                end
                            end
                            if bCurUnitSpreadAttack == false then
                                --Target nearest enemy (and queue up attacks on all other units)
                                if bDebugMessages == true then LOG(sFunctionRef..': Telling cur unit to attack the nearest enemy unit; bQueueUpOtherAttacks='..tostring(bQueueUpOtherAttacks)) end
                                IssueAttack({oUnit}, oNearestEnemyUnit)
                                if oNearestEnemyUnit[sTargetedRef] == nil then oNearestEnemyUnit[sTargetedRef] = 0 end
                                oNearestEnemyUnit[sTargetedRef] = oNearestEnemyUnit[sTargetedRef] + 1
                                if bQueueUpOtherAttacks == true then
                                    if iUnitsInRange > 0 then
                                        for iEnemyUnit, oEnemyUnit in tUnitsInRange do
                                            if not(oEnemyUnit == oNearestEnemyUnit) then IssueAttack({oUnit}, oEnemyUnit) end
                                        end
                                    else
                                        for iEnemyUnit, oEnemyUnit in tPriorityEnemiesNearFiringRange do
                                            if not(oEnemyUnit == oNearestEnemyUnit) then IssueAttack({oUnit}, oEnemyUnit) end
                                        end
                                    end
                                end
                            else
                                --Spread attack - target the unit in range with the least existing targets (or the nearest enemy unit if no units in range), and queue up attacks on all other priority units
                                --If any units in range, then queue up attacks on all of them, starting with the one with min targets:
                                if bDebugMessages == true then LOG(sFunctionRef..':'..sPlatoonUniqueRef..': iUnit='..iUnit..'; iUnitsInRange='..iUnitsInRange..'; iMinTargetsInRange='..iMinTargetsInRange..'; bQueueUpOtherAttacks='..tostring(bQueueUpOtherAttacks)) end
                                if bQueueUpOtherAttacks == true then
                                    if iUnitsInRange > 0 then
                                        if bDebugMessages == true then LOG(sFunctionRef..':'..sPlatoonUniqueRef..': Telling unit to attack the least targetted enemy unit in range, iUnit='..iUnit..'; X position of target='..oFirstUnitWithMinTargetsInRange:GetPosition()[1]..'; oPlatoon[refiEnemiesInRange]='..oPlatoon[refiEnemiesInRange]..'; iIndirectUnits='..oPlatoon[refiIndirectUnits]) end
                                        if bDebugMessages == true then LOG('oUnit ID='..oUnit:GetUnitId()) end
                                        IssueAttack({oUnit}, oFirstUnitWithMinTargetsInRange)
                                        if oFirstUnitWithMinTargetsInRange[sTargetedRef] == nil then oFirstUnitWithMinTargetsInRange[sTargetedRef] = 0 end
                                        oFirstUnitWithMinTargetsInRange[sTargetedRef] = oFirstUnitWithMinTargetsInRange[sTargetedRef] + 1
                                        for iEnemyUnit, oEnemyUnit in tUnitsInRange do
                                            if not(oEnemyUnit == oFirstUnitWithMinTargetsInRange) then IssueAttack({oUnit}, oEnemyUnit) end
                                        end
                                    else
                                        --No units in range, so target the closest unit
                                        if oNearestEnemyUnit == nil then M27Utilities.ErrorHandler('Dont have any unit to target')
                                        else
                                            if bDebugMessages == true then LOG(sFunctionRef..': Telling unit to attack the nearest enemy unit') end
                                            IssueAttack({oUnit}, oNearestEnemyUnit)
                                            if oNearestEnemyUnit[sTargetedRef] == nil then oNearestEnemyUnit[sTargetedRef] = 0 end
                                            oNearestEnemyUnit[sTargetedRef] = oNearestEnemyUnit[sTargetedRef] + 1
                                        end

                                        for iEnemyUnit, oEnemyUnit in tPriorityEnemiesNearFiringRange do
                                            if not(oEnemyUnit == oNearestEnemyUnit) then IssueAttack({oUnit}, oEnemyUnit) end
                                        end
                                    end
                                end
                            end
                        end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Warning - table of indirect units is empty') end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdateScoutPositions(oPlatoon)
    --Send scouts to the platoons current position (so should never be in front); sends up to 2 scouts to the middle (so for v.large platoons dont group them all in 1 place)
    local sFunctionRef = 'UpdateScoutPositions'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if oPlatoon[refiScoutUnits] <= 2 then
        if oPlatoon[refiScoutUnits] > 0 and GetPlatoonUnitsOrUnitCount(oPlatoon, reftScoutUnits, true, true) >= 1 then
            if bDebugMessages == true then LOG('UpdateScoutPositions: Sending IssueMove command') end
            IssueMove(GetPlatoonUnitsOrUnitCount(oPlatoon, reftScoutUnits, false, true), GetPlatoonFrontPosition(oPlatoon))
        end
    else
        if GetPlatoonUnitsOrUnitCount(oPlatoon, reftScoutUnits, true, true) > 0 then
            for iUnit, oUnit in GetPlatoonUnitsOrUnitCount(oPlatoon, reftScoutUnits, false, true) do
                if iUnit >= 3 then break end
                if bDebugMessages == true then LOG('UpdateScoutPositions: Sending IssueMove command') end
                IssueMove({oUnit}, GetPlatoonFrontPosition(oPlatoon))
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end


function GetPositionNearTargetInSamePathingGroup(tStartPos, tTargetPos, iDistanceFromTarget, iAngleBase, oPathingUnit, iNearbyMethodIfBlocked, bTrySidePositions, bCheckAgainstExistingCommandTarget, iMinDistanceFromCurrentBuilderMoveTarget)
    --Returns the position to move to in order to be iDistanceFromTarget away from tTargetPos
    --Returns nil if empty table
    --Returns pathing unit's current move location if it also fits the criteria
    --iAngleBase: 0 = straight line; 90 and 270: right angle to the direction; 180 - opposite direction (not yet supported other angles)
    --oPathingUnit - Unit to use for seeing if can path to the desired location
    --iNearbyMethodIfBlocked: default and 1: Move closer to target until are in same pathing group, checking side options as we go;
            --2: Move further away from target until are in same pathing group
            --3: Alternate between closer and further away from target until are in same pathing group
        --bTrySidePositions: Alternates left and right if base line can't find a position, based on the outer distance (so effectively plotting a circle around the target)
    --bCheckAgainstExistingCommandTarget: If true, then will check oPathingUnit's current target location, and if that appears a better fit than what this method results in
        --iMinDistanceFromCurrentBuilderMoveTarget - if bCheckAgainstExistingCommandTarget is true, then this will also check if the potential move target is >1 from the current target (and ignore if its not)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetPositionNearTargetInSamePathingGroup'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bCheckAgainstExistingCommandTarget == nil then bCheckAgainstExistingCommandTarget = true end
    if iMinDistanceFromCurrentBuilderMoveTarget == nil then iMinDistanceFromCurrentBuilderMoveTarget = 0 end
    if bDebugMessages == true then LOG(sFunctionRef..': Start; oPathingUnit blueprint='..oPathingUnit:GetUnitId()..'; iDistanceFromTarget='..iDistanceFromTarget) end
    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iMaxX = rPlayableArea[3] - rPlayableArea[1]
    local iMaxZ = rPlayableArea[4] - rPlayableArea[2]

    local iAdjDistance = 0
    local iLoopCount = 0
    local iIncrement = 0.5

    local iMaxLoopCount = math.max(math.abs(iDistanceFromTarget) / iIncrement + 1, 4)
    local bHaveValidTarget = false
    local tPossibleTarget = {}
    local iAngleToTarget = 0
    local iMaxAdjCycleCount = 2
    if iNearbyMethodIfBlocked == 3 then iMaxAdjCycleCount = 3 end
    local iMaxAngleCycleCount = 1
    if bTrySidePositions == true then iMaxAngleCycleCount = 3 end
    local iAdjSignage
    local tBasePossibleTarget = {}
    if bDebugMessages == true then LOG(sFunctionRef..': bHaveValidTarget='..tostring(bHaveValidTarget)..'; iDistanceFromTarget='..iDistanceFromTarget..'; iMaxLoopCount='..iMaxLoopCount..'; iLoopCount='..iLoopCount) end
    while bHaveValidTarget == false do
        iLoopCount = iLoopCount + 1
        if iLoopCount > iMaxLoopCount then
            if bDebugMessages == true then LOG(sFunctionRef..': Have exhausted all options on the way to the target location, so will give up moving within range of the target') end
            break
        end

        if bDebugMessages == true then LOG(sFunctionRef..': iLoopCount='..iLoopCount..'; iMaxAdjCycleCount='..iMaxAdjCycleCount..'; iAdjDistance='..iAdjDistance..'; iDistanceFromTarget='..iDistanceFromTarget..' tBasePossibleTarget='..repr(tBasePossibleTarget)) end

        for iAdjCycleCount = 1, iMaxAdjCycleCount do
            if iAdjCycleCount == iMaxAdjCycleCount then iAdjDistance = iAdjDistance + 1 end  --e.g. if passed distance of 0, then want to increase the distance by 1 after the first attempt or else will be checking the same location each time
            if iAdjCycleCount < 3 then iAdjSignage = 1 else iAdjSignage = -1 end
            iAngleToTarget = iAngleBase

            tBasePossibleTarget = M27Utilities.MoveTowardsTarget(tTargetPos, tStartPos, (iDistanceFromTarget + iAdjDistance) * iAdjSignage, iAngleToTarget)
            for iAngleCycleCount = 1, iMaxAngleCycleCount do

                if iAngleCycleCount == 1 then
                    tPossibleTarget = tBasePossibleTarget
                    if bDebugMessages == true then LOG(sFunctionRef..': tPossibleTarget is set to equal tBasePossibleTarget') end
                else
                    if iAngleCycleCount == 2 then
                        iAngleToTarget = 90
                        iAdjDistance = iAdjDistance + 1
                    elseif iAngleCycleCount == 3 then iAngleToTarget = 270
                    end
                    iAngleToTarget = iAngleToTarget + iAngleBase
                    if iAngleToTarget < 0 then iAngleToTarget = iAngleToTarget + 360
                    elseif iAngleToTarget > 360 then iAngleToTarget = iAngleToTarget - 360 end

                --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
                    --tPossibleTarget = M27Utilities.MoveTowardsTarget(tTargetPos, tStartPos, (iDistanceFromTarget + iAdjDistance) * iAdjSignage, iAngleToTarget)
                    tPossibleTarget = M27Utilities.MoveInDirection(tTargetPos, iAngleToTarget, iDistanceFromTarget + iAdjDistance)
                    if bDebugMessages == true then LOG(sFunctionRef..': tPossibleTarget is based on iAngleToTarget of '..iAngleToTarget..'; and tPossibleTarget is '..repr(tPossibleTarget)..'; iDistanceFromTarget + iAdjDistance='..iDistanceFromTarget + iAdjDistance) end
                end

                if bDebugMessages == true then
                    LOG(sFunctionRef..': tPossibleTarget='..repr(tPossibleTarget)..'; checking if its valid; oPathingUnit blueprint='..oPathingUnit:GetUnitId()..'; Adjusted distance='..(iDistanceFromTarget + iAdjDistance) * iAdjSignage..'; iAngleCycleCount='..iAngleCycleCount..'; iAdjCycleCount='..iAdjCycleCount..'; iLoopCount='..iLoopCount..'; iAngleToTarget='..iAngleToTarget)
                    M27Utilities.DrawLocation(tPossibleTarget, nil, 4, 10)
                end
                --Are we in map bounds?
                tPossibleTarget[1] = math.max(rPlayableArea[1] + 1, math.min(tPossibleTarget[1], (iMaxX-1)))
                tPossibleTarget[3] = math.max(rPlayableArea[2] + 1, math.min(tPossibleTarget[3], (iMaxZ-1)))

                        --Are we in the same segment group?

                if M27MapInfo.InSameSegmentGroup(oPathingUnit, tPossibleTarget) == true then
                    --are in same pathing grouping
                    if bDebugMessages == true then LOG(sFunctionRef..': tPossibleTarget is valid, ='..repr(tPossibleTarget)..'; checking if its valid; oPathingUnit blueprint='..oPathingUnit:GetUnitId()) end
                    if bDebugMessages == true then LOG(sFunctionRef..': have valid location='..repr(tPossibleTarget)) end
                    bHaveValidTarget = true
                    break
                    --note - not bothering with check re if target built on as engi seems to cope ok id building covering its move location
                else
                    if bDebugMessages == true then
                        local iTargetSegmentX, iTargetSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tPossibleTarget)
                        local iUnitSegmentGroup = M27MapInfo.GetUnitSegmentGroup(oPathingUnit)
                        if iUnitSegmentGroup == nil then iUnitSegmentGroup = 'nil' end
                        local iSegmentGroupOfTarget = M27MapInfo.GetSegmentGroupOfTarget(M27UnitInfo.GetUnitPathingType(oPathingUnit), iTargetSegmentX, iTargetSegmentZ)
                        if iSegmentGroupOfTarget == nil then iSegmentGroupOfTarget = 'nil' end
                        LOG(sFunctionRef..': Not in same segment group; oPathingUnitSegmentGroup='..iUnitSegmentGroup..'; SegmentGroupOfTarget='..iSegmentGroupOfTarget)
                    end
                end
            end
            if bHaveValidTarget == true then break end
        end


    end
    --Check if already have a move location that will take us here
    if bHaveValidTarget == true then
        if bDebugMessages == true then LOG(sFunctionRef..': Checking if already have a move location that will take us to the target') end
        tPossibleTarget[2] = GetTerrainHeight(tPossibleTarget[1], tPossibleTarget[3])
        if bCheckAgainstExistingCommandTarget == true then
            if bDebugMessages == true then LOG(sFunctionRef..': Checking against existing target to see if thats better') end
            if oPathingUnit.GetNavigator then
                local oNavigator = oPathingUnit:GetNavigator()
                if oNavigator.GetCurrentTargetPos then
                    local tExistingTargetPos = oNavigator:GetCurrentTargetPos()
                    if M27Utilities.IsTableEmpty(tExistingTargetPos) == false then
                        if M27MapInfo.InSameSegmentGroup(oPathingUnit, tExistingTargetPos) == true then
                            local iDistanceBetweenQueuedAndPossibleTarget = M27Utilities.GetDistanceBetweenPositions(tExistingTargetPos, tPossibleTarget)
                            if bDebugMessages == true then LOG(sFunctionRef..': iDistanceBetweenQueuedAndPossibleTarget='..iDistanceBetweenQueuedAndPossibleTarget) end
                            if iDistanceBetweenQueuedAndPossibleTarget > iMinDistanceFromCurrentBuilderMoveTarget then
                                local tPatherPos = oPathingUnit:GetPosition()
                                local iDistanceFromQueuedMoveLocationToTarget = M27Utilities.GetDistanceBetweenPositions(tExistingTargetPos, tTargetPos)
                                local iDistanceFromPossibleTargetToTarget = M27Utilities.GetDistanceBetweenPositions(tPossibleTarget, tTargetPos)
                                local iDistanceFromPatherToPossibleTarget = M27Utilities.GetDistanceBetweenPositions(tPossibleTarget, tPatherPos)
                                local iDistanceFromPatherToQueuedLocation = M27Utilities.GetDistanceBetweenPositions(tExistingTargetPos, tPatherPos)

                                --first check - are they both within the desired range?
                                local bPossibleTargetIsGood, bQueuedTargetIsGood
                                if iDistanceFromQueuedMoveLocationToTarget == iDistanceFromTarget then bQueuedTargetIsGood = true
                                elseif iDistanceFromQueuedMoveLocationToTarget < iDistanceFromTarget then
                                    if iNearbyMethodIfBlocked == 2 then --Want to be >=
                                        bQueuedTargetIsGood = false
                                    else bQueuedTargetIsGood = true
                                    end
                                else --must be > distance
                                    if iNearbyMethodIfBlocked == 1 then --Want to be <=
                                        bQueuedTargetIsGood = false else bQueuedTargetIsGood = true
                                    end
                                end

                                if iDistanceFromPossibleTargetToTarget == iDistanceFromTarget then bPossibleTargetIsGood = true
                                elseif iDistanceFromPossibleTargetToTarget < iDistanceFromTarget then
                                    if iNearbyMethodIfBlocked == 2 then --Want to be >=
                                        bPossibleTargetIsGood = false
                                    else bPossibleTargetIsGood = true
                                    end
                                else --must be > distance
                                    if iNearbyMethodIfBlocked == 1 then --Want to be <=
                                        bPossibleTargetIsGood = false else bPossibleTargetIsGood = true
                                    end
                                end
                                local bBothGoodOrBad = false
                                if bPossibleTargetIsGood == true and bQueuedTargetIsGood == true then bBothGoodOrBad = true
                                elseif bPossibleTargetIsGood == false and bQueuedTargetIsGood == false then bBothGoodOrBad = true end



                                if bBothGoodOrBad == false then
                                    --One is better than the other so pick it
                                    if bDebugMessages == true then LOG(sFunctionRef..': One of locations is better than the other at meeting initial requirements so will pick it; bQueuedTargetIsGood='..tostring(bQueuedTargetIsGood)) end
                                    if bQueuedTargetIsGood == true then tPossibleTarget = tExistingTargetPos end
                                else
                                    --both are good or bad re meeting the requirements; pick the one that's closest to the target
                                    if bDebugMessages == true then LOG(sFunctionRef..': Both locations are equally good/bad; if theyre both within the target distance will return closet to builder/pather; if theyre both outside the target will pick the one closest to target') end
                                    if iDistanceFromPossibleTargetToTarget <= iDistanceFromTarget and iDistanceFromQueuedMoveLocationToTarget <= iDistanceFromTarget and iDistanceFromPatherToQueuedLocation <= iDistanceFromPatherToPossibleTarget then tPossibleTarget = tExistingTargetPos
                                    elseif iDistanceFromPossibleTargetToTarget > iDistanceFromTarget and iDistanceFromQueuedMoveLocationToTarget > iDistanceFromTarget and iDistanceFromQueuedMoveLocationToTarget <= iDistanceFromPossibleTargetToTarget then tPossibleTarget = tExistingTargetPos
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    else tPossibleTarget = nil end
    if bDebugMessages == true then
        if M27Utilities.IsTableEmpty(tPossibleTarget) == true then LOG(sFunctionRef..': End of code, tPossibleTarget is empty')
        else LOG(sFunctionRef..': End of code, tPossibleTarget='..repr(tPossibleTarget)) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tPossibleTarget
end
--PUT IN TO HELP SEARCHING - USE ABOVE INSTEAD
function MoveTowardsSameGroupTarget(tStartPos, tTargetPos, iDistanceFromTarget, iAngleBase, oPathingUnit, iNearbyMethodIfBlocked, bTrySidePositions, bCheckAgainstExistingCommandTarget, iMinDistanceFromCurrentBuilderMoveTarget)
    GetPositionNearTargetInSamePathingGroup(tStartPos, tTargetPos, iDistanceFromTarget, iAngleBase, oPathingUnit, iNearbyMethodIfBlocked, bTrySidePositions, bCheckAgainstExistingCommandTarget, iMinDistanceFromCurrentBuilderMoveTarget)
end

function MoveNearConstruction(aiBrain, oBuilder, tLocation, sBlueprintID, iBuildDistanceMod, bReturnMovePathInstead, bUpdatePlatoonMovePath, bReturnNilIfAlreadyMovingNearConstruction)
    --gives oBuilder a move command to get them within range of building on tLocation, factoring in the size of buildingType
    --sBlueprintID - if nil, then will treat the action as having a size of 0
    --iBuildDistanceMod - increase or decrease if want to move closer/further away than build distance would send you; e.g. if want to get 3 within the build distance, set this to -3
    --bReturnMovePathInstead - if true return move destination instead of moving there; returns oBuilder's current position if it doesnt need to move
    --bUpdatePlatoonMovePath - default false; if true then if oBuilder has a platoon, updates that platoon's movement path
    --bReturnNilIfAlreadyMovingNearConstruction - will return nil if bReturnMovePathInstead is set to true and unit is already moving towards target, otherwise will return current move target if its close enough, or the builder position if already in position
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MoveNearConstruction'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        local sBuilderName = oBuilder:GetUnitId()
        sBuilderName = sBuilderName..M27UnitInfo.GetUnitLifetimeCount(oBuilder)
        LOG(sFunctionRef..': Start; oBuilderId and unique count='..sBuilderName)
        M27Utilities.DrawLocation(tLocation)
    end
    if iBuildDistanceMod == nil then iBuildDistanceMod = 0 end
    if bReturnMovePathInstead == nil then bReturnMovePathInstead = false end
    if bUpdatePlatoonMovePath == nil then bUpdatePlatoonMovePath = false end
    if bReturnNilIfAlreadyMovingNearConstruction == nil then bReturnNilIfAlreadyMovingNearConstruction = true end
    local tBuilderLocation = oBuilder:GetPosition()
    local iBuildDistance = 0
    local oBuilderBP = oBuilder:GetBlueprint()
    if oBuilderBP.Economy and oBuilderBP.Economy.MaxBuildDistance then iBuildDistance = oBuilderBP.Economy.MaxBuildDistance end
    iBuildDistance = iBuildDistance + iBuildDistanceMod
    --if iBuildDistance <= 0 then iBuildDistance = 1 end
    local iBuildingSize
    if sBlueprintID == nil then
        iBuildingSize = 0
    else
        iBuildingSize = M27UnitInfo.GetBuildingSize(sBlueprintID)[1]
    end
    local fSizeMod = 0.5
    local iDistanceWantedFromTarget = iBuildingSize * fSizeMod + iBuildDistance
    local tPossibleTarget
    local bIgnoreMove = false
    local bUseLocationInsteadOfMoveNearby = false
    local iPossibleDistanceFromTarget

    --Determine target:
    local iCurrentDistanceFromTarget = M27Utilities.GetDistanceBetweenPositions(tBuilderLocation, tLocation)
    if iCurrentDistanceFromTarget > iDistanceWantedFromTarget then
        --Add slight buffer so move into place:
        if bDebugMessages == true then LOG(sFunctionRef..': About to get move position near the target '..repr(tLocation)..'; iCurrentDistanceFromTarget='..iCurrentDistanceFromTarget..'; iDistanceWantedFromTarget='..iDistanceWantedFromTarget..'; will decrease distance wanted very slightly') end
        iDistanceWantedFromTarget = iDistanceWantedFromTarget - 0.25

        --GetPositionNearTargetInSamePathingGroup(tStartPos, tTargetPos, iDistanceWantedFromTarget, iAngleBase, oPathingUnit, iNearbyMethodIfBlocked, bTrySidePositions)
        local iMinDistanceFromCurrentBuilderMoveTarget = 2 --dont want to change movement path from the one generated if it's not that different

         tPossibleTarget = GetPositionNearTargetInSamePathingGroup(tBuilderLocation, tLocation, iDistanceWantedFromTarget, 0, oBuilder, 1, true, true, iMinDistanceFromCurrentBuilderMoveTarget)

        if tPossibleTarget == nil then
            if bDebugMessages == true then LOG(sFunctionRef..': Cant get a nearby location for target; will return tLocation if can path to it') end
            bUseLocationInsteadOfMoveNearby = true
        else
            iPossibleDistanceFromTarget = M27Utilities.GetDistanceBetweenPositions(tLocation, tPossibleTarget)
            if iPossibleDistanceFromTarget - iDistanceWantedFromTarget > 0.01 then --Can sometimes get tiny rounding differences
                if bDebugMessages == true then LOG(sFunctionRef..': Possible target location is outside the build range, so want to just return the target position instead, iPossibleDistanceFromTarget='..iPossibleDistanceFromTarget..'; iDistanceWantedFromTarget='..iDistanceWantedFromTarget) end
                bUseLocationInsteadOfMoveNearby = true
            end
        end
        if bUseLocationInsteadOfMoveNearby == true then
            --Couldn't find anywhere; can we path to the target?
            bIgnoreMove = true
            if M27MapInfo.InSameSegmentGroup(oBuilder, tLocation, false) == true then
                if bDebugMessages == true then LOG(sFunctionRef..': Can path to tLocation so returning that') end
                if tPossibleTarget == tLocation then M27Utilities.ErrorHandler('GetPositionNearTargetInSamePathingGroup should already consider if target location is valid and use that instead of pathing units current position, so investigate how this has triggered (this was added as quick fix backup for v6 hotfix, but hope was with other changes this wouldnt be needed/trigger') end
                tPossibleTarget = tLocation
            else
                --Could be our logic for pathing is faulty - use canpathto instead
                if oBuilder:CanPathTo(tLocation) then
                    LOG(sFunctionRef..': When pathing from '..repr(oBuilder:GetPosition())..' to '..repr(tLocation)..' we thought we were in different pathing groups, but we can path there using CanPathTo for unit ID='..oBuilder:GetUnitId())
                    tPossibleTarget = tLocation
                else
                    M27Utilities.ErrorHandler('MoveNearConstructions target location cant be pathed to and cant find pathable positions near it, will return nil, may cause future error depending on what has called this')
                end
            end
        end

        --Is this target different to current move target?
        if tPossibleTarget then
            if bDebugMessages == true then LOG(sFunctionRef..': tPossibleTarget='..repr(tPossibleTarget)) end
            local oNavigator = oBuilder:GetNavigator()
            if oNavigator.GetCurrentTargetPos then
                local tExistingTargetPos = oNavigator:GetCurrentTargetPos()
                if M27Utilities.IsTableEmpty(tExistingTargetPos) == false then
                    if M27Utilities.GetDistanceBetweenPositions(tExistingTargetPos, tPossibleTarget) < iMinDistanceFromCurrentBuilderMoveTarget then
                        if bDebugMessages == true then LOG(sFunctionRef..': Existing move location '..repr(tExistingTargetPos)..' is close enough to possible target '..repr(tPossibleTarget)..' so will go with that, or return nil if have specified to') end
                        if bReturnNilIfAlreadyMovingNearConstruction == true then tPossibleTarget = nil
                        else tPossibleTarget = tExistingTargetPos end
                        bIgnoreMove = true
                    end
                end
            end
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': Are already close enough to target position, so will return builder location or nil depending on function arguments') end
        --Are already in position
        if bReturnNilIfAlreadyMovingNearConstruction == true then tPossibleTarget = nil
        else tPossibleTarget = tBuilderLocation end
        bIgnoreMove = true
    end

    --Move to target:
    if bReturnMovePathInstead == false then
        --Check if unit's current move location is within 1 of this already (note the getpositionneartarget function will have more advanced logic for considering if no need to change current target
        if bIgnoreMove == false then
            --[[if oBuilder.GetNavigator then
                local oNavigator = oBuilder:GetNavigator()
                if oNavigator.GetCurrentTargetPos then
                    local tExistingTargetPos = oNavigator:GetCurrentTargetPos()
                    if M27Utilities.GetDistanceBetweenPositions(tExistingTargetPos, tPossibleTarget) < 1 then
                        bIgnoreMove = true
                    end
                end
            end]]--
            if bIgnoreMove == false then
                if bDebugMessages == true then LOG(sFunctionRef..': Issuing move command to tPossibleTarget='..repr(tPossibleTarget)) end
                if not(oBuilder[M27UnitInfo.refbSpecialMicroActive]) then IssueMove({oBuilder}, tPossibleTarget) end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Not issuing move command as tPossibleTarget is close to existing target') end
            end
        end
    end
    --Update platoon movement path:
    if bIgnoreMove == false then
        if bUpdatePlatoonMovePath == true and oBuilder.PlatoonHandle then
            if oBuilder.PlatoonHandle[reftMovementPath] == nil then oBuilder.PlatoonHandle[reftMovementPath] = {} end
            if oBuilder.PlatoonHandle[refiCurrentPathTarget] == nil then oBuilder.PlatoonHandle[refiCurrentPathTarget] = 1 end
            if oBuilder.PlatoonHandle[reftMovementPath][oBuilder.PlatoonHandle[refiCurrentPathTarget]] == nil then oBuilder.PlatoonHandle[reftMovementPath][oBuilder.PlatoonHandle[refiCurrentPathTarget]] = {} end
            oBuilder.PlatoonHandle[reftMovementPath][oBuilder.PlatoonHandle[refiCurrentPathTarget]] = tPossibleTarget
        end
    end
    --Return position if have asked for one:
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if bReturnMovePathInstead == true then
        if bDebugMessages == true then
            if tPossibleTarget == nil then LOG(sFunctionRef..': End of function, returning nil')
            else LOG(sFunctionRef..': End of function, returning '..repr(tPossibleTarget)) end
        end
        return tPossibleTarget
    end
end

function RefreshSupportPlatoonMovementPath(oPlatoon)
    --Updates movement path for oPlatoon
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RefreshSupportPlatoonMovementPath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if oPlatoon:GetPlan() == 'M27MAAAssister' then bDebugMessages = true end
    local sPlatoonName = oPlatoon:GetPlan()

    local sPlatoonRef = sPlatoonName..oPlatoon[refiPlatoonCount]
    --if sPlatoonName == 'M27ScoutAssister' then bDebugMessages = true end
    --if sPlatoonName == 'M27MAAAssister' then bDebugMessages = true end
    --if sPlatoonName == 'M27EscortAI' then bDebugMessages = true end
    --if sPlatoonName == 'M27MobileShield' then bDebugMessages = true end
    --If no unit assigned default to first intel path midpoint
    local bHaveUnitToFollow = false
    if oPlatoon then
        local iCurrentUnits = GetPlatoonUnitsOrUnitCount(oPlatoon, reftCurrentUnits, true, true)
        local tCurrentUnits = GetPlatoonUnitsOrUnitCount(oPlatoon, reftCurrentUnits, false, true)

        if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonRef..': Start of code') end
        if oPlatoon[reftMovementPath] == nil then oPlatoon[reftMovementPath] = {} end
        if oPlatoon[M27PlatoonTemplates.refbRequiresSingleLocationToGuard] == true then
            oPlatoon[reftMovementPath][1] = oPlatoon[reftLocationToGuard]
            if iCurrentUnits > 0 then
                IssueClearCommands(tCurrentUnits)
                IssueMove(tCurrentUnits, oPlatoon[reftMovementPath][1])
            end
        else
            local bNoLongerHaveTargetToFollow = not(DoesPlatoonStillHaveSupportTarget(oPlatoon))
            --local bNoLongerHaveTargetToFollow = false
            local aiBrain = oPlatoon:GetBrain()
            if bNoLongerHaveTargetToFollow == true then
                --Make sure variables are cleared:
                oPlatoon[refoSupportHelperUnitTarget] = nil
                oPlatoon[refoSupportHelperPlatoonTarget] = nil
                oPlatoon[refoPlatoonOrUnitToEscort] = nil
                local tTempMovePosition = {}
                local tCurPosition = GetPlatoonFrontPosition(oPlatoon)
                if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonRef..': Just cleared platoon/unit/support to escort; No scout helper target, will look for intel path instead') end
                if aiBrain[M27Overseer.refbIntelPathsGenerated] == false then --Shouldnt happen but code just in case
                    --Set to current position for now
                    tTempMovePosition = tCurPosition
                    if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonRef..': No intel path generated, setting to platoon position instead') end
                else
                    tTempMovePosition = aiBrain[M27Overseer.reftIntelLinePositions][1][1]
                    if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonRef..': No scout helper target, setting to intel path instead') end
                end
                oPlatoon[reftMovementPath][1] = tTempMovePosition
                if M27Utilities.GetDistanceBetweenPositions(tCurPosition, tTempMovePosition) <= 20 then
                    oPlatoon[refiCurrentAction] = refActionDisband
                    if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonRef..': Have fallen back to intel path, now want to disband') end
                else
                    oPlatoon[refiCurrentPathTarget] = 1
                    if iCurrentUnits > 0 then
                        IssueClearCommands(tCurrentUnits)
                        if ShouldPlatoonMoveInFormation(oPlatoon, false) then IssueFormMove(tCurrentUnits, tTempMovePosition, (oPlatoon.PlatoonData.UseFormation or 'GrowthFormation'), 0)
                        else IssueMove(tCurrentUnits, tTempMovePosition) end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': Sending platoon to the temporary move position='..repr(tTempMovePosition)) end
                end
            else
                -- GetPositionToFollowTargets(tUnitsToFollow, oFollowingUnit, iFollowDistance)
                if bDebugMessages == true then LOG(sFunctionRef..': Either helperunit or helperplatoon isnt nil') end
                local tTargetUnitPosition
                local tUnitsToFollow = {}
                local bHavePlatoonTarget = false
                if oPlatoon[refoSupportHelperPlatoonTarget] or oPlatoon[refoPlatoonOrUnitToEscort] then
                    if oPlatoon[refoSupportHelperPlatoonTarget].GetPlatoonUnits or oPlatoon[refoPlatoonOrUnitToEscort].GetPlatoonUnits or oPlatoon[refoPlatoonOrUnitToEscort].GetUnitId then
                        bHavePlatoonTarget = true
                    end
                end
                if bHavePlatoonTarget then
                    if oPlatoon[refoSupportHelperPlatoonTarget] then
                        if bDebugMessages == true then LOG(sFunctionRef..': refoSupportHelperPlatoonTarget='..oPlatoon[refoSupportHelperPlatoonTarget]:GetPlan()..oPlatoon[refoSupportHelperPlatoonTarget][refiPlatoonCount]) end
                        if oPlatoon[refoSupportHelperPlatoonTarget][refoFrontUnit] and not(oPlatoon[refoSupportHelperPlatoonTarget][refoFrontUnit].Dead) then tUnitsToFollow = {oPlatoon[refoSupportHelperPlatoonTarget][refoFrontUnit]}
                        else tUnitsToFollow = oPlatoon[refoSupportHelperPlatoonTarget]:GetPlatoonUnits()
                        end
                        tTargetUnitPosition = GetPlatoonFrontPosition(oPlatoon[refoSupportHelperPlatoonTarget])
                    else
                        if oPlatoon[refoPlatoonOrUnitToEscort][refbShouldHaveEscort] == true or oPlatoon[refoPlatoonOrUnitToEscort][M27PlatoonTemplates.refbWantsShieldEscort] == true then
                            tTargetUnitPosition = GetPlatoonFrontPosition(oPlatoon[refoPlatoonOrUnitToEscort])
                            if bDebugMessages == true then
                                if oPlatoon[refoPlatoonOrUnitToEscort].GetPlan then
                                    LOG(sFunctionRef..': refoPlatoonOrUnitToEscort='..oPlatoon[refoPlatoonOrUnitToEscort]:GetPlan()..oPlatoon[refoPlatoonOrUnitToEscort][refiPlatoonCount])
                                else
                                    LOG(sFunctionRef..': Escorting platoon with UnitID='..oPlatoon[refoPlatoonOrUnitToEscort]:GetUnitId())
                                end
                            end
                            if oPlatoon[refoPlatoonOrUnitToEscort][refoFrontUnit] and not(oPlatoon[refoPlatoonOrUnitToEscort][refoFrontUnit].Dead) then
                                tUnitsToFollow = {oPlatoon[refoPlatoonOrUnitToEscort][refoFrontUnit]}
                            else
                                if oPlatoon[refoPlatoonOrUnitToEscort].GetPlatoonUnits then
                                    tUnitsToFollow = oPlatoon[refoPlatoonOrUnitToEscort]:GetPlatoonUnits()
                                end
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Platoon to escort/shield no longer wants an escort or a shield') end
                        end
                    end
                else
                    tUnitsToFollow = {oPlatoon[refoSupportHelperUnitTarget]}
                    tTargetUnitPosition = tUnitsToFollow[1]:GetPosition()
                    if bDebugMessages == true then LOG(sFunctionRef..': Dont have a platoon target so will get the position of the unit to follow instead = '..repr(tTargetUnitPosition)) end
                end
                if M27Utilities.IsTableEmpty(tTargetUnitPosition) == true then
                    LOG('WARNING - potential error - have no tTargetUnitPosition for the escort/support unit')
                end

                --Check at least 1 of target is alive
                local iFollowingUnitCount = 0
                local oUnitToFollow
                if M27Utilities.IsTableEmpty(tUnitsToFollow) == false then
                    for iUnit, oUnit in tUnitsToFollow do
                        if not(oUnit.Dead) then
                            iFollowingUnitCount = iFollowingUnitCount + 1
                            oUnitToFollow = oUnit
                        end
                    end
                end
                if iFollowingUnitCount == 0 then
                    if bDebugMessages == true then LOG(sFunctionRef..':'..sPlatoonRef..': No units to follow so returning to base') end
                    oPlatoon[refiCurrentAction] = refActionReturnToBase
                    oPlatoon[refoSupportHelperPlatoonTarget] = nil
                    oPlatoon[refoPlatoonOrUnitToEscort] = nil
                    oPlatoon[refoSupportHelperUnitTarget] = nil
                    ReturnToBase(oPlatoon, nil, false, false)
                else
                    if bDebugMessages == true then LOG(sFunctionRef..':'..sPlatoonRef..': Have '..iFollowingUnitCount..' units that are following') end
                    local oUnitPather = oPlatoon[reftCurrentUnits][1]
                    if oUnitPather == nil or oUnitPather.Dead then
                        if oPlatoon[refiCurrentUnits] > 1 then
                            for _, oPlatoonUnit in oPlatoon[reftCurrentUnits] do
                               if not(oPlatoonUnit.Dead) then oUnitPather = oPlatoonUnit end
                            end
                        else
                            --Platoon is dead so disband
                            if bDebugMessages == true then LOG(sFunctionRef..': Platoon is dead so disband') end
                            oPlatoon[refiCurrentAction] = refActionDisband
                        end
                    end
                    if oUnitPather == nil then
                        if bDebugMessages == true then LOG(sFunctionRef..': Unit pather is nil so disbanding') end
                        oPlatoon[refiCurrentAction] = refActionDisband
                    else
                        --Update distance to follow if are meant to be leading the unit that are escorting, based on our platoon size and target platoon size
                        if oPlatoon[refiSupportHelperFollowDistance] < 0 then
                            local iFollowDistance = math.max(20, 10 + oPlatoon[refiCurrentUnits])
                            --Escort platoons - be closer to target if its small
                            if oPlatoon[refoPlatoonOrUnitToEscort] and oPlatoon[refoPlatoonOrUnitToEscort][refiCurrentUnits] <= 3 then
                                iFollowDistance = math.max(10, iFollowDistance - 5)
                            end
                            oPlatoon[refiSupportHelperFollowDistance] = -iFollowDistance
                        elseif oPlatoon[refiSupportHelperFollowDistance] == nil then oPlatoon[refiSupportHelperFollowDistance] = 5
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonRef..': iFollowDistance='..oPlatoon[refiSupportHelperFollowDistance]) end

                        local refiFollowedUnitIsDeadOrNilCycleCount = 'M27FollowedUnitDeadOrNilCycleCount'
                        if oPlatoon[refiFollowedUnitIsDeadOrNilCycleCount] == nil then oPlatoon[refiFollowedUnitIsDeadOrNilCycleCount] = 0 end
                        if not(oUnitToFollow) or oUnitToFollow.Dead then
                            if bDebugMessages == true then LOG(sFunctionRef..': Dont have valid unit to follow, will look for alternative units to follow') end
                            oPlatoon[refiFollowedUnitIsDeadOrNilCycleCount] = oPlatoon[refiFollowedUnitIsDeadOrNilCycleCount] + 1
                            if oPlatoon[refiFollowedUnitIsDeadOrNilCycleCount] > 1 then
                                if oPlatoon[refiFollowedUnitIsDeadOrNilCycleCount] == 2 then
                                    --Try to find a different unit to follow
                                    for iUnit, oUnit in tUnitsToFollow do
                                        if not(oUnit.Dead) then
                                            oUnitToFollow = oUnit
                                            bHaveUnitToFollow = true
                                            break end
                                    end
                                end
                                if bHavePlatoonTarget == false then
                                    if oPlatoon[refiFollowedUnitIsDeadOrNilCycleCount] > 2 then
                                        if bDebugMessages == true then LOG('First unit of platoon to follow has been dead or nil 3+ cycles in a row; will set platoon '..sPlatoonRef..' to move to itself') end
                                        if oPlatoon.GetPosition then oPlatoon[reftMovementPath][1] = GetPlatoonFrontPosition(oPlatoon) end
                                        if oPlatoon[refiFollowedUnitIsDeadOrNilCycleCount] > 6 then
                                            M27Utilities.ErrorHandler('First unit of platoon to follow has been dead or nil 7+ cycles in a row; will disband platoon')
                                            oPlatoon[refiCurrentAction] = refActionDisband
                                        end
                                    end
                                end
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Have valid unit that are following, ='..oUnitToFollow:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnitToFollow)..'; position='..repr(oUnitToFollow:GetPosition())..'; our platoon position='..repr(GetPlatoonFrontPosition(oPlatoon))) end
                            bHaveUnitToFollow = true

                        end
                        if bHaveUnitToFollow then
                            local oOurPlatoonUnitReference = oPlatoon[refoFrontUnit]
                            if oOurPlatoonUnitReference == nil then oOurPlatoonUnitReference = oPlatoon[reftCurrentUnits][1] end
                            --oPlatoon[reftMovementPath][1] = M27Logic.GetPositionToFollowTargets(tUnitsToFollow, oOurPlatoonUnitReference, oPlatoon[refiSupportHelperFollowDistance])
                            --GetPositionNearTargetInSamePathingGroup(tStartPos, tTargetPos, iDistanceFromTarget, iAngleBase, oPathingUnit, iNearbyMethodIfBlocked, bTrySidePositions, bCheckAgainstExistingCommandTarget, iMinDistanceFromCurrentBuilderMoveTarget)
                            if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': About to get position near target in same pathing group; tTargetUnitPosition='..repr(tTargetUnitPosition)..'; distance we want to be towards enemy base from the target='..-oPlatoon[refiSupportHelperFollowDistance]) end
                            local tNewTargetPath = GetPositionNearTargetInSamePathingGroup(M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)], tTargetUnitPosition, -oPlatoon[refiSupportHelperFollowDistance], 0, oOurPlatoonUnitReference, 1, true, true, 3)
                            if bDebugMessages == true then
                                M27Utilities.DrawLocation(tTargetUnitPosition, nil, 5, 10) --Light blue
                                M27Utilities.DrawLocation(tNewTargetPath, nil, 2, 10) --red
                            end
                            if M27Utilities.IsTableEmpty(tNewTargetPath) == true then
                                if M27Utilities.IsTableEmpty(oPlatoon[reftMovementPath][1]) == true then
                                    --Couldnt get a new path (e.g. target is in a different pathing group) and we dont have an existing path; return to base for now
                                    oPlatoon[reftMovementPath][1] = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                                end
                            else
                                oPlatoon[reftMovementPath][1] = tNewTargetPath
                            end
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': '..sPlatoonRef..': Targetting location of helper; NewMovementPath='..repr(oPlatoon[reftMovementPath][1])..'; tTargetUnitPosition='..repr(tTargetUnitPosition)..'; oPlatoon[refiSupportHelperFollowDistance]='..oPlatoon[refiSupportHelperFollowDistance])
                            end
                            if iCurrentUnits > 0 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Issuing move command to '..repr(oPlatoon[reftMovementPath][1])) end
                                IssueClearCommands(tCurrentUnits)
                                if ShouldPlatoonMoveInFormation(oPlatoon, false) then IssueFormMove(tCurrentUnits, oPlatoon[reftMovementPath][1], (oPlatoon.PlatoonData.UseFormation or 'GrowthFormation'), 0)
                                else IssueMove(tCurrentUnits, oPlatoon[reftMovementPath][1]) end
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Failed to find a unit to follow') end
                        end
                    end
                end
            end
        end
        oPlatoon[refiCurrentPathTarget] = 1
    else
        if bDebugMessages == true then LOG(sFunctionRef..': dont have a platoon assigned to scout helper') end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function MoveNearHydroAndAssistEngiBuilder(oPlatoon, oHydroBuilder, tHydroPosition)
    --called by AssistHydro platoon.lua AI - intended for platoon that can build/assist
    --oHydroBuilder is the unit constructing a hydro at tHydroPosition that want to assist
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MoveNearHydroAndAssistEngiBuilder'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tPlatoonPosition = GetPlatoonFrontPosition(oPlatoon)
    local aiBrain = oPlatoon:GetBrain()
    local iCurHydroDistance = M27Utilities.GetDistanceBetweenPositions(tHydroPosition, tPlatoonPosition)
    local tBuilders = EntityCategoryFilterDown(categories.CONSTRUCTION + categories.REPAIR, oPlatoon:GetPlatoonUnits())
    if M27Utilities.IsTableEmpty(tBuilders) == false then
        local oBuilder = tBuilders[1]
        if iCurHydroDistance > (oBuilder:GetBlueprint().Economy.MaxBuildDistance + M27UnitInfo.GetBuildingSize('UAB1102')[1]*0.5) then
            --Send move command towards the hydro
            if bDebugMessages == true then LOG(sFunctionRef..': About to call MoveNearConstruction') end
            --MoveNearConstruction(aiBrain, oBuilder, tLocation, sBlueprintID, iBuildDistanceMod, bReturnMovePathInstead, bUpdatePlatoonMovePath, bReturnNilIfAlreadyMovingNearConstruction)
            MoveNearConstruction(aiBrain, oBuilder, tHydroPosition, 'UAB1102', 0, false, true, false, false)
        else
            if oPlatoon[reftMovementPath] == nil then oPlatoon[reftMovementPath] = {} end
            if oPlatoon[reftMovementPath][1] == nil then oPlatoon[reftMovementPath][1] = {} end
            oPlatoon[reftMovementPath][1] = tPlatoonPosition
            oPlatoon[refiCurrentPathTarget] = 1
        end


        if bDebugMessages == true then LOG(sFunctionRef..': Attempting to issue guard command') end
        if oHydroBuilder == nil or oHydroBuilder.Dead or oHydroBuilder:BeenDestroyed() then LOG(sFunctionRef..': ERROR - There is no valid target; wont issue guard command')
        else
            IssueGuard({ oBuilder}, oHydroBuilder)
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ReplaceMovementPathWithNewTarget(oPlatoon, tNewTarget)
    --Replace current movement path target with this
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReplaceMovementPathWithNewTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]] = tNewTarget
    local iLoopCountCheck = 0
    while table.getn(oPlatoon[reftMovementPath]) > oPlatoon[refiCurrentPathTarget] do
        iLoopCountCheck = iLoopCountCheck + 1
        if iLoopCountCheck > 20 then M27Utilities.ErrorHandler('Infinite loop') break end
        table.remove(oPlatoon[reftMovementPath], oPlatoon[refiCurrentPathTarget] + 1)
    end
    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Replacing remaining movement path with tNewTarget='..repr(tNewTarget)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end


function ProcessPlatoonAction(oPlatoon)
    --Assumes DeterminePlatoonAction has been called
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ProcessPlatoonAction'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if oPlatoon and oPlatoon.GetBrain then
        local aiBrain = oPlatoon[refoBrain]
        if aiBrain and aiBrain.PlatoonExists and aiBrain:PlatoonExists(oPlatoon) then

            local sPlatoonName = oPlatoon:GetPlan()

            --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end
            --if sPlatoonName == 'M27DefenderAI' then bDebugMessages = true end
            --if sPlatoonName == 'M27MexRaiderAI' then bDebugMessages = true end
            --if sPlatoonName == 'M27ScoutAssister' then bDebugMessages = true end
            --if sPlatoonName == 'M27MAAAssister' then bDebugMessages = true end
            --if sPlatoonName == M27Overseer.sIntelPlatoonRef then bDebugMessages = true end
            --if sPlatoonName == 'M27LargeAttackForce' then bDebugMessages = true end
            --if sPlatoonName == 'M27IntelPathAI' then bDebugMessages = true end
            --if sPlatoonName == 'M27IndirectDefender' then bDebugMessages = true end
            --if sPlatoonName == 'M27CombatPatrolAI' then bDebugMessages = true end
            --if sPlatoonName == 'M27EscortAI' then bDebugMessages = true end
            --if sPlatoonName == 'M27MexLargerRaiderAI' then bDebugMessages = true end
            --if sPlatoonName == 'M27RetreatingShieldUnits' then bDebugMessages = true end
            --if sPlatoonName == 'M27MobileShield' then bDebugMessages = true end

            if bDebugMessages == true then
                if oPlatoon[refiCurrentAction] == nil then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': '..sFunctionRef..': refiCurrentAction is nil')
                else LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': '..sFunctionRef..': refiCurrentAction = '..oPlatoon[refiCurrentAction]) end
            end

            --First add in extra action (if have one) - currently extra action is just overcharge

            local bDontClearActions = false
            local bCancelOvercharge = false
            local bGiveMoveTargetFirst = false
            if bDebugMessages == true then
                local sCurFormation = oPlatoon.PlatoonData.UseFormation
                if sCurFormation == nil then sCurFormation = 'None' end
                LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': formation = '..sCurFormation)
            end
            if not(oPlatoon[refiExtraAction]==nil) then
                local oOverchargingUnit = oPlatoon[reftBuilders][1]
                if bDebugMessages == true then LOG(sFunctionRef..': Have extra action to process') end
                if oPlatoon[refiExtraAction] == refExtraActionOvercharge then
                    if bDebugMessages == true then LOG(sFunctionRef..': Extra action is overcharge - checking have a target') end
                    if oPlatoon[refExtraActionTargetUnit] and not(oPlatoon[refExtraActionTargetUnit].Dead) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have valid target, issuing overcharge') end
                        if M27Utilities.IsTableEmpty(oPlatoon[reftBuilders]) == true then
                            LOG(sFunctionRef..': ERROR - tried calling overcharge action but dont have a unit to issue it to')
                        else
                            local oUnitToIssueOverchargeTo = oOverchargingUnit
                            if oUnitToIssueOverchargeTo and not(oUnitToIssueOverchargeTo.Dead) and not(oUnitToIssueOverchargeTo[M27UnitInfo.refbSpecialMicroActive]) then
                                --Do we need to move closer to get in range of overcharge (e.g. are targetting T2 PD)?
                                local tOCTargetPos = oPlatoon[refExtraActionTargetUnit]:GetPosition()
                                local tOverchargingUnitPos = oOverchargingUnit:GetPosition()
                                local iOverchargingUnitRange = M27Logic.GetACUMaxDFRange(oOverchargingUnit)
                                local iDistanceBetweenUnits = M27Utilities.GetDistanceBetweenPositions(tOCTargetPos, tOverchargingUnitPos)
                                local tMoveTarget = {}
                                local tPossibleTarget = {}
                                if iDistanceBetweenUnits > iOverchargingUnitRange then
                                    --Move towards the target
                                    local iLoopCount = 0
                                    local iMaxLoop = 100
                                    bGiveMoveTargetFirst = true
                                    --GetPositionNearTargetInSamePathingGroup(tStartPos, tTargetPos, iDistanceWantedFromTarget, iAngleBase, oPathingUnit, iNearbyMethodIfBlocked, bTrySidePositions)
                                    tMoveTarget = GetPositionNearTargetInSamePathingGroup(tOverchargingUnitPos, tOCTargetPos, iDistanceBetweenUnits - iOverchargingUnitRange, 0, oOverchargingUnit, 1, true)
                                    if tMoveTarget == nil then
                                        bCancelOvercharge = true
                                    end
                                end
                                if bCancelOvercharge == false then
                                    IssueClearCommands({oUnitToIssueOverchargeTo})
                                    if bGiveMoveTargetFirst == true then IssueMove({ oOverchargingUnit }, tMoveTarget) end
                                    IssueOverCharge({oOverchargingUnit}, oPlatoon[refExtraActionTargetUnit])
                                    oOverchargingUnit[M27UnitInfo.refbOverchargeOrderGiven] = true
                                    --Give up on issuing overcharge after 4s
                                    M27Utilities.DelayChangeVariable(oOverchargingUnit, M27UnitInfo.refbOverchargeOrderGiven, false, 4, nil, nil)
                                    bDontClearActions = true
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have just issued overcharge action, waiting') end
                                    --Reissue prev action if current action is nil so we dont stand around for a while
                                    if oPlatoon[refiCurrentAction] == nil then oPlatoon[refiCurrentAction] = oPlatoon[reftPrevAction][1] end
                                end
                            else
                                LOG(sFunctionRef..': Warning - unit to issue overcharge to isnt valid or is dead')
                            end
                        end
                    else
                        LOG(sFunctionRef..': ERROR - tried calling overcharge action without a target')
                    end
                end
            end

            if oPlatoon[refiCurrentAction] == nil then
                --dont change what are currently doing
            else
                --local aiBrain = oPlatoon:GetBrain()
                local bPlatoonNameDisplay = false
                if bDebugMessages == true then LOG(sFunctionRef..': ACU state='..M27Logic.GetUnitState(M27Utilities.GetACU(aiBrain))..'; Special Micro='..tostring(M27Utilities.GetACU(aiBrain).M27UnitInfo.refbSpecialMicroActive or false)) end
                if M27Config.M27ShowUnitNames == true then bPlatoonNameDisplay = true end
                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': ProcessPlatoonAction: refiCurrentAction='..oPlatoon[refiCurrentAction]..'; bDontClearActions='..tostring(bDontClearActions)) end
                if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': A'..oPlatoon[refiCurrentAction]) end

                if not(oPlatoon[refiCurrentAction] == refActionMoveToTemporaryLocation) then oPlatoon[reftTemporaryMoveTarget] = {} end --Resets variable since are about to get new command

                local tCurrentUnits = GetPlatoonUnitsOrUnitCount(oPlatoon, reftCurrentUnits, false, true)
                local iCurrentUnits = GetPlatoonUnitsOrUnitCount(oPlatoon, reftCurrentUnits, true, true)


                if oPlatoon[refiCurrentAction] == refActionAttack then
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': A'..refActionAttack) end
                    if bDontClearActions == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': Clearing commands for all units in platoon') end
                        if iCurrentUnits > 0 then IssueClearCommands(tCurrentUnits) end
                    end
                    --attack-move to nearest enemy; LargeAttackAI - prioritise structure over nearest enemy if <=5 enemy units
                    if oPlatoon[refiEnemiesInRange] == 0 and oPlatoon[refiEnemyStructuresInRange] == 0 then ReissueMovementPath(oPlatoon)
                    else
                        local tDFTargetPosition = {}

                        local bAlreadyDeterminedTargetEnemy = false
                        local bChangedActions = false
                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': refActionAttack: About to process action') end
                        --Get DF Unit target:
                        if sPlatoonName == 'M27LargeAttackForce' then
                            --If only a small number of enemies then target the nearest DF structure or the slowest enemy unit
                            if oPlatoon[refiEnemiesInRange] < math.min(8, oPlatoon[refiDFUnits] * 0.5) then
                                if oPlatoon[refiEnemyStructuresInRange] > 0 then
                                    --Are there any nearby PD? If so are we in range of them
                                    local tNearbyPD = EntityCategoryFilterDown(M27UnitInfo.refCategoryPD, oPlatoon[reftEnemyStructuresInRange])
                                    if M27Utilities.IsTableEmpty(tNearbyPD) == false then
                                        local iEnemyPDRange = M27Logic.GetUnitMaxGroundRange(tNearbyPD)
                                        local oNearestPD = M27Utilities.GetNearestUnit(tNearbyPD, GetPlatoonFrontPosition(oPlatoon))
                                        if M27Utilities.GetDistanceBetweenPositions(oNearestPD:GetPosition(), GetPlatoonFrontPosition(oPlatoon)) < (iEnemyPDRange + 4) then
                                            --have a PD thats in range or almost in range of us, so should attack it
                                            tDFTargetPosition = oNearestPD:GetPosition()
                                            bAlreadyDeterminedTargetEnemy = true
                                        end
                                    end
                                    if bAlreadyDeterminedTargetEnemy == false then
                                        --No nearby PD so just go for nearest structure
                                        tDFTargetPosition = M27Utilities.GetNearestUnit(oPlatoon[reftEnemyStructuresInRange], GetPlatoonFrontPosition(oPlatoon)):GetPosition()
                                        bAlreadyDeterminedTargetEnemy = true
                                    end
                                end
                                if bAlreadyDeterminedTargetEnemy == false then
                                    --No structures; see if are any slower enemies and if so then target them
                                    local tSlowerEnemies = M27Logic.GetUnitSpeedData(oPlatoon[reftEnemiesInRange], aiBrain, true, 4, M27Logic.GetUnitMinSpeed(oPlatoon[reftCurrentUnits], aiBrain, false))
                                    if not(tSlowerEnemies==nil) then
                                        if table.getn(tSlowerEnemies) > 0 then
                                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': ProcessPlatoonAction: table.getn(tSlowerEnemies)='..table.getn(tSlowerEnemies)) end
                                            tDFTargetPosition = M27Utilities.GetNearestUnit(tSlowerEnemies, GetPlatoonFrontPosition(oPlatoon)):GetPosition()
                                            bAlreadyDeterminedTargetEnemy = true
                                        end
                                    end
                                end
                            end
                        else
                            if oPlatoon[refiDFUnits] > 0 then
                                if oPlatoon[M27PlatoonTemplates.refbAlwaysAttack] == true then
                                    --Has platoon attack nearby structures and (if there are none) nearby land units forever; if no known units then will attack enemy base and then go back to our base and repeat
                                    if oPlatoon[refiEnemyStructuresInRange] > 0 then
                                        tDFTargetPosition = M27Utilities.GetNearestUnit(oPlatoon[reftEnemyStructuresInRange], GetPlatoonFrontPosition(oPlatoon)):GetPosition()
                                        bAlreadyDeterminedTargetEnemy = true
                                    elseif oPlatoon[refiEnemiesInRange] == 0 then --Redundancy - no structures or enemies in range
                                        bChangedActions = true
                                        ReturnToBase(oPlatoon)
                                    end
                                end
                                if bAlreadyDeterminedTargetEnemy == false then
                                    if oPlatoon[refiEnemiesInRange] > 0 then
                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': refActionAttack: Enemies in range, will attack nearest enemy unit') end
                                        tDFTargetPosition = M27Utilities.GetNearestUnit(oPlatoon[reftEnemiesInRange], GetPlatoonFrontPosition(oPlatoon)):GetPosition()
                                    elseif oPlatoon[refiEnemyStructuresInRange] > 0 then
                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': refActionAttack: No enemies in range but have structures in range') end
                                        tDFTargetPosition = M27Utilities.GetNearestUnit(oPlatoon[reftEnemyStructuresInRange], GetPlatoonFrontPosition(oPlatoon)):GetPosition()
                                    else
                                        LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': WARNING - have been assigned action to attack for DF units, but no nearby units recorded.  Will tell DF units to go to current movement path target')
                                        if M27Utilities.IsTableEmpty(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]]) == true then
                                            GetNewMovementPath(oPlatoon, bDontClearActions)
                                            bChangedActions = true
                                        else
                                            tDFTargetPosition = oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]]
                                        end
                                    end
                                end
                            end
                        end
                        --Attack-move to target enemy for direct fire units if spread out, otherwise move; for indirect fire units instead do special attack targetting structures if there are any, or spread attack if there arent
                        if bChangedActions == false then
                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': refActionAttack: About to issue attack orders') end
                            --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': A'..refActionAttack) end
                            if bDontClearActions == false and iCurrentUnits > 0 then IssueClearCommands(tCurrentUnits) end
                            local bMoveNotAttack = false
                            if oPlatoon[refiDFUnits] > 0 and GetPlatoonUnitsOrUnitCount(oPlatoon, reftDFUnits, true, true) > 0 then
                                --Do we have enemy mobile units? If so consider moving towards them:
                                if oPlatoon[refiEnemiesInRange] > 0 then
                                    --if enemy T1 arti or T2 MML detected then move instead of attack-move even if spread out:
                                    if oPlatoon[refiVisibleEnemyIndirect] > 0 then
                                        bMoveNotAttack = true
                                    else
                                        --ACU in platoon? Then attack move
                                        if oPlatoon[refbACUInPlatoon] == true then bMoveNotAttack = false
                                        else
                                            if GetPlatoonPositionDeviation(oPlatoon) <= 10 then
                                            --Platoon isn't spread out, so ok to move
                                            bMoveNotAttack = true
                                            end
                                        end
                                    end
                                end
                                if M27Utilities.IsTableEmpty(tDFTargetPosition) == true then tDFTargetPosition = M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)] end
                                oPlatoon[reftTemporaryMoveTarget] = tDFTargetPosition

                                if bMoveNotAttack and M27Conditions.HaveNearbyMobileShield(oPlatoon) then bMoveNotAttack = false end



                                if bMoveNotAttack == true then
                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': refActionAttack: Issuing move to DF units to position '..repr(oPlatoon[reftTemporaryMoveTarget])) end
                                    IssueMove(GetPlatoonUnitsOrUnitCount(oPlatoon, reftDFUnits, false, true), oPlatoon[reftTemporaryMoveTarget])
                                else
                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': refActionAttack: Issuing attack move to DF units to position '..repr(oPlatoon[reftTemporaryMoveTarget])) end
                                    IssueAggressiveMove(GetPlatoonUnitsOrUnitCount(oPlatoon, reftDFUnits, false, true), oPlatoon[reftTemporaryMoveTarget])
                                end
                            end
                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': refActionAttack: About to issue attack orders for indirect units') end
                            IssueIndirectAttack(oPlatoon, bDontClearActions) --if are any indirect fire units this will tell them to target structures, or (if none) spread attack enemy unitsi n range
                            UpdateScoutPositions(oPlatoon)
                        end
                    end

                elseif oPlatoon[refiCurrentAction] == refActionRun or oPlatoon[refiCurrentAction] == refActionTemporaryRetreat then
                    local bTemporaryRetreat = false
                    if oPlatoon[refiCurrentAction] == refActionTemporaryRetreat then bTemporaryRetreat = true end
                    if bPlatoonNameDisplay == true then
                        if bTemporaryRetreat == true then --UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': A'..refActionTemporaryRetreat)
                        else
                            --UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': '..refActionRun)
                            oPlatoon[refbHavePreviouslyRun] = true
                        end
                    end

                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Start of refActionRun and refActionTemporaryRetreat; bTemporaryRetreat='..tostring(bTemporaryRetreat)..'; platoon movement path='..repr(oPlatoon[reftMovementPath])) end

                    --Check if current target is away from nearest enemy and also the enemy start location:
                    local bTargetAwayFromNearestEnemy = false
                    local tCurPlatoonPos = GetPlatoonFrontPosition(oPlatoon)
                    local bUseTempPath = false
                    --What is the platoons current move location?
                    local oUnit = oPlatoon[refoFrontUnit]
                    local tPlatoonCurMoveLocation
                    if M27UnitInfo.IsUnitValid(oUnit) then
                        if oUnit.GetNavigator then
                            local oNavigator = oUnit:GetNavigator()
                            if oNavigator.GetCurrentTargetPos then
                                tPlatoonCurMoveLocation = oNavigator:GetCurrentTargetPos()
                                if bDontClearActions == true then LOG(sFunctionRef..': tPlatoonCurMoveLocation='..repr(tPlatoonCurMoveLocation)) end
                            end
                        end
                    end
                    --if tPlatoonCurMoveLocation == nil then tPlatoonCurMoveLocation = oPlatoon[reftTemporaryMoveTarget] end --redundancy now
                    --Distance to run back by: If follower platoon (such as intel platoon) with temporary retreat or actionrun then will be refreshing every 2s (6s if hover in platoon)
                    local iDistanceToRunBackBy = 60
                    local iMinDistanceToRunBack = 50
                    if oPlatoon[refiCurrentAction] == refActionTemporaryRetreat then
                        iDistanceToRunBackBy = 25
                        iMinDistanceToRunBack = 20
                    end

                    local iOurMinSpeed = M27Logic.GetUnitMinSpeed(oPlatoon[reftCurrentUnits], aiBrain, false)
                    if iOurMinSpeed > 3.5 then
                        --Dealing with a fast unit such as a land scout
                        if oPlatoon[refbCombatHoverInPlatoon] then iDistanceToRunBackBy = math.max(iDistanceToRunBackBy, 30)
                        else iDistanceToRunBackBy = math.min(25, iDistanceToRunBackBy)
                        end
                    end

                    if M27Utilities.IsTableEmpty(oPlatoon[reftTemporaryMoveTarget]) == false and M27Utilities.IsTableEmpty(tPlatoonCurMoveLocation) == false and oPlatoon[reftTemporaryMoveTarget][1] == tPlatoonCurMoveLocation[1] and oPlatoon[reftTemporaryMoveTarget][3] == tPlatoonCurMoveLocation[3] then
                        bUseTempPath = true
                        if bDebugMessages == true then LOG(sFunctionRef..': Have a temporary move target set which is equal to platoon front unit current target location') end
                    else
                        bUseTempPath = false
                        if bDebugMessages == true then LOG(sFunctionRef..': Dont have a temporary move target set which is equal to platoon front unit current target location') end
                    end

                    --if M27Utilities.IsTableEmpty(tPlatoonCurMoveLocation) == true then
                    --    tPlatoonCurMoveLocation = oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]]
                    --[[else
                        bUseTempPath = true
                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Temporary move target being used which shouldnt be nil, repr='..repr(oPlatoon[reftTemporaryMoveTarget])) end
                    end--]]
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Point 1: platoon movement path='..repr(oPlatoon[reftMovementPath])) end

                    if oPlatoon[refiEnemiesInRange] + oPlatoon[refiEnemyStructuresInRange] == 0 then
                        --Head towards base as we either have low health or just got hit by an unseen unit so dont know that our current move target is safe
                        if bDebugMessages == true then LOG(sFunctionRef..': About to call returntobase') end
                        ReturnToBase(oPlatoon, iDistanceToRunBackBy, bDontClearActions, bTemporaryRetreat)
                        bTargetAwayFromNearestEnemy = true
                    else
                        --Can detect enemy units, so will see if current move target will take us far enough away from them

                        --IsDestinationAwayFromNearbyEnemies(aiBrain, tCurPos, tCurDestination, iEnemySearchRadius, bAlsoRunFromEnemyStartLocation)
                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': RunAway action - are nearby enemies so checking if moving away from them and enemy base``') end
                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': tCurPlatoonPos='..repr(tCurPlatoonPos)) end
                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': tPlatoonCurMoveLocation='..repr(tPlatoonCurMoveLocation)) end
                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]]='..repr(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]])) end
                        if IsDestinationAwayFromNearbyEnemies(aiBrain, tCurPlatoonPos, tPlatoonCurMoveLocation, math.max(oPlatoon[refiEnemySearchRadius], aiBrain[M27Overseer.refiSearchRangeForEnemyStructures]), true) == true and M27Utilities.GetDistanceBetweenPositions(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]], tCurPlatoonPos) >= iMinDistanceToRunBack then bTargetAwayFromNearestEnemy = true end
                        if bDebugMessages == true then
                            LOG('bTargetAwayFromNearestEnemy='..tostring(bTargetAwayFromNearestEnemy)..'; oPlatoon[refiCurrentPathTarget]='..oPlatoon[refiCurrentPathTarget]..'; oPlatoon[refiEnemySearchRadius]='..oPlatoon[refiEnemySearchRadius])
                            M27Utilities.DrawLocation(tCurPlatoonPos, nil, 1, 50)
                            M27Utilities.DrawLocation(tPlatoonCurMoveLocation, nil, 4, 50)
                        end
                    end
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Point 2: platoon movement path='..repr(oPlatoon[reftMovementPath])) end
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Action is to run; bTargetAwayFromNearestEnemy and enemy start='..tostring(bTargetAwayFromNearestEnemy)) end
                    if bTargetAwayFromNearestEnemy == false then
                        --Will need to change direction, so clear current commands
                        if bDontClearActions == false then IssueClearCommands(tCurrentUnits) end

                        --Not moving further away with the current movement path target, try the previous movement path
                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': 1s loop: Running away - Try moving to first mex location or start; iCurrentPathTarget='..oPlatoon[refiCurrentPathTarget]) end
                        local tTempMoveTarget = {}
                        --Would moving to the previous movement path mean we move away from the enemy?
                        tTempMoveTarget[1] = oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget] - 1][1]
                        tTempMoveTarget[2] = oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget] - 1][2]
                        tTempMoveTarget[3] = oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget] - 1][3]
                        if oPlatoon[refiCurrentPathTarget] > 1 and IsDestinationAwayFromNearbyEnemies(aiBrain, tCurPlatoonPos, tTempMoveTarget, math.max(oPlatoon[refiEnemySearchRadius], aiBrain[M27Overseer.refiSearchRangeForEnemyStructures]), false) == true and M27Utilities.GetDistanceBetweenPositions(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget] - 1], tCurPlatoonPos) >= iMinDistanceToRunBack then
                            bTargetAwayFromNearestEnemy = true
                            oPlatoon[refiCurrentPathTarget] = oPlatoon[refiCurrentPathTarget] - 1
                            if bTemporaryRetreat == true then
                                bUseTempPath = true
                                oPlatoon[reftTemporaryMoveTarget] = tTempMoveTarget
                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Setting temp move target '..repr(tTempMoveTarget)..' to earlier movement path') end
                            else
                                --Replace current movement path target with this
                                ReplaceMovementPathWithNewTarget(oPlatoon, tTempMoveTarget)
                            end
                        end

                        if bTargetAwayFromNearestEnemy == false then
                            --Try going towards base
                            tTempMoveTarget = M27Utilities.MoveTowardsTarget(tCurPlatoonPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iDistanceToRunBackBy, 0)
                            if IsDestinationAwayFromNearbyEnemies(aiBrain, tCurPlatoonPos, tTempMoveTarget, math.max(oPlatoon[refiEnemySearchRadius],aiBrain[M27Overseer.refiSearchRangeForEnemyStructures]), false) == true then
                                bTargetAwayFromNearestEnemy = true
                                if bTemporaryRetreat == true then
                                    bUseTempPath = true
                                    oPlatoon[reftTemporaryMoveTarget] = tTempMoveTarget
                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Setting temp move target '..repr(tTempMoveTarget)..' to towards base and away from nearest enemy') end
                                else
                                    --Replace current movement path target with this
                                    ReplaceMovementPathWithNewTarget(oPlatoon, tTempMoveTarget)
                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Replacing remaining movement path with the retreat location') end
                                end
                            else
                                --Just run in opposite direction to nearest enemy
                                local oNearestEnemy
                                if oPlatoon[refiEnemiesInRange] > 0 then oNearestEnemy = M27Utilities.GetNearestUnit(oPlatoon[reftEnemiesInRange], tCurPlatoonPos)
                                else oNearestEnemy = M27Utilities.GetNearestUnit(oPlatoon[reftEnemyStructuresInRange], tCurPlatoonPos) end

                                tTempMoveTarget = M27Utilities.MoveTowardsTarget(tCurPlatoonPos, oNearestEnemy:GetPosition(), iDistanceToRunBackBy, 180)
                                --IsDestinationAwayFromNearbyEnemies(aiBrain, tCurPos, tCurDestination, iEnemySearchRadius, bAlsoRunFromEnemyStartLocation)
                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': RunAway action - Seeing if moving in opposite direction will move us away') end
                                if IsDestinationAwayFromNearbyEnemies(aiBrain, tCurPlatoonPos, tTempMoveTarget, math.max(oPlatoon[refiEnemySearchRadius],aiBrain[M27Overseer.refiSearchRangeForEnemyStructures]), false) == true then
                                    bTargetAwayFromNearestEnemy = true
                                    if bTemporaryRetreat == true then
                                        bUseTempPath = true
                                        oPlatoon[reftTemporaryMoveTarget] = tTempMoveTarget
                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Setting temp move target '..repr(tTempMoveTarget)..' to move away from nearest enemy') end
                                    else
                                        --Replace current movement path target with this
                                        ReplaceMovementPathWithNewTarget(oPlatoon, tTempMoveTarget)
                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Replacing remaining movement path with the retreat location') end
                                    end
                                else
                                    --Although going to base may not be running from nearest enemy, other alternatives arent suitable either so just run towards base and hope we survive
                                    if bDebugMessages == true then
                                        LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Returning to base as moving away from nearest enemy doesnt move us away from other enemies; location that tried to move awawy to='..repr(tTempMoveTarget))
                                        M27Utilities.DrawLocation(tTempMoveTarget)
                                    end
                                    if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': A'..refActionReturnToBase) end
                                    local iReturnToBaseDistance --nil unless special case
                                    if oPlatoon[M27PlatoonTemplates.refbRunFromAllEnemies] == true then iReturnToBaseDistance = iDistanceToRunBackBy end
                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Point 2B: platoon movement path='..repr(oPlatoon[reftMovementPath])) end
                                    ReturnToBase(oPlatoon, iDistanceToRunBackBy, bDontClearActions, bTemporaryRetreat)
                                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Point 2c: platoon movement path='..repr(oPlatoon[reftMovementPath])) end
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Point 3: platoon movement path='..repr(oPlatoon[reftMovementPath])..'; bTargetAwayFromNearestEnemy='..tostring(bTargetAwayFromNearestEnemy)) end
                        if bTargetAwayFromNearestEnemy == true then
                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': bTargetAwayFromNearestEnemy is true; bUseTempPath='..tostring(bUseTempPath)) end
                            if bDontClearActions == false and iCurrentUnits > 0 then IssueClearCommands(tCurrentUnits) end
                            oPlatoon:SetPlatoonFormationOverride('GrowthFormation')
                            if not(bUseTempPath == true) then
                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': RunAway action - Are already moving away from nearest enemy based on the current movement path; oPlatoon[refiCurrentPathTarget]='..oPlatoon[refiCurrentPathTarget]) end
                                if iCurrentUnits > 0 then IssueMove(tCurrentUnits, oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]]) end
                                --oPlatoon:MoveToLocation(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]], false)
                                if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': RunToPrev') end
                            else
                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': RunAway action - moving to temporary move target') end
                                if iCurrentUnits > 0 then IssueMove(tCurrentUnits, oPlatoon[reftTemporaryMoveTarget]) end
                                --oPlatoon:MoveToLocation(oPlatoon[reftTemporaryMoveTarget], false)
                                if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': RunToTemp') end
                            end
                            --oPlatoon[refiLastPathTarget] = oPlatoon[refiCurrentPathTarget]
                            --WaitSeconds(2)
                        end
                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Point 4: platoon movement path='..repr(oPlatoon[reftMovementPath])) end
                    else
                        --Already moving from enemy, so no need to change things

                        --[[
                        --Already moving away from enemy, so no need to change things, unless we're moving to a temporary movement path
                        local bReissuePath = false
                        if oPlatoon[reftPrevAction][1] == refActionMoveDFToNearestEnemy or oPlatoon[reftPrevAction][1] == refActionMoveToTemporaryLocation then
                            bReissuePath = true
                            if bDebugMessages == true then LOG(sFunctionRef..': Prev action was to move somewhere else so will reissue movement path') end
                        else
                            --Check if cur destination is away from enemy if ACU in platoon
                            if oPlatoon[refbACUInPlatoon] == true then
                                if IsDestinationAwayFromNearbyEnemies(aiBrain, tCurPlatoonPos, M27Utilities.GetACU(aiBrain):GetNavigator():GetCurrentTargetPos(), math.max(oPlatoon[refiEnemySearchRadius], aiBrain[M27Overseer.refiSearchRangeForEnemyStructures]), true) == false then bReissuePath = true end
                            end
                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': 1s loop: Already running away from enemy, no need to change things unless we arent following our movement path. Prev action='..oPlatoon[reftPrevAction][1]..'; bReissuePath='..tostring(bReissuePath)) end
                        end
                        if bReissuePath == true then ReissueMovementPath(oPlatoon, false) end --]]
                    end
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': End of refActionRun; platoon movement path='..repr(oPlatoon[reftMovementPath])) end
                elseif oPlatoon[refiCurrentAction] == refActionReissueMovementPath then
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': About to call reissuemovementpath; bDontClearActions='..tostring(bDontClearActions)) end
                    ReissueMovementPath(oPlatoon, bDontClearActions)

                    --IssueMove(oPlatoon[reftCurrentUnits], oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]])
                elseif oPlatoon[refiCurrentAction] == refActionContinueMovementPath  then
                    --if if bDontClearActions == false then IssueClearCommands(oPlatoon[reftCurrentUnits]) end --already clear using MoveAlongPath
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': refActionContinueMovementPath') end
                    oPlatoon:SetPlatoonFormationOverride('AttackFormation')
                    --Update movement path if have already gone past it and are closer to the next part of the path:
                    if table.getn(oPlatoon[reftMovementPath]) > oPlatoon[refiCurrentPathTarget] then
                        local tPlatoonCurPos = GetPlatoonFrontPosition(oPlatoon)
                        if tPlatoonCurPos == nil then
                            M27Utilities.ErrorHandler(sPlatoonName..oPlatoon[refiPlatoonCount]..': Processing current action ContinueMovementPath - platoon has nil position so disbanding instead')
                            oPlatoon[refiCurrentAction] = refActionDisband
                            --if oPlatoon and aiBrain:PlatoonExists(oPlatoon) then oPlatoon:PlatoonDisband() end
                        else
                            if M27Utilities.GetDistanceBetweenPositions(tPlatoonCurPos, oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget] + 1]) < M27Utilities.GetDistanceBetweenPositions(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]], oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]+1]) then
                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Are moving current path target up 1 as a recloser to next destination than current; refiCurrentPathTarget='..oPlatoon[refiCurrentPathTarget]..'; table.getn(oPlatoon[reftMovementPath])='..table.getn(oPlatoon[reftMovementPath])) end
                                oPlatoon[refiCurrentPathTarget] = oPlatoon[refiCurrentPathTarget] + 1
                            else
                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Are not moving current path target up 1. Distance between platoon and current target='..M27Utilities.GetDistanceBetweenPositions(tPlatoonCurPos, oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget] + 1])..'; distance between current and next move targets='..M27Utilities.GetDistanceBetweenPositions(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]], oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]+1])..'; refiCurrentPathTarget='..oPlatoon[refiCurrentPathTarget]..'; table.getn(oPlatoon[reftMovementPath])='..table.getn(oPlatoon[reftMovementPath])) end
                            end
                        end
                    end

                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': About to issue MoveAlongPath order, oPlatoon[refiCurrentPathTarget]='..oPlatoon[refiCurrentPathTarget]) end
                    MoveAlongPath(oPlatoon, oPlatoon[reftMovementPath], oPlatoon[M27PlatoonTemplates.refbAttackMove], oPlatoon[refiCurrentPathTarget], bDontClearActions)
                elseif oPlatoon[refiCurrentAction] == refActionNewMovementPath  then
                  --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Pre getting new movement path') end
                    GetNewMovementPath(oPlatoon, bDontClearActions)
                  --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Post getting new movement path') end
                    if oPlatoon[refiCurrentAction] == refActionReissueMovementPath then ReissueMovementPath(oPlatoon, bDontClearActions) end

                elseif oPlatoon[refiCurrentAction] == refActionUseAttackAI  then
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': refActionuseAttackAI') end
                    oPlatoon:SetAIPlan('M27AttackNearestUnits')
                elseif oPlatoon[refiCurrentAction] == refActionDisband then
                    --Refresh the unit list
                    local tPlatoonUnits = oPlatoon:GetPlatoonUnits()
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Platoon disbanding') end
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': refActionDisband') end
                    if oPlatoon then
                        if aiBrain:PlatoonExists(oPlatoon) and M27Utilities.IsTableEmpty(tPlatoonUnits) == false then
                            if oPlatoon[refbACUInPlatoon] == false then

                                local iRallyPointIntelLine = aiBrain[M27Overseer.refiCurIntelLineTarget]
                                local tRallyPoint
                                if iRallyPointIntelLine then
                                    iRallyPointIntelLine = iRallyPointIntelLine - 2
                                    if iRallyPointIntelLine < 0 then iRallyPointIntelLine = 1 end
                                    tRallyPoint = aiBrain[M27Overseer.reftIntelLinePositions][iRallyPointIntelLine][1]
                                end
                                if iRallyPointIntelLine == nil or M27Utilities.IsTableEmpty(tRallyPoint) == true then
                                    tRallyPoint = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                                end
                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Still have units, so sending them to rallypoint='..repr(tRallyPoint)) end

                                M27PlatoonFormer.AllocateNewUnitsToPlatoonNotFromFactory(tPlatoonUnits)
                            end
                        end
                        --Was there a helper assigned to this platoon? If so clear its target and tell it to return to base
                        local refHelper = M27Overseer.refoUnitsScoutHelper
                        local oHelperPlatoon
                        for iHelperType = 1, 2 do
                            if iHelperType == 2 then
                                refHelper = M27Overseer.refoUnitsMAAHelper
                            end
                            oHelperPlatoon = oPlatoon[refHelper]
                            if oHelperPlatoon then
                                oHelperPlatoon[refoSupportHelperPlatoonTarget] = nil
                                oHelperPlatoon[refbOverseerAction] = true
                                oHelperPlatoon[refiOverseerAction] = refActionReturnToBase
                            end
                        end
                        --Are we escorting a platoon? If so then clear that platoon's tracker
                        if oPlatoon[refoPlatoonOrUnitToEscort] and oPlatoon[refoPlatoonOrUnitToEscort][refoEscortingPlatoon] == oPlatoon then oPlatoon[refoPlatoonOrUnitToEscort][refoEscortingPlatoon] = nil end
                        --Are we being escorted by a platoon? If so then disband that platoon
                        if oPlatoon[refoEscortingPlatoon] and oPlatoon[refoEscortingPlatoon][refoPlatoonOrUnitToEscort] == oPlatoon then
                            if bDebugMessages == true then LOG(sFunctionRef..': We are being escorted by a platoon so will disband that platoon') end
                            oPlatoon[refoEscortingPlatoon][refoPlatoonOrUnitToEscort] = nil
                            oPlatoon[refoEscortingPlatoon][refiCurrentAction] = refActionDisband
                        end
                        --Are we being tracked as needing an escort?
                        if oPlatoon[refiNeedingEscortUniqueCount] and aiBrain[reftPlatoonsOrUnitsNeedingEscorts][oPlatoon[refiNeedingEscortUniqueCount]] then
                            table.remove(aiBrain[reftPlatoonsOrUnitsNeedingEscorts], oPlatoon[refiNeedingEscortUniqueCount])
                        end
                        --Are we a mobile shield platoon? If so then assign the shield to a retreating platoon
                        if sPlatoonName == 'M27MobileShield' then
                            local tRemainingUnits = oPlatoon:GetPlatoonUnits()
                            if M27Utilities.IsTableEmpty(tRemainingUnits) == false then
                                local oShieldPlatoon = M27PlatoonFormer.CreatePlatoon(aiBrain, 'M27RetreatingShieldUnits', tRemainingUnits, true)
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Will now disband platoon with ref='..oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]) end
                        aiBrain:DisbandPlatoon(oPlatoon)
                    end
                elseif oPlatoon[refiCurrentAction] == refActionMoveDFToNearestEnemy  then
                    --Update the name just for direct fire units hence commented out below
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': refActionMoveDFToNearestEnemy') end
                    if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': About to process move DF to nearest enemy') end
                    if oPlatoon[refiEnemiesInRange] + oPlatoon[refiEnemyStructuresInRange] > 0 then
                        if oPlatoon[refiDFUnits] > 0 and GetPlatoonUnitsOrUnitCount(oPlatoon, reftDFUnits, true, true) > 0 then
                            if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': We have DF units in our platoon') end
                            local oTargetEnemy
                            if oPlatoon[refiEnemiesInRange] == 0 then oTargetEnemy = M27Utilities.GetNearestUnit(oPlatoon[reftEnemyStructuresInRange], GetPlatoonFrontPosition(oPlatoon))
                            elseif oPlatoon[refiEnemyStructuresInRange] == 0 then oTargetEnemy = M27Utilities.GetNearestUnit(oPlatoon[reftEnemiesInRange], GetPlatoonFrontPosition(oPlatoon))
                            else
                                oTargetEnemy = M27Utilities.GetNearestUnit(M27Utilities.CombineTables(oPlatoon[reftEnemiesInRange], oPlatoon[reftEnemyStructuresInRange]), GetPlatoonFrontPosition(oPlatoon))
                            end
                            if oTargetEnemy then
                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Have a target to move to. bDontClearActions='..tostring(bDontClearActions)) end
                                if bDontClearActions == false then IssueClearCommands(GetPlatoonUnitsOrUnitCount(oPlatoon, reftDFUnits, false, true)) end
                                oPlatoon[reftTemporaryMoveTarget] = oTargetEnemy:GetPosition()
                                if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Sending Issue Move to DF units') end
                                IssueMove(GetPlatoonUnitsOrUnitCount(oPlatoon, reftDFUnits, false, true), oPlatoon[reftTemporaryMoveTarget])
                                if oPlatoon[refiScoutUnits] > 0 and GetPlatoonUnitsOrUnitCount(oPlatoon, reftScoutUnits, true, true) > 0 then
                                    if bDontClearActions == false then IssueClearCommands(GetPlatoonUnitsOrUnitCount(oPlatoon, reftScoutUnits, false, true)) end
                                    UpdateScoutPositions(oPlatoon) --Moves scouts to platoon average position
                                end
                                if bPlatoonNameDisplay == true then --Only update name of DF units (so cant use normal function):
                                    for iUnit, oUnit in oPlatoon[reftDFUnits] do
                                        if not oUnit.Dead then
                                            oUnit:SetCustomName(sPlatoonName..oPlatoon[refiPlatoonCount]..': DFUnitsMoveToEnemy')
                                        end
                                    end
                                end
                            else
                                M27Utilities.ErrorHandler(sPlatoonName..oPlatoon[refiPlatoonCount]..': Warning - Told to move DF units to nearby enemy but no nearby enemy')
                            end
                            --WaitSeconds(1)
                        else
                            M27Utilities.ErrorHandler(sPlatoonName..oPlatoon[refiPlatoonCount]..': Told to move DF units to nearby enemy but we have no DF units in our platoon')
                        end
                    end

                elseif oPlatoon[refiCurrentAction] == refActionReturnToBase   then
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': refActionReturnToBase') end
                    ReturnToBase(oPlatoon)
                elseif oPlatoon[refiCurrentAction] == refActionReclaimTarget then
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': ActionReclaim') end
                    if bDebugMessages == true then
                        local iReclaim = oPlatoon[refoNearbyReclaimTarget].MaxMassReclaim
                        if iReclaim == nil then iReclaim = 0 end
                        LOG(sFunctionRef..': Have a reclaim target, mass on reclaim='..iReclaim)
                    end
                    --Will have already determined reclaim target as part of the check whether to reclaim (for efficiency)
                    if oPlatoon[reftReclaimers] and oPlatoon[refoNearbyReclaimTarget] and M27Utilities.IsTableEmpty(GetPlatoonUnitsOrUnitCount(oPlatoon, reftReclaimers, false, true)) == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..' about to issue reclaim target') end
                        if bDontClearActions == false then IssueClearCommands(GetPlatoonUnitsOrUnitCount(oPlatoon, reftReclaimers, false, true)) end
                        IssueReclaim(GetPlatoonUnitsOrUnitCount(oPlatoon, reftReclaimers, false, true), oPlatoon[refoNearbyReclaimTarget])
                    else
                        if M27Utilities.IsTableEmpty(GetPlatoonUnitsOrUnitCount(oPlatoon, reftReclaimers, false, true)) == true then
                            --Aborted due to units being busy on micro
                        else
                            M27Utilities.ErrorHandler(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': the object to be reclaim doesnt exist or we dont have reclaimers in the platoon')
                            if oPlatoon[reftReclaimers] then LOG('tReclaimers is valid') end
                            if oPlatoon[refoNearbyReclaimTarget] then LOG('Reclaim target is valid') end
                            LOG('Size of tReclaimers='..GetPlatoonUnitsOrUnitCount(oPlatoon, reftReclaimers, true, true))
                        end
                    end
                    --Add move command so unit wont stay idle
                    IssueMove(GetPlatoonUnitsOrUnitCount(oPlatoon, reftReclaimers, false, true), oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]])
                elseif oPlatoon[refiCurrentAction] == refActionReclaimAllNearby then
                    --Have reclaim potentially near us - action will be cleared as part of engineer logic
                    local tAvailableReclaimers = GetPlatoonUnitsOrUnitCount(oPlatoon, reftReclaimers, false, true)
                    if M27Utilities.IsTableEmpty(tAvailableReclaimers) == false then
                        for iEngineer, oEngineer in tAvailableReclaimers do
                            oEngineer[M27EngineerOverseer.reftEngineerCurrentTarget] = oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]]
                            if bDebugMessages == true then LOG(sFunctionRef..': Have set engineer '..oEngineer:GetUnitId()..' with LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' to have a current target of '..repr(oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]] or {'nil'})..'; oEngineer[M27EngineerOverseer.reftEngineerCurrentTarget]='..repr(oEngineer[M27EngineerOverseer.reftEngineerCurrentTarget] or {'nil'})) end
                            --UpdateActionForNearbyReclaim(oEngineer, iMinReclaimIndividualValue, bDontIssueMoveAfter)
                            M27EngineerOverseer.UpdateActionForNearbyReclaim(oEngineer, 5, true)
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': About to reissue movement path after updating action for nearby reclaim') end
                        ReissueMovementPath(oPlatoon, true)
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': tReclaimers is nil; oPlatoon[refiReclaimers]='..oPlatoon[refiReclaimers]..'; Is micro active on first unit on platoon='..tostring(oPlatoon[refoFrontUnit].M27UnitInfo.refbSpecialMicroActive or false)) end
                    end
                elseif oPlatoon[refiCurrentAction] == refActionBuildMex then
                    --Will have already determined the location to build the mex on (and checked its available to build oin) as part of the check of whether to have this as an action
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': ActionBuildMex') end
                    if GetPlatoonUnitsOrUnitCount(oPlatoon, reftBuilders, true, true) > 0 then
                        local tBuilders = GetPlatoonUnitsOrUnitCount(oPlatoon, reftBuilders, false, true)
                        if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..' about to issue command to build mex at location '..repr(oPlatoon[reftNearbyMexToBuildOn])..'; bDontClearActions='..tostring(bDontClearActions)) end
                        if bDontClearActions == false then IssueClearCommands(tBuilders) end
                        if bDebugMessages == true then M27Utilities.DrawLocation(oPlatoon[reftNearbyMexToBuildOn], nil, nil, 20) end --blue circle
                        --First move near construction if it's different to current move target
                        local tMoveNearMex
                        local tBuilderCurPos
                        local bDontMoveBefore = false
                        for _, oBuilder in tBuilders do
                            if not(oBuilder.Dead) then
                                --Not sure how well this will work with platoons containing multiple builders - if gives issues then switch to using assist for the remaining units
                                --M27BuildStructureAtLocation(oBuilder, sBuildingType, tBuildLocation, bMoveNearFirst)
                                if bDebugMessages == true then LOG(sFunctionRef..': First builder position='..repr(oBuilder:GetPosition())) end
                                --MoveNearConstruction(aiBrain, oBuilder, tLocation, sBlueprintID, iBuildDistanceMod, bReturnMovePathInstead, bUpdatePlatoonMovePath, bReturnNilIfAlreadyMovingNearConstruction)
                                tMoveNearMex = MoveNearConstruction(aiBrain, oBuilder, oPlatoon[reftNearbyMexToBuildOn], 'UAB1103', -0.1, true, false, true)
                                if tMoveNearMex then
                                    --Check if this is different to current position by enough (as movenearconstruction returns current position if dont need to change things)
                                    tBuilderCurPos = oBuilder:GetPosition()
                                    if M27Utilities.GetDistanceBetweenPositions(tMoveNearMex, tBuilderCurPos) < 1 then bDontMoveBefore = true tMoveNearMex = nil end
                                else bDontMoveBefore = true
                                end

                                break
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': BuildingMex process action; bDontMoveBefore='..tostring(bDontMoveBefore)) end
                        if bDontMoveBefore == false then
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': tMoveNearMex='..repr(tMoveNearMex))
                                M27Utilities.DrawLocation(tMoveNearMex, nil, 3, 20) --orange circle
                            end
                            IssueMove(tBuilders, tMoveNearMex)
                        end
                        for _, oBuilder in tBuilders do
                            if not(oBuilder.Dead) then
                                --AIBuildStructures.M27BuildStructureAtLocation(oBuilder, 'T1Resource', oPlatoon[reftNearbyMexToBuildOn])
                                if bDebugMessages == true then LOG(sFunctionRef..': Issuing build command to '..oBuilder:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oBuilder)..'; to build mex at '..repr(oPlatoon[reftNearbyMexToBuildOn])) end
                                AIBuildStructures.M27BuildStructureDirectAtLocation(oBuilder, 'T1Resource', oPlatoon[reftNearbyMexToBuildOn])
                            end
                        end
                        --Move as soon as are done:
                        IssueMove(tBuilders, oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]])
                    end
                elseif oPlatoon[refiCurrentAction] == refActionBuildLandFactory then
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': BuildLandFac') end
                    if GetPlatoonUnitsOrUnitCount(oPlatoon, reftBuilders, true, true) > 0 then
                        local tBuilders = GetPlatoonUnitsOrUnitCount(oPlatoon, reftBuilders, false, true)
                        if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..' about to issue command to build land factory; bDontClearActions='..tostring(bDontClearActions)) end
                        if bDontClearActions == false then IssueClearCommands(tBuilders) end
                        local oACU = M27Utilities.GetACU(aiBrain)
                        local iCategoryToBuild = M27UnitInfo.refCategoryLandFactory
                        local iMaxAreaToSearch = 35
                        local iCategoryToBuildBy = M27UnitInfo.refCategoryT1Mex
                        local oNearbyUnderConstruction = M27EngineerOverseer.GetPartCompleteBuilding(aiBrain, oACU, iCategoryToBuild, iMaxAreaToSearch, 30)
                        if oNearbyUnderConstruction == nil then
                            --BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCategoryToBuildBy, tAlternativePositionToLookFrom)
                            if bDebugMessages == true then LOG(sFunctionRef..': About to tell ACU to build land factory') end
                            M27EngineerOverseer.BuildStructureAtLocation(aiBrain, oACU, iCategoryToBuild, iMaxAreaToSearch, iCategoryToBuildBy, nil)
                            --Move as soon as are done:
                            IssueMove(tBuilders, oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]])
                        else
                            IssueGuard(tBuilders, oNearbyUnderConstruction)
                        end
                    end
                elseif oPlatoon[refiCurrentAction] == refActionBuildInitialPower then
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': BuildPower') end
                    if GetPlatoonUnitsOrUnitCount(oPlatoon, reftBuilders, true, true) > 0 then
                        local tBuilders = GetPlatoonUnitsOrUnitCount(oPlatoon, reftBuilders, false, true)
                        if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..' about to issue command to build power; bDontClearActions='..tostring(bDontClearActions)) end
                        if bDontClearActions == false then IssueClearCommands(tBuilders) end
                        local oACU = M27Utilities.GetACU(aiBrain)
                        local iCategoryToBuild = M27UnitInfo.refCategoryPower
                        local iMaxAreaToSearch = 14
                        local iCategoryToBuildBy = M27UnitInfo.refCategoryLandFactory

                        --BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCategoryToBuildBy, tAlternativePositionToLookFrom)
                        if bDebugMessages == true then LOG(sFunctionRef..': About to tell ACU to build power') end
                        local tBuildLocation = M27EngineerOverseer.BuildStructureAtLocation(aiBrain, oACU, iCategoryToBuild, iMaxAreaToSearch, iCategoryToBuildBy, nil)

                        local oNearbyUnderConstruction = M27EngineerOverseer.GetPartCompleteBuilding(aiBrain, oACU, iCategoryToBuild, iMaxAreaToSearch, 30)
                        if oNearbyUnderConstruction == nil then
                            --BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCategoryToBuildBy, tAlternativePositionToLookFrom)
                            if bDebugMessages == true then LOG(sFunctionRef..': About to tell ACU to build land factory') end
                            M27EngineerOverseer.BuildStructureAtLocation(aiBrain, oACU, iCategoryToBuild, iMaxAreaToSearch, iCategoryToBuildBy, nil)
                            --Move as soon as are done:
                            IssueMove(tBuilders, oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]])
                        else
                            IssueGuard(tBuilders, oNearbyUnderConstruction)
                        end

                        --Update engineer trackers so they can assist us
                                                        --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers)
                        M27EngineerOverseer.UpdateEngineerActionTrackers(aiBrain, oACU, M27EngineerOverseer.refActionBuildPower, tBuildLocation, false, nil, nil, false)
                        --Move as soon as are done:
                        IssueMove(tBuilders, oPlatoon[reftMovementPath][oPlatoon[refiCurrentPathTarget]])
                    end

                elseif oPlatoon[refiCurrentAction] == refActionAssistConstruction then
                    --shoudl have already determined the unit/building to assist previously
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..':ActionAssistConstruction') end
                    if GetPlatoonUnitsOrUnitCount(oPlatoon, reftBuilders, true, true) > 0 then
                        local tBuilders = GetPlatoonUnitsOrUnitCount(oPlatoon, reftBuilders, false, true)
                        if bDontClearActions == false then IssueClearCommands(tBuilders) end
                        --Is it in our build range?
                        local iBuildDistance = 5
                        local tBuildingPosition = oPlatoon[refoConstructionToAssist]:GetPosition()
                        if bDebugMessages == true then LOG(sFunctionRef..':'..sPlatoonName..': about to assign construction target to assist') end
                        for _, oBuilder in tBuilders do
                            if not(oBuilder.Dead) then
                                iBuildDistance = oBuilder:GetBlueprint().Economy.MaxBuildDistance
                                if M27Utilities.GetDistanceBetweenPositions(tBuildingPosition, oBuilder:GetPosition()) > iBuildDistance then
                                    --Move to location
                                    if bDebugMessages == true then LOG(sFunctionRef..':'..sPlatoonName..': Are too far away, will move closer before assisting') end
                                    if oPlatoon[refiOverrideDistanceToReachDestination] == nil then oPlatoon[refiOverrideDistanceToReachDestination] = 3 end --(redundancy as set when platoon first created if there are builders in it)
                                    MoveNearConstruction(aiBrain, oBuilder, tBuildingPosition, oPlatoon[refoConstructionToAssist]:GetUnitId(), -oPlatoon[refiOverrideDistanceToReachDestination] - 1, false)
                                end
                                IssueGuard({oBuilder}, oPlatoon[refoConstructionToAssist])
                                if bDebugMessages == true then LOG(sFunctionRef..':'..sPlatoonName..': Issued guard order to assist') end
                            end
                        end
                    end
                elseif oPlatoon[refiCurrentAction] == refActionMoveJustWithinRangeOfNearestPD then
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..':ActionMoveNearPD') end
                    if iCurrentUnits > 0 then
                        if bDontClearActions == false then IssueClearCommands(tCurrentUnits) end
                        --Locate nearest PD:
                        if oPlatoon[refiEnemyStructuresInRange] > 0 then
                            local tNearbyPD = EntityCategoryFilterDown(categories.DIRECTFIRE, oPlatoon[reftEnemyStructuresInRange])
                            if M27Utilities.IsTableEmpty(tNearbyPD) == false then
                                local tPlatoonPosition = GetPlatoonFrontPosition(oPlatoon)
                                local oNearestPD = M27Utilities.GetNearestUnit(tNearbyPD, tPlatoonPosition, aiBrain, true)
                                local iPlatoonMaxRange = M27Logic.GetUnitMaxGroundRange(oPlatoon[reftCurrentUnits])
                                if not(iPlatoonMaxRange == nil) and iPlatoonMaxRange > 0 then
                                                    --GetPositionNearTargetInSamePathingGroup(tStartPos, tTargetPos, iDistanceWantedFromTarget, iAngleBase, oPathingUnit, iNearbyMethodIfBlocked, bTrySidePositions)
                                    local iDistanceFromPDWanted = iPlatoonMaxRange - math.ceil(oPlatoon[refiCurrentUnits] / 4)
                                    if iDistanceFromPDWanted < 0 then iDistanceFromPDWanted = 0 end
                                    local tMoveTarget = GetPositionNearTargetInSamePathingGroup(tPlatoonPosition, oNearestPD:GetPosition(), iDistanceFromPDWanted, 0, GetPathingUnit(oPlatoon), 1, true)
                                    if tMoveTarget then
                                        if bDebugMessages == true then LOG(sPlatoonName..oPlatoon[refiPlatoonCount]..': Move target for enemy PD='..repr(tMoveTarget)) end
                                        IssueMove(tCurrentUnits, tMoveTarget)
                                    else
                                        --Have a nearby enemy PD but can't move within range of it - resume normal move path (but dont clear actions)
                                        ReissueMovementPath(oPlatoon, true)
                                    end
                                else
                                    LOG(sFunctionRef..':'..sPlatoonName..oPlatoon[refiPlatoonCount]..': Likely error - sent action to move within range of nearest PD, but platoon has no max range')
                                end
                            else
                                LOG(sFunctionRef..':'..sPlatoonName..oPlatoon[refiPlatoonCount]..': Likely error - sent action to move within range of nearest PD, and no nearby structures found')
                            end
                        else
                            LOG(sFunctionRef..':'..sPlatoonName..oPlatoon[refiPlatoonCount]..': Likely error - sent action to move within range of nearest PD, and no nearby structures found')
                        end
                    end
                elseif oPlatoon[refiCurrentAction] == refActionMoveToTemporaryLocation then
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..':ActionTempMove') end
                    if iCurrentUnits > 0 then
                        if bDontClearActions == false then IssueClearCommands(tCurrentUnits) end
                        if M27Utilities.IsTableEmpty(oPlatoon[reftTemporaryMoveTarget]) == true then
                            M27Utilities.ErrorHandler('Temporary move target is blank, will send log with platoon details if theyre not blank')
                            if oPlatoon.GetPlan and oPlatoon:GetPlan() and oPlatoon[refiPlatoonCount] and oPlatoon[refiCurrentUnits] then LOG('Platoon plan, count and current units='..oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]..'; units='..oPlatoon[refiCurrentUnits])
                                else LOG('Platoon core values contained a nil value') end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': Temporary move target='..repr(oPlatoon[reftTemporaryMoveTarget])) end
                            if ShouldPlatoonMoveInFormation(oPlatoon, false) then IssueFormMove(tCurrentUnits, oPlatoon[reftTemporaryMoveTarget], (oPlatoon.PlatoonData.UseFormation or 'GrowthFormation'), 0)
                            else IssueMove(tCurrentUnits, oPlatoon[reftTemporaryMoveTarget]) end
                            local bAttackMove = oPlatoon[M27PlatoonTemplates.refbAttackMove]
                            MoveAlongPath(oPlatoon, oPlatoon[reftMovementPath], bAttackMove, oPlatoon[refiCurrentPathTarget], true)
                        end
                    end
                elseif oPlatoon[refiCurrentAction] == refActionAttackSpecificUnit then
                    --if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..':ActionSpecificUnitAttack') end
                    if oPlatoon[refoTemporaryAttackTarget] == nil then M27Utilities.ErrorHandler('Temporary attack target is nil')
                    else
                        if iCurrentUnits > 0 then
                            if bDontClearActions == false then IssueClearCommands(tCurrentUnits) end
                            IssueAttack(tCurrentUnits, oPlatoon[refoTemporaryAttackTarget])
                        end
                    end
                elseif oPlatoon[refiCurrentAction] == refActionUpgrade then
                    if not(oPlatoon[refbACUInPlatoon]) then M27Utilities.ErrorHandler('Dont have code to handle non-ACU upgrades yet')
                    else
                        local oACU = M27Utilities.GetACU(aiBrain)
                        if not(oACU:IsUnitState('Upgrading')) and not(oACU[M27UnitInfo.refbSpecialMicroActive]) then
                            --Get a new upgrade
                            local sUpgrade = GetACUUpgradeWanted(aiBrain, oACU)
                            if sUpgrade then
                                if bDontClearActions == false then IssueClearCommands(oPlatoon[reftCurrentUnits]) end
                                if bDebugMessages == true then LOG(sFunctionRef..': About to tell ACU to upgrade using sUpgrade='..sUpgrade) end
                                IssueScript({oACU}, {TaskName = 'EnhanceTask', Enhancement = sUpgrade})
                                --IssueUpgrade({oACU}, sUpgrade)
                                if bDebugMessages == true then LOG(sFunctionRef..'ACU state after sending issueupgrade='..M27Logic.GetUnitState(oACU)) end
                            end
                        end
                    end
                elseif oPlatoon[refiCurrentAction] == refActionKillACU then
                    --bDebugMessages = true
                    if bDontClearActions == false then IssueClearCommands(tCurrentUnits) end
                    local tDFUnits = GetPlatoonUnitsOrUnitCount(oPlatoon, reftDFUnits, false, true)
                    local iDistanceWithinAttackRange = 11
                    local iDistanceBehindACUWanted = 2
                    local iOffsetToNotBlockACUDistance = 5
                    local iDistanceFromACUForUnitMicro = 40 --If platoon front unit is this close to ACU then will do micro on a unit by unit basis
                    local bPerUnitMicro = false

                    --Pick a location that means we're less likely to block the ACU if its in the attack
                    --ACU direction from our base
                    local iACULikelyFleeAngle = M27Utilities.GetAngleFromAToB(aiBrain[M27Overseer.reftLastNearestACU], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    local tPositionBehindEnemyACU = M27Utilities.MoveInDirection(aiBrain[M27Overseer.reftLastNearestACU], iACULikelyFleeAngle, iDistanceBehindACUWanted)
                    local tTargetMoveLocation
                    local iOurACUAngleToTarget
                    local tACUPos = M27Utilities.GetACU(aiBrain):GetPosition()
                    local iACUDistanceToTarget = M27Utilities.GetDistanceBetweenPositions(tACUPos, aiBrain[M27Overseer.reftLastNearestACU])
                    if aiBrain[M27Overseer.refbIncludeACUInAllOutAttack] and not(oPlatoon[refbACUInPlatoon]) then
                        if M27Utilities.IsTableEmpty(tDFUnits) == false and M27Utilities.GetDistanceBetweenPositions(tACUPos, GetPlatoonFrontPosition(oPlatoon)) <= iDistanceFromACUForUnitMicro then
                            bPerUnitMicro = true
                        end
                    else
                        bPerUnitMicro = true
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': '..oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]..': bPerUnitMicro='..tostring(bPerUnitMicro)..'; M27Utilities.IsTableEmpty(tDFUnits)='..tostring(M27Utilities.IsTableEmpty(tDFUnits))..'; aiBrain[M27Overseer.refbIncludeACUInAllOutAttack]='..tostring(aiBrain[M27Overseer.refbIncludeACUInAllOutAttack])..'; M27Utilities.GetDistanceBetweenPositions(tACUPos, GetPlatoonFrontPosition(oPlatoon))='..M27Utilities.GetDistanceBetweenPositions(tACUPos, GetPlatoonFrontPosition(oPlatoon))) end

                    local tIndirectUnits = GetPlatoonUnitsOrUnitCount(oPlatoon, reftIndirectUnits, false, true)

                    if tDFUnits and table.getn(tDFUnits) > 0 then
                        oPlatoon[reftPlatoonDFTargettingCategories] = M27UnitInfo.refWeaponPriorityACU
                        if not(oPlatoon[refbACUInPlatoon]) then iOurACUAngleToTarget = M27Utilities.GetAngleFromAToB(tACUPos, tPositionBehindEnemyACU) end
                        if bPerUnitMicro == true then
                            if bDebugMessages == true then LOG(sFunctionRef..': '..oPlatoon:GetPlan()..oPlatoon[refiPlatoonCount]..': tDFUnits='..table.getn(tDFUnits)..'; oPlatoon[refbACUInPlatoon]='..tostring(oPlatoon[refbACUInPlatoon])..'; aiBrain[M27Overseer.refbIncludeACUInAllOutAttack]='..tostring(aiBrain[M27Overseer.refbIncludeACUInAllOutAttack])) end
                            for iDFUnit, oDFUnit in tDFUnits do
                                if M27UnitInfo.IsUnitValid(oDFUnit) then
                                    --Are we further from target than our ACU and our ACU is in the attack?
                                    if bDebugMessages == true then LOG(sFunctionRef..': oDFUnit='..oDFUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oDFUnit)..'; Position to enemy ACU='..M27Utilities.GetDistanceBetweenPositions(oDFUnit:GetPosition(), aiBrain[M27Overseer.reftLastNearestACU])..'; iACUDistanceToTarget='..iACUDistanceToTarget..'; iOffsetToNotBlockACUDistance='..iOffsetToNotBlockACUDistance) end
                                    --Check if we're further away from target than ACU (ignore if within a bit of ACU distance to avoid us dobuling back)
                                    if aiBrain[M27Overseer.refbIncludeACUInAllOutAttack] and not(oPlatoon[refbACUInPlatoon]) then
                                        local iDFDistToTarget = M27Utilities.GetDistanceBetweenPositions(oDFUnit:GetPosition(), aiBrain[M27Overseer.reftLastNearestACU])
                                        if (iDFDistToTarget - iOffsetToNotBlockACUDistance * 0.6 + 1) >=  iACUDistanceToTarget or (iDFDistToTarget > iACUDistanceToTarget and M27Utilities.GetDistanceBetweenPositions(tACUPos, oDFUnit:GetPosition()) <= 2) then
                                            --We're further away than ACU so take detour
                                            if bDebugMessages == true then LOG(sFunctionRef..': tACUPos before getting position to side of target='..repr(tACUPos)) end
                                            IssueMove({oDFUnit}, M27Logic.GetPositionToSideOfTarget(oDFUnit, tACUPos, iOurACUAngleToTarget, iOffsetToNotBlockACUDistance))
                                            if bDebugMessages == true then LOG(sFunctionRef..': Want to detour by ACU; Details after getting position to side of targeet: Our position='..repr(oDFUnit:GetPosition())..'; ACU pos='..repr(tACUPos)..'; Detour='..repr(M27Logic.GetPositionToSideOfTarget(oDFUnit, tACUPos, iOurACUAngleToTarget, iOffsetToNotBlockACUDistance))..'; Angle from us to ACU='..M27Utilities.GetAngleFromAToB(oDFUnit:GetPosition(), tACUPos)..'; iOurACUAngleToTarget='..iOurACUAngleToTarget) end
                                        end
                                    end
                                    --Check how close we are to the target
                                    local iPlatoonRange = M27Logic.GetUnitMaxGroundRange({ oDFUnit})
                                    local iDistToTarget = M27Utilities.GetDistanceBetweenPositions(oDFUnit:GetPosition(), aiBrain[M27Overseer.reftLastNearestACU])
                                    if iDistToTarget < iPlatoonRange - iDistanceWithinAttackRange then
                                        IssueAttack({oDFUnit}, aiBrain[M27Overseer.refoLastNearestACU])
                                    else
                                        --Revise move position to be away from target unless we are the ACU
                                        if oPlatoon[refbACUInPlatoon] == false then
                                            tTargetMoveLocation = M27Logic.GetPositionToSideOfTarget(oDFUnit, tPositionBehindEnemyACU, iOurACUAngleToTarget, iOffsetToNotBlockACUDistance)
                                        else
                                            --ACU move location
                                            tTargetMoveLocation = tPositionBehindEnemyACU
                                        end
                                        IssueMove({oDFUnit}, tTargetMoveLocation)
                                    end
                                end
                            end
                        else
                            --Apply logic based on entire platoon
                            local iPlatoonRange = M27Logic.GetUnitMaxGroundRange(tDFUnits)
                            local iDistToTarget = M27Utilities.GetDistanceBetweenPositions(GetPlatoonFrontPosition(oPlatoon), aiBrain[M27Overseer.reftLastNearestACU])
                            if iDistToTarget < iPlatoonRange - iDistanceWithinAttackRange then
                                IssueAttack(tDFUnits, aiBrain[M27Overseer.refoLastNearestACU])
                            else
                                if M27UnitInfo.IsUnitValid(oPlatoon[refoFrontUnit]) then
                                    tTargetMoveLocation = M27Logic.GetPositionToSideOfTarget(oPlatoon[refoFrontUnit], tPositionBehindEnemyACU, iOurACUAngleToTarget, iOffsetToNotBlockACUDistance)
                                    IssueMove(tDFUnits, tTargetMoveLocation)
                                end
                            end
                        end

                        --Set weapon priorities
                        for iUnit, oUnit in tDFUnits do
                            M27UnitInfo.SetUnitTargetPriorities(oUnit, oPlatoon[reftPlatoonDFTargettingCategories])
                        end


                        --If indirect fire and direct fire units in the same platoon then also attack with these
                        if M27Utilities.IsTableEmpty(tIndirectUnits) == false then IssueAttack(tIndirectUnits, aiBrain[M27Overseer.refoLastNearestACU]) end
                    else
                        --No DF units in platoon
                        if M27Utilities.IsTableEmpty(tIndirectUnits) == false then
                            local tNearbyStructures = GetPlatoonUnitsOrUnitCount(oPlatoon, reftEnemyStructuresInRange, false, true)
                            local tNearbyPD
                            if tNearbyStructures then tNearbyPD = EntityCategoryFilterDown(M27UnitInfo.refCategoryPD, tNearbyStructures) end

                            if M27Utilities.IsTableEmpty(tNearbyPD) == true or M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.TECH1, tIndirectUnits)) == false then
                                IssueAttack(tIndirectUnits, aiBrain[M27Overseer.refoLastNearestACU])
                            else
                                IssueIndirectAttack(oPlatoon, false)
                            end
                        end
                    end

                else
                    --Unrecognised platoon action
                    if oPlatoon[refiCurrentAction]  then M27Utilities.ErrorHandler('Dont recognise the current platoon action='..oPlatoon[refiCurrentAction])
                        else M27Utilities.ErrorHandler('Platoon action is nil')
                    end
                end

                if bDebugMessages == true then
                    local sPlatoonAction = oPlatoon[refiCurrentAction]
                    if sPlatoonAction == nil then sPlatoonAction = 'nil' end
                    LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': end of function - platoon curaction='..sPlatoonAction)
                end
            end
        else
            LOG(sFunctionRef..': PlatoonExists is no longer valid')
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end



function PlatoonInitialSetup(oPlatoon)
    --Updates platoon name and number of times its been called, then ensures segment pathing and mexes within the pathing group exist
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'PlatoonInitialSetup'
    --PROFILER NOTE - is included lower down due to waitticks
    local aiBrain = oPlatoon:GetBrain()
    local sPlatoonName = oPlatoon:GetPlan()
    --if sPlatoonName == 'M27ACUMain' then bDebugMessages = true end
    --if sPlatoonName == 'M27IndirectDefender' then bDebugMessages = true end
    --if sPlatoonName == 'M27EscortAI' then bDebugMessages = true end
    --if sPlatoonName == 'M27CombatPatrolAI' then bDebugMessages = true end
    --if sPlatoonName == 'M27RetreatingShieldUnits' then bDebugMessages = true end
    --if sPlatoonName == 'M27MobileShield' then bDebugMessages = true end

    oPlatoon[refbPlatoonLogicActive] = true

    local tCurrentUnits = oPlatoon:GetPlatoonUnits()
    local bIdlePlatoon = M27PlatoonTemplates.PlatoonTemplate[sPlatoonName][M27PlatoonTemplates.refbIdlePlatoon]
    local bAbort = false
    if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonName='..sPlatoonName..': Start of code') end
    if M27Utilities.IsTableEmpty(tCurrentUnits) == true and bIdlePlatoon == false then
        oPlatoon[refiCurrentAction] = refActionDisband
        if sPlatoonName == nil then sPlatoonName = 'NilName' end
        if bDebugMessages == true then LOG('WARNING - Platoon setup but no units in platoon so will disband in 1s if still the case. Platoon name='..sPlatoonName..(oPlatoon[refiPlatoonCount] or 'nil')) end
        WaitTicks(10)
        if bDebugMessages == true then LOG('Finished waiting 10 ticks for '..sPlatoonName..(oPlatoon[refiPlatoonCount] or 'nil')) end
        tCurrentUnits = oPlatoon:GetPlatoonUnits()
        if M27Utilities.IsTableEmpty(tCurrentUnits) == true then
            LOG('Platoon still has no units so will disband. Platoon name='..sPlatoonName..(oPlatoon[refiPlatoonCount] or 'nil'))
            bAbort = true
            oPlatoon[refbPlatoonLogicActive] = false
            oPlatoon:PlatoonDisband()
        else
            if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..(oPlatoon[refiPlatoonCount] or 'nil')..': Now have units after waiting 1s, so will proceed') end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if not(bAbort) then
        if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..': Platoon has units so proceeding with intialisation') end
        --General data for idle and non-idle platoons alike:

        --Record the platoon plan's default template values:
        if M27PlatoonTemplates.PlatoonTemplate then
            for sReference, val in M27PlatoonTemplates.PlatoonTemplate[sPlatoonName] do
                oPlatoon[sReference] = val
            end
            else M27Utilities.ErrorHandler('Dont have a platoon template for platoon with name='..sPlatoonName)
        end
        local sFormationOverride = oPlatoon[M27PlatoonTemplates.refsDefaultFormation]
        if sFormationOverride == nil then sFormationOverride = 'GrowthFormation' end --default
        oPlatoon:SetPlatoonFormationOverride(sFormationOverride)

        --Backup - not sure if it even works:
        if oPlatoon.PlatoonData.UseFormation == nil then oPlatoon.PlatoonData.UseFormation = oPlatoon[sFormationOverride] end
        --if oPlatoon[refbACUInPlatoon] == true then bDebugMessages = true end

        if aiBrain[refiLifetimePlatoonCount] == nil then aiBrain[refiLifetimePlatoonCount] = {} end
        if aiBrain[refiLifetimePlatoonCount][sPlatoonName] == nil then aiBrain[refiLifetimePlatoonCount][sPlatoonName] = 0 end
        aiBrain[refiLifetimePlatoonCount][sPlatoonName] = aiBrain[refiLifetimePlatoonCount][sPlatoonName] + 1
        oPlatoon[refiPlatoonCount] = aiBrain[refiLifetimePlatoonCount][sPlatoonName]
        local bPlatoonNameDisplay = false
        if M27Config.M27ShowUnitNames == true then bPlatoonNameDisplay = true end
        if bPlatoonNameDisplay == true then UpdatePlatoonName(oPlatoon, sPlatoonName..oPlatoon[refiPlatoonCount]..': A'..refActionReturnToBase) end
        if bDebugMessages == true then LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': Have a platoon with units, proceeding with rest of initialisation') end


        --Non-idle logic:
        if not(bIdlePlatoon) then
            oPlatoon[refoBrain] = aiBrain
            oPlatoon[refbMovingToBuild] = false
            local oPathingUnit = GetPathingUnit(oPlatoon)
            local tPlatoonUnits = oPlatoon:GetPlatoonUnits()

            --Make sure action that give in this platoon repalces any existing action the platoon has:
            local sPathingType
            if oPathingUnit == nil or not(tPlatoonUnits) or oPathingUnit.Dead or not(oPathingUnit.GetPosition) then
                M27Utilities.ErrorHandler('Possible error - no pathing unit in platoon; sPlatoonName='..sPlatoonName..oPlatoon[refiPlatoonCount]..'; will disband platoon')
                if M27Utilities.IsTableEmpty(tPlatoonUnits) == false then LOG('PlatoonInitialSetup: tPlatoonUnits is not empty') end
                if oPlatoon then oPlatoon[refiCurrentAction] = refActionDisband end --and aiBrain:PlatoonExists(oPlatoon) then oPlatoon:PlatoonDisband() end
            else
                IssueClearCommands(tPlatoonUnits)
                local tCurPos = oPathingUnit:GetPosition()
                local iCurSegmentX, iCurSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tCurPos)
                sPathingType = M27UnitInfo.GetUnitPathingType(oPathingUnit)
                local iSegmentGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathingType, iCurSegmentX, iCurSegmentZ)
                if iSegmentGroup == nil then LOG('ERROR: '..sPlatoonName..oPlatoon[refiPlatoonCount]..': No segments that the platoon can path to') end
                --M27MapInfo.RecordMexForPathingGroup(oPathingUnit)

                --Kiting logic (and ACU overcharge):
                oPlatoon[refbKiteEnemies] = false
                --Do we have an ACU in the platoon? If so set auto-overcharge to be on
                local oACU = M27Utilities.GetACU(aiBrain)
                local tACUs = EntityCategoryFilterDown(categories.COMMAND, tPlatoonUnits)
                if not(tACUs == nil) then --for some reason using the above would return non-nil value even when ACU not in platoon, so below is to make sure that there is an ACU in platoon
                    for iUnit, oUnit in tACUs do
                        if oUnit == oACU then
                            oPlatoon[refbACUInPlatoon] = true
                            oPlatoon[refbKiteEnemies] = true
                            M27EngineerOverseer.ClearEngineerActionTrackers(aiBrain, M27Utilities.GetACU(aiBrain), true)
                            break
                        end
                    end
                end
                if not(oPlatoon[refbACUInPlatoon]) then
                    oPlatoon[refbACUInPlatoon] = false
                    --GetDirectFireUnitMinOrMaxRange(tUnits, iReturnRangeType)
                    --    --Works if either sent a table of units or a single unit
                    --    --iReturnRangeType: nil or 0: Return min+Max; 1: Return min only; 2: Return max only
                    local iMaxDFRange = M27Logic.GetDirectFireUnitMinOrMaxRange(tPlatoonUnits, 2)
                    if iMaxDFRange and iMaxDFRange > 22 and oPlatoon[M27PlatoonTemplates.refbIgnoreStuckAction] == false then oPlatoon[refbKiteEnemies] = true end
                end


                --Does the platoon contain builders or reclaimers? If so then flag to consider nearby mexes and reclaim respectively
                --(although below also updates the tables of these, these will be refreshed every platoon cycle anyway)
                local tBuilders = EntityCategoryFilterDown(categories.CONSTRUCTION, tPlatoonUnits)
                local bCanBuildMex = false
                if bDebugMessages == true then
                    if tBuilders == nil then LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': tBuilder size=nil')
                        else LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': tBuilder size='..table.getn(tBuilders))
                    end
                end
                if M27Utilities.IsTableEmpty(tBuilders) == false then
                    local iBuilderFaction
                    local sFactionMexBPID
                    for iBuilder, oBuilder in tBuilders do
                        iBuilderFaction = M27UnitInfo.GetFactionFromBP(oBuilder:GetBlueprint())
                        sFactionMexBPID = M27UnitInfo.GetBlueprintIDFromBuildingTypeAndFaction('T1Resource', iBuilderFaction)
                        if oBuilder:CanBuild(sFactionMexBPID) then
                            bCanBuildMex = true
                            break
                        end
                    end
                end
                --Pathing range override for ACU and builders
                if oPlatoon[refbACUInPlatoon] == true then
                    oPlatoon[refiOverrideDistanceToReachDestination] = 3 --ACU treated as reaching destination when it gets this close to it
                elseif M27Utilities.IsTableEmpty(tBuilders) == false then
                    oPlatoon[refiOverrideDistanceToReachDestination] = 3
                end
                oPlatoon[refbConsiderMexes] = bCanBuildMex
                if bCanBuildMex == true then
                    oPlatoon[reftBuilders] = tBuilders
                end

                local tReclaimers = EntityCategoryFilterDown(categories.RECLAIM, tPlatoonUnits)
                local bHaveReclaimers = false
                bHaveReclaimers = M27Utilities.IsTableEmpty(tReclaimers)
                if bDebugMessages == true then LOG(sFunctionRef..': bHaveReclaimers='..tostring(bHaveReclaimers)) end
                oPlatoon[refbConsiderReclaim] = not(bHaveReclaimers)
                if bHaveReclaimers == true then
                    oPlatoon[reftReclaimers] = tReclaimers
                end
                if bDebugMessages == true then
                    LOG('oPlatoon[refbConsiderReclaim]='..tostring(oPlatoon[refbConsiderReclaim])..' oPlatoon[refbConsiderMexes]='..tostring(oPlatoon[refbConsiderMexes]))
                    if tBuilders == nil then LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': tBuilder size=nil')
                    else LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': tBuilder size='..table.getn(tBuilders))
                    end
                    if tReclaimers == nil then LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': tReclaimers size=nil')
                    else LOG(sFunctionRef..': '..sPlatoonName..oPlatoon[refiPlatoonCount]..': tReclaimers size='..table.getn(tReclaimers))
                    end
                end

                --Does the platoon contain underwater land units?
                oPlatoon[refbPlatoonHasUnderwaterLand] = false
                oPlatoon[refbPlatoonHasOverwaterLand] = false
                if sPathingType == M27UnitInfo.refPathingTypeAmphibious then
                    for iUnit, oUnit in tPlatoonUnits do
                        if M27UnitInfo.IsUnitUnderwaterAmphibious(oUnit) == true then
                            oPlatoon[refbPlatoonHasUnderwaterLand] = true
                            break
                        else
                            oPlatoon[refbPlatoonHasOverwaterLand] = true
                            break
                        end
                    end
                end

                if oPlatoon and oPlatoon.SetPlatoonFormationOverride and aiBrain:PlatoonExists(oPlatoon) then oPlatoon:SetPlatoonFormationOverride('AttackFormation') end--default is to stick together

                --Follower support platoon logic:
                if sPlatoonName == 'M27EscortAI' then
                    oPlatoon[refiSupportHelperFollowDistance] = -15
                elseif sPlatoonName == 'M27MobileShield' then oPlatoon[refiSupportHelperFollowDistance] = 1.5
                else
                    local iOurMinSpeed = M27Logic.GetUnitMinSpeed(oPlatoon:GetPlatoonUnits(), aiBrain, false)
                    if iOurMinSpeed <= 3.5 then oPlatoon[refiSupportHelperFollowDistance] = 18 --i.e. MAA
                    else oPlatoon[refiSupportHelperFollowDistance] = 5 end
                end
            end
        end
    end
    oPlatoon[refiLastPrevActionOverride] = 0
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RunPlatoonSingleCycle(oPlatoon)
    local sFunctionRef = 'RunPlatoonSingleCycle'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    DeterminePlatoonAction(oPlatoon)
    ProcessPlatoonAction(oPlatoon)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function PlatoonCycler(oPlatoon)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'PlatoonCycler'
    local aiBrain = oPlatoon:GetBrain()
    local sOrigPlatoonName = oPlatoon:GetPlan()
    if sOrigPlatoonName == 'M27MobileShield' then bDebugMessages = false end

    if bDebugMessages == true then LOG(sFunctionRef..': About to start main loop for platoon '..sOrigPlatoonName..(oPlatoon[refiPlatoonCount] or 'nil')) end
    if aiBrain:PlatoonExists(oPlatoon) then
        --Check we're not duplicating a backup loop
        if not(oPlatoon[refbPlatoonLogicActive]) then
            PlatoonInitialSetup(oPlatoon)
            while aiBrain:PlatoonExists(oPlatoon) do
                ForkThread(RunPlatoonSingleCycle, oPlatoon)
                WaitSeconds(1)
                if oPlatoon and oPlatoon.GetPlan and aiBrain then
                    if not(oPlatoon:GetPlan() == sOrigPlatoonName) then break end
                else break end
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': '..sOrigPlatoonName..(oPlatoon[refiPlatoonCount] or 'nil')..': Platoon already has an active cycler so wont duplicate') end
        end
    else
        oPlatoon[refbPlatoonLogicActive] = false
        if bDebugMessages == true then LOG(sFunctionRef..': '..sOrigPlatoonName..(oPlatoon[refiPlatoonCount] or 'nil')..' has ceased to exist so stopping platoon loop') end
    end
end
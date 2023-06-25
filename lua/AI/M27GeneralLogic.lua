tPlatoonRaiderTargets = {} --[a][b]: a = aiBrain Army Index; b = string reference to the location, e.g. x=12.5 z=15 would be 'x12.5;z15'; returns the number of times a raider platoon has been ordered to go there
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27Chat = import('/mods/M27AI/lua/AI/M27Chat.lua')
local M27EconomyOverseer = import('/mods/M27AI/lua/AI/M27EconomyOverseer.lua')
local M27Transport = import('/mods/M27AI/lua/AI/M27Transport.lua')
local M27Team = import('/mods/M27AI/lua/AI/M27Team.lua')

--Threat values
tUnitThreatByIDAndType = {} --Calculated at the start of the game
reftBaseThreat = 'M27BaseThreatTable' --Against unit, stores the base threat value for different combinations
tiThreatRefsCalculated = {} --table of the threat ID references that have done blueprint checks on
tbExpectMissileBlockedByCliff = 'M27TMLExpectedBlocked' --table with [x] as the TML location ref, which returns true, false or nil based on if we have considered if a TML shot is likely to be blocked

--Other:
refbNearestEnemyBugDisplayed = 'M27NearestEnemyBug' --true if have already given error messages for no nearest enemy
refiNearestEnemyIndex = 'M27NearestEnemyIndex'
refiNearestEnemyStartPoint = 'M27NearestEnemyStartPoint'
tPlayerStartPointByIndex = {}
iTimeOfLastBrainAllDefeated = 0 --Used to avoid massive error spamming if all brains defeated
refbAllEnemiesDead = 'M27AllEnemiesDead' --true if flagged all brains are dead
refiT3ArtiShotCount = 'M27T3ArtiShotCount' --Against a unit, the number of t3 arti shots fired near here recently
refiT3ArtiLifetimeShotCount = 'M27T3ArtiLifetimeShotCount' --Against a unit, nubmer of t3 arti shots fired near it in its lifetime, with this value not being reset
refbScheduledArtiShotReset = 'M27T3ArtiTriggeredShotReset' --true if have a delayed order to reset the arti shot count on the unit
iT3ArtiShotThreshold = 18 --Number of shots to be fired by t3 arti before we give up and try a different target
iT3ArtiShotLifetimeThreshold = 40 --Number of shots before will significantly reduce the value of the target (starting with a 40% reduction, and going down to a 10% reduction at 4 times this)

refiEnemyScoutSpeed = 'M27LogicEnemyScoutSpeed' --expected speed of the nearest enemy's land scouts

refiIdleCount = 'M27UnitIdleCount' --Used to track how long a unit has been idle with the isunitidle check

function GetUnitState(oUnit)
    --Returns a string containing oUnit's unit state. Returns '' if no unit state.
    local sUnitState = ''
    local sAllUnitStates = {'Immobile',
    'Moving',
    'Attacking',
    'Guarding',
    'Building',
    'Upgrading',
    'WaitingForTransport',
    'TransportLoading',
    'TransportUnloading',
    'MovingDown',
    'MovingUp',
    'Patrolling',
    'Busy',
    'Attached',
    'BeingReclaimed',
    'Repairing',
    'Diving',
    'Surfacing',
    'Teleporting',
    'Ferrying',
    'WaitForFerry',
    'AssistMoving',
    'PathFinding',
    'ProblemGettingToGoal',
    'NeedToTerminateTask',
    'Capturing',
    'BeingCaptured',
    'Reclaiming',
    'AssistingCommander',
    'Refueling',
    'GuardBusy',
    'ForceSpeedThrough',
    'UnSelectable',
    'DoNotTarget',
    'LandingOnPlatform',
    'CannotFindPlaceToLand',
    'BeingUpgraded',
    'Enhancing',
    'BeingBuilt',
    'NoReclaim',
    'NoCost',
    'BlockCommandQueue',
    'MakingAttackRun',
    'HoldingPattern',
    'SiloBuildingAmmo' }
    for _, sState in sAllUnitStates do
        if oUnit:IsUnitState(sState) == true then
            sUnitState = sState
            break
        end
    end
    return sUnitState
end

function ReturnUnitsInTargetSegmentGroup(tUnits, iTargetGroup)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReturnUnitsInTargetSegmentGroup'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tCurPosition = {}
    local iCurSegmentX, iCurSegmentZ
    local tMatchingUnits = {}
    local iMatchingUnitCount = 0
    local sPathing
    if bDebugMessages == true then LOG(sFunctionRef..': tUnits size='..table.getn(tUnits)..'; iTargetGroup='..iTargetGroup) end
    local iUnitPathGroup
    if M27Utilities.IsTableEmpty(tUnits) == false then
        for iCurUnit, oUnit in tUnits do
            if not(oUnit.Dead) then
                tCurPosition = oUnit:GetPosition()
                iCurSegmentX, iCurSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tCurPosition)
                sPathing = M27UnitInfo.GetUnitPathingType(oUnit)
                if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
                iUnitPathGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iCurSegmentX, iCurSegmentZ)
                if iTargetGroup == iUnitPathGroup then
                    iMatchingUnitCount = iMatchingUnitCount + 1
                    tMatchingUnits[iMatchingUnitCount] = {}
                    tMatchingUnits[iMatchingUnitCount] = oUnit
                end
                if bDebugMessages == true then LOG(sFunctionRef..': iCurUnit='..iCurUnit..'; iTargetGroup='..iTargetGroup..'; Unit grouping='..iUnitPathGroup) end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': iCurUnit='..iCurUnit..'; Unit is dead') end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tMatchingUnits
end

function GetNearestSegmentWithEnergyReclaim(tStartPosition, iMinEnergyReclaim, iIgnoreAssignedSegmentRange, aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReturnUnitsInTargetSegmentGroup'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iSegmentSearchRange = math.ceil(50 / M27MapInfo.iReclaimSegmentSizeX)
    local iBaseReclaimSegmentX, iBaseReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tStartPosition)

    local iCurLevel = -1
    local iCurSublevel = 0
    local tiAdjustFactor = {{1,0}, {1,1},{0,1},{-1,1},{-1,0},{-1,-1},{0,-1}, {1,-1}}

    local iReclaimSegmentX
    local iReclaimSegmentZ
    local bFoundEnergyReclaim = false
    local tAlreadyAsisgnedSegmentXZ
    local bAlreadyAssigned
    local sLocationRef

    --Find nearest segment to engineer containing energy reclaim
    while iCurLevel < math.min(iSegmentSearchRange, 10000) do
        bAlreadyAssigned = false
        iCurLevel = iCurLevel + 1
        iCurSublevel = iCurSublevel + 1
        if iCurSublevel > 4 then iCurSublevel = 1 end
        for iCurFactor, tCurFactor in tiAdjustFactor do
            iReclaimSegmentX = iBaseReclaimSegmentX + iCurLevel * tCurFactor[1]

            if M27MapInfo.tReclaimAreas[iReclaimSegmentX] then
                iReclaimSegmentZ = iBaseReclaimSegmentZ + iCurLevel * tCurFactor[2]
                if M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ] then
                    if bDebugMessages == true then LOG(sFunctionRef..': Checking for energy reclaim in segment '..iReclaimSegmentX..'-'..iReclaimSegmentZ..'; Dist to the base segment='..M27Utilities.GetDistanceBetweenPositions(tStartPosition, M27MapInfo.GetReclaimLocationFromSegment(iReclaimSegmentX, iReclaimSegmentZ))) end
                    if M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][M27MapInfo.refReclaimTotalEnergy] >= iMinEnergyReclaim then
                        --Is this already assigned?
                        if iIgnoreAssignedSegmentRange then
                            for iAdjustX = -iIgnoreAssignedSegmentRange, iIgnoreAssignedSegmentRange do
                                for iAdjustZ = -iIgnoreAssignedSegmentRange, iIgnoreAssignedSegmentRange do
                                    sLocationRef = M27Utilities.ConvertLocationToStringRef(M27MapInfo.GetReclaimLocationFromSegment(iReclaimSegmentX + iAdjustX, iReclaimSegmentZ + iAdjustZ))
                                    if bDebugMessages == true then LOG(sFunctionRef..': Found segment '..iReclaimSegmentX..'-'..iReclaimSegmentZ..'; seeing if nearby segment is assigned. iAdjustX='..iAdjustX..'; iAdjustZ='..iAdjustZ..'; sLocationRef='..sLocationRef..'; Is table of actions empty for this location='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef]))) end
                                    if aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] and (aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea] or aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimTrees]) then
                                        bAlreadyAssigned = true
                                        break
                                    end
                                end
                            end
                        end
                        if not(bAlreadyAssigned) then
                            bFoundEnergyReclaim = true
                            if bDebugMessages == true then LOG(sFunctionRef..': Found sufficient reclaim') end
                            break
                        else
                            if not(tAlreadyAsisgnedSegmentXZ) then tAlreadyAsisgnedSegmentXZ = {iReclaimSegmentX, iReclaimSegmentZ} end
                        end
                    end
                end

            end
            if iCurLevel == 0 then break end
        end
    end
    --If couldnt find anywhere for energy reclaim then pick the location already assigned
    if not(bFoundEnergyReclaim) and tAlreadyAsisgnedSegmentXZ then
        bFoundEnergyReclaim = true
        iReclaimSegmentX = tAlreadyAsisgnedSegmentXZ[1]
        iReclaimSegmentZ = tAlreadyAsisgnedSegmentXZ[2]
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if bFoundEnergyReclaim then return iReclaimSegmentX, iReclaimSegmentZ
    else return nil, nil
    end
end

function ChooseReclaimTarget(oEngineer, bWantEnergy)
    --Returns a table containing the target position to attack move to based on reclaimsegments
    --If are no reclaim positions then returns the current segment
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ChooseReclaimTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..':Started ChooseReclaimTarget') end
    --Update reclaim if havent recently
    local aiBrain = oEngineer:GetAIBrain()
    --ForkThread(M27MapInfo.UpdateReclaimAreasOfInterest, aiBrain)


    local sLocationRef, tCurMidpoint
    local iClosestDistanceToEngi = 10000
    local iCurDistanceToEngi
    local tClosestLocationToEngi
    local tEngiPosition = oEngineer:GetPosition()

    if bWantEnergy then
        --See if can find unassigned segment for energy reclaim
        local iEnergySegmentX, iEnergySegmentZ = GetNearestSegmentWithEnergyReclaim(tEngiPosition, 20, 0, aiBrain)


        if not(iEnergySegmentX) then
            --Get energy segment and ignore if already assigned
            iEnergySegmentX, iEnergySegmentZ = GetNearestSegmentWithEnergyReclaim(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 20)
            if bDebugMessages == true then LOG(sFunctionRef..': Energy segment X and Z after checking near base='..(iEnergySegmentX or 'nil')..'-'..(iEnergySegmentZ or 'nil')) end
            if not(iEnergySegmentX) then
                M27Utilities.ErrorHandler(sFunctionRef..': Couldnt find any segments containing energy near to engineer or start so will just return engineer current segment')
                iEnergySegmentX, iEnergySegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tEngiPosition)
            end
        elseif bDebugMessages == true then LOG(sFunctionRef..': Energy segment X and Z after checking near engi='..(iEnergySegmentX or 'nil')..'-'..(iEnergySegmentZ or 'nil')..'; Dist between here and engi='..M27Utilities.GetDistanceBetweenPositions(tEngiPosition, M27MapInfo.GetReclaimLocationFromSegment(iEnergySegmentX, iEnergySegmentZ)))
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return M27MapInfo.GetReclaimLocationFromSegment(iEnergySegmentX, iEnergySegmentZ)

        --[[
        if bDebugMessages == true then LOG(sFunctionRef..': Want to find energy; engineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' action='..(oEngineer[M27EngineerOverseer.refiEngineerCurrentAction] or 'nil')) end
        --Want the nearest location that has a decent amount of power - manually calculate as fairly rare that want this info
        local rCurRect
        local tNearbyReclaim
        local iCurReclaimDist
        local iNearestReclaim = 10000
        local bCoveredByEngi
        local tEngineerActions = {M27EngineerOverseer.refActionReclaimArea, M27EngineerOverseer.refActionReclaimTrees}
        for iSearchRadius = 10, 100, 10 do
            rCurRect = Rect(tEngiPosition[1] - iSearchRadius, tEngiPosition[3] - iSearchRadius, tEngiPosition[3] + iSearchRadius, tEngiPosition[3] + iSearchRadius)
            if M27MapInfo.GetReclaimInRectangle(5, rCurRect) > 100 then --At least 100 energy income nearby
                tNearbyReclaim = M27MapInfo.GetReclaimInRectangle(4, rCurRect)
                for iReclaim, oReclaim in tNearbyReclaim do
                    if oReclaim.MaxEnergyReclaim > 5 then
                        iCurReclaimDist = M27Utilities.GetDistanceBetweenPositions(oReclaim.CachePosition, tEngiPosition)
                        if iCurReclaimDist < iNearestReclaim then
                            --Is this location within 10 of existing engineer reclaim targets?
                            bCoveredByEngi = false
                            for _, iActionRef in tEngineerActions do
                                if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][iActionRef]) == false then
                                    for iSubtable, tSubtable in aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][iActionRef] do
                                        if M27Utilities.GetDistanceBetweenPositions(tSubtable[M27EngineerOverseer.refEngineerAssignmentActualLocation], oReclaim.CachePosition) <= 10 then
                                            bCoveredByEngi = true
                                            break
                                        end
                                    end
                                end
                                if bCoveredByEngi then break end
                            end
                            if not(bCoveredByEngi) then
                                iNearestReclaim = iCurReclaimDist
                                tClosestLocationToEngi = oReclaim.CachePosition
                            end
                        end
                    end
                end
                if M27Utilities.IsTableEmpty(tClosestLocationToEngi) == true then
                    M27Utilities.ErrorHandler('Couldnt find any energy reclaim, only scenario where expected is if lots of very tiny energy reclaim or have lots of engis already reclaiming; will just pick a random location', true)
                    tClosestLocationToEngi = {tEngiPosition[1] + math.random(iSearchRadius - 10, iSearchRadius), nil, tEngiPosition[3] + math.random(iSearchRadius - 10, iSearchRadius)}
                    tClosestLocationToEngi[2] = GetSurfaceHeight(tClosestLocationToEngi[1], tClosestLocationToEngi[3])
                    aiBrain[M27EngineerOverseer.refiTimeOfLastFailure][M27EngineerOverseer.refActionReclaimTrees] = GetGameTimeSeconds()
                end
                break
            end
        end--]]
    else --Can refer to the shortlist of reclaim areas
        for iCurPriority = 1, 3 do --priority 4 is for ACU only
            if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftReclaimAreasOfInterest][iCurPriority]) == false then
                --Check have areas where an engineer hasn't been assigned
                for iCount, tSegmentXAndZ in aiBrain[M27MapInfo.reftReclaimAreasOfInterest][iCurPriority] do
                    tCurMidpoint = M27MapInfo.tReclaimAreas[tSegmentXAndZ[1]][tSegmentXAndZ[2]][M27MapInfo.refReclaimSegmentMidpoint]
                    sLocationRef = M27Utilities.ConvertLocationToReference(tCurMidpoint)
                    if not(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef]) or not(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea]) or not(M27UnitInfo.IsUnitValid(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea])) then
                        iCurDistanceToEngi = M27Utilities.GetDistanceBetweenPositions(tEngiPosition, tCurMidpoint)
                        if iCurDistanceToEngi < iClosestDistanceToEngi and iCurDistanceToEngi > M27MapInfo.iReclaimSegmentSizeX then --Need to be a certain distance away or else risk the same location being given to the engineer repeatedly
                            iClosestDistanceToEngi = iCurDistanceToEngi
                            tClosestLocationToEngi = tCurMidpoint
                        end
                    end
                end
            end
            --Ignore lower priority locations if have a valid location
            if M27Utilities.IsTableEmpty(tClosestLocationToEngi) == false then break end
        end
    end
    if M27Utilities.IsTableEmpty(tClosestLocationToEngi) == true then
        if bDebugMessages == true then LOG(sFunctionRef..': Couldnt find a valid reclaim target for engineer but presumably gave it an action to reclaim, will return nil') end
    elseif bDebugMessages == true then
        local iBaseX, iBaseZ = M27MapInfo.GetReclaimSegmentsFromLocation(tClosestLocationToEngi)
        LOG(sFunctionRef..': Foudn a location, ='..repru(tClosestLocationToEngi)..'; will draw a black rectangle around the reclaim segment.  Mass in segment='..M27MapInfo.tReclaimAreas[iBaseX][iBaseZ][M27MapInfo.refReclaimTotalMass])
        local rRect = Rect((iBaseX - 1) * M27MapInfo.iReclaimSegmentSizeX, (iBaseZ - 1) * M27MapInfo.iReclaimSegmentSizeZ, iBaseX * M27MapInfo.iReclaimSegmentSizeX, iBaseZ * M27MapInfo.iReclaimSegmentSizeZ)
        M27Utilities.DrawRectangle(rRect, 3, 10)

        --[[tReclaimAreas = {} --Stores reclaim info for each segment: tReclaimAreas[iSegmentX][iSegmentZ][x]; if x=1 returns total mass in area; if x=2 then returns position of largest reclaim in the area, if x=3 returns how many platoons have been sent here since the game started
        --refReclaimTotalMass = 1
        --refReclaimSegmentMidpoint = 2
        --refReclaimHighestIndividualReclaim = 3
        --reftReclaimTimeOfLastEngineerDeathByArmyIndex = 4 --Table: [a] where a is the army index, and it returns the time the last engineer died
        --refReclaimTimeLastEnemySightedByArmyIndex = 5
        --refsSegmentMidpointLocationRef = 6 ==]]
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tClosestLocationToEngi

    --OLD METHOD Below
    --[[

    local tEngPosition = oEngineer:GetPosition()
    local iEngSegmentX, iEngSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tEngPosition)
    if bDebugMessages == true then LOG(sFunctionRef..': iEngSegmentXZ='..iEngSegmentX..'-'..iEngSegmentZ) end
    local sPathing = M27UnitInfo.GetUnitPathingType(oEngineer)
    local iEngSegmentGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iEngSegmentX, iEngSegmentZ)

    if not(iEngSegmentGroup) then
        M27Utilities.ErrorHandler('iEngSegmentGroup is nil')
    else
        local iCurSegmentX, iCurSegmentZ, iSegmentMass
        --Go through tReclaimAreas to determine optimal choice:
        -- M27MapInfo.tReclaimAreas = {} --Stores key reclaim area locations; tReclaimAreas[iSegmentX][iSegmentZ][x]; if x=1 returns total mass in area; if x=2 then returns position of largest reclaim in the area, if x=3 returns how many platoons have been sent here since the game started
        if bDebugMessages == true then LOG(sFunctionRef..': iEngSegmentGroup='..iEngSegmentGroup..'; sPathing='..sPathing) end
        if M27MapInfo.tSegmentBySegmentGroup[sPathing][iEngSegmentGroup] == nil then
            M27Utilities.ErrorHandler('No segments that can path to; returning eng current position iEngSegmentGroup='..iEngSegmentGroup..'; Engineer will attack move to its own segment')
            return tEngPosition
        else
            local iHighestReclaim = 0
            local iLongestDistance = 0
            local iCurDistance = 0
            local iCurOtherPlayerDistance = 0
            local iAbsClosestOtherPlayerDistance = 0
            --local tReclaimOptions = {} --[x][y]: x is the option no.; y: 1 = reclaim amount; 2 = position; 3 = no. of engineers assigned; 4 = distance from engi, 5 = distance from enemy, 6 = priority
            local iEnemyX, iEnemyZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()

            --Get the highest of certain varaibles (so can then prioritise):
            if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through reclaimgroupsegments') end
            --Map every segment that contains reclaim (if haven't already):
            --local iMapSizeX, iMapSizeZ = GetMapSize()
            --local iSegmentSizeX = 1
            --local iSegmentSizeZ = 1
            for iCurSegmentX = 1, M27MapInfo.iMaxSegmentInterval do
                for iCurSegmentZ = 1, M27MapInfo.iMaxSegmentInterval do
            --for iCurSegmentX = 1, math.ceil(iMapSizeX / M27MapInfo.iSegmentSizeX) do
                --for iCurSegmentZ = 1, math.ceil(iMapSizeZ / M27MapInfo.iSegmentSizeZ) do


            --for iCurReclaimGroupSegment, v in M27MapInfo.tSegmentBySegmentGroup[sPathing][iEngSegmentGroup] do
                --if not (v[1] == nil) then
                    --iCurSegmentX = v[1]
                    --iCurSegmentZ = v[2]
                    iSegmentMass = M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][1]

                    if iSegmentMass > 0 then
                        --Can we path to this segment?
                        --function InSameSegmentGroup(oUnit, tDestination, bReturnUnitGroupOnly)
                        --GetSegmentGroupOfTarget(sPathing, iTargetSegmentX, iTargetSegmentZ)
                        if M27MapInfo.GetSegmentGroupOfTarget(sPathing, iCurSegmentX, iCurSegmentZ) == iEngSegmentGroup then
                            if bDebugMessages == true then LOG(sFunctionRef..': iEngSegmentGroup='..iEngSegmentGroup..'; iCurReclaimGroupSegment='..'iCurSegmentX-Z='..iCurSegmentX..'-'..iCurSegmentZ..'; iSegmentMass='..iSegmentMass) end
                            iCurDistance = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][2], tEngPosition)
                            if iSegmentMass > iHighestReclaim then iHighestReclaim = iSegmentMass end
                            iCurOtherPlayerDistance = VDist2(M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][2][1], M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][2][3], iEnemyX, iEnemyZ)
                            if iAbsClosestOtherPlayerDistance < math.abs(iCurOtherPlayerDistance - iCurDistance) then iAbsClosestOtherPlayerDistance = iCurOtherPlayerDistance - iCurDistance end
                            if iCurDistance > iLongestDistance then iLongestDistance = iCurDistance end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..' Cant path to iCurSegmentXZ='..iCurSegmentX..'-'..iCurSegmentZ) end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': iSegmentMass isnt >0; iCurReclaimGroupSegment='..'; iEngSegmentGroup='..iEngSegmentGroup..'iCurSegmentX-Z='..iCurSegmentX..'-'..iCurSegmentZ) end
                    end
                end
            end
            --Repeat the loop but this time determine priority:
            if bDebugMessages == true then LOG(sFunctionRef..':Re-doing loop through segments to determine priority; iLongestDistance='..iLongestDistance..'; iAbsClosestOtherPlayerDistance='..iAbsClosestOtherPlayerDistance..'; iHighestReclaim='..iHighestReclaim) end
            local iCurPriority = 0
            local iMaxPriority = 0
            local iBestMatchSegment = 0
            local sLocationRef, iAlreadyAssignedEngis

            --Since have mapped every location with reclaim the below should now include any such locations:
            for iCurReclaimGroupSegment, v in M27MapInfo.tSegmentBySegmentGroup[sPathing][iEngSegmentGroup] do
                if not (v[1] == nil) then
                    iCurSegmentX = v[1]
                    iCurSegmentZ = v[2]
                    iSegmentMass = M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][1]
                    if iSegmentMass > 0 then
                        iCurDistance = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][2], tEngPosition)
                        iCurOtherPlayerDistance = math.abs(VDist2(M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][2][1], M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][2][3], iEnemyX, iEnemyZ) - iCurDistance)
                        iCurPriority = math.random(1,3) --introduce a slight element of unpredictibility
                        iCurPriority = iCurPriority + 5 * iSegmentMass / iHighestReclaim
                        if M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][3] == nil then M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][3] = 0 end
                        iCurPriority = iCurPriority - M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][3] --No. of engineers already assigned
                        iCurPriority = iCurPriority + 3 - 3 * iCurDistance / iLongestDistance
                        iCurPriority = iCurPriority - 3 * iCurOtherPlayerDistance / iAbsClosestOtherPlayerDistance -- Reduces priority if closer to enemy than to us; increases priority if closer to us than enemy
                        sLocationRef = M27Utilities.ConvertLocationToReference(M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][2])
                        iAlreadyAssignedEngis = 0
                        if aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation] and aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea]) == false then
                            iAlreadyAssignedEngis = table.getn(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaimArea])
                        end
                        iCurPriority = iCurPriority - 2 * iAlreadyAssignedEngis


                        if iCurPriority > iMaxPriority then
                            iMaxPriority = iCurPriority
                            iBestMatchSegment = iCurReclaimGroupSegment
                        end

                    end
                end
            end
            if iBestMatchSegment == 0 then
                --No notable mass left in any segment
                return tEngPosition
            else
                if bDebugMessages == true then LOG(sFunctionRef..': About to get iCurSegmentX and Z; sPathing='..sPathing..'iEngSegmentGroup='..iEngSegmentGroup..'; iBestMatchSegment='..iBestMatchSegment) end
                iCurSegmentX = M27MapInfo.tSegmentBySegmentGroup[sPathing][iEngSegmentGroup][iBestMatchSegment][1]
                iCurSegmentZ = M27MapInfo.tSegmentBySegmentGroup[sPathing][iEngSegmentGroup][iBestMatchSegment][2]
                if bDebugMessages == true then LOG(sFunctionRef..': Returning best match, iMaxPriority = '..iMaxPriority..'; iBestMatchSegment='..iBestMatchSegment..';iCurSegmentX-Z='..iCurSegmentX..'-'..iCurSegmentZ) end
                --Update engineer count and return target position:
                if M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ] == nil then
                    if M27MapInfo.tReclaimAreas[iCurSegmentX] == nil then M27MapInfo.tReclaimAreas[iCurSegmentX] = {} end
                    M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ] = {}
                    M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][3] = 1
                else M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][3] = M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][3] + 1 end

                return M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][2]
            end
        end
    end --]]

end

function IsCivilianBrain(aiBrain)
    --Is this an AI brain?
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsCivilianBrain'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local bIsCivilian = false
    if bDebugMessages == true then
        LOG(sFunctionRef..': Brain index='..aiBrain:GetArmyIndex()..'; BrainType='..(aiBrain.BrainType or 'nil')..'; Personality='..ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality)
        M27Utilities.DebugArray(aiBrain)
    end
    --Basic check that it appears to have the values we'd expect
    --if aiBrain.BrainType and aiBrain.Name then
        if aiBrain.BrainType == nil or aiBrain.BrainType == "AI" or string.find(aiBrain.BrainType, "AI") then
            if bDebugMessages == true then LOG('Dealing with an AI brain') end
            --Does it have no personality?
            if not(ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality) or ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality == "" then
                if bDebugMessages == true then LOG(sFunctionRef..': Index='..aiBrain:GetArmyIndex()..'; Has no AI personality so will treat as being a civilian brain unless nickname contains AI or AIX and doesnt contain civilian.  Will do repr of this'..repru(repru(aiBrain))) end
                bIsCivilian = true
                if string.find(aiBrain.Nickname, '%(AI') and not(string.find(aiBrain.Nickname, "civilian")) then
                    if bDebugMessages == true then LOG(sFunctionRef..': AI nickanme suggests its an actual AI and the developer has forgotten to give it a personality') end
                    bIsCivilian = false
                end

            end
        end
    --end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bIsCivilian
end

function CheckIfAllEnemiesDead(aiBrain)
    --Returns true if aiBrain has no enemies and did at start of game.  Also updates variables rleating to this
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CheckIfAllEnemiesDead'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code. aiBrain[M27Overseer.refbNoEnemies]='..tostring(aiBrain[M27Overseer.refbNoEnemies] or false)..'; aiBrain[refbAllEnemiesDead]='..tostring(aiBrain[refbAllEnemiesDead] or false)) end
    if aiBrain[refbAllEnemiesDead] then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return true
    else
        if not(aiBrain[M27Overseer.refbNoEnemies]) then
            local bHaveAnyEnemies = false
            for iBrain, oBrain in ArmyBrains do
                if IsEnemy(oBrain:GetArmyIndex(), aiBrain:GetArmyIndex()) then
                    if not(oBrain.M27IsDefeated) and not(oBrain:IsDefeated()) and not(IsCivilianBrain(oBrain)) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy '..oBrain.Nickname..' isnt flagged as defeated') end
                        bHaveAnyEnemies = true
                        break
                    end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Finished checking every brain in ArmyBrains. bHaveAnyEnemies='..tostring(bHaveAnyEnemies)) end
            if not(bHaveAnyEnemies) then
                aiBrain[refbAllEnemiesDead] = true
                iTimeOfLastBrainAllDefeated = GetGameTimeSeconds()
                if bDebugMessages == true then LOG(sFunctionRef..': Returning true') end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return true
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Returning false') end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return false
    end
end

function GetNearestEnemyIndex(aiBrain, bForceDebug)
    --Returns the ai brain index of the enemy who's got the nearest start location to aiBrain's start location and is still alive
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if bForceDebug == true then bDebugMessages = true end --for error control
    local sFunctionRef = 'GetNearestEnemyIndex'
    --if GetGameTimeSeconds() >= 1343 then bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if aiBrain[refiNearestEnemyIndex] and M27Overseer.tAllAIBrainsByArmyIndex[aiBrain[refiNearestEnemyIndex]] and not(M27Overseer.tAllAIBrainsByArmyIndex[aiBrain[refiNearestEnemyIndex]]:IsDefeated()) and not(aiBrain.M27IsDefeated) and not(M27Overseer.tAllAIBrainsByArmyIndex[aiBrain[refiNearestEnemyIndex]].M27IsDefeated) then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return aiBrain[refiNearestEnemyIndex]
    else
        if not (aiBrain.M27IsDefeated) and not (aiBrain:IsDefeated()) then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Considering brain index=' .. aiBrain:GetArmyIndex() .. '; aiBrain[M27Overseer.refbNoEnemies]=' .. tostring((aiBrain[M27Overseer.refbNoEnemies] or false)))
            end
            local iNearestEnemyIndex
            local iPlayerArmyIndex = aiBrain:GetArmyIndex()
            if aiBrain[M27Overseer.refbNoEnemies] then
                local iCivilianBrain
                for iCurBrain, oBrain in ArmyBrains do
                    if IsEnemy(oBrain:GetArmyIndex(), aiBrain:GetArmyIndex()) then
                        iNearestEnemyIndex = iCurBrain
                        break
                    elseif IsCivilianBrain(oBrain) then
                        iCivilianBrain = iCurBrain
                    end
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iNearestEnemyIndex=' .. (iNearestEnemyIndex or 0) .. '; iCivilianBrain=' .. (iCivilianBrain or 'nil'))
                end
                if not (iNearestEnemyIndex) then
                    iNearestEnemyIndex = iCivilianBrain
                end
            else
                local iDistToCurEnemy
                local iMinDistToEnemy = 10000000

                local iEnemyStartPos
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Start before looping through brains; aiBrain personality=' .. ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality .. '; brain.Name=' .. aiBrain.Name .. '; aiBrain[refiNearestEnemyIndex]=' .. (aiBrain[refiNearestEnemyIndex] or 'nil'))
                    if M27Utilities.IsTableEmpty(M27Overseer.tAllAIBrainsByArmyIndex) == false then
                        LOG('M27Overseer.tAllAIBrainsByArmyIndex has a value; [aiBrain[refiNearestEnemyIndex]].M27IsDefeated=' .. tostring((M27Overseer.tAllAIBrainsByArmyIndex[aiBrain[refiNearestEnemyIndex]].M27IsDefeated or false)))
                    end
                end
                --local tBrainsToSearch = ArmyBrains
                --if M27Utilities.IsTableEmpty(ArmyBrains) == true then tBrainsToSearch = M27Overseer.tAllAIBrainsByArmyIndex end

                for iCurBrain, brain in ArmyBrains do
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Start of brain loop, iCurBrain=' .. iCurBrain .. '; brain personality=' .. ScenarioInfo.ArmySetup[brain.Name].AIPersonality .. '; brain.Name=' .. brain.Name .. '; Brain index=' .. brain:GetArmyIndex() .. '; if brain isnt equal to our AI brain then will get its start position etc. IsCivilian='..tostring(IsCivilianBrain(brain))..'; IsEnemy='..tostring(IsEnemy(brain:GetArmyIndex(), aiBrain:GetArmyIndex()))..'; aiBrain[M27Overseer.refbNoEnemies]='..tostring((aiBrain[M27Overseer.refbNoEnemies] or false)))
                    --M27Utilities.DebugArray(brain) --Enable this if want more details of the brain we're dealing with
                    end
                    if not (brain == aiBrain) and (not (IsCivilianBrain(brain)) or (aiBrain[M27Overseer.refbNoEnemies] and IsEnemy(brain:GetArmyIndex(), aiBrain:GetArmyIndex()))) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Brain is dif to aiBrain so will record its start position number if it doesnt have one already')
                        end
                        iEnemyStartPos = brain.M27StartPositionNumber
                        if iEnemyStartPos == nil then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': brain doesnt have an M27StartPositionNumber set so will set it now')
                            end
                            iEnemyStartPos = M27Utilities.GetAIBrainArmyNumber(brain)
                            brain.M27StartPositionNumber = iEnemyStartPos
                        end
                        if IsEnemy(brain:GetArmyIndex(), iPlayerArmyIndex) then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': brain is an enemy of us')
                            end
                            if not (brain:IsDefeated()) and not (brain.M27IsDefeated) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': brain with index' .. brain:GetArmyIndex() .. ' is not defeated')
                                end

                                --Strange bug where still returns true for empty slot - below line to avoid this:
                                if brain:GetCurrentUnits(categories.ALLUNITS) > 0 then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': brain has some units')
                                    end
                                    if not (M27MapInfo.PlayerStartPoints[iEnemyStartPos] == nil) then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': iEnemyStartPos=' .. iEnemyStartPos .. '; iPlayerArmyIndex=' .. iPlayerArmyIndex)
                                        end
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': PlayerStartPoints[aiBrain.M27StartPositionNumber][1]=' .. M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1] .. '; M27MapInfo.PlayerStartPoints[iEnemyStartPos][1]=' .. M27MapInfo.PlayerStartPoints[iEnemyStartPos][1])
                                        end
                                        iDistToCurEnemy = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[iEnemyStartPos])
                                        if iDistToCurEnemy < iMinDistToEnemy then
                                            iMinDistToEnemy = iDistToCurEnemy
                                            iNearestEnemyIndex = brain:GetArmyIndex()
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Current nearest enemy index=' .. iNearestEnemyIndex .. '; startp osition of this enemy=' .. repru(M27MapInfo.PlayerStartPoints[iEnemyStartPos]))
                                            end
                                        end
                                    else
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Map info doesnt have a start point for iEnemyStartPos=' .. iEnemyStartPos)
                                        end
                                    end
                                else
                                    --Can have some cases where have an aibrain but no units, e.g. map Africa has ARMY_9 aibrain name, with no personality, that has no units
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': WARNING: brain isnt defeated but has no units; brain:ArmyIndex=' .. brain:GetArmyIndex())
                                    end
                                end
                            end
                        else
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': iPlayerArmyIndex=' .. iPlayerArmyIndex .. '; iEnemyArmyIndex=' .. brain:GetArmyIndex() .. '; IsEnemy isnt true for this')
                            end
                        end
                    end
                end
            end
            if iNearestEnemyIndex == nil and not (bForceDebug) then
                if not (aiBrain[refbNearestEnemyBugDisplayed]) then
                    --Are all enemies defeated?
                    local bAllDefeated = true
                    local bHaveBrains = false
                    if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.toEnemyBrains]) == false then
                        for iEnemy, oEnemyBrain in aiBrain[M27Overseer.toEnemyBrains] do
                            bHaveBrains = true
                            if not (oEnemyBrain:IsDefeated()) and not (oEnemyBrain.M27IsDefeated) then
                                bAllDefeated = false
                                break
                            end
                        end
                    end
                    if bHaveBrains and bAllDefeated == true then
                        if not(aiBrain[refbAllEnemiesDead]) then
                            LOG('All enemies defeated, ACU death count=' .. M27Overseer.iACUDeathCount)
                            if CheckIfAllEnemiesDead(aiBrain) then return nil end
                            if M27Overseer.iACUDeathCount == 0 then
                                if GetGameTimeSeconds() - iTimeOfLastBrainAllDefeated >= 5 then
                                    M27Utilities.ErrorHandler('All brains are showing as dead but we havent recorded any ACU deaths.  Assuming all enemies are dead and aborting all code; will show this message every 5s')
                                    iTimeOfLastBrainAllDefeated = GetGameTimeSeconds()
                                    aiBrain[refbAllEnemiesDead] = true
                                end
                            end

                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                            WaitSeconds(1)
                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                        else
                            return nil
                        end
                    elseif bHaveBrains and not(aiBrain[refbAllEnemiesDead]) then
                        M27Utilities.ErrorHandler('iNearestEnemyIndex is nil so will wait 1 sec and then repeat function with logs enabled; if gametime is <=10s then will also flag that the aiBrain has no enemies')
                        if GetGameTimeSeconds() <= 10 then
                            aiBrain[M27Overseer.refbNoEnemies] = true
                            if bDebugMessages == true then LOG(sFunctionRef..': Setting no enemies to be true') end
                        end
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                        WaitSeconds(1)
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                        return GetNearestEnemyIndex(aiBrain, true)
                    else
                        --No brains - could be game mode doesnt have enemy player brains
                        if not(aiBrain[refbAllEnemiesDead]) then
                            M27Utilities.ErrorHandler('Have no enemy brains to check if are defeated; if gametime is <=10s then will also flag that the aiBrain has no enemies and update start positions accordingly; otherwise will assume all enemies defeated')
                            if GetGameTimeSeconds() <= 10 then
                                aiBrain[M27Overseer.refbNoEnemies] = true
                                M27MapInfo.bUsingArmyIndexForStartPosition = true
                                M27MapInfo.RecordPlayerStartLocations()
                                if bDebugMessages == true then LOG(sFunctionRef..': No enemy brains identified, Setting no enemies to be true') end
                            elseif not(aiBrain[M27Overseer.refbNoEnemies]) then
                                --Check if any of armybrains are enemies
                                if CheckIfAllEnemiesDead(aiBrain) then return nil end
                            end
                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                            return GetNearestEnemyIndex(aiBrain, true)
                        else
                            return nil
                        end
                    end
                else
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    return aiBrain[refiNearestEnemyIndex]
                end
            else
                if iNearestEnemyIndex == nil then
                    --e.g. force debug is true
                    if not (aiBrain[refbNearestEnemyBugDisplayed]) then
                        local iLastValue = aiBrain[refiNearestEnemyIndex]
                        if iLastValue == nil then
                            iLastValue = -1
                        end --so error message wont return nil value
                        M27Utilities.ErrorHandler('iNearestEnemyIndex is nil; bForceDebug=' .. tostring(bForceDebug) .. '; relying on last valid value=' .. iLastValue .. '; all future error messages re this will be suppressed; iPlayerArmyIndex=' ..iPlayerArmyIndex)
                        aiBrain[refbNearestEnemyBugDisplayed] = true
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                        return aiBrain[refiNearestEnemyIndex]
                    else
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                        return aiBrain[refiNearestEnemyIndex]
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..'; iNearestEnemyIndex='..iNearestEnemyIndex..'; about to set bIntelPathsGenerated to false so theyll be re-done') end
                    aiBrain[refiNearestEnemyIndex] = iNearestEnemyIndex
                    aiBrain[refiNearestEnemyIndex] = iNearestEnemyIndex
                    --Update intel path as nearest enemy has changed
                    aiBrain[M27Overseer.refbIntelPathsGenerated] = false
                    ForkThread(M27MapInfo.SetWhetherCanPathToEnemy,aiBrain)
                end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return iNearestEnemyIndex
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': our aiBrain is defeated so will just return nil') end
            return nil
        end
    end
end

function IndexToStartNumber(iArmyIndex)
    --Returns the start position for iArmyIndex
    local iStartPoint
    if M27Utilities.IsTableEmpty(tPlayerStartPointByIndex) == true then
        --Need to record all positions
        local iCurIndex
        for iCurBrain, oBrain in ArmyBrains do
            iCurIndex = oBrain:GetArmyIndex()
            tPlayerStartPointByIndex[iCurIndex] = oBrain.M27StartPositionNumber
        end
    end
    iStartPoint = tPlayerStartPointByIndex[iArmyIndex]
    if iStartPoint == nil then
        if not(iTimeOfLastBrainAllDefeated) or iTimeOfLastBrainAllDefeated<10 then
            M27Utilities.ErrorHandler('Dont have start position for iArmyIndex='..(iArmyIndex or 'nil')..'; will now enable logs and try to figure out why. iTimeOfLastBrainAllDefeated='..(iTimeOfLastBrainAllDefeated or 'nil'))
            for iCurBrain, aiBrain in ArmyBrains do
                LOG('iCurBrain='..iCurBrain..'; ArmyIndex='..aiBrain:GetArmyIndex()..'; M27StartPositionNumber='..(aiBrain.M27StartPositionNumber or 'nil'))
                if not(aiBrain.M27StartPositionNumber) then
                    LOG('M27Utilities.GetAIBrainArmyNumber(aiBrain)='..(M27Utilities.GetAIBrainArmyNumber(aiBrain) or 'nil'))
                end
            end
        end
    end
    return iStartPoint
end

function GetNearestEnemyStartNumber(aiBrain)
    local iNearestEnemyIndex = GetNearestEnemyIndex(aiBrain)
    return IndexToStartNumber(iNearestEnemyIndex)
end

function GetUnitNearestEnemy(aiBrain, tUnits)
    --returns the unit nearest the enemy start location (or nil if there is none); only considers units that are not dead
    --(note - probably better to have just used GetNearestUnit from M27Utilities)
    if (iTimeOfLastBrainAllDefeated or 0) > 10 then
        return nil
    else
        return M27Utilities.GetNearestUnit(tUnits, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), aiBrain, false)
    end
    --[[
    local iNearestDistance = 100000
    local oNearestUnit
    local tEnemyStart = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
    local iCurDistanceToEnemy
    for iUnit, oUnit in tUnits do
        if not(oUnit.Dead) and oUnit.GetPosition then
            iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tEnemyStart)
            if iCurDistanceToEnemy < iNearestDistance then
                oNearestUnit = oUnit
                iNearestDistance = iCurDistanceToEnemy
            end
        end
    end
    return oNearestUnit--]]
end

--[[function GetNearestEnemyStartNumber(aiBrain)
    --Returns the start position number of the enemy nearest aiBrain (note - start position number isn't the same as armyindex)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetNearestEnemyStartNumber'
    local iEnemyIndex = GetNearestEnemyIndex(aiBrain)
    local iOurIndex = aiBrain:GetArmyIndex()
    local oEnemyBrain
    local iEnemyStartNumber
    if bDebugMessages == true then LOG(sFunctionRef..': aiBrain.Name='..aiBrain.Name) end
    if bDebugMessages == true then LOG(sFunctionRef..': iEnemyIndex='..iEnemyIndex) end
    if aiBrain == nil then
        M27Utilities.ErrorHandler('aiBrain is nil, something has gone wrong')
    else
        if iEnemyIndex == nil then
            LOG(sFunctionRef..': iEnemyIndex is nil, will now re-run with logs enabled in case this is an error')
            iEnemyIndex = GetNearestEnemyIndex(aiBrain, true)
            M27Utilities.ErrorHandler('iEnemyIndex is nil but aiBrain isnt, so presumably end of game, will wait 30 seconds', 30)
        end
    end
    for iCurBrain, oBrain in ArmyBrains do
        if bDebugMessages == true then LOG(sFunctionRef..': Cycling through each brain; iEnemyIndex='..iEnemyIndex..'; oBrain:Index='..oBrain:GetArmyIndex()) end
        if oBrain:GetArmyIndex() == iEnemyIndex then oEnemyBrain = oBrain break
        elseif iEnemyIndex == nil then
            if IsEnemy(iOurIndex, oBrain:GetArmyIndex()) == true then oEnemyBrain = oBrain end
        end
    end
    if oEnemyBrain == nil then
        M27Utilities.ErrorHandler('oEnemyBrain is nil, recycling through brains to find one who is an enemy')
        for iCurBrain, oBrain in ArmyBrains do
            if IsEnemy(iOurIndex, oBrain:GetArmyIndex()) == true then oEnemyBrain = oBrain break end
        end
    end
    if oEnemyBrain == nil then
        if aiBrain[refiNearestEnemyStartPoint] then
            M27Utilities.ErrorHandler('Still not able to find an enemy brain, will revert to using the last recorded start position instead')
        else
            M27Utilities.ErrorHandler('still not able to find an enemy brain, and dont have a valid previously recorded value either, will wait 1 second then return nil')
            WaitSeconds(1)
            return nil
        end
    else
        iEnemyStartNumber = oEnemyBrain.M27StartPositionNumber
        aiBrain[refiNearestEnemyStartPoint] = iEnemyStartNumber
    end
    return iEnemyStartNumber --May return a nil value
end--]]

function GetMexRaidingPath(oPlatoonHandle, iIgnoreDistanceFromStartLocation, iEndPointMaxDistFromEnemyStart, iIgnoreDistanceFromOwnStart, bOnlyTargetEndDestination)
    --Returns a table containing a movement order for raiding for tUnits
    --Logic: Determine the end mex destination wanted, then choose pathing to get to there if the intermediary step both reduces the VDist to the end poitn, and is further away from the start point
    --Ignores mexes that are within iIgnoreDistanceFromStartLocation of any non-defeated player
    --iEndPointMaxDistFromEnemyStart: optional, if nil then will be ignored, otherwise end point needs to be within this far of the enemy start (or the nearest mex if none within such a distance)
    --iIgnoreDistanceFromOwnStart: optional, will default to iIgnoreDistanceFromStartLocation if nil, otherwise allows you to ignore friendly mexes near start while still considering mexes near enemy start
    --bOnlyTargetEndDestination: optional, will default to false; if true then will just choose an end mex poitn and not stop at mexes on the way

    --if are no mexes that can path to then will return the enemy base
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetMexRaidingPath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if iIgnoreDistanceFromOwnStart == nil then iIgnoreDistanceFromOwnStart = iIgnoreDistanceFromStartLocation end
    if bOnlyTargetEndDestination == nil then bOnlyTargetEndDestination = false end

    --if oPlatoonHandle:GetPlan() == 'M27DefenderAI' and oPlatoonHandle[refiPlatoonCount] == 25 then bDebugMessages = true end

    local iMinDistanceFromPlatoon = 30 --To help stop rare error where platoon gets a new path that is near where it currently is
    local bMexNotByUs --true if mex is by us
    local iLoopCount = 0 --Used for debugging
    local iMaxLoopCountBeforeChecks = 20 --If a while loop goes more than this number of times then will send out an error log and turn on debugging even if it's off
    local oUnit = M27PlatoonUtilities.GetPathingUnit(oPlatoonHandle)
    local aiBrain = oPlatoonHandle:GetBrain()
    local bAbort = false
    if aiBrain == nil then
        M27Utilities.ErrorHandler('aiBrain is nil, will return the position for the first player')
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return {M27MapInfo.PlayerStartPoints[1]}
    end

    local bHaveAliveUnit = true
    if oUnit == nil or not(oUnit.GetPosition) then
        bHaveAliveUnit = false
        --Likely platoon units are dead so disband (if are alive units in platoon then instead give error message and send back to start)
        local oPlatoonUnits = oPlatoonHandle:GetPlatoonUnits()
        if M27Utilities.IsTableEmpty(oPlatoonUnits) == true then
            if bDebugMessages == true then LOG(sFunctionRef..': Platoon has no units so disbanding') end
            oPlatoonHandle[M27PlatoonUtilities.refiCurrentAction] = M27PlatoonUtilities.refActionDisband
        else
            for iUnit, oUnit in oPlatoonUnits do
                if not(oUnit.Dead) and oUnit.GetPosition then bHaveAliveUnit = true break end
            end
        end
    end
    local tSortedFinalWaypoints = {}
    if bHaveAliveUnit == false then
        M27Utilities.ErrorHandler('Cant find valid unit in platoon, will set platoon to disband and return start position as the movement path.  Will send log with platoon plan and count after this', true)
        if oPlatoonHandle.GetPlan then LOG(oPlatoonHandle:GetPlan()..(oPlatoonHandle[M27PlatoonUtilities.refiPlatoonCount] or 'nil')) end
        oPlatoonHandle[M27PlatoonUtilities.refiCurrentAction] = M27PlatoonUtilities.refActionDisband
        tSortedFinalWaypoints = {M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]}
        if oPlatoonHandle[M27PlatoonUtilities.refiPlatoonCount] and oPlatoonHandle.GetPlan and oPlatoonHandle:GetPlan() and oPlatoonHandle[M27PlatoonUtilities.refiCurrentUnits] then LOG(oPlatoonHandle[M27PlatoonUtilities.refiPlatoonCount]..'; plan='..oPlatoonHandle:GetPlan()..'; currentunits='..oPlatoonHandle[M27PlatoonUtilities.refiCurrentUnits])
        else LOG('Some of platoon core data is nil') end
    else
        local tUnitStart = oUnit:GetPosition()
        local iPlayerArmyIndex = aiBrain:GetArmyIndex()
        if GetNearestEnemyStartNumber(aiBrain) then
            local sPathing = M27UnitInfo.GetUnitPathingType(oUnit)
            if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
            local iBaseStartGroup = M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            --function InSameSegmentGroup(oUnit, tDestination, bReturnUnitGroupOnly)
            local iUnitSegmentX, iUnitSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tUnitStart)
            local iUnitSegmentGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iUnitSegmentX, iUnitSegmentZ)
            local tPossibleMexTargets = {} --Table storing the mex number within tMexByPathingAndGrouping for mexes that aren't in enemy base (or other player base where other player is alive) but are nearer enemy than us

            --Determine PlayerStartPoints:
            local tActivePlayerStartLocations = {}
            local iActivePlayerCount = 0
            local iCurPlayerStartNumber = 0
            if bDebugMessages == true then LOG(sFunctionRef..': sPathing='..sPathing..'; iUnitSegmentGroup='..iUnitSegmentGroup) end
            for iCurBrain, brain in ArmyBrains do
                if not(brain:IsDefeated()) and not(brain.M27IsDefeated) then
                    iCurPlayerStartNumber = brain.M27StartPositionNumber
                    if not (M27MapInfo.PlayerStartPoints[iCurPlayerStartNumber] == nil) then
                        if aiBrain:GetCurrentUnits(categories.ALLUNITS) > 0 then
                            iActivePlayerCount = iActivePlayerCount + 1
                            tActivePlayerStartLocations[iActivePlayerCount] = {}
                            tActivePlayerStartLocations[iActivePlayerCount] = M27MapInfo.PlayerStartPoints[iCurPlayerStartNumber]
                        end
                    end
                end
            end

            local iMinDistanceFromStart
            local iCurDistanceFromStart
            local iDistanceToEnemyBase = 0
            local iDistanceToOurBase = 0
            local tCurMexPosition = {}
            local iPossibleTargetCount = 0
            local iMinRaidsAlreadySent = 1000
            local sMexLocationRef
            local tFriendlyPossibleMexes = {}
            local iFriendlyPossibleMexes = 0
            local bIsEnemyMex
            local bIsStartMex
            local bIsEndDestinationMex
            local tMexesInGroup = M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitSegmentGroup]

            local iTotalMexesInGroup
            if M27Utilities.IsTableEmpty(tMexesInGroup) == true then iTotalMexesInGroup = 0
                else iTotalMexesInGroup = table.getn(tMexesInGroup) end
            if iTotalMexesInGroup == nil then iTotalMexesInGroup = 0 end
            if bDebugMessages == true then
                LOG(sFunctionRef..': MexesByPathingAndGrouping='..repru(M27MapInfo.tMexByPathingAndGrouping))
                --M27Utilities.DrawLocations(tMexesInGroup, nil, 7, 1000)
            end
            local bNoBetterTargets
            if bDebugMessages == true then LOG(sFunctionRef..': iActivePlayerCount='..iActivePlayerCount..'; size of tMexByPathingAndGrouping='..iTotalMexesInGroup..'; sPathing='..sPathing..'; iUnitSegmentGroup='..iUnitSegmentGroup) end
            if iTotalMexesInGroup == 0 then
                bNoBetterTargets = true
                --No mexes in group; check if are in the base group (as if a platoon is spread out some units may be on other segments):
                local tAltUnits
                local iAltUnits = 0
                if not(iUnitSegmentGroup == iBaseStartGroup) then
                    --See if any units are in the segment group wanted:
                    tAltUnits = ReturnUnitsInTargetSegmentGroup(oPlatoonHandle[M27PlatoonUtilities.refiCurrentUnits], iBaseStartGroup)
                    if M27Utilities.IsTableEmpty(tAltUnits) == false then bNoBetterTargets = false end
                end
                if bNoBetterTargets == false then
                    oUnit = tAltUnits[math.random(1, iAltUnits)]
                    sPathing = M27UnitInfo.GetUnitPathingType(oUnit)
                    if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
                    iUnitSegmentGroup = 1
                    iTotalMexesInGroup = table.getn(M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitSegmentGroup])
                    if iTotalMexesInGroup == nil then
                        M27Utilities.ErrorHandler('iTotalMexesInGroup is nil after looking for iUnitSegmentGroup1')
                        bNoBetterTargets = true
                    elseif iTotalMexesInGroup == 0 then
                        bNoBetterTargets = true
                        M27Utilities.ErrorHandler('iTotalMexesInGroup is nil after looking for iUnitSegmentGroup1')
                    end
                    if bNoBetterTargets == true then
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                        return {M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)}
                    end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': iTotalMexesInGroup='..iTotalMexesInGroup..'; about to do loop') end

            for iCurMex = 1, iTotalMexesInGroup do
                --Is the mex closer to the enemy than to us?
                tCurMexPosition = M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitSegmentGroup][iCurMex]
                if M27Utilities.IsTableEmpty(tCurMexPosition) == false then
                    iDistanceToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tCurMexPosition, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                    iDistanceToOurBase = M27Utilities.GetDistanceBetweenPositions(tCurMexPosition, M27MapInfo.PlayerStartPoints[iPlayerArmyIndex])
                    if bDebugMessages == true then LOG(sFunctionRef..': Looping through mex, iCurMex='..iCurMex..'; iDistanceToEnemyBase='..iDistanceToEnemyBase..'; iDistanceToOurBase='..iDistanceToOurBase) end
                    --Check if mex is too close to any player start:
                    --if iDistanceToEnemyBase > iIgnoreDistanceFromStartLocation and iDistanceToOurBase > iIgnoreDistanceFromStartLocation then
                    bIsStartMex = false
                    iMinDistanceFromStart = 1000000
                    if iDistanceToEnemyBase > iIgnoreDistanceFromStartLocation and iDistanceToOurBase > iIgnoreDistanceFromStartLocation then
                        if M27Utilities.GetDistanceBetweenPositions(tCurMexPosition, tUnitStart) > iMinDistanceFromPlatoon then
                            bMexNotByUs = true
                            for iCurPlayer = 1, iActivePlayerCount do
                                iCurDistanceFromStart = M27Utilities.GetDistanceBetweenPositions(tCurMexPosition, tActivePlayerStartLocations[iCurPlayer])
                                if iCurDistanceFromStart <= iIgnoreDistanceFromStartLocation then
                                    iMinDistanceFromStart = iCurDistanceFromStart
                                    break
                                end
                            end
                            if iMinDistanceFromStart <= iIgnoreDistanceFromStartLocation then bIsStartMex = true end
                        else bMexNotByUs = false
                        end
                    else bIsStartMex = true
                    end


                    --Check if its on enemy side of the map:
                    bIsEnemyMex = false
                    if iDistanceToEnemyBase <= iDistanceToOurBase then bIsEnemyMex = true end
                    if bDebugMessages == true then LOG(sFunctionRef..': iCurMex='..iCurMex..'; bIsEnemyMex='..tostring(bIsEnemyMex)..'; bIsStartMex='..tostring(bIsStartMex)) end
                    --Record enemy mexes outside of base areas:
                    if bDebugMessages == true then LOG('iCurMex='..iCurMex..'; tCurMexPositionXZ='..tCurMexPosition[1]..'-'..tCurMexPosition[3]..'; bIsEnemyMex='..tostring(bIsEnemyMex)..'; bIsStartMex='..tostring(bIsStartMex)..'; iPossibleTargetCount='..iPossibleTargetCount) end
                    if bIsStartMex == false and bIsEnemyMex == true then
                        if bMexNotByUs == true then
                            --Can consider as a potential end target and the no. of times a platoon has been sent to a target
                            iPossibleTargetCount = iPossibleTargetCount + 1
                            tPossibleMexTargets[iPossibleTargetCount] = tCurMexPosition
                            if iMinRaidsAlreadySent > 0 then
                                sMexLocationRef = M27Utilities.ConvertLocationToStringRef(tCurMexPosition)
                                if tPlatoonRaiderTargets == nil then tPlatoonRaiderTargets = {} end
                                if tPlatoonRaiderTargets[iPlayerArmyIndex] == nil then tPlatoonRaiderTargets[iPlayerArmyIndex] = {} end
                                if tPlatoonRaiderTargets[iPlayerArmyIndex][sMexLocationRef] == nil then tPlatoonRaiderTargets[iPlayerArmyIndex][sMexLocationRef] = 0 end
                                if iMinRaidsAlreadySent >= tPlatoonRaiderTargets[iPlayerArmyIndex][sMexLocationRef] then
                                    --Only consider if will be a valid end position:
                                    bIsEndDestinationMex = false
                                    if iEndPointMaxDistFromEnemyStart == nil then bIsEndDestinationMex = true
                                    elseif M27Utilities.GetDistanceBetweenPositions(tCurMexPosition, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) <= iEndPointMaxDistFromEnemyStart then bIsEndDestinationMex = true end
                                    if bIsEndDestinationMex == true then iMinRaidsAlreadySent = tPlatoonRaiderTargets[iPlayerArmyIndex][sMexLocationRef] end
                                end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': iPossibleTargetCount='..iPossibleTargetCount..'; iMinRaidsAlreadySent='..iMinRaidsAlreadySent..'; tPlatoonRaiderTargets[iPlayerArmyIndex][sMexLocationRef]='..tPlatoonRaiderTargets[iPlayerArmyIndex][sMexLocationRef]) end
                        end
                    end
                    --Record friendly mexes outside of base areas to consider passing by after determined raid targets:
                    if bIsStartMex == false and bIsEnemyMex == false and bOnlyTargetEndDestination == false then
                        --Is it near our start?
                        if iDistanceToOurBase > iIgnoreDistanceFromOwnStart then
                            iFriendlyPossibleMexes = iFriendlyPossibleMexes + 1
                            tFriendlyPossibleMexes[iFriendlyPossibleMexes] = {}
                            tFriendlyPossibleMexes[iFriendlyPossibleMexes] = tCurMexPosition
                            if bDebugMessages == true then LOG(sFunctionRef..': FriendlyPossibleMex: iFriendlyPossibleMexes='..iFriendlyPossibleMexes..'; iDistanceToOurBase='..iDistanceToOurBase..'; tCurMexPosition='..tCurMexPosition[1]..'-'..tCurMexPosition[3]) end
                        end
                    end
                end
            end

            --Have now recorded the min. no. of raids sent to a particular mex and got a table of possible mexes
            --Next step: Prepare a new table with just the mexes that have the min. no. of raids sent to them that are also close enough to the enemy base (if specified a max distasnce from base)
            local tRevisedMexTargets = {}
            local iRevisedPossibleMex = 0
            if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through possible targets, iPossibleTargetCount='..iPossibleTargetCount..'; iEndPointMaxDistFromEnemyStart='..(iEndPointMaxDistFromEnemyStart or 'nil')..'; platoon='..oPlatoonHandle:GetPlan()..oPlatoonHandle[M27PlatoonUtilities.refiPlatoonCount]..'; Platoon location='..repru(oPlatoonHandle:GetPlatoonPosition())) end
              local bErrorControl = false
            local iFinalMex
            local tFinalWaypoints = {}
            tFinalWaypoints[1] = {}
            if iPossibleTargetCount > 0 then
                for iCurMex = 1, iPossibleTargetCount do
                    tCurMexPosition = tPossibleMexTargets[iCurMex]
                    --if have specified a distance from enemy base, check if are close enough:
                    bIsEndDestinationMex = false
                    if iEndPointMaxDistFromEnemyStart == nil then bIsEndDestinationMex = true
                    elseif M27Utilities.GetDistanceBetweenPositions(tCurMexPosition, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) <= iEndPointMaxDistFromEnemyStart then bIsEndDestinationMex = true end

                    if bIsEndDestinationMex == true then
                        sMexLocationRef = M27Utilities.ConvertLocationToStringRef(tCurMexPosition)
                        if tPlatoonRaiderTargets[iPlayerArmyIndex][sMexLocationRef] <= iMinRaidsAlreadySent then
                            iRevisedPossibleMex = iRevisedPossibleMex + 1
                            tRevisedMexTargets[iRevisedPossibleMex] = {}
                            tRevisedMexTargets[iRevisedPossibleMex] = tCurMexPosition
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': PossibleTargetCount cycle; iCurMex='..iCurMex..'; bIsEndDstinationMex='..tostring(bIsEndDestinationMex)) end
                end
                --Now have a table of possible mex targets where no platoon/the min. number of platoons has been sent.  Pick one of them randomly:


                if iRevisedPossibleMex == nil then iRevisedPossibleMex = 0
                    bErrorControl = true
                elseif iRevisedPossibleMex < 1 then bErrorControl = true
                end
            else
                bErrorControl = true
            end
            if bErrorControl then
                bErrorControl = false
                if iPossibleTargetCount == nil then bErrorControl = true
                elseif iPossibleTargetCount == 0 then bErrorControl = true end
                if bErrorControl then
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    return {M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)}
                else
                    M27Utilities.ErrorHandler('iRevisedPossibleMex is nil or 0 but iPossibleTargetCount > 0 so reverting to that')
                    iFinalMex = math.random(1, iPossibleTargetCount)
                    tFinalWaypoints[1] = tPossibleMexTargets[iFinalMex]
                end
            else
                iFinalMex = math.random(1, iRevisedPossibleMex)
                tFinalWaypoints[1] = tRevisedMexTargets[iFinalMex]
            end
            local iFinalWaypoints = 1
            local tUnitPosition = oUnit:GetPosition()
            bNoBetterTargets = false
            if oUnit == nil then M27Utilities.ErrorHandler('oUnit is nil')
                bNoBetterTargets = true
            elseif iFinalMex == nil then
                M27Utilities.ErrorHandler('iFinalMex is nil. iRevisedPossibleMex='..iRevisedPossibleMex)
                bNoBetterTargets = true
            elseif iFinalMex == 0 then
                M27Utilities.ErrorHandler('iFinalMex is 0, but shouldve already spotted this when fixing iRevisedPossibleMex')
                bNoBetterTargets = true
            end
            if bNoBetterTargets == true then
                M27Utilities.ErrorHandler('bNoBetterTargets is true, returning player start point')
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return {M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)}
            end

            if bDebugMessages == true then LOG(sFunctionRef..': iRevisedPossibleMex='..iRevisedPossibleMex..'; iFinalMex='..iFinalMex) end
            if tFinalWaypoints[1][1] == nil then
                M27Utilities.ErrorHandler('tFinalWaypoints is nil, will revert to aiBrain listing of priority mexes and ignore intermediary mexes')
                tFinalWaypoints = {}
                tFinalWaypoints[1] = {}
                --TODO - long term want to repalce this entire function to be based off HighPrioritymexes
                local iCurrentMexPriorities = table.getn(aiBrain[M27MapInfo.reftHighPriorityMexes])
                local iMexWanted = math.random(1, iCurrentMexPriorities)
                tFinalWaypoints[1] = aiBrain[M27MapInfo.reftHighPriorityMexes][iMexWanted]
                bOnlyTargetEndDestination = true
            end
            if tUnitPosition == nil then M27Utilities.ErrorHandler('tUnitPosition is nil') end
            local iDistToFinal = M27Utilities.GetDistanceBetweenPositions(tFinalWaypoints[1], tUnitPosition)
            local iCurDistToUnit = 0
            local iFurthestValidMex = 0
            local iMinDistToLastMex = 1000000
            local iCurDistToLastMex = 0
            --Return table contents for debugging:
            if bDebugMessages == true then
                LOG('About to dump tPossibleMexTargets data')
                LOG(repru(tPossibleMexTargets))
                LOG('About to dump friendly mex targets data')
                LOG(repru(tFriendlyPossibleMexes))
            end
            --Now need to add in mexes inbetween the end point and oUnit's start point
            if bOnlyTargetEndDestination == false then
                if iPossibleTargetCount > 1 then
                    local bSearchForMexes = true
                    local bFoundPassThroughMex
                    local tLastMexPosition = {}
                    iLoopCount = 0
                    local iEnemyMexStart, iEnemyMexEnd, iEnemyMexRand
                    if iPossibleTargetCount > 10 then
                        --Randomly choose 10 of the mexes to consider (to help mitigate slowdown on large maps)
                        iEnemyMexRand = math.random(1, iPossibleTargetCount)
                        iEnemyMexStart = iEnemyMexRand - 5
                        iEnemyMexEnd = iEnemyMexRand + 4
                        if iEnemyMexStart < 1 then
                            iEnemyMexEnd = iEnemyMexEnd - (iEnemyMexStart - 1)
                            iEnemyMexStart = 1
                        elseif iEnemyMexEnd > iPossibleTargetCount then
                            iEnemyMexStart = iEnemyMexStart + (iEnemyMexEnd - iPossibleTargetCount)
                            iEnemyMexEnd = iPossibleTargetCount
                        end
                    else
                        iEnemyMexStart = 1
                        iEnemyMexEnd = iPossibleTargetCount
                    end
                    local iWaitCount = 0
                    while bSearchForMexes == true do
                        iLoopCount = iLoopCount + 1
                        iWaitCount = iWaitCount + 1
                        if iLoopCount > iMaxLoopCountBeforeChecks then
                            M27Utilities.ErrorHandler('iLoopCount has exceeded iMaxLoopCountBeforeChecks, likely infinite loop; slowing down script') bDebugMessages = true --for error control - want these enabled to help debugging where get this error arising
                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                            WaitTicks(5)
                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                        end
                        --Cycle through all of the possible targets, and pick the one furthest away that is still closer than the target
                        if bDebugMessages == true then LOG(sFunctionRef..': enemy while loop: Search for mexes: Start  of loop before loping through each mex. iLoopCount='..iLoopCount..'; iPossibleTargetCount='..iPossibleTargetCount) end
                        if iPossibleTargetCount <= 0 then
                            --Note - below error message can sometimes trigger e.g. if large group of units and some are in impassable area
                            M27Utilities.ErrorHandler('Dont have any possible target mexes, iPossibleTargetCount <=0')
                            break end
                        bFoundPassThroughMex = false
                        tLastMexPosition = tFinalWaypoints[iFinalWaypoints]
                        if M27Utilities.IsTableEmpty(tLastMexPosition) then
                            M27Utilities.ErrorHandler('tLastMexPosition is empty, iFinalWaypoints='..iFinalWaypoints..repru(tFinalWaypoints)..'; if iFinalWaypoints is > 1 then will change to 1 to try and let code continue working')
                            if iFinalWaypoints > 1 then iFinalWaypoints = 1 end
                            break end

                        iMinDistToLastMex = 1000000
                        iFurthestValidMex = 0
                        for iCurMex = iEnemyMexStart, iEnemyMexEnd do
                            tCurMexPosition = tPossibleMexTargets[iCurMex]
                            iCurDistToUnit = M27Utilities.GetDistanceBetweenPositions(tCurMexPosition, tUnitPosition)
                            iCurDistToLastMex = M27Utilities.GetDistanceBetweenPositions(tCurMexPosition, tLastMexPosition)
                            if iCurDistToLastMex > 0 then --Don't want duplicate mex targets
                                if bDebugMessages == true then LOG(sFunctionRef..': enemy while loop: Search for mexes: iCurMex='..iCurMex..'; iCurDistToUnit='..iCurDistToUnit..'; iDistToFinal='..iDistToFinal..'; iCurDistToLastMex='..iCurDistToLastMex..'; iMinDistToLastMex='..iMinDistToLastMex..'; tLastMexPosition='..tLastMexPosition[1]..'-'..tLastMexPosition[3]..'; iFinalWaypoints='..iFinalWaypoints) end
                                if iCurDistToUnit < iDistToFinal and iCurDistToLastMex < iMinDistToLastMex then
                                    --iMaxDistToUnit = iCurDistToUnit
                                    iMinDistToLastMex = iCurDistToLastMex
                                    iFurthestValidMex = iCurMex
                                    bFoundPassThroughMex = true
                                else
                                    if iCurMex >= iEnemyMexEnd then
                                        if bFoundPassThroughMex == false then bSearchForMexes = false end
                                        bFoundPassThroughMex = false
                                    end
                                end
                            end
                        end
                        if bFoundPassThroughMex == true then
                            --Add this mex to the final locations:
                            iFinalWaypoints = iFinalWaypoints + 1
                            tFinalWaypoints[iFinalWaypoints] = {}
                            tFinalWaypoints[iFinalWaypoints] = tPossibleMexTargets[iFurthestValidMex]
                            table.remove(tPossibleMexTargets, iFurthestValidMex)
                            iPossibleTargetCount = iPossibleTargetCount - 1
                            if iFurthestValidMex >= iEnemyMexStart and iFurthestValidMex <= iEnemyMexEnd then iEnemyMexEnd = iEnemyMexEnd - 1 end
                            if iEnemyMexStart > iEnemyMexEnd then bSearchForMexes = false end
                            if bDebugMessages == true then LOG(sFunctionRef..' Adding mex to tFinalWaypoints, iFinalWaypoints='..iFinalWaypoints..'; iFurthestValidMex='..iFurthestValidMex..'; Mex location='..tFinalWaypoints[iFinalWaypoints][1]..'-'..tFinalWaypoints[iFinalWaypoints][3]) end
                        else
                            bSearchForMexes = false
                        end
                        if iWaitCount > 2 then
                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                            WaitTicks(1)
                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                            iWaitCount = 0
                        end
                        bAbort = true
                        if oPlatoonHandle and aiBrain and aiBrain:PlatoonExists(oPlatoonHandle) == true and oUnit and not(oUnit.Dead) then bAbort = false end
                        if bAbort == true then
                            LOG(sFunctionRef..': Warning - platoon or pathing unit no longer exists after waiting 1 tick, aborting')
                            break
                        end
                    end
                end
                --Logic for adding via point near friendly mexes - have decided to ignore in v29 for performance reasons
                --[[
                if bAbort == false then
                    --Are there any mexes on our side of the map that wouldn't result in a significant detour to pass by? If so then add to queue
                    if iFriendlyPossibleMexes > 0 then
                        if M27Utilities.GetDistanceBetweenPositions(tUnitStart, M27MapInfo.PlayerStartPoints[iPlayerArmyIndex]) > M27Utilities.GetDistanceBetweenPositions(tUnitStart, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) then
                            --Dont search for friendly mexes as are closer to enemy base than our own
                        else
                            --To avoid significant slowdown, if >10 friendly mexes then split them into groups of 10
                            local iMexSubgroupEnd, iMexSubgroupStart, iMexSubgroupRand

                            if iFriendlyPossibleMexes > 10 then
                                iMexSubgroupRand = math.random(1, iFriendlyPossibleMexes)
                                iMexSubgroupStart = iMexSubgroupRand - 5
                                iMexSubgroupEnd = iMexSubgroupRand + 4
                                if iMexSubgroupStart < 1 then
                                    iMexSubgroupEnd = iMexSubgroupEnd - (iMexSubgroupStart - 1)
                                    iMexSubgroupStart = 1
                                elseif iMexSubgroupEnd > iFriendlyPossibleMexes then
                                    iMexSubgroupStart = iMexSubgroupStart + (iMexSubgroupEnd - iPossibleTargetCount)
                                    iMexSubgroupEnd = iPossibleTargetCount
                                end
                            else
                                iMexSubgroupStart = 1
                                iMexSubgroupEnd = iFriendlyPossibleMexes
                            end
                            bSearchForMexes = true
                            local iExistingPathingDistance
                            local iCurPathingDistance
                            local iMaxDistanceFactor = 1.2
                            local iCurDistanceToUnit
                            iLoopCount = 0
                            while bSearchForMexes == true do
                                --Current distance from last enemy mex and current location:
                                iLoopCount = iLoopCount + 1
                                if iLoopCount > iMaxLoopCountBeforeChecks then
                                    M27Utilities.ErrorHandler(sFunctionRef..': iLoopCount has exceeded iMaxLoopCountBeforeChecks, likely infinite loop; slowing down script', nil, true)
                                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                                    WaitTicks(5)
                                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                                end

                                if bDebugMessages == true then LOG('Friendly while loop started, iLoopCount='..iLoopCount) end
                                iCurPathingDistance = 0
                                if M27Utilities.IsTableEmpty(tFinalWaypoints[iFinalWaypoints]) then
                                    M27Utilities.ErrorHandler('tFinalWaypoints[iFinalWaypoints] is empty; iFinalWaypoints='..iFinalWaypoints)
                                    bSearchForMexes = false
                                    break
                                else
                                    iExistingPathingDistance = M27Utilities.GetDistanceBetweenPositions(tFinalWaypoints[iFinalWaypoints], tUnitPosition)
                                    iMinDistToLastMex = 100000
                                    iFurthestValidMex = 0
                                    for iCurFriendlyMex, tFriendlyMex in tFriendlyPossibleMexes do
                                    --for iCurFriendlyMex = iMexSubgroupStart, iMexSubgroupEnd do
                                        if tFinalWaypoints[iFinalWaypoints] == nil then M27Utilities.ErrorHandler('tFinalWaypoints[iFinalWaypoints] is nil; iCurFriendlyMex='..iCurFriendlyMex..'; iFinalWaypoints='..iFinalWaypoints) end
                                        if tFinalWaypoints[iFinalWaypoints] == nil then M27Utilities.ErrorHandler('tFriendlyPossibleMexes[iCurFriendlyMex] is nil; iCurFriendlyMex='..iCurFriendlyMex..'iFinalWaypoints='..iFinalWaypoints..'; tFriendlyMex='..repru(tFriendlyMex)) end
                                        iCurDistToLastMex = M27Utilities.GetDistanceBetweenPositions(tFinalWaypoints[iFinalWaypoints], tFriendlyMex)
                                        iCurDistanceToUnit = M27Utilities.GetDistanceBetweenPositions(tUnitPosition, tFriendlyMex)
                                        iCurPathingDistance = iCurDistToLastMex + iCurDistanceToUnit
                                        if iCurDistToLastMex > 0 then --may be considering the same mex as before, so this stops infinite loop
                                            if iCurDistanceToUnit < iExistingPathingDistance then --No point adding this mex if it ends up being further away
                                                if iCurPathingDistance / iExistingPathingDistance <= iMaxDistanceFactor then
                                                    if iCurDistToLastMex < iMinDistToLastMex then
                                                        if bDebugMessages == true then LOG('FriendlyMex while loop: found new mex for pathing, iCurFriendlyMex='..iCurFriendlyMex..'; iCurPathingDistance='..iCurPathingDistance..'; iExistingPathingDistance='..iExistingPathingDistance..'; iCurDistToLastMex='..iCurDistToLastMex..'; iFinalWaypoints='..iFinalWaypoints..'; tFinalWaypoints[iFinalWaypoints]XZ='..tFinalWaypoints[iFinalWaypoints][1]..'-'..tFinalWaypoints[iFinalWaypoints][3]) end
                                                        iMinDistToLastMex = iCurDistToLastMex
                                                        iFurthestValidMex = iCurFriendlyMex
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    if iFurthestValidMex > 0 then
                                        --Have a friendly mex to consider
                                        iFinalWaypoints = iFinalWaypoints + 1
                                        tFinalWaypoints[iFinalWaypoints] = {}
                                        tFinalWaypoints[iFinalWaypoints] = tFriendlyPossibleMexes[iFurthestValidMex]
                                        table.remove(tFriendlyPossibleMexes, iFurthestValidMex)
                                        iFriendlyPossibleMexes = iFriendlyPossibleMexes - 1
                                        if iFurthestValidMex >= iMexSubgroupStart and iFurthestValidMex <= iMexSubgroupEnd then iMexSubgroupEnd = iMexSubgroupEnd - 1 end
                                        if bDebugMessages == true then LOG(sFunctionRef..': Adding friendly mex to movement path; iFurthestValidMex='..iFurthestValidMex..'; iFinalWaypoints='..iFinalWaypoints) end
                                        if iMexSubgroupStart > iMexSubgroupEnd then bSearchForMexes = false end
                                    else
                                        bSearchForMexes = false
                                        break
                                    end
                                end
                                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                                WaitTicks(1)
                                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                                bAbort = true
                                if oPlatoonHandle and aiBrain and aiBrain:PlatoonExists(oPlatoonHandle) == true and oUnit and not(oUnit.Dead) then bAbort = false end
                                if bAbort == true then
                                    LOG(sFunctionRef..': Warning - platoon or pathing unit no longer exists after waiting 1 tick, aborting')
                                end
                            end
                        end
                    end
                end --]]
            end
            if M27Utilities.IsTableEmpty(tFinalWaypoints) == true then
                bAbort = true
            else
                iFinalWaypoints = table.getn(tFinalWaypoints)
            end

            if bAbort == false then
                --Return table contents for debugging:
                if bDebugMessages == true then
                    LOG('About to dump tFinalWaypoints data')
                    LOG(repru(tFinalWaypoints))
                end
                --Reverse order of tFinalWaypoints
                for iCurWaypoint = 1, iFinalWaypoints do
                    tSortedFinalWaypoints[iCurWaypoint] = {}
                    tSortedFinalWaypoints[iCurWaypoint] = tFinalWaypoints[iFinalWaypoints + 1 - iCurWaypoint]
                    --Update the details of platoons sent to a particular mex:
                    sMexLocationRef = M27Utilities.ConvertLocationToStringRef(tSortedFinalWaypoints[iCurWaypoint])
                    if tPlatoonRaiderTargets[iPlayerArmyIndex][sMexLocationRef] == nil then tPlatoonRaiderTargets[iPlayerArmyIndex][sMexLocationRef] = 0 end
                    tPlatoonRaiderTargets[iPlayerArmyIndex][sMexLocationRef] = tPlatoonRaiderTargets[iPlayerArmyIndex][sMexLocationRef] + 1
                end
                --Return table contents for debugging:
                if bDebugMessages == true then
                    LOG('About to dump tSortedFinalWaypoints data')
                    LOG(repru(tSortedFinalWaypoints))
                end
            end
        else
            M27Utilities.ErrorHandler('Enemy start position is nil, returning our start position')
            tSortedFinalWaypoints = {}
            tSortedFinalWaypoints[1] = {}
            tSortedFinalWaypoints[1] = M27MapInfo.PlayerStartPoints[iPlayerArmyIndex]
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tSortedFinalWaypoints
end

function SetFactoryRallyPoint(oFactory)
    --Sets the rally point on oFactory
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'SetFactoryRallyPoint'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iDistFromFactory = 5 --Factories are 8x8, midpoint is middle of it so 4 to end of factory
    local aiBrain = oFactory:GetAIBrain()
    if aiBrain == nil then M27Utilities.ErrorHandler('SetFactoryRallyPoint: aiBrain is Nil') end
    local tNearestEnemyStart = M27MapInfo.PlayerStartPoints[GetNearestEnemyStartNumber(aiBrain)]

    local iEnemyX = tNearestEnemyStart[1]
    local iEnemyZ = tNearestEnemyStart[3]
    if bDebugMessages == true then LOG('SetFactoryRallyPoint: iEnemyX='..iEnemyX) end
    local tFactoryPos = oFactory:GetPosition()
    --Set the rally point near to the factory in the direction of the enemy, unless the nearest rally point is closer to the enemy
    local iRallyX = tFactoryPos[1]
    local iRallyZ = tFactoryPos[3]
    if iEnemyX > iRallyX then iRallyX = iRallyX + iDistFromFactory
    else iRallyX = iRallyX - iDistFromFactory end
    if iEnemyZ > iRallyZ then iRallyZ = iRallyZ + iDistFromFactory
    else iRallyZ = iRallyZ - iDistFromFactory end

    --Is this a plateau factory?
    local iFactoryGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oFactory:GetPosition())
    if iFactoryGroup == aiBrain[M27MapInfo.refiOurBasePlateauGroup] then

        local tRallyPoint = {iRallyX, GetTerrainHeight(iRallyX, iRallyZ), iRallyZ}
        local tNearestRallyPoint = GetNearestRallyPoint(aiBrain, tFactoryPos)
        if M27Utilities.GetDistanceBetweenPositions(tRallyPoint, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) > M27Utilities.GetDistanceBetweenPositions(tNearestRallyPoint, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) then
            tRallyPoint = {tNearestRallyPoint[1], tNearestRallyPoint[2], tNearestRallyPoint[3]}
        end
        if bDebugMessages == true then LOG('SetFactoryRallyPoint: tFactoryPos='..tFactoryPos[1]..'-'..tFactoryPos[3]..'; iRallyXZ='..iRallyX..'-'..iRallyZ..'; iEnemyXZ='..iEnemyX..'-'..iEnemyZ) end
        IssueClearFactoryCommands({oFactory})
        IssueFactoryRallyPoint({oFactory}, tRallyPoint)
    else
        if not(oFactory[M27Transport.refiAssignedPlateau]) then oFactory[M27Transport.refiAssignedPlateau] = iFactoryGroup end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end


function GetUpgradeCombatWeighting(sEnhancementRef, iFaction)
    --Returns the combat mass mod to apply to an enhancement
    --Note that enhancements have a visual indicator, so if calling this on an enemy you need to have had visual of the enemy at some point
    --iFaction: 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
    --Obtain using aiBrain:GetFactionIndex()

    local iMinor = 0.4
    local iMajor = 1.2
    local iDeadly = 2
    local iNone = 0
    local iUnknown = 1

    local tEnhancementsCombatMod = {
        {
            --UEF:
            AdvancedEngineering = iMinor, --T2
            DamageStabilization = iMajor, --Nano
            HeavyAntiMatterCannon = iMajor,
            LeftPod = iNone, --Engi
            ResourceAllocation = iNone, --RAS
            RightPod = iNone, --Engi
            Shield = iMajor, --Shield
            ShieldGeneratorField = iMajor, --Shield aoe
            T3Engineering = iMinor, --T3
            TacticalMissile = iNone, --TML
            TacticalNukeMissile = iNone, --Billy
            Teleporter = iNone, --Teleport
        },
        {
            --Aeon:
            AdvancedEngineering = iMinor, --T2
            ChronoDampener = iDeadly, --ChronoDampener
            CrysalisBeam = iMajor, --Range
            EnhancedSensors = iNone, --Sensors
            HeatSink = iMajor, --ROF
            ResourceAllocation = iNone, --RAS
            ResourceAllocationAdvanced = iNone, --RAS lev 2
            Shield = iMajor, --Shield
            ShieldHeavy = iMajor, --Shield lev2
            T3Engineering = iMinor, --T3
            Teleporter = iNone, --Teleport
        },
        {
            --Cybran:
            AdvancedEngineering = iMinor, --T2
            CloakingGenerator = iMinor, --Cloak
            CoolingUpgrade = iMajor, --Gun
            MicrowaveLaserGenerator = iDeadly, --Laser
            NaniteTorpedoTube = iMinor, --Torpedo
            ResourceAllocation = iNone, --RAS
            StealthGenerator = iMinor, --Stealth
            T3Engineering = iMinor, --T3
            Teleporter = iNone, --Teleport
        },
        {
            --Sera:
            AdvancedEngineering = iMinor, --T2
            AdvancedRegenAura = iMajor, --Regen aura lev2
            BlastAttack = iDeadly, --AOE and damage
            DamageStabilization = iMajor, --Nano
            DamageStabilizationAdvanced = iMajor, --Nano lev2
            Missile = iNone, --TML
            RateOfFire = iDeadly, --Gun
            RegenAura = iDeadly, --Regen aura
            ResourceAllocation = iNone, --RAS
            ResourceAllocationAdvanced = iNone, --RAS lev 2
            T3Engineering = iMinor, --T3
            Teleporter = iNone, --Teleport
        }
    }
    if tEnhancementsCombatMod[iFaction][sEnhancementRef] == nil then return iUnknown
    else return tEnhancementsCombatMod[iFaction][sEnhancementRef] end
end

function GetACUCombatMassRating(oACU)
    --Returns the combat adjusted mass value (ignoring current health percentage) of oACU, factoring in any upgrades
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetACUCombatMassRating'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tPossibleUpgrades = {}
    local tPossibleUpgrades = oACU:GetBlueprint().Enhancements
    local aiBrain = oACU:GetAIBrain()
    local iFaction = aiBrain:GetFactionIndex()
    local iCurMassValue
    local iCurMassMod
    local iBaseMassValue = 1200 --Overrides default mass value with one that reflects roughly how many T1 tanks an ACU is equivalent to (is slighlty higher than 20 to allow for possibility enemy has energy storage and overcharge)
    local iTotalMassValue = iBaseMassValue
    if bDebugMessages == true then LOG('GetACUCombatMassRating: tPossibleUpgrades size='..table.getn(tPossibleUpgrades)) end
    if tPossibleUpgrades then
        for iCurUpgrade, tUpgrade in tPossibleUpgrades do
            if oACU:HasEnhancement(iCurUpgrade) then
                iCurMassValue = tUpgrade.BuildCostMass
                iCurMassMod = GetUpgradeCombatWeighting(iCurUpgrade, iFaction)
                iTotalMassValue = iTotalMassValue + iCurMassMod * iCurMassValue
                if bDebugMessages == true then LOG('GetACUCombatMassRating: ACU has enhancement no. '..iCurUpgrade..'; iCurMassValue='..iCurMassValue..'; iCurMassMod='..iCurMassMod) end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iTotalMassValue
end

--v61 - removed the below so everything uses GetUnitMaxGroundRange(oUnit) instead
--[[function GetACUMaxDFRange(oACU)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetACUMaxDFRange'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oBP = oACU:GetBlueprint()
    local tPossibleUpgrades = oBP.Enhancements
    local iRange = 22 --can't figure out easy way to determine this so will just hard-enter
    if tPossibleUpgrades then
        for iCurUpgrade, tUpgrade in tPossibleUpgrades do
            if bDebugMessages == true then LOG(sFunctionRef..': Checking if ACU has upgrade='..iCurUpgrade) end
            if oACU:HasEnhancement(iCurUpgrade) then
                if bDebugMessages == true then LOG(sFunctionRef..': ACU has upgrade='..iCurUpgrade) end
                if tUpgrade.NewMaxRadius then
                    if bDebugMessages == true then LOG(sFunctionRef..': Range of upgrade='..tUpgrade.NewMaxRadius) end
                    if iRange < tUpgrade.NewMaxRadius then iRange = tUpgrade.NewMaxRadius end
                end
            end
        end
    else    --redundancy, e.g. in case have ACU or SACU with no upgrade list
        return M27UnitInfo.GetUnitMaxGroundRange(oUnit)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iRange
end--]]



function GetDFAndT1ArtiUnitMinOrMaxRange(tUnits, iReturnRangeType, bEnemyRange)
    --Works if either sent a table of units or a single unit
    --iReturnRangeType: nil or 0: Return min+Max; 1: Return min only; 2: Return max only
    --Cycles through each unit and then each weapon to determine the minimum range
    --bEnemyRange - if true, then will return longest range for monkeylord intead of main laser range
    local sFunctionRef = 'GetDFAndT1ArtiUnitMinOrMaxRange'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local iCurRange = 0
    local iMinRange = 1000000000
    local iMaxRange = 0
    local tAllUnits = {}
    if tUnits[1]==nil then tAllUnits[1] = tUnits else tAllUnits = tUnits end
    local tUnitBPs = {}
    local iBPCount = 0

    --Override for fatboy (since its an indirect fire unit but can work as an ok direct fire unit)
    if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFatboy, tUnits)) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': Have a fatboy, so setting range to 100') end
        iMaxRange = 100
    end
    local bIncludeT1Arti = false
    for i, oUnit in tAllUnits do
        --if EntityCategoryContains(categories.EXPERIMENTAL, oUnit.UnitId) then bDebugMessages = true end
        if not(oUnit.Dead) then
            if M27Utilities.IsACU(oUnit) == false and not(EntityCategoryContains(categories.SUBCOMMANDER, oUnit.UnitId)) then
                if oUnit.GetBlueprint then
                    if EntityCategoryContains(M27UnitInfo.refCategorySniperBot * categories.SERAPHIM, oUnit.UnitId) and oUnit:GetAIBrain().M27AI then
                        if oUnit[M27UnitInfo.refbSniperRifleEnabled] then iMaxRange = 75 iMinRange = 75
                        else iMaxRange = 65 iMinRange = 65 end
                    elseif not(bEnemyRange) and oUnit.UnitId == 'url0402' then --Monkeylord - go with its main laser not its other weapons
                        iMaxRange = 30 iMinRange = 4
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Have a non-ACU blueprint, adding to the list') end
                        iBPCount = iBPCount + 1
                        tUnitBPs[iBPCount] = oUnit:GetBlueprint()
                        if EntityCategoryContains(categories.TECH1 * categories.ARTILLERY, oUnit.UnitId) then bIncludeT1Arti = true end
                    end
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Have an ACU blueprint, using custom logic to work out DF range') end
                iMaxRange = M27UnitInfo.GetUnitMaxGroundRange(oUnit)
                if bDebugMessages == true then LOG(sFunctionRef..': iMaxRange='..(iMaxRange or 'nil')) end
                --iMaxRange = GetACUMaxDFRange(oUnit)
                iMinRange = iMaxRange
            end
        end
    end
    local tUniqueBPs = {}
    tUniqueBPs = M27Utilities.ConvertTableIntoUniqueList(tUnitBPs)
    for iCurBP, oBP in tUniqueBPs do
        if bDebugMessages == true then LOG(sFunctionRef..': Considering blueprint '..oBP.BlueprintId) end
        if not(oBP.Weapon == nil) then
            for iCurWeapon, oCurWeapon in oBP.Weapon do
                if bDebugMessages == true then LOG(sFunctionRef..': Considering weapon '..(oCurWeapon.DisplayName or 'nil')) end
                if not(oCurWeapon.CannotAttackGround == true) then
                    if not(oCurWeapon.ManualFire == true) then
                        --Exclude indirect fire weapons
                        if not(oCurWeapon.WeaponCategory == 'Artillery' and (not(bIncludeT1Arti) or not(EntityCategoryContains(categories.TECH1 * categories.ARTILLERY, oBP.BlueprintId)))) and not(oCurWeapon.WeaponCategory == 'Missile') and not(oCurWeapon.WeaponCategory == 'Indirect Fire') then
                            iCurRange = oCurWeapon.MaxRadius
                            if iCurRange > iMaxRange then iMaxRange = iCurRange end
                            if iCurRange < iMinRange then iMinRange = iCurRange end
                            if bDebugMessages == true then LOG(sFunctionRef..': iCurRange='..iCurRange..'; iMaxRange='..iMaxRange) end
                        elseif bDebugMessages == true then LOG(sFunctionRef..': Have an indirect fire unit')
                        end
                    elseif bDebugMessages == true then LOG(sFunctionRef..': Manual fire is true')
                    end
                elseif bDebugMessages == true then LOG(sFunctionRef..': CannotAttackGround is true')
                end
            end
        elseif bDebugMessages == true then LOG(sFunctionRef..': Blueprint has no weapon')
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': MinRange='..iMinRange..'; iMaxRange='..iMaxRange) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if iReturnRangeType == 1 then return iMinRange
    elseif iReturnRangeType == 2 then return iMaxRange
    else return iMinRange, iMaxRange
    end
end

function GetUnitMinGroundRange(tUnits)
    return GetDFAndT1ArtiUnitMinOrMaxRange(tUnits, 1)
end
function GetUnitMaxGroundRange(tUnits)
    return GetDFAndT1ArtiUnitMinOrMaxRange(tUnits, 2)
end
function GetUnitMinAndMaxGroundRange(tUnits)
    return GetDFAndT1ArtiUnitMinOrMaxRange(tUnits, 0)
end

function GetUnitSpeedData(tUnits, aiBrain, bNeedToHaveBlipOrVisual, iReturnType, iOptionalSpeedThreshold)
    --iReturnType: 1 = min speed; 2 = max speed; 3 = average speed; 4 = return a table of the units that we know are <= iOptionalSpeedThreshold
    --bNeedToHaveBlipOrVisual: if true, then will check if aiBrain can see the tUnits; defaults to false
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetUnitSpeedData'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bNeedToHaveBlipOrVisual == nil then bNeedToHaveBlipOrVisual = false end
    local tUnitBPs = {}
    local oBlip
    local bCanSeeUnit
    local iValidUnits = 0
    local tSpeedThresholdUnits = {}
    --Get a list of units that can see
    if M27Utilities.IsTableEmpty(tUnits) == true then
        M27Utilities.ErrorHandler('tUnits is empty')
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return nil
    else
        for i, oUnit in tUnits do
            bCanSeeUnit = false
            if bNeedToHaveBlipOrVisual == false then bCanSeeUnit = true
            else
                --Check if need to see the unit:
                bCanSeeUnit = M27Utilities.CanSeeUnit(aiBrain, oUnit)
            end
            if bCanSeeUnit then
                if iReturnType == 4 then
                    if iOptionalSpeedThreshold == nil then M27Utilities.ErrorHandler('iOptionalSpeedThreshold not specified but return type is 4') return nil
                    else
                        if oUnit:GetBlueprint().Physics.MaxSpeed <= iOptionalSpeedThreshold then
                            iValidUnits = iValidUnits + 1
                            tSpeedThresholdUnits[iValidUnits] = {}
                            tSpeedThresholdUnits[iValidUnits] = oUnit
                        end
                        if bDebugMessages == true then LOG('GetUnitSpeedData: iReturnType='..iReturnType..'; iValidUnits='..iValidUnits) end
                    end
                else
                    iValidUnits = iValidUnits + 1
                    tUnitBPs[iValidUnits] = oUnit:GetBlueprint()
                    if bDebugMessages == true then LOG('GetUnitSpeedData: bCanSeeUnit is true; i='..i..'; iReturnType='..iReturnType..'; iValidUnits='..iValidUnits) end
                end
            end
        end
        if iValidUnits == 0 then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return nil
        else
            local tUniqueBPs = {}
            if iReturnType == 3 then tUniqueBPs = tUnitBPs
            else
                tUniqueBPs = M27Utilities.ConvertTableIntoUniqueList(tUnitBPs)
                if bDebugMessages == true then
                    local iSpeedOfFirstValue = tUniqueBPs[1].Physics.MaxSpeed
                    if iSpeedOfFirstValue == nil then iSpeedOfFirstValue = 0 end
                    LOG('Speed of first value in tUniqueBPs='..iSpeedOfFirstValue)
                end
            end
            local iMinSpeed = 10000000
            local iMaxSpeed = 0
            local iCurSpeed
            local iTotalEntries = 0
            local iTotalSpeed = 0
            if iReturnType == 4 then
                --Already done code above
            else
                for iCurBP, oBP in tUniqueBPs do --per above if iReturnType is 3 or 4 then this uses tUnitBPs instead
                    iCurSpeed = oBP.Physics.MaxSpeed
                    if iCurSpeed == nil then iCurSpeed = 0 end

                    if iCurSpeed < iMinSpeed then iMinSpeed = iCurSpeed end
                    if iCurSpeed > iMaxSpeed then iMaxSpeed = iCurSpeed end
                    iTotalSpeed = iTotalSpeed + iCurSpeed
                    iTotalEntries = iTotalEntries + 1
                    if bDebugMessages == true then LOG('GetUnitSpeedData: iCurSpeed='..iCurSpeed..'; iMiNSpeed='..iMinSpeed..';iMaxSpeed='..iMaxSpeed..';iTotalSpeed='..iTotalSpeed) end

                end
            end
            if bDebugMessages == true then LOG('GetUnitSpeedData: iReturnType='..iReturnType..'; iTotalEntries='..iTotalEntries..'; iMinSpeed='..iMinSpeed..'; iMaxSpeed='..iMaxSpeed..'; iTotalSpeed='..iTotalSpeed) end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            if iReturnType == 1 then return iMinSpeed
            elseif iReturnType == 2 then return iMaxSpeed
            elseif iReturnType == 3 then
                if iTotalEntries > 0 then return iTotalSpeed / iTotalEntries
                else return nil
                end
            elseif iReturnType == 4 then
                if iTotalEntries == 0 then return nil
                    else return tSpeedThresholdUnits
                end
            end
        end
    end
end

function GetUnitMinSpeed(tUnits, aiBrain, bVisualCheck)
    --bVisualCheck: True if aiBrain needs to see tUnits to be able to tell their speed
    --Returns nil if can't tell the speed
    return GetUnitSpeedData(tUnits, aiBrain, bVisualCheck, 1)
end

function GetUnitAverageSpeed(tUnits, aiBrain, bVisualCheck)
    --bVisualCheck: True if aiBrain needs to see tUnits to be able to tell their speed
    --Returns nil if can't tell the speed
    return GetUnitSpeedData(tUnits, aiBrain, bVisualCheck, 3)
end

function GetVisibleUnitsOnly(aiBrain, tUnits)
    --Returns a table of tUnits containing only those that have visibility of, or ahve radar blips where know the type of unit
    local sFunctionRef = 'GetVisibleUnitsOnly'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oBlip
    local iArmyIndex = aiBrain:GetArmyIndex()
    local tVisibleUnits = {}
    local iVisibleCount = 0
    for iUnit, oUnit in tUnits do
        if not(oUnit.Dead) and oUnit.GetBlip then
            oBlip = oUnit:GetBlip(iArmyIndex)
            if oBlip then
                if not(oBlip:IsKnownFake(iArmyIndex)) then
                    if oBlip:IsOnRadar(iArmyIndex) then
                        if oBlip:IsSeenEver(iArmyIndex) then
                            iVisibleCount = iVisibleCount + 1
                            tVisibleUnits[iVisibleCount] = oUnit
                        end
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if iVisibleCount == 0 then return nil
    else return tVisibleUnits end
end

function DetermineEnemyScoutSpeed(aiBrain)
    aiBrain[refiEnemyScoutSpeed] = nil --resets incase our nearest enemy has changed
    local iNearestEnemyFaction
    for iCurBrain, oEnemyBrain in ArmyBrains do
        if oEnemyBrain:GetArmyIndex() == GetNearestEnemyIndex(aiBrain) then
            iNearestEnemyFaction = oEnemyBrain:GetFactionIndex()
            break
        end
    end
    if iNearestEnemyFaction and iNearestEnemyFaction <= 4 then --Standard 4 factions
        if not(iNearestEnemyFaction == M27UnitInfo.refFactionSeraphim) then --Seraphim have combat scouts
            local tPossibleBlueprints = EntityCategoryGetUnitList(M27UnitInfo.refCategoryLandScout * M27Utilities.FactionIndexToCategory(iNearestEnemyFaction))
            if M27Utilities.IsTableEmpty(tPossibleBlueprints) == false then
                for _, sUnitID in tPossibleBlueprints do
                    aiBrain[refiEnemyScoutSpeed] = __blueprints[sUnitID].Physics.MaxSpeed
                end
            end
        end
    end
end

function GetCombatThreatRating(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, iMassValueOfBlipsOverride, iSoloBlipMassOverride, bIndirectFireThreatOnly, bJustGetMassValue, bBlueprintThreat, bAntiNavyOnly, bAddAntiNavy, bSubmersibleOnly, bLongRangeThreatOnly)
    --Determines threat rating for tUnits; if bMustBeVisibleToIntelOrSight is true then will assume threat where dont have visual
    --bMustBeVisibleToIntelOrSight - Set to false to get threat information regardless of visibility; automatically done where the unit's owner is equal to aiBrain
    --Threat method: based on mass value * multiplier; 1 if are direct fire, 0.2 if are indirect (0.75 for t1 arti), *2 if are a direct fire structure, *1.5 if are a shield or wall
    --iMassValueOfBlipsOverride - if not nil then will use this instead of coded value for blip threats
    --iSoloBlipMassOverride - similar to massvalue of blips override

    --Note: bMustBeVisibleToIntelOrSight and onwards are all optional, with default values set in the below (within the code for performance reasons)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetCombatThreatRating'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bMustBeVisibleToIntelOrSight == nil then bMustBeVisibleToIntelOrSight = true end
    --IsTableEmpty(tTable, bNotEmptyIfSingleValueNotTable)
    if bDebugMessages == true then LOG(sFunctionRef..': About to check if table is empty. bBlueprintThreat='..tostring(bBlueprintThreat)) end
    if M27Utilities.IsTableEmpty(tUnits, true) == true then
        --if tUnits == nil then
        if bDebugMessages == true then LOG(sFunctionRef..': Warning: tUnits is empty, returning 0') end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return 0
    else
        --if table.getn(tUnits) <= 2 then bDebugMessages = true end
        local iArmyIndex
        local iTotalUnits
        if not(bBlueprintThreat) then
            iArmyIndex = aiBrain:GetArmyIndex()
            iTotalUnits = table.getn(tUnits)
            if bDebugMessages == true then LOG(sFunctionRef..': tUnits has units in it='..table.getn(tUnits)) end
        end
        local oBlip
        local iCurThreat = 0
        local iMassCost = 0
        local iMassMod
        local iTotalThreat = 0
        local bCalcActualThreat = false
        local iHealthPercentage, iMaxHealth
        local bOurUnits = false
        local iHealthFactor --if unit has 40% health, then threat reduced by (1-40%)*iHealthFactor
        local iCurShield, iMaxShield
        local oBP
        local refiMaxHealth = 'M27UnitMaxHealth' --stores max health per blueprint

        local iOtherAdjustFactor = 1

        local iBlipThreat = 54
        if iMassValueOfBlipsOverride then iBlipThreat = iMassValueOfBlipsOverride
        elseif bMustBeVisibleToIntelOrSight then
            if aiBrain[M27Overseer.refiEnemyHighestTechLevel] == 2 then
                iBlipThreat = 250
            elseif aiBrain[M27Overseer.refiEnemyHighestTechLevel] >= 3 then
                iBlipThreat = 500
            end
        end

        local iThreatRef = '1'
        if bIndirectFireThreatOnly then iThreatRef = iThreatRef .. '1' else iThreatRef = iThreatRef .. '0' end
        if bJustGetMassValue then iThreatRef = iThreatRef .. '1' else iThreatRef = iThreatRef .. '0' end
        if bAntiNavyOnly then iThreatRef = iThreatRef .. '1' else iThreatRef = iThreatRef .. '0' end
        if bAddAntiNavy then iThreatRef = iThreatRef .. '1' else iThreatRef = iThreatRef .. '0' end
        if bSubmersibleOnly then iThreatRef = iThreatRef .. '1' else iThreatRef = iThreatRef .. '0' end
        if bLongRangeThreatOnly then iThreatRef = iThreatRef..'1' else iThreatRef = iThreatRef .. '0' end

        if not(tiThreatRefsCalculated[iThreatRef]) then M27Utilities.ErrorHandler('Havent calculated threat values for iThreatRef='..iThreatRef..' refer to CalculateUnitThreatsByType') end

        local iBaseThreat = 0

        if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through relevant units based on iThreatRef='..iThreatRef..'; First unit ID='..(tUnits[1].UnitId or 'nil')..'; bBlueprintThreat='..tostring(bBlueprintThreat or false)) end

        for iUnit, oUnit in tUnits do
            iCurThreat = 0
            iBaseThreat = 0
            bCalcActualThreat = false
            --oBP = nil

            --Get the base threat for the unit
            if M27UnitInfo.IsUnitValid(oUnit) and not(bBlueprintThreat) then
                if oUnit[reftBaseThreat] and oUnit[reftBaseThreat][iThreatRef] then
                    iBaseThreat = oUnit[reftBaseThreat][iThreatRef]
                    if EntityCategoryContains(categories.COMMAND, oUnit.UnitId) and not(bBlueprintThreat) then
                        iBaseThreat = GetACUCombatMassRating(oUnit)
                    end
                    bCalcActualThreat = true
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': About to check if unit is dead') end

                    if not(bMustBeVisibleToIntelOrSight) or not(oUnit.GetBlip) or oUnit[M27UnitInfo.refbTreatAsVisible] then
                        bCalcActualThreat = true
                    elseif oUnit:GetAIBrain() == aiBrain then
                        bOurUnits = true
                        if bDebugMessages == true then LOG(sFunctionRef..': Unit is alive and has same ai brain so will determine actual threat') end
                        bCalcActualThreat = true
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Unit is alive and owned by dif ai brain, and has a GetBlip argument') end
                        --if bMustBeVisibleToIntelOrSight == true and oUnit.GetBlip and not(oUnit[M27UnitInfo.refbTreatAsVisible]) then
                        oBlip = oUnit:GetBlip(iArmyIndex)
                        if oBlip then
                            if not(oBlip:IsKnownFake(iArmyIndex)) then
                                if oBlip:IsOnRadar(iArmyIndex) or oBlip:IsSeenEver(iArmyIndex) then
                                    if oBlip:IsSeenEver(iArmyIndex) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..'; IsSeenEver is true, so calculating actual threat') end
                                        bCalcActualThreat = true
                                    else
                                        --Is it a structure:
                                        oBP = oUnit:GetBlueprint()
                                        if EntityCategoryContains(categories.STRUCTURE, oBP.BlueprintId) then
                                            if bDebugMessages == true then LOG('iUnit='..iUnit..'; IsSeenEver is false; have a structure so will be reduced threat.') end
                                            iBaseThreat = 0
                                        else
                                            --Specific speed checks
                                            if bDebugMessages == true and oUnit.GetBlueprint then LOG('Unit has blueprint with maxpseed='..oUnit:GetBlueprint().Physics.MaxSpeed..';  If dont satisfy speed check, then iSoloBlipMassOverride='..(iSoloBlipMassOverride or 'nil')..'; backup iBlipThreat='..iBlipThreat..'; aiBrain[refiEnemyScoutSpeed]='..(aiBrain[refiEnemyScoutSpeed] or 'nil')) end
                                            if oUnit.GetBlueprint and oBP.Physics.MaxSpeed == 1.9 then
                                                --Unit is same speed as engineer so more likely tahn not its an engineer
                                                iBaseThreat = 5
                                            elseif oUnit.GetBlueprint and oBP.Physics.MaxSpeed == 1.7 then
                                                --Unit is same speed as ACU so more likely than not its an ACU; if gametime is >10m then assume will also know if the ACU is upgraded
                                                iBaseThreat = 800
                                                if EntityCategoryContains(categories.COMMAND, oUnit.UnitId) and GetGameTimeSeconds() >= 720 then iBaseThreat = GetACUCombatMassRating(oUnit) end
                                            elseif oUnit.GetBlueprint and oBP.Physics.MaxSpeed == aiBrain[refiEnemyScoutSpeed] then
                                                iBaseThreat = 10
                                            else
                                                if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..'; IsSeenEver is false; unit isnt a structure so calculating threat based on whether its on its own or not; will be using blip threat override of '..(iMassValueOfBlipsOverride or 54)..' if more than one blip') end
                                                if iTotalUnits <= 1 then iBaseThreat = (iSoloBlipMassOverride or iBlipThreat)
                                                else iBaseThreat = iBlipThreat end
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': oBlip isnt true; iUnit='..iUnit) end
                        end
                    end
                    if bCalcActualThreat then
                        if EntityCategoryContains(categories.COMMAND, oUnit.UnitId) and not(bBlueprintThreat) then
                            iBaseThreat = GetACUCombatMassRating(oUnit)
                        else
                            iBaseThreat = tUnitThreatByIDAndType[oUnit.UnitId][iThreatRef]
                        end
                        if not(iBaseThreat) and not(bBlueprintThreat) then
                            --Not sure why this happens - seems like various blueprints aren't picked up when cycling through __blueprints at the start of the game, e.g. more of an issue if using custom FAF initialisation
                            M27Utilities.ErrorHandler('Dont have any threat rating for threat ref '..iThreatRef..' with unit iD '..oUnit.UnitId..'; will try re-running this for the blueprint', true)
                            iBaseThreat = GetCombatThreatRating(aiBrain, { { ['UnitId'] = oUnit.UnitId } }, false, nil, nil, bIndirectFireThreatOnly, bJustGetMassValue, true, bAntiNavyOnly, bAddAntiNavy, bSubmersibleOnly, bLongRangeThreatOnly)
                            if bDebugMessages == true then LOG(sFunctionRef..': iBaseThreat after update='..(iBaseThreat or 'nil')) end
                        end
                        if not(oUnit[reftBaseThreat]) then oUnit[reftBaseThreat] = {} end
                        oUnit[reftBaseThreat][iThreatRef] = iBaseThreat
                    end
                end
            end


            if bCalcActualThreat then
                --Have got the base threat for this type of unit, now adjust threat for unit health if want to calculate actual threat
                if iBaseThreat > 0 then
                    iCurShield, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oUnit)
                    iMaxHealth = oUnit:GetMaxHealth() + iMaxShield
                    if iMaxHealth and iMaxHealth > 0 then
                        if not(oUnit[refiMaxHealth]) then oUnit[refiMaxHealth] = oUnit:GetBlueprint().Defense.MaxHealth end
                        --if not(oBP) then oBP = oUnit:GetBlueprint() end

                        iOtherAdjustFactor = 1



                        iHealthPercentage = (oUnit:GetHealth() + iCurShield) / iMaxHealth

                        if (oUnit.VetLevel or oUnit.Sync.VeteranLevel) > 0 then
                            iHealthPercentage = iHealthPercentage * ((iMaxHealth) / (oUnit[refiMaxHealth] + iMaxShield) + (oUnit.VetLevel or oUnit.Sync.VeteranLevel) * 0.04)
                            if bDebugMessages == true then LOG(sFunctionRef..': Unit '..(oUnit.UnitId or 'nil')..(M27UnitInfo.GetUnitLifetimeCount(oUnit) or 'nil')..' veterancy level='..(oUnit.VetLevel or oUnit.Sync.VeteranLevel or 'nil')..'; max health='..(iMaxHealth or 'nil')..'; BP max health='..(oBP.Defense.MaxHealth or 'nil')..'; Unit max health='..(oUnit:GetMaxHealth() or 'nil')..'; iMaxShield='..(iMaxShield or 0)..'; iHealthPercentage='..(iHealthPercentage or 'nil')) end
                        end

                        --Calculate max unit health (used elsewhere in code e.g. to calculate energy storage wanted for overcharge)
                        if iMaxHealth > aiBrain[M27Overseer.refiHighestEnemyGroundUnitHealth] and EntityCategoryContains(M27UnitInfo.refCategoryLandCombat - categories.COMMAND - categories.SUBCOMMANDER, oUnit.UnitId) then aiBrain[M27Overseer.refiHighestEnemyGroundUnitHealth] = iMaxHealth end

                        --Reduce threat by health, with the amount depending on if its an ACU and if its an enemy
                        if M27Utilities.IsACU(oUnit) == true then
                            iHealthFactor = iHealthPercentage --threat will be mass * iHealthFactor
                            --iMassCost = GetACUCombatMassRating(oUnit) --have already calculated this earlier
                            if bOurUnits == true then
                                if aiBrain:GetEconomyStored('ENERGY') >= 6000 then iOtherAdjustFactor = 1.1 end --If we can overcharge then we can take on a greater threat
                                if iHealthPercentage < 0.5 then iHealthFactor = iHealthPercentage * iHealthPercentage
                                elseif iHealthPercentage < 0.9 then iHealthFactor = iHealthPercentage * (iHealthPercentage + 0.1) end


                            else iOtherAdjustFactor = 1.15 --Want to send 15% more than what expect to need against enemy ACU given it can gain veterancy
                            end
                        else
                            if bOurUnits == true then iHealthFactor = iHealthPercentage
                            else
                                if iHealthPercentage > 0.25 then
                                    --For enemy damaged units treat them as still ahving high threat, since enemy likely could use them effectively still
                                    if iHealthPercentage >= 1 then iHealthFactor = iHealthPercentage
                                    else
                                        iHealthFactor = iHealthPercentage * (1 + (1 - iHealthPercentage))
                                    end
                                else iHealthFactor = 0.25 end
                            end
                        end
                        if oUnit:GetFractionComplete() <= 0.75 then iOtherAdjustFactor = iOtherAdjustFactor * 0.1 end
                    end
                    iCurThreat = iBaseThreat * iOtherAdjustFactor * iHealthFactor

                end
            else


                --Are we calculating blueprint threat (per code at start of game)?
                if bBlueprintThreat then
                    oBP = __blueprints[oUnit.UnitId]

                    if bDebugMessages == true then LOG(sFunctionRef..': Considering unit with ID='..(oUnit.UnitId or 'nil')..'; bJustGetMassValue='..tostring(bJustGetMassValue or false)) end

                    if bJustGetMassValue == true then iBaseThreat = (oBP.Economy.BuildCostMass or 0)
                    else
                        iMassMod = 0
                        if not(bIndirectFireThreatOnly) then
                            if bAntiNavyOnly or bSubmersibleOnly then
                                iMassMod = 0
                                if (bSubmersibleOnly and (EntityCategoryContains(categories.SUBMERSIBLE, oUnit.UnitId) or oBP.Physics.MotionType == 'RULEUMT_Amphibious')) or (not(bSubmersibleOnly) and bAntiNavyOnly and EntityCategoryContains(categories.ANTINAVY+categories.OVERLAYANTINAVY + M27UnitInfo.refCategoryBattleship, oUnit.UnitId)) then
                                    iMassMod = 0.25 --e.g. for overlayantinavy or submersibles with no attack
                                    if EntityCategoryContains(categories.ANTINAVY, oUnit.UnitId) then
                                        iMassMod = 1
                                    elseif EntityCategoryContains(categories.LAND * categories.ANTINAVY, oUnit.UnitId) then
                                        iMassMod = 0.5 --brick, wagner etc
                                        --UEF units (which are either really bad or good at antinavy)
                                    elseif EntityCategoryContains(categories.UEF * categories.ANTINAVY, oUnit.UnitId) then
                                        --Destroyer and battlecruiser
                                        if EntityCategoryContains(categories.DIRECTFIRE * categories.TECH2, oUnit.UnitId) then iMassMod = 0.25 --valiant
                                        elseif EntityCategoryContains(categories.DIRECTFIRE * categories.TECH3, oUnit.UnitId) then iMassMod = 0.15 --battlecruiser
                                        elseif EntityCategoryContains(categories.TECH2 - categories.DIRECTFIRE, oUnit.UnitId) then iMassMod = 1.2 --Cooper
                                        else
                                            --Unexpected category
                                            iMassMod = 0.5
                                        end
                                    elseif EntityCategoryContains(categories.CYBRAN * categories.ANTINAVY, oUnit.UnitId) then
                                        iMassMod = 0.8
                                    elseif EntityCategoryContains(M27UnitInfo.refCategoryMegalith, oUnit.UnitId) then
                                        iMassMod = 0.5
                                    elseif EntityCategoryContains(M27UnitInfo.refCategoryBattleship, oUnit.UnitId) then
                                        iMassMod = 0.05 --battleships could ground fire, although theyre unlikely to and very inaccurate if the target is moving
                                    end
                                end
                            elseif bLongRangeThreatOnly then
                                if EntityCategoryContains(categories.DIRECTFIRE + categories.INDIRECTFIRE, oUnit.UnitId) then
                                    local iUnitRange = M27UnitInfo.GetBlueprintMaxGroundRange(oBP)
                                    if iUnitRange >= 55 then
                                        if EntityCategoryContains(categories.SILO * categories.TECH3 * categories.SUBMERSIBLE, oUnit.UnitId) then
                                            iMassMod = 0.25 --Missile sub
                                        end
                                    end
                                end
                            else
                                if EntityCategoryContains(categories.DIRECTFIRE, oUnit.UnitId) then
                                    if EntityCategoryContains(M27UnitInfo.refCategoryLandScout, oUnit.UnitId) then
                                        iMassMod = 0.55 --Selen costs 20, so Selen ends up with a threat of 12; engineer logic will ignore threats <10 (so all other lands couts)
                                    elseif EntityCategoryContains(M27UnitInfo.refCategoryCruiserCarrier, oUnit.UnitId) then
                                        if EntityCategoryContains(categories.CYBRAN * categories.TECH2, oUnit.UnitId) then iMassMod = 0.55
                                        elseif EntityCategoryContains(categories.AEON, oUnit.UnitId) then
                                            iMassMod = 0.2 --Aeon cruiser loses vs 2 UEF frigates in sandbox (it kills 1 just before it dies)
                                        else
                                            iMassMod = 0.15 --e.g. uef cruiser - 1 frigate can almost solo it if it dodges the missiles
                                        end
                                    elseif EntityCategoryContains(M27UnitInfo.refCategoryAttackBot * categories.TECH1, oUnit.UnitId) then
                                        iMassMod = 0.85
                                    elseif EntityCategoryContains(categories.BATTLESHIP - M27UnitInfo.refCategoryBattlecruiser, oUnit.UnitId) then
                                        iMassMod = 0.85
                                    elseif EntityCategoryContains(categories.DESTROYER, oUnit.UnitId) then
                                        iMassMod = 0.95
                                    elseif EntityCategoryContains(M27UnitInfo.refCategoryFrigate * categories.CYBRAN, oUnit.UnitId) then
                                        iMassMod = 1.05
                                    else iMassMod = 1
                                    end
                                elseif EntityCategoryContains(M27UnitInfo.refCategoryFatboy, oUnit.UnitId) then
                                    iMassMod = 0.55
                                elseif EntityCategoryContains(categories.SUBCOMMANDER, oUnit.UnitId) then iMassMod = 1 --SACUs dont have directfire category for some reason (they have subcommander and overlaydirectfire)
                                elseif EntityCategoryContains(categories.INDIRECTFIRE * categories.ARTILLERY * categories.STRUCTURE * categories.TECH2, oUnit.UnitId) then iMassMod = 0.1 --Gets doubled as its a structure
                                elseif EntityCategoryContains(categories.INDIRECTFIRE * categories.ARTILLERY * categories.MOBILE * categories.TECH1, oUnit.UnitId) then iMassMod = 0.9
                                elseif EntityCategoryContains(categories.INDIRECTFIRE * categories.ARTILLERY * categories.MOBILE * categories.TECH3, oUnit.UnitId) then iMassMod = 0.5
                                elseif EntityCategoryContains(categories.SHIELD, oUnit.UnitId) then iMassMod = 0.75 --will be doubled for structures
                                elseif EntityCategoryContains(categories.COMMAND, oUnit.UnitId) then iMassMod = 1 --Put in just in case - code was working before this, but dont want it to be affected yb more recenlty added engineer category
                                elseif EntityCategoryContains(categories.ENGINEER,oUnit.UnitId) then iMassMod = 0.1 --Engis can reclaim and capture so can't just e.g. beat with a scout
                                end
                                if bAddAntiNavy and iMassMod < 1 and EntityCategoryContains(categories.ANTINAVY  + categories.OVERLAYANTINAVY, oUnit.UnitId) then
                                    --Increase mass mod for certain units
                                    if iMassMod < 0.25 then iMassMod = 0.25 end
                                    if EntityCategoryContains(categories.SUBMERSIBLE + categories.ANTINAVY, oUnit.UnitId) then
                                        iMassMod = 1 --Subs
                                    elseif EntityCategoryContains(categories.LAND * categories.ANTINAVY, oUnit.UnitId) then
                                        iMassMod = math.max(iMassMod, 0.5) --wagners, bricks etc.
                                    elseif EntityCategoryContains(categories.SUBMERSIBLE * categories.SILO * categories.TECH3, oUnit.UnitId) then
                                        iMassMod = math.max(iMassMod, 0.25) --missile ship
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': iMassMod after considering main direct fire type categories='..iMassMod) end
                            end
                        else
                            if EntityCategoryContains(categories.INDIRECTFIRE, oUnit.UnitId) then
                                if EntityCategoryContains(categories.SILO * categories.TECH3 * categories.SUBMERSIBLE, oUnit.UnitId) then
                                    iMassMod = 0.25 --Missile sub
                                else
                                    iMassMod = 1
                                end
                                if EntityCategoryContains(categories.DIRECTFIRE, oUnit.UnitId) then iMassMod = 0.5 end
                            elseif EntityCategoryContains(categories.ANTIMISSILE, oUnit.UnitId) then iMassMod = 2 --Doubled for structures ontop of this, i.e. want 4xmass of TMD in indirect fire so can overwhelm it
                            elseif EntityCategoryContains(categories.SHIELD, oUnit.UnitId) then iMassMod = 1
                            elseif EntityCategoryContains(M27UnitInfo.refCategoryLongRangeDFLand, oUnit.UnitId) then iMassMod = 0.5
                            end
                        end
                        if EntityCategoryContains(M27UnitInfo.refCategoryStructure, oUnit.UnitId) then
                            iMassMod = iMassMod * 2
                            if bAntiNavyOnly then iMassMod = iMassMod * 1.1 end
                        end
                        iMassCost = (oBP.Economy.BuildCostMass or 0)
                        if bDebugMessages == true then LOG(sFunctionRef..': iMassCost='..(iMassCost or 'nil')..'; iMassMod='..(iMassMod or 'nil')) end
                        iBaseThreat = iMassCost * iMassMod
                    end
                end

                iCurThreat = iBaseThreat
            end

            iTotalThreat = iTotalThreat + iCurThreat
        end
        if bDebugMessages == true then LOG(sFunctionRef..': iTotalThreat='..iTotalThreat) end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return iTotalThreat
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride, bIncludeAirTorpedo, bBlueprintThreat)
    --Threat value depends on inputs:
    --bIncludeAntiAir - will include anti-air on ground units
    --bIncludeNonCombatAir - adds threat value for transports and scouts
    --bIncludeAirTorpedo - Adds threat for torpedo bombers
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetAirThreatLevel'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if (tUnits.UnitId and EntityCategoryContains(categories.EXPERIMENTAL * categories.AIR * categories.AEON, tUnits.UnitId)) or (tUnits[1] and tUnits[1].UnitId and EntityCategoryContains(categories.EXPERIMENTAL * categories.AIR * categories.AEON, tUnits[1].UnitId)) or M27Utilities.IsTableEmpty(tUnits) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.EXPERIMENTAL * categories.AIR * categories.AEON, tUnits)) == false then bDebugMessages = true end
    local iStructureBlipThreat = 0 --Assumes an unrevealed structure has no threat rating
    if bMustBeVisibleToIntelOrSight == nil then bMustBeVisibleToIntelOrSight = true end
    if bIncludeAirTorpedo == nil then bIncludeAirTorpedo = bIncludeAirToGround end
    if bDebugMessages == true then LOG(sFunctionRef..': About to check if table is empty. bIncludeAirToAir='..tostring(bIncludeAirToAir)) end
    --Decide blip threat values:

    --blip values are lower than actual for tech level since unlikely 100% of blips will be the highest tech level unit of that type (and may be a different type altogether)
    local tiAirAABlipThreats
    local tiAirToGroundBlip
    local tiMobileGroundAABlip
    local tiNavyBlipAABlip
    local tBlipThreatByPathingType



    function UpdateBlipThreatToUse()
        --No point doing this calculation unless actually have blips that need their threat calculating
        tiAirAABlipThreats = {50, 100, 300, 300}
        tiAirToGroundBlip = {90, 150, 350, 350}
        tiMobileGroundAABlip = {28, 75, 200, 200}
        tiNavyBlipAABlip = {28, 200, 1000, 1000}
        if iAirBlipThreatOverride == nil then
            if bIncludeAirToGround == true then
                iAirBlipThreatOverride = tiAirToGroundBlip[aiBrain[M27Overseer.refiEnemyHighestTechLevel]]
            elseif bIncludeAirToAir == true then

                if aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][3] > 0 then iAirBlipThreatOverride = tiAirAABlipThreats[3]
                elseif aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][2] > 0 then iAirBlipThreatOverride = tiAirAABlipThreats[2]
                else iAirBlipThreatOverride = tiAirAABlipThreats[1]
                end
            elseif bIncludeNonCombatAir == true then
                iAirBlipThreatOverride = 40 * aiBrain[M27Overseer.refiEnemyHighestTechLevel]
            else iAirBlipThreatOverride = 0
            end
        end
        if iMobileLandBlipThreatOverride == nil then
            if bIncludeGroundToAir == true then
                iMobileLandBlipThreatOverride = tiMobileGroundAABlip[aiBrain[M27Overseer.refiEnemyHighestTechLevel]]
            else iMobileLandBlipThreatOverride = 0
            end
        end
        if iNavyBlipThreatOverride == nil then
            if bIncludeGroundToAir == true then
                iNavyBlipThreatOverride = tiNavyBlipAABlip[aiBrain[M27Overseer.refiEnemyHighestTechLevel]]
            else iNavyBlipThreatOverride = 0
            end
        end
        if iStructureBlipThreatOverride == nil then iStructureBlipThreatOverride = 0 end

        tBlipThreatByPathingType = {}
        tBlipThreatByPathingType[M27UnitInfo.refPathingTypeAir] = iAirBlipThreatOverride
        tBlipThreatByPathingType[M27UnitInfo.refPathingTypeNavy] = iNavyBlipThreatOverride
        tBlipThreatByPathingType[M27UnitInfo.refPathingTypeLand] = iMobileLandBlipThreatOverride
        tBlipThreatByPathingType[M27UnitInfo.refPathingTypeAmphibious] = iMobileLandBlipThreatOverride
        tBlipThreatByPathingType[M27UnitInfo.refPathingTypeNone] = iStructureBlipThreat
    end

    if bDebugMessages == true then LOG(sFunctionRef..': tBlipThreatByPathingType='..repru(tBlipThreatByPathingType)) end

    --Determine the amount that health impacts on threat
    local iHealthFactor = 1 --if unit has 40% health, then threat reduced by (1-40%)*iHealthFactor
    if bIncludeAirToAir == true then
        if not(bBlueprintThreat) and tUnits[1] and tUnits[1].GetAIBrain and not(IsEnemy(tUnits[1]:GetAIBrain():GetArmyIndex(), aiBrain:GetArmyIndex())) then
            iHealthFactor = 0.5
        else
            iHealthFactor = 0.15
        end
    elseif bIncludeAirToGround == true then iHealthFactor = 0.5
    else iHealthFactor = 0 end


    --Check if can see the unit or if are relying on the blip:
    local bUnitFitsDesiredCategory
    if M27Utilities.IsTableEmpty(tUnits, false) == true then
        --if tUnits == nil then
        if bDebugMessages == true then LOG(sFunctionRef..': Warning: tUnits is empty, returning 0') end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return 0
    else
        if table.getn(tUnits) == 0 then
            --Have sent a single unit instead of a table of units - basic workaround:
            tUnits = {tUnits}
            if bDebugMessages == true then LOG(sFunctionRef..': tUnits is a table size 0, so moving it into a table incase its a single unit reference') end
        end
        local iArmyIndex
        if not(bBlueprintThreat) then
            iArmyIndex = aiBrain:GetArmyIndex()
            if bDebugMessages == true then LOG(sFunctionRef..': tUnits has units in it='..table.getn(tUnits)) end
        end
        local oBlip
        local iCurThreat = 0
        local iMassCost = 0
        local iMassMod
        local iTotalThreat = 0
        local bCalcActualThreat = false
        local iHealthPercentage
        local iHealthThreatFactor
        local bOurUnits = false
        local sCurUnitPathing
        local oBP
        local sCurUnitBP
        local iGhettoGunshipAdjust = 0



        local iThreatRef = '2'
        if bIncludeAirToAir then iThreatRef = iThreatRef..'1' else iThreatRef = iThreatRef..'0' end
        if bIncludeGroundToAir then iThreatRef = iThreatRef..'1' else iThreatRef = iThreatRef..'0' end
        if bIncludeAirToGround then iThreatRef = iThreatRef..'1' else iThreatRef = iThreatRef..'0' end
        if bIncludeNonCombatAir then iThreatRef = iThreatRef..'1' else iThreatRef = iThreatRef..'0' end
        if bIncludeAirTorpedo then iThreatRef = iThreatRef..'1' else iThreatRef = iThreatRef..'0' end
        if not(tiThreatRefsCalculated[iThreatRef]) then
            M27Utilities.ErrorHandler('Dont have a thraat ref '..iThreatRef..' So CalculateUnitThreatsByType threat calculation likely wrong')
        end



        local iBaseThreat = 0

        for iUnit, oUnit in tUnits do
            iCurThreat = 0
            iBaseThreat = 0
            iGhettoGunshipAdjust = 0
            bCalcActualThreat = false
            sCurUnitPathing = nil
            if bDebugMessages == true then LOG(sFunctionRef..': About to check if unit is dead') end

            if M27UnitInfo.IsUnitValid(oUnit) then
                --Get the base threat for the unit
                if oUnit[reftBaseThreat] and oUnit[reftBaseThreat][iThreatRef] then
                    iBaseThreat = oUnit[reftBaseThreat][iThreatRef]
                    bCalcActualThreat = true
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': iThreatRef='..iThreatRef..'; Considering threat calculation for oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                    if oUnit:GetAIBrain() == aiBrain then
                        bOurUnits = true
                        if bDebugMessages == true then LOG(sFunctionRef..': Unit is alive and has same ai brain so will determine actual threat') end
                        bCalcActualThreat = true
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Unit is alive and owned by dif ai brain, seeing if we have a blip for it') end
                        if bMustBeVisibleToIntelOrSight == true and oUnit.GetBlip then
                            oBlip = oUnit:GetBlip(iArmyIndex)
                            if oBlip then
                                if not(oBlip:IsKnownFake(iArmyIndex)) then
                                    if oBlip:IsOnRadar(iArmyIndex) or oBlip:IsSeenEver(iArmyIndex) then
                                        if oBlip:IsSeenEver(iArmyIndex) then
                                            if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..'; IsSeenEver is true, so calculating actual threat') end
                                            bCalcActualThreat = true
                                        else
                                            sCurUnitPathing = M27UnitInfo.GetUnitPathingType(oUnit)
                                            if not(tiAirAABlipThreats) then UpdateBlipThreatToUse() end
                                            iBaseThreat = tBlipThreatByPathingType[sCurUnitPathing]
                                            if bDebugMessages == true then LOG(sFunctionRef..': Setting cur threat equal to blip threat; iCurThreat='..iCurThreat) end
                                        end
                                    end
                                end
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': oBlip isnt true; iUnit='..iUnit) end
                            end
                        else
                            --Not using blip so just get actual values (e.g. if want cheating AI or if running this on own units
                            bCalcActualThreat = true
                        end
                    end
                    if bCalcActualThreat then
                        iBaseThreat = tUnitThreatByIDAndType[oUnit.UnitId][iThreatRef]
                        if not(oUnit[reftBaseThreat]) then oUnit[reftBaseThreat] = {} end
                        oUnit[reftBaseThreat][iThreatRef] = iBaseThreat
                    end

                end
            end
            if bCalcActualThreat == true then
                --Adjust threat for health
                if iBaseThreat > 0 then
                    --Increase for cargo of transports
                    if bIncludeAirToGround and EntityCategoryContains(categories.TRANSPORTATION, sCurUnitBP) and oUnit.GetCargo then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have an enemy transport, will get its cargo and see if it contains LABs') end
                        --Include threat of cargo if cargo are LABs
                        local tCargo = oUnit:GetCargo()
                        --Filter to just LABs (note unfortunately it doesnt distinguish between mantis and LABs so matnis get treated as LABs to be prudent)
                        if tCargo then
                            tCargo = EntityCategoryFilterDown(M27UnitInfo.refCategoryAttackBot, tCargo)
                            if M27Utilities.IsTableEmpty(tCargo) == false then
                                --Get mass value ignoring health:
                                --GetCombatThreatRating(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, iMassValueOfBlipsOverride, iSoloBlipMassOverride, bIndirectFireThreatOnly, bJustGetMassValue)
                                iGhettoGunshipAdjust = GetCombatThreatRating(aiBrain, tCargo, true, 35, 35, false, true)
                                if bDebugMessages == true then LOG(sFunctionRef..': Contains LABs so will increase threat by '..iGhettoGunshipAdjust) end
                            end
                        end
                    end


                    --Adjust threat for health
                    iHealthThreatFactor = 1
                    if iHealthFactor > 0 then
                        iHealthPercentage = M27UnitInfo.GetUnitHealthPercent(oUnit)
                        --Assume low health experimental is has more health than it does - e.g. might heal, or might be under construction
                        if iHealthPercentage < 1 and EntityCategoryContains(categories.EXPERIMENTAL, oUnit) and oUnit:GetFractionComplete() >= 0.2 then iHealthPercentage = math.min(1, math.max(0.4, iHealthPercentage * 1.5)) end
                        iHealthThreatFactor = (1 - (1-iHealthPercentage) * iHealthFactor) * iHealthThreatFactor
                    end

                    iCurThreat = iBaseThreat * iHealthThreatFactor + iGhettoGunshipAdjust
                    if bDebugMessages == true then LOG(sFunctionRef..': UnitBP='..(oUnit.UnitId or 'nil')..'; iBaseThreat='..(iBaseThreat or 'nil')..'; iMassMod='..(iMassMod or 'nil')..'iCurThreat='..(iCurThreat or 'nil')) end
                end
            else
                --Calculate the base threat for hte blueprint (start of game)
                if bBlueprintThreat then
                    oBP = __blueprints[oUnit.UnitId]
                    if bDebugMessages == true then LOG(sFunctionRef..': About to calculate threat using actual unit data') end
                    --get actual threat calc
                    iMassMod = 0 --For non-offensive structures
                    --Does the unit contain any of the categories of interest?
                    bUnitFitsDesiredCategory = false
                    --Exclude based on pathing type initially before considering more precisely:
                    sCurUnitPathing = M27UnitInfo.GetUnitPathingType(oUnit)
                    if sCurUnitPathing == M27UnitInfo.refPathingTypeAir then
                        if bIncludeAirToAir == true then bUnitFitsDesiredCategory = true
                        elseif bIncludeAirToGround == true then bUnitFitsDesiredCategory = true
                        elseif bIncludeAirTorpedo == true then bUnitFitsDesiredCategory = true
                        elseif bIncludeNonCombatAir == true then bUnitFitsDesiredCategory = true
                        end
                    elseif bIncludeGroundToAir == true then bUnitFitsDesiredCategory = true end

                    --Is unit still valid? If so then consider its weapons/categories more precisely:
                    if bDebugMessages == true then LOG(sFunctionRef..': bUnitFitsDesiredCategory='..tostring(bUnitFitsDesiredCategory)..'; bIncludeAirToAir='..tostring(bIncludeAirToAir)..'; bIncludeAirToGround='..tostring(bIncludeAirToGround)..'; iThreatRef='..iThreatRef) end
                    if bUnitFitsDesiredCategory == true then

                        sCurUnitBP = oBP.BlueprintId

                        --Get values for air units:
                        if sCurUnitPathing == M27UnitInfo.refPathingTypeAir then
                            if bIncludeNonCombatAir == true then
                                iMassMod = 1

                            else
                                if bIncludeAirToGround == true then
                                    if EntityCategoryContains(categories.BOMBER + categories.GROUNDATTACK + categories.OVERLAYDIRECTFIRE, sCurUnitBP) == true then iMassMod = 1
                                    elseif EntityCategoryContains(categories.TRANSPORTATION, sCurUnitBP) then iMassMod = 1 --might be a ghetto
                                    end
                                end
                                if bIncludeAirTorpedo == true and EntityCategoryContains(categories.ANTINAVY, sCurUnitBP) == true then iMassMod = 1 end
                                if bDebugMessages == true then LOG(sFunctionRef..': bIncludeAirTorpedo='..tostring(bIncludeAirTorpedo)..'; iMassMod='..iMassMod) end

                                if bIncludeAirToAir == true and iMassMod < 1 then
                                    if bDebugMessages == true then LOG(sFunctionRef..': bIncludeAirToAir='..tostring(bIncludeAirToAir)..'; iMassMod='..iMassMod..'; does BP contain airaa category='..tostring(EntityCategoryContains(categories.ANTIAIR * categories.AIR, sCurUnitBP))) end
                                    if EntityCategoryContains(categories.ANTIAIR * categories.AIR, sCurUnitBP) == true then
                                        iMassMod = 1
                                        if EntityCategoryContains(categories.BOMBER + categories.GROUNDATTACK + categories.DIRECTFIRE, sCurUnitBP) then
                                            iMassMod = 0.75 --e.g. t2 bombers
                                            --Manual adjustments for units with good AA that also have direct fire
                                            if sCurUnitBP == 'xaa0305' then iMassMod = 0.8 --Restorer
                                            elseif sCurUnitBP == 'xea0306' then iMassMod = 0.7 --Continental
                                            elseif sCurUnitBP == 'uaa0310' then iMassMod = 0.55 --Czar
                                            elseif sCurUnitBP == 'xsa0402' then iMassMod = 0.3 --Sera experi bomber
                                            end
                                        end
                                        if bDebugMessages == true then LOG(sFunctionRef..': sCurUnitBP='..sCurUnitBP..': Mass mod after checking AirAA value='..iMassMod) end
                                    elseif EntityCategoryContains(categories.OVERLAYANTIAIR * categories.AIR, sCurUnitBP) then
                                        iMassMod = 0.05
                                    end
                                end
                            end
                        else
                            --Non-air pathing type
                            if bDebugMessages == true then LOG(sFunctionRef..': Unit doesnt have air pathing. bIncludeGroundToAir='..tostring(bIncludeGroundToAir)) end
                            if bIncludeGroundToAir == true then
                                if EntityCategoryContains(categories.ANTIAIR, sCurUnitBP) == true then
                                    iMassMod = 1 --Cruisers and T3 aircraft carriers have antiair as well as overlay antiair
                                    if sCurUnitBP == 'urs0103' or EntityCategoryContains(categories.EXPERIMENTAL, sCurUnitBP) then iMassMod = 0.1 end --Cybran frigate and land experimentals misclassified as anti-air
                                elseif EntityCategoryContains(categories.OVERLAYANTIAIR, sCurUnitBP) == true then
                                    iMassMod = 0.05
                                    if sCurUnitBP == 'ues0401' then iMassMod = 1 end --atlantis misclassifiefd as not anti-air
                                    if EntityCategoryContains(categories.FRIGATE, sCurUnitBP) then iMassMod = 0.18 end
                                end
                            end
                        end
                        --Increase AA threat for structures
                        if bIncludeGroundToAir == true and sCurUnitPathing == M27UnitInfo.refPathingTypeNone then iMassMod = iMassMod * 2 end
                    end

                    iMassCost = (oBP.Economy.BuildCostMass or 0)
                    if bDebugMessages == true then LOG(sFunctionRef..': iMassCost='..(iMassCost or 'nil')..'; iMassMod='..(iMassMod or 'nil')) end
                    iBaseThreat = iMassCost * iMassMod
                end
                iCurThreat = iBaseThreat
            end

            iTotalThreat = iTotalThreat + iCurThreat
            if bDebugMessages == true then LOG(sFunctionRef..': Unit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iCurThreat='..iCurThreat..'; iTotalThreat='..iTotalThreat) end
        end


        if bDebugMessages == true then LOG(sFunctionRef..': End of code, iTotalThreat='..iTotalThreat) end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return iTotalThreat
    end
    M27Utilities.ErrorHandler('Code shouldve returend before now, will return 0')
    return 0
end

function CategoriesInVisibleUnits(aiBrain, tEnemyUnits, category, iReturnType)
    --iReturnType1 - returns true if contains category;
    --2 = no. of units meeting the conditions
    --3 = table of units meeting the conditions
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local tIndirectUnits = EntityCategoryFilterDown(category, tEnemyUnits)
    local bIsSeen
    local iValidCount = 0
    local tValidUnits = {}
    for iUnit, oUnit in tIndirectUnits do
        bIsSeen = M27Utilities.CanSeeUnit(aiBrain, oUnit)
        if bIsSeen == true then
            if bDebugMessages == true then LOG('CategoriesInVisibleUnits: iUnit='..iUnit..'; is seen; ID='..oUnit.UnitId) end
            if iReturnType == 1 then return true
            else
                iValidCount = iValidCount + 1
                if iReturnType == 3 then tValidUnits[iValidCount] = oUnit end
            end
        end
    end
    if iReturnType == 1 then return false
    elseif iReturnType == 2 then return iValidCount
    elseif iReturnType == 3 then return tValidUnits
    else M27Utilities.ErrorHandler('iReturnType not recognised') return nil
    end

end

function IsUnitIdle(oUnit, bGuardWithFocusUnitIsIdle, bGuardWithNoFocusUnitIsIdle, bMovingUnassignedEngiIsIdle, bDontIncreaseIdleCount)
    --Cycles through various unit states that could indicate the unit is idle
    --if bGuardIsIdle == true then will treat a unit that is guarding/assisting as being idle
    --bDontIncreaseIdleCount - optional - if set to true then wont increase the idle count for determining if a unit is idle; e.g. if debugging, then set to true to avoid changing what happens
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsUnitIdle'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit) == 'url01053' then bDebugMessages = true end

    local bIsIdle
    local iIdleCountThreshold = 1 --Number of times the unit must have been idle to trigger (its increased by 1 this cycle, so 1 effectively means no previous times)
    --Note this is increased for engineers with an action to build a T3 mex
    --if EntityCategoryContains(M27UnitInfo.refCategoryEngineer, oUnit.UnitId) and (M27EngineerOverseer.GetEngineerUniqueCount(oUnit) == 59) then bDebugMessages = true end

    if bDebugMessages == true then LOG(sFunctionRef..': Checking if unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' is idle; unit state='..(GetUnitState(oUnit) or 'nil')) end
    if oUnit[M27UnitInfo.refbSpecialMicroActive] then bIsIdle = false
    else

        if bGuardWithFocusUnitIsIdle == nil then bGuardWithFocusUnitIsIdle = false end
        if bGuardWithNoFocusUnitIsIdle == nil then bGuardWithNoFocusUnitIsIdle = true end
        if bMovingUnassignedEngiIsIdle == nil then bMovingUnassignedEngiIsIdle = false end
        if oUnit:IsUnitState('Building') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Building') end
            --If target is flagged for reclaim then treat as idle
            bIsIdle = false
            if oUnit.GetFocusUnit and oUnit:GetFocusUnit() and oUnit:GetFocusUnit()[M27EconomyOverseer.refbWillReclaimUnit] then bIsIdle = true end
        elseif oUnit:IsUnitState('Moving') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Moving') end
            if bMovingUnassignedEngiIsIdle == true and not(oUnit[M27EngineerOverseer.refiEngineerCurrentAction]) and EntityCategoryContains(M27UnitInfo.refCategoryEngineer, oUnit.UnitId) then
                bIsIdle = true
            else
                bIsIdle = false
            end
        elseif oUnit:IsUnitState('Attacking') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Attacking') end
            bIsIdle = false
        elseif oUnit:IsUnitState('Upgrading') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Upgrading') end
            bIsIdle = false
        elseif oUnit:IsUnitState('Teleporting') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Teleporting') end
            bIsIdle = false
        elseif oUnit:IsUnitState('Enhancing') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Enhancing') end
            bIsIdle = false
        elseif oUnit:IsUnitState('Attached') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Attached') end
            bIsIdle = false
        elseif oUnit:IsUnitState('Guarding') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is guarding; bGuardIsIdle='..tostring(bGuardWithFocusUnitIsIdle)) end
            local bHaveValidFocusUnit = false
            local oGuardedUnit
            if oUnit.GetFocusUnit then
                oGuardedUnit = oUnit:GetFocusUnit()
                if oGuardedUnit and not(oGuardedUnit.Dead) and oGuardedUnit.GetUnitId and not(oGuardedUnit[M27EconomyOverseer.refbWillReclaimUnit]) then
                    bHaveValidFocusUnit = true
                end
            end

            --Engineer specific - treat unit as idle if it is assisting a factory or silo unit that isnt doing anything
            if not(bGuardWithFocusUnitIsIdle) and bHaveValidFocusUnit and EntityCategoryContains(M27UnitInfo.refCategoryEngineer, oUnit.UnitId) and EntityCategoryContains(M27UnitInfo.refCategorySML + M27UnitInfo.refCategorySMD + M27UnitInfo.refCategoryTML + M27UnitInfo.refCategoryAllFactories + M27UnitInfo.refCategoryQuantumGateway, oGuardedUnit.UnitId) then
                --Is the focus unit idle?
                if (oGuardedUnit.GetWorkProgress and oGuardedUnit:GetWorkProgress() > 0) or oGuardedUnit:GetFractionComplete() < 1 then
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    return true
                else
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    return false
                end
            end


            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            if bHaveValidFocusUnit == true then
                return bGuardWithFocusUnitIsIdle
            else return bGuardWithNoFocusUnitIsIdle
            end
        elseif oUnit:IsUnitState('Repairing') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Repairing') end
            bIsIdle = false
            if oUnit.GetFocusUnit and oUnit:GetFocusUnit() and oUnit:GetFocusUnit()[M27EconomyOverseer.refbWillReclaimUnit] then bIsIdle = true end
        elseif oUnit:IsUnitState('Busy') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Busy') end
            bIsIdle = false
        elseif oUnit:IsUnitState('Patrolling') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Patrolling') end
            bIsIdle = false
        elseif oUnit:IsUnitState('Reclaiming') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Reclaiming') end
            bIsIdle = false
        elseif oUnit:IsUnitState('Capturing') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Capturing') end
            bIsIdle = false
        else
            iIdleCountThreshold = 2 --i.e. need to have been idle at least this-1 times before
            --Sometimes e.g. for an engi if it finishes its current construction there's a period where unit state is nil, but it still has queued up actions
            --However, when its finished everything it can still have a position close to it (but not identical) in its navigator
            --Below attempts to distinguish between the two
            if oUnit.GetNavigator then
                local oNavigator = oUnit:GetNavigator()
                local tUnitPos = oUnit:GetPosition()
                local iDistanceToNotBeIdle = 3
                if oNavigator.GetCurrentTargetPos then
                    local tCurTargetPos = oNavigator:GetCurrentTargetPos()
                    if bDebugMessages == true then LOG(sFunctionRef..': UnitPos='..repru(tUnitPos)..'; targetpos='..repru(tCurTargetPos)) end
                    if M27Utilities.IsTableEmpty(oNavigator:GetCurrentTargetPos()) == false then
                        if math.abs(tCurTargetPos[1] - tUnitPos[1]) >= iDistanceToNotBeIdle or math.abs(tCurTargetPos[3] - tUnitPos[3]) >= iDistanceToNotBeIdle then
                            bIsIdle = false
                        end
                    end
                    if oNavigator.GetGoalPos then
                        local tCurGoalPos = oNavigator:GetGoalPos()
                        if bDebugMessages == true then LOG(sFunctionRef..': UnitPos='..repru(tUnitPos)..'; GoalPos='..repru(tCurGoalPos)) end
                        if M27Utilities.IsTableEmpty(oNavigator:GetGoalPos()) == false then
                            if math.abs(tCurGoalPos[1] - tUnitPos[1]) >= iDistanceToNotBeIdle or math.abs(tCurGoalPos[3] - tUnitPos[3]) >= iDistanceToNotBeIdle then
                                bIsIdle = false
                            end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': After checking navigator and goal positions theyre not far enough away so unit treated as being idle') end
                end
            end
            bIsIdle = true
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': bIsIdle='..tostring(bIsIdle)..'; if true then will check against idle count first') end
    if not(bIsIdle) then
        oUnit[refiIdleCount] = 0
        if bDebugMessages == true then LOG(sFunctionRef..': Unit not idle so returning false') end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return false
    else
        if not(bDontIncreaseIdleCount) then oUnit[refiIdleCount] = (oUnit[refiIdleCount] or 0) + 1 end
        if oUnit[M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionBuildT3MexOverT2 and not(oUnit[M27EngineerOverseer.rebToldToStartBuildingT3Mex]) then
            iIdleCountThreshold = 20 --can take a long time to start building if units nearby blocking the mex or if pathfinding issues due to units; was set to 60 but have changed reassignment so it should typically only happen once every 4 seconds (made 20 as compromise as sometimes will be more often)
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Unit appears idle, but checking against idle threshold. Unit idle count='..(oUnit[refiIdleCount] or 'nil')..'; Idle threshold='..iIdleCountThreshold..'; if >= idle threshold then will return true. Engineer action (nil for non engineers)='..(oUnit[M27EngineerOverseer.refiEngineerCurrentAction] or 'nil')) end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        if oUnit[refiIdleCount] >=  iIdleCountThreshold then
            return true
        else return false
        end
    end
end

function GetReclaimDetourLocation(tCurStartPosition, tEndPosition, iMaxDetourAbsolute, iMinDistanceFromStartAndEnd)
    --Returns either nil or a reclaim location that doesnt represent a big detour
    --WARNING: If using this with MoveNearConstruction afterwards then need to specify iMinDistanceFromStartAndEnd, or else risk infinite loop
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetReclaimDetourLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    if iMinDistanceFromStartAndEnd == nil then iMinDistanceFromStartAndEnd = 0 end
    local iAngleToTarget = M27Utilities.GetAngleFromAToB(tCurStartPosition, tEndPosition)
    local tCurPointAlongLine
    local iBaseDistanceInterval = math.max(M27MapInfo.iReclaimSegmentSizeX, M27MapInfo.iReclaimSegmentSizeZ, iMaxDetourAbsolute)
    local iDistanceFromStartToEnd = M27Utilities.GetDistanceBetweenPositions(tCurStartPosition, tEndPosition)
    local iMaxPointsAlongLine = math.ceil(iDistanceFromStartToEnd / iBaseDistanceInterval)
    local iMaxSegmentRange = math.ceil(iMaxDetourAbsolute / math.min(M27MapInfo.iReclaimSegmentSizeX, M27MapInfo.iReclaimSegmentSizeZ))
    local iBaseSegmentX, iBaseSegmentZ
    local iClosestDetour = 10000
    local tClosestDetour
    local iBasePathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tCurStartPosition)
    local tPossibleDetour
    local iDistanceFromStartToDetour, iDistanceFromDetourToEnd
    local iStartSegmentX, iStartSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tCurStartPosition)
    local iEndSegmentX, iEndSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tEndPosition)

    tCurPointAlongLine = {tCurStartPosition[1], tCurStartPosition[2], tCurStartPosition[3]}
    for iCurPointAlongLine = 1, iMaxPointsAlongLine do
        if bDebugMessages == true then LOG(sFunctionRef..': iCurPointAlongLine='..iCurPointAlongLine..'; iMaxPointsALongLine='..iMaxPointsAlongLine..'; iAngleToTarget='..iAngleToTarget..'; iBaseDistanceInterval='..iBaseDistanceInterval..'; iMaxSegmentRange='..(iMaxSegmentRange or 'nil')) end
        tCurPointAlongLine = M27Utilities.MoveInDirection(tCurPointAlongLine, iAngleToTarget, iBaseDistanceInterval)
        if bDebugMessages == true then LOG(sFunctionRef..': tCurPointAlongLine='..repru((tCurPointAlongLine or {'nil'}))) end
        iBaseSegmentX, iBaseSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tCurPointAlongLine)
        if bDebugMessages == true then LOG(sFunctionRef..': iBaseSegmentX='..iBaseSegmentX..'; iBaseSegmentZ='..iBaseSegmentZ) end
        for iAdjX = -iMaxSegmentRange, iMaxSegmentRange do
            for iAdjZ = -iMaxSegmentRange, iMaxSegmentRange do
                if bDebugMessages == true then LOG(sFunctionRef..': iAdjX='..iAdjX..'; iAdjZ='..iAdjZ) end
                --Different segment to the start and end positions?
                if not({iBaseSegmentX + iAdjX, iBaseSegmentZ + iAdjZ} == {iStartSegmentX, iStartSegmentZ}) and not({iBaseSegmentX + iAdjX, iBaseSegmentZ + iAdjZ} == {iEndSegmentX, iEndSegmentZ}) then

                    --Has at least 30 mass with at least a 7.5+ reclaim item in it?
                    if M27MapInfo.tReclaimAreas[iBaseSegmentX + iAdjX] and M27MapInfo.tReclaimAreas[iBaseSegmentX + iAdjX][iBaseSegmentZ + iAdjZ] and (M27MapInfo.tReclaimAreas[iBaseSegmentX + iAdjX][iBaseSegmentZ + iAdjZ][M27MapInfo.refReclaimTotalMass] or 0) >= 30 and (M27MapInfo.tReclaimAreas[iBaseSegmentX + iAdjX][iBaseSegmentZ + iAdjZ][M27MapInfo.refReclaimHighestIndividualReclaim] or 0) >= 7.5 then
                        --In same pathing group?
                        tPossibleDetour = M27MapInfo.GetReclaimLocationFromSegment(iBaseSegmentX + iAdjX, iBaseSegmentZ + iAdjZ)
                        if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tPossibleDetour) == iBasePathingGroup then
                            --Closer to destination than the start is?
                            iDistanceFromStartToDetour = M27Utilities.GetDistanceBetweenPositions(tCurStartPosition, tPossibleDetour)
                            iDistanceFromDetourToEnd = M27Utilities.GetDistanceBetweenPositions(tPossibleDetour, tEndPosition)
                            if iDistanceFromDetourToEnd < iDistanceFromStartToEnd then
                                --Less than 30% detour and < absolute detour?
                                if iDistanceFromStartToDetour + iDistanceFromDetourToEnd - iDistanceFromStartToEnd <= iMaxDetourAbsolute and (iDistanceFromStartToDetour + iDistanceFromDetourToEnd) / iDistanceFromStartToEnd < 1.3 then
                                    if iDistanceFromDetourToEnd + iDistanceFromStartToDetour < iClosestDetour then
                                        if iDistanceFromDetourToEnd >= iMinDistanceFromStartAndEnd and iDistanceFromStartToDetour >= iMinDistanceFromStartAndEnd then
                                            iClosestDetour = iDistanceFromDetourToEnd + iDistanceFromStartToDetour
                                            tClosestDetour = tPossibleDetour
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if tClosestDetour then
            break
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code; tClosestDetour='..repru((tClosestDetour or {'nil'}))) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tClosestDetour
end

function AddMexesAndReclaimToMovementPath(oPathingUnit, tFinalDestination, iPassingSearchRadius)
    --Considers mex locations and reclaim that are near the path that would take to reach tFinalDestination
    --iPassingSearchRadius - defaults to build distance+10 if not specified

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AddMexesAndReclaimToMovementPath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Avoid infinite loop caused by dividing by 0 later on - check reclaim segment size has been determined
    if (M27MapInfo.iReclaimSegmentSizeX or 0) == 0 then --Not yet determined reclaim sizes
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return {tFinalDestination}
    else

        --Config variables
        local iMinReclaimToConsider = 29 --Will consider a detour if reclaim is more than this

        --Other variables:

        local oUnitBP = oPathingUnit:GetBlueprint()
        local iBuildDistance = oUnitBP.Economy.MaxBuildDistance
        local iUnitSpeed = oUnitBP.Physics.MaxSpeed
        local aiBrain = oPathingUnit:GetAIBrain()
      --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Start of code') end
        if iBuildDistance == nil then iBuildDistance = 5 end
        if iPassingSearchRadius == nil then iPassingSearchRadius = iBuildDistance + 10 end --look for mexes and reclaim within this distance of the path
        local iSearchIntervals = iPassingSearchRadius * 0.5 --will look every x points along the path from start to end to identify places where want to stop off on the way
        local tCurStartPosition = {}
        tCurStartPosition = oPathingUnit:GetPosition()
        local iMaxLoopCount = 200
        local iCurLoopCount = 0
        local tAllTargetLocations = {}
        local iPassingLocationCount = 0
        local bHavePassThrough
        --Get shortlist of mexes so not having to cycle through every mex on the map at every point
        local tMexShortlist = {}
        local iPossibleMex = 0
        local iDestinationSegmentX, iDestinationSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tFinalDestination)
        local sPathing = M27UnitInfo.GetUnitPathingType(oPathingUnit)
        if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
        local iACUSegmentX, iACUSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tCurStartPosition)
        local iUnitPathGroup = M27MapInfo.InSameSegmentGroup(oPathingUnit, tCurStartPosition, true)
        local iReclaimLoopCount
        local iReclaimSegmentBaseX, iReclaimSegmentBaseZ, iHighestReclaimValue
        local tBestReclaimSegmentXZ = {}
        local iReclaimSegmentSearchSize = math.ceil(iPassingSearchRadius / M27MapInfo.iReclaimSegmentSizeX)
      --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to loop through mexes in pathing group') end
        if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitPathGroup]) == false then
            for iCurMex, tMexLocation in M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitPathGroup] do
                local iSegmentX, iSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tMexLocation)
                if iSegmentX <= math.max(iDestinationSegmentX, iACUSegmentX) then
                    if iSegmentX >= math.min(iDestinationSegmentX, iACUSegmentX) then
                        if iSegmentZ <= math.max(iDestinationSegmentZ, iACUSegmentZ) then
                            if iSegmentZ >= math.min(iDestinationSegmentZ, iACUSegmentZ) then
                                --Ignore if we or an ally already has a mex near here (i.e. below will say its unclaimed if enemy built there or noone built there)
                                if M27Conditions.IsMexOrHydroUnclaimed(aiBrain, tMexLocation, true, true, false, true) then
                                    iPossibleMex = iPossibleMex + 1
                                    tMexShortlist[iPossibleMex] = {}
                                    tMexShortlist[iPossibleMex] = tMexLocation
                                end
                            end
                        end
                    end
                end
            end
        end
        local iMinDistanceToMex, iCurDistanceToMex
        local tClosestMex, bFoundPassThroughMex
        local iCurDistanceToEnd = M27Utilities.GetDistanceBetweenPositions(tCurStartPosition, tFinalDestination)
        local tPassThroughLocation, iTempDistanceToEnd
        local tLastPassThroughPosition = {}
        local tHighestValidReclaim, ReclaimRectangle, tReclaimables, iMassValue
        local iTempDistanceToCurStart
      --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': just before while loop') end
        while iCurDistanceToEnd > iSearchIntervals do
            bHavePassThrough = false
            iCurLoopCount = iCurLoopCount + 1
            if iCurLoopCount > iMaxLoopCount then
                LOG(sFunctionRef..': LIKELY ERROR - Infinite loop count exceeded')
                break
            end
            tPassThroughLocation = {}
            --Search for nearby mex within shortlist
            if iPossibleMex > 0 then
                iMinDistanceToMex = 10000
                tClosestMex = {}
                bFoundPassThroughMex = false
                if bDebugMessages == true then LOG(sFunctionRef..': tMexShortlist='..repru(tMexShortlist)..'; iPassingLocationCount='..iPassingLocationCount) end
                for iCurMex, tMexLocation in tMexShortlist do
                    if not(tLastPassThroughPosition == tMexLocation) then
                        if M27Utilities.IsTableEmpty(tMexLocation) == false then
                            --Check it's not close to our current position
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': iCurMex='..iCurMex..'; tMexLocation='..repru(tMexLocation)..'; tCurStartPosition='..repru(tCurStartPosition))
                                if tLastPassThroughPosition == nil then LOG(sFunctionRef..'; tLastPassThroughPosition is nil')
                                else LOG(sFunctionRef..': tLastPassThroughPosition='..repru(tLastPassThroughPosition))
                                end
                            end
                            iCurDistanceToMex = M27Utilities.GetDistanceBetweenPositions(tMexLocation, tCurStartPosition)
                            if iCurDistanceToMex <= iPassingSearchRadius then
                                if iCurDistanceToMex < iMinDistanceToMex then
                                    iMinDistanceToMex = iCurDistanceToMex
                                    tClosestMex = tMexLocation
                                    bHavePassThrough = true
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have at least 1 passthrough mex, current tClosestMex='..repru(tClosestMex)) end
                                end
                            end
                        end
                    end
                    --Add closest mex:
                    if bHavePassThrough == true then
                        tPassThroughLocation = tClosestMex
                    end
                end
            end


            --Search for nearby reclaim as a detour (if no mexes were found)
            if bHavePassThrough == false then
                iHighestReclaimValue = 0
                iReclaimSegmentBaseX, iReclaimSegmentBaseZ = M27MapInfo.GetReclaimSegmentsFromLocation(tCurStartPosition)

                for iReclaimSegmentX = iReclaimSegmentBaseX - iReclaimSegmentSearchSize, iReclaimSegmentBaseX + iReclaimSegmentSearchSize do
                    for iReclaimSegmentZ = iReclaimSegmentBaseZ - iReclaimSegmentSearchSize, iReclaimSegmentBaseZ + iReclaimSegmentSearchSize do
                        if (M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][M27MapInfo.refReclaimTotalMass] or 0) > iMinReclaimToConsider then
                            if (M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][M27MapInfo.refReclaimHighestIndividualReclaim] or 0) > iHighestReclaimValue then
                                iHighestReclaimValue = (M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][M27MapInfo.refReclaimHighestIndividualReclaim] or 0)
                                tBestReclaimSegmentXZ = {iReclaimSegmentX, iReclaimSegmentZ}
                            end
                        end
                    end
                end
                if iHighestReclaimValue > 0 then
                    bHavePassThrough = true
                    tPassThroughLocation = M27MapInfo.GetReclaimLocationFromSegment(tBestReclaimSegmentXZ[1], tBestReclaimSegmentXZ[2])
                end
            end


            --Update the start position if have added a via point:
          --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': just before updating start position') end
            if bHavePassThrough == true then
                --Check won't be moving further away from the end destination than we currently are:
                iTempDistanceToEnd = M27Utilities.GetDistanceBetweenPositions(tPassThroughLocation, tFinalDestination)
                if iTempDistanceToEnd < iCurDistanceToEnd then
                    iTempDistanceToCurStart = M27Utilities.GetDistanceBetweenPositions(tPassThroughLocation, tCurStartPosition)
                    if iTempDistanceToCurStart <= iTempDistanceToEnd then
                        tLastPassThroughPosition = tPassThroughLocation --needed so dont consider this in next loop (given aren't moving all the way to the target)

                        iPassingLocationCount = iPassingLocationCount + 1
                        tAllTargetLocations[iPassingLocationCount] = {}
                        --Dont move all the way to the target, just close enough that should spend at least 1 second in its build range

                        if bDebugMessages == true then LOG(sFunctionRef..': Have a pass-through location, iPassingLocationCount='..iPassingLocationCount..'; location='..repru(tPassThroughLocation)..'; about to get position to move near it for construction') end
                        --MoveNearConstruction(aiBrain, oBuilder, tLocation, sBlueprintID, iBuildDistanceMod, bReturnMovePathInstead, bUpdatePlatoonMovePath, bReturnNilIfAlreadyMovingNearConstruction)
                        tAllTargetLocations[iPassingLocationCount] = M27PlatoonUtilities.MoveNearConstruction(aiBrain, oPathingUnit, tPassThroughLocation, nil, -iUnitSpeed, true, false, false)
                        if bDebugMessages == true then LOG(sFunctionRef..': Move position='..repru(tAllTargetLocations[iPassingLocationCount])) end
                        tCurStartPosition = tAllTargetLocations[iPassingLocationCount]
                        if bDebugMessages == true then LOG(sFunctionRef..': CurStartPosition='..repru(tCurStartPosition)) end
                        iCurDistanceToEnd = iTempDistanceToEnd
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Have no passthrough location') end
                        bHavePassThrough = false
                    end
                else bHavePassThrough = false
                end

                --Check for reclaim alone a line from the start to the next position on the path
                iReclaimLoopCount = 0
                if bDebugMessages == true then LOG(sFunctionRef..': Have pass through location, tAllTargetLocations[iPassingLocationCount]='..repru(tAllTargetLocations[iPassingLocationCount])..'; tCurStartPosition='..repru(tCurStartPosition)..'; about to add any reclaim along the path') end
                while bHavePassThrough == true do
                    iReclaimLoopCount = iReclaimLoopCount + 1
                    if bDebugMessages == true then LOG(sFunctionRef..': Start of loop for passthrough; iReclaimLoopCount='..iReclaimLoopCount) end
                    if iReclaimLoopCount > iMaxLoopCount then
                        M27Utilities.ErrorHandler('Infinite loop')
                        bHavePassThrough = false
                        break
                    else
                        local tCurPassThrough = {tPassThroughLocation[1], tPassThroughLocation[2], tPassThroughLocation[3]}
                        tPassThroughLocation = GetReclaimDetourLocation(tCurStartPosition, tCurPassThrough, iPassingSearchRadius, iBuildDistance)
                        if bDebugMessages == true then LOG(sFunctionRef..'; iReclaimLoopCount='..iReclaimLoopCount..'; tPassThroughLocation='..repru(tPassThroughLocation or {'nil'})) end
                        if tPassThroughLocation then
                            iPassingLocationCount = iPassingLocationCount + 1
                            tAllTargetLocations[iPassingLocationCount] = {}
                                                                                --MoveNearConstruction(aiBrain, oBuilder, tLocation, sBlueprintID, iBuildDistanceMod, bReturnMovePathInstead, bUpdatePlatoonMovePath, bReturnNilIfAlreadyMovingNearConstruction)
                            tAllTargetLocations[iPassingLocationCount] = M27PlatoonUtilities.MoveNearConstruction(aiBrain, oPathingUnit, tPassThroughLocation, nil, -iUnitSpeed, true, false, false)
                            tCurStartPosition = {tAllTargetLocations[iPassingLocationCount][1], tAllTargetLocations[iPassingLocationCount][2], tAllTargetLocations[iPassingLocationCount][3]}
                            if bDebugMessages == true then LOG(sFunctionRef..': Have a valid apssthrough location, so moving near here and adding that to the movement path; tAllTargetLocations[iPassingLocationCount]='..repru(tAllTargetLocations[iPassingLocationCount])..'; tCurStartPosition='..repru(tCurStartPosition)) end
                        else
                            bHavePassThrough = false
                        end
                    end
                end
            end
            if bHavePassThrough == false then
                --No move points - move forwards by iSearchIntervals
                if bDebugMessages == true then LOG(sFunctionRef..': No nearby pass-points - moving forwards along path by 10. Position before moving forwards='..repru(tCurStartPosition)) end
                --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
                tCurStartPosition = M27Utilities.MoveTowardsTarget(tCurStartPosition, tFinalDestination, iSearchIntervals, 0)
                if bDebugMessages == true then LOG(sFunctionRef..': Position after moving forwards by '..iSearchIntervals..' ='..repru(tCurStartPosition)) end
                iCurDistanceToEnd = iCurDistanceToEnd - iSearchIntervals
            end
        end
      --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': about to add final destination at the end') end
        tAllTargetLocations[iPassingLocationCount + 1] = {}
        tAllTargetLocations[iPassingLocationCount + 1] = tFinalDestination
        if bDebugMessages == true then
            if bDebugMessages == true then LOG(sFunctionRef..': Will draw alltargetlocations in blue') end
            --DrawLocations(tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation, iCircleSize)
            M27Utilities.DrawLocations(tAllTargetLocations)
        end
        if bDebugMessages == true then LOG(sFunctionRef..': End of function, iPassingLocationCount='..iPassingLocationCount..'; tAllTargetLocations='..repru(tAllTargetLocations)) end
      --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': End of code') end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return tAllTargetLocations
    end

end

function GetLocationValue(aiBrain, tLocation, tStartPoint, sPathing, iSegmentGroup)
    --Considers the value of a location for being targeted by a strong combat unit such as a guncom
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetLocationValue'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tAllUnits
    local iTotalValue = 0
    local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]

    --Value of all nearby mexes
    for iMex, tMex in M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup] do
        if math.abs(tMex[1] - tLocation[1]) <= 30 and math.abs(tMex[3] - tLocation[3]) <= 30 then
            --have a mex, check who has built on item
            iTotalValue = iTotalValue + 25
            tAllUnits = GetUnitsInRect(Rect(tLocation[1]-0.2, tLocation[3]-0.2, tLocation[1]+0.2, tLocation[3]+0.2))
            if M27Utilities.IsTableEmpty(tAllUnits) == true then
                --Noone has the mex so of some value
                iTotalValue = iTotalValue + 75
            else
                tAllUnits = EntityCategoryFilterDown(M27UnitInfo.refCategoryMex, tAllUnits)
                if M27Utilities.IsTableEmpty(tAllUnits) == true then
                    --No-one has built on it so of value
                    iTotalValue = iTotalValue + 75
                else
                    --Someone has claimed the mex, is it us or enemy?
                    if IsEnemy(aiBrain:GetArmyIndex(), tAllUnits[1]:GetAIBrain():GetArmyIndex()) then
                        iTotalValue = iTotalValue + 75 + math.max(100, tAllUnits[1]:GetBlueprint().Economy.BuildCostMass)
                    end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': iMex of '..iMex..' is within 30, so increased total value, total value after increase='..iTotalValue) end
        end
    end

    --Factor in enemy mobile units
    local tEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat + M27UnitInfo.refCategoryEngineer, tLocation, 40, 'Enemy')
    if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
        iTotalValue = iTotalValue + GetCombatThreatRating(aiBrain, tEnemyUnits, true, nil, nil, false, false)
        if bDebugMessages == true then LOG(sFunctionRef..': Increased total value for nearby combat units, total value post increase='..iTotalValue) end
    end

    --Factor in reclaim: 60% of cur segment, 30% of adjacent segments (i.e. would rather target units than reclaim)
    local iBaseReclaimSegmentX, iBaseReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tLocation)
    local iCurReclaimFactor

    function GetSegmentReclaimValue(iReclaimSegmentX, iReclaimSegmentZ)
        local iCurReclaimFactor
        if (M27MapInfo.tReclaimAreas[iBaseReclaimSegmentX][iBaseReclaimSegmentZ][M27MapInfo.refReclaimTotalMass] or 0) > 20 then
            if M27MapInfo.tReclaimAreas[iBaseReclaimSegmentX][iBaseReclaimSegmentZ][M27MapInfo.refReclaimHighestIndividualReclaim] > 250 then
                iCurReclaimFactor = 0.3
            elseif M27MapInfo.tReclaimAreas[iBaseReclaimSegmentX][iBaseReclaimSegmentZ][M27MapInfo.refReclaimHighestIndividualReclaim] > 100 then
                iCurReclaimFactor = 0.2
            elseif M27MapInfo.tReclaimAreas[iBaseReclaimSegmentX][iBaseReclaimSegmentZ][M27MapInfo.refReclaimHighestIndividualReclaim] > 50 then
                iCurReclaimFactor = 0.1
            elseif M27MapInfo.tReclaimAreas[iBaseReclaimSegmentX][iBaseReclaimSegmentZ][M27MapInfo.refReclaimHighestIndividualReclaim] < 10 then
                iCurReclaimFactor = 0.02
            else
                iCurReclaimFactor = 0.05
            end
        end
        if iCurReclaimFactor then
            return iCurReclaimFactor * M27MapInfo.tReclaimAreas[iBaseReclaimSegmentX][iBaseReclaimSegmentZ][M27MapInfo.refReclaimTotalMass]
        else
            return 0
        end
    end

    iTotalValue = iTotalValue + GetSegmentReclaimValue(iBaseReclaimSegmentX, iBaseReclaimSegmentZ)
    for iAdjustX = -1, 1, 1 do
        for iAdjustZ = -1, 1, 1 do
            if iBaseReclaimSegmentX + iAdjustX > 0 and iBaseReclaimSegmentZ + iAdjustZ > 0 then
                iTotalValue = iTotalValue + GetSegmentReclaimValue(iBaseReclaimSegmentX + iAdjustX, iBaseReclaimSegmentZ + iAdjustZ)
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Total value after reclaim adjustment='..iTotalValue) end


    --Adjust value based on distance
    local iStartToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tStartPoint, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
    local iStartToTarget = M27Utilities.GetDistanceBetweenPositions(tStartPoint, tLocation)
    local iTargetToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tLocation, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))

    --% reduction based on how much of a detour to enemy base
    iTotalValue = iTotalValue * iStartToEnemyBase / (iStartToTarget + iTargetToEnemyBase)

    --Also prioritise locations close to the ACU, but not if ACU is withi n5 of them (suggesting it has already chosen it as a location)
    iTotalValue = iTotalValue * (1 - 0.5 * (iStartToTarget / iStartToEnemyBase))
    if iStartToTarget <= 5 then iTotalValue = iTotalValue * 0.7 end
    if bDebugMessages == true then LOG(sFunctionRef..': Total value after distance adjustments='..iTotalValue) end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iTotalValue
end

function GetPriorityACUDestination(aiBrain, oPlatoon)
    --Factors in reclaim, enemy units, enemy mexes, and how much of a detour the location would be from the enemy base to decide whether to go somewhere other than the enemy base
    --Intended for use on ACU when want ACU heading into combat (e.g. it has gun upgrade); also used as a backup where we are going to go to enemy base due to not finding anything with the pre-gun logic
    --Works off platoon variable in case we want to reuse this function for other units in the future
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetPriorityACUDestination'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tHighestValueLocation

    --Check we can path to the enemy base or (if we cant) that the last intel path is reasonably far away from our base
    if oPlatoon[M27PlatoonUtilities.refbNeedToHeal] then
        if bDebugMessages == true then LOG(sFunctionRef..': ACU flagged as needing to heal so will go to nearest rally point') end
        tHighestValueLocation = GetNearestRallyPoint(aiBrain, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), oPlatoon[M27PlatoonUtilities.refoFrontUnit])
    else
        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle then
            local tFirebasePosition = aiBrain[M27MapInfo.reftChokepointBuildLocation]
            if bDebugMessages == true then LOG(sFunctionRef..': ChokepointCount='..aiBrain[M27MapInfo.refiAssignedChokepointCount]..'; tFirebasePosition='..repru(tFirebasePosition)..'; Distance between them='..M27Utilities.GetDistanceBetweenPositions(M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), tFirebasePosition)) end
            if M27Utilities.GetDistanceBetweenPositions(M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), tFirebasePosition) <= 10 then
                --Are we in the same pathing group? If not then get a random point around the firebase
                local sPathing = M27UnitInfo.GetUnitPathingType(oPlatoon[M27PlatoonUtilities.refoFrontUnit])
                if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
                local iSegmentGroup = M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon))
                if not(iSegmentGroup == M27MapInfo.GetSegmentGroupOfLocation(sPathing, tFirebasePosition)) then
                    tHighestValueLocation = {math.random(-20, 20) + tFirebasePosition[1], 0, math.random(-20, 20) + tFirebasePosition[3]}
                    tHighestValueLocation[2] = GetTerrainHeight(tHighestValueLocation[1], tHighestValueLocation[3])
                else
                    tHighestValueLocation = GetRandomPointInAreaThatCanPathTo(M27UnitInfo.GetUnitPathingType(oPlatoon[M27PlatoonUtilities.refoFrontUnit]), M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.GetUnitPathingType(oPlatoon[M27PlatoonUtilities.refoFrontUnit]), tFirebasePosition), tFirebasePosition, 20, 5)
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Got random point in area that can path to as are already near the chokepoint. tHighestValueLocation='..repru(tHighestValueLocation)..'; pathing group of firebase='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, aiBrain[M27MapInfo.reftChokepointBuildLocation])..'; Segment group of ACU='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, GetPlatoonFrontPosition())) end
            else
                tHighestValueLocation = {tFirebasePosition[1], tFirebasePosition[2], tFirebasePosition[3]}
                if bDebugMessages == true then LOG(sFunctionRef..': Will try and go to the chokepoint. tHighestValueLocation='..repru(tHighestValueLocation)) end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Want to turtle so will go to the firebase. tHighestValueLocation='..repru(tHighestValueLocation)) end
        else
            if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] or M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.reftIntelLinePositions][aiBrain[M27Overseer.refiMaxIntelBasePaths]][1]) > math.min(250, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.25) then
                local iMaxDistFromBase = 600
                if aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] >= 550 then iMaxDistFromBase = math.max(math.min(500, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.8), aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.65) end


                --First calculate the value for the enemy start position
                local sPathing = M27UnitInfo.GetUnitPathingType(oPlatoon[M27PlatoonUtilities.refoFrontUnit])
                if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
                local iSegmentGroup = M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon))
                if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup]) then
                    if M27MapInfo.RecheckPathingOfLocation(sPathing, oPlatoon[M27PlatoonUtilities.refoFrontUnit], M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)) then
                        iSegmentGroup = M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon))
                    end
                end
                if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup]) then
                    --Something has likely gone wrong - will use segment group of our base
                    M27Utilities.ErrorHandler('Have no mexes in iSegmentGroup='..iSegmentGroup..'; sPathing='..sPathing..'; will use segemtn group of our base instead which is '..M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]))
                    iSegmentGroup = M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                end
                local tEnemyBase = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
                local iHighestValueLocation = GetLocationValue(aiBrain, tEnemyBase, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), sPathing, iSegmentGroup)

                tHighestValueLocation = { tEnemyBase[1], tEnemyBase[2], tEnemyBase[3] }
                if aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] > iMaxDistFromBase then iHighestValueLocation = 1 end --very low value so if nowhere else viable we will still choose here
                local iCurValueLocation

                if bDebugMessages == true then LOG(sFunctionRef..': Value of enemy start location='..iHighestValueLocation..'; will consider if any mexes have a better value') end
                local tiMexesConsideredByRef = {} --Key is the iMex value, returns true if considered; stored here for mex by pathing and grouping when its considered
                local iMexesConsideredCount = 0

                --tMexByPathingAndGrouping = {} --Stores position of each mex based on the segment that it's part of; [a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
                if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup]) == false then
                    for iMex, tMex in M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup] do
                        if M27Utilities.GetDistanceBetweenPositions(tMex, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)) <= 200 and M27Utilities.GetDistanceBetweenPositions(tMex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iMaxDistFromBase then
                            --Check not tried going here here lots before
                            if (oPlatoon[M27PlatoonUtilities.reftDestinationCount][M27Utilities.ConvertLocationToReference(tMex)] or 0) <= 3 or M27MapInfo.CanWeMoveInSameGroupInLineToTarget(sPathing, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), tMex) then
                                tiMexesConsideredByRef[iMex] = true
                                iMexesConsideredCount = iMexesConsideredCount + 1
                                iCurValueLocation = GetLocationValue(aiBrain, tMex, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), sPathing, iSegmentGroup)
                                if iCurValueLocation > iHighestValueLocation then
                                    if bDebugMessages == true then LOG(sFunctionRef..': tMex='..repru(tMex)..'; value of location='..iCurValueLocation) end
                                    iHighestValueLocation = iCurValueLocation
                                    tHighestValueLocation = tMex
                                end
                            end
                        end
                    end
                end
                --Expand search range if we havent considered many mexes and new target isnt far from us and is owned by us
                if bDebugMessages == true then LOG(sFunctionRef..': Will consider if we should try more locations further away. iMexesConsideredCount='..iMexesConsideredCount..'; Distance between cur location and platoon front position='..M27Utilities.GetDistanceBetweenPositions(tHighestValueLocation, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon))..'; Is table of allied mexes near the highest value location empty='..tostring(M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMex, tHighestValueLocation, 3, 'Ally')))) end
                if iMexesConsideredCount <= 16 and M27Utilities.GetDistanceBetweenPositions(tHighestValueLocation, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)) <= 15 and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMex, tHighestValueLocation, 3, 'Ally')) == false then
                    if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup]) == false then
                        for iMex, tMex in M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup] do
                            if bDebugMessages == true then LOG(sFunctionRef..': Checking if considered mex before and if its within larger range. iMex='..iMex..'; tiMexesConsideredByRef[iMex]='..tostring(tiMexesConsideredByRef[iMex] or false)..'; Distance to platoon='..M27Utilities.GetDistanceBetweenPositions(tMex, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon))..'; Distance from start='..M27Utilities.GetDistanceBetweenPositions(tMex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) end
                            if not(tiMexesConsideredByRef[iMex]) and M27Utilities.GetDistanceBetweenPositions(tMex, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon)) <= 350 and M27Utilities.GetDistanceBetweenPositions(tMex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iMaxDistFromBase then
                                tiMexesConsideredByRef[iMex] = true
                                iMexesConsideredCount = iMexesConsideredCount + 1
                                if bDebugMessages == true then LOG(sFunctionRef..': Destination count of mex='..(oPlatoon[M27PlatoonUtilities.reftDestinationCount][M27Utilities.ConvertLocationToReference(tMex)] or 0)..'; Can we move in same line to target='..tostring(M27MapInfo.CanWeMoveInSameGroupInLineToTarget(sPathing, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), tMex))) end
                                --Check not tried going here here lots before
                                if (oPlatoon[M27PlatoonUtilities.reftDestinationCount][M27Utilities.ConvertLocationToReference(tMex)] or 0) <= 3 or M27MapInfo.CanWeMoveInSameGroupInLineToTarget(sPathing, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), tMex) then
                                    iCurValueLocation = GetLocationValue(aiBrain, tMex, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), sPathing, iSegmentGroup)
                                    if bDebugMessages == true then LOG(sFunctionRef..': iCurValueLocation='..iCurValueLocation) end
                                    if iCurValueLocation > iHighestValueLocation then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Extended range, tMex='..repru(tMex)..'; value of location='..iCurValueLocation) end
                                        iHighestValueLocation = iCurValueLocation
                                        tHighestValueLocation = tMex
                                    end
                                end
                            end
                        end
                    end
                end
            else
                --Cant path to enemy base so find a building to assist
                tHighestValueLocation = GetNearbyUnderConstructionBuilding(aiBrain, oPlatoon[M27PlatoonUtilities.refoPathingUnit], 100)
                if bDebugMessages == true then LOG(sFunctionRef..': Just seen if any under construction buildings we want to head towards; tHighestValueLocation='..repru(tHighestValueLocation or {'nil'})) end

            end

        end
    end
    if tHighestValueLocation == nil then
        if bDebugMessages == true then LOG(sFunctionRef..': Dont have a highest value location so will pick enemy start if can path to it, otherwise will pick closest intel path') end
        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] then
            tHighestValueLocation = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
        else
            if bDebugMessages == true then LOG(sFunctionRef..': refiMaxIntelBasePaths='..(aiBrain[M27Overseer.refiMaxIntelBasePaths] or 'nil')..'; Intel line positions='..repru(aiBrain[M27Overseer.reftIntelLinePositions])) end
            --Are we already close to intel path? If so then go for the previous intel path
            if M27Utilities.GetDistanceBetweenPositions(M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), aiBrain[M27Overseer.reftIntelLinePositions][aiBrain[M27Overseer.refiMaxIntelBasePaths]][1]) <= 10 then
                if aiBrain[M27Overseer.refiMaxIntelBasePaths] <= 1 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Only have 1 intel path so will get random position around base (and attack-move to it)') end
                    tHighestValueLocation = M27EngineerOverseer.AttackMoveToRandomPositionAroundBase(aiBrain, oPlatoon[M27PlatoonUtilities.refoFrontUnit], 50, 30)
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Have more than 1 intel path, so will get preceding one, i.e. intel path number '..aiBrain[M27Overseer.refiMaxIntelBasePaths]-1) end
                    tHighestValueLocation = aiBrain[M27Overseer.reftIntelLinePositions][aiBrain[M27Overseer.refiMaxIntelBasePaths]-1][1]
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Arent at the intel path nearest enemy so will move to the last intel path') end
                tHighestValueLocation = aiBrain[M27Overseer.reftIntelLinePositions][aiBrain[M27Overseer.refiMaxIntelBasePaths]][1]
            end
        end
    end
    if M27Utilities.IsTableEmpty(tHighestValueLocation) then M27Utilities.ErrorHandler('Couldnt find a priority destination') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tHighestValueLocation
end

function GetNearbyUnderConstructionBuilding(aiBrain, oPathingUnit, iMaxSearchRange)
    --Returns either the locatino of the nearest building under construction, or nil
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetNearbyUnderConstructionBuilding'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tDestination
    if bDebugMessages == true then LOG(sFunctionRef..': About to look for buildings in a range of '..iMaxSearchRange..' around the point '..repru(oPathingUnit:GetPosition())) end
    local tNearbyBuildings = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, oPathingUnit:GetPosition(), iMaxSearchRange, 'Ally')
    if M27Utilities.IsTableEmpty(tNearbyBuildings) == false then
        local iNearestBuilding = 10000
        local sPathing = M27UnitInfo.GetUnitPathingType(oPathingUnit)
        local tUnitPosition = oPathingUnit:GetPosition()
        local iPathingGroup = M27MapInfo.GetSegmentGroupOfLocation(sPathing, tUnitPosition)
        if bDebugMessages == true then LOG(sFunctionRef..': Checking if any of the buildings are under construction and have a pathing group of '..iPathingGroup) end
        for iBuilding, oBuilding in tNearbyBuildings do
            if bDebugMessages == true then LOG(sFunctionRef..': Considering building '..oBuilding.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBuilding)..'with pathing group='..M27MapInfo.GetSegmentGroupOfLocation(sPathing, oBuilding:GetPosition())..' and fraction complete='..oBuilding:GetFractionComplete()) end
            if oBuilding:GetFractionComplete() < 1 and M27MapInfo.GetSegmentGroupOfLocation(sPathing, oBuilding:GetPosition()) == iPathingGroup then
                if bDebugMessages == true then LOG(sFunctionRef..': Have a building under construction, distance to ACU='..M27Utilities.GetDistanceBetweenPositions(oBuilding:GetPosition(), tUnitPosition)..'; iNearestBuilding prior to this='..iNearestBuilding) end
                if M27Utilities.GetDistanceBetweenPositions(oBuilding:GetPosition(), tUnitPosition) < iNearestBuilding then
                    tDestination = oBuilding:GetPosition()
                    if bDebugMessages == true then LOG(sFunctionRef..': Have a new nearest building as our destination') end
                end
            end
        end
    elseif bDebugMessages == true then LOG(sFunctionRef..': No buildings found')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tDestination
end

function GetPriorityExpansionMovementPath(aiBrain, oPathingUnit, iMinDistanceOverride, iMaxDistanceOverride)
    --Determiens a high priority location e.g. to send ACU to, and then identifies any places of interest on the way
    --Intended for oPathingUnit to be the ACU, but in theory can be used by any unit
    --Returns nil if no locations can be found
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetPriorityExpansionMovementPath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return {GetPriorityACUDestination(aiBrain, oPathingUnit.PlatoonHandle)}
    else
        --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Start of code') end
        --if oPathingUnit == M27Utilities.GetACU(aiBrain) then bDebugMessages = true end
        --Key config variables:
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
        local iSmallestReclaimSizeToConsider = 10 --Reclaim of less than this wont get counted
        local iMinReclaimWanted = 100
        local iMinReclaimIfCloseToACU = 40 --Will pick location near ACU as final destination if has a bit of reclaim
        local iMaxDistanceAbsolute = 250
        local iMinDistancePercentage = 0.20
        local iMaxDistancePercentage = 0.80
        if iMinDistanceOverride then iMinDistancePercentage = iMinDistanceOverride end
        if iMaxDistanceOverride then iMaxDistancePercentage = iMaxDistanceOverride end
        local iStopCyclingMaxThreshold = 1.2 --If iMaxDistance is over this then will return nil if still dont find a match
        local iSearchRadius = 23
        local iMassValueOfUnclaimedMex = 120
        local iMassValueOfClaimedMex = 20
        local iMinDistanceAwayFromStart = 40 --Wont consider moving to a new expansion point unless its >= this distance away
        local iMinDistanceAwayFromUnit = 40 --Wont consider moving to a new expansion point unless its >= this distance away from unit unless its reclaim
        local iMinDistanceAwayForReclaim = 10
        --If ACU was called away to defend then may want to pick a final destination closer to the ACU:
        if aiBrain[M27Overseer.refbACUWasDefending] == true then
            if bDebugMessages == true then LOG(sFunctionRef..': ACU was previously defending, so reducing mindistancefromunit') end
            aiBrain[M27Overseer.refbACUWasDefending] = false
            iMinDistanceAwayFromUnit = 10
        end

        local tFinalDestination = {}
        local bHaveFinalDestination = false

        local tUnitPos = oPathingUnit:GetPosition()
        local iACUSegmentX, iACUSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tUnitPos)
        local iUnitPathGroup = M27MapInfo.InSameSegmentGroup(oPathingUnit, tUnitPos, true)
        local sPathing = M27UnitInfo.GetUnitPathingType(oPathingUnit)
        if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
        if bDebugMessages == true then LOG(sFunctionRef..': Start; tUnitPos='..repru(tUnitPos)) end
        local iTargetGroup
        local rPlayableArea = M27MapInfo.rMapPlayableArea
        local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
        local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]

        local iSegmentSizeX = iMapSizeX / M27MapInfo.iMaxSegmentInterval
        local iSegmentSizeZ = iMapSizeZ / M27MapInfo.iMaxSegmentInterval
        local iMaxSegmentDistanceX = iMaxDistanceAbsolute / iSegmentSizeX
        local iMaxSegmentDistanceZ = iMaxDistanceAbsolute / iSegmentSizeZ
        local tCurSegmentPosition = {}
        local iPlayerStartPoint = aiBrain.M27StartPositionNumber
        local iMaxDistanceFromEnemy, iMaxDistanceFromStart, iMinDistanceFromStart, iMinDistanceFromEnemy, iCurDistanceFromUnit, bIsFarEnoughFromStart
        local tCurPosition = oPathingUnit:GetPosition()
        local iSegmentX, iSegmentZ



        if GetNearestEnemyStartNumber(aiBrain) == nil then
            LOG(sFunctionRef..': ERROR unless enemy is dead - GetNearestEnemyStartNumber(aiBrain) is nil; returning our start position')
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return {M27MapInfo.PlayerStartPoints[iPlayerStartPoint]}
        else
            --Is ACU unable to path to enemy with amphibious units? then pick somewhere under construction in our base, or return our base if there is nowhere
            if not(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]) then
                local tNearbyBuildings = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, M27MapInfo.PlayerStartPoints[iPlayerStartPoint], 75, 'Ally')
                local oUnderConstruction
                if M27Utilities.IsTableEmpty(tNearbyBuildings) == false then
                    local iClosestDist = 10000
                    local iCurDist
                    local iPlateauWanted = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[iPlayerStartPoint])
                    for iUnit, oUnit in tNearbyBuildings do
                        if oUnit:GetFractionComplete() < 1 then
                            iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oPathingUnit:GetPosition())
                            if iCurDist < iClosestDist then
                                --Is it in teh same plateau?
                                if iPlateauWanted == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition()) then
                                    iClosestDist = iCurDist
                                    oUnderConstruction = oUnit
                                end
                            end
                        end
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Cant path to enemy with amphibious so will keep ACU around base, oUnderConstruction='..(oUnderConstruction.UnitId or 'nil')) end
                if oUnderConstruction then
                    if bDebugMessages == true then LOG(sFunctionRef..': Will return position of '..oUnderConstruction.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnderConstruction)..' pos '..repru(oUnderConstruction:GetPosition())) end
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    return {oUnderConstruction:GetPosition()}
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Will return base position='..repru(M27MapInfo.PlayerStartPoints[iPlayerStartPoint])) end
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    return {M27MapInfo.PlayerStartPoints[iPlayerStartPoint]}
                end
            else

                --Do we have an ACU with gun? If so then just pick enemy base
                if M27Utilities.IsACU(oPathingUnit) and M27Conditions.DoesACUHaveGun(aiBrain, true, oPathingUnit) then
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    return {M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)}
                else
                    --Ignore detailed/complicated pathing logic if we cant path to the enemy base, and go to rally point if we want to heal
                    if oPathingUnit.PlatoonHandle and oPathingUnit.PlatoonHandle[M27PlatoonUtilities.refbNeedToHeal] then
                        if bDebugMessages == true then LOG(sFunctionRef..': ACU flagged as needing to heal so will go to nearest rally point') end
                        bHaveFinalDestination = true
                        tFinalDestination = GetNearestRallyPoint(aiBrain, M27PlatoonUtilities.GetPlatoonFrontPosition(oPathingUnit.PlatoonHandle), oPathingUnit)
                    elseif aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] or M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.reftIntelLinePositions][aiBrain[M27Overseer.refiMaxIntelBasePaths]][1]) > math.min(250, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.25) then


                        if bDebugMessages == true then LOG(sFunctionRef..': GetNearestEnemyStartNumber(aiBrain)='..GetNearestEnemyStartNumber(aiBrain)..'; iPlayerStartPoint='..iPlayerStartPoint) end
                        local iDistanceBetweenBases = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[iPlayerStartPoint], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                        iMinDistanceFromEnemy = iDistanceBetweenBases * iMinDistancePercentage
                        iMaxDistanceFromEnemy = iDistanceBetweenBases * iMaxDistancePercentage
                        iMaxDistanceFromStart = iDistanceBetweenBases * iMaxDistancePercentage
                        iMinDistanceFromStart = iDistanceBetweenBases * iMinDistancePercentage
                        local ReclaimRectangle = {}
                        local tReclaimables = {}
                        local iReclaimInCurrentArea

                        local tPossibleMexLocationsAndNumber = {}
                        local refiMassValue = 1
                        local reftMexPosition = 2
                        local refiDistanceFromStart = 3
                        local refiDistanceFromEnemy = 4
                        local refiDistanceFromACU = 5
                        local refiDistanceFromMiddle = 6
                        local iMaxMassInArea = 1
                        local iMaxMexesInArea = 0
                        local iMaxDistanceFromMiddle = 0
                        local iCurDistanceFromMiddle = 0
                        local iPossibleMexLocations = 0
                        iCurDistanceFromUnit = 0
                        local iMaxDistanceToACU = 0

                        local iDistanceFromStartToEnd = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[iPlayerStartPoint], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))

                        M27Utilities.FunctionProfiler(sFunctionRef..'ReclaimNearACU', M27Utilities.refProfilerStart)
                        --First check if overseer has flagged there's nearby reclaim (in which case have this as the end destination)
                        --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to check overseer reclaim flag') end
                        if bDebugMessages == true then LOG(sFunctionRef..': About to check if significant reclaim near ACU in which case will have this as final destination') end
                        local bReclaimNearACU = false
                        local iACUReclaimSegmentX, iACUReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tCurPosition)
                        local iHighestReclaimLocationMass = 0
                        for iAdjX = -1, 1 do
                            for iAdjZ = -1, 1 do
                                if M27MapInfo.tReclaimAreas[iACUReclaimSegmentX + iAdjX] and M27MapInfo.tReclaimAreas[iACUReclaimSegmentX + iAdjX][iACUReclaimSegmentZ + iAdjZ] and (M27MapInfo.tReclaimAreas[iACUReclaimSegmentX + iAdjX][iACUReclaimSegmentZ + iAdjZ][M27MapInfo.refReclaimTotalMass] or 0) >= iMinReclaimIfCloseToACU then
                                    bReclaimNearACU = true
                                    if iHighestReclaimLocationMass < (M27MapInfo.tReclaimAreas[iACUReclaimSegmentX + iAdjX][iACUReclaimSegmentZ + iAdjZ][M27MapInfo.refReclaimTotalMass] or 0) then
                                        iHighestReclaimLocationMass = (M27MapInfo.tReclaimAreas[iACUReclaimSegmentX + iAdjX][iACUReclaimSegmentZ + iAdjZ][M27MapInfo.refReclaimTotalMass] or 0)
                                        tFinalDestination = M27MapInfo.GetReclaimLocationFromSegment(iACUReclaimSegmentX + iAdjX, iACUReclaimSegmentZ + iAdjZ)
                                    end
                                end
                            end
                        end

                        if bReclaimNearACU == true then
                            if bDebugMessages == true then LOG(sFunctionRef..': Is reclaim near ACU, checking if platoon contains an ACU') end
                            local oUnitBP = oPathingUnit:GetBlueprint()
                            if M27Utilities.IsACU(oUnitBP) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Platoon contains an ACU, obtaining location of reclaim') end
                                if M27Utilities.IsTableEmpty(tFinalDestination) == false then
                                    --Check its far enough away from our start (as dont want ACU running behind its base at the start of the game)
                                    if bDebugMessages == true then LOG(sFunctionRef..': Reclaim location='..repru(tFinalDestination)..'; checking how far it is from player start') end
                                    if M27Utilities.GetDistanceBetweenPositions(tFinalDestination, M27MapInfo.PlayerStartPoints[iPlayerStartPoint]) <= iMinDistanceAwayFromStart then
                                        if M27Utilities.GetDistanceBetweenPositions(tFinalDestination, tCurPosition) >= iMinDistanceAwayForReclaim then
                                            --Its close to our base, so only consider if we could use the mass and its closer to enemy than us
                                            if bDebugMessages == true then LOG(sFunctionRef..': Reclaim is close to our base, checking if we have enough available storage') end
                                            local iStorageRatio = aiBrain:GetEconomyStoredRatio('MASS')
                                            if iStorageRatio == 0 then
                                                bHaveFinalDestination = true
                                            else
                                                local iSpareStorage = aiBrain:GetEconomyStored('MASS') / iStorageRatio
                                                if iSpareStorage >= 100 then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Reclaim is close to our base, and we have enough storage, checking its closer to enemy than ACU') end
                                                    if M27Utilities.GetDistanceBetweenPositions(tFinalDestination, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) <= M27Utilities.GetDistanceBetweenPositions(tUnitPos, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) then
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Reclaim is close to our base, but closer to enemy than us, so choosing it as final destination') end
                                                        bHaveFinalDestination = true
                                                    end
                                                end
                                            end
                                        else
                                            if bDebugMessages == true then LOG(sFunctionRef..': Location is too close to current position') end
                                        end
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': Reclaim is far enough from our start, choosing it as final destination') end
                                        bHaveFinalDestination = true
                                    end
                                end
                            end
                        end
                        --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Finished check of overseer reclaim flag') end

                        --Draw range circles
                        if bDebugMessages == true then
                            local iDisplayCount = 500         --DrawLocation(tLocation, relativeStart, iColour, iDisplayCount, iCircleSize)
                            M27Utilities.DrawLocation(M27MapInfo.PlayerStartPoints[iPlayerStartPoint], false, 2, iDisplayCount, iMinDistanceFromStart)
                            M27Utilities.DrawLocation(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), false, 2,iDisplayCount, iMinDistanceFromStart)
                            M27Utilities.DrawLocation(M27MapInfo.PlayerStartPoints[iPlayerStartPoint], false, 4,iDisplayCount, iMaxDistanceFromStart)
                            M27Utilities.DrawLocation(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), false, 4,iDisplayCount, iMaxDistanceFromStart)
                        end


                        --Update max distances - want to be between 35-65% of the way to enemy base and our base
                        local iCurDistanceFromEnemy, iCurDistanceFromStart
                        --================High value reclaim locations (ignoring mexes)================
                        --Consider if high value reclaim locations on the map:
                        local iChosenReclaimLocationMass = 0
                        M27Utilities.FunctionProfiler(sFunctionRef..'ReclaimNearACU', M27Utilities.refProfilerEnd)
                        if bHaveFinalDestination == false then
                            --M27MapInfo.UpdateReclaimMarkers() --Moved this to overseer so dont risk ACU waiting a while for this to complete
                            M27Utilities.FunctionProfiler(sFunctionRef..'ReclaimAreas', M27Utilities.refProfilerStart)
                            if math.max(M27MapInfo.iHighestReclaimInASegment, M27MapInfo.iPreviousHighestReclaimInASegment) >= iMinReclaimWanted and M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftReclaimAreasOfInterest]) == false then
                                if bDebugMessages == true then LOG(sFunctionRef..': Have enough reclaim in a segment somewhere on map, so want to go through all segments to see if any have enough reclaim to warrant consideration even if no mex') end
                                --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to loop through segments looking at reclaim') end
                                for iPriority, tSubtable in aiBrain[M27MapInfo.reftReclaimAreasOfInterest] do
                                    for iSegments, tSegments in aiBrain[M27MapInfo.reftReclaimAreasOfInterest][iPriority] do
                                        iSegmentX = tSegments[1]
                                        iSegmentZ = tSegments[2]

                                        --for iSegmentX, tVal in M27MapInfo.tReclaimAreas do
                                        if math.abs(iSegmentX - iACUSegmentX) <= iMaxSegmentDistanceX then
                                            --for iSegmentZ, tReclaimInfo in tVal do
                                            if math.abs(iSegmentZ - iACUSegmentZ) <= iMaxSegmentDistanceZ then
                                                --Is there enough reclaim in this segment?
                                                if (M27MapInfo.tReclaimAreas[iSegmentX][iSegmentZ][M27MapInfo.refReclaimTotalMass] or 0) >= iMinReclaimWanted then
                                                    --Are we in the same pathing group?
                                                    --GetSegmentGroupOfTarget(sPathing, iTargetSegmentX, iTargetSegmentZ)
                                                    iTargetGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iSegmentX, iSegmentZ)
                                                    if iTargetGroup == iUnitPathGroup then
                                                        --iSecondMinReclaimCheck = nil --This is set if want an up to date reading on reclaim
                                                        --Is the location close enough to warrant consideration?
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Segment '..iSegmentX..'-'..iSegmentZ..' might be close enough') end
                                                        tCurSegmentPosition = M27MapInfo.GetPositionFromPathingSegments(iSegmentX, iSegmentZ)
                                                        iCurDistanceFromEnemy = M27Utilities.GetDistanceBetweenPositions(tCurSegmentPosition, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                                                        if iCurDistanceFromEnemy <= iMaxDistanceFromEnemy then
                                                            if iCurDistanceFromEnemy >= iMinDistanceFromEnemy then
                                                                iCurDistanceFromStart = M27Utilities.GetDistanceBetweenPositions(tCurSegmentPosition, M27MapInfo.PlayerStartPoints[iPlayerStartPoint])
                                                                if bDebugMessages == true then LOG(sFunctionRef..': Segment '..iSegmentX..'-'..iSegmentZ..' position='..repru(tCurSegmentPosition)..'; iCurDistanceFromEnemy='..iCurDistanceFromEnemy..'; iCurDistanceFromStart='..iCurDistanceFromStart..'; iMaxDistanceFromEnemy='..iMaxDistanceFromEnemy..'; iMinDistanceFromEnemy='..iMinDistanceFromEnemy..'; iMaxDistanceAbsolute='..iMaxDistanceAbsolute..'; iMaxDistanceFromStart='..iMaxDistanceFromStart..'; iMinDistanceFromStart='..iMinDistanceFromStart) end
                                                                if iCurDistanceFromStart <= iMaxDistanceAbsolute then
                                                                    if iCurDistanceFromStart <= iMaxDistanceFromStart then
                                                                        if iCurDistanceFromStart >= iMinDistanceFromStart then

                                                                            if bDebugMessages == true then LOG(sFunctionRef..': Segment '..iSegmentX..'-'..iSegmentZ..' is within the target area by distance') end
                                                                            --Check its far enough away from unit's current position, if unit has already been assigned such a movement path
                                                                            --v7 will comment this out as even if reclaim is close it may still be valid to move to it to gain reclaim; recall this was put in due to acu alternating between mexes that were claimed
                                                                            bIsFarEnoughFromStart = true
                                                                            --[[
                                                                            bIsFarEnoughFromStart = false
                                                                            if oPathingUnit.GetPriorityExpansionMovementPath == nil then
                                                                                bIsFarEnoughFromStart = true
                                                                            else
                                                                                if oPathingUnit.GetPriorityExpansionMovementPath == false then
                                                                                    bIsFarEnoughFromStart = true
                                                                                else --]]

                                                                            iCurDistanceFromUnit = M27Utilities.GetDistanceBetweenPositions(tCurSegmentPosition, tUnitPos)
                                                                            if iCurDistanceFromUnit <= iMinDistanceAwayForReclaim then bIsFarEnoughFromStart = false end
                                                                            --[[if bDebugMessages == true then LOG(sFunctionRef..': Checking if min distance from unit, iCurDistanceFromUnit='..iCurDistanceFromUnit..'; iMinDistanceAwayFromUnit='..iMinDistanceAwayFromUnit) end
                                                                            if iCurDistanceFromUnit >= iMinDistanceAwayFromUnit then
                                                                                if bDebugMessages == true then LOG(sFunctionRef..': Segment '..iSegmentX..'-'..iSegmentZ..' position='..repru(tCurSegmentPosition)..'; iCurDistanceFromUnit='..iCurDistanceFromUnit..'; far enough away that can consider as final destination') end
                                                                                bIsFarEnoughFromStart = true
                                                                            else
                                                                                --Is a reclaim location so check if is actually still enough reclaim in this area
                                                                                iSecondMinReclaimCheck = math.min(math.max(tReclaimInfo[1] * 0.5, 100),200)
                                                                            end
                                                                        end
                                                                    end--]]
                                                                            if bIsFarEnoughFromStart == true then
                                                                                --Have a segment that might have enough reclaim, and is far enough from the start
                                                                                --bHaveEnoughReclaim = true
                                                                                --if iSecondMinReclaimCheck and iReclaimInCurrentArea < iSecondMinReclaimCheck then bHaveEnoughReclaim = false end

                                                                                if bDebugMessages == true then LOG(sFunctionRef..': position '..repru(tCurSegmentPosition)..' has enough reclaim - recording as a possible location') end

                                                                                iPossibleMexLocations = iPossibleMexLocations + 1
                                                                                iReclaimInCurrentArea = (M27MapInfo.tReclaimAreas[iSegmentX][iSegmentZ][M27MapInfo.refReclaimTotalMass] or 0)

                                                                                tPossibleMexLocationsAndNumber[iPossibleMexLocations] = {}
                                                                                tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiMassValue] = iReclaimInCurrentArea
                                                                                tPossibleMexLocationsAndNumber[iPossibleMexLocations][reftMexPosition] = {}
                                                                                tPossibleMexLocationsAndNumber[iPossibleMexLocations][reftMexPosition] = tCurSegmentPosition
                                                                                tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiDistanceFromStart] = iCurDistanceFromStart
                                                                                tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiDistanceFromEnemy] = iCurDistanceFromEnemy
                                                                                tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiDistanceFromACU] = iCurDistanceFromUnit
                                                                                iCurDistanceFromMiddle = math.abs(iCurDistanceFromEnemy - iCurDistanceFromStart)
                                                                                tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiDistanceFromMiddle] = iCurDistanceFromMiddle
                                                                                if iReclaimInCurrentArea > iMaxMassInArea then iMaxMassInArea = iReclaimInCurrentArea end
                                                                                if iCurDistanceFromMiddle > iMaxDistanceFromMiddle then iMaxDistanceFromMiddle = iCurDistanceFromMiddle end
                                                                                if iCurDistanceFromUnit > iMaxDistanceToACU then iMaxDistanceToACU = iCurDistanceFromUnit end
                                                                                if bDebugMessages == true then LOG(sFunctionRef..': iReclaimInCurrentArea='..iReclaimInCurrentArea..'; iMaxMassInArea='..iMaxMassInArea) end
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
                                end
                            end
                            M27Utilities.FunctionProfiler(sFunctionRef..'ReclaimAreas', M27Utilities.refProfilerEnd)

                            --[[if table.getn(tPossibleReclaimLocationAndReclaim) > 0 then
                                local iNewMinReclaimWanted = iMaxReclaimFound * iReclaimPercentageOfMaxWanted
                                local iDistanceFromACU
                                local iMinDistanceFromACU = 10000
                                local iMinDistanceAreaRef
                                for iCurArea, tAreaInfo in tPossibleReclaimLocationAndReclaim do
                                    if tAreaInfo[refiReclaimAmount] >= iNewMinReclaimWanted then
                                        iDistanceFromACU = M27Utilities.GetDistanceBetweenPositions(tAreaInfo[refiSegmentPosition], tUnitPos)
                                        if iDistanceFromACU <= iMinDistanceFromACU then
                                            iMinDistanceFromACU = iDistanceFromACU
                                            iMinDistanceAreaRef = iCurArea
                                        end
                                    end
                                    --DrawLocation(tableLocations, relativeStart, iColour, iDisplayCount)
                                    if bDebugMessages == true then M27Utilities.DrawLocation(tAreaInfo[refiSegmentPosition], false, 3) end
                                end
                                tFinalDestination = tPossibleReclaimLocationAndReclaim[iMinDistanceAreaRef][refiSegmentPosition]
                                if bDebugMessages == true then M27Utilities.DrawLocation(tFinalDestination, false, 1) end
                                bHaveFinalDestination = true
                                iChosenReclaimLocationMass = tPossibleReclaimLocationAndReclaim[iMinDistanceAreaRef][refiSegmentPosition] = iReclaimInCurrentArea
                            end ]]--
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Already have final destination from overseer = '..repru(tFinalDestination)) end
                        end

                        --================High value mex locations (including reclaim)================

                        --if bHaveFinalDestination == false then
                        --consider mexes
                        --tMexByPathingAndGrouping = {} --Stores position of each mex based on the segment that it's part of; [a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering mexes') end
                        local iSegmentX, iSegmentZ
                        local iMexesInCurArea
                        --local tPossibleMexLocationsAndNumber = {}
                        --[[local refiMexCount = 1
                        local reftMexPosition = 2
                        local refiDistanceFromStart = 3
                        local refiDistanceFromEnemy = 4
                        local refiDistanceFromACU = 5
                        local refiDistanceFromMiddle = 6
                        local iMaxMexesInArea = 0
                        local iMaxDistanceFromMiddle = 0
                        local iCurDistanceFromMiddle = 0
                        local iPossibleMexLocations = 0
                        iCurDistanceFromUnit = 0
                        local iMaxDistanceToACU = 0]]--
                        local iClaimedMexesInArea = 0
                        local iReclaimSegmentX, iReclaimSegmentZ
                        local iReclaimSegmentSearchRange = math.ceil(iSearchRadius / M27MapInfo.iReclaimSegmentSizeX)
                        local bIsCurMexUnclaimed
                        --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to record mex for pathing group') end
                        --M27MapInfo.RecordMexForPathingGroup(oPathingUnit)
                        if bDebugMessages == true then LOG(sFunctionRef..': table of MexByPathingAndGrouping='..table.getn(M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitPathGroup])..'; sPathing='..sPathing..'; iUnitPathGroup='..iUnitPathGroup) end
                        --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to cycle through mexes in pathing group') end
                        if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitPathGroup]) == false then
                            M27Utilities.FunctionProfiler(sFunctionRef..'Mexes', M27Utilities.refProfilerStart)
                            for iCurMex, tMexLocation in M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitPathGroup] do
                                --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': iCurMex='..iCurMex..'; tMexLocation='..repru(tMexLocation)..': Start of loop') end
                                iSegmentX, iSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tMexLocation)
                                if bDebugMessages == true then LOG(sFunctionRef..': Considering mex position='..repru(tMexLocation)..'; iSegmentX,Z='..iSegmentX..'-'..iSegmentZ..'; iACUSegmentX-Z='..iACUSegmentX..'-'..iACUSegmentZ..'; iMaxSegmentDistanceX,Z='..iMaxSegmentDistanceX..'-'..iMaxSegmentDistanceZ) end
                                if math.abs(iSegmentX - iACUSegmentX) <= iMaxSegmentDistanceX then
                                    if math.abs(iSegmentZ - iACUSegmentZ) <= iMaxSegmentDistanceZ then
                                        --Is the location close enough to warrant consideration?
                                        iCurDistanceFromEnemy = M27Utilities.GetDistanceBetweenPositions(tMexLocation, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                                        if iCurDistanceFromEnemy <= iMaxDistanceFromEnemy then
                                            if iCurDistanceFromEnemy >= iMinDistanceFromEnemy then
                                                iCurDistanceFromStart = M27Utilities.GetDistanceBetweenPositions(tMexLocation, M27MapInfo.PlayerStartPoints[iPlayerStartPoint])
                                                if bDebugMessages == true then LOG(sFunctionRef..': Considering distance from start; iCurDistanceFromEnemy='..iCurDistanceFromEnemy..'; iCurDistanceFromStart='..iCurDistanceFromStart) end
                                                if iCurDistanceFromStart <= iMaxDistanceAbsolute then
                                                    if iCurDistanceFromStart <= iMaxDistanceFromStart then
                                                        if iCurDistanceFromStart >= iMinDistanceFromStart then
                                                            iCurDistanceFromUnit = M27Utilities.GetDistanceBetweenPositions(tMexLocation, tUnitPos)
                                                            if iCurDistanceFromUnit <= iMaxDistanceAbsolute then
                                                                --Check its far enough away from unit's current position, if unit has already been assigned such a movement path
                                                                bIsFarEnoughFromStart = false
                                                                if oPathingUnit.GetPriorityExpansionMovementPath == nil then
                                                                    bIsFarEnoughFromStart = true
                                                                else
                                                                    if oPathingUnit.GetPriorityExpansionMovementPath == false then
                                                                        bIsFarEnoughFromStart = true
                                                                    else
                                                                        iCurDistanceFromUnit = M27Utilities.GetDistanceBetweenPositions(tMexLocation, tUnitPos)
                                                                        if iCurDistanceFromUnit >= iMinDistanceAwayFromUnit then
                                                                            if bDebugMessages == true then LOG(sFunctionRef..': tMexLocation='..repru(tMexLocation)..'; iCurDistanceFromUnit='..iCurDistanceFromUnit..'; far enough away that can consider as final destination') end
                                                                            bIsFarEnoughFromStart = true
                                                                        end
                                                                    end
                                                                end
                                                                if bIsFarEnoughFromStart == true then
                                                                    --The mex is close enough to us and enemy for consideration - determine how many mexes are nearby that we havent got mexes on
                                                                    --IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
                                                                    --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Just before checking if mex is unclaimed') end
                                                                    if M27Conditions.IsMexUnclaimed(aiBrain, tMexLocation, true, false, false) == true then
                                                                        --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Just after checking if mex is unclaimed - it is unclaimed') end
                                                                        iMexesInCurArea = 1
                                                                        iPossibleMexLocations = iPossibleMexLocations + 1

                                                                        --Record other mexes in the area: First unclaimed mexes:

                                                                        for iAltMex, tAltMexLocation in M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitPathGroup] do
                                                                            if not(iAltMex == iCurMex) then
                                                                                if M27Utilities.GetDistanceBetweenPositions(tAltMexLocation, tMexLocation) <= iSearchRadius then
                                                                                    --IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
                                                                                    if M27Conditions.IsMexUnclaimed(aiBrain, tAltMexLocation, true, false, false) == true then
                                                                                        iMexesInCurArea = iMexesInCurArea + 1
                                                                                    end
                                                                                end
                                                                            end
                                                                        end

                                                                        --Next claimed mexes:
                                                                        iClaimedMexesInArea = 0
                                                                        for iAltMex, tAltMexLocation in M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitPathGroup] do
                                                                            --if not(iAltMex == iCurMex) then
                                                                            if M27Utilities.GetDistanceBetweenPositions(tAltMexLocation, tMexLocation) <= iSearchRadius then
                                                                                --IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
                                                                                if M27Conditions.IsMexUnclaimed(aiBrain, tAltMexLocation, true, true, true) == true then
                                                                                    iClaimedMexesInArea = iClaimedMexesInArea + 1
                                                                                end
                                                                            end
                                                                            --end
                                                                        end
                                                                        iClaimedMexesInArea = iClaimedMexesInArea - iMexesInCurArea
                                                                        if iClaimedMexesInArea < 0 then iClaimedMexesInArea = 0 LOG(sFunctionRef..': ERROR - shouldnt be possible for claimed mexes to be negative') end

                                                                        --Now get reclaim in the area:
                                                                        iReclaimSegmentX, iReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tMexLocation)
                                                                        iReclaimInCurrentArea = 0
                                                                        for iBaseX = iReclaimSegmentX - iReclaimSegmentSearchRange, iReclaimSegmentX + iReclaimSegmentSearchRange do
                                                                            for iBaseZ = iReclaimSegmentZ - iReclaimSegmentSearchRange, iReclaimSegmentZ + iReclaimSegmentSearchRange do
                                                                                iReclaimInCurrentArea = iReclaimInCurrentArea + (M27MapInfo.tReclaimAreas[iBaseX][iBaseZ][M27MapInfo.refReclaimTotalMass] or 0)
                                                                            end
                                                                        end
                                                                        --ReclaimRectangle = Rect(tMexLocation[1] - iSearchRadius,tMexLocation[3] - iSearchRadius, tMexLocation[1] + iSearchRadius, tMexLocation[3] + iSearchRadius)
                                                                        --tReclaimables = GetReclaimablesInRect(ReclaimRectangle)
                                                                        --iReclaimInCurrentArea = M27MapInfo.GetReclaimablesResourceValue(tReclaimables, false, iSmallestReclaimSizeToConsider)

                                                                        iCurDistanceFromMiddle = math.abs(iCurDistanceFromEnemy - iCurDistanceFromStart)

                                                                        tPossibleMexLocationsAndNumber[iPossibleMexLocations] = {}
                                                                        --tPossibleMexLocationsAndNumber[iPossibleMexLocations][iMexesInCurArea] = {}
                                                                        tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiMassValue] = iMexesInCurArea * iMassValueOfUnclaimedMex + iClaimedMexesInArea * iMassValueOfClaimedMex + iReclaimInCurrentArea
                                                                        tPossibleMexLocationsAndNumber[iPossibleMexLocations][reftMexPosition] = {}
                                                                        tPossibleMexLocationsAndNumber[iPossibleMexLocations][reftMexPosition] = {tMexLocation[1], tMexLocation[2], tMexLocation[3]} --Need this rather than table reference or mess up engineer tracking
                                                                        tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiDistanceFromStart] = iCurDistanceFromStart
                                                                        tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiDistanceFromEnemy] = iCurDistanceFromEnemy
                                                                        tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiDistanceFromACU] = iCurDistanceFromUnit
                                                                        tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiDistanceFromMiddle] = iCurDistanceFromMiddle
                                                                        --if iMexesInCurArea > iMaxMexesInArea then iMaxMexesInArea = iMexesInCurArea end
                                                                        if bDebugMessages == true then LOG(sFunctionRef..': iPossibleMexLocations='..iPossibleMexLocations..'; tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiMassValue]='..tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiMassValue]..'; iMaxMassInArea='..iMaxMassInArea..'; Location='..repru(tMexLocation)) end
                                                                        if tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiMassValue] > iMaxMassInArea then iMaxMassInArea = tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiMassValue] end
                                                                        if iCurDistanceFromMiddle > iMaxDistanceFromMiddle then iMaxDistanceFromMiddle = iCurDistanceFromMiddle end
                                                                        if iCurDistanceFromUnit > iMaxDistanceToACU then iMaxDistanceToACU = iCurDistanceFromUnit end
                                                                        --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': End of recording possible mex locations main section') end
                                                                    else
                                                                        if bDebugMessages == true then LOG(sFunctionRef..': Mex is claimed so ignoring this location') end
                                                                        --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Just after checking if mex is unclaimed - it was already claimed') end
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
                                --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': iCurMex='..iCurMex..'; tMexLocation='..repru(tMexLocation)..': End of loop') end
                            end
                            M27Utilities.FunctionProfiler(sFunctionRef..'Mexes', M27Utilities.refProfilerEnd)
                        end
                        --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to consider possible locations to pass through') end
                        if table.getn(tPossibleMexLocationsAndNumber) > 0 then
                            M27Utilities.FunctionProfiler(sFunctionRef..'Prioritisation', M27Utilities.refProfilerStart)
                            local iMaxPriority = 0
                            local iAreaWithMaxPriority
                            local iCurPriority
                            if bDebugMessages == true then LOG(sFunctionRef..' About to cycle through all possible locations and determine their priority; Total possible locations='..table.getn(tPossibleMexLocationsAndNumber)..'; iMaxMassInArea='..iMaxMassInArea..'; iDistanceFromStartToEnd='..iDistanceFromStartToEnd) end
                            for iCurArea, tAreaInfo in tPossibleMexLocationsAndNumber do

                                if bDebugMessages == true then
                                    LOG(sFunctionRef..'iCurArea='..iCurArea..'; about to reproduce tAreaInfo')
                                    LOG(repru(tAreaInfo))
                                end
                                iCurPriority = 0
                                --[[Pick a location with the following priority:
                                    +2 if closer to enemy start than ours
                                    +0-4 based no how close to the middle of the map it is (+4 for closest to middle)
                                    +0-4 based on how close to our ACU it is (the closer the better)
                                    +0 to 8, based on max no. of mexes of any position (0) to most (8)
                                    -0 to 4 based on how far it deviates from the centre of the map (in rare cases it may be higher than 4; i.e. if symmetrical map with both bases in each corner, then pickign one of the other map corners would result in a value of approx 4 ]]

                                if tAreaInfo[refiDistanceFromEnemy] <= tAreaInfo[refiDistanceFromStart] then iCurPriority = iCurPriority + 2 end
                                iCurPriority = iCurPriority + 4 * (1 - tAreaInfo[refiDistanceFromMiddle] / iMaxDistanceFromMiddle)
                                iCurPriority = iCurPriority + 4 * (1 - tAreaInfo[refiDistanceFromACU] / iMaxDistanceToACU)
                                iCurPriority = iCurPriority - (4 / 0.415) * (tAreaInfo[refiDistanceFromStart] + tAreaInfo[refiDistanceFromEnemy] - iDistanceFromStartToEnd) / iDistanceFromStartToEnd
                                iCurPriority = iCurPriority + 8 * tAreaInfo[refiMassValue] / iMaxMassInArea
                                if iCurPriority > iMaxPriority then
                                    iAreaWithMaxPriority = iCurArea
                                    iMaxPriority = iCurPriority
                                end
                                if bDebugMessages == true then M27Utilities.DrawLocation(tAreaInfo[reftMexPosition], false, 4) end
                                if bDebugMessages == true then LOG(sFunctionRef..': Mass in location='..tAreaInfo[refiMassValue]..'; max mass in area='..iMaxMassInArea..'; iCurPriority='..iCurPriority..'; iMaxPriority='..iMaxPriority) end
                            end
                            --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to settle on final destination') end
                            tFinalDestination = tPossibleMexLocationsAndNumber[iAreaWithMaxPriority][reftMexPosition]
                            if bDebugMessages == true then M27Utilities.DrawLocation(tFinalDestination, false, 1) end
                            bHaveFinalDestination = true
                            M27Utilities.FunctionProfiler(sFunctionRef..'Prioritisation', M27Utilities.refProfilerEnd)
                        end
                    else
                        --Cant path to enemy base, look for the nearest underconstrucntion building to assist
                        if bDebugMessages == true then LOG(sFunctionRef..': About to check for under construction buildings to head to') end
                        tFinalDestination = GetNearbyUnderConstructionBuilding(aiBrain, oPathingUnit, 100)
                        if tFinalDestination then bHaveFinalDestination = true end
                        if bDebugMessages == true then LOG(sFunctionRef..': Just seen if any under construction buildings we want to head towards; tFinalDestination='..repru(tFinalDestination or {'nil'})) end
                    end
                    --end
                    if bDebugMessages == true then LOG(sFunctionRef..': Near end of code, will return value based on specifics') end
                    if bHaveFinalDestination == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': Failed to find a final destination, will just use enemy base if can path there, or closest rally point if cant path there') end
                        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] then
                            tFinalDestination = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': refiMaxIntelBasePaths='..(aiBrain[M27Overseer.refiMaxIntelBasePaths] or 'nil')..'; Intel line positions='..repru(aiBrain[M27Overseer.reftIntelLinePositions])) end
                            --Are we already close to intel path? If so then go for the previous intel path
                            if M27Utilities.GetDistanceBetweenPositions(tUnitPos, aiBrain[M27Overseer.reftIntelLinePositions][aiBrain[M27Overseer.refiMaxIntelBasePaths]][1]) <= 10 then
                                if aiBrain[M27Overseer.refiMaxIntelBasePaths] <= 1 then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Only have 1 intel path so will get random position around base (and attack-move to it)') end
                                    tFinalDestination = M27EngineerOverseer.AttackMoveToRandomPositionAroundBase(aiBrain, oPathingUnit, 50, 30)
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have more than 1 intel path, so will get preceding one, i.e. intel path number '..aiBrain[M27Overseer.refiMaxIntelBasePaths]-1) end
                                    tFinalDestination = aiBrain[M27Overseer.reftIntelLinePositions][aiBrain[M27Overseer.refiMaxIntelBasePaths]-1][1]
                                end
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Arent at the intel path nearest enemy so will move to the last intel path') end
                                tFinalDestination = aiBrain[M27Overseer.reftIntelLinePositions][aiBrain[M27Overseer.refiMaxIntelBasePaths]][1]
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Backup tFinalDestination='..repru(tFinalDestination)) end

                        --[[ As of v15 removed this since performance on this function is already terrible
                        --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Failed to get final destination, repeating again') end
                        if bDebugMessages == true then LOG(sFunctionRef..': Failed to find a final destination, will retry with higher bounds unless already done that or no mexes in pathing group') end
                        if iMaxDistancePercentage > iStopCyclingMaxThreshold or M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitPathGroup]) == true then return nil
                        else
                            local iNewMaxDistance = iMaxDistancePercentage + 0.2
                            local tExpansionPath = GetPriorityExpansionMovementPath(aiBrain, oPathingUnit, iMinDistanceOverride, iNewMaxDistance)
                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                            return tExpansionPath
                        end --]]
                    end

                    --If final destination is near enemy base then instead use GetPriorityACUDestination
                    if bHaveFinalDestination == false or M27Utilities.GetDistanceBetweenPositions(tFinalDestination, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) <= 50 then
                        tFinalDestination = GetPriorityACUDestination(aiBrain, oPathingUnit.PlatoonHandle)
                    end

                    --Update final destination to move near it:
                    M27Utilities.FunctionProfiler(sFunctionRef..'AddingDetours', M27Utilities.refProfilerStart)
                    local tRevisedDestination = {}
                    if bDebugMessages == true then LOG(sFunctionRef..': About to call MoveNearConstruction') end
                    --MoveNearConstruction(aiBrain, oBuilder, tLocation, sBlueprintID, iBuildDistanceMod, bReturnMovePathInstead, bUpdatePlatoonMovePath, bReturnNilIfAlreadyMovingNearConstruction)
                    tRevisedDestination = M27PlatoonUtilities.MoveNearConstruction(aiBrain, oPathingUnit, tFinalDestination, nil, -3, true, false, false)
                    --=========Get mexes and high value reclaim en-route================
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': tFinalDestination determined, ='..repru(tFinalDestination)..'; tRevisedDestination='..repru(tRevisedDestination)..'; will now add mexes as via points')
                        M27Utilities.DrawLocation(tRevisedDestination, nil, 1, 100)
                        --Below may cause desync so only enable temporarily
                        --if bDebugMessages == true then LOG(sFunctionRef..': SegmentGroup of tFinalDestination='..M27MapInfo.InSameSegmentGroup(oPathingUnit, tFinalDestination, true)) end
                        --if bDebugMessages == true then LOG(sFunctionRef..': CanPathToManual for tFinalDestination='..tostring(oPathingUnit:CanPathTo(tFinalDestination))) end
                    end
                    oPathingUnit.GetPriorityExpansionMovementPath = true
                    --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to add nearby reclaim and mexes to movement path') end'
                    local tRevisedPath = AddMexesAndReclaimToMovementPath(oPathingUnit, tRevisedDestination)

                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    M27Utilities.FunctionProfiler(sFunctionRef..'AddingDetours', M27Utilities.refProfilerEnd)
                    return tRevisedPath
                end
            end
        end
    end
end

function GetPositionToFollowTargets(tUnitsToFollow, oFollowingUnit, iFollowDistance)
    --If following single unit, then do {oSingleUnit} for tUnitsToFollow
    --returns the units to follow average position if cant find anywhere at iFollowDistance from it
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetPositionToFollowTargets'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tTargetPosition = M27Utilities.GetAveragePosition(tUnitsToFollow)
    local tPossibleMovePosition = {}
    local tFollowerPosition = oFollowingUnit:GetPosition()
    if oFollowingUnit and not(oFollowingUnit.Dead) then
        if iFollowDistance == nil then iFollowDistance = 5 end

        --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
        --[[local iCount = 0
        local iMaxCount = 40
        local tFollowMovePosition = {}
        local iDirectionMod
        local iCurSegmentGroup = M27MapInfo.InSameSegmentGroup(oFollowingUnit, tTargetPosition, true)
        local iPossibleSegmentX, iPossibleSegmentZ
        local iPossibleGroup
        local sPathing = M27UnitInfo.GetUnitPathingType(oFollowingUnit)--]]
        --function GetPositionNearTargetInSamePathingGroup(tStartPos, tTargetPos, iDistanceFromTarget, iAngleBase, oPathingUnit, iNearbyMethodIfBlocked, bTrySidePositions)
        --tPossibleMovePosition = M27PlatoonUtilities.GetPositionNearTargetInSamePathingGroup(tFollowerPosition, tTargetPosition, iFollowDistance, 0, oFollowingUnit, 3, true)
        tPossibleMovePosition = M27PlatoonUtilities.GetPositionAtOrNearTargetInPathingGroup(tFollowerPosition, tTargetPosition, iFollowDistance, 0, oFollowingUnit, true, true, 2)
        if tPossibleMovePosition == nil then tPossibleMovePosition = tTargetPosition end
    else
        M27Utilities.ErrorHandler(sFunctionRef..': Warning - trying to follow target but unit do do following is dead or nil - if this triggers more than one cycle in a row then have error')

        tPossibleMovePosition = tFollowerPosition
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tPossibleMovePosition
end

function GetIntelCoverageOfPosition(aiBrain, tTargetPosition, iMinCoverageWanted, bOnlyGetRadarCoverage)
    --Look for the nearest intel coverage for tTargetPosition, or (if nil) then the visual range of the nearest unit to the position that is friendly
    --if iMinCoverageWanted isn't specified then will return the highest amount, otherwise returns true/false
    --if bOnlyGetRadarCoverage is true then will only consider if we have a radar structure providing iMinCoverageWanted
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetIntelCoverageOfPosition'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if aiBrain[M27AirOverseer.refbHaveOmniVision] then

        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        if iMinCoverageWanted then return true
        else return 100000
        end
    else


        --Visual range - base on air segments and if they've been flagged as having had recent visual
        local iAirSegmentAdjSize = 1
        if iMinCoverageWanted then iAirSegmentAdjSize = math.ceil(iMinCoverageWanted   / M27AirOverseer.iAirSegmentSize) end
        local iBaseAirSegmentX, iBaseAirSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(tTargetPosition)
        local bHaveRecentVisual = true
        for iAdjX = -iAirSegmentAdjSize, iAirSegmentAdjSize do
            for iAdjZ = -iAirSegmentAdjSize, iAirSegmentAdjSize do
                if bDebugMessages == true then LOG(sFunctionRef..': Time of last visual for segment with iAdjX='..iAdjX..'; iAdjZ='..iAdjZ..'='..M27AirOverseer.GetTimeSinceLastScoutedSegment(aiBrain, iBaseAirSegmentX + iAdjX, iBaseAirSegmentZ + iAdjZ)) end
                if aiBrain[M27AirOverseer.reftAirSegmentTracker][iBaseAirSegmentX + iAdjX] and aiBrain[M27AirOverseer.reftAirSegmentTracker][iBaseAirSegmentX + iAdjX][iBaseAirSegmentZ + iAdjZ]
                        and M27AirOverseer.GetTimeSinceLastScoutedSegment(aiBrain, iBaseAirSegmentX + iAdjX, iBaseAirSegmentZ + iAdjZ) > 1.1 then
                    --Dont have recent visual (prior to v60 - would check are either 0 adj, or are within iMinCoverageWanted)
                    bHaveRecentVisual = false
                    --[[if iAdjX == 0 and iAdjZ == 0 then
                        bHaveRecentVisual = false
                        break
                    elseif M27Utilities.GetDistanceBetweenPositions(tTargetPosition, M27AirOverseer.GetAirPositionFromSegment(iBaseAirSegmentX + iAdjX, iBaseAirSegmentZ + iAdjZ)) <= iMinCoverageWanted then
                        bHaveRecentVisual = false
                        break
                    end--]]
                end
            end
            if not(bHaveRecentVisual) then break end
        end


        local iMaxIntelCoverage = 0
        if iMinCoverageWanted == nil and bHaveRecentVisual then iMaxIntelCoverage = M27AirOverseer.iAirSegmentSize end
        if bDebugMessages == true then LOG(sFunctionRef..': iMinCoverageWanted='..(iMinCoverageWanted or 'nil')..'; bHaveRecentVisual='..tostring(bHaveRecentVisual)..'; iMaxIntelCoverage='..(iMaxIntelCoverage or 'nil')) end
        if bHaveRecentVisual == false or iMinCoverageWanted == nil then
            --Dont have recent visual, so see if have nearby radar or scout
            local tCategoryList = {M27UnitInfo.refCategoryRadar, categories.SCOUT}
            if bOnlyGetRadarCoverage then tCategoryList = {M27UnitInfo.refCategoryRadar} end
            local tiSearchRange = {570, 70} --Omni radar is 600; spy plan is 96; want to be at least 30
            local iCurIntelRange, iCurDistanceToPosition, iCurIntelCoverage
            local tCurUnits = {}

            for iCategoryTableRef, iCategoryType in tCategoryList do
                tCurUnits = aiBrain:GetUnitsAroundPoint(iCategoryType, tTargetPosition, tiSearchRange[iCategoryTableRef], 'Ally')
                --tCurUnits = aiBrain:GetListOfUnits(iCategoryType, false, true)
                for iUnit, oUnit in tCurUnits do
                    iCurIntelRange = oUnit:GetBlueprint().Intel.RadarRadius
                    iCurDistanceToPosition = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tTargetPosition)
                    iCurIntelCoverage = iCurIntelRange - iCurDistanceToPosition
                    if iCurIntelCoverage > iMaxIntelCoverage then

                        --if iMinCoverageWanted == nil then
                        iMaxIntelCoverage = iCurIntelCoverage
                        --else
                        if not(iMinCoverageWanted==nil) then
                            if iCurIntelCoverage > iMinCoverageWanted then
                                if bDebugMessages == true then LOG(sFunctionRef..': iMinCoverageWanted='..iMinCoverageWanted..'; iMaxIntelCoverage='..iMaxIntelCoverage..'; iCurIntelCoverage='..iCurIntelCoverage) end
                                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                                return true
                            end
                        end
                    end
                end
            end
            --Below removed from v15 for performance reasons and replaced with check to air segments above
            --[[
            if iMaxIntelCoverage <= 30 and not(bOnlyGetRadarCoverage) then
                --Consider vision range of nearest friendly units
                local iCurVisionRange
                for iUnit, oUnit in aiBrain:GetUnitsAroundPoint(categories.ALLUNITS, tTargetPosition, 30, 'Ally') do
                    iCurVisionRange = oUnit.Intel.VisionRadius
                    if iCurVisionRange and iCurVisionRange > iMaxIntelCoverage then
                        iCurIntelCoverage = iCurVisionRange - M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tTargetPosition)
                        if iCurIntelCoverage > iMaxIntelCoverage then
                            iMaxIntelCoverage = iCurIntelCoverage
                            if not(iMinCoverageWanted==nil) and iCurIntelCoverage > iMinCoverageWanted then
                                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                                return true end
                        end
                    end
                end
            end--]]
        elseif bHaveRecentVisual and iMinCoverageWanted then
            if bDebugMessages == true then LOG(sFunctionRef..': Have recent visual of all nearby segments so returning true') end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return true
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        if iMinCoverageWanted == nil then
            if bDebugMessages == true then LOG(sFunctionRef..': iMinCoverage is nil; returning iMaxIntelCoverage='..iMaxIntelCoverage) end
            return iMaxIntelCoverage
        else
            if bDebugMessages == true then LOG(sFunctionRef..': iMinCoverage='..iMinCoverageWanted..'; iMaxIntelCoverage='..iMaxIntelCoverage..'; returning false') end
            return false end
    end

end

function GetDirectFireWeaponPosition(oFiringUnit)
    --Returns position of oFiringUnit's first DF weapon; nil if oFiringUnit doesnt have a DF weapon; Unit position if no weapon bone
    --for ACU, returns this for the overcharge weapon
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetDirectFireWeaponPosition'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oBPFiringUnit = oFiringUnit:GetBlueprint()
    local tShotStartPosition
    if EntityCategoryContains(categories.DIRECTFIRE + M27UnitInfo.refCategoryFatboy, oBPFiringUnit.BlueprintId) == true then
        local bIsACU = EntityCategoryContains(categories.COMMAND, oBPFiringUnit.BlueprintId)

        local sFiringBone
        if bDebugMessages == true then LOG(sFunctionRef..': Have a DF unit, working out where shot coming from') end
        --Work out where the shot is coming from:
        local bIsFatboy = EntityCategoryContains(M27UnitInfo.refCategoryFatboy, oFiringUnit)
        for iCurWeapon, oWeapon in oBPFiringUnit.Weapon do
            if oWeapon.RangeCategory and (oWeapon.RangeCategory == 'UWRC_DirectFire' or (bIsFatboy and oWeapon.RangeCategory == 'UWRC_IndirectFire')) then
                if bDebugMessages == true then LOG(sFunctionRef..': Have a weapon with range category') end
                if oWeapon.RackBones then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have a weapon with RackBones') end
                    for _, oRackBone in oWeapon.RackBones do
                        if bDebugMessages == true then LOG(sFunctionRef..' Cur oRackBone='..repru(oRackBone)) end
                        if oRackBone.MuzzleBones then
                            sFiringBone = oRackBone.MuzzleBones[1]
                            if bDebugMessages == true then LOG(sFunctionRef..': Found muzzlebone='..sFiringBone) end
                            break
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Cant locate muzzle bone') end
                        end
                    end
                    if sFiringBone then
                        if bIsACU == false then break
                        else
                            --ACU - make sure we have an overcharge weapon (to avoid e.g. cybran laser weapon)
                            if oWeapon.OverChargeWeapon then
                                break
                            end
                        end
                    end
                end
            end
        end
        if sFiringBone then
            tShotStartPosition = oFiringUnit:GetPosition(sFiringBone)
        else
            tShotStartPosition = oFiringUnit:GetPosition()
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tShotStartPosition
end

function IsLineBlockedAborted(aiBrain, tShotStartPosition, tShotEndPosition, iAOE)
    --NOTE: Attempted use of new function CheckBlockingTerrain but it just seemed to return that there was blocking terrain every time when there wasnt, unless documentation is wrong; have left code as will want to investigate at a future point when look to optimise more
    --If iAOE is specified then will end once reach the iAOE range
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsLineBlocked'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bShotIsBlocked = false
    local iFlatDistance = M27Utilities.GetDistanceBetweenPositions(tShotStartPosition, tShotEndPosition)
    local tTerrainPositionAtPoint = {}
    if iFlatDistance > 1 then
        --[[Returns true in case terrain is not blocking weapon fire from attackPosition to targetPosition.
        -- @param attackPosition  Table with position {x, y z}
        -- @param targetPosition position Table with position {x, y z}
        -- @param arcType Types: 'high', 'low', 'none'.
        -- @return true/false
        function CAiBrain:CheckBlockingTerrain(attackPosition, targetPosition, arcType)--]]
        if iAOE and iAOE > 0 then
            local iDistanceFromStartToEnd = M27Utilities.GetDistanceBetweenPositions(tShotEndPosition, tShotStartPosition)
            if iDistanceFromStartToEnd > iAOE then
                tShotEndPosition = M27Utilities.MoveTowardsTarget(tShotEndPosition, tShotStartPosition,  iAOE, 0)
            else
                if bDebugMessages == true then LOG(sFunctionRef..': AOE is greater than distance between positions so returning false') end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return false
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': bShotIsBlocked pre checking for blocking terrain='..tostring(bShotIsBlocked)) end
        bShotIsBlocked = not(aiBrain:CheckBlockingTerrain(tShotStartPosition, tShotEndPosition, 'none'))
        if bDebugMessages == true then LOG(sFunctionRef..': bShotIsBlocked post checking for blocking terrain='..tostring(bShotIsBlocked)) end
    else bShotIsBlocked = false
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bShotIsBlocked
end

function IsLineBlocked(aiBrain, tShotStartPosition, tShotEndPosition, iAOE, bReturnDistanceThatBlocked)
    --If iAOE is specified then will end once reach the iAOE range
    --(aiBrain included as argument as want to retry CheckBlockingTerrain in the future)
    --bReturnDistanceThatBlocked - if true then returns either distance at which shot is blocked, or the distance+1 between the start and end position

    --Angle (looking only at vertical dif) from shot start to shot end, theta: Tan Theta = Opp/Adj, so Theta = tan-1 Opp/Adj
    --Once have this angle, then the height if move vertically to the target is: Sin theta = opp / hyp
    --Opp is the height dif; adj is the distance between start and end (referred to below as iFlatDistance)

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsLineBlocked'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bShotIsBlocked = false
    local iFlatDistance = M27Utilities.GetDistanceBetweenPositions(tShotStartPosition, tShotEndPosition)
    local tTerrainPositionAtPoint = {}
    local bStartHigherThanEnd = false
    if tShotStartPosition[2] > tShotEndPosition[2] then bStartHigherThanEnd = true end
    if iFlatDistance > 1 then
        local iAngleInRadians = math.atan(math.abs((tShotEndPosition[2] - tShotStartPosition[2])) / iFlatDistance)
        local iShotHeightAtPoint
        if bDebugMessages == true then LOG(sFunctionRef..': About to check if at any point on path shot will be lower than terrain; iAngle='..M27Utilities.ConvertAngleToRadians(iAngleInRadians)..'; startshot height='..tShotStartPosition[2]..'; target height='..tShotEndPosition[2]..'; iFlatDistance='..iFlatDistance) end
        local iEndPoint = math.max(1, math.floor(iFlatDistance - (iAOE or 0)))
        for iPointToTarget = 1, iEndPoint do
            --math.min(math.floor(iFlatDistance), math.max(math.floor(iStartDistance or 1),1)), math.floor(iFlatDistance) do
            --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
            tTerrainPositionAtPoint = M27Utilities.MoveTowardsTarget(tShotStartPosition, tShotEndPosition, iPointToTarget, 0)
            if bDebugMessages == true then LOG(sFunctionRef..': iPointToTarget='..iPointToTarget..'; tTerrainPositionAtPoint='..repru(tTerrainPositionAtPoint)) end
            if bStartHigherThanEnd then iShotHeightAtPoint = tShotStartPosition[2] - math.sin(iAngleInRadians) * iPointToTarget
            else iShotHeightAtPoint = tShotStartPosition[2] + math.sin(iAngleInRadians) * iPointToTarget
            end
            if iShotHeightAtPoint <= tTerrainPositionAtPoint[2] then
                if not(iPointToTarget == iEndPoint and iShotHeightAtPoint == tTerrainPositionAtPoint[2]) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': Shot blocked at this position; iPointToTarget='..iPointToTarget..'; iShotHeightAtPoint='..iShotHeightAtPoint..'; tTerrainPositionAtPoint='..tTerrainPositionAtPoint[2])
                        M27Utilities.DrawLocation(tTerrainPositionAtPoint, nil, 5, 10)
                    end
                    bShotIsBlocked = true
                    if bReturnDistanceThatBlocked then
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                        return iPointToTarget
                    end

                    break
                elseif bDebugMessages == true then LOG(sFunctionRef..': Are at end point and terrain height is identical, so will assume we will actually reach the target')
                end
            else
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Shot not blocked at this position, will draw in blue; iPointToTarget='..iPointToTarget..'; iShotHeightAtPoint='..iShotHeightAtPoint..'; tTerrainPositionAtPoint='..tTerrainPositionAtPoint[2]..'; iAngle='..M27Utilities.ConvertAngleToRadians(iAngleInRadians)..'; iPointToTarget='..iPointToTarget..'; tShotStartPosition[2]='..tShotStartPosition[2])
                    M27Utilities.DrawLocation(tTerrainPositionAtPoint, false, 1, 20)
                end
            end
        end
    else bShotIsBlocked = false
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if bReturnDistanceThatBlocked and not(bShotIsBlocked) then return M27Utilities.GetDistanceBetweenPositions(tShotStartPosition, tShotEndPosition) + 1
    else
        return bShotIsBlocked
    end
end

--NOTE: Use IsLineBlocked if have positions instead of units
function IsShotBlocked(oFiringUnit, oTargetUnit)
    --Returns true or false depending on if oFiringUnit can hit oTargetUnit in a straight line
    --intended for direct fire units only
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsShotBlocked'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local bShotIsBlocked = false
    if not(oTargetUnit.GetBlueprint) then bShotIsBlocked = false else

        local oBPFiringUnit = oFiringUnit:GetBlueprint()

        local tShotStartPosition = GetDirectFireWeaponPosition(oFiringUnit)
        if tShotStartPosition then
            if bDebugMessages == true then LOG(sFunctionRef..': tShotStartPosition='..repru(tShotStartPosition)) end
            if tShotStartPosition[2] <= 0 then bShotIsBlocked = true
            else
                local tShotEndPosition = {}
                local oBPTargetUnit = oTargetUnit:GetBlueprint()
                local iLowestHeight = 1000
                local iHighestHeight = -1000
                local sLowestBone, sHighestBone
                local tTargetUnitDefaultPosition = oTargetUnit:GetPosition()
                --Work out where the shot is targetting - not all units will have a bone specified in the AI section, in which case just get the unit position
                if oBPTargetUnit.AI and oBPTargetUnit.AI.TargetBones then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have targetbones in the targetunit blueprint; repr='..repru(oBPTargetUnit.AI.TargetBones)) end
                    --Is the target higher or lower than the shooter? If higher, want the lowest target bone; if lower, want the highest target bone
                    for iBone, sBone in oBPTargetUnit.AI.TargetBones do
                        if oTargetUnit:IsValidBone(sBone) == true then
                            tShotEndPosition = oTargetUnit:GetPosition(sBone)
                            if bDebugMessages == true then LOG(sFunctionRef..' Getting position for sBone='..sBone..'; position='..repru(tShotEndPosition)) end
                            if tShotEndPosition[2] < iLowestHeight then
                                iLowestHeight = tShotEndPosition[2]
                                sLowestBone = sBone
                            end
                            if tShotEndPosition[2] > iHighestHeight then
                                iHighestHeight = tShotEndPosition[2]
                                sHighestBone = sBone
                            end
                        end
                    end
                    --Try alternative approach:
                    if sHighestBone == nil and oTargetUnit.GetBoneCount then
                        local iBoneCount = oTargetUnit:GetBoneCount()
                        local sBone
                        if iBoneCount > 0 then
                            for iCurBone = 0, iBoneCount - 1 do
                                sBone = oTargetUnit:GetBoneName(iCurBone)
                                if sBone then
                                    if oTargetUnit:IsValidBone(sBone) == true then
                                        tShotEndPosition = oTargetUnit:GetPosition(sBone)
                                        if bDebugMessages == true then LOG(sFunctionRef..' Getting position for sBone='..sBone..'; position='..repru(tShotEndPosition)) end
                                        if tShotEndPosition[2] < iLowestHeight then
                                            iLowestHeight = tShotEndPosition[2]
                                            sLowestBone = sBone
                                        end
                                        if tShotEndPosition[2] > iHighestHeight then
                                            iHighestHeight = tShotEndPosition[2]
                                            sHighestBone = sBone
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if sHighestBone == nil then
                    tShotEndPosition = tTargetUnitDefaultPosition
                    if bDebugMessages == true then LOG(sFunctionRef..': Couldnt find a bone to target for target unit, so using its position instaed='..repru(tShotEndPosition)) end
                else
                    if tTargetUnitDefaultPosition[2] > tShotStartPosition[2] then
                        tShotEndPosition = oTargetUnit:GetPosition(sLowestBone)
                        --if tShotEndPosition[2] - GetSurfaceHeight(tShotEndPosition[1], tShotEndPosition[3]) > 0.1 then tShotEndPosition[2] = math.max(GetSurfaceHeight(tShotEndPosition[1], tShotEndPosition[3]) + 0.1, tShotEndPosition[2] - 0.2) end
                    else
                        tShotEndPosition = oTargetUnit:GetPosition(sHighestBone)
                        --if tShotEndPosition[2] - GetSurfaceHeight(tShotEndPosition[1], tShotEndPosition[3]) > 0.1 then tShotEndPosition[2] = math.max(GetSurfaceHeight(tShotEndPosition[1], tShotEndPosition[3]) + 0.1, tShotEndPosition[2] - 0.2) end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': HighestBone='..sHighestBone..'; lowest bone='..sLowestBone..'; tShotEndPosition='..repru(tShotEndPosition)) end
                end
                --Have the shot end and start positions; Now check that not firing at underwater target
                if tShotEndPosition[2] < GetSurfaceHeight(tShotEndPosition[1], tShotEndPosition[3]) then
                    bShotIsBlocked = true
                else
                    --Have the shot end and start positions; now want to move along a line between the two and work out if terrain will block the shot
                    if bDebugMessages == true then LOG(sFunctionRef..': About to see if line is blocked. tShotStartPosition='..repru(tShotStartPosition)..'; tShotEndPosition='..repru(tShotEndPosition)..'; Terrain height at start='..GetTerrainHeight(tShotStartPosition[1], tShotStartPosition[3])..'; Terrain height at end='..GetTerrainHeight(tShotEndPosition[1], tShotEndPosition[3])) end
                    bShotIsBlocked = IsLineBlocked(oFiringUnit:GetAIBrain(), tShotStartPosition, tShotEndPosition)
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bShotIsBlocked
end

function IssueDelayMoveBase(tUnits, tTarget, iDelay)
    local sFunctionRef = 'IssueDelayMoveBase'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicks(iDelay)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    IssueMove(tUnits, tTarget)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function IssueDelayedMove(tUnits, tTarget, iDelay)
    ForkThread(IssueDelayMoveBase, tUnits, tTarget, iDelay)
end

function GetNearestActiveFixedEnemyShield(aiBrain, tLocation)
    --True if the target location has an enemy hsield structure which has active health
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetNearestActiveFixedEnemyShield'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tNearbyShields = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedShield, tLocation, 46, 'Enemy')
    local oNearestShield
    local iNearestShield = 10000
    local iCurShieldDistance

    if M27Utilities.IsTableEmpty(tNearbyShields) == false then
        local iShieldCurHealth, iShieldMaxHealth
        for iShield, oShield in tNearbyShields do
            if M27UnitInfo.IsUnitValid(oShield) then
                iShieldCurHealth, iShieldMaxHealth = M27UnitInfo.GetCurrentAndMaximumShield(oShield)
                if iShieldCurHealth > 50 then
                     iCurShieldDistance = M27Utilities.GetDistanceBetweenPositions(oShield:GetPosition(), tLocation)
                    if iCurShieldDistance < iNearestShield then
                        oNearestShield = oShield
                        iNearestShield = iCurShieldDistance
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oNearestShield
end

function IsLocationUnderFriendlyFixedShield(aiBrain, tTargetPos)
--Based on IsTargetUnderShield, but simplified slightly

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsLocationUnderFriendlyFixedShield'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iShieldSearchRange = 46
    local tNearbyShields = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedShield, tTargetPos, iShieldSearchRange, 'Ally')
    if M27Utilities.IsTableEmpty(tNearbyShields) == false then
        local oCurUnitBP, iCurShieldRadius, iCurDistanceFromTarget
        for iUnit, oUnit in tNearbyShields do
            if not(oUnit.Dead) and oUnit:GetFractionComplete() >= 0.8 then
                oCurUnitBP = oUnit:GetBlueprint()
                iCurShieldRadius = 0
                if oCurUnitBP.Defense and oCurUnitBP.Defense.Shield then
                    iCurShieldRadius = oCurUnitBP.Defense.Shield.ShieldSize * 0.5
                    if iCurShieldRadius > 0 then
                        iCurDistanceFromTarget = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tTargetPos)
                        if bDebugMessages == true then LOG(sFunctionRef..': iCurDistance to shield='..iCurDistanceFromTarget..'; iCurShieldRadius='..iCurShieldRadius..'; shield position='..repru(oUnit:GetPosition())..'; target position='..repru(tTargetPos)) end
                        if iCurDistanceFromTarget <= (iCurShieldRadius - 1) then --if dont decrease by anything then more than half of unit might be under shield which means bombs cant hit it due to the 'snap to' logic e.g. for building placement
                            if bDebugMessages == true then LOG(sFunctionRef..': Shield is large enough to cover target') end
                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                            return true
                        end
                    elseif bDebugMessages == true then LOG(sFunctionRef..': Shield radius isnt >0')
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Blueprint doesnt have a shield value; UnitID='..oUnit.UnitId) end
                end
            elseif bDebugMessages == true then LOG(sFunctionRef..': Unit is dead')
            end
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': tNearbyShields is empty') end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return false
end

function IsTargetUnderShield(aiBrain, oTarget, iIgnoreShieldsWithLessThanThisHealth, bReturnShieldHealthInstead, bIgnoreMobileShields, bTreatPartCompleteAsComplete, bCumulativeShieldHealth)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsTargetUnderShield'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Determines if target is under a shield
    --bCumulativeShieldHealth - if true, then will treat as being under a shield if all shields combined have health of at least iIgnoreShieldsWithLessThanThisHealth
    --if oTarget.UnitId == 'urb4206' then bDebugMessages = true end
    if M27UnitInfo.IsUnitValid(oTarget) and oTarget.GetHealth then
        if bDebugMessages == true and EntityCategoryContains(M27UnitInfo.refCategoryFixedShield, oTarget.UnitId) then
            if oTarget.MyShield.GetHealth then
                LOG(sFunctionRef..': oTarget is a shield='..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..'; Shield ratio='..oTarget:GetShieldRatio(false)..'; Shield ratio true='..oTarget:GetShieldRatio(true)..'; Shield health='..oTarget.MyShield:GetHealth()..'; SHield max health='..oTarget.MyShield:GetMaxHealth()..'; Active consumption='..tostring(oTarget.ActiveConsumption)..'; reprs of shield='..reprs(oTarget.MyShield))
            else
                LOG(sFunctionRef..': oTarget is a shield but it doesnt have a .GetHealth property. target='..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..'reprs of shield='..reprs(oTarget.MyShield))
            end
        end
        if iIgnoreShieldsWithLessThanThisHealth == nil then iIgnoreShieldsWithLessThanThisHealth = 0 end
        local bUnderShield = false
        local iShieldSearchRange = 46 --T3 sera shield is 46; bulwark is 120; will go with sera t3 for now; if changing here then also change reference in getmaxstrikedamage
        --Is the target an enemy?
        local oTBrain = oTarget:GetAIBrain()
        local bEnemy
        if oTBrain == aiBrain then
            bEnemy = false
        else
            local iOurArmyIndex = aiBrain:GetArmyIndex()
            local iTargetArmyIndex = oTBrain:GetArmyIndex()
            if iOurArmyIndex and iTargetArmyIndex then
                bEnemy = IsEnemy(iOurArmyIndex, iTargetArmyIndex)
            else bEnemy = true
            end
        end
        local sSearchType = 'Ally'
        if bEnemy then sSearchType = 'Enemy' end
        local tTargetPos = oTarget:GetPosition()
        local iShieldCategory = M27UnitInfo.refCategoryMobileLandShield + M27UnitInfo.refCategoryFixedShield
        if bIgnoreMobileShields then iShieldCategory = M27UnitInfo.refCategoryFixedShield end
        local tNearbyShields = aiBrain:GetUnitsAroundPoint(iShieldCategory, tTargetPos, iShieldSearchRange, sSearchType)
        if bDebugMessages == true then LOG(sFunctionRef..': Searching for shields around '..repru(tTargetPos)..'; iShieldSearchRange='..iShieldSearchRange..'; sSearchType='..sSearchType) end
        local iShieldCurHealth, iShieldMaxHealth
        local iTotalShieldCurHealth = 0
        local iTotalShieldMaxHealth = 0
        local iMinFractionComplete = 0.95

        local iShieldSizeAdjust = 2 --i.e. if want to be prudent about whether can hit an enemy should be positive, if prudent about whether an ally is protected want a negative value
        if not(bEnemy) then iShieldSizeAdjust = -1 end

        if bTreatPartCompleteAsComplete then iMinFractionComplete = 0 end
        if M27Utilities.IsTableEmpty(tNearbyShields) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Size of tNearbyShields='..table.getn(tNearbyShields)) end
            local oCurUnitBP, iCurShieldRadius, iCurDistanceFromTarget
            for iUnit, oUnit in tNearbyShields do
                if not(oUnit.Dead) and oUnit:GetFractionComplete() >= iMinFractionComplete then
                    oCurUnitBP = oUnit:GetBlueprint()
                    iCurShieldRadius = 0
                    if oCurUnitBP.Defense and oCurUnitBP.Defense.Shield then
                        if bDebugMessages == true then LOG(sFunctionRef..': Target has a shield, will check its shield size and how close that is to the target') end
                        iCurShieldRadius = oCurUnitBP.Defense.Shield.ShieldSize * 0.5
                        if iCurShieldRadius > 0 then
                            iCurDistanceFromTarget = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tTargetPos)
                            if bDebugMessages == true then LOG(sFunctionRef..': iCurDistance to shield='..iCurDistanceFromTarget..'; iCurShieldRadius='..iCurShieldRadius..'; shield position='..repru(oUnit:GetPosition())..'; target position='..repru(tTargetPos)) end
                            if iCurDistanceFromTarget <= (iCurShieldRadius + iShieldSizeAdjust) then --if dont increase by anything then half of unit might be under shield which means bombs cant hit it
                                if bDebugMessages == true then LOG(sFunctionRef..': Shield is large enough to cover target, will check its health') end
                                iShieldCurHealth, iShieldMaxHealth = M27UnitInfo.GetCurrentAndMaximumShield(oUnit)
                                iTotalShieldCurHealth = iTotalShieldCurHealth + iShieldCurHealth
                                iTotalShieldMaxHealth = iTotalShieldMaxHealth + iShieldMaxHealth
                                if bTreatPartCompleteAsComplete or (oUnit:GetFractionComplete() >= 0.95 and oUnit:GetFractionComplete() < 1) then iShieldCurHealth = iShieldMaxHealth end
                                if bDebugMessages == true then LOG(sFunctionRef..': iShieldCurHealth='..iShieldCurHealth..'; iIgnoreShieldsWithLessThanThisHealth='..iIgnoreShieldsWithLessThanThisHealth) end
                                if (not(bCumulativeShieldHealth) and iShieldCurHealth >= iIgnoreShieldsWithLessThanThisHealth) or (bCumulativeShieldHealth and iTotalShieldCurHealth >= iIgnoreShieldsWithLessThanThisHealth) then
                                    bUnderShield = true
                                    if bDebugMessages == true then LOG(sFunctionRef..': Shield health more than threshold so unit is under a shield') end
                                    if not(bReturnShieldHealthInstead) then break end
                                end
                            end
                        elseif bDebugMessages == true then LOG(sFunctionRef..': Shield radius isnt >0')
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Blueprint doesnt have a shield value; UnitID='..oUnit.UnitId) end
                    end
                elseif bDebugMessages == true then LOG(sFunctionRef..': Unit is dead')
                end
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': tNearbyShields is empty') end
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        if bReturnShieldHealthInstead then
            return iTotalShieldCurHealth, iTotalShieldMaxHealth
        else return bUnderShield
        end
    end
end

function GetRandomPointInAreaThatCanPathTo(sPathing, iSegmentGroup, tMidpoint, iMaxDistance, iMinDistance, bDebugMode)
    --Tries to find a random location in a square around tMidpoint that can path to; returns nil if couldnt find anywhere
    local sFunctionRef = 'GetRandomPointInAreaThatCanPathTo'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = (bDebugMode or false) if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    --if sPathing == M27UnitInfo.refPathingTypeAir then bDebugMessages = true end





    local iLoopCount = 0
    local iMaxLoop1 = 6
    local iMaxLoop2 = iMaxLoop1 + 8
    local iMaxLoop3 = iMaxLoop2 + 4
    local tEndDestination

    local iMidSegmentX, iMidSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tMidpoint)
    local iSegmentMaxRange = iMaxDistance / M27MapInfo.iSizeOfBaseLevelSegment
    local iSegmentMinRange = iMinDistance / M27MapInfo.iSizeOfBaseLevelSegment


    local iMinSegmentX = math.max(1, iMidSegmentX - iSegmentMaxRange)
    local iMaxSegmentX = math.min(M27MapInfo.iMaxBaseSegmentX, iMidSegmentX + iSegmentMaxRange)
    local iMinSegmentZ = math.max(1, iMidSegmentZ - iSegmentMaxRange)
    local iMaxSegmentZ = math.min(M27MapInfo.iMaxBaseSegmentZ, iMidSegmentZ + iSegmentMaxRange)

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, sPathing='..sPathing..'; iSegmentGroup='..(iSegmentGroup or 'nil')..'; tMidpoint='..repru(tMidpoint)..'; iMaxDistance='..iMaxDistance..'; iMinDistance='..iMinDistance..'; Mid segments='..iMidSegmentX..'-'..iMidSegmentZ..'; iMinSegmentX-Z='..iMinSegmentX..'-'..iMinSegmentZ..'; iMaxSegmentX-Z='..iMaxSegmentX..'-'..iMaxSegmentZ..'; M27MapInfo.iSizeOfBaseLevelSegment='..M27MapInfo.iSizeOfBaseLevelSegment) end

    local iConstraintMinX = math.max(1, iMidSegmentX - iSegmentMinRange)
    local iConstraintMaxX = math.min(M27MapInfo.iMaxBaseSegmentX, iMidSegmentX + iSegmentMinRange)
    local iConstraintMinZ = math.max(1, iMidSegmentZ - iSegmentMinRange)
    local iConstraintMaxZ = math.min(M27MapInfo.iMaxBaseSegmentZ, iMidSegmentZ + iSegmentMinRange)

    local iCurMinSegmentZ, iCurMaxSegmentZ
    local iRandX, iRandZ
    local iRandFlag
    local iPathingTarget
    local bTryManualAlternative = false
    local tiManualRandomStart
    local tiManualSegments --
    local iSegmentThickness
    local tiMinRangeAttempt = {
        {iMinSegmentX, iMinSegmentZ},
        {iMinSegmentX, -iMinSegmentZ},
        {-iMinSegmentX, -iMinSegmentZ},
        {iMinSegmentX, -iMinSegmentZ},
    }

    if bDebugMessages == true then
        LOG(sFunctionRef..': About to search between Segment min and max X of '..iMinSegmentX..'-'..iMaxSegmentX..'; and Z min and max of '..iMinSegmentZ..'-'..iMaxSegmentZ..' if the pathing target of each point checked is different to iSegmentGroup'..iSegmentGroup..'; iMidSegmentX='..iMidSegmentX..'; iSegmentMaxRange='..iSegmentMaxRange..'; iMidSegment'..iMidSegmentZ)

    end
    while not(iPathingTarget == iSegmentGroup) do
        iLoopCount = iLoopCount + 1
        if iLoopCount > iMaxLoop1 then
            if bDebugMessages == true then LOG(sFunctionRef..': Failed to find anywhere in the first '..iMaxLoop1..' attempts so will try alternative approach. bTryManualAlternative='..tostring(bTryManualAlternative)) end
            if bTryManualAlternative == false then
                bTryManualAlternative = true
                iSegmentThickness = math.max(1, math.floor((iMaxDistance - iMinDistance) / M27MapInfo.iSizeOfBaseLevelSegment))
                tiManualRandomStart = {math.random(0, 7), math.random(0, 7)}
                tiManualSegments = {
                    {iMinSegmentX + iSegmentThickness, iMinSegmentZ + iSegmentThickness },
                    {math.floor((iMaxSegmentX - iMinSegmentX) * 0.5), iMinSegmentZ + iSegmentThickness },
                    {iMaxSegmentX - iSegmentThickness, iMinSegmentZ + iSegmentThickness},
                    {iMaxSegmentX - iSegmentThickness, math.floor((iMaxSegmentZ - iMinSegmentZ) * 0.5)},
                    {iMaxSegmentX - iSegmentThickness, iMaxSegmentZ - iSegmentThickness},
                    {math.floor((iMaxSegmentX - iMinSegmentX) * 0.5), iMaxSegmentZ - iSegmentThickness },
                    {iMinSegmentX + iSegmentThickness, iMaxSegmentZ - iSegmentThickness},
                    {iMinSegmentX + iSegmentThickness, math.floor((iMaxSegmentZ - iMinSegmentZ) * 0.5)},
                    --Copy above so can just pick a random point 1-8 in the table
                    {iMinSegmentX + iSegmentThickness, iMinSegmentZ + iSegmentThickness },
                    {math.floor((iMaxSegmentX - iMinSegmentX) * 0.5), iMinSegmentZ + iSegmentThickness },
                    {iMaxSegmentX - iSegmentThickness, iMinSegmentZ + iSegmentThickness},
                    {iMaxSegmentX - iSegmentThickness, math.floor((iMaxSegmentZ - iMinSegmentZ) * 0.5)},
                    {iMaxSegmentX - iSegmentThickness, iMaxSegmentZ - iSegmentThickness},
                    {math.floor((iMaxSegmentX - iMinSegmentX) * 0.5), iMaxSegmentZ - iSegmentThickness },
                    {iMinSegmentX + iSegmentThickness, iMaxSegmentZ - iSegmentThickness},
                    {iMinSegmentX + iSegmentThickness, math.floor((iMaxSegmentZ - iMinSegmentZ) * 0.5)}
                }
                if bDebugMessages == true then LOG(sFunctionRef..': tiManualSegments='..repru(tiManualSegments)..'; tiManualRandomStart='..repru(tiManualRandomStart)..'; iSegmentThickness='..iSegmentThickness) end

            end
            if iLoopCount > iMaxLoop3 then

                M27Utilities.ErrorHandler('Couldnt find random point in area after looking a few times', true)
                if bDebugMessages == true then LOG(sFunctionRef..': iMaxLoop3='..iMaxLoop3..'; tMidpoint='..math.floor(tMidpoint[1])..'-'..math.floor(tMidpoint[2])..'-'..math.floor(tMidpoint[3])..'; iMaxDistance='..iMaxDistance..'; iMinDistance='..iMinDistance..'; sPathing='..sPathing..'; iSegmentGroup='..iSegmentGroup..'; Start position 1 grouping of this map='..M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[1])..';hopefully the code that called this should recheck pathing') end
                if bDebugMessages == true then
                    --Draw midpoint in white, draw last place checked in gold
                    M27Utilities.DrawLocation(M27MapInfo.GetPositionFromPathingSegments(iRandX, iRandZ), nil, 4, 20)
                    M27Utilities.DrawLocation(tMidpoint, nil, 7, 20)
                end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return nil
            end
        end
        if bTryManualAlternative == false then

            --Get random position in the X range first
            iRandX = math.random(iMinSegmentX, iMaxSegmentX)
            --Set the revised Z range to look from
            if iRandX <= iConstraintMinX or iRandX >= iConstraintMaxX then
                --Wherever we are we're outside the X range cosntraint so will be far enough away
                iCurMinSegmentZ = iMinSegmentZ
                iCurMaxSegmentZ = iMaxSegmentZ
            else
                --We're within range of the X constraints so our Z value must be outside the range
                iRandFlag = math.random(0, 1)
                if iRandFlag == 0 then
                    iCurMinSegmentZ = iMinSegmentZ
                    iCurMaxSegmentZ = iConstraintMinZ
                else
                    iCurMinSegmentZ = iConstraintMaxZ
                    iCurMaxSegmentZ = iMaxSegmentZ
                end
            end
            iRandZ = math.random(iCurMinSegmentZ, iCurMaxSegmentZ)
        else
            --Have tried randomly and failed, now just try by looking at NW/N/NE/E etc. randomly
            if iLoopCount < iMaxLoop2 then
                iRandX = tiManualSegments[iLoopCount - iMaxLoop1 + tiManualRandomStart[1]][1]
                iRandZ = tiManualSegments[iLoopCount - iMaxLoop1 + tiManualRandomStart[2]][2]
                if bDebugMessages == true then LOG(sFunctionRef..': tiManualRandomStart='..repru(tiManualRandomStart)..'; X segment to use='..(iLoopCount - iMaxLoop1 + tiManualRandomStart[1])..'; Z segment to use='..(iLoopCount - iMaxLoop1 + tiManualRandomStart[2])..'; iRandX='..iRandX..'; iRandZ='..iRandZ) end
            else
                iRandX = tiMinRangeAttempt[iMaxLoop3 - iLoopCount][1]
                iRandZ = tiMinRangeAttempt[iMaxLoop3 - iLoopCount][2]
            end
        end

        iPathingTarget = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iRandX, iRandZ)

        if bDebugMessages == true then
            LOG(sFunctionRef..': iLoopCount='..iLoopCount..'; Target='..repru(M27MapInfo.GetPositionFromPathingSegments(iRandX, iRandZ))..'; iRandX='..iRandX..'; iRandZ='..iRandZ..'; iPathingTarget (i.e. group) ='..iPathingTarget..'; will draw in red unless can path there in which case in blue')
            if not(iPathingTarget == iSegmentGroup) then
                M27Utilities.DrawLocation(M27MapInfo.GetPositionFromPathingSegments(iRandX, iRandZ), nil, 2, 100)
            else M27Utilities.DrawLocation(M27MapInfo.GetPositionFromPathingSegments(iRandX, iRandZ), nil, 1, 100)
            end
        end
    end
    if iPathingTarget == iSegmentGroup then
        tEndDestination = M27MapInfo.GetPositionFromPathingSegments(iRandX, iRandZ)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tEndDestination
end

function GetNearestFirebase(aiBrain, tPosition, bMustHaveShield)
    local sFunctionRef = 'GetNearestFirebase'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Returns nil if no nearby firebase
    if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef]) == false then
        local bHasShield = bMustHaveShield
        local iCurDist
        local iClosestDist = 10000
        local iClosestFirebaseRef
        for iFirebaseRef, tFirebaseUnits in aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef] do
            if not(bMustHaveShield) then
                for iUnit, oUnit in tFirebaseUnits do
                    if EntityCategoryContains(M27UnitInfo.refCategoryFixedShield, oUnit.UnitId) then
                        bHasShield = true
                        break
                    end
                end
            end
            if bHasShield then --Eitherh as shield, or not bothered if it ahs a shield
                iCurDist = M27Utilities.GetDistanceBetweenPositions(tPosition, aiBrain[M27EngineerOverseer.reftFirebasePosition][iFirebaseRef])
                if iCurDist < iClosestDist then
                    iClosestFirebaseRef = iFirebaseRef
                    iClosestDist = iCurDist
                end
            end
        end
        if iClosestFirebaseRef then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return aiBrain[M27EngineerOverseer.reftFirebasePosition][iClosestFirebaseRef]
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return nil
end

function GetNearestRallyPoint(aiBrain, tPosition, oOptionalPathingUnit, bSecondTimeRun)
    --Todo - longer term want to integrate this with forward base logic
    --NOTE: Air overseer uses custom copy of this with some variations to get air rally point
    --OptionalPathingUnit - mainly for issues caused by units thinking they are on a plateau
    --If are turtling will return the chokepoint

    local sFunctionRef = 'GetNearestRallyPoint'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    --if GetGameTimeSeconds() >= 1065 then bDebugMessages = true end

    --Are we in same amphibious pathing group? If not then will want to get alternative position to move to
    local iPlateauGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tPosition)
    if bDebugMessages == true then LOG(sFunctionRef..': Near start of code. iPlateauGroup='..iPlateauGroup..'; BasePlateauGroup='..aiBrain[M27MapInfo.refiOurBasePlateauGroup]) end
    if not(iPlateauGroup == aiBrain[M27MapInfo.refiOurBasePlateauGroup]) then
        --Do we have any land factories in the plateau? If so then go to the nearest of these
        local iNearestDist = 10000
        local iCurDist
        local tPotentialLocation
        if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup]) == false and M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup][M27MapInfo.subrefPlateauLandFactories]) == false then
            for iFactory, oFactory in aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup][M27MapInfo.subrefPlateauLandFactories] do
                iCurDist = M27Utilities.GetDistanceBetweenPositions(tPosition, oFactory:GetPosition())
                if iCurDist < iNearestDist then
                    iNearestDist = iCurDist
                    tPotentialLocation = oFactory:GetPosition()
                end
            end
        end
        if not(tPotentialLocation) then
            --Do we have a mex location to go to? If so pick the one closest to our base
            if M27Utilities.IsTableEmpty(M27MapInfo.tAllPlateausWithMexes[iPlateauGroup]) == false and M27Utilities.IsTableEmpty(M27MapInfo.tAllPlateausWithMexes[iPlateauGroup][M27MapInfo.subrefPlateauMexes]) == false then
                for iMex, tMex in M27MapInfo.tAllPlateausWithMexes[iPlateauGroup][M27MapInfo.subrefPlateauMexes] do
                    iCurDist = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tMex)
                    if iCurDist < iNearestDist then
                        tPotentialLocation = tMex
                        iNearestDist = iCurDist
                    end
                end
            end
            if not(tPotentialLocation) then
                --Check the pathing
                if M27UnitInfo.IsUnitValid(oOptionalPathingUnit) and M27MapInfo.RecheckPathingOfLocation(M27UnitInfo.GetUnitPathingType(oOptionalPathingUnit), oOptionalPathingUnit, tPosition) then
                    if not(bSecondTimeRun) then
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                        return GetNearestRallyPoint(aiBrain, tPosition, oOptionalPathingUnit, true)
                    else
                        tPotentialLocation = {tPosition[1] + math.random(-10, 10), tPosition[2], tPosition[3] + math.random(-10, 10)}
                        tPotentialLocation[2] = GetTerrainHeight(tPotentialLocation[1], tPotentialLocation[3])
                        M27Utilities.ErrorHandler('Couldnt find a mex or land factory on the plateau so will just return a random position nearby')
                    end
                else
                    if M27UnitInfo.IsUnitValid(oOptionalPathingUnit) then
                        M27Utilities.ErrorHandler('Couldnt find a mex or land factory on the plateau. already done a check of pathing, and we also have a valid pathing unit; will just return a random location near the current position', true)
                    else
                        --No pathing unit so could be expected - e.g. one cause is a platoon being disbanded will call the nearest rally point - if there is no front unit then it may return an error
                    end
                    tPotentialLocation = {tPosition[1] + math.random(-10, 10), tPosition[2], tPosition[3] + math.random(-10, 10)}
                    tPotentialLocation[2] = GetTerrainHeight(tPotentialLocation[1], tPotentialLocation[3])

                end
            end
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return tPotentialLocation
    else
        --Refresh rally points if we've not refreshed in a while
        M27MapInfo.RecordAllRallyPoints(aiBrain)

        --if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle and aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef][aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef]]) == false and table.getsize(aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef][aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef]]) >= 3 then
        --M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        --return {aiBrain[M27MapInfo.reftChokepointBuildLocation][1], aiBrain[M27MapInfo.reftChokepointBuildLocation][2], aiBrain[M27MapInfo.reftChokepointBuildLocation][3]}
        --else
        --Cycle through all rally points and pick the closest to tPosition
        local iNearestToStart = 10000
        local iNearestRallyPoint, iCurDistanceToStart
        if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftRallyPoints]) then
            if GetGameTimeSeconds() >= 150 then
                M27Utilities.ErrorHandler('Dont have any rally point >=2.5m into the game, wouldve expected to have generated intel paths by now; will return base as a rally point', true)
            end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        else


            for iRallyPoint, tRallyPoint in aiBrain[M27MapInfo.reftRallyPoints] do
                iCurDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tPosition, aiBrain[M27MapInfo.reftRallyPoints][iRallyPoint])
                if bDebugMessages == true then LOG(sFunctionRef..': Considering iRallyPoint='..iRallyPoint..' at position '..repru(tRallyPoint)..'; Distance to our position='..M27Utilities.GetDistanceBetweenPositions(tPosition, tRallyPoint)) end
                if iCurDistanceToStart < iNearestToStart then
                    iNearestRallyPoint = iRallyPoint
                end
            end

            --Do we have a firebase near here?
            local tNearbyFirebase = GetNearestFirebase(aiBrain, aiBrain[M27MapInfo.reftRallyPoints][iNearestRallyPoint], false)
            if M27Utilities.IsTableEmpty(tNearbyFirebase) == false and (M27Utilities.GetDistanceBetweenPositions(tNearbyFirebase, aiBrain[M27MapInfo.reftRallyPoints][iNearestRallyPoint]) <= 40 or M27Utilities.GetDistanceBetweenPositions(tPosition, tNearbyFirebase) <= (iNearestToStart + 40)) then
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return M27Utilities.MoveInDirection(tNearbyFirebase, M27Utilities.GetAngleFromAToB(tNearbyFirebase, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]), 12, true)
            else
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return {aiBrain[M27MapInfo.reftRallyPoints][iNearestRallyPoint][1], aiBrain[M27MapInfo.reftRallyPoints][iNearestRallyPoint][2], aiBrain[M27MapInfo.reftRallyPoints][iNearestRallyPoint][3]}
            end
        end
        --end
        --[[ Previous code based on mex patrol locations:
        local tMexPatrolLocations = M27MapInfo.GetMexPatrolLocations(aiBrain)
        local iNearestToStart = 10000
        local tNearestMex
        local iCurDistanceToStart
        local tOurStart = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        for iMex, tMexLocation in tMexPatrolLocations do
            iCurDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tOurStart, tMexLocation)
            if iCurDistanceToStart < iNearestToStart then
                iNearestToStart = iCurDistanceToStart
                tNearestMex = tMexLocation
            end
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return tNearestMex--]]
    end
end

function GetPositionToSideOfTarget(oUnit, tTargetLocation, iBaseAngleToTarget, iDistanceToMove)
    --NOTE: Largely replaced by the M27Utilities moveindirection function
    --Copy of comments from platoonutilities (in case need to refer to later)
    --[[
                        If our ACU angle is 0 (enemy ACU is north of us):
                            -If a platoon angle is between 1 and 179 to enemy ACU then they're to the left, and want the end posiion to be to the left (so 270 degrees from base position)
                            -If a platoon angle is between 181 and 359 then they're to the right, and want end position to be to the right (so 90 degrees from base position)
                        If our ACU angle is 90 (enemy ACU is to the right of us): Want to split between units above, and units below us
                            --	If a platoon angle is between 91 and 269 then theyre above, if between 271 and 89 theyre below
                        --If our ACU angle is 135 (enemy ACU is south-east of our ACU):
                             Want to split between units based on a threshold of 135
                         If our ACU angle is 359 then want platoon angle between 0-178 to go in direction 269; and 179-358 to go 89 degrees from base position
                         --]]

    --local iDestinationAngleOffset = iOurACUAngleToTarget + 90
    --local iInverseThresholdAngleUpper = iOurACUAngleToTarget + 180

    --Rework all numbers based on ACU angle of 360 so my head hurts less trying to do the simple maths...

    --E.g.: tTargetLocation is the position of our ACU; iBaseAngleToTarget is the angle of our ACU to the enemy ACU; our ACU is trying to get enemy ACU, which is north-east (45 degrees):
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetPositionToSideOfTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code: tTargetLocation='..repru(tTargetLocation)..'; oUnit:GetPosition()='..repru(oUnit:GetPosition())..'; iBaseAngleToTarget='..iBaseAngleToTarget..'; iDistanceToMove='..iDistanceToMove) end
    local iOurACUAngleToTarget = iBaseAngleToTarget
    local iPreRebasingAngleToMove
    local iTempRebasingAdjust = 360 - iOurACUAngleToTarget --=315 in this example

    --e.g. We have a platoon which is behind our ACU, and for which our ACU is east (90 degrees)
    local iPlatoonAngleToTarget = M27Utilities.GetAngleFromAToB(oUnit:GetPosition(), tTargetLocation) --90 degrees in this example
    if bDebugMessages == true then LOG(sFunctionRef..': iPlatoonAngleToTarget='..iPlatoonAngleToTarget..'; iTempRebasingAdjust='..iTempRebasingAdjust) end
    local iPlatoonAnglePostRebasing = iPlatoonAngleToTarget + iTempRebasingAdjust --405 in this eg
    if iPlatoonAnglePostRebasing > 360 then iPlatoonAnglePostRebasing = iPlatoonAnglePostRebasing - 360 end --45 in this eg

    if iPlatoonAnglePostRebasing < 180 then
        iPreRebasingAngleToMove = 270 --270 in this eg
    else iPreRebasingAngleToMove = 90 end


    --Rebase all numbers now
    local iPostRebasingAngleToMove = iPreRebasingAngleToMove - iTempRebasingAdjust -- -45 in this eg
    if iPostRebasingAngleToMove < 0 then iPostRebasingAngleToMove = iPostRebasingAngleToMove + 360 end --315 in this eg
    if bDebugMessages == true then LOG(sFunctionRef..': About to call MoveInDirection, tTargetLocation='..repru(tTargetLocation)..'; iPostRebasingAngleToMove='..iPostRebasingAngleToMove..'; iDistanceToMove='..iDistanceToMove..'; iPreRebasingAngleToMove='..iPreRebasingAngleToMove..'; iTempRebasingAdjust='..iTempRebasingAdjust) end
    local tDestination = M27Utilities.MoveInDirection(tTargetLocation, iPostRebasingAngleToMove, iDistanceToMove) --Should try to move north-west of our ACU (which is what we want)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tDestination
end

function ForkedCheckForAnotherMissile(oUnit)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ForkedCheckForAnotherMissile'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if not(oUnit['M27MissileChecker'] == true) then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitSeconds(1) --make sure we have an accurate number for missiles
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        local iMissiles = 0
        if oUnit.GetTacticalSiloAmmoCount then iMissiles = iMissiles + oUnit:GetTacticalSiloAmmoCount() end
        if oUnit.GetNukeSiloAmmoCount then iMissiles = iMissiles + oUnit:GetNukeSiloAmmoCount() end
        if iMissiles >= 2 then
            oUnit['M27MissileChecker'] = true
            while M27UnitInfo.IsUnitValid(oUnit) do
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitSeconds(10)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                if M27UnitInfo.IsUnitValid(oUnit) then
                    iMissiles = 0
                    if oUnit.GetTacticalSiloAmmoCount then iMissiles = iMissiles + oUnit:GetTacticalSiloAmmoCount() end
                    if oUnit.GetNukeSiloAmmoCount then iMissiles = iMissiles + oUnit:GetNukeSiloAmmoCount() end
                    if bDebugMessages == true then LOG(sFunctionRef..': iMissiles='..iMissiles) end
                    if iMissiles < 2 then
                        oUnit:SetPaused(false)
                        if bDebugMessages == true then LOG(sFunctionRef..': Will change unit state so it isnt paused') end
                        break
                    end
                else
                    break
                end

            end
        else
            if M27UnitInfo.IsUnitValid(oUnit) then oUnit:SetPaused(false) end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end
function CheckIfWantToBuildAnotherMissile(oUnit)
    ForkThread(ForkedCheckForAnotherMissile, oUnit)
end

function GetDamageFromBomb(aiBrain, tBaseLocation, iAOE, iDamage, iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, bCumulativeShieldHealthCheck, iOptionalSizeAdjust, iOptionalModIfNeedMultipleShots, iMobileValueOverrideFactorWithin75Percent, bT3ArtiShotReduction, iOptionalShieldReductionFactor)
    --iFriendlyUnitDamageReductionFactor - optional, assumed to be 0 if not specified; will reduce the damage from the bomb by any friendly units in the aoe
    --iFriendlyUnitAOEFactor - e.g. if 2, then will search for friendly units in 2x the aoe
    --bCumulativeShieldHealthCheck - if true, then will treat a unit as unshielded if its cumulative shield health check is below the damage
    --iOptionalSizeAdjust - Defaults to 1, % of value to assign to a normal (mex sized) target; if this isn't 1 then will adjust values accordingly, with T3 power given a value of 1, larger buildings given a greater value, and T1 PD sized buildings given half of iOptionalSizeAdjust
    --iOptionalModIfNeedMultipleShots - Defaults to 0.1; % of value to assign if we wont kill the target with a single shot (experimentals will always give at least 0.5 value)
    --bT3ArtiShotReduction - if true then will reduce value of targets where we have fired lots of shots at them
    --iOptionalShieldReductionFactor - if shields exceed iDamage, then this will be used in place of 0 (the default)

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetDamageFromBomb'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local bIgnoreT3ArtiShotReduction = not(bT3ArtiShotReduction or false)



    local iTotalDamage = 0
    local tEnemiesInRange = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand + M27UnitInfo.refCategoryStructure + M27UnitInfo.refCategoryAllNavy + M27UnitInfo.refCategoryAllAir * categories.EXPERIMENTAL, tBaseLocation, iAOE + 4, 'Enemy')
    local oCurBP
    local iMassFactor
    local iCurHealth, iMaxHealth, iCurShield, iMaxShield
    local tFriendlyUnits
    local iSizeAdjustFactor = iOptionalSizeAdjust or 1
    local iDifBetweenSize8And2 = 0

    local tiSizeAdjustFactors
    local iFactorIfWontKill = iOptionalModIfNeedMultipleShots or 0.1
    if not(iSizeAdjustFactor == 1) then
        iDifBetweenSize8And2 = iSizeAdjustFactor - 1
        --Key values are 1, 2 (Mex), 6 (T2 pgen), 8 (T3 PGen), 10 (rapidfire arti); could potentially go up to 20 (czar)
        tiSizeAdjustFactors = {[1] = 2, [2] = 1, [3] = 0.9, [4] = 0.75, [5] = 0.6, [6] = 0.5, [7] = 0.3, [8] = 0, [9] = -0.1, [10] = -0.25}

    end

    function GetBuildingSizeFactor(sBlueprint)
        if iSizeAdjustFactor == 1 then
            return 1
        else
            local tSize = M27UnitInfo.GetBuildingSize(sBlueprint)
            local iCurSize = math.floor(tSize[1], tSize[2])
            if bDebugMessages == true then LOG(sFunctionRef..': iCurSize='..iCurSize..'; tiSizeAdjustFactors[iCurSize]='..(tiSizeAdjustFactors[iCurSize] or 'nil')..'; expected factor='..1 + (tiSizeAdjustFactors[iCurSize] or -0.35) * iDifBetweenSize8And2) end

            return 1 + (tiSizeAdjustFactors[iCurSize] or -0.35) * iDifBetweenSize8And2
        end
    end

    if iFriendlyUnitDamageReductionFactor then
        --Reduce damage dealt based on nearby friendly units

        tFriendlyUnits = aiBrain:GetUnitsAroundPoint(categories.ALLUNITS - categories.BENIGN - M27UnitInfo.refCategorySatellite, tBaseLocation, iAOE * (iFriendlyUnitAOEFactor or 1), 'Ally')
        if M27Utilities.IsTableEmpty(tFriendlyUnits) == false then
            for iUnit, oUnit in tFriendlyUnits do
                if oUnit.GetBlueprint and not(oUnit.Dead) then
                    if EntityCategoryContains(categories.COMMAND, oUnit.UnitId) then
                        if ScenarioInfo.Options.Victory == "demoralization" then
                            iTotalDamage = iTotalDamage - 100000
                        else
                            iTotalDamage = iTotalDamage - 15000 * iFriendlyUnitDamageReductionFactor
                        end
                    else
                        iTotalDamage = iTotalDamage - oUnit:GetBlueprint().Economy.BuildCostMass * oUnit:GetFractionComplete() * iFriendlyUnitDamageReductionFactor
                    end
                end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Is table of enemies in range empty='..tostring(M27Utilities.IsTableEmpty(tEnemiesInRange))) end
    if M27Utilities.IsTableEmpty(tEnemiesInRange) == false then
        local iShieldThreshold = math.max(iDamage * 0.9, iDamage - 500)
        local iCurDist
        local iMobileDamageDistThreshold = iAOE * 0.75
        local iMobileDamageFactorWithinThreshold
        local iMobileDamageFactorOutsideThreshold = 0.2
        local iMobileDamageNotMovingWithinThreshold
        local iMobileDamageFactorOutsideThresholdMoving
        if iMobileValueOverrideFactorWithin75Percent then
            iMobileDamageFactorWithinThreshold = math.max(iMobileDamageFactorOutsideThreshold, iMobileValueOverrideFactorWithin75Percent)
        else
            if iAOE >= 3.5 then iMobileDamageFactorWithinThreshold = iMobileDamageFactorOutsideThreshold * 1.25
            else
                iMobileDamageFactorWithinThreshold = iMobileDamageFactorOutsideThreshold
            end
        end
        iMobileDamageNotMovingWithinThreshold = math.min(iMobileDamageFactorWithinThreshold + 0.1, iMobileDamageFactorWithinThreshold * 1.5, 1)
        iMobileDamageFactorWithinThreshold = math.max(iMobileDamageFactorWithinThreshold - 0.1, iMobileDamageFactorWithinThreshold * 0.5) --value for if we are moving
        iMobileDamageFactorOutsideThresholdMoving = math.max(iMobileDamageFactorOutsideThreshold - 0.1, iMobileDamageFactorOutsideThreshold * 0.5)

        for iUnit, oUnit in tEnemiesInRange do
            if oUnit.GetBlueprint and not(oUnit.Dead) and oUnit:GetFractionComplete() == 1 or not(EntityCategoryContains(categories.AIR * categories.MOBILE, oUnit.UnitId)) then
                iMassFactor = 1
                oCurBP = oUnit:GetBlueprint()
                --Is the unit within range of the aoe?
                iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tBaseLocation)
                if bDebugMessages == true then LOG(sFunctionRef..': Considering unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Distance to base location='..M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tBaseLocation)..'; iAOE='..iAOE) end
                if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tBaseLocation) <= iAOE then
                    --Is the unit shielded by more than 90% of our damage?
                    --IsTargetUnderShield(aiBrain, oTarget, iIgnoreShieldsWithLessThanThisHealth, bReturnShieldHealthInstead, bIgnoreMobileShields, bTreatPartCompleteAsComplete, bCumulativeShieldHealth)
                    if IsTargetUnderShield(aiBrain, oUnit, iShieldThreshold, false, false, nil, bCumulativeShieldHealthCheck) then iMassFactor = (iOptionalShieldReductionFactor or 0) end
                    if bDebugMessages == true then LOG(sFunctionRef..': Mass factor after considering if under shield='..iMassFactor) end
                    if iMassFactor > 0 then
                        iCurShield, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oUnit)
                        iCurHealth = iCurShield + oUnit:GetHealth()
                        iMaxHealth = iMaxShield + oUnit:GetMaxHealth()
                        --Set base mass value based on health
                        if not(iFactorIfWontKill == 1) then
                            if iDamage >= iMaxHealth or iDamage >= math.min(iCurHealth * 3, iCurHealth + 1000) then
                                --Do nothing - stick with default mass factor of 1
                            else
                                --Still some value in damaging a unit (as might get a second strike), but far less than killing it

                                if EntityCategoryContains(categories.EXPERIMENTAL, oUnit.UnitId) then
                                    iMassFactor = iMassFactor * math.max(0.5, iFactorIfWontKill)
                                else
                                    iMassFactor = iMassFactor * iFactorIfWontKill
                                end
                            end
                        end
                        --Adjust for building size if specified (e.g. useful for if firing from unit with randomness factor)
                        iMassFactor = iMassFactor * GetBuildingSizeFactor(oUnit.UnitId)
                        if bDebugMessages == true then LOG(sFunctionRef..': oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iMassFactor after considering if will kill it and how large it is='..iMassFactor..'; iFactorIfWontKill='..iFactorIfWontKill..'; Building size factor='..GetBuildingSizeFactor(oUnit.UnitId)) end
                        --Is the target mobile and not under construction? Then reduce to 20% as unit might dodge or not be there when bomb lands
                        if oUnit:GetFractionComplete() == 1 then
                            if EntityCategoryContains(categories.MOBILE, oUnit.UnitId) then
                                if iCurDist <= iMobileDamageDistThreshold then
                                    if oUnit:IsUnitState('Moving') then
                                        iMassFactor = iMassFactor * iMobileDamageFactorWithinThreshold
                                    else
                                        iMassFactor = iMassFactor * iMobileDamageNotMovingWithinThreshold
                                    end
                                else
                                    if oUnit:IsUnitState('Moving') then
                                        iMassFactor = iMassFactor * iMobileDamageFactorOutsideThresholdMoving
                                    else
                                        iMassFactor = iMassFactor * iMobileDamageFactorOutsideThreshold
                                    end
                                end
                                --Is it a mex that will be killed outright and/or a volatile structure? Then increase the value of killing it
                            elseif iMassFactor >= 1 and EntityCategoryContains(categories.MASSEXTRACTION + categories.VOLATILE, oUnit.UnitId) then iMassFactor = iMassFactor * 2
                            end
                        end
                        if bT3ArtiShotReduction then
                            if (oUnit[refiT3ArtiShotCount] >= iT3ArtiShotThreshold) then
                                iMassFactor = iMassFactor * 0.1
                            elseif (oUnit[refiT3ArtiLifetimeShotCount] or 0) >= iT3ArtiShotLifetimeThreshold then
                                iMassFactor = iMassFactor * math.max(0.1, 0.4 * oUnit[refiT3ArtiLifetimeShotCount] / iT3ArtiShotLifetimeThreshold)
                            end
                        end
                        iTotalDamage = iTotalDamage + oCurBP.Economy.BuildCostMass * oUnit:GetFractionComplete() * iMassFactor
                        --Increase further for SML and SMD that might have a missile
                        if EntityCategoryContains(M27UnitInfo.refCategorySML - M27UnitInfo.refCategoryBattleship, oUnit.UnitId) then
                            if oUnit:GetFractionComplete() == 1 then
                                iTotalDamage = iTotalDamage + 12000 * math.min(iMassFactor, 1)
                            end
                        elseif EntityCategoryContains(M27UnitInfo.refCategorySMD, oUnit.UnitId) then
                            if oUnit:GetFractionComplete() == 1 then
                                iTotalDamage = iTotalDamage + 3600 * math.min(iMassFactor, 1)
                                --Also increase if we have a nuke launcher more than 35% complete

                                function HaveSML(oBrain)
                                    local tFriendlyNukes = aiBrain:GetListOfUnits(M27UnitInfo.refCategorySML, false, true)
                                    if M27Utilities.IsTableEmpty(tFriendlyNukes) == false then
                                        for iUnit, oUnit in tFriendlyNukes do
                                            if oUnit:GetFractionComplete() == 1 then
                                                if oUnit:GetWorkProgress() >= 0.35 then
                                                    return true
                                                elseif oUnit.GetNukeSiloAmmoCount and oUnit:GetNukeSiloAmmoCount() >= 1 then
                                                    return true
                                                end
                                            end
                                        end
                                    end
                                    return false
                                end
                                local bHaveFriendlySMLNearlyLoaded = false
                                if not(bHaveFriendlySMLNearlyLoaded) then
                                    for iBrain, oBrain in aiBrain[M27Overseer.toAllyBrains] do
                                        if not(oBrain == aiBrain) then
                                            if HaveSML(oBrain) then
                                                bHaveFriendlySMLNearlyLoaded = true
                                                break
                                            end
                                        end
                                    end
                                end
                                if bHaveFriendlySMLNearlyLoaded then
                                    iTotalDamage = iTotalDamage + 10000
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Finished considering the unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iTotalDamage='..iTotalDamage..'; oCurBP.Economy.BuildCostMass='..oCurBP.Economy.BuildCostMass..'; oUnit:GetFractionComplete()='..oUnit:GetFractionComplete()..'; iMassFactor after considering if unit is mobile='..iMassFactor..'; distance between unit and target='..M27Utilities.GetDistanceBetweenPositions(tBaseLocation, oUnit:GetPosition())) end
                    end
                end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Finished going through units in the aoe, iTotalDamage in mass='..iTotalDamage..'; tBaseLocation='..repru(tBaseLocation)..'; iAOE='..iAOE..'; iDamage='..iDamage) end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iTotalDamage
end

function GetDamageFromOvercharge(aiBrain, oTargetUnit, iAOE, iDamage, bTargetWalls)
    --Originally copied from the 'getdamagefrombomb' function, but adjusted since OC doesnt deal full damage to ACU or structures
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetDamageFromOvercharge'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    local iTotalDamage = 0

    local tEnemiesInRange
    if bTargetWalls then tEnemiesInRange =  aiBrain:GetUnitsAroundPoint(categories.WALL + M27UnitInfo.refCategoryMobileLand + M27UnitInfo.refCategoryStructure + M27UnitInfo.refCategoryAllNavy, oTargetUnit:GetPosition(), iAOE, 'Enemy')
    else tEnemiesInRange = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand + M27UnitInfo.refCategoryStructure + M27UnitInfo.refCategoryAllNavy, oTargetUnit:GetPosition(), iAOE, 'Enemy')
    end

    local oCurBP
    local iMassFactor
    local iCurHealth, iMaxHealth, iCurShield, iMaxShield
    local iActualDamage
    local iKillsExpected = 0
    local iUnitsHit = 0 --E.g. if targeting walls then this means we target the most walls assuming no nearby other units
    if bDebugMessages == true then LOG(sFunctionRef..': About to loop through all enemies in range; iDamage='..iDamage..'; iAOE='..iAOE..'; Base target unit='..oTargetUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTargetUnit)..'; position='..repru(oTargetUnit:GetPosition())) end

    if M27Utilities.IsTableEmpty(tEnemiesInRange) == false then
        for iUnit, oUnit in tEnemiesInRange do
            if oUnit.GetBlueprint then
                oCurBP = oUnit:GetBlueprint()
                if bDebugMessages == true then LOG(sFunctionRef..': Considering enemy unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; dist to postiion='..M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oTargetUnit:GetPosition())) end
                --Is the unit within range of the aoe?
                if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oTargetUnit:GetPosition()) <= iAOE then
                    --Is the unit shielded by a non-mobile shield (mobile shields should take full damage I think)
                    --IsTargetUnderShield(aiBrain, oTarget, iIgnoreShieldsWithLessThanThisHealth, bReturnShieldHealthInstead, bIgnoreMobileShields, bTreatPartCompleteAsComplete)
                    if not(IsTargetUnderShield(aiBrain, oUnit, 800, false, true, false)) then
                        iActualDamage = iDamage
                        if EntityCategoryContains(categories.STRUCTURE, oUnit.UnitId) then
                            iActualDamage = 800
                        elseif EntityCategoryContains(categories.COMMAND, oUnit.UnitId) then
                            iActualDamage = 400
                        end

                        iCurShield, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oUnit)
                        iCurHealth = iCurShield + oUnit:GetHealth()
                        iMaxHealth = iMaxShield + oUnit:GetMaxHealth()
                        --Set base mass value based on health
                        if iDamage >= iMaxHealth or iDamage >= math.min(iCurHealth * 3, iCurHealth + 1000) then
                            iMassFactor = 1
                            iKillsExpected = iKillsExpected + 1
                            --Was the unit almost dead already?
                            if (iCurShield + iCurHealth) <= iMaxHealth * 0.4 then iMassFactor = math.max(0.25, (iCurShield + iCurHealth) / iMaxHealth) end
                        else
                            --Still some value in damaging a unit (as might get a second strike), but far less than killing it
                            iMassFactor = 0.4
                            if EntityCategoryContains(categories.EXPERIMENTAL, oUnit.UnitId) then iMassFactor = 0.5 end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iMassFactor after considering if will kill it='..iMassFactor..'; Unit max health='..iMaxHealth..'; CurHealth='..iCurHealth) end
                        --Is the target mobile and within 1 of the AOE edge? If so then reduce to 25% as it might move out of the wayif
                        if oUnit:GetFractionComplete() == 1 and EntityCategoryContains(categories.MOBILE, oUnit.UnitId) and iAOE - 0.5 < M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oTargetUnit:GetPosition()) then iMassFactor = iMassFactor * 0.25 end
                        iTotalDamage = iTotalDamage + oCurBP.Economy.BuildCostMass * oUnit:GetFractionComplete() * iMassFactor
                        if bDebugMessages == true then LOG(sFunctionRef..': Finished considering the unit; iTotalDamage='..iTotalDamage..'; oCurBP.Economy.BuildCostMass='..oCurBP.Economy.BuildCostMass..'; oUnit:GetFractionComplete()='..oUnit:GetFractionComplete()..'; iMassFactor after considering if unit is mobile='..iMassFactor) end
                    end
                end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Finished going through units in the aoe, iTotalDamage in mass='..iTotalDamage..'; iAOE='..iAOE..'; iDamage='..iDamage) end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iTotalDamage, iKillsExpected
end

function GetBestAOETarget(aiBrain, tBaseLocation, iAOE, iDamage, bOptionalCheckForSMD, tSMLLocationForSMDCheck, iOptionalTimeSMDNeedsToHaveBeenBuiltFor, iSMDRangeAdjust, iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, iOptionalMaxDistanceCheckOptions, iMobileValueOverrideFactorWithin75Percent, iOptionalShieldReductionFactor)
    --Calcualtes the most damaging location for an aoe target; also returns the damage dealt
    --if bOptionalCheckForSMD is true then will ignore targest that are near an SMD
    --iOptionalMaxDistanceCheckOptions - can use to limit hte nubmer of distance options that will choose
    --iFriendlyUnitAOEFactor - e.g. if 2, then will search for friendly units in 2x the aoe
    --iOptionalShieldReductionFactor - instead of igivng shielded targets 0 value this assigns this % of value
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetBestAOETarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': About to find the best target for bomb, tBaseLocation='..repru(tBaseLocation)..'; iAOE='..(iAOE or 'nil')..'; iDamage='..(iDamage or 'nil')) end

    local tBestTarget = {tBaseLocation[1], tBaseLocation[2], tBaseLocation[3]}
    --GetDamageFromBomb(aiBrain, tBaseLocation, iAOE, iDamage)
                            --GetDamageFromBomb(aiBrain, tBaseLocation, iAOE, iDamage, iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, bCumulativeShieldHealthCheck, iOptionalSizeAdjust, iOptionalModIfNeedMultipleShots, iMobileValueOverrideFactorWithin75Percent, bT3ArtiShotReduction, iOptionalShieldReductionFactor)
    local iCurTargetDamage = GetDamageFromBomb(aiBrain, tBaseLocation, iAOE, iDamage, iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, nil, nil, nil, iMobileValueOverrideFactorWithin75Percent, nil, iOptionalShieldReductionFactor)
    local iMaxTargetDamage = iCurTargetDamage
    local iMaxDistanceChecks = math.min(4, math.ceil(iAOE / 2))
    if iOptionalMaxDistanceCheckOptions then iMaxDistanceChecks = math.min(iOptionalMaxDistanceCheckOptions, iMaxDistanceChecks) end
    local iDistanceFromBase = 0
    local tPossibleTarget
    if bOptionalCheckForSMD and IsSMDBlockingTarget(aiBrain, tBaseLocation, tSMLLocationForSMDCheck, (iOptionalTimeSMDNeedsToHaveBeenBuiltFor or 200), iSMDRangeAdjust) then iMaxTargetDamage = math.min(4000, iMaxTargetDamage) end

    for iCurDistanceCheck = iMaxDistanceChecks, 1, -1 do
        iDistanceFromBase = iAOE / iCurDistanceCheck
        for iAngle = 0, 360, 45 do
            tPossibleTarget = M27Utilities.MoveInDirection(tBaseLocation, iAngle, iDistanceFromBase)
                            --GetDamageFromBomb(aiBrain, tBaseLocation, iAOE, iDamage, iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, bCumulativeShieldHealthCheck, iOptionalSizeAdjust, iOptionalModIfNeedMultipleShots, iMobileValueOverrideFactorWithin75Percent, bT3ArtiShotReduction, iOptionalShieldReductionFactor)
            iCurTargetDamage = GetDamageFromBomb(aiBrain, tPossibleTarget, iAOE, iDamage, iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, nil, nil, nil, iMobileValueOverrideFactorWithin75Percent, nil, iOptionalShieldReductionFactor)
            if iCurTargetDamage > iMaxTargetDamage then
                if bOptionalCheckForSMD and IsSMDBlockingTarget(aiBrain, tPossibleTarget, tSMLLocationForSMDCheck, (iOptionalTimeSMDNeedsToHaveBeenBuiltFor or 200), iSMDRangeAdjust) then iCurTargetDamage = math.min(4000, iCurTargetDamage) end
                if iCurTargetDamage > iMaxTargetDamage then
                    tBestTarget = tPossibleTarget
                    iMaxTargetDamage = iCurTargetDamage
                end
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Finished checking every angle for iDistanceFromBase='..iDistanceFromBase..'; iMaxTargetDamage='..iMaxTargetDamage..'; tBestTarget='..repru(tBestTarget)) end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef..': Best target for bomb='..repru(tBestTarget)..'; iMaxTargetDamage='..iMaxTargetDamage)
        M27Utilities.DrawLocation(tBestTarget, nil, 5, 30)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tBestTarget, iMaxTargetDamage
end

function IsSMDBlockingTarget(aiBrain, tTarget, tSMLPosition, iIgnoreSMDCreatedThisManySecondsAgo, iSMDRangeAdjust)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsSMDBlockingTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local bEnemySMDInRange = false
    local iSMLToTarget = M27Utilities.GetDistanceBetweenPositions(tTarget, tSMLPosition)
    local iAngleSMLToTarget = M27Utilities.GetAngleFromAToB(tSMLPosition, tTarget)
    local iTargetToSMD

    local iSMLToSMD
    local iSMDRange
    local iAngleToSMD
    local bSMDInRangeOfMissile

    if bDebugMessages == true then LOG(sFunctionRef..': Considering tTarget='..repru(tTarget)..'; iIgnoreSMDCreatedThisManySecondsAgo='..(iIgnoreSMDCreatedThisManySecondsAgo or 1)..'; Current game time='..GetGameTimeSeconds()) end

    if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemySMD]) == false then
        for iSMD, oSMD in aiBrain[M27Overseer.reftEnemySMD] do
            if M27UnitInfo.IsUnitValid(oSMD) then
                if GetGameTimeSeconds() - (oSMD[M27UnitInfo.refiTimeOfLastCheck] or (GetGameTimeSeconds() - 10)) > (iIgnoreSMDCreatedThisManySecondsAgo or 0) then
                    bSMDInRangeOfMissile = false
                    iSMDRange = (oSMD:GetBlueprint().Weapon[1].MaxRadius or 90) + 1 + (iSMDRangeAdjust or 0)
                    iTargetToSMD = M27Utilities.GetDistanceBetweenPositions(tTarget, oSMD:GetPosition())

                    iSMLToSMD = M27Utilities.GetDistanceBetweenPositions(oSMD:GetPosition(), tSMLPosition)
                    iAngleToSMD = M27Utilities.GetAngleFromAToB(tSMLPosition, oSMD:GetPosition())
                    if bDebugMessages == true then LOG(sFunctionRef..': oSMD='..oSMD.UnitId..M27UnitInfo.GetUnitLifetimeCount(oSMD)..'; iTargetToSMD='..iTargetToSMD..'; iSMLToSMD='..iSMLToSMD..'; iSMLToTarget='..iSMLToTarget..'; iSMDRange='..iSMDRange..'; oSMD[M27UnitInfo.refiTimeOfLastCheck]='..(oSMD[M27UnitInfo.refiTimeOfLastCheck] or 'nil')..'; Distance from target to oSMD='..M27Utilities.GetDistanceBetweenPositions(tTarget, oSMD:GetPosition())..'; iSMDRange='..iSMDRange..'; iAngleToSMD='..iAngleToSMD..'; iAngleSMLToTarget='..iAngleSMLToTarget..'; SMD position='..repru(oSMD:GetPosition())..'; tSMLPosition='..repru(tSMLPosition)..'; TargetPos='..repru(tTarget)..'; iAngleFromAToB - iAngleFromAToC='..(iAngleSMLToTarget - iAngleToSMD)..'; ConvertAngleToRadians(iAngleFromAToB - iAngleFromAToC)='..M27Utilities.ConvertAngleToRadians(iAngleSMLToTarget - iAngleToSMD)..'; math.tan(math.abs(ConvertAngleToRadians(iAngleFromAToB - iAngleFromAToC)))='..math.tan(math.abs(M27Utilities.ConvertAngleToRadians(iAngleSMLToTarget - iAngleToSMD)))..'; iDistFromAToC='..iSMLToSMD..'; Tan result times this distance='..iSMLToSMD*math.tan(math.abs(M27Utilities.ConvertAngleToRadians(iAngleSMLToTarget - iAngleToSMD)))) end

                    bSMDInRangeOfMissile = M27Utilities.IsLineFromAToBInRangeOfCircleAtC(iSMLToTarget, iSMLToSMD, iTargetToSMD, iAngleSMLToTarget, iAngleToSMD, iSMDRange)

                    if bSMDInRangeOfMissile then
                        if bDebugMessages == true then LOG(sFunctionRef..': SMD is in range and was built a while ago') end
                        bEnemySMDInRange = true
                        break
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': SMD is not blocking the target') end
                elseif bDebugMessages == true then LOG(sFunctionRef..': SMD was only recently built, time we think the SMD was active='..GetGameTimeSeconds() - (oSMD[M27UnitInfo.refiTimeOfLastCheck] or (GetGameTimeSeconds() - 10)))
                end
            end
        end
    elseif bDebugMessages == true then LOG(sFunctionRef..': No enemy SMD detected')
    end
    if bDebugMessages == true then LOG(sFunctionRef..': bEnemySMDInRange='..tostring(bEnemySMDInRange)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bEnemySMDInRange
end

function RecheckForTMLMissileTarget(aiBrain, oLauncher)
    --Call via fork thread - called if couldnt find any targets for TML
    local sFunctionRef = 'RecheckForTMLMissileTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if not(oLauncher[M27UnitInfo.refbActiveMissileChecker]) then
        oLauncher[M27UnitInfo.refbActiveMissileChecker] = true
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitSeconds(30)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        if M27UnitInfo.IsUnitValid(oLauncher) then
            ConsiderLaunchingMissile(oLauncher)
            oLauncher[M27UnitInfo.refbActiveMissileChecker] = false
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DecideToLaunchNukeSMLOrTMLMissile()  end --Done only to make it easier to find considerlaunchingmissile
function ConsiderLaunchingMissile(oLauncher, oWeapon)
    --Should be called via forkthread when missile created due to creating a loop
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ConsiderLaunchingMissile'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    if M27UnitInfo.IsUnitValid(oLauncher) then
        oLauncher[M27UnitInfo.refbActiveMissileChecker] = true


        local tTarget
        local tEnemyUnitsOfInterest
        local iBestTargetValue
        local iCurTargetValue
        local tEnemyCategoriesOfInterest
        local aiBrain = oLauncher:GetAIBrain()
        local iMaxRange = 250 --basic default, should get overwritten
        local iMinRange = 0
        local iAOE, iDamage

        local bTML = false
        local bSML = false
        local bCheckForSMD = false
        if EntityCategoryContains(M27UnitInfo.refCategoryTML, oLauncher.UnitId) then bTML = true
        elseif EntityCategoryContains(M27UnitInfo.refCategorySML, oLauncher.UnitId) then
            bSML = true
            if not(EntityCategoryContains(categories.EXPERIMENTAL, oLauncher.UnitId)) then bCheckForSMD = true end
        else M27Utilities.ErrorHandler('Unknown type of launcher, code to fire a missile wont work; oLauncher='..oLauncher.UnitId..M27UnitInfo.GetUnitLifetimeCount(oLauncher)) end

        if bTML or bSML then
            iAOE, iDamage, iMinRange, iMaxRange = M27UnitInfo.GetLauncherAOEStrikeDamageMinAndMaxRange(oLauncher)

            if bTML then
                --tEnemyCategoriesOfInterest = M27EngineerOverseer.iTMLHighPriorityCategories
            else --SML
                tEnemyCategoriesOfInterest = {M27UnitInfo.refCategoryExperimentalStructure, M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategorySML, M27UnitInfo.refCategoryT3Mex + M27UnitInfo.refCategoryT3Power, M27UnitInfo.refCategoryLandExperimental + M27UnitInfo.refCategoryStructure * categories.TECH3 + M27UnitInfo.refCategoryFixedT2Arti - M27UnitInfo.refCategoryExperimentalStructure - M27UnitInfo.refCategoryFixedT3Arti - M27UnitInfo.refCategorySML - M27UnitInfo.refCategoryT3Mex - M27UnitInfo.refCategorySMD - M27UnitInfo.refCategoryT3Power, M27UnitInfo.refCategoryNavalSurface * categories.TECH3 + M27UnitInfo.refCategoryNavalSurface * categories.EXPERIMENTAL}
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Will consider missile target. iMinRange='..(iMinRange or 'nil')..'; iAOE='..(iAOE or 'nil')..'; iDamage='..(iDamage or 'nil')..'; bSML='..tostring((bSML or false))) end

            while M27UnitInfo.IsUnitValid(oLauncher) do
                if bTML then
                    local tHighHealthTargets = {}
                    local tStartPos = oLauncher:GetPosition()
                    local tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27EngineerOverseer.iTMLHighPriorityCategories, tStartPos, iMaxRange, 'Enemy')
                    local tEnemyTMD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryTMD, tStartPos, iMaxRange + 30, 'Enemy')
                    local iValidTargets = 0
                    local tValidTargets = {}
                    local oBestTarget
                    if M27Utilities.IsTableEmpty(tPotentialTargets) == false then
                        for iUnit, oUnit in tPotentialTargets do
                            if M27EngineerOverseer.IsValidTMLTarget(aiBrain, tStartPos, oUnit, tEnemyTMD) then
                                iValidTargets = iValidTargets + 1
                                tValidTargets[iValidTargets] = oUnit
                            end
                        end
                    end
                    if iValidTargets == 0 then
                        tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure * categories.TECH2 + M27UnitInfo.refCategoryStructure * categories.TECH3 + M27UnitInfo.refCategoryFatboy - M27EngineerOverseer.iTMLHighPriorityCategories -M27UnitInfo.refCategoryTMD, tStartPos, iMaxRange, 'Enemy')
                        if M27Utilities.IsTableEmpty(tPotentialTargets) == false then
                            for iUnit, oUnit in tPotentialTargets do
                                if not(EntityCategoryContains(categories.MOBILE, oUnit.UnitId)) or not(oUnit:IsUnitState('Moving')) then
                                    if oUnit:GetHealth() <= 6000 then
                                        if M27EngineerOverseer.IsValidTMLTarget(aiBrain, tStartPos, oUnit, tEnemyTMD) then
                                            iValidTargets = iValidTargets + 1
                                            tValidTargets[iValidTargets] = oUnit
                                        end
                                    else
                                        table.insert(tHighHealthTargets, oUnit)
                                    end
                                end
                            end
                        end
                        if iValidTargets == 0 then
                            --Target valid high health targets
                            if M27Utilities.IsTableEmpty(tHighHealthTargets) == false then
                                for iUnit, oUnit in tHighHealthTargets do
                                    if M27EngineerOverseer.IsValidTMLTarget(aiBrain, tStartPos, oUnit, tEnemyTMD) then
                                        iValidTargets = iValidTargets + 1
                                        tValidTargets[iValidTargets] = oUnit
                                    end
                                end
                            end
                        end
                    end

                    if iValidTargets == 0 then
                        if not(oLauncher[M27EconomyOverseer.refbWillReclaimUnit]) and not(EntityCategoryContains(categories.EXPERIMENTAL, oLauncher.UnitId)) then
                            --Disable autobuild and pause the TML since we have no targets, so this missile will be our last
                            oLauncher:SetAutoMode(false)
                            oLauncher:SetPaused(true)
                            if oLauncher.UnitId == 'xsb2401' then M27Utilities.ErrorHandler('Pausing Yolona') end
                            if not(oLauncher[M27EngineerOverseer.refiFirstTimeNoTargetsAvailable]) then
                                --First time we have no target
                                oLauncher[M27EngineerOverseer.refiFirstTimeNoTargetsAvailable] = GetGameTimeSeconds()
                            end
                            --[[if GetGameTimeSeconds() - oLauncher[M27EngineerOverseer.refiFirstTimeNoTargetsAvailable] >= 150 and not(M27Utilities.IsTableEmpty(tEnemyTMD)) then
                                --Reclaim the unit
                                oLauncher[M27EconomyOverseer.refbWillReclaimUnit] = true
                                table.insert(aiBrain[M27EconomyOverseer.reftoTMLToReclaim], oLauncher)
                            end--]]
                        else
                            --Already set to be reclaimed, or dealing with a yolona oss so just need to check for targets
                        end
                        --Wait a while then call this function again:
                        ForkThread(RecheckForTMLMissileTarget, aiBrain, oLauncher)
                    else
                        --Have at least 1 valid target, so want to pick the best one

                        iBestTargetValue = 0
                        local sLauncherLocationRef = M27Utilities.ConvertLocationToReference(oLauncher:GetPosition())
                        for iUnit, oUnit in tValidTargets do
                            iCurTargetValue = GetDamageFromBomb(aiBrain, oUnit:GetPosition(), iAOE, iDamage)
                            if EntityCategoryContains(M27UnitInfo.refCategoryMex, oUnit.UnitId) then iCurTargetValue = iCurTargetValue * 1.5 end
                            --Adjust value if we think the missile will hit a cliff
                            if oUnit[tbExpectMissileBlockedByCliff][sLauncherLocationRef] == nil then
                                if not(oUnit[tbExpectMissileBlockedByCliff]) then oUnit[tbExpectMissileBlockedByCliff] = {} end
                                local tExpectedMissileVertical = M27Utilities.MoveInDirection(oLauncher:GetPosition(), M27Utilities.GetAngleFromAToB(oLauncher:GetPosition(), oUnit:GetPosition()), 31, true)
                                tExpectedMissileVertical[2] = tExpectedMissileVertical[2] + 60 --Doing testing, it actually only goes up by 50, but I think it travels in an arc from here to the target, as in a test scenario doing at less than +60 meant it thought it would hit a cliff when it didnt
                                -- {oLauncher:GetPosition()[1], oLauncher:GetPosition()[2] + 65, oLauncher:GetPosition()[3]}
                                oUnit[tbExpectMissileBlockedByCliff][sLauncherLocationRef] = IsLineBlocked(aiBrain, tExpectedMissileVertical, oUnit:GetPosition(), iAOE, false)
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': Potential TML target '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iCurTargetValue before adj for blocked='..iCurTargetValue..'; oUnit[tbExpectMissileBlockedByCliff][sLauncherLocationRef]='..tostring(oUnit[tbExpectMissileBlockedByCliff][sLauncherLocationRef])) end
                            if oUnit[tbExpectMissileBlockedByCliff][sLauncherLocationRef] then iCurTargetValue = iCurTargetValue * 0.2 end
                            if iBestTargetValue < iCurTargetValue then
                                iBestTargetValue = iCurTargetValue
                                oBestTarget = oUnit
                            end
                        end
                        if oBestTarget then
                            if bDebugMessages == true then LOG(sFunctionRef..': oBestTarget='..oBestTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBestTarget)) end
                            tTarget = oBestTarget:GetPosition()
                            oBestTarget[M27EngineerOverseer.refiTMLShotsFired] = (oBestTarget[M27EngineerOverseer.refiTMLShotsFired] or 0) + 1
                            oLauncher[M27EngineerOverseer.refoLastTMLTarget] = oBestTarget
                            oLauncher[M27EngineerOverseer.refiLastTMLMassKills] = (oLauncher.VetExperience or oLauncher.Sync.totalMassKilled or 0)
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': iValidTargets='..iValidTargets..'; tTarget='..repru((tTarget or {'nil'}))) end





                    --[[ Prev logic for choosing target (never actually tested)
                    iBestTargetValue = 1000
                    for iRef, iCategory in tEnemyCategoriesOfInterest do
                        tEnemyUnitsOfInterest = aiBrain:GetUnitsAroundPoint(iCategory, oLauncher:GetPosition(), iMaxRange, 'Enemy')
                        if M27Utilities.IsTableEmpty(tEnemyUnitsOfInterest) == false then
                            for iUnit, oUnit in tEnemyUnitsOfInterest do
                                iCurTargetValue = M27Utilities.GetDistanceBetweenPositions(oLauncher:GetPosition(), oUnit:GetPosition())
                                if iCurTargetValue > iBestTargetValue and iCurTargetValue > iMinRange then
                                    iBestTargetValue = iCurTargetValue
                                    tTarget = oUnit:GetPosition()
                                end
                            end
                            break
                        end
                    end--]]
                else --SML - work out which location would deal the most damage - consider all high value structures and the enemy start position
                    iBestTargetValue = 0
                    --Shortlist of locations we have recently nuked
                    local tRecentlyNuked = {}
                    local iTimeSMDNeedsToHaveBeenBuiltFor = 240 --default, will adjust
                    local iMissileSpeed = (__blueprints[oWeapon.Blueprint.ProjectileId].Physics.MaxSpeed or 40)
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': oLauncher='..oLauncher.UnitId..M27UnitInfo.GetUnitLifetimeCount(oLauncher)..'; Breakdown of the weapon table='..reprs(oWeapon)..'; iMissileSpeed='..iMissileSpeed..'; missile speed per BP='..__blueprints[oWeapon.Blueprint.ProjectileId].Physics.MaxSpeed)
                    end
                    --local oMissileBP = __blueprints[oWeapon.ProjectileId]
                    --[[local sMissile = oMissileBP.Label
                    local oSMLBP = oLauncher:GetBlueprint()
                    for iWeapon, tWeapon in oSMLBP do
                        if tWeapon.label == sMissile then
                            iMissileSpeed = tWeapon.Physics.MaxSpeed
                            if bDebugMessages == true then LOG(sFunctionRef..': Have an actual speed value for the SML of '..iMissileSpeed) end
                            break
                        end
                    end--]]


                    --[[if bDebugMessages == true then
                        LOG(sFunctionRef..': oLauncher='..oLauncher.UnitId..M27UnitInfo.GetUnitLifetimeCount(oLauncher)..'; Breakdown of the weapon table='..reprs(oWeapon))
                        LOG(sFunctionRef..': Breakdown of oMissileBP='..reprs(oMissileBP))
                        LOG(sFunctionRef..': Breakdown of .Blueprint='..reprs(oWeapon.Blueprint)..'; projectile Id='..oWeapon.Blueprint.ProjectileId)
                        local sMissile = oMissileBP.Label
                        local oSMLBP = oLauncher:GetBlueprint()
                        for iWeapon, tWeapon in oSMLBP do
                            if tWeapon.label == sMissile then
                                LOG(sFunctionRef..': Breakdown of reprs for blueprint[projectileid]='..reprs(__blueprints[tWeapon.ProjectileId]))
                                break
                            end
                        end
                        LOG(sFunctionRef..': Breakdown of Weapon blueprint proj ID='..reprs(__blueprints[oWeapon.Blueprint.ProjectileId]))
                    end--]]

                    if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.subrefNukeLaunchLocations]) == false then
                        for iTime, tLocation in M27Team.tTeamData[aiBrain.M27Team][M27Team.subrefNukeLaunchLocations] do
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering iTime='..iTime..'; tLocation='..repru(tLocation)..'; GameTime='..GetGameTimeSeconds()) end
                            if GetGameTimeSeconds() - iTime < 60 then --Testing with Aeon SML on setons it takes 60s to go from one corner to another roughly
                                table.insert(tRecentlyNuked, tLocation)
                            end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': tRecentlyNuked='..repru((tRecentlyNuked or {'nil'}))) end

                    function HaventRecentlyNukedLocation(tLocation)
                        if M27Utilities.IsTableEmpty(tRecentlyNuked) then return true
                        else
                            for iRecentLocation, tRecentLocation in tRecentlyNuked do
                                if bDebugMessages == true then LOG(sFunctionRef..': Considering tLocation='..repru(tLocation)..'; Distance to tRecentLocation='..M27Utilities.GetDistanceBetweenPositions(tLocation, tRecentLocation)) end
                                if M27Utilities.GetDistanceBetweenPositions(tLocation, tRecentLocation) <= 50 then
                                    return false
                                end
                            end
                        end
                        return true
                    end

                    --First get the best location if just target the start position or locations near here
                    if HaventRecentlyNukedLocation(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) then
                        --GetBestAOETarget(aiBrain, tBaseLocation, iAOE, iDamage, bOptionalCheckForSMD, tSMLLocationForSMDCheck, iOptionalTimeSMDNeedsToHaveBeenBuiltFor, iSMDRangeAdjust, iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, iOptionalMaxDistanceCheckOptions, iMobileValueOverrideFactorWithin75Percent, iOptionalShieldReductionFactor)
                        iTimeSMDNeedsToHaveBeenBuiltFor = 200 --3m20
                        tTarget, iBestTargetValue = GetBestAOETarget(aiBrain, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), iAOE, iDamage, bCheckForSMD, oLauncher:GetPosition(), nil, nil, 2, 2.5)
                    end
                    --local iAirSegmentX, iAirSegmentZ

                    --Cycle through other start positions to see if can get a better target, but reduce value of target if we havent scouted it in the last 5 minutes
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering best target for nuke.  If target enemy base then iBestTargetValue='..iBestTargetValue) end
                    for iStartPoint = 1, table.getn(M27MapInfo.PlayerStartPoints) do
                        if not(iStartPoint == aiBrain.M27StartPositionNumber) and M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[iStartPoint], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) >= 30 then
                            --Have we scouted this location recently?
                            --iAirSegmentX, iAirSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(M27MapInfo.PlayerStartPoints[iStartPoint])
                            if bDebugMessages == true then LOG(sFunctionRef..': Cycling through start points, iStartPoint='..iStartPoint..'; time last scouted='..M27AirOverseer.GetTimeSinceLastScoutedLocation(aiBrain, M27MapInfo.PlayerStartPoints[iStartPoint])..'; do we have intel coverage='..tostring(GetIntelCoverageOfPosition(aiBrain, M27MapInfo.PlayerStartPoints[iStartPoint], 25, false))) end
                            if M27AirOverseer.GetTimeSinceLastScoutedLocation(aiBrain, M27MapInfo.PlayerStartPoints[iStartPoint]) <= 300 or GetIntelCoverageOfPosition(aiBrain, M27MapInfo.PlayerStartPoints[iStartPoint], 30, false) then
                                if HaventRecentlyNukedLocation(M27MapInfo.PlayerStartPoints[iStartPoint]) then
                                    iCurTargetValue = GetDamageFromBomb(aiBrain, M27MapInfo.PlayerStartPoints[iStartPoint], iAOE, iDamage, 2, 2.5)
                                    if bDebugMessages == true then LOG(sFunctionRef..': Considering the start position '..iStartPoint..'='..repru(M27MapInfo.PlayerStartPoints[iStartPoint])..'; value ignroign SMD='..iCurTargetValue) end
                                    if iCurTargetValue > iBestTargetValue then
                                        iTimeSMDNeedsToHaveBeenBuiltFor = 230 - (M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[iStartPoint], oLauncher:GetPosition()) / iMissileSpeed + 10)
                                        if IsSMDBlockingTarget(aiBrain, M27MapInfo.PlayerStartPoints[iStartPoint], oLauncher:GetPosition(), iTimeSMDNeedsToHaveBeenBuiltFor) then
                                            iCurTargetValue = 4000
                                            if bDebugMessages == true then LOG(sFunctionRef..': SMD is blocking target so reducing value to 4k. iTimeSMDNeedsToHaveBeenBuiltFor='..iTimeSMDNeedsToHaveBeenBuiltFor) end
                                        end
                                        if iCurTargetValue > iBestTargetValue then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Have a better start position target, for the start position='..iStartPoint..' dealing damage of '..iCurTargetValue..' vs prev best value of '..iBestTargetValue..'; iTimeSMDNeedsToHaveBeenBuiltFor='..iTimeSMDNeedsToHaveBeenBuiltFor) end
                                            iBestTargetValue = iCurTargetValue
                                            tTarget = {M27MapInfo.PlayerStartPoints[iStartPoint][1], M27MapInfo.PlayerStartPoints[iStartPoint][2], M27MapInfo.PlayerStartPoints[iStartPoint][3]}
                                        end
                                    end
                                end
                            end
                        end
                    end





                    --Reduce value if enemy has SMD within range of here - already incorporated into getbestaoetarget
                    --[[if IsSMDBlockingTarget(aiBrain, tTarget, oLauncher:GetPosition(), 200) then
                        if bDebugMessages == true then LOG(sFunctionRef..': SMD is blocking the nearest enemy base so will limit damage to 4k') end
                        iBestTargetValue = 4000
                    elseif bDebugMessages == true then LOG(sFunctionRef..': SMD not blockign enemy base, value of that='..iBestTargetValue)
                    end--]]


                    --Will assume that even if are in range of SMD it isnt loaded, as wouldve reclaimed the nuke if they built SMD in time
                    if bDebugMessages == true then LOG(sFunctionRef..': iBestTargetValue for enemy base='..iBestTargetValue..'; if <20k then will consider other targets') end
                    local iEnemyUnitsConsideredThisTick = 0
                    if iBestTargetValue < 80000 then --If have high value location for nearest enemy start then just go with this
                        for iRef, iCategory in tEnemyCategoriesOfInterest do
                            tEnemyUnitsOfInterest = aiBrain:GetUnitsAroundPoint(iCategory, oLauncher:GetPosition(), iMaxRange, 'Enemy')
                            if M27Utilities.IsTableEmpty(tEnemyUnitsOfInterest) == false then
                                for iUnit, oUnit in tEnemyUnitsOfInterest do
                                    if M27UnitInfo.IsUnitValid(oUnit) then
                                        iEnemyUnitsConsideredThisTick = iEnemyUnitsConsideredThisTick + 1
                                        if bDebugMessages == true then LOG(sFunctionRef..': Considering unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iEnemyUnitsConsideredThisTick='..iEnemyUnitsConsideredThisTick..'; Have we recently nuked this location='..tostring((HaventRecentlyNukedLocation(oUnit:GetPosition())) or false)) end
                                        if HaventRecentlyNukedLocation(oUnit:GetPosition()) then
                                            iCurTargetValue = GetDamageFromBomb(aiBrain, oUnit:GetPosition(), iAOE, iDamage, 2, 2.5)
                                            if bDebugMessages == true then LOG(sFunctionRef..': target oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iCurTargetValue='..iCurTargetValue..'; location='..repru(oUnit:GetPosition())..'; iEnemyUnitsConsideredThisTick='..iEnemyUnitsConsideredThisTick) end
                                            --Stop looking if tried >=10 targets and have one that is at least 20k of value
                                            if iCurTargetValue > iBestTargetValue then
                                                iTimeSMDNeedsToHaveBeenBuiltFor = 230 - (M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oLauncher:GetPosition()) / iMissileSpeed + 10)
                                                if bCheckForSMD and IsSMDBlockingTarget(aiBrain, oUnit:GetPosition(), oLauncher:GetPosition(), iTimeSMDNeedsToHaveBeenBuiltFor) then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': SMD is blocking the unit target '..repru(oUnit:GetPosition())..'; will limit damage to 4k; iTimeSMDNeedsToHaveBeenBuiltFor='..iTimeSMDNeedsToHaveBeenBuiltFor) end
                                                    iCurTargetValue = 4000 end
                                                if iCurTargetValue > iBestTargetValue then
                                                    iBestTargetValue = iCurTargetValue
                                                    tTarget = oUnit:GetPosition()
                                                    if bDebugMessages == true then LOG(sFunctionRef..': New best target with value='..iBestTargetValue..'; iTimeSMDNeedsToHaveBeenBuiltFor='..iTimeSMDNeedsToHaveBeenBuiltFor) end
                                                end
                                            end
                                            --Note: Mass value of mexes is doubled, so 3 T3 mexes would give a value of 27600
                                            if iEnemyUnitsConsideredThisTick >= 15 and iBestTargetValue >= 70000 then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Have a target with a decent amount of value and have already tried quite a few units.  iBestTargetValue='..iBestTargetValue..'; iEnemyUnitsConsideredThisTick='..iEnemyUnitsConsideredThisTick) end
                                                break
                                            end
                                        end
                                        if iEnemyUnitsConsideredThisTick >= 25 then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Considered 25 targets, will wait 1 tick before considering more for performance reasons. iBestTargetValue='..iBestTargetValue) end
                                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                                            WaitTicks(1)
                                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                                            iEnemyUnitsConsideredThisTick = 0
                                            if not(M27UnitInfo.IsUnitValid(oLauncher)) then
                                                tTarget = nil
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if tTarget then tTarget, iBestTargetValue = GetBestAOETarget(aiBrain, tTarget, iAOE, iDamage, bCheckForSMD, oLauncher:GetPosition(), nil, nil, 2, 2.5) end
                        if bDebugMessages == true then LOG(sFunctionRef..': iBestTargetValue after getting best location='..iBestTargetValue..'; Best location for this target='..repru(tTarget)) end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': If value is <12k then will clear target; iBestTargetValue='..iBestTargetValue..'; tTarget='..repru(tTarget or {'nil'})) end
                    if iBestTargetValue < 12000 then tTarget = nil end
                end

                if tTarget then
                    --Launch missile
                    if bDebugMessages == true then LOG(sFunctionRef..': Will launch missile at tTarget='..repru(tTarget)) end
                    if bTML then
                        IssueTactical({oLauncher}, tTarget)
                        oLauncher:SetAutoMode(true)
                        oLauncher:SetPaused(false)
                        if bDebugMessages == true then
                            local tExpectedMissileVertical = M27Utilities.MoveInDirection(oLauncher:GetPosition(), M27Utilities.GetAngleFromAToB(oLauncher:GetPosition(), tTarget), 31, true)
                            tExpectedMissileVertical[2] = tExpectedMissileVertical[2] + 60 --Doing testing, it actually only goes up by 50, but I think it travels in an arc from here to the target, as in a test scenario doing at less than +60 meant it thought it would hit a cliff when it didnt
                            -- {oLauncher:GetPosition()[1], oLauncher:GetPosition()[2] + 65, oLauncher:GetPosition()[3]}
                            local bShotBlocked = IsLineBlocked(aiBrain, tExpectedMissileVertical, tTarget, iAOE, false)
                            LOG(sFunctionRef..': Just launched tactical missile at tTarget='..repru(tTarget)..'; oLauncher position='..repru(oLauncher:GetPosition())..'; will draw in blue if think shot will hit, red if think shot blocked')
                            local iColour = 1
                            if bShotBlocked then iColour = 2 end
                            M27Utilities.DrawLocation(tTarget, nil, iColour)
                        end
                    else
                        IssueNuke({oLauncher}, tTarget)
                        M27Team.tTeamData[aiBrain.M27Team][M27Team.subrefNukeLaunchLocations][GetGameTimeSeconds()] = tTarget
                        if bDebugMessages == true then LOG(sFunctionRef..': Launching nuke at tTarget='..repru(tTarget)..'; M27Team.tTeamData[aiBrain.M27Team][M27Team.subrefNukeLaunchLocations]='..repru(M27Team.tTeamData[aiBrain.M27Team][M27Team.subrefNukeLaunchLocations])) end
                        --Restart SMD monitor after giving time for missile to fire
                        if oLauncher then oLauncher[M27UnitInfo.refbActiveSMDChecker] = false end
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                        WaitSeconds(10)
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                        if not(oLauncher[M27UnitInfo.refbActiveSMDChecker]) and not(EntityCategoryContains(categories.EXPERIMENTAL, oLauncher.UnitId)) then ForkThread(M27EngineerOverseer.CheckForEnemySMD, aiBrain, oLauncher) end
                        --Send a voice taunt if havent in last 10m
                        ForkThread(M27Chat.SendGloatingMessage, aiBrain, 10, 600)
                    end
                    break
                end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitSeconds(10)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            end
        end
        oLauncher[M27UnitInfo.refbActiveMissileChecker] = false
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

--[[function TempT3ArtiTest(oT3Arti)
    if not(oT3Arti['TempTest']) then
        oT3Arti['TempTest'] = true
        while M27UnitInfo.IsUnitValid(oT3Arti) do
            LOG('GameTime='..GetGameTimeSeconds()..'; T3 arti weapon1='..reprs(oT3Arti:GetWeapon(1)))
            LOG('Weapon rackbones='..reprs(oT3Arti:GetWeapon(1).RackBones))
            LOG('Blueprint rackbones='..reprs(oT3Arti:GetWeapon(1):GetBlueprint().RackBones))
            local tRackBones = oT3Arti:GetWeapon(1):GetBlueprint().RackBones[1]
            LOG('Muzzle bones='..reprs(tRackBones.MuzzleBones))
            local sBone = tRackBones.MuzzleBones[1]
            LOG('sBone direction converted for muzzlebone1='..(180 - oT3Arti:GetBoneDirection(sBone) / math.pi * 180)..'; raw bone direction='..reprs(oT3Arti:GetBoneDirection(sBone)))
            sBone = tRackBones.RackBone
            LOG('sBone direction for RackBone1='..(180 - oT3Arti:GetBoneDirection(sBone) / math.pi * 180))
            LOG('sBoneDirection for Turret='..(180 - oT3Arti:GetBoneDirection('Turret') / math.pi * 180))
            LOG('sBoneDirection for Barrel='..(180 - oT3Arti:GetBoneDirection('Barrel') / math.pi * 180))
            LOG('sBoneDirection for Turret_Muzzle='..(180 - oT3Arti:GetBoneDirection('Turret_Muzzle') / math.pi * 180))
            LOG('GetUnitFacingAngle='..M27UnitInfo.GetUnitFacingAngle(oT3Arti))
            if oT3Arti[M27UnitInfo.refoLastTargetUnit] then
                LOG('Direction to the last target '..oT3Arti[M27UnitInfo.refoLastTargetUnit].UnitId..M27UnitInfo.GetUnitLifetimeCount(oT3Arti[M27UnitInfo.refoLastTargetUnit])..' is equal to '..M27Utilities.GetAngleFromAToB(oT3Arti:GetPosition(), oT3Arti[M27UnitInfo.refoLastTargetUnit]:GetPosition()))
            end
            WaitTicks(5)
        end
    end
end--]]

function GetT3ArtiTarget(oT3Arti, bDontDelayShot)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetT3ArtiTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then
        LOG(sFunctionRef..': Start of code, time='..GetGameTimeSeconds()..', oT3Arti='..oT3Arti.UnitId..M27UnitInfo.GetUnitLifetimeCount(oT3Arti)..'; Fraction complete='..oT3Arti:GetFractionComplete()..'; Is table of adjacent units empty='..tostring(M27Utilities.IsTableEmpty(oT3Arti.AdjacentUnits)))
        if M27Utilities.IsTableEmpty(oT3Arti.AdjacentUnits) == false then
            for iUnit, oUnit in oT3Arti.AdjacentUnits do
                LOG(sFunctionRef..': Adjacent unit: '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit))
            end
        end
    end

    --ForkThread(TempT3ArtiTest, oT3Arti)



    --Redundancy incase we've been gifted a scathis that we havent started construction on:
    if EntityCategoryContains(categories.MOBILE, oT3Arti) then
        oT3Arti:GetAIBrain()[M27EngineerOverseer.reftFriendlyScathis][oT3Arti.UnitId..M27UnitInfo.GetUnitLifetimeCount(oT3Arti)] = oT3Arti
    end

    local iTicksWaited = 0 --Will spread calculations over a number of ticks to ease the load
    local iMinRange = 0
    local iMaxRange = 0
    local iAOE = 1
    local iDamage = 2500
    local iRandomness = 0
    local iMaxTimeToWait = 0
    local iRateOfFire
    for iWeapon, tWeapon in oT3Arti:GetBlueprint().Weapon do
        iMinRange = math.max(tWeapon.MinRadius, iMinRange)
        iMaxRange = math.max(tWeapon.MaxRadius, iMaxRange)
        iAOE = math.max(iAOE, tWeapon.DamageRadius)
        iDamage = math.max(iDamage, tWeapon.Damage)
        iRandomness = math.max(iRandomness, (tWeapon.FiringRandomness or 0))
        iRateOfFire = math.max(tWeapon.RateOfFire or 0.01, 0.01)
        iMaxTimeToWait = math.floor(10 * math.max(iMaxTimeToWait, 1 / iRateOfFire) * (oT3Arti:GetWeapon(iWeapon).AdjRoFMod or 1))/10
        if bDebugMessages == true then LOG(sFunctionRef..': Estimated time between shots in seconds (rounded)='..iMaxTimeToWait) end
    end
    local iArtiFacingAngle = M27UnitInfo.GetUnitFacingAngle(oT3Arti)
    local iCurAngleDif
    --Assume that 5 shots will land on this target for deciding aoe targets (i.e. unit would need to have massive health to not die)
    iDamage = math.min(23500, iDamage * 5) --Want to ignore shields with combined health less than this
    if EntityCategoryContains(categories.EXPERIMENTAL * categories.AEON, oT3Arti.UnitId) then iDamage = math.max(iDamage, 47000) end --rapid fire arti will deal quite a lot of damage to shields since it is very accurate

    --Adjust aoe for firing randomness
    iAOE = iAOE * (1 + iRandomness * 2.5)
    local iEffectiveMaxRange = iMaxRange + iAOE * 0.5

    local aiBrain = oT3Arti:GetAIBrain()
    local tTarget
    local tEnemyUnitsOfInterest
    local iBestTargetValue
    local iCurTargetValue
    local oTarget

    --T3 arti priority target variables:
    local tTargetShortlist = {} --High priority targets like t3 arti
    local iTargetShortlist = 0
    local iFriendlyT3ArtiInRange = 0
    local iCompleteOrNearCompleteEnemyArti = 0
    local iNearCompletePercent = 0.65
    local iCurDistance
    local bRecheckWhenReadyToFire = false --If true then after picking the target and sending the order to attack, we will get a new target when we are ready to fire

    local bDontConsiderShotCount = false
    if oT3Arti.UnitId == 'ueb2401' then bDontConsiderShotCount = true end

    --First prioritise enemy T3 arti regardless of how well shielded, as if we dont kill them quickly we will die
    if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyArtiAndExpStructure]) == false then
        --Pick the one in range of the most t3 arti including this one; if there are multiple, then pick the one closest to this (since its accuracy will be best)
        local iMostT3ArtiInRange = 0
        local tT3ArtiInRange = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategoryExperimentalArti, oT3Arti:GetPosition(), math.max(825, iEffectiveMaxRange * 2), 'Ally')



        if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through every enemy artillery and experimental structure, size of table='..table.getsize(aiBrain[M27Overseer.reftEnemyArtiAndExpStructure])) end
        --[[local tExperimentalArti = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryExperimentalArti, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 3000)
        local iExperimentalArti = 0
        if M27Utilities.IsTableEmpty(tExperimentalArti) == false then
            for iUnit, oUnit in tExperimentalArti do
                if oUnit:GetFractionComplete() == 1 then
                    iExperimentalArti = iExperimentalArti + 1
                end
            end
        end--]]
        for iUnit, oUnit in aiBrain[M27Overseer.reftEnemyArtiAndExpStructure] do
            if M27UnitInfo.IsUnitValid(oUnit) and oUnit:GetFractionComplete() >= 0.25 and (bDontConsiderShotCount or ((oUnit[refiT3ArtiShotCount] or 0) <= iT3ArtiShotThreshold) and (oUnit[refiT3ArtiLifetimeShotCount] or 0) <= iT3ArtiShotLifetimeThreshold) then
                iCurDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oT3Arti:GetPosition())
                --Use 15 above normal range due to inaccuracy of shots
                if bDebugMessages == true then LOG(sFunctionRef..': Considering enemy unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iCurDistance='..iCurDistance) end
                if iCurDistance <= iEffectiveMaxRange and iCurDistance >= iMinRange then

                    --tT3ArtiInRange = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT3Arti, oUnit:GetPosition(), 840, 'Ally')

                    if M27Utilities.IsTableEmpty(tT3ArtiInRange) == false then

                        iFriendlyT3ArtiInRange = 0
                        --iFriendlyT3ArtiInRange = iExperimentalArti
                        for iFriendlyArti, oFriendlyArti in tT3ArtiInRange do
                            if oUnit:GetFractionComplete() == 1 and (oFriendlyArti == oT3Arti or oUnit == oFriendlyArti[M27UnitInfo.refoLastTargetUnit] or not(oFriendlyArti[M27UnitInfo.refoLastTargetUnit])) then
                                iFriendlyT3ArtiInRange = iFriendlyT3ArtiInRange + 1
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': iFriendlyT3ArtiInRange='..iFriendlyT3ArtiInRange..'; iMostT3ArtiInRange='..iMostT3ArtiInRange) end

                        if iFriendlyT3ArtiInRange >= iMostT3ArtiInRange then
                            if iFriendlyT3ArtiInRange > iMostT3ArtiInRange then
                                tTargetShortlist = {}
                                iTargetShortlist = 0
                            end
                            iTargetShortlist = iTargetShortlist + 1
                            tTargetShortlist[iTargetShortlist] = oUnit
                            iMostT3ArtiInRange = iFriendlyT3ArtiInRange
                            if oUnit:GetFractionComplete() >= iNearCompletePercent then iCompleteOrNearCompleteEnemyArti = iCompleteOrNearCompleteEnemyArti + 1 end
                        end
                    end
                end
            end
        end
    end

    --if iTargetShortlist == 0 then
        --Target enemy nukes and (if we hae a nuke) enemy SMDs whose fraction is complete
        if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers]) == false then
            for iUnit, oUnit in aiBrain[M27Overseer.reftEnemyNukeLaunchers] do
                if M27UnitInfo.IsUnitValid(oUnit) and oUnit:GetFractionComplete() == 1 and (bDontConsiderShotCount or ((oUnit[refiT3ArtiShotCount] or 0) <= iT3ArtiShotThreshold) and (oUnit[refiT3ArtiLifetimeShotCount] or 0) >= iT3ArtiShotLifetimeThreshold) then
                    iCurDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oT3Arti:GetPosition())
                    if iCurDistance <= iMaxRange and iCurDistance >= iMinRange then
                        iTargetShortlist = iTargetShortlist + 1
                        tTargetShortlist[iTargetShortlist] = oUnit
                    end
                end
            end
        end

        --Also target enemy T2 arti that are close to a teammate's base
        if bDebugMessages == true then LOG(sFunctionRef..': Considering if enemy T2 arti to target. refiNearestEnemyT2PlusStructure='..aiBrain[M27Overseer.refiNearestEnemyT2PlusStructure]..'; Dist to nearest enemy base='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]) end
        if aiBrain[M27Overseer.refiNearestEnemyT2PlusStructure] <= math.min(750, iMaxRange, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] - 50) then
            local tEnemyT2Arti = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryFatboy, oT3Arti:GetPosition(), math.min(750, iMaxRange), 'Enemy')
            if bDebugMessages == true then LOG(sFunctionRef..': Is table of enemy T2 arti in range of our t3 arti empty='..tostring(M27Utilities.IsTableEmpty(tEnemyT2Arti))) end
            if M27Utilities.IsTableEmpty(tEnemyT2Arti) == false then
                local iModDistThreshold = math.max(250, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.5)
                for iUnit, oUnit in tEnemyT2Arti do
                    --Is construction complete?
                    if bDebugMessages == true then LOG(sFunctionRef..': Checking for T2 arti threatening a teammate. oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Fraction complete='..oUnit:GetFractionComplete()..'; iModDistThreshold='..iModDistThreshold..'; Unit mod dist='..M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition())..'; Dist from our arti='..M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oT3Arti:GetPosition())..'; Is table of allied nearby structurse empty='..tostring(M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure * categories.TECH3 + M27UnitInfo.refCategoryStructure * categories.EXPERIMENTAL, oUnit:GetPosition(), 150, 'Ally')))) end
                    if oUnit:GetFractionComplete() >= 1 and (bDontConsiderShotCount or ((oUnit[refiT3ArtiShotCount] or 0) <= iT3ArtiShotThreshold) and (oUnit[refiT3ArtiLifetimeShotCount] or 0) >= iT3ArtiShotLifetimeThreshold) then
                        --Does mod distance mean they are on our side of the map?
                        if M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition()) <= iModDistThreshold then
                            --Are they outside our min range?
                            iCurDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oT3Arti:GetPosition())
                            if iCurDistance >= iMinRange and iCurDistance <= iMaxRange then
                                --Are they threatening valuable friendly structures (or close to threatening)?
                                if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure * categories.TECH3 + M27UnitInfo.refCategoryStructure * categories.EXPERIMENTAL + M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryFixedShield + M27UnitInfo.refCategoryT2Mex, oUnit:GetPosition(), 180, 'Ally')) == false then
                                    iTargetShortlist = iTargetShortlist + 1
                                    tTargetShortlist[iTargetShortlist] = oUnit
                                    if bDebugMessages == true then LOG(sFunctionRef..': Will add arti '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to table of targets') end
                                end
                            end
                        end
                    end
                end
            end
        end

        --Also consider enemy TML firebases if they have a large number (5+)
        if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyTML]) == false and table.getn(aiBrain[M27Overseer.reftEnemyTML]) >= 4 then
            for iUnit, oUnit in aiBrain[M27Overseer.reftEnemyTML] do
                if M27UnitInfo.IsUnitValid(oUnit) and oUnit:GetFractionComplete() >= 1 and (bDontConsiderShotCount or ((oUnit[refiT3ArtiShotCount] or 0) <= iT3ArtiShotThreshold) and (oUnit[refiT3ArtiLifetimeShotCount] or 0) >= iT3ArtiShotLifetimeThreshold) then
                    local iModDistThreshold = math.max(250, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.5)
                    if M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition()) <= iModDistThreshold then
                        --Are they outside our min range?
                        iCurDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oT3Arti:GetPosition())
                        if iCurDistance >= iMinRange and iCurDistance <= iMaxRange then
                            --Are they threatening valuable friendly structures (or close to threatening)?
                            if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure * categories.TECH3 + M27UnitInfo.refCategoryStructure * categories.EXPERIMENTAL + M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryFixedShield + M27UnitInfo.refCategoryT2Mex, oUnit:GetPosition(), M27EngineerOverseer.iTMLMissileRange + 10, 'Ally')) == false then
                                iTargetShortlist = iTargetShortlist + 1
                                tTargetShortlist[iTargetShortlist] = oUnit
                                if bDebugMessages == true then LOG(sFunctionRef..': Will add TML '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to table of targets') end
                            end
                        end
                    end
                end
            end
        end

        --Target enemy T3 MAA if we have an approaching experimental threat that has MAA near it and we dont have t3 units nearby
        if M27Conditions.HaveApproachingLandExperimentalThreat(aiBrain) then
            local tMAAAroundNearestExperimental = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMAA - categories.TECH1 - categories.CYBRAN * categories.TECH3 - categories.AEON * categories.TECH3, aiBrain[M27Overseer.refoNearestRangeAdjustedLandExperimental]:GetPosition(), 60, 'Enemy')
            if M27Utilities.IsTableEmpty(tMAAAroundNearestExperimental) == false and table.getn(tMAAAroundNearestExperimental) >= 5 and GetAirThreatLevel(aiBrain, tMAAAroundNearestExperimental, false, false, true, false, false, nil, nil, nil, nil, nil, nil) >= 2500 then
                --Prioritise T3 MAA if no nearby friendlies
                local tNearbyFriendlies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand + M27UnitInfo.refCategoryStructure - categories.TECH1 - categories.TECH2, aiBrain[M27Overseer.refoNearestRangeAdjustedLandExperimental]:GetPosition(), 40, 'Ally')
                if M27Utilities.IsTableEmpty(tNearbyFriendlies) then
                    local tT3MAA = EntityCategoryFilterDown(categories.TECH3, tMAAAroundNearestExperimental)
                    if M27Utilities.IsTableEmpty(tT3MAA) == false then
                        for iUnit, oUnit in tT3MAA do
                            iCurDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oT3Arti:GetPosition())
                            if iCurDistance >= iMinRange and iCurDistance <= iMaxRange then
                                iTargetShortlist = iTargetShortlist + 1
                                tTargetShortlist[iTargetShortlist] = oUnit
                            end
                        end
                    else
                        for iUnit, oUnit in tMAAAroundNearestExperimental do

                            iCurDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oT3Arti:GetPosition())
                            if iCurDistance >= iMinRange and iCurDistance <= iMaxRange then
                                iTargetShortlist = iTargetShortlist + 1
                                tTargetShortlist[iTargetShortlist] = oUnit
                            end
                        end
                    end
                end
            end
        end

        if iTargetShortlist == 0 and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategorySML, oT3Arti:GetPosition(), 10000, 'Ally')) == false then
            local tEnemySMD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategorySMD, oT3Arti:GetPosition(), iMaxRange, 'Enemy')
            if M27Utilities.IsTableEmpty(tEnemySMD) == false then
                for iUnit, oUnit in tEnemySMD do
                    if oUnit:GetFractionComplete() >= 1 and (bDontConsiderShotCount or ((oUnit[refiT3ArtiShotCount] or 0) <= iT3ArtiShotThreshold) and (oUnit[refiT3ArtiLifetimeShotCount] or 0) >= iT3ArtiShotLifetimeThreshold) then
                        iTargetShortlist = iTargetShortlist + 1
                        tTargetShortlist[iTargetShortlist] = oUnit
                    end
                end
            end
        end
    --end


    if bDebugMessages == true then LOG(sFunctionRef..': Finished going through all enemy experimental structures. Targetshortlist='..iTargetShortlist) end
    if iTargetShortlist > 0 then
        --Pick the target expected to give the best value factoring in angle
        if iTargetShortlist == 1 then
            oTarget = tTargetShortlist[1]
            tTarget = oTarget:GetPosition()
            if bDebugMessages == true then LOG(sFunctionRef..': Only one target '..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..' so will pick this, position='..repru(tTarget)) end
        else
            iBestTargetValue = 0
            for iUnit, oUnit in tTargetShortlist do
                iCurTargetValue = GetDamageFromBomb(aiBrain, oUnit:GetPosition(), iAOE, iDamage, nil, nil, true, 0.25, 1, nil, not(bDontConsiderShotCount), 0.2)
                iCurAngleDif =  M27Utilities.GetAngleDifference(iArtiFacingAngle, M27Utilities.GetAngleFromAToB(oT3Arti:GetPosition(), oUnit:GetPosition())) --M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oT3Arti:GetPosition())
                if iCurAngleDif >= 15 then iCurTargetValue = iCurTargetValue * (1 - 0.5 * iCurAngleDif / 180) end
                if iCurTargetValue > iBestTargetValue then
                    oTarget = oUnit
                    tTarget = oTarget:GetPosition()

                    --if iCompleteOrNearCompleteEnemyArti == 0 or oUnit:GetFractionComplete() >= iNearCompletePercent then
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Unit in shortlist='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iCurAngleDif (angle)='..iCurAngleDif..'; iClosestTarget='..iClosestTarget..'; tTarget='..repru(tTarget)..'; iArtiFacingAngle='..iArtiFacingAngle..'; ANgle to target='..M27Utilities.GetAngleFromAToB(oT3Arti:GetPosition(), oUnit:GetPosition())..'; iCurTargetValue='..iCurTargetValue) end
                --end
            end
        end
    end
    --if target is mobile then adjust it:

    if bDebugMessages == true and oTarget then LOG(sFunctionRef..': oTarget='..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..'; Target unit state='..GetUnitState(oTarget)..'; Does target have a valid focus unit='..tostring(M27UnitInfo.IsUnitValid(oTarget:GetFocusUnit()))..'; Is GetGuardedUnit() valid='..tostring(M27UnitInfo.IsUnitValid(oTarget:GetGuardedUnit()))..'; IsEnemyUnitLikelyMoving='..tostring(M27UnitInfo.IsEnemyUnitLikelyMoving(oTarget)))
        if M27UnitInfo.IsUnitValid(oTarget:GetFocusUnit()) then
            LOG(sFunctionRef..': Target focus unit='..oTarget:GetFocusUnit().UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget:GetFocusUnit())..' with unit state='..GetUnitState(oTarget:GetFocusUnit()))
        end
        if M27UnitInfo.IsUnitValid(oTarget:GetGuardedUnit()) then
            LOG(sFunctionRef..': Target guarded unit='..oTarget:GetGuardedUnit().UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget:GetGuardedUnit())..' with unit state='..GetUnitState(oTarget:GetGuardedUnit()))
        end
    end
    if oTarget and EntityCategoryContains(categories.MOBILE, oTarget.UnitId) and oTarget:GetFractionComplete() == 1 then
        --Mobile targets - lead the target slightly with the shot and also recalculate just as we are ready to fire
        if not(bDontDelayShot) then
            bRecheckWhenReadyToFire = true
            if bDebugMessages == true then LOG(sFunctionRef..': Wont target unit yet, instead will wait until we are ready to fire') end
        end
        local iDistanceAdjust = 5
        if M27UnitInfo.IsEnemyUnitLikelyMoving(oTarget) then
            iDistanceAdjust = 20
            if bDebugMessages == true then LOG(sFunctionRef..': Target is likely moving') end
        end
        tTarget = M27Utilities.MoveInDirection(tTarget, M27UnitInfo.GetUnitFacingAngle(oTarget), iDistanceAdjust)
        if bDebugMessages == true then
            LOG(sFunctionRef..': Were going to target unit '..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..' but it is mobile so will target a bit infront of it by '..iDistanceAdjust..', will draw unit location and the adjusted target if we are ready to fire, bRecheckWhenReadyToFire='..tostring(bRecheckWhenReadyToFire or false))
            if not(bRecheckWhenReadyToFire) then
                M27Utilities.DrawLocation(tTarget, nil, 1)
                M27Utilities.DrawLocation(oTarget:GetPosition(), nil, 2)
            end
        end
    end
    if tTarget then
        iCurDistance = M27Utilities.GetDistanceBetweenPositions(tTarget, oT3Arti:GetPosition())
        if iCurDistance > (iMaxRange - 0.01) then
            tTarget = M27Utilities.MoveInDirection(oT3Arti:GetPosition(), M27Utilities.GetAngleFromAToB(oT3Arti:GetPosition(), tTarget), (iMaxRange - 0.01), false)
            if bDebugMessages == true then LOG(sFunctionRef..': Unit is more than '..(iMaxRange - 0.01)..' away, so will adjust target to '..repru(tTarget)) end
        elseif iCurDistance - 0.01 < iMinRange then
            tTarget = M27Utilities.MoveInDirection(oT3Arti:GetPosition(), M27Utilities.GetAngleFromAToB(oT3Arti:GetPosition(), tTarget), (iMinRange + 0.01), false)
        end
    end
    if not(tTarget) then
        if bDebugMessages == true then LOG(sFunctionRef..': Have no target so will try and get an alternative one') end
        local tEnemyCategoriesOfInterest = {M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategoryExperimentalStructure + M27UnitInfo.refCategorySML + M27UnitInfo.refCategoryT3Mex + M27UnitInfo.refCategoryT3Power + M27UnitInfo.refCategoryAllHQFactories * categories.TECH3 + M27UnitInfo.refCategoryFatboy, M27UnitInfo.refCategoryStructure * categories.TECH2 + M27UnitInfo.refCategoryNavalSurface * categories.TECH3, categories.COMMAND}
        local iCalculationCount = 0 --Used to trakc how many heavy duty calculations we have done this tick and to spread things out

        --First get the best location if just target the start position; note bleow uses similar code to choosing best nuke target
        tTarget = {M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)[1], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)[2], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)[3]}
        --GetDamageFromBomb(aiBrain, tBaseLocation, iAOE, iDamage, iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, bCumulativeShieldHealthCheck, iOptionalSizeAdjust, iOptionalModIfNeedMultipleShots, iMobileValueOverrideFactorWithin75Percent, bT3ArtiShotReduction)
        iBestTargetValue = GetDamageFromBomb(aiBrain, tTarget,      iAOE, iDamage, nil, nil, true, 0.25, 1          , nil, not(bDontConsiderShotCount), 0.2)
        iCalculationCount = iCalculationCount + 1



        --Check we dont have key friendly units close to here
        if M27Utilities.IsTableEmpty(categories.COMMAND + categories.EXPERIMENTAL - M27UnitInfo.refCategorySatellite, tTarget, iAOE * 2, 'Ally') == false then
            iBestTargetValue = 0
            if bDebugMessages == true then LOG(sFunctionRef..': Have a friendly ACU or experimental near here so wont attack') end
        end

        --iBestTargetValue = GetBestAOETarget(aiBrain, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), iAOE, iDamage)
        --Will assume that even if are in range of SMD it isnt loaded, as wouldve reclaimed the nuke if they built SMD in time
        if bDebugMessages == true then LOG(sFunctionRef..': iBestTargetValue for enemy base='..iBestTargetValue..'; if <15k then will consider other targets') end
        if iBestTargetValue < 60000 then --If have high value location for nearest enemy start then just go with this
            for iRef, iCategory in tEnemyCategoriesOfInterest do
                tEnemyUnitsOfInterest = aiBrain:GetUnitsAroundPoint(iCategory, oT3Arti:GetPosition(), iMaxRange, 'Enemy')
                if M27Utilities.IsTableEmpty(tEnemyUnitsOfInterest) == false then
                    for iUnit, oUnit in tEnemyUnitsOfInterest do
                        if M27UnitInfo.IsUnitValid(oUnit) then
                            iCurDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oT3Arti:GetPosition())
                            if iCurDistance > iMinRange and iCurDistance < iMaxRange then
                                --GetDamageFromBomb(aiBrain, tBaseLocation, iAOE, iDamage, iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, bCumulativeShieldHealthCheck, iOptionalSizeAdjust, iOptionalModIfNeedMultipleShots, iMobileValueOverrideFactorWithin75Percent, bT3ArtiShotReduction)
                                iCurTargetValue = GetDamageFromBomb(aiBrain, oUnit:GetPosition(), iAOE, iDamage, nil, nil, true, 0.25, 1, nil, not(bDontConsiderShotCount), 0.2)
                                iCalculationCount = iCalculationCount + 1
                                --Adjust value for facing direction

                                if bDebugMessages == true then LOG(sFunctionRef..': CategoryRef='..iRef..'; target oUnit='..oUnit.UnitId..'; iCurTargetValue='..iCurTargetValue..'; location='..repru(oUnit:GetPosition())) end
                                --Stop looking if tried >=10 targets and have one that is at least 20k of value
                                if iCurTargetValue > iBestTargetValue then
                                    if M27Utilities.IsTableEmpty(categories.COMMAND + categories.EXPERIMENTAL - M27UnitInfo.refCategorySatellite, tTarget, iAOE * 2, 'Ally') == false then
                                        iCurTargetValue = 0
                                    else
                                        iCurAngleDif = M27Utilities.GetAngleDifference(iArtiFacingAngle, M27Utilities.GetAngleFromAToB(oT3Arti:GetPosition(), oUnit:GetPosition()))
                                        --Reduce the value of the target by up to 50% if we will have to turn around a lot for it
                                        if iCurAngleDif >= 15 then iCurTargetValue = iCurTargetValue * (1 - 0.5 * iCurAngleDif / 180) end
                                    end
                                    if iCurTargetValue > iBestTargetValue then
                                        iBestTargetValue = iCurTargetValue
                                        oTarget = oUnit
                                        tTarget = oTarget:GetPosition()
                                    end
                                end
                                if iBestTargetValue > 60000 and iCalculationCount >=15 then break
                                elseif iCalculationCount >= 15 and not(bDontDelayShot) and iTicksWaited < (iMaxTimeToWait - 0.5) then
                                    iCalculationCount = 0
                                    if bDebugMessages == true then LOG(sFunctionRef..': Want to wait a tick as have done lots of calculations alreayd, iTicksWaited='..iTicksWaited) end
                                    iTicksWaited = iTicksWaited + 1
                                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                                    WaitTicks(1)
                                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                                elseif iCalculationCount >= 50 then --backup to ensure we both select a target in time and dont overload the cpu
                                    break
                                end
                            end
                        end
                    end
                end
                if iBestTargetValue > 60000 and iCalculationCount >=10 then break end
            end
                                                    --GetBestAOETarget(aiBrain, tBaseLocation, iAOE, iDamage, bOptionalCheckForSMD, tSMLLocationForSMDCheck, iOptionalTimeSMDNeedsToHaveBeenBuiltFor, iSMDRangeAdjust, iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, iOptionalMaxDistanceCheckOptions, iMobileValueOverrideFactorWithin75Percent, iOptionalShieldReductionFactor)
            if tTarget then tTarget, iBestTargetValue = GetBestAOETarget(aiBrain, tTarget,      iAOE, iDamage, nil,nil,nil,nil, nil, nil, nil, nil, 0.2) end
            if bDebugMessages == true then LOG(sFunctionRef..': iBestTargetValue after getting best location='..iBestTargetValue) end
        end

        if tTarget then --Dont want to adjust the aoe target if are targeting a high priority unit such as a t3 arti
            --GetBestAOETarget(aiBrain, tBaseLocation, iAOE, iDamage, bOptionalCheckForSMD, tSMLLocationForSMDCheck, iOptionalTimeSMDNeedsToHaveBeenBuiltFor, iSMDRangeAdjust, iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, iOptionalMaxDistanceCheckOptions, iMobileValueOverrideFactorWithin75Percent, iOptionalShieldReductionFactor)
            tTarget, iBestTargetValue = GetBestAOETarget(aiBrain, tTarget, iAOE, iDamage, nil,nil,nil,nil, nil, nil, nil, nil, 0.2)
            if bDebugMessages == true then LOG(sFunctionRef..': Adjusted target for aoe, changed tTarget to '..repru(tTarget)..'; iBestTargetValue='..iBestTargetValue) end
        end
    end
    if tTarget then
        M27Utilities.IssueTrackedClearCommands({oT3Arti})
        IssueAttack({oT3Arti}, tTarget)
        if bDebugMessages == true then LOG(sFunctionRef..': Told oT3Arti '..oT3Arti.UnitId..M27UnitInfo.GetUnitLifetimeCount(oT3Arti)..' to attack tTarget '..repru(tTarget)) end
        oT3Arti[M27UnitInfo.refoLastTargetUnit] = oTarget
        if bRecheckWhenReadyToFire and not(bDontDelayShot) and iMaxTimeToWait - iTicksWaited > 0.1 then
            WaitTicks(iMaxTimeToWait - iTicksWaited)
            if bDebugMessages == true then LOG(sFunctionRef..': Have waited '..iMaxTimeToWait..'; will now get a new target and fire') end
            GetT3ArtiTarget(oT3Arti, true)
        else
            --Update tracking for all nearby units
            local tNearbyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure - categories.TECH1, tTarget, iAOE, 'Enemy')
            if M27Utilities.IsTableEmpty(tNearbyUnits) == false then
                for iUnit, oUnit in tNearbyUnits do
                    oUnit[refiT3ArtiShotCount] = (oUnit[refiT3ArtiShotCount] or 0) + 1
                    oUnit[refiT3ArtiLifetimeShotCount] = (oUnit[refiT3ArtiLifetimeShotCount] or 0) + 1
                    if oUnit[refiT3ArtiShotCount] >= iT3ArtiShotThreshold then
                        if not(oUnit[refbScheduledArtiShotReset]) then
                            oUnit[refbScheduledArtiShotReset] = true
                            M27Utilities.DelayChangeVariable(oUnit, refiT3ArtiShotCount, 0, math.min(420, 140 + oUnit[refiT3ArtiLifetimeShotCount] * 1.5))
                            M27Utilities.DelayChangeVariable(oUnit, refbScheduledArtiShotReset, false, math.min(420, 140 + oUnit[refiT3ArtiLifetimeShotCount] * 1.5))
                        end
                    end
                end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': iBestTargetValue after getting best location (will be nil if targeting t3 arti)='..(iBestTargetValue or 'nil')) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RefreshT3ArtiAdjacencyLocations(oT3Arti)
    --M27UnitInfo variables:
    --reftAdjacencyPGensWanted = 'M27UnitAdjacentPGensWanted' --Table, [x] = subref: 1 = category wanted; 2 = buildlocation
    --refiSubrefCategory = 1 --for reftAdjacencyPGensWanted
    --refiSubrefBuildLocation = 2 --for reftAdjacencyPGensWanted

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RefreshT3ArtiAdjacencyLocations'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --If the arti has no valid adjacency locations, then check we haven't recently done this (as dont want to use up too many resources)
    if bDebugMessages == true then LOG(sFunctionRef..': Arti='..oT3Arti.UnitId..M27UnitInfo.GetUnitLifetimeCount(oT3Arti)..' - is the list of adjacencylocations empty='..tostring(M27Utilities.IsTableEmpty(oT3Arti[M27UnitInfo.reftAdjacencyPGensWanted]))..'; Time of last check='..GetGameTimeSeconds() - (oT3Arti[M27UnitInfo.refiTimeOfLastCheck] or -100)..'; ArtiPosition='..repru(oT3Arti:GetPosition())) end
    if not(M27Utilities.IsTableEmpty(oT3Arti[M27UnitInfo.reftAdjacencyPGensWanted])) or GetGameTimeSeconds() - (oT3Arti[M27UnitInfo.refiTimeOfLastCheck] or -100) > 30 then
        oT3Arti[M27UnitInfo.reftAdjacencyPGensWanted] = {}
        local tsPowerBlueprints = {[1]='ueb1101', [2]='ueb1201', [3]='ueb1301'}
        local iT3ArtiRadius = math.max(oT3Arti:GetBlueprint().Physics.SkirtSizeX, oT3Arti:GetBlueprint().Physics.SkirtSizeZ) * 0.5
        local iPowerRadius
        local tPossibleAdjacencyPosition
        local iMaxAdjust
        local tStartingPosition
        local aiBrain = oT3Arti:GetAIBrain()
        local iCurBuildingCount = 0
        local iBuildingCountForSide
        local iT1FurtherAdjust
        for iSide = 1, 4 do
            iBuildingCountForSide = 0
            for iPowerLevel = 3, 1, -1 do
                if not(iPowerLevel == 2 and iBuildingCountForSide > 0) then
                    if iPowerLevel > 1 then iT1FurtherAdjust = 0 end
                    iPowerRadius = __blueprints[tsPowerBlueprints[iPowerLevel]].Physics.SkirtSizeX * 0.5
                    iMaxAdjust = iT3ArtiRadius - iPowerRadius
                    tStartingPosition = M27Utilities.MoveInDirection(oT3Arti:GetPosition(), iSide * 90, iT3ArtiRadius + iPowerRadius, true)
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering if can build power with tech level='..iPowerLevel..'; tStartingPosition='..repru(tStartingPosition)) end
                    for iCurAdjust = -iMaxAdjust, iMaxAdjust, 1 do

                        if iCurAdjust == 0 and iBuildingCountForSide == 0 then tPossibleAdjacencyPosition = {tStartingPosition[1], tStartingPosition[2], tStartingPosition[3]}
                        else tPossibleAdjacencyPosition = M27Utilities.MoveInDirection(tStartingPosition, (iSide - 1) * 90, iCurAdjust + iBuildingCountForSide + iT1FurtherAdjust, true) end

                        if M27EngineerOverseer.CanBuildAtLocation(aiBrain, tsPowerBlueprints[iPowerLevel], tPossibleAdjacencyPosition, M27EngineerOverseer.refActionBuildT3ArtiPower, true) then

                        --[[if aiBrain:CanBuildStructureAt(tsPowerBlueprints[iPowerLevel], tPossibleAdjacencyPosition) then
                            --Cancel any queued up orders that might be preventing us building here, unless the order is to build T3 arti adjacency
                            if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][M27Utilities.ConvertLocationToStringRef(tPossibleAdjacencyPosition)]) == false and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][M27Utilities.ConvertLocationToStringRef(tPossibleAdjacencyPosition)][M27EngineerOverseer.refActionBuildT3ArtiPower]) == true then bDebugMessages = true
                                if bDebugMessages == true then LOG(sFunctionRef..': Will cancel any queued up buildings around here so we can build t3 power and tPossibleAdjacencyPosition='..repru(tPossibleAdjacencyPosition)) end
                                local tLocationToCancel
                                local sCancelLocationRef
                                for iAdjustX = -iPowerRadius, iPowerRadius do
                                    for iAdjustZ = -iPowerRadius, iPowerRadius do
                                        tLocationToCancel = {tPossibleAdjacencyPosition[1] + iAdjustX, 0, tPossibleAdjacencyPosition[3] + iAdjustZ}
                                        tLocationToCancel[2] = GetTerrainHeight(tLocationToCancel[1], tLocationToCancel[3])
                                        sCancelLocationRef = M27Utilities.ConvertLocationToStringRef(tLocationToCancel)
                                        if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sCancelLocationRef]) == false then
                                            for iActionRef, tSubtable in aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sCancelLocationRef] do
                                                for iUniqueEngiRef, oEngineer in tSubtable do
                                                    if bDebugMessages == true then LOG(sFunctionRef..': About to clear oEngineer='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' which was recorded as having iActionRef='..iActionRef) end
                                                    M27Utilities.IssueTrackedClearCommands({oEngineer})
                                                    M27EngineerOverseer.ClearEngineerActionTrackers(aiBrain, oEngineer, true)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': FInished clearing all recorded engi actions in the area needed for building the PGen; IsTableEmpty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][M27Utilities.ConvertLocationToStringRef(tPossibleAdjacencyPosition)]))) end
                            local bIgnoreQueuedBuildings = false
                            if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][M27Utilities.ConvertLocationToStringRef(tPossibleAdjacencyPosition)]) == false then

                            if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][M27Utilities.ConvertLocationToStringRef(tPossibleAdjacencyPosition)]) then
                            --]]
                            --We can build here
                            iCurBuildingCount = iCurBuildingCount + 1
                            iBuildingCountForSide = iBuildingCountForSide + 1
                            oT3Arti[M27UnitInfo.reftAdjacencyPGensWanted][iCurBuildingCount] = {}
                            oT3Arti[M27UnitInfo.reftAdjacencyPGensWanted][iCurBuildingCount][M27UnitInfo.refiSubrefCategory] = M27UnitInfo.refCategoryPower * M27UnitInfo.ConvertTechLevelToCategory(iPowerLevel)
                            oT3Arti[M27UnitInfo.reftAdjacencyPGensWanted][iCurBuildingCount][M27UnitInfo.refiSubrefBuildLocation] = {tPossibleAdjacencyPosition[1], tPossibleAdjacencyPosition[2], tPossibleAdjacencyPosition[3]}
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': Can build at location '..repru(tPossibleAdjacencyPosition)..' for power='..iPowerLevel..'; side='..iSide..'; will draw in blue')
                                M27Utilities.DrawLocation(tPossibleAdjacencyPosition, nil, 1, 100)
                            end
                            if iPowerLevel > 1 then
                                if iPowerLevel == 2 then
                                    if iCurAdjust == -iMaxAdjust then
                                        iT1FurtherAdjust = 5 --Would be 6, but we already adjust for the number of buildings on the size (which will be 1)
                                    end --Not perfect as means if T2 power had to be adjusted in order to move we wont be able to build t1 power
                                end
                                break
                            end
                            --end
                        elseif bDebugMessages == true then
                            LOG(sFunctionRef..': Cant build at location '..repru(tPossibleAdjacencyPosition)..' for power='..iPowerLevel..'; side='..iSide..'; will draw in red; aiBrain:CanBuildStructure result='..tostring(aiBrain:CanBuildStructureAt(tsPowerBlueprints[iPowerLevel], tPossibleAdjacencyPosition)))
                            M27Utilities.DrawLocation(tPossibleAdjacencyPosition, nil, 2, 100)
                        end
                        if iPowerLevel == 1 and iBuildingCountForSide + iCurAdjust + iT1FurtherAdjust >= iMaxAdjust then break end
                    end
                    --Dont want lower tech PGens if managed to find space for higher tech PGen; can only fit 1 t3 or 1 t2 power on a side
                    if iBuildingCountForSide > 0 and (iPowerLevel > 2 or iPowerLevel == 2 and iT1FurtherAdjust == 0) then break end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Finished considering PGen locations for iSide='..iSide..'; iCurBuildingCount='..iCurBuildingCount) end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DetermineTMDWantedForTML(aiBrain, oTML, toOptionalUnitsToProtect)
    --toOptionalUnitsToProtect - so can call this function when just considering a single unit
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DetermineTMDWantedForTML'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': oTML='..oTML.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTML)) end

    local iTMLRange = M27UnitInfo.GetUnitMissileRange(oTML) or M27EngineerOverseer.iTMLMissileRange + 4 --slight buffer given aoe and building sizes
    local tUnitsToProtect
    local tTMLPosition = oTML:GetPosition()
    local sUnitRef
    if toOptionalUnitsToProtect then
        tUnitsToProtect = {}
        for iUnit, oUnit in toOptionalUnitsToProtect do
            if M27UnitInfo.IsUnitValid(oUnit) then
                if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tTMLPosition) <= iTMLRange then
                    table.insert(tUnitsToProtect, oUnit)
                end
            else
                --If unit is listed in table of units wanting protection then remove it
                if oUnit.UnitId then
                    sUnitRef = oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)
                    for iPlateau, toUnits in aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau] do
                        if toUnits[sUnitRef] then
                            toUnits[sUnitRef] = nil
                        end
                    end
                end
            end
        end
    else
        tUnitsToProtect = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryProtectFromTML, oTML:GetPosition(), iTMLRange, 'Ally')
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Identifying any units we want to protect within range of enemy TML '..oTML.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTML)..'; Is tUnitsToProtect empty='..tostring(M27Utilities.IsTableEmpty(tUnitsToProtect))) end
    if M27Utilities.IsTableEmpty(tUnitsToProtect) == false then
        local iBasePathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        local sTMLRef = oTML.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTML)
        local tNearbyTMD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryTMD, oTML:GetPosition(), iTMLRange + 21, 'Ally')
        local iUnitToTML
        local iTMDToTML
        local iUnitToTMD

        local iTMDRange
        local iBuildingSize
        local bCanBlock
        local iAngleTMLToUnit
        local iAngleTMLToTMD
        local sUnitRef
        local iCurPlateau
        for iUnit, oUnit in tUnitsToProtect do
            if M27UnitInfo.IsUnitValid(oUnit) then
                if bDebugMessages == true then LOG(sFunctionRef..': Considering oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; IsTable for oUnit[M27UnitInfo.reftTMLDefence] empty='..tostring(M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftTMLDefence]))..'; oUnit[M27UnitInfo.refbCantBuildTMDNearby]='..tostring((oUnit[M27UnitInfo.refbCantBuildTMDNearby] or false))) end
                if not(oUnit[M27UnitInfo.reftTMLDefence] and oUnit[M27UnitInfo.reftTMLDefence][sTMLRef]) and not(oUnit[M27UnitInfo.refbCantBuildTMDNearby]) then
                    --Havent considered this TML yet
                    --oUnit[M27UnitInfo.reftTMLDefence][sTMLRef] = false --Decided to clear this as want to be able see if we have any TMD built for a unit by checking if this table is empty

                    if bDebugMessages == true then LOG(sFunctionRef..': iBasePathingGroup='..iBasePathingGroup..'; Unit pathing group='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition())) end
                    --if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition()) == iBasePathingGroup then

                    sUnitRef = oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)
                    iBuildingSize = M27UnitInfo.GetBuildingSize(oUnit.UnitId)[1]
                    iAngleTMLToUnit = M27Utilities.GetAngleFromAToB(tTMLPosition, oUnit:GetPosition())
                    if not(oUnit[M27UnitInfo.reftTMLDefence]) then oUnit[M27UnitInfo.reftTMLDefence] = {} end
                    if M27Utilities.IsTableEmpty(tNearbyTMD) == false then
                        for iTMD, oTMD in tNearbyTMD do
                            bCanBlock = false
                            iUnitToTMD = M27Utilities.GetDistanceBetweenPositions(oTMD:GetPosition(), oUnit:GetPosition())
                            iUnitToTML = M27Utilities.GetDistanceBetweenPositions(tTMLPosition, oUnit:GetPosition())
                            iTMDToTML = M27Utilities.GetDistanceBetweenPositions(oTMD:GetPosition(), tTMLPosition)
                            if EntityCategoryContains(categories.AEON, oTMD.UnitId) then
                                iTMDRange = 12.5
                            else iTMDRange = (oTMD:GetBlueprint().Weapon[1].MaxRadius or 31) - 10 --Reduce by 10 to factor in effective range (a guess as to how much coverage is needed)
                            end
                            --Reduce TMDRange to the effective range
                            iTMDRange = iTMDRange - iBuildingSize
                            iAngleTMLToTMD = M27Utilities.GetAngleFromAToB(tTMLPosition, oTMD:GetPosition())
                            if M27Utilities.IsLineFromAToBInRangeOfCircleAtC(iUnitToTML, iTMDToTML, iUnitToTMD, iAngleTMLToUnit, iAngleTMLToTMD, iTMDRange) then
                                --TMD can block the TML
                                if bDebugMessages == true then LOG(sFunctionRef..': oTMD='..oTMD.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTMD)..' can block the TML so will record it') end
                                oUnit[M27UnitInfo.reftTMLDefence][sTMLRef] = oTMD
                                if not(oTMD[M27UnitInfo.reftTMLDefence]) then oTMD[M27UnitInfo.reftTMLDefence] = {} end
                                oTMD[M27UnitInfo.reftTMLDefence][sUnitRef] = oUnit
                                break
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': oTMD='..oTMD.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTMD)..' is not able to block the TML so will record it') end
                            end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': Is TMD empty for sTMLRef='..tostring(M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftTMLDefence][sTMLRef]))) end
                    if not(oUnit[M27UnitInfo.reftTMLDefence][sTMLRef]) then
                        --Dont have anything to protect this unit, so add it to list of units that want protection
                        iCurPlateau = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition())
                        if not(aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau][iCurPlateau]) then aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau][iCurPlateau] = {} end
                        aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau][iCurPlateau][sUnitRef] = oUnit
                        if not(oUnit[M27UnitInfo.reftTMLThreats]) then oUnit[M27UnitInfo.reftTMLThreats] = {} end
                        oUnit[M27UnitInfo.reftTMLThreats][sTMLRef] = oTML
                        if bDebugMessages == true then LOG(sFunctionRef..': Have recorded oTML with sTMLRef='..sTMLRef..' as a threat for unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                    end
                    --end
                end
            end
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DetermineTMDWantedForUnits(aiBrain, tUnits)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DetermineTMDWantedForUnits'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --First remove tUnits from the list of units wanting TMD (will re-add them per the below if we still want TMD)
    if bDebugMessages == true then
        LOG(sFunctionRef..': Start of code, will consider TMD wanted for tUnits.  Log of units in tUnits:')
        for iUnit, oUnit in tUnits do
            LOG(sFunctionRef..': oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit))
        end
    end
    local iCurPlateau, sUnitRef
    for iUnit, oUnit in tUnits do
        sUnitRef = oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)
        if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau]) == false then
            for iPlateau, toUnits in aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau] do
                if toUnits[sUnitRef] then toUnits[sUnitRef] = nil end
            end
        end
    end

    --First check we still have valid TML
    local bValidTML = false

    for iTML, oTML in aiBrain[M27Overseer.reftEnemyTML] do
        if M27UnitInfo.IsUnitValid(oTML) then
            bValidTML = true
            if bDebugMessages == true then LOG(sFunctionRef..': About to determine TMD wanted for the TML '..oTML.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTML)) end
            DetermineTMDWantedForTML(aiBrain, oTML, tUnits)
        end
    end
    if not(bValidTML) then aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau] = nil end
    if bDebugMessages == true then
        LOG(sFunctionRef..': Finished updating TMD wanted for all TML.  Will list out units flagged as wanting TMD')
        if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau]) then
            LOG(sFunctionRef..': No units wanting TMD')
        else
            for iPlateau, toUnits in aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau] do
                if M27Utilities.IsTableEmpty(toUnits) == false then
                    for iUnit, oUnit in toUnits do
                        LOG(sFunctionRef..': Plateau '..iPlateau..'; iUnit='..iUnit..'; Unit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit))
                    end
                end
            end
        end
        LOG(sFunctionRef..': End of code')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function YthothaDeathBallSearchAndSlow(oOwnerBrain, tLikelyPosition)
    --E.g. if become aware of an AI that controls the Ythotha death ball then can call this function to reduce the harmful effects
    local sFunctionRef = 'YthothaDeathBallSearchAndSlow'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iGameTimeStart = GetGameTimeSeconds()
    local tNearbyDeathBalls
    local iDeathBallCategory = categories.EXPERIMENTAL * categories.UNSELECTABLE * categories.SERAPHIM * categories.MOBILE * categories.LAND * categories.INSIGNIFICANTUNIT * categories.UNTARGETABLE
    local bHaveChanged = false
    while GetGameTimeSeconds() < (iGameTimeStart + 4) do
        tNearbyDeathBalls = oOwnerBrain:GetListOfUnits(iDeathBallCategory, false, true)
        if M27Utilities.IsTableEmpty(tNearbyDeathBalls) == false then
            for iUnit, oUnit in tNearbyDeathBalls do
                if not(oUnit.M27DeathBallAdjustActive) and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tLikelyPosition) <= 5 then
                    oUnit.M27DeathBallAdjustActive = true
                    oUnit:SetSpeedMult(0.4)
                    bHaveChanged = true
                    oUnit.M27DeathBallAdjustActive = true
                end
            end
        end
        if bHaveChanged then break end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitSeconds(1)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function CalculateUnitThreatsByType()
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CalculateUnitThreatsByType'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if M27Utilities.IsTableEmpty(tUnitThreatByIDAndType) then
        local sUnitId
        --GetCombatThreatRating(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, iMassValueOfBlipsOverride, iSoloBlipMassOverride, bIndirectFireThreatOnly, bJustGetMassValue, bBlueprintThreat, bAntiNavyOnly, bAddAntiNavy, bSubmersibleOnly, bLongRangeThreatOnly)
        --{bIndirectFireThreatOnly, bJustGetMassValue, bAntiNavyOnly, bAddAntiNavy, bSubmersibleOnly, bLongRangeThreatOnly}
        local tiLandAndNavyThreatTypes = {
            ['1000000'] = { false, false, false, false, false, false }, --Normal land threat
            ['1010000'] = { false, true, false, false, false, false }, --mass cost
            ['1100000'] = { true, false, false, false, false, false }, --Indirect
            ['1000100'] = { false, false, false, true, false, false }, --Normal land threat plus antinavy threat if higher
            ['1001000'] = { false, false, true, false, false, false }, --Antinavy threat only
            ['1000010'] = { false, false, false, false, true, false }, --Submersible threat only
            ['1000001'] = { false, false, false, false, false, true }, --Long range threat only
        }
        --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride, bIncludeAirTorpedo, bBlueprintThreat)
        --{bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, bIncludeAirTorpedo}
        local tiAirThreatTypes = {
            ['200001'] = {false, false, false, false, true,}, --Torpedo bombers
            ['200100'] = { false, false, true, false, false }, --Air to ground
            ['200110'] = { false, false, true, true, false }, --Air to gorund and non-combat
            ['200111'] = { false, false, true, true, true }, --Air to ground and non-combat; note: The code will set TorpBombers to equal the airtoground value if it's nil, hence use of code ending 111
            ['201000'] = { false, true, false, false, false }, --Ground AA
            ['210000'] = { true, false, false, false, false }, --Air AA
            ['210110'] = { true, false, true, true, false }, --Air threat (general)
            ['210111'] = { true, false, true, true, true }, --Air threat (general)
            ['200101'] = { true, false, true, true, true }, --Bombers and torpedo bombers
            --['211000'] = { true, true, false, false, false} --GroundAA and AirAA combined - was thinking of using this for recording IMAP air version but decided to stick to just airaa
        }

        for iRef, tValue in tiLandAndNavyThreatTypes do
            tiThreatRefsCalculated[iRef] = true
        end
        for iRef, tValue in tiAirThreatTypes do
            tiThreatRefsCalculated[iRef] = true
        end



        function RecordBlueprintThreatValues(oBP, sUnitId)

            if not(tUnitThreatByIDAndType[sUnitId]) then tUnitThreatByIDAndType[sUnitId] = {} end
            if bDebugMessages == true then LOG(sFunctionRef..': About to consider different land threat values for unit '..sUnitId..' Name='..LOCF((oBP.General.UnitName) or 'nil')) end
            for iRef, tConditions in tiLandAndNavyThreatTypes do
                --GetCombatThreatRating(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, iMassValueOfBlipsOverride, iSoloBlipMassOverride, bIndirectFireThreatOnly, bJustGetMassValue, bBlueprintThreat, bAntiNavyOnly, bAddAntiNavy, bSubmersibleOnly, bLongRangeThreatOnly)
                --{bIndirectFireThreatOnly, bJustGetMassValue, bAntiNavyOnly, bAddAntiNavy, bSubmersibleOnly, bLongRangeThreatOnly}
                tUnitThreatByIDAndType[sUnitId][iRef] = GetCombatThreatRating(nil, { {['UnitId']=sUnitId }}, nil, nil, nil, tConditions[1], tConditions[2], true, tConditions[3], tConditions[4], tConditions[5], tConditions[6])
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Finished calculating land threat values for '..LOCF((oBP.General.UnitName or 'nil'))..', result='..reprs(tUnitThreatByIDAndType[sUnitId])) end

            for iRef, tConditions in tiAirThreatTypes do
                tUnitThreatByIDAndType[sUnitId][iRef] = GetAirThreatLevel(nil, { {['UnitId']=sUnitId }}, nil, tConditions[1], tConditions[2], tConditions[3], tConditions[4], nil, nil, nil, nil, tConditions[5], true)
            end
            if bDebugMessages == true then
                local sName
                if oBP.General.UnitName then sName = LOCF(oBP.General.UnitName)
                else sName = sUnitId
                end
                LOG(sFunctionRef..': Finished calculating air threat values, result of land and air for '..sName..'='..reprs(tUnitThreatByIDAndType[sUnitId]))

            end
        end

        local iCount = 0

        for iBP, oBP in __blueprints do
            --Updates tUnitThreatByIDAndType
            sUnitId = oBP.BlueprintId
            if bDebugMessages == true then LOG(sFunctionRef..': Considering sUnitId='..(sUnitId or 'nil')..'; Is tUnitThreatByIDAndType not nil='..tostring(not(tUnitThreatByIDAndType[sUnitId]))..'; oBP.Economy.BuildCostMass='..(oBP.Economy.BuildCostMass or 'nil')..'; oBP.General.UnitName='..(oBP.General.UnitName or 'nil')) end
            --if not(tUnitThreatByIDAndType[sUnitId]) and oBP.Economy.BuildCostMass and oBP.General.UnitName then
            if not(tUnitThreatByIDAndType[sUnitId]) and oBP.Economy.BuildCostMass then
                --iCount = iCount + 1
                --if iCount >= 10 then break end
                ForkThread(RecordBlueprintThreatValues, oBP, sUnitId)
            end
        end

    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end
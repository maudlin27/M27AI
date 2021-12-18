tPlatoonRaiderTargets = {} --[a][b]: a = aiBrain Army Index; b = string reference to the location, e.g. x=12.5 z=15 would be 'x12.5;z15'; returns the number of times a raider platoon has been ordered to go there
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')

refbNearestEnemyBugDisplayed = 'M27NearestEnemyBug' --true if have already given error messages for no nearest enemy
refiNearestEnemyIndex = 'M27NearestEnemyIndex'
refiNearestEnemyStartPoint = 'M27NearestEnemyStartPoint'
tPlayerStartPointByIndex = {}

function GetUnitState(oUnit)
    --Returns a string containing oUnit's unit state
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
    return tMatchingUnits
end

function ChooseReclaimTarget(oEngineer)
    --Returns a table containing the target position to attack move to based on reclaimsegments
    --If are no reclaim positions then returns the current segment
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ChooseReclaimTarget'
    if bDebugMessages == true then LOG(sFunctionRef..':Started ChooseReclaimTarget') end
    local tEngPosition = oEngineer:GetPosition()
    local iEngSegmentX, iEngSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tEngPosition)
    if bDebugMessages == true then LOG(sFunctionRef..': iEngSegmentXZ='..iEngSegmentX..'-'..iEngSegmentZ) end
    local sPathingType = M27UnitInfo.GetUnitPathingType(oEngineer)
    local iEngSegmentGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathingType, iEngSegmentX, iEngSegmentZ)
    local aiBrain = oEngineer:GetAIBrain()
    if not(iEngSegmentGroup) then
        M27Utilities.ErrorHandler('iEngSegmentGroup is nil')
    else
        local iCurSegmentX, iCurSegmentZ, iSegmentMass
        --Go through tReclaimAreas to determine optimal choice:
        -- M27MapInfo.tReclaimAreas = {} --Stores key reclaim area locations; tReclaimAreas[iSegmentX][iSegmentZ][x]; if x=1 returns total mass in area; if x=2 then returns position of largest reclaim in the area, if x=3 returns how many platoons have been sent here since the game started
        if bDebugMessages == true then LOG(sFunctionRef..': iEngSegmentGroup='..iEngSegmentGroup..'; sPathingType='..sPathingType) end
        if M27MapInfo.tSegmentBySegmentGroup[sPathingType][iEngSegmentGroup] == nil then
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


            --for iCurReclaimGroupSegment, v in M27MapInfo.tSegmentBySegmentGroup[sPathingType][iEngSegmentGroup] do
                --if not (v[1] == nil) then
                    --iCurSegmentX = v[1]
                    --iCurSegmentZ = v[2]
                    iSegmentMass = M27MapInfo.tReclaimAreas[iCurSegmentX][iCurSegmentZ][1]

                    if iSegmentMass > 0 then
                        --Can we path to this segment?
                        --function InSameSegmentGroup(oUnit, tDestination, bReturnUnitGroupOnly)
                        --GetSegmentGroupOfTarget(sPathing, iTargetSegmentX, iTargetSegmentZ)
                        if M27MapInfo.GetSegmentGroupOfTarget(sPathingType, iCurSegmentX, iCurSegmentZ) == iEngSegmentGroup then
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
            for iCurReclaimGroupSegment, v in M27MapInfo.tSegmentBySegmentGroup[sPathingType][iEngSegmentGroup] do
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
                        if aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation] and aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaim]) == false then
                            iAlreadyAssignedEngis = table.getn(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionReclaim])
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
                if bDebugMessages == true then LOG(sFunctionRef..': About to get iCurSegmentX and Z; sPathingType='..sPathingType..'iEngSegmentGroup='..iEngSegmentGroup..'; iBestMatchSegment='..iBestMatchSegment) end
                iCurSegmentX = M27MapInfo.tSegmentBySegmentGroup[sPathingType][iEngSegmentGroup][iBestMatchSegment][1]
                iCurSegmentZ = M27MapInfo.tSegmentBySegmentGroup[sPathingType][iEngSegmentGroup][iBestMatchSegment][2]
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
    end
end

function GetNearestEnemyIndex(aiBrain, bForceDebug)
    --Returns the ai brain index of the enemy who's got the nearest start location to aiBrain's start location and is still alive
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if bForceDebug == true then bDebugMessages = true end --for error control
    local sFunctionRef = 'GetNearestEnemyIndex'
    local iPlayerArmyIndex = aiBrain:GetArmyIndex()
    local iDistToCurEnemy
    local iMinDistToEnemy = 10000000
    local iNearestEnemyIndex
    local iEnemyStartPos
    if bDebugMessages == true then LOG(sFunctionRef..': Start before looping through brains; aiBrain personality='..ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality..'; brain.Name='..aiBrain.Name) end
    local tBrainsToSearch = ArmyBrains
    if M27Utilities.IsTableEmpty(ArmyBrains) == true then tBrainsToSearch = M27Overseer.AllAIBrainsBackup end
    if M27Utilities.IsTableEmpty(tBrainsToSearch) == true then
        M27Utilities.ErrorHandler('Still have empty brains to search')
        --tBrainsToSearch = M27Overseer.AnotherAIBrainsBackup
        --LOG(sFunctionRef..': Size of tBrainsToSearch='..table.getn(tBrainsToSearch))
    end
    --if bForceDebug then tBrainsToSearch = M27Overseer.AllAIBrainsBackup
    --else tBrainsToSearch = ArmyBrains end


    for iCurBrain, brain in tBrainsToSearch do
        if bDebugMessages == true then LOG(sFunctionRef..': Start of brain loop, iCurBrain='..iCurBrain..'; brain personality='..ScenarioInfo.ArmySetup[brain.Name].AIPersonality..'; brain.Name='..brain.Name..'; if brain isnt equal to our AI brain then will get its start position etc.') end
        if not(brain == aiBrain) then
            if bDebugMessages == true then LOG(sFunctionRef..': Brain is dif to aiBrain so will record its start position number if it doesnt have one already') end
            iEnemyStartPos = brain.M27StartPositionNumber
            if iEnemyStartPos == nil then
                if bDebugMessages == true then LOG(sFunctionRef..': brain doesnt have an M27StartPositionNumber set so will set it now') end
                iEnemyStartPos = M27Utilities.GetAIBrainArmyNumber(brain)
                brain.M27StartPositionNumber = iEnemyStartPos
            end
            if IsEnemy(brain:GetArmyIndex(), iPlayerArmyIndex) then
                if bDebugMessages == true then LOG(sFunctionRef..': brain is an enemy of us') end
                if not(brain:IsDefeated()) then
                    if bDebugMessages == true then LOG(sFunctionRef..': brain is not defeated') end
                    --Strange bug where still returns true for empty slot - below line to avoid this:
                    if brain:GetCurrentUnits(categories.ALLUNITS) > 0 then
                        if bDebugMessages == true then LOG(sFunctionRef..': brain has some units') end
                        if not (M27MapInfo.PlayerStartPoints[iEnemyStartPos] == nil) then
                            if bDebugMessages == true then LOG(sFunctionRef..': iEnemyStartPos='..iEnemyStartPos..'; iPlayerArmyIndex='..iPlayerArmyIndex) end
                            if bDebugMessages == true then LOG(sFunctionRef..': PlayerStartPoints[aiBrain.M27StartPositionNumber][1]='..M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1]..'; M27MapInfo.PlayerStartPoints[iEnemyStartPos][1]='..M27MapInfo.PlayerStartPoints[iEnemyStartPos][1]) end
                            iDistToCurEnemy = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[iEnemyStartPos])
                            if iDistToCurEnemy < iMinDistToEnemy then
                                iMinDistToEnemy = iDistToCurEnemy
                                iNearestEnemyIndex = brain:GetArmyIndex()
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Map info doesnt have a start point for iEnemyStartPos='..iEnemyStartPos) end
                        end
                    else
                        --Can have some cases where have an aibrain but no units, e.g. map Africa has ARMY_9 aibrain name, with no personality, that has no units
                        if bDebugMessages == true then LOG(sFunctionRef..': WARNING: brain isnt defeated but has no units; brain:ArmyIndex='..brain:GetArmyIndex()) end
                    end
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': iPlayerArmyIndex='..iPlayerArmyIndex..'; iEnemyArmyIndex='..brain:GetArmyIndex()..'; IsEnemy isnt true for this') end
            end
        end
    end
    if iNearestEnemyIndex == nil and not(bForceDebug) then
        if not(aiBrain[refbNearestEnemyBugDisplayed]) then
            --Are all enemies defeated?
            local bAllDefeated = true
            local bHaveBrains = false
            for iEnemy, oEnemyBrain in M27Overseer.toEnemyBrains do
                bHaveBrains = true
                if not(oEnemyBrain:IsDefeated()) then
                    bAllDefeated = false break end
            end
            if bHaveBrains and bAllDefeated == true then
                LOG('All enemies defeated, ACU death count='..M27Overseer.iACUDeathCount..'; will ignore errors with nearest enemy index and wait 30 seconds')
                if M27Overseer.iACUDeathCount == 0 then M27Utilities.ErrorHandler('All brains are showing as dead but we havent recorded any ACU deaths.  Assuming all enemies are dead') end
                WaitSeconds(30)
            elseif bHaveBrains then
                M27Utilities.ErrorHandler('iNearestEnemyIndex is nil so will repeat function with logs enabled')
                return GetNearestEnemyIndex(aiBrain, true)
            else
                M27Utilities.ErrorHandler('Have no enemy brains to check if are defeated; will wait 1 second then call again; gametime='..GetGameTimeSeconds())
                WaitTicks(1)
                return GetNearestEnemyIndex(aiBrain, true)
            end
        else return aiBrain[refiNearestEnemyIndex] end
    else
        if iNearestEnemyIndex == nil then
            if not(aiBrain[refbNearestEnemyBugDisplayed]) then
                local iLastValue = aiBrain[refiNearestEnemyIndex]
                if iLastValue == nil then iLastValue = -1 end --so error message wont return nil value
                M27Utilities.ErrorHandler('iNearestEnemyIndex is nil; bForceDebug='..tostring(bForceDebug)..'; relying on last valid value='..iLastValue..'; all future error messages re this will be suppressed; iPlayerArmyIndex='..iPlayerArmyIndex)
                aiBrain[refbNearestEnemyBugDisplayed] = true
                return aiBrain[refiNearestEnemyIndex]
            else
                return aiBrain[refiNearestEnemyIndex]
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..'; iNearestEnemyIndex='..iNearestEnemyIndex) end
            aiBrain[refiNearestEnemyIndex] = iNearestEnemyIndex
        end
        return iNearestEnemyIndex
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
    if iStartPoint == nil then M27Utilities.ErrorHandler('Dont have start position for iArmyIndex='..iArmyIndex) end
    return iStartPoint
end

function GetNearestEnemyStartNumber(aiBrain)
    local iNearestEnemyIndex = GetNearestEnemyIndex(aiBrain)
    return IndexToStartNumber(iNearestEnemyIndex)
end

function GetUnitNearestEnemy(aiBrain, tUnits)
    --returns the unit nearest the enemy start location (or nil if there is none); only considers units that are not dead
    --(note - probably better to have just used GetNearestUnit from M27Utilities)
    return M27Utilities.GetNearestUnit(tUnits, M27MapInfo.PlayerStartPoints[GetNearestEnemyStartNumber(aiBrain)], aiBrain, false)
    --[[
    local iNearestDistance = 100000
    local oNearestUnit
    local tEnemyStart = M27MapInfo.PlayerStartPoints[GetNearestEnemyStartNumber(aiBrain)]
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
    if iIgnoreDistanceFromOwnStart == nil then iIgnoreDistanceFromOwnStart = iIgnoreDistanceFromStartLocation end
    if bOnlyTargetEndDestination == nil then bOnlyTargetEndDestination = false end

    local iMinDistanceFromPlatoon = 30 --To help stop rare error where platoon gets a new path that is near where it currently is
    local bMexNotByUs --true if mex is by us
    local iLoopCount = 0 --Used for debugging
    local iMaxLoopCountBeforeChecks = 20 --If a while loop goes more than this number of times then will send out an error log and turn on debugging even if it's off
    local oUnit = M27PlatoonUtilities.GetPathingUnit(oPlatoonHandle)
    local aiBrain = oPlatoonHandle:GetBrain()
    local bAbort = false
    if aiBrain == nil then
        M27Utilities.ErrorHandler('aiBrain is nil, will return the position for the first player')
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
        M27Utilities.ErrorHandler('Cant find valid unit in platoon, will set platoon to disband and return start position as the movement path')
        oPlatoonHandle[M27PlatoonUtilities.refiCurrentAction] = M27PlatoonUtilities.refActionDisband
        tSortedFinalWaypoints = {M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]}
        if oPlatoonHandle[M27PlatoonUtilities.refiPlatoonCount] and oPlatoonHandle.GetPlan and oPlatoonHandle:GetPlan() and oPlatoonHandle[M27PlatoonUtilities.refiCurrentUnits] then LOG(oPlatoonHandle[M27PlatoonUtilities.refiPlatoonCount]..'; plan='..oPlatoonHandle:GetPlan()..'; currentunits='..oPlatoonHandle[M27PlatoonUtilities.refiCurrentUnits])
        else LOG('Some of platoon core data is nil') end
    else
        local tUnitStart = oUnit:GetPosition()
        local iPlayerArmyIndex = aiBrain:GetArmyIndex()
        local iEnemyStartPos = GetNearestEnemyStartNumber(aiBrain)
        if iEnemyStartPos then
            local sPathingType = M27UnitInfo.GetUnitPathingType(oUnit)
            local iBaseStartGroup = M27MapInfo.GetSegmentGroupOfLocation(sPathingType, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            --function InSameSegmentGroup(oUnit, tDestination, bReturnUnitGroupOnly)
            local iUnitSegmentX, iUnitSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tUnitStart)
            local iUnitSegmentGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathingType, iUnitSegmentX, iUnitSegmentZ)
            local tPossibleMexTargets = {} --Table storing the mex number within tMexByPathingAndGrouping for mexes that aren't in enemy base (or other player base where other player is alive) but are nearer enemy than us
            --Determine PlayerStartPoints:
            local tActivePlayerStartLocations = {}
            local iActivePlayerCount = 0
            local iCurPlayerStartNumber = 0
            if bDebugMessages == true then LOG(sFunctionRef..': sPathingType='..sPathingType..'; iUnitSegmentGroup='..iUnitSegmentGroup) end
            for iCurBrain, brain in ArmyBrains do
                if not(brain:IsDefeated()) then
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
            local tMexesInGroup = M27MapInfo.tMexByPathingAndGrouping[sPathingType][iUnitSegmentGroup]

            local iTotalMexesInGroup
            if M27Utilities.IsTableEmpty(tMexesInGroup) == true then iTotalMexesInGroup = 0
                else iTotalMexesInGroup = table.getn(tMexesInGroup) end
            if iTotalMexesInGroup == nil then iTotalMexesInGroup = 0 end
            if bDebugMessages == true then
                LOG(sFunctionRef..': MexesByPathingAndGrouping='..repr(M27MapInfo.tMexByPathingAndGrouping))
                --M27Utilities.DrawLocations(tMexesInGroup, nil, 7, 1000)
            end
            local bNoBetterTargets
            if bDebugMessages == true then LOG(sFunctionRef..': iActivePlayerCount='..iActivePlayerCount..'; size of tMexByPathingAndGrouping='..iTotalMexesInGroup..'; sPathingType='..sPathingType..'; iUnitSegmentGroup='..iUnitSegmentGroup) end
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
                    sPathingType = M27UnitInfo.GetUnitPathingType(oUnit)
                    iUnitSegmentGroup = 1
                    iTotalMexesInGroup = table.getn(M27MapInfo.tMexByPathingAndGrouping[sPathingType][iUnitSegmentGroup])
                    if iTotalMexesInGroup == nil then
                        M27Utilities.ErrorHandler('iTotalMexesInGroup is nil after looking for iUnitSegmentGroup1')
                        bNoBetterTargets = true
                    elseif iTotalMexesInGroup == 0 then
                        bNoBetterTargets = true
                        M27Utilities.ErrorHandler('iTotalMexesInGroup is nil after looking for iUnitSegmentGroup1')
                    end
                    if bNoBetterTargets == true then return {M27MapInfo.PlayerStartPoints[iEnemyStartPos]} end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': iTotalMexesInGroup='..iTotalMexesInGroup..'; about to do loop') end

            for iCurMex = 1, iTotalMexesInGroup do
                --Is the mex closer to the enemy than to us?
                tCurMexPosition = M27MapInfo.tMexByPathingAndGrouping[sPathingType][iUnitSegmentGroup][iCurMex]
                if M27Utilities.IsTableEmpty(tCurMexPosition) == false then
                    iDistanceToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tCurMexPosition, M27MapInfo.PlayerStartPoints[iEnemyStartPos])
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
                                    elseif M27Utilities.GetDistanceBetweenPositions(tCurMexPosition, M27MapInfo.PlayerStartPoints[iEnemyStartPos]) <= iEndPointMaxDistFromEnemyStart then bIsEndDestinationMex = true end
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
            if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through possible targets, iPossibleTargetCount='..iPossibleTargetCount..'; iEndPointMaxDistFromEnemyStart='..(iEndPointMaxDistFromEnemyStart or 'nil')..'; platoon='..oPlatoonHandle:GetPlan()..oPlatoonHandle[M27PlatoonUtilities.refiPlatoonCount]..'; Platoon location='..repr(oPlatoonHandle:GetPlatoonPosition())) end
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
                    elseif M27Utilities.GetDistanceBetweenPositions(tCurMexPosition, M27MapInfo.PlayerStartPoints[iEnemyStartPos]) <= iEndPointMaxDistFromEnemyStart then bIsEndDestinationMex = true end

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
                    return {M27MapInfo.PlayerStartPoints[iEnemyStartPos]}
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
                return {M27MapInfo.PlayerStartPoints[iEnemyStartPos]}
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
                LOG(repr(tPossibleMexTargets))
                LOG('About to dump friendly mex targets data')
                LOG(repr(tFriendlyPossibleMexes))
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
                            M27Utilities.ErrorHandler('iLoopCount has exceeded iMaxLoopCountBeforeChecks, likely infinite loop; slowing down script')
                            bDebugMessages = true --for error control - want these enabled to help debugging where get this error arising
                            WaitTicks(5)
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
                            M27Utilities.ErrorHandler('tLastMexPosition is empty, iFinalWaypoints='..iFinalWaypoints..repr(tFinalWaypoints)..'; if iFinalWaypoints is > 1 then will change to 1 to try and let code continue working')
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
                        if iWaitCount > 2 then WaitTicks(1) iWaitCount = 0 end
                        bAbort = true
                        if oPlatoonHandle and aiBrain and aiBrain:PlatoonExists(oPlatoonHandle) == true and oUnit and not(oUnit.Dead) then bAbort = false end
                        if bAbort == true then
                            LOG(sFunctionRef..': Warning - platoon or pathing unit no longer exists after waiting 1 tick, aborting')
                            break
                        end
                    end
                end
                if bAbort == false then
                    --Are there any mexes on our side of the map that wouldn't result in a significant detour to pass by? If so then add to queue
                    if iFriendlyPossibleMexes > 0 then
                        if M27Utilities.GetDistanceBetweenPositions(tUnitStart, M27MapInfo.PlayerStartPoints[iPlayerArmyIndex]) > M27Utilities.GetDistanceBetweenPositions(tUnitStart, M27MapInfo.PlayerStartPoints[iEnemyStartPos]) then
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
                                    LOG(sFunctionRef..': iLoopCount has exceeded iMaxLoopCountBeforeChecks, likely infinite loop; slowing down script')
                                    WaitTicks(5)
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
                                        if tFinalWaypoints[iFinalWaypoints] == nil then M27Utilities.ErrorHandler('tFriendlyPossibleMexes[iCurFriendlyMex] is nil; iCurFriendlyMex='..iCurFriendlyMex..'iFinalWaypoints='..iFinalWaypoints..'; tFriendlyMex='..repr(tFriendlyMex)) end
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
                                WaitTicks(1)
                                bAbort = true
                                if oPlatoonHandle and aiBrain and aiBrain:PlatoonExists(oPlatoonHandle) == true and oUnit and not(oUnit.Dead) then bAbort = false end
                                if bAbort == true then
                                    LOG(sFunctionRef..': Warning - platoon or pathing unit no longer exists after waiting 1 tick, aborting')
                                end
                            end
                        end
                    end
                end
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
                    LOG(repr(tFinalWaypoints))
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
                    LOG(repr(tSortedFinalWaypoints))
                end
            end
        else
            M27Utilities.ErrorHandler('Enemy start position is nil, returning our start position')
            tSortedFinalWaypoints = {}
            tSortedFinalWaypoints[1] = {}
            tSortedFinalWaypoints[1] = M27MapInfo.PlayerStartPoints[iPlayerArmyIndex]
        end
    end

    return tSortedFinalWaypoints
end

function SetFactoryRallyPoint(oFactory)
    --Sets the rally point on oFactory
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local iDistFromFactory = 5 --Factories are 8x8, midpoint is middle of it so 4 to end of factory
    local oBrain = oFactory:GetAIBrain()
    if oBrain == nil then M27Utilities.ErrorHandler('SetFactoryRallyPoint: oBrain is Nil') end
    local iEnemyX, iEnemyZ = oBrain:GetCurrentEnemy():GetArmyStartPos()
    if bDebugMessages == true then LOG('SetFactoryRallyPoint: iEnemyX='..iEnemyX) end
    local tFactoryPos = oFactory:GetPosition()
    --Set the rally point near to the factory in the direction of the enemy:
    local iRallyX = tFactoryPos[1]
    local iRallyZ = tFactoryPos[3]
    if iEnemyX > iRallyX then iRallyX = iRallyX + iDistFromFactory
    else iRallyX = iRallyX - iDistFromFactory end
    if iEnemyZ > iRallyZ then iRallyZ = iRallyZ + iDistFromFactory
    else iRallyZ = iRallyZ - iDistFromFactory end

    local tRallyPoint = {iRallyX, GetTerrainHeight(iRallyX, iRallyZ), iRallyZ}
    if bDebugMessages == true then LOG('SetFactoryRallyPoint: tFactoryPos='..tFactoryPos[1]..'-'..tFactoryPos[3]..'; iRallyXZ='..iRallyX..'-'..iRallyZ..'; iEnemyXZ='..iEnemyX..'-'..iEnemyZ) end
    IssueClearFactoryCommands({oFactory})
    IssueFactoryRallyPoint({oFactory}, tRallyPoint)
end


function GetUpgradeCombatWeighting(sEnhancementRef, iFaction)
    --Returns the combat mass mod to apply to an enhancement
    --Note that enhancements have a visual indicator, so if calling this on an enemy you need to have had visual of the enemy at some point
    --iFaction: 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
    --Obtain using aiBrain:GetFactionIndex()

    local iMinor = 0.5
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
    return iTotalMassValue
end

function GetACUMaxDFRange(oACU)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetACUMaxDFRange'
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
    end
    return iRange
end



function GetDirectFireUnitMinOrMaxRange(tUnits, iReturnRangeType)
    --Works if either sent a table of units or a single unit
    --iReturnRangeType: nil or 0: Return min+Max; 1: Return min only; 2: Return max only
    --Cycles through each unit and then each weapon to determine the minimum range
    local iCurRange = 0
    local iMinRange = 1000000000
    local iMaxRange = 0
    local tAllUnits = {}
    if tUnits[1]==nil then tAllUnits[1] = tUnits else tAllUnits = tUnits end
    local tUnitBPs = {}
    local iBPCount = 0
    for i, oUnit in tAllUnits do
        if not(oUnit.Dead) then
            if M27Utilities.IsACU(oUnit) == false then
                if oUnit.GetBlueprint then
                    iBPCount = iBPCount + 1
                    tUnitBPs[iBPCount] = oUnit:GetBlueprint()
                end
            else
                iMaxRange = GetACUMaxDFRange(oUnit)
                iMinRange = iMaxRange
            end
        end
    end
    local tUniqueBPs = {}
    tUniqueBPs = M27Utilities.ConvertTableIntoUniqueList(tUnitBPs)
    for iCurBP, oBP in tUniqueBPs do
        if not(oBP.Weapon == nil) then
            for iCurWeapon, oCurWeapon in oBP.Weapon do
                if not(oCurWeapon.CannotAttackGround == true) then
                    if not(oCurWeapon.ManualFire == true) then
                        iCurRange = oCurWeapon.MaxRadius
                        if iCurRange > iMaxRange then iMaxRange = iCurRange end
                        if iCurRange < iMinRange then iMinRange = iCurRange end
                    end
                end
            end
        end
    end
    if iReturnRangeType == 1 then return iMinRange
    elseif iReturnRangeType == 2 then return iMaxRange
    else return iMinRange, iMaxRange
    end
end

function GetUnitMinGroundRange(tUnits)
    return GetDirectFireUnitMinOrMaxRange(tUnits, 1)
end
function GetUnitMaxGroundRange(tUnits)
    return GetDirectFireUnitMinOrMaxRange(tUnits, 2)
end
function GetUnitMinAndMaxGroundRange(tUnits)
    return GetDirectFireUnitMinOrMaxRange(tUnits, 0)
end

function GetUnitSpeedData(tUnits, aiBrain, bNeedToHaveBlipOrVisual, iReturnType, iOptionalSpeedThreshold)
    --iReturnType: 1 = min speed; 2 = max speed; 3 = average speed; 4 = return a table of the units that we know are <= iOptionalSpeedThreshold
    --bNeedToHaveBlipOrVisual: if true, then will check if aiBrain can see the tUnits; defaults to false
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if bNeedToHaveBlipOrVisual == nil then bNeedToHaveBlipOrVisual = false end
    local tUnitBPs = {}
    local oBlip
    local bCanSeeUnit
    local iValidUnits = 0
    local tSpeedThresholdUnits = {}
    --Get a list of units that can see
    if M27Utilities.IsTableEmpty(tUnits) == true then
        M27Utilities.ErrorHandler('tUnits is empty')
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
        if iValidUnits == 0 then return nil else
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
    local oBlip
    local iArmyIndex = aiBrain:GetArmyIndex()
    local tVisibleUnits = {}
    local iVisibleCount = 0
    for iUnit, oUnit in tUnits do
        if not(oUnit.Dead) then
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
    if iVisibleCount == 0 then return nil
    else return tVisibleUnits end
end

function GetCombatThreatRating(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, iMassValueOfBlipsOverride, iSoloBlipMassOverride, bIndirectFireThreatOnly, bJustGetMassValue)
    --Determines threat rating for tUnits; if bMustBeVisibleToIntelOrSight is true then will assume threat where dont have visual
    --bMustBeVisibleToIntelOrSight - Set to false to get threat information regardless of visibility; automatically done where the unit's owner is equal to aiBrain
    --Threat method: based on mass value * multiplier; 1 if are direct fire, 0.2 if are indirect (0.75 for t1 arti), *2 if are a direct fire structure, *1.5 if are a shield or wall
    --iMassValueOfBlipsOverride - if not nil then will use this instead of coded value for blip threats
    --iSoloBlipMassOverride - similar to massvalue of blips override
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetCombatThreatRating'
    local iBlipThreat = 54 --assumes blip is t1 tank
    local iSoloBlipThreat = 10 -- assumes a single unit as a blip is more likely a scout or engineer
    local iHealthFactor --if unit has 40% health, then threat reduced by (1-40%)*iHealthFactor
    local bOnlyGetIndirectFireThreat = bIndirectFireThreatOnly
    if bOnlyGetIndirectFireThreat == nil then bOnlyGetIndirectFireThreat = false end
    if bJustGetMassValue == nil then bJustGetMassValue = false end

    if not(iSoloBlipMassOverride == nil) then iSoloBlipThreat = iSoloBlipMassOverride end
    if not(iMassValueOfBlipsOverride==nil) then iBlipThreat = iMassValueOfBlipsOverride end
    local iStructureBlipThreat = 0 --Assumes an unrevealed structure has no threat rating
    if bMustBeVisibleToIntelOrSight == nil then bMustBeVisibleToIntelOrSight = true end
    --IsTableEmpty(tTable, bNotEmptyIfSingleValueNotTable)
    if bDebugMessages == true then LOG(sFunctionRef..': About to check if table is empty') end
    if M27Utilities.IsTableEmpty(tUnits, false) == true then
    --if tUnits == nil then
        if bDebugMessages == true then LOG(sFunctionRef..': Warning: tUnits is empty, returning 0') end
        return 0
    else
        if table.getn(tUnits) == 0 then
            --Have sent a single unit instead of a table of units - workaround:
            tUnits = {tUnits}
            if bDebugMessages == true then LOG(sFunctionRef..': tUnits is a table size 0, so moving it into a table incase its a single unit reference') end
        end
        local iArmyIndex = aiBrain:GetArmyIndex()
        if bDebugMessages == true then LOG(sFunctionRef..': tUnits has units in it='..table.getn(tUnits)) end
        local oBlip
        local iCurThreat = 0
        local iMassCost = 0
        local iMassMod
        local iTotalThreat = 0
        local bCalcActualThreat = false
        local iTotalUnits = table.getn(tUnits)
        local iHealthPercentage
        local bOurUnits = false
        for iUnit, oUnit in tUnits do
            iCurThreat = 0
            bCalcActualThreat = false
            if bDebugMessages == true then LOG(sFunctionRef..': About to check if unit is dead') end
            if not(oUnit.Dead) then
                if oUnit:GetAIBrain() == aiBrain then
                    bOurUnits = true
                    if bDebugMessages == true then LOG(sFunctionRef..': Unit is alive and has same ai brain so will determine actual threat') end
                    bCalcActualThreat = true
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Unit is alive and owned by dif ai brain, seeing if we have a blip for it') end
                    if bMustBeVisibleToIntelOrSight == true then
                        oBlip = oUnit:GetBlip(iArmyIndex)
                        if oBlip then
                            if not(oBlip:IsKnownFake(iArmyIndex)) then
                                if oBlip:IsOnRadar(iArmyIndex) or oBlip:IsSeenEver(iArmyIndex) then
                                    if oBlip:IsSeenEver(iArmyIndex) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..'; IsSeenEver is true, so calculating actual threat') end
                                        bCalcActualThreat = true
                                    else
                                        --Is it a structure:
                                        if EntityCategoryContains(categories.STRUCTURE, oUnit:GetBlueprint().BlueprintId) then
                                            if bDebugMessages == true then LOG('iUnit='..iUnit..'; IsSeenEver is false; have a structure so will be reduced threat') end
                                            iCurThreat = iStructureBlipThreat
                                        else
                                            if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..'; IsSeenEver is false; unit isnt a structure so calculating threat based on whether its on its own or not') end
                                            if iTotalUnits <= 1 then iCurThreat = iSoloBlipThreat
                                            else iCurThreat = iBlipThreat end
                                        end
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
            end
            if bCalcActualThreat == true then
                if bDebugMessages == true then LOG(sFunctionRef..': About to calculate threat using actual unit data; unitID='..oUnit:GetUnitId()) end
                --get actual threat calc
                if bJustGetMassValue == true then iCurThreat = oUnit:GetBlueprint().Economy.BuildCostMass
                else
                    iMassMod = 0
                    if bOnlyGetIndirectFireThreat == false then
                        if EntityCategoryContains(categories.DIRECTFIRE, oUnit) then iMassMod = 1
                        elseif EntityCategoryContains(categories.SUBCOMMANDER, oUnit) then iMassMod = 1 --SACUs dont have directfire category for some reason (they have subcommander and overlaydirectfire)
                        elseif EntityCategoryContains(categories.INDIRECTFIRE * categories.ARTILLERY * categories.STRUCTURE * categories.TECH2, oUnit) then iMassMod = 0.1 --Gets doubled as its a structure
                        elseif EntityCategoryContains(categories.INDIRECTFIRE * categories.ARTILLERY * categories.MOBILE * categories.TECH1, oUnit) then iMassMod = 0.9
                        elseif EntityCategoryContains(categories.INDIRECTFIRE * categories.ARTILLERY * categories.MOBILE * categories.TECH3, oUnit) then iMassMod = 0.5
                        elseif EntityCategoryContains(categories.SHIELD, oUnit) then iMassMod = 0.75 --will be doubled for structures
                        elseif EntityCategoryContains(categories.COMMAND, oUnit) then iMassMod = 1 --Put in just in case - code was working before this, but dont want it to be affected yb more recenlty added engineer category
                        elseif EntityCategoryContains(categories.ENGINEER,oUnit) then iMassMod = 0.1 --Engis can reclaim and capture so can't just e.g. beat with a scout
                        end
                    else
                        if EntityCategoryContains(categories.INDIRECTFIRE, oUnit) then
                            iMassMod = 1
                            if EntityCategoryContains(categories.DIRECTFIRE, oUnit) then iMassMod = 0.5 end
                        elseif EntityCategoryContains(categories.ANTIMISSILE, oUnit) then iMassMod = 2 --Doubled for structures ontop of this, i.e. want 4xmass of TMD in indirect fire so can overwhelm it
                        elseif EntityCategoryContains(categories.SHIELD, oUnit) then iMassMod = 1
                        end
                    end
                    if EntityCategoryContains(categories.STRUCTURE, oUnit) then iMassMod = iMassMod * 2 end
                    iMassCost = oUnit:GetBlueprint().Economy.BuildCostMass
                    iHealthPercentage = oUnit:GetHealthPercent()
                    --Reduce threat by health, with the amount depending on if its an ACU and if its an enemy
                    if iMassMod > 0 then
                        if M27Utilities.IsACU(oUnit) == true then

                            iHealthFactor = iHealthPercentage --threat will be mass * iHealthFactor
                            iMassCost = GetACUCombatMassRating(oUnit)
                            if bOurUnits == true then
                                if iHealthPercentage < 0.5 then iHealthFactor = iHealthPercentage * iHealthPercentage
                                elseif iHealthPercentage < 0.9 then iHealthFactor = iHealthPercentage * (iHealthPercentage + 0.1) end
                            else iMassMod = iMassMod * 1.15 --Want to send 15% more than what expect to need against enemy ACU given it can gain veterancy
                            end
                        else
                            if bOurUnits == true then iHealthFactor = iHealthPercentage
                            else
                                if iHealthPercentage > 0.25 then
                                    iHealthFactor = iHealthPercentage * (1 + (1 - iHealthPercentage))
                                else iHealthFactor = 0.25 end
                            end
                        end
                        iCurThreat = iMassCost * iMassMod * iHealthFactor
                        if bDebugMessages == true then LOG(sFunctionRef..': UnitBP='..oUnit:GetUnitId()..'; iMassCost='..iMassCost..'; iMassMod='..iMassMod..'; iHealthPercentage='..iHealthPercentage..'; UnitHealth='..oUnit:GetHealth()..'; UnitMaxHealth='..oUnit:GetBlueprint().Defense.MaxHealth..'; UnitHealth='..oUnit:GetBlueprint().Defense.Health) end
                    end
                end
                --Reduce threat if its under construction
                if oUnit:GetFractionComplete() <= 0.75 then iCurThreat = iCurThreat * 0.1 end
            end
            iTotalThreat = iTotalThreat + iCurThreat
        end
        if bDebugMessages == true then LOG(sFunctionRef..': iTotalThreat='..iTotalThreat) end
        return iTotalThreat
    end
end

function GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride, bIncludeAirTorpedo)
    --Threat value depends on inputs:
    --bIncludeAntiAir - will include anti-air on ground units
    --bIncludeNonCombatAir - adds threat value for transports and scouts
    --bIncludeAirTorpedo - Adds threat for torpedo bombers
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetCombatThreatRating'
    local iSoloBlipThreat = 10 -- assumes a single unit as a blip is more likely a scout or engineer
    local iStructureBlipThreat = 0 --Assumes an unrevealed structure has no threat rating
    if bMustBeVisibleToIntelOrSight == nil then bMustBeVisibleToIntelOrSight = true end
    if bIncludeAirTorpedo == nil then bIncludeAirTorpedo = bIncludeAirToGround end
    if bDebugMessages == true then LOG(sFunctionRef..': About to check if table is empty') end
    --Decide blip threat values:
    if iAirBlipThreatOverride == nil then
        if bIncludeAirToGround == true then
            iAirBlipThreatOverride = 100
        elseif bIncludeAirToAir == true then
            iAirBlipThreatOverride = 50
        elseif bIncludeNonCombatAir == true then
            iAirBlipThreatOverride = 40
        else iAirBlipThreatOverride = 0
        end
    end
    if iMobileLandBlipThreatOverride == nil then
        if bIncludeGroundToAir == true then
            iMobileLandBlipThreatOverride = 28
        else iMobileLandBlipThreatOverride = 0
        end
    end
    if iNavyBlipThreatOverride == nil then
        if bIncludeGroundToAir == true then
            iNavyBlipThreatOverride = 28 --Except for aeon, most t1 navy sucks at AA
        else iNavyBlipThreatOverride = 0
        end
    end
    if iStructureBlipThreatOverride == nil then iStructureBlipThreatOverride = 0 end

    local tBlipThreatByPathingType = {}
    tBlipThreatByPathingType[M27UnitInfo.refPathingTypeAir] = iAirBlipThreatOverride
    tBlipThreatByPathingType[M27UnitInfo.refPathingTypeNavy] = iNavyBlipThreatOverride
    tBlipThreatByPathingType[M27UnitInfo.refPathingTypeLand] = iMobileLandBlipThreatOverride
    tBlipThreatByPathingType[M27UnitInfo.refPathingTypeAmphibious] = iMobileLandBlipThreatOverride
    tBlipThreatByPathingType[M27UnitInfo.refPathingTypeNone] = iStructureBlipThreat

    if bDebugMessages == true then LOG(sFunctionRef..': tBlipThreatByPathingType='..repr(tBlipThreatByPathingType)) end

    --Determine the amount that health impacts on threat
    local iHealthFactor = 1 --if unit has 40% health, then threat reduced by (1-40%)*iHealthFactor
    if bIncludeAirToAir == true then iHealthFactor = 0.4
    elseif bIncludeAirToGround == true then iHealthFactor = 0.5
    else iHealthFactor = 0 end


    --Check if can see the unit or if are relying on the blip:
    local bUnitFitsDesiredCategory
    if M27Utilities.IsTableEmpty(tUnits, false) == true then
        --if tUnits == nil then
        if bDebugMessages == true then LOG(sFunctionRef..': Warning: tUnits is empty, returning 0') end
        return 0
    else
        if table.getn(tUnits) == 0 then
            --Have sent a single unit instead of a table of units - basic workaround:
            tUnits = {tUnits}
            if bDebugMessages == true then LOG(sFunctionRef..': tUnits is a table size 0, so moving it into a table incase its a single unit reference') end
        end
        local iArmyIndex = aiBrain:GetArmyIndex()
        if bDebugMessages == true then LOG(sFunctionRef..': tUnits has units in it='..table.getn(tUnits)) end
        local oBlip
        local iCurThreat = 0
        local iMassCost = 0
        local iMassMod
        local iTotalThreat = 0
        local bCalcActualThreat = false
        local iTotalUnits = table.getn(tUnits)
        local iHealthPercentage
        local bOurUnits = false
        local sCurUnitPathing
        local oCurUnitBlueprint
        local sCurUnitBP
        for iUnit, oUnit in tUnits do
            iCurThreat = 0
            bCalcActualThreat = false
            if bDebugMessages == true then LOG(sFunctionRef..': About to check if unit is dead') end
            if not(oUnit.Dead) then
                sCurUnitPathing = M27UnitInfo.GetUnitPathingType(oUnit)
                if oUnit:GetAIBrain() == aiBrain then
                    bOurUnits = true
                    if bDebugMessages == true then LOG(sFunctionRef..': Unit is alive and has same ai brain so will determine actual threat') end
                    bCalcActualThreat = true
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Unit is alive and owned by dif ai brain, seeing if we have a blip for it') end
                    if bMustBeVisibleToIntelOrSight == true then
                        oBlip = oUnit:GetBlip(iArmyIndex)
                        if oBlip then
                            if not(oBlip:IsKnownFake(iArmyIndex)) then
                                if oBlip:IsOnRadar(iArmyIndex) or oBlip:IsSeenEver(iArmyIndex) then
                                    if oBlip:IsSeenEver(iArmyIndex) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..'; IsSeenEver is true, so calculating actual threat') end
                                        bCalcActualThreat = true
                                    else
                                        iCurThreat = tBlipThreatByPathingType[sCurUnitPathing]
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
                if bCalcActualThreat == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': About to calculate threat using actual unit data') end
                    --get actual threat calc
                    iMassMod = 0 --For non-offensive structures
                    --Does the unit contain any of the categories of interest?
                    bUnitFitsDesiredCategory = false
                    --Exclude based on pathing type initially before considering more precisely:
                    if sCurUnitPathing == M27UnitInfo.refPathingTypeAir then
                        if bIncludeAirToAir == true then bUnitFitsDesiredCategory = true
                        elseif bIncludeAirToGround == true then bUnitFitsDesiredCategory = true
                        elseif bIncludeAirTorpedo == true then bUnitFitsDesiredCategory = true
                        elseif bIncludeNonCombatAir == true then bUnitFitsDesiredCategory = true
                        end
                    elseif bIncludeGroundToAir == true then bUnitFitsDesiredCategory = true end

                    --Is unit still valid? If so then consider its weapons/categories more precisely:
                    if bDebugMessages == true then LOG(sFunctionRef..': bUnitFitsDesiredCategory='..tostring(bUnitFitsDesiredCategory)) end
                    if bUnitFitsDesiredCategory == true then
                        oCurUnitBlueprint = oUnit:GetBlueprint()
                        sCurUnitBP = oCurUnitBlueprint.BlueprintId

                        --Get values for air units:
                        if sCurUnitPathing == M27UnitInfo.refPathingTypeAir then
                            if bIncludeNonCombatAir == true then
                                iMassMod = 1
                            else
                                if bIncludeAirToGround == true then
                                    if EntityCategoryContains(categories.BOMBER + categories.GROUNDATTACK + categories.OVERLAYDIRECTFIRE, sCurUnitBP) == true then iMassMod = 1 end
                                end
                                if bIncludeAirTorpedo == true and EntityCategoryContains(categories.ANTINAVY, sCurUnitBP) == true then iMassMod = 1 end
                                if bDebugMessages == true then LOG(sFunctionRef..': bIncludeAirTorpedo='..tostring(bIncludeAirTorpedo)..'; iMassMod='..iMassMod) end

                                if bIncludeAirToAir == true and iMassMod < 1 then
                                    if EntityCategoryContains(categories.ANTIAIR * categories.AIR, sCurUnitBP) == true then
                                        iMassMod = 1
                                        if bDebugMessages == true then LOG(sFunctionRef..': sCurUnitBP='..sCurUnitBP..': about to see if unit doesnt contain onlyantiair category') end
                                        if EntityCategoryContains(categories.BOMBER, sCurUnitBP) or EntityCategoryContains(categories.GROUNDATTACK, sCurUnitBP) then
                                            iMassMod = 0.05
                                            --Manual adjustments for units with good AA that also have direct fire
                                            if sCurUnitBP == 'XAA0305' then iMassMod = 0.7 --Restorer
                                            elseif sCurUnitBP == 'XEA0306' then iMassMod = 0.7 --Continental
                                            elseif sCurUnitBP == 'UAA0310' then iMassMod = 0.4 --Czar
                                            elseif sCurUnitBP == 'XSA0402' then iMassMod = 0.2 --Sera experi bomber
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            --Non-air pathing type
                            if bDebugMessages == true then LOG(sFunctionRef..': Unit doesnt have air pathing. bIncludeGroundToAir='..tostring(bIncludeGroundToAir)) end
                            if bIncludeGroundToAir == true then
                                if EntityCategoryContains(categories.ANTIAIR, sCurUnitBP) == true then
                                    iMassMod = 1 --Cruisers and T3 aircraft carriers have antiair as well as overlay antiair
                                    if sCurUnitBP == 'urs0103' then iMassMod = 0.05 end --Cybran frigate misclassified as anti-air
                                elseif EntityCategoryContains(categories.OVERLAYANTIAIR, sCurUnitBP) == true then
                                    iMassMod = 0.05
                                    if sCurUnitBP == 'ues0401' then iMassMod = 1 end --atlantis misclassifiefd as not anti-air
                                end
                            end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': iMassMod='..iMassMod) end
                    if iMassMod > 0 then
                        --Onlyantiair - use to weight results when calculating AA threat
                        if iHealthFactor > 0 then
                            iHealthPercentage = oUnit:GetHealthPercent()
                            iMassMod = (1 - (1-iHealthPercentage) * iHealthFactor) * iMassMod
                        end
                        --Only GroundToAir: Increase structure value by 100%
                        if bIncludeGroundToAir == true and sCurUnitPathing == M27UnitInfo.refPathingTypeNone then iMassMod = iMassMod * 2 end
                        iMassCost = oUnit:GetBlueprint().Economy.BuildCostMass
                        iCurThreat = iMassCost * iMassMod
                        if bDebugMessages == true then LOG(sFunctionRef..': UnitBP='..oUnit:GetUnitId()..'; iMassCost='..iMassCost..'; iMassMod='..iMassMod..'iCurThreat='..iCurThreat) end
                    end
                end
                iTotalThreat = iTotalThreat + iCurThreat
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': iTotalThreat='..iTotalThreat) end
        return iTotalThreat
    end
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
            if bDebugMessages == true then LOG('CategoriesInVisibleUnits: iUnit='..iUnit..'; is seen; ID='..oUnit:GetUnitId()) end
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

function IsUnitIdle(oUnit, bGuardWithFocusUnitIsIdle, bGuardWithNoFocusUnitIsIdle, bMovingUnassignedEngiIsIdle)
    --Cycles through various unit states that could indicate the unit is idle
    --if bGuardIsIdle == true then will treat a unit that is guarding/assisting as being idle
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsUnitIdle'
    local bIsIdle
    local iIdleCountThreshold = 1 --Number of times the unit must have been idle to trigger (its increased by 1 this cycle, so 1 effectively means no previous times)
    local refiIdleCount = 'M27UnitIdleCount'
    if oUnit[M27UnitInfo.refbSpecialMicroActive] then bIsIdle = false
    else

        if bGuardWithFocusUnitIsIdle == nil then bGuardWithFocusUnitIsIdle = false end
        if bGuardWithNoFocusUnitIsIdle == nil then bGuardWithNoFocusUnitIsIdle = true end
        if bMovingUnassignedEngiIsIdle == nil then bMovingUnassignedEngiIsIdle = false end
        if oUnit:IsUnitState('Building') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Building') end
            bIsIdle = false
        elseif oUnit:IsUnitState('Moving') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Moving') end
            if bMovingUnassignedEngiIsIdle == true and not(oUnit[M27EngineerOverseer.refiEngineerCurrentAction]) and EntityCategoryContains(M27UnitInfo.refCategoryEngineer, oUnit:GetUnitId()) then
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
            if oUnit.GetFocusUnit then
                local oGuardedUnit = oUnit:GetFocusUnit()
                if oGuardedUnit and not(oGuardedUnit.Dead) and oGuardedUnit.GetUnitId then
                    bHaveValidFocusUnit = true
                end
            end
            if bHaveValidFocusUnit == true then
                return bGuardWithFocusUnitIsIdle
            else return bGuardWithNoFocusUnitIsIdle
            end
        elseif oUnit:IsUnitState('Repairing') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Repairing') end
            bIsIdle = false
        elseif oUnit:IsUnitState('Busy') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Busy') end
            bIsIdle = false
        elseif oUnit:IsUnitState('Patrolling') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Patrolling') end
            bIsIdle = false
        elseif oUnit:IsUnitState('Reclaiming') then
            if bDebugMessages == true then LOG('IsUnitIdle: Unit state is Reclaiming') end
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
                    if bDebugMessages == true then LOG(sFunctionRef..': UnitPos='..repr(tUnitPos)..'; targetpos='..repr(tCurTargetPos)) end
                    if M27Utilities.IsTableEmpty(oNavigator:GetCurrentTargetPos()) == false then
                        if math.abs(tCurTargetPos[1] - tUnitPos[1]) >= iDistanceToNotBeIdle or math.abs(tCurTargetPos[3] - tUnitPos[3]) >= iDistanceToNotBeIdle then
                            bIsIdle = false
                        end
                    end
                    if oNavigator.GetGoalPos then
                        local tCurGoalPos = oNavigator:GetGoalPos()
                        if bDebugMessages == true then LOG(sFunctionRef..': UnitPos='..repr(tUnitPos)..'; GoalPos='..repr(tCurGoalPos)) end
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
    if bIsIdle == false then
        oUnit[refiIdleCount] = 0
        return false
    else
        if oUnit[refiIdleCount] == nil then oUnit[refiIdleCount] = 1
        else oUnit[refiIdleCount] = oUnit[refiIdleCount] + 1 end
        if bDebugMessages == true then LOG(sFunctionRef..': Unit appears idle, but checking against idle threshold. Unit idle count='..oUnit[refiIdleCount]..'; Idle threshold='..iIdleCountThreshold) end
        if oUnit[refiIdleCount] >=  iIdleCountThreshold then
            return true
        else return false
        end
    end
end

--Moved below to customconditions
--[[function DoesACUHaveGun(aiBrain)
    --UCBC includes simialr code but for some reason referencing it (or using a direct copy) causes error
    local oACU = M27Utilities.GetACU(aiBrain)
    local tGunUpgrades = { 'HeavyAntiMatterCannon',
                           'CrysalisBeam',
                           'HeatSink',
                           'CoolingUpgrade',
                           'RateOfFire'
    }
    local bACUHasUpgrade = false

    for iUpgrade, sUpgrade in tGunUpgrades do
        if oACU:HasEnhancement(sUpgrade) == true then
            bACUHasUpgrade = true break
        end
    end
    return bACUHasUpgrade
end]]--

function AddMexesAndReclaimToMovementPath(oPathingUnit, tFinalDestination, iPassingSearchRadius)
    --Considers mex locations and reclaim that are near the path that would take to reach tFinalDestination
    --iPassingSearchRadius - defaults to build distance+10 if not specified
    --Config variables
    local iMinReclaimToConsider = 29 --Will consider a detour if reclaim is more than this

    --Other variables:
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AddMexesAndReclaimToMovementPath'
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
    local iACUSegmentX, iACUSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tCurStartPosition)
    local iUnitPathGroup = M27MapInfo.InSameSegmentGroup(oPathingUnit, tCurStartPosition, true)
  --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to loop through mexes in pathing group') end
    for iCurMex, tMexLocation in M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitPathGroup] do
        local iSegmentX, iSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tMexLocation)
        if iSegmentX <= math.max(iDestinationSegmentX, iACUSegmentX) then
            if iSegmentX >= math.min(iDestinationSegmentX, iACUSegmentX) then
                if iSegmentZ <= math.max(iDestinationSegmentZ, iACUSegmentZ) then
                    if iSegmentZ >= math.min(iDestinationSegmentZ, iACUSegmentZ) then
                        iPossibleMex = iPossibleMex + 1
                        tMexShortlist[iPossibleMex] = {}
                        tMexShortlist[iPossibleMex] = tMexLocation
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
            if bDebugMessages == true then LOG(sFunctionRef..': tMexShortlist='..repr(tMexShortlist)..'; iPassingLocationCount='..iPassingLocationCount) end
            for iCurMex, tMexLocation in tMexShortlist do
                if not(tLastPassThroughPosition == tMexLocation) then
                    if M27Utilities.IsTableEmpty(tMexLocation) == false then
                        --Check it's not close to our current position
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': iCurMex='..iCurMex..'; tMexLocation='..repr(tMexLocation)..'; tCurStartPosition='..repr(tCurStartPosition))
                            if tLastPassThroughPosition == nil then LOG(sFunctionRef..'; tLastPassThroughPosition is nil')
                            else LOG(sFunctionRef..': tLastPassThroughPosition='..repr(tLastPassThroughPosition))
                            end
                        end
                        iCurDistanceToMex = M27Utilities.GetDistanceBetweenPositions(tMexLocation, tCurStartPosition)
                        if iCurDistanceToMex <= iPassingSearchRadius then
                            if iCurDistanceToMex < iMinDistanceToMex then
                                iMinDistanceToMex = iCurDistanceToMex
                                tClosestMex = tMexLocation
                                bHavePassThrough = true
                                if bDebugMessages == true then LOG(sFunctionRef..': Have at least 1 passthrough mex, current tClosestMex='..repr(tClosestMex)) end
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
            --GetReclaimablesMassValue(tReclaimables, bAlsoReturnLargestReclaimPosition, iIgnoreReclaimIfNotMoreThanThis)
            ReclaimRectangle = {}
            tReclaimables = {}
            ReclaimRectangle = Rect(tCurStartPosition[1] - iPassingSearchRadius,tCurStartPosition[3] - iPassingSearchRadius, tCurStartPosition[1] + iPassingSearchRadius, tCurStartPosition[3] + iPassingSearchRadius)
            tReclaimables = GetReclaimablesInRect(ReclaimRectangle)
            tHighestValidReclaim = {}

            iMassValue, tHighestValidReclaim = M27MapInfo.GetReclaimablesMassValue(tReclaimables, true, iMinReclaimToConsider)
            if M27Utilities.IsTableEmpty(tHighestValidReclaim) == false then
                if not(tHighestValidReclaim == tLastPassThroughPosition) then
                    bHavePassThrough = true
                    tPassThroughLocation = tHighestValidReclaim
                end
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

                    if bDebugMessages == true then LOG(sFunctionRef..': Have a pass-through location, iPassingLocationCount='..iPassingLocationCount..'; location='..repr(tPassThroughLocation)..'; about to get position to move near it for construction') end
                    --MoveNearConstruction(aiBrain, oBuilder, tLocation, sBlueprintID, iBuildDistanceMod, bReturnMovePathInstead, bUpdatePlatoonMovePath, bReturnNilIfAlreadyMovingNearConstruction)
                    tAllTargetLocations[iPassingLocationCount] = M27PlatoonUtilities.MoveNearConstruction(aiBrain, oPathingUnit, tPassThroughLocation, nil, -iUnitSpeed, true, false, false)
                    if bDebugMessages == true then LOG(sFunctionRef..': Move position='..repr(tAllTargetLocations[iPassingLocationCount])) end
                    tCurStartPosition = tAllTargetLocations[iPassingLocationCount]
                    if bDebugMessages == true then LOG(sFunctionRef..': CurStartPosition='..repr(tCurStartPosition)) end
                    iCurDistanceToEnd = iTempDistanceToEnd
                else
                    bHavePassThrough = false
                end
            else bHavePassThrough = false
            end
        end
        if bHavePassThrough == false then
            --No move points - move forwards by iSearchIntervals
            if bDebugMessages == true then LOG(sFunctionRef..': No nearby pass-points - moving forwards along path by 10. Position before moving forwards='..repr(tCurStartPosition)) end
            --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
            tCurStartPosition = M27Utilities.MoveTowardsTarget(tCurStartPosition, tFinalDestination, iSearchIntervals, 0)
            if bDebugMessages == true then LOG(sFunctionRef..': Position after moving forwards by '..iSearchIntervals..' ='..repr(tCurStartPosition)) end
            iCurDistanceToEnd = iCurDistanceToEnd - iSearchIntervals
        end
    end
  --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': about to add final destination at the end') end
    tAllTargetLocations[iPassingLocationCount + 1] = {}
    tAllTargetLocations[iPassingLocationCount + 1] = tFinalDestination
    if bDebugMessages == true then
        --DrawLocations(tableLocations, relativeStart, iColour, iDisplayCount, bSingleLocation, iCircleSize)
        M27Utilities.DrawLocations(tAllTargetLocations)
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of function, iPassingLocationCount='..iPassingLocationCount..'; tAllTargetLocations='..repr(tAllTargetLocations)) end
  --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': End of code') end
    return tAllTargetLocations

end

function GetPriorityExpansionMovementPath(aiBrain, oPathingUnit, iMinDistanceOverride, iMaxDistanceOverride)
    --Determiens a high priority location e.g. to send ACU to, and then identifies any places of interest on the way
    --Intended for oPathingUnit to be the ACU, but in theory can be used by any unit
    --Returns nil if no locations can be found
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetPriorityExpansionMovementPath'
  --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Start of code') end
    --if oPathingUnit == M27Utilities.GetACU(aiBrain) then bDebugMessages = true end
    --Key config variables:
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local iSmallestReclaimSizeToConsider = 10 --Reclaim of less than this wont get counted
    local iMinReclaimWanted = 100
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
    local iMinDistanceAwayForReclaim = 5
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
    if bDebugMessages == true then LOG(sFunctionRef..': Start; tUnitPos='..repr(tUnitPos)) end
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
    local iEnemyStartPoint = GetNearestEnemyStartNumber(aiBrain)
    local iMaxDistanceFromEnemy, iMaxDistanceFromStart, iMinDistanceFromStart, iMinDistanceFromEnemy, iCurDistanceFromUnit, bIsFarEnoughFromStart

    if iEnemyStartPoint == nil then
        LOG(sFunctionRef..': ERROR unless enemy is dead - iEnemyStartPoint is nil; returning our start position')
        return M27MapInfo.PlayerStartPoints[iPlayerStartPoint]
    else
        if bDebugMessages == true then LOG(sFunctionRef..': iEnemyStartPoint='..iEnemyStartPoint..'; iPlayerStartPoint='..iPlayerStartPoint) end
        local iDistanceBetweenBases = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[iPlayerStartPoint], M27MapInfo.PlayerStartPoints[iEnemyStartPoint])
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

        local iDistanceFromStartToEnd = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[iPlayerStartPoint], M27MapInfo.PlayerStartPoints[iEnemyStartPoint])

        --First check if overseer has flagged there's nearby reclaim (in which case have this as the end destination)
      --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to check overseer reclaim flag') end
        if bDebugMessages == true then LOG(sFunctionRef..': About to check if reclaim near ACU that overseer has flagged for us to get') end
        if aiBrain[M27Overseer.refbReclaimNearACU] == true then
            if bDebugMessages == true then LOG(sFunctionRef..': Is reclaim near ACU, checking if platoon contains an ACU') end
            local oUnitBP = oPathingUnit:GetBlueprint()
            if EntityCategoryContains(categories.COMMAND, oUnitBP.BlueprintId) == true then
                if bDebugMessages == true then LOG(sFunctionRef..': Platoon contains an ACU, obtaining location of reclaim') end
                if not(aiBrain[M27Overseer.refoReclaimNearACU] == nil) then
                    tFinalDestination = aiBrain[M27Overseer.refoReclaimNearACU].CachePosition
                    if M27Utilities.IsTableEmpty(tFinalDestination) == false then
                        --Check its far enough away from our start (as dont want ACU running behind its base at the start of the game)
                        if bDebugMessages == true then LOG(sFunctionRef..': Reclaim location='..repr(tFinalDestination)..'; checking how far it is from player start') end
                        if M27Utilities.GetDistanceBetweenPositions(tFinalDestination, M27MapInfo.PlayerStartPoints[iPlayerStartPoint]) <= iMinDistanceAwayFromStart then
                            --Its close to our base, so only consider if we could use the mass and its closer to enemy than us
                            if bDebugMessages == true then LOG(sFunctionRef..': Reclaim is close to our base, checking if we have enough available storage') end
                            local iStorageRatio = aiBrain:GetEconomyStoredRatio('MASS')
                            if iStorageRatio == 0 then
                                bHaveFinalDestination = true
                            else
                                local iSpareStorage = (1 - iStorageRatio) * aiBrain:GetEconomyStored('MASS')
                                if iSpareStorage >= 100 then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Reclaim is close to our base, and we have enough storage, checking its closer to enemy than ACU') end
                                    if M27Utilities.GetDistanceBetweenPositions(tFinalDestination, M27MapInfo.PlayerStartPoints[iEnemyStartPoint]) <= M27Utilities.GetDistanceBetweenPositions(tUnitPos, M27MapInfo.PlayerStartPoints[iEnemyStartPoint]) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Reclaim is close to our base, but closer to enemy than us, so choosing it as final destination') end
                                        bHaveFinalDestination = true
                                    end
                                end
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Reclaim is far enough from our start, choosing it as final destination') end
                            bHaveFinalDestination = true
                        end
                    end
                end
            end
        end
      --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Finished check of overseer reclaim flag') end

        --Draw range circles
        if bDebugMessages == true then
            local iDisplayCount = 500         --DrawLocation(tLocation, relativeStart, iColour, iDisplayCount, iCircleSize)
            M27Utilities.DrawLocation(M27MapInfo.PlayerStartPoints[iPlayerStartPoint], false, 2, iDisplayCount, iMinDistanceFromStart)
            M27Utilities.DrawLocation(M27MapInfo.PlayerStartPoints[iEnemyStartPoint], false, 2,iDisplayCount, iMinDistanceFromStart)
            M27Utilities.DrawLocation(M27MapInfo.PlayerStartPoints[iPlayerStartPoint], false, 4,iDisplayCount, iMaxDistanceFromStart)
            M27Utilities.DrawLocation(M27MapInfo.PlayerStartPoints[iEnemyStartPoint], false, 4,iDisplayCount, iMaxDistanceFromStart)
        end


        --Update max distances - want to be between 35-65% of the way to enemy base and our base
        local iCurDistanceFromEnemy, iCurDistanceFromStart
        --================High value reclaim locations (ignoring mexes)================
        --Consider if high value reclaim locations on the map:
        local iChosenReclaimLocationMass = 0

        if bHaveFinalDestination == false then
            --M27MapInfo.UpdateReclaimMarkers() --Moved this to overseer so dont risk ACU waiting a while for this to complete
            if M27MapInfo.iMapTotalMass >= (iMinReclaimWanted * 1.5) then --highly unlikely will have a map where almost all reclaim is in one small area, so this is done to reduce processing load
                if bDebugMessages == true then LOG(sFunctionRef..': Have enough reclaim on map ('..M27MapInfo.iMapTotalMass..') to consider if any high reclaim locations') end
              --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to loop through segments looking at reclaim') end
                for iSegmentX, tVal in M27MapInfo.tReclaimAreas do
                    if math.abs(iSegmentX - iACUSegmentX) <= iMaxSegmentDistanceX then
                        for iSegmentZ, tReclaimInfo in tVal do
                            if math.abs(iSegmentZ - iACUSegmentZ) <= iMaxSegmentDistanceZ then
                                --Are we in the same pathing group?
                                --GetSegmentGroupOfTarget(sPathing, iTargetSegmentX, iTargetSegmentZ)
                                iTargetGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iSegmentX, iSegmentZ)
                                if iTargetGroup == iUnitPathGroup then
                                    --Is there sufficient mass to warrant consideration?
                                    if tReclaimInfo[1] >= 100 then --wont even consider if enough in the area if dont meet this thresthold first
                                        --iSecondMinReclaimCheck = nil --This is set if want an up to date reading on reclaim
                                        --Is the location close enough to warrant consideration?
                                        if bDebugMessages == true then LOG(sFunctionRef..': Segment '..iSegmentX..'-'..iSegmentZ..' might be close enough; ReclaimAmount='..tReclaimInfo[1]) end
                                        tCurSegmentPosition = M27MapInfo.GetPositionFromPathingSegments(iSegmentX, iSegmentZ)
                                        iCurDistanceFromEnemy = M27Utilities.GetDistanceBetweenPositions(tCurSegmentPosition, M27MapInfo.PlayerStartPoints[iEnemyStartPoint])
                                        if iCurDistanceFromEnemy <= iMaxDistanceFromEnemy then
                                            if iCurDistanceFromEnemy >= iMinDistanceFromEnemy then
                                                iCurDistanceFromStart = M27Utilities.GetDistanceBetweenPositions(tCurSegmentPosition, M27MapInfo.PlayerStartPoints[iPlayerStartPoint])
                                                if bDebugMessages == true then LOG(sFunctionRef..': Segment '..iSegmentX..'-'..iSegmentZ..' position='..repr(tCurSegmentPosition)..'; iCurDistanceFromEnemy='..iCurDistanceFromEnemy..'; iCurDistanceFromStart='..iCurDistanceFromStart..'; iMaxDistanceFromEnemy='..iMaxDistanceFromEnemy..'; iMinDistanceFromEnemy='..iMinDistanceFromEnemy..'; iMaxDistanceAbsolute='..iMaxDistanceAbsolute..'; iMaxDistanceFromStart='..iMaxDistanceFromStart..'; iMinDistanceFromStart='..iMinDistanceFromStart) end
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
                                                                        if bDebugMessages == true then LOG(sFunctionRef..': Segment '..iSegmentX..'-'..iSegmentZ..' position='..repr(tCurSegmentPosition)..'; iCurDistanceFromUnit='..iCurDistanceFromUnit..'; far enough away that can consider as final destination') end
                                                                        bIsFarEnoughFromStart = true
                                                                    else
                                                                        --Is a reclaim location so check if is actually still enough reclaim in this area
                                                                        iSecondMinReclaimCheck = math.min(math.max(tReclaimInfo[1] * 0.5, 100),200)
                                                                    end
                                                                end
                                                            end--]]
                                                            if bIsFarEnoughFromStart == true then
                                                                --Have a segment that might have enough reclaim, and is far enough from the start
                                                                --Get reclaim within search radius
                                                                ReclaimRectangle = Rect(tCurSegmentPosition[1] - iSearchRadius,tCurSegmentPosition[3] - iSearchRadius, tCurSegmentPosition[1] + iSearchRadius, tCurSegmentPosition[3] + iSearchRadius)
                                                                tReclaimables = GetReclaimablesInRect(ReclaimRectangle)
                                                                iReclaimInCurrentArea = M27MapInfo.GetReclaimablesMassValue(tReclaimables, false, iSmallestReclaimSizeToConsider)
                                                                if bDebugMessages == true then LOG(sFunctionRef..': Segment '..iSegmentX..'-'..iSegmentZ..' is close enough; iReclaimInCurrentArea='..iReclaimInCurrentArea) end
                                                                --bHaveEnoughReclaim = false
                                                                if iReclaimInCurrentArea >= iMinReclaimWanted then
                                                                    --bHaveEnoughReclaim = true
                                                                    --if iSecondMinReclaimCheck and iReclaimInCurrentArea < iSecondMinReclaimCheck then bHaveEnoughReclaim = false end

                                                                    if bDebugMessages == true then LOG(sFunctionRef..': position '..repr(tCurSegmentPosition)..' has enough reclaim - recording as a possible location') end

                                                                    iPossibleMexLocations = iPossibleMexLocations + 1

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
            end

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
            if bDebugMessages == true then LOG(sFunctionRef..': Already have final destination from overseer = '..repr(tFinalDestination)) end
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
        local bIsCurMexUnclaimed
      --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to record mex for pathing group') end
        --M27MapInfo.RecordMexForPathingGroup(oPathingUnit)
        if bDebugMessages == true then LOG(sFunctionRef..': table of MexByPathingAndGrouping='..table.getn(M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitPathGroup])..'; sPathing='..sPathing..'; iUnitPathGroup='..iUnitPathGroup) end
      --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to cycle through mexes in pathing group') end
        if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitPathGroup]) == false then
            for iCurMex, tMexLocation in M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitPathGroup] do
              --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': iCurMex='..iCurMex..'; tMexLocation='..repr(tMexLocation)..': Start of loop') end
                iSegmentX, iSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tMexLocation)
                if bDebugMessages == true then LOG(sFunctionRef..': Considering mex position='..repr(tMexLocation)..'; iSegmentX,Z='..iSegmentX..'-'..iSegmentZ..'; iACUSegmentX-Z='..iACUSegmentX..'-'..iACUSegmentZ..'; iMaxSegmentDistanceX,Z='..iMaxSegmentDistanceX..'-'..iMaxSegmentDistanceZ) end
                if math.abs(iSegmentX - iACUSegmentX) <= iMaxSegmentDistanceX then
                    if math.abs(iSegmentZ - iACUSegmentZ) <= iMaxSegmentDistanceZ then
                        --Is the location close enough to warrant consideration?
                        iCurDistanceFromEnemy = M27Utilities.GetDistanceBetweenPositions(tMexLocation, M27MapInfo.PlayerStartPoints[iEnemyStartPoint])
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
                                                            if bDebugMessages == true then LOG(sFunctionRef..': tMexLocation='..repr(tMexLocation)..'; iCurDistanceFromUnit='..iCurDistanceFromUnit..'; far enough away that can consider as final destination') end
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
                                                        ReclaimRectangle = Rect(tMexLocation[1] - iSearchRadius,tMexLocation[3] - iSearchRadius, tMexLocation[1] + iSearchRadius, tMexLocation[3] + iSearchRadius)
                                                        tReclaimables = GetReclaimablesInRect(ReclaimRectangle)
                                                        iReclaimInCurrentArea = M27MapInfo.GetReclaimablesMassValue(tReclaimables, false, iSmallestReclaimSizeToConsider)

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
                                                        if bDebugMessages == true then LOG(sFunctionRef..': iPossibleMexLocations='..iPossibleMexLocations..'; tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiMassValue]='..tPossibleMexLocationsAndNumber[iPossibleMexLocations][refiMassValue]..'; iMaxMassInArea='..iMaxMassInArea..'; Location='..repr(tMexLocation)) end
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
              --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': iCurMex='..iCurMex..'; tMexLocation='..repr(tMexLocation)..': End of loop') end
            end
        end
      --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to consider possible locations to pass through') end
        if table.getn(tPossibleMexLocationsAndNumber) > 0 then
            local iMaxPriority = 0
            local iAreaWithMaxPriority
            local iCurPriority
            if bDebugMessages == true then LOG(sFunctionRef..' About to cycle through all possible locations and determine their priority; Total possible locations='..table.getn(tPossibleMexLocationsAndNumber)..'; iMaxMassInArea='..iMaxMassInArea..'; iDistanceFromStartToEnd='..iDistanceFromStartToEnd) end
            for iCurArea, tAreaInfo in tPossibleMexLocationsAndNumber do

                if bDebugMessages == true then
                    LOG(sFunctionRef..'iCurArea='..iCurArea..'; about to reproduce tAreaInfo')
                    LOG(repr(tAreaInfo))
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
        end
        --end
        if bDebugMessages == true then LOG(sFunctionRef..': Near end of code, will return value based on specifics') end
        if bHaveFinalDestination == false then
          --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': Failed to get final destination, repeating again') end
            if bDebugMessages == true then LOG(sFunctionRef..': Failed to find a final destination, will retry with higher bounds unless already done that or no mexes in pathing group') end
            if iMaxDistancePercentage > iStopCyclingMaxThreshold or M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing][iUnitPathGroup]) == true then return nil
            else
                local iNewMaxDistance = iMaxDistancePercentage + 0.2
                return GetPriorityExpansionMovementPath(aiBrain, oPathingUnit, iMinDistanceOverride, iNewMaxDistance)
            end
        else
            --Update final destination to move near it:

            local tRevisedDestination = {}
            if bDebugMessages == true then LOG(sFunctionRef..': About to call MoveNearConstruction') end
            --MoveNearConstruction(aiBrain, oBuilder, tLocation, sBlueprintID, iBuildDistanceMod, bReturnMovePathInstead, bUpdatePlatoonMovePath, bReturnNilIfAlreadyMovingNearConstruction)
            tRevisedDestination = M27PlatoonUtilities.MoveNearConstruction(aiBrain, oPathingUnit, tFinalDestination, nil, -3, true, false, false)
            --=========Get mexes and high value reclaim en-route================
            if bDebugMessages == true then
                LOG(sFunctionRef..': tFinalDestination determined, ='..repr(tFinalDestination)..'; tRevisedDestination='..repr(tRevisedDestination))
                M27Utilities.DrawLocation(tRevisedDestination, nil, 1, 100)
                --Below may cause desync so only enable temporarily
                --if bDebugMessages == true then LOG(sFunctionRef..': SegmentGroup of tFinalDestination='..M27MapInfo.InSameSegmentGroup(oPathingUnit, tFinalDestination, true)) end
                --if bDebugMessages == true then LOG(sFunctionRef..': CanPathToManual for tFinalDestination='..tostring(oPathingUnit:CanPathTo(tFinalDestination))) end
            end
            oPathingUnit.GetPriorityExpansionMovementPath = true
          --if bDebugMessages == true then M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..': About to add nearby reclaim and mexes to movement path') end
            return AddMexesAndReclaimToMovementPath(oPathingUnit, tRevisedDestination)
        end
    end
end

function GetPositionToFollowTargets(tUnitsToFollow, oFollowingUnit, iFollowDistance)
    --If following single unit, then do {oSingleUnit} for tUnitsToFollow
    --returns the units to follow average position if cant find anywhere at iFollowDistance from it
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetPositionToFollowTargets'
    local tTargetPosition = M27Utilities.GetAveragePosition(tUnitsToFollow)
    local tPossibleMovePosition = {}
    local tFollowerPosition = oFollowingUnit:GetPosition()
    if oFollowingUnit and not(oFollowingUnit.Dead) then
        if iFollowDistance == nil then iFollowDistance = 5 end

        --function MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
        --[[local iCount = 0
        local iMaxCount = 40
        local tFollowMovePosition = {}
        local iDirectionMod
        local iCurSegmentGroup = M27MapInfo.InSameSegmentGroup(oFollowingUnit, tTargetPosition, true)
        local iPossibleSegmentX, iPossibleSegmentZ
        local iPossibleGroup
        local sPathing = M27UnitInfo.GetUnitPathingType(oFollowingUnit)--]]
        --function GetPositionNearTargetInSamePathingGroup(tStartPos, tTargetPos, iDistanceFromTarget, iAngleBase, oPathingUnit, iNearbyMethodIfBlocked, bTrySidePositions)
        tPossibleMovePosition = M27PlatoonUtilities.GetPositionNearTargetInSamePathingGroup(tFollowerPosition, tTargetPosition, iFollowDistance, 0, oFollowingUnit, 3, true)
        if tPossibleMovePosition == nil then tPossibleMovePosition = tTargetPosition end
    else
        M27Utilities.ErrorHandler(sFunctionRef..': Warning - trying to follow target but unit do do following is dead or nil - if this triggers more than one cycle in a row then have error')

        tPossibleMovePosition = tFollowerPosition
    end
    return tPossibleMovePosition
end

function GetIntelCoverageOfPosition(aiBrain, tTargetPosition, iMinCoverageWanted)
    --Look for the nearest intel coverage for tTargetPosition, or (if nil) then the visual range of the nearest unit to the position that is friendly
    --if iMinCoverageWanted isn't specified then will return the highest amount, otherwise returns true/false
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetIntelCoverageOfPosition'
    local tCategoryList = {categories.SCOUT, M27UnitInfo.refCategoryRadar}
    local iCurIntelRange, iCurDistanceToPosition, iCurIntelCoverage
    local tCurUnits = {}
    local iMaxIntelCoverage = 0
    for _, iCategoryType in tCategoryList do
        tCurUnits = aiBrain:GetListOfUnits(iCategoryType, false, true)
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
                        if bDebugMessages == true then LOG(sFunctionRef..': iMinCoverage='..iMinCoverageWanted..'; iMaxIntelCoverage='..iMaxIntelCoverage) end
                        return true end
                end
            end
        end
    end
    if iMaxIntelCoverage <= 30 then
        --Consider vision range of nearest friendly units
        local iCurVisionRange
        for iUnit, oUnit in aiBrain:GetUnitsAroundPoint(categories.ALLUNITS, tTargetPosition, 30, 'Ally') do
            iCurVisionRange = oUnit.Intel.VisionRadius
            if iCurVisionRange and iCurVisionRange > iMaxIntelCoverage then
                iCurIntelCoverage = iCurVisionRange - M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tTargetPosition)
                if iCurIntelCoverage > iMaxIntelCoverage then
                    iMaxIntelCoverage = iCurIntelCoverage
                    if not(iMinCoverageWanted==nil) and iCurIntelCoverage > iMinCoverageWanted then return true end
                end
            end
        end
    end
    if iMinCoverageWanted == nil then
        if bDebugMessages == true then LOG(sFunctionRef..': iMinCoverage is nil; returning iMaxIntelCoverage='..iMaxIntelCoverage) end
        return iMaxIntelCoverage
    else
        if bDebugMessages == true then LOG(sFunctionRef..': iMinCoverage='..iMinCoverageWanted..'; iMaxIntelCoverage='..iMaxIntelCoverage) end
        return false end
end

function GetDirectFireWeaponPosition(oFiringUnit)
    --Returns position of oFiringUnit's first DF weapon; nil if oFiringUnit doesnt have a DF weapon; Unit position if no weapon bone
    --for ACU, returns this for the overcharge weapon
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetDirectFireWeaponPosition'
    local oBPFiringUnit = oFiringUnit:GetBlueprint()
    local tShotStartPosition
    if EntityCategoryContains(categories.DIRECTFIRE, oBPFiringUnit.BlueprintId) == true then
        local bIsACU = EntityCategoryContains(categories.COMMAND, oBPFiringUnit.BlueprintId)

        local sFiringBone
        if bDebugMessages == true then LOG(sFunctionRef..': Have a DF unit, working out where shot coming from') end
        --Work out where the shot is coming from:
        for iCurWeapon, oWeapon in oBPFiringUnit.Weapon do
            if oWeapon.RangeCategory and oWeapon.RangeCategory == 'UWRC_DirectFire' then
                if bDebugMessages == true then LOG(sFunctionRef..': Have a weapon with range category') end
                if oWeapon.RackBones then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have a weapon with RackBones') end
                    for _, oRackBone in oWeapon.RackBones do
                        if bDebugMessages == true then LOG(sFunctionRef..' Cur oRackBone='..repr(oRackBone)) end
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
    return tShotStartPosition
end

function IsLineBlocked(tShotStartPosition, tShotEndPosition)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsLineBlocked'
    local bShotIsBlocked = false
    local iFlatDistance = M27Utilities.GetDistanceBetweenPositions(tShotStartPosition, tShotEndPosition)
    local tTerrainPositionAtPoint = {}
    if iFlatDistance > 1 then
        local iAngle = math.atan((tShotEndPosition[2] - tShotStartPosition[2]) / iFlatDistance)
        local iShotHeightAtPoint
        if bDebugMessages == true then LOG(sFunctionRef..': About to check if at any point on path shot will be lower than terrain; iAngle='..iAngle..'; startshot height='..tShotStartPosition[2]..'; target height='..tShotEndPosition[2]..'; iFlatDistance='..iFlatDistance) end
        for iPointToTarget = 1, math.floor(iFlatDistance) do
            --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
            tTerrainPositionAtPoint = M27Utilities.MoveTowardsTarget(tShotStartPosition, tShotEndPosition, iPointToTarget, 0)
            if bDebugMessages == true then LOG(sFunctionRef..': iPointToTarget='..iPointToTarget..'; tTerrainPositionAtPoint='..repr(tTerrainPositionAtPoint)) end
            iShotHeightAtPoint = math.tan(iAngle) * iPointToTarget + tShotStartPosition[2]
            if iShotHeightAtPoint <= tTerrainPositionAtPoint[2] then
                if bDebugMessages == true then LOG(sFunctionRef..': Shot blocked at this position; iPointToTarget='..iPointToTarget..'; iShotHeightAtPoint='..iShotHeightAtPoint..'; tTerrainPositionAtPoint='..tTerrainPositionAtPoint[2]) end
                bShotIsBlocked = true
                break
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Shot not blocked at this position; iPointToTarget='..iPointToTarget..'; iShotHeightAtPoint='..iShotHeightAtPoint..'; tTerrainPositionAtPoint='..tTerrainPositionAtPoint[2]) end
            end
        end
    else bShotIsBlocked = false
    end
    return bShotIsBlocked
end

--NOTE: Use IsLineBlocked if have positions instead of units
function IsShotBlocked(oFiringUnit, oTargetUnit)
    --Returns true or false depending on if oFiringUnit can hit oTargetUnit in a straight line
    --intended for direct fire units only
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsShotBlocked'
    local oBPFiringUnit = oFiringUnit:GetBlueprint()
    local bShotIsBlocked = false
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local tShotStartPosition = GetDirectFireWeaponPosition(oFiringUnit)
    if tShotStartPosition then
        if bDebugMessages == true then LOG(sFunctionRef..': tShotStartPosition='..repr(tShotStartPosition)) end
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
                if bDebugMessages == true then LOG(sFunctionRef..': Have targetbones in the targetunit blueprint; repr='..repr(oBPTargetUnit.AI.TargetBones)) end
                --Is the target higher or lower than the shooter? If higher, want the lowest target bone; if lower, want the highest target bone
                for iBone, sBone in oBPTargetUnit.AI.TargetBones do
                    if oTargetUnit:IsValidBone(sBone) == true then
                        tShotEndPosition = oTargetUnit:GetPosition(sBone)
                        if bDebugMessages == true then LOG(sFunctionRef..' Getting position for sBone='..sBone..'; position='..repr(tShotEndPosition)) end
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
                                    if bDebugMessages == true then LOG(sFunctionRef..' Getting position for sBone='..sBone..'; position='..repr(tShotEndPosition)) end
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
                if bDebugMessages == true then LOG(sFunctionRef..': Couldnt find a bone to target for target unit, so using its position instaed='..repr(tShotEndPosition)) end
            else
                if tTargetUnitDefaultPosition[2] > tShotStartPosition[2] then tShotEndPosition = oTargetUnit:GetPosition(sLowestBone)
                else tShotEndPosition = oTargetUnit:GetPosition(sHighestBone) end
                if bDebugMessages == true then LOG(sFunctionRef..': HighestBone='..sHighestBone..'; lowest bone='..sLowestBone..'; tShotEndPosition='..repr(tShotEndPosition)) end
            end
            --Have the shot end and start positions; Now check that not firing at underwater target
            if tShotEndPosition[2] < GetSurfaceHeight(tShotEndPosition[1], tShotEndPosition[3]) then
                bShotIsBlocked = true
            else
                --Have the shot end and start positions; now want to move along a line between the two and work out if terrain will block the shot
                bShotIsBlocked = IsLineBlocked(tShotStartPosition, tShotEndPosition)
            end
        end
    end
    return bShotIsBlocked
end

function IssueDelayMoveBase(tUnits, tTarget, iDelay)
    WaitTicks(iDelay)
    IssueMove(tUnits, tTarget)
end

function IssueDelayedMove(tUnits, tTarget, iDelay)
    ForkThread(IssueDelayMoveBase, tUnits, tTarget, iDelay)
end

function IsTargetUnderShield(aiBrain, oTarget, bIgnoreMobileShield)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsTargetUnderShield'
    --Determines if target is under a shield
    if bIgnoreMobileShield == nil then bIgnoreMobileShield = false end
    local bUnderShield = false
    local iShieldSearchRange = 46 --T3 sera shield is 46; bulwark is 120; will go with sera t3 for now
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
    local iShieldCategory = categories.SHIELD
    if bIgnoreMobileShield == true then iShieldCategory = categories.SHIELD * categories.STRUCTURE end
    local tNearbyShields = aiBrain:GetUnitsAroundPoint(iShieldCategory, tTargetPos, iShieldSearchRange, sSearchType)
    if bDebugMessages == true then LOG(sFunctionRef..': Searching for shields around '..repr(tTargetPos)..'; iShieldSearchRange='..iShieldSearchRange..'; sSearchType='..sSearchType) end
    if M27Utilities.IsTableEmpty(tNearbyShields) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': Size of tNearbyShields='..table.getn(tNearbyShields)) end
        local oCurUnitBP, iCurShieldRadius, iCurDistanceFromTarget
        for iUnit, oUnit in tNearbyShields do
            if not(oUnit.Dead) then
                oCurUnitBP = oUnit:GetBlueprint()
                iCurShieldRadius = 0
                if oCurUnitBP.Defense and oCurUnitBP.Defense.Shield then
                    if bDebugMessages == true then LOG(sFunctionRef..': Target has a shield, will check its shield size and how close that is to the target') end
                    iCurShieldRadius = oCurUnitBP.Defense.Shield.ShieldSize
                    if iCurShieldRadius > 0 then
                        iCurDistanceFromTarget = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tTargetPos)
                        if bDebugMessages == true then LOG(sFunctionRef..': iCurDistance to shield='..iCurDistanceFromTarget..'; iCurShieldRadius='..iCurShieldRadius) end
                        if iCurDistanceFromTarget <= iCurShieldRadius then
                            if bDebugMessages == true then LOG(sFunctionRef..': Shield is large enough to cover target') end
                            bUnderShield = true
                            break
                        end
                    elseif bDebugMessages == true then LOG(sFunctionRef..': Shield radius isnt >0')
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Blueprint doesnt have a shield value; UnitID='..oUnit:GetUnitId()) end
                end
            elseif bDebugMessages == true then LOG(sFunctionRef..': Unit is dead')
            end
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': tNearbyShields is empty') end
    end
    return bUnderShield
end

function GetRandomPointInAreaThatCanPathTo(sPathingType, iSegmentGroup, tMidpoint, iMaxDistance, iMinDistance)
    --Tries to find a random location in a square around tMidpoint that can path to; returns nil if couldnt find anywhere


    local iLoopCount = 0
    local iMaxLoop = 20
    local tEndDestination

    local iMidSegmentX, iMidSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tMidpoint)
    local iSegmentMaxRange = iMaxDistance / M27MapInfo.iPathingIntervalSize
    local iSegmentMinRange = iMinDistance / M27MapInfo.iPathingIntervalSize

    local iMinSegmentX = math.max(1, iMidSegmentX - iSegmentMaxRange)
    local iMaxSegmentX = math.min(M27MapInfo.iMaxBaseSegmentX, iMidSegmentX + iSegmentMaxRange)
    local iMinSegmentZ = math.max(1, iMidSegmentZ - iSegmentMaxRange)
    local iMaxSegmentZ = math.min(M27MapInfo.iMaxBaseSegmentZ, iMidSegmentZ + iSegmentMaxRange)

    local iConstraintMinX = math.max(1, iMidSegmentX - iSegmentMinRange)
    local iConstraintMaxX = math.min(M27MapInfo.iMaxBaseSegmentX, iMidSegmentX + iSegmentMinRange)
    local iConstraintMinZ = math.max(1, iMidSegmentZ - iSegmentMinRange)
    local iConstraintMaxZ = math.min(M27MapInfo.iMaxBaseSegmentZ, iMidSegmentZ + iSegmentMinRange)

    local iCurMinSegmentZ, iCurMaxSegmentZ
    local iRandX, iRandZ
    local iRandFlag
    local iPathingTarget
    while not(iPathingTarget == iSegmentGroup) do
        iLoopCount = iLoopCount + 1
        if iLoopCount > iMaxLoop then
            M27Utilities.ErrorHandler('Couldnt find random point in area, tMidpoint='..repr(tMidpoint)..'; iMaxDistance='..iMaxDistance..'; iMinDistance='..iMinDistance..'; sPathingType='..sPathingType..'; iSegmentGroup='..iSegmentGroup..'; will return midpoint instead')
            return tMidpoint
        end

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

        --Can we path here?
        iPathingTarget = M27MapInfo.GetSegmentGroupOfTarget(sPathingType, iRandX, iRandZ)
    end
    if iPathingTarget == iSegmentGroup then
        tEndDestination = M27MapInfo.GetPositionFromPathingSegments(iRandX, iRandZ)
    end
    return tEndDestination
end

function GetNearestRallyPoint(aiBrain, tPosition)
    --Placeholder code below - longer term want to integrate this with forward base logic
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
    return tNearestMex
end
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local XZDist = import('/lua/utilities.lua').XZDistanceTwoVectors
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')

function MoveAwayFromTargetTemporarily(oUnit, iTimeToRun, tPositionToRunFrom)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MoveAwayFromTargetTemporarily'

    local tUnitPosition = oUnit:GetPosition()
    local iUnitSpeed = oUnit:GetBlueprint().Physics.MaxSpeed
    local iDistanceToMove = (iTimeToRun + 1) * iUnitSpeed
    local tRevisedPositionToRunFrom
    if tUnitPosition[1] == tPositionToRunFrom[1] and tUnitPosition[3] == tPositionToRunFrom[3] then
        local aiBrain = oUnit:GetAIBrain()
        tRevisedPositionToRunFrom = M27Utilities.MoveTowardsTarget(tUnitPosition, M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)], 1, 0)
        if bDebugMessages == true then LOG(sFunctionRef..': Unit position was the same as position to run from, so will run from enemy ase instead, tRevisedPositionToRunFrom='..repr(tRevisedPositionToRunFrom)) end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': Will try to run from '..repr(tPositionToRunFrom)) end
        tRevisedPositionToRunFrom = tPositionToRunFrom
    end


    local tNewTargetIgnoringGrouping = M27Utilities.MoveTowardsTarget(tUnitPosition, tRevisedPositionToRunFrom, iDistanceToMove, 180)
    if bDebugMessages == true then LOG(sFunctionRef..': tNewTargetIgnoringGrouping='..repr(tNewTargetIgnoringGrouping)..'; tUnitPosition='..repr(tUnitPosition)) end
    local tNewTargetInSameGroup = M27PlatoonUtilities.GetPositionNearTargetInSamePathingGroup(tUnitPosition, tNewTargetIgnoringGrouping, 0, 0, oUnit, 3, true, false, 0)
    if tNewTargetInSameGroup then
        if bDebugMessages == true then LOG(sFunctionRef..': Starting bomber dodge for unit='..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; tNewTargetInSameGroup='..repr(tNewTargetInSameGroup)) end
        IssueClearCommands({oUnit})
        IssueMove({oUnit}, tNewTargetInSameGroup)
        oUnit[M27UnitInfo.refbSpecialMicroActive] = true
        if oUnit.PlatoonHandle then
            oUnit.PlatoonHandle[M27UnitInfo.refbSpecialMicroActive] = true
        end
        M27Utilities.DelayChangeVariable(oUnit, M27UnitInfo.refbSpecialMicroActive, false, iTimeToRun)
    end
end

function ForkedMoveInHalfCircle(oUnit, iTimeToRun, tPositionToRunFrom)
    --More intensive version of MoveAwayFromTargetTemporarily, intended e.g. for ACUs
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ForkedMoveInHalfCircle'

    --KEY CONFIG SETTINGS:

    local iInitialAngleAdj = 30
    local iAngleMaxSingleAdj = 30
    local iTempDistanceAwayToMove = 1.5
    local iDistanceIncreasePerCycle = 0.3
    local iDistanceIncreaseCompoundFactor = 1.5
    --local iTicksBetweenOrders = 2

    local iStartTime = GetGameTimeSeconds()
    oUnit[M27UnitInfo.refiGameTimeMicroStarted] = iStartTime
    local iLoopCount = 0
    local iMaxLoop = iTimeToRun * 10 + 1
    local tUnitStartPosition = oUnit:GetPosition()
    local iAngleToTargetToEscape = M27Utilities.GetAngleFromAToB(tUnitStartPosition, tPositionToRunFrom)
    local iCurFacingDirection = M27UnitInfo.GetUnitFacingAngle(oUnit)
    local iAngleAdjFactor
    local iFacingAngleWanted = iAngleToTargetToEscape + 180
    if iFacingAngleWanted >= 360 then iFacingAngleWanted = iFacingAngleWanted - 360 end

    --Do we turn clockwise or anti-clockwise?
    if math.abs(iCurFacingDirection - iFacingAngleWanted) > 180 then iAngleAdjFactor = 1 --Clockwise
    else iAngleAdjFactor = -1 end --Anticlockwise


    local iCurAngleDif

    local tTempLocationToMove

    oUnit[M27UnitInfo.refbSpecialMicroActive] = true
    if oUnit.PlatoonHandle then
        oUnit.PlatoonHandle[M27UnitInfo.refbSpecialMicroActive] = true
    end
    M27Utilities.DelayChangeVariable(oUnit, M27UnitInfo.refbSpecialMicroActive, false, iTimeToRun)

    if bDebugMessages == true then LOG(sFunctionRef..': About to start main loop for move commands; iTimeToRun='..iTimeToRun..'; iStartTime='..iStartTime..'; iCurFacingDirection='..iCurFacingDirection..'; iAngleToTargetToEscape='..iAngleToTargetToEscape..'; iFacingAngleWanted='..iFacingAngleWanted..'; tUnitStartPosition='..repr(tUnitStartPosition)) end
    IssueClearCommands({oUnit})
    local iTempAngleDirectionToMove = iCurFacingDirection + iInitialAngleAdj * iAngleAdjFactor
    while not(iTempAngleDirectionToMove == iFacingAngleWanted) do
        iLoopCount = iLoopCount + 1
        if iLoopCount > iMaxLoop then M27Utilities.ErrorHandler('Loop has gone on for too long, likely infinite') break end

        iCurAngleDif = math.abs(iTempAngleDirectionToMove - iFacingAngleWanted)
        if iCurAngleDif < iAngleMaxSingleAdj then iTempAngleDirectionToMove = iFacingAngleWanted
        else
            iTempAngleDirectionToMove = iTempAngleDirectionToMove + iAngleMaxSingleAdj * iAngleAdjFactor
            if iTempAngleDirectionToMove > 360 then iTempAngleDirectionToMove = iTempDistanceAwayToMove - 360 end
        end
        iTempDistanceAwayToMove = iTempDistanceAwayToMove + iDistanceIncreasePerCycle * iDistanceIncreasePerCycle * (iDistanceIncreaseCompoundFactor ^ iLoopCount - 1)
        tTempLocationToMove = M27Utilities.MoveInDirection(tUnitStartPosition, iTempAngleDirectionToMove, iTempDistanceAwayToMove)
        IssueMove({oUnit}, tTempLocationToMove)
        if bDebugMessages == true then LOG(sFunctionRef..': tTempLocationToMove='..repr(tTempLocationToMove)..'; iTempAngleDirectionToMove='..iTempAngleDirectionToMove) end
    end

    --[[while (oUnit[M27UnitInfo.refiGameTimeMicroStarted] == iStartTime and GetGameTimeSeconds() - iStartTime < iTimeToRun) do
        iLoopCount = iLoopCount + 1
        if iLoopCount > iMaxLoop then M27Utilities.ErrorHandler('Loop has gone on for too long, likely infinite') break end
        iCurFacingDirection = M27UnitInfo.GetUnitFacingAngle(oUnit)
        iCurAngleDif = iFacingAngleWanted - iCurFacingDirection
        if math.abs(iCurAngleDif) <= iAngleMaxSingleAdj then
            if bDebugMessages == true then LOG(sFunctionRef..': Angle change less than threshold so setting angle to move to iFacingAngleWanted='..iFacingAngleWanted) end
            iTempAngleDirectionToMove = iFacingAngleWanted
        else
            iTempAngleDirectionToMove = iCurFacingDirection + iAngleMaxSingleAdj * iAngleAdjFactor
            if bDebugMessages == true then LOG(sFunctionRef..': iCurFacingDirection='..iCurFacingDirection..'; iAngleMaxSingleAdj*iAngleAdjFactor='..(iAngleMaxSingleAdj * iAngleAdjFactor)..'; iTempAngleDirectionToMove pre cap='..iTempAngleDirectionToMove) end
            if iTempAngleDirectionToMove > 360 then iTempAngleDirectionToMove = iTempAngleDirectionToMove - 360 end

        end

        tTempLocationToMove = M27Utilities.MoveInDirection(oUnit:GetPosition(), iTempAngleDirectionToMove, iTempDistanceAwayToMove)
        IssueMove({oUnit}, tTempLocationToMove)
        if bDebugMessages == true then LOG(sFunctionRef..': iLoopCount='..iLoopCount..'; Just issued move order to '..repr(tTempLocationToMove)..'; iCurFacingDirection='..iCurFacingDirection..'; iTempAngleDirectionToMove='..iTempAngleDirectionToMove) end

        WaitTicks(iTicksBetweenOrders)
    end--]]
end

function MoveInHalfCircleTemporarily(oUnit, iTimeToRun, tPositionToRunFrom)
    ForkThread(ForkedMoveInHalfCircle, oUnit, iTimeToRun, tPositionToRunFrom)
end

function ForkedMoveInCircle(oUnit, iTimeToRun)
    --More intensive version of MoveAwayFromTargetTemporarily, intended e.g. for ACUs
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ForkedMoveInCircle'

    --KEY CONFIG SETTINGS: (these will work sometimes but not always against an aeon strat)
    local iInitialAngleAdj = 15
    local iAngleMaxSingleAdj = 45
    local iInitialDistanceAdj = -1
    local iDistanceAwayToMove = 2
    local iTicksBetweenOrders = 4

    local iStartTime = GetGameTimeSeconds()
    oUnit[M27UnitInfo.refiGameTimeMicroStarted] = iStartTime
    local iLoopCount = 0
    local iMaxLoop = iTimeToRun * 10 + 1
    local tUnitStartPosition = oUnit:GetPosition()
    --local iAngleToTargetToEscape = M27Utilities.GetAngleFromAToB(tUnitStartPosition, tPositionToRunFrom)
    local iCurFacingDirection = M27UnitInfo.GetUnitFacingAngle(oUnit)
    local iAngleAdjFactor = 1
    --local iFacingAngleWanted = iAngleToTargetToEscape + 180
    --if iFacingAngleWanted >= 360 then iFacingAngleWanted = iFacingAngleWanted - 360 end

    --Do we turn clockwise or anti-clockwise?
    --if math.abs(iCurFacingDirection - iFacingAngleWanted) > 180 then iAngleAdjFactor = 1 --Clockwise
    --else iAngleAdjFactor = -1 end --Anticlockwise


    local iCurAngleDif

    local tTempLocationToMove

    oUnit[M27UnitInfo.refbSpecialMicroActive] = true
    if oUnit.PlatoonHandle then
        oUnit.PlatoonHandle[M27UnitInfo.refbSpecialMicroActive] = true
    end
    M27Utilities.DelayChangeVariable(oUnit, M27UnitInfo.refbSpecialMicroActive, false, iTimeToRun)
    local bRecentMicro = false
    local iRecentMicroThreshold = 1
    local iGameTime = GetGameTimeSeconds()
    if oUnit[M27UnitInfo.refbSpecialMicroActive] and iGameTime - oUnit[M27UnitInfo.refiGameTimeMicroStarted] < iRecentMicroThreshold then bRecentMicro = true end

    if bRecentMicro == false then IssueClearCommands({oUnit}) end
    if bDebugMessages == true then LOG(sFunctionRef..': About to start main loop for move commands; iTimeToRun='..iTimeToRun..'; iStartTime='..iStartTime..'; iCurFacingDirection='..iCurFacingDirection..'; tUnitStartPosition='..repr(tUnitStartPosition)) end
    local iTempAngleDirectionToMove = iCurFacingDirection + iInitialAngleAdj * iAngleAdjFactor
    local iTempDistanceAwayToMove
    while (oUnit[M27UnitInfo.refiGameTimeMicroStarted] == iStartTime and GetGameTimeSeconds() - iStartTime < iTimeToRun) do
    --while not(iTempAngleDirectionToMove == iFacingAngleWanted) do
        iLoopCount = iLoopCount + 1
        if iLoopCount > iMaxLoop then M27Utilities.ErrorHandler('Loop has gone on for too long, likely infinite') break end

        --iCurAngleDif = math.abs(iTempAngleDirectionToMove - iFacingAngleWanted)
        --if iCurAngleDif < iAngleMaxSingleAdj then iTempAngleDirectionToMove = iFacingAngleWanted
        --else
            iTempAngleDirectionToMove = iTempAngleDirectionToMove + iAngleMaxSingleAdj * iAngleAdjFactor
            if iTempAngleDirectionToMove > 360 then iTempAngleDirectionToMove = iTempAngleDirectionToMove - 360 end
        --end
        iTempDistanceAwayToMove = iDistanceAwayToMove
        if iLoopCount == 1 then iTempDistanceAwayToMove = iDistanceAwayToMove + iInitialDistanceAdj end
        tTempLocationToMove = M27Utilities.MoveInDirection(tUnitStartPosition, iTempAngleDirectionToMove, iTempDistanceAwayToMove)
        IssueMove({oUnit}, tTempLocationToMove)
        WaitTicks(iTicksBetweenOrders)
    end

    --[[while (oUnit[M27UnitInfo.refiGameTimeMicroStarted] == iStartTime and GetGameTimeSeconds() - iStartTime < iTimeToRun) do
        iLoopCount = iLoopCount + 1
        if iLoopCount > iMaxLoop then M27Utilities.ErrorHandler('Loop has gone on for too long, likely infinite') break end
        iCurFacingDirection = M27UnitInfo.GetUnitFacingAngle(oUnit)
        iTempAngleDirectionToMove = iCurFacingDirection + iAngleMaxSingleAdj
        if iTempAngleDirectionToMove > 360 then iTempAngleDirectionToMove = iTempDistanceAwayToMove - 360 end

        tTempLocationToMove = M27Utilities.MoveInDirection(oUnit:GetPosition(), iTempAngleDirectionToMove, iTempDistanceAwayToMove)

        IssueMove({oUnit}, tTempLocationToMove)
        if bDebugMessages == true then LOG(sFunctionRef..': iLoopCount='..iLoopCount..'; Just issued move order to '..repr(tTempLocationToMove)..'; iCurFacingDirection='..iCurFacingDirection..'; iTempAngleDirectionToMove='..iTempAngleDirectionToMove) end

        WaitTicks(iTicksBetweenOrders)
    end --]]
end

function MoveInCircleTemporarily(oUnit, iTimeToRun)
    ForkThread(ForkedMoveInCircle, oUnit, iTimeToRun)
end


function MoveInOppositeDirectionTemporarily(oUnit, iTimeToMove)
    --OBSOLETE
    --e.g. so can dodge a bomb
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MoveInOppositeDirectionTemporarily'

    if oUnit.GetNavigator then
        local tUnitPosition = oUnit:GetPosition()
        local oNavigator = oUnit:GetNavigator()
        if oNavigator and oNavigator.GetCurrentTargetPos then
            local tUnitTarget = oNavigator:GetCurrentTargetPos()
            local iUnitSpeed = oUnit:GetBlueprint().Physics.MaxSpeed
            local iDistanceToMove = (iTimeToMove + 1) * iUnitSpeed
            --GetPositionNearTargetInSamePathingGroup(tStartPos, tTargetPos, iDistanceFromTarget, iAngleBase, oPathingUnit, iNearbyMethodIfBlocked, bTrySidePositions, bCheckAgainstExistingCommandTarget, iMinDistanceFromCurrentBuilderMoveTarget)
            --iNearbyMethodIfBlocked: default and 1: Move closer to target until are in same pathing group, checking side options as we go;
            --2: Move further away from target until are in same pathing group
            --3: Alternate between closer and further away from target until are in same pathing group

            --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
            local tNewTargetIgnoringGrouping = M27Utilities.MoveTowardsTarget(tUnitPosition, tUnitTarget, iDistanceToMove, 180)
            local tNewTargetInSameGroup = M27PlatoonUtilities.GetPositionNearTargetInSamePathingGroup(tUnitPosition, tNewTargetIgnoringGrouping, 0, 0, oUnit, 3, true, false, 0)
            if bDebugMessages == true then LOG(sFunctionRef..': Starting bomber dodge for unit='..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
            local bRecentMicro = false
            local iRecentMicroThreshold = 1
            local iGameTime = GetGameTimeSeconds()
            if oUnit[M27UnitInfo.refbSpecialMicroActive] and iGameTime - oUnit[M27UnitInfo.refiGameTimeMicroStarted] < iRecentMicroThreshold then bRecentMicro = true end
            if bRecentMicro == false then IssueClearCommands({oUnit}) end
            IssueMove({oUnit}, tNewTargetInSameGroup)
            oUnit[M27UnitInfo.refbSpecialMicroActive] = true
            oUnit[M27UnitInfo.refiGameTimeToResetMicroActive] = iGameTime + iTimeToMove
            if oUnit.PlatoonHandle then
                oUnit.PlatoonHandle[M27UnitInfo.refbSpecialMicroActive] = true
            end

            M27Utilities.DelayChangeVariable(oUnit, M27UnitInfo.refbSpecialMicroActive, false, iTimeToMove, M27UnitInfo.refiGameTimeToResetMicroActive, oUnit[M27UnitInfo.refiGameTimeToResetMicroActive])
        end
    end
end

function GetBombTarget(weapon, projectile)
    --based on CalcBallisticAcceleration
    
    --Copy of CalcBallisticAcceleration core part of calculation to determine bomb target; ignores multiple bombs
    local acc = 4.75
    if projectile and projectile.GetLauncher then
        local launcher = projectile:GetLauncher()
        if launcher then
            -- Get projectile position and velocity
            -- velocity needs to multiplied by 10 due to being returned /tick instead of /s
            local proj = {pos=projectile:GetPosition(), vel=VMult(Vector(launcher:GetVelocity()), 10)}
            local entity = launcher:GetTargetEntity()

            local target
            if entity and IsUnit(entity) then
                -- target is a entity
                target = {pos=entity:GetPosition(), vel=VMult(Vector(entity:GetVelocity()), 10)}
            else
                -- target is something else i.e. attack ground
                target = {pos=weapon:GetCurrentTargetPos(), vel=Vector(0, 0, 0)}
            end

            -- calculate flat(exclude y-axis) distance and velocity between projectile and target
            if M27Utilities.IsTableEmpty(target) == false and M27Utilities.IsTableEmpty(proj.pos) == false and target.pos and target.vel and proj.pos and target.pos then
                local dist = {pos=XZDist(proj.pos, target.pos), vel=XZDist(proj.vel, target.vel)}

                -- how many seconds until the bomb hits the target in xz-space
                local time = dist.pos / dist.vel
                if time == 0 then return acc end

                -- find out where the target will be at that point in time (it could be moving)
                target.tpos = {target.pos[1] + time * target.vel[1], 0, target.pos[3] + time * target.vel[3]}
                -- what is the height at that future position
                target.tpos[2] = GetSurfaceHeight(target.tpos[1], target.tpos[3])
                return target.tpos
            end
        end
    end
    return nil
end

function DodgeBomb(oBomber, oWeapon, projectile)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DodgeBombsFiredByUnit'
    local tBombTarget = GetBombTarget(oWeapon, projectile)
    if tBombTarget then
        local iBombSize = 2.5
        if EntityCategoryContains(categories.TECH2, oBomber:GetUnitId()) then iBombSize = 3 end --Some t2 bombers do damage in a spread (cybran, uef)
        if oWeapon.GetBlueprint then iBombSize = math.max(iBombSize, (oWeapon:GetBlueprint().DamageRadius or iBombSize)) end
        local iTimeToRun = math.min(7, iBombSize + 1)
        local iRadiusSize = iBombSize + 1

        local iBomberArmyIndex = oBomber:GetAIBrain():GetArmyIndex()

        if bDebugMessages == true then
            LOG(sFunctionRef..': tBombTarget='..repr(tBombTarget))
            M27Utilities.DrawLocation(tBombTarget, nil, 3, 20)
        end --black ring around target

        local tAllUnitsInArea = GetUnitsInRect(Rect(tBombTarget[1]-iRadiusSize, tBombTarget[3]-iRadiusSize, tBombTarget[1]+iRadiusSize, tBombTarget[3]+iRadiusSize))
        if M27Utilities.IsTableEmpty(tAllUnitsInArea) == false then
            local tMobileLandInArea = EntityCategoryFilterDown(M27UnitInfo.refCategoryMobileLand - M27UnitInfo.refCategoryMobileLandShield, tAllUnitsInArea)
            if M27Utilities.IsTableEmpty(tMobileLandInArea) == false then
                local oCurBrain
                for iUnit, oUnit in tMobileLandInArea do
                    if not(oUnit.Dead) and oUnit.GetUnitId and oUnit.GetPosition and oUnit.GetAIBrain then
                        oCurBrain = oUnit:GetAIBrain()
                        if oCurBrain.M27AI and IsEnemy(oCurBrain:GetArmyIndex(), iBomberArmyIndex) then
                            --ACU specific
                            if M27Utilities.IsACU(oUnit) then
                                local aiBrain = oCurBrain
                                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and aiBrain[M27Overseer.refbIncludeACUInAllOutAttack] and oUnit:GetHealthPercent() > 0.3 and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), aiBrain[M27Overseer.reftLastNearestACU]) > (M27Logic.GetUnitMaxGroundRange({oUnit}) - 8) and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), aiBrain[M27Overseer.reftLastNearestACU]) < 32 then
                                    --Dont dodge in case we can no longer attack ACU
                                else
                                    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and aiBrain[M27Overseer.refbIncludeACUInAllOutAttack] then iTimeToRun = math.max(iTimeToRun, 2) end
                                    if oUnit[M27UnitInfo.refbSpecialMicroActive] then
                                        MoveInCircleTemporarily(oUnit, iTimeToRun)
                                    else
                                        MoveAwayFromTargetTemporarily(oUnit, iTimeToRun, tBombTarget)
                                        oUnit[M27UnitInfo.refiGameTimeMicroStarted] = GetGameTimeSeconds()
                                    end
                                end
                            else
                                --if iBombSize <=5 or iBombSize >= 5.75 or not(M27Utilities.IsACU(oUnit)) then --If <=5 then should be able to dodge; if >5.5 then no poitn trying extra micro as wont be able to dodge (but there's a chance units may move out of the aoe so we still try the normal go in opposite direction)
                                    if bDebugMessages == true then LOG(sFunctionRef..': about to call moveawayfromtargettemporarily') end
                                    MoveAwayFromTargetTemporarily(oUnit, iTimeToRun, tBombTarget)
                                    oUnit[M27UnitInfo.refiGameTimeMicroStarted] = GetGameTimeSeconds()
                                --else --NOTE: Although manually moving in half circle dodges strats, for AI it's not possible due to issueclearcommands stopping the unit for about half a second
                                    --if bDebugMessages == true then LOG(sFunctionRef..': about to call moveainhalfcircletemporarily') end
                                    --MoveInHalfCircleTemporarily(oUnit, iTimeToRun, tBombTarget)
                                    --MoveInCircleTemporarily(oUnit, iTimeToRun)
                                --end
                            end
                        end
                    end
                end
            end
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': tBombTarget is nil') end
    end
end

function DodgeBombsFiredByUnit(oWeapon, oBomber)
    --NOTE: BELOW IS SUPERCEDED
    --Should have already checked we have a bomber before calling this
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DodgeBombsFiredByUnit'
    local tBombTarget = oWeapon:GetCurrentTargetPos()
    local iRadiusSize = 1.5
    local iBombSize = 2.5
    if EntityCategoryContains(categories.TECH2, oBomber:GetUnitId()) then iBombSize = 3 end --Some t2 bombers do damage in a spread (cybran, uef)
    if oWeapon.GetBlueprint then iBombSize = math.min(iBombSize, (oWeapon:GetBlueprint().DamageRadius or iBombSize)) end
    local iTimeToRun = math.min(7, iBombSize + 1)
    if EntityCategoryContains(categories.TECH3, oBomber:GetUnitId()) then
        iRadiusSize = 2.5
        iTimeToRun = 5
    elseif EntityCategoryContains(categories.TECH2, oBomber:GetUnitId()) then
        iTimeToRun = 4
    end



    local iBomberArmyIndex = oBomber:GetAIBrain():GetArmyIndex()

    if bDebugMessages == true then
        LOG(sFunctionRef..': tBombTarget='..repr(tBombTarget))
        M27Utilities.DrawLocation(tBombTarget, nil, 3, 20)
    end --black ring around target

    local tAllUnitsInArea = GetUnitsInRect(Rect(tBombTarget[1]-iRadiusSize, tBombTarget[3]-iRadiusSize, tBombTarget[1]+iRadiusSize, tBombTarget[3]+iRadiusSize))
    if M27Utilities.IsTableEmpty(tAllUnitsInArea) == false then
        local tMobileLandInArea = EntityCategoryFilterDown(M27UnitInfo.refCategoryMobileLand - M27UnitInfo.refCategoryMobileLandShield, tAllUnitsInArea)
        if M27Utilities.IsTableEmpty(tMobileLandInArea) == false then
            local oCurBrain
            for iUnit, oUnit in tMobileLandInArea do
                if not(oUnit.Dead) and oUnit.GetUnitId and oUnit.GetPosition and oUnit.GetAIBrain then
                    oCurBrain = oUnit:GetAIBrain()
                    if oCurBrain.M27AI and IsEnemy(oCurBrain:GetArmyIndex(), iBomberArmyIndex) then
                        if iBombSize <=5 or iBombSize >= 5.75 then --If <=5 then should be able to dodge; if >5.5 then no poitn trying extra micro as wont be able to dodge (but there's a chance units may move out of the aoe so we still try the normal go in opposite direction)
                            MoveInOppositeDirectionTemporarily(oUnit, iTimeToRun)
                        else
                            if M27Utilities.IsACU(oUnit) then
                                MoveInCircleTemporarily(oUnit, iTimeToRun)
                            else
                                MoveInOppositeDirectionTemporarily(oUnit, iTimeToRun)
                            end
                        end
                    end
                end
            end
        end


    end
end

function GetOverchargeExtraAction(aiBrain, oPlatoon, oUnitWithOvercharge)
    --should have already confirmed overcharge action is available using CanUnitUseOvercharge
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetOverchargeExtraAction'

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    --Do we have positive energy income? If not, then only overcharge if ACU is low on health as an emergency
    local bResourcesToOvercharge = false
    local oOverchargeTarget
    local iMinT1ForOvercharge = 3
    local bAreRunning = false
    local oEnemyACU

    --Check unit not already been given an overcharge action recently
    if not(oUnitWithOvercharge[M27UnitInfo.refbOverchargeOrderGiven]) then
        if M27Conditions.HaveExcessEnergy(aiBrain, 10) then bResourcesToOvercharge = true
        else
            if oPlatoon[M27PlatoonUtilities.refbACUInPlatoon] == true and M27Utilities.GetACU(aiBrain):GetHealthPercent() < 0.4 then bResourcesToOvercharge = true end
        end
        if bResourcesToOvercharge == true then
            local tUnitPosition = oUnitWithOvercharge:GetPosition()
            local iACURange = M27Logic.GetACUMaxDFRange(oUnitWithOvercharge)
            local iOverchargeArea = 2.5
            local bShotIsBlocked
            local iInitialT2PDSearchRange = 50
            local bAbort = false
            if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill then
                iInitialT2PDSearchRange = iACURange
                local iDistanceToEnemyACU
                --Target enemy ACU if its low health as a top priority unless it's about to move out of our range
                if M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoLastNearestACU]) and M27Utilities.CanSeeUnit(aiBrain, aiBrain[M27Overseer.refoLastNearestACU], true) then
                    oEnemyACU = aiBrain[M27Overseer.refoLastNearestACU]
                    if aiBrain[M27Overseer.refoLastNearestACU]:GetHealthPercent() < 0.2 then
                        iDistanceToEnemyACU = M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.reftLastNearestACU], tUnitPosition)
                        if iDistanceToEnemyACU + 2 < iACURange then
                            oOverchargeTarget = aiBrain[M27Overseer.refoLastNearestACU]
                        else
                            bAbort = true
                        end
                    end
                end
                if bAbort == false then
                    if iDistanceToEnemyACU == nil then iDistanceToEnemyACU = M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.reftLastNearestACU], tUnitPosition) end
                    --Is ACU about to fall out of our vision or weapon range?
                    if iDistanceToEnemyACU + 4 > math.min(iACURange, 26) then bAbort = true end
                end
            end
            if bAbort == false then

                --Is there any enemy point defence nearby? If so then overcharge it (unless are running away in which case just target mobile units)
                if oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionRun or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionTemporaryRetreat or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionReturnToBase then bAreRunning = true end
                if bAreRunning == false then
                    if oOverchargeTarget == nil then
                        local tEnemyPointDefence = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * categories.DIRECTFIRE, tUnitPosition, iACURange, 'Enemy')
                        if bDebugMessages == true then LOG(sFunctionRef..': have resources to overcharge, considering nearby enemies') end
                        if M27Utilities.IsTableEmpty(tEnemyPointDefence) == false then
                            if bDebugMessages == true then LOG(sFunctionRef..': Have enemy point defence in range - considering if shot is blocked') end
                            for iUnit, oEnemyPD in tEnemyPointDefence do
                                if M27Logic.IsShotBlocked(oUnitWithOvercharge, oEnemyPD) == false then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Setting target to in range PD') end
                                    oOverchargeTarget = oEnemyPD
                                    break
                                end
                            end
                        end
                    end
                    if oOverchargeTarget == nil then
                        --Check further away incase enemy has T2 PD
                        if bDebugMessages == true then LOG(sFunctionRef..': Checking if any T2 PD further away') end
                        tEnemyPointDefence = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH2 + categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH3, tUnitPosition, iInitialT2PDSearchRange, 'Enemy')
                        if M27Utilities.IsTableEmpty(tEnemyPointDefence) == false then
                            if bDebugMessages == true then LOG(sFunctionRef..': Have enemy T2 defence that can hit us but is out of our range - considering if shot is blocked') end
                            for iUnit, oEnemyT2PD in tEnemyPointDefence do
                                if M27Logic.IsShotBlocked(oUnitWithOvercharge, oEnemyT2PD) == false then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Setting target to T2 PD') end
                                    oOverchargeTarget = oEnemyT2PD
                                    break
                                end
                            end
                        end
                    end
                end
                if oOverchargeTarget == nil then
                    local tEnemyT2Plus = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.TECH2 + categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.TECH3 + categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.EXPERIMENTAL - categories.SUBCOMMANDER + M27UnitInfo.refCategoryAllNavy, tUnitPosition, iACURange, 'Enemy')
                    if M27Utilities.IsTableEmpty(tEnemyT2Plus) == false then
                        for iUnit, oEnemyT2Unit in tEnemyT2Plus do
                            if bDebugMessages == true then LOG(sFunctionRef..': Have enemy T2+ mobile land to consider') end
                            if M27Logic.IsShotBlocked(oUnitWithOvercharge, oEnemyT2Unit) == false then
                                if bDebugMessages == true then LOG(sFunctionRef..': Setting target to t2+ unit') end
                                oOverchargeTarget = oEnemyT2Unit
                                break
                            end
                        end
                    end
                    if oOverchargeTarget == nil then
                        local tEnemyT1 = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE * categories.TECH1 * categories.DIRECTFIRE + categories.LAND * categories.MOBILE * categories.TECH1 * categories.INDIRECTFIRE, tUnitPosition, iACURange, 'Enemy')
                        local tNearbyEnemiesToTarget
                        local iMaxUnitsInArea = 0
                        local iCurUnitsInArea
                        for iUnit, oEnemyT1Unit in tEnemyT1 do
                            if bDebugMessages == true then LOG(sFunctionRef..': Have T1 units to consider, checking how many units are near them for AOE') end
                            tNearbyEnemiesToTarget = aiBrain:GetUnitsAroundPoint(categories.ALLUNITS, oEnemyT1Unit:GetPosition(), iOverchargeArea, 'Enemy')
                            if M27Utilities.IsTableEmpty(tNearbyEnemiesToTarget) == false then
                                iCurUnitsInArea = table.getn(tNearbyEnemiesToTarget)if bDebugMessages == true then LOG(sFunctionRef..': Have T1 units with iCurUnitsInArea='..iCurUnitsInArea..' within area effect') end
                                if iCurUnitsInArea >= iMinT1ForOvercharge then
                                    --bShotIsBlocked = M27Logic.IsShotBlocked(oUnitWithOvercharge, oEnemyT1Unit)
                                    bShotIsBlocked = M27Logic.IsShotBlocked(oUnitWithOvercharge, oEnemyT1Unit)
                                    if bShotIsBlocked == false then
                                        if iCurUnitsInArea > iMaxUnitsInArea then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Setting target to t1 unit') end
                                            iMaxUnitsInArea = iCurUnitsInArea
                                            oOverchargeTarget = oEnemyT1Unit
                                            if oOverchargeTarget == nil and bDebugMessages == true then LOG(sFunctionRef..': Overcharge target is nil1') end
                                        end
                                        if oOverchargeTarget == nil and bDebugMessages == true then LOG(sFunctionRef..': Overcharge target is nil2') end
                                    end
                                    if oOverchargeTarget == nil and bDebugMessages == true then LOG(sFunctionRef..': Overcharge target is nil3') end
                                end
                                if oOverchargeTarget == nil and bDebugMessages == true then LOG(sFunctionRef..': Overcharge target is nil4') end
                            end
                            if oOverchargeTarget == nil and bDebugMessages == true then LOG(sFunctionRef..': Overcharge target is nil5') end
                        end
                        if oOverchargeTarget == nil and bDebugMessages == true then LOG(sFunctionRef..': Overcharge target is nil6') end
                        if oOverchargeTarget == nil then
                            --Consider enemy ACU if its in range and low on health
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering enemy ACU and if its low on health') end
                            local tEnemyACU = aiBrain:GetUnitsAroundPoint(categories.COMMAND, tUnitPosition, iACURange, 'Enemy')
                            if M27Utilities.IsTableEmpty(tEnemyACU) == false then
                                for iUnit, oEnemyACUUnit in tEnemyACU do
                                    if oEnemyACUUnit:GetHealthPercent() <= 0.1 then
                                        if M27Logic.IsShotBlocked(oUnitWithOvercharge, oEnemyACUUnit) == false then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Setting target to enemy ACU') end
                                            oOverchargeTarget = oEnemyACUUnit
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if oOverchargeTarget == nil then
                --Target enemy ACU anyway if we have max energy and in attack mode
                if oEnemyACU and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and aiBrain:GetEconomyStoredRatio('ENERGY') >= 1 then
                    oOverchargeTarget = oEnemyACU
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': oOverchargeTarget is nil, wont give overcharge action') end
                end
            end
            if oOverchargeTarget then
                if bDebugMessages == true then LOG(sFunctionRef..': Telling platoon to process overcharge action') end
                oPlatoon[M27PlatoonUtilities.refiExtraAction] = M27PlatoonUtilities.refExtraActionOvercharge
                oPlatoon[M27PlatoonUtilities.refExtraActionTargetUnit] = oOverchargeTarget
            end
        end
    end
end
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local XZDist = import('/lua/utilities.lua').XZDistanceTwoVectors
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27EconomyOverseer = import('/mods/M27AI/lua/AI/M27EconomyOverseer.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27Team = import('/mods/M27AI/lua/AI/M27Team.lua')

function MoveAwayFromTargetTemporarily(oUnit, iTimeToRun, tPositionToRunFrom)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MoveAwayFromTargetTemporarily'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local bMoveInStages = false --set to true later if hardly have any time to run, but in reality this functionality isn't expected to be used in most cases, left in since took a while to get it to work to a basic level, but turns out it's probably better to just move in a straight line rather than trying multiple move orders


    local tUnitPosition = oUnit:GetPosition()
    local oBP = oUnit:GetBlueprint()
    local iUnitSpeed = oBP.Physics.MaxSpeed
    local iDistanceToMove = (iTimeToRun + 1) * iUnitSpeed
    --local tRevisedPositionToRunFrom

    local iCurFacingDirection = M27UnitInfo.GetUnitFacingAngle(oUnit)
    local iAngleFromUnitToBomb
    if tUnitPosition[1] == tPositionToRunFrom[1] and tUnitPosition[3] == tPositionToRunFrom[3] then
        iAngleFromUnitToBomb = iCurFacingDirection - 180
        if iAngleFromUnitToBomb < 0 then iAngleFromUnitToBomb = iAngleFromUnitToBomb + 360 end
    else
        iAngleFromUnitToBomb = M27Utilities.GetAngleFromAToB(oUnit:GetPosition(), tPositionToRunFrom)
    end

    local iAngleAdjFactor
    local iFacingAngleWanted = iAngleFromUnitToBomb + 180
    if iFacingAngleWanted >= 360 then iFacingAngleWanted = iFacingAngleWanted - 360 end

    local iTurnRate = (oBP.Physics.TurnRate or 90)
    local iTimeToTurn = math.abs(iFacingAngleWanted - iCurFacingDirection) / iTurnRate
    local iDistToBomb = M27Utilities.GetDistanceBetweenPositions(tPositionToRunFrom, oUnit:GetPosition())
    if iDistToBomb * 2 / iUnitSpeed <= iTimeToTurn then
        iFacingAngleWanted = iCurFacingDirection
        iDistanceToMove = iDistanceToMove + iDistToBomb
    end
    if iTimeToTurn > iTimeToRun then bMoveInStages = true end

    if bDebugMessages == true then LOG(sFunctionRef..': Unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..': iTurnRate='..iTurnRate..'; iTimeToTurn='..iTimeToTurn..'; iDistToBomb='..iDistToBomb..'; iFacingAngleWanted='..iFacingAngleWanted..'; iDistanceToMove='..iDistanceToMove) end

    --[[if math.abs(tUnitPosition[1] - tPositionToRunFrom[1]) <= 0.2 and math.abs(tUnitPosition[3] - tPositionToRunFrom[3]) <= 0.2 then
        --local aiBrain = oUnit:GetAIBrain()
        --tRevisedPositionToRunFrom = M27Utilities.MoveTowardsTarget(tUnitPosition, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), 1, 0)
        --if bDebugMessages == true then LOG(sFunctionRef..': Unit position was the same as position to run from, so will run from enemy ase instead, tRevisedPositionToRunFrom='..repru(tRevisedPositionToRunFrom)) end

        tRevisedPositionToRunFrom = M27Utilities.MoveInDirection(tUnitPosition, iAngleFromUnitToBomb, 0.1, false)
        if bDebugMessages == true then LOG(sFunctionRef..': Unit position was almost the same as position to run from, so will run in the direction we are facing') end

    else
        if bDebugMessages == true then LOG(sFunctionRef..': Will try to run from '..repru(tPositionToRunFrom)) end
        tRevisedPositionToRunFrom = tPositionToRunFrom
    end--]]






    local iCurAngleDif

    local tTempLocationToMove

    TrackTemporaryUnitMicro(oUnit, iTimeToRun)

    --[[oUnit[M27UnitInfo.refbSpecialMicroActive] = true
    if oUnit.PlatoonHandle then
        oUnit.PlatoonHandle[M27UnitInfo.refbSpecialMicroActive] = true
    end
    M27Utilities.DelayChangeVariable(oUnit, M27UnitInfo.refbSpecialMicroActive, false, iTimeToRun)--]]

    if bDebugMessages == true then LOG(sFunctionRef..': About to start main loop for move commands for unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iTimeToRun='..iTimeToRun..'; iCurFacingDirection='..iCurFacingDirection..'; iAngleFromUnitToBomb='..iAngleFromUnitToBomb..'; iFacingAngleWanted='..iFacingAngleWanted..'; tUnitStartPosition='..repru(oUnit:GetPosition())..'; tPositionToRunFrom='..repru(tPositionToRunFrom)) end
    M27Utilities.IssueTrackedClearCommands({oUnit})
    tTempLocationToMove = oUnit:GetPosition()
    local iDistanceAlreadyMoved = 0


    --Turn around while moving away if we're not facing the right direction:
    if bMoveInStages then
        local iInitialAngleAdj = 30
        local iAngleMaxSingleAdj = 45
        local iTempDistanceAwayToMove = 3
        local iDistanceIncreasePerCycle = 1.5
        local iDistanceIncreaseCompoundFactor = 1.5
        local iLoopCount = 0

        if math.abs(iCurFacingDirection - iFacingAngleWanted) > (iAngleMaxSingleAdj + iInitialAngleAdj) then
            local iTempAngleDirectionToMove = iCurFacingDirection

            if iCurFacingDirection - iFacingAngleWanted > 0 then
                if iCurFacingDirection - iFacingAngleWanted > 180 then iAngleAdjFactor = 1 --Clockwise
                else iAngleAdjFactor = -1 --AntiClockwise
                end

            elseif iCurFacingDirection - iFacingAngleWanted < -180 then iAngleAdjFactor = -1
            else iAngleAdjFactor = 1
            end --Clockwise



            while iLoopCount < 6 do
                iLoopCount = iLoopCount + 1

                iTempAngleDirectionToMove = iCurFacingDirection + (iInitialAngleAdj + iLoopCount * iAngleMaxSingleAdj) * iAngleAdjFactor
                if iTempAngleDirectionToMove > 360 then iTempAngleDirectionToMove = iTempAngleDirectionToMove - 360
                elseif iTempAngleDirectionToMove < 0 then iTempAngleDirectionToMove = iTempAngleDirectionToMove + 360
                end

                if bDebugMessages == true then LOG(sFunctionRef..': iLoopCount='..iLoopCount..'; iTempAngleDirectionToMove='..iTempAngleDirectionToMove..'; iInitialAngleAdj='..iInitialAngleAdj..'; iAngleAdjFactor='..iAngleAdjFactor..'; iCurFacingDirection='..iCurFacingDirection..'; iFacingAngleWanted='..iFacingAngleWanted) end


                iTempDistanceAwayToMove = iTempDistanceAwayToMove + iDistanceIncreasePerCycle * iDistanceIncreasePerCycle * (iDistanceIncreaseCompoundFactor ^ iLoopCount - 1)
                tTempLocationToMove = M27Utilities.MoveInDirection(oUnit:GetPosition(), iTempAngleDirectionToMove, iTempDistanceAwayToMove)
                IssueMove({oUnit}, tTempLocationToMove)
                if bDebugMessages == true then LOG(sFunctionRef..': Just issued move order to tTempLocationToMove='..repru(tTempLocationToMove)..'; iTempAngleDirectionToMove='..iTempAngleDirectionToMove) end
                if math.abs(iTempAngleDirectionToMove - iFacingAngleWanted) <= iAngleMaxSingleAdj then break
                elseif math.abs(iTempAngleDirectionToMove - iFacingAngleWanted) > 360 then
                    M27Utilities.ErrorHandler('Something has gone wrong with dodge micro, will stop trying to turn around')
                    break
                end
            end
            iDistanceAlreadyMoved = M27Utilities.GetDistanceBetweenPositions(tTempLocationToMove, tPositionToRunFrom)
        end
    end

    --Should now be facing close to the right direction, so move further in this direction


    local tNewTargetIgnoringGrouping = M27Utilities.MoveInDirection(oUnit:GetPosition(), iFacingAngleWanted, math.max(1, iDistanceToMove - iDistanceAlreadyMoved))
    if bDebugMessages == true then LOG(sFunctionRef..': Finished trying to face the right direction, tNewTargetIgnoringGrouping='..repru(tNewTargetIgnoringGrouping)..'; tUnitPosition='..repru(tUnitPosition)..'; iDistanceToMove='..iDistanceToMove..'; iDistanceAlreadyMoved='..iDistanceAlreadyMoved) end
    --local tNewTargetInSameGroup = M27PlatoonUtilities.GetPositionNearTargetInSamePathingGroup(tUnitPosition, tNewTargetIgnoringGrouping, 0, 0, oUnit, 3, true, false, 0)
    local tNewTargetInSameGroup = M27PlatoonUtilities.GetPositionAtOrNearTargetInPathingGroup(tUnitPosition, tNewTargetIgnoringGrouping, 0, 0, oUnit, true, false)
    if tNewTargetInSameGroup then
        if bDebugMessages == true then LOG(sFunctionRef..': Starting bomber dodge for unit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; tNewTargetInSameGroup='..repru(tNewTargetInSameGroup)) end
        --M27Utilities.IssueTrackedClearCommands({oUnit})
        IssueMove({oUnit}, tNewTargetInSameGroup)

        TrackTemporaryUnitMicro(oUnit, iTimeToRun)

        --[[oUnit[M27UnitInfo.refbSpecialMicroActive] = true
        if oUnit.PlatoonHandle then
            oUnit.PlatoonHandle[M27UnitInfo.refbSpecialMicroActive] = true
        end
        M27Utilities.DelayChangeVariable(oUnit, M27UnitInfo.refbSpecialMicroActive, false, iTimeToRun)--]]
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ForkedMoveInHalfCircle(oUnit, iTimeToRun, tPositionToRunFrom)
    --More intensive version of MoveAwayFromTargetTemporarily, intended e.g. for ACUs
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ForkedMoveInHalfCircle'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

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

    TrackTemporaryUnitMicro(oUnit, iTimeToRun)

    --[[oUnit[M27UnitInfo.refbSpecialMicroActive] = true
    if oUnit.PlatoonHandle then
        oUnit.PlatoonHandle[M27UnitInfo.refbSpecialMicroActive] = true
    end
    M27Utilities.DelayChangeVariable(oUnit, M27UnitInfo.refbSpecialMicroActive, false, iTimeToRun)--]]

    if bDebugMessages == true then LOG(sFunctionRef..': About to start main loop for move commands; iTimeToRun='..iTimeToRun..'; iStartTime='..iStartTime..'; iCurFacingDirection='..iCurFacingDirection..'; iAngleToTargetToEscape='..iAngleToTargetToEscape..'; iFacingAngleWanted='..iFacingAngleWanted..'; tUnitStartPosition='..repru(tUnitStartPosition)) end
    M27Utilities.IssueTrackedClearCommands({oUnit})
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
        if bDebugMessages == true then LOG(sFunctionRef..': tTempLocationToMove='..repru(tTempLocationToMove)..'; iTempAngleDirectionToMove='..iTempAngleDirectionToMove) end
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
        if bDebugMessages == true then LOG(sFunctionRef..': iLoopCount='..iLoopCount..'; Just issued move order to '..repru(tTempLocationToMove)..'; iCurFacingDirection='..iCurFacingDirection..'; iTempAngleDirectionToMove='..iTempAngleDirectionToMove) end

        WaitTicks(iTicksBetweenOrders)
    end--]]
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function MoveInHalfCircleTemporarily(oUnit, iTimeToRun, tPositionToRunFrom)
    ForkThread(ForkedMoveInHalfCircle, oUnit, iTimeToRun, tPositionToRunFrom)
end

function ForkedMoveInCircle(oUnit, iTimeToRun, bDontTreatAsMicroAction, bDontClearCommandsFirst, iCircleSizeOverride, iTickWaitOverride)
    --More intensive version of MoveAwayFromTargetTemporarily, intended e.g. for ACUs
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ForkedMoveInCircle'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local refbActiveCircleMicro = 'M27MicroActiveCircleMicro'

    if bDebugMessages == true then LOG(sFunctionRef..': GameTime='..GetGameTimeSeconds()..'; Unit has active circle micro='..tostring(oUnit[refbActiveCircleMicro] or false)) end
    if not(oUnit[refbActiveCircleMicro]) then

        --KEY CONFIG SETTINGS: (these will work sometimes but not always against an aeon strat)
        local iInitialAngleAdj = 15
        local iInitialDistanceAdj = -1
        local iDistanceAwayToMove = (iCircleSizeOverride or 2)
        local iAngleMaxSingleAdj = 45
        local iTicksBetweenOrders = (iTickWaitOverride or 4)

        if iDistanceAwayToMove > oUnit:GetBlueprint().Physics.MaxSpeed * 1.5 then
            iAngleMaxSingleAdj = math.max(25, iAngleMaxSingleAdj * 2.5 / iDistanceAwayToMove)
        end



        local iStartTime = GetGameTimeSeconds()
        oUnit[M27UnitInfo.refiGameTimeMicroStarted] = iStartTime
        local iLoopCount = 0
        local iMaxLoop = iTimeToRun * 10 + 1
        --Distance from point A to point B will be much less than distanceaway to move, since that is the distance from the centre (radius) rather than the distance between 1 points on the circle edge; for simplicity will assume that distance is 0.25 of the distance from the centre
        if bDontTreatAsMicroAction then iMaxLoop = math.ceil(iTimeToRun / (iDistanceAwayToMove / oUnit:GetBlueprint().Physics.MaxSpeed)) * 4 end
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

        local bRecentMicro = false
        local iRecentMicroThreshold = 1
        local iGameTime = GetGameTimeSeconds()
        if oUnit[M27UnitInfo.refbSpecialMicroActive] and iGameTime - oUnit[M27UnitInfo.refiGameTimeMicroStarted] < iRecentMicroThreshold then bRecentMicro = true end
        if bDebugMessages == true then LOG(sFunctionRef..': About to start main loop for move commands for unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iTimeToRun='..iTimeToRun..'; iStartTime='..iStartTime..'; iCurFacingDirection='..iCurFacingDirection..'; tUnitStartPosition='..repru(tUnitStartPosition)..'; bRecentMicro='..tostring((bRecentMicro or false))..'; bDontClearCommandsFirst='..tostring(bDontClearCommandsFirst or false)..'; oUnit[M27UnitInfo.refbSpecialMicroActive]='..tostring(oUnit[M27UnitInfo.refbSpecialMicroActive])..'; oUnit[M27UnitInfo.refiGameTimeMicroStarted]='..(oUnit[M27UnitInfo.refiGameTimeMicroStarted] or 'nil')..'; GameTime='..iGameTime..'; Dif='..iGameTime-(oUnit[M27UnitInfo.refiGameTimeMicroStarted] or 0)..'; bDontTreatAsMicroAction='..tostring((bDontTreatAsMicroAction or false))) end
        if bRecentMicro == false and not(bDontClearCommandsFirst) then
            M27Utilities.IssueTrackedClearCommands({oUnit})
            if bDebugMessages == true then LOG(sFunctionRef..': Issued clear commands order to the unit') end
        end
        if not(bDontTreatAsMicroAction) then
            TrackTemporaryUnitMicro(oUnit, iTimeToRun, refbActiveCircleMicro)
            if bDebugMessages == true then LOG(sFunctionRef..': Will temporarily track the unit micro. iTimeToRun='..(iTimeToRun or 'nil')) end
            --[[oUnit[M27UnitInfo.refbSpecialMicroActive] = true
            if oUnit.PlatoonHandle then
                oUnit.PlatoonHandle[M27UnitInfo.refbSpecialMicroActive] = true
            end
            M27Utilities.DelayChangeVariable(oUnit, M27UnitInfo.refbSpecialMicroActive, false, iTimeToRun)--]]
        end

        local iTempAngleDirectionToMove = iCurFacingDirection + iInitialAngleAdj * iAngleAdjFactor
        local iTempDistanceAwayToMove
        local bTimeToStop = false
        if bDebugMessages == true then LOG(sFunctionRef..': oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; refbSpecialMicroActive='..tostring((oUnit[M27UnitInfo.refbSpecialMicroActive] or false))..'; iMaxLoop='..iMaxLoop) end
        while bTimeToStop == false do
            --while not(iTempAngleDirectionToMove == iFacingAngleWanted) do
            iLoopCount = iLoopCount + 1
            if iLoopCount > iMaxLoop then break
            elseif M27UnitInfo.IsUnitValid(oUnit) == false then break end --No longer give error message as may be calling this for intel scouts now
            --M27Utilities.ErrorHandler('Loop has gone on for too long, likely infinite') break end

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
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitTicks(iTicksBetweenOrders)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            if not(bDontTreatAsMicroAction) and not((oUnit[M27UnitInfo.refiGameTimeMicroStarted] == iStartTime and GetGameTimeSeconds() - iStartTime < iTimeToRun)) then bTimeToStop = true end
        end
    end


    --[[while (oUnit[M27UnitInfo.refiGameTimeMicroStarted] == iStartTime and GetGameTimeSeconds() - iStartTime < iTimeToRun) do
        iLoopCount = iLoopCount + 1
        if iLoopCount > iMaxLoop then M27Utilities.ErrorHandler('Loop has gone on for too long, likely infinite') break end
        iCurFacingDirection = M27UnitInfo.GetUnitFacingAngle(oUnit)
        iTempAngleDirectionToMove = iCurFacingDirection + iAngleMaxSingleAdj
        if iTempAngleDirectionToMove > 360 then iTempAngleDirectionToMove = iTempDistanceAwayToMove - 360 end

        tTempLocationToMove = M27Utilities.MoveInDirection(oUnit:GetPosition(), iTempAngleDirectionToMove, iTempDistanceAwayToMove)

        IssueMove({oUnit}, tTempLocationToMove)
        if bDebugMessages == true then LOG(sFunctionRef..': iLoopCount='..iLoopCount..'; Just issued move order to '..repru(tTempLocationToMove)..'; iCurFacingDirection='..iCurFacingDirection..'; iTempAngleDirectionToMove='..iTempAngleDirectionToMove) end

        WaitTicks(iTicksBetweenOrders)
    end --]]
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function MoveInCircleTemporarily(oUnit, iTimeToRun, bDontTreatAsMicroAction, bDontClearCommandsFirst, iCircleSizeOverride, iTickWaitOverride)
    ForkThread(ForkedMoveInCircle, oUnit, iTimeToRun, bDontTreatAsMicroAction, bDontClearCommandsFirst, iCircleSizeOverride, iTickWaitOverride)
end


function MoveInOppositeDirectionTemporarily(oUnit, iTimeToMove)
    --OBSOLETE
    --e.g. so can dodge a bomb
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MoveInOppositeDirectionTemporarily'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

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
            --local tNewTargetInSameGroup = M27PlatoonUtilities.GetPositionNearTargetInSamePathingGroup(tUnitPosition, tNewTargetIgnoringGrouping, 0, 0, oUnit, 3, true, false, 0)
            local tNewTargetInSameGroup = M27PlatoonUtilities.GetPositionAtOrNearTargetInPathingGroup(tUnitPosition, tNewTargetIgnoringGrouping, 0, 0, oUnit, true, false)
            if bDebugMessages == true then LOG(sFunctionRef..': Starting bomber dodge for unit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
            local bRecentMicro = false
            local iRecentMicroThreshold = 1
            local iGameTime = GetGameTimeSeconds()
            if oUnit[M27UnitInfo.refbSpecialMicroActive] and iGameTime - oUnit[M27UnitInfo.refiGameTimeMicroStarted] < iRecentMicroThreshold then bRecentMicro = true end
            if bRecentMicro == false then M27Utilities.IssueTrackedClearCommands({oUnit}) end
            IssueMove({oUnit}, tNewTargetInSameGroup)

            TrackTemporaryUnitMicro(oUnit, iTimeToMove)

            --[[oUnit[M27UnitInfo.refbSpecialMicroActive] = true
            oUnit[M27UnitInfo.refiGameTimeToResetMicroActive] = iGameTime + iTimeToMove
            if oUnit.PlatoonHandle then
                oUnit.PlatoonHandle[M27UnitInfo.refbSpecialMicroActive] = true
            end

            M27Utilities.DelayChangeVariable(oUnit, M27UnitInfo.refbSpecialMicroActive, false, iTimeToMove, M27UnitInfo.refiGameTimeToResetMicroActive, oUnit[M27UnitInfo.refiGameTimeToResetMicroActive])--]]
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
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
    elseif not(projectile) and weapon.GetCurrentTarget then
        if weapon:GetCurrentTarget().GetPosition then return weapon:GetCurrentTarget():GetPosition() end
    end
    return nil
end

function TrackTemporaryUnitMicro(oUnit, iTimeActiveFor, sAdditionalTrackingVar)
    --Where we are doing all actions upfront can call this to enable micro and then turn the flag off after set period of time
    --Note that air logic currently doesnt make use of this
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'TrackTemporaryUnitMicro'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Setting special micro active flag to true for oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..', cur time='..GetGameTimeSeconds()..'; iTimeActiveFor='..iTimeActiveFor) end
    oUnit[M27UnitInfo.refbSpecialMicroActive] = true
    oUnit[M27UnitInfo.refiGameTimeMicroStarted] = GetGameTimeSeconds()
    oUnit[M27UnitInfo.refiGameTimeToResetMicroActive] = GetGameTimeSeconds() + iTimeActiveFor
    --Navy tracking - clear last unit target since are only moving to its location not attacking
    oUnit[M27UnitInfo.refoLastOrderUnitTarget] = nil

    M27Utilities.DelayChangeVariable(oUnit, M27UnitInfo.refbSpecialMicroActive, false, iTimeActiveFor - 0.01)

    if oUnit.PlatoonHandle then
        oUnit.PlatoonHandle[M27UnitInfo.refbSpecialMicroActive] = true
        M27Utilities.DelayChangeVariable(oUnit.PlatoonHandle, M27UnitInfo.refbSpecialMicroActive, false, iTimeActiveFor - 0.01)
    end

    if sAdditionalTrackingVar then
        oUnit[sAdditionalTrackingVar] = true
        M27Utilities.DelayChangeVariable(oUnit, sAdditionalTrackingVar, false, iTimeActiveFor - 0.01)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DodgeShot(oTarget, oWeapon, oAttacker, iTimeToDodge)
    --Should have already checked oTarget is a valid unit that has a chance of dodging the shot in time before claling this
    --Gets unit to move at a slightly different angle to its current facing direction for iTimeToDodge
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DodgeShot'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    local tCurDestination
    if oTarget.PlatoonHandle and M27Utilities.IsTableEmpty(oTarget.PlatoonHandle[M27PlatoonUtilities.reftLastOrderPosition]) == false then
        tCurDestination = oTarget.PlatoonHandle[M27PlatoonUtilities.reftLastOrderPosition]
        if bDebugMessages == true then LOG(sFunctionRef..': Part of platoon '..oTarget.PlatoonHandle:GetPlan()..oTarget.PlatoonHandle[M27PlatoonUtilities.refiPlatoonCount]..'; last order position='..repru(oTarget.PlatoonHandle[M27PlatoonUtilities.reftLastOrderPosition])) end
    else
        local oNavigator = oTarget:GetNavigator()
        if oNavigator and oNavigator.GetCurrentTargetPos then
            tCurDestination = oNavigator:GetCurrentTargetPos()
            if bDebugMessages == true then
                LOG(sFunctionRef..': Will get navigator current target position='..repru(oNavigator:GetCurrentTargetPos())..'; Cur pos='..repru(oTarget:GetPosition())..'; Platoon last order='..(oTarget.PlatoonHandle[M27PlatoonUtilities.refiLastOrderType] or 'nil')..'; Angle to nav target='..M27Utilities.GetAngleFromAToB(oTarget:GetPosition(), oNavigator:GetCurrentTargetPos()))
            end

        else
            if oAttacker.GetPosition then
                if bDebugMessages == true then LOG(sFunctionRef..': Attacker has position so will get this') end
                tCurDestination = oAttacker:GetPosition()
            else
                if oWeapon.GetPosition then
                    if bDebugMessages == true then LOG(sFunctionRef..': Weapon has position so will get this') end
                    tCurDestination = oWeapon:GetPosition()
                elseif oWeapon.unit and oWeapon.unit.GetPosition then
                    if bDebugMessages == true then LOG(sFunctionRef..': Weapon has unit htat has position so will get this') end
                    tCurDestination = oWeapon.unit:GetPosition()
                else
                    local aiBrain = oTarget:GetAIBrain()
                    tCurDestination = {M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][2], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]}
                    if bDebugMessages == true then LOG(sFunctionRef..': Will assume we were moving towards our start position as a redundancy') end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': tCurDestination after backup options='..repru(tCurDestination)) end
        end
    end

    local iCurFacingAngle = M27UnitInfo.GetUnitFacingAngle(oTarget)
    local iAngleToDestination = M27Utilities.GetAngleFromAToB(oTarget:GetPosition(), tCurDestination)
    local oBP = oTarget:GetBlueprint()
    local iSpeed = oBP.Physics.MaxSpeed
    local iDistanceToRun = iTimeToDodge * iSpeed
    local iUnitSize = oBP.SizeX + oBP.SizeZ
    local iAngleAdjust = math.max(15, oBP.Physics.TurnRate * 0.3)
    if iUnitSize >= 2 then
        if iUnitSize >= 4 then iAngleAdjust = iAngleAdjust * 2.5
        else iAngleAdjust = iAngleAdjust * 1.75
        end
        if EntityCategoryContains(M27UnitInfo.refCategoryLandExperimental, oTarget.UnitId) then
            iAngleAdjust = math.min(iAngleAdjust, 30)
        end
    end
    if M27Utilities.GetAngleDifference(iCurFacingAngle + iAngleAdjust, iAngleToDestination) > M27Utilities.GetAngleDifference(iCurFacingAngle - iAngleAdjust, iAngleToDestination) then
        iAngleAdjust = iAngleAdjust * -1
    end

    local tTempDestination = M27Utilities.MoveInDirection(oTarget:GetPosition(), iCurFacingAngle + iAngleAdjust, iDistanceToRun, true, false)
    local bAttackMove = false
    local iLastOrder = (oTarget[M27PlatoonUtilities.refiLastOrderType] or oTarget.PlatoonHandle[M27PlatoonUtilities.refiLastOrderType])
    if iLastOrder and (iLastOrder == M27PlatoonUtilities.refiOrderIssueAttack or iLastOrder == M27PlatoonUtilities.refiOrderIssueAggressiveMove or iLastOrder == M27PlatoonUtilities.refiOrderIssueAggressiveFormMove) then
        bAttackMove = true
    end
    if bDebugMessages == true then LOG(sFunctionRef..': oTarget (ie unit that is dodging)='..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..'; clearing current orders which have a possible destination of '..repru(tCurDestination)..'; and giving an order to move to '..repru(tTempDestination)..'; Dist from our position to temp position='..M27Utilities.GetDistanceBetweenPositions(oTarget:GetPosition(), tTempDestination)..'; iAngleAdjust='..iAngleAdjust..'; Unit size='..iUnitSize) end
    M27Utilities.IssueTrackedClearCommands({oTarget})
    TrackTemporaryUnitMicro(oTarget, iTimeToDodge)
    IssueMove({oTarget}, tTempDestination)
    --Also send an order to go to the destination that we had before
    if bAttackMove then
        IssueAggressiveMove({oTarget}, tCurDestination)
    else
        IssueMove({oTarget}, tCurDestination)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ConsiderDodgingShot(oUnit, oWeapon)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ConsiderDodgingShot'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if EntityCategoryContains(categories.TECH3, oUnit.UnitId) then bDebugMessages = true end
    if bDebugMessages == true then
        LOG(sFunctionRef..': Just fired, oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Time='..GetGameTimeSeconds())
        if oWeapon.GetCurrentTarget then
            LOG(sFunctionRef..': Is current target valid='..tostring(M27UnitInfo.IsUnitValid(oWeapon:GetCurrentTarget()))..'; Weapon category='..oWeapon.Blueprint.WeaponCategory)
            if not(M27UnitInfo.IsUnitValid(oWeapon:GetCurrentTarget())) then
                LOG(sFunctionRef..': Invalid target, will do reprs of it:'..reprs(oWeapon:GetCurrentTarget())..' will also draw black square around the weapon target position which is '..repru(oWeapon:GetCurrentTargetPos()))
                M27Utilities.DrawLocation(oWeapon:GetCurrentTargetPos(), nil, 3, 200)
            else
                LOG(sFunctionRef..': Valid target='..oWeapon:GetCurrentTarget().UnitId..M27UnitInfo.GetUnitLifetimeCount(oWeapon:GetCurrentTarget()))
            end
        else
            LOG(sFunctionRef..': Dont have a current target for this weapon')
        end
    end
    --Direct fire, t1 mobile arti, t2 mobile missile launchers, and experimental land
    if oWeapon.GetCurrentTarget and (oWeapon.Blueprint.WeaponCategory == 'Direct Fire' or oWeapon.Blueprint.WeaponCategory == 'Direct Fire Naval' or oWeapon.Blueprint.WeaponCategory == 'Direct Fire Experimental' or (oWeapon.Blueprint.WeaponCategory == 'Artillery' and EntityCategoryContains(categories.TECH1, oUnit.UnitId)) or (oWeapon.Blueprint.WeaponCategory == 'Missile' and oWeapon.Blueprint.MaxRadius <= 80)) or (oWeapon.Blueprint.WeaponCategory == 'Indirect Fire' and oWeapon.Blueprint.MuzzleVelocity <= 25) then
        if bDebugMessages == true then LOG(sFunctionRef..': Have a valid weapon category, will see if have targets to consider dodging') end
        local oWeaponTarget = oWeapon:GetCurrentTarget()
        local bConsiderUnitsInArea = false
        if not(M27UnitInfo.IsUnitValid(oWeaponTarget)) or EntityCategoryContains(categories.NAVAL * categories.MOBILE, oWeaponTarget.UnitId) then bConsiderUnitsInArea = true end

        local tUnitsToConsiderDodgeFor = {}
        function ConsiderAddingUnitToTable(oCurUnit, bIncludeBusyUnits)
            if bDebugMessages == true then LOG(sFunctionRef..': Considering if we should add oCurUnit='..oCurUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oCurUnit)..'; Brain='..oCurUnit:GetAIBrain().Nickname..'; Unit state='..M27Logic.GetUnitState(oCurUnit)..'; Special micro active='..tostring(oCurUnit[M27UnitInfo.refbSpecialMicroActive] or false)..'; oUnit[M27UnitInfo.refiGameTimeToResetMicroActive]='..(oUnit[M27UnitInfo.refiGameTimeToResetMicroActive] or 'nil')) end
            if oCurUnit:GetAIBrain().M27AI and (bIncludeBusyUnits or (not(oCurUnit:IsUnitState('Upgrading')) and not(oCurUnit[M27UnitInfo.refbSpecialMicroActive]))) then
                if EntityCategoryContains(categories.AIR + categories.STRUCTURE, oCurUnit.UnitId) then
                    --Do nothing
                elseif EntityCategoryContains(categories.MOBILE, oCurUnit.UnitId) then
                    if oCurUnit:GetFractionComplete() == 1 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Added unit to table of units to consider dodging for') end
                        table.insert(tUnitsToConsiderDodgeFor, oCurUnit)
                    end
                end
            end
        end
        local bIncludeBusyUnits = false
        if oWeapon.Blueprint.Damage >= 5000 then bIncludeBusyUnits = true end
        if not(bConsiderUnitsInArea) then
            --Is it a unit with a shield?
            if EntityCategoryContains(categories.SHIELD, oWeaponTarget.UnitId) then
                local iCurShield, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oWeaponTarget, true)
                if (iCurShield or 0) <= (iMaxShield or 0) * 0.2 then
                    ConsiderAddingUnitToTable(oWeaponTarget, bIncludeBusyUnits)
                end
            else
                ConsiderAddingUnitToTable(oWeaponTarget, bIncludeBusyUnits)
            end

        else
            --Does the weapon have an aoe?
            if (oWeapon.Blueprint.DamageRadius or 0) > 0.1 then
                --Get all units in area
                local tWeaponTarget = oWeapon:GetCurrentTargetPos()
                if M27Utilities.IsTableEmpty(tWeaponTarget) == false then
                    local iRadiusSize = math.min(3, math.max(oWeapon.Blueprint.DamageRadius, 1))
                    local tAllUnitsInArea = GetUnitsInRect(Rect(tWeaponTarget[1]-iRadiusSize, tWeaponTarget[3]-iRadiusSize, tWeaponTarget[1]+iRadiusSize, tWeaponTarget[3]+iRadiusSize))
                    if M27Utilities.IsTableEmpty(tAllUnitsInArea) == false then
                        --Do we have shield units in the area with at least 20% shield? Will assume shield covers all the units
                        local tShieldsInArea = EntityCategoryFilterDown(categories.SHIELD, tAllUnitsInArea)
                        local bUnderMobileShield = false
                        if M27Utilities.IsTableEmpty(tShieldsInArea) == false then
                            local iCurShield, iMaxShield
                            for iShield, oShield in tShieldsInArea do
                                iCurShield, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oShield, true)
                                if bDebugMessages == true then LOG(sFunctionRef..': oCurUnit='..oShield.UnitId..M27UnitInfo.GetUnitLifetimeCount(oShield)..'; iCurShield='..iCurShield..'; iMaxShield='..iMaxShield) end
                                if (iCurShield or 0) > (iMaxShield or 0) * 0.2 then
                                    bUnderMobileShield = true
                                    if bDebugMessages == true then LOG(sFunctionRef..': Unit has at least 20% shield remaining so wont dodge') end
                                    break
                                end
                            end
                        end
                        if not(bUnderMobileShield) then
                            for iNearbyUnit, oNearbyUnit in tAllUnitsInArea do
                                ConsiderAddingUnitToTable(oNearbyUnit, bIncludeBusyUnits)
                            end
                        end
                    end
                end
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Is table of units to consider dodging empty='..tostring(M27Utilities.IsTableEmpty(tUnitsToConsiderDodgeFor))..'; Weapon damage='..oWeapon.Blueprint.Damage) end
        if M27Utilities.IsTableEmpty(tUnitsToConsiderDodgeFor) == false then
            --Calculate time to impact
            local iDistToTarget = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oWeapon:GetCurrentTargetPos())
            local iMaxTimeToRun = 3
            if oWeapon.Blueprint.WeaponCategory == 'Artillery' then
                iDistToTarget = iDistToTarget + 15
                iMaxTimeToRun = 0.8
            elseif oWeapon.Blueprint.WeaponCategory == 'Missile' then
                iDistToTarget = iDistToTarget + 10
                iMaxTimeToRun = 0.8
            end
            local iShotSpeed = oWeapon.Blueprint.MuzzleVelocity
            local iTimeUntilImpact = iDistToTarget / iShotSpeed
            local bCancelDodge = false
            if bDebugMessages == true then LOG(sFunctionRef..': Dist to target='..iDistToTarget..'; Shot speed='..iShotSpeed..'; iTimeUntilImpact='..iTimeUntilImpact) end
            if iTimeUntilImpact > 0.8 then
                for iTarget, oTarget in tUnitsToConsiderDodgeFor do
                    bCancelDodge = false
                    if bDebugMessages == true then LOG(sFunctionRef..': oTarget='..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..'; Weapon damage='..oWeapon.Blueprint.Damage..'; Target health='..oTarget:GetHealth()) end
                    --Does the shot do enough damage that we want to try and doge it?
                    if oWeapon.Blueprint.Damage / oTarget:GetHealth() >= 0.01 then
                        --Do we think we can dodge the shot?
                        --If we are a large unit then only dodge if will be a while for the shot to hit
                        local oBP = oTarget:GetBlueprint()
                        local iAverageSize = (oBP.SizeX + oBP.SizeZ) * 0.5
                        if bDebugMessages == true then LOG(sFunctionRef..': iAverageSize='..iAverageSize..'; Is unit underwater='..tostring(M27UnitInfo.IsUnitUnderwater(oUnit))..'; Unit speed='..oBP.Physics.MaxSpeed) end
                        if iTimeUntilImpact > math.min(2.5, 0.4 + iAverageSize * 1.5 / oBP.Physics.MaxSpeed) and (iTimeUntilImpact >= 2 or not(EntityCategoryContains(categories.EXPERIMENTAL, oUnit.UnitId))) then
                            --Are we not underwater?
                            if not(M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                --If dealing with an ACU then drastically reduce the dodge time so we can overcharge if we havent recently and have enemies in range and enough power
                                if EntityCategoryContains(categories.COMMAND, oUnit.UnitId) and M27Conditions.CanUnitUseOvercharge(oUnit:GetAIBrain(), oUnit) and (GetGameTimeSeconds() - (oUnit[M27UnitInfo.refiTimeOfLastOverchargeShot] or 0)) > 5 and oUnit.PlatoonHandle[M27PlatoonUtilities.refiEnemiesInRange] > 0 and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27Utilities.GetNearestUnit(oUnit.PlatoonHandle[M27PlatoonUtilities.reftEnemiesInRange], oUnit:GetPosition()):GetPosition()) <= oUnit.PlatoonHandle[M27PlatoonUtilities.refiPlatoonMaxRange] then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Reducing dodge time drastically as have ACU that can overcharge enemies in range but it also wants to dodge a shot; will cancel if damage is very low that are dodging. oWeapon.Blueprint.Damage='..oWeapon.Blueprint.Damage) end
                                    if oWeapon.Blueprint.Damage <= 100 then
                                        bCancelDodge = true
                                    else
                                        iMaxTimeToRun = math.min(0.9, iMaxTimeToRun)
                                    end
                                elseif EntityCategoryContains(categories.EXPERIMENTAL, oUnit.UnitId) then
                                    --If we are a GC, Monkey or Ythotha that has an enemy experimental nearby but not in range, then cancel dodging as want to get in range to be able to  fire
                                    --local iOurRange = M27Logic.GetUnitMinGroundRange({ oUnit })
                                    --local tNearbyEnemyExperimentals = oUnit:GetAIBrain():GetUnitsAroundPoint(M27UnitInfo.refCategoryLandExperimental, oUnit:GetPosition(), 70, 'Enemy')
                                    iMaxTimeToRun = math.min(2.5, iMaxTimeToRun)
                                end

                                if not(bCancelDodge) then


                                    if bDebugMessages == true then LOG(sFunctionRef..': Will try to dodge shot. iTimeUntilImpact='..iTimeUntilImpact..'; iMaxTimeToRun='..iMaxTimeToRun) end
                                    DodgeShot(oTarget, oUnit, oWeapon, math.min(iTimeUntilImpact, iMaxTimeToRun))
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

function DodgeBomb(oBomber, oWeapon, projectile)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DodgeBombsFiredByUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tBombTarget = GetBombTarget(oWeapon, projectile)
    if tBombTarget then
        local iBombSize = 2.5
        if oWeapon.GetBlueprint then iBombSize = math.max(iBombSize, (oWeapon:GetBlueprint().DamageRadius or iBombSize)) end
        local iTimeToRun = 1.75 --T1
        if iBombSize > 2.5 then iTimeToRun = math.min(2.6, iTimeToRun + (iBombSize - 2.5) * 0.5) end
        if EntityCategoryContains(categories.TECH2, oBomber.UnitId) then
            iBombSize = 3
            iTimeToRun = 1.95
            if iBombSize > 3 then iTimeToRun = math.min(2.6, iTimeToRun + (iBombSize - 3) * 0.5) end
        elseif EntityCategoryContains(categories.TECH3, oBomber.UnitId) then
            iTimeToRun = 2.5
        end --Some t2 bombers do damage in a spread (cybran, uef)
        --local iTimeToRun = math.min(7, iBombSize + 1)
        local iRadiusSize = iBombSize + 1

        local iBomberArmyIndex = oBomber:GetAIBrain():GetArmyIndex()

        if bDebugMessages == true then
            LOG(sFunctionRef..': oBomber='..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; Bomber position='..repru(oBomber:GetPosition())..'; tBombTarget='..repru(tBombTarget)..'; Dist between position and target='..M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), tBombTarget)..'; Angle='..M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), tBombTarget)..'; Bomber facing direction='..M27UnitInfo.GetUnitFacingAngle(oBomber)..'; will draw bomb target in black')
            M27Utilities.DrawLocation(tBombTarget, nil, 3, 20)
        end --black ring around target

        local tAllUnitsInArea = GetUnitsInRect(Rect(tBombTarget[1]-iRadiusSize, tBombTarget[3]-iRadiusSize, tBombTarget[1]+iRadiusSize, tBombTarget[3]+iRadiusSize))
        if bDebugMessages == true then LOG(sFunctionRef..': Is table of units in rectangle around bomb radius empty='..tostring(M27Utilities.IsTableEmpty(tAllUnitsInArea))) end
        if M27Utilities.IsTableEmpty(tAllUnitsInArea) == false then
            local tMobileLandInArea = EntityCategoryFilterDown(M27UnitInfo.refCategoryMobileLand - categories.EXPERIMENTAL, tAllUnitsInArea)
            if bDebugMessages == true then LOG(sFunctionRef..': Is table of mobile land units in rectangle around bomb radius empty='..tostring(M27Utilities.IsTableEmpty(tMobileLandInArea))) end
            if M27Utilities.IsTableEmpty(tMobileLandInArea) == false then
                local oCurBrain
                for iUnit, oUnit in tMobileLandInArea do
                    if not(oUnit.Dead) and oUnit.GetUnitId and oUnit.GetPosition and oUnit.GetAIBrain then
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Does unit already have micro active='..tostring((oUnit[M27UnitInfo.refbSpecialMicroActive] or false))..'; iTimeToRun='..iTimeToRun) end
                        oCurBrain = oUnit:GetAIBrain()
                        if oCurBrain.M27AI and not(oCurBrain.M27IsDefeated) and not(oCurBrain:IsDefeated()) and M27Logic.iTimeOfLastBrainAllDefeated < 10 and IsEnemy(oCurBrain:GetArmyIndex(), iBomberArmyIndex) then
                            --ACU specific
                            if M27Utilities.IsACU(oUnit) then
                                local aiBrain = oCurBrain
                                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and aiBrain[M27Overseer.refbIncludeACUInAllOutAttack] and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), aiBrain[M27Overseer.refoACUKillTarget]:GetPosition()) > (M27Logic.GetUnitMaxGroundRange({oUnit}) - 10) and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), aiBrain[M27Overseer.refoACUKillTarget]:GetPosition()) < 32 and (M27UnitInfo.GetUnitTechLevel(oBomber) == 1 or M27UnitInfo.GetUnitHealthPercent(oUnit) > 0.3) then
                                    --Dont dodge in case we can no longer attack ACU
                                else
                                    --If ACU is upgrading might not want to cancel
                                    local bDontTryAndDodge = false
                                    if oUnit:IsUnitState('Upgrading') then
                                        --Are we facing a T1 bomb?
                                        if EntityCategoryContains(categories.TECH1, oBomber.UnitId) then
                                            bDontTryAndDodge = true
                                        else
                                            --Facing T2+ bomb, so greater risk if we dont try and dodge; dont dodge if are almost complete
                                            if oUnit:GetWorkProgress() >= 0.9 then
                                                bDontTryAndDodge = true
                                            else
                                                --Is it a T2 bomber, and there arent many bombers nearby?
                                                if EntityCategoryContains(categories.TECH2, oBomber.UnitId) then
                                                    local tNearbyBombers = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryBomber + M27UnitInfo.refCategoryGunship - categories.TECH1, oUnit:GetPosition(), 100, 'Enemy')
                                                    if M27Utilities.IsTableEmpty(tNearbyBombers) == true then
                                                        bDontTryAndDodge = true
                                                    else
                                                        local iEnemyBomberCount = 0
                                                        for iEnemy, oEnemy in tNearbyBombers do
                                                            if M27UnitInfo.IsUnitValid(oEnemy) then
                                                                iEnemyBomberCount = iEnemyBomberCount + 1
                                                                if iEnemyBomberCount >= 4 then break end
                                                            end
                                                        end
                                                        if iEnemyBomberCount < 4 then bDontTryAndDodge = true end

                                                    end
                                                end
                                            end
                                        end
                                    end
                                    if bDebugMessages == true then LOG(sFunctionRef..': bDontTryAndDodge after checking if upgrading='..tostring(bDontTryAndDodge)) end
                                    if not(bDontTryAndDodge) then
                                        --Are we running and have significant nearby land threats and are against a T1 bomber?
                                        if oUnit.PlatoonHandle[M27PlatoonUtilities.refiEnemiesInRange] > 0 and oUnit.PlatoonHandle[M27PlatoonUtilities.refbHavePreviouslyRun] and EntityCategoryContains(categories.TECH1, oBomber.UnitId) then
                                            if M27Logic.GetCombatThreatRating(aiBrain, oUnit.PlatoonHandle[M27PlatoonUtilities.reftEnemiesInRange]) >= 250 then
                                                bDontTryAndDodge = true
                                            end
                                        end
                                    end

                                    if not(bDontTryAndDodge) then
                                        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and aiBrain[M27Overseer.refbIncludeACUInAllOutAttack] then iTimeToRun = math.max(iTimeToRun, 2) end
                                        if oUnit[M27UnitInfo.refbSpecialMicroActive] then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Will move in a circle as micro is already active') end
                                            MoveInCircleTemporarily(oUnit, iTimeToRun)
                                        else
                                            if bDebugMessages == true then LOG(sFunctionRef..': Will move away from bomb target temporarily') end
                                            MoveAwayFromTargetTemporarily(oUnit, iTimeToRun, tBombTarget)
                                            oUnit[M27UnitInfo.refiGameTimeMicroStarted] = GetGameTimeSeconds()
                                        end
                                    end
                                end
                            else
                                --Are we a mobile shield that isn't on the same team as the bomber? If so, then dont worry about dodging
                                --if not(EntityCategoryContains(M27UnitInfo.refCategoryMobileLandShield, oUnit.UnitId)) then
                                --if IsEnemy(oCurBrain:GetArmyIndex(), oBomber:GetAIBrain():GetArmyIndex()) and oUnit.MyShield and oUnit.MyShield:GetHealth() > 0 and (M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tBombTarget) - oUnit:GetBlueprint().Defense.Shield.ShieldSize * 0.5) <= -4 then
                                --Dont actually want to dodge as highly unlikely to avoid due to size of our shield bubble
                                --else

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
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DodgeBombsFiredByUnit(oWeapon, oBomber)
    --NOTE: BELOW IS SUPERCEDED
    --Should have already checked we have a bomber before calling this
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DodgeBombsFiredByUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tBombTarget = oWeapon:GetCurrentTargetPos()
    local iRadiusSize = 1.5
    local iBombSize = 2.5
    if EntityCategoryContains(categories.TECH2, oBomber.UnitId) then iBombSize = 3 end --Some t2 bombers do damage in a spread (cybran, uef)
    if oWeapon.GetBlueprint then iBombSize = math.min(iBombSize, (oWeapon:GetBlueprint().DamageRadius or iBombSize)) end
    local iTimeToRun = math.min(7, iBombSize + 1)
    if EntityCategoryContains(categories.TECH3, oBomber.UnitId) then
        iRadiusSize = 2.5
        iTimeToRun = 5
    elseif EntityCategoryContains(categories.TECH2, oBomber.UnitId) then
        iTimeToRun = 4
    end



    local iBomberArmyIndex = oBomber:GetAIBrain():GetArmyIndex()

    if bDebugMessages == true then
        LOG(sFunctionRef..': tBombTarget='..repru(tBombTarget))
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
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

--[[function GetOverchargeExtraActionOld(aiBrain, oPlatoon, oUnitWithOvercharge)
    --should have already confirmed overcharge action is available using CanUnitUseOvercharge
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetOverchargeExtraAction'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

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
            if oPlatoon[M27PlatoonUtilities.refbACUInPlatoon] == true and M27UnitInfo.GetUnitHealthPercent(M27Utilities.GetACU(aiBrain)) < 0.4 then bResourcesToOvercharge = true end
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
                    if M27UnitInfo.GetUnitHealthPercent(aiBrain[M27Overseer.refoLastNearestACU]) < 0.2 then
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
                if oPlatoon[M27PlatoonUtilities.refbHavePreviouslyRun] == true or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionRun or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionTemporaryRetreat or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionReturnToBase or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionGoToNearestRallyPoint or (M27Utilities.IsACU(oUnitWithOvercharge) and oUnitWithOvercharge:GetHealth() < aiBrain[M27Overseer.refiACUHealthToRunOn]) then bAreRunning = true end
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
                        --Check further away incase enemy has T2 PD that can see us
                        if bDebugMessages == true then LOG(sFunctionRef..': Checking if any T2 PD further away') end
                        tEnemyPointDefence = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH2 + categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH3, tUnitPosition, iInitialT2PDSearchRange, 'Enemy')
                        if M27Utilities.IsTableEmpty(tEnemyPointDefence) == false then
                            if bDebugMessages == true then LOG(sFunctionRef..': Have enemy T2 defence that can hit us but is out of our range - considering if OC it will bring us in range of T1 PD, and/or if shot is blocked, and/or if the T2PD cant even see us') end
                            local tNearbyT1PD
                            local iNearestT1PD = 10000
                            local iCurDistance
                            if iInitialT2PDSearchRange - iACURange > 0 then tNearbyT1PD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryPD * categories.TECH1, tUnitPosition, iInitialT2PDSearchRange - iACURange, 'Enemy') end
                            if M27Utilities.IsTableEmpty(tNearbyT1PD) == false then
                                for iT1PD, oT1PD in tNearbyT1PD do
                                    iCurDistance = M27Utilities.GetDistanceBetweenPositions(oT1PD:GetPosition(), tUnitPosition)
                                    if iCurDistance < iNearestT1PD then iNearestT1PD = iCurDistance end
                                end
                            end

                            for iUnit, oEnemyT2PD in tEnemyPointDefence do
                                --Can we get in range of the T2 PD without getting in range of the T1 PD? (approximates just based on distances rather than considering the likely path to take)
                                if M27Utilities.GetDistanceBetweenPositions(oEnemyT2PD:GetPosition(), tUnitPosition) - iACURange + 2 < iNearestT1PD then
                                    if M27Logic.IsShotBlocked(oUnitWithOvercharge, oEnemyT2PD) == false then
                                        --Can the T2 PD see us?
                                        if M27Utilities.CanSeeUnit(oEnemyT2PD:GetAIBrain(), oUnitWithOvercharge, true) then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Setting target to T2 PD') end
                                            oOverchargeTarget = oEnemyT2PD
                                            break
                                        else
                                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy T2 PDs owner can see our ACU') end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if oOverchargeTarget == nil then
                    local tEnemyT2Plus = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.TECH2 + categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.TECH3 + categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.EXPERIMENTAL - categories.SUBCOMMANDER + M27UnitInfo.refCategoryNavalSurface, tUnitPosition, iACURange, 'Enemy')
                    if M27Utilities.IsTableEmpty(tEnemyT2Plus) == false then
                        for iUnit, oEnemyT2Unit in tEnemyT2Plus do
                            if bDebugMessages == true then LOG(sFunctionRef..': Have enemy T2+ mobile land to consider') end
                            if M27Logic.IsShotBlocked(oUnitWithOvercharge, oEnemyT2Unit) == false then
                                if bDebugMessages == true then LOG(sFunctionRef..': Setting target to t2+ unit') end
                                oOverchargeTarget = oEnemyT2Unit
                                break
                            end
                        end
                    else
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': No T2PlusOrNavy in range of '..iACURange)
                            local tNearbyNavy = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryNavalSurface, tUnitPosition, iACURange, 'Enemy')
                            if M27Utilities.IsTableEmpty(tNearbyNavy) == false then
                                M27Utilities.ErrorHandler('Have nearby navy despite not showing up in tEnemyT2Plus')
                            end
                        end
                    end
                    if oOverchargeTarget == nil then
                        --NOTE: Not using unitinfo category below as want to include walls (as realised inadvertently introduced anti-wall protection for ACU)
                        local tEnemyPossibleTargets = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE + categories.STRUCTURE - categories.COMMAND - categories.FACTORY * categories.STRUCTURE, tUnitPosition, iACURange, 'Enemy')
                        local tNearbyEnemiesToTarget
                        local iMaxUnitsInArea = 0
                        local iCurUnitsInArea
                        local iMassValueOfUnitsInArea
                        for iUnit, oEnemyLandUnit in tEnemyPossibleTargets do
                            if bDebugMessages == true then LOG(sFunctionRef..': Have T1 units to consider, checking how many units are near them for AOE') end
                            tNearbyEnemiesToTarget = aiBrain:GetUnitsAroundPoint(categories.ALLUNITS, oEnemyLandUnit:GetPosition(), iOverchargeArea, 'Enemy')
                            if M27Utilities.IsTableEmpty(tNearbyEnemiesToTarget) == false then
                                iCurUnitsInArea = table.getn(tNearbyEnemiesToTarget)
                                if bDebugMessages == true then LOG(sFunctionRef..': Have T1 units with iCurUnitsInArea='..iCurUnitsInArea..' within area effect') end
                                iMassValueOfUnitsInArea = 0
                                if iCurUnitsInArea < iMinT1ForOvercharge then iMassValueOfUnitsInArea = M27Logic.GetCombatThreatRating(aiBrain, tNearbyEnemiesToTarget, true, nil, nil, nil, true) end
                                if iCurUnitsInArea >= iMinT1ForOvercharge or iMassValueOfUnitsInArea >= iMinT1ForOvercharge * 70 then
                                    --bShotIsBlocked = M27Logic.IsShotBlocked(oUnitWithOvercharge, oEnemyLandUnit)
                                    bShotIsBlocked = M27Logic.IsShotBlocked(oUnitWithOvercharge, oEnemyLandUnit)
                                    if bShotIsBlocked == false then
                                        if iCurUnitsInArea > iMaxUnitsInArea then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Setting target to t1 unit') end
                                            iMaxUnitsInArea = iCurUnitsInArea
                                            oOverchargeTarget = oEnemyLandUnit
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
                                    if M27UnitInfo.GetHealthPercent(oEnemyACUUnit) <= 0.1 then
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
                if bDebugMessages == true then LOG(sFunctionRef..': Telling platoon to process overcharge action on '..oOverchargeTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oOverchargeTarget)) end
                oPlatoon[M27PlatoonUtilities.refiExtraAction] = M27PlatoonUtilities.refExtraActionOvercharge
                oPlatoon[M27PlatoonUtilities.refExtraActionTargetUnit] = oOverchargeTarget
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end--]]

function GetOverchargeExtraAction(aiBrain, oPlatoon, oUnitWithOvercharge)
    --should have already confirmed overcharge action is available using CanUnitUseOvercharge
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetOverchargeExtraAction'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    --Do we have positive energy income? If not, then only overcharge if ACU is low on health as an emergency
    local bResourcesToOvercharge = false
    local oOverchargeTarget
    local bAreRunning = false
    local oEnemyACU
    local reftiAngleFromACUToUnit = 'M27AngleFromACUToUnit'
    local reftiDistFromACUToUnit = 'M27DistFromACUToUnit'
    local toStructuresAndACU

--Subfunction
    function IsBuildingOrACUBlockingShot(oFiringUnit, oTargetUnit)
        --Assumes have already been through tBlockingUnits and set their angle to the firing unit, so we just need to compare to firing unit
        if bDebugMessages == true then LOG(sFunctionRef..': Will see if any buildings or ACU are blocking the shot; if dont get log saying result was false then means was true') end
        if M27Utilities.IsTableEmpty(toStructuresAndACU) == false then
            local iAngleToTargetUnit = M27Utilities.GetAngleFromAToB(oFiringUnit:GetPosition(), oTargetUnit:GetPosition())
            local iDistToTargetUnit = M27Utilities.GetDistanceBetweenPositions(oFiringUnit:GetPosition(), oTargetUnit:GetPosition())
            local iCurAngleDif
            if bDebugMessages == true then LOG(sFunctionRef..': iAngleToTargetUnit='..iAngleToTargetUnit..'; iDistToTargetUnit='..iDistToTargetUnit) end
            for iUnit, oUnit in toStructuresAndACU do
                if not(oUnit == oTargetUnit) and iDistToTargetUnit > oUnit[reftiDistFromACUToUnit][aiBrain:GetArmyIndex()] then
                    iCurAngleDif = iAngleToTargetUnit - oUnit[reftiAngleFromACUToUnit][aiBrain:GetArmyIndex()]
                    if iCurAngleDif < 0 then iCurAngleDif = iCurAngleDif + 360 end
                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' will block a shot from the ACU to the target '..oTargetUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTargetUnit)..'; iCurAngleDif='..iCurAngleDif..'; 180 / iDistToTargetUnit='..180 / iDistToTargetUnit..'; oUnit[reftiAngleFromACUToUnit][aiBrain:GetArmyIndex()]='..oUnit[reftiAngleFromACUToUnit][aiBrain:GetArmyIndex()]..'; oUnit[reftiDistFromACUToUnit]='..oUnit[reftiDistFromACUToUnit][aiBrain:GetArmyIndex()]..'; angle from ACU to unit='..oUnit[reftiAngleFromACUToUnit][aiBrain:GetArmyIndex()]) end
                    if iCurAngleDif <= math.max(8, 180 / iDistToTargetUnit) then
                        return true
                    end
                end
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': End of code, will return false') end
        return false
    end

--Subfunction
    function WillShotHit(oFiringUnit, oTargetUnit)
        --Check for units in a transport
        if oTargetUnit:IsUnitState('Attached') or M27Logic.IsShotBlocked(oFiringUnit, oTargetUnit) or IsBuildingOrACUBlockingShot(oFiringUnit, oTargetUnit) then
            if bDebugMessages == true then LOG(sFunctionRef..': oTargetUnit='..oTargetUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTargetUnit)..'; shot is blocked so wont hit. IsShotBlocked='..tostring(M27Logic.IsShotBlocked(oFiringUnit, oTargetUnit))) end
            return false
        else return true
        end
    end


    --Check unit not already been given an overcharge action recently
    if bDebugMessages == true then LOG(sFunctionRef..': Has unit been given a recent OC order='..tostring((oUnitWithOvercharge[M27UnitInfo.refbOverchargeOrderGiven] or false))) end
    if not(oUnitWithOvercharge[M27UnitInfo.refbOverchargeOrderGiven]) then
        if M27Conditions.HaveExcessEnergy(aiBrain, 10) then bResourcesToOvercharge = true
        else
            if oPlatoon[M27PlatoonUtilities.refbACUInPlatoon] == true and M27UnitInfo.GetUnitHealthPercent(M27Utilities.GetACU(aiBrain)) < 0.4 then bResourcesToOvercharge = true end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Do we have resources to overcharge='..tostring((bResourcesToOvercharge or false))) end
        if bResourcesToOvercharge == true then
            local tUnitPosition = oUnitWithOvercharge:GetPosition()
            --local iACURange = M27Logic.GetACUMaxDFRange(oUnitWithOvercharge)
            local iACURange = M27UnitInfo.GetUnitMaxGroundRange(oUnitWithOvercharge)
            local iOverchargeArea = 2.5
            local bAbort = false

            --First locate where any blocking units are - will assume non-wall structures larger than a T1 pgen will block the shot, and ACUs will block
            toStructuresAndACU = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure - categories.SIZE4 + categories.COMMAND, tUnitPosition, 50, 'Enemy')
            if bDebugMessages == true then LOG(sFunctionRef..': First locating blocking units; is table empty='..tostring(M27Utilities.IsTableEmpty(toStructuresAndACU))..'; iACURange='..iACURange..'; iOverchargeArea='..iOverchargeArea) end
            if M27Utilities.IsTableEmpty(toStructuresAndACU) == false then
                for iUnit, oUnit in toStructuresAndACU do
                    if not(oUnit[reftiAngleFromACUToUnit]) then
                        oUnit[reftiAngleFromACUToUnit] = {}
                        oUnit[reftiDistFromACUToUnit] = {}
                    end
                    oUnit[reftiAngleFromACUToUnit][aiBrain:GetArmyIndex()] = M27Utilities.GetAngleFromAToB(tUnitPosition, oUnit:GetPosition())
                    oUnit[reftiDistFromACUToUnit][aiBrain:GetArmyIndex()] = M27Utilities.GetDistanceBetweenPositions(tUnitPosition, oUnit:GetPosition())
                    if bDebugMessages == true then LOG(sFunctionRef..': Angle from oUnit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to our ACU='..repru(oUnit[reftiAngleFromACUToUnit])..'; distance='..repru(oUnit[reftiDistFromACUToUnit])) end
                end
            end

            if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill then
                local iDistanceToEnemyACU
                --Target enemy ACU if its low health as a top priority unless it's about to move out of our range
                if M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoACUKillTarget]) and M27Utilities.CanSeeUnit(aiBrain, aiBrain[M27Overseer.refoACUKillTarget], true) then
                    oEnemyACU = aiBrain[M27Overseer.refoACUKillTarget]
                    if M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoLastNearestACU]) and aiBrain[M27Overseer.refoLastNearestACU]:GetHealth() < 1400 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy ACU is almost dead so want to target it, and not target anything else if we cant hit it') end
                        iDistanceToEnemyACU = M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.reftLastNearestACU], tUnitPosition)
                        if iDistanceToEnemyACU < (iACURange - 2) and WillShotHit(oUnitWithOvercharge, oEnemyACU) then
                            oOverchargeTarget = aiBrain[M27Overseer.refoLastNearestACU]
                        else
                            --bAbort = true
                        end
                    end
                end
                if bAbort == false then
                    if iDistanceToEnemyACU == nil then iDistanceToEnemyACU = M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.reftLastNearestACU], tUnitPosition) end
                    --Is ACU about to fall out of our vision or weapon range?
                    if iDistanceToEnemyACU + 4 > math.min(iACURange, 26) and M27UnitInfo.GetUnitHealthPercent(oUnitWithOvercharge) >= 0.8 and oUnitWithOvercharge.PlatoonHandle[M27PlatoonUtilities.refiEnemiesInRange] <= 4 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy ACU about to fall out of our vision or range so will abort as want to keep moving') end
                        bAbort = true
                    end
                end
            end
            if bAbort == false and not(oOverchargeTarget) then
                --Cycle through every land combat non-ACU unit within firing range to see if can find one that reduces the damage the most, or failing that does the most mass damage; will include all navy on the assumption isshotblocked will trigger if shot will go underwater (as otherwise we might ignore sera T2 destroyers)
                local tEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand - categories.COMMAND + M27UnitInfo.refCategoryPD + M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryAllNavy, tUnitPosition, iACURange - 1, 'Enemy')
                --local iMostMobileCombatMassDamage = 0
                --local oMostCombatMassDamage
                local iMostMassDamage = 0
                local oMostMassDamage, iKillsExpected
                local iMaxOverchargeDamage = (aiBrain:GetEconomyStored('ENERGY') * 0.9) * 0.25
                local iCurDamageDealt, iCurKillsExpected
                if bDebugMessages == true then LOG(sFunctionRef..': Will consider enemy mobile units and PD within 2 of the ACU max range; is the table empty='..tostring(M27Utilities.IsTableEmpty(tEnemyUnits))) end
                if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                    for iUnit, oUnit in tEnemyUnits do
                        if WillShotHit(oUnitWithOvercharge, oUnit) then
                            iCurDamageDealt, iCurKillsExpected = M27Logic.GetDamageFromOvercharge(aiBrain, oUnit, iOverchargeArea, iMaxOverchargeDamage)
                            if bDebugMessages == true then LOG(sFunctionRef..': Shot will hit enemy unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; damage result='..iCurDamageDealt) end
                            if iCurDamageDealt > iMostMassDamage then
                                iMostMassDamage = iCurDamageDealt
                                oMostMassDamage = oUnit
                                iKillsExpected = iCurKillsExpected

                            end
                        end
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Finished searching through enemy mobile untis and PD in range, iMostMassDamage='..iMostMassDamage..'; iKillsExpected='..(iKillsExpected or 0)..'; Energy stored %='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; E stored='..aiBrain:GetEconomyStored('ENERGY')) end

                --if iMostMobileCombatMassDamage >= 80 then
                --    oOverchargeTarget = oMostCombatMassDamage
                if iMostMassDamage >= 200 or iKillsExpected >= 3 or (iKillsExpected >= 1 and iMostMassDamage >= 100) or (iMostMassDamage >= 60 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.9 and (aiBrain:GetEconomyStored('ENERGY') >= 10000 or (aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome] >= 1 and aiBrain:GetEconomyStored('ENERGY') >= 8000))) then --e.g. striker is 56 mass; lobo is 36
                    oOverchargeTarget = oMostMassDamage
                    if bDebugMessages == true then LOG(sFunctionRef..': Have a mobile or PD unit in range that will do enough damage to, oOverchargeTarget='..oOverchargeTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oOverchargeTarget)) end
                else
                    --Check we aren't running before considering whether to target walls or T2 PDs
                    if not(oPlatoon[M27PlatoonUtilities.refbHavePreviouslyRun] == true or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionRun or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionTemporaryRetreat or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionReturnToBase or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionGoToNearestRallyPoint or (M27Utilities.IsACU(oUnitWithOvercharge) and oUnitWithOvercharge:GetHealth() < aiBrain[M27Overseer.refiACUHealthToRunOn])) then
                        --No decent combat targets; Check for lots of walls that might be blocking our path (dont reduce ACU range given these are structures)
                        --Only consider overcharging walls if no enemies within our combat range + 3
                        if M27Team.tTeamData[aiBrain.M27Team][M27Team.refiEnemyWalls] >= 9 then
                            local tAllEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand + M27UnitInfo.refCategoryStructure + M27UnitInfo.refCategoryNavalSurface, tUnitPosition, iACURange + 3, 'Enemy')
                            if M27Utilities.IsTableEmpty(tAllEnemies) then
                                tEnemyUnits = aiBrain:GetUnitsAroundPoint(categories.WALL, tUnitPosition, iACURange, 'Enemy')
                                if bDebugMessages == true then LOG(sFunctionRef..': iMostMassDamage='..iMostMassDamage..'; so will check for walls and other structure targets; is table of wall units empty='..tostring(M27Utilities.IsTableEmpty(tEnemyUnits))) end
                                if M27Utilities.IsTableEmpty(tEnemyUnits) == false and table.getn(tEnemyUnits) >= 5 then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have at least 5 wall units in range, so potential blockage; size='..table.getn(tEnemyUnits)) end
                                    local bSuspectedPathBlock = false
                                    --If more than 10 then assume blocking our path

                                    if table.getn(tEnemyUnits) >= 10 then
                                        if bDebugMessages == true then LOG(sFunctionRef..': At least 10 wall units so assuming a blockage') end
                                        bSuspectedPathBlock = true
                                    else
                                        local tFirstWall = tEnemyUnits[1]:GetPosition()
                                        for iWall, oWall in tEnemyUnits do
                                            if iWall > 1 then
                                                if M27Utilities.GetDistanceBetweenPositions(oWall:GetPosition(), tFirstWall) >= 4 then
                                                    bSuspectedPathBlock = true
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    if bSuspectedPathBlock then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Think enemy has walls in a line so will overcharge them unless they are all closer to our base than us') end
                                        iMostMassDamage = 0
                                        oMostMassDamage = nil
                                        bSuspectedPathBlock = false

                                        local iOurDistToBase = M27Utilities.GetDistanceBetweenPositions(tUnitPosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                        local iWallDistToBase
                                        for iWall, oUnit in tEnemyUnits do
                                            if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iOurDistToBase + 4 then
                                                bSuspectedPathBlock = true
                                                break
                                            end
                                        end
                                        if bSuspectedPathBlock then
                                            for iWall, oUnit in tEnemyUnits do
                                                if WillShotHit(oUnitWithOvercharge, oUnit) then
                                                    iCurDamageDealt = M27Logic.GetDamageFromOvercharge(aiBrain, oUnit, iOverchargeArea, iMaxOverchargeDamage, true)
                                                    if iCurDamageDealt > iMostMassDamage then
                                                        iMostMassDamage = iCurDamageDealt
                                                        oMostMassDamage = oUnit
                                                    end
                                                end
                                            end
                                            if oMostMassDamage then oOverchargeTarget = oMostMassDamage end
                                        elseif bDebugMessages == true then LOG(sFunctionRef..': Walls are all closer to our base than we are so probably not blocking us')
                                        end
                                    elseif bDebugMessages == true then LOG(sFunctionRef..': Dont think the walls are in a line so wont try and OC')
                                    end
                                end
                            end
                        end
                        if not(oOverchargeTarget) and not(M27Overseer.refbAreBigThreats) then --Is there enemy T2PD nearby (out of our range)?
                            --Check further away incase enemy has T2 PD that can see us and we arent running
                            if oPlatoon[M27PlatoonUtilities.refbHavePreviouslyRun] == true or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionRun or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionTemporaryRetreat or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionReturnToBase or oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionGoToNearestRallyPoint or (M27Utilities.IsACU(oUnitWithOvercharge) and oUnitWithOvercharge:GetHealth() < aiBrain[M27Overseer.refiACUHealthToRunOn]) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Checking if any T2 PD further away') end
                                tEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2PlusPD, tUnitPosition, 50, 'Enemy')
                                if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have enemy T2 defence that can hit us but is out of our range - considering if OC it will bring us in range of T1 PD, and/or if shot is blocked, and/or if the T2PD cant even see us') end
                                    local tNearbyT1PD
                                    local iNearestT1PD = 10000
                                    local iCurDistance
                                    if 50 - iACURange > 0 then tNearbyT1PD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryPD * categories.TECH1, tUnitPosition, 50 - iACURange, 'Enemy') end
                                    if M27Utilities.IsTableEmpty(tNearbyT1PD) == false then
                                        for iT1PD, oT1PD in tNearbyT1PD do
                                            iCurDistance = M27Utilities.GetDistanceBetweenPositions(oT1PD:GetPosition(), tUnitPosition)
                                            if iCurDistance < iNearestT1PD then iNearestT1PD = iCurDistance end
                                        end
                                    end

                                    for iUnit, oEnemyT2PD in tEnemyUnits do
                                        --Can we get in range of the T2 PD without getting in range of the T1 PD? (approximates just based on distances rather than considering the likely path to take)
                                        if M27Utilities.GetDistanceBetweenPositions(oEnemyT2PD:GetPosition(), tUnitPosition) - iACURange + 2 < iNearestT1PD then
                                            if M27Logic.IsShotBlocked(oUnitWithOvercharge, oEnemyT2PD) == false then
                                                --Can the T2 PD see us?
                                                if M27Utilities.CanSeeUnit(oEnemyT2PD:GetAIBrain(), oUnitWithOvercharge, true) then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Setting target to T2 PD') end
                                                    oOverchargeTarget = oEnemyT2PD
                                                    break
                                                else
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Enemy T2 PDs owner can see our ACU') end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if not(oOverchargeTarget) then
                            --Consider all structures (can do ACU max range since before when structures were considered we were looking at reduced range)
                            tEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, tUnitPosition, iACURange, 'Enemy')
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering all enemy structures within range of ACU; is table empty='..tostring(M27Utilities.IsTableEmpty(tEnemyUnits))) end
                            --local iMostMobileCombatMassDamage = 0
                            --local oMostCombatMassDamage
                            if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                                if bDebugMessages == true then LOG(sFunctionRef..': Considering other enemy structures in range; iMostMassDamage before looking='..iMostMassDamage) end
                                for iUnit, oUnit in tEnemyUnits do
                                    if WillShotHit(oUnitWithOvercharge, oUnit) then
                                        iCurDamageDealt, iCurKillsExpected = M27Logic.GetDamageFromOvercharge(aiBrain, oUnit, iOverchargeArea, iMaxOverchargeDamage)
                                        if bDebugMessages == true then LOG(sFunctionRef..': Shot will hit enemy unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; damage result='..iCurDamageDealt) end
                                        if iCurDamageDealt > iMostMassDamage then
                                            iMostMassDamage = iCurDamageDealt
                                            oMostMassDamage = oUnit
                                            iKillsExpected = iCurKillsExpected
                                        end
                                    end
                                end
                            end
                            if iMostMassDamage >= 110 then
                                oOverchargeTarget = oMostMassDamage
                            end
                        end
                    end
                end
            end
            if oOverchargeTarget == nil then
                if bDebugMessages == true then LOG(sFunctionRef..': No OC targets found, will target enemy ACU if we are in ACU kill mode and have max energy') end
                --Target enemy ACU anyway if we have max energy and in attack mode
                if oEnemyACU and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and aiBrain:GetEconomyStoredRatio('ENERGY') >= 1 and WillShotHit(oUnitWithOvercharge, oEnemyACU) then
                    oOverchargeTarget = oEnemyACU
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': oOverchargeTarget is nil, wont give overcharge action') end
                end
            end
            if oOverchargeTarget then
                if bDebugMessages == true then LOG(sFunctionRef..': Telling platoon to process overcharge action on '..oOverchargeTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oOverchargeTarget)) end
                oPlatoon[M27PlatoonUtilities.refiExtraAction] = M27PlatoonUtilities.refExtraActionOvercharge
                oPlatoon[M27PlatoonUtilities.refExtraActionTargetUnit] = oOverchargeTarget
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

--[[function HoverBombTargetOldBase(aiBrain, oBomber, oTarget)
    --Called if we dont think our bomb will kill the target; call via fork thread
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'HoverBombTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, oBomber='..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; oTarget='..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..'; GameTime='..GetGameTimeSeconds()) end

    oBomber[M27UnitInfo.refbSpecialMicroActive] = true
    local iReloadTime = 5
    local iBomberRange = 40
    local oBP = oBomber:GetBlueprint()

    for iWeapon, tWeapon in oBP.Weapon do
        if tWeapon.WeaponCategory == 'Bomb' then
            if tWeapon.RateOfFire > 0 then iReloadTime = 1 / tWeapon.RateOfFire end
            iBomberRange = tWeapon.MaxRadius
        end
    end

    local iStartTime = GetGameTimeSeconds()
    --local iAngleToTarget

    --M27Utilities.IssueTrackedClearCommands({oBomber})
    --Config:
    local iTicksBetweenOrders = 5
    --local tiAngleToUse = {50, -50, 50}
    local iDistanceAwayToMove = 10
    --local tiReloadTimePercent = {0.25, 0.75}
    --local iMaxAngleDifference = 10
    local iAngleAdjust = 50


    --Other variables:
    --local tiAngleTimeThresholds = {iStartTime + iReloadTime *tiReloadTimePercent[1], iStartTime + iReloadTime * tiReloadTimePercent[2]}
    local iActualAngleToUse
    --local iAngleTableRef
    local iCurAngleDif
    --local iPrevAngleAdjust = iAngleAdjust
    local iAngleAdjustToUse
    local iFacingDirection
    local iAngleToTarget

    local iCurTick = 0
    local bTriedMovingForwardsAndTurning




    while GetGameTimeSeconds() - iStartTime < iReloadTime do
        iCurTick = iCurTick + 1
        if iCurTick == 1 then
            M27Utilities.IssueTrackedClearCommands({oBomber})
            iFacingDirection = M27UnitInfo.GetUnitFacingAngle(oBomber)
            iAngleToTarget = M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oTarget:GetPosition())
            iCurAngleDif = iFacingDirection - iAngleToTarget
            --e.g. if bomber is facing 350 degrees, and the target is at 10 degrees, then it means there's only a dif of 20 degrees, but we want the bomber to go 350+50, rather than 350-50.  Facing - Angle would result in a positive value
            --if instead bomber was facing 10 degrees, and the target was 30 degrees, then would get -20 as the result, and so want to also increase
            --the effect of the below is that when bomber is facing 350 degrees and target 10 degrees, it will treat the difference as being 350 - 10 - 360 = -20, and want the bomber to go 350+50; if insteadbomber 10 and target 30, then dif = -20 and no adjustment made
            if math.abs(iCurAngleDif) > 180 then
                if iCurAngleDif > 180 then
                    --iFacingDirection is too high so decrease the angle difference
                    iCurAngleDif = iCurAngleDif - 360
                else --Curangledif must be < -180, so angletotarget is too high
                    iCurAngleDif = iCurAngleDif + 360
                end
            end


            if iCurAngleDif < 0 then
                iAngleAdjustToUse = iAngleAdjust
            else iAngleAdjustToUse = -iAngleAdjust
            end




            iActualAngleToUse = iFacingDirection + iAngleAdjustToUse
            local tTempTarget = M27Utilities.MoveInDirection(oBomber:GetPosition(), iActualAngleToUse, iDistanceAwayToMove, true)
            IssueMove({oBomber}, tTempTarget)
            if bDebugMessages == true then LOG(sFunctionRef..': iFacingDirection='..iFacingDirection..'; iCurANgleDif='..iCurAngleDif..'; iAngleAdjustToUse='..iAngleAdjustToUse..'; iActualAngleToUse='..iActualAngleToUse..'; angle from bomber to target='..M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oTarget:GetPosition())) end
        elseif iCurTick >= iTicksBetweenOrders then iCurTick = 0
        end

        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(1)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

        if not(M27UnitInfo.IsUnitValid(oBomber)) or not(M27UnitInfo.IsUnitValid(oTarget)) then
            if bDebugMessages == true then LOG(sFunctionRef..': either the bomber or target is no longer valid so aborting micro') end
            break
        end
        --]]

        --[[if GetGameTimeSeconds() - iStartTime >= iReloadTime then
            --Only keep going if our angle is far away
            iFacingDirection = M27UnitInfo.GetUnitFacingAngle(oBomber)
            iCurAngleDif = iFacingDirection - M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oTarget:GetPosition())

            if math.abs(iCurAngleDif) > 180 then
                if iCurAngleDif > 180 then
                    --iFacingDirection is too high so decrease the angle difference
                    iCurAngleDif = iCurAngleDif - 360
                else --Curangledif must be < -180, so angletotarget is too high
                    iCurAngleDif = iCurAngleDif + 360
                end
            end

            if bDebugMessages == true then LOG(sFunctionRef..': Have reloaded, will see if can get slightly better angle. iCurAngleDif='..iCurAngleDif..'; distance='..M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oTarget:GetPosition())..'; iFacingDirection='..iFacingDirection..'; Angle from bomber to target='..M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oTarget:GetPosition())) end
            if math.abs(iCurAngleDif) >= 170 or M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oTarget:GetPosition()) <= 1 then
                if bDebugMessages == true then LOG(sFunctionRef..': Angle dif is more than 110 so will give up') end
                break
            elseif math.abs(iCurAngleDif) <= 30 then
                if bDebugMessages == true then LOG(sFunctionRef..': Angle dif is less than 30 so will try and attack') end
                break
            --elseif math.abs(iCurAngleDif) <= 35 and M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oTarget:GetPosition()) <= 8 then
                --if bDebugMessages == true then LOG(sFunctionRef..': Within 45 degrees and 8 distance so will try and attack') end
                --break
            elseif bDebugMessages == true then LOG(sFunctionRef..': Angle dif too far to attack but might be able to do better so will keep trying')
            end
        end--]]
        --[[
    end
    if M27UnitInfo.IsUnitValid(oBomber) then
        oBomber[M27UnitInfo.refbSpecialMicroActive] = false
        if M27UnitInfo.IsUnitValid(oTarget) then
            --Below function should clear commands and then issue an attack
            if bDebugMessages == true then
                LOG(sFunctionRef..': Bomber '..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; Target '..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..'; Time to wait between orders='..iTicksBetweenOrders..'; Distance away to move to='..iDistanceAwayToMove..'; iAngleAdjust='..iAngleAdjust..'; Bomber facing direction='..M27UnitInfo.GetUnitFacingAngle(oBomber)..'; Angle from bomber to target='..M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oTarget:GetPosition())..'; Distance from bomber to target='..M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oTarget:GetPosition())..'; GameTime='..GetGameTimeSeconds())
                LOG(sFunctionRef..': Have valid bomber and target so will issue an attack order for the bomber to attack the target')
            end
            M27AirOverseer.IssueNewAttackToBomber(oBomber, oTarget, 1, true)
        else
            M27Utilities.IssueTrackedClearCommands({oBomber})
            ForkThread(M27AirOverseer.DelayedBomberTargetRecheck, oBomber)
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end--]]

function HoverBombTarget(aiBrain, oBomber, oTarget)
    --Called if we dont think our bomb will kill the target; call via fork thread
    --See separate xls notes for various different combinations that have tried to get hover-bombing to work.  The range at which a bomber fires it's bomb and the angle is affected by the bomber speed, so the below is an approximate approach that wont always work
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'HoverBombTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, oBomber='..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; oTarget='..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..'; GameTime='..GetGameTimeSeconds()) end

    if not(oBomber[M27UnitInfo.refbSpecialMicroActive]) then

        oBomber[M27UnitInfo.refbSpecialMicroActive] = true
        local iReloadTime = 5
        local iBomberRange = 40
        local oBP = oBomber:GetBlueprint()
        local iAOE, iStrikeDamage, iFiringRandomness = M27UnitInfo.GetBomberAOEAndStrikeDamage(oBomber)

        for iWeapon, tWeapon in oBP.Weapon do
            if tWeapon.WeaponCategory == 'Bomb' then
                if tWeapon.RateOfFire > 0 then iReloadTime = 1 / tWeapon.RateOfFire end
                iBomberRange = tWeapon.MaxRadius
            end
        end

        local iStartTime = GetGameTimeSeconds()
        --local iAngleToTarget

        --M27Utilities.IssueTrackedClearCommands({oBomber})
        --Config:
        local iTicksBetweenOrders = 5
        --local tiAngleToUse = {50, -50, 50}
        local iDistanceAwayToMove = 10
        --local tiReloadTimePercent = {0.25, 0.75}
        --local iMaxAngleDifference = 10
        local iAngleAdjust = 50


        --Other variables:
        --local tiAngleTimeThresholds = {iStartTime + iReloadTime *tiReloadTimePercent[1], iStartTime + iReloadTime * tiReloadTimePercent[2]}
        local iActualAngleToUse
        --local iAngleTableRef
        local iCurAngleDif
        --local iPrevAngleAdjust = iAngleAdjust
        local iAngleAdjustToUse
        local iFacingDirection
        local iAngleToTarget

        local iCurTick = 0
        local bTriedMovingForwardsAndTurning = false
        local iDistToTarget
        local tTempTarget
        local tGroundTarget




        while GetGameTimeSeconds() - iStartTime < iReloadTime + 20 do
            iCurTick = iCurTick + 1

            iFacingDirection = M27UnitInfo.GetUnitFacingAngle(oBomber)
            iAngleToTarget = M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oTarget:GetPosition())
            iCurAngleDif = iFacingDirection - iAngleToTarget
            iDistToTarget = M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oTarget:GetPosition())
            --e.g. if bomber is facing 350 degrees, and the target is at 10 degrees, then it means there's only a dif of 20 degrees, but we want the bomber to go 350+50, rather than 350-50.  Facing - Angle would result in a positive value
            --if instead bomber was facing 10 degrees, and the target was 30 degrees, then would get -20 as the result, and so want to also increase
            --the effect of the below is that when bomber is facing 350 degrees and target 10 degrees, it will treat the difference as being 350 - 10 - 360 = -20, and want the bomber to go 350+50; if insteadbomber 10 and target 30, then dif = -20 and no adjustment made
            if math.abs(iCurAngleDif) > 180 then
                if iCurAngleDif > 180 then
                    --iFacingDirection is too high so decrease the angle difference
                    iCurAngleDif = iCurAngleDif - 360
                else --Curangledif must be < -180, so angletotarget is too high
                    iCurAngleDif = iCurAngleDif + 360
                end
            end


            if iCurAngleDif < 0 then
                iAngleAdjustToUse = iAngleAdjust
            else iAngleAdjustToUse = -iAngleAdjust
            end

            if iCurTick == 1 then
                M27Utilities.IssueTrackedClearCommands({oBomber})

                iActualAngleToUse = iFacingDirection + iAngleAdjustToUse
                tTempTarget = M27Utilities.MoveInDirection(oBomber:GetPosition(), iActualAngleToUse, iDistanceAwayToMove, true)
                IssueMove({oBomber}, tTempTarget)
                if bDebugMessages == true then LOG(sFunctionRef..': Just issued move order, iFacingDirection='..iFacingDirection..'; iCurANgleDif='..iCurAngleDif..'; iAngleAdjustToUse='..iAngleAdjustToUse..'; iActualAngleToUse='..iActualAngleToUse..'; angle from bomber to target='..M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oTarget:GetPosition())) end
            elseif iCurTick >= iTicksBetweenOrders then iCurTick = 0
            end

            --Make the angle dif an absolute number for below tests
            iCurAngleDif = math.abs(iCurAngleDif)

            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitTicks(1)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

            if not(M27UnitInfo.IsUnitValid(oBomber)) or not(M27UnitInfo.IsUnitValid(oTarget)) then
                if bDebugMessages == true then LOG(sFunctionRef..': either the bomber or target is no longer valid so aborting micro') end
                break
            elseif iDistToTarget <= 8 and iCurAngleDif >= 30 then
                if bDebugMessages == true then LOG(sFunctionRef..': Dont expect we will be able to hit from current position, so will try and moving forwards and turning around unless have already done this once. bTriedMovingForwardsAndTurning='..tostring(bTriedMovingForwardsAndTurning)) end
                if bTriedMovingForwardsAndTurning then
                    break
                else
                    M27Utilities.IssueTrackedClearCommands({oBomber})
                    tTempTarget = M27Utilities.MoveInDirection(oBomber:GetPosition(), iFacingDirection, 20, true)
                    IssueMove({oBomber}, tTempTarget)
                    bTriedMovingForwardsAndTurning = true
                    if bDebugMessages == true then LOG(sFunctionRef..': Telling the bomber to move forwards for a while and will then try and get it to turn around in a bit') end
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    WaitSeconds(2.5)
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                    iCurTick = 0
                end
            elseif GetGameTimeSeconds() - iStartTime >= iReloadTime then
                --Angle between 15-30, it appears that at short distances a greater angle might be acceptable
                if bDebugMessages == true then LOG(sFunctionRef..': Bomb is ready to fire so will check every tick if our angle is close enough.  iCurAngleDif='..iCurAngleDif) end
                if iCurAngleDif <= math.min(30, math.max(40 - iDistToTarget, 6)) then
                    if bDebugMessages == true then LOG(sFunctionRef..': have reached reload time so will try and attack as curangledif is <=28. iCurAngleDif='..iCurAngleDif..'; iDistToTarget='..iDistToTarget) end
                    break
                else
                    --If we fire a bomb now, at a target straight in front but 10 away, will we hit it?
                    if iAOE > 2 then
                        tTempTarget = M27Utilities.MoveInDirection(oBomber:GetPosition(), iFacingDirection, 8.5, false)
                        if M27Utilities.GetDistanceBetweenPositions(tTempTarget, oTarget:GetPosition()) < (iAOE - 1 - iFiringRandomness * 1) then
                            tGroundTarget = tTempTarget
                            break
                        end
                    end
                end
            elseif bDebugMessages == true then LOG(sFunctionRef..': Bomb not loaded yet, will continue loop')
            end

        end
        if M27UnitInfo.IsUnitValid(oBomber) then
            oBomber[M27UnitInfo.refbSpecialMicroActive] = false
            if M27UnitInfo.IsUnitValid(oTarget) then
                --Below function should clear commands and then issue an attack
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Bomber '..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; Target '..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..'; Time to wait between orders='..iTicksBetweenOrders..'; Distance away to move to='..iDistanceAwayToMove..'; iAngleAdjust='..iAngleAdjust..'; Bomber facing direction='..M27UnitInfo.GetUnitFacingAngle(oBomber)..'; Angle from bomber to target='..M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oTarget:GetPosition())..'; Distance from bomber to target='..M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oTarget:GetPosition())..'; GameTime='..GetGameTimeSeconds())
                    LOG(sFunctionRef..': Have valid bomber and target so will issue an attack order for the bomber to attack the target, unless we have a ground target. tGroundTarget='..repru((tGroundTarget or {'nil'})))
                end
                if tGroundTarget then
                    if bDebugMessages == true then LOG(sFunctionRef..': Issuing attack order on ground='..repru(tGroundTarget)) end
                    oBomber[M27AirOverseer.reftGroundAttackLocation] = tGroundTarget
                    M27Utilities.IssueTrackedClearCommands({oBomber})
                    IssueAttack({oBomber}, tGroundTarget)
                else
                    M27AirOverseer.IssueNewAttackToBomber(oBomber, oTarget, 1, true)
                end
            else
                M27Utilities.IssueTrackedClearCommands({oBomber})
                if bDebugMessages == true then LOG(sFunctionRef..': Cleared bomber commands and will call the bomber target recheck') end
                ForkThread(M27AirOverseer.DelayedBomberTargetRecheck, oBomber)
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function TurnAirUnitAndMoveToTarget(aiBrain, oBomber, tDirectionToMoveTo, iMaxAcceptableAngleDif)
    --Based on hoverbomb logic - may give unexpected results if not using with T3 bombers
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'TurnAirUnitAndMoveToTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, oBomber='..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; GameTime='..GetGameTimeSeconds()) end


    local iStartTime = GetGameTimeSeconds()
    --local iAngleToTarget

    --Config:
    local iTicksBetweenOrders = 5
    local iDistanceAwayToMove = 10
    local iAngleAdjust = 50


    --Other variables:
    local iActualAngleToUse
    local iCurAngleDif
    local iAngleAdjustToUse
    local iFacingDirection
    local iAngleToTarget

    local iCurTick = 0
    local bTriedMovingForwardsAndTurning = false
    local iDistToTarget
    local tTempTarget

    local iMaxMicroTime = 5 --will micro for up to 5 seconds
    if EntityCategoryContains(categories.EXPERIMENTAL, oBomber.UnitId) then iMaxMicroTime = 10 end


    local iFacingAngleWanted = M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), tDirectionToMoveTo)

    --Clear trackers so we dont think we're targeting anything - commented out as this is called via the clearairunitassignmenttracker so causes issues
    --M27AirOverseer.ClearAirUnitAssignmentTrackers(aiBrain, oBomber, true)
    oBomber[M27UnitInfo.refbSpecialMicroActive] = true



    while GetGameTimeSeconds() - iStartTime < iMaxMicroTime do
        iCurTick = iCurTick + 1

        iFacingDirection = M27UnitInfo.GetUnitFacingAngle(oBomber)
        iAngleToTarget = M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), tDirectionToMoveTo)
        iCurAngleDif = iFacingDirection - iAngleToTarget
        iDistToTarget = M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), tDirectionToMoveTo)
        --e.g. if bomber is facing 350 degrees, and the target is at 10 degrees, then it means there's only a dif of 20 degrees, but we want the bomber to go 350+50, rather than 350-50.  Facing - Angle would result in a positive value
        --if instead bomber was facing 10 degrees, and the target was 30 degrees, then would get -20 as the result, and so want to also increase
        --the effect of the below is that when bomber is facing 350 degrees and target 10 degrees, it will treat the difference as being 350 - 10 - 360 = -20, and want the bomber to go 350+50; if insteadbomber 10 and target 30, then dif = -20 and no adjustment made
        if math.abs(iCurAngleDif) > 180 then
            if iCurAngleDif > 180 then
                --iFacingDirection is too high so decrease the angle difference
                iCurAngleDif = iCurAngleDif - 360
            else --Curangledif must be < -180, so angletotarget is too high
                iCurAngleDif = iCurAngleDif + 360
            end
        end


        if iCurAngleDif < 0 then
            iAngleAdjustToUse = iAngleAdjust
        else iAngleAdjustToUse = -iAngleAdjust
        end

        --Are we close enough to the direction wanted?
        iCurAngleDif = math.abs(iCurAngleDif)
        if iCurAngleDif <= (iMaxAcceptableAngleDif or 15) then
            --Are close enough in angle so can stop the micro
            break
        else
            if iCurTick == 1 then
                M27Utilities.IssueTrackedClearCommands({oBomber})

                iActualAngleToUse = iFacingDirection + iAngleAdjustToUse
                tTempTarget = M27Utilities.MoveInDirection(oBomber:GetPosition(), iActualAngleToUse, iDistanceAwayToMove, true)
                IssueMove({oBomber}, tTempTarget)
                if bDebugMessages == true then LOG(sFunctionRef..': Just issued move order, iFacingDirection='..iFacingDirection..'; iCurANgleDif='..iCurAngleDif..'; iAngleAdjustToUse='..iAngleAdjustToUse..'; iActualAngleToUse='..iActualAngleToUse..'; angle from bomber to target='..M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), tDirectionToMoveTo)) end
            elseif iCurTick >= iTicksBetweenOrders then iCurTick = 0
            end

            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitTicks(1)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            if not(M27UnitInfo.IsUnitValid(oBomber)) then
                break
            end
        end
    end

    if M27UnitInfo.IsUnitValid(oBomber) then
        oBomber[M27UnitInfo.refbSpecialMicroActive] = false
        M27Utilities.IssueTrackedClearCommands({oBomber})
        IssueMove({oBomber}, tDirectionToMoveTo)
        if bDebugMessages == true then LOG(sFunctionRef..': Just cleared bomber '..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..' commands and told it to move to '..repru(tDirectionToMoveTo)..'; GameTime='..GetGameTimeSeconds()) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end


function ExperimentalSAMHitAndRun(oBomber, oTarget)
    --Only for use with experimental bomber - if it has fired a bomb at SAMs that are shielded, then activate this
    --Aims to turn the experimental bomber around in opposite direction to SAM, move away a bit, then turn back and fire another bomb before aborting
    --Very similar to hover-bombing logic


    --Called if we dont think our bomb will kill the target; call via fork thread
    --See separate xls notes for various different combinations that have tried to get hover-bombing to work.  The range at which a bomber fires it's bomb and the angle is affected by the bomber speed, so the below is an approximate approach that wont always work
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ExperimentalSAMHitAndRun'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, oBomber='..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; oTarget='..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..'; GameTime='..GetGameTimeSeconds()) end

    if not(oBomber[M27UnitInfo.refbSpecialMicroActive]) then

        oBomber[M27UnitInfo.refbSpecialMicroActive] = true
        local iReloadTime = 5
        local iBomberRange = 40
        local oBP = oBomber:GetBlueprint()
        local iAOE, iStrikeDamage, iFiringRandomness = M27UnitInfo.GetBomberAOEAndStrikeDamage(oBomber)

        for iWeapon, tWeapon in oBP.Weapon do
            if tWeapon.WeaponCategory == 'Bomb' then
                if tWeapon.RateOfFire > 0 then iReloadTime = 1 / tWeapon.RateOfFire end
                iBomberRange = tWeapon.MaxRadius
            end
        end

        local iStartTime = GetGameTimeSeconds()
        --local iAngleToTarget

        --M27Utilities.IssueTrackedClearCommands({oBomber})
        --Config:
        local iTicksBetweenOrders = 5
        --local tiAngleToUse = {50, -50, 50}
        local iDistanceAwayToMove = 10
        --local tiReloadTimePercent = {0.25, 0.75}
        --local iMaxAngleDifference = 10
        local iAngleAdjust = 50


        --Other variables:
        --local tiAngleTimeThresholds = {iStartTime + iReloadTime *tiReloadTimePercent[1], iStartTime + iReloadTime * tiReloadTimePercent[2]}
        local iActualAngleToUse
        --local iAngleTableRef
        local iCurAngleDif
        --local iPrevAngleAdjust = iAngleAdjust
        local iAngleAdjustToUse
        local iFacingDirection = M27UnitInfo.GetUnitFacingAngle(oBomber)
        local iAngleToTarget

        local iCurTick = 0
        local bTriedMovingForwardsAndTurning = false
        local iDistToTarget
        local tTempTarget
        local tGroundTarget

        local iMaxDistanceAwayWanted = M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oTarget:GetPosition()) * 3
        local iAngleAwayWanted = M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oTarget:GetPosition()) + 180
        if iAngleAwayWanted > 360 then iAngleAwayWanted = iAngleAwayWanted - 360 end
        iCurAngleDif = M27Utilities.GetAngleDifference(iFacingDirection, iAngleAwayWanted)
        local iMaxAcceptableAngleDif = 30


        --First turn around most of the way
        while iCurAngleDif >= iMaxAcceptableAngleDif do
            iCurTick = iCurTick + 1

            iFacingDirection = M27UnitInfo.GetUnitFacingAngle(oBomber)
            --iAngleToTarget = M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), tDirectionToMoveTo)
            iCurAngleDif = iFacingDirection - iAngleAwayWanted
            --iDistToTarget = M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), tDirectionToMoveTo)
            --e.g. if bomber is facing 350 degrees, and the target is at 10 degrees, then it means there's only a dif of 20 degrees, but we want the bomber to go 350+50, rather than 350-50.  Facing - Angle would result in a positive value
            --if instead bomber was facing 10 degrees, and the target was 30 degrees, then would get -20 as the result, and so want to also increase
            --the effect of the below is that when bomber is facing 350 degrees and target 10 degrees, it will treat the difference as being 350 - 10 - 360 = -20, and want the bomber to go 350+50; if insteadbomber 10 and target 30, then dif = -20 and no adjustment made
            if math.abs(iCurAngleDif) > 180 then
                if iCurAngleDif > 180 then
                    --iFacingDirection is too high so decrease the angle difference
                    iCurAngleDif = iCurAngleDif - 360
                else --Curangledif must be < -180, so angletotarget is too high
                    iCurAngleDif = iCurAngleDif + 360
                end
            end


            if iCurAngleDif < 0 then
                iAngleAdjustToUse = iAngleAdjust
            else iAngleAdjustToUse = -iAngleAdjust
            end

            --Are we close enough to the direction wanted?
            iCurAngleDif = math.abs(iCurAngleDif)
            if iCurAngleDif <= iMaxAcceptableAngleDif then
                --Are close enough in angle so can stop the micro
                break
            else
                if iCurTick == 1 then
                    M27Utilities.IssueTrackedClearCommands({oBomber})

                    iActualAngleToUse = iFacingDirection + iAngleAdjustToUse
                    tTempTarget = M27Utilities.MoveInDirection(oBomber:GetPosition(), iActualAngleToUse, iDistanceAwayToMove, true)
                    IssueMove({oBomber}, tTempTarget)
                    if bDebugMessages == true then LOG(sFunctionRef..': Just issued move order, iFacingDirection='..iFacingDirection..'; iCurANgleDif='..iCurAngleDif..'; iAngleAdjustToUse='..iAngleAdjustToUse..'; iActualAngleToUse='..iActualAngleToUse..'; angle from bomber to target='..M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), tTempTarget)) end
                elseif iCurTick >= iTicksBetweenOrders then iCurTick = 0
                end

                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitTicks(1)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                if not(M27UnitInfo.IsUnitValid(oBomber)) or not(M27UnitInfo.IsUnitValid(oTarget)) then
                    break
                end
            end
        end

        --Are facing in the direction wanted, so issue a move command
        if M27UnitInfo.IsUnitValid(oBomber) and M27UnitInfo.IsUnitValid(oTarget) then

            local iMoveStartTime = GetGameTimeSeconds()
            local iTimeToTurn = (iMoveStartTime - iStartTime)
            --Time to move away: Assume will move in roughly the same amount of time when coming back to fire bomb.  Want to move away slightly longer than this to make sure we can fire a bomb in time.  Also need to allow time to turn around again


            --The below time means we dont maximise DPS, but we increase survivability by increasing the distance at which the bomb can be fired
            local iTimeToStartTurn = iMoveStartTime + iReloadTime - math.min(iReloadTime, (iTimeToTurn * 2)) + 4

            M27Utilities.IssueTrackedClearCommands({oBomber})
            IssueMove({oBomber}, M27Utilities.MoveInDirection(oTarget:GetPosition(), iAngleAwayWanted, iMaxDistanceAwayWanted, true))

            while GetGameTimeSeconds() < iTimeToStartTurn do
                if not(M27UnitInfo.IsUnitValid(oBomber)) or not(M27UnitInfo.IsUnitValid(oTarget)) then
                    break
                end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitTicks(1)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            end



            if M27UnitInfo.IsUnitValid(oBomber) and M27UnitInfo.IsUnitValid(oTarget) then
                --Have finished moving, turn again and fire the same as if were hover-bombing
                iCurTick = 0

                while M27UnitInfo.IsUnitValid(oBomber) do
                    iCurTick = iCurTick + 1

                    iFacingDirection = M27UnitInfo.GetUnitFacingAngle(oBomber)
                    iAngleToTarget = M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oTarget:GetPosition())
                    iCurAngleDif = iFacingDirection - iAngleToTarget
                    iDistToTarget = M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oTarget:GetPosition())
                    --e.g. if bomber is facing 350 degrees, and the target is at 10 degrees, then it means there's only a dif of 20 degrees, but we want the bomber to go 350+50, rather than 350-50.  Facing - Angle would result in a positive value
                    --if instead bomber was facing 10 degrees, and the target was 30 degrees, then would get -20 as the result, and so want to also increase
                    --the effect of the below is that when bomber is facing 350 degrees and target 10 degrees, it will treat the difference as being 350 - 10 - 360 = -20, and want the bomber to go 350+50; if insteadbomber 10 and target 30, then dif = -20 and no adjustment made
                    if math.abs(iCurAngleDif) > 180 then
                        if iCurAngleDif > 180 then
                            --iFacingDirection is too high so decrease the angle difference
                            iCurAngleDif = iCurAngleDif - 360
                        else --Curangledif must be < -180, so angletotarget is too high
                            iCurAngleDif = iCurAngleDif + 360
                        end
                    end


                    if iCurAngleDif < 0 then
                        iAngleAdjustToUse = iAngleAdjust
                    else iAngleAdjustToUse = -iAngleAdjust
                    end

                    if iCurTick == 1 then
                        M27Utilities.IssueTrackedClearCommands({oBomber})

                        iActualAngleToUse = iFacingDirection + iAngleAdjustToUse
                        tTempTarget = M27Utilities.MoveInDirection(oBomber:GetPosition(), iActualAngleToUse, iDistanceAwayToMove, true)
                        IssueMove({oBomber}, tTempTarget)
                        if bDebugMessages == true then LOG(sFunctionRef..': Just issued move order, iFacingDirection='..iFacingDirection..'; iCurANgleDif='..iCurAngleDif..'; iAngleAdjustToUse='..iAngleAdjustToUse..'; iActualAngleToUse='..iActualAngleToUse..'; angle from bomber to target='..M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oTarget:GetPosition())) end
                    elseif iCurTick >= iTicksBetweenOrders then iCurTick = 0
                    end

                    --Make the angle dif an absolute number for below tests
                    iCurAngleDif = math.abs(iCurAngleDif)

                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    WaitTicks(1)
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

                    if not(M27UnitInfo.IsUnitValid(oBomber)) or not(M27UnitInfo.IsUnitValid(oTarget)) then
                        if bDebugMessages == true then LOG(sFunctionRef..': either the bomber or target is no longer valid so aborting micro') end
                        break
                    elseif GetGameTimeSeconds() - iStartTime >= iReloadTime then
                        --Angle between 15-30, it appears that at short distances a greater angle might be acceptable
                        if bDebugMessages == true then LOG(sFunctionRef..': Bomb is ready to fire so will check every tick if our angle is close enough.  iCurAngleDif='..iCurAngleDif) end
                        if iCurAngleDif <= math.min(30, math.max(40 - iDistToTarget, 6)) then
                            if bDebugMessages == true then LOG(sFunctionRef..': have reached reload time so will try and attack as curangledif is <=28. iCurAngleDif='..iCurAngleDif..'; iDistToTarget='..iDistToTarget) end
                            break
                        else
                            --If we fire a bomb now, at a target straight in front but 10 away, will we hit it?
                            if iAOE > 2 then
                                tTempTarget = M27Utilities.MoveInDirection(oBomber:GetPosition(), iFacingDirection, 8.5, false)
                                if M27Utilities.GetDistanceBetweenPositions(tTempTarget, oTarget:GetPosition()) < (iAOE - 1 - iFiringRandomness * 1) then
                                    tGroundTarget = tTempTarget
                                    break
                                end
                            end
                        end
                    elseif bDebugMessages == true then LOG(sFunctionRef..': Bomb not loaded yet, will continue loop')
                    end

                end
                if M27UnitInfo.IsUnitValid(oBomber) then
                    oBomber[M27UnitInfo.refbSpecialMicroActive] = false
                    if M27UnitInfo.IsUnitValid(oTarget) then
                        --Below function should clear commands and then issue an attack
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Bomber '..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; Target '..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..'; Time to wait between orders='..iTicksBetweenOrders..'; Distance away to move to='..iDistanceAwayToMove..'; iAngleAdjust='..iAngleAdjust..'; Bomber facing direction='..M27UnitInfo.GetUnitFacingAngle(oBomber)..'; Angle from bomber to target='..M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oTarget:GetPosition())..'; Distance from bomber to target='..M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oTarget:GetPosition())..'; GameTime='..GetGameTimeSeconds())
                            LOG(sFunctionRef..': Have valid bomber and target so will issue an attack order for the bomber to attack the target, unless we have a ground target. tGroundTarget='..repru((tGroundTarget or {'nil'})))
                        end
                        if tGroundTarget then
                            if bDebugMessages == true then LOG(sFunctionRef..': Issuing attack order on ground='..repru(tGroundTarget)) end
                            oBomber[M27AirOverseer.reftGroundAttackLocation] = tGroundTarget
                            M27Utilities.IssueTrackedClearCommands({oBomber})
                            IssueAttack({oBomber}, tGroundTarget)
                        else
                            M27AirOverseer.IssueNewAttackToBomber(oBomber, oTarget, 1, true)
                        end
                    else
                        M27Utilities.IssueTrackedClearCommands({oBomber})
                        if bDebugMessages == true then LOG(sFunctionRef..': Cleared bomber'..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..' commands and will call delayed bomber target recheck') end
                        ForkThread(M27AirOverseer.DelayedBomberTargetRecheck, oBomber)
                    end
                end
            end
        end
    end
end

function ConsiderT2ArtiGroundFire(oArti)
    --Periodically checks for if T2 arti should try ground-firing
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ConsiderT2ArtiGroundFire'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local aiBrain = oArti:GetAIBrain()
    local iArtiDistToBase = M27Utilities.GetDistanceBetweenPositions(oArti:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])

    local iMaxRange = 0
    local iFiringRandomness
    local iAOE
    local iFiringFrequency
    local iMinArtiRange = 0

    local oBP = oArti:GetBlueprint()
    if oBP.Weapon then
        for iCurWeapon, oCurWeapon in oBP.Weapon do
            if (oCurWeapon.WeaponCategory == 'Missile' and not(oCurWeapon.DamageType == 'Nuke')) or oCurWeapon.WeaponCategory == 'Artillery' or oCurWeapon.WeaponCategory == 'Indirect Fire' then
                if oCurWeapon.MaxRadius > iMaxRange then
                    iMaxRange = oCurWeapon.MaxRadius
                    iFiringRandomness = oCurWeapon.FiringRandomness
                    iAOE = (oCurWeapon.DamageRadius or 1)
                    iFiringFrequency = 1 / oCurWeapon.RateOfFire
                    iMinArtiRange = (oCurWeapon.MinRadius or 0)
                end
            end
        end
    end
    local iArtiEffectiveRange = iMaxRange
    if iAOE >= 0.5 then
        iArtiEffectiveRange = iMaxRange + iAOE + iFiringRandomness * 7
    end

    local tNearbyPriorityUnits
    local iMaxSearchRange = iArtiEffectiveRange + iArtiDistToBase
    local iPriorityCategories = M27UnitInfo.refCategoryStructure - categories.TECH1 + M27UnitInfo.refCategoryIndirectT2Plus + M27UnitInfo.refCategoryMobileLandShield + M27UnitInfo.refCategorySniperBot + M27UnitInfo.refCategoryFatboy
    local oNearestPriorityUnit
    local tGroundFireTarget
    local bIssueAttack
    local iTimeToWait
    local bHavePriorityVisibleInRange
    local iNearestUnitDist
    local iCurDist
    if bDebugMessages == true then LOG(sFunctionRef..': Pre start of main loop for oArti='..oArti.UnitId..M27UnitInfo.GetUnitLifetimeCount(oArti)..'; iMaxSearchRange='..iMaxSearchRange..'; iEffectiveRange='..iArtiEffectiveRange..'; iMaxRange='..iMaxRange..'; iArtiDistToBase='..iArtiDistToBase) end
    while M27UnitInfo.IsUnitValid(oArti) do
        tGroundFireTarget = nil
        iTimeToWait = iFiringFrequency
        bHavePriorityVisibleInRange = false
        iNearestUnitDist = 10000
        if bDebugMessages == true then LOG(sFunctionRef..': iMaxSearchRange='..iMaxSearchRange..'; refiNearestEnemyT2PlusStructure='..aiBrain[M27Overseer.refiNearestEnemyT2PlusStructure]) end
        tNearbyPriorityUnits = {}
        if aiBrain[M27Overseer.refiNearestEnemyT2PlusStructure] <= iMaxSearchRange then
            tNearbyPriorityUnits = aiBrain:GetUnitsAroundPoint(iPriorityCategories, oArti:GetPosition(), iArtiEffectiveRange, 'Enemy')

            if M27Utilities.IsTableEmpty(tNearbyPriorityUnits) == false then
                oNearestPriorityUnit = M27Utilities.GetNearestUnit(tNearbyPriorityUnits, oArti:GetPosition())
                iNearestUnitDist = M27Utilities.GetDistanceBetweenPositions(oNearestPriorityUnit:GetPosition(), oArti:GetPosition())
                if bDebugMessages == true then LOG(sFunctionRef..': Nearest priority unit='..oNearestPriorityUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oNearestPriorityUnit)..'; Distance to arti='..M27Utilities.GetDistanceBetweenPositions(oNearestPriorityUnit:GetPosition(), oArti:GetPosition())..'; iMaxRange='..iMaxRange..'; Effective range='..iArtiEffectiveRange) end
                if iNearestUnitDist > iMaxRange then
                    --No priority units within our range so want to ground fire at the closest priority unit
                    tGroundFireTarget = M27Utilities.MoveInDirection(oArti:GetPosition(), M27Utilities.GetAngleFromAToB(oArti:GetPosition(), oNearestPriorityUnit:GetPosition()), iMaxRange - 0.05)
                    bIssueAttack = true
                else
                    bHavePriorityVisibleInRange = true
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': No nearby enemies so will keep checking') end
                iTimeToWait = 1
            end
        end
        if not(bHavePriorityVisibleInRange) then
            function ConsiderUnitForNewTarget(oUnit)
                iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oArti:GetPosition())
                if iCurDist <= iMaxSearchRange and iCurDist <= iNearestUnitDist then
                    if iNearestUnitDist > iMinArtiRange then
                        tGroundFireTarget = oUnit:GetPosition()
                        iNearestUnitDist = iCurDist
                    end
                end
            end
            --Do we have any units that have killed/damaged our units (so will have seen proejctiles and be able to estimate where they are)?
            if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyArtiToAvoid]) == false then
                for iUnit, oUnit in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyArtiToAvoid] do
                    ConsiderUnitForNewTarget(oUnit)
                end
            end
            if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftUnseenPD]) == false then
                for iUnit, oUnit in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftUnseenPD] do
                    ConsiderUnitForNewTarget(oUnit)
                end
            end

        end

        if bDebugMessages == true then LOG(sFunctionRef..': Finished checking if want ground fire target for unit '..oArti.UnitId..M27UnitInfo.GetUnitLifetimeCount(oArti)..'; tGroundFireTarget='..repru(tGroundFireTarget)) end
        if tGroundFireTarget then
            oArti[M27UnitInfo.refbSpecialMicroActive] = true
            M27Utilities.IssueTrackedClearCommands({oArti})
            IssueAttack({oArti}, tGroundFireTarget)
            if bDebugMessages == true then LOG(sFunctionRef..': Sent aggressive move order') end
        else
            if oArti[M27UnitInfo.refbSpecialMicroActive] == true then
                M27Utilities.IssueTrackedClearCommands({oArti})
                oArti[M27UnitInfo.refbSpecialMicroActive] = false
            end
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitSeconds(iTimeToWait)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    end
end

function FocusDownTarget(oUnit, oTarget)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'FocusDownTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if M27UnitInfo.IsUnitValid(oUnit) and M27UnitInfo.IsUnitValid(oTarget) then


        local sFocusDownTargetActive = 'M27MicroFocusDownTargetActive' --against unit, true if are focusing down the unit
        if not(oUnit[sFocusDownTargetActive]) then
            if bDebugMessages == true then LOG(sFunctionRef..': Time='..GetGameTimeSeconds()..'; will get unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to focus down target '..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)) end
            oUnit[sFocusDownTargetActive] = true
            oUnit[M27UnitInfo.refbSpecialMicroActive] = true
            local iReloadRate = 5 --default; will hard code exceptions as cant be bothered to figure out code
            if EntityCategoryContains(M27UnitInfo.refCategoryDestroyer * categories.AEON, oUnit.UnitId) then
                iReloadRate = 7 --allows time for shot to hit
            elseif EntityCategoryContains(M27UnitInfo.refCategoryBattleship * categories.UEF, oUnit.UnitId) then
                iReloadRate = 20
            elseif EntityCategoryContains(M27UnitInfo.refCategoryBattleship, oUnit.UnitId) then
                iReloadRate = 6
            end

            if not(oUnit[M27PlatoonUtilities.refiLastOrderType] == M27PlatoonUtilities.refiOrderIssueAttack) or not(oUnit[M27UnitInfo.refoLastOrderUnitTarget] == oTarget) then
                --bDebugMessages = true if bDebugMessages == true then LOG('Repr of oTarget='..reprs(oTarget)..'; repr of oUnit='..reprs(oUnit)..'; Is unit valid(oUnit)='..tostring(M27UnitInfo.IsUnitValid(oUnit))..'; Is unit valid(oTarget)='..tostring(M27UnitInfo.IsUnitValid(oTarget))) end
                M27Utilities.IssueTrackedClearCommands({oUnit})
                IssueAttack({oUnit}, oTarget)
                oUnit[M27PlatoonUtilities.refiLastOrderType] = M27PlatoonUtilities.refiOrderIssueAttack
                oUnit[M27UnitInfo.refoLastOrderUnitTarget] = oTarget
            end

            while M27UnitInfo.IsUnitValid(oUnit) and M27UnitInfo.IsUnitValid(oTarget) do
                if oUnit[M27UnitInfo.refbRecentlyDealtDamage] or (iReloadRate >= 5 and GetGameTimeSeconds() - oUnit[M27UnitInfo.refiGameTimeDamageLastDealt] < iReloadRate) then
                    --Keep firing
                else
                    break
                end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitSeconds(1)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            end
            if M27UnitInfo.IsUnitValid(oUnit) then
                oUnit[sFocusDownTargetActive] = false
                oUnit[M27UnitInfo.refbSpecialMicroActive] = false
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RunFromNuke(oUnit, oSML)
    --Checks if is a nearby SMD and if so have oUnit run towards it
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RunFromNuke'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    local aiBrain = oUnit:GetAIBrain()
    if aiBrain.M27AI then
        local tNearbySMD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategorySMD, oUnit:GetPosition(), 180, 'Ally')
        if bDebugMessages == true then LOG(sFunctionRef..': Time='..GetGameTimeSeconds()..'; oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Brani='..aiBrain.Nickname..'; Is tNearbySMD empty='..tostring(M27Utilities.IsTableEmpty(tNearbySMD))) end
        if M27Utilities.IsTableEmpty(tNearbySMD) == false then
            local oNearestLoadedSMD
            local iClosestLoadedSMD = 100000
            local oNearestUnloadedSMD
            local iClosestUnloadedSMD = 100000
            local iCurDist
            local bLoaded
            for iSMD, oSMD in tNearbySMD do
                if oSMD:GetFractionComplete() >= 1 then
                    bLoaded = true
                    iCurDist = M27Utilities.GetDistanceBetweenPositions(oSMD:GetPosition(), oUnit:GetPosition())
                    if oSMD.GetTacticalSiloAmmoCount and oSMD:GetTacticalSiloAmmoCount() < 1 and not (oSMD[M27EngineerOverseer.refbMissileRecentlyBuilt]) then
                        bLoaded = false
                    end
                    if bLoaded then
                        if iCurDist < iClosestLoadedSMD then
                            oNearestLoadedSMD = oSMD
                            iClosestLoadedSMD = iCurDist
                        end
                    else
                        if iCurDist < iClosestUnloadedSMD then
                            oNearestUnloadedSMD = oSMD
                            iClosestUnloadedSMD = iCurDist
                        end
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Finished considering oSMD='..oSMD.UnitId..M27UnitInfo.GetUnitLifetimeCount(oSMD)..'; iCurDist='..(iCurDist or 'nil')..'; Fraction complete='..oSMD:GetFractionComplete()..'; iClosestLoadedSMD='..(iClosestLoadedSMD or 'nil')..'; iClosestUnloadedSMD='..(iClosestUnloadedSMD or 'nil')..'; bLoaded='..tostring(bLoaded or false)) end
            end
            if oNearestLoadedSMD or oNearestUnloadedSMD then
                if bDebugMessages == true then LOG(sFunctionRef..': Will move towards closest SMD unless it is too close, math.min(iClosestLoadedSMD, iClosestUnloadedSMD)='..math.min(iClosestLoadedSMD, iClosestUnloadedSMD)) end
                if math.min(iClosestLoadedSMD, iClosestUnloadedSMD) >= 35 then --Arent that close to SMD so want to move closer
                    local iDistFromNuke = M27Utilities.GetDistanceBetweenPositions(oSML:GetPosition(), oUnit:GetPosition())
                    local iTimeToRun = 13 + iDistFromNuke / 40 --approximation
                    local tSMDToRunTo = (oNearestLoadedSMD or oNearestUnloadedSMD):GetPosition()
                    M27Utilities.IssueTrackedClearCommands({oUnit})
                    IssueMove({oUnit}, tSMDToRunTo)
                    TrackTemporaryUnitMicro(oUnit, iTimeToRun)
                    if bDebugMessages == true then LOG(sFunctionRef..': Told unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to run towards the SMD '..(oNearestLoadedSMD or oNearestUnloadedSMD).UnitId..M27UnitInfo.GetUnitLifetimeCount((oNearestLoadedSMD or oNearestUnloadedSMD))) end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end
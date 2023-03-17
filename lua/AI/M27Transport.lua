local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Team = import('/mods/M27AI/lua/AI/M27Team.lua')


--reftTimeOfTransportLastLocationAttempt = 'M27TransportPrevTargetTime' --[x] = Location ref of previous target, returns gametime that we attempted it as a target
reftTransportsWaitingForEngi = 'M27TransportsWaitingForENgi' --against aibrain, each entry is a transport unit
refiEngineersWantedForTransports = 'M27TransportsEngineersWanted'
reftTransportsAssignedByPlateauGroup = 'M27TransportAssignedByPlateauGroup' --[x] = plateau segment group; [y] = cycles through each entry, returns transport unit assigned
reftEngineersWaitingForTransport = 'M27TransportEngineersWaiting' --key is the unique engineer count; returns engineer object; engineer will have the transport it wants assigned as a variable to the engineer

--Local variables assigned to a unit or transport
refiAssignedPlateau = 'M27TransportAssignedPlateau' --Used by transports to record the plateau they're currently assigned to
reftPlateauNearestMex = 'M27TransportNearestMexTarget' --Assigned to transport
refoTransportToLoadOnto = 'M27TransportWanted' --local variable assigned to an engineer object
reftUnitsToldToLoadOntoTransport = 'M27TransportUnitsToldToLoad' --Recorded on a transport to keep track of units told to load onto it
reftUnitsLoadedOntoTransport = 'M27TransportUnitsLoadedOntoTransport' --Engineers successfully loaded onto a transport
refiUnitsLoaded = 'M27TransportEngisLoaded' --Number of engineers successfully loaded onto transport
refiMaxEngisWanted = 'M27TransportEngisWanted' --max number of engineers a transport wants
refiWaitingForEngiCount = 'M27TransportWaitingForEngiCount' --Will increase by 1 for each cycle that transport is near base and engi and waiting to be loaded
refbMoreUnitsWanted = 'M27TransportMoreUnitsWanted' --against transport, true if when we last loaded a unit we wanted more units before leaving (used to stop the transport unloading its units)

refiTimeSinceLastHadAvailableTransport = 'M27TransportTimeSinceLastHadTransport' --Gametimeseconds that we last had a transport to consider giving orders to
refiTimeSinceFirstInactive = 'M27TransportTimeSincFirstInactive' --Against transport; gives gametimeseconds; if unit state suggests not idle then this gets reset
reftLocationWhenFirstInactive = 'M27TransportLocationWhenFirstInactive' --against transport

function UpdateTransportForLoadedUnit(oUnitJustLoaded, oTransport)
    --Called when the event for a unit being loaded onto a transport is triggered
    --Updates tracking variables, and if the transport is full then sends it to the target
    local sFunctionRef = 'UpdateTransportForLoadedUnit'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --if oTransport:GetAIBrain():GetArmyIndex() == 5 then bDebugMessages = true end
    if bDebugMessages == true then LOG(sFunctionRef..': oUnitJustLoaded='..oUnitJustLoaded.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitJustLoaded)..'; Is unit valid='..tostring(M27UnitInfo.IsUnitValid(oUnitJustLoaded))) end

    oUnitJustLoaded[refoTransportToLoadOnto] = nil
    oUnitJustLoaded[M27UnitInfo.refbSpecialMicroActive] = false
    if M27UnitInfo.IsUnitValid(oTransport) then
        if not(oTransport[reftUnitsToldToLoadOntoTransport]) then oTransport[reftUnitsToldToLoadOntoTransport] = {} end

        oTransport[reftUnitsToldToLoadOntoTransport][oUnitJustLoaded.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitJustLoaded)] = nil
        oTransport[refiUnitsLoaded] = (oTransport[refiUnitsLoaded] or 0) + 1
        if M27Utilities.IsTableEmpty(oTransport[reftUnitsToldToLoadOntoTransport]) then
            oTransport[M27UnitInfo.refbSpecialMicroActive] = false
        end
        if not(oTransport[reftUnitsLoadedOntoTransport]) then oTransport[reftUnitsLoadedOntoTransport] = {} end


        --Is the transport full?
        local bSendTransportToTarget = false
        local iMaxTechLevel = 1
        if M27UnitInfo.IsUnitValid(oUnitJustLoaded) then iMaxTechLevel = math.max(iMaxTechLevel, M27UnitInfo.GetUnitTechLevel(oUnitJustLoaded)) end
        local iCurTechLevel
        local iEngisToBeLoaded = 0
        local aiBrain = oTransport:GetAIBrain()
        if bDebugMessages == true then LOG(sFunctionRef..': Is table of units told to load onto transport empty='..tostring(M27Utilities.IsTableEmpty(oTransport[reftUnitsToldToLoadOntoTransport]))) end
        if M27Utilities.IsTableEmpty(oTransport[reftUnitsToldToLoadOntoTransport]) == false then
            for iEngi, oEngi in oTransport[reftUnitsToldToLoadOntoTransport] do
                if bDebugMessages == true then LOG(sFunctionRef..': iEngi='..iEngi..'; oEngi is valid='..tostring(M27UnitInfo.IsUnitValid(oEngi))) end
                if M27UnitInfo.IsUnitValid(oEngi) then
                    iEngisToBeLoaded = iEngisToBeLoaded + 1
                    iCurTechLevel = M27UnitInfo.GetUnitTechLevel(oEngi)
                    if iCurTechLevel > iMaxTechLevel then iMaxTechLevel = iCurTechLevel end
                    if bDebugMessages == true then LOG(sFunctionRef..': oEngi='..oEngi.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi)..'; iCurTechLevel='..iCurTechLevel..'; iMaxTechLevel='..iMaxTechLevel) end
                else
                    oTransport[reftUnitsToldToLoadOntoTransport][iEngi] = nil
                end
            end
        end
        if iMaxTechLevel < 3 and M27Utilities.IsTableEmpty(oTransport[reftUnitsLoadedOntoTransport]) == false then
            for iEngi, oEngi in oTransport[reftUnitsToldToLoadOntoTransport] do
                if bDebugMessages == true then LOG(sFunctionRef..': iEngi='..iEngi..'; oEngi is valid='..tostring(M27UnitInfo.IsUnitValid(oEngi))) end
                if M27UnitInfo.IsUnitValid(oEngi) then
                    iCurTechLevel = M27UnitInfo.GetUnitTechLevel(oEngi)
                    if iCurTechLevel > iMaxTechLevel then iMaxTechLevel = iCurTechLevel end
                    if bDebugMessages == true then LOG(sFunctionRef..': oEngi='..oEngi.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi)..'; iCurTechLevel='..iCurTechLevel..'; iMaxTechLevel='..iMaxTechLevel) end
                else
                    oTransport[reftUnitsToldToLoadOntoTransport][iEngi] = nil
                end
            end
        end
        if iEngisToBeLoaded == 0 then iMaxTechLevel = math.max(iMaxTechLevel, aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]) end

        oTransport[reftUnitsLoadedOntoTransport][oUnitJustLoaded.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitJustLoaded)] = oUnitJustLoaded

        local iTransportCapacity = M27UnitInfo.GetTransportMaxCapacity(oTransport, iMaxTechLevel)
        if bDebugMessages == true then LOG(sFunctionRef..': iMaxTechLevel='..iMaxTechLevel..'; iTransportCapacity='..iTransportCapacity..'; oTransport[refiUnitsLoaded]='..(oTransport[refiUnitsLoaded] or 'nil')..'; oTransport[refiMaxEngisWanted]='..(oTransport[refiMaxEngisWanted] or 'nil')) end
        if iTransportCapacity <= oTransport[refiUnitsLoaded] or oTransport[refiUnitsLoaded] >= oTransport[refiMaxEngisWanted] or (oTransport[refiUnitsLoaded] >= oTransport[refiMaxEngisWanted] * 0.7 and iEngisToBeLoaded == 0) then
            bSendTransportToTarget = true
        end

        if bSendTransportToTarget then
            ForkThread(SendTransportToPlateau, aiBrain, oTransport)
        else
            oTransport[refbMoreUnitsWanted] = true
        end

        oTransport[reftLocationWhenFirstInactive] = nil
        oTransport[refiTimeSinceFirstInactive] = nil
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordUnitLoadingOntoTransport(oUnit, oTransport)
    local sFunctionRef = 'RecordUnitLoadingOntoTransport'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if oTransport:GetAIBrain():GetArmyIndex() == 2 then bDebugMessages = true end
    oUnit[refoTransportToLoadOnto] = oTransport
    if M27Utilities.IsTableEmpty(oTransport[reftUnitsToldToLoadOntoTransport]) then oTransport[reftUnitsToldToLoadOntoTransport] = {} end
    oTransport[reftUnitsToldToLoadOntoTransport][oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)] = oUnit
    if bDebugMessages == true then LOG(sFunctionRef..': oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; oTransport='..oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)) end
    oTransport[reftLocationWhenFirstInactive] = nil
    oTransport[refiTimeSinceFirstInactive] = nil
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function LoadEngineerOnTransport(aiBrain, oEngineer, oTransport)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'LoadEngineerOnTransport'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if oTransport:GetAIBrain():GetArmyIndex() == 2 then bDebugMessages = true end

    if bDebugMessages == true then LOG(sFunctionRef..': Engineer='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; Unit state='..M27Logic.GetUnitState(oEngineer)..'; Transport='..oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)..'; Unit state='..M27Logic.GetUnitState(oTransport)..'; oTransport[M27UnitInfo.refbSpecialMicroActive]='..tostring(oTransport[M27UnitInfo.refbSpecialMicroActive] or false)) end

    if oTransport[M27UnitInfo.refbSpecialMicroActive] then
        aiBrain[reftEngineersWaitingForTransport][M27EngineerOverseer.GetEngineerUniqueCount(oEngineer)] = oEngineer
        oEngineer[refoTransportToLoadOnto] = oTransport
    else
        M27Utilities.IssueTrackedClearCommands({oEngineer})
        M27Utilities.IssueTrackedClearCommands({oTransport})
        IssueTransportLoad({oEngineer}, oTransport)
        oEngineer[M27UnitInfo.refbSpecialMicroActive] = true
        oTransport[M27UnitInfo.refbSpecialMicroActive] = true
        RecordUnitLoadingOntoTransport(oEngineer, oTransport)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function AssignTransportToPlateau(aiBrain, oTransport, iPlateauGroup, iMaxEngisWanted)
    local sFunctionRef = 'AssignTransportToPlateau'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --if aiBrain:GetArmyIndex() == 5 then bDebugMessages = true end

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code for ai '..aiBrain.Nickname..', assigning transport '..oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)..' to iPlateauGroup '..iPlateauGroup..'; iMaxEngisWanted='..iMaxEngisWanted) end

    if iMaxEngisWanted > 0 then
        aiBrain[reftTransportsWaitingForEngi][oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)] = oTransport
    end
    oTransport[refiAssignedPlateau] = iPlateauGroup
    oTransport[reftPlateauNearestMex] = aiBrain[M27MapInfo.reftPlateausOfInterest][iPlateauGroup]

    if not(aiBrain[reftTransportsAssignedByPlateauGroup][iPlateauGroup]) then aiBrain[reftTransportsAssignedByPlateauGroup][iPlateauGroup] = {} end
    aiBrain[reftTransportsAssignedByPlateauGroup][iPlateauGroup][oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)] = oTransport
    oTransport[refiMaxEngisWanted] = iMaxEngisWanted
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ClearTransportTrackers(aiBrain, oTransport)
    local sFunctionRef = 'ClearTransportTrackers'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if aiBrain:GetArmyIndex() == 3 then bDebugMessages = true end


    if aiBrain[reftTransportsAssignedByPlateauGroup][oTransport[refiAssignedPlateau]] then
        if bDebugMessages == true then LOG(sFunctionRef..': ai='..aiBrain.Nickname..'; About to clear any tracking for the transport '..oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)) end
        aiBrain[reftTransportsAssignedByPlateauGroup][oTransport[refiAssignedPlateau]][oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)] = nil
    end
    aiBrain[reftTransportsWaitingForEngi][oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)] = nil
    oTransport[refiAssignedPlateau] = nil
    oTransport[refiMaxEngisWanted] = 0
    oTransport[refbMoreUnitsWanted] = false

    if bDebugMessages == true then LOG(sFunctionRef..': Cleared tracking for oTransport '..oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)) end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function SendTransportToPlateau(aiBrain, oTransport)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'SendTransportToPlateau'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if oTransport:GetAIBrain():GetArmyIndex() == 1 then bDebugMessages = true end
    --Check if target still safe and if not switches to an alternative target if there's a better one
    if bDebugMessages == true then
        LOG(sFunctionRef..': Start of code at time='..GetGameTimeSeconds()..', will update plateaus that we want to expand to. oTransport='..oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)..'; oTransport[refiAssignedPlateau]='..(oTransport[refiAssignedPlateau] or 'nil')..'; Units loaded onto oTransport='..(oTransport[refiUnitsLoaded] or 'nil'))
    end
    M27MapInfo.UpdatePlateausToExpandTo(aiBrain, true, false, oTransport)

    if bDebugMessages == true then LOG(sFunctionRef..': About to check if current assigned plateau for the transport is still the best one to expand to.  oTransport[refiAssignedPlateau]='..(oTransport[refiAssignedPlateau] or 'nil')..'; Is PlateauOfInterst table for this empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftPlateausOfInterest][oTransport[refiAssignedPlateau]]))) end
    if M27Utilities.IsTableEmpty( aiBrain[M27MapInfo.reftPlateausOfInterest]) == false then
        local iCurDist
        local iNearestDist = 10000
        local iNearestPathingGroup
        for iPathingGroup, tNearestMex in aiBrain[M27MapInfo.reftPlateausOfInterest] do
            iCurDist = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tNearestMex)
            if bDebugMessages == true then LOG(sFunctionRef..': Considering plateaus of interest, iPathingGroup='..iPathingGroup..'; iNearestDist='..iNearestDist..'; iCurDist='..iCurDist..'; tNearestMex='..repru(tNearestMex)) end
            if iCurDist < iNearestDist then
                iNearestDist = iCurDist
                iNearestPathingGroup = iPathingGroup
            end
        end
        if not(oTransport[refiAssignedPlateau] == iNearestPathingGroup) then
            ClearTransportTrackers(aiBrain, oTransport)
            if bDebugMessages == true then LOG(sFunctionRef..': About to assign oTransport '..oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)..' to iNearestPathingGroup='..(iNearestPathingGroup or 'nil')) end
            AssignTransportToPlateau(aiBrain, oTransport, iNearestPathingGroup, 0)
        end
    end

    if not(oTransport[reftPlateauNearestMex]) then
        if bDebugMessages == true then LOG(sFunctionRef..': No longerh ave a plateau we want to send transport to, so will have it land engineers at its current position') end
        oTransport[reftPlateauNearestMex] = {oTransport:GetPosition()[1], oTransport:GetPosition()[2], oTransport:GetPosition()[3]}
    end

    --Remove transport from list of transports waiting for engineers
    aiBrain[reftTransportsWaitingForEngi][oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)] = nil
    oTransport[refiMaxEngisWanted] = 0

    --Tell transport to unload engineers at the target
    if bDebugMessages == true then LOG(sFunctionRef..': Setting transport '..oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)..' to have no activem icro') end
    oTransport[M27UnitInfo.refbSpecialMicroActive] = false
    oTransport[M27AirOverseer.refbOnAssignment] = true

    IssueTransportUnload({oTransport}, oTransport[reftPlateauNearestMex])
    M27Team.tTeamData[aiBrain.M27Team][M27Team.reftTimeOfTransportLastLocationAttempt][M27Utilities.ConvertLocationToReference(oTransport[reftPlateauNearestMex])] = GetGameTimeSeconds()
    if bDebugMessages == true then LOG(sFunctionRef..': Just told transport '..oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)..' owned by '..oTransport:GetAIBrain().Nickname..' to go to a plateau, oTransport[refiAssignedPlateau]='..(oTransport[refiAssignedPlateau] or 'nil')..'; will go to the mex with location '..repru(oTransport[reftPlateauNearestMex])..'; Brain start position='..repru(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; Dist between start position and mex='..M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oTransport[reftPlateauNearestMex])) end

    oTransport[reftLocationWhenFirstInactive] = nil
    oTransport[refiTimeSinceFirstInactive] = nil
    oTransport[refbMoreUnitsWanted] = false

    --Remove transport from list of available transports if it is in such a list
    if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableTransports]) == false then
        for iUnit, oUnit in aiBrain[M27AirOverseer.reftAvailableTransports] do
            if oUnit == oTransport then
                table.remove(aiBrain[M27AirOverseer.reftAvailableTransports], iUnit)
                break
            end
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function TransportManager(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'TransportManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if aiBrain:GetArmyIndex() == 3 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryTransport) > 0 then bDebugMessages = true end

    --Called via forkthread from airoverseer after identifying available transports

    --First get the closest plateau to our base, and work out how many engineers we would want to claim it

    local iAvailableTransports = 0
    local iTransportsWaitingForEngis = 0
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, is table of avaialble transports empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftPlateausOfInterest]))..'; Is table of plateaus of interest empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftPlateausOfInterest]))..'; Plateau group of base='..aiBrain[M27MapInfo.refiOurBasePlateauGroup]) end
    if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableTransports]) == false then
        aiBrain[refiTimeSinceLastHadAvailableTransport] = GetGameTimeSeconds()
        for iUnit, oUnit in aiBrain[M27AirOverseer.reftAvailableTransports] do
            iAvailableTransports = iAvailableTransports + 1
        end
    end
    local iEngineersInWaitingTransports = 0
    if M27Utilities.IsTableEmpty(aiBrain[reftTransportsWaitingForEngi]) == false then
        for iUnit, oUnit in aiBrain[reftTransportsWaitingForEngi] do
            if M27Utilities.IsTableEmpty(oUnit[reftUnitsToldToLoadOntoTransport]) then
                oUnit[M27UnitInfo.refbSpecialMicroActive] = false
                if bDebugMessages == true then LOG(sFunctionRef..': No units told to load onto transport so setting transport '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to have no activem icro') end
            end
            if M27UnitInfo.IsUnitValid(oUnit) and M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftPlateausOfInterest]) == false then

                iTransportsWaitingForEngis = iTransportsWaitingForEngis + 1
                iEngineersInWaitingTransports = iEngineersInWaitingTransports + (oUnit[refiUnitsLoaded] or 0)
                if bDebugMessages == true then LOG(sFunctionRef..': Recording transports waiting for negis, transport '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' has '..(oUnit[refiUnitsLoaded] or 'nil')..' Engineers loaded') end
            else
                --Remove from table and abort (will come back to for next cycle)
                aiBrain[reftTransportsWaitingForEngi][iUnit] = nil
                break
            end
        end
    end
    if iAvailableTransports > 0 then
        --Force refresh of plateaus so we have an up to date list
        M27MapInfo.UpdatePlateausToExpandTo(aiBrain, true)
    else M27MapInfo.UpdatePlateausToExpandTo(aiBrain, false)
    end

    --Get the closest plateau
    local iMaxEngisWantedForPlateau = 0
    local iPlateauCount = 0

    if bDebugMessages == true then LOG(sFunctionRef..': iAvailableTransports='..iAvailableTransports..'; iTransportsWaitingForEngis='..iTransportsWaitingForEngis..'; Is table of plateaus of interest empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftPlateausOfInterest]))) end
    if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftPlateausOfInterest]) == false then

        --Decide on the plateau to expand to - factor in both distance and number of mexes


        --Get the closest plateau to our base
        local iBestPlateauGroup
        --local iClosestPlateauDistance = 100000
        local iCurDist
        local iCurPriority
        local iBestPriority = -1000

        local iDistToMid = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.5
        local iDistancePriorityFactor = -3 / iDistToMid

        for iPathingGroup, tNearestMex in aiBrain[M27MapInfo.reftPlateausOfInterest] do
            iPlateauCount = iPlateauCount + 1
            iCurDist = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tNearestMex)
            iCurPriority = M27MapInfo.tAllPlateausWithMexes[iPathingGroup][M27MapInfo.subrefPlateauTotalMexCount] + iCurDist * iDistancePriorityFactor
            if M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tNearestMex, false) <= iDistToMid then iCurPriority = iCurPriority + 3 end
            if bDebugMessages == true then LOG(sFunctionRef..': Considering plateau priority for plateau group '..iPathingGroup..'; iCurDist='..iCurDist..'; Total mex count='..M27MapInfo.tAllPlateausWithMexes[iPathingGroup][M27MapInfo.subrefPlateauTotalMexCount]..'; iDistancePriorityFactor='..iDistancePriorityFactor..'; iDistToMid='..iDistToMid..'; Mod distance from start='..M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tNearestMex, false)..'; iCurPriority='..iCurPriority..'; tNearestMex='..repru(tNearestMex)) end
            if iCurPriority > iBestPriority then
                iBestPlateauGroup = iPathingGroup
                iBestPriority = iCurPriority
            end
        end
        iMaxEngisWantedForPlateau = math.min(6,math.max(1, M27MapInfo.tAllPlateausWithMexes[iBestPlateauGroup][M27MapInfo.subrefPlateauTotalMexCount] - 1))

        if bDebugMessages == true then LOG(sFunctionRef..': iBestPriority='..iBestPriority..'; iBestPlateauGroup='..iBestPlateauGroup..'; iMaxEngisWantedForPlateau='..iMaxEngisWantedForPlateau) end

        --Assign transport to go to this plateau - find the one closest to our base
        if iAvailableTransports > 0 then
            local iClosestTransportDistance = 10000
            local oTransportToAssign
            for iUnit, oUnit in aiBrain[M27AirOverseer.reftAvailableTransports] do
                iCurDist = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition())
                if iCurDist < iClosestTransportDistance then
                    iClosestTransportDistance = iCurDist
                    oTransportToAssign = oUnit
                end
            end

            --Assign transport to this plateau
            if bDebugMessages == true then LOG(sFunctionRef..': Assigning transport '..oTransportToAssign.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransportToAssign)..' to the plateau group '..(iBestPlateauGroup or 'nil')) end
            AssignTransportToPlateau(aiBrain, oTransportToAssign, iBestPlateauGroup, iMaxEngisWantedForPlateau)
        end
    end

    --Set how many engineers we want for transports
    --Do we have an air fac yet that is able to build transports? assume no if no AirAA
    aiBrain[refiEngineersWantedForTransports] = 0

    if aiBrain[M27AirOverseer.refiOurMassInAirAA] == 0 then
        --Dont have air fac yet so no point trying to get engis for transports
        aiBrain[refiEngineersWantedForTransports] = 0
    else
        aiBrain[refiEngineersWantedForTransports] = iMaxEngisWantedForPlateau + math.max(0, math.min(iPlateauCount - 1, iAvailableTransports + iTransportsWaitingForEngis)) * 2 - iEngineersInWaitingTransports
    end
    --Exception - if we already have a transport waiting

    if iTransportsWaitingForEngis > 0 then

        aiBrain[refiEngineersWantedForTransports] = math.max(iTransportsWaitingForEngis * 2, aiBrain[refiEngineersWantedForTransports])
    end
    if bDebugMessages == true then LOG(sFunctionRef..': iTransportsWaitingForEngis='..iTransportsWaitingForEngis..'; aiBrain[refiEngineersWantedForTransports]='..aiBrain[refiEngineersWantedForTransports]..'; iAvailableTransports='..iAvailableTransports..'; iEngineersInWaitingTransports='..iEngineersInWaitingTransports) end


    --Send idle transports back to base (dont want to use air rally point since want them close to where engineers are liekly to be built)
    if iAvailableTransports > 0 then
        local tRallyPoint = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local tCurTarget
        local oNavigator
        local bSendToRallyPoint
        local bUnloadFirst
        for iUnit, oUnit in aiBrain[M27AirOverseer.reftAvailableTransports] do
            --Does the transport have any units loaded? If so then unload them
            if M27UnitInfo.IsUnitValid(oUnit) then --Redundancy

                bUnloadFirst = false
                if not(oUnit[refbMoreUnitsWanted]) then
                    if oUnit.GetCargo and M27Utilities.IsTableEmpty(oUnit:GetCargo()) == false then
                        bUnloadFirst = true
                    end
                end
                --[[if oUnit[refiUnitsLoaded] > 0 then
                    for iEngi, oEngi in oUnit[reftUnitsToldToLoadOntoTransport] do
                        if M27UnitInfo.IsUnitValid(oEngi) and oEngi:IsUnitState('Attached') then
                            bUnloadFirst = true
                            break
                        end
                    end
                end--]]
                if bDebugMessages == true then LOG(sFunctionRef..': Considering available transport '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; oUnit[refiUnitsLoaded]='..(oUnit[refiUnitsLoaded] or 0)..'; bUnloadFirst='..tostring(bUnloadFirst)) end

                if bUnloadFirst then
                    M27Utilities.IssueTrackedClearCommands({oUnit})
                    M27AirOverseer.ClearAirUnitAssignmentTrackers(aiBrain, oUnit, true)
                    oUnit[M27AirOverseer.refbOnAssignment] = true
                    IssueTransportUnload({oUnit}, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    if bDebugMessages == true then LOG(sFunctionRef..': Told transport to unload at the start position') end
                else
                    --Check if want to send the transport - e.g. in case we have changed the plateau we want to go to
                    local bSendTransportToPlateau = false
                    if (oUnit[refiUnitsLoaded] or 0) >= math.max(1, iMaxEngisWantedForPlateau) then
                        bSendTransportToPlateau = true
                        SendTransportToPlateau(aiBrain, oUnit)
                        if bDebugMessages == true then LOG(sFunctionRef..': Have sent transport '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to go to a plateau') end
                    end
                    if not(bSendTransportToPlateau) then


                        bSendToRallyPoint = false
                        if oUnit.GetNavigator then
                            oNavigator = oUnit:GetNavigator()
                            if oNavigator and oNavigator.GetCurrentTargetPos then
                                tCurTarget = oNavigator:GetCurrentTargetPos()
                                if M27Utilities.GetDistanceBetweenPositions(tCurTarget, tRallyPoint) >= 30 then
                                    bSendToRallyPoint = true
                                end
                            end
                        end

                        if bSendToRallyPoint then
                            M27Utilities.IssueTrackedClearCommands({oUnit})
                            M27AirOverseer.ClearAirUnitAssignmentTrackers(aiBrain, oUnit, true)
                            IssueMove({oUnit}, tRallyPoint)
                            if bDebugMessages == true then LOG(sFunctionRef..': Telling transport to return to rally point '..repru(tRallyPoint)) end
                        else
                            --Low fuel or health transport with no units?
                            if (oUnit[refiUnitsLoaded] or 0) == 0 and (M27UnitInfo.GetUnitHealthPercent(oUnit) <= 0.35 or oUnit:GetFuelRatio() <= 0.2) then
                                if not(oUnit.GetCargo) or M27Utilities.IsTableEmpty(oUnit:GetCargo()) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' is low health with no cargo, Rally point='..repru(tRallyPoint)..'; Unit position='..repru(oUnit:GetPosition())..'; Start position='..repru(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) end
                                    if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tRallyPoint) <= 30 or M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 60 then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Will kill transport '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' as it has low fuel or health') end
                                        oUnit:Kill()
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    --Load engineers in a group onto transport
    if bDebugMessages == true then LOG(sFunctionRef..': Is the table of engineers waiting for transport empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineersWaitingForTransport]))) end
    if M27Utilities.IsTableEmpty(aiBrain[reftEngineersWaitingForTransport]) == false then
        local tEngisByTransportRef = {}
        local oTransportWanted
        for iEngi, oEngi in aiBrain[reftEngineersWaitingForTransport] do
            if not(M27UnitInfo.IsUnitValid(oEngi)) or not(oEngi[M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionLoadOnTransport) then
                aiBrain[reftEngineersWaitingForTransport][iEngi] = nil
            else
                if not(M27UnitInfo.IsUnitValid(oEngi[refoTransportToLoadOnto])) then
                    M27Utilities.IssueTrackedClearCommands({oEngi})
                    aiBrain[reftEngineersWaitingForTransport][iEngi] = nil
                    M27EngineerOverseer.ClearEngineerActionTrackers(aiBrain, oEngi, true)
                else
                    if not(tEngisByTransportRef[oEngi[refoTransportToLoadOnto].UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi[refoTransportToLoadOnto])]) then tEngisByTransportRef[oEngi[refoTransportToLoadOnto].UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi[refoTransportToLoadOnto])] = {} end
                    table.insert(tEngisByTransportRef[oEngi[refoTransportToLoadOnto].UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi[refoTransportToLoadOnto])], oEngi)
                end
            end
        end

        for iTransportRef, tEngiGroup in tEngisByTransportRef do
            oTransportWanted = tEngiGroup[1][refoTransportToLoadOnto]

            --Is the transport already at capacity? If so then clear the engineers
            local iTransportCapacity = M27UnitInfo.GetTransportMaxCapacity(oTransportWanted, M27UnitInfo.GetUnitTechLevel(tEngiGroup[1]))
            if bDebugMessages == true then LOG(sFunctionRef..': oTransportWanted='..oTransportWanted.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransportWanted)..'; iTransportCapacity='..iTransportCapacity..'; refiUnitsLoaded='..(oTransportWanted[refiUnitsLoaded] or 0)) end
            if oTransportWanted[refiUnitsLoaded] >= math.min(iTransportCapacity, oTransportWanted[refiMaxEngisWanted]) then
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Transport is already full so will clear all engineers wanting to load into the transport')
                    for iEngi, oEngi in tEngiGroup do
                        M27Utilities.IssueTrackedClearCommands({oEngi})
                        oEngi[refoTransportToLoadOnto] = nil
                        oEngi[refiAssignedPlateau] = nil
                        M27EngineerOverseer.ClearEngineerActionTrackers(aiBrain, oEngi)
                        if bDebugMessages == true then LOG(sFunctionRef..': Cleared trackers etc. for engineer '..oEngi.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi)) end
                    end
                end

            else
                if bDebugMessages == true then LOG(sFunctionRef..': iTransportRef='..iTransportRef..'; Is special micro active='..tostring(oTransportWanted[M27UnitInfo.refbSpecialMicroActive])) end
                if not(oTransportWanted[M27UnitInfo.refbSpecialMicroActive]) then
                    M27Utilities.IssueTrackedClearCommands(tEngiGroup)
                    M27Utilities.IssueTrackedClearCommands({oTransportWanted})
                    IssueTransportLoad(tEngiGroup, oTransportWanted)
                    oTransportWanted[M27UnitInfo.refbSpecialMicroActive] = true

                    if bDebugMessages == true then LOG(sFunctionRef..': Getting engineers to load onto transport '..oTransportWanted.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransportWanted)..'; Transport Special micro active='..tostring(oTransportWanted[M27UnitInfo.refbSpecialMicroActive] or false)) end
                    for iEngi, oEngi in tEngiGroup do
                        oEngi[M27UnitInfo.refbSpecialMicroActive] = true
                        RecordUnitLoadingOntoTransport(oEngi, oTransportWanted)
                        if bDebugMessages == true then LOG(sFunctionRef..': Sent order for oEngi '..oEngi.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi)..' to load onto transport '..oTransportWanted.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransportWanted)) end
                    end
                else
                    --Engineers have been told to load onto transport, however if we have been waiting for them to load for some time and the transport is near base, then want to retry
                    if bDebugMessages == true then LOG(sFunctionRef..': Special micro is active for the transport. if close to base will consider reissuing order. Dist to base='..M27Utilities.GetDistanceBetweenPositions(oTransportWanted:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) end
                    if M27Utilities.GetDistanceBetweenPositions(oTransportWanted:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 50 then
                        local bWaitingForEngi = true
                        for iEngi, oEngi in tEngiGroup do
                            if not(M27UnitInfo.IsUnitValid(oEngi)) or not(oEngi[M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionLoadOnTransport) then
                                tEngiGroup[iEngi] = nil
                            else
                                if M27Utilities.GetDistanceBetweenPositions(oTransportWanted:GetPosition(), oEngi:GetPosition()) >= 50 then
                                    bWaitingForEngi = false
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': bWaitingForEngi='..tostring(bWaitingForEngi)..'; WaitingCount='..(oTransportWanted[refiWaitingForEngiCount] or 0)..'; is table of engis empty='..tostring(M27Utilities.IsTableEmpty(tEngiGroup))) end
                        if bWaitingForEngi then
                            oTransportWanted[refiWaitingForEngiCount] = (oTransportWanted[refiWaitingForEngiCount] or 0) + 1
                            if oTransportWanted[refiWaitingForEngiCount] >= 30 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Will reset special micro flag, or if we have engis in engi group will reissue order to load') end
                                oTransportWanted[refiWaitingForEngiCount] = 0
                                if M27Utilities.IsTableEmpty(tEngiGroup) == false then
                                    M27Utilities.IssueTrackedClearCommands(tEngiGroup)
                                    M27Utilities.IssueTrackedClearCommands({oTransportWanted})
                                    IssueTransportLoad(tEngiGroup, oTransportWanted)
                                    oTransportWanted[M27UnitInfo.refbSpecialMicroActive] = true
                                    for iEngi, oEngi in tEngiGroup do
                                        RecordUnitLoadingOntoTransport(oEngi, oTransportWanted)
                                    end
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': No engi group so setting transport '..oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)..' to have no activem icro') end
                                    oTransportWanted[M27UnitInfo.refbSpecialMicroActive] = false
                                end
                            end
                        end
                    end
                end
            end
        end
    elseif bDebugMessages == true then LOG(sFunctionRef..': No engineers to load onto transport')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function TransportInitialisation(aiBrain)
    aiBrain[reftTransportsWaitingForEngi] = {}
    --aiBrain[reftTimeOfTransportLastLocationAttempt] = {}
    aiBrain[reftTransportsAssignedByPlateauGroup] = {}
    aiBrain[reftEngineersWaitingForTransport] = {}
end
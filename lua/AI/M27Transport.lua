local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')



reftTimeOfTransportLastLocationAttempt = 'M27TransportPrevTargetTime' --[x] = Location ref of previous target, returns gametime that we attempted it as a target
reftTransportsWaitingForEngi = 'M27TransportsWaitingForENgi' --each entry is a transport unit
refiEngineersWantedForTransports = 'M27TransportsEngineersWanted'
reftTransportsAssignedByPlateauGroup = 'M27TransportAssignedByPlateauGroup' --[x] = plateau segment group; [y] = cycles through each entry, returns transport unit assigned
reftEngineersWaitingForTransport = 'M27TransportEngineersWaiting' --key is the unique engineer count; returns engineer object; engineer will have the transport it wants assigned as a variable to the engineer

--Local variables assigned to a unit or transport
refiAssignedPlateau = 'M27TransportAssignedPlateau' --Used by transports to record the plateau they're currently assigned to
reftPlateauNearestMex = 'M27TransportNearestMexTarget' --Assigned to transport
refoTransportToLoadOnto = 'M27TransportWanted' --local variable assigned to an engineer object
reftUnitsToldToLoadOntoTransport = 'M27TransportUnitsToldToLoad' --Recorded on a transport to keep track of units told to load onto it
refiEngisLoaded = 'M27TransportEngisLoaded' --Number of engineers successfully loaded onto transport
refiMaxEngisWanted = 'M27TransportEngisWanted' --max number of engineers a transport wants

function UpdateTransportForLoadedUnit(oUnitJustLoaded, oTransport)
    --Called when the event for a unit being loaded onto a transport is triggered
    --Updates tracking variables, and if the transport is full then sends it to the target

    oUnitJustLoaded[refoTransportToLoadOnto] = nil
    oUnitJustLoaded[M27UnitInfo.refbSpecialMicroActive] = false
    oTransport[reftUnitsToldToLoadOntoTransport][oUnitJustLoaded.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitJustLoaded)] = nil
    oTransport[refiEngisLoaded] = (oTransport[refiEngisLoaded] or 0) + 1
    if M27Utilities.IsTableEmpty(oTransport[reftUnitsToldToLoadOntoTransport]) then
        oTransport[M27UnitInfo.refbSpecialMicroActive] = false
    end

    --Is the transport full?
    local bSendTransportToTarget = false
    local iMaxTechLevel = 1
    local iCurTechLevel
    local iEngisToBeLoaded = 0
    local aiBrain = oTransport:GetAIBrain()
    if M27Utilities.IsTableEmpty(oTransport[reftUnitsToldToLoadOntoTransport]) == false then
        for iEngi, oEngi in oTransport[reftUnitsToldToLoadOntoTransport] do
            if M27UnitInfo.IsUnitValid(oEngi) then
                iEngisToBeLoaded = iEngisToBeLoaded + 1
                iCurTechLevel = M27UnitInfo.GetUnitTechLevel(oEngi)
                if iCurTechLevel > iMaxTechLevel then iMaxTechLevel = iCurTechLevel end
            else
                oTransport[reftUnitsToldToLoadOntoTransport][iEngi] = nil
            end
        end
    end
    if iEngisToBeLoaded == 0 then iMaxTechLevel = aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] end

    local iTransportCapacity = M27UnitInfo.GetTransportMaxCapacity(oTransport, iMaxTechLevel)
    if iTransportCapacity <= oTransport[refiEngisLoaded] or oTransport[refiEngisLoaded] >= oTransport[refiMaxEngisWanted] or (oTransport[refiEngisLoaded] >= oTransport[refiMaxEngisWanted] * 0.7 and iEngisToBeLoaded == 0) then
        bSendTransportToTarget = true
    end

    if bSendTransportToTarget then
        ForkThread(SendTransportToPlateau, aiBrain, oTransport)
    end
end

function RecordUnitLoadingOntoTransport(oUnit, oTransport)
    oUnit[refoTransportToLoadOnto] = oTransport
    if not(oTransport[reftUnitsToldToLoadOntoTransport]) then oTransport[reftUnitsToldToLoadOntoTransport] = {} end
    oTransport[reftUnitsToldToLoadOntoTransport][oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)] = oUnit
end

function LoadEngineerOnTransport(aiBrain, oEngineer, oTransport)
    if oTransport[M27UnitInfo.refbSpecialMicroActive] then
        aiBrain[reftEngineersWaitingForTransport][M27EngineerOverseer.GetEngineerUniqueCount(oEngineer)] = oEngineer
        oEngineer[refoTransportToLoadOnto] = oTransport
    else
        IssueClearCommands({oEngineer})
        IssueClearCommands({oTransport})
        IssueTransportLoad({oEngineer}, oTransport)
        oEngineer[M27UnitInfo.refbSpecialMicroActive] = true
        oTransport[M27UnitInfo.refbSpecialMicroActive] = true
        RecordUnitLoadingOntoTransport(oEngineer, oTransport)
    end
end

function AssignTransportToPlateau(aiBrain, oTransport, iPlateauGroup, iMaxEngisWanted)
    if iMaxEngisWanted > 0 then
        aiBrain[reftTransportsWaitingForEngi][oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)] = oTransport
    end
    oTransport[refiAssignedPlateau] = iPlateauGroup
    oTransport[reftPlateauNearestMex] = aiBrain[M27MapInfo.reftPlateausOfInterest][iPlateauGroup]
    if not(aiBrain[reftTransportsAssignedByPlateauGroup][iPlateauGroup]) then aiBrain[reftTransportsAssignedByPlateauGroup][iPlateauGroup] = {} end
    aiBrain[reftTransportsAssignedByPlateauGroup][iPlateauGroup][oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)] = oTransport
    oTransport[refiMaxEngisWanted] = iMaxEngisWanted
end

function ClearTransportTrackers(aiBrain, oTransport)
    if aiBrain[reftTransportsAssignedByPlateauGroup][oTransport[refiAssignedPlateau]] then
        aiBrain[reftTransportsAssignedByPlateauGroup][oTransport[refiAssignedPlateau]][oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)] = nil
    end
    aiBrain[reftTransportsWaitingForEngi][oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)] = nil
    oTransport[refiAssignedPlateau] = nil
    oTransport[refiMaxEngisWanted] = 0
end

function SendTransportToPlateau(aiBrain, oTransport)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'SendTransportToPlateau'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Check if target still safe and if not switches to an alternative target if there's a better one
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, will update plateaus that we want to expand to. oTransport='..oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)) end
    M27MapInfo.UpdatePlateausToExpandTo(aiBrain, true)

    if bDebugMessages == true then LOG(sFunctionRef..': About to check if current assigned plateau for the transport is still one we want to expand to.  oTransport[refiAssignedPlateau]='..(oTransport[refiAssignedPlateau] or 'nil')..'; Is PlateauOfInterst table for this empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftPlateausOfInterest][oTransport[refiAssignedPlateau]]))) end
    if not(aiBrain[M27MapInfo.reftPlateausOfInterest][oTransport[refiAssignedPlateau]]) and M27Utilities.IsTableEmpty( aiBrain[M27MapInfo.reftPlateausOfInterest]) == false then
        --Current target isnt safe but we have a better one
        local iCurDist
        local iNearestDist = 10000
        local iNearestPathingGroup
        for iPathingGroup, tNearestMex in aiBrain[M27MapInfo.reftPlateausOfInterest] do
            iCurDist = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tNearestMex)
            if iCurDist < iNearestDist then
                iNearestDist = iCurDist
                iNearestPathingGroup = iPathingGroup
            end
        end
        ClearTransportTrackers(aiBrain, oTransport)
        AssignTransportToPlateau(aiBrain, oTransport, iNearestPathingGroup, 0)
    end

    --Remove transport from list of transports waiting for engineers
    aiBrain[reftTransportsWaitingForEngi][oTransport.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransport)] = nil
    oTransport[refiMaxEngisWanted] = 0

    --Tell transport to unload engineers at the target
    oTransport[M27UnitInfo.refbSpecialMicroActive] = false
    oTransport[M27AirOverseer.refbOnAssignment] = true

    IssueTransportUnload({oTransport}, oTransport[reftPlateauNearestMex])
    aiBrain[reftTimeOfTransportLastLocationAttempt][M27Utilities.ConvertLocationToReference(oTransport[reftPlateauNearestMex])] = GetGameTimeSeconds()
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function TransportManager(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'TransportManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Called via forkthread from airoverseer after identifying available transports

    --First get the closest plateau to our base, and work out how many engineers we would want to claim it

    local iAvailableTransports = 0
    local iTransportsWaitingForEngis = 0
    if M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftAvailableTransports]) == false then
        for iUnit, oUnit in aiBrain[M27AirOverseer.reftAvailableTransports] do
            iAvailableTransports = iAvailableTransports + 1
        end
    end
    if M27Utilities.IsTableEmpty(aiBrain[reftTransportsWaitingForEngi]) == false then
        for iUnit, oUnit in aiBrain[reftTransportsWaitingForEngi] do
            if M27UnitInfo.IsUnitValid(oUnit) then
                iTransportsWaitingForEngis = iTransportsWaitingForEngis + 1
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
        --Get the closest plateau to our base
        local iClosestPlateauGroup
        local iClosestPlateauDistance = 100000
        local iCurDist
        for iPathingGroup, tNearestMex in aiBrain[M27MapInfo.reftPlateausOfInterest] do
            iPlateauCount = iPlateauCount + 1
            iCurDist = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tNearestMex)
            if iCurDist < iClosestPlateauDistance then
                iClosestPlateauGroup = iPathingGroup
                iClosestPlateauDistance = iCurDist
            end
        end
        iMaxEngisWantedForPlateau = math.min(6,math.max(1, M27MapInfo.tAllPlateausWithMexes[iClosestPlateauGroup][M27MapInfo.subrefPlateauTotalMexCount] - 1))

        if bDebugMessages == true then LOG(sFunctionRef..': iClosestPlateauDistance='..iClosestPlateauDistance..'; iClosestPlateauGroup='..iClosestPlateauGroup..'; iMaxEngisWantedForPlateau='..iMaxEngisWantedForPlateau) end

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
            if bDebugMessages == true then LOG(sFunctionRef..': Assigning transport '..oTransportToAssign.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransportToAssign)..' to the plateau group '..iClosestPlateauGroup) end
            AssignTransportToPlateau(aiBrain, oTransportToAssign, iClosestPlateauGroup, iMaxEngisWantedForPlateau)
        end
    end

    --Set how many engineers we want for transports
    --Do we have an air fac yet that is able to build transports? assume no if no AirAA
    aiBrain[refiEngineersWantedForTransports] = 0

    if aiBrain[M27AirOverseer.refiOurMassInAirAA] == 0 then
        --Dont have air fac yet so no point trying to get engis for transports
        aiBrain[refiEngineersWantedForTransports] = 0
    else
        aiBrain[refiEngineersWantedForTransports] = iMaxEngisWantedForPlateau + math.max(0, math.min(iPlateauCount - 1, iAvailableTransports + iTransportsWaitingForEngis)) * 2
    end
    --Exception - if we already have a transport waiting
    if iTransportsWaitingForEngis > 0 then aiBrain[refiEngineersWantedForTransports] = math.min(iTransportsWaitingForEngis * 2, 4) end
    if bDebugMessages == true then LOG(sFunctionRef..': iTransportsWaitingForEngis='..iTransportsWaitingForEngis..'; aiBrain[refiEngineersWantedForTransports]='..aiBrain[refiEngineersWantedForTransports]) end


    --Send idle transports back to base (dont want to use air rally point since want them close to where engineers are liekly to be built)
    if iAvailableTransports > 0 then
        local tRallyPoint = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local tCurTarget
        local oNavigator
        local bSendToRallyPoint
        for iUnit, oUnit in aiBrain[M27AirOverseer.reftAvailableTransports] do
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
                IssueClearCommands({oUnit})
                M27AirOverseer.ClearAirUnitAssignmentTrackers(aiBrain, oUnit, true)
                IssueMove({oUnit}, tRallyPoint)
            end
        end
    end

    --Load engineers in a group onto transport
    if bDebugMessages == true then LOG(sFunctionRef..': Is the table of engineers waiting for transport empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineersWaitingForTransport]))) end
    if M27Utilities.IsTableEmpty(aiBrain[reftEngineersWaitingForTransport]) then
        local tEngisByTransportRef = {}
        local oTransportWanted
        for iEngi, oEngi in aiBrain[reftEngineersWaitingForTransport] do
            if not(M27UnitInfo.IsUnitValid(oEngi)) then
                aiBrain[reftEngineersWaitingForTransport] = nil
            else
                if not(M27UnitInfo.IsUnitValid(oEngi[refoTransportToLoadOnto])) then
                    IssueClearCommands({oEngi})
                    aiBrain[reftEngineersWaitingForTransport] = nil
                    M27EngineerOverseer.ClearEngineerActionTrackers(aiBrain, oEngi, true)
                else
                    if not(tEngisByTransportRef[oEngi[refoTransportToLoadOnto].UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi[refoTransportToLoadOnto])]) then tEngisByTransportRef[oEngi[refoTransportToLoadOnto].UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi[refoTransportToLoadOnto])] = {} end
                    table.insert(tEngisByTransportRef[oEngi[refoTransportToLoadOnto].UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi[refoTransportToLoadOnto])], oEngi)
                end
            end
        end

        for iTransportRef, tEngiGroup in tEngisByTransportRef do
            oTransportWanted = tEngiGroup[1][refoTransportToLoadOnto]
            if not(oTransportWanted.refbSpecialMicroActive) then
                IssueClearCommands(tEngiGroup)
                IssueClearCommands({oTransportWanted})
                IssueTransportLoad(tEngiGroup, oTransportWanted)
                oTransportWanted[M27UnitInfo.refbSpecialMicroActive] = true
                if bDebugMessages == true then LOG(sFunctionRef..': Getting engineers to load onto transport '..oTransportWanted.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTransportWanted)) end
                for iEngi, oEngi in tEngiGroup do
                    oEngi[M27UnitInfo.refbSpecialMicroActive] = true
                    RecordUnitLoadingOntoTransport(oEngi, oTransportWanted)
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function TransportInitialisation(aiBrain)
    aiBrain[reftTransportsWaitingForEngi] = {}
    aiBrain[reftTimeOfTransportLastLocationAttempt] = {}
    aiBrain[reftTransportsAssignedByPlateauGroup] = {}
    aiBrain[reftEngineersWaitingForTransport] = {}
end
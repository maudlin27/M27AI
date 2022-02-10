local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27utilities.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27FactoryOverseer = import('/mods/M27AI/lua/AI/M27FactoryOverseer.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27EconomyOverseer = import('/mods/M27AI/lua/AI/M27EconomyOverseer.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27PlatoonFormer = import('/mods/M27AI/lua/AI/M27PlatoonFormer.lua')


local refCategoryEngineer = M27UnitInfo.refCategoryEngineer
local refCategoryLandFactory = M27UnitInfo.refCategoryLandFactory
local refCategoryAirStaging = M27UnitInfo.refCategoryAirStaging
local refCategoryAirFactory = M27UnitInfo.refCategoryAirFactory


local refCategoryT1Mex = M27UnitInfo.refCategoryT1Mex
local refCategoryMex = M27UnitInfo.refCategoryMex
local refCategoryHydro = M27UnitInfo.refCategoryHydro
local refCategoryPower = M27UnitInfo.refCategoryPower
local refCategoryEnergyStorage = M27UnitInfo.refCategoryEnergyStorage

--Actions for engineers (dont have as local variables due to cap on how many local variables we can have)
refActionBuildMex = 1
refActionBuildHydro = 2
refActionReclaimArea = 3
refActionBuildPower = 4
refActionBuildLandFactory = 5
refActionBuildEnergyStorage = 6
refActionSpare = 7
refActionHasNearbyEnemies = 8
refActionUpgradeBuilding = 9
refActionBuildSecondPower = 10
refActionBuildAirStaging = 11
refActionBuildAirFactory = 12
refActionBuildSMD = 13
refActionBuildMassStorage = 14
refActionBuildT1Radar = 15
refActionBuildT2Radar = 16
refActionBuildT3Radar = 17
refActionAssistSMD = 18
refActionAssistAirFactory = 19
refActionBuildThirdPower = 20
refActionBuildLandExperimental = 21
refActionReclaimUnit = 22
refActionBuildT3MexOverT2 = 23
refActionUpgradeHQ = 24 --Assists an HQ with its upgrade
refActionReclaimTrees = 25
refActionBuildT1Sonar = 26
refActionBuildT2Sonar = 27
--NOTE: IF ADDING MORE ACTIONS, UPDATE THE ACTIONS IN THE POWER STALL MANAGER

--Build order related variables
refiBOInitialEngineersWanted = 'M27BOInitialEngineersWanted'
refiBOPreReclaimEngineersWanted = 'M27BOPreReclaimEngineersWanted'
refiBOPreSpareEngineersWanted = 'M27BOPreSpareEngineersWanted'
refiBOActiveSpareEngineers = 'M27ActiveSpareEngineers' --not the number we want to build, but the number we have

iEngineerEnemySearchRange = 40

--Tracking variables
--Engineer main tracking tables:
--local reftPrevEngineerAssignmentsByAction = 'M27EngineerPrevAssignmentsByAction' --Records all engineers. [x][y]; x is the action ref, [y] is the nth engineer (1st is the primary), returns engineer object
--local reftPrevEngineerAssignmentsByLocation = 'M27PrevEngineerAssignmentsByLoc' --[x][y]: x = unique location ref, y = action ref, returns engineer

--NOTE: table.getn wont work properly with below tables if are referring to keys that use a non-sequential numerical reference
reftEngineerAssignmentsByLocation = 'M27EngineerAssignmentsByLoc'     --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the engineer unique ref assigned to this location; returns the engineer object
reftEngineerAssignmentsByActionRef = 'M27EngineerAssignmentsByAction' --Records all engineers. [x][y]{1,2} - x is the action ref; y is the engineer unique ref, 1 is the location ref, 2 is the engineer object (use the subtable ref keys instead of numbers to refer to these)
reftEngineerActionsByEngineerRef = 'M27EngineerActionsByEngineerRef' --Records actions by engineer reference; aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][BuildingQueue]: returns {LocRef, EngRef, AssistingRef, ActionRef, refbPrimaryBuilder, reftActualTargetLocationRef} but not in that order - i.e. use subtable keys to reference these; buildingqueue will be 1 for the first queueud building by the unit, 2 for the second etc. (e.g. t1 power)
reftEngineersHelpingACU = 'M27AllEngineersHelpingACU' --Engineer objects for any spare engineers assisting ACU
--Subtable reference keys:
local refEngineerAssignmentLocationRef = 'LocationRef' --Could use a number but this makes it more likely errors will be identified
local refEngineerAssignmentEngineerRef = 'EngineerRef'
local refoObjectTarget = 'ObjectAssistingRef' --Usually this will be the object we are assisting; however in the case of 'build t3 mex' it will be the mex itself if dealing with the priamry engineer
local refiActionRef = 'ActionRef'
reftActualTargetLocationRef = 'M27EngineerActualLocationRef' --The precise location instead of just the location ref
refbPrimaryBuilder = 'M27EngineerPrimaryBuilder' --true if arent assisting anything


--Localised engineer tracking:
local refiEngineerConditionNumber = 'M27EngineerConditionNumber' --condition number of the action assigned to the engineer (for if want an engineer with a lower priority, i.e. higher condition number)
refiEngineerCurrentAction = 'M27EngineerCurrentAction' --current action reference number that the engineer has been assigned
reftEngineerCurrentTarget = 'M27EngineerCurrentTarget'
refbEngineerActiveReclaimChecker = 'M27EngineerActiveReclaim'
reftEngineerLastPositionOfReclaimOrder = 'M27EngineerIssueReclaimLastPosition'
refbRecentlyAbortedReclaim = 'M27EngineerRecentlyAbortedReclaim' --Not reset by changes in action - used to flag if engineer was meant to be reclaiming but ran due to nearby enemies
local reftGuardedBy = 'M27EngineerGuardedByList' --stored as a variable on a particular unit, to track units which are guarding it
refiEngineerCurUniqueReference = 'M27EngineerCurUniqueReference' --aiBrain stores the xth engineer object its given an action to, so this can be used as a unique reference
local refiTotalActionsAssigned = 'M27EngineerTotalActionsAssigned' --Having issues with counting size of table so use this instead
--local refbEngineerHasNearbyEnemies = 'M27EngineerNearbyEnemies'
--local refbEngineerActionBeingRefreshed = 'M27EngineerActionBeingRefreshed' --Used to refresh tracking variables that have the relevant engineer as the one to be used
rebToldToStartBuildingT3Mex = 'M27EngineerStartedT3Mex' --Used so engineer can wait efore being treated as idle if this is false (for building t3 ontop of t2)
refbHelpingACU = 'M27EngineerHelpingACU' --e.g. used for spare engineers so can track how many we have helping the ACU

--Other variables:
local refiInitialMexBuildersWanted = 'M27InitialMexBuildersWanted' --build order related
refbNeedResourcesForMissile = 'M27NeedResourcesForMissile' -- true if e.g. want to build anti-nuke from SMD
refiTimeOfLastEngiSelfDestruct = 'M27TimeOfLastSelfDestruct' --floor(gametimeseconds) of when last ctrl K engineer (to stop ctrlK of all engis at once)
refbLastSpareEngineerHadNoAction = 'M27EngLastSpareEngineerHadNoAction' --True if the last spare engineer had nothing to do - used to increase search range
--local refoCurrentlyGuarding = 'M27CurrentlyGuarding' -- Unit object stored on a particular unit when its guarding another

function GetEngineerUniqueCount(oEngineer)
    local iUniqueRef = oEngineer[refiEngineerCurUniqueReference]
    if iUniqueRef == nil then
        local aiBrain = oEngineer:GetAIBrain()
        iUniqueRef = aiBrain[refiEngineerCurUniqueReference] + 1
        aiBrain[refiEngineerCurUniqueReference] = iUniqueRef
        oEngineer[refiEngineerCurUniqueReference] = iUniqueRef
    end
    return iUniqueRef
end

function TEMPTEST(aiBrain, sFunctionRef)
    --DONT REMOVE THIS as its helpful for testing, instead just comment out except for the errorhandler line once have used it

    --M27Utilities.ErrorHandler('This was only meant for debugging, disable') --remove this line if are actually using this for testing
    --Used if a particular location gives strange results - can hard code the location ref and track the variable and when it changes by uncommenting out various uses of --TEMPTEST

    if sFunctionRef then LOG('Temp test called from function ref '..sFunctionRef..'; Game time in seconds='..GetGameTimeSeconds()) end



    --BELOW CAN BE USED IF KNOW A PARTICULAR LOCATION THAT WANT TO TRACK

    local tLocationRefs = {'X207Z306', 'X87Z357', 'X231Z280'}
    M27Utilities.DrawLocations({{207,GetTerrainHeight(207,306),306}, {87,GetTerrainHeight(87,357),357}, {231,GetTerrainHeight(231,280),280}})
    local iActionRef = refActionBuildMex


    local iMaxCycle = table.getn(tLocationRefs)
    local sLocationRef
    local sEngiRef
    local oEngBuilder
    local sUnitState

    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation]) == true then LOG('All engineer assignments by location are empty')
    else
        LOG('Cycling through locations, iMaxCycle='..iMaxCycle)
        for iCurCount = 1, iMaxCycle do
            local iAssignments = 0
            local tAssignmentLocationRefs = {}
            sLocationRef = tLocationRefs[iCurCount]
            if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef]) == true then
                LOG('Building location '..sLocationRef..' is currently empty when considering by location')
            else
                if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionRef]) == false then
                    for iEngiRef, oEngBuilder in aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionRef] do
                        sEngiRef = GetEngineerUniqueCount(oEngBuilder)

                        sUnitState = M27Logic.GetUnitState(oEngBuilder)
                        if sUnitState == nil then sUnitState='NoState' end
                        sEngiRef = sEngiRef..sUnitState
                        LOG('Engineer with unique ref='..sEngiRef..'; is assigned to location ref='..sLocationRef..' for actionref='..iActionRef)
                    end
                else LOG('nothing recorded for sLocationRef:'..sLocationRef..' with iActionRef='..iActionRef)
                end
            end
        end
    end

    --Tracking ACUs actions:
    --[[
    if aiBrain[reftEngineerActionsByEngineerRef][1] then
        for iAction, tSubtable in aiBrain[reftEngineerActionsByEngineerRef][1] do
            LOG('iAction='..iAction..'; iActionRef='..tSubtable[refiActionRef]..'; location='..repr(tSubtable[refEngineerAssignmentLocationRef]))
        end
    end--]]
    
    

    --Tracking nth engineer's actions and/or guards
    --[[
    local bFirstEngiHasGuards = false
    for iEngi, oEngi in aiBrain:GetListOfUnits(refCategoryEngineer, false, true) do
        if GetEngineerUniqueCount(oEngi) == 2 then
            local iUniqueRef = GetEngineerUniqueCount(oEngi)
            local sLocRef
            local iActionCount = oEngi[refiTotalActionsAssigned]
            if iActionCount == nil then iActionCount = 0 end
            if M27Utilities.IsTableEmpty(aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef]) == false then
                for iAction, tSubtable in aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef] do
                    if tSubtable[refEngineerAssignmentLocationRef] == nil then sLocRef = 'nil' else sLocRef = tSubtable[refEngineerAssignmentLocationRef] end
                    LOG('iAction='..iAction..'; refEngineerAssignmentLocationRef='..sLocRef..'; ActionRef='..tSubtable[refiActionRef]..'; Engi action count='..iActionCount)
                end
            else LOG('Eng '..iUniqueRef..' has no actions assigned in EngineerActionsbyEngineerRef. Engi action count='..iActionCount)
            end

--]]
            --Track guards
            --[[if oEngi[reftGuardedBy] and M27Utilities.IsTableEmpty(oEngi[reftGuardedBy]) == false then
                bFirstEngiHasGuards = true
                LOG('First engi number of guards using invalid tablegetn method='..table.getn(oEngi[reftGuardedBy]))
                for iGuard, oGuard in oEngi[reftGuardedBy] do
                    LOG('First engi iGuard ref='..iGuard)
                    LOG('First engi iGuard unique ref from object variable='..GetEngineerUniqueCount(oGuard))
                end
            end--]]
 --[[
        end
    end--]]

    --[[
    local iActionToTrack = refActionBuildHydro
    if aiBrain[reftEngineerAssignmentsByActionRef] and aiBrain[reftEngineerAssignmentsByActionRef][iActionToTrack] then
        local sLocationRef = 'nil'
        for iEngiUniqueRef, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][iActionToTrack] do
            if tSubtable[refEngineerAssignmentLocationRef] then sLocationRef = tSubtable[refEngineerAssignmentLocationRef] end
            LOG('iEngiUniqueRef='..iEngiUniqueRef..'; sLocationRef='..sLocationRef..'; Engineer object unique ref (should be the same)='..tSubtable[refEngineerAssignmentEngineerRef][refiEngineerCurUniqueReference])
        end
    end
    --]]
    --if bFirstEngiHasGuards == false then LOG('First engi has no guards') end


    --Tracking a particular action:
    --[[if aiBrain[reftEngineerAssignmentsByActionRef] and aiBrain[reftEngineerAssignmentsByActionRef][1] then
        if aiBrain[reftEngineerAssignmentsByActionRef][1][1] then
            local oEngineer = aiBrain[reftEngineerAssignmentsByActionRef][1][1][refEngineerAssignmentEngineerRef]
            local sEngineer = 'Nil'
            if oEngineer then
                if oEngineer.GetUnitId then sEngineer = oEngineer:GetUnitId()
                    else sEngineer = 'Not a unit'
                end
            end
            LOG(sEngineer)
        else LOG('No unit assigned for action 1')
        end
    else
        LOG('No action recrded for action 1 yet')
    end--]]



end

function ClearEngineerActionTrackers(aiBrain, oEngineer, bDontClearUnitThatAreGuarding)
    --Assumes the unit will have been given a clearcommands() action if it needs one prior to calling this since sometimes will want to sometimes wont
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'ClearEngineerActionTrackers'
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetEngineerUniqueCount(oEngineer) == 59 then bDebugMessages = true end
    --if oEngineer == M27Utilities.GetACU(aiBrain) then bDebugMessages = true end
    if not(aiBrain.M27IsDefeated) and M27Logic.iTimeOfLastBrainAllDefeated < 10 then
        if bDontClearUnitThatAreGuarding == nil then bDontClearUnitThatAreGuarding = true end
        local iCurActionRef, sCurLocationRef, oCurAssistingRef, iGuardedByTableLocation
        local iUniqueRef = GetEngineerUniqueCount(oEngineer)
        local iEngiActionPreClear = oEngineer[refiEngineerCurrentAction]
        local tPrevReclaimTarget
      --TEMPTEST(aiBrain, sFunctionRef..': Start')

        if iUniqueRef then --Wont have any actions assigned by code if unique ref is nil (since its set by the action tracker)
            if bDebugMessages == true then LOG(sFunctionRef..': iUniqueRef='..iUniqueRef..': LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..': Start of clearing actions. bDontClearUnitThatAreGuarding='..tostring(bDontClearUnitThatAreGuarding)..'; action of engineer that are clearing='..(oEngineer[refiEngineerCurrentAction] or 'nil')) end

            --Clear engineer local variables:
            if oEngineer[refiEngineerCurrentAction] == refActionReclaimArea then tPrevReclaimTarget = {oEngineer[reftEngineerCurrentTarget][1], oEngineer[reftEngineerCurrentTarget][2], oEngineer[reftEngineerCurrentTarget][3]} end
            oEngineer[refiEngineerConditionNumber] = nil
            oEngineer[refiEngineerCurrentAction] = nil
            oEngineer[reftEngineerCurrentTarget] = nil
            oEngineer[reftEngineerLastPositionOfReclaimOrder] = nil
            oEngineer[refiTotalActionsAssigned] = 0
            oEngineer[rebToldToStartBuildingT3Mex] = false
            oEngineer[refbPrimaryBuilder] = false
            if oEngineer[refbHelpingACU] then
                if M27Utilities.IsTableEmpty(aiBrain[reftEngineersHelpingACU]) == false then
                    for iUnit, oUnit in aiBrain[reftEngineersHelpingACU] do
                        if oUnit == oEngineer then
                            table.remove(aiBrain[reftEngineersHelpingACU], iUnit)
                            break
                        end
                    end
                end
            end

            oEngineer[refbHelpingACU] = false
            --reftGuardedBy is cleared later
            --TEMPTEST(aiBrain, sFunctionRef..': Just cleared local variables moving on to tables')
            --reftEngineerActionsByEngineerRef = 'M27EngineerActionsByEngineerRef' --Records actions by engineer reference; aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable]: returns {LocRef, EngRef, AssistingRef, ActionRef} - i.e. use subtable keys to reference these
            if M27Utilities.IsTableEmpty(aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef]) == false then
                for iRef, tActionSubtable in aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef] do
                    iCurActionRef = tActionSubtable[refiActionRef]
                    sCurLocationRef = tActionSubtable[refEngineerAssignmentLocationRef]
                    if sCurLocationRef then
                        if bDebugMessages == true then
                            if sCurLocationRef then LOG(sFunctionRef..': Clearing for iCurActionRef='..iCurActionRef..'; sCurLocationRef='..sCurLocationRef)
                            else LOG(sFunctionRef..': Clearing for iCurActionRef='..iCurActionRef..'; sCurLocationRef is nil') end
                        end

                        --Clear bylocationref: reftEngineerAssignmentsByLocation --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the engineer unique ref assigned to this location
                        if aiBrain[reftEngineerAssignmentsByLocation][sCurLocationRef] and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sCurLocationRef][iCurActionRef]) == false then
                            --TEMPTEST(aiBrain, sFunctionRef..': Pre making sCurLocationRef nil, sCurLocationRef='..sCurLocationRef)
                            if bDebugMessages == true then LOG(sFunctionRef..': about to clear assignmentsbylocation, sCurLocationRef='..sCurLocationRef..'; iCurActionRef='..iCurActionRef..'; iUniqueRef='..iUniqueRef) end
                            aiBrain[reftEngineerAssignmentsByLocation][sCurLocationRef][iCurActionRef][iUniqueRef] = nil
                            --TEMPTEST(aiBrain, sFunctionRef..': Post making sCurLocationRef nil, sCurLocationRef='..sCurLocationRef)
                            if bDebugMessages == true then LOG(sFunctionRef..': Have cleared from AssignmentsByLocation for sCurLocationRef='..sCurLocationRef) end
                        else
                            if iCurActionRef then
                                if bDebugMessages == true then LOG('No table tracker to clear when clearing assignmentsbylocation or non nil location ref. iCurActionRef='..iCurActionRef) end
                            else
                                if oEngineer[refiEngineerCurrentAction] then M27Utilities.ErrorHandler('iCurActionRef is nil; iRef='..iRef..'; iUniqueRef='..iUniqueRef..'; oEngineer[refiEngineerCurrentAction] pre clear='..iEngiActionPreClear)
                                else M27Utilities.ErrorHandler('iCurActionRef is nil; iRef='..iRef..'; iUniqueRef='..iUniqueRef..'; oEngineer[refiEngineerCurrentAction] pre clear=nil')
                                end
                            end
                        end
                        --TEMPTEST(aiBrain, sFunctionRef..': Just cleared for sCurLocationRef='..sCurLocationRef)
                    end

                    --Clear by action ref:
                    --reftEngineerAssignmentsByActionRef --Records all engineers. [x][y]{1,2} - x is the action ref; y is the engineer unique ref, 1 is the location ref, 2 is the engineer object (use the subtable ref keys instead of numbers to refer to these)
                    if aiBrain[reftEngineerAssignmentsByActionRef] and aiBrain[reftEngineerAssignmentsByActionRef][iCurActionRef] then
                        if bDebugMessages == true then LOG(sFunctionRef..': Clearing reftEngineerAssignmentsByActionRef for iCurActionRef='..iCurActionRef) end
                        aiBrain[reftEngineerAssignmentsByActionRef][iCurActionRef][iUniqueRef] = nil
                    end
                    --TEMPTEST(aiBrain, sFunctionRef..': Just cleared engineer assignments by action ref')

                    --Clear this engineer from any unit it is assisting
                    if bDontClearUnitThatAreGuarding == false then
                        oCurAssistingRef = tActionSubtable[refoObjectTarget]
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Are assigned as assisting a unit')
                            if oCurAssistingRef.GetUnitId then LOG('Unit ID assisting='..oCurAssistingRef:GetUnitId())
                            else LOG('unit that are assisting has no unit Id') end
                            if oCurAssistingRef[reftEngineerActionsByEngineerRef] then LOG('Unique ref assisting='..oCurAssistingRef[reftEngineerActionsByEngineerRef])
                            else LOG('Unit that are assisting has no unique ref') end
                            if M27Utilities.IsTableEmpty(oCurAssistingRef[reftGuardedBy]) == true then LOG('Unit that are assisting doesnt have a table of units its guarded by') end
                        end
                        if oCurAssistingRef and M27Utilities.IsTableEmpty(oCurAssistingRef[reftGuardedBy]) == false then
                            oCurAssistingRef[reftGuardedBy][iUniqueRef] = nil
                        end
                    end
                end
                aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef] = {}
                --TEMPTEST(aiBrain, sFunctionRef..': Just cleared engineer actions by engineer ref')
            else
                if bDebugMessages == true then LOG(sFunctionRef..': table of actions by engineer ref is empty') end
            end



            --Clear actions of any units guarding this one and then call the update engineer tracker on them:
            local tTempGuardedBy = {}
            if M27Utilities.IsTableEmpty(oEngineer[reftGuardedBy]) == false then
                if bDebugMessages == true then LOG(sFunctionRef..': Clearing guards, number of guards='..table.getn(oEngineer[reftGuardedBy])) end
                local bAbortClearGuards = false
                local iGuardCount = 0
                for iGuard, oGuard in oEngineer[reftGuardedBy] do
                    if GetEngineerUniqueCount(oGuard) then
                        iGuardCount = iGuardCount + 1
                        tTempGuardedBy[iGuardCount] = oGuard
                        if bDebugMessages == true then LOG(sFunctionRef..': iGuardCount='..iGuardCount..'; oGuard lifetime count='..M27UnitInfo.GetUnitLifetimeCount(oGuard)) end
                    else
                        M27Utilities.ErrorHandler('Guard assigned to engineer with lifetime count='..iUniqueRef..'; doesnt have a unique ref so something has gone wrong, aborting actions to clear commands. iGuard='..iGuard)
                        bAbortClearGuards = true
                    end
                end

                if bAbortClearGuards == false then
                    if bDebugMessages == true then LOG(sFunctionRef..'; iGuardCount='..iGuardCount..'; will now clear commands of those guards and send them for reassignment') end
                    if M27Utilities.IsTableEmpty(tTempGuardedBy) == false then
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': About to issue clear commands to '..table.getn(tTempGuardedBy)..'engineers.  Unique ref of each engineer about to be cleared')
                            for iEngi, oEngi in tTempGuardedBy do
                                LOG('iEngi='..iEngi..'; oEngi[UniqueRef]='..GetEngineerUniqueCount(oEngi))
                            end
                        end

                        IssueClearCommands(tTempGuardedBy) --Otherwise engi will appear to be busy when reassignengi cycles through engis
                        ForkThread(DelayedEngiReassignment, aiBrain, true, tTempGuardedBy)
                    end
                    oEngineer[reftGuardedBy] = {}
                    for iGuard, oGuard in tTempGuardedBy do
                        --if GetEngineerUniqueCount(oGuard) == 59 then bDebugMessages = true end
                        if bDebugMessages == true then LOG(sFunctionRef..': About to clear oGuard, oGuard UC='..GetEngineerUniqueCount(oGuard)..'LC='..M27UnitInfo.GetUnitLifetimeCount(oGuard)) end
                        ClearEngineerActionTrackers(aiBrain, oGuard, true) --Dont want to do this earlier as risk infinite loop if this engineer assists another engineer that assists it
                    end
                end
            elseif bDebugMessages == true then LOG(sFunctionRef..': Dont have any guards assigned')
            end
            if tPrevReclaimTarget then
                local iReclaimSegmentX, iReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tPrevReclaimTarget)
                if bDebugMessages == true then LOG(sFunctionRef..': iReclaimSegmentX-Z='..iReclaimSegmentX..'-'..iReclaimSegmentZ..'; Engineer UC='..GetEngineerUniqueCount(oEngineer)..'; LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)) end
                --Update both this segment and adjacent ones (since adjacent ones will have beeni gnored if they were by a segment assigned for reclaim)
                for iAdjX = -1, 1 do
                    for iAdjZ = -1, 1 do
                        M27MapInfo.UpdateReclaimSegmentAreaOfInterest(iReclaimSegmentX + iAdjX, iReclaimSegmentZ + iAdjZ, {aiBrain})
                    end
                end
            end
        else if bDebugMessages == true then LOG(sFunctionRef..'; Unique ref is nil') end
        end

        --Clear escort requirements
        if oEngineer[M27PlatoonUtilities.refbShouldHaveEscort] then
            if not(M27Utilities.IsACU(oEngineer)) then
            --if not(oEngineer == M27Utilities.GetACU(aiBrain)) then

                --Reset after 20s incase the engineer is running from an enemy or is in danger, but only reset if we dont have a new action that is the same as the current action (in case engineer runs away, threat is dealt with, and then engineer returns and wants an escort)
                --DelayChangeVariable(oVariableOwner, sVariableName, vVariableValue, iDelayInSeconds, sOptionalOwnerTimeRef, iMustBeLessThanThisTimeValue, iMustBeMoreThanThisTimeValue, vMustEqualThisValue)
                M27Utilities.DelayChangeVariable(oEngineer, M27PlatoonUtilities.refbShouldHaveEscort, false, 20, refiEngineerCurrentAction, nil, nil, iEngiActionPreClear)
            end
        end
        if bDebugMessages == true and M27Utilities.IsACU(oEngineer) then
            local iACUAction = M27Utilities.GetACU(aiBrain)[refiEngineerCurrentAction]
            if iACUAction == nil then iACUAction = 'nil' end
            LOG(sFunctionRef..': Were dealing with ACU; ACU action at end of code ='..iACUAction)
        end
    end
    --DoesPlatoonStillHaveSupportTarget function will cause the escort to be disbanded (eventually) - dont want to do here since we may assign an action that leads us to wanting the engineer to still be escorted immediately after clearing its actions
  --TEMPTEST(aiBrain, sFunctionRef..': End')
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdateReclaimSegmentsForEngineerDeathOrNearbyEnemy(aiBrain, oEngineer, bNearbyEnemyNotDeath)
    local iArmyIndex = aiBrain:GetArmyIndex()
    local ReclaimReference = M27MapInfo.reftReclaimTimeOfLastEngineerDeathByArmyIndex
    if bNearbyEnemyNotDeath then ReclaimReference = M27MapInfo.refReclaimTimeLastEnemySightedByArmyIndex end
    if (oEngineer[refiEngineerCurrentAction] == refActionReclaimArea or oEngineer[refbRecentlyAbortedReclaim]) and M27Utilities.IsTableEmpty(oEngineer[reftEngineerCurrentTarget]) == false then
        local iReclaimSegmentX, iReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(oEngineer[reftEngineerCurrentTarget])
        for iAdjX = -1, 1 do
            for iAdjZ = -1, 1 do
                if M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX] and M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ] then
                    if not(M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ][ReclaimReference]) then M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ][ReclaimReference] = {} end
                    M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ][ReclaimReference][iArmyIndex] = GetGameTimeSeconds()
                end
            end
        end
    end

    --Also mark nearby segments from where the engineer just died/spotted enemies
    local iReclaimSegmentX, iReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(oEngineer:GetPosition())
    for iAdjX = -1, 1 do
        for iAdjZ = -1, 1 do
            if M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX] and M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ] then
                if not(M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ][ReclaimReference]) then M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ][ReclaimReference] = {} end
                M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ][ReclaimReference][iArmyIndex] = GetGameTimeSeconds()
            end
        end
    end
end

function OnEngineerDeath(aiBrain, oEngineer)
    --Was the engineer reclaiming? If so then mark its target and surroundings as dangerous
    if not(aiBrain.M27IsDefeated) and M27Logic.iTimeOfLastBrainAllDefeated < 10 then
        UpdateReclaimSegmentsForEngineerDeathOrNearbyEnemy(aiBrain, oEngineer, false)
        ClearEngineerActionTrackers(aiBrain, oEngineer, true)
    end
end

function UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers, oUnitToBeDestroyed)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'UpdateEngineerActionTrackers'
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --if GetEngineerUniqueCount(oEngineer) == 59 then bDebugMessages = true end


    if iActionToAssign == nil then M27Utilities.ErrorHandler('iActionToAssign is nil') end

  --TEMPTEST(aiBrain, sFunctionRef..': Start')
    if bDontClearExistingTrackers == nil then bDontClearExistingTrackers = false end
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code; iActionToAssign='..iActionToAssign..'; tTargetLocation='..repr(tTargetLocation)..'; bAreAssisting='..tostring(bAreAssisting)..'; bDontClearExistingTrackers='..tostring(bDontClearExistingTrackers)..'; tTargetLocation='..repr((tTargetLocation or {'nil'}))) end
    local sLocationRef
    if tTargetLocation == nil then
        if not(bAreAssisting) and oUnitToAssist == nil and not(iActionToAssign == refActionSpare) then M27Utilities.ErrorHandler('dont have a location or unit to assist') end
    else
        sLocationRef = M27Utilities.ConvertLocationToReference(tTargetLocation)
        if bDebugMessages == true then LOG(sFunctionRef..': sLocationRef='..sLocationRef) end
    end

    --Ensure have unique ref for engineer
    local iUniqueRef = GetEngineerUniqueCount(oEngineer)


    if bDebugMessages == true then LOG(sFunctionRef..': oEngineer uniqueref='..iUniqueRef..'; updating displayed name') end

    local bUpdateName = false
    local sName = ''
    if M27Config.M27ShowUnitNames == true or M27Config.M27ShowUnitNames == true then bUpdateName = true end
    if bUpdateName == true then
        sName = 'E'..iUniqueRef..':UID='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; Action='..iActionToAssign
        if bAreAssisting then sName = sName..': AssistObject' end
        if oEngineer.SetCustomName then oEngineer:SetCustomName(sName) end
    end



    --Update oEngineer trackers
    if not(bDontClearExistingTrackers) then
        if bDebugMessages == true then LOG(sFunctionRef..': Clearing engineer action trackers for engineer with UC='..GetEngineerUniqueCount(oEngineer)..' which has action '..(oEngineer[refiEngineerCurrentAction] or 'nil')) end
        ClearEngineerActionTrackers(aiBrain, oEngineer)
    else
        if bDebugMessages == true then LOG(sFunctionRef..': Not clearing engineers trackers due to input settings') end
    end
    oEngineer[refiEngineerCurrentAction] = iActionToAssign
    oEngineer[reftEngineerCurrentTarget] = tTargetLocation
    oEngineer[refiEngineerConditionNumber] = iConditionNumber
    local iCurPlaceInEngineerActionTable = oEngineer[refiTotalActionsAssigned]
    if iCurPlaceInEngineerActionTable == nil then iCurPlaceInEngineerActionTable = 1
    else iCurPlaceInEngineerActionTable = iCurPlaceInEngineerActionTable + 1 end
    oEngineer[refiTotalActionsAssigned] = iCurPlaceInEngineerActionTable

    if bDebugMessages == true then LOG(sFunctionRef..': Have updated engineers current action to '..oEngineer[refiEngineerCurrentAction]) end


    --Record guard in unit to be guarded
    if bAreAssisting == true and oUnitToAssist == nil then
        M27Utilities.ErrorHandler('Are meant to be assisting but unit to assist is nil')
    elseif oUnitToAssist and not(bAreAssisting) then
        M27Utilities.ErrorHandler('Have a unit to assist but bAreAssisting isnt true')
    elseif bAreAssisting == true then
        oEngineer[refbPrimaryBuilder] = false
        if oUnitToAssist[reftGuardedBy] == nil then oUnitToAssist[reftGuardedBy] = {} end
        oUnitToAssist[reftGuardedBy][iUniqueRef] = oEngineer
        if bDebugMessages == true then
            LOG(sFunctionRef..': Recorded engineer with unique ref '..iUniqueRef..'; as a guard for unit with ID= '..oUnitToAssist:GetUnitId())
            LOG('Unit that are assisting has unique reference='..GetEngineerUniqueCount(oUnitToAssist))
            LOG('Will cycle through each guardedby entry now and output the unique ref of each unit')
            for iGuard, oGuard in oUnitToAssist[reftGuardedBy] do
                LOG('oGuard has unique ref='..iGuard)
            end
        end
    else
        --Not guarding a unit - check if have an action that means we want an escort
        oEngineer[refbPrimaryBuilder] = true
        local bWantEscort = false
        if not(oEngineer == M27Utilities.GetACU(aiBrain)) then
            if iActionToAssign == refActionBuildMex or iActionToAssign == refActionBuildHydro or iActionToAssign == refActionReclaimArea then
                --Want an escort for the platoon if the target destination is far enough away
                if M27Utilities.IsTableEmpty(tTargetLocation) then
                    M27Utilities.ErrorHandler('No target location for iActionToAssign='..iActionToAssign..'; oEngineer='..oEngineer:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UQ='..GetEngineerUniqueCount(oEngineer)..'; gametime='..GetGameTimeSeconds())
                    tTargetLocation = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                end

                local iTargetDistanceFromOurBase = M27Utilities.GetDistanceBetweenPositions(tTargetLocation, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                if iTargetDistanceFromOurBase > 100 then bWantEscort = true
                elseif iTargetDistanceFromOurBase > 50 then
                    --Are we closer to enemy base than our base is?
                    local tEnemyStartPosition = M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]
                    local iDistanceBetweenBases = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]
                    local iTargetDistanceToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tTargetLocation, tEnemyStartPosition)
                    if iTargetDistanceToEnemyBase < iDistanceBetweenBases then bWantEscort = true end
                end
            end
        end
        if bWantEscort == true then
            oEngineer[M27PlatoonUtilities.refbShouldHaveEscort] = true
            M27PlatoonUtilities.RecordPlatoonUnitsByType(oEngineer, true)
            M27PlatoonUtilities.GetNearbyEnemyData(oEngineer, iEngineerEnemySearchRange, true)
            M27PlatoonUtilities.UpdateEscortDetails(oEngineer)
        else
            oEngineer[M27PlatoonUtilities.refbShouldHaveEscort] = false --Redundancy (clearactiontracker should already cover)
        end
    end

    --Record action in engineer reference table
    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef]) == true then
        aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef] = {}
    end

    aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable] = {}
    if oUnitToAssist then aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refoObjectTarget] = oUnitToAssist end
    if M27Utilities.IsTableEmpty(tTargetLocation) == false then
        aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refEngineerAssignmentLocationRef] = sLocationRef
        aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][reftActualTargetLocationRef] = {tTargetLocation[1], tTargetLocation[2], tTargetLocation[3]}
    end
    --[[if not(bAreAssisting) then
        aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refEngineerAssignmentLocationRef] = sLocationRef
    else aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refoObjectTarget] = oUnitToAssist
    end--]]
    aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refbPrimaryBuilder] = not(bAreAssisting)
    aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refiActionRef] = iActionToAssign
    if bDebugMessages == true then
        local sLocRef = sLocationRef
        if sLocRef == nil then sLocRef = 'nil' end
        LOG(sFunctionRef..': UniqueRef='..iUniqueRef..'; Recorded in ActionsByEngineerRef subtable for sLocRef='..sLocRef..'; iActionToAssign='..iActionToAssign..'; iCurPlaceInEngineerActionTable='..iCurPlaceInEngineerActionTable)
    end
    --Record AssignmentsByActionRef: -Records all engineers. [x][y]{1,2} - x is the action ref; y is the Engineer unique ref, 1 is the location ref, 2 is the engineer object
    if aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] == nil then
        aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] = {}
    end
    aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign][iUniqueRef] = {}
    aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign][iUniqueRef][refEngineerAssignmentLocationRef] = sLocationRef
    aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign][iUniqueRef][refEngineerAssignmentEngineerRef] = oEngineer
    if bDebugMessages == true then LOG(sFunctionRef..': Recorded in AssignmentsByActionRef') end

    --Record reftEngineerAssignmentsByLocation; --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the nth engineer assigned to this location
    if sLocationRef then
        if aiBrain[reftEngineerAssignmentsByLocation][sLocationRef] == nil then
            aiBrain[reftEngineerAssignmentsByLocation][sLocationRef] = {}
            aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionToAssign] = {}
        else
            if aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionToAssign] == nil then aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionToAssign] = {} end
        end
        aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionToAssign][iUniqueRef] = oEngineer
        if bDebugMessages == true then
            LOG(sFunctionRef..': Recorded in assignments by location; sLocationRef='..sLocationRef..'; iActionToAssign='..iActionToAssign..'; iUniqueRef='..iUniqueRef)
            LOG(sFunctionRef..': Values for corresponding entry in 1st action for actionsbyengineerref: iActionRef='..aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][1][refiActionRef]..'; sLocationRef='..aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][1][refEngineerAssignmentLocationRef])
        end

    end
    --Update reclaim tracker
    if iActionToAssign == refActionReclaimArea then
        local iReclaimSegmentX, iReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tTargetLocation)
        if bDebugMessages == true then LOG(sFunctionRef..': iReclaimSegmentX-Z='..iReclaimSegmentX..'-'..iReclaimSegmentZ..'; Engineer UC='..GetEngineerUniqueCount(oEngineer)..'; LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)) end
        --Update both the target segment and all adjacent segments (as dont want to relcaim if engineer already assigned nearby)
        for iAdjX = -1, 1 do
            for iAdjZ = -1, 1 do
                M27MapInfo.UpdateReclaimSegmentAreaOfInterest(iReclaimSegmentX + iAdjX, iReclaimSegmentZ + iAdjZ, {aiBrain})
            end
        end
    end

    --Record mexes that will be ctrl-k ing
    if oUnitToBeDestroyed then
        oUnitToBeDestroyed[M27EconomyOverseer.refbWillCtrlKMex] = true
    end

      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
  --TEMPTEST(aiBrain, sFunctionRef..': End')
end

function UpdateActionsForACUMovementPath(tMovementPath, aiBrain, oEngineer, iPathStartPoint)
    --Assumes oEngineer (e.g. the ACU) will build mexes anywhere near tMovementPath locations
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateActionsForACUMovementPath'
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iUniqueRef = GetEngineerUniqueCount(oEngineer)

    if bDebugMessages == true then

        LOG(sFunctionRef..': Start of code; tMovementPath='..repr(tMovementPath)..'; oEngineer BP='..oEngineer:GetUnitId())

        LOG('oEngineer lifetime count='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; Engineer Unique count='..iUniqueRef)
        local iPlatoonCount
        local sPlan = 'None'

        if oEngineer.PlatoonHandle and oEngineer.PlatoonHandle.GetPlan then
            sPlan = oEngineer.PlatoonHandle:GetPlan()
            iPlatoonCount = oEngineer.PlatoonHandle[M27PlatoonUtilities.refiPlatoonCount]
        end
        if iPlatoonCount == nil then iPlatoonCount = 0 end
        LOG(sFunctionRef..': sPlan='..sPlan..'; iPlatoonCount='..iPlatoonCount)
    end
  --TEMPTEST(aiBrain, sFunctionRef..': Start')
    ClearEngineerActionTrackers(aiBrain, oEngineer, true) --Only want to clear ACU and units guarding ACU, not the unit the ACU is assisting
  --TEMPTEST(aiBrain, sFunctionRef..': Just after clearing action trackers')
    local tNearbyMexes
    local iSearchRange = M27Overseer.iACUMaxTravelToNearbyMex

    for iLocation, tLocation in tMovementPath do
        if iLocation >= iPathStartPoint then
            if M27Utilities.IsTableEmpty(tLocation) == false then

                tNearbyMexes = M27MapInfo.GetResourcesNearTargetLocation(tLocation, iSearchRange, true)
                if M27Utilities.IsTableEmpty(tNearbyMexes) == false then
                    for iMex, tMexLocation in tNearbyMexes do
                        if bDebugMessages == true then LOG(sFunctionRef..': Updating for tMexLocation ref='..M27Utilities.ConvertLocationToReference(tMexLocation)) end
                        --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers)
                        UpdateEngineerActionTrackers(aiBrain, oEngineer, refActionBuildMex, tMexLocation, false, 0, nil, true)
                  --TEMPTEST(aiBrain, sFunctionRef..': Just after updating engineer action trackers for the mex location')
                    end
                end
            else
                M27Utilities.ErrorHandler(sFunctionRef..': Warning - tMovementPath is blank - likely error unless happens near start of game')
            end
        end
    end
  --TEMPTEST(aiBrain, sFunctionRef..': End')
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ProcessingEngineerActionForNearbyEnemies(aiBrain, oEngineer)
    --Returns true if are enemies near the engineer such that it's been given an override action (and should be ignored)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'ProcessingEngineerActionForNearbyEnemies'
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bAreNearbyEnemies = false
    if oEngineer and not(oEngineer.Dead) then
        local iSearchRangeLong = iEngineerEnemySearchRange
        local iSearchRangeShort = 13
        local tEngPosition = oEngineer:GetPosition()
        local bKeepBuilding = true


        local tNearbyEnemiesLong = aiBrain:GetUnitsAroundPoint(categories.LAND + M27UnitInfo.refCategoryStructure - categories.BENIGN, tEngPosition, iSearchRangeLong, 'Enemy')
        local bNearbyMobileEnemies = not(M27Utilities.IsTableEmpty(tNearbyEnemiesLong))
        local bNearbyPD, tNearbyPD
        if bNearbyMobileEnemies == false and aiBrain[M27Overseer.refiSearchRangeForEnemyStructures] > iSearchRangeLong then
            tNearbyPD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2PlusPD, tEngPosition, math.min(aiBrain[M27Overseer.refiSearchRangeForEnemyStructures], 73), 'Enemy')
            bNearbyPD = not(M27Utilities.IsTableEmpty(tNearbyPD))
        end
        if bDebugMessages == true then
            local sUniqueRef = GetEngineerUniqueCount(oEngineer)
            LOG(sFunctionRef..': Eng ref='..sUniqueRef..'; iEngineerEnemySearchRange='..iEngineerEnemySearchRange..'; bNearbyMobileEnemies='..tostring(bNearbyMobileEnemies))
            if bNearbyMobileEnemies == true then LOG(sFunctionRef..': NearbyEnemySize='..table.getn(tNearbyEnemiesLong))
            elseif bNearbyPD then LOG(sFunctionRef..': bNearbyPD is true; NearbyPDSize='..table.getn(tNearbyPD))
            end
        end
        if bNearbyMobileEnemies == true or bNearbyPD == true then
            --Mark nearby reclaim segments as having nearby enemy so will avoid
            UpdateReclaimSegmentsForEngineerDeathOrNearbyEnemy(aiBrain, oEngineer, true)


            bKeepBuilding = false --default if enemies nearby, will change in some cases
            if bDebugMessages == true then LOG(sFunctionRef..': have nearby enemies') end
            bAreNearbyEnemies = true
            local tNearbyEnemiesShort
            if bNearbyMobileEnemies == true then tNearbyEnemiesShort = aiBrain:GetUnitsAroundPoint(categories.LAND - categories.BENIGN, tEngPosition, iSearchRangeShort, 'Enemy') end
            local oReclaimTarget
            local bCaptureNotReclaim = false
            local iThreatOfEnemies
            if M27Utilities.IsTableEmpty(tNearbyEnemiesShort) == true and M27Logic.GetCombatThreatRating(aiBrain, tNearbyEnemiesLong, true, nil, nil, false, false) <= 10 then
                --Liekly enemy engineer or scout, so just ignore until it gets close to us
                if bDebugMessages == true then LOG(sFunctionRef..': No nearby enemies but the threat of all enemies in longer range is less than 10 so likely land scout or engi') end
                bKeepBuilding = true
            elseif M27Utilities.IsTableEmpty(tNearbyEnemiesShort) == false then
                oReclaimTarget = M27Utilities.GetNearestUnit(tNearbyEnemiesShort, tEngPosition, aiBrain, true)
                if oReclaimTarget.GetFractionComplete and EntityCategoryContains(M27UnitInfo.refCategoryStructure, oReclaimTarget:GetUnitId()) and oReclaimTarget:GetFractionComplete() == 1 and oReclaimTarget:GetHealthPercent() >= 0.8 then bCaptureNotReclaim = true end
                if bDebugMessages == true then LOG(sFunctionRef..': Have '..table.getn(tNearbyEnemiesShort)..' nearby enemies; bCaptureNotReclaim='..tostring(bCaptureNotReclaim)..'; contains structure='..tostring(EntityCategoryContains(categories.STRUCTURE, oReclaimTarget:GetUnitId()))..'; fraction complete='..oReclaimTarget:GetHealthPercent()) end
            else
                --Have nearby enemies but they're not close, and they have a threat of at least 10 - ignore if we're almost done building
                local oBeingBuilt, iFractionComplete

                if oEngineer:IsUnitState('Repairing') or oEngineer:IsUnitState('Building') then
                    if oEngineer.GetFocusUnit then
                        oBeingBuilt = oEngineer:GetFocusUnit()
                        if oBeingBuilt and oBeingBuilt.GetFractionComplete then
                            iFractionComplete = oBeingBuilt:GetFractionComplete()
                            if iFractionComplete >= 0.9  and iFractionComplete < 1 then bKeepBuilding = true end
                        end
                    end
                elseif oEngineer:IsUnitState('Reclaiming') then
                    bKeepBuilding = true
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Have far away enemies that arent close, bKeepBuilding='..tostring(bKeepBuilding)) end
                if bKeepBuilding == false then
                    --otherwise, run unless it's an enemy engineer in which case try to reclaim, or a mex in which case capture
                    local bOnlyNearbyEngisOrStructure = true
                    if bNearbyMobileEnemies == true then
                        oReclaimTarget = nil
                        local sCurEnemyID
                        for iUnit, oUnit in tNearbyEnemiesLong do
                            if M27UnitInfo.IsEnemyUnitAnEngineer(aiBrain, oUnit) == false then
                                --Dont need to know if unit visible to know if its a mex since mex only built on mass deposits
                                if not(EntityCategoryContains(M27UnitInfo.refCategoryMex, oUnit:GetUnitId())) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': iUnit isnt a mex or engineer') end
                                    bOnlyNearbyEngisOrStructure = false
                                    break
                                elseif bDebugMessages == true then LOG(sFunctionRef..': iUnit is a mex so isnt a threat')
                                end
                            end
                        end

                        --[[local tPossibleEngineers = M27Logic.GetVisibleUnitsOnly(aiBrain, tNearbyEnemiesLong)
                        if M27Utilities.IsTableEmpty(tPossibleEngineers) == false and tNearbyEnemiesLong == tNearbyEnemiesLong then
                            tPossibleEngineers = EntityCategoryFilterDown(refCategoryEngineer, tPossibleEngineers)
                            if M27Utilities.IsTableEmpty(tPossibleEngineers) == false and tPossibleEngineers == tNearbyEnemiesLong then
                                oReclaimTarget = M27Utilities.GetNearestUnit(tNearbyEnemiesShort, oEngineer:GetPosition(), aiBrain, true)
                            end
                        end--]]
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Only structures nearby, will capture if theyre only mexes') end
                        for iUnit, oUnit in tNearbyEnemiesLong do
                            if not(EntityCategoryContains(M27UnitInfo.refCategoryMex, oUnit:GetUnitId())) then bOnlyNearbyEngisOrStructure = false break end
                        end
                    end

                    if bOnlyNearbyEngisOrStructure then
                        oReclaimTarget = M27Utilities.GetNearestUnit(tNearbyEnemiesLong, tEngPosition, aiBrain, true)
                        if oReclaimTarget and oReclaimTarget.GetUnitId and EntityCategoryContains(M27UnitInfo.refCategoryMex, oReclaimTarget:GetUnitId()) then bCaptureNotReclaim = true end
                    end
                end
            end
            if oReclaimTarget then
                if oEngineer:IsUnitState('Capturing') == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': Clearing commands for engi with count='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' and unique ref='..GetEngineerUniqueCount(oEngineer)) end
                    IssueClearCommands({oEngineer})
                    if bCaptureNotReclaim then
                        IssueCapture({oEngineer}, oReclaimTarget)
                    else
                        IssueReclaim({oEngineer}, oReclaimTarget)
                    end
                end
            else
                if bKeepBuilding == false then
                    --Nearby enemy but we dont know if its an engineer so we want to run back towards base
                    if bDebugMessages == true then LOG(sFunctionRef..': Clearing commands for engi with count='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' and unique ref='..GetEngineerUniqueCount(oEngineer)) end
                    IssueClearCommands({oEngineer})
                    IssueMove({oEngineer}, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                end
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': no nearby enemies') end
        end
        if bKeepBuilding == false then
            --Reset variables relating to the engineer
            --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers)
            UpdateEngineerActionTrackers(aiBrain, oEngineer, refActionHasNearbyEnemies, oEngineer:GetPosition(), false, 0)
            oEngineer[refbRecentlyAbortedReclaim] = true
            M27Utilities.DelayChangeVariable(oEngineer, refbRecentlyAbortedReclaim, false, 10)
        elseif M27Utilities.IsTableEmpty(tNearbyEnemiesLong) == false and M27Logic.IsUnitIdle(oEngineer, false, false, false) then
                --Presumably a scout or engineer, attack-move towards them as dont want to get new commands yet
            IssueAggressiveMove({oEngineer}, M27Utilities.GetNearestUnit(tNearbyEnemiesLong, oEngineer:GetPosition(), aiBrain, nil, nil))
        end
    end


    --oEngineer[refbEngineerHasNearbyEnemies] = bAreNearbyEnemies
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, bAreNearEnemies='..tostring(bAreNearbyEnemies)) end
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bAreNearbyEnemies
end

function GetNearestEngineerWithLowerPriority(aiBrain, tEngineers, iCurrentActionPriority, tCurrentActionTarget, iActionRefToGetExistingCount, tsUnitStatesToIgnore, iMaxRangeForPrevEngi, iMaxRangeForNearestEngi, bOnlyGetIdleEngis, bGetInitialEngineer, iMinTechLevelWanted)
    --Returns the nearest engineer
    --Will also look for nearby enemies and get engineers to run away or reclaim, if it's the first time this cycle it's been done
    --If engineer was assigned previously to the action being looked for, will choose that in priority if it's nearby even if its not closest
    --bIgnoreActiveBuilders - if true, then wont consider engineers that are building or repairing a unit (but will consider if assisting, guarding etc.)
    --bOnlyGetIdleEngineers - Only affects engineers that have no action (i.e. doesnt even affect if are moving)
    --iCurrentActionPriority - the condition number (will only get engineers that have a higher condition number)
    --iMaxRangeForPrevEngi -- will only consider prev engineer if its within this range
    --bGetInitialEngineer - if true then will just look for the first idle engineer, ignoring everything else
    --iMinTechLevelWanted - will ignore engis lower than this tech level
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'GetNearestEngineerWithLowerPriority'
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local oNearestEngineer
    --local iActionExistingCount = 0
    local bNeedToCheckForNearbyEnemies = false
    local bEngineerIsBusy
    local iCurEngiPriority
    local iClosestDistanceToTarget, iCurDistanceToTarget
    iClosestDistanceToTarget = 10000
    if M27Utilities.IsTableEmpty(tEngineers) == true then
        M27Utilities.ErrorHandler('tEngineers is nil')
    else
        --[[if bDebugMessages == true then LOG(sFunctionRef..': iAction='..iActionRefToGetExistingCount..': Engineer count='..table.getn(tEngineers)..': bNeedToCheckForNearbyEnemies='..tostring(bNeedToCheckForNearbyEnemies)..'; Will cycle through to find nearest if we dont have a previously assigned engineer') end

        --Do we have a previous engineer already assigned to the action which is within range that is available?
        local bHavePreviousEngineer = false
        if bDebugMessages == true then LOG(sFunctionRef..': Checking if have any prev engineers recorded for this action, iActionRefToGetExistingCount='..iActionRefToGetExistingCount) end
        --Only do the first check below on non-mexes, since mexes can have multiple engis building multiple mexes at once (all other buildings aim to just have 1 primary unit building)
        if not(iActionRefToGetExistingCount==refActionBuildMex) and aiBrain[reftPrevEngineerAssignmentsByAction] and aiBrain[reftPrevEngineerAssignmentsByAction][iActionRefToGetExistingCount] then
            if bDebugMessages == true then LOG(sFunctionRef..': iActionRefToGetExistingCount='..iActionRefToGetExistingCount..': Checking previous engineers, size of table='..table.getn(aiBrain[reftPrevEngineerAssignmentsByAction][iActionRefToGetExistingCount])) end
            for iPrevEngi, oPrevEngi in aiBrain[reftPrevEngineerAssignmentsByAction][iActionRefToGetExistingCount] do
                if not(oPrevEngi.Dead) and oPrevEngi[refiEngineerCurrentAction] == nil then
                    iCurDistanceToTarget = M27Utilities.GetDistanceBetweenPositions(tCurrentActionTarget, oPrevEngi:GetPosition())
                    if iCurDistanceToTarget <= iMaxRangeForPrevEngi then
                        if bDebugMessages == true then
                            local sNearestEngiName = 'nil'
                            if oNearestEngineer then sNearestEngiName = oNearestEngineer.M27LifetimeUnitCount if sNearestEngiName == nil then sNearestEngiName = 'nil' end end
                            local sPrevEngiName = oPrevEngi.M27LifetimeUnitCount if sPrevEngiName == nil then sPrevEngiName = 'nil' end
                            LOG(sFunctionRef..': Are replacing nearest engineer with previous engineer.  iActionRefToGetExistingCount='..iActionRefToGetExistingCount..'sPrevEngiName='..sPrevEngiName..'; sNearestEngiName='..sNearestEngiName..'; iPrevEngi='..iPrevEngi)
                        end
                        bHavePreviousEngineer = true
                        oNearestEngineer = oPrevEngi
                        break
                    end
                    bHavePreviousEngineer = true
                    oNearestEngineer = oPrevEngi
                    break
                else
                    LOG(sFunctionRef..': iPrevEngi '..iPrevEngi..' has a current action='..oPrevEngi[refiEngineerCurrentAction])
                end
            end
        end--]]
        --[[if bHavePreviousEngineer == false then
            if aiBrain[reftPrevEngineerAssignmentsByLocation] then
                local sLocationRef = M27Utilities.ConvertLocationToReference(tCurrentActionTarget)
                if aiBrain[reftPrevEngineerAssignmentsByLocation][sLocationRef] then
                    local oPrevEngi = aiBrain[reftPrevEngineerAssignmentsByLocation][sLocationRef][iActionRefToGetExistingCount]
                    if oPrevEngi and not(oPrevEngi.Dead) and oPrevEngi[refiEngineerCurrentAction] == nil then
                        if oPrevEngi.GetPosition then
                            --if M27Utilities.GetDistanceBetweenPositions(oPrevEngi:GetPosition(), oNearestEngineer:GetPosition() <= iMaxRangeForPrevEngi) then
                                bHavePreviousEngineer = true
                                oNearestEngineer = oPrevEngi
                            --end
                        else
                            M27Utilities.ErrorHandler('oPrevEngi doesnt have a position; iActionRef='..iActionRefToGetExistingCount..'; sLocationRef='..sLocationRef..'; Will send log of the blueprint if its not nil next')
                            if oPrevEngi.GetUnitId then LOG('prev Engi Unit ID='..oPrevEngi:GetUnitId()) else LOG('Prev engi doesnt have unit ID so isnt a unit') end
                            LOG('oPrevEngi result of istableempty='..tostring(M27Utilities.IsTableEmpty(oPrevEngi)))
                            if oPrevEngi[refEngineerAssignmentEngineerRef] and oPrevEngi[refEngineerAssignmentEngineerRef].GetUnitId then LOG('If do the subtable then its an engineer object') end
                        end
                    end
                end
            end
        end--]]
        --if bHavePreviousEngineer == false then
        --Filter tEngineers to min tech level
        if iMinTechLevelWanted > 1 then
            local iTechRestrictedEngiCategory
            if iMinTechLevelWanted == 3 then iTechRestrictedEngiCategory = refCategoryEngineer * categories.TECH3
            else iTechRestrictedEngiCategory = refCategoryEngineer * categories.TECH3 + refCategoryEngineer * categories.TECH2 end

            tEngineers = EntityCategoryFilterDown(iTechRestrictedEngiCategory, tEngineers)
            if bDebugMessages == true then LOG(sFunctionRef..': Want engineers with min tech level='..iMinTechLevelWanted) end
        end
        if M27Utilities.IsTableEmpty(tEngineers) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': tEngineers size='..table.getn(tEngineers)) end
            for iEngineer, oEngineer in tEngineers do
                if bGetInitialEngineer == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': Want one of the initial T1 engineers we first built') end
                    if M27UnitInfo.GetUnitLifetimeCount(oEngineer) <= aiBrain[refiInitialMexBuildersWanted] and M27UnitInfo.GetUnitTechLevel(oEngineer) == 1 then
                        oNearestEngineer = oEngineer
                        break
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..': No nearby enemies so will consider action') end
                    --Does the engineer have a higher condition (so lower priority) assigned?
                    iCurEngiPriority = oEngineer[refiEngineerConditionNumber]
                    if iCurEngiPriority == nil then iCurEngiPriority = 1000 end
                    if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..': iCurEngiPriority='..iCurEngiPriority..': iCurrentActionPriority='..iCurrentActionPriority) end
                    if iCurEngiPriority > iCurrentActionPriority then
                        --Check engineer state/if is busy:
                        bEngineerIsBusy = false
                        if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..': Engineer state='..M27Logic.GetUnitState(oEngineer)) end
                        if bOnlyGetIdleEngis == true then bEngineerIsBusy = not(M27Logic.IsUnitIdle(oEngineer, false, false, true))
                        else
                            for iState, sState in tsUnitStatesToIgnore do
                                if oEngineer:IsUnitState(sState) == true then bEngineerIsBusy = true break end
                            end
                        end

                        if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..': bEngineerIsBusy='..tostring(bEngineerIsBusy)) end
                        if bEngineerIsBusy == false then
                            if not(iActionRefToGetExistingCount == refActionSpare) then
                                iCurDistanceToTarget = M27Utilities.GetDistanceBetweenPositions(tCurrentActionTarget, oEngineer:GetPosition())
                                if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..': iCurDistanceToTarget='..iCurDistanceToTarget..'; iClosestDistanceToTarget='..iClosestDistanceToTarget) end
                                if iCurDistanceToTarget < iClosestDistanceToTarget then
                                    if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..': Have a valid engineer') end
                                    iClosestDistanceToTarget = iCurDistanceToTarget
                                    oNearestEngineer = oEngineer
                                end
                            else oNearestEngineer = oEngineer break end
                        end
                    end
                end
            end
        end
        --end
        if oNearestEngineer and not(iActionRefToGetExistingCount == refActionSpare) then
            if iClosestDistanceToTarget > iMaxRangeForNearestEngi and not (bGetInitialEngineer) then
                if bDebugMessages == true then LOG(sFunctionRef..': iClosestDistanceToTarget='..iClosestDistanceToTarget..'; iMaxRangeForNearestEngi='..iMaxRangeForNearestEngi..'; therefore engineer too far away') end
                oNearestEngineer = nil
            end
        end
    end
    if bDebugMessages == true then
        if oNearestEngineer == nil then LOG(sFunctionRef..': No engineer found')
        else LOG(sFunctionRef..': Found engineer='..oNearestEngineer:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oNearestEngineer))
        end
    end
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oNearestEngineer
end

function DelayedSpareEngineerClearAction(aiBrain, oEngineer, iDelaySeconds)
    --Will wait iDelay seconds, before clearing engineer's actions if it's guarding a unit and its action is still spare
    local bDebugMessages = false

    local sFunctionRef = 'DelayedSpareEngineerClearAction'
    WaitSeconds(iDelaySeconds)
    --if GetEngineerUniqueCount(oEngineer) == 59 then bDebugMessages = true end
    if oEngineer[refiEngineerCurrentAction] == refActionSpare then
        if bDebugMessages == true then LOG(sFunctionRef..': About to clear engineer '..GetEngineerUniqueCount(oEngineer)..' actions as it still has a spare action') end
        IssueClearCommands({oEngineer})
        ClearEngineerActionTrackers(aiBrain, oEngineer, true)
    end
    --ReassignEngineers(aiBrain, true, {oEngineer})
end

function IssueSpareEngineerAction(aiBrain, oEngineer)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'IssueSpareEngineerAction'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end

    --Action already cleared in previous code
    local iCurSearchDistance = 40
    --local iRangeIncreaseFactor = 2 --Will increase search distance by this factor each cycle
    local bHaveAction = false
    local tTempTarget
    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
    local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]

    local iMaxSearchRange = math.min(iMapSizeX, iMapSizeZ)

    local iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS')
    local tEngineerPosition = oEngineer:GetPosition()
    local tNearbyBuildings
    local oBuildingProducing

    local bDestroy = false

    --while bHaveAction == false do
        --Check for reclaim

    if bDebugMessages == true then
        LOG(sFunctionRef..': About to start checking for spare engi actions for engi with unique ref='..GetEngineerUniqueCount(oEngineer)..'; iMassStoredRatio='..iMassStoredRatio)
    end

    local tLocationToSearchFrom
    local iDistToStart = M27Utilities.GetDistanceBetweenPositions(tEngineerPosition,M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
    if iDistToStart <= 30 then tLocationToSearchFrom = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber] else tLocationToSearchFrom = tEngineerPosition end

    --Check if we have a reasonable amount of power
    local iNetCurEnergyIncome = aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome]
    local iEnergyStored = aiBrain:GetEconomyStored('ENERGY')
    local iEnergyPercentStorage = aiBrain:GetEconomyStoredRatio('ENERGY')
    local iStorageModIfUpgrading = 0
    if oEngineer:IsUnitState('Upgrading') or oEngineer:IsUnitState('Building') then iStorageModIfUpgrading = -0.1 end
    iEnergyPercentStorage = iEnergyPercentStorage + iStorageModIfUpgrading
    iNetCurEnergyIncome = iNetCurEnergyIncome * (1 + iStorageModIfUpgrading)
    local bHaveLowPower = false
    --Are we power stalling or have we in the last 20s?
    if aiBrain[M27EconomyOverseer.refbStallingEnergy] or GetGameTimeSeconds() - aiBrain[M27EconomyOverseer.refiLastEnergyStall] <= 20 then bHaveLowPower = true
    else
        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
            iCurSearchDistance = 70
            if iNetCurEnergyIncome < 2 or iEnergyPercentStorage < 0.98 then bHaveLowPower = true end
        else
            if iNetCurEnergyIncome < 0 and iEnergyPercentStorage < 0.9 then bHaveLowPower = true
            elseif iEnergyPercentStorage < 0.2 then bHaveLowPower = true end
        end
    end

    local bHaveLowMass = M27Conditions.HaveLowMass(aiBrain)
    local bACUIsUpgrading = false
    local oACU = M27Utilities.GetACU(aiBrain)
    if oACU:IsUnitState('Upgrading') then bACUIsUpgrading = true end
    local iCategoryToSearchFor = M27UnitInfo.refCategoryStructure
    if bHaveLowPower then
        iCurSearchDistance = math.max(iCurSearchDistance, 50)
        iCategoryToSearchFor = refCategoryPower
    elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then iCategoryToSearchFor = refCategoryPower + refCategoryAirFactory
    end

    if aiBrain[refbLastSpareEngineerHadNoAction] then iCurSearchDistance = iCurSearchDistance + 15 end

        --Help ACU if its nearby and upgrading
    if bDebugMessages == true then LOG(sFunctionRef..': If ACU is upgrading will see if want to help it. bACUIsUpgrading='..tostring(bACUIsUpgrading)..'; bHaveLowPower='..tostring(bHaveLowPower)..'; iEnergyPercentStorage='..iEnergyPercentStorage) end
    if bACUIsUpgrading and not(bHaveLowPower) then
        local bCanHelpACU = false

        local iDistToACU = M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), oACU:GetPosition())
        if iDistToACU <= 25 and oACU:GetWorkProgress() < 0.95 then
            bCanHelpACU = true
        else
            local iSpeed = oEngineer:GetBlueprint().Physics.MaxSpeed
            local iTimeToGetToACU = math.max(0, iDistToACU - 6) / iSpeed
            local iCurGameTime = math.floor(GetGameTimeSeconds())
            local iTimeForACUToCompleteUpgrade
            if oACU[M27Overseer.reftACURecentUpgradeProgress][iCurGameTime - 11] and oACU[M27Overseer.reftACURecentUpgradeProgress][iCurGameTime - 1] then
                iTimeForACUToCompleteUpgrade = (1 - oACU[M27Overseer.reftACURecentUpgradeProgress][iCurGameTime - 1]) / ((oACU[M27Overseer.reftACURecentUpgradeProgress][iCurGameTime - 1] - oACU[M27Overseer.reftACURecentUpgradeProgress][iCurGameTime - 11]) / 10)
            else
                --ACU must have only just started, so assume it will complete based on its build power
                iTimeForACUToCompleteUpgrade = (M27UnitInfo.GetUpgradeBuildTime(oACU, oACU[M27UnitInfo.refsUpgradeRef]) or 1) / oACU:GetBlueprint().Economy.BuildRate
            end
            if bDebugMessages == true then LOG(sFunctionRef..': ACU is upgrading.  iTimeToGetToACU='..iTimeToGetToACU..'; iTimeForACUToCompleteUpgrade='..iTimeForACUToCompleteUpgrade..'; Engineer LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer)..'; Engineer position='..repr(oEngineer:GetPosition())..'; ACU position='..repr(oACU:GetPosition())) end
            if iTimeToGetToACU * 1.05 < iTimeForACUToCompleteUpgrade then
                bCanHelpACU = true
            elseif bDebugMessages == true then LOG(sFunctionRef..': Wont help ACU as will take too long to get to ACU. reftACURecentUpgradeProgress='..repr(oACU[M27Overseer.reftACURecentUpgradeProgress])..'; refsUpgradeRef='..oACU[M27UnitInfo.refsUpgradeRef]..'; Upgrade time='..M27UnitInfo.GetUpgradeBuildTime(oACU, oACU[M27UnitInfo.refsUpgradeRef]))
            end
            if bCanHelpACU then
                --If ACU isn't close to our base or the engineer, then limit the number of spare engineers helping the ACU
                if M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) > 120 then
                    local iSpareEngisHelpingACU = 0
                    if M27Utilities.IsTableEmpty(aiBrain[reftEngineersHelpingACU]) == false then
                        for iSpareEngi, oSpareEngi in aiBrain[reftEngineersHelpingACU] do
                            if M27UnitInfo.IsUnitValid(oSpareEngi) and oSpareEngi[refbHelpingACU] then iSpareEngisHelpingACU = iSpareEngisHelpingACU + 1 end
                        end
                    end
                    if iSpareEngisHelpingACU >= 10 then bCanHelpACU = false end
                end
            end
        end
        if bCanHelpACU then
            --Help ACU
            if bDebugMessages == true then LOG(sFunctionRef..': Will tell engineer to help ACU') end
            bHaveAction = true
            IssueGuard({oEngineer}, oACU)
            oEngineer[refbHelpingACU] = true

            table.insert(aiBrain[reftEngineersHelpingACU], oEngineer)
        end
    end

    if bHaveAction == false then
        if iMassStoredRatio < 0.60 and aiBrain:GetEconomyStored('MASS') < 5000 then
            local oReclaim = M27MapInfo.GetNearestReclaim(tEngineerPosition, iCurSearchDistance, 2)
            --Setting min value to 1 caused issue with wall segment
            if not(oReclaim == nil) then
                bHaveAction = true
                tTempTarget = oReclaim:GetPosition()
                IssueAggressiveMove({oEngineer}, tTempTarget )
                if bDebugMessages == true then LOG(sFunctionRef..': Have nearby reclaim, at location '..repr(tTempTarget)) end
            end
        end
    end
    if bHaveAction == false then
        if not(bACUIsUpgrading and bHaveLowMass) then
            --Do we have too many engineers of this tech level? If so ctrl-K if are near base
            if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 2 then
                local iCurTechLevel = M27UnitInfo.GetUnitTechLevel(oEngineer)
                if iCurTechLevel < aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] then
                    local iCurTime = math.floor(GetGameTimeSeconds())
                    if iCurTime - aiBrain[refiTimeOfLastEngiSelfDestruct] > 0.99 and M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 90 then
                        local iMaxEngisOfThisTechLevelWanted = 30
                        local iHighestTechUnits = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * M27UnitInfo.ConvertTechLevelToCategory(aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]))
                        if iHighestTechUnits >= 10 then
                            if bHaveLowMass then iMaxEngisOfThisTechLevelWanted = 5
                            else iMaxEngisOfThisTechLevelWanted = 8
                            end
                        elseif bHaveLowMass and iHighestTechUnits >= 5 then
                            iMaxEngisOfThisTechLevelWanted = 12
                        end
                        local iEngisOfTechLevel = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * M27UnitInfo.ConvertTechLevelToCategory(iCurTechLevel))
                        if iHighestTechUnits >= 3 and iEngisOfTechLevel > iMaxEngisOfThisTechLevelWanted then
                            --Double threshold if we have any factories below tech3
                            if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllFactories * M27UnitInfo.ConvertTechLevelToCategory(iCurTechLevel)) == 0 or iEngisOfTechLevel < iMaxEngisOfThisTechLevelWanted * 2 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Have too many engineers of the current tech level so will kill engineer '..oEngineer:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' with UC='..GetEngineerUniqueCount(oEngineer)) end
                                ClearEngineerActionTrackers(aiBrain, oEngineer, true)
                                oEngineer:Kill()
                                bDestroy = true
                                bHaveAction = true
                            end
                        end
                    end
                end
            end

            if bDestroy == false then
                --Prioritise any HQ upgrades that are nearby
                if bDebugMessages == true then LOG(sFunctionRef..': Checking whether we have active HQ upgrades; Is the table empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]))) end
                if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]) == false then
                    tNearbyBuildings = {}
                    if bDebugMessages == true then LOG(sFunctionRef..': Have active HQ upgrades will cycle through each one, size of table='..table.getn(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades])) end
                    for iUnit, oUnit in aiBrain[M27EconomyOverseer.reftActiveHQUpgrades] do
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering oUnit='..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; will see if it is close enough to tLocationToSearchFrom='..repr(tLocationToSearchFrom)) end
                        if M27UnitInfo.IsUnitValid(oUnit) and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tLocationToSearchFrom) <= iCurSearchDistance then
                            if bDebugMessages == true then LOG(sFunctionRef..': Unit is close enough so adding to list of nearby buildings') end
                            table.insert(tNearbyBuildings, oUnit)
                        end
                    end
                end
                if M27Utilities.IsTableEmpty(tNearbyBuildings) == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': Adding nearby buildings') end
                    tNearbyBuildings = aiBrain:GetUnitsAroundPoint(iCategoryToSearchFor, tLocationToSearchFrom, iCurSearchDistance, 'Ally')
                end
                if M27Utilities.IsTableEmpty(tNearbyBuildings) == false then
                    --If have low mass or are in eco mode then prioritise mexes, subject to wanting to tech up
                    if bDebugMessages == true then LOG(sFunctionRef..': Cycling through each unit to see if it can be helped') end
                    local tiCategoriesByPriority
                    if bHaveLowMass or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
                        tiCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryMex, M27UnitInfo.refCategoryPower, M27UnitInfo.refCategoryAllFactories, M27UnitInfo.refCategoryStructure - M27UnitInfo.refCategoryAllFactories - M27UnitInfo.refCategoryPower - M27UnitInfo.refCategorySMD}
                    else
                        tiCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryStructure - M27UnitInfo.refCategorySMD}
                    end

                    local tBuildingsOfPriority = {}
                    for iCategoryType, iCategoryRef in tiCategoriesByPriority do
                        tBuildingsOfPriority = EntityCategoryFilterDown(iCategoryRef, tNearbyBuildings)
                        if M27Utilities.IsTableEmpty(tBuildingsOfPriority) == false then
                            for iBuilding, oBuilding in tBuildingsOfPriority do


                        --for iBuilding, oBuilding in tNearbyBuildings do
                                if oBuilding.GetFractionComplete and oBuilding:GetFractionComplete() < 0.99 then
                                    bHaveAction = true
                                    IssueRepair({ oEngineer}, oBuilding)
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have a part-complete building that will assist') end
                                elseif oBuilding.IsUnitState then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have a building with unit state='..M27Logic.GetUnitState(oEngineer)) end
                                    if oBuilding:IsUnitState('Upgrading') == true or oBuilding:IsUnitState('SiloBuildingAmmo') or (oBuilding.GetWorkProgress and oBuilding:GetWorkProgress() < 1) then
                                        --Check we have spare resources
                                        if aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] > 2 then
                                            --If building ammo, check if we already have 2
                                            if not(oBuilding:IsUnitState('SiloBuildingAmmo')) or oBuilding:GetTacticalSiloAmmoCount() + oBuilding:GetNukeSiloAmmoCount() < 2 then
                                                bHaveAction = true
                                                IssueGuard({ oEngineer}, oBuilding)
                                                if bDebugMessages == true then LOG(sFunctionRef..': Have an upgrading unti that will assist') end
                                            end
                                        end
                                    elseif oBuilding:IsUnitState('Building') == true then
                                        oBuildingProducing = oBuilding --Dont mind which order upgrade and part-complete buildings are done in, but assisting a factory is a lower priority so only do if no matches to prev 2 in the search area
                                        if bDebugMessages == true then LOG(sFunctionRef..': Have a unit that is building something, will assist it if cant find upgrading or part complete buildings') end
                                    end
                                end
                                if bHaveAction then break end
                            end
                        end
                        if bHaveAction then break end
                    end
                    if bHaveAction == false and oBuildingProducing then
                        if bDebugMessages == true then LOG(sFunctionRef..': Issuing guard to assist unit in its production') end
                        bHaveAction = true
                        IssueGuard({oEngineer}, oBuildingProducing)
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Dont have any buildings within '..iCurSearchDistance..' of engineer') end
                end
            end
        end
    end

        --[[if iCurSearchDistance > iMaxSearchRange then
            break
        end
        iCurSearchDistance = iCurSearchDistance * iRangeIncreaseFactor

        iLoopCount = iLoopCount + 1
        if iLoopCount > iMaxLoop then
            M27Utilities.ErrorHandler('Exceeded max loop, likely infinite loop')
        end--]]
    --end
    local iTimeToWaitInSecondsBeforeRefresh
    if bHaveAction == false then
        aiBrain[refbLastSpareEngineerHadNoAction] = true
        --Are we within 50 of the base? If not then attack-move to random point within 30 of start position
        local tPlaceToMoveTo
        if iDistToStart > 50 then
            AttackMoveToRandomPositionAroundBase(aiBrain, oEngineer, 30, 20)
            --tPlaceToMoveTo = M27Logic.GetRandomPointInAreaThatCanPathTo(M27UnitInfo.GetUnitPathingType(oEngineer), M27MapInfo.GetUnitSegmentGroup(oEngineer), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 30, 20)
        else
            --Already near base - have checked above to upgrade within a 40 range, so presumably we are power stalling; attack-move further away from base
            AttackMoveToRandomPositionAroundBase(aiBrain, oEngineer, 50, 30)
            --tPlaceToMoveTo = M27Logic.GetRandomPointInAreaThatCanPathTo(M27UnitInfo.GetUnitPathingType(oEngineer), M27MapInfo.GetUnitSegmentGroup(oEngineer), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 50, 30)
        end
        --IssueAggressiveMove({oEngineer}, tPlaceToMoveTo)
        iTimeToWaitInSecondsBeforeRefresh = math.random(3,7)
    else
        aiBrain[refbLastSpareEngineerHadNoAction] = false
        iTimeToWaitInSecondsBeforeRefresh = math.random(15, 25)
    end
    if bDestroy == false then ForkThread(DelayedSpareEngineerClearAction, aiBrain, oEngineer, iTimeToWaitInSecondsBeforeRefresh) end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function AreMobileUnitsInRect(rRectangleToSearch, bOnlyLookForMobileLand)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'AreMobileUnitsInRect'
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bAreUnits
    local tBlockingUnits = GetUnitsInRect(rRectangleToSearch)
    if bOnlyLookForMobileLand == nil then bOnlyLookForMobileLand = true end
    if M27Utilities.IsTableEmpty(tBlockingUnits) == true then
        bAreUnits = false
    else
        if bOnlyLookForMobileLand == true then
            --For some reason using entity category filters down
            local bHaveMobileLand = false
            local sUnitID
            for iUnit, oUnit in tBlockingUnits do
                if oUnit.GetUnitId then
                    sUnitID = oUnit:GetUnitId()
                    if bDebugMessages == true then LOG(sFunctionRef..': Units in rect: iUnit='..iUnit..' sUnitID='..sUnitID) end
                    if EntityCategoryContains(categories.MOBILE * categories.LAND, sUnitID) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Unit is mobile land so stopping loop') end
                        bHaveMobileLand = true
                        break
                    end
                end
            end
            if bHaveMobileLand == true then
                bAreUnits = true
            else
                bAreUnits = false
            end
        else bAreUnits = true end
    end
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bAreUnits
end

function FindRandomPlaceToBuildOld(aiBrain, oBuilder, tStartPosition, sBlueprintToBuild, iSearchSizeMin, iSearchSizeMax)
    --TRUE RANDOM APPROACH BELOW - replaced with non-random appraoch in subsequent function
    --This hasnt been updated for getmapsizechange
    --tries finding somewhere with enough space to build sBuildingBPToBuild - e.g. to be used as a backup when fail to find adjacency location
    --Can also be used for general movement
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'FindRandomPlaceToBuildOld'
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local iMapSizeX, iMapSizeZ = GetMapSize()
    local iMapBoundMaxX = iMapSizeX - 4
    local iMapBoundMaxZ = iMapSizeZ - 4
    local iMapBoundMinX = 4
    local iMapBoundMinZ = 4
    local tTargetLocation = {} --{tStartPosition[1], tStartPosition[2], tStartPosition[3]}
    if iSearchSizeMax == nil then iSearchSizeMax = 10 end
    if iSearchSizeMin == nil then iSearchSizeMin = 2 end
    local iRandomX, iRandomZ
    local iCurSizeCycleCount = 0
    local iCycleSize = 8
    local iSignageX, iSignageZ
    local iMaxCycles = 5
    local iCurCycle = 0
    local iValidLocationCount = 0
    local tValidLocations = {}
    local tValidDistanceToEnemy = {}
    local tValidDistanceToBuilder = {}
    local iMinDistanceToBuilder = 10000
    local iMaxDistanceToBuilder = 0
    local iMaxDistanceToEnemy = 0
    local iCurDistanceToEnemy, iCurDistanceToBuilder
    local iCurPriority = 0
    local iMaxPriority = 0
    local tBuilderPosition
    local oBuilderBP, iBuilderRange
    if oBuilder and oBuilder.GetPosition then
        tBuilderPosition = oBuilder:GetPosition()
        oBuilderBP = oBuilder:GetBlueprint()
        if oBuilderBP.Economy and oBuilderBP.Economy.MaxBuildDistance then iBuilderRange = oBuilderBP.Economy.MaxBuildDistance end
    else
        M27Utilities.ErrorHandler('oBuilder is nil or has no position')
        tBuilderPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    end


    local iEnemyStartPosition = M27Logic.GetNearestEnemyStartNumber(aiBrain)
    local tEnemyStartPosition = M27MapInfo.PlayerStartPoints[iEnemyStartPosition]
    local tNewBuildingSize
    if sBlueprintToBuild then tNewBuildingSize = M27UnitInfo.GetBuildingSize(sBlueprintToBuild) end
    if tNewBuildingSize == nil then
        M27Utilities.ErrorHandler('sBlueprintToBuild is nil or has no building size')
        tNewBuildingSize = {0,0}
    end
    local fSizeMod = 0.5
    local iMaxDistanceToBuildWithoutMoving = iBuilderRange + tNewBuildingSize[1] * fSizeMod
    local sPathing
    local iBuilderSegmentX, iBuilderSegmentZ
    local iBuilderPathingGroup, iCurPathingGroup
    local iCurSegmentX, iCurSegmentZ
    local iGroupCycleCount = 0

    while iValidLocationCount == 0 do
        iGroupCycleCount = iGroupCycleCount + 1
        if bDebugMessages == true then LOG(sFunctionRef..': Start of main loop grouping, iGroupCycleCount='..iGroupCycleCount..'; iCycleSize='..iCycleSize) end
        if iGroupCycleCount > iMaxCycles then
            M27Utilities.ErrorHandler('Possible infinite loop - Old findrandom place - unable to find anywhere to build despite iSearchSizeMax='..iSearchSizeMax)
            break
        end
        for iCurSizeCycleCount = 1, iCycleSize do
            iSignageX = math.random(0,1) * 2 - 1
            iSignageZ = math.random(0,1) * 2 - 1
            iRandomX = math.random(iSearchSizeMin, iSearchSizeMax) * iSignageX + tStartPosition[1]
            iRandomZ = math.random(iSearchSizeMin, iSearchSizeMax) * iSignageZ + tStartPosition[3]
            if iRandomX < iMapBoundMinX then iRandomX = iMapBoundMinX
            elseif iRandomX > iMapBoundMaxX then iRandomX = iMapBoundMaxX end
            if iRandomZ < iMapBoundMinZ then iRandomZ = iMapBoundMinZ
            elseif iRandomZ > iMapBoundMaxZ then iRandomZ = iMapBoundMaxZ end

            tTargetLocation = {iRandomX, GetTerrainHeight(iRandomX, iRandomZ), iRandomZ}
            if aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation) == true then
                iValidLocationCount = iValidLocationCount + 1
                tValidLocations[iValidLocationCount] = tTargetLocation
                iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tEnemyStartPosition, tTargetLocation)
                tValidDistanceToEnemy[iValidLocationCount] = iCurDistanceToEnemy
                if iCurDistanceToEnemy > iMaxDistanceToEnemy then iMaxDistanceToEnemy = iCurDistanceToEnemy end
                iCurDistanceToBuilder = M27Utilities.GetDistanceBetweenPositions(tTargetLocation, tBuilderPosition)
                tValidDistanceToBuilder[iValidLocationCount] = iCurDistanceToBuilder
                if iCurDistanceToBuilder > iMaxDistanceToBuilder then iMaxDistanceToBuilder = iCurDistanceToBuilder end
                if iCurDistanceToBuilder < iMinDistanceToBuilder then iMinDistanceToBuilder = iCurDistanceToBuilder end
            end
            if iCurSizeCycleCount == iCycleSize then
                iSearchSizeMin = iSearchSizeMax
                iSearchSizeMax = iSearchSizeMax * 2
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Finished looping through locations, iValidLocationCount='..iValidLocationCount) end
    if iValidLocationCount > 0 then
        --Pick the best valid location that we have
        if iMaxDistanceToBuilder > iMaxDistanceToBuildWithoutMoving and oBuilder then
            sPathing = M27UnitInfo.GetUnitPathingType(oBuilder)
            iBuilderSegmentX, iBuilderSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tBuilderPosition)
            iBuilderPathingGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iBuilderSegmentX, iBuilderSegmentZ)
        end

        local rBuildAreaRect
        for iCurLocation, tLocation in tValidLocations do
            rBuildAreaRect = Rect(tLocation[1] - iNewBuildingRadius, tLocation[3] - iNewBuildingRadius, tLocation[1] + iNewBuildingRadius, tLocation[3] + iNewBuildingRadius)
            if M27MapInfo.GetReclaimInRectangle(1, rBuildAreaRect) == false then iCurPriority = iCurPriority + 3 end
            if AreMobileUnitsInRect(rBuildAreaRect) == false then iCurPriority = iCurPriority + 3 end
            if tValidDistanceToEnemy[iCurLocation] >= iMaxDistanceToEnemy then iCurPriority = iCurPriority + 1 end
            iCurDistanceToBuilder = tValidDistanceToBuilder[iValidLocationCount]
            if iCurDistanceToBuilder <= iMaxDistanceToBuildWithoutMoving then
                iCurPriority = iCurPriority + 3
            else
                iCurSegmentX, iCurSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tLocation)
                iCurPathingGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iCurSegmentX, iCurSegmentZ)
                if not(iCurPathingGroup == iBuilderPathingGroup) then
                    iCurPriority = iCurPriority - 40
                    if iCurDistanceToBuilder == iMinDistanceToBuilder then iCurPriority = iCurPriority + 20 end --If only have places that cant path to, then want the cloest one as are most likely to be able to build
                end
            end
            iCurPriority = iCurPriority + 2 * (iCurDistanceToBuilder - iMinDistanceToBuilder) / (iMaxDistanceToBuilder - iMinDistanceToBuilder)

            if iCurPriority > iMaxPriority then
                iMaxPriority = iCurPriority
                tTargetLocation = tLocation
            end
        end
    end

      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tTargetLocation
end

function FindRandomPlaceToBuild(aiBrain, oBuilder, tStartPosition, sBlueprintToBuild, iSearchSizeMin, iSearchSizeMax, bForcedDebug, iOptionalMaxCycleOverride, bAlreadyRecheckedPathing)
    --Returns nil if cant find anywhere
    --tries finding somewhere with enough space to build sBuildingBPToBuild - e.g. to be used as a backup when fail to find adjacency location
    --Can also be used for general movement
    --very similar to FindEmptyPathableAreaNearTarget, but now with added code to ignore if blocking mex
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if bForcedDebug then bDebugMessages = true end --for error handling
    local sFunctionRef = 'FindRandomPlaceToBuild'


      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local rPlayableArea = M27MapInfo.rMapPlayableArea

    local iMapBoundMaxX = rPlayableArea[3]
    local iMapBoundMaxZ = rPlayableArea[4]
    local iMapBoundMinX = rPlayableArea[1]
    local iMapBoundMinZ = rPlayableArea[2]
    local tTargetLocation = {} --{tStartPosition[1], tStartPosition[2], tStartPosition[3]}
    if iSearchSizeMax == nil then iSearchSizeMax = 10 end
    if iSearchSizeMin == nil then iSearchSizeMin = 2 end
    local iRandomX, iRandomZ
    local iCurSizeCycleCount = 0
    local iCycleSize = 8
    local iSignageX, iSignageZ
    local iMaxCycles = (iOptionalMaxCycleOverride or 5)
    local iCurCycle = 0
    local iValidLocationCount = 0
    local tValidLocations = {}
    local tValidDistanceToEnemy = {}
    local tValidDistanceToBuilder = {}
    local iMinDistanceToBuilder = 10000
    local iMaxDistanceToBuilder = 0
    local iMaxDistanceToEnemy = 0
    local iCurDistanceToEnemy, iCurDistanceToBuilder
    local iCurPriority = 0
    local iMaxPriority = -1000000
    local tBuilderPosition
    local oBuilderBP, iBuilderRange
    if oBuilder and oBuilder.GetPosition then
        tBuilderPosition = oBuilder:GetPosition()
        oBuilderBP = oBuilder:GetBlueprint()
        if oBuilderBP.Economy and oBuilderBP.Economy.MaxBuildDistance then iBuilderRange = oBuilderBP.Economy.MaxBuildDistance end
    else
        M27Utilities.ErrorHandler('oBuilder is nil or has no position')
        tBuilderPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    end


    local iEnemyStartPosition = M27Logic.GetNearestEnemyStartNumber(aiBrain)
    local tEnemyStartPosition = M27MapInfo.PlayerStartPoints[iEnemyStartPosition]
    local tNewBuildingSize
    if sBlueprintToBuild then tNewBuildingSize = M27UnitInfo.GetBuildingSize(sBlueprintToBuild) end
    if tNewBuildingSize == nil then
        M27Utilities.ErrorHandler('sBlueprintToBuild is nil or has no building size')
        tNewBuildingSize = {0,0}
    end
    local fSizeMod = 0.5
    local iNewBuildingRadius = tNewBuildingSize[1] * fSizeMod
    local iMaxDistanceToBuildWithoutMoving = iBuilderRange + iNewBuildingRadius
    local sPathing = M27UnitInfo.GetUnitPathingType(oBuilder)
    local iBuilderPathingGroup = M27MapInfo.GetUnitSegmentGroup(oBuilder)
    local iCurPathingGroup
    local iCurSegmentX, iCurSegmentZ
    local iGroupCycleCount = 0

    local tSignageX = {1, 1, 1, 0, -1, -1, -1, 0}
    local tSignageZ = {1, 0, -1, -1, -1, 0, 1, 1}
    local iRandomDistance
    --[[local tPathingAdjust = {    {0, 0},
                                {-iNewBuildingRadius, -iNewBuildingRadius},
                                {iNewBuildingRadius, -iNewBuildingRadius},
                                {-iNewBuildingRadius, iNewBuildingRadius},
                                {iNewBuildingRadius, iNewBuildingRadius},
                            }--]]


    while iValidLocationCount == 0 do
        iGroupCycleCount = iGroupCycleCount + 1
        if bDebugMessages == true then LOG(sFunctionRef..': Start of main loop grouping, iGroupCycleCount='..iGroupCycleCount..'; iCycleSize='..iCycleSize..'; iValidLocationCount='..iValidLocationCount) end
        if iGroupCycleCount > iMaxCycles then
            if iMaxCycles >= 5 then --Sometimes we may be ok with not finding anywhere to build, e.g. for rally points
                M27Utilities.ErrorHandler('Possible infinite loop - unable to find anywhere to build despite iSearchSizeMax='..iSearchSizeMax..'; aiBrain index='..aiBrain:GetArmyIndex()..'; start number='..aiBrain.M27StartPositionNumber..'; sBlueprintToBuild='..(sBlueprintToBuild or 'nil')..'; Builder='..oBuilder:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oBuilder)..'; UC='..GetEngineerUniqueCount(oBuilder)..'; will check pathing and rerun if pathing changes if not already checked, bAlreadyRecheckedPathing='..tostring(bAlreadyRecheckedPathing or false))
                if not(bAlreadyRecheckedPathing) and M27MapInfo.RecheckPathingOfLocation(sPathing, oBuilder, tStartPosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then
                    LOG(sFunctionRef..': Pathing was incorrect and has now changed so will refun function')
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    return FindRandomPlaceToBuild(aiBrain, oBuilder, tStartPosition, sBlueprintToBuild, iSearchSizeMin, iSearchSizeMax, false, nil, true)
                else
                    LOG('Pathing='..sPathing..'; Engineer pathing group='..M27MapInfo.GetSegmentGroupOfLocation(sPathing, oBuilder:GetPosition())..'; target position group='..M27MapInfo.GetSegmentGroupOfLocation(sPathing, tTargetLocation)..'; our base group='..M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]))
                end
            end
            break
        end
        iRandomDistance = math.random(iSearchSizeMin, iSearchSizeMax)
        if bDebugMessages == true then LOG(sFunctionRef..': Picking random distance='..iRandomDistance..'; iSearchSizeMin='..iSearchSizeMin..'; iSearchSizeMax='..iSearchSizeMax..'; iGroupCycleCount='..iGroupCycleCount) end
        for iCurSizeCycleCount = 1, iCycleSize do
            iSignageX = tSignageX[iCurSizeCycleCount]
            iSignageZ = tSignageZ[iCurSizeCycleCount]
            iRandomX = iRandomDistance * iSignageX + tStartPosition[1]
            iRandomZ = iRandomDistance * iSignageZ + tStartPosition[3]
            if iRandomX < (iMapBoundMinX + iNewBuildingRadius) then iRandomX = iMapBoundMinX + iNewBuildingRadius
            elseif iRandomX > (iMapBoundMaxX - iNewBuildingRadius) then iRandomX = iMapBoundMaxX - iNewBuildingRadius end
            if iRandomZ < (iMapBoundMinZ + iNewBuildingRadius) then iRandomZ = iMapBoundMinZ + iNewBuildingRadius
            elseif iRandomZ > (iMapBoundMaxZ - iNewBuildingRadius) then iRandomZ = iMapBoundMaxZ - iNewBuildingRadius end

            tTargetLocation = {iRandomX, GetTerrainHeight(iRandomX, iRandomZ), iRandomZ}
            if bDebugMessages == true then LOG(sFunctionRef..': Checking if can build at location '..repr(tTargetLocation)) end
            if aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation) == true then
                --Check not blocking a mex
                if bDebugMessages == true then LOG(sFunctionRef..': Can build structure at the location, checking if will block mex') end
                if WillBuildingBlockMex(sBlueprintToBuild, tTargetLocation) == false then
                    --Is it either in range of the engineer or in the same pathing group?
                    iCurDistanceToBuilder = M27Utilities.GetDistanceBetweenPositions(tTargetLocation, tBuilderPosition)
                    local bEngineerCanBuild = false
                    if iCurDistanceToBuilder < iMaxDistanceToBuildWithoutMoving then bEngineerCanBuild = true
                    else
                        --Check both target and the build area appear to be in the same group
                        bEngineerCanBuild = true
                        if not(iBuilderPathingGroup == M27MapInfo.GetSegmentGroupOfLocation(sPathing, tTargetLocation)) then bEngineerCanBuild = false end

                        --[[for iAdjEntry, tAdjust in tPathingAdjust do
                            if not(iBuilderPathingGroup == M27MapInfo.GetSegmentGroupOfLocation(sPathing, { tTargetLocation[1] + tAdjust[1], tTargetLocation[2], tTargetLocation[3] + tAdjust[2] })) then
                                bEngineerCanBuild = false
                                break
                            end
                        end--]]
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': Wont block mex, checking if in range of engineer or in same pathing group. bEngineerCanBuild='..tostring(bEngineerCanBuild)) end
                    if bEngineerCanBuild == true then
                        iValidLocationCount = iValidLocationCount + 1
                        tValidLocations[iValidLocationCount] = tTargetLocation
                        iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tEnemyStartPosition, tTargetLocation)
                        tValidDistanceToEnemy[iValidLocationCount] = iCurDistanceToEnemy
                        if iCurDistanceToEnemy > iMaxDistanceToEnemy then iMaxDistanceToEnemy = iCurDistanceToEnemy end
                        tValidDistanceToBuilder[iValidLocationCount] = iCurDistanceToBuilder
                        if iCurDistanceToBuilder > iMaxDistanceToBuilder then iMaxDistanceToBuilder = iCurDistanceToBuilder end
                        if iCurDistanceToBuilder < iMinDistanceToBuilder then iMinDistanceToBuilder = iCurDistanceToBuilder end
                        if bDebugMessages == true then LOG(sFunctionRef..': Have a valid location taht engineers can path to; tTargetLocation='..repr(tTargetLocation)..'; iValidLocationCount='..iValidLocationCount) end
                    end
                end
            end
            if iCurSizeCycleCount == iCycleSize then
                iSearchSizeMin = iSearchSizeMax
                iSearchSizeMax = math.min(iSearchSizeMax * 1.25, iSearchSizeMax + 10)
            end
            if bDebugMessages == true then M27Utilities.DrawLocation(tTargetLocation) end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Finished looping through locations, iValidLocationCount='..iValidLocationCount) end
    if iValidLocationCount > 0 then
        --Pick the best valid location that we have
        if bDebugMessages == true then LOG(sFunctionRef..': Have a valid location count or '..iValidLocationCount..' so will pick the best location; possible locations to choose from='..repr(tValidLocations)) end
        local rBuildAreaRect
        for iCurLocation, tLocation in tValidLocations do
            rBuildAreaRect = Rect(tLocation[1] - iNewBuildingRadius, tLocation[3] - iNewBuildingRadius, tLocation[1] + iNewBuildingRadius, tLocation[3] + iNewBuildingRadius)
            if M27MapInfo.GetReclaimInRectangle(1, rBuildAreaRect) == false then iCurPriority = iCurPriority + 3 end
            if AreMobileUnitsInRect(rBuildAreaRect) == false then iCurPriority = iCurPriority + 3 end
            if tValidDistanceToEnemy[iCurLocation] >= iMaxDistanceToEnemy then iCurPriority = iCurPriority + 1 end
            iCurDistanceToBuilder = tValidDistanceToBuilder[iValidLocationCount]
            if iCurDistanceToBuilder <= iMaxDistanceToBuildWithoutMoving then
                iCurPriority = iCurPriority + 3
            --else
                --iCurSegmentX, iCurSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tLocation)
                --iCurPathingGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iCurSegmentX, iCurSegmentZ)
                --if not(iCurPathingGroup == iBuilderPathingGroup) then
                    --iCurPriority = iCurPriority - 40
                    --if iCurDistanceToBuilder == iMinDistanceToBuilder then iCurPriority = iCurPriority + 20 end --If only have places that cant path to, then want the cloest one as are most likely to be able to build
                --end
            end
            if iCurDistanceToEnemy >= iMinDistanceToBuilder then iCurPriority = iCurPriority + 1 end
            if iMaxDistanceToBuilder - iMinDistanceToBuilder > 0 then
                iCurPriority = iCurPriority + 2 * (iCurDistanceToBuilder - iMinDistanceToBuilder) / (iMaxDistanceToBuilder - iMinDistanceToBuilder)
            end

            if iCurPriority > iMaxPriority then
                iMaxPriority = iCurPriority
                tTargetLocation = tLocation
                if bDebugMessages == true then LOG(sFunctionRef..': New highest priority location, iCurPriority='..iCurPriority..'; tTargetLocation='..repr(tTargetLocation)) end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Finished considering iCurLocation='..iCurLocation..'; tLocation='..repr(tLocation)..'; iCurPriority='..iCurPriority..'; iMaxPriority='..iMaxPriority..'; iCurDistanceToBuilder='..iCurDistanceToBuilder..'; iMaxDistanceToBuildWithoutMoving='..iMaxDistanceToBuildWithoutMoving..'; iMinDistanceToBuilder='..iMinDistanceToBuilder) end
        end
    else
        tTargetLocation = nil
        if iMaxCycles >= 5 then
            M27Utilities.ErrorHandler('Failed to find a random place to build that engineer can path to, will check pathing and re-run this function if this is the first time')
        end


    end

    if bDebugMessages == true then
        if M27Utilities.IsTableEmpty(tTargetLocation) == false then
            LOG(sFunctionRef..'; Found random place to build, which is tTargetLocation='..repr(tTargetLocation)..'; aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation)='..tostring(aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation)))
        else LOG(sFunctionRef..': Couldnt find anywhere to build')
        end
        LOG(sFunctionRef..': End of code')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tTargetLocation
end

function WillBuildingBlockMex(sNewBuildingBPID, tPositionOfNewBuilding)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'WillBuildingBlockMex'
      M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --returns true if building will build by a mex; will only check outer border of the buildingID, i.e. assumes mex location wont be inside this since hten we couldnt build anyway
    --MassPoints = {} -- Stores position of each mass point (as a position value, i.e. a table with 3 values, x, y, z
    --tMexPointsByLocationRef = {} --As per mass points, but the key is the locationref value, and it returns the position

    --Mex has a size 2x2 so centre of mex will have 1 space to either side
    --So if e.g. we're building T1 power, which is also 2x2 building, then will block a mex if mex is +/-2 from midpoint of t1 power on x or z (but not +/- 2 on both, so should be 12 combinations that are testing
    --If instead dealing with 4x4 building, then is up to +/-3
    --If instead dealing with 1x1 building, then is up to +/- 1
    --so formula for the max +/- is the floor of the radius + 1

    local tBuildingSize = M27UnitInfo.GetBuildingSize(sNewBuildingBPID)
    local iSizeX = math.floor(tBuildingSize[1] * 0.5 + 3) --if were to build a T1 power right by a mex, then it woudl show as 2 away; 1 being the power's radius, 1 being the mexes' radius.  We want at least 4 away, to allow space for mass storage; building size*0.5 returns radius of the building we're considering
    local iSizeZ = math.floor(tBuildingSize[2] * 0.5 + 3)
    local iBuildingSizeRadius = math.max(iSizeX, iSizeZ)
    --local sLocationRef
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return not(M27Utilities.IsTableEmpty(M27MapInfo.GetResourcesNearTargetLocation(tPositionOfNewBuilding, iBuildingSizeRadius, true)))

    --[[if bDebugMessages == true then LOG(sFunctionRef..': tMexPointsByLocationRef='..repr(M27MapInfo.tMexPointsByLocationRef)..'; tBuildingSize='..repr(tBuildingSize)..'; sNewBuildingBPID='..sNewBuildingBPID..'; tPositionOfNewBuilding='..repr(tPositionOfNewBuilding)) end
    for iModX = -iSizeX, iSizeX, 1 do
        for iModZ = -iSizeZ, iSizeZ, 1 do
            if iModZ <= -iSizeZ or iModZ >= iSizeZ or iModX <= -iSizeX or iModX >= iSizeX then
                if not (math.abs(iModX) == iSizeX and math.abs(iModZ) == iSizeZ) then
                    sLocationRef = M27Utilities.ConvertLocationToReference({tPositionOfNewBuilding[1] + iModX, 0, tPositionOfNewBuilding[3] + iModZ})
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': iSizeX='..iSizeX..'; iSizeZ='..iSizeZ..'; iModX='..iModX..'; iModZ='..iModZ..'; tPositionOfNewBuilding='..repr(tPositionOfNewBuilding)..'; sLocationRef='..sLocationRef)
                        M27Utilities.DrawLocation({tPositionOfNewBuilding[1] + iModX, GetTerrainHeight(tPositionOfNewBuilding[1] + iModX, tPositionOfNewBuilding[3] + iModZ), tPositionOfNewBuilding[3] + iModZ}, nil, 1, 100)
                    end

                    if M27MapInfo.tMexPointsByLocationRef[sLocationRef] then
                        if bDebugMessages == true then LOG(sFunctionRef..': Mex identified near building, so will return that are blocking') end
                        return true
                    end
                end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': No mexes identified around target building') end
    return false--]]
end

function GetBestBuildLocationForTarget(tablePosTarget, sTargetBuildingBPID, sNewBuildingBPID, bCheckValid, aiBrain, bReturnOnlyBestMatch, pBuilderPos, iMaxAreaToSearch, iBuilderRange, bIgnoreOutsideBuildArea, bBetterIfNoReclaim, bPreferCloseToEnemy, bPreferFarFromEnemy, bLookForQueuedBuildings)
    --Returns all co-ordinates that will result in a sNewBuildingBPID being built adjacent to PosTarget; if bCheckValid is true (default) then will also check it's a valid location to build
    -- tablePosTarget can either be a table (e.g. a table of mex locations), or just a single position
    --Only need to specify aiBrain if bCheckValid = true
    --bIgnoreOutsideBuildArea - if true then ignore any locations outside of the builder's build area
    --bReturnOnlyBestMatch: if true then applies prioritisation and returns only the best match
    --bBetterIfNoReclaim - if true, then will ignore any build location that contains any reclaim (to avoid ACU trying to build somewhere that it has to walk to and reclaim)
    --bPreferCloseToEnemy, bPreferFarFromEnemy - optional variables, if either is set then will give +0.5 priority to locations that are closer/further to enemy
    --bLookForQueuedBuildings - optional, defaults to true, if true then check if any engineer has been assigned to buidl to that location already

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --True if want most log messages to print
    local sFunctionRef = 'GetBestBuildLocationForTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end



    if bCheckValid == nil then bCheckValid = false end
    if aiBrain == nil then bCheckValid = false end
    if bReturnOnlyBestMatch == nil then bReturnOnlyBestMatch = false end
    local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    local iEnemyStartPosition = M27Logic.GetNearestEnemyStartNumber(aiBrain)
    local tEnemyStartPosition = M27MapInfo.PlayerStartPoints[iEnemyStartPosition]
    local iDistanceToEnemy
    local iMinDistanceToEnemy = 10000
    local iMaxDistanceToEnemy = 0
    if pBuilderPos == nil then
        ErrorHandler('pBuilderPos is nil')
        pBuilderPos = tStartPosition
        bIgnoreOutsideBuildArea = false
    end
    if iBuilderRange == nil then iBuilderRange = 5 end
    if iMaxAreaToSearch == nil then iMaxAreaToSearch = iBuilderRange + 10 end
    if bIgnoreOutsideBuildArea == nil then bIgnoreOutsideBuildArea = false end
    if bBetterIfNoReclaim == nil then bBetterIfNoReclaim = false end
    if bLookForQueuedBuildings == nil then bLookForQueuedBuildings = true end

    local bWantAdjacency = true

    if sTargetBuildingBPID == nil then
        bWantAdjacency = false
    end

    local bDontBuildByMex = true
    if bWantAdjacency and EntityCategoryContains(categories.MASSEXTRACTION, sTargetBuildingBPID) then bDontBuildByMex = false end
    if bDebugMessages == true then LOG(sFunctionRef..': sNewBuildingBPID='..sNewBuildingBPID..'; sTargetBuildingBPID='..(sTargetBuildingBPID or 'nil')..'; tablePosTarget='..repr(tablePosTarget)..'; bBetterIfNoReclaim='..tostring(bBetterIfNoReclaim or false)) end
    --local TargetSize = GetBuildingTypeInfo(TargetBuildingType, 1)
    local TargetSize
    if bWantAdjacency then TargetSize = M27UnitInfo.GetBuildingSize(sTargetBuildingBPID) end

    --local tNewBuildingSize = GetBuildingTypeInfo(NewBuildingType, 1)
    local tNewBuildingSize = M27UnitInfo.GetBuildingSize(sNewBuildingBPID)
    local fSizeMod = 0.5
    local iRectangleSizeReduction = 0
    local iNewBuildingRadius = tNewBuildingSize[1] * fSizeMod
    if bDebugMessages == true and bWantAdjacency then LOG(sFunctionRef..': TargetSize='..repr(TargetSize)..'; NewBuildingSize='..repr(tNewBuildingSize)) end
    local iBuildRangeExtension = iNewBuildingRadius
    if bDebugMessages == true then LOG(sFunctionRef..': Increasing builder distance from '..iBuilderRange..' by '..iBuildRangeExtension) end
    iBuilderRange = iBuilderRange + iBuildRangeExtension
    iMaxAreaToSearch = math.max(iMaxAreaToSearch, iBuilderRange + tNewBuildingSize[1])


    local iMaxX, iMinX, iMaxZ, iMinZ, iTargetMaxX, iTargetMinX, iTargetMaxZ, iTargetMinZ, OptionsX, OptionsZ
    local iNewX, iNewZ
    local iValidPosCount = 0
    local CurPosition = {}
    local PossiblePositions = {}
    local iValidPositionPriorities = {}
    local iValidPositionDistanceToEnemy = {}
    local iPriority
    local iDistanceBetween
    local iMaxPriority = -100
    local tBestPosition = {}
    local bMultipleTargets = M27Utilities.IsTableArray(tablePosTarget[1])
    local iTotalTargets = 1
    local PosTarget = {}
    if bMultipleTargets == true then iTotalTargets = M27Utilities.GetTableSize(tablePosTarget) end
    local bNewBuildingLargerThanNewTarget = false
    if TargetSize[1] < tNewBuildingSize[1] or TargetSize[2] < tNewBuildingSize[2] then bNewBuildingLargerThanNewTarget = true end

    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iMaxMapX = rPlayableArea[3]
    local iMaxMapZ = rPlayableArea[4]
    local bHaveGoodMatch
    local iMapBoundarySize = 4
    local iActualMaxSearchRange
    local iIncrementSize = 4
    if bWantAdjacency then
        iIncrementSize = 1
        iActualMaxSearchRange = math.min(iMaxAreaToSearch + iNewBuildingRadius, TargetSize[1] * fSizeMod + iNewBuildingRadius)
        else iActualMaxSearchRange = math.min(iMaxAreaToSearch + iNewBuildingRadius, iBuilderRange)
    end
    if bDebugMessages == true then LOG(sFunctionRef..': About to try and build '..sNewBuildingBPID..' adjacent to '..(sTargetBuildingBPID or 'nil')..'; bDontBuildByMex='..tostring(bDontBuildByMex)..'; iTotalTargets='..iTotalTargets) end

    for iCurTarget = 1, iTotalTargets do
        if bMultipleTargets == true then
            PosTarget = tablePosTarget[iCurTarget]
        else
            PosTarget = tablePosTarget
        end
        --LOG('PosTarget[1]='..PosTarget[1])
        --LOG('TargetSize[1]='..TargetSize[1])
        --LOG('tNewBuildingSize[1]='..tNewBuildingSize[1])
        if bWantAdjacency then
            iMaxX = PosTarget[1] + TargetSize[1] * fSizeMod + iNewBuildingRadius
            if iMaxX > (iMaxMapX - iNewBuildingRadius) then iMaxX = iMaxMapX - iNewBuildingRadius end
            iMinX = PosTarget[1] - TargetSize[1] * fSizeMod - tNewBuildingSize[1]* fSizeMod
            if iMinX < (rPlayableArea[1] + iMapBoundarySize + iNewBuildingRadius) then iMinX = rPlayableArea[1] + iMapBoundarySize + iNewBuildingRadius end
            iMaxZ = PosTarget[3] + TargetSize[2] * fSizeMod + tNewBuildingSize[2]* fSizeMod
            if iMaxZ > (iMaxMapZ - iNewBuildingRadius) then iMaxZ = iMaxMapZ - iNewBuildingRadius end
            iMinZ = PosTarget[3] - TargetSize[2] * fSizeMod - tNewBuildingSize[2]* fSizeMod
            if iMinZ < (rPlayableArea[2] + iMapBoundarySize + iNewBuildingRadius) then iMinZ = rPlayableArea[2] + iMapBoundarySize + iNewBuildingRadius end

            iTargetMaxX = PosTarget[1] + TargetSize[1] * fSizeMod
            iTargetMinX = PosTarget[1] - TargetSize[1] * fSizeMod
            iTargetMaxZ = PosTarget[3] + TargetSize[2] * fSizeMod
            iTargetMinZ = PosTarget[3] - TargetSize[2] * fSizeMod
        else --Not interested in adjacency
            iMaxX = math.min(PosTarget[1] + iActualMaxSearchRange, iMaxMapX - iNewBuildingRadius)
            iMinX = math.max(PosTarget[1] - iActualMaxSearchRange,  rPlayableArea[1] + iMapBoundarySize + iNewBuildingRadius)
            iMaxZ = math.min(PosTarget[3] + iActualMaxSearchRange, iMaxMapZ - iNewBuildingRadius)
            iMinZ = math.max(PosTarget[3] - iActualMaxSearchRange,  rPlayableArea[2] + iMapBoundarySize + iNewBuildingRadius)
            if bDebugMessages == true then LOG(sFunctionRef..': Dont have adjancy so X Min-Max='..iMinX..'-'..iMaxX..'; Z Min-Max='..iMinZ..'-'..iMaxZ..'; iActualMaxSearchRange='..iActualMaxSearchRange) end
        end
        OptionsX = math.floor(iMaxX - iMinX)
        OptionsZ = math.floor(iMaxZ - iMinZ)
        if bDebugMessages == true then LOG(sFunctionRef..':About to cycle through potential adjacency locations for iCurTarget='..iCurTarget..'; iTotalTargets='..iTotalTargets..'; iMinX-iMaxX='..iMinX..'-'..iMaxX..'; iMinZ-iMaxZ='..iMinZ..'-'..iMaxZ..'; OptionsX='..OptionsX..'; OptionsZ='..OptionsZ..'; bWantAdjacency='..tostring(bWantAdjacency))end

        for xi = 0, OptionsX, iIncrementSize do
            iNewX = iMinX + xi
            --if iNewX >= (iMinX + TargetSize[1]*fSizeMod) or iNewX >= (iTargetMaxX - iNewBuildingRadius) then
            for zi = 0, OptionsZ, iIncrementSize do
                iPriority = 0
                iNewZ = iMinZ + zi

                --if iNewZ < (iTargetMinZ + tNewBuildingSize[2]* fSizeMod) or iNewZ > (iTargetMaxZ - tNewBuildingSize[2]* fSizeMod) then
                --ignore corner results (new building larger than target):
                local bIgnore = false
                if bWantAdjacency then
                    if bNewBuildingLargerThanNewTarget == true then
                        if iNewX - iNewBuildingRadius > iTargetMinX or iNewX + iNewBuildingRadius < iTargetMaxX then
                            if iNewZ - iNewBuildingRadius > iTargetMinZ or iNewZ + iNewBuildingRadius < iTargetMaxZ then
                                iPriority = iPriority - 4
                                --bIgnore = true
                                if bDebugMessages == true then LOG(sFunctionRef..': Corner position so no adjacency - priority decreased; iNewX='..iNewX..'; iNewZ='..iNewZ) end
                            end
                        end
                    else
                        if iNewX >= iTargetMinX and iNewX <= iTargetMaxX then
                            if bDebugMessages == true then LOG(sFunctionRef..': x value is within the required range for adjacency, now checking if z values are') end
                            --z value needs to be right by the min or max values:
                            if iNewZ == (iTargetMinZ - iNewBuildingRadius) or iNewZ == (iTargetMaxZ + iNewBuildingRadius) then
                                --valid co-ordinate
                                    if bDebugMessages == true then LOG(sFunctionRef..': Should benefit from adjacency') end
                            else
                                --If it's within the target building area then ignore, otherwise record with lower priority as no adjacency:
                                if iNewZ < (iTargetMinZ - iNewBuildingRadius) or iNewZ > (iTargetMaxZ + iNewBuildingRadius) then
                                    iPriority = iPriority - 4
                                else bIgnore = true end
                                if bDebugMessages == true then LOG(sFunctionRef..': NewBuilding <= NewTarget size 1 - failed to find adjacency match so reducing priority by 4; iNewX='..iNewX..'; iNewZ='..iNewZ..'; iTargetMinX='..iTargetMinX..'; iTargetMaxX='..iTargetMaxX..'; iTargetMinZ='..iTargetMinZ..'; iTargetMaxZ='..iTargetMaxZ..'; iNewBuildingRadius='..iNewBuildingRadius..'; tNewBuildingSize[1] * fSizeMod='..tNewBuildingSize[1] * fSizeMod) end
                            end
                        else
                            if iNewZ >= iTargetMinZ and iNewZ <= iTargetMaxZ then
                                if iNewX == (iTargetMinX - iNewBuildingRadius) or iNewX == (iTargetMaxX + iNewBuildingRadius) then
                                    --Valid match
                                    if bDebugMessages == true then LOG(sFunctionRef..': Should benefit from adjacency') end
                                else
                                    --If it's within the target building area then ignore, otherwise record with lower priority as no adjacency:
                                    if iNewX < (iTargetMinX - iNewBuildingRadius) or iNewX > (iTargetMaxX + iNewBuildingRadius) then
                                        iPriority = iPriority - 4
                                    else bIgnore = true end
                                    if bDebugMessages == true then LOG(sFunctionRef..': NewBuilding <= NewTarget size 2 - failed to find adjacency match so reducing priority by 4; iNewX='..iNewX..'; iNewZ='..iNewZ..'; iTargetMinX='..iTargetMinX..'; iTargetMaxX='..iTargetMaxX..'; iTargetMinZ='..iTargetMinZ..'; iTargetMaxZ='..iTargetMaxZ..'; iNewBuildingRadius='..iNewBuildingRadius..'; tNewBuildingSize[1] * fSizeMod='..tNewBuildingSize[1] * fSizeMod) end
                                end
                            else
                                if (iNewX < (iTargetMinX - iNewBuildingRadius) or iNewX > (iTargetMaxX + iNewBuildingRadius)) and (iNewZ < (iTargetMinZ - iNewBuildingRadius) or iNewZ > (iTargetMaxZ + iNewBuildingRadius)) then
                                    --should be valid just no adjacency
                                    iPriority = iPriority - 4
                                else bIgnore = true end
                                if bDebugMessages == true then LOG(sFunctionRef..': NewBuilding <= NewTarget size 3 - failed to find adjacency match so reducing priority by 4; iNewX='..iNewX..'; iNewZ='..iNewZ..'; iTargetMinX='..iTargetMinX..'; iTargetMaxX='..iTargetMaxX..'; iTargetMinZ='..iTargetMinZ..'; iTargetMaxZ='..iTargetMaxZ..'; iNewBuildingRadius='..iNewBuildingRadius..'; tNewBuildingSize[1] * fSizeMod='..tNewBuildingSize[1] * fSizeMod) end
                            end
                        end
                        -- If bCheckValid then see if aiBrain can build the desired structure at the location
                    end
                end
                if bIgnore == false and bLookForQueuedBuildings == true then

                    local sLocationRef = M27Utilities.ConvertLocationToReference({iNewX, 0, iNewZ})
                    --reftEngineerAssignmentsByLocation --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the engineer unique ref assigned to this location
                    if aiBrain[reftEngineerAssignmentsByLocation] and aiBrain[reftEngineerAssignmentsByLocation][sLocationRef] then
                        if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef]) == false then bIgnore = true end
                    end
                end
                    --Check if already queued up
                local rBuildAreaRect
                if bIgnore == false then
                    --Check for reclaim:
                    if bBetterIfNoReclaim == true then

                        rBuildAreaRect = Rect(iNewX - iNewBuildingRadius + iRectangleSizeReduction, iNewZ - iNewBuildingRadius + iRectangleSizeReduction, iNewX + iNewBuildingRadius - iRectangleSizeReduction, iNewZ + iNewBuildingRadius - iRectangleSizeReduction)
                        --ReturnType: 1 = true/false: GetReclaimInRectangle(iReturnType, rRectangleToSearch)
                        if M27MapInfo.GetReclaimInRectangle(1, rBuildAreaRect) == true then iPriority = iPriority - 4 end
                        if bDebugMessages == true then
                            if iNewX == 881.5 and iNewZ == 662.5 then
                                LOG('Dealing with specific area of interest for debug')
                                LOG(sFunctionRef..': Want to avoid reclaim if we can; Checking if any reclaim in the area, rBuildAreaRec='..repr(rBuildAreaRect)..'; iNewBuildingRadius='..iNewBuildingRadius..'; iRectangleSizeReduction='..iRectangleSizeReduction..'; iNewX-Z='..iNewX..'-'..iNewZ..'; M27MapInfo.GetReclaimInRectangle(1, rBuildAreaRect)='..tostring((M27MapInfo.GetReclaimInRectangle(1, rBuildAreaRect, true) or false)))
                            else
                                LOG(sFunctionRef..': Want to avoid reclaim if we can; Checking if any reclaim in the area, rBuildAreaRec='..repr(rBuildAreaRect)..'; iNewBuildingRadius='..iNewBuildingRadius..'; iRectangleSizeReduction='..iRectangleSizeReduction..'; iNewX-Z='..iNewX..'-'..iNewZ..'; M27MapInfo.GetReclaimInRectangle(1, rBuildAreaRect)='..tostring((M27MapInfo.GetReclaimInRectangle(1, rBuildAreaRect) or false)))
                            end
                        end
                    end
                end
                if bIgnore ==  false then
                    CurPosition = {iNewX, GetTerrainHeight(iNewX, iNewZ), iNewZ}
                    if bCheckValid then
                        --if aiBrain:CanBuildStructureAt(GetBuildingTypeInfo(NewBuildingType, 2), CurPosition) == false then
                        if aiBrain:CanBuildStructureAt(sNewBuildingBPID, CurPosition) == false then
                            bIgnore = true
                            if bDebugMessages == true then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef..': aiBrain cant build at iNewX='..iNewX..'; iNewZ='..iNewZ..'; CurPosition='..CurPosition[1]..'-'..CurPosition[2]..'-'..CurPosition[3])
                                end
                            end
                        end
                    end
                end
                --Ignore if -ve priority and already have better:
                if iPriority < 0 and iMaxPriority > iPriority then
                    if bDebugMessages == true then LOG(sFunctionRef..': Ignoring location as priority too low; iPriority='..iPriority..';iMaxPriority='..iMaxPriority..'; iNewX='..iNewX..'; iNewZ='..iNewZ) end
                    bIgnore = true end

                if bIgnore == false then
                    -- We now have a co-ordinate that should result in newbuilding being built adjacent to target building (unless negative priority); check other conditions/priorities
                    iPriority = iPriority + 1

                    if bDebugMessages == true then LOG(sFunctionRef..': Have valid build location, iPriority pre considering build distance='..iPriority..'; CurPosition[1]='..CurPosition[1]..'-'..CurPosition[2]..'-'..CurPosition[3]) end
                    if bIgnoreOutsideBuildArea == true or bReturnOnlyBestMatch == true then iDistanceBetween = M27Utilities.GetDistanceBetweenBuildingPositions(pBuilderPos, CurPosition, iNewBuildingRadius) end
                    --if bIgnoreOutsideBuildArea == true or bReturnOnlyBestMatch == true then iDistanceBetween = GetDistanceBetweenPositions(pBuilderPos, PosTarget) end
                    if bReturnOnlyBestMatch == true then
                        --Check if within build area:
                        if iDistanceBetween <= iMaxAreaToSearch then
                            if bDebugMessages == true then LOG(sFunctionRef..': Is within build area, iDistanceBetween='..iDistanceBetween..'; iMaxAreaToSearch='..iMaxAreaToSearch) end
                            if iDistanceBetween > 0 then
                                iPriority = iPriority + 4
                            else iPriority = iPriority + 1
                            end
                            if iDistanceBetween <= iBuilderRange then iPriority = iPriority + 2 end
                        end
                        --Deduct 3 if ACU would have to move to build - should hopefully be covered by above
                        --if pBuilderPos[1] >= iNewX - tNewBuildingSize[1] * fSizeMod and pBuilderPos[1] <= iNewX + tNewBuildingSize[1] * fSizeMod then
                        --if pBuilderPos[3] >= iNewZ - tNewBuildingSize[2] * fSizeMod and pBuilderPos[3] <= iNewX + tNewBuildingSize[2] * fSizeMod then
                        --iPriority = iPriority - 3
                        --end
                        --end
                        --Check if level with target (makes it easier for other buildings to get adjacency):
                        if bWantAdjacency then
                            if CurPosition[1] - iNewBuildingRadius == iTargetMinX then iPriority = iPriority + 1 end
                            if CurPosition[1] + iNewBuildingRadius == iTargetMaxX then iPriority = iPriority + 1 end
                            if CurPosition[3] - iNewBuildingRadius == iTargetMinZ then iPriority = iPriority + 1 end
                            if CurPosition[3] + iNewBuildingRadius == iTargetMaxZ then iPriority = iPriority + 1 end
                        end
                    end
                    if bIgnoreOutsideBuildArea == true then
                        if iDistanceBetween > iMaxAreaToSearch then
                            bIgnore = true
                            if bDebugMessages == true then LOG(sFunctionRef..': Ignoring as iDistanceBetween='..iDistanceBetween..'; normal dist='..M27Utilities.GetDistanceBetweenPositions(pBuilderPos, CurPosition)) end
                        else iPriority = iPriority - 2
                        end
                    end

                    --Check if any units in the area (if not then icnrease priority)
                    if AreMobileUnitsInRect(rBuildAreaRect) == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': No mobile units are in the build area rectangle='..repr(rBuildAreaRect)) end
                        iPriority = iPriority + 1
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': mobile units are in the build area rectangle='..repr(rBuildAreaRect)) end
                    end

                    --Check if want to weight for if its closer or further from start (jsut enough that it affects equal priority locations)
                    if bPreferCloseToEnemy or bPreferFarFromEnemy then
                        iDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(CurPosition, tEnemyStartPosition)
                        if iDistanceToEnemy < iMinDistanceToEnemy then iMinDistanceToEnemy = iDistanceToEnemy end
                        if iDistanceToEnemy > iMaxDistanceToEnemy then iMaxDistanceToEnemy = iDistanceToEnemy end
                    end

                    if bIgnore == false then
                        --Check not blocking a mex
                        if bDebugMessages == true then LOG(sFunctionRef..': About to check whether we will block a mex by building '..sNewBuildingBPID..' and CurPosition='..repr(CurPosition)) end
                        if bDontBuildByMex and WillBuildingBlockMex(sNewBuildingBPID, CurPosition) then bIgnore = true end
                        if bIgnore == false then
                            iValidPosCount = iValidPosCount + 1
                            PossiblePositions[iValidPosCount] = CurPosition
                            iValidPositionPriorities[iValidPosCount] = iPriority
                            iValidPositionDistanceToEnemy[iValidPosCount] = iDistanceToEnemy
                            if iPriority > iMaxPriority then
                                iMaxPriority = iPriority
                                if bReturnOnlyBestMatch == true then
                                    tBestPosition = CurPosition
                                end
                            end
                            if bDebugMessages == true then if bReturnOnlyBestMatch == true then LOG('iPriority='..iPriority..'; iDistanceBetween='..iDistanceBetween) end end
                            if bDebugMessages == true then LOG(sFunctionRef..': iValidPosCount='..iValidPosCount..'; PossiblePositions[iValidPosCount][1-2-3]='..PossiblePositions[iValidPosCount][1]..'-'..PossiblePositions[iValidPosCount][2]..'-'..PossiblePositions[iValidPosCount][3]..'; bReturnOnlyBestMatch='..tostring(bReturnOnlyBestMatch)) end
                        end
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': End of considering this option, bIgnore='..tostring(bIgnore)..'; iPriority='..iPriority) end
                --end
            end
            --end
        end
    end
    if iValidPosCount >= 1 then
        --Check if want to weight for if its closer or further from start (jsut enough that it affects equal priority locations)
        if bDebugMessages == true then LOG(sFunctionRef..': Considering if closest or furthest from enemy; bPreferCloseToEnemy='..tostring(bPreferCloseToEnemy)..'; bPreferFarFromEnemy='..tostring(bPreferFarFromEnemy)) end
        if bPreferCloseToEnemy or bPreferFarFromEnemy then
            for iPosition, tPosition in PossiblePositions do
                iDistanceToEnemy = iValidPositionDistanceToEnemy[iPosition]
                iPriority = iValidPositionPriorities[iPosition]
                bHaveGoodMatch = false
                if bPreferFarFromEnemy == true and iDistanceToEnemy >= iMaxDistanceToEnemy then bHaveGoodMatch = true
                elseif bPreferCloseToEnemy == true and iDistanceToEnemy <= iMinDistanceToEnemy then bHaveGoodMatch = true end
                if bDebugMessages == true then LOG(sFunctionRef..': iPosition='..iPosition..'; tPosition='..repr(tPosition)..'iPriority pre distance='..iPriority..'; iDistanceToEnemy='..iDistanceToEnemy..'; iMaxDistanceToEnemy='..iMaxDistanceToEnemy..'; iMinDistanceToEnemy='..iMinDistanceToEnemy..'; bHaveGoodMatch='..tostring(bHaveGoodMatch)) end
                if bHaveGoodMatch == true then
                    iPriority = iPriority + 0.5
                    if iPriority > iMaxPriority then
                        iMaxPriority = iPriority
                        tBestPosition = tPosition
                    end
                end
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Near end of code, will return value depending on specifics') end
        if bReturnOnlyBestMatch then
            if bDebugMessages == true then
                LOG(sFunctionRef..': Returning best possible position; tBestPosition[1]='..tBestPosition[1]..'-'..tBestPosition[2]..'-'..tBestPosition[3]..'; iMaxPriority='..iMaxPriority)
                LOG(sFunctionRef..': iMaxMapX='..iMaxMapX..'; iMaxMapZ='..iMaxMapZ..'tBestPosition='..repr(tBestPosition)..'; our start position='..repr(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]))
                M27Utilities.DrawLocations(PossiblePositions, nil, 3, 10)
                M27Utilities.DrawLocation(tBestPosition, nil, 7, 100) --draws best position in white
            end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return tBestPosition
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Returning table of possible positions; PossiblePositions[1][1]='..PossiblePositions[1][1]..'-'..PossiblePositions[1][2]..'-'..PossiblePositions[1][3]) end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return PossiblePositions
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': No valid matches found. PosTarget='..PosTarget[1]..'-'..PosTarget[3]) end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return nil
    end

end

function BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tAlternativePositionToLookFrom, bLookForPartCompleteBuildings, bLookForQueuedBuildings)
    --Determines the blueprint and location for oEngineer to build at; also returns the location
    --iCatToBuildBy: Optional, specify if want to look for adjacency locations; Note to factor in 50% of the builder's size and 50% of the likely adjacency building size
    --bLookForQueuedBuildings: Optional, if true, then doesnt choose a target if another engineer already has that target function ref assigned to build something
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'BuildStructureAtLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetEngineerUniqueCount(oEngineer) == 59 then bDebugMessages = true end
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, Engineer UC='..GetEngineerUniqueCount(oEngineer)..'; Engineer LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)) end



    local bAbortConstruction = false
    local sBlueprintToBuild = M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, iCategoryToBuild, oEngineer)--, false, false)
    local sBlueprintBuildBy
    local bFindRandomLocation = false
    local tTargetLocation = tAlternativePositionToLookFrom
    local tEngineerPosition = oEngineer:GetPosition()
    if not(tTargetLocation) then tTargetLocation = tEngineerPosition end
    local bFoundEnemyInstead = false
    local iNewBuildingRadius = M27UnitInfo.GetBuildingSize(sBlueprintToBuild)[1] * 0.5

    if sBlueprintToBuild == nil then
        M27Utilities.ErrorHandler('sBlueprintToBuild is nil, could happen e.g. if try and get sparky to build sxomething it cant - refer to log for more details')
        LOG('oEngineer='..oEngineer:GetUnitId()..GetEngineerUniqueCount(oEngineer))
    else

        local iBuilderRange = oEngineer:GetBlueprint().Economy.MaxBuildDistance + math.min(oEngineer:GetBlueprint().SizeX, oEngineer:GetBlueprint().SizeZ)*0.5
        local iDistanceFromStart = M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        local bBuildNearToEnemy = false
        if iDistanceFromStart <= 80 then bBuildNearToEnemy = true end

        --Check if is an existing building of the type wanted first:
        local oPartCompleteBuilding
        if bLookForPartCompleteBuildings then
                --GetPartCompleteBuilding(aiBrain, oBuilder, iCategoryToBuild, iBuildingSearchRange, iEnemySearchRange)
                --Returns nil if no nearby part complete building
                --iEnemySearchRange: nil if dont care about nearby enemies, otherwise will ignore buildings that have enemies within iEnemySearchRange
            oPartCompleteBuilding = GetPartCompleteBuilding(aiBrain, oEngineer, iCategoryToBuild, iBuilderRange + 15, nil)
        end
        if oPartCompleteBuilding then
            if bDebugMessages == true then LOG(sFunctionRef..': have partcompletebuilding so returning that as the position') end
            tTargetLocation = oPartCompleteBuilding:GetPosition()
        else
            if bDebugMessages == true then
                local sEngUniqueRef = GetEngineerUniqueCount(oEngineer)
                LOG(sFunctionRef..': Eng builder unique ref='..sEngUniqueRef..'; builder range='..iBuilderRange)
            end
            --Check we're not trying to buidl a mex or hydro or mass storage
            local bMexHydroOrStorage = false
            if EntityCategoryContains(refCategoryMex, sBlueprintToBuild) or EntityCategoryContains(refCategoryHydro, sBlueprintToBuild) or EntityCategoryContains(M27UnitInfo.refCategoryMassStorage, sBlueprintToBuild) then bMexHydroOrStorage = true end



            if not(bMexHydroOrStorage) then
                if iCatToBuildBy then
                    sBlueprintBuildBy = M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, iCatToBuildBy, oEngineer)--, false, false)
                    if bDebugMessages == true then LOG(sFunctionRef..': Engineer position='..repr(oEngineer:GetPosition())..'; tTargetLocation='..repr(tTargetLocation)..'; iMaxAreaToSearch='..iMaxAreaToSearch) end
                    local oPossibleBuildingsToBuildBy = aiBrain:GetUnitsAroundPoint(iCatToBuildBy, tTargetLocation, iMaxAreaToSearch, 'Ally')
                    local iBuildingCount = 0
                    local tPossibleTargets = {}
                    local tBuildingPosition
                    if M27Utilities.IsTableEmpty(oPossibleBuildingsToBuildBy) == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have possible buildings to build by, so will consider best location') end
                        for iBuilding, oBuilding in oPossibleBuildingsToBuildBy do
                            if not(oBuilding.Dead) and oBuilding.GetPosition then
                                tBuildingPosition = oBuilding:GetPosition()
                                if M27Utilities.GetDistanceBetweenPositions(tBuildingPosition, tTargetLocation) <= iMaxAreaToSearch then
                                    --Check we're not building by a mex
                                    --if M27Utilities.IsTableEmpty(M27MapInfo.GetResourcesNearTargetLocation(tBuildingPosition, iNewBuildingRadius, true)) == true then
                                        --if bDebugMessages == true then LOG(sFunctionRef..': No resources near the target build position') end
                                        iBuildingCount = iBuildingCount + 1
                                        tPossibleTargets[iBuildingCount] = tBuildingPosition
                                    --else
                                        --if bDebugMessages == true then LOG(sFunctionRef..': Have resources near the target build position') end
                                    --end
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Found iBuildingCount='..iBuildingCount..' to build by') end
                    else
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Cant find any buildings for adjacency, getting random location to build unless we want to build by a mex/hydro and have an unbuilt one nearby')
                            local tNearestBuildingOfCategory = aiBrain:GetUnitsAroundPoint(iCatToBuildBy, tTargetLocation, 10000, 'Ally')
                            if M27Utilities.IsTableEmpty(tNearestBuildingOfCategory) then LOG(sFunctionRef..': Dont have any units of the desired category anywhere on map')
                            else
                                local oNearestBuildingOfCategory = M27Utilities.GetNearestUnit(tNearestBuildingOfCategory, oEngineer:GetPosition(), aiBrain)
                                LOG(sFunctionRef..': Nearest unit of desired category is '..oNearestBuildingOfCategory:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oNearestBuildingOfCategory)..' which is '..M27Utilities.GetDistanceBetweenPositions(oNearestBuildingOfCategory:GetPosition(), oEngineer:GetPosition())..' away from the engineer')
                            end
                        end
                        bFindRandomLocation = true
                    end
                    --Also check for unbuilt buildings if dealing with a mex or hydro
                    local tResourceLocations
                    if EntityCategoryContains(M27UnitInfo.refCategoryMex, sBlueprintBuildBy) then
                        tResourceLocations = M27MapInfo.GetResourcesNearTargetLocation(tTargetLocation, 30, true)
                    elseif EntityCategoryContains(M27UnitInfo.refCategoryHydro, sBlueprintBuildBy) or EntityCategoryContains(M27UnitInfo.refCategoryT2Power, sBlueprintBuildBy) then --Dont want to make this all power, because the adjacency code requires a building size, and only works for a single building size; i.e. if try and get adjacency for t1 power and include hydro locations, then it will think it needs to build within the hydro for adjacency
                        tResourceLocations = M27MapInfo.GetResourcesNearTargetLocation(tTargetLocation, 30, false)
                    end
                    if M27Utilities.IsTableEmpty(tResourceLocations) == false then
                        for iResource, tCurResourceLocation in tResourceLocations do
                            iBuildingCount = iBuildingCount + 1
                            tPossibleTargets[iBuildingCount] = tCurResourceLocation
                        end
                    end
                    if iBuildingCount > 0 then
                                    --GetBestBuildLocationForTarget(tablePosTarget, sTargetBuildingBPID, sNewBuildingBPID, bCheckValid, aiBrain, bReturnOnlyBestMatch, pBuilderPos, iMaxAreaToSearch, iBuilderRange, bIgnoreOutsideBuildArea, bBetterIfNoReclaim, bPreferCloseToEnemy, bPreferFarFromEnemy, bLookForQueuedBuildings)
                        if bDebugMessages == true then LOG(sFunctionRef..': About to call GetBestBuildLocation; iBuildingCount='..iBuildingCount..'; sBlueprintBuildBy='..sBlueprintBuildBy) end
                        tTargetLocation = GetBestBuildLocationForTarget(tPossibleTargets, sBlueprintBuildBy, sBlueprintToBuild, true, aiBrain, true, tTargetLocation, iMaxAreaToSearch, iBuilderRange, false, true, bBuildNearToEnemy, not(bBuildNearToEnemy), bLookForQueuedBuildings)
                        if M27Utilities.IsTableEmpty(tTargetLocation) == true then
                            if bDebugMessages == true then LOG('Adjacency location is empty, will try finding anywhere to build') end
                            bFindRandomLocation = true
                        else
                            bFindRandomLocation = false
                            if aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation) == false then
                                M27Utilities.ErrorHandler('Cant build '..sBlueprintToBuild..' on adjacency location tTargetLocation='..repr(tTargetLocation))
                                bFindRandomLocation = true
                            else
                                --Check we're within mapBoundary
                                if bDebugMessages == true then LOG(sFunctionRef..': Checking if tTargetLocation '..repr(tTargetLocation)..' is in the playable area '..repr(M27MapInfo.rMapPlayableArea)..' based on building size radius='..iNewBuildingRadius) end
                                if (tTargetLocation[1] - iNewBuildingRadius) < M27MapInfo.rMapPlayableArea[1] or (tTargetLocation[3] - iNewBuildingRadius) < M27MapInfo.rMapPlayableArea[2] or (tTargetLocation[1] + iNewBuildingRadius) > M27MapInfo.rMapPlayableArea[3] or (tTargetLocation[3] + iNewBuildingRadius) > M27MapInfo.rMapPlayableArea[4] then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Target location isnt in playable area so will find random place to build instead') end
                                    bFindRandomLocation = true
                                    tTargetLocation = tEngineerPosition
                                end
                                if bDebugMessages == true then M27Utilities.DrawLocation(tTargetLocation) end
                            end
                        end
                    else
                        bFindRandomLocation = true
                        if bDebugMessages == true then LOG(sFunctionRef..': Cant find any valid buildings for adjacency') end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Dont have a category to build by, will look for random location unless current target is valid') end
                    bFindRandomLocation = true
                end
            else
                --Dealing with mex or hydro or storage
                if bDebugMessages == true then LOG(sFunctionRef..': Are trying to build a mex, hydro or storage; tTargetLocation='..repr((tTargetLocation or {}))..'; oEngineer='..GetEngineerUniqueCount(oEngineer)..'; LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)) end
                if M27Utilities.IsTableEmpty(tTargetLocation) == true then
                    M27Utilities.ErrorHandler('Trying to build mex, hydro or storage without defined location')
                else
                    if aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Can build structure at targetlocation='..repr(tTargetLocation)) end
                    else
                        --Cant build at location, is that because of enemy building blocking it, or we have a part-built building?
                        if bDebugMessages == true then LOG(sFunctionRef..': Are trying to build a mex or hydro or mass storage so cant get a random location, but we cant build a structure at the target') end
                        local tEnemyBuildingAtTarget = aiBrain:GetUnitsAroundPoint(iCategoryToBuild, tTargetLocation, 1, 'Enemy')
                        if M27Utilities.IsTableEmpty(tEnemyBuildingAtTarget) == false then
                            if bDebugMessages == true then LOG(sFunctionRef..': Have enemy buildings around target') end
                            M27PlatoonUtilities.MoveNearConstruction(aiBrain, oEngineer, tTargetLocation, sBlueprintToBuild, 0, false, false, false)
                            for iUnit, oUnit in tEnemyBuildingAtTarget do
                                if oUnit.GetPosition then
                                    IssueReclaim({oEngineer}, oUnit)
                                end
                            end
                            IssueBuildMobile({oEngineer}, tTargetLocation, sBlueprintToBuild, {})
                            bAbortConstruction = true
                            bFoundEnemyInstead = true
                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy building is at the target mex/hydro so will try and reclaim that first') end
                        else
                            local tAllyBuildingAtTarget = aiBrain:GetUnitsAroundPoint(iCategoryToBuild, tTargetLocation, 1, 'Ally')
                            if M27Utilities.IsTableEmpty(tAllyBuildingAtTarget) == false then
                                if bDebugMessages == true then LOG(sFunctionRef..': Will target the ally building as its part complete') end
                                oPartCompleteBuilding = tAllyBuildingAtTarget[1]
                            else
                                --Are we stopped from building due to reclaim?

                                local tNewBuildingSize = M27UnitInfo.GetBuildingSize(sBlueprintToBuild)
                                local fSizeMod = 0.5

                                local rTargetRect = M27Utilities.GetRectAroundLocation(tTargetLocation, tNewBuildingSize[1] * fSizeMod)
                                if bDebugMessages == true then LOG(sFunctionRef..': tTargetLocation='..repr(tTargetLocation)..'; tNewBuildingSize='..repr(tNewBuildingSize)..'; rTargetRect='..repr(rTargetRect)) end
                                --GetReclaimInRectangle(iReturnType, rRectangleToSearch)
                                --iReturnType: 1 = true/false; 2 = number of wrecks; 3 = total mass, 4 = valid wrecks
                                local tReclaimables = M27MapInfo.GetReclaimInRectangle(4, rTargetRect)

                                if M27Utilities.IsTableEmpty(tReclaimables) == false then
                                    for iReclaim, oReclaim in tReclaimables do
                                        --oEngineer:IssueReclaim(oReclaim)
                                        IssueReclaim({oEngineer}, oReclaim)
                                    end
                                    IssueBuildMobile({oEngineer}, tTargetLocation, sBlueprintToBuild, {})
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef..': Reclaim found that is blocking mex or hydro so will reclaim all wrecks in rectangle='..repr(rTargetRect))
                                        M27Utilities.DrawRectangle(rTargetRect, 7, 100)
                                    end
                                else
                                    --Are we trying to build a T3 mex? If so then we probably are trying to replace a T2 mex which  can lead to problems with the canbuild check
                                    if iCategoryToBuild == M27UnitInfo.refCategoryT3Mex then
                                        IssueBuildMobile({oEngineer}, tTargetLocation, sBlueprintToBuild, {})
                                        if bDebugMessages == true then LOG(sFunctionRef..': Not sure we can build here but will try anyway') end
                                    else
                                        --One likely explanation is that enemy has built on the mex and we cant see the building, in which case we only want to check this for debugging purposes, and proceed with the default action of having hte engineer try to move there
                                        local tUnits = GetUnitsInRect(rTargetRect)
                                        if M27Utilities.IsTableEmpty(tUnits) == true then
                                            M27Utilities.ErrorHandler(sFunctionRef..': Cant build at resource location but no units or reclaim on it, will just try moving near the target instead.  Will draw white circle around the target if in debug mode', nil, true)
                                            if bDebugMessages == true then
                                                M27Utilities.DrawLocation(tTargetLocation, nil, 7)
                                                LOG(sFunctionRef..': Cnat build at TargetLocation='..repr(tTargetLocation)..'; RectangleSearched='..repr(rTargetRect))
                                            end
                                        end
                                        M27PlatoonUtilities.MoveNearConstruction(aiBrain, oEngineer, tTargetLocation, sBlueprintToBuild, 0, false, false, false)
                                        bAbortConstruction = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        --Switch to random location if an amphibious unit cant path there
        if not(bFindRandomLocation) and not(bAbortConstruction) then
           if not(M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tTargetLocation) == M27MapInfo.GetUnitSegmentGroup(oEngineer)) then bFindRandomLocation = true end
        end

        if bFindRandomLocation == true and not(bAbortConstruction) then
            if bDebugMessages == true then LOG(sFunctionRef..': Are finding a random location to build unless current location is valid; sBlueprintToBuild='..sBlueprintToBuild) end
            if M27Utilities.IsTableEmpty(tTargetLocation) == true then tTargetLocation = tEngineerPosition end
            --First check in build area for the best location
            tTargetLocation = GetBestBuildLocationForTarget(tTargetLocation, nil, sBlueprintToBuild, true, aiBrain, true, tTargetLocation, iMaxAreaToSearch, iBuilderRange, false, true, bBuildNearToEnemy, not(bBuildNearToEnemy), false)
            if M27Utilities.IsTableEmpty(tTargetLocation) == true then
                tTargetLocation = tEngineerPosition
                if bDebugMessages == true then
                    LOG(sFunctionRef..' Cant build '..sBlueprintToBuild..' and '..repr(tTargetLocation)..'; will try and find a random place to build')
                    if iCategoryToBuild == nil then LOG(sFunctionRef..' iCategoryToBuild is nil somehow') end
                end
                --FindRandomPlaceToBuild(aiBrain, oBuilder, tStartPosition, sBlueprintToBuild, iSearchSizeMin, iSearchSizeMax, bForcedDebug)
                tTargetLocation = FindRandomPlaceToBuild(aiBrain, oEngineer, tTargetLocation, sBlueprintToBuild, 2, iMaxAreaToSearch, bDebugMessages)
                if M27Utilities.IsTableEmpty(tTargetLocation) == true then
                    LOG(sFunctionRef..': WARNING - couldnt find a random place to build based on position='..repr(tTargetLocation)..'; will abort construction')
                    bAbortConstruction = true
                end
            else if bDebugMessages == true then LOG(sFunctionRef..': No need for random place as current targetlocation is valid, ='..repr(tTargetLocation)) end
            end
        end
        if bAbortConstruction == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Not aborting function so will try to move near construction if we have a valid location') end
            if M27Utilities.IsTableEmpty(tTargetLocation) == false and sBlueprintToBuild then
                M27PlatoonUtilities.MoveNearConstruction(aiBrain, oEngineer, tTargetLocation, sBlueprintToBuild, 0, false, false, false)
                if oPartCompleteBuilding then
                    IssueRepair({ oEngineer}, oPartCompleteBuilding)
                else
                    IssueBuildMobile({oEngineer}, tTargetLocation, sBlueprintToBuild, {})
                end
            end
        else
            if bDebugMessages == true then LOG('Warning - couldnt find any places to build after looking randomly nearby, will abort construction. bFoundEnemyInstead='..tostring(bFoundEnemyInstead)) end
        end
    end
    if bDebugMessages == true then
        if sBlueprintToBuild == nil then LOG('sBlueprintToBuild is nil')
        else
            LOG(sFunctionRef..': tTargetLocation='..repr(tTargetLocation)..'; aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation)='..tostring(aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation))..'; sBlueprintToBuild='..(sBlueprintToBuild or 'nil'))
            M27Utilities.DrawLocation(tTargetLocation, nil, 7, 100) --show in white (colour 7)
            LOG(sFunctionRef..': About to list any units in 1x1 rectangle around targetlocation')
            local iSizeAdj = 3
            local rBuildAreaRect = Rect(tTargetLocation[1] - iSizeAdj, tTargetLocation[3] - iSizeAdj, tTargetLocation[1] + iSizeAdj, tTargetLocation[3] + iSizeAdj)
            local tUnitsInRect = GetUnitsInRect(rBuildAreaRect)
            local tsUnitRefs = {}
            if M27Utilities.IsTableEmpty(tUnitsInRect) == false then
                for iUnit, oUnit in tUnitsInRect do
                    table.insert(tsUnitRefs, iUnit, oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit))
                end
            end
            LOG('tsUnitRefs='..repr(tsUnitRefs))
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tTargetLocation
end

function GetPartCompleteBuilding(aiBrain, oBuilder, iCategoryToBuild, iBuildingSearchRange, iEnemySearchRange)
    --Returns nil if no nearby part complete building
    --iEnemySearchRange: nil if dont care about nearby enemies, otherwise will ignore buildings that have enemies within iEnemySearchRange
    local sFunctionRef = 'GetPartCompleteBuilding'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tBuilderPosition = oBuilder:GetPosition()
    local tAllBuildings = aiBrain:GetUnitsAroundPoint(iCategoryToBuild, tBuilderPosition, iBuildingSearchRange, 'Ally')
    local iCurDistanceToBuilder
    local iMinDistanceToBuilder = 10000
    local tBuildingPosition
    local oNearestPartCompleteBuilding
    if M27Utilities.IsTableEmpty(tAllBuildings) == false then
        for iBuilding, oBuilding in tAllBuildings do
            if oBuilding.GetFractionComplete and oBuilding.GetPosition and oBuilding:GetFractionComplete() < 1 then
                local tNearbyEnemies
                local tBuildingPosition = oBuilding:GetPosition()
                if iEnemySearchRange then tNearbyEnemies = aiBrain:GetUnitsAroundPoint(categories.ALLUNITS, tBuildingPosition, iEnemySearchRange, 'Enemy') end
                if M27Utilities.IsTableEmpty(tNearbyEnemies) == true then
                    iCurDistanceToBuilder = M27Utilities.GetDistanceBetweenPositions(tBuildingPosition, tBuilderPosition)
                    if iCurDistanceToBuilder < iMinDistanceToBuilder then
                        iMinDistanceToBuilder = iCurDistanceToBuilder
                        oNearestPartCompleteBuilding = oBuilding
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oNearestPartCompleteBuilding
end

function GetCategoryToBuildFromAction(iActionToAssign, iMinTechLevel)
    local iCategoryToBuild
    if iActionToAssign == refActionBuildMex then
        iCategoryToBuild = refCategoryT1Mex
    elseif iActionToAssign == refActionBuildT3MexOverT2 then
        iCategoryToBuild = M27UnitInfo.refCategoryT3Mex
    elseif iActionToAssign == refActionBuildMassStorage then
        iCategoryToBuild = M27UnitInfo.refCategoryMassStorage
    elseif iActionToAssign == refActionBuildHydro then
        iCategoryToBuild = refCategoryHydro
    elseif iActionToAssign == refActionBuildPower or iActionToAssign == refActionBuildSecondPower or iActionToAssign == refActionBuildThirdPower then
        iCategoryToBuild = refCategoryPower
    elseif iActionToAssign == refActionBuildLandFactory then
        iCategoryToBuild = refCategoryLandFactory
    elseif iActionToAssign == refActionBuildAirFactory then
        iCategoryToBuild = refCategoryAirFactory
    elseif iActionToAssign == refActionBuildEnergyStorage then
        iCategoryToBuild = refCategoryEnergyStorage
    elseif iActionToAssign == refActionBuildAirStaging then
        iCategoryToBuild = refCategoryAirStaging
    elseif iActionToAssign == refActionBuildSMD then
        iCategoryToBuild = M27UnitInfo.refCategorySMD
    elseif iActionToAssign == refActionBuildT1Radar then
        iCategoryToBuild = M27UnitInfo.refCategoryT1Radar
    elseif iActionToAssign == refActionBuildT2Radar then
        iCategoryToBuild = M27UnitInfo.refCategoryT2Radar
    elseif iActionToAssign == refActionBuildT3Radar then
        iCategoryToBuild = M27UnitInfo.refCategoryT3Radar
    elseif iActionToAssign == refActionAssistSMD then
        iCategoryToBuild = nil
    elseif iActionToAssign == refActionAssistAirFactory then
        iCategoryToBuild = nil
    elseif iActionToAssign == refActionBuildLandExperimental then
        iCategoryToBuild = M27UnitInfo.refCategoryLandExperimental
    elseif iActionToAssign == refActionSpare then
        iCategoryToBuild = nil
    elseif iActionToAssign == refActionBuildT1Sonar then
        iCategoryToBuild = M27UnitInfo.refCategoryT1Sonar
    elseif iActionToAssign == refActionBuildT2Sonar then
        iCategoryToBuild = M27UnitInfo.refCategoryT2Sonar
    else
        M27Utilities.ErrorHandler('Need to add code for action='..iActionToAssign)
    end
    if iMinTechLevel > 1 then
        if iMinTechLevel == 3 then iCategoryToBuild = iCategoryToBuild * categories.TECH3 + iCategoryToBuild*categories.EXPERIMENTAL
        else iCategoryToBuild = iCategoryToBuild * categories.TECH2 + iCategoryToBuild * categories.TECH3
        end
    end
    return iCategoryToBuild
end

function UpgradeBuildingActionCompleteChecker(aiBrain, oEngineer, oBuildingToUpgrade)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'UpgradeBuildingActionCompleteChecker'
    local bContinue = true
    while bContinue == true do
        WaitSeconds(1)
        --Check if building has finished upgrading
        bContinue = false
        if oBuildingToUpgrade and not(oBuildingToUpgrade.Dead) and oBuildingToUpgrade.IsUnitState and oBuildingToUpgrade:IsUnitState('Upgrading') then bContinue = true end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': About to clear engineer with ref '..GetEngineerUniqueCount(oEngineer)..' actions') end
    IssueClearCommands({oEngineer})
    ClearEngineerActionTrackers(aiBrain, oEngineer, true)

end

function UpdateActionForNearbyReclaim(oEngineer, iMinReclaimIndividualValue, bDontIssueMoveAfter, bWantEnergy)
    --Gets engineer to stop and reclaim if its about to move out of range of reclaim with at least iMinReclaimIndividualValue
    --Will stop and reclaim anyway if >100 reclaim individually, or if engineer almost at its target destination
    --returns true if it triggers an issuereclaim order
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateActionForNearbyReclaim'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetEngineerUniqueCount(oEngineer) == 59 then bDebugMessages = true end

    local bReclaimWillMoveOutOfRangeSoon = false
    --First check we have space to accept any reclaim - want higher of 1% storage and 50 mass
    local aiBrain = oEngineer:GetAIBrain()
    if bDebugMessages == true then LOG(sFunctionRef..': Considering for E'..GetEngineerUniqueCount(oEngineer)..' LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' with unit state='..M27Logic.GetUnitState(oEngineer)..' currently at position '..repr(oEngineer:GetPosition())..'; mass stored='..aiBrain:GetEconomyStoredRatio('MASS')) end
    if aiBrain:GetEconomyStoredRatio('MASS') < 0.98 and (aiBrain:GetEconomyStoredRatio('MASS') == 0 or aiBrain:GetEconomyStored('MASS') / aiBrain:GetEconomyStoredRatio('MASS') > 50) then
        local tCurPos = oEngineer:GetPosition()
        --Has the engineer moved from its location when it was last told to reclaim?
        if bDebugMessages == true then LOG(sFunctionRef..': Checking if engineer has moved, oEngineer[M27UnitInfo.refbSpecialMicroActive]='..tostring((oEngineer[M27UnitInfo.refbSpecialMicroActive] or false))..'; oEngineer[reftEngineerLastPositionOfReclaimOrder]='..repr(oEngineer[reftEngineerLastPositionOfReclaimOrder])..'; oEngineer[reftEngineerCurrentTarget]='..repr(oEngineer[reftEngineerCurrentTarget])) end
        if not(oEngineer[M27UnitInfo.refbSpecialMicroActive]) then
            if not(oEngineer[reftEngineerLastPositionOfReclaimOrder]) or (M27Utilities.GetDistanceBetweenPositions(tCurPos, oEngineer[reftEngineerLastPositionOfReclaimOrder]) > 1 or M27Utilities.GetDistanceBetweenPositions(tCurPos, oEngineer[reftEngineerCurrentTarget]) <= 1) then
                --Is the engineer part of a segment with iMinReclaimIndividualValue reclaim, or near a segment with this minimum)?
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Engineer isnt close to recent reclaim order; will check if any reclaim in range of engi')
                    --DrawRectangle(rRect, iColour, iDisplayCount)
                    local iCurX, iCurZ = M27MapInfo.GetReclaimSegmentsFromLocation(tCurPos)
                    M27Utilities.DrawRectangle(Rect((iCurX - 1) * M27MapInfo.iReclaimSegmentSizeX, (iCurZ - 1) * M27MapInfo.iReclaimSegmentSizeZ, iCurX * M27MapInfo.iReclaimSegmentSizeX, iCurZ * M27MapInfo.iReclaimSegmentSizeZ))
                    LOG(sFunctionRef..': Have drawn rectangle that the engineer is in, iCurX='..iCurX..'; iCurZ='..iCurZ..'; IsReclaimNearby='..tostring(M27Conditions.IsReclaimNearby(tCurPos, 1, iMinReclaimIndividualValue)))
                end

                if M27Conditions.IsReclaimNearby(tCurPos, 1, iMinReclaimIndividualValue) then --want to only look at adjacent segments even for ACU, as build range of 10 should still be smaller than 1+bit of segment in almost all cases
                    if bDebugMessages == true then LOG(sFunctionRef..' Is reclaim in current or adjacent segment, will check if any reclaim will move out of range; oEngineer[reftEngineerCurrentTarget]='..repr(oEngineer[reftEngineerCurrentTarget] or {'nil'})) end
                    local oEngBP = oEngineer:GetBlueprint()
                    local iMoveSpeed = oEngBP.Physics.MaxSpeed
                    local iMaxDistanceToEngineer = oEngBP.Economy.MaxBuildDistance + math.min(oEngBP.SizeX, oEngBP.SizeZ) * 0.5 - 0.1
                    --local iRadius = iMaxDistanceToEngineer * 0.5

                    local iCurDistToEngineer
                    local iMinDistanceToEngineer = math.max(oEngBP.SizeX, oEngBP.SizeZ)
                    local iCompletionDistToFinalDestination = 3.5
                    if oEngineer.PlatoonHandle and oEngineer.Platoonhandle[M27PlatoonUtilities.refiOverrideDistanceToReachDestination] then iCompletionDistToFinalDestination = math.max(iCompletionDistToFinalDestination, oEngineer.Platoonhandle[M27PlatoonUtilities.refiOverrideDistanceToReachDestination]) end

                    local tExpectedPositionSoon = M27Utilities.MoveInDirection(tCurPos, M27Utilities.GetAngleFromAToB(tCurPos, oEngineer[reftEngineerCurrentTarget]), iMoveSpeed)

                    --GetReclaimInRectangle(iReturnType, rRectangleToSearch)
                    --    --iReturnType: 1 = true/false; 2 = number of wrecks; 3 = total mass, 4 = valid wrecks
                    local tNearbyReclaim = M27MapInfo.GetReclaimInRectangle(4, Rect(tCurPos[1] - iMaxDistanceToEngineer, tCurPos[3] - iMaxDistanceToEngineer, tCurPos[1] + iMaxDistanceToEngineer, tCurPos[3] + iMaxDistanceToEngineer))
                    if bDebugMessages == true then
                        if bDebugMessages == true then LOG(sFunctionRef..': iMaxDistanceToEngineer='..iMaxDistanceToEngineer..'; oEngBP.Economy.MaxBuildDistance='..oEngBP.Economy.MaxBuildDistance..'; Rect='..repr(Rect(tCurPos[1] - iMaxDistanceToEngineer, tCurPos[3] - iMaxDistanceToEngineer, tCurPos[1] + iMaxDistanceToEngineer, tCurPos[3] + iMaxDistanceToEngineer))) end
                        M27Utilities.DrawRectangle(Rect(tCurPos[1] - iMaxDistanceToEngineer, tCurPos[3] - iMaxDistanceToEngineer, tCurPos[1] + iMaxDistanceToEngineer, tCurPos[3] + iMaxDistanceToEngineer), 2, 20)
                    end

                    if M27Utilities.IsTableEmpty(tNearbyReclaim) == false then
                        if M27Utilities.GetDistanceBetweenPositions(oEngineer[reftEngineerCurrentTarget], tCurPos) <= iCompletionDistToFinalDestination then
                            bReclaimWillMoveOutOfRangeSoon = true
                            iMinDistanceToEngineer = 0
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..'Have nearby reclaim, will check if any will move out of range soon') end
                        local tReclaimInRange = {}
                        local iValidReclaimInRange = 0
                        for iReclaim, oReclaim in tNearbyReclaim do
                            --is this valid reclaim within our build area?
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': iReclaim='..iReclaim..'; oReclaim.MaxMassReclaim='..(oReclaim.MaxMassReclaim or 0))
                                if oReclaim.MaxMassReclaim >= 100 or (bWantEnergy and oReclaim.MaxEnergyReclaim >= 100) then
                                    LOG('Large reclaim, repr of all values='..repr(oReclaim))
                                    if oReclaim.GetBlueprint then
                                        LOG('oReclaim has a blueprint='..repr(oReclaim:GetBlueprint()))
                                    else LOG('oReclaim doesnt have .GetBlueprint')
                                    end
                                end--M27Utilities.DebugArray(oReclaim)) end
                            end
                            if ((not (bWantEnergy) and oReclaim.MaxMassReclaim >= iMinReclaimIndividualValue) or (bWantEnergy and oReclaim.MaxEnergyReclaim >= iMinReclaimIndividualValue)) and oReclaim.CachePosition and not(oReclaim:BeenDestroyed()) then
                                iCurDistToEngineer = math.max(0, M27Utilities.GetDistanceBetweenPositions(tCurPos, oReclaim.CachePosition) - math.min(oReclaim:GetBlueprint().SizeX, oReclaim:GetBlueprint().SizeZ)*0.5)
                                if iCurDistToEngineer <= iMaxDistanceToEngineer and (iCurDistToEngineer > iMinDistanceToEngineer or oReclaim.MaxMassReclaim > 100) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': iReclaim='..iReclaim..'; Reclaim is in range, iCurDistToEngineer='..iCurDistToEngineer) end
                                    table.insert(tReclaimInRange, oReclaim)
                                    --Will the reclaim be out of range soon? or is it very high value such that we want to reclaim immediately?
                                    if oReclaim.MaxMassReclaim > 100 or (bWantEnergy and oReclaim.MaxEnergyReclaim > 100) or M27Utilities.GetDistanceBetweenPositions(tExpectedPositionSoon, oReclaim.CachePosition) > iMaxDistanceToEngineer then
                                        bReclaimWillMoveOutOfRangeSoon = true
                                        --(dont want a break here, as need to record all reclaim in range right now for the recelaim command)
                                    end
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': iReclaim='..iReclaim..'; Too far away from engineer, iCurDistToEngineer='..iCurDistToEngineer) end
                                end
                            end
                        end
                        --If we want to reclaim (it will move out of range soon) but we dont have any reclaim flagged as being in-range, then update to include all nearby reclaim as backup

                        if M27Utilities.IsTableEmpty(tReclaimInRange) and M27Utilities.IsTableEmpty(tNearbyReclaim) == false and bReclaimWillMoveOutOfRangeSoon then
                            tReclaimInRange = tNearbyReclaim
                        end




                        if bDebugMessages == true then LOG(sFunctionRef..'bReclaimWillMoveOutOfRangeSoon='..tostring(bReclaimWillMoveOutOfRangeSoon)) end
                        if bReclaimWillMoveOutOfRangeSoon then
                            if bDebugMessages == true then LOG(sFunctionRef..'Reclaim is about to go out of range so will issue reclaim command for any valid reclaim') end
                            oEngineer[reftEngineerLastPositionOfReclaimOrder] = {tCurPos[1], tCurPos[2], tCurPos[3]}
                            IssueClearCommands({oEngineer})
                            for iValidReclaim, oValidReclaim in tReclaimInRange do
                                if bDebugMessages == true then LOG(sFunctionRef..'Issuing reclaim command') end
                                IssueReclaim({oEngineer}, oValidReclaim)
                            end
                            if not(bDontIssueMoveAfter) then IssueMove({oEngineer}, oEngineer[reftEngineerCurrentTarget]) end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..' No reclaim in engineer build range') end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..' No reclaim in nearby segments') end
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Engineer hasnt moved from its last position where it was given a reclaim order; tCurPos='..repr(tCurPos)..'; oEngineer[reftEngineerLastPositionOfReclaimOrder]='..repr(oEngineer[reftEngineerLastPositionOfReclaimOrder] or {'nil'})) end
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Engineer has special micro active') end
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': Have too much mass so wont try to reclaim; Stored ratio='..aiBrain:GetEconomyStoredRatio('MASS')..'; Mass stored='..aiBrain:GetEconomyStored('MASS')) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bReclaimWillMoveOutOfRangeSoon
end

function RegularlyCheckForNearbyReclaim(oEngineer, bWantEnergy)
    --Should be called via a fork thread
    --(dont use function profiler as too few commands absent the waitseconds to be worth putting in lots of profiler calls)
    if not(oEngineer[refbEngineerActiveReclaimChecker]) then
        oEngineer[refbEngineerActiveReclaimChecker] = true
        WaitSeconds(1)
        while M27UnitInfo.IsUnitValid(oEngineer) do
            if oEngineer[refiEngineerCurrentAction] == refActionReclaimArea then
                UpdateActionForNearbyReclaim(oEngineer, 2.5, nil, bWantEnergy) --Get any reclaim >= 5 in value
                WaitSeconds(1)
            else
                oEngineer[refbEngineerActiveReclaimChecker] = false
                break
            end
        end
    end
end

function AttackMoveToRandomPositionAroundBase(aiBrain, oEngineer, iMaxDistance, iMinDistance)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AttackMoveToRandomPositionAroundBase'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Check pathing group
    local iEngiPathingGroup = M27MapInfo.GetUnitSegmentGroup(oEngineer)
    local sPathingType = M27UnitInfo.GetUnitPathingType(oEngineer)
    local tActionTargetLocation = {M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][2], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]}
    if not(iEngiPathingGroup == M27MapInfo.GetSegmentGroupOfLocation(sPathingType, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) then
        --Engi not expected to be able to path to base based on segment pathing - check if this is correct
        if not(M27MapInfo.RecheckPathingOfLocation(sPathingType, oEngineer, tActionTargetLocation, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) or not(iEngiPathingGroup == M27MapInfo.GetSegmentGroupOfLocation(sPathingType, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) then
            --Engi cant path to base, so instead look for somwhere randomly from where it currently is and reduce min and max distance
            tActionTargetLocation = oEngineer:GetPosition()
            iMinDistance = math.min(5, iMinDistance)
            iMaxDistance = math.min(iMinDistance + 5, iMaxDistance)
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': About to get random point in area that can path to') end
    local tRandomTargetLocation = M27Logic.GetRandomPointInAreaThatCanPathTo(sPathingType, iEngiPathingGroup, tActionTargetLocation, iMaxDistance, iMinDistance)
    if tRandomTargetLocation == nil then
        --Couldnt find anywhere that can path to, check if pathing is correct for our current position; if it is then just go for the location itself
        --We cant path to the target, check if its correct to think this
        if M27MapInfo.RecheckPathingOfLocation(sPathingType, oEngineer, tActionTargetLocation, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then
            --Have changed the pathing so retry
            tRandomTargetLocation = M27Logic.GetRandomPointInAreaThatCanPathTo(sPathingType, iEngiPathingGroup, tActionTargetLocation, iMaxDistance, iMinDistance)
            if tRandomTargetLocation == nil then tRandomTargetLocation = tActionTargetLocation end
        else
            --Its correct that we cant path to the target, so just resort to backup of trying to go there anywhere
            tRandomTargetLocation = tActionTargetLocation
        end
    end
    IssueAggressiveMove({ oEngineer }, tRandomTargetLocation)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tRandomTargetLocation
end

function ReplaceT2WithT3Monitor(aiBrain, oEngineer, oActionTargetObject)
    --Call this via forkthread; will check if oEngineer is near the target object, and if the target object exists, and once it is, will get it rebuilt with a T3 mex
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReplaceT2WithT3Monitor'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tTargetMex = oActionTargetObject:GetPosition()
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code for Engineer UC='..GetEngineerUniqueCount(oEngineer)..'; LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..', tTargetMex='..repr(tTargetMex)..'; Target object='..oActionTargetObject:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oActionTargetObject)) end

    local iDistanceThreshold = oEngineer:GetBlueprint().Economy.MaxBuildDistance + 1 --Mex is 2x2 size, so has radius of 1

    --Move towards the target if we aren't already near there
    if M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), tTargetMex) >= 6 then
        if bDebugMessages == true then LOG(sFunctionRef..': Arent near the target so sending issuemove to it before starting main loop') end
        IssueMove({oEngineer}, tTargetMex)
        WaitTicks(10)
    end

    --Wait until we are near the target

    while M27UnitInfo.IsUnitValid(oEngineer) and M27UnitInfo.IsUnitValid(oActionTargetObject) and oEngineer[refiEngineerCurrentAction] == refActionBuildT3MexOverT2 do
        if M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), tTargetMex) >= iDistanceThreshold then
            if bDebugMessages == true then LOG(sFunctionRef..': Are more than 6 away from target so waiting 1 second then rechecking') end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitTicks(10)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Are close enough to mex now so will move on to ctrlk logic') end
            break
        end
    end

    --Ctrl-K the target if engineer and target still exist
    if M27UnitInfo.IsUnitValid(oEngineer) and oEngineer[refiEngineerCurrentAction] == refActionBuildT3MexOverT2 then
        if bDebugMessages == true then LOG(sFunctionRef..': UC='..GetEngineerUniqueCount(oEngineer)..': Are near target, current action='..oEngineer[refiEngineerCurrentAction]..'; Target object='..oActionTargetObject:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oActionTargetObject)) end

        if not(M27UnitInfo.IsUnitValid(oActionTargetObject)) or (oActionTargetObject:IsUnitState('Upgrading') and oActionTargetObject.GetWorkProgress and oActionTargetObject:GetWorkProgress() > 0.01) then
            if bDebugMessages == true then LOG(sFunctionRef..': Target no longer valid or is upgrading so will clear engineer trackers') end
            ClearEngineerActionTrackers(aiBrain, oEngineer, true)
            M27EconomyOverseer.RefreshT2MexesNearBase(aiBrain)
        else
            if bDebugMessages == true then LOG(sFunctionRef..': About to tell '..oActionTargetObject:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oActionTargetObject)..' to ctrlk') end
            oActionTargetObject:Kill()
            IssueClearCommands({oEngineer})
            BuildStructureAtLocation(aiBrain, oEngineer, M27UnitInfo.refCategoryT3Mex, 1, nil, tTargetMex, true, false)
            M27Utilities.DelayChangeVariable(oEngineer, rebToldToStartBuildingT3Mex, true, 20)
            WaitTicks(10) --Backup logic
            if M27UnitInfo.IsUnitValid(oEngineer) then
                if bDebugMessages == true then LOG(sFunctionRef..': Finished waiting for engineer UC'..GetEngineerUniqueCount(oEngineer)..'; About to tell engineer to build T3 mex at the location. tTargetMex='..repr(tTargetMex)) end
                --M27Utilities.DelayChangeVariable(oEngineer, rebToldToStartBuildingT3Mex, true, 8)
                BuildStructureAtLocation(aiBrain, oEngineer, M27UnitInfo.refCategoryT3Mex, 1, nil, tTargetMex, true, false)
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Engineer is no longer valid') end
            end
        end
    elseif bDebugMessages == true then LOG(sFunctionRef..': Engineer either no longer valid or has been reassigned so aborting')
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function AssignActionToEngineer(aiBrain, oEngineer, iActionToAssign, tActionTargetLocation, oActionTargetObject, iConditionNumber, sBuildingBPRef)
    --If oActionTargetObject is specified, then will assist this (unless specifically coded an exception), otherwise will try and construct a new building
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'AssignActionToEngineer'
    M27Utilities.FunctionProfiler(sFunctionRef..iActionToAssign, M27Utilities.refProfilerStart)

    --if GetEngineerUniqueCount(oEngineer) == 59 then bDebugMessages = true end

    if oEngineer then
        if oEngineer.GetUnitId then
            if bDebugMessages == true then LOG(sFunctionRef..': Issuing clear commands to engineer with unique ref '..GetEngineerUniqueCount(oEngineer)..'; iActionToAssign='..iActionToAssign) end
            IssueClearCommands{oEngineer}
            if iActionToAssign == refActionSpare then
                IssueSpareEngineerAction(aiBrain, oEngineer)
                --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers)
                UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, nil, false, iConditionNumber)
            else
                local bAreAssisting = false
                if iActionToAssign == refActionReclaimArea or iActionToAssign == refActionReclaimTrees then
                    tActionTargetLocation = M27Logic.ChooseReclaimTarget(oEngineer, true)
                    if M27Utilities.IsTableEmpty(tActionTargetLocation) == true then
                        --Get random position between 50 and 100 of base to attack-move to
                        tActionTargetLocation = AttackMoveToRandomPositionAroundBase(aiBrain, oEngineer, 100, 50)
                    else
                        IssueMove({ oEngineer }, tActionTargetLocation)
                    end
                    ForkThread(RegularlyCheckForNearbyReclaim, oEngineer, true)
                    UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tActionTargetLocation, false, iConditionNumber)
                else
                    if oActionTargetObject then
                        if not(iActionToAssign == refActionReclaimArea) and not(iActionToAssign == refActionReclaimTrees) then
                            if iActionToAssign == refActionReclaimUnit then
                                IssueReclaim({oEngineer}, oActionTargetObject)
                                --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers)
                                UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, nil, true, iConditionNumber, oActionTargetObject)
                                bAreAssisting = true
                            elseif iActionToAssign == refActionBuildT3MexOverT2 and M27UnitInfo.IsUnitValid(oActionTargetObject) and EntityCategoryContains(M27UnitInfo.refCategoryMex, oActionTargetObject:GetUnitId()) then
                                --Redundancy - set the target location equal to the target object position
                                tActionTargetLocation = oActionTargetObject:GetPosition()
                                if bDebugMessages == true then LOG(sFunctionRef..': Have an action target object but the target is a mex so we dont want to assist it, instead its the target location') end
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Are assisting an object') end
                                bAreAssisting = true
                                if oActionTargetObject.GetUnitId then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Telling engineer '..GetEngineerUniqueCount(oEngineer)..'to assist enginner '..GetEngineerUniqueCount(oActionTargetObject)..'; ID='..oActionTargetObject:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oActionTargetObject)) end
                                    if oActionTargetObject.GetFractionComplete and oActionTargetObject:GetFractionComplete() < 1 then
                                        IssueRepair({ oEngineer}, oActionTargetObject)
                                    else
                                        IssueGuard({ oEngineer}, oActionTargetObject)
                                    end
                                    --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers)
                                    UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, nil, true, iConditionNumber, oActionTargetObject)
                                else
                                    LOG('oActionTargetObject isnt a unit, will see if it has a subtable with a unit and use that (workaround for strange issue)')
                                    if oActionTargetObject[2] and oActionTargetObject[2].GetUnitId then
                                        LOG(sFunctionRef..': Have a valid unit in a subtable, so will make this the target')
                                        oActionTargetObject = oActionTargetObject[2]
                                    else
                                        bAreAssisting = false
                                        LOG(sFunctionRef..': Dont have a valid unit in a subtable, so will try and perform action without assisting')
                                    end
                                end
                            end
                        end
                    end
                    if bAreAssisting == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': Arent assisting so determine what to build based on action='..iActionToAssign) end
                        --Get the building to construct, and the location to construct it at, factoring in adjacency if its not a mex/hydro
                        local iCategoryToBuild
                        local bConsiderAdjacency = false --Only set to true if have manually added code to determine adjacency in the getadjacency function
                        local bConstructBuilding = true
                        local iCatToBuildBy
                        local tTargetLocation = tActionTargetLocation
                        local bQueueUpMultiple = false
                        local iMaxAreaToSearch = 60
                        iCategoryToBuild = GetCategoryToBuildFromAction(iActionToAssign)
                        if iCategoryToBuild == nil then
                            bConstructBuilding = false
                            M27Utilities.ErrorHandler('Couldnt get category to build for iActionToAssign='..iActionToAssign)
                        else
                            if iActionToAssign == refActionBuildMex then
                                --iCategoryToBuild = refCategoryT1Mex
                                bQueueUpMultiple = true
                            elseif iActionToAssign == refActionBuildT3MexOverT2 then
                                bConsiderAdjacency = false
                                bConstructBuilding = false --Wont want to construct immediately so want to avoid normal logic
                            elseif iActionToAssign == refActionBuildHydro then
                                --iCategoryToBuild = refCategoryHydro
                            elseif iActionToAssign == refActionBuildPower or iActionToAssign == refActionBuildSecondPower or iActionToAssign == refActionBuildThirdPower then
                                --iCategoryToBuild = refCategoryPower
                                bConsiderAdjacency = true
                                if M27UnitInfo.GetUnitTechLevel(oEngineer) == 1 then
                                    iCatToBuildBy = refCategoryLandFactory + refCategoryAirFactory
                                    bQueueUpMultiple = true
                                elseif M27UnitInfo.GetUnitTechLevel(oEngineer) == 2 then
                                    iCatToBuildBy = refCategoryAirFactory + M27UnitInfo.refCategoryT2Radar
                                else
                                    iCatToBuildBy = refCategoryAirFactory + M27UnitInfo.refCategoryT3Radar + M27UnitInfo.refCategorySMD + M27UnitInfo.refCategoryFixedT3Arti
                                end
                                iMaxAreaToSearch = 20
                                if iActionToAssign == refActionBuildSecondPower or iActionToAssign == refActionBuildThirdPower then iMaxAreaToSearch = 50 end
                            elseif iActionToAssign == refActionBuildLandFactory then
                                --iCategoryToBuild = refCategoryLandFactory
                                bConsiderAdjacency = true
                                iCatToBuildBy = refCategoryT1Mex
                            elseif iActionToAssign == refActionBuildAirFactory then
                                --iCategoryToBuild = refCategoryAirFactory
                                --HydroNearACUAndBase(aiBrain, bNearBaseOnlyCheck, bAlsoReturnHydroTable)
                                if M27Conditions.HydroNearACUAndBase(aiBrain, true, false) == true then
                                    bConsiderAdjacency = true
                                    --Need to decide what power to build by, as adjacency code requires a fixed building size (whereas T2+Hydro is dif to T3 power)
                                        --for now simple check - if have t3 power, then build by t3 power; otherwise build by hydro+t2 power (which have the same size)
                                    if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Power) > 0 then
                                        iCatToBuildBy = M27UnitInfo.refCategoryT3Power
                                    else iCatToBuildBy = refCategoryHydro + M27UnitInfo.refCategoryT2Power end
                                else
                                    if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Power) > 0 then
                                        iCatToBuildBy = M27UnitInfo.refCategoryT3Power
                                    elseif aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Power) > 0 then
                                        iCatToBuildBy = M27UnitInfo.refCategoryT2Power
                                    else iCatToBuildBy = M27UnitInfo.refCategoryT1Power
                                    end
                                end
                            elseif iActionToAssign == refActionBuildEnergyStorage then
                                --iCategoryToBuild = refCategoryEnergyStorage
                                if bDebugMessages == true then LOG(sFunctionRef..': Decided on category to build for energy storage') end
                                bConsiderAdjacency = false
                            elseif iActionToAssign == refActionBuildAirStaging then
                                --iCategoryToBuild = refCategoryAirStaging
                                bConsiderAdjacency = false
                            elseif iActionToAssign == refActionBuildSMD then
                                bConsiderAdjacency = true
                                iCatToBuildBy = M27UnitInfo.refCategoryT3Power
                                iMaxAreaToSearch = 120
                            elseif iActionToAssign == refActionBuildT1Radar then
                                bConsiderAdjacency = true
                                iCatToBuildBy = M27UnitInfo.refCategoryT1Power
                            elseif iActionToAssign == refActionBuildT2Radar then
                                bConsiderAdjacency = true
                                iCatToBuildBy = M27UnitInfo.refCategoryT2Power
                            elseif iActionToAssign == refActionBuildT3Radar then
                                bConsiderAdjacency = true
                                iCatToBuildBy = M27UnitInfo.refCategoryT3Power
                                iMaxAreaToSearch = 120
                            elseif iActionToAssign == refActionAssistSMD then
                                bConstructBuilding = false
                            elseif iActionToAssign == refActionAssistAirFactory then
                                bConstructBuilding = false
                            elseif iActionToAssign == refActionBuildLandExperimental then
                                bConsiderAdjacency = false
                            elseif iActionToAssign == refActionBuildMassStorage then
                                bConsiderAdjacency = false
                            elseif iActionToAssign == refActionBuildT1Sonar or iActionToAssign == refActionBuildT2Sonar then
                                bConsiderAdjacency = false
                            else
                                M27Utilities.ErrorHandler('Need to add code for action='..iActionToAssign)
                                bConstructBuilding = false
                            end
                        end
                        if bConstructBuilding == true then
                                            --BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tAlternativePositionToLookFrom)
                            if not(iCategoryToBuild) then M27Utilities.ErrorHandler('Are about to try and build without having a category to build')
                                else if bDebugMessages == true then LOG(sFunctionRef..'; iCategoryToBuild is not nil') end
                            end
                                            --BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tAlternativePositionToLookFrom, bLookForPartCompleteBuildings, bLookForQueuedBuildings)
                            tTargetLocation = BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tTargetLocation)
                            if M27Utilities.IsTableEmpty(tTargetLocation) == true then
                                M27Utilities.ErrorHandler('Failed to find a location to build at for oEngineer UC='..GetEngineerUniqueCount(oEngineer)..'; Action='..iActionToAssign..'; , switching to backup engineer logic')
                                tTargetLocation = oEngineer:GetPosition()
                                iActionToAssign = refActionSpare
                                IssueSpareEngineerAction(aiBrain, oEngineer)
                                --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers)
                                UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, nil, false, iConditionNumber)
                                bQueueUpMultiple = false
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': About to call update tracker for tTargetLocation='..repr(tTargetLocation)) end
                                UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, false, iConditionNumber)
                            end

                            if bQueueUpMultiple == true and M27Utilities.IsTableEmpty(tTargetLocation) == false then
                                iMaxAreaToSearch = iMaxAreaToSearch - 5
                                if iActionToAssign == refActionBuildMex then
                                    --Get nearest mex in pathing group and see if its close enough
                                    local tMexesToIgnore = {}
                                    local iCurMexCount = 1
                                    local iMaxMexCount = 3
                                    local iCurLoopCount = 0
                                    local tNearestMex
                                    while iCurMexCount < iMaxMexCount do
                                        iCurLoopCount = iCurLoopCount + 1
                                        if iCurLoopCount > iCurMexCount then break end
                                        tMexesToIgnore[iCurMexCount] = {tTargetLocation[1], tTargetLocation[2], tTargetLocation[3]}
                                        if bDebugMessages == true then LOG(sFunctionRef..': Looking for extra mexes to build; tMexesToIgnore='..repr(tMexesToIgnore)..'; tTargetLocation='..repr(tTargetLocation)) end
                                        --GetNearestMexToUnit(oBuilder, bCanBeBuiltOnByAlly, bCanBeBuiltOnByEnemy, bCanBeQueuedToBeBuilt, iMaxSearchRangeMod, tStartPositionOverride, tMexesToIgnore)
                                        tNearestMex = M27MapInfo.GetNearestMexToUnit(oEngineer, false, false, false, iMaxAreaToSearch, tTargetLocation, tMexesToIgnore)
                                        if tNearestMex then
                                            tTargetLocation = tNearestMex
                                            tTargetLocation = BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tTargetLocation)
                                            if M27Utilities.IsTableEmpty(tTargetLocation) == false then
                                                --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers)
                                                UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, false, iConditionNumber, nil, true)
                                                iCurMexCount = iCurMexCount + 1
                                            end
                                        end
                                    end
                                elseif iActionToAssign == refActionBuildPower or iActionToAssign == refActionBuildSecondPower or iActionToAssign == refActionBuildThirdPower then
                                    if EntityCategoryContains(categories.TECH1, oEngineer:GetUnitId()) and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 16 then --Dont want to queue up multiple T2 or T3 as theyre much more expensive, and also only want to start queing once we have a base level of power
                                        if M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), tTargetLocation) <= 10 then
                                            --TODO - improve movenearconstruction so dont need above line
                                            local iMaxCount = 3
                                            local iCurCount = 1
                                            if bDebugMessages == true then LOG(sFunctionRef..': Last T1 power is within 10 of builder, so will queue up more; iCurCount='..iCurCount) end
                                            while iCurCount < iMaxCount do
                                                tTargetLocation = BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tTargetLocation)
                                                if M27Utilities.IsTableEmpty(tTargetLocation) == false then
                                                    --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers)
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Found location for an extra T1 power to be built; tTargetLocation='..repr(tTargetLocation)) end
                                                    UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, false, iConditionNumber, nil, true)
                                                    iCurCount = iCurCount + 1
                                                else
                                                    break
                                                end
                                            end
                                        end
                                    end
                                else
                                    --WARNING: If add in any new queue'd actions, then make sure update ClearEngineerActionTrackers as it will only cycle through location tables for mex and power (for performance reasons)
                                    --Alternatively, define for each action if we sometimes might queue it
                                    M27Utilities.ErrorHandler('Need to add code for this action to queue up multiple')
                                end
                            end
                        else
                            --Not constructing anything, consider other actions
                            if bDebugMessages == true then LOG(sFunctionRef..': Dont have anything to build, so check for reclaim order') end
                            if iActionToAssign == refActionReclaimArea or iActionToAssign == refActionReclaimTrees then
                                IssueAggressiveMove({oEngineer}, tTargetLocation )
                                --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers)
                                UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, false, iConditionNumber)
                            elseif iActionToAssign == refActionBuildT3MexOverT2 then
                                --Want to move near the location first, wait for it to be ctrl-Kd, and then build
                                --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers, oUnitToBeDestroyed)
                                if bDebugMessages == true then LOG(sFunctionRef..': Are trying to build T3 mex, and have been flagged that we arent assisting anything. tTargetLocation='..repr((tTargetLocation or {'nil'}))..'; Engi location='..repr(oEngineer:GetPosition())) end
                                if M27UnitInfo.IsUnitValid(oActionTargetObject) == false then M27Utilities.ErrorHandler('Dont have a target mex to be replaced')
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..'L Will update the tracker, with an oActionTargetObject object that has a position='..repr(oActionTargetObject:GetPosition())) end
                                    UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, false, iConditionNumber, nil, false, oActionTargetObject)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef..': Have action to build T3 over T2, oEngineer UC='..GetEngineerUniqueCount(oEngineer))
                                        if M27UnitInfo.IsUnitValid(oActionTargetObject) then
                                            LOG('oActionTargetObject='..oActionTargetObject:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oActionTargetObject))
                                        else
                                            LOG('No oActionTargetObject')
                                        end
                                    end


                                    ForkThread(ReplaceT2WithT3Monitor, aiBrain, oEngineer, oActionTargetObject)
                                end
                            else
                                if iActionToAssign == refActionReclaimUnit then M27Utilities.ErrorHandler('No reclaim unit logic activated so may be missing a valid target, will issue a spare action', nil, true) end
                                if bDebugMessages == true then LOG(sFunctionRef..': Nothing to build or reclaim, will issue spare action instead') end
                                IssueSpareEngineerAction(aiBrain, oEngineer)
                                UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, nil, false, iConditionNumber)
                            end
                        end
                    end
                end
                --Not a spare action - if upgrading a building then need to check if should reset after a short time period
                if iActionToAssign == refActionUpgradeBuilding or iActionToAssign == refActionUpgradeHQ then
                    ForkThread(UpgradeBuildingActionCompleteChecker, aiBrain, oEngineer, oActionTargetObject)
                end
            end

        else
            M27Utilities.ErrorHandler('oEngineer isnt a unit')
        end
    else
        M27Utilities.ErrorHandler('oEngineer is nil')
    end
    M27Utilities.FunctionProfiler(sFunctionRef..iActionToAssign, M27Utilities.refProfilerEnd)
end

function FilterLocationsBasedOnDistanceToEnemy(aiBrain, tLocationsToFilter, iMaxPercentageOfWayTowardsEnemy, bSortTable)
    --Returns {} if cant find any
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'FilterLocationsBasedOnDistanceToEnemy'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tRevisedLocations = {}
    --local tNearestLocation = {}
    if bDebugMessages == true then LOG(sFunctionRef..': Start; about to filter through '..table.getn(tLocationsToFilter)..' locations') end
    if M27Utilities.IsTableEmpty(tLocationsToFilter) == false then
        local iCurPercentageDistance, iCurDistanceToEnemy, iCurDistanceToStart
        local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local iNearestEnemyStartNumber = M27Logic.GetNearestEnemyStartNumber(aiBrain)
        local tEnemyStartPosition = M27MapInfo.PlayerStartPoints[iNearestEnemyStartNumber]
        local iValidLocationCount = 0
        local iClosestDistance = 1000
        if M27Utilities.IsTableEmpty(tStartPosition) == false and M27Utilities.IsTableEmpty(tEnemyStartPosition) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Just before main loop; tStartPosition='..repr(tStartPosition)..'; tEnemyStartPosition='..repr(tEnemyStartPosition)..'; our startposition number='..aiBrain.M27StartPositionNumber..'; enemy start position number='..iNearestEnemyStartNumber) end
            for iLocation, tLocation in tLocationsToFilter do
                iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tLocation, tEnemyStartPosition)
                iCurDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tLocation, tStartPosition)
                iCurPercentageDistance = iCurDistanceToStart / (iCurDistanceToEnemy + iCurDistanceToStart)
                if iCurPercentageDistance <= iMaxPercentageOfWayTowardsEnemy then
                    iValidLocationCount = iValidLocationCount + 1
                    tRevisedLocations[iValidLocationCount] = tLocation
                end
                if bDebugMessages == true then LOG(sFunctionRef..': LocationRef='..M27Utilities.ConvertLocationToReference(tLocation)..'; iCurDistanceToEnemy='..iCurDistanceToEnemy..'; iCurDistanceToStart='..iCurDistanceToStart..'; iCurPercentageDistance='..iCurPercentageDistance..'; iValidLocationCount='..iValidLocationCount) end
            end
        else
            M27Utilities.ErrorHandler('tStartPosition or tEnemyStartPosition is empty')
        end
    else
        M27Utilities.ErrorHandler('tLocationsToFilter is empty')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tRevisedLocations--, tNearestLocation
end

function FilterLocationsBasedOnIntelPathCoverage(aiBrain, tLocationsToFilter, bNOTYETCODEDAlsoReturnClosest, bTableOfObjectsNotLocations)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'FilterLocationsBasedOnIntelPathCoverage'

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tFilteredLocations = {}
    if bTableOfObjectsNotLocations == nil then bTableOfObjectsNotLocations = false end
    if M27Utilities.IsTableEmpty(tLocationsToFilter) == true then
        M27Utilities.ErrorHandler('tLocationsToFilter are empty')
    else
        local iValidLocationCount = 0
        local bInIntelLine
        for iLocation, tLocation in tLocationsToFilter do
            if bTableOfObjectsNotLocations == true then
                bInIntelLine = M27Conditions.IsLocationWithinIntelPathLine(aiBrain, tLocation:GetPosition())
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Checking if tLocation '..repr(tLocation)..' is within intel path line') end
                bInIntelLine = M27Conditions.IsLocationWithinIntelPathLine(aiBrain, tLocation)
            end
            if bInIntelLine == false then
                --Do we have visual/intel coverage of the location anyway?
                if bTableOfObjectsNotLocations then bInIntelLine = M27Logic.GetIntelCoverageOfPosition(aiBrain, tLocation:GetPosition(), 40, true)
                else bInIntelLine = M27Logic.GetIntelCoverageOfPosition(aiBrain, tLocation, 40, true)
                end
            end
            if bInIntelLine == true then
                if bDebugMessages == true then LOG(sFunctionRef..': Location is within intel path line so recording') end
                iValidLocationCount = iValidLocationCount + 1
                tFilteredLocations[iValidLocationCount] = tLocation
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tFilteredLocations
end

function FilterLocationsBasedOnDefenceCoverage(aiBrain, tLocationsToFilter, bAlsoNeedIntelCoverage, bNOTYETCODEDAlsoReturnClosest, bTableOfObjectsNotLocations)
    --Intel coverage - achieved if either have intel coverage of the target, or intel path line is closer to enemy base than it
    --Returns nil if cant find anywhere
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'FilterLocationsBasedOnDefenceCoverage'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bTableOfObjectsNotLocations == nil then bTableOfObjectsNotLocations = false end
    local tFilteredLocations = {}
    if M27Utilities.IsTableEmpty(tLocationsToFilter) == true then
        M27Utilities.ErrorHandler('tLocationsToFilter doesnt contain values')
    else
        local iValidLocationCount = 0
        local iModDistanceFromStart
        local iDefenceCoverage = aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat]
        if iDefenceCoverage and iDefenceCoverage > 0 then
            for iLocation, tLocation in tLocationsToFilter do
                if bTableOfObjectsNotLocations == true then
                    iModDistanceFromStart = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tLocation:GetPosition())
                    if bDebugMessages == true then LOG(sFunctionRef..': bTableOfObjectsNotLocations='..tostring(bTableOfObjectsNotLocations)..'; Location='..repr(tLocation:GetPosition())..'; iModDistanceFromStart='..iModDistanceFromStart..'; iDefenceCoverage='..iDefenceCoverage) end
                else
                    iModDistanceFromStart = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tLocation)
                    if bDebugMessages == true then LOG(sFunctionRef..': bTableOfObjectsNotLocations='..tostring(bTableOfObjectsNotLocations)..'; tLocation='..repr(tLocation)..'; iModDistanceFromStart='..iModDistanceFromStart..'; iDefenceCoverage='..iDefenceCoverage) end
                end

                if iModDistanceFromStart <= iDefenceCoverage then
                    iValidLocationCount = iValidLocationCount + 1
                    tFilteredLocations[iValidLocationCount] = tLocation
                    if bDebugMessages == true then LOG(sFunctionRef..': Location is valid, iValidLoctionCount='..iValidLocationCount) end
                end
            end
        end
    end

    if bAlsoNeedIntelCoverage == true and M27Utilities.IsTableEmpty(tFilteredLocations) == false then
        tFilteredLocations = FilterLocationsBasedOnIntelPathCoverage(aiBrain, tFilteredLocations, bNOTYETCODEDAlsoReturnClosest, bTableOfObjectsNotLocations)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tFilteredLocations
end

function FilterLocationsBasedOnIfUnclaimed(aiBrain, tLocationsToFilter, bMexNotHydro)
    local sFunctionRef = 'FilterLocationsBasedOnIfUnclaimed'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tValidLocations = {}
    if M27Utilities.IsTableEmpty(tLocationsToFilter) == true then
        M27Utilities.ErrorHandler('tLocationsToFilter doesnt contain values')
    else
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        local sFunctionRef = 'FilterLocationsBasedOnIfUnclaimed'
        if bDebugMessages == true then LOG(sFunctionRef..': Start - have valid table of locations, with size='..table.getn(tLocationsToFilter)) end
        local iValidLocationCount = 0
        local bUnclaimed
        for iLocation, tLocation in tLocationsToFilter do
                                    --IsMexOrHydroUnclaimed(aiBrain, tResourcePosition, bMexNotHydro, bTreatEnemyBuildingAsUnclaimed, bTreatAllyBuildingAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
            bUnclaimed = M27Conditions.IsMexOrHydroUnclaimed(aiBrain, tLocation, bMexNotHydro, false, false, true)
            if bDebugMessages == true then LOG(sFunctionRef..': iLocation='..iLocation..': tLocation='..repr(tLocation)..'; bUnclaimed='..tostring(bUnclaimed)) end
            if bUnclaimed == true then
                iValidLocationCount = iValidLocationCount + 1
                tValidLocations[iValidLocationCount] = tLocation
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tValidLocations
end

function GetUnclaimedMexOrHydro(bMexNotHydro, aiBrain, sPathing, iPathingGroup, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
    --Returns a table of mexes/hydros that are within the sPathing iPathingGroup which are unclaimed
    --returns {} if no such table
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetUnclaimedMexOrHydro'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tAllLocationsInGroup
    if bTreatQueuedBuildingAsUnclaimed == nil then bTreatQueuedBuildingAsUnclaimed = bTreatOurOrAllyMexAsUnclaimed end
    if bMexNotHydro == false then
        if bDebugMessages == true then LOG(sFunctionRef..': sPathing='..sPathing..': iPathingGroup='..iPathingGroup) end
        tAllLocationsInGroup = M27MapInfo.GetHydroLocationsForPathingGroup(sPathing, iPathingGroup)
    else tAllLocationsInGroup = M27MapInfo.tMexByPathingAndGrouping[sPathing][iPathingGroup] --Stores position of each mex based on the segment that it's part of; [a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
    end
    local iValidMexCount = 0
    local tUnclaimedLocations = {}
    if bDebugMessages == true then LOG(sFunctionRef..': Just before main loop, bMexNotHydro='..tostring(bMexNotHydro)..'; iPathingGroup='..iPathingGroup..'; sPathing='..sPathing..'; bTreatEnemyMexAsUnclaimed='..tostring(bTreatEnemyMexAsUnclaimed)..'; bTreatOurOrAllyMexAsUnclaimed='..tostring(bTreatOurOrAllyMexAsUnclaimed)..'; bTreatQueuedBuildingAsUnclaimed='..tostring(bTreatQueuedBuildingAsUnclaimed)) end
    if M27Utilities.IsTableEmpty(tAllLocationsInGroup) == false then
        for iMex, tMexPosition in tAllLocationsInGroup do
            if bDebugMessages == true then
                local bClaimedResult= M27Conditions.IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
                local sLocationRef = M27Utilities.ConvertLocationToReference(tMexPosition)
                LOG(sFunctionRef..': Checking if sLocation ref is unclaimed; sLocationRef='..sLocationRef..'; bClaimedResult='..tostring(bClaimedResult)..'; Brain start number='..aiBrain.M27StartPositionNumber)
            end
            if M27Conditions.IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed) == true then
                iValidMexCount = iValidMexCount + 1
                if bDebugMessages == true then
                    local sLocationRef = M27Utilities.ConvertLocationToReference(tMexPosition)
                    LOG(sFunctionRef..': iValidMexCount='..iValidMexCount..': Recorded mex with location '..sLocationRef..' as a valid mex. aiBrain startposition='..aiBrain.M27StartPositionNumber)
                end
            tUnclaimedLocations[iValidMexCount] = {}
            tUnclaimedLocations[iValidMexCount] = tMexPosition
        end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef..': Finished getting all unclaimed locations, will now draw them if there are any')
        if M27Utilities.IsTableEmpty(tUnclaimedLocations) == false then
            LOG('Have '..table.getn(tUnclaimedLocations)..' uncalimed locations, drawing them all')
            M27Utilities.DrawLocations(tUnclaimedLocations, nil, 1, 50)
        else LOG('Table is empty')
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)

    return tUnclaimedLocations
end

function GetNearestPartBuiltUnit(aiBrain, iCategoryToBuild, tStartPosition, iSearchRange)
    local bDebugMessages = false
    local sFunctionRef = 'GetNearestPartBuiltUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oNearestPartBuilt
    --Check if any nearby part-built units (that have abandoned) near tStartPosition
    if iCategoryToBuild then
        local tNearbyUnitsOfType = aiBrain:GetUnitsAroundPoint(iCategoryToBuild, tStartPosition, iSearchRange, 'Ally')
        local sPartBuiltLocationRef
        if M27Utilities.IsTableEmpty(tNearbyUnitsOfType) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Have '..table.getn(tNearbyUnitsOfType)..' units of the target type, will see if any are part-complete') end
            for iUnit, oUnit in tNearbyUnitsOfType do
                if oUnit.GetFractionComplete and oUnit:GetFractionComplete() < 1 then
                    --Check not already assigned to an existing unit
                    sPartBuiltLocationRef = M27Utilities.ConvertLocationToReference(oUnit:GetPosition())
                    if bDebugMessages == true then LOG(sFunctionRef..': Unit is part complete, checking if its location is already assigned to an engineer') end
                    --reftEngineerAssignmentsByLocation = 'M27EngineerAssignmentsByLoc'     --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the engineer unique ref assigned to this location; returns the engineer object
                    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sPartBuiltLocationRef]) == true then
                        if bDebugMessages == true then LOG(sFunctionRef..': Location not assigned to an engineer, so will assist this') end
                        oNearestPartBuilt = oUnit
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oNearestPartBuilt
end

function GetActionTargetAndObject(aiBrain, iActionRefToAssign, tExistingLocationsToPickFrom, tIdleEngineers, iActionPriority, tsUnitStatesToIgnoreCurrent, iSearchRangeForPrevEngi, iSearchRangeForNearestEngi, bOnlyReassignIdle, bGetInitialEngineer, iMinTechLevelWanted)
    --Returns both the location of the target, and (if relevant) the object (either the first engineer assigned the action, or the building its constructing if it exists yet); will return nil for object if there is none
    --if tExistingLocationsToPickFrom isn't nil then will only refer to here
    --Variables from tIdleEngineers onwards are only used by the mex functionality which will use the existing function to get the nearest idle engineer, and see hwo far it is from the mex
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetActionTargetAndObject'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)



    local tLocationsToGoThrough = tExistingLocationsToPickFrom
    local tNearbyUnitsOfType, iCategoryToBuild
    local tActionLocation, oActionObject
    local iClosestUnassignedLocation = 10000
    local iCurLocationDistance
    local tCurAssignments
    local bLocationAlreadyAssigned
    local oEngiAlreadyAssigned
    local oFirstConstructingEngineer
    local oBuildingUnderConstruction
    local oAssistTarget
    local bAssistBuildingOrEngineer = false
    local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]



    local bClearCurrentlyAssignedEngineer = false --e.g. if want to switch to T2 unit then will clear actions of the currently assigned engineer

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    if iActionRefToAssign == refActionUpgradeBuilding or iActionRefToAssign == refActionAssistSMD or iActionRefToAssign == refActionAssistAirFactory or iActionRefToAssign == refActionUpgradeHQ then
        --Find the nearest building that is upgrading and assist it, but set a timer to reconsider engineer action after a while
        if bDebugMessages == true then LOG(sFunctionRef..': About to search for buildings to assist in upgrading') end
        local iCategoryToAssist = M27UnitInfo.refCategoryStructure
        local sUnitStateWanted = 'Upgrading'
        local sAltUnitStateWanted
        local bIgnoreUnitState = false
        local iEnemySearchRange = 60
        local tAllBuildings

        if iActionRefToAssign == refActionAssistSMD then
            iCategoryToAssist = M27UnitInfo.refCategorySMD
            sUnitStateWanted = 'SiloBuildingAmmo'
            iEnemySearchRange = 0
        elseif iActionRefToAssign == refActionAssistAirFactory then
            iCategoryToAssist = M27UnitInfo.refCategoryAirFactory
            sUnitStateWanted = 'Building'
            sAltUnitStateWanted = 'Upgrading'
            iEnemySearchRange = 20
        elseif iActionRefToAssign == refActionUpgradeHQ then
            tAllBuildings = aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]
            bIgnoreUnitState = true
            iEnemySearchRange = 0
        end


        if M27Utilities.IsTableEmpty(tAllBuildings) then tAllBuildings = aiBrain:GetListOfUnits(iCategoryToAssist, false, false) end
        local iNearestUpgradingBuilding = 10000
        local iCurDistanceToStart, tCurPosition
        local tNearbyEnemies


        if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through all buildings meeting the category in question to see if we can assist them') end
        if M27Utilities.IsTableEmpty(tAllBuildings) == false then
            for iBuilding, oBuilding in tAllBuildings do
                if bDebugMessages == true then LOG(sFunctionRef..': iBuilding='..iBuilding..'; oBuilding Id='..oBuilding:GetUnitId()..'; Unit state='..M27Logic.GetUnitState(oBuilding)) end
                if oBuilding:GetFractionComplete() < 1 or bIgnoreUnitState or (oBuilding.IsUnitState and (oBuilding:IsUnitState(sUnitStateWanted) or (sAltUnitStateWanted and oBuilding:IsUnitState(sAltUnitStateWanted)))) then
                    tCurPosition = oBuilding:GetPosition()
                    iCurDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tCurPosition, tStartPosition)
                    if bDebugMessages == true then LOG(sFunctionRef..': iBuilding is '..sUnitStateWanted..';  its distance to start='..iCurDistanceToStart) end
                    if iCurDistanceToStart < iNearestUpgradingBuilding then
                        --Check no nearby enemies
                        if iEnemySearchRange > 0 then tNearbyEnemies = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.DIRECTFIRE + categories.LAND * categories.INDIRECTFIRE, tCurPosition, iEnemySearchRange, 'Enemy')
                        else tNearbyEnemies = nil end
                        if M27Utilities.IsTableEmpty(tNearbyEnemies) == true then
                            if bDebugMessages == true then LOG(sFunctionRef..': No nearby enemies so will assign this building as target unless we subsequently find ones that are even closer') end
                            iNearestUpgradingBuilding = iCurDistanceToStart
                            oActionObject = oBuilding
                            tActionLocation = oBuilding:GetPosition()
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Have nearby enemies so not picking this building') end
                        end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': oBuilding='..oBuilding:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oBuilding)..'; Unit state='..M27Logic.GetUnitState(oBuilding)) end
                end
            end
        else
            M27Utilities.ErrorHandler('Couldnt find any buildings for Action '..(iActionRefToAssign or 'nil'))
        end
    else
        if M27Utilities.IsTableEmpty(tLocationsToGoThrough) == true then --No locations to go through
            if iActionRefToAssign == refActionBuildMex then M27Utilities.ErrorHandler('Likely error - should have mex location determined before calling the action') end
            if bDebugMessages == true then LOG(sFunctionRef..': Dont have existing locations to choose from, so pick location based on action') end
            --Pick targets based on action
            if iActionRefToAssign == refActionReclaimArea then
                --Get preferred reclaim position - pick engineer closest to below location (will overwrite the actual target location later on when assigning reclaim action)
                tActionLocation = M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]
            elseif iActionRefToAssign == refActionReclaimUnit then
                --Pick a reclaim unit closest to our start
                oActionObject = M27Utilities.GetNearestUnit(aiBrain[M27EconomyOverseer.reftUnitsToReclaim], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain, false, false)
                if oActionObject.GetPosition then
                    tActionLocation = oActionObject:GetPosition()
                else oActionObject = nil
                end
            elseif iActionRefToAssign == refActionReclaimTrees then
                tActionLocation = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
            elseif iActionRefToAssign == refActionBuildT1Sonar or iActionRefToAssign == refActionBuildT2Sonar then
                if bDebugMessages == true then LOG(sFunctionRef..': Want to build sonar, will try and find a water location along a line from us to enemy base') end
                --Find water along the way from our base to the midpoint of the map that is pathable by an amphibious unit
                local tPossiblePosition
                local iT2SonarAdjust = 5
                --local iAngleToEnemyBase = M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
                for iCurPath = 1, math.floor(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.05) do
                    --Debug mode - draw valid location in gold, invalid locations in red
                    tPossiblePosition = M27Utilities.MoveTowardsTarget(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)], iCurPath * 10 + iT2SonarAdjust, 0)
                    if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tPossiblePosition) == aiBrain[M27MapInfo.refiStartingSegmentGroup][M27UnitInfo.refPathingTypeAmphibious] and not(M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, tPossiblePosition) == aiBrain[M27MapInfo.refiStartingSegmentGroup][M27UnitInfo.refPathingTypeLand]) then
                        --Can path there amphibiously but not with land, is the locaiton water?
                        if GetTerrainHeight(tPossiblePosition[1], tPossiblePosition[3]) < M27MapInfo.iMapWaterHeight then
                            --Is underwater, so want to build around here
                            if bDebugMessages == true then M27Utilities.DrawLocation(tPossiblePosition, nil, 4) end
                            tActionLocation = tPossiblePosition
                            break
                        end
                    end
                    if bDebugMessages == true then M27Utilities.DrawLocation(tPossiblePosition, nil, 2) end
                end
                if M27Utilities.IsTableEmpty(tActionLocation) then
                    --Try a (sort of) random location
                    if bDebugMessages == true then LOG(sFunctionRef..': COuldnt find a location moving in a straight line so will try a random location') end
                    local tBasePoint = M27Utilities.MoveTowardsTarget(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)], aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.25, 0)
                    for iDistanceAdjust = 50, 250, 50 do
                        for iAngleAdjust = -2, 6 do
                            tPossiblePosition = M27Utilities.MoveTowardsTarget(tBasePoint, M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)], iDistanceAdjust + iT2SonarAdjust, iAngleAdjust * 45)
                            if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tPossiblePosition) == aiBrain[M27MapInfo.refiStartingSegmentGroup][M27UnitInfo.refPathingTypeAmphibious] and not(M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, tPossiblePosition) == aiBrain[M27MapInfo.refiStartingSegmentGroup][M27UnitInfo.refPathingTypeLand]) then
                                --Can path there amphibiously but not with land, is the locaiton water?
                                if GetTerrainHeight(tPossiblePosition[1], tPossiblePosition[3]) < M27MapInfo.iMapWaterHeight then
                                    --Is underwater, so want to build around here
                                    if bDebugMessages == true then M27Utilities.DrawLocation(tPossiblePosition, nil, 4) end
                                    tActionLocation = tPossiblePosition
                                    break
                                end
                            end
                            if bDebugMessages == true then M27Utilities.DrawLocation(tPossiblePosition, nil, 2) end
                        end
                    end
                    if M27Utilities.IsTableEmpty(tActionLocation) then M27Utilities.ErrorHandler('Unable to find any water to build sonar on despite being able to path to enemy base only with amphibious units') end
                end
            else
                --First check if we are already building anything under this action (in which case want to assist it instead of building a new one)
                if aiBrain[reftEngineerAssignmentsByActionRef] then
                    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionRefToAssign]) == false then
                        oFirstConstructingEngineer = nil
                        local oEngi
                        local iEngineerCount = 0
                        for iEngi, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][iActionRefToAssign] do
                            iEngineerCount = iEngineerCount + 1
                            if not(oFirstConstructingEngineer) then
                                oEngi = tSubtable[refEngineerAssignmentEngineerRef]
                                if bDebugMessages == true then LOG(sFunctionRef..': Cycling through engineers assigned to action '..iActionRefToAssign..'; Engi unique ref='..iEngi) end
                                if oEngi.GetUnitId == nil then LOG(sFunctionRef..': oEngi doesnt have a unit ID so likely error recording it') end
                                if not(oEngi.Dead) and oEngi.GetPosition then
                                    oFirstConstructingEngineer = oEngi
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef..': Engi is still alive so assigning it as the first constructing engineer')
                                    else break --If debug not enabled not interested in engineer count
                                    end
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': size of engineers assigned to iActionRef '..iActionRefToAssign..' is: '..iEngineerCount) end


                        if oFirstConstructingEngineer == nil then
                            --Not bothered about units with the spare action as they all operate independently, and theyre ctrlKd
                            if not(iActionRefToAssign == refActionSpare) then M27Utilities.ErrorHandler('Potential error unless unit died in last second - FirstConstructingEngineer for action ref '..iActionRefToAssign..' is dead or not a unit', nil, true) end
                        else
                            if bDebugMessages == true then
                                local sFirstConstructingName = GetEngineerUniqueCount(oFirstConstructingEngineer)
                                LOG(sFunctionRef..': First constructing engineer unique ref='..sFirstConstructingName)
                            end
                            --Do we want to assist the first constructing engineer, or instead clear it of its actions and become the first constructing engineer?
                            bAssistBuildingOrEngineer = true
                            if iMinTechLevelWanted > 1 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Checking if unit constructing tech level is below the min wanted') end
                                if M27UnitInfo.GetUnitTechLevel(oFirstConstructingEngineer) < iMinTechLevelWanted then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Unit constructing tech level is below the min wanted so will mark it to be cleared') end
                                    bAssistBuildingOrEngineer = false
                                    bClearCurrentlyAssignedEngineer = true
                                end
                            end
                            if bAssistBuildingOrEngineer == true then oAssistTarget = oFirstConstructingEngineer end
                            --[[if oFirstConstructingEngineer:IsUnitState('Building') == true then
                                oBuildingUnderConstruction = oFirstConstructingEngineer:GetFocusUnit()
                                if oBuildingUnderConstruction.GetFractionComplete then
                                    local iFractionComplete = oBuildingUnderConstruction:GetFractionComplete()
                                    if iFractionComplete < 1 and iFractionComplete > 0 then
                                        if not(oBuildingUnderConstruction.GetPosition) then M27Utilities.ErrorHandler('Building under construction doesnt have a position so ignoring')
                                        else oAssistTarget = oBuildingUnderConstruction end
                                    end
                                end
                            end--]]
                        end
                    else
                        --Check if any nearby part-built units (that have abandoned) near the start position
                        local iCategoryToBuild = GetCategoryToBuildFromAction(iActionRefToAssign, iMinTechLevelWanted)
                        local oNearestPartBuilt = GetNearestPartBuiltUnit(aiBrain, iCategoryToBuild, tStartPosition, math.max(iSearchRangeForNearestEngi, 30))
                        if oNearestPartBuilt then
                           if bDebugMessages == true then LOG(sFunctionRef..': Are assisting part built building') end
                           bAssistBuildingOrEngineer = true
                           oAssistTarget = oNearestPartBuilt
                       end
                    end
                end
                if bAssistBuildingOrEngineer == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': Are assisting building or engineer') end
                    oActionObject = oAssistTarget
                    tActionLocation = oActionObject:GetPosition()
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Will construct a new building instead of assisting') end
                    --Need to create a new building instead of assisting - will determine actual location to try and build later on
                    tActionLocation = tStartPosition
                end
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Have already been given a list of potential locations to consider') end
            --Pick target from existing locations, and check if already been assigned to an engineer (e.g. would expect this to be done for actions to buidl mex and hydro)
            local oNearestEngineer, tPositionToLookFrom
            for iLocation, tLocation in tExistingLocationsToPickFrom do
                if not(iActionRefToAssign == refActionBuildMex) then
                    --Check if any nearby part-built units (that have abandoned) near the start position
                    local iCategoryToBuild = GetCategoryToBuildFromAction(iActionRefToAssign, iMinTechLevelWanted)
                    local oNearestPartBuilt = GetNearestPartBuiltUnit(aiBrain, iCategoryToBuild, tLocation, math.max(iSearchRangeForNearestEngi, 30))
                    if oNearestPartBuilt then
                        if bDebugMessages == true then LOG(sFunctionRef..': Are assisting part built building') end
                        bAssistBuildingOrEngineer = true
                        oActionObject = oNearestPartBuilt
                        tActionLocation = oActionObject:GetPosition()
                        break
                    end
                end
                bLocationAlreadyAssigned = false
                local sLocationRef = M27Utilities.ConvertLocationToReference(tLocation)
                if not(aiBrain[reftEngineerAssignmentsByLocation] == nil) then
                    if not(iActionRefToAssign == refActionBuildMassStorage) or (aiBrain:CanBuildStructureAt('uab1106', tLocation) or (aiBrain[reftEngineerAssignmentsByLocation][sLocationRef] and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionRefToAssign]) == false)) then
                        --reftEngineerAssignmentsByLocation --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the engineer unique ref assigned to this location
                        tCurAssignments = aiBrain[reftEngineerAssignmentsByLocation][sLocationRef]
                        if M27Utilities.IsTableEmpty(tCurAssignments) == false then
                            --Could we build the building we want to at this location
                            if bDebugMessages == true then LOG(sFunctionRef..': Checking if the location has been assigned already, sLocationRef='..sLocationRef) end
                            if M27Utilities.IsTableEmpty(tCurAssignments[iActionRefToAssign]) == false then
                                oEngiAlreadyAssigned = nil
                                for iUniqueEngiRef, oEngi in tCurAssignments[iActionRefToAssign] do
                                    if not(oEngi.Dead) and oEngi.GetPosition then
                                        oEngiAlreadyAssigned = oEngi
                                        break
                                    end
                                end
                                if oEngiAlreadyAssigned == nil then
                                    if bDebugMessages == true then LOG(sFunctionRef..': sLocationRef='..sLocationRef..': No alive engineer has been assigned this action yet') end
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': iLocation='..iLocation..' is already assigned to an engineer so will ignore unless building hydro. iActionRefToAssign='..iActionRefToAssign) end
                                    bLocationAlreadyAssigned = true
                                    if iActionRefToAssign == refActionBuildHydro or iActionRefToAssign == refActionBuildMassStorage or iActionRefToAssign == refActionBuildT3MexOverT2 then --If we're building a mex dont need to assist it.  If we're building a hydro or mass storage then do want to assist it
                                        oActionObject = oEngiAlreadyAssigned
                                        tActionLocation = oActionObject:GetPosition()
                                        if bDebugMessages == true then LOG(sFunctionRef..': iLocation='..iLocation..'; Location of engineer that will be assisting='..repr(tActionLocation)) end
                                        if M27Utilities.IsTableEmpty(tActionLocation) == true then
                                            if not(oActionObject.GetUnitId) then
                                                M27Utilities.ErrorHandler('Action object doesnt have a unit ID; iActionRefToAssign='..iActionRefToAssign..'; previously had a workaround, have commented out for new appraoch, revisit')
                                                --[[LOG('Strange issue for iActionRefToAssign='..iActionRefToAssign..' where oEngineer has somehow become the table above it, will try a workaround')
                                                if M27Utilities.IsTableEmpty(oActionObject[1]) == false and oActionObject[1][1] and oActionObject[1][3] then
                                                    LOG(sFunctionRef..': Replacing the location')
                                                    tActionLocation = {oActionObject[1][1], oActionObject[1][2], oActionObject[1][3]}
                                                    if oActionObject[2].GetUnitId then oActionObject = oActionObject[2] end
                                                else
                                                    LOG(sFunctionRef..': oActionObject subtable doesnt have a location, so will use current location instead')
                                                    tActionLocation = tLocation
                                                end--]]
                                            else
                                                M27Utilities.ErrorHandler('tActionLocation is nil')
                                            end
                                        end
                                        break
                                    end
                                end
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': table for sLocationRef='..sLocationRef..' is empty') end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Mass storage location is blocked') end
                    end
                end
                if bLocationAlreadyAssigned == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': iLocation='..iLocation..': No other engineer has target location ref '..sLocationRef..', so if its the closest one to us will pick it') end
                    tPositionToLookFrom = tStartPosition
                    if iActionRefToAssign == refActionBuildMex or iActionRefToAssign == refActionBuildMassStorage then
                        --Find the nearest unassigned engineer
                        --GetNearestEngineerWithLowerPriority(aiBrain, tEngineers, iCurrentActionPriority, tCurrentActionTarget, iActionRefToGetExistingCount, tsUnitStatesToIgnore, iMaxRangeForPrevEngi, iMaxRangeForNearestEngi, bOnlyGetIdleEngis, bGetInitialEngineer)
                        oNearestEngineer = GetNearestEngineerWithLowerPriority(aiBrain, tIdleEngineers, iActionPriority, tLocation, iActionRefToAssign, tsUnitStatesToIgnoreCurrent, iSearchRangeForPrevEngi, iSearchRangeForNearestEngi, bOnlyReassignIdle, bGetInitialEngineer)
                        if oNearestEngineer and oNearestEngineer.GetPosition then
                            if bDebugMessages == true then LOG(sFunctionRef..': Found an engi near to the mex, so will use this as the base position to see how close the mex is to it') end
                            tPositionToLookFrom = oNearestEngineer:GetPosition()
                        end
                    end

                    iCurLocationDistance = M27Utilities.GetDistanceBetweenPositions(tLocation, tPositionToLookFrom)
                    if iCurLocationDistance < iClosestUnassignedLocation then
                        if bDebugMessages == true then LOG(sFunctionRef..': Location is closest, iCurLocationDistance='..iCurLocationDistance..' based on tPositionToLookFrom='..repr(tPositionToLookFrom)) end
                        iClosestUnassignedLocation = iCurLocationDistance
                        tActionLocation = tLocation
                    end
                    if iActionRefToAssign == refActionBuildT3MexOverT2 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Will assign nearest T2 mex as the action object') end
                        oActionObject = aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]
                        if M27UnitInfo.IsUnitValid(oActionObject) == false then M27Utilities.ErrorHandler('Dont have a valid mex assigned for the action to build t3 mex') end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Already have the target location assigned to another engineer') end
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef..': About to return tActionLocation and oActionObject')
        if M27Utilities.IsTableEmpty(tActionLocation) == true then LOG(sFunctionRef..': End - iActionRefToAssign='..iActionRefToAssign..'; tActionLocation is nil/empty')
        else LOG(sFunctionRef..': tActionLocation ref='..M27Utilities.ConvertLocationToReference(tActionLocation)) end
        if oActionObject == nil then LOG(sFunctionRef..': End - oActionObject is nil/empty')
        else if M27UnitInfo.GetUnitLifetimeCount(oActionObject) then LOG(sFunctionRef..': oActionObject lifetime count='..M27UnitInfo.GetUnitLifetimeCount(oActionObject))
            else LOG(sFunctionRef..': oActionObject exists but has no lifetime count') end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tActionLocation, oActionObject, bClearCurrentlyAssignedEngineer
end

function GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetUnclaimedMexes'
    if bDebugMessages == true then LOG(sFunctionRef..': bTreatEnemyMexAsUnclaimed='..tostring(bTreatEnemyMexAsUnclaimed)..'; bTreatOurOrAllyMexAsUnclaimed='..tostring(bTreatOurOrAllyMexAsUnclaimed)..'; bTreatQueuedBuildingAsUnclaimed='..tostring(bTreatQueuedBuildingAsUnclaimed)) end
    --GetUnclaimedMexOrHydro(bMexNotHydro, aiBrain, sPathing, iPathingGroup, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
    return GetUnclaimedMexOrHydro(true, aiBrain, sPathing, iPathingGroup, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
end

function GetUnclaimedHydros(aiBrain, sPathing, iPathingGroup, bTreatEnemyHydroAsUnclaimed, bTreatOurOrAllyHydroAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
    return GetUnclaimedMexOrHydro(false, aiBrain, sPathing, iPathingGroup, bTreatEnemyHydroAsUnclaimed, bTreatOurOrAllyHydroAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
end


function ReassignEngineers(aiBrain, bOnlyReassignIdle, tEngineersToReassign)
    --tEngineersToReassign - optional - if specified, then will only consider these engineers for reassignment

    --DEBUGGING: Key log below to look for: LOG(sFunctionRef..': Game time='..GetGameTimeSeconds()..': About to assign action '..iActionToAssign..' to engineer number '..GetEngineerUniqueCount(oEngineerToAssign)..' with lifetime count='..sEngineerName..'; Eng unitId='..oEngineerToAssign:GetUnitId()..'; ActionTargetLocation='..repr(tActionTargetLocation))

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReassignEngineers'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if M27Logic.iTimeOfLastBrainAllDefeated < 10 then


        local tEngineers
        local bOnlyLookingAtSomeEngineers = false
        if tEngineersToReassign == nil then
            bOnlyLookingAtSomeEngineers = true
            tEngineers = aiBrain:GetListOfUnits(refCategoryEngineer, false, true)
        else tEngineers = tEngineersToReassign end
        local tIdleEngineers = {}
        local iEngineersToConsider = 0
        local bEngineerIsBusy = false
        local tsUnitStatesToIgnoreStrict = {'Building', 'Repairing', 'BeingBuilt'}
        local tsUnitStateToIgnoreBroader = {'Building', 'Repairing', 'BeingBuilt', 'Moving', 'Reclaiming', 'Guarding'}
        local tsUnitStatesToIgnoreBase, tsUnitStatesToIgnoreCurrent
        if bOnlyReassignIdle == true then tsUnitStatesToIgnoreBase = tsUnitStateToIgnoreBroader
        else tsUnitStatesToIgnoreBase = tsUnitStatesToIgnoreStrict end



            local iHighestTechLevelEngi = 1
            local iMinEngiTechLevelWanted
            local iCurEngiTechLevel


          --TEMPTEST(aiBrain, sFunctionRef..': Pre record prev actions')
            --RecordPreviousEngineerActions(aiBrain)
            --Determine engineers that are available to be assigned
            local bStillHaveEarlyEngis = false
            local iIdleEarlyEngis = 0
            local iInitialCountThreshold = aiBrain[refiInitialMexBuildersWanted]

            --local iEngineersAlreadyBuildingMexes = 0
            if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
          --TEMPTEST(aiBrain, sFunctionRef..': Start')
            local sEngineerID

            if M27Utilities.IsTableEmpty(tEngineers) == false then
                for iEngineer, oEngineer in tEngineers do
                    if not(oEngineer.Dead) and oEngineer.GetFractionComplete and oEngineer:GetFractionComplete() >= 1 then
                        --if GetEngineerUniqueCount(oEngineer) == 59 then bDebugMessages = true end
                        sEngineerID = oEngineer:GetUnitId()
                        if M27UnitInfo.GetUnitLifetimeCount(oEngineer) <= iInitialCountThreshold then bStillHaveEarlyEngis = true end

                        bEngineerIsBusy = ProcessingEngineerActionForNearbyEnemies(aiBrain, oEngineer)
                        if bEngineerIsBusy == false and oEngineer[refiEngineerCurrentAction] == refActionHasNearbyEnemies then
                            ClearEngineerActionTrackers(aiBrain, oEngineer, true)
                        end
                        if bDebugMessages == true then
                            local sUniqueRef = GetEngineerUniqueCount(oEngineer)
                            LOG(sFunctionRef..': Cycling through all engineers. Engineer Unique ref='..sUniqueRef..' Lifetimecount='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' iEngineer in loop of current engineers being considered='..iEngineer..'; Engineer state='..M27Logic.GetUnitState(oEngineer)..'; bOnlyReassignIdle='..tostring(bOnlyReassignIdle)..'; M27Logic.IsUnitIdle(oEngineer, not(bOnlyReassignIdle))='..tostring(M27Logic.IsUnitIdle(oEngineer, not(bOnlyReassignIdle), not(bOnlyReassignIdle), true))..'; bEngineerIsBusy after nearby enemy check='..tostring(bEngineerIsBusy))
                        end
                        if bEngineerIsBusy == false then
                            if bDebugMessages == true then LOG(sFunctionRef..': Engineer doest have nearby enemies, checking if its busy') end
                            if bOnlyReassignIdle == true then
                                bEngineerIsBusy = not(M27Logic.IsUnitIdle(oEngineer, false, false, true)) --Dont want to constantly reassign guarding units or else if theyre assisting a building they'll keep stuttering and not do anything; if this causes issues elsewhere then need to think up better solution
                                if bDebugMessages == true then LOG(sFunctionRef..': EngineerIsBusy based on IsUnitIdle ='..tostring(bEngineerIsBusy)) end
                            else
                                if oEngineer[refiEngineerCurrentAction] == refActionSpare then
                                    tsUnitStatesToIgnoreCurrent = tsUnitStatesToIgnoreStrict
                                else tsUnitStatesToIgnoreCurrent = tsUnitStatesToIgnoreBase end
                                if bDebugMessages == true then LOG(sFunctionRef..': Cycling through engineer unit states and comparing to the list of states to treat as idle') end
                                if oEngineer.IsUnitState then
                                    for iState, sState in tsUnitStatesToIgnoreCurrent do
                                        if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..'; considering if iEngineer state is '..sState) end
                                        if oEngineer:IsUnitState(sState) == true then
                                            bEngineerIsBusy = true break end
                                    end
                                end
                            end
                        end
                        --oEngineer[refbEngineerActionBeingRefreshed] = not(bEngineerIsBusy)
                        if bEngineerIsBusy == false then
                            iEngineersToConsider = iEngineersToConsider + 1
                            tIdleEngineers[iEngineersToConsider] = oEngineer
                            --if GetEngineerUniqueCount(oEngineer) == 59 then bDebugMessages = true end
                            if bDebugMessages == true then LOG(sFunctionRef..': Engineer with UC='..GetEngineerUniqueCount(oEngineer)..' isnt busy so will clear its action trackers') end
                            ClearEngineerActionTrackers(aiBrain, oEngineer)
                            iCurEngiTechLevel = M27UnitInfo.GetUnitTechLevel(oEngineer)
                            if iCurEngiTechLevel > iHighestTechLevelEngi then iHighestTechLevelEngi = iCurEngiTechLevel end
                            if bDebugMessages == true then LOG(sFunctionRef..': Engineer isnt busy, so recording as available and clearing its actions. iCurEngiTechLevel='..iCurEngiTechLevel) end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Engineer is busy so leaving alone') end
                        end
                        if bStillHaveEarlyEngis == true then
                            --if oEngineer[refiEngineerCurrentAction] == refActionBuildMex then iEngineersAlreadyBuildingMexes = iEngineersAlreadyBuildingMexes + 1 end
                            if M27UnitInfo.GetUnitLifetimeCount(oEngineer) <= iInitialCountThreshold and iCurEngiTechLevel == 1 then
                                if bEngineerIsBusy == false then
                                    iIdleEarlyEngis = iIdleEarlyEngis + 1
                                end
                            end
                        end
                    elseif oEngineer.Dead then
                        if bDebugMessages == true then LOG(sFunctionRef..': Engineer is dead so clearing its actions') end
                        ClearEngineerActionTrackers(aiBrain, oEngineer)
                    end
                end
            end
            if bOnlyReassignIdle == nil then bOnlyReassignIdle = false end
            local iAllEngineers = iEngineersToConsider

            if bDebugMessages == true then
                if iIdleEarlyEngis == nil then LOG('iIdleEarlyEngis is nil') else LOG('iIdleEarlyEngis='..iIdleEarlyEngis) end
                --LOG('iEngineersAlreadyBuildingMexes='..iEngineersAlreadyBuildingMexes)
            end

            local iHighestFactoryOrEngineerTechAvailable = math.max(aiBrain[M27Overseer.refiOurHighestFactoryTechLevel], iHighestTechLevelEngi)

            if iEngineersToConsider > 0 then
          --TEMPTEST(aiBrain, sFunctionRef..': After determined have engineers to consider')
                --Reset action variables for any engineers that are idle (otherwise will end up having an engineer with that action thinking it can assit itself)
                --[[ Now handled via function called whenever engineer is given action or is being made available for an action
                local oRecordedEngineer
                if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation]) == false then
                    for iRef1, tSubtable in aiBrain[reftEngineerAssignmentsByLocation] do
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering resetting for iRef1='..iRef1) end
                        if M27Utilities.IsTableEmpty(tSubtable) == false then
                            for iRef2, tSubSubTable in tSubtable do
                                if bDebugMessages == true then LOG(sFunctionRef..': Considering resetting for iRef1='..iRef1..'; iRef2='..iRef2) end
                                oRecordedEngineer = tSubSubTable[refEngineerAssignmentEngineerRef]
                                if bDebugMessages == true then if oRecordedEngineer and oRecordedEngineer.GetUnitId then LOG(sFunctionRef..': oRecordedEngineer ID='..oRecordedEngineer:GetUnitId()) end end
                                if oRecordedEngineer and oRecordedEngineer[refbEngineerActionBeingRefreshed] == true then
                                    if bDebugMessages == true then LOG(sFunctionRef..': iRef1='..iRef1..'; iRef2='..iRef2..': Engineer assigned is being refreshed so resetting') end
                                    aiBrain[reftEngineerAssignmentsByLocation][iRef1][iRef2] = {}
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': iRef1='..iRef1..'; iRef2='..iRef2..': Engineer assigned isnt being refreshed') end
                                end
                            end
                        end
                    end
                end
                if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef]) == false then
                    for iActionRef, oRecordedEngineer in aiBrain[reftEngineerAssignmentsByActionRef] do
                        if oRecordedEngineer[refbEngineerActionBeingRefreshed] == true then
                            aiBrain[reftEngineerAssignmentsByActionRef][iActionRef] = nil
                        end
                    end
                end--]]

                local iCurrentConditionToTry = 1
                local oEngineerToAssign, iExistingEngineersAssigned, bWillBeAssigning
                local iLoopCount = 0
                local iMaxLoopCount = 150

                --Get values for various conditions that wont change so dont have to keep getting them for every engineer in the loop:
                local iGameTime = GetGameTimeSeconds()
                local sPathing = M27UnitInfo.refPathingTypeAmphibious
                local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                local iSegmentX, iSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tStartPosition)
                local iPathingGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iSegmentX, iSegmentZ)
                if bDebugMessages == true then LOG(sFunctionRef..': iEngineersToConsider ='..iEngineersToConsider..'; about to get unclaimed mexes') end
                local tAllUnclaimedHydroInPathingGroup
                --NOTE: For optimisation reasons, variables are declared here but are first defined in the first condition that uses them (so dont obtain the condition value if not enough engineers in the first place)
                local tAllUnclaimedMexesInPathingGroup, iAllUnclaimedMexesInPathingGroup, tAllUnclaimedMexesInLandPathingGroup, iAllUnclaimedMexesInLandPathingGroup
                local tUnclaimedMexesOnOurSideOfMap, iUnclaimedMexesOnOurSideOfMap
                local tUnclaimedMexesWithinDefenceCoverage, iUnclaimedMexesWithinDefenceCoverage
                local iUnclaimedHydroWithinDefenceCoverage, tUnclaimedHydroWithinDefenceCoverage
                local bNearbyHydro, tNearbyHydro, iUnclaimedHydroNearBase, tUnclaimedHydroNearBase
                local iGrossCurEnergyIncome, iNetCurEnergyIncome
                local iLandFactories, iAirFactories, iMassStored, iEnergyStored, iEnergyStorageMax, iEnergyStoredRatio, iMassStoredRatio
                local tExistingLocationsToPickFrom

                local iMaxEngisWanted
                local iActionToAssign
                local tActionTargetLocation, oActionTargetObject
                local iSearchRangeForPrevEngi = 100 --when set to 50 would sometimes have issues with engis looping from one to the other
                local iSearchRangeForNearestEngi --will ignore engis further away than this - should set to massive value for mexes etc. that build far away from base, but low value for buildings that want built by base

                --Build order threshold variables:
                local bThresholdInitialEngineerCondition
                local bThresholdPreReclaimEngineerCondition
                local iCurConditionEngiShortfall
                local bClearCurrentlyAssignedEngineer

                local bHaveVeryLowPower = false
                local bWantMorePower = true
                iNetCurEnergyIncome = aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome]
                iEnergyStored = aiBrain:GetEconomyStored('ENERGY')
                --NOTE: IF UPDATING LOW POWER VALUES: Also consider updating spare engineer action
                if iNetCurEnergyIncome < 0 then
                    if iEnergyStored < 1000 then
                        bHaveVeryLowPower = true
                    end
                elseif iEnergyStored < 50 then bHaveVeryLowPower = true
                end
                local bHaveLowPower = bHaveVeryLowPower
                local iLowPowerThreshold = 6
                local iGrossMassIncome = aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]
                local iAbsolutePowerBufferWanted = 10 --Min amoutn of net energy income wanted per tick; 100 for t1
                local iEnergyBufferMassFactorWanted = 7 --e.g. t2 mex needs 6 power for every 1 mass; T1 bomber is 22.8; striker is 4.75
                local iExtraEngisForPowerBasedOnTech = 0

                if iHighestFactoryOrEngineerTechAvailable >= 3 then
                    iLowPowerThreshold = 40
                    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                        iEnergyBufferMassFactorWanted = 50
                    else
                        --Increase based on number of T3 air factories we have - --t3 mex needs 7 power for every 1 mass; titan needs 11, t3 strat 69
                        iEnergyBufferMassFactorWanted = math.min(50,15 + aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory * categories.TECH3) * 5)
                    end
                    iAbsolutePowerBufferWanted = 250 --2500
                    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
                        iEnergyBufferMassFactorWanted = iEnergyBufferMassFactorWanted * 0.9
                        iAbsolutePowerBufferWanted = 80 --800
                    end
                    iExtraEngisForPowerBasedOnTech = 5
                elseif iHighestFactoryOrEngineerTechAvailable == 2 then
                    iLowPowerThreshold = 10
                    iEnergyBufferMassFactorWanted = 12    --T3 mex is 7:1, janus is 20, pillar is 5
                    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then iEnergyBufferMassFactorWanted = 15 end
                    iAbsolutePowerBufferWanted = 40 --400
                    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
                        iEnergyBufferMassFactorWanted = 9
                        iAbsolutePowerBufferWanted = 25 --250
                    end
                    iExtraEngisForPowerBasedOnTech = 7
                else
                    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then iEnergyBufferMassFactorWanted = 15 end
                end
                --Reduce power buffers wanted if are ecoing (as want to focus more on mass)



                local iPowerWantedPerTick = math.max(iGrossMassIncome * iEnergyBufferMassFactorWanted, aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] - aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome]) + iAbsolutePowerBufferWanted
                --Ensure we can support guncom
                iPowerWantedPerTick = math.max(iPowerWantedPerTick, 50)

                if bHaveLowPower == false then
                    if iNetCurEnergyIncome < iLowPowerThreshold and (iEnergyStored < 4000 or aiBrain:GetEconomyStoredRatio('ENERGY') < 0.95) then bHaveLowPower = true
                    elseif iEnergyStored < 2000 or aiBrain:GetEconomyStoredRatio('ENERGY') < 0.6 then bHaveLowPower = true end
                end
                if bHaveLowPower == false then
                    --Do we have enough power? Base the power wanted on factory tech level
                    --is true by default
                    if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] > iPowerWantedPerTick then bWantMorePower = false end
                end

                if bDebugMessages == true then LOG(sFunctionRef..': Power calcs: bHaveLowPower='..tostring(bHaveLowPower)..'; bWantMorePower='..tostring(bWantMorePower)..'; iPowerWantedPerTick='..iPowerWantedPerTick..'; iNetCurEnergyIncome='..iNetCurEnergyIncome..'; % energy stored='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; iEnergyBufferMassFactorWanted='..iEnergyBufferMassFactorWanted..'; iGrossMassIncome='..iGrossMassIncome..'; aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; iAbsolutePowerBufferWanted='..iAbsolutePowerBufferWanted) end




                aiBrain[refiBOInitialEngineersWanted] = 0
                aiBrain[refiBOPreReclaimEngineersWanted] = 0
                aiBrain[refiBOPreSpareEngineersWanted] = 0
                aiBrain[refiBOActiveSpareEngineers] = {0,0,0,0}

                local bGetInitialEngineer
                local bAreOnSpareActions = false
                local iT2Power, iT3Power
                local iCurRadarCount, iCurT2RadarCount
                local iNearbyOmniCount
                local bHaveLowMass = M27Conditions.HaveLowMass(aiBrain)



                local iCount = 0
                while iEngineersToConsider > 0 do
                    iCount = iCount + 1
                    if M27Logic.iTimeOfLastBrainAllDefeated > 10 then break end
                    if iCount > 100 then
                        if iEngineersToConsider < 40 then
                            M27Utilities.ErrorHandler('Infinite loop - have done more than 100 cycles but only have '..(iEngineersToConsider or 'nil')..' engineers to consider')
                            break
                        elseif iCount > 110 then
                            --abort for performance reasons anyway
                            break
                        end
                    end
                    bThresholdInitialEngineerCondition = false
                    bThresholdPreReclaimEngineerCondition = false
              --TEMPTEST(aiBrain, sFunctionRef..': just after while loop start')
                    if bDebugMessages == true then LOG(sFunctionRef..': Start of loop to assign engineer action; iEngineersToConsider='..iEngineersToConsider..'; iCurrentConditionToTry='..iCurrentConditionToTry..'; iHighestFactoryOrEngineerTechAvailable='..iHighestFactoryOrEngineerTechAvailable..'; iAbsolutePowerBufferWanted='..iAbsolutePowerBufferWanted) end
                    tExistingLocationsToPickFrom = {}
                    iMaxEngisWanted = 1 --default; NOTE: This should be the cumulative value for that action (not that condition)
                    iActionToAssign = nil

                    oEngineerToAssign = nil
                    bGetInitialEngineer = false
                    iMinEngiTechLevelWanted = nil --Default - will consider later in the code



                    --Special logic if in ACU attack mode
                    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and aiBrain[M27Overseer.refbIncludeACUInAllOutAttack] then
                        --ACU in attack - want energy storage if we dont already have it so can overcharge
                        if iCurrentConditionToTry == 1 then
                            if iEnergyStoredRatio == nil then iEnergyStoredRatio = aiBrain:GetEconomyStoredRatio('ENERGY') end
                            if iEnergyStorageMax == nil then iEnergyStorageMax = iEnergyStored / iEnergyStoredRatio end
                            if iEnergyStorageMax < 9000 then
                                iActionToAssign = refActionBuildEnergyStorage
                                iMaxEngisWanted = 6
                            end

                        elseif iCurrentConditionToTry == 2 then
                            iActionToAssign = refActionBuildPower
                            iMaxEngisWanted = 10
                        elseif iCurrentConditionToTry == 3 then
                            if iHighestFactoryOrEngineerTechAvailable <= 1 then
                                iActionToAssign = refActionBuildSecondPower
                                iMaxEngisWanted = 5
                            end
                        else
                            iActionToAssign = refActionSpare
                            iSearchRangeForNearestEngi = 10000
                            iMaxEngisWanted = 1000
                        end
                    else

                        if iCurrentConditionToTry == 1 then --Start of game - hydro near start?
                            if bDebugMessages == true then LOG(sFunctionRef..': Condition 1 - checking if want to build hydro') end
                            if iGrossCurEnergyIncome == nil then  iGrossCurEnergyIncome = aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] end
                            if iGrossCurEnergyIncome < 11 then -->110 per second, so must have hydro and/or 5 T1 power

                                if bNearbyHydro == nil then bNearbyHydro, tNearbyHydro = M27Conditions.HydroNearACUAndBase(aiBrain, true, true) end --Ignores ACU and just checks if near start position
                                if bNearbyHydro == true then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Condition 1 - want to build hydro; iGrossCurEnergyIncome='..iGrossCurEnergyIncome) end
                                    iActionToAssign = refActionBuildHydro
                                    iSearchRangeForNearestEngi = 100
                                    if iUnclaimedHydroNearBase == nil then
                                        tUnclaimedHydroNearBase = FilterLocationsBasedOnIfUnclaimed(aiBrain, tNearbyHydro)
                                        if M27Utilities.IsTableEmpty(tUnclaimedHydroNearBase) == true then iUnclaimedHydroNearBase = 0
                                        else iUnclaimedHydroNearBase = table.getn(tUnclaimedHydroNearBase) end
                                    end
                                    if bDebugMessages == true then LOG(sFunctionRef..': Condition='..iCurrentConditionToTry..': iUnclaimedHydroNearBase='..iUnclaimedHydroNearBase) end
                                    tExistingLocationsToPickFrom = tUnclaimedHydroNearBase
                                end
                            elseif bDebugMessages == true then LOG(sFunctionRef..': We have enough energy so dont need hydro urgently')
                            end
                            iMaxEngisWanted = 3
                        elseif iCurrentConditionToTry == 2 then --Power stall early on where nearby reclaim might help
                            if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; aiBrain[M27EconomyOverseer.refbStallingEnergy]='..tostring(aiBrain[M27EconomyOverseer.refbStallingEnergy])..'; Energy storage='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; Net income='..aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome]) end
                            if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] < 150 and (aiBrain[M27EconomyOverseer.refbStallingEnergy] or (aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] < 0 and aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.3)) then
                                --Have really low energy so want to try and get energy reclaim - how much energy is nearby?
                                local iNearbyEnergy = M27MapInfo.GetReclaimInRectangle(5, Rect(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1]-50, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]-50, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1] + 50, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]+50), bDebugMessages)
                                if bDebugMessages == true then LOG(sFunctionRef..': iNearbyEnergy='..iNearbyEnergy) end
                                if iNearbyEnergy >= 100 then
                                    iActionToAssign = refActionReclaimTrees
                                    iMaxEngisWanted = math.max(2, math.min(aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] / 10, iNearbyEnergy / 90, 10))
                                    if bDebugMessages == true then LOG(sFunctionRef..': Want engineers to reclaim energy, iMaxEngisWanted='..iMaxEngisWanted) end
                                end

                            end
                        elseif iCurrentConditionToTry == 3 then  --want 2 engis claiming mexes for first 5m of game (and for initial 2 engis to keep building mexes)
                            --Have initial engineers only build mexes, separate to the normal process
                            if iAllUnclaimedMexesInPathingGroup == nil then
                                tAllUnclaimedMexesInPathingGroup = GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, false, false, false)

                                if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInPathingGroup) == false then iAllUnclaimedMexesInPathingGroup = table.getn(tAllUnclaimedMexesInPathingGroup)
                                    else iAllUnclaimedMexesInPathingGroup = 0 end
                                if bDebugMessages == true then LOG(sFunctionRef..': Condition '..iCurrentConditionToTry..': iAllUnclaimedMexesInPathingGroup='..iAllUnclaimedMexesInPathingGroup) end
                            end
                            if iAllUnclaimedMexesInPathingGroup > 0 then
                                --Initial build order - if no hydro and we dont have muc hpower, then dont assign engis to mexe as want them for power instead
                                if bNearbyHydro == nil then bNearbyHydro, tNearbyHydro = M27Conditions.HydroNearACUAndBase(aiBrain, true, true) end --Ignores ACU and just checks if near start position
                                if bDebugMessages == true then LOG(sFunctionRef..': Checking if should build power as initial priority instead of mex; aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; aiBrain:GetEconomyStoredRatio(Energy)='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; bNearbyHydro='..tostring(bNearbyHydro)) end
                                if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] <= 8 and not(bNearbyHydro) and aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.7 and aiBrain:GetEconomyStoredRatio('MASS') >= 0.1 then --have 3 or fewer t1 power
                                    iActionToAssign = refActionBuildPower
                                    iMaxEngisWanted = 1
                                else
                                    if iUnclaimedMexesOnOurSideOfMap == nil then
                                        tUnclaimedMexesOnOurSideOfMap = FilterLocationsBasedOnDistanceToEnemy(aiBrain, tAllUnclaimedMexesInPathingGroup, 0.5)
                                        if M27Utilities.IsTableEmpty(tUnclaimedMexesOnOurSideOfMap) == false then iUnclaimedMexesOnOurSideOfMap = table.getn(tUnclaimedMexesOnOurSideOfMap)
                                        else iUnclaimedMexesOnOurSideOfMap = 0 end
                                    end
                                    if bDebugMessages == true then LOG(sFunctionRef..': Condition '..iCurrentConditionToTry..': iUnclaimedMexesOnOurSideOfMap='..iUnclaimedMexesOnOurSideOfMap) end
                                    if iUnclaimedMexesOnOurSideOfMap > 0 then
                                        if bDebugMessages == true then LOG(sFunctionRef..': We have '..iUnclaimedMexesOnOurSideOfMap..' unclaimed mexes our side of the map') end
                                        if iGameTime <= 500 then
                                            iActionToAssign = refActionBuildMex
                                            iSearchRangeForNearestEngi = 10000
                                            iMaxEngisWanted = aiBrain[refiInitialMexBuildersWanted]
                                            if iUnclaimedMexesOnOurSideOfMap <= aiBrain[refiInitialMexBuildersWanted] then iMaxEngisWanted = aiBrain[refiInitialMexBuildersWanted] end
                                            tExistingLocationsToPickFrom = tUnclaimedMexesOnOurSideOfMap
                                        end
                                        --Still want this action for initial engineers - do we have any idle engineers that are the initial engineers?
                                        if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..': bStillHaveEarlyEngis='..tostring(bStillHaveEarlyEngis)..'; iIdleEarlyEngis='..iIdleEarlyEngis..'; aiBrain[refiInitialMexBuildersWanted]='..aiBrain[refiInitialMexBuildersWanted]) end
                                        if bStillHaveEarlyEngis == true and iIdleEarlyEngis > 0 then
                                            bGetInitialEngineer = true
                                            iActionToAssign = refActionBuildMex
                                            iSearchRangeForNearestEngi = 10000
                                            local iEngineersAlreadyBuildingMexes = 0
                                            for iEngi, oEngineer in aiBrain:GetListOfUnits(refCategoryEngineer, false, true) do
                                                if oEngineer[refiEngineerCurrentAction] == refActionBuildMex then iEngineersAlreadyBuildingMexes = iEngineersAlreadyBuildingMexes + 1 end
                                            end
                                            if bDebugMessages == true then LOG(sFunctionRef..': iEngineersAlreadyBuildingMexes='..iEngineersAlreadyBuildingMexes) end
                                            iMaxEngisWanted = math.max(iEngineersAlreadyBuildingMexes + iIdleEarlyEngis, iMaxEngisWanted)
                                            iIdleEarlyEngis = iIdleEarlyEngis - 1
                                            tExistingLocationsToPickFrom = tUnclaimedMexesOnOurSideOfMap
                                        end
                                        if bDebugMessages == true then LOG('iMaxEngisWanted after finishing checking condition for initial mexes='..iMaxEngisWanted) end
                                    end
                                end
                            end
                            if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] < 10 then iMaxEngisWanted = 1 end
                        elseif iCurrentConditionToTry == 4 then --Get reclaim if low on mass

                            if iMassStoredRatio == nil then iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS') end
                            if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..'; iMassStoredRatio='..iMassStoredRatio..'; M27MapInfo.iMapTotalMass='..(M27MapInfo.iMapTotalMass or 'nil')..'; aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1]='..(aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] or 'nil')) end
                            if iMassStoredRatio < 0.05 then
                                if aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] > 0 then
                                    --Have some reclaim somewhere on map, so have at least 1 engineer assigned to reclaim even if no high priority locations
                                    iActionToAssign = refActionReclaimArea
                                    --M27MapInfo.UpdateReclaimMarkers() --Does periodically if been a while since last update --Moved this to overseer so dont end up with engis waiting for this to compelte
                                    iMaxEngisWanted = math.min(2, math.max(1, math.ceil((aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] or 0)/3)))
                                    iSearchRangeForNearestEngi = 10000
                                end
                            end
                        elseif iCurrentConditionToTry == 5 then --Want 3 factories as a high priority (higher than power)
                            if iLandFactories == nil then
                                iLandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory)
                                if iLandFactories == nil then iLandFactories = 0 end
                            end
                            if iAirFactories == nil then
                                iAirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory)
                                if iAirFactories == nil then iAirFactories = 0 end
                            end
                            if iLandFactories+iAirFactories < 3 then
                                if aiBrain:GetEconomyStored('MASS') >= 100 and aiBrain:GetEconomyStored('ENERGY') >= 1000 then
                                    if iLandFactories < aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes] then
                                        iActionToAssign = refActionBuildLandFactory
                                        iMaxEngisWanted = 1
                                    elseif iAirFactories == 0 then
                                        iActionToAssign = refActionBuildAirFactory
                                        iMaxEngisWanted = 1
                                    else
                                        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] then
                                            iActionToAssign = refActionBuildLandFactory
                                            iMaxEngisWanted = 1
                                        else iActionToAssign = refActionBuildAirFactory
                                            iMaxEngisWanted = 1
                                        end
                                    end
                                end
                            end
                        elseif iCurrentConditionToTry == 6 then --If engi tech level >1 then want to build power if have none >= that tech level
                            if iHighestFactoryOrEngineerTechAvailable > 1 then
                                if iT3Power == nil then iT3Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH3) end
                                if iHighestFactoryOrEngineerTechAvailable > 2 then
                                    if iT3Power == 0 or (iT3Power < 2 and (GetGameTimeSeconds() - aiBrain[M27EconomyOverseer.refiLastEnergyStall] <= 60 or aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] <= 100)) then
                                        iSearchRangeForNearestEngi = 100
                                        iActionToAssign = refActionBuildPower
                                        if iT3Power == 0 then
                                            iMaxEngisWanted = 5
                                        else iMaxEngisWanted = 1 end
                                    end
                                else
                                    if iT2Power == nil then iT2Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH2) end
                                    if iT2Power + iT3Power == 0 or (iT3Power == 0 and iT2Power < 4 and (aiBrain[M27EconomyOverseer.refiLastEnergyStall] <= 60 or aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] <= 50)) then
                                        iSearchRangeForNearestEngi = 100
                                        iActionToAssign = refActionBuildPower
                                        if iT2Power <= 3 then
                                            iMaxEngisWanted = 5
                                        else iMaxEngisWanted = 1 end
                                    end
                                end
                                if bDebugMessages == true then
                                    if iT2Power == nil then iT2Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH2) end
                                    LOG('Condition:'..iCurrentConditionToTry..': iT3Power='..iT3Power..'; iT2Power='..iT2Power..'; iHighestFactoryOrEngineerTechAvailable='..iHighestFactoryOrEngineerTechAvailable)
                                    if iActionToAssign == nil then LOG('Not assigned an action') else LOG('iActionToAssign='..iActionToAssign) end
                                end
                            end
                        elseif iCurrentConditionToTry == 7 then --Non-early game want 1 engi getting unclaimed mexes as a higher priority
                            if iGameTime >= 360 then --6 mins
                                if iAllUnclaimedMexesInPathingGroup == nil then
                                    tAllUnclaimedMexesInPathingGroup = GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, false, false, false)
                                    if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInPathingGroup) == false then iAllUnclaimedMexesInPathingGroup = table.getn(tAllUnclaimedMexesInPathingGroup)
                                    else iAllUnclaimedMexesInPathingGroup = 0 end
                                end
                                if iAllUnclaimedMexesInPathingGroup > 0 then
                                    if iUnclaimedMexesWithinDefenceCoverage == nil then
                                        if iAllUnclaimedMexesInPathingGroup > 0 then
                                            tUnclaimedMexesWithinDefenceCoverage = FilterLocationsBasedOnDefenceCoverage(aiBrain, tAllUnclaimedMexesInPathingGroup, true)
                                            if M27Utilities.IsTableEmpty(tUnclaimedMexesWithinDefenceCoverage) == false then iUnclaimedMexesWithinDefenceCoverage = table.getn(tUnclaimedMexesWithinDefenceCoverage)
                                            else iUnclaimedMexesWithinDefenceCoverage = 0 end
                                        else iUnclaimedMexesWithinDefenceCoverage = 0 end
                                    end
                                    if iUnclaimedMexesWithinDefenceCoverage > 0 then
                                        iActionToAssign = refActionBuildMex
                                        iSearchRangeForNearestEngi = 10000
                                        iMaxEngisWanted = 1
                                        tExistingLocationsToPickFrom = tUnclaimedMexesWithinDefenceCoverage
                                    end
                                end
                            end
                        elseif iCurrentConditionToTry == 8 then --Low power action part 1
                            if iMassStoredRatio == nil then iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS') end
                            if bHaveLowPower or (iMassStoredRatio >= 0.05 and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] <= 40) then
                                --Build power unless early game hydro under construction in which case assist it instead
                                local bAssistHydroInstead = false
                                if iUnclaimedHydroNearBase > 0 and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildHydro]) == false then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Condition 4 (low power): iUnclaimedHydroNearBase='..iUnclaimedHydroNearBase..'; iGrossCurEnergyIncome='..iGrossCurEnergyIncome) end
                                    --Get first valid unit building hydro:
                                    local oUnitRecordedAsBuildingHydro, oEngi
                                    for iEngiUniqueRef, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildHydro] do
                                        oEngi = tSubtable[refEngineerAssignmentEngineerRef]
                                        if not(oEngi.Dead) and oEngi.GetPosition then
                                            oUnitRecordedAsBuildingHydro = oEngi
                                            break
                                        end
                                    end
                                    if oUnitRecordedAsBuildingHydro and not(oUnitRecordedAsBuildingHydro.Dead) and oUnitRecordedAsBuildingHydro.GetFocusUnit then
                                        local oHydro = oUnitRecordedAsBuildingHydro:GetFocusUnit()
                                        if EntityCategoryContains(refCategoryHydro, oHydro) then
                                            bAssistHydroInstead = true
                                        else
                                            if bDebugMessages == true then LOG(sFunctionRef..': low power1 condition: The unit being built isnt a hydro') end
                                        end
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': low power1 condition: Dont have a unit assigned to building hydro') end
                                    end
                                end
                                if bAssistHydroInstead == true then iActionToAssign = refActionBuildHydro
                                else
                                    if bNearbyHydro == nil then bNearbyHydro, tNearbyHydro = M27Conditions.HydroNearACUAndBase(aiBrain, true, true) end --Ignores ACU and just checks if near start position
                                    if bNearbyHydro and iUnclaimedHydroNearBase == nil then
                                        tUnclaimedHydroNearBase = FilterLocationsBasedOnIfUnclaimed(aiBrain, tNearbyHydro)
                                        if M27Utilities.IsTableEmpty(tUnclaimedHydroNearBase) == true then iUnclaimedHydroNearBase = 0
                                        else iUnclaimedHydroNearBase = table.getn(tUnclaimedHydroNearBase) end
                                    end
                                    if bNearbyHydro and iUnclaimedHydroNearBase > 0 then
                                        iActionToAssign = refActionBuildHydro
                                        tExistingLocationsToPickFrom = tUnclaimedHydroNearBase
                                    else
                                        iActionToAssign = refActionBuildPower
                                    end
                                end
                                iSearchRangeForNearestEngi = 75
                                iMaxEngisWanted = 3
                                if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] > 20 and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] < 40 then iMaxEngisWanted = 4 end
                            end
                        elseif iCurrentConditionToTry == 9 then --Initial land factories (high priority with low resource conditions)
                            if iLandFactories == nil then
                                iLandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory)
                                if iLandFactories == nil then iLandFactories = 0 end
                            end
                            if iAirFactories == nil then
                                iAirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory)
                                if iAirFactories == nil then iAirFactories = 0 end
                            end
                            if iMassStored == nil then iMassStored = aiBrain:GetEconomyStored('MASS') end
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering buildilng land facs, iMassStored='..iMassStored..'; iEnergyStored='..iEnergyStored..'; iLandFactories='..iLandFactories) end

                            if iMassStored > 100 and iEnergyStored > 250 and (iLandFactories < aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes] or iAirFactories < 1 or aiBrain[M27EconomyOverseer.refbWantMoreFactories] == true) then
                                iSearchRangeForNearestEngi = 75
                                iMaxEngisWanted = 2
                                if iLandFactories < aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes] then iActionToAssign = refActionBuildLandFactory
                                else
                                    if iAirFactories < 1 then iActionToAssign = refActionBuildAirFactory
                                    else
                                        if bHaveLowPower == false and bHaveLowMass == false then
                                            if iAirFactories < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir] then iActionToAssign = refActionBuildAirFactory
                                            else
                                                if not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance) then iActionToAssign = refActionBuildLandFactory end
                                            end
                                        end
                                    end
                                end
                            end
                        elseif iCurrentConditionToTry == 10 then --SMD
                            if bDebugMessages == true then LOG(sFunctionRef..': Checking if need to build SMD; iHighestFactoryOrEngineerTechAvailable='..iHighestFactoryOrEngineerTechAvailable..'; M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers])='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers]))) end
                            if iHighestFactoryOrEngineerTechAvailable >= 3 and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers]) == false then
                                --Do we have as many SMD as they have nuke launchers?
                                local iSMDsWeHave = 0
                                local iSMDsWithNoMissiles = 0
                                local tSMD = aiBrain:GetListOfUnits(M27UnitInfo.refCategorySMD, false, true)
                                if M27Utilities.IsTableEmpty(tSMD) == false then
                                    for iSMDNumber, oSMD in tSMD do
                                        --Check we've completed construction
                                        if bDebugMessages == true then LOG(sFunctionRef..': Have an SMD, will check if its completed construction') end
                                        if M27UnitInfo.IsUnitValid(oSMD, true) then
                                            iSMDsWeHave = iSMDsWeHave + 1
                                            --Check missile count
                                            if bDebugMessages == true then LOG(sFunctionRef..': SMD LC='..M27UnitInfo.GetUnitLifetimeCount(oSMD)..'; will check its nuke silo ammo count') end
                                            if oSMD.GetTacticalSiloAmmoCount and oSMD:GetTacticalSiloAmmoCount() < 1 then iSMDsWithNoMissiles = iSMDsWithNoMissiles + 1 end
                                            if bDebugMessages == true then
                                                if oSMD.GetNukeSiloAmmoCount then LOG('Silo ammo count='..oSMD:GetNukeSiloAmmoCount())
                                                else LOG('SiloAmmoCount doesnt exist') end
                                                if oSMD.GetTacticalSiloAmmoCount then LOG('GetTacticalSiloAmmoCount='..oSMD:GetTacticalSiloAmmoCount()) else LOG('GetTacticalSiloAmmoCount doesnt exist') end
                                            end
                                        end
                                    end
                                end
                                local iEnemyNukes = 0 --Cant use table.getn
                                for iNuke, oNuke in aiBrain[M27Overseer.reftEnemyNukeLaunchers] do
                                   iEnemyNukes = iEnemyNukes + 1
                                end
                                iEnemyNukes = math.min(iEnemyNukes, 1) --Redundancy - if table isnt empty enemy must have at least one
                                if bDebugMessages == true then LOG(sFunctionRef..': iSMDsWeHave='..iSMDsWeHave..'; iEnemyNukes='..iEnemyNukes..'; iSMDsWithNoMissiles='..iSMDsWithNoMissiles) end
                                if iSMDsWeHave < iEnemyNukes then
                                    aiBrain[refbNeedResourcesForMissile] = true
                                    iMinEngiTechLevelWanted = 3
                                    iActionToAssign = refActionBuildSMD
                                    iMaxEngisWanted = 20
                                    if bHaveLowPower == false and bHaveLowMass == false then iMaxEngisWanted = 30 end

                                elseif iSMDsWithNoMissiles > 0 then
                                    --We have enough SMDs, so want to assist SMD unless all SMDs have an anti-nuke loaded already
                                    aiBrain[refbNeedResourcesForMissile] = true
                                    iActionToAssign = refActionAssistSMD
                                    iMaxEngisWanted = 20
                                    if bHaveLowPower == false and bHaveLowMass == false then iMaxEngisWanted = 40 end
                                else
                                    aiBrain[refbNeedResourcesForMissile] = false
                                    --Have SMDs but they all have anti-nuke loaded; check if we have any engineers already assigned to this action and if so clear them
                                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if any engineers have been assigned to assist SMD, if so will clear their actions') end
                                    if aiBrain[reftEngineerAssignmentsByActionRef] and aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistSMD] and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistSMD]) == false then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Engineers have been assigned to assist an SMD, will cycle through them') end
                                        --Cant use table.getn for this table so do manually:
                                        for iUniqueRef, tSubtable in  aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistSMD] do
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef..': refEngineerAssignmentEngineerRef='..repr(aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistSMD][iUniqueRef][refEngineerAssignmentLocationRef]))
                                                LOG(sFunctionRef..': oEngineer UC='..GetEngineerUniqueCount(aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistSMD][iUniqueRef][refEngineerAssignmentEngineerRef])..'; About to check if valid unit')
                                            end
                                            if M27UnitInfo.IsUnitValid(tSubtable[refEngineerAssignmentEngineerRef]) then
                                                --if GetEngineerUniqueCount(tSubtable[refEngineerAssignmentEngineerRef]) == 59 then bDebugMessages = true end
                                                if bDebugMessages == true then LOG(sFunctionRef..': Engineer is assigned the action so will clear it') end
                                                IssueClearCommands({tSubtable[refEngineerAssignmentEngineerRef]})
                                                ClearEngineerActionTrackers(aiBrain, tSubtable[refEngineerAssignmentEngineerRef], false)
                                            end
                                        end
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': No engineers appear to have been assigned to assist an SMD') end
                                    end
                                end
                            end

                        elseif iCurrentConditionToTry == 11 then --Unclaimed mexes within defender coverage
                            bThresholdInitialEngineerCondition = true
                            if iAllUnclaimedMexesInPathingGroup == nil then
                                tAllUnclaimedMexesInPathingGroup = GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, false, false, false)
                                if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInPathingGroup) == false then iAllUnclaimedMexesInPathingGroup = table.getn(tAllUnclaimedMexesInPathingGroup)
                                else iAllUnclaimedMexesInPathingGroup = 0 end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': Looking if unclaimed mexes within defence coverage, iAllUnclaimedMexesInPathingGroup='..iAllUnclaimedMexesInPathingGroup) end
                            if iAllUnclaimedMexesInPathingGroup > 0 then
                                if iUnclaimedMexesWithinDefenceCoverage == nil then
                                    tUnclaimedMexesWithinDefenceCoverage = FilterLocationsBasedOnDefenceCoverage(aiBrain, tAllUnclaimedMexesInPathingGroup, true)
                                    if M27Utilities.IsTableEmpty(tUnclaimedMexesWithinDefenceCoverage) == false then iUnclaimedMexesWithinDefenceCoverage = table.getn(tUnclaimedMexesWithinDefenceCoverage)
                                    else iUnclaimedMexesWithinDefenceCoverage = 0 end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': Have unclaimed mexes in pathing group, iUnclaimedMexesWithinDefenceCoverage='..iUnclaimedMexesWithinDefenceCoverage) end
                                if iUnclaimedMexesWithinDefenceCoverage > 2 then
                                    iActionToAssign = refActionBuildMex
                                    iMaxEngisWanted = math.ceil(iUnclaimedMexesWithinDefenceCoverage / 1.35) + 1
                                    tExistingLocationsToPickFrom = tUnclaimedMexesWithinDefenceCoverage
                                    iSearchRangeForNearestEngi = 10000
                                elseif not(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand]) then
                                    --Do we have mexes that are land pathable from our base?
                                    if iAllUnclaimedMexesInLandPathingGroup == nil then
                                        --Include enemy mexes in this list since if theyre on our land pathable mass it could just be a lucky engi got through
                                        tAllUnclaimedMexesInLandPathingGroup = GetUnclaimedMexes(aiBrain, M27UnitInfo.refPathingTypeLand, M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]), true, false, false)
                                        if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInLandPathingGroup) then iAllUnclaimedMexesInLandPathingGroup = 0
                                        else iAllUnclaimedMexesInLandPathingGroup = table.getn(tAllUnclaimedMexesInLandPathingGroup)
                                        end
                                    end
                                    if bDebugMessages == true then LOG(sFunctionRef..': iAllUnclaimedMexesInLandPathingGroup='..iAllUnclaimedMexesInLandPathingGroup) end
                                    if iAllUnclaimedMexesInLandPathingGroup > 0 then
                                        iActionToAssign = refActionBuildMex
                                        iMaxEngisWanted = math.min(2, math.max(1, math.ceil(iAllUnclaimedMexesInPathingGroup / 3)))
                                        tExistingLocationsToPickFrom = tAllUnclaimedMexesInLandPathingGroup
                                        iSearchRangeForNearestEngi = 10000
                                    end
                                end
                            end

                        elseif iCurrentConditionToTry == 12 then --Hydro within our defence coverage?'
                            if iUnclaimedHydroWithinDefenceCoverage == nil then
                                if tAllUnclaimedHydroInPathingGroup == nil then tAllUnclaimedHydroInPathingGroup = GetUnclaimedHydros(aiBrain, sPathing, iPathingGroup, false, false, false)  end
                                if M27Utilities.IsTableEmpty(tAllUnclaimedHydroInPathingGroup) == false then
                                    tUnclaimedHydroWithinDefenceCoverage = FilterLocationsBasedOnDefenceCoverage(aiBrain, tAllUnclaimedHydroInPathingGroup, true)
                                    if M27Utilities.IsTableEmpty(tUnclaimedHydroWithinDefenceCoverage) == true then iUnclaimedHydroWithinDefenceCoverage = 0
                                    else iUnclaimedHydroWithinDefenceCoverage = table.getn(tUnclaimedHydroWithinDefenceCoverage) end
                                else iUnclaimedHydroWithinDefenceCoverage = 0
                                end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': iUnclaimedHydroWithinDefenceCoverage='..iUnclaimedHydroWithinDefenceCoverage) end
                            if iUnclaimedHydroWithinDefenceCoverage > 0 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Want to build hydro as is at least 1 within defense coverage; iUnclaimedHydroWithinDefenceCoverage='..iUnclaimedHydroWithinDefenceCoverage) end
                                iActionToAssign = refActionBuildHydro
                                tExistingLocationsToPickFrom = tUnclaimedHydroNearBase
                                iSearchRangeForNearestEngi = 10000
                                iMaxEngisWanted = 2
                                --Increase max number of engis if hydro is close to us
                                local iNearestHydroDistance = 10000
                                local iCurHydroDistance
                                for iHydro, tHydro in tUnclaimedHydroWithinDefenceCoverage do
                                    iCurHydroDistance = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tHydro)
                                    if iCurHydroDistance < iNearestHydroDistance then iNearestHydroDistance = iCurHydroDistance end
                                end
                                if iNearestHydroDistance <= 90 then iMaxEngisWanted = 4 end
                                tExistingLocationsToPickFrom = tUnclaimedHydroWithinDefenceCoverage
                            end
                        elseif iCurrentConditionToTry == 13 then --Lower power action part 2 - want enough power to support guncom
                            if bDebugMessages == true then LOG(sFunctionRef..': 2nd low power action; bHaveLowPower='..tostring(bHaveLowPower)..'; bWantMorePower='..tostring(bWantMorePower)..'; bHaveLowMass='..tostring(bHaveLowMass)) end
                            if bHaveLowPower or (bWantMorePower and bHaveLowMass == false) then
                                --Hydro or power
                                if bNearbyHydro == nil then bNearbyHydro, tNearbyHydro = M27Conditions.HydroNearACUAndBase(aiBrain, true, true) end --Ignores ACU and just checks if near start position
                                if iUnclaimedHydroNearBase == nil then
                                    if bNearbyHydro == false then
                                        iUnclaimedHydroNearBase = 0
                                    else
                                        tUnclaimedHydroNearBase = FilterLocationsBasedOnIfUnclaimed(aiBrain, tNearbyHydro)
                                        if M27Utilities.IsTableEmpty(tUnclaimedHydroNearBase) == true then iUnclaimedHydroNearBase = 0
                                        else iUnclaimedHydroNearBase = table.getn(tUnclaimedHydroNearBase) end
                                    end
                                end
                                iSearchRangeForNearestEngi = 75
                                if iUnclaimedHydroNearBase > 0 then
                                    iActionToAssign = refActionBuildHydro
                                    tExistingLocationsToPickFrom = tUnclaimedHydroNearBase
                                    iMaxEngisWanted = 5
                                else
                                    iActionToAssign = refActionBuildPower
                                    iMaxEngisWanted = math.min(math.ceil(iAllEngineers * 0.4), 5)
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': 2nd low power action: Want to build power; iAllEngineers='..iAllEngineers..'; iMaxEngisWanted='..iMaxEngisWanted) end
                            end
                        elseif iCurrentConditionToTry == 14 then --Mass storage around T2/T3 mexes
                            if bHaveLowPower == false and M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftMassStorageLocations]) == false and iNetCurEnergyIncome > 8 then
                                iActionToAssign = refActionBuildMassStorage
                                iMaxEngisWanted = 5
                                --Pick the best 3 locations as the target for storage, provided they're reasonably comparable in preference
                                local tClosestSubtableRef = {}
                                local iLastModDistance = 100000
                                local iCurModDistance
                                local iClosestCount = 0
                                local iMaxModDistanceIncrease = 30
                                local bInclude
                                for iSubtable, tSubtable in M27Utilities.SortTableBySubtable(aiBrain[M27EconomyOverseer.reftMassStorageLocations], M27EconomyOverseer.refiStorageSubtableModDistance, true) do
                                    iCurModDistance = tSubtable[M27EconomyOverseer.refiStorageSubtableModDistance]
                                    if iCurModDistance - iLastModDistance <= iMaxModDistanceIncrease then
                                        iClosestCount = iClosestCount + 1
                                        tClosestSubtableRef[iClosestCount] = iSubtable
                                        iLastModDistance = iCurModDistance
                                        if iClosestCount >= 3 then break end
                                    end
                                end

                                --[[for iSubtable, tSubtable in aiBrain[M27EconomyOverseer.reftMassStorageLocations] do
                                    if tSubtable[M27EconomyOverseer.refiStorageSubtableModDistance] < iClosestModDistance then
                                        iClosestModDistance = tSubtable[M27EconomyOverseer.refiStorageSubtableModDistance]
                                        iClosestSubtableRef = iSubtable
                                    end
                                end--]]
                                tExistingLocationsToPickFrom = {}
                                for iEntry, vEntry in tClosestSubtableRef do
                                    tExistingLocationsToPickFrom[iEntry] = {}
                                    tExistingLocationsToPickFrom[iEntry][1] = aiBrain[M27EconomyOverseer.reftMassStorageLocations][vEntry][M27EconomyOverseer.reftStorageSubtableLocation][1]
                                    tExistingLocationsToPickFrom[iEntry][2] = aiBrain[M27EconomyOverseer.reftMassStorageLocations][vEntry][M27EconomyOverseer.reftStorageSubtableLocation][2]
                                    tExistingLocationsToPickFrom[iEntry][3] = aiBrain[M27EconomyOverseer.reftMassStorageLocations][vEntry][M27EconomyOverseer.reftStorageSubtableLocation][3]
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef..': tExistingLocationsToPickFrom='..repr(tExistingLocationsToPickFrom))
                                    M27Utilities.DrawLocation(tExistingLocationsToPickFrom[1], nil, 1, 100)
                                end
                            end
                        elseif iCurrentConditionToTry == 15 then --T3 mexes in place of existing T2 mexes
                            if iHighestFactoryOrEngineerTechAvailable >= 3 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Considering if shoudl assign action to ctrlK mex. Is tMexesToCtrlK empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftMexesToCtrlK]))..'; Existing engi assignments='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildT3MexOverT2]))) end
                                if iT3Power == nil then iT3Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH3) end
                                if bDebugMessages == true then LOG(sFunctionRef..': iT3Power='..iT3Power..': T3 Engis='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * categories.TECH3)..'; T3 mex='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex)) end
                                if iT3Power > 0 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * categories.TECH3) >= 1 then -- and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex) >= 1 then
                                    --Do we have T1 mexes near base that are upgrading or available to upgrade? If so, then only want to get a T3 mex if we have high mass
                                    local iT1MexesNearBase = 0
                                    local tAllT1Mexes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT1Mex, false, true)
                                    local bProceedWithT3 = true
                                    if M27Utilities.IsTableEmpty(tAllT1Mexes) == false then
                                        for iT1Mex, oT1Mex in tAllT1Mexes do
                                            if M27UnitInfo.IsUnitValid(oT1Mex) and M27Utilities.GetDistanceBetweenPositions(oT1Mex:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 90 and M27Conditions.SafeToUpgradeUnit(oT1Mex) then
                                                iT1MexesNearBase = iT1MexesNearBase + 1
                                            end
                                        end
                                    end
                                    if iT1MexesNearBase > 0 then
                                        if M27Conditions.HaveLowMass(aiBrain) then bProceedWithT3 = false
                                        elseif aiBrain:GetEconomyStoredRatio('MASS') < 0.1 or aiBrain:GetEconomyStored('MASS') < 1000 then
                                            bProceedWithT3 = false
                                        end
                                    end

                                    if bProceedWithT3 then
                                        local bRefreshMexes = M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildT3MexOverT2])
                                        if bRefreshMexes and M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftMexesToCtrlK]) == false then
                                            bRefreshMexes = false
                                            --Check all mexes are valid as we dont have an existing order to assist
                                            for iMex, oMex in aiBrain[M27EconomyOverseer.reftMexesToCtrlK] do
                                                if M27UnitInfo.IsUnitValid(oMex) == false then
                                                    bRefreshMexes = true
                                                    break
                                                end
                                            end
                                        end


                                        if bRefreshMexes then
                                            --Do we have any suitable mexes to add to this list? Check if we meet the conditions for shortlisting a mex
                                                --Do we have any T2 mexes near our base who arent upgrading? (Below will also update the variable for the nearest one of these, based on mexes which arent upgrading)
                                            if bDebugMessages == true then LOG(sFunctionRef..': T2 mexes near base pre refresh='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftT2MexesNearBase]))..'; Nearest T2mex is valid='..tostring((M27UnitInfo.IsUnitValid(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]) or false))) end
                                            --if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftT2MexesNearBase]) == true or not(M27UnitInfo.IsUnitValid(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase])) then
                                                --if bDebugMessages == true then LOG(sFunctionRef..': Will refresh T2 mexes near base') end
                                                M27EconomyOverseer.RefreshT2MexesNearBase(aiBrain)
                                            --end
                                            if bDebugMessages == true then LOG(sFunctionRef..': Is T2 mexes near base post any refresh empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftT2MexesNearBase]))..'; Nearest T2mex is valid='..tostring((M27UnitInfo.IsUnitValid(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]) or false))) end

                                            if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftT2MexesNearBase]) == false and M27UnitInfo.IsUnitValid(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]) then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Have a valid t2 mex near our base, Safe To upgrade='..tostring(M27Conditions.SafeToUpgradeUnit(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]))) end
                                                --Is the nearest mex to our base within defence coverage, with no nearby threats?
                                                if M27Conditions.SafeToUpgradeUnit(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]) then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': will add the mex '..aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase])..' to the list of mexes to ctrlk') end
                                                    table.insert(aiBrain[M27EconomyOverseer.reftMexesToCtrlK], aiBrain[M27EconomyOverseer.refoNearestT2MexToBase])
                                                end
                                            end
                                        elseif bDebugMessages == true then LOG(sFunctionRef..': Not refreshing list of mexes')
                                        end
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef..': After potential refresh, reftT2MexesNearBase size='..table.getn(aiBrain[M27EconomyOverseer.reftT2MexesNearBase])..'; MexesToCtrlK size='..table.getn(aiBrain[M27EconomyOverseer.reftMexesToCtrlK]))
                                            if M27UnitInfo.IsUnitValid(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]) then LOG('Mex nearest base position='..repr(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]:GetPosition()))
                                            else LOG(' refoNearestT2MexToBase is no longer valid')
                                            end
                                        end

                                        if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftMexesToCtrlK]) == false or M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildT3MexOverT2]) == false then
                                            iActionToAssign = refActionBuildT3MexOverT2
                                            iMaxEngisWanted = 10
                                            tExistingLocationsToPickFrom = {}
                                            iSearchRangeForNearestEngi = 125
                                            if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildT3MexOverT2]) == false then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Already have an engineer assigned to build t3 mex so will just assist that engi') end
                                                tExistingLocationsToPickFrom = nil
                                            else
                                                    --Dont already have this assigned so get a new location
                                                for iMex, oMex in aiBrain[M27EconomyOverseer.reftMexesToCtrlK] do
                                                    if oMex.GetPosition then table.insert(tExistingLocationsToPickFrom, oMex:GetPosition()) end
                                                end
                                                if bDebugMessages == true then LOG(sFunctionRef..': Dont have engi assigned to build T3 yet, so will pick location from mexes to ctrlK table; size of table='..table.getn(aiBrain[M27EconomyOverseer.reftMexesToCtrlK])..'; size of ctrlk table='..table.getn(aiBrain[M27EconomyOverseer.reftMexesToCtrlK])..'; tExistingLocationsToPickFrom='..repr(tExistingLocationsToPickFrom)) end
                                                if M27Utilities.IsTableEmpty(tExistingLocationsToPickFrom) == true then M27Utilities.ErrorHandler('Couldnt find any mex locations for ctrlk') end
                                            end
                                        elseif bDebugMessages == true then LOG(sFunctionRef..': Dont have existing order to build T3 mex over T2, and no mexes that we think we should')
                                        end
                                    elseif bDebugMessages == true then LOG(sFunctionRef..': Have t1 mexes to upgrade near our base and have decent amount of mass')
                                    end
                                end
                            end
                        elseif iCurrentConditionToTry == 16 then --Build factories (or upgrade HQ) if getting too much mass
                            if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..'; bHaveVeryLowPower='..tostring(bHaveVeryLowPower)) end
                            if bHaveVeryLowPower == false and bHaveLowMass == false then
                                if iLandFactories == nil then
                                    iLandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory)
                                    if iLandFactories == nil then iLandFactories = 0 end
                                end

                                if iMassStored == nil then iMassStored = aiBrain:GetEconomyStored('MASS') end
                                if iEnergyStored == nil then iEnergyStored = aiBrain:GetEconomyStored('ENERGY') end
                                if bDebugMessages == true then LOG(sFunctionRef..': Considering buildilng land or air facs, iMassStored='..iMassStored..'; iEnergyStored='..iEnergyStored..'; iLandFactories='..iLandFactories) end
                                if iMassStored > 100 and iEnergyStored > 250 then
                                    if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]) == false then
                                        --Double check al lthe units are still valid (as may be a slight delay)
                                        local bStillValid = false
                                        for iHQ, oHQ in aiBrain[M27EconomyOverseer.reftActiveHQUpgrades] do
                                            if M27UnitInfo.IsUnitValid(oHQ) then
                                                bStillValid = true
                                                break
                                            end
                                        end
                                        if not(bStillValid) then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Clearing all of the active HQ upgrades') end
                                            aiBrain[M27EconomyOverseer.reftActiveHQUpgrades] = {}
                                        else
                                            iActionToAssign = refActionUpgradeHQ
                                        end
                                    end
                                    if not(iActionToAssign) then
                                        --Not trying to upgrade a factory to HQ; do we have the min number of land factories wanted before we get an air fac?
                                        if iLandFactories < aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes] then
                                            iActionToAssign = refActionBuildLandFactory
                                        else
                                            --Have min. number of land facs wanted, so now consider if we want more air facs
                                            if iAirFactories == nil then
                                                iAirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory)
                                                if iAirFactories == nil then iAirFactories = 0 end
                                            end
                                            if bDebugMessages == true then LOG(sFunctionRef..': iAirFactories='..iAirFactories..'; iEnergyStored='..iEnergyStored..'; iNetCurEnergyIncome='..iNetCurEnergyIncome) end
                                            if iAirFactories == 0 then
                                                iActionToAssign = refActionBuildAirFactory
                                            else
                                                --Already have 1 air fac, only get more if we both have power, and we have fewer than the ratio of max factories wanted
                                                if not(bHaveLowPower) then
                                                    local bTooFewAirFacs = false
                                                    if aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir] > iAirFactories then
                                                        if not(aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons]) then bTooFewAirFacs = true
                                                        else
                                                            --Are making use of land units, check ratio of land fac vs air fac
                                                            if iLandFactories / math.max(1,aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand]) >= iAirFactories / math.max(1, aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir]) then
                                                                bTooFewAirFacs = true
                                                            end
                                                        end
                                                    end
                                                    if bTooFewAirFacs then iActionToAssign = refActionBuildAirFactory end
                                                end
                                            end
                                        end
                                        if not(iActionToAssign) then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Not building air factory; consider if we want to build more land factories; aiBrain[M27EconomyOverseer.refbWantMoreFactories]='..tostring(aiBrain[M27EconomyOverseer.refbWantMoreFactories])) end
                                            if not(iActionToAssign) then
                                                --Dont want to build any more air facs, or upgrade a HQ, and have the min. level of land facs; build another tank if we are making use of tanks and dont ahve the max number
                                                if not(aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons]) and iLandFactories < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] then
                                                    iActionToAssign = refActionBuildLandFactory
                                                end
                                            end
                                        end
                                    end
                                    if not(iActionToAssign) then
                                        --Dont want to build any factories, so upgrade a mex if we are upgrading any
                                        if aiBrain[M27EconomyOverseer.refiMexesUpgrading] > 0 then
                                            iActionToAssign = refActionUpgradeBuilding
                                        end
                                    end
                                end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': Action after checking if want to build a factory, upgrade HQ, or upgrade a mex='..(iActionToAssign or 'nil')) end
                            if iActionToAssign then
                                iSearchRangeForNearestEngi = 75
                                iMaxEngisWanted = math.min(math.floor(iMassStored / 100), math.floor(iEnergyStored / 250), 5)
                                --Increase engineers if we are about to overflow
                                if bHaveLowPower == false and bHaveLowMass == false then
                                    if iMassStoredRatio == nil then iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS') end
                                    if iMassStored == nil then iMassStored = aiBrain:GetEconomyStored('MASS') end
                                    if iNetCurEnergyIncome > 0.2 and (iMassStoredRatio > 0.6 or (iMassStoredRatio > 0.4 and iMassStored > 3500)) then --Have too much mass stored so try to build something
                                        iMaxEngisWanted = iMaxEngisWanted + 5
                                    end
                                end

                            end
                        elseif iCurrentConditionToTry == 17 then --Air staging if we need one for low fuel air units
                            if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..': bHaveLowPower='..tostring(bHaveLowPower)..'; aiBrain[M27AirOverseer.refiAirStagingWanted]='..(aiBrain[M27AirOverseer.refiAirStagingWanted] or 'nil')) end
                            if bHaveLowPower == false and aiBrain[M27AirOverseer.refiAirStagingWanted] and aiBrain[M27AirOverseer.refiAirStagingWanted] > 0 then
                                local iCurAirStaging = aiBrain:GetCurrentUnits(refCategoryAirStaging)
                                if bDebugMessages == true then LOG(sFunctionRef..': iCurAirStaging='..iCurAirStaging) end
                                if iCurAirStaging < 5 then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Dont have enough air staging so will build more') end
                                    iActionToAssign = refActionBuildAirStaging
                                    iSearchRangeForNearestEngi = 100
                                    if iCurAirStaging < 3 then iMaxEngisWanted = 2
                                    else iMaxEngisWanted = 1
                                    end
                                end
                            end
                            --end
                        elseif iCurrentConditionToTry == 18 then --Energy storage once have certain level of power
                            if bHaveLowPower == false then
                                if iGrossCurEnergyIncome >= 28 then
                                    if iEnergyStoredRatio == nil then iEnergyStoredRatio = aiBrain:GetEconomyStoredRatio('ENERGY') end
                                    if iEnergyStorageMax == nil then iEnergyStorageMax = iEnergyStored / iEnergyStoredRatio end
                                    local iMaxStorageWanted = 9000
                                    if iGrossCurEnergyIncome >= 90 then
                                        if iGrossCurEnergyIncome >= 200 then
                                            iMaxStorageWanted = math.max(17000, aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] * 200) --Energy storage to replenish overcharge every 20s
                                        else
                                            iMaxStorageWanted = 13000
                                        end
                                    end
                                    iMaxStorageWanted = math.min(65000, iMaxStorageWanted) --need 60k energy to deal max of 15k, but only a % of current energy (90%?) is used; when sandboxing, dealt max 15k damage at 68.5k storage, and c.800 below max at 63.5k storage

                                    if iEnergyStorageMax < iMaxStorageWanted then
                                        iActionToAssign = refActionBuildEnergyStorage
                                        if iEnergyStorageMax < 9000 then
                                            iSearchRangeForNearestEngi = 100
                                            iMaxEngisWanted = 3
                                        else
                                            iSearchRangeForNearestEngi = 75
                                            iMaxEngisWanted = 2
                                        end
                                    end
                                end
                            end
                        elseif iCurrentConditionToTry == 19 then --Get reclaim
                            bThresholdPreReclaimEngineerCondition = true

                            if iMassStoredRatio == nil then iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS') end
                            if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..'; iMassStoredRatio='..iMassStoredRatio..'; M27MapInfo.iMapTotalMass='..(M27MapInfo.iMapTotalMass or 'nil')..'; aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1]='..(aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] or 'nil')) end
                            if iMassStoredRatio < 0.98 then
                                if aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] > 0 then
                                    --Have some reclaim somewhere on map, so have at least 1 engineer assigned to reclaim even if no high priority locations
                                    iActionToAssign = refActionReclaimArea
                                    --M27MapInfo.UpdateReclaimMarkers() --Does periodically if been a while since last update --Moved this to overseer so dont end up with engis waiting for this to compelte
                                    iMaxEngisWanted = math.max(1, math.ceil((aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] or 0)/3))
                                    if iMaxEngisWanted > 5 then iMaxEngisWanted = 5 end
                                    iSearchRangeForNearestEngi = 10000
                                end
                            end
                        elseif iCurrentConditionToTry == 20 then
                            if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftUnitsToReclaim]) == false then
                                iActionToAssign = refActionReclaimUnit
                                iMaxEngisWanted = math.min(4, table.getn(aiBrain[M27EconomyOverseer.reftUnitsToReclaim]))
                                iSearchRangeForNearestEngi = 200
                            end
                        elseif iCurrentConditionToTry == 21 then --Try to get nearest unclaimed mex (i.e. this will only run if are no mexes within defensive area or our side of map):
                            if iAllUnclaimedMexesInPathingGroup == nil then
                                tAllUnclaimedMexesInPathingGroup = GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, false, false, false)
                                if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInPathingGroup) == false then iAllUnclaimedMexesInPathingGroup = table.getn(tAllUnclaimedMexesInPathingGroup)
                                else iAllUnclaimedMexesInPathingGroup = 0 end
                            end
                            if iAllUnclaimedMexesInPathingGroup > 0 then
                                iActionToAssign = refActionBuildMex
                                iSearchRangeForNearestEngi = 10000
                                iMaxEngisWanted = math.ceil(iAllUnclaimedMexesInPathingGroup / 2)

                                if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] and iMaxEngisWanted > 3 then iMaxEngisWanted = 3 end
                                tExistingLocationsToPickFrom = tAllUnclaimedMexesInPathingGroup
                            end
                        elseif iCurrentConditionToTry == 22 then --2nd T1 power construction with low priority engineers
                            if bHaveVeryLowPower == false and bHaveLowMass == false then --If almost power stalling then want to focus on the first T1 power rather than trying multiple at once
                                if bDebugMessages == true then LOG(sFunctionRef..': Separate power action; bWantMorePower='..tostring(bWantMorePower)) end
                                if iT3Power == nil then iT3Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH3) end
                                if iT2Power == nil then iT2Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH2) end
                                if bWantMorePower == true then
                                    if iHighestFactoryOrEngineerTechAvailable == 1 or (iHighestFactoryOrEngineerTechAvailable == 2 and iT2Power >= 2) then
                                        iActionToAssign = refActionBuildSecondPower
                                        iSearchRangeForNearestEngi = 100
                                        iMaxEngisWanted = 4
                                    else
                                        iActionToAssign = refActionBuildPower
                                        iSearchRangeForNearestEngi = 100
                                        iMaxEngisWanted = 8
                                    end
                                end
                            end
                        elseif iCurrentConditionToTry == 23 then --Radar near base
                            if bHaveLowPower == false then
                                if iCurRadarCount == nil then iCurRadarCount = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryRadar) end
                                if iCurRadarCount == 0 and iNetCurEnergyIncome > 5 and iEnergyStored >= 2000 then
                                    iActionToAssign = refActionBuildT1Radar
                                    iMaxEngisWanted = 1
                                elseif bHaveLowMass == false then

                                    --Already have a radar, check if we or an ally has T3
                                    if iNearbyOmniCount == nil then
                                        local tNearbyOmni = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT3Radar, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 250, 'Ally')
                                        if M27Utilities.IsTableEmpty(tNearbyOmni) == false then iNearbyOmniCount = table.getn(tNearbyOmni)
                                        else iNearbyOmniCount = 0 end
                                    end
                                    if iNearbyOmniCount == 0 then
                                        local iOmniWanted = 0
                                        --GetResourcesNearTargetLocation(tTargetPos, iMaxDistance, bMexNotHydro)
                                        if iT3Power == nil then iT3Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH3) end
                                        --Only get omni if we have several T3 power, and we have no nearby enemies (within 175, as T2 radar is 200 range; also not much point if enemy start is within 250 of us)
                                        if iHighestFactoryOrEngineerTechAvailable >= 3 and iNetCurEnergyIncome >= 300 and iT3Power > 1 and aiBrain[M27Overseer.refiModDistFromStartNearestThreat] >= 175 and aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] >= 250 then
                                            --Also want at least 2 T3 mexes (or 4 if we're in eco mode), assuming we have that many near our start position
                                            local iT3MexesWantedFirst = M27MapInfo.GetResourcesNearTargetLocation(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 40, true)
                                            if M27Utilities.IsTableEmpty(iT3MexesWantedFirst) == true then iT3MexesWantedFirst = 1 else iT3MexesWantedFirst = table.getn(iT3MexesWantedFirst) end

                                            if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then iT3MexesWantedFirst = math.min(4, iT3MexesWantedFirst)
                                            else iT3MexesWantedFirst = math.min(2, iT3MexesWantedFirst) end
                                            if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex) >= iT3MexesWantedFirst then
                                                iOmniWanted = 1
                                            end
                                        end
                                        if iOmniWanted > 0 then
                                            iActionToAssign = refActionBuildT3Radar
                                            iMinEngiTechLevelWanted = 3
                                            iMaxEngisWanted = 3
                                        else
                                            if iT2Power == nil then iT2Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH2) end
                                            if iT2Power + iT3Power > 0 then
                                                --Do we already have T2 radar
                                                if iCurT2RadarCount == nil then iCurT2RadarCount = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Radar) end
                                                if iCurT2RadarCount == 0 and iNetCurEnergyIncome >= 40 then
                                                    iActionToAssign = refActionBuildT2Radar
                                                    iMinEngiTechLevelWanted = 2
                                                    iMaxEngisWanted = 3
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        elseif iCurrentConditionToTry == 24 then --reclaim on enemy side of map
                            if iMassStoredRatio <= 0.25 and aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] + aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][2] + aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][3] > 0 then
                                iActionToAssign = refActionReclaimArea
                                iMaxEngisWanted = math.max(1, math.min(math.ceil(aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] * 0.5 + aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][2] * 0.3 + aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][3] * 0.1)))
                                iSearchRangeForNearestEngi = 10000
                            end
                        elseif iCurrentConditionToTry == 25 then --Assist air
                            if bHaveLowPower == false then
                                if iAirFactories == nil then
                                    iAirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory)
                                    if iAirFactories == nil then iAirFactories = 0 end
                                end

                                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance or (iAirFactories >= 1 and iAirFactories < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir]) then
                                    iActionToAssign = refActionAssistAirFactory
                                    if bHaveLowMass == false then iMaxEngisWanted = 10
                                    else iMaxEngisWanted = 5 end
                                    iSearchRangeForNearestEngi = 75
                                end
                            end
                        elseif iCurrentConditionToTry == 26 then --Sonar
                            if bDebugMessages == true then LOG(sFunctionRef..': Checking if we want sonar, aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand]='..tostring(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand])..'; aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]='..tostring(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious])..'; M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryTorpBomber, 1)='..tostring(M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryTorpBomber, 1))) end
                            if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == false and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] and not(M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryTorpBomber, 1)) then
                                --Can get to enemy via amphib not land so must be a water map, so want sonar to detect subs if we dont already have it
                                if bDebugMessages == true then LOG(sFunctionRef..': aiBrain:GetCurrentUnits(M27UnitInfo.refCategorySonar)='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategorySonar)) end
                                if aiBrain:GetCurrentUnits(M27UnitInfo.refCategorySonar) == 0 then
                                    iActionToAssign = refActionBuildT1Sonar
                                    iMinEngiTechLevelWanted = 1
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[M27Overseer.refiOurHighestAirFactoryTech]='..aiBrain[M27Overseer.refiOurHighestAirFactoryTech]..'; aiBrain[M27AirOverseer.refiAirAANeeded]='..aiBrain[M27AirOverseer.refiAirAANeeded]..'; aiBrain[M27AirOverseer.refiTorpBombersWanted]='..aiBrain[M27AirOverseer.refiTorpBombersWanted]..'; aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT1Sonar)='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT1Sonar)) end
                                    if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Sonar) == 0 and aiBrain[M27Overseer.refiOurHighestAirFactoryTech] >= 3 and aiBrain[M27AirOverseer.refiAirAANeeded] <= 0 and aiBrain[M27AirOverseer.refiTorpBombersWanted] <= 0 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT1Sonar) > 0 then
                                        iActionToAssign = refActionBuildT2Sonar
                                        iMinEngiTechLevelWanted = 2
                                    end
                                end
                                if iActionToAssign then
                                    iMaxEngisWanted = 1
                                    iSearchRangeForNearestEngi = 1000
                                    if bDebugMessages == true then LOG(sFunctionRef..': Will build sonar, action='..iActionToAssign) end
                                end
                            end
                        elseif iCurrentConditionToTry == 27 then --More reclaim (lower priority locations)
                            if iMassStoredRatio == nil then iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS') end
                            if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..'; iMassStoredRatio='..iMassStoredRatio..'; M27MapInfo.iMapTotalMass='..M27MapInfo.iMapTotalMass..'; aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1]='..aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1]) end
                            if iMassStoredRatio < 0.98 then
                                if aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] + aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][2] + aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][3] > 0 then
                                    --Have some reclaim somewhere on map, so have at least 1 engineer assigned to reclaim even if no high priority locations
                                    iActionToAssign = refActionReclaimArea
                                    --M27MapInfo.UpdateReclaimMarkers() --Does periodically if been a while since last update --Moved this to overseer so dont end up with engis waiting for this to compelte
                                    iMaxEngisWanted = math.max(1, math.ceil(((aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] or 0) + (aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][2] or 0) + (aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][3] or 0))/3))
                                    if iMaxEngisWanted > 20 then iMaxEngisWanted = 20 end
                                    iSearchRangeForNearestEngi = 10000
                                    if bDebugMessages == true then LOG(sFunctionRef..': Reclaim: iMaxEngisWanted='..iMaxEngisWanted) end
                                end
                            end
                        elseif iCurrentConditionToTry == 28 then --Experimental if have loads of mass
                            if aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 25 and iHighestFactoryOrEngineerTechAvailable >= 3 then --at least 250 gross income ignoring reclaim
                                if aiBrain:GetEconomyStored('MASS') >= 10000 or (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyLandEarly and aiBrain:GetEconomyStored('MASS') >= 8000) or (aiBrain:GetEconomyStoredRatio('MASS') >= 0.5 and aiBrain:GetEconomyStored('MASS') >= 4000 and aiBrain[M27EconomyOverseer.refiMassNetBaseIncome] >= 1 and bHaveLowPower == false and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 7) then
                                    iActionToAssign = refActionBuildLandExperimental
                                    if bHaveLowPower then iMaxEngisWanted = 2 else iMaxEngisWanted = math.min(30, math.max(3, math.ceil(aiBrain:GetEconomyStored('MASS')/500), math.ceil(aiBrain[M27EconomyOverseer.refiMassNetBaseIncome] * 2))) end
                                    iMaxEngisWanted = 30
                                    iSearchRangeForNearestEngi = 175
                                    iMinEngiTechLevelWanted = 3
                                end
                            end

                        --SPARE ACTIONS BELOW
                        else
                            bAreOnSpareActions = true
                            if iCurrentConditionToTry == 29 then
                                if bHaveVeryLowPower == false and bHaveLowMass == false then
                                    if bWantMorePower then
                                        if iHighestFactoryOrEngineerTechAvailable == 1 then
                                            iActionToAssign = refActionBuildSecondPower
                                            iSearchRangeForNearestEngi = 100
                                            iMaxEngisWanted = 8
                                        else
                                            if iT3Power == nil then iT3Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH3) end
                                            if iT2Power == nil then iT2Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH2) end

                                            if aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 20 and ((aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 and iT3Power >= 2) or (aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 2 and iT2Power >=2)) then
                                                iActionToAssign = refActionBuildSecondPower
                                                iMaxEngisWanted = 5
                                            else
                                                iActionToAssign = refActionBuildPower
                                                iMaxEngisWanted = 15
                                            end
                                            iSearchRangeForNearestEngi = 100
                                        end
                                    end
                                end
                            elseif iCurrentConditionToTry == 30 then
                                if bHaveLowMass == false and bHaveLowPower == false then
                                    if iMassStoredRatio == nil then iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS') end
                                    if iMassStored == nil then iMassStored = aiBrain:GetEconomyStored('MASS') end
                                    if iMassStored > 800 and iMassStoredRatio >= 0.5 and (aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] < 750 or bWantMorePower) then --7.5k net energy income
                                        iActionToAssign = refActionBuildSecondPower
                                        iSearchRangeForNearestEngi = 100
                                        iMaxEngisWanted = 10
                                    end
                                end
                            elseif iCurrentConditionToTry == 31 then
                                if bHaveLowMass == false and iHighestFactoryOrEngineerTechAvailable == 1 and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                                    iActionToAssign = refActionBuildThirdPower
                                    iMaxEngisWanted = 4
                                end
                            elseif iCurrentConditionToTry == 32 then
                                if bHaveLowMass == false and bHaveLowPower == false then
                                   if (iMassStoredRatio > 0.6 or iMassStored > 12000) then --About to overflow so try to build something
                                       --local iFactoryToAirRatio = iLandFactories / math.max(1, iAirFactories)
                                       --local iDesiredFactoryToAirRatio = aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] / math.max(1, aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir])
                                       --if iFactoryToAirRatio > iDesiredFactoryToAirRatio then
                                           --if bDebugMessages == true then LOG(sFunctionRef..': iFactoryToAirRatio='..iFactoryToAirRatio..'; iDesiredFactoryToAirRatio='..iDesiredFactoryToAirRatio..'; iLandFactories='..iLandFactories..'; iAirFactories='..iAirFactories..'; aiBrain[M27Overseer.reftiMaxFactoryByType]='..repr(aiBrain[M27Overseer.reftiMaxFactoryByType])) end
                                       if iAirFactories < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir] then
                                           iActionToAssign = refActionBuildAirFactory
                                       else iActionToAssign = refActionBuildLandFactory
                                       end
                                    end
                                    iMaxEngisWanted = 10
                                end
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': No priority actions so will assign any remaining engineers to spare action') end
                                iActionToAssign = refActionSpare
                                iSearchRangeForNearestEngi = 10000
                                iMaxEngisWanted = 1000
                            end
                        end
                    end

                    iLoopCount = iLoopCount + 1
                    if iLoopCount > iMaxLoopCount then
                        M27Utilities.ErrorHandler('Infinite loop for engineer assignment, will abort')
                        break
                    end


                    bWillBeAssigning = false
                    if iActionToAssign then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have an action to assign='..iActionToAssign..', will adjust the number of engineers we want if we are building power; iMaxEngisWanted before adj='..iMaxEngisWanted) end
                        --Increase engis to assign to power based on tech level
                        if iActionToAssign == refActionBuildPower then iMaxEngisWanted = iMaxEngisWanted + iExtraEngisForPowerBasedOnTech end
                        iExistingEngineersAssigned = 0
                        if aiBrain[reftEngineerAssignmentsByActionRef] and aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign]) == false then
                            --Cant use table.getn for this table so do manually:
                            for iEngineer, oEngineer in  aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] do
                                iExistingEngineersAssigned = iExistingEngineersAssigned + 1
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': iExistingEngineersAssigned='..iExistingEngineersAssigned..'; iMaxEngisWanted='..iMaxEngisWanted) end
                        if iExistingEngineersAssigned <= iMaxEngisWanted then
                            if iExistingEngineersAssigned == iMaxEngisWanted then
                                --Check if ACU is one of the units assigned to this action
                                if M27Utilities.GetACU(aiBrain)[refiEngineerCurrentAction] == iActionToAssign then
                                    if bDebugMessages == true then LOG(sFunctionRef..': iActionToAssign='..iActionToAssign..': ACU already has this action so reducing the number of engineers assigned.  iExistingEngineersAssigned before this change='..iExistingEngineersAssigned..'; iMaxEngisWanted='..iMaxEngisWanted) end
                                    iExistingEngineersAssigned = iExistingEngineersAssigned - 1
                                end
                            end
                            if iExistingEngineersAssigned < iMaxEngisWanted then

                                if bDebugMessages == true then LOG(sFunctionRef..': iActionToAssign='..iActionToAssign..'; iMaxEngisWanted='..iMaxEngisWanted..'; iCurrentConditionToTry='..iCurrentConditionToTry) end
                                --Need to get the location first so can search for engineers nearest to it
                                if iSearchRangeForNearestEngi == nil then iSearchRangeForNearestEngi = 100 end
                                        --GetActionTargetAndObject(aiBrain, iActionRefToAssign, tExistingLocationsToPickFrom, tIdleEngineers, iActionPriority, tsUnitStatesToIgnoreCurrent, iSearchRangeForPrevEngi, iSearchRangeForNearestEngi, bOnlyReassignIdle, bGetInitialEngineer, iMinTechLevelWanted)
        --GET MIN ENGI TECH LEVEL WANTED if not already specified above
                                --Set minimum engineer tech level if not specified and no existing engineers assigned to the action
                                if (iHighestFactoryOrEngineerTechAvailable > 1 or iHighestFactoryOrEngineerTechAvailable > 1) and iMinEngiTechLevelWanted == nil then
                                    --Are we building power or factory? If so then only build with the highest tech engi unless action is already in progress
                                    if iActionToAssign == refActionBuildPower or iActionToAssign == refActionBuildSecondPower or iActionToAssign == refActionBuildThirdPower or iActionToAssign == refActionBuildAirFactory or iActionToAssign == refActionBuildLandFactory then
                                        --Do we have at least 440 gross power or minimal mass stored? othwerise dont set any limit
                                        if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] > 44 or (aiBrain:GetEconomyStoredRatio('MASS') <= 0.1 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99) then
                                            --Have we already got an engineer assigned to this action?
                                            if iExistingEngineersAssigned == 0 then
                                                if iActionToAssign == refActionBuildPower then iMinEngiTechLevelWanted = math.max(iHighestFactoryOrEngineerTechAvailable, iHighestFactoryOrEngineerTechAvailable)
                                                else iMinEngiTechLevelWanted = iHighestFactoryOrEngineerTechAvailable end
                                                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and aiBrain[M27Overseer.refbIncludeACUInAllOutAttack] then
                                                    iMinEngiTechLevelWanted = math.min(iHighestFactoryOrEngineerTechAvailable, iHighestFactoryOrEngineerTechAvailable)
                                                end
                                            elseif iHighestFactoryOrEngineerTechAvailable >= 3 then
                                                iMinEngiTechLevelWanted = 2
                                            end
                                        end
                                    elseif iActionToAssign == refActionBuildT3MexOverT2 then iMinEngiTechLevelWanted = 3
                                    else
                                        --Dont use t1 engineers for anything likely to be built near base once we have T3+ factory
                                        if iMinEngiTechLevelWanted == nil and iHighestFactoryOrEngineerTechAvailable >= 3 then
                                            if not(iActionToAssign == refActionBuildMex) and not(iActionToAssign == refActionBuildT1Radar) and not(iActionToAssign == refActionBuildMassStorage) and not(iActionToAssign == refActionReclaimArea) and not(iActionToAssign == refActionReclaimTrees) and not(iActionToAssign == refActionSpare) and not(iActionToAssign == refActionBuildHydro) then
                                                iMinEngiTechLevelWanted = 2
                                            end
                                        end
                                    end
                                end
                                if iMinEngiTechLevelWanted == nil then iMinEngiTechLevelWanted = 1 end
                                if bDebugMessages == true then LOG(sFunctionRef..': iMinEngiTechLevelWanted='..iMinEngiTechLevelWanted) end
                                tActionTargetLocation, oActionTargetObject, bClearCurrentlyAssignedEngineer = GetActionTargetAndObject(aiBrain, iActionToAssign, tExistingLocationsToPickFrom, tIdleEngineers, iCurrentConditionToTry, tsUnitStatesToIgnoreCurrent, iSearchRangeForPrevEngi, iSearchRangeForNearestEngi, bOnlyReassignIdle, bGetInitialEngineer, iMinEngiTechLevelWanted)

                                --GetNearestEngineerWithLowerPriority(aiBrain, tEngineers, iCurrentActionPriority, tCurrentActionTarget, iActionRefToGetExistingCount, tsUnitStatesToIgnore)
                                if M27Utilities.IsTableEmpty(tActionTargetLocation) == true and oActionTargetObject == nil then
                                    M27Utilities.ErrorHandler('Couldnt find valid target or object for the action so wont proceed with it, review if this happens repeatedly as normally shoudlnt have this happen - current examples are if want to assist a building but all of them have nearby enemies, or if try to reclaim a unit that no longer has a position. iActionToAssign='..iActionToAssign..'; iCurrentConditionToTry='..iCurrentConditionToTry)
                                    iCurConditionEngiShortfall = iMaxEngisWanted - iExistingEngineersAssigned
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': iExistingEngineersAssigned='..iExistingEngineersAssigned..'; iMinEngiTechLevelWanted='..iMinEngiTechLevelWanted) end
                                    --GetNearestEngineerWithLowerPriority(aiBrain, tEngineers, iCurrentActionPriority, tCurrentActionTarget, iActionRefToGetExistingCount, tsUnitStatesToIgnore, iMaxRangeForPrevEngi)
                                    if oEngineerToAssign == nil then oEngineerToAssign = GetNearestEngineerWithLowerPriority(aiBrain, tIdleEngineers, iCurrentConditionToTry, tActionTargetLocation, iActionToAssign, tsUnitStatesToIgnoreCurrent, iSearchRangeForPrevEngi, iSearchRangeForNearestEngi, bOnlyReassignIdle, bGetInitialEngineer, iMinEngiTechLevelWanted) end
                                    if oEngineerToAssign then
                                        if bDebugMessages == true then
                                            local sEngiName = M27UnitInfo.GetUnitLifetimeCount(oEngineerToAssign)
                                            LOG(sFunctionRef..': Have a valid engineer and not already assigned for the action, so will be assigning action to this engineer with name='..sEngiName)
                                        end
                                        bWillBeAssigning = true
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..' condition:'..iCurrentConditionToTry..': oEngineerToAssign is nil, assuming its because available engineer is too far away so wont abort') end
                                        iCurConditionEngiShortfall = iMaxEngisWanted - iExistingEngineersAssigned
                                    end
                                end
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Already assigned '..iExistingEngineersAssigned..'  engis and only wanted '..iMaxEngisWanted) end
                        end
                    else
                        iCurConditionEngiShortfall = 0
                    end


                    --Update build order tracker; all of below were set to 0 before started the loop, so only need to change from 0
                    --Note that for spare engis we just track how many we have (not how many we want)
                    if iCurConditionEngiShortfall > 0 then
                        if bAreOnSpareActions == false then
                            --NOTE: Although below will set engis wanted, this may be changed back to 0 at end if we have engineers of the highest tech level
                            if bThresholdPreReclaimEngineerCondition == false then
                                if bThresholdInitialEngineerCondition == false then --Not got through initial conditions
                                    aiBrain[refiBOInitialEngineersWanted] = aiBrain[refiBOInitialEngineersWanted] + iCurConditionEngiShortfall
                                    aiBrain[refiBOPreReclaimEngineersWanted] = 1
                                    aiBrain[refiBOPreSpareEngineersWanted] = 1
                                else --Have got initial engis
                                    aiBrain[refiBOPreReclaimEngineersWanted] = aiBrain[refiBOPreReclaimEngineersWanted] + iCurConditionEngiShortfall
                                    aiBrain[refiBOPreSpareEngineersWanted] = 1
                                end
                            else --Have got initial engis and pre-reclaim engis
                                aiBrain[refiBOPreSpareEngineersWanted] = aiBrain[refiBOPreSpareEngineersWanted] + iCurConditionEngiShortfall
                            end
                        else
                            --Already all set to 0
                        end
                    end
                    --Ensure we will be building initial engineer build order in priority to anything else
                    if M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryEngineer, aiBrain[M27FactoryOverseer.refiInitialEngineersWanted]) then
                        aiBrain[refiBOInitialEngineersWanted] = math.max(aiBrain[refiBOInitialEngineersWanted], aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] - aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer))
                    end


                    if bWillBeAssigning == true then
                        if bDebugMessages == true then
                            local sEngineerName = M27UnitInfo.GetUnitLifetimeCount(oEngineerToAssign)
                            LOG(sFunctionRef..': Game time='..GetGameTimeSeconds()..': About to assign action '..iActionToAssign..' to engineer number '..GetEngineerUniqueCount(oEngineerToAssign)..' with lifetime count='..sEngineerName..' due to iCurrentConditionToTry='..iCurrentConditionToTry..'; Eng unitId='..oEngineerToAssign:GetUnitId()..'; ActionTargetLocation='..repr(tActionTargetLocation))
                            if iAllUnclaimedMexesInPathingGroup then LOG('iAllUnclaimedMexesInPathingGroup='..iAllUnclaimedMexesInPathingGroup) end
                            if iUnclaimedMexesOnOurSideOfMap then LOG('iUnclaimedMexesOnOurSideOfMap='..iUnclaimedMexesOnOurSideOfMap) end
                            if iUnclaimedMexesWithinDefenceCoverage then LOG('iUnclaimedMexesWithinDefenceCoverage='..iUnclaimedMexesWithinDefenceCoverage) end
                        end
                        if bClearCurrentlyAssignedEngineer == true then --will be true if currently assigned engineer is lower tech level than the min tech level wanted
                            --Clear existing engineer assigned the action
                            local oEngineerToClear = aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign][refEngineerAssignmentEngineerRef]
                            if oEngineerToClear then
                                --if GetEngineerUniqueCount(oEngineerToClear) == 59 then bDebugMessages = true end
                                if bDebugMessages == true then LOG(sFunctionRef..': Want to clear currently assigned engineer for the action; engi to clear='..oEngineerToClear:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oEngineerToClear)) end
                                M27Utilities.ClearEngineerActionTrackers(aiBrain, oEngineerToClear, false)
                            end
                        end
                        iEngineersToConsider = iEngineersToConsider - 1
                        AssignActionToEngineer(aiBrain, oEngineerToAssign, iActionToAssign, tActionTargetLocation, oActionTargetObject, iCurrentConditionToTry)
                        if iActionToAssign == refActionBuildMex then
                            tAllUnclaimedMexesInPathingGroup = nil
                            iAllUnclaimedMexesInPathingGroup = nil
                            tUnclaimedMexesOnOurSideOfMap = nil
                            iUnclaimedMexesOnOurSideOfMap = nil
                            tUnclaimedMexesWithinDefenceCoverage = nil
                            iUnclaimedMexesWithinDefenceCoverage = nil
                        end
                    else
                        iCurrentConditionToTry = iCurrentConditionToTry + 1
                        if iActionToAssign == refActionSpare then
                            M27Utilities.ErrorHandler('Werent able to assign a spare action to an engineer so likely we think an engineer is idle but we cant then locate that engineer when trying toa ssign the action - investigate')
                            break
                        end --If we couldnt assign a spare engi action then dont want to keep going as may be in infinite loop territory
                    end
                end
            end

            --Check how many spare engineers we have
            local tiSpareEngiCount = {0,0,0,0}
            local iCurTechLevel
            for iEngineer, oEngineer in tEngineers do
                if oEngineer[refiEngineerCurrentAction] == refActionSpare then
                    iCurTechLevel = M27UnitInfo.GetUnitTechLevel(oEngineer)
                    tiSpareEngiCount[iCurTechLevel] = tiSpareEngiCount[iCurTechLevel] + 1
                end
            end
            local iExistingSpareEngisForCurTechLevel = 0
            for iCurTechLevel = iHighestFactoryOrEngineerTechAvailable, 4 do
                if tiSpareEngiCount[iCurTechLevel] > 0 then iExistingSpareEngisForCurTechLevel = iExistingSpareEngisForCurTechLevel + 1 end
            end
            aiBrain[refiBOActiveSpareEngineers] = tiSpareEngiCount
            if iExistingSpareEngisForCurTechLevel > 2 then
                aiBrain[refiBOInitialEngineersWanted] = 0
                aiBrain[refiBOPreReclaimEngineersWanted] = 0
                aiBrain[refiBOPreSpareEngineersWanted] = 0
            end

      --TEMPTEST(aiBrain, sFunctionRef..': End of code')
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DelayedEngiReassignment(aiBrain, bOnlyReassignIdle, tEngineersToReassign)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'DelayedEngiReassignment'
    WaitTicks(1)
    if M27Logic.iTimeOfLastBrainAllDefeated < 10 then
        if bDebugMessages == true then LOG(sFunctionRef..': Reassigning '..table.getn(tEngineersToReassign)..'engineers') end
        ReassignEngineers(aiBrain, bOnlyReassignIdle, tEngineersToReassign)
    end
end

function EngineerInitialisation() end --Done to help find where we declare our variables
function EngineerManager(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'EngineerManager'
    local iLongLoopCount = 0
    local iLongLoopThreshold = 5

    --Initial setup:
    aiBrain[refiInitialMexBuildersWanted] = 2
    aiBrain[refiEngineerCurUniqueReference] = 0
    aiBrain[reftEngineerActionsByEngineerRef] = {}
    aiBrain[reftEngineerAssignmentsByActionRef] = {}
    aiBrain[reftEngineerAssignmentsByLocation] = {}
    aiBrain[refbNeedResourcesForMissile] = false
    aiBrain[refiTimeOfLastEngiSelfDestruct] = 0
    aiBrain[reftEngineersHelpingACU] = {}

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    while(not(aiBrain:IsDefeated())) do
        if aiBrain.M27IsDefeated or M27Logic.iTimeOfLastBrainAllDefeated > 10 then break end
        if iLongLoopCount == 0 then
            if bDebugMessages == true then LOG(sFunctionRef..': Doing full refresh of all engineers') end
            --ReassignEngineers(aiBrain, false)
            ForkThread(ReassignEngineers, aiBrain, false)
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Only assigning actions to idle engineers') end
            ForkThread(ReassignEngineers, aiBrain, true)
        end
        iLongLoopCount = iLongLoopCount + 1
        --Had hoped to do a full refresh periodically but causing too many bugs and poor CPU performance
        --if iLongLoopCount >= iLongLoopThreshold then iLongLoopCount = 0 end
        if bDebugMessages == true then LOG(sFunctionRef..': About to wait 10 ticks') end
  --TEMPTEST(aiBrain, sFunctionRef..': Pre wait 10 ticks')
        WaitTicks(10)
        if bDebugMessages == true then LOG(sFunctionRef..': End of cycle after waiting 10 ticks') end
  --TEMPTEST(aiBrain, sFunctionRef..': Post wait 10 ticks')
    end
end
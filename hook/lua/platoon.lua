-- 6819 line items (without uveso) before this is appended
--6828 as of 2021-09
local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27ConUtility = import('/mods/M27AI/lua/AI/M27ConstructionUtilities.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
--local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')



M27PlatoonClass = Platoon
Platoon = Class(M27PlatoonClass) {

    PlatoonDisband = function(self)

        if self.GetBrain and self:GetBrain().M27AI then
            local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
            local sFunctionRef = 'PlatoonDisband'
            if bDebugMessages == true then LOG(sFunctionRef..' Just attempted to disband platoon') end
            M27PlatoonClass.PlatoonDisband(self)
        else
            M27PlatoonClass.PlatoonDisband(self)
        end
    end,

    ProcessBuildCommand = function(eng, removeLastBuild)
        --For some reason this is called whenever a reclaim command is issued to a builder
        if not eng or eng.Dead or not eng.PlatoonHandle then
            return
        else
            local aiBrain = eng:GetAIBrain()
            if aiBrain.M27AI then
                --Do nothing
            else
                M27PlatoonClass.ProcessBuildCommand(eng, removeLastBuild)
            end
        end
    end,
    --[[

        if 1 == 1 then --basic flag used to turn on and off while testing new code to check new code worked without this
        --With thanks to UVESO for tweaks to the base code for this (which fixes an issue where the ACU stopped building after completing the first build order despite having a valid location to build to from aibuildstructures)
            --(these tweaks were subsequently incorporated into FAF main patch)
    -- For AI Patch V9. Fixed a bug where the ACU stops working when build to close
            local bDoNothing = false

            local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
            if bDebugMessages == true then LOG('Running ProcessBuildCommand') end
            if not eng or eng.Dead or not eng.PlatoonHandle then
                return
            end
            local aiBrain = eng.PlatoonHandle:GetBrain()
            local sPlatoonName = 'None'
            local oPlatoon = eng.PlatoonHandle
            if oPlatoon then
                if oPlatoon.GetPlan then sPlatoonName = oPlatoon:GetPlan() end

                if not aiBrain or eng.Dead or not eng.EngineerBuildQueue or table.empty(eng.EngineerBuildQueue) then
                    if not(oPlatoon==nil) then
                        if not eng.AssistSet and not eng.AssistPlatoon and not eng.UnitBeingAssist then
                            --M27 added code to ignore the code where platoon is reclaiming as its current action
                            local oPlatoonHandle = eng.PlatoonHandle
                            local iPlatoonAction = oPlatoonHandle[M27PlatoonUtilities.refiCurrentAction]
                            if iPlatoonAction == nil then iPlatoonAction = 'nil' end
                            if bDebugMessages == true then LOG('ProcessBuildCommand: iPlatoonAction='..iPlatoonAction..'; Platoon plan='..oPlatoonHandle:GetPlan()) end
                            if iPlatoonAction == M27PlatoonUtilities.refActionReclaimTarget then bDoNothing = true
                            else


                                --Sometimes this code fires, e.g. if running assisthydro AI, and then switch to defender platoon AI
                                if sPlatoonName == 'M27ACUMain' or sPlatoonName == 'M27AssistHydroEngi' or sPlatoonName == 'M27DefenderAI' then
                                    if bDebugMessages == true then LOG('ProcessBuildCommand: WARNING - were about to disband platoon butaborting due to m27 added override of core code') end
                                    bDoNothing = true
                                else
                                    if bDebugMessages == true then LOG('ProcessBuildCommand: About to disband platoon1; sPlatoonName='..sPlatoonName) end
                                    if eng.PlatoonHandle and aiBrain:PlatoonExists(eng.PlatoonHandle) then eng.PlatoonHandle:PlatoonDisband() end
                                end
                            end
                        end
                    end
                    if eng then eng.ProcessBuild = nil end
                    return
                end
            end
            if bDoNothing == false then

                -- it wasn't a failed build, so we just finished something
                --local sConstructedBP
                --local oConstuctedUnitExample
                if removeLastBuild then
                    --if bDebugMessages == true then LOG('Platoon: ProcessBuildComand: Remove eng build queue; eng.EngineerBuildQueue[1][1]='..tostring(eng.EngineerBuildQueue[1][1])) end
                    --Check if just constructed a factory, and if so then set its rally point - commented this out as the SetRallyPoint hook covers this already
                    --if EntityCategoryContains(categories.FACTORY, eng.EngineerBuildQueue[1][1]) == true then
                    --Cycle through all factories and udpate their rally point if its not already been set:
                    --                local bRallySet
                    --              if bDebugMessages == true then LOG('Platoon: ProcessBuildCommand: Have just built a factory; updating factory rally points') end
                    --            for iUnit, oUnit in aiBrain:GetListOfUnits(categories.FACTORY, true) do
                    --              bRallySet = false
                    --            if oUnit.bRallySet == nil then oUnit.bRallySet = false
                    --          else
                    --            bRallySet = oUnit.bRallySet
                    --      end
                    --    if bDebugMessages == true then LOG('In loop of factory units; iUnit='..iUnit..'; bRallySet='..tostring(bRallySet)) end
                    --  if bRallySet == false then
                    --    M27Logic.SetFactoryRallyPoint(oUnit)
                    --  oUnit.bRallySet = true
                    --                    end
                    --              end
                    --        end

                    --LOG('Platoon: ProcessBuildCommand: Does the unit bp contain factory category?'..tostring(EntityCategoryContains(categories.FACTORY, eng.EngineerBuildQueue[1][1])))
                    table.remove(eng.EngineerBuildQueue, 1)
                end

                eng.ProcessBuildDone = false
                if bDebugMessages == true then LOG('Platoon: ProcessBuildCommand: Just before issue clear commands to eng UnitId='..eng.UnitId) end
                M27Utilities.IssueTrackedClearCommands({eng})
                local commandDone = false
                local PlatoonPos
                local iCount = 0
                while not eng.Dead and not commandDone and not table.empty(eng.EngineerBuildQueue)  do
                    iCount = iCount + 1
                    if iCount > 1000 then
                        M27Utilities.ErrorHandler('Infinite loop 1')
                        LOG('eng ID and lifetime count='..eng.UnitId..M27UnitInfo.GetUnitLifetimeCount(eng))
                        break
                    end
                    if bDebugMessages == true then LOG('Platoon: ProcessBuildCommand: Getting next building from engineer build queue') end
                    local whatToBuild = eng.EngineerBuildQueue[1][1]
                    local buildLocation = {eng.EngineerBuildQueue[1][2][1], 0, eng.EngineerBuildQueue[1][2][2]}
                    if GetTerrainHeight(buildLocation[1], buildLocation[3]) > GetSurfaceHeight(buildLocation[1], buildLocation[3]) then
                        --land
                        buildLocation[2] = GetTerrainHeight(buildLocation[1], buildLocation[3])
                    else
                        --water
                        buildLocation[2] = GetSurfaceHeight(buildLocation[1], buildLocation[3])
                    end
                    local buildRelative = eng.EngineerBuildQueue[1][3]
                    if not eng.NotBuildingThread then
                        eng.NotBuildingThread = eng:ForkThread(eng.PlatoonHandle.WatchForNotBuilding)
                    end
                    -- see if we can move there first
                    if bDebugMessages == true then LOG('Platoon: ProcessBuildCommand: About to see if engineer can move to buildLocation') end
                    if AIUtils.EngineerMoveWithSafePath(aiBrain, eng, buildLocation) then
                        if not eng or eng.Dead or not eng.PlatoonHandle or not aiBrain:PlatoonExists(eng.PlatoonHandle) then
                            return
                        end
                        -- issue buildcommand to block other engineers from caping mex/hydros or to reserve the buildplace
                        PlatoonPos = eng:GetPosition()

                        if bDebugMessages == true then LOG('ProcessBuildCommand: About to call MoveNearConstruction') end
                        --MoveNearConstruction(aiBrain, oBuilder, tLocation, sBlueprintID, iBuildDistanceMod, bReturnMovePathInstead, bUpdatePlatoonMovePath, bReturnNilIfAlreadyMovingNearConstruction)
                        M27PlatoonUtilities.MoveNearConstruction(aiBrain, eng, buildLocation, whatToBuild, 0, false, false, false)
                        if VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, buildLocation[1] or 0, buildLocation[3] or 0) >= 30 then
                            if bDebugMessages == true then LOG('ProcessBuildCommand: >=30 loop') end
                            aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                            coroutine.yield(3)
                            -- wait until we are close to the buildplace so we have intel
                            local iCount2 = 0
                            while not eng.Dead do
                                iCount2 = iCount2 + 1
                                if iCount2 > 1000 then M27Utilities.ErrorHandler('Infinite loop 2')
                                    LOG('eng ID and lifetime count='..eng.UnitId..M27UnitInfo.GetUnitLifetimeCount(eng))
                                    break
                                end
                                PlatoonPos = eng:GetPosition()
                                if VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, buildLocation[1] or 0, buildLocation[3] or 0) < 12 then
                                    if bDebugMessages == true then LOG('Exiting ProcessBuildCommand') end
                                    break
                                end
                                -- check if we are already building in close range
                                -- (ACU can build at higher range than engineers)
                                if eng:IsUnitState("Building") then
                                    break
                                end
                                coroutine.yield(1)
                            end
                        end
                        if not eng or eng.Dead or not eng.PlatoonHandle or not aiBrain:PlatoonExists(eng.PlatoonHandle) then
                            if eng then eng.ProcessBuild = nil end
                            return
                        end
                        -- if we are already building then we don't need to reclaim, repair or issue the BuildStructure again
                        if not eng:IsUnitState("Building") then
                            -- cancel all commands, also the buildcommand for blocking mex to check for reclaim or capture
                            eng.PlatoonHandle:Stop()
                            -- check to see if we need to reclaim or capture...
                            AIUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, buildLocation)
                            -- check to see if we can repair
                            AIUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, buildLocation)
                            -- otherwise, go ahead and build the next structure there
                            if bDebugMessages == true then LOG('ProcessBuildCommand: About to send build structure command') end
                            M27PlatoonUtilities.MoveNearConstruction(aiBrain, eng, buildLocation, whatToBuild)
                            aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                        end
                        if not eng.NotBuildingThread then
                            if bDebugMessages == true then LOG('ProcessBuildCommand: Fork for watchfornotbuilding') end
                            eng.NotBuildingThread = eng:ForkThread(eng.PlatoonHandle.WatchForNotBuilding)
                        end
                        commandDone = true
                    else
                        -- we can't move there, so remove it from our build queue
                        table.remove(eng.EngineerBuildQueue, 1)
                    end
                end

                -- final check for if we should disband
                if not eng or eng.Dead or table.empty(eng.EngineerBuildQueue) then
                    if eng.PlatoonHandle and not eng.PlatoonHandle.UsingTransport then
                        if bDebugMessages == true then LOG('ProcessBuildCommand: About to disband platoon2') end
                        if eng.PlatoonHandle and aiBrain:PlatoonExists(eng.PlatoonHandle) then eng.PlatoonHandle:PlatoonDisband() end
                    end
                end
                if eng then eng.ProcessBuild = nil end
            end
        end
    end,--]]


    --[[M27ReclaimAI = function(self)
        --NOTE: REDUNDANT AI LOGIC

        --Gets engineer to attack-move to the best reclaim area on the map (based on location, mass value, how many other platoons have gone, etc.)
        --does nothing if engineer is busy
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        local bPlatoonNameDisplay = false
        local sFunctionRef = 'M27ReclaimAI'
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        if M27Config.M27ShowUnitNames == true then bPlatoonNameDisplay = true end
        local sPlatoonName = 'M27ReclaimAI'
        M27Utilities.ErrorHandler('Redundant AI logic '..sPlatoonName..' still being used')
        if bDebugMessages==true then LOG('* M27ReclaimAI has been started - locating engineers in the platoon') end
        local aiBrain = self:GetBrain()
        local platoonUnits = GetPlatoonUnits(self)
        local eng

        local bPlatoonNameDisplay = false
        if M27Config.M27ShowUnitNames == true then bPlatoonNameDisplay = true end

        --Set platoon names:
        if bPlatoonNameDisplay == true then M27PlatoonUtilities.UpdatePlatoonName(self, sPlatoonName) end

        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.MOBILE * categories.ENGINEER, v) then
                eng = v
                break
            end
        end
        if eng then
            local tTarget
            while aiBrain:PlatoonExists(self) do
                if bDebugMessages==true then LOG('ReclaimPlatoon: Starting while loop.  GetGameTimeSeconds='..GetGameTimeSeconds()) end
                for iCycle = 1, 30 do
                    if not eng or eng.Dead then
                        if self and aiBrain:PlatoonExists(self) then self:PlatoonDisband() break end end
                    if iCycle == 1 then
                        M27MapInfo.UpdateReclaimMarkers(eng) --Refreshes reclaim in each marker if enough time has elapsed or it's never been done
                        tTarget = M27Logic.ChooseReclaimTarget(eng)

                        --Below comments are for if want to manually test a location:
                        --tTarget = {262.5, 47.585899353027, 268.5}
                        --local iDestX = 12.5*20
                        --local iDestZ = 12.5*20
                        --local iCurHeight = GetTerrainHeight(iDestX, iDestZ)
                        --tTarget = {iDestX, iCurHeight, iDestZ}
                        --LOG('CanPathTo '..tTarget[1]..'-'..tTarget[2]..'-'..tTarget[3]..'='..tostring(eng:CanPathTo(tTarget)))
                        if bDebugMessages==true then LOG('ReclaimPlatoon: Starting for loop, on cycle 1.  GetGameTimeSeconds='..GetGameTimeSeconds()) end
                        M27Utilities.IssueTrackedClearCommands({eng})
                        IssueAggressiveMove({eng}, tTarget )
                        if bDebugMessages==true then LOG('ReclaimPlatoon: Telling enginneer to attack-move to tTarget='..tTarget[1]..'-'..tTarget[2]..'-'..tTarget[3]..'; GetGameTimeSeconds='..GetGameTimeSeconds()) end
                    end
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    WaitTicks(100)
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                    if eng and self and not(eng.Dead) then
                        if eng:IsUnitState('Moving')==false and eng:IsUnitState('Attacking') == false and eng:IsUnitState('Busy') == false and eng:IsUnitState('Reclaiming') == false then --possible IsUnitStates that have been able to identify so far: Moving, Attacking, Upgrading, Building, Teleporting, Enhancing, Attached, Guarding, Repairing, Busy
                            if bDebugMessages==true then LOG('ReclaimPlatoon: Engineer isnt moving or attacking so reset target if still the case after 1 tick.  Gametime='..GetGameTimeSeconds()..'; iCycle='..iCycle) end
                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                            WaitTicks(1)
                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                            if eng and self and not(eng.Dead) then
                                if eng:IsUnitState('Moving')==false and eng:IsUnitState('Attacking') == false and eng:IsUnitState('Busy') == false and eng:IsUnitState('Reclaiming') == false then
                                    iCycle = 1
                                    if bDebugMessages==true then LOG('ReclaimPlatoon: Engineer isnt moving or attacking after waiting 1 tick so resetting iCycle to 1.  Gametime='..GetGameTimeSeconds()) end
                                end
                            else
                                break
                            end
                        elseif M27Utilities.GetDistanceBetweenPositions(eng:GetPosition(), tTarget) < 10 then if iCycle < 80 then iCycle = 80 end
                        end
                    else break end
                end
            end
            if bDebugMessages==true then LOG('ReclaimPlatoon: Ending.  GetGameTimeSeconds='..GetGameTimeSeconds()) end
            --eng.UnitBeingBuilt = nil
        end
        --disband platoon:
        if self and aiBrain and aiBrain.PlatoonExists and aiBrain:PlatoonExists(self) then
            if bPlatoonNameDisplay == true then M27PlatoonUtilities.UpdatePlatoonName(self, 'No custom platoon AI') end
            if bDebugMessages == true then LOG('M27ReclaimAI: About to disband platoon') end
            self:PlatoonDisband()
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end,
    M27AssistHydroEngi = function(self)
        --NOTE: REDUNDANT AI LOGIC - HAVE INCORPORATED MAIN PARTS INTO ACU MAIN; ACU Main might not be quite as good/efficient, but means dont have to worry about switching AI plans

        --Used with initial build order to get ACU to assist engineer constructing a hydro; stops as soon as player has a hydro constructed
        --Done before had introduced main platoon logic, so most of this is manual, but it's been updated to reference some of the standard platoon logic re nearby enemies, mexes and reclaim
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        local sPlatoonName = 'M27AssistHydroEngi'
        local sFunctionRef = 'M27AssistHydroEngi'
        M27Utilities.ErrorHandler('Redundant AI logic '..sPlatoonName..' still being used')
        local sFunctionRef = sPlatoonName
        --Set platoon names
        local bPlatoonNameDisplay = false
        if M27Config.M27ShowUnitNames == true then bPlatoonNameDisplay = true end
        if bPlatoonNameDisplay == true then M27PlatoonUtilities.UpdatePlatoonName(self, sPlatoonName) end
        if bDebugMessages == true then LOG('M27AssistHydroEngi started') end
        M27PlatoonUtilities.PlatoonInitialSetup(self) --sets some variables in case of use for making other code work

        local aiBrain = self:GetBrain()
        local platoonUnits = GetPlatoonUnits(self)
        local eng



        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.MOBILE * categories.ENGINEER, v) then
                eng = v
                break
            end
        end

        if eng then
            --Check that dont already have hydrocarbon constructed (backup as this seems to get called after hydro constructed despite build condition):
            if aiBrain:GetCurrentUnits(categories.STRUCTURE * categories.HYDROCARBON) < 1 then
                --Move towards hydro if not already near it
                local tNearestHydro = {}
                local iMinHydroDistance = 1000
                local iCurHydroDistance
                if bDebugMessages == true then M27Utilities.DrawLocations(M27MapInfo.HydroPoints) end
                for iHydro, tHydroPos in M27MapInfo.HydroPoints do
                    iCurHydroDistance = M27Utilities.GetDistanceBetweenPositions(tHydroPos, self:GetPlatoonPosition())
                    if iCurHydroDistance < iMinHydroDistance then
                        tNearestHydro = tHydroPos
                        iMinHydroDistance = iCurHydroDistance
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': dont have any hydrocarbons built') end
                local iArmy = M27Utilities.GetAIBrainArmyNumber(aiBrain)
                local oGuardedUnit = M27ConUtility.tHydroBuilder[iArmy][1]
                M27PlatoonUtilities.MoveNearHydroAndAssistEngiBuilder(self, oGuardedUnit, tNearestHydro)

                local oUnitBeingBuilt
                local bConstructionStarted = false
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitTicks(10)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                if oGuardedUnit and eng and aiBrain and self and aiBrain.PlatoonExists and aiBrain:PlatoonExists(self) then
                    --oGuardedUnit = eng:GetGuardedUnit()
                    if not(oGuardedUnit==nil) and not(oGuardedUnit.Dead) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have a guarded unit, proceeding with main loop') end
                        local iPlatoonMaxRange = M27Logic.GetUnitMaxGroundRange({M27Utilities.GetACU(aiBrain)})
                        local iEnemySearchRadius = iPlatoonMaxRange * 2 --Will consider responses if any enemies get within 2 times the max range of platoon
                        local iPrevAction = -1
                        local iSameActionCount = 0
                        local iBuildDistance = eng:GetBlueprint().Economy.MaxBuildDistance
                        local bIssuedTemporaryAction = false
                        while aiBrain:PlatoonExists(self) do
                            --Check if hydro has finished construction or engineer that are assisting has died:
                            if oGuardedUnit == nil then LOG(sFunctionRef..': oGuardedUnit is nil') end
                            if bDebugMessages == true then LOG(sFunctionRef..': oGuardedUnit='..tostring(oGuardedUnit.UnitId)) end
                            if not oGuardedUnit or oGuardedUnit.Dead or oGuardedUnit:BeenDestroyed() then
                                if bDebugMessages == true then LOG(sFunctionRef..': oguardedunit no longer exists') end
                                break end
                            -- stop if our target is finished
                            if bConstructionStarted == false then
                                if bDebugMessages == true then LOG(sFunctionRef..': Construction not yet started') end
                                if oGuardedUnit:IsUnitState('Building') == true then
                                    bConstructionStarted = true
                                    oUnitBeingBuilt = oGuardedUnit:GetFocusUnit()
                                    if bDebugMessages == true then LOG(sFunctionRef..': guarded unit is building; oUnitBeingBuilt='..tostring(oUnitBeingBuilt.UnitId)) end
                                end
                                --iFractionComplete = oGuardedUnit:GetFractionComplete()
                                --if iFractionComplete == nil then --do nothing
                                --else

                                --Check if engi has started yet:
                                --if iFractionComplete > 0 and iFractionComplete < 1 then bConstructionStarted = true end
                                --end
                            else
                                --Check if have completed hydro now:
                                if not(oUnitBeingBuilt==nil) then
                                    if not(oUnitBeingBuilt.Dead) then
                                        if oUnitBeingBuilt:GetFractionComplete() == 1 and not oUnitBeingBuilt:IsUnitState('Upgrading') then
                                            if bDebugMessages == true then LOG(sFunctionRef..': oGuardedUnit has completed construction') end
                                            break
                                        else
                                            if bDebugMessages == true then LOG(sFunctionRef..': oGuardedUnit is still constructing; FractionComplete='..oUnitBeingBuilt:GetFractionComplete()) end
                                            if bDebugMessages == true then LOG(sFunctionRef..': Number of hydrocarbon units='..M27Utilities.GetNumberOfUnits(aiBrain, categories.STRUCTURE * categories.HYDROCARBON)) end
                                        end
                                    else
                                        break
                                    end
                                end
                            end

                            --Check for nearby enemies, mex and reclaim:
                            if not(self[M27PlatoonUtilities.refiCurrentAction] == nil) then
                                iPrevAction = self[M27PlatoonUtilities.refiCurrentAction]
                                self[M27PlatoonUtilities.refiCurrentAction] = nil
                            end

                            M27PlatoonUtilities.RecordPlatoonUnitsByType(self)
                            M27PlatoonUtilities.RecordNearbyEnemyData(self, iEnemySearchRadius)
                            if bDebugMessages == true then LOG(sFunctionRef..': iNearbyEnemies='..self[M27PlatoonUtilities.refiEnemiesInRange]) end
                            M27PlatoonUtilities.UpdatePlatoonActionForNearbyEnemies(self)
                            if self[M27PlatoonUtilities.refiCurrentAction] == nil then
                                if bDebugMessages == true then LOG(sFunctionRef..': Action after updating for nearby enemies is nil, checking for nearby mexes') end
                                --M27PlatoonUtilities.DetermineActionForNearbyReclaim(self)
                                --if self[M27PlatoonUtilities.refiCurrentAction] == nil then
                                --Check if we have enough mexes built already (below gets only those that have completed construction)
                                if bDebugMessages == true then LOG(sFunctionRef..' current no. of mexes='..aiBrain:GetCurrentUnits(categories.MASSEXTRACTION * categories.STRUCTURE)..'; will look for nearby mexes if <=2') end
                                if aiBrain:GetCurrentUnits(categories.MASSEXTRACTION * categories.STRUCTURE) <= 2 then
                                    M27PlatoonUtilities.DetermineActionForNearbyMex(self)
                                end
                                --end
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Action after updating for nearby enemies='..self[M27PlatoonUtilities.refiCurrentAction]) end
                            end
                            local bProcessPlatoonAction = false
                            if not(self[M27PlatoonUtilities.refiCurrentAction] == nil) then
                                --Is this the same as the prev action?
                                if self[M27PlatoonUtilities.refiCurrentAction] == iPrevAction then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Current action='..self[M27PlatoonUtilities.refiCurrentAction]..'; this is the same as the previous action; checking if still want to process it; iSameActionCount='..iSameActionCount) end
                                    --Is the ACU busy?
                                    if not(eng:IsUnitState('Reclaiming') == true or eng:IsUnitState('Guarding') == true or eng:IsUnitState('Building') == true) then
                                        --ACU might be moving into position or attacking enemies
                                        iSameActionCount = iSameActionCount + 1
                                        if iSameActionCount > 25 then --refresh every 2.5 seconds
                                            if bDebugMessages == true then LOG(sFunctionRef..': iSameActionCount='..iSameActionCount..'; will refresh action') end
                                            bProcessPlatoonAction = true
                                        else
                                            if self[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionBuildMex then
                                                if M27Utilities.GetDistanceBetweenPositions(eng:GetPosition(), self[M27PlatoonUtilities.reftNearbyMexToBuildOn]) <= iBuildDistance then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Engineer is close to target mex so will refresh action') end
                                                    bProcessPlatoonAction = true
                                                end
                                            end
                                        end
                                    else
                                        --Dont refresh as busy
                                    end
                                else --Dif action to before so want to process
                                    iSameActionCount = 0
                                    bProcessPlatoonAction = true
                                    if bDebugMessages == true then LOG(sFunctionRef..': Current action dif to prev action so will refresh') end
                                end
                                if bProcessPlatoonAction == true then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Platoon action recorded and is '..self[M27PlatoonUtilities.refiCurrentAction]) end
                                    iSameActionCount = 0
                                    bIssuedTemporaryAction = true
                                    M27PlatoonUtilities.ProcessPlatoonAction(self)
                                    --M27PlatoonUtilities.MoveNearHydroAndAssistEngiBuilder(self, oGuardedUnit, tNearestHydro)
                                end
                            end
                            if bIssuedTemporaryAction == true then
                                if self[M27PlatoonUtilities.refiCurrentAction] == nil then
                                    --Previously issued a temporary action but dont have one now; reissue guard command
                                    bIssuedTemporaryAction = false
                                    M27Utilities.IssueTrackedClearCommands(self:GetPlatoonUnits())
                                    M27PlatoonUtilities.MoveNearHydroAndAssistEngiBuilder(self, oGuardedUnit, tNearestHydro)
                                end
                            end

                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                            WaitTicks(3) --Dont set too low or ACU may not do anything
                            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                            if eng.PlatoonHandle and eng.PlatoonHandle.GetPlan and eng.PlatoonHandle:GetPlan() == sPlatoonName then
                                --Proceed
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Platoon plan has changed so disbanding this platoon') end
                                break
                            end
                        end
                    else
                        if bDebugMessages == true then LOG('AssistHydroAI - oGuardedUnit is nil so aborting') end
                    end
                else
                    --Something has gone wrong, e.g. unit has died
                end
                if bDebugMessages == true then
                    if bDebugMessages == true then LOG('AssistHydroAI - End of script, clearing commands and disbanding platoon') end
                    --HaveGreaterThanUnitsWithCategory(aiBrain, numReq, category, idleReq)
                    if bDebugMessages == true then LOG('Number of hydrocarbon units='..M27Utilities.GetNumberOfUnits(aiBrain, categories.STRUCTURE * categories.HYDROCARBON)) end
                end
            else
                if bDebugMessages == true then LOG('AssistHydroAI: Aborting and clearing engi actions and disbanding platoon as already constructed hydro') end
            end
            --disband platoon:
            if self and aiBrain and aiBrain.PlatoonExists and aiBrain:PlatoonExists(self) then
                if bPlatoonNameDisplay == true then M27PlatoonUtilities.UpdatePlatoonName(self, 'No custom platoon AI') end
                --M27Utilities.IssueTrackedClearCommands({eng})
                --self:Stop()
                if bDebugMessages == true then LOG('M27AssistHydroEngi: About to disband platoon') end
                self:PlatoonDisband()
            end
        end
    end,


    M27EngiAssister = function(self)
        --NOTE: REDUNDANT AI LOGIC - Now have separate engineer logic to handle this
        --Intended as low priority function for ACU and spare engis to help any engis building near it in the base, unless engi is building a mex
        --will keep searching for engi that is building something nearby; once located will assist the engi and cancel the platoon
        --if no ACU in platoon, then will attack-move to home base if no nearby units
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        local sFunctionRef = 'M27EngiAssister'
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        local bPlatoonNameDisplay = false
        if M27Config.M27ShowUnitNames == true then bPlatoonNameDisplay = true end
        local sPlatoonName = 'M27EngiAssister'
        M27Utilities.ErrorHandler('Redundant AI logic '..sPlatoonName..' still being used')

        local tFriendlyEngis = {}
        local tBuildingEngis
        local iBuildingEngis
        local iNearestBuilderDistance
        local iClosestBuilderIndex
        local iCurBuilderDistance
        local tACUCurPosition = {}
        local tTargetCurPosition = {}
        local bACUIsBusy = false
        local oBeingBuilt
        local bACUInPlatoon = false
        if bDebugMessages == true then LOG(sPlatoonName..': Start of platoon') end
        local aiBrain = self:GetBrain()
        local tOwnUnits = self:GetPlatoonUnits()
        local oFirstUnit
        local iArmyStartPos = aiBrain.M27StartPositionNumber
        for iCurUnit, oUnit in tOwnUnits do
            if not(oUnit.Dead) then oFirstUnit = oUnit break end
        end
        for iCurUnit, oUnit in tOwnUnits do
            if not(oUnit.Dead) then
                if M27Utilities.IsACU(oUnit) then bACUInPlatoon = true break end
            end
        end
        bACUIsBusy = not(M27Logic.IsUnitIdle(oFirstUnit, false, true))
        if bDebugMessages == true then LOG(sPlatoonName..': bACUInPlatoon='..tostring(bACUInPlatoon)..'; start of platoon before loop; bACUIsBusy='..tostring(bACUIsBusy)) end
        if bACUIsBusy == false then if bPlatoonNameDisplay == true then M27PlatoonUtilities.UpdatePlatoonName(self, sPlatoonName) end
        else
            if bDebugMessages == true then LOG(sPlatoonName..': bACUInPlatoon='..tostring(bACUInPlatoon)..': ACU is busy - aborting platoon') end
        end
        local iCount = 0
        while bACUIsBusy == false do
            iCount = iCount + 1
            if iCount > 100 then M27Utilities.ErrorHandler('Infinite loop 3') break end
            if bDebugMessages == true then LOG(sPlatoonName..': bACUInPlatoon='..tostring(bACUInPlatoon)..': Starting while loop - looking for nearby engis building. bACUIsBusy='..tostring(bACUIsBusy)) end
            --Locate nearest engineer that is building something:
            tBuildingEngis = {}
            iNearestBuilderDistance = 1000000
            iClosestBuilderIndex = nil
            iBuildingEngis = 0
            tFriendlyEngis = aiBrain:GetListOfUnits(categories.ENGINEER * categories.BUILTBYTIER3FACTORY, false, true)
            --Check if any of these are building something
            if tFriendlyEngis then
                if bDebugMessages == true then LOG(sPlatoonName..': bACUInPlatoon='..tostring(bACUInPlatoon)..': Found nearby engis, seeing if any are building') end
                tACUCurPosition = self:GetPlatoonPosition()
                for iUnit, oEngi in tFriendlyEngis do
                    if oEngi:IsUnitState('Building') then
                        if bDebugMessages == true then LOG(sPlatoonName..': bACUInPlatoon='..tostring(bACUInPlatoon)..'Found engi that is building, iUnit='..iUnit) end
                        --Is the engi building something other than a T1 Mex (where it doesn't need assistance)?
                        oBeingBuilt = oEngi:GetFocusUnit()
                        if oBeingBuilt == nil then if bDebugMessages == true then LOG(sPlatoonName..': bACUInPlatoon='..tostring(bACUInPlatoon)..'Engi is building but oBeingBuilt is nil') end --sometimes this is the case so presumably engineer is 'building' when it's about to build but hasn't actually started yet?
                        else
                            if EntityCategoryContains(categories.TECH1*categories.MASSEXTRACTION, oBeingBuilt.UnitId) == false then
                                if bDebugMessages == true then LOG(sPlatoonName..': bACUInPlatoon='..tostring(bACUInPlatoon)..'iUnit='..iUnit..'; Engi isnt building a T1 Mex') end
                                --Engi is building something; work out if ACU can path to the unit being built, and (if so) how close it is to the ACU
                                tTargetCurPosition = oBeingBuilt:GetPosition() --(want the unit being built so can prioritise buildings the ACU can assist without moving, if there are any)
                                --Can the ACU get there?
                                if M27MapInfo.InSameSegmentGroup(oFirstUnit, tTargetCurPosition) == true then
                                    if bDebugMessages == true then LOG(sPlatoonName..': : bACUInPlatoon='..tostring(bACUInPlatoon)..'iUnit='..iUnit..'; ACU can path to the building being built') end
                                    iCurBuilderDistance = M27Utilities.GetDistanceBetweenPositions(tACUCurPosition, oEngi:GetPosition())
                                    --Is this relatively close to the ACU?
                                    if bDebugMessages == true then LOG(sPlatoonName..': : bACUInPlatoon='..tostring(bACUInPlatoon)..'iUnit='..iUnit..'; iCurBuilderDistance='..iCurBuilderDistance..'; iNearestBuilderDistance='..iNearestBuilderDistance) end
                                    if iCurBuilderDistance <= 50 then
                                        --Check if closer than any builder have found so far:
                                        if iCurBuilderDistance < iNearestBuilderDistance then
                                            iClosestBuilderIndex = iUnit
                                            iNearestBuilderDistance = iCurBuilderDistance
                                        end
                                    end
                                else
                                    if bDebugMessages == true then LOG(sPlatoonName..': bACUInPlatoon='..tostring(bACUInPlatoon)..'iUnit='..iUnit..'; ACU cant path to Engi so wont assist it') end
                                end
                            end
                        end
                    end
                end
            end
            --Have we found any nearby engis that are building?
            if iClosestBuilderIndex then
                --Assist the engineer builder
                if bDebugMessages == true then LOG(sPlatoonName..': bACUInPlatoon='..tostring(bACUInPlatoon)..'Assigning guard to iClosestBuilderIndex='..iClosestBuilderIndex) end
                for iCurUnit, oUnit in tOwnUnits do
                    if not(oUnit.Dead) then
                        IssueGuard({ oUnit}, tFriendlyEngis[iClosestBuilderIndex])
                    end
                end
                if bPlatoonNameDisplay == true then M27PlatoonUtilities.UpdatePlatoonName(self, sPlatoonName..':Assisting') end
            else
                if bDebugMessages == true then LOG(sPlatoonName..': bACUInPlatoon='..tostring(bACUInPlatoon)..'No valid Engis found') end
                --If engineer only platoon then attack-move towards start
                if bACUInPlatoon == false then
                    self:AggressiveMoveToLocation(M27MapInfo.PlayerStartPoints[iArmyStartPos])
                    if bPlatoonNameDisplay == true then M27PlatoonUtilities.UpdatePlatoonName(self, sPlatoonName..':ReturningToBase') end
                else
                    --If ACU then wait slightly then disband
                    if bDebugMessages == true then LOG(sPlatoonName..': bACUInPlatoon='..tostring(bACUInPlatoon)..' Disbanding engi assister as no nearby engis to assist') end
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    WaitTicks(5)
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                    if not(M27Utilities.GetACU(aiBrain).Dead) then
                        if self and aiBrain and aiBrain.PlatoonExists and aiBrain:PlatoonExists(self) then
                            if bPlatoonNameDisplay == true then M27PlatoonUtilities.UpdatePlatoonName(self, 'No longer assisting') end
                            if bDebugMessages == true then LOG('M27EngiAssister: About to disband platoon') end
                            self:PlatoonDisband()
                        end
                    end
                end
            end

            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitTicks(5)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            if self and aiBrain and aiBrain.PlatoonExists and aiBrain:PlatoonExists(self) then
                if oFirstUnit.Dead then
                    for iCurUnit, oUnit in tOwnUnits do
                        if not(oUnit.Dead) then oFirstUnit = oUnit break end
                    end
                end
                bACUIsBusy = not(M27Logic.IsUnitIdle(oFirstUnit, false, true))
                if bDebugMessages == true then LOG(sPlatoonName..': bACUInPlatoon='..tostring(bACUInPlatoon)..';bACUIsBusy='..tostring(bACUIsBusy)) end
            end
        end
        --Unit is now busy; however when disband platoon it will reset its orders, so wait until the unit has been constructed and at least 3 seconds from when move command was given before checking if other higher priority orders
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(25)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        if self and aiBrain and aiBrain.PlatoonExists and aiBrain:PlatoonExists(self) then
            local bConstructionEnd = false
            iCount = 0
            while bConstructionEnd == false do
                iCount = iCount + 1
                if iCount > 250 then M27Utilities.ErrorHandler('Infinite loop 4') break end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitTicks(5)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                if self and aiBrain and aiBrain.PlatoonExists and aiBrain:PlatoonExists(self) then
                    if oBeingBuilt == nil then
                        bConstructionEnd = true
                    else
                        if not(oBeingBuilt == nil) then
                            if not(oBeingBuilt.Dead) then
                                if oBeingBuilt:GetFractionComplete() >= 1 then bConstructionEnd = true end
                            else
                                bConstructionEnd = true
                            end
                        else
                            bConstructionEnd = true
                        end
                    end
                    if bDebugMessages == true then LOG(sPlatoonName..': bACUInPlatoon='..tostring(bACUInPlatoon)..'; bConstructionEnd='..tostring(bConstructionEnd)) end
                else
                    break
                end
            end
            if bDebugMessages == true then LOG('M27EngiAssister: About to disband platoon') end
            if self and aiBrain and aiBrain.PlatoonExists and aiBrain:PlatoonExists(self) then self:PlatoonDisband() end
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end,--]]


    --START OF ACTUAL PLATOON CODE - we just list out every platoon here for now, long term might want to just remove use of platoon.lua entirely
    M27AttackNearestUnits = function(self)
        --Has platoon attack nearby structures and (if there are none) nearby land units forever; if no known units then will attack enemy base and then go back to our base and repeat
        M27PlatoonUtilities.PlatoonCycler(self)
    end,

    M27MexRaiderAI = function(self)
        --For small groups of tanks to patrol likely enemy mexes to kill engis and (in larger numbers) to kill mexes
        M27PlatoonUtilities.PlatoonCycler(self)
    end,

    M27LargeAttackForce = function(self)
        --Intended for large attack which will target enemy base (and run back to base if it comes across a bigger threat)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27GroundExperimental = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27DefenderAI = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27AmphibiousDefender = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27IndirectDefender = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27IndirectSpareAttacker = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27Skirmisher = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27RAS = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27EscortAI = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27IntelPathAI = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27ACUBuildOrder = function(self)
        --Intended to house main ACU logic after initial build order is done
        M27PlatoonUtilities.ACUInitialBuildOrder(self)
    end,


    M27ACUMain = function(self)
        --Intended to house main ACU logic after initial build order is done
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27ScoutAssister = function(self)
        --Scout that will follow a target and provide it with intel
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27LocationAssister = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27MAAAssister = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27MAAPatrol = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27MexLargerRaiderAI = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27CombatPatrolAI = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27MobileShield = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27MobileStealth = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27RetreatingShieldUnits = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27SuicideSquad = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    --Plateau platoons
    M27PlateauLandCombat = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27PlateauIndirect = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27PlateauMAA = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,
    M27PlateauScout = function(self)
        M27PlatoonUtilities.PlatoonCycler(self)
    end,

    --Idle platoons
    M27IdleScouts = function(self)
        M27PlatoonUtilities.PlatoonInitialSetup(self)
    end,
    M27IdleMAA = function(self)
        M27PlatoonUtilities.PlatoonInitialSetup(self)
    end,
    M27AllEngineers = function(self)
        M27PlatoonUtilities.PlatoonInitialSetup(self)
    end,
    M27AllStructures = function(self)
        M27PlatoonUtilities.PlatoonInitialSetup(self)
    end,
    M27IdleCombat = function(self)
        M27PlatoonUtilities.PlatoonInitialSetup(self)
    end,
    M27IdleIndirect = function(self)
        M27PlatoonUtilities.PlatoonInitialSetup(self)
    end,
    M27UnderConstruction = function(self)
        M27PlatoonUtilities.PlatoonInitialSetup(self)
    end,
    M27IdleAir = function(self)
        M27PlatoonUtilities.PlatoonInitialSetup(self)
    end,
    M27IdleNavy = function(self)
        M27PlatoonUtilities.PlatoonInitialSetup(self)
    end,
    M27IdleOther = function(self)
        M27PlatoonUtilities.PlatoonInitialSetup(self)
    end,

}
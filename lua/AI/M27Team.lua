---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by maudlin27.
--- DateTime: 24/07/2022 19:32
---
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27EconomyOverseer = import('/mods/M27AI/lua/AI/M27EconomyOverseer.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27EconomyOverseer = import('/mods/M27AI/lua/AI/M27EconomyOverseer.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')


tTeamData = {} --[x] is the aiBrain.M27Team number - stores certain team-wide information
reftFriendlyActiveM27Brains = 'M27TeamFriendlyM27Brains' --Stored against tTeamData[brain.M27Team], returns table of all M27 brains on the same team (including this one), with a key of the army index
iTotalTeamCount = 0 --Number o teams in the game
subrefNukeLaunchLocations = 'M27TeamNukeTargets' --stored against tTeamData[brain.M27Team], [x] is gametimeseconds, returns the location of a nuke target
refiEnemyWalls = 'M27TeamEnemyWallCount' --stored against tTeamData[brain.M27Team], returns the ntotal number of enemy wall units; used as threshold to enable engineers to start looking for wall segments to reclaim
refiTimeOfLastEnemyTeamDataUpdate = 'M27TeamEnemyLastUpdate' --as above, returns the gametimeseconds of hte last update
reftEnemyArtiToAvoid = 'M27TeamEnemyArtiToAvoid' --against tTeamData[aiBrain.M27Team], [x] is a count (so table.getn works), returns T2 arti units that has got enough mass kills to want to avoid
refiFriendlyFatboyCount = 'M27TeamFriendlyFatboys' --against tTeamData[aiBrain.M27Team], returns the number of friendly fatboys on the team
refbActiveResourceMonitor = 'M27TeamActiveResourceMonitor' --against tTeamData[aiBrain.M27Team], true if the tema has an active resource monitor
reftUnseenPD = 'M27TeamUnseenPD' --against tTeamData[aiBrain.M27Team], table of T2+ PD objects that have damaged an ally but havent been revealed yet
refbEnemyTeamHasUpgrade = 'M27TeamEnemeyHasUpgrade' --against tTeamData[aiBrain.M27Team], true if enemy has started ACU upgrade or has ACU upgrade
reftiTeamMessages = 'M27TeamMessages' --against tTeamData[aiBrain.M27Team], [x] is the message type string, returns the gametime that last sent a message of this type to the team

reftTimeOfTransportLastLocationAttempt = 'M27TeamTimeOfLastTransportAttempt' --against tTeamData[aiBrain.M27Team], returns a table with [x] being the string location ref, and the value being the game time in seconds that we last tried to land a transport there
tScoutAssignedToMexLocation = 'M27ScoutsAssignedByMex' --tTeamData[aiBrain.M27Team][this]: returns a table, with key [sLocationRef], that returns a scout object, e.g. [X1Z1] = oScout; only returns scout unit if one has been assigned to that location; used to track scouts assigned by mex

refbActiveNovaxCoordinator = 'M27TeamNovaxCoordinator'
refbActiveLandExperimentalCoordinator = 'M27TeamExperimentalCoordinator' --Used to decide actions involving multiple experimentals

refiTimeOfLastVisualUpdate = 'M27TeamLastVisualUpdate' --against tTeamData, Similar to refiTimeOfLastEnemyTeamDataUpdate


--Variables recorded elsewhere relating to team data:
--[[

M27MapInfo:
Various informatino about chokepoints, starting with the refbConsideredChokepointsForTeam variable
includes chokepoint locations, the average team and enemy team start positions for the chokepoint line, angle and distances relating to chokepoints

--]]


function UpdateTeamDataForEnemyUnits(aiBrain)
    if GetGameTimeSeconds() - (tTeamData[aiBrain.M27Team][refiTimeOfLastEnemyTeamDataUpdate] or 0) >= 9.9 then
        --Record number of wall segments
        tTeamData[aiBrain.M27Team][refiTimeOfLastEnemyTeamDataUpdate] = GetGameTimeSeconds()
        local iWallCount = 0
        for iBrain, oBrain in aiBrain[M27Overseer.toEnemyBrains] do
            iWallCount = iWallCount + oBrain:GetCurrentUnits(M27UnitInfo.refCategoryWall)
        end
        tTeamData[aiBrain.M27Team][refiEnemyWalls] = iWallCount


        --Update T2 arti for those that are no longer valid
        if M27Utilities.IsTableEmpty(tTeamData[aiBrain.M27Team][reftEnemyArtiToAvoid]) == false then
            local bUpdatedTable = true
            local iCycleCount = 0
            while bUpdatedTable do
                iCycleCount = iCycleCount + 1
                if iCycleCount >= 20 then
                    M27Utilities.ErrorHandler('Possible infinite loop for T2 arti checker')
                    break
                end
                bUpdatedTable = false
                for iUnit, oUnit in tTeamData[aiBrain.M27Team][reftEnemyArtiToAvoid] do
                    if not(M27UnitInfo.IsUnitValid(oUnit)) then
                        table.remove(tTeamData[aiBrain.M27Team][reftEnemyArtiToAvoid], iUnit)
                        bUpdatedTable = true
                        break
                    end
                end
            end
        end



        --Update count of friendly team fatboys (so can decide whether to run platoon logic relating to this)
        local iFatboyCount = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryFatboy)
        for iBrain, oBrain in aiBrain[M27Overseer.toAllyBrains] do
            if not(oBrain == aiBrain) then --redundancy, dont think this is needed
                iFatboyCount = iFatboyCount + aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryFatboy)
            end
        end
        tTeamData[aiBrain.M27Team][refiFriendlyFatboyCount] = iFatboyCount


        --Refresh table of unseen PD
        if M27Utilities.IsTableEmpty(tTeamData[aiBrain.M27Team][reftUnseenPD]) == false then
            for iUnit, oUnit in tTeamData[aiBrain.M27Team][reftUnseenPD] do
                if M27UnitInfo.IsUnitValid(oUnit) then
                    tTeamData[aiBrain.M27Team][reftUnseenPD][iUnit] = nil
                elseif M27Utilities.CanSeeUnit(aiBrain, oUnit, true) then
                    tTeamData[aiBrain.M27Team][reftUnseenPD][iUnit] = nil
                end
            end
        end

        --Record if enemy has upgraded ACU
        if not(tTeamData[aiBrain.M27Team][refbEnemyTeamHasUpgrade]) then
            local tEnemyVisibleACU = aiBrain:GetUnitsAroundPoint(categories.COMMAND, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 10000, 'Enemy')
            if M27Utilities.IsTableEmpty(tEnemyVisibleACU) == false then
                for iUnit, oUnit in tEnemyVisibleACU do
                    if oUnit:IsUnitState('Upgrading') then
                        tTeamData[aiBrain.M27Team][refbEnemyTeamHasUpgrade] = true
                        break
                    elseif M27UnitInfo.GetNumberOfUpgradesObtained(oUnit) > 0 then
                        tTeamData[aiBrain.M27Team][refbEnemyTeamHasUpgrade] = true
                    end
                end
            end

        end

    end
end

function GiveResourcesToPlayer(oBrainGiver, oBrainReceiver, iMass, iEnergy)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GiveResourcesToPlayer'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Failed attempt - simcallback:
    --[[SimCallback(
            {
                Func = "GiveResourcesToPlayer",
                Args = {
                    From = oBrainGiver:GetArmyIndex(),
                    To = oBrainReceiver:GetArmyIndex(),
                    Mass = iMass,
                    Energy = iEnergy,
                }
            }
    )--]]
    --Failed attempt: SimUtils
    --SimUtils.GiveResourcesToPlayer(oBrainGiver:GetArmyIndex(), oBrainReceiver:GetArmyIndex(), iMass, iEnergy)
    --Check we have the resources to give:
    if iMass > 0 and oBrainGiver:GetEconomyStored('MASS') >= iMass then
        --Check the person receiving has enough capacity
        if M27EconomyOverseer.GetMassStorageMaximum(oBrainReceiver) - oBrainReceiver:GetEconomyStored('MASS') >= iMass then
            oBrainReceiver:GiveResource('Mass', iMass)
            oBrainGiver:TakeResource('Mass', iMass)
            if bDebugMessages == true then LOG(sFunctionRef..': Given '..iMass..' Mass from '..oBrainGiver.Nickname..' to '..oBrainReceiver.Nickname) end

        end
    end
    if iEnergy > 0 and oBrainGiver:GetEconomyStored('ENERGY') >= iEnergy then
        if M27EconomyOverseer.GetEnergyStorageMaximum(oBrainReceiver) - oBrainReceiver:GetEconomyStored('ENERGY') >= iEnergy then
            oBrainReceiver:GiveResource('Energy', iEnergy)
            oBrainGiver:TakeResource('Energy', iEnergy)
            if bDebugMessages == true then LOG(sFunctionRef..': Given '..iEnergy..' Energy from '..oBrainGiver.Nickname..' to '..oBrainReceiver.Nickname) end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)

end

function AllocateTeamEnergyResources(iTeam, iFirstM27Brain)
    --Cycles through every team member, and for M27 team members considers giving resources to non-M27 team members

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AllocateTeamEnergyResources'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Priority for brains wanting resources:
    --M27 Power stalling (<10% energy stored, or flagged as pwoerstalling with <50% energy stored)
    --M27 Less than 5k energy stored with at least 5k storage available, with enemies near the ACU
    --M27 Less than 75% energy stored with enemies near the ACU
    --Non-M27 powerstalling

    --M27 brains to give energy if
    --Positive energy, with 90% stored - surrender higher of positive energy * 1.5 and amount that would take us to 80% stored.  Increase to 50% stored if have brains in priority 1/2 scenario and we dont have enemies near our ACU
    --ACU not in combat, or (if in combat) to only give energy equal to net energy income, and only if have >=95% stored

    local tBrainsWithEnergyAndEnergyAvailable = {}
    local tBrainsNeedingEnergyByPriority = {}
    local subrefBrain = 1
    local subrefEnergyPriority = 2
    local subrefRemainingEnergyNeeded = 3
    local subrefEnergyAvailable = 2
    local subrefRemainingEnergyToGive = 3
    local tiCountOfBrainsNeedingEnergyByPriority = {} --i.e. a count of the number of brains by priority

    local iEnergyStorageMax

    local iPriority

    for iBrain, oBrain in tTeamData[iTeam][reftFriendlyActiveM27Brains] do
        iEnergyStorageMax = M27EconomyOverseer.GetEnergyStorageMaximum(oBrain)

        if bDebugMessages == true then LOG(sFunctionRef..': Considering brain with name='..oBrain.Nickname..'; iEnergyStorageMax='..iEnergyStorageMax..'; Is M27='..tostring(oBrain.M27AI or false)..'; % stored energy='..oBrain:GetEconomyStoredRatio('ENERGY')..'; flagged as stalling energy='..tostring(oBrain[M27EconomyOverseer.refbStallingEnergy] or false)) end

        --Does ACU have enemies nearby and we are capable of overcharging?
        if M27Utilities.GetACU(oBrain).PlatoonHandle[M27PlatoonUtilities.refiEnemiesInRange] and iEnergyStorageMax >= 5000 then
            if oBrain:GetEconomyStoredRatio('ENERGY') <= 0.8 or oBrain[M27EconomyOverseer.refbStallingEnergy] then
                if oBrain:GetEconomyStoredRatio('ENERGY') < 0.8 then
                    iPriority = 2
                    table.insert(tBrainsNeedingEnergyByPriority, {[subrefBrain] = oBrain, [subrefEnergyPriority] = iPriority, [subrefRemainingEnergyNeeded] = iEnergyStorageMax * (0.8 - oBrain:GetEconomyStoredRatio('ENERGY'))})
                    tiCountOfBrainsNeedingEnergyByPriority[iPriority] = (tiCountOfBrainsNeedingEnergyByPriority[iPriority] or 0) + 1
                    if bDebugMessages == true then LOG(sFunctionRef..': Want energy as priority '..iPriority) end
                else
                    --Have lots of energy but flagged as stalling energy so dont want to give any energy or claim any
                    if bDebugMessages == true then LOG(sFunctionRef..': Dont want to give or receive energy') end
                end
            elseif oBrain:GetEconomyStoredRatio('ENERGY') >= 0.95 and oBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] > 0 and not(oBrain[M27EconomyOverseer.refbStallingEnergy]) then
                table.insert(tBrainsWithEnergyAndEnergyAvailable, {[subrefBrain] = oBrain, [subrefEnergyAvailable] = math.max(oBrain[M27EconomyOverseer.refiEnergyNetBaseIncome], oBrain:GetEconomyStored('ENERGY') * 0.02)})
                if bDebugMessages == true then LOG(sFunctionRef..': Have energy available to give') end
            else
                --Enemies near our ACU, we can overcharge them, and we dont have strong energy, so keep what energy we have for ourself
            end
        else
            --Not in combat, so can make more of our energy available
            if oBrain:GetEconomyStoredRatio('ENERGY') < 0.25 then
                if oBrain[M27EconomyOverseer.refbStallingEnergy] or oBrain:GetEconomyStoredRatio('ENERGY') <= 0.05 then
                    iPriority = 1
                else
                    iPriority = 3
                end
                table.insert(tBrainsNeedingEnergyByPriority, {[subrefBrain] = oBrain, [subrefEnergyPriority] = iPriority, [subrefRemainingEnergyNeeded] = iEnergyStorageMax * (0.25 - oBrain:GetEconomyStoredRatio('ENERGY'))})
                tiCountOfBrainsNeedingEnergyByPriority[iPriority] = (tiCountOfBrainsNeedingEnergyByPriority[iPriority] or 0) + 1
                if bDebugMessages == true then LOG(sFunctionRef..': Not in combat, want energy as priority '..iPriority) end
            else
                --Do we have enough to offer some?
                if oBrain:GetEconomyStoredRatio('ENERGY') > 0.3 and not(oBrain[M27EconomyOverseer.refbStallingEnergy]) then
                    if oBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] < 0 and oBrain:GetEconomyStoredRatio('ENERGY') >= 0.98 then
                        table.insert(tBrainsWithEnergyAndEnergyAvailable, {[subrefBrain] = oBrain, [subrefEnergyAvailable] = oBrain:GetEconomyStored('ENERGY') * 0.02})
                        if bDebugMessages == true then LOG(sFunctionRef..': Have energy available to give') end
                    elseif oBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] > 0 then
                        table.insert(tBrainsWithEnergyAndEnergyAvailable, {[subrefBrain] = oBrain, [subrefEnergyAvailable] = iEnergyStorageMax * (oBrain:GetEconomyStoredRatio('ENERGY') - 0.3)})
                        if bDebugMessages == true then LOG(sFunctionRef..': Have positive energy income so have energy avialable to give') end
                    else
                        --Dont have positive net income, and not got 100% energy, so want to keep our energy for ourself
                    end
                end
            end
        end
    end

    if bDebugMessages == true then LOG(sFunctionRef..': Finished going through M27 brains to work out who gan give and receive. Is table of energy givers empty='..tostring(M27Utilities.IsTableEmpty(tBrainsWithEnergyAndEnergyAvailable))..'; is table of brains wanting energy empty='..tostring(M27Utilities.IsTableEmpty(tBrainsNeedingEnergyByPriority))) end

    --Do we have brains capable of surrendering energy?
    if M27Utilities.IsTableEmpty(tBrainsWithEnergyAndEnergyAvailable) == false then
        --Are there any non-M27 brains that are power stalling?  Have already checked have toAllyBrains as part of the seharing monitor

        for iBrain, oBrain in tTeamData[iTeam][reftFriendlyActiveM27Brains][iFirstM27Brain][M27Overseer.toAllyBrains] do
            --Only consider non-M27 since we considered M27 above
            if not(oBrain.M27AI) then
                if oBrain:GetEconomyStoredRatio('ENERGY') < 0.1 then
                    iPriority = 4
                    table.insert(tBrainsNeedingEnergyByPriority, {[subrefBrain] = oBrain, [subrefEnergyPriority] = iPriority, [subrefRemainingEnergyNeeded] = M27EconomyOverseer.GetEnergyStorageMaximum(oBrain) * (0.15 - oBrain:GetEconomyStoredRatio('ENERGY'))})
                    tiCountOfBrainsNeedingEnergyByPriority[iPriority] = (tiCountOfBrainsNeedingEnergyByPriority[iPriority] or 0) + 1
                    if bDebugMessages == true then LOG(sFunctionRef..': Non M27 brain, Want energy as priority '..iPriority) end
                end
            end
        end

        if bDebugMessages == true then LOG(sFunctionRef..': Finished going through non-M27 brains as well to identify those needing energy. Is table of any brains needing energy empty='..tostring(M27Utilities.IsTableEmpty(tBrainsNeedingEnergyByPriority))) end

        --Do we have brains needing energy?
        if M27Utilities.IsTableEmpty(tBrainsNeedingEnergyByPriority) == false then
            --Calculate total energy available, and total energy needed
            local iTotalEnergyAvailable = 0
            local iTotalEnergyNeeded = 0
            for iTable, tTable in tBrainsWithEnergyAndEnergyAvailable do
                iTotalEnergyAvailable = iTotalEnergyAvailable + tTable[subrefEnergyAvailable]
            end
            for iTable, tTable in tBrainsNeedingEnergyByPriority do
                if bDebugMessages == true then LOG(sFunctionRef..': Energy needed for brain '..tTable[subrefBrain].Nickname..'='..tTable[subrefRemainingEnergyNeeded]..'; energy storage % for this brain='..tTable[subrefBrain]:GetEconomyStoredRatio('ENERGY')) end
                iTotalEnergyNeeded = iTotalEnergyNeeded + tTable[subrefRemainingEnergyNeeded]
            end

            local iEnergyGiftPercentage --% of energy available that we shoudl gift
            if iTotalEnergyNeeded < iTotalEnergyAvailable then
                iEnergyGiftPercentage = iTotalEnergyNeeded / iTotalEnergyAvailable
            else
                iEnergyGiftPercentage = 1
            end

            for iTable, tTable in tBrainsWithEnergyAndEnergyAvailable do
                tTable[subrefRemainingEnergyToGive] = iEnergyGiftPercentage * tTable[subrefEnergyAvailable]
            end

            local iEnergyToGive

            if bDebugMessages == true then LOG(sFunctionRef..': iEnergyGiftPercentage='..iEnergyGiftPercentage..'; iTotalEnergyNeeded='..iTotalEnergyNeeded..'; iTotalEnergyAvailable='..iTotalEnergyAvailable) end



            --Cycle through by priority
            for iPriority, iCount in tiCountOfBrainsNeedingEnergyByPriority do
                if iCount > 0 then
                    for iClaimerTable, tClaimerTable in tBrainsNeedingEnergyByPriority do
                        if tClaimerTable[subrefRemainingEnergyNeeded] > 0 then
                            for iGiverTable, tGiverTable in tBrainsWithEnergyAndEnergyAvailable do
                                if tGiverTable[subrefRemainingEnergyToGive] > 0 then
                                    iEnergyToGive = math.min(tGiverTable[subrefRemainingEnergyToGive], tClaimerTable[subrefRemainingEnergyNeeded])
                                    tGiverTable[subrefRemainingEnergyToGive] = tGiverTable[subrefRemainingEnergyToGive] - iEnergyToGive
                                    tClaimerTable[subrefRemainingEnergyNeeded] = tClaimerTable[subrefRemainingEnergyNeeded] - iEnergyToGive
                                    GiveResourcesToPlayer(tGiverTable[subrefBrain], tClaimerTable[subrefBrain], 0, iEnergyToGive)
                                    if bDebugMessages == true then LOG(sFunctionRef..': '..tGiverTable[subrefBrain].Nickname..' has just given '..iEnergyToGive..' energy to '..tClaimerTable[subrefBrain].Nickname) end
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

function AllocateTeamMassResources(iTeam, iFirstM27Brain)
    --Cycles through every team member, and for M27 team members considers giving resources to non-M27 team members

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AllocateTeamMassResources'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    local tBrainsWithMassAndMassAvailable = {}
    local tBrainsNeedingMassByPriority = {}
    local subrefBrain = 1
    local subrefMassPriority = 2
    local subrefRemainingMassNeeded = 3
    local subrefMassAvailable = 2
    local subrefRemainingMassToGive = 3
    local tiCountOfBrainsNeedingMassByPriority = {} --i.e. a count of the number of brains by priority

    local iMassStorageMax

    local iPriority

    for iBrain, oBrain in tTeamData[iTeam][reftFriendlyActiveM27Brains] do
        if oBrain.M27IsDefeated and (not(oBrain.GetCurrentUnits) or oBrain:GetCurrentUnits(categories.ALLUNITS - categories.BENIGN) <= 1) then tTeamData[iTeam][reftFriendlyActiveM27Brains][iBrain] = nil break
        else

            iMassStorageMax = M27EconomyOverseer.GetMassStorageMaximum(oBrain)

            if bDebugMessages == true then LOG(sFunctionRef..': Considering brain with name='..oBrain.Nickname..'; iMassStorageMax='..iMassStorageMax..'; Is M27='..tostring(oBrain.M27AI or false)..'; % stored Mass='..oBrain:GetEconomyStoredRatio('MASS')..'; flagged as stalling Mass='..tostring(oBrain[M27EconomyOverseer.refbStallingMass] or false)) end

            --Do we have low mass?
            if oBrain:GetEconomyStoredRatio('MASS') < 0.05 then
                if oBrain:GetEconomyStoredRatio('MASS') < 0.01 and oBrain:GetEconomyStoredRatio('ENERGY') == 1 then
                    iPriority = 1
                else
                    iPriority = 2
                end
                table.insert(tBrainsNeedingMassByPriority, {[subrefBrain] = oBrain, [subrefMassPriority] = iPriority, [subrefRemainingMassNeeded] = iMassStorageMax * (0.05 - oBrain:GetEconomyStoredRatio('MASS'))})
                tiCountOfBrainsNeedingMassByPriority[iPriority] = (tiCountOfBrainsNeedingMassByPriority[iPriority] or 0) + 1
                if bDebugMessages == true then LOG(sFunctionRef..': Not in combat, want Mass as priority '..iPriority) end
            else
                --Do we have enough to offer some?
                if oBrain:GetEconomyStoredRatio('MASS') > 0.25 and not(oBrain[M27EconomyOverseer.refbStallingMass]) and not(M27Conditions.HaveLowMass(oBrain)) then
                    if oBrain[M27EconomyOverseer.refiMassNetBaseIncome] < 0 and oBrain:GetEconomyStoredRatio('MASS') >= 0.3 then
                        table.insert(tBrainsWithMassAndMassAvailable, {[subrefBrain] = oBrain, [subrefMassAvailable] = oBrain:GetEconomyStored('MASS') * 0.02})
                        if bDebugMessages == true then LOG(sFunctionRef..': Have Mass available to give even though have negative mass income') end
                    elseif oBrain[M27EconomyOverseer.refiMassNetBaseIncome] > 0 then
                        table.insert(tBrainsWithMassAndMassAvailable, {[subrefBrain] = oBrain, [subrefMassAvailable] = iMassStorageMax * (oBrain:GetEconomyStoredRatio('MASS') - 0.25)})
                        if bDebugMessages == true then LOG(sFunctionRef..': Have positive Mass income so have Mass avialable to give') end
                    else
                        --Dont have positive net income, and not got 100% Mass, so want to keep our Mass for ourself
                    end
                end
            end
        end
    end

    if bDebugMessages == true then LOG(sFunctionRef..': Finished going through M27 brains to work out who gan give and receive. Is table of Mass givers empty='..tostring(M27Utilities.IsTableEmpty(tBrainsWithMassAndMassAvailable))..'; is table of brains wanting Mass empty='..tostring(M27Utilities.IsTableEmpty(tBrainsNeedingMassByPriority))) end

    --Do we have brains capable of surrendering Mass?
    if M27Utilities.IsTableEmpty(tBrainsWithMassAndMassAvailable) == false then
        --Are there any non-M27 brains that are power stalling?  Have already checked have toAllyBrains as part of the seharing monitor

        for iBrain, oBrain in tTeamData[iTeam][reftFriendlyActiveM27Brains][iFirstM27Brain][M27Overseer.toAllyBrains] do
            --Only consider non-M27 since we considered M27 above
            if not(oBrain.M27AI) then
                if oBrain:GetEconomyStoredRatio('MASS') < 0.01 and oBrain:GetEconomyStoredRatio('ENERGY') == 1 then
                    iPriority = 3
                    table.insert(tBrainsNeedingMassByPriority, {[subrefBrain] = oBrain, [subrefMassPriority] = iPriority, [subrefRemainingMassNeeded] = M27EconomyOverseer.GetMassStorageMaximum(oBrain) * (0.01 - oBrain:GetEconomyStoredRatio('MASS'))})
                    tiCountOfBrainsNeedingMassByPriority[iPriority] = (tiCountOfBrainsNeedingMassByPriority[iPriority] or 0) + 1
                    if bDebugMessages == true then LOG(sFunctionRef..': Non M27 brain, Want Mass as priority '..iPriority) end
                end
            end
        end

        if bDebugMessages == true then LOG(sFunctionRef..': Finished going through non-M27 brains as well to identify those needing Mass. Is table of any brains needing Mass empty='..tostring(M27Utilities.IsTableEmpty(tBrainsNeedingMassByPriority))) end

        --Do we have brains needing Mass?
        if M27Utilities.IsTableEmpty(tBrainsNeedingMassByPriority) == false then
            --Calculate total Mass available, and total Mass needed
            local iTotalMassAvailable = 0
            local iTotalMassNeeded = 0
            for iTable, tTable in tBrainsWithMassAndMassAvailable do
                iTotalMassAvailable = iTotalMassAvailable + tTable[subrefMassAvailable]
            end
            for iTable, tTable in tBrainsNeedingMassByPriority do
                if bDebugMessages == true then LOG(sFunctionRef..': Mass needed for brain '..tTable[subrefBrain].Nickname..'='..tTable[subrefRemainingMassNeeded]..'; Mass storage % for this brain='..tTable[subrefBrain]:GetEconomyStoredRatio('MASS')) end
                iTotalMassNeeded = iTotalMassNeeded + tTable[subrefRemainingMassNeeded]
            end

            local iMassGiftPercentage --% of Mass available that we shoudl gift
            if iTotalMassNeeded < iTotalMassAvailable then
                iMassGiftPercentage = iTotalMassNeeded / iTotalMassAvailable
            else
                iMassGiftPercentage = 1
            end

            for iTable, tTable in tBrainsWithMassAndMassAvailable do
                tTable[subrefRemainingMassToGive] = iMassGiftPercentage * tTable[subrefMassAvailable]
            end

            local iMassToGive

            if bDebugMessages == true then LOG(sFunctionRef..': iMassGiftPercentage='..iMassGiftPercentage..'; iTotalMassNeeded='..iTotalMassNeeded..'; iTotalMassAvailable='..iTotalMassAvailable) end



            --Cycle through by priority
            for iPriority, iCount in tiCountOfBrainsNeedingMassByPriority do
                if iCount > 0 then
                    for iClaimerTable, tClaimerTable in tBrainsNeedingMassByPriority do
                        if tClaimerTable[subrefRemainingMassNeeded] > 0 then
                            for iGiverTable, tGiverTable in tBrainsWithMassAndMassAvailable do
                                if tGiverTable[subrefRemainingMassToGive] > 0 then
                                    iMassToGive = math.min(tGiverTable[subrefRemainingMassToGive], tClaimerTable[subrefRemainingMassNeeded])
                                    tGiverTable[subrefRemainingMassToGive] = tGiverTable[subrefRemainingMassToGive] - iMassToGive
                                    tClaimerTable[subrefRemainingMassNeeded] = tClaimerTable[subrefRemainingMassNeeded] - iMassToGive
                                    GiveResourcesToPlayer(tGiverTable[subrefBrain], tClaimerTable[subrefBrain], iMassToGive, 0)
                                    if bDebugMessages == true then LOG(sFunctionRef..': '..tGiverTable[subrefBrain].Nickname..' has just given '..iMassToGive..' Mass to '..tClaimerTable[subrefBrain].Nickname) end
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

function TeamResourceSharingMonitor(iTeam)
    --Monitors resources for AI in the team and shares resources
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'TeamResourceSharingMonitor'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, checking if already running a monitor for iTeam='..iTeam..': Is resource monitor active='..tostring(tTeamData[iTeam][refbActiveResourceMonitor] or false)..'; Is table of friendl yM27 brains for this team empty='..tostring(M27Utilities.IsTableEmpty(tTeamData[iTeam][reftFriendlyActiveM27Brains]))) end

    if not(tTeamData[iTeam][refbActiveResourceMonitor]) and M27Utilities.IsTableEmpty(tTeamData[iTeam][reftFriendlyActiveM27Brains]) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': Will flag that we ahve an active resource monitor and wait 3 minutes before starting main loop') end
        tTeamData[iTeam][refbActiveResourceMonitor] = true
        WaitSeconds(180) --Dont want to share in the first 3m
        local oFirstM27Brain
        local iFirstM27Brain
        if M27Utilities.IsTableEmpty(tTeamData[iTeam][reftFriendlyActiveM27Brains]) == false then
            for iBrain, oBrain in tTeamData[iTeam][reftFriendlyActiveM27Brains] do
                oFirstM27Brain = oBrain
                iFirstM27Brain = iBrain
                break
            end
        end

        while M27Utilities.IsTableEmpty(tTeamData[iTeam][reftFriendlyActiveM27Brains]) == false do
            if bDebugMessages == true then LOG(sFunctionRef..': Start of main loop, about to call logic to allocate resources if we have active friendly M27 brains. Does our team '..iTeam..'with a first brain with index='..iFirstM27Brain..' have an empty table of M27 brains='..tostring(M27Utilities.IsTableEmpty(tTeamData[iTeam][reftFriendlyActiveM27Brains][iFirstM27Brain][M27Overseer.toAllyBrains]))) end

            if oFirstM27Brain.M27IsDefeated then
                for iBrain, oBrain in tTeamData[iTeam][reftFriendlyActiveM27Brains] do
                    oFirstM27Brain = oBrain
                    iFirstM27Brain = iBrain
                    break
                end
            end
            
            --Do we still have teammates?
            if M27Utilities.IsTableEmpty(tTeamData[iTeam][reftFriendlyActiveM27Brains][iFirstM27Brain][M27Overseer.toAllyBrains]) then
                break
            else
                ForkThread(AllocateTeamEnergyResources, iTeam, iFirstM27Brain)
                ForkThread(AllocateTeamMassResources, iTeam, iFirstM27Brain)
                WaitSeconds(1)
            end            

        end
        tTeamData[iTeam][refbActiveResourceMonitor] = false
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function TransferUnitsToPlayer(tUnits, iArmyIndex, bCaptured)
    import('/lua/SimUtils.lua').TransferUnitsOwnership(tUnits, iArmyIndex, bCaptured)
end

function GiveAllResourcesToAllies(aiBrain)
    local iMassToGive = aiBrain:GetEconomyStored('MASS')
    local iEnergyToGive = aiBrain:GetEconomyStored('ENERGY')
    local iSpareMassStorage
    local iSpareEnergyStorage
    for iBrain, oBrain in aiBrain[M27Overseer.toAllyBrains] do
        if not(oBrain.M27IsDefeated) then
            iSpareMassStorage = 0
            iSpareEnergyStorage = 0
            if iMassToGive > 0 and aiBrain:GetEconomyStoredRatio('MASS') < 1 then
                iSpareMassStorage = M27EconomyOverseer.GetMassStorageMaximum(aiBrain) * (1 -aiBrain:GetEconomyStoredRatio('MASS'))
            end
            if iEnergyToGive > 0 and aiBrain:GetEconomyStoredRatio('ENERGY') < 1 then
                iSpareEnergyStorage = M27EconomyOverseer.GetEnergyStorageMaximum(aiBrain) * (1 -aiBrain:GetEconomyStoredRatio('ENERGY'))
            end

            if iSpareMassStorage + iSpareEnergyStorage > 0 then
                GiveResourcesToPlayer(aiBrain, oBrain, math.min(iMassToGive, iSpareMassStorage), math.min(iEnergyToGive, iSpareEnergyStorage))
            end

        end
        if iMassToGive + iEnergyToGive < 0 then break end
    end
end

function GiveResourcesToAllyDueToParagon(aiBrain)
    if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.toAllyBrains]) == false then
        --Prioritise giving to M27 brains since they have auto-resource sharing
        local oM27Ally
        local oOtherAlly
        for iBrain, oBrain in aiBrain[M27Overseer.toAllyBrains] do
            if oBrain.M27AI then
                --Check we dont have a paragon and arent overflowing mass
                if oM27Ally[M27EconomyOverseer.refiMassGrossBaseIncome] < 1000 and aiBrain:GetEconomyStoredRatio('MASS') <= 0.8 then
                    oM27Ally = oBrain
                end
            else
                if aiBrain:GetEconomyIncome('MASS') < 1000 and aiBrain:GetEconomyIncome('MASS') <= 0.8 then
                    oOtherAlly = oBrain
                end
            end
        end
        local oBrainToGiveTo
        if oM27Ally then oBrainToGiveTo = oM27Ally
        else oBrainToGiveTo = oOtherAlly
        end

        if oBrainToGiveTo then

            local tMexesToGive = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryMex, false, true)
            local tPowerToGive = {}
            if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Power + M27UnitInfo.refCategoryT2Power) > 1 then
                for iPower, oPower in aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT3Power + M27UnitInfo.refCategoryT2Power, false, true) do
                    if iPower > 1 then
                        table.insert(tPowerToGive, oPower)
                    end
                end
            end
            if M27Utilities.IsTableEmpty(tMexesToGive) == false then
                TransferUnitsToPlayer(tMexesToGive, oBrainToGiveTo:GetArmyIndex(), false)
            end
            if M27Utilities.IsTableEmpty(tPowerToGive) == false then
                TransferUnitsToPlayer(tPowerToGive, oBrainToGiveTo:GetArmyIndex(), false)
            end
        end
    end
end

function RecordUnseenPD(oPD, oUnitDamaged)
    local aiBrain = oUnitDamaged:GetAIBrain()
    --Do we have M27 brains on this team?
    if M27Utilities.IsTableEmpty(tTeamData[aiBrain.M27Team][reftFriendlyActiveM27Brains]) == false then
        --Have we already recorded?
        local bInsert = true
        if M27Utilities.IsTableEmpty(tTeamData[aiBrain.M27Team][reftUnseenPD]) then
            tTeamData[aiBrain.M27Team][reftUnseenPD] = { }
        else
            for iUnit, oUnit in tTeamData[aiBrain.M27Team][reftUnseenPD] do
                if oUnit == oPD then
                    bInsert = false
                    break
                end
            end
        end
        if bInsert then
            table.insert(tTeamData[aiBrain.M27Team][reftUnseenPD], oPD)
            oPD[M27UnitInfo.refbTreatAsVisible] = true
        end
    end
end

function RecordSegmentsThatTeamHasVisualOf(aiBrain)
    if GetGameTimeSeconds() - (tTeamData[aiBrain.M27Team][refiTimeOfLastVisualUpdate] or -1) >= 0.99 then
        local iTimeStamp = GetGameTimeSeconds()

        local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local tAirScouts = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirScout * categories.TECH1, tStartPosition, 10000, 'Ally')
        local iAirVision = 42
        for iUnit, oUnit in tAirScouts do
            if not (oUnit.Dead) then
                M27AirOverseer.UpdateSegmentsForLocationVision(aiBrain, oUnit:GetPosition(), iAirVision, iTimeStamp)
            end
        end
        local tSpyPlanes = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirScout * categories.TECH3, tStartPosition, 10000, 'Ally')
        iAirVision = 64
        for iUnit, oUnit in tSpyPlanes do
            if not (oUnit.Dead) then
                M27AirOverseer.UpdateSegmentsForLocationVision(aiBrain, oUnit:GetPosition(), iAirVision, iTimeStamp)
            end
        end

        local tAllOtherUnits = aiBrain:GetUnitsAroundPoint(categories.ALLUNITS - refCategoryAirScout - M27UnitInfo.refCategoryMex - M27UnitInfo.refCategoryHydro, tStartPosition, aiBrain[refiMaxScoutRadius], 'Ally')
        local oCurBP, iCurVision
        for iUnit, oUnit in tAllOtherUnits do
            if not (oUnit.Dead) and oUnit.GetBlueprint then
                oCurBP = oUnit:GetBlueprint()
                iCurVision = oCurBP.Intel.VisionRadius
                if iCurVision and iCurVision >= iAirSegmentSize then
                    M27AirOverseer.UpdateSegmentsForLocationVision(aiBrain, oUnit:GetPosition(), iCurVision, iTimeStamp)
                end
            end
        end
    end
end

function TeamInitialisation(iTeamRef)
    --Should have already specified friendly M27 brains and recorded an empty table for tTeamData as part of RecordAllEnemiesAndAllies
    tTeamData[iTeamRef][subrefNukeLaunchLocations] = {}
    tTeamData[iTeamRef][reftEnemyArtiToAvoid] = {}
    tTeamData[iTeamRef][reftTimeOfTransportLastLocationAttempt] = {}
    tTeamData[iTeamRef][tScoutAssignedToMexLocation] = {}
    tTeamData[iTeamRef][reftiTeamMessages] = {}
end
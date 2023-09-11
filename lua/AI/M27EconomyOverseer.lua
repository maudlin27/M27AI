--Manages building upgrades

local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27FactoryOverseer = import('/mods/M27AI/lua/AI/M27FactoryOverseer.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27PlatoonFormer = import('/mods/M27AI/lua/AI/M27PlatoonFormer.lua')
local M27Transport = import('/mods/M27AI/lua/AI/M27Transport.lua')
local M27Team = import('/mods/M27AI/lua/AI/M27Team.lua')
local M27Navy = import('/mods/M27AI/lua/AI/M27Navy.lua')


--Tracking variables:
refbWantMoreFactories = 'M27UpgraderWantMoreFactories'
refbWantForAdjacency = 'M27UnitWantForAdjacency' --Local unit variable; if true then wont reclaim unit even if obsolete

reftMassStorageLocations = 'M27UpgraderMassStorageLocations' --List of all locations where we want a mass storage to be built
reftStorageSubtableLocation = 'M27UpgraderStorageLocationSubtable'
refiStorageSubtableModDistance = 'M27UpgraderStorageModDistance'
local refbWantToUpgradeMoreBuildings = 'M27UpgraderWantToUpgradeMore'
reftUnitsToReclaim = 'M27UnitReclaimShortlist' --list of units we want engineers to reclaim
reftoCiviliansToCapture = 'M27CiviliansToCapture' --against aiBrain, table of any civilian units htat want to capture
reftMexesToCtrlK = 'M27EconomyMexesToCtrlK' --Mexes that we want to destroy to rebuild with better ones
reftT2MexesNearBase = 'M27EconomyT2MexesNearBase' --Amphib pathable near base and not upgrading; NOTE - this isnt kept up to date, instead engineer will only refresh the mexes in this if its empty; for now just used by engineer overseer but makes sense to have variable in this code
refoNearestT2MexToBase = 'M27EconomyNearestT2MexToBase' --As per t2mexesnearbase
refbWillCtrlKMex = 'M27EconomyWillCtrlKMex' --true if mex is marked for ctrl-k
refbReclaimNukes = 'M27EconomyReclaimNukes' --true if want to add nuke silos to the reclaim shortlist
reftoTMLToReclaim = 'M27EconomyTMLToReclaim' --any TML flagged to be reclaimed
refbWillReclaimUnit = 'M27EconomyWillReclaimUnit' --Set against a unit, true if will reclaim it

reftUpgrading = 'M27UpgraderUpgrading' --[x] is the nth building upgrading, returns the object upgrading
refiPausedUpgradeCount = 'M27UpgraderPausedCount' --Number of units where have paused the upgrade
refiFailedUpgradeUnitSearchCount = 'M27FailedUpgradeUnitSearchCount' --against aiBrain, tracks number of times in a row we have fialed to find our desired category to upgrade
local refbUpgradePaused = 'M27UpgraderUpgradePaused' --flags on particular unit if upgrade has been paused or not

local refiEnergyStoredLastCycle = 'M27EnergyStoredLastCycle'

--ECONOMY VARIABLES - below 4 are to track values based on base production, ignoring reclaim. Provide per tick values so 10% of per second)
refiGrossEnergyBaseIncome = 'M27EnergyGrossIncome'
refiNetEnergyBaseIncome = 'M27EnergyNetIncome'
refiGrossMassBaseIncome = 'M27MassGrossIncome'
refiNetMassBaseIncome = 'M27MassNetIncome'

refbBehindOnEco = 'M27EconomyBehindOnEco' --against aiBrain, true if we think we are behind on eco

refiMexesUpgrading = 'M27EconomyMexesUpgrading'
refiMexesAvailableForUpgrade = 'M27EconomyMexesAvailableToUpgrade'
reftActiveHQUpgrades = 'M27EconomyHQActiveUpgrades'

refbStallingEnergy = 'M27EconomyStallingEnergy'
refiGrossEnergyWhenStalled = 'M27EconomyGrossEnergyWhenStalled' --Energy per tick
refbStallingMass = 'M27EconomyStallingMass'
refiLastEnergyStall = 'M27EconomyLastEnergyStall' --Game time in seconds of last power stall
refbJustBuiltLotsOfPower = 'M27EconomyJustBuiltLotsPower' --true if we have just built a lot of power (so we are less likely to build more in the short period after)
reftPausedUnits = 'M27EconomyPausedUnits'
iSpecialHQCategory = 'M27EconomyFactoryHQ' --Used as a way of choosing to pause HQ

refiMexPointsNearBase = 'M27EconomyMexPointsNearBase'


--Other variables:
local refCategoryLandFactory = M27UnitInfo.refCategoryLandFactory
local refCategoryAirFactory = M27UnitInfo.refCategoryAirFactory
local refCategoryT1Mex = M27UnitInfo.refCategoryT1Mex
local refCategoryT2Mex = M27UnitInfo.refCategoryT2Mex
local refCategoryT3Mex = M27UnitInfo.refCategoryT3Mex
local refCategoryMex = M27UnitInfo.refCategoryMex
local refCategoryHydro = M27UnitInfo.refCategoryHydro
local refCategoryT1Power = M27UnitInfo.refCategoryT1Power
local refCategoryT2Power = M27UnitInfo.refCategoryT2Power
local refCategoryT3Power = M27UnitInfo.refCategoryT3Power

local reftMexOnOurSideOfMap = 'M27MexOnOurSideOfMap'
local refbPauseForPowerStall = 'M27PauseForPowerStall'

function GetMexCountOnOurSideOfMap(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetMexCountOnOurSideOfMap'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iCount = 0
    if aiBrain[reftMexOnOurSideOfMap] then
        iCount = table.getn(aiBrain[reftMexOnOurSideOfMap])
    end
    if iCount == 0 then
        --Update/refresh the count:
        aiBrain[reftMexOnOurSideOfMap] = {}
        local tOurStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local tEnemyStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)

        local iSegmentX, iSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tOurStartPosition)
        local sPathing = M27UnitInfo.GetUnitPathingType(M27Utilities.GetACU(aiBrain))
        if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then
            sPathing = M27UnitInfo.refPathingTypeLand
        end
        local iSegmentGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iSegmentX, iSegmentZ)
        local iCurDistanceToStart
        local iCurDistanceToEnemy


        --tMexByPathingAndGrouping = {} --Stores position of each mex based on the segment that it's part of; [a][b][x,y,z]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [x,y,z] = Mex position
        if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing]) == false then
            if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup]) == false then
                for iMex, tMexLocation in M27MapInfo.tMexByPathingAndGrouping[sPathing][iSegmentGroup] do
                    iCurDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tOurStartPosition, tMexLocation)
                    iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tEnemyStartPosition, tMexLocation)
                    if iCurDistanceToStart <= iCurDistanceToEnemy then
                        iCount = iCount + 1
                        aiBrain[reftMexOnOurSideOfMap][iCount] = tMexLocation
                    end
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Mexes on our side=' .. iCount)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iCount
end

function GetCivilianCaptureTargets(aiBrain, tiCivilianBrainIndex, toCivilianBrains)
    --Assumes is run at start of game and civilians have temporarily been set to be our ally, with tiCivilianBrainIndex being a table of civilian brains temporarily set as our allies
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetCivilianCaptureTargets'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if M27Utilities.IsTableEmpty(tiCivilianBrainIndex) == false then

        aiBrain[reftoCiviliansToCapture] = {}
        local iSearchRange = math.min(300, math.max(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.4, 175, math.min(225, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.5)))
        local iCategoriesOfInterest = M27UnitInfo.refCategoryLandCombat * categories.RECLAIMABLE - categories.TECH1
        local tUnitsOfInterest = aiBrain:GetUnitsAroundPoint(iCategoriesOfInterest, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iSearchRange, 'Ally')
        local sPathing = M27UnitInfo.refPathingTypeAmphibious
        local iPlateauWanted = M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        if bDebugMessages == true then LOG(sFunctionRef..': Running for aiBrain='..aiBrain.Nickname..' at gametime='..GetGameTimeSeconds()..'; Is table of tUnitsOfInterest empty='..tostring(M27Utilities.IsTableEmpty(tUnitsOfInterest))..'; iPlateauWanted='..iPlateauWanted..'; tiCivilianBrainIndex='..reprs(tiCivilianBrainIndex)..'; aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]..'; iSearchRange='..iSearchRange) end
        if M27Utilities.IsTableEmpty(tUnitsOfInterest) then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitTicks(10)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            for iBrain, oBrain in toCivilianBrains do
                local tCivilianUnits = oBrain:GetListOfUnits(iCategoriesOfInterest, false, true)
                if M27Utilities.IsTableEmpty(tCivilianUnits) == false then
                    for iUnit, oUnit in tCivilianUnits do
                        table.insert(tUnitsOfInterest, oUnit)
                    end
                end
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Is tUnitsOfInterest empty after checking getlist of units='..tostring(M27Utilities.IsTableEmpty(tUnitsOfInterest))) end
        --toCivilianBrains
        if M27Utilities.IsTableEmpty(tUnitsOfInterest) == false then
            local iCurPlateau, bIsCivilianUnit, iCurUnitIndex
            for iUnit, oUnit in tUnitsOfInterest do
                --Is it in the same plateua?
                iCurPlateau = M27MapInfo.GetSegmentGroupOfLocation(sPathing, oUnit:GetPosition())
                if bDebugMessages == true then LOG(sFunctionRef..': Considering civilian unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iCurPlateau='..(iCurPlateau or 'nil')..'; iPlateauWanted='..iPlateauWanted..'; Dist to our base='..M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; Mod dist='..M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition())) end
                if iCurPlateau == iPlateauWanted then
                    --Is it one of the civilian brains we temporarily moved to be our ally?
                    bIsCivilianUnit = false
                    iCurUnitIndex = oUnit:GetAIBrain():GetArmyIndex()
                    for iEntry, iBrainIndex in tiCivilianBrainIndex do
                        if iBrainIndex == iCurUnitIndex then bIsCivilianUnit = true break end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': bIsCivilianUnit='..tostring(bIsCivilianUnit)) end
                    if bIsCivilianUnit then
                        local tNearbyThreats = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryPD + M27UnitInfo.refCategoryFixedT2Arti, oUnit:GetPosition(), 140, 'Enemy')
                        if M27Utilities.IsTableEmpty(tNearbyThreats) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Adding unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to the table of civilians to capture; unit brain='..(oUnit:GetAIBrain().Nickname or 'nil')..'; is civilian='..tostring(M27Logic.IsCivilianBrain(oUnit:GetAIBrain()))) end
                            table.insert(aiBrain[reftoCiviliansToCapture], oUnit)
                        end
                    end
                end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, is aiBrain[reftoCiviliansToCapture] empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftoCiviliansToCapture]))) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetUnitReclaimTargets(aiBrain)
    --Prepares a shortlist of targets we want engineers to reclaim
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetUnitReclaimTargets'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    aiBrain[reftUnitsToReclaim] = {}

    --Dont have any power in shortlist if we are powerstalling (or have in last 10s) or dont have >=99% energy stored
    if not (aiBrain[refbStallingEnergy]) and aiBrain:GetEconomyStoredRatio('ENERGY') > 0.99 and GetGameTimeSeconds() - aiBrain[refiLastEnergyStall] >= 10 then

        --NOTE: DONT ADD conditions above here as T2 power assumes the table is empty

        --Add any old power to the table - T1 and T2 if we have lots of power and T3
        local iT3Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Power)
        if iT3Power >= 1 and aiBrain[refiGrossEnergyBaseIncome] >= 500 and aiBrain[refiNetEnergyBaseIncome] >= 50 then
            local oTeammateWantingPower
            if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.toAllyBrains]) == false then
                for iBrain, oBrain in aiBrain[M27Overseer.toAllyBrains] do
                    if not(oBrain == aiBrain) then
                        if oBrain.M27AI then
                            if oBrain[refiGrossEnergyBaseIncome] <= 250 then
                                oTeammateWantingPower = oBrain
                                break
                            end
                        elseif oBrain:GetEconomyIncome('ENERGY') <= 250 then
                            oTeammateWantingPower = oBrain
                            break
                        end
                    end
                end
            end
            local iCurTransferCount = 0


            --Add all t2 power (unless using it for T3 arti)
            for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT2Power, false, true) do
                if not (oUnit[refbWantForAdjacency]) then
                    oUnit[refbWantForAdjacency] = M27Conditions.IsBuildingWantedForAdjacency(oUnit)
                    if not (oUnit[refbWantForAdjacency]) then
                        if oTeammateWantingPower and oUnit:GetFractionComplete() == 1 then
                            --if not(oUnit[M27UnitInfo.refoOriginalBrainOwner]) then oUnit[M27UnitInfo.refoOriginalBrainOwner] = aiBrain end
                            --Above is already done via .oldowner field on a unit, and the above doesnt work since a new unit gets created to transfer a unit to a player
                            M27Team.TransferUnitsToPlayer({oUnit}, oTeammateWantingPower:GetArmyIndex(), false)
                            iCurTransferCount = iCurTransferCount + 1
                            if iCurTransferCount >= 1 then break end --Only transfer 1 T2 PGen at a time
                        else
                            if oUnit.oldowner and not(oUnit.oldowner == aiBrain:GetArmyIndex()) then
                                M27Team.TransferUnitsToPlayer({oUnit}, oUnit.oldowner, false)
                                break --Dont want to transfer more than 1 at at time due to risk of power stalling
                            else
                                table.insert(aiBrain[reftUnitsToReclaim], oUnit)
                            end
                        end
                    end
                end
            end
        end

        --Reclaim T1 power if we have T2+ power and enough gross income

        --v44 - removed some of the tests so only considers if flagged that its wanted for adjacency (i.e. for T3 arti)
        if bDebugMessages == true then LOG(sFunctionRef..': Considering T1 power. iT3Power='..iT3Power..'; T2 power='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Power)..'; Gross energy income='..aiBrain[refiGrossEnergyBaseIncome]..'; Net energy income='..aiBrain[refiNetEnergyBaseIncome]) end
        if (iT3Power >= 1 or aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Power) >= 2) and aiBrain[refiGrossEnergyBaseIncome] >= 110 and aiBrain[refiNetEnergyBaseIncome] > 10 then --and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryFixedT2Arti) <= 0 then
            --Do we have a teammate who needs more energy?
            local oTeammateWantingPower
            if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.toAllyBrains]) == false then
                for iBrain, oBrain in aiBrain[M27Overseer.toAllyBrains] do
                    if not(oBrain == aiBrain) then
                        --Is it an M27 brain with <=75 energy and no T2 PGen?
                        if oBrain.M27AI then
                            if oBrain[refiGrossEnergyBaseIncome] <= 75 and oBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Power + M27UnitInfo.refCategoryT3Power) == 0 then
                                oTeammateWantingPower = oBrain
                                break
                            end
                            --Only give to non-M27 teammate in exceptional circumstances (i.e. where they're power stalling and have low gross energy)
                        elseif oBrain:GetEconomyIncome('ENERGY') <= 75 and oBrain:GetEconomyStoredRatio('ENERGY') <= 0.1 then
                            oTeammateWantingPower = oBrain
                            break
                        end
                    end
                end
            end
            local iCurTransferCount = 0
            if bDebugMessages == true then
                if oTeammateWantingPower == nil then LOG(sFunctionRef..': Dont have a teammate wanting power')
                else
                    LOG(sFunctionRef..': Have teammate wanting power='..oTeammateWantingPower.Nickname)
                end
            end

            --All T1 power
            for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT1Power, false, true) do
                --Check not near to an air factory - will do slightly larger than actual radius needed to be prudent
                --tNearbyAdjacencyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirFactory, oUnit:GetPosition(), 6, 'Ally')
                --if M27Utilities.IsTableEmpty(tNearbyAdjacencyUnits) == true then
                --if not (oUnit[refbWantForAdjacency]) then
                oUnit[refbWantForAdjacency] = M27Conditions.IsBuildingWantedForAdjacency(oUnit)
                if bDebugMessages == true then LOG(sFunctionRef..': Considering T1 Pgen unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Wanted for adjacency='..tostring(oUnit[refbWantForAdjacency] or false)) end
                if not (oUnit[refbWantForAdjacency]) then
                    if oTeammateWantingPower and oUnit:GetFractionComplete() == 1 then
                        --if not(oUnit[M27UnitInfo.refoOriginalBrainOwner]) then oUnit[M27UnitInfo.refoOriginalBrainOwner] = aiBrain end
                        --Above is covered by .oldowner - need to use .oldowner as the old unit gets removed and a new unit created in its place

                        if bDebugMessages == true then LOG(sFunctionRef..': About to gift PGen '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to player '..oTeammateWantingPower.Nickname..'; PGen position='..repru(oUnit:GetPosition())) end
                        M27Team.TransferUnitsToPlayer({oUnit}, oTeammateWantingPower:GetArmyIndex(), false)
                        iCurTransferCount = iCurTransferCount + 1
                        if iCurTransferCount >= 3 then break end
                    else
                        if bDebugMessages == true then
                            if oUnit.oldowner then LOG(sFunctionRef..': PGen original owner index='..oUnit.oldowner)
                            else
                                LOG(sFunctionRef..': Pgen doesnt have an original owner. M27TempTestIndex='..(oUnit['M27TempTestIndex'] or 'nil')..'; PGen position='..repru(oUnit:GetPosition()))
                            end
                        end
                        if oUnit.oldowner and not(oUnit.oldowner == aiBrain:GetArmyIndex()) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Transferring unit back to original owner who has index='..oUnit.oldowner) end
                            M27Team.TransferUnitsToPlayer({oUnit}, oUnit.oldowner, false)
                            break --Dont want to transfer more than 1 at at time due to risk of power stalling
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Will add unit to list of units to be reclaimed') end
                            table.insert(aiBrain[reftUnitsToReclaim], oUnit)
                        end
                    end
                    --end
                    --end
                end
            end
        end
    end

    local tT3Radar = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT3Radar, false, true)
    local tT2Radar = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT2Radar, false, true)
    local bRadarInsideOtherRadarRange
    local bRadarIsConstructed
    --T2 radar if in range of T3
    if M27Utilities.IsTableEmpty(tT3Radar) == false and M27Utilities.IsTableEmpty(tT2Radar) == false then
        --Check T3 radar is constructed
        bRadarIsConstructed = false
        for iUnit, oUnit in tT3Radar do
            if oUnit:GetFractionComplete() == 1 then
                bRadarIsConstructed = true
                break
            end
        end
        if bRadarIsConstructed then
            for iUnit, oUnit in tT2Radar do
                bRadarInsideOtherRadarRange = false
                for iT3Radar, oT3Radar in tT3Radar do
                    if M27Utilities.GetDistanceBetweenPositions(oT3Radar:GetPosition(), oUnit:GetPosition()) <= (oT3Radar:GetBlueprint().Intel.RadarRadius - oUnit:GetBlueprint().Intel.RadarRadius) then
                        bRadarInsideOtherRadarRange = true
                        break
                    end
                end
                if bRadarInsideOtherRadarRange then
                    table.insert(aiBrain[reftUnitsToReclaim], oUnit)
                end
            end
        end
    end

    --T1 radar
    if M27Utilities.IsTableEmpty(tT3Radar) == false or M27Utilities.IsTableEmpty(tT2Radar) == false then
        bRadarIsConstructed = false
        if M27Utilities.IsTableEmpty(tT3Radar) == false then
            for iUnit, oUnit in tT3Radar do
                if oUnit:GetFractionComplete() == 1 then
                    bRadarIsConstructed = true
                    break
                end
            end
        end
        if not (bRadarIsConstructed) and M27Utilities.IsTableEmpty(tT2Radar) == false then
            for iUnit, oUnit in tT2Radar do
                if oUnit:GetFractionComplete() == 1 then
                    bRadarIsConstructed = true
                    break
                end
            end
        end
        if bRadarIsConstructed then
            for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT1Radar, false, true) do
                bRadarInsideOtherRadarRange = false
                if M27Utilities.IsTableEmpty(tT3Radar) == false then
                    for iT3Radar, oT3Radar in tT3Radar do
                        if M27Utilities.GetDistanceBetweenPositions(oT3Radar:GetPosition(), oUnit:GetPosition()) <= (oT3Radar:GetBlueprint().Intel.RadarRadius - oUnit:GetBlueprint().Intel.RadarRadius) then
                            bRadarInsideOtherRadarRange = true
                            break
                        end
                    end
                end
                if bRadarInsideOtherRadarRange == false and M27Utilities.IsTableEmpty(tT2Radar) == false then
                    for iT2Radar, oT2Radar in tT2Radar do
                        if M27Utilities.GetDistanceBetweenPositions(oT2Radar:GetPosition(), oUnit:GetPosition()) <= (oT2Radar:GetBlueprint().Intel.RadarRadius - oUnit:GetBlueprint().Intel.RadarRadius) then
                            bRadarInsideOtherRadarRange = true
                            break
                        end
                    end
                end
                if bRadarInsideOtherRadarRange then
                    table.insert(aiBrain[reftUnitsToReclaim], oUnit)
                end
            end
        end
    end

    --T1 Sonar
    if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT1Sonar) > 0 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Sonar + M27UnitInfo.refCategoryT3Sonar) > 0 then
        --Do we have T1 sonar within range of T2 sonar?
        local tT1Sonar
        for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT2Sonar + M27UnitInfo.refCategoryT3Sonar, false, true) do
            if oUnit:GetFractionComplete() == 1 then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; .Intel=' .. repru((oUnit:GetBlueprint().Intel or { 'nil' })) .. '; .Intel.SonarRadius=' .. (oUnit:GetBlueprint().Intel.SonarRadius or 'nil'))
                end
                tT1Sonar = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT1Sonar, oUnit:GetPosition(), oUnit:GetBlueprint().Intel.SonarRadius - 115, 'Ally')
                if M27Utilities.IsTableEmpty(tT1Sonar) == false then
                    for iT1Sonar, oT1Sonar in tT1Sonar do
                        if oT1Sonar:GetAIBrain() == aiBrain then
                            table.insert(aiBrain[reftUnitsToReclaim], oT1Sonar)
                        end
                    end
                end
            end
        end
    end

    --Civilian buildings on our side of the map that can be pathed to amphibiously with no enemy units nearby
    local tCivilianBuildings = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 500, 'Neutral')
    local iBasePathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
    if M27Utilities.IsTableEmpty(tCivilianBuildings) == false then
        for iUnit, oUnit in tCivilianBuildings do
            --Are we closer to our base than enemy?
            if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) then
                --Can we path here with an amphibious unit?
                if iBasePathingGroup == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition()) then
                    table.insert(aiBrain[reftUnitsToReclaim], oUnit)
                end
            end

        end
    end

    --Nukes
    if aiBrain[refbReclaimNukes] then
        for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategorySML - categories.EXPERIMENTAL, false, false) do
            table.insert(aiBrain[reftUnitsToReclaim], oUnit)
        end
    end

    --TML - units are added to a table to be reclaimed when we decide we no longer want to use them
    if M27Utilities.IsTableEmpty(aiBrain[reftoTMLToReclaim]) == false then
        for iUnit, oUnit in aiBrain[reftoTMLToReclaim] do
            if M27UnitInfo.IsUnitValid(oUnit) then
                table.insert(aiBrain[reftUnitsToReclaim], oUnit)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Adding TML unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' to list of units to reclaim')
                end
            end
        end
    end

    --TMD if no longer up against TML and have low mass - v32 decided to disable as too risky as may not see enemy tml and doesnt give that much mass
    --[[if aiBrain[M27Overseer.refbEnemyTMLSightedBefore] and M27Utilities.IsTableEmpty(M27Overseer.reftEnemyTML) and M27Conditions.HaveLowMass(aiBrain) then
        for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategoryTMD, false, false) do
            table.insert(aiBrain[reftUnitsToReclaim], oUnit)
        end
    end--]]

    --Flag any units set to be reclaimed
    if M27Utilities.IsTableEmpty(aiBrain[reftUnitsToReclaim]) == false then
        for iUnit, oUnit in aiBrain[reftUnitsToReclaim] do
            oUnit[refbWillReclaimUnit] = true
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetMassStorageTargets(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetMassStorageTargets'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Goes through all mexes and records any available locations for mass storage
    local iDistanceModForEachAdjacentMex = -60
    local iDistanceModForEachT1AdjacentMex = -35 --NOTE: If changing this value, then also update engineer overseer's threshold for ignoring a location based on difference in distance
    local iDistanceModForTech2 = 120
    local sLocationRef, tCurLocation
    local tAdjustedPosition = {}

    local tAllMexes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryMex, false, true)
    local tAllT2PlusMexes = EntityCategoryFilterDown(M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryT3Mex, tAllMexes)
    local tAllT1Mexes = EntityCategoryFilterDown(M27UnitInfo.refCategoryT1Mex, tAllMexes)
    aiBrain[reftMassStorageLocations] = {}
    local tStorageLocationsForTech1 = {} --[sLocationRef]; true if the location is by a t1 mex
    local iValidCount = 0
    local tPositionAdjustments = {
        { -2, 0 },
        { 2, 0 },
        { 0, -2 },
        { 0, 2 },
    }

    for iT1Mex, oT1Mex in tAllT1Mexes do
        for _, tModPosition in tPositionAdjustments do
            tCurLocation = oT1Mex:GetPosition()
            tAdjustedPosition = { tCurLocation[1] + tModPosition[1], GetSurfaceHeight(tCurLocation[1] + tModPosition[1], tCurLocation[3] + tModPosition[2]), tCurLocation[3] + tModPosition[2] }
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Storage by T1Mex: tCurLocation=' .. repru(tCurLocation) .. '; tModPosition=' .. repru(tModPosition) .. '; adjusted position=' .. repru(tAdjustedPosition))
            end
            sLocationRef = M27Utilities.ConvertLocationToReference(tAdjustedPosition)
            if tStorageLocationsForTech1[sLocationRef] == nil then
                tStorageLocationsForTech1[sLocationRef] = true
            end
        end
    end

    local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    local iDistanceFromOurBase, iCurPositionTechAdjust, iCurPositionStartedConstructionAdjust, iCurPositionAdjacencyAdjust
    local sStorageBP = 'ueb1106'
    local iMexesNearStart = table.getn(M27MapInfo.tResourceNearStart[aiBrain.M27StartPositionNumber][1])
    if M27Utilities.IsTableEmpty(tAllT2PlusMexes) == false then
        --Only want to consider storage if have already upgraded easy T1 mexes to T2
        local iMinSingleMexForStorage = math.min(iMexesNearStart, 6)
        local iMinDoubleMexForStorage = math.min(iMexesNearStart, 2)
        local bOnlyConsiderDoubleOrT3 = false
        local iMexesForStorage = table.getn(tAllT2PlusMexes)
        local tStorageAtLocation
        local iStorageRadius = 1
        local bStorageFinishedConstruction
        local iCurAdjustedDistance
        if iMexesForStorage >= iMinDoubleMexForStorage then
            if iMexesForStorage < iMinSingleMexForStorage then
                bOnlyConsiderDoubleOrT3 = true
            end
            for iMex, oMex in tAllT2PlusMexes do
                if not (oMex.Dead) and oMex:GetFractionComplete() >= 1 then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Considering mex with unique ref=' .. oMex.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oMex))
                    end
                    tCurLocation = oMex:GetPosition()
                    for _, tModPosition in tPositionAdjustments do
                        tAdjustedPosition = { tCurLocation[1] + tModPosition[1], GetSurfaceHeight(tCurLocation[1] + tModPosition[1], tCurLocation[3] + tModPosition[2]), tCurLocation[3] + tModPosition[2] }
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': tCurLocation=' .. repru(tCurLocation) .. '; tModPosition=' .. repru(tModPosition) .. '; adjusted position=' .. repru(tAdjustedPosition))
                        end
                        sLocationRef = M27Utilities.ConvertLocationToReference(tAdjustedPosition)
                        if M27EngineerOverseer.CanBuildAtLocation(aiBrain, sStorageBP, tAdjustedPosition, M27EngineerOverseer.refActionBuildMassStorage, false) then
                            --if aiBrain:CanBuildStructureAt(sStorageBP, tAdjustedPosition) or (aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][M27EngineerOverseer.refActionBuildMassStorage]) == false) then
                            --Check the building hasnt finished construction
                            bStorageFinishedConstruction = false
                            if not (aiBrain:CanBuildStructureAt(sStorageBP, tAdjustedPosition)) then
                                tStorageAtLocation = GetUnitsInRect(Rect(tAdjustedPosition[1] - iStorageRadius, tAdjustedPosition[3] - iStorageRadius, tAdjustedPosition[1] + iStorageRadius, tAdjustedPosition[3] + iStorageRadius))
                                if M27Utilities.IsTableEmpty(tStorageAtLocation) == false then
                                    tStorageAtLocation = EntityCategoryFilterDown(M27UnitInfo.refCategoryMassStorage, tStorageAtLocation)
                                    if M27Utilities.IsTableEmpty(tStorageAtLocation) == false then
                                        for iUnit, oUnit in tStorageAtLocation do
                                            if oUnit:GetFractionComplete() >= 1 then
                                                bStorageFinishedConstruction = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                            if bStorageFinishedConstruction == false then

                                --sLocationRef = M27Utilities.ConvertLocationToReference(tAdjustedPosition)
                                iDistanceFromOurBase = M27Utilities.GetDistanceBetweenPositions(tAdjustedPosition, tStartPosition)
                                iCurPositionTechAdjust = 0
                                iCurPositionStartedConstructionAdjust = 0
                                iCurPositionAdjacencyAdjust = 0
                                --Reduce distance by 100 if already have it assigned to an engineer (as want to continue existing structure)
                                if aiBrain:CanBuildStructureAt(sStorageBP, tAdjustedPosition) == false then
                                    iCurPositionStartedConstructionAdjust = -100
                                end
                                if EntityCategoryContains(categories.TECH2, oMex.UnitId) then
                                    iCurPositionTechAdjust = iDistanceModForTech2
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Can build storage at the position, so will record; sLocationRef=' .. sLocationRef .. '; iDistanceFromOurBase=' .. iDistanceFromOurBase .. '; iCurPositionTechAdjust=' .. iCurPositionTechAdjust .. '; iDistanceModForEachAdjacentMex=' .. iDistanceModForEachAdjacentMex)
                                end
                                if aiBrain[reftMassStorageLocations][sLocationRef] then
                                    iCurPositionAdjacencyAdjust = iDistanceModForEachAdjacentMex
                                    --[[--Already have a position, so choose the lower of it reduced by 50, or the current value reduced by 50
                                    if bDebugMessages == true then LOG(sFunctionRef..': Already have a position so will reduce current distance by iDistanceModForEachAdjacentMex='..iDistanceModForEachAdjacentMex..'; current distance='..aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance]) end

                                    aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance] = math.min(aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance] + iDistanceModForEachAdjacentMex, iDistanceFromOurBase + iCurPositionTechAdjust + iDistanceModForEachAdjacentMex + iCurPositionStartedConstructionAdjust)
                                    if bDebugMessages == true then LOG(sFunctionRef..': Distance after modification='..aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance]) end--]]
                                elseif tStorageLocationsForTech1[sLocationRef] then
                                    iCurPositionAdjacencyAdjust = iDistanceModForEachT1AdjacentMex
                                end
                                iCurAdjustedDistance = iDistanceFromOurBase + iCurPositionTechAdjust + iCurPositionAdjacencyAdjust + iCurPositionStartedConstructionAdjust
                                if aiBrain[reftMassStorageLocations][sLocationRef] then
                                    aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance] = math.min(iCurAdjustedDistance, aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance] + iCurPositionAdjacencyAdjust)
                                else
                                    aiBrain[reftMassStorageLocations][sLocationRef] = {}
                                    aiBrain[reftMassStorageLocations][sLocationRef][refiStorageSubtableModDistance] = iCurAdjustedDistance
                                    aiBrain[reftMassStorageLocations][sLocationRef][reftStorageSubtableLocation] = tAdjustedPosition
                                end
                            end
                        else
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Cant build mass storage at this location')
                                M27Utilities.DrawLocation(tAdjustedPosition, nil, 3, 200)
                            end
                        end
                    end
                end
            end
            --Now go through again and remove entries that are too far away so that we're not getting storage when we still have t1 nearby mexes to upgrade
            if bOnlyConsiderDoubleOrT3 and M27Utilities.IsTableEmpty(aiBrain[reftMassStorageLocations]) == false then
                local iMaxDistance = iDistanceModForTech2 - 1
                for iEntry, tSubtable in aiBrain[reftMassStorageLocations] do
                    if tSubtable[refiStorageSubtableModDistance] > iMaxDistance then
                        aiBrain[reftMassStorageLocations][sLocationRef] = nil
                    end
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Storage locations=' .. repru(aiBrain[reftMassStorageLocations]))
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end



function RefreshT2MexesNearBase(aiBrain)
    --Updates list of T2 mexes that are near to base and pathable by amphibious units, and arent upgrading, along with the varaible with the nearest one to our base
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RefreshT2MexesNearBase'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    aiBrain[reftT2MexesNearBase] = {}
    aiBrain[reftMexesToCtrlK] = {} --Not ideal that reset here, but for now hopefully the scenario where we order an engineer to ctrl-K a mex, and then change our mind about wanting to do that and it leads to the mex being upgraded is low?
    local iT2MexCount = 0
    local iT2NearBaseCount = 0
    local tAllT2Mexes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT2Mex, false, true)
    local iCurDistToBase
    local iMinDistToBase = 10000
    local iBasePathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
    aiBrain[refoNearestT2MexToBase] = nil
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Is tAllT2Mexes empty=' .. tostring(M27Utilities.IsTableEmpty(tAllT2Mexes)))
    end
    if M27Utilities.IsTableEmpty(tAllT2Mexes) == false then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Size of tAllT2Mexes=' .. table.getn(tAllT2Mexes))
        end
        for iMex, oMex in tAllT2Mexes do
            if M27UnitInfo.IsUnitValid(oMex) and oMex:GetFractionComplete() == 1 then
                iT2MexCount = iT2MexCount + 1
                tAllT2Mexes[iT2MexCount] = oMex
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Considering mex with position=' .. repru(oMex:GetPosition()))
                    LOG('Player start position=' .. repru(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]))
                    LOG('VDist2 between these positions=' .. VDist2(oMex:GetPosition()[1], oMex:GetPosition()[3], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]))
                end

                iCurDistToBase = M27Utilities.GetDistanceBetweenPositions(oMex:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Considering mex ' .. oMex.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oMex) .. '; iCurDistanceToBase=' .. iCurDistToBase)
                end
                if iCurDistToBase <= 80 then
                    --Ignore mexes which are upgrading
                    if not (oMex:IsUnitState('Upgrading') or (oMex.GetWorkProgress and oMex:GetWorkProgress() < 1 and oMex:GetWorkProgress() > 0.01)) then
                        --Mex must be in same pathing group
                        if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oMex:GetPosition()) == iBasePathingGroup then
                            iT2NearBaseCount = iT2NearBaseCount + 1
                            aiBrain[reftT2MexesNearBase][iT2NearBaseCount] = oMex
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Added mex to table of T2 mexes near base, iT2NearBaseCount=' .. iT2NearBaseCount)
                            end
                            if iCurDistToBase < iMinDistToBase then
                                aiBrain[refoNearestT2MexToBase] = oMex
                                iMinDistToBase = iCurDistToBase
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Mex is the current closest to base')
                                end
                            end
                        elseif bDebugMessages == true then
                            LOG(sFunctionRef .. ': Mex isnt in same pathing group')
                        end
                    elseif bDebugMessages == true then
                        LOG(sFunctionRef .. ': Mex is upgrading or workprogress<1')
                    end
                end
            elseif bDebugMessages == true then
                LOG(sFunctionRef .. ': Mex isnt valid')
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, iUnitCategory, bIgnoreT2SupportFactories)
    --Doesnt factor in if a unit is paused
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iUpgradingCount = 0
    local iAvailableToUpgradeCount = 0
    local tAllUnits = aiBrain:GetListOfUnits(iUnitCategory, false, true)
    local oUnitBP
    local bAreAlreadyUpgradingToHQ = false
    local iHighestTech = 1
    local iHighestFactoryBeingUpgraded = 0
    local iCurTech
    local iIgnoredSupportCategory

    if bIgnoreT2SupportFactories then
        iIgnoredSupportCategory = categories.SUPPORTFACTORY * categories.TECH2
    end

    for iUnit, oUnit in tAllUnits do
        if not (oUnit.Dead) and oUnit.GetFractionComplete and oUnit:GetFractionComplete() == 1 then
            if not (iIgnoredSupportCategory and EntityCategoryContains(iIgnoredSupportCategory, oUnit.UnitId)) then
                iCurTech = M27UnitInfo.GetUnitTechLevel(oUnit)
                if iCurTech > iHighestTech then
                    iHighestTech = iCurTech
                end
                if oUnit:IsUnitState('Upgrading') then
                    iUpgradingCount = iUpgradingCount + 1
                    if iCurTech > iHighestFactoryBeingUpgraded then
                        iHighestFactoryBeingUpgraded = iCurTech
                    end
                else
                    if M27Conditions.SafeToUpgradeUnit(oUnit) and not (oUnit[refbWillCtrlKMex]) then
                        iAvailableToUpgradeCount = iAvailableToUpgradeCount + 1
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': iUnit in tAllUnits=' .. iUnit .. '; iAvailableToUpgradeCount=' .. iAvailableToUpgradeCount .. '; Have unit available to upgrading whose unit state isnt upgrading.  UnitId=' .. oUnit.UnitId .. '; Unit State=' .. M27Logic.GetUnitState(oUnit) .. ': Upgradesto=' .. (oUnitBP.General.UpgradesTo or 'nil'))
                        end
                    end
                end
            end
        end
    end
    if iHighestFactoryBeingUpgraded >= iHighestTech then
        bAreAlreadyUpgradingToHQ = true
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code, iUpgradingCount=' .. iUpgradingCount .. '; iAvailableToUpgradeCount=' .. iAvailableToUpgradeCount)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iUpgradingCount, iAvailableToUpgradeCount, bAreAlreadyUpgradingToHQ
end


function TrackHQUpgrade(oUnitUpgradingToHQ)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'TrackHQUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local aiBrain = oUnitUpgradingToHQ:GetAIBrain()
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code for unit ' .. oUnitUpgradingToHQ.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnitUpgradingToHQ) .. '; Game time=' .. GetGameTimeSeconds() .. '; is the table of units upgrading to HQ empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])))
    end


    --Check not already in the table
    local bAlreadyRecorded = false
    if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
        for iHQ, oHQ in aiBrain[reftActiveHQUpgrades] do
            if oHQ == oUnitUpgradingToHQ then
                bAlreadyRecorded = true
                break
            end
        end
    end

    if not (bAlreadyRecorded) then
        table.insert(aiBrain[reftActiveHQUpgrades], oUnitUpgradingToHQ)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Added unit to table of active HQ upgrades; is table empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])))
        end
    elseif bDebugMessages == true then
        LOG(sFunctionRef .. ': Already recorded unit in the table of active HQ upgrades so wont add')
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Finished checking if already recorded unit, bAlreadyRecorded=' .. tostring(bAlreadyRecorded) .. '; Size of activeHQUpgrades=' .. table.getn(aiBrain[reftActiveHQUpgrades]))
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicks(10)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    while M27UnitInfo.IsUnitValid(oUnitUpgradingToHQ) do
        if not (oUnitUpgradingToHQ.GetWorkProgress) or oUnitUpgradingToHQ:GetWorkProgress() == 1 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Unit ' .. oUnitUpgradingToHQ.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnitUpgradingToHQ) .. ' either has no work progress or it is 1')
            end
            break
        else
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Unit ' .. oUnitUpgradingToHQ.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnitUpgradingToHQ) .. ' hasnt finished upgrade so will continue to monitor.  Work progress=' .. oUnitUpgradingToHQ:GetWorkProgress())
            end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitTicks(1)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        end
    end

    --Remove from table of upgrading HQs
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Unit has finished upgrading, so will remove from the list of active HQ upgrades; size of table before removal=' .. table.getn(aiBrain[reftActiveHQUpgrades]) .. '; is table empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])) .. '; Game time=' .. GetGameTimeSeconds())
    end
    local oHQ
    if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
        for iHQ = table.getn(aiBrain[reftActiveHQUpgrades]), 1, -1 do
            oHQ = aiBrain[reftActiveHQUpgrades][iHQ]
            if not (M27UnitInfo.IsUnitValid(oHQ)) then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Removing unit from table of active HQ upgrades as it is no longer valid')
                end
                table.remove(aiBrain[reftActiveHQUpgrades], iHQ)
                --[[else
                    if not(oUnitUpgradingToHQ:IsUnitState('Upgrading')) and (not(oUnitUpgradingToHQ.GetWorkProgress) or oUnitUpgradingToHQ:GetWorkProgress() == 1) then
                        table.remove(aiBrain[reftActiveHQUpgrades], iHQ)
                    end--]]
            end
        end
    end
    --Update our highest factory tech
    M27Overseer.UpdateHighestFactoryTechTracker(aiBrain)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Finished removal from the table and calling the UpdateHighestFactoryTechTracker, is table empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])))
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpgradeUnit(oUnitToUpgrade, bUpdateUpgradeTracker, bDontUpdateHQTracker)
    --Work out the upgrade ID wanted; if bUpdateUpgradeTracker is true then records upgrade against unit's aiBrain
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpgradeUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if EntityCategoryContains(M27UnitInfo.refCategoryLandFactory, oUnitToUpgrade.UnitId) then bDebugMessages = true end
    --if oUnitToUpgrade.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade) == 'urb01012' then bDebugMessages = true end

    --Do we have any HQs of the same factory type of a higher tech level?
    local sUpgradeID = M27UnitInfo.GetUnitUpgradeBlueprint(oUnitToUpgrade, true) --If not a factory or dont recognise the faction then just returns the normal unit ID
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, sUpgradeID='..(sUpgradeID or 'nil')..'; bUpdateUpgradeTracker='..tostring((bUpdateUpgradeTracker or false))..'; bDontUpdateHQTracker='..tostring(bDontUpdateHQTracker or false)) end
    --local oUnitBP = oUnitToUpgrade:GetBlueprint()
    --local iFactoryTechLevel = GetUnitTechLevel(oUnitBP.BlueprintId)

    --GetUnitUpgradeBlueprint(oFactoryToUpgrade, bGetSupportFactory)


    --local sUpgradeID = oUnitBP.General.UpgradesTo


    if sUpgradeID then
        local aiBrain = oUnitToUpgrade:GetAIBrain()
        if bDebugMessages == true then LOG(sFunctionRef..': About to issue ugprade to unit '..oUnitToUpgrade.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade)..'; Current state='..M27Logic.GetUnitState(oUnitToUpgrade)..'; Work progress='..(oUnitToUpgrade:GetWorkProgress() or 'nil')..'; Is unit upgrading='..tostring(oUnitToUpgrade:IsUnitState('Upgrading'))) end

        if not(oUnitToUpgrade:IsUnitState('Upgrading')) then
            local refsQueuedTransport = 'M27EconomyHaveQueuedTransport'



            --Factory specific - if work progress is <=5% then cancel so can do the upgrade
            if EntityCategoryContains(M27UnitInfo.refCategoryAllFactories, oUnitToUpgrade.UnitId) then
                if bDebugMessages == true then LOG(sFunctionRef..': Are upgrading a factory '..oUnitToUpgrade.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade)..'; work progress='..oUnitToUpgrade:GetWorkProgress()) end
                if oUnitToUpgrade.GetWorkProgress and oUnitToUpgrade:GetWorkProgress() <= 0.05 and not(oUnitToUpgrade[refsQueuedTransport]) then
                    M27Utilities.IssueTrackedClearCommands({ oUnitToUpgrade })
                    if bDebugMessages == true then LOG(sFunctionRef..': Have barely started with current construction so will cancel so can get upgrade sooner') end
                end
            end

            --Air factory upgrades - if we are upgrading from T1 to T2 and havent build a transport, and have plateaus, then want to get a transport first
            if EntityCategoryContains(M27UnitInfo.refCategoryAirFactory * categories.TECH1, oUnitToUpgrade.UnitId) and aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 1 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory * categories.TECH1) == 1 then
                M27MapInfo.UpdatePlateausToExpandTo(aiBrain)
                if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftPlateausOfInterest]) == false and M27Conditions.GetLifetimeBuildCount(aiBrain, M27UnitInfo.refCategoryTransport) == 0 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if we have already queued up transport for this unit='..tostring(oUnitToUpgrade[refsQueuedTransport] or false)) end
                    if not(oUnitToUpgrade[refsQueuedTransport]) then
                        --Havent built any transports yet so build a T1 transport before we upgrade to T2 air

                        local sTransportID = M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, M27UnitInfo.refCategoryTransport, oUnitToUpgrade)
                        if sTransportID then
                            oUnitToUpgrade[refsQueuedTransport] = true
                            IssueBuildFactory({ oUnitToUpgrade }, sTransportID, 1)
                            if bDebugMessages == true then LOG(sFunctionRef..': Will queue up a transport for factory '..oUnitToUpgrade.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade)) end
                        end
                    end
                end
            elseif EntityCategoryContains(M27UnitInfo.refCategoryLandFactory * categories.TECH2 + M27UnitInfo.refCategoryAirFactory * categories.TECH2, oUnitToUpgrade.UnitId) and aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] <= 2 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer - categories.TECH1) <= 5 then
                --About to go for T3 factory but have hardl yany engineers so queue up an extra one
                local sEngiID = M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, M27UnitInfo.refCategoryEngineer, oUnitToUpgrade)
                if sEngiID then
                    IssueBuildFactory({oUnitToUpgrade}, sEngiID, 1)
                end
                if bDebugMessages == true then LOG(sFunctionRef..': About to go to T3 on factory '..oUnitToUpgrade.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade)..' but only have '..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer - categories.TECH1)..' T2 plus engis so will queue up another engi before the upgrade. sEngiID='..(sEngiID or 'nil')) end
            end

            --Issue upgrade
            IssueUpgrade({ oUnitToUpgrade }, sUpgradeID)
        end

        --Clear any pausing of the unit
        if M27UnitInfo.IsUnitValid(oUnitToUpgrade) then
            oUnitToUpgrade:SetPaused(false)
            oUnitToUpgrade[M27UnitInfo.refbPaused] = false
        end
        if bUpdateUpgradeTracker then

            table.insert(aiBrain[reftUpgrading], oUnitToUpgrade)
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Have issued upgrade ' .. sUpgradeID .. ' to unit ' .. oUnitToUpgrade.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade) .. ' and recorded it')
            end
        end
        --Are we upgrading to a factory HQ? If so then record this as will prioritise it with spare engineers
        --oBlueprint = __blueprints[string.lower(sBlueprintID)]
        --EntityCategoryContains
        if EntityCategoryContains(M27UnitInfo.refCategoryAllFactories, sUpgradeID) then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': sUpgradeID is a factory')
            end
            if not (EntityCategoryContains(categories.SUPPORTFACTORY, sUpgradeID)) then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': sUpgradeID is not a support factory')
                end
                if not(bDontUpdateHQTracker) then
                    ForkThread(TrackHQUpgrade, oUnitToUpgrade)
                end
            end
            --T1 mexes - if start upgrading, then flag for TML protection
        elseif EntityCategoryContains(M27UnitInfo.refCategoryT1Mex, oUnitToUpgrade.UnitId) and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyTML]) == false then
            M27Logic.DetermineTMDWantedForUnits(aiBrain, { oUnitToUpgrade })
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Have just checked if oUnitToUpgrade ' .. oUnitToUpgrade.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade) .. ' needs protecting from TML; will list out all units flagged as wanting tmd')
                if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau]) then
                    LOG(sFunctionRef .. ': No units wanting TMD')
                else
                    for iPlateau, toUnits in aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau] do
                        if M27Utilities.IsTableEmpty(toUnits) == false then
                            for iUnit, oUnit in toUnits do
                                LOG(sFunctionRef .. ': ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iPlateau='..iPlateau)
                            end
                        end
                    end
                end
            end
        end

    else
        M27Utilities.ErrorHandler('Dont have a valid upgrade ID; UnitID=' .. oUnitToUpgrade.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade))
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetUnitToUpgrade(aiBrain, iUnitCategory, tStartPoint)
    --Looks for the nearest non-upgrading unit of iunitcategory to tStartPoint
    --Returns nil if cant find one
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetUnitToUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    local tAllUnits = aiBrain:GetListOfUnits(iUnitCategory, false, true)
    local oUnitToUpgrade, tCurPosition, iCurDistanceToStart, iCurDistanceToEnemy, iCurCombinedDist
    local iMaxCombinedDist = -100000
    local tOurStartPosition
    if tStartPoint then
        tOurStartPosition = tStartPoint
    else
        tOurStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    end
    --local tEnemyStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
    --local iEnemySearchRange = 60
    --local tNearbyEnemies
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': About to loop through units to find one to upgrade; size of tAllUnits=' .. table.getn(tAllUnits))
    end
    local tPotentialUnits = {}
    local iPotentialUnits = 0

    --local iDistFromOurStartToEnemy = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]
    --local iDistanceBufferToEnemy = iDistFromOurStartToEnemy * 0.15

    --First create a shortlist of units that we could upgrade: - must be closer to us than enemy base by at least 10% of distance between us and enemy; Must have defence coverage>=10% of the % between us and enemy (or have it behind our base)
    if M27Utilities.IsTableEmpty(tAllUnits) == false then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Have shortlist of potential units, size=' .. table.getn(tAllUnits))
        end
        for iUnit, oUnit in tAllUnits do
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': iUnit in tAllUnits=' .. iUnit .. '; checking if its valid')
                if M27UnitInfo.IsUnitValid(oUnit) then
                    LOG('Unit is valid, ID=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; Unit status=' .. M27Logic.GetUnitState(oUnit) .. '; GameTime=' .. GetGameTimeSeconds())
                end
            end
            if M27UnitInfo.IsUnitValid(oUnit) and M27UnitInfo.GetUnitUpgradeBlueprint(oUnit, true) and not (oUnit:IsUnitState('Upgrading')) then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Have a unit that is available for upgrading; iUnit=' .. iUnit .. '; Unit ref=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
                end
                if M27Conditions.SafeToUpgradeUnit(oUnit) and not (oUnit[refbWillCtrlKMex]) and (oUnit[M27Transport.refiAssignedPlateau] or aiBrain[M27MapInfo.refiOurBasePlateauGroup]) == aiBrain[M27MapInfo.refiOurBasePlateauGroup] then
                    iPotentialUnits = iPotentialUnits + 1
                    tPotentialUnits[iPotentialUnits] = oUnit
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Have a potential unit to upgrade, iPotentialUnits=' .. iPotentialUnits)
                    end
                end
            end
        end
        --Re-do without the safe to upgrade check and also including plateau units if we are overflowing mass
        if iPotentialUnits == 0 and M27Utilities.IsTableEmpty(tAllUnits) == false and aiBrain:GetEconomyStoredRatio('MASS') >= 0.7 and aiBrain:GetEconomyStored('MASS') >= 2000 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and not (aiBrain[refbStallingEnergy]) and aiBrain[refiNetEnergyBaseIncome] >= 10 * aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] and aiBrain[refiNetMassBaseIncome] >= 0.5 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Are overflowing mass so will redo check without checking if its safe to upgrade the mex')
            end
            for iUnit, oUnit in tAllUnits do
                if M27UnitInfo.IsUnitValid(oUnit) and not (M27UnitInfo.GetUnitUpgradeBlueprint(oUnit, true) == nil) and not (oUnit:IsUnitState('Upgrading')) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Have a unit that is available for upgrading; iUnit=' .. iUnit .. '; Unit ref=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
                    end
                    if not (oUnit[refbWillCtrlKMex]) then
                        iPotentialUnits = iPotentialUnits + 1
                        tPotentialUnits[iPotentialUnits] = oUnit
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Have a potential unit to upgrade, iPotentialUnits=' .. iPotentialUnits)
                        end
                    end
                end
            end
        end
        if iPotentialUnits > 0 then
            --FilterLocationsBasedOnDefenceCoverage(aiBrain, tLocationsToFilter, bAlsoNeedIntelCoverage, bNOTYETCODEDAlsoReturnClosest, bTableOfObjectsNotLocations)
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': About to check if we have any safe units; defence coverage=' .. aiBrain[M27Overseer.refiPercentageOutstandingThreat])
            end
            local tSafeUnits = M27EngineerOverseer.FilterLocationsBasedOnDefenceCoverage(aiBrain, tPotentialUnits, true, nil, true)
            if M27Utilities.IsTableEmpty(tSafeUnits) == false then
                local tTech1SafeUnits = EntityCategoryFilterDown(categories.TECH1, tSafeUnits)
                if M27Utilities.IsTableEmpty(tTech1SafeUnits) == false then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Have tech 1 safe units, will get the nearest one to our start')
                    end
                    --GetNearestUnit(tUnits, tCurPos, aiBrain, bHostileOnly)
                    oUnitToUpgrade = M27Utilities.GetNearestUnit(tTech1SafeUnits, tOurStartPosition, aiBrain, false)
                else
                    oUnitToUpgrade = M27Utilities.GetNearestUnit(tSafeUnits, tOurStartPosition, aiBrain, false)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': no tech 1 safe units so will just get the nearest safe unit to our start')
                    end
                end

            else
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': No safe units based on intel and defence coverage, so will only include if have at least 15% stored mass and decent economy more generally. Mass stored ratio='..aiBrain:GetEconomyStoredRatio('MASS')..'; Energy stored ratio='..aiBrain:GetEconomyStoredRatio('ENERGY'))
                end
                if aiBrain:GetEconomyStoredRatio('MASS') >= 0.15 and aiBrain:GetEconomyStored('MASS') >= 400 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and not (aiBrain[refbStallingEnergy]) and aiBrain[refiNetEnergyBaseIncome] >= 10 * aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] and aiBrain[refiNetMassBaseIncome] >= 0.5 then
                    oUnitToUpgrade = M27Utilities.GetNearestUnit(tPotentialUnits, tOurStartPosition, aiBrain, false)
                end
            end
        end
    else
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Dont have any units of the desired category')
        end
    end

    if oUnitToUpgrade and EntityCategoryContains(M27UnitInfo.refCategoryMex, oUnitToUpgrade.UnitId) and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyTML]) == false then
        aiBrain[M27PlatoonFormer.refbUsingMobileShieldsForPlatoons] = true
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oUnitToUpgrade
end

function DecideWhatToUpgrade(aiBrain, iMaxToBeUpgrading)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DecideWhatToUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if aiBrain:GetArmyIndex() == 1 and aiBrain:GetCurrentUnits(refCategoryT2Mex) >= 1 then bDebugMessages = true end
    --if GetGameTimeSeconds() >= 600 then bDebugMessages = true end



    --iMexesUpgrading, iMexesAvailableForUpgrade = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryT1Mex + refCategoryT2Mex, true)
    local iT1Mexes = aiBrain:GetCurrentUnits(refCategoryT1Mex)
    local iT2Mexes = aiBrain:GetCurrentUnits(refCategoryT2Mex)
    local iT3Mexes = aiBrain:GetCurrentUnits(refCategoryT3Mex)
    local bIgnoreT2LandSupport = false
    local bIgnoreT2AirSupport = false

    if aiBrain[M27Overseer.refiOurHighestLandFactoryTech] < 3 then
        if aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 1 and aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.SUPPORTFACTORY) > 0 then
            bIgnoreT2LandSupport = true
        elseif aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.SUPPORTFACTORY * categories.TECH3) > 0 then
            bIgnoreT2LandSupport = true
        end
    end
    if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 then
        if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 1 and aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.SUPPORTFACTORY) > 0 then
            bIgnoreT2AirSupport = true
        elseif aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.SUPPORTFACTORY * categories.TECH3) > 0 then
            bIgnoreT2AirSupport = true
        end
    end

    local iLandFactoryUpgrading, iLandFactoryAvailable, bAlreadyUpgradingLandHQ = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryLandFactory, bIgnoreT2LandSupport)
    local iAirFactoryUpgrading, iAirFactoryAvailable, bAlreadyUpgradingAirHQ = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryAirFactory, bIgnoreT2AirSupport)
    --Double check air factory HQ upgrade due to potential bug
    if bAlreadyUpgradingAirHQ == false and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
        for iUnit, oUnit in aiBrain[reftActiveHQUpgrades] do
            if EntityCategoryContains(refCategoryAirFactory, oUnit.UnitId) then
                bAlreadyUpgradingAirHQ = true
                break
            end
        end
    end

    local iT1LandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.TECH1)
    local iT2LandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.TECH2)
    local iT3LandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.TECH3)
    local iT1AirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.TECH1)
    local iT2AirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.TECH2)
    local iT3AirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.TECH3)
    local iT2PlusHQs = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllHQFactories - categories.TECH1)

    local iCategoryToUpgrade

    local iEngisOfHighestTechLevel = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * M27UnitInfo.ConvertTechLevelToCategory(aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]))

    --Override for everything - if enemy navy detected then prioritise T2 air factory as the next upgrade if dont have one/upgrading
    if bDebugMessages == true then LOG(sFunctionRef..': Considering if want priority air fac. iAirFactoryAvailable='..iAirFactoryAvailable..'; iAirFactoryUpgrading='..iAirFactoryUpgrading..'; iT2AirFactories+iT3AirFactories='..(iT2AirFactories + iT3AirFactories)..'; aiBrain[refiGrossMassBaseIncome]='..aiBrain[refiGrossMassBaseIncome]..'; aiBrain[refiGrossEnergyBaseIncome]='..aiBrain[refiGrossEnergyBaseIncome]) end
    if iAirFactoryAvailable > 0 and iAirFactoryUpgrading == 0 and iT2AirFactories + iT3AirFactories == 0 and aiBrain[refiGrossMassBaseIncome] >= 1.4 and aiBrain[refiGrossEnergyBaseIncome] >= 22 then
        --Does enemy have naval threat in a pond that is of danger to us?
        if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond]) == false then
            for iPond, tEnemyUnits in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond] do
                if bDebugMessages == true then LOG(sFunctionRef..': Considering iPond='..iPond..'; is table of enemy units empty for this='..tostring(M27Utilities.IsTableEmpty(tEnemyUnits))..'; Pond thraet to us='..(aiBrain[M27Navy.reftiPondThreatToUs][iPond] or 'nil')) end
                --How much of a threat is this pond to us?
                if (aiBrain[M27Navy.reftiPondThreatToUs][iPond] or 0) >= 2 then
                    if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                        local tNavalUnits = EntityCategoryFilterDown(categories.NAVAL * categories.MOBILE + M27UnitInfo.refCategoryNavalFactory, tEnemyUnits)
                        if M27Utilities.IsTableEmpty(tNavalUnits) == false then
                            iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
                            if bDebugMessages == true then LOG(sFunctionRef..': Priority air fac upgrade due to enemy naval threat') end
                            break
                        end
                    end
                end
            end
        end
    end
    local bAlreadyUpgradingEnough = false
    if not(iCategoryToUpgrade) then
        if iMaxToBeUpgrading <= (iLandFactoryUpgrading + aiBrain[refiMexesUpgrading] + iAirFactoryUpgrading) then
            bAlreadyUpgradingEnough = true
        end

        --Special logic for upgrading HQs that takes priority
        local bGetT2FactoryHQ = false
        if not(bAlreadyUpgradingLandHQ) and iLandFactoryAvailable > 0 and iLandFactoryUpgrading == 0 then
            bGetT2FactoryHQ = M27Conditions.DoWeWantPriorityT2LandFactoryHQ(aiBrain, iLandFactoryAvailable)
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Is table of active HQ upgrades empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])) .. '; Highest land fac=' .. aiBrain[M27Overseer.refiOurHighestLandFactoryTech] .. '; highest air fac=' .. aiBrain[M27Overseer.refiOurHighestAirFactoryTech] .. '; T1,2,3 land fac=' .. iT1LandFactories .. '-' .. iT2LandFactories .. '-' .. iT3LandFactories .. '; T1-2-3 air facs=' .. iT1AirFactories .. '-' .. iT2AirFactories .. '-' .. iT3AirFactories..'; iEngisOfHighestTechLevel='..iEngisOfHighestTechLevel..'; iT2PlusHQs='..iT2PlusHQs)
        end
        if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) and (iEngisOfHighestTechLevel >= 2 or (aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] < 3 and iT3AirFactories + iT3LandFactories > 0)) then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': No active HQ upgrades so will see if we have lost our HQ and need a new one first. aiBrain[M27Overseer.refiOurHighestLandFactoryTech]=' .. aiBrain[M27Overseer.refiOurHighestLandFactoryTech] .. '; aiBrain[M27Overseer.refiOurHighestLandFactoryTech]=' .. aiBrain[M27Overseer.refiOurHighestLandFactoryTech] .. '; iT2LandFactories=' .. iT2LandFactories .. '; iT3LandFactories=' .. iT3LandFactories)
            end
            if aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 1 and (iT2LandFactories + iT3LandFactories) > 0 then
                --Have lower tech level than we have in factories (e.g. our HQ was destroyed)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Only have T1 land factory tech available, but have T2 and T3 factories so assuming we lost our HQ')
                end
                if iT1LandFactories > 0 then
                    iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1
                end
            elseif aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 2 and iT3LandFactories > 0 then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Only have T2 land factory tech available, but have T3 factories so assuming we lost our HQ')
                end
                local iT2LandHQs = aiBrain:GetCurrentUnits(refCategoryLandFactory * categories.TECH2 - categories.SUPPORTFACTORY)
                if iT2LandHQs > 0 then
                    iCategoryToUpgrade = refCategoryLandFactory * categories.TECH2 - categories.SUPPORTFACTORY
                elseif iT1LandFactories > 0 then
                    iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1
                end
            elseif aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 1 and (iT2AirFactories + iT3AirFactories) > 0 then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Only have T1 Air factory tech available, but have T2 and T3 factories so assuming we lost our HQ')
                end
                if iT1AirFactories > 0 then
                    iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
                end
            elseif aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 2 and iT3AirFactories > 0 then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Only have T2 Air factory tech available, but have T3 factories so assuming we lost our HQ')
                end
                local iT2AirHQs = aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.TECH2 - categories.SUPPORTFACTORY)
                if iT2AirHQs > 0 then
                    iCategoryToUpgrade = refCategoryAirFactory * categories.TECH2 - categories.SUPPORTFACTORY
                elseif iT1AirFactories > 0 then
                    iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
                end
            end
            -- if have factories of a type that are higher than our recorded highest tech level, it suggests we have lost our HQ and need to get a new one

            --Special logic - upgrade HQ if we have air or land below our highest tech and have 4+ T3 mexes
            if not (iCategoryToUpgrade) then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': NO category to upgrade yet, will decide if we want to get an HQ upgrade')
                end
                if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) and aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 and (aiBrain[M27Overseer.refiOurHighestLandFactoryTech] < 3 and iLandFactoryAvailable > 0) or (aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 and iAirFactoryAvailable > 0) and (iT3Mexes >= 4 or (aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 and iAirFactoryAvailable > 0 and aiBrain[refiGrossEnergyBaseIncome] >= 500 and aiBrain[refiGrossMassBaseIncome] >= 4)) then
                    --Want to ugprade either land or air
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Want to upgrade an air or land factory HQ as its below our highest tech level')
                    end
                    if aiBrain[M27Overseer.refiOurHighestLandFactoryTech] < aiBrain[M27Overseer.refiOurHighestAirFactoryTech] and iLandFactoryAvailable > 0 then
                        --Want a land fac - do we want to upgrade t2, or t1?
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Will upgrade a land factory')
                        end
                        if iT2LandFactories > 0 then
                            iCategoryToUpgrade = refCategoryLandFactory * categories.TECH2
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Will upgrade a T2 land factory')
                            end
                        else
                            iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Will upgrade a T1 land factory')
                            end
                        end
                    elseif iAirFactoryAvailable > 0 then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Will upgrade an air factory')
                        end
                        if iT2AirFactories > 0 then
                            iCategoryToUpgrade = refCategoryAirFactory * categories.TECH2
                        else
                            iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
                        end
                    end
                    --Get Air HQ upgrade at same time as land HQ if we have loads of resources and no nearby enemies
                elseif M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false and aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 and iAirFactoryAvailable > 0 then
                    local bAirFacUpgrading = false
                    for iUnit, oUnit in aiBrain[reftActiveHQUpgrades] do
                        if EntityCategoryContains(M27UnitInfo.refCategoryAirFactory, oUnit.UnitId) then
                            bAirFacUpgrading = true
                            break
                        end
                    end
                    if not (bAirFacUpgrading) then
                        --Enough resources to support T3 air?
                        if aiBrain[refiGrossEnergyBaseIncome] >= 500 and aiBrain[refiNetEnergyBaseIncome] >= 100 and aiBrain[refiGrossMassBaseIncome] >= 15 and aiBrain[refiNetMassBaseIncome] >= 1 and ((aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 1 and (iT1AirFactories >= 2 or aiBrain[M27Overseer.refiModDistFromStartNearestThreat] >= 75)) or (aiBrain:GetEconomyStored('MASS') >= 2000 and (aiBrain[M27Overseer.refiModDistFromStartNearestThreat] >= 150 or (iT1AirFactories + iT2AirFactories >= 4 and aiBrain[M27Overseer.refiModDistFromStartNearestThreat] >= 75)))) then
                            if iT2AirFactories > 0 then
                                iCategoryToUpgrade = refCategoryAirFactory * categories.TECH2
                            else
                                iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
                            end
                        elseif iT2AirFactories == 0 and aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 2 and aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 1 and iT1AirFactories >= 2 and aiBrain[refiNetEnergyBaseIncome] >= 25 and aiBrain[refiGrossMassBaseIncome] >= 6 and aiBrain[refiNetMassBaseIncome] >= 0.3 and aiBrain[refiGrossEnergyBaseIncome] >= 125 then
                            iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
                        end
                    end
                end
            elseif bDebugMessages == true then
                LOG(sFunctionRef .. ': Have HQ category to upgrade after checking if our factory level is higher than what is recorded suggesting we have lost our HQ')
            end
        else
            --Dont have enough engis of cur tech level so want to keep factory before upgrading further; however want to get land fac to T2 if it is at T1 and we have T2 air, in case air is focused on something else
            if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) and iEngisOfHighestTechLevel < 3 and aiBrain[refiGrossMassBaseIncome] >= 8 and iT2AirFactories > 0 and aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 2 and iT2LandFactories == 0 and iT1LandFactories > 0 then
                if bDebugMessages == true then LOG(sFunctionRef..': Want to get T2 land as have T2 air but not many engis and have decent income') end
                iCategoryToUpgrade = M27UnitInfo.refCategoryLandFactory
            end
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Already have active HQ upgrades or not enough engineers of the tech level. iEngisOfHighestTechLevel='..iEngisOfHighestTechLevel..'; will list out the units and their work progress')
                for iUnit, oUnit in aiBrain[reftActiveHQUpgrades] do
                    if M27UnitInfo.IsUnitValid(oUnit) then
                        LOG(sFunctionRef .. ': HQ unit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; Workpgoress=' .. oUnit:GetWorkProgress())
                    else
                        LOG(sFunctionRef .. ': HQ Unit isnt valid. iUnit=' .. iUnit)
                    end
                end
            end
        end
        --Prioritise getting T3 air if enemy has T3 air
        if not(iCategoryToUpgrade) and aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][3] > 0 and iAirFactoryUpgrading == 0 and iAirFactoryAvailable > 0 and aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 and (aiBrain[refiGrossEnergyBaseIncome] >= 100 or iT2AirFactories == 0) then
            if iT2AirFactories > 0 then iCategoryToUpgrade = refCategoryAirFactory * categories.TECH2 else iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 end
        end
        if not (iCategoryToUpgrade) then
            if bDebugMessages == true then LOG(sFunctionRef..': No category after running normal HQ selection logic. bGetT2FactoryHQ priority='..tostring(bGetT2FactoryHQ)) end
            if bGetT2FactoryHQ then
                iCategoryToUpgrade = M27UnitInfo.refCategoryLandFactory
            end
            if not(iCategoryToUpgrade) then

                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Still no category to upgrade, will follow normal logic on what to upgrade unless we already have enough. bAlreadyUpgradingEnough=' .. tostring(bAlreadyUpgradingEnough))
                end

                --Special logic for if trying to snipe ACU
                if iAirFactoryAvailable > 0 and iT1AirFactories > 0 and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and M27UnitInfo.IsUnitUnderwater(aiBrain[M27Overseer.refoACUKillTarget]) and (iT2AirFactories + iT3AirFactories) == 0 then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Will upgrade air factory. iAirFactoryAvailable=' .. iAirFactoryAvailable .. '; strategy is to kill ACU and enemy aCU is underwater and we dont ahve T2 or T3 air factory yet')
                    end
                    iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryAirFactory * categories.TECH2
                elseif not (bAlreadyUpgradingEnough) then

                    local iUnitUpgrading, iUnitAvailable
                    local iRatioOfMexToFactory = 1.1
                    --[[if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 then
                        if iT3AirFactories > 0 then aiBrain[M27Overseer.refiOurHighestAirFactoryTech] = 3
                        elseif iT2AirFactories + iT3AirFactories > 0 then aiBrain[M27Overseer.refiOurHighestAirFactoryTech] = 2 end
                    end--]]
                    if (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle) then
                        iRatioOfMexToFactory = 3
                    end

                    function DecideOnFirstHQ()
                        --Assumes ahve already checked we have factories available to upgrade and arent upgrading an HQ already
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Deciding on first HQ and if want it to be land or air')
                        end
                        local iFactoryToUpgrade
                        if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 1 then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Deciding whether to upgrade from T1 to T2; aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes]=' .. aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes] .. '; aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat]=' .. aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] .. '; aiBrain[M27Overseer.refiModDistFromStartNearestThreat]=' .. aiBrain[M27Overseer.refiModDistFromStartNearestThreat])
                            end
                            if iT1AirFactories <= 0 then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Want to upgrade land factory as no T1 factories available to upgrade')
                                end
                                iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH1
                            elseif iT1LandFactories <= 0 then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Want to upgrade air factory as no T1 land factories available to upgrade')
                                end
                                iFactoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH1
                            else
                                --Are we turtling, and we are likely to want mobile shields?
                                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle and not(aiBrain:GetFactionIndex() == M27UnitInfo.refFactionCybran) then
                                    iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH1
                                else
                                    local iEnergyIncomeAdjustForReclaim = 0
                                    local iNearbyEnergyReclaim = 0
                                    local iBaseSegmentX, iBaseSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                    local iMaxAdjust = 13
                                    if aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 300 then
                                        iMaxAdjust = 4
                                    end
                                    for iXAdj = -iMaxAdjust, iMaxAdjust do
                                        for iZAdj = -iMaxAdjust, iMaxAdjust do
                                            iNearbyEnergyReclaim = iNearbyEnergyReclaim + (M27MapInfo.tReclaimAreas[iBaseSegmentX + iXAdj][iBaseSegmentZ + iZAdj][M27MapInfo.refReclaimTotalEnergy] or 0)
                                        end

                                    end
                                    if iNearbyEnergyReclaim >= 1000 then
                                        iEnergyIncomeAdjustForReclaim = math.max(-iNearbyEnergyReclaim / 500, -12)
                                    end

                                    if aiBrain[refiGrossEnergyBaseIncome] <= (42 + iEnergyIncomeAdjustForReclaim) then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Energy income too low to support air fac')
                                        end
                                        if not (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]) and aiBrain[refiMexesAvailableForUpgrade] > 0 then
                                            iFactoryToUpgrade = M27UnitInfo.refCategoryT1Mex --Better to not upgrade factory yet and e.g. upgrade a mex than to upgrade land
                                        else
                                            iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH1
                                        end
                                    elseif aiBrain[M27AirOverseer.refiTorpBombersWanted] > 0 then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Want to upgrade air factory as need torp bombers')
                                        end
                                        iFactoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH1 + M27UnitInfo.refCategoryAirFactory * categories.TECH2
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': Can path to enemy with land='..tostring(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand])..'; Dist to nearest enemy base='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]..'; Highest factory tech='..aiBrain[M27Overseer.refiOurHighestLandFactoryTech]) end
                                        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] and aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 400 and aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 1 then
                                            iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH1
                                            if bDebugMessages == true then LOG(sFunctionRef..': Want T2 land as enemy base is relatively close') end
                                        elseif aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] and (aiBrain[refiGrossEnergyBaseIncome] <= (46 + iEnergyIncomeAdjustForReclaim) or aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes] > 1 or aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] <= math.min(300, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.4) or aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= math.min(200, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.32)) then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Want to upgrade land factory as no T1 factories available to upgrade')
                                            end
                                            iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH1 + M27UnitInfo.refCategoryLandFactory * categories.TECH2
                                        else
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Want to upgrade air factory as either cant path to enemy with land, or only want 1 land fac and nearest enemy is far away')
                                            end
                                            iFactoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH1 + M27UnitInfo.refCategoryAirFactory * categories.TECH2
                                        end
                                    end
                                end
                            end
                        else
                            local iEnergyIncomeAdjustForReclaim = 0
                            local iNearbyEnergyReclaim = 0
                            local iBaseSegmentX, iBaseSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                            local iMaxAdjust = 13
                            if aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 300 then
                                iMaxAdjust = 4
                            end
                            for iXAdj = -iMaxAdjust, iMaxAdjust do
                                for iZAdj = -iMaxAdjust, iMaxAdjust do
                                    iNearbyEnergyReclaim = iNearbyEnergyReclaim + (M27MapInfo.tReclaimAreas[iBaseSegmentX + iXAdj][iBaseSegmentZ + iZAdj][M27MapInfo.refReclaimTotalEnergy] or 0)
                                end
                            end
                            if iNearbyEnergyReclaim >= 1000 then
                                iEnergyIncomeAdjustForReclaim = math.max(-iNearbyEnergyReclaim / 500, -30)
                            end

                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Want to upgrade to T3, will decide if want land or air')
                            end
                            --Must be wanting to upgrade to T3
                            if iT2AirFactories <= 0 then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Have no T2 air facs or <=1.25k energy income gross so will upgrade land fac')
                                end
                                iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH2
                            elseif iT2LandFactories <= 0 then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Have no T2 land facs so will upgrade air HQ')
                                end
                                iFactoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH2
                            elseif iT2LandFactories > 0 and aiBrain[refiGrossEnergyBaseIncome] <= (120 + iEnergyIncomeAdjustForReclaim) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Gross energy income is below 1.2k so will upgrade land')
                                end
                                iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH2

                            elseif M27UnitInfo.IsUnitUnderwater(M27Utilities.GetACU(aiBrain)) and M27Utilities.GetACU(aiBrain)[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage] and GetGameTimeSeconds() - M27Utilities.GetACU(aiBrain)[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage] <= 30 and M27UnitInfo.IsUnitValid(M27Utilities.GetACU(aiBrain)[M27Overseer.refoUnitDealingUnseenDamage]) and EntityCategoryContains(categories.ANTINAVY + categories.OVERLAYANTINAVY, M27Utilities.GetACU(aiBrain)[M27Overseer.refoUnitDealingUnseenDamage].UnitId) then
                                --Upgrade land if we need torp bombers to help the ACU
                                iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH2
                            elseif not (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand]) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Cant path to enemy base with land so will focus on air')
                                end
                                iFactoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH2
                            else
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Could go for land or air, consider if enough targets for bomber and no nearby land threats')
                                end
                                --Want to get land normally, but first check if enough targets of opportunity for bombers and enemy has no airAA, in which case get air
                                --Go for air if enemy has no tech3 AA and we dont have nearby enemy land threats
                                local bGetAirNotLand = false
                                if not (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand]) then
                                    bGetAirNotLand = true
                                else
                                    --Are there nearby land threats?
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Checking if have nearby enemy land threats')
                                    end
                                    if aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] <= math.min(350, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.4) or aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= math.min(200, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.32) then
                                        --Do they have T3 AA or cruisers?
                                        local tEnemyBigAirThreats = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3 + M27UnitInfo.refCategoryStructureAA * categories.TECH3 + M27UnitInfo.refCategoryAirAA * categories.TECH3 + M27UnitInfo.refCategoryAirAA * categories.TECH2 * M27Utilities.FactionIndexToCategory(M27UnitInfo.refFactionAeon) + M27UnitInfo.refCategoryCruiserCarrier, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27AirOverseer.refiMaxScoutRadius], 'Enemy')
                                        if M27Utilities.IsTableEmpty(tEnemyBigAirThreats) == true and aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] <= math.min(200, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.3) then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Enemy has no T3 AA so will check if they have enough unshielded mexes to warrant an early strat bomber')
                                            end
                                            --Are there enough enemy T2+ mexes that arent shielded?
                                            local tEnemyMexes = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryT3Mex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27AirOverseer.refiMaxScoutRadius], 'Enemy')
                                            if M27Utilities.IsTableEmpty(tEnemyMexes) == false then
                                                local iPriorityTargets = 0
                                                for iMex, oMex in tEnemyMexes do
                                                    if M27Logic.IsTargetUnderShield(aiBrain, oMex, 4000) == false then
                                                        iPriorityTargets = iPriorityTargets + 1
                                                        if iPriorityTargets >= 5 then
                                                            bGetAirNotLand = true
                                                            break
                                                        end
                                                    end
                                                end
                                            end
                                        elseif bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Enemy has T3 AA')
                                        end
                                    elseif bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Nearest enemy land threat is too close; aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat]=' .. aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] .. '; aiBrain[M27Overseer.refiModDistFromStartNearestThreat]=' .. aiBrain[M27Overseer.refiModDistFromStartNearestThreat])
                                    end
                                end
                                if bGetAirNotLand then
                                    iFactoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH2
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Will upgrade T2 air factory')
                                    end
                                else
                                    iFactoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH2
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Will upgrade T2 land factory')
                                    end
                                end
                            end
                        end
                        return iFactoryToUpgrade
                    end

                    --Do we have T2 land but not T2 air? If so get T2 air as a high priority if map has water (as may want torp bombers)
                    if iAirFactoryAvailable > 0 and iT1AirFactories > 0 and not (bAlreadyUpgradingAirHQ) and aiBrain[M27Overseer.refiOurHighestLandFactoryTech] >= 2 and aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 1 and aiBrain[refiGrossEnergyBaseIncome] >= 60 and
                            ((M27MapInfo.bMapHasWater and (aiBrain[refiGrossMassBaseIncome] >= 6 or (aiBrain:GetEconomyStoredRatio('MASS') > 0.01 and aiBrain[refiGrossMassBaseIncome] >= 4))) or (aiBrain[refiGrossEnergyBaseIncome] >= 75 and (aiBrain[refiGrossMassBaseIncome] >= 8.5 or (aiBrain:GetEconomyStoredRatio('MASS') > 0.05 and aiBrain[refiGrossMassBaseIncome] >= 6.5)))) then
                        iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Will upgrade T1 air factory')
                        end
                    else
                        if iMaxToBeUpgrading > (iLandFactoryUpgrading + aiBrain[refiMexesUpgrading] + iAirFactoryUpgrading) then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Arent already upgrading the max amount wanted; iMaxToBeUpgrading=' .. iMaxToBeUpgrading .. '; iLandFactoryUpgrading=' .. iLandFactoryUpgrading .. '; aiBrain[refiMexesUpgrading]=' .. aiBrain[refiMexesUpgrading] .. '; iAirFactoryUpgrading=' .. iAirFactoryUpgrading .. '; will check if want to prioritise HQ upggrades; M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])) .. '; aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]=' .. aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] .. '; iLandFactoryUpgrading=' .. iLandFactoryUpgrading .. '; iAirFactoryUpgrading=' .. iAirFactoryUpgrading .. '; iT1AirFactories=' .. iT1AirFactories .. '; iT2AirFactories=' .. iT2AirFactories .. '; iT1LandFactories=' .. iT1LandFactories .. '; iT2LandFactories=' .. iT2LandFactories .. '; iT2Mexes=' .. iT2Mexes .. '; iT3Mexes=' .. iT3Mexes .. '; aiBrain[refiGrossMassBaseIncome]=' .. aiBrain[refiGrossMassBaseIncome] .. '; aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes]=' .. aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes]..'; Faction index='..aiBrain:GetFactionIndex()..'; Gross mass inc='..aiBrain[refiGrossMassBaseIncome]..'; Highest land fac tech='..aiBrain[M27Overseer.refiOurHighestLandFactoryTech]..'; Dist to enemy='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase])
                            end
                            --Get T2 HQ so can get T2 as soon as start having significant mass income, regardless of strategy
                            if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 1 and (aiBrain[refiGrossMassBaseIncome] >= 4 or iT2Mexes + iT3Mexes >= 2) and iAirFactoryAvailable + iLandFactoryAvailable > 0 and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == true and iT2AirFactories + iT3AirFactories + iT2LandFactories + iT3LandFactories == 0 then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Will get HQ upgrade')
                                end
                                iCategoryToUpgrade = DecideOnFirstHQ()
                                --Get T3 HQ with similar scenario
                            elseif aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 2 and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == true and iT3LandFactories + iT3AirFactories == 0 and iT2LandFactories + iT2AirFactories > 0 and (aiBrain[refiGrossMassBaseIncome] >= 11 or iT3Mexes >= 4) and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Power + M27UnitInfo.refCategoryT3Power) > 0 and iEngisOfHighestTechLevel >= 2 and ((iT2LandFactories + iT2AirFactories) >= 4 or aiBrain[M27Overseer.refiEnemyHighestTechLevel] >= 2 or M27Conditions.GetLifetimeBuildCount(aiBrain, categories.TECH2 * categories.MOBILE * categories.LAND) >= 12) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Want to get T3 factory upgrade, will decide if want ot get land or air factory')
                                end
                                iCategoryToUpgrade = DecideOnFirstHQ()
                                --Get T2 urgently regardless of eco if enemy has T2 structures near our base
                            elseif M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) and aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 1 and iAirFactoryAvailable + iLandFactoryAvailable > 0 and aiBrain[M27Overseer.refiNearestEnemyT2PlusStructure] <= 200 then
                                iCategoryToUpgrade = DecideOnFirstHQ()
                                --Prioritise T2 land upgrade for Cybran and UEF on land maps where enemy base relatively close
                            elseif aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] and aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 400 and aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 1 and iLandFactoryUpgrading == 0 and iT1LandFactories >= 2 and (aiBrain[refiGrossMassBaseIncome] >= 3.5 or (aiBrain[refiGrossMassBaseIncome] >= 2 and (iT2Mexes + iT3Mexes) > 0)) and (aiBrain:GetFactionIndex() == M27UnitInfo.refFactionUEF or aiBrain:GetFactionIndex() == M27UnitInfo.refFactionCybran) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Are UEF or Cybran so want to rush T2 land') end
                                iCategoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH1
                            else
                                if aiBrain[refiMexesAvailableForUpgrade] > 0 then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Setting unit to upgrade to be T1+T2 mex as default, will now consider changing this')
                                    end
                                    iCategoryToUpgrade = refCategoryT1Mex + refCategoryT2Mex --Default
                                end
                                if aiBrain[refiMexesUpgrading] == 0 and (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle) and aiBrain[refiMexesAvailableForUpgrade] > 0 then
                                    --Just stick with upgrading a mex, no change
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': No change will stick with mexes')
                                    end
                                else
                                    --Dont upgrade factory if we have an HQ upgrade going on
                                    if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
                                        local bClearUpgrades = true
                                        for iHQ, oHQ in aiBrain[reftActiveHQUpgrades] do
                                            if M27UnitInfo.IsUnitValid(oHQ) then
                                                bClearUpgrades = false
                                                break
                                            end
                                        end
                                        if bClearUpgrades then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Clearing all active HQ upgrades as none of them are of a valid unit any more')
                                            end
                                            aiBrain[reftActiveHQUpgrades] = {}
                                        end
                                    end
                                    if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Dont have any active HQ upgrades; Have enough available units to upgrade; have started by setting upgrade to mex as default')
                                        end
                                        --Do we need torpedo bombers and cant build them fast enough?
                                        if iAirFactoryAvailable > 0 and iT2AirFactories + iT3AirFactories + iAirFactoryUpgrading == 0 and aiBrain[M27AirOverseer.refiTorpBombersWanted] > 0 then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Will look to upgrade air fac')
                                            end
                                            iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryAirFactory * categories.TECH2
                                        elseif aiBrain[M27AirOverseer.refiTorpBombersWanted] > 5 and iAirFactoryUpgrading == 0 and (iAirFactoryAvailable - iT2AirFactories) > 0 then
                                            iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryAirFactory * categories.TECH2
                                        else
                                            --Get t2 mex before T2 HQ
                                            local iMinT2MexesWanted = 2
                                            if (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle) then
                                                iMinT2MexesWanted = 4
                                            end
                                            if aiBrain[refiMexesAvailableForUpgrade] == 0 or aiBrain[refiMexesUpgrading] + iT2Mexes + iT3Mexes >= 2 then
                                                --Do we want to improve build power instead of getting mexes?
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Deciding if want to improve build power instead of mexes. Factory value=' .. (iLandFactoryUpgrading + iT2LandFactories + iAirFactoryUpgrading + iT2AirFactories) + (iT3LandFactories + iT3AirFactories) * 1.5 .. '; Mex value=' .. ((aiBrain[refiMexesUpgrading] + iT2Mexes) + iT3Mexes * 3) .. '; iRatioOfMexToFactory=' .. iRatioOfMexToFactory .. '; aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused]=' .. aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused])
                                                end
                                                if (iLandFactoryUpgrading + iT2LandFactories + iAirFactoryUpgrading + iT2AirFactories) + (iT3LandFactories + iT3AirFactories) * 1.5 < ((aiBrain[refiMexesUpgrading] + iT2Mexes) + iT3Mexes * 3) * iRatioOfMexToFactory and aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused] == 0 then
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Want to upgrade build power if we have factories available and enough engis of our highest tech level. bAlreadyUpgradingLandHQ=' .. tostring((bAlreadyUpgradingLandHQ or false)) .. '; bAlreadyUpgradingAirHQ=' .. tostring((bAlreadyUpgradingAirHQ or false)) .. '; Number of engis of current tech level=' .. table.getn(aiBrain:GetListOfUnits(M27UnitInfo.refCategoryEngineer * M27UnitInfo.ConvertTechLevelToCategory(aiBrain[M27Overseer.refiOurHighestFactoryTechLevel])), false, true) .. '; Gross energy income=' .. aiBrain[refiGrossEnergyBaseIncome] .. '; Mexes near start=' .. table.getn(M27MapInfo.GetResourcesNearTargetLocation(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 30, true)))
                                                    end
                                                    --Want to upgrade build power; do we want an HQ?


                                                    if iEngisOfHighestTechLevel >= 2 and aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] < 2 and aiBrain:GetListOfUnits(M27UnitInfo.refCategoryEngineer * M27UnitInfo.ConvertTechLevelToCategory(aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]), false, true) >= 3 and aiBrain[refiGrossEnergyBaseIncome] >= 50 then
                                                        iCategoryToUpgrade = DecideOnFirstHQ()
                                                    elseif iEngisOfHighestTechLevel >= 2 and aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 2 and (iT3Mexes > 0 or aiBrain[refiGrossMassBaseIncome] > 5) and (iT2Mexes + iT3Mexes) >= math.min(8, table.getn(M27MapInfo.GetResourcesNearTargetLocation(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 30, true))) and aiBrain[refiGrossEnergyBaseIncome] >= 100 then
                                                        iCategoryToUpgrade = DecideOnFirstHQ()
                                                    elseif aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 2 and (aiBrain[refiGrossMassBaseIncome] >= 5 or (aiBrain[refiGrossMassBaseIncome] >= 3 and iAirFactoryUpgrading == 0 and iLandFactoryUpgrading == 0)) then
                                                        --Dont want to upgrade an HQ, consider upgrading a support factory as well providing it wont be upgraded to a HQ
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': Dont want to upgrade an HQ yet, want more engineers or power first')
                                                        end

                                                        if iT2LandFactories > 0 and iT2AirFactories == 0 and iLandFactoryUpgrading <= iT2LandFactories then
                                                            iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1
                                                        elseif iT2LandFactories > 0 and iT2AirFactories > 0 then
                                                            if iLandFactoryUpgrading <= iT2LandFactories and iAirFactoryUpgrading <= iT2AirFactories then
                                                                iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryLandFactory * categories.TECH1
                                                            elseif iLandFactoryUpgrading <= iT2LandFactories then
                                                                iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1
                                                            elseif iAirFactoryUpgrading <= iT2AirFactories then
                                                                iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
                                                            end
                                                        elseif iT2AirFactories > 0 and iAirFactoryUpgrading <= iT2AirFactories then
                                                            iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1
                                                        end
                                                    elseif aiBrain[refiGrossMassBaseIncome] >= 5 then
                                                        --Already at tech 3
                                                        if iAirFactoryAvailable == 0 then
                                                            iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1 + refCategoryLandFactory * categories.TECH2
                                                        elseif iLandFactoryAvailable == 0 then
                                                            iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryAirFactory * categories.TECH2
                                                        else
                                                            --Have both land and air available so pick the best one
                                                            if (iT3AirFactories > 0 and iT3LandFactories == 0) or (iT3AirFactories > iT3LandFactories and aiBrain[refiGrossEnergyBaseIncome] <= 300) then
                                                                if iLandFactoryUpgrading <= iT3LandFactories then
                                                                    iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1 + refCategoryLandFactory * categories.TECH2
                                                                end
                                                            else
                                                                local iFactoryToAirRatio = (iLandFactoryUpgrading * 2 + iT1LandFactories + iT2LandFactories * 2 + iT3LandFactories * 3) / math.max(1, iAirFactoryUpgrading * 2 + iT1AirFactories + iT2AirFactories * 2 + iT3AirFactories * 3)
                                                                local iDesiredFactoryToAirRatio = aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] / math.max(1, aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir])
                                                                if iAirFactoryAvailable > 0 and iFactoryToAirRatio > iDesiredFactoryToAirRatio and aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir] > (iAirFactoryUpgrading + iAirFactoryAvailable) and not (bAlreadyUpgradingAirHQ) then
                                                                    if bDebugMessages == true then
                                                                        LOG(sFunctionRef .. ': Want to upgrade air factory')
                                                                    end
                                                                    if iAirFactoryUpgrading <= iT3AirFactories then
                                                                        iCategoryToUpgrade = refCategoryAirFactory * categories.TECH1 + refCategoryAirFactory * categories.TECH2
                                                                    end
                                                                elseif iLandFactoryAvailable > 0 and not (bAlreadyUpgradingLandHQ) and (iLandFactoryAvailable + iT3LandFactories + iT3AirFactories + iAirFactoryAvailable) > 1 then
                                                                    --Dont want to upgrade our only land factory taht can produce units if we have no other available factories (including air, to allow for maps where we go for only 1 land fac)
                                                                    if bDebugMessages == true then
                                                                        LOG(sFunctionRef .. ': Want to upgrade land factory')
                                                                    end
                                                                    if iLandFactoryUpgrading <= iT3LandFactories then
                                                                        iCategoryToUpgrade = refCategoryLandFactory * categories.TECH1 + refCategoryLandFactory * categories.TECH2
                                                                    end
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    elseif bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Have active HQ upgrade so wont get a factory to upgrade (meaning will go with default of upgrading a mex')
                                    end
                                end
                            end
                            if not (iCategoryToUpgrade) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Not determined any category to upgrade from the preceding logic, so will upgrade mex if we have any, or if not then T2 factory, or if not then T1 factory')
                                end
                                if aiBrain[refiMexesAvailableForUpgrade] > 0 then
                                    iCategoryToUpgrade = M27UnitInfo.refCategoryT1Mex + M27UnitInfo.refCategoryT2Mex
                                else
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Dont have any mexes available for upgrade so will try a factory instead')
                                    end
                                    if iLandFactoryUpgrading == 0 and iLandFactoryAvailable > 0 then
                                        if aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 3 then
                                            if iT2LandFactories > 0 then
                                                iCategoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH2
                                            else
                                                iCategoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH1
                                            end
                                        else
                                            if iT1LandFactories > 0 then
                                                iCategoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH1
                                            elseif iT2LandFactories > 0 then
                                                iCategoryToUpgrade = M27UnitInfo.refCategoryLandFactory * categories.TECH2
                                            end
                                        end
                                    elseif iAirFactoryUpgrading == 0 and iAirFactoryAvailable > 0 then
                                        if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 3 then
                                            if iT2AirFactories > 0 then
                                                iCategoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH2
                                            else
                                                iCategoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH1
                                            end
                                        else
                                            if iT1AirFactories > 0 then
                                                iCategoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH1
                                            elseif iT2AirFactories > 0 then
                                                iCategoryToUpgrade = M27UnitInfo.refCategoryAirFactory * categories.TECH2
                                            end
                                        end
                                    else
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Cant find anything to upgrade, will just say to upgrade a mex, so then the backup logic should kick in to try and upgrade soemthing else instead')
                                        end
                                        iCategoryToUpgrade = M27UnitInfo.refCategoryT1Mex + M27UnitInfo.refCategoryT2Mex
                                    end
                                end
                            end
                        elseif bDebugMessages == true then
                            LOG(sFunctionRef .. ': Are upgrading the max amount wanted already.  iMaxToBeUpgrading=' .. iMaxToBeUpgrading .. '; iLandFactoryUpgrading=' .. iLandFactoryUpgrading .. '; aiBrain[refiMexesUpgrading]=' .. aiBrain[refiMexesUpgrading] .. '; iAirFactoryUpgrading=' .. iAirFactoryUpgrading)
                        end
                    end
                end
            end
        end
    end
    if not (iCategoryToUpgrade) then
        --Are we already upgrading enough?
        if not (bAlreadyUpgradingEnough) then
            M27Utilities.ErrorHandler('No category to upgrade specified but we wanted to upgrade more than we currently are', true)
        end
    end
    if bDebugMessages == true then
        if iCategoryToUpgrade == nil then

            LOG(sFunctionRef .. ': Dont have a category to upgrade')
        else
            LOG(sFunctionRef .. ': Have a category to upgrade, number of untis of that category=' .. aiBrain:GetCurrentUnits(iCategoryToUpgrade) .. '; Blueprints that meet that category=' .. repru(EntityCategoryGetUnitList(iCategoryToUpgrade)))
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iCategoryToUpgrade
end

function ClearOldRecords(aiBrain, iOldRecordsExpected)
    --iOldRecordsExpected - optional - allows optimisation by having this called from loops which can already determine this for minimal extra cost
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ClearOldRecords'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iLoopCount = 0
    local iLoopMax = 100
    local sUnitReasonForClear, sUnitState
    local iOldRecordCount = 0
    if M27Utilities.IsTableEmpty(aiBrain[reftUpgrading]) == false then
        if iOldRecordsExpected == nil then
            for iRef, oUnit in aiBrain[reftUpgrading] do
                if M27UnitInfo.IsUnitValid(oUnit) == false or oUnit:IsUnitState('Upgrading') == false then
                    iOldRecordCount = iOldRecordCount + 1
                end
            end
        else
            iOldRecordCount = iOldRecordsExpected
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': iOldRecordCount=' .. iOldRecordCount .. '; will clean up trackers')
        end
        while iOldRecordCount > 0 do
            iLoopCount = iLoopCount + 1
            if iLoopCount > iLoopMax then
                M27Utilities.ErrorHandler('Infinite loop')
                break
            end

            for iRef, oUnit in aiBrain[reftUpgrading] do
                if M27UnitInfo.IsUnitValid(oUnit) == false then
                    if bDebugMessages == true then
                        sUnitReasonForClear = 'Unknown'
                        if oUnit.Dead then
                            sUnitReasonForClear = 'Unit is dead'
                        elseif oUnit.GetFractionComplete == nil then
                            sUnitReasonForClear = 'Unit doesnt have a fraction complete, likely error'
                            --Commented out to avoid desyncs:
                            --elseif oUnit:GetFractionComplete() < 1 then sUnitReasonForClear = 'Unit fraction complete isnt 100%'
                            --elseif oUnit:IsUnitState('Upgrading') == false then sUnitReasonForClear = 'Unit state isnt upgrading'
                        end
                        --if oUnit.GetUnitId then sUnitReasonForClear = oUnit.UnitId..':'..sUnitReasonForClear end
                        LOG(sFunctionRef .. ': iRef=' .. iRef .. ': clearing from tracker, reason for clearing: ' .. sUnitReasonForClear)
                        --sUnitState = 'UnknownState'
                        --if oUnit.IsUnitState then sUnitState = M27Logic.GetUnitState(oUnit) end
                    end

                    if oUnit[refbUpgradePaused] == true then
                        aiBrain[refiPausedUpgradeCount] = aiBrain[refiPausedUpgradeCount] - 1
                    end
                    table.remove(aiBrain[reftUpgrading], iRef)
                    iOldRecordCount = iOldRecordCount - 1
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Just removed an old record; iOldRecordCount=' .. iOldRecordCount)
                    end
                    break
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UnpauseUpgrades(aiBrain, iMaxToUnpause)
    --Note - this will try and unpause any units that have been paused previously.  However, in some cases there may not be a unit to unpause e.g. if engineers have assisted it while its paused
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UnpauseUpgrades'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iAmountToUnpause = math.min(iMaxToUnpause, aiBrain[refiPausedUpgradeCount])
    local iOldRecordCount = 0
    local iLoopCount = 0
    local iMaxLoopCount = 20
    local bNoUnitsFound = true
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': iAmountToUnpause=' .. iAmountToUnpause .. '; aiBrain[refiPausedUpgradeCount]=' .. aiBrain[refiPausedUpgradeCount])
    end

    function InternalUnpauseUpgrade(oUnit)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Units upgrade is paused, will unpause now')
        end
        iAmountToUnpause = iAmountToUnpause - 1
        oUnit:SetPaused(false)
        oUnit[refbUpgradePaused] = false
        aiBrain[refiPausedUpgradeCount] = aiBrain[refiPausedUpgradeCount] - 1
        bNoUnitsFound = false
    end
    while iAmountToUnpause > 0 do
        iLoopCount = iLoopCount + 1
        if iLoopCount > iMaxLoopCount then
            M27Utilities.ErrorHandler('Infinite loop detected')
            break
        end
        if M27Utilities.IsTableEmpty(aiBrain[reftUpgrading]) == false then
            bNoUnitsFound = true
            --First unpause any HQs that are paused
            if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
                for iHQ, oHQ in aiBrain[reftActiveHQUpgrades] do
                    if M27UnitInfo.IsUnitValid(oHQ) and oHQ[refbUpgradePaused] then
                        InternalUnpauseUpgrade(oHQ)
                    end
                end
            end

            if bNoUnitsFound then
                for iRef, oUnit in aiBrain[reftUpgrading] do
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Cycling through units in reftUpgrading; iRef=' .. iRef)
                    end
                    if M27UnitInfo.IsUnitValid(oUnit) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Have a valid unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ';, checking if it has a paused upgrade, oUnit[refbUpgradePaused]=' .. tostring(oUnit[refbUpgradePaused]))
                        end
                        if oUnit[refbUpgradePaused] == true then
                            InternalUnpauseUpgrade(oUnit)
                        end
                    else
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Unit not valid so must be an old record')
                        end
                        iOldRecordCount = iOldRecordCount + 1
                    end
                end
            end
            if bNoUnitsFound == true then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': NoUnits found; iOldRecordCount=' .. iOldRecordCount)
                end
                aiBrain[reftUpgrading] = {}
                break
            end
        else
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Table of upgrading units is empty but we should have paused units in it; maybe they died?')
            end
            break
        end
        if iOldRecordCount > 0 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': iOldRecordCount=' .. iOldRecordCount .. '; will clear old records before continuing loop')
            end
            ClearOldRecords(aiBrain, iOldRecordCount)
            iOldRecordCount = 0
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function PauseLastUpgrade(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'PauseLastUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local oLastUnpausedUpgrade
    local oLastUnpausedNonMex
    local iOldRecordCount = 0
    local iMexThresholdToIgnorePausing = 0.9
    local iGeneralThresholdToIgnorePausing = 0.9
    local sUnitId
    if aiBrain[refbPauseForPowerStall] == false then
        iMexThresholdToIgnorePausing = 0.6
        iGeneralThresholdToIgnorePausing = 0.8
    end
    local iThresholdToIgnorePausing
    local bHaveMex = false
    if M27Utilities.IsTableEmpty(aiBrain[reftUpgrading]) == false then
        for iRef, oUnit in aiBrain[reftUpgrading] do
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': iRef=' .. iRef .. ' Considering if unit is alive and part-complete')
            end
            if M27UnitInfo.IsUnitValid(oUnit) then
                if not (oUnit[refbUpgradePaused]) then
                    if oUnit:IsUnitState('Upgrading') == true then
                        local bIsHQUpgrade = false
                        --Dont pause if is an HQ
                        if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
                            for iHQ, oHQ in aiBrain[reftActiveHQUpgrades] do
                                if oHQ == oUnit then
                                    bIsHQUpgrade = true
                                    break
                                end
                            end
                        end
                        if not (bIsHQUpgrade) then

                            sUnitId = oUnit.UnitId
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Unit ID=' .. sUnitId .. '; Unit is valid and not paused so will pause it unless theres a later upgrade or its a mex and almost complete')
                            end
                            if not (EntityCategoryContains(refCategoryMex, sUnitId)) then
                                iThresholdToIgnorePausing = iGeneralThresholdToIgnorePausing
                            else
                                bHaveMex = true
                                iThresholdToIgnorePausing = iMexThresholdToIgnorePausing
                            end

                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': oUnit=' .. sUnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
                                if oUnit.UnitBeingBuilt then
                                    LOG(sFunctionRef .. ': Have a unit being built')
                                    if oUnit.UnitBeingBuilt.GetUnitId then
                                        LOG(sFunctionRef .. ': ID of unit being built=' .. oUnit.UnitBeingBuilt.UnitId)
                                    end
                                    if oUnit.UnitBeingBuilt.GetFractionComplete then
                                        LOG(sFunctionRef .. ': Fraction complete=' .. oUnit.UnitBeingBuilt:GetFractionComplete())
                                    else
                                        LOG('Fraction complete is nil')
                                    end
                                elseif oUnit.unitBeingBuilt then
                                    M27Utilities.ErrorHandler('UnitBeingBuilt sometimes is lower case so need to revise code')
                                else
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': unitBeingBuilt is nil')
                                    end
                                end
                            end
                            if oUnit.UnitBeingBuilt and oUnit.UnitBeingBuilt.GetFractionComplete and oUnit.UnitBeingBuilt:GetFractionComplete() < iThresholdToIgnorePausing then
                                oLastUnpausedUpgrade = oUnit
                                if not (bHaveMex) then
                                    oLastUnpausedNonMex = oLastUnpausedUpgrade
                                end
                            end
                        end
                    end
                end
            else
                iOldRecordCount = iOldRecordCount + 1
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Unit was dead or complete, will call separate function to remove from tracker')
                end
            end
        end
        if oLastUnpausedUpgrade then

            if oLastUnpausedNonMex then
                oLastUnpausedNonMex:SetPaused(true)
            else
                oLastUnpausedUpgrade:SetPaused(true)
            end
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Pausing upgrade')
            end
            aiBrain[refiPausedUpgradeCount] = aiBrain[refiPausedUpgradeCount] + 1
            oLastUnpausedUpgrade[refbUpgradePaused] = true
        end
    else
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': We have no buildings recorded that we are upgrading, so nothing to pause')
        end
    end

    if iOldRecordCount > 0 then
        if iOldRecordCount > 0 then
            ClearOldRecords(aiBrain, iOldRecordCount)
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DecideMaxAmountToBeUpgrading(aiBrain)
    --Returns max number to upgrade
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DecideMaxAmountToBeUpgrading'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetGameTimeSeconds() >= 600 then bDebugMessages = true end



    local iMassStored, iMassNetIncome, iEnergyStored, iEnergyNetIncome
    local bHaveHighMass, bHaveEnoughEnergy
    local iMaxToUpgrade = 0

    --Get economy values:
    iMassStored = aiBrain:GetEconomyStored('MASS')
    iEnergyStored = aiBrain:GetEconomyStored('ENERGY')
    iMassNetIncome = aiBrain:GetEconomyTrend('MASS')
    iEnergyNetIncome = aiBrain:GetEconomyTrend('ENERGY')
    local iEnergyChangeFromLastCycle = iEnergyStored - aiBrain[refiEnergyStoredLastCycle]
    local iEnergyPercentStorage = aiBrain:GetEconomyStoredRatio('ENERGY')

    bHaveHighMass = false
    bHaveEnoughEnergy = false
    local bHaveLotsOfResources = false

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': iMassStored=' .. iMassStored .. '; iEnergyStored=' .. iEnergyStored .. '; iMassNetIncome=' .. iMassNetIncome .. '; iEnergyNetIncome=' .. iEnergyNetIncome .. '; Time of last power stall=' .. aiBrain[refiLastEnergyStall] .. '; Game time=' .. GetGameTimeSeconds())
    end

    local bHaveLotsOfFactories = false
    local iT3MexCount = aiBrain:GetCurrentUnits(refCategoryMex * categories.TECH3)
    local iT2MexCount = aiBrain:GetCurrentUnits(refCategoryMex * categories.TECH2)
    local iMexesOnOurSideOfMap = GetMexCountOnOurSideOfMap(aiBrain)
    local iLandFactoryCount = aiBrain:GetCurrentUnits(refCategoryLandFactory)
    local iAirFactoryCount = aiBrain:GetCurrentUnits(refCategoryAirFactory)
    if iLandFactoryCount >= 10 then
        bHaveLotsOfFactories = true
    end
    local bWantMoreFactories = false
    if iLandFactoryCount < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] then
        bWantMoreFactories = true
    elseif iAirFactoryCount < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir] then
        bWantMoreFactories = true
    end

    local bNormalLogic = true
    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill then
        bNormalLogic = false
        --Pause upgrades unlessd ACU is underwater and we dont ahve T2+ air
        if bDebugMessages == true then LOG(sFunctionRef..': In ACU kill mode so will pause upgrades unless ACU underwater and we lack T2 air, or we have full energy') end
        if M27UnitInfo.IsUnitUnderwater(aiBrain[M27Overseer.refoACUKillTarget]) and aiBrain:GetCurrentUnits(refCategoryAirFactory * categories.TECH2 + refCategoryAirFactory * categories.TECH3) == 0 then
            bWantMoreFactories = true
            iMaxToUpgrade = 2
        elseif aiBrain[M27Overseer.refbIncludeACUInAllOutAttack] == true then
            if aiBrain:GetEconomyStoredRatio('ENERGY') < 1 or aiBrain:GetEconomyStoredRatio('MASS') < 0.1 then
                iMaxToUpgrade = -1
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Still have decent resources so wont pause upgrades') end
            bNormalLogic = true
        end
    elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyLandRush then
        bNormalLogic = false

        if aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and aiBrain:GetEconomyStoredRatio('MASS') >= 0.5 and (iLandFactoryCount >= math.min(5, aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand]) or aiBrain:GetEconomyStoredRatio('MASS') >= 0.9) then
            if aiBrain:GetEconomyStoredRatio('MASS') >= 0.8 then
                bNormalLogic = true
            elseif aiBrain:GetEconomyStoredRatio('MASS') >= 0.7 and aiBrain[refiNetMassBaseIncome] > 0 then
                bNormalLogic = true
            elseif aiBrain:GetEconomyStoredRatio('MASS') >= 0.5 and aiBrain[refiNetMassBaseIncome] > 0.4 then
                bNormalLogic = true
            end
        elseif iLandFactoryCount >= 3 and aiBrain:GetEconomyStoredRatio('MASS') >= 0.85 and aiBrain[refiNetEnergyBaseIncome] >= 6 and (not(aiBrain[refbStallingEnergy]) or aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.5) then
            bNormalLogic = true
        end
        if bDebugMessages == true then LOG(sFunctionRef..': In land rush, bNormalLogic='..tostring(bNormalLogic)..'; Energy stored='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; Mass stored ratio='..aiBrain:GetEconomyStoredRatio('MASS')..'; Net mass income='.. aiBrain[refiNetMassBaseIncome]..'; Land Factory count='..iLandFactoryCount..'; Energy net income='..aiBrain[refiNetEnergyBaseIncome]..'; Are power stalling='..tostring(aiBrain[refbStallingEnergy])) end
    end
    if bNormalLogic then
        local tMassThresholds = {}
        aiBrain[refiMexesUpgrading], aiBrain[refiMexesAvailableForUpgrade] = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryT1Mex + refCategoryT2Mex)

        local iT1MexesNearBase = 0
        local tAllT1Mexes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT1Mex, false, true)
        if M27Utilities.IsTableEmpty(tAllT1Mexes) == false then
            for iT1Mex, oT1Mex in tAllT1Mexes do
                if M27UnitInfo.IsUnitValid(oT1Mex) and M27Utilities.GetDistanceBetweenPositions(oT1Mex:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 90 and M27Conditions.SafeToUpgradeUnit(oT1Mex) then
                    iT1MexesNearBase = iT1MexesNearBase + 1
                end
            end
        end
        local iT2MexesUpgrading, iT2MexesAvailableForUpgrade = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryT2Mex)

        local bWantHQEvenWithLowMass = false
        --If enemy has T3 air then want to get air factory asap
        if aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][3] > 0 and iAirFactoryCount > 0 and aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 and aiBrain[refiGrossMassBaseIncome] >= 4 and aiBrain[refiGrossEnergyBaseIncome] >= 130 then
            if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == true then
                bWantHQEvenWithLowMass = true
            else
                local bAlreadyUpgradingAir = false
                for iUnit, oUnit in aiBrain[reftUpgrading] do
                    if EntityCategoryContains(M27UnitInfo.refCategoryAirFactory, oUnit.UnitId) and M27UnitInfo.GetUnitTechLevel(oUnit) >= aiBrain[M27Overseer.refiOurHighestAirFactoryTech] then
                        bAlreadyUpgradingAir = true
                    end
                end
                if not(bAlreadyUpgradingAir) then bWantHQEvenWithLowMass = true end
            end
            if not(bWantHQEvenWithLowMass) and M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoLastNearestACU]) and aiBrain[M27Overseer.refoLastNearestACU]:HasEnhancement('AdvancedEngineering') and iLandFactoryCount > 0 and aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 1 and M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.refoLastNearestACU]:GetPosition()) <= 325 then
                if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == true then
                    bWantHQEvenWithLowMass = true
                else
                    local bAlreadyUpgradingLand = false
                    for iUnit, oUnit in aiBrain[reftUpgrading] do
                        if EntityCategoryContains(M27UnitInfo.refCategoryLandFactory, oUnit.UnitId) then
                            bAlreadyUpgradingLand = true
                        end
                    end
                    if not(bAlreadyUpgradingLand) then bWantHQEvenWithLowMass = true end
                end
            end
        end
        --Alternative to mass threshold - try and get an HQ even if we have low mass in certain cases
        if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == true then
            --Not got an existing HQ upgrade in progress; Do we already have a t3 factory but have another factory type of a lower tech level, and have 3+ T3 mexes?
            if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 and (aiBrain[M27Overseer.refiOurHighestLandFactoryTech] < 3 and iLandFactoryCount > 0) or (aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 and iAirFactoryCount > 0) then
                if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex) >= 3 or (aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 and iAirFactoryCount > 0 and aiBrain[refiGrossEnergyBaseIncome] >= 500 and aiBrain[refiGrossMassBaseIncome] >= 4) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Want to ugprade factory that has lower HQ to our highest HQ level; M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])))
                    end
                    bWantHQEvenWithLowMass = true
                end
            end
            if not(bWantHQEvenWithLowMass) then
                if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 1 and iLandFactoryCount + iAirFactoryCount > 0 and (aiBrain[M27Overseer.refiNearestEnemyT2PlusStructure] <= 200 or aiBrain[M27Overseer.refbEnemyGuncomApproachingBase]) then
                    bWantHQEvenWithLowMass = true
                end
            end
        end


        local iPausedMexes = 0
        if M27Utilities.IsTableEmpty(aiBrain[reftUpgrading]) == false then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Have paused units; size of table=' .. table.getn(aiBrain[reftPausedUnits]))
            end
            for iUnit, oUnit in aiBrain[reftUpgrading] do
                if M27UnitInfo.IsUnitValid(oUnit) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Upgrading unit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; Unit state=' .. M27Logic.GetUnitState(oUnit) .. '; IsPaused=' .. tostring(oUnit:IsPaused()) .. '; refbUpgradePaused=' .. tostring(oUnit[refbUpgradePaused]))
                    end
                    if oUnit[refbUpgradePaused] then
                        if EntityCategoryContains(M27UnitInfo.refCategoryMex, oUnit.UnitId) then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Unit is a mex so noting it as paused')
                            end
                            iPausedMexes = iPausedMexes + 1
                        end
                    end
                end
            end
        elseif bDebugMessages == true then
            LOG(sFunctionRef .. ': aiBrain[reftPausedUnits] is empty')
        end

        local bGetT2FactoryEvenWithLowMass = M27Conditions.DoWeWantPriorityT2LandFactoryHQ(aiBrain, iLandFactoryCount)

        --Does enemy have T2/T3? If so then want to upgrade core mexes in land attack mode (will already be doing this if in eco or turtle mode)
        local bNeedToUpgradeMexesByBase = false
        if not(aiBrain[refiMexPointsNearBase]) then
            aiBrain[refiMexPointsNearBase] = 0
            if M27Utilities.IsTableEmpty(M27MapInfo.tResourceNearStart[aiBrain.M27StartPositionNumber][1]) then
                M27Utilities.ErrorHandler('No mexes recorded near start of our base for brain index '..aiBrain:GetArmyIndex()..'; Start number '..(aiBrain.M27StartPositionNumber or 'nil')..';MassCount='..(M27MapInfo.MassCount or 'nil'))
            else
                for iMex, tMex in M27MapInfo.tResourceNearStart[aiBrain.M27StartPositionNumber][1] do
                    aiBrain[refiMexPointsNearBase] = aiBrain[refiMexPointsNearBase] + 1
                end
            end
        end
        if aiBrain[refiMexesUpgrading] - iPausedMexes <= 1 and (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyLandMain) and aiBrain[M27Overseer.refiEnemyHighestTechLevel] >= 2 then
            if aiBrain[M27Overseer.refiEnemyHighestTechLevel] >= 3 then
                if iT3MexCount < math.min(aiBrain[refiMexPointsNearBase], 3) or iT2MexCount + iT3MexCount < aiBrain[refiMexPointsNearBase] then
                    bNeedToUpgradeMexesByBase = true
                end
            elseif aiBrain[M27Overseer.refiEnemyHighestTechLevel] == 2 then
                if iT3MexCount + iT2MexCount < math.min(aiBrain[refiMexPointsNearBase], 3) then
                    bNeedToUpgradeMexesByBase = true
                end
            end
        end


        --Ecoing strategy - want to have a mex ugprading at all times regardless of mass income if we have mexes available to upgrade and arent getting an HQ upgrade and have at least 6 T1 mexes
        --Meanwhile if in land attack and have lots of t1 tanks then even if mass stalling want to start getting t2 land HQ

        if (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle or bNeedToUpgradeMexesByBase) and aiBrain[refiGrossMassBaseIncome] >= 1.4 and (aiBrain[refiMexesUpgrading] - iPausedMexes) <= 1 and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildT3MexOverT2]) and (aiBrain[refiMexesAvailableForUpgrade] > 0 or iPausedMexes > 0) and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) then
            tMassThresholds[1] = { 0, -15 }
            if bDebugMessages == true then LOG(sFunctionRef..': Want to have at least 1 unit/mex upgrading as a high priority even if mass stalling. aiBrain[M27Overseer.refiAIBrainCurrentStrategy]='..aiBrain[M27Overseer.refiAIBrainCurrentStrategy]..'; aiBrain[refiGrossMassBaseIncome]='..aiBrain[refiGrossMassBaseIncome]..'; aiBrain[refiMexesUpgrading]='..aiBrain[refiMexesUpgrading]..'; iPausedMexes='..iPausedMexes..'; will get an upgrade even if are mass stalling') end
        elseif bGetT2FactoryEvenWithLowMass or bWantHQEvenWithLowMass or (aiBrain[refiPausedUpgradeCount] >= 1 and table.getn(aiBrain[reftUpgrading]) <= 1) then
            --Want to resume unless we're energy stalling
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Have paused upgrades, and nothing is currently upgrading, so want to resume one of the upgrades hence setting mass thresholds really low')
            end
            tMassThresholds[1] = { 0, -2.0 }
            tMassThresholds[2] = { 500, -8 }
            tMassThresholds[3] = { 1000, -25 }
            tMassThresholds[4] = { 2500, -200 }
        elseif (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle) and ((aiBrain[refiPausedUpgradeCount] >= 1 and iPausedMexes == aiBrain[refiMexesUpgrading]) or (aiBrain[refiMexesUpgrading] <= 0 and aiBrain[refiMexesAvailableForUpgrade] > 0 and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildT3MexOverT2]) == true)) then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Want to eco but dont have any active mex upgrades')
            end
            tMassThresholds[1] = { 0, -100.0 }
            tMassThresholds[2] = { 1000, -200 }
        elseif (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle) and iT2MexesUpgrading <= 0 and (iPausedMexes > 0 or (M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildT3MexOverT2]) == true and aiBrain[refiMexesUpgrading] <= iT1MexesNearBase and aiBrain[refiMexesAvailableForUpgrade] > 0)) then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Want to eco, dont have any active t2 upgrades, so will either unpause paused mex upgrades, or will start a new upgrade if we arent planning to ctrl-K a T2 mex')
            end
            local iFullStorageAmount = 1000 --Base value for if we have 0% stored ratio
            tMassThresholds[1] = { math.min(400, iFullStorageAmount * 0.1), 0.0 }
            tMassThresholds[2] = { math.min(800, iFullStorageAmount * 0.15), -0.3 }
            tMassThresholds[3] = { math.min(1300, iFullStorageAmount * 0.35), -1 }
            tMassThresholds[4] = { math.min(1500, iFullStorageAmount * 0.45), -2 }
            tMassThresholds[5] = { math.min(2000, iFullStorageAmount * 0.55), -3 }
            tMassThresholds[6] = { iFullStorageAmount * 0.8, -4 }
            tMassThresholds[7] = { iFullStorageAmount * 0.98, -10 }
        else
            --Not in eco mode, if is early game then dont want to upgrade anything unless significant mass income
            if not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle) and aiBrain[refiGrossMassBaseIncome] < 2 and GetGameTimeSeconds() <= 360 then
                tMassThresholds[1] = {500, 0.1}
                tMassThresholds[2] = {600, 0}
                tMassThresholds[3] = {750, -0.2}
                tMassThresholds[4] = {795, -0.5}
            else

                --If not upgrading anything and have t1 mexes near base, or enemy is at t3 and we dont have all t3 mexes, then consider upgrading as high priority
                local iAvailableT1MexesNearBase = 0
                local iMexesNearStart = table.getn(M27MapInfo.tResourceNearStart[aiBrain.M27StartPositionNumber][1])
                local tNearbyT1Mexes = aiBrain:GetUnitsAroundPoint(refCategoryT1Mex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 35, 'Ally')
                for iMex, oMex in tNearbyT1Mexes do
                    if not(oMex:IsUnitState('Upgrading')) then iAvailableT1MexesNearBase = iAvailableT1MexesNearBase + 1 end
                end
                --Below threshold for mexes is <=1 so we dont keep pausing the mex just after telling it to upgrade
                if iAvailableT1MexesNearBase > 0 and (aiBrain[refiMexesUpgrading] - iPausedMexes) <= 1 and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) and (iLandFactoryCount + iAirFactoryCount >= 3 or GetGameTimeSeconds() >= 300 or aiBrain[refiGrossMassBaseIncome] >= 2) then
                    --Want to get a t2 mex upgrade so our mass income is always increasing
                    if aiBrain[refiGrossMassBaseIncome] >= 3 then
                        tMassThresholds[1] = {0, -2}
                        tMassThresholds[2] = {100, -2.5}
                        tMassThresholds[3] = {250, -3.5}
                        tMassThresholds[4] = {400, -6}
                    elseif aiBrain[refiGrossMassBaseIncome] >= 1.8 then
                        tMassThresholds[1] = { 0, -0.2}
                        tMassThresholds[2] = {50, 0.4}
                        tMassThresholds[3] = {100, 0.3}
                        tMassThresholds[4] = {150, 0}
                        tMassThresholds[5] = {200, -0.3}
                        tMassThresholds[6] = {300, -0.5}
                        tMassThresholds[7] = {400, -1}
                        tMassThresholds[8] = {600, -2}
                    else
                        tMassThresholds[1] = { 0, 0.5}
                        tMassThresholds[2] = {50, 0.4}
                        tMassThresholds[3] = {100, 0.3}
                        tMassThresholds[4] = {150, 0}
                        tMassThresholds[5] = {200, -0.3}
                        tMassThresholds[6] = {300, -0.5}
                        tMassThresholds[7] = {400, -1}
                        tMassThresholds[8] = {600, -2}
                    end
                    --Upgrade if enemy at T3 and we have mexes near our base not at T3
                elseif (aiBrain[refiMexesUpgrading] - iPausedMexes) <= 1 and iMexesNearStart < (aiBrain[refiMexesUpgrading] + 1 + iT3MexCount) and aiBrain[M27Overseer.refiEnemyHighestTechLevel] >= 3 and aiBrain[refiGrossMassBaseIncome] >= 3 and not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyProtectACU) and not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill) then
                    tMassThresholds[1] = {0, -2}
                    tMassThresholds[2] = {100, -2.5}
                    tMassThresholds[3] = {250, -3.5}
                    tMassThresholds[4] = {400, -6}


                elseif aiBrain[refiGrossMassBaseIncome] <= 7 then

                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Arent ecoing and our mass income is less tahn 70 mass per sec')
                    end
                    tMassThresholds[1] = { 400, 1 }
                    tMassThresholds[2] = { 500, 0.5 }
                    tMassThresholds[3] = { 600, 0.1 }
                    tMassThresholds[4] = { 700, -0.1 }
                    tMassThresholds[5] = { 750, -0.2 }
                else
                    local iFullStorageAmount = 1000 --Base value for if we have 0% stored ratio
                    if aiBrain:GetEconomyStoredRatio('MASS') > 0 then
                        iFullStorageAmount = aiBrain:GetEconomyStored('MASS') / aiBrain:GetEconomyStoredRatio('MASS')
                    end

                    --Are we not upgrading any mexes (and have at least 70 mass per tick given above condition)?
                    if aiBrain[refiMexesUpgrading] == 0 and aiBrain[refiMexesAvailableForUpgrade] > 0 then
                        tMassThresholds[1] = {0, -2}
                        tMassThresholds[2] = { math.min(500, iFullStorageAmount * 0.1), -3 }
                        tMassThresholds[3] = { math.min(1000, iFullStorageAmount * 0.15), -3.5 }
                        tMassThresholds[4] = { math.min(1500, iFullStorageAmount * 0.35), -4.5 }
                        tMassThresholds[5] = { math.min(3000, iFullStorageAmount * 0.55), -7 }
                        if bDebugMessages == true then LOG(sFunctionRef..': Have no mexes upgrading so using significantly lower thresholds') end
                    else
                        --Are we already upgrading a T2 mex, and either have recently powerstalled, or dont have much gross mass income (so we probably cant support multiple mex upgrades)
                        if iT2MexesUpgrading > 0 and (GetGameTimeSeconds() - aiBrain[refiLastEnergyStall] <= 45 or aiBrain[refiGrossMassBaseIncome] <= 7.5) then
                            tMassThresholds[1] = { math.min(750, iFullStorageAmount * 0.1), 2.4 }
                            tMassThresholds[2] = { math.min(1500, iFullStorageAmount * 0.15), 1.2 }
                            tMassThresholds[3] = { math.min(2000, iFullStorageAmount * 0.35), 0.6 }
                            tMassThresholds[4] = { math.min(2500, iFullStorageAmount * 0.45), 0.2 }
                            tMassThresholds[5] = { math.min(3000, iFullStorageAmount * 0.55), 0 }
                            tMassThresholds[6] = { iFullStorageAmount * 0.8, -0.2 }
                            tMassThresholds[7] = { iFullStorageAmount * 0.9, -1.5 }
                        else
                            --if aiBrain[refiPausedUpgradeCount] > 1 or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
                            tMassThresholds[1] = { math.min(500, iFullStorageAmount * 0.1), 0.1 }
                            tMassThresholds[2] = { math.min(1000, iFullStorageAmount * 0.15), 0 }
                            tMassThresholds[3] = { math.min(1500, iFullStorageAmount * 0.35), -0.5 }
                            tMassThresholds[4] = { math.min(1750, iFullStorageAmount * 0.45), -1.5 }
                            tMassThresholds[5] = { math.min(3000, iFullStorageAmount * 0.55), -2.5 }
                            tMassThresholds[6] = { iFullStorageAmount * 0.8, -4 }
                            tMassThresholds[7] = { iFullStorageAmount * 0.98, -10 }
                        end
                    end
                end
            end
        end

        --Increase thresholds if we're trying to build a missile
        if aiBrain[M27EngineerOverseer.refbNeedResourcesForMissile] then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Are trying to buidl a missile so will decrease thresholds')
            end
            for iThresholdRef, tThreshold in tMassThresholds do
                tMassThresholds[iThresholdRef][1] = tMassThresholds[iThresholdRef][1] + math.max(500, tMassThresholds[iThresholdRef][1] * 0.5)
                tMassThresholds[iThresholdRef][2] = tMassThresholds[iThresholdRef][2] + 1
            end
        end
        --Increase thresholds if we have high eco, as want to keep upgrading with some of our mass if we can
        if aiBrain[refiGrossMassBaseIncome] >= 20 then
            for iThresholdRef, tThreshold in tMassThresholds do
                if tMassThresholds[iThresholdRef][2] < 0 then tMassThresholds[iThresholdRef][2] = tMassThresholds[iThresholdRef][2] * 2
                elseif tMassThresholds[iThresholdRef][2] > 0 then tMassThresholds[iThresholdRef][2] = tMassThresholds[iThresholdRef][2] * 0.5 end
            end
        end


        --Increase thresholds if we are trying to ctrl-K a mex
        if aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByActionRef][M27EngineerOverseer.refActionBuildT3MexOverT2]) == false then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Trying to ctrlK a mex so increasing mass thresholds; will produce tMassThresholds below')
                if M27Utilities.IsTableEmpty(tMassThresholds) then
                    M27Utilities.ErrorHandler('tMassThresholds is empty')
                else
                    LOG(repru(tMassThresholds))
                end
            end

            for iThresholdRef, tThreshold in tMassThresholds do
                tMassThresholds[iThresholdRef][1] = tMassThresholds[iThresholdRef][1] + 2000
            end
        end

        aiBrain[refbWantMoreFactories] = bWantMoreFactories

        for _, tThreshold in tMassThresholds do
            if iMassStored >= tThreshold[1] and iMassNetIncome >= tThreshold[2] then
                bHaveHighMass = true
                break
            end
        end

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Finished calculating mass thresholds=' .. repru(tMassThresholds) .. '; bHaveHighmass=' .. tostring(bHaveHighMass) .. '; iPausedMexes=' .. iPausedMexes .. '; aiBrain[refiMexesUpgrading]=' .. aiBrain[refiMexesUpgrading])
            LOG(sFunctionRef .. ': bWantMoreFactories=' .. tostring(bWantMoreFactories) .. '; iLandFactoryCount=' .. iLandFactoryCount .. '; iMexesOnOurSideOfMap=' .. iMexesOnOurSideOfMap .. '; bHaveHighMass=' .. tostring(bHaveHighMass) .. '; iMassStored=' .. iMassStored .. '; iMassNetIncome=' .. iMassNetIncome)
        end

        --Low mass override
        if M27Conditions.HaveLowMass(aiBrain) == true and (aiBrain[refiMexesUpgrading] - iPausedMexes) >= 2 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Low mass override - standard low mass condition is failed, and are upgrading more than 1 mex at once, so want to pause one of them')
            end
            bHaveHighMass = false
        end

        if bHaveHighMass == true then
            if not (aiBrain[refbStallingEnergy]) or (aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and aiBrain[refiNetEnergyBaseIncome] >= 25) then
                --Do we have any power plants of the current tech level? If not, then hold off on upgrades until we do, unless we have lots of power already
                if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] <= 1 or aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * M27UnitInfo.ConvertTechLevelToCategory(aiBrain[M27Overseer.refiOurHighestFactoryTechLevel])) > 0 or (aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and aiBrain[refiGrossEnergyBaseIncome] > 25 * aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] * (aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] - 1)) then
                    --Have we powerstalled at T2+ in last 15s?
                    local iPowerStallThreshold = 15
                    if aiBrain[refiGrossEnergyBaseIncome] - aiBrain[refiGrossEnergyWhenStalled] >= 45 then
                        iPowerStallThreshold = 5
                        if aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 then iPowerStallThreshold = 2.5 end
                    end
                    if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] <= 1 or GetGameTimeSeconds() - aiBrain[refiLastEnergyStall] >= iPowerStallThreshold then
                        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                            --Want more energy if in air dominance to avoid risk we start upgrading and cant produce bombers
                            if iEnergyPercentStorage > 0.8 and iEnergyStored > 3500 and iEnergyNetIncome > 4 and iEnergyChangeFromLastCycle > 0 then
                                bHaveEnoughEnergy = true
                            elseif iEnergyPercentStorage >= 0.99 then
                                bHaveEnoughEnergy = true
                            end
                        else
                            if iEnergyChangeFromLastCycle > 0 then
                                if iEnergyNetIncome > 4 and iEnergyStored > 1500 and iEnergyPercentStorage > 0.4 then
                                    bHaveEnoughEnergy = true
                                elseif iEnergyNetIncome > 2 and iEnergyStored > 2500 and iEnergyPercentStorage > 0.5 then
                                    bHaveEnoughEnergy = true
                                end
                            elseif iEnergyNetIncome > 5 and iEnergyStored > 2500 and iEnergyPercentStorage > 0.8 then
                                bHaveEnoughEnergy = true
                            elseif iEnergyPercentStorage >= 0.99 then
                                bHaveEnoughEnergy = true
                            elseif  aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 1 and iEnergyNetIncome >= 6 then
                                bHaveEnoughEnergy = true
                            end
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Have high mass, bHaveEnoughEnergy=' .. tostring(bHaveEnoughEnergy))
                        end
                        if bHaveEnoughEnergy then
                            local iGameTime = GetGameTimeSeconds()
                            --Do we have lots of resources?
                            if iMassStored > 800 and iMassNetIncome > 0.2 and iEnergyNetIncome > 4 and iEnergyStored > 1000 then
                                bHaveLotsOfResources = true
                            elseif iMassStored > 2000 and iEnergyPercentStorage >= 0.99 then
                                bHaveLotsOfResources = true
                            end
                            if iGameTime > 180 then
                                --Dont consider upgrading at start of game
                                iMaxToUpgrade = 1
                                if bHaveLotsOfResources == true then
                                    iMaxToUpgrade = 20
                                elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech and aiBrain[refiMexesUpgrading] <= 0 then
                                    iMaxToUpgrade = 2
                                end
                            end
                            --Backup for unusual scenarios - are we about to overflow mass and have high energy stored and have positive mass and energy income? then upgrade with no limit
                            if (iEnergyPercentStorage >= 0.99 or iEnergyNetIncome > 5) and (aiBrain:GetEconomyStoredRatio('MASS') >= 0.7 or iMassStored >= 2000) then
                                iMaxToUpgrade = 100
                            elseif bHaveLotsOfResources == true and aiBrain:GetEconomyStoredRatio('ENERGY') > 0.9 and aiBrain:GetEconomyStoredRatio('MASS') > 0.7 then
                                iMaxToUpgrade = 1000
                            end
                        end
                    else
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Are at T2+ and have powerstalled in last '..iPowerStallThreshold..' seconds. GetGameTimeSeconds() - aiBrain[refiLastEnergyStall]='..GetGameTimeSeconds() - (aiBrain[refiLastEnergyStall] or -100)..'; iEnergyPercentStorage='..iEnergyPercentStorage..'; aiBrain[refiNetEnergyBaseIncome]='..aiBrain[refiNetEnergyBaseIncome]..'; aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]='..aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]..'; Energy when last stalled='..aiBrain[refiGrossEnergyWhenStalled])
                            --still ok to upgrade a max of 1 if we have good power (500 net at T2, 1k net at T3)
                            if iEnergyPercentStorage >= 0.99 and aiBrain[refiNetEnergyBaseIncome] >= 25 * aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] * (aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] - 1) then
                                iMaxToUpgrade = 1
                            end
                        end
                    end
                elseif bDebugMessages == true then
                    LOG(sFunctionRef .. ': Are stalling energy and dont have 100% stored with decent net income')
                end
            elseif bDebugMessages == true then
                LOG(sFunctionRef .. ': Are stalling energy so wont upgrade more')
            end
        end

        if iMaxToUpgrade == 0 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Dont have enough resources to upgrade, checking if should pause upgrades')
            end
            --Check for low energy amounts
            local bLowEnergy = aiBrain[refbStallingEnergy]
            if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 1 then
                if iEnergyStored <= 250 and iEnergyNetIncome < 0 then
                    bLowEnergy = true
                elseif iEnergyStored <= 50 then
                    bLowEnergy = true
                end
            elseif (aiBrain:GetEconomyStoredRatio('ENERGY') < 0.4 and iEnergyNetIncome < 0) or aiBrain:GetEconomyStoredRatio('ENERGY') < 0.2 then
                bLowEnergy = true
            end

            if bLowEnergy == true then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Have low energy so will flag we want to pause an upgrade')
                end
                iMaxToUpgrade = -1
                aiBrain[refbPauseForPowerStall] = true
            else
                --Check for mass stall if we have more than 1 mex or any factories upgrading, or have nearby enemy
                local iLandFactoryUpgrading, iLandFactoryAvailable, bAlreadyUpgradingLandHQ = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryLandFactory)
                local iAirFactoryUpgrading, iAirFactoryAvailable, bAlreadyUpgradingAirHQ = GetTotalUnitsCurrentlyUpgradingAndAvailableForUpgrade(aiBrain, refCategoryAirFactory)

                if (aiBrain[refiMexesUpgrading] - iPausedMexes) > 1 or iLandFactoryUpgrading + iAirFactoryUpgrading > 0 or aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= 100 or aiBrain[M27Overseer.refiPercentageOutstandingThreat] <= 0.3 then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Checking if stalling mass; iMassStored=' .. iMassStored .. '; aiBrain:GetEconomyStoredRatio(MASS)=' .. aiBrain:GetEconomyStoredRatio('MASS') .. '; iMassNetIncome=' .. iMassNetIncome)
                    end
                    if (M27Conditions.HaveLowMass(aiBrain) and aiBrain[refiMexesUpgrading] + iLandFactoryUpgrading + iAirFactoryUpgrading >= 2) or (iMassStored <= 60 or aiBrain:GetEconomyStoredRatio('MASS') <= 0.06) and iMassNetIncome < 0.2 then
                        aiBrain[refbPauseForPowerStall] = false
                        iMaxToUpgrade = -1
                    end
                end
            end

        end
    end

    aiBrain[refiEnergyStoredLastCycle] = iEnergyStored

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code, iMaxToUpgrade=' .. iMaxToUpgrade .. '; iMassStored=' .. iMassStored .. '; bHaveHighMass=' .. tostring(bHaveHighMass) .. '; iMassNetIncome=' .. iMassNetIncome .. '; iEnergyNetIncome=' .. iEnergyNetIncome .. '; iEnergyStored=' .. iEnergyStored .. '; iEnergyPercentStorage=' .. iEnergyPercentStorage .. '; iEnergyChangeFromLastCycle=' .. iEnergyChangeFromLastCycle .. '; bHaveEnoughEnergy=' .. tostring(bHaveEnoughEnergy))
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iMaxToUpgrade
end

function RefreshEconomyData(aiBrain)
    --Yes, hardcoding resource values will make it really hard to support mods or patches that change these values
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RefreshEconomyData'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iACUMass = 1
    local iACUEnergy = 20
    local iEnergyT3Power = 2500
    local iEnergyT2Power = 500
    local iEnergyT1Power = 20
    local iEnergyHydro = 100
    local iT1MexMass = 2
    local iT2MexMass = 6
    local iT3MexMass = 18
    local iParagonMass = 10000
    local iParagonEnergy = 1000000

    local iRASSACUMass = 11
    local iRASSACUEnergy = 1020
    local iSeraphimSACUMass = 2
    local iSeraphimSACUEnergy = 200

    local iT3PowerCount, iT2PowerCount, iT1PowerCount, iHydroCount, iT1MexCount, iT2MexCount, iT3MexCount, iParagonCount, iRASSACUCount, iSeraphimSACUCount

    iT1PowerCount = aiBrain:GetCurrentUnits(refCategoryT1Power)
    iT2PowerCount = aiBrain:GetCurrentUnits(refCategoryT2Power)
    iT3PowerCount = aiBrain:GetCurrentUnits(refCategoryT3Power)
    iHydroCount = aiBrain:GetCurrentUnits(refCategoryHydro)
    iT1MexCount = aiBrain:GetCurrentUnits(refCategoryT1Mex)
    iT2MexCount = aiBrain:GetCurrentUnits(refCategoryT2Mex)
    iT3MexCount = aiBrain:GetCurrentUnits(refCategoryT3Mex)
    iParagonCount = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryParagon)
    iRASSACUCount = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryRASSACU - categories.SERAPHIM)
    iSeraphimSACUCount = aiBrain:GetCurrentUnits(categories.SUBCOMMANDER * categories.SERAPHIM)
    local tMassStorage = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryMassStorage, false, true)
    local iStorageIncomeBoost = 0
    local tMexByStorage
    local tCurPos
    local tMexMidpoint
    local iMexSize = 0.5
    local oCurBP
    if M27Utilities.IsTableEmpty(tMassStorage) == false then
        local tPositionAdj = {
            { -1, -1 },
            { -1, 1 },
            { 1, -1 },
            { 1, 1 }
        }

        for iStorage, oStorage in tMassStorage do
            --Check nearby mex adjacency
            tCurPos = oStorage:GetPosition()
            for iCurAdj = 1, 4 do
                tMexMidpoint = { tCurPos[1] + tPositionAdj[iCurAdj][1], 0, tCurPos[3] + tPositionAdj[iCurAdj][2] }
                tMexMidpoint[2] = GetSurfaceHeight(tMexMidpoint[1], tMexMidpoint[3])
                tMexByStorage = GetUnitsInRect(Rect(tMexMidpoint[1] - iMexSize, tMexMidpoint[3] - iMexSize, tMexMidpoint[1] + iMexSize, tMexMidpoint[3] + iMexSize))
                if M27Utilities.IsTableEmpty(tMexByStorage) == false then
                    tMexByStorage = EntityCategoryFilterDown(M27UnitInfo.refCategoryMex, tMexByStorage)
                    if M27Utilities.IsTableEmpty(tMexByStorage) == false then
                        if tMexByStorage[1].GetBlueprint and not (tMexByStorage[1].Dead) and tMexByStorage[1].GetAIBrain and tMexByStorage[1]:GetAIBrain() == aiBrain then
                            oCurBP = tMexByStorage[1]:GetBlueprint()
                            if oCurBP.Economy and oCurBP.Economy.ProductionPerSecondMass then
                                iStorageIncomeBoost = iStorageIncomeBoost + oCurBP.Economy.ProductionPerSecondMass * 0.125
                            end
                        end
                    end
                end
            end
        end
    end


    local iPerTickFactor = 0.1

    local iCheatMod = 1
    if aiBrain.CheatEnabled then
        iCheatMod = tonumber(ScenarioInfo.Options.CheatMult) or 2 --.CheatMult is the resource bonus; Build bonus is .BuildMult
    end
    aiBrain[refiGrossEnergyBaseIncome] = (iParagonCount * iParagonEnergy + iACUEnergy + iT3PowerCount * iEnergyT3Power + iT2PowerCount * iEnergyT2Power + iT1PowerCount * iEnergyT1Power + iHydroCount * iEnergyHydro + iRASSACUCount * iRASSACUEnergy + iSeraphimSACUCount * iSeraphimSACUEnergy) * iPerTickFactor * iCheatMod

    --Assume any T2 and T3 arti will be firing constantly to be safe; EconomyRequested gives a per tick value
    local iEnergyUsage = math.max(aiBrain:GetEconomyRequested('ENERGY') - aiBrain[refiGrossEnergyBaseIncome], -(aiBrain:GetEconomyTrend('ENERGY') - aiBrain:GetEconomyIncome('ENERGY'))) + aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryFixedT2Arti) * 10 - aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategoryExperimentalArti) * 400 + aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryQuantumOptics) * 250
    local iMassUsage = math.max(aiBrain:GetEconomyRequested('MASS'), -(aiBrain:GetEconomyTrend('MASS') - aiBrain:GetEconomyIncome('MASS')))

    --Net energy in theory is meant to ignore benefit of tree reclaim, however there are some flaws as sometimes especially late game it can show with a positive value despite trend being negative.  Will therefore use the lower of the two
    aiBrain[refiNetEnergyBaseIncome] = math.min(aiBrain[refiGrossEnergyBaseIncome] - iEnergyUsage, aiBrain:GetEconomyTrend('ENERGY'))
    aiBrain[refiGrossMassBaseIncome] = (iParagonCount * iParagonMass + iACUMass + iT3MexMass * iT3MexCount + iT2MexMass * iT2MexCount + iT1MexMass * iT1MexCount + iStorageIncomeBoost + iRASSACUCount * iRASSACUMass + iSeraphimSACUCount * iSeraphimSACUMass) * iPerTickFactor * iCheatMod
    aiBrain[refiNetMassBaseIncome] = aiBrain[refiGrossMassBaseIncome] - iMassUsage

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': aiBrain[refiGrossEnergyBaseIncome]=' .. aiBrain[refiGrossEnergyBaseIncome] .. '; aiBrain[refiNetEnergyBaseIncome]=' .. aiBrain[refiNetEnergyBaseIncome] .. '; iT2PowerCount=' .. iT2PowerCount .. '; iEnergyT1Power=' .. iEnergyT1Power .. '; iEnergyUsage=' .. iEnergyUsage)
    end

    --Increase gross and net base income for M27 teammate overflow
    if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains]) == false then
        local iSizeOfTeam = 1
        for iBrain, oBrain in aiBrain[M27Overseer.toAllyBrains] do
            iSizeOfTeam = iSizeOfTeam + 1
        end
        local iExtraEnergy = 0
        local iExtraMass = 0
        for iBrain, oBrain in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] do
            if not(oBrain == aiBrain) then
                if oBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and oBrain[refiGrossEnergyBaseIncome] < iParagonEnergy then iExtraEnergy = oBrain[refiNetEnergyBaseIncome] end
                if oBrain:GetEconomyStoredRatio('MASS') >= 0.99 and oBrain[refiGrossMassBaseIncome] < iParagonMass then iExtraMass = oBrain[refiNetMassBaseIncome] end
            end
        end
        if iExtraEnergy > 0 then
            --Assume we will get half of our share of the power overflow (only half since a risk it gets stopped at a moments notice)
            aiBrain[refiNetEnergyBaseIncome] = aiBrain[refiNetEnergyBaseIncome] + 0.5 * iExtraEnergy / iSizeOfTeam
        end
        if iExtraMass > 0 then
            aiBrain[refiNetMassBaseIncome] = aiBrain[refiNetMassBaseIncome] + 0.5 * iExtraMass / iSizeOfTeam
        end
    end

    --Give mexes to teammate
    if iParagonCount > 0 and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.toAllyBrains]) == false and (iT1MexCount + iT2MexCount + iT3MexCount) > 0 then
        ForkThread(M27Team.GiveResourcesToAllyDueToParagon, aiBrain)
    end


    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpgradeMainLoop(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpgradeManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    if (M27Logic.iTimeOfLastBrainAllDefeated or 0) < 10 then

        local iCategoryToUpgrade, oUnitToUpgrade
        local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local iMaxToBeUpgrading, iAmountToUpgradeAfterUnpausing

        aiBrain[refbWantToUpgradeMoreBuildings] = false --default

        iMaxToBeUpgrading = DecideMaxAmountToBeUpgrading(aiBrain)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': iMaxToBeUpgrading=' .. iMaxToBeUpgrading)
        end

        if iMaxToBeUpgrading >= 1 then
            --Unpause any already upgrading units first
            iAmountToUpgradeAfterUnpausing = math.max(iMaxToBeUpgrading - aiBrain[refiPausedUpgradeCount], 0)
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Checking if upgrades to be unpaused; iPausedUpgradeCount=' .. (aiBrain[refiPausedUpgradeCount] or 0))
            end
            UnpauseUpgrades(aiBrain, iMaxToBeUpgrading)
            if bDebugMessages == true then
                LOG(sFunctionRef .. '; iAmountToUpgradeAfterUnpausing=' .. iAmountToUpgradeAfterUnpausing .. '; Paused upgrade count=' .. (aiBrain[refiPausedUpgradeCount] or 0))
            end
            if iAmountToUpgradeAfterUnpausing > 0 then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': WIll look for a category to start upgrading as well')
                end
                iCategoryToUpgrade = DecideWhatToUpgrade(aiBrain, iMaxToBeUpgrading)

                if iCategoryToUpgrade then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Got category to upgrade')
                    end
                    oUnitToUpgrade = GetUnitToUpgrade(aiBrain, iCategoryToUpgrade, tStartPosition)
                    if oUnitToUpgrade then
                        aiBrain[refiFailedUpgradeUnitSearchCount] = 0
                    else --Unit to upgrade is nil
                        aiBrain[refiFailedUpgradeUnitSearchCount] = aiBrain[refiFailedUpgradeUnitSearchCount] + 1
                        --One possible explanation for htis is that there are enemies near the units of the category wanted
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Couldnt find unit to upgrade, will revert to default categories, starting with T1 mex')
                        end
                        oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryT1Mex, tStartPosition)
                        if oUnitToUpgrade == nil and (aiBrain[refiFailedUpgradeUnitSearchCount] >= 30 or (not(M27Conditions.HaveLowMass(aiBrain)) and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and not(aiBrain[refbStallingEnergy]) and (aiBrain[refiGrossMassBaseIncome] >= 4 or aiBrain:GetEconomyStoredRatio('MASS') >= 0.9))) then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Will look for T2 mex if our failure count is high')
                            end
                            oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryT2Mex, tStartPosition)
                            if oUnitToUpgrade == nil then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Will look for T1 land factory')
                                end
                                oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryLandFactory * categories.TECH1, tStartPosition)
                                if oUnitToUpgrade == nil then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Will look for T1 air factory')
                                    end
                                    oUnitToUpgrade = GetUnitToUpgrade(aiBrain, M27UnitInfo.refCategoryAirFactory * categories.TECH1, tStartPosition)
                                    if oUnitToUpgrade == nil then
                                        local iT2PlusEngis = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer - categories.TECH1)
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Will look for T2 land factory unless our highest tech level is T2 and we lack 2 T2 engineers. iT2PlusEngis='..iT2PlusEngis..'; Highest tech level='..aiBrain[M27Overseer.refiOurHighestFactoryTechLevel])
                                        end
                                        if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 or iT2PlusEngis >= 2 then oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryLandFactory * categories.TECH2, tStartPosition) end

                                        if oUnitToUpgrade == nil then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Will look for T2 air factory')
                                            end
                                            if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 or iT2PlusEngis >= 2 then oUnitToUpgrade = GetUnitToUpgrade(aiBrain, refCategoryAirFactory * categories.TECH2, tStartPosition) end
                                            if oUnitToUpgrade == nil then
                                                --Upgrade T2 shields (and Cybran ED4) if we have any and have very high resources
                                                if bDebugMessages == true then LOG(sFunctionRef..': If about to overflow mass then will upgrade T2 shields if have any. aiBrain:GetEconomyStoredRatio(MASS)='..aiBrain:GetEconomyStoredRatio('MASS')..'; Energy net income='..aiBrain[refiNetEnergyBaseIncome]..'; Total number of T2 shields='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryFixedShield * categories.TECH2)) end
                                                if aiBrain:GetEconomyStoredRatio('MASS') >= 0.8 and aiBrain[refiNetEnergyBaseIncome] >= 50 then
                                                    oUnitToUpgrade = GetUnitToUpgrade(aiBrain, M27UnitInfo.refCategoryFixedShield * categories.TECH2 + M27UnitInfo.refCategoryFixedShield * categories.TECH3 * categories.CYBRAN * categories.CQUEMOV, tStartPosition)
                                                end
                                                if oUnitToUpgrade == nil then
                                                    --Consider upgrading naval factory
                                                    if aiBrain[refiGrossMassBaseIncome] >= 5 then
                                                        oUnitToUpgrade = GetUnitToUpgrade(aiBrain, M27UnitInfo.refCategoryNavalFactory * categories.TECH1, tStartPosition)
                                                        if not(oUnitToUpgrade) and aiBrain[refiGrossMassBaseIncome] >= 10 then
                                                            oUnitToUpgrade = GetUnitToUpgrade(aiBrain, M27UnitInfo.refCategoryNavalFactory * categories.TECH2, tStartPosition)
                                                        end
                                                    end
                                                    if not(oUnitToUpgrade) then


                                                        --FOR DEBUG ONLY: Is it unexpected that there is nothing to upgrade?

                                                        --Do we have enemies within 100 of our base? if so then this is probably why we cant find anything to upgrade as buildings check no enemies within 90
                                                        if M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) and aiBrain[M27Overseer.refiModDistFromStartNearestThreat] > 150 then
                                                            --Do we have any T1 or T2 factories or mexes within 100 of our base? If not, then we have presumably run out of units to upgrade
                                                            local tNearbyUpgradables = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAllFactories + M27UnitInfo.refCategoryMex - categories.TECH3 - categories.EXPERIMENTAL, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 100, 'Ally')
                                                            if M27Utilities.IsTableEmpty(tNearbyUpgradables) == false then
                                                                --Do we own any of these
                                                                for iUpgradable, oUpgradable in tNearbyUpgradables do
                                                                    if oUpgradable:GetAIBrain() == aiBrain and not (oUpgradable:IsUnitState('Upgrading')) then
                                                                        M27Utilities.ErrorHandler('Couldnt find unit to upgrade after trying all backup options; oUpgradable='..oUpgradable.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUpgradable)..'; Unit state='..M27Logic.GetUnitState(oUpgradable)..'; nearest enemy to base=' .. math.floor(aiBrain[M27Overseer.refiModDistFromStartNearestThreat]) .. '; Have a T2 or below mex or factory within 100 of our base, which includes ' .. oUpgradable.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUpgradable), true)
                                                                        break
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
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Couldnt find a unit to upgrade of desired category, failure count='..aiBrain[refiFailedUpgradeUnitSearchCount]) end
                        end
                    end
                    if oUnitToUpgrade and not (oUnitToUpgrade.Dead) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': About to try and upgrade unit ID=' .. oUnitToUpgrade.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnitToUpgrade))
                        end
                        UpgradeUnit(oUnitToUpgrade, true)
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Finished sending order to upgrade unit')
                        end
                    else
                        if bDebugMessages == true then
                            LOG('Couldnt get a unit to upgrade despite trying alternative categories.  Likely cause is that we have enemies near our base meaning poor defence coverage')
                        end
                    end
                else
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Dont have anything to upgrade')
                    end
                end
                if iAmountToUpgradeAfterUnpausing > 2 then
                    aiBrain[refbWantToUpgradeMoreBuildings] = true
                end
            end
        elseif iMaxToBeUpgrading < 0 then
            --Need to pause
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': We need to pause an upgrade')
            end
            PauseLastUpgrade(aiBrain)
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)

end

function GetCategoriesAndActionsToPause(aiBrain, bStallingMass)
    local tCategoriesByPriority, tEngineerActionsByPriority
    if bStallingMass then
        --Simplified non-strategy dependent logic for now except if want to prioritise early strat or are in air dominatino mode
        if aiBrain[M27Overseer.refbT2NavyNearOurBase] then
            --(smd is high priority because it only gets paused if it has 1 missile)
            tCategoriesByPriority = { M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryEngineerStation, M27UnitInfo.refCategoryRASSACU, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryAirFactory, iSpecialHQCategory, M27UnitInfo.refCategoryTML, categories.COMMAND, M27UnitInfo.refCategoryEngineer }
        else
            tCategoriesByPriority = { M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryEngineerStation, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryRASSACU, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryAirFactory, iSpecialHQCategory, M27UnitInfo.refCategoryT2Mex, M27UnitInfo.refCategoryTML, categories.COMMAND, M27UnitInfo.refCategoryEngineer }
        end


        tEngineerActionsByPriority = { { M27EngineerOverseer.refActionBuildQuantumOptics, M27EngineerOverseer.refActionBuildHive, M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildSecondExperimental, M27EngineerOverseer.refActionNavalSpareAction, M27EngineerOverseer.refActionBuildT2Sonar, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildSecondAirFactory, M27EngineerOverseer.refActionBuildSecondLandFactory, M27EngineerOverseer.refActionBuildLandFactory, M27EngineerOverseer.refActionSAMCreep, M27EngineerOverseer.refActionBuildNavalFactory, M27EngineerOverseer.refActionAssistNavalFactory, M27EngineerOverseer.refActionBuildAirFactory, M27EngineerOverseer.refActionBuildT1Sonar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildSecondPower, M27EngineerOverseer.refActionBuildTML, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionBuildShield, M27EngineerOverseer.refActionBuildSecondShield, M27EngineerOverseer.refActionBuildExperimental, M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionUpgradeBuilding, M27EngineerOverseer.refActionBuildPower },
                                       { M27EngineerOverseer.refActionBuildHydro, M27EngineerOverseer.refActionFortifyFirebase, M27EngineerOverseer.refActionAssistShield, M27EngineerOverseer.refActionBuildSecondTMD, M27EngineerOverseer.refActionBuildMassStorage, M27EngineerOverseer.refActionAssistMexUpgrade, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildTMD, M27EngineerOverseer.refActionBuildSMD, M27EngineerOverseer.refActionBuildEmergencyArti, M27EngineerOverseer.refActionBuildEmergencyPD, M27EngineerOverseer.refActionBuildMex }}

    else
        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then

            --NOTE: SMD is top priority for pausing since have a later check that we have at least 1 missile (i.e. only pause once have 1 missile)
            if aiBrain[M27AirOverseer.refiAirAANeeded] <= 0 and aiBrain[M27Overseer.refiModDistFromStartNearestThreat] > aiBrain[M27AirOverseer.refiBomberDefenceModDistance] then
                --No nearby enemy threats so can afford to delay air
                tCategoriesByPriority = { M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryEngineerStation, M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryRASSACU, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategorySML - categories.EXPERIMENTAL, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, iSpecialHQCategory, M27UnitInfo.refCategoryEngineer }
            else
                --Enemy near base so need to priortiise emergency bombers
                tCategoriesByPriority = { M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryEngineerStation, M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryRASSACU, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategorySML - categories.EXPERIMENTAL, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, iSpecialHQCategory, M27UnitInfo.refCategoryEngineer }
            end

            tEngineerActionsByPriority = { { M27EngineerOverseer.refActionBuildQuantumOptics, M27EngineerOverseer.refActionBuildHive,  M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildSecondExperimental, M27EngineerOverseer.refActionNavalSpareAction, M27EngineerOverseer.refActionBuildT2Sonar, M27EngineerOverseer.refActionBuildT1Sonar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildTML, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionBuildShield, M27EngineerOverseer.refActionBuildSecondShield, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildExperimental, M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionBuildSecondAirFactory, M27EngineerOverseer.refActionSAMCreep, M27EngineerOverseer.refActionBuildAirFactory, M27EngineerOverseer.refActionBuildSecondLandFactory, M27EngineerOverseer.refActionBuildLandFactory, M27EngineerOverseer.refActionBuildNavalFactory, M27EngineerOverseer.refActionAssistNavalFactory, M27EngineerOverseer.refActionBuildMassStorage, M27EngineerOverseer.refActionAssistMexUpgrade, M27EngineerOverseer.refActionUpgradeBuilding, M27EngineerOverseer.refActionBuildMex, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildSecondPower, M27EngineerOverseer.refActionFortifyFirebase },
                                           { M27EngineerOverseer.refActionBuildSMD, M27EngineerOverseer.refActionBuildTMD, M27EngineerOverseer.refActionBuildEmergencyArti, M27EngineerOverseer.refActionBuildEmergencyPD, M27EngineerOverseer.refActionAssistShield, M27EngineerOverseer.refActionBuildSecondTMD, M27EngineerOverseer.refActionBuildPower, M27EngineerOverseer.refActionBuildHydro } }
        elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle then
            if aiBrain[M27AirOverseer.refiAirAANeeded] <= 0 and aiBrain[M27Overseer.refiModDistFromStartNearestThreat] > aiBrain[M27AirOverseer.refiBomberDefenceModDistance] then
                --No nearby enemy threats so can afford to delay air
                tCategoriesByPriority = { M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryEngineerStation, M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryT3Radar, M27UnitInfo.refCategoryRASSACU, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryLandFactory, categories.COMMAND, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategorySML - categories.EXPERIMENTAL, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, iSpecialHQCategory, M27UnitInfo.refCategoryEngineer }
            else
                tCategoriesByPriority = { M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryEngineerStation, M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategoryT3Radar, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryRASSACU, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryAirFactory, categories.COMMAND, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategorySML - categories.EXPERIMENTAL, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, iSpecialHQCategory, M27UnitInfo.refCategoryEngineer }
            end

            tEngineerActionsByPriority = { { M27UnitInfo.refCategoryQuantumOptics, M27EngineerOverseer.refActionBuildQuantumOptics, M27EngineerOverseer.refActionBuildHive, M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildSecondExperimental, M27EngineerOverseer.refActionNavalSpareAction, M27EngineerOverseer.refActionBuildT2Sonar, M27EngineerOverseer.refActionBuildT1Sonar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildTML, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionBuildShield, M27EngineerOverseer.refActionBuildSecondShield, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildExperimental, M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionBuildSecondAirFactory, M27EngineerOverseer.refActionSAMCreep, M27EngineerOverseer.refActionBuildAirFactory, M27EngineerOverseer.refActionBuildSecondLandFactory, M27EngineerOverseer.refActionBuildLandFactory, M27EngineerOverseer.refActionBuildNavalFactory, M27EngineerOverseer.refActionAssistNavalFactory, M27EngineerOverseer.refActionBuildMassStorage, M27EngineerOverseer.refActionAssistMexUpgrade, M27EngineerOverseer.refActionUpgradeBuilding, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildSecondPower, M27EngineerOverseer.refActionFortifyFirebase, M27EngineerOverseer.refActionBuildMex },
                                           { M27EngineerOverseer.refActionBuildTMD, M27EngineerOverseer.refActionBuildSMD, M27EngineerOverseer.refActionBuildEmergencyArti, M27EngineerOverseer.refActionBuildEmergencyPD, M27EngineerOverseer.refActionAssistShield, M27EngineerOverseer.refActionBuildSecondTMD, M27EngineerOverseer.refActionBuildPower, M27EngineerOverseer.refActionBuildHydro } }
        elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill then
            tCategoriesByPriority = { M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryEngineerStation, M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategoryRASSACU, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategorySML - categories.EXPERIMENTAL, M27UnitInfo.refCategoryLandFactory, iSpecialHQCategory, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, M27UnitInfo.refCategoryEngineer }
            tEngineerActionsByPriority = { { M27EngineerOverseer.refActionBuildQuantumOptics, M27EngineerOverseer.refActionBuildHive, M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildSecondExperimental, M27EngineerOverseer.refActionNavalSpareAction, M27EngineerOverseer.refActionBuildT2Sonar, M27EngineerOverseer.refActionBuildT1Sonar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildTML, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionBuildShield, M27EngineerOverseer.refActionBuildSecondShield, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildExperimental, M27EngineerOverseer.refActionBuildMassStorage,M27EngineerOverseer.refActionAssistMexUpgrade, M27EngineerOverseer.refActionUpgradeBuilding, M27EngineerOverseer.refActionBuildTMD, M27EngineerOverseer.refActionBuildSMD, M27EngineerOverseer.refActionBuildSecondLandFactory, M27EngineerOverseer.refActionSAMCreep, M27EngineerOverseer.refActionBuildLandFactory, M27EngineerOverseer.refActionBuildNavalFactory, M27EngineerOverseer.refActionAssistNavalFactory, M27EngineerOverseer.refActionFortifyFirebase },
                                           { M27EngineerOverseer.refActionAssistSMD, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildMex, M27EngineerOverseer.refActionBuildSecondPower },
                                           { M27EngineerOverseer.refActionBuildEmergencyArti, M27EngineerOverseer.refActionBuildEmergencyPD, M27EngineerOverseer.refActionAssistShield, M27EngineerOverseer.refActionBuildSecondTMD, M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionBuildPower, M27EngineerOverseer.refActionBuildHydro } }
        elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
            tCategoriesByPriority = { M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryEngineerStation, M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategoryRASSACU, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategorySML - categories.EXPERIMENTAL, iSpecialHQCategory, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryEngineer }
            tEngineerActionsByPriority = { { M27EngineerOverseer.refActionBuildQuantumOptics, M27EngineerOverseer.refActionBuildHive, M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildSecondExperimental, M27EngineerOverseer.refActionNavalSpareAction, M27EngineerOverseer.refActionBuildT2Sonar, M27EngineerOverseer.refActionBuildT1Sonar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildTML, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildShield, M27EngineerOverseer.refActionBuildSecondShield, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildExperimental, M27EngineerOverseer.refActionBuildMassStorage,M27EngineerOverseer.refActionAssistMexUpgrade, M27EngineerOverseer.refActionFortifyFirebase },
                                           { M27EngineerOverseer.refActionUpgradeBuilding, M27EngineerOverseer.refActionBuildTMD, M27EngineerOverseer.refActionBuildSMD, M27EngineerOverseer.refActionBuildSecondLandFactory, M27EngineerOverseer.refActionSAMCreep, M27EngineerOverseer.refActionBuildLandFactory, M27EngineerOverseer.refActionBuildNavalFactory, M27EngineerOverseer.refActionAssistNavalFactory, M27EngineerOverseer.refActionAssistSMD },
                                           { M27EngineerOverseer.refActionBuildEmergencyArti, M27EngineerOverseer.refActionBuildEmergencyPD, M27EngineerOverseer.refActionAssistShield, M27EngineerOverseer.refActionBuildSecondTMD, M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildMex, M27EngineerOverseer.refActionBuildSecondPower, M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionBuildPower, M27EngineerOverseer.refActionBuildHydro } }
        else
            --Land attack mode/normal logic
            if aiBrain[M27AirOverseer.refiAirAANeeded] <= 0 and aiBrain[M27Overseer.refiModDistFromStartNearestThreat] > aiBrain[M27AirOverseer.refiBomberDefenceModDistance] and not(aiBrain[M27Overseer.refbT2NavyNearOurBase]) then
                tCategoriesByPriority = { M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryEngineerStation, M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryRASSACU, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategorySML - categories.EXPERIMENTAL, iSpecialHQCategory, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, M27UnitInfo.refCategoryEngineer }
            else
                tCategoriesByPriority = { M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryEngineerStation, M27UnitInfo.refCategoryQuantumOptics, M27UnitInfo.refCategoryRASSACU, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryT3Radar, categories.COMMAND, M27UnitInfo.refCategoryLandFactory, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryAirFactory, M27UnitInfo.refCategoryTML, M27UnitInfo.refCategorySML - categories.EXPERIMENTAL, iSpecialHQCategory, M27UnitInfo.refCategoryStealthGenerator, M27UnitInfo.refCategoryStealthAndCloakPersonal, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryPersonalShield, M27UnitInfo.refCategoryFixedShield, M27UnitInfo.refCategoryMobileLandShield, M27UnitInfo.refCategoryEngineer }
            end

            tEngineerActionsByPriority = { { M27EngineerOverseer.refActionBuildQuantumOptics, M27EngineerOverseer.refActionBuildHive, M27EngineerOverseer.refActionBuildT3Radar, M27EngineerOverseer.refActionBuildSecondExperimental, M27EngineerOverseer.refActionNavalSpareAction, M27EngineerOverseer.refActionBuildT2Sonar, M27EngineerOverseer.refActionBuildT1Sonar, M27EngineerOverseer.refActionBuildT2Radar, M27EngineerOverseer.refActionBuildT1Radar, M27EngineerOverseer.refActionBuildTML, M27EngineerOverseer.refActionBuildEnergyStorage, M27EngineerOverseer.refActionBuildAirStaging, M27EngineerOverseer.refActionBuildShield, M27EngineerOverseer.refActionBuildSecondShield, M27EngineerOverseer.refActionBuildThirdPower, M27EngineerOverseer.refActionBuildExperimental, M27EngineerOverseer.refActionBuildSecondAirFactory, M27EngineerOverseer.refActionBuildAirFactory, M27EngineerOverseer.refActionBuildSecondLandFactory, M27EngineerOverseer.refActionSAMCreep, M27EngineerOverseer.refActionBuildLandFactory, M27EngineerOverseer.refActionBuildNavalFactory, M27EngineerOverseer.refActionAssistNavalFactory, M27EngineerOverseer.refActionAssistNavalFactory, M27EngineerOverseer.refActionBuildMassStorage,M27EngineerOverseer.refActionAssistMexUpgrade, M27EngineerOverseer.refActionUpgradeBuilding },
                                           { M27EngineerOverseer.refActionAssistAirFactory, M27EngineerOverseer.refActionBuildMex, M27EngineerOverseer.refActionSpare, M27EngineerOverseer.refActionBuildSecondPower, M27EngineerOverseer.refActionFortifyFirebase },
                                           { M27EngineerOverseer.refActionBuildTMD, M27EngineerOverseer.refActionBuildSMD, M27EngineerOverseer.refActionBuildEmergencyArti, M27EngineerOverseer.refActionBuildEmergencyPD, M27EngineerOverseer.refActionAssistShield, M27EngineerOverseer.refActionBuildSecondTMD, M27EngineerOverseer.refActionBuildPower, M27EngineerOverseer.refActionBuildHydro } }
        end


    end



    return tCategoriesByPriority, tEngineerActionsByPriority
end

function ManageMassStalls(aiBrain)
    --For now focus is on if we are trying to build a missile for an SML, or we are massively mass stalling
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ManageMassStalls'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetGameTimeSeconds() >= 960 and (aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.05 or aiBrain[refbStallingEnergy]) then bDebugMessages = true end

    local bPauseNotUnpause = true
    local bChangeRequired = false
    local iUnitsAdjusted = 0
    local iMassStallPercentAdjust = 0
    if aiBrain[M27EngineerOverseer.refbNeedResourcesForMissile] then
        if aiBrain:GetEconomyStored('MASS') <= aiBrain[refiGrossMassBaseIncome] * 5 or aiBrain[refiNetMassBaseIncome] < 0 then
            iMassStallPercentAdjust = 0.04
        else
            iMassStallPercentAdjust = 0.02
        end
    end
    --Dont consider pausing or unpausing if are stalling energy or early game, as our energy stall manager is likely to be operating
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, GetGameTimeSeconds='..GetGameTimeSeconds()..'; aiBrain[refiGrossMassBaseIncome]='..aiBrain[refiGrossMassBaseIncome]..'; aiBrain[refbStallingEnergy]='..tostring(aiBrain[refbStallingEnergy])..'; time since last energy stall='..GetGameTimeSeconds() - (aiBrain[refiLastEnergyStall] or -100)..'; energy stored='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; refbNeedResourcesForMissile='..tostring(aiBrain[M27EngineerOverseer.refbNeedResourcesForMissile] or false)) end
    if aiBrain[refbStallingMass] or (GetGameTimeSeconds() >= 120 and aiBrain[refiGrossMassBaseIncome] >= 3 and not(aiBrain[refbStallingEnergy]) and GetGameTimeSeconds() - (aiBrain[refiLastEnergyStall] or -100) >= 10 and aiBrain:GetEconomyStoredRatio('ENERGY') == 1) then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': About to consider if we have a mass stall or not. aiBrain:GetEconomyStoredRatio(MASS)=' .. aiBrain:GetEconomyStoredRatio('MASS') .. '; aiBrain[refiNetMassBaseIncome]=' .. aiBrain[refiNetMassBaseIncome] .. '; aiBrain:GetEconomyTrend(MASS)=' .. aiBrain:GetEconomyTrend('MASS') .. '; aiBrain[refbStallingMass]=' .. tostring(aiBrain[refbStallingMass])..'; aiBrain:GetEconomyRequested(MASS)='..aiBrain:GetEconomyRequested('MASS'))
        end
        --First consider unpausing
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': If we have flagged that we are stalling mass then will check if we have enough to start unpausing things')
        end

        if aiBrain[refbStallingMass] and aiBrain:GetEconomyStoredRatio('MASS') > (0.005 + iMassStallPercentAdjust) then
            --aiBrain[refbStallingEnergy] = false
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Have enough mass stored or income to start unpausing things')
            end
            bChangeRequired = true
            bPauseNotUnpause = false
        end
        if bDebugMessages == true then LOG(sFunctionRef .. ': Checking if we shoudl flag that we are mass stalling. bChangeRequired='..tostring(bChangeRequired)..'; Mass stored='..aiBrain:GetEconomyStored('MASS')..'; Need resources for missile='..tostring((aiBrain[M27EngineerOverseer.refbNeedResourcesForMissile] or false))..'; Gross mass income='..aiBrain[refiGrossMassBaseIncome]..'; aiBrain[refiNetMassBaseIncome]='..aiBrain[refiNetMassBaseIncome]..'; aiBrain:GetEconomyRequested(MASS)='..aiBrain:GetEconomyRequested('MASS')) end
        --Check if should manage mass stall
        if bChangeRequired == false and aiBrain:GetEconomyStoredRatio('MASS') <= (0.001 + iMassStallPercentAdjust) and (aiBrain[M27EngineerOverseer.refbNeedResourcesForMissile] or (aiBrain[refiNetMassBaseIncome] < -1 and (aiBrain[refiGrossMassBaseIncome] / math.max(1, aiBrain:GetEconomyRequested('MASS'))) <= 0.75)) then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': We are stalling mass, will look for units to pause')
            end
            bChangeRequired = true
            bPauseNotUnpause = true
            aiBrain[refbStallingMass] = true
        end

        if bDebugMessages == true then LOG(sFunctionRef..': bChangeRequired='..tostring(bChangeRequired)..'; bPauseNotUnpause='..tostring(bPauseNotUnpause)) end

        if bChangeRequired then
            --Decide on order to pause/unpause

            local tCategoriesByPriority, tEngineerActionsByPriority = GetCategoriesAndActionsToPause(aiBrain, true)

            local iMassPerTickSavingNeeded
            if aiBrain[refbStallingMass] then
                if aiBrain[M27EngineerOverseer.refbNeedResourcesForMissile] and aiBrain:GetEconomyStored('MASS') <= math.max(500, aiBrain[refiGrossMassBaseIncome] * 4) then
                    iMassPerTickSavingNeeded = math.max(1, -aiBrain[refiNetMassBaseIncome] * 0.6)
                else
                    iMassPerTickSavingNeeded = math.max(1, -aiBrain[refiNetMassBaseIncome] * 0.8)
                end
            else
                iMassPerTickSavingNeeded = math.min(-1, -aiBrain[refiNetMassBaseIncome] * 1.2)
                if aiBrain[M27EngineerOverseer.refbNeedResourcesForMissile] then iMassPerTickSavingNeeded = math.min(-1, -aiBrain[refiNetMassBaseIncome])
                else
                    iMassPerTickSavingNeeded = math.min(-1, -aiBrain[refiNetMassBaseIncome] * 1.2)
                end
            end

            local iMassSavingManaged = 0
            local iEngineerSubtableCount = 0
            local tEngineerActionSubtable
            local tRelevantUnits, oUnit

            local bAbort = false
            local iTotalUnits = 0
            local iCategoryStartPoint, iIntervalChange, iCategoryEndPoint, iCategoryRef
            local bWasUnitPaused
            local bConsiderReclaimingEngineer = false
            local iKillCount = 0
            local tReclaimLocationsAlreadyConsidered = {}
            if bPauseNotUnpause then
                iCategoryStartPoint = 1
                iIntervalChange = 1
                iCategoryEndPoint = table.getn(tCategoriesByPriority)
                if GetGameTimeSeconds() - aiBrain[M27EngineerOverseer.refiTimeOfLastEngiSelfDestruct] > 0.99 then
                    local iEngiCategoryWanted
                    if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 then iEngiCategoryWanted = M27UnitInfo.refCategoryEngineer * categories.TECH3
                    elseif aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 2 then iEngiCategoryWanted = M27UnitInfo.refCategoryEngineer - categories.TECH1
                    else iEngiCategoryWanted = M27UnitInfo.refCategoryEngineer
                    end
                    local iCurEngis = aiBrain:GetCurrentUnits(iEngiCategoryWanted)
                    if iCurEngis >= 10 then
                        --If are defending against arti then want a min of 10 + 12 for every t3 shield we have to a max of 70 before start considering ctrl-king any
                        if not(aiBrain[M27Overseer.refbDefendAgainstArti]) or iCurEngis >= 70 then
                            bConsiderReclaimingEngineer = true
                        else
                            local iPriorityShields = 0
                            for iUnit, oUnit in aiBrain[M27EngineerOverseer.reftPriorityShieldsToAssist] do
                                if M27UnitInfo.IsUnitValid(oUnit) then iPriorityShields = iPriorityShields + 1 end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': iPriorityShields='..iPriorityShields..'; iCurEngis='..iCurEngis) end
                            if iCurEngis >= math.max(1, iPriorityShields) * 12 + 10 then
                                bConsiderReclaimingEngineer = true
                            end
                        end
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Time='..GetGameTimeSeconds()..'; Time of last engi self destruct='..aiBrain[M27EngineerOverseer.refiTimeOfLastEngiSelfDestruct]..'; T3 engis='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * categories.TECH3)..'; bConsiderReclaimingEngineer='..tostring(bConsiderReclaimingEngineer)) end
            else
                iCategoryStartPoint = table.getn(tCategoriesByPriority)
                iIntervalChange = -1
                iCategoryEndPoint = 1
            end

            local bConsideringHQ
            local bNoRelevantUnits = true

            if bDebugMessages == true then
                LOG(sFunctionRef .. ': About to cycle through every category, bPauseNotUnpause=' .. tostring(bPauseNotUnpause) .. '; iCategoryStartPoint=' .. iCategoryStartPoint .. '; iCategoryEndPoint=' .. iCategoryEndPoint .. '; strategy=' .. aiBrain[M27Overseer.refiAIBrainCurrentStrategy])
            end
            for iCategoryCount = iCategoryStartPoint, iCategoryEndPoint, iIntervalChange do
                iCategoryRef = tCategoriesByPriority[iCategoryCount]

                --Are we considering upgrading factory HQs?
                if iCategoryRef == iSpecialHQCategory then
                    iCategoryRef = M27UnitInfo.refCategoryAllHQFactories
                    bConsideringHQ = true
                else
                    bConsideringHQ = false
                end

                if bPauseNotUnpause then
                    tRelevantUnits = aiBrain:GetListOfUnits(iCategoryRef, false, true)
                else
                    tRelevantUnits = EntityCategoryFilterDown(iCategoryRef, aiBrain[reftPausedUnits])
                end

                local iCurUnitMassUsage
                local bApplyActionToUnit
                local oBP
                if M27Utilities.IsTableEmpty(tRelevantUnits) == false then
                    bNoRelevantUnits = false
                    iTotalUnits = table.getn(tRelevantUnits)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': iCategoryCount=' .. iCategoryCount .. '; iTotalUnits=' .. iTotalUnits .. '; bPauseNotUnpause=' .. tostring(bPauseNotUnpause))
                    end
                    if iCategoryRef == M27UnitInfo.refCategoryEngineer then
                        iEngineerSubtableCount = iEngineerSubtableCount + 1
                        tEngineerActionSubtable = tEngineerActionsByPriority[iEngineerSubtableCount]
                    end
                    for iUnit = iTotalUnits, 1, -1 do
                        oUnit = tRelevantUnits[iUnit]
                        --for iUnit, oUnit in tRelevantUnits do
                        bApplyActionToUnit = false
                        iCurUnitMassUsage = 0
                        if M27UnitInfo.IsUnitValid(oUnit, true) then --Only consider unit if it has been constructed
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': About to consider pausing/unpausingunit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; will first check category specific logic for if we want to go ahead with pausing4')
                            end


                            --Do we actually want to pause the unit? check any category specific logic
                            bApplyActionToUnit = true
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': UnitState=' .. M27Logic.GetUnitState(oUnit) .. '; Is ActiveHQUpgrades Empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])))
                            end
                            --Factories, ACU and engineers - dont pause if >=85% done
                            if bPauseNotUnpause and oUnit.GetWorkProgress and EntityCategoryContains(M27UnitInfo.refCategoryEngineer + categories.COMMAND + M27UnitInfo.refCategoryAllFactories, oUnit.UnitId) and (oUnit:GetWorkProgress() or 0) >= 0.85 then
                                bApplyActionToUnit = false
                                --SMD LOGIC - Check if already have 1 missile loaded before pausing
                            elseif iCategoryRef == M27UnitInfo.refCategorySMD and oUnit.GetTacticalSiloAmmoCount and oUnit:GetTacticalSiloAmmoCount() >= 1 then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Have SMD with at least 1 missile so will pause it')
                                end
                                bApplyActionToUnit = false
                            elseif iCategoryRef == M27UnitInfo.refCategoryEngineer then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Have an engineer with action=' .. (oUnit[M27EngineerOverseer.refiEngineerCurrentAction] or 'nil') .. '; tEngineerActionSubtable=' .. repru(tEngineerActionSubtable))
                                end
                                bApplyActionToUnit = false
                                for iActionCount, iActionRef in tEngineerActionSubtable do
                                    if iActionRef == oUnit[M27EngineerOverseer.refiEngineerCurrentAction] then
                                        bApplyActionToUnit = true
                                        --Dont pause the last engi building power, and also dont pause if are building PD/T2 Arti/Shield/Experimental and have a fraction complete of at least 70%
                                        if bPauseNotUnpause and iActionRef == M27EngineerOverseer.refActionBuildPower and (oUnit[M27EngineerOverseer.refbPrimaryBuilder] or aiBrain:GetEconomyStoredRatio('MASS') >= 0.7) then
                                            bApplyActionToUnit = false
                                        elseif bPauseNotUnpause and oUnit.GetFocusUnit then
                                            local oFocusUnit = oUnit:GetFocusUnit()
                                            if bDebugMessages == true then
                                                if M27UnitInfo.IsUnitValid(oFocusUnit) then
                                                    LOG(sFunctionRef..': Considering engineer '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; UC='..M27EngineerOverseer.GetEngineerUniqueCount(oUnit)..'; Focus unit='..oFocusUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oFocusUnit)..'; Fraction complete='..oFocusUnit:GetFractionComplete())
                                                else LOG(sFunctionRef..': Focus unit for engineer '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; UC='..M27EngineerOverseer.GetEngineerUniqueCount(oUnit)..' isnt valid') end
                                            end
                                            if M27UnitInfo.IsUnitValid(oFocusUnit) and oFocusUnit:GetFractionComplete() >= 0.7 and oFocusUnit:GetFractionComplete() < 1 then
                                                if EntityCategoryContains(M27UnitInfo.refCategoryPD + M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryExperimentalLevel, oFocusUnit.UnitId) then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Wont apply action to unit as it is PD/Arti/Experimental') end
                                                    bApplyActionToUnit = false
                                                elseif bDebugMessages == true then LOG(sFunctionRef..': Will apply action to focus unit as it isnt PD/Experimental level')
                                                end
                                            end
                                        end
                                        if bApplyActionToUnit and bConsiderReclaimingEngineer and not(oUnit[M27EngineerOverseer.refbPrimaryBuilder]) and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 90 then
                                            --Is there reclaim near the engineer? If so clear its orders and have it reclaim, otherwise kill it
                                            local oBP = oUnit:GetBlueprint()
                                            if oBP.Economy.BuildCostMass < 500 and oBP.Economy.MaxBuildDistance then --redundancy so we dont ctrl-K SACUs or a unit with no build radius
                                                bApplyActionToUnit = false
                                                M27EngineerOverseer.ClearEngineerActionTrackers(aiBrain, oUnit, true)
                                                M27Utilities.IssueTrackedClearCommands({ oUnit })

                                                function KillEngineer(oUnit)
                                                    if bDebugMessages == true then LOG(sFunctionRef..': About to kill engineer '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                                                    oUnit:Kill() --Assumes we have already cleared engineer action trackers
                                                    iKillCount = iKillCount + 1
                                                    if iKillCount >= 2 then
                                                        bConsiderReclaimingEngineer = false
                                                    end
                                                    aiBrain[M27EngineerOverseer.refiTimeOfLastEngiSelfDestruct] = GetGameTimeSeconds()
                                                end

                                                local bGetReclaimInstead = false
                                                local iBuildingRadius = oBP.Economy.MaxBuildDistance --approximate so we are highly likely to be able to reclaim without moving
                                                local rReclaimRect = Rect(oUnit:GetPosition()[1]-iBuildingRadius, oUnit:GetPosition()[3]-iBuildingRadius, oUnit:GetPosition()[1]+iBuildingRadius, oUnit:GetPosition()[3]+iBuildingRadius)
                                                local iReclaimNearby = M27MapInfo.GetReclaimInRectangle(3, rReclaimRect)
                                                if iReclaimNearby >= 40 then
                                                    bGetReclaimInstead = true
                                                    if M27Utilities.IsTableEmpty(tReclaimLocationsAlreadyConsidered) == false then
                                                        for iLocation, tLocation in tReclaimLocationsAlreadyConsidered do
                                                            if M27Utilities.GetDistanceBetweenPositions(tLocation, oUnit:GetPosition()) <= 10 then
                                                                bGetReclaimInstead = false
                                                                break
                                                            end
                                                        end
                                                    end
                                                end
                                                if bDebugMessages == true then LOG(sFunctionRef..': Considering killing engi for mass, iReclaimNearby='..iReclaimNearby..'; bGetReclaimInstead='..tostring(bGetReclaimInstead)) end
                                                if bGetReclaimInstead then
                                                    table.insert(tReclaimLocationsAlreadyConsidered, oUnit:GetPosition())
                                                    local tReclaimables = M27MapInfo.GetReclaimInRectangle(4, rReclaimRect)
                                                    local bGivenReclaimOrder = false
                                                    if M27Utilities.IsTableEmpty(tReclaimables) == false then
                                                        local tReclaimablesNearRange = {}
                                                        for iWreck, oReclaim in tReclaimables do
                                                            if (oReclaim.MaxMassReclaim or 0) > 0 and oReclaim.CachePosition then
                                                                if M27Utilities.GetDistanceBetweenPositions(oReclaim.CachePosition, oUnit:GetPosition()) <= iBuildingRadius then
                                                                    IssueReclaim({oUnit}, oReclaim)
                                                                    bGivenReclaimOrder = true
                                                                else
                                                                    table.insert(tReclaimablesNearRange, oReclaim)
                                                                end
                                                            end
                                                        end
                                                        if M27Utilities.IsTableEmpty(tReclaimablesNearRange) == false then
                                                            for iWreck, oReclaim in tReclaimablesNearRange do
                                                                IssueReclaim({oUnit}, oReclaim)
                                                                bGivenReclaimOrder = true
                                                            end
                                                        end
                                                        if not(bGivenReclaimOrder) then
                                                            if bDebugMessages == true then LOG(sFunctionRef..': Will kill unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' due to no reclaim odrer') end
                                                            KillEngineer(oUnit)
                                                        end
                                                    else
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Will kill unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' due to no reclaim nearby') end
                                                        KillEngineer(oUnit)
                                                    end
                                                else
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Will kill unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' as no reclaim') end
                                                    KillEngineer(oUnit)
                                                end
                                            end
                                        end
                                        break
                                    end
                                end
                            elseif iCategoryRef == M27UnitInfo.refCategoryPersonalShield or iCategoryRef == M27UnitInfo.refCategoryFixedShield or iCategoryRef == M27UnitInfo.refCategoryMobileLandShield then
                                --Mass stalling so pausing shield not expected to do anything
                                if bPauseNotUnpause then bApplyActionToUnit = false end
                                --[[elseif iCategoryRef == M27UnitInfo.refCategoryAirFactory or iCategoryRef == M27UnitInfo.refCategoryLandFactory then
                                    --Dont want to pause an HQ upgrade since it will give us better power
                                    if bPauseNotUnpause and not (bConsideringHQ) and oUnit:IsUnitState('Upgrading') and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false and EntityCategoryContains(categories.FACTORY, oUnit) then
                                        for iFactory, oFactory in aiBrain[reftActiveHQUpgrades] do
                                            if oUnit == oFactory then
                                                bApplyActionToUnit = false
                                                break
                                            end
                                        end
                                    elseif not (bPauseNotUnpause) and bConsideringHQ then
                                        --Only unpause HQs
                                        bApplyActionToUnit = false
                                        if oUnit:IsUnitState('Upgrading') and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
                                            for iFactory, oFactory in aiBrain[reftActiveHQUpgrades] do
                                                if oUnit == oFactory then
                                                    bApplyActionToUnit = true
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    if bApplyActionToUnit and bPauseNotUnpause then
                                        --Dont pause factory that is building an engineer or is an air factory that isnt building an air unit, if its our highest tech level and we dont have at least 5 engis of that tech level
                                        if M27UnitInfo.GetUnitTechLevel(oUnit) >= math.max(2, aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]) and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * M27UnitInfo.ConvertTechLevelToCategory(M27UnitInfo.GetUnitTechLevel(oUnit))) < 2 then
                                            --Dont pause factory as have too few engis and want to build power with those engis
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Have too few engineers so wont pause factory')
                                            end
                                            bApplyActionToUnit = false
                                        end
                                    end--]]
                            end



                            if iCategoryRef == categories.COMMAND then
                                --want in addition to above as ACU might have personal shield
                                if bPauseNotUnpause then
                                    if oUnit:IsUnitState('Upgrading') then
                                        bApplyActionToUnit = false
                                    elseif oUnit.GetWorkProgress then
                                        --if oUnit:GetWorkProgress() >= 0.85 then
                                        bApplyActionToUnit = false
                                        --dont pause t1 mex construction
                                        if oUnit.GetFocusUnit and oUnit:GetFocusUnit() and oUnit:GetFocusUnit().UnitId and EntityCategoryContains(M27UnitInfo.refCategoryT1Mex, oUnit:GetFocusUnit().UnitId) then
                                            bApplyActionToUnit = false
                                        elseif aiBrain[M27Overseer.refiDefaultStrategy] == M27Overseer.refStrategyTurtle and not(M27Conditions.DoesACUHaveUpgrade(aiBrain, oUnit)) then
                                            bApplyActionToUnit = false
                                        end
                                    end
                                end
                            end


                            --Pause the unit

                            if bApplyActionToUnit then
                                bWasUnitPaused = oUnit[M27UnitInfo.refbPaused] --Means we will ignore the mass usage when calculating how much we have saved
                                oBP = oUnit:GetBlueprint()
                                iCurUnitMassUsage = oBP.Economy.MaintenanceConsumptionPerSecondMass

                                if (iCurUnitMassUsage or 0) == 0 or iCategoryRef == M27UnitInfo.refCategoryEngineer or iCategoryRef == M27UnitInfo.refCategoryMex or iCategoryRef == categories.COMMAND then
                                    --Approximate mass usage based on build rate as a very rough guide
                                    --examples: Upgrading mex to T3 costs 11E per BP; T3 power is 8.4; T1 power is 6; Guncom is 30; Laser is 178; Strat bomber is 15
                                    local iMassPerBP = 0.25 --e.g. building t1 land factory uses 4; building a titan uses 1.1; divide by 10 as dealing with values per tick
                                    if EntityCategoryContains(categories.SILO, oUnit.UnitId) and oBP.Economy.BuildRate then
                                        --Dealing with a silo so need to calculate mass usage differently
                                        iCurUnitMassUsage = 0
                                        for iWeapon, tWeapon in oBP.Weapon do
                                            if tWeapon.MaxProjectileStorage and tWeapon.ProjectileId then
                                                local oProjectileBP = __blueprints[tWeapon.ProjectileId]
                                                if oProjectileBP.Economy and oProjectileBP.Economy.BuildCostMass and oProjectileBP.Economy.BuildTime > 0 and oBP.Economy.BuildRate > 0 then
                                                    iCurUnitMassUsage = oProjectileBP.Economy.BuildCostMass * oBP.Economy.BuildRate / oProjectileBP.Economy.BuildTime
                                                    --If are power stalling then assume we only save 80% of this, as might have adjacency
                                                    if bPauseNotUnpause then iCurUnitMassUsage = iCurUnitMassUsage * 0.8 end
                                                    break
                                                end
                                            end
                                        end
                                    else
                                        if iCategoryRef == categories.COMMAND and oUnit[M27UnitInfo.refsUpgradeRef] then
                                            --Determine mass cost per BP
                                            if bDebugMessages == true then LOG(sFunctionRef..': aiBrain='..oUnit:GetAIBrain():GetArmyIndex()..'; Unit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; oUnit[M27UnitInfo.refsUpgradeRef]='..(oUnit[M27UnitInfo.refsUpgradeRef] or 'nil')..'; Upgrade mass cost='..(M27UnitInfo.GetUpgradeMassCost(oUnit, oUnit[M27UnitInfo.refsUpgradeRef]) or 'nil')..'; Upgrade build time='..(M27UnitInfo.GetUpgradeBuildTime(oUnit, oUnit[M27UnitInfo.refsUpgradeRef]) or 'nil')) end
                                            iMassPerBP = M27UnitInfo.GetUpgradeMassCost(oUnit, oUnit[M27UnitInfo.refsUpgradeRef]) / (M27UnitInfo.GetUpgradeBuildTime(oUnit, oUnit[M27UnitInfo.refsUpgradeRef]) or 1)
                                        else
                                            --Engineer - adjust energy consumption based on what are building
                                            if oUnit[M27EngineerOverseer.refiEngineerCurrentAction] and EntityCategoryContains(M27UnitInfo.refCategoryEngineer, oUnit.UnitId) then
                                                if oUnit[M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionAssistAirFactory then
                                                    iMassPerBP = 0.18 --asf is 0.117; strat is 0.22; T1 bomber is 0.18
                                                elseif oUnit[M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionBuildSMD then
                                                    iMassPerBP = 1.28
                                                elseif oUnit[M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionBuildExperimental then
                                                    if aiBrain[M27EngineerOverseer.refiLastExperimentalReference] == M27EngineerOverseer.refiExperimentalAir then
                                                        iMassPerBP = 0.7 --approximation, aeon is higher, cybran much lower, sera around this
                                                    elseif aiBrain[M27EngineerOverseer.refiLastExperimentalReference] == M27EngineerOverseer.refiExperimentalArti then
                                                        if EntityCategoryContains(categories.UEF, oUnit.UnitId) then iMassPerBP = 0.75
                                                        elseif EntityCategoryContains(categories.CYBRAN, oUnit.UnitId) then iMassPerBP = 0.917
                                                        elseif EntityCategoryContains(categories.AEON, oUnit.UnitId) then iMassPerBP = 2.025
                                                        else
                                                            iMassPerBP = 0.8
                                                        end
                                                    elseif aiBrain[M27EngineerOverseer.refiLastExperimentalReference] == M27EngineerOverseer.refiExperimentalYolona then
                                                        iMassPerBP = 0.75
                                                    elseif aiBrain[M27EngineerOverseer.refiLastExperimentalReference] == M27EngineerOverseer.refiExperimentalParagon then
                                                        iMassPerBP = 0.77
                                                    end
                                                elseif oUnit[M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionBuildSecondExperimental then
                                                    if aiBrain[M27EngineerOverseer.refiLastSecondExperimentalRef] == M27EngineerOverseer.refiExperimentalAir then
                                                        iMassPerBP = 0.7
                                                    elseif aiBrain[M27EngineerOverseer.refiLastSecondExperimentalRef] == M27EngineerOverseer.refiExperimentalArti then
                                                        if EntityCategoryContains(categories.UEF, oUnit.UnitId) then iMassPerBP = 0.75
                                                        elseif EntityCategoryContains(categories.CYBRAN, oUnit.UnitId) then iMassPerBP = 0.917
                                                        elseif EntityCategoryContains(categories.AEON, oUnit.UnitId) then iMassPerBP = 2.025
                                                        else
                                                            iMassPerBP = 0.8
                                                        end
                                                    elseif aiBrain[M27EngineerOverseer.refiLastExperimentalReference] == M27EngineerOverseer.refiExperimentalYolona then
                                                        iMassPerBP = 0.75
                                                    elseif aiBrain[M27EngineerOverseer.refiLastExperimentalReference] == M27EngineerOverseer.refiExperimentalParagon then
                                                        iMassPerBP = 0.77
                                                    end
                                                end
                                            end
                                        end
                                        if oBP.Economy.BuildRate then
                                            iCurUnitMassUsage = oBP.Economy.BuildRate * iMassPerBP
                                            --Reduce this massively if unit isn't actually building anything
                                            if bPauseNotUnpause and (not(oUnit:IsUnitState('Building')) and not(oUnit:IsUnitState('Repairing')) and not(oUnit.GetWorkProgress and oUnit:GetWorkProgress() > 0)) then iCurUnitMassUsage = iCurUnitMassUsage * 0.05 end
                                        end
                                    end
                                end
                                --We're working in ticks so adjust mass usage accordingly
                                iCurUnitMassUsage = iCurUnitMassUsage * 0.1
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Estimated mass usage=' .. iCurUnitMassUsage..'; About to call the function PauseOrUnpauseMassUsage on unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; bPauseNotUnpause='..tostring(bPauseNotUnpause)..'; iUnitsAdjusted before counting this unit='..iUnitsAdjusted)
                                end

                                if not((iCurUnitMassUsage or 0) == 0) then iUnitsAdjusted = iUnitsAdjusted + 1 end
                                M27UnitInfo.PauseOrUnpauseMassUsage(aiBrain, oUnit, bPauseNotUnpause)
                                --Cant move the below into unitinfo as get a crash if unitinfo tries to refernce the table of paused units
                                if bPauseNotUnpause then
                                    local bRecordUnit = true
                                    if M27Utilities.IsTableEmpty(aiBrain[reftPausedUnits]) == false then
                                        for iExistingUnit, oExistingUnit in aiBrain[reftPausedUnits] do
                                            if oExistingUnit == oUnit then
                                                bRecordUnit = false
                                                break
                                            end
                                        end
                                    end
                                    if bRecordUnit then
                                        table.insert(aiBrain[reftPausedUnits], oUnit)
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Added unit to tracker table, size=' .. table.getn(aiBrain[reftPausedUnits]))
                                        end
                                    elseif bDebugMessages == true then LOG(sFunctionRef..': Unit is already recorded in table of paused units')
                                    end
                                else
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Will remove unit from reftPausedUnits. Size of table before removal=' .. table.getn(aiBrain[reftPausedUnits]))
                                    end
                                    for iPausedUnit, oPausedUnit in aiBrain[reftPausedUnits] do
                                        if oPausedUnit == oUnit then
                                            table.remove(aiBrain[reftPausedUnits], iPausedUnit)
                                        end
                                    end
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Size of table after removal =' .. table.getn(aiBrain[reftPausedUnits]))
                                    end
                                end

                            end
                        end
                        if not (bWasUnitPaused) and bPauseNotUnpause then
                            iMassSavingManaged = iMassSavingManaged + iCurUnitMassUsage
                        elseif bWasUnitPaused and not (bPauseNotUnpause) then
                            iMassSavingManaged = iMassSavingManaged - iCurUnitMassUsage
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': iMassSavingManaged=' .. iMassSavingManaged .. '; iMassPerTickSavingNeeded=' .. iMassPerTickSavingNeeded .. '; aiBrain[refbStallingMass]=' .. tostring(aiBrain[refbStallingMass]))
                        end

                        if aiBrain[refbStallingMass] then
                            if iMassSavingManaged > iMassPerTickSavingNeeded then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Estimate we have saved ' .. iMassSavingManaged .. ' which is more tahn we wanted so will pause')
                                end
                                bAbort = true
                                break
                            end
                        else
                            if iMassSavingManaged < iMassPerTickSavingNeeded then
                                bAbort = true
                                break
                            end
                        end
                    end
                elseif bDebugMessages == true then
                    LOG(sFunctionRef .. ': We have no units for iCategoryCount=' .. iCategoryCount)
                end
                if bAbort then
                    break
                end
            end
            if bDebugMessages == true then
                LOG(sFunctionRef .. 'If we have no paused units then will set us as not having a mass stall')
            end
            if M27Utilities.IsTableEmpty(aiBrain[reftPausedUnits]) == true then
                aiBrain[refbStallingMass] = false
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': We are no longer stalling mass')
                end
            else
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': About to check if we wanted to unpause units but havent unpaused anything; Size of table=' .. table.getn(aiBrain[reftPausedUnits]) .. '; iUnitsAdjusted=' .. iUnitsAdjusted .. '; bNoRelevantUnits=' .. tostring(bNoRelevantUnits) .. '; aiBrain[refbStallingMass]=' .. tostring(aiBrain[refbStallingMass]))
                end
                --Backup - sometimes we still have units in the table listed as being paused (e.g. if an engineer changes action to one that isnt listed as needing pausing) - unpause them if we couldnt find via category search
                if aiBrain[refbStallingMass] and not (bPauseNotUnpause) and (iUnitsAdjusted == 0 or bNoRelevantUnits) and aiBrain:GetEconomyStoredRatio('MASS') >= 0.03 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 1 then
                    --Have a decent amount of mass, are flagged as stalling mass, but couldnt find any categories to unpause
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': werent able to find any units to unpause with normal approach so will unpause all remaining units')
                    end
                    local iLoopCountCheck = 0
                    local iMaxLoop = math.max(20, table.getn(aiBrain[reftPausedUnits]) + 1)
                    while M27Utilities.IsTableEmpty(aiBrain[reftPausedUnits]) == false do
                        iLoopCountCheck = iLoopCountCheck + 1
                        if iLoopCountCheck >= iMaxLoop then
                            M27Utilities.ErrorHandler('Infinite loop likely')
                            break
                        end
                        if M27Utilities.IsTableEmpty(aiBrain[reftPausedUnits]) == false then
                            for iUnit, oUnit in aiBrain[reftPausedUnits] do
                                if bDebugMessages == true then
                                    if M27UnitInfo.IsUnitValid(oUnit) then
                                        LOG(sFunctionRef .. ': About to unpause ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
                                    else
                                        LOG('Removing iUnit=' .. iUnit .. ' which is no longer valid')
                                    end
                                    LOG('Size of aiBrain[reftPausedUnits] before removal=' .. table.getn(aiBrain[reftPausedUnits]) .. '; will double check this size')
                                    local iActualSize = 0
                                    for iAltUnit, oAltUnit in aiBrain[reftPausedUnits] do
                                        iActualSize = iActualSize + 1
                                    end
                                    LOG('Actual size=' .. iActualSize)
                                end
                                if M27UnitInfo.IsUnitValid(oUnit) then
                                    M27UnitInfo.PauseOrUnpauseMassUsage(aiBrain, oUnit, false)
                                end
                                table.remove(aiBrain[reftPausedUnits], iUnit)
                                break
                            end
                        end
                    end
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': FInished unpausing units')
                    end
                end
            end
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': End of code, aiBrain[refbStallingMass]=' .. tostring(aiBrain[refbStallingMass]) .. '; Stalling energy='..tostring(aiBrain[refbStallingEnergy])..'; bPauseNotUnpause=' .. tostring(bPauseNotUnpause) .. '; iUnitsAdjusted=' .. iUnitsAdjusted .. '; Game time=' .. GetGameTimeSeconds() .. '; Mass stored %=' .. aiBrain:GetEconomyStoredRatio('MASS') .. '; Net mass income=' .. aiBrain[refiNetMassBaseIncome] .. '; gross mass income=' .. aiBrain[refiGrossMassBaseIncome])
        end
        --[[if aiBrain[refbStallingMass] then
            aiBrain[refiLastEnergyStall] = GetGameTimeSeconds()
        end--]]
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ManageEnergyStalls(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ManageEnergyStalls'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --if GetGameTimeSeconds() >= 1080 and (aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.05 or aiBrain[refbStallingEnergy]) then bDebugMessages = true end

    local bPauseNotUnpause = true
    local bChangeRequired = false
    local iUnitsAdjusted = 0
    local bHaveWeCappedUnpauseAmount = false
    if (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyLandRush and GetGameTimeSeconds() >= 200) or (GetGameTimeSeconds() >= 120 or (GetGameTimeSeconds() >= 40 and aiBrain[refiGrossEnergyBaseIncome] >= 15)) then
        --Only consider power stall management after 2m, otherwise risk pausing things such as early microbots when we would probably be ok after a couple of seconds; lower time limit put in as a theroetical possibility due to AIX
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': About to consider if we have an energy stall or not. aiBrain:GetEconomyStoredRatio(ENERGY)=' .. aiBrain:GetEconomyStoredRatio('ENERGY') .. '; aiBrain[refiNetEnergyBaseIncome]=' .. aiBrain[refiNetEnergyBaseIncome] .. '; aiBrain:GetEconomyTrend(ENERGY)=' .. aiBrain:GetEconomyTrend('ENERGY') .. '; aiBrain[refbStallingEnergy]=' .. tostring(aiBrain[refbStallingEnergy]))
        end
        --First consider unpausing
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': If we have flagged that we are stalling energy then will check if we have enough to start unpausing things')
        end
        local iT3Arti = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategoryExperimentalArti)
        local iPercentMod = 0
        local iNetMod = 0
        if iT3Arti > 0 then
            iPercentMod = 0.1
            --Already factored in to the net income, this gives a further buffer
            iNetMod = 25 + (iT3Arti - 1) * 100
        end
        --Also increase net energy if are at tech 3 and lack 3k power
        if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 then
            if aiBrain[refiGrossEnergyBaseIncome] <= 300 then iNetMod = iNetMod + 25 end
            if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle then
                iPercentMod = math.max(0.075, iPercentMod)
                iNetMod = iNetMod + 5
            else
                iPercentMod = math.max(0.05, iPercentMod)
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': If are in stall mode will check if want to come out. aiBrain[refbStallingEnergy]='..tostring(aiBrain[refbStallingEnergy])..'; Gross income='..aiBrain[refiGrossEnergyBaseIncome]..'; Stored ratio='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; Net income='..aiBrain[refiNetEnergyBaseIncome]..'; iNetMod='..iNetMod..'; iPercentMod='..iPercentMod..'; GameTime='..GetGameTimeSeconds()..'; aiBrain[refiGrossEnergyWhenStalled]='..aiBrain[refiGrossEnergyWhenStalled]..'; Changei n power since then='..aiBrain[refiGrossEnergyBaseIncome] - aiBrain[refiGrossEnergyWhenStalled]) end

        if aiBrain[refiGrossEnergyBaseIncome] >= 800 then iPercentMod = math.max(iPercentMod,  math.min(iPercentMod + 0.2, 0.275)) end

        if aiBrain[refbStallingEnergy] and aiBrain[refiGrossEnergyBaseIncome] - aiBrain[refiGrossEnergyWhenStalled] >= 45 then
            iPercentMod = iPercentMod -0.3
        end

        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyLandRush then
            iPercentMod = iPercentMod - 0.06
            iNetMod = iNetMod - 2.5
        end

        if aiBrain[refbStallingEnergy] and (aiBrain[refiGrossEnergyBaseIncome] >= 100000 or (aiBrain:GetEconomyStoredRatio('ENERGY') > math.min(0.95, (0.8 + iPercentMod)) or (aiBrain:GetEconomyStoredRatio('ENERGY') > (0.7 + iPercentMod) and aiBrain[refiNetEnergyBaseIncome] > (1 + iNetMod)) or (aiBrain:GetEconomyStoredRatio('ENERGY') > (0.5 + iPercentMod) and aiBrain[refiNetEnergyBaseIncome] > (4 + iNetMod)) or (GetGameTimeSeconds() <= 180 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.3)) or (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyLandRush and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.2 and aiBrain[refiNetEnergyBaseIncome] > 0)) then
            --aiBrain[refbStallingEnergy] = false
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Have enough energy stored or income to start unpausing things')
            end
            bChangeRequired = true
            bPauseNotUnpause = false
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Checking if we shoudl flag that we are energy stalling')
        end
        --Check if should manage energy stall
        if bChangeRequired == false and (aiBrain:GetEconomyStoredRatio('ENERGY') <= (0.08 + iPercentMod) or (aiBrain:GetEconomyStoredRatio('ENERGY') <= (0.6 + iPercentMod) and aiBrain[refiNetEnergyBaseIncome] < (2 + iNetMod)) or (aiBrain:GetEconomyStoredRatio('ENERGY') <= (0.4 + iPercentMod) and aiBrain[refiNetEnergyBaseIncome] < (0.5 + (aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] - 1) * 5 + iNetMod))) then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': We are stalling energy, will look for units to pause, subject to early game check')
            end
            --If this is early game then add extra check
            if GetGameTimeSeconds() >= 180 or aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.04 then
                aiBrain[refbStallingEnergy] = true
                bChangeRequired = true
                aiBrain[refiGrossEnergyWhenStalled] = aiBrain[refiGrossEnergyBaseIncome]
                if bDebugMessages == true then LOG(sFunctionRef..': early game check cleared, so are stalling energy') end
            end
        end

        if bChangeRequired then
            if bPauseNotUnpause then
                if bDebugMessages == true then LOG(sFunctionRef..': Change is required and we want to pause units') end
                aiBrain[refbStallingEnergy] = true
                aiBrain[refiGrossEnergyWhenStalled] = aiBrain[refiGrossEnergyBaseIncome]
            end --redundancy
            aiBrain[refiLastEnergyStall] = GetGameTimeSeconds()
            --Decide on order to pause/unpause

            local tCategoriesByPriority, tEngineerActionsByPriority = GetCategoriesAndActionsToPause(aiBrain)

            local iEnergyPerTickSavingNeeded
            if aiBrain[refbStallingEnergy] then
                iEnergyPerTickSavingNeeded = math.max(1, -aiBrain[refiNetEnergyBaseIncome] + iNetMod * 0.5 + aiBrain[refiGrossEnergyBaseIncome] * 0.02)
                if aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.15 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have less than 15% energy stored so increasing the energy saving wanted. iEnergyPerTickSavingNeeded pre increase='..iEnergyPerTickSavingNeeded..'; Gross base income='..aiBrain[refiGrossEnergyBaseIncome]..'; Cur energy storage units='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEnergyStorage)) end
                    local iStorageFactor = 50
                    if aiBrain[refiGrossEnergyBaseIncome] >= 1000 then iStorageFactor = 100 end
                    iEnergyPerTickSavingNeeded = math.max(iEnergyPerTickSavingNeeded * 1.3, iEnergyPerTickSavingNeeded + aiBrain[refiGrossEnergyBaseIncome] * 0.03)
                    iEnergyPerTickSavingNeeded = math.max(iEnergyPerTickSavingNeeded, aiBrain[refiGrossEnergyBaseIncome] * 0.06, math.min(aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEnergyStorage) * iStorageFactor, aiBrain[refiGrossEnergyBaseIncome]*0.15))
                elseif aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.225 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Less than 22.5% energy stored so increasing energy saving slightly') end
                    iEnergyPerTickSavingNeeded = math.max(iEnergyPerTickSavingNeeded * 1.15, iEnergyPerTickSavingNeeded + aiBrain[refiGrossEnergyBaseIncome] * 0.015)
                end
            else
                iEnergyPerTickSavingNeeded = math.min(-1, -aiBrain[refiNetEnergyBaseIncome])
                iEnergyPerTickSavingNeeded = math.max(iEnergyPerTickSavingNeeded, -300)
                if aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.75 then iEnergyPerTickSavingNeeded = iEnergyPerTickSavingNeeded * 0.75 end
            end

            local iEnergySavingManaged = 0
            local iEngineerSubtableCount = 0
            local tEngineerActionSubtable
            local tRelevantUnits, oUnit

            local bAbort = false
            local iTotalUnits = 0
            local iCategoryStartPoint, iIntervalChange, iCategoryEndPoint, iCategoryRef
            local bWasUnitPaused
            local bDontPauseShields = false
            if bPauseNotUnpause then
                iCategoryStartPoint = 1
                iIntervalChange = 1
                iCategoryEndPoint = table.getn(tCategoriesByPriority)
                --Pausing shields - if have lots of gross energy then dont want to do this
                if aiBrain[refiGrossEnergyBaseIncome] >= 750 then bDontPauseShields = true end
            else
                iCategoryStartPoint = table.getn(tCategoriesByPriority)
                iIntervalChange = -1
                iCategoryEndPoint = 1
            end

            local bConsideringHQ
            local bNoRelevantUnits = true

            if bDebugMessages == true then
                LOG(sFunctionRef .. ': About to cycle through every category, bPauseNotUnpause=' .. tostring(bPauseNotUnpause) .. '; iCategoryStartPoint=' .. iCategoryStartPoint .. '; iCategoryEndPoint=' .. iCategoryEndPoint .. '; strategy=' .. aiBrain[M27Overseer.refiAIBrainCurrentStrategy])
            end
            for iCategoryCount = iCategoryStartPoint, iCategoryEndPoint, iIntervalChange do
                iCategoryRef = tCategoriesByPriority[iCategoryCount]
                if bDontPauseShields and (iCategoryRef == M27UnitInfo.refCategoryPersonalShield or iCategoryRef == M27UnitInfo.refCategoryFixedShield or iCategoryRef == M27UnitInfo.refCategoryMobileLandShield) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Dont want to pause shields so will abort') end
                    break
                end

                --Are we considering upgrading factory HQs?
                if iCategoryRef == iSpecialHQCategory then
                    iCategoryRef = M27UnitInfo.refCategoryAllHQFactories
                    bConsideringHQ = true
                else
                    bConsideringHQ = false
                end

                if bPauseNotUnpause then
                    tRelevantUnits = aiBrain:GetListOfUnits(iCategoryRef, false, true)
                else
                    tRelevantUnits = EntityCategoryFilterDown(iCategoryRef, aiBrain[reftPausedUnits])
                end

                local iCurUnitEnergyUsage
                local bApplyActionToUnit
                local oBP
                if M27Utilities.IsTableEmpty(tRelevantUnits) == false then
                    bNoRelevantUnits = false
                    iTotalUnits = table.getn(tRelevantUnits)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Strategy='..aiBrain[M27Overseer.refiAIBrainCurrentStrategy]..'; iCategoryCount=' .. iCategoryCount .. '; iTotalUnits=' .. iTotalUnits .. '; bPauseNotUnpause=' .. tostring(bPauseNotUnpause))
                    end
                    if iCategoryRef == M27UnitInfo.refCategoryEngineer then
                        iEngineerSubtableCount = iEngineerSubtableCount + 1
                        tEngineerActionSubtable = tEngineerActionsByPriority[iEngineerSubtableCount]
                    end

                    for iUnit = iTotalUnits, 1, -1 do
                        oUnit = tRelevantUnits[iUnit]
                        --for iUnit, oUnit in tRelevantUnits do
                        bApplyActionToUnit = false
                        iCurUnitEnergyUsage = 0
                        if M27UnitInfo.IsUnitValid(oUnit, true) then --Only consider unit if it has been constructed
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': About to consider pausing/unpausingunit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; will first check category specific logic for if we want to go ahead with pausing4')
                            end


                            --Do we actually want to pause the unit? check any category specific logic
                            bApplyActionToUnit = true
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': UnitState=' .. M27Logic.GetUnitState(oUnit) .. '; Is ActiveHQUpgrades Empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades])))
                            end
                            --SMD LOGIC - Check if already have 1 missile loaded before pausing
                            if iCategoryRef == M27UnitInfo.refCategorySMD and oUnit.GetTacticalSiloAmmoCount and oUnit:GetTacticalSiloAmmoCount() >= 1 then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Have SMD with at least 1 missile so will pause it')
                                end
                                bApplyActionToUnit = false
                            elseif iCategoryRef == M27UnitInfo.refCategoryEngineer then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Have an engineer with action=' .. (oUnit[M27EngineerOverseer.refiEngineerCurrentAction] or 'nil') .. '; tEngineerActionSubtable=' .. repru(tEngineerActionSubtable))
                                end
                                bApplyActionToUnit = false
                                if not(oUnit[M27EngineerOverseer.refiEngineerCurrentAction]) and not(bPauseNotUnpause) then bApplyActionToUnit = true
                                else
                                    for iActionCount, iActionRef in tEngineerActionSubtable do
                                        if iActionRef == oUnit[M27EngineerOverseer.refiEngineerCurrentAction] then
                                            bApplyActionToUnit = true
                                            --Dont pause the last engi building power
                                            if bPauseNotUnpause and iActionRef == M27EngineerOverseer.refActionBuildPower and (oUnit[M27EngineerOverseer.refbPrimaryBuilder] or aiBrain:GetEconomyStoredRatio('MASS') >= 0.7) then
                                                bApplyActionToUnit = false
                                            end
                                            break
                                        end
                                    end
                                end
                            elseif iCategoryRef == M27UnitInfo.refCategoryPersonalShield or iCategoryRef == M27UnitInfo.refCategoryFixedShield or iCategoryRef == M27UnitInfo.refCategoryMobileLandShield then
                                --Dont disable shield if unit has enemies nearby
                                if bPauseNotUnpause and M27UnitInfo.IsUnitShieldEnabled(oUnit) and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, oUnit:GetPosition(), 40, 'Enemy')) == false then
                                    bApplyActionToUnit = false
                                end
                            elseif iCategoryRef == M27UnitInfo.refCategoryAirFactory or iCategoryRef == M27UnitInfo.refCategoryLandFactory then
                                --Dont want to pause an HQ upgrade since it will give us better power
                                if bPauseNotUnpause and not (bConsideringHQ) and oUnit:IsUnitState('Upgrading') and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false and EntityCategoryContains(categories.FACTORY, oUnit) then
                                    for iFactory, oFactory in aiBrain[reftActiveHQUpgrades] do
                                        if oUnit == oFactory then
                                            bApplyActionToUnit = false
                                            break
                                        end
                                    end
                                elseif not (bPauseNotUnpause) and bConsideringHQ then
                                    --Only unpause HQs
                                    bApplyActionToUnit = false
                                    if oUnit:IsUnitState('Upgrading') and M27Utilities.IsTableEmpty(aiBrain[reftActiveHQUpgrades]) == false then
                                        for iFactory, oFactory in aiBrain[reftActiveHQUpgrades] do
                                            if oUnit == oFactory then
                                                bApplyActionToUnit = true
                                                break
                                            end
                                        end
                                    end
                                end
                                if bApplyActionToUnit and bPauseNotUnpause then
                                    --Dont pause factory that is building an engineer or is an air factory that isnt building an air unit, if its our highest tech level and we dont have at least 5 engis of that tech level
                                    if M27UnitInfo.GetUnitTechLevel(oUnit) >= math.max(2, aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]) and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * M27UnitInfo.ConvertTechLevelToCategory(M27UnitInfo.GetUnitTechLevel(oUnit))) < 2 then
                                        --Dont pause factory as have too few engis and want to build power with those engis
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Have too few engineers so wont pause factory')
                                        end
                                        bApplyActionToUnit = false
                                    end
                                end
                            end

                            if iCategoryRef == categories.COMMAND then
                                --want in addition to above as ACU might have personal shield
                                if bPauseNotUnpause then
                                    if not (oUnit:IsUnitState('Upgrading')) then
                                        bApplyActionToUnit = false
                                    elseif oUnit.GetWorkProgress then
                                        if oUnit:GetWorkProgress() >= 0.85 then
                                            bApplyActionToUnit = false
                                            --dont pause t1 mex construction
                                        elseif oUnit.GetFocusUnit and oUnit:GetFocusUnit() and oUnit:GetFocusUnit().UnitId and EntityCategoryContains(M27UnitInfo.refCategoryT1Mex, oUnit:GetFocusUnit().UnitId) then
                                            bApplyActionToUnit = false
                                        elseif aiBrain[M27Overseer.refiDefaultStrategy] == M27Overseer.refStrategyTurtle and not(M27Conditions.DoesACUHaveUpgrade(aiBrain, oUnit)) then
                                            bApplyActionToUnit = false
                                        end
                                    end
                                else
                                    bApplyActionToUnit = true --redundancy - are unpausing units so want to unpause ACU asap
                                end
                            end


                            --Pause the unit

                            if bDebugMessages == true then LOG(sFunctionRef..': bApplyActionToUnit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'='..tostring(bApplyActionToUnit)) end

                            if bApplyActionToUnit then
                                bWasUnitPaused = oUnit[M27UnitInfo.refbPaused] --Means we will ignore the energy usage when calculating how much we have saved
                                oBP = oUnit:GetBlueprint()
                                iCurUnitEnergyUsage = oBP.Economy.MaintenanceConsumptionPerSecondEnergy

                                if (iCurUnitEnergyUsage or 0) == 0 or iCategoryRef == M27UnitInfo.refCategoryEngineer or iCategoryRef == M27UnitInfo.refCategoryMex or iCategoryRef == categories.COMMAND then
                                    --Approximate energy usage based on build rate as a very rough guide
                                    --examples: Upgrading mex to T3 costs 11E per BP; T3 power is 8.4; T1 power is 6; Guncom is 30; Laser is 178; Strat bomber is 15
                                    local iEnergyPerBP = 9
                                    if EntityCategoryContains(categories.SILO, oUnit.UnitId) and oBP.Economy.BuildRate then
                                        --Dealing with a silo so need to calculate energy usage differently
                                        iCurUnitEnergyUsage = 0
                                        for iWeapon, tWeapon in oBP.Weapon do
                                            if tWeapon.MaxProjectileStorage and tWeapon.ProjectileId then
                                                local oProjectileBP = __blueprints[tWeapon.ProjectileId]
                                                if oProjectileBP.Economy and oProjectileBP.Economy.BuildCostEnergy and oProjectileBP.Economy.BuildTime > 0 and oBP.Economy.BuildRate > 0 then
                                                    --(will multiply cost by 10% in later step)
                                                    iCurUnitEnergyUsage = oProjectileBP.Economy.BuildCostEnergy * oBP.Economy.BuildRate / oProjectileBP.Economy.BuildTime
                                                    --If are power stalling then assume we only save 80% of this, as might have adjacency
                                                    if bPauseNotUnpause then iCurUnitEnergyUsage = iCurUnitEnergyUsage * 0.8 end
                                                    break
                                                end
                                            end
                                        end
                                    else
                                        if iCategoryRef == categories.COMMAND and oUnit[M27UnitInfo.refsUpgradeRef] then
                                            --Determine energy cost per BP
                                            iEnergyPerBP = M27UnitInfo.GetUpgradeEnergyCost(oUnit, oUnit[M27UnitInfo.refsUpgradeRef]) / (M27UnitInfo.GetUpgradeBuildTime(oUnit, oUnit[M27UnitInfo.refsUpgradeRef]) or 1)
                                        else
                                            --Engineer - adjust energy consumption based on what are building
                                            iEnergyPerBP = 3
                                            if oUnit[M27EngineerOverseer.refiEngineerCurrentAction] and EntityCategoryContains(M27UnitInfo.refCategoryEngineer, oUnit.UnitId) then
                                                if oUnit[M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionAssistAirFactory then
                                                    iEnergyPerBP = 13
                                                elseif oUnit[M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionBuildSMD then
                                                    iEnergyPerBP = 17.9
                                                elseif oUnit[M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionBuildExperimental then
                                                    if aiBrain[M27EngineerOverseer.refiLastExperimentalReference] == M27EngineerOverseer.refiExperimentalAir then
                                                        iEnergyPerBP = 12 --approximation, aeon is higher, cybran much lower, sera around this
                                                    elseif aiBrain[M27EngineerOverseer.refiLastExperimentalReference] == M27EngineerOverseer.refiExperimentalArti then
                                                        if EntityCategoryContains(categories.UEF, oUnit.UnitId) then iEnergyPerBP = 20
                                                        elseif EntityCategoryContains(categories.CYBRAN, oUnit.UnitId) then iEnergyPerBP = 16.7
                                                        elseif EntityCategoryContains(categories.AEON, oUnit.UnitId) then iEnergyPerBP = 54
                                                        else
                                                            iEnergyPerBP = 15
                                                        end
                                                    elseif aiBrain[M27EngineerOverseer.refiLastExperimentalReference] == M27EngineerOverseer.refiExperimentalYolona then
                                                        iEnergyPerBP = 40
                                                    elseif aiBrain[M27EngineerOverseer.refiLastExperimentalReference] == M27EngineerOverseer.refiExperimentalParagon then
                                                        iEnergyPerBP = 23
                                                    end
                                                elseif oUnit[M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionBuildSecondExperimental then
                                                    if aiBrain[M27EngineerOverseer.refiLastSecondExperimentalRef] == M27EngineerOverseer.refiExperimentalAir then
                                                        iEnergyPerBP = 12 --approximation, aeon is higher, cybran much lower, sera around this
                                                    elseif aiBrain[M27EngineerOverseer.refiLastSecondExperimentalRef] == M27EngineerOverseer.refiExperimentalArti then
                                                        if EntityCategoryContains(categories.UEF, oUnit.UnitId) then iEnergyPerBP = 20
                                                        elseif EntityCategoryContains(categories.CYBRAN, oUnit.UnitId) then iEnergyPerBP = 16.7
                                                        elseif EntityCategoryContains(categories.AEON, oUnit.UnitId) then iEnergyPerBP = 54
                                                        else
                                                            iEnergyPerBP = 15
                                                        end
                                                    elseif aiBrain[M27EngineerOverseer.refiLastSecondExperimentalRef] == M27EngineerOverseer.refiExperimentalYolona then
                                                        iEnergyPerBP = 40
                                                    elseif aiBrain[M27EngineerOverseer.refiLastSecondExperimentalRef] == M27EngineerOverseer.refiExperimentalParagon then
                                                        iEnergyPerBP = 23
                                                    end
                                                else
                                                    if oUnit.GetFocusUnit then
                                                        local oFocusUnit = oUnit:GetFocusUnit()
                                                        if M27UnitInfo.IsUnitValid(oFocusUnit) then
                                                            if oFocusUnit:GetFractionComplete() < 1 then
                                                                local oBP = oFocusUnit:GetBlueprint()
                                                                iEnergyPerBP = (oBP.Economy.BuildCostEnergy or 1) / (oBP.Economy.BuildTime or 10000000)
                                                                if bDebugMessages == true then LOG(sFunctionRef..': Engineer is assisting unit '..oFocusUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oFocusUnit)..'; iEnergyPerBP='..iEnergyPerBP) end
                                                            else
                                                                iEnergyPerBP = 1 --The unit might be building something so dont want it as low as others
                                                            end
                                                        else
                                                            iEnergyPerBP = 0.1
                                                        end
                                                    else
                                                        iEnergyPerBP = 0.1
                                                    end
                                                end
                                            end
                                        end
                                        if oBP.Economy.BuildRate then
                                            iCurUnitEnergyUsage = oBP.Economy.BuildRate * iEnergyPerBP
                                            --Reduce this massively if unit isn't actually building anything
                                            if bPauseNotUnpause and (not(oUnit:IsUnitState('Building')) and not(oUnit:IsUnitState('Repairing')) and not(oUnit.GetWorkProgress and oUnit:GetWorkProgress() > 0)) then iCurUnitEnergyUsage = iCurUnitEnergyUsage * 0.01 end
                                        end
                                    end
                                end
                                --We're working in ticks so adjust energy usage accordingly
                                iCurUnitEnergyUsage = iCurUnitEnergyUsage * 0.1
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Estimated energy usage before factoring in unit state=' .. iCurUnitEnergyUsage..'; About to call the function PauseOrUnpauseEnergyUsage on unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; bPauseNotUnpause='..tostring(bPauseNotUnpause)..'; iUnitsAdjusted where expected to save energy='..iUnitsAdjusted)
                                end

                                if not((iCurUnitEnergyUsage or 0) == 0) then
                                    iUnitsAdjusted = iUnitsAdjusted + 1
                                    if bPauseNotUnpause and EntityCategoryContains(M27UnitInfo.refCategoryEngineer + M27UnitInfo.refCategoryAllFactories, oUnit.UnitId) then
                                        if not(oUnit:IsUnitState('Upgrading') or oUnit:IsUnitState('Repairing') or oUnit:IsUnitState('Building')) then
                                            iCurUnitEnergyUsage = iCurUnitEnergyUsage * 0.01
                                            if bDebugMessages == true then LOG(sFunctionRef..': Unit state='..M27Logic.GetUnitState(oUnit)..' so will set the amount of energy saved equal to just 1% of the actual value, so it is now '..iCurUnitEnergyUsage) end
                                        end
                                    end
                                end
                                M27UnitInfo.PauseOrUnpauseEnergyUsage(aiBrain, oUnit, bPauseNotUnpause)
                                --Cant move the below into unitinfo as get a crash if unitinfo tries to refernce the table of paused units
                                if bPauseNotUnpause then
                                    local bRecordUnit = true
                                    if M27Utilities.IsTableEmpty(aiBrain[reftPausedUnits]) == false then
                                        for iExistingUnit, oExistingUnit in aiBrain[reftPausedUnits] do
                                            if oExistingUnit == oUnit then
                                                bRecordUnit = false
                                                break
                                            end
                                        end
                                    end
                                    if bRecordUnit then
                                        table.insert(aiBrain[reftPausedUnits], oUnit)
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Added unit to tracker table, size=' .. table.getn(aiBrain[reftPausedUnits]))
                                        end
                                    elseif bDebugMessages == true then LOG(sFunctionRef..': Unit is already recorded in table of paused units')
                                    end
                                else
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Will remove unit from reftPausedUnits. Size of table before removal=' .. table.getn(aiBrain[reftPausedUnits]))
                                    end
                                    for iPausedUnit, oPausedUnit in aiBrain[reftPausedUnits] do
                                        if oPausedUnit == oUnit then
                                            table.remove(aiBrain[reftPausedUnits], iPausedUnit)
                                        end
                                    end
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Size of table after removal =' .. table.getn(aiBrain[reftPausedUnits]))
                                    end
                                end
                            end
                        end
                        if not (bWasUnitPaused) and bPauseNotUnpause then
                            iEnergySavingManaged = iEnergySavingManaged + iCurUnitEnergyUsage
                        elseif bWasUnitPaused and not (bPauseNotUnpause) then
                            iEnergySavingManaged = iEnergySavingManaged - iCurUnitEnergyUsage
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': iEnergySavingManaged=' .. iEnergySavingManaged .. '; iEnergyPerTickSavingNeeded=' .. iEnergyPerTickSavingNeeded .. '; aiBrain[refbStallingEnergy]=' .. tostring(aiBrain[refbStallingEnergy]))
                        end

                        if aiBrain[refbStallingEnergy] then
                            if iEnergySavingManaged > iEnergyPerTickSavingNeeded then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Estimate we have saved ' .. iEnergySavingManaged .. ' which is more tahn we wanted so will pause')
                                end
                                bAbort = true
                                break
                            end
                        else
                            if iEnergySavingManaged < iEnergyPerTickSavingNeeded then
                                bAbort = true
                                break
                            end
                        end
                    end
                elseif bDebugMessages == true then
                    LOG(sFunctionRef .. ': We have no units for iCategoryCount=' .. iCategoryCount)
                end
                if bAbort then
                    break
                end
            end
            if bDebugMessages == true then
                LOG(sFunctionRef .. 'If we have no paused units then will set us as not having an energy stall; is table empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftPausedUnits]))..'; aiBrain[refbStallingMass]='..tostring(aiBrain[refbStallingMass])..'; bPauseNotUnpause='..tostring(bPauseNotUnpause))
            end
            if M27Utilities.IsTableEmpty(aiBrain[reftPausedUnits]) or (aiBrain[refbStallingMass] and not(bPauseNotUnpause) and not(bHaveWeCappedUnpauseAmount)) then
                aiBrain[refbStallingEnergy] = false
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': We are no longer stalling energy')
                end
            else
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': About to check if we wanted to unpause units but havent unpaused anything; Size of table=' .. table.getn(aiBrain[reftPausedUnits]) .. '; iUnitsAdjusted=' .. iUnitsAdjusted .. '; bNoRelevantUnits=' .. tostring(bNoRelevantUnits) .. '; aiBrain[refbStallingEnergy]=' .. tostring(aiBrain[refbStallingEnergy]))
                end
                --Backup - sometimes we still have units in the table listed as being paused (e.g. if an engineer changes action to one that isnt listed as needing pausing) - unpause them if we couldnt find via category search
                if aiBrain[refbStallingEnergy] and not (bPauseNotUnpause) and (iUnitsAdjusted == 0 or bNoRelevantUnits) and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.95 then
                    --Have a decent amount of power, are flagged as stalling energy, but couldnt find any categories to unpause
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': werent able to find any units to unpause with normal approach so will unpause all remaining units')
                    end
                    local iLoopCountCheck = 0
                    local iMaxLoop = math.max(20, table.getn(aiBrain[reftPausedUnits]) + 1)
                    while M27Utilities.IsTableEmpty(aiBrain[reftPausedUnits]) == false do
                        iLoopCountCheck = iLoopCountCheck + 1
                        if iLoopCountCheck >= iMaxLoop then
                            M27Utilities.ErrorHandler('Infinite loop likely')
                            break
                        end
                        if M27Utilities.IsTableEmpty(aiBrain[reftPausedUnits]) == false then
                            for iUnit, oUnit in aiBrain[reftPausedUnits] do
                                if bDebugMessages == true then
                                    if M27UnitInfo.IsUnitValid(oUnit) then
                                        LOG(sFunctionRef .. ': About to unpause ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
                                    else
                                        LOG('Removing iUnit=' .. iUnit .. ' which is no longer valid')
                                    end
                                    LOG('Size of aiBrain[reftPausedUnits] before removal=' .. table.getn(aiBrain[reftPausedUnits]) .. '; will double check this size')
                                    local iActualSize = 0
                                    for iAltUnit, oAltUnit in aiBrain[reftPausedUnits] do
                                        iActualSize = iActualSize + 1
                                    end
                                    LOG('Actual size=' .. iActualSize)
                                end
                                if M27UnitInfo.IsUnitValid(oUnit) then
                                    M27UnitInfo.PauseOrUnpauseEnergyUsage(aiBrain, oUnit, false)
                                end
                                table.remove(aiBrain[reftPausedUnits], iUnit)
                                break
                            end
                        end
                    end
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': FInished unpausing units')
                    end
                end
            end
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': End of code, aiBrain[refbStallingEnergy]=' .. tostring(aiBrain[refbStallingEnergy]) .. '; bPauseNotUnpause=' .. tostring(bPauseNotUnpause) .. '; iUnitsAdjusted=' .. iUnitsAdjusted .. '; Game time=' .. GetGameTimeSeconds() .. '; Energy stored %=' .. aiBrain:GetEconomyStoredRatio('ENERGY') .. '; Net energy income=' .. aiBrain[refiNetEnergyBaseIncome] .. '; gross energy income=' .. aiBrain[refiGrossEnergyBaseIncome])
        end
        if aiBrain[refbStallingEnergy] then
            aiBrain[refiLastEnergyStall] = GetGameTimeSeconds()
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Will now call manage mass stalls if not stalling energy. aiBrain[refbStallingEnergy]='..tostring(aiBrain[refbStallingEnergy])..'; bChangeRequired='..tostring(bChangeRequired)) end
    if not(aiBrain[refbStallingEnergy]) and not(bChangeRequired) then
        ForkThread(ManageMassStalls, aiBrain)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetEnergyStorageMaximum(aiBrain)
    if aiBrain:GetEconomyStoredRatio('ENERGY') > 0 then return aiBrain:GetEconomyStored('ENERGY') / aiBrain:GetEconomyStoredRatio('ENERGY')
    else
        return aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEnergyStorage) * 7500 + aiBrain:GetCurrentUnits(categories.COMMAND) * 3900 + 100
    end
end

function GetMassStorageMaximum(aiBrain)
    if aiBrain:GetEconomyStoredRatio('MASS') > 0 then return aiBrain:GetEconomyStored('MASS') / aiBrain:GetEconomyStoredRatio('MASS')
    else
        return aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryMassStorage) * 500 + aiBrain:GetCurrentUnits(categories.COMMAND) * 650 + 150
    end
end

function UpgradeManager(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpgradeManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iCycleWaitTime = 40
    local iReducedWaitTime = 20
    local iShortestWaitTime = 10
    local iCurCycleTime

    aiBrain[refbWantMoreFactories] = true
    aiBrain[reftUpgrading] = {}
    aiBrain[refiPausedUpgradeCount] = 0
    aiBrain[refiEnergyStoredLastCycle] = 0
    aiBrain[refbPauseForPowerStall] = false
    aiBrain[reftMassStorageLocations] = {}
    aiBrain[refbWantToUpgradeMoreBuildings] = false
    aiBrain[reftPausedUnits] = {}
    aiBrain[refbStallingEnergy] = false
    aiBrain[refiGrossEnergyWhenStalled] = 0
    aiBrain[refbStallingMass] = false
    aiBrain[refiLastEnergyStall] = 0
    aiBrain[reftUnitsToReclaim] = {}
    aiBrain[reftoTMLToReclaim] = {}
    aiBrain[reftMexesToCtrlK] = {}
    aiBrain[reftT2MexesNearBase] = {}
    aiBrain[refoNearestT2MexToBase] = nil
    aiBrain[reftActiveHQUpgrades] = {}
    aiBrain[refiFailedUpgradeUnitSearchCount] = 0

    --Economy - placeholder
    aiBrain[refiGrossEnergyBaseIncome] = 2
    aiBrain[refiGrossMassBaseIncome] = 0.1
    aiBrain[refiNetEnergyBaseIncome] = 2
    aiBrain[refiNetMassBaseIncome] = 0.1

    --Initial wait:
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitTicks(300)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    while (not (aiBrain:IsDefeated()) and not(aiBrain.M27IsDefeated)) do
        if aiBrain.M27IsDefeated or M27Logic.iTimeOfLastBrainAllDefeated > 10 then
            break
        end
        --Decide when to refresh next - refresh sooner for energy stalls and mass overflows
        iCurCycleTime = iCycleWaitTime --default (is shortened if have lots to upgrade)
        --Shorten the shortest wait time at high energy levels if are stalling energy
        if iCycleWaitTime > 1 and aiBrain[refiGrossEnergyBaseIncome] >= 750 then
            if aiBrain[refbStallingEnergy] or aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.5 then
                iShortestWaitTime = math.floor(iShortestWaitTime * 0.5)
            end
        end
        ForkThread(UpgradeMainLoop, aiBrain)
        if aiBrain[refbWantToUpgradeMoreBuildings] then
            iCurCycleTime = iReducedWaitTime
            if aiBrain:GetEconomyStoredRatio('MASS') >= 0.7 and aiBrain:GetEconomyStored('MASS') >= 1000 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and aiBrain[refiNetEnergyBaseIncome] >= 5 and aiBrain[refiNetMassBaseIncome] > 0 then
                iCurCycleTime = iShortestWaitTime
            end
        end
        if iCurCycleTime > iShortestWaitTime and aiBrain[refbStallingEnergy] and aiBrain:GetEconomyStoredRatio('ENERGY') < 0.99 then iCurCycleTime = iShortestWaitTime end

        ForkThread(GetMassStorageTargets, aiBrain)
        ForkThread(GetUnitReclaimTargets, aiBrain)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': End of loop about to wait ' .. iCycleWaitTime .. ' ticks. aiBrain[refbWantToUpgradeMoreBuildings]=' .. tostring(aiBrain[refbWantToUpgradeMoreBuildings]) .. '; Mass stored %=' .. aiBrain:GetEconomyStoredRatio('MASS') .. '; Mass stored=' .. aiBrain:GetEconomyStored('MASS') .. '; Energy stored %=' .. aiBrain:GetEconomyStoredRatio('ENERGY') .. '; aiBrain[refiNetEnergyBaseIncome]=' .. aiBrain[refiNetEnergyBaseIncome] .. '; aiBrain[refiNetMassBaseIncome]=' .. aiBrain[refiNetMassBaseIncome])
        end

        ForkThread(ManageEnergyStalls, aiBrain)
        if aiBrain[refiGrossEnergyBaseIncome] >= 750 and GetGameTimeSeconds() - (aiBrain[refiLastEnergyStall] or -100) <= 10 then iCurCycleTime = iShortestWaitTime end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        iCurCycleTime = _G.MyM27Scheduler:WaitTicks(iCurCycleTime,iCurCycleTime + 0.5, 0.4)
        --WaitTicks(iCurCycleTime)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': End of loop after waiting ticks')
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdateIfJustBuiltLotsOfPower(oJustBuilt)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateIfJustBuiltLotsOfPower'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iMassGen
    local iEnergyGen
    local aiBrain = oJustBuilt:GetAIBrain()
    if EntityCategoryContains(M27UnitInfo.refCategoryParagon, oJustBuilt.UnitId) then
        iMassGen = 10000
        iEnergyGen = 1000000
    else
        local oBP = oJustBuilt:GetBlueprint()
        iMassGen = math.max(oBP.Economy.ProductionPerSecondMass or 0) * 0.1
        iEnergyGen = math.max(oBP.Economy.ProductionPerSecondEnergy or 0) * 0.1
    end
    --Set temporary flag that we have just built a lot of power (if we have)
    if iEnergyGen >= math.max(20, (aiBrain[refiGrossEnergyBaseIncome] * 0.2), -(aiBrain[refiNetEnergyBaseIncome] or 0)) and not(aiBrain[refbJustBuiltLotsOfPower]) then
        aiBrain[refbJustBuiltLotsOfPower] = true
        M27Utilities.DelayChangeVariable(aiBrain, refbJustBuiltLotsOfPower, false, 10)
        if bDebugMessages == true then LOG(sFunctionRef..': Just built a lot of power so will temporarily say we dont need more power') end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end
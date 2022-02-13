local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27PlatoonTemplates = import('/mods/M27AI/lua/AI/M27PlatoonTemplates.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')


local reftoCombatUnitsWaitingForAssignment = 'M27CombatUnitsWaitingForAssignment'

local refCategoryLandCombat = M27UnitInfo.refCategoryLandCombat
local refCategoryEngineer = M27UnitInfo.refCategoryEngineer
local refCategoryLandScout = M27UnitInfo.refCategoryLandScout
local refCategoryMAA = M27UnitInfo.refCategoryMAA
local refCategoryIndirectT2Plus = M27UnitInfo.refCategoryIndirectT2Plus
local refCategoryAllAir = M27UnitInfo.refCategoryAllAir

refbJustBuilt = 'M27JustBuilt' --Used to flag the unit may still be moving off the land factory/not yet had its commands cleared, so can look for this in other functions such as threat detection and scout and MAA formation
refbJustCleared = 'M27JustCleared' --Used to flag if we've just issued a clearcommands so the engineeroverseer workaround doesnt clear this cycle
refbProcessedForPlatoon = 'M27ProcessedForPlatoon' --Used to flag that platoon former has tried assigning to a platoon already
refbWaitingForAssignment = 'M27UnitIsWaitingForAssignment' --Used if are building up to a larger platoon size
refbUsingTanksForPlatoons = 'M27PlatoonFormerUsingTanksForPlatoons' --false if have no use for tanks so are putting them into attacknearest platoon
refbUsingMobileShieldsForPlatoons = 'M27PlatoonFormerUsingMobileShields' --false if dont ahve any platoons to assign mobile shields to
refiTimeLastCheckedForIdleShields = 'M27PlatoonFormerTimeCheckedIdleShields' --Gametime that last checked for idle shields

refoMAABasePatrolPlatoon = 'M27PlatoonFormerMAABasePatrol'
refoMAARallyPatrolPlatoon = 'M27PlatoonFormerMAARallyPatrol'
refoCombatPatrolPlatoon = 'M27PlatoonCombatPatrol'

local iIdleUnitSearchThreshold = 10

function CreatePlatoon(aiBrain, sPlatoonPlan, oPlatoonUnits) --, bRunImmediately)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CreatePlatoon'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oNewPlatoon
    if sPlatoonPlan == nil then
        M27Utilities.ErrorHandler('sPlatoonPlan is nil')
    else
        if sPlatoonPlan == 'M27MobileShield' then bDebugMessages = false end
        local tPlatoonTemplate = M27PlatoonTemplates.PlatoonTemplate[sPlatoonPlan]
        if M27Utilities.IsTableEmpty(tPlatoonTemplate) == true then
            M27Utilities.ErrorHandler('Dont have a platoon template for sPlatoonPlan='..sPlatoonPlan)
        else
            oNewPlatoon = aiBrain:MakePlatoon('', '')
            local sFormation = M27PlatoonTemplates.PlatoonTemplate[sPlatoonPlan][M27PlatoonTemplates.refsDefaultFormation]

            aiBrain:AssignUnitsToPlatoon(oNewPlatoon, oPlatoonUnits, 'Attack', sFormation)
            oNewPlatoon:SetAIPlan(sPlatoonPlan)
            if bDebugMessages == true then
                LOG(sFunctionRef..': Have just created a new platoon and set its plan to '..sPlatoonPlan..'; about to cycle through units added to it')
                for iUnit, oUnit in oPlatoonUnits do
                    LOG(sFunctionRef..': Added '..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit))
                end
            end
            --Removed below since the normal platoon logic should handle this if have assigend to a retreating platoon, and any other platoon would just override this with a new movement path anyway
            --[[if bRunImmediately then
                if bDebugMessages == true then LOG(sFunctionRef..': We want the units to run immediately') end
                IssueClearCommands(oPlatoonUnits)
                IssueMove(oPlatoonUnits, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            end--]]

            --Make sure our cycler works (the normal platoon.lua should do this but have come across some instances where it doesnt seem to work)
            ForkThread(M27PlatoonUtilities.PlatoonCycler, oNewPlatoon)
        end
    end
    --Check first unit has a platoon now
    if bDebugMessages == true then LOG(sFunctionRef..': Plan of First unit in oPlatoonUnits platoon='..oPlatoonUnits[1].PlatoonHandle:GetPlan()) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oNewPlatoon
end

function RefreshUnitsWaitingForAssignment(aiBrain)
    local sFunctionRef = 'RefreshUnitsWaitingForAssignment'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tUnitsWaiting = aiBrain[reftoCombatUnitsWaitingForAssignment]
    local tValidRemainingUnits = {}
    local iValidUnits = 0
    if M27Utilities.IsTableEmpty(tUnitsWaiting) == false then
        for iUnit, oUnit in tUnitsWaiting do
            if not(oUnit.Dead) then
                --Exclude T2+ indirect fire units
                if not(EntityCategoryContains(refCategoryIndirectT2Plus, oUnit:GetUnitId())) then
                    iValidUnits = iValidUnits + 1
                    tValidRemainingUnits[iValidUnits] = oUnit
                    oUnit[refbWaitingForAssignment] = true
                end
            end
        end
        aiBrain[reftoCombatUnitsWaitingForAssignment] = tValidRemainingUnits
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function PlatoonOrUnitNeedingEscortIsStillValid(aiBrain, oPlatoonOrUnit, bProvidingShieldEscort)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'PlatoonOrUnitNeedingEscortIsStillValid'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bStillValid = true
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    if oPlatoonOrUnit == nil or (not(oPlatoonOrUnit[M27PlatoonUtilities.refbShouldHaveEscort]) and not(bProvidingShieldEscort)) or (bProvidingShieldEscort and not(oPlatoonOrUnit[M27PlatoonTemplates.refbWantsShieldEscort])) then
        if bDebugMessages == true then
            LOG(sFunctionRef..': PlatoonOrUnit is no longer valid, or it is flagged to no longer need an escort')
            if oPlatoonOrUnit == nil then LOG('(cont) PlatoonorUnit is invalid') end
        end
        bStillValid = false
    else
        if oPlatoonOrUnit.GetUnitId then
            if oPlatoonOrUnit.Dead then
                if bDebugMessages == true then LOG(sFunctionRef..': Unit is dead') end
                bStillValid = false
            end
        else
            if oPlatoonOrUnit.GetPlatoonUnits and not(aiBrain:PlatoonExists(oPlatoonOrUnit)) then
                if bDebugMessages == true then LOG(sFunctionRef..': Platoon no longer exists') end
                bStillValid = false
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bStillValid
end

function GetPlatoonOrUnitToEscort(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetPlatoonOrUnitToEscort'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oPlatoonOrUnitToEscort = nil
    --Returns the platoon handle if we have one that needs an escort, otherwise returns nil
    local bRefreshPlatoonsNeedingEscortingList = false
    if bDebugMessages == true then LOG(sFunctionRef..': Have '..table.getn(aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts])..' platoons needing an escort') end
    for iPlatoon, oPlatoonOrUnit in aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts] do
        if PlatoonOrUnitNeedingEscortIsStillValid(aiBrain, oPlatoonOrUnit) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': iPlatoon='..iPlatoon..': Platoon is no longer valid') end
            bRefreshPlatoonsNeedingEscortingList = true
        else
            if bDebugMessages == true then
                local iPlatoonCount = oPlatoonOrUnit[M27PlatoonUtilities.refiPlatoonCount]
                if iPlatoonCount == nil then iPlatoonCount = 'nil' end
                local sPlan
                if oPlatoonOrUnit.GetUnitId then sPlan = oPlatoonOrUnit:GetUnitId()
                else sPlan = oPlatoonOrUnit:GetPlan() end
                LOG(sFunctionRef..': iPlatoon='..iPlatoon..'; Platoon plan and count='..sPlan..iPlatoonCount..'refiCurrentEscortThreat='..oPlatoonOrUnit[M27PlatoonUtilities.refiCurrentEscortThreat]..'; oPlatoonOrUnit[M27PlatoonUtilities.refiEscortThreatWanted]='..oPlatoonOrUnit[M27PlatoonUtilities.refiEscortThreatWanted])
            end
            if oPlatoonOrUnit[M27PlatoonUtilities.refiCurrentEscortThreat] < oPlatoonOrUnit[M27PlatoonUtilities.refiEscortThreatWanted] and oPlatoonOrUnit[M27PlatoonUtilities.refiCurrentUnits] then
                --Check if we have too many units in the escort
                local bHaveTooManyUnits = false
                local iMaxEscortSize = math.min(25, 5 * oPlatoonOrUnit[M27PlatoonUtilities.refiCurrentUnits])
                if oPlatoonOrUnit[M27PlatoonUtilities.refoEscortingPlatoon] and oPlatoonOrUnit[M27PlatoonUtilities.refoEscortingPlatoon][M27PlatoonUtilities.refiCurrentUnits] and oPlatoonOrUnit[M27PlatoonUtilities.refoEscortingPlatoon][M27PlatoonUtilities.refiCurrentUnits] > iMaxEscortSize then bHaveTooManyUnits = true end
                if bHaveTooManyUnits == false then
                    oPlatoonOrUnitToEscort = oPlatoonOrUnit
                    break
                end
            end
        end
    end

    if bDebugMessages == true then LOG(sFunctionRef..': About to refresh list of platoons needing an escort, current table size='..table.getn(aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts])) end

    if bRefreshPlatoonsNeedingEscortingList == true then
        bRefreshPlatoonsNeedingEscortingList = false

        for iPlatoon, oPlatoonOrUnit in aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts] do
            if PlatoonOrUnitNeedingEscortIsStillValid(aiBrain, oPlatoonOrUnit) == false then
                --bRefreshPlatoonsNeedingEscortingList = true
                if bDebugMessages == true then LOG(sFunctionRef..': Removing iPlatoon='..iPlatoon..' from platoon list; table size pre removal='..table.getn(aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts])) end
                oPlatoonOrUnit = nil
                --table.remove(aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts], iPlatoon)
                --break
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Finished refreshing list of platoons needing an escort, current table size='..table.getn(aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts])) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oPlatoonOrUnitToEscort
end


function CombatPlatoonFormer(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CombatPlatoonFormer'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, about to refresh units waiting for assignment') end


    RefreshUnitsWaitingForAssignment(aiBrain)


    --Remove any duplicate units from reftoCombatUnitsWaitingForAssignment
    if M27Utilities.IsTableEmpty(aiBrain[reftoCombatUnitsWaitingForAssignment]) == false then
        local tUniqueUnitListing = {}
        local sUniqueRef, oUnit, bRemoveFromTable
        for iUnit = table.getn(aiBrain[reftoCombatUnitsWaitingForAssignment]), 1, -1 do
            bRemoveFromTable = false
            oUnit = aiBrain[reftoCombatUnitsWaitingForAssignment][iUnit]
            if M27UnitInfo.IsUnitValid(oUnit) then
                sUniqueRef = oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)
                if tUniqueUnitListing[sUniqueRef] then bRemoveFromTable = true
                else tUniqueUnitListing[sUniqueRef] = true
                end
            else bRemoveFromTable = true
            end
            if bRemoveFromTable then
                if bDebugMessages == true then LOG(sFunctionRef..': Removing duplicate entry from table of units waiting for assignment') end
                table.remove(aiBrain[reftoCombatUnitsWaitingForAssignment], iUnit)
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef..': About to list out every unit in aiBrain[reftoCombatUnitsWaitingForAssignment]')
        if M27Utilities.IsTableEmpty(aiBrain[reftoCombatUnitsWaitingForAssignment]) == false then
            for iUnit, oUnit in aiBrain[reftoCombatUnitsWaitingForAssignment] do
                LOG(oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit))
            end
        end
    end

    local tUnitsWaiting = {}
    local iUnitsWaiting = 0
    local tSuicideUnits = {}
    if M27Utilities.IsTableEmpty(aiBrain[reftoCombatUnitsWaitingForAssignment]) == false then
        if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 2 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * categories.TECH2 + M27UnitInfo.refCategoryEngineer * categories.TECH3) >= 3  then
            for iUnit, oUnit in aiBrain[reftoCombatUnitsWaitingForAssignment] do
                if EntityCategoryContains(categories.ALLUNITS - categories.COMMAND -M27UnitInfo.refCategoryLandExperimental, oUnit:GetUnitId()) then
                    --Consider if should assign to suicide squad instead
                    if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == false and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] == true and EntityCategoryContains(categories.TECH1 * M27UnitInfo.refCategoryDFTank, oUnit:GetUnitId()) and M27UnitInfo.GetUnitPathingType(oUnit) == M27UnitInfo.refPathingTypeLand then
                        table.insert(tSuicideUnits, oUnit)
                    else
                        iUnitsWaiting = iUnitsWaiting + 1
                        tUnitsWaiting[iUnitsWaiting] = oUnit
                    end
                end
            end
        else
            for iUnit, oUnit in aiBrain[reftoCombatUnitsWaitingForAssignment] do
                iUnitsWaiting = iUnitsWaiting + 1
                tUnitsWaiting[iUnitsWaiting] = oUnit
            end
        end
    end
    --Form suicide squad
    if M27Utilities.IsTableEmpty(tSuicideUnits) == false then
        CreatePlatoon(aiBrain, 'M27SuicideSquad', tSuicideUnits)
    end



    local bAreUsingCombatPatrolUnits = false
    if bDebugMessages == true then
        LOG(sFunctionRef..': Is tUnitsWaiting empty='..tostring(M27Utilities.IsTableEmpty(tUnitsWaiting))..'; does the combat patrol platoon exist?')
        if aiBrain[refoCombatPatrolPlatoon] then
            LOG('It exists, now seeing if aiBrain check returns true')
            if aiBrain:PlatoonExists(aiBrain[refoCombatPatrolPlatoon]) then
                LOG('aiBrain says it exists, number of units in it='..(aiBrain[refoCombatPatrolPlatoon][M27PlatoonUtilities.refiCurrentUnits] or 'nil'))
            end
        end
    end

    if M27Utilities.IsTableEmpty(tUnitsWaiting) == false then
        --Exclude ACU and experimentals - now done above
        --if bDebugMessages == true then LOG(sFunctionRef..': Removing any ACUs and experimentals from the units to form platoons with as backup as these are dealt with separately') end
        --tUnitsWaiting = EntityCategoryFilterDown(categories.ALLUNITS - categories.COMMAND -M27UnitInfo.refCategoryLandExperimental, tUnitsWaiting)
        --[[
        --Check if ACU is one of the units
        local iCurCount = 0
        local tUnitsToExclude = EntityCategoryFilterDown(categories.COMMAND + M27UnitInfo.refCategoryLandExperimental, tUnitsWaiting)
        local iMaxLoop = table.getn(tUnitsToExclude) + 1

        while M27Utilities.IsTableEmpty(tUnitsToExclude) == false do
            iCurCount = iCurCount + 1
            if iCurCount > iMaxLoop then M27Utilities.ErrorHandler('Likely infinite loop') break end
            for iUnit, oUnit in tUnitsWaiting do
                if EntityCategoryContains(categories.COMMAND, oUnit:GetUnitId()) then
                    table.remove(aiBrain[reftoCombatUnitsWaitingForAssignment], iUnit)
                    tUnitsWaiting = aiBrain[reftoCombatUnitsWaitingForAssignment]
                    break
                elseif EntityCategoryContains(M27UnitInfo.refCategoryLandExperimental, oUnit:GetUnitId()) then
                    local oNewPlatoon = CreatePlatoon(aiBrain, 'M27GroundExperimental', {oUnit})
                    table.remove(aiBrain[reftoCombatUnitsWaitingForAssignment], iUnit)
                    tUnitsWaiting = aiBrain[reftoCombatUnitsWaitingForAssignment]
                    break
                end
            end
            tUnitsToExclude = EntityCategoryFilterDown(categories.COMMAND + M27UnitInfo.refCategoryLandExperimental, tUnitsWaiting)
        end--]]

        --iUnitsWaiting = table.getn(tUnitsWaiting)
        --local tDFUnitsWaiting, tIndirectT1UnitsWaiting, tIndirectT2PlusUnitsWaiting, iDFUnitsWaiting, iIndirectT1UnitsWaiting, iIndirectT2PlusUnitsWaiting

        --if M27Utilities.IsTableEmpty(tUnitsWaiting) == false then
            if bDebugMessages == true then
                LOG(sFunctionRef..': iUnitsWaiting='..iUnitsWaiting..'; About to list out every unit in tUnitsWaiting')
                if M27Utilities.IsTableEmpty(tUnitsWaiting) == true then LOG('Table is empty')
                else
                    for iUnit, oUnit in tUnitsWaiting do
                        local iUniqueID = M27UnitInfo.GetUnitLifetimeCount(oUnit)
                        if iUniqueID == nil then iUniqueID = 0 end
                        LOG('iUnit='..iUnit..'; Blueprint+UniqueCount='..oUnit:GetUnitId()..iUniqueID)
                    end
                end
            end


            local iStrategy = aiBrain[M27Overseer.refiAIBrainCurrentStrategy]
            local iCurrentConditionToTry = 1
            local sPlatoonToForm, iRaiders, iDefenceCoverage, oPlatoonOrUnitToEscort
            iDefenceCoverage = aiBrain[M27Overseer.refiPercentageOutstandingThreat]
            if bDebugMessages == true then LOG(sFunctionRef..': iDefenceCoverage='..iDefenceCoverage..'; iStrategy='..iStrategy) end
            local iCount = 0
            while sPlatoonToForm == nil do
                oPlatoonOrUnitToEscort = nil
                iCount = iCount + 1 if iCount > 100 then M27Utilities.ErrorHandler('Infinite loop') break end
                aiBrain[refbUsingTanksForPlatoons] = true
                if iStrategy == M27Overseer.refStrategyLandEarly then
                    if bDebugMessages == true then LOG(sFunctionRef..'We are using early land strategy, decide what platoon to form') end
                    if iCurrentConditionToTry == 1 then --Initial land raiders
                        if aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27MexRaiderAI'] < aiBrain[M27Overseer.refiInitialRaiderPlatoonsWanted] then
                            sPlatoonToForm = 'M27MexRaiderAI' end
                    elseif iCurrentConditionToTry == 2 then --Emergency defence
                        --iDefenceCoverage = aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat]
                        if iDefenceCoverage < 0.3 and M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, aiBrain[M27Overseer.reftLocationFromStartNearestThreat]) == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then sPlatoonToForm = 'M27DefenderAI' end
                    elseif iCurrentConditionToTry == 3 then
                        --Platoon escorts
                        if bDebugMessages == true then LOG(sFunctionRef..': Checking if need escorts, IsTableEmpty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts]))) end
                        if M27Utilities.IsTableEmpty(aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts]) == false then
                            oPlatoonOrUnitToEscort = GetPlatoonOrUnitToEscort(aiBrain)
                            if oPlatoonOrUnitToEscort then sPlatoonToForm = 'M27EscortAI' end
                        end
                    elseif iCurrentConditionToTry == 4 then --1 active raider
                        aiBrain[M27PlatoonUtilities.refbNeedEscortUnits] = false --Have just gone through the escort conditions - if not allocated to it, then suggests we dont need any more units
                        iRaiders = M27PlatoonUtilities.GetActivePlatoonCount(aiBrain, 'M27MexLargerRaiderAI')
                        if bDebugMessages == true then LOG(sFunctionRef..': iRaiders='..iRaiders) end
                        if iRaiders < 1 then sPlatoonToForm = 'M27MexLargerRaiderAI' end
                    elseif iCurrentConditionToTry == 5 then
                        if iDefenceCoverage < 0.4 and M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, aiBrain[M27Overseer.reftLocationFromStartNearestThreat]) == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])  then sPlatoonToForm = 'M27DefenderAI' end
                    elseif iCurrentConditionToTry == 6 then
                        if iRaiders < 2 then sPlatoonToForm = 'M27MexLargerRaiderAI' end

                    elseif iCurrentConditionToTry == 7 then
                        if iRaiders < 3 then sPlatoonToForm = 'M27MexLargerRaiderAI' end
                    elseif iCurrentConditionToTry == 8 then
                        if iDefenceCoverage < aiBrain[M27Overseer.refiMaxDefenceCoverageWanted] and M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, aiBrain[M27Overseer.reftLocationFromStartNearestThreat]) == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then sPlatoonToForm = 'M27DefenderAI' end
                    elseif iCurrentConditionToTry == 9 then
                        if M27PlatoonUtilities.GetActivePlatoonCount(aiBrain, 'M27LargeAttackForce') < 1 and (aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 3 or aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] >= M27Overseer.iDistanceToEnemyEcoThreshold) then
                            --Does the ACU need help? If not, then can form a large platoon
                            local bACUNeedsHelp = false
                            local oACU = M27Utilities.GetACU(aiBrain)
                            if oACU:GetHealthPercent() <= 0.75 then
                                local oComPlatoon = oACU.GetPlatoonHandle
                                if oComPlatoon and oComPlatoon[M27PlatoonUtilities.refiEnemiesInRange] and oComPlatoon[M27PlatoonUtilities.refiEnemiesInRange] > 0 then
                                    bACUNeedsHelp = true
                                end
                            end
                            if bACUNeedsHelp == false then
                                sPlatoonToForm = 'M27LargeAttackForce'
                                if bDebugMessages == true then LOG(sFunctionRef..': Seeting platoon to form to be large attack force') end
                            end
                        end
                    elseif iCurrentConditionToTry == 10 then
                        if iRaiders < 5 then sPlatoonToForm = 'M27MexLargerRaiderAI' end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Dont meet any other conditions so will form attackenarestunit platoon') end
                        sPlatoonToForm = 'M27AttackNearestUnits'
                        aiBrain[refbUsingTanksForPlatoons] = false
                        break
                    end
                elseif iStrategy == M27Overseer.refStrategyEcoAndTech or iStrategy == M27Overseer.refStrategyAirDominance then
                    --Defend with coverage up to the max % value specified, and have 1 active raider
                    if bDebugMessages == true then LOG(sFunctionRef..': Start of loop for eco strategy, iCurrentConditionToTry='..iCurrentConditionToTry) end
                    aiBrain[refbUsingTanksForPlatoons] = true
                    if iCurrentConditionToTry == 1 then --Emergency defence
                        --iDefenceCoverage = aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat]
                        if iDefenceCoverage < 0.3 and M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, aiBrain[M27Overseer.reftLocationFromStartNearestThreat]) == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then sPlatoonToForm = 'M27DefenderAI' end
                    elseif iCurrentConditionToTry == 2 then
                        --Platoon escorts
                        if bDebugMessages == true then LOG(sFunctionRef..': Checking if need escorts, IsTableEmpty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts]))) end
                        if M27Utilities.IsTableEmpty(aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts]) == false then
                            oPlatoonOrUnitToEscort = GetPlatoonOrUnitToEscort(aiBrain)
                            if oPlatoonOrUnitToEscort then sPlatoonToForm = 'M27EscortAI' end
                        end
                    elseif iCurrentConditionToTry == 3 then
                        aiBrain[M27PlatoonUtilities.refbNeedEscortUnits] = false --Have just gone through the escort conditions - if not allocated to it, then suggests we dont need any more units
                        if iDefenceCoverage < 0.5 and M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, aiBrain[M27Overseer.reftLocationFromStartNearestThreat]) == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then sPlatoonToForm = 'M27DefenderAI' end
                    elseif iCurrentConditionToTry == 4 then --1 active raider
                        iRaiders = M27PlatoonUtilities.GetActivePlatoonCount(aiBrain, 'M27MexLargerRaiderAI')
                        if bDebugMessages == true then LOG(sFunctionRef..': iRaiders='..iRaiders) end
                        if iRaiders < 1 then sPlatoonToForm = 'M27MexLargerRaiderAI' end
                    elseif iCurrentConditionToTry == 5 then
                        if iDefenceCoverage < aiBrain[M27Overseer.refiMaxDefenceCoverageWanted] and M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, aiBrain[M27Overseer.reftLocationFromStartNearestThreat]) == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then sPlatoonToForm = 'M27DefenderAI' end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Dont meet any other conditions so will form attackenarestunit platoon') end
                        sPlatoonToForm = 'M27CombatPatrolAI'
                        aiBrain[refbUsingTanksForPlatoons] = false
                        break
                    end
                elseif iStrategy == M27Overseer.refStrategyACUKill then
                    sPlatoonToForm = 'M27AttackNearestUnits'
                elseif iStrategy == M27Overseer.refStrategyProtectACU then
                    sPlatoonToForm = 'M27EscortAI'
                    oPlatoonOrUnitToEscort = M27Utilities.GetACU(aiBrain).PlatoonHandle
                else
                    M27Utilities.ErrorHandler('Dont have a recognised strategy')
                end
                iCurrentConditionToTry = iCurrentConditionToTry + 1
            end

            if bDebugMessages == true then LOG(sFunctionRef..': Finished looping throug hplatoon former conditions to work out what platoon to form. aiBrain[refbUsingTanksForPlatoons]='..tostring(aiBrain[refbUsingTanksForPlatoons])..'; sPlatoonToForm='..(sPlatoonToForm or 'nil')) end

            if sPlatoonToForm == nil then
                M27Utilities.ErrorHandler('Werent able to figure out a platoon for a combat unit to go into')
            else
                --Do we have enough units for this platoon?
                local iMinSize = M27PlatoonTemplates.PlatoonTemplate[sPlatoonToForm][M27PlatoonTemplates.refiMinimumPlatoonSize]
                if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry after increasing by 1='..iCurrentConditionToTry..'; sPlatoonWanted='..sPlatoonToForm..'; iMinSize='..iMinSize..'; iUnitsWaiting='..iUnitsWaiting) end
                --Add combat patrol platoon to units that are waiting if we dont want to form a combat patrol platoon
                if not(sPlatoonToForm == 'M27CombatPatrolAI') then
                    if aiBrain[refoCombatPatrolPlatoon] and aiBrain:PlatoonExists(aiBrain[refoCombatPatrolPlatoon]) and aiBrain[refoCombatPatrolPlatoon][M27PlatoonUtilities.refiCurrentUnits] > 0 and (aiBrain[refoCombatPatrolPlatoon][M27PlatoonUtilities.refiEnemiesInRange] or 0) <= 0 then
                        --if M27Utilities.IsTableEmpty(tUnitsWaiting) == false then iUnitsWaiting = table.getn(tUnitsWaiting) end
                        for iUnit, oUnit in aiBrain[refoCombatPatrolPlatoon]:GetPlatoonUnits() do
                            if M27UnitInfo.IsUnitValid(oUnit) then
                                iUnitsWaiting = iUnitsWaiting + 1
                                tUnitsWaiting[iUnitsWaiting] = oUnit
                            end
                        end
                        bAreUsingCombatPatrolUnits = true
                        if bDebugMessages == true then LOG(sFunctionRef..': Have combat patrol units so setting units waiting to be the units in the combat patrol platoon. IsTableEmpty='..tostring(M27Utilities.IsTableEmpty(tUnitsWaiting))..'; iUnitsWaiting='..iUnitsWaiting) end
                    end
                end



                if iUnitsWaiting >= iMinSize then
                    if bDebugMessages == true then LOG(sFunctionRef..': Checking whether we have a platoon/unit to escort or not. bAreUsingCombatPatrolUnits='..tostring(bAreUsingCombatPatrolUnits)) end
                    --Are we an escort platoon?
                    local tTemporaryUnitsWaitingForAssignment = {}
                    local iTemporaryUnitsWaitingForAssignment = 0
                    if oPlatoonOrUnitToEscort then
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Have a platoon or unit to escort, will note its ID in a moment')
                            if oPlatoonOrUnitToEscort.PlatoonHandle then LOG(oPlatoonOrUnitToEscort:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oPlatoonOrUnitToEscort))
                            else LOG(oPlatoonOrUnitToEscort:GetPlan()..oPlatoonOrUnitToEscort[M27PlatoonUtilities.refiPlatoonCount])
                            end
                        end
                        --Determine if we want all of the units that are waiting for assignment
                        --GetCombatThreatRating(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, iMassValueOfBlipsOverride, iSoloBlipMassOverride)
                        if not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyProtectACU) then --If protecting ACU then want to assign every unit to ACU's escort
                            local iThreatOfUnitsWaitingForAssignment = M27Logic.GetCombatThreatRating(aiBrain, tUnitsWaiting, false, nil, nil)
                            local iExcessThreat = math.max(0, iThreatOfUnitsWaitingForAssignment + oPlatoonOrUnitToEscort[M27PlatoonUtilities.refiCurrentEscortThreat] - oPlatoonOrUnitToEscort[M27PlatoonUtilities.refiEscortThreatWanted])
                            if bDebugMessages == true then LOG(sFunctionRef..': Will remove excess threat before forming the escort from waiting units. iExcessThreat='..iExcessThreat..'; iThreatOfUnitsWaitingForAssignment='..iThreatOfUnitsWaitingForAssignment..'; oPlatoonOrUnitToEscort[M27PlatoonUtilities.refiCurrentEscortThreat]='..oPlatoonOrUnitToEscort[M27PlatoonUtilities.refiCurrentEscortThreat]..'; oPlatoonOrUnitToEscort[M27PlatoonUtilities.refiEscortThreatWanted]='..oPlatoonOrUnitToEscort[M27PlatoonUtilities.refiEscortThreatWanted]) end
                            if iExcessThreat > 100 then
                                --Temporarily move spare units waiting for assignment into a different platoon until we've removing all spare units/threat
                                local iCurLoopCount = 0
                                local iCurUnitRef
                                for iCurUnitRef = iUnitsWaiting, 1, -1 do
                                --while iExcessThreat > 100 do
                                    iCurLoopCount = iCurLoopCount + 1
                                    if iCurLoopCount > 100 then M27Utilities.ErrorHandler('Likely infinite loop as have been through 100 units waiting for assignment') break
                                    else
                                        --iCurUnitRef = table.getn(tUnitsWaiting)
                                        if iCurUnitRef <= 1 then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Only have 1 unit left in the table so will just assign a bit more threat unless its massively over; will list out every unit if we are stopping here; iUnitsWaiting='..iUnitsWaiting) end
                                            if iExcessThreat < 5000 then
                                                if bDebugMessages == true then
                                                    for iUnit, oUnit in tUnitsWaiting do
                                                        LOG(oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit))
                                                    end
                                                end
                                                break
                                            end
                                        end

                                        if bDebugMessages == true then LOG(sFunctionRef..': iCurLoopCount='..iCurLoopCount..'; iCurUnitRef='..iCurUnitRef) end
                                        if tUnitsWaiting[iCurUnitRef] then
                                            local iLastTableUnitThreat = M27Logic.GetCombatThreatRating(aiBrain, {tUnitsWaiting[iCurUnitRef]}, false, nil, nil)
                                            if bDebugMessages == true then LOG(sFunctionRef..': iLastTableUnitThreat='..iLastTableUnitThreat..'; iExcessThreat='..iExcessThreat) end
                                            if iLastTableUnitThreat > iExcessThreat then
                                                break
                                            else
                                                iTemporaryUnitsWaitingForAssignment = iTemporaryUnitsWaitingForAssignment + 1
                                                tTemporaryUnitsWaitingForAssignment[iTemporaryUnitsWaitingForAssignment] = tUnitsWaiting[iCurUnitRef]
                                                table.remove(tUnitsWaiting, iCurUnitRef)
                                                iExcessThreat = iExcessThreat - iLastTableUnitThreat
                                                iUnitsWaiting = iUnitsWaiting - 1
                                                if bDebugMessages == true then LOG(sFunctionRef..': Removed unit from tUnitsWaiting, iExcessThreat after reducing for this='..iExcessThreat..'; size of tUnitsWaiting='..table.getn(tUnitsWaiting)) end
                                                if M27Utilities.IsTableEmpty(tUnitsWaiting) == true then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': No units left to assign as escort') end
                                                    break
                                                elseif iExcessThreat <= 0 then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Excess threat is below 0 now so wont remove anything further') end
                                                    break
                                                end
                                            end
                                        else break
                                        end
                                    end
                                end
                            end
                        elseif bDebugMessages == true then LOG(sFunctionRef..': Strategy is to protect ACU so dont want to reduce number of units assigned to the escort')
                        end
                    elseif bDebugMessages == true then LOG(sFunctionRef..': Dont have a platoon or unit to escort')
                    end
                    --if not(bAreUsingCombatPatrolUnits) or not(sPlatoonToForm == 'M27CombatPatrolAI') then
                        --if bDebugMessages == true then LOG(sFunctionRef..': Arent using combat patrol units or platoon to form isnt the combat patrol AI') end
                        if oPlatoonOrUnitToEscort and oPlatoonOrUnitToEscort[M27PlatoonUtilities.refoEscortingPlatoon] and aiBrain:PlatoonExists(oPlatoonOrUnitToEscort[M27PlatoonUtilities.refoEscortingPlatoon]) then
                            --Add to existing platoon
                            if bDebugMessages == true then LOG(sFunctionRef..': Have a platoon or unit to escort that already has an assigned escort so will assign units to existing escort') end
                            aiBrain:AssignUnitsToPlatoon(oPlatoonOrUnitToEscort[M27PlatoonUtilities.refoEscortingPlatoon], tUnitsWaiting, 'Attack', 'GrowthFormation')
                        elseif sPlatoonToForm == 'M27CombatPatrolAI' then
                            if bDebugMessages == true then LOG(sFunctionRef..': want to use a combat patrol platoon; will see if we already have one and if so add units to that') end
                            if aiBrain[refoCombatPatrolPlatoon] and aiBrain:PlatoonExists(aiBrain[refoCombatPatrolPlatoon]) then
                                aiBrain:AssignUnitsToPlatoon(aiBrain[refoCombatPatrolPlatoon], tUnitsWaiting, 'Attack', 'GrowthFormation')
                                if bDebugMessages == true then LOG(sFunctionRef..': Platoon already exists so have just assigned tUnitsWaiting to the combat patrol platoon, plan='..aiBrain[refoCombatPatrolPlatoon]:GetPlan()..(aiBrain[refoCombatPatrolPlatoon][M27PlatoonUtilities.refiPlatoonCount] or 'nil')) end
                            else
                                aiBrain[refoCombatPatrolPlatoon] = CreatePlatoon(aiBrain, sPlatoonToForm, tUnitsWaiting)
                                if bDebugMessages == true then LOG(sFunctionRef..': Have created a new platoon for the waiting units to join') end
                            end
                        else
                            if M27Utilities.IsTableEmpty(tUnitsWaiting) == true then
                                M27Utilities.ErrorHandler('tUnitsWaiting is nil, wont form a platoon afterall')
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Creating new platoon and assigning units to it') end
                                local oNewPlatoon = CreatePlatoon(aiBrain, sPlatoonToForm, tUnitsWaiting)
                                if oPlatoonOrUnitToEscort then
                                    if bDebugMessages == true then LOG(sFunctionRef..': oPlatoonOrUnitToEscort doesnt have an escorting platoon assigned to it') end
                                    oNewPlatoon[M27PlatoonUtilities.refoPlatoonOrUnitToEscort] = oPlatoonOrUnitToEscort
                                    oPlatoonOrUnitToEscort[M27PlatoonUtilities.refoEscortingPlatoon] = oNewPlatoon
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Will update units that were flagged as waiting for assignment to say they are no longer waiting for assignment, and then clear the table of units waiting for assignment') end
                        for iUnit, oUnit in aiBrain[reftoCombatUnitsWaitingForAssignment] do
                            oUnit[refbWaitingForAssignment] = false
                        end
                        aiBrain[reftoCombatUnitsWaitingForAssignment] = {}
                        --Did we have too many units for assignment? If so then move spare ones back to be waiting for assignment
                        if iTemporaryUnitsWaitingForAssignment > 0 then
                            if bDebugMessages == true then LOG(sFunctionRef..': We had too many units for assignment, so will now add any spare units back to be waiting for assignment. iTemporaryUnitsWaitingForAssignment='..iTemporaryUnitsWaitingForAssignment) end
                            if not(bAreUsingCombatPatrolUnits) then
                                for iUnit, oUnit in tTemporaryUnitsWaitingForAssignment do
                                    aiBrain[reftoCombatUnitsWaitingForAssignment][iUnit] = oUnit
                                end
                            end
                        end
                    --end
                else
                    --Get the units that are waiting to move to the rally point nearest the enemy
                    if bDebugMessages == true then LOG(sFunctionRef..': Dont have enough units for min size, iUnitsWaiting='..iUnitsWaiting..'; iMinSize='..iMinSize..' so will send them to intel path temporarily') end
                    if aiBrain[M27Overseer.refbIntelPathsGenerated] == true then
                        --[[local iIntelPathPoint = aiBrain[M27Overseer.refiCurIntelLineTarget]
                        if iIntelPathPoint == nil then iIntelPathPoint = 1
                        else
                            iIntelPathPoint = iIntelPathPoint - 2
                            if iIntelPathPoint <= 0 then iIntelPathPoint = 1 end
                        end
                        local tTargetPosition = aiBrain[M27Overseer.reftIntelLinePositions][iIntelPathPoint][1]
                        --]]
                        local tTargetPosition = M27Logic.GetNearestRallyPoint(aiBrain, M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
                        --Modify position if its close to a factory
                        --[[local iCurLoop = 0
                        local iMaxLoop = 10
                        local tBasePosition = {tTargetPosition[1], tTargetPosition[2], tTargetPosition[3]}
                        if M27Utilities.IsTableEmpty(tBasePosition) == true then
                            M27Utilities.ErrorHandler('tBasePosition is empty, will give logs to help figure out why and set the rally point to our start position')
                            if aiBrain[M27Overseer.refiCurIntelLineTarget] then
                                LOG('aiBrain[M27Overseer.refiCurIntelLineTarget]='..aiBrain[M27Overseer.refiCurIntelLineTarget])
                            else LOG('aiBrain[M27Overseer.refiCurIntelLineTarget] is nil')
                            end
                            if iIntelPathPoint == nil then LOG('iIntelPathPoint is nil') else LOG('iIntelPathPoint='..iIntelPathPoint) end
                            if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftIntelLinePositions][iIntelPathPoint]) == true then
                                LOG('reftIntelLinePositions is empty for iIntelPathPoint '..iIntelPathPoint)
                            else
                                LOG('aiBrain[M27Overseer.reftIntelLinePositions][iIntelPathCurTarget] isnt empty, will now check the first point in it')
                                if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftIntelLinePositions][iIntelPathPoint][1]) == true then
                                    LOG('intel path point 1 is empty')
                                else LOG('Intel path point 1='..repr(aiBrain[M27Overseer.reftIntelLinePositions][iIntelPathPoint][1]))
                                end
                            end
                            local tStartPoint = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                            tBasePosition = {tStartPoint[1], tStartPoint[2], tStartPoint[3]}
                        end

                        local tEnemyStartPosition = M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]
                        local bHaveValidLocation = false
                        local oPathingUnitExample = aiBrain[reftoCombatUnitsWaitingForAssignment][1]
                        local sPathing = M27UnitInfo.GetUnitPathingType(oPathingUnitExample)
                        local iStartSegmentX, iStartSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tBasePosition)
                        local iBaseGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iStartSegmentX, iStartSegmentZ)
                        local iNewPositionGroup = iBaseGroup
                        local iNewPositionSegmentX, iNewPositionSegmentZ
                        while bHaveValidLocation == false do
                            if iNewPositionGroup == iBaseGroup and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandFactory, tTargetPosition, 8, 'Ally'))==true then
                                bHaveValidLocation = true
                                break
                            else
                                iCurLoop = iCurLoop + 1
                                if iCurLoop > iMaxLoop then M27Utilities.ErrorHandler('Infinite loop') break end
                                --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
                                tTargetPosition = M27Utilities.MoveTowardsTarget(tBasePosition, tEnemyStartPosition, 5 * iCurLoop, 0)
                                iNewPositionSegmentX, iNewPositionSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tTargetPosition)
                                iNewPositionGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iNewPositionSegmentX, iNewPositionSegmentZ)
                            end
                        end --]]
                        if M27Utilities.IsTableEmpty(tTargetPosition) == false then
                            if bDebugMessages == true then LOG(sFunctionRef..': About to clear commands for all units waiting for assignment to a platoon and tell them to move to '..repr(tTargetPosition)) end
                            IssueClearCommands(aiBrain[reftoCombatUnitsWaitingForAssignment])
                            IssueMove(aiBrain[reftoCombatUnitsWaitingForAssignment], tTargetPosition)
                            if M27Config.M27ShowUnitNames == true then M27PlatoonUtilities.UpdateUnitNames(aiBrain[reftoCombatUnitsWaitingForAssignment], 'WaitingToForm '..sPlatoonToForm) end
                        else M27Utilities.ErrorHandler('target position doesnt exist')
                        end

                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Dont have intel path generated yet so wont try to move to a new rally point') end
                    end
                end
            end
        --end
        --Are we still using units, but are using them from the combat patrol platoon and still ahve units left in this platoon?
        if bAreUsingCombatPatrolUnits and aiBrain[refbUsingTanksForPlatoons] == true and aiBrain[refoCombatPatrolPlatoon] and aiBrain:PlatoonExists(aiBrain[refoCombatPatrolPlatoon]) and M27Utilities.IsTableEmpty(aiBrain[refoCombatPatrolPlatoon]:GetPlatoonUnits()) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Are using combat patrol units and still have units left in the patrol platoon so will say we arent actually using tanks that we build') end
            aiBrain[refbUsingTanksForPlatoons] = false
        end
    else if bDebugMessages == true then LOG(sFunctionRef..': No units waiting for assigment to a platoon') end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function AddIdleUnitsToPlatoon(aiBrain, tUnits, oPlatoonToAddTo)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AddIdleUnitsToPlatoon'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local sPlatoonName = 'None'
    if oPlatoonToAddTo.GetPlan then
        sPlatoonName = oPlatoonToAddTo:GetPlan()
        if bDebugMessages == true then LOG(sFunctionRef..': sPlatoonName='..sPlatoonName..'; tUnits size='..table.getn(tUnits)) end
        aiBrain:AssignUnitsToPlatoon(oPlatoonToAddTo, tUnits, 'Support', 'GrowthFormation')
        if M27Config.M27ShowUnitNames == true and oPlatoonToAddTo[M27PlatoonTemplates.refbDontDisplayName] then
            local sName = sPlatoonName..':'
            local iLifetimeCount
            for iUnit, oUnit in tUnits do
                if oUnit.GetUnitId then sName = sName..oUnit:GetUnitId() end
                iLifetimeCount = M27UnitInfo.GetUnitLifetimeCount(oUnit)
                if not(iLifetimeCount) then iLifetimeCount = 0 end
                sName = sName..iLifetimeCount
                if oUnit.SetCustomName then oUnit:SetCustomName(sName) end
            end
        end
    else M27Utilities.ErrorHandler('no plan for oPlatoonToAddTo, aborting allocation - SetupIdlePlatoon needs to be added on initialisation for every idle platoon plan') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function AllocateUnitsToIdlePlatoons(aiBrain, tNewUnits)
    --Will allocate units to idle platoon based on their type
    --See platoon templates for platoons that are idle
    --Assumes units all have the same aiBrain

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AllocateUnitsToIdlePlatoons'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if M27Utilities.IsTableEmpty(tNewUnits) == true then M27Utilities.ErrorHandler('tNewUnits is empty')
    else
        local tScouts = {}
        local tMAA = {}
        local tACU = {}
        local tCombat = {}
        local tLandExperimentals = {}
        local tIndirect = {}
        local tEngi = {}
        local tStructures = {}
        local tAir = {}
        local tMobileShield = {}
        local tOther = {}
        local tUnderConstruction = {}

        local sUnitID
        local bHaveValidUnit = false
        for iUnit, oUnit in tNewUnits do
            if not(aiBrain) then
                aiBrain = oUnit:GetAIBrain()
                if not(aiBrain.M27AI) then
                    M27Utilities.ErrorHandler('Have called this function on a non-M27AI, something likely has gone wrong')
                    aiBrain = nil
                end
            end
            if not(oUnit.Dead) then
                if oUnit:GetFractionComplete() < 1 then table.insert(tUnderConstruction, oUnit)
                else
                    if not(oUnit[refbWaitingForAssignment]) then
                        bHaveValidUnit = true
                        sUnitID = oUnit:GetUnitId()
                        if EntityCategoryContains(refCategoryLandScout, sUnitID) then
                            table.insert(tScouts, oUnit)
                            --Enable stealth on cybran moles (but not selens)
                            if oUnit:GetBlueprint().Intel.Cloak and (oUnit:GetBlueprint().Intel.StealthWaitTime or 0) == 0 then
                                M27UnitInfo.EnableUnitStealth(oUnit)
                            end
                        elseif EntityCategoryContains(refCategoryMAA, sUnitID) then table.insert(tMAA, oUnit)
                        elseif EntityCategoryContains(categories.COMMAND, sUnitID) then table.insert(tACU, oUnit)
                        elseif EntityCategoryContains(refCategoryEngineer, sUnitID) then table.insert(tEngi, oUnit)
                        elseif EntityCategoryContains(categories.STRUCTURE, sUnitID) then table.insert(tStructures, oUnit)
                        elseif EntityCategoryContains(M27UnitInfo.refCategoryLandExperimental, sUnitID) then table.insert(tLandExperimentals, oUnit)
                        elseif EntityCategoryContains(refCategoryLandCombat, sUnitID) then table.insert(tCombat, oUnit)
                        elseif EntityCategoryContains(refCategoryIndirectT2Plus, sUnitID) then table.insert(tIndirect, oUnit)
                        elseif EntityCategoryContains(refCategoryAllAir, sUnitID) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Adding air unit '..sUnitID..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to table to include in air platoon') end
                            table.insert(tAir, oUnit)
                            --Enable stealth on any air units
                            if EntityCategoryContains(categories.STEALTH, sUnitID) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Unit contains stealth so will enable stealth on it') end
                                M27UnitInfo.EnableUnitStealth(oUnit)
                            end
                        elseif EntityCategoryContains(M27UnitInfo.refCategoryMobileLandShield, sUnitID) then table.insert(tMobileShield, oUnit)
                        else table.insert(tOther, oUnit) end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..'; sUnitID='..oUnit:GetUnitId()) end
                    end
                end
            end
        end
        if bHaveValidUnit == true then
            if M27Utilities.IsTableEmpty(tUnderConstruction) == false then AddIdleUnitsToPlatoon(aiBrain, tUnderConstruction, aiBrain[M27PlatoonTemplates.refoUnderConstruction]) end
            if M27Utilities.IsTableEmpty(tScouts) == false then AddIdleUnitsToPlatoon(aiBrain, tScouts, aiBrain[M27PlatoonTemplates.refoIdleScouts]) end
            if M27Utilities.IsTableEmpty(tMAA) == false then AddIdleUnitsToPlatoon(aiBrain, tMAA, aiBrain[M27PlatoonTemplates.refoIdleMAA]) end
            if M27Utilities.IsTableEmpty(tACU) == false then
                if tACU[1] and tACU[1][M27Overseer.refbACUOnInitialBuildOrder] == true then
                    AddIdleUnitsToPlatoon(aiBrain, tEngi, aiBrain[M27PlatoonTemplates.refoAllEngineers])
                else
                    CreatePlatoon(aiBrain, 'M27ACUMain', tACU)
                end
            end
            if M27Utilities.IsTableEmpty(tEngi) == false then AddIdleUnitsToPlatoon(aiBrain, tEngi, aiBrain[M27PlatoonTemplates.refoAllEngineers]) end
            if M27Utilities.IsTableEmpty(tLandExperimentals) == false then local oNewPlatoon = CreatePlatoon(aiBrain, 'M27GroundExperimental', tLandExperimentals) end
            if M27Utilities.IsTableEmpty(tCombat) == false then
                AddIdleUnitsToPlatoon(aiBrain, tCombat, aiBrain[M27PlatoonTemplates.refoIdleCombat])
                AllocateNewUnitsToPlatoonNotFromFactory(tCombat)
            end
            if M27Utilities.IsTableEmpty(tIndirect) == false then AddIdleUnitsToPlatoon(aiBrain, tIndirect, aiBrain[M27PlatoonTemplates.refoIdleIndirect]) end
            if M27Utilities.IsTableEmpty(tStructures) == false then AddIdleUnitsToPlatoon(aiBrain, tStructures, aiBrain[M27PlatoonTemplates.refoAllStructures]) end
            if M27Utilities.IsTableEmpty(tAir) == false then AddIdleUnitsToPlatoon(aiBrain, tAir, aiBrain[M27PlatoonTemplates.refoIdleAir]) end
            if M27Utilities.IsTableEmpty(tMobileShield) == false then AllocateNewUnitsToPlatoonNotFromFactory(tMobileShield) end
            if M27Utilities.IsTableEmpty(tOther) == false then AddIdleUnitsToPlatoon(aiBrain, tOther, aiBrain[M27PlatoonTemplates.refoIdleOther]) end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DoesPlatoonWantAnotherMobileShield(oPlatoon, iShieldMass, bCheckIfRemoveExistingShield)
    local sFunctionRef = 'DoesPlatoonWantAnotherMobileShield'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if oPlatoon[M27PlatoonUtilities.refbACUInPlatoon] == true then bDebugMessages = true end

    local iPlatoonValueToShieldRatio = 3.5 --want 3.5 mass in the platoon for every 1 mass in the shield

    if bDebugMessages == true then
        if oPlatoon.GetUnitId then LOG(sFunctionRef..': About to consider if Unit='..oPlatoon:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oPlatoon)..' wants a shield.  oPlatoon[M27PlatoonTemplates.refbWantsShieldEscort]='..tostring(oPlatoon[M27PlatoonTemplates.refbWantsShieldEscort])..'; oPlatoon[M27PlatoonUtilities.refiPlatoonMassValue]='..(oPlatoon[M27PlatoonUtilities.refiPlatoonMassValue] or 'nil'))
        else LOG(sFunctionRef..': About to consider if oPlatoon '..oPlatoon:GetPlan()..(oPlatoon[M27PlatoonUtilities.refiPlatoonCount] or 'nil')..' wants a shield; oPlatoon[M27PlatoonTemplates.refbWantsShieldEscort]='..tostring(oPlatoon[M27PlatoonTemplates.refbWantsShieldEscort]))
        end
    end
    if oPlatoon and oPlatoon[M27PlatoonTemplates.refbWantsShieldEscort] and oPlatoon[M27PlatoonUtilities.refiPlatoonMassValue] > 0 then
        if oPlatoon[M27PlatoonUtilities.refbACUInPlatoon] then
            --bDebugMessages = true
            iPlatoonValueToShieldRatio = 2.5 end
        if bCheckIfRemoveExistingShield then
            iPlatoonValueToShieldRatio = 1.5
        end
        --Do we have enough shields already assigned and/or enough threat value to be worth assigning?
        local iPlatoonMass = oPlatoon[M27PlatoonUtilities.refiPlatoonMassValue]
        --If not dealing with a platoon but instead a unit then cap the mass value (as e.g. we're dealing with a mex)

        local iShieldValueHave = 0
        if oPlatoon.GetUnitId then
            if bDebugMessages == true then LOG(sFunctionRef..': Pre cap on mass value: iPlatoonMass='..iPlatoonMass..'; iPlatoonValueToShieldRatio='..iPlatoonValueToShieldRatio..'; iShieldMass='..iShieldMass) end
            if oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon] and oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon].GetPlan then
                iShieldValueHave = oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon][M27PlatoonUtilities.refiPlatoonMassValue]
            end
            iPlatoonMass = math.min(iPlatoonMass, iPlatoonValueToShieldRatio * iShieldMass + 50)
            iPlatoonMass = math.max((iShieldValueHave or 0), iPlatoonMass)
            if bDebugMessages == true then LOG(sFunctionRef..': Dealing with a unit such as a mex; iPlatoonMass after cap='..iPlatoonMass) end
        end
        local iShieldValueWanted = iPlatoonMass / iPlatoonValueToShieldRatio
        local iShieldUnitsHave = 0
        if oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon] and oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon].GetPlan then
            iShieldValueHave = oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon][M27PlatoonUtilities.refiPlatoonMassValue]
            if bDebugMessages == true then LOG(sFunctionRef..': have a supporting shield platoon, will compare the mass value of that to what we want; iShieldValueHave='..(iShieldValueHave or 'nil')) end
            if iShieldValueHave == nil then
                M27PlatoonUtilities.RecordPlatoonUnitsByType(oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon])
                iShieldValueHave = oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon][M27PlatoonUtilities.refiPlatoonMassValue]
                if iShieldValueHave == nil then iShieldValueHave = 0 end
            end
            iShieldUnitsHave = oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon][M27PlatoonUtilities.refiCurrentUnits]
            if iShieldUnitsHave == nil then iShieldUnitsHave = 0 end
            if bDebugMessages == true then
                LOG(sFunctionRef..': Supporting shield platoon details='..oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon]:GetPlan()..(oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon][M27PlatoonUtilities.refiPlatoonCount] or 'nil'))
                local tShieldPlatoonUnits = oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon]:GetPlatoonUnits()
                if M27Utilities.IsTableEmpty(tShieldPlatoonUnits) == true then
                    LOG('Shield platoon units is empty')
                    if M27Utilities.IsTableEmpty(oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon][M27PlatoonUtilities.reftCurrentUnits]) == true then LOG('reftCurrentUnits is also empty') else LOG('reftCurrentUnits isnt empty though') end
                else LOG('Size of shield platoon units='..table.getn(tShieldPlatoonUnits)..'; will list out each unit')
                    for iShield, oShield in tShieldPlatoonUnits do
                        LOG('Shield unit='..oShield:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oShield))
                    end
                end
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Dont have an existing supporting shield platoon') end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': iShieldValueWanted='..iShieldValueWanted..'; iShieldValueHave='..iShieldValueHave..'; iShieldMass='..iShieldMass..'; iShieldUnitsHave='..iShieldUnitsHave) end
        if iShieldValueWanted > (iShieldValueHave + iShieldMass) and iShieldUnitsHave < 5 then
            if bDebugMessages == true then LOG(sFunctionRef..': Returning true as the shield value wanted is more than the value we have plus shield mass, and we have fewer than 5 shield units') end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return true
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Returning false') end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return false
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': Platoon hasnt said that it wants a shield so returning false') end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return false
    end
end

function GetClosestPlatoonWantingMobileShield(aiBrain, tStartPosition, oShield)

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetClosestPlatoonWantingMobileShield'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iClosestDistanceToUs = 100000
    local iCurDistanceToUs
    local oClosestPlatoon
    local iShieldMass = oShield:GetBlueprint().Economy.BuildCostMass
    local iShieldPathingGroup = M27MapInfo.GetUnitSegmentGroup(oShield)
    local sShieldPathing = M27UnitInfo.GetUnitPathingType(oShield)
    if bDebugMessages == true then LOG(sFunctionRef..': oShield='..oShield:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oShield)) end
    if bDebugMessages == true then LOG(sFunctionRef..' iShieldMass='..iShieldMass) end
    local iTargetPathingGroup
    local sPlan
    for iPlatoon, oPlatoon in aiBrain:GetPlatoonsList() do
        if oPlatoon.GetPlan then
            sPlan = oPlatoon:GetPlan()
            if sPlan then
                --if oPlatoon[M27PlatoonUtilities.refbACUInPlatoon] == true then bDebugMessages = true end
                if bDebugMessages == true then LOG(sFunctionRef..': Platoon plan='..oPlatoon:GetPlan()..(oPlatoon[M27PlatoonUtilities.refiPlatoonCount] or 'nil')) end
                if bDebugMessages == true then LOG(sFunctionRef..': About to consider if oPlatoon '..oPlatoon:GetPlan()..(oPlatoon[M27PlatoonUtilities.refiPlatoonCount] or 'nil')..' and if it wants mobile shields') end
                if DoesPlatoonWantAnotherMobileShield(oPlatoon, iShieldMass) == true then
                    if oPlatoon[M27PlatoonUtilities.refbACUInPlatoon] then
                        if bDebugMessages == true then LOG(sFunctionRef..': ACU in platoon so make it a high priority') end
                        iCurDistanceToUs = -1 else
                        iCurDistanceToUs = M27Utilities.GetDistanceBetweenPositions(tStartPosition, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon))
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': Platoon wants another shield, will see if its closest to us; iCurDistanceToUs='..iCurDistanceToUs..'; iClosestDistanceToUs='..iClosestDistanceToUs) end
                    if iCurDistanceToUs < iClosestDistanceToUs then
                        --Can shield path to the platoon?
                        iTargetPathingGroup = M27MapInfo.GetSegmentGroupOfLocation(sShieldPathing, M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon))
                        if iTargetPathingGroup == iShieldPathingGroup then
                            if bDebugMessages == true then LOG(sFunctionRef..': Shield can path to the target') end
                            iClosestDistanceToUs = iCurDistanceToUs
                            oClosestPlatoon = oPlatoon
                            if oPlatoon[M27PlatoonUtilities.refbACUInPlatoon] then
                                break --Prioritise ACU over all other platoons
                            end
                        elseif bDebugMessages == true then LOG(sFunctionRef..': Shield cant path to the target')
                        end
                    end
                end
            end
        end
    end
    if bDebugMessages == true then
        if not(oClosestPlatoon) then LOG('No platoons found that want shields')
        else
            LOG(sFunctionRef..': Returning oClosestPlatoon as wanting a shield, oClosestPlatoon='..oClosestPlatoon:GetPlan()..oClosestPlatoon[M27PlatoonUtilities.refiPlatoonCount])
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oClosestPlatoon
end

function MAAPlatoonFormer(aiBrain, tMAA)
    --Assign MAA to a MAA patrol AI platoon by default (units will then be taken from here to MAA assister platoons as and when theyre needed)
    local sFunctionRef = 'MAAPlatoonFormer'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local oPlatoonToAddTo
    if aiBrain[refoMAABasePatrolPlatoon] == nil or (aiBrain[refoMAABasePatrolPlatoon][M27PlatoonUtilities.refiCurrentUnits] or 0) == 0 then
        oPlatoonToAddTo = CreatePlatoon(aiBrain, 'M27MAAPatrol', tMAA)
        oPlatoonToAddTo[M27PlatoonUtilities.reftLocationToGuard] = aiBrain[M27MapInfo.reftRallyPoints][1]
        if bDebugMessages == true then LOG(sFunctionRef..': Created new MAA patrol platoon for the base MAA platoon and set location to guard='..repr(oPlatoonToAddTo[M27PlatoonUtilities.reftLocationToGuard])) end
    elseif aiBrain[refoMAARallyPatrolPlatoon] == nil or (aiBrain[refoMAABasePatrolPlatoon][M27PlatoonUtilities.refiCurrentUnits] or 0) == 0 then
        oPlatoonToAddTo = CreatePlatoon(aiBrain, 'M27MAAPatrol', tMAA)
        oPlatoonToAddTo[M27PlatoonUtilities.reftLocationToGuard] = M27MapInfo.GetNearestRallyPoint(aiBrain, M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
        if bDebugMessages == true then LOG(sFunctionRef..': Created new MAA patrol platoon for the rally point MAA platoon and set location to guard='..repr(oPlatoonToAddTo[M27PlatoonUtilities.reftLocationToGuard])) end
    else
        --Which platoon needs more MAA if we want 60:40 ratio for base:rally point?
        if aiBrain[refoMAABasePatrolPlatoon][M27PlatoonUtilities.refiPlatoonThreatValue] * 0.6 < aiBrain[refoMAARallyPatrolPlatoon][M27PlatoonUtilities.refiPlatoonThreatValue] * 0.4 then
            oPlatoonToAddTo = aiBrain[refoMAABasePatrolPlatoon]
        else oPlatoonToAddTo = aiBrain[refoMAARallyPatrolPlatoon]
        end
        AddIdleUnitsToPlatoon(aiBrain, tMAA, oPlatoonToAddTo)
        if bDebugMessages == true then LOG(sFunctionRef..': Added MAA to platoon '..oPlatoonToAddTo:GetPlan()..oPlatoonToAddTo[M27PlatoonUtilities.refiPlatoonCount]) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function MobileShieldPlatoonFormer(aiBrain, tMobileShieldUnits)
    local sFunctionRef = 'MobileShieldPlatoonFormer'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local tStartPosition
    local bHaveUnitsToAssign = true
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code; size of tMobileShieldUnits='..table.getn(tMobileShieldUnits)) end

    local oPlatoonToHelp, oShieldPlatoon
    local iCurCount = 0
    local iMaxLoop = 50
    local oCurUnitToAssign
    local bRetreatCurShield
    local iEnemySearchRange = math.max(60, aiBrain[M27Overseer.refiSearchRangeForEnemyStructures])
    local iBaseSafeDistance = 60
    aiBrain[refbUsingMobileShieldsForPlatoons] = true
    local iPlatoonRefreshCount = 0
    local iShieldMass
    local bNoMorePlatoonsToHelp = false

    while bHaveUnitsToAssign == true do
        iCurCount = iCurCount + 1
        if iCurCount > iMaxLoop then M27Utilities.ErrorHandler('Infinite loop or excessive mobile shields') break end
        if M27Utilities.IsTableEmpty(tMobileShieldUnits) == false then
            for iUnit, oUnit in tMobileShieldUnits do
                if M27UnitInfo.IsUnitValid(oUnit) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering shield oUnit='..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                    --Are we already in a mobile shield platoon?
                    if oUnit.PlatoonHandle and oUnit.PlatoonHandle.GetPlan and oUnit.PlatoonHandle:GetPlan() == 'M27MobileShield' then
                        if bDebugMessages == true then LOG(sFunctionRef..': Are already in a mobile shield platoon') end
                        --Do nothing
                    else
                        oCurUnitToAssign = oUnit
                        tMobileShieldUnits[iUnit] = nil
                        bRetreatCurShield = true
                        tStartPosition = oCurUnitToAssign:GetPosition()
                        --Do we want to assign to a platoon or run away?
                        if bDebugMessages == true then LOG(sFunctionRef..': ShieldRatio='..oUnit:GetShieldRatio(true)) end
                        if oUnit:GetShieldRatio(true) >= 0.8 then --WARNING: Mustnt be higher than the logic for retreating a shield or else risk infinite loop
                            --Are we either close to our base or have no enemy untis near the shield?
                            if M27Utilities.GetDistanceBetweenPositions(tStartPosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iBaseSafeDistance then
                                if bDebugMessages == true then LOG(sFunctionRef..': Close to base so will stop retreating') end
                                bRetreatCurShield = false
                            else
                                if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(categories.ALLUNITS - M27UnitInfo.refCategoryAirAA - M27UnitInfo.refCategoryAirScout, tStartPosition, iEnemySearchRange, 'Enemy')) == true then
                                    if bDebugMessages == true then LOG(sFunctionRef..': No nearby enemies so will stop retreating') end
                                    bRetreatCurShield = false
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': Nearby enemies so want to keep retreating') end
                                end
                            end
                        else if bDebugMessages == true then LOG(sFunctionRef..': Units shield isnt recharegd yet so want to run') end
                        end
                        break
                    end
                end
            end
        else oCurUnitToAssign = nil end
        if oCurUnitToAssign then
            if bDebugMessages == true then LOG(sFunctionRef..': We have a shield unit to assign; bRetreatCurShield='..tostring(bRetreatCurShield)) end
            if bRetreatCurShield == true then
                if oCurUnitToAssign.Platoonhandle and oCurUnitToAssign.Platoonhandle.GetPlan and oCurUnitToAssign.Platoonhandle:GetPlan() == 'M27RetreatingShieldUnits' then
                    --Do nothing
                    if bDebugMessages == true then LOG(sFunctionRef..': Want to retreat cur shield, but it already is in a retreating shield platoon') end
                else
                    oShieldPlatoon = CreatePlatoon(aiBrain, 'M27RetreatingShieldUnits', {oCurUnitToAssign}, true)
                    if bDebugMessages == true then LOG(sFunctionRef..': Want to retreat cur shield, so have created a new retreating shield platoon for it') end
                end
            else
                --Get the platoon to help
                if bDebugMessages == true then LOG(sFunctionRef..': Look for platoon that wants shield; bNoMorePlatoonsToHelp='..tostring(bNoMorePlatoonsToHelp)) end
                iShieldMass = oCurUnitToAssign:GetBlueprint().Economy.BuildCostMass
                if bNoMorePlatoonsToHelp == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': Get a platoon if this is the first time running (otherwise will only get new platoon if current assigned platoon doesnt want more shields); iPlatoonRefreshCount='..iPlatoonRefreshCount) end
                    if iPlatoonRefreshCount == 0 then
                        oPlatoonToHelp = GetClosestPlatoonWantingMobileShield(aiBrain, tStartPosition, oCurUnitToAssign)
                        iPlatoonRefreshCount = 1
                    else
                        if oPlatoonToHelp and DoesPlatoonWantAnotherMobileShield(oPlatoonToHelp, iShieldMass) == false then
                            if bDebugMessages == true then LOG(sFunctionRef..': Cur platoon no longer wants a mobile shield so getting a new one') end
                            oPlatoonToHelp = GetClosestPlatoonWantingMobileShield(aiBrain, tStartPosition, oCurUnitToAssign)
                        end
                    end
                end

                local oMexToHelp
                if not(oPlatoonToHelp) then
                    bNoMorePlatoonsToHelp = true
                    --No platoon to help; do we have any mexes to shield instead?
                    if bDebugMessages == true then LOG(sFunctionRef..': Have no more platoons to help, checking if we need to guard mexes') end
                    if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyTML]) == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have enemy TML, size='..table.getn(aiBrain[M27Overseer.reftEnemyTML])) end
                        --Search for nearest mex without a shield assigned
                        local tBuildingsWantingShield = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryT3Mex + M27UnitInfo.refCategoryT3Radar, false, false)
                        if M27Utilities.IsTableEmpty(tBuildingsWantingShield) == false then
                            if bDebugMessages == true then LOG(sFunctionRef..': tBuildingsWantingShield size='..table.getn(tBuildingsWantingShield)) end
                            for iMex, oMex in tBuildingsWantingShield do
                                if M27UnitInfo.IsUnitValid(oMex) then
                                    if bDebugMessages == true then LOG(sFunctionRef..'iMex='..iMex..'; oMex='..oMex:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oMex)) end
                                    M27PlatoonUtilities.RecordPlatoonUnitsByType(oMex, true)
                                    oMex[M27PlatoonTemplates.refbWantsShieldEscort] = true
                                    if DoesPlatoonWantAnotherMobileShield(oMex, iShieldMass) == true then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Have a mex to help') end
                                        oMexToHelp = oMex
                                        break
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': Mex doesnt want shield coverage') end
                                    end
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': iMex='..iMex..': Unit is not valid') end
                                end
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': tBuildingsWantingShield is empty') end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': No enemy TML detected') end
                    end
                end
                local oUnitOrPlatoonToHelp = oPlatoonToHelp
                if oUnitOrPlatoonToHelp == nil then
                    if bDebugMessages == true and oMexToHelp then LOG(sFunctionRef..': Assigning the mex as the unit or platoon needing help') end
                    oUnitOrPlatoonToHelp = oMexToHelp
                end
                if not(oUnitOrPlatoonToHelp) then
                    if bDebugMessages == true then LOG(sFunctionRef..': No platoons or TML threatened mexes to help, will tell platoon to go to rally point') end
                    aiBrain[refbUsingMobileShieldsForPlatoons] = false
                    --Retreat the shield
                    IssueClearCommands({oCurUnitToAssign})
                    IssueMove({oCurUnitToAssign}, M27Logic.GetNearestRallyPoint(aiBrain, oCurUnitToAssign:GetPosition()))
                else
                    if bDebugMessages == true then
                        local sPlan = 'nil'
                        if oUnitOrPlatoonToHelp.GetPlan then sPlan = oUnitOrPlatoonToHelp:GetPlan() end
                        LOG(sFunctionRef..': oPlatoonToHelp='..sPlan..(oPlatoonToHelp[M27PlatoonUtilities.refiPlatoonCount] or '0')..'; checking if already have a platoon that should add to')
                    end
                    --Does the platoon already have a shield helper assigned?
                    if oUnitOrPlatoonToHelp[M27PlatoonUtilities.refoSupportingShieldPlatoon] and aiBrain:PlatoonExists(oUnitOrPlatoonToHelp[M27PlatoonUtilities.refoSupportingShieldPlatoon]) then
                        --Add to existing platoon
                        aiBrain:AssignUnitsToPlatoon(oUnitOrPlatoonToHelp[M27PlatoonUtilities.refoSupportingShieldPlatoon], { oCurUnitToAssign }, 'Attack', 'GrowthFormation')
                        M27PlatoonUtilities.RecordPlatoonUnitsByType(oUnitOrPlatoonToHelp[M27PlatoonUtilities.refoSupportingShieldPlatoon], false)

                        if bDebugMessages == true then LOG(sFunctionRef..': Added shield unit to existing platoon='..oUnitOrPlatoonToHelp[M27PlatoonUtilities.refoSupportingShieldPlatoon]:GetPlan()..oUnitOrPlatoonToHelp[M27PlatoonUtilities.refoSupportingShieldPlatoon][M27PlatoonUtilities.refiPlatoonCount]) end
                    else
                        --Create new platoon
                        oShieldPlatoon = CreatePlatoon(aiBrain, 'M27MobileShield', {oCurUnitToAssign})
                        oUnitOrPlatoonToHelp[M27PlatoonUtilities.refoSupportingShieldPlatoon] = oShieldPlatoon
                        oShieldPlatoon[M27PlatoonUtilities.refoPlatoonOrUnitToEscort] = oUnitOrPlatoonToHelp
                        if bDebugMessages == true then LOG(sFunctionRef..': Just created a new platoon for the mobile shield') end
                    end
                end
            end
            oCurUnitToAssign = nil
        else
            bHaveUnitsToAssign = false
        end
    end
    if aiBrain[refbUsingMobileShieldsForPlatoons] == true and (GetGameTimeSeconds() - aiBrain[refiTimeLastCheckedForIdleShields]) >= 1 then
        CheckForIdleMobileLandUnits(aiBrain)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end


function AllocateNewUnitToPlatoonBase(tNewUnits, bNotJustBuiltByFactory)
    --DONT CALL DIRECTLY

    --Called when a factory finishes constructing a unit, or a platoon is disbanded with combat units in it
    --if called from a factory, tNewUnits should be a single unit in a table
    --if bNoDelay is true then wont do normal waiting for the unit to move away from the factory (nb: should only set this to true if we're not talking about a newly produced unit from a factory as it will bypass the workaround for factory error where factories stop building)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AllocateNewUnitToPlatoonBase'
    --DONT USE PROFILER HERE as need solution to the waitticks
    if bDebugMessages == true then LOG(sFunctionRef..': Start') end

    local iLifetimeCount
    local iUnits = 0
    if M27Utilities.IsTableEmpty(tNewUnits) == true then
        M27Utilities.ErrorHandler('tNewUnits is empty')
    elseif not(type(tNewUnits) == "table") then M27Utilities.ErrorHandler('tNewUnits isnt a table')
    else
        iUnits = table.getn(tNewUnits)
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code, iUnits='..iUnits..'; bNotJustBuiltByFactory='..tostring(bNotJustBuiltByFactory or false)) end
    end
    if not(bNotJustBuiltByFactory) and iUnits > 1 then
        M27Utilities.ErrorHandler('More than 1 units has been passed to this function but should only do this if not built by a factory recently; will only consider the first unit')
    end
    local oNewUnit
    local bValidUnit = false
    local iCount = 0
    while bValidUnit == false do
        iCount = iCount + 1 if iCount > 200 then M27Utilities.ErrorHandler('Infinite loop') break end
        for iUnit, oUnit in tNewUnits do
            if not(oUnit.Dead) then
                oNewUnit = oUnit
                bValidUnit = true
                break
            end
        end
        break
    end
    if bValidUnit == false then LOG('Warning - no valid units in tNewUnits')
    else

        if bDebugMessages == true then LOG(sFunctionRef..': About to consider if unit is still in factory area before we try to allocate it to a platoon') end
        local sUnitID = oNewUnit:GetUnitId()
        local aiBrain = oNewUnit:GetAIBrain()
        local tStartPosition
        local bProceed = false
        local bReissueExistingMoveToPlatoon = true
        oNewUnit[refbProcessedForPlatoon] = true
        if bNotJustBuiltByFactory == true then
            if bDebugMessages == true then LOG(sFunctionRef..': arent considering delay command from being built by factory') end
            bProceed = true
        else
            --Add in cumulative unit count tracking here:
            iLifetimeCount = M27UnitInfo.GetUnitLifetimeCount(oNewUnit)
            oNewUnit[refbJustBuilt] = true



            --Wait for the unit to leave the factory area before try to assign it to a platoon:
            local iCurCycleCount = 0
            local iMaxCycleCount = 100 --max wait is 10 seconds before we give up and try and assign a platoon anyway
            local tOrigPosition = oNewUnit:GetPosition()
            tStartPosition = {tOrigPosition[1], tOrigPosition[2], tOrigPosition[3]}

            local tCurPosition
            local iCurDistanceFromStartPosition
            local iMinDistanceNeeded = 2.9 --i.e. land fac is 4x4, so 2x2 from middle, so if do (2^2 + 2^2)^0.5 get just under 2.83, so if distance is >=2.83 the unit is away from the factory; have used distance of 3 to be safe incase unit size affects things
            local iBuildingHalfSize = 2
            local iDistToLookAtRect = iBuildingHalfSize
            local rRect = Rect(tStartPosition[1] - iBuildingHalfSize, tStartPosition[3] - iBuildingHalfSize, tStartPosition[1] + iBuildingHalfSize, tStartPosition[3] + iBuildingHalfSize)
            local tUnitsInRect
            if bDebugMessages == true then LOG(sFunctionRef..': About to loop until the new unit is far enough away from where it started. bProceed='..tostring(bProceed)..'; iCurCycleCount='..iCurCycleCount) end
            while bProceed == false do
                if not(oNewUnit.GetUnitId) then
                    if bDebugMessages == true then LOG(sFunctionRef..': oNewUnit doesnt have GetUnitId so not a valid unit') end
                    break
                else
                    iCurCycleCount = iCurCycleCount + 1
                    if iCurCycleCount > iMaxCycleCount then
                        local sUniqueCount = M27UnitInfo.GetUnitLifetimeCount(oNewUnit)
                        if sUniqueCount == nil then sUniqueCount = 'nil' end
                        if oNewUnit.GetUnitId then LOG('UnitId='..oNewUnit:GetUnitId()..'; UniqueCount='..sUniqueCount) end
                        M27Utilities.ErrorHandler('Waited 10 seconds for unit to leave land factory area and it still hasnt, will proceed with trying to form a platoon with it anyway', nil, true) break
                    end
                    if oNewUnit and not(oNewUnit.Dead) then
                        WaitTicks(1)
                        if M27UnitInfo.IsUnitValid(oNewUnit[M27UnitInfo.refoFactoryThatBuildThis]) and M27Logic.IsUnitIdle(oNewUnit[M27UnitInfo.refoFactoryThatBuildThis]) == false then
                            bProceed = true
                            break
                        else
                            tCurPosition = oNewUnit:GetPosition()
                            iCurDistanceFromStartPosition = M27Utilities.GetDistanceBetweenPositions(tCurPosition, tStartPosition)
                            if bDebugMessages == true then LOG(sFunctionRef..': '..' iCurCycleCount='..iCurCycleCount..'; iCurDistanceFromStartPosition='..iCurDistanceFromStartPosition) end
                            if iCurDistanceFromStartPosition >= iMinDistanceNeeded then
                                if bDebugMessages == true then LOG(sFunctionRef..': Unit is far enough away that wont be part of land factory') end
                                bProceed = true
                            elseif iCurDistanceFromStartPosition > iDistToLookAtRect then
                                --See if the unit is one of those in a rect of the land factory
                                if bDebugMessages == true then
                                    LOG(sFunctionRef..': Checking all units in a rect of the land factory='..repr(rRect))
                                    --M27Utilities.DrawRectangle(rRect, 2, 10)
                                end
                                tUnitsInRect = GetUnitsInRect(rRect)
                                if M27Utilities.IsTableEmpty(tUnitsInRect) == true then
                                    bProceed = true
                                else
                                    bProceed = true
                                    for iUnit, oUnit in tUnitsInRect do
                                        if oUnit == oNewUnit then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Unit is in a rect of land factory still') end
                                            bProceed = false
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': NewUnit is nil or dead') end
                        break
                    end
                end
            end
            if bProceed == true then
                --Check the unit doesnt already have an order to move away from the factory
                if bDebugMessages == true then LOG(sFunctionRef..': NewUnit='..sUnitID..': Checking if unit is already moving far away from factory') end
                if oNewUnit.GetCommandQueue then
                    local tCommandQueue = oNewUnit:GetCommandQueue() --NOTE: For some reason this sometimes causes an error message despite having the check in the previous line that the unit has such a function; not sure what can do to fix this but it happens rarely enough that hopefully can just ignore the error
                    if M27Utilities.IsTableEmpty(tCommandQueue) == false then
                        if oNewUnit.GetNavigator then
                            local oNavigator = oNewUnit:GetNavigator()
                            if oNavigator.GetCurrentTargetPos then
                                local tCurTarget = oNavigator:GetCurrentTargetPos()
                                if bDebugMessages == true then LOG(sFunctionRef..': tCurTarget='..repr(tCurTarget)..'; Unitposition='..repr(tOrigPosition)) end

                                if math.abs(tOrigPosition[1] - tCurTarget[1]) > 10 or math.abs(tOrigPosition[3] - tCurTarget[3]) > 10 then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Unit is already moving far away from the factory so dont try to reissue it any commands') end
                                    bReissueExistingMoveToPlatoon = false
                                else
                                    if oNavigator.GetGoalPos then
                                        local tGoalTarget = oNavigator:GetGoalPos()
                                        if bDebugMessages == true then LOG(sFunctionRef..': tGoalTarget='..repr(tGoalTarget)..'; Unitposition='..repr(tOrigPosition)) end
                                        if math.abs(tOrigPosition[1] - tGoalTarget[1]) > 10 or math.abs(tOrigPosition[3] - tGoalTarget[3]) > 10 then
                                            bReissueExistingMoveToPlatoon = false
                                        end
                                    end
                                end
                            end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': NewUnit='..sUnitID..': Command queue is empty') end
                    end
                end
            end
        end

        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


        if bProceed == true then
            if bDebugMessages == true then LOG(sFunctionRef..': We can proceed, clearing unit commands unless we have an air or acu unit') end
            if (M27Logic.iTimeOfLastBrainAllDefeated or 0) < 10 then
                local bIssueTemporaryMoveOrder = true
                local bReissueMovementPath = true
                --Clear unit commands
                if bDebugMessages == true then
                    local iLifetimeCount = M27UnitInfo.GetUnitLifetimeCount(oNewUnit)
                    if iLifetimeCount == nil then iLifetimeCount = 0 end
                    LOG(sFunctionRef..': About to clear commands to unit with lifetime count='..iLifetimeCount..' and ID='..sUnitID)
                end
                local tUnitsToClear = EntityCategoryFilterDown(categories.ALLUNITS - categories.AIR - categories.COMMAND, tNewUnits)
                --Is the factory unit state building or upgrading? If so then dont need to worry about clearing
                local bFactoryNotBuilding = false
                if M27Utilities.IsTableEmpty(tUnitsToClear) == false then
                    for iUnit, oUnit in tUnitsToClear do
                        if M27UnitInfo.IsUnitValid(oUnit[M27UnitInfo.refoFactoryThatBuildThis]) and M27Logic.IsUnitIdle(oUnit[M27UnitInfo.refoFactoryThatBuildThis]) then
                            bFactoryNotBuilding = true
                            break
                        end
                    end
                end

                if bFactoryNotBuilding then
                    IssueClearCommands(tUnitsToClear)
                else
                    bIssueTemporaryMoveOrder = false
                    bReissueMovementPath = false
                end

                local bAbortPlatoonFormation = false

                if oNewUnit.PlatoonHandle and not(bNotJustBuiltByFactory) then
                    local sPlatoonName = 'Nil or pool'
                    if oNewUnit.PlatoonHandle.GetPlan then sPlatoonName = oNewUnit.PlatoonHandle:GetPlan() if sPlatoonName == nil then sPlatoonName = 'PlanWithNilName' end end

                    if iLifetimeCount == nil then iLifetimeCount = M27UnitInfo.GetUnitLifetimeCount(oNewUnit) end

                    --Sometimes (not often) can have this happen e.g. if unit was assigned to defenders then removed as a spare unit so it went to army pool
                    if bDebugMessages == true then LOG('oNewUnit was just built by a factory but has a platoon handle already with name='..sPlatoonName..'; unit name='..sUnitID..iLifetimeCount..'; oNewUnit[refbJustCleared]='..tostring(oNewUnit[refbJustCleared])..'; oNewUnit[refbJustBuilt] ='..tostring(oNewUnit[refbJustBuilt])) end
                    if oNewUnit[refbJustBuilt] == false and not(oNewUnit.PlatoonHandle[M27PlatoonTemplates.refbIdlePlatoon] == nil) and oNewUnit.PlatoonHandle[M27PlatoonTemplates.refbIdlePlatoon] == false then
                        bAbortPlatoonFormation = true
                        if M27Utilities.IsTableEmpty(oNewUnit.PlatoonHandle[M27PlatoonUtilities.reftMovementPath]) == false then
                            bIssueTemporaryMoveOrder = false
                        end
                    end
                end

                if bIssueTemporaryMoveOrder == true then
                    --Give the new unit a move command to try and make sure its away from the factory
                    --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
                    if tStartPosition then
                        local tRallyPoint = M27Logic.GetNearestRallyPoint(aiBrain, M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
                        --local tRallyPoint = M27Utilities.MoveTowardsTarget(tStartPosition, M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)], 10, 0)
                        if EntityCategoryContains(refCategoryLandCombat, sUnitID) then
                            IssueAggressiveMove(tNewUnits, tRallyPoint)
                        elseif not(EntityCategoryContains(M27UnitInfo.refCategoryEngineer, sUnitID)) then IssueMove(tNewUnits, tRallyPoint) end
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Issuing move to rally point')
                            --M27Utilities.DrawLocation(tRallyPoint)
                        end

                    end
                else
                    --Reissue platoon movement path if there is one
                    if bReissueMovementPath == true and oNewUnit.PlatoonHandle and M27Utilities.IsTableEmpty(oNewUnit.PlatoonHandle[M27PlatoonUtilities.reftMovementPath]) == false then
                        local tPlatoonUnits = oNewUnit.PlatoonHandle:GetPlatoonUnits()
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': About to reissue movement path')
                            LOG('Platoon name='..oNewUnit.PlatoonHandle:GetPlan())
                            LOG('UnitId='..oNewUnit:GetUnitId())
                            LOG('movement path='..repr(oNewUnit.PlatoonHandle[M27PlatoonUtilities.reftMovementPath]))
                        end
                        for iMovementPath, tMovementTarget in oNewUnit.PlatoonHandle[M27PlatoonUtilities.reftMovementPath] do
                            IssueMove(tPlatoonUnits, tMovementTarget)
                        end
                    end
                end

                if bAbortPlatoonFormation == false then
                    oNewUnit[refbJustCleared] = true
                    oNewUnit[refbJustBuilt] = false
                    --Is it a combat unit?
                    local sUnitBP
                    --local refCategoryDFTank = M27UnitInfo.refCategoryDFTank
                    --local refCategoryAttackBot = M27UnitInfo.refCategoryDFTank
                    --local refCategoryIndirect = M27UnitInfo.refCategoryIndirect
                    local tMobileShieldUnits = EntityCategoryFilterDown(M27UnitInfo.refCategoryMobileLandShield, tNewUnits)
                    local tCombatUnits = EntityCategoryFilterDown(M27UnitInfo.refCategoryLandCombat - M27UnitInfo.refCategoryMobileLandShield, tNewUnits)
                    local tEngineerUnits = EntityCategoryFilterDown(refCategoryEngineer - M27UnitInfo.refCategoryLandCombat - M27UnitInfo.refCategoryMobileLandShield, tNewUnits)
                    local tAirUnits = EntityCategoryFilterDown(categories.AIR - refCategoryEngineer, tNewUnits)
                    local tNavalUnits = EntityCategoryFilterDown(categories.NAVAL - categories.AIR - refCategoryEngineer - M27UnitInfo.refCategoryLandCombat, tNewUnits)
                    local tIndirectT2Plus = EntityCategoryFilterDown(M27UnitInfo.refCategoryIndirectT2Plus - categories.NAVAL - categories.AIR - refCategoryEngineer - M27UnitInfo.refCategoryLandCombat - M27UnitInfo.refCategoryMobileLandShield, tNewUnits)
                    local tMAA = EntityCategoryFilterDown(M27UnitInfo.refCategoryMAA  - M27UnitInfo.refCategoryIndirectT2Plus - categories.NAVAL - categories.AIR - refCategoryEngineer - M27UnitInfo.refCategoryLandCombat - M27UnitInfo.refCategoryMobileLandShield, tNewUnits)

                    local tNeedingAssigningCombatUnits = {}
                    local iValidCombatUnitCount = 0


                    if M27Utilities.IsTableEmpty(tEngineerUnits) == false then
                        --Is this an engineer that has been assigned to build a T3 mex on a delay? If so then reissue its command instead of reassigning it

                        if table.getn(tEngineerUnits) == 1 and M27UnitInfo.IsUnitValid(tEngineerUnits[1]) and tEngineerUnits[1][M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionBuildT3MexOverT2 and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerActionsByEngineerRef][M27EngineerOverseer.GetEngineerUniqueCount(tEngineerUnits[1])]) == false and aiBrain[M27EngineerOverseer.reftEngineerActionsByEngineerRef][M27EngineerOverseer.GetEngineerUniqueCount(tEngineerUnits[1])][1][M27EngineerOverseer.refbPrimaryBuilder] == true then
                            if bDebugMessages == true then LOG(sFunctionRef..': Have just cleared actions and were going to call reassignengineers for engineer '..M27EngineerOverseer.GetEngineerUniqueCount(tEngineerUnits[1])..'; however its action is to build a T3 mex over T2, given the time delay on this will tell it to move to its old target and also to build a mex there so should work either way. reftActualTargetLocationRef='..repr(aiBrain[M27EngineerOverseer.reftEngineerActionsByEngineerRef][M27EngineerOverseer.GetEngineerUniqueCount(tEngineerUnits[1])][1][M27EngineerOverseer.reftActualTargetLocationRef])) end
                            IssueMove({tEngineerUnits[1]}, aiBrain[M27EngineerOverseer.reftEngineerActionsByEngineerRef][M27EngineerOverseer.GetEngineerUniqueCount(tEngineerUnits[1])][1][M27EngineerOverseer.reftActualTargetLocationRef])
                            M27EngineerOverseer.BuildStructureAtLocation(aiBrain, tEngineerUnits[1], M27UnitInfo.refCategoryT3Mex, 1, nil, aiBrain[M27EngineerOverseer.reftEngineerActionsByEngineerRef][M27EngineerOverseer.GetEngineerUniqueCount(tEngineerUnits[1])][1][M27EngineerOverseer.reftActualTargetLocationRef], true, false)
                        else
                            M27EngineerOverseer.ReassignEngineers(aiBrain, false, tEngineerUnits)
                        end
                    end
                    if M27Utilities.IsTableEmpty(tCombatUnits) == false then
                        for iUnit, oUnit in tCombatUnits do
                            if not(oUnit[refbWaitingForAssignment]) then
                                iValidCombatUnitCount = iValidCombatUnitCount + 1
                               tNeedingAssigningCombatUnits[iValidCombatUnitCount] = oUnit
                            end
                        end
                        local iCombatUnits = iValidCombatUnitCount
                        if bDebugMessages == true then LOG(sFunctionRef..': Dealing with combat units, iCombatUnits='..iCombatUnits) end
                        if aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] == nil then aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] = {} end
                        if aiBrain[reftoCombatUnitsWaitingForAssignment] == nil then aiBrain[reftoCombatUnitsWaitingForAssignment] = {} end
                        if M27Utilities.IsTableEmpty(aiBrain[reftoCombatUnitsWaitingForAssignment]) == true then
                            if bDebugMessages == true then LOG(sFunctionRef..': No existing units waiting for assignment, will set current units as waiting') end
                            aiBrain[reftoCombatUnitsWaitingForAssignment] = tNeedingAssigningCombatUnits
                        else
                            local iUnitsWaiting = table.getn(aiBrain[reftoCombatUnitsWaitingForAssignment])
                            if bDebugMessages == true then LOG(sFunctionRef..': iUnitsWaiting='..iUnitsWaiting..'; iCombatUnits='..iCombatUnits) end
                            local iCount
                            local tTableToAddToOther
                            local tTableToBeAddedTo
                            local bReplaceCombatUnitsWaiting = false
                            if iCombatUnits > iUnitsWaiting then
                                iCount = iCombatUnits
                                tTableToAddToOther = aiBrain[reftoCombatUnitsWaitingForAssignment]
                                tTableToBeAddedTo = tNeedingAssigningCombatUnits
                                bReplaceCombatUnitsWaiting = true
                            else
                                iCount = iUnitsWaiting
                                tTableToAddToOther = tNeedingAssigningCombatUnits
                                tTableToBeAddedTo = aiBrain[reftoCombatUnitsWaitingForAssignment]
                            end
                            for iUnit, oUnit in tTableToAddToOther do
                                iCount = iCount + 1
                                tTableToBeAddedTo[iCount] = oUnit
                            end
                            if bReplaceCombatUnitsWaiting == true then aiBrain[reftoCombatUnitsWaitingForAssignment] = tTableToBeAddedTo end
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': About to list out every unit in aiBrain[reftoCombatUnitsWaitingForAssignment] before we call the combat platoon former')
                            if M27Utilities.IsTableEmpty(aiBrain[reftoCombatUnitsWaitingForAssignment]) == true then LOG('Table is empty')
                            else
                                for iUnit, oUnit in aiBrain[reftoCombatUnitsWaitingForAssignment] do
                                    local iUniqueID = M27UnitInfo.GetUnitLifetimeCount(oNewUnit)
                                    LOG('iUnit='..iUnit..'; Blueprint+UniqueCount='..oUnit:GetUnitId()..iUniqueID)
                                end
                            end
                        end
                        CombatPlatoonFormer(aiBrain)
                    end
                    if M27Utilities.IsTableEmpty(tMobileShieldUnits) == false then
                        MobileShieldPlatoonFormer(aiBrain, tMobileShieldUnits)
                    end
                    if M27Utilities.IsTableEmpty(tIndirectT2Plus) == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have indirect T2+ units, will assign to idle platoon for now, number of units='..table.getn(tIndirectT2Plus)) end
                        AllocateUnitsToIdlePlatoons(aiBrain, tIndirectT2Plus)
                    end
                    if M27Utilities.IsTableEmpty(tMAA) == false then
                        MAAPlatoonFormer(aiBrain, tMAA)
                    end
                    if M27Utilities.IsTableEmpty(tAirUnits) == false then
                       AllocateUnitsToIdlePlatoons(aiBrain, tAirUnits)
                    end
                    if M27Utilities.IsTableEmpty(tNavalUnits) == false then
                        AllocateUnitsToIdlePlatoons(aiBrain, tNavalUnits)
                    end

                    M27Utilities.DelayChangeVariable(oNewUnit, refbJustCleared, false, 1, nil, nil)
                end
            end
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
end

function AllocateNewUnitsToPlatoonNotFromFactory(tNewUnits)
    ForkThread(AllocateNewUnitToPlatoonBase, tNewUnits, true)
end


function AllocateNewUnitToPlatoonFromFactory(oNewUnit, oFactory)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if bDebugMessages == true then LOG('AllocateNewUnitToPlatoonFromFactory About to fork thread') end
    if not(oNewUnit.Dead) and not(oNewUnit.GetUnitId) then M27Utilities.ErrorHandler('oNewUnit doesnt have a unit ID so likely isnt a unit') end
    oNewUnit[M27UnitInfo.refoFactoryThatBuildThis] = oFactory
    ForkThread(AllocateNewUnitToPlatoonBase, {oNewUnit}, false)
end

function AssignIdlePlatoonUnitsToPlatoons(aiBrain)
    local sFunctionRef = 'AssignIdlePlatoonUnitsToPlatoons'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tIdleCombat = aiBrain[M27PlatoonTemplates.refoIdleCombat]:GetPlatoonUnits()
    if M27Utilities.IsTableEmpty(tIdleCombat) == false then
        AllocateNewUnitsToPlatoonNotFromFactory(tIdleCombat)
    end
    local oArmyPool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local tIdleArmyPool = oArmyPool:GetPlatoonUnits()
    if M27Utilities.IsTableEmpty(tIdleArmyPool) == false then
        AllocateUnitsToIdlePlatoons(aiBrain, tIdleArmyPool)
    end
    local tUnderConstruction = aiBrain[M27PlatoonTemplates.refoUnderConstruction]:GetPlatoonUnits()
    local tFinishedConstruction = {}
    if M27Utilities.IsTableEmpty(tUnderConstruction) == false then
        for iUnit, oUnit in tUnderConstruction do
            if not(oUnit.Dead) then
                if oUnit.GetFractionComplete and oUnit:GetFractionComplete() == 1 then
                    table.insert(tFinishedConstruction, oUnit)
                end
            end
        end
        if M27Utilities.IsTableEmpty(tFinishedConstruction) == false then AllocateUnitsToIdlePlatoons(aiBrain, tFinishedConstruction) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function CheckForIdleMobileLandUnits(aiBrain)
    --Assigns any units without a platoon to the relevant platoon handle
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CheckForIdleMobileLandUnits'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tAllUnits = aiBrain:GetListOfUnits(categories.MOBILE * categories.LAND, false, true)
    local oPlatoon
    local oArmyPool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    --Update flag for mobile shields if we have none idle (as suggests we're using them all)
    local bHaveIdleMobileShield = false
    aiBrain[refiTimeLastCheckedForIdleShields] = GetGameTimeSeconds()


    for iUnit, oUnit in tAllUnits do
        oPlatoon = oUnit.PlatoonHandle
        if not(oUnit.Dead) and oUnit:GetFractionComplete() == 1 and (not(oPlatoon) or oPlatoon == oArmyPool or oPlatoon:GetPlan() == M27PlatoonTemplates.refoUnderConstruction) then
            if bDebugMessages == true then
                LOG(sFunctionRef..': Assigning unit to relevant idle platoon as it either has no platoon or is in army pool')
            end
            if EntityCategoryContains(M27UnitInfo.refCategoryMobileLandShield, oUnit:GetUnitId()) then bHaveIdleMobileShield = true end
            AllocateUnitsToIdlePlatoons(aiBrain, {oUnit})
        end
    end
    aiBrain[refbUsingMobileShieldsForPlatoons] = not(bHaveIdleMobileShield)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function SetupIdlePlatoon(aiBrain, sPlan)
    local oNewPlatoon = aiBrain:MakePlatoon('', '')
    oNewPlatoon:UniquelyNamePlatoon(sPlan)
    oNewPlatoon:SetAIPlan(sPlan)
    aiBrain[sPlan] = oNewPlatoon
    oNewPlatoon:TurnOffPoolAI()
end

function UpdateIdlePlatoonActions(aiBrain, iCycleCount)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateIdlePlatoonActions'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Indirect fire platoon - assign to temporary attack platoon every other cycle
    if (math.mod(iCycleCount, 2) == 0) then
        --Even cycle count so refresh
        if bDebugMessages == true then LOG(sFunctionRef..': Checking if any T2+ indirect units in idle platoon, in which case will assign them to attacknearest temporary platoon') end
        local tIdleIndirectUnits = aiBrain[M27PlatoonTemplates.refoIdleIndirect]:GetPlatoonUnits()
        if M27Utilities.IsTableEmpty(tIdleIndirectUnits) == false then
            local tIdleIndirectT2Plus = EntityCategoryFilterDown(M27UnitInfo.refCategoryIndirectT2Plus, tIdleIndirectUnits)
            if M27Utilities.IsTableEmpty(tIdleIndirectT2Plus) == false then
                if bDebugMessages == true then LOG(sFunctionRef..': Allocating idle indirect units to indirectspareattacker platoon') end
                CreatePlatoon(aiBrain, 'M27IndirectSpareAttacker', tIdleIndirectT2Plus)
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function PlatoonMainIdleUnitLoop(aiBrain, iCycleCount)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'PlatoonMainIdleUnitLoop'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iIdleUnitSearchThreshold = 10 --Change both here and in earlier code

    if bDebugMessages == true then
        LOG(sFunctionRef..': About to detail unit count of some of the platoons')
        local tIdleScouts, tIdleMAA, tEngineers, tUnderConstruction, tAllStructures
        tIdleScouts = aiBrain[M27PlatoonTemplates.refoIdleScouts]:GetPlatoonUnits()
        tIdleMAA = aiBrain[M27PlatoonTemplates.refoIdleMAA]:GetPlatoonUnits()
        tEngineers = aiBrain[M27PlatoonTemplates.refoAllEngineers]:GetPlatoonUnits()
        tUnderConstruction = aiBrain[M27PlatoonTemplates.refoUnderConstruction]:GetPlatoonUnits()
        tAllStructures = aiBrain[M27PlatoonTemplates.refoAllStructures]:GetPlatoonUnits()
        local tAllIdlePlatoonUnits = {tIdleScouts, tIdleMAA, tEngineers, tUnderConstruction, tAllStructures}
        for iSubtable, tSubtable in tAllIdlePlatoonUnits do
            if M27Utilities.IsTableEmpty(tSubtable) == false then
                LOG('iSubtable='..iSubtable..'; unit count='..table.getn(tSubtable))
            end
        end
        LOG('Scout platoon exists status='..tostring(aiBrain:PlatoonExists(aiBrain[M27PlatoonTemplates.refoIdleScouts])))
        LOG('Under construction platoon exists status='..tostring(aiBrain:PlatoonExists(aiBrain[M27PlatoonTemplates.refoUnderConstruction])))
        LOG('Name of MAA platoon='..aiBrain[M27PlatoonTemplates.refoIdleMAA]:GetPlan())
    end

    ForkThread(AssignIdlePlatoonUnitsToPlatoons, aiBrain)
    if iCycleCount == iIdleUnitSearchThreshold then
        ForkThread(CheckForIdleMobileLandUnits, aiBrain)
    end
    ForkThread(UpdateIdlePlatoonActions, aiBrain, iCycleCount)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function PlatoonIdleUnitOverseer(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'PlatoonIdleUnitOverseer'
    local iCycleCount = 0

    --Initial setup - create the idle platoons
    WaitTicks(60)
    SetupIdlePlatoon(aiBrain, M27PlatoonTemplates.refoIdleScouts)
    SetupIdlePlatoon(aiBrain, M27PlatoonTemplates.refoIdleMAA)
    SetupIdlePlatoon(aiBrain, M27PlatoonTemplates.refoAllEngineers)
    SetupIdlePlatoon(aiBrain, M27PlatoonTemplates.refoIdleCombat)
    SetupIdlePlatoon(aiBrain, M27PlatoonTemplates.refoIdleIndirect)
    SetupIdlePlatoon(aiBrain, M27PlatoonTemplates.refoAllStructures)
    SetupIdlePlatoon(aiBrain, M27PlatoonTemplates.refoUnderConstruction)
    SetupIdlePlatoon(aiBrain, M27PlatoonTemplates.refoIdleAir)
    SetupIdlePlatoon(aiBrain, M27PlatoonTemplates.refoIdleOther)

    while(not(aiBrain:IsDefeated())) do
        if aiBrain.M27IsDefeated or M27Logic.iTimeOfLastBrainAllDefeated > 10 then break end
        if bDebugMessages == true then LOG(sFunctionRef..': About to fork thread function to assign idle platoon units to platoons') end
        iCycleCount = iCycleCount + 1
        ForkThread(PlatoonMainIdleUnitLoop, aiBrain, iCycleCount)
        if iCycleCount == iIdleUnitSearchThreshold then iCycleCount = 0 end
        WaitTicks(10)
    end
end
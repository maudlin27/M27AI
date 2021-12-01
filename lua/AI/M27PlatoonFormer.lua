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


function CreatePlatoon(aiBrain, sPlatoonPlan, oPlatoonUnits)
    local oNewPlatoon
    if sPlatoonPlan == nil then
        M27Utilities.ErrorHandler('sPlatoonPlan is nil')
    else
        local tPlatoonTemplate = M27PlatoonTemplates.PlatoonTemplate[sPlatoonPlan]
        if M27Utilities.IsTableEmpty(tPlatoonTemplate) == true then
            M27Utilities.ErrorHandler('Dont have a platoon template for sPlatoonPlan='..sPlatoonPlan)
        else
            oNewPlatoon = aiBrain:MakePlatoon('', '')
            local sFormation = M27PlatoonTemplates.PlatoonTemplate[sPlatoonPlan][M27PlatoonTemplates.refsDefaultFormation]
            aiBrain:AssignUnitsToPlatoon(oNewPlatoon, oPlatoonUnits, 'Attack', sFormation)
            oNewPlatoon:SetAIPlan(sPlatoonPlan)
        end
    end
    return oNewPlatoon
end

function RefreshUnitsWaitingForAssignment(aiBrain)
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
end

function PlatoonOrUnitNeedingEscortIsStillValid(aiBrain, oPlatoonOrUnit)
    local bDebugMessages = false
    local sFunctionRef = 'PlatoonOrUnitNeedingEscortIsStillValid'
    local bStillValid = true
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    if oPlatoonOrUnit == nil or not(oPlatoonOrUnit[M27PlatoonUtilities.refbShouldHaveEscort]) then
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
    return bStillValid
end

function GetPlatoonOrUnitToEscort(aiBrain)
    local bDebugMessages = false
    local sFunctionRef = 'GetPlatoonOrUnitToEscort'
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
    return oPlatoonOrUnitToEscort
end


function CombatPlatoonFormer(aiBrain)
    local bDebugMessages = false
    local sFunctionRef = 'CombatPlatoonFormer'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, about to refresh units waiting for assignment') end
    RefreshUnitsWaitingForAssignment(aiBrain)
    local iUnitsWaiting = 0
    local tUnitsWaiting = aiBrain[reftoCombatUnitsWaitingForAssignment]
    if M27Utilities.IsTableEmpty(tUnitsWaiting) == false then
        --Check if ACU is one of the units
        local iCurCount = 0
        local iMaxLoop = 2
        local tACU = EntityCategoryFilterDown(categories.COMMAND, tUnitsWaiting)

        while M27Utilities.IsTableEmpty(tACU) == false do
            iCurCount = iCurCount + 1
            if iCurCount > iMaxLoop then M27Utilities.ErrorHandler('Likely infinite loop') break end
            for iUnit, oUnit in tUnitsWaiting do
                if EntityCategoryContains(categories.COMMAND, oUnit:GetUnitId()) then
                    table.remove(aiBrain[reftoCombatUnitsWaitingForAssignment], iUnit)
                    tUnitsWaiting = aiBrain[reftoCombatUnitsWaitingForAssignment]
                    tACU = EntityCategoryFilterDown(categories.COMMAND, tUnitsWaiting)
                    break
                end
            end

        end

        iUnitsWaiting = table.getn(tUnitsWaiting)
        local tDFUnitsWaiting, tIndirectT1UnitsWaiting, tIndirectT2PlusUnitsWaiting, iDFUnitsWaiting, iIndirectT1UnitsWaiting, iIndirectT2PlusUnitsWaiting

        if M27Utilities.IsTableEmpty(tUnitsWaiting) == false then
            if bDebugMessages == true then
                LOG(sFunctionRef..': iUnitsWaiting='..iUnitsWaiting..'; About to list out every unit in aiBrain[reftoCombatUnitsWaitingForAssignment]')
                if M27Utilities.IsTableEmpty(aiBrain[reftoCombatUnitsWaitingForAssignment]) == true then LOG('Table is empty')
                else
                    for iUnit, oUnit in aiBrain[reftoCombatUnitsWaitingForAssignment] do
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
                if iStrategy == M27Overseer.refStrategyLandEarly then
                    aiBrain[refbUsingTanksForPlatoons] = true
                    if iCurrentConditionToTry == 1 then --Initial land raiders
                        if aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount]['M27MexRaiderAI'] < aiBrain[M27Overseer.refiInitialRaiderPlatoonsWanted] then
                            sPlatoonToForm = 'M27MexRaiderAI' end
                    elseif iCurrentConditionToTry == 2 then --Emergency defence
                        --iDefenceCoverage = aiBrain[M27Overseer.refiNearestOutstandingThreat]
                        if iDefenceCoverage < 0.3 then sPlatoonToForm = 'M27DefenderAI' end
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
                        if iDefenceCoverage < 0.4 then sPlatoonToForm = 'M27DefenderAI' end
                    elseif iCurrentConditionToTry == 6 then
                        if iRaiders < 2 then sPlatoonToForm = 'M27MexLargerRaiderAI' end

                    elseif iCurrentConditionToTry == 7 then
                        if iRaiders < 3 then sPlatoonToForm = 'M27MexLargerRaiderAI' end
                    elseif iCurrentConditionToTry == 8 then
                        if iDefenceCoverage < aiBrain[M27Overseer.refiMaxDefenceCoverageWanted] then sPlatoonToForm = 'M27DefenderAI' end
                    elseif iCurrentConditionToTry == 9 then
                        if M27PlatoonUtilities.GetActivePlatoonCount(aiBrain, 'M27LargeAttackForce') < 1 then
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
                elseif iStrategy == M27Overseer.refStrategyEcoAndTech then
                    --Defend with coverage up to 70%, and have 1 active raider
                    if bDebugMessages == true then LOG(sFunctionRef..': Start of loop for eco strategy, iCurrentConditionToTry='..iCurrentConditionToTry) end
                    aiBrain[refbUsingTanksForPlatoons] = true
                    if iCurrentConditionToTry == 1 then --Emergency defence
                        --iDefenceCoverage = aiBrain[M27Overseer.refiNearestOutstandingThreat]
                        if iDefenceCoverage < 0.3 then sPlatoonToForm = 'M27DefenderAI' end
                    elseif iCurrentConditionToTry == 2 then
                        --Platoon escorts
                        if bDebugMessages == true then LOG(sFunctionRef..': Checking if need escorts, IsTableEmpty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts]))) end
                        if M27Utilities.IsTableEmpty(aiBrain[M27PlatoonUtilities.reftPlatoonsOrUnitsNeedingEscorts]) == false then
                            oPlatoonOrUnitToEscort = GetPlatoonOrUnitToEscort(aiBrain)
                            if oPlatoonOrUnitToEscort then sPlatoonToForm = 'M27EscortAI' end
                        end
                    elseif iCurrentConditionToTry == 3 then
                        aiBrain[M27PlatoonUtilities.refbNeedEscortUnits] = false --Have just gone through the escort conditions - if not allocated to it, then suggests we dont need any more units
                        if iDefenceCoverage < 0.5 then sPlatoonToForm = 'M27DefenderAI' end
                    elseif iCurrentConditionToTry == 4 then --1 active raider
                        iRaiders = M27PlatoonUtilities.GetActivePlatoonCount(aiBrain, 'M27MexLargerRaiderAI')
                        if bDebugMessages == true then LOG(sFunctionRef..': iRaiders='..iRaiders) end
                        if iRaiders < 1 then sPlatoonToForm = 'M27MexLargerRaiderAI' end
                    elseif iCurrentConditionToTry == 5 then
                        if iDefenceCoverage < aiBrain[M27Overseer.refiMaxDefenceCoverageWanted] then sPlatoonToForm = 'M27DefenderAI' end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Dont meet any other conditions so will form attackenarestunit platoon') end
                        sPlatoonToForm = 'M27CombatPatrolAI'
                        aiBrain[refbUsingTanksForPlatoons] = false
                        break
                    end
                else
                    M27Utilities.ErrorHandler('Dont have a recognised strategy')
                end
                iCurrentConditionToTry = iCurrentConditionToTry + 1
            end

            if sPlatoonToForm == nil then
                M27Utilities.ErrorHandler('Werent able to figure out a platoon for a combat unit to go into')
            else
                --Do we have enough units for this platoon?
                local iMinSize = M27PlatoonTemplates.PlatoonTemplate[sPlatoonToForm][M27PlatoonTemplates.refiMinimumPlatoonSize]
                if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..'; sPlatoonWanted='..sPlatoonToForm..'; iMinSize='..iMinSize..'; iUnitsWaiting='..iUnitsWaiting) end
                if iUnitsWaiting >= iMinSize then
                    --Are we an escort platoon?
                    local tTemporaryUnitsWaitingForAssignment = {}
                    local iTemporaryUnitsWaitingForAssignment = 0
                    if oPlatoonOrUnitToEscort then
                        --Determine if we want all of the units that are waiting for assignment
                        --GetCombatThreatRating(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, iMassValueOfBlipsOverride, iSoloBlipMassOverride)
                        local iThreatOfUnitsWaitingForAssignment = M27Logic.GetCombatThreatRating(aiBrain, aiBrain[reftoCombatUnitsWaitingForAssignment], false, nil, nil)
                        local iExcessThreat = math.max(0, iThreatOfUnitsWaitingForAssignment + oPlatoonOrUnitToEscort[M27PlatoonUtilities.refiCurrentEscortThreat] - oPlatoonOrUnitToEscort[M27PlatoonUtilities.refiEscortThreatWanted])
                        if iExcessThreat > 120 then
                            --Temporarily move spare units waiting for assignment into a different platoon until we've finished allocating
                            local iCurLoopCount = 0
                            while iExcessThreat > 120 do
                                iCurLoopCount = iCurLoopCount + 1
                                if iCurLoopCount > 100 then M27Utilities.ErrorHandler('Likely infinite loop as have been through 100 units waiting for assignment') break
                                else
                                    --Move the cur unit waiting for assignment into the temporary table
                                    local iUnitsWaitingForAssignment = table.getn(aiBrain[reftoCombatUnitsWaitingForAssignment])
                                    local iLastTableUnitThreat = M27Logic.GetCombatThreatRating(aiBrain, {aiBrain[reftoCombatUnitsWaitingForAssignment][iUnitsWaitingForAssignment]}, false, nil, nil)
                                    if iLastTableUnitThreat > iExcessThreat then
                                        break
                                    else
                                        iTemporaryUnitsWaitingForAssignment = iTemporaryUnitsWaitingForAssignment + 1
                                        tTemporaryUnitsWaitingForAssignment[iTemporaryUnitsWaitingForAssignment] = aiBrain[reftoCombatUnitsWaitingForAssignment][iUnitsWaitingForAssignment]
                                        table.remove(aiBrain[reftoCombatUnitsWaitingForAssignment], iUnitsWaitingForAssignment)
                                        iExcessThreat = iExcessThreat - iLastTableUnitThreat
                                    end
                                end
                            end
                        end
                    end

                    if oPlatoonOrUnitToEscort and oPlatoonOrUnitToEscort[M27PlatoonUtilities.refoEscortingPlatoon] and aiBrain:PlatoonExists(oPlatoonOrUnitToEscort[M27PlatoonUtilities.refoEscortingPlatoon]) then
                        --Add to existing platoon
                        if bDebugMessages == true then LOG(sFunctionRef..': Have a platoon or unit to escort that already has an assigned escort so will assign units to existing escort') end
                        aiBrain:AssignUnitsToPlatoon(oPlatoonOrUnitToEscort[M27PlatoonUtilities.refoEscortingPlatoon], aiBrain[reftoCombatUnitsWaitingForAssignment], 'Attack', 'GrowthFormation')
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Creating new platoon and assigning units to it') end
                        local oNewPlatoon = CreatePlatoon(aiBrain, sPlatoonToForm, aiBrain[reftoCombatUnitsWaitingForAssignment])
                        if oPlatoonOrUnitToEscort then
                            if bDebugMessages == true then LOG(sFunctionRef..': oPlatoonOrUnitToEscort doesnt have an escorting platoon assigned to it') end
                            oNewPlatoon[M27PlatoonUtilities.refoPlatoonOrUnitToEscort] = oPlatoonOrUnitToEscort
                            oPlatoonOrUnitToEscort[M27PlatoonUtilities.refoEscortingPlatoon] = oNewPlatoon
                        end
                    end
                    for iUnit, oUnit in aiBrain[reftoCombatUnitsWaitingForAssignment] do
                        oUnit[refbWaitingForAssignment] = false
                    end
                    aiBrain[reftoCombatUnitsWaitingForAssignment] = {}
                    --Did we have too many units for assignment? If so then move spare ones back to be waiting for assignment
                    if iTemporaryUnitsWaitingForAssignment > 0 then
                        for iUnit, oUnit in tTemporaryUnitsWaitingForAssignment do
                            aiBrain[reftoCombatUnitsWaitingForAssignment][iUnit] = oUnit
                        end
                    end
                else
                    --Get the units that are waiting to move to the intel path location so they're ready/on hand
                    if bDebugMessages == true then LOG(sFunctionRef..': Dont have enough units for min size, iUnitsWaiting='..iUnitsWaiting..'; iMinSize='..iMinSize..' so will send them to intel path temporarily') end
                    if aiBrain[M27Overseer.refbIntelPathsGenerated] == true then
                        local iIntelPathPoint = aiBrain[M27Overseer.refiCurIntelLineTarget]
                        if iIntelPathPoint == nil then iIntelPathPoint = 1
                        else
                            iIntelPathPoint = iIntelPathPoint - 2
                            if iIntelPathPoint <= 0 then iIntelPathPoint = 1 end
                        end

                        local tTargetPosition = aiBrain[M27Overseer.reftIntelLinePositions][iIntelPathPoint][1]
                        --Modify position if its close to a factory
                        local iCurLoop = 0
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

                        local tEnemyBase = M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]
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
                                tTargetPosition = M27Utilities.MoveTowardsTarget(tBasePosition, tEnemyBase, 5 * iCurLoop, 0)
                                iNewPositionSegmentX, iNewPositionSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tTargetPosition)
                                iNewPositionGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iNewPositionSegmentX, iNewPositionSegmentZ)
                            end
                        end
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
        end
    else if bDebugMessages == true then LOG(sFunctionRef..': No units waiting for assigment to a platoon') end
    end
end

function AddIdleUnitsToPlatoon(aiBrain, tUnits, oPlatoonToAddTo)
    local bDebugMessages = false
    local sFunctionRef = 'AddIdleUnitsToPlatoon'
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
end

function AllocateUnitsToIdlePlatoons(aiBrain, tNewUnits)
    --Will allocate units to idle platoon based on their type
    --See platoon templates for platoons that are idle
    --Assumes units all have the same aiBrain

    local bDebugMessages = false
    local sFunctionRef = 'AllocateUnitsToIdlePlatoons'

    if M27Utilities.IsTableEmpty(tNewUnits) == true then M27Utilities.ErrorHandler('tNewUnits is empty')
    else
        local tScouts = {}
        local tMAA = {}
        local tACU = {}
        local tCombat = {}
        local tIndirect = {}
        local tEngi = {}
        local tStructures = {}
        local tAir = {}
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
                        if EntityCategoryContains(refCategoryLandScout, sUnitID) then table.insert(tScouts, oUnit)
                        elseif EntityCategoryContains(refCategoryMAA, sUnitID) then table.insert(tMAA, oUnit)
                        elseif EntityCategoryContains(categories.COMMAND, sUnitID) then table.insert(tACU, oUnit)
                        elseif EntityCategoryContains(refCategoryEngineer, sUnitID) then table.insert(tEngi, oUnit)
                        elseif EntityCategoryContains(categories.STRUCTURE, sUnitID) then table.insert(tStructures, oUnit)
                        elseif EntityCategoryContains(refCategoryLandCombat, sUnitID) then table.insert(tCombat, oUnit)
                        elseif EntityCategoryContains(refCategoryIndirectT2Plus, sUnitID) then table.insert(tIndirect, oUnit)
                        elseif EntityCategoryContains(refCategoryAllAir, sUnitID) then table.insert(tAir, oUnit)
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
            if M27Utilities.IsTableEmpty(tCombat) == false then
                AddIdleUnitsToPlatoon(aiBrain, tCombat, aiBrain[M27PlatoonTemplates.refoIdleCombat])
                AllocatNewUnitsToPlatoonNotFromFactory(tCombat)
            end
            if M27Utilities.IsTableEmpty(tIndirect) == false then AddIdleUnitsToPlatoon(aiBrain, tIndirect, aiBrain[M27PlatoonTemplates.refoIdleIndirect]) end
            if M27Utilities.IsTableEmpty(tStructures) == false then AddIdleUnitsToPlatoon(aiBrain, tStructures, aiBrain[M27PlatoonTemplates.refoAllStructures]) end
            if M27Utilities.IsTableEmpty(tAir) == false then AddIdleUnitsToPlatoon(aiBrain, tAir, aiBrain[M27PlatoonTemplates.refoIdleAir]) end
            if M27Utilities.IsTableEmpty(tOther) == false then AddIdleUnitsToPlatoon(aiBrain, tOther, aiBrain[M27PlatoonTemplates.refoIdleOther]) end
        end
    end
end


function AllocateNewUnitToPlatoonBase(tNewUnits, bNotJustBuiltByFactory)
    --DONT CALL DIRECTLY

    --Called when a factory finishes constructing a unit, or a platoon is disbanded with combat units in it
    --if called from a factory, tNewUnits should be a single unit in a table
    --if bNoDelay is true then wont do normal waiting for the unit to move away from the factory (nb: should only set this to true if we're not talking about a newly produced unit from a factory as it will bypass the workaround for factory error where factories stop building)
    local bDebugMessages = false
    local sFunctionRef = 'AllocateNewUnitToPlatoonBase'
    if bDebugMessages == true then LOG(sFunctionRef..': Start') end

    local iLifetimeCount
    local iUnits = 0
    if M27Utilities.IsTableEmpty(tNewUnits) == true then
        M27Utilities.ErrorHandler('tNewUnits is empty')
    elseif not(type(tNewUnits) == "table") then M27Utilities.ErrorHandler('tNewUnits isnt a table')
    else
        iUnits = table.getn(tNewUnits)
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
                    local tCommandQueue = oNewUnit:GetCommandQueue()
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


        if bProceed == true then
            if bDebugMessages == true then LOG(sFunctionRef..': We can proceed, clearing unit commands unless we have an air or acu unit') end

            local bIssueTemporaryMoveOrder = true
            local bReissueMovementPath = true
            --Clear unit commands
            if bDebugMessages == true then
                local iLifetimeCount = M27UnitInfo.GetUnitLifetimeCount(oNewUnit)
                if iLifetimeCount == nil then iLifetimeCount = 0 end
                LOG(sFunctionRef..': About to clear commands to unit with lifetime count='..iLifetimeCount..' and ID='..sUnitID)
            end
            local tUnitsToClear = EntityCategoryFilterDown(categories.ALLUNITS - categories.AIR - categories.COMMAND, tNewUnits)
            if M27Utilities.IsTableEmpty(tUnitsToClear) == false then
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
                    local tRallyPoint = M27Utilities.MoveTowardsTarget(tStartPosition, M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)], 10, 0)
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
                local tCombatUnits = EntityCategoryFilterDown(M27UnitInfo.refCategoryLandCombat, tNewUnits)
                local tEngineerUnits = EntityCategoryFilterDown(refCategoryEngineer, tNewUnits)
                local tAirUnits = EntityCategoryFilterDown(categories.AIR, tNewUnits)
                local tNavalUnits = EntityCategoryFilterDown(categories.NAVAL, tNewUnits)
                local tIndirectT2Plus = EntityCategoryFilterDown(M27UnitInfo.refCategoryIndirectT2Plus, tNewUnits)
                local tNeedingAssigningCombatUnits = {}
                local iValidCombatUnitCount = 0


                if M27Utilities.IsTableEmpty(tEngineerUnits) == false then M27EngineerOverseer.ReassignEngineers(aiBrain, false, tEngineerUnits) end
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
                        LOG(sFunctionRef..': About to list out every unit in aiBrain[reftoCombatUnitsWaitingForAssignment]')
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
                if M27Utilities.IsTableEmpty(tIndirectT2Plus) == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have indirect T2+ units, will assign to idle platoon for now, number of units='..table.getn(tIndirectT2Plus)) end
                    AllocateUnitsToIdlePlatoons(aiBrain, tIndirectT2Plus)
                end
                if M27Utilities.IsTableEmpty(tAirUnits) == false then
                   AllocateUnitsToIdlePlatoons(aiBrain, tAirUnits)
                end
                if M27Utilities.IsTableEmpty(tNavalUnits) == false then
                    AllocateUnitsToIdlePlatoons(aiBrain, tNavalUnits)
                end

                WaitSeconds(1)
                if oNewUnit then oNewUnit[refbJustCleared] = false end
            end
        end
    end
end

function AllocatNewUnitsToPlatoonNotFromFactory(tNewUnits)
    ForkThread(AllocateNewUnitToPlatoonBase, tNewUnits, true)
end


function AllocateNewUnitToPlatoonFromFactory(oNewUnit)
    local bDebugMessages = false
    if bDebugMessages == true then LOG('AllocateNewUnitToPlatoonFromFactory About to fork thread') end
    if not(oNewUnit.Dead) and not(oNewUnit.GetUnitId) then M27Utilities.ErrorHandler('oNewUnit doesnt have a unit ID so likely isnt a unit') end
    ForkThread(AllocateNewUnitToPlatoonBase, {oNewUnit}, false)
end

function AssignIdlePlatoonUnitsToPlatoons(aiBrain)
    local tIdleCombat = aiBrain[M27PlatoonTemplates.refoIdleCombat]:GetPlatoonUnits()
    if M27Utilities.IsTableEmpty(tIdleCombat) == false then
        AllocatNewUnitsToPlatoonNotFromFactory(tIdleCombat)
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
end

function CheckForIdleMobileLandUnits(aiBrain)
    --Assigns any units without a platoon to the relevant platoon handle
    local bDebugMessages = false
    local sFunctionRef = 'CheckForIdleMobileLandUnits'
    local tAllUnits = aiBrain:GetListOfUnits(categories.MOBILE * categories.LAND, false, true)
    local oPlatoon
    local oArmyPool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    for iUnit, oUnit in tAllUnits do
        oPlatoon = oUnit.PlatoonHandle
        if not(oPlatoon) or oPlatoon == oArmyPool then
            if bDebugMessages == true then
                LOG(sFunctionRef..': Assigning unit to relevant idle platoon as it either has no platoon or is in army pool')
            end
            AllocateUnitsToIdlePlatoons(aiBrain, {oUnit})
        end
    end
end

function SetupIdlePlatoon(aiBrain, sPlan)
    local oNewPlatoon = aiBrain:MakePlatoon('', '')
    oNewPlatoon:UniquelyNamePlatoon(sPlan)
    oNewPlatoon:SetAIPlan(sPlan)
    aiBrain[sPlan] = oNewPlatoon
    oNewPlatoon:TurnOffPoolAI()
end

function UpdateIdlePlatoonActions(aiBrain, iCycleCount)
    local bDebugMessages = false
    local sFunctionRef = 'UpdateIdlePlatoonActions'
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
end

function PlatoonIdleUnitOverseer(aiBrain)
    local bDebugMessages = false
    local sFunctionRef = 'PlatoonIdleUnitOverseer'
    local iCycleCount = 0
    local iIdleUnitSearchThreshold = 10

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
        if bDebugMessages == true then LOG(sFunctionRef..': About to fork thread function to assign idle platoon units to platoons') end
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
        iCycleCount = iCycleCount + 1
        ForkThread(AssignIdlePlatoonUnitsToPlatoons, aiBrain)
        if iCycleCount == iIdleUnitSearchThreshold then
            ForkThread(CheckForIdleMobileLandUnits, aiBrain)
            iCycleCount = 0
        end
        ForkThread(UpdateIdlePlatoonActions, aiBrain, iCycleCount)
        WaitTicks(10)
    end
end
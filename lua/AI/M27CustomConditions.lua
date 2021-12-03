local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27EconomyOverseer = import('/mods/M27AI/lua/AI/M27EconomyOverseer.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')


function SafeToGetACUUpgrade(aiBrain)
    --Determines if its safe for the ACU to get an upgrade - considers ACU health and whether ACU is in a platoon set to heal
    local bDebugMessages = true if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'SafeToGetACUUpgrade'

    local bIsSafe = false
    local iSearchRange = 33
    local tACUPos = M27Utilities.GetACU(aiBrain):GetPosition()
    if bDebugMessages == true then LOG(sFunctionRef..': About to check if have intel coverage of iSearchRange='..iSearchRange..' for ACU position repr='..repr(tACUPos)) end
    if M27Logic.GetIntelCoverageOfPosition(aiBrain, tACUPos, iSearchRange) == true then
        --Are there enemies near the ACU with a threat value?
        local tNearbyEnemies = aiBrain:GetUnitsAroundPoint(categories.LAND, tACUPos, iSearchRange, 'Enemy')
        local iThreat = M27Logic.GetCombatThreatRating(aiBrain, tNearbyEnemies, true, nil, 50)
        if iThreat <= 15 then bIsSafe = true end
        if bDebugMessages == true then LOG(sFunctionRef..': Have intel coverage, iThreat='..iThreat..'; bIsSafe='..tostring(bIsSafe)) end
    end
    if bIsSafe == true then
        if bDebugMessages == true then LOG(sFunctionRef..': No nearby enemies, will now check ACUs health and if its trying to heal') end
        local oACU = M27Utilities.GetACU(aiBrain)
        local iCurrentHealth = oACU:GetHealth()
        local bACUNearBase = false
        if bDebugMessages == true then LOG(sFunctionRef..': M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]='..repr(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; M27Overseer.iDistanceFromBaseToBeSafe='..M27Overseer.iDistanceFromBaseToBeSafe..'; tACUPos='..repr(tACUPos)) end

        if M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= M27Overseer.iDistanceFromBaseToBeSafe then bACUNearBase = true end
        if iCurrentHealth <= aiBrain[M27Overseer.refiACUHealthToRunOn] and bACUNearBase == false then
            if bDebugMessages == true then LOG(sFunctionRef..': ACU health is '..iCurrentHealth..'; Health to run on='..aiBrain[M27Overseer.refiACUHealthToRunOn]) end
            bIsSafe = false
        elseif oACU.PlatoonHandle and oACU.PlatoonHandle[M27PlatoonUtilities.refbNeedToHeal] and bACUNearBase == false then
            if bDebugMessages == true then LOG(sFunctionRef..': ACU platoon is flagged that it needs to heal so not safe to get gun') end
            bIsSafe = false end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of check, bIsSafe='..tostring(bIsSafe)) end
    return bIsSafe
end

function NoEnemyUnitsNearACU(aiBrain, iMaxSearchRange, iMinSearchRange)
    --Need to have iMinSearchRange intel available, and will look up to iMaxSearchRange
    local tACUPos = M27Utilities.GetACU(aiBrain):GetPosition()
    local bNoEnemyUnits = true
    if M27Logic.GetIntelCoverageOfPosition(aiBrain, tACUPos, iMinSearchRange) == false then bNoEnemyUnits = false
    else
        local tNearbyEnemies = aiBrain:GetUnitsAroundPoint(categories.LAND, tACUPos, iMaxSearchRange, 'Enemy')
        bNoEnemyUnits = M27Utilities.IsTableEmpty(tNearbyEnemies)
    end
    return bNoEnemyUnits
end

function WantToGetGunUpgrade(aiBrain, bIgnoreEnemies)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'WantToGetGunUpgrade'
    --Returns true if meet all the conditions that mean will want gun upgrade
    if bIgnoreEnemies == nil then bIgnoreEnemies = false end
    local bWantToGetGun = true
    local iGrossEnergyIncome
    if bDebugMessages == true then LOG(sFunctionRef..': GrowwEnergyIncome='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; Netincome='..aiBrain:GetEconomyTrend('ENERGY')..'; EnergyStored='..aiBrain:GetEconomyStored('ENERGY')) end
    if aiBrain:GetEconomyTrend('ENERGY') < 170*0.1 then bWantToGetGun = false --Net energy income
    else
        iGrossEnergyIncome = aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]
        if iGrossEnergyIncome < 45 then --450 per second
            bWantToGetGun = false
            if iGrossEnergyIncome > 33 and aiBrain:GetEconomyStored('ENERGY') > 8000 then bWantToGetGun = true end
        end
        if bWantToGetGun == true and bIgnoreEnemies == false and SafeToGetACUUpgrade(aiBrain) == false then bWantToGetGun = false
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..'; bWantToGetGun='..tostring(bWantToGetGun)) end
    return bWantToGetGun
end

function WantMoreMAA(aiBrain, iMassOnMAAVsEnemyAir)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'WantMoreMAA'
    local iMAAMaxUnitCount = 50
    local bWantMoreMAA = false
    if aiBrain[M27Overseer.refbNeedMAABuilt] == true then
        if bDebugMessages == true then LOG(sFunctionRef..'; rebNeedMAABuild is true so returning true') end
        bWantMoreMAA = true
    else
        local iMassInMAA = aiBrain[M27AirOverseer.refiOurMassInMAA]
        if iMassInMAA <= 0 then
            if bDebugMessages == true then LOG(sFunctionRef..'; We have no MAA so want to build more') end
            bWantMoreMAA = true
        else
            local iMassInEnemyAir = aiBrain[M27AirOverseer.refiHighestEnemyAirThreat]
            if iMassOnMAAVsEnemyAir == nil then iMassOnMAAVsEnemyAir = 0.4 end
            if iMassInEnemyAir == 0 then
                if bDebugMessages == true then LOG(sFunctionRef..'; Enemy has no air threat') end
                bWantMoreMAA = false
            else
                if iMassInEnemyAir > iMassInMAA * iMassOnMAAVsEnemyAir then
                    --Check we haven't exceeded the threshold on MAA to get
                    if aiBrain[M27AirOverseer.refiOurMAAUnitCount] == nil then aiBrain[M27AirOverseer.refiOurMAAUnitCount] = 0 end
                    if aiBrain[M27AirOverseer.refiOurMAAUnitCount] > iMAAMaxUnitCount then return false
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..'; We dont have enough mass in MAA to deal with enemy air threat') end
                        bWantMoreMAA = true
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..'; We have enough mass in maa to deal with enemy air') end
                    bWantMoreMAA = false
                end
            end
        end
    end
end

function DoesACUHaveGun(aiBrain, bROFAndRange, oAltACU)
    --bROFAndRange: True if want ACU to have both ROFAndRange (only does something for Aeon)
    --UCBC includes simialr code but for some reason referencing it (or using a direct copy) causes error
    --oAltACU - can pass an ACU that's not aiBrain's ACU
    --e.g. need to specify 1 of aiBrain and oAltACU (no need to specify both)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'DoesACUHaveGun'
    if bROFAndRange == nil then bROFAndRange = true end
    local oACU = oAltACU
    if oACU == nil then oACU = M27Utilities.GetACU(aiBrain) end
    local tGunUpgrades = { 'HeavyAntiMatterCannon',
                           'CrysalisBeam', --Range
                           'HeatSink', --Aeon
                           'CoolingUpgrade',
                           'RateOfFire'
    }
    local bACUHasUpgrade = false
    local bHaveOne = false
    if bDebugMessages == true then LOG(sFunctionRef..': About to check if ACU has gun upgrade') end
    for iUpgrade, sUpgrade in tGunUpgrades do
        if bDebugMessages == true then LOG(sFunctionRef..': sUpgrade to check='..sUpgrade..'; oACU:HasEnhancement(sUpgrade)='..tostring(oACU:HasEnhancement(sUpgrade))) end
        if oACU:HasEnhancement(sUpgrade) then
            if bDebugMessages == true then LOG(sFunctionRef..': ACU has enhancement '..sUpgrade..'; returning true unless Aeon and only 1 upgrade') end
            bACUHasUpgrade = true
            if sUpgrade == 'CrysalisBeam' or sUpgrade == 'HeatSink' then
                if bDebugMessages == true then LOG(sFunctionRef..': ACU has either Crysalis or Heat sink, sUpgrade='..sUpgrade) end
                if bROFAndRange == false then
                    break
                else
                    if bHaveOne == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': First of gun upgrades have come across, so not true yet') end
                        bACUHasUpgrade = false
                        bHaveOne = true
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Second of gun upgrades have come across, so return true') end
                        bACUHasUpgrade = true break
                    end
                end
            else
            break
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of check, bACUHasUpgrade='..tostring(bACUHasUpgrade)) end
    return bACUHasUpgrade
end

function HydroNearACUAndBase(aiBrain, bNearBaseOnlyCheck, bAlsoReturnHydroTable)
    --If further away hydro, considers if its closer to enemy base than start point; returns empty table if no hydro
    --if bAlsoReturnHydroTable == true then returns table of the hydro locations
    if bNearBaseOnlyCheck == nil then bNearBaseOnlyCheck = false end
    local iMaxDistanceForHydro = 70 --must be within this distance of start position and ACU
    local tACUPosition = M27Utilities.GetACU(aiBrain):GetPosition()
    local tNearestHydro = {}
    local iMinDistanceToACU = 1000
    local iCurDistanceToACU
    local bHydroNear = false
    local iDistanceToStart
    local iValidHydroCount = 0
    local tValidHydro = {}
    if bAlsoReturnHydroTable == nil then bAlsoReturnHydroTable = false end
    local iStartGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
    local iHydroGroup
    if M27Utilities.GetACU(aiBrain) then
        for iHydro, tHydro in M27MapInfo.HydroPoints do
            if bNearBaseOnlyCheck == false then iCurDistanceToACU = M27Utilities.GetDistanceBetweenPositions(tHydro, tACUPosition) end
            if bNearBaseOnlyCheck == true or iCurDistanceToACU <= iMaxDistanceForHydro then
                --InSameSegmentGroup(oUnit, tDestination, bReturnUnitGroupOnly)
                iHydroGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tHydro)
                if iStartGroup == iHydroGroup then
                    iDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tHydro, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    if iDistanceToStart <= iMaxDistanceForHydro then
                        bHydroNear = true
                        if bAlsoReturnHydroTable == false then
                            break
                        else
                            iValidHydroCount = iValidHydroCount + 1
                            tValidHydro[iValidHydroCount] = tHydro
                        end
                    end
                end
            end
        end
    end
    return bHydroNear, tValidHydro
end

function ACUShouldAssistEarlyHydro(aiBrain)
    local bHydroNearStart = HydroNearACUAndBase(aiBrain)
    local bACUShouldAssist = false
    if bHydroNearStart and GetGameTimeSeconds() <= 200 then bACUShouldAssist = true end
    return bACUShouldAssist
end

function CanUnitUseOvercharge(aiBrain, oUnit)
    --For now checks if enough energy and not underwater; separate function used as may want to expand this with rate of fire check in future
    local oBP = oUnit:GetBlueprint()
    local iEnergyNeeded
    for iWeapon, oWeapon in oBP.Weapon do
        if oWeapon.OverChargeWeapon then
            if oWeapon.EnergyRequired then
                iEnergyNeeded = oWeapon.EnergyRequired
                break
            end
        end
    end
    local bCanUseOC = false
    if aiBrain:GetEconomyStored('ENERGY') >= iEnergyNeeded then bCanUseOC = true end
    if bCanUseOC == true then
        --Check if underwater
        local oUnitPosition = oUnit:GetPosition()
        local iHeightAtWhichConsideredUnderwater = M27MapInfo.IsUnderwater(oUnitPosition, true) + 0.25 --small margin of error
        local tFiringPositionStart = M27Logic.GetDirectFireWeaponPosition(oUnit)
        if tFiringPositionStart then
            local iFiringHeight = tFiringPositionStart[2]
            if iFiringHeight <= iHeightAtWhichConsideredUnderwater then
                bCanUseOC = false
            end
        end
    end
    return bCanUseOC
end

function HaveExcessEnergy(aiBrain, iExcessEnergy)
    --returns true if have at least iExcessEnergy; note that GetEconomyTrend returns the 'per tick' excess (so 10% of what is displayed)
    local sResource = 'ENERGY'
    local bExcessEnergy = false
    if aiBrain:GetCurrentUnits(categories.EXPERIMENTAL * categories.ECONOMIC * categories.STRUCTURE) > 0 then bExcessEnergy = true
    else
        if aiBrain:GetEconomyTrend(sResource) >= iExcessEnergy*0.1 then bExcessEnergy = true end
    end
    return bExcessEnergy
end

function ExcessMassIncome(aiBrain, iExcessResource)
    --returns true if have at least iExcessMass; note that the economy trend will be 10% of what is displayed (so 0.8 excess mass income is displayed in-game as 8 excess mass income) - i.e. presumably it's the 'per tick' excess
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sResource = 'MASS'
    local bHaveExcess = false
    if bDebugMessages == true then LOG('M27ExcessMassIncome='..aiBrain:GetEconomyTrend(sResource)..'; iExcessCondition='..iExcessResource) end
    if aiBrain:GetCurrentUnits(categories.EXPERIMENTAL * categories.ECONOMIC * categories.STRUCTURE) > 0 then HaveExcess = true
    elseif aiBrain:GetEconomyTrend(sResource) >= iExcessResource*0.1 then bHaveExcess = true end
    return bHaveExcess
end

function AtLeastXMassStored(aiBrain, iResourceStored)
    local iStored = aiBrain:GetEconomyStored('MASS')
    local bEnoughStored = false
    if iStored >= iResourceStored then bEnoughStored = true end
    return bEnoughStored
end

function LifetimeBuildCountLessThan(aiBrain, category, iBuiltThreshold)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'LifetimeBuildCountLessThan'
    local iTotalBuilt = 0
    if bDebugMessages == true then LOG(sFunctionRef..' - start') end
    local testCat = category
    if type(category) == 'string' then
        testCat = ParseEntityCategory(category)
    end
    local tUnitBPIDs = EntityCategoryGetUnitList(category)
    local oCurBlueprint
    local iCurCount

    if tUnitBPIDs == nil then
        M27Utilities.ErrorHandler('tUnitBPIDs is nil, so wont have built any')
        iTotalBuilt = 0
    else
        if bDebugMessages == true then LOG(sFunctionRef..': cycling through tUnitBPIDs') end
        for _, sBPID in tUnitBPIDs do
            oCurBlueprint = __blueprints[sBPID]
            iCurCount = aiBrain.M27LifetimeUnitCount[sBPID]
            if iCurCount == nil then iCurCount = 0 end
            if bDebugMessages == true then LOG(sFunctionRef..': sBPID='..sBPID..'; LifetimeCount='..iCurCount) end
            iTotalBuilt = iTotalBuilt + iCurCount
        end
    end
    local bBuiltLessThan = true
    if iTotalBuilt >= iBuiltThreshold then bBuiltLessThan = false end
    if bDebugMessages == true then LOG(sFunctionRef..': iTotalBuilt='..iTotalBuilt..'; iBuiltThreshold='..iBuiltThreshold..'; bBuiltLessThan='..tostring(bBuiltLessThan)) end
    return bBuiltLessThan
end

function IsMexOrHydroUnclaimed(aiBrain, tResourcePosition, bMexNotHydro, bTreatEnemyBuildingAsUnclaimed, bTreatOurOrAllyBuildingAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
    --bTreatQueuedBuildingsAsUnclaimed: If set to false, then consideres all planned mex buidlings for engineers and treats them as being claimed
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'IsMexOrHydroUnclaimed'
    if bTreatEnemyBuildingAsUnclaimed == nil then bTreatEnemyBuildingAsUnclaimed = false end
    if bTreatOurOrAllyBuildingAsUnclaimed == nil then bTreatOurOrAllyBuildingAsUnclaimed = false end
    if bTreatQueuedBuildingsAsUnclaimed == nil then bTreatQueuedBuildingsAsUnclaimed = bTreatOurOrAllyBuildingAsUnclaimed end
    local iBuildingSizeRadius = 0.5
    if bMexNotHydro == false then iBuildingSizeRadius = M27UnitInfo.GetBuildingSize('UAB1102')[1]*0.5 end
    local tNearbyAllyUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, tResourcePosition, iBuildingSizeRadius, 'Ally')
    local bResourceIsUnclaimed = true

    if M27Utilities.IsTableEmpty(tNearbyAllyUnits) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': Detected an allied building, checking its fractioncomplete') end
        if bTreatOurOrAllyBuildingAsUnclaimed == false then
            --Check if mex is part-built
            for iBuilding, oBuilding in tNearbyAllyUnits do
                if oBuilding.GetFractionComplete then
                    if oBuilding:GetFractionComplete() >= 1 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Fraction complete>=1 so building marked as complete') end
                        bResourceIsUnclaimed = false break end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Fractioncomplete='..oBuilding.GetFractionComplete()) end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': 1 bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': 2 bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
        else
            if bTreatEnemyBuildingAsUnclaimed == true then bResourceIsUnclaimed = true
            else
                local tNearbyEnemyUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, tResourcePosition, iBuildingSizeRadius, 'Enemy')
                bResourceIsUnclaimed = M27Utilities.IsTableEmpty(tNearbyEnemyUnits)
            end
            if bDebugMessages == true then LOG(sFunctionRef..': 3 bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': 3a bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': 3b bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
        if bTreatEnemyBuildingAsUnclaimed == true then
            bResourceIsUnclaimed = true
            if bDebugMessages == true then LOG(sFunctionRef..': 3c bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
        else
            local tNearbyEnemyUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, tResourcePosition, iBuildingSizeRadius, 'Enemy')
            bResourceIsUnclaimed = M27Utilities.IsTableEmpty(tNearbyEnemyUnits)
            if bDebugMessages == true then LOG(sFunctionRef..': 3d bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': 4 bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)..'; about to check if we should consider building queues bTreatQueuedBuildingsAsUnclaimed='..tostring(bTreatQueuedBuildingsAsUnclaimed)) end
    if bResourceIsUnclaimed == true and bTreatQueuedBuildingsAsUnclaimed == false then
        --Do we have an entry in the mex queue?
        local sLocationRef = M27Utilities.ConvertLocationToReference(tResourcePosition)
        if bDebugMessages == true then LOG(sFunctionRef..': Checking if queued up anything for sLocationRef='..sLocationRef) end
        --reftEngineerAssignmentsByLocation --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the engineer unique ref assigned to this location
        if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation]) == false then
            if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef]) == false then
                if bDebugMessages == true then LOG(sFunctionRef..': Have queued something for sLocationRef='..sLocationRef..'; checking if any builders are still alive') end
                --Check that any queued engineer is still alive
                local oBuilder
                local bClearedSomething = false
                for iActionRef, tSubtable in aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] do
                    if M27Utilities.IsTableEmpty(tSubtable) == false then
                        for iUniqueRef, oBuilder in aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][iActionRef] do
                            if oBuilder.Dead then
                                if bDebugMessages == true then LOG(sFunctionRef..': oBuilder for iAction='..iAction..' is dead so clearing its actions') end
                                M27EngineerOverseer.ClearEngineerActionTrackers(aiBrain, oBuilder)
                                bClearedSomething = true
                            else
                                bResourceIsUnclaimed = false
                                break
                            end
                        end
                    end
                end
                if bClearedSomething == true and bResourceIsUnclaimed == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': Resource was claimed but all builders are dead so treating as unclaimed') end
                end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End: bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
    return bResourceIsUnclaimed
end

function IsHydroUnclaimed(aiBrain, tHydroPosition, bTreatEnemyBuildingAsUnclaimed, bTreatOurOrAllyBuildingAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
    return IsMexOrHydroUnclaimed(aiBrain, tResourcePosition, false, bTreatEnemyBuildingAsUnclaimed, bTreatOurOrAllyBuildingAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
end
function IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
    --IsMexOrHydroUnclaimed(aiBrain, tResourcePosition, bMexNotHydro, bTreatEnemyBuildingAsUnclaimed, bTreatOurOrAllyBuildingAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
    return IsMexOrHydroUnclaimed(aiBrain, tMexPosition, true, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
    --[[
    --bTreatQueuedBuildingsAsUnclaimed: If set to true, then consideres all planned mex buidlings for engineers and treats them as being claimed
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'IsMexUnclaimed'
    if bTreatEnemyMexAsUnclaimed == nil then bTreatEnemyMexAsUnclaimed = false end
    if bTreatAllyMexAsUnclaimed == nil then bTreatAllyMexAsUnclaimed = false end
    if bTreatQueuedBuildingsAsUnclaimed == nil then bTreatQueuedBuildingsAsUnclaimed = false end
    local iBuildingSizeRadius = 0.5
    local tNearbyAllyUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, tMexPosition, iBuildingSizeRadius, 'Ally')
    local bMexIsUnclaimed = true

    if M27Utilities.IsTableEmpty(tNearbyAllyUnits) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': Detected an allied building, checking its fractioncomplete') end
        if bTreatAllyMexAsUnclaimed == false then
            --Check if mex is part-built
            for iBuilding, oBuilding in tNearbyAllyUnits do
                if oBuilding.GetFractionComplete then
                    if oBuilding:GetFractionComplete() >= 1 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Fraction complete>=1 so building marked as complete') end
                        bMexIsUnclaimed = false break end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Fractioncomplete='..oBuilding.GetFractionComplete()) end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': 1 bMexIsUnclaimed='..tostring(bMexIsUnclaimed)) end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': 2 bMexIsUnclaimed='..tostring(bMexIsUnclaimed)) end
        else
            if bTreatEnemyMexAsUnclaimed == true then bMexIsUnclaimed = true
            else
                local tNearbyEnemyUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, tMexPosition, iBuildingSizeRadius, 'Enemy')
                bMexIsUnclaimed = M27Utilities.IsTableEmpty(tNearbyEnemyUnits)
            end
            if bDebugMessages == true then LOG(sFunctionRef..': 3 bMexIsUnclaimed='..tostring(bMexIsUnclaimed)) end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': 3a bMexIsUnclaimed='..tostring(bMexIsUnclaimed)) end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': 3b bMexIsUnclaimed='..tostring(bMexIsUnclaimed)) end
        if bTreatEnemyMexAsUnclaimed == true then
            bMexIsUnclaimed = true
            if bDebugMessages == true then LOG(sFunctionRef..': 3c bMexIsUnclaimed='..tostring(bMexIsUnclaimed)) end
        else
            local tNearbyEnemyUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, tMexPosition, iBuildingSizeRadius, 'Enemy')
            bMexIsUnclaimed = M27Utilities.IsTableEmpty(tNearbyEnemyUnits)
            if bDebugMessages == true then LOG(sFunctionRef..': 3d bMexIsUnclaimed='..tostring(bMexIsUnclaimed)) end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': 4 bMexIsUnclaimed='..tostring(bMexIsUnclaimed)) end
    end

    if bMexIsUnclaimed == true and bTreatQueuedBuildingsAsUnclaimed == true then
        --Do we have an entry in the mex queue?
        local sLocationRef = M27Utilities.ConvertLocationToReference(tMexPosition)
        local tPossibleQueue1 = aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation]
        if M27Utilities.IsTableEmpty(tPossibleQueue1) == false then
            local tPossibleQueue2 = tPossibleQueue1[sLocationRef]
            if M27Utilities.IsTableEmpty(tPossibleQueue2) == false then
                local oBuilder = tPossibleQueue2[M27EngineerOverseer.refEngineerAssignmentEngineerRef]
                if oBuilder and not(oBuilder.Dead) then
                    if oBuilder[M27EngineerOverseer.refiEngineerCurrentAction] == M27EngineerOverseer.refActionBuildMex then
                        bMexIsUnclaimed = false
                    end
                else
                    --Engi is dead so clear tracking of this
                    aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] = {}
                end
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End: bMexIsUnclaimed='..tostring(bMexIsUnclaimed)) end
    return bMexIsUnclaimed --]]
end

function IsLocationWithinIntelPathLine(aiBrain, tLocation)
    --Returns true if tLocation is closer to our start than the intel line
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
    local sFunctionRef = 'IsLocationWithinIntelPathLine'
    local bWithinIntelLine = false
    if aiBrain[M27Overseer.refbIntelPathsGenerated] == true then
        local iIntelPathPosition = aiBrain[M27Overseer.refiCurIntelLineTarget]
        if iIntelPathPosition then
            local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]

            local iEnemyStartPosition = M27Logic.GetNearestEnemyStartNumber(aiBrain)
            local tEnemyPosition = M27MapInfo.PlayerStartPoints[iEnemyStartPosition]
            local iDistanceFromStartToEnemy = M27Utilities.GetDistanceBetweenPositions(tEnemyPosition, tStartPosition)
            local iLocationDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tEnemyPosition, tLocation)
            if bDebugMessages == true then LOG(sFunctionRef..': tLocation='..repr(tLocation)..'; iLocationDistanceToEnemy='..iLocationDistanceToEnemy..'; iDistanceFromStartToEnemy='..iDistanceFromStartToEnemy..'; tEnemyPosition='..repr(tEnemyPosition)..'; tStartPosition='..repr(tStartPosition)) end
            if iLocationDistanceToEnemy > iDistanceFromStartToEnemy then
                bWithinIntelLine = true
            else
                local iLocationDistanceToBase = M27Utilities.GetDistanceBetweenPositions(tStartPosition, tLocation)
                local iMinDistanceToPath = 10000
                local tClosestIntelPosition = {}
                local iCurDistanceToPath
                for iIntelPosition, tIntelPosition in aiBrain[M27Overseer.reftIntelLinePositions][iIntelPathPosition] do
                    iCurDistanceToPath = M27Utilities.GetDistanceBetweenPositions(tIntelPosition, tLocation)
                    if iCurDistanceToPath < iMinDistanceToPath then
                        iCurDistanceToPath = iMinDistanceToPath
                        tClosestIntelPosition = tIntelPosition
                    end
                end
                local iPathDistanceToBase = M27Utilities.GetDistanceBetweenPositions(tStartPosition, tClosestIntelPosition)
                if iLocationDistanceToBase <= iPathDistanceToBase then bWithinIntelLine = true end
                if bDebugMessages == true then LOG(sFunctionRef..': iLocationDistanceToBase='..iLocationDistanceToBase..'; iPathDistanceToBase='..iPathDistanceToBase) end
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': No intel path generated yet') end
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': No intel line generated yet') end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Finished considering; bWithinIntelLine='..tostring(bWithinIntelLine)) end
    return bWithinIntelLine
end
function IsLocationWithinDefenceCoverage(aiBrain, tLocation)
    --Returns true if tLocation is within defence coverage range
    local bWithinCoverage = false
    local iDefenceCoverage = aiBrain[M27Overseer.refiNearestOutstandingThreat]
    local iModDistanceFromStart = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tLocation)
    if iModDistanceFromStart <= iDefenceCoverage then bWithinCoverage = true end
    return bWithinCoverage
end
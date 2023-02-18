local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27EconomyOverseer = import('/mods/M27AI/lua/AI/M27EconomyOverseer.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27Team = import('/mods/M27AI/lua/AI/M27Team.lua')
local M27Navy = import('/mods/M27AI/lua/AI/M27Navy.lua')

--NOTE: Below are replaced by GameSettingWarningsAndChecks if sim mods are detected that expand the acu enhancement list
tGunUpgrades = { 'HeavyAntiMatterCannon',
                       'CrysalisBeam', --Range
                       'HeatSink', --Aeon
                       'CoolingUpgrade',
                       'RateOfFire'
}
tBigGunUpgrades = { 'MicrowaveLaserGenerator',
                    'BlastAttack'
}

tTMLUpgrades = {'Missile',
                'TacticalMissile',
                'TacticalNukeMissile',}

function SafeToUpgradeUnit(oUnit)
    --Intended e.g. for mexes to decide whether to upgrade
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'SafeToUpgradeUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if EntityCategoryContains(M27UnitInfo.refCategoryMex * categories.TECH1, oUnit.UnitId) then bDebugMessages = true end
    --Can the unit be upgraded?
    local bSafeToGetUpgrade = false
    local aiBrain = oUnit:GetAIBrain()
    local oUnitBP = oUnit:GetBlueprint()
    local sUpgradesTo = oUnitBP.General.UpgradesTo
    local iCurRadarRange, oCurBlueprint
    local iDistanceToBaseThatIsSafe = 40 --treat as safe even if enemies within this distance
    local iMinScoutRange = 15 --treated as intel coverage if have a land scout within this range
    local iEnemySearchRange = 90 --look for enemies within this range
    local iMinIntelRange = 40 --Need a radar with at least this much intel to treat as having intel coverage
    if bDebugMessages == true then LOG(sFunctionRef..': Considering if it is safe to upgrade '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end

    if sUpgradesTo and not(sUpgradesTo == '') then
        local tUnitLocation = oUnit:GetPosition()
        local iDistToStart = M27Utilities.GetDistanceBetweenPositions(tUnitLocation, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])

        if iDistToStart <= iDistanceToBaseThatIsSafe then bSafeToGetUpgrade = true
        else
            local bHaveIntelCoverage = false
            --Not close to base so check for intel coverage and enemies - is there a land scout within 15 of us?
            if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandScout, tUnitLocation, iMinScoutRange, 'Ally')) == false then
                bHaveIntelCoverage = true
            else --Check if nearby radar
                local tNearbyRadar = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryRadar, tUnitLocation, 1000, 'Ally')
                if M27Utilities.IsTableEmpty(tNearbyRadar) == false then
                    for iRadar, oRadar in tNearbyRadar do
                        iCurRadarRange = 0
                        if oRadar.GetBlueprint and not(oRadar.Dead) and oRadar.GetFractionComplete and oRadar:GetFractionComplete() == 1 then
                            oCurBlueprint = oRadar:GetBlueprint()
                            if oCurBlueprint.Intel and oCurBlueprint.Intel.RadarRadius then iCurRadarRange = oCurBlueprint.Intel.RadarRadius end
                        end
                        if iCurRadarRange > 0 then
                            if M27Utilities.GetDistanceBetweenPositions(oRadar:GetPosition(), tUnitLocation) - iCurRadarRange <= iMinIntelRange then bHaveIntelCoverage = true break end
                        end
                    end
                end
            end
            if bHaveIntelCoverage then
                --Check for nearby enemies

                bSafeToGetUpgrade = M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAllNonAirScoutUnits, tUnitLocation, iEnemySearchRange, 'Enemy'))
                if bSafeToGetUpgrade == false then
                    --Exception - Unit is ACU with gun with low enemy threat and have shield coverage and high health
                    if oUnit.PlatoonHandle and M27Utilities.IsACU(oUnit) then
                        local oPlatoon = oUnit.PlatoonHandle
                        if oPlatoon[M27PlatoonUtilities.refbACUInPlatoon] and M27UnitInfo.GetUnitHealthPercent(oUnit) > 0.8 and DoesACUHaveGun(aiBrain, false, oUnit) and DoesPlatoonOrUnitWantAnotherMobileShield(oPlatoon, 200, false) == false then
                            bSafeToGetUpgrade = true
                        end
                    end
                end
            else
                --No intel coverage - still consider safe if relatively close to our base on a mod distance basis
                if bDebugMessages == true then LOG(sFunctionRef..': Have no intel coverage, will still consider safe if have full health and are relatively close to our base. Health%='..M27UnitInfo.GetUnitHealthPercent(oUnit)..'; ModDist='..M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false)..'; Emergency range='..aiBrain[M27Overseer.refiModDistEmergencyRange]..'; Dist to enemy base='..M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))..'; Dist to our base='..iDistToStart..'; Dist between our base and enemy base='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]) end
                if M27UnitInfo.GetUnitHealthPercent(oUnit) == 1 then
                    local iModDistToStart = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tUnitLocation, false)
                    if iDistToStart <= aiBrain[M27Overseer.refiModDistEmergencyRange] and iModDistToStart <= aiBrain[M27Overseer.refiModDistEmergencyRange] and M27Utilities.GetDistanceBetweenPositions(tUnitLocation, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) >= aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] then
                        if bDebugMessages == true then LOG(sFunctionRef..': Are within emergency range so safe to upgrade') end
                        bSafeToGetUpgrade = true
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': iModDistToStart='..iModDistToStart..'; aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]..'; aiBrain[M27Overseer.refiModDistFromStartNearestThreat]='..aiBrain[M27Overseer.refiModDistFromStartNearestThreat]..'; iDistToStart='..iDistToStart..'; aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy]='..aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy]..'; aiBrain[refiPercentageClosestFriendlyLandFromOurBaseToEnemy]='..aiBrain[M27Overseer.refiPercentageClosestFriendlyLandFromOurBaseToEnemy]..'; aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]..'; Is table of nearby units empty='..tostring(M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(categories.ALLUNITS - categories.BENIGN, tUnitLocation, iEnemySearchRange + 30, 'Enemy')))) end

                        if iModDistToStart < aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] and iModDistToStart < aiBrain[M27Overseer.refiModDistFromStartNearestThreat] and (iDistToStart < aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy] * aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] or iDistToStart + 40 < aiBrain[M27Overseer.refiPercentageClosestFriendlyLandFromOurBaseToEnemy] * aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]) and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(categories.ALLUNITS - categories.BENIGN, tUnitLocation, iEnemySearchRange + 30, 'Enemy')) then
                            bSafeToGetUpgrade = true
                        end
                    end
                end
            end
        end
    end


    --TML extra logic for mexes (in reality will only stop T2 mexes upgrading to T3; t1 mex would be harder since would need to recreate the 'protected from TMD' logic here for T1 mexes, without recording the mex as wanting an upgrade, and would then risk never upgrading mexes
    if bSafeToGetUpgrade and EntityCategoryContains(M27UnitInfo.refCategoryMex, oUnit.UnitId) then
        if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyTML]) == false and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau]) == false then
            for iPlateau, toUnits in aiBrain[M27EngineerOverseer.reftUnitsWantingTMDByPlateau] do
                if M27Utilities.IsTableEmpty(toUnits) == false then
                    for iAltUnit, oAltUnit in toUnits do
                        if oUnit == oAltUnit then
                            bSafeToGetUpgrade = false
                        end
                    end
                end
            end
        end
        --T1 mexes - dont upgrade if recently built and far from base
        if bSafeToGetUpgrade and EntityCategoryContains(categories.TECH1, oUnit.UnitId) and GetGameTimeSeconds() - (oUnit[M27UnitInfo.refiTimeConstructed] or 0) <= 40 and M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) >= 80 then
            bSafeToGetUpgrade = false
        end
    end

    if bDebugMessages == true then LOG(sFunctionRef..': End of code, bSafeToGetUpgrade='..tostring(bSafeToGetUpgrade)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bSafeToGetUpgrade
end

function DoWeWantPriorityT2LandFactoryHQ(aiBrain, iOptionalLandFactoryCount)
    if not(iOptionalLandFactoryCount) then iOptionalLandFactoryCount = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryLandFactory) end
    local bGetT2FactoryEvenWithLowMass = false
    function AlreadyGettingT2Land()
        if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]) == false then
            --Are we upgrading a T2 air fac to T3 (rather than T1 to T2), or a land fac?
            for iUpgrading, oUpgrading in aiBrain[M27EconomyOverseer.reftActiveHQUpgrades] do
                if EntityCategoryContains(M27UnitInfo.refCategoryLandFactory + categories.TECH1, oUpgrading.UnitId) then
                    return true
                end
            end
        end
        return false
    end
    --If enemy has ACU with T2 upgrade and can path to us with land and it isnt that far away then want T2 land
    if M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoLastNearestACU]) and iOptionalLandFactoryCount > 0 and aiBrain[M27Overseer.refoLastNearestACU]:HasEnhancement('AdvancedEngineering') and aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 1 and M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.refoLastNearestACU]:GetPosition()) <= 325 then
        if not(AlreadyGettingT2Land) then
            return true
        end
    end
    if iOptionalLandFactoryCount >= 4 and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyLandMain and aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 1 and aiBrain[M27Overseer.refiOurHighestAirFactoryTech] > 1 then
        local bAlreadyGettingT2LandFacOrT2Air = false
        if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]) == false then
            --Are we upgrading a T2 air fac to T3 (rather than T1 to T2), or a land fac?
            for iUpgrading, oUpgrading in aiBrain[M27EconomyOverseer.reftActiveHQUpgrades] do
                if EntityCategoryContains(M27UnitInfo.refCategoryLandFactory + categories.TECH1, oUpgrading.UnitId) then
                    bAlreadyGettingT2LandFacOrT2Air = true
                    break
                end
            end
        end
        if not(AlreadyGettingT2Land()) then
            local iCurrentCombatUnits = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryLandCombat)
            if iCurrentCombatUnits >= 40 or (iCurrentCombatUnits >= 30 and (aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 5 or aiBrain:GetEconomyStored('MASS') >= 1000)) then
                bGetT2FactoryEvenWithLowMass = true
            end
        end
    end
    return bGetT2FactoryEvenWithLowMass
end

function HaveNearbyMobileShield(oPlatoon)
    local bHaveNearbyShield = false
    local sFunctionRef = 'HaveNearbyMobileShield'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon] then
        local iShieldValueHave = oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon][M27PlatoonUtilities.refiPlatoonMassValue]
        if iShieldValueHave >= 100 and M27Utilities.GetDistanceBetweenPositions(M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon), M27PlatoonUtilities.GetPlatoonFrontPosition(oPlatoon[M27PlatoonUtilities.refoSupportingShieldPlatoon])) <= 20 then
            bHaveNearbyShield = true
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bHaveNearbyShield
end

function WantEnergyOrMassReclaim(aiBrain)
    --Returns 2 variables, 1st: true/flse for if want energy; 2nd: true/false for if want mass
    local bGetEnergy = true
    local bGetMass = true

    if aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.95 then
        bGetEnergy = false
    else
        if aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.25 then
            bGetMass = false
        end
    end
    if bGetMass and aiBrain:GetEconomyStoredRatio('MASS') >= 0.85 then
        bGetMass = false
    end

    return bGetEnergy, bGetMass
end

function SafeToGetACUUpgrade(aiBrain)
    --Determines if its safe for the ACU to get an upgrade - considers ACU health and whether ACU is in a platoon set to heal
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'SafeToGetACUUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local bIsSafe = false
    local iSearchRange = 33
    local iDistanceToBaseThatIsSafe = M27Overseer.iDistanceFromBaseToBeSafe --treat as safe even if enemies nearby if are this close to base
    if not(aiBrain) or aiBrain.GetUnitId then M27Utilities.ErrorHandler('aiBrain is nil or is a unit reference')
    else
        local oACU = M27Utilities.GetACU(aiBrain)
        local bFirstUpgrade = true
        if DoesACUHaveGun(aiBrain, false, oACU) then
            iDistanceToBaseThatIsSafe = iDistanceToBaseThatIsSafe + 50
            bFirstUpgrade = false
        elseif M27UnitInfo.GetNumberOfUpgradesObtained(oACU) > 0 then
            bFirstUpgrade = false
        end
        local tACUPos = oACU:GetPosition()
        if M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iDistanceToBaseThatIsSafe then
            if bDebugMessages == true then LOG(sFunctionRef..': Are close to our start so will treat it as being safe') end
            bIsSafe = true
        else
            --Have we been losing health quickly?

            --Do we have at least 2 T2 PD nearby?
            local tNearbyPD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2PlusPD, oACU:GetPosition(), 20, 'Ally')
            if M27Utilities.IsTableEmpty(tNearbyPD) == false and table.getn(tNearbyPD) >= 2 then
                local iNearbyPD = 0
                for iPD, oPD in tNearbyPD do
                    if oPD:GetFractionComplete() >= 1 then
                        iNearbyPD = iNearbyPD + 1
                        if iNearbyPD >= 2 then
                            if bDebugMessages == true then LOG(sFunctionRef..': Have at least 2 nearby PD so safe to upgrade') end
                            bIsSafe = true break
                        end
                    end
                end
            end
            if not(bIsSafe) and M27Utilities.IsACU(oACU) then

                if not(ACUShouldRunFromBigThreat(aiBrain)) then

                    local iCurTime = math.floor(GetGameTimeSeconds())

                    --Have we taken at least 1k damage over our regen rate in last 20s?
                    if bDebugMessages == true then LOG(sFunctionRef..': ACU health change in last 20s='..(oACU[M27Overseer.reftACURecentHealth][iCurTime-21] or 0) - (oACU[M27Overseer.reftACURecentHealth][iCurTime - 1] or oACU[M27Overseer.reftACURecentHealth][iCurTime - 2] or oACU[M27Overseer.reftACURecentHealth][iCurTime - 3] or 0)) end
                    if (oACU[M27Overseer.reftACURecentHealth][iCurTime-21] or 0) - (oACU[M27Overseer.reftACURecentHealth][iCurTime - 1] or oACU[M27Overseer.reftACURecentHealth][iCurTime - 2] or oACU[M27Overseer.reftACURecentHealth][iCurTime - 3] or 0) > 1000 then
                        bIsSafe = false --Redundancy
                        if bDebugMessages == true then LOG(sFunctionRef..': Taken too much damage recently so not safe') end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': About to check if have intel coverage of iSearchRange='..iSearchRange..' for ACU position repr='..repru(tACUPos)) end
                        --Does ACU have an assigned scout that is nearby, or does it have sufficient intel coverage
                        local tNearbyEnemies

                        --Are we either underwater, or are a cloaked ACU not in enemy omni range?
                        local bAreUnderwater = M27UnitInfo.IsUnitUnderwater(oACU)
                        if bDebugMessages == true then LOG(sFunctionRef..': Are we underwater='..tostring(bAreUnderwater)..'; Do we have cloaking enhancement='..tostring(oACU:HasEnhancement('CloakingGenerator'))) end

                        if (oACU:HasEnhancement('CloakingGenerator') and not(IsLocationNearEnemyOmniRange(aiBrain, oACU:GetPosition(), 3))) then bIsSafe = true
                        elseif bAreUnderwater then
                            if not(aiBrain[M27AirOverseer.refbEnemyHasBuiltTorpedoBombers]) then
                                local iPond = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeNavy, oACU:GetPosition())
                                if not(M27Navy.tPondDetails[iPond]) then
                                    bIsSafe = true
                                else
                                    --Does the enemy have no units or no antinavy units in the pond?
                                    if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond][iPond]) then
                                        bIsSafe = true
                                    elseif M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.ANTINAVY * categories.MOBILE, M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond][iPond])) then
                                        bIsSafe = true
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': ACU not safe to get upgrade as enemy has mobile antinavy in the pond') end
                                    end
                                end
                            elseif bDebugMessages == true then LOG(sFunctionRef..': ACU not safe to get upgrade as enemy has prev built torp bombers')
                            end
                        else
                            --Are we near to enemy base and not near ours?
                            local iDistToEnemy = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                            if iDistToEnemy > 90 or iDistToEnemy > M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then
                                local bNearbyScout = false
                                if oACU[M27Overseer.refoScoutHelper] and M27UnitInfo.IsUnitValid(oACU[M27Overseer.refoScoutHelper][M27PlatoonUtilities.refoFrontUnit]) and M27Utilities.GetDistanceBetweenPositions(M27PlatoonUtilities.GetPlatoonFrontPosition(oACU[M27Overseer.refoScoutHelper]), tACUPos) <= math.max(8, oACU[M27Overseer.refoScoutHelper][M27PlatoonUtilities.refoFrontUnit]:GetBlueprint().Intel.RadarRadius - iSearchRange) then
                                    bNearbyScout = true
                                end
                                if bNearbyScout or M27Logic.GetIntelCoverageOfPosition(aiBrain, tACUPos, iSearchRange) == true then

                                    --Are there enemies near the ACU with a threat value?
                                    tNearbyEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAllNonAirScoutUnits, tACUPos, iSearchRange, 'Enemy')
                                    local iThreat = M27Logic.GetCombatThreatRating(aiBrain, tNearbyEnemies, true, nil, 50)
                                    if iThreat <= 150 then
                                        bIsSafe = true
                                    end
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Have intel coverage, iThreat=' .. iThreat .. '; bIsSafe=' .. tostring(bIsSafe))
                                    end
                                elseif bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Dont have intel coverage of ACU')
                                    if oACU[M27Overseer.refoScoutHelper] then
                                        LOG('Distance of assigned scout to ACU=' .. M27Utilities.GetDistanceBetweenPositions(M27PlatoonUtilities.GetPlatoonFrontPosition(oACU[M27Overseer.refoScoutHelper]), tACUPos))
                                    else
                                        LOG('Scout helper isnt a valid platoon')
                                    end
                                end
                            elseif bDebugMessages == true then
                                LOG(sFunctionRef .. ': iDistToEnemy=' .. iDistToEnemy)
                            end
                        end
                        if bIsSafe == true then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': No nearby enemies or underwater, will now check ACUs health and if its trying to heal')
                            end
                            local iCurrentHealth = oACU:GetHealth()
                            local bACUNearBase = false
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]=' .. repru(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) .. '; M27Overseer.iDistanceFromBaseToBeSafe=' .. M27Overseer.iDistanceFromBaseToBeSafe .. '; tACUPos=' .. repru(tACUPos) .. '; ACU health %=' .. M27UnitInfo.GetUnitHealthPercent(oACU) .. '; dist wanted from base=' .. math.min(150, math.max(M27Overseer.iDistanceFromBaseToBeSafe, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.25)))
                            end

                            local iACUDistToBase = M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                            if iACUDistToBase <= M27Overseer.iDistanceFromBaseToBeSafe or (M27UnitInfo.GetUnitHealthPercent(oACU) >= 0.75 and iACUDistToBase <= math.min(150, math.max(M27Overseer.iDistanceFromBaseToBeSafe, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.25))) then
                                bACUNearBase = true
                            elseif M27Utilities.GetDistanceBetweenPositions(tACUPos, M27Logic.GetNearestRallyPoint(aiBrain, tACUPos, oACU)) <= math.min(10, M27Overseer.iDistanceFromBaseToBeSafe * 0.5) then
                                --Treat ACU as though it's near our base if its close to a rally point
                                bACUNearBase = true
                            end
                            if iCurrentHealth <= aiBrain[M27Overseer.refiACUHealthToRunOn] and bACUNearBase == false then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': ACU health is ' .. iCurrentHealth .. '; Health to run on=' .. aiBrain[M27Overseer.refiACUHealthToRunOn])
                                end
                                bIsSafe = false
                            elseif oACU.PlatoonHandle and oACU.PlatoonHandle[M27PlatoonUtilities.refbNeedToHeal] and bACUNearBase == false then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': ACU platoon is flagged that it needs to heal so not safe to get gun')
                                end
                                bIsSafe = false
                            elseif M27UnitInfo.GetUnitHealthPercent(oACU) <= M27Overseer.iACUEmergencyHealthPercentThreshold then
                                if bACUNearBase then
                                    if iACUDistToBase > M27Overseer.iDistanceFromBaseWhenVeryLowHealthToBeSafe then
                                        bIsSafe = false
                                    end
                                else
                                    bIsSafe = false
                                end
                            end
                            if bIsSafe == false then
                                --Check if we have mobile shields nearby and are on our side of the map
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Not safe under normal checks, but if underwater and not vulnerable to navy then may still be save. bAreUnderwater=' .. tostring(bAreUnderwater) .. '; aiBrain[M27AirOverseer.refiTorpBombersWanted]=' .. (aiBrain[M27AirOverseer.refiTorpBombersWanted] or 0) .. '; Time since last took unseen damage=' .. (GetGameTimeSeconds() - oACU[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage]) >= 30)
                                end
                                if oACU.PlatoonHandle and HaveNearbyMobileShield(oACU.PlatoonHandle) and M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) and M27UnitInfo.GetUnitHealthPercent(oACU) <= M27Overseer.iACUEmergencyHealthPercentThreshold * 0.8 then
                                    bIsSafe = true
                                elseif bAreUnderwater and aiBrain[M27AirOverseer.refiTorpBombersWanted] < 3 and (bFirstUpgrade or (aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][2] + aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][3]) == 0) then
                                    local iTimeSinceTookUnseenDamage = (GetGameTimeSeconds() - (oACU[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage] or -1000))
                                    if iTimeSinceTookUnseenDamage >= 30 or (iTimeSinceTookUnseenDamage >= 10 and aiBrain[M27AirOverseer.refiTorpBombersWanted] <= 0 and (not (M27UnitInfo.IsUnitValid(oACU[M27Overseer.refoUnitDealingUnseenDamage])) or not (EntityCategoryContains(categories.ANTINAVY, oACU[M27Overseer.refoUnitDealingUnseenDamage].UnitId)))) then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Underwater and been a while since took damage so will treat as being safe')
                                        end
                                        bIsSafe = true
                                    end
                                end
                            end
                            if bIsSafe == true then
                                --Check are either underwater, near base, or our shots wont be blocked if we upgrade
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': CHecking if ACU is underwater or (if not) if its shot is blocked')
                                end
                                if not (bACUNearBase) and not (bAreUnderwater) then
                                    local iIntervalDegrees = 30
                                    local iMaxInterval = 180
                                    local iChecks = math.ceil(iMaxInterval / iIntervalDegrees)
                                    local iAngleToEnemy = M27Utilities.GetAngleFromAToB(tACUPos, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                                    local iBaseAngle = -iMaxInterval / 2 + iAngleToEnemy
                                    local iCurAngle

                                    local iDistanceFromACU = 22

                                    if DoesACUHaveGun(aiBrain, false, oACU) then
                                        iDistanceFromACU = 30
                                    end
                                    local tCurPositionToCheck
                                    local iHeightFromGround = 0.6
                                    --function DoesACUHaveGun(aiBrain, bROFAndRange, oAltACU)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Checking if any shots are blocked by ACU before decide whether to upgrade')
                                        M27Utilities.DrawLocation(tACUPos, nil, 1)
                                    end

                                    local iBlockedShots = 0
                                    local iMaxBlockedShots = math.min(3, iChecks * 0.35) --If a third of shots are blocked dont want to upgrade here
                                    for iCurCheck = 0, iChecks do
                                        iCurAngle = iBaseAngle + iIntervalDegrees * iCurCheck
                                        if iCurAngle > 360 then
                                            iCurAngle = iCurAngle - 360
                                        elseif iCurAngle < 0 then
                                            iCurAngle = iCurAngle + 360
                                        end
                                        --MoveInDirection(tStart, iAngle, iDistance)
                                        tCurPositionToCheck = M27Utilities.MoveInDirection(tACUPos, iCurAngle, iDistanceFromACU) --uses surfaceheight for y
                                        tCurPositionToCheck[2] = tCurPositionToCheck[2] + iHeightFromGround
                                        if bDebugMessages == true then
                                            M27Utilities.DrawLocation(tCurPositionToCheck, nil, 2)
                                            LOG(sFunctionRef .. ': tCurPositionToCheck=' .. repru(tCurPositionToCheck) .. '; iCurCheck=' .. iCurCheck)
                                        end

                                        if M27Logic.IsLineBlocked(aiBrain, tACUPos, tCurPositionToCheck) then
                                            iBlockedShots = iBlockedShots + 1
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': expect a shot is blocked, iBlockedShots=' .. iBlockedShots .. '; iMaxBlockedShots=' .. iMaxBlockedShots)
                                            end
                                            if iBlockedShots >= iMaxBlockedShots then
                                                bIsSafe = false
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                            if bIsSafe == true then
                                --Check not taken damage recently from unseen enemy
                                if oACU[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage] and GetGameTimeSeconds() - oACU[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage] <= 20 then
                                    local oUnseenDamageDealer = oACU[M27Overseer.refoUnitDealingUnseenDamage]
                                    if oUnseenDamageDealer and not (oUnseenDamageDealer.Dead) and oUnseenDamageDealer.GetUnitId then
                                        if M27Logic.GetUnitMaxGroundRange({ oUnseenDamageDealer }) >= 35 or EntityCategoryContains(M27UnitInfo.refCategoryTorpedoLandAndNavy, oUnseenDamageDealer.UnitId) then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': ACU taken unseem damage from a unit with a range of at least 35 so want to run')
                                            end
                                            bIsSafe = false
                                        end
                                    end
                                end
                            end
                            if bIsSafe == true then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Will check for nearby PD, T2 arti and TML unless are underwater')
                                end
                                --Check no enemy T2 arti or T3 PD nearby, or TML
                                if not (M27UnitInfo.IsUnitUnderwater(oACU)) then
                                    --Is enemy ACU near us?
                                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if enemy ACU nearby, aiBrain[M27Overseer.refbEnemyACUNearOurs]='..tostring(aiBrain[M27Overseer.refbEnemyACUNearOurs])..'; Dist to nearest ACU='..M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), aiBrain[M27Overseer.refoLastNearestACU]:GetPosition())) end
                                    if aiBrain[M27Overseer.refbEnemyACUNearOurs] or (aiBrain[M27Overseer.refoLastNearestACU] and M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), aiBrain[M27Overseer.refoLastNearestACU]:GetPosition()) <= 90) then
                                        bIsSafe = false
                                    else
                                        tNearbyEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryPD * categories.TECH3 + M27UnitInfo.refCategoryFixedT2Arti, tACUPos, 128, 'Enemy')
                                        bIsSafe = M27Utilities.IsTableEmpty(tNearbyEnemies)
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': bIsSafe after checking for nearby enemies=' .. tostring(bIsSafe))
                                        end
                                        if bIsSafe and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyTML]) == false then
                                            local iTMLInRange = 0
                                            for iUnit, oUnit in aiBrain[M27Overseer.reftEnemyTML] do
                                                if EntityCategoryContains(M27UnitInfo.refCategoryTML, oUnit.UnitId) and M27Utilities.GetDistanceBetweenPositions(tACUPos, oUnit:GetPosition()) <= 259 then
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': In range of TML')
                                                    end
                                                    iTMLInRange = iTMLInRange + 1
                                                    if iTMLInRange >= 2 then
                                                        bIsSafe = false
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
                elseif bDebugMessages == true then
                    LOG(sFunctionRef .. ': Want to run from big threat')
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of check, bIsSafe=' .. tostring(bIsSafe))
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bIsSafe
end

function CanWeStopProtectingACU(aiBrain, oACU)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CanWeStopProtectingACU'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local bStopProtecting = false
    local iCurTime = math.floor(GetGameTimeSeconds())
    if not(aiBrain[M27Overseer.refbEnemyACUNearOurs]) then
        if DoesACUHaveGun(aiBrain, false, oACU) and M27UnitInfo.GetUnitHealthPercent(oACU) >= 0.5 then
            bStopProtecting = true
        elseif M27UnitInfo.GetUnitHealthPercent(oACU) >= 0.8 and not(oACU:IsUnitState('Upgrading')) and not(oACU.GetWorkProgress and oACU:GetWorkProgress() > 0 and oACU:GetWorkProgress() < 1) and not(oACU.PlatoonHandle[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionUpgrade) then
            bStopProtecting = true
        elseif M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= M27Overseer.iDistanceFromBaseToBeSafe then
            bStopProtecting = true
        elseif oACU[M27Overseer.reftACURecentHealth][iCurTime - 30] < (oACU[M27Overseer.reftACURecentHealth][iCurTime] or oACU[M27Overseer.reftACURecentHealth][iCurTime-1] or oACU[M27Overseer.reftACURecentHealth][iCurTime-2] or oACU[M27Overseer.reftACURecentHealth][iCurTime-3] or 0) and M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, oACU:GetPosition(), 50, 'Enemy')) then
            bStopProtecting = true
        end
    end

    if bDebugMessages == true then LOG(sFunctionRef..': bStopProtecting='..tostring(bStopProtecting)..'; iCurTime='..iCurTime..'; Does ACU have gun='..tostring(DoesACUHaveGun(aiBrain, false, oACU))..'; ACU health%='..M27UnitInfo.GetUnitHealthPercent(oACU)..'; ACU unit state='..M27Logic.GetUnitState(oACU)..'; Dist to base='..M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; Dist to base to be safe='..M27Overseer.iDistanceFromBaseToBeSafe..'; ACU health 30s ago='..(oACU[M27Overseer.reftACURecentHealth][iCurTime - 30] or 'nil')..'; ACU cur health='..(oACU[M27Overseer.reftACURecentHealth][iCurTime] or oACU[M27Overseer.reftACURecentHealth][iCurTime-1] or oACU[M27Overseer.reftACURecentHealth][iCurTime-2] or oACU[M27Overseer.reftACURecentHealth][iCurTime-3] or 'nil')..'; Dist to enemy base='..M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))..'; Is table of enemy nearby units empty='..tostring(M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, oACU:GetPosition(), 50, 'Enemy')))..'; aiBrain[M27Overseer.refbEnemyACUNearOurs]='..tostring((aiBrain[M27Overseer.refbEnemyACUNearOurs] or false))) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bStopProtecting
end


function NoEnemyUnitsNearACU(aiBrain, iMaxSearchRange, iMinSearchRange)
    --Need to have iMinSearchRange intel available (unless we have a land scout within 2 of the ACU), and will look up to iMaxSearchRange
    local sFunctionRef = 'NoEnemyUnitsNearACU'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oACU = M27Utilities.GetACU(aiBrain)
    local tACUPos = oACU:GetPosition()
    local bNoEnemyUnits = true
    local bHaveIntelCoverage = false
    --Do we have a nearby scout, or if not do we have intel coverage of the position?

    if (oACU[M27Overseer.refoScoutHelper] and M27Utilities.GetDistanceBetweenPositions(M27PlatoonUtilities.GetPlatoonFrontPosition(oACU[M27Overseer.refoScoutHelper]), tACUPos) <= math.max(2, M27Utilities.GetACU(aiBrain)[M27Overseer.refoScoutHelper][M27PlatoonUtilities.refoFrontUnit]:GetBlueprint().Intel.RadarRadius - iMinSearchRange)) or M27Logic.GetIntelCoverageOfPosition(aiBrain, tACUPos, iMinSearchRange) == true then bHaveIntelCoverage = true end
    if bHaveIntelCoverage == false then bNoEnemyUnits = false
    else
        local tNearbyEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryDangerousToLand, tACUPos, iMaxSearchRange, 'Enemy')
        bNoEnemyUnits = M27Utilities.IsTableEmpty(tNearbyEnemies)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bNoEnemyUnits
end

function HaveEnoughGrossIncomeToForceFirstUpgrade(aiBrain)
    if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 4 and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] >= 60 then
        return true
    else
        if aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 375 and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] and aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 3 and (aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] >= 50 or (aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] >= 40 and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyLandRush)) then
            return true
        else
            return false
        end
    end
end


function WantToGetFirstACUUpgrade(aiBrain, bIgnoreEnemies)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'WantToGetFirstACUUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Returns true if meet all the conditions that mean will want gun upgrade
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    if bIgnoreEnemies == nil then bIgnoreEnemies = false end
    local bWantToGetGun = true
    local iGrossEnergyIncome
    if GetGameTimeSeconds() < 60 then bWantToGetGun = false
    else
        if not(M27Utilities.IsACU(M27Utilities.GetACU(aiBrain))) then bWantToGetGun = false
        else
            if ACUShouldRunFromBigThreat(aiBrain) then
                bWantToGetGun = false
            else
                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle and aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 1.4 and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] >= 26 and (M27Utilities.GetACU(aiBrain):GetHealth() >= 7500 or M27Utilities.GetDistanceBetweenPositions(M27Utilities.GetACU(aiBrain):GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= M27Overseer.iDistanceFromBaseToBeSafe) and
                        (aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] >= 40 or
                                (M27Utilities.GetDistanceBetweenPositions(M27Utilities.GetACU(aiBrain):GetPosition(), aiBrain[M27MapInfo.reftChokepointBuildLocation]) <= 50 and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] >= 34) or
                                (M27Utilities.GetDistanceBetweenPositions(M27Utilities.GetACU(aiBrain):GetPosition(), aiBrain[M27MapInfo.reftChokepointBuildLocation]) <= 20 and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] >= 28)) then
                    return true
                else
                    bWantToGetGun = false
                    if HaveEnoughGrossIncomeToForceFirstUpgrade(aiBrain) and (M27Utilities.GetDistanceBetweenPositions(M27Utilities.GetACU(aiBrain):GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 150 or M27Utilities.GetDistanceBetweenPositions(M27Utilities.GetACU(aiBrain):GetPosition(), M27Logic.GetNearestRallyPoint(aiBrain, M27Utilities.GetACU(aiBrain):GetPosition())) <= 30) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have enough income to force upgrade and not far from base/rally point. Gross energy='..aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome]..'; Gross mass='..aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome]..'; Strategy='..aiBrain[M27Overseer.refiAIBrainCurrentStrategy]) end
                        bWantToGetGun = true
                    else
                        local iResourceThresholdAdjustFactor = 1
                        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance or aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] >= 700 or not (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]) or (not (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand]) and aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] >= 450) then
                            iResourceThresholdAdjustFactor = 2.5
                        elseif M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]) == false or (aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] > 1 and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] < 75) then
                            iResourceThresholdAdjustFactor = 1.5
                        elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
                            iResourceThresholdAdjustFactor = 1.3
                        end

                        if aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 400 and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] then
                            iResourceThresholdAdjustFactor = iResourceThresholdAdjustFactor * 0.9
                            local iDistToBase = M27Utilities.GetDistanceBetweenPositions(M27Utilities.GetACU(aiBrain):GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                            local iCloseDist = math.min(150, math.max(M27Overseer.iDistanceFromBaseToBeSafe, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.25))
                            if iDistToBase <= iCloseDist then
                                iResourceThresholdAdjustFactor = iResourceThresholdAdjustFactor * 0.9
                            end
                            if M27UnitInfo.GetUnitHealthPercent(M27Utilities.GetACU(aiBrain)) <= 0.8 and (M27UnitInfo.GetUnitHealthPercent(M27Utilities.GetACU(aiBrain)) >= 0.5 or iDistToBase <= iCloseDist) then iResourceThresholdAdjustFactor = math.max(0.75, iResourceThresholdAdjustFactor * 0.9) end
                        end

                        --Reduce resource factor if enemy already getting upgrade
                        if M27Team.tTeamData[aiBrain.M27Team][M27Team.refbEnemyTeamHasUpgrade] then iResourceThresholdAdjustFactor = iResourceThresholdAdjustFactor * 0.8 end


                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': GrowwEnergyIncome=' .. aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] .. '; Netincome=' .. aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome] .. '; Net income based on trend=' .. aiBrain:GetEconomyTrend('ENERGY') .. '; EnergyStored=' .. aiBrain:GetEconomyStored('ENERGY')..'; iResourceThresholdAdjustFactor='..iResourceThresholdAdjustFactor..'; ACU health%'..M27UnitInfo.GetUnitHealthPercent(M27Utilities.GetACU(aiBrain))..'; Dist from ACU to our base='..M27Utilities.GetDistanceBetweenPositions(M27Utilities.GetACU(aiBrain):GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; Close distance='..math.min(150, math.max(M27Overseer.iDistanceFromBaseToBeSafe, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.25)))
                        end
                        if aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome] < 120 * 0.1 * iResourceThresholdAdjustFactor then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Net energy income is too low, only get gun if we have lots of energy stored')
                            end
                            if aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome] >= 0 and aiBrain:GetEconomyStored('ENERGY') >= 9000 and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] > 55 * iResourceThresholdAdjustFactor then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Have small net energy income and 9k stored and 550+ gross income so will ugprade anyway')
                                end
                                bWantToGetGun = true
                            else
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Dont have enough gross and stored to ris upgrading')
                                end
                                bWantToGetGun = false
                            end
                        else
                            if aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome] < 170 * 0.1 * iResourceThresholdAdjustFactor and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] < 500 * 0.1 * iResourceThresholdAdjustFactor then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Energy net income < 170 per second and gross < 500 per second so dont want to proceed')
                                end
                                bWantToGetGun = false
                            else
                                iGrossEnergyIncome = aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome]
                                if iGrossEnergyIncome < 45 * iResourceThresholdAdjustFactor then
                                    --450 per second
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Gross income is <45 so dont want to ugprade unless have alot stored')
                                    end
                                    bWantToGetGun = false
                                    if iGrossEnergyIncome > 33 * iResourceThresholdAdjustFactor and aiBrain:GetEconomyStored('ENERGY') > 8000 then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Have alot of energy stored so will proceed with upgrade')
                                        end
                                        bWantToGetGun = true
                                    end
                                else
                                    if iGrossEnergyIncome > 55 * iResourceThresholdAdjustFactor then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Have decent gross income so will proceed')
                                        end
                                        bWantToGetGun = true
                                    elseif aiBrain:GetEconomyStored('ENERGY') >= 5000 * iResourceThresholdAdjustFactor then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Have decent stored energy so will proceed')
                                        end
                                        bWantToGetGun = true
                                    else
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Gross and stored energy not enough to proceed')
                                        end
                                    end
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': bWantToGetGun=' .. tostring(bWantToGetGun) .. '; will now check if its safe to get gun')
                                end
                                if bWantToGetGun == true and bIgnoreEnemies == false and SafeToGetACUUpgrade(aiBrain) == false then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Its not safe to get gun upgrade')
                                    end
                                    bWantToGetGun = false
                                end
                            end
                        end
                    end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..'; Finished main checks, bWantToGetGun='..tostring(bWantToGetGun)) end
        end
    end
    --Adjust based on what strategy we are using
    if bWantToGetGun then
        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
            if aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.8 or aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome] < 10 then bWantToGetGun = false end
        elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
            if bDebugMessages == true then LOG(sFunctionRef..': Are ecoing so check we have enough power both now and if we start building a t2 pgen. Energy ratio='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; Net energy income='..aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome]..'; Gross energy income='..aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome]) end
            if (aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.8 and aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome] <= 22.5) or (aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome] < 10 and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] <= 125) or aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] < 75 then
                --Are we about to start on a T2 PGen? If so then hold off on upgrade
                if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]) == false or aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] > 1 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Are ecoing and likely to start building a T2 Pgen so hold off so we dont powerstall unless enemy start position is close adn we think we have enough power to force an upgrade and we have no T2 engis yet') end
                    if HaveEnoughGrossIncomeToForceFirstUpgrade(aiBrain) and (aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome] > 0 or aiBrain:GetEconomyStoredRatio('ENERGY') >= 1) and (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyLandRush or aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer - categories.TECH1) == 0) then
                        --Still get upgrade
                    else
                        bWantToGetGun = false
                    end
                end
            end
        end
    end

    --Backup check for mod games that have disabled the gun upgrade as an option
    if bWantToGetGun and not(M27PlatoonUtilities.GetACUUpgradeWanted(aiBrain, M27Utilities.GetACU(aiBrain))) then

        if bDebugMessages == true then LOG(sFunctionRef..': Cant find any valid ACU upgrades') end
        bWantToGetGun = false
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, bWantToGetGun='..tostring(bWantToGetGun)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bWantToGetGun
end

function ACUShouldRunFromBigThreat(aiBrain)
    local bRun = false
    if aiBrain[M27Overseer.refbAreBigThreats] then
        local oACU = M27Utilities.GetACU(aiBrain)
        --if M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) > M27Overseer.iDistanceFromBaseToBeSafe and not(oACU:HasEnhancement('CloakingGenerator')) then
        if not(oACU:HasEnhancement('CloakingGenerator')) then
            bRun = true
            local iClosestExperimental = 1000
            local iCurDist
            --Are we near our base and nearest big threat isnt?
            local iDistToBase = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            if iDistToBase <= M27Overseer.iDistanceFromBaseWhenVeryLowHealthToBeSafe then
                bRun = false
            elseif iDistToBase <= M27Overseer.iDistanceFromBaseToBeSafe + 100 or (oACU:GetWorkProgress() >= 0.35 and iDistToBase <= math.min(250, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.4)) then
                if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyLandExperimentals]) then
                    --Not a ground experimental so just want to stay near base
                    bRun = false
                else
                    bRun = false
                    for iUnit, oUnit in aiBrain[M27Overseer.reftEnemyLandExperimentals] do
                        if M27UnitInfo.IsUnitValid(oUnit) then
                            iCurDist = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), oUnit:GetPosition())
                            if iCurDist < iClosestExperimental then iClosestExperimental = iCurDist end
                        end
                    end
                    if iClosestExperimental <= 150 then bRun = true end
                end
            end

            --Are we turtling and have a firebase with significant number of units and we are almost in range of the enemy experimental?
            --LOG('ACUShouldRunFromBigThreat: aiBrain[M27Overseer.refiAIBrainCurrentStrategy]='..aiBrain[M27Overseer.refiAIBrainCurrentStrategy]..'; Chokepoint firebase ref='..(aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef] or 'nil')..';  Size of firebase units='..table.getsize(aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef][aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef]])..'; ACU dist to chokepoint='..M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), aiBrain[M27MapInfo.reftChokepointBuildLocation])..'; Is ACU under friendly fixed shield='..tostring(M27Logic.IsLocationUnderFriendlyFixedShield(aiBrain, oACU:GetPosition()))..'; ACU position='..repru(oACU:GetPosition())..'; Firebase position='..repru(aiBrain[M27MapInfo.reftChokepointBuildLocation])..'; Is target under shield (unit specific)='..tostring(M27Logic.IsTargetUnderShield(aiBrain, oACU, 4000, false, false, false)))
            if bRun and iClosestExperimental <= 40 then
                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef][aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef]]) == false and table.getsize(aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef][aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef]]) >= 8 then
                    local iDistToFirebase = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), aiBrain[M27MapInfo.reftChokepointBuildLocation])
                    if iDistToFirebase <= 40 then
                        --Are we either under a shield; very close to the firebase; or closer to our base than the firebase (meaning hopefully the firebase is between us and the experimental)?
                        if iDistToFirebase <= 10 or M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27MapInfo.reftChokepointBuildLocation]) or M27Logic.IsTargetUnderShield(aiBrain, oACU, 4000, false, false, false) then
                            bRun = false
                        end
                    end
                    --Are we under a shield with nearby PD?
                elseif M27Logic.IsTargetUnderShield(aiBrain, oACU, 4000, false, false, false) then
                    local tNearbyPD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2PlusPD, oACU:GetPosition(), 35, 'Ally')
                    if M27Utilities.IsTableEmpty(tNearbyPD) == false and table.getn(tNearbyPD) >= 5 then
                        bRun = false
                    end
                end
            end
        end
    end
    return bRun
end


function WantToGetAnotherACUUpgrade(aiBrain)
    --Returns 2 variables: true/false if we have eco+safety to get upgrade; also returns true/false if safe to get upgrade
    local sFunctionRef = 'WantToGetAnotherACUUpgrade'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetGameTimeSeconds() >= 1020 and aiBrain:GetArmyIndex() == 1 then bDebugMessages = true end
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local bWantUpgrade = false
    local bSafeToGetUpgrade = true
    if GetGameTimeSeconds() > 60 then
        if aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 then
            local oACU = M27Utilities.GetACU(aiBrain)
            if M27Utilities.IsACU(oACU) and not(ACUShouldRunFromBigThreat(aiBrain)) then
                local sUpgradeRef = M27PlatoonUtilities.GetACUUpgradeWanted(aiBrain, oACU)
                if sUpgradeRef then
                    --Is it a really expensive upgrade?
                    local iACUBuildRate = oACU:GetBuildRate()
                    local oBP = oACU:GetBlueprint()
                    if bDebugMessages == true then LOG(sFunctionRef..': oBP.Enhancements[sUpgradeRef]='..repru(oBP.Enhancements[sUpgradeRef])) end
                    local iUpgradeBuildTime = oBP.Enhancements[sUpgradeRef].BuildTime
                    local iUpgradeEnergyCost = oBP.Enhancements[sUpgradeRef].BuildCostEnergy
                    --Double the energy cost if its really high (so we are less likely to get it)

                    local iEnergyWanted = (iUpgradeEnergyCost / (iUpgradeBuildTime / iACUBuildRate)) * 0.1 * 1.2 --Want slight margin for error in case we're just inbetween building power
                    if iUpgradeEnergyCost >= 250000 then iEnergyWanted = iEnergyWanted * 2 end

                    --Increase threshold if we want to eco, but not if we are turtling
                    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then iEnergyWanted = iEnergyWanted * 2
                    elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle then iEnergyWanted = iEnergyWanted * 0.8
                    end
                    --Aif our ACU isnt going gun due to not pathign to enemy base then wait until we have enough energy to indicate we have T2 power as well
                    if oACU[M27Overseer.refbACUCantPathAwayFromBase] and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] < 100 then iEnergyWanted = math.max(iEnergyWanted, aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome] + 10) end

                    --Be more likely to get an upgrade if we are low health
                    iEnergyWanted = iEnergyWanted * math.max(0.4, oACU:GetHealth() / oACU:GetMaxHealth())





                    if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome]='..aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome]..'; iEnergyWanted='..iEnergyWanted) end
                    if aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome] > iEnergyWanted then
                        --Do we have enough mass? Want this to represent <20% of our total mass income
                        local iUpgradeMassCost = oBP.Enhancements[sUpgradeRef].BuildCostMass
                        --Double the mass cost if its a really expensive upgrade
                        if iUpgradeMassCost >= 2400 then iUpgradeMassCost = iUpgradeMassCost * 2 end
                        local iMassIncomePerTickWanted = iUpgradeMassCost / iUpgradeBuildTime * iACUBuildRate * 0.5 --I.e. if took 10% of this, then that's the mass per tick needed; however we want the mass required for the upgrade to represent <20% of our total mass income
                        --Increase threshold if we want to eco
                        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
                            if M27Utilities.GetACU(aiBrain)[M27Overseer.refbACUCantPathAwayFromBase] then iMassIncomePerTickWanted = iMassIncomePerTickWanted * 4 end
                        elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle then iMassIncomePerTickWanted = iMassIncomePerTickWanted * 0.8
                        end

                        --Be more likely to upgrade if low health
                        iMassIncomePerTickWanted = iMassIncomePerTickWanted * math.max(0.4, oACU:GetHealth() / oACU:GetMaxHealth())


                        if bDebugMessages == true then LOG(sFunctionRef..': Considering if enough mass income to get upgrade; iMassIncomePerTickWanted='..iMassIncomePerTickWanted..'; iUpgradeMassCost='..iUpgradeMassCost..'; iUpgradeBuildTime='..iUpgradeBuildTime..'; iACUBuildRate='..iACUBuildRate..'; aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome]='..aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome]..'; aiBrain:GetEconomyStored(MASS)='..aiBrain:GetEconomyStored('MASS')) end
                        if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= iMassIncomePerTickWanted and aiBrain:GetEconomyStored('MASS') >= 5 then --check we're not massively mass stalling
                            --Do we have good health, and dont have map control?  If so then want to use ACU to attack
                            if bDebugMessages == true then LOG(sFunctionRef..': If have low health or nearby threats wont upgrade; M27UnitInfo.GetUnitHealthPercent(oACU)='..M27UnitInfo.GetUnitHealthPercent(oACU)..'; aiBrain[M27Overseer.refiPercentageOutstandingThreat]='..aiBrain[M27Overseer.refiPercentageOutstandingThreat]..'; aiBrain[M27Overseer.refiModDistFromStartNearestThreat]='..aiBrain[M27Overseer.refiModDistFromStartNearestThreat]..'; aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]) end
                            if M27UnitInfo.GetUnitHealthPercent(oACU) < 0.8 or (aiBrain[M27Overseer.refiPercentageOutstandingThreat] > 0.5 and aiBrain[M27Overseer.refiModDistFromStartNearestThreat] / aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] > 0.3) then
                                --Have enough energy, check if safe to get upgrade
                                local bAbort = false
                                if bDebugMessages == true then LOG(sFunctionRef..': Have enough energy and mass, check its safe to get upgrade') end
                                --Dont treat as being safe if trying to get a slow upgrade and arent on our side of map
                                if (iUpgradeBuildTime / iACUBuildRate) > 150 then --If will take a while then need to be closer to our base than enemy
                                    local iDistToStart = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                    local iDistToEnemy = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                                    if iDistToStart + 75 > iDistToEnemy then
                                        --Abort unless we're close to a rally point and near our side of the map
                                        if bDebugMessages == true then M27Utilities.DrawLocation(M27Logic.GetNearestRallyPoint(aiBrain, oACU:GetPosition(), oACU), nil, 1, 100) end --draw in dark blue
                                        if iDistToStart - 25 > iDistToEnemy or M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27Logic.GetNearestRallyPoint(aiBrain, oACU:GetPosition(), oACU)) > 50 then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Are on enemy side of map, or too far from nearest rally point') end
                                            bAbort = true
                                        end
                                    end
                                end
                                if bAbort then bSafeToGetUpgrade = false
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': Want to get upgrade providing its safe; based on distances it looks ok') end
                                    bSafeToGetUpgrade = SafeToGetACUUpgrade(aiBrain)
                                end
                                if bSafeToGetUpgrade then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Its safe to get upgrade') end
                                    bWantUpgrade = true
                                end
                            end
                        end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': sUpgradeRef is nil so no more upgrades that we want') end
                end
            end
        elseif bDebugMessages == true then LOG(sFunctionRef..': Energy storage too low')
        end
    end
    if bWantUpgrade and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
        if aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.8 or aiBrain[M27EconomyOverseer.refiNetEnergyBaseIncome] < 10 then bWantUpgrade = false end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bWantUpgrade, bSafeToGetUpgrade
end

function HaveLowMass(aiBrain)
    local bHaveLowMass = false
    if aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] <= 200 then --i.e. we dont ahve a paragon or crazy amount of SACUs
        local iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS')
        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle then
            if iMassStoredRatio <= 0.175 or aiBrain:GetEconomyStored('MASS') <= 500 then bHaveLowMass = true
            elseif iMassStoredRatio <= 0.25 and aiBrain[M27EconomyOverseer.refiNetMassBaseIncome] < 0.3 and aiBrain:GetEconomyStored('MASS') <= 1000 then bHaveLowMass = true
            end
        elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyLandRush then
            if iMassStoredRatio < 0.03 and aiBrain:GetEconomyStored('MASS') <= 25 and (aiBrain[M27EconomyOverseer.refiNetMassBaseIncome] < 0 or (aiBrain[M27EconomyOverseer.refiNetMassBaseIncome] < 0.3 and aiBrain:GetEconomyStored('MASS') == 0)) then bHaveLowMass = true end
        else
            if iMassStoredRatio < 0.05 then bHaveLowMass = true
            elseif (iMassStoredRatio < 0.15 or aiBrain:GetEconomyStored('MASS') < 250) and aiBrain[M27EconomyOverseer.refiNetMassBaseIncome] < 0.2 then bHaveLowMass = true
            elseif iMassStoredRatio <= 0.175 and aiBrain[M27Overseer.refbDefendAgainstArti] then bHaveLowMass = true
            end
        end
    end
    return bHaveLowMass
end

function WantMoreMAA(aiBrain, iMassOnMAAVsEnemyAir)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'WantMoreMAA'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
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
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DoesACUHaveBigGun(aiBrain, oAltACU)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DoesACUHaveBigGun'
    local oACU = oAltACU
    if oACU == nil then oACU = M27Utilities.GetACU(aiBrain) end
    if M27Utilities.IsACU(oACU) then
        for iUpgrade, sUpgrade in tBigGunUpgrades do
            if oACU:HasEnhancement(sUpgrade) then
                return true
            end
        end
    end
    return false
end

function DoesACUHaveUpgrade(aiBrain, oAltACU)
    --Returns true if ACU has any upgrade with a mass cost of more than 1
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DoesACUHaveUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oACU = (oAltACU or M27Utilities.GetACU(aiBrain))
    local oBP = oACU:GetBlueprint()
    if M27Utilities.IsTableEmpty(oBP.Enhancements) == false then
        for sEnhancement, tEnhancement in oACU:GetBlueprint().Enhancements do
            if oACU:HasEnhancement(sEnhancement) and tEnhancement.BuildCostMass > 1 then
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return true
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return false
end

function DoesACUHaveGun(aiBrain, bROFAndRange, oAltACU)
    --bROFAndRange: True if want ACU to have both ROFAndRange (only does something for Aeon)
    --UCBC includes simialr code but for some reason referencing it (or using a direct copy) causes error
    --oAltACU - can pass an ACU that's not aiBrain's ACU
    --e.g. need to specify 1 of aiBrain and oAltACU (no need to specify both)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DoesACUHaveGun'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bROFAndRange == nil then bROFAndRange = true end
    local oACU = (oAltACU or M27Utilities.GetACU(aiBrain))
    local bACUHasUpgrade = false
    local iGunUpgradesGot = 0
    local oBP = oACU:GetBlueprint()
    if bDebugMessages == true then LOG(sFunctionRef..': About to check if ACU has gun upgrade') end
    if M27Utilities.IsACU(oACU) then
        for iUpgrade, sUpgrade in tGunUpgrades do
            if bDebugMessages == true then LOG(sFunctionRef..': sUpgrade to check='..sUpgrade..'; oACU:HasEnhancement(sUpgrade)='..tostring(oACU:HasEnhancement(sUpgrade))) end
            if oACU:HasEnhancement(sUpgrade) then
                iGunUpgradesGot = iGunUpgradesGot + 1
                if oBP.Enhancements[sUpgrade].Prerequisite then iGunUpgradesGot = iGunUpgradesGot + 1 end
                if bDebugMessages == true then LOG(sFunctionRef..': ACU has enhancement '..sUpgrade..'; returning true unless Aeon and only 1 upgrade. iGunUpgradesGot='..iGunUpgradesGot..'; bROFAndRange='..tostring((bROFAndRange or false))) end

                if not(bROFAndRange) then
                    bACUHasUpgrade = true
                    break
                else
                    if iGunUpgradesGot >= 2 or not(EntityCategoryContains(categories.AEON, oACU.UnitId)) then
                        bACUHasUpgrade = true
                    end
                end


                --[[if sUpgrade == 'CrysalisBeam' or sUpgrade == 'HeatSink' then
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
                end--]]
            end
        end
        if bACUHasUpgrade == false then bACUHasUpgrade = DoesACUHaveBigGun(aiBrain, oACU) end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of check, bACUHasUpgrade='..tostring(bACUHasUpgrade)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bACUHasUpgrade
end

function HydroNearACUAndBase(aiBrain, bNearBaseOnlyCheck, bAlsoReturnHydroTable, bNotYetBuiltOn, bIncludeEvenIfBuiltOrQueuedByAlly)
    --If further away hydro, considers if its closer to enemy base than start point; returns empty table if no hydro
    --if bAlsoReturnHydroTable == true then returns table of the hydro locations
    --bNotYetBuiltOn - if true, only includes hydro if it's not already built on
    --bIncludeEvenIfBuiltOrQueuedByAlly - if true, includes hydro even if it has been built on or queued to be built on by an ally
    local sFunctionRef = 'HydroNearACUAndBase'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    if bNearBaseOnlyCheck == nil then bNearBaseOnlyCheck = false end
    local iMaxDistanceForHydro = 70 --must be within this distance of start position and ACU
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
            if bDebugMessages == true then LOG(sFunctionRef..': Considering tHydro='..repru(tHydro)..'; Dist to ACU='..M27Utilities.GetDistanceBetweenPositions(tHydro, M27Utilities.GetACU(aiBrain):GetPosition())..'; Dist to start position='..M27Utilities.GetDistanceBetweenPositions(tHydro, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; iMaxDistanceForHydro='..iMaxDistanceForHydro) end
            if bNearBaseOnlyCheck == false then iCurDistanceToACU = M27Utilities.GetDistanceBetweenPositions(tHydro, M27Utilities.GetACU(aiBrain):GetPosition()) end
            if bNearBaseOnlyCheck == true or iCurDistanceToACU <= iMaxDistanceForHydro then
                --InSameSegmentGroup(oUnit, tDestination, bReturnUnitGroupOnly)
                iHydroGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tHydro)
                if bDebugMessages == true then LOG(sFunctionRef..': Hydro pathing group='..iHydroGroup..'; iStartGroup='..iStartGroup) end
                if iStartGroup == iHydroGroup then
                    iDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tHydro, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    if iDistanceToStart <= iMaxDistanceForHydro then
                        if bDebugMessages == true then LOG(sFunctionRef..': Is table of uncliamed hydros containing just this hydro empty='..tostring(M27Utilities.IsTableEmpty(M27EngineerOverseer.FilterLocationsBasedOnIfUnclaimed(aiBrain, { tHydro }, false)))) end
                        --Norush active - check if hydro is in range of norush
                        if not(M27MapInfo.bNoRushActive) or iDistanceToStart + 0.5 < M27MapInfo.iNoRushRange then
                            if not(bNotYetBuiltOn) or M27Utilities.IsTableEmpty(M27EngineerOverseer.FilterLocationsBasedOnIfUnclaimed(aiBrain, { tHydro }, false)) == false then
                                --IsMexOrHydroUnclaimed(aiBrain, tResourcePosition, bMexNotHydro, bTreatEnemyBuildingAsUnclaimed, bTreatOurOrAllyBuildingAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed, bTreatAllyBuildingAsClaimed)
                                if bIncludeEvenIfBuiltOrQueuedByAlly or IsMexOrHydroUnclaimed(aiBrain, tHydro, false, false, true, true, true) then

                                    bHydroNear = true
                                    if bAlsoReturnHydroTable == false then
                                        break
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': Have a valid hydro location') end
                                        iValidHydroCount = iValidHydroCount + 1
                                        tValidHydro[iValidHydroCount] = tHydro
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bHydroNear, tValidHydro
end

function ACUShouldAssistEarlyHydro(aiBrain)
    local bHydroNearStart = HydroNearACUAndBase(aiBrain)
    local bACUShouldAssist = false
    if bHydroNearStart and GetGameTimeSeconds() <= 200 then bACUShouldAssist = true end
    return bACUShouldAssist
end

function CanUnitUseOvercharge(aiBrain, oUnit)
    --For now checks if enough energy and not underwater and not fired in last 5s; separate function used as may want to expand this with rate of fire check in future
    local sFunctionRef = 'CanUnitUseOvercharge'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local oBP = oUnit:GetBlueprint()
    local iEnergyNeeded
    local bCanUseOC = false
    if GetGameTimeSeconds() - (oUnit[M27UnitInfo.refiTimeOfLastOverchargeShot] or -100) >= 5 then
        for iWeapon, oWeapon in oBP.Weapon do
            if oWeapon.OverChargeWeapon then
                if oWeapon.EnergyRequired then
                    iEnergyNeeded = oWeapon.EnergyRequired
                    break
                end
            end
        end

        if aiBrain:GetEconomyStored('ENERGY') >= iEnergyNeeded then bCanUseOC = true end
        if bDebugMessages == true then LOG(sFunctionRef..': iEnergyNeeded='..iEnergyNeeded..'; aiBrain:GetEconomyStored='..aiBrain:GetEconomyStored('ENERGY')..'; bCanUseOC='..tostring(bCanUseOC)) end
        if bCanUseOC == true then
            --Check if underwater
            local oUnitPosition = oUnit:GetPosition()
            local iHeightAtWhichConsideredUnderwater = M27MapInfo.IsUnderwater(oUnitPosition, true) + 0.25 --small margin of error
            local tFiringPositionStart = M27Logic.GetDirectFireWeaponPosition(oUnit)
            if tFiringPositionStart then
                local iFiringHeight = tFiringPositionStart[2]
                if iFiringHeight <= iHeightAtWhichConsideredUnderwater then
                    if bDebugMessages == true then LOG(sFunctionRef..': ACU is underwater; iFiringHeight='..iFiringHeight..'; iHeightAtWhichConsideredUnderwater='..iHeightAtWhichConsideredUnderwater) end
                    bCanUseOC = false
                end
            end
        end
    elseif bDebugMessages == true then LOG(sFunctionRef..': Has been less tahn 5s since last overcharged')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
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
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
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

function GetLifetimeBuildCount(aiBrain, category)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetLifetimeBuildCount'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iTotalBuilt = 0
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
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iTotalBuilt
end

function LifetimeBuildCountLessThan(aiBrain, category, iBuiltThreshold)
    if GetLifetimeBuildCount(aiBrain, category) >= iBuiltThreshold then return false else return true end
end

function IsReclaimNearby(tLocation, iAdjacentSegmentSize, iMinTotal, iMinIndividual)
    --Returns true if any nearby adjacent segments have reclaim; to be used as basic check before calling getreclaimablesinrect
    local sFunctionRef = 'IsReclaimNearby'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local iBaseX, iBaseZ = M27MapInfo.GetReclaimSegmentsFromLocation(tLocation)
    for iAdjX = -iAdjacentSegmentSize, iAdjacentSegmentSize do
        for iAdjZ = -iAdjacentSegmentSize, iAdjacentSegmentSize do
            if bDebugMessages == true then
                LOG(sFunctionRef..': X-Z='..iBaseX + iAdjX..'-'..iBaseZ + iAdjZ..'; Location='..repru(tLocation)..'; refReclaimTotalMass='..(M27MapInfo.tReclaimAreas[iBaseX + iAdjX][iBaseZ + iAdjZ][M27MapInfo.refReclaimTotalMass] or 'nil')..'; refReclaimHighestIndividualReclaim='..(M27MapInfo.tReclaimAreas[iBaseX + iAdjX][iBaseZ + iAdjZ][M27MapInfo.refReclaimHighestIndividualReclaim] or 'nil')..'; Location from segment='..repru(M27MapInfo.GetReclaimLocationFromSegment(iBaseX, iBaseZ)))
                if iAdjX == 0 and iAdjZ == 0 then
                    local rRect = Rect((iBaseX - 1) * M27MapInfo.iReclaimSegmentSizeX, (iBaseZ - 1) * M27MapInfo.iReclaimSegmentSizeZ, iBaseX * M27MapInfo.iReclaimSegmentSizeX, iBaseZ * M27MapInfo.iReclaimSegmentSizeZ)
                    local tReclaimables = GetReclaimablesInRect(rRect) --(this is only being used if debugmessages is true)
                    M27Utilities.DrawRectangle(rRect)
                    for iReclaim, oReclaim in tReclaimables do
                        if oReclaim.MaxMassReclaim > 0 and oReclaim.CachePosition then
                            LOG('iReclaim='..iReclaim..'; MaxMassReclaim='..oReclaim.MaxMassReclaim..'; CachePosition='..repru(oReclaim.CachePosition))
                        end
                    end
                end
            end
            if (M27MapInfo.tReclaimAreas[iBaseX + iAdjX][iBaseZ + iAdjZ][M27MapInfo.refReclaimTotalMass] or 0) >= iMinTotal and (not iMinIndividual or (M27MapInfo.tReclaimAreas[iBaseX + iAdjX][iBaseZ + iAdjZ][M27MapInfo.refReclaimHighestIndividualReclaim] or 0) >= iMinIndividual) then
                if bDebugMessages == true then LOG(sFunctionRef..': Have enough reclaim so returning true') end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return true
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': None of locations had enough reclaim so returning false') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return false
end

function IsMexOrHydroUnclaimed(aiBrain, tResourcePosition, bMexNotHydro, bTreatEnemyBuildingAsUnclaimed, bTreatOurOrAllyBuildingAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed, bTreatAllyBuildingAsClaimed)
    --bTreatQueuedBuildingsAsUnclaimed: If set to false, then consideres all planned mex buidlings for engineers and treats them as being claimed
    --bTreatAllyBuildingAsClaimed - if set to true then even if bTreatOurOrAllyBuildingAsUnclaimed is true, we will treat as claimed if an ally has built on it
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsMexOrHydroUnclaimed'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bTreatEnemyBuildingAsUnclaimed == nil then bTreatEnemyBuildingAsUnclaimed = false end
    if bTreatOurOrAllyBuildingAsUnclaimed == nil then bTreatOurOrAllyBuildingAsUnclaimed = false end
    if bTreatQueuedBuildingsAsUnclaimed == nil then bTreatQueuedBuildingsAsUnclaimed = bTreatOurOrAllyBuildingAsUnclaimed end
    local sLocationRef = M27Utilities.ConvertLocationToReference(tResourcePosition)

    if not(aiBrain[M27EngineerOverseer.reftiResourceClaimedStatus][sLocationRef]) then
        aiBrain[M27EngineerOverseer.reftiResourceClaimedStatus][sLocationRef] = {}
        aiBrain[M27EngineerOverseer.reftiResourceClaimedStatus][sLocationRef][M27EngineerOverseer.refiResourceStatus] = M27EngineerOverseer.refiStatusAvailable --Available
        aiBrain[M27EngineerOverseer.reftiResourceClaimedStatus][sLocationRef][M27EngineerOverseer.refiTimeOfLastUpdate] = -1000
    end

    local bDontHaveResourceStatus = true
    local iAvailabilityType
    --Refresh every 10 seconds for unavailable mexes, and every time for available mexes
    if aiBrain[M27EngineerOverseer.reftiResourceClaimedStatus][sLocationRef][M27EngineerOverseer.refiResourceStatus] == M27EngineerOverseer.refiStatusAvailable or GetGameTimeSeconds() - aiBrain[M27EngineerOverseer.reftiResourceClaimedStatus][sLocationRef][M27EngineerOverseer.refiTimeOfLastUpdate] >= 10 then
        aiBrain[M27EngineerOverseer.reftiResourceClaimedStatus][sLocationRef][M27EngineerOverseer.refiTimeOfLastUpdate] = GetGameTimeSeconds()
        iAvailabilityType = M27EngineerOverseer.refiStatusAvailable --Available

        local iBuildingSizeRadius = 0.5

        if bMexNotHydro == false then
            iBuildingSizeRadius = M27UnitInfo.GetBuildingSize('UAB1102')[1]*0.5
        else
            --Mex specific - if we just ctrlKd our mex then would have an engi nearby so treat mex as claimed
            if aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation] and aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][M27EngineerOverseer.refActionBuildT3MexOverT2] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][M27EngineerOverseer.refActionBuildT3MexOverT2][sLocationRef]) == false then
                iAvailabilityType = M27EngineerOverseer.refiStatusT3MexQueued
                bDontHaveResourceStatus = false
            end
        end

        if bDontHaveResourceStatus then
            local tNearbyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, tResourcePosition, iBuildingSizeRadius, 'Ally')
            if M27Utilities.IsTableEmpty(tNearbyUnits) == false then
                for iBuilding, oBuilding in tNearbyUnits do
                    if not(oBuilding.Dead) and oBuilding.GetFractionComplete then
                        if oBuilding:GetFractionComplete() >= 1 then
                            if oBuilding:GetAIBrain() == aiBrain then iAvailabilityType = M27EngineerOverseer.refiStatusWeHaveBuilt
                            else
                                iAvailabilityType = M27EngineerOverseer.refiStatusAllyBuilt
                            end
                        else
                            if oBuilding:GetAIBrain() == aiBrain then iAvailabilityType = M27EngineerOverseer.refiStatusWeHavePartBuilt
                            else
                                iAvailabilityType = M27EngineerOverseer.refiStatusAllyPartBuilt
                            end
                        end
                        bDontHaveResourceStatus = false
                        break
                    end
                end
            end
            --Check for enemy units
            if bDontHaveResourceStatus then
                tNearbyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, tResourcePosition, iBuildingSizeRadius, 'Enemy')
                for iBuilding, oBuilding in tNearbyUnits do
                    if not(oBuilding.Dead) and oBuilding.GetFractionComplete then
                        iAvailabilityType = M27EngineerOverseer.refiStatusEnemyBuilt
                        bDontHaveResourceStatus = false
                        break
                    end
                end
            end
            if bDontHaveResourceStatus then
                --Check for queued units
                for iBrain, oBrain in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] do
                    if M27Utilities.IsTableEmpty(oBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef]) == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have queued something for sLocationRef='..sLocationRef..'; checking if any builders are still alive') end
                        --Check that any queued engineer is still alive
                        local oBuilder
                        local bClearedSomething = false
                        for iActionRef, tSubtable in oBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef] do
                            if M27Utilities.IsTableEmpty(tSubtable) == false then
                                for iUniqueRef, oBuilder in oBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef][iActionRef] do
                                    if oBuilder.Dead then
                                        if bDebugMessages == true then LOG(sFunctionRef..': oBuilder for iAction='..iActionRef..' is dead so clearing its actions') end
                                        M27EngineerOverseer.ClearEngineerActionTrackers(oBrain, oBuilder)
                                        bClearedSomething = true
                                    else
                                        bDontHaveResourceStatus = false
                                        iAvailabilityType = M27EngineerOverseer.refiStatusQueued
                                        break
                                    end
                                end
                            end
                        end
                        if bClearedSomething == true and bDontHaveResourceStatus == true then
                            if bDebugMessages == true then LOG(sFunctionRef..': Resource was claimed but all builders are dead so treating as unclaimed') end
                        end
                    end
                    if iAvailabilityType == M27EngineerOverseer.refiStatusQueued then break end
                end
            end
            --If still not found status then will go with default (i.e. treat it as available)
        end
    else
        iAvailabilityType = aiBrain[M27EngineerOverseer.reftiResourceClaimedStatus][sLocationRef][M27EngineerOverseer.refiResourceStatus]
    end
    --Decide if its uncalimed or not based on availability type
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if iAvailabilityType == M27EngineerOverseer.refiStatusEnemyBuilt then
        return bTreatEnemyBuildingAsUnclaimed
    elseif iAvailabilityType == M27EngineerOverseer.refiStatusAllyBuilt then
        if bTreatAllyBuildingAsClaimed then return false
        else return bTreatOurOrAllyBuildingAsUnclaimed
        end
    elseif iAvailabilityType == M27EngineerOverseer.refiStatusAllyPartBuilt then
        if bTreatAllyBuildingAsClaimed then return false
        else
            --Want to treat as claimed if we have fully built on it, or if we are part-built and have an engineer queued up to build; if part built and no engi queued then treat as unclaimed
            return M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef])
        end
    elseif iAvailabilityType == M27EngineerOverseer.refiStatusWeHaveBuilt then
        return bTreatOurOrAllyBuildingAsUnclaimed
    elseif iAvailabilityType == M27EngineerOverseer.refiStatusWeHavePartBuilt then
        if bTreatOurOrAllyBuildingAsUnclaimed then return true
        else
            --Want to treat as claimed if we have fully built on it, or if we are part-built and have an engineer queued up to build; if part built and no engi queued then treat as unclaimed
            return M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][sLocationRef])
        end
    elseif iAvailabilityType == M27EngineerOverseer.refiStatusQueued then
        return bTreatQueuedBuildingsAsUnclaimed
    elseif iAvailabilityType == M27EngineerOverseer.refiStatusT3MexQueued then
        return false
    elseif iAvailabilityType == M27EngineerOverseer.refiStatusAvailable then
        return true
    else M27Utilities.ErrorHandler('Unrecognised iAvailabilityType='..(iAvailabilityType or 'nil')..' for sLocationRef='..sLocationRef..'; tResourcePosition='..repru(tResourcePosition)..'; will return true')
        return true
    end
end

function IsHydroUnclaimed(aiBrain, tHydroPosition, bTreatEnemyBuildingAsUnclaimed, bTreatOurOrAllyBuildingAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
    return IsMexOrHydroUnclaimed(aiBrain, tResourcePosition, false, bTreatEnemyBuildingAsUnclaimed, bTreatOurOrAllyBuildingAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
end
function IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
    --IsMexOrHydroUnclaimed(aiBrain, tResourcePosition, bMexNotHydro, bTreatEnemyBuildingAsUnclaimed, bTreatOurOrAllyBuildingAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
    return IsMexOrHydroUnclaimed(aiBrain, tMexPosition, true, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
    --[[
    --bTreatQueuedBuildingsAsUnclaimed: If set to true, then consideres all planned mex buidlings for engineers and treats them as being claimed
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
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
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsLocationWithinIntelPathLine'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bWithinIntelLine = false
    if aiBrain[M27Overseer.refbIntelPathsGenerated] == true then
        local iIntelPathPosition = aiBrain[M27Overseer.refiCurIntelLineTarget]
        if iIntelPathPosition then
            local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]

            local tEnemyStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
            local iLocationDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tEnemyStartPosition, tLocation)
            if bDebugMessages == true then LOG(sFunctionRef..': tLocation='..repru(tLocation)..'; iLocationDistanceToEnemy='..iLocationDistanceToEnemy..'; iDistanceFromStartToEnemy='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]..'; tEnemyStartPosition='..repru(tEnemyStartPosition)..'; tStartPosition='..repru(tStartPosition)) end
            if iLocationDistanceToEnemy > aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] then
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
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bWithinIntelLine
end
function IsLocationWithinDefenceCoverage(aiBrain, tLocation)
    --Returns true if tLocation is within defence coverage range
    local sFunctionRef = 'IsLocationWithinDefenceCoverage'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bWithinCoverage = false
    local iDefenceCoverage = aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat]
    local iModDistanceFromStart = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tLocation)
    if iModDistanceFromStart <= iDefenceCoverage then bWithinCoverage = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bWithinCoverage
end

function IsLocationNearEnemyOmniRange(aiBrain, tLocation, iMinDistanceOutsideOmniToNotBeInRange)
    local sFunctionRef = 'IsLocationNearEnemyOmniRange'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Highest omni range is 200 (omni sensor)
    local tEnemyOmniUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryUnitsWithOmni, tLocation, iMinDistanceOutsideOmniToNotBeInRange + 201, 'Enemy')
    local bOmniNearby = false
    local iCurOmni, iCurDistanceToLocation
    if M27Utilities.IsTableEmpty(tEnemyOmniUnits) == false then
        for iUnit, oUnit in tEnemyOmniUnits do
            if M27UnitInfo.IsUnitValid(oUnit) then
                iCurDistanceToLocation = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tLocation)
                iCurOmni = (oUnit:GetBlueprint().Intel.OmniRadius or 0)
                if bDebugMessages == true then LOG(sFunctionRef..': Considering if oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' with omni radius '..iCurOmni..' and distance to location of '..iCurDistanceToLocation..'; is too close to location '..repru(tLocation)..'; iMinDistanceOutsideOmniToNotBeInRange='..iMinDistanceOutsideOmniToNotBeInRange) end
                if (iCurOmni + iMinDistanceOutsideOmniToNotBeInRange - iCurDistanceToLocation) > 0 then
                    bOmniNearby = true
                    break
                end
            end
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bOmniNearby
end

function IsBuildingWantedForAdjacency(oUnit)
    --NOTE: Suggested that if use this, the unit gets M27EconomyOverseer.refbWantForAdjacency set to true, and only call this when it's false
    --If is a powerplant, check if adjacent to T2 or T3 arti
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsBuildingWantedForAdjacency'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local bWantForAdjacency = false
    if EntityCategoryContains(M27UnitInfo.refCategoryPower, oUnit.UnitId) then
        local iBuildingRadius = oUnit:GetBlueprint().Physics.SkirtSizeX
        --Check for T2 first
        --Do rect of units
        local tAdjacent2x2Buildings = GetUnitsInRect(Rect(oUnit:GetPosition()[1]-iBuildingRadius - 1.1, oUnit:GetPosition()[3]-iBuildingRadius - 1.1, oUnit:GetPosition()[1]+iBuildingRadius + 1.1, oUnit:GetPosition()[3]+iBuildingRadius + 1.1))
        if M27Utilities.IsTableEmpty(tAdjacent2x2Buildings) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedT2Arti, tAdjacent2x2Buildings)) == false then
            bWantForAdjacency = true
        else
            local tAdjacent8x8Buildings = GetUnitsInRect(Rect(oUnit:GetPosition()[1]-iBuildingRadius - 4.1, oUnit:GetPosition()[3]-iBuildingRadius - 4.1, oUnit:GetPosition()[1]+iBuildingRadius + 4.1, oUnit:GetPosition()[3]+iBuildingRadius + 4.1))
            if bDebugMessages == true then LOG(sFunctionRef..': Checking if any units in a rectangle around '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iBuildingRadius='..iBuildingRadius..'; Unitposition='..repru(oUnit:GetPosition())..'; is tAdjacent8x8Buildings empty='..tostring(M27Utilities.IsTableEmpty(tAdjacent8x8Buildings))) end
            if M27Utilities.IsTableEmpty(tAdjacent8x8Buildings) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategoryExperimentalArti * categories.STRUCTURE, tAdjacent8x8Buildings)) == false then
                bWantForAdjacency = true
            elseif bDebugMessages == true then LOG(sFunctionRef..': No T3 arti in tAdjacent8x8Buildings')
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bWantForAdjacency
end

function AreAllChokepointsCoveredByTeam(aiBrain)
    --Returns true if every chokepoint on map has an aiBrain assigned whose strategy is to defend it
    local bCovered = false
    if not(M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27MapInfo.tiPlannedChokepointsByDistFromStart])) then
        local iChokepoints = table.getsize(M27Team.tTeamData[aiBrain.M27Team][M27MapInfo.tiPlannedChokepointsByDistFromStart])
        local iCoveredChokepoints = 0
        for iBrain, oBrain in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] do
            if oBrain[M27Overseer.refiDefaultStrategy] == M27Overseer.refStrategyTurtle then
                if oBrain[M27MapInfo.refiAssignedChokepointFirebaseRef] then
                    iCoveredChokepoints = iCoveredChokepoints + 1
                    --allow 10m for ACU to setup at a chokepoint if ACU is near the chokepoint, and no enemies nearby
                elseif oBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle and GetGameTimeSeconds() <= 600 then
                    local oAssignedACU = M27Utilities.GetACU(oBrain)
                    if GetGameTimeSeconds() <= 300 or (M27UnitInfo.IsUnitValid(oAssignedACU) and M27UnitInfo.GetUnitHealthPercent(oAssignedACU) >= 0.99 and M27Utilities.GetDistanceBetweenPositions(oAssignedACU:GetPosition(), oBrain[M27MapInfo.reftChokepointBuildLocation])  <= 40 and (oAssignedACU.PlatoonHandle[M27PlatoonUtilities.refiEnemiesInRange] or 0) <= 2) then
                        iCoveredChokepoints = iCoveredChokepoints + 1
                    end
                end
            end
        end
        if iCoveredChokepoints >= iChokepoints then bCovered = true end
    end
    return bCovered
end

function HaveApproachingLandExperimentalThreat(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'HaveApproachingLandExperimentalThreat'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Is nearest land experimental valid='..tostring(M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoNearestRangeAdjustedLandExperimental]))..'; Nearest distance adjusted for range='..(aiBrain[M27Overseer.refiNearestRangeAdjustedLandExperimental] or 'nil')..'; Distance threshold='..math.max(180, math.min(300, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.55))) end
    if M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoNearestRangeAdjustedLandExperimental]) and aiBrain[M27Overseer.refiNearestRangeAdjustedLandExperimental] <= math.max(180, math.min(300, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.55)) then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return true
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return false
end
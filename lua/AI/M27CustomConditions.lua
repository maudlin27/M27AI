local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27EconomyOverseer = import('/mods/M27AI/lua/AI/M27EconomyOverseer.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')

tGunUpgrades = { 'HeavyAntiMatterCannon',
                       'CrysalisBeam', --Range
                       'HeatSink', --Aeon
                       'CoolingUpgrade',
                       'RateOfFire'
}
tBigGunUpgrades = { 'MicrowaveLaserGenerator',
                    'BlastAttack'
}

function SafeToUpgradeUnit(oUnit)
    --Intended e.g. for mexes to decide whether to upgrade
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'SafeToUpgradeUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Can the unit be upgraded?
    local bNoNearbyEnemies = false
    local aiBrain = oUnit:GetAIBrain()
    local oUnitBP = oUnit:GetBlueprint()
    local sUpgradesTo = oUnitBP.General.UpgradesTo
    local iCurRadarRange, oCurBlueprint
    local iDistanceToBaseThatIsSafe = 40 --treat as safe even if enemies within this distance
    local iMinScoutRange = 15 --treated as intel coverage if have a land scout within this range
    local iEnemySearchRange = 90 --look for enemies within this range
    local iMinIntelRange = 40 --Need a radar with at least this much intel to treat as having intel coverage

    if sUpgradesTo and not(sUpgradesTo == '') then
        local tUnitLocation = oUnit:GetPosition()
        if M27Utilities.GetDistanceBetweenPositions(tUnitLocation, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iDistanceToBaseThatIsSafe then bNoNearbyEnemies = true
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

                bNoNearbyEnemies = M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAllNonAirScoutUnits, tUnitLocation, iEnemySearchRange, 'Enemy'))
                if bNoNearbyEnemies == false then
                    --Exception - Unit is ACU with gun with low enemy threat and have shield coverage and high health
                    if oUnit.PlatoonHandle and M27Utilities.IsACU(oUnit) then
                        local oPlatoon = oUnit.PlatoonHandle
                        if oPlatoon[M27PlatoonUtilities.refbACUInPlatoon] and oUnit:GetHealthPercent() > 0.8 and DoesACUHaveGun(aiBrain, false, oUnit) and DoesPlatoonWantAnotherMobileShield(oPlatoon, 200, false) == false then
                            bNoNearbyEnemies = true
                        end
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bNoNearbyEnemies
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
        if DoesACUHaveGun(aiBrain, false) then iDistanceToBaseThatIsSafe = iDistanceToBaseThatIsSafe + 50 end
        local tACUPos = M27Utilities.GetACU(aiBrain):GetPosition()
        if M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iDistanceToBaseThatIsSafe then
            if bDebugMessages == true then LOG(sFunctionRef..': Are close to our start so will treat it as being safe') end
            bIsSafe = true
        else
            --Have we been losing health quickly?
            local oACU = M27Utilities.GetACU(aiBrain)
            local iCurTime = math.floor(GetGameTimeSeconds())

            --Have we taken at least 1k damage over our regen rate in last 20s?
            if (oACU[M27Overseer.reftACURecentHealth][iCurTime-20] or 0) - (oACU[M27Overseer.reftACURecentHealth][iCurTime] or 0) > 1000 then
                bIsSafe = false --Redundancy
            else
                if bDebugMessages == true then LOG(sFunctionRef..': About to check if have intel coverage of iSearchRange='..iSearchRange..' for ACU position repr='..repr(tACUPos)) end
                --Does ACU have an assigned scout that is nearby, or does it have sufficient intel coverage
                local tNearbyEnemies

                --Are we either underwater, or are a cloaked ACU not in enemy omni range?
                if M27UnitInfo.IsUnitUnderwater(oACU) or (oACU:HasEnhancement('CloakingGenerator') and not(IsLocationNearEnemyOmniRange(aiBrain, oACU:GetPosition(), 3))) then bIsSafe = true
                else
                    --Are we near to enemy base and not near ours?
                    local iDistToEnemy = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
                    if iDistToEnemy > 90 or iDistToEnemy > M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then
                        local bNearbyScout = false
                        if oACU[M27Overseer.refoScoutHelper] and M27UnitInfo.IsUnitValid(oACU[M27Overseer.refoScoutHelper][M27PlatoonUtilities.refoFrontUnit]) and M27Utilities.GetDistanceBetweenPositions(M27PlatoonUtilities.GetPlatoonFrontPosition(oACU[M27Overseer.refoScoutHelper]), tACUPos) <= math.max(8, oACU[M27Overseer.refoScoutHelper][M27PlatoonUtilities.refoFrontUnit]:GetBlueprint().Intel.RadarRadius - iSearchRange) then bNearbyScout = true end
                        if bNearbyScout or M27Logic.GetIntelCoverageOfPosition(aiBrain, tACUPos, iSearchRange) == true then
                            --Are there enemies near the ACU with a threat value?
                            tNearbyEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAllNonAirScoutUnits, tACUPos, iSearchRange, 'Enemy')
                            local iThreat = M27Logic.GetCombatThreatRating(aiBrain, tNearbyEnemies, true, nil, 50)
                            if iThreat <= 150 then bIsSafe = true end
                            if bDebugMessages == true then LOG(sFunctionRef..': Have intel coverage, iThreat='..iThreat..'; bIsSafe='..tostring(bIsSafe)) end
                        elseif bDebugMessages == true then
                            LOG(sFunctionRef..': Dont have intel coverage of ACU')
                            if oACU[M27Overseer.refoScoutHelper] then
                                LOG('Distance of assigned scout to ACU='..M27Utilities.GetDistanceBetweenPositions(M27PlatoonUtilities.GetPlatoonFrontPosition(oACU[M27Overseer.refoScoutHelper]), tACUPos))
                            else
                                LOG('Scout helper isnt a valid platoon')
                            end
                        end
                    elseif bDebugMessages == true then LOG(sFunctionRef..': iDistToEnemy='..iDistToEnemy)
                    end
                end
                if bIsSafe == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': No nearby enemies, will now check ACUs health and if its trying to heal') end
                    local iCurrentHealth = oACU:GetHealth()
                    local bACUNearBase = false
                    if bDebugMessages == true then LOG(sFunctionRef..': M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]='..repr(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])..'; M27Overseer.iDistanceFromBaseToBeSafe='..M27Overseer.iDistanceFromBaseToBeSafe..'; tACUPos='..repr(tACUPos)) end

                    local iACUDistToBase = M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    if iACUDistToBase <= M27Overseer.iDistanceFromBaseToBeSafe then bACUNearBase = true
                    elseif M27Utilities.GetDistanceBetweenPositions(tACUPos, M27Logic.GetNearestRallyPoint(aiBrain, tACUPos)) <= math.min(10, M27Overseer.iDistanceFromBaseToBeSafe * 0.5) then
                        --Treat ACU as though it's near our base if its close to a rally point
                        bACUNearBase = true
                    end
                    if iCurrentHealth <= aiBrain[M27Overseer.refiACUHealthToRunOn] and bACUNearBase == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': ACU health is '..iCurrentHealth..'; Health to run on='..aiBrain[M27Overseer.refiACUHealthToRunOn]) end
                        bIsSafe = false
                    elseif oACU.PlatoonHandle and oACU.PlatoonHandle[M27PlatoonUtilities.refbNeedToHeal] and bACUNearBase == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': ACU platoon is flagged that it needs to heal so not safe to get gun') end
                        bIsSafe = false
                    elseif oACU:GetHealthPercent() <= M27Overseer.iACUEmergencyHealthPercentThreshold then
                        if bACUNearBase then
                            if iACUDistToBase > M27Overseer.iDistanceFromBaseWhenVeryLowHealthToBeSafe then bIsSafe = false end
                        else bIsSafe = false
                        end
                    end
                    if bIsSafe == false then --Check if we have mobile shields nearby and are on our side of the map
                        if oACU.PlatoonHandle and HaveNearbyMobileShield(oACU.PlatoonHandle) and M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(tACUPos, M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]) and oACU:GetHealthPercent() <= M27Overseer.iACUEmergencyHealthPercentThreshold * 0.8 then
                            bIsSafe = true
                        end
                    end
                    if bIsSafe == true then --Check are either underwater, near base, or our shots wont be blocked if we upgrade
                        if bDebugMessages == true then LOG(sFunctionRef..': CHecking if ACU is underwater or (if not) if its shot is blocked') end
                        if not(bACUNearBase) and not(M27UnitInfo.IsUnitUnderwater(oACU)) then
                            local iIntervalDegrees = 30
                            local iMaxInterval = 180
                            local iChecks = math.ceil(iMaxInterval / iIntervalDegrees)
                            local iAngleToEnemy = M27Utilities.GetAngleFromAToB(tACUPos, M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
                            local iBaseAngle = -iMaxInterval / 2 + iAngleToEnemy
                            local iCurAngle

                            local iDistanceFromACU = 22

                            if DoesACUHaveGun(aiBrain, false, oACU) then iDistanceFromACU = 30 end
                            local tCurPositionToCheck
                            local iHeightFromGround = 0.6
                            --function DoesACUHaveGun(aiBrain, bROFAndRange, oAltACU)
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': Checking if any shots are blocked by ACU before decide whether to upgrade')
                                M27Utilities.DrawLocation(tACUPos, nil, 1)
                            end

                            local iBlockedShots = 0
                            local iMaxBlockedShots = math.min(3, iChecks * 0.35) --If a third of shots are blocked dont want to upgrade here
                            for iCurCheck = 0, iChecks do
                                iCurAngle = iBaseAngle + iIntervalDegrees * iCurCheck
                                if iCurAngle > 360 then iCurAngle = iCurAngle - 360 elseif iCurAngle < 0 then iCurAngle = iCurAngle + 360 end
                                --MoveInDirection(tStart, iAngle, iDistance)
                                tCurPositionToCheck = M27Utilities.MoveInDirection(tACUPos, iCurAngle, iDistanceFromACU) --uses surfaceheight for y
                                tCurPositionToCheck[2] = tCurPositionToCheck[2] + iHeightFromGround
                                if bDebugMessages == true then
                                    M27Utilities.DrawLocation(tCurPositionToCheck, nil, 2)
                                    LOG(sFunctionRef..': tCurPositionToCheck='..repr(tCurPositionToCheck)..'; iCurCheck='..iCurCheck)
                                end


                                if M27Logic.IsLineBlocked(aiBrain, tACUPos, tCurPositionToCheck) then
                                    iBlockedShots = iBlockedShots + 1
                                    if bDebugMessages == true then LOG(sFunctionRef..': expect a shot is blocked, iBlockedShots='..iBlockedShots..'; iMaxBlockedShots='..iMaxBlockedShots) end
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
                            if oUnseenDamageDealer and not(oUnseenDamageDealer.Dead) and oUnseenDamageDealer.GetUnitId then
                                if M27Logic.GetUnitMaxGroundRange({oUnseenDamageDealer}) >= 35 or EntityCategoryContains(M27UnitInfo.refCategoryTorpedoLandAndNavy, oUnseenDamageDealer:GetUnitId()) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': ACU taken unseem damage from a unit with a range of at least 35 so want to run') end
                                    bIsSafe = false
                                end
                            end
                        end
                    end
                    if bIsSafe == true then
                        if bDebugMessages == true then LOG(sFunctionRef..': Will check for nearby PD, T2 arti and TML unless are underwater') end
                        --Check no enemy T2 arti or T3 PD nearby, or TML
                        if not(M27UnitInfo.IsUnitUnderwater(oACU)) then
                            tNearbyEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryPD * categories.TECH3 + M27UnitInfo.refCategoryFixedT2Arti, tACUPos, 128, 'Enemy')
                            bIsSafe = M27Utilities.IsTableEmpty(tNearbyEnemies)
                            if bDebugMessages == true then LOG(sFunctionRef..': bIsSafe after checking for nearby enemies='..tostring(bIsSafe)) end
                            if bIsSafe and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyTML]) == false then
                                local iTMLInRange = 0
                                for iUnit, oUnit in aiBrain[M27Overseer.reftEnemyTML] do
                                    if M27Utilities.GetDistanceBetweenPositions(tACUPos, oUnit:GetPosition()) <= 259 then
                                        if bDebugMessages == true then LOG(sFunctionRef..': In range of TML') end
                                        iTMLInRange = iTMLInRange + 1
                                        if iTMLInRange >= 2 then
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
    if bDebugMessages == true then LOG(sFunctionRef..': End of check, bIsSafe='..tostring(bIsSafe)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bIsSafe
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

function WantToGetGunUpgrade(aiBrain, bIgnoreEnemies)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'WantToGetGunUpgrade'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Returns true if meet all the conditions that mean will want gun upgrade
    if bIgnoreEnemies == nil then bIgnoreEnemies = false end
    local bWantToGetGun = true
    local iGrossEnergyIncome
    if GetGameTimeSeconds() < 60 then bWantToGetGun = false
    else
        if bDebugMessages == true then LOG(sFunctionRef..': GrowwEnergyIncome='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; Netincome='..aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome]..'; Net income based on trend='..aiBrain:GetEconomyTrend('ENERGY')..'; EnergyStored='..aiBrain:GetEconomyStored('ENERGY')) end
        if aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] < 120 * 0.1 then
            if bDebugMessages == true then LOG(sFunctionRef..': Net energy income is too low, only get gun if we have lots of energy stored') end
            if aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] >= 0 and aiBrain:GetEconomyStored('ENERGY') >= 9000 and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] > 55 then
                if bDebugMessages == true then LOG(sFunctionRef..': Have small net energy income and 9k stored and 550+ gross income so will ugprade anyway') end
                bWantToGetGun = true
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Dont have enough gross and stored to ris upgrading') end
                bWantToGetGun = false
            end
        else
            if aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] < 170 * 0.1 and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] < 500 * 0.1 then
                if bDebugMessages == true then LOG(sFunctionRef..': Energy net income < 170 per second and gross < 500 per second so dont want to proceed') end
                bWantToGetGun = false
            else
                iGrossEnergyIncome = aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]
                if iGrossEnergyIncome < 45 then --450 per second
                    if bDebugMessages == true then LOG(sFunctionRef..': Gross income is <45 so dont want to ugprade unless have alot stored') end
                    bWantToGetGun = false
                    if iGrossEnergyIncome > 33 and aiBrain:GetEconomyStored('ENERGY') > 8000 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have alot of energy stored so will proceed with upgrade') end
                        bWantToGetGun = true
                    end
                else
                    if iGrossEnergyIncome > 55 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have decent gross income so will proceed') end
                        bWantToGetGun = true
                    elseif aiBrain:GetEconomyStored('ENERGY') >= 5000 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have decent stored energy so will proceed') end
                        bWantToGetGun = true
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Gross and stored energy not enough to proceed') end
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': bWantToGetGun='..tostring(bWantToGetGun)..'; will now check if its safe to get gun') end
                if bWantToGetGun == true and bIgnoreEnemies == false and SafeToGetACUUpgrade(aiBrain) == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': Its not safe to get gun upgrade') end
                    bWantToGetGun = false
                end
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..'; bWantToGetGun='..tostring(bWantToGetGun)) end
    end
    --Adjust based on what strategy we are using
    if bWantToGetGun then
        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
            if aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.8 or aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] < 10 then bWantToGetGun = false end
        elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
            if aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.8 or aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] < 10 or aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] < 75 then
                --Are we about to start on a T2 PGen? If so then hold off on upgrade
                if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]) == false or aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] > 1 then
                    bWantToGetGun = false
                end
            end
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bWantToGetGun
end

function WantToGetAnotherACUUpgrade(aiBrain)
    --Returns 2 variables: true/false if we have eco+safety to get upgrade; also returns true/false if safe to get upgrade
    local sFunctionRef = 'WantToGetAnotherACUUpgrade'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local bWantUpgrade = false
    local bSafeToGetUpgrade = true
    if GetGameTimeSeconds() > 60 then
        if aiBrain:GetEconomyStoredRatio('ENERGY') > 0.8 then
            local oACU = M27Utilities.GetACU(aiBrain)
            local sUpgradeRef = M27PlatoonUtilities.GetACUUpgradeWanted(aiBrain, oACU)
            if sUpgradeRef then
                local iACUBuildRate = oACU:GetBuildRate()
                local oBP = oACU:GetBlueprint()
                if bDebugMessages == true then LOG(sFunctionRef..': oBP.Enhancements[sUpgradeRef]='..repr(oBP.Enhancements[sUpgradeRef])) end
                local iUpgradeBuildTime = oBP.Enhancements[sUpgradeRef].BuildTime
                local iUpgradeEnergyCost = oBP.Enhancements[sUpgradeRef].BuildCostEnergy
                local iEnergyWanted = (iUpgradeEnergyCost / (iUpgradeBuildTime / iACUBuildRate)) * 0.1
                local iNetEnergyIncome = aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome]
                if bDebugMessages == true then LOG(sFunctionRef..': iNetEnergyIncome='..iNetEnergyIncome..'; iEnergyWanted='..iEnergyWanted) end
                if iNetEnergyIncome > iEnergyWanted then
                    --Do we have enough mass? Want this to represent <10% of our total mass income
                    local iUpgradeMassCost = oBP.Enhancements[sUpgradeRef].BuildCostMass
                    local iMassIncomePerTickWanted = iUpgradeMassCost / iUpgradeBuildTime * iACUBuildRate * 0.1
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering if enough mass income to get upgrade; iMassIncomePerTickWanted='..iMassIncomePerTickWanted..'; iUpgradeMassCost='..iUpgradeMassCost..'; iUpgradeBuildTime='..iUpgradeBuildTime..'; iACUBuildRate='..iACUBuildRate..'; aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]='..aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]..'; aiBrain:GetEconomyStored(MASS)='..aiBrain:GetEconomyStored('MASS')) end
                    if aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= iMassIncomePerTickWanted and aiBrain:GetEconomyStored('MASS') >= 5 then --check we're not massively mass stalling
                        --Have enough energy, check if safe to get upgrade
                        local bAbort = false
                        if bDebugMessages == true then LOG(sFunctionRef..': Have enough energy and mass, check its safe to get upgrade') end
                        --Dont treat as being safe if trying to get a slow upgrade and arent on our side of map
                        if (iUpgradeBuildTime / iACUBuildRate) > 150 then --If will take a while then need to be closer to our base than enemy
                            local iDistToStart = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                            local iDistToEnemy = M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
                            if iDistToStart + 75 > iDistToEnemy then
                                --Abort unless we're close to a rally point and near our side of the map
                                if bDebugMessages == true then M27Utilities.DrawLocation(M27Logic.GetNearestRallyPoint(aiBrain, oACU:GetPosition()), nil, 1, 100) end --draw in dark blue
                                if iDistToStart - 25 > iDistToEnemy or M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27Logic.GetNearestRallyPoint(aiBrain, oACU:GetPosition())) > 50 then
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
            else
                if bDebugMessages == true then LOG(sFunctionRef..': sUpgradeRef is nil so no more upgrades that we want') end
            end
        elseif bDebugMessages == true then LOG(sFunctionRef..': Energy storage too low')
        end
    end
    if bWantUpgrade and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
        if aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.8 or aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] < 10 then bWantUpgrade = false end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bWantUpgrade, bSafeToGetUpgrade
end

function HaveLowMass(aiBrain)
    local bHaveLowMass = false
    local iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS')
    if iMassStoredRatio < 0.05 then bHaveLowMass = true
    elseif (iMassStoredRatio < 0.15 or aiBrain:GetEconomyStored('MASS') < 250) and aiBrain[M27EconomyOverseer.refiMassNetBaseIncome] < 0.2 then bHaveLowMass = true
    elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech and (iMassStoredRatio < 0.1 or (iMassStoredRatio < 0.2 and aiBrain:GetEconomyStored('MASS') < 1000 and aiBrain[M27EconomyOverseer.refiMassNetBaseIncome] < 0.3)) then bHaveLowMass = true
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
    for iUpgrade, sUpgrade in tBigGunUpgrades do
        if oACU:HasEnhancement(sUpgrade) then
            return true
        end
    end
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
    local oACU = oAltACU
    if oACU == nil then oACU = M27Utilities.GetACU(aiBrain) end

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
    if bACUHasUpgrade == false then bACUHasUpgrade = DoesACUHaveBigGun(aiBrain, oACU) end
    if bDebugMessages == true then LOG(sFunctionRef..': End of check, bACUHasUpgrade='..tostring(bACUHasUpgrade)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bACUHasUpgrade
end

function HydroNearACUAndBase(aiBrain, bNearBaseOnlyCheck, bAlsoReturnHydroTable, bNotYetBuiltOn)
    --If further away hydro, considers if its closer to enemy base than start point; returns empty table if no hydro
    --if bAlsoReturnHydroTable == true then returns table of the hydro locations
    --bNotYetBuiltOn - if true, only includes hydro if it's not already built on
    local sFunctionRef = 'HydroNearACUAndBase'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
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
                        if not(bNotYetBuiltOn) or M27Utilities.IsTableEmpty(M27EngineerOverseer.FilterLocationsBasedOnIfUnclaimed(aiBrain, { tHydro }, false)) == false then
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

function LifetimeBuildCountLessThan(aiBrain, category, iBuiltThreshold)
    --Returns true if have built >= iBuiltThreshold
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'LifetimeBuildCountLessThan'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
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
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bBuiltLessThan
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
                LOG(sFunctionRef..': X-Z='..iBaseX + iAdjX..'-'..iBaseZ + iAdjZ..'; Location='..repr(tLocation)..'; refReclaimTotalMass='..(M27MapInfo.tReclaimAreas[iBaseX + iAdjX][iBaseZ + iAdjZ][M27MapInfo.refReclaimTotalMass] or 'nil')..'; refReclaimHighestIndividualReclaim='..(M27MapInfo.tReclaimAreas[iBaseX + iAdjX][iBaseZ + iAdjZ][M27MapInfo.refReclaimHighestIndividualReclaim] or 'nil')..'; Location from segment='..repr(M27MapInfo.GetReclaimLocationFromSegment(iBaseX, iBaseZ)))
                if iAdjX == 0 and iAdjZ == 0 then
                    local rRect = Rect((iBaseX - 1) * M27MapInfo.iReclaimSegmentSizeX, (iBaseZ - 1) * M27MapInfo.iReclaimSegmentSizeZ, iBaseX * M27MapInfo.iReclaimSegmentSizeX, iBaseZ * M27MapInfo.iReclaimSegmentSizeZ)
                    local tReclaimables = GetReclaimablesInRect(rRect)
                    M27Utilities.DrawRectangle(rRect)
                    for iReclaim, oReclaim in tReclaimables do
                        if oReclaim.MaxMassReclaim > 0 and oReclaim.CachePosition then
                            LOG('iReclaim='..iReclaim..'; MaxMassReclaim='..oReclaim.MaxMassReclaim..'; CachePosition='..repr(oReclaim.CachePosition))
                        end
                    end
                end
            end
            if M27MapInfo.tReclaimAreas[iBaseX + iAdjX][iBaseZ + iAdjZ][M27MapInfo.refReclaimTotalMass] >= iMinTotal and (not iMinIndividual or M27MapInfo.tReclaimAreas[iBaseX + iAdjX][iBaseZ + iAdjZ][M27MapInfo.refReclaimHighestIndividualReclaim] >= iMinIndividual) then
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

function IsMexOrHydroUnclaimed(aiBrain, tResourcePosition, bMexNotHydro, bTreatEnemyBuildingAsUnclaimed, bTreatOurOrAllyBuildingAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
    --bTreatQueuedBuildingsAsUnclaimed: If set to false, then consideres all planned mex buidlings for engineers and treats them as being claimed
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsMexOrHydroUnclaimed'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bTreatEnemyBuildingAsUnclaimed == nil then bTreatEnemyBuildingAsUnclaimed = false end
    if bTreatOurOrAllyBuildingAsUnclaimed == nil then bTreatOurOrAllyBuildingAsUnclaimed = false end
    if bTreatQueuedBuildingsAsUnclaimed == nil then bTreatQueuedBuildingsAsUnclaimed = bTreatOurOrAllyBuildingAsUnclaimed end
    local iBuildingSizeRadius = 0.5
    local bResourceIsUnclaimed = true
    local sLocationRef = M27Utilities.ConvertLocationToReference(tResourcePosition)
    if bMexNotHydro == false then
        iBuildingSizeRadius = M27UnitInfo.GetBuildingSize('UAB1102')[1]*0.5
    else
        --Mex specific - if we just ctrlKd our mex then would have an engi nearby so treat mex as claimed
        if aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation] and aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][M27EngineerOverseer.refActionBuildT3MexOverT2] and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftEngineerAssignmentsByLocation][M27EngineerOverseer.refActionBuildT3MexOverT2][sLocationRef]) == false then
            bResourceIsUnclaimed = false
        end
    end

    if bResourceIsUnclaimed then

        local tNearbyAllyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, tResourcePosition, iBuildingSizeRadius, 'Ally')


        if M27Utilities.IsTableEmpty(tNearbyAllyUnits) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Detected an allied building, checking its fractioncomplete') end
            if bTreatOurOrAllyBuildingAsUnclaimed == false then
                --Check if mex is part-built
                for iBuilding, oBuilding in tNearbyAllyUnits do
                    if not(oBuilding.Dead) then
                        if oBuilding.GetFractionComplete then
                            if oBuilding:GetFractionComplete() >= 1 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Fraction complete>=1 so building marked as complete') end
                                bResourceIsUnclaimed = false break end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Fractioncomplete='..oBuilding.GetFractionComplete()) end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': 1 bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
                end

                if bDebugMessages == true then LOG(sFunctionRef..': 2 bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
            else
                if bTreatEnemyBuildingAsUnclaimed == true then bResourceIsUnclaimed = true
                else
                    local tNearbyEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, tResourcePosition, iBuildingSizeRadius, 'Enemy')
                    if M27Utilities.IsTableEmpty(tNearbyEnemyUnits) == false then
                        for iEnemyBuilding, oEnemyBuilding in tNearbyEnemyUnits do
                            if not(oBuilding.Dead) then
                                bResourceIsUnclaimed = false break
                            end
                        end
                    end
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
                local tNearbyEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, tResourcePosition, iBuildingSizeRadius, 'Enemy')
                if M27Utilities.IsTableEmpty(tNearbyEnemyUnits) == false then
                    for iEnemyBuilding, oEnemyBuilding in tNearbyEnemyUnits do
                        if not(oEnemyBuilding.Dead) then
                            bResourceIsUnclaimed = false break
                        end
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': 3d bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': 4 bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)..'; about to check if we should consider building queues bTreatQueuedBuildingsAsUnclaimed='..tostring(bTreatQueuedBuildingsAsUnclaimed)) end
        if bResourceIsUnclaimed == true and bTreatQueuedBuildingsAsUnclaimed == false then
            --Do we have an entry in the mex queue?
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
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End: bResourceIsUnclaimed='..tostring(bResourceIsUnclaimed)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
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

            local iEnemyStartPosition = M27Logic.GetNearestEnemyStartNumber(aiBrain)
            local tEnemyStartPosition = M27MapInfo.PlayerStartPoints[iEnemyStartPosition]
            local iLocationDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tEnemyStartPosition, tLocation)
            if bDebugMessages == true then LOG(sFunctionRef..': tLocation='..repr(tLocation)..'; iLocationDistanceToEnemy='..iLocationDistanceToEnemy..'; iDistanceFromStartToEnemy='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]..'; tEnemyStartPosition='..repr(tEnemyStartPosition)..'; tStartPosition='..repr(tStartPosition)) end
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
                if bDebugMessages == true then LOG(sFunctionRef..': Considering if oUnit='..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' with omni radius '..iCurOmni..' and distance to location of '..iCurDistanceToLocation..'; is too close to location '..repr(tLocation)..'; iMinDistanceOutsideOmniToNotBeInRange='..iMinDistanceOutsideOmniToNotBeInRange) end
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
    if EntityCategoryContains(M27UnitInfo.refCategoryPower, oUnit:GetUnitId()) then
        local iBuildingRadius = oUnit:GetBlueprint().Physics.SkirtSizeX
        --Check for T2 first
        --Do rect of units
        local tAdjacent2x2Buildings = GetUnitsInRect(Rect(oUnit:GetPosition()[1]-iBuildingRadius - 1.1, oUnit:GetPosition()[3]-iBuildingRadius - 1.1, oUnit:GetPosition()[1]+iBuildingRadius + 1.1, oUnit:GetPosition()[3]+iBuildingRadius + 1.1))
        if M27Utilities.IsTableEmpty(tAdjacent2x2Buildings) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedT2Arti, tAdjacent2x2Buildings)) == false then
            bWantForAdjacency = true
        else
            local tAdjacent8x8Buildings = GetUnitsInRect(Rect(oUnit:GetPosition()[1]-iBuildingRadius - 4.1, oUnit:GetPosition()[3]-iBuildingRadius - 4.1, oUnit:GetPosition()[1]+iBuildingRadius + 4.1, oUnit:GetPosition()[3]+iBuildingRadius + 4.1))
            if bDebugMessages == true then LOG(sFunctionRef..': Checking if any units in a rectangle around '..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iBuildingRadius='..iBuildingRadius..'; Unitposition='..repr(oUnit:GetPosition())..'; is tAdjacent8x8Buildings empty='..tostring(M27Utilities.IsTableEmpty(tAdjacent8x8Buildings))) end
            if M27Utilities.IsTableEmpty(tAdjacent8x8Buildings) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedT3Arti, tAdjacent8x8Buildings)) == false then
                bWantForAdjacency = true
            elseif bDebugMessages == true then LOG(sFunctionRef..': No T3 arti in tAdjacent8x8Buildings')
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bWantForAdjacency
end
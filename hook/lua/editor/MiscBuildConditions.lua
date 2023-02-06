--Approx 504 lines in core code
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27ConUtility = import('/mods/M27AI/lua/AI/M27ConstructionUtilities.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')

function M27IsXNearbyMex(aiBrain, bool, iMexNumber)
    --Note: The distance is set to nil to avoid confusion as RecordMexNearStartPosition's distance only matters the first time ever it's called; it's called by aibrain before build conditions, hence whatever number is entered here has no effect
    local iNearbyMex = M27MapInfo.RecordMexNearStartPosition(M27Utilities.GetAIBrainArmyNumber(aiBrain), nil, true, true)

    if iNearbyMex == iMexNumber then return bool
    else return not(bool)
    end
end
function M27IsXPlusNearbyMex(aiBrain, bool, iMexNumber)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local iNearbyMex = M27MapInfo.RecordMexNearStartPosition(M27Utilities.GetAIBrainArmyNumber(aiBrain), nil, true, true)
    if bDebugMessages == true then LOG('M27IsXPlusNearbyMex: iNearbyMex='..iNearbyMex) end
    if iNearbyMex >= iMexNumber then return bool
    else return not(bool)
    end
end

function M27IsNearbyHydro(aiBrain, bool, iMaxDistance)
    --NOTE: Repalced with M27NearbyHydro for decision on whether ACU should help with building hydro instead of t1 power
    --returns true if hydrocarbon is within iMaxDistance of start location; checks every 5s
    local iNearbyHydro = M27MapInfo.RecordHydroNearStartPosition(M27Utilities.GetAIBrainArmyNumber(aiBrain), iMaxDistance, true, true)
    if iNearbyHydro >= 1 then return bool
    else return not(bool) end
end

function M27IsUnclaimedHydro(aiBrain, bool, bOurSideOfMap)
    --returns true if are any unclaimed hydro positions on the map (refreshes every 5s)
    --bOurSideOfMap: true if only consider hydro positions closer to us than enemy
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'M27IsUnclaimedHydro'
    if M27MapInfo.HydroCount > 0 then
        local iLastCheck = aiBrain[sFunctionRef]
        local bRefreshCheck = false
        if iLastCheck == nil then bRefreshCheck = true
        else
            --How long since last refreshed
            local iGameLength = GetGameTimeSeconds()
            if iGameLength - iLastCheck > 5 then bRefreshCheck = true end
        end
        --function GetNumberOfResource (aiBrain, bTrueIfMexFalseIfHydro, bUnclaimedOnly, bVisibleOnly, iType)
        --iType: 1 = mexes nearer to aiBrain than nearest enemy (in future can add more, e.g. entire map; mexes closer to us than ally, etc.)
        if bRefreshCheck then aiBrain[sFunctionRef] = M27MapInfo.GetNumberOfResource(aiBrain, false, true, true, 1) end
        if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[sFunctionRef]='..aiBrain[sFunctionRef]) end

        if aiBrain[sFunctionRef] >= 1 then return bool else return not(bool) end
    else return not(bool)
    end
end

function M27IsNoNearbyHydro(aiBrain, bool, iMaxDistance)
    local iNearbyHydro = M27MapInfo.RecordHydroNearStartPosition(M27Utilities.GetAIBrainArmyNumber(aiBrain), iMaxDistance, true, true)
    if iNearbyHydro <= 0 then return bool else return not(bool) end
end

function M27IsReclaimOnMap(aiBrain, bool, iMinReclaim)
    --Returns true if map has iMinReclaim
    M27MapInfo.UpdateReclaimMarkers() --refreshes reclaim calculation if sufficient time passed since last time called this
    --LOG('M27IsReclaimOnMap condition: iMapTotalMass='..M27MapInfo.iMapTotalMass..'; iMinReclaim='..iMinReclaim)
    if M27MapInfo.iMapTotalMass > iMinReclaim then return bool
    else return not(bool)
    end
end

function M27HydroUnderConstruction(aiBrain, bool)
--Returns true if a hydro is under construction; resets hydro tracker variable if any hydro has been completed
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local iArmy = M27Utilities.GetAIBrainArmyNumber(aiBrain)
    if M27ConUtility.tHydroBuilder[iArmy][1] == nil then
        --LOG('Build condition: Hydro Under construction: Not started yet')
        return not(bool)
    else
        --LOG('Hydro Under construction: In progress or complete')
        --Cycle through hydrocarbons and check if they've completed:
        if M27Utilities.GetNumberOfUnits(aiBrain, categories.STRUCTURE * categories.HYDROCARBON) >= 1 then
            if bDebugMessages == true then LOG('Build condition: Hydro has been constructed, returning false') end
            return not(bool)
        else
            --LOG('Build condition: Hydro is in progress but not yet constructed, returning true')
            return bool
        end
    end
end

function M27MexToFactoryRatio(aiBrain, bool, iMexesPerFactory)
    --Determines no. of mexes / no. of factories; returns true >=iMexesPerFactory
    local iOwnedMexes = M27Utilities.GetNumberOfUnits(aiBrain, categories.STRUCTURE * categories.MASSEXTRACTION)
    local iOwnedFactories = M27Utilities.GetNumberOfUnits(aiBrain, categories.STRUCTURE * categories.FACTORY)
    local iRatio = 0
    if iOwnedMexes == 0 then iRatio = 0
    else
        if iOwnedFactories == 0 then
            iRatio = 10000
        else
            iRatio = iOwnedMexes / iOwnedFactories
        end
    end

    --LOG('M27MexToFactoryRatio: iOwnedMexes='..iOwnedMexes..'; iOwnedFactories='..iOwnedFactories..'; iRatio='..iRatio)
    if iRatio >= iMexesPerFactory then return bool
    else return not(bool) end
end

function M27NeedDefenders(aiBrain, bool)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if bDebugMessages == true then
        if aiBrain[M27Overseer.refbNeedDefenders] == nil then aiBrain[M27Overseer.refbNeedDefenders] = false end
        LOG('MIBC: M27NeedDefenders: aiBrain[M27Overseer.refbNeedDefenders]='..tostring(aiBrain[M27Overseer.refbNeedDefenders])) end
    if aiBrain[M27Overseer.refbNeedDefenders] == true then return bool else return not(bool) end
end

function M27NeedScoutPlatoons(aiBrain, bool)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if bDebugMessages == true then LOG('M27NeedScoutPlatoons: aiBrain[M27Overseer.refbNeedScoutPlatoons]='..tostring(aiBrain[M27Overseer.refbNeedScoutPlatoons])..'; bool='..tostring(bool)) end
    if aiBrain[M27Overseer.refbNeedScoutPlatoons] == true then return bool else return not(bool) end
end
function M27NeedScoutsBuilt(aiBrain, bool)
    local bWantScouts = false
    if aiBrain[refiScoutShortfallInitialRaider] > 0 then bWantScouts = true
        elseif aiBrain[refiScoutShortfallACU] > 0 then bWantScouts = true
        elseif aiBrain[refiScoutShortfallIntelLine] > 0 then bWantScouts = true
        elseif aiBrain[refiScoutShortfallLargePlatoons] > 0 then bWantScouts = true
    end
    --refiScoutShortfallAllPlatoons - not high priority
    if bWantScouts == true then return bool else return not(bool) end
end

function M27NeedMAABuilt(aiBrain, bool, iMassOnMAAVsEnemyAir)
    if M27Conditions.WantMoreMAA(aiBrain, iMassOnMAAVsEnemyAir) == true then return bool else return not(bool) end
end

function M27IsUnclaimedMexNearACU(aiBrain, bool)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if bDebugMessages == true then
        if aiBrain[M27Overseer.refbUnclaimedMexNearACU] == nil then
            LOG('MIBC M27IsUnclaimedMexNearACU: refbUnclaimedMexNearACU=nil')
        else LOG('MIBC M27IsUnclaimedMexNearACU: refbUnclaimedMexNearACU='..tostring(aiBrain[M27Overseer.refbUnclaimedMexNearACU])) end
    end
    if aiBrain[M27Overseer.refbUnclaimedMexNearACU] == true then return bool else return not(bool) end
end

--Removed below and related flag in v15 for performance
--[[function M27IsReclaimNearACU(aiBrain, bool)
    if aiBrain[M27Overseer.refbReclaimNearACU] == true then return bool else return not(bool) end
end--]]

function M27SafeToGetACUUpgrade(aiBrain, bool)

    --[[
    --Determines if its safe for the ACU to get an upgrade
    local bIsSafe = false
    local iSearchRange = 33
    local tACUPos = M27Utilities.GetACU(aiBrain):GetPosition()
    if M27Logic.GetIntelCoverageOfPosition(aiBrain, tACUPos, iSearchRange) == true then
        --Are there enemies near the ACU with a threat value?
        local tNearbyEnemies = aiBrain:GetUnitsAroundPoint(categories.LAND, tACUPos, iSearchRange, 'Enemy')
        local iThreat = M27Logic.GetCombatThreatRating(aiBrain, tNearbyEnemies, true, nil, 50)
        if iThreat <= 15 then bIsSafe = true end
    end
    if bIsSafe == true then return bool else return not(bool) end--]]
    if M27Conditions.SafeToGetACUUpgrade(aiBrain) == true then return bool else return not(bool) end
end

function M27WantACUToGetGunUpgrade(aiBrain, bool)
    if M27Conditions.WantToGetFirstACUUpgrade(aiBrain, false) == true then return bool else return not(bool) end
end

function M27ACUHasGunUpgrade(aiBrain, bool, bBothUpgrades)
    --For some reason referencing this function from elsewhere causes an error, so M27GeneralLogic includes a variant of this
    --Returns true if commander has finished any of the gun upgrades
    --[[
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local oACU = M27Utilities.GetACU(aiBrain)
    local bHasGun = false
    local tGunUpgrades = { 'HeavyAntiMatterCannon',
                           'CrysalisBeam',
                           'HeatSink',
                           'CoolingUpgrade',
                           'RateOfFire'
    }
    for iUpgrade, sUpgrade in tGunUpgrades do
        if oACU:HasEnhancement(sUpgrade) then
            if bDebugMessages == true then LOG('M27ACUHasGunUpgradebHasGun: Returning true') end
            bHasGun = true return bool end
    end
    if bDebugMessages == true then LOG('M27ACUHasGunUpgradebHasGun: No gun upgrades, returning false') end
    return not(bool)]]--
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'M27ACUHasGunUpgrade'
    local bHasGun = M27Conditions.DoesACUHaveGun(aiBrain, bBothUpgrades)
    if bDebugMessages == true then LOG(sFunctionRef..': ACU has gun='..tostring(bHasGun)..'; bool condition='..tostring(bool)) end
    if bHasGun then return bool else return not(bool) end
end

function M27NoEnemiesNearACU(aiBrain, bool, iMaxSearchRange, iMinSearchRange)
    --Need to have iMinSearchRange intel available, and will look up to iMaxSearchRange)
    if M27Conditions.NoEnemyUnitsNearACU(aiBrain, iMaxSearchRange, iMinSearchRange) == true then return bool else return not(bool) end
end

function M27NearbyHydro(aiBrain, bool)
    --Below checks hydro near ACU and that early in the game
    if M27Conditions.ACUShouldAssistEarlyHydro(aiBrain) == true then return bool else return not(bool) end
end

function M27TestReturnFalse(aiBrain, bool)
    return not(bool)
end

function M27TestReturnTrue(aiBrain, bool)
    LOG('M27TestReturnTrue: Returning true')
    return bool
end
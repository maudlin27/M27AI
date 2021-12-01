local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')

function M27LifetimeBuildCountLessThan(aiBrain, bool, category, iBuiltThreshold)
    local bDebugMessages = false
    local iTotalBuilt = 0
    if bDebugMessages == true then LOG('M27LifetimeBuildCountLessThan - start') end
    local testCat = category
    --if type(category) == 'string' then
        --testCat = ParseEntityCategory(category)
    --end
    local tUnitBPIDs = M27Utilities.GetUnitsInFactionCategory(aiBrain, testCat)
    local iCurCount = 0


    --GetUnitsInFactionCategory(aiBrain, category)
    if tUnitBPIDs == nil then
        iTotalBuilt = 0
        if bDebugMessages == true then LOG('LifetimeBuildCount: tUnitBPIDs == nil') end
    else
        if bDebugMessages == true then LOG('LifetimeBuildCount: cycling through tUnitBPIDs') end
        for i1, sBPID in tUnitBPIDs do
            --aiBrain.M27LifetimeUnitCount[sUnitBlueprintID]
            iCurCount = aiBrain.M27LifetimeUnitCount[sBPID]
            if iCurCount == nil then iCurCount = 0 end
            iTotalBuilt = iTotalBuilt + iCurCount
            if bDebugMessages == true then LOG('LifetimeBuildCount: sBPID='..sBPID..'; iCurCount='..iCurCount) end
        end
    end
    if bDebugMessages == true then LOG('LifetimeBuildCount: iTotalBuilt='..iTotalBuilt..'; iBuiltThreshold='..iBuiltThreshold) end
    if iTotalBuilt < iBuiltThreshold then return bool
    else return not(bool)
    end
end

function M27LifetimePlatoonCount(aiBrain, bool, sPlatoonAI, iBuiltThreshold, bLessThan)
    --bLessThan: True if test is whether are less than the number; false if test is greater than
    local bDebugMessages = false
    local sFunctionRef = 'M27LifetimePlatoonCount'
    if bDebugMessages == true then LOG(sFunctionRef..': start') end
    if aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] == nil then aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] = {} end
    local iCurCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount][sPlatoonAI]
    if iCurCount == nil then iCurCount = 0 end
    if bDebugMessages == true then LOG(sFunctionRef..': iCurCount='..iCurCount..'; iBuiltThreshold='..iBuiltThreshold) end


    if iCurCount < iBuiltThreshold then
        if bLessThan == true then return bool else return not(bool) end
    elseif iCurCount > iBuiltThreshold then
        if bLessThan == true then return not(bLessThan) else return bool end
    else return not(bool)
    end
end

function M27LifetimePlatoonCountLessThan(aiBrain, bool, sPlatoonAI, iBuiltThreshold)
    local bDebugMessages = false
    if bDebugMessages == true then LOG('M27LifetimePlatoonCountLessThan - start') end
    if aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] == nil then aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount] = {} end
    local iCurCount = aiBrain[M27PlatoonUtilities.refiLifetimePlatoonCount][sPlatoonAI]
    if iCurCount == nil then iCurCount = 0 end
    if bDebugMessages == true then LOG('M27LifetimePlatoonCountLessThan: iCurCount='..iCurCount..'; iBuiltThreshold='..iBuiltThreshold) end

    if iCurCount < iBuiltThreshold then return bool
    else return not(bool)
    end
end

function M27AtLeastXUnclaimedMexesNearUs(aiBrain, bool, iUnclaimedThreshold)
    --Checks if are iUnclaimedThreshold mexes left that are closer to aiBrain than the enemy; refreshes details of unclaimed mexes every 10s
    local bDebugMessages = false
    local sFunctionRef = 'M27AtLeastXUnclaimedMexesNearUs'
    local iLastCheck = aiBrain[sFunctionRef]
    local bRefreshCheck = false
    if iLastCheck == nil then bRefreshCheck = true
    else
        --How long since last refreshed
        local iGameLength = GetGameTimeSeconds()
        if iGameLength - iLastCheck > 10 then bRefreshCheck = true end
    end
    --function GetNumberOfResource (aiBrain, true, bUnclaimedOnly, bVisibleOnly, iType)
    --iType: 1 = mexes nearer to aiBrain than nearest enemy (in future can add more, e.g. entire map; mexes closer to us than ally, etc.)
    if bRefreshCheck then aiBrain[sFunctionRef] = M27MapInfo.GetNumberOfResource(aiBrain, true, true, true, 1) end
    if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[sFunctionRef]='..aiBrain[sFunctionRef]..'; iUnclaimedThreshold='..iUnclaimedThreshold) end
    if aiBrain[sFunctionRef] >= iUnclaimedThreshold then return bool
    else return not(bool) end
end
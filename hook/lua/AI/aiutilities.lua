--[[local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')

--v63 - removed below due to bug highlighted by Relent0r
local M27EngineerTryReclaimCaptureArea = EngineerTryReclaimCaptureArea
function EngineerTryReclaimCaptureArea(aiBrain, eng, pos, iAreaSize)
    --Reclaims only if within iAreaSize (defaults to size of 1) - although called iAreaSize, it will be based on rectangle, i.e. see if both x and Z co=-ordinates are within iAreaSize of the pos
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if aiBrain.M27AI == false then
        M27EngineerTryReclaimCaptureArea(aiBrain, eng, pos)
    else
        if iAreaSize == nil then iAreaSize = 1 end
        if not pos then
            return false
        end
        local Reclaiming = false
        -- Check if enemy units are at location
        local checkUnits = aiBrain:GetUnitsAroundPoint( (M27UnitInfo.refCategoryStructure + categories.MOBILE) - categories.AIR, pos, iAreaSize, 'Enemy')
        -- reclaim units near our building place.
        if checkUnits and table.getn(checkUnits) > 0 then
            for num, unit in checkUnits do
                if unit.Dead or unit:BeenDestroyed() then
                    -- continue
                end
                if not IsEnemy( aiBrain:GetArmyIndex(), unit:GetAIBrain():GetArmyIndex() ) then
                    -- continue
                end
                if unit:IsCapturable() then
                    -- if we can capture the unit/building then do so
                    unit.CaptureInProgress = true
                    IssueCapture({eng}, unit)
                else
                    -- if we can't capture then reclaim
                    unit.ReclaimInProgress = true
                    IssueReclaim({eng}, unit)
                end
                Reclaiming = true
            end
        end
        -- reclaim rocks etc or we can't build mexes or hydros
        local Reclaimables = GetReclaimablesInRect(Rect(pos[1], pos[3], pos[1], pos[3])) --(dont think we use this function anymore)
        if Reclaimables and table.getn( Reclaimables ) > 0 then
            local ReclaimPos
            for k,v in Reclaimables do
                if v.MaxMassReclaim > 0 or v.MaxEnergyReclaim > 0 then

                    ReclaimPos = v.CachePosition
                    --Check the reclaim position is actually within the target size:
                    if math.abs(ReclaimPos[1]-pos[1]) <= iAreaSize then
                        if math.abs(ReclaimPos[2] - pos[3]) <= iAreaSize then
                            LOG('Issuing reclaim order; pos[1,3]='..pos[1]..'-'..pos[3]..'; ReclaimPos='..ReclaimPos[1]..'-'..ReclaimPos[3])
                            IssueReclaim({eng}, v)
                            Reclaiming = true
                        else
                            if bDebugMessages == true then LOG('Preventing reclaim order as reclaim too far away') end
                        end
                    else
                        if bDebugMessages == true then LOG('Preventing reclaim order as reclaim too far away') end
                    end
                end
            end
        end
        return Reclaiming
    end
end--]]

-- Assist factories based on what factories have less units helping
--[[local M27AIEngineersAssistFactories = AIEngineersAssistFactories
function AIEngineersAssistFactories(aiBrain, engineers, factories)
    if aiBrain.M27AI == false then
        M27AIEngineersAssistFactories(aiBrain, engineers, factories)
    else
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        local sFunctionRef = 'AIEngineersAssistFactories'
        if bDebugMessages == true then LOG(sFunctionRef..':Start of code') end
        local factoryData = {}
        local lowNum, key, value, tempNum, tempActive, setVal

        local active = false
        for _, v in factories do
            if not v.Dead and (v:IsUnitState('Building') or v:GetNumBuildOrders(categories.ALLUNITS) > 0) then
                active = true
                break
            end
        end

        -- Sort Factories based on number of guards
        for i = 1, table.getn(factories) do
            lowNum = false
            key = -1
            value = false
            tempActive = false

            for j, v in factories do
                -- We only want factories that are actively doin stuff and aren\'t like dead
                local guards = v:GetGuards()
                local tempNum = 0
                for n, g in guards do
                    if not EntityCategoryContains(categories.FACTORY, g) then
                        tempNum = tempNum + 1
                    end
                end
                if not v.Dead then
                    setVal = false
                    tempActive = v:IsUnitState('Building') or (v:GetNumBuildOrders(categories.ALLUNITS) > 0)
                    if not active and tempActive then
                        active = true
                        setVal = true
                    elseif active and tempActive and (not lowNum or tempNum < lowNum) then
                        setVal = true
                    elseif not active and not tempActive and (not lowNum or tempNum < lowNum) then
                        setVal = true
                    end
                    if setVal then
                        lowNum = table.getn(v:GetGuards())
                        value = v
                        key = j
                    end
                end
            end
            if key > 0 then
                factoryData[i] = {Factory = value, NumGuards = lowNum}
                table.remove(factories, key)
            end
        end

        -- Find a factory for each engineer and update number of guards
        for unitNum, unit in engineers do
            lowNum = false
            key = 0
            for k, v in factoryData do
                if not lowNum or v.NumGuards < lowNum then
                    lowNum = v.NumGuards
                    key = k
                end
            end

            if lowNum then
                IssueGuard({unit}, factoryData[key].Factory)
                factoryData[key].NumGuards = factoryData[key].NumGuards + 1
            else
                aiBrain:AssignUnitsToPlatoon('ArmyPool', {unit}, 'Unassigned', 'NoFormation')
            end
        end

        return true
    end
end--]]
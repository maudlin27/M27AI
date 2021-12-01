local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
function M27LessThanEnergyIncome(aiBrain, bool, EnergyIncome)
    --Energy economy values are shown at 10% of actual values
    if HaveGreaterThanUnitsWithCategory(aiBrain, 0, 'ENERGYPRODUCTION EXPERIMENTAL STRUCTURE') then return not(bool) end
    if AIUtils.AIGetEconomyNumbers(aiBrain).EnergyIncome < EnergyIncome*0.1 then return bool
        else return not(bool) end
end

function M27GreaterThanEnergyIncome(aiBrain, bool, EnergyIncome)
    local bDebugMessages = false
    local sResource = 'ENERGY'
    if bDebugMessages == true then LOG('M27GreaterThanEnergyIncome='..aiBrain:GetEconomyIncome(sResource)..'; iEnergyIncome='..EnergyIncome) end
    if HaveGreaterThanUnitsWithCategory(aiBrain, 0, 'ENERGYPRODUCTION EXPERIMENTAL STRUCTURE') then return true end
    if aiBrain:GetEconomyIncome(sResource) > EnergyIncome * 0.1 then return bool
    else return not(bool) end
end

function M27ExcessEnergyIncome(aiBrain, bool, iExcessEnergy)
    --returns true if have at least iExcessEnergy; note that GetEconomyTrend returns the 'per tick' excess (so 10% of what is displayed)
    --[[
    local bDebugMessages = false
    local sResource = 'ENERGY'
    if bDebugMessages == true then LOG('M27ExcessEnergyIncome='..aiBrain:GetEconomyTrend(sResource)..'; iExcessEnergy='..iExcessEnergy) end
    if HaveGreaterThanUnitsWithCategory(aiBrain, 0, 'ENERGYPRODUCTION EXPERIMENTAL STRUCTURE') then return bool end
    if aiBrain:GetEconomyTrend(sResource) >= iExcessEnergy*0.1 then return bool else return not(bool) end]]--
    if M27Conditions.HaveExcessEnergy(aiBrain, iExcessEnergy) == true then return bool else return not(bool) end
end

function M27ExcessMassIncome(aiBrain, bool, iExcessResource)
    --returns true if have at least iExcessMass; note that the economy trend will be 10% of what is displayed (so 0.8 excess mass income is displayed in-game as 8 excess mass income) - i.e. presumably it's the 'per tick' excess
    local bDebugMessages = false
    local sResource = 'MASS'
    if bDebugMessages == true then LOG('M27ExcessMassIncome='..aiBrain:GetEconomyTrend(sResource)..'; iExcessCondition='..iExcessResource) end
    if HaveGreaterThanUnitsWithCategory(aiBrain, 0, 'ENERGYPRODUCTION EXPERIMENTAL STRUCTURE') then return bool end
    if aiBrain:GetEconomyTrend(sResource) >= iExcessResource*0.1 then return bool else return not(bool) end
end

function M27ResourceStoredCurrent(aiBrain, bool, bMass, iMinStored)
    local bDebugMessages = false
    local sResource = 'ENERGY'
    if bMass == true then sResource = 'MASS' end
    if bDebugMessages == true then LOG('M27ResourceStoredCurrent: bMass='..tostring(bMass)..'; iMinStoredCondition='..iMinStored..'; sResource='..sResource..'; GetEconomyStored='..aiBrain:GetEconomyStored(sResource)) end
    if aiBrain:GetEconomyStored(sResource) >= iMinStored then return bool else return not(bool) end
end
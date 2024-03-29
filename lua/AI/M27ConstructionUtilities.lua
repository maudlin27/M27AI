--[[local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
tHydroBuilder = {} --[x][y] returns the yth engineer for x army number that is constructing a hydro

function RecordHydroConstructor(aiBrain, oEng)
    local sFunctionRef = 'RecordHydroConstructor'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iArmy = M27Utilities.GetAIBrainArmyNumber(aiBrain)
    local iExistingEngineers = 0
    if tHydroBuilder[iArmy] == nil then tHydroBuilder[iArmy] = {}
    else
        iExistingEngineers = tHydroBuilder[iArmy].getn
        if iExistingEngineers == nil then iExistingEngineers = 0 end
    end

    tHydroBuilder[iArmy][iExistingEngineers + 1] = oEng
    if bDebugMessages == true then LOG('RecordHydroConstructor: Just recorded for iArmy='..iArmy..'; iExistingEngineers+1='..(iExistingEngineers + 1)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end--]]
---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by maudlin27.
--- DateTime: 21/11/2021 19:41
---
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Config = import('/mods/M27AI/lua/M27Config.lua')

--Put anything we want to only run once (not once per aiBrain) below
local M27BeginSession = BeginSession
function BeginSession()
    M27BeginSession()
    --Call anything e.g. profilers
    if M27Config.M27RunSoftlesProfiling then ForkThread(M27Utilities.StartSoftlesProfiling) end
end

local M27OnCreateArmyBrain = OnCreateArmyBrain
function OnCreateArmyBrain(index, brain, name, nickname)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OnCreateArmyBrain'
    if bDebugMessages == true then LOG(sFunctionRef..': name='..name..'; nickname='..nickname..'; index='..index) end
    M27Overseer.tAllAIBrainsByArmyIndex[index] = brain
    --M27Overseer.AnotherAIBrainsBackup[index] = brain
    --if bDebugMessages == true then LOG(sFunctionRef..': Size of AnotherAIBrainsBackup='..table.getn(M27Overseer.AnotherAIBrainsBackup)) end
    M27OnCreateArmyBrain(index, brain, name, nickname)
end

--Approach of hooking to get around adaptive map issues is based on Softels DilliDalli AI - alternative is using CanBuildStructureAt to check, but that runs into issues if the resource point has reclaim on it
local M27CreateResourceDeposit = CreateResourceDeposit
CreateResourceDeposit = function(t,x,y,z,size)
    M27MapInfo.RecordResourcePoint(t,x,y,z,size)
    M27CreateResourceDeposit(t,x,y,z,size)
end
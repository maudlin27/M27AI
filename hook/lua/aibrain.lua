--NOTE: In theory the June 2023 FAF develop changes mean the separate M27Brain and index.lua files should handle brain creation (and if all this is deleted they do), but these were still having effect pre-adding those other codes, have left in for backwards compatibility and just in case
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27Events = import('/mods/M27AI/lua/AI/M27Events.lua')
local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27MiscProfiling = import('/mods/M27AI/lua/MiscProfiling.lua')
local AIUtils = import("/lua/ai/aiutilities.lua")

M27AIBrainClass = AIBrain
AIBrain = Class(M27AIBrainClass) {

    OnDefeat = function(self)
        ForkThread(M27Events.OnPlayerDefeated, self)
        M27AIBrainClass.OnDefeat(self)
    end,

    -- Hook m27AI and record it as being used

    OnCreateAI = function(self, planName)
        local sFunctionRef = 'OnCreateAI'
        local bDebugMessages = false
        if M27Utilities.bGlobalDebugOverride == true then bDebugMessages = true end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ' M27AI: aibrain.lua: OnCreateAI function - before recorded if m27AI. reprs of AI=' .. reprs(self))
        end

        --Set aiBrain attribute on all AIs:
        local iArmyNo = M27Utilities.GetAIBrainArmyNumber(self)
        self.M27StartPositionNumber = iArmyNo

        --Also update other AIs (failsafe)
        for iCurBrain, oBrain in ArmyBrains do
            oBrain.M27StartPositionNumber = M27Utilities.GetAIBrainArmyNumber(oBrain)
        end

        local personality = ScenarioInfo.ArmySetup[self.Name].AIPersonality
        if bDebugMessages == true then
            LOG(sFunctionRef .. '* M27AI: aibrain.lua: personality=' .. personality .. ')')
            LOG(sFunctionRef .. 'Start position number=' .. (iArmyNo or 'nil') .. '; ArmyIndex=' .. self:GetArmyIndex())
        end
        if string.find(personality, 'm27') or string.find(personality, 'M27') then
            if not(self.M27AI) then --We havent run this yet
                local bDebugMode = true

                -- case sensitive
                if bDebugMessages == true then
                    LOG(sFunctionRef .. '* M27AI: personality (' .. personality .. ') is being used by army name: (' .. self.Name .. '); self.M27AI set to true')
                end
                self.M27AI = true
                M27Utilities.bM27AIInGame = true
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': reprs of ScenarioInfo=' .. reprs(ScenarioInfo.Options))
                end

                M27Overseer.tAllActiveM27Brains[self:GetArmyIndex()] = self
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Size of tAllActiveM27Brains=' .. table.getsize(M27Overseer.tAllActiveM27Brains))
                end


                M27AIBrainClass.OnCreateAI(self, planName)

                --Redundancy - enable cheats if not already
                if not(self.CheatEnabled) then
                    local per = ScenarioInfo.ArmySetup[self.Name].AIPersonality
                    local cheatPos = string.find(per, 'cheat')
                    if cheatPos then
                        AIUtils.SetupCheat(self, true)
                        ScenarioInfo.ArmySetup[self.Name].AIPersonality = string.sub(per, 1, cheatPos - 1)
                    end
                end

                ForkThread(M27Overseer.OverseerManager, self)
            else
                M27AIBrainClass.OnCreateAI(self, planName)
            end
        else
            --Flag for swarm so can deal with ythotha cheat
            if string.find(personality, 'swarm') and string.find(self.Nickname, ': Swarm') then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Have a swarm AI')
                end
                self.M27SwarmAI = true
            end
            M27AIBrainClass.OnCreateAI(self, planName)
            ForkThread(M27Overseer.SendWarningIfNoM27, self)
        end
        if M27Config.M27RunGamePerformanceCheck then
            ForkThread(M27MiscProfiling.LogGamePerformanceData)
        end

    end,

    BaseMonitorInitialization = function(self, spec)
        if self.M27AI then
            --Do nothing (so we dont get the message about navmesh not being generated)
        else
            M27AIBrainClass.BaseMonitorInitialization(self, spec)
        end
    end,
}
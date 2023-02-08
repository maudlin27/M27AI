-- 2021-07-09: Base aiBrain is 4057 without UVESO, 4449 lines long with?
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Events = import('/mods/M27AI/lua/AI/M27Events.lua')
local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27MiscProfiling = import('/mods/M27AI/lua/MiscProfiling.lua')

M27AIBrainClass = AIBrain
AIBrain = Class(M27AIBrainClass) {

    OnDefeat = function(self)
        ForkThread(M27Events.OnPlayerDefeated, self)
        M27AIBrainClass.OnDefeat(self)
    end,

    -- Hook m27AI and record it as being used

    OnCreateAI = function(self, planName)
        local sFunctionRef = 'OnCreateAI'
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        if bDebugMessages == true then LOG(sFunctionRef..' M27AI: aibrain.lua: OnCreateAI function - before recorded if m27AI. reprs of AI='..reprs(self)) end

        --Set aiBrain attribute on all AIs:
        local iArmyNo = M27Utilities.GetAIBrainArmyNumber(self)
        self.M27StartPositionNumber = iArmyNo

        --Also update other AIs (failsafe)
        for iCurBrain, oBrain in ArmyBrains do
            oBrain.M27StartPositionNumber = M27Utilities.GetAIBrainArmyNumber(oBrain)
        end

        local personality = ScenarioInfo.ArmySetup[self.Name].AIPersonality
        if bDebugMessages == true then
            LOG(sFunctionRef..'* M27AI: aibrain.lua: personality=' .. personality .. ')')
            LOG(sFunctionRef..'Start position number='..(iArmyNo or 'nil')..'; ArmyIndex='..self:GetArmyIndex())
        end
        if string.find(personality, 'm27') or string.find(personality, 'M27') then
            local bDebugMode = true

            -- case sensitive
            if bDebugMessages == true then LOG(sFunctionRef..'* M27AI: personality (' .. personality .. ') is being used by army name: (' .. self.Name .. '); self.M27AI set to true') end
            self.M27AI = true
            M27Utilities.bM27AIInGame = true
            if bDebugMessages == true then LOG(sFunctionRef..': reprs of ScenarioInfo='..reprs(ScenarioInfo.Options)) end

            M27Overseer.tAllActiveM27Brains[self:GetArmyIndex()] = self
            if bDebugMessages == true then LOG(sFunctionRef..': Size of tAllActiveM27Brains='..table.getsize(M27Overseer.tAllActiveM27Brains)) end

            --self:CreateBrainShared(planName)

            M27AIBrainClass.OnCreateAI(self, planName)

            -- Do the initial AI setup:
            -- local iArmyNo = tonumber(string.sub(self.Name, (string.len(self.Name)-7)))

            --local iBuildDistance = self:GetUnitBlueprint('UAL0001').Economy.MaxBuildDistance
            --if bDebugMessages == true then LOG('* M27AI: iArmyNo='..iArmyNo..'; iBuildDistance='..iBuildDistance) end

            --Moved below to overseer:
            --[[
            M27MapInfo.RecordResourceLocations(self)
            M27MapInfo.RecordPlayerStartLocations()
            M27MapInfo.RecordMexNearStartPosition(iArmyNo, 26) --similar to the range of T1 PD --]]


            -- LOG('* M27AI: M27MapInfo.lua: First mass co-ord x =' ..M27MapInfo.MassPoints[2][1]..'; X of first mex near iArmyNo2='..M27MapInfo.tResourceNearStart[1][2][1][1])
            -- LOG('* M27AI: Non-nil marker position, position[1][1]=' ..M27MapInfo.PlayerStartPoints[1][1]..')')
            -- self.M27MapInfo = M27MapInfo.CreateM27MapInfo(self)
            ForkThread(M27Overseer.OverseerManager, self)
        else
            --Flag for swarm so can deal with ythotha cheat
            if string.find(personality, 'swarm') and string.find(self.Nickname, ': Swarm') then
                if bDebugMessages == true then LOG(sFunctionRef..': Have a swarm AI') end
                self.M27SwarmAI = true
            end
            M27AIBrainClass.OnCreateAI(self, planName)
            ForkThread(M27Overseer.SendWarningIfNoM27, self)
        end
        if M27Config.M27RunGamePerformanceCheck then ForkThread(M27MiscProfiling.LogGamePerformanceData) end

    end,

    BaseMonitorInitialization = function(self, spec)
        if self.M27AI then
            --Do nothing (so we dont get the message about navmesh not being generated)
        else
            M27AIBrainClass.BaseMonitorInitialization(self, spec)
        end
    end,

    --[[InitializeSkirmishSystems = function(self)
        if not(self.M27AI) then M27AIBrainClass.InitializeSkirmishSystems(self)
        else
            local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
            if bDebugMessages == true then LOG('InitializeSkirmishSystems: Hook successful - will icnrease base range from 100 to 1000') end
            --Copy of base code, only change is to expand the range on managers from 100 to 1000
            -- Make sure we don't do anything for the human player!!!
            if self.BrainType == 'Human' then
                return
            end

            -- TURNING OFF AI POOL PLATOON, I MAY JUST REMOVE THAT PLATOON FUNCTIONALITY LATER
            local poolPlatoon = self:GetPlatoonUniquelyNamed('ArmyPool')
            if poolPlatoon then
                poolPlatoon:TurnOffPoolAI()
            end

            -- Stores handles to all builders for quick iteration and updates to all
            self.BuilderHandles = {}

            -- Condition monitor for the whole brain
            self.ConditionsMonitor = BrainConditionsMonitor.CreateConditionsMonitor(self)

            -- Economy monitor for new skirmish - stores out econ over time to get trend over 10 seconds
            self.EconomyData = {}
            self.EconomyTicksMonitor = 50
            self.EconomyCurrentTick = 1
            self.EconomyMonitorThread = self:ForkThread(self.EconomyMonitor)
            self.LowEnergyMode = false

            -- Add default main location and setup the builder managers
            self.NumBases = 0 -- AddBuilderManagers will increase the number

            self.BuilderManagers = {}
            SUtils.AddCustomUnitSupport(self)
            --Base game code line:
            --self:AddBuilderManagers(self:GetStartVector3f(), 100, 'MAIN', false)
            --Hook change to code:

            --self:AddBuilderManagers(self:GetStartVector3f(), 1000, 'MAIN', false)
            local tFarFarAway = {}
            local iMapSizeX, iMapSizeZ = GetMapSize()
            local tStart = self:GetStartVector3f()
            if (iMapSizeX - tStart[1]) > tStart[1] then tFarFarAway[1] = iMapSizeX - 1 else tFarFarAway[1] = 1 end
            if (iMapSizeZ - tStart[3]) > tStart[3] then tFarFarAway[3] = iMapSizeZ - 1 else tFarFarAway[3] = 1 end
            tFarFarAway[2] = GetTerrainHeight(tFarFarAway[1], tFarFarAway[3])
            self:AddBuilderManagers(tFarFarAway, 1, 'MAIN', false)


            -- Begin the base monitor process
            if self.Sorian then
                local spec = {
                    DefaultDistressRange = 200,
                    AlertLevel = 8,
                }
                self:BaseMonitorInitializationSorian(spec)
            else
                self:BaseMonitorInitialization()
            end

            local plat = self:GetPlatoonUniquelyNamed('ArmyPool')
            --]]
    --[[if self.Sorian then
        plat:ForkThread(plat.BaseManagersDistressAISorian)
    else
        plat:ForkThread(plat.BaseManagersDistressAI)
    end]]--
    --[[


    self.DeadBaseThread = self:ForkThread(self.DeadBaseMonitor)
    if self.Sorian then
        self.EnemyPickerThread = self:ForkThread(self.PickEnemySorian)
    else
        self.EnemyPickerThread = self:ForkThread(self.PickEnemy)
    end
end
end,--]]




    --[[PBMCheckBusyFactories = function(self)
        if not(self.M27AI) then
            M27AIBrainClass.PBMCheckBusyFactories(self)
        else
            local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
            local sFunctionRef = 'PBMCheckBusyFactories'
            if bDebugMessages == true then LOG(sFunctionRef..': Code start') end
            local busyPlat = self:GetPlatoonUniquelyNamed('BusyFactories')
            if not busyPlat then
                busyPlat = self:MakePlatoon('', '')
                busyPlat:UniquelyNamePlatoon('BusyFactories')
            end

            local poolPlat = self:GetPlatoonUniquelyNamed('ArmyPool')
            local poolTransfer = {}
            for _, v in poolPlat:GetPlatoonUnits() do
                if not v.Dead and EntityCategoryContains(categories.FACTORY - categories.MOBILE, v) then
                    if v:IsUnitState('Building') or v:IsUnitState('Upgrading') then
                        table.insert(poolTransfer, v)
                    end
                end
            end

            local busyTransfer = {}
            for _, v in busyPlat:GetPlatoonUnits() do
                if not v.Dead and not v:IsUnitState('Building') and not v:IsUnitState('Upgrading') then
                    table.insert(busyTransfer, v)
                end
            end

            self:AssignUnitsToPlatoon(poolPlat, busyTransfer, 'Unassigned', 'None')
            self:AssignUnitsToPlatoon(busyPlat, poolTransfer, 'Unassigned', 'None')
        end
    end,
    --]]




}


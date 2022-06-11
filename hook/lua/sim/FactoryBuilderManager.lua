local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27PlatoonFormer = import('/mods/M27AI/lua/AI/M27PlatoonFormer.lua')
local M27FactoryOverseer = import('/mods/M27AI/lua/AI/M27FactoryOverseer.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')

M27FactoryBuilderManager = FactoryBuilderManager
FactoryBuilderManager = Class(M27FactoryBuilderManager) {
    FactoryFinishBuilding = function(self,factory,finishedUnit)
        if not self.Brain.M27AI then
            M27FactoryBuilderManager.FactoryFinishBuilding(self,factory,finishedUnit)
            if M27Config.M27ShowEnemyUnitNames then M27PlatoonUtilities.UpdateUnitNames({ finishedUnit }, finishedUnit.UnitId, true) end
        else
            if EntityCategoryContains(M27UnitInfo.refCategoryLandFactory, factory) then
                --Do nothing - this function doesnt always trigger so have incorporated a 'unit finished building' test into factory overseer
            else
                factory[M27FactoryOverseer.refoLastUnitBuilt] = finishedUnit
                if M27Config.M27ShowUnitNames == true then M27PlatoonUtilities.UpdateUnitNames({ finishedUnit }, 'SentForAllocation') end

                --Toggle long range on sniper bots:
                if EntityCategoryContains(M27UnitInfo.refCategorySniperBot, finishedUnit.UnitId) then M27UnitInfo.EnableLongRangeSniper(finishedUnit) end

                M27PlatoonFormer.AllocateNewUnitToPlatoonFromFactory(finishedUnit, factory)

                --[[if EntityCategoryContains(categories.ENGINEER, finishedUnit) then
                    self.Brain.BuilderManagers[self.LocationType].EngineerManager:AddUnit(finishedUnit)
                elseif EntityCategoryContains(categories.FACTORY, finishedUnit) then
                    self:AddFactory(finishedUnit)
                end
                self:AssignBuildOrder(factory, factory.BuilderManagerData.BuilderType)--]]
            end
        end
    end,

    SetRallyPoint = function(self, factory)
        local M27bDebugMessages = false
        if M27bDebugMessages == true then LOG('SetRallyPoint: Hook start') end

        if not self.Brain.M27AI then
            if M27bDebugMessages == true then LOG('SetRallyPoint: Not using M27AI') end
            M27FactoryBuilderManager.SetRallyPoint(self, factory)
        else
            if M27bDebugMessages == true then LOG('SetRallyPoint: About to run custom code to set rallypoint') end
            M27Logic.SetFactoryRallyPoint(factory)
        end
    end,
    --RallyPointMonitor = function(self)
        --if not self.Brain.M27AI then
            --LOG('RallyPointMonitor: Not using M27AI')
            --return M27FactoryBuilderManager.RallyPointMonitor(self)
        --else
            --LOG('RallyPointMonitor: Using M27AI')
        --end
    --end,


}
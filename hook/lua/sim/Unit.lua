local M27Events = import('/mods/M27AI/lua/AI/M27Events.lua')


M27Unit = Unit
Unit = Class(M27Unit) {
    OnKilled = function(self, instigator, type, overkillRatio)
        M27Events.OnKilled(self, instigator, type, overkillRatio)
        M27Unit.OnKilled(self, instigator, type, overkillRatio)
    end,
    OnDestroy = function(self)
        M27Events.OnUnitDeath(self) --Any custom code we want to run
        M27Unit.OnDestroy(self) --Normal code
    end,
    OnWorkEnd = function(self, work)
        M27Events.OnWorkEnd(self, work)
        M27Unit.OnWorkEnd(self, work)
    end,
    OnDamage = function(self, instigator, amount, vector, damageType)
        M27Unit.OnDamage(self, instigator, amount, vector, damageType)
        M27Events.OnDamaged(self, instigator) --Want this after just incase our code messes things up
    end,
    OnSiloBuildEnd = function(self, weapon)
        M27Unit.OnSiloBuildEnd(self, weapon)
        M27Events.OnMissileBuilt(self, weapon)
    end,
    OnStartBuild = function(self, built, order)
        M27Unit.OnStartBuild(self, built, order)
        ForkThread(M27Events.OnConstructionStarted, self, built, order)
    end

    --[[CreateEnhancementEffects = function(self, enhancement)
        local bp = self:GetBlueprint().Enhancements[enhancement]
        local effects = TrashBag()
        local bpTime = bp.BuildTime
        local bpBuildCostEnergy = bp.BuildCostEnergy
        if bpTime == nil then LOG('ERROR: CreateEnhancementEffects: bp.bpTime is nil; bp='..self:GetBlueprint().BlueprintId)
            bpTime = 1 end --Avoid infinite loop
        if bpBuildCostEnergy == nil then
            LOG('ERROR: CreateEnhancementEffects: bp.BuildCostEnergy is nil; bp='..self:GetBlueprint().BlueprintId)
            bpBuildCostEnergy = 1 end
        local scale = math.min(4, math.max(1, (bpBuildCostEnergy / bpTime or 1) / 50))

        if bp.UpgradeEffectBones then
            for _, v in bp.UpgradeEffectBones do
                if self:IsValidBone(v) then
                    EffectUtilities.CreateEnhancementEffectAtBone(self, v, self.UpgradeEffectsBag)
                end
            end
        end

        if bp.UpgradeUnitAmbientBones then
            for _, v in bp.UpgradeUnitAmbientBones do
                if self:IsValidBone(v) then
                    EffectUtilities.CreateEnhancementUnitAmbient(self, v, self.UpgradeEffectsBag)
                end
            end
        end

        for _, e in effects do
            e:ScaleEmitter(scale)
            self.UpgradeEffectsBag:Add(e)
        end
    end, ]]--

}
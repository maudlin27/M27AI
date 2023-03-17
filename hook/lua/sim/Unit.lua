local M27Events = import('/mods/M27AI/lua/AI/M27Events.lua')

do --Per Balthazaar - encasing the code in do .... end means that you dont have to worry about using unique variables
    local M27OldUnit = Unit
    Unit = Class(M27OldUnit) {
        OnKilled = function(self, instigator, type, overkillRatio) --NOTE: For some reason this doesnt run a lot of the time; onkilledunit is more reliable
            M27Events.OnKilled(self, instigator, type, overkillRatio)
            M27OldUnit.OnKilled(self, instigator, type, overkillRatio)
        end,
        OnKilledUnit = function(self, unitKilled, massKilled)
            M27Events.OnKilled(unitKilled, self)
            M27OldUnit.OnKilledUnit(self, unitKilled, massKilled)
        end,
        OnDestroy = function(self)
            M27Events.OnUnitDeath(self) --Any custom code we want to run
            M27OldUnit.OnDestroy(self) --Normal code
        end,
        OnWorkEnd = function(self, work)
            M27Events.OnWorkEnd(self, work)
            M27OldUnit.OnWorkEnd(self, work)
        end,
        OnDamage = function(self, instigator, amount, vector, damageType)
            M27OldUnit.OnDamage(self, instigator, amount, vector, damageType)
            M27Events.OnDamaged(self, instigator) --Want this after just incase our code messes things up
        end,
        OnSiloBuildEnd = function(self, weapon)
            M27OldUnit.OnSiloBuildEnd(self, weapon)
            M27Events.OnMissileBuilt(self, weapon)
        end,
        OnStartBuild = function(self, built, order, ...)
            ForkThread(M27Events.OnConstructionStarted, self, built, order)
            return M27OldUnit.OnStartBuild(self, built, order, unpack(arg))
        end,
        OnStartReclaim = function(self, target)
            ForkThread(M27Events.OnReclaimStarted, self, target)
            return M27OldUnit.OnStartReclaim(self, target)
        end,
        OnStopReclaim = function(self, target)
            ForkThread(M27Events.OnReclaimFinished, self, target)
            return M27OldUnit.OnStopReclaim(self, target)
        end,

        OnStopBuild = function(self, unit)
            if unit and not(unit.Dead) and unit.GetFractionComplete and unit:GetFractionComplete() == 1 then ForkThread(M27Events.OnConstructed, self, unit) end
            return M27OldUnit.OnStopBuild(self, unit)
        end,

        OnAttachedToTransport = function(self, transport, bone)
            ForkThread(M27Events.OnTransportLoad, self, transport, bone)
            return M27OldUnit.OnAttachedToTransport(self, transport, bone)
        end,
        OnDetachedFromTransport = function(self, transport, bone)
            ForkThread(M27Events.OnTransportUnload, self, transport, bone)
            return M27OldUnit.OnDetachedFromTransport(self, transport, bone)
        end,
        OnDetectedBy = function(self, index)

            ForkThread(M27Events.OnDetectedBy, self, index)
            return M27OldUnit.OnDetectedBy(self, index)
        end,
        CreateEnhancement = function(self, enh)
            ForkThread(M27Events.OnEnhancementComplete, self, enh)
            return M27OldUnit.CreateEnhancement(self, enh)
        end,

        --[[ Note: As at 2023-03017 there's a bug with the FAF capture callback which Jip confirmed - will be fixed in the next faf development patch/version - revisit at this point
        OnCaptured = function(self, captor)
            M27OldUnit.OnCaptured(self, captor)
            ForkThread(M27Events.OnCaptured, self, captor)
        end,
        AddOnCapturedCallback = function(self, cbOldUnit, cbNewUnit)
            M27OldUnit.AddOnCapturedCallback(self, cbOldUnit, cbNewUnit)
            ForkThread(M27Events.OnCapturedAlt, cbOldUnit, cbNewUnit)
        end,--]]
    }
end


--Hooks not used:
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
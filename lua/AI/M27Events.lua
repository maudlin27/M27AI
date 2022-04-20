---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by maudlin27.
--- DateTime: 08/10/2021 13:05
---

local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27UnitMicro = import('/mods/M27AI/lua/AI/M27UnitMicro.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27PlatoonFormer = import('/mods/M27AI/lua/AI/M27PlatoonFormer.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Config = import('/mods/M27AI/lua/M27Config.lua')


local refCategoryEngineer = M27UnitInfo.refCategoryEngineer
local refCategoryAirScout = M27UnitInfo.refCategoryAirScout


function OnKilled(self, instigator, type, overkillRatio)
    --NOTE: Called by any unit of any player being killed; also note that OnUnitDeath triggers as well as this
    --i.e. this shoudl be used for where only want to get an event where the unit was killed by something
    --Is the unit owned by M27AI?
    if M27Utilities.bM27AIInGame then
        local sFunctionRef = 'OnKilled'
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

        if self.GetAIBrain then
            local aiBrain = self:GetAIBrain()
            if aiBrain.M27AI then
                --were we killed by something?
                local oKillerUnit
                if instigator then
                    if IsUnit(instigator) then
                        oKillerUnit = instigator
                    elseif IsProjectile(instigator) or IsCollisionBeam(instigator) then
                        oKillerUnit = instigator.unit
                    end
                    if oKillerUnit and oKillerUnit.GetAIBrain then
                        M27AirOverseer.CheckForUnseenKiller(aiBrain, self, oKillerUnit)
                    end
                end
            else
                --Decided to remove the below and instead just work off a lower threshold that only increases when we run
                --[[if instigator and IsUnit(instigator) and EntityCategoryContains(M27UnitInfo.refCategoryAirNonScout * categories.EXPERIMENTAL, instigator.UnitId) then
                    local oKillerBrain = instigator:GetAIBrain()
                    if oKillerBrain.M27AI then
                        local iSegmentX, iSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(instigator:GetPosition())
                        for iXAdj = -1, 1 do
                            for iZAdj = -1, 1 do
                                if not(oKillerBrain[M27AirOverseer.reftPreviousTargetByLocationCount][iSegmentX + iXAdj]) then oKillerBrain[M27AirOverseer.reftPreviousTargetByLocationCount][iSegmentX + iXAdj] = {} end
                                oKillerBrain[M27AirOverseer.reftPreviousTargetByLocationCount][iSegmentX+iXAdj][iSegmentZ+iZAdj] = math.max(0,(oKillerBrain[M27AirOverseer.reftPreviousTargetByLocationCount][iSegmentX + iXAdj][iSegmentZ+iZAdj] or 0) - 1)
                            end
                        end
                    end
                end--]]
            end
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
end

function OnMexDeath(oUnit)
    --Make the mex status available
    if M27Utilities.bM27AIInGame then
        local sFunctionRef = 'OnMexDeath'
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

        local sLocationRef = M27Utilities.ConvertLocationToStringRef(oUnit:GetPosition())
        for iRefBrain, aiBrain in M27Overseer.tAllActiveM27Brains do
            if aiBrain[M27EngineerOverseer.reftiResourceClaimedStatus][sLocationRef] then
                aiBrain[M27EngineerOverseer.reftiResourceClaimedStatus][sLocationRef][M27EngineerOverseer.refiResourceStatus] = M27EngineerOverseer.refiStatusAvailable
            end
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
end

function OnPropDestroyed(oProp)
    --Confirmed manually this triggers e.g. if a bomber destroys a rock, and if a tree is reclaimed
    if M27Utilities.bM27AIInGame then
        local sFunctionRef = 'OnUnitDeath'
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        if oProp.CachePosition then
            if bDebugMessages == true then
                LOG(sFunctionRef..': Prop destroyed hook successful; will debug array and then update reclaim at the location '..repr(oProp.CachePosition)..' drawing red rectangle around cahce position')
                M27Utilities.DrawLocation(oProp.CachePosition, nil, 2, 100, nil)
                M27Utilities.DebugArray(oProp)
            end

            ForkThread(M27MapInfo.RecordThatWeWantToUpdateReclaimAtLocation, oProp.CachePosition, 0)
        end

        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
end


function OnUnitDeath(oUnit)
    --NOTE: This is called by the death of any unit of any player, so careful with what commands are given
    if M27Utilities.bM27AIInGame then
        local sFunctionRef = 'OnUnitDeath'
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

        if bDebugMessages == true then LOG(sFunctionRef..'Hook successful') end
        --Is it an ACU?
        if M27Utilities.IsACU(oUnit) then
            M27Overseer.iACUDeathCount = M27Overseer.iACUDeathCount + 1
            LOG(sFunctionRef..' ACU kill detected; total kills='..M27Overseer.iACUDeathCount)
            --Update list of brains
            local oACUBrain = oUnit:GetAIBrain()
            if ScenarioInfo.Options.Victory == "demoralization" then
                M27Utilities.ErrorHandler('ACU has died for brain='..oACUBrain:GetArmyIndex()..'; are in assassination so will flag the brain is defeated', true)
                oACUBrain.M27IsDefeated = true
            end

            for iArmyIndex, aiBrain in M27Overseer.tAllAIBrainsByArmyIndex do
                if aiBrain == oACUBrain and ScenarioInfo.Options.Victory == "demoralization" then
                    M27Overseer.tAllAIBrainsByArmyIndex[iArmyIndex] = nil
                    M27Overseer.tAllActiveM27Brains[iArmyIndex] = nil
                elseif aiBrain.M27AI then
                    ForkThread(M27Overseer.RecordAllEnemiesAndAllies, aiBrain)
                end
            end
        else
            if bDebugMessages == true then
                LOG('Will debug array of the unit')
                M27Utilities.DebugArray(oUnit)
            end
            if oUnit.CachePosition then --Redundancy, not sure this will actually trigger as looks like wreck deaths are picked up by the prop logic above
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Unit killed has a cache position, will draw in blue around it')
                    M27Utilities.DrawLocation(oUnit.CachePosition, nil, 1, 100, nil)
                end
                ForkThread(M27MapInfo.RecordThatWeWantToUpdateReclaimAtLocation, oUnit.CachePosition, 0)
            else
                --Is the unit owned by M27AI?
                if oUnit.GetAIBrain then
                    local aiBrain = oUnit:GetAIBrain()
                    if aiBrain.M27AI then
                        --Flag for the platoon count of units to be updated:
                        if oUnit.PlatoonHandle then oUnit.PlatoonHandle[M27PlatoonUtilities.refbUnitHasDiedRecently] = true end

                        --Run unit type specific on death logic
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                        local sUnitBP = oUnit.UnitId
                        if EntityCategoryContains(refCategoryEngineer, sUnitBP) then
                            --M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..'Pre clear action')
                            M27EngineerOverseer.OnEngineerDeath(aiBrain, oUnit)
                            --M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..'Post clear action')
                        elseif EntityCategoryContains(refCategoryAirScout, sUnitBP) then
                            M27AirOverseer.OnScoutDeath(aiBrain, oUnit)
                        elseif EntityCategoryContains(M27UnitInfo.refCategoryAirAA, sUnitBP) then
                            M27AirOverseer.OnAirAADeath(oUnit)
                        elseif EntityCategoryContains(M27UnitInfo.refCategoryBomber, sUnitBP) or EntityCategoryContains(M27UnitInfo.refCategoryTorpBomber, sUnitBP) then
                            M27AirOverseer.OnBomberDeath(aiBrain, oUnit)
                        elseif EntityCategoryContains(M27UnitInfo.refCategoryFixedShield, sUnitBP) then
                            M27EngineerOverseer.CheckUnitsStillShielded(aiBrain)
                            --elseif EntityCategoryContains(M27UnitInfo.refCategoryMobileLandShield, sUnitBP) then
                            --aiBrain[M27PlatoonFormer.refbUsingMobileShieldsForPlatoons] = true
                        elseif EntityCategoryContains(M27UnitInfo.refCategoryMex, sUnitBP) then
                            OnMexDeath(oUnit)
                        elseif EntityCategoryContains(M27UnitInfo.refCategoryTMD, sUnitBP) and M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftTMLDefence]) == false then
                            local tUnitsWantingTMD = {}
                            for iWantingTMD, oWantingTMD in oUnit[M27UnitInfo.reftTMLDefence] do
                                if M27UnitInfo.IsUnitValid(oUnit) then table.insert(tUnitsWantingTMD, oUnit) end
                            end
                            if M27Utilities.IsTableEmpty(tUnitsWantingTMD) == false then M27Logic.DetermineTMDWantedForUnits(aiBrain, tUnitsWantingTMD) end
                        elseif EntityCategoryContains(M27UnitInfo.refCategoryTML, sUnitBP) then
                            if (oUnit.Sync.totalMassKilled or 0) >= 800 then
                                aiBrain[M27EngineerOverseer.refiTimeOfLastFailedTML] = nil
                            else
                                local iTime = GetGameTimeSeconds()
                                aiBrain[M27EngineerOverseer.refiTimeOfLastFailedTML] = iTime
                                --Reset after 5m (unless another TML dies between now and then)
                                M27Utilities.DelayChangeVariable(aiBrain, M27EngineerOverseer.refiTimeOfLastFailedTML, nil, 300, M27EngineerOverseer.refiTimeOfLastFailedTML, iTime + 0.01, nil, nil)
                            end
                        end
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    elseif EntityCategoryContains(M27UnitInfo.refCategoryMex, oUnit.UnitId) then
                        OnMexDeath(oUnit)
                    end
                end
            end
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
end

function OnWorkEnd(self, work)
    if M27Utilities.bM27AIInGame then
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        local sFunctionRef = 'OnWorkEnd'
        if bDebugMessages == true then LOG(sFunctionRef..': Hook successful') end
    end
end

function OnDamaged(self, instigator)
    if M27Utilities.bM27AIInGame then
        local sFunctionRef = 'OnDamaged'
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        if self.IsWreckage then
            --Decided to comment out the below and only update when props and wrecks are destroyed
            --[[
            if bDebugMessages == true then LOG(sFunctionRef..': Wreckage damaged, will udpate reclaim') end

            --ForkThread(DelayedReclaimUpdateAtLocation, self.CachePosition, 1) --this would Update reclaim in this segment in 1 tick
            ForkThread(RecordThatWeWantToUpdateReclaimAtLocation, self.CachePosition, 0)--]]

        else
            if bDebugMessages == true then LOG(sFunctionRef..': Non-wreck damaged') end
            if self.GetUnitId then
                if self.GetAIBrain and not(self.Dead) then
                    local aiBrain = self:GetAIBrain()
                    if aiBrain.M27AI then
                        --Has our ACU been hit by an enemy we have no sight of? Or a mex taking damage? Or a land experimental taking naval damage?
                        if M27UnitInfo.IsUnitValid(self) and ((M27Utilities.IsACU(self) and self == M27Utilities.GetACU(aiBrain)) or EntityCategoryContains(M27UnitInfo.refCategoryMex, self.UnitId) or (EntityCategoryContains(M27UnitInfo.refCategoryLandExperimental, self.UnitId) and M27UnitInfo.IsUnitUnderwater(self))) then
                            if bDebugMessages == true then LOG(sFunctionRef..': ACU has just taken damage, checking if can see the unit that damaged it') end
                            --Do we have a unit that damaged us?
                            local oUnitCausingDamage
                            if instigator then
                                if IsUnit(instigator) then
                                    oUnitCausingDamage = instigator
                                elseif IsProjectile(instigator) or IsCollisionBeam(instigator) then
                                    oUnitCausingDamage = instigator.unit
                                end
                                if not(oUnitCausingDamage) and bDebugMessages == true then LOG(sFunctionRef..': Dont ahve a valid unit as instigator') end

                                if oUnitCausingDamage and M27UnitInfo.IsUnitValid(oUnitCausingDamage) then
                                    --Can we see the unit?
                                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if can see the unit that dealt us damage') end
                                    if not(M27Utilities.CanSeeUnit(aiBrain, oUnitCausingDamage, true)) then
                                        if M27Utilities.IsACU(self) or EntityCategoryContains(M27UnitInfo.refCategoryLandExperimental, self.UnitId) then
                                            if bDebugMessages == true then LOG(sFunctionRef..': self='..self.UnitId..M27UnitInfo.GetUnitLifetimeCount(self)..'; cant see unit that caused damage, will ask for an air scout and flag the ACU/experimental has taken damage recently') end
                                            self[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage] = GetGameTimeSeconds()
                                            self[M27Overseer.refoUnitDealingUnseenDamage] = oUnitCausingDamage
                                        else
                                            --mex taken damage for first time from unseen enemy
                                            if not(aiBrain[M27Overseer.reftPriorityLandScoutTargets]) then aiBrain[M27Overseer.reftPriorityLandScoutTargets] = {} end
                                            if not(aiBrain[M27Overseer.reftPriorityLandScoutTargets][self.UnitId..M27UnitInfo.GetUnitLifetimeCount(self)]) then
                                                aiBrain[M27Overseer.reftPriorityLandScoutTargets][self.UnitId..M27UnitInfo.GetUnitLifetimeCount(self)] = self
                                                M27Utilities.DelayChangeVariable(aiBrain[M27Overseer.reftPriorityLandScoutTargets], self.UnitId..M27UnitInfo.GetUnitLifetimeCount(self), nil, 120)
                                            end
                                        end
                                            --Flag that we want the location (and +- 2 segments around it) the shot came from scouted asap
                                            M27AirOverseer.MakeSegmentsAroundPositionHighPriority(aiBrain, oUnitCausingDamage:GetPosition(), 2)
                                    else
                                        if oUnitCausingDamage.GetUnitId and EntityCategoryContains(M27UnitInfo.refCategoryTorpedoLandAndNavy, oUnitCausingDamage.UnitId) then
                                            self[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage] = GetGameTimeSeconds()
                                            self[M27Overseer.refoUnitDealingUnseenDamage] = oUnitCausingDamage
                                            if bDebugMessages == true then LOG(sFunctionRef..': self='..self.UnitId..M27UnitInfo.GetUnitLifetimeCount(self)..'; Can see unit and it is a torpedo unit so will flag that we have taken unseen or torpedo damage. self[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage]='..self[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage]) end
                                        end
                                    end
                                    --If we're upgrading consider cancelling

                                    if self.IsUnitState and self:IsUnitState('Upgrading') and EntityCategoryContains(categories.INDIRECTFIRE, oUnitCausingDamage.UnitId) and not(M27Conditions.DoesACUHaveGun(aiBrain, false, self)) then
                                        if self:GetWorkProgress() <= 0.25 then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Taken indirect fire, consider cancelling upgrade as onl yat '..self:GetWorkProgress()) end
                                            --Do we have nearby friendly units?
                                            if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, self:GetPosition(), 40, 'Ally')) == true then
                                                --Is the unit within range of us?
                                                local iOurMaxRange = M27Logic.GetUnitMaxGroundRange({self})
                                                if M27Utilities.GetDistanceBetweenPositions(self:GetPosition(), oUnitCausingDamage:GetPosition()) > iOurMaxRange then
                                                    IssueClearCommands({self})
                                                    IssueMove({self}, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                                end
                                            end
                                        end
                                        if not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance) and not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill) then
                                            aiBrain[M27Overseer.refiAIBrainCurrentStrategy] = M27Overseer.refStrategyProtectACU
                                        end
                                    end
                                end
                            end
                        elseif EntityCategoryContains(M27UnitInfo.refCategoryMex, self.UnitId) and M27UnitInfo.IsUnitValid(self) then
                            --Can we see the enemy?


                        end
                        --General logic for shields so are very responsive with micro
                        if self.MyShield and self.MyShield.GetHealth and self.MyShield:GetHealth() < 100 and EntityCategoryContains((M27UnitInfo.refCategoryMobileLandShield + M27UnitInfo.refCategoryPersonalShield) * categories.MOBILE, self) then
                            if self.PlatoonHandle and aiBrain:PlatoonExists(self.PlatoonHandle) then M27PlatoonUtilities.RetreatLowHealthShields(self.PlatoonHandle, aiBrain)
                            else
                                --Assign to a retreating platoon
                                local oShieldPlatoon = M27PlatoonFormer.CreatePlatoon(aiBrain, 'M27RetreatingShieldUnits', {self}, true)
                            end
                        end
                    end
                end
            end
            if instigator and IsUnit(instigator) and instigator.GetAIBrain and instigator:GetAIBrain().M27AI then
                instigator[M27UnitInfo.refbRecentlyDealtDamage] = true
                instigator[M27UnitInfo.refiGameTimeDamageLastDealt] = math.floor(GetGameTimeSeconds())
                M27Utilities.DelayChangeVariable(instigator, M27UnitInfo.refbRecentlyDealtDamage, false, 5, M27UnitInfo.refiGameTimeDamageLastDealt, instigator[M27UnitInfo.refiGameTimeDamageLastDealt] + 1, nil, nil)
            end
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
end

function OnBombFired(oWeapon, projectile)
    if M27Utilities.bM27AIInGame then
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        local sFunctionRef = 'OnBombFired'
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
        local oUnit = oWeapon.unit
        if oUnit and oUnit.GetUnitId then
            local sUnitID = oUnit.UnitId
            if bDebugMessages == true then LOG(sFunctionRef..': bomber position when firing bomb='..repr(oUnit:GetPosition())) end
            if EntityCategoryContains(M27UnitInfo.refCategoryBomber + M27UnitInfo.refCategoryTorpBomber, sUnitID) then
                --Dont bother trying to dodge an experimental bomb
                if not(EntityCategoryContains(categories.EXPERIMENTAL, sUnitID)) then
                    M27UnitMicro.DodgeBomb(oUnit, oWeapon, projectile)
                end
                if oUnit.GetAIBrain and oUnit:GetAIBrain().M27AI then
                    if bDebugMessages == true then LOG(sFunctionRef..': Projectile position='..repr(projectile:GetPosition())) end
                    local iDelay = 0
                    if M27UnitInfo.DoesBomberFireSalvo(oUnit) then iDelay = 3 end

                    if not(oUnit[M27AirOverseer.refiLastFiredBomb]) or GetGameTimeSeconds() - oUnit[M27AirOverseer.refiLastFiredBomb] > iDelay then
                        oUnit[M27AirOverseer.refiLastFiredBomb] = GetGameTimeSeconds()
                        oUnit[M27AirOverseer.refiBombsDropped] = (oUnit[M27AirOverseer.refiBombsDropped] or 0) + 1
                        oUnit[M27AirOverseer.refoLastBombTarget] = oUnit[M27AirOverseer.reftTargetList][oUnit[M27AirOverseer.refiCurTargetNumber]][M27AirOverseer.refiShortlistUnit]
                    end
                    ForkThread(M27AirOverseer.DelayedBomberTargetRecheck, oUnit, iDelay)
                end
            end
        end
    end
end

--WARNING: OnWeaponFired and/or OnProjectilfeFired - one of these (probably the latter) resulted in error messages when t1 arti fired, disabled both of them as dont use now

function OnWeaponFired(oWeapon)
    if M27Utilities.bM27AIInGame then
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        local sFunctionRef = 'OnWeaponFired'
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
        --NOTE: Have used hook on calcballisticacceleration instead of below now
        --if oWeapon.GetBlueprint then LOG('OnWeaponFired hook for blueprint='..repr(oWeapon:GetBlueprint())) end
        local oUnit = oWeapon.unit
        if oUnit and oUnit.GetUnitId then
            --Overcharge
            if oWeapon.GetBlueprint and oWeapon:GetBlueprint().Overcharge then
                oUnit[M27UnitInfo.refbOverchargeOrderGiven] = false
                if bDebugMessages == true then LOG('Overcharge weapon was just fired') end
                oUnit[M27UnitInfo.refiTimeOfLastOverchargeShot] = GetGameTimeSeconds()
            end

            --T3 arti
            if oUnit:GetAIBrain().M27AI then
                if EntityCategoryContains(M27UnitInfo.refCategoryFixedT3Arti, oUnit.UnitId) then
                    ForkThread(M27Logic.GetT3ArtiTarget, oUnit)
                end
            end
        end
    end
end

function OnMissileBuilt(self, weapon)
    if M27Utilities.bM27AIInGame then

        if self.GetAIBrain and self:GetAIBrain().M27AI then
            --Pause if we already have 2 missiles
            local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
            local sFunctionRef = 'OnMissileBuilt'
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            if bDebugMessages == true then
                if M27UnitInfo.IsUnitValid(self) then
                    LOG(sFunctionRef..': Have valid unit='..self.UnitId..M27UnitInfo.GetUnitLifetimeCount(self))
                else
                    LOG(sFunctionRef..': self='..DebugArray(self))
                end
            end

            local iMissiles = 1 --For some reason the count is off by 1, presumably a slight delay between the event being called and the below ammo counts working
            if self.GetTacticalSiloAmmoCount then iMissiles = iMissiles + self:GetTacticalSiloAmmoCount() end
            if bDebugMessages == true then LOG(sFunctionRef..': iMissiles based on tactical silo ammo='..iMissiles) end
            if self.GetNukeSiloAmmoCount then iMissiles = iMissiles + self:GetNukeSiloAmmoCount() end
            if bDebugMessages == true then LOG(sFunctionRef..': iMissiles after Nuke silo ammo='..iMissiles) end
            if iMissiles >= 2 then
                if bDebugMessages == true then LOG(sFunctionRef..': Have at least 2 missiles so will set paused to true') end
                self:SetPaused(true)
                --Recheck every minute
                ForkThread(M27Logic.CheckIfWantToBuildAnotherMissile, self)
            end
            --Start logic to periodically check for targets to fire the missile at (in case there are no targets initially)
            if not(self[M27UnitInfo.refbActiveMissileChecker]) and not(EntityCategoryContains(M27UnitInfo.refCategorySMD, self.UnitId)) then
                if bDebugMessages == true then LOG(sFunctionRef..': Calling logic to consider launching a missile') end
                ForkThread(M27Logic.ConsiderLaunchingMissile, self, weapon)
            end

            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        end
    end
end

--[[
function OnProjectileFired(oWeapon, oMuzzle)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OnProjectileFired'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    if oWeapon.GetBlueprint then
        LOG('OnWeaponFired hook for blueprint='..repr(oWeapon:GetBlueprint()))
    end
    if oWeapon.unit then
        LOG('Have a unit; unit position='..repr(oWeapon.unit:GetPosition()))
    end
end--]]

function OnConstructionStarted(oEngineer, oConstruction, sOrder)
    if M27Utilities.bM27AIInGame then
        --Track experimental construction and other special on construction logic
        if oEngineer.GetAIBrain and oEngineer:GetAIBrain().M27AI and oConstruction.GetUnitId and not(oConstruction['M27FirstConstructionStart']) then
            local sFunctionRef = 'OnConstructionStarted'
            local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

            oConstruction['M27FirstConstructionStart'] = true
            local aiBrain = oEngineer:GetAIBrain()
            --Decide if we want to shield the construction
            local oBP = oConstruction:GetBlueprint()
            if oBP.Economy.BuildCostMass >= 2000 then
                if oBP.Defense.Health / oBP.Economy.BuildCostMass < 1 or (aiBrain[M27Overseer.refbDefendAgainstArti] and oBP.Economy.BuildCostMass >= 3000 and EntityCategoryContains(M27UnitInfo.refCategoryStructure, oConstruction.UnitId)) then
                    oConstruction[M27EngineerOverseer.refiShieldsWanted] = 1
                    table.insert(aiBrain[M27EngineerOverseer.reftUnitsWantingFixedShield], oConstruction)
                    --Flag if we want it to have a heavy shield
                    if aiBrain[M27Overseer.refbDefendAgainstArti] then
                        oConstruction[M27EngineerOverseer.refbNeedsLargeShield] = true
                        aiBrain[M27EngineerOverseer.refbHaveUnitsWantingHeavyShield] = true --Redundancy (should already check for the defendagainstarti flag)
                        if oBP.Economy.BuildCostMass >= 12000 then
                            oConstruction[M27EngineerOverseer.refiShieldsWanted] = 2
                        end
                    else
                        if oBP.Economy.BuildCostMass >= 12000 then

                            if oBP.Economy.BuildCostMass >= 20000 then
                                oConstruction[M27EngineerOverseer.refbNeedsLargeShield] = true
                                aiBrain[M27EngineerOverseer.refbHaveUnitsWantingHeavyShield] = true
                            else
                                --Cybran - shield nukes with T3 shields.  Other factions can use t2
                                if EntityCategoryContains(categories.CYBRAN, oConstruction.UnitId) then
                                    oConstruction[M27EngineerOverseer.refbNeedsLargeShield] = true
                                    aiBrain[M27EngineerOverseer.refbHaveUnitsWantingHeavyShield] = true
                                end
                            end

                        end
                    end
                end
            end


            --Check for construction of nuke
            --if aiBrain[M27EngineerOverseer.refiLastExperimentalReference] then
                local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
                local sFunctionRef = 'OnConstructionStarted'
                if bDebugMessages == true then LOG(sFunctionRef..': Considering if we have just started construction on a nuke; if so then will start a monitor; UnitID='..oConstruction.UnitId..'; oConstruction[M27UnitInfo.refbActiveSMDChecker]='..(tostring(oConstruction[M27UnitInfo.refbActiveSMDChecker] or false))) end

                if EntityCategoryContains(M27UnitInfo.refCategorySML, oConstruction.UnitId) then
                    --Are building a nuke, check if already monitoring SMD somehow
                    if not(oConstruction[M27UnitInfo.refbActiveSMDChecker]) and oConstruction:GetFractionComplete() < 1 then
                    --if aiBrain[M27EngineerOverseer.refiLastExperimentalReference] == M27UnitInfo.refCategorySML and not(aiBrain[M27UnitInfo.refbActiveSMDChecker]) then
                        ForkThread(M27EngineerOverseer.CheckForEnemySMD, aiBrain, oConstruction)
                    end
                end
            --end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        end
    end
end
function OnConstructed(oEngineer, oJustBuilt)
    --NOTE: This is called every time an engineer stops building a unit whose fractioncomplete is 100%, so can be called multiple times
    if M27Utilities.bM27AIInGame then

        if oJustBuilt:GetAIBrain().M27AI and not(oJustBuilt.M27OnConstructedCalled) then
            local sFunctionRef = 'OnConstructed'
            local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

            oJustBuilt.M27OnConstructedCalled = true

            --LOG('OnConstructed hook test; oJustBuilt='..oJustBuilt.UnitId..'; oEngineer='..oEngineer.UnitId)
            local aiBrain = oJustBuilt:GetAIBrain()
            --Have we just built an experimental unit? If so then tell our ACU to return to base as even if we havent scouted enemy threat they could have an experimental by now
            if EntityCategoryContains(categories.EXPERIMENTAL, oJustBuilt.UnitId) then
                aiBrain[M27Overseer.refbAreBigThreats] = true
            end
            if aiBrain[M27Overseer.refbEnemyTMLSightedBefore] and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyTML]) == false then
                if EntityCategoryContains(M27UnitInfo.refCategoryProtectFromTML, oJustBuilt.UnitId) then
                    M27Logic.DetermineTMDWantedForUnits(aiBrain, {oJustBuilt})
                elseif EntityCategoryContains(M27UnitInfo.refCategoryTMD, oJustBuilt.UnitId) then
                    --Update list of units wanting TMD to factor in if they have TMD coverage from all threats now that we have just built a TMD
                    M27Logic.DetermineTMDWantedForUnits(aiBrain, aiBrain[M27EngineerOverseer.reftUnitsWantingTMD])
                end
            end
            if EntityCategoryContains(M27UnitInfo.refCategoryFixedT3Arti, oJustBuilt.UnitId) and not(oJustBuilt[M27UnitInfo.refbActiveTargetChecker]) then
                aiBrain[M27Overseer.refbAreBigThreats] = true
                --T3 arti - first time its constructed want to start thread checking for power, and also tell it what to fire
                oJustBuilt[M27UnitInfo.refbActiveTargetChecker] = true
                ForkThread(M27Logic.GetT3ArtiTarget, oJustBuilt)
            end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        elseif M27Config.M27ShowEnemyUnitNames then
            oJustBuilt:SetCustomName(oJustBuilt.UnitId..M27UnitInfo.GetUnitLifetimeCount(oJustBuilt))
        end
        --Engineer callbacks
        if oEngineer:GetAIBrain().M27AI and not(oEngineer.Dead) and EntityCategoryContains(M27UnitInfo.refCategoryEngineer, oEngineer:GetUnitId()) then
            local sFunctionRef = 'OnConstructed'
            local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            ForkThread(M27EngineerOverseer.ReassignEngineers, oEngineer:GetAIBrain(), true, { oEngineer })
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        end
    end
end

function OnReclaimFinished(oEngineer, oReclaim)
    if M27Utilities.bM27AIInGame then
        --Update the segment that the reclaim is at, or the engineer if hte reclaim doesnt have one
        local sFunctionRef = 'OnReclaimFinished'
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

        if oReclaim and oReclaim.CachePosition then
            --LOG('OnReclaimFinished temp log - remove once confirmed this works - about to update reclaim data near location='..repr(oReclaim.CachePosition))
            ForkThread(M27MapInfo.RecordThatWeWantToUpdateReclaimAtLocation, oReclaim.CachePosition, 0)
            --M27MapInfo.UpdateReclaimDataNearLocation(oReclaim.CachePosition, 0, nil)
        else
            --LOG('OnReclaimFinished alt temp log - couldnt find reclaim position so will use engineer position')
            ForkThread(M27MapInfo.RecordThatWeWantToUpdateReclaimAtLocation, oEngineer:GetPosition(), 1)
            --M27MapInfo.UpdateReclaimDataNearLocation(oEngineer:GetPosition(), 1, nil)
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
end

function OnCreateWreck(tPosition, iMass, iEnergy)
    --Dont check if M27brains are in game yet as can be called at start of game before we have recorded any aiBrain; instead will have check in the delayedreclaim
    if M27Utilities.bM27AIInGame  or GetGameTimeSeconds() <= 5 then
        --LOG('OnCreateWreck temp log - remove once confirmed this works; wreck position='..repr(tPosition)..'; iMass='..(iMass or 'nil')..'; iEnergy='..(iEnergy or 'nil'))
        local sFunctionRef = 'OnCreateWreck'
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        if GetGameTimeSeconds() <= 5 then --Some variables wont be setup yet (probably only need to do <=1s but will do 5s to be safe)
            ForkThread(M27MapInfo.DelayedReclaimRecordAtLocation, tPosition, 0, 5)
        else
            ForkThread(M27MapInfo.RecordThatWeWantToUpdateReclaimAtLocation, tPosition, 0)
        end
        --M27MapInfo.UpdateReclaimDataNearLocation(tPosition, 0, nil)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
end
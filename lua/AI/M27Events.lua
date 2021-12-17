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


local refCategoryEngineer = M27UnitInfo.refCategoryEngineer
local refCategoryAirScout = M27UnitInfo.refCategoryAirScout


function OnKilled(self, instigator, type, overkillRatio)
    --NOTE: Called by any unit of any player being killed; also note that OnUnitDeath triggers as well as this
    --i.e. this shoudl be used for where only want to get an event where the unit was killed by something
    --Is the unit owned by M27AI?
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
        end
    end
end

function OnUnitDeath(oUnit)
    --NOTE: This is called by the death of any unit of any player, so careful with what commands are given
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OnUnitDeath'
    if bDebugMessages == true then LOG(sFunctionRef..'Hook successful') end
    --Is it an ACU?
    if M27Utilities.IsACU(oUnit) then
        M27Overseer.iACUDeathCount = M27Overseer.iACUDeathCount + 1
        LOG(sFunctionRef..' ACU kill detected; total kills='..M27Overseer.iACUDeathCount)
    else
        --Is the unit owned by M27AI?
        if oUnit.GetAIBrain then
            local aiBrain = oUnit:GetAIBrain()
            if aiBrain.M27AI then
                local sUnitBP = oUnit:GetUnitId()
                if EntityCategoryContains(refCategoryEngineer, sUnitBP) then
                    --M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..'Pre clear action')
                    M27EngineerOverseer.ClearEngineerActionTrackers(aiBrain, oUnit, true)
                    --M27EngineerOverseer.TEMPTEST(aiBrain, sFunctionRef..'Post clear action')
                elseif EntityCategoryContains(refCategoryAirScout, sUnitBP) then
                    M27AirOverseer.OnScoutDeath(aiBrain, oUnit)
                elseif EntityCategoryContains(M27UnitInfo.refCategoryAirAA, sUnitBP) then
                    M27AirOverseer.OnAirAADeath(oUnit)
                elseif EntityCategoryContains(M27UnitInfo.refCategoryBomber, sUnitBP) or EntityCategoryContains(M27UnitInfo.refCategoryTorpBomber, sUnitBP) then
                    M27AirOverseer.OnBomberDeath(aiBrain, oUnit)
                elseif EntityCategoryContains(M27UnitInfo.refCategoryMobileLandShield, sUnitBP) then
                    aiBrain[M27PlatoonFormer.refbUsingMobileShieldsForPlatoons] = true
                end
            end
        end
    end
end

function OnWorkEnd(self, work)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OnWorkEnd'
    if bDebugMessages == true then LOG(sFunctionRef..': Hook successful') end
end

function OnDamaged(self, instigator)

    if self.GetUnitId then
        if self.GetAIBrain and not(self.Dead) then
            local aiBrain = self:GetAIBrain()
            if aiBrain.M27AI then
                --Has our ACU been hit by an enemy we have no sight of?
                if self == M27Utilities.GetACU(aiBrain) then
                    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
                    local sFunctionRef = 'OnDamage'
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

                        if oUnitCausingDamage and oUnitCausingDamage.GetAIBrain then
                            --Can we see the unit?
                            if bDebugMessages == true then LOG(sFunctionRef..': Checking if can see the unit that dealt us damage') end
                            if not(M27Utilities.CanSeeUnit(aiBrain, oUnitCausingDamage, true)) then
                                if bDebugMessages == true then LOG(sFunctionRef..': cant see unit that caused damage, will ask for an air scout and flag the ACU has taken damage recently') end
                                self[M27Overseer.refiACULastTakenUnseenDamage] = GetGameTimeSeconds()
                                self[M27Overseer.refoUnitDealingUnseenDamage] = oUnitCausingDamage
                                --Flag that we want the location (and +- 2 segments around it) the shot came from scouted asap
                                M27AirOverseer.MakeSegmentsAroundPositionHighPriority(aiBrain, oUnitCausingDamage:GetPosition(), 2)

                            end
                            --If we're upgrading consider cancelling
                            if self:IsUnitState('Upgrading') and self:GetWorkProgress() <= 0.3 and oUnitCausingDamage:EntityCategoryContains(categories.INDIRECT, oUnitCausingDamage:GetUnitId()) and M27Conditions.DoesACUHaveGun(aiBrain, false, self) then
                                --Do we have nearby friendly units?
                                if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, self:GetPosition(), 40, 'Ally')) == true then
                                    IssueClearCommands({self})
                                    IssueMove({self}, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                end
                            end
                        end
                    end
                end
                --General logic for shields so are very responsive with micro
                if self.MyShield and self.MyShield.GetHealth and self.MyShield:GetHealth() < 100 and EntityCategoryContains((M27UnitInfo.refCategoryMobileLandShield + M27UnitInfo.refCategoryPersonalShield) * categories.MOBILE, self) then
                    if self.PlatoonHandle then M27PlatoonUtilities.RetreatLowHealthShields(self.PlatoonHandle) end
                end
            end

        end
    end
end

function OnBombFired(oWeapon, projectile)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OnBombFired'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local oUnit = oWeapon.unit
    if oUnit and oUnit.GetUnitId then
        local sUnitID = oUnit:GetUnitId()
        if EntityCategoryContains(M27UnitInfo.refCategoryBomber - categories.EXPERIMENTAL, sUnitID) then
            M27UnitMicro.DodgeBomb(oUnit, oWeapon, projectile)
        end
    end
end

--WARNING: OnWeaponFired and/or OnProjectilfeFired - one of these (probably the latter) resulted in error messages when t1 arti fired, disabled both of them as dont use now
--[[
function OnWeaponFired(oWeapon)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OnWeaponFired'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    --NOTE: Have used hook on calcballisticacceleration instead of below now
    --if oWeapon.GetBlueprint then LOG('OnWeaponFired hook for blueprint='..repr(oWeapon:GetBlueprint())) end
    local oUnit = oWeapon.unit
    if oUnit and oUnit.GetUnitId then
        local sUnitID = oUnit:GetUnitId()
        if EntityCategoryContains(M27UnitInfo.refCategoryBomber - categories.EXPERIMENTAL, sUnitID) then
            M27UnitMicro.DodgeBombsFiredByUnit(oWeapon, oUnit)
        end
    end
end--]]

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
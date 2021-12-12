--OBSOLETE - below isnt united by M27AI
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'
local SBC = '/lua/editor/SorianBuildConditions.lua'
--local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local SAI = '/lua/ScenarioPlatoonAI.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local MABC = '/lua/editor/MarkerBuildConditions.lua'
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')

--[[BuilderGroup {
    BuilderGroupName = 'M27AIPlatoonBuilder',
    BuildersType = 'PlatoonFormBuilder', -- A PlatoonFormBuilder is for builder groups of units.
    Builder {
        BuilderName = 'M27AI Land Attack1A',
        PlatoonTemplate = 'M27SmallRaider', -- The platoon template tells the AI what units to include, and how to use them.
        Priority = 1000,
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
        },
        BuilderConditions = {
            { MIBC, 'M27TestReturnFalse', {true} }, --for testing
        },
    },--]]
    --[[
    Builder {
        BuilderName = 'M27AI Land Attack1OffRaider',
        PlatoonTemplate = 'M27SmallRaider', -- The platoon template tells the AI what units to include, and how to use them.
        Priority = 999,
        InstanceCount = 2,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
        },
        BuilderConditions = {
            { UCBC, 'M27LifetimeBuildCountLessThan', { true, categories.LAND * categories.SCOUT * categories.MOBILE, 2 + 1}},
            --{ MIBC, 'M27TestReturnFalse', {true} }, --for testing
        },
    },

    Builder {
        BuilderName = 'M27IntelScouts1st',
        PlatoonTemplate = 'M27MainIntelPlatoon',
        Priority = 110,
        InstanceCount = 1, --Only ever want 1 intel platoon - overseer will add units to it
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = true,
            UseFormation = 'GrowthFormation',
        },
        BuilderConditions = {
            { UCBC, 'M27LifetimePlatoonCount', { false, 'M27MexRaiderAI', 2, true}}, -->1
        },
    },
    Builder {
        BuilderName = 'M27IntelScoutsInitial',
        PlatoonTemplate = 'M27ExtraScoutsForIntelPlatoon',
        Priority = 109,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = true,
            UseFormation = 'GrowthFormation',
        },
        BuilderConditions = {
            { MIBC, 'M27NeedScoutPlatoons', {true} }, --overseer will flag we need scouts
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 5, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.MOBILE * categories.SCOUT * categories.DIRECTFIRE}},
            { UCBC, 'M27LifetimePlatoonCount', { false, 'M27MexRaiderAI', 2, true}}, -->1
        },
    },
    Builder {
        BuilderName = 'M27Defenders',
        PlatoonTemplate = 'M27DefenderTemplate',
        Priority = 100,
        InstanceCount = 100,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
        },
        BuilderConditions = {
            { MIBC, 'M27NeedDefenders', {true} }, --overseer will flag we need defenders if it cant deal with all ID'd threats
            { MIBC, 'M27ACUHasGunUpgrade', { false, true } }, --Once ACU has gun switch to attacking regardless of threats
        },
    },
    Builder {
        BuilderName = 'M27AI Land Attack1B',
        PlatoonTemplate = 'M27SmallRaider', -- The platoon template tells the AI what units to include, and how to use them.
        Priority = 65,
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
        },
        BuilderConditions = {
            { UCBC, 'M27LifetimePlatoonCount', { true, 'M27MexRaiderAI', 8, true}}, --< 8
            --{ UCBC, 'M27LifetimePlatoonCount', { false, 'M27MexRaiderAI', M27Overseer.refiInitialRaiderPlatoonsWanted, true}}, -->1
            --{ MIBC, 'M27TestReturnFalse', {true} }, --for testing
        },
    },
    Builder {
        BuilderName = 'M27AI AttackNearestStart',
        PlatoonTemplate = 'M27AILandAttackNearestTemplate',
        Priority = 60,
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
        },
        BuilderConditions = {
            --{ UCBC, 'M27LifetimePlatoonCount', { false, 'M27MexRaiderAI', M27Overseer.refiInitialRaiderPlatoonsWanted, true}}, -->1
            --{ MIBC, 'M27TestReturnFalse', {true} }, --for testing
        },
    },
    Builder {
        BuilderName = 'M27AI Land Attack2',
        PlatoonTemplate = 'M27MediumRaider', -- The platoon template tells the AI what units to include, and how to use them.
        Priority = 55,
        InstanceCount = 2,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
        },
        BuilderConditions = {
            { UCBC, 'M27LifetimePlatoonCount', { true, 'M27MexRaiderAI', 8, true}}, --<8
            --{ UCBC, 'M27LifetimePlatoonCount', { false, 'M27MexRaiderAI', M27Overseer.refiInitialRaiderPlatoonsWanted, true}}, -->1
            --{ MIBC, 'M27TestReturnFalse', {true} }, --used for testing
        },
    },
    Builder {
        BuilderName = 'M27AI Land Attack3',
        PlatoonTemplate = 'M27LargeRaider', -- The platoon template tells the AI what units to include, and how to use them.
        Priority = 50,
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
        },
        BuilderConditions = {
            --{ UCBC, 'M27LifetimePlatoonCount', { false, 'M27MexRaiderAI', M27Overseer.refiInitialRaiderPlatoonsWanted, true}}, -->1
            --{ UCBC, 'M27LifetimePlatoonCount', { true, 'M27MexRaiderAI', 8, true}}, --<8
            --{ MIBC, 'M27TestReturnFalse', {true} }, --for testing
        },
    },
    Builder {
        BuilderName = 'M27AI Base Attack 1',
        PlatoonTemplate = 'M27LargeAttack', -- The platoon template tells the AI what units to include, and how to use them.
        Priority = 200,
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
        },
        BuilderConditions = {
            --{ UCBC, 'M27LifetimePlatoonCount', { true, 'M27LargeAttackForce', 1, true}}, --<1
            { MIBC, 'M27ACUHasGunUpgrade', { true, true } },
            --{ MIBC, 'M27TestReturnFalse', {true} }, --used for testing
        },
    },
    Builder {
        BuilderName = 'M27IntelScoutsMore',
        PlatoonTemplate = 'M27ExtraScoutsForIntelPlatoon',
        Priority = 20,
        InstanceCount = 100,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = true,
            UseFormation = 'GrowthFormation',
        },
        BuilderConditions = {
            { MIBC, 'M27NeedScoutPlatoons', {true} }, --overseer will flag we need scouts
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 5, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.MOBILE * categories.SCOUT * categories.DIRECTFIRE}},
            --{ UCBC, 'M27LifetimePlatoonCount', { false, 'M27MexRaiderAI', M27Overseer.refiInitialRaiderPlatoonsWanted, true}}, -->1
        },
    },

    Builder {
        BuilderName = 'M27AttackWhenBuilt',
        PlatoonTemplate = 'M27AILandAttack', --Min platoon size is 2 units
        Priority = 1,
        InstanceCount = 200,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
        },
        BuilderConditions = {
            { MIBC, 'M27NeedDefenders', {false} }, --overseer will flag we need defenders if it cant deal with all ID'd threats
            { UCBC, 'M27LifetimePlatoonCount', { true, 'M27LargeAttackForce', 0, false}}, -- >0
            { MIBC, 'M27ACUHasGunUpgrade', { true, true } }, --Once ACU has gun switch to attacking regardless of threats
            --{ UCBC, 'M27LifetimePlatoonCount', { false, 'M27MexRaiderAI', M27Overseer.refiInitialRaiderPlatoonsWanted, true}}, -->1
            --{ MIBC, 'M27TestReturnFalse', {true} }, --used for testing
        },
    },
    Builder {
        BuilderName = 'M27AttackWhenBuiltPostGun',
        PlatoonTemplate = 'M27AILandAttack', --Min platoon size is 2 units
        Priority = 1,
        InstanceCount = 200,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
        },
        BuilderConditions = {
            --{ MIBC, 'M27NeedDefenders', {false} }, --overseer will flag we need defenders if it cant deal with all ID'd threats
            { UCBC, 'M27LifetimePlatoonCount', { true, 'M27LargeAttackForce', 0, false}}, -- >0
            --{ MIBC, 'M27TestReturnFalse', {true} }, --used for testing
        },
    },--]]
    --[[
    Builder {
        BuilderName = 'M27AI Air Attack',
        PlatoonTemplate = 'BomberAttack',
        Priority = 100,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderConditions = { },
    },
    Builder {
        BuilderName = 'M27AI Air Intercept',
        PlatoonTemplate = 'AntiAirHunt',
        Priority = 100,
        InstanceCount = 200,
        BuilderType = 'Any',
        BuilderConditions = { },
    },--]]
--}

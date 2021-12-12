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


BuilderGroup {
    BuilderGroupName = 'M27AILandBuilder',
    BuildersType = 'FactoryBuilder',

    Builder {
        BuilderName = 'M27Ai Factory AntiAir',
        PlatoonTemplate = 'T1LandAA',
        Priority = 110,
        InstanceCount = 3, --dont want to build too many at once
        BuilderConditions = {
            { MIBC, 'M27TestReturnFalse', {true} },
            --{ TBC, 'EnemyThreatGreaterThanValueAtBase', { 'LocationType', 0, 'Air', 1 } }, -- Build AA if the enemy is threatening our base with air units.
            --{ UCBC, 'HaveUnitRatio', { 0.15, categories.LAND * categories.ANTIAIR * categories.MOBILE, '<', categories.LAND  * categories.MOBILE - categories.ENGINEER } },
            --{ UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.LAND  * categories.ANTIAIR } },
             --for testing
        },
        BuilderType = 'All',
    },
--[[
    Builder {
        BuilderName = 'M27Ai Factory Engineer',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 100, -- Top factory priority (except if need AA immediately)
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.ENGINEER - categories.COMMAND } }, -- Build engies until we have 5 of them.
            --{ MIBC, 'M27TestReturnFalse', {true} }, --for testing

        },
        BuilderType = 'All',
    },

    Builder {
        BuilderName = 'M27Ai InitialRaiderScout',
        PlatoonTemplate = 'T1LandScout',
        Priority = 95,
        BuilderConditions = {
            { UCBC, 'HaveUnitRatio', { 0.7, categories.LAND * categories.SCOUT * categories.MOBILE,  '<=', categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.LAND * categories.MOBILE * categories.DIRECTFIRE*categories.ENGINEER - categories.LAND * categories.MOBILE * categories.DIRECTFIRE*categories.SCOUT } }, -- Don't make scouts if we have lots of them.
            { UCBC, 'M27LifetimeBuildCountLessThan', { true, categories.LAND * categories.SCOUT * categories.MOBILE, 2}},
            --{ MIBC, 'M27TestReturnFalse', {true} }, --for testing
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'M27Ai InitialRaiderBot',
        PlatoonTemplate = 'T1LandDFBot',
        Priority = 94,
        BuilderConditions = {
            --ERROR - this condition doesn't work; hwoever dont need it anyway { UCBC, 'HaveUnitRatio', { 0.5, categories.LAND * categories.DIRECTFIRE * categories.MOBILE - categories.LAND * categories.DIRECTFIRE * categories.SCOUT * categories.MOBILE,  '<=', categories.LAND * categories.MOBILE - categories.ENGINEER } },
            { UCBC, 'M27LifetimeBuildCountLessThan', { true, categories.LAND * categories.DIRECTFIRE * categories.MOBILE - categories.LAND * categories.DIRECTFIRE * categories.MOBILE * categories.SCOUT, 2}}, --True if < 2 direct fire tanks have been built
            --{ UCBC, 'HaveUnitRatio', { 1, categories.LAND * categories.DIRECTFIRE * categories.MOBILE - categories.COMMAND,  '<=', categories.LAND * categories.SCOUT * categories.MOBILE } },
            --{ MIBC, 'M27TestReturnFalse', {true} }, --for testing

        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'M27Ai Initial Defenders',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 90,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.LAND  * categories.DIRECTFIRE * categories.MOBILE - categories.LAND  * categories.DIRECTFIRE * categories.MOBILE*categories.SCOUT - categories.LAND  * categories.DIRECTFIRE * categories.MOBILE*categories.ENGINEER } },
            --{ MIBC, 'M27TestReturnFalse', {true} }, --for testing
        },
        BuilderType = 'All',
    },

    Builder {
        BuilderName = 'M27Ai Factory Initial Scout',
        PlatoonTemplate = 'T1LandScout',
        Priority = 88,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.LAND  * categories.SCOUT * categories.MOBILE } }, --since scouts are cheap have some available for use by platoons
            --{ UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.LAND * categories.MOBILE - categories.MOBILE * categories.ENGINEER - categories.MOBILE * categories.SCOUT * categories.LAND}},
            --{ MIBC, 'M27TestReturnFalse', {true} }, --for testing
        },
        BuilderType = 'All',
    },

    Builder {
        BuilderName = 'M27AiNeedMoreScouts1',
        PlatoonTemplate = 'T1LandScout',
        Priority = 85,
        InstanceCount = 2,
        BuilderConditions = {
            { MIBC, 'M27NeedScoutsBuilt', {true} }, --Overseer flags when need scouts
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 5, categories.LAND  * categories.DIRECTFIRE * categories.MOBILE - categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.SCOUT - categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.ANTIAIR -categories.COMMAND } },
            { UCBC, 'HaveUnitRatio', { 0.5, categories.LAND * categories.SCOUT * categories.MOBILE,  '<=', categories.LAND * categories.MOBILE - categories.ENGINEER } }, -- Don't make scouts if we have lots of them.
            { UCBC, 'HaveLessThanUnitsWithCategory', { 30, categories.LAND  * categories.DIRECTFIRE * categories.MOBILE } },
            --{ MIBC, 'M27TestReturnFalse', {true} }, --for testing
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'M27Ai Factory AntiAirExtra',
        PlatoonTemplate = 'T1LandAA',
        Priority = 84,
        InstanceCount = 1, --dont want to build too many at once
        BuilderConditions = {
            --{ UCBC, 'HaveUnitRatio', { 0.15, categories.LAND * categories.ANTIAIR * categories.MOBILE,'<', categories.LAND  * categories.MOBILE - categories.ENGINEER } },
            --{ UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.LAND  * categories.ANTIAIR } },
            { MIBC, 'M27NeedMAABuilt', {true, 0.4}} --want 40% of enemy's highest ever air mass in MAA
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'M27AiNeedDefenders1',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 84,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'M27NeedDefenders', {true} }, --Overseer flags when need defenders; however it will do this even if threats far away hence only a 1 instance count for now (and later have another one)
            { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.LAND  * categories.DIRECTFIRE * categories.MOBILE - categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.SCOUT - categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.ANTIAIR -categories.COMMAND } },
        },
        BuilderType = 'All',
    },

    Builder {
        BuilderName = 'M27AiFactoryExtraEngineerBase',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 80,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.ENGINEER - categories.COMMAND } }, -- Build another engi if enough spots that need mexes
            { UCBC, 'M27AtLeastXUnclaimedMexesNearUs', {true, 6 } },

        },
        BuilderType = 'All',
    },
    --Build 1-3 extra t1 engis if lots of unclaimed mexes on the map
    Builder {
        BuilderName = 'M27AiFactoryExtraEngineer1',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 78,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 7, categories.ENGINEER - categories.COMMAND } }, -- Build another engi if enough spots that need mexes
            { UCBC, 'M27AtLeastXUnclaimedMexesNearUs', {true, 9 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'M27AiFactoryExtraEngineer2',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 77,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 8, categories.ENGINEER - categories.COMMAND } }, -- Build another engi if enough spots that need mexes
            { UCBC, 'M27AtLeastXUnclaimedMexesNearUs', {true, 12 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'M27AiFactoryExtraEngineer3',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 76,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 9, categories.ENGINEER - categories.COMMAND } }, -- Build another engi if enough spots that need mexes
            { UCBC, 'M27AtLeastXUnclaimedMexesNearUs', {true, 15 } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'M27AiFactoryExtraEngineerGeneral',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 75,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 9, categories.ENGINEER - categories.COMMAND } }, -- Build another engi if enough spots that need mexes
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.LAND * categories.MOBILE - categories.MOBILE * categories.ENGINEER - categories.MOBILE * categories.SCOUT * categories.LAND}},
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'M27AiFactoryExtraEngineerAvoidOverflow',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 74,
        InstanceCount = 2,
        BuilderConditions = {
            { EBC, 'M27ExcessMassIncome', { true, 2 }},
            { EBC, 'GreaterThanEconStorageRatio', { 0.3, 0.05}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.SCOUT - categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.ANTIAIR - categories.COMMAND}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 25, categories.ENGINEER - categories.COMMAND } },
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'M27AiNeedMoreScouts2',
        PlatoonTemplate = 'T1LandScout',
        Priority = 71,
        InstanceCount = 2,
        BuilderConditions = {
            { MIBC, 'M27NeedScoutsBuilt', {true} }, --Overseer flags when need scouts
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 5, categories.LAND  * categories.DIRECTFIRE * categories.MOBILE } },
            { UCBC, 'HaveUnitRatio', { 0.40, categories.LAND * categories.MOBILE * categories.SCOUT, '<=', categories.LAND * categories.MOBILE - categories.ENGINEER } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 30, categories.LAND  * categories.DIRECTFIRE * categories.MOBILE } },
        },
        BuilderType = 'All',
    },
    --M27AtLeastXUnclaimedMexesNearUs
    Builder {
    BuilderName = 'M27Ai Factory Artillery',
    PlatoonTemplate = 'T1LandArtillery',
    Priority = 70,
    InstanceCount = 4,
    BuilderConditions = {
        { UCBC, 'HaveGreaterThanUnitsWithCategory', { 5, categories.LAND * categories.MOBILE - categories.MOBILE * categories.ENGINEER - categories.MOBILE * categories.SCOUT * categories.LAND}},
        { UCBC, 'HaveUnitRatio', { 0.10, categories.LAND * categories.MOBILE * categories.INDIRECTFIRE, '<=', categories.LAND * categories.MOBILE - categories.ENGINEER } },
    },
    BuilderType = 'All',
    },
    Builder {
        BuilderName = 'M27AiNeedDefenders2',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 67,
        InstanceCount = 8,
        BuilderConditions = {
            { MIBC, 'M27NeedDefenders', {true} }, --Overseer flags when need defenders; however it will do this even if threats far away
            { MIBC, 'M27ACUHasGunUpgrade', { false, true } }, --Once ACU has gun switch to attacking regardless of threats
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'M27Ai Factory Extra Artillery',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 65,
        InstanceCount = 3,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 15, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.LAND * categories.DIRECTFIRE * categories.SCOUT}},
            { UCBC, 'HaveUnitRatio', { 0.20, categories.LAND * categories.MOBILE * categories.INDIRECTFIRE, '<=', categories.LAND * categories.MOBILE - categories.ENGINEER } },
        },
        BuilderType = 'All',
    },

    Builder {
        BuilderName = 'M27Ai Factory Tank',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 1,
        BuilderConditions = {
        },
        BuilderType = 'All',
    },
}--]]
--[[
BuilderGroup {
    BuilderGroupName = 'M27AIAirBuilder',
    BuildersType = 'FactoryBuilder',

    Builder {
        BuilderName = 'M27AI Factory Bomber',
        PlatoonTemplate = 'T1AirBomber',
        Priority = 80,
        BuilderConditions = {
            { MIBC, 'M27TestReturnFalse', {true} },
            { EBC, 'GreaterThanEconStorageRatio', { 0.0, 0.7}},
            { EBC, 'M27ExcessEnergyIncome', { true, 40 }},
        },
        BuilderType = 'Air',
    },--]]
--[[
    Builder {
        BuilderName = 'M27AI Factory Intie',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 90,
        BuilderConditions = { -- Only make inties if the enemy air is strong.
            { SBC, 'HaveRatioUnitsWithCategoryAndAlliance', { false, 1.5, categories.AIR * categories.ANTIAIR, categories.AIR * categories.MOBILE, 'Enemy'}},
            { EBC, 'GreaterThanEconStorageRatio', { 0.0, 0.7}},
            { EBC, 'M27ExcessEnergyIncome', { true, 40 }},
        },
        BuilderType = 'Air',
    },--]]
}
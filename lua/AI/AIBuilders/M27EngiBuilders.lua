--OBSOLETE - below isnt united by M27AI
--[[
        The keys for these builders are included AI/AIBaseTemplates/M27AI.lua.
        --This file contains builder groups for the engineers; ACU is in M27ACUBuilder.lua; builder groups for the factories are in M27FactoryBuilders.lua
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'
local SBC = '/lua/editor/SorianBuildConditions.lua'
--local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local SAI = '/lua/ScenarioPlatoonAI.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local MABC = '/lua/editor/MarkerBuildConditions.lua'

--[[BuilderGroup {
    BuilderGroupName = 'M27AIEngineerBuilder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'M27AI Early Hydro',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 1500,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'M27TestReturnFalse', { true } },
            --{ MIBC, 'M27NearbyHydro', { true } }, --Includes a game time condition
            --{ UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.MOBILE * categories.ENGINEER - categories.COMMAND}},
            --{ UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.HYDROCARBON}},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T1HydroCarbon',
                }
            }
        }
    },--]]
    --[[
    Builder {
        BuilderName = 'M27AI Early reclaim engi',
        PlatoonTemplate = 'M27AIT1EngineerReclaimer',
        --PlatoonAIPlan = 'M27ReclaimAI',
        Priority = 94,
        InstanceCount = 1, -- The max number concurrent instances of this builder - i.e. wont have more than 2 engineers reclaiming using this.
        BuilderConditions = {
            { MIBC, 'M27IsReclaimOnMap', { true, 250 } }, --Checks that is at least 250 reclaim on entire map
            { MIBC, 'LessThanGameTime', { 240 } }, --true if greatherthangametime(180) would be false
            --{ UCBC, 'HaveLessThanUnitsWithCategory', { 11, categories.MOBILE * categories.ENGINEER - categories.COMMAND}},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'M27AI later game engi',
        PlatoonTemplate = 'M27AIT1EngineerReclaimer',
        --PlatoonAIPlan = 'M27ReclaimAI',
        Priority = 85,
        InstanceCount = 2, -- The max number concurrent instances of this builder, i.e. wont have more than 2 engineers using this
        BuilderConditions = {
            { MIBC, 'M27IsReclaimOnMap', { true, 250 } }, --Checks that is at least 250 reclaim on entire map
            { MIBC, 'GreaterThanGameTime', { 240 } },
            --{ UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.MOBILE * categories.ENGINEER - categories.COMMAND}},
            { EBC, 'LessThanEconStorageRatio', { 0.5, 1.1}}, -- If less than 50% mass, send engineer to reclaim
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'M27AI T1Engineer Mex',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 100,
        InstanceCount = 2, -- The max number concurrent instances of this builder.
        BuilderConditions = { },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    Builder {
        BuilderName = 'M27AI Later Hydro',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 95,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'M27IsUnclaimedHydro', { true, true } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T1HydroCarbon',
                }
            }
        }
    },
    Builder {
        BuilderName = 'M27AI T1Engineer Pgen',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 90,
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'LessThanEconStorageRatio', { 1.1, 0.99}}, -- If less than full energy, build a pgen.
            { MIBC, 'M27HydroUnderConstruction', {false} }, --Dont want to start this if building hydro (as risk energy stall)
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                }
            }
        }
    },
    Builder {
        BuilderName = 'M27AI T1Engineer LandFac',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 89,
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.5}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 16, 'FACTORY TECH1' } }, -- Stop after 12 facs have been built.
            {MIBC, 'M27MexToFactoryRatio', {true, 1.8} } --if have >=1.8 mexes for every factory then will build another one
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T1LandFactory',
                }
            }
        }
    },
    Builder { --build up to 1 air fac if lots of mass stored
        BuilderName = 'M27AI T1Engineer AirFac',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 88,
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatio', { 0.5, 0.85}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 5, 'FACTORY TECH1' } }, -- Don't build air fac immediately.
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.FACTORY * categories.AIR } },
            { EBC, 'M27ExcessEnergyIncome', { true, 40 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T1AirFactory',
                }
            }
        }
    },
    Builder {
        BuilderName = 'M27AI T1Engineer LandFac Extra',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 87,
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatio', { 0.8, 0.5}},
            {MIBC, 'M27MexToFactoryRatio', {true, 1.2} } --if have >=1.2 mexes for every factory then will build another one
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T1LandFactory',
                }
            }
        }
    },
    Builder {
        BuilderName = 'M7AI T1Engineer Extra Mex',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 50,
        InstanceCount = 2, -- The max number concurrent instances of this builder.
        BuilderConditions = {
            { UCBC, 'M27AtLeastXUnclaimedMexesNearUs', {true, 6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    Builder {
        BuilderName = 'M27AI T1Engineer EStorage',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 45,
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'M27GreaterThanEnergyIncome', { true, 280}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ENERGYSTORAGE }},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'EnergyStorage',
                }
            }
        }
    },
    Builder {
        BuilderName = 'M27AI T1Engineer ExtraPgen',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 40,
        InstanceCount = 3,
        BuilderConditions = {
            { EBC, 'M27LessThanEnergyIncome', { true, 440}}, -- Want 400 income to support guncom, 420 for aeon, so go a bit further (since will want to support overcharge as well)
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                }
            }
        }
    },
    Builder {
        BuilderName = 'M27AI Early reclaim engiLowPriority',
        PlatoonTemplate = 'M27AIT1EngineerReclaimer',
        --PlatoonAIPlan = 'M27ReclaimAI',
        Priority = 20,
        InstanceCount = 1, -- The max number concurrent instances of this builder - i.e. wont have more than 2 engineers reclaiming using this.
        BuilderConditions = {
            { MIBC, 'M27IsReclaimOnMap', { true, 250 } }, --Checks that is at least 250 reclaim on entire map
            --{ UCBC, 'HaveLessThanUnitsWithCategory', { 11, categories.MOBILE * categories.ENGINEER - categories.COMMAND}},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'M7AISpareEngiAssisters',
        PlatoonTemplate = 'M27TemplateEngiAssister',
        Priority = 10,
        BuilderConditions = {
        },
        BuilderType = 'Any',
    }, --]]
--}
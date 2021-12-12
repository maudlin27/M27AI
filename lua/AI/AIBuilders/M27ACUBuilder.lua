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

--[[BuilderGroup {
    BuilderGroupName = 'M27ACUBuildOrder', -- Globally unique key that the AI base template file uses to add the contained builders to your AI.
    BuildersType = 'EngineerBuilder', -- The kind of builder this is.  One of 'EngineerBuilder', 'PlatoonFormBuilder', or 'FactoryBuilder'.
    Builder {
        BuilderName = 'Ignore', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'M27CommanderBuilder', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 1500,
        BuilderConditions = {
            { MIBC, 'M27TestReturnFalse', {true} },
        },
        BuilderData = {
            Construction = {
                BuildStructures = { 'T1LandFactory',
                }
            }
        }
    },--]]
    -- The initial build order - note this is set to repeat with a <1 factory condition, due to rare issue on 1 map (so possible happens on others) where depending on the adjacency location chosen for building the factory wont build with the feirst build command, but after waiting 1 tick and retrying it will
    --[[
    Builder {
        BuilderName = 'M27AIFirstEverFactory', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'M27CommanderBuilder', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 1500,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            { IBC, 'NotPreBuilt', {} }, -- Only run this if the base isn't pre-built.
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'FACTORY TECH1' } }, -- Stop after 12 facs have been built.
            { MIBC, 'LessThanGameTime', { 14 } }, --Factory should start building around 8s mark, so this helps avoid infinite loop if e.g. issue with script later on that prevented this building
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildStructures = { 'T1LandFactory',
                }
            }
        }
    },--]]
--[[
    Builder {
        BuilderName = 'M27AIFirstEverMex', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'M27CommanderBuilder', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 1200,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            --{ IBC, 'NotPreBuilt', {} }, -- Only run this if the base isn't pre-built.
            { MIBC, 'M27IsXPlusNearbyMex', { true, 1 } }, --True if >=1 mex
            { MIBC, 'M27NearbyHydro', { false } },
            { MIBC, 'M27IsUnclaimedMexNearACU', { true } },
        },
        InstantCheck = true,
        BuilderType = 'Any',
        PlatoonAddFunctions = { { SAI, 'BuildOnce' }, }, -- Flag this builder to be only run once.
        BuilderData = {
            Construction = {
                BuildStructures = {
                                    'T1Resource',
                }
            }
        }
    },

    --Remaining build order where no nearby hydro
    Builder {
        BuilderName = 'M27AIFirstPowerNoHydro2Mex', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'M27CommanderBuilder2', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 999,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            { IBC, 'NotPreBuilt', {} }, -- Only run this if the base isn't pre-built.
            { MIBC, 'M27IsXPlusNearbyMex', { true, 2 } }, --True if >=1 mex
            { MIBC, 'M27NearbyHydro', { false } }, --dont use this if nearby hydro
            { MIBC, 'M27IsUnclaimedMexNearACU', { true } },
            { EBC, 'M27LessThanEnergyIncome', { true, 80}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                }
            }
        }
    },

    Builder {
        BuilderName = 'M27AIFirstPowerNoHydroNoMex', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'M27CommanderBuilder2', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 999,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            { IBC, 'NotPreBuilt', {} }, -- Only run this if the base isn't pre-built.
            { MIBC, 'M27IsXNearbyMex', { true, 0 } }, --True if ==0 mex
            { MIBC, 'M27NearbyHydro', { false } }, --requires no hydro within x distance of the start
            { EBC, 'M27LessThanEnergyIncome', { true, 80}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                }
            }
        }
    },

    --Hydro build order changes - get more mex first while waiting for the hydro override to kick in
    Builder {
        BuilderName = 'M27AIACUInitialMexH2', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'M27CommanderBuilder', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 1199,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            --{ IBC, 'NotPreBuilt', {} }, -- Only run this if the base isn't pre-built.
            { MIBC, 'M27IsXPlusNearbyMex', { true, 2 } }, --True if >=1 mex
            { MIBC, 'M27NearbyHydro', { true } },
            { MIBC, 'M27IsUnclaimedMexNearACU', { true } },
        },
        InstantCheck = true,
        BuilderType = 'Any',
        PlatoonAddFunctions = { { SAI, 'BuildOnce' }, }, -- Flag this builder to be only run once.
        BuilderData = {
            Construction = {
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },

    Builder {
        BuilderName = 'M27AIACUInitialMexH3', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'M27CommanderBuilder', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 1198,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            --{ IBC, 'NotPreBuilt', {} }, -- Only run this if the base isn't pre-built.
            { MIBC, 'M27IsXPlusNearbyMex', { true, 3 } }, --True if >=1 mex
            { MIBC, 'M27NearbyHydro', { true } },
            { MIBC, 'M27IsUnclaimedMexNearACU', { true } },
        },
        InstantCheck = true,
        BuilderType = 'Any',
        PlatoonAddFunctions = { { SAI, 'BuildOnce' }, }, -- Flag this builder to be only run once.
        BuilderData = {
            Construction = {
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },

    --Build on unclaimed mex in build area - commented out for now as ACUMain logic should do this
    Builder {
        BuilderName = 'M27ACUBuildUnclaimedMex',
        PlatoonTemplate = 'M27CommanderBuilder',
        Priority = 800,
        BuilderConditions = {
            { MIBC, 'M27IsUnclaimedMexNearACU', { true } }
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },]]--

    --Factories and other AI behaviour pre gun
    --[[Builder {
        BuilderName = 'M27AIExtraLandFacsInitial1', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'M27CommanderBuilder3', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 998,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            { IBC, 'NotPreBuilt', {} }, -- Only run this if the base isn't pre-built.
            { EBC, 'M27ExcessMassIncome', { true, 2 }},
            { EBC, 'M27ResourceStoredCurrent', { true, true, 20}}, --at least 20 mass
            { EBC, 'M27ResourceStoredCurrent', { true, false, 250}}, --at least 250 energy stored
            { EBC, 'M27GreaterThanEnergyIncome', {true, 79}}, -->79 gross energy income (i.e. want to get hydro or T1 power before this)
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.FACTORY}},


        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildStructures = {
                    'T1LandFactory',
                }
            }
        }
    },
    Builder {
        BuilderName = 'M27AIExtraLandFacsInitial2', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'M27CommanderBuilder3', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 998,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            { IBC, 'NotPreBuilt', {} }, -- Only run this if the base isn't pre-built.
            --{ EBC, 'M27ExcessMassIncome', { true, 2 }},
            { EBC, 'M27ResourceStoredCurrent', { true, true, 150}},
            { EBC, 'M27ResourceStoredCurrent', { true, false, 100}}, --at least 100 energy stored
            { EBC, 'M27GreaterThanEnergyIncome', {true, 79}}, -->79 gross energy income (i.e. want to get hydro or T1 power before this)
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.FACTORY}},


        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildStructures = {
                    'T1LandFactory',
                }
            }
        }
    },--]]

    --Assist hydro if its being built
    --[[
    Builder {
        BuilderName = 'M27ACU Assist Hydro M27',
        PlatoonTemplate = 'M27ACUHydroAssister',
        Priority = 17950,
        BuilderConditions = {
            { MIBC, 'M27HydroUnderConstruction', {true} },
            { MIBC, 'M27NearbyHydro', { true } }, --Includes gametime condition
        },
        BuilderType = 'Any',
    },--]]
    --Higher priority assister if Hydro will be built but hasn't yet
    --[[Builder {
        BuilderName = 'M27ACUAssistNearbyEngi',
        PlatoonTemplate = 'M27ACUTemplateEngiAssister',
        Priority = 500,
        BuilderConditions = {
            { MIBC, 'M27ACUHasGunUpgrade', { false, true } }, --Once have gun upgrade are attacking
            { MIBC, 'M27HydroUnderConstruction', {false} },
            { MIBC, 'M27NearbyHydro', { true } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'HYDROCARBON' } }
        },
        BuilderType = 'Any',
    },]]--

    --Expand (unless not got hydro yet in which case will move into position to assist hydro)
    --[[
    Builder {
        BuilderName = 'M27ACUExpand',
        PlatoonTemplate = 'M27ACUExpand',
        Priority = 5,
        BuilderConditions = {
            { MIBC, 'M27ACUHasGunUpgrade', { false, true } },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'M27ACUAttack',
        PlatoonTemplate = 'M27ACUExpand', --AI plan used works for both expand and attack
        Priority = 1000,
        BuilderConditions = {
            { MIBC, 'M27ACUHasGunUpgrade', { true, true } }, --top priority once gun is done
        },
        BuilderType = 'Any',
    },--]]

    --[[
    --Gun upgrades by faction:
    Builder {
        BuilderName = 'M27GunComUEF', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'CommanderEnhance', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 500,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            { UCBC, 'CmdrHasUpgrade', { 'HeavyAntiMatterCannon', false }},
            { MIBC, 'FactionIndex', {1}},
            { MIBC, 'M27WantACUToGetGunUpgrade', {true}},
        },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Enhancement = { 'HeavyAntiMatterCannon' },
        },

    },
    Builder {
        BuilderName = 'M27GunComAeonRange', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'CommanderEnhance', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 500,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            { UCBC, 'CmdrHasUpgrade', { 'CrysalisBeam', false }},
            { MIBC, 'FactionIndex', {2}},
            { MIBC, 'M27WantACUToGetGunUpgrade', {true}},
        },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Enhancement = { 'CrysalisBeam' },
        },
    },
    Builder {
        BuilderName = 'M27GunComAeonROF', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'CommanderEnhance', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 499,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            { UCBC, 'CmdrHasUpgrade', { 'HeatSink', false }},
            { MIBC, 'FactionIndex', {2}},
            { MIBC, 'M27WantACUToGetGunUpgrade', {true}},
        },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Enhancement = { 'HeatSink' },
        },
    },
    Builder {
        BuilderName = 'M27GunComAeonROF2', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'CommanderEnhance', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 499,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            { UCBC, 'CmdrHasUpgrade', { 'HeatSink', false }},
            { MIBC, 'FactionIndex', {2}},
            { MIBC, 'M27WantACUToGetGunUpgrade', {true}},
        },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Enhancement = { 'HeatSink' },
        },
    },
    Builder {
        BuilderName = 'M27GunComCybran', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'CommanderEnhance', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 500,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            { UCBC, 'CmdrHasUpgrade', { 'CoolingUpgrade', false }},
            { MIBC, 'FactionIndex', {3}},
            { MIBC, 'M27WantACUToGetGunUpgrade', {true}},
        },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Enhancement = { 'CoolingUpgrade' },
        },
    },
    Builder {
        BuilderName = 'M27GunComSera', -- Names need to be GLOBALLY unique.  Prefixing the AI name will help avoid name collisions with other AIs.
        PlatoonTemplate = 'CommanderEnhance', -- Specify what platoon template to use, see the PlatoonTemplates folder.
        Priority = 500,
        BuilderConditions = { -- The build conditions determine if this builder is available to be used or not.
            { UCBC, 'CmdrHasUpgrade', { 'RateOfFire', false }},
            { MIBC, 'FactionIndex', {4}},
            { MIBC, 'M27WantACUToGetGunUpgrade', {true}},
        },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Enhancement = { 'RateOfFire' },
        },
    },--]]
--}
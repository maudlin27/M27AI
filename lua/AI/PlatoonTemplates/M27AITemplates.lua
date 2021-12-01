--[[
    File    :   /lua/AI/PlattonTemplates/M27AITemplates.lua
    Author  :   SoftNoob
    Summary :
        Responsible for defining a mapping from AIBuilders keys -> Plans (Plans === platoon.lua functions)
]]

PlatoonTemplate {
    Name = 'M27AILandAttack',
    Plan = 'StrikeForceAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.DIRECTFIRE + categories.MOBILE * categories.LAND * categories.INDIRECTFIRE - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT, -- Type of units.
          1, -- Min number of units.
          20, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'none' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
    },
}
PlatoonTemplate {
    Name = 'M27AILandAttackNearestTemplate',
    Plan = 'M27AttackNearestUnits', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT - categories.ANTIAIR, -- Type of units.
          2, -- Min number of units.
          2, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'AttackFormation' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',; AttackFormation - units stay together
        {categories.MOBILE * categories.LAND * categories.SCOUT, 1, 1, 'attack', 'AttackFormation' },
        {categories.MOBILE * categories.LAND * categories.INDIRECTFIRE, 0, 1, 'attack', 'AttackFormation' },
    },
}

PlatoonTemplate {
    Name = 'M27SmallRaider',
    Plan = 'M27MexRaiderAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT - categories.ANTIAIR, -- Type of units.
          1, -- Min number of units.
          1, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'AttackFormation' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',; AttackFormation - units stay together
        {categories.MOBILE * categories.LAND * categories.SCOUT, 0, 1, 'attack', 'AttackFormation' },
    },
}
PlatoonTemplate {
    Name = 'M27MediumRaider',
    Plan = 'M27MexRaiderAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT - categories.ANTIAIR, -- Type of units.
          3, -- Min number of units.
          6, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'AttackFormation' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',; AttackFormation - units stay together
        {categories.MOBILE * categories.LAND * categories.SCOUT, 1, 1, 'attack', 'AttackFormation' },
        {categories.MOBILE * categories.LAND * categories.INDIRECTFIRE, 0, 1, 'attack', 'AttackFormation' },
    },
}

PlatoonTemplate {
    Name = 'M27LargeRaider',
    Plan = 'M27MexRaiderAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT - categories.ANTIAIR, -- Type of units.
          7, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'AttackFormation' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',; AttackFormation - units stay together
        {categories.MOBILE * categories.LAND * categories.SCOUT, 1, 1, 'attack', 'AttackFormation' },
        {categories.MOBILE * categories.LAND * categories.INDIRECTFIRE, 0, 3, 'attack', 'AttackFormation' },
        {categories.MOBILE * categories.LAND * categories.ANTIAIR, 0, 1, 'attack', 'AttackFormation' },
    },
}
PlatoonTemplate {
    Name = 'M27LargeAttack',
    Plan = 'M27LargeAttackForce', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT - categories.ANTIAIR, -- Type of units.
          10, -- Min number of units.
          60, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'AttackFormation' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',; AttackFormation - units stay together
        {categories.MOBILE * categories.LAND * categories.SCOUT, 0, 2, 'attack', 'AttackFormation' },
        {categories.MOBILE * categories.LAND * categories.INDIRECTFIRE - categories.MOBILE * categories.LAND * categories.INDIRECTFIRE * categories.ANTIAIR, 0, 20, 'attack', 'AttackFormation' },
        {categories.MOBILE * categories.LAND * categories.ANTIAIR, 0, 3, 'attack', 'AttackFormation' },
        --{categories.COMMAND, 1, 1, 'attack', 'AttackFormation' },
    },
}
PlatoonTemplate {
    Name = 'M27DefenderTemplate',
    Plan = 'M27DefenderAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.COMMAND - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT - categories.ANTIAIR, -- Type of units.
          0, -- Min number of units.
          50, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'AttackFormation' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',; AttackFormation - units stay together
        --{categories.MOBILE * categories.LAND * categories.SCOUT, 0, 4, 'attack', 'AttackFormation' },
        {categories.MOBILE * categories.LAND * categories.INDIRECTFIRE, 0, 50, 'attack', 'AttackFormation' },
        --{categories.MOBILE * categories.LAND * categories.ANTIAIR, 0, 10, 'attack', 'AttackFormation' },
    },
}
PlatoonTemplate {
    Name = 'M27MainIntelPlatoon',
    Plan = 'M27IntelPathAI', -- The platoon function to use.
    GlobalSquads = {
        {categories.MOBILE * categories.LAND * categories.SCOUT, 1, 1, 'attack', 'GrowthFormation' },
    },
}
PlatoonTemplate {
    Name = 'M27ExtraScoutsForIntelPlatoon',
    Plan = 'M27IntelPathAI', -- The platoon function to use.
    GlobalSquads = {
        {categories.MOBILE * categories.LAND * categories.SCOUT, 1, 1, 'attack', 'GrowthFormation' },
    },
}

PlatoonTemplate {
    Name = 'M27AIT1EngineerReclaimer',
    Plan = 'M27ReclaimAI',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH1 - categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'M27ACUHydroAssister',
    Plan = 'M27AssistHydroEngi',
    GlobalSquads = {
        { categories.COMMAND, 1, 1, 'support', 'None' }
    },
}
PlatoonTemplate {
    Name = 'M27ACUTemplateEngiAssister',
    Plan = 'M27EngiAssister',
    GlobalSquads = {
        { categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'M27ACUExpand',
    Plan = 'M27ACUMain',
    GlobalSquads = {
        { categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'M27CommanderBuilder',
    Plan = 'EngineerBuildAI',
    GlobalSquads = {
        { categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'M27TemplateEngiAssister',
    Plan = 'M27EngiAssister',
    GlobalSquads = {
        { categories.ENGINEER - categories.COMMAND, 1, 6, 'support', 'None' }
    },
}
refiMinimumPlatoonSize = 'M27MinPlatoonSize'
refbIgnoreStuckAction = 'M27IgnoreStuckAction'
refsDefaultFormation = 'M27DefaultFormation'
--Reaching destination alternative actions (default will be new movement path):
refbIdlePlatoon = 'M27IdlePlatoon' --true if platoon not meant to use normal platoon functionality
refbDisbandIfReachDestination = 'M27DisbandAtDestination'
refbDisbandAfterRunningAway = 'M27DisbandAfterRunningAway'
refbSwitchToAttackIfReachDestination = 'M27AttackAtDestination'
refbRunFromAllEnemies = 'M27RunFromAllEnemies' --Only cases where wont run are if 0 threat structures
refbAlwaysAttack = 'M27AlwaysAttack' --will attack and not run away
refbAttackMove = 'M27PlatTempAttackMove'
refbRequiresUnitToFollow = 'M27PlatTempRequiresUnitToFollow'
reftPlatoonsToAmalgamate = 'M27PlatoonsToAmalgamate'
refiPlatoonAmalgamationRange = 'M27PlatoonAmalgamationRange'
refiPlatoonAmalgamationMaxSize = 'M27PlatoonAmalgamationMaxSize' --Optional - required only if are amalgmating; If exceed this then will stop looking to amalgamate
refbDontDisplayName = 'M27PlatoonDontDisplayName' --Used for idle platoons so dont overwrite name when arent really using the platoon and are assigning names via separate method (e.g. for engis and air)
refbUsedByThreatDefender = 'M27PlatoonUsedByThreatDefender' --Overseer's threat assess and respond will consider this platoon if this is set to true

--AI global idle platoon references (i.e. only have 1 of these per aibrain):
refoIdleScouts = 'M27IdleScouts'
refoIdleMAA = 'M27IdleMAA'
refoAllEngineers = 'M27AllEngineers'
refoIdleCombat = 'M27IdleCombat'
refoAllStructures = 'M27AllStructures'
refoUnderConstruction = 'M27UnderConstruction'
refoIdleIndirect = 'M27IdleIndirect'
refoIdleAir = 'M27IdleAir'
refoIdleOther = 'M27IdleOther'

--NOTE: If adding a platoon to platoon template, also need to add it to platoon.lua


PlatoonTemplate = {
    ['M27AttackNearestUnits'] =
        {
            [refbIdlePlatoon] = false,
            [refbRequiresUnitToFollow] = false,
            [refbIgnoreStuckAction] = false,
            [refiMinimumPlatoonSize] = 1,
            [refsDefaultFormation] = 'GrowthFormation',
            [refbDisbandIfReachDestination] = false,
            [refbDisbandAfterRunningAway] = false,
            [refbSwitchToAttackIfReachDestination] = false,
            [refbRunFromAllEnemies] = false,
            [refbAlwaysAttack] = true,
            [refbAttackMove] = true,
            [reftPlatoonsToAmalgamate] = { 'M27AttackNearestUnits' },
            [refiPlatoonAmalgamationRange] = 20,
            [refiPlatoonAmalgamationMaxSize] = 20,
            [refbUsedByThreatDefender] = true,
        },
    ['M27MexRaiderAI'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'AttackFormation',
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
    },
    ['M27MexLargerRaiderAI'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 3,
        [refsDefaultFormation] = 'AttackFormation',
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
    },
    ['M27CombatPatrolAI'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'AttackFormation',
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = { 'M27CombatPatrolAI' },
        [refiPlatoonAmalgamationRange] = 50,
        [refbUsedByThreatDefender] = true,
        [refiPlatoonAmalgamationMaxSize] = 50,
    },
    ['M27LargeAttackForce'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 25,
        [refsDefaultFormation] = 'AttackFormation',
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = true,
        [refbSwitchToAttackIfReachDestination] = true,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = { 'M27MexLargerRaiderAI', 'M27MexRaiderAI', 'M27AttackNearestUnits' },
        [refiPlatoonAmalgamationRange] = 28,
        [refiPlatoonAmalgamationMaxSize] = 65,
    },
    ['M27DefenderAI'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbUsedByThreatDefender] = true,
    },
    ['M27IndirectDefender'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = true,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbUsedByThreatDefender] = true,
    },
    ['M27IndirectSpareAttacker'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = true,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbUsedByThreatDefender] = true,
    },
    ['M27EscortAI'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = true,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
    },
    ['M27MAAAssister'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = true,
        [refbIgnoreStuckAction] = true,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = true,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
    },
    ['M27ScoutAssister'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = true,
        [refbIgnoreStuckAction] = true,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = true,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
    },
    ['M27IntelPathAI'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = true,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = true,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
    },
    ['M27ACUMain'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbDisbandIfReachDestination] = true,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbUsedByThreatDefender] = false, --Some of functionality in platoon utilities such as building factory is turned off if this is true
    },
    ['M27AssistHydroEngi'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbDisbandIfReachDestination] = true,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
    },


    --Note when adding more - see above re any functions that will need specific behaviour if dont want default


    ------------------IDLE PLATOONS BELOW===================
    --Idle platoons only record some of the values
    [refoIdleScouts] =
    {
        [refbIdlePlatoon] = true,
        [refbRunFromAllEnemies] = true
    },
    [refoIdleMAA] =
    {
        [refbIdlePlatoon] = true,
        [refbRunFromAllEnemies] = true
    },
    [refoAllEngineers] =
    {
        [refbIdlePlatoon] = true,
        [refbRunFromAllEnemies] = true,
        [refbDontDisplayName] = true
    },
    [refoAllStructures] =
    {
        [refbIdlePlatoon] = true,
        [refbRunFromAllEnemies] = false
    },
    [refoIdleCombat] =
    {
        [refbIdlePlatoon] = true,
        [refbRunFromAllEnemies] = true
    },
    [refoIdleIndirect] =
    {
        [refbIdlePlatoon] = true,
        [refbRunFromAllEnemies] = true
    },

    [refoUnderConstruction] =
    {
        [refbIdlePlatoon] = true,
        [refbRunFromAllEnemies] = true
    },
    [refoIdleAir] =
    {
        [refbIdlePlatoon] = true,
        [refbRunFromAllEnemies] = true,
        [refbDontDisplayName] = true
    },

    [refoIdleOther] =
    {--For where a unit doesnt fall into expected categories - hopefully not needed
        [refbIdlePlatoon] = true,
        [refbRunFromAllEnemies] = true
    },
}
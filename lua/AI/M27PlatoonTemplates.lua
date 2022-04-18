refiMinimumPlatoonSize = 'M27MinPlatoonSize'
refbIgnoreStuckAction = 'M27IgnoreStuckAction'
refsDefaultFormation = 'M27DefaultFormation'
refbFormMoveIfCloseTogetherAndNoEnemies = 'M27FormMoveIfCloseTogetherAndNoEnemies'
refiFormMoveCloseDistanceThreshold = 'M27DistanceForFormMoveFlag' --i.e. if this is 50, then will use formmove if front and rear platoons are within this distance of each other
--Reaching destination alternative actions (default will be new movement path):
refbIdlePlatoon = 'M27IdlePlatoon' --true if platoon not meant to use normal platoon functionality
refbDisbandIfReachDestination = 'M27DisbandAtDestination'
refbDisbandAfterRunningAway = 'M27DisbandAfterRunningAway'
refbSwitchToAttackIfReachDestination = 'M27AttackAtDestination'
refbRunFromAllEnemies = 'M27RunFromAllEnemies' --Only cases where wont run are if 0 threat structures
refbAlwaysAttack = 'M27AlwaysAttack' --will attack and not run away
refbAttackMove = 'M27PlatTempAttackMove'
refbRequiresUnitToFollow = 'M27PlatTempRequiresUnitToFollow'
refbRequiresSingleLocationToGuard = 'M27PlatTempRequiresSingleLocationToGuard'
reftPlatoonsToAmalgamate = 'M27PlatoonsToAmalgamate'
refiPlatoonAmalgamationRange = 'M27PlatoonAmalgamationRange'
refiPlatoonAmalgamationMaxSize = 'M27PlatoonAmalgamationMaxSize' --Optional - required only if are amalgmating; If exceed this then will stop looking to amalgamate
refbAmalgamateIntoEscort = 'M27PlatoonAmalgamateIntoEscort' --true if any amalgamation shoudl be done to the escort platoon (but based on the position of the platoon its escorting)
refbDontDisplayName = 'M27PlatoonDontDisplayName' --Used for idle platoons so dont overwrite name when arent really using the platoon and are assigning names via separate method (e.g. for engis and air)
refbUsedByThreatDefender = 'M27PlatoonUsedByThreatDefender' --Overseer's threat assess and respond will consider this platoon if this is set to true
refbWantsShieldEscort = 'M27PlatoonWantsShieldEscort' --true if should be considered when assigning mobile shields
refiAirAttackRange = 'M27PlatoonAirAttackRange' --If this is not nil, then will check if the platoon has any MAA in it, and if so will search for enemy air units within this value + the MAA range; if any are detected, the platoon will move towards these air units (assuming there aren't ground units nearby that they're running from)

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
            [refbFormMoveIfCloseTogetherAndNoEnemies] = true,
            [refiFormMoveCloseDistanceThreshold] = 30,
            [refbDisbandIfReachDestination] = false,
            [refbDisbandAfterRunningAway] = false,
            [refbSwitchToAttackIfReachDestination] = false,
            [refbRunFromAllEnemies] = false,
            [refbAlwaysAttack] = true,
            [refbAttackMove] = true,
            [reftPlatoonsToAmalgamate] = { 'M27AttackNearestUnits' },
            [refiPlatoonAmalgamationRange] = 20,
            [refiPlatoonAmalgamationMaxSize] = 10,
            [refbUsedByThreatDefender] = true,
            [refbWantsShieldEscort] = true,
        },
    ['M27MexRaiderAI'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'AttackFormation',
        [refbFormMoveIfCloseTogetherAndNoEnemies] = true,
        [refiFormMoveCloseDistanceThreshold] = 30,
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbWantsShieldEscort] = true,
    },
    ['M27MexLargerRaiderAI'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 3,
        [refsDefaultFormation] = 'AttackFormation',
        [refbFormMoveIfCloseTogetherAndNoEnemies] = true,
        [refiFormMoveCloseDistanceThreshold] = 30,
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbWantsShieldEscort] = true,
    },
    ['M27CombatPatrolAI'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'AttackFormation',
        [refbFormMoveIfCloseTogetherAndNoEnemies] = true,
        [refiFormMoveCloseDistanceThreshold] = 30,
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = { 'M27CombatPatrolAI' },
        [refiPlatoonAmalgamationRange] = 50,
        [refbUsedByThreatDefender] = true,
        [refiPlatoonAmalgamationMaxSize] = 20,
        [refbWantsShieldEscort] = true,
    },
    ['M27LargeAttackForce'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 25,
        [refsDefaultFormation] = 'AttackFormation',
        [refbFormMoveIfCloseTogetherAndNoEnemies] = true,
        [refiFormMoveCloseDistanceThreshold] = 30,
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = true,
        [refbSwitchToAttackIfReachDestination] = true,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = { 'M27MexLargerRaiderAI', 'M27MexRaiderAI', 'M27AttackNearestUnits' },
        [refiPlatoonAmalgamationRange] = 28,
        [refiPlatoonAmalgamationMaxSize] = 40,
        [refbWantsShieldEscort] = true,
    },
    ['M27GroundExperimental'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbFormMoveIfCloseTogetherAndNoEnemies] = false,
        [refiFormMoveCloseDistanceThreshold] = nil,
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [refbUsedByThreatDefender] = false,
        [refbWantsShieldEscort] = false,
    },
    ['M27DefenderAI'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbFormMoveIfCloseTogetherAndNoEnemies] = true,
        [refiFormMoveCloseDistanceThreshold] = 30,
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbUsedByThreatDefender] = true,
        [refbWantsShieldEscort] = true,
    },
    ['M27IndirectDefender'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbFormMoveIfCloseTogetherAndNoEnemies] = true,
        [refiFormMoveCloseDistanceThreshold] = 30,
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = true,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbUsedByThreatDefender] = true,
        [refbWantsShieldEscort] = true,
    },
    ['M27IndirectSpareAttacker'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbFormMoveIfCloseTogetherAndNoEnemies] = true,
        [refiFormMoveCloseDistanceThreshold] = 30,
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = true,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbUsedByThreatDefender] = true,
        [refbWantsShieldEscort] = true,
    },
    ['M27EscortAI'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = true,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbFormMoveIfCloseTogetherAndNoEnemies] = false,  --Dont want on assister platoons as they refresh too often and cause wierd results
        [refiFormMoveCloseDistanceThreshold] = 30,
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = true,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbWantsShieldEscort] = true,
    },
    ['M27MAAAssister'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = true,
        [refbRequiresSingleLocationToGuard] = false,
        [refbIgnoreStuckAction] = true,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbFormMoveIfCloseTogetherAndNoEnemies] = false, --Dont want on assister platoons as they refresh too often and cause wierd results
        [refiFormMoveCloseDistanceThreshold] = 30,
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = true,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbWantsShieldEscort] = true,
        [refiAirAttackRange] = 20,
    },
    --MAAPatrol - different platoon to MAA assister as the overseer will treat units in MAApatrol as being available for assignment (i.e. its effectively an active 'idle' platoon)
    ['M27MAAPatrol'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbRequiresSingleLocationToGuard] = true,
        [refbIgnoreStuckAction] = true,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbFormMoveIfCloseTogetherAndNoEnemies] = false, --Dont want on assister platoons as they refresh too often and cause wierd results
        [refiFormMoveCloseDistanceThreshold] = 30,
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = true,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbWantsShieldEscort] = true,
        [refiAirAttackRange] = 40,
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
        [refbWantsShieldEscort] = false,
    },
    ['M27LocationAssister'] = --used for scouts to stay near mexes
    {
        [refbIdlePlatoon] = false,
        [refbIgnoreStuckAction] = true,
        [refbRequiresSingleLocationToGuard] = true,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = true,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [refbWantsShieldEscort] = false,
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
        [refbWantsShieldEscort] = false,
    },
    ['M27ACUMain'] =
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
        [refbAmalgamateIntoEscort] = true, --E.g. overseer will in some cases set amalgamation to happen in which case want it to be into escort
        [refbUsedByThreatDefender] = false, --Some of functionality in platoon utilities such as building factory is turned off if this is true
        [refbWantsShieldEscort] = true,
    },
    ['M27AssistHydroEngi'] = --Dont think this is used any more
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
        [refbWantsShieldEscort] = false,
    },

    ['M27MobileShield'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = true,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbFormMoveIfCloseTogetherAndNoEnemies] = false, --Dont want on assister platoons as they refresh too often and cause wierd results
        [refiFormMoveCloseDistanceThreshold] = 30,
        [refbDisbandIfReachDestination] = false,
        [refbDisbandAfterRunningAway] = false,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = false,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbUsedByThreatDefender] = false,
    },
    ['M27RetreatingShieldUnits'] =
    {
        [refbIdlePlatoon] = false,
        [refbRequiresUnitToFollow] = false,
        [refbIgnoreStuckAction] = false,
        [refiMinimumPlatoonSize] = 1,
        [refsDefaultFormation] = 'GrowthFormation',
        [refbDisbandIfReachDestination] = true,
        [refbDisbandAfterRunningAway] = true,
        [refbSwitchToAttackIfReachDestination] = false,
        [refbRunFromAllEnemies] = true,
        [refbAlwaysAttack] = false,
        [refbAttackMove] = false,
        [reftPlatoonsToAmalgamate] = nil,
        [refiPlatoonAmalgamationRange] = nil,
        [refbUsedByThreatDefender] = false,
    },
    ['M27SuicideSquad'] =
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
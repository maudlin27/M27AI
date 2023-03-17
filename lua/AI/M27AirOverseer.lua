--Overseer to handle air threat detection, air scout usage, interceptor logic, and bomber logic
local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27EconomyOverseer = import('/mods/M27AI/lua/AI/M27EconomyOverseer.lua')
local M27UnitMicro = import('/mods/M27AI/lua/AI/M27UnitMicro.lua')
local M27Transport = import('/mods/M27AI/lua/AI/M27Transport.lua')
local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27Team = import('/mods/M27AI/lua/AI/M27Team.lua')
local M27Chat = import('/mods/M27AI/lua/AI/M27Chat.lua')

--General air scouting values
iAirSegmentSize = 1 --Updated/set in initialisation
local iSegmentVisualThresholdBoxSize1 --set in initialisation, e.g. v11 this is AirSegmentSize*2
local iSegmentVisualThresholdBoxSize2 --set in initialisation, eg v11 this is aiisegmentsixe * 3

iMapMaxAirSegmentX = 0 --Updated separately
iMapMaxAirSegmentZ = 0 --Updated separately


refiMaxScoutRadius = 'M27AirMaxScoutRadius' --Range from base at which will look for air scouts to be used
--below 4 variables used so can ignore segments on very large maps
local refiMinSegmentX = 'M27AirMinSegmentX'
local refiMinSegmentZ = 'M27AirMinSegmentZ'
local refiMaxSegmentX = 'M27AirMaxSegmentX'
local refiMaxSegmentZ = 'M27AirMaxSegmentZ'

--Note: Dont need more box sizes as anything larger uses a formula to calculate


--How long to allow between scouting
local refiIntervalLowestPriority = 'M27AirIntervalLow'
local refiIntervalHighestPriority = 'M27AirIntervalHigh'
local refiIntervalMexNotBuiltOn = 'M27AirIntervalMexNotBuiltOn'
local refiIntervaPriorityMex = 'M27AirIntervalNearbyEnemyMex' --for high priority mexes
local refiIntervalEnemyMex = 'M27AirIntervalEnemyMex'
refiIntervalChokepoint = 'M27AirIntervalChokepoint'
refiIntervalEnemyBase = 'M27AirIntervalEnemyBase'

--Main trackers: Scout
reftAirSegmentTracker = 'M27AirSegmentTracker' --[x][z]{a,b,c,d etc.} - x = segment x, z = segment z, a, b, c etc. = subtable refs - Used to track all things relating to air scouting for a particular segment
--Subtable values (include in SetupAirSegments to make sure these can be referenced)
refiLastScouted = 'M27AirLastScouted'
refbHaveOmniVision = 'M27AirHaveOmniVision' --against aiBrain, true if have omni vision of whole map
refbEnemyHasOmniVision = 'M27AirEnemyHasOmniVision' --against aiBrain, true if any brains on enemy team have omni vision of whole map
local refiAirScoutsAssigned = 'M27AirScoutsAssigned'
refiNormalScoutingIntervalWanted = 'M27AirScoutIntervalWanted' --What to default to if e.g. temporairly increased
refiCurrentScoutingInterval = 'M27AirScoutCurrentIntervalWanted' --e.g. can temporarily override this if a unit dies and want to make it higher priority
reftMidpointPosition = 'M27AirSegmentMidpointPosition'
local refiDeadScoutsSinceLastReveal = 'M27AirDeadScoutsSinceLastReveal'
local refiLastTimeScoutingIntervalChanged = 'M27AirLastTimeScoutingIntervalChanged'

local reftScoutingTargetShortlist = 'M27ScoutingTargetShortlist' --[y]: [y] is the count (e.g. location 1, 2, 3), and then this gives {a,b,c} where a, b, c are subrefs, i.e. refiTimeSinceWantedToScout
--subtable values:
local refiTimeSinceWantedToScout = 'M27AirTimeSinceWantedToScout'
local refiSegmentX = 'M27AirSegmentX'
local refiSegmentZ = 'M27AirSegmentZ'


--Whether teleport units are in the game (so bombers will factor in extra logic to their targeting
bTeleportersInGame = false

--AirAA
local refiNearToACUThreshold = 'M27AirNearToACUThreshold'
local refbNonScoutUnassignedAirAATargets = 'M27AirNonScoutUnassignedAirAATargets'
iAssistNearbyUnitRange = 50 --if spot an enemy air unit, will intercept it if we have friendly non-air units within this range of it

--Main trackers: Bomber
reftBomberShortlistByTech = 'M27AirBomberTargetByTechShortlist' --v31 - reworked way bombers target, so it is based on tech level of the bomber
reftBomberTargetShortlist = 'M27AirBomberTargetShortlist' --[x] is the count (1, 2, 3 etc.), [y] is the ref (refPriority, refUnit)
refiShortlistPriority = 1 --for reftBomberTargetShortlist
refiShortlistUnit = 2 --for reftBomberTargetShortlist
refiShortlistStrikeDamageWanted = 3 --e.g. the max health of the unit and any nearby shields, or a higher value if ACU or experimental
refbShortlistContainsLowPriorityTargets = 'M27AirShortlistContainsLowPriorityTargets' --true if shortlist only contains low priority targets that only want added once to a unit
refiLowPriorityStart = 'M27AirLowPriorityStart' --The priority number at which a target is low priority
--Unit local variables
local refiCurBombersAssigned = 'M27AirCurBombersAssigned' --Currently assigned to a particular unit, so know how many bombers have already been assigned
local refiLifetimeFailedBombersAssigned = 'M27AirLifetimeBombersAssigned' --All bombers assigned to target the unit that have died with it as their current target
local refiLifetimeFailedBomberMassAssigned = 'M27AirLifetimeBomberMassAssigned' --as above, but mass value of the bomber
refiBomberTargetLastAssessed = 'M27AirBomberTargetLastAssessed'
refiBomberDefencePercentRange = 'M27BomberDefencePercentRange' --v31 - replaced with refiBomberDefenceModDistance
refiBomberDefenceModDistance = 'M27BomberDefenceRange' --ai Brain value is the Modified distance (absolute value) for bomber range; individual unit value is its mod distacne to our base
refiBomberDefenceDistanceCap = 'M27BomberDefenceDistanceCap' --aiBrain, is the unmodified max distance from our base
refiBomberDefenceCriticalThreatDistance = 'M27BomberDefenceCriticalThreatDistance' --aiBrain, is the unmodified distance from our base at which should ignore if target is shielded or has AA
refiBomberIneffectivenessByDefenceModRange = 'M27AirBomberIneffectivenessByModRange' --aiBrain, [x] is the bomberdefencemoddistance value then the bomber was assigned a target, gets +1 if bomber dies having only fired <=1 bomb, gets -x for each bomb above 1 that a bomber has fired
refbBomberDefenceRestrictedByAA = 'M27BomberDefenceRestrictedByAA' --e.g. enemy has shielded flak structure or SAM in our emergency defence range
refiFailedHitCount = 'M27BomberFailedHitCount' --Whenever a bomber fires a bomb at a unit, this is increased by 1 if the bomb does nothing
refiTargetFailedHitCount = 'M27BomberTargetFailedHitCount' --Number of failed hits on a target when bomber is assigned it (so dont abort if we knew it woudl be a hard to hit target unless it's proving really hard to hit)
reftBombersAssignedLowPriorityTargets = 'M27AirBombersWithLowPriorityTargets' --List of bombers (key is unit ID+lifetimecount) whose current target is low priority
refiShieldIgnoreValue = 'M27BomberShieldIgnoreValue' --Both aibrain and bomber variable; When a bomber is assigned a target, it will record the value of shields that can be ignored.  When the value is calculated, it's set at the aibrain level
reftEngiHunterBombers = 'M27AirEngiHunterBombers' --[x] = UnitId..LifetimeCount.  Returns the bomber object
refiEngiHuntersToGet = 'M27AirEngiHuntersToGet' --returns number of engi hunter bombers wanted in lifetime

refiTimeOfLastT1BomberMexAttack = 'M27BomberTimeOfLastMexAttack' --Against aiBrain when a T1 bomber is told to attack a mex
reftMexHunterT1Bombers = 'M27AirMexHunterT1Bombers' --[x] = UnitId..LifetimeCount. Returns the bomber object
refoT1MexTarget = 'M27AirT1MexTarget' --The mex unit being targeted by MexHunterT1Bombers


--localised values
reftMovementPath = 'M27AirMovementPath'
reftGroundAttackLocation = 'M27AirGroundAttackLocation' --If give a bomber a ground attack order then will record against here so we then abort if the target unit gets too far away from it
local refiCurMovementPath = 'M27AirCurMovementPath'
reftTargetList = 'M27AirTargetList' --For bomber to track targets as objects, [a] = ref, either refiShortlistPriority or refiShortlistUnit
refiCurTargetNumber = 'M27AirCurTargetNumber' --e.g. for a bomber which is assigned objects not locations to target
local refoAirAATarget = 'M27AirAirAATarget' --Interceptor target
local reftTargetedByList = 'M27AirTargetedByList' --for interceptor target so can track mass value assigned to it, each entry is an air AA object assigned to target the unit
local refbPartOfSpecialAttack = 'M27AirPartOfLargeAttack' --True if part of special attack logic
refoTorpBomberPrimaryTarget = 'M27TorpPrimaryTarget' --Primary target of a torp bomber, so can reduce its threat damage assigned when torp bomber dies or becomes available
reftoBombersTargetingUnit = 'M27AirBombersTargetingUnit' --[x] key is the aiBrain armyindex..BomberID+UniqueCount.  Table of bombers told to target a unit (e.g. as part of a coordinated attack)
refiStrikeDamageAssigned = 'M27AirStrikeDamageAssigned'
refiCoordinatedStrikeDamageAssigned = 'M27AirCoordinatedStrikeDamage' --Used to work out how much strike damage was assigned at the start of the attack
refiMaxStrikeDamageWanted = 'M27AirMaxStrikeDamageWanted' --stored against a unit target, with the last strike damage value we wanted for it
refiTimeLastCalculatedStrikeDamageWanted = 'M27AirTimeOfMaxStrikeDamage' --Stored against a unit target
refoAirStagingAssigned = 'M27AirStagingAssigned' --Store against an air unit send to refuel, and it will track the air staging unit its been ordered to refuel at
reftAssignedRefuelingUnits = 'M27AirRefuelingUnitsAssigned' --[x]  = UnitID + lifetimecount, returns air unit told to refuel here;Store against air staging unit to track the units assigned to refuel
refiBombsDropped = 'M27AirBombsDropped'
refiLastFiredBomb = 'M27AirLastFiredBomb'
refoLastBombTarget = 'M27AirLastBombTarget'
refiModDefenceRangeAtTimeTargetAssigned = 'M27AirBomberModDefenceRangeAtTimeTargetAssigned' --returns the mod defence range at the time a bomber is told to attack a target
refoAssignedAirScout = 'M27HaveAssignedAirScout' --Assigned to a unit that wants a dedicated air scout (e.g. experimental) - the unit air scout assigned to it; also attached to air scout to indicate the unit it is assisting
refbEngiHunterMode = 'M27AirBomberEngiHunterLogic' --set to true for t1 bombers with low lifetime count who are in engi hunter mode
refbHaveDelayedTargeting = 'M27AirBomberHaveDelayedTargeting' --set to true against a bomber if it has already delayed targeting to give another engi a chance - currently used for engihunter bombers
refiGunshipPlacement = 'M27AirGunshipPlacementNumber' --Against unit (gunship) for the placement number


refiLastCoveredByAAByTech = 'M27AirLastTimeUnitHadAA' --[x] is the tech level of AA we are concerned about (e.g. 1 = 1+; 2 = 2+ 3 = 3+)
refbLastCoveredByAAByTech = 'M27AirIsUnitCoveredByAA' --[x] is the tech level of AA we are concerned about

--Build order related
refiExtraAirScoutsWanted = 'M27AirExtraAirScoutsWanted'
--refiBombersWanted = 'M27AirBombersWanted'
refiTorpBombersWanted = 'M27TorpBombersWanted'
refiAirStagingWanted = 'M27AirStagingWanted'
local iMinScoutsForMap
local iMaxScoutsForMap
local iLongScoutDelayThreshold = 60 --Only locations where we're overdue by this much will be taken into account when deciding how many scouts we want
refiAirAANeeded = 'M27AirNeedMoreAirAA'
refiAirAAWanted = 'M27AirWantedMoreAirAA'
refbBombersAreEffective = 'M27AirBombersAreEffective' --[x] = tech level, returns true/false
refbBombersAreReallyEffective = 'M27AirBombersAreReallyEffective' -- [x] = tech level, returns true/false

refiLargeBomberAttackThreshold = 'M27AirLargeBomberAttackThreshold' --How many bombers are needed before launching a large attack
refiTimesThatHaveMetLargeAttackThreshold = 'M27AirLargeBomberTimesMetThreshold' --Increases by 1 each time we meet the threshold

refiGunshipMassKilled = 'M27AirGunshipMassKilled' --Against aiBrain, mass that our gunships have killed
refiGunshipMassLost = 'M27AirGunshipMassLost' --against brain, mass in gunships that we have lost

--Bomber effectiveness (used to decide whether to keep building bombers)
reftBomberEffectiveness = 'M27AirBomberEffectiveness' --[x][y]: x = unit tech level, y = nth entry; returns subtable {MassCost}{MassKilled}
refiBomberMassCost = 'M27AirBomberMassCost' --Subtable ref
refiBomberMassKilled = 'M27AirBomberMassKilled' --Subtable ref

subrefoBomber = 'M27AirBomberUnit' --Stores the unit ref of the bomber that the table entry relates to, so can check if it is still alive

local iBombersToTrackEffectiveness = 3 --Will track the last n bombers killed

--Air threat related
refiClosestEnemyDangerousAADistToOurBase = 'M27AirClosestEnemyDangerousAADistToBase' --This will only consider cruisers+T3 AA once we have t3 air, but before that considers more AA; factors in unit range; based on dist from that unit to our base, less that unit's range
refiHighestEnemyAirThreat = 'M27HighestEnemyAirThreat' --highest ever value the enemy's air threat has reached in a single map snapshot'
refiEnemyAirAAThreat = 'M27HighestEnemyAirAAThreat'
refiHighestEverEnemyAirAAThreat = 'M27HighestEverAirAAThreat'
refiEnemyAirToGroundThreat = 'M27HighestEnemyAirToGroundThreat'
refbEnemyHasBuiltTorpedoBombers = 'M27AirHasEnemyBuildTorpBombers' --true if torp bombers have been detected for an enemy at any point in the game
refiEnemyMassInGroundAA = 'M27HighestEnemyGroundAAThreat'
refbEnemyHasHadCruisersOrT3AA = 'M27EnemyHadCruisersOrT3AA' --True if enemy had cruisers or T3 AA - used to decide if should switch to air domination mode
refbHaveAirControl = 'M27AirHaveAirControl' --Against aiBrain, true if our team has air control (Considering only M27 airAA)
refbFarBehindOnAir = 'M27AirFarBehind' --against aibrain, if our team is far behind the enemy airaa force and our own airAA force is fairly small then this should be true, means we should be less likely to do things like an early strat
refiOurFurthestAAStructureFromBase = 'M27AirFurthestAAFromBase' --Against aibrain, records T1 (if enemy has low air threat) or T2+ AA structure furthest from our base; used to limit airaa and gunship operational range when we are really far behind on air
refiOurMassInMAA = 'M27OurMassInMAA'
refiOurMAAUnitCount = 'M27OurMAAUnitCount'
refiOurMassInAirAA = 'M27OurMassInAirAA'
refiTeamMassInAirAA = 'M27AirTeamMassInAirAA'
refiTimeOfLastMercy = 'M27TimeOfLastMercy'
refbMercySightedRecently = 'M27MercySightedRecently'
reftEnemyAirFactoryByTech = 'M27AirEnemyHighestAirFactory' --Against aiBrain, [x] is the tech level, returns number of enemy air factories for the given tech level
reftNearestEnemyAirThreat = 'M27AirNearestThreat'
refoNearestEnemyAirThreat = 'M27AirNearestEnemyAirUnit'
refiNearestEnemyAirThreatActualDist = 'M27AirNearestEnemyAirUnitDist'



--Available air units
reftAvailableScouts = 'M27AirScoutsWithFuel'
reftAvailableBombers = 'M27AirAvailableBombers'
refiPreviousAvailableBombers = 'M27AirPreviousAvailableBombers' --Number of idle bombers when last checked for threats
reftAvailableTorpBombers = 'M27AirAvailableTorpBombers' --Determined by threat overseer
reftAvailableAirAA = 'M27AirAvailableAirAA'
reftAvailableTransports = 'M27AirAvailableTransports'
reftAvailableGunships = 'M27AirAvailableGunships' --For T1-T3 gunships (T4 are handled via their own logic)
refoFrontGunship = 'M27AirFrontGunship' --Location of our front gunship
--local reftLowFuelAir = 'M27AirScoutsWithLowFuel'
local reftLowFuelAir = 'M27AirLowFuelAir'

refbOnAssignment = 'M27AirOnAssignment'
--refbTorpBomberProtectingACU = 'M27AirTorpBomberProtectingACU'
reftIdleChecker = 'M27AirIdleChecker' --[x] is gametimeseconds where has been idle, so if its been idle but on assignment for >=2s then will treat as not on assignment
local refbSentRefuelCommand = 'M27AirSentRefuelCommand' --set to true when send an order to go into air staging; set to false 5s after sent an order to be unloaded
local refiCyclesOnGroundWaitingToRefuel = 'M27AirCyclesOnGroundWaitingToRefuel' --if a unit was sent a refuel command and is sat on the ground then update this

--Experimental target tracker
reftPreviousTargetByLocationCount = 'M27AirExperimentalPreviousTarget' --key is the string of the location, returns the number of times we've already gone somewhere in the last e.g. 3 minutes
refoPriorityTargetOverride = 'M27AirPriorityTargetOverride' --e.g. used for novax - will be the object that shoudl be targeted
refiTimeOfLastOverride = 'M27AirPriorityTargetTime' --Gametimeseconds that was given the override target

--Other
local refCategoryAirScout = M27UnitInfo.refCategoryAirScout
local refCategoryBomber = M27UnitInfo.refCategoryBomber
local refCategoryTorpBomber = M27UnitInfo.refCategoryTorpBomber
local refCategoryAirAA = M27UnitInfo.refCategoryAirAA
local refCategoryAirNonScout = M27UnitInfo.refCategoryAirNonScout
local iLongCycleThreshold = 4
local iLowFuelPercent = 0.25
local iLowHealthPercent = 0.55
iGunshipLowHealthPercent = 0.6

function GetAirSegmentFromPosition(tPosition)
    --returns x and z values of the segment that tPosition is in
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'GetAirSegmentFromPosition'
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code. iAirSegmentSize='..(iAirSegmentSize or 'nil')..'; tPosition='..repru(tPosition)..'; rPlayableArea='..repru(M27MapInfo.rMapPlayableArea))
    end
    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iSegmentX = math.ceil((tPosition[1] - rPlayableArea[1]) / iAirSegmentSize)
    local iSegmentZ = math.ceil((tPosition[3] - rPlayableArea[2]) / iAirSegmentSize)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code, iSegmentX,Z=' .. iSegmentX .. '-' .. iSegmentZ)
    end
    return iSegmentX, iSegmentZ
end

function GetAirPositionFromSegment(iSegmentX, iSegmentZ)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetAirPositionFromSegment'
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code')
    end

    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iPosX = (iSegmentX - 0.5) * iAirSegmentSize + rPlayableArea[1]
    local iPosZ = (iSegmentZ - 0.5) * iAirSegmentSize + rPlayableArea[2]
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code')
    end
    return { iPosX, GetTerrainHeight(iPosX, iPosZ), iPosZ }
end

function TimeSinceLastHadVisualOrIntelOfLocation()  end --Done solely to help find the below function
function GetTimeSinceLastScoutedLocation(aiBrain, tLocation)
    --Returns the game-time since we last had intel of a location
    if aiBrain[refbHaveOmniVision] then return 0
    else
        local iAirSegmentX, iAirSegmentZ = GetAirSegmentFromPosition(tLocation)
        return GetGameTimeSeconds() - (aiBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiLastScouted] or 0)
    end
end

function GetTimeSinceLastScoutedSegment(aiBrain, iAirSegmentX, iAirSegmentZ)
    if aiBrain[refbHaveOmniVision] then return 0
    else return GetGameTimeSeconds() - (aiBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiLastScouted] or 0)
    end
end

function ClearAirScoutDeathFromSegmentInFuture(aiBrain, iAirSegmentX, iAirSegmentZ)
    --CALL VIA FORKED THREAD
    local sFunctionRef = 'ClearAirScoutDeathFromSegmentInFuture'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    WaitSeconds(200)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Have we failed to reveal the area since this time?
    if GetTimeSinceLastScoutedSegment(aiBrain, iAirSegmentX, iAirSegmentZ) >= 200 then
        if aiBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiDeadScoutsSinceLastReveal] > 0 then
            aiBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiDeadScoutsSinceLastReveal] = aiBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiDeadScoutsSinceLastReveal] - 1
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordAirScoutDyingInNearbySegments(aiBrain, iBaseSegmentX, iBaseSegmentZ)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OnScoutDeath'
    local iStartX, iEndX, iStartZ, iEndZ
    iStartX = math.max(iBaseSegmentX - 1, 1)
    iStartZ = math.max(iBaseSegmentZ - 1, 1)
    iEndX = math.min(iBaseSegmentX + 1, iMapMaxAirSegmentX)
    iEndZ = math.min(iBaseSegmentZ + 1, iMapMaxAirSegmentZ)
    for iX = iStartX, iEndX, 1 do
        for iZ = iStartZ, iEndZ, 1 do
            aiBrain[reftAirSegmentTracker][iX][iZ][refiDeadScoutsSinceLastReveal] = aiBrain[reftAirSegmentTracker][iX][iZ][refiDeadScoutsSinceLastReveal] + 1
            ForkThread(ClearAirScoutDeathFromSegmentInFuture, aiBrain, iX, iZ)
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Finshed recording that scout died around segments ' .. iBaseSegmentX .. '-' .. iBaseSegmentZ)
    end
end

function ClearPreviousMovementEntries(aiBrain, oAirUnit)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ClearPreviousMovementEntries'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iMaxMovementPaths = 0
    if oAirUnit[reftMovementPath] and oAirUnit[refiCurMovementPath] and oAirUnit[refiCurMovementPath] > 1 then
        iMaxMovementPaths = table.getn(oAirUnit[reftMovementPath])
    end
    if iMaxMovementPaths > 1 then
        local iCurAirSegmentX, iCurAirSegmentZ
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': about to cycle through earlier movement paths and clear them; oAirUnit[refiCurMovementPath]=' .. oAirUnit[refiCurMovementPath] .. '; iMaxMovementPaths=' .. iMaxMovementPaths)
        end
        for iPath = 1, (oAirUnit[refiCurMovementPath] - 1), 1 do
            iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(oAirUnit[reftMovementPath][1])
            aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] - 1
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Just reduced assigned scouts for segment X-Z=' .. iCurAirSegmentX .. '-' .. iCurAirSegmentZ)
            end
            table.remove(oAirUnit[reftMovementPath], 1)
        end
        oAirUnit[refiCurMovementPath] = 1
    end
    if M27Config.M27ShowUnitNames == true and oAirUnit.GetUnitId then
        local sPath = 'nil'
        if oAirUnit[reftMovementPath] and M27Utilities.IsTableEmpty(oAirUnit[reftMovementPath][1]) == false then
            sPath = oAirUnit[reftMovementPath][1][1] .. oAirUnit[reftMovementPath][1][3]
        end
        M27PlatoonUtilities.UpdateUnitNames({ oAirUnit }, oAirUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAirUnit) .. ':MoveTo:' .. sPath)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ClearTrackersOnUnitsTargets(oAirUnit, bOnlyRemoveFirstEntry)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ClearTrackersOnUnitsTargets'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if EntityCategoryContains(categories.TECH3 * categories.BOMBER, oAirUnit.UnitId) and (M27UnitInfo.GetUnitLifetimeCount(oAirUnit) == 10 or M27UnitInfo.GetUnitLifetimeCount(oAirUnit) == 45) then bDebugMessages = true end

    --if oAirUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAirUnit) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code. oAirUnit='..oAirUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAirUnit)..'; Is the air unit target list empty='..tostring(M27Utilities.IsTableEmpty(oAirUnit[reftTargetList]))..'; Does it have a torpedo target='..tostring(M27UnitInfo.IsUnitValid(oAirUnit[refoTorpBomberPrimaryTarget]))) end
    --Further torp bomber tracking (as was having issues with current approach)
    if M27UnitInfo.IsUnitValid(oAirUnit[refoTorpBomberPrimaryTarget]) then
        local iArmyIndex = oAirUnit:GetAIBrain():GetArmyIndex()
        oAirUnit[refoTorpBomberPrimaryTarget][iArmyIndex][M27Overseer.refiAssignedThreat] = (oAirUnit[refoTorpBomberPrimaryTarget][iArmyIndex][M27Overseer.refiAssignedThreat] or 0) - oAirUnit:GetBlueprint().Economy.BuildCostMass
        if bDebugMessages == true then LOG(sFunctionRef..': Air unit '..oAirUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAirUnit)..'; Reduced assigned threat on '..oAirUnit[refoTorpBomberPrimaryTarget].UnitId..M27UnitInfo.GetUnitLifetimeCount(oAirUnit[refoTorpBomberPrimaryTarget])..'; assigned threat is now '..oAirUnit[refoTorpBomberPrimaryTarget][iArmyIndex][M27Overseer.refiAssignedThreat]) end
    end

    if M27Utilities.IsTableEmpty(oAirUnit[reftTargetList]) == false then
        --local iTotalTargets = table.getn(oAirUnit[reftTargetList])
        --local oCurTarget

        local iStrikeDamage = M27UnitInfo.GetUnitStrikeDamage(oAirUnit)
        local iMassCost = oAirUnit:GetBlueprint().Economy.BuildCostMass --Not perfect because if a bomber is assigned a target when at 50% health the target unit's assigned threat will be reduced when the bomber dies by more than it should
        local iArmyIndex = oAirUnit:GetAIBrain():GetArmyIndex()
        local oUnit
        for iUnit, tSubtable in oAirUnit[reftTargetList] do
            oUnit = tSubtable[refiShortlistUnit]
            if bDebugMessages == true then LOG(sFunctionRef..': Considering entry '..iUnit..' in bomber '..oAirUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAirUnit)..' target list. Is unit dead='..tostring(oUnit.Dead)) end
            if not (oUnit.Dead) then
                if bDebugMessages == true then LOG(sFunctionRef..': Clearing oUnit as a target, oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                if oUnit[reftoBombersTargetingUnit] then oUnit[reftoBombersTargetingUnit][oUnit:GetAIBrain():GetArmyIndex()..oAirUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAirUnit)] = nil end
                if oUnit[refiCurBombersAssigned] == nil then
                    oUnit[refiCurBombersAssigned] = 0
                else
                    oUnit[refiCurBombersAssigned] = oUnit[refiCurBombersAssigned] - 1
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Will reduce strike damage assigned to the target oUnit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; oUnit[refiStrikeDamageAssigned]='..(oUnit[refiStrikeDamageAssigned] or 'nil')..'; iStrikeDamage='..iStrikeDamage) end
                if oUnit[refiStrikeDamageAssigned] == nil then
                    oUnit[refiStrikeDamageAssigned] = 0
                else
                    oUnit[refiStrikeDamageAssigned] = math.max(0, oUnit[refiStrikeDamageAssigned] - iStrikeDamage)
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Target unit strike damage assigned after update='..oUnit[refiStrikeDamageAssigned]) end

                if oUnit[iArmyIndex][M27Overseer.refiAssignedThreat] then
                    oUnit[iArmyIndex][M27Overseer.refiAssignedThreat] = math.max(0, oUnit[iArmyIndex][M27Overseer.refiAssignedThreat] - iMassCost)
                end
            end
            if bOnlyRemoveFirstEntry then
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Only wanted to remove first entry so will abort now.  Will list out if any other units in the target list. Is target list empty='..tostring(M27Utilities.IsTableEmpty(oAirUnit[reftTargetList])))
                    if not(M27Utilities.IsTableEmpty(oAirUnit[reftTargetList])) then
                        for iEntry, oEntry in oAirUnit[reftTargetList] do
                            LOG(sFunctionRef..': iEntry='..iEntry..'; Is unit valid='..tostring(M27UnitInfo.IsUnitValid(tSubtable[refiShortlistUnit])))
                            if M27UnitInfo.IsUnitValid(tSubtable[refiShortlistUnit]) then LOG(sFunctionRef..': the unit='..tSubtable[refiShortlistUnit].UnitId..M27UnitInfo.GetUnitLifetimeCount(tSubtable[refiShortlistUnit])) end
                        end
                    end
                end
                break
            end
        end
    end
    if oAirUnit[refoAirAATarget] then
        if M27Utilities.IsTableEmpty(oAirUnit[refoAirAATarget][reftTargetedByList]) == false then
            for iTargetedBy, oTargetedBy in oAirUnit[refoAirAATarget][reftTargetedByList] do
                if oTargetedBy == oAirUnit then
                    table.remove(oAirUnit[refoAirAATarget][reftTargetedByList], iTargetedBy)
                    break
                end
            end
        end
        oAirUnit[refoAirAATarget] = nil
    end
    if M27Config.M27ShowUnitNames == true and oAirUnit.GetUnitId then
        M27PlatoonUtilities.UpdateUnitNames({ oAirUnit }, oAirUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAirUnit) .. ':TargetsCleared')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ClearAirUnitAssignmentTrackers(aiBrain, oAirUnit, bDontIssueCommands)
    --Clears a units commands and trackers and tells it to move ot the nearest rally point; if bDontIssueCommands is true then instead just clears trackers and nothing else
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ClearAirUnitAssignmentTrackers'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if M27UnitInfo.GetUnitTechLevel(oAirUnit) == 4 and M27UnitInfo.GetUnitLifetimeCount(oAirUnit) == 1 then bDebugMessages = true end
    --if M27UnitInfo.GetUnitTechLevel(oAirUnit) == 3 and M27UnitInfo.GetUnitLifetimeCount(oAirUnit) == 1 then bDebugMessages = true end

    --if oAirUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAirUnit) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': oAirUnit=' .. oAirUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAirUnit) .. '; Gametime=' .. GetGameTimeSeconds())
    end
    local iMaxMovementPaths = 0
    if oAirUnit[reftMovementPath] then
        iMaxMovementPaths = table.getn(oAirUnit[reftMovementPath])
    end
    if iMaxMovementPaths > 0 then
        local iCurAirSegmentX, iCurAirSegmentZ
        for iCurTarget = oAirUnit[refiCurMovementPath], iMaxMovementPaths, 1 do
            iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(oAirUnit[reftMovementPath][iCurTarget])
            aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] - 1
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Just reduced assigned scouts for segment X-Z=' .. iCurAirSegmentX .. '-' .. iCurAirSegmentZ)
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Clearing movement path and making unit available for future use')
    end
    oAirUnit[refbOnAssignment] = false
    oAirUnit[reftMovementPath] = {}
    ClearTrackersOnUnitsTargets(oAirUnit) --This MUST come before clearing the target list
    oAirUnit[reftTargetList] = {}
    oAirUnit[refiCurTargetNumber] = 0
    oAirUnit[reftGroundAttackLocation] = nil
    oAirUnit[refiGunshipPlacement] = nil

    if not (bDontIssueCommands) then
        M27Utilities.IssueTrackedClearCommands({ oAirUnit })
        if EntityCategoryContains(M27UnitInfo.refCategoryTorpBomber, oAirUnit.UnitId) then
            IssueAggressiveMove({ oAirUnit }, GetAirRallyPoint(aiBrain))
        else
            --Consider bomber micro - if will want to refuel, are low on health, or are about to head into lots of AA, then want to use micro to turn around rather than carrying on current path
            local tRallyPoint = GetAirRallyPoint(aiBrain)
            local bMicroTurn = false

            if not(oAirUnit[M27UnitInfo.refbSpecialMicroActive]) and EntityCategoryContains(refCategoryBomber - categories.TECH1 - refCategoryTorpBomber, oAirUnit.UnitId) and not(oAirUnit[refbSentRefuelCommand]) and not(oAirUnit[refoAirStagingAssigned]) then
                --Do we have low health or fuel? Then will want to return to base
                if M27UnitInfo.GetUnitHealthPercent(oAirUnit) < iLowHealthPercent or oAirUnit:GetFuelRatio() < iLowFuelPercent then
                    --Do we have any air staging units?
                    if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirStaging) > 0 or EntityCategoryContains(categories.EXPERIMENTAL, oAirUnit.UnitId) then
                        --DOnt use micro if have a strat bomber and enemy doesnt have T3 AA (since risk dying to T1/T2 AA if slow down even if cant see it at the moment)
                        if aiBrain[refbEnemyHasHadCruisersOrT3AA] or not(EntityCategoryContains(categories.TECH3, oAirUnit.UnitId)) or (aiBrain[refiEnemyAirAAThreat] >= 750 and GetAirAAThreatAroundPosition(aiBrain, oAirUnit:GetPosition(), 4) >= 500) then
                            bMicroTurn = true
                        end
                    end
                end
            end
            if bMicroTurn then
                oAirUnit[M27UnitInfo.refbSpecialMicroActive] = true --To make sure this triggers now rather than when the forkthread starts
                ForkThread(M27UnitMicro.TurnAirUnitAndMoveToTarget, aiBrain, oAirUnit, tRallyPoint, 15)
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Telling oAirUnit '..oAirUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAirUnit)..' to move to rally point '..repru(tRallyPoint)) end
                IssueMove({ oAirUnit }, tRallyPoint)
            end
        end
    end
    --Refueling trackers:
    oAirUnit[refbSentRefuelCommand] = false
    if oAirUnit[refoAirStagingAssigned] then
        if oAirUnit[refoAirStagingAssigned][reftAssignedRefuelingUnits] then
            oAirUnit[refoAirStagingAssigned][reftAssignedRefuelingUnits][oAirUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAirUnit)] = nil
        end
        oAirUnit[refoAirStagingAssigned] = nil
    end

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': refbOnAssignment=' .. tostring(oAirUnit[refbOnAssignment]))
    end

    --Transport trackers
    if EntityCategoryContains(M27UnitInfo.refCategoryTransport, oAirUnit.UnitId) then
        M27Transport.ClearTransportTrackers(aiBrain, oAirUnit)
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)

end

function MakeSegmentsAroundPositionHighPriority(aiBrain, tPosition, iSegmentSize)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MakeSegmentsAroundPositionHighPriority'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code')
    end
    local iBaseAirSegmentX, iBaseAirSegmentZ = GetAirSegmentFromPosition(tPosition)
    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iMaxSegmentSizeX, iMaxSegmentSizeZ = GetAirSegmentFromPosition({ rPlayableArea[3], 0, rPlayableArea[4] })
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': iMaxSegmentSizeX=' .. iMaxSegmentSizeX .. '; iMaxSegmentSizeZ=' .. iMaxSegmentSizeZ)
    end

    for iAirSegmentX = math.max(1, iBaseAirSegmentX - iSegmentSize), math.min(iMaxSegmentSizeX, iBaseAirSegmentX + iSegmentSize) do
        for iAirSegmentZ = math.max(1, iBaseAirSegmentZ - iSegmentSize), math.min(iMaxSegmentSizeZ, iBaseAirSegmentZ + iSegmentSize) do
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': iAirSegmentX=' .. iAirSegmentX .. '; iAirSegmentZ=' .. iAirSegmentZ)
                LOG('aiBrain[refiIntervalHighestPriority]=' .. aiBrain[refiIntervalHighestPriority])
            end

            aiBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiCurrentScoutingInterval] = aiBrain[refiIntervalHighestPriority]
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function CheckForUnseenKiller(aiBrain, oKilled, oKiller)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CheckForUnseenKiller'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Air scout specific - if air scout died then also update the area around the killer to flag an air scout as being killed
    if EntityCategoryContains(refCategoryAirScout, oKilled.UnitId) == true then
        local iAirSegmentX, iAirSegmentZ = GetAirSegmentFromPosition(oKilled:GetPosition())
        RecordAirScoutDyingInNearbySegments(aiBrain, iAirSegmentX, iAirSegmentZ)
    else
        --If unit dies, check if have intel on a nearby enemy, and if not then make it a high priority area for scouting
        --CanSeeUnit(aiBrain, oUnit, bTrueIfOnlySeeBlip)
        if oKiller.GetAIBrain then
            local bJustNeedBlip = true
            if EntityCategoryContains(categories.INDIRECTFIRE * categories.LAND + categories.STRUCTURE, oKiller.UnitId) then bJustNeedBlip = false end
            if not (M27Utilities.CanSeeUnit(aiBrain, oKiller, bJustNeedBlip)) then
                MakeSegmentsAroundPositionHighPriority(aiBrain, oKilled:GetPosition(), 3)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Unit died from unseen killer, so will flag to scout it sooner. Killed position='..repru(oKilled:GetPosition()))
                end
                --If unit is part of a platoon, tell that platoon to retreat if it cant see any nearby enemies
                local oPlatoon = oKilled.PlatoonHandle
                if oPlatoon then
                    if oPlatoon[M27PlatoonUtilities.refiCurrentUnits] > 1 then
                        if not (oPlatoon[M27PlatoonUtilities.refiEnemiesInRange] > 0 or oPlatoon[M27PlatoonUtilities.refiEnemyStructuresInRange] > 0) then
                            --No nearby units to the platoon, so retreat unless platoon already running
                            if not (oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionTemporaryRetreat) and not (oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionDisband) then
                                oPlatoon[M27PlatoonUtilities.refbOverseerAction] = true
                                oPlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionRun
                            end
                        end
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ResetBomberEffectiveness(aiBrain, iTechLevel, iDelayInTicks)
    --Call via forkthread
    WaitTicks(iDelayInTicks)
    aiBrain[refbBombersAreEffective][iTechLevel] = true
end

function UpdateBomberEffectiveness(aiBrain, oBomber, bBomberNotDead)
    --Called either when bomber has died, or when it has fired a bomb (in the latter case, bBomberNotDead should be set to true so we dont add a new entry to the table but instead overwrite the last entry)
    --Track how effective the bomber was
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateBomberEffectiveness'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if EntityCategoryContains(categories.TECH3, oBomber.UnitId) then bDebugMessages = true end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Checking if have a unitID for dead bomber')
    end
    if oBomber.GetUnitId and oBomber.GetBlueprint then
        if bDebugMessages == true then LOG(sFunctionRef..': Bomber has a unit ID and blueprint. ID='..oBomber.UnitId) end
        --T1 bomber defence range effectiveness tracking:
        if oBomber[refiModDefenceRangeAtTimeTargetAssigned] and EntityCategoryContains(categories.TECH1, oBomber.UnitId) then
            local iAdjust = 1.5
            if bBomberNotDead then --fired a bomb but still alive
                iAdjust = -1
            end
            aiBrain[refiBomberIneffectivenessByDefenceModRange][oBomber[refiModDefenceRangeAtTimeTargetAssigned]] = (aiBrain[refiBomberIneffectivenessByDefenceModRange][oBomber[refiModDefenceRangeAtTimeTargetAssigned]] or 0) + iAdjust
            if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[refiBomberIneffectivenessByDefenceModRange][oBomber[refiModDefenceRangeAtTimeTargetAssigned]]='..aiBrain[refiBomberIneffectivenessByDefenceModRange][oBomber[refiModDefenceRangeAtTimeTargetAssigned]]..'; oBomber[refiModDefenceRangeAtTimeTargetAssigned]='..oBomber[refiModDefenceRangeAtTimeTargetAssigned]) end
        end

        if not (EntityCategoryContains(M27UnitInfo.refCategoryTorpBomber, oBomber:GetBlueprint().BlueprintId)) then
            if bDebugMessages == true then LOG(sFunctionRef..': Dealing with a normal bomber') end
            local iMassKilled = (oBomber.VetExperience or oBomber.Sync.totalMassKilled or 0)
            if iMassKilled == nil then
                iMassKilled = 0
            end
            local iExistingEntries
            local tNewEntry = {}
            local iTechLevel = M27UnitInfo.GetUnitTechLevel(oBomber)
            if M27Utilities.IsTableEmpty(aiBrain[reftBomberEffectiveness]) then
                aiBrain[reftBomberEffectiveness] = {}
                for iTech = 1, 4 do
                    aiBrain[reftBomberEffectiveness][iTech] = {}
                end
                iExistingEntries = 0
            else
                iExistingEntries = table.getn(aiBrain[reftBomberEffectiveness][iTechLevel])
            end
            tNewEntry[refiBomberMassCost] = oBomber:GetBlueprint().Economy.BuildCostMass
            tNewEntry[refiBomberMassKilled] = (oBomber.VetExperience or oBomber.Sync.totalMassKilled or 0)
            tNewEntry[subrefoBomber] = oBomber

            if not (bBomberNotDead) or iExistingEntries == 0 then
                table.insert(aiBrain[reftBomberEffectiveness][iTechLevel], 1, tNewEntry)
                iExistingEntries = iExistingEntries + 1
            else
                aiBrain[reftBomberEffectiveness][iTechLevel][1] = tNewEntry
            end

            if iExistingEntries > iBombersToTrackEffectiveness then
                table.remove(aiBrain[reftBomberEffectiveness][iTechLevel], iExistingEntries)
            end
            if bDebugMessages == true then LOG(sFunctionRef..': About to check if still want to build bombers. iExistingEntries='..iExistingEntries) end

            --Do we still want to build bombers?
            local bNoEffectiveBombers = true
            local iEffectiveMinRatio = 0.5
            if iExistingEntries >= 3 then
                for iLastBomber, tSubtable in aiBrain[reftBomberEffectiveness][iTechLevel] do
                    if tSubtable[refiBomberMassKilled] / tSubtable[refiBomberMassCost] >= iEffectiveMinRatio then
                        bNoEffectiveBombers = false
                        break
                    end
                end
            else
                bNoEffectiveBombers = false
            end
            aiBrain[refbBombersAreEffective][iTechLevel] = not (bNoEffectiveBombers)
            aiBrain[refbBombersAreReallyEffective][iTechLevel] = false
            if tNewEntry[refiBomberMassKilled] > tNewEntry[refiBomberMassCost] + 50 then
                aiBrain[refbBombersAreReallyEffective][iTechLevel] = true
            end
            --If higher tier bomber is ineffective then lower tier ones will be as well
            if not(aiBrain[refbBombersAreReallyEffective]) then aiBrain[refbBombersAreReallyEffective] = {} end
            if not(aiBrain[refbBombersAreReallyEffective]) then aiBrain[refbBombersAreReallyEffective] = {} end
            if bDebugMessages == true then LOG(sFunctionRef..': If higher tier ineffective will make lower tier ineffective. iTechLevel='..iTechLevel..'; aiBrain[refbBombersAreReallyEffective]='..repru(aiBrain[refbBombersAreReallyEffective])..'; aiBrain[refbBombersAreReallyEffective]='..repru(aiBrain[refbBombersAreReallyEffective])) end
            if iTechLevel > 1 and not (aiBrain[refbBombersAreReallyEffective][iTechLevel]) then
                for iCurTechLevel = 1, (iTechLevel - 1), 1 do
                    if bDebugMessages == true then LOG(sFunctionRef..': Setting effectiveness for tech level '..iCurTechLevel..' to false') end
                    if not (aiBrain[refbBombersAreEffective][iTechLevel]) then
                        aiBrain[refbBombersAreEffective][iCurTechLevel] = false
                    end
                    aiBrain[refbBombersAreReallyEffective][iCurTechLevel] = false
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Finished setting bomber lower tech level effectiveness') end
            end
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Is bomber dead='..tostring((bBomberNotDead or false))..'; iBomberMassCost=' .. oBomber:GetBlueprint().Economy.BuildCostMass .. '; iMassKilled=' .. iMassKilled .. '; bNoEffectiveBombers=' .. tostring(bNoEffectiveBombers))
            end

            --If this was one of our last t3 bombers then reset the flag for effectiveness after a while (for long games we might want to retry bombers again)
            if iTechLevel == 3 and bNoEffectiveBombers and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryBomber * M27UnitInfo.ConvertTechLevelToCategory(iTechLevel)) <= 1 then
                --6 mins would be 6*60 seconds, and want the number of ticks; will do every 7 minuts
                if bDebugMessages == true then LOG(sFunctionRef..': Will reset bomber effectiveness') end
                ForkThread(ResetBomberEffectiveness, aiBrain, iTechLevel, 7 * 60 * 10)
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)

end

function OnBomberDeath(aiBrain, oDeadBomber)
    --Track how effective the bomber was
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OnBomberDeath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Checking if have a unitID for dead bomber')
    end
    if oDeadBomber.GetUnitId then
        local oBomberBP = oDeadBomber:GetBlueprint()
        local iBomberMassCost = oBomberBP.Economy.BuildCostMass

        --Record against the bomber's target that a bomber died trying to kill it
        if oDeadBomber[refiCurTargetNumber] == 1 and oDeadBomber[reftTargetList][oDeadBomber[refiCurTargetNumber]][refiShortlistUnit] then
            oDeadBomber[reftTargetList][oDeadBomber[refiCurTargetNumber]][refiShortlistUnit][refiLifetimeFailedBombersAssigned] = (oDeadBomber[reftTargetList][oDeadBomber[refiCurTargetNumber]][refiShortlistUnit][refiLifetimeFailedBombersAssigned] or 0) + 1
            oDeadBomber[reftTargetList][oDeadBomber[refiCurTargetNumber]][refiShortlistUnit][refiLifetimeFailedBomberMassAssigned] = (oDeadBomber[reftTargetList][oDeadBomber[refiCurTargetNumber]][refiShortlistUnit][refiLifetimeFailedBomberMassAssigned] or 0) + oBomberBP.Economy.BuildCostMass
        end

        UpdateBomberEffectiveness(aiBrain, oDeadBomber, false)
    end

    --Update units it was targetting to show them as no longer having bomber strike damage assigned
    ClearTrackersOnUnitsTargets(oDeadBomber)

    --Check if bomber was in the table of bombers targetting low prioritiy targets
    if M27Utilities.IsTableEmpty(aiBrain[reftBombersAssignedLowPriorityTargets]) == false then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': oDeadBomber=' .. oDeadBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oDeadBomber) .. '; will remove from table of bombers with low priority targets')
        end
        aiBrain[reftBombersAssignedLowPriorityTargets][oDeadBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oDeadBomber)] = nil
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function OnScoutDeath(aiBrain, oDeadScout)
    --Get scouts current movement target, and update its trackers to show it no longer has as many scouts assigned and we have a dead scout
    --also flags a dead scout in the segments around where the scout died, and the segments around its current movement path target
    local sFunctionRef = 'OnScoutDeath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if oDeadScout[reftMovementPath] and oDeadScout[refiCurMovementPath] then
        --Cycle through remaining points on movement path and note they're no longer assigned to this scout
        local tFirstTarget
        if oDeadScout[reftMovementPath] and oDeadScout[refiCurMovementPath] then
            tFirstTarget = oDeadScout[reftMovementPath][oDeadScout[refiCurMovementPath]]
            if M27Utilities.IsTableEmpty(tFirstTarget) == true then
                tFirstTarget = oDeadScout:GetPosition()
            end
            local iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(tFirstTarget)
            RecordAirScoutDyingInNearbySegments(aiBrain, iCurAirSegmentX, iCurAirSegmentZ)
        end
    end
    ClearAirUnitAssignmentTrackers(aiBrain, oDeadScout, true)

    --Update all nearby segments to show a scout has died
    iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(oDeadScout:GetPosition())
    RecordAirScoutDyingInNearbySegments(aiBrain, iCurAirSegmentX, iCurAirSegmentZ)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function OnAirAADeath(oDeadAirAA)
    local sFunctionRef = 'OnAirAADeath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if oDeadAirAA[refoAirAATarget] and M27Utilities.IsTableEmpty(oDeadAirAA[refoAirAATarget][reftTargetedByList]) == false then
        for iTargetedBy, oTargetedBy in oDeadAirAA[refoAirAATarget][reftTargetedByList] do
            if oTargetedBy == oDeadAirAA then
                table.remove(oDeadAirAA[refoAirAATarget][reftTargetedByList], iTargetedBy)
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function CheckForBetterBomberTargets(oBomber, bOneOff)
    local sFunctionRef = 'CheckForBetterBomberTargets'
    --bOneOff - if true, then only run this once (e.g. in response to bomb being fired); otherwise will create a loop
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    --if M27UnitInfo.GetUnitTechLevel(oBomber) == 3 then bDebugMessages = true end

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code, oBomber=' .. oBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oBomber))
        LOG(sFunctionRef .. ': Current target=' .. oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit].UnitId)
    end
    local iBomberTechLevel = M27UnitInfo.GetUnitTechLevel(oBomber)
    local aiBrain = oBomber:GetAIBrain()
    if not (bOneOff) then
        WaitSeconds(1)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Finished waiting 1 second for bomber ' .. oBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oBomber))
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tShortlistToPickFrom
    local iShortlistCount


    while M27UnitInfo.IsUnitValid(oBomber) do
        if M27Utilities.IsTableEmpty(oBomber[reftTargetList]) == false then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Bomber target list isnt empty. oBomber[refiCurTargetNumber]=' .. oBomber[refiCurTargetNumber])
                if oBomber[reftTargetList] and oBomber[refiCurTargetNumber] and oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit] then
                    LOG('Cur target priority=' .. oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistPriority])
                    LOG('Is target valid=' .. tostring(M27UnitInfo.IsUnitValid(oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit])))
                end
            end

            --Is the first unit on the shortlist a higher priority than our current target?
            if oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistPriority] > 1 and not(M27Utilities.IsTableEmpty(aiBrain[reftBomberShortlistByTech][iBomberTechLevel])) and oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistPriority] > aiBrain[reftBomberShortlistByTech][iBomberTechLevel][1][refiShortlistPriority] then
                --Want to change our current target and instead get the nearest target on the shortlist, unless we are really close to our current target
                local iMaxPriority = oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistPriority] - 1
                local iNearestHighPriority = M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit]:GetPosition()) - (40 * iBomberTechLevel)
                if iBomberTechLevel >= 3 then
                    iNearestHighPriority = iNearestHighPriority - 30
                end
                local iShortlistRef, iCurDistanceFromBomber
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Want to change current target and get the nearest one on the shortlist if its not too far away; iMaxPriority=' .. iMaxPriority .. '; iNearestHighPriority=' .. iNearestHighPriority)
                end
                if iNearestHighPriority > 0 then
                    tShortlistToPickFrom = {}
                    iShortlistCount = 0
                    local oNewTarget
                    local iHighestPriority = 1000
                    for iAltUnit, tSubtable in aiBrain[reftBomberShortlistByTech][iBomberTechLevel] do
                        if tSubtable[refiShortlistPriority] <= iMaxPriority and tSubtable[refiShortlistUnit] and not (tSubtable[refiShortlistUnit].Dead) then
                            iShortlistCount = iShortlistCount + 1
                            tShortlistToPickFrom[iShortlistCount] = tSubtable[refiShortlistUnit]
                            if tSubtable[refiShortlistPriority] < iHighestPriority then iHighestPriority = tSubtable[refiShortlistPriority] end
                        end
                    end
                    if iShortlistCount > 0 then
                        oNewTarget = GetBestBomberTarget(oBomber, tShortlistToPickFrom, 0.5)
                        if oNewTarget then
                            --if oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end
                            ClearAirUnitAssignmentTrackers(aiBrain, oBomber, true)
                            TrackBomberTarget(oBomber, oNewTarget, iHighestPriority)
                            M27Utilities.IssueTrackedClearCommands({ oBomber })
                            TellBomberToAttackTarget(oBomber, oNewTarget, false, false)
                            if bDebugMessages == true then LOG(sFunctionRef..': Told bomber '..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..' to clear its current target and attack a new target '..oNewTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oNewTarget)) end
                            break --Need to stop or else risk this function being called numerous times at once for the same unit
                        end
                    end
                else
                    break
                end
            else
                break
            end
        else
            break
        end

        --Stop looking for changes in targets once get within 100 of cur target (will re-assess whenever we fire a bomb instead)
        if bOneOff then
            break
        else
            local iSearchRange = 100
            if EntityCategoryContains(categories.TECH3, oBomber.UnitId) or EntityCategoryContains(categories.EXPERIMENTAL, oBomber.UnitId) then
                iSearchRange = iSearchRange + 100
            end
            if M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit]:GetPosition()) < iSearchRange then
                break
            end
        end

        if not (bOneOff) then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitSeconds(1)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        else
            break --redundancy - shouldnt need but dont want infinite loop
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetMaxStrikeDamageWanted(oUnit)
    local sFunctionRef = 'GetMaxStrikeDamageWanted'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iMaxUnitStrikeDamageWanted
    local iCurUnitShield, iCurUnitMaxShield

    if GetGameTimeSeconds() - (oUnit[refiTimeLastCalculatedStrikeDamageWanted] or -10000) > 1 then
        oUnit[refiTimeLastCalculatedStrikeDamageWanted] = GetGameTimeSeconds()

        if oUnit:GetFractionComplete() < 1 then
            --If dealing with AA or shield then base on max health, otherwise base on lower of max health and 1.25 * cur health; for shields base on max shield health if completed construction
            if EntityCategoryContains(M27UnitInfo.refCategoryGroundAA + M27UnitInfo.refCategoryFixedShield, oUnit.UnitId) then
                iMaxUnitStrikeDamageWanted = oUnit:GetMaxHealth()
            else
                iMaxUnitStrikeDamageWanted = math.min(oUnit:GetHealth() * 1.25, oUnit:GetMaxHealth())
            end
        else
            iCurUnitShield, iCurUnitMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oUnit)
            iMaxUnitStrikeDamageWanted = math.min(oUnit:GetHealth() * 1.25, oUnit:GetMaxHealth()) + iCurUnitMaxShield
        end
        --Is the unit under a shield? If so then increase the strike damage unless the unit is a shield itself
        local tNearbyEnemyShields
        if iCurUnitMaxShield == 0 then
            iMaxUnitStrikeDamageWanted = iMaxUnitStrikeDamageWanted + M27Logic.IsTargetUnderShield(oUnit:GetAIBrain(), oUnit, 0, true)
        end
        if EntityCategoryContains(categories.COMMAND + categories.EXPERIMENTAL, oUnit.UnitId) then
            iMaxUnitStrikeDamageWanted = iMaxUnitStrikeDamageWanted * 1.3
        elseif iMaxUnitStrikeDamageWanted >= 12000 then iMaxUnitStrikeDamageWanted = iMaxUnitStrikeDamageWanted * 1.15
        end

        oUnit[refiMaxStrikeDamageWanted] = iMaxUnitStrikeDamageWanted
    else
        iMaxUnitStrikeDamageWanted = oUnit[refiMaxStrikeDamageWanted]
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iMaxUnitStrikeDamageWanted
end

function ConsiderRemovalFromShortlist(aiBrain, iShortlistRef)
    local sFunctionRef = 'ConsiderRemovalFromShortlist'
    local bRemoved = false
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --If strike damage assigned to target is high enough, remove it from the shortlist of bomber targets

    if aiBrain[reftBomberTargetShortlist][iShortlistRef][refiShortlistUnit][refiStrikeDamageAssigned] > GetMaxStrikeDamageWanted(aiBrain[reftBomberTargetShortlist][iShortlistRef][refiShortlistUnit]) then
        --Already have enoguh strike damage assigned
        table.remove(aiBrain[reftBomberTargetShortlist], iShortlistRef)
        bRemoved = true
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bRemoved
end

function GetAirRallyPoint(aiBrain)
    local sFunctionRef = 'GetAirRallyPoint'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local iFurthestFromStart = 0
    local iNearestRallyPoint, iCurDistanceToStart
    local iMaxDistance = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.4
    --If are turtling then have the air rally point 30 behind our chokepoint
    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle then iMaxDistance = math.min(iMaxDistance, M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27MapInfo.reftChokepointBuildLocation])-30) end

    --Override for all of this - rally at ACU if it is in water and taking damage from torps
    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyProtectACU and GetGameTimeSeconds() - (M27Utilities.GetACU(aiBrain)[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage] or -100) <= 30 and M27UnitInfo.IsUnitUnderwater(M27Utilities.GetACU(aiBrain)) and M27UnitInfo.IsUnitValid(M27Utilities.GetACU(aiBrain)[M27Overseer.refoUnitDealingUnseenDamage]) and EntityCategoryContains(categories.ANTINAVY + categories.OVERLAYANTINAVY, M27Utilities.GetACU(aiBrain)[M27Overseer.refoUnitDealingUnseenDamage].UnitId) then
        if bDebugMessages == true then LOG(sFunctionRef..': ACU is in trouble underwater so will make our rally point the ACU so we are more likely to be able to protect it from navy') end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return M27Utilities.GetACU(aiBrain):GetPosition()
    else

        if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftLocationFromStartNearestThreat]) == false then iMaxDistance = math.min(iMaxDistance, M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.reftLocationFromStartNearestThreat]) - 30) end

        --[[local tNearbyEnemyAir = aiBrain:GetUnitsAroundPoint(refCategoryAirAA, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iMaxDistance + 60, 'Enemy')
        if M27Utilities.IsTableEmpty(tNearbyEnemyAir) == false then
            local oNearestAir = M27Utilities.GetNearestUnit(tNearbyEnemyAir, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain)
            iMaxDistance = M27Utilities.GetDistanceBetweenPositions(oNearestAir:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) - 60
        end--]]
        if M27UnitInfo.IsUnitValid(aiBrain[refoNearestEnemyAirThreat]) then iMaxDistance = M27Utilities.GetDistanceBetweenPositions(aiBrain[refoNearestEnemyAirThreat]:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) - 60 end
        iMaxDistance = math.min(iMaxDistance, aiBrain[M27Overseer.refiNearestT2PlusNavalThreat] - 150)
        M27MapInfo.RecordAllRallyPoints(aiBrain)
        if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftRallyPoints]) then
            if GetGameTimeSeconds() >= 150 then
                M27Utilities.ErrorHandler('Dont have any rally point >=2.5m into the game, wouldve expected to have generated intel paths by now; will return base as a rally point', true)
            end
            if bDebugMessages == true then LOG(sFunctionRef..': No rally points so will return start position') end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        else
            if iMaxDistance >= 30 then

                --local tTarget = M27Utilities.MoveInDirection(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)), iMaxDistance)
                if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through every rally point to get the one furthest from the base that is still within the max distance. iMaxDistance='..iMaxDistance) end
                for iRallyPoint, tRallyPoint in aiBrain[M27MapInfo.reftRallyPoints] do
                    iCurDistanceToStart = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tRallyPoint)
                    if bDebugMessages == true then LOG(sFunctionRef..': tRallyPoint='..repru(tRallyPoint)..'; iCurDistanceToStart='..iCurDistanceToStart..'; iMaxDistance='..iMaxDistance..'; iFurthestFromStart='..iFurthestFromStart) end
                    if iCurDistanceToStart <= iMaxDistance and iCurDistanceToStart > iFurthestFromStart then
                        iNearestRallyPoint = iRallyPoint
                        iFurthestFromStart = iCurDistanceToStart
                        if bDebugMessages == true then LOG(sFunctionRef..': Will set the nearest rally point to iNearestRallypoint '..iNearestRallyPoint..' which is '..repru(aiBrain[M27MapInfo.reftRallyPoints][iNearestRallyPoint])) end
                    end
                end
            end



            if bDebugMessages == true then LOG(sFunctionRef..': Returning rally point '..repru(aiBrain[M27MapInfo.reftRallyPoints][iNearestRallyPoint])) end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            if not(iNearestRallyPoint) then return M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
            else
                return {aiBrain[M27MapInfo.reftRallyPoints][iNearestRallyPoint][1], aiBrain[M27MapInfo.reftRallyPoints][iNearestRallyPoint][2], aiBrain[M27MapInfo.reftRallyPoints][iNearestRallyPoint][3]}
            end
        end
    end
end

function GetAirAAMainRallyPoint(aiBrain)
    --Allows most of our air to escort key units of interest
    local sFunctionRef = 'GetAirAAMainRallyPoint'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local tAirRallyPoint

    --First get the position of the nearest unit that we want to have our rally point by:

    --Do we or an ally in our subteam have air experimentals? If so set the rally point to the nearest air experimental
    local tFriendlyExperimentals = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirNonScout * categories.EXPERIMENTAL, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Ally')
    local bUseRallyPointIfCloser = false

    if M27Utilities.IsTableEmpty(tFriendlyExperimentals) == false then
        local iNearestDistance = 10000
        local iCurDistance
        for iExperimental, oExperimental in tFriendlyExperimentals do
            if oExperimental:GetFractionComplete() >= 1 and oExperimental:GetAIBrain().M27Subteam == aiBrain.M27Subteam then
                iCurDistance = M27Utilities.GetDistanceBetweenPositions(oExperimental:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                if iCurDistance < iNearestDistance then
                    tAirRallyPoint = oExperimental:GetPosition()
                    iNearestDistance = iCurDistance
                end
            end
        end
    end
    if not(tAirRallyPoint) then
        bUseRallyPointIfCloser = true
        --Have we only built a few strat bombers? If so then escort the one closest to the enemy base
        if M27Conditions.GetLifetimeBuildCount(aiBrain, refCategoryBomber * categories.TECH3) <= 3 then
            local tStratBombers = aiBrain:GetListOfUnits(refCategoryBomber * categories.TECH3, false, true)
            local oNearestStrat = M27Utilities.GetNearestUnit(tStratBombers, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
            if oNearestStrat then
                tAirRallyPoint = oNearestStrat:GetPosition()
                if bDebugMessages == true then LOG(sFunctionRef..': Setting rally point baesd on the nearest strat to enemy base, strat='..oNearestStrat.UnitId..M27UnitInfo.GetUnitLifetimeCount(oNearestStrat)..' at position '..repru(oNearestStrat:GetPosition())..'; will adjust position shortly') end
            end
        end
        if not(tAirRallyPoint) then
            --Do we have a gunship? If so then pick this as the air rally point
            if M27UnitInfo.IsUnitValid(aiBrain[refoFrontGunship]) then
                tAirRallyPoint = aiBrain[refoFrontGunship]:GetPosition()
                if bDebugMessages == true then LOG(sFunctionRef..': Setting rally point based on front gunship '..aiBrain[refoFrontGunship].UnitId..M27UnitInfo.GetUnitLifetimeCount(aiBrain[refoFrontGunship])) end
            end
        end
    end

    --Now that we have the unit, update our arlly point to move towards our base until there is no enemy groundAA nearby

    if M27Utilities.IsTableEmpty(tAirRallyPoint) == false then
        local bKeepMovingBack = true
        while bKeepMovingBack do
            bKeepMovingBack = false
            tAirRallyPoint = M27Utilities.MoveTowardsTarget(tAirRallyPoint, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 50, 0)
        end
        if bUseRallyPointIfCloser then
            local tDefaultRallyPoint = GetAirRallyPoint(aiBrain)
            --Use the default rally point if its closer to our base but not that far from where we want to be
            if M27Utilities.GetDistanceBetweenPositions(tAirRallyPoint, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(tDefaultRallyPoint, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) and M27Utilities.GetDistanceBetweenPositions(tDefaultRallyPoint, tAirRallyPoint) <= 125 then
                tAirRallyPoint = tDefaultRallyPoint
            end
        end
    end

    --Backup if no units we want to shadow
    if M27Utilities.IsTableEmpty(tAirRallyPoint) then
        tAirRallyPoint = GetAirRallyPoint(aiBrain)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tAirRallyPoint
end

function TrackBomberTarget(oBomber, oTarget, iPriority, bFirstTorpTarget)
    local sFunctionRef = 'TrackBomberTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    --if EntityCategoryContains(categories.TECH3, oBomber.UnitId) and (M27UnitInfo.GetUnitLifetimeCount(oBomber) == 10 or M27UnitInfo.GetUnitLifetimeCount(oBomber) == 45) then bDebugMessages = true end

    --if oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code, oBomber=' .. oBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oBomber) .. '; oTarget=' .. oTarget.UnitId .. '; iPriority=' .. (iPriority or 'nil') .. '; bomber cur target number=' .. (oBomber[refiCurTargetNumber] or 'nil'))
    end

    if oBomber[reftTargetList] == nil then
        oBomber[reftTargetList] = {}
    end
    if bFirstTorpTarget and EntityCategoryContains(M27UnitInfo.refCategoryTorpBomber, oBomber.UnitId) then
        oBomber[refoTorpBomberPrimaryTarget] = oTarget
    end

    --oBomber[refbTorpBomberProtectingACU] = false --Will set for all units rather than adding an eneitry category check fotorp bombers for performance reasons
    table.insert(oBomber[reftTargetList], { [refiShortlistPriority] = iPriority, [refiShortlistUnit] = oTarget })

    if oTarget[refiCurBombersAssigned] == nil then
        oTarget[refiCurBombersAssigned] = 1
        --oTarget[refiLifetimeFailedBombersAssigned] = 1
    else
        oTarget[refiCurBombersAssigned] = oTarget[refiCurBombersAssigned] + 1
        --oTarget[refiLifetimeFailedBombersAssigned] = oTarget[refiLifetimeFailedBombersAssigned] + 1
    end

    if oBomber[refiCurTargetNumber] == 0 or oBomber[refiCurTargetNumber] == nil then
        oBomber[refiCurTargetNumber] = 1
        oBomber[refiTargetFailedHitCount] = (oTarget[refiFailedHitCount] or 0)
    end
    if not(oTarget[refiMaxStrikeDamageWanted]) then oTarget[refiMaxStrikeDamageWanted] = GetMaxStrikeDamageWanted(oTarget) end

    local iCurBomberStrikeDamage = M27UnitInfo.GetUnitStrikeDamage(oBomber)
    if iCurBomberStrikeDamage < 10 then
        M27Utilities.ErrorHandler('Bomber seems to have strike damage of less than 10, will assume its 10')
        iCurBomberStrikeDamage = 10
    end
    if bDebugMessages == true then LOG(sFunctionRef..': About to assign bomber strike damage to the target. iCurBomberStrikeDamage='..iCurBomberStrikeDamage..'; oTarget[refiStrikeDamageAssigned]='..(oTarget[refiStrikeDamageAssigned] or 'nil')) end
    if oTarget[refiStrikeDamageAssigned] == nil then
        oTarget[refiStrikeDamageAssigned] = iCurBomberStrikeDamage
    else
        oTarget[refiStrikeDamageAssigned] = oTarget[refiStrikeDamageAssigned] + iCurBomberStrikeDamage
    end
    if not(oTarget[reftoBombersTargetingUnit]) then oTarget[reftoBombersTargetingUnit] = {} end
    oTarget[reftoBombersTargetingUnit][oBomber:GetAIBrain():GetArmyIndex()..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)] = oBomber

    for iBomber, oBomber in oTarget[reftoBombersTargetingUnit] do
        if bDebugMessages == true then LOG(sFunctionRef..': Recording strike damage of '..oTarget[refiStrikeDamageAssigned]..' as being the coordinated strike damage assigned for bomber with table key='..iBomber..'; Bomber ID+LC='..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)) end
        oBomber[refiCoordinatedStrikeDamageAssigned] = oTarget[refiStrikeDamageAssigned]
    end
    oTarget[refiCoordinatedStrikeDamageAssigned] = oTarget[refiStrikeDamageAssigned]

    if bDebugMessages == true then LOG(sFunctionRef..': Target strike damage assigned after updating='..oTarget[refiStrikeDamageAssigned]) end

    if M27Config.M27ShowUnitNames == true and oBomber.GetUnitId then
        M27PlatoonUtilities.UpdateUnitNames({ oBomber }, oBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oBomber) .. ':Attack:' .. oTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oTarget))
    end

    if iPriority > 1 then
        local iSearchRange = 100
        if EntityCategoryContains(categories.TECH3, oBomber.UnitId) or EntityCategoryContains(categories.EXPERIMENTAL, oBomber.UnitId) then
            iSearchRange = iSearchRange + 100
        end
        if M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oTarget:GetPosition()) > iSearchRange then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Priority > 1 and more than 100 from bomber so will check for new targets as long as bomber remains far away. Bomber cur target=' .. oBomber[refiCurTargetNumber])
                LOG(sFunctionRef .. ': ID of current target=' .. oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit].UnitId)
            end

            ForkThread(CheckForBetterBomberTargets, oBomber)
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetModifiedBomberDistanceToTarget(iTimeUntilBomberLoaded, iBomberFacingDirection, iBomberSpeed, iDistToTarget, iAngleToTarget)
    --Treats targets as being further away if expect bomber will have to turn around and make another pass at them

    local iAnglePerSecond = 30
    local iMinDistToFireShot = iBomberSpeed * 4 --No idea how accurate this is, but means for a strat bomber have a min distance of 60; strat bomber range is 90; in one example Strat was able to hit a mex with a 5s reload time when the mex was 141 away; in theory it couldve travelled 85 although it probably travelled less than that

    local iModDist = iDistToTarget
    local bWillTurnAround = false
    if iDistToTarget < iMinDistToFireShot then
        bWillTurnAround = true
    else
        --NOTE: Could use the function GetAngleDifference(iAngle1, iAngle2) to calculate iAngleDif, but as this will likely get called a lot have reproduced here
        local iAngleDif = math.abs(iBomberFacingDirection - iAngleToTarget)
        if iAngleDif > 180 then iAngleDif = math.abs(iAngleDif - 360) end

        local iTimeUntilFacingRightWay = iAngleDif / iAnglePerSecond
        local iTimeUntilReadyToFire = iTimeUntilFacingRightWay + (iDistToTarget - iMinDistToFireShot) / iBomberSpeed
        if iTimeUntilReadyToFire < iTimeUntilBomberLoaded then
            bWillTurnAround = true
        end
    end
    if bWillTurnAround then
        local iDistToTurnAround = 180 / iAnglePerSecond * iBomberSpeed + iMinDistToFireShot
        iModDist = iModDist + iDistToTurnAround
    end
    return iModDist
end


function GetBestBomberTarget(oBomber, tPotentialUnitTargets, iMinFractionComplete, iAATechToCheckFor)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetBestBomberTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iBomberTech = M27UnitInfo.GetUnitTechLevel(oBomber)
    local oBomberCurTarget = oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit]
    local oRecentlyTargeted
    local iBomberStrikeDamage = M27UnitInfo.GetUnitStrikeDamage(oBomber)
    local iBomberDirection = M27UnitInfo.GetUnitFacingAngle(oBomber)

    local iLastFiredBomb = GetGameTimeSeconds() - (oBomber[refiLastFiredBomb] or -100)
    local iExtraDistanceIfDifAngle = iBomberTech * 45 + 10
    local tBomberPosition = oBomber:GetPosition()

    local oBP = oBomber:GetBlueprint()
    --local iBomberSpeed = oBP.Physics.MaxSpeed
    --local iTimeToReload = 5
    local iBomberRange = 40


    --if iBomberTech == 1 and M27UnitInfo.IsUnitValid(oBomberCurTarget) then bDebugMessages = true end

    local iBomberSpeed, iTimeToReload = M27UnitInfo.GetBomberSpeedAndTimeToReload(oBomber)
    local iTimeUntilLoaded = math.max(iTimeToReload - iLastFiredBomb, 0)


    --[[for iWeapon, tWeapon in oBP.Weapon do
        if tWeapon.WeaponCategory == 'Bomb' then
            if tWeapon.RateOfFire > 0 then iTimeToReload = 1 / tWeapon.RateOfFire end
            iBomberRange = tWeapon.MaxRadius
        end
    end--]]
    local iTooCloseDistance = iBomberRange + iBomberTech * 15
    if iTimeToReload < iLastFiredBomb then
        iTooCloseDistance = math.max(iTooCloseDistance, iBomberRange + (iLastFiredBomb - iTimeToReload) * iBomberSpeed + iBomberTech * 5)
        iExtraDistanceIfDifAngle = iExtraDistanceIfDifAngle + 15
    end

    if bDebugMessages == true then LOG(sFunctionRef..': Bomber='..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; iBomberRange='..iBomberRange..'; iTooCloseDistance='..iTooCloseDistance..'; iTimeToReload='..iTimeToReload..'; iLastFiredBomb='..iLastFiredBomb..'; iExtraDistanceIfDifAngle='..iExtraDistanceIfDifAngle) end

    --[[if GetGameTimeSeconds() - (oBomber[refiLastFiredBomb] or -100000) <= 4 then
        --Did we recently target a unit that should die to our strike damage?
        if oBomber[refoLastBombTarget] and oBomber[refoLastBombTarget][refiMaxStrikeDamageWanted] < iBomberStrikeDamage then
            oRecentlyTargeted = oBomber[refoLastBombTarget]
            if not(M27UnitInfo.IsUnitValid(oRecentlyTargeted)) then oRecentlyTargeted = nil end
            if bDebugMessages == true and oRecentlyTargeted then LOG(sFunctionRef..': We recently fired a bomb at oRecentlyTargeted='..oRecentlyTargeted.UnitId..M27UnitInfo.GetUnitLifetimeCount(oRecentlyTargeted)..' and think our bomb will be enough to have killed it') end
        end
    end--]]

    local iCurUnitAngle
    local iDistanceToTarget
    local iClosestDistance = 100000
    local oClosestDistance
    local iCurTargetDistance

    --Get existing target as want to ignore strike damage from this bomber for below check
    local oBomberCurTarget = oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit]

    local tEnemyAAToAvoid
    local aiBrain = oBomber:GetAIBrain()
    if iAATechToCheckFor then
        local iMaxAARange = 0
        local iCurDist
        for iUnit, oUnit in tPotentialUnitTargets do
            iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oBomber:GetPosition())
            if iCurDist > iMaxAARange then
                iMaxAARange = iCurDist
            end
        end
        iMaxAARange = iMaxAARange + 60

        local iAACategory
        if iAATechToCheckFor == 1 then iAACategory = M27UnitInfo.refCategoryGroundAA
        elseif iAATechToCheckFor == 2 then iAACategory = M27UnitInfo.refCategoryGroundAA - categories.TECH1
        else iAACategory = M27UnitInfo.refCategoryGroundAA * categories.TECH3 + M27UnitInfo.refCategoryCruiser
        end
        tEnemyAAToAvoid = aiBrain:GetUnitsAroundPoint(iAACategory, oBomber:GetPosition(), iMaxAARange, 'Enemy')
        if bDebugMessages == true then
            LOG(sFunctionRef..': Is table of enemyAAToAvoid empty='..tostring(M27Utilities.IsTableEmpty(tEnemyAAToAvoid))..'; will list out AA if there are any')
            if M27Utilities.IsTableEmpty(tEnemyAAToAvoid) == false then
                for iAA, oAA in tEnemyAAToAvoid do
                    LOG(sFunctionRef..': oAA='..oAA.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAA)..'; Position='..repru(oAA:GetPosition())..'; Dist to us='..M27Utilities.GetDistanceBetweenPositions(oAA:GetPosition(), oBomber:GetPosition())..'; Angle to AA='..M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oAA:GetPosition()))
                end
            end
        end
    end

    --Engi hunters - want the idle bomber closest to the engi to target it, unless have already given it a chance to target it
    local tAltEngiHunterBomberPositions
    local iIdleEngiHunters = 0
    if oBomber[refbEngiHunterMode] and not(oBomber[refbHaveDelayedTargeting]) then
        tAltEngiHunterBomberPositions = {}
        if bDebugMessages == true then LOG(sFunctionRef..': Will see if we have any idle engi hutner bombers. Is table empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngiHunterBombers]))..'; Bomber curpos='..repru(oBomber:GetPosition())) end
        if M27Utilities.IsTableEmpty(aiBrain[reftEngiHunterBombers]) == false then
            for iUnit, oUnit in aiBrain[reftEngiHunterBombers] do
                if not(oUnit == oBomber) and M27UnitInfo.IsUnitValid(oUnit) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering bomber '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' which is dif to the bomber we are currently considering.  Does it have an empty target list='..tostring(M27Utilities.IsTableEmpty(oUnit[reftTargetList]))..'; Bomber cur target number='..(oUnit[refiCurTargetNumber] or 'nil')..'; Bomber position='..repru(oUnit:GetPosition())) end
                    if M27Utilities.IsTableEmpty(oUnit[reftTargetList]) then
                        iIdleEngiHunters = iIdleEngiHunters + 1
                        tAltEngiHunterBomberPositions[iIdleEngiHunters] = oUnit:GetPosition()
                    end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': iIdleEngiHunters='..iIdleEngiHunters..'; table of alt bomber positions='..repru(tAltEngiHunterBomberPositions)) end
        end
    end
    local bLeaveForOtherBomber
    local iMaxDistFromEnemyBase



    local bDontCheckIfCivilian = true
    --Avoid targeting hostile civilians with initail bombers, but consider for later T1-T2 bombers
    if EntityCategoryContains(categories.TECH1 + categories.TECH2, oBomber.UnitId) and aiBrain[M27Overseer.refiActiveEnemyBrains] > 0 and M27UnitInfo.GetUnitLifetimeCount(oBomber) <= 10 then bDontCheckIfCivilian = false end

    for iUnit, oUnit in tPotentialUnitTargets do
        --Check its not about to die and is complete enough
        if bDebugMessages == true then LOG(sFunctionRef..': Considering if we want to target oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; oBomber[refbEngiHunterMode]='..tostring(oBomber[refbEngiHunterMode] or false)..'; Bomber LC='..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; Dist from unit to enemy base='..M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))..'; aiBrain[refiHighestEnemyAirThreat]='..(aiBrain[refiHighestEnemyAirThreat] or 0)..'; aiBrain[refiEnemyMassInGroundAA]='..(aiBrain[refiEnemyMassInGroundAA] or 0)..'; is oUnit the same as oRecentlyTargeted='..tostring(oUnit == oRecentlyTargeted)..'; oUnit fraction complete='..oUnit:GetFractionComplete()..'; GetMaxStrikeDamageWanted(oUnit)='..GetMaxStrikeDamageWanted(oUnit)..'; oUnit[refiStrikeDamageAssigned]='..(oUnit[refiStrikeDamageAssigned] or 'nil')..'; Is unit bombers current target='..tostring(oUnit == oBomberCurTarget)..'; Dist to enemy base='..M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))..'; aiBrain[refiHighestEnemyAirThreat]='..aiBrain[refiHighestEnemyAirThreat]..'; iMinFractionComplete wanted='..iMinFractionComplete) end
        if not(oUnit == oRecentlyTargeted) and oUnit:GetFractionComplete() >= (iMinFractionComplete or 0.5) and (bDontCheckIfCivilian or not(M27Logic.IsCivilianBrain(oUnit:GetAIBrain()))) then
            --Check it odesnt already have enough strike damage assigned
            if GetMaxStrikeDamageWanted(oUnit) > (oUnit[refiStrikeDamageAssigned] or 0) or oUnit == oBomberCurTarget then
                --If in engi hunter mode then ignore engineers close to enemy base unless enemy has no air units
                iDistanceToTarget = M27Utilities.GetDistanceBetweenPositions(tBomberPosition, oUnit:GetPosition())
                iMaxDistFromEnemyBase = 80
                if iDistanceToTarget <= 60 then iMaxDistFromEnemyBase = 50 end
                if bDebugMessages == true then LOG(sFunctionRef..': iDistanceToTarget='..iDistanceToTarget..'; iMaxDistFromEnemyBase='..iMaxDistFromEnemyBase..'; Dist to enemy base='..M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))) end
                if not(oBomber[refbEngiHunterMode]) or (aiBrain[refiHighestEnemyAirThreat] <= 60 and (aiBrain[refiEnemyMassInGroundAA] <= 10 or M27UnitInfo.GetUnitLifetimeCount(oBomber) == 1)) or M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) > iMaxDistFromEnemyBase then
                    bLeaveForOtherBomber = false
                    if not(M27Utilities.IsTableEmpty(tAltEngiHunterBomberPositions)) then
                        for iAltBomberPos, tAltBomberPos in tAltEngiHunterBomberPositions do
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering if we have another idle bomber closer to the target. tAltBomberPos='..repru(tAltBomberPos)..';  Dist to altbomberpos='..M27Utilities.GetDistanceBetweenPositions(tAltBomberPos, oUnit:GetPosition())..'; iDistanceToTarget='..iDistanceToTarget) end
                            if iDistanceToTarget - 35 > M27Utilities.GetDistanceBetweenPositions(tAltBomberPos, oUnit:GetPosition()) then
                                if bDebugMessages == true then LOG(sFunctionRef..': We have another idle engi hunter bomber that is closer to the target so will leave it.  Dist to altbomberpos='..M27Utilities.GetDistanceBetweenPositions(tAltBomberPos, oUnit:GetPosition())..'; iDistanceToTarget='..iDistanceToTarget) end
                                oBomber[refbHaveDelayedTargeting] = true
                                bLeaveForOtherBomber = true
                                --Not fully accurate since we might not have picked this target anyway, but should be close enough
                            end
                        end
                    end

                    if bDebugMessages == true then LOG(sFunctionRef..': Either not engi hunter, or Unit is far enough from enemy base, or no AA at enemy base. iAATechToCheckFor='..(iAATechToCheckFor or 'nil')..'  Is it covered by AA+'..tostring(IsTargetCoveredByAA(oUnit, tEnemyAAToAvoid, (iAATechToCheckFor or 1), oBomber:GetPosition(), false, true))..'; Dist to target before adjusting for angle and being too close='..M27Utilities.GetDistanceBetweenPositions(tBomberPosition, oUnit:GetPosition())..'; iClosestDistance='..iClosestDistance..'; Angle from bomber to target='..M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oUnit:GetPosition())..'; Dist to unit='..M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oUnit:GetPosition())) end
                    if not(iAATechToCheckFor) or not(IsTargetCoveredByAA(oUnit, tEnemyAAToAvoid, iAATechToCheckFor, oBomber:GetPosition(), false, true)) then
                        iDistanceToTarget = GetModifiedBomberDistanceToTarget(iTimeUntilLoaded, iBomberDirection, iBomberSpeed, iDistanceToTarget, M27Utilities.GetAngleFromAToB(tBomberPosition, oUnit:GetPosition()))
                        --[[if iDistanceToTarget <= iTooCloseDistance then
                            iDistanceToTarget = iDistanceToTarget + iExtraDistanceIfDifAngle
                        else
                            iCurUnitAngle = M27Utilities.GetAngleFromAToB(tBomberPosition, oUnit:GetPosition())
                            if math.abs(iCurUnitAngle - iBomberDirection) > 15 then
                                iDistanceToTarget = iDistanceToTarget + iExtraDistanceIfDifAngle
                            end
                        end--]]



                        --Increase distance for failed attempts
                        iDistanceToTarget = iDistanceToTarget + (oUnit[refiFailedHitCount] or 0) * 15 * iBomberTech

                        --Decrease distance slightly if its existing target
                        if oUnit == oBomberCurTarget then iDistanceToTarget = iDistanceToTarget - 10 end

                        if bDebugMessages == true then LOG(sFunctionRef..': iDistanceToTarget='..iDistanceToTarget..'; oUnit[refiFailedHitCount]='..(oUnit[refiFailedHitCount] or 'nil')..'; iClosestDistance before considering this unit='..iClosestDistance) end



                        if iDistanceToTarget < iClosestDistance then
                            oClosestDistance = oUnit
                            iClosestDistance = iDistanceToTarget
                            if bDebugMessages == true then LOG(sFunctionRef..': Will make the best target oUnit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' unless al ater unit is even closer.') end
                        end
                        if oUnit == oBomberCurTarget then iCurTargetDistance = iDistanceToTarget end
                    end
                end
            end
        end
    end

    --Is our current target already fairly close and we havent fired a bomb at it recently
    if iCurTargetDistance and iCurTargetDistance <= (iDistanceToTarget + 50) and not(oBomberCurTarget == oRecentlyTargeted) then
        oClosestDistance = oBomberCurTarget
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oClosestDistance
end



function IssueNewAttackToBomber(oBomber, oTarget, iPriority, bAreHoverBombing)
    local aiBrain = oBomber:GetAIBrain()
    local iCurShield, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oTarget)
    --IsTargetUnderShield(aiBrain, oTarget, iIgnoreShieldsWithLessThanThisHealth, bReturnShieldHealthInstead, bIgnoreMobileShields, bTreatPartCompleteAsComplete)

    local iNearbyShieldCurHealth, iNearbyShieldMaxHealth = M27Logic.IsTargetUnderShield(aiBrain, oTarget, 0, true, false, true)
    local iHealthPercent = M27UnitInfo.GetUnitHealthPercent(oTarget)
    if iHealthPercent == 0 then
        iHealthPercent = 1
    end

    ClearAirUnitAssignmentTrackers(aiBrain, oBomber, true)

    TrackBomberTarget(oBomber, oTarget, iPriority)
    --Does our bomber have good aoe and is targetting a structure? If so the below will adjust the bomb location
    TellBomberToAttackTarget(oBomber, oTarget, true, bAreHoverBombing)
    oBomber[refiShieldIgnoreValue] = GetMaxStrikeDamageWanted(oBomber)
end

function OneOffTargetNearbyEngineer(aiBrain, oBomber)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OneOffTargetNearbyEngineer'

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, oBomber='..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; Is this an engi hunter='..tostring(oBomber[refbEngiHunterMode])) end

    --Assumed called from on killed event, e.g. when t1 bomber kills t1 mex - will look for nearby engineers and target the nearest one that doesnt already ahve an assigned bomber
    if not(oBomber[refbEngiHunterMode]) then
        local tNearbyEngineers = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryEngineer, oBomber:GetPosition(), 60, 'Enemy')
        if bDebugMessages == true then LOG(sFunctionRef..': Is table of nearby engineers empty='..tostring(M27Utilities.IsTableEmpty(tNearbyEngineers))) end
        if M27Utilities.IsTableEmpty(tNearbyEngineers) == false then
            local oNearestUnshieldedEngi
            local iNearestUnshieldedEngi = 10000
            local iCurDist
            for iEngi, oEngi in tNearbyEngineers do
                if (oEngi[refiStrikeDamageAssigned] or 0) == 0 then
                    iCurDist = M27Utilities.GetDistanceBetweenPositions(oEngi:GetPosition(), oBomber:GetPosition())
                    if iCurDist < iNearestUnshieldedEngi then
                        if not(M27Logic.IsTargetUnderShield(aiBrain, oEngi, 0, false, false, false, false)) then
                            iNearestUnshieldedEngi = iCurDist
                            oNearestUnshieldedEngi = oEngi
                        end
                    end
                end
            end
            if oNearestUnshieldedEngi then
                ClearAirUnitAssignmentTrackers(aiBrain, oBomber, true)
                TrackBomberTarget(oBomber, oNearestUnshieldedEngi, 1)
                M27Utilities.IssueTrackedClearCommands({ oBomber })
                TellBomberToAttackTarget(oBomber, oNearestUnshieldedEngi, false, false)
                for iMexBomber, oMexBomber in aiBrain[reftMexHunterT1Bombers] do
                    if oMexBomber == oBomber then
                        oMexBomber = nil
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ManualTellTorpedoBomberToAttackTarget(aiBrain, oBomber, oTarget)
    --Used to e.g. get torp bombers to target enemy ACU when in ACU kill mode, if not already targeting the unit
    local oBomberCurTarget = oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit]
    local bCanSeeTarget = M27Utilities.CanSeeUnit(aiBrain, oTarget, true)
    if not(oBomberCurTarget == oTarget) or (oBomber[M27PlatoonUtilities.refiLastOrderType] == M27PlatoonUtilities.refiOrderIssueAggressiveMove and (bCanSeeTarget or M27Utilities.GetDistanceBetweenPositions(oTarget:GetPosition(), (oBomber[M27UnitInfo.reftLastOrderTarget] or {0,0,0})) >= 15)) then
        ClearAirUnitAssignmentTrackers(aiBrain, oBomber, true)
        M27Utilities.IssueTrackedClearCommands({ oBomber })
        TrackBomberTarget(oBomber, oTarget, 1)
        if bCanSeeTarget then
            IssueAttack({ oBomber }, oTarget)
            oBomber[M27PlatoonUtilities.refiLastOrderType] = M27PlatoonUtilities.refiOrderIssueAttack
        else
            oBomber[M27PlatoonUtilities.refiLastOrderType] = M27PlatoonUtilities.refiOrderIssueAggressiveMove
            IssueAggressiveMove({oBomber}, oTarget:GetPosition())
        end
    end
end

function UpdateBomberTargets(oBomber, bRemoveIfOnLand, bLookForHigherPriorityShortlist, bReissueIfBlocked)
    --Checks if target dead; or (if not part of a large attack) if its shielded by significantly more than the threshold when the bomber was first assigned
    --bLookForHigherPriorityShortlist - set to true when a bomb is fired and this function is called as a result; if the target shortlist has a higher priority unit for targetting, then will switch to this
    --bReissueIfBlocked - will make use of the logic for maps like astro where cliffs can block bomber shots - should only use this on specific events like when the bomb has been recently fired

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateBomberTargets'

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if M27UnitInfo.GetUnitTechLevel(oBomber) == 4 then bDebugMessages = true end
    --if M27UnitInfo.GetUnitTechLevel(oBomber) == 3 and M27UnitInfo.GetUnitLifetimeCount(oBomber) == 1 then bDebugMessages = true end
    --if oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber) == 'uaa02041' and GetGameTimeSeconds() >= 60 then bDebugMessages = true else bDebugMessages = false end
    local bRemoveCurTarget
    local bHaveMoveCommand = false
    local tTargetPos
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code, oBomber=' .. oBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; GameTIme='..GetGameTimeSeconds())
    end

    --Special code for T1 bomber with low LC - search only for enemy T1 engineers until the bomber dies
    if M27UnitInfo.IsUnitValid(oBomber) then
        local aiBrain = oBomber:GetAIBrain()
        local bTargetACU = false
        local bIsTorpBomber = EntityCategoryContains(M27UnitInfo.refCategoryTorpBomber, oBomber.UnitId)

        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill then
            local bACUUnderwater = M27UnitInfo.IsUnitUnderwater(aiBrain[M27Overseer.refoACUKillTarget])

            if bIsTorpBomber and bACUUnderwater then
                bTargetACU = true
            elseif not (bIsTorpBomber) and not (bACUUnderwater) then
                bTargetACU = true
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Are in ACU kill mode, bACUUnderwater='..tostring(bACUUnderwater)..'; bIsTorpBomber='..tostring(bIsTorpBomber)..'; bTargetACU='..tostring(bTargetACU)) end
        end
        if bTargetACU and bIsTorpBomber then
            ManualTellTorpedoBomberToAttackTarget(aiBrain, oBomber, aiBrain[M27Overseer.refoACUKillTarget])
        else
            if oBomber[refbEngiHunterMode] then
                --Hunt for engineers - get what we think is the best target (regardless of whether we have a current target)
                --exception if our current target is near us and within the preferred angle range
                local oBomberCurTarget = oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit]
                local bKeepExistingTarget = false

                local iIdleEngiHunters = 0
                if bDebugMessages == true then LOG(sFunctionRef..': Will see if we have any idle engi hutner bombers. Is table empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngiHunterBombers]))) end
                if M27Utilities.IsTableEmpty(aiBrain[reftEngiHunterBombers]) == false then
                    for iUnit, oUnit in aiBrain[reftEngiHunterBombers] do
                        if not(oUnit == oBomber) and M27UnitInfo.IsUnitValid(oUnit) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering bomber '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' which is dif to the bomber we are currently considering.  Does it have an empty target list='..tostring(M27Utilities.IsTableEmpty(oUnit[reftTargetList]))..'; Bomber cur target number='..(oUnit[refiCurTargetNumber] or 'nil')) end
                            if M27Utilities.IsTableEmpty(oUnit[reftTargetList]) then
                                iIdleEngiHunters = iIdleEngiHunters + 1
                            end
                        end
                    end
                end


                if M27UnitInfo.IsUnitValid(oBomberCurTarget) then
                    if iIdleEngiHunters > 0 and not(M27Utilities.CanSeeUnit(aiBrain, oBomberCurTarget, true)) then
                        bKeepExistingTarget = true
                    elseif M27Utilities.GetDistanceBetweenPositions(oBomberCurTarget:GetPosition(), oBomber:GetPosition()) <= 110 and math.abs(M27UnitInfo.GetUnitFacingAngle(oBomber) - M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oBomberCurTarget:GetPosition())) <= 20 then
                        bKeepExistingTarget = true
                    end
                end
                if bDebugMessages == true and M27UnitInfo.IsUnitValid(oBomberCurTarget) then LOG(sFunctionRef..': Bomber has a valid target, oBomberCurTarget='..oBomberCurTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomberCurTarget)..'; distance to bomber='..M27Utilities.GetDistanceBetweenPositions(oBomberCurTarget:GetPosition(), oBomber:GetPosition())..'; bKeepExistingTarget='..tostring(bKeepExistingTarget)) end
                if not(bKeepExistingTarget) then

                    --For if bomber is in refbEngiHunterMode (command to help search locate this) - will also include t1 radar as same priority as enemy engineer
                    if bDebugMessages == true then LOG(sFunctionRef..': Have a t1 bomber that is the first one built, so will hunt for engineers') end
                    local tEnemyEngineers = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryEngineer * categories.TECH1 + M27UnitInfo.refCategoryT1Radar, oBomber:GetPosition(), aiBrain[refiMaxScoutRadius], 'Enemy')
                    if M27Utilities.IsTableEmpty(tEnemyEngineers) then
                        tEnemyEngineers = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryEngineer, oBomber:GetPosition(), aiBrain[refiMaxScoutRadius], 'Enemy')
                        if bDebugMessages == true then LOG(sFunctionRef..': No T1 engineers detected, is table of T2+ engineers empty='..tostring(M27Utilities.IsTableEmpty(tEnemyEngineers))) end
                    end

                    local oTargetWanted

                    if M27Utilities.IsTableEmpty(tEnemyEngineers) == false then

                        oTargetWanted = GetBestBomberTarget(oBomber, tEnemyEngineers, 0.75, 1) --Ignore T1 AA
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Have engineers detected so will pick the best target out of these')
                            if oTargetWanted then LOG(sFunctionRef..': The best target chosen is '..oTargetWanted.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTargetWanted))
                            else LOG('No target was found')
                            end
                        end
                    end

                    if bDebugMessages == true then
                        if oBomberCurTarget then LOG(sFunctionRef..': Bombers current target before making any changes='..oBomberCurTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomberCurTarget))
                        else LOG(sFunctionRef..': Bomber doesnt have an existing unit target at the moment')
                        end
                    end
                    if oTargetWanted and not (oTargetWanted == oBomberCurTarget) then
                        --Have a new target
                        IssueNewAttackToBomber(oBomber, oTargetWanted, 1)
                        if bDebugMessages == true then LOG(sFunctionRef..': Have a target that isnt the same as the current target so will issue a new attack for it') end
                    elseif not (oTargetWanted) and not(oBomberCurTarget) then

                        --Do we have an existing target? If so are we near it?
                        local tCurTarget
                        if oBomber.GetNavigator then
                            local oNavigator = oBomber:GetNavigator()
                            if oNavigator and oNavigator.GetCurrentTargetPos then
                                tCurTarget = oNavigator:GetCurrentTargetPos()
                            end
                        end
                        local bWantNewMovementTarget = true
                        if oBomber[M27UnitInfo.refbSpecialMicroActive] then bWantNewMovementTarget = false
                        else
                            if tCurTarget and oBomber:IsUnitState('Moving') then
                                if M27Utilities.GetDistanceBetweenPositions(tCurTarget, oBomber:GetPosition()) >= 30 then
                                    if bDebugMessages == true then LOG(sFunctionRef..': current location target is more than 30 from bomber current position so dont want a new one') end
                                    bWantNewMovementTarget = false
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Dont have a target to select, and dont ahve an existing target, so will consider moving somewhere. bWantNewMovementTarget='..tostring(bWantNewMovementTarget)..'; tCurTarget='..repru((tCurTarget or {'nil'}))..'; Bomber unit state='..M27Logic.GetUnitState(oBomber)) end
                        if bWantNewMovementTarget then
                            local tNewTarget
                            --Need a move order for the bomber if it's idle - locate the nearest mex on enemy side of map that we havent had sight of recently
                            local iPathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                            local tPotentialMexes = M27MapInfo.tMexByPathingAndGrouping[M27UnitInfo.refPathingTypeAmphibious][iPathingGroup]
                            local iLowestDistance = 100000
                            local iCurDistance
                            local iCurSegmentX, iCurSegmentZ
                            local iLastVisualSight
                            local tEnemyBase = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
                            local tOurBase = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]

                            if bDebugMessages == true then LOG(sFunctionRef..': Will cycle through mexes to identify any we havent had sight of recently and will pick one of these') end
                            local tEnemyAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, oBomber:GetPosition(), aiBrain[M27Overseer.refiDistanceToNearestEnemyBase], 'Enemy')
                            local iDistToEnemyBase
                            local bAlreadyCoveredByOtherBomber

                            local iIdleEngiHunters = 0
                            local tIdleEngiHunterTargets = {}
                            if bDebugMessages == true then LOG(sFunctionRef..': Will see if we have any idle engi hutner bombers. Is table empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngiHunterBombers]))) end
                            if M27Utilities.IsTableEmpty(aiBrain[reftEngiHunterBombers]) == false then
                                for iUnit, oUnit in aiBrain[reftEngiHunterBombers] do
                                    if not(oUnit == oBomber) and M27UnitInfo.IsUnitValid(oUnit) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Considering bomber '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' which is dif to the bomber we are currently considering.  Does it have an empty target list='..tostring(M27Utilities.IsTableEmpty(oUnit[reftTargetList]))..'; Bomber cur target number='..(oUnit[refiCurTargetNumber] or 'nil')) end
                                        if M27Utilities.IsTableEmpty(oUnit[reftTargetList]) then
                                            if oUnit.GetNavigator and oUnit:GetNavigator() then
                                                iIdleEngiHunters = iIdleEngiHunters + 1
                                                tIdleEngiHunterTargets[iIdleEngiHunters] = oUnit:GetNavigator():GetCurrentTargetPos()
                                            end

                                        end
                                    end
                                end
                            end

                            for iMex, tMex in tPotentialMexes do
                                bAlreadyCoveredByOtherBomber = false
                                --iCurSegmentX, iCurSegmentZ = GetAirSegmentFromPosition(tMex)
                                iLastVisualSight =  GetTimeSinceLastScoutedLocation(aiBrain, tMex)
                                if bDebugMessages == true then LOG(sFunctionRef..': Considering iMex='..iMex..'; tMex='..repru(tMex)..'; Dist to our base='..M27Utilities.GetDistanceBetweenPositions(tMex, tOurBase)..'; Dist to enemy base='..M27Utilities.GetDistanceBetweenPositions(tMex, tEnemyBase)..'; iLastVisualSight='..iLastVisualSight) end
                                if iLastVisualSight >= 60 then
                                    --Been more than 60s since had sight of the mex so consider it if its closer to enemy base than our base
                                    iDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tMex, tEnemyBase)

                                    if M27Utilities.GetDistanceBetweenPositions(tMex, tOurBase) > iDistToEnemyBase then
                                        if iDistToEnemyBase >= 100 or (aiBrain[refiHighestEnemyAirThreat] <= 60 and (aiBrain[refiEnemyMassInGroundAA] <= 10 or M27UnitInfo.GetUnitLifetimeCount(oBomber) == 1)) then
                                            iCurDistance = M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), tMex)
                                            if iCurDistance >= 30 and iCurDistance < iLowestDistance then
                                                if iIdleEngiHunters > 0 then
                                                    --Do we have another bomber already targeting here?
                                                    for iExistingTarget, tExistingTarget in tIdleEngiHunterTargets do
                                                        if M27Utilities.GetDistanceBetweenPositions(tExistingTarget, tMex) <= 30 then
                                                            bAlreadyCoveredByOtherBomber = true
                                                            break
                                                        end
                                                    end
                                                end

                                                --Check dont have a bomber already going here, and that there's no AA covering it?
                                                if not(bAlreadyCoveredByOtherBomber) and not(IsTargetPositionCoveredByAA(tMex, tEnemyAA, oBomber:GetPosition(), false)) then
                                                    iLowestDistance = iCurDistance
                                                    tNewTarget = {tMex[1], tMex[2], tMex[3]}
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Have a new lowest distance, iLowestDistance='..iLowestDistance) end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            local bAttackMove = false

                            if M27Utilities.IsTableEmpty(tNewTarget) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Dont have a mex target so will target enemy base instead if no enemy air threat, or our base') end
                                if aiBrain[refiHighestEnemyAirThreat] <= 60 and aiBrain[refiEnemyMassInGroundAA] <= 10 then
                                    tNewTarget = tEnemyBase
                                else tNewTarget = GetAirRallyPoint(aiBrain)
                                end
                                if M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), tEnemyBase) <= 10 then bAttackMove = true end
                            end

                            --if oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end

                            M27Utilities.IssueTrackedClearCommands({oBomber})
                            if bAttackMove then IssueAggressiveMove({oBomber}, tNewTarget)
                            else IssueMove({oBomber}, tNewTarget)
                            end

                            bHaveMoveCommand = true
                            if bDebugMessages == true then LOG(sFunctionRef..': Just given order to oBomber='..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..' to move to target '..repru(tNewTarget)..'; bAttackMove='..tostring(bAttackMove)) end
                            --Dont track this - i.e. consider the bomber to be idle
                        else
                            --Dont want a new move command so we must already ahve one that we want to stick with
                            bHaveMoveCommand = true
                        end
                    end
                end
            else
                if not(oBomber[M27UnitInfo.refbSpecialMicroActive]) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Does bomber have an empty target list='..tostring(M27Utilities.IsTableEmpty(oBomber[reftTargetList]))) end
                    if M27Utilities.IsTableEmpty(oBomber[reftTargetList]) == false then
                        local oBomberCurTarget
                        local bBomberHasDeadOrShieldedTarget = true
                        local iDeadLoopCount = 0
                        local iMaxDeadLoopCount = table.getn(oBomber[reftTargetList]) + 1
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': iMaxDeadLoopCount=' .. iMaxDeadLoopCount .. ': About to check if bomber has any dead targets')
                        end
                        local bLookForShieldOrAA = false
                        local bHaveAssignedNewTarget = false
                        --if M27UnitInfo.IsUnitValid(oBomber) then
                        local sBomberID = oBomber.UnitId
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': ' .. sBomberID .. M27UnitInfo.GetUnitLifetimeCount(oBomber))
                        end
                        local aiBrain = oBomber:GetAIBrain()
                        local tNearbyPriorityShieldTargets = {}
                        local tNearbyPriorityAATargets = {}
                        local iNearbyPriorityShieldTargets = 0
                        local iNearbyPriorityAATargets = 0





                        if bIsTorpBomber then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Have a torp bomber, will consider whether to clear its targets')
                            end
                            --Torp bombers - retarget any nearby enemy AA units if we are targetting a non-AA unit
                            oBomberCurTarget = oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit]


                            if not (M27UnitInfo.IsUnitValid(oBomberCurTarget)) then
                                ClearAirUnitAssignmentTrackers(aiBrain, oBomber, true)
                            else
                                --Have a valid target, does it have AA?
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': BomberCurTarget=' .. oBomberCurTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oBomberCurTarget))
                                end
                                if not (EntityCategoryContains(M27UnitInfo.refCategoryGroundAA, oBomberCurTarget.UnitId)) then
                                    --Is there nearby ground AA that isnt hover and is on water?
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Our current target doesnt have AA, checking if nearby enemy that does')
                                    end
                                    local tNonHoverGroundAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA - categories.HOVER, oBomber:GetPosition(), 90, 'Enemy')
                                    local oNearestGroundAA
                                    local iCurDistanceFromGroundAA
                                    local iNearestGroundAA = 10000
                                    local tAllValidAATargets = {}
                                    if M27Utilities.IsTableEmpty(tNonHoverGroundAA) == true then
                                        if bDebugMessages == true then LOG(sFunctionRef..': No AA, will look for overlayAA and subs if our current target doesnt meet this and we arent targeting an ACU when in ACU kill mode') end
                                        local iLowPriorityCat = M27UnitInfo.refCategoryAllNavy * categories.OVERLAYANTIAIR + M27UnitInfo.refCategorySubmarine
                                        if not (EntityCategoryContains(iLowPriorityCat, oBomberCurTarget.UnitId)) and (not(EntityCategoryContains(categories.COMMAND, oBomberCurTarget.UnitId)) or not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill)) then
                                            tNonHoverGroundAA = aiBrain:GetUnitsAroundPoint(iLowPriorityCat, oBomber:GetPosition(), 45, 'Enemy')
                                        end
                                    end
                                    if M27Utilities.IsTableEmpty(tNonHoverGroundAA) == false then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Have enemy groundAA nearby, will see if its underwater')
                                        end
                                        for iGroundAA, oGroundAA in tNonHoverGroundAA do
                                            --Is the unit on water?
                                            if M27UnitInfo.IsUnitOnOrUnderWater(oGroundAA) then
                                                iCurDistanceFromGroundAA = M27Utilities.GetDistanceBetweenPositions(oGroundAA:GetPosition(), oBomber:GetPosition())
                                                if iCurDistanceFromGroundAA < iNearestGroundAA then
                                                    oNearestGroundAA = oGroundAA
                                                    iNearestGroundAA = iCurDistanceFromGroundAA
                                                    table.insert(tAllValidAATargets, oGroundAA)
                                                end
                                            end
                                        end
                                    end
                                    if oNearestGroundAA then
                                        --if oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end
                                        ClearAirUnitAssignmentTrackers(aiBrain, oBomber, true)
                                        M27Utilities.IssueTrackedClearCommands({ oBomber })
                                        IssueAttack({ oBomber }, oNearestGroundAA)
                                        for iGroundAA, oGroundAA in tAllValidAATargets do
                                            IssueAttack({ oBomber }, oGroundAA)
                                        end
                                        TrackBomberTarget(oBomber, oNearestGroundAA, 1)
                                        IssueAggressiveMove({ oBomber }, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                        oBomber[refbOnAssignment] = true
                                        if bDebugMessages == true then LOG(sFunctionRef..': Cleared bomber '..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..' current targets and will attack nearest groundAA '..oNearestGroundAA.UnitId..M27UnitInfo.GetUnitLifetimeCount(oNearestGroundAA)) end
                                    end
                                end
                            end
                        else
                            --Logic for bombers
                            while bBomberHasDeadOrShieldedTarget == true do
                                iDeadLoopCount = iDeadLoopCount + 1
                                if iDeadLoopCount > iMaxDeadLoopCount then
                                    M27Utilities.ErrorHandler('Infinite loop, will abort')
                                    break
                                end
                                oBomberCurTarget = oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit]
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': iDeadLoopCount=' .. iDeadLoopCount .. '; iMaxDeadLoopCount=' .. iMaxDeadLoopCount)
                                end
                                bRemoveCurTarget = false
                                --Dont use isunitvalid as that checks if its completed and we may want to target part-complete buildings
                                if oBomberCurTarget == nil or oBomberCurTarget.Dead or not (oBomberCurTarget.GetPosition) then
                                    bRemoveCurTarget = true
                                elseif bTargetACU == true and not (oBomberCurTarget == aiBrain[M27Overseer.refoLastNearestACU]) and not(oBomberCurTarget == aiBrain[M27Overseer.refoACUKillTarget]) then
                                    bRemoveCurTarget = true
                                elseif bRemoveIfOnLand then
                                    tTargetPos = oBomberCurTarget:GetPosition()
                                    if GetTerrainHeight(tTargetPos[1], tTargetPos[2]) >= M27MapInfo.iMapWaterHeight then
                                        bRemoveCurTarget = true
                                    end
                                else
                                    --Check in case we are targeting the ground and it is too far away from the target
                                    if iDeadLoopCount == 1 and oBomber.GetNavigator and not(oBomber[M27UnitInfo.refbSpecialMicroActive]) and not(M27Utilities.IsTableEmpty(oBomber[reftGroundAttackLocation])) then
                                        local iAOE, iStrikeDamage = M27UnitInfo.GetBomberAOEAndStrikeDamage(oBomber)
                                        if bDebugMessages == true then LOG(sFunctionRef..': oBomber[reftGroundAttackLocation]='..repru(oBomber[reftGroundAttackLocation])..'; distance to the bomber target='..M27Utilities.GetDistanceBetweenPositions(oBomber[reftGroundAttackLocation], oBomberCurTarget:GetPosition())..'; iAOE='..iAOE) end
                                        if M27Utilities.GetDistanceBetweenPositions(oBomber[reftGroundAttackLocation], oBomberCurTarget:GetPosition()) > iAOE then
                                            bRemoveCurTarget = true
                                        end
                                    end
                                end

                                --Is the target hard to hit and wasnt when first assigned? If so then reassign target
                                local iFailedHitThreshold = 2
                                if EntityCategoryContains(categories.STRUCTURE, oBomberCurTarget.UnitId) then iFailedHitThreshold = 1 end
                                if bRemoveCurTarget == false and oBomberCurTarget[refiFailedHitCount] >= iFailedHitThreshold and not (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill) then
                                    --have we either switched from hard to hit to hard to hit, or had a significant increase in how hard to hit?
                                    if (oBomberCurTarget[refiFailedHitCount] or 0) - (oBomber[refiTargetFailedHitCount] or 0) >= iFailedHitThreshold then
                                        --if (oBomberCurTarget[refiFailedHitCount] or 0) < iFailedHitThreshold or (oBomberCurTarget[refiFailedHitCount] or 0) - (oBomber[refiTargetFailedHitCount] or 0) >= 5 then
                                        bRemoveCurTarget = true
                                        --end
                                    end
                                end

                                if bRemoveCurTarget == false then
                                    --Air dominance - switch to target part-complete shields and AA; more generally switch to target part complete fixed shields
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': If in air dom mode will search for nearby part-constructed shields and any AA; otherwise just search for part-constructed shields. Bomber cur targetID=' .. oBomberCurTarget.UnitId)
                                    end
                                    local iCategoriesToSearch
                                    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                                        iCategoriesToSearch = M27UnitInfo.refCategoryFixedShield + M27UnitInfo.refCategoryGroundAA
                                    else
                                        if M27UnitInfo.GetUnitTechLevel(oBomber) <= 2 then
                                            iCategoriesToSearch = M27UnitInfo.refCategoryFixedShield
                                        else
                                            iCategoriesToSearch = nil
                                        end
                                    end
                                    if iCategoriesToSearch and not (EntityCategoryContains(iCategoriesToSearch, oBomberCurTarget.UnitId)) then
                                        local tNearbyUnitsOfInterest = aiBrain:GetUnitsAroundPoint(iCategoriesToSearch, oBomber:GetPosition(), 125, 'Enemy')
                                        if M27Utilities.IsTableEmpty(tNearbyUnitsOfInterest) == false then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Have nearby shields or AA to consider')
                                            end
                                            for iUnit, oUnit in tNearbyUnitsOfInterest do
                                                --Fixed shield - only target if <75% done
                                                if EntityCategoryContains(M27UnitInfo.refCategoryFixedShield, oUnit.UnitId) and oUnit:GetFractionComplete() <= 0.8 and M27Logic.IsTargetUnderShield(aiBrain, oUnit, M27UnitInfo.GetUnitStrikeDamage(oUnit) * 0.5) == false then
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Shield being constructed, fraction complete=' .. oUnit:GetFractionComplete())
                                                    end
                                                    iNearbyPriorityShieldTargets = iNearbyPriorityShieldTargets + 1
                                                    tNearbyPriorityShieldTargets[iNearbyPriorityShieldTargets] = oUnit
                                                elseif EntityCategoryContains(M27UnitInfo.refCategoryGroundAA, oUnit.UnitId) then
                                                    --Check no nearby shield
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Ground AA detected, checking if under shield')
                                                    end
                                                    if M27Logic.IsTargetUnderShield(aiBrain, oBomberCurTarget, M27UnitInfo.GetUnitStrikeDamage(oUnit) * 0.8) == false then
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': AA not under shield, adding as priority target')
                                                        end
                                                        iNearbyPriorityAATargets = iNearbyPriorityAATargets + 1
                                                        tNearbyPriorityAATargets[iNearbyPriorityAATargets] = oUnit
                                                    elseif bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': AA under shield')
                                                    end
                                                end
                                            end
                                        else
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': No nearby shields or AA to consider')
                                            end
                                        end
                                        if iNearbyPriorityShieldTargets + iNearbyPriorityAATargets > 0 then
                                            --Switch target to this if we are far enough away (based on our tech level)
                                            local oTargetToSwitchTo
                                            if iNearbyPriorityShieldTargets > 0 then
                                                oTargetToSwitchTo = M27Utilities.GetNearestUnit(tNearbyPriorityShieldTargets, oBomber:GetPosition(), aiBrain, false, false)
                                            else
                                                oTargetToSwitchTo = M27Utilities.GetNearestUnit(tNearbyPriorityAATargets, oBomber:GetPosition(), aiBrain, false, false)
                                            end
                                            if bDebugMessages == true then
                                                if M27UnitInfo.IsUnitValid(oTargetToSwitchTo) then
                                                    LOG(sFunctionRef .. ': oTargetToSwitchTo=' .. oTargetToSwitchTo.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oTargetToSwitchTo))
                                                else
                                                    LOG(sFunctionRef .. ': oTargetToSwitchTo is not valid')
                                                end
                                            end
                                            if not (M27UnitInfo.IsUnitValid(oTargetToSwitchTo)) then
                                                --(added all this in for error that didnt actually have!)
                                                M27Utilities.ErrorHandler('Unexpected error as oTargetToSwitchTo is not valid; iNearbyPriorityShieldTargets=' .. iNearbyPriorityShieldTargets .. '; iNearbyPriorityAATargets=' .. iNearbyPriorityAATargets .. '; will do a log of units in the tables')
                                                if M27Utilities.IsTableEmpty(tNearbyPriorityAATargets) then
                                                    LOG('tNearbyPriorityAATargets is empty')
                                                else
                                                    for iUnit, oUnit in tNearbyPriorityAATargets do
                                                        LOG('tNearbyPriorityAATargets oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
                                                    end
                                                end
                                                if M27Utilities.IsTableEmpty(tNearbyPriorityShieldTargets) then
                                                    LOG('tNearbyPriorityShieldTargets is empty')
                                                else
                                                    for iUnit, oUnit in tNearbyPriorityShieldTargets do
                                                        LOG('tNearbyPriorityShieldTargets oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
                                                    end
                                                end
                                            end
                                            local bChangeTarget = true
                                            local iMinDistanceWanted = (M27UnitInfo.GetUnitTechLevel(oBomber) - 1) * 60

                                            if M27Utilities.GetDistanceBetweenPositions(oTargetToSwitchTo:GetPosition(), oBomber:GetPosition()) < iMinDistanceWanted then
                                                bChangeTarget = false
                                            end
                                            if bChangeTarget then
                                                --if oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end
                                                bHaveAssignedNewTarget = true
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Want to switch target to high priority AA or shield. oBomber='..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; oTargetToSwitchTo='..oTargetToSwitchTo.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTargetToSwitchTo))
                                                end
                                                ClearAirUnitAssignmentTrackers(aiBrain, oBomber, true)
                                                TrackBomberTarget(oBomber, oTargetToSwitchTo, 1)
                                                M27Utilities.IssueTrackedClearCommands({ oBomber })
                                                --T3+ bombers - consider moving away from target first to make sure have a clear shot
                                                if M27UnitInfo.GetUnitTechLevel(oBomber) >= 3 or M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oTargetToSwitchTo:GetPosition()) >= 100 then
                                                    TellBomberToAttackTarget(oBomber, oTargetToSwitchTo, false)
                                                else
                                                    IssueAttack({ oBomber }, oTargetToSwitchTo)
                                                end
                                            end
                                        end
                                    elseif bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Bomber cur target is already a shield or AA')
                                    end

                                    if bLookForHigherPriorityShortlist and not (bHaveAssignedNewTarget) then
                                        --Does the shortlist contain a higher priority unit?
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Want to look for higher priority targets in the shortlist (as have just fired a bomb) and dont already have a higher priority target assigned')
                                        end
                                        --if not(oBomber[refbDontCheckForBetterTargets]) then
                                        CheckForBetterBomberTargets(oBomber, true)
                                        --end
                                    end

                                    if not (oBomber[refbPartOfSpecialAttack]) and not (bHaveAssignedNewTarget) then
                                        --Check if shielded unless part of large attack
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Checking if current target is shielded')
                                            if oBomber[refiCurTargetNumber] == 1 then
                                                LOG(sFunctionRef .. ': Position of first target is ' .. repru(oBomberCurTarget:GetPosition()))
                                                M27Utilities.DrawLocation(oBomberCurTarget:GetPosition(), nil, 3)
                                            end --draw black circle around target
                                        end

                                        if M27Logic.IsTargetUnderShield(aiBrain, oBomberCurTarget, math.max((oBomber[refiShieldIgnoreValue] or 0) * 1.1, (oBomber[refiShieldIgnoreValue] or 0) + 100)) == true then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Current target is shielded so will remove')
                                            end
                                            bRemoveCurTarget = true
                                        end
                                    end
                                end

                                if bRemoveCurTarget == true and not (bHaveAssignedNewTarget) then
                                    --if oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end
                                    if oBomber[refiCurTargetNumber] == nil then
                                        M27Utilities.ErrorHandler('Bomber cur target number is nil; reftTargetList size=' .. table.getn(oBomber[reftTargetList]))
                                    end
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Removing bombers current target as it is nil or dead, iCurTargetNumber=' .. oBomber[refiCurTargetNumber]..'; Bomber='..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber))
                                        if oBomberCurTarget then LOG(sFunctionRef..': oBomberCurTarget is not nil, UnitId='..oBomberCurTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomberCurTarget))
                                        else LOG(sFunctionRef..': oBomberCurTarget is nil')
                                        end
                                    end
                                    --Dont want to use the normal clearairunitassignmenttrackers, as are only clearing the current entry
                                    oBomber[refbOnAssignment] = false
                                    --Only remove trackers on the first target of the bomber
                                    ClearTrackersOnUnitsTargets(oBomber, true)
                                    table.remove(oBomber[reftTargetList], oBomber[refiCurTargetNumber])
                                    --Clear current target
                                    M27Utilities.IssueTrackedClearCommands({ oBomber })
                                    --Reissue orders to attack each subsequent target
                                    if M27Utilities.IsTableEmpty(oBomber[reftTargetList]) == false then
                                        for iTarget, tTarget in oBomber[reftTargetList] do
                                            if M27UnitInfo.IsUnitValid(tTarget[refiShortlistUnit]) then
                                                TellBomberToAttackTarget(oBomber, tTarget[refiShortlistUnit], false)
                                            end
                                        end
                                    end

                                    if M27Utilities.IsTableEmpty(oBomber[reftTargetList]) == true then
                                        oBomber[refiCurTargetNumber] = 0
                                        bBomberHasDeadOrShieldedTarget = false
                                        --Will clear the trackers below
                                        break
                                    end
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Bomber target list size=' .. table.getn(oBomber[reftTargetList]))
                                    end
                                else
                                    --Consider reissuing movement target for cliff blocking
                                    if bReissueIfBlocked then
                                        --Should only set this to true in rare cases e.g. after bomb fired, as below test not perfect - we're using the bomber unit target position rather than the ground location the bomber has targetted
                                        local tPreTargetViaPoint = GetBomberPreTargetViaPoint(oBomber, oBomberCurTarget:GetPosition())
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. 'Recently fired bomb, checking if we think we are blocked when attacking target; tPreTargetViaPoint=' .. repru((tPreTargetViaPoint or { 'nil' })))
                                        end
                                        if M27Utilities.IsTableEmpty(tPreTargetViaPoint) == false then
                                            --if oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end
                                            --Expect to be blocked so want to reissue
                                            M27Utilities.IssueTrackedClearCommands({ oBomber })
                                            if bDebugMessages == true then LOG(sFunctionRef..': Bomber expects to be blocked so will clear commands and then reissue orders to its target list. bomber='..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)) end
                                            if M27Utilities.IsTableEmpty(oBomber[reftTargetList]) == false then
                                                for iTarget, tTarget in oBomber[reftTargetList] do
                                                    if M27UnitInfo.IsUnitValid(tTarget[refiShortlistUnit]) then
                                                        TellBomberToAttackTarget(oBomber, tTarget[refiShortlistUnit], false)
                                                    end
                                                end
                                            end
                                        end
                                    end

                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Bomber current target isnt dead, UnitId=' .. oBomberCurTarget.UnitId .. '; will draw circle around target position ' .. repru(oBomberCurTarget:GetPosition()))
                                        M27Utilities.DrawLocation(oBomberCurTarget:GetPosition(), nil, 4, 100)
                                    end
                                    bBomberHasDeadOrShieldedTarget = false
                                    break
                                end
                            end
                        end
                    else
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Bomber has no target list')
                        end
                    end
                end
            end
        end
    end
    if M27Utilities.IsTableEmpty(oBomber[reftTargetList]) == true and not(bHaveMoveCommand) and not(oBomber[M27UnitInfo.refbSpecialMicroActive]) then
        if bDebugMessages == true then
            LOG(sFunctionRef..': Bombers target list is empty so making it available and sending it to the nearest rally point unless it has special logic; GameTime='..GetGameTimeSeconds())
        end
        ClearAirUnitAssignmentTrackers(oBomber:GetAIBrain(), oBomber)
        --oBomber[refbOnAssignment] = false
        --oBomber[reftTargetList] = {}
    end
    if bDebugMessages == true then
        LOG(sFunctionRef..': Bomer cur target='..(oBomber[refiCurTargetNumber] or 0))
        if oBomber[refiCurTargetNumber] >= 1 then
            LOG('Target unit ID at end of this function='..oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit].UnitId)
        end
    end
    if oBomber[refbPartOfSpecialAttack] == true then
        oBomber[refbOnAssignment] = true
    end
    oBomber[refiBomberTargetLastAssessed] = GetGameTimeSeconds()
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

--[[function TestProjectileTracking(projectile)
    local iDelayWanted = 10
    local iOrigTime = GetGameTimeSeconds()
    while GetGameTimeSeconds() - iOrigTime < iDelayWanted do
        if projectile then
            LOG('Testing projectile, time since called function='..GetGameTimeSeconds() - iOrigTime..'; Projectile.Dead='..tostring((projectile.dead or false))..'; reprs of projectile='..reprs(projectile))
            if projectile.IsDestroyed then LOG('Is destroyed='..tostring(projectile:IsDestroyed())) end
            if projectile.Impacts and projectile.Impacts > 0 then LOG('Bomb has landed') end
            if projectile.Impacts then
                LOG('.Impacts is valid')
                LOG('Log of projectile.Impacts='..projectile.Impacts..'; Is projectile.Impacts > 0='..tostring(projectile.Impacts > 0))
            end

        else
        LOG('Projectile is no longer valid')
        end
        WaitSeconds(1)
    end
    LOG('Finished projectile tracking')
end--]]

function TrackBombImpact(aiBrain, oBomber, oTarget, projectile, bConsiderChangingTargetOnImpact, bTemporarilyTrackStrikeDamage)
    local sFunctionRef = 'TrackBombImpact'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end

    local iStrikeDamage = 0
    if M27UnitInfo.IsUnitValid(oBomber) and bTemporarilyTrackStrikeDamage and M27UnitInfo.IsUnitValid(oTarget) then
        --The bomber is no longer targeting this unit, make sure we still have strike damage assigned to the unit temporarily so we dont retarget it
        local iAOE, iActualStrikeDamage = M27UnitInfo.GetBomberAOEAndStrikeDamage(oBomber)
        iStrikeDamage = iActualStrikeDamage
        oTarget[refiStrikeDamageAssigned] = (oTarget[refiStrikeDamageAssigned] or 0) + iStrikeDamage


    end

    local iCurCount = 0
    local iTargetHealth
    local iTargetShieldHealth
    local iOriginalHealth
    local iOriginalShieldHealth
    if M27UnitInfo.IsUnitValid(oTarget) then
        iTargetHealth = oTarget:GetHealth()
        iTargetShieldHealth = M27UnitInfo.GetCurrentAndMaximumShield(oTarget)
        iOriginalHealth = iTargetHealth
        iOriginalShieldHealth = iTargetShieldHealth
    end
    local bFailedAttack = false
    while projectile do
        if bDebugMessages == true then LOG(sFunctionRef..': Start of loop, iCurCount='..iCurCount) end
        iCurCount = iCurCount + 1
        if iCurCount > 20 then --Means have been waiting more than 10s for bomb to land; FAF develop change that has .impacts is only expected in main FAF as of 20 August 2022, so if before this date that coudl be why
            M27Utilities.ErrorHandler('Has been too long with no impact, something has gone wrong with tracking, will abort. reprs of projectile='..reprs(projectile))
            if M27UnitInfo.IsUnitValid(oTarget) then
                if iTargetHealth >= iOriginalHealth then
                    if iOriginalShieldHealth > 0 then iTargetShieldHealth = M27UnitInfo.GetCurrentAndMaximumShield(oTarget) end
                    if iTargetShieldHealth >= iOriginalShieldHealth then
                        bFailedAttack = true
                    end
                end
            end
            break
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitTicks(5)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

        if projectile.M27Impacted or projectile.Impacts > 0 then
            --Bomb has impacted; has the unit's health changed?
            --if bDebugMessages == true then LOG(sFunctionRef..': Projectile has impacted') end
            if iTargetHealth > 0 and M27UnitInfo.IsUnitValid(oTarget) then
                if oTarget:GetHealth() >= iTargetHealth then
                    local iCurShieldHealth = 0
                    if iTargetShieldHealth > 0 then iCurShieldHealth = M27UnitInfo.GetCurrentAndMaximumShield(oTarget) end
                    if iTargetShieldHealth == 0 or iCurShieldHealth >= iTargetShieldHealth then
                        --Hasnt taken any damage; is it under a fixed shield?
                        if not(M27Logic.IsTargetUnderShield(aiBrain, oTarget)) then
                            --Target hasnt taken any damage from the impact but isnt under a shield, so bomb has failed
                            bFailedAttack = true
                        end
                    end

                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Bomb from bomber '..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..' has impacted unit '..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..'; bFailedAttack='..tostring(bFailedAttack)) end
            break
        else
            --Update unit health tracking
            if M27UnitInfo.IsUnitValid(oTarget) then
                iTargetHealth = oTarget:GetHealth()
                if iTargetShieldHealth > 0 then iTargetShieldHealth = M27UnitInfo.GetCurrentAndMaximumShield(oTarget) end
            else
                iTargetHealth = 0
            end
            --if bDebugMessages == true then LOG(sFunctionRef..': Projectile still there. iTargetHealth='..iTargetHealth) end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of loop. is target still valid='..tostring(M27UnitInfo.IsUnitValid(oTarget))..'; Bomber LC='..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'; Is bomber valid='..tostring(M27UnitInfo.IsUnitValid(oBomber))) end
    if M27UnitInfo.IsUnitValid(oTarget) then
        if bFailedAttack then
            oTarget[refiFailedHitCount] = (oTarget[refiFailedHitCount] or 0) + 1
            if oTarget[refiFailedHitCount] > 0 and bConsiderChangingTargetOnImpact then
                if bDebugMessages == true then LOG(sFunctionRef..': Failed ot damage target so will call update bomber targets') end
                ForkThread(UpdateBomberTargets, oBomber, false)
            end
        else
            oTarget[refiFailedHitCount] = math.max(-1, (oTarget[refiFailedHitCount] or 0) - 0.5)
        end

        if iStrikeDamage > 0 and bTemporarilyTrackStrikeDamage then
            if bDebugMessages == true then LOG(sFunctionRef..': About to decrease target strike damage assigned as bomb has now landed. Target='..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..'; Strike damage before decrease='..oTarget[refiStrikeDamageAssigned]) end
            oTarget[refiStrikeDamageAssigned] = math.max(0, oTarget[refiStrikeDamageAssigned] - iStrikeDamage)
            if bDebugMessages == true then LOG(sFunctionRef..': Strike damage after decrease='..oTarget[refiStrikeDamageAssigned]) end
        end
    else
        if M27UnitInfo.IsUnitValid(oBomber) and M27UnitInfo.GetUnitLifetimeCount(oBomber) == 1 and not(M27Chat.tiM27VoiceTauntByType['Effective Bomber']) then
            local iVetLevel = (oBomber.VetLevel or oBomber.Sync.VeteranLevel)
            if bDebugMessages == true then LOG(sFunctionRef..': Bomber vet level='..(iVetLevel or 'nil')..'; Mass killed='..(oBomber.VetExperience or oBomber.Sync.totalMassKilled or 'nil')) end
            local iVetLevelWanted = 3
            if EntityCategoryContains(categories.TECH3 + categories.EXPERIMENTAL, oBomber.UnitId) then iVetLevelWanted = 2 end
            if iVetLevel >= iVetLevelWanted or (not(EntityCategoryContains(categories.EXPERIMENTAL, oBomber.UnitId)) and (oBomber.VetExperience or oBomber.Sync.totalMassKilled) >= 6000) or ((oBomber.VetExperience or oBomber.Sync.totalMassKilled) >= 30000) then
                local sMessage = 'How are you enjoying the shock and awe, Commander?'
                if math.random(1,2) == 1 then
                    if EntityCategoryContains(categories.TECH3, oBomber.UnitId) and __blueprints[oTarget.UnitId].Economy.BuildCostMass >= 800 then sMessage = 'Ouch! That must have been expensive!'
                    elseif EntityCategoryContains(categories.TECH1, oBomber.UnitId) then sMessage = 'Birds away! Let\'s go hunt some engis.'
                    end
                end

                M27Chat.SendMessage(aiBrain, 'Effective Bomber', sMessage, 2, 10000)

            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DelayedBomberTargetRecheck(oBomber, projectile, iDelayBeforeTargetChange)
    local sFunctionRef = 'DelayedBomberTargetRecheck'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    --if M27UnitInfo.GetUnitTechLevel(oBomber) == 3 then bDebugMessages = true end

    --Do we think our bomb will kill the target? If so then change targets now.  If not, then consider changing as part of the projectile tracking
    local bConsiderChangingTargetOnImpact = false
    local bChangeTargetNow = false

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code. Is bomber valid='..tostring(M27UnitInfo.IsUnitValid(oBomber))) end

    if M27UnitInfo.IsUnitValid(oBomber) then
        local bReturnToBase = true --only used if are going to clear the target
        if oBomber[refbEngiHunterMode] then bReturnToBase = false end

        local aiBrain = oBomber:GetAIBrain()
        local oTarget = oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit]
        if bDebugMessages == true then LOG(sFunctionRef..': Bomber '..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..' - is its target valid='..tostring(M27UnitInfo.IsUnitValid(oTarget))) end
        if M27UnitInfo.IsUnitValid(oTarget) then

            --Do we expect the bomb to kill the target?
            local iAOE, iBomberStrikeDamage = M27UnitInfo.GetBomberAOEAndStrikeDamage(oBomber)
            if bDebugMessages == true then LOG(sFunctionRef..': Target still exists; iBomberStrikeDamage='..(iBomberStrikeDamage or 'nil')..'; oTarget[refiMaxStrikeDamageWanted]='..(oTarget[refiMaxStrikeDamageWanted] or 'nil')..'; Target health='..oTarget:GetHealth()..'; is target under shield='..tostring(M27Logic.IsTargetUnderShield(aiBrain, oTarget, 0, false, false, false))..'; iAOE='..(iAOE or 'nil')) end
            if (oTarget[refiMaxStrikeDamageWanted] or 0) <= iBomberStrikeDamage then
                bChangeTargetNow = true
            else
                if oTarget:GetHealth() * 1.1 <= iBomberStrikeDamage and not(M27Logic.IsTargetUnderShield(aiBrain, oTarget, 0, false, false, false)) then
                    bChangeTargetNow = true
                end
            end
            if not(bChangeTargetNow) then
                --Check in case we are targeting the ground and it is too far away from the target
                if oBomber.GetNavigator and not(oBomber[M27UnitInfo.refbSpecialMicroActive]) and not(M27Utilities.IsTableEmpty(oBomber[reftGroundAttackLocation])) then
                    if bDebugMessages == true then LOG(sFunctionRef..': oBomber[reftGroundAttackLocation]='..repru((oBomber[reftGroundAttackLocation] or {'nil'}))..'; distance to the bomber target='..M27Utilities.GetDistanceBetweenPositions((oBomber[reftGroundAttackLocation] or {0,0,0}), oTarget:GetPosition())..'; iAOE='..(iAOE or 'nil')) end
                    if M27Utilities.GetDistanceBetweenPositions(oBomber[reftGroundAttackLocation], oTarget:GetPosition()) > iAOE then
                        bChangeTargetNow = true
                        bReturnToBase = false
                    end
                end
            end

            if not(bChangeTargetNow) then bConsiderChangingTargetOnImpact = true end
            --TrackBombImpact(aiBrain, oBomber, oTarget, projectile, bConsiderChangingTargetOnImpact, bTemporarilyTrackStrikeDamage)
            if bDebugMessages == true then LOG(sFunctionRef..'If have a projectile then will track bomb impact for bomber '..oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber)..'. Is t able empty for projectile='..tostring(M27Utilities.IsTableEmpty(projectile, true))) end
            if projectile and M27Utilities.IsTableEmpty(projectile, true) == false then ForkThread(TrackBombImpact, aiBrain, oBomber, oTarget, projectile, bConsiderChangingTargetOnImpact, bChangeTargetNow) end
            --Record that the bomber has fired a bomb for tracking relating to this:
            ForkThread(UpdateBomberEffectiveness, aiBrain, oBomber, true)

        else
            bChangeTargetNow = true
        end
        if bDebugMessages == true then LOG(sFunctionRef..': bChangeTargetNow='..tostring(bChangeTargetNow)..'; iDelayBeforeTargetChange='..(iDelayBeforeTargetChange or 'nil')) end

        if bChangeTargetNow then
            --if just fired bomb at an engineer that were trying to kill then also look to kill another nearby engineer (this wont run if this is an engi hunter bomber, i.e. intended for bombers that targeted an engi in the above logic)
            --Will ahve already told bomber to change targets if the engineer died

            --Bombers that fire a salvo - want to wait until finished firing salvo
            if iDelayBeforeTargetChange > 0 then
                local iTimeAtStart = GetGameTimeSeconds()
                local iSalvoDelay = M27UnitInfo.GetBomberSalvoDelay(oBomber) + 0.1 --1 extra tick for backup
                while M27UnitInfo.IsUnitValid(oBomber) do
                    if GetGameTimeSeconds() - oBomber[refiLastFiredBomb] > iSalvoDelay then
                        break
                    elseif GetGameTimeSeconds() - iTimeAtStart > iDelayBeforeTargetChange then
                        break
                    else
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                        WaitTicks(3)
                        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
                    end
                end
            end
            if M27UnitInfo.IsUnitValid(oBomber) then

                local bTargetEngineer = false
                if EntityCategoryContains(M27UnitInfo.refCategoryEngineer, oTarget.UnitId) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering if want to target another engineer as just killed one. Cur target='..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)) end
                    if M27Utilities.IsTableEmpty(oBomber[reftTargetList]) or oBomber[reftTargetList][oBomber[refiCurTargetNumber]][refiShortlistUnit] == oTarget then
                        if bDebugMessages == true then LOG(sFunctionRef..': Will look for another nearby engineer to target') end
                        bTargetEngineer = true
                    end
                end
                ClearAirUnitAssignmentTrackers(aiBrain, oBomber, not(bReturnToBase))
                if bDebugMessages == true then
                    LOG(sFunctionRef..': have just cleared bomber trackers. bReturnToBase='..tostring(bReturnToBase)..'; bTargetEngineer='..tostring(bTargetEngineer))
                    if M27UnitInfo.IsUnitValid(oTarget) then LOG(sFunctionRef..': are no longer targeting unit '..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)) end
                end
                if bTargetEngineer then
                    ForkThread(OneOffTargetNearbyEngineer, aiBrain, oBomber)
                end
            end
        else
            if EntityCategoryContains(M27UnitInfo.refCategoryStructureAA * categories.TECH3, oTarget.UnitId) and EntityCategoryContains(categories.EXPERIMENTAL, oBomber.UnitId) then
                --Experi bomber - if we thought we would kill sam in 1 hit then wouldnt be running hover bombing log, so instead will try hit and run logic
                ForkThread(M27UnitMicro.ExperimentalSAMHitAndRun, oBomber, oTarget)
            else
                --Dont hover-bomb for Torp bombers, T1 bombers, or Non-Notha t2 bombers
                if not(EntityCategoryContains(refCategoryTorpBomber + refCategoryBomber * categories.TECH1 + refCategoryBomber * categories.TECH2 - refCategoryBomber * categories.TECH2 * categories.SERAPHIM, oBomber.UnitId)) then
                    local bHoverBomb = false
                    if not(EntityCategoryContains(refCategoryTorpBomber, oBomber.UnitId)) then
                        if EntityCategoryContains(categories.COMMAND + M27UnitInfo.refCategoryExperimentalLevel, oTarget.UnitId) then
                            bHoverBomb = true
                        elseif oTarget[refiCoordinatedStrikeDamageAssigned] < GetMaxStrikeDamageWanted(oTarget) then
                            if bDebugMessages == true then LOG(sFunctionRef..': oTarget[refiCoordinatedStrikeDamageAssigned]='..oTarget[refiCoordinatedStrikeDamageAssigned]..'; GetMaxStrikeDamageWanted(oUnit)='..GetMaxStrikeDamageWanted(oTarget)..' so will hoverbomb') end
                            bHoverBomb = true
                        else
                            --Do we have close to the expected strike damage?
                            local iCurStrikeDamage = 0
                            local iBomberAOE, iBomberStrikeDamage
                            if oTarget[reftoBombersTargetingUnit] then
                                for iAltBomber, oAltBomber in oTarget[reftoBombersTargetingUnit] do
                                    if M27UnitInfo.IsUnitValid(oAltBomber) and not(EntityCategoryContains(refCategoryTorpBomber, oAltBomber.UnitId)) then
                                        iBomberAOE, iBomberStrikeDamage = M27UnitInfo.GetBomberAOEAndStrikeDamage(oAltBomber)
                                        iCurStrikeDamage = iCurStrikeDamage + iBomberStrikeDamage
                                    end
                                end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': iCurStrikeDamage='..iCurStrikeDamage..'; oTarget[refiCoordinatedStrikeDamageAssigned]='..oTarget[refiCoordinatedStrikeDamageAssigned]) end
                            if iCurStrikeDamage < oTarget[refiCoordinatedStrikeDamageAssigned] then
                                bHoverBomb = true
                            end
                        end
                        --Dont hover-bomb if enemy flak detected (as hover-bombing means our bombersa re likely to die) unless are targeting enemy ACU or very high priority structure threat
                        if bHoverBomb and not(EntityCategoryContains(categories.COMMAND + categories.STRUCTURE * M27UnitInfo.refCategoryExperimentalLevel, oTarget.UnitId)) then
                            if not(aiBrain[refbEnemyHasHadCruisersOrT3AA]) then
                                --DOnt hover-bomb if enemey has no T3 ground AA, since risk they have inties chasing us or T1/T2 groundAA that can hit us
                                bHoverBomb = false
                            else
                                local tNearbyFlak = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMAA * categories.TECH2 + M27UnitInfo.refCategoryStructureAA * categories.TECH2, oBomber:GetPosition(), 70, 'Enemy')

                                if M27Utilities.IsTableEmpty(tNearbyFlak) == false then
                                    local iNearbyFlak = table.getn(tNearbyFlak)
                                    --Ignore if only 1 T2 mobile flak, otherwise dont hover-bomb
                                    if iNearbyFlak > 1 or M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.STRUCTURE, tNearbyFlak)) == false then
                                        bHoverBomb = false
                                    end
                                end
                            end
                        end
                    end

                    if bHoverBomb then ForkThread(M27UnitMicro.HoverBombTarget, aiBrain, oBomber, oTarget) end
                end
            end
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function CheckIfTargetHardToHitBase(oBomber, oTarget)
    local sFunctionRef = 'CheckIfTargetHardToHitBase'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if M27UnitInfo.IsUnitValid(oBomber) and M27UnitInfo.IsUnitValid(oTarget) then

        if EntityCategoryContains(categories.TECH3, oBomber.UnitId) and M27UnitInfo.GetUnitLifetimeCount(oBomber) == 1 then
        end
        --Ignore if dealing with experimental bomber
        if not (EntityCategoryContains(categories.EXPERIMENTAL, oBomber.UnitId)) then
            local iUnitCurHealth, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oTarget)
            iUnitCurHealth = iUnitCurHealth + oTarget:GetHealth()
            local iUnitPrevMaxHealth = oTarget:GetMaxHealth() + iMaxShield
            local iPrevHealth = iUnitCurHealth
            local bFailedAttack = false
            --Have used 1s longer than micro time as not a precise measure
            local iTimeToRun = M27UnitInfo.GetUnitTechLevel(oBomber)
            if M27UnitInfo.DoesBomberFireSalvo(oBomber) then
                iTimeToRun = iTimeToRun + 1
            end

            if bDebugMessages == true then
                LOG(sFunctionRef .. ': About to wait iTimeToRun=' .. iTimeToRun .. ' before checking if target is hard to hit')
            end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitSeconds(iTimeToRun)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            if M27UnitInfo.IsUnitValid(oTarget) then
                iUnitCurHealth, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oTarget)
                iUnitCurHealth = iUnitCurHealth + oTarget:GetHealth()
                --has the target not gained veterancy (as if it has this may have caused health to increase)?
                if iMaxShield + oTarget:GetMaxHealth() <= iUnitPrevMaxHealth then
                    --Has the target taken damage that hasnt been fully repaired by our attack?
                    if iUnitCurHealth >= iPrevHealth + 1 then
                        --Are there nearby shields that might have protected the target?
                        if M27Logic.IsTargetUnderShield(oBomber:GetAIBrain(), oTarget, 0) == false then
                            bFailedAttack = true
                        end
                    end
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': oTarget=' .. oTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oTarget) .. '; oBomber=' .. oBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oBomber) .. '; bFailedAttack=' .. tostring(bFailedAttack) .. '; iUnitPrevMaxHealth=' .. iUnitPrevMaxHealth .. '; iUnitCurHealth=' .. iUnitCurHealth .. '; is unit under shield=' .. tostring(M27Logic.IsTargetUnderShield(oBomber:GetAIBrain(), oTarget, 0)) .. '; oTarget[refiFailedHitCount] before update=' .. (oTarget[refiFailedHitCount] or 0))
                end
                if bFailedAttack == true then
                    oTarget[refiFailedHitCount] = (oTarget[refiFailedHitCount] or 0) + 1
                else
                    if (oTarget[refiFailedHitCount] or 0) <= 0 then
                        oTarget[refiFailedHitCount] = (oTarget[refiFailedHitCount] or 0) - 0.5
                    else
                        oTarget[refiFailedHitCount] = 0
                    end
                end
                if oTarget[refiFailedHitCount] >= 2 then
                    --Reassign targets
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Failed hit count is at least 2 so updating bomber targets')
                    end
                    ForkThread(UpdateBomberTargets, oBomber, false)
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function CheckIfTargetHardToHit(oBomber, oTarget)
    ForkThread(CheckIfTargetHardToHitBase, oBomber, oTarget)
end

function AirThreatChecker(aiBrain)
    --Get enemy total air threat level
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AirThreatChecker'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of cycle')
    end

    local tEnemyAirUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAllAir, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Enemy')
    local tEnemyAirAAUnits, tEnemyAirGroundUnits

    aiBrain[reftNearestEnemyAirThreat] = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain) --Will update below if are any detected threats
    local bEnemyUsingGhettos = false
    if M27Utilities.IsTableEmpty(tEnemyAirUnits) == false then
        local tEnemyTransports = EntityCategoryFilterDown(M27UnitInfo.refCategoryTransport, tEnemyAirUnits)
        if M27Utilities.IsTableEmpty(tEnemyTransports) == false then
            local tCargo
            for iTransport, oTransport in tEnemyTransports do
                if oTransport.GetCargo then
                    tCargo = oTransport:GetCargo()
                    if M27Utilities.IsTableEmpty(tCargo) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryAttackBot, tCargo)) == false then
                        bEnemyUsingGhettos = true
                        break
                    end
                end
            end
        end

        tEnemyAirAAUnits = EntityCategoryFilterDown(M27UnitInfo.refCategoryAirAA, tEnemyAirUnits)
        if bEnemyUsingGhettos then
            tEnemyAirGroundUnits = EntityCategoryFilterDown(M27UnitInfo.refCategoryAirNonScout - M27UnitInfo.refCategoryAirAA, tEnemyAirUnits)
        else
            tEnemyAirGroundUnits = EntityCategoryFilterDown(M27UnitInfo.refCategoryAirNonScout - M27UnitInfo.refCategoryAirAA - M27UnitInfo.refCategoryTransport, tEnemyAirUnits)
        end


        local oNearestAirUnit, oAltNearestUnit
        if M27Utilities.IsTableEmpty(tEnemyAirAAUnits) == false then
            oNearestAirUnit = M27Utilities.GetNearestUnit(tEnemyAirAAUnits, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain)
        end
        if M27Utilities.IsTableEmpty(tEnemyAirGroundUnits) == false then
            if oNearestAirUnit then
                oAltNearestUnit = M27Utilities.GetNearestUnit(tEnemyAirGroundUnits, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain)
                if M27Utilities.GetDistanceBetweenPositions(oAltNearestUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(oNearestAirUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then
                    oNearestAirUnit = oAltNearestUnit
                end
            else
                oNearestAirUnit = M27Utilities.GetNearestUnit(tEnemyAirGroundUnits, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain)
            end
        end
        if oNearestAirUnit then
            aiBrain[reftNearestEnemyAirThreat] = oNearestAirUnit:GetPosition()
            aiBrain[refoNearestEnemyAirThreat] = oNearestAirUnit
            aiBrain[refiNearestEnemyAirThreatActualDist] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[reftNearestEnemyAirThreat])
        end
    end
    --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride, bIncludeAirTorpedo)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': About to calcualte threat level of enemy antiair units.  Threat before this=' .. aiBrain[refiEnemyAirAAThreat])
    end

    local iDecayThresholdFactor = 0.75 --If cur threat is less than this then will start to decay
    local iDecayFactor
    local iIntelCoverage = M27Logic.GetIntelCoverageOfPosition(aiBrain, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], nil, true)
    if iIntelCoverage >= 450 then --Omni fairly close to our base
        iDecayFactor = 0.008
    elseif iIntelCoverage >= 350 then --we or an ally has omni with decent range
        iDecayFactor = 0.004
    elseif iIntelCoverage >= 170 then --T2 radar near our base
        iDecayFactor = 0.002
    else
        iDecayFactor = 0.001
    end
    if aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] >= 550 then
        iDecayFactor = iDecayFactor * 0.5
        if aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] >= 1000 then iDecayFactor = iDecayFactor * 0.25 end
    end

    --Reduce value of enemy air threat in team game since unlikely 1 team will have all the airaa
    local iCurAirAAThreat = M27Logic.GetAirThreatLevel(aiBrain, tEnemyAirUnits, false, true, false, false, false, nil, 0, 0, 0) * 1.1
    if M27Team.iTotalTeamCount >= 3 then iCurAirAAThreat = iCurAirAAThreat / math.min(1.75, (M27Team.iTotalTeamCount - 1.5)) end

    --Also decay enemy air threat
    if iCurAirAAThreat > aiBrain[refiEnemyAirAAThreat] then
        aiBrain[refiEnemyAirAAThreat] = iCurAirAAThreat
    else
        --add in decay to enemy threat
        if iCurAirAAThreat < aiBrain[refiEnemyAirAAThreat] * iDecayThresholdFactor then
            aiBrain[refiEnemyAirAAThreat] = aiBrain[refiEnemyAirAAThreat] - (aiBrain[refiEnemyAirAAThreat] - iCurAirAAThreat) * iDecayFactor
        end
    end


    aiBrain[refiHighestEverEnemyAirAAThreat] = math.max(aiBrain[refiHighestEverEnemyAirAAThreat], aiBrain[refiEnemyAirAAThreat]) --Unlike airaathreat it doesnt get reduced when enemy airaa dies and doesnt suffer from decay

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': aiBrain[refiEnemyAirAAThreat] after update=' .. aiBrain[refiEnemyAirAAThreat])
    end



    --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride, bIncludeAirTorpedo, bBlueprintThreat)
    local iCurAirToGroundThreat = M27Logic.GetAirThreatLevel(aiBrain, tEnemyAirGroundUnits, true, false, false, true, bEnemyUsingGhettos, nil, 0, 0, 0)
    --Reduce enemy air threat if multiple teams
    if M27Team.iTotalTeamCount >= 3 then iCurAirToGroundThreat = iCurAirToGroundThreat / math.min(2, (M27Team.iTotalTeamCount - 1)) end
    aiBrain[refiEnemyAirToGroundThreat] = math.max((aiBrain[refiEnemyAirToGroundThreat] or 0), iCurAirToGroundThreat)
    if not(aiBrain[refbEnemyHasBuiltTorpedoBombers]) and aiBrain[refiEnemyAirToGroundThreat] >= 200 and M27Utilities.IsTableEmpty(tEnemyAirGroundUnits) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(refCategoryTorpBomber, tEnemyAirUnits)) == false then
        aiBrain[refbEnemyHasBuiltTorpedoBombers] = true
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': EnemyAAThreat=' .. aiBrain[refiEnemyAirAAThreat] .. '; Enemy Air to ground threat=' .. aiBrain[refiEnemyAirToGroundThreat])
        if M27Utilities.IsTableEmpty(tEnemyAirUnits) == false then
            LOG(sFunctionRef..': Size of tEnemyAirUnits='..table.getn(tEnemyAirUnits)..'; bEnemyUsingGhettos='..tostring(bEnemyUsingGhettos))
            if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.BOMBER + categories.GROUNDATTACK, tEnemyAirUnits)) == false then
                LOG(sFunctionRef..': Size of bomber nad ground attack air units='..table.getn(EntityCategoryFilterDown(categories.BOMBER + categories.GROUNDATTACK, tEnemyAirUnits))..'; Is table of tEnemyAirGroundUnits empty='..tostring(M27Utilities.IsTableEmpty(tEnemyAirGroundUnits)))
                if table.getn(tEnemyAirGroundUnits) >= 4 then
                    for iAirUnit, oAirUnit in tEnemyAirGroundUnits do
                        LOG(sFunctionRef..': Threat given by enemy air to ground unit '..oAirUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAirUnit)..'='..M27Logic.GetAirThreatLevel(aiBrain, { oAirUnit }, true, false, false, true, true, nil, 0, 0, 0))
                    end
                end
            end
        end
    end
    local iAllAirThreat = aiBrain[refiEnemyAirAAThreat] + aiBrain[refiEnemyAirToGroundThreat] * 0.4
    if iAllAirThreat >= 200 then
        if M27Utilities.IsTableEmpty(tEnemyAirGroundUnits) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryMercy, tEnemyAirGroundUnits)) == false then
            aiBrain[refiTimeOfLastMercy] = GetGameTimeSeconds()
            aiBrain[refbMercySightedRecently] = true
        elseif aiBrain[refbMercySightedRecently] and GetGameTimeSeconds() - aiBrain[refiTimeOfLastMercy] >= 120 then
            aiBrain[refbMercySightedRecently] = false
        end
    elseif aiBrain[refbMercySightedRecently] and GetGameTimeSeconds() - aiBrain[refiTimeOfLastMercy] >= 120 then
        aiBrain[refbMercySightedRecently] = false
    end

    --Increase enemy air threat based on how many factories and of what tech
    local tAirThreatByTech = { 100, 500, 2000, 4000 }
    local tEnemyAirFactories = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirFactory, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), aiBrain[refiMaxScoutRadius], 'Enemy')
    local bWarnOfT3
    if aiBrain[reftEnemyAirFactoryByTech][3] == 0 then bWarnOfT3 = true end
    aiBrain[reftEnemyAirFactoryByTech] = { 0, 0, 0 }
    local iAirFacTech
    if M27Utilities.IsTableEmpty(tEnemyAirFactories) == false then
        for iAirFac, oAirFac in tEnemyAirFactories do
            iAirFacTech = math.min(3, M27UnitInfo.GetUnitTechLevel(oAirFac))
            iAllAirThreat = iAllAirThreat + tAirThreatByTech[M27UnitInfo.GetUnitTechLevel(oAirFac)]
            aiBrain[reftEnemyAirFactoryByTech][iAirFacTech] = aiBrain[reftEnemyAirFactoryByTech][iAirFacTech] + 1
        end
    end
    if bWarnOfT3 and aiBrain[reftEnemyAirFactoryByTech][3] > 0 then
        M27Chat.SendMessage(aiBrain, 'Enemy T3 Air', 'Enemy has T3 air', 0, 10000, true)
    end



    if aiBrain[refiHighestEnemyAirThreat] == nil then
        aiBrain[refiHighestEnemyAirThreat] = 0
    end
    if iAllAirThreat > aiBrain[refiHighestEnemyAirThreat] then
        aiBrain[refiHighestEnemyAirThreat] = iAllAirThreat
    else
        --add in decay to enemy threat
        if iAllAirThreat < aiBrain[refiHighestEnemyAirThreat] * iDecayThresholdFactor then
            aiBrain[refiHighestEnemyAirThreat] = aiBrain[refiHighestEnemyAirThreat] - (aiBrain[refiHighestEnemyAirThreat] - iAllAirThreat) * iDecayFactor
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': iAllAirThreat=' .. iAllAirThreat .. '; aiBrain[refiHighestEnemyAirThreat]=' .. aiBrain[refiHighestEnemyAirThreat] .. '; size of tEnemyAirUnits=' .. table.getn(tEnemyAirUnits))
    end
    local tEnemyGroundAAUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Enemy')
    local iGroundAAThreat = M27Logic.GetAirThreatLevel(aiBrain, tEnemyGroundAAUnits, true, false, true, false, false)
    if iGroundAAThreat > aiBrain[refiEnemyMassInGroundAA] then
        aiBrain[refiEnemyMassInGroundAA] = iGroundAAThreat
    else
        --add in decay to enemy threat
        if iGroundAAThreat < aiBrain[refiEnemyMassInGroundAA] * iDecayThresholdFactor then
            aiBrain[refiEnemyMassInGroundAA] = aiBrain[refiEnemyMassInGroundAA] - (aiBrain[refiEnemyMassInGroundAA] - iGroundAAThreat) * iDecayFactor
        end
    end
    --If enemy has any air units, set air threat to not equal 0, for purposes of air dominance strategy
    if aiBrain[refiHighestEnemyAirThreat] < 40 and M27Utilities.IsTableEmpty(tEnemyAirUnits) == false then
        aiBrain[refiHighestEnemyAirThreat] = 40
    end

    local tMAAUnits = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryMAA, false, true)
    if M27Utilities.IsTableEmpty(tMAAUnits) == true then
        aiBrain[refiOurMAAUnitCount] = 0
    else
        aiBrain[refiOurMAAUnitCount] = table.getn(tMAAUnits)
    end
    aiBrain[refiOurMassInMAA] = M27Logic.GetAirThreatLevel(aiBrain, tMAAUnits, false, false, true, false, false)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Finished cycle, iAllAirThreat=' .. iAllAirThreat .. '; OurMassInMAA=' .. aiBrain[refiOurMassInMAA])
    end


    --air AA wanted:
    local tAirAAUnits = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryAirAA + M27UnitInfo.refCategoryRestorer + M27UnitInfo.refCategoryCzar, false, true)
    local tiAirAAThreatByTech = { 50, 235, 350 }
    local iFriendlyM27AirAA = 0
    local iFriendlyAirFactor
    local iFriendlyDistThreshold = math.max(500, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] + 50)
    --v63 - replaced with subteam:
    --[[for iBrain, oBrain in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] do
        iFriendlyAirFactor = 1
        if not (oBrain:GetArmyIndex() == aiBrain:GetArmyIndex()) then
            --Do we want to consider the air power from this ally? Ignore if multiple teams and far away, and treat as much less valuable if only 2 teams but far away
            if aiBrain[M27Overseer.tiDistToPlayerByIndex][oBrain:GetArmyIndex()] > iFriendlyDistThreshold then
                if M27Team.iTotalTeamCount > 2 then
                    iFriendlyAirFactor = 0
                else
                    iFriendlyAirFactor = 0.4
                end
            end
            if iFriendlyAirFactor > 0 then
                iFriendlyM27AirAA = iFriendlyM27AirAA + (oBrain[refiOurMassInAirAA] or 0) * iFriendlyAirFactor
            end
        end
    end
    M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subrefiFriendlyAirAAThreat] = iFriendlyM27AirAA + (aiBrain[refiOurMassInAirAA] or 0)--]]
    local iAirAAWantedBasedOnThreat = math.max(0, ((aiBrain[refiHighestEnemyAirThreat] or 0) - (aiBrain[refiOurMassInAirAA] or 0) - math.min(aiBrain[refiHighestEnemyAirThreat] * 0.5, M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subrefiFriendlyAirAAThreat] * 0.5)) / tiAirAAThreatByTech[math.min(3, aiBrain[M27Overseer.refiOurHighestAirFactoryTech])])

    aiBrain[refbHaveAirControl] = true
    if aiBrain[refiEnemyAirAAThreat] > 0 and M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subrefiFriendlyAirAAThreat] < aiBrain[refiEnemyAirAAThreat] then
        aiBrain[refbHaveAirControl] = false
    end

    if M27Utilities.IsTableEmpty(tAirAAUnits) == true then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Have no AirAA units so setting amount wanted to 2')
        end
        aiBrain[refiOurMassInAirAA] = 0
        aiBrain[refiAirAAWanted] = math.max(aiBrain[refiAirAANeeded], 2, aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory), iAirAAWantedBasedOnThreat)
    else
        aiBrain[refiOurMassInAirAA] = M27Logic.GetAirThreatLevel(aiBrain, tAirAAUnits, false, true, false, false, false)
        if aiBrain[refiOurMassInAirAA] < aiBrain[refiHighestEnemyAirThreat] then
            aiBrain[refiAirAAWanted] = math.max(aiBrain[refiAirAANeeded], aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory), iAirAAWantedBasedOnThreat)
        else
            aiBrain[refiAirAAWanted] = math.max(aiBrain[refiAirAANeeded], 0)
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Finished calculating how much airAA we want for brain '..aiBrain.Nickname..'. aiBrain[refiOurMassInAirAA]=' .. aiBrain[refiOurMassInAirAA] .. '; aiBrain[refiHighestEnemyAirThreat]=' .. aiBrain[refiHighestEnemyAirThreat] .. '; aiBrain[refiAirAANeeded]=' .. aiBrain[refiAirAANeeded])
        end
    end
    --Emergency MAA checker
    local bEmergencyAA = false
    if aiBrain[refiHighestEnemyAirThreat] > 0 then
        if aiBrain[refiOurMassInMAA] == 0 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': refiHighestEnemyAirThreat=' .. aiBrain[refiHighestEnemyAirThreat] .. '; aiBrain[refiOurMassInMAA]=' .. aiBrain[refiOurMassInMAA] .. ' so are building emergency MAA')
            end
            bEmergencyAA = true
        else
            --Is there an enemy air threat near our base and we dont have much MAA near our base?
            local tNearbyEnemyAirThreat = aiBrain:GetUnitsAroundPoint(refCategoryAirNonScout, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 150, 'Enemy')
            if M27Utilities.IsTableEmpty(tNearbyEnemyAirThreat) == false then
                --Do we have MAA near our base equal to 50% of the enemy air threat in mass, to a minimum of 3 units?
                local tNearbyGroundAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 100, 'Ally')
                if M27Utilities.IsTableEmpty(tNearbyGroundAA) == true then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Have nearby enemy air threat with ' .. table.getn(tNearbyEnemyAirThreat) .. ' units but no nearby MAA so building emergency MAA')
                    end
                    bEmergencyAA = true
                elseif aiBrain[refiAirAANeeded] > 0 or aiBrain[refiAirAAWanted] > 0 then

                    local iOurNearbyMAAThreat = M27Logic.GetAirThreatLevel(aiBrain, tNearbyGroundAA, false, false, true, false, false)
                    local iNearbyEnemyAirThreat = M27Logic.GetAirThreatLevel(aiBrain, tEnemyAirUnits, true, true, false, true, true)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': iOurNearbyMAAThreat=' .. iOurNearbyMAAThreat .. '; iNearbyEnemyAirThreat=' .. iNearbyEnemyAirThreat)
                    end
                    if iOurNearbyMAAThreat < iNearbyEnemyAirThreat * 0.5 then
                        bEmergencyAA = true
                    end
                end
            end
        end
    end
    aiBrain[M27Overseer.refbEmergencyMAANeeded] = bEmergencyAA

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordAvailableAndLowFuelAirUnits(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordAvailableAndLowFuelAirUnits'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if aiBrain:GetArmyIndex() == 3 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryTransport) > 0 then bDebugMessages = true end
    if not(aiBrain.M27IsDefeated) then
        local iAirAACategories = refCategoryAirAA
        local iBomberCategories = refCategoryBomber
        if aiBrain[refiAirAANeeded] > 0 and aiBrain[M27Overseer.refiOurHighestAirFactoryTech] >= 2 then
            --Make idle fighter bombers attack air units as we need airaa
            iAirAACategories = M27UnitInfo.refCategoryFighterBomber
            iBomberCategories = refCategoryBomber - M27UnitInfo.refCategoryFighterBomber
        end

        --Updates aiBrain trackers to record units with and without enough fuel
        local tAllScouts = aiBrain:GetListOfUnits(refCategoryAirScout, false, true)
        local tAllBombers = aiBrain:GetListOfUnits(refCategoryBomber, false, true)
        local tAllAirAA = aiBrain:GetListOfUnits(refCategoryAirAA, false, true)
        local tTorpBombers = aiBrain:GetListOfUnits(refCategoryTorpBomber, false, true)
        local tTransports = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryTransport, false, true)
        local tGunships = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryGunship - categories.EXPERIMENTAL, false, true)
        --Every 10s update list of closest enemy AA in case we dont have the bomber logic triggering and we have airaa that needs checking aginst this; hgowever only decrease the range dont increase it
        if M27Utilities.IsTableEmpty(tAllAirAA) == false and math.floor(GetGameTimeSeconds() / 10) * 10 == math.floor(GetGameTimeSeconds()) then
            local iAACategoryToConsider

            if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] >= 3 then
                iAACategoryToConsider = M27UnitInfo.refCategoryCruiser + M27UnitInfo.refCategoryGroundAA * categories.TECH3
            elseif aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 2 then
                iAACategoryToConsider = M27UnitInfo.refCategoryGroundAA - categories.TECH1
            else
                iAACategoryToConsider = M27UnitInfo.refCategoryGroundAA
            end
            local tClosestEnemyAA = aiBrain:GetUnitsAroundPoint(iAACategoryToConsider, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], math.min(aiBrain[refiClosestEnemyDangerousAADistToOurBase] + 1, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]), 'Enemy')
            if M27Utilities.IsTableEmpty(tClosestEnemyAA) == false then
                local oClosestEnemyAA = M27Utilities.GetNearestUnit(tClosestEnemyAA, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                aiBrain[refiClosestEnemyDangerousAADistToOurBase] = math.min(aiBrain[refiClosestEnemyDangerousAADistToOurBase], aiBrain[M27Overseer.refiDistanceToNearestEnemyBase], M27Utilities.GetDistanceBetweenPositions(oClosestEnemyAA:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) - M27UnitInfo.GetUnitAARange(oClosestEnemyAA) - 20) --If changing the -20 adjustment here also change in the bombermanager update
                if bDebugMessages == true then LOG(sFunctionRef..': Closest enemy dangerous AA dist to our base post update='.. aiBrain[refiClosestEnemyDangerousAADistToOurBase]) end
            end
        end

        local iCurUnitsWithFuel, iCurUnitsWithLowFuel
        local tAllAirUnits = { tAllScouts, tAllBombers, tAllAirAA, tTorpBombers, tTransports, tGunships }
        local tAvailableUnitRef = { reftAvailableScouts, reftAvailableBombers, reftAvailableAirAA, reftAvailableTorpBombers, reftAvailableTransports, reftAvailableGunships }
        local iTypeScout = 1
        local iTypeBomber = 2
        local iTypeAirAA = 3
        local iTypeTorpBomber = 4
        local iTypeTransport = 5
        local iTypeGunship = 6
        local sAvailableUnitRef
        local bUnitIsUnassigned
        local iTimeStamp = GetGameTimeSeconds()
        local sTargetBP, tTargetPos, tOurPosition, bClearAirAATargets, bReturnToRallyPoint
        --local tTargetDestination
        local tNearbyEnemyAA
        local tNearbyFriendlies
        local iCurTechLevel

        local iClosestBomberDistanceToEnemy = 10000
        local iCurDistanceToEnemyBase
        if M27Utilities.IsTableEmpty(tAllBombers) == false then
            for iUnit, oBomber in tAllBombers do
                if M27UnitInfo.IsUnitValid(oBomber) then
                    iCurDistanceToEnemyBase = M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                    if iCurDistanceToEnemyBase < iClosestBomberDistanceToEnemy then
                        iClosestBomberDistanceToEnemy = iCurDistanceToEnemyBase
                    end
                end
            end
        end
        if M27Utilities.IsTableEmpty(tTorpBombers) == false then
            for iUnit, oBomber in tTorpBombers do
                if M27UnitInfo.IsUnitValid(oBomber) then
                    iCurDistanceToEnemyBase = M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                    if iCurDistanceToEnemyBase < iClosestBomberDistanceToEnemy then
                        iClosestBomberDistanceToEnemy = iCurDistanceToEnemyBase
                    end
                end
            end
        end

        --Get details of recently seen cruisers so AirAA can abort:
        local iRecentlySeenCruiserSearchRange = 100
        local tAllRecentlySeenCruisers = {}
        --Add any pond AA recently seen but not currently visible to this
        if bDebugMessages == true then LOG(sFunctionRef..': Is table of enemy untis by pond empty='..tostring(M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond]))) end
        if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond]) == false then
            for iPond, tEnemyUnits in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond] do
                if bDebugMessages == true then LOG(sFunctionRef..': Considering iPond='..iPond..'; is table of enemy units empty for this='..tostring(M27Utilities.IsTableEmpty(tEnemyUnits))) end
                if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                    local tEnemyT2PlusNavalAA = EntityCategoryFilterDown(M27UnitInfo.refCategoryCruiserCarrier, M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond][iPond])
                    if bDebugMessages == true then LOG(sFunctionRef..': Is table of cruisers and carriers empty='..tostring(M27Utilities.IsTableEmpty(tEnemyT2PlusNavalAA))) end
                    if M27Utilities.IsTableEmpty(tEnemyT2PlusNavalAA) == false then
                        for iUnit, oUnit in tEnemyT2PlusNavalAA do
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering enemy unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Is valid='..tostring(M27UnitInfo.IsUnitValid(oUnit))..'; Is last known position empty='..tostring(M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftLastKnownPosition]))..'; Can see unit='..tostring(M27Utilities.CanSeeUnit(aiBrain, oUnit, true))) end
                            if M27UnitInfo.IsUnitValid(oUnit) and M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftLastKnownPosition]) == false and not(M27Utilities.CanSeeUnit(aiBrain, oUnit, true)) then
                                if bDebugMessages == true then LOG(sFunctionRef..': About to add naval unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to AA threats') end
                                table.insert( tAllRecentlySeenCruisers, oUnit)
                            end
                        end
                    end
                end
            end
        end

        aiBrain[reftLowFuelAir] = {}
        iCurUnitsWithLowFuel = 0
        aiBrain[refiPreviousAvailableBombers] = 0
        local iAirStaging = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirStaging)
        if iAirStaging == 0 and aiBrain[refiAirStagingWanted] == 0 and (aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory) >= 2 or aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllAir) >= 10) then
            aiBrain[refiAirStagingWanted] = 1
        end

        --First update the list of engihunter bombers
        if M27Utilities.IsTableEmpty(aiBrain[reftEngiHunterBombers]) == false then
            for iUnit, oUnit in aiBrain[reftEngiHunterBombers] do
                if not (M27UnitInfo.IsUnitValid) or not (oUnit[refbEngiHunterMode]) then
                    aiBrain[reftEngiHunterBombers][iUnit] = nil
                end
            end
        end

        local bCheckForMobileAirStaging = false

        for iUnitType, tAllAirOfType in tAllAirUnits do
            sAvailableUnitRef = tAvailableUnitRef[iUnitType]
            aiBrain[sAvailableUnitRef] = {}
            iCurUnitsWithFuel = 0
            if M27Utilities.IsTableEmpty(tAllAirOfType) == false then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Going through all air units to see if any have low fuel')
                end
                local tCurWaypointTarget, iDistanceToComplete, tUnitCurPosition, iTotalMovementPaths, iCurLoopCount, iCurAirSegmentX, iCurAirSegmentZ, oNavigator
                local iMaxLoopCount = 50
                local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                local tEnemyStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
                local iDistanceFromStartForReset = 20 --If unit is this close to start then will reset it if its not on its first assignment/doesnt have a target thats further away
                local iFuelPercent, iCurTechLevel
                local iDistToOurBase --used e.g. for airaa to decide whether to retreat
                local iDistToEnemyBase --used e.g. for airaa to decide whether to retreat
                local iNavigationDistToEnemybase
                local iTargetUnitDistToEnemyBase
                for iUnit, oUnit in tAllAirOfType do
                    --if iUnitType == iTypeGunship and aiBrain:GetArmyIndex() == 7 and GetGameTimeSeconds() >= 1730 and oUnit.UnitId == 'xsa0203' and oUnit:GetHealth() <= 600 then bDebugMessages = true M27Config.M27ShowUnitNames = true else bDebugMessages = false end
                    --if M27UnitInfo.GetUnitTechLevel(oUnit) == 4 then bDebugMessages = true else bDebugMessages = false end
                    --if M27UnitInfo.GetUnitTechLevel(oUnit) == 3 and M27UnitInfo.GetUnitLifetimeCount(oUnit) == 1 then bDebugMessages = true else bDebugMessages = false end
                    --if oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit) == 'uaa03034' and GetGameTimeSeconds() >= 140 then bDebugMessages = true else bDebugMessages = false end
                    bUnitIsUnassigned = false
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. '; iUnitType=' .. iUnitType .. '; iUnit=' .. iUnit .. '; ID and LC=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; checking if unit is dead and has fuel and whether its on assignment; oUnit[refbSentRefuelCommand]=' .. tostring(oUnit[refbSentRefuelCommand] or false))
                    end
                    if not (oUnit.Dead) and oUnit.GetFractionComplete and oUnit:GetFractionComplete() == 1 then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': oUnit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; Unit state=' .. M27Logic.GetUnitState(oUnit) .. '; Health percent=' .. oUnit:GetHealthPercent() .. '; Fuel ratio=' .. oUnit:GetFuelRatio() .. '; Unit[refbOnAssignment]=' .. tostring(oUnit[refbOnAssignment] or false) .. '; special micro active=' .. tostring(oUnit[M27UnitInfo.refbSpecialMicroActive] or false))
                        end
                        --Backup logic for units attached to a non-air staging structure (that wont get sent an order to issue the units)
                        iFuelPercent = 0
                        if oUnit.GetFuelRatio then
                            iFuelPercent = oUnit:GetFuelRatio()
                        end
                        if iFuelPercent == 1 and not (bCheckForMobileAirStaging) and oUnit:IsUnitState('Attached') then
                            bCheckForMobileAirStaging = true
                        end
                        if not (oUnit[refbSentRefuelCommand]) then

                            iCurTechLevel = M27UnitInfo.GetUnitTechLevel(oUnit)

                            if iAirStaging == 0 or iFuelPercent >= iLowFuelPercent or iCurTechLevel >= 4 or EntityCategoryContains(categories.CANNOTUSEAIRSTAGING, oUnit.UnitId) then
                                if oUnit[refbOnAssignment] == true then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Unit is on assignment')
                                    end
                                    --Check there's not a rare error where unit is on assignment but is actually idle
                                    --This might also be used for transports (havent bothered debugging to confirm since they work as desired)
                                    if M27Logic.IsUnitIdle(oUnit, true, false, nil) then
                                        local iIdleTime = math.floor(GetGameTimeSeconds())
                                        if not (oUnit[reftIdleChecker]) then
                                            oUnit[reftIdleChecker] = {}
                                        end
                                        oUnit[reftIdleChecker][iIdleTime] = true
                                        if oUnit[reftIdleChecker][iIdleTime - 1] then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Air unit is idle so clearing its commands')
                                                if oUnit[refoAirAATarget] and oUnit[refoAirAATarget].GetUnitId then
                                                    LOG('Units target that will be cleared=' .. oUnit[refoAirAATarget].UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit[refoAirAATarget]))
                                                end
                                            end
                                            oUnit[refbOnAssignment] = false
                                            ClearAirUnitAssignmentTrackers(aiBrain, oUnit)
                                            --IssueMove({oUnit}, M27Logic.GetNearestRallyPoint(aiBrain, oUnit:GetPosition()))
                                            bUnitIsUnassigned = true
                                        end
                                    else


                                        --Unit on assignment - check if its reached it, unless special micro is active
                                        if not (oUnit[M27UnitInfo.refbSpecialMicroActive]) then
                                            if iUnitType == iTypeScout then
                                                --Check its not a scout with a dedicated assist target which uses its own logic`
                                                if not (oUnit[refoAssignedAirScout]) then
                                                    tCurWaypointTarget = oUnit[reftMovementPath][oUnit[refiCurMovementPath]]
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Checking if iUnit=' .. iUnit .. ' has reached its target; cur target=' .. repru(tCurWaypointTarget))
                                                    end
                                                    if M27Utilities.IsTableEmpty(tCurWaypointTarget) == false then
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': tCurWaypointTarget=' .. repru(tCurWaypointTarget))
                                                        end
                                                        iDistanceToComplete = oUnit:GetBlueprint().Intel.VisionRadius * 0.8
                                                        tUnitCurPosition = oUnit:GetPosition()
                                                        local iDistanceToCurTarget = M27Utilities.GetDistanceBetweenPositions(tUnitCurPosition, tCurWaypointTarget)
                                                        iCurLoopCount = 0

                                                        iTotalMovementPaths = table.getn(oUnit[reftMovementPath])
                                                        iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(tCurWaypointTarget)
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': iDistanceToCurTarget=' .. iDistanceToCurTarget .. '; iDistanceToComplete=' .. iDistanceToComplete .. '; aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastScouted]=' .. aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastScouted] .. '; iTimeStamp=' .. iTimeStamp)
                                                        end
                                                        --Check if are either close to the target, or have had recent visual of the target

                                                        while iDistanceToCurTarget <= iDistanceToComplete or GetTimeSinceLastScoutedLocation(aiBrain, tCurWaypointTarget) <= math.max(2, aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval] or 500 - 10) do
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': Are close enough to target or have already had recent visual of the target, checking unit on assignment, iCurLoopCount=' .. iCurLoopCount .. '; iTimeStamp=' .. iTimeStamp .. '; [refiLastScouted]=' .. aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastScouted] .. '; iCurAirSegmentX-Z=' .. iCurAirSegmentX .. '-' .. iCurAirSegmentZ)
                                                            end
                                                            iCurLoopCount = iCurLoopCount + 1
                                                            if iCurLoopCount > iMaxLoopCount then
                                                                M27Utilities.ErrorHandler('Infinite loop')
                                                                break
                                                            end

                                                            aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] - 1
                                                            oUnit[refiCurMovementPath] = oUnit[refiCurMovementPath] + 1
                                                            if oUnit[refiCurMovementPath] > iTotalMovementPaths then
                                                                if bDebugMessages == true then
                                                                    LOG(sFunctionRef .. ': Unit has reached all its movement paths so making it available')
                                                                end
                                                                ClearAirUnitAssignmentTrackers(aiBrain, oUnit)
                                                                bUnitIsUnassigned = true
                                                                break
                                                                --oUnit[refbOnAssignment] = false
                                                            else
                                                                tCurWaypointTarget = oUnit[reftMovementPath][oUnit[refiCurMovementPath]]
                                                                if bDebugMessages == true then
                                                                    LOG(sFunctionRef .. ': Scout has reached target, increasing its movement path 1 to ' .. oUnit[refiCurMovementPath] .. '; location of this=' .. repru(tCurWaypointTarget))
                                                                end
                                                                if M27Utilities.IsTableEmpty(tCurWaypointTarget) == true then
                                                                    if bDebugMessages == true then
                                                                        LOG(sFunctionRef .. ': Units current target is empty so making it available again')
                                                                    end
                                                                    ClearAirUnitAssignmentTrackers(aiBrain, oUnit)
                                                                    bUnitIsUnassigned = true
                                                                    --oUnit[refbOnAssignment] = false
                                                                    break
                                                                else
                                                                    iDistanceToCurTarget = M27Utilities.GetDistanceBetweenPositions(tUnitCurPosition, tCurWaypointTarget)
                                                                    iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(tCurWaypointTarget)
                                                                end
                                                            end
                                                        end
                                                        if iCurLoopCount == 0 then
                                                            --Scout not close to any destination, check if it's close to the start and reset if it is (unless it has an action to move away and hasnt scouted anywhere yet)
                                                            if M27Utilities.GetDistanceBetweenPositions(tStartPosition, tUnitCurPosition) < iDistanceFromStartForReset then
                                                                local bConsiderForReset = false
                                                                if not (oUnit[M27UnitInfo.refbSpecialMicroActive]) then
                                                                    if oUnit[refiCurMovementPath] > 1 then
                                                                        bConsiderForReset = true
                                                                    else
                                                                        if oUnit.GetNavigator then
                                                                            oNavigator = oUnit:GetNavigator()
                                                                            if oNavigator.GetCurrentTargetPos then
                                                                                if M27Utilities.GetDistanceBetweenPositions(oNavigator:GetCurrentTargetPos(), tStartPosition) < iDistanceFromStartForReset then
                                                                                    bConsiderForReset = true
                                                                                end
                                                                            end
                                                                        end
                                                                    end
                                                                end
                                                                if bConsiderForReset == true then
                                                                    --Reset scout to prevent risk of it reaching a movement path but not registering in above code
                                                                    if bDebugMessages == true then
                                                                        LOG(sFunctionRef .. ': Reseting scout trackers and clearing its orders')
                                                                    end
                                                                    ClearAirUnitAssignmentTrackers(aiBrain, oUnit)
                                                                end
                                                            end
                                                        else
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': iCurLoopCount=' .. iCurLoopCount .. '; so scout managed to reach at least one destination')
                                                            end
                                                            --Scout managed to reach at least one destination
                                                            if oUnit[refiCurMovementPath] <= iTotalMovementPaths then
                                                                if bDebugMessages == true then
                                                                    local iLifetimeCount = M27UnitInfo.GetUnitLifetimeCount(oUnit)
                                                                    LOG(sFunctionRef .. ': About to clear scouts path and then reissue remaining paths that scout hasnt reached yet; scout unique count=' .. iLifetimeCount)
                                                                end
                                                                M27Utilities.IssueTrackedClearCommands({ oUnit })
                                                                ClearPreviousMovementEntries(aiBrain, oUnit) --Will remove earlier movement path entries and update assignment trackers

                                                                for iPath, tPath in oUnit[reftMovementPath] do
                                                                    IssueMove({ oUnit }, tPath)
                                                                end
                                                            else
                                                                if bDebugMessages == true then
                                                                    LOG(sFunctionRef .. ': CurMovementPath > total movement paths so scout must have reached all its destinations - making scout available again')
                                                                end
                                                                bUnitIsUnassigned = true
                                                                ClearAirUnitAssignmentTrackers(aiBrain, oUnit)
                                                                --oUnit[refbOnAssignment] = false
                                                            end
                                                        end

                                                    else
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': Current movement path is empty so making scout available')
                                                        end
                                                        --oUnit[refbOnAssignment] = false
                                                        ClearAirUnitAssignmentTrackers(aiBrain, oUnit)
                                                        bUnitIsUnassigned = true
                                                    end
                                                elseif bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Scout ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' is assigned to assist unit ' .. oUnit[refoAssignedAirScout].UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit[refoAssignedAirScout]))
                                                end
                                            elseif iUnitType == iTypeBomber or iUnitType == iTypeTorpBomber then
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Have a bomber or torp bomber, will check its targets; refbOnAssignment pre check=' .. tostring(oUnit[refbOnAssignment]))
                                                end
                                                UpdateBomberTargets(oUnit)
                                                if oUnit[refbOnAssignment] == false and not (oUnit[M27UnitInfo.refbSpecialMicroActive]) then
                                                    bUnitIsUnassigned = true
                                                end
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Unit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; refbOnAssignment post check=' .. tostring(oUnit[refbOnAssignment]))
                                                end
                                            elseif iUnitType == iTypeGunship then
                                                --Stop if gunship low health and send it back to our base
                                                if M27UnitInfo.GetUnitHealthPercent() <= iGunshipLowHealthPercent then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Gunship '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' has health percent='..M27UnitInfo.GetUnitHealthPercent()..' so will clear any trackers') end
                                                    ClearAirUnitAssignmentTrackers(aiBrain, oUnit)
                                                    bUnitIsUnassigned = true
                                                end
                                            elseif iUnitType == iTypeAirAA then
                                                bClearAirAATargets = false
                                                bReturnToRallyPoint = false
                                                if oUnit[refoAirAATarget] == nil or oUnit[refoAirAATarget].Dead then
                                                    bClearAirAATargets = true
                                                else
                                                    --Check if want to stop chasing the target
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Our unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' is currently targetting enemy unit ' .. oUnit[refoAirAATarget].UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit[refoAirAATarget]))
                                                    end
                                                    if not (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance) then
                                                        --Want to continue chasing regardless of how far away we go if we're in air dominance mode

                                                        sTargetBP = oUnit[refoAirAATarget].UnitId
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': Checking if sTargetBP ' .. sTargetBP .. ' is an air scout or airAA unit')
                                                        end
                                                        if EntityCategoryContains(refCategoryAirScout, sTargetBP) and aiBrain[refbNonScoutUnassignedAirAATargets] then
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': Clearing target as its an air scout and we have bigger fish to fry')
                                                            end
                                                            bClearAirAATargets = true
                                                            bReturnToRallyPoint = true
                                                        else
                                                            --Non-scout target - consider not following if we arent on our side of the map
                                                            --Are we closer to enemy base than ours, or might be near dangerous enemy airaa?
                                                            tOurPosition = oUnit:GetPosition()

                                                            iDistToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tEnemyStartPosition, tOurPosition)
                                                            iDistToOurBase = M27Utilities.GetDistanceBetweenPositions(tStartPosition, tOurPosition)
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': Checking how close we are to our start and enemy start; distance to enemy=' .. iDistToEnemyBase .. '; distance to our start=' .. iDistToOurBase..'; aiBrain[refiClosestEnemyDangerousAADistToOurBase]='..aiBrain[refiClosestEnemyDangerousAADistToOurBase])
                                                            end

                                                            if iDistToEnemyBase < iDistToOurBase or iDistToOurBase >= aiBrain[refiClosestEnemyDangerousAADistToOurBase] then
                                                                --are we not in combat range of the enemy target?
                                                                tTargetPos = oUnit[refoAirAATarget]:GetPosition()
                                                                if bDebugMessages == true then
                                                                    LOG(sFunctionRef .. ': Checking if enemy unit is within our combat range; our range=' .. oUnit:GetBlueprint().Weapon[1].MaxRadius..'; Dist to target units position='..M27Utilities.GetDistanceBetweenPositions(tTargetPos, tOurPosition)..'; target unit facing angle='..M27UnitInfo.GetUnitFacingAngle(oUnit[refoAirAATarget])..'; Angle from target unit to our base='..M27Utilities.GetAngleFromAToB(oUnit[refoAirAATarget]:GetPosition(), tStartPosition)..'; Angle dif='..M27Utilities.GetAngleDifference(M27UnitInfo.GetUnitFacingAngle(oUnit[refoAirAATarget]), M27Utilities.GetAngleFromAToB(oUnit[refoAirAATarget]:GetPosition(), tStartPosition)))
                                                                end

                                                                if M27Utilities.GetDistanceBetweenPositions(tTargetPos, tOurPosition) - 1 > oUnit:GetBlueprint().Weapon[1].MaxRadius then
                                                                    --is it moving further away from our base? Approximate by getting the unit's facing angle
                                                                    --[[if oUnit[refoAirAATarget].GetNavigator then
                                                                        tTargetDestination = oUnit[refoAirAATarget]:GetNavigator():GetCurrentTargetPos()
                                                                    else
                                                                        tTargetDestination = oUnit[refoAirAATarget]:GetPosition()
                                                                    end
                                                                    if bDebugMessages == true then
                                                                        LOG(sFunctionRef .. ': Checking if enemy unit navigator target is closer to enemy base than the unit; dist for navigator target to enemy base='..M27Utilities.GetDistanceBetweenPositions(tTargetDestination, tEnemyStartPosition))
                                                                    end
                                                                    iNavigationDistToEnemybase = M27Utilities.GetDistanceBetweenPositions(tTargetDestination, tEnemyStartPosition)--]]
                                                                    --Is the destination of the target unit opposite direction to our base?
                                                                    if M27Utilities.GetAngleDifference(M27UnitInfo.GetUnitFacingAngle(oUnit[refoAirAATarget]), M27Utilities.GetAngleFromAToB(oUnit[refoAirAATarget]:GetPosition(), tStartPosition)) >= 100 then
                                                                        --Is it not near our ACU? (use double normal threshold)
                                                                        if bDebugMessages == true then
                                                                            LOG(sFunctionRef .. ': Checking if enemy unit is near our ACU, distance between ACU and target unit=' .. M27Utilities.GetDistanceBetweenPositions(tTargetPos, M27Utilities.GetACU(aiBrain):GetPosition()))
                                                                        end
                                                                        if M27Utilities.GetDistanceBetweenPositions(tTargetPos, M27Utilities.GetACU(aiBrain):GetPosition()) > aiBrain[refiNearToACUThreshold] + math.min(aiBrain[refiNearToACUThreshold], 40) then
                                                                            --Dont run if we have friendly units and there is no AA of our current tech level or better

                                                                            --NOTE: if making changes to below, also consider whether to change the logic for assigning the target in the first place which has a similar check for if enemy air near friendly units
                                                                            --currently have set range to double the range when target first assigned
                                                                            tNearbyFriendlies = M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure + categories.LAND + categories.NAVAL + M27UnitInfo.refCategoryTorpBomber + M27UnitInfo.refCategoryBomber, tTargetPos, iAssistNearbyUnitRange + math.min(iAssistNearbyUnitRange, 40), 'Ally'))
                                                                            --Do we have any friendly units nearby, and/or our closest bomber to the enemy base is a similar distance from the base to the air unit we are targetting and our target is significantly slower than us? (as e.g. strat bombers can outpace inties meaning the intie ends up out of range until the strat bomber turns)
                                                                            if M27Utilities.IsTableEmpty(tNearbyFriendlies) and (M27Utilities.GetDistanceBetweenPositions(tTargetPos, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) - 50 < iClosestBomberDistanceToEnemy or oUnit[refoAirAATarget]:GetBlueprint().Air.MaxAirspeed > oUnit:GetBlueprint().Air.MaxAirspeed) then
                                                                                if bDebugMessages == true then
                                                                                    LOG(sFunctionRef .. ': Will clear target since its heading towards enemy base and we dont want to follow it')
                                                                                end
                                                                                bClearAirAATargets = true
                                                                                bReturnToRallyPoint = true
                                                                            else
                                                                                if bDebugMessages == true then
                                                                                    LOG(sFunctionRef .. ': Have nearby friendly units, will check if any enemy AA')
                                                                                end
                                                                                --Have nearby friendly units, but still abort if significant enemy groundAA near us since we arent near our ACU
                                                                                tNearbyEnemyAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, tOurPosition, 110, 'Enemy')
                                                                                if M27Utilities.IsTableEmpty(tNearbyEnemyAA) == false then
                                                                                    --Is any of the ground AA at our tech level or greater?
                                                                                    iCurTechLevel = M27UnitInfo.GetUnitTechLevel(oUnit)
                                                                                    for iEnemy, oEnemy in tNearbyEnemyAA do
                                                                                        if M27UnitInfo.GetUnitTechLevel(oEnemy) >= iCurTechLevel then
                                                                                            if bDebugMessages == true then
                                                                                                LOG(sFunctionRef .. ': Enemy has AA of at least teh same tech level as us; iCurTechLevel=' .. iCurTechLevel .. '; Enemy AA unit=' .. oEnemy.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oEnemy))
                                                                                            end
                                                                                            bClearAirAATargets = true
                                                                                            bReturnToRallyPoint = true
                                                                                            break
                                                                                        end
                                                                                    end
                                                                                end
                                                                                if not(bClearAirAATargets) and M27Utilities.IsTableEmpty(tAllRecentlySeenCruisers) == false then
                                                                                    for iCruiser, oCruiser in tAllRecentlySeenCruisers do
                                                                                        if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oCruiser:GetPosition()) <= iRecentlySeenCruiserSearchRange then
                                                                                            bClearAirAATargets = true
                                                                                            bReturnToRallyPoint = true
                                                                                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy cruiser recently detected nearby='..oCruiser.UnitId..M27UnitInfo.GetUnitLifetimeCount(oCruiser)..'; Dist away='..M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oCruiser:GetPosition())) end
                                                                                            break
                                                                                        end
                                                                                    end
                                                                                end
                                                                                if bDebugMessages == true then LOG(sFunctionRef..': Finished checking for nearby AA. bClearAirAATargets='..tostring(bClearAirAATargets)..'; bReturnToRallyPoint='..tostring(bReturnToRallyPoint)) end
                                                                            end
                                                                        else
                                                                            if bDebugMessages == true then
                                                                                LOG(sFunctionRef .. ': Air unit is on enemy side of map but near our ACU so will still intercept it')
                                                                            end
                                                                        end
                                                                    else
                                                                        if bDebugMessages == true then
                                                                            LOG(sFunctionRef .. ': navigator target destination is closer to our start than the enemy start')
                                                                        end
                                                                    end
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                                if bClearAirAATargets == true then
                                                    if bDebugMessages == true then
                                                        if oUnit[refoAirAATarget].GetUnitId then
                                                            LOG(sFunctionRef .. ': Clearing airAA targets; Target about to be cleared=' .. oUnit[refoAirAATarget].UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit[refoAirAATarget]))
                                                        else
                                                            LOG(sFunctionRef .. ': Clearing airAA targets, dont appear to have a valid target')
                                                        end
                                                    end
                                                    ClearAirUnitAssignmentTrackers(aiBrain, oUnit, true)
                                                    bUnitIsUnassigned = true
                                                    if bReturnToRallyPoint == true then
                                                        --if oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end
                                                        M27Utilities.IssueTrackedClearCommands({ oUnit })

                                                        local tAirRally = GetAirRallyPoint(aiBrain)
                                                        oUnit[M27PlatoonUtilities.refiLastOrderType] = M27PlatoonUtilities.refiOrderIssueMove
                                                        oUnit[M27UnitInfo.reftLastOrderTarget] = {tAirRally[1], tAirRally[2], tAirRally[3]}
                                                        IssueMove({ oUnit }, tAirRally)
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': Cleared commants for unit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
                                                        end
                                                    end
                                                    --oUnit[refbOnAssignment] = false
                                                end
                                            elseif iUnitType == iTypeTorpBomber then
                                                --Do nothing
                                            elseif iUnitType == iTypeTransport then
                                                --Do nothing - idle transport logic is handled by M27Transport manager
                                            else
                                                M27Utilities.ErrorHandler('Unrecognised unit type. iUnitType=' .. iUnitType) --Redundancy
                                            end
                                        elseif bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Unit has special micro active so wont do normal checks')
                                        end
                                    end
                                else
                                    if oUnit[M27UnitInfo.refbSpecialMicroActive] then
                                        bUnitIsUnassigned = false

                                        --Transport backup logic for if transport been idle for a minute
                                        if EntityCategoryContains(M27UnitInfo.refCategoryTransport, oUnit.UnitId) then
                                            if M27Logic.GetUnitState(oUnit) == '' then
                                                if M27Utilities.IsTableEmpty(oUnit[M27Transport.reftLocationWhenFirstInactive]) or M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oUnit[M27Transport.reftLocationWhenFirstInactive]) <= 1 then
                                                    --Havent moved since last location when idle
                                                    oUnit[M27Transport.refiTimeSinceFirstInactive] = math.min((oUnit[M27Transport.refiTimeSinceFirstInactive] or GetGameTimeSeconds()), GetGameTimeSeconds())
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Updating time that transport has been inactive if we havent recorded a value yet, oUnit[M27Transport.refiTimeSinceFirstInactive]='..(oUnit[M27Transport.refiTimeSinceFirstInactive] or 'nil')) end
                                                end
                                                if GetGameTimeSeconds() - oUnit[M27Transport.refiTimeSinceFirstInactive] >= 60 then
                                                    M27Utilities.ErrorHandler('Transport has been idle for more than 1m with an active micro flag, will reset the flag')
                                                    oUnit[M27UnitInfo.refbSpecialMicroActive] = false
                                                    M27Transport.ClearTransportTrackers(aiBrain, oUnit)
                                                end
                                            else
                                                oUnit[M27Transport.refiTimeSinceFirstInactive] = nil
                                                oUnit[M27Transport.reftLocationWhenFirstInactive] = nil
                                            end
                                        end

                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Special micro is active for the unit so wont treat it as idle. Unit state='..M27Logic.GetUnitState(oUnit)..'; Is unit state empty='..tostring(M27Logic.GetUnitState(oUnit)==''))
                                        end
                                    else
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Unit doesnt have an assignment')
                                        end
                                        if not (oUnit[refbSentRefuelCommand]) then
                                            bUnitIsUnassigned = true
                                            --T1 bomber override for the first couple of T1 bombers
                                            if iUnitType == iTypeBomber and M27UnitInfo.GetUnitLifetimeCount(oUnit) <= aiBrain[refiEngiHuntersToGet] and iCurTechLevel == 1 then
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Dealing with early T1 bomber so want it to hunt for engineers rather tahn being available for normal target logic')
                                                end
                                                bUnitIsUnassigned = false
                                                if not (oUnit[refbEngiHunterMode]) then
                                                    oUnit[refbEngiHunterMode] = true
                                                    aiBrain[reftEngiHunterBombers][oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit)] = oUnit
                                                end
                                                UpdateBomberTargets(oUnit)
                                            end
                                        else
                                            --Error check in case unit somehow gained full health and fuel
                                            if iFuelPercent >= 0.99 then
                                                if M27UnitInfo.GetUnitHealthPercent(oUnit) >= 0.99 then
                                                    if bDebugMessages == true then
                                                        LOG('Warning - Unit has its status as refueling, but its health and fuel percent are >=99%.  Will remove its status as refueling')
                                                    end
                                                    oUnit[refbSentRefuelCommand] = false
                                                end
                                            end
                                        end
                                    end
                                end
                                if bUnitIsUnassigned == true then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Unit is unassigned, will treat as available unless it is a low health bomber or t3 air or any tech gunship and we have air staging. iAirStaging=' .. iAirStaging .. '; M27UnitInfo.GetUnitHealthPercent(oUnit)=' .. M27UnitInfo.GetUnitHealthPercent(oUnit) .. '; Tech level=' .. M27UnitInfo.GetUnitTechLevel(oUnit) .. '; iUnitType=' .. iUnitType .. '; ')
                                    end

                                    --Torp bomber when in attackACU mode - attack ACU if its underwater
                                    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and iUnitType == iTypeTorpBomber and M27UnitInfo.IsUnitUnderwater(aiBrain[M27Overseer.refoACUKillTarget]) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': In ACU kill mode so will get the torp bomber to target enemy ACU which is underwater') end
                                        ManualTellTorpedoBomberToAttackTarget(aiBrain, oUnit, aiBrain[M27Overseer.refoACUKillTarget])
                                    else

                                        --Send low health bombers and T3 air to heal up provided no T2+ airAA units nearby
                                        if iCurTechLevel < 4 and iAirStaging > 0 and ((iUnitType == iTypeGunship and M27UnitInfo.GetUnitHealthPercent(oUnit) <= iGunshipLowHealthPercent) or M27UnitInfo.GetUnitHealthPercent(oUnit) <= iLowHealthPercent) and (iUnitType == iTypeBomber or iUnitType == iTypeTorpBomber or iUnitType == iTypeGunship or iCurTechLevel == 3) and
                                                (iUnitType == iTypeGunship or ((M27UnitInfo.GetUnitTechLevel(oUnit) == 3 and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirAA - categories.TECH1, oUnit:GetPosition(), 100, 'Enemy'))) or (M27UnitInfo.GetUnitTechLevel(oUnit) <= 2 and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirAA, oUnit:GetPosition(), 100, 'Enemy'))))) and
                                                (oUnit[refiBombsDropped] >= 2 or not (iUnitType == iTypeBomber or iUnitType == iTypeTorpBomber)) then
                                            iCurUnitsWithLowFuel = iCurUnitsWithLowFuel + 1
                                            aiBrain[reftLowFuelAir][iCurUnitsWithLowFuel] = oUnit
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' has low health or fuel so wont make it available; instead will add to list of units with low fuel; iCurUnitsWithLowFuel=' .. iCurUnitsWithLowFuel)
                                            end
                                        else
                                            iCurUnitsWithFuel = iCurUnitsWithFuel + 1
                                            aiBrain[sAvailableUnitRef][iCurUnitsWithFuel] = oUnit
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': have an air unit with enough fuel and either good health or nearby enemy air units, iCurUnitsWithFuel=' .. iCurUnitsWithFuel)
                                            end
                                        end
                                    end
                                end
                            else
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' has low fuel')
                                end
                                iCurUnitsWithLowFuel = iCurUnitsWithLowFuel + 1
                                aiBrain[reftLowFuelAir][iCurUnitsWithLowFuel] = oUnit
                            end
                        else
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Unit is trying to refuel so wont mark it as available or as a unit with low fuel unless it has high fuel and health')
                            end
                            if (M27UnitInfo.GetUnitHealthPercent(oUnit) >= 0.98 and oUnit:GetFuelRatio() >= 0.98) or EntityCategoryContains(categories.CANNOTUSEAIRSTAGING, oUnit.UnitId) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Unit has high health and fuel so clearing order so it is seen as being available next cycle')
                                end
                                oUnit[refbSentRefuelCommand] = false
                            else
                                --Is the unit sat on the ground for a while near air staging or has no unit state? If so then clear its flag as likely it got overridden
                                --Air staging size z varies between 2.75 to 3
                                if bDebugMessages == true then LOG(sFunctionRef..': Checking if unit refuel command may have been overridden. Unit position='..repru(oUnit:GetPosition())..'; Surface height='..GetSurfaceHeight(oUnit:GetPosition()[1], oUnit:GetPosition()[3])) end
                                local bReaddToLowFuel = false
                                if not(M27UnitInfo.IsUnitValid(oUnit[refoAirStagingAssigned])) then
                                    bReaddToLowFuel = true
                                else
                                    if oUnit:GetPosition()[2] - GetSurfaceHeight(oUnit:GetPosition()[1], oUnit:GetPosition()[3]) <= 7 or oUnit:IsUnitState('MovingDown') then
                                        oUnit[refiCyclesOnGroundWaitingToRefuel] = (oUnit[refiCyclesOnGroundWaitingToRefuel] or 0) + 1
                                        if bDebugMessages == true then LOG(sFunctionRef..': Unit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Unit state='..M27Logic.GetUnitState(oUnit)..'; Distance above surface height='..oUnit:GetPosition()[2] - GetSurfaceHeight(oUnit:GetPosition()[1], oUnit:GetPosition()[3])..'; Cycles in this position='..oUnit[refiCyclesOnGroundWaitingToRefuel]) end
                                        if oUnit[refiCyclesOnGroundWaitingToRefuel] >= 20 or (oUnit[refiCyclesOnGroundWaitingToRefuel] >= 5 and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(),oUnit[refoAirStagingAssigned]:GetPosition()) >= 75) then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Will readd unit to those wanting a new refuel command') end
                                            bReaddToLowFuel = true
                                            oUnit[refiCyclesOnGroundWaitingToRefuel] = 0
                                        end
                                    end
                                end
                                if bReaddToLowFuel then
                                    --Clear flag but also send unit back for refueling
                                    ClearAirUnitAssignmentTrackers(aiBrain, oUnit, true)
                                    iCurUnitsWithLowFuel = iCurUnitsWithLowFuel + 1
                                    aiBrain[reftLowFuelAir][iCurUnitsWithLowFuel] = oUnit
                                end
                            end
                        end
                    else
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Unit is dead or not constructed')
                        end
                    end
                end
                if sAvailableUnitRef == reftAvailableBombers then
                    aiBrain[refiPreviousAvailableBombers] = table.getn(aiBrain[sAvailableUnitRef])
                end

                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Finished getting all units with type ref=' .. sAvailableUnitRef .. '; size of available unit ref table=' .. table.getn(aiBrain[sAvailableUnitRef]) .. '; will list out all available units')
                    if table.getn(aiBrain[sAvailableUnitRef]) > 0 then
                        for iUnit, oUnit in aiBrain[sAvailableUnitRef] do
                            LOG(sFunctionRef .. ': UnitTYpe=' .. iUnitType .. '; bomber=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
                        end
                    end
                    LOG('IsAvailableTorpBombersEmpty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftAvailableTorpBombers])))
                end
            end
        end

        --If have flagged that have full fuel air units attached to something, then do a check of all non-structure units with air staging platforms
        if bCheckForMobileAirStaging then
            local tMobileAirStaging = aiBrain:GetListOfUnits(categories.AIRSTAGINGPLATFORM - categories.STRUCTURE, false, true)
            if M27Utilities.IsTableEmpty(tMobileAirStaging) == false then
                for iUnit, oUnit in tMobileAirStaging do
                    if oUnit:GetFractionComplete() == 1 then
                        ReleaseRefueledUnitsFromAirStaging(aiBrain, oUnit)
                    end
                end
            end
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function OrderUnitsToRefuel(aiBrain, tUnitsToRefuel)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OrderUnitsToRefuel'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Sends low fuel units to air staging
    if M27Utilities.IsTableEmpty(tUnitsToRefuel) == false then
        --Only consider actual air staging buildings for these purposes, or else risk interfering with other logic
        local tAirStaging = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryAirStaging, false, true)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': GameTime=' .. GetGameTimeSeconds() .. '; Want units to refuel, number of airstaging we have=' .. table.getn(tAirStaging))
        end
        if M27Utilities.IsTableEmpty(tAirStaging) == true then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': tAirStaging is nil, but we have units that want to refuel')
            end
            aiBrain[refiAirStagingWanted] = math.max(1, math.ceil(table.getn(tUnitsToRefuel) / 8))
        else
            local iFullyAvailableStaging = 0
            aiBrain[refiAirStagingWanted] = table.getn(tAirStaging)
            aiBrain[refiAirStagingWanted] = aiBrain[refiAirStagingWanted] + math.max(0, math.floor(table.getn(tUnitsToRefuel) / 3 - aiBrain[refiAirStagingWanted]))

            --Check if all our air staging are being used, in which case increase the number wanted by 1

            for iAirStaging, oAirStaging in tAirStaging do
                if M27Utilities.IsTableEmpty(oAirStaging[reftAssignedRefuelingUnits]) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': We have an air staging unit ' .. oAirStaging.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAirStaging) .. ' that hasnt had any units sent to it to refuel that we know of')
                    end
                    iFullyAvailableStaging = iFullyAvailableStaging + 1
                end
            end
            if iFullyAvailableStaging == 0 then
                aiBrain[refiAirStagingWanted] = aiBrain[refiAirStagingWanted] + 1
            end


            --Find nearest available air staging unit
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': We have air staging so getting unit to refuel')
            end
            local bAlreadyTryingToRefuel = false
            local oNavigator, tCurTarget, tNearbyAirStaging
            local iAssignedUnits
            local iCapacity
            local bUpdateRefuelingUnits
            local iLoopCount = 0
            local iRemainingUnitsToRefuel = 0
            for iUnit, oUnit in tUnitsToRefuel do
                --T3 bombers look like they take up 4 slots instead of 1
                if EntityCategoryContains(M27UnitInfo.refCategoryBomber * categories.TECH3, oUnit.UnitId) then
                    iRemainingUnitsToRefuel = iRemainingUnitsToRefuel + 4
                else
                    iRemainingUnitsToRefuel = iRemainingUnitsToRefuel + 1
                end
            end
            for iStaging, oStaging in tAirStaging do
                if M27UnitInfo.IsUnitValid(oStaging) then
                    --Do we have a fully available air staging and <=4 units t o refuel? If so then just send the units to this air staging
                    if M27Utilities.IsTableEmpty(oStaging[reftAssignedRefuelingUnits]) or not (iFullyAvailableStaging > 0 and iFullyAvailableStaging * 4 <= table.getn(tUnitsToRefuel)) then


                        --Estimate capacity (cant see in blueprint)
                        if EntityCategoryContains(categories.STRUCTURE, oStaging) then
                            iCapacity = 4
                        elseif EntityCategoryContains(categories.EXPERIMENTAL * categories.CARRIER, oStaging) then
                            iCapacity = 40
                        else
                            iCapacity = 1
                        end

                        iAssignedUnits = 0
                        if M27Utilities.IsTableEmpty(oStaging[reftAssignedRefuelingUnits]) == false then
                            for iRefuelingUnit, oRefuelingUnit in oStaging[reftAssignedRefuelingUnits] do
                                if M27UnitInfo.IsUnitValid(oRefuelingUnit) == false or oRefuelingUnit[refbSentRefuelCommand] == false then
                                    oStaging[reftAssignedRefuelingUnits][iRefuelingUnit] = nil
                                else
                                    --Is the unit already refueled and isnt flagged as being in air staging?
                                    if oRefuelingUnit:GetFuelRatio() >= 0.95 and M27UnitInfo.GetUnitHealthPercent(oRefuelingUnit) >= 0.98 and not (oRefuelingUnit:IsUnitState('Attached')) then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': oRefuelingUnit=' .. oRefuelingUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oRefuelingUnit) .. '; appears to have refueld and isnt attached, unit state=' .. M27Logic.GetUnitState(oRefuelingUnit) .. ' so will clear refueling trakcers')
                                        end
                                        oRefuelingUnit[refbSentRefuelCommand] = false
                                        oStaging[reftAssignedRefuelingUnits][iRefuelingUnit] = nil
                                        oRefuelingUnit[refoAirStagingAssigned] = nil
                                        oRefuelingUnit[refiGunshipPlacement] = nil --Redundancy for gunship logic
                                    else
                                        if EntityCategoryContains(M27UnitInfo.refCategoryBomber * categories.TECH3, oRefuelingUnit.UnitId) then
                                            iAssignedUnits = iAssignedUnits + 4
                                        else
                                            iAssignedUnits = iAssignedUnits + 1
                                        end

                                    end
                                end
                            end
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Air staging unit ' .. oStaging.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oStaging) .. ': iCapacity=' .. iCapacity .. '; iAssignedUnits=' .. iAssignedUnits)
                        end

                        if iAssignedUnits < iCapacity then
                            for iUnit, oUnit in tUnitsToRefuel do
                                bAlreadyTryingToRefuel = false
                                if M27UnitInfo.IsUnitValid(oUnit) then
                                    --Does the air staging have enough capacity for this unit?
                                    if M27Utilities.IsTableEmpty(oStaging[reftAssignedRefuelingUnits]) or iCapacity >= 4 or not (EntityCategoryContains(M27UnitInfo.refCategoryBomber * categories.TECH3, oUnit.UnitId)) then

                                        --Does the unit already have a target of the air staging and isnt flagged as having been sent a refuel command?
                                        if not (oUnit[refbSentRefuelCommand]) and oUnit.GetNavigator then
                                            oNavigator = oUnit:GetNavigator()
                                            if oNavigator.GetCurrentTargetPos then
                                                tCurTarget = oNavigator:GetCurrentTargetPos()
                                                tNearbyAirStaging = M27Utilities.GetOwnedUnitsAroundPoint(aiBrain, M27UnitInfo.refCategoryAirStaging, tCurTarget, 1)
                                                if M27Utilities.IsTableEmpty(tNearbyAirStaging) == false then
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ' tCurTarget=' .. repru(tCurTarget))
                                                        M27Utilities.DrawLocation(tCurTarget)
                                                    end
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Units target is the same as an air staging platform so think it is already trying to refuel')
                                                    end
                                                    bAlreadyTryingToRefuel = true
                                                end
                                            end
                                        end
                                        if not (bAlreadyTryingToRefuel) and not (oUnit:IsUnitState('Attached')) then
                                            --if oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end
                                            ClearAirUnitAssignmentTrackers(aiBrain, oUnit, true)
                                            M27Utilities.IssueTrackedClearCommands({ oUnit })
                                            oUnit[M27PlatoonUtilities.refiLastOrderType] = M27PlatoonUtilities.refiOrderTransportLoad
                                            oUnit[M27UnitInfo.reftLastOrderTarget] = oStaging:GetPosition()
                                            IssueTransportLoad({ oUnit }, oStaging)
                                            oUnit[refbSentRefuelCommand] = true
                                            oUnit[refoAirStagingAssigned] = oStaging
                                            if M27Utilities.IsTableEmpty(oStaging[reftAssignedRefuelingUnits]) then
                                                oStaging[reftAssignedRefuelingUnits] = {}
                                            end
                                            oStaging[reftAssignedRefuelingUnits][oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit)] = oUnit
                                            if EntityCategoryContains(M27UnitInfo.refCategoryBomber * categories.TECH3, oUnit.UnitId) then
                                                iAssignedUnits = iAssignedUnits + 4
                                            else
                                                iAssignedUnits = iAssignedUnits + 1
                                            end
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Sent command for oUnit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' to refuel, iAssignedUnits=' .. iAssignedUnits)
                                            end
                                            if iAssignedUnits >= iCapacity then
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                            --Update units to refuel
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': About to update tUnitsToRefuel to remove units that have now been sent for refueling')
                            end
                            bUpdateRefuelingUnits = true
                            while bUpdateRefuelingUnits do
                                iLoopCount = iLoopCount + 1
                                if iLoopCount >= 100 then
                                    M27Utilities.ErrorHandler('Infinite loop')
                                    break
                                end
                                bUpdateRefuelingUnits = false
                                for iUnit, oUnit in tUnitsToRefuel do
                                    if M27UnitInfo.IsUnitValid(oUnit) == false or oUnit[refbSentRefuelCommand] then
                                        bUpdateRefuelingUnits = true
                                        table.remove(tUnitsToRefuel, iUnit)
                                        break
                                    end
                                end
                            end
                            if M27Utilities.IsTableEmpty(tUnitsToRefuel) then
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code; Is tUnitsToRefuel empty=' .. tostring(M27Utilities.IsTableEmpty(tUnitsToRefuel)))
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RefuelIdleAirUnits(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RefuelIdleAirUnits'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Checks for any idle air units on our side of the map that could do with a slight refuel
    --local iSearchRange = 50
    local tOurStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    --local tAirUnitsNearStart = M27Utilities.GetOwnedUnitsAroundPoint(aiBrain, M27UnitInfo.refCategoryAllNonExpAir, tOurStartPosition, iSearchRange)
    local tAllAirUnits = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryAllNonExpAir, false, true)
    local iHealthThreshold = 0.8
    local iFuelThreshold = 0.7
    local iGunshipFuelThreshold = 0.25
    local tUnitsToRefuel = {}
    local iUnitsToRefuel = 0
    local bRefuelUnit
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code, checking if have any air units near start')
    end
    if M27Utilities.IsTableEmpty(tAllAirUnits) == false then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': have ' .. table.getn(tAllAirUnits) .. ' air units to consider')
        end
        for _, oUnit in tAllAirUnits do
            bRefuelUnit = false
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Unit ID=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; unit fraction complete=' .. oUnit:GetFractionComplete() .. '; oUnit[refbOnAssignment]=' .. tostring((oUnit[refbOnAssignment] or false)))
            end
            if M27UnitInfo.IsUnitValid(oUnit) and not (oUnit[refbOnAssignment]) and not (oUnit[refbSentRefuelCommand]) and M27Utilities.IsTableEmpty(oUnit[reftTargetList]) == true and M27Utilities.IsTableEmpty(oUnit[refiCurMovementPath]) == true and oUnit.GetFuelRatio and not (oUnit:IsUnitState('Attached')) and not (EntityCategoryContains(categories.CANNOTUSEAIRSTAGING, oUnit.UnitId)) then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Unit is available, will check its fuel and health; Fuel=' .. oUnit:GetFuelRatio() .. '; Health=' .. M27UnitInfo.GetUnitHealthPercent(oUnit))
                end
                if oUnit:GetFuelRatio() <= iFuelThreshold then
                    bRefuelUnit = true
                elseif M27UnitInfo.GetUnitHealthPercent(oUnit) <= iHealthThreshold then
                    bRefuelUnit = true
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Finished checking unit fuel ratio and health, bRefuelUnit=' .. tostring(bRefuelUnit))
                end

                if bRefuelUnit == true then
                    --Are we on our side of the map?
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Have a unit to refuel=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ', checking if its on our side of the map; distance to our start=' .. M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) .. '; Distance to enemy base=' .. M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)))
                    end
                    if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) < M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) then
                        --Gunship specific - have a higher fuel threshold and health threshold since idle gunships appear the same as non-idle
                        if EntityCategoryContains(M27UnitInfo.refCategoryGunship, oUnit.UnitId) and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) >= 70 and oUnit:GetFuelRatio() >= iGunshipFuelThreshold and M27UnitInfo.GetUnitHealthPercent(oUnit) >= iGunshipLowHealthPercent then
                            bRefuelUnit = false
                            if bDebugMessages == true then LOG(sFunctionRef..': Gunship has enough health and fuel and isnt close to bsae so wont refuel') end
                        end
                        if bRefuelUnit then
                            iUnitsToRefuel = iUnitsToRefuel + 1
                            tUnitsToRefuel[iUnitsToRefuel] = oUnit
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Adding unit to list of units to be refueled')
                            end
                        end
                    end
                end
            else
                if bDebugMessages == true then
                    local iUnitLifetimeCount = M27UnitInfo.GetUnitLifetimeCount(oUnit)
                    LOG(sFunctionRef .. ': Unit with ID and lifetime count=' .. oUnit.UnitId .. iUnitLifetimeCount .. ' is either on assignment or has a target in target list or has a movement path')
                end
            end
        end
    end
    if iUnitsToRefuel > 0 then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': iUnitsToRefuel=' .. iUnitsToRefuel .. '; calling function to order them to refuel')
        end
        ForkThread(OrderUnitsToRefuel, aiBrain, tUnitsToRefuel)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UnloadUnit(oTransport)
    --Unfortunately couldnt get this to work by issuing transportunload command to the unit docked in the transport, so having to have transport release all its units
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UnloadUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if M27UnitInfo.IsUnitValid(oTransport) then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Issuing unload command to transport/air staging unit')
        end
        local tTransportPosition = oTransport:GetPosition()
        local tRefuelingUnits = oTransport:GetCargo()
        for iUnit, oUnit in tRefuelingUnits do
            ClearAirUnitAssignmentTrackers(oUnit:GetAIBrain(), oUnit, true)
            --oUnit[refbOnAssignment] = false
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Issuing clear commands')
        end
        M27Utilities.IssueTrackedClearCommands({ oTransport })
        IssueTransportUnload({ oTransport }, { tTransportPosition[1] + 5, tTransportPosition[2], tTransportPosition[3] + 5 })
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ReleaseRefueledUnitsFromAirStaging(aiBrain, oAirStaging)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReleaseRefueledUnitsFromAirStaging'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if M27UnitInfo.IsUnitValid(oAirStaging) and oAirStaging.GetCargo then
        local tRefuelingUnits = oAirStaging:GetCargo()
        local bReadyToLeave = false
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Checking if air staging has any refueling units')
        end
        if M27Utilities.IsTableEmpty(tRefuelingUnits) == false then
            for iRefuelingUnit, oRefuelingUnit in tRefuelingUnits do
                if not (oRefuelingUnit.Dead) and not(EntityCategoryContains(categories.UNSELECTABLE + categories.STRUCTURE, oRefuelingUnit.UnitId)) then --Need structure in here to avoid error with blackops which has structure units included as part of the cargo
                    oRefuelingUnit[refbSentRefuelCommand] = false
                    bReadyToLeave = true
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Have a unit refueling, checking its health and fuel. Unit='..oRefuelingUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oRefuelingUnit))
                        LOG(sFunctionRef..': Unit fuel ratio='..oRefuelingUnit:GetFuelRatio())
                    end
                    if oRefuelingUnit:GetFuelRatio() < 0.99 or M27UnitInfo.GetUnitHealthPercent(oRefuelingUnit) < 0.99 then
                        bReadyToLeave = false
                    end
                    if bReadyToLeave then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Telling unit to leave air staging')
                        end
                        ForkThread(UnloadUnit, oAirStaging)
                        M27Utilities.DelayChangeVariable(oRefuelingUnit, refbSentRefuelCommand, false, 5)
                        break
                    end
                end
            end
        else
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': .Refueling is nil so not proceeding')
            end
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ReleaseRefueledUnits(aiBrain)
    --Only want to call this periodically as doesnt seem an easy way of telling it to only release some of the units, instead it releases all
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReleaseRefueledUnits'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tAirStaging = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryAirStaging, false, true)
    if M27Utilities.IsTableEmpty(tAirStaging) == false then
        for iStaging, oStaging in tAirStaging do
            if not (oStaging.Dead) then
                ReleaseRefueledUnitsFromAirStaging(aiBrain, oStaging)
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdateScoutingSegmentRequirements(aiBrain)
    --Updates trackers for when we last had visual of an area, and updates table containing list of targets that we want to scout
    --returns the number of scouts we want
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateScoutingSegmentRequirements'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iCurIntervalWanted, iLastScoutedTime, tCurPosition
    local iCurTime = GetGameTimeSeconds()
    local iIntervalInSecondsBeforeRefresh = 3 --If last had visual < this time ago then wont refresh
    local iScoutTargetCount = 0
    local iScoutLongDelayCount = 0
    local iCurTimeSinceWantedToScout
    local iDeadScoutThreshold = 3 --If >= this number of scouts have died then dont proceed
    aiBrain[reftScoutingTargetShortlist] = {}

    --reftScoutingTargetShortlist = 'M27ScoutingTargetShortlist' --[y] is the count (e.g. location 1, 2, 3), and then this gives {a,b,c} where a, b, c are subrefs, i.e. refiTimeSinceWantedToScout
    local iCurActiveScoutsAssigned
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code, Nearest enemy start point=' .. repru(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) .. '; aiBrain[refiMinSegmentX]=' .. aiBrain[refiMinSegmentX] .. '; aiBrain[refiMaxSegmentX]=' .. aiBrain[refiMaxSegmentX] .. '; aiBrain[refiMinSegmentX]=' .. aiBrain[refiMinSegmentX] .. '; aiBrain[refiMaxSegmentZ]=' .. aiBrain[refiMaxSegmentZ])
    end
    local iScoutMinSegmentX = aiBrain[refiMinSegmentX]
    local iScoutMaxSegmentX = aiBrain[refiMaxSegmentX]
    local iScoutMinSegmentZ = aiBrain[refiMinSegmentZ]
    local iScoutMaxSegmentZ = aiBrain[refiMaxSegmentZ]
    if M27MapInfo.bNoRushActive then
        local iBaseSegmentX, iBaseSegmentZ = GetAirSegmentFromPosition(aiBrain[M27MapInfo.reftNoRushCentre])
        local iSegmentSizeAdjust = math.ceil(M27MapInfo.iNoRushRange / iAirSegmentSize)
        iScoutMinSegmentX = iBaseSegmentX - iSegmentSizeAdjust
        iScoutMaxSegmentX = iBaseSegmentX + iSegmentSizeAdjust
        iScoutMinSegmentZ = iBaseSegmentZ - iSegmentSizeAdjust
        iScoutMaxSegmentZ = iBaseSegmentZ + iSegmentSizeAdjust
    else

        --Change scouting interval for enemy base once we have access to T3 air and decent mass income
        if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 3 and aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] >= 12 then
            aiBrain[refiIntervalEnemyBase] = math.max(40, 80 - (aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] - 10) * 4)
            aiBrain[refiIntervalHighestPriority] = math.max(15, 30 - (aiBrain[M27EconomyOverseer.refiGrossMassBaseIncome] - 10) * 2)
        end

        --Update enemy base to lower of its current value and the value for an enemy base (as the primary enemy base location may be different to the start position)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Primary enemy base location=' .. repru((M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain) or { 'nil' })) .. '; Air segment=' .. (GetAirSegmentFromPosition(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) or 'nil'))
        end
        local iEnemyBaseX, iEnemyBaseZ = GetAirSegmentFromPosition(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
        aiBrain[reftAirSegmentTracker][iEnemyBaseX][iEnemyBaseZ][refiNormalScoutingIntervalWanted] = math.min(aiBrain[reftAirSegmentTracker][iEnemyBaseX][iEnemyBaseZ][refiNormalScoutingIntervalWanted], aiBrain[refiIntervalEnemyBase])
    end

    for iCurAirSegmentX = iScoutMinSegmentX, iScoutMaxSegmentX, 1 do
        for iCurAirSegmentZ = iScoutMinSegmentZ, iScoutMaxSegmentZ, 1 do
            --iLastScoutedTime = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastScouted]
            if bDebugMessages == true then
                if iCurAirSegmentX <= 4 and iCurAirSegmentZ then
                    LOG(sFunctionRef .. ': iCurAirSegmentXZ=' .. iCurAirSegmentX .. '-' .. iCurAirSegmentZ .. '; Time since last scouted=' .. GetTimeSinceLastScoutedSegment(aiBrain, iCurAirSegmentX, iCurAirSegmentZ) .. ';[refiCurrentScoutingInterval]=' .. aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval] .. '; iCurTime=' .. iCurTime .. '; iIntervalInSecondsBeforeRefresh=' .. iIntervalInSecondsBeforeRefresh)
                end
            end
            if GetTimeSinceLastScoutedSegment(aiBrain, iCurAirSegmentX, iCurAirSegmentZ) >= iIntervalInSecondsBeforeRefresh then
                --tCurPosition = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][reftMidpointPosition]
                --[[if CanSeePosition(aiBrain, tCurPosition, iMaxSearchRange) then
            aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastScouted] = iCurTime
            aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiDeadScoutsSinceLastReveal] = 0
            aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval] = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiNormalScoutingIntervalWanted]
        else--]]
                iCurIntervalWanted = (aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval] or aiBrain[refiIntervalLowestPriority])
                iCurTimeSinceWantedToScout = (GetTimeSinceLastScoutedSegment(aiBrain, iCurAirSegmentX, iCurAirSegmentZ) or 0) - iCurIntervalWanted
                if iCurTimeSinceWantedToScout > 0 then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Found a location that we havent scouted for a while, X-Z=' .. iCurAirSegmentX .. '-' .. iCurAirSegmentZ .. '; Dead scouts=' .. aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiDeadScoutsSinceLastReveal] .. '; assigned scouts=' .. aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned])
                    end
                    --Check we dont already have assigned scouts and/or too many dead scouts
                    if aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiDeadScoutsSinceLastReveal] < iDeadScoutThreshold then
                        --Get all allies that have assigned an air scout here
                        iCurActiveScoutsAssigned = 0
                        for iBrain, oBrain in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] do
                            for iAdjX = -1, 1, 1 do
                                for iAdjZ = -1, 1, 1 do
                                    iCurActiveScoutsAssigned = oBrain[reftAirSegmentTracker][iCurAirSegmentX + iAdjX][iCurAirSegmentZ + iAdjZ][refiAirScoutsAssigned]
                                    if iCurActiveScoutsAssigned > 0 then
                                        break
                                    end
                                end
                                if iCurActiveScoutsAssigned > 0 then
                                    break
                                end
                            end
                            if iCurActiveScoutsAssigned > 0 then
                                break
                            end
                        end
                        if iCurActiveScoutsAssigned == 0 then
                            iScoutTargetCount = iScoutTargetCount + 1

                            aiBrain[reftScoutingTargetShortlist][iScoutTargetCount] = {}
                            aiBrain[reftScoutingTargetShortlist][iScoutTargetCount][refiTimeSinceWantedToScout] = iCurTimeSinceWantedToScout
                            aiBrain[reftScoutingTargetShortlist][iScoutTargetCount][refiSegmentX] = iCurAirSegmentX
                            aiBrain[reftScoutingTargetShortlist][iScoutTargetCount][refiSegmentZ] = iCurAirSegmentZ
                            if iCurTimeSinceWantedToScout > iLongScoutDelayThreshold then
                                iScoutLongDelayCount = iScoutLongDelayCount + 1
                            end
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Adding location to shortlist, iScoutTargetCount=' .. iScoutTargetCount)
                            end
                        else
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Already assigned ' .. (iCurActiveScoutsAssigned or 'nil') .. ' scouts to this location')
                            end
                        end
                    elseif bDebugMessages == true then
                        LOG(sFunctionRef .. ': Too many scouts have died, iDeadScoutThreshold=' .. iDeadScoutThreshold .. '; Number of scouts who ahve died=' .. aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiDeadScoutsSinceLastReveal] .. '; iCurAirSegmentX-Z=' .. iCurAirSegmentX .. '-' .. iCurAirSegmentZ)
                    end
                    if bDebugMessages == true then
                        if aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiDeadScoutsSinceLastReveal] > 0 then
                            M27Utilities.DrawLocation(GetAirPositionFromSegment(iCurAirSegmentX, iCurAirSegmentZ), nil, 3)
                        end
                    end
                end
                --end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Finished going through every segment on the map')
        local iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
        LOG(sFunctionRef .. ':Values for enemy base: iCurAirSegmentX=' .. iCurAirSegmentX .. '; iCurAirSegmentZ=' .. iCurAirSegmentZ .. '; iCurIntervalWanted=' .. aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval] .. '; iLastScoutedTime=' .. aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastScouted] .. '; iLongScoutDelayThreshold=' .. iLongScoutDelayThreshold .. '; aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiDeadScoutsSinceLastReveal]=' .. aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiDeadScoutsSinceLastReveal])
    end

    --Determine how many scouts we want
    local iScoutsWantedActual = math.ceil(iScoutLongDelayCount / 3)
    if iScoutsWantedActual < iMinScoutsForMap then
        iScoutsWantedActual = iMinScoutsForMap
    elseif iScoutsWantedActual > iMaxScoutsForMap then
        iScoutsWantedActual = iMaxScoutsForMap
    end

    local iAvailableScouts = 0
    if M27Utilities.IsTableEmpty(aiBrain[reftAvailableScouts]) == false then
        iAvailableScouts = table.getn(aiBrain[reftAvailableScouts])
    end

    if M27MapInfo.bNoRushActive then
        iScoutsWantedActual = math.min(iScoutsWantedActual, 3)
    end

    aiBrain[refiExtraAirScoutsWanted] = iScoutsWantedActual - iAvailableScouts

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code, aiBrain[refiExtraAirScoutsWanted]=' .. aiBrain[refiExtraAirScoutsWanted])
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetEndDestinationForScout(aiBrain, oScout)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetEndDestinationForScout'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tEndDestination
    local iSegmentDistance
    local iCurOverdueTime
    local iGreatestOverdueTime = 0
    local iClosestDistance, iCurDistance
    local iFinalX, iFinalZ, iFinalCount
    iClosestDistance = 10000

    local iStartSegmentX, iStartSegmentZ = GetAirSegmentFromPosition(oScout:GetPosition())

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code, Shortlist size=' .. table.getn(aiBrain[reftScoutingTargetShortlist]) .. '; reftScoutingTargetShortlist=' .. repru(aiBrain[reftScoutingTargetShortlist]) .. '; Enemy start position=' .. repru(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)))
    end

    local iEnemyBaseSegmentX, iEnemyBaseSegmentZ = GetAirSegmentFromPosition(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
    local bHaveLocationsReallyOverdue = false
    --If any location is more than 2.5m overdue then will filter to only consider locations overdue by this; if enemy base is overdue by 2m, then will prioritise scouting the base
    local iReallyOverduePriorityThreshold = 150
    if GetTimeSinceLastScoutedSegment(aiBrain, iEnemyBaseSegmentX, iEnemyBaseSegmentZ) - aiBrain[reftAirSegmentTracker][iEnemyBaseSegmentX][iEnemyBaseSegmentZ][refiCurrentScoutingInterval] >= math.min(120, iReallyOverduePriorityThreshold) then
        bHaveLocationsReallyOverdue = true
    end
    --If any location is more than 2m overdue then will filter to only consider locations overdue by this
    --Increase threshold to the enemy base if its overdue by more than this (so we will prioritise scouting enemy base every 3m)



    if bDebugMessages == true then
        LOG(sFunctionRef .. ': bHaveLocationsReallyOverdue=' .. tostring(bHaveLocationsReallyOverdue) .. '; iReallyOverduePriorityThreshold=' .. iReallyOverduePriorityThreshold .. '; amount by which enemy base is overdue=' .. (GetGameTimeSeconds() - aiBrain[reftAirSegmentTracker][iEnemyBaseSegmentX][iEnemyBaseSegmentZ][refiLastScouted] - aiBrain[reftAirSegmentTracker][iEnemyBaseSegmentX][iEnemyBaseSegmentZ][refiCurrentScoutingInterval]))
    end
    if bHaveLocationsReallyOverdue then
        bHaveLocationsReallyOverdue = false
        --If happened before even considering shortlist then pick enemy base as priority location if its in the shortlist
        for iCount, tSubtable1 in aiBrain[reftScoutingTargetShortlist] do
            if aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentX] == iEnemyBaseSegmentX then
                if aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentZ] == iEnemyBaseSegmentZ then
                    bHaveLocationsReallyOverdue = true
                    iFinalCount = iCount
                    break
                end
            end
        end
        if bHaveLocationsReallyOverdue then
            iFinalX = iEnemyBaseSegmentX
            iFinalZ = iEnemyBaseSegmentZ
        end
    end

    if not (iFinalCount) then

        --Get the location closest to scout based on segment check (segment check used instead of getposition for efficiency)
        for iCount, tSubtable1 in aiBrain[reftScoutingTargetShortlist] do
            iCurOverdueTime = aiBrain[reftScoutingTargetShortlist][iCount][refiTimeSinceWantedToScout]
            if not (bHaveLocationsReallyOverdue) and iCurOverdueTime >= iReallyOverduePriorityThreshold then
                --Reset the closest distance and finalX and Z
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Increasing the overdue threshold to be considered to ' .. iReallyOverduePriorityThreshold)
                end
                iGreatestOverdueTime = 0
                iClosestDistance = 10000
                iFinalCount = nil
                bHaveLocationsReallyOverdue = true
            end
            if iCurOverdueTime == nil then
                M27Utilities.ErrorHandler('No overdue time assigned')
            elseif iCurOverdueTime >= iGreatestOverdueTime and (not (bHaveLocationsReallyOverdue) or iCurOverdueTime >= iReallyOverduePriorityThreshold) then
                iCurDistance = math.abs(aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentX] - iStartSegmentX) + math.abs(aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentZ] - iStartSegmentZ)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Segment ' .. aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentX] .. '-' .. aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentZ] .. ' has an overdue time of ' .. iCurOverdueTime .. '; will include it if its either the most overdue time we have, or its closer to the scout; iCurDistance=' .. iCurDistance .. '; iClosestDistance=' .. iClosestDistance)
                end
                if iCurOverdueTime > iGreatestOverdueTime or iCurDistance < iClosestDistance then
                    iClosestDistance = iCurDistance
                    iFinalX = aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentX]
                    iFinalZ = aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentZ]
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Current segment to use for final destination XZ=' .. iFinalX .. '-' .. iFinalZ .. '; iCurOverdueTime=' .. iCurOverdueTime)
                    end
                    iFinalCount = iCount
                end
                iGreatestOverdueTime = iCurOverdueTime
            end
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': iCount=' .. iCount .. '; Segment X-Z=' .. aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentX] .. '-' .. aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentZ] .. '; Time since wanted to scout=' .. aiBrain[reftScoutingTargetShortlist][iCount][refiTimeSinceWantedToScout] .. '; iGreatestOverdueTime=' .. iGreatestOverdueTime .. '; iFinalX-Z=' .. (iFinalX or 'nil') .. '-' .. (iFinalZ or 'nil'))
            end
        end
    end
    if iFinalCount then
        --Update tracker to show we've assigned this scout - this is now done later when the move command is given
        table.remove(aiBrain[reftScoutingTargetShortlist], iFinalCount)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': iFinalX=' .. iFinalX .. '; iFinalZ=' .. iFinalZ .. ': Increasing scouts assigned by 1')
        end
        --aiBrain[reftAirSegmentTracker][iFinalX][iFinalZ][refiAirScoutsAssigned] = aiBrain[reftAirSegmentTracker][iFinalX][iFinalZ][refiAirScoutsAssigned] + 1
        iFinalX = math.max(aiBrain[refiMinSegmentX], math.min(aiBrain[refiMaxSegmentX], iFinalX))
        iFinalZ = math.max(aiBrain[refiMinSegmentZ], math.min(aiBrain[refiMaxSegmentZ], iFinalZ))

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Final destination XZ segments after capping to map size=' .. iFinalX .. '-' .. iFinalZ .. '; about to check for via points')
        end
        return GetAirPositionFromSegment(iFinalX, iFinalZ)
    else
        --No places to scout - return nil (will add player start position at later step)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': No final destination found, will return to base')
        end
        return nil
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function CreateMovementPathFromDestination(aiBrain, tEndDestination, oScout)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CreateMovementPathFromDestination'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tMovementPath = {}
    tMovementPath[1] = tEndDestination
    local tLocalisedShortlist, iLocalShortlistCount
    local bValidViaPointX, bValidViaPointZ
    local iCurSegmentX, iCurSegmentZ

    local iStartSegmentX, iStartSegmentZ = GetAirSegmentFromPosition(oScout:GetPosition())
    local iEndDestinationX, iEndDestinationZ = GetAirSegmentFromPosition(tEndDestination)
    local bWantSmallerThanEndX, bWantSmallerThanEndZ

    local bKeepSearching = true
    local iCurCount = 0
    local iMaxCount = 100
    local iClosestSegmentDistance, iCurSegmentDistance, iClosestSegmentRefX, iClosestSegmentRefZ
    local iOriginalShortlistKeyRef
    local tLocalShortlistToOriginalShortlistIndex = {}
    local tEndViaPoint

    local iDetourDistance = 100


    --First add a via point if scouts have already died trying to get here
    if aiBrain[reftAirSegmentTracker][iEndDestinationX][iEndDestinationZ][refiDeadScoutsSinceLastReveal] > 0 then
        --MoveTowardsTarget(tStartPos, tTargetPos, iDistanceToTravel, iAngle)
        --    --Returns the position that want to move iDistanceToTravel along the path from tStartPos to tTargetPos, ignoring height
        --    --iAngle: 0 = straight line; 90 and 270: right angle to the direction; 180 - opposite direction
        local iAngle = aiBrain[reftAirSegmentTracker][iEndDestinationX][iEndDestinationZ][refiDeadScoutsSinceLastReveal] * 90
        if iAngle == 180 or iAngle >= 360 then
            iAngle = 270
        end
        tEndViaPoint = M27Utilities.MoveTowardsTarget(aiBrain[reftAirSegmentTracker][iEndDestinationX][iEndDestinationZ][reftMidpointPosition], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iDetourDistance, iAngle)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Orig end point was ' .. repru(aiBrain[reftAirSegmentTracker][iEndDestinationX][iEndDestinationZ][reftMidpointPosition]) .. '; new end point is ' .. repru(tEndViaPoint))
        end
        if M27Utilities.IsTableEmpty(tEndViaPoint) == false then
            table.insert(tMovementPath, 1, tEndViaPoint)
            iEndDestinationX, iEndDestinationZ = GetAirSegmentFromPosition(tEndViaPoint)
        end
    end

    local iMaxViaPoints = 20
    local iCurViaPointCount = 0

    while bKeepSearching == true do
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Checking via points for unit, iCurCount=' .. iCurCount)
        end
        iCurCount = iCurCount + 1
        if iCurCount > iMaxCount then
            M27Utilities.ErrorHandler('Infinite loop, will abort')
            break
        end

        if iEndDestinationX - iStartSegmentX < 0 then
            bWantSmallerThanEndX = false
        else
            bWantSmallerThanEndX = true
        end
        if iEndDestinationZ - iStartSegmentZ < 0 then
            bWantSmallerThanEndZ = false
        else
            bWantSmallerThanEndZ = true
        end

        --Create a temporary local shortlist of locations to consider based on the current destination
        iLocalShortlistCount = 0
        tLocalisedShortlist = {}
        for iCount, tSubtable1 in aiBrain[reftScoutingTargetShortlist] do
            iCurSegmentX = aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentX]
            iCurSegmentZ = aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentZ]
            bValidViaPointX = false
            bValidViaPointZ = false
            if bWantSmallerThanEndX then
                if iCurSegmentX <= iEndDestinationX then
                    bValidViaPointX = true
                end
            else
                if iCurSegmentX >= iEndDestinationX then
                    bValidViaPointX = true
                end
            end
            if bValidViaPointX == true then
                if bWantSmallerThanEndZ then
                    if iCurSegmentZ <= iEndDestinationZ then
                        bValidViaPointZ = true
                    end
                else
                    if iCurSegmentZ >= iEndDestinationZ then
                        bValidViaPointZ = true
                    end
                end
                if bValidViaPointZ == true then
                    --Have any scouts died going to this via point?
                    if aiBrain[reftAirSegmentTracker][iCurSegmentX][iCurSegmentZ][refiDeadScoutsSinceLastReveal] == 0 then
                        iLocalShortlistCount = iLocalShortlistCount + 1
                        tLocalisedShortlist[iLocalShortlistCount] = tSubtable1
                        tLocalShortlistToOriginalShortlistIndex[iLocalShortlistCount] = iCount
                    end
                end
            end
        end
        if iLocalShortlistCount > 0 then
            --Pick the best of the localist shortlist, based on which location is closest to the end destination
            iClosestSegmentDistance = 100000
            iClosestSegmentRefX = nil
            iClosestSegmentRefZ = nil
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': iEndDestinationX=' .. iEndDestinationX)
                LOG(sFunctionRef .. ': tLocalisedShortlist[1][refiSegmentX]=' .. tLocalisedShortlist[1][refiSegmentX])
            end
            for iLocalCount, tSubtable2 in tLocalisedShortlist do
                iCurSegmentDistance = math.abs(iEndDestinationX - tLocalisedShortlist[iLocalCount][refiSegmentX]) + math.abs(iEndDestinationZ - tLocalisedShortlist[iLocalCount][refiSegmentZ])
                if iCurSegmentDistance < iClosestSegmentDistance then
                    iClosestSegmentRefX = tLocalisedShortlist[iLocalCount][refiSegmentX]
                    iClosestSegmentRefZ = tLocalisedShortlist[iLocalCount][refiSegmentZ]
                    iOriginalShortlistKeyRef = tLocalShortlistToOriginalShortlistIndex[iLocalCount]
                end
            end

            --Get a new final destination
            if iClosestSegmentRefX then
                table.insert(tMovementPath, 1, GetAirPositionFromSegment(iClosestSegmentRefX, iClosestSegmentRefZ))
                iEndDestinationX = iClosestSegmentRefX
                iEndDestinationZ = iClosestSegmentRefZ
                --Update tracker to show a scout is assigned this location - this is done later when the move command is given
                --aiBrain[reftAirSegmentTracker][iEndDestinationX][iEndDestinationZ][refiAirScoutsAssigned] = aiBrain[reftAirSegmentTracker][iEndDestinationX][iEndDestinationZ][refiAirScoutsAssigned] + 1
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Assining scout to X-Z=' .. iEndDestinationX .. '-' .. iEndDestinationZ)
                end
                --Remove from shortlist so not considered by anything else this cycle
                table.remove(aiBrain[reftScoutingTargetShortlist], iOriginalShortlistKeyRef)
                iCurViaPointCount = iCurViaPointCount + 1
                if iCurViaPointCount >= iMaxViaPoints then
                    bKeepSearching = false
                    break
                end
            else
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Dont have a closest segment X ref')
                end
                break
            end
        else
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Local shortlist count isnt > 0')
            end
            --no viable locations so stop adding via points
            break
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code, tMovementPath=' .. repru(tMovementPath))
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tMovementPath
end

function RecordThatCanSeeSegment(aiBrain, iAirSegmentX, iAirSegmentZ, iTimeStamp)
    for iBrain, oBrain in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] do
        oBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiLastScouted] = iTimeStamp
        oBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiDeadScoutsSinceLastReveal] = 0
        oBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiCurrentScoutingInterval] = oBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiNormalScoutingIntervalWanted]
    end
end

function UpdateSegmentsForLocationVision(aiBrain, tUnitPosition, iVisionRange, iTimeStamp)
    local sFunctionRef = 'UpdateSegmentsForLocationVision'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(tUnitPosition)

    --Next update +/-1 (but not corners)
    local iBoxSize
    if iVisionRange <= iAirSegmentSize then
        iBoxSize = 0
    elseif iVisionRange <= iSegmentVisualThresholdBoxSize1 then
        iBoxSize = 1
    elseif iVisionRange <= iSegmentVisualThresholdBoxSize2 then
        iBoxSize = 2
    else
        iBoxSize = math.ceil((iVisionRange / iAirSegmentSize) - 1)
    end

    local iFirstX = math.max(iCurAirSegmentX - iBoxSize, 1)
    local iLastX = math.min(iCurAirSegmentX + iBoxSize, iMapMaxAirSegmentX)
    local iFirstZ = math.max(iCurAirSegmentZ - iBoxSize, 1)
    local iLastZ = math.min(iCurAirSegmentZ + iBoxSize, iMapMaxAirSegmentZ)

    for iX = iFirstX, iLastX, 1 do
        for iZ = iFirstZ, iLastZ, 1 do
            RecordThatCanSeeSegment(aiBrain, iX, iZ, iTimeStamp)
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DedicatedScoutManager(aiBrain, oScout, oAssistTarget)
    oScout[refbOnAssignment] = true
    M27Utilities.IssueTrackedClearCommands({ oScout })
    oScout[refoAssignedAirScout] = oAssistTarget
    oAssistTarget[refoAssignedAirScout] = oScout
    --local iAngleFromBaseToTarget = M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oAssistTarget:GetPosition())
    --local iCount = 0
    oScout[refiCurMovementPath] = 1
    oScout[reftMovementPath] = { oAssistTarget:GetPosition() }
    IssueGuard({ oScout }, oAssistTarget)

    while M27UnitInfo.IsUnitValid(oAssistTarget) and M27UnitInfo.IsUnitValid(oScout) do
        --Do we have low fuel?
        if oScout:GetFuelRatio() <= 0.25 then
            break
        else
            --if iCount == 0 then

            --iAngleFromBaseToTarget = M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oAssistTarget:GetPosition())

            --oScout[reftMovementPath][oUnit[refiCurMovementPath]]
            --if M27Logic.IsUnitIdle(
            WaitSeconds(1)
            --[[iCount = iCount + 1
    if iCount >= 10 then
       iCount = 0
    end--]]
        end
    end
    if M27UnitInfo.IsUnitValid(oScout) then
        --Reset values so can be used by normal overseer functionality
        oScout[refoAssignedAirScout] = nil
        oScout[refbOnAssignment] = false
        M27Utilities.IssueTrackedClearCommands({ oScout })
        IssueMove({ oScout }, GetAirRallyPoint(aiBrain))
    end
end

function AirScoutManager(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AirScoutManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Determine how many scouts we want and what locations need scouting:
    UpdateScoutingSegmentRequirements(aiBrain)

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code, GameTIme=' .. GetGameTimeSeconds() .. '; is table of available scouts empty?=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftAvailableScouts])))
    end
    if M27Utilities.IsTableEmpty(aiBrain[reftAvailableScouts]) == false then
        --Determine how many scouts are actually available to issue new commands to
        local tAvailableScouts = {}
        local iAvailableScouts = 0
        local tEndDestination, tMovementPath
        local tCurWaypointTarget, iDistanceToComplete
        local iCurAirSegmentX, iCurAirSegmentZ, tUnitCurPosition
        local iCurLoopCount = 0
        local iMaxLoopCount = 30
        local iTotalMovementPaths = 0
        local tOurStart = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local iMoveCount
        local oNavigator, tGoalTarget, tNavigatorTarget

        --First work out if we have any high priority units that want a dedicated air scout assigned to them
        local tDedicatedScoutAssistTargets = {}
        local tPossibleScoutAssistTargets = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryLandExperimental, false, true)
        local iTargetsWantingAssistance = 0
        if M27Utilities.IsTableEmpty(tPossibleScoutAssistTargets) == false then
            for iUnit, oUnit in tPossibleScoutAssistTargets do
                if oUnit:GetFractionComplete() >= 0.95 and not (M27UnitInfo.IsUnitValid(oUnit[refoAssignedAirScout])) then
                    iTargetsWantingAssistance = iTargetsWantingAssistance + 1
                    tDedicatedScoutAssistTargets[iTargetsWantingAssistance] = oUnit
                end
            end
        end

        for iUnit, oUnit in aiBrain[reftAvailableScouts] do
            if M27Utilities.IsTableEmpty(tDedicatedScoutAssistTargets) == false then
                ForkThread(DedicatedScoutManager, aiBrain, oUnit, tDedicatedScoutAssistTargets[iTargetsWantingAssistance])
                tDedicatedScoutAssistTargets[iTargetsWantingAssistance] = nil
            else

                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iUnit=' .. iUnit .. ': Not on assignment so getting end destination')
                end
                tEndDestination = GetEndDestinationForScout(aiBrain, oUnit)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iUnit=' .. iUnit .. ': End destination=' .. repru(tEndDestination))
                end
                if M27Utilities.IsTableEmpty(tEndDestination) == false then
                    tMovementPath = CreateMovementPathFromDestination(aiBrain, tEndDestination, oUnit)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. 'iUnit=' .. iUnit .. ': Full movement path=' .. repru(tMovementPath))
                        M27Utilities.DrawLocations(tMovementPath)
                    end
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': About to issue clear command to scout with unit number=' .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
                    end
                    M27Utilities.IssueTrackedClearCommands({ oUnit })
                    --Issue moves to the targets and update tracker for this
                    iMoveCount = 0
                    for iWaypoint, tWaypoint in tMovementPath do
                        iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(tWaypoint)

                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Issuing move command to go to Segment X-Z=' .. iCurAirSegmentX .. iCurAirSegmentZ .. '; destination=' .. repru(tWaypoint))
                        end
                        if not (aiBrain[reftAirSegmentTracker][iCurAirSegmentX]) then
                            aiBrain[reftAirSegmentTracker][iCurAirSegmentX] = {}
                            aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ] = {}
                        elseif not (aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ]) then
                            aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ] = {}
                        end
                        aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] = (aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] or 0) + 1
                        --M27Logic.IssueDelayedMove({oUnit}, tWaypoint, iMoveCount * 10)
                        IssueMove({ oUnit }, tWaypoint)
                        iMoveCount = iMoveCount + 1
                    end
                    --Return to base at the end:
                    --M27Logic.IssueDelayedMove({oUnit}, tOurStart, iMoveCount * 10)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Setting the unit to be assigned and recording its movement path')
                    end
                    IssueMove({ oUnit }, tOurStart)
                    oUnit[refbOnAssignment] = true
                    oUnit[refiCurMovementPath] = 1
                    oUnit[reftMovementPath] = tMovementPath
                    if M27Config.M27ShowUnitNames == true and oUnit.GetUnitId then
                        M27PlatoonUtilities.UpdateUnitNames({ oUnit }, oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ':ScoutingThenReturningToBase')
                    end
                else
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': No valid final destination so will move to start unless already there')
                    end
                    if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) > 20 then
                        IssueMove({ oUnit }, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    end
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function QuantumOpticsManager(aiBrain, oUnit)
    --Call via forkthread
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'QuantumOpticsManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if M27UnitInfo.IsUnitValid(oUnit) and not (oUnit[M27UnitInfo.refbActiveTargetChecker]) then
        oUnit[M27UnitInfo.refbActiveTargetChecker] = true
        local tAreaToScout
        local oBP = oUnit:GetBlueprint()
        local iIntelRange = (oBP.Intel.RemoteViewingRadius or oBP.Intel.VisionRadius)
        local iDelayInSeconds = math.max(1, (oBP.Intel.ReactivateTime or 1) * 0.1)
        local iSegmentXZOverdueNoScout
        local iSegmentXZOverdueWithScout

        local iScoutMinSegmentX = aiBrain[refiMinSegmentX]
        local iScoutMaxSegmentX = aiBrain[refiMaxSegmentX]
        local iScoutMinSegmentZ = aiBrain[refiMinSegmentZ]
        local iScoutMaxSegmentZ = aiBrain[refiMaxSegmentZ]

        local iTimeSinceLastScouted, iTimeUntilWantToScout, iCurActiveScoutsAssigned
        local iLowestTimeUntilWantToScoutUnassigned
        local iLowestTimeUntilWantToScoutAssigned

        function UpdateOverdueSegment(iCurAirSegmentX, iCurAirSegmentZ)
            iTimeSinceLastScouted = GetTimeSinceLastScoutedSegment(aiBrain, iCurAirSegmentX, iCurAirSegmentZ)
            iTimeUntilWantToScout = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval] - iTimeSinceLastScouted
            iCurActiveScoutsAssigned = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned]
            --If more than 1 scout assigned suggests location with AA so treat same as unassigned
            if iCurActiveScoutsAssigned == 1 then
                if iTimeUntilWantToScout < iLowestTimeUntilWantToScoutAssigned then
                    iLowestTimeUntilWantToScoutAssigned = iTimeUntilWantToScout
                    iSegmentXZOverdueWithScout = { iCurAirSegmentX, iCurAirSegmentZ }
                end
            else
                if iTimeUntilWantToScout < iLowestTimeUntilWantToScoutUnassigned then
                    iLowestTimeUntilWantToScoutUnassigned = iTimeUntilWantToScout
                    iSegmentXZOverdueNoScout = { iCurAirSegmentX, iCurAirSegmentZ }
                end
            end
        end

        while M27UnitInfo.IsUnitValid(oUnit) do
            if oUnit:GetFractionComplete() == 1 then
                if aiBrain:GetEconomyStoredRatio('ENERGY') >= 1 and aiBrain[M27EconomyOverseer.refiGrossEnergyBaseIncome] >= 250 and aiBrain:GetEconomyStored('ENERGY') >= 14000 and not (aiBrain[M27EconomyOverseer.refbStallingEnergy]) then
                    iSegmentXZOverdueNoScout = nil
                    iSegmentXZOverdueWithScout = nil
                    iLowestTimeUntilWantToScoutUnassigned = 10000
                    iLowestTimeUntilWantToScoutAssigned = 10000
                    tAreaToScout = nil

                    --Pick a location to scout - do we have a shortlist?
                    if M27Utilities.IsTableEmpty(aiBrain[reftScoutingTargetShortlist]) then
                        for iCurAirSegmentX = iScoutMinSegmentX, iScoutMaxSegmentX, 1 do
                            for iCurAirSegmentZ = iScoutMinSegmentZ, iScoutMaxSegmentZ, 1 do
                                UpdateOverdueSegment(iCurAirSegmentX, iCurAirSegmentZ)
                            end
                        end
                    else
                        --Pick from existing shortlist
                        for iTargetCount, tSubtable in aiBrain[reftScoutingTargetShortlist] do
                            UpdateOverdueSegment(tSubtable[refiSegmentX], tSubtable[refiSegmentZ])
                        end
                    end
                    --Do we have an overdue no scout location?
                    if iLowestTimeUntilWantToScoutUnassigned < 0 then
                        tAreaToScout = GetAirPositionFromSegment(iSegmentXZOverdueNoScout[1], iSegmentXZOverdueNoScout[2])
                    else
                        --Do we have an overdue 'scout assigned' location?
                        if iLowestTimeUntilWantToScoutAssigned < 0 then
                            tAreaToScout = GetAirPositionFromSegment(iSegmentXZOverdueWithScout[1], iSegmentXZOverdueWithScout[2])
                        else
                            --Just get the lowest unassigned location
                            tAreaToScout = GetAirPositionFromSegment(iSegmentXZOverdueNoScout[1], iSegmentXZOverdueNoScout[2])
                        end
                    end

                    --Scout the area
                    M27UnitInfo.ScryTarget(oUnit, tAreaToScout)
                    --Update segments to show we have visual of the target
                    for iBrain, oBrain in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftFriendlyActiveM27Brains] do
                        UpdateSegmentsForLocationVision(oBrain, oUnit:GetPosition(), iIntelRange, math.ceil(GetGameTimeSeconds() * 10)/10)
                    end
                end
            end

            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitSeconds(iDelayInSeconds)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordSegmentsThatHaveVisualOf(aiBrain)
    --NOTE: If just want to get the last time we had visual range of a segment, refer to the function RecordThatCanSeeSegment, in particular:
    -- aiBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiLastScouted] = iTimeStamp



    local sFunctionRef = 'RecordSegmentsThatHaveVisualOf'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code')
    end
    if not (aiBrain[refbHaveOmniVision]) then
        if GetGameTimeSeconds() - (M27Team.tTeamData[aiBrain.M27Team][M27Team.refiTimeOfLastVisualUpdate] or -1) >= 0.99 then
            local iTimeStamp = math.ceil(GetGameTimeSeconds() * 10)/10
            M27Team.tTeamData[aiBrain.M27Team][M27Team.refiTimeOfLastVisualUpdate] = iTimeStamp

            local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
            local tAirScouts = aiBrain:GetUnitsAroundPoint(refCategoryAirScout * categories.TECH1, tStartPosition, 10000, 'Ally')
            local iAirVision = 42
            for iUnit, oUnit in tAirScouts do
                if not (oUnit.Dead) then
                    UpdateSegmentsForLocationVision(aiBrain, oUnit:GetPosition(), iAirVision, iTimeStamp)
                end
            end
            local tSpyPlanes = aiBrain:GetUnitsAroundPoint(refCategoryAirScout * categories.TECH3, tStartPosition, 10000, 'Ally')
            iAirVision = 64
            for iUnit, oUnit in tSpyPlanes do
                if not (oUnit.Dead) then
                    UpdateSegmentsForLocationVision(aiBrain, oUnit:GetPosition(), iAirVision, iTimeStamp)
                end
            end

            local tAllOtherUnits = aiBrain:GetUnitsAroundPoint(categories.ALLUNITS - refCategoryAirScout - M27UnitInfo.refCategoryMex - M27UnitInfo.refCategoryHydro, tStartPosition, 10000, 'Ally')
            local oCurBP, iCurVision
            for iUnit, oUnit in tAllOtherUnits do
                if not (oUnit.Dead) and oUnit.GetBlueprint then
                    oCurBP = oUnit:GetBlueprint()
                    iCurVision = oCurBP.Intel.VisionRadius
                    if iCurVision and iCurVision >= iAirSegmentSize then
                        UpdateSegmentsForLocationVision(aiBrain, oUnit:GetPosition(), iCurVision, iTimeStamp)
                    end
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end
function GetVulnerableMexes(aiBrain, tStartPoint, iShieldHealthToIgnore, iMinDistanceAwayFromEnemyBase)
    --iMinDistanceAwayFromEnemyBase will default to 0
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetVulnerableMexes'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tEnemyMexes = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryT3Mex, tStartPoint, aiBrain[refiMaxScoutRadius], 'Enemy')
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': tStartPoint=' .. repru(tStartPoint) .. '; iShieldHealthToignore=' .. iShieldHealthToIgnore .. '; Size of tEnemyMexes=' .. table.getn(tEnemyMexes))
    end
    local tVulnerableMexes = {}
    if M27Utilities.IsTableEmpty(tEnemyMexes) == false then
        local iVulnerableMexes = 0
        local tEnemyT3AA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3, tStartPoint, aiBrain[refiMaxScoutRadius], 'Enemy')
        local iRangeToUse = 65 --For performance reasons will approximate with this range; SAMs have a range of 60
        local tEnemyBases
        if iMinDistanceAwayFromEnemyBase > 0 then
            tEnemyBases = {}
            for iBrain, oBrain in aiBrain[M27Overseer.toEnemyBrains] do
                table.insert(tEnemyBases, M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber])
            end
        end
        if M27Utilities.IsTableEmpty(tEnemyT3AA) == false then
            local iDistFromBaseToMex, iDistFromBaseToAA, iDistFromMexToAA, iAngleFromBaseToMex, iAngleFromBaseToAA

            local tMex
            local bIsVulnerable
            for iMex, oMex in tEnemyMexes do
                bIsVulnerable = true
                tMex = oMex:GetPosition()
                --Check if too close to enemy base
                if iMinDistanceAwayFromEnemyBase > 0 and M27Utilities.IsTableEmpty(tEnemyBases) == false then
                    for iStart, tStart in tEnemyBases do
                        if M27Utilities.GetDistanceBetweenPositions(tMex, tStart) <= iMinDistanceAwayFromEnemyBase then
                            bIsVulnerable = false
                            break
                        end
                    end
                end
                if bIsVulnerable then
                    --Is it under heavy shield?
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Checking if oMex=' .. oMex.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oMex) .. ' is under a shield')
                    end
                    if not (M27Logic.IsTargetUnderShield(aiBrain, oMex, iShieldHealthToIgnore, false, false, true)) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Mex isnt under a shield, will see if any T3 AA that will block us')
                        end

                        iDistFromBaseToMex = M27Utilities.GetDistanceBetweenPositions(tStartPoint, tMex)
                        iAngleFromBaseToMex = M27Utilities.GetAngleFromAToB(tStartPoint, tMex)

                        --IsLineFromAToBInRangeOfCircleAtC(iDistFromAToB, iDistFromAToC, iDistFromBToC, iAngleFromAToB, iAngleFromAToC, iCircleRadius)

                        for iAA, oAA in tEnemyT3AA do
                            iDistFromBaseToAA = M27Utilities.GetDistanceBetweenPositions(tStartPoint, oAA:GetPosition())
                            iAngleFromBaseToAA = M27Utilities.GetAngleFromAToB(tStartPoint, oAA:GetPosition())
                            iDistFromMexToAA = M27Utilities.GetDistanceBetweenPositions(tMex, oAA:GetPosition())
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Will check if mex has AA that will block it; oAA=' .. oAA.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAA) .. '; iDistFromBaseToMex=' .. iDistFromBaseToMex .. '; iDistFromBaseToAA=' .. iDistFromBaseToAA .. '; iDistFromMexToAA=' .. iDistFromMexToAA)
                            end
                            if M27Utilities.IsLineFromAToBInRangeOfCircleAtC(iDistFromBaseToMex, iDistFromBaseToAA, iDistFromMexToAA, iAngleFromBaseToMex, iAngleFromBaseToAA, iRangeToUse) then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': AA is blocking the path to mex')
                                end
                                bIsVulnerable = false
                                break
                            end
                        end
                    else
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Mex is under a shield')
                        end
                        bIsVulnerable = false
                    end

                    if not (bIsVulnerable) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Mex is vulnerable so recording')
                        end
                        iVulnerableMexes = iVulnerableMexes + 1
                        tVulnerableMexes[iVulnerableMexes] = tMex
                    end
                end
            end
        else
            for iMex, oMex in tEnemyMexes do
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': No T3+ AA so will record all mexes that arent under a shield; oMex=' .. oMex.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oMex))
                end
                if not (M27Logic.IsTargetUnderShield(aiBrain, oMex, iShieldHealthToIgnore, false, false, true)) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Mex is vulnerable so recording')
                    end
                    iVulnerableMexes = iVulnerableMexes + 1
                    tVulnerableMexes[iVulnerableMexes] = oMex:GetPosition()
                end
            end
        end
    elseif bDebugMessages == true then
        LOG(sFunctionRef .. ': No enemy T2 or T3 mexes')
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code, tVulnerableMexes=' .. repru((tVulnerableMexes or { 'nil' })))
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tVulnerableMexes
end

--GetBomberTargetShortlist - removed from v42 (was only being used by the old bomber logic replaced some time ago now)
--IssueLargeBomberAttack - removed from v42 (was only being used by old bomber logic)

function GetBomberPreTargetViaPoint(oBomber, tGroundTarget, bTargetingMobileUnit)
    --Returns nil if no need for a via point
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetBomberPreTargetViaPoint'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if M27UnitInfo.GetUnitTechLevel(oBomber) == 3 then bDebugMessages = true end

    local tViaPoint
    --Are we at least the bomber's range + 10 from the target or are a strat bomber that will want a run-up anyway?
    local iDistanceWanted = M27UnitInfo.GetBomberRange(oBomber) + 25
    if bTargetingMobileUnit then
        iDistanceWanted = iDistanceWanted * 1.3
    end
    if M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), tGroundTarget) > iDistanceWanted or M27UnitInfo.GetUnitTechLevel(oBomber) >= 3 then
        local tPossibleViaPoint
        local iAngleFromTargetToBomber = M27Utilities.GetAngleFromAToB(tGroundTarget, oBomber:GetPosition())
        local iAOE, iStrikeDamage = M27UnitInfo.GetBomberAOEAndStrikeDamage(oBomber)
        iAOE = math.max(math.floor(iAOE * 0.6), 1)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Via point if dont limit to map area=' .. repru(M27Utilities.MoveInDirection(tGroundTarget, iAngleFromTargetToBomber, iDistanceWanted)) .. '; via point if limit to map area=' .. repru(M27Utilities.MoveInDirection(tGroundTarget, iAngleFromTargetToBomber, iDistanceWanted, true)))
        end
        tPossibleViaPoint = M27Utilities.MoveInDirection(tGroundTarget, iAngleFromTargetToBomber, iDistanceWanted, true)
        tPossibleViaPoint = { tPossibleViaPoint[1], tGroundTarget[2] + 25, tPossibleViaPoint[3] }
        local aiBrain = oBomber:GetAIBrain()
        if GetSurfaceHeight(tPossibleViaPoint[1], tPossibleViaPoint[3]) >= tPossibleViaPoint[2] or M27Logic.IsLineBlocked(aiBrain, tPossibleViaPoint, tGroundTarget, iAOE) then
            --Need to find a new via point to make sure our shot isnt blocked
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Ground target=' .. repru(tGroundTarget) .. '; initial expected position=' .. repru(tPossibleViaPoint) .. '; line is blocked so will try alternative positions')
            end

            for iAngleAdjust = 10, 170, 10 do
                for iAngleFactor = -1, 1, 2 do
                    tPossibleViaPoint = M27Utilities.MoveInDirection(tGroundTarget, iAngleFromTargetToBomber + iAngleAdjust * iAngleFactor, iDistanceWanted, true)
                    tPossibleViaPoint = { tPossibleViaPoint[1], tGroundTarget[2] + 25, tPossibleViaPoint[3] }
                    if not (M27Logic.IsLineBlocked(aiBrain, tPossibleViaPoint, tGroundTarget, iAOE)) then
                        tViaPoint = tPossibleViaPoint
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Found a valid via point=' .. repru(tViaPoint) .. '; will draw in gold')
                            M27Utilities.DrawLocation(tViaPoint, nil, 4, 200)
                        end

                        break
                    elseif bDebugMessages == true then
                        LOG(sFunctionRef .. ': Tried out location ' .. repru(tPossibleViaPoint) .. '; Line is blocked so will keep trying; iAngleAdjust=' .. iAngleAdjust * iAngleFactor .. '; will draw in white')
                        M27Utilities.DrawLocation(tPossibleViaPoint, nil, 7, 200, nil)
                    end
                end
                if tViaPoint then
                    break
                end
            end
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tViaPoint
end

function TellBomberToAttackTarget(oBomber, oTarget, bClearCommands, bAreHoverBombing)
    --Works out the best location to attack, and then if the bomber should be sent a move command to ensure its bomb will hit the target
    --bAreHoverBombing - if true, then will pick a location within 2.5 degrees of the bomber facing direction if possible
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'TellBomberToAttackTarget'
    local aiBrain = oBomber:GetAIBrain()
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if M27UnitInfo.GetUnitTechLevel(oBomber) == 4 then bDebugMessages = true end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code for bomber ' .. oBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oBomber) .. ' which is attacking oTarget=' .. oTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oTarget))
    end
    --if M27UnitInfo.GetUnitTechLevel(oBomber) == 3 then bDebugMessages = true end

    local bTargetGround
    local iBomberAOE, iBomberStrikeDamage = M27UnitInfo.GetBomberAOEAndStrikeDamage(oBomber)
    local tGroundTarget

    oBomber[refbOnAssignment] = true

    --If T1 bomber whose target is within bomber mod distance + 20 then track it
    if EntityCategoryContains(categories.TECH1, oBomber.UnitId) and aiBrain[refiBomberDefenceModDistance] > aiBrain[refiBomberDefenceCriticalThreatDistance] and aiBrain[refiBomberDefenceModDistance] - 20 > M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oTarget:GetPosition()) then
        oBomber[refiModDefenceRangeAtTimeTargetAssigned] = aiBrain[refiBomberDefenceModDistance]
    else
        oBomber[refiModDefenceRangeAtTimeTargetAssigned] = nil
    end

    if iBomberAOE >= 2 and EntityCategoryContains(M27UnitInfo.refCategoryStructure, oTarget.UnitId) then
        bTargetGround = true
    elseif iBomberAOE >= 2 and M27UnitInfo.IsUnitUnderwater(oTarget) and EntityCategoryContains(M27UnitInfo.refCategoryBomber, oBomber.UnitId) then
        bTargetGround = true
    end
    --Will reduce bomber aoe by 0.1 as had an issue where bombers were just missing a mex, not sure if this was the cause; however if come across same issue use logs to confirm what is causing in case it's somethign else
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Considering oBomber=' .. oBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oBomber) .. '; iBomberAOE=' .. (iBomberAOE or 'nil'))
    end
    oBomber[reftGroundAttackLocation] = nil
    if bTargetGround then
        tGroundTarget = M27Logic.GetBestAOETarget(aiBrain, oTarget:GetPosition(), iBomberAOE - 0.1, iBomberStrikeDamage)
        if bAreHoverBombing then
            --Check if this target is valid
            local iMaxAngleWanted = 2.5
            local iBomberRange = 90
            local oBP = oBomber:GetBlueprint()
            for iWeapon, tWeapon in oBP.Weapon do
                if tWeapon.WeaponCategory == 'Bomb' then
                    iBomberRange = tWeapon.MaxRadius
                end
            end
            local iMinDistanceWanted = iBomberRange * 0.39
            local iCurBomberFacing = M27UnitInfo.GetUnitFacingAngle(oBomber)
            if M27Utilities.GetDistanceBetweenPositions(tGroundTarget, oBomber:GetPosition()) < iMinDistanceWanted or math.abs(M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), tGroundTarget) - iCurBomberFacing) >= iMaxAngleWanted then
                --Not sure the hover-bomb will hit, so see if we can get a better target
                local iCurDistToTarget = M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), oTarget:GetPosition())
                local iCurAngleToTarget = M27Utilities.GetAngleFromAToB(oBomber:GetPosition(), oTarget:GetPosition())
                if iCurDistToTarget >= iMinDistanceWanted and math.abs(iCurBomberFacing - iCurAngleToTarget) <= iMaxAngleWanted then
                    --Should be able to get a new target within the constraints wanted
                    tGroundTarget = M27Utilities.MoveInDirection(oBomber:GetPosition(), iCurAngleToTarget, math.max(iMinDistanceWanted, iCurDistToTarget - (iBomberAOE - 0.5)), false)
                else
                    --Cant get a new target so just issue a normal attack instead of attackground
                    bTargetGround = false
                end
            end
        end
    else
        tGroundTarget = oTarget:GetPosition()
    end

    --Get the bomber to line up so it can hit the target if relevant

    local tPreTargetViaPoint
    local bTargetingMobileUnit = false
    if not (bTargetGround) and EntityCategoryContains(categories.MOBILE, oTarget.UnitId) then
        bTargetingMobileUnit = true
    end
    if not (bAreHoverBombing) then
        tPreTargetViaPoint = GetBomberPreTargetViaPoint(oBomber, tGroundTarget, bTargetingMobileUnit)
    end
    --if oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': tPreTargetViaPoint=' .. repru((tPreTargetViaPoint or { 'nil' })))
    end
    if bClearCommands then
        M27Utilities.IssueTrackedClearCommands({ oBomber })
    end
    if M27Utilities.IsTableEmpty(tPreTargetViaPoint) == false then
        IssueMove({ oBomber }, tPreTargetViaPoint)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Issued pre target via point to the bomber ' .. oBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oBomber))
        end
    end

    if not (bTargetGround) then
        IssueAttack({ oBomber }, oTarget)
    else
        IssueAttack({ oBomber }, tGroundTarget)
        oBomber[reftGroundAttackLocation] = tGroundTarget
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Just issued attack at oTarget=' .. oTarget.UnitId .. '; Size of bomber target list=' .. table.getn(oBomber[reftTargetList]) .. '; iCurTargetNumber=' .. oBomber[refiCurTargetNumber] .. ': Issued attack order for target with position=' .. repru(tGroundTarget) .. ' and unitId=' .. oTarget.UnitId .. '; GameTime=' .. GetGameTimeSeconds())
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function DebugBomberTracker(oBomber)
    --Used for temporary debugging of a particular bomber
    local sFunctionRef = 'DebugBomberTracker'
    while M27UnitInfo.IsUnitValid(oBomber) do
        LOG(sFunctionRef .. ': Time=' .. math.floor(GetGameTimeSeconds()) .. '; Bomber position=' .. repru(oBomber:GetPosition()) .. '; Terrain height of position=' .. GetTerrainHeight(oBomber:GetPosition()[1], oBomber:GetPosition()[3]))
        WaitTicks(10)
    end
end

function DetermineBomberDefenceRange(aiBrain)
    --Calculate bomber defence range (affects both targeting, and production of bombers)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DetermineBomberDefenceRange'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    --Decrease by at most 1 per second so have more gradual defence range reduction; can increase by any amount though
    local iPrevDefenceRange = (aiBrain[refiBomberDefenceModDistance] or 150)
    local iMaxRange = math.min(325, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.5)
    aiBrain[refiBomberDefenceDistanceCap] = iMaxRange

    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle then
        aiBrain[refiBomberDefenceModDistance] = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, aiBrain[M27MapInfo.reftChokepointBuildLocation], false) + 45
        local iClosestExperimentalModDist = 10000
        if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyLandExperimentals]) == false then
            local iCurModDist
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Enemy has land experimentals, will get the closest one and consider increasing mod distance')
            end
            for iUnit, oUnit in aiBrain[M27Overseer.reftEnemyLandExperimentals] do
                if M27UnitInfo.IsUnitValid(oUnit) then
                    iCurModDist = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; iCurModDist=' .. iCurModDist .. '; Actual dist to start=' .. M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) .. '; iClosestExperimentalModDist before update=' .. iClosestExperimentalModDist)
                    end
                    if iCurModDist < iClosestExperimentalModDist then
                        iClosestExperimentalModDist = iCurModDist
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Have set iClosestExperimentalModDist to ' .. iClosestExperimentalModDist)
                        end
                    end
                end
            end
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Before updating bomber defence for experimental, it is ' .. aiBrain[refiBomberDefenceModDistance] .. '; higher of this and 15+closest experimental mod dist=' .. math.max(aiBrain[refiBomberDefenceModDistance], iClosestExperimentalModDist + 15) .. '; this plus 90=' .. aiBrain[refiBomberDefenceModDistance] + 90)
        end
        if iClosestExperimentalModDist <= aiBrain[refiBomberDefenceModDistance] + 170 then
            aiBrain[refiBomberDefenceModDistance] = math.max(aiBrain[refiBomberDefenceModDistance], iClosestExperimentalModDist + 30) --Factory only builds bombers as emergency if more than 20 inside emergency defence range
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Bomber defence dist after increasing for experimental=' .. aiBrain[refiBomberDefenceModDistance] .. '; iClosestExperimentalModDist=' .. iClosestExperimentalModDist)
            end
        else
            local tNearbyIndirect = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryIndirectT2Plus + M27UnitInfo.refCategorySniperBot + M27UnitInfo.refCategoryFatboy, aiBrain[M27MapInfo.reftChokepointBuildLocation], 100, 'Enemy')
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': aiBrain[refiBomberDefenceModDistance] based on firebase=' .. aiBrain[refiBomberDefenceModDistance] .. '; Is tNearbyIndirect empty=' .. tostring(M27Utilities.IsTableEmpty(tNearbyIndirect)))
            end
            if M27Utilities.IsTableEmpty(tNearbyIndirect) == false then
                aiBrain[refiBomberDefenceModDistance] = aiBrain[refiBomberDefenceModDistance] + 80
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Increased bomber defence distance due to enemy indirect units, defence mod dist=' .. aiBrain[refiBomberDefenceModDistance])
                end
            end
        end
        aiBrain[refiBomberDefenceCriticalThreatDistance] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27MapInfo.reftChokepointBuildLocation]) + 35
        aiBrain[refiBomberDefenceDistanceCap] = aiBrain[refiBomberDefenceCriticalThreatDistance] + 100
    elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyProtectACU then
        aiBrain[refiBomberDefenceModDistance] = math.min(130, math.max(60, 20 + aiBrain[M27Overseer.refiHighestMobileLandEnemyRange]))
        aiBrain[refiBomberDefenceCriticalThreatDistance] = math.max(50, aiBrain[refiBomberDefenceModDistance] - 20)
    else
        aiBrain[refiBomberDefenceCriticalThreatDistance] = math.min(math.max(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.2, math.min(130, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * math.min(0.35, aiBrain[M27Overseer.refiMaxDefenceCoveragePercentWanted]))))

        --aiBrain[refiBomberDefencePercentRange] = 0.25 --(Will decrease if in air domination mode)
        --Increase bomber defence range if enemy has a land experimental that is within 40% of the base, or we have high value buildings we want to protect (in which case base the % range on the % that would provide 120 range protection on high value buildings)
        aiBrain[refbBomberDefenceRestrictedByAA] = false

        aiBrain[refiBomberDefenceModDistance] = math.min(125, iMaxRange - 20)
        local iClosestEnemyExperimental = 10000
        if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyLandExperimentals]) == false then

            local iCurDistance
            for iUnit, oUnit in aiBrain[M27Overseer.reftEnemyLandExperimentals] do
                if M27UnitInfo.IsUnitValid(oUnit) then
                    --iCurDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    iCurDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false)
                    if iCurDistance < iClosestEnemyExperimental then
                        iClosestEnemyExperimental = iCurDistance
                    end
                end
            end
            if iClosestEnemyExperimental <= 300 then
                aiBrain[refiBomberDefenceModDistance] = iClosestEnemyExperimental + 40
            end
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': aiBrain[refiBomberDefenceModDistance] after checking for enemy experimentals=' .. aiBrain[refiBomberDefenceModDistance] .. '; iMaxRange=' .. iMaxRange .. '; Dist to enemy base=' .. aiBrain[M27Overseer.refiDistanceToNearestEnemyBase])
        end
        if aiBrain[refiBomberDefenceModDistance] < iMaxRange then
            --Consider friendly experimentals under construction, and completed high value structures

            --Note: These limits get increased further below by 60, which should cover most units that can threaten them
            aiBrain[refiBomberDefenceDistanceCap] = math.max(aiBrain[refiBomberDefenceDistanceCap], 20 + aiBrain[M27Overseer.refiFurthestValuableBuildingActualDist])
            aiBrain[refiBomberDefenceModDistance] = aiBrain[M27Overseer.refiFurthestValuableBuildingModDist]
            aiBrain[refiBomberDefenceModDistance] = math.min(aiBrain[refiBomberDefenceModDistance], aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.45)
        end

        aiBrain[refiBomberDefenceModDistance] = math.min(aiBrain[refiBomberDefenceModDistance] + 60, iMaxRange, aiBrain[M27Overseer.refiMaxDefenceCoveragePercentWanted] * aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] + 10)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Have increased defence distance to ' .. aiBrain[refiBomberDefenceModDistance] .. '; iMaxRange=' .. iMaxRange .. '; will increase further if have lots of available bombers. aiBrain[refiPreviousAvailableBombers]=' .. aiBrain[refiPreviousAvailableBombers])
        end

        --Limit defence range if we are far behind (with the limit not as great if enemy experimental is getting near)
        if aiBrain[refiBomberDefenceModDistance] >= 125 and aiBrain[refbFarBehindOnAir] then
            aiBrain[refiBomberDefenceModDistance] = math.min(aiBrain[refiBomberDefenceModDistance], math.max(125, math.min(175, iClosestEnemyExperimental), aiBrain[refiOurFurthestAAStructureFromBase] + 60))
        end

        --Increase bomber defence range if are enemy T3 indirect fire within it (since they have a greater range)
        local tEnemyIndirect = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryIndirectT2Plus, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iMaxRange + 50, 'Enemy')
        if M27Utilities.IsTableEmpty(tEnemyIndirect) == false then
            local oNearestIndirect = M27Utilities.GetNearestUnit(tEnemyIndirect, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain)
            aiBrain[refiBomberDefenceModDistance] = math.max(aiBrain[refiBomberDefenceModDistance], M27Utilities.GetDistanceBetweenPositions(oNearestIndirect:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) + 100)
        end

        --Increase effective range if we have lots of bombers idle
        if aiBrain[refiPreviousAvailableBombers] >= 10 then
            aiBrain[refiBomberDefenceModDistance] = aiBrain[refiBomberDefenceModDistance] + math.min(70, (aiBrain[refiPreviousAvailableBombers] - 10))
        end

        --Reduce range if nearest enemy unit is much closer and we had few available bombers last cycle
        if aiBrain[refiPreviousAvailableBombers] <= 5 then
            aiBrain[refiBomberDefenceModDistance] = math.min(aiBrain[M27Overseer.refiModDistFromStartNearestThreat] + 90, aiBrain[refiBomberDefenceModDistance])
        end

        --Increase defence range based on air rally point to make sure our bombers cant be attacked by land units
        local tRallyPoint = GetAirRallyPoint(aiBrain)
        aiBrain[refiBomberDefenceModDistance] = math.max(aiBrain[refiBomberDefenceModDistance], M27Utilities.GetDistanceBetweenPositions(tRallyPoint, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) + 40)

        --Reduce defence distance if nearby enemy air unit that is AirAA and we need airaa
        if aiBrain[refiAirAANeeded] >= 1 and M27UnitInfo.IsUnitValid(aiBrain[refoNearestEnemyAirThreat]) and EntityCategoryContains(refCategoryAirAA, aiBrain[refoNearestEnemyAirThreat].UnitId) then
            aiBrain[refiBomberDefenceModDistance] = math.min(aiBrain[refiBomberDefenceModDistance], M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, aiBrain[refoNearestEnemyAirThreat]:GetPosition()) - 30)
        end

        --Limit reduction to 4 per second
        aiBrain[refiBomberDefenceModDistance] = math.max(aiBrain[refiBomberDefenceModDistance], iPrevDefenceRange - 4)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Range after limiting to a reduction of 2 per second=' .. aiBrain[refiBomberDefenceModDistance])
        end

        --Dont limit beyond the critical threat distance
        aiBrain[refiBomberDefenceModDistance] = math.max(aiBrain[refiBomberDefenceModDistance], aiBrain[refiBomberDefenceCriticalThreatDistance])

        --Further override - reduce the defence range if there is nearby T2 fixed flak or SAMs, or shielded T1 AA
        if aiBrain[refiBomberDefenceModDistance] >= 75 then
            local tNearbyStructureAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructureAA, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiBomberDefenceModDistance] + 50, 'Enemy')
            if M27Utilities.IsTableEmpty(tNearbyStructureAA) == false then
                aiBrain[refbBomberDefenceRestrictedByAA] = true --Want to set this flag even if we arent actually restricted, since dont want to eco and want more land tanks if enemy has AA within our bomber defence range
                local iCurDist
                local iClosestDist = 10000
                local iRange
                for iUnit, oUnit in tNearbyStructureAA do
                    if oUnit:GetFractionComplete() >= 0.8 then
                        iCurDist = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false)
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Enemy AA within bomber defence range. Unit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; iCurDist=' .. iCurDist .. '; Unit tech level=' .. M27UnitInfo.GetUnitTechLevel(oUnit) .. '; Is under shield=' .. tostring(M27Logic.IsTargetUnderShield(aiBrain, oUnit, 3250, false, true, false)))
                        end
                        if iCurDist < iClosestDist then
                            if EntityCategoryContains(categories.TECH3, oUnit.UnitId) or M27Logic.IsTargetUnderShield(aiBrain, oUnit, 3250, false, true, false) then
                                iClosestDist = iCurDist
                                if EntityCategoryContains(categories.TECH1, oUnit.UnitId) then
                                    iRange = 30
                                elseif EntityCategoryContains(categories.TECH2, oUnit.UnitId) then
                                    iRange = 50
                                else
                                    iRange = 60
                                end
                            end
                        end
                    end
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Finished going through enemy units. iClosestDist=' .. iClosestDist .. '; aiBrain[refiBomberDefenceModDistance]=' .. aiBrain[refiBomberDefenceModDistance])
                end

                if iClosestDist < aiBrain[refiBomberDefenceModDistance] then
                    aiBrain[refiBomberDefenceModDistance] = math.max(iClosestDist - iRange, 75, math.min(150, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * math.min(0.2, aiBrain[M27Overseer.refiMaxDefenceCoveragePercentWanted])))
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': aiBrain[refiBomberDefenceModDistance] after updating for enemy shielded AA or SAM=' .. aiBrain[refiBomberDefenceModDistance])
                    end
                end
            end
        end


        --Limit the bomber defence range if bombers are failing to drop more than 1 bomb
        if M27Utilities.IsTableEmpty(aiBrain[refiBomberIneffectivenessByDefenceModRange]) == false then
            local iCumulativeFailedBomberValue = 0
            local iHighestValidValue = 0
            local iLowestFailedValue = 1000000

            for iEntry, iFailedTotal in M27Utilities.SortTableByValue(aiBrain[refiBomberIneffectivenessByDefenceModRange], false) do
                if iEntry > aiBrain[refiBomberDefenceModDistance] then
                    break
                else
                    iCumulativeFailedBomberValue = iCumulativeFailedBomberValue + iFailedTotal
                    if iCumulativeFailedBomberValue < 15 then
                        iHighestValidValue = iEntry
                    else
                        if iEntry < iLowestFailedValue then
                            iLowestFailedValue = iEntry
                        end
                    end
                end
            end

            if iCumulativeFailedBomberValue >= 15 then
                local iValueCap = iHighestValidValue
                if iLowestFailedValue > (iHighestValidValue + 1) then
                    iValueCap = math.max(iHighestValidValue + 1, iLowestFailedValue - 5)
                end
                aiBrain[refiBomberDefenceModDistance] = math.max(aiBrain[refiBomberDefenceCriticalThreatDistance], math.min(aiBrain[refiBomberDefenceModDistance], iValueCap))
            end
        end

        --Limit the defence range based on nearest enemy dangerous AA
        if aiBrain[refiBomberDefenceModDistance] > 125 then
            aiBrain[refiBomberDefenceModDistance] = math.max(125, math.min(aiBrain[refiBomberDefenceModDistance], aiBrain[refiClosestEnemyDangerousAADistToOurBase] - 80))
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function IsTargetPositionCoveredByAA(tTarget, tEnemyAA, tStartPoint, bReturnNumberOfAA, iMinAAConstructionPercent)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsTargetPositionCoveredByAA'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code. tTarget=' .. repru(tTarget) .. '; tStartPoint=' .. repru(tStartPoint))
    end

    local iAAInRange = 0
    local iDistFromStartToTarget = M27Utilities.GetDistanceBetweenPositions(tStartPoint, tTarget)
    local iDistFromStartToAA
    local iDistFromTargetToAA
    local iAngleFromStartToTarget = M27Utilities.GetAngleFromAToB(tStartPoint, tTarget)
    local iAngleFromStartToAA
    local iAARange
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Rechecking if any AA blocking. iAngleFromStartToTarget=' .. iAngleFromStartToTarget .. '; iDistanceFromStartToTarget=' .. iDistFromStartToTarget)
    end

    for iUnit, oUnit in tEnemyAA do
        if not (iMinAAConstructionPercent) or oUnit:GetFractionComplete() > iMinAAConstructionPercent then
            iDistFromStartToAA = M27Utilities.GetDistanceBetweenPositions(tStartPoint, oUnit:GetPosition())
            iDistFromTargetToAA = M27Utilities.GetDistanceBetweenPositions(tTarget, oUnit:GetPosition())
            iAngleFromStartToAA = M27Utilities.GetAngleFromAToB(tStartPoint, oUnit:GetPosition())
            iAARange = M27UnitInfo.GetUnitAARange(oUnit) + 15
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': considering AA unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; iDistFromStartToAA=' .. iDistFromStartToAA .. '; iDistFromTargetToAA=' .. iDistFromTargetToAA .. '; iAngleFromStartToAA=' .. iAngleFromStartToAA .. '; iAARange=' .. iAARange .. '; Is AA in range=' .. tostring(M27Utilities.IsLineFromAToBInRangeOfCircleAtC(iDistFromStartToTarget, iDistFromStartToAA, iDistFromTargetToAA, iAngleFromStartToTarget, iAngleFromStartToAA, iAARange)))
            end
            --IsLineFromAToBInRangeOfCircleAtC(iDistFromAToB, iDistFromAToC, iDistFromBToC, iAngleFromAToB, iAngleFromAToC, iCircleRadius)
            --E.g. if TML is at point A, target is at point B, and TMD is at point C, does the TMD block the TML in a straight line?
            if M27Utilities.IsLineFromAToBInRangeOfCircleAtC(iDistFromStartToTarget, iDistFromStartToAA, iDistFromTargetToAA, iAngleFromStartToTarget, iAngleFromStartToAA, iAARange) then
                iAAInRange = iAAInRange + 1
                if not (bReturnNumberOfAA) then
                    break
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code, iAAInRange=' .. iAAInRange)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if bReturnNumberOfAA then
        return iAAInRange
    else
        if iAAInRange > 0 then
            return true
        else
            return false
        end
    end
end
function IsTargetCoveredByAA(oTarget, tEnemyAA, iTechLevelOfEnemyAA, tStartPoint, bReturnNumberOfAA, bForceRefresh)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsTargetCoveredByAA'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --tEnemyAA should be list of all AA units of the relevant tech level, otherwise the tracking of if a target is protected will give false results
    if not (oTarget[refiLastCoveredByAAByTech]) then
        oTarget[refiLastCoveredByAAByTech] = {}
        oTarget[refbLastCoveredByAAByTech] = {}
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code. oTarget=' .. oTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oTarget) .. '; iTechLevelOfEnemyAA=' .. iTechLevelOfEnemyAA .. '; tStartPoint=' .. repru(tStartPoint))
    end

    --If we have already checked in the last 10 seconds and it was protected, or we checked in the last 2 seconds and it wasn't then just use this value
    if not (bReturnNumberOfAA) and not (bForceRefresh) then
        if oTarget[refbLastCoveredByAAByTech][iTechLevelOfEnemyAA] and GetGameTimeSeconds() - oTarget[refiLastCoveredByAAByTech][iTechLevelOfEnemyAA] <= 10 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': We have checked in the last 10 seconds and the target was protected. Time last checked=' .. GetGameTimeSeconds() - oTarget[refiLastCoveredByAAByTech][iTechLevelOfEnemyAA])
            end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return true
        elseif oTarget[refiLastCoveredByAAByTech][iTechLevelOfEnemyAA] and GetGameTimeSeconds() - oTarget[refiLastCoveredByAAByTech][iTechLevelOfEnemyAA] <= 2 then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': We have checked in the last 2 seconds so will rely on this result.  Tiem since last checked=' .. GetGameTimeSeconds() - oTarget[refiLastCoveredByAAByTech][iTechLevelOfEnemyAA])
            end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return false
        end
    end

    --Havent checked recently or want a total number count or bForceRefresh is true so recheck
    local iAAInRange = 0
    oTarget[refiLastCoveredByAAByTech][iTechLevelOfEnemyAA] = GetGameTimeSeconds()
    oTarget[refbLastCoveredByAAByTech][iTechLevelOfEnemyAA] = false
    local bAACovers = false
    local iDistFromStartToTarget = M27Utilities.GetDistanceBetweenPositions(tStartPoint, oTarget:GetPosition())
    local iDistFromStartToAA
    local iDistFromTargetToAA
    local iAngleFromStartToTarget = M27Utilities.GetAngleFromAToB(tStartPoint, oTarget:GetPosition())
    local iAngleFromStartToAA
    local iAARange
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Rechecking if any AA blocking. iAngleFromStartToTarget=' .. iAngleFromStartToTarget .. '; iDistanceFromStartToTarget=' .. iDistFromStartToTarget)
    end

    if M27Utilities.IsTableEmpty(tEnemyAA) == false then
        for iUnit, oUnit in tEnemyAA do
            iDistFromStartToAA = M27Utilities.GetDistanceBetweenPositions(tStartPoint, oUnit:GetPosition())
            iDistFromTargetToAA = M27Utilities.GetDistanceBetweenPositions(oTarget:GetPosition(), oUnit:GetPosition())
            iAngleFromStartToAA = M27Utilities.GetAngleFromAToB(tStartPoint, oUnit:GetPosition())
            iAARange = M27UnitInfo.GetUnitAARange(oUnit) + 15
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': considering AA unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; iDistFromStartToAA=' .. iDistFromStartToAA .. '; iDistFromTargetToAA=' .. iDistFromTargetToAA .. '; iAngleFromStartToAA=' .. iAngleFromStartToAA .. '; iAARange=' .. iAARange .. '; Is AA in range=' .. tostring(M27Utilities.IsLineFromAToBInRangeOfCircleAtC(iDistFromStartToTarget, iDistFromStartToAA, iDistFromTargetToAA, iAngleFromStartToTarget, iAngleFromStartToAA, iAARange)))
            end
            --IsLineFromAToBInRangeOfCircleAtC(iDistFromAToB, iDistFromAToC, iDistFromBToC, iAngleFromAToB, iAngleFromAToC, iCircleRadius)
            --E.g. if TML is at point A, target is at point B, and TMD is at point C, does the TMD block the TML in a straight line?
            if M27Utilities.IsLineFromAToBInRangeOfCircleAtC(iDistFromStartToTarget, iDistFromStartToAA, iDistFromTargetToAA, iAngleFromStartToTarget, iAngleFromStartToAA, iAARange) then
                oTarget[refbLastCoveredByAAByTech][iTechLevelOfEnemyAA] = true
                iAAInRange = iAAInRange + 1
                if not (bReturnNumberOfAA) then
                    break
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code, about to return ' .. tostring(oTarget[refbLastCoveredByAAByTech][iTechLevelOfEnemyAA]) .. '; or iAAInRange=' .. iAAInRange)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    if bReturnNumberOfAA then
        return iAAInRange
    else
        return oTarget[refbLastCoveredByAAByTech][iTechLevelOfEnemyAA]
    end
end

function GetTargetAACoverage(oTarget, tEnemyAA, tStartPoint, iRangeBuffer)
    --Returns a table of units that are protecting oTarget, or iwthin iRangeBuffer of protecting target
    --Similar to IsTargetCoveredByAA but more intensive so use sparingly - currently intended for use by gunship but only on their planned target
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetTargetAirThreatCoverage'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tRelevantAA = {}

    --Havent checked recently or want a total number count or bForceRefresh is true so recheck
    local iAAInRange = 0
    local iDistFromStartToTarget = M27Utilities.GetDistanceBetweenPositions(tStartPoint, oTarget:GetPosition())
    local iDistFromStartToAA
    local iDistFromTargetToAA
    local iAngleFromStartToTarget = M27Utilities.GetAngleFromAToB(tStartPoint, oTarget:GetPosition())
    local iAngleFromStartToAA
    local iAARange
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Rechecking if any AA blocking. iAngleFromStartToTarget=' .. iAngleFromStartToTarget .. '; iDistanceFromStartToTarget=' .. iDistFromStartToTarget)
    end

    if M27Utilities.IsTableEmpty(tEnemyAA) == false then
        for iUnit, oUnit in tEnemyAA do
            iDistFromStartToAA = M27Utilities.GetDistanceBetweenPositions(tStartPoint, oUnit:GetPosition())
            iDistFromTargetToAA = M27Utilities.GetDistanceBetweenPositions(oTarget:GetPosition(), oUnit:GetPosition())
            iAngleFromStartToAA = M27Utilities.GetAngleFromAToB(tStartPoint, oUnit:GetPosition())
            iAARange = M27UnitInfo.GetUnitAARange(oUnit) + (iRangeBuffer or 15)
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': considering AA unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; iDistFromStartToAA=' .. iDistFromStartToAA .. '; iDistFromTargetToAA=' .. iDistFromTargetToAA .. '; iAngleFromStartToAA=' .. iAngleFromStartToAA .. '; iAARange=' .. iAARange .. '; Is AA in range=' .. tostring(M27Utilities.IsLineFromAToBInRangeOfCircleAtC(iDistFromStartToTarget, iDistFromStartToAA, iDistFromTargetToAA, iAngleFromStartToTarget, iAngleFromStartToAA, iAARange)))
            end
            --IsLineFromAToBInRangeOfCircleAtC(iDistFromAToB, iDistFromAToC, iDistFromBToC, iAngleFromAToB, iAngleFromAToC, iCircleRadius)
            --E.g. if TML is at point A, target is at point B, and TMD is at point C, does the TMD block the TML in a straight line?
            if M27Utilities.IsLineFromAToBInRangeOfCircleAtC(iDistFromStartToTarget, iDistFromStartToAA, iDistFromTargetToAA, iAngleFromStartToTarget, iAngleFromStartToAA, iAARange) then
                table.insert(tRelevantAA, oUnit)
            end
        end
    end
    return tRelevantAA
end

function AirBomberManager(aiBrain)
    --v30 - replaced old approach which would determine a shortlist for use by all bombers; new approach will break things up by bomber tech level
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AirBomberManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --if aiBrain[refiPreviousAvailableBombers] >= 10 and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and GetGameTimeSeconds() >= 780 then bDebugMessages = true end

    --if GetGameTimeSeconds() >= 1560 then bDebugMessages = true end

    DetermineBomberDefenceRange(aiBrain) --Updates aiBrain[refiBomberDefenceModDistance]
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code for aiBrain=' .. aiBrain.Nickname .. ' Index=' .. aiBrain:GetArmyIndex() .. '; have determined bomber defence range=' .. aiBrain[refiBomberDefenceModDistance] .. '; is table of available bombers empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftAvailableBombers])) .. '; Distance cap=' .. aiBrain[refiBomberDefenceDistanceCap] .. '; Critical dist=' .. aiBrain[refiBomberDefenceCriticalThreatDistance]..'; GameTime='..GetGameTimeSeconds())
    end

    if M27Utilities.IsTableEmpty(aiBrain[reftAvailableBombers]) == false then
        --Have bombers to assign; assign by tech
        local tBombersOfTechLevel
        local tPotentialTargets
        local iTargetCount
        local iMaxPossibleRange = aiBrain[refiBomberDefenceModDistance] * 2 --Very rough figure - better than nothing
        local iCurPriority
        local iAvailableBombers
        local tBasePosition
        local iHighestPriorityFound
        local tStartPoint = {M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][2], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]}
        local tEnemyAA

        local iNearestCruiserModDistance = 10000
        local iCurModDistance
        local iCurActualDistance
        local bAvoidCruisers = false
        local tEnemyCruisers = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryCruiserCarrier, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iMaxPossibleRange, 'Enemy')
        local tAllRecentlySeenCruisers = {}

        local bConsiderAvoidingTeleporters = false
        if bTeleportersInGame then
            --Do we have 3+ Gunships of a suitable category?
            local iSuitableGunships = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryNoFriendlyFireGunships)
            if iSuitableGunships >= 3 then
                --Do we have T3 arti, or SMD with enemy having nuke, or experimental structure?
                if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers]) == false or aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryExperimentalStructure + M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategorySML) > 0 then
                    bConsiderAvoidingTeleporters = true

                end
            end
        end
        --Include recently seen cruisers in this
        --Add any pond AA recently seen but not currently visible to this
        if bDebugMessages == true then LOG(sFunctionRef..': Is table of enemy untis by pond empty='..tostring(M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond]))) end
        if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond]) == false then
            for iPond, tEnemyUnits in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond] do
                if bDebugMessages == true then LOG(sFunctionRef..': Considering iPond='..iPond..'; is table of enemy units empty for this='..tostring(M27Utilities.IsTableEmpty(tEnemyUnits))) end
                if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                    local tEnemyT2PlusNavalAA = EntityCategoryFilterDown(M27UnitInfo.refCategoryCruiserCarrier, M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond][iPond])
                    if bDebugMessages == true then LOG(sFunctionRef..': Is table of cruisers and carriers empty='..tostring(M27Utilities.IsTableEmpty(tEnemyT2PlusNavalAA))) end
                    if M27Utilities.IsTableEmpty(tEnemyT2PlusNavalAA) == false then
                        for iUnit, oUnit in tEnemyT2PlusNavalAA do
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering enemy unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Is valid='..tostring(M27UnitInfo.IsUnitValid(oUnit))..'; Is last known position empty='..tostring(M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftLastKnownPosition]))..'; Can see unit='..tostring(M27Utilities.CanSeeUnit(aiBrain, oUnit, true))) end
                            if M27UnitInfo.IsUnitValid(oUnit) and M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftLastKnownPosition]) == false and not(M27Utilities.CanSeeUnit(aiBrain, oUnit, true)) then
                                if bDebugMessages == true then LOG(sFunctionRef..': About to add naval unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to AA threats') end
                                table.insert( tAllRecentlySeenCruisers, oUnit)
                                table.insert(tEnemyCruisers, oUnit)
                            end
                        end
                    end
                end
            end
        end

        --Refresh table of dangerous AA
        local bCheckForDangerousAA = false
        --local bCheckForDangerousStratBomberAA = false
        --local tDangerousT3OnlyAA
        if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyAAToAvoid]) == false then

            local bKeepChecking = true
            while bKeepChecking do
                bKeepChecking = false
                if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyAAToAvoid]) == false then
                    for iUnit, oUnit in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyAAToAvoid] do
                        if not(M27UnitInfo.IsUnitValid(oUnit)) then
                            table.remove(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyAAToAvoid], iUnit)
                        end
                    end
                end
            end
            if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyAAToAvoid]) == false then
                bCheckForDangerousAA = true
                --[[tDangerousT3OnlyAA = EntityCategoryFilterDown(categories.TECH3, M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyAAToAvoid])
                if M27Utilities.IsTableEmpty(tDangerousT3OnlyAA) == false then
                    bCheckForDangerousStratBomberAA = true
                end--]]
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Finished checking for dangerous AA. bCheckForDangerousAA='..tostring(bCheckForDangerousAA)) end

        if M27Utilities.IsTableEmpty(tEnemyCruisers) == false then
            aiBrain[refbEnemyHasHadCruisersOrT3AA] = true
            for iUnit, oUnit in tEnemyCruisers do
                iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition())
                if iCurModDistance <= iNearestCruiserModDistance then
                    iNearestCruiserModDistance = iCurModDistance
                end
            end
        end
        if iNearestCruiserModDistance >= aiBrain[refiBomberDefenceModDistance] + 30 or not (aiBrain[M27Overseer.refbT2NavyNearOurBase]) then
            bAvoidCruisers = true
        end

        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyProtectACU then
            tBasePosition = M27Utilities.GetACU(aiBrain):GetPosition()
        else
            tBasePosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        end
        local tbConsideredTargetsByTech = { [1] = false, [2] = false, [3] = false, [4] = false }

        local iAssumedAOE = 1

        function TargetUnit(oTarget, oBomber, iPriority, iExpectedMaxHealth)
            TrackBomberTarget(oBomber, oTarget, iPriority)
            --Does our bomber have good aoe and is targetting a structure?
            TellBomberToAttackTarget(oBomber, oTarget, true)
            oBomber[refiShieldIgnoreValue] = iExpectedMaxHealth
            tBombersOfTechLevel[iAvailableBombers] = nil
            iAvailableBombers = iAvailableBombers - 1
        end

        function AddUnitToShortlist(oUnit, iTechLevel, iOptionalModDistanceToBase, iOptionalMaxStrikeDamageWanted)
            --Optional values - done for performance reasons, so can copy existing entry and feed them back to this function instead of recalculating
            --First make sure we want to add to the shortlist subject to strike damage (which this will consider) and special anti-teleport logic (to stop enemy teleporting into a high value unit of ours)
            oUnit[refiMaxStrikeDamageWanted] = (iOptionalMaxStrikeDamageWanted or GetMaxStrikeDamageWanted(oUnit))
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Will add oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' to shortlist unless we have assigned enough strike damage.  oUnit[refiMaxStrikeDamageWanted]=' .. (oUnit[refiMaxStrikeDamageWanted] or 0) .. '; oUnit[refiStrikeDamageAssigned]=' .. (oUnit[refiStrikeDamageAssigned] or 0))
            end

            if oUnit[refiStrikeDamageAssigned] < oUnit[refiMaxStrikeDamageWanted] or EntityCategoryContains(categories.COMMAND + categories.EXPERIMENTAL + M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategorySML, oUnit.UnitId) then
                --Is the target underwater so much that aoe wont hurt it?
                local tTargetPosition = oUnit:GetPosition()
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': oUnit position=' .. repru(tTargetPosition) .. '; iAssumedAOE=' .. iAssumedAOE .. '; SizeY=' .. (oUnit:GetBlueprint().SizeY or 0) .. '; Underwater height=' .. M27MapInfo.iMapWaterHeight)
                end
                if not (M27MapInfo.IsUnderwater({ tTargetPosition[1], tTargetPosition[2] + math.max(0, iAssumedAOE + (oUnit:GetBlueprint().SizeY or 0) - 0.1), tTargetPosition[3] }, false)) then
                    --Is this a teleporting unit that is by high value friendly units when we want to deal with non-aoe means?
                    if not(bConsiderAvoidingTeleporters and EntityCategoryContains(categories.COMMAND + categories.SUBCOMMANDER, oUnit.UnitId) and oUnit.HasEnhancement and oUnit:HasEnhancement('Teleporter') and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryExperimentalStructure + M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategorySML + M27UnitInfo.refCategorySMD, oUnit:GetPosition(), 10, 'Ally')) == false) then
                        --This is a duplication in part of checks done in most of hte bomber targeting, but not all of them have an underwater check and this one is more accurate
                        iTargetCount = iTargetCount + 1
                        aiBrain[reftBomberShortlistByTech][iTechLevel][iTargetCount] = {}
                        aiBrain[reftBomberShortlistByTech][iTechLevel][iTargetCount][refiShortlistPriority] = iCurPriority
                        aiBrain[reftBomberShortlistByTech][iTechLevel][iTargetCount][refiShortlistUnit] = oUnit
                        --Increase the mod distance based on the priority so we effectively only consider highest priority first
                        oUnit[refiBomberDefenceModDistance] = (iOptionalModDistanceToBase or M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false)) + iCurPriority * 10000
                        aiBrain[reftBomberShortlistByTech][iTechLevel][iTargetCount][refiBomberDefenceModDistance] = oUnit[refiBomberDefenceModDistance]
                        aiBrain[reftBomberShortlistByTech][iTechLevel][iTargetCount][refiShortlistStrikeDamageWanted] = oUnit[refiMaxStrikeDamageWanted]
                        iHighestPriorityFound = math.min(iHighestPriorityFound, iCurPriority)
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Added unit to the shortlist as it isnt underwater')
                            --if EntityCategoryContains(categories.COMMAND, oUnit.UnitId) then M27Utilities.ErrorHandler('Audit trail') end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Dealing with a teleporting unit so will avoid targeting') end
                    end
                end
            elseif bDebugMessages == true then
                LOG(sFunctionRef .. ': Already assigned enough strike damage')
            end
        end

        aiBrain[reftBomberShortlistByTech] = {}

        local tT1AreasToAvoidSubtables
        local iT1AreasToAvoidCount = 0
        local refiSubtableLocation = 1
        local refiSubtableAngle = 2
        local refiSubtableDistanceFromBase = 3
        local bTargetNearAreaToAvoid
        local sPathing = M27UnitInfo.refPathingTypeAmphibious
        local iBasePathingGroup = M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])

        local tAllEnemyAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Enemy')
        if M27Utilities.IsTableEmpty(tAllRecentlySeenCruisers) == false then
            for iUnit, oUnit in tAllRecentlySeenCruisers do
                table.insert(tAllEnemyAA, oUnit)
            end
        end

        local tEnemyAAAndCruisers = nil
        local tEnemySAMsAndCruisers = nil

        if M27Utilities.IsTableEmpty(tAllEnemyAA) == false then
            local iT3AAAndCruisersCat = M27UnitInfo.refCategoryGroundAA * categories.TECH3 + M27UnitInfo.refCategoryCruiser --(aircraft carriers already included in groundAA)
            tEnemyAAAndCruisers = EntityCategoryFilterDown(iT3AAAndCruisersCat, tAllEnemyAA)
            if M27Utilities.IsTableEmpty(tEnemyAAAndCruisers) == false then
                tEnemySAMsAndCruisers = EntityCategoryFilterDown(M27UnitInfo.refCategoryStructureAA * categories.TECH3 + M27UnitInfo.refCategoryCruiser, tEnemyAAAndCruisers)
                aiBrain[refbEnemyHasHadCruisersOrT3AA] = true
                if not(M27Chat.tiM27VoiceTauntByType['LotsOfAA']) then
                    if M27Utilities.IsTableEmpty(tEnemyAAAndCruisers) == false and table.getn(tEnemyAAAndCruisers) >= 10 + 7 * M27Overseer.iPlayersAtGameStart then
                        --Get the player with the most AA
                        local toBrainByIndex = {}
                        local tiCountByIndex = {}
                        local iCurIndex
                        local iMostAACount = 0
                        for iUnit, oUnit in tEnemyAAAndCruisers do
                            iCurIndex = oUnit:GetAIBrain():GetArmyIndex()
                            if not(tiCountByIndex[iCurIndex]) then
                                tiCountByIndex[iCurIndex] = 0
                                toBrainByIndex[iCurIndex] = oUnit:GetAIBrain()
                            end
                            tiCountByIndex[iCurIndex] = tiCountByIndex[iCurIndex] + 1
                        end
                        local oMostAABrain
                        for iIndex, iTotalCount in tiCountByIndex do
                            if iTotalCount > iMostAACount then
                                iMostAACount = iTotalCount
                                oMostAABrain = toBrainByIndex[iIndex]
                            end
                        end
                        local sEnemyName
                        if oMostAABrain and oMostAABrain.Nickname then sEnemyName = oMostAABrain.Nickname
                        else sEnemyName = 'commander'
                        end

                        local sMessage
                        local iRandom = math.random(1, 3)
                        if iRandom <= 2 then
                            sMessage = 'That\'s a lot of anti-air '..sEnemyName..'.  Think it\'ll be enough to calm the fear?', 0, 10000
                        elseif iRandom == 3 then
                            sMessage = 'Scared of air much '..sEnemyName..'?'
                        end

                        M27Chat.SendMessage(aiBrain, 'LotsOfAA', sMessage, 0, 10000)
                    end
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Size of tEnemyAAAndCruisers='..table.getn(tEnemyAAAndCruisers)..'; will list out each unit in here')
                    for iUnit, oUnit in tEnemyAAAndCruisers do
                        LOG(sFunctionRef..': Unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit))
                    end
                end
            end

            --Record closest enemy dangerous AA to our base (used for AirAA manager - putting here helps for performance but means it's less accurate if we dont have available bombers for a while)
            if M27Utilities.IsTableEmpty(tAllEnemyAA) == false then
                local iAACategoryToConsider

                if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] >= 3 then
                    iAACategoryToConsider = M27UnitInfo.refCategoryCruiser + M27UnitInfo.refCategoryGroundAA * categories.TECH3
                elseif aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 2 then
                    iAACategoryToConsider = M27UnitInfo.refCategoryGroundAA - categories.TECH1
                else
                    iAACategoryToConsider = M27UnitInfo.refCategoryGroundAA
                end
                local tClosestEnemyAA = EntityCategoryFilterDown(iAACategoryToConsider, tAllEnemyAA)

                if M27Utilities.IsTableEmpty(tClosestEnemyAA) == false then
                    local oClosestEnemyAA = M27Utilities.GetNearestUnit(tClosestEnemyAA, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                    local iRangeAdjust = M27UnitInfo.GetUnitAARange(oClosestEnemyAA) + 20 --If changing here also change in recordavailableandlowfuelairunits

                    aiBrain[refiClosestEnemyDangerousAADistToOurBase] = math.min(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase], M27Utilities.GetDistanceBetweenPositions(oClosestEnemyAA:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) - iRangeAdjust)
                else
                    aiBrain[refiClosestEnemyDangerousAADistToOurBase] = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]
                end
            end


        end
        if bCheckForDangerousAA then
            for iUnit, oUnit in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyAAToAvoid] do
                --Add to AA table (even if already there - just means will be extra cautious of it)
                table.insert(tEnemySAMsAndCruisers, oUnit)
                table.insert(tEnemyAAAndCruisers, oUnit)
            end
        end

        local iIntelBasedLimit = math.max(aiBrain[refiBomberDefenceCriticalThreatDistance] + 50, aiBrain[refiBomberDefenceModDistance] * 0.75, 150, M27Logic.GetIntelCoverageOfPosition(aiBrain, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], nil, true))
        if aiBrain[refbHaveAirControl] then iIntelBasedLimit = iIntelBasedLimit * 1.5 end
        iIntelBasedLimit = math.min(iIntelBasedLimit, aiBrain[refiMaxScoutRadius])
        local iT3DefensiveLimit
        if aiBrain[refbHaveAirControl] then iT3DefensiveLimit = iMaxPossibleRange
        elseif aiBrain[refbFarBehindOnAir] then iT3DefensiveLimit = math.min(iMaxPossibleRange, math.max(iIntelBasedLimit, 200))
        else iT3DefensiveLimit = math.min(iMaxPossibleRange, math.max(iIntelBasedLimit, 300))
        end
        if bDebugMessages == true then LOG(sFunctionRef..': iIntelBasedLimit='..iIntelBasedLimit..'; Intel coverage of start position='..M27Logic.GetIntelCoverageOfPosition(aiBrain, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], nil, true)..'; iT3DefensiveLimit='..iT3DefensiveLimit) end




        for iTechLevel = 1, 4 do

            if iTechLevel >= 3 then
                if iTechLevel >= 4 or (iTechLevel == 3 and aiBrain[M27Overseer.refbT2NavyNearOurBase]) then
                    bAvoidCruisers = false
                end
            end

            iHighestPriorityFound = 1000
            iCurPriority = 1
            tBombersOfTechLevel = EntityCategoryFilterDown(M27UnitInfo.ConvertTechLevelToCategory(iTechLevel), aiBrain[reftAvailableBombers])
            aiBrain[reftBomberShortlistByTech][iTechLevel] = {}
            iTargetCount = 0

            iAvailableBombers = 0
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Is table of bombers of iTechLevel=' .. iTechLevel .. ' empty=' .. tostring(M27Utilities.IsTableEmpty(tBombersOfTechLevel)) .. '; cur strategy=' .. aiBrain[M27Overseer.refiAIBrainCurrentStrategy] .. '; GameTime=' .. GetGameTimeSeconds() .. '; iMaxPossibleRange for bomber defence=' .. iMaxPossibleRange)
            end
            if M27Utilities.IsTableEmpty(tBombersOfTechLevel) == false then
                iAvailableBombers = table.getn(tBombersOfTechLevel)
                iAssumedAOE = M27UnitInfo.GetBomberAOEAndStrikeDamage(tBombersOfTechLevel[1])
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iAvailableBombers=' .. iAvailableBombers .. '; strategy=' .. aiBrain[M27Overseer.refiAIBrainCurrentStrategy])
                end
                --Are we in protect ACU mode?
                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyProtectACU and iTechLevel < 4 then
                    bAvoidCruisers = false
                    tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand - M27UnitInfo.refCategoryEngineer + M27UnitInfo.refCategoryNavalSurface, tBasePosition, 90, 'Enemy')
                    for iUnit, oUnit in tPotentialTargets do
                        --if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                        --Dont add if it's under fixed shield and isnt in range of ACU

                        iCurModDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tBasePosition)
                        if iCurModDistance <= 30 or (EntityCategoryContains(categories.DIRECTFIRE + categories.INDIRECTFIRE * categories.TECH1, oUnit.UnitId) and iCurModDistance <= M27UnitInfo.GetUnitMaxGroundRange(oUnit)) or not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 1500, false, true, false, false)) then
                            AddUnitToShortlist(oUnit, iTechLevel, iCurModDistance)
                        end
                        --end
                    end
                    --Are we in kill ACU mode? Then target ACU unless its underwater (but allow ahwassa to target if it is underwater)
                elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoACUKillTarget]) and (not (M27UnitInfo.IsUnitUnderwater(aiBrain[M27Overseer.refoACUKillTarget])) or (iTechLevel == 4 and not (M27MapInfo.IsUnderwater({ aiBrain[M27Overseer.refoACUKillTarget]:GetPosition()[1], aiBrain[M27Overseer.refoACUKillTarget]:GetPosition()[2] + 18, aiBrain[M27Overseer.refoACUKillTarget]:GetPosition()[3] }, false)))) then
                    --Add any nearby AA structures if enemy ACU has relatively highi health and are dealing with T2 or lower
                    iCurPriority = 1
                    local bTargetDownAA = false
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': In ACU kill mode.  iTechLevel=' .. iTechLevel .. '; Enemy ACU health=' .. aiBrain[M27Overseer.refoACUKillTarget]:GetHealth())
                    end
                    if iTechLevel <= 2 and aiBrain[M27Overseer.refoACUKillTarget]:GetHealth() >= 2500 then
                        --Target only structureAA if have <=4 t1 bombers, and all AA if have >=5 bombers
                        if iAvailableBombers <= 5 then
                            tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructureAA, aiBrain[M27Overseer.refoACUKillTarget]:GetPosition(), 60, 'Enemy')
                        else
                            tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructureAA + M27UnitInfo.refCategoryMAA, aiBrain[M27Overseer.refoACUKillTarget]:GetPosition(), 60, 'Enemy')
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Is table of enemy AA structures around ACU empty=' .. tostring(M27Utilities.IsTableEmpty(tPotentialTargets)))
                        end

                        if M27Utilities.IsTableEmpty(tPotentialTargets) == false then
                            bTargetDownAA = true
                            if table.getn(tPotentialTargets) >= 2 or iAvailableBombers > 5 then
                                --If only 1 AA structure we can probably take it down with bombers
                                for iUnit, oUnit in tPotentialTargets do
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Considering unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; fraction complete=' .. oUnit:GetFractionComplete() .. '; Health percent=' .. M27UnitInfo.GetUnitHealthPercent(oUnit))
                                    end
                                    if oUnit:GetFractionComplete() >= 1 and M27UnitInfo.GetUnitHealthPercent(oUnit) >= 0.5 then
                                        bTargetDownAA = false
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Enemy has completed AA structure so will just try and kill the enemy ACU instead of targeting down AA')
                                        end
                                        break
                                    end
                                end
                            end
                            if bTargetDownAA then
                                for iUnit, oUnit in tPotentialTargets do
                                    AddUnitToShortlist(aiBrain[M27Overseer.refoACUKillTarget], iTechLevel, 0)
                                end
                            end
                        end
                    end
                    if bTargetDownAA then
                        iCurPriority = 2
                    end
                    AddUnitToShortlist(aiBrain[M27Overseer.refoLastNearestACU], iTechLevel, 0)
                else
                    tbConsideredTargetsByTech[iTechLevel] = true
                    --Air domination - consider all enemy ground AA and shields
                    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                        iCurPriority = 1
                        local iCategoryToSearch = M27UnitInfo.refCategoryGroundAA
                        if iTechLevel == 4 then
                            iCategoryToSearch = iCategoryToSearch * categories.TECH3
                        end

                        tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA + M27UnitInfo.refCategoryFixedShield, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Enemy')
                        for iUnit, oUnit in tPotentialTargets do
                            if not (oUnit:IsUnitState('Attached')) then
                                iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false)
                                if not (bAvoidCruisers) or iCurModDistance < iNearestCruiserModDistance - 30 then
                                    --if iCurModDistance <= aiBrain[refiBomberDefenceModDistance] then
                                    AddUnitToShortlist(oUnit, iTechLevel, iCurModDistance)
                                    --end
                                end
                            end
                        end
                        if iTechLevel >= 3 and M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoLastNearestACU]) and M27Utilities.CanSeeUnit(aiBrain, aiBrain[M27Overseer.refoLastNearestACU], true) and not (M27UnitInfo.IsUnitUnderwater(aiBrain[M27Overseer.refoLastNearestACU])) then
                            AddUnitToShortlist(aiBrain[M27Overseer.refoLastNearestACU], iTechLevel)
                        end
                    end

                    --Tech 1 and 2: Consider nearby targets
                    if iTechLevel == 1 or (iTechLevel == 2 and not (tbConsideredTargetsByTech[1])) then
                        --Shortlist for T1 bombers - nearby enemies
                        iCurPriority = 1

                        function ConsiderAddingUnitsNearMexesToShortlist(oBrain, iModDistanceCap)
                            if oBrain[M27Overseer.refbGroundCombatEnemyNearBuilding] then
                                for iThreatGroupCount, sThreatGroupRef in oBrain[M27Overseer.reftEnemyGroupsThreateningBuildings] do
                                    if bDebugMessages == true then LOG(sFunctionRef..': Considering threat group '..iThreatGroupCount..'-'..sThreatGroupRef..'; Is table of details for this threat group empty='..tostring(M27Utilities.IsTableEmpty(oBrain[M27Overseer.reftEnemyThreatGroup][sThreatGroupRef]))) end
                                    if M27Utilities.IsTableEmpty(oBrain[M27Overseer.reftEnemyThreatGroup][sThreatGroupRef]) == false then
                                        for iUnit, oUnit in oBrain[M27Overseer.reftEnemyThreatGroup][sThreatGroupRef][M27Overseer.refoEnemyGroupUnits] do
                                            if M27UnitInfo.IsUnitValid(oUnit) then
                                                iCurModDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                                if bDebugMessages == true then LOG(sFunctionRef..': Unit threatening mex='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iCurModDistance='..iCurModDistance) end
                                                if iCurModDistance < iModDistanceCap and (iCurModDistance < (aiBrain[refiBomberDefenceModDistance] + 30) or not (IsTargetCoveredByAA(oUnit, tAllEnemyAA, 1, M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber], false))) then
                                                    if not (M27Logic.IsTargetUnderShield(oBrain, oUnit, 0, false, false, true)) then
                                                        if EntityCategoryContains(M27UnitInfo.refCategoryMAA, oUnit.UnitId) then
                                                            iCurPriority = 1
                                                        else
                                                            iCurPriority = 2
                                                        end
                                                        if not(bCheckForDangerousAA) or iCurModDistance <= aiBrain[refiBomberDefenceCriticalThreatDistance] + 25 or not (IsTargetCoveredByAA(oUnit, M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyAAToAvoid], 4, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], false)) then
                                                            --if not (IsTargetCoveredByAA(oUnit, tAllEnemyAA, 1, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], false)) then
                                                            AddUnitToShortlist(oUnit, iTechLevel, iCurModDistance)
                                                        end
                                                        --end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        --First target enemies that can hurt mexes and are near mexes we own, regardless of whether hteyre shielded or protected by AA (unless theyre protected by AA that has killed lots of our units)
                        if bDebugMessages == true then LOG(sFunctionRef..': Checking if any enemies threatening our mexes that have a threat group for. aiBrain[M27Overseer.refbGroundCombatEnemyNearBuilding]='..tostring(aiBrain[M27Overseer.refbGroundCombatEnemyNearBuilding])) end
                        ConsiderAddingUnitsNearMexesToShortlist(aiBrain, aiBrain[refiBomberDefenceModDistance] + 300)

                        --Consider nearest enemy experimental and if it is near a friendly experimental level structure
                        if M27Conditions.HaveApproachingLandExperimentalThreat(aiBrain) then
                            if M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.refoNearestRangeAdjustedLandExperimental]:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 500 and not(M27UnitInfo.IsUnitUnderwater(aiBrain[M27Overseer.refoNearestRangeAdjustedLandExperimental])) then
                                local tNearbyExperimentalLevelBuildings = aiBrain:GetUnitsAroundPoint(categories.COMMAND + M27UnitInfo.refCategoryExperimentalLevel * categories.STRUCTURE, aiBrain[M27Overseer.refoNearestRangeAdjustedLandExperimental]:GetPosition(), M27UnitInfo.GetNavalDirectAndSubRange(aiBrain[M27Overseer.refoNearestRangeAdjustedLandExperimental]) + 40, 'Ally')
                                if M27Utilities.IsTableEmpty(tNearbyExperimentalLevelBuildings) == false then
                                    for iPriorityAllyUnit, oPriorityAllyUnit in tNearbyExperimentalLevelBuildings do
                                        if oPriorityAllyUnit:GetAIBrain().M27Subteam == aiBrain.M27Subteam then

                                            iCurPriority = 1
                                            iCurModDistance = M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.refoNearestRangeAdjustedLandExperimental]:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                            --if not(aiBrain == oPriorityAllyUnit:GetAIBrain()) then bDebugMessages = true end
                                            AddUnitToShortlist(aiBrain[M27Overseer.refoNearestRangeAdjustedLandExperimental], iTechLevel, iCurModDistance)
                                            if bDebugMessages == true then LOG(sFunctionRef..': Want to defend subteammate building that is under threat from experimental '..aiBrain[M27Overseer.refoNearestRangeAdjustedLandExperimental].UnitId..M27UnitInfo.GetUnitLifetimeCount(aiBrain[M27Overseer.refoNearestRangeAdjustedLandExperimental])) end
                                            break
                                        end
                                    end
                                end
                            end
                        end

                        --Prioritise AA and vulnerable indirect fire units (will only consider structure based AA threats if part-complete)
                        --T2 bombers will use the exact same logic
                        iCurPriority = 1
                        if aiBrain[M27Overseer.refbGroundCombatEnemyNearBuilding] then
                            iCurPriority = 3
                        end

                        --If we have subteammates with no available bombers whose mexes are under attack and we have at least 5 available bombers then consider helping them
                        if iAvailableBombers >= 5 then
                            for iBrain, oBrain in M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subreftoFriendlyBrains] do
                                if not(oBrain.M27IsDefeated) and not(oBrain == aiBrain) and oBrain[M27Overseer.refbGroundCombatEnemyNearBuilding] and oBrain[refiPreviousAvailableBombers] < 5 then
                                    ConsiderAddingUnitsNearMexesToShortlist(oBrain, aiBrain[refiBomberDefenceModDistance] + 200)
                                end
                            end
                        end


                        tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMAA + M27UnitInfo.refCategoryStructureAA + M27UnitInfo.refCategoryIndirectT2Plus + M27UnitInfo.refCategorySniperBot - M27UnitInfo.refCategoryCruiserCarrier, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iMaxPossibleRange, 'Enemy')
                        if M27Utilities.IsTableEmpty(tPotentialTargets) == false then
                            if iTechLevel == 1 and iAvailableBombers > 0 then
                                --Generate list of locations to avoid for T1 bombers (will have already reduced emergency def range for shielded T2 flak and T3 AA)

                                --Dont want to avoid T3 MAA since T1 bombers do ok against them
                                local tAAForT1BombersToAvoid = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH2 + M27UnitInfo.refCategoryStructureAA + M27UnitInfo.refCategoryCruiserCarrier, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iMaxPossibleRange, 'Enemy')
                                if bCheckForDangerousAA then
                                    for iUnit, oUnit in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyAAToAvoid] do
                                        if bDebugMessages == true then LOG(sFunctionRef..': Adding dangerous AA unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to table of AA for T1 bombers to avoid') end
                                        table.insert(tAAForT1BombersToAvoid, oUnit)
                                    end
                                end
                                --Add unseen cruisers
                                if M27Utilities.IsTableEmpty(tAllRecentlySeenCruisers) == false then
                                    for iCruiser, oCruiser in tAllRecentlySeenCruisers do
                                        table.insert(tAAForT1BombersToAvoid, oCruiser)
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': T1 bomber targeting - is table of tAAForT1BombersToAvoid empty='..tostring( M27Utilities.IsTableEmpty(tAAForT1BombersToAvoid))) end

                                if M27Utilities.IsTableEmpty(tAAForT1BombersToAvoid) == false then
                                    tT1AreasToAvoidSubtables = {}
                                    local tNearbyLandCombat
                                    local iNearbyLandCombatMass
                                    local tNearbyAA, iNearbyAAMass, iDistFromBase
                                    for iUnit, oUnit in tAAForT1BombersToAvoid do
                                        if (M27UnitInfo.GetUnitHealthPercent(oUnit) >= 0.5 or oUnit[M27UnitInfo.refbIsDangerousAA] or EntityCategoryContains(categories.TECH3 + categories.TECH2, oUnit.UnitId)) and oUnit:GetFractionComplete() >= 0.8 then
                                            iDistFromBase = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition())
                                            if iDistFromBase > aiBrain[refiBomberDefenceCriticalThreatDistance] then
                                                iNearbyLandCombatMass = 0
                                                iNearbyAAMass = 0
                                                if not(oUnit[M27UnitInfo.refbIsDangerousAA]) then
                                                    tNearbyAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, oUnit:GetPosition(), 30, 'Enemy')
                                                    if M27Utilities.IsTableEmpty(tNearbyAA) == false then
                                                        iNearbyAAMass = M27Logic.GetCombatThreatRating(aiBrain, tNearbyAA, false, nil, nil, nil, true) --Dont need to check if visible since getunitsaroundpoint already does this
                                                    end
                                                    --Is the land threat around here significantly greater than the AA threat?  For performance reasons use basic calculation
                                                    tNearbyLandCombat = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, oUnit:GetPosition(), 30, 'Enemy')
                                                    if M27Utilities.IsTableEmpty(tNearbyLandCombat) == false then
                                                        iNearbyLandCombatMass = M27Logic.GetCombatThreatRating(aiBrain, tNearbyLandCombat, false, nil, nil, nil, true) --Dont need to check if visible since getunitsaroundpoint already does this
                                                    end
                                                end
                                                if oUnit[M27UnitInfo.refbIsDangerousAA] or iNearbyAAMass > iNearbyLandCombatMass * 0.5 then
                                                    --Add unit to list of targets to avoid
                                                    iT1AreasToAvoidCount = iT1AreasToAvoidCount + 1
                                                    tT1AreasToAvoidSubtables[iT1AreasToAvoidCount] = {}
                                                    tT1AreasToAvoidSubtables[iT1AreasToAvoidCount][refiSubtableLocation] = oUnit:GetPosition()
                                                    tT1AreasToAvoidSubtables[iT1AreasToAvoidCount][refiSubtableAngle] = M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition())
                                                    tT1AreasToAvoidSubtables[iT1AreasToAvoidCount][refiSubtableDistanceFromBase] = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition())
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            for iUnit, oUnit in tPotentialTargets do
                                if not (oUnit:IsUnitState('Attached')) then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Considering potential AA or indirect high priority target. unit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; Fraction compelte=' .. oUnit:GetFractionComplete() .. '; Health%=' .. M27UnitInfo.GetUnitHealthPercent(oUnit))
                                    end
                                    if not (EntityCategoryContains(M27UnitInfo.refCategoryStructureAA, oUnit.UnitId)) or oUnit:GetFractionComplete() <= 0.8 or M27UnitInfo.GetUnitHealthPercent(oUnit) <= 0.2 then
                                        iCurActualDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                        if iCurActualDistance <= aiBrain[refiBomberDefenceDistanceCap] then
                                            iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false) + math.min(100, (oUnit[refiFailedHitCount] or 0) * 15)
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': CurPriority=' .. iCurPriority .. '; Considering whether to add unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' to shortlist; mod distance=' .. (iCurModDistance or 'nil') .. '; aiBrain[refiBomberDefenceModDistance]=' .. aiBrain[refiBomberDefenceModDistance] .. '; Actual distance to start=' .. M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) .. '; Angle from start to unit=' .. M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) .. '; Dist to enemy base=' .. aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] .. '; Angle to enemy base from start=' .. M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) .. '; Unit position=' .. repru(oUnit:GetPosition()) .. '; enemy base position=' .. repru(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)))
                                            end
                                            if iCurModDistance <= aiBrain[refiBomberDefenceModDistance] and (not (bAvoidCruisers) or iCurModDistance < iNearestCruiserModDistance - 30) then
                                                bTargetNearAreaToAvoid = false
                                                if iCurActualDistance > aiBrain[refiBomberDefenceCriticalThreatDistance] and iT1AreasToAvoidCount > 0 then
                                                    for iCount, tSubtable in tT1AreasToAvoidSubtables do
                                                        --Are we within 30 degrees?
                                                        if math.abs(M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) - tSubtable[refiSubtableAngle]) <= 30 then
                                                            if M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) - 30 >= tSubtable[refiSubtableDistanceFromBase] then
                                                                bTargetNearAreaToAvoid = true
                                                                break
                                                            end
                                                        end
                                                    end
                                                end
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': T1 bomber emergency defence: bTargetNearAreaToAvoid=' .. tostring(bTargetNearAreaToAvoid) .. '; iT1AreasToAvoidCount=' .. iT1AreasToAvoidCount .. '; tT1AreasToAvoidSubtables=' .. repru(tT1AreasToAvoidSubtables or { 'nil' }))
                                                end
                                                if not (bTargetNearAreaToAvoid) then
                                                    --Ignore targets on a plateau unless in critical threat distance
                                                    if iCurActualDistance <= aiBrain[refiBomberDefenceCriticalThreatDistance] then
                                                        AddUnitToShortlist(oUnit, iTechLevel, iCurModDistance)
                                                    else
                                                        if M27MapInfo.GetSegmentGroupOfLocation(sPathing, oUnit:GetPosition()) == iBasePathingGroup and not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, nil, nil, true, true)) then
                                                            AddUnitToShortlist(oUnit, iTechLevel, iCurModDistance)
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        --T2+ Indirect fire units near a firebase - same priority as AA
                        if M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef]) == false then
                            for iFirebaseRef, tFirebaseUnits in aiBrain[M27EngineerOverseer.reftFirebaseUnitsByFirebaseRef] do
                                if iFirebaseRef and M27Utilities.IsTableEmpty(tFirebaseUnits) == false and M27Utilities.IsTableEmpty(aiBrain[M27EngineerOverseer.reftFirebasePosition][iFirebaseRef]) == false then
                                    iCurPriority = 1
                                    if aiBrain[M27Overseer.refbGroundCombatEnemyNearBuilding] then
                                        iCurPriority = 2
                                    end
                                    tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryIndirect + M27UnitInfo.refCategorySniperBot - categories.TECH1, aiBrain[M27EngineerOverseer.reftFirebasePosition][iFirebaseRef], 110, 'Enemy')
                                    for iUnit, oUnit in tPotentialTargets do
                                        if not (oUnit:IsUnitState('Attached')) then
                                            if iCurActualDistance <= aiBrain[refiBomberDefenceCriticalThreatDistance] or not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, nil, nil, false, true)) then
                                                AddUnitToShortlist(oUnit, iTechLevel, M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), aiBrain[M27EngineerOverseer.reftFirebasePosition][iFirebaseRef]))
                                            end
                                        end
                                    end
                                end
                            end
                        end


                        --Normal combat units
                        iCurPriority = 2
                        if aiBrain[M27Overseer.refbGroundCombatEnemyNearBuilding] then
                            iCurPriority = 4
                        end
                        tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand - categories.COMMAND + M27UnitInfo.refCategorySalem, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iMaxPossibleRange, 'Enemy')
                        for iUnit, oUnit in tPotentialTargets do
                            if not (oUnit:IsUnitState('Attached')) then
                                iCurActualDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                if iCurActualDistance <= aiBrain[refiBomberDefenceDistanceCap] then
                                    iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false) + math.min(100, (oUnit[refiFailedHitCount] or 0) * 15)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': CurPriority=' .. iCurPriority .. '; Considering whether to add unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' to shortlist; mod distance=' .. (iCurModDistance or 'nil') .. '; aiBrain[refiBomberDefenceModDistance]=' .. aiBrain[refiBomberDefenceModDistance] .. '; Actual distance to start=' .. M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) .. '; Angle from start to unit=' .. M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) .. '; Dist to enemy base=' .. aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] .. '; Angle to enemy base from start=' .. M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) .. '; Unit position=' .. repru(oUnit:GetPosition()) .. '; enemy base position=' .. repru(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)))
                                    end
                                    if iCurModDistance <= aiBrain[refiBomberDefenceModDistance] and (not (bAvoidCruisers) or iCurModDistance < iNearestCruiserModDistance - 30) then
                                        bTargetNearAreaToAvoid = false
                                        if iCurActualDistance > aiBrain[refiBomberDefenceCriticalThreatDistance] and iT1AreasToAvoidCount > 0 then
                                            for iCount, tSubtable in tT1AreasToAvoidSubtables do
                                                --Are we within 30 degrees?
                                                if math.abs(M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) - tSubtable[refiSubtableAngle]) <= 30 then
                                                    if M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) - 30 >= tSubtable[refiSubtableDistanceFromBase] then
                                                        bTargetNearAreaToAvoid = true
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': T1 bomber emergency defence: bTargetNearAreaToAvoid=' .. tostring(bTargetNearAreaToAvoid) .. '; iT1AreasToAvoidCount=' .. iT1AreasToAvoidCount .. '; tT1AreasToAvoidSubtables=' .. repru(tT1AreasToAvoidSubtables or { 'nil' }))
                                        end
                                        if not (bTargetNearAreaToAvoid) then
                                            if iCurActualDistance <= aiBrain[refiBomberDefenceCriticalThreatDistance] or not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, nil, nil, true, true)) then
                                                AddUnitToShortlist(oUnit, iTechLevel, iCurModDistance)
                                            end
                                        end
                                    end
                                end
                            end
                        end



                        --ACU
                        iCurPriority = 3
                        if aiBrain[M27Overseer.refbGroundCombatEnemyNearBuilding] then
                            iCurPriority = 5
                        end
                        if M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoLastNearestACU]) then
                            if aiBrain[M27Overseer.refoLastNearestACU]:GetHealth() <= 3000 then
                                iCurPriority = iCurPriority - 1
                            end
                            iCurActualDistance = M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.refoLastNearestACU]:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                            if iCurActualDistance <= aiBrain[refiBomberDefenceDistanceCap] then
                                iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, aiBrain[M27Overseer.refoLastNearestACU]:GetPosition(), false) + math.min(75, (aiBrain[M27Overseer.refoLastNearestACU][refiFailedHitCount] or 0) * 15)
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': CurPriority=' .. iCurPriority .. '; Considering whether to add enemy ACU to bomber target. Mod distance for enemy ACU=' .. iCurModDistance .. '; aiBrain[refiBomberDefenceModDistance]=' .. aiBrain[refiBomberDefenceModDistance] .. '; aiBrain[M27Overseer.refoLastNearestACU][refiFailedHitCount]=' .. (aiBrain[M27Overseer.refoLastNearestACU][refiFailedHitCount] or 0))
                                end
                                if iCurModDistance <= aiBrain[refiBomberDefenceModDistance] and (not (bAvoidCruisers) or iCurModDistance < iNearestCruiserModDistance - 30) then
                                    bTargetNearAreaToAvoid = false
                                    if iCurActualDistance > aiBrain[refiBomberDefenceCriticalThreatDistance] and iT1AreasToAvoidCount > 0 then
                                        for iCount, tSubtable in tT1AreasToAvoidSubtables do
                                            --Are we within 30 degrees?
                                            if math.abs(M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.refoLastNearestACU]:GetPosition()) - tSubtable[refiSubtableAngle]) <= 30 then
                                                if M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.refoLastNearestACU]:GetPosition()) - 30 >= tSubtable[refiSubtableDistanceFromBase] then
                                                    bTargetNearAreaToAvoid = true
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': T1 bomber emergency defence: bTargetNearAreaToAvoid=' .. tostring(bTargetNearAreaToAvoid) .. '; iT1AreasToAvoidCount=' .. iT1AreasToAvoidCount .. '; tT1AreasToAvoidSubtables=' .. repru(tT1AreasToAvoidSubtables or { 'nil' }))
                                    end
                                    if not (bTargetNearAreaToAvoid) then
                                        if iCurActualDistance <= aiBrain[refiBomberDefenceCriticalThreatDistance] or not (M27Logic.IsTargetUnderShield(aiBrain, aiBrain[M27Overseer.refoLastNearestACU], nil, nil, true, true)) then
                                            AddUnitToShortlist(aiBrain[M27Overseer.refoLastNearestACU], iTechLevel, iCurModDistance)
                                        end
                                    end
                                end
                            end
                        end

                        --All non-T2+ AA structures within emergency defence range - 20 that arent protected by AA
                        iCurPriority = 4
                        if aiBrain[M27Overseer.refbGroundCombatEnemyNearBuilding] then
                            iCurPriority = 6
                        end
                        tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure - M27UnitInfo.refCategoryStructureAA * categories.TECH2 - M27UnitInfo.refCategoryStructureAA * categories.TECH3, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iMaxPossibleRange - 20, 'Enemy')
                        for iUnit, oUnit in tPotentialTargets do
                            if not (oUnit:IsUnitState('Attached')) then
                                iCurActualDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                if iCurActualDistance <= aiBrain[refiBomberDefenceDistanceCap] then
                                    iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false) + math.min(100, (oUnit[refiFailedHitCount] or 0) * 15)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': CurPriority=' .. iCurPriority .. '; Considering whether to add unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' to shortlist; mod distance=' .. (iCurModDistance or 'nil') .. '; aiBrain[refiBomberDefenceModDistance]=' .. aiBrain[refiBomberDefenceModDistance] .. '; Actual distance to start=' .. M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) .. '; Angle from start to unit=' .. M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) .. '; Dist to enemy base=' .. aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] .. '; Angle to enemy base from start=' .. M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) .. '; Unit position=' .. repru(oUnit:GetPosition()) .. '; enemy base position=' .. repru(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)))
                                    end
                                    if iCurModDistance <= aiBrain[refiBomberDefenceModDistance] and (not (bAvoidCruisers) or iCurModDistance < iNearestCruiserModDistance - 30) then
                                        bTargetNearAreaToAvoid = false
                                        if iCurActualDistance > aiBrain[refiBomberDefenceCriticalThreatDistance] and iT1AreasToAvoidCount > 0 then
                                            for iCount, tSubtable in tT1AreasToAvoidSubtables do
                                                --Are we within 30 degrees?
                                                if math.abs(M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) - tSubtable[refiSubtableAngle]) <= 30 then
                                                    if M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) - 30 >= tSubtable[refiSubtableDistanceFromBase] then
                                                        bTargetNearAreaToAvoid = true
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': T1 bomber emergency defence - AA buildings: bTargetNearAreaToAvoid=' .. tostring(bTargetNearAreaToAvoid) .. '; iT1AreasToAvoidCount=' .. iT1AreasToAvoidCount .. '; tT1AreasToAvoidSubtables=' .. repru(tT1AreasToAvoidSubtables or { 'nil' }) .. '; Is target position ' .. repru(oUnit:GetPosition()) .. ' covered by AA=' .. tostring(IsTargetPositionCoveredByAA(oUnit:GetPosition(), tAllEnemyAA, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], false, 0.8)))
                                        end

                                        if not (bTargetNearAreaToAvoid) then
                                            if iCurActualDistance <= aiBrain[refiBomberDefenceCriticalThreatDistance] or (not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, nil, nil, true, true)) and not (IsTargetPositionCoveredByAA(oUnit:GetPosition(), tAllEnemyAA, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], false, 0.8))) then
                                                AddUnitToShortlist(oUnit, iTechLevel, iCurModDistance)
                                            elseif bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Target is either near a place to avoid, or covered by AA')
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        --Mex (if not targeted a mex for a while) for T1 bombers
                        iCurPriority = 5
                        if aiBrain[M27Overseer.refbGroundCombatEnemyNearBuilding] then
                            iCurPriority = 7
                        end
                        if iTechLevel == 1 and iTargetCount == 0 and iAvailableBombers >= 3 then
                            local bTargetMexWithT1Bombers = false
                            local tLivingT1Bombers = {}
                            local tMexStartPos
                            local iLivingBombers = 0

                            if GetGameTimeSeconds() - (aiBrain[refiTimeOfLastT1BomberMexAttack] or -100) >= 300 and (aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 or GetGameTimeSeconds() - (aiBrain[refiTimeOfLastT1BomberMexAttack] or -400) >= 400) then
                                bTargetMexWithT1Bombers = true
                            else
                                --Have we killed the last target with at least 2 of the assigned bombers still being alive?
                                if not (M27UnitInfo.IsUnitValid(aiBrain[refoT1MexTarget])) then
                                    bTargetMexWithT1Bombers = true
                                    if M27Utilities.IsTableEmpty(aiBrain[reftMexHunterT1Bombers]) then
                                        bTargetMexWithT1Bombers = false
                                    else
                                        for iUnit, oUnit in aiBrain[reftMexHunterT1Bombers] do
                                            if M27UnitInfo.IsUnitValid(oUnit) then
                                                iLivingBombers = iLivingBombers + 1
                                                tLivingT1Bombers[iLivingBombers] = oUnit
                                            end
                                        end
                                        if iLivingBombers == 0 then
                                            aiBrain[reftMexHunterT1Bombers] = {}
                                        end
                                        if iLivingBombers < 2 then
                                            bTargetMexWithT1Bombers = false
                                        end

                                    end
                                end

                            end

                            if bTargetMexWithT1Bombers then
                                if iLivingBombers >= 2 then
                                    tMexStartPos = M27Utilities.GetAveragePosition(aiBrain[reftMexHunterT1Bombers])
                                else
                                    tMexStartPos = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': It has been a while since the last mex attack so will consider targeting a mex.  aiBrain[M27Overseer.refiOurHighestAirFactoryTech]=' .. aiBrain[M27Overseer.refiOurHighestAirFactoryTech] .. '; Time since last targeted mex=' .. GetGameTimeSeconds() - (aiBrain[refiTimeOfLastT1BomberMexAttack] or 0))
                                end
                                local iClosestDistance = 100000
                                local oClosestDistance
                                --Find the mex with the lowest special distance to target, ignoring those that have already been targeted or are near the enemy ACU's last known position
                                tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT1Mex, tBasePosition, aiBrain[refiMaxScoutRadius], 'Enemy')
                                if M27Utilities.IsTableEmpty(tPotentialTargets) == false then
                                    --Want to avoid all AA (T1+)
                                    --if not(M27Logic.IsTargetUnderShield(aiBrain, oMex, 0, false, false, true)) then
                                    -- if not(IsTargetCoveredByAA(oMex, tEnemyAA, 1, tStartPoint)) then
                                    for iUnit, oUnit in tPotentialTargets do
                                        --Ignore mex if it's the last one we tried to target (since that means we failed)
                                        if not (M27UnitInfo.IsUnitUnderwater(oUnit)) and not (aiBrain[refoT1MexTarget] == oUnit) then
                                            if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), aiBrain[M27Overseer.reftLastNearestACU]) >= 50 then
                                                iCurModDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tMexStartPos) - M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) + 100 * math.max(0, (oUnit[refiFailedHitCount] or 0))
                                                if iCurModDistance < iClosestDistance and (not (bAvoidCruisers) or iCurModDistance < iNearestCruiserModDistance - 30) then
                                                    if not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)) then
                                                        if not (IsTargetCoveredByAA(oUnit, tAllEnemyAA, 1, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], false)) then
                                                            oClosestDistance = oUnit
                                                            iClosestDistance = iCurModDistance
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                if oClosestDistance then
                                    AddUnitToShortlist(oClosestDistance, iTechLevel, iClosestDistance)
                                end
                            end
                        end
                    end

                    if iTechLevel == 2 then
                        if tbConsideredTargetsByTech[1] then
                            --Add any priority 1-3 targets for T1 bombers that still need assigning to the T2 bomber shortlist
                            for iValue, tValue in aiBrain[reftBomberShortlistByTech][1] do
                                if tValue[refiShortlistPriority] <= 4 or (aiBrain[M27Overseer.refbGroundCombatEnemyNearBuilding] and tValue[refiShortlistPriority] <= 6) then
                                    iCurPriority = tValue[refiShortlistPriority]
                                    AddUnitToShortlist(tValue[refiShortlistUnit], iTechLevel, tValue[refiBomberDefenceModDistance], tValue[refiShortlistStrikeDamageWanted])
                                end
                            end
                            --note - if not considered by tech, then should have considered with above code already
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': tbConsideredTargetsByTech[1]=' .. tostring(tbConsideredTargetsByTech[1]) .. '; iTargetCount=' .. iTargetCount)
                        end
                        if iTargetCount == 0 then
                            iCurPriority = 4
                            if aiBrain[M27Overseer.refbGroundCombatEnemyNearBuilding] then
                                iCurPriority = 6
                            end
                            --Do we still have T2 bombers with LC <= 2? in which case want to try and target a nearby mex
                            local bHaveT2EarlyBombers = false
                            for iBomber, oBomber in tBombersOfTechLevel do
                                if M27UnitInfo.GetUnitLifetimeCount(oBomber) <= 2 then
                                    bHaveT2EarlyBombers = true
                                    break
                                end
                            end
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Target count is 0. bHaveT2EarlyBombers=' .. tostring(bHaveT2EarlyBombers))
                            end
                            if bHaveT2EarlyBombers then
                                --Determine a mex to add to the target list - add every vulnerable mex for every t2 bomber to target as long as our first 2 bombers are alive
                                local tEnemyT2Mex = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2Mex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Enemy')
                                if M27Utilities.IsTableEmpty(tEnemyT2Mex) == false then
                                    tStartPoint = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                                    for iMex, oMex in tEnemyT2Mex do
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Early t2 bomber logic - Considering mex ' .. oMex.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oMex) .. '; is it underwater=' .. tostring(M27UnitInfo.IsUnitUnderwater(oMex)) .. '; Is under shield=' .. tostring(M27Logic.IsTargetUnderShield(aiBrain, oMex, 0, false, false, true)) .. '; is protected by AA=' .. tostring(IsTargetCoveredByAA(oMex, tEnemyAA, 3, tStartPoint)))
                                        end
                                        if not (M27UnitInfo.IsUnitUnderwater(oMex)) then
                                            --might be quicker to duplicate this check rather than waiting until doing the shield and AA coverage checks
                                            if not (bAvoidCruisers) or M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oMex:GetPosition()) < iNearestCruiserModDistance - 30 then
                                                --Include if its unshielded with no AA on the way to it from our base (assume part-compelte shields will be built by the time we get there)
                                                if not (M27Logic.IsTargetUnderShield(aiBrain, oMex, 0, false, false, true)) then
                                                    if not (IsTargetCoveredByAA(oMex, tAllEnemyAA, 1, tStartPoint)) then
                                                        AddUnitToShortlist(oMex, iTechLevel)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Have early T2 bombers so added T2 mexes without AA coverage to the target list. iTargetCount=' .. iTargetCount)
                                end
                            end
                        end
                    elseif iTechLevel == 3 then
                        --Strat bombers - copy any T2+ nearby units for bomber defence (but ignore t1 units)
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Considering strat bomber targets.  first checking if have considered targets for T1+T2 bombers. tbConsideredTargetsByTech=' .. repru(tbConsideredTargetsByTech))
                        end
                        if tbConsideredTargetsByTech[1] and iT1AreasToAvoidCount == 0 then
                            --Add any priority 1-3 targets for T1 bombers that still need assigning to the T2 bomber shortlist
                            for iValue, tValue in aiBrain[reftBomberShortlistByTech][1] do
                                if tValue[refiShortlistPriority] <= 3 then
                                    iCurPriority = tValue[refiShortlistPriority]
                                    if not (EntityCategoryContains(categories.TECH1 + M27UnitInfo.refCategoryEngineer - categories.COMMAND, tValue[refiShortlistUnit].UnitId)) then
                                        --Adjust priorities for strat bombers: T3 AA; T2 AA; Other units
                                        if iCurPriority == 1 then
                                            if not (EntityCategoryContains(categories.TECH3, tValue[refiShortlistUnit].UnitId)) then
                                                iCurPriority = 2
                                            end
                                        elseif iCurPriority == 2 then
                                            iCurPriority = 3
                                        end
                                        AddUnitToShortlist(tValue[refiShortlistUnit], iTechLevel, tValue[refiBomberDefenceModDistance], tValue[refiShortlistStrikeDamageWanted])
                                    end
                                end
                            end
                        elseif tbConsideredTargetsByTech[2] and iT1AreasToAvoidCount == 0 then
                            --Add any priority 1-3 targets for T1 bombers that still need assigning to the T2 bomber shortlist
                            local iRevisedPriority
                            for iValue, tValue in aiBrain[reftBomberShortlistByTech][2] do
                                if tValue[refiShortlistPriority] <= 3 then
                                    if not (EntityCategoryContains(categories.TECH1 + M27UnitInfo.refCategoryEngineer - categories.COMMAND, tValue[refiShortlistUnit].UnitId)) then
                                        iCurPriority = tValue[refiShortlistPriority]
                                        --Adjust priorities for strat bombers: T3 AA; T2 AA; Other units
                                        if iCurPriority == 1 then
                                            if not (EntityCategoryContains(categories.TECH3, tValue[refiShortlistUnit].UnitId)) then
                                                iCurPriority = 2
                                            end
                                        elseif iCurPriority == 2 then
                                            iCurPriority = 3
                                        end

                                        AddUnitToShortlist(tValue[refiShortlistUnit], iTechLevel, tValue[refiBomberDefenceModDistance], tValue[refiShortlistStrikeDamageWanted])
                                    end
                                end
                            end
                        else
                            --Check for nearby enemy T2+T3 units, except SAMs
                            iCurPriority = 1
                            tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA - categories.TECH1 - M27UnitInfo.refCategoryEngineer - M27UnitInfo.refCategoryStructureAA * categories.TECH3, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iT3DefensiveLimit, 'Enemy')
                            for iUnit, oUnit in tPotentialTargets do
                                if not (oUnit:IsUnitState('Attached')) then
                                    iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false) + math.min(100, (oUnit[refiFailedHitCount] or 0) * 15)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': CurPriority=' .. iCurPriority .. '; Considering whether to add unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' to shortlist; mod distance=' .. (iCurModDistance or 'nil') .. '; aiBrain[refiBomberDefenceModDistance]=' .. aiBrain[refiBomberDefenceModDistance] .. '; Actual distance to start=' .. M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) .. '; Angle from start to unit=' .. M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) .. '; Dist to enemy base=' .. aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] .. '; Angle to enemy base from start=' .. M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) .. '; Unit position=' .. repru(oUnit:GetPosition()) .. '; enemy base position=' .. repru(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)))
                                    end
                                    if iCurModDistance <= aiBrain[refiBomberDefenceModDistance] then
                                        if not(bCheckForDangerousAA) or iCurModDistance <= aiBrain[refiBomberDefenceCriticalThreatDistance] or not (IsTargetCoveredByAA(oUnit, M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyAAToAvoid], 4, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], false)) then
                                            AddUnitToShortlist(oUnit, iTechLevel, iCurModDistance)
                                        end
                                    end
                                end
                            end

                            --Normal combat units
                            iCurPriority = 2
                            tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand - categories.TECH1 - M27UnitInfo.refCategoryEngineer + M27UnitInfo.refCategorySalem, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iT3DefensiveLimit, 'Enemy')
                            for iUnit, oUnit in tPotentialTargets do
                                if not (oUnit:IsUnitState('Attached')) then
                                    iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false) + math.min(100, (oUnit[refiFailedHitCount] or 0) * 15)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': CurPriority=' .. iCurPriority .. '; Considering whether to add unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' to shortlist; mod distance=' .. (iCurModDistance or 'nil') .. '; aiBrain[refiBomberDefenceModDistance]=' .. aiBrain[refiBomberDefenceModDistance] .. '; Actual distance to start=' .. M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) .. '; Angle from start to unit=' .. M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit:GetPosition()) .. '; Dist to enemy base=' .. aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] .. '; Angle to enemy base from start=' .. M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) .. '; Unit position=' .. repru(oUnit:GetPosition()) .. '; enemy base position=' .. repru(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)))
                                    end
                                    if iCurModDistance <= aiBrain[refiBomberDefenceModDistance] then
                                        if not(bCheckForDangerousAA) or iCurModDistance <= aiBrain[refiBomberDefenceCriticalThreatDistance] or not (IsTargetCoveredByAA(oUnit, M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyAAToAvoid], 4, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], false)) then
                                            AddUnitToShortlist(oUnit, iTechLevel, iCurModDistance)
                                        end
                                    end
                                end
                            end

                            --ACU
                            iCurPriority = 3
                            if M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoLastNearestACU]) then
                                iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, aiBrain[M27Overseer.refoLastNearestACU]:GetPosition(), false) + math.min(100, (aiBrain[M27Overseer.refoLastNearestACU][refiFailedHitCount] or 0) * 15)
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': CurPriority=' .. iCurPriority .. '; Considering whether to add enemy ACU to bomber target. Mod distance for enemy ACU=' .. iCurModDistance .. '; aiBrain[refiBomberDefenceModDistance]=' .. aiBrain[refiBomberDefenceModDistance]..'; aiBrain[M27Overseer.refiLastNearestACUDistance]='..aiBrain[M27Overseer.refiLastNearestACUDistance]..'; aiBrain[refiBomberDefenceCriticalThreatDistance]='..aiBrain[refiBomberDefenceCriticalThreatDistance]..'; Intel coverage of target ACU position='..M27Logic.GetIntelCoverageOfPosition(aiBrain, aiBrain[M27Overseer.refoLastNearestACU]:GetPosition())..'; last nearest ACU owner='..(aiBrain[M27Overseer.refoLastNearestACU]:GetAIBrain().Nickname or 'nil')..'; do we haev at least 19 intel coverage='..tostring(M27Logic.GetIntelCoverageOfPosition(aiBrain, aiBrain[M27Overseer.refoLastNearestACU]:GetPosition(), 19, false)))
                                end
                                if iCurModDistance <= aiBrain[refiBomberDefenceModDistance] then
                                    if iCurModDistance <= aiBrain[refiBomberDefenceCriticalThreatDistance] or ((aiBrain[M27Overseer.refiLastNearestACUDistance] <= 150 and (not(bCheckForDangerousAA) or not (IsTargetCoveredByAA(aiBrain[M27Overseer.refoLastNearestACU], M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyAAToAvoid], 4, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], false)))) and M27Logic.GetIntelCoverageOfPosition(aiBrain, aiBrain[M27Overseer.refoLastNearestACU]:GetPosition(), 19)) then
                                        AddUnitToShortlist(aiBrain[M27Overseer.refoLastNearestACU], iTechLevel, iCurModDistance)
                                    else
                                        --Only add ACU if it has no shield under it and no T3+ AA, and we have intel coverage (use 19 since air segment size is 20, so if we have visual it will return true)
                                        if not (M27Logic.IsTargetUnderShield(aiBrain, aiBrain[M27Overseer.refoLastNearestACU], 0, false, false, true)) and M27Logic.GetIntelCoverageOfPosition(aiBrain, aiBrain[M27Overseer.refoLastNearestACU]:GetPosition(), 19) then
                                            if not (IsTargetCoveredByAA(aiBrain[M27Overseer.refoLastNearestACU], tEnemyAAAndCruisers, 3, tStartPoint)) then
                                                AddUnitToShortlist(aiBrain[M27Overseer.refoLastNearestACU], iTechLevel, iCurModDistance)
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        --Also consider vulnerable T2 mexes even if have nearby threats (so strat bombers far from base will keep raiding in the hope the T1 bombers can hold out at base
                        local tEnemyT2Mex = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2Mex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Enemy')
                        tStartPoint = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                        --tEnemyAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3 + M27UnitInfo.refCategoryCruiser, tStartPoint, aiBrain[refiMaxScoutRadius], 'Enemy')
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': iTargetCount after considering emergency threat range=' .. iTargetCount .. '; is table of enemy T2 mexes empty=' .. tostring(M27Utilities.IsTableEmpty(tEnemyT2Mex)) .. '; is table of enemy t3 air empty=' .. tostring(M27Utilities.IsTableEmpty(tAllEnemyAA)) .. '; iHighestPriorityFound=' .. iHighestPriorityFound)
                        end
                        if M27Utilities.IsTableEmpty(tEnemyT2Mex) == false then
                            if iHighestPriorityFound >= 100 then iHighestPriorityFound = 1 end
                            --iCurPriority = iHighestPriorityFound --I.e. consider alongside the top priority for defence

                            for iMex, oMex in tEnemyT2Mex do
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Considering mex ' .. oMex.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oMex) .. '; is it underwater=' .. tostring(M27UnitInfo.IsUnitUnderwater(oMex)) .. '; Is under shield=' .. tostring(M27Logic.IsTargetUnderShield(aiBrain, oMex, 0, false, false, true)) .. '; is protected by AA=' .. tostring(IsTargetCoveredByAA(oMex, tEnemyAAAndCruisers, 3, tStartPoint)))
                                end
                                if not (M27UnitInfo.IsUnitUnderwater(oMex)) then
                                    --Include if its unshielded with no AA (ignoring flak and T1) on the way to it from our base (assume part-compelte shields will be built by the time we get there)
                                    if not (M27Logic.IsTargetUnderShield(aiBrain, oMex, 0, false, false, true)) then
                                        if not (IsTargetCoveredByAA(oMex, tEnemyAAAndCruisers, 3, tStartPoint)) then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Will add mex ' .. oMex.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oMex) .. ' to shortlist')
                                            end
                                            if (oMex[refiFailedHitCount] or 0) > 0 then iCurPriority = iHighestPriorityFound + 3 else iCurPriority = iHighestPriorityFound end --I.e. consider alongside the top priority for defence
                                            AddUnitToShortlist(oMex, iTechLevel)
                                        end
                                    end
                                end
                            end
                        end

                        --If enemy cruiser within emergency defence range, and aren't avoiding cruisers, then also consider this (but not carriers)
                        if not (bAvoidCruisers) and iNearestCruiserModDistance <= aiBrain[refiBomberDefenceModDistance] + 30 then
                            iCurPriority = iHighestPriorityFound
                            tPotentialTargets = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryCruiser, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], math.min(iT3DefensiveLimit, aiBrain[refiBomberDefenceModDistance] * 2), 'Enemy')
                            if M27Utilities.IsTableEmpty(tPotentialTargets) == false then
                                for iUnit, oUnit in tPotentialTargets do
                                    if M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition()) <= aiBrain[refiBomberDefenceModDistance] + 30 then
                                        --Dont add if unit is shielded or has high max health
                                        if (oUnit:GetMaxHealth() <= 2750 or oUnit:GetHealth() <= 2400) and not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, false)) then
                                            AddUnitToShortlist(oUnit, iTechLevel)
                                        end
                                    end
                                end
                            end
                        end

                        --If no targets, then search for lower priority targets subject to intel limit
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': If no target count then will search for lower priority targets. iTargetCount=' .. iTargetCount)
                        end
                        if iTargetCount == 0 then
                            --Look for enemies that should be able to 1-shot if theyre unshielded that are high enoguh value to be worth risking the strat on
                            iCurPriority = 4
                            local tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryStructureAA * categories.TECH2 + M27UnitInfo.refCategoryTML + M27UnitInfo.refCategoryT3Radar + M27UnitInfo.refCategoryPD * categories.TECH2, tStartPoint, iIntelBasedLimit, 'Enemy')
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': is tEnemiesEmpty=' .. tostring(M27Utilities.IsTableEmpty(tEnemies)))
                            end
                            if M27Utilities.IsTableEmpty(tEnemies) == false then
                                for iUnit, oUnit in tEnemies do
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Considering oUnit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; is it underwater=' .. tostring(M27UnitInfo.IsUnitUnderwater(oUnit)) .. '; Is under shield=' .. tostring(M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)) .. '; is protected by AA=' .. tostring(IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint)))
                                    end
                                    if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                        --Include if its unshielded with no AA on the way to it from our base (assume part-compelte shields will be built by the time we get there)
                                        if not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)) then
                                            if not (IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint)) then
                                                AddUnitToShortlist(oUnit, iTechLevel)
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Just tried adding the unit to shortlist')
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': iTargetCount=' .. iTargetCount .. '; if its zero will look for enemy ACUs and experimentals closer to our base than enemy base')
                            end
                            if iTargetCount == 0 then
                                iCurPriority = 5
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Couldnt find any emergengy defence or t2 vulnerable mexes so have looked for enemy ACU and land experimentals on our side of the map.  iTargetCount=' .. iTargetCount)
                                end
                                --Also consider T3 MAA that is unshielded within 65% of our base
                                tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMAA * categories.TECH3, tStartPoint, math.min(iIntelBasedLimit, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.65), 'Enemy')
                                --local tEnemyNonMAASAM --calculate outside of the istableempty check for tenemies since also refer to it for t2maa
                                --if M27Utilities.IsTableEmpty(tEnemyAA) == false then
                                --tEnemyNonMAASAM = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3 * categories.STRUCTURE + M27UnitInfo.refCategoryCruiserCarrier, tStartPoint, aiBrain[refiMaxScoutRadius], 'Enemy')
                                --end
                                if M27Utilities.IsTableEmpty(tEnemies) == false then
                                    for iUnit, oUnit in tEnemies do
                                        if (oUnit[refiStrikeDamageAssigned] or 0) == 0 then
                                            --Dont want to target if already being targeted for some other reason (as risk sending bombers piecemeal)
                                            if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                                if not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)) and not (IsTargetCoveredByAA(oUnit, tEnemySAMsAndCruisers, 3, tStartPoint)) then
                                                    AddUnitToShortlist(oUnit, iTechLevel)
                                                end
                                            end
                                        end
                                    end
                                end
                                --Consider T2 MAA and fixed T1 AA within bomber defence range+40 given how bad t1 bombers are against them
                                tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMAA * categories.TECH2 + M27UnitInfo.refCategoryStructureAA * categories.TECH1, tStartPoint, math.min(iIntelBasedLimit, aiBrain[refiBomberDefenceModDistance] * 2), 'Enemy')
                                if M27Utilities.IsTableEmpty(tEnemies) == false then
                                    for iUnit, oUnit in tEnemies do
                                        if (oUnit[refiStrikeDamageAssigned] or 0) == 0 then
                                            --Dont want to target if already being targeted for some other reason (as risk sending bombers piecemeal)
                                            if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                                iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false) + math.min(70, (oUnit[refiFailedHitCount] or 0) * 15)
                                                if iCurModDistance <= aiBrain[refiBomberDefenceModDistance] + 50 then
                                                    if not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)) and not (IsTargetCoveredByAA(oUnit, tEnemySAMsAndCruisers, 3, tStartPoint)) then
                                                        AddUnitToShortlist(oUnit, iTechLevel)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            if iTargetCount == 0 then
                                --land experimental or enemy ACU that is within 60% of our base, and within 500?
                                iCurPriority = 6
                                tEnemies = aiBrain:GetUnitsAroundPoint(categories.COMMAND + M27UnitInfo.refCategoryLandExperimental, tStartPoint, math.min(iIntelBasedLimit, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]), 'Enemy')
                                if M27Utilities.IsTableEmpty(tEnemies) == false then
                                    for iUnit, oUnit in tEnemies do
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Considering oUnit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; is it underwater=' .. tostring(M27UnitInfo.IsUnitUnderwater(oUnit)) .. '; Is under shield=' .. tostring(M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)) .. '; is protected by AA=' .. tostring(IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint)) .. '; strike damage already assigned=' .. (oUnit[refiStrikeDamageAssigned] or 0))
                                        end
                                        if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                            if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tStartPoint) < math.max(M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)), aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.6) then
                                                --Fatboy specific - include if shield is low and we have fewer than 5 T2 arti in range of it, and we have friendly units in range of it
                                                if EntityCategoryContains(M27UnitInfo.refCategoryFatboy, oUnit.UnitId) and not(aiBrain[refbFarBehindOnAir]) then
                                                    local iCurShield, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oUnit, true)
                                                    if iCurShield <= iMaxShield * 0.15 then
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy fatboy has low shield, iCurShield='..iCurShield..'; iMaxShield='..iMaxShield..'; Is it covered by AA='..tostring(IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint))) end
                                                        if not (IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint)) then
                                                            AddUnitToShortlist(oUnit, iTechLevel)
                                                        else
                                                            --Still attack if nearby T2+ units or ACU
                                                            local tNearbyT2PlusFriendlies = aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE - categories.TECH1 - categories.UNSELECTABLE - categories.UNTARGETABLE, oUnit:GetPosition(), 110, 'Ally')
                                                            if bDebugMessages == true then LOG(sFunctionRef..': Do we have T2+ ground units near the fatboy? Is table empty='..tostring(M27Utilities.IsTableEmpty(tNearbyT2PlusFriendlies))) end
                                                            if M27Utilities.IsTableEmpty(tNearbyT2PlusFriendlies) == false then
                                                                AddUnitToShortlist(oUnit, iTechLevel)
                                                            end
                                                        end
                                                    end
                                                    --Include if its unshielded with no AA on the way to it from our base (assume part-compelte shields will be built by the time we get there)
                                                elseif not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)) then
                                                    if not (IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint)) then
                                                        AddUnitToShortlist(oUnit, iTechLevel)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            if iTargetCount == 0 then
                                iCurPriority = 7
                                --Consider T3 mexes since hover-bombing means we can kill in 1 go sometimes
                                tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT3Mex, tStartPoint, math.min(iIntelBasedLimit, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]), 'Enemy')
                                if M27Utilities.IsTableEmpty(tEnemies) == false then
                                    for iUnit, oUnit in tEnemies do
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Considering oUnit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; is it underwater=' .. tostring(M27UnitInfo.IsUnitUnderwater(oUnit)) .. '; Is under shield=' .. tostring(M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)) .. '; is protected by AA=' .. tostring(IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint)) .. '; strike damage already assigned=' .. (oUnit[refiStrikeDamageAssigned] or 0))
                                        end
                                        if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                            --Include if its unshielded with no AA on the way to it from our base (assume part-compelte shields will be built by the time we get there)
                                            if not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)) then
                                                if not (IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint)) then
                                                    AddUnitToShortlist(oUnit, iTechLevel)
                                                end
                                            end
                                        end
                                    end
                                end

                                --T3 enemy land on our side of the map
                                if iTargetCount == 0 then
                                    iCurPriority = 8
                                    --Consider enemy T3 land within 50% of our base
                                    tEnemies = aiBrain:GetUnitsAroundPoint(categories.SUBCOMMANDER + M27UnitInfo.refCategoryLandCombat * categories.TECH3 + M27UnitInfo.refCategoryMobileLandShield + M27UnitInfo.refCategoryMAA * categories.TECH3, tStartPoint, math.min(iIntelBasedLimit, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.5), 'Enemy')
                                    if M27Utilities.IsTableEmpty(tEnemies) == false then
                                        for iUnit, oUnit in tEnemies do
                                            if (oUnit[refiStrikeDamageAssigned] or 0) == 0 then
                                                --Dont want to target if already being targeted for some other reason (as risk sending bombers piecemeal)
                                                if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                                    if not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)) and not (IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint)) then
                                                        AddUnitToShortlist(oUnit, iTechLevel)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end

                            end
                        elseif bDebugMessages == true then
                            LOG(sFunctionRef .. ': Have targets from emergency defence and t2 vulnerable mexes so wont look for more targets. iTargetCount=' .. iTargetCount .. '; tStartPoint=' .. repru(tStartPoint))
                        end
                    elseif iTechLevel == 4 then
                        if iAvailableBombers == 1 then
                            tStartPoint = tBombersOfTechLevel[iAvailableBombers]:GetPosition()
                        else
                            tStartPoint = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                        end
                        --tEnemyAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3 + M27UnitInfo.refCategoryCruiser, tStartPoint, aiBrain[refiMaxScoutRadius], 'Enemy')
                        if bDebugMessages == true then
                            if not (M27Utilities.IsTableEmpty(tEnemyAAAndCruisers)) then
                                LOG(sFunctionRef .. ': Size of tEnemyAAAndCruisers=' .. table.getn(tEnemyAAAndCruisers))
                            else
                                LOG(sFunctionRef .. ': tEnemyAAAndCruisers is empty')
                            end
                        end
                        local iEnemyAANearTarget
                        local iAOE, iStrikeDamage = M27UnitInfo.GetBomberAOEAndStrikeDamage(tBombersOfTechLevel[iAvailableBombers])
                        local tNearbyFriendlies
                        local iNearbyFriendlyCategories = categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL + categories.COMMAND - categories.AIR
                        local iFriendlySearchRange = iAOE * 1.5

                        local iT4MaxDistFromBase = aiBrain[refiMaxScoutRadius]
                        local bDontCheckForDistanceCap = true
                        if aiBrain[refbFarBehindOnAir] then
                            iT4MaxDistFromBase = math.min(iT4MaxDistFromBase, math.max(aiBrain[refiBomberDefenceCriticalThreatDistance] + 50, aiBrain[refiOurFurthestAAStructureFromBase] + 70, 150))
                            bDontCheckForDistanceCap = false
                        elseif not(aiBrain[refbHaveAirControl]) then
                            iT4MaxDistFromBase = math.min(iT4MaxDistFromBase, math.max(aiBrain[refiBomberDefenceCriticalThreatDistance] + 125, aiBrain[refiOurFurthestAAStructureFromBase] + 130, 200, aiBrain[refiBomberDefenceModDistance]))
                            bDontCheckForDistanceCap = false
                        end



                        --Is the enemy ACU vulnerable and we are in assassination mode and it's either the last ACU or full share isnt on? If so then target this
                        iCurPriority = 1
                        if ScenarioInfo.Options.Victory == "demoralization" and not(aiBrain[M27Overseer.refiActiveEnemyBrains] > 1 and ScenarioInfo.Options.Share == 'FullShare') and M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoLastNearestACU]) and M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.reftLastNearestACU], aiBrain[M27Overseer.refoLastNearestACU]:GetPosition()) <= 10 and (not (M27UnitInfo.IsUnitUnderwater(aiBrain[M27Overseer.refoLastNearestACU])) or not (M27MapInfo.IsUnderwater({ aiBrain[M27Overseer.refoLastNearestACU]:GetPosition()[1], aiBrain[M27Overseer.refoLastNearestACU]:GetPosition()[2] + 18, aiBrain[M27Overseer.refoLastNearestACU]:GetPosition()[3] }, false))) then
                            if bDontCheckForDistanceCap or aiBrain[M27Overseer.refiLastNearestACUDistance] <= iT4MaxDistFromBase then
                                tNearbyFriendlies = aiBrain:GetUnitsAroundPoint(iNearbyFriendlyCategories, aiBrain[M27Overseer.refoLastNearestACU]:GetPosition(), iFriendlySearchRange, 'Ally')
                                if M27Utilities.IsTableEmpty(tNearbyFriendlies) then
                                    iEnemyAANearTarget = IsTargetCoveredByAA(aiBrain[M27Overseer.refoLastNearestACU], tEnemyAAAndCruisers, 3, tStartPoint, true)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Checking ACU nearby, iEnemyAANearTarget=' .. iEnemyAANearTarget)
                                    end
                                    if iEnemyAANearTarget <= 5 then
                                        AddUnitToShortlist(aiBrain[M27Overseer.refoLastNearestACU], iTechLevel)
                                    end
                                end
                            end
                        end
                        local tEnemies
                        if iTargetCount == 0 then
                            --Enemy high value structure threats
                            tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategoryExperimentalArti + M27UnitInfo.refCategorySML + M27UnitInfo.refCategoryExperimentalStructure, tStartPoint, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 1.5, 'Enemy')
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Checking high value structure threats; is table empty=' .. tostring(M27Utilities.IsTableEmpty(tEnemies)))
                            end
                            if M27Utilities.IsTableEmpty(tEnemies) == false then
                                for iUnit, oUnit in tEnemies do
                                    if oUnit:GetFractionComplete() >= 0.5 then
                                        if bDontCheckForDistanceCap or M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iT4MaxDistFromBase then
                                            tNearbyFriendlies = aiBrain:GetUnitsAroundPoint(iNearbyFriendlyCategories, oUnit:GetPosition(), iFriendlySearchRange, 'Ally')
                                            if M27Utilities.IsTableEmpty(tNearbyFriendlies) then
                                                iEnemyAANearTarget = IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint, true)
                                                if iEnemyAANearTarget <= 6 then
                                                    AddUnitToShortlist(oUnit, iTechLevel)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            iCurPriority = 2
                            local tEnemySAMs
                            if iTargetCount == 0 then
                                --Enemy navy and land experimentals up to 70% of distsance to enemy base, with <=2 SAMs coverage
                                tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryNavalSurface - categories.TECH1 - categories.STRUCTURE + M27UnitInfo.refCategoryLandExperimental, tStartPoint, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.7, 'Enemy')
                                tEnemySAMs = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3, tStartPoint, aiBrain[refiMaxScoutRadius], 'Enemy')
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Checking enemy naval threats; is table empty=' .. tostring(M27Utilities.IsTableEmpty(tEnemies)))
                                end
                                if M27Utilities.IsTableEmpty(tEnemies) == false then
                                    for iUnit, oUnit in tEnemies do
                                        if oUnit:GetFractionComplete() >= 0.5 then
                                            if bDontCheckForDistanceCap or M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iT4MaxDistFromBase then
                                                tNearbyFriendlies = aiBrain:GetUnitsAroundPoint(iNearbyFriendlyCategories, oUnit:GetPosition(), iFriendlySearchRange, 'Ally')
                                                if M27Utilities.IsTableEmpty(tNearbyFriendlies) then
                                                    iEnemyAANearTarget = IsTargetCoveredByAA(oUnit, tEnemySAMs, 3, tStartPoint, true)
                                                    if iEnemyAANearTarget <= 2 then
                                                        AddUnitToShortlist(oUnit, iTechLevel)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            if iTargetCount == 0 then
                                --Vulnerable groups of T3 mexes
                                iCurPriority = 3
                                tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT3Mex, tStartPoint, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] + 30, 'Enemy')
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Checking enemy vulnerable mexes; is table empty=' .. tostring(M27Utilities.IsTableEmpty(tEnemies)))
                                end
                                local tNearbyMexes
                                if M27Utilities.IsTableEmpty(tEnemies) == false then
                                    for iUnit, oUnit in tEnemies do
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Considering oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; Fractioncomplete=' .. oUnit:GetFractionComplete() .. '; will check for how many high value targets are within iAOE*1.2=' .. iAOE * 1.2 .. ' of the position ' .. repru(oUnit:GetPosition()))
                                        end
                                        if oUnit:GetFractionComplete() >= 0.5 then
                                            if bDontCheckForDistanceCap or M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iT4MaxDistFromBase then
                                                tNearbyFriendlies = aiBrain:GetUnitsAroundPoint(iNearbyFriendlyCategories, oUnit:GetPosition(), iFriendlySearchRange, 'Ally')
                                                if M27Utilities.IsTableEmpty(tNearbyFriendlies) then
                                                    --Are there at least 3 other T2+ mexes or t3 buildings near here (ignoring shields)?
                                                    tNearbyMexes = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryStructure * categories.TECH3 + M27UnitInfo.refCategoryExperimentalStructure, oUnit:GetPosition(), iAOE * 1.2, 'Enemy')
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': size of tNearbyMexes=' .. table.getn(tNearbyMexes))
                                                    end
                                                    if table.getn(tNearbyMexes) >= 3 then
                                                        iEnemyAANearTarget = IsTargetCoveredByAA(oUnit, tEnemySAMs, 3, tStartPoint, true)
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': iEnemyAANearTarget=' .. iEnemyAANearTarget)
                                                        end
                                                        if iEnemyAANearTarget <= 3 then
                                                            AddUnitToShortlist(oUnit, iTechLevel)
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            if iTargetCount == 0 then
                                iCurPriority = 4
                                --Vulnerable T3 mobile land, T2 mexes, T2 fixed arti and T2+ naval fac
                                tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand * categories.TECH3 + M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryNavalSurface * categories.STRUCTURE - categories.TECH1, tStartPoint, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.8, 'Enemy')
                                local tNearbyOtherUnits
                                if M27Utilities.IsTableEmpty(tEnemies) == false then
                                    for iUnit, oUnit in tEnemies do
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Considering oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; Fractioncomplete=' .. oUnit:GetFractionComplete() .. '; will check for how many high value targets are within iAOE*1.2=' .. iAOE * 1.2 .. ' of the position ' .. repru(oUnit:GetPosition()))
                                        end
                                        if oUnit:GetFractionComplete() >= 0.5 then
                                            if bDontCheckForDistanceCap or M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iT4MaxDistFromBase then
                                                tNearbyFriendlies = aiBrain:GetUnitsAroundPoint(iNearbyFriendlyCategories, oUnit:GetPosition(), iFriendlySearchRange, 'Ally')
                                                if M27Utilities.IsTableEmpty(tNearbyFriendlies) then
                                                    --Are there at least 3 other T2+ mexes or t3 buildings near here (ignoring shields) or T3 mobile land
                                                    tNearbyOtherUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryStructure * categories.TECH3 + M27UnitInfo.refCategoryExperimentalStructure + M27UnitInfo.refCategoryMobileLand * categories.TECH3 + M27UnitInfo.refCategoryNavalSurface, oUnit:GetPosition(), iAOE, 'Enemy')
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': size of tNearbyMexes=' .. table.getn(tNearbyOtherUnits))
                                                    end
                                                    if table.getn(tNearbyOtherUnits) >= 3 then
                                                        iEnemyAANearTarget = IsTargetCoveredByAA(oUnit, tEnemySAMs, 3, tStartPoint, true)
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': iEnemyAANearTarget=' .. iEnemyAANearTarget)
                                                        end
                                                        if iEnemyAANearTarget <= 2 then
                                                            AddUnitToShortlist(oUnit, iTechLevel)
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end

                                --Target nearest SAM or cruiser
                                if iTargetCount == 0 then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Dont ahve any targets so will go for the nearest SAM to us')
                                    end
                                    if not (M27Utilities.IsTableEmpty(tEnemyAAAndCruisers)) then
                                        iCurPriority = 5
                                        local iMaxShieldedSAM = 6
                                        local iMaxUnshieldedSAM = 12
                                        if M27UnitInfo.GetUnitHealthPercent(tBombersOfTechLevel[iAvailableBombers]) <= 0.4 then
                                            iMaxShieldedSAM = 0
                                            iMaxUnshieldedSAM = 6
                                        elseif M27UnitInfo.GetUnitHealthPercent(tBombersOfTechLevel[iAvailableBombers]) <= 0.8 then
                                            iMaxShieldedSAM = 3
                                            iMaxUnshieldedSAM = 6
                                        end
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Will look for unshielded enemy AA; iMaxShieldedSAM=' .. iMaxShieldedSAM .. '; iMaxUnshieldedSAM=' .. iMaxUnshieldedSAM)
                                        end
                                        for iUnit, oUnit in tEnemyAAAndCruisers do
                                            --Is the target far enoguh away that we can get a decent run at it (at speed)?
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Considering oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; Distance to startpoint=' .. M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tStartPoint) .. '; iEnemyAANearTarget=' .. IsTargetCoveredByAA(oUnit, tEnemySAMs, 3, tStartPoint, true) .. '; Is shielded=' .. tostring(M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)))
                                            end

                                            --Is the unit visible (since we have included recently seen units in here)?
                                            if M27Utilities.CanSeeUnit(aiBrain, oUnit, true) then
                                                if bDontCheckForDistanceCap or M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iT4MaxDistFromBase then
                                                    if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tStartPoint) >= 120 then
                                                        tNearbyFriendlies = aiBrain:GetUnitsAroundPoint(iNearbyFriendlyCategories, oUnit:GetPosition(), iFriendlySearchRange, 'Ally')
                                                        if M27Utilities.IsTableEmpty(tNearbyFriendlies) then
                                                            iEnemyAANearTarget = IsTargetCoveredByAA(oUnit, tEnemySAMs, 3, tStartPoint, true)

                                                            if iEnemyAANearTarget <= iMaxUnshieldedSAM then
                                                                if iEnemyAANearTarget <= iMaxShieldedSAM or not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)) then
                                                                    AddUnitToShortlist(oUnit, iTechLevel)
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            if iTargetCount == 0 then
                                iCurPriority = 6
                                tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure * categories.TECH3 + M27UnitInfo.refCategoryExperimentalStructure + M27UnitInfo.refCategoryFixedT2Arti, tStartPoint, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] + 30, 'Enemy')
                                if M27Utilities.IsTableEmpty(tEnemies) == false then
                                    local iMaxShieldedSAM = 2
                                    local iMaxUnshieldedSAM = 4
                                    if M27UnitInfo.GetUnitHealthPercent(tBombersOfTechLevel[iAvailableBombers]) <= 0.4 then
                                        iMaxShieldedSAM = 0
                                        iMaxUnshieldedSAM = 2
                                    elseif M27UnitInfo.GetUnitHealthPercent(tBombersOfTechLevel[iAvailableBombers]) <= 0.8 then
                                        iMaxShieldedSAM = 1
                                        iMaxUnshieldedSAM = 3
                                    end

                                    for iUnit, oUnit in tEnemies do
                                        if oUnit:GetFractionComplete() >= 0.5 then
                                            if bDontCheckForDistanceCap or M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iT4MaxDistFromBase then
                                                tNearbyFriendlies = aiBrain:GetUnitsAroundPoint(iNearbyFriendlyCategories, oUnit:GetPosition(), iFriendlySearchRange, 'Ally')
                                                if M27Utilities.IsTableEmpty(tNearbyFriendlies) then
                                                    iEnemyAANearTarget = IsTargetCoveredByAA(oUnit, tEnemySAMs, 3, tStartPoint, true)
                                                    if iEnemyAANearTarget <= iMaxUnshieldedSAM then
                                                        if iEnemyAANearTarget <= iMaxShieldedSAM or not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)) then
                                                            AddUnitToShortlist(oUnit, iTechLevel)
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                if iTargetCount == 0 then
                                    iCurPriority = 7
                                    tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure * categories.TECH2 - M27UnitInfo.refCategoryFixedT2Arti, tStartPoint, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] + 30, 'Enemy')
                                    if M27Utilities.IsTableEmpty(tEnemies) == false then
                                        for iUnit, oUnit in tEnemies do
                                            if oUnit:GetFractionComplete() >= 0.5 then
                                                if bDontCheckForDistanceCap or M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iT4MaxDistFromBase then
                                                    tNearbyFriendlies = aiBrain:GetUnitsAroundPoint(iNearbyFriendlyCategories, oUnit:GetPosition(), iFriendlySearchRange, 'Ally')
                                                    if M27Utilities.IsTableEmpty(tNearbyFriendlies) then
                                                        iEnemyAANearTarget = IsTargetCoveredByAA(oUnit, tEnemySAMs, 3, tStartPoint, true)
                                                        if iEnemyAANearTarget <= 0 then
                                                            AddUnitToShortlist(oUnit, iTechLevel)
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end

                                end
                            end
                        end
                    end
                end
                if iTargetCount == 0 and iTechLevel < 4 and iAvailableBombers > 0 and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                    --In air dominance mode, so consider all enemy units even low value ones
                    iCurPriority = iCurPriority + 1
                    --First target any eco
                    local tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryPower + M27UnitInfo.refCategoryMex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Enemy')
                    if M27Utilities.IsTableEmpty(tEnemies) == false then
                        for iUnit, oUnit in tEnemies do
                            if not (M27UnitInfo.IsUnitUnderwater(oUnit)) and oUnit:GetFractionComplete() >= 0.5 then
                                AddUnitToShortlist(oUnit, iTechLevel)
                            end
                        end
                    end

                    if iTargetCount == 0 then
                        iCurPriority = iCurPriority + 1
                        --Target any mobile land units and surface naval units
                        tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand + M27UnitInfo.refCategoryNavalSurface, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Enemy')
                        if M27Utilities.IsTableEmpty(tEnemies) == false then
                            for iUnit, oUnit in tEnemies do
                                if not (M27UnitInfo.IsUnitUnderwater(oUnit)) and oUnit:GetFractionComplete() >= 0.5 then
                                    AddUnitToShortlist(oUnit, iTechLevel)
                                end
                            end
                        end
                        if iTargetCount == 0 then
                            iCurPriority = iCurPriority + 1
                            --Target any structures
                            tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Enemy')
                            if M27Utilities.IsTableEmpty(tEnemies) == false then
                                for iUnit, oUnit in tEnemies do
                                    if not (M27UnitInfo.IsUnitUnderwater(oUnit)) and oUnit:GetFractionComplete() >= 0.5 then
                                        AddUnitToShortlist(oUnit, iTechLevel)
                                    end
                                end
                            end
                        end
                    end
                end




                --Assign the shortlist to avaialble bombers
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iTechLevel=' .. iTechLevel .. '; iTargetCount=' .. iTargetCount .. '; iAvailableBombers=' .. iAvailableBombers .. '; if have targets and available bombers then will assign targets to the bombers')
                end
                if iTargetCount > 0 and iAvailableBombers > 0 then
                    local oCurTarget, oCurBomber
                    local iLoopStartAvailableBombers = 0
                    if iAvailableBombers >= 10 and iTechLevel == 1 then
                        --For performance reasons assign targets based on mod distance to the base
                        for iEntry, tValue in M27Utilities.SortTableBySubtable(aiBrain[reftBomberShortlistByTech][iTechLevel], refiBomberDefenceModDistance, true) do
                            oCurTarget = tValue[refiShortlistUnit]
                            --Do we still have more damage to deal to the target?
                            while (oCurTarget[refiStrikeDamageAssigned] <= tValue[refiShortlistStrikeDamageWanted] or EntityCategoryContains(categories.COMMAND + categories.EXPERIMENTAL, tValue[refiShortlistUnit].UnitId)) do
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': oCurTarget=' .. oCurTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oCurTarget) .. '; strike damage assigned=' .. (oCurTarget[refiStrikeDamageAssigned] or 'nil') .. '; tValue[refiShortlistStrikeDamageWanted]=' .. tValue[refiShortlistStrikeDamageWanted] .. '; iAvailableBombers=' .. iAvailableBombers .. '; iLoopStartAvailableBombers=' .. iLoopStartAvailableBombers)
                                end
                                iLoopStartAvailableBombers = iAvailableBombers
                                oCurBomber = tBombersOfTechLevel[iAvailableBombers]
                                if not (M27UnitInfo.IsUnitValid(oCurBomber)) then
                                    M27Utilities.ErrorHandler('Returned a bomber iAvailablerBombers=' .. iAvailableBombers .. ' that isnt valid')
                                end
                                TargetUnit(oCurTarget, oCurBomber, tValue[refiShortlistPriority], tValue[refiShortlistStrikeDamageWanted])
                                if EntityCategoryContains(M27UnitInfo.refCategoryT1Mex, oCurTarget.UnitId) and EntityCategoryContains(categories.TECH1, oCurBomber) then
                                    aiBrain[refiTimeOfLastT1BomberMexAttack] = GetGameTimeSeconds()
                                    aiBrain[reftMexHunterT1Bombers][oCurBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oCurBomber)] = oCurBomber
                                    aiBrain[refoT1MexTarget] = oCurTarget
                                end
                                if iLoopStartAvailableBombers <= iAvailableBombers or iAvailableBombers <= 0 then
                                    break
                                end
                            end
                            if iAvailableBombers <= 0 then
                                break
                            end
                        end
                    else
                        --Assign units based on distance to the bomber itself, starting with the highest priority
                        local iMaxAlternativeDistanceIncrease = 0 --e.g. if cycling through ooptions after selecting the best target, then will keep looking at the same priority to see if anything in a similar distance that deals much more damage
                        local iMaxAlternativeTargetsToConsider = 0 --Max number of units that will consider (used so we ont overload the cpu if we have lots of bombers
                        local toAlternatives = {}
                        local iReference --Used to temporarily store subtable reference
                        local tiDistanceOfAlternatives = {}
                        local tValidAlternatives = {} --refined list of toAlternatives based on priority and distance
                        local iMinValueWanted --Min value wanted from an alternative target
                        local iCurBombValue --value given by a bomb
                        local iAOE, iCurStrikeDamage --used for if considering alternative targets
                        local iCurAlternative = 0 --Used to limit the number of alternative targets considered
                        local iMaxDistanceChecks = 1
                        local iWithin75PercentFactor




                        if iTechLevel == 3 then
                            iMaxAlternativeDistanceIncrease = 45
                            iMaxAlternativeTargetsToConsider = math.max(3, 10 - iAvailableBombers)
                            iMaxDistanceChecks = 1
                            iWithin75PercentFactor = 0.45
                        elseif iTechLevel == 4 then
                            iMaxAlternativeDistanceIncrease = 75
                            iMaxAlternativeTargetsToConsider = 30
                            iMaxDistanceChecks = 2
                            iWithin75PercentFactor = 0.8
                        elseif iAvailableBombers <= 2 and iTechLevel == 2 then
                            iMaxAlternativeDistanceIncrease = 15
                            iMaxAlternativeTargetsToConsider = 2
                            iMaxDistanceChecks = 1
                            iWithin75PercentFactor = nil
                        end



                        local iClosestDistance
                        local oClosestDistance
                        local iLowestPriority
                        local tBomberPosition
                        local iTargetMaxHealth

                        local iLastFiredBomb, iBomberSpeed, iTimeToReload, iTimeUntilBomberLoaded, iBomberFacingDirection, bIsTech1

                        local iClosestDangerousDistance
                        local oClosestDangerousDistance
                        local iLowestDangerousPriority
                        local bCurTargetIsDangerous
                        local iDangerousTargetMaxHealth
                        local iCurIMAPAAThreat


                        local bConsiderIMAPThreat = false
                        local iUseRecordedIMAPAvailableThreshold = 0 --If number of available bomers is <= this then will use recorded values
                        local bConsiderUsingDangerousTarget = false --if true then will use dangerous target if it is higher priority than best non-dangerous target
                        local refbTempIsDangerousForBomber = 'M27AirTargetDangerousT3Bomb'

                        if iTechLevel == 3 and aiBrain[refiEnemyAirAAThreat] >= 750 then
                            bConsiderIMAPThreat = true
                            if iAvailableBombers >= 2 then
                                bConsiderUsingDangerousTarget = true
                                if iAvailableBombers > 3 then
                                    iUseRecordedIMAPAvailableThreshold = iAvailableBombers - 3
                                    --Reset previous values
                                    for iEntry, tSubtable in aiBrain[reftBomberShortlistByTech][iTechLevel] do
                                        tSubtable[refiShortlistUnit][refbTempIsDangerousForBomber] = false
                                    end
                                end
                            end
                        end --15+ inties equivalent



                        while iAvailableBombers > 0 do
                            iLoopStartAvailableBombers = iAvailableBombers
                            oCurBomber = tBombersOfTechLevel[iAvailableBombers]
                            tBomberPosition = oCurBomber:GetPosition()
                            bIsTech1 = EntityCategoryContains(categories.TECH1, oCurBomber.UnitId)
                            toAlternatives = {}
                            tiAlternativeShortlistReference = {} --iEntry in aiBrain[reftBomberShortlistByTech][iTechLevel]
                            --tiPriorityOfAlternatives = {}
                            tiDistanceOfAlternatives = {}

                            iLowestPriority = 1000
                            iClosestDistance = 100000
                            oClosestDistance = nil
                            if bConsiderIMAPThreat then
                                iClosestDangerousDistance = 100000
                                oClosestDangerousDistance = nil
                                iLowestDangerousPriority = 1000
                            end

                            if not(bIsTech1) then

                                iLastFiredBomb = GetGameTimeSeconds() - (oCurBomber[refiLastFiredBomb] or -100)
                                iBomberSpeed, iTimeToReload = M27UnitInfo.GetBomberSpeedAndTimeToReload(oCurBomber)
                                if bDebugMessages == true then LOG(sFunctionRef..': Have just got teh speed for oCurBomber '..oCurBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oCurBomber)..'; speed='..(iBomberSpeed or 'nil')..'; Using blueprint this is '..(oCurBomber:GetBlueprint().Air.MaxAirspeed or 'nil')) end
                                iTimeUntilBomberLoaded = math.max(iTimeToReload - iLastFiredBomb, 0)
                                iBomberFacingDirection = M27UnitInfo.GetUnitFacingAngle(oCurBomber)
                            end

                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': About to assign target to oCurBomber=' .. oCurBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oCurBomber))
                            end
                            for iEntry, tSubtable in aiBrain[reftBomberShortlistByTech][iTechLevel] do
                                bCurTargetIsDangerous = false
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Considering shortlist for techlevel=' .. iTechLevel..'; iEntry='..iEntry..'; is shortlist unit valid='..tostring(M27UnitInfo.IsUnitValid(tSubtable[refiShortlistUnit])))
                                end
                                if M27UnitInfo.IsUnitValid(tSubtable[refiShortlistUnit]) then
                                    --Redundancy as once had error that indicated oClosestDistance was a table
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': tSubtable[refiShortlistUnit][refiStrikeDamageAssigned]=' .. (tSubtable[refiShortlistUnit][refiStrikeDamageAssigned] or 0) .. '; tSubtable[refiShortlistStrikeDamageWanted]=' .. tSubtable[refiShortlistStrikeDamageWanted] .. '; tSubtable[refiShortlistPriority]=' .. tSubtable[refiShortlistPriority] .. '; iLowestPriority=' .. iLowestPriority .. '; Mod distance after adjusting for failed hits=' .. M27Utilities.GetDistanceBetweenPositions(tBomberPosition, tSubtable[refiShortlistUnit]:GetPosition()) + math.min(100, (tSubtable[refiShortlistUnit][refiFailedHitCount] or 0) * 15) .. '; iClosestDistance=' .. iClosestDistance)
                                    end
                                    if (tSubtable[refiShortlistUnit][refiStrikeDamageAssigned] or 0) <= tSubtable[refiShortlistStrikeDamageWanted] then
                                        if tSubtable[refiShortlistPriority] <= iLowestPriority then
                                            iCurModDistance = M27Utilities.GetDistanceBetweenPositions(tBomberPosition, tSubtable[refiShortlistUnit]:GetPosition())
                                            --T2+ bombers: factor in angles and time to fire bomb (dont do for t1 for performance reasons)
                                            if not(bIsTech1) then iCurModDistance = GetModifiedBomberDistanceToTarget(iTimeUntilBomberLoaded, iBomberFacingDirection, iBomberSpeed, iCurModDistance, M27Utilities.GetAngleFromAToB(tBomberPosition, tSubtable[refiShortlistUnit]:GetPosition())) end
                                            --Adjust for missed shots
                                            iCurModDistance = iCurModDistance + math.min(100, (tSubtable[refiShortlistUnit][refiFailedHitCount] or 0) * 15)
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Current entry in shortlist is low enough priority.  tSubtable[refiShortlistPriority]=' .. tSubtable[refiShortlistPriority] .. '; iCurModDistance=' .. iCurModDistance .. '; iLowestPriority=' .. iLowestPriority .. '; iClosestDistance=' .. iClosestDistance .. '; tSubtable[refiShortlistUnit][refiStrikeDamageAssigned]=' .. (tSubtable[refiShortlistUnit][refiStrikeDamageAssigned] or 'nil')..'; Actual dist to this unit='..M27Utilities.GetDistanceBetweenPositions(tBomberPosition, tSubtable[refiShortlistUnit]:GetPosition()))
                                                if not(bIsTech1) then
                                                    LOG(sFunctionRef..': Mod dist after adjusting for angle and time to fire shot='..GetModifiedBomberDistanceToTarget(iTimeUntilBomberLoaded, iBomberFacingDirection, iBomberSpeed, iCurModDistance, M27Utilities.GetAngleFromAToB(tBomberPosition, tSubtable[refiShortlistUnit]:GetPosition())))
                                                end
                                            end

                                            --Factor in IMAP if relevant
                                            if bConsiderIMAPThreat then
                                                if iAvailableBombers > iUseRecordedIMAPAvailableThreshold then

                                                    --Decide if taret is dangerous for this bomber

                                                    if GetAirAAThreatAlongPath(aiBrain, tBomberPosition, tSubtable[refiShortlistUnit]:GetPosition(), 3) >= 750 then --If inties are traveling over an area then they will result in a much greater threat than they actually have overall, hence dont want this too low.  At the same time, threat decays so dont want it too high.  750 is equivalent to 15 inties in a single palce (or more realistically, inties picked up in 2 separate segments c.1.5 minutes ago)
                                                        bCurTargetIsDangerous = true
                                                        if bDebugMessages == true then LOG(sFunctionRef..': AirAA historic Threat for potential target '..tSubtable[refiShortlistUnit].UnitId..M27UnitInfo.GetUnitLifetimeCount( tSubtable[refiShortlistUnit])..'='..GetAirAAThreatAlongPath(aiBrain, tBomberPosition, tSubtable[refiShortlistUnit]:GetPosition(), 3)..'; bCurTargetIsDangerous='..tostring(bCurTargetIsDangerous)..'; target position='..repru(tSubtable[refiShortlistUnit]:GetPosition())) end
                                                    elseif bDebugMessages == true then LOG(sFunctionRef..': No airaa threat for potential target '.. tSubtable[refiShortlistUnit].UnitId..M27UnitInfo.GetUnitLifetimeCount( tSubtable[refiShortlistUnit])..' at position '..repru(tSubtable[refiShortlistUnit]:GetPosition()))
                                                    end



                                                    --Update details of the unit even if dangerous:
                                                    if iUseRecordedIMAPAvailableThreshold > 0 and bCurTargetIsDangerous then tSubtable[refiShortlistUnit][refbTempIsDangerousForBomber] = true end
                                                else
                                                    --Dangerous if either of the first 3 bombers thought it was dangerous
                                                    bCurTargetIsDangerous = tSubtable[refiShortlistUnit][refbTempIsDangerousForBomber] or false
                                                end
                                            end
                                            if bCurTargetIsDangerous then
                                                if bConsiderUsingDangerousTarget then
                                                    if tSubtable[refiShortlistPriority] < math.min(iLowestDangerousPriority, iLowestPriority) then
                                                        iClosestDangerousDistance = iCurModDistance
                                                        oClosestDangerousDistance = tSubtable[refiShortlistUnit]
                                                        iDangerousTargetMaxHealth = tSubtable[refiShortlistStrikeDamageWanted]
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': New dangerous target selected=' .. oClosestDangerousDistance.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oClosestDangerousDistance))
                                                        end
                                                        iLowestDangerousPriority = tSubtable[refiShortlistPriority]
                                                    else
                                                        if iCurModDistance < iClosestDangerousDistance and (iLowestDangerousPriority < iLowestPriority or iCurModDistance < iClosestDistance) then
                                                            iClosestDangerousDistance = iCurModDistance
                                                            oClosestDangerousDistance = tSubtable[refiShortlistUnit]
                                                            iDangerousTargetMaxHealth = tSubtable[refiShortlistStrikeDamageWanted]
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': New dangerous target selected=' .. oClosestDangerousDistance.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oClosestDangerousDistance))
                                                            end
                                                        end
                                                    end
                                                end
                                            else
                                                if bDebugMessages == true then LOG(sFunctionRef..': Considering whether to add unit '..tSubtable[refiShortlistUnit].UnitId..M27UnitInfo.GetUnitLifetimeCount(tSubtable[refiShortlistUnit])..' to list of alternatives. iMaxAlternativeDistanceIncrease='..iMaxAlternativeDistanceIncrease..'; tSubtable[refiShortlistPriority]='..iLowestPriority..'; iEntry='..iEntry..'; iCurModDistance='..iCurModDistance..'; Priority='..tSubtable[refiShortlistPriority]) end
                                                if iMaxAlternativeDistanceIncrease > 0 and tSubtable[refiShortlistPriority] <= iLowestPriority then
                                                    table.insert(toAlternatives, tSubtable[refiShortlistUnit])
                                                    table.insert(tiAlternativeShortlistReference, iEntry)
                                                    --table.insert(tiPriorityOfAlternatives, tSubtable[refiShortlistPriority])
                                                    table.insert(tiDistanceOfAlternatives, iCurModDistance)
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Added unit to toAlterantives table, size of toAlternatives='..table.getn(toAlternatives)..'; Shortlist ref='..iEntry..'; Mod dist='..iCurModDistance) end
                                                end
                                                if tSubtable[refiShortlistPriority] < iLowestPriority then
                                                    iClosestDistance = iCurModDistance
                                                    oClosestDistance = tSubtable[refiShortlistUnit]
                                                    iTargetMaxHealth = tSubtable[refiShortlistStrikeDamageWanted]
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': New target selected=' .. oClosestDistance.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oClosestDistance))
                                                    end
                                                    iLowestPriority = tSubtable[refiShortlistPriority]

                                                else
                                                    if iCurModDistance < iClosestDistance then
                                                        iClosestDistance = iCurModDistance
                                                        oClosestDistance = tSubtable[refiShortlistUnit]
                                                        iTargetMaxHealth = tSubtable[refiShortlistStrikeDamageWanted]
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': New target selected=' .. oClosestDistance.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oClosestDistance))
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                elseif bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Unit isnt valid')
                                end
                            end

                            --Decide on unit to target
                            if bConsiderIMAPThreat and bConsiderUsingDangerousTarget and oClosestDangerousDistance and (iLowestDangerousPriority < iLowestPriority or (iLowestDangerousPriority == iLowestPriority and iClosestDangerousDistance + 250 < iClosestDistance)) then
                                if bDebugMessages == true then LOG(sFunctionRef..': All targets of this priority are dangerous or much further away and we have a number of available bombers so will pick the best dangerous target. iLowestPriority='..iLowestPriority..'; iLowestDangerousPriority='..iLowestDangerousPriority) end
                                oClosestDistance = oClosestDangerousDistance
                                iLowestPriority = iLowestDangerousPriority
                                iTargetMaxHealth = iDangerousTargetMaxHealth
                            end
                            if oClosestDistance then
                                --Consider alternatives
                                if bDebugMessages == true then LOG(sFunctionRef..': Have a base target, considering if we want to consider alternatives. iMaxAlternativeDistanceIncrease='..iMaxAlternativeDistanceIncrease..'; Is table empty='..tostring(M27Utilities.IsTableEmpty(toAlternatives))) end
                                if iMaxAlternativeDistanceIncrease > 0 and M27Utilities.IsTableEmpty(toAlternatives) == false then
                                    tValidAlternatives = {}
                                    for iAlternative, oAlternative in toAlternatives do
                                        if not(oAlternative == oClosestDistance) then
                                            iReference = tiAlternativeShortlistReference[iAlternative]
                                            if bDebugMessages == true then LOG(sFunctionRef..': Is cur alternative '..(iAlternative or 'nil')..' with reference '..iReference..' worth considering? Priority='..(aiBrain[reftBomberShortlistByTech][iTechLevel][iReference][refiShortlistPriority] or 'nil')..'; iLowestPriority='..(iLowestPriority or 'nil')..'; iClosestDistance='..(iClosestDistance or 'nil')..'; iMaxAlternativeDistanceIncrease='..(iMaxAlternativeDistanceIncrease or 'nil')..'; tiDistanceOfAlternatives[iAlternative]='..(tiDistanceOfAlternatives[iAlternative] or 'nil')) end
                                            if aiBrain[reftBomberShortlistByTech][iTechLevel][iReference][refiShortlistPriority] <= iLowestPriority and tiDistanceOfAlternatives[iAlternative] <= iClosestDistance + iMaxAlternativeDistanceIncrease then
                                                table.insert(tValidAlternatives, oAlternative)
                                                if bDebugMessages == true then LOG(sFunctionRef..': Will consider unit '..oAlternative.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAlternative)..' as a valid alternative') end
                                            end
                                        end
                                    end
                                    if M27Utilities.IsTableEmpty(tValidAlternatives) == false then
                                        iAOE, iCurStrikeDamage = M27UnitInfo.GetBomberAOEAndStrikeDamage(oCurBomber)
                                        --GetBestAOETarget(aiBrain, tBaseLocation,                  iAOE, iDamage,      bOptionalCheckForSMD, tSMLLocationForSMDCheck, iOptionalTimeSMDNeedsToHaveBeenBuiltFor, iSMDRangeAdjust, iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, iOptionalMaxDistanceCheckOptions, iMobileValueOverrideFactorWithin75Percent)
                                        --tBestBombTarget, iMinValueWanted = M27Logic.GetBestAOETarget(aiBrain, oClosestDistance:GetPosition(), iAOE, iCurStrikeDamage, false,                nil,                     nil,                                   nil,                nil,                                nil,                     iMaxDistanceChecks,             iWithin75PercentFactor)

                                        --if bDebugMessages == true then LOG(sFunctionRef..': About to get damage from bomb for position '..repru(oClosestDistance:GetPosition())..'; iAOE='..(iAOE or 'nil')..'; iCurStrikeDamage='..(iCurStrikeDamage or 'nil')..'; iWithin75PercentFactor='..(iWithin75PercentFactor or 'nil')) end
                                        --GetDamageFromBomb(aiBrain, tBaseLocation,             iAOE, iDamage,          iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, bCumulativeShieldHealthCheck, iOptionalSizeAdjust, iOptionalModIfNeedMultipleShots, iMobileValueOverrideFactorWithin75Percent)
                                        iCurBombValue = M27Logic.GetDamageFromBomb(aiBrain, oClosestDistance:GetPosition(), iAOE, iCurStrikeDamage, nil,                                nil,                    nil,                            nil,                nil,                                iWithin75PercentFactor)
                                        iMinValueWanted = iCurBombValue * 1.3
                                        if EntityCategoryContains(categories.ANTIAIR, oClosestDistance.UnitId) then iMinValueWanted = iMinValueWanted * 1.5 end --If we are targeting an AA unit then only want to switch to a further away target if potential for damage is greatly increased
                                        if bDebugMessages == true then LOG(sFunctionRef..': Min value wanted to change from base target '..oClosestDistance.UnitId..M27UnitInfo.GetUnitLifetimeCount(oClosestDistance)..' = '..iMinValueWanted..' based on iAOE='..iAOE..'; iCurStrikeDamage='..iCurStrikeDamage) end

                                        for iAlternative, oAlternative in tValidAlternatives do
                                            iCurAlternative = iCurAlternative + 1
                                            iReference = tiAlternativeShortlistReference[iAlternative]
                                            --Below does slightly less calculations than normal to reduce taxing CPU too much
                                            --GetBestAOETarget(aiBrain, tBaseLocation,                  iAOE, iDamage,      bOptionalCheckForSMD, tSMLLocationForSMDCheck, iOptionalTimeSMDNeedsToHaveBeenBuiltFor, iSMDRangeAdjust, iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, iOptionalMaxDistanceCheckOptions, iMobileValueOverrideFactorWithin75Percent)
                                            --GetDamageFromBomb(aiBrain, tBaseLocation,             iAOE, iDamage,          iFriendlyUnitDamageReductionFactor, iFriendlyUnitAOEFactor, bCumulativeShieldHealthCheck, iOptionalSizeAdjust, iOptionalModIfNeedMultipleShots, iMobileValueOverrideFactorWithin75Percent)
                                            iCurBombValue = M27Logic.GetDamageFromBomb(aiBrain, oAlternative:GetPosition(), iAOE, iCurStrikeDamage, nil,                                nil,                    nil,                            nil,                nil,                                iWithin75PercentFactor)
                                            --tBestBombTarget, iCurBombValue = M27Logic.GetBestAOETarget(aiBrain, oAlternative:GetPosition(), iAOE, iCurStrikeDamage, false,              nil,                    nil,                                        nil,                nil,                            nil,                 iMaxDistanceChecks,             iWithin75PercentFactor)
                                            if bDebugMessages == true then LOG(sFunctionRef..': Considering valid alternative '..iAlternative..'='..oAlternative.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAlternative)..'; iCurBombValue='..iCurBombValue..'; iMinValueWanted='..iMinValueWanted) end
                                            if iCurBombValue > iMinValueWanted then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Changing bomber target for oCurBomber '..oCurBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oCurBomber)..', were going to target unit '..oClosestDistance.UnitId..M27UnitInfo.GetUnitLifetimeCount(oClosestDistance)..' but will now target '..oAlternative.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAlternative)) end
                                                iMinValueWanted = iCurBombValue + 1
                                                oClosestDistance = oAlternative
                                                iTargetMaxHealth = aiBrain[reftBomberShortlistByTech][iTechLevel][iReference][refiShortlistStrikeDamageWanted]
                                            end
                                            if iCurAlternative >= iMaxAlternativeTargetsToConsider then break end
                                        end
                                    end
                                end


                                TargetUnit(oClosestDistance, oCurBomber, iLowestPriority, iTargetMaxHealth)
                                if iTechLevel == 1 and EntityCategoryContains(M27UnitInfo.refCategoryT1Mex, oCurTarget.UnitId) then
                                    aiBrain[refiTimeOfLastT1BomberMexAttack] = GetGameTimeSeconds()
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Telling oCurBomber=' .. oCurBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oCurBomber) .. ' to target unit ' .. oClosestDistance.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oClosestDistance) .. ' with strike damage assigned on that unit=' .. oClosestDistance[refiStrikeDamageAssigned] .. ' and max strike damage wanted=' .. oClosestDistance[refiMaxStrikeDamageWanted] .. '; bomber on assignment=' .. tostring(oCurBomber[refbOnAssignment]) .. '; iAvailableBombers=' .. iAvailableBombers)
                                end
                            elseif bDebugMessages == true then
                                LOG(sFunctionRef .. ': oClosestDistance is nil')
                            end

                            if iLoopStartAvailableBombers <= iAvailableBombers or iAvailableBombers == 0 then
                                --We havent found any new targets so abort
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': iLoopStartAvailableBombers=' .. iLoopStartAvailableBombers .. '; iAvailableBombers=' .. iAvailableBombers .. '; will abort')
                                end
                                break
                            end
                        end
                    end
                end

            end
            if iAvailableBombers > 0 then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Available bombers after assigning all targets=' .. iAvailableBombers .. '; will send back to rally point')
                end

                local tRallyPoint
                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                    tRallyPoint = { aiBrain[M27MapInfo.reftPrimaryEnemyBaseLocation][1], aiBrain[M27MapInfo.reftPrimaryEnemyBaseLocation][2], aiBrain[M27MapInfo.reftPrimaryEnemyBaseLocation][3] }
                else
                    tRallyPoint = GetAirRallyPoint(aiBrain)
                end

                --T3 strats only - consider coordinated attacks if couldnt find any targets with above and have enough idle bombers
                if iTechLevel == 3 and iAvailableBombers >= 3 and iTargetCount == 0 then
                    --if iAvailableBombers >= 20 then bDebugMessages = true end
                    --Will likely have already determined tStartPoint and tEnemyAA above
                    if M27Utilities.IsTableEmpty(tStartPoint) then
                        tStartPoint = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                    end

                    local iStratsNearRallyPoint = 0
                    local tStratsNearRallyPoint = {}
                    local bTargetsContainHighPriorityWithNoAA = false
                    local iAANearTarget
                    for iUnit, oUnit in tBombersOfTechLevel do
                        if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tRallyPoint) <= 60 then
                            iStratsNearRallyPoint = iStratsNearRallyPoint + 1
                            tStratsNearRallyPoint[iStratsNearRallyPoint] = oUnit
                        end
                    end
                    if iStratsNearRallyPoint >= 3 and not(aiBrain[refbFarBehindOnAir]) and (aiBrain[refbHaveAirControl] or iStratsNearRallyPoint >= 5) and not(M27Conditions.HaveApproachingLandExperimentalThreat(aiBrain)) then

                        --local tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT3Mex, tStartPoint, math.min(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 2, aiBrain[refiMaxScoutRadius]), 'Enemy')
                        local tTargetsByMaxHealth = {} --[1] = 10k, [2] = 20k, [3] = 30k, [4] = 40k, [5] = 50k+
                        local tTargetStrikeDamageByMaxHealth = {}
                        for iIndex = 1, 5 do
                            tTargetsByMaxHealth[iIndex] = {}
                            tTargetStrikeDamageByMaxHealth[iIndex] = {}
                        end
                        local iCurStrikeDamage
                        local iTableIndex
                        local iPossibleTargets = 0
                        iCurPriority = 5
                        --[[if M27Utilities.IsTableEmpty(tEnemies) == false then
                            for iUnit, oUnit in tEnemies do
                                if (oUnit[refiStrikeDamageAssigned] or 0) == 0 then --Dont want to target if already being targeted for some other reason (as risk sending bombers piecemeal)
                                    if not(M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                        if not(IsTargetCoveredByAA(oUnit, tEnemyAA, 3, tStartPoint)) then
                                            iCurStrikeDamage = GetMaxStrikeDamageWanted(oUnit)
                                            iTableIndex = math.ceil(iCurStrikeDamage / 10000)
                                            table.insert(tTargetsByMaxHealth[iTableIndex], oUnit)
                                            table.insert(tTargetStrikeDamageByMaxHealth[iTableIndex], iCurStrikeDamage)
                                            iPossibleTargets = iPossibleTargets + 1
                                        end
                                    end
                                end
                            end
                        end
                        if iPossibleTargets == 0 or M27Utilities.IsTableEmpty(tTargetsByMaxHealth[1]) then --Couldnt find any vulnerable T3 mexes, so look for other tyeps of units as well before settling on a target--]]
                        local iCategoriesToLookFor
                        local bAssassination = false
                        if ScenarioInfo.Options.Victory == "demoralization" then
                            bAssassination = true
                        end

                        if bAssassination then
                            iCategoriesToLookFor = categories.COMMAND + M27UnitInfo.refCategoryStructure * categories.TECH3 - M27UnitInfo.refCategoryStructureAA * categories.TECH3 + M27UnitInfo.refCategoryStructure * categories.EXPERIMENTAL + M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryStructureAA * categories.TECH2 + M27UnitInfo.refCategoryTML + M27UnitInfo.refCategoryT3Radar + M27UnitInfo.refCategoryPD * categories.TECH2
                        else
                            --Dont consider an ACU snipe
                            iCategoriesToLookFor = M27UnitInfo.refCategoryStructure * categories.TECH3 - M27UnitInfo.refCategoryStructureAA * categories.TECH3 + M27UnitInfo.refCategoryStructure * categories.EXPERIMENTAL + M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryStructureAA * categories.TECH2 + M27UnitInfo.refCategoryTML + M27UnitInfo.refCategoryT3Radar + M27UnitInfo.refCategoryPD * categories.TECH2
                        end

                        local tEnemies = aiBrain:GetUnitsAroundPoint(categories.COMMAND + M27UnitInfo.refCategoryStructure * categories.TECH3 - M27UnitInfo.refCategoryStructureAA * categories.TECH3 + M27UnitInfo.refCategoryStructure * categories.EXPERIMENTAL + M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryStructureAA * categories.TECH2 + M27UnitInfo.refCategoryTML + M27UnitInfo.refCategoryT3Radar + M27UnitInfo.refCategoryPD * categories.TECH2, tStartPoint, math.min(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 2, iIntelBasedLimit + 20), 'Enemy')
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': tStartPoint=' .. repru((tStartPoint or { 'nil' })) .. '; aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]=' .. (aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] or 'nil') .. '; aiBrain[refiMaxScoutRadius]=' .. (aiBrain[refiMaxScoutRadius] or 'nil') .. '; tEnemies is high values tructures (e.g. t2 defence and t3 structures, excl t3 aa) and enemy ACU.  Is the table empty=' .. tostring(M27Utilities.IsTableEmpty(tEnemies)))
                        end
                        if M27Utilities.IsTableEmpty(tEnemies) == false then
                            --[[if M27Utilities.IsTableEmpty(tEnemyAAAndCruisers) then
                                tEnemyAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3 + M27UnitInfo.refCategoryCruiser, tStartPoint, aiBrain[refiMaxScoutRadius], 'Enemy')
                            end--]]

                            for iUnit, oUnit in tEnemies do
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Considering oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; Strike damage already assigned=' .. (oUnit[refiStrikeDamageAssigned] or 'nil') .. '; Is unit underwater=' .. tostring(M27UnitInfo.IsUnitUnderwater(oUnit)) .. '; AA covering target=' .. IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint, true) .. '; iStratsNearRallyPoint=' .. iStratsNearRallyPoint .. '; bTargetsContainHighPriorityWithNoAA=' .. tostring(bTargetsContainHighPriorityWithNoAA))
                                end
                                if (oUnit[refiStrikeDamageAssigned] or 0) <= 1000 then
                                    --Dont want to target if already being targeted for some other reason (as risk sending bombers piecemeal); since dealing with t3 strats can ignore low level bomber targeting though
                                    if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                        iAANearTarget = 1000
                                        if not (IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint)) then
                                            iAANearTarget = 0
                                        elseif (bAssassination and EntityCategoryContains(categories.COMMAND, oUnit.UnitId)) or iStratsNearRallyPoint >= 6 then
                                            iAANearTarget = IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint, true)
                                        end
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Considering whether to add unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' to the list of possible targets by health. iCurStrikeDamage=' .. (iCurStrikeDamage or 'nil') .. '; iTableIndex=' .. (iTableIndex or 'nil') .. '; iPossibleTargets=' .. (iPossibleTargets or 'nil') .. '; iAANearTarget=' .. (iAANearTarget or 'nil') .. '; iStratsNearRallyPoint=' .. (iStratsNearRallyPoint or 'nil') .. 'bTargetsContainHighPriorityWithNoAA=' .. tostring(bTargetsContainHighPriorityWithNoAA))
                                        end
                                        if iAANearTarget == 0 or (not (bTargetsContainHighPriorityWithNoAA) and (bAssassination and EntityCategoryContains(categories.COMMAND, oUnit.UnitId) and (iStratsNearRallyPoint >= 26 and iAANearTarget <= 8) or (iStratsNearRallyPoint < 26 and iStratsNearRallyPoint >= 6 and iAANearTarget <= 4)) or (iStratsNearRallyPoint >= 15 and EntityCategoryContains(categories.EXPERIMENTAL, oUnit.UnitId) and iAANearTarget <= 2)) then
                                            iCurStrikeDamage = GetMaxStrikeDamageWanted(oUnit)
                                            iTableIndex = math.min(math.ceil(iCurStrikeDamage / 10000), 5)
                                            table.insert(tTargetsByMaxHealth[iTableIndex], oUnit)
                                            table.insert(tTargetStrikeDamageByMaxHealth[iTableIndex], iCurStrikeDamage)
                                            iPossibleTargets = iPossibleTargets + 1
                                            if iAANearTarget == 0 and not (bTargetsContainHighPriorityWithNoAA) and (aiBrain[refiAirAAWanted] == 0 or aiBrain[refiHighestEnemyAirThreat] <= 2000) and EntityCategoryContains(categories.COMMAND + M27UnitInfo.refCategoryExperimentalStructure + M27UnitInfo.refCategoryExperimentalArti + M27UnitInfo.refCategorySML, oUnit.UnitId) then
                                                bTargetsContainHighPriorityWithNoAA = true
                                            end
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Have decided to add unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' to the list of possible targets by health')
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        --end

                        --Are there no targets with <=20k health needed to kill?  If so, then consider targeting enemy SAMs if we have enough bombers to target 3 SAMs at a time
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': About to check if want to consider worse targets due to ltos of strats. iStratsNearRallyPoint=' .. iStratsNearRallyPoint .. '; iPossibleTargets=' .. iPossibleTargets .. '; Is table of index1 health targets empty=' .. tostring(M27Utilities.IsTableEmpty(tTargetsByMaxHealth[1])) .. '; is table of index2 empty=' .. tostring(M27Utilities.IsTableEmpty(tTargetsByMaxHealth[2])))
                        end
                        if iStratsNearRallyPoint >= 9 and (iPossibleTargets == 0 or (M27Utilities.IsTableEmpty(tTargetsByMaxHealth[1]) and M27Utilities.IsTableEmpty(tTargetsByMaxHealth[2]))) then
                            --Consider targeting unshielded isolated SAMs and cruisers if we have lots of available strats
                            local iEnemyAANearTarget
                            tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructureAA * categories.TECH3 + M27UnitInfo.refCategoryCruiser + M27UnitInfo.refCategoryMAA * categories.TECH3, tStartPoint, math.min(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 2, iIntelBasedLimit + 20), 'Enemy')
                            if M27Utilities.IsTableEmpty(tEnemies) == false then
                                for iUnit, oUnit in tEnemies do
                                    if (oUnit[refiStrikeDamageAssigned] or 0) <= 1000 then
                                        --Dont want to target if already being targeted for some other reason (as risk sending bombers piecemeal)
                                        iCurStrikeDamage = GetMaxStrikeDamageWanted(oUnit)
                                        if iCurStrikeDamage < 10000 then
                                            iEnemyAANearTarget = IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint, true)
                                            if iEnemyAANearTarget <= 3 then
                                                iTableIndex = math.min(5, math.ceil(iCurStrikeDamage / 10000))
                                                table.insert(tTargetsByMaxHealth[iTableIndex], oUnit)
                                                table.insert(tTargetStrikeDamageByMaxHealth[iTableIndex], iCurStrikeDamage)
                                                iPossibleTargets = iPossibleTargets + 1
                                            end
                                        end
                                    end
                                end
                            end

                            if iPossibleTargets == 0 then
                                --Consider enemy T3 land within 80% of our base
                                tEnemies = aiBrain:GetUnitsAroundPoint(categories.SUBCOMMANDER + M27UnitInfo.refCategoryLandCombat * categories.TECH3 + M27UnitInfo.refCategoryMobileLandShield + M27UnitInfo.refCategoryMAA * categories.TECH3, tStartPoint, math.min(iIntelBasedLimit, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.8), 'Enemy')
                                if M27Utilities.IsTableEmpty(tEnemies) == false then
                                    for iUnit, oUnit in tEnemies do
                                        if (oUnit[refiStrikeDamageAssigned] or 0) == 0 then
                                            --Dont want to target if already being targeted for some other reason (as risk sending bombers piecemeal)
                                            if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                                if not (IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint)) then
                                                    iCurStrikeDamage = GetMaxStrikeDamageWanted(oUnit)
                                                    iTableIndex = math.min(5, math.ceil(iCurStrikeDamage / 10000))
                                                    table.insert(tTargetsByMaxHealth[iTableIndex], oUnit)
                                                    table.insert(tTargetStrikeDamageByMaxHealth[iTableIndex], iCurStrikeDamage)
                                                    iPossibleTargets = iPossibleTargets + 1
                                                end
                                            end
                                        end
                                    end
                                end
                                --And at a similar priority, enemy MAA up to 100% of distance to base, provided it is unshielded
                                tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMAA * categories.TECH3, tStartPoint, math.min(iIntelBasedLimit + 20, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]), 'Enemy')
                                if M27Utilities.IsTableEmpty(tEnemies) == false then
                                    --[[local tEnemyNonMAASAM
                                    if M27Utilities.IsTableEmpty(tEnemyAAAndCruisers) == false then
                                        tEnemyNonMAASAM = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3 * categories.STRUCTURE + M27UnitInfo.refCategoryCruiserCarrier, tStartPoint, aiBrain[refiMaxScoutRadius], 'Enemy')
                                    end--]]

                                    for iUnit, oUnit in tEnemies do
                                        if (oUnit[refiStrikeDamageAssigned] or 0) == 0 then
                                            --Dont want to target if already being targeted for some other reason (as risk sending bombers piecemeal)
                                            if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                                if not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true)) and not (IsTargetCoveredByAA(oUnit, tEnemySAMsAndCruisers, 3, tStartPoint)) then
                                                    iCurStrikeDamage = GetMaxStrikeDamageWanted(oUnit)
                                                    iTableIndex = math.min(5, math.ceil(iCurStrikeDamage / 10000))
                                                    table.insert(tTargetsByMaxHealth[iTableIndex], oUnit)
                                                    table.insert(tTargetStrikeDamageByMaxHealth[iTableIndex], iCurStrikeDamage)
                                                    iPossibleTargets = iPossibleTargets + 1
                                                end
                                            end
                                        end
                                    end
                                end

                                if iPossibleTargets == 0 then
                                    --Consider enemy T2 land within 80% of our base
                                    tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat * categories.TECH2 + M27UnitInfo.refCategoryMAA * categories.TECH2, tStartPoint, math.min(iIntelBasedLimit + 20, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.8), 'Enemy')
                                    if M27Utilities.IsTableEmpty(tEnemies) == false then
                                        for iUnit, oUnit in tEnemies do
                                            if (oUnit[refiStrikeDamageAssigned] or 0) == 0 then
                                                --Dont want to target if already being targeted for some other reason (as risk sending bombers piecemeal)
                                                if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                                    if not (IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint)) then
                                                        iCurStrikeDamage = GetMaxStrikeDamageWanted(oUnit)
                                                        iTableIndex = math.min(5, math.ceil(iCurStrikeDamage / 10000))
                                                        table.insert(tTargetsByMaxHealth[iTableIndex], oUnit)
                                                        table.insert(tTargetStrikeDamageByMaxHealth[iTableIndex], iCurStrikeDamage)
                                                        iPossibleTargets = iPossibleTargets + 1
                                                    end
                                                end
                                            end
                                        end
                                    end

                                    --Also add T1 ground AA and t1 mexes within 85% of dist to their base
                                    tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT1Mex + refCategoryAirAA * categories.STRUCTURE, tStartPoint, math.min(iIntelBasedLimit, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.85), 'Enemy')
                                    if M27Utilities.IsTableEmpty(tEnemies) == false then
                                        for iUnit, oUnit in tEnemies do
                                            if (oUnit[refiStrikeDamageAssigned] or 0) == 0 then
                                                --Dont want to target if already being targeted for some other reason (as risk sending bombers piecemeal)
                                                if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                                    if not (IsTargetCoveredByAA(oUnit, tEnemyAAAndCruisers, 3, tStartPoint)) then
                                                        iCurStrikeDamage = GetMaxStrikeDamageWanted(oUnit)
                                                        iTableIndex = math.min(5, math.ceil(iCurStrikeDamage / 10000))
                                                        table.insert(tTargetsByMaxHealth[iTableIndex], oUnit)
                                                        table.insert(tTargetStrikeDamageByMaxHealth[iTableIndex], iCurStrikeDamage)
                                                        iPossibleTargets = iPossibleTargets + 1
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            --Backup for scenarios where get crazy number of strats
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': About to consider tactics for if have loads of idle strats. iPossibleTargets=' .. iPossibleTargets .. '; iStratsNearRallyPoint=' .. iStratsNearRallyPoint)
                            end
                            if iPossibleTargets == 0 and iStratsNearRallyPoint >= 30 then
                                --Assassination mode - target enemy ACU
                                if ScenarioInfo.Options.Victory == "demoralization" then
                                    tEnemies = aiBrain:GetUnitsAroundPoint(categories.COMMAND, tStartPoint, aiBrain[refiMaxScoutRadius], 'Enemy')
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Seeing if enemy ACU can be identified. tEnemies is empty=' .. tostring(M27Utilities.IsTableEmpty(tEnemies)))
                                    end
                                    if M27Utilities.IsTableEmpty(tEnemies) == false then
                                        for iUnit, oUnit in tEnemies do
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Considering ACU unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; Is underwater=' .. tostring(M27UnitInfo.IsUnitUnderwater(oUnit)) .. '; Strike damage that would want=' .. GetMaxStrikeDamageWanted(oUnit))
                                            end
                                            if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                                iCurStrikeDamage = GetMaxStrikeDamageWanted(oUnit)
                                                iTableIndex = math.min(5, math.ceil(iCurStrikeDamage / 10000))
                                                table.insert(tTargetsByMaxHealth[iTableIndex], oUnit)
                                                table.insert(tTargetStrikeDamageByMaxHealth[iTableIndex], iCurStrikeDamage)
                                                iPossibleTargets = iPossibleTargets + 1
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Adding ACU to list of targets. iPossibleTargets=' .. iPossibleTargets)
                                                end
                                            end
                                        end
                                    end
                                end
                                if iPossibleTargets == 0 then
                                    --experimental structures and T3 arti
                                    tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryExperimentalStructure + M27UnitInfo.refCategoryFixedT3Arti, tStartPoint, aiBrain[refiMaxScoutRadius], 'Enemy')
                                    if M27Utilities.IsTableEmpty(tEnemies) then
                                        for iUnit, oUnit in tEnemies do
                                            if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                                iCurStrikeDamage = GetMaxStrikeDamageWanted(oUnit)
                                                iTableIndex = math.min(5, math.ceil(iCurStrikeDamage / 10000))
                                                table.insert(tTargetsByMaxHealth[iTableIndex], oUnit)
                                                table.insert(tTargetStrikeDamageByMaxHealth[iTableIndex], iCurStrikeDamage)
                                                iPossibleTargets = iPossibleTargets + 1
                                            end
                                        end
                                    end
                                end
                                if iPossibleTargets == 0 and M27Utilities.IsTableEmpty(tEnemyAAAndCruisers) == false then
                                    --Target enemy AA within 60% of our base, regardless of if shielded or protected by AA
                                    local iMaxDist = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.6
                                    for iUnit, oUnit in tEnemyAAAndCruisers do
                                        --Make sure we can see this (since we include recently seen but not visible cruisers)
                                        if M27Utilities.CanSeeUnit(aiBrain, oUnit, true) then
                                            if (oUnit[refiStrikeDamageAssigned] or 0) <= 1000 and oUnit:GetFractionComplete() >= 0.5 then
                                                if not (M27UnitInfo.IsUnitUnderwater(oUnit)) then
                                                    --Is the unit within 60% of our base?
                                                    iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition())
                                                    if iCurModDistance <= iMaxDist then

                                                        iCurStrikeDamage = GetMaxStrikeDamageWanted(oUnit)
                                                        iTableIndex = math.min(5, math.ceil(iCurStrikeDamage / 10000))
                                                        table.insert(tTargetsByMaxHealth[iTableIndex], oUnit)
                                                        table.insert(tTargetStrikeDamageByMaxHealth[iTableIndex], iCurStrikeDamage)
                                                        iPossibleTargets = iPossibleTargets + 1
                                                    end
                                                end
                                            end
                                        end
                                    end
                                elseif iPossibleTargets == 0 then
                                    --Enemy has no AA, so target their shields
                                    tEnemies = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedShield, tStartPoint, aiBrain[refiMaxScoutRadius], 'Enemy')
                                    if M27Utilities.IsTableEmpty(tEnemies) == false then
                                        local iMaxDist = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.6
                                        for iUnit, oUnit in tEnemies do
                                            if (oUnit[refiStrikeDamageAssigned] or 0) <= 1000 and oUnit:GetFractionComplete() >= 0.25 then
                                                iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition())
                                                if iCurModDistance <= iMaxDist then
                                                    iCurStrikeDamage = GetMaxStrikeDamageWanted(oUnit)
                                                    iTableIndex = math.min(5, math.ceil(iCurStrikeDamage / 10000))
                                                    table.insert(tTargetsByMaxHealth[iTableIndex], oUnit)
                                                    table.insert(tTargetStrikeDamageByMaxHealth[iTableIndex], iCurStrikeDamage)
                                                    iPossibleTargets = iPossibleTargets + 1
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': iStratsNearRallyPoint=' .. iStratsNearRallyPoint .. '; coordinated targets to consider=' .. iPossibleTargets .. '; will decide on best target if have any')
                        end
                        if iPossibleTargets > 0 then
                            --Chose a target for a coordinated attack; start with lowest priority. If have high priority vulnerable unit then just include these in shortlist
                            for iHealthIndex = 1, 5 do
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Considering all units for iHealthIndex=' .. iHealthIndex .. '; iTargetCount=' .. iTargetCount .. '; Is table for this healthindex empty=' .. tostring(M27Utilities.IsTableEmpty(tTargetsByMaxHealth[iHealthIndex])))
                                end
                                if M27Utilities.IsTableEmpty(tTargetsByMaxHealth[iHealthIndex]) == false then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': iTechLevel=' .. (iTechLevel or 'nil') .. '; iHealthIndex=' .. iHealthIndex .. '; Size of table of targets by max health=' .. table.getn(tTargetsByMaxHealth[iHealthIndex]) .. '; bTargetsContainHighPriorityWithNoAA=' .. tostring(bTargetsContainHighPriorityWithNoAA))
                                    end
                                    for iUnit, oUnit in tTargetsByMaxHealth[iHealthIndex] do
                                        if not (bTargetsContainHighPriorityWithNoAA) or (not (oUnit[refbLastCoveredByAAByTech][3]) and EntityCategoryContains(categories.COMMAND + M27UnitInfo.refCategoryExperimentalStructure + M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategorySML, oUnit.UnitId)) then
                                            AddUnitToShortlist(oUnit, iTechLevel, M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tRallyPoint), tTargetStrikeDamageByMaxHealth[iHealthIndex][iUnit])
                                        end
                                    end
                                end
                                if iTargetCount > 0 then
                                    break
                                end
                            end
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': iPossibleTarget=' .. iPossibleTargets .. '; iTargetCount=' .. iTargetCount .. '; iStratsNearRallyPoint=' .. iStratsNearRallyPoint)
                            end

                            --Launch co-ordinated attack against the targets
                            local oCurTarget, oCurBomber, iTargetMaxHealth
                            local iLoopStartAvailableBombers, iLowestPriority, iClosestDistance, oClosestDistance
                            local iRemainingStrikeDamageAvailable
                            local iStrikeDamageWanted, iMinStrikeDamageNeeded
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': About to send strats on coordinated attack. iStratsNearRallyPoint=' .. iStratsNearRallyPoint .. '; iTargetCount=' .. iTargetCount)
                            end

                            local iAverageStrikeDamage = 0
                            local iCurStrikeDamage, iAOE
                            local iTotalStrikeDamage = 0
                            for iBomber, oBomber in tStratsNearRallyPoint do
                                iAOE, iCurStrikeDamage = M27UnitInfo.GetBomberAOEAndStrikeDamage(oBomber)
                                iTotalStrikeDamage = iTotalStrikeDamage + iCurStrikeDamage
                            end
                            if iStratsNearRallyPoint > 0 then
                                iAverageStrikeDamage = iTotalStrikeDamage / iStratsNearRallyPoint
                            end

                            while iStratsNearRallyPoint > 0 do
                                iLoopStartAvailableBombers = iStratsNearRallyPoint

                                iLowestPriority = 1000
                                iClosestDistance = 100000
                                oClosestDistance = nil
                                for iEntry, tSubtable in aiBrain[reftBomberShortlistByTech][iTechLevel] do
                                    if tSubtable[refiShortlistPriority] <= iLowestPriority then
                                        iCurModDistance = tSubtable[refiBomberDefenceModDistance]
                                        if tSubtable[refiShortlistPriority] < iLowestPriority then
                                            iClosestDistance = iCurModDistance
                                            oClosestDistance = tSubtable[refiShortlistUnit]
                                            iTargetMaxHealth = tSubtable[refiShortlistStrikeDamageWanted]
                                        else
                                            if iCurModDistance < iClosestDistance then
                                                iClosestDistance = iCurModDistance
                                                oClosestDistance = tSubtable[refiShortlistUnit]
                                                iTargetMaxHealth = tSubtable[refiShortlistStrikeDamageWanted]
                                            end
                                        end
                                    end
                                end

                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': iStratsNearRallyPoint=' .. iStratsNearRallyPoint .. '; iClosestDistance=' .. iClosestDistance)
                                end

                                if oClosestDistance then
                                    --Issue co-ordinated attack if we have enough damage to kill it
                                    iRemainingStrikeDamageAvailable = iStratsNearRallyPoint * iAverageStrikeDamage --Approximation - correct if we dont have mixture of different strat bomber techs
                                    iStrikeDamageWanted = GetMaxStrikeDamageWanted(oClosestDistance)

                                    if not (oClosestDistance[refbLastCoveredByAAByTech][3]) and EntityCategoryContains(categories.COMMAND + M27UnitInfo.refCategoryExperimentalStructure + M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategorySML, oClosestDistance.UnitId) then
                                        iMinStrikeDamageNeeded = math.min(35000, iStrikeDamageWanted * 0.5)
                                    else
                                        iMinStrikeDamageNeeded = iStrikeDamageWanted
                                    end

                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Issuing coordinated attack on oClosestDistance=' .. oClosestDistance.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oClosestDistance) .. ' if we have enough strike damage; iStrikeDamageWanted=' .. iStrikeDamageWanted .. '; iRemainingStrikeDamageAvailable=' .. iRemainingStrikeDamageAvailable .. '; iMinStrikeDamageNeeded=' .. iMinStrikeDamageNeeded)
                                    end
                                    if iRemainingStrikeDamageAvailable >= math.min(75000, iMinStrikeDamageNeeded) or oClosestDistance[refiStrikeDamageAssigned] > 1000 then
                                        --Have enough strats to attack and kill in 1 hit (or dealing with something with so high health that it probably has multiple shields that will fail due to bomber aoe)
                                        while oClosestDistance[refiStrikeDamageAssigned] <= iStrikeDamageWanted do
                                            --Get the first bomber
                                            oCurBomber = tStratsNearRallyPoint[iStratsNearRallyPoint]
                                            TargetUnit(oClosestDistance, oCurBomber, iLowestPriority, iTargetMaxHealth)
                                            iStrikeDamageWanted = iStrikeDamageWanted - M27UnitInfo.GetUnitStrikeDamage(oCurBomber)
                                            iStratsNearRallyPoint = iStratsNearRallyPoint - 1
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Told bomber ' .. oCurBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oCurBomber) .. ' to target unit ' .. oClosestDistance.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oClosestDistance) .. '; iStratsNearRallyPoint after this=' .. iStratsNearRallyPoint)
                                            end
                                            if iStratsNearRallyPoint <= 0 then
                                                break
                                            end
                                        end
                                    else
                                        --Dont want to keep trying to find targets as dont have enough bombers to kill outright
                                        break
                                    end
                                end

                                if iLoopStartAvailableBombers <= iStratsNearRallyPoint or iStratsNearRallyPoint == 0 then
                                    --We havent found any new targets so abort
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': No new targets so will abort loop now')
                                    end
                                    break
                                end
                            end
                        end
                    end
                end

                if iAvailableBombers > 0 then
                    --Couldn't find any targets, send bombers back to rally point

                    --Tell any spare bombers to go to the nearest rally point if hteyre not there already, and treat it as ahving a low priority target for tracking purposes (for how much shield damage to ignore)
                    --Order any spare bombers that dont have a current target to go to nearest rally point; if are in air domination mode then instead send them on attack-move to enemy base
                    local tCurTarget, oNavigator
                    tRallyPoint = GetAirRallyPoint(aiBrain)
                    for iBomber, oBomber in tBombersOfTechLevel do
                        --[[if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                            tRallyPoint = { aiBrain[M27MapInfo.reftPrimaryEnemyBaseLocation][1], aiBrain[M27MapInfo.reftPrimaryEnemyBaseLocation][2], aiBrain[M27MapInfo.reftPrimaryEnemyBaseLocation][3] }
                        else
                            tRallyPoint = M27Logic.GetNearestRallyPoint(aiBrain, oBomber:GetPosition())
                        end--]]
                        --if M27UnitInfo.GetUnitTechLevel(oBomber) == 4 then bDebugMessages = true end
                        oNavigator = oBomber:GetNavigator()
                        if oNavigator and oNavigator.GetCurrentTargetPos then
                            tCurTarget = oNavigator:GetCurrentTargetPos()
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': oBomber=' .. oBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oBomber) .. '; tCurTarget=' .. repru((tCurTarget or { 'nil' })) .. '; tRallyPoint=' .. repru((tRallyPoint or { 'nil' })) .. '; oBomber position=' .. repru(oBomber:GetPosition()))
                        end
                        if (M27Utilities.IsTableEmpty(tCurTarget) == false and (tCurTarget[1] == tRallyPoint[1] and tCurTarget[3] == tRallyPoint[3])) or M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), tRallyPoint) <= 30 then
                            --Do nothing - already moving to nearest rally point or near it already
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Bomber already near or moving to rally point; distance to rally point=' .. repru(tRallyPoint) .. '; tCurTarget=' .. repru(tCurTarget))
                            end
                        else
                            --if oBomber.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBomber) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end
                            --Move to nearest rally point
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Telling ' .. oBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oBomber) .. ' to move to nearest rapply point=' .. repru(tRallyPoint))
                            end
                            M27Utilities.IssueTrackedClearCommands({ oBomber })
                            if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance and M27UnitInfo.GetUnitTechLevel(oBomber) <= 2 then
                                IssueAggressiveMove({ oBomber }, tRallyPoint)
                            else
                                IssueMove({ oBomber }, tRallyPoint)
                            end
                        end
                        if M27Config.M27ShowUnitNames == true and oBomber.GetUnitId then
                            M27PlatoonUtilities.UpdateUnitNames({ oBomber }, oBomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oBomber) .. ':NoTargetReturnToBase')
                        end
                    end
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code')
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

--AirBomberManagerOld - removed from v42 (wasnt being used for some time before)

function AirAAManager(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AirAAManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetGameTimeSeconds() >= 290 then bDebugMessages = true end
    --if M27Utilities.IsTableEmpty(aiBrain[reftAvailableAirAA]) == false then bDebugMessages = true end

    local iMAANearACURange = 25
    local bACUUnderShield = false
    if M27Logic.IsLocationUnderFriendlyFixedShield(aiBrain, M27Utilities.GetACU(aiBrain):GetPosition()) then
        bACUUnderShield = true
    end

    if aiBrain[refbMercySightedRecently] then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Mercies sighted recently so will defend threats near ACU at a greater range')
        end
        iMAANearACURange = 0
    elseif bACUUnderShield then
        iMAANearACURange = 50
    end
    local iEnemyGroundAASearchRange = 90
    local iOurHighestAirAATech = 1
    if M27Utilities.IsTableEmpty(aiBrain[reftAvailableAirAA]) == false then
        if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryAirAA * categories.TECH3, aiBrain[reftAvailableAirAA])) == false then
            iOurHighestAirAATech = 3
        elseif M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryAirAA * categories.TECH2, aiBrain[reftAvailableAirAA])) == false then
            iOurHighestAirAATech = 2
        end
    end

    aiBrain[refbNonScoutUnassignedAirAATargets] = false

    --Does ACU have Ground AA near it?
    if not (aiBrain.M27IsDefeated) and M27Logic.iTimeOfLastBrainAllDefeated < 10 then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': AirAA manager start')
        end

        --Record furthestAAFromBase value (used e.g. for AirAA logic below to limit defensive range, and for gunship logic so they stay close to base if we are far behind on air
        local iFurthestAAFromBase = 0 --Base value
        local iAACategory

        if aiBrain[refiEnemyAirAAThreat] <= 600 then iAACategory = M27UnitInfo.refCategoryStructureAA
        elseif aiBrain[refiEnemyAirAAThreat] <= 6000 then
            iAACategory = M27UnitInfo.refCategoryStructureAA * categories.TECH3 + M27UnitInfo.refCategoryStructureAA * categories.TECH2
        else
            --Need AOE base air defence to help fight off enemy air threat
            iAACategory = M27UnitInfo.refCategoryStructureAA * categories.TECH3
        end
        local tOurFixedAA = aiBrain:GetListOfUnits(iAACategory, false, true)

        if M27Utilities.IsTableEmpty(tOurFixedAA) == false then
            local iCurDist
            for iUnit, oUnit in tOurFixedAA do
                iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) + M27UnitInfo.GetUnitAARange(oUnit)
                if iCurDist > iFurthestAAFromBase then
                    iFurthestAAFromBase = iCurDist
                end
            end
        end
        aiBrain[refiOurFurthestAAStructureFromBase] = iFurthestAAFromBase

        local tACUPos
        if M27Utilities.GetACU(aiBrain) then
            tACUPos = M27Utilities.GetACU(aiBrain):GetPosition()
        else
            tACUPos = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        end
        local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local tNearbyMAA
        if iMAANearACURange > 0 then
            tNearbyMAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, tACUPos, iMAANearACURange, 'Ally')
        end
        if M27Utilities.IsTableEmpty(tNearbyMAA) == false then
            --If we think ACU is relatively safe then use a much smaller range
            if bACUUnderShield and aiBrain[refiAirAAWanted] >= 5 and (not (M27UnitInfo.IsUnitValid(aiBrain[refoNearestEnemyAirThreat])) or not (EntityCategoryContains(categories.BOMBER + categories.GROUNDATTACK, aiBrain[refoNearestEnemyAirThreat].UnitId))) then
                aiBrain[refiNearToACUThreshold] = 20
            else
                aiBrain[refiNearToACUThreshold] = iAssistNearbyUnitRange
            end
        else
            aiBrain[refiNearToACUThreshold] = 90
            if aiBrain[refbMercySightedRecently] then
                aiBrain[refiNearToACUThreshold] = 150
            end
        end
        if aiBrain[refbFarBehindOnAir] and not(aiBrain[refbMercySightedRecently]) and aiBrain[refiNearToACUThreshold] >= 60 then
            aiBrain[refiNearToACUThreshold] = math.max(50, math.min(aiBrain[refiNearToACUThreshold] - 20, 75))
        end

        local iEnemyAirSearchRange = aiBrain[refiMaxScoutRadius]
        if M27MapInfo.bNoRushActive then
            iEnemyAirSearchRange = math.min(iEnemyAirSearchRange, M27MapInfo.iNoRushRange)
        end

        local tEnemyAirUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAllAir, tStartPosition, iEnemyAirSearchRange, 'Enemy')

        local iAirThreatShortfall = 0
        local tValidEnemyAirThreats = {}
        local bDidntHaveAnyAirAAToStartWith = false
        local refiDistance = 'AirAADistance'

        --Hold back AirAA units from most air threats if we need to build up our force
        local bIgnoreUnlessEmergencyThreat = false
        local iIgnoredThreats = 0
        --if M27Utilities.IsTableEmpty(aiBrain[reftAvailableAirAA]) == false and table.getsize(aiBrain[reftAvailableAirAA]) >= 20 then bDebugMessages = true end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Will hold back AirAA if need to build up our force.  aiBrain[refbMercySightedRecently]=' .. tostring(aiBrain[refbMercySightedRecently]) .. '; aiBrain[refiHighestEnemyAirThreat]=' .. aiBrain[refiHighestEnemyAirThreat] .. '; aiBrain[refiOurMassInAirAA]=' .. aiBrain[refiOurMassInAirAA])
        end
        if not (aiBrain[refbMercySightedRecently]) and aiBrain[refiHighestEnemyAirThreat] >= 150 and not ((aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill)) then
            --[[if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.toAllyBrains]) then
                for iAlly, oAllyBrain in aiBrain[M27Overseer.toAllyBrains] do
                    if oAllyBrain.M27AI then
                        iTeamAirAAMass = iTeamAirAAMass + oAllyBrain[refiOurMassInAirAA]
                    end
                end
            end--]]

            if M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subrefiFriendlyAirAAThreat] < aiBrain[refiEnemyAirAAThreat] then
                --Have lost air control so only engage threats nearby
                bIgnoreUnlessEmergencyThreat = true
                if bDebugMessages == true then LOG(sFunctionRef..': Our subteam airaa threat='..M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subrefiFriendlyAirAAThreat]..'; Enemy AirAA threat='..aiBrain[refiEnemyAirAAThreat]) end
            end

            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Will ignore threats that arent emergency air threats')
            end

        end

        if M27Utilities.IsTableEmpty(tEnemyAirUnits) == false then
            if bDebugMessages == true then

                --Below is all for debug!
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Will list out any friendly bombers and the distance of the nearest enemy airAA unit to them')
                end
                local tFriendlyT3Bombers = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryBomber * categories.TECH3, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Ally')
                local tEnemyAirAA = EntityCategoryFilterDown(M27UnitInfo.refCategoryAirAA, tEnemyAirUnits)
                local oNearestEnemyAirAA
                if M27Utilities.IsTableEmpty(tFriendlyT3Bombers) == false then
                    for iT3Bomber, oT3Bomber in tFriendlyT3Bombers do
                        LOG(sFunctionRef .. ': Bomber=' .. oT3Bomber.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oT3Bomber) .. '; Position=' .. repru(oT3Bomber:GetPosition()))
                        if M27Utilities.IsTableEmpty(tEnemyAirAA) == false then
                            oNearestEnemyAirAA = M27Utilities.GetNearestUnit(tEnemyAirAA, oT3Bomber:GetPosition(), aiBrain)
                            LOG(sFunctionRef .. ': Nearest enemy airAA=' .. oNearestEnemyAirAA.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oNearestEnemyAirAA) .. '; position=' .. repru(oNearestEnemyAirAA:GetPosition()) .. '; distance to bomber=' .. M27Utilities.GetDistanceBetweenPositions(oNearestEnemyAirAA:GetPosition(), oT3Bomber:GetPosition()))
                        else
                            LOG('No enemy AirAA detected anywhere')
                        end
                    end
                end
                --End of debug
            end

            --Is any subteammate ACU far enough away from their base that we want to check for air threats near it?
            local iDistanceFromACUToStart = 0
            if aiBrain[refiNearToACUThreshold] > 0 then
                iDistanceFromACUToStart = M27Utilities.GetDistanceBetweenPositions(tStartPosition, tACUPos)
                local tAllyACUPos
                local iAllyDistFromOurStart
                for iAllyBrain, aiAllyBrain in M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subreftoFriendlyBrains] do
                    if not(aiAllyBrain == aiBrain) and not (aiAllyBrain:IsDefeated()) and not (aiBrain.M27IsDefeated) then
                        --redundancy in case issue with toallybrains being updated
                        if M27Utilities.GetACU(aiAllyBrain) then
                            tAllyACUPos = M27Utilities.GetACU(aiAllyBrain):GetPosition()
                        else
                            tAllyACUPos = M27MapInfo.PlayerStartPoints[aiAllyBrain.M27StartPositionNumber]
                        end

                        --Only consider teammates ACUs if either 2 teams; or the teammate is nearer to us than the nearest enemy
                        iAllyDistFromOurStart = M27Utilities.GetDistanceBetweenPositions(tAllyACUPos, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                        if M27Team.iTotalTeamCount <= 2 or iAllyDistFromOurStart <= math.max(400, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] + 50) or aiBrain[M27Overseer.tiDistToPlayerByIndex][aiAllyBrain:GetArmyIndex()] <= math.max(500, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] + 50) then
                            if M27Utilities.IsTableEmpty(tAllyACUPos) == false and M27Utilities.IsTableEmpty(M27MapInfo.PlayerStartPoints[aiAllyBrain.M27StartPositionNumber]) == false then

                                iDistanceFromACUToStart = math.max(iDistanceFromACUToStart, M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiAllyBrain.M27StartPositionNumber], tAllyACUPos))
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Brain start number=' .. aiAllyBrain.M27StartPositionNumber .. '; distance from enemy air unit to ACU of this player=' .. M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiAllyBrain.M27StartPositionNumber], M27Utilities.GetACU(aiAllyBrain):GetPosition()))
                                end
                            end
                        end
                    end
                end
            end
            local iDistanceFromEnemyStartToOurStart = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]
            local iMapMidpointDistance = iDistanceFromEnemyStartToOurStart * 0.5

            local refoUnit = 'AirAAUnit'

            local iEnemyUnitCount = 0
            local tUnitCurPosition
            local iDistanceToACU

            local iCurTargetModDistanceFromStart
            local bShouldAttackThreat
            local iCurDistanceToStartOrACU
            local tEnemyGroundAA
            local bCloseEnoughToConsider
            local tFriendlyGroundUnits
            local tFriendlyPriorityDefence = aiBrain:GetUnitsAroundPoint(categories.COMMAND + categories.EXPERIMENTAL - M27UnitInfo.refCategorySatellite, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Ally')
            local iOtherUnitMaxDistFromBase = aiBrain[refiMaxScoutRadius]
            if bIgnoreUnlessEmergencyThreat and aiBrain[refbFarBehindOnAir] and aiBrain[refiEnemyAirAAThreat] <= 500 then iOtherUnitMaxDistFromBase = math.max(75, aiBrain[refiOurFurthestAAStructureFromBase]) end
            local iOtherUnitCategoriesToDefend = M27UnitInfo.refCategoryIndirectT3 + categories.STRUCTURE * categories.TECH3 + M27UnitInfo.refCategoryBomber * categories.TECH3
            local tOtherUnitsToDefend = aiBrain:GetUnitsAroundPoint(iOtherUnitCategoriesToDefend, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iOtherUnitMaxDistFromBase, 'Ally')
            local bCheckForOtherUnitsToDefend = false

            local iOtherUnitDefenceRange = 70
            if bIgnoreUnlessEmergencyThreat then
                iOtherUnitDefenceRange = 50
            end

            local iMinMAAFriendlyThreatNeeded = math.max(150, math.min(1600, aiBrain[refiEnemyAirAAThreat] * 0.1))
            local iFriendlyMAASearchRange = math.max(80, iOtherUnitDefenceRange)


            function RefineListOfUnitsToDefend(tUnits, iSubteamWanted)
                local bKeepUpdating = true
                local tRevisedList = {}
                local iCurDist
                local bInclude
                for iUnit, oUnit in tUnits do
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering whether to keep unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' in the list of units to defend. bIgnoreUnlessEmergencyThreat='..tostring(bIgnoreUnlessEmergencyThreat)..'; aiBrain[refbFarBehindOnAir]='..tostring(aiBrain[refbFarBehindOnAir])..'; aiBrain[refiEnemyAirAAThreat]='..aiBrain[refiEnemyAirAAThreat]) end
                    if oUnit:GetAIBrain().M27Subteam == iSubteamWanted and (not(bIgnoreUnlessEmergencyThreat) or not(aiBrain[refbFarBehindOnAir]) or aiBrain[refiEnemyAirAAThreat] <= 500 or EntityCategoryContains(categories.COMMAND, oUnit.UnitId)) then
                        --Do we have significant friendly AA threat nearby that can help us? Or do we have air control? or is our ACU under threat?
                        bInclude = false
                        if aiBrain[refbHaveAirControl] or (EntityCategoryContains(categories.COMMAND, oUnit.UnitId) and aiBrain[M27Overseer.refbACUVulnerableToAirSnipe]) then
                            bInclude = true
                        else
                            local tFriendlyGroundAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA - categories.TECH1, oUnit:GetPosition(), iFriendlyMAASearchRange, 'Ally')
                            if bDebugMessages == true then LOG(sFunctionRef..': iFriendlyMAASearchRange='..iFriendlyMAASearchRange..'; Total friendly ground AA threat nearby='..M27Logic.GetAirThreatLevel(aiBrain, tFriendlyGroundAA, false, false, true, false, false, nil, nil, nil, nil, false, false)) end
                            if M27Utilities.IsTableEmpty(tFriendlyGroundAA) == false then
                                if M27Logic.GetAirThreatLevel(aiBrain, tFriendlyGroundAA, false, false, true, false, false, nil, nil, nil, nil, false, false) >= 1600 then
                                    bInclude = true
                                end
                            end
                        end
                        if bInclude then
                            table.insert(tRevisedList, oUnit)
                            if bDebugMessages == true then LOG(sFunctionRef..': Added unit to revised list') end
                        end
                    end
                end
                if bDebugMessages == true then
                    if M27Utilities.IsTableEmpty(tRevisedList) then LOG(sFunctionRef..': tRevisedList is empty')
                    else
                        LOG(sFunctionRef..': Size of tRevisedList='..table.getn(tRevisedList))
                    end
                end
                return tRevisedList
            end
            if M27Utilities.IsTableEmpty(tFriendlyPriorityDefence) == false then
                tFriendlyPriorityDefence = RefineListOfUnitsToDefend(tFriendlyPriorityDefence, aiBrain.M27Subteam)
            end

            if M27Utilities.IsTableEmpty(tOtherUnitsToDefend) == false then
                if bDebugMessages == true then LOG(sFunctionRef..': Size of tOtherUnitsToDefend before refinement='..table.getn(tOtherUnitsToDefend)) end
                tOtherUnitsToDefend = RefineListOfUnitsToDefend(tOtherUnitsToDefend, aiBrain.M27Subteam)

                if M27Utilities.IsTableEmpty(tOtherUnitsToDefend) == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': Size of tOtherUnitsToDefend after refinement='..table.getn(tOtherUnitsToDefend)) end
                    bCheckForOtherUnitsToDefend = true
                end
            end


            if bDebugMessages == true then
                LOG(sFunctionRef .. ': total enemy threats=' .. table.getn(tEnemyAirUnits) .. '; total vailable inties=' .. table.getn(aiBrain[reftAvailableAirAA]))
            end

            local iCloseToBaseRange = math.max(80, math.min(130, aiBrain[refiBomberDefenceCriticalThreatDistance] - 15))
            --Adjust close to base range for chokepoints
            if not (M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27MapInfo.tiPlannedChokepointsByDistFromStart])) then
                local iCurChokepointDistance
                local iFurthestChokepointDistance = 0
                local iClosestChokepointDistance = 10000

                for iBrain, oBrain in M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subreftoFriendlyBrains] do
                    if oBrain.M27AI and oBrain[M27Overseer.refiDefaultStrategy] == M27Overseer.refStrategyTurtle and oBrain[M27MapInfo.refiAssignedChokepointFirebaseRef] then
                        iCurChokepointDistance = M27Utilities.GetDistanceBetweenPositions(oBrain[M27MapInfo.reftChokepointBuildLocation], tStartPosition)
                        if iCurChokepointDistance > iFurthestChokepointDistance then
                            iFurthestChokepointDistance = iCurChokepointDistance
                        end
                        if iCurChokepointDistance < iClosestChokepointDistance then
                            iClosestChokepointDistance = iCurChokepointDistance
                        end
                    end
                end
                if iFurthestChokepointDistance >= iClosestChokepointDistance then
                    iCloseToBaseRange = iClosestChokepointDistance
                    if not(aiBrain[refbFarBehindOnAir]) then
                        iCloseToBaseRange = math.max(iCloseToBaseRange, math.min(iFurthestChokepointDistance + 40, aiBrain[refiClosestEnemyDangerousAADistToOurBase] - 70))
                    end
                    if aiBrain[M27Overseer.refiDefaultStrategy] == M27Overseer.refStrategyTurtle and aiBrain[refiEnemyAirToGroundThreat] >= 12000 and not(aiBrain[refbFarBehindOnAir]) then
                        if aiBrain[refiOurMassInAirAA] > aiBrain[refiEnemyAirAAThreat] * 0.75 and aiBrain[refbHaveAirControl] then
                            iCloseToBaseRange = math.max(iCloseToBaseRange, math.min(iClosestChokepointDistance + 90, math.max(iClosestChokepointDistance + 65, aiBrain[refiClosestEnemyDangerousAADistToOurBase] - 70)))
                        else
                            iCloseToBaseRange = math.max(iCloseToBaseRange, iClosestChokepointDistance + 65)
                        end
                    end
                end
            end

            --Adjust base defence range further if is <=200 and have lots of available AirAA units
            aiBrain[refbFarBehindOnAir] = false --gets updated below if we are far behind
            if bDebugMessages == true then LOG(sFunctionRef..': Considering whether to adjust close to base range, aiBrain[refiEnemyAirAAThreat]='..aiBrain[refiEnemyAirAAThreat]..'; aiBrain[refiOurMassInAirAA]='..aiBrain[refiOurMassInAirAA]..'; iCloseToBaseRange pre adjust='..iCloseToBaseRange..'; M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subrefiFriendlyAirAAThreat]='..M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subrefiFriendlyAirAAThreat]) end
            if aiBrain[refiOurMassInAirAA] >= 3000 and M27Utilities.IsTableEmpty(aiBrain[reftAvailableAirAA]) == false and (aiBrain[refiOurMassInAirAA] >= 6000 or M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subrefiFriendlyAirAAThreat] > 0.7 * aiBrain[refiEnemyAirAAThreat]) then
                if iCloseToBaseRange < 200 then
                    local iAvailableAirAA = 0
                    for iUnit, oUnit in aiBrain[reftAvailableAirAA] do
                        iAvailableAirAA = iAvailableAirAA + 1
                    end
                    if iAvailableAirAA >= 50 then
                        iCloseToBaseRange = math.min(180, math.max(iCloseToBaseRange, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.3, aiBrain[refiBomberDefenceModDistance]))
                    end
                end
            elseif M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subrefiFriendlyAirAAThreat] < 0.75 * aiBrain[refiEnemyAirAAThreat] and aiBrain[refiOurMassInAirAA] <= 6000 then
                --Enemy significantly outnumbers us and we dont have many airaa units, so want to keep air units close to base
                if iCloseToBaseRange > 70 then
                    iCloseToBaseRange = math.min(iCloseToBaseRange, math.max(70, iFurthestAAFromBase))
                end

                --Also set flag that are far behind from air if relevant
                if bDebugMessages == true then LOG(sFunctionRef..': Considering whether to limit the close to base range based on our AA structures. iCloseToBaseRange pre adjust='..iCloseToBaseRange..'; iFurthestAAFromBase='..iFurthestAAFromBase) end
                if not(aiBrain[refbHaveAirControl]) and M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subrefiFriendlyAirAAThreat] < 0.95 * aiBrain[refiEnemyAirAAThreat] then
                    --If we have at least 200 asf equivalent in AA threat then make this test more restrictive
                    if aiBrain[refiOurMassInAirAA] <= 60000 or M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subrefiFriendlyAirAAThreat] < 0.65 * aiBrain[refiEnemyAirAAThreat] or aiBrain:GetCurrentUnits(refCategoryAirAA * categories.TECH3) <= 150  then
                        aiBrain[refbFarBehindOnAir] = true
                    end
                end
            end


            --Record enemy unseen cruisers/carriers that have had sight of recently
            local iRecentlySeenCruiserSearchRange = 100
            local tAllRecentlySeenCruisers = {}
            --Add any pond AA recently seen but not currently visible to this
            if bDebugMessages == true then LOG(sFunctionRef..': Is table of enemy untis by pond empty='..tostring(M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond]))) end
            if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond]) == false then
                for iPond, tEnemyUnits in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond] do
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering iPond='..iPond..'; is table of enemy units empty for this='..tostring(M27Utilities.IsTableEmpty(tEnemyUnits))) end
                    if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                        local tEnemyT2PlusNavalAA = EntityCategoryFilterDown(M27UnitInfo.refCategoryCruiserCarrier, M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond][iPond])
                        if bDebugMessages == true then LOG(sFunctionRef..': Is table of cruisers and carriers empty='..tostring(M27Utilities.IsTableEmpty(tEnemyT2PlusNavalAA))) end
                        if M27Utilities.IsTableEmpty(tEnemyT2PlusNavalAA) == false then
                            for iUnit, oUnit in tEnemyT2PlusNavalAA do
                                if bDebugMessages == true then LOG(sFunctionRef..': Considering enemy unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Is valid='..tostring(M27UnitInfo.IsUnitValid(oUnit))..'; Is last known position empty='..tostring(M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftLastKnownPosition]))..'; Can see unit='..tostring(M27Utilities.CanSeeUnit(aiBrain, oUnit, true))) end
                                if M27UnitInfo.IsUnitValid(oUnit) and M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftLastKnownPosition]) == false and not(M27Utilities.CanSeeUnit(aiBrain, oUnit, true)) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': About to add naval unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to AA threats') end
                                    table.insert( tAllRecentlySeenCruisers, oUnit)
                                end
                            end
                        end
                    end
                end
            end

            --Cap operational range of anti-air (added v63 to try and limit how far we attack when we have air control as already have some other logic for when far behind on air
            local iMaxModDistanceRange = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] --NOTE: This is only used for non-emergency targets
            if aiBrain[refiClosestEnemyDangerousAADistToOurBase] < iMaxModDistanceRange then
                iMaxModDistanceRange = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] - 70
                --Get closest friendly air and land experimental to enemy base
                local tCurBrainExperimentals
                local iFurthestExperimental = 0
                local iCurModDistance
                for iBrain, oBrain in M27Team.tSubteamData[aiBrain.M27Subteam][M27Team.subreftoFriendlyBrains] do
                    if not(oBrain.M27IsDefeated) then
                        tCurBrainExperimentals = oBrain:GetListOfUnits(categories.EXPERIMENTAL * M27UnitInfo.refCategoryAirNonScout + M27UnitInfo.refCategoryLandExperimental, false, true)
                        if M27Utilities.IsTableEmpty(tCurBrainExperimentals) == false then
                            for iUnit, oUnit in tCurBrainExperimentals do
                                iCurModDistance = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition())
                                if iCurModDistance > iFurthestExperimental then iFurthestExperimental = iCurModDistance end
                            end
                        end
                    end
                end
                iMaxModDistanceRange = math.max(iMaxModDistanceRange, iFurthestExperimental + 30)
            end





            --Create a table with all air threats and their distance
            for iUnit, oUnit in tEnemyAirUnits do
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Considering if we want to attack enemy unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' that is at position ' .. repru(oUnit:GetPosition()) .. ' which is ' .. M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) .. '; iCloseToBaseRange=' .. iCloseToBaseRange)
                end
                bShouldAttackThreat = false
                if not (oUnit.Dead) and oUnit.GetUnitId then
                    bCloseEnoughToConsider = false
                    tUnitCurPosition = oUnit:GetPosition()
                    iCurDistanceToStartOrACU = M27Utilities.GetDistanceBetweenPositions(tStartPosition, tUnitCurPosition)

                    --Adjust how close a threat we consider it if its near any of our priority units to defend and could damage them
                    if iDistanceFromACUToStart > aiBrain[refiNearToACUThreshold] and (not(bIgnoreUnlessEmergencyThreat) or EntityCategoryContains(M27UnitInfo.refCategoryBomber + M27UnitInfo.refCategoryGunship + M27UnitInfo.refCategoryTorpBomber + M27UnitInfo.refCategoryTransport, oUnit.UnitId)) then
                        --Check if enemy air unit is near our ACU or a friendly ACU and could damage it (if we are considering emergency threats only)
                        --if iCurDistanceToStartOrACU > iDistanceFromACUToStart then
                        iDistanceToACU = M27Utilities.GetDistanceBetweenPositions(tACUPos, tUnitCurPosition)
                        if iDistanceToACU <= aiBrain[refiNearToACUThreshold] then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Have enemy air unit near our ACU; oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; iDistanceToACU=' .. iDistanceToACU .. '; iCurDistanceToStartOrACU=' .. iCurDistanceToStartOrACU)
                            end
                            iCurDistanceToStartOrACU = math.min(iCurDistanceToStartOrACU, iDistanceToACU)
                        end
                        --Check if enemy air is near allied ACU or experimental (but prioritise enemies really close to our base instead)
                        if M27Utilities.IsTableEmpty(tFriendlyPriorityDefence) == false then
                            for iPriorityDefence, oPriorityDefence in tFriendlyPriorityDefence do
                                --(have already checked if have friedly AA nearby above in order to generate tFriendlyPriorityDefence)
                                iCurDistanceToStartOrACU = math.min(iCurDistanceToStartOrACU, 60 + M27Utilities.GetDistanceBetweenPositions(tUnitCurPosition, oPriorityDefence:GetPosition()))

                                --Note - hardcoded adj - will increase dist on enemy near ally ACU by 60, and will consider helping against air units near ally ACU if within 130 (so within 70) without doing AA check at all
                            end
                        end
                        --[[if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.toAllyBrains]) == false then
                    for iAllyBrain, aiAllyBrain in aiBrain[M27Overseer.toAllyBrains] do
                        iDistanceToACU = math.min(iDistanceToACU, M27Utilities.GetDistanceBetweenPositions(tUnitCurPosition, M27Utilities.GetACU(aiAllyBrain):GetPosition()))
                    end
                    iCurDistanceToStartOrACU = math.min(iCurDistanceToStartOrACU, iDistanceToACU + 75)
                end--]]
                        --end


                    end
                    iCurTargetModDistanceFromStart = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tUnitCurPosition)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': iCurTargetModDistanceFromStart=' .. iCurTargetModDistanceFromStart .. '; iMapMidpointDistance=' .. iMapMidpointDistance .. '; iCurDistanceToStartOrACU=' .. iCurDistanceToStartOrACU .. '; aiBrain[refiNearToACUThreshold]=' .. (aiBrain[refiNearToACUThreshold] or 'nil') .. '; iCloseToBaseRange=' .. iCloseToBaseRange)
                    end
                    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                        --Dont care about AA or distance, just want to kill any air unit
                        bShouldAttackThreat = true
                    else
                        if iCurDistanceToStartOrACU <= math.max(aiBrain[refiNearToACUThreshold], iCloseToBaseRange) then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': We want to attack this unit because its close to our ACU or base or ally ACU or experimental')
                            end
                            bShouldAttackThreat = true
                            iCurTargetModDistanceFromStart = iCurDistanceToStartOrACU
                        else
                            --AirAA Near our gunships?
                            if M27UnitInfo.IsUnitValid(aiBrain[refoFrontGunship]) and EntityCategoryContains(M27UnitInfo.refCategoryAirAA + M27UnitInfo.refCategoryGunship, oUnit.UnitId) and M27Utilities.GetDistanceBetweenPositions(aiBrain[refoFrontGunship]:GetPosition(), oUnit:GetPosition()) <= 60 then
                                bShouldAttackThreat = true
                                if bDebugMessages == true then LOG(sFunctionRef..': Air unit is close to our front gunship '..aiBrain[refoFrontGunship].UnitId..M27UnitInfo.GetUnitLifetimeCount(aiBrain[refoFrontGunship])..', distance='..M27Utilities.GetDistanceBetweenPositions(aiBrain[refoFrontGunship]:GetPosition(), oUnit:GetPosition())) end
                            else


                                --Ignore enemy AA if near another type of unit to defend
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Will ignore enemy AA if near another type of unit we want to defend. bCheckForOtherUnitsToDefend=' .. tostring((bCheckForOtherUnitsToDefend or false)) .. '; iOtherUnitDefenceRange=' .. (iOtherUnitDefenceRange or 'nil'))
                                end
                                if bCheckForOtherUnitsToDefend then
                                    for iDefend, oDefend in tOtherUnitsToDefend do
                                        if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oDefend:GetPosition()) <= iOtherUnitDefenceRange then
                                            bShouldAttackThreat = true
                                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy air unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' is distance '..M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oDefend:GetPosition())..' from oDefend='..oDefend.UnitId..M27UnitInfo.GetUnitLifetimeCount(oDefend)..' so will attack it') end
                                            break
                                        end
                                    end
                                    --v62 - replaced getunitsaroundpoint approach with going through the predefined table so we arent calculating MAA threat each time
                                    --[[tOtherUnitsToDefend = aiBrain:GetUnitsAroundPoint(iOtherUnitCategoriesToDefend, oUnit:GetPosition(), iOtherUnitDefenceRange, 'Ally')

                                    if M27Utilities.IsTableEmpty(tOtherUnitsToDefend) == false then
                                        if bIgnoreUnlessEmergencyThreat == false then
                                            bShouldAttackThreat = true
                                        else
                                            --Only help out if we have enough AA threat nearby, and we are within the range of the nearest fixed AA
                                            if not(aiBrain[refbFarBehindOnAir]) or iCurTargetModDistanceFromStart <= 40 + aiBrain[refiOurFurthestAAStructureFromBase] then
                                                local tFriendlyGroundAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA - categories.TECH1, oUnit:GetPosition(), iOtherUnitDefenceRange, 'Ally')
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Enemy air threat near unit we want to protect but we dont have air control; is table of nearby ground units empty=' .. tostring(M27Utilities.IsTableEmpty(tFriendlyGroundAA)))
                                                end
                                                if M27Utilities.IsTableEmpty(tFriendlyGroundAA) == false then
                                                    if aiBrain[refiEnemyAirAAThreat] <= 500 or M27Logic.GetAirThreatLevel(aiBrain, tFriendlyGroundAA, false, false, true, false, false, nil, nil, nil, nil, false, false) >= 1600 then
                                                        bShouldAttackThreat = true
                                                    end
                                                end
                                            end
                                        end
                                    end--]]
                                end
                            end
                            if not(bShouldAttackThreat) and EntityCategoryContains(M27UnitInfo.refCategoryTransport, oUnit.UnitId) and oUnit.GetCargo and M27Utilities.IsTableEmpty(oUnit:GetCargo()) == false and M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition()) <= 175 then
                                bShouldAttackThreat = true
                            end

                            if not (bShouldAttackThreat) then
                                --Lower priority air targets, which will only consider if we think we have air control
                                if bIgnoreUnlessEmergencyThreat then
                                    iIgnoredThreats = iIgnoredThreats + 1
                                else
                                    if iCurDistanceToStartOrACU <= iMapMidpointDistance then
                                        bCloseEnoughToConsider = true
                                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy unit on our side of the map and we think we have air control so will consider') end
                                    else
                                        --Are we in defence coverage?
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Target unit=' .. oUnit.UnitId .. '; iCurTargetModDistanceFromStart=' .. iCurTargetModDistanceFromStart .. '; iDefenceCoverage=' .. aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat])
                                        end
                                        if iCurTargetModDistanceFromStart <= aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat] then
                                            bCloseEnoughToConsider = true
                                        elseif iCurTargetModDistanceFromStart <= iMaxModDistanceRange then

                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Not on our side of map, not in defence coverage, and not near ACU; will see if we have nearby units we want to protect. iAssistNearbyUnitRange=' .. iAssistNearbyUnitRange)
                                            end
                                            --Do we have nearby ground units (that we'll want to protect)?

                                            --NOTE: If making changes to the below, also update the logic for an air unit cancelling its attack
                                            tFriendlyGroundUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure + categories.LAND + categories.NAVAL + M27UnitInfo.refCategoryTorpBomber + M27UnitInfo.refCategoryBomber, tUnitCurPosition, iAssistNearbyUnitRange, 'Ally')
                                            if M27Utilities.IsTableEmpty(tFriendlyGroundUnits) == false then
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Have ' .. table.getn(tFriendlyGroundUnits) .. ' friendly units nearby so will assist')
                                                end
                                                bCloseEnoughToConsider = true
                                            elseif bDebugMessages == true then
                                                LOG(sFunctionRef .. ': No friendly units near ' .. repru(tUnitCurPosition))
                                            end
                                        end
                                    end
                                    if bCloseEnoughToConsider == true then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Enemy is close enough to consider, will check if unit is attached (e.g. still being built by factory) or has nearby enemy ground AA, iEnemyGroundAASearchRange=' .. iEnemyGroundAASearchRange)
                                        end
                                        if not (oUnit:IsUnitState('Attached')) then
                                            --Check if ground AA near the target
                                            tEnemyGroundAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, tUnitCurPosition, iEnemyGroundAASearchRange, 'Enemy')



                                            if M27Utilities.IsTableEmpty(tEnemyGroundAA) == true then
                                                bShouldAttackThreat = true
                                            else
                                                --Ignore T1 AA if have asfs
                                                if iOurHighestAirAATech == 3 then
                                                    tEnemyGroundAA = EntityCategoryFilterDown(M27UnitInfo.refCategoryAirAA * categories.TECH2 + M27UnitInfo.refCategoryAllNavy * categories.TECH2 + categories.TECH3, tEnemyGroundAA)
                                                end
                                                if M27Utilities.IsTableEmpty(tEnemyGroundAA) == true then
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': No nearby ground AA so ok to attack')
                                                    end
                                                    bShouldAttackThreat = true
                                                else
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Nearby ground AA so dont want to attack unelss its all being transported.  Will list out nearby ground AA')
                                                        for iEnemyAA, oEnemyAA in tEnemyGroundAA do
                                                            LOG(sFunctionRef .. ': oEnemyAA=' .. oEnemyAA.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oEnemyAA))
                                                        end
                                                    end
                                                    --Ignore if only threat is MAA that is being transported
                                                    bShouldAttackThreat = true
                                                    for iAA, oAA in tEnemyGroundAA do
                                                        if EntityCategoryContains(M27UnitInfo.refCategoryGroundAA - M27UnitInfo.refCategoryMAA, oAA.UnitId) then
                                                            bShouldAttackThreat = false
                                                            break
                                                        else
                                                            if bDebugMessages == true then
                                                                LOG(sFunctionRef .. ': Enemy has AA with unit ID=' .. oAA.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAA) .. '; Unit state=' .. M27Logic.GetUnitState(oAA))
                                                            end
                                                            if not (oAA:IsUnitState('Attached')) then
                                                                bShouldAttackThreat = false
                                                                break
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                            if bShouldAttackThreat then
                                                --Is there a nearby cruiser or carrier? If so then abort
                                                if M27Utilities.IsTableEmpty(tAllRecentlySeenCruisers) == false then
                                                    for iCruiser, oCruiser in tAllRecentlySeenCruisers do
                                                        if M27Utilities.GetDistanceBetweenPositions(tUnitCurPosition, oCruiser:GetPosition()) <= iRecentlySeenCruiserSearchRange then
                                                            bShouldAttackThreat = false
                                                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy cruiser recently detected nearby='..oCruiser.UnitId..M27UnitInfo.GetUnitLifetimeCount(oCruiser)..'; Dist away='..M27Utilities.GetDistanceBetweenPositions(tUnitCurPosition, oCruiser:GetPosition())) end
                                                            break
                                                        end
                                                    end
                                                end

                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if bShouldAttackThreat == true then
                        iEnemyUnitCount = iEnemyUnitCount + 1
                        tValidEnemyAirThreats[iEnemyUnitCount] = {}
                        tValidEnemyAirThreats[iEnemyUnitCount][refoUnit] = oUnit
                        tValidEnemyAirThreats[iEnemyUnitCount][refiDistance] = iCurTargetModDistanceFromStart
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Want to attack target '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' as it is a threat that we should attack, recording in tValidEnemyAirThreats, iEnemyUnitCount=' .. iEnemyUnitCount .. '; refiDistance=' .. tValidEnemyAirThreats[iEnemyUnitCount][refiDistance])
                        end
                    end
                elseif bDebugMessages == true then
                    LOG(sFunctionRef .. ': Target is dead or doesnt have a unit ID')
                end
            end

            local iOriginalMassThreat, iRemainingMassThreat
            local oClosestAirAA
            local iClosestAirAADistance, iCurAirAADistance, iClosestAirAARef
            local tCurUnitPos
            local bAbortAsNoMoreAirAA
            local oCurTarget, iAlreadyAssignedMassValue

            if M27Utilities.IsTableEmpty(aiBrain[reftAvailableAirAA]) == false then
                --SortTableBySubtable(tTableToSort, sSortByRef, bLowToHigh)
                bAbortAsNoMoreAirAA = false
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': We have available air units to assign, will now consider the target')
                end
                for iUnit, tSubtable in M27Utilities.SortTableBySubtable(tValidEnemyAirThreats, refiDistance, true) do

                    --Get mass threat
                    --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride)

                    oCurTarget = tSubtable[refoUnit]
                    tCurUnitPos = oCurTarget:GetPosition()
                    iOriginalMassThreat = M27Logic.GetAirThreatLevel(aiBrain, { oCurTarget }, true, true, false, true, true)
                    --Update details of units already assigned to the unit
                    iRemainingMassThreat = iOriginalMassThreat * 2.5
                    if EntityCategoryContains(M27UnitInfo.refCategoryAirNonScout, oCurTarget.UnitId) then
                        iRemainingMassThreat = iRemainingMassThreat * 2
                    end
                    iAlreadyAssignedMassValue = 0
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Target =' .. oCurTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oCurTarget) .. '; iRemainingMassThreat=' .. iRemainingMassThreat .. '; iOriginalMassThreat=' .. iOriginalMassThreat)
                    end
                    if M27Utilities.IsTableEmpty(oCurTarget[reftTargetedByList]) == false then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': About to update details of units already assigned to the unit; cycle through reftTargetedByList, table size=' .. table.getn(oCurTarget[reftTargetedByList]))
                        end
                        for iExistingAirAA, oExistingAirAA in oCurTarget[reftTargetedByList] do
                            if oExistingAirAA.GetUnitId then
                                iAlreadyAssignedMassValue = iAlreadyAssignedMassValue + M27Logic.GetAirThreatLevel(aiBrain, { oExistingAirAA }, false, true, false, false, false)
                            end
                            if bDebugMessages == true then
                                if M27UnitInfo.IsUnitValid(oExistingAirAA) == false then
                                    LOG('existing airAA Unit isnt valid')
                                else
                                    if not (oExistingAirAA[refoAirAATarget]) or not (oExistingAirAA[refoAirAATarget].GetUnitId) then
                                        LOG('Existing airAA ' .. oExistingAirAA.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oExistingAirAA) .. ' doesnt have a valid target')
                                    else
                                        LOG(sFunctionRef .. ': oExistingAirAA=' .. oExistingAirAA.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oExistingAirAA) .. '; oExistingAirAA target=' .. oExistingAirAA[refoAirAATarget].UnitId .. M27UnitInfo.GetUnitLifetimeCount(oExistingAirAA[refoAirAATarget]))
                                    end
                                end
                            end
                        end
                    end
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Finished updating the existing units already assigned to oCurTargetId=' .. oCurTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oCurTarget) .. '; iOriginalMassThreat=' .. iOriginalMassThreat .. '; iRemainingMassThreat pre assigned value=' .. iRemainingMassThreat .. '; iAlreadyAssignedMassValue=' .. iAlreadyAssignedMassValue)
                    end

                    iRemainingMassThreat = iRemainingMassThreat - iAlreadyAssignedMassValue

                    iClosestAirAADistance = 10000

                    local iCurLoopCount = 0
                    local iMaxLoopCount = 150
                    local iMaxAirAA = 150 --Will stop cycling through after this many (performance reasons)
                    local iThresholdToDisableDistanceCheck = 30

                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': About to look for our AirAA units to attack the target; Target Unit Id=' .. oCurTarget.UnitId .. '; original mass threat=' .. iOriginalMassThreat .. '; iAlreadyAssignedMassValue=' .. iAlreadyAssignedMassValue .. '; iRemainingMassThreat=' .. iRemainingMassThreat .. '; size of availableAA=' .. table.getn(aiBrain[reftAvailableAirAA]))
                    end
                    while iRemainingMassThreat > 0 and bAbortAsNoMoreAirAA == false do
                        if iCurLoopCount > iMaxLoopCount then
                            if iOriginalMassThreat <= 5000 then
                                M27Utilities.ErrorHandler('Infinite loop; threat mass threat=' .. iOriginalMassThreat)
                            end
                            break
                        end
                        if iCurLoopCount < iThresholdToDisableDistanceCheck then

                            iClosestAirAADistance = 10000
                            oClosestAirAA = nil
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': About to look for inties to attack, iRemainingMassThreat=' .. iRemainingMassThreat .. '; size of availableAA=' .. table.getn(aiBrain[reftAvailableAirAA]))
                            end
                            iCurLoopCount = iCurLoopCount + 1

                            for iAirAA, oAirAA in aiBrain[reftAvailableAirAA] do
                                if iAirAA > iMaxAirAA then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': iAirAA=' .. iAirAAll '; iMaxAirAA=' .. iMaxAirAA .. '; Wont try and find any closer AirAA as already been through more than want')
                                    end
                                    break
                                end

                                iCurAirAADistance = M27Utilities.GetDistanceBetweenPositions(oAirAA:GetPosition(), tCurUnitPos)
                                if iCurAirAADistance < iClosestAirAADistance then
                                    iClosestAirAADistance = iCurAirAADistance
                                    oClosestAirAA = oAirAA
                                    iClosestAirAARef = iAirAA
                                end
                            end
                        else
                            oClosestAirAA = aiBrain[reftAvailableAirAA][1]
                        end
                        if oClosestAirAA then
                            --if oClosestAirAA.UnitId..M27UnitInfo.GetUnitLifetimeCount(oClosestAirAA) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end
                            if bDebugMessages == true then
                                local iLifetimeCount = M27UnitInfo.GetUnitLifetimeCount(oClosestAirAA)
                                if iLifetimeCount == nil then
                                    iLifetimeCount = 'nil'
                                end
                                LOG(sFunctionRef .. ': Clearing commands for closest airAA and then telling it to attack oCurTarget, ClosestAirAA=' .. oClosestAirAA.UnitId .. '; Unique ID=' .. iLifetimeCount .. '; iClosestAirAARef=' .. iClosestAirAARef .. 'ClosestAA Pos=' .. repru(oClosestAirAA:GetPosition()))
                            end
                            ClearAirUnitAssignmentTrackers(aiBrain, oClosestAirAA, true)
                            M27Utilities.IssueTrackedClearCommands({ oClosestAirAA })
                            IssueAttack({ oClosestAirAA }, oCurTarget)
                            IssueAggressiveMove({ oClosestAirAA }, tStartPosition)
                            if M27Config.M27ShowUnitNames == true and oClosestAirAA.GetUnitId then
                                M27PlatoonUtilities.UpdateUnitNames({ oClosestAirAA }, oClosestAirAA.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oClosestAirAA) .. ':IntereceptAir')
                            end
                            oClosestAirAA[refbOnAssignment] = true
                            oClosestAirAA[refoAirAATarget] = oCurTarget
                            if oCurTarget[reftTargetedByList] == nil then
                                oCurTarget[reftTargetedByList] = {}
                            end
                            table.insert(oCurTarget[reftTargetedByList], 1, oClosestAirAA)
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': about to cycle through available AA noting their lifetime count before removing cur entry')
                                for iAA, oAA in aiBrain[reftAvailableAirAA] do
                                    LOG('iAA=' .. iAA .. '; Lifetime count=' .. M27UnitInfo.GetUnitLifetimeCount(oAA))
                                end
                            end
                            table.remove(aiBrain[reftAvailableAirAA], iClosestAirAARef)
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Finished removing iClosestAirAARef=' .. iClosestAirAARef .. '; about to cycle through available AA noting their lifetime count')
                                for iAA, oAA in aiBrain[reftAvailableAirAA] do
                                    LOG('iAA=' .. iAA .. '; Lifetime count=' .. M27UnitInfo.GetUnitLifetimeCount(oAA))
                                end
                            end
                            if M27Utilities.IsTableEmpty(aiBrain[reftAvailableAirAA]) == true then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': No longer have any availalbe AA so aborting loop')
                                end
                                bAbortAsNoMoreAirAA = true
                                break
                            else
                                --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride)
                                iRemainingMassThreat = iRemainingMassThreat - M27Logic.GetAirThreatLevel(aiBrain, { oClosestAirAA }, false, true, false, false, false)
                            end
                        else
                            bAbortAsNoMoreAirAA = true
                            if M27Utilities.IsTableEmpty(aiBrain[reftAvailableAirAA]) == false then
                                M27Utilities.ErrorHandler('oClosestAirAA is blank despite having AA nearby, size of availableairAA=' .. table.getn(aiBrain[reftAvailableAirAA]))
                            else
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': No airAA available any more')
                                end
                            end
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': iRemainingMassThreat=' .. iRemainingMassThreat .. '; bAbortAsNoMoreAirAA=' .. tostring(bAbortAsNoMoreAirAA))
                        end
                        if bAbortAsNoMoreAirAA == true then
                            if not (aiBrain[refbNonScoutUnassignedAirAATargets]) and EntityCategoryContains(M27UnitInfo.refCategoryAirNonScout, oCurTarget.UnitId) then
                                aiBrain[refbNonScoutUnassignedAirAATargets] = true
                            end
                            break
                        end
                    end
                    if bAbortAsNoMoreAirAA == true then
                        if not (aiBrain[refbNonScoutUnassignedAirAATargets]) and EntityCategoryContains(M27UnitInfo.refCategoryAirNonScout, oCurTarget.UnitId) then
                            aiBrain[refbNonScoutUnassignedAirAATargets] = true
                        end
                        iAirThreatShortfall = iAirThreatShortfall + iRemainingMassThreat
                    end
                end
            else
                bDidntHaveAnyAirAAToStartWith = true
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': No available airAA')
                end
                --Are any of the air targets non-scouts?
                if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryAirNonScout, tValidEnemyAirThreats)) == false then
                    aiBrain[refbNonScoutUnassignedAirAATargets] = true
                end
            end
        else
            --Dont need any airAA any more
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': No enemy air units to target')
            end
        end

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': bIgnoreUnlessEmergencyThreat=' .. tostring(bIgnoreUnlessEmergencyThreat) .. '; iIgnoredThreats=' .. iIgnoredThreats)
        end
        if M27Utilities.IsTableEmpty(aiBrain[reftAvailableAirAA]) == false then
            aiBrain[refbNonScoutUnassignedAirAATargets] = false --redundancy
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Have available air units after assigning actions to deal with air threats; will send any remaining units to the rally point nearest the enemy unless theyre already near here; are considering aiBrain with armyindex=' .. aiBrain:GetArmyIndex())
            end
            local tAirRallyPoint = GetAirAAMainRallyPoint(aiBrain)

            local tAltRallyPoint = M27Utilities.GetACU(aiBrain):GetPosition()
            local iAirUnitsWantAtAltRallyPoint = 0
            if aiBrain[refbMercySightedRecently] then
                if M27Utilities.GetDistanceBetweenPositions(tAltRallyPoint, tAirRallyPoint) >= 30 then
                    iAirUnitsWantAtAltRallyPoint = 2
                end
            elseif aiBrain[M27Overseer.refbACUVulnerableToAirSnipe] then
                local tNearbyAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, tAltRallyPoint, 80, 'Enemy')
                if M27Utilities.IsTableEmpty(tNearbyAA) then
                    iAirUnitsWantAtAltRallyPoint = 2
                    --Are there enemy AA units near the ACU/on the way to the ACU? If not, then send our full air force nearby
                    local iACUIntelCoverage = M27Logic.GetIntelCoverageOfPosition(aiBrain, tAltRallyPoint)
                    if iACUIntelCoverage >= 40 then
                        iAirUnitsWantAtAltRallyPoint = 10
                        --Increase slightly if we wont have asfs yet or enemy has large air to ground threat
                        if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] < 3 or aiBrain[refiEnemyAirToGroundThreat] >= 2500 then iAirUnitsWantAtAltRallyPoint = 13 end
                    end
                end
            end




            if iAirUnitsWantAtAltRallyPoint > 0 then
                --Create table containing air units and their distance to the alt rally
                local tAirUnitsByDistance = {}
                local iCount = 0
                local oAirAA
                for iAirAA, oAirAA in aiBrain[reftAvailableAirAA] do
                    tAirUnitsByDistance[iAirAA] = {}
                    tAirUnitsByDistance[iAirAA]['Unit'] = oAirAA
                    tAirUnitsByDistance[iAirAA]['DistToAlt'] = M27Utilities.GetDistanceBetweenPositions(tAltRallyPoint, oAirAA:GetPosition())
                end
                for iEntry, tValue in M27Utilities.SortTableBySubtable(tAirUnitsByDistance, 'DistToAlt', true) do
                    oAirAA = tValue['Unit']
                    --if oAirAA.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAirAA) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end
                    iCount = iCount + 1
                    if iCount <= iAirUnitsWantAtAltRallyPoint then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Sending airAA unit ' .. tValue['Unit'].UnitId .. M27UnitInfo.GetUnitLifetimeCount(tValue['Unit']) .. ' to alt rally point; dist to rally=' .. tValue['DistToAlt'])
                        end
                        M27Utilities.IssueTrackedClearCommands({ oAirAA })
                        IssueMove({ oAirAA }, tAltRallyPoint)
                    else
                        M27Utilities.IssueTrackedClearCommands({ oAirAA })
                        IssueMove({ oAirAA }, tAirRallyPoint)
                    end
                end
            else
                for iAirAA, oAirAA in aiBrain[reftAvailableAirAA] do
                    if M27Utilities.GetDistanceBetweenPositions(oAirAA:GetPosition(), tAirRallyPoint) > 40 then
                        --if oAirAA.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAirAA) == 'uea03042' then bDebugMessages = true else bDebugMessages = false end
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Clearing commands of airAA unit ' .. oAirAA.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAirAA))
                        end
                        M27Utilities.IssueTrackedClearCommands({ oAirAA })
                        IssueMove({ oAirAA }, tAirRallyPoint)
                    end
                end
            end
        end

        --Calculate how much airAA we want to build
        --if M27Utilities.IsTableEmpty(aiBrain[reftAvailableAirAA]) == false and table.getsize(aiBrain[reftAvailableAirAA]) >= 20 then bDebugMessages = true end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': About to calculate how much airAA we want')
        end

        local iExpectedThreatPerCount = 50
        if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] >= 3 then
            iExpectedThreatPerCount = 350
        end
        if bDidntHaveAnyAirAAToStartWith == true then
            local iEnemyAirUnits = 0
            if M27Utilities.IsTableEmpty(tValidEnemyAirThreats) == false then
                for iUnit, tSubtable in M27Utilities.SortTableBySubtable(tValidEnemyAirThreats, refiDistance, true) do
                    iEnemyAirUnits = iEnemyAirUnits + 1
                end
            end
            iEnemyAirUnits = iEnemyAirUnits + iIgnoredThreats
            aiBrain[refiAirAANeeded] = iEnemyAirUnits * 1.3 + 2
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': No AirAA so need a minimum of 2 plus 1.3*iEnemyAirUnits, =' .. aiBrain[refiAirAANeeded])
            end
        else
            iAirThreatShortfall = iAirThreatShortfall + iIgnoredThreats
            if iAirThreatShortfall > 0 then
                --Dont flag as needing as many airAA units if we already have a decent number available
                if aiBrain[refiOurMassInAirAA] >= math.max(8 * iExpectedThreatPerCount, 350 * aiBrain[M27Overseer.refiEnemyHighestTechLevel]) and M27Utilities.IsTableEmpty(aiBrain[reftAvailableAirAA]) == false and table.getsize(aiBrain[reftAvailableAirAA]) >= 10 then
                    aiBrain[refiAirAANeeded] = math.ceil(iAirThreatShortfall / iExpectedThreatPerCount) * 0.5
                else
                    aiBrain[refiAirAANeeded] = math.max(5, math.ceil(iAirThreatShortfall / iExpectedThreatPerCount))
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': End of calculating threat required; iAirThreatShortfall=' .. iAirThreatShortfall .. '; iExpectedThreatPerCount=' .. iExpectedThreatPerCount .. '; aiBrain[refiAirAANeeded]=' .. aiBrain[refiAirAANeeded])
                end
            else
                --Do we have any available air units?
                aiBrain[refiAirAANeeded] = 0
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iAirThreatShortfall is 0 so airAA needed is 0')
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function AirLogicMainLoop(aiBrain, iCycleCount)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AirLogicMainLoop'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': iCycleCount=' .. iCycleCount .. ': GameTime=' .. GetGameTimeSeconds())
    end
    RecordSegmentsThatHaveVisualOf(aiBrain)
    RecordAvailableAndLowFuelAirUnits(aiBrain)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': about to show how many available bombers we have')
        if aiBrain[reftAvailableBombers] then
            LOG('Size of table=' .. table.getn(aiBrain[reftAvailableBombers]))
        end
        LOG(sFunctionRef .. ': Post recording available units, IsAvailableTorpBombersEmpty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftAvailableTorpBombers])))
    end
    ForkThread(AirThreatChecker, aiBrain)
    ForkThread(AirScoutManager, aiBrain)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Pre air bomber manager; IsAvailableTorpBombersEmpty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftAvailableTorpBombers])))
    end
    ForkThread(AirBomberManager, aiBrain)
    ForkThread(AirAAManager, aiBrain)
    ForkThread(M27Transport.TransportManager, aiBrain)
    ForkThread(GunshipManager, aiBrain)

    if iCycleCount == iLongCycleThreshold then
        if M27Utilities.IsTableEmpty(aiBrain[reftLowFuelAir]) == false then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Have some scouts with low fuel so about to call function to tell them to refuel')
            end
            ForkThread(OrderUnitsToRefuel, aiBrain, aiBrain[reftLowFuelAir])
        elseif bDebugMessages == true then
            LOG(sFunctionRef .. ': No units listed as having low fuel')
        end

        ForkThread(ReleaseRefueledUnits, aiBrain)
    elseif iCycleCount == (iLongCycleThreshold - 1) then
        ForkThread(RefuelIdleAirUnits, aiBrain)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)

end

function AirLogicOverseer(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AirLogicOverseer'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local bProfiling = false
    local iProfileStartTime = 0

    local iCycleCount = 0

    if bProfiling == true then
        iProfileStartTime = M27Utilities.ProfilerTimeSinceLastCall(sFunctionRef .. ': Pre start of while loop', iProfileStartTime)
    end

    local iTicksToWait

    while (not (aiBrain:IsDefeated()) and not (aiBrain.M27IsDefeated)) do
        if aiBrain.M27IsDefeated or M27Logic.iTimeOfLastBrainAllDefeated > 10 then
            break
        end
        if bProfiling == true then
            iProfileStartTime = M27Utilities.ProfilerTimeSinceLastCall(sFunctionRef .. ': Start of loop', iProfileStartTime)
        end
        iCycleCount = iCycleCount + 1

        ForkThread(AirLogicMainLoop, aiBrain, iCycleCount)

        if iCycleCount == iLongCycleThreshold then
            iCycleCount = 0
        end
        if bProfiling == true then
            iProfileStartTime = M27Utilities.ProfilerTimeSinceLastCall(sFunctionRef .. ': End of loop', iProfileStartTime)
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        iTicksToWait = _G.MyM27Scheduler:WaitTicks(10, 15, 0.6)
        --WaitTicks(iTicksToWait)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function Initialise()
end --Done so can find air overseer setup more easily
function SetupAirOverseer(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'SetupAirOverseer'
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code')
    end
    --Sets default/starting values for everything so dont have to worry about checking if is nil or not
    aiBrain[refiExtraAirScoutsWanted] = 0
    aiBrain[refiAirStagingWanted] = 0
    aiBrain[refiTorpBombersWanted] = 0
    aiBrain[refiAirAANeeded] = 0
    aiBrain[refiAirAAWanted] = 1
    --aiBrain[refiBombersWanted] = 1
    aiBrain[refiBomberDefencePercentRange] = 0.25
    aiBrain[refiBomberDefenceModDistance] = 125
    aiBrain[refiBomberDefenceDistanceCap] = 200
    aiBrain[refiBomberDefenceCriticalThreatDistance] = 100

    aiBrain[refbBombersAreEffective] = {}
    aiBrain[refbBombersAreReallyEffective] = {}
    for iTech = 1, 4 do
        aiBrain[refbBombersAreEffective][iTech] = true
        aiBrain[refbBombersAreReallyEffective][iTech] = false
    end
    aiBrain[reftBombersAssignedLowPriorityTargets] = {}
    aiBrain[reftPreviousTargetByLocationCount] = {}
    aiBrain[reftEnemyAirFactoryByTech] = { 0, 0, 0 }
    aiBrain[reftNearestEnemyAirThreat] = {}
    aiBrain[refiNearestEnemyAirThreatActualDist] = 1000
    aiBrain[refiEnemyMassInGroundAA] = 0
    aiBrain[refiHighestEnemyAirThreat] = 0
    aiBrain[reftEngiHunterBombers] = {}
    aiBrain[reftMexHunterT1Bombers] = {}
    aiBrain[refiOurMassInAirAA] = 0
    aiBrain[refiEnemyAirAAThreat] = 0
    aiBrain[refiHighestEverEnemyAirAAThreat] = 0
    aiBrain[refiEnemyAirToGroundThreat] = 0
    aiBrain[refiGunshipMassLost] = 0
    aiBrain[refiGunshipMassKilled] = 0

    aiBrain[refiBomberIneffectivenessByDefenceModRange] = {}



    --Air scouts have visual of 42, so want to divide map into segments of size 20

    iAirSegmentSize = 20
    iSegmentVisualThresholdBoxSize1 = iAirSegmentSize * 2
    iSegmentVisualThresholdBoxSize2 = iAirSegmentSize * 3

    aiBrain[refiIntervalLowestPriority] = 300
    aiBrain[refiIntervalHighestPriority] = 30 --Note this is changed late game on high incomes
    aiBrain[refiIntervalMexNotBuiltOn] = 100
    aiBrain[refiIntervaPriorityMex] = 60
    aiBrain[refiIntervalEnemyMex] = 120
    aiBrain[refiIntervalEnemyBase] = 80 --Note this is changed when updating scouting requirements if we are late game, so changes here should be considered there as well (have set it = 80 + x so easier to locate)
    aiBrain[refiIntervalChokepoint] = 45

    aiBrain[reftAirSegmentTracker] = {}
    aiBrain[reftScoutingTargetShortlist] = {}

    aiBrain[refiLargeBomberAttackThreshold] = 10 --Default

    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
    local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]

    if (iMapMaxAirSegmentX or 0) == 0 then
        --Only need to do once if have multiple brains
        iMapMaxAirSegmentX = math.ceil(iMapSizeX / iAirSegmentSize)
        iMapMaxAirSegmentZ = math.ceil(iMapSizeZ / iAirSegmentSize)
    end

    aiBrain[refiClosestEnemyDangerousAADistToOurBase] = math.min(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase], math.max(iMapSizeX, iMapSizeZ))

    iMinScoutsForMap = math.min(12, math.ceil(iMapSizeX * iMapSizeZ / (250 * 250)) * 0.75)
    iMaxScoutsForMap = iMinScoutsForMap * 3

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': iMapMaxAirSegmentX=' .. iMapMaxAirSegmentX .. '; iMapMaxAirSegmentZ=' .. iMapMaxAirSegmentZ .. '; rPlayableArea=' .. repru(rPlayableArea) .. '; iAirSegmentSize=' .. iAirSegmentSize)
    end
    --For large maps want to limit the segments that we consider (dont want to use aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] in case its not updated
    local iDistanceToEnemyFromStart = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
    aiBrain[refiMaxScoutRadius] = math.max(1500, iDistanceToEnemyFromStart * 1.5) --Note this gets updated whenever the enemy start position is changed
    local iStartSegmentX, iStartSegmentZ = GetAirSegmentFromPosition(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
    --local iSegmentSizeX = iMapSizeX / iAirSegmentSize
    --local iSegmentSizeZ = iMapSizeZ / iAirSegmentSize
    local iMaxSegmentDistanceFromStartX = math.ceil(aiBrain[refiMaxScoutRadius] / iAirSegmentSize)
    local iMaxSegmentDistanceFromStartZ = math.ceil(aiBrain[refiMaxScoutRadius] / iAirSegmentSize)

    aiBrain[refiMaxSegmentX] = math.min(iMapMaxAirSegmentX, iStartSegmentX + iMaxSegmentDistanceFromStartX)
    aiBrain[refiMaxSegmentZ] = math.min(iMapMaxAirSegmentZ, iStartSegmentZ + iMaxSegmentDistanceFromStartZ)
    aiBrain[refiMinSegmentX] = math.max(1, iStartSegmentX - iMaxSegmentDistanceFromStartX)
    aiBrain[refiMinSegmentZ] = math.max(1, iStartSegmentZ - iMaxSegmentDistanceFromStartZ)

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Determined min and max segments, iMapMaxAirSegmentX=' .. iMapMaxAirSegmentX .. '; iStartSegmentX=' .. iStartSegmentX .. '; iMaxSegmentDistanceFromStartX=' .. iMaxSegmentDistanceFromStartX .. '; iMapMaxAirSegmentZ=' .. iMapMaxAirSegmentZ .. '; iStartSegmentZ=' .. iStartSegmentZ .. '; iMaxSegmentDistanceFromStartZ=' .. iMaxSegmentDistanceFromStartZ .. '; aiBrain[refiMaxScoutRadius]=' .. aiBrain[refiMaxScoutRadius] .. '; iAirSegmentSize=' .. iAirSegmentSize)
    end


    --Default values for each segment:
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Recording segments for iMapMaxAirSegmentX=' .. iMapMaxAirSegmentX .. ' iMapMaxAirSegmentZ=' .. iMapMaxAirSegmentZ)
    end
    for iCurX = 1, iMapMaxAirSegmentX do
        aiBrain[reftAirSegmentTracker][iCurX] = {}
        for iCurZ = 1, iMapMaxAirSegmentZ do
            aiBrain[reftAirSegmentTracker][iCurX][iCurZ] = {}
            aiBrain[reftAirSegmentTracker][iCurX][iCurZ][refiLastScouted] = 0
            aiBrain[reftAirSegmentTracker][iCurX][iCurZ][refiAirScoutsAssigned] = 0
            aiBrain[reftAirSegmentTracker][iCurX][iCurZ][refiNormalScoutingIntervalWanted] = aiBrain[refiIntervalLowestPriority]
            aiBrain[reftAirSegmentTracker][iCurX][iCurZ][refiCurrentScoutingInterval] = aiBrain[refiIntervalLowestPriority]
            aiBrain[reftAirSegmentTracker][iCurX][iCurZ][reftMidpointPosition] = GetAirPositionFromSegment(iCurX, iCurZ)
            aiBrain[reftAirSegmentTracker][iCurX][iCurZ][refiDeadScoutsSinceLastReveal] = 0
        end
    end

    --Higher priorities for enemy start locations
    --(note - M27Overseer will reduce the threshold for nearest enemy when it thinks we'll be deciding what experimental to be building soon)
    local iOurArmyIndex = aiBrain:GetArmyIndex()
    local iEnemyArmyIndex, tEnemyStartPosition
    local iCurAirSegmentX, iCurAirSegmentZ
    for iCurBrain, oBrain in ArmyBrains do
        if not (oBrain == aiBrain) then
            iEnemyArmyIndex = oBrain:GetArmyIndex()
            if IsEnemy(iOurArmyIndex, iEnemyArmyIndex) then
                if oBrain.M27StartPositionNumber then
                    tEnemyStartPosition = M27MapInfo.PlayerStartPoints[oBrain.M27StartPositionNumber]
                    if tEnemyStartPosition then
                        iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(tEnemyStartPosition)
                        aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiNormalScoutingIntervalWanted] = aiBrain[refiIntervalEnemyBase]
                        aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval] = aiBrain[refiIntervalEnemyBase]
                    end
                end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': air units wanted: aiBrain[refiExtraAirScoutsWanted]=' .. aiBrain[refiExtraAirScoutsWanted] .. '; aiBrain[refiAirStagingWanted]=' .. aiBrain[refiAirStagingWanted] .. '; aiBrain[refiTorpBombersWanted]=' .. aiBrain[refiTorpBombersWanted] .. '; aiBrain[refiAirAANeeded]=' .. aiBrain[refiAirAANeeded])
        LOG(sFunctionRef .. ': End of code pre wait ticks and calling of air logic overseer fork thread')
    end
    WaitTicks(100)
    ForkThread(AirLogicOverseer, aiBrain)
end

--Decide on mex targets and update air scouting for these
function UpdateMexScoutingPriorities(aiBrain)
    --called from strategic overseer
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateMexScoutingPriorities'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code. Is table of sorted mexes empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftSortedMexesInOriginalGroup])) .. '; CurGameTime=' .. GetGameTimeSeconds())
    end
    if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftSortedMexesInOriginalGroup]) == true then
        if GetGameTimeSeconds() > 15 then
            M27Utilities.ErrorHandler('Still dont have a table of sorted mexes after 15 seconds')
        end
    else
        local iPriorityCount = 0
        local iGameTime = math.floor(GetGameTimeSeconds())
        local iCurAirSegmentX, iCurAirSegmentZ
        local iPriorityValue
        aiBrain[M27MapInfo.reftHighPriorityMexes] = {}
        --refiLastTimeScoutingIntervalChanged
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Sorted mex count=' .. table.getn(aiBrain[M27MapInfo.reftSortedMexesInOriginalGroup]) .. '; full list of sorted mex locations=' .. repru(aiBrain[M27MapInfo.reftSortedMexesInOriginalGroup]))
        end


        --Make mexes near enemy high priority if we need actions
        local bAlsoConsiderMexesNearerEnemyBase = false
        local sPathing, iMinDistanceFromEnemy, iMaxDistanceFromEnemy, iPathingGroup
        local bConsiderIfWeShouldConsiderOtherMexes = false
        if M27Utilities.IsTableEmpty(aiBrain[reftBomberTargetShortlist]) == true and M27Utilities.IsTableEmpty(aiBrain[reftAvailableBombers]) == false then
            bConsiderIfWeShouldConsiderOtherMexes = true
        elseif M27Utilities.IsTableEmpty(aiBrain[reftAvailableBombers]) == false and aiBrain[reftAvailableBombers][1] and aiBrain[reftAvailableBombers][1]['M27LifetimeUnitCount'] and aiBrain[reftAvailableBombers][1]['M27LifetimeUnitCount'] == 1 then
            bConsiderIfWeShouldConsiderOtherMexes = true
        end

        if bConsiderIfWeShouldConsiderOtherMexes == true then
            --RecordMexesInPathingGroupFilteredByEnemyDistance(aiBrain, sPathing, iPathingGroup, iMinDistanceFromEnemy, iMaxDistanceFromEnemy)
            sPathing = M27UnitInfo.refPathingTypeAmphibious
            iMinDistanceFromEnemy = 50
            iMaxDistanceFromEnemy = 300
            iPathingGroup = aiBrain[M27MapInfo.refiStartingSegmentGroup][sPathing]
            M27MapInfo.RecordMexesInPathingGroupFilteredByEnemyDistance(aiBrain, sPathing, iPathingGroup, iMinDistanceFromEnemy, iMaxDistanceFromEnemy)
            if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup][iMinDistanceFromEnemy][iMaxDistanceFromEnemy]) == false then
                bAlsoConsiderMexesNearerEnemyBase = true
            end
        end

        local tMexesToCycleThrough
        local iTablesToCycleThrough = 1
        if bAlsoConsiderMexesNearerEnemyBase == true then
            iTablesToCycleThrough = iTablesToCycleThrough + 1
        end

        local iMaxHighPriorityTargets = 3
        for iCurTable = 1, iTablesToCycleThrough do
            if iTablesToCycleThrough == 1 then
                tMexesToCycleThrough = aiBrain[M27MapInfo.reftSortedMexesInOriginalGroup]
                iMaxHighPriorityTargets = math.max(3, table.getn(aiBrain[M27MapInfo.reftSortedMexesInOriginalGroup]) * 0.2)
            elseif iTablesToCycleThrough == 2 then
                tMexesToCycleThrough = aiBrain[M27MapInfo.reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup][iMinDistanceFromEnemy][iMaxDistanceFromEnemy]
                iMaxHighPriorityTargets = math.max(20, iMaxHighPriorityTargets)
            else
                M27Utilities.ErrorHandler('Not added code for more tables')
            end

            for iMex, tMexLocation in tMexesToCycleThrough do
                iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(tMexLocation)
                iPriorityValue = nil
                --IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
                if M27Conditions.IsMexUnclaimed(aiBrain, tMexLocation, true, false, false) == true then
                    iPriorityCount = iPriorityCount + 1
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Mex location is either unclaimed or has enemy mex on it, location=' .. repru(tMexLocation) .. '; iPriorityCount=' .. iPriorityCount)
                    end
                    if iPriorityCount <= iMaxHighPriorityTargets and not(M27MapInfo.IsUnderwater(tMexLocation, false, nil)) then
                        iPriorityValue = aiBrain[refiIntervaPriorityMex]
                        aiBrain[M27MapInfo.reftHighPriorityMexes][iPriorityCount] = tMexLocation
                    else
                        iPriorityValue = aiBrain[refiIntervalEnemyMex]
                    end
                else
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Mex location is already built on by us or queued, location=' .. repru(tMexLocation))
                    end
                    --Only update if not already updated this segment (as if already updated it mightve been for a high priority)
                    if aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastTimeScoutingIntervalChanged] < iGameTime then
                        --Do we own the mex? We already know that the mex is claimed if considering our buildings+queued buildings, so now just want to consider if its unclaimed when ignoring queued buildings
                        if M27Conditions.IsMexUnclaimed(aiBrain, tMexLocation, false, false, true) == true then
                            --Mex is not built on (might be queued though)
                            iPriorityValue = aiBrain[refiIntervalMexNotBuiltOn]
                        else
                            --Mex is built on by us/ally so we already have small visual range of it, so low priority
                            iPriorityValue = aiBrain[refiIntervalLowestPriority]
                        end
                    end
                end
                if not (iPriorityValue == nil) then
                    aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiNormalScoutingIntervalWanted] = iPriorityValue
                    if aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval] > iPriorityValue then
                        aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval] = iPriorityValue
                    end
                    aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastTimeScoutingIntervalChanged] = iGameTime
                end
            end
        end

        if bDebugMessages == true then
            LOG(sFunctionRef .. ': End: Number of high priority mexes=' .. table.getn(aiBrain[M27MapInfo.reftHighPriorityMexes]))
            M27Utilities.DrawLocations(aiBrain[M27MapInfo.reftHighPriorityMexes])
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetNovaxTarget(aiBrain, oNovax)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetNovaxTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tEnemyUnits
    local iMaxRange = 600
    local oTarget

    --Check for priority override (but still consider shields and ACU even if have a priority target)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Time='..GetGameTimeSeconds()..'; Is there a valid target override set=' .. tostring(oNovax[refoPriorityTargetOverride]) .. '; Time since last override=' .. GetGameTimeSeconds() - (oNovax[refiTimeOfLastOverride] or -100))
    end
    if M27UnitInfo.IsUnitValid(oNovax[refoPriorityTargetOverride]) and (GetGameTimeSeconds() - oNovax[refiTimeOfLastOverride]) <= 11 then
        --Ignore override if are in ACU kill mode and its assassination
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Will ignore override if in ACU kill mode. Strategy=' .. aiBrain[M27Overseer.refiAIBrainCurrentStrategy] .. '; Victory setting=' .. ScenarioInfo.Options.Victory)
        end
        if not (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and ScenarioInfo.Options.Victory == "demoralization") then
            --Are there any near-exposed shields nearby? Then target them instead
            local tNearbyEnemyShields = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedShield + M27UnitInfo.refCategoryShieldBoat + M27UnitInfo.refCategoryMobileLandShield * categories.TECH3, oNovax[refoPriorityTargetOverride]:GetPosition(), 23, 'Enemy')
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': is table of nearby shields empty=' .. tostring(M27Utilities.IsTableEmpty(tNearbyEnemyShields)) .. '; target subject to this=' .. oNovax[refoPriorityTargetOverride].UnitId .. M27UnitInfo.GetUnitLifetimeCount(oNovax[refoPriorityTargetOverride]))
            end
            if M27Utilities.IsTableEmpty(tNearbyEnemyShields) == false then
                local iCurShield, iMaxShield
                local iLowestShield = 5000
                for iUnit, oUnit in tNearbyEnemyShields do
                    iCurShield, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oUnit)
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering whether to target enemy near-exposed shield, oUnit='..oUnit.UnitId..M28UnitInfo.GetUnitLifetimeCount(oUnit)..'; iCurShield='..iCurShield..'; iMaxShield='..iMaxShield) end
                    if iCurShield <= iLowestShield and iCurShield <= iMaxShield * 0.3 then
                        if not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, iLowestShield + 1, false, false, false)) then
                            oTarget = oUnit
                            iLowestShield = iCurShield
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Nearby shield with low health, setting oTarget=' .. oTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oTarget))
                            end
                        end
                    end
                end
            end
            if not(oTarget) then
                --Is there an expoesd enemy ACU that we can kill instead?
                if ScenarioInfo.Options.Victory == "demoralization" then
                    local iRange = math.max(20, oNovax:GetBlueprint().Weapon[1].MaxRadius)
                    local tNearbyACUs = aiBrain:GetUnitsAroundPoint(categories.COMMAND, oNovax:GetPosition(), iRange + 10, 'Enemy')
                    local iDPS = 243

                    if M27Utilities.IsTableEmpty(tNearbyACUs) == false then
                        local iShortestTimeToKillTarget = 60 --Wont consider ACUs where will take more than this time to kill them
                        local oACUForShortestTime
                        local iTimeToKillTarget
                        local iCurDPSMod = 0
                        for iACU, oACU in tNearbyACUs do
                            iTimeToKillTarget = 10000
                            if not(oACU:IsUnitState('Attached')) and not(M27MapInfo.IsUnderwater(oACU:GetPosition())) then --Even if ACU slightly above water watn to ignore since it could probably easily get underwater
                                local iACUCurShield, iACUMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oACU)
                                iCurDPSMod = -M27UnitInfo.GetACUShieldRegenRate(oACU) - M27UnitInfo.GetACUHealthRegenRate(oACU)
                                local iACUHealth = oACU:GetHealth() + iACUCurShield
                                if -iCurDPSMod < iCurDPSMod then
                                    iTimeToKillTarget = iACUHealth / (iDPS + iCurDPSMod)
                                    if iTimeToKillTarget > 0 and  iTimeToKillTarget < iShortestTimeToKillTarget then
                                        --Are there nearby shields?
                                        local iDistToTravel = (oACU:GetBlueprint().Physics.MaxSpeed or 1.7) * iTimeToKillTarget
                                        local tNearbyShields = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedShield + M27UnitInfo.refCategoryMobileLandShield, oACU:GetPosition(), iDistToTravel, 'Enemy')
                                        if M27Utilities.IsTableEmpty(tNearbyShields) then
                                            iShortestTimeToKillTarget = iTimeToKillTarget
                                            oTarget = oACU
                                        end
                                    end
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': iShortestTimeToKillTarget='..iShortestTimeToKillTarget..'; is oTarget valid='..tostring(M27UnitInfo.IsUnitValid(oTarget))) end
                    end
                end

                if not(oTarget) then
                    --Target the priority override
                    oTarget = oNovax[refoPriorityTargetOverride]
                end
            end
        end
    end

    if not (oTarget) then

        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': In air dom mode so will target enemy AA units')
            end
            tEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA - categories.SUBMERSIBLE, oNovax:GetPosition(), iMaxRange, 'Enemy')
            if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                oTarget = M27Utilities.GetNearestUnit(tEnemyUnits, oNovax:GetPosition(), aiBrain)
            else
                if M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoLastNearestACU]) and not (M27MapInfo.IsUnderwater(aiBrain[M27Overseer.reftLastNearestACU])) then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': WIll target enemy ACU as no AA targets and ACU is on ground')
                    end
                    oTarget = aiBrain[M27Overseer.refoLastNearestACU]
                else
                    tEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryNavalSurface + M27UnitInfo.refCategoryStructure + M27UnitInfo.refCategoryMobileLand, aiBrain[M27Overseer.reftLastNearestACU], iMaxRange * 0.5, 'Enemy')
                    if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                        oTarget = M27Utilities.GetNearestUnit(tEnemyUnits, oNovax:GetPosition(), aiBrain)
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Targeting the nearest enemy unit to the last known ACU position')
                        end
                    end
                end
            end
        elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Want to kill enemy ACU so will target the ACU if we can see it')
            end
            if M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoACUKillTarget]) and M27Utilities.CanSeeUnit(aiBrain, aiBrain[M27Overseer.refoACUKillTarget], true) and not (M27MapInfo.IsUnderwater(aiBrain[M27Overseer.refoACUKillTarget]:GetPosition())) then
                oTarget = aiBrain[M27Overseer.refoACUKillTarget]
            else
                tEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryNavalSurface + M27UnitInfo.refCategoryStructure + M27UnitInfo.refCategoryMobileLand, aiBrain[M27Overseer.reftLastNearestACU], iMaxRange * 0.5, 'Enemy')
                if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                    oTarget = M27Utilities.GetNearestUnit(tEnemyUnits, oNovax:GetPosition(), aiBrain)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Targeting the nearest enemy unit to the last known ACU position')
                    end
                end
            end
        else
            --Normal targeting logic
            local iRange = math.max(20, oNovax:GetBlueprint().Weapon[1].MaxRadius)
            local iSpeed = oNovax:GetBlueprint().Physics.MaxSpeed
            local iTimeToTarget
            local iTimeToKillTarget
            local iDPS = 243
            local iCurDPSMod
            local iBestTargetValue = 0
            local iCurValue
            local bConsideredAllHighValueTargets = false
            local iCurTargetType = 0
            local iCategoriesToSearch
            local iSearchRange
            local iMassFactor
            local iCurShield, iMaxShield
            local tPositionToSearchFrom
            local iNearestShield, iCurShieldDistance, iNearestWater, tPossiblePosition, tPossibleShields, iACUSpeed, iCurAmphibiousGroup

            while not (bConsideredAllHighValueTargets) do
                iCurTargetType = iCurTargetType + 1
                --Default values:
                iMassFactor = 1
                tPositionToSearchFrom = oNovax:GetPosition()
                iSearchRange = iRange


                --HOW BELOW WORKS: all units are treated as euqal priority, the only differencees are thes earch range for these 'high priority' units, and the mass mod value to apply
                if iCurTargetType == 1 then
                    --Nearby low shields
                    iCategoriesToSearch = M27UnitInfo.refCategoryFixedShield + M27UnitInfo.refCategoryMobileLandShield + M27UnitInfo.refCategoryShieldBoat
                    iSearchRange = 90
                    iMassFactor = 4
                elseif iCurTargetType == 2 then
                    --Cruisers near base
                    tPositionToSearchFrom = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                    iSearchRange = 300
                    iCategoriesToSearch = M27UnitInfo.refCategoryCruiser
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Are searching for enemy cruisers, iSearchRange=' .. iSearchRange)
                    end
                elseif iCurTargetType == 3 then
                    iCategoriesToSearch = M27UnitInfo.refCategoryT1Mex
                    iMassFactor = 5
                elseif iCurTargetType == 4 then
                    iCategoriesToSearch = M27UnitInfo.refCategoryT2Mex
                    iMassFactor = 2
                elseif iCurTargetType == 5 then
                    iCategoriesToSearch = M27UnitInfo.refCategoryT3Mex
                    iMassFactor = 1.5
                elseif iCurTargetType == 6 then
                    --Use default values for all of these
                    iCategoriesToSearch = M27UnitInfo.refCategoryLandExperimental + M27UnitInfo.refCategorySMD + M27UnitInfo.refCategorySML + M27UnitInfo.refCategoryExperimentalStructure + M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategoryRadar + M27UnitInfo.refCategoryMAA
                elseif iCurTargetType == 7 then
                    iCategoriesToSearch = M27UnitInfo.refCategoryEngineer - categories.TECH1
                    iSearchRange = math.max(50, iRange)
                elseif iCurTargetType == 8 then
                    iCategoriesToSearch = M27UnitInfo.refCategoryIndirectT2Plus + M27UnitInfo.refCategoryFixedT2Arti
                    iSearchRange = math.max(60, iRange)
                elseif iCurTargetType == 9 then
                    iCategoriesToSearch = categories.COMMAND
                    iSearchRange = iRange + 10
                    if ScenarioInfo.Options.Victory == "demoralization" then
                        iSearchRange = iSearchRange + 100
                        iMassFactor = 3
                    end
                elseif iCurTargetType == 10 then
                    iCategoriesToSearch = categories.VOLATILE * categories.STRUCTURE + categories.VOLATILE * categories.LAND
                    iMassFactor = 2
                    iSearchRange = iRange + 5
                elseif iCurTargetType == 11 then
                    --Nearby mexes - not valued as much as mexes within range
                    iCategoriesToSearch = M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryT3Mex
                    iSearchRange = iRange + 60
                else
                    bConsideredAllHighValueTargets = true
                    break
                end

                tEnemyUnits = aiBrain:GetUnitsAroundPoint(iCategoriesToSearch, oNovax:GetPosition(), iSearchRange, 'Enemy')

                if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': iCurTargetType=' .. iCurTargetType .. '; Found a total of ' .. table.getn(tEnemyUnits) .. ' enemy units, will check if any of them are valid targets')
                    end
                    for iUnit, oUnit in tEnemyUnits do
                        --Is the unit mobile and attached to another and is <=T3?
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Considering enemy unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; Unit state=' .. M27Logic.GetUnitState(oUnit) .. '; Does it contain mobile category=' .. tostring(EntityCategoryContains(categories.MOBILE, oUnit.UnitId)) .. '; is it underwater=' .. tostring(M27UnitInfo.IsUnitUnderwater(oUnit)) .. '; Is it under shield=' .. tostring(M27Logic.IsTargetUnderShield(aiBrain, oUnit, 2000, false, false, false)))
                        end
                        if not (oUnit:IsUnitState('Attached') and EntityCategoryContains(categories.MOBILE, oUnit.UnitId)) then
                            --Is the unit underwater or shielded?
                            if not (M27UnitInfo.IsUnitUnderwater(oUnit)) and not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 2000, false, false, false)) then
                                iCurDPSMod = 0
                                iCurValue = oUnit:GetBlueprint().Economy.BuildCostMass * iMassFactor
                                if oUnit:GetBlueprint().Defense.Shield and M27UnitInfo.IsUnitShieldEnabled(oUnit) then
                                    if oUnit.MyShield.GetHealth and oUnit.MyShield:GetHealth() > 0 then
                                        iCurDPSMod = oUnit:GetBlueprint().Defense.Shield.ShieldRegenRate
                                        if not (iCurDPSMod) then
                                            if EntityCategoryContains(categories.COMMAND + categories.SUBCOMMANDER, oUnit.UnitId) then
                                                iCurDPSMod = M27UnitInfo.GetACUShieldRegenRate(oUnit)
                                                if (iCurDPSMod or 0) == 0 then
                                                    M27Utilities.ErrorHandler('For some reason the unit has a shield with health but no regen rate; oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit), nil, true)
                                                    iCurDPSMod = 0
                                                end
                                            else
                                                M27Utilities.ErrorHandler('For some reason the unit has a shield with health but no regen rate; oUnit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit), nil, true)
                                                iCurDPSMod = 0
                                            end
                                        end
                                    else
                                        iCurDPSMod = 0
                                    end
                                else
                                    iCurDPSMod = 0
                                end
                                iCurDPSMod = iCurDPSMod + (oUnit:GetBlueprint().Defense.RegenRate or 0)
                                iTimeToTarget = math.max(0, M27Utilities.GetDistanceBetweenPositions(oNovax:GetPosition(), oUnit:GetPosition()) - iRange) / iSpeed
                                iCurShield, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oUnit)

                                iTimeToKillTarget = (oUnit:GetHealth() + iCurShield + math.min(iMaxShield - iCurShield, iTimeToTarget * iCurDPSMod)) / math.max(0.001, iDPS - iCurDPSMod)
                                if iMaxShield == 0 and not (EntityCategoryContains(categories.COMMAND, oUnit.UnitId)) then
                                    --If target is already in firing range then prioritise low health units; if its outside firing range then instead prioritise higher health units (that are worth a detour to kill)
                                    if iTimeToTarget > 0 then
                                        iCurValue = iCurValue * math.max(M27UnitInfo.GetUnitHealthPercent(oUnit), 0.25)
                                    elseif oUnit:GetMaxHealth() >= 600 then
                                        iCurValue = iCurValue * (1 + 0.2 * (1-M27UnitInfo.GetUnitHealthPercent(oUnit)))
                                    end
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ' Unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' iCurValue=' .. iCurValue .. '; iTimeToTarget=' .. iTimeToTarget .. '; iTimeToKillTarget=' .. iTimeToKillTarget .. '; iCurShield=' .. iCurShield .. '; iMaxShield=' .. iMaxShield .. '; iCurDPSMod=' .. iCurDPSMod)
                                end
                                iCurValue = iCurValue / math.max(1.5, iTimeToTarget * 0.9 + iTimeToKillTarget)


                                --Massively adjust mass factor if dealing with nearby ACU that can kill before it gets to safety
                                if iCategoriesToSearch == categories.COMMAND and (iTimeToTarget + iTimeToKillTarget) < 60 and (iMaxShield + oUnit:GetMaxHealth()) <= 25000 then
                                    iACUSpeed = oUnit:GetBlueprint().Physics.MaxSpeed
                                    --Get nearest shield
                                    iNearestShield = 10000
                                    tPossibleShields = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedShield, oUnit:GetPosition(), 102, 'Enemy')
                                    --Dont do mobile shields since risk thinking no mobile shields, then revealing them and aborting attack, then losing intle on the mobile shield and repeating attack; so better to just attack if there's a mobile shield
                                    if M27Utilities.IsTableEmpty(tPossibleShields) == false then
                                        for iShield, oShield in tPossibleShields do
                                            iCurShieldDistance = M27Utilities.GetDistanceBetweenPositions(oShield:GetPosition(), oUnit:GetPosition()) - oShield:GetBlueprint().Defense.Shield.ShieldSize * 0.5
                                            if iCurShieldDistance < iNearestShield then
                                                iNearestShield = iCurShieldDistance
                                            end
                                        end
                                    end
                                    --Could the ACU get under a shield before it dies?
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Have a nearby ACU target, will consider if we can kill it before it gets to safety; iNearestShield=' .. iNearestShield .. '; iACUSpeed=' .. iACUSpeed)
                                    end
                                    if iNearestShield / iACUSpeed > iTimeToKillTarget then
                                        iNearestWater = nil
                                        if not (M27MapInfo.bMapHasWater) then
                                            iNearestWater = 10000
                                        else
                                            --Where is the nearest water to the ACU
                                            iCurAmphibiousGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition())
                                            for iDistance = 20, 100, 20 do
                                                for iAngle = 0, 315, 45 do
                                                    tPossiblePosition = M27Utilities.MoveInDirection(oUnit:GetPosition(), iAngle, iDistance, true)
                                                    tPossiblePosition[2] = GetTerrainHeight(tPossiblePosition[1], tPossiblePosition[3])
                                                    if M27MapInfo.IsUnderwater(tPossiblePosition) then
                                                        --Can the enemy ACU path here?
                                                        if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tPossiblePosition) == iCurAmphibiousGroup then
                                                            iNearestWater = iDistance
                                                            break
                                                        end
                                                    end
                                                end
                                                if iNearestWater then
                                                    break
                                                end
                                            end
                                        end
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': iNearestWater=' .. (iNearestWater or 'nil'))
                                        end
                                        if (iNearestWater or 10000) / iACUSpeed > iTimeToKillTarget then
                                            iCurValue = iCurValue * 30
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Think we can kill the ACU so massively increasing the curvalue to ' .. iCurValue)
                                            end
                                        end
                                    end
                                end
                                if iCurValue > iBestTargetValue then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Have a new best target, iBestTargetValue=' .. iBestTargetValue .. '; Target=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
                                    end
                                    iBestTargetValue = iCurValue
                                    oTarget = oUnit
                                end
                            elseif bDebugMessages == true then
                                LOG(sFunctionRef .. ': Target unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. ' is underwater or under a shield')
                            end
                        end
                    end
                elseif bDebugMessages == true then
                    LOG(sFunctionRef .. ': iCurTargetType=' .. iCurTargetType .. ': No units found')
                end
            end

            if not (oTarget) then
                --Get low priority target
                tEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryT3Mex, oNovax:GetPosition(), 200, 'Enemy')
                if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                    local iClosestTarget = 10000
                    local iCurDist
                    for iUnit, oUnit in tEnemyUnits do
                        if oUnit:GetFractionComplete() == 1 and not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 0, false, false, true, false)) then
                            iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oNovax:GetPosition())
                            if iCurDist < iClosestTarget then
                                iClosestTarget = iCurDist
                                oTarget = oUnit
                            end
                        end
                    end
                end

                if not (oTarget) then
                    --Nearest surface naval unit
                    tEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryNavalSurface, tPositionToSearchFrom, 1000, 'Enemy')
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': No high priority targets, will search for lower priority, first with surface naval units. Is table empty=' .. tostring(M27Utilities.IsTableEmpty(tEnemyUnits)))
                    end
                    if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                        oTarget = M27Utilities.GetNearestUnit(tEnemyUnits, tPositionToSearchFrom, aiBrain)
                    else
                        --Target nearest unshielded T3+ mobile land unit or T2 structure; if are none, then just get the nearest mobile land unit:
                        tEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand + M27UnitInfo.refCategoryStructure, tPositionToSearchFrom, 1000, 'Enemy')
                        if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                            local iCurDist
                            local iClosestUnshieldedDist = 10000
                            local iClosestShieldedDist = 10000
                            local oClosestShieldedUnit
                            local oClosestUnshieldedUnit
                            local tNovaxPosition = oNovax:GetPosition()
                            for iUnit, oUnit in tEnemyUnits do
                                iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tNovaxPosition)
                                if iCurDist < math.max(iClosestUnshieldedDist, iClosestShieldedDist) then
                                    if iCurDist < iClosestShieldedDist then
                                        oClosestShieldedUnit = oUnit
                                        iClosestShieldedDist = iCurDist
                                    end
                                    if iCurDist < iClosestUnshieldedDist and iCurDist <= math.max(250, iClosestShieldedDist) then
                                        if not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 10000, false, true, true, false)) then
                                            oClosestUnshieldedUnit = oUnit
                                            iClosestUnshieldedDist = iCurDist
                                        end
                                    end
                                end
                            end

                            if oClosestUnshieldedUnit and iClosestUnshieldedDist <= math.max(250, iClosestShieldedDist + 60) then
                                oTarget = oClosestUnshieldedUnit
                            elseif oClosestShieldedUnit then
                                oTarget = oClosestShieldedUnit
                            else
                                oTarget = aiBrain[M27Overseer.refoLastNearestACU]
                            end

                            if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.TECH3 + categories.EXPERIMENTAL + M27UnitInfo.refCategoryMAA, tEnemyUnits)) then
                                oTarget = M27Utilities.GetNearestUnit(tEnemyUnits, tPositionToSearchFrom, aiBrain)
                            else
                                oTarget = M27Utilities.GetNearestUnit(EntityCategoryFilterDown(categories.TECH3 + categories.EXPERIMENTAL, tEnemyUnits), tPositionToSearchFrom, aiBrain)
                            end
                        end
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oTarget
end

function NovaxCoreTargetLoop(aiBrain, oNovax, bCalledFromUnitDeath)
    --Used so can do forkthread of this in case come across errors
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'NovaxCoreTargetLoop'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetGameTimeSeconds() >= 1980 then bDebugMessages = true end

    local iEffectiveRange = math.max(20, oNovax:GetBlueprint().Weapon[1].MaxRadius) + 10
    local oTarget

    local iOrderType
    local refiLastIssuedOrderType = 'M27NovaxLastOrderType'
    local refoLastIssuedOrderUnit = 'M27NovaxLastOrderUnit'
    local reftLastIssuedOrderLocation = 'M27NovaxLastOrderLocation'
    local refOrderAttack = 1
    local refOrderMove = 2
    oTarget = GetNovaxTarget(aiBrain, oNovax)

    if oTarget then
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': GameTime='..GetGameTimeSeconds()..'; Have a target ' .. oTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oTarget) .. '; will decide whether to attack or move to it; Distance to target=' .. M27Utilities.GetDistanceBetweenPositions(oTarget:GetPosition(), oNovax:GetPosition()))
        end
        if M27Utilities.GetDistanceBetweenPositions(oTarget:GetPosition(), oNovax:GetPosition()) > iEffectiveRange then
            iOrderType = refOrderMove
        else
            iOrderType = refOrderAttack
        end

        if iOrderType == refOrderMove then
            --Has the order changed from before?
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Target out of range so want to move to it.  Position of target=' .. repru(oTarget:GetPosition()) .. '; Position of last order location=' .. repru(oNovax[reftLastIssuedOrderLocation]) .. ' Dist between them=' .. M27Utilities.GetDistanceBetweenPositions((oNovax[reftLastIssuedOrderLocation] or { 0, 0, 0 }), oTarget:GetPosition()))
            end
            if not (iOrderType == oNovax[refiLastIssuedOrderType] and oNovax[reftLastIssuedOrderLocation] and M27Utilities.GetDistanceBetweenPositions(oNovax[reftLastIssuedOrderLocation], oTarget:GetPosition()) <= 8) then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Issuing new order to novax, telling it to move to ' .. repru(oNovax[reftLastIssuedOrderLocation]))
                end
                if not (bCalledFromUnitDeath) or (oNovax.GetNavigator and oNovax:GetNavigator()) then
                    M27Utilities.IssueTrackedClearCommands({ oNovax })
                end
                oNovax[reftLastIssuedOrderLocation] = { oTarget:GetPosition()[1], oTarget:GetPosition()[2], oTarget:GetPosition()[3] }
                IssueMove({ oNovax }, oNovax[reftLastIssuedOrderLocation])
                oNovax[refiLastIssuedOrderType] = iOrderType
                oNovax[refoLastIssuedOrderUnit] = nil
            end
        elseif iOrderType == refOrderAttack then
            --Has the order changed from before?
            if not (iOrderType == oNovax[refiLastIssuedOrderType] and M27UnitInfo.IsUnitValid(oNovax[refoLastIssuedOrderUnit]) and oNovax[refoLastIssuedOrderUnit] == oTarget) then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Issuing new order to novax, telling it to attack target=' .. oTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oTarget))
                end
                if not (bCalledFromUnitDeath) or (oNovax.GetNavigator and oNovax:GetNavigator()) then
                    M27Utilities.IssueTrackedClearCommands({ oNovax })
                end
                IssueAttack({ oNovax }, oTarget)
                oNovax[refiLastIssuedOrderType] = iOrderType
                oNovax[refoLastIssuedOrderUnit] = oTarget
                oNovax[reftLastIssuedOrderLocation] = nil
            end
        else
            M27Utilities.ErrorHandler('Not coded')
        end
    else
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': No target so move to enemy base')
        end
        --No target so move towards enemy base
        iOrderType = refOrderMove
        if not (iOrderType == oNovax[refiLastIssuedOrderType] and oNovax[reftLastIssuedOrderLocation] and M27Utilities.GetDistanceBetweenPositions(oNovax[reftLastIssuedOrderLocation], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) <= 8) then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Issuing new order to novax, telling it to move to nearest enemy start location')
            end
            M27Utilities.IssueTrackedClearCommands({ oNovax })
            oNovax[reftLastIssuedOrderLocation] = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
            IssueMove({ oNovax }, oNovax[reftLastIssuedOrderLocation])
            oNovax[refiLastIssuedOrderType] = iOrderType
            oNovax[refoLastIssuedOrderUnit] = nil
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function NovaxManager(oNovax)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'NovaxManager'
    --if GetGameTimeSeconds() >= 1980 then bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code for oNovax=' .. oNovax.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oNovax))
    end

    if M27UnitInfo.IsUnitValid(oNovax) and not (oNovax['M27ActiveNovaxLoop']) then
        local aiBrain = oNovax:GetAIBrain()
        if aiBrain then
            oNovax['M27ActiveNovaxLoop'] = true

            while M27UnitInfo.IsUnitValid(oNovax) do
                ForkThread(NovaxCoreTargetLoop, aiBrain, oNovax)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitSeconds(1)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ExperimentalGunshipCoreTargetLoop(aiBrain, oUnit, bIsCzar)
    --Decides whether to run, and if not then whether to attack a unit, or move to a location
    --Broad idea (at time of first draft) - target locations that expect to be lightly defended, but try to dominate enemy groundAA when come across threats
    --bIsCzar - will affect some of the logic

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ExperimentalGunshipCoreTargetLoop'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetGameTimeSeconds() >= 2872 and M27UnitInfo.GetUnitLifetimeCount(oUnit) == 1 then bDebugMessages = true end

    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of loop for unit ' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
    end

    local tLocationToMoveTo
    local oAttackTarget
    local tCurPosition = oUnit:GetPosition()
    local iCombatRangeToUse = 35 --Treat units within this range as being in combat range
    local iImmediateCombatRange = 30 --Dont avoid targeting a unit if we are this close to it since we can attack
    if bIsCzar then
        iCombatRangeToUse = 25
        iImmediateCombatRange = 17 --Given czar's speed, this is a reasonable approximation
    end
    local iSAMSearchRange = 60 + iCombatRangeToUse + 6
    local iRecentlySeenCruiserSearchRange = 100
    local tRecentlySeenCruisersToAdd = {} --table of cruisers/carriers that we dont have visiblitliy of but have seen recently so we know to avoid an area
    --Add any pond AA recently seen but not currently visible to this
    if bDebugMessages == true then LOG(sFunctionRef..': Is table of enemy untis by pond empty='..tostring(M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond]))) end
    if M27Utilities.IsTableEmpty(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond]) == false then
        for iPond, tEnemyUnits in M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond] do
            if bDebugMessages == true then LOG(sFunctionRef..': Considering iPond='..iPond..'; is table of enemy units empty for this='..tostring(M27Utilities.IsTableEmpty(tEnemyUnits))) end
            if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                local tEnemyT2PlusNavalAA = EntityCategoryFilterDown(M27UnitInfo.refCategoryCruiserCarrier, M27Team.tTeamData[aiBrain.M27Team][M27Team.reftEnemyUnitsByPond][iPond])
                if bDebugMessages == true then LOG(sFunctionRef..': Is table of cruisers and carriers empty='..tostring(M27Utilities.IsTableEmpty(tEnemyT2PlusNavalAA))) end
                if M27Utilities.IsTableEmpty(tEnemyT2PlusNavalAA) == false then
                    for iUnit, oUnit in tEnemyT2PlusNavalAA do
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering enemy unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Is valid='..tostring(M27UnitInfo.IsUnitValid(oUnit))..'; Is last known position empty='..tostring(M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftLastKnownPosition]))..'; Can see unit='..tostring(M27Utilities.CanSeeUnit(aiBrain, oUnit, true))) end
                        if M27UnitInfo.IsUnitValid(oUnit) and M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftLastKnownPosition]) == false and not(M27Utilities.CanSeeUnit(aiBrain, oUnit, true)) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Distance to last known position='..M27Utilities.GetDistanceBetweenPositions(tCurPosition, oUnit[M27UnitInfo.reftLastKnownPosition])..'; Distance to actual position='..M27Utilities.GetDistanceBetweenPositions(tCurPosition, oUnit:GetPosition())) end
                            if M27Utilities.GetDistanceBetweenPositions(tCurPosition, oUnit[M27UnitInfo.reftLastKnownPosition]) <= iRecentlySeenCruiserSearchRange and M27Utilities.GetDistanceBetweenPositions(tCurPosition, oUnit:GetPosition()) <= iRecentlySeenCruiserSearchRange then
                                if bDebugMessages == true then LOG(sFunctionRef..': About to add naval unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' to AA threats') end
                                table.insert( tRecentlySeenCruisersToAdd, oUnit)
                            end
                        end
                    end
                end
            end
        end
    end


    local reftLastLocationTarget = 'M27AirLastLocationTarget'
    local refoLastUnitTarget = 'M27AirLastUnitTarget'
    local refbPreviouslyRun = 'M27AirPreviouslyRun'
    local refiTimeSinceLastRan = 'M27AirTimePreviouslyRan'
    local refiTimeWhenFirstRan = 'M27AirTimeWhenFirstRan' --First time started to run in this 'cycle' (will reset when recover health)
    local refiTimeWhenFirstEverRan = 'M27AirTimeFirstEverRan' --First time ever ran, wont reset
    local refbCanRunFromLastTarget = 'M27AirCanRunFromLastTarget' --i.e. dont want to track how often we have run from our base or rally point since those are meant to be 'safe'
    local iCurShield = 0
    local iMaxShield = 0
    local bUpdateLocationAttemptCount = true --Used to stop going back and forth to the same location - if true then will increase the count by 1 when we run
    local iMaxPrevTargets = 1
    local iTimeSinceLastRan = GetGameTimeSeconds() - (oUnit[refiTimeSinceLastRan] or -10000)
    if iTimeSinceLastRan <= 90 then
        iMaxPrevTargets = 1
    end
    local iCurDistance
    local iNearestDistance = 100000
    local tNearbyAirExperimental = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirNonScout * categories.EXPERIMENTAL, tCurPosition, 90, 'Ally')
    local iNearbyFriendlyAirExperimental = 0
    if M27Utilities.IsTableEmpty(tNearbyAirExperimental) == false then
        iNearbyFriendlyAirExperimental = table.getn(tNearbyAirExperimental) - 1
    end

    local iSAMThreshold

    function GetSegmentFailedAttempts(tLocation)
        local iSegmentX, iSegmentZ = GetAirSegmentFromPosition(tLocation)
        if not (aiBrain[reftPreviousTargetByLocationCount][iSegmentX]) then
            aiBrain[reftPreviousTargetByLocationCount][iSegmentX] = {}
        end
        return (aiBrain[reftPreviousTargetByLocationCount][iSegmentX][iSegmentZ] or 0)
    end

    local bWantToRun = false

    function IsTargetInDeepWater(oUnit)
        --Czar can ground fire units
        if not (bIsCzar) then
            --if oUnit then
            return M27UnitInfo.IsUnitUnderwater(oUnit)
            --else return M27MapInfo.IsUnderwater(tPositionInstead)
            --end
        else
            --if oUnit then
            if M27MapInfo.iMapWaterHeight - oUnit:GetPosition()[2] > 4 then
                return true
            else
                return false
            end
            --[[else
        if M27MapInfo.iMapWaterHeight - tPositionInstead[2] > 4 then
            return true
        else return false
        end
    end--]]
        end
    end

    iCurShield, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oUnit)
    local iOurTotalHealth = iCurShield + oUnit:GetHealth()

    if bDebugMessages == true then
        if M27UnitInfo.IsUnitValid(oUnit[refoLastUnitTarget]) then
            LOG(sFunctionRef .. ': Last target was a unit ' .. oUnit[refoLastUnitTarget].UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit[refoLastUnitTarget]) .. '; distance to this target=' .. M27Utilities.GetDistanceBetweenPositions(oUnit[refoLastUnitTarget]:GetPosition(), tCurPosition)..'; Last target cur position='..repru(oUnit[refoLastUnitTarget]:GetPosition())..'; recorded last target position='..repru((oUnit[reftLastLocationTarget] or { 'nil' })))
        else
            LOG(sFunctionRef .. ': Last target was a location or nil =' .. repru((oUnit[reftLastLocationTarget] or { 'nil' })))
        end
        LOG(sFunctionRef .. ': Last time run=' .. (oUnit[refiTimeSinceLastRan] or 0) .. '; which is ' .. iTimeSinceLastRan .. ' seconds ago')
        if M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoLastNearestACU]) then LOG(sFunctionRef..': Have valid last nearest ACU, distance to it='..M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.refoLastNearestACU]:GetPosition(), tCurPosition)..'; Time since last ran='..iTimeSinceLastRan..'; iCombatRangeToUse='..iCombatRangeToUse) end
    end

    --ACU OVERRIDE
    --If we are near enemy ACU and it's on ground and its not heavily shielded with T3 Air around it then attack it
    if M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoLastNearestACU]) and not (IsTargetInDeepWater(aiBrain[M27Overseer.refoLastNearestACU])) and M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.refoLastNearestACU]:GetPosition(), tCurPosition) <= 80 then
        --Are we either clsoe to the ACU, or (havent recently run + not far behind air)?
        local iDistToACU = M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.refoLastNearestACU]:GetPosition(), tCurPosition)
        if iDistToACU <= iCombatRangeToUse or (iTimeSinceLastRan >= 50 and (not(aiBrain[refbFarBehindOnAir]) or iDistToACU <= iCombatRangeToUse + 30)) then
            --Do we think we can kill the ACU before we die?
            local iOurDPS = 2700
            if bIsCzar then
                iOurDPS = 3330
            end
            if iNearbyFriendlyAirExperimental > 0 then
                iOurDPS = iOurDPS + (iNearbyFriendlyAirExperimental * iOurDPS)
            end

            local iDistToTarget = M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.refoLastNearestACU]:GetPosition(), tCurPosition)
            local iSpeed = 8
            local iTimeToTarget
            local iActualRange = 30
            if bIsCzar then
                iActualRange = 4
            end
            if iDistToTarget <= iActualRange then
                iTimeToTarget = 0
            else
                iTimeToTarget = (iDistToTarget - iActualRange) / iSpeed
            end
            local iACUCurShield, iACUMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(aiBrain[M27Overseer.refoLastNearestACU])
            local iNearbyShieldHealth = M27Logic.IsTargetUnderShield(aiBrain, aiBrain[M27Overseer.refoLastNearestACU], 0, true, false, false, true)
            local iCrashDamage = 0
            local iACURegen = M27UnitInfo.GetACUShieldRegenRate(aiBrain[M27Overseer.refoLastNearestACU]) + M27UnitInfo.GetACUHealthRegenRate(aiBrain[M27Overseer.refoLastNearestACU])
            if bIsCzar then
                iCrashDamage = 10000
            end

            local iTimeToKillTarget = iTimeToTarget + math.max(1, (iNearbyShieldHealth * 1.1 + aiBrain[M27Overseer.refoLastNearestACU]:GetHealth() + iACUCurShield - iCrashDamage)) / math.max(0.001, iOurDPS - iACURegen)
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': iNearbyShieldHealth=' .. iNearbyShieldHealth .. '; iCrashDamage=' .. iCrashDamage .. '; ACU cur health=' .. aiBrain[M27Overseer.refoLastNearestACU]:GetHealth() .. '; iACUCurShield=' .. (iACUCurShield or 0) .. '; iOurDPS=' .. iOurDPS..'; iACURegen='..iACURegen..'; iTimeToKillTarget='..iTimeToKillTarget)
            end
            if iTimeToKillTarget <= 150 then
                local iTimeUntilWeDie

                local iEnemyAASearchRange = 100
                local tEnemyAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirAA + M27UnitInfo.refCategoryGroundAA, tCurPosition, 100, 'Enemy')
                --Add any pond AA recently seen but not currently visible to this
                if M27Utilities.IsTableEmpty(tRecentlySeenCruisersToAdd) == false then
                    for iUnit, oUnit in tRecentlySeenCruisersToAdd do
                        table.insert(tEnemyAA, oUnit)
                    end
                end



                local iEstimatedEnemyAADPS = 0
                local iEstimatedMassDPSFactor = 0.4
                local iEnemyAAMass = 0

                if M27Utilities.IsTableEmpty(tEnemyAA) == false then
                    for iAA, oAA in tEnemyAA do
                        iEnemyAAMass = iEnemyAAMass + oAA:GetBlueprint().Economy.BuildCostMass
                    end
                end
                iEstimatedEnemyAADPS = iEnemyAAMass * iEstimatedMassDPSFactor

                if iEstimatedEnemyAADPS == 0 then
                    iTimeUntilWeDie = 100000
                else
                    iTimeUntilWeDie = iOurTotalHealth / iEstimatedEnemyAADPS
                end
                if iNearbyFriendlyAirExperimental > 0 then
                    iTimeUntilWeDie = iTimeUntilWeDie * (1 + 0.25 * iNearbyFriendlyAirExperimental)
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iOurTotalHealth=' .. iOurTotalHealth .. '; iEstimatedEnemyAADPS=' .. iEstimatedEnemyAADPS .. '; iTimeToKillTarget=' .. iTimeToKillTarget .. '; iTimeUntilWeDie=' .. iTimeUntilWeDie)
                end
                --Give a small margin of error
                local iTimeToKillFactor = 0.9 --Want to kill enemy in 90% of the time it will take for us to die
                if not (ScenarioInfo.Options.Victory == "demoralization") then
                    iTimeToKillFactor = 0.4
                end
                if iTimeToKillTarget > 2 and (iTimeUntilWeDie * 0.9 - 2) < iTimeToKillTarget then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': We will die before we kill the target so want to revert to normal logic (which will likely ahve us retreat once low on health')
                    end
                    --Dont try and attack enemy ACU
                else
                    bUpdateLocationAttemptCount = false
                    oAttackTarget = aiBrain[M27Overseer.refoLastNearestACU]
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Near enemy ACU and should kill it before we die so will attack it')
                    end
                end
            end
        elseif bDebugMessages == true then
            LOG(sFunctionRef .. ': ENemy ACU is within 80 of us but we have run recently and its not in combat range')
        end
    else
        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoACUKillTarget]) then
            bUpdateLocationAttemptCount = false
            tLocationToMoveTo = aiBrain[M27Overseer.refoACUKillTarget]:GetPosition()
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': In ACUKill mode so going to enemy ACU')
            end
        elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyProtectACU then
            bUpdateLocationAttemptCount = false
            tLocationToMoveTo = M27Utilities.GetACU(aiBrain):GetPosition()
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': In ACU protect mode so going to our ACU')
            end
        end
    end
    if not (oAttackTarget) and M27Utilities.IsTableEmpty(tLocationToMoveTo) then
        --Do we want to run?
        --LOW HEALTH LOGIC
        --Low on health (and not near base if are a czar)
        if not (bIsCzar) or M27Utilities.GetDistanceBetweenPositions(tCurPosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) > 80 then
            local iPercentMod = 0
            if aiBrain[refbPreviouslyRun] then
                if bIsCzar then
                    iPercentMod = 0.4
                elseif aiBrain[refiTimeWhenFirstEverRan] then
                    iPercentMod = 0.3
                else
                    iPercentMod = 0.1
                end
            end

            if M27UnitInfo.GetUnitHealthPercent(oUnit) <= (0.25 + iPercentMod) or (bIsCzar and iCurShield <= iMaxShield * (0.1 + iPercentMod)) then
                bWantToRun = true
            else
                oUnit[refbPreviouslyRun] = false
                local iASFSearchRange = 60
                local iMaxASF = 6
                if bIsCzar then
                    iASFSearchRange = 112 --(range of 120 on AA, so this means ASF should be close enough that can do some damage)
                    iMaxASF = 4 --Czar has better AA so can be used to kite enemy ASFs, hence want to run away at a lower threshold so can kill the asfs gradually
                    --Increase max ASF for Czar if have decent shield health and nearby T2+ buildings
                    if iMaxShield > 0 and iCurShield / iMaxShield >= 0.4 and not (M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure - categories.TECH1, tCurPosition, 35, 'Enemy'))) then
                        iMaxASF = 10
                    end
                end
                if iNearbyFriendlyAirExperimental > 0 then
                    iMaxASF = iMaxASF * (1 + iNearbyFriendlyAirExperimental)
                end

                if oUnit[refiTimeWhenFirstEverRan] then
                    iMaxASF = iMaxASF * 0.75
                end

                local tNearbyASF = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirAA * categories.TECH3, tCurPosition, iASFSearchRange, 'Enemy')
                if M27Utilities.IsTableEmpty(tNearbyASF) == false and table.getn(tNearbyASF) >= iMaxASF then
                    local iValidASF = 0
                    if bIsCzar then
                        --Double-check we have at least x 100% complete ASFs (dont want to run if enemy has them in factories)
                        for iASF, oASF in tNearbyASF do
                            if oASF:GetFractionComplete() >= 1 then
                                iValidASF = iValidASF + 1
                            end
                        end
                    else
                        iValidASF = table.getn(tNearbyASF)
                    end

                    if iValidASF >= iMaxASF then
                        bWantToRun = true
                    end
                end
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': bWantToRun pre adjustments='..tostring(bWantToRun)) end
        --Decide whether to continue attackign our last target (overrides whether we want to run, i.e. if we're about to kill the target then should try and finish it off before we run)
        if M27Utilities.IsTableEmpty(tLocationToMoveTo) and not (oAttackTarget) and (M27UnitInfo.IsUnitValid(oUnit[refoLastUnitTarget]) and oUnit[refoLastUnitTarget]:GetHealth() <= 15000 and M27Utilities.GetDistanceBetweenPositions(oUnit[refoLastUnitTarget]:GetPosition(), tCurPosition) <= iImmediateCombatRange and not (M27Logic.IsTargetUnderShield(aiBrain, oUnit[refoLastUnitTarget], 5000, false, false, false))) then
            --Keep attacking this unit rather than changing our target
            oAttackTarget = oUnit[refoLastUnitTarget]
            bWantToRun = false
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Want to keep attacking our last target as we are near it')
            end
        end

        --(if changing the time since last ran here, then also change for the ACU logic above to be consistent)
        if bWantToRun or (not (oAttackTarget) and iTimeSinceLastRan <= 50) then
            local bStillRun = true
            if not (bWantToRun) then
                if M27UnitInfo.GetUnitHealthPercent(oUnit) >= 0.99 and iCurShield >= iMaxShield * 0.95 then
                    bStillRun = false
                end
            end

            --While running, see if are targets of opportunity that can kill on the way back to base
            --Need to have run for longer if dealing with soulripper vs czar
            --Will target T2 AA first in priority to everything else; will look for targets that are either unshielded or only have a T2 UEF or worse shield covering them
            local iTimeSinceFirstRan = 0
            if oUnit[refiTimeWhenFirstRan] then
                iTimeSinceFirstRan = GetGameTimeSeconds() - oUnit[refiTimeWhenFirstRan]
            end
            if bStillRun and iTimeSinceFirstRan >= 15 and (bIsCzar or iTimeSinceFirstRan >= 25) then
                --Does the enemy not have any SAMs (or other T3 ground AA) within range of us?
                local tNearbyEnemySAMs = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3 + M27UnitInfo.refCategoryCruiserCarrier, tCurPosition, iSAMSearchRange + 10, 'Enemy')
                if M27Utilities.IsTableEmpty(tRecentlySeenCruisersToAdd) == false then
                    for iUnit, oUnit in tRecentlySeenCruisersToAdd do
                        table.insert(tNearbyEnemySAMs, oUnit)
                    end
                end

                if M27Utilities.IsTableEmpty(tNearbyEnemySAMs) then
                    local tNearbyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand + M27UnitInfo.refCategoryStructure + M27UnitInfo.refCategoryNavalSurface - categories.TECH1, tCurPosition, iCombatRangeToUse, 'Enemy')
                    if M27Utilities.IsTableEmpty(tNearbyUnits) then
                        local iClosestUnshieldedEnemy = 10000
                        local oClosestUnshieldedEnemy
                        local iCurDistToCzar
                        local iCurDistToBase
                        local iCzarDistToBase = M27Utilities.GetDistanceBetweenPositions(tCurPosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                        local oClosestT2PlusAA
                        for iUnit, oUnit in tNearbyUnits do
                            if oUnit:GetFractionComplete() >= 0.7 then
                                if not (oClosestT2PlusAA) or EntityCategoryContains(M27UnitInfo.refCategoryGroundAA, oUnit.UnitId) then
                                    iCurDistToCzar = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tCurPosition)
                                    if iCurDistToCzar < iClosestUnshieldedEnemy then
                                        iCurDistToBase = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                        if iCurDistToBase + 6 <= iCzarDistToBase then
                                            if not (M27Logic.IsTargetUnderShield(aiBrain, oUnit, 9000, false, true, false)) then
                                                iClosestUnshieldedEnemy = iCurDistToCzar
                                                oClosestUnshieldedEnemy = oUnit
                                                if EntityCategoryContains(M27UnitInfo.refCategoryGroundAA, oUnit.UnitId) then
                                                    oClosestT2PlusAA = oClosestUnshieldedEnemy
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if oClosestUnshieldedEnemy then
                            bStillRun = false
                            oAttackTarget = oClosestUnshieldedEnemy
                        end
                    end
                end
            end

            if bDebugMessages == true then
                LOG(sFunctionRef .. ': We either want to run, or have recently want to run; bWantToRun=' .. tostring(bWantToRun) .. '; Health %=' .. M27UnitInfo.GetUnitHealthPercent(oUnit) .. '; Cur shield=' .. iCurShield .. '; MaxShield=' .. iMaxShield .. '; bStillRun=' .. tostring(bStillRun))
            end
            if bStillRun then
                if bWantToRun then
                    oUnit[refiTimeSinceLastRan] = GetGameTimeSeconds()
                    if not (oUnit[refbPreviouslyRun]) then
                        oUnit[refiTimeWhenFirstRan] = GetGameTimeSeconds()
                        if not (oUnit[refiTimeWhenFirstEverRan]) then
                            oUnit[refiTimeWhenFirstEverRan] = GetGameTimeSeconds()
                        end
                    end
                end
                oAttackTarget = nil
                bUpdateLocationAttemptCount = false
                tLocationToMoveTo = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                oUnit[refbPreviouslyRun] = true
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': We want to run so will return to base')
                end
                bWantToRun = true --redundancy
            else
                bWantToRun = false
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': bWantToRun post adjustments='..tostring(bWantToRun)) end
        if M27Utilities.IsTableEmpty(tLocationToMoveTo) and not (oAttackTarget) then
            --NEARBY TARGET LOGIC
            --Lots of enemy SAMs or T3 MAA nearby?
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': No immediate targets so will consider units nearby')
            end
            local tNearbySAM = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3, tCurPosition, iSAMSearchRange, 'Enemy')
            if M27Utilities.IsTableEmpty(tRecentlySeenCruisersToAdd) == false then
                for iUnit, oUnit in tRecentlySeenCruisersToAdd do
                    table.insert(tNearbySAM, oUnit)
                end
            end
            iSAMThreshold = 6
            if iNearbyFriendlyAirExperimental > 0 then
                iSAMThreshold = iSAMThreshold * (1 + iNearbyFriendlyAirExperimental)
            end
            if M27UnitInfo.GetUnitHealthPercent(oUnit) <= 0.9 then

                if M27UnitInfo.GetUnitHealthPercent(oUnit) <= 0.7 then
                    iSAMThreshold = iSAMThreshold - 2
                else
                    iSAMThreshold = iSAMThreshold - 1
                end
                if iTimeSinceLastRan <= 60 then
                    iSAMThreshold = iSAMThreshold - 1
                end
            end
            if oUnit[refiTimeWhenFirstEverRan] then
                iSAMThreshold = math.max(math.min(iSAMThreshold, 2), iSAMThreshold - 2)
            end
            if M27Utilities.IsTableEmpty(tNearbySAM) == false and table.getn(tNearbySAM) >= iSAMThreshold then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': At least ' .. iSAMThreshold .. ' T3 AA nearby so want to run unless theyre in range')
                end
                --Are any of the T3 air within range of us? If so and its unshielded, then attack the nearest one
                local oNearestSAM
                iNearestDistance = 100000
                for iSAM, oSAM in tNearbySAM do
                    iCurDistance = M27Utilities.GetDistanceBetweenPositions(oSAM:GetPosition(), tCurPosition)
                    if iCurDistance <= math.min(iCombatRangeToUse, iNearestDistance) and (iCurDistance <= iImmediateCombatRange or GetSegmentFailedAttempts(oSAM:GetPosition()) < iMaxPrevTargets) then
                        if not (M27Logic.IsTargetUnderShield(aiBrain, oSAM, 5000, false, false, false)) then
                            iNearestDistance = iCurDistance
                            oNearestSAM = oSAM
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': oSAM ' .. oSAM.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oSAM) .. ' in range so will attack it unless we can find a closer one')
                            end
                        end
                    end
                end
                if not (oNearestSAM) then
                    bUpdateLocationAttemptCount = false
                    tLocationToMoveTo = GetAirRallyPoint(aiBrain)
                    oUnit[refbPreviouslyRun] = true
                    bWantToRun = true
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': No SAMs in range that weh avent already attacked multiple times so will run')
                    end
                end
            else
                --Not enough AA to consider running; prioritise enemy shields and then ground AA nearby, unless we have run recently in which case try and find the nearest vulnerable mex that we havent targeted multiple times


                --First look for any part-complete or broken shields that arent shielded as a top priority
                local tNearbyShields = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedShield + M27UnitInfo.refCategoryMobileLandShield, tCurPosition, 50, 'Enemy')
                local iCurShield, iMaxShield

                if M27Utilities.IsTableEmpty(tNearbyShields) == false then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Have nearby enemy shields so will see if we want to attack any')
                    end
                    for iShield, oShield in tNearbyShields do
                        if oShield:GetFractionComplete() < 0.98 then
                            iCurShield = 0
                        else
                            iCurShield, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oShield)
                        end
                        if iCurShield < 2000 then
                            iCurDistance = M27Utilities.GetDistanceBetweenPositions(oShield:GetPosition(), tCurPosition)
                            if iCurDistance <= iImmediateCombatRange or GetSegmentFailedAttempts(oShield:GetPosition()) < iMaxPrevTargets then
                                if not (M27Logic.IsTargetUnderShield(aiBrain, oShield, 2000, false, false, false)) then
                                    oAttackTarget = oShield
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Have a small shield so will attack')
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
                if not (oAttackTarget) then
                    --Consider any unshielded AA in range
                    local tNearbyGroundAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, tCurPosition, iCombatRangeToUse, 'Enemy')
                    if M27Utilities.IsTableEmpty(tNearbyGroundAA) == false then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Nearby groundAA< will see if any of it is under a shield')
                        end
                        for iAA, oAA in tNearbyGroundAA do
                            iCurDistance = M27Utilities.GetDistanceBetweenPositions(oAA:GetPosition(), tCurPosition)
                            if iCurDistance <= iImmediateCombatRange or GetSegmentFailedAttempts(oAA:GetPosition()) < iMaxPrevTargets then
                                if not (M27Logic.IsTargetUnderShield(aiBrain, oAA, 2000, false, false, false)) then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Target AA not under shield so will attack')
                                    end
                                    oAttackTarget = oAA
                                    break
                                end
                            end
                        end
                    end
                    if not (oAttackTarget) then
                        --Target nearby shields even if theyre not low health
                        if M27Utilities.IsTableEmpty(tNearbyShields) == false then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Will target the nearest shield even though its a tough one')
                            end
                            iNearestDistance = 10000
                            for iShield, oShield in tNearbyShields do
                                iCurDistance = M27Utilities.GetDistanceBetweenPositions(oShield:GetPosition(), tCurPosition)
                                if iCurDistance < iNearestDistance and (iCurDistance <= iImmediateCombatRange or GetSegmentFailedAttempts(oShield:GetPosition()) < iMaxPrevTargets) then
                                    oAttackTarget = oShield
                                    iNearestDistance = iCurDistance
                                end
                            end
                        end
                        if not (oAttackTarget) then
                            --No nearby shields, and no unshielded AA within firing range; check for AA that is likely able to attack us
                            if M27Utilities.IsTableEmpty(tNearbyGroundAA) == false then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': WIll target the nearest AA even though it may be shielded')
                                end
                                iNearestDistance = 10000
                                for iAA, oAA in tNearbyGroundAA do
                                    iCurDistance = M27Utilities.GetDistanceBetweenPositions(oAA:GetPosition(), tCurPosition)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Considering oAA=' .. oAA.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAA) .. '; GetSegmentFailedAttempts(oAA:GetPosition())=' .. GetSegmentFailedAttempts(oAA:GetPosition()) .. '; IsTargetUnderShield=' .. tostring(M27Logic.IsTargetUnderShield(aiBrain, oAA, 5000, false, false, false)))
                                    end
                                    if iCurDistance < iNearestDistance and (GetSegmentFailedAttempts(oAA:GetPosition()) < iMaxPrevTargets or (iCurDistance <= iImmediateCombatRange and not (M27Logic.IsTargetUnderShield(aiBrain, oAA, 5000, false, false, false)))) then
                                        iNearestDistance = iCurDistance
                                        oAttackTarget = oAA
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Have a valid target oAA=' .. oAA.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAA))
                                        end
                                    end
                                end
                            end
                            if not (oAttackTarget) then
                                tNearbyGroundAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, tCurPosition, iCombatRangeToUse + 30, 'Enemy')
                                if M27Utilities.IsTableEmpty(tNearbyGroundAA) == false then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Have AA further away that can probably hit us so will target it unless we have targeted too many times already')
                                    end
                                    iNearestDistance = 10000
                                    for iAA, oAA in tNearbyGroundAA do
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Considering oAA=' .. oAA.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; GetSegmentFailedAttempts(oAA:GetPosition())=' .. GetSegmentFailedAttempts(oAA:GetPosition()) .. '; IsTargetUnderShield=' .. tostring(M27Logic.IsTargetUnderShield(aiBrain, oAA, 5000, false, false, false)))
                                        end
                                        iCurDistance = M27Utilities.GetDistanceBetweenPositions(oAA:GetPosition(), tCurPosition)
                                        if iCurDistance < iNearestDistance and (GetSegmentFailedAttempts(oAA:GetPosition()) < iMaxPrevTargets) or (iCurDistance <= iImmediateCombatRange and not (M27Logic.IsTargetUnderShield(aiBrain, oAA, 5000, false, false, false))) then
                                            iNearestDistance = iCurDistance
                                            oAttackTarget = oAA
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Have a valid target oAA=' .. oAA.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAA))
                                            end
                                        end
                                    end
                                end
                                if not (oAttackTarget) then
                                    --No shields or groundAA nearby; Was our last target a shield or groundAA unit (e.g. may have issued attack order and hten somehow lost visibility/intel) or is within combat range and on ground?
                                    if oUnit[refoLastUnitTarget] and M27UnitInfo.IsUnitValid(oUnit[refoLastUnitTarget]) and GetSegmentFailedAttempts(oUnit[refoLastUnitTarget]:GetPosition()) < iMaxPrevTargets and (EntityCategoryContains(M27UnitInfo.refCategoryGroundAA + M27UnitInfo.refCategoryFixedShield + M27UnitInfo.refCategoryMobileLandShield, oUnit[refoLastUnitTarget].UnitId) or (not (IsTargetInDeepWater(oUnit[refoLastUnitTarget])) and M27Utilities.GetDistanceBetweenPositions(oUnit[refoLastUnitTarget]:GetPosition(), tCurPosition) <= (iCombatRangeToUse + 2))) then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Our last target was a shield or AA and is still valid so will attack it')
                                        end
                                        oAttackTarget = oUnit[refoLastUnitTarget]
                                    else
                                        --Are there any units in-range with at least 190 mass value? Then target them
                                        local tEnemiesInRange = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand + M27UnitInfo.refCategoryNavalSurface + M27UnitInfo.refCategoryStructure, tCurPosition, iCombatRangeToUse, 'Enemy')
                                        if M27Utilities.IsTableEmpty(tEnemiesInRange) == false then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Have nearby enemies, will see if any have significant mass value')
                                            end
                                            local iMinMassWanted = 190
                                            if bIsCzar then
                                                iMinMassWanted = 400
                                            end
                                            for iEnemy, oEnemy in tEnemiesInRange do
                                                if not (IsTargetInDeepWater(oEnemy)) and oEnemy:GetBlueprint().Economy.BuildCostMass >= iMinMassWanted and GetSegmentFailedAttempts(oEnemy:GetPosition()) < iMaxPrevTargets then
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Have a nearby enemy unit with a mass cost of ' .. oEnemy:GetBlueprint().Economy.BuildCostMass)
                                                    end
                                                    oAttackTarget = oEnemy
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    --LONG RANGE TARGETS
    --Do we still need a target (as dont want to run and no nearby units of interest)?
    if not (oAttackTarget) and M27Utilities.IsTableEmpty(tLocationToMoveTo) then
        local bDefensiveExperimental = false --True if want to use experimental defensively
        if aiBrain[refbFarBehindOnAir] or (not(aiBrain[refbHaveAirControl]) and aiBrain[refiAirAAWanted] >= 20) then bDefensiveExperimental = true end
        local iDefensiveModDistanceThreshold = 100000
        local iActualDistanceThreshold = 100000
        if bDefensiveExperimental then
            --Increase distance threshold if we have good intel
            iDefensiveModDistanceThreshold = math.max(125, aiBrain[refiBomberDefenceCriticalThreatDistance], math.min(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.35, aiBrain[refiBomberDefenceModDistance])) --Used if we are using experimental defensively
            iActualDistanceThreshold = iDefensiveModDistanceThreshold + 40
            local iIntelCoverage = M27Logic.GetIntelCoverageOfPosition(aiBrain, tCurPosition, nil, true)
            if iIntelCoverage + 60 >= iDefensiveModDistanceThreshold then
                iDefensiveModDistanceThreshold = math.min(math.max(140, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.4), iDefensiveModDistanceThreshold + 40)
                iActualDistanceThreshold = math.max(iDefensiveModDistanceThreshold + 20, iActualDistanceThreshold + 20)
            end
            if bDebugMessages == true then LOG(sFunctionRef..': iDefensiveModDistanceThreshold='..iDefensiveModDistanceThreshold..'; aiBrain[refiBomberDefenceCriticalThreatDistance]='..aiBrain[refiBomberDefenceCriticalThreatDistance]..'; aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.35='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.35..'; aiBrain[refiBomberDefenceModDistance]='..aiBrain[refiBomberDefenceModDistance]..'; iActualDistanceThreshold='..iActualDistanceThreshold) end
        end
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': No nearby targets so will consider further away targets. bDefensiveExperimental='..tostring(bDefensiveExperimental)..'; iDefensiveModDistanceThreshold='..iDefensiveModDistanceThreshold..'; refiTimeWhenFirstEverRan=' .. (oUnit[refiTimeWhenFirstEverRan] or 'nil'))
        end
        --Is the enemy ACU on land, has minimal AA near it, and isn't under >=10k of shields?
        if M27UnitInfo.IsUnitValid(aiBrain[M27Overseer.refoLastNearestACU]) and (not(bDefensiveExperimental) or M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.reftLastNearestACU]) <= iDefensiveModDistanceThreshold) and not (IsTargetInDeepWater(aiBrain[M27Overseer.refoLastNearestACU])) and not (M27Logic.IsTargetUnderShield(aiBrain, aiBrain[M27Overseer.refoLastNearestACU], 14000, false, false, true)) and GetSegmentFailedAttempts(aiBrain[M27Overseer.refoLastNearestACU]:GetPosition()) < iMaxPrevTargets then
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Can see enemy ACU and its on land and not well shielded so head towards it subject to intel')
            end

            if not (oUnit[refiTimeWhenFirstEverRan]) or M27Logic.GetIntelCoverageOfPosition(aiBrain, aiBrain[M27Overseer.reftLastNearestACU], 40, true) then

                if M27Utilities.CanSeeUnit(aiBrain, aiBrain[M27Overseer.refoLastNearestACU], true) or aiBrain[M27Overseer.refoLastNearestACU] == oUnit[refoLastUnitTarget] then
                    oAttackTarget = aiBrain[M27Overseer.refoLastNearestACU]
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Last ACU position based on unit=' .. repru(oAttackTarget:GetPosition()))
                    end
                else
                    tLocationToMoveTo = aiBrain[M27Overseer.reftLastNearestACU]
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Last ACU position based on location=' .. repru(tLocationToMoveTo))
                    end
                end
            end
        end
        if not (oAttackTarget) and M27Utilities.IsTableEmpty(tLocationToMoveTo) then
            --Alternative: Target enemy experimental if within 55% of our base, or within 100 of us, or 60% if it's our last target, provided it's on land
            if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyLandExperimentals]) == false then
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Enemy has land experimerntasls so will see if any are close subject to intel')
                end
                local tPotentialTargets = {}
                local iPotentialTargets = 0
                local iDistFromBase
                for iExperimental, oExperimental in aiBrain[M27Overseer.reftEnemyLandExperimentals] do
                    if M27UnitInfo.IsUnitValid(oExperimental) and oExperimental:GetFractionComplete() >= 0.05 and M27Utilities.CanSeeUnit(aiBrain, oExperimental, true) and GetSegmentFailedAttempts(oExperimental:GetPosition()) < iMaxPrevTargets and (M27Utilities.GetDistanceBetweenPositions(oExperimental:GetPosition(), tCurPosition) <= 120 or (M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oExperimental:GetPosition(), false) <= aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.6 and iDistFromBase <= aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.55 or oUnit[refoLastUnitTarget] == oExperimental)) then
                        iDistFromBase = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oExperimental:GetPosition(), false)
                        if (not(bDefensiveExperimental) or (iDistFromBase <= iDefensiveModDistanceThreshold and M27Utilities.GetDistanceBetweenPositions(oExperimental:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iActualDistanceThreshold)) and not (oUnit[refiTimeWhenFirstEverRan]) or iDistFromBase <= aiBrain[refiBomberDefenceCriticalThreatDistance] + 40 or M27Logic.GetIntelCoverageOfPosition(aiBrain, oExperimental:GetPosition(), 30, true) then
                            iPotentialTargets = iPotentialTargets + 1
                            tPotentialTargets[iPotentialTargets] = oExperimental
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Potential experimental target found')
                            end
                        end
                    end
                end
                if iPotentialTargets > 0 then
                    oAttackTarget = M27Utilities.GetNearestUnit(tPotentialTargets, tCurPosition, aiBrain)
                end
            end
            if not (oAttackTarget) then
                --Is the enemy base vulnerable?
                if not(bDefensiveExperimental) and GetSegmentFailedAttempts(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) < iMaxPrevTargets then
                    local tSAMByBase = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), math.max(iSAMSearchRange + 10, 120), 'Enemy')
                    local iSAMByBase = 0
                    if M27Utilities.IsTableEmpty(tSAMByBase) == false then
                        iSAMByBase = table.getn(tSAMByBase)
                    end
                    if iSAMByBase < math.max(2, (iSAMThreshold - 1)) then
                        if not (oUnit[refiTimeWhenFirstEverRan]) or M27Logic.GetIntelCoverageOfPosition(aiBrain, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), 40, true) then
                            tLocationToMoveTo = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
                        end
                    end
                end
                if M27Utilities.IsTableEmpty(tLocationToMoveTo) then
                    --Alternative: Vulnerable T2 or T3 mexes (mexes with minimal AA and shielding)
                    local iMinDistanceAwayFromEnemyBase = 0
                    if oUnit[refiTimeWhenFirstEverRan] then
                        iMinDistanceAwayFromEnemyBase = 80
                    end
                    if bDefensiveExperimental then iMinDistanceAwayFromEnemyBase = iMinDistanceAwayFromEnemyBase + math.min(125, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.5) end
                    local tVulnerableMexes = GetVulnerableMexes(aiBrain, tCurPosition, 14000, iMinDistanceAwayFromEnemyBase)
                    if M27Utilities.IsTableEmpty(tVulnerableMexes) == false then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Have vulnerable mexes so will target the nearest one')
                        end
                        iNearestDistance = 100000
                        for iLocation, tLocation in tVulnerableMexes do
                            iCurDistance = M27Utilities.GetDistanceBetweenPositions(tCurPosition, tLocation)
                            if iCurDistance < iNearestDistance and iCurDistance < iActualDistanceThreshold and GetSegmentFailedAttempts(tLocation) < iMaxPrevTargets then
                                if not(bDefensiveExperimental) or M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tLocation) <= iDefensiveModDistanceThreshold then
                                    if not (oUnit[refiTimeWhenFirstEverRan]) or GetTimeSinceLastScoutedLocation(aiBrain, tLocation) <= 60 or M27Logic.GetIntelCoverageOfPosition(aiBrain, tLocation, 20, true) then
                                        tLocationToMoveTo = tLocation
                                        iNearestDistance = iCurDistance
                                        if bDebugMessages == true then LOG(sFunctionRef..': Found a mex, iCurDistance='..iCurDistance..'; Distance to base='..M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tLocation)..'; Mod dist to base='..M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tLocation)) end
                                    end
                                end
                            end
                        end
                    end
                end
                if M27Utilities.IsTableEmpty(tLocationToMoveTo) and not (oAttackTarget) then
                    --Nearest bomber shortlist target that doesnt have AA protecting it based on our position
                    if M27Utilities.IsTableEmpty(aiBrain[reftBomberTargetShortlist]) == false then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Will see if any targets on our bomber shortlist to go for')
                        end
                        local iNearestTargetDist = 10000
                        local tEnemyT3AA, iDistFromGunshipToTarget, iDistFromGunshipToAA, iDistFromTargetToAA, iAngleFromGunshipToTarget, iAngleFromGunshipToAA
                        tEnemyT3AA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3, tCurPosition, aiBrain[refiMaxScoutRadius], 'Enemy')
                        local iRangeToUse = 65
                        local bVulnerable
                        for iTable, tSubtable in aiBrain[reftBomberTargetShortlist] do
                            if M27UnitInfo.IsUnitValid(tSubtable[refiShortlistUnit]) then
                                iCurDistance = M27Utilities.GetDistanceBetweenPositions(tSubtable[refiShortlistUnit]:GetPosition(), tCurPosition)
                                if iCurDistance < iNearestTargetDist and iCurDistance < iActualDistanceThreshold and GetSegmentFailedAttempts(tSubtable[refiShortlistUnit]:GetPosition()) < iMaxPrevTargets and (not(bDefensiveExperimental) or M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tSubtable[refiShortlistUnit]:GetPosition()) <= iDefensiveModDistanceThreshold) then
                                    bVulnerable = false
                                    --Are there T3 AA on the way to this target?
                                    iDistFromGunshipToTarget = iCurDistance
                                    iAngleFromGunshipToTarget = M27Utilities.GetAngleFromAToB(tCurPosition, tSubtable[refiShortlistUnit]:GetPosition())
                                    if M27Utilities.IsTableEmpty(tEnemyT3AA) == false then
                                        for iAA, oAA in tEnemyT3AA do
                                            iDistFromGunshipToAA = M27Utilities.GetDistanceBetweenPositions(tCurPosition, oAA:GetPosition())
                                            iAngleFromGunshipToAA = M27Utilities.GetAngleFromAToB(tCurPosition, oAA:GetPosition())
                                            iDistFromTargetToAA = M27Utilities.GetDistanceBetweenPositions(tSubtable[refiShortlistUnit]:GetPosition(), oAA:GetPosition())
                                            if not (M27Utilities.IsLineFromAToBInRangeOfCircleAtC(iDistFromGunshipToTarget, iDistFromGunshipToAA, iDistFromTargetToAA, iAngleFromGunshipToTarget, iAngleFromGunshipToAA, iRangeToUse)) then
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Have a target and no AA that can hit us if we attack it so will go for it if its nearest')
                                                end
                                                bVulnerable = true
                                                break
                                            end
                                        end
                                    else
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Have a target and no T3 AA so will go for it if its nearest')
                                        end
                                        bVulnerable = true
                                    end

                                    if bVulnerable then
                                        iNearestTargetDist = iCurDistance
                                        tLocationToMoveTo = tSubtable[refiShortlistUnit]:GetPosition()
                                    end
                                end
                            end
                        end
                    end
                    if M27Utilities.IsTableEmpty(tLocationToMoveTo) and not (oAttackTarget) then
                        --Alternative: any unit within half of distance to enemy base (vs our base)
                        local tEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand + M27UnitInfo.refCategoryNavalSurface + M27UnitInfo.refCategoryStructure, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], math.min(iDefensiveModDistanceThreshold, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.5), 'Enemy')
                        if M27Utilities.IsTableEmpty(tEnemyUnits) == false then
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Have enemy units within 50% radius around our base so will target nearest one')
                            end
                            iNearestDistance = 10000
                            for iEnemy, oEnemy in tEnemyUnits do
                                if GetSegmentFailedAttempts(oEnemy:GetPosition()) < iMaxPrevTargets then
                                    iCurDistance = M27Utilities.GetDistanceBetweenPositions(oEnemy:GetPosition(), tCurPosition)
                                    if iCurDistance < iNearestDistance then
                                        oAttackTarget = oEnemy
                                        iNearestDistance = iCurDistance
                                    end
                                end
                            end
                        end
                        if not (oAttackTarget) and M27Utilities.IsTableEmpty(tLocationToMoveTo) then
                            --Rally point
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Cant find any targets so will go to nearest rally point')
                            end
                            bUpdateLocationAttemptCount = false
                            tLocationToMoveTo = GetAirRallyPoint(aiBrain)
                        end
                    end
                end
            end
        end
    end

    --Update tracking - if we want to run, then increase the failed count on our previous target or location
    if bWantToRun and oUnit[refbCanRunFromLastTarget] then
        local tRunPosition
        if oUnit[refoLastUnitTarget] then
            local tTempPos = oUnit[refoLastUnitTarget]:GetPosition()
            tRunPosition = { tTempPos[1], tTempPos[2], tTempPos[3] }
        else
            tRunPosition = { oUnit[reftLastLocationTarget][1], oUnit[reftLastLocationTarget][2], oUnit[reftLastLocationTarget][3] }
        end

        local iSegmentX, iSegmentZ = GetAirSegmentFromPosition(tRunPosition)
        for iXAdj = -1, 1 do
            for iZAdj = -1, 1 do
                if not (aiBrain[reftPreviousTargetByLocationCount][iSegmentX + iXAdj]) then
                    aiBrain[reftPreviousTargetByLocationCount][iSegmentX + iXAdj] = {}
                end
                aiBrain[reftPreviousTargetByLocationCount][iSegmentX + iXAdj][iSegmentZ + iZAdj] = (aiBrain[reftPreviousTargetByLocationCount][iSegmentX + iXAdj][iSegmentZ + iZAdj] or 0) + 1
                --Reset after 3 minutes
                M27Utilities.DelayChangeSubtable(aiBrain, reftPreviousTargetByLocationCount, iSegmentX + iXAdj, iSegmentZ + iZAdj, -1, 180)
            end
        end
    end


    --Process the order to attack/move:
    if oAttackTarget or M27Utilities.IsTableEmpty(tLocationToMoveTo) == false then
        oUnit[refbCanRunFromLastTarget] = bUpdateLocationAttemptCount
        if bDebugMessages == true then
            local tPosition
            if oAttackTarget then
                tPosition = oAttackTarget:GetPosition()
            else
                tPosition = tLocationToMoveTo
            end
            LOG(sFunctionRef .. ': Have a target; Experimental air unit state=' .. M27Logic.GetUnitState(oUnit) .. '; bUpdateLocationAttemptCount=' .. tostring(bUpdateLocationAttemptCount) .. '; Position of target=' .. repru(tPosition) .. '; is oAttackTarget a valid unit=' .. tostring(M27UnitInfo.IsUnitValid(oAttackTarget)))
        end

        --Wierd bug where can give e.g. a czar a move order, it's shown as being issued the order in the logic, but it then fails to move.  Happens when its constructed so likely it was given an order while under construction then it was cleared as a 1-off on completion.  Solution is to check the unit state
        local iSegmentX, iSegmentZ
        if oAttackTarget then
            local bRefreshAttack = false

            if (not (oAttackTarget == oUnit[refoLastUnitTarget]) and (not (bIsCzar) or M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oAttackTarget:GetPosition()) >= 2)) or M27Logic.IsUnitIdle(oUnit) then
                bRefreshAttack = true
            elseif bIsCzar and oAttackTarget == oUnit[refoLastUnitTarget] and (M27Utilities.IsTableEmpty(oUnit[reftLastLocationTarget]) or M27Utilities.GetDistanceBetweenPositions(oUnit[reftLastLocationTarget], oAttackTarget:GetPosition()) >= 3) then
                bRefreshAttack = true
            elseif oAttackTarget == oUnit[refoLastUnitTarget] and oUnit.GetNavigator then
                local oNavigator = oUnit:GetNavigator()
                if oNavigator and oNavigator.GetCurrentTargetPos then
                    if bDebugMessages == true then LOG(sFunctionRef..': Distance between our navigator target and the target unit='..M27Utilities.GetDistanceBetweenPositions(oNavigator:GetCurrentTargetPos(), oAttackTarget:GetPosition())) end
                    if M27Utilities.GetDistanceBetweenPositions(oNavigator:GetCurrentTargetPos(), oAttackTarget:GetPosition()) >= 3.5 then
                        bRefreshAttack = true
                        LOG(sFunctionRef..': INCONSISTENT TARGETS, will refresh')
                    end
                end
            end
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Attacking target. bRefreshAttack=' .. tostring(bRefreshAttack) .. '; bIsCzar=' .. tostring(bIsCzar) .. '; oAttackTarget=' .. oAttackTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAttackTarget) .. '; Position=' .. repru(oAttackTarget:GetPosition()) .. '; Is this the same as last target=' .. tostring(oAttackTarget == oUnit[refoLastUnitTarget]) .. '; Is last target location empty=' .. tostring(M27Utilities.IsTableEmpty(oUnit[reftLastLocationTarget])) .. '; Last target=' .. repru(oUnit[reftLastLocationTarget] or { 'nil' }))
                if M27UnitInfo.IsUnitValid(oUnit[refoLastUnitTarget]) then
                    LOG(sFunctionRef .. ': Last unit target=' .. oUnit[refoLastUnitTarget].UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit[refoLastUnitTarget]) .. '; Position=' .. repru(oUnit[refoLastUnitTarget]:GetPosition()))
                else
                    LOG(sFunctionRef .. ': Last unit target isnt valid')
                end
            end
            local tTempLocation
            if bRefreshAttack then
                M27Utilities.IssueTrackedClearCommands({ oUnit })
                oUnit[refoLastUnitTarget] = oAttackTarget
                if bIsCzar then
                    --Ground fire if target is underwater
                    if M27UnitInfo.IsUnitUnderwater(oAttackTarget) then
                        IssueAttack({ oUnit }, oAttackTarget:GetPosition())
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Given attack ground order to try and hit unit ' .. oAttackTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAttackTarget) .. ' at position ' .. repru(oAttackTarget:GetPosition()))
                        end
                    else
                        --Are we close to the target? If so then move slightly beyond it to reduce the likelihood they can keep outrunning us
                        local iDistToTarget = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oAttackTarget:GetPosition())
                        if iDistToTarget <= 8 then
                            tTempLocation = M27Utilities.MoveInDirection(oUnit:GetPosition(), M27Utilities.GetAngleFromAToB(oUnit:GetPosition(), oAttackTarget:GetPosition()), iDistToTarget + 2, true)
                        else
                            tTempLocation = oAttackTarget:GetPosition()
                        end
                        IssueMove({ oUnit }, tTempLocation)

                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Given move order to go to ' .. repru(tTempLocation) .. '; unit position=' .. repru(oAttackTarget:GetPosition()) .. ' so czar will go near unit to attack it; unit ' .. oAttackTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAttackTarget) .. ' at position ' .. repru(oAttackTarget:GetPosition()))
                        end
                    end
                else
                    IssueAttack({ oUnit }, oAttackTarget)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Given attack unit order to ' .. oAttackTarget.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oAttackTarget) .. ' at position ' .. repru(oAttackTarget:GetPosition()))
                    end
                end
                --if bUpdateLocationAttemptCount then iSegmentX, iSegmentZ = GetAirSegmentFromPosition(oAttackTarget:GetPosition()) end
            end
            if bIsCzar then
                if bRefreshAttack then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': bRefreshAttack is true so will update last location target from ' .. repru((oUnit[reftLastLocationTarget] or { 'nil' })) .. ' to ' .. repru(oAttackTarget:GetPosition()))
                    end
                    if M27Utilities.IsTableEmpty(tTempLocation) then
                        --redundancy as shouldve alreayd set above
                        tTempLocation = oAttackTarget:GetPosition()
                    end
                    oUnit[reftLastLocationTarget] = { tTempLocation[1], tTempLocation[2], tTempLocation[3] }
                elseif bDebugMessages == true then
                    LOG(sFunctionRef .. ': bRefreshAttack is false so wont update the last location target as it hasnt changed')
                end
            else
                oUnit[reftLastLocationTarget] = nil
            end
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Unit to attack position=' .. repru(oAttackTarget:GetPosition()))
            end
        else
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': tLocationToMoveTo=' .. repru(tLocationToMoveTo) .. '; oUnit[reftLastLocationTarget]=' .. repru(oUnit[reftLastLocationTarget] or { 'nil' }))
            end
            if not (oUnit[reftLastLocationTarget]) or (bIsCzar and M27Utilities.GetDistanceBetweenPositions(oUnit[reftLastLocationTarget], tLocationToMoveTo) >= 3.5) or M27Utilities.GetDistanceBetweenPositions(oUnit[reftLastLocationTarget], tLocationToMoveTo) >= 5 or M27Logic.IsUnitIdle(oUnit) then
                M27Utilities.IssueTrackedClearCommands({ oUnit })
                IssueMove({ oUnit }, tLocationToMoveTo)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Updating last location target from ' .. repru(oUnit[reftLastLocationTarget] or { 'nil' }) .. ' to ' .. repru(tLocationToMoveTo))
                end
                oUnit[reftLastLocationTarget] = { tLocationToMoveTo[1], tLocationToMoveTo[2], tLocationToMoveTo[3] }
                --if bUpdateLocationAttemptCount then iSegmentX, iSegmentZ = GetAirSegmentFromPosition(tLocationToMoveTo) end
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Given move order to a location ' .. repru(tLocationToMoveTo))
                end
            end
            oUnit[refoLastUnitTarget] = nil
        end
        --Moved this earlier and changed so only increase on run rather than every time
        --[[if iSegmentX and bUpdateLocationAttemptCount then
    for iXAdj = -1, 1 do
        for iZAdj = -1, 1 do
            if not(aiBrain[reftPreviousTargetByLocationCount][iSegmentX + iXAdj]) then aiBrain[reftPreviousTargetByLocationCount][iSegmentX + iXAdj] = {} end
            aiBrain[reftPreviousTargetByLocationCount][iSegmentX + iXAdj][iSegmentZ + iZAdj] = (aiBrain[reftPreviousTargetByLocationCount][iSegmentX + iXAdj][iSegmentZ + iZAdj] or 0) + 1
            --Reset after 3 minutes
            M27Utilities.DelayChangeSubtable(aiBrain, reftPreviousTargetByLocationCount, iSegmentX + iXAdj, iSegmentZ + iZAdj, -1, 180)
        end
    end
end--]]
    else
        M27Utilities.ErrorHandler('Couldnt find any target location or unit for soulripper with ID=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

--CzarCoreTargetLoop

function ExperimentalBomberCoreTargetLoop(aiBrain, oUnit)
    --Decided to go with standard bomber targeting approach and just add custom logic into that rather than something completely new
    M27Utilities.ErrorHandler('To add code') --Not in use at the moment
end

function ExperimentalAirManager(oUnit)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ExperimentalAirManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code for unit=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
    end

    if M27UnitInfo.IsUnitValid(oUnit) and not (oUnit['M27ActiveExperimentalLoop']) then
        local aiBrain = oUnit:GetAIBrain()
        local bCybran
        local bAeon
        local bSeraphim
        if aiBrain then
            oUnit['M27ActiveExperimentalLoop'] = true
            if EntityCategoryContains(categories.CYBRAN, oUnit.UnitId) then
                bCybran = true
            elseif EntityCategoryContains(categories.AEON, oUnit.UnitId) then
                bAeon = true
            elseif EntityCategoryContains(categories.SERAPHIM, oUnit.UnitId) then
                bSeraphim = true
            else
                --Use same logic as cybran gunship for other factions
                bCybran = true
            end

            while M27UnitInfo.IsUnitValid(oUnit) do
                if bCybran or bAeon then
                    ForkThread(ExperimentalGunshipCoreTargetLoop, aiBrain, oUnit, bAeon)
                elseif bSeraphim then
                    --Use normal bomber logic (below commented out is in case ever decide want to do something completely different)
                    --ForkThread(ExperimentalBomberCoreTargetLoop, aiBrain, oUnit)
                end

                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitSeconds(1)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GunshipManager(aiBrain)
    --Handles logic for available T1-T3 gunship units; Gunship logic will treat every gunship as being available unless it's gone for refueling, so is different to the concept for bombers where they get assigned an individual unit to target.  Instead gunship targeting is reassessed every cycle
    --Will use gunships as a group - i.e. 1 large group of gunships, rather than splitting them up into separate groups

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GunshipManager'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if aiBrain:GetArmyIndex() == 3 and GetGameTimeSeconds() >= 600 then bDebugMessages = true end

    if M27Utilities.IsTableEmpty(aiBrain[reftAvailableGunships]) == false then
        --First get the nearest threat that we want to focus on, then decide how we will approach it
        local iClosestEnemyDist = 100000
        local iCurEnemyDist
        local oClosestEnemy
        local iGunshipOperationalRange = math.max(aiBrain[refiBomberDefenceModDistance] + 30, 150)
        local iAvailableGunships = table.getn(aiBrain[reftAvailableGunships])
        if iAvailableGunships > 4 then  iGunshipOperationalRange = iGunshipOperationalRange + 8 * (iAvailableGunships - 4) end
        local iMaxDirectLineExtraDist = math.min(100, 20 + 8 * iAvailableGunships) --Amount of extra search range on units where the mod range is within the operational range
        if bDebugMessages == true then LOG(sFunctionRef..': About to start main gunship logic, Gunships available='..iAvailableGunships..'; Gunship range='..iGunshipOperationalRange..'; iMaxDirectLineExtraDist='..iMaxDirectLineExtraDist) end

        function ConsiderTargetingUnit(oUnit)
            if not(oUnit:IsUnitState('Attached')) and not(M27UnitInfo.IsUnitUnderwater(oUnit)) and not(EntityCategoryContains(categories.UNTARGETABLE, oUnit.UnitId)) then
                iCurEnemyDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                if bDebugMessages == true then LOG(sFunctionRef..': Unit threatening mex='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iCurEnemyDist='..iCurEnemyDist) end
                if iCurEnemyDist < iClosestEnemyDist then
                    iClosestEnemyDist = iCurEnemyDist
                    oClosestEnemy = oUnit
                end
            end
        end



        function SendGunshipMoveOrder(tUnits, tTarget)
            local iGunshipMoveTolerance = 3 --If last move target was within 2.5 of current move target then wont move


            local tDistanceAdjustXZ = {{0,0},{-5,-5},{5,5},{-5,5},{5,-5},{0,-5},{0,5},{-5,0},{5,0},{-10,-10},{10,10},{-10,10},{10,-10},{0,-10},{0,10},{-10,0},{10,0},{-15,-15},{15,15},{-15,15},{15,-15},{0,-15},{0,15},{-15,0},{15,0}}
            --Find the first placement that we dont have assigned
            local tiValidPlacements = {}
            local iTotalUnits = table.getn(tUnits)
            for iUnit, oUnit in tUnits do
                if oUnit[refiGunshipPlacement] then tiValidPlacements[oUnit[refiGunshipPlacement]] = true end
            end
            local iFirstMissingPlacement
            for iCurPlacement = 1, iTotalUnits do
                if not(tiValidPlacements[iCurPlacement]) then
                    iFirstMissingPlacement = iCurPlacement
                    break
                end
            end

            local tAdjustedMovePosition
            local iCurPlacement
            local iPlacementSize = table.getn(tDistanceAdjustXZ)
            if iFirstMissingPlacement then
                local toUnitsToPlace = {}
                for iUnit, oUnit in tUnits do
                    if (oUnit[refiGunshipPlacement] or 10000) >= iFirstMissingPlacement then
                        table.insert(toUnitsToPlace, oUnit)
                    end
                end

                local iClosestDist
                local iCurDist
                local iClosestUnitRef

                for iBasePlacement = iFirstMissingPlacement, iTotalUnits do
                    --Adjust placement value to reflect we have only defined a limited number of options
                    if M27Utilities.IsTableEmpty(toUnitsToPlace) then break end --redundancy
                    iCurPlacement = iBasePlacement
                    while iCurPlacement  > iPlacementSize do
                        iCurPlacement = iCurPlacement - iPlacementSize
                    end
                    --Identify which gunship is closest to each placement point
                    tAdjustedMovePosition = {tTarget[1] + tDistanceAdjustXZ[iCurPlacement][1], tTarget[2], tTarget[3] + tDistanceAdjustXZ[iCurPlacement][2]}
                    iClosestDist = 10000
                    iClosestUnitRef = nil
                    for iUnit, oUnit in toUnitsToPlace do
                        iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tAdjustedMovePosition)
                        if iCurDist < iClosestDist then
                            iClosestDist = iCurDist
                            iClosestUnitRef = iUnit
                        end
                    end
                    --Assign this position to this gunship
                    toUnitsToPlace[iClosestUnitRef][refiGunshipPlacement] = iBasePlacement
                    table.remove(toUnitsToPlace, iClosestUnitRef)
                end
            end

            --Issue move orders
            local toUnitsByBasePlacementRef = {}
            for iUnit, oUnit in tUnits do
                toUnitsByBasePlacementRef[oUnit[refiGunshipPlacement]] = oUnit
            end

            function MoveIndividualGunship(oClosestUnit, tUnitDestination)
                if not(oClosestUnit[M27PlatoonUtilities.refiLastOrderType] == M27PlatoonUtilities.refiOrderIssueMove) or M27Utilities.GetDistanceBetweenPositions(oClosestUnit[M27UnitInfo.reftLastOrderTarget], tTarget) > iGunshipMoveTolerance then
                    M27Utilities.IssueTrackedClearCommands({oClosestUnit})
                    IssueMove({oClosestUnit}, tUnitDestination)
                    oClosestUnit[M27PlatoonUtilities.refiLastOrderType] = M27PlatoonUtilities.refiOrderIssueMove
                    oClosestUnit[M27UnitInfo.reftLastOrderTarget] = {tUnitDestination[1], tUnitDestination[2], tUnitDestination[3]}
                end
            end


            for iBasePlacement = 1, iTotalUnits do
                iCurPlacement = iBasePlacement
                while iCurPlacement  > iPlacementSize do
                    iCurPlacement = iCurPlacement - iPlacementSize
                end

                tAdjustedMovePosition = {tTarget[1] + tDistanceAdjustXZ[iCurPlacement][1], tTarget[2], tTarget[3] + tDistanceAdjustXZ[iCurPlacement][2]}
                tAdjustedMovePosition[2] = GetSurfaceHeight(tAdjustedMovePosition[1], tAdjustedMovePosition[3])
                if not(toUnitsByBasePlacementRef[iBasePlacement]) then
                    M27Utilities.ErrorHandler('Missing gunship for iBasePlacement='..iBasePlacement)
                else
                    MoveIndividualGunship(toUnitsByBasePlacementRef[iBasePlacement], tAdjustedMovePosition)
                end
            end




            --[[ OLD APPROACH below - would calculate angle and distance each time
            local iAngleToBase = M27Utilities.GetAngleFromAToB(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            local iAngleFurtherAdjust = 0
            local tiDistanceAndAngleAdjustments = {[0] = {0},
                                                   [10] = {45, 225, 135, 315 },
                                                   [5] = {0, 180, 90, 270},
                                                   [15] =  {22, 202, 112, 292, 67, 247, 157, 337},
                                                   [16] = {0, 180, 90, 270, 45, 225, 135, 315}}
            local tUnitDestination
            local tRemainingUnits = {}
            for iUnit, oUnit in tUnits do
                table.insert(tRemainingUnits, oUnit)
            end
            local iClosestUnitDist
            local oClosestUnit
            local iClosestUnitRef
            local iCurDist

            function MoveIndividualGunship(oClosestUnit, tUnitDestination)
                if not(oClosestUnit[M27PlatoonUtilities.refiLastOrderType] == M27PlatoonUtilities.refiOrderIssueMove) or M27Utilities.GetDistanceBetweenPositions(oClosestUnit[M27UnitInfo.reftLastOrderTarget], tTarget) > iGunshipMoveTolerance then
                    M27Utilities.IssueTrackedClearCommands({oClosestUnit})
                    IssueMove({oClosestUnit}, tUnitDestination)
                    oClosestUnit[M27PlatoonUtilities.refiLastOrderType] = M27PlatoonUtilities.refiOrderIssueMove
                    oClosestUnit[M27UnitInfo.reftLastOrderTarget] = {tUnitDestination[1], tUnitDestination[2], tUnitDestination[3]}
                end
            end

            for iDistanceAdjust, tiAngles in tiDistanceAndAngleAdjustments do
                for _, iAngleAdjust in tiAngles do
                    --Find the closest gunship to the desired location
                    tUnitDestination = M27Utilities.MoveInDirection(tTarget, iAngleToBase + iAngleAdjust, iDistanceAdjust, true)
                    iClosestUnitDist = 10000
                    for iUnit, oUnit in tRemainingUnits do
                        iCurDist = M27Utilities.GetDistanceBetweenPositions(tUnitDestination, oUnit:GetPosition())
                        if iCurDist < iClosestUnitDist then
                            iClosestUnitDist = iCurDist
                            oClosestUnit = oUnit
                            iClosestUnitRef = iUnit
                        end
                    end
                    table.remove(tRemainingUnits, iClosestUnitRef)

                    --Tell unit to move here
                    MoveIndividualGunship(oClosestUnit, tUnitDestination)
                end
            end
            if M27Utilities.IsTableEmpty(tRemainingUnits) == false then
                if table.getn(tUnits) <= 25 then M27Utiliites.ErrorHandler('Have '..table.getn(tUnits)..' gunships but didnt find destinations for all of them') end
                for iUnit, oUnit in tRemainingUnits do
                    MoveIndividualGunship(oClosestUnit, tUnitDestination)
                end
            end--]]
        end

        --Get the gunship closest to the front:
        local oFrontGunship
        local iSmallestBasePlacement = 10000
        for iUnit, oUnit in aiBrain[reftAvailableGunships] do
            if bDebugMessages == true then LOG(sFunctionRef..': Checking for front gunship, oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Gunship placement='..(oUnit[refiGunshipPlacement] or 10000)) end
            if (oUnit[refiGunshipPlacement] or 10000) < iSmallestBasePlacement then
                iSmallestBasePlacement = oUnit[refiGunshipPlacement]
                oFrontGunship = oUnit
            end
        end
        --Backup if no gunship assigned a base position:
        if not(oFrontGunship) then
            local iCurGunshipDist
            local iClosestGunshipDist = 10000
            local tEnemyBase = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)

            for iUnit, oUnit in aiBrain[reftAvailableGunships] do
                iCurGunshipDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tEnemyBase)
                if bDebugMessages == true then LOG(sFunctionRef..': Dont have any front gunship, so will pick the gunship closest to the nearest enemy base, oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iCurGunshipDist='..iCurGunshipDist) end
                if iCurGunshipDist < iClosestGunshipDist then
                    iClosestGunshipDist = iCurGunshipDist
                    oFrontGunship = oUnit
                end
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Front gunship='..oFrontGunship.UnitId..M27UnitInfo.GetUnitLifetimeCount(oFrontGunship)) end
        aiBrain[refoFrontGunship] = oFrontGunship

        --Does the enemy have AirAA near our front gunship or lots of T3 AA? If so then retreat unless are in ACU kill/protect mode
        local bRetreatFromAA = false
        if not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill) and not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyProtectACU) then
            local iOurAARange = 0
            local tOurAAGunships = EntityCategoryFilterDown(categories.ANTIAIR, aiBrain[reftAvailableGunships])
            if M27Utilities.IsTableEmpty(tOurAAGunships) == false then
                local iCurAARange
                for iUnit, oUnit in tOurAAGunships do
                    iCurAARange = M27UnitInfo.GetUnitAARange(oUnit)
                    if iCurAARange > iOurAARange then
                        iOurAARange = iCurAARange
                    end
                end
            end
            local iAirAASearchRange

            if iOurAARange == 0 then
                iAirAASearchRange = 70
                if M27Utilities.GetDistanceBetweenPositions(oFrontGunship:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) >= 200 then
                    iAirAASearchRange = 100
                end
            else
                iAirAASearchRange = iOurAARange
            end
            if iAvailableGunships >= 5 then iAirAASearchRange = iAirAASearchRange + iAvailableGunships * 0.5 end


            local tNearbyAirAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAirAA, oFrontGunship:GetPosition(), iAirAASearchRange, 'Enemy')
            if bDebugMessages == true then LOG(sFunctionRef..': checking for nearby enemy AirAA, iAirAASearchRange='..iAirAASearchRange..'; Is table empty of enemy AirAA='..tostring(M27Utilities.IsTableEmpty(tNearbyAirAA))) end
            if M27Utilities.IsTableEmpty(tNearbyAirAA) == false then
                bRetreatFromAA = true
            else
                local tNearbyT3AA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3 + M27UnitInfo.refCategoryCruiser, oFrontGunship:GetPosition(), math.max(70, iAirAASearchRange), 'Enemy')
                if M27Utilities.IsTableEmpty(tNearbyT3AA) == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have '..table.getn(tNearbyT3AA)..' nearby T3 ground AA') end
                    if table.getn(tNearbyT3AA) >= 3 then
                        bRetreatFromAA = true
                    else
                        --If we were to move to the closest T3 AA, would there then be 3+ T3 AA around it? If so then also want to retreat (to avoid us moving towards T3 AA in range, then retreating without firing)

                        local oNearestT3AA = M27Utilities.GetNearestUnit(tNearbyT3AA, oFrontGunship:GetPosition())
                        local tT3AANearNearestAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3 + M27UnitInfo.refCategoryCruiser, oFrontGunship:GetPosition(), 70, 'Enemy')
                        if bDebugMessages == true then LOG(sFunctionRef..': Nearest T3AA='..oNearestT3AA.UnitId..M27UnitInfo.GetUnitLifetimeCount(oNearestT3AA)..'; Number of T3 AA near this='..table.getn(tT3AANearNearestAA)) end
                        if M27Utilities.IsTableEmpty(tT3AANearNearestAA) == false and table.getn(tT3AANearNearestAA) >= 3 then
                            bRetreatFromAA = true
                        end
                    end
                end
            end
        end
        if not(bRetreatFromAA) then


            --Prioritise closest enemies threatening mexes
            local iRangeCap = 100000 --cap even for higih priority units if we are far behind on air
            local bIgnoreRangeCap = true


            --Special targeting depending on strategy:
            local oTargetUnitsAroundThisOne
            if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then iGunshipOperationalRange = 1000
            elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and EntityCategoryContains(categories.COMMAND, aiBrain[M27Overseer.refoACUKillTarget].UnitId) then
                oTargetUnitsAroundThisOne = aiBrain[M27Overseer.refoACUKillTarget]
            elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyProtectACU then
                oTargetUnitsAroundThisOne = M27Utilities.GetACU(aiBrain)
                if not(EntityCategoryContains(categories.COMMAND, oTargetUnitsAroundThisOne.UnitId)) then
                    oTargetUnitsAroundThisOne = nil
                end
            else
                if aiBrain[refbFarBehindOnAir] then
                    iRangeCap = math.max(aiBrain[refiOurFurthestAAStructureFromBase] + 10, 80)
                    bIgnoreRangeCap = true
                    iGunshipOperationalRange = math.min(iRangeCap, iGunshipOperationalRange)
                end
            end
            if oTargetUnitsAroundThisOne then
                if not(oTargetUnitsAroundThisOne:IsUnitState('Attached')) and not(M27UnitInfo.IsUnitUnderwater(oTargetUnitsAroundThisOne)) then
                    oClosestEnemy = oTargetUnitsAroundThisOne --Simplification so gunships travel to this unit even if it is our ACU
                end
            end



            if not(oClosestEnemy) then
                if aiBrain[M27Overseer.refbGroundCombatEnemyNearBuilding] then
                    for iThreatGroupCount, sThreatGroupRef in aiBrain[M27Overseer.reftEnemyGroupsThreateningBuildings] do
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering threat group '..iThreatGroupCount..'-'..sThreatGroupRef..'; Is table of details for this threat group empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyThreatGroup][sThreatGroupRef]))) end
                        if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyThreatGroup][sThreatGroupRef]) == false then
                            for iUnit, oUnit in aiBrain[M27Overseer.reftEnemyThreatGroup][sThreatGroupRef][M27Overseer.refoEnemyGroupUnits] do
                                if M27UnitInfo.IsUnitValid(oUnit) then
                                    if bIgnoreRangeCap or M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= iRangeCap then
                                        ConsiderTargetingUnit(oUnit)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            --if iClosestEnemyDist > iGunshipOperationalRange then oClosestEnemy = nil end --Dont want this for enemies threatening a mex
            if not(oClosestEnemy) then
                --Get nearest enemy unit within defensive range, unless alreadhave enemies near the front unit
                --Still consider attacking even if have a range cap to avoid situations where we approach enemy then fall back after taking some damage
                if bDebugMessages == true then LOG(sFunctionRef..': Dont have a target yet, considering nearest enemy unit within defensive range unlesss already have enemies near front unit. iSmallestBasePlacement='..iSmallestBasePlacement) end

                local tEnemiesInGunshipRange
                --if iSmallestBasePlacement <= 3 then
                --Check for units near our gunship (i.e. that it is already in range or almost within range of)
                local iSearchRange
                if bIgnoreRangeCap then iSearchRange = math.max(20, M27UnitInfo.GetNavalDirectAndSubRange(oFrontGunship) + math.min(30, 5 + iAvailableGunships)) --Gets the direct fire range, used for convenience
                else iSearchRange = math.max(15, M27UnitInfo.GetNavalDirectAndSubRange(oFrontGunship) + math.min(15, 5 + iAvailableGunships))
                end

                tEnemiesInGunshipRange = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand + M27UnitInfo.refCategoryStructure + M27UnitInfo.refCategoryNavalSurface, oFrontGunship:GetPosition(), iSearchRange, 'Enemy')
                if M27Utilities.IsTableEmpty(tEnemiesInGunshipRange) == false then
                    for iUnit, oUnit in tEnemiesInGunshipRange do
                        ConsiderTargetingUnit(oUnit)
                    end
                end
                --end
                if not(oClosestEnemy) then
                    tEnemiesInGunshipRange = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMobileLand + M27UnitInfo.refCategoryStructure + M27UnitInfo.refCategoryNavalSurface, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iGunshipOperationalRange + iMaxDirectLineExtraDist, 'Enemy')
                    if bDebugMessages == true then LOG(sFunctionRef..': Still no enemy, is tEnemiesInGunshipRange empty='..tostring(M27Utilities.IsTableEmpty(tEnemiesInGunshipRange))..'; iGunshipOperationalRange + iMaxDirectLineExtraDist='..iGunshipOperationalRange + iMaxDirectLineExtraDist) end
                    if M27Utilities.IsTableEmpty(tEnemiesInGunshipRange) == false then
                        for iUnit, oUnit in tEnemiesInGunshipRange do
                            --Is our mod distance within range?
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering targeting enemy unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Mod dist to start='..M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition())..'; iGunshipOperationalRange='..iGunshipOperationalRange) end
                            if M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition()) <= iGunshipOperationalRange then
                                ConsiderTargetingUnit(oUnit)
                            end
                        end
                    end
                    if iClosestEnemyDist > iGunshipOperationalRange + iMaxDirectLineExtraDist then oClosestEnemy = nil end --(Redundancy)
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Finished considering all potential targets, do we have a valid target='..tostring(M27UnitInfo.IsUnitValid(oClosestEnemy))) end
            if oClosestEnemy then
                --Factor in enemy AA around the target and dont engage if it's too much to try and attack attritionally, unless it's in critical defence range
                if bDebugMessages == true then LOG(sFunctionRef..': Have a potential enemy near our gunship to target, will check for AA around it. iClosestEnemyDist='..iClosestEnemyDist..'; aiBrain[refiBomberDefenceCriticalThreatDistance]='..aiBrain[refiBomberDefenceCriticalThreatDistance]) end
                if iClosestEnemyDist > aiBrain[refiBomberDefenceCriticalThreatDistance] then --Dont want to check for AA if enemy at our base
                    local tPotentialGroundAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, oFrontGunship:GetPosition(), M27Utilities.GetDistanceBetweenPositions(oFrontGunship:GetPosition(), oClosestEnemy:GetPosition()) + 75, 'Enemy')
                    if M27Utilities.IsTableEmpty(tPotentialGroundAA) == false then
                        --Filter to just those AA that would be within 20 of our front gunship
                        local tAACoverage = GetTargetAACoverage(oClosestEnemy, tPotentialGroundAA, oFrontGunship:GetPosition(), 20)
                        if M27Utilities.IsTableEmpty(tAACoverage) == false then
                            --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride, bIncludeAirTorpedo, bBlueprintThreat)
                            local iAAThreat = M27Logic.GetAirThreatLevel(aiBrain, tAACoverage, false, false, true, false, false, nil, nil, nil, nil, false)
                            if bDebugMessages == true then LOG(sFunctionRef..': COnsidering if AA threat such that we want to ignore the closest enemy so that we retreat to air rally, iAAThreat='..iAAThreat) end
                            if iAAThreat >= 50 then
                                --Low levels of AA threat - apply different ratio to higher levels where SAM is more likely

                                if iAAThreat >= 1900 and (iAAThreat >= 3300 or table.getn(aiBrain[reftAvailableGunships]) < 10) then --Equivalent to 1 SAM plus some other AA
                                    oClosestEnemy = nil
                                else
                                    local tNearbyGunships = {}
                                    for iUnit, oUnit in aiBrain[reftAvailableGunships] do
                                        if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oFrontGunship:GetPosition()) <= 40 then
                                            table.insert(tNearbyGunships, oUnit)
                                        end
                                    end
                                    local iOurThreat = M27Logic.GetAirThreatLevel(aiBrain, tNearbyGunships, false, false, false, true, false)
                                    if bDebugMessages == true then LOG(sFunctionRef..': iOurThreat='..iOurThreat) end
                                    if (iAAThreat >= 600 and iOurThreat < iAAThreat * 3) or iOurThreat < iAAThreat * 2.25 then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy has too much AA so wont attack') end
                                        oClosestEnemy = nil
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if oClosestEnemy and not(bRetreatFromAA) then
            SendGunshipMoveOrder(aiBrain[reftAvailableGunships], oClosestEnemy:GetPosition())
        else
            --Return to air rally point
            local tDestination = GetAirRallyPoint(aiBrain)
            SendGunshipMoveOrder(aiBrain[reftAvailableGunships], tDestination)
        end
    else
        aiBrain[refoFrontGunship] = nil
    end
end


function GetAirAAThreatAlongPath(aiBrain, tStartPoint, tEndPoint, iAdjacentSegmentSize)
    --Returns the total threat along a path; iAdjacentSegmentSize is the number of air segments adjacent to the path to include

    local iStartX, iStartZ = GetAirSegmentFromPosition(tStartPoint)
    local iEndX, iEndZ = GetAirSegmentFromPosition(tEndPoint)

    local iMinX = math.max(aiBrain[refiMinSegmentX], math.min(iStartX, iEndX) - iAdjacentSegmentSize)
    local iMaxX = math.min(aiBrain[refiMaxSegmentX], math.max(iStartX, iEndX) + iAdjacentSegmentSize)
    local iMinZ = math.max(aiBrain[refiMinSegmentZ], math.min(iStartZ, iEndZ) - iAdjacentSegmentSize)
    local iMaxZ = math.min(aiBrain[refiMaxSegmentZ], math.max(iStartZ, iEndZ) + iAdjacentSegmentSize)

    local iTotalThreat = 0
    local iDistFromAToB = M27Utilities.GetDistanceBetweenPositions(tStartPoint, tEndPoint)
    local iAngleFromAToB = M27Utilities.GetAngleFromAToB(tStartPoint, tEndPoint)
    local iCircleRadius = (iAdjacentSegmentSize + 1) * iAirSegmentSize

    local iDistFromAToC
    local iDistFromBToC
    local iAngleFromAToC

    for iCurSegmentX = iMinX, iMaxX, 1 do
        for iCurSegmentZ = iMinZ, iMaxZ, 1 do
            iDistFromAToC = M27Utilities.GetDistanceBetweenPositions(tStartPoint, aiBrain[reftAirSegmentTracker][iCurSegmentX][iCurSegmentZ][reftMidpointPosition])
            iDistFromBToC = M27Utilities.GetDistanceBetweenPositions(tEndPoint, aiBrain[reftAirSegmentTracker][iCurSegmentX][iCurSegmentZ][reftMidpointPosition])
            iAngleFromAToC = M27Utilities.GetAngleFromAToB(tStartPoint, aiBrain[reftAirSegmentTracker][iCurSegmentX][iCurSegmentZ][reftMidpointPosition])

            if M27Utilities.IsLineFromAToBInRangeOfCircleAtC(iDistFromAToB, iDistFromAToC, iDistFromBToC, iAngleFromAToB, iAngleFromAToC, iCircleRadius) then
                if M27Team.tTeamData[aiBrain.M27Team][M27Team.reftAirSegmentTracker][iCurSegmentX] and M27Team.tTeamData[aiBrain.M27Team][M27Team.reftAirSegmentTracker][iCurSegmentX][iCurSegmentZ] then
                    iTotalThreat = iTotalThreat + (M27Team.tTeamData[aiBrain.M27Team][M27Team.reftAirSegmentTracker][iCurSegmentX][iCurSegmentZ][M27Team.subrefEnemyAACurThreat] or 0)
                end
            end
        end
    end
    return iTotalThreat
end

function GetAirAAThreatAroundPosition(aiBrain, tPosition, iAdjacentSegmentSize)
    --Returns the airaa threat around the position and iAdjacentSegmentSize air segments
    local iStartX, iStartZ = GetAirSegmentFromPosition(tPosition)
    local iMinX = math.max(aiBrain[refiMinSegmentX], iStartX - iAdjacentSegmentSize)
    local iMaxX = math.min(aiBrain[refiMaxSegmentX], iStartX + iAdjacentSegmentSize)
    local iMinZ = math.max(aiBrain[refiMinSegmentZ], iStartZ - iAdjacentSegmentSize)
    local iMaxZ = math.min(aiBrain[refiMaxSegmentZ], iStartZ + iAdjacentSegmentSize)
    local iTotalThreat = 0
    for iCurSegmentX = iMinX, iMaxX, 1 do
        for iCurSegmentZ = iMinZ, iMaxZ, 1 do
            iTotalThreat = iTotalThreat + (M27Team.tTeamData[aiBrain.M27Team][M27Team.reftAirSegmentTracker][iCurSegmentX][iCurSegmentZ][M27Team.subrefEnemyAACurThreat] or 0)
        end
    end
    return iTotalThreat

end
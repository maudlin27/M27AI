--Overseer to handle air threat detection, air scout usage, interceptor logic, and bomber logic
local PROFILER = import('/mods/M27AI/lua/DilliProfiler.lua').GetProfiler()

local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')

--General air scouting values
local iAirSegmentSize--set in initialisation
local iSegmentVisualThresholdBoxSize1 --set in initialisation, e.g. v11 this is AirSegmentSize*2
local iSegmentVisualThresholdBoxSize2 --set in initialisation, eg v11 this is aiisegmentsixe * 3

local iMapMaxSegmentX, iMapMaxSegmentZ --Last x and z segments in map size


local refiMaxScoutRadius = 'M27AirMaxScoutRadius' --Range from base at which will look for air scouts to be used
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
local refiIntervalEnemyBase = 'M27AirIntervalEnemyBase'

--Main trackers: Scout
local reftAirSegmentTracker = 'M27AirSegmentTracker' --[x][z]{a,b,c,d etc.} - x = segment x, z = segment z, a, b, c etc. = subtable refs - Used to track all things relating to air scouting for a particular segment
--Subtable values (include in SetupAirSegments to make sure these can be referenced)
local refiLastScouted = 'M27AirLastScouted'
local refiAirScoutsAssigned = 'M27AirScoutsAssigned'
local refiNormalScoutingIntervalWanted = 'M27AirScoutIntervalWanted' --What to default to if e.g. temporairly increased
local refiCurrentScoutingInterval = 'M27AirScoutCurrentIntervalWanted' --e.g. can temporarily override this if a unit dies and want to make it higher priority
local reftMidpointPosition = 'M27AirSegmentMidpointPosition'
local refiDeadScoutsSinceLastReveal = 'M27AirDeadScoutsSinceLastReveal'
local refiLastTimeScoutingIntervalChanged = 'M27AirLastTimeScoutingIntervalChanged'

local reftScoutingTargetShortlist = 'M27ScoutingTargetShortlist' --[y]: [y] is the count (e.g. location 1, 2, 3), and then this gives {a,b,c} where a, b, c are subrefs, i.e. refiTimeSinceWantedToScout
--subtable values:
local refiTimeSinceWantedToScout = 'M27AirTimeSinceWantedToScout'
local refiSegmentX = 'M27AirSegmentX'
local refiSegmentZ = 'M27AirSegmentZ'

--Main trackers: Bomber
reftBomberTargetShortlist = 'M27AirBomberTargetShortlist' --[x] is the count (1, 2, 3 etc.)
local refbShortlistContainsLowPriorityTargets = 'M27AirShortlistContainsLowPriorityTargets' --true if shortlist only contains low priority targets that only want added once to a unit
--Unit local variables
local refiCurBombersAssigned = 'M27AirCurBombersAssigned' --Currently assigned to a particular unit, so know how many bombers have already been assigned
local refiLifetimeBombersAssigned = 'M27AirLifetimeBombersAssigned' --All bombers ever sent against the unit in question
refiBomberTargetLastAssessed = 'M27AirBomberTargetLastAssessed'


--localised values
reftMovementPath = 'M27AirMovementPath'
local refiCurMovementPath = 'M27AirCurMovementPath'
local reftTargetList = 'M27AirTargetList' --For bomber to track targets as objects
local refiCurTargetNumber = 'M27AirCurTargetNumber' --e.g. for a bomber which is assigned objects not locations to target
local refoAirAATarget = 'M27AirAirAATarget' --Interceptor target
local reftTargetedByList = 'M27AirTargetedByList' --for interceptor target so can track mass value assigned to it, each entry is an air AA object assigned to target the unit
local refbPartOfLargeAttack = 'M27AirPartOfLargeAttack' --True if part of large attack platoon (so dont want to treat it as available)
local refiStrikeDamageAssigned = 'M27AirStrikeDamageAssigned'

--Build order related
refiExtraAirScoutsWanted = 'M27AirExtraAirScoutsWanted'
refiBombersWanted = 'M27AirBombersWanted'
refiTorpBombersWanted = 'M27TorpBombersWanted'
refiAirStagingWanted = 'M27AirStagingWanted'
local iMinScoutsForMap
local iMaxScoutsForMap
local iLongScoutDelayThreshold = 60 --Only locations where we're overdue by this much will be taken into account when deciding how many scouts we want
refiAirAANeeded = 'M27AirNeedMoreAirAA'
refiAirAAWanted = 'M27AirWantedMoreAirAA'
refbBombersAreEffective = 'M27AirBombersAreEffective' --[x] = tech level, returns true/false

refiLargeBomberAttackThreshold = 'M27AirLargeBomberAttackThreshold' --How many bombers are needed before launching a large attack

--Bomber effectiveness (used to decide whether to keep building bombers)
local reftBomberEffectiveness = 'M27AirBomberEffectiveness' --[x][y]: x = unit tech level, y = nth entry; returns subtable {MassCost}{MassKilled}
local refiBomberMassCost = 'M27AirBomberMassCost' --Subtable ref
local refiBomberMassKilled = 'M27AirBomberMassKilled' --Subtable ref
local iBombersToTrackEffectiveness = 3 --Will track the last n bombers killed

--Air threat related
refiHighestEnemyAirThreat = 'M27HighestEnemyAirThreat' --highest ever value the enemy's air threat has reached in a single map snapshot
refiOurMassInMAA = 'M27OurMassInMAA'
refiOurMAAUnitCount = 'M27OurMAAUnitCount'
refiOurMassInAirAA = 'M27OurMassInAirAA'



--Available air units
local reftAvailableScouts = 'M27AirScoutsWithFuel'
reftAvailableBombers = 'M27AirAvailableBombers'
reftAvailableTorpBombers = 'M27AirAvailableTorpBombers' --Determined by threat overseer
local reftAvailableAirAA = 'M27AirAvailableAirAA'
--local reftLowFuelAir = 'M27AirScoutsWithLowFuel'
local reftLowFuelAir = 'M27AirLowFuelAir'

refbOnAssignment = 'M27AirOnAssignment'
local refbWillBeRefueling = 'M27AirWillBeRefueling'

--Other
local refCategoryAirScout = M27UnitInfo.refCategoryAirScout
local refCategoryBomber = M27UnitInfo.refCategoryBomber
local refCategoryTorpBomber = M27UnitInfo.refCategoryTorpBomber
local refCategoryAirAA = M27UnitInfo.refCategoryAirAA
local refCategoryAirNonScout = M27UnitInfo.refCategoryAirNonScout


function GetAirSegmentFromPosition(tPosition)
    --returns x and z values of the segment that tPosition is in
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetAirSegmentFromPosition'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iSegmentX = math.ceil((tPosition[1] - rPlayableArea[1]) / iAirSegmentSize)
    local iSegmentZ = math.ceil((tPosition[3] - rPlayableArea[2]) / iAirSegmentSize)
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, iSegmentX,Z='..iSegmentX..'-'..iSegmentZ) end
    return iSegmentX, iSegmentZ
end

function GetAirPositionFromSegment(iSegmentX, iSegmentZ)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetAirPositionFromSegment'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end

    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iPosX = (iSegmentX-0.5) * iAirSegmentSize + rPlayableArea[1]
    local iPosZ = (iSegmentZ-0.5) * iAirSegmentSize + rPlayableArea[2]
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
    return {iPosX, GetTerrainHeight(iPosX, iPosZ), iPosZ}
end

function RecordAirScoutDyingInNearbySegments(aiBrain, iBaseSegmentX, iBaseSegmentZ)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OnScoutDeath'
    local iStartX, iEndX, iStartZ, iEndZ
    iStartX = math.max(iBaseSegmentX - 1, 1)
    iStartZ = math.max(iBaseSegmentZ - 1, 1)
    iEndX = math.min(iBaseSegmentX + 1, iMapMaxSegmentX)
    iEndZ = math.min(iBaseSegmentZ + 1, iMapMaxSegmentZ)
    for iX = iStartX, iEndX, 1 do
        for iZ = iStartZ, iEndZ, 1 do
            aiBrain[reftAirSegmentTracker][iX][iZ][refiDeadScoutsSinceLastReveal] = aiBrain[reftAirSegmentTracker][iX][iZ][refiDeadScoutsSinceLastReveal] + 1
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Finshed recording that scout died around segments '..iBaseSegmentX..'-'..iBaseSegmentZ) end
end

function ClearPreviousMovementEntries(aiBrain, oAirUnit)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ClearPreviousMovementEntries'
    local iMaxMovementPaths = 0
    if oAirUnit[reftMovementPath] and oAirUnit[refiCurMovementPath] and oAirUnit[refiCurMovementPath] > 1 then iMaxMovementPaths = table.getn(oAirUnit[reftMovementPath]) end
    if iMaxMovementPaths > 1 then
        local iCurAirSegmentX, iCurAirSegmentZ
        if bDebugMessages == true then LOG(sFunctionRef..': about to cycle through earlier movement paths and clear them; oAirUnit[refiCurMovementPath]='..oAirUnit[refiCurMovementPath]..'; iMaxMovementPaths='..iMaxMovementPaths) end
        for iPath = 1, (oAirUnit[refiCurMovementPath] - 1), 1 do
            iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(oAirUnit[reftMovementPath][1])
            aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] - 1
            if bDebugMessages == true then LOG(sFunctionRef..': Just reduced assigned scouts for segment X-Z='..iCurAirSegmentX..'-'..iCurAirSegmentZ) end
            table.remove(oAirUnit[reftMovementPath], 1)
        end
        oAirUnit[refiCurMovementPath] = 1
    end
    if M27Config.M27ShowUnitNames == true and oAirUnit.GetUnitId then
        local sPath = 'nil'
        if oAirUnit[reftMovementPath] and M27Utilities.IsTableEmpty(oAirUnit[reftMovementPath][1]) == false then sPath = oAirUnit[reftMovementPath][1][1]..oAirUnit[reftMovementPath][1][3] end
        M27PlatoonUtilities.UpdateUnitNames({oAirUnit}, oAirUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oAirUnit)..':MoveTo:'..sPath)
    end
end

function ClearTrackersOnUnitsTargets(oAirUnit, iAirUnitMassCost)
    if M27Utilities.IsTableEmpty(oAirUnit[reftTargetList]) == false then
        --local iTotalTargets = table.getn(oAirUnit[reftTargetList])
        --local oCurTarget
        local iStrikeDamage = M27UnitInfo.GetUnitStrikeDamage(oAirUnit)
        local iMassCost = oAirUnit:GetBlueprint().Economy.BuildCostMass --Not perfect because if a bomber is assigned a target when at 50% health the target unit's assigned threat will be reduced when the bomber dies by more than it should
        local iArmyIndex = oAirUnit:GetAIBrain():GetArmyIndex()
        for iUnit, oUnit in oAirUnit[reftTargetList] do
            if not(oUnit.Dead) then
                if oUnit[refiCurBombersAssigned] == nil then oUnit[refiCurBombersAssigned] = 0
                else oUnit[refiCurBombersAssigned] = oUnit[refiCurBombersAssigned] - 1 end
                if oUnit[refiStrikeDamageAssigned] == nil then oUnit[refiStrikeDamageAssigned] = 0
                else oUnit[refiStrikeDamageAssigned] = math.max(0, oUnit[refiStrikeDamageAssigned] - iStrikeDamage) end
                if oUnit[iArmyIndex][M27Overseer.refiAssignedThreat] then oUnit[iArmyIndex][M27Overseer.refiAssignedThreat] = math.max(0, oUnit[iArmyIndex][M27Overseer.refiAssignedThreat] - iMassCost) end
            end
        end
    end
    if M27Config.M27ShowUnitNames == true and oAirUnit.GetUnitId then M27PlatoonUtilities.UpdateUnitNames({oAirUnit}, oAirUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oAirUnit)..':TargetsCleared') end
end

function ClearAirUnitAssignmentTrackers(aiBrain, oAirUnit)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ClearAirUnitAssignmentTrackers'
    local iMaxMovementPaths = 0
    if oAirUnit[reftMovementPath] then iMaxMovementPaths = table.getn(oAirUnit[reftMovementPath]) end
    if iMaxMovementPaths > 0 then
        local iCurAirSegmentX, iCurAirSegmentZ
        for iCurTarget = oAirUnit[refiCurMovementPath], iMaxMovementPaths, 1 do
            iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(oAirUnit[reftMovementPath][iCurTarget])
            aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] - 1
            if bDebugMessages == true then LOG(sFunctionRef..': Just reduced assigned scouts for segment X-Z='..iCurAirSegmentX..'-'..iCurAirSegmentZ) end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Clearing movement path and making unit available for future use') end
    oAirUnit[refbOnAssignment] = false
    oAirUnit[reftMovementPath] = {}
    oAirUnit[reftTargetList] = {}
    oAirUnit[refiCurTargetNumber] = 0


    ClearTrackersOnUnitsTargets(oAirUnit)

end

function MakeSegmentsAroundPositionHighPriority(aiBrain, tPosition, iSegmentSize)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MakeSegmentsAroundPositionHighPriority'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local iBaseAirSegmentX, iBaseAirSegmentZ = GetAirSegmentFromPosition(tPosition)
    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iMaxSegmentSizeX, iMaxSegmentSizeZ = GetAirSegmentFromPosition({ rPlayableArea[3], 0, rPlayableArea[4] })
    if bDebugMessages == true then LOG(sFunctionRef..': iMaxSegmentSizeX='..iMaxSegmentSizeX..'; iMaxSegmentSizeZ='..iMaxSegmentSizeZ) end

    for iAirSegmentX = math.max(1, iBaseAirSegmentX - iSegmentSize), math.min(iMaxSegmentSizeX, iBaseAirSegmentX + iSegmentSize) do
        for iAirSegmentZ = math.max(1, iBaseAirSegmentZ - iSegmentSize), math.min(iMaxSegmentSizeZ, iBaseAirSegmentZ + iSegmentSize) do
            if bDebugMessages == true then
                LOG(sFunctionRef..': iAirSegmentX='..iAirSegmentX..'; iAirSegmentZ='..iAirSegmentZ)
                LOG('aiBrain[refiIntervalHighestPriority]='..aiBrain[refiIntervalHighestPriority])
            end

            aiBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiCurrentScoutingInterval] = aiBrain[refiIntervalHighestPriority]
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
end


function CheckForUnseenKiller(aiBrain, oKilled, oKiller)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CheckForUnseenKiller'

    --Air scout specific - if air scout died then also update the area around the killer to flag an air scout as being killed
    if EntityCategoryContains(refCategoryAirScout, oKilled:GetUnitId()) == true then
        local iAirSegmentX, iAirSegmentZ = GetAirSegmentFromPosition(oKilled:GetPosition())
        RecordAirScoutDyingInNearbySegments(aiBrain, iAirSegmentX, iAirSegmentZ)
    else
        --If unit dies, check if have intel on a nearby enemy, and if not then make it a high priority area for scouting
        --CanSeeUnit(aiBrain, oUnit, bTrueIfOnlySeeBlip)
        if oKiller.GetAIBrain then
            if not(M27Utilities.CanSeeUnit(aiBrain, oKiller, true)) then
                MakeSegmentsAroundPositionHighPriority(aiBrain, oKilled:GetPosition(), 3)
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Unit died from unseen killer, so will flag to scout it sooner')
                    M27Utilities.DrawLocation(GetAirPositionFromSegment(iAirSegmentX, iAirSegmentZ))
                end
                --If unit is part of a platoon, tell that platoon to retreat if it cant see any nearby enemies
                local oPlatoon = oKilled.PlatoonHandle
                if oPlatoon then
                    if oPlatoon[M27PlatoonUtilities.refiCurrentUnits] > 1 then
                        if not(oPlatoon[M27PlatoonUtilities.refiEnemiesInRange] > 0 or oPlatoon[M27PlatoonUtilities.refiEnemyStructuresInRange] > 0) then
                            --No nearby units to the platoon, so retreat unless platoon already running
                            if not(oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionTemporaryRetreat) and not(oPlatoon[M27PlatoonUtilities.refiCurrentAction] == M27PlatoonUtilities.refActionDisband) then
                                oPlatoon[M27PlatoonUtilities.refbOverseerAction] = true
                                oPlatoon[M27PlatoonUtilities.refiOverseerAction] = M27PlatoonUtilities.refActionRun
                            end
                        end
                    end
                end
            end
        end
    end
end

function OnBomberDeath(aiBrain, oDeadBomber)
    --Track how effective the bomber was
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OnBomberDeath'
    if bDebugMessages == true then LOG(sFunctionRef..': Checking if have a unitID for dead bomber') end
    if oDeadBomber.GetUnitId then
        local oBomberBP = oDeadBomber:GetBlueprint()
        local iBomberMassCost = oBomberBP.Economy.BuildCostMass
        if not(EntityCategoryContains(M27UnitInfo.refCategoryTorpBomber, oBomberBP.BlueprintId)) then
            local iMassKilled = oDeadBomber.Sync.totalMassKilled
            if iMassKilled == nil then iMassKilled = 0 end
            local iExistingEntries
            local tNewEntry = {}
            local iTechLevel = M27UnitInfo.GetUnitTechLevel(oDeadBomber)
            if M27Utilities.IsTableEmpty(aiBrain[reftBomberEffectiveness]) == true then
                aiBrain[reftBomberEffectiveness] = {}
                for iTech = 1, 4 do
                    aiBrain[reftBomberEffectiveness][iTech] = {}
                end
                iExistingEntries = 0
            else
                iExistingEntries = table.getn(aiBrain[reftBomberEffectiveness][iTechLevel])
            end
            tNewEntry[refiBomberMassCost] = iBomberMassCost
            tNewEntry[refiBomberMassKilled] = iMassKilled
            table.insert(aiBrain[reftBomberEffectiveness][iTechLevel], 1, tNewEntry)
            iExistingEntries = iExistingEntries + 1
            if iExistingEntries > iBombersToTrackEffectiveness then table.remove(aiBrain[reftBomberEffectiveness][iTechLevel], iExistingEntries) end

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
            aiBrain[refbBombersAreEffective][iTechLevel] = not(bNoEffectiveBombers)
            if bDebugMessages == true then LOG(sFunctionRef..': Bomber died; iBomberMassCost='..iBomberMassCost..'; iMassKilled='..iMassKilled..'; bNoEffectiveBombers='..tostring(bNoEffectiveBombers)) end
        end
    end

    --Update units it was targetting to show them as no longer having bomber strike damage assigned
    ClearTrackersOnUnitsTargets(oDeadBomber)
end

function OnScoutDeath(aiBrain, oDeadScout)
    --Get scouts current movement target, and update its trackers to show it no longer has as many scouts assigned and we have a dead scout
    --also flags a dead scout in the segments around where the scout died, and the segments around its current movement path target
    if oDeadScout[reftMovementPath] and oDeadScout[refiCurMovementPath] then
        --Cycle through remaining points on movement path and note they're no longer assigned to this scout
        local tFirstTarget
        if oDeadScout[reftMovementPath] and oDeadScout[refiCurMovementPath] then
            tFirstTarget = oDeadScout[reftMovementPath][oDeadScout[refiCurMovementPath]]
            if M27Utilities.IsTableEmpty(tFirstTarget) == true then tFirstTarget = oDeadScout:GetPosition() end
            local iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(tFirstTarget)
            RecordAirScoutDyingInNearbySegments(aiBrain, iCurAirSegmentX, iCurAirSegmentZ)
        end
    end
    ClearAirUnitAssignmentTrackers(aiBrain, oDeadScout)

    --Update all nearby segments to show a scout has died
    iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(oDeadScout:GetPosition())
    RecordAirScoutDyingInNearbySegments(aiBrain, iCurAirSegmentX, iCurAirSegmentZ)
end

function OnAirAADeath(oDeadAirAA)
    if oDeadAirAA[refoAirAATarget] and M27Utilities.IsTableEmpty(oDeadAirAA[refoAirAATarget][reftTargetedByList]) == false then
        for iTargetedBy, oTargetedBy in oDeadAirAA[refoAirAATarget][reftTargetedByList] do
            if oTargetedBy == oDeadAirAA then
                table.remove(oDeadAirAA[refoAirAATarget][reftTargetedByList], iTargetedBy)
            end
        end
    end
end

function TrackBomberTarget(oBomber, oTarget)
    if oBomber[reftTargetList] == nil then oBomber[reftTargetList] = {} end
    table.insert(oBomber[reftTargetList], oTarget)

    if oTarget[refiCurBombersAssigned] == nil then
        oTarget[refiCurBombersAssigned] = 1
        oTarget[refiLifetimeBombersAssigned] = 1
    else
        oTarget[refiCurBombersAssigned] = oTarget[refiCurBombersAssigned] + 1
        oTarget[refiLifetimeBombersAssigned] = oTarget[refiLifetimeBombersAssigned] + 1
    end

    if oBomber[refiCurTargetNumber] == 0 or oBomber[refiCurTargetNumber] == nil then oBomber[refiCurTargetNumber] = 1 end

    local iCurBomberStrikeDamage = M27UnitInfo.GetUnitStrikeDamage(oBomber)
    if iCurBomberStrikeDamage < 10 then
        M27Utilities.ErrorHandler('Bomber seems to have strike damage of less than 10, will assume its 10')
        iCurBomberStrikeDamage = 10
    end
    if oTarget[refiStrikeDamageAssigned] == nil then oTarget[refiStrikeDamageAssigned] = iCurBomberStrikeDamage
    else oTarget[refiStrikeDamageAssigned] = oTarget[refiStrikeDamageAssigned] + iCurBomberStrikeDamage end

    if M27Config.M27ShowUnitNames == true and oBomber.GetUnitId then M27PlatoonUtilities.UpdateUnitNames({oBomber}, oBomber:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oBomber)..':Attack:'..oTarget:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oTarget)) end
end

function UpdateBomberTargets(oBomber, bRemoveIfOnLand)
    --Checks if target dead; or (if not part of a large attack) if its shielded
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateBomberTargets'
    local bRemoveCurTarget
    local tTargetPos
    if M27Utilities.IsTableEmpty(oBomber[reftTargetList]) == false then
        local oBomberCurTarget
        local bBomberHasDeadOrShieldedTarget = true
        local iDeadLoopCount = 0
        local iMaxDeadLoopCount = table.getn(oBomber[reftTargetList]) + 1
        if bDebugMessages == true then LOG(sFunctionRef..': iMaxDeadLoopCount='..iMaxDeadLoopCount..': About to check if bomber has any dead targets') end
        local bIgnoreMobileShield = true
        if oBomber.GetUnitId and oBomber.GetAIBrain then
            local sBomberID = oBomber:GetUnitId()
            if EntityCategoryContains(categories.TECH1, sBomberID) or EntityCategoryContains(categories.TECH2, sBomberID) then bIgnoreMobileShield = false end
            local aiBrain = oBomber:GetAIBrain()

            while bBomberHasDeadOrShieldedTarget == true do
                iDeadLoopCount = iDeadLoopCount + 1
                if iDeadLoopCount > iMaxDeadLoopCount then M27Utilities.ErrorHandler('Infinite loop, will abort') break end
                oBomberCurTarget = oBomber[reftTargetList][oBomber[refiCurTargetNumber]]
                if bDebugMessages == true then LOG(sFunctionRef..': iDeadLoopCount='..iDeadLoopCount..'; iMaxDeadLoopCount='..iMaxDeadLoopCount) end
                bRemoveCurTarget = false
                if oBomberCurTarget == nil or oBomberCurTarget.Dead or not(oBomberCurTarget.GetPosition) then bRemoveCurTarget = true
                elseif bRemoveIfOnLand then
                    tTargetPos = oBomberCurTarget:GetPosition()
                    if GetTerrainHeight(tTargetPos[1], tTargetPos[2]) >= M27MapInfo.iMapWaterHeight then bRemoveCurTarget = true end
                end
                if bRemoveCurTarget == false and not(oBomber[refbPartOfLargeAttack]) then
                    --Check if shielded unless part of large attack
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': Checking if current target is shielded')
                        if oBomber[refiCurTargetNumber] == 1 then
                            LOG(sFunctionRef..': Position of first target is '..repr(oBomberCurTarget:GetPosition()))
                            M27Utilities.DrawLocation(oBomberCurTarget:GetPosition(), nil, 3)
                        end --draw black circle around target
                    end

                    if M27Logic.IsTargetUnderShield(aiBrain, oBomberCurTarget, bIgnoreMobileShield) == true then
                        if bDebugMessages == true then LOG(sFunctionRef..': Current target is shielded so will remove') end
                        bRemoveCurTarget = true
                    end
                end

                if bRemoveCurTarget == true then
                    if oBomber[refiCurTargetNumber] == nil then
                        M27Utilities.ErrorHandler('Bomber cur target number is nil; reftTargetList size='..table.getn(oBomber[reftTargetList]))
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': Removing bombers current target as it is nil or dead, iCurTargetNumber='..oBomber[refiCurTargetNumber]) end
                    --Dont want to use the normal clearairunitassignmenttrackers, as are only clearing the current entry
                    oBomber[refbOnAssignment] = false
                    table.remove(oBomber[reftTargetList], oBomber[refiCurTargetNumber])
                    if M27Utilities.IsTableEmpty(oBomber[reftTargetList]) == true then
                        oBomber[refiCurTargetNumber] = 0
                        bBomberHasDeadOrShieldedTarget = false
                        break
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': Bomber target list size='..table.getn(oBomber[reftTargetList])) end
                else
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': Bomber current target isnt dead, UnitId='..oBomberCurTarget:GetUnitId()..'; will draw circle around target position '..repr(oBomberCurTarget:GetPosition()))
                        M27Utilities.DrawLocation(oBomberCurTarget:GetPosition(), nil, 4, 100)
                    end
                    bBomberHasDeadOrShieldedTarget = false
                    break
                end
            end
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': Bomber has no target list') end
    end
    if M27Utilities.IsTableEmpty(oBomber[reftTargetList]) == true then
        if bDebugMessages == true then LOG(sFunctionRef..': Bombers target list is empty so making it available') end
        ClearAirUnitAssignmentTrackers(oBomber:GetAIBrain(), oBomber)
        --oBomber[refbOnAssignment] = false
        --oBomber[reftTargetList] = {}
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Bomer cur target='..oBomber[refiCurTargetNumber]) end
    if oBomber[refbPartOfLargeAttack] == true then oBomber[refbOnAssignment] = true end
    oBomber[refiBomberTargetLastAssessed] = GetGameTimeSeconds()
end

function DelayedBomberTargetRecheck(oBomber, iDelayInSeconds)
    WaitSeconds(iDelayInSeconds)
    if oBomber and GetGameTimeSeconds() - (oBomber[refiBomberTargetLastAssessed] or 0) >= 1 then
        UpdateBomberTargets(oBomber)
    end
end

function AirThreatChecker(aiBrain)
    --Get enemy total air threat level
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AirThreatChecker'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of cycle') end
    local tEnemyAirUnits = aiBrain:GetUnitsAroundPoint(categories.AIR, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Enemy')
    --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride)
    local iAllAirThreat = M27Logic.GetAirThreatLevel(aiBrain, tEnemyAirUnits, true, true, false, true, true)
    if aiBrain[refiHighestEnemyAirThreat] == nil then aiBrain[refiHighestEnemyAirThreat] = 0 end
    if iAllAirThreat > aiBrain[refiHighestEnemyAirThreat] then aiBrain[refiHighestEnemyAirThreat] = iAllAirThreat end
    local tMAAUnits = aiBrain:GetListOfUnits(categories.MOBILE * categories.LAND * categories.ANTIAIR, false, true)
    if M27Utilities.IsTableEmpty(tMAAUnits) == true then aiBrain[refiOurMAAUnitCount] = 0
    else aiBrain[refiOurMAAUnitCount] = table.getn(tMAAUnits) end
    aiBrain[refiOurMassInMAA] = M27Logic.GetAirThreatLevel(aiBrain, tMAAUnits, false, false, true, false, false)
    if bDebugMessages == true then LOG(sFunctionRef..': Finished cycle, iAllAirThreat='..iAllAirThreat..'; OurMassInMAA='..aiBrain[refiOurMassInMAA]) end


    --air AA wanted:
    local tAirAAUnits = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryAirAA, false, true)
    if M27Utilities.IsTableEmpty(tAirAAUnits) == true then
        aiBrain[refiOurMassInAirAA] = 0
        aiBrain[refiAirAAWanted] = math.max(aiBrain[refiAirAANeeded], 2)
    else
        aiBrain[refiOurMassInAirAA] = M27Logic.GetAirThreatLevel(aiBrain, tAirAAUnits, false, true, false, false, false)
        if aiBrain[refiOurMassInAirAA] < aiBrain[refiHighestEnemyAirThreat] then aiBrain[refiAirAAWanted] = math.max(aiBrain[refiAirAANeeded], 2)
        else aiBrain[refiAirAAWanted] = math.max(aiBrain[refiAirAANeeded], 0) end
    end
    --Emergency MAA checker
    local bEmergencyAA = false
    if aiBrain[refiHighestEnemyAirThreat] > 0 then
        if aiBrain[refiOurMassInMAA] == 0 then
            if bDebugMessages == true then LOG(sFunctionRef..': refiHighestEnemyAirThreat='..aiBrain[refiHighestEnemyAirThreat]..'; aiBrain[refiOurMassInMAA]='..aiBrain[refiOurMassInMAA]..' so are building emergency MAA') end
            bEmergencyAA = true
        else
            --Is there an enemy air threat near our base and we dont have much MAA near our base?
            local tNearbyEnemyAirThreat = aiBrain:GetUnitsAroundPoint(refCategoryAirNonScout, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 150, 'Enemy')
            if M27Utilities.IsTableEmpty(tNearbyEnemyAirThreat) == false then
                --Do we have MAA near our base equal to 1/3 of the enemy air threat in mass, to a minimum of 3 units?
                local tNearbyMAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMAA, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 100, 'Ally')
                if M27Utilities.IsTableEmpty(tNearbyMAA) == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have nearby enemy air threat with '..table.getn(tNearbyEnemyAirThreat)..' units but no nearby MAA so building emergency MAA') end
                    bEmergencyAA = true
                else
                    local iOurNearbyMAAThreat = M27Logic.GetAirThreatLevel(aiBrain, tNearbyMAA, false, false, true, false, false)
                    local iNearbyEnemyAirThreat = M27Logic.GetAirThreatLevel(aiBrain, tEnemyAirUnits, true, true, false, true, true)
                    if bDebugMessages == true then LOG(sFunctionRef..': iOurNearbyMAAThreat='..iOurNearbyMAAThreat..'; iNearbyEnemyAirThreat='..iNearbyEnemyAirThreat) end
                    if iOurNearbyMAAThreat < iNearbyEnemyAirThreat * 0.3 then
                        bEmergencyAA = true
                    end
                end
            end
        end
    end
    aiBrain[M27Overseer.refbEmergencyMAANeeded] = bEmergencyAA
end

function RecordAvailableAndLowFuelAirUnits(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordAvailableAndLowFuelAirUnits'
    --Updates aiBrain trackers to record units with and without enough fuel
    local tAllScouts = aiBrain:GetListOfUnits(refCategoryAirScout, false, true)
    local tAllBombers = aiBrain:GetListOfUnits(refCategoryBomber, false, true)
    local tAllAirAA = aiBrain:GetListOfUnits(refCategoryAirAA, false, true)
    local tTorpBombers = aiBrain:GetListOfUnits(refCategoryTorpBomber, false, true)
    local iCurUnitsWithFuel, iCurUnitsWithLowFuel
    local tAllAirUnits = {tAllScouts, tAllBombers, tAllAirAA, tTorpBombers}
    local tAvailableUnitRef = {reftAvailableScouts, reftAvailableBombers, reftAvailableAirAA, reftAvailableTorpBombers}
    local iTypeScout = 1
    local iTypeBomber = 2
    local iTypeAirAA = 3
    local iTypeTorpBomber = 4
    local sAvailableUnitRef
    local bUnitIsUnassigned
    local iTimeStamp = GetGameTimeSeconds()
    local sTargetBP, tTargetPos, tOurPosition, tTargetDestination, bClearAirAATargets, bReturnToBase

    aiBrain[reftLowFuelAir] = {}
    iCurUnitsWithLowFuel = 0

    for iUnitType, tAllAirOfType in tAllAirUnits do
        --if iUnitType == iTypeTorpBomber then bDebugMessages = true end
        sAvailableUnitRef = tAvailableUnitRef[iUnitType]
        aiBrain[sAvailableUnitRef] = {}
        iCurUnitsWithFuel = 0
        if M27Utilities.IsTableEmpty(tAllAirOfType) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Going through all air units to see if any have low fuel') end
            local tCurWaypointTarget, iDistanceToComplete, tUnitCurPosition, iTotalMovementPaths, iCurLoopCount, iCurAirSegmentX, iCurAirSegmentZ, oNavigator
            local iMaxLoopCount = 50
            local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
            local tEnemyStartPosition = M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]
            local iDistanceFromStartForReset = 20 --If unit is this close to start then will reset it if its not on its first assignment/doesnt have a target thats further away
            local iFuelPercent, iHealthPercent
            for iUnit, oUnit in tAllAirOfType do
                bUnitIsUnassigned = false
                if bDebugMessages == true then LOG(sFunctionRef..'; iUnitType='..iUnitType..'; iUnit='..iUnit..'; checking if unit is dead and has fuel and whether its on assignment') end
                if not(oUnit.Dead) and oUnit.GetFractionComplete and oUnit:GetFractionComplete() == 1 then
                    iFuelPercent = 0
                    if oUnit.GetFuelRatio then iFuelPercent = oUnit:GetFuelRatio() end
                    if iFuelPercent >= 0.25 then
                        if oUnit[refbOnAssignment] == true then
                            --Unit on assignment - check if its reached it
                            if iUnitType == iTypeScout then
                                tCurWaypointTarget = oUnit[reftMovementPath][oUnit[refiCurMovementPath]]
                                if bDebugMessages == true then LOG(sFunctionRef..': Checking if iUnit='..iUnit..' has reached its target; cur target='..repr(tCurWaypointTarget)) end
                                if M27Utilities.IsTableEmpty(tCurWaypointTarget) == false then
                                    if bDebugMessages == true then LOG(sFunctionRef..': tCurWaypointTarget='..repr(tCurWaypointTarget)) end
                                    iDistanceToComplete = oUnit:GetBlueprint().Intel.VisionRadius * 0.8
                                    tUnitCurPosition = oUnit:GetPosition()
                                    local iDistanceToCurTarget = M27Utilities.GetDistanceBetweenPositions(tUnitCurPosition, tCurWaypointTarget)
                                    iCurLoopCount = 0
                                    if bDebugMessages == true then LOG(sFunctionRef..': iDistanceToCurTarget='..iDistanceToCurTarget..'; iDistanceToComplete='..iDistanceToComplete) end
                                    iTotalMovementPaths = table.getn(oUnit[reftMovementPath])
                                    iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(tCurWaypointTarget)
                                    --Check if are either close to the target, or have had recent visual of the target

                                    while iDistanceToCurTarget <= iDistanceToComplete or iTimeStamp - aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastScouted] <= math.max(2, aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval] - 10)  do
                                        if bDebugMessages == true then LOG(sFunctionRef..': Are close enough to target or have already had recent visual of the target, checking unit on assignment, iCurLoopCount='..iCurLoopCount..'; iTimeStamp='..iTimeStamp..'; [refiLastScouted]='..aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastScouted]..'; iCurAirSegmentX-Z='..iCurAirSegmentX..'-'..iCurAirSegmentZ) end
                                        iCurLoopCount = iCurLoopCount + 1
                                        if iCurLoopCount > iMaxLoopCount then M27Utilities.ErrorHandler('Infinite loop') break end

                                        aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] - 1
                                        oUnit[refiCurMovementPath] = oUnit[refiCurMovementPath] + 1
                                        if oUnit[refiCurMovementPath] > iTotalMovementPaths then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Unit has reached all its movement paths so making it available') end
                                            ClearAirUnitAssignmentTrackers(aiBrain, oUnit)
                                            bUnitIsUnassigned = true
                                            break
                                            --oUnit[refbOnAssignment] = false
                                        else
                                            tCurWaypointTarget = oUnit[reftMovementPath][oUnit[refiCurMovementPath]]
                                            if bDebugMessages == true then LOG(sFunctionRef..': Scout has reached target, increasing its movement path 1 to '..oUnit[refiCurMovementPath]..'; location of this='..repr(tCurWaypointTarget)) end
                                            if M27Utilities.IsTableEmpty(tCurWaypointTarget) == true then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Units current target is empty so making it available again') end
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
                                            if oUnit[refiCurMovementPath] > 1 then bConsiderForReset = true
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
                                            if bConsiderForReset == true then
                                                --Reset scout to prevent risk of it reaching a movement path but not registering in above code
                                                ClearAirUnitAssignmentTrackers(aiBrain, oUnit)
                                            end
                                        end
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': iCurLoopCount='..iCurLoopCount..'; so scout managed to reach at least one destination') end
                                        --Scout managed to reach at least one destination
                                        if oUnit[refiCurMovementPath] <= iTotalMovementPaths then
                                            if bDebugMessages == true then
                                                local iLifetimeCount = M27UnitInfo.GetUnitLifetimeCount(oUnit)
                                                LOG(sFunctionRef..': About to clear scouts path and then reissue remaining paths that scout hasnt reached yet; scout unique count='..iLifetimeCount)
                                            end
                                            IssueClearCommands({oUnit})
                                            ClearPreviousMovementEntries(aiBrain, oUnit) --Will remove earlier movement path entries and update assignment trackers

                                            for iPath, tPath in oUnit[reftMovementPath] do
                                                IssueMove({oUnit}, tPath)
                                            end
                                        else
                                            if bDebugMessages == true then LOG(sFunctionRef..': CurMovementPath > total movement paths so scout must have reached all its destinations - making scout available again') end
                                            bUnitIsUnassigned = true
                                            ClearAirUnitAssignmentTrackers(aiBrain, oUnit)
                                            --oUnit[refbOnAssignment] = false
                                        end
                                    end
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': Current movement path is empty so making scout available') end
                                    --oUnit[refbOnAssignment] = false
                                    ClearAirUnitAssignmentTrackers(aiBrain, oUnit)
                                    bUnitIsUnassigned = true
                                end
                            elseif iUnitType == iTypeBomber or iUnitType == iTypeTorpBomber then
                                if bDebugMessages == true then LOG(sFunctionRef..': Have a bomber or torp bomber, will check its targets; refbOnAssignment pre check='..tostring(oUnit[refbOnAssignment])) end
                                UpdateBomberTargets(oUnit)
                                if oUnit[refbOnAssignment] == false then bUnitIsUnassigned = true end
                                if bDebugMessages == true then LOG(sFunctionRef..': refbOnAssignment post check='..tostring(oUnit[refbOnAssignment])) end
                            elseif iUnitType == iTypeAirAA then
                                bClearAirAATargets = false
                                bReturnToBase = false
                                if oUnit[refoAirAATarget] == nil or oUnit[refoAirAATarget].Dead then
                                    bClearAirAATargets = true
                                else
                                    --Check if want to stop chasing the target
                                    sTargetBP = oUnit[refoAirAATarget]:GetUnitId()
                                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if sTargetBP '..sTargetBP..' is an air scout or airAA unit') end
                                    if EntityCategoryContains(refCategoryAirAA, sTargetBP) or EntityCategoryContains(refCategoryAirScout, sTargetBP) then
                                        --Are we closer to enemy base than ours?
                                        tOurPosition = oUnit:GetPosition()
                                        if bDebugMessages == true then LOG(sFunctionRef..': Checking how close we are to our start and enemy start') end
                                        if M27Utilities.GetDistanceBetweenPositions(tEnemyStartPosition, tOurPosition) < M27Utilities.GetDistanceBetweenPositions(tStartPosition, tOurPosition) then
                                            --are we not in combat range of the enemy target?
                                            if bDebugMessages == true then LOG(sFunctionRef..': Checking if enemy unit is within our combat range') end
                                            tTargetPos = oUnit[refoAirAATarget]:GetPosition()
                                            if M27Utilities.GetDistanceBetweenPositions(tTargetPos, tOurPosition) - 1 > oUnit:GetBlueprint().Weapon[1].MaxRadius then
                                                --is it moving further away from our base? Approximate by getting the unit's current target
                                                if bDebugMessages == true then LOG(sFunctionRef..': Checking if enemy unit navigator target is closer to us or enemy') end
                                                if oUnit[refoAirAATarget].GetNavigator then
                                                    tTargetDestination = oUnit[refoAirAATarget]:GetNavigator():GetCurrentTargetPos()
                                                    if M27Utilities.GetDistanceBetweenPositions(tTargetDestination, tStartPosition) > M27Utilities.GetDistanceBetweenPositions(tTargetDestination, tEnemyStartPosition) then
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Will clear target since its heading towards enemy base and we dont want to follow it') end
                                                        bClearAirAATargets = true
                                                        bReturnToBase = true
                                                    else
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef..': navigator target destination is closer to our start than the enemy start')
                                                        end
                                                    end
                                                else if bDebugMessages == true then LOG(sFunctionRef..': Target unit doesnt have a navigator') end
                                                end
                                            end
                                        end
                                    end
                                end
                                if bClearAirAATargets == true then
                                    ClearAirUnitAssignmentTrackers(aiBrain, oUnit)
                                    bUnitIsUnassigned = true
                                    if bReturnToBase == true then
                                        IssueClearCommands({oUnit})
                                        IssueMove({oUnit}, tStartPosition)
                                        if bDebugMessages == true then LOG(sFunctionRef..': Cleared commants for unit='..oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                                    end
                                    --oUnit[refbOnAssignment] = false
                                end
                            elseif iUnitType == M27UnitInfo.refCategoryTorpBomber then

                            else
                                M27Utilities.ErrorHandler('To add code')
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Unit doesnt have an assignment') end
                            if not(oUnit[refbWillBeRefueling]) then
                                bUnitIsUnassigned = true
                            else
                                --Error check in case unit somehow gained full health and fuel
                                if iFuelPercent >= 0.99 then
                                    if oUnit:GetHealthPercent() >= 0.99 then
                                        if bDebugMessages == true then LOG('Warning - Unit has its status as refueling, but its health and fuel percent are >=99%.  Will remove its status as refueling') end
                                        oUnit[refbWillBeRefueling] = false
                                    end
                                end
                            end
                        end
                        if bUnitIsUnassigned == true then
                            --Bomber specific - treat low health bombers as unavailable
                            if (iUnitType == iTypeBomber or iUnitType == iTypeTorpBomber) and oUnit:GetHealthPercent() <= 0.25 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Bomber has low health or fuel so wont make it available') end
                                iCurUnitsWithLowFuel = iCurUnitsWithLowFuel + 1
                                aiBrain[reftLowFuelAir][iCurUnitsWithLowFuel] = oUnit
                            else
                                iCurUnitsWithFuel = iCurUnitsWithFuel + 1
                                aiBrain[sAvailableUnitRef][iCurUnitsWithFuel] = oUnit
                                if bDebugMessages == true then LOG(sFunctionRef..': have an air unit with enough fuel, iCurUnitsWithFuel='..iCurUnitsWithFuel) end
                            end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Unit has low fuel') end
                        iCurUnitsWithLowFuel = iCurUnitsWithLowFuel + 1
                        aiBrain[reftLowFuelAir][iCurUnitsWithLowFuel] = oUnit
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Unit is dead or not constructed') end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Finished getting all units with type ref='..sAvailableUnitRef..'; size of available unit ref table='..table.getn(aiBrain[sAvailableUnitRef])) end
        end
    end
end

function OrderUnitsToRefuel(aiBrain, tUnitsToRefuel)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'OrderUnitsToRefuel'
    --Sends low fuel units to air staging
    if M27Utilities.IsTableEmpty(tUnitsToRefuel) == false then
        local tAirStaging = aiBrain:GetListOfUnits(categories.AIRSTAGINGPLATFORM, false, true)
        if bDebugMessages == true then LOG(sFunctionRef..': Want units to refuel, number of airstaging we have='..table.getn(tAirStaging)) end
        if M27Utilities.IsTableEmpty(tAirStaging) == true then
            if bDebugMessages == true then LOG(sFunctionRef..': tAirStaging is nil, but we have units that want to refuel') end
            aiBrain[refiAirStagingWanted] = 1
        else
            aiBrain[refiAirStagingWanted] = 0
            --Find nearest available air staging unit
            if bDebugMessages == true then LOG(sFunctionRef..': We have air staging so getting unit to refuel') end
            local bAlreadyTryingToRefuel = false
            local bWaitBeforeRefueling
            local oNavigator, tCurTarget, tNearbyAirStaging
            local tTargetPos, tUnitPosition, iDistanceToTarget, iDistanceToBase
            local tOurStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
            for iStaging, oStaging in tAirStaging do
                if not(oStaging.Dead) then
                    local roomAvailable = false
                    if not EntityCategoryContains(categories.CARRIER, oStaging) then
                        roomAvailable = oStaging:TransportHasSpaceFor(tUnitsToRefuel[1])
                    end
                    if roomAvailable then

                        if bDebugMessages == true then LOG(sFunctionRef..': First refueling unit state='..M27Logic.GetUnitState(tUnitsToRefuel[1])) end
                        for iUnit, oUnit in tUnitsToRefuel do
                            bWaitBeforeRefueling = false
                            if EntityCategoryContains(refCategoryBomber, oUnit:GetUnitId()) then
                                UpdateBomberTargets(oUnit)
                                if oUnit[refiCurTargetNumber] > 0 then
                                    --Is the target a long way away?
                                    if bDebugMessages == true then LOG(sFunctionRef..': refiCurTargetNumber='..oUnit[refiCurTargetNumber]..'; target list size='..table.getn(oUnit[reftTargetList])) end

                                    tTargetPos = oUnit[reftTargetList][oUnit[refiCurTargetNumber]]:GetPosition()
                                    tUnitPosition = oUnit:GetPosition()
                                    iDistanceToTarget = M27Utilities.GetDistanceBetweenPositions(tTargetPos, tUnitPosition)
                                    bWaitBeforeRefueling = true
                                    if iDistanceToTarget >= 200 then
                                        --Bombers have fuel use time of 400s, and max air speed of 10s; threshold for refueling is currently 25%, or 100s, meaning max distance in theory should be 1000
                                        --Want margin of error though, so consider distance from target to our start
                                        iDistanceToBase = M27Utilities.GetDistanceBetweenPositions(tTargetPos, tOurStartPosition)
                                        if iDistanceToTarget + iDistanceToBase >= 500 then
                                            bWaitBeforeRefueling = false
                                        end
                                    end
                                end
                                if not(oUnit[refbWillBeRefueling]) then
                                    --First time we're telling the bomber to refuel so send it home as a final action
                                    IssueMove({oUnit}, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                end
                            end
                            oUnit[refbWillBeRefueling] = true

                            if bWaitBeforeRefueling == false then
                                bAlreadyTryingToRefuel = false
                                if oUnit:IsUnitState('MovingDown') then bAlreadyTryingToRefuel = true
                                else
                                    --Check if current target is the refueling location
                                    if oUnit.GetNavigator then
                                        oNavigator = oUnit:GetNavigator()
                                        if oNavigator.GetCurrentTargetPos then
                                            tCurTarget = oNavigator:GetCurrentTargetPos()
                                            tNearbyAirStaging = M27Utilities.GetOwnedUnitsAroundPoint(aiBrain, categories.AIRSTAGINGPLATFORM, tCurTarget, 2)
                                            if M27Utilities.IsTableEmpty(tNearbyAirStaging) == false then
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef..' tCurTarget='..repr(tCurTarget))
                                                    M27Utilities.DrawLocation(tCurTarget)
                                                end
                                                bAlreadyTryingToRefuel = true
                                            end
                                        end
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': bAlreadyTryingToRefuel='..tostring(bAlreadyTryingToRefuel)) end
                                if not(bAlreadyTryingToRefuel) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Clearing commands for unit') end
                                    if M27Config.M27ShowUnitNames == true and oUnit.GetUnitId then M27PlatoonUtilities.UpdateUnitNames({oUnit}, oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)..':Refueling') end
                                    IssueClearCommands({ oUnit})
                                    IssueTransportLoad({ oUnit }, oStaging)

                                    --Reset trackers on the unit
                                    for iUnit, oUnit in tUnitsToRefuel do
                                        ClearAirUnitAssignmentTrackers(aiBrain, oUnit)
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

function RefuelIdleAirUnits(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RefuelIdleAirUnits'
    --Checks for any idle air units near start that could do with a slight refuel
    local iSearchRange = 50
    local tOurStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    local tAirUnitsNearStart = M27Utilities.GetOwnedUnitsAroundPoint(aiBrain, M27UnitInfo.refCategoryAllNonExpAir, tOurStartPosition, iSearchRange)
    local iHealthThreshold = 0.8
    local iFuelThreshold = 0.7
    local tUnitsToRefuel = {}
    local iUnitsToRefuel = 0
    local bRefuelUnit
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, checking if have any air units near start') end
    if M27Utilities.IsTableEmpty(tAirUnitsNearStart) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': have '..table.getn(tAirUnitsNearStart)..' air units to consider') end
        for _, oUnit in tAirUnitsNearStart do
            bRefuelUnit = false
            if not(oUnit[refbOnAssignment]) and M27Utilities.IsTableEmpty(oUnit[reftTargetList]) == true and M27Utilities.IsTableEmpty(oUnit[refiCurMovementPath]) == true and oUnit.GetFuelRatio then
                if bDebugMessages == true then LOG(sFunctionRef..': Unit ID='..oUnit:GetUnitId()..'; unit fraction complete='..oUnit:GetFractionComplete()) end
                if oUnit:GetFuelRatio() <= iFuelThreshold then bRefuelUnit = true
                elseif oUnit:GetHealthPercent() <= iHealthThreshold then bRefuelUnit = true end
                if bDebugMessages == true then LOG(sFunctionRef..': Finished checking unit fuel ratio and health, bRefuelUnit='..tostring(bRefuelUnit)) end

                if bRefuelUnit == true then
                    iUnitsToRefuel = iUnitsToRefuel + 1
                    tUnitsToRefuel[iUnitsToRefuel] = oUnit
                    if bDebugMessages == true then LOG(sFunctionRef..': Have a unit to refuel') end
                end
            else
                if bDebugMessages == true then
                    local iUnitLifetimeCount = M27UnitInfo.GetUnitLifetimeCount(oUnit)
                    LOG(sFunctionRef..': Unit with ID and lifetime count='..oUnit:GetUnitId()..iUnitLifetimeCount..' is either on assignment or has a target in target list or has a movement path')
                end
            end
        end
    end
    if iUnitsToRefuel > 0 then
        OrderUnitsToRefuel(aiBrain, tUnitsToRefuel)
    end
end

function UnloadUnit(oTransport)
    --Unfortunately couldnt get this to work by issuing transportunload command to the unit docked in the transport, so having to have transport release all its units
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UnloadUnit'
    if bDebugMessages == true then LOG(sFunctionRef..': Issuing unload command to transport/air staging unit') end
    local tTransportPosition = oTransport:GetPosition()
    local tRefuelingUnits = oTransport:GetCargo()
    for iUnit, oUnit in tRefuelingUnits do
        ClearAirUnitAssignmentTrackers(oUnit:GetAIBrain(), oUnit)
        --oUnit[refbOnAssignment] = false
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Issuing clear commands') end
    IssueClearCommands({oTransport})
    IssueTransportUnload({oTransport}, {tTransportPosition[1]+5, tTransportPosition[2], tTransportPosition[3]+5})
end

function ReleaseRefueledUnits(aiBrain)
    --Only want to call this periodically as doesnt seem an easy way of telling it to only release some of the units, instead it releases all
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReleaseRefueledUnits'
    local tStagingPosition = {}
    local bReadyToLeave
    local tAirStaging = aiBrain:GetListOfUnits(categories.AIRSTAGINGPLATFORM, false, true)
    local tRefuelingUnits
    if M27Utilities.IsTableEmpty(tAirStaging) == false then
        for iStaging, oStaging in tAirStaging do
            if not(oStaging.Dead) then
                tRefuelingUnits = oStaging:GetCargo()
                if bDebugMessages == true then LOG(sFunctionRef..': Checking if air staging has any refueling units') end
                if M27Utilities.IsTableEmpty(tRefuelingUnits) == false then
                    for iRefuelingUnit, oRefuelingUnit in tRefuelingUnits do
                        if not(oRefuelingUnit.Dead) then
                            oRefuelingUnit[refbWillBeRefueling] = false
                            if bDebugMessages == true then LOG(sFunctionRef..': Have a unit refueling, checking tracker') end
                            bReadyToLeave = true
                            if bDebugMessages == true then LOG(sFunctionRef..': Have a unit refueling, checking its health and fuel') end
                            if oRefuelingUnit:GetFuelRatio() < 0.9 or oRefuelingUnit:GetHealthPercent() < 0.9 then bReadyToLeave = false end
                            if bReadyToLeave then
                                if bDebugMessages == true then LOG(sFunctionRef..': Telling unit to leave air staging') end
                                ForkThread(UnloadUnit, oStaging)
                                break
                            end
                        end
                    end
                else if bDebugMessages == true then LOG(sFunctionRef..': .Refueling is nil so not proceeding') end
                end
            end
        end
    end
end

function UpdateScoutingSegmentRequirements(aiBrain)
    --Updates trackers for when we last had visual of an area, and updates table containing list of targets that we want to scout
    --returns the number of scouts we want
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateScoutingSegmentRequirements'

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
    for iCurAirSegmentX = aiBrain[refiMinSegmentX], aiBrain[refiMaxSegmentX], 1 do
        for iCurAirSegmentZ = aiBrain[refiMinSegmentZ], aiBrain[refiMaxSegmentZ], 1 do
            iLastScoutedTime = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastScouted]
            if bDebugMessages == true then
                if iCurAirSegmentX <= 4 and iCurAirSegmentZ <= 4 then
                    LOG(sFunctionRef..': iCurAirSegmentXZ='..iCurAirSegmentX..'-'..iCurAirSegmentZ..'; iLastScoutedTime='..iLastScoutedTime..';[refiCurrentScoutingInterval]='..aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval]..'; iCurTime='..iCurTime..'; iIntervalInSecondsBeforeRefresh='..iIntervalInSecondsBeforeRefresh)
                end
            end
            if iCurTime - iLastScoutedTime >= iIntervalInSecondsBeforeRefresh then
                --tCurPosition = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][reftMidpointPosition]
                --[[if CanSeePosition(aiBrain, tCurPosition, iMaxSearchRange) then
                    aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastScouted] = iCurTime
                    aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiDeadScoutsSinceLastReveal] = 0
                    aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval] = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiNormalScoutingIntervalWanted]
                else--]]
                iCurIntervalWanted = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval]
                iCurTimeSinceWantedToScout = iCurTime - iLastScoutedTime - iCurIntervalWanted
                if iCurTimeSinceWantedToScout > 0 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Found a location that we havent scouted for a while, X-Z='..iCurAirSegmentX..'-'..iCurAirSegmentZ..'; Dead scouts='..aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiDeadScoutsSinceLastReveal]..'; assigned scouts='..aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned]) end
                    --Check we dont already have assigned scouts and/or too many dead scouts
                    if aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiDeadScoutsSinceLastReveal] < iDeadScoutThreshold then
                        iCurActiveScoutsAssigned = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned]
                        if iCurActiveScoutsAssigned == 0 then
                            iScoutTargetCount = iScoutTargetCount + 1


                            aiBrain[reftScoutingTargetShortlist][iScoutTargetCount] = {}
                            aiBrain[reftScoutingTargetShortlist][iScoutTargetCount][refiTimeSinceWantedToScout] = iCurTimeSinceWantedToScout
                            aiBrain[reftScoutingTargetShortlist][iScoutTargetCount][refiSegmentX] = iCurAirSegmentX
                            aiBrain[reftScoutingTargetShortlist][iScoutTargetCount][refiSegmentZ] = iCurAirSegmentZ
                            if iCurTimeSinceWantedToScout > iLongScoutDelayThreshold then
                                iScoutLongDelayCount = iScoutLongDelayCount + 1
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': Adding location to shortlist, iScoutTargetCount='..iScoutTargetCount) end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Already assigned '..iCurActiveScoutsAssigned..' scouts to this location') end
                        end
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
    if bDebugMessages == true then LOG(sFunctionRef..': Finished going through every segment on the map') end

    --Determine how many scouts we want
    local iScoutsWantedActual = math.ceil(iScoutLongDelayCount / 3)
    if iScoutsWantedActual < iMinScoutsForMap then iScoutsWantedActual = iMinScoutsForMap
    elseif iScoutsWantedActual > iMaxScoutsForMap then iScoutsWantedActual = iMaxScoutsForMap end

    local iAvailableScouts = 0
    if M27Utilities.IsTableEmpty(aiBrain[reftAvailableScouts]) == false then iAvailableScouts = table.getn(aiBrain[reftAvailableScouts]) end

    aiBrain[refiExtraAirScoutsWanted] = iScoutsWantedActual - iAvailableScouts
end

function GetEndDestinationForScout(aiBrain, oScout)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetEndDestinationForScout'

    local tEndDestination
    local iSegmentDistance
    local iCurOverdueTime
    local iGreatestOverdueTime = 0
    local iClosestDistance, iCurDistance
    local iFinalX, iFinalZ, iFinalCount
    iClosestDistance = 10000

    local iStartSegmentX, iStartSegmentZ = GetAirSegmentFromPosition(oScout:GetPosition())

    if bDebugMessages == true then LOG(sFunctionRef..': Shortlist size='..table.getn(aiBrain[reftScoutingTargetShortlist])..'; reftScoutingTargetShortlist='..repr(aiBrain[reftScoutingTargetShortlist])) end
    --Get the location closest to scout based on segment check (segment check used instead of getposition for efficiency)
    for iCount, tSubtable1 in aiBrain[reftScoutingTargetShortlist] do
        iCurOverdueTime =  aiBrain[reftScoutingTargetShortlist][iCount][refiTimeSinceWantedToScout]
        if iCurOverdueTime == nil then M27Utilities.ErrorHandler('No overdue time assigned')
        elseif iCurOverdueTime >= iGreatestOverdueTime then
            iCurDistance = math.abs(aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentX] - iStartSegmentX) + math.abs(aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentZ] - iStartSegmentZ)
            if iCurOverdueTime > iGreatestOverdueTime or iCurDistance < iClosestDistance then
                iClosestDistance = iCurDistance
                iFinalX = aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentX]
                iFinalZ = aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentZ]
                if bDebugMessages == true then LOG(sFunctionRef..': Current segment to use for final destination XZ='..iFinalX..'-'..iFinalZ) end
                iFinalCount = iCount
            end
            iGreatestOverdueTime = iCurOverdueTime
        end
        if bDebugMessages == true then LOG(sFunctionRef..': iCount='..iCount..'; Segment X-Z='..aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentX]..'-'..aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentZ]..'; Time since wanted to scout='..aiBrain[reftScoutingTargetShortlist][iCount][refiTimeSinceWantedToScout]..'; iGreatestOverdueTime='..iGreatestOverdueTime..'; iFinalX-Z='..iFinalX..'-'..iFinalZ) end
    end
    if iFinalCount then
        --Update tracker to show we've assigned this scout - this is now done later when the move command is given
        table.remove(aiBrain[reftScoutingTargetShortlist], iFinalCount)
        if bDebugMessages == true then LOG(sFunctionRef..': iFinalX='..iFinalX..'; iFinalZ='..iFinalZ..': Increasing scouts assigned by 1') end
        --aiBrain[reftAirSegmentTracker][iFinalX][iFinalZ][refiAirScoutsAssigned] = aiBrain[reftAirSegmentTracker][iFinalX][iFinalZ][refiAirScoutsAssigned] + 1

        if bDebugMessages == true then LOG(sFunctionRef..': Final destination XZ segments='..iFinalX..'-'..iFinalZ..'; about to check for via points') end
        return GetAirPositionFromSegment(iFinalX, iFinalZ)
    else
        --No places to scout - return nil (will add player start position at later step)
        if bDebugMessages == true then LOG(sFunctionRef..': No final destination found, will return to base') end
        return nil
    end
end

function CreateMovementPathFromDestination(aiBrain, tEndDestination, oScout)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CreateMovementPathFromDestination'
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
        if iAngle == 180 or iAngle >= 360 then iAngle = 270 end
        tEndViaPoint = M27Utilities.MoveTowardsTarget(aiBrain[reftAirSegmentTracker][iEndDestinationX][iEndDestinationZ][reftMidpointPosition], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iDetourDistance, iAngle)
        if bDebugMessages == true then LOG(sFunctionRef..': Orig end point was '..repr(aiBrain[reftAirSegmentTracker][iEndDestinationX][iEndDestinationZ][reftMidpointPosition])..'; new end point is '..repr(tEndViaPoint)) end
        if M27Utilities.IsTableEmpty(tEndViaPoint) == false then
            table.insert(tMovementPath, 1, tEndViaPoint)
            iEndDestinationX, iEndDestinationZ = GetAirSegmentFromPosition(tEndViaPoint)
        end
    end

    local iMaxViaPoints = 20
    local iCurViaPointCount = 0

    while bKeepSearching == true do
        if bDebugMessages == true then LOG(sFunctionRef..': Checking via points for unit, iCurCount='..iCurCount) end
        iCurCount = iCurCount + 1
        if iCurCount > iMaxCount then M27Utilities.ErrorHandler('Infinite loop, will abort') break end

        if iEndDestinationX - iStartSegmentX < 0 then bWantSmallerThanEndX = false else bWantSmallerThanEndX = true end
        if iEndDestinationZ - iStartSegmentZ < 0 then bWantSmallerThanEndZ = false else bWantSmallerThanEndZ = true end

        --Create a temporary local shortlist of locations to consider based on the current destination
        iLocalShortlistCount = 0
        tLocalisedShortlist = {}
        for iCount, tSubtable1 in aiBrain[reftScoutingTargetShortlist] do
            iCurSegmentX = aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentX]
            iCurSegmentZ = aiBrain[reftScoutingTargetShortlist][iCount][refiSegmentZ]
            bValidViaPointX = false
            bValidViaPointZ = false
            if bWantSmallerThanEndX then
                if iCurSegmentX <= iEndDestinationX then bValidViaPointX = true end
            else
                if iCurSegmentX >= iEndDestinationX then bValidViaPointX = true end
            end
            if bValidViaPointX == true then
                if bWantSmallerThanEndZ then
                    if iCurSegmentZ <= iEndDestinationZ then bValidViaPointZ = true end
                else
                    if iCurSegmentZ >= iEndDestinationZ then bValidViaPointZ = true end
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
                LOG(sFunctionRef..': iEndDestinationX='..iEndDestinationX)
                LOG(sFunctionRef..': tLocalisedShortlist[1][refiSegmentX]='..tLocalisedShortlist[1][refiSegmentX])
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
                if bDebugMessages == true then LOG(sFunctionRef..': Assining scout to X-Z='..iEndDestinationX..'-'..iEndDestinationZ) end
                --Remove from shortlist so not considered by anything else this cycle
                table.remove(aiBrain[reftScoutingTargetShortlist], iOriginalShortlistKeyRef)
                iCurViaPointCount = iCurViaPointCount + 1
                if iCurViaPointCount >= iMaxViaPoints then
                    bKeepSearching = false
                    break
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Dont have a closest segment X ref') end
                break
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Local shortlist count isnt > 0') end
            --no viable locations so stop adding via points
            break
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, tMovementPath='..repr(tMovementPath)) end
    return tMovementPath
end

function AirScoutManager(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AirScoutManager'
    --Determine how many scouts we want and what locations need scouting:
    UpdateScoutingSegmentRequirements(aiBrain)

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
        for iUnit, oUnit in aiBrain[reftAvailableScouts] do
            if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': Not on assignment so getting end destination') end
            tEndDestination = GetEndDestinationForScout(aiBrain, oUnit)
            if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..': End destination='..repr(tEndDestination)) end
            if M27Utilities.IsTableEmpty(tEndDestination) == false then
                tMovementPath = CreateMovementPathFromDestination(aiBrain, tEndDestination, oUnit)
                if bDebugMessages == true then
                    LOG(sFunctionRef..'iUnit='..iUnit..': Full movement path='..repr(tMovementPath))
                    M27Utilities.DrawLocations(tMovementPath)
                end
                if bDebugMessages == true then LOG(sFunctionRef..': About to issue clear command to scout with unit number='..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                IssueClearCommands({oUnit})
                --Issue moves to the targets and update tracker for this
                iMoveCount = 0
                for iWaypoint, tWaypoint in tMovementPath do
                    iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(tWaypoint)
                    if bDebugMessages == true then LOG(sFunctionRef..': Issuing move command to go to Segment X-Z='..iCurAirSegmentX..iCurAirSegmentZ..'; destination='..repr(tWaypoint)) end
                    aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] = aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiAirScoutsAssigned] + 1
                    --M27Logic.IssueDelayedMove({oUnit}, tWaypoint, iMoveCount * 10)
                    IssueMove({oUnit}, tWaypoint)
                    iMoveCount = iMoveCount + 1
                end
                --Return to base at the end:
                --M27Logic.IssueDelayedMove({oUnit}, tOurStart, iMoveCount * 10)
                if bDebugMessages == true then LOG(sFunctionRef..': Setting the unit to be assigned and recording its movement path') end
                IssueMove({oUnit}, tOurStart)
                oUnit[refbOnAssignment] = true
                oUnit[refiCurMovementPath] = 1
                oUnit[reftMovementPath] = tMovementPath
                if M27Config.M27ShowUnitNames == true and oUnit.GetUnitId then M27PlatoonUtilities.UpdateUnitNames({oUnit}, oUnit:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oUnit)..':ScoutingThenReturningToBase') end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': No valid final destination so will move to start unless already there') end
                if M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) > 20 then IssueMove({oUnit}, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) end
            end
        end
    end
end

function RecordThatCanSeeSegment(aiBrain, iAirSegmentX, iAirSegmentZ, iTimeStamp)
    aiBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiLastScouted] = iTimeStamp
    aiBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiDeadScoutsSinceLastReveal] = 0
    aiBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiCurrentScoutingInterval] = aiBrain[reftAirSegmentTracker][iAirSegmentX][iAirSegmentZ][refiNormalScoutingIntervalWanted]
end

function UpdateSegmentsForUnitVision(aiBrain, oUnit, iVisionRange, iTimeStamp)
    local tUnitPosition = oUnit:GetPosition()
    local iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(tUnitPosition)

    --Next update +/-1 (but not corners)
    local iBoxSize
    if iVisionRange <= iAirSegmentSize then iBoxSize = 0
    elseif iVisionRange <= iSegmentVisualThresholdBoxSize1 then iBoxSize = 1
    elseif iVisionRange <= iSegmentVisualThresholdBoxSize2 then iBoxSize = 2
    else iBoxSize = math.ceil((iVisionRange / iAirSegmentSize) - 1) end

    local iFirstX = math.max(iCurAirSegmentX - iBoxSize, 1)
    local iLastX = math.min(iCurAirSegmentX + iBoxSize, iMapMaxSegmentX)
    local iFirstZ = math.max(iCurAirSegmentZ - iBoxSize, 1)
    local iLastZ = math.min(iCurAirSegmentZ + iBoxSize, iMapMaxSegmentZ)

    for iX = iFirstX, iLastX, 1 do
        for iZ = iFirstZ, iLastZ, 1 do
            RecordThatCanSeeSegment(aiBrain, iX, iZ, iTimeStamp)
        end
    end
end

function RecordSegmentsThatHaveVisualOf(aiBrain)
    local sFunctionRef = 'RecordSegmentsThatHaveVisualOf'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local iTimeStamp = GetGameTimeSeconds()

    local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    local tAirScouts = aiBrain:GetUnitsAroundPoint(refCategoryAirScout * categories.TECH1, tStartPosition, aiBrain[refiMaxScoutRadius], 'Ally')
    local iAirVision = 42
    for iUnit, oUnit in tAirScouts do
        if not(oUnit.Dead) then
            UpdateSegmentsForUnitVision(aiBrain, oUnit, iAirVision, iTimeStamp)
        end
    end
    local tSpyPlanes = aiBrain:GetUnitsAroundPoint(refCategoryAirScout * categories.TECH3, tStartPosition, aiBrain[refiMaxScoutRadius], 'Ally')
    iAirVision = 64
    for iUnit, oUnit in tSpyPlanes do
        if not(oUnit.Dead) then
            UpdateSegmentsForUnitVision(aiBrain, oUnit, iAirVision, iTimeStamp)
        end
    end

    local tAllOtherUnits = aiBrain:GetUnitsAroundPoint(categories.ALLUNITS - refCategoryAirScout - M27UnitInfo.refCategoryMex - M27UnitInfo.refCategoryHydro, tStartPosition, aiBrain[refiMaxScoutRadius], 'Ally')
    local oCurBP, iCurVision
    for iUnit, oUnit in tAllOtherUnits do
        if not(oUnit.Dead) and oUnit.GetBlueprint then
            oCurBP = oUnit:GetBlueprint()
            iCurVision = oCurBP.Intel.VisionRadius
            if iCurVision and iCurVision >= iAirSegmentSize then
                UpdateSegmentsForUnitVision(aiBrain, oUnit, iCurVision, iTimeStamp)
            end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
end

function GetBomberTargetShortlist(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetBomberTargetShortlist'


    local tEnemyUnitsOfType
    local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    local iMaxSearchRange = aiBrain[refiMaxScoutRadius]
    local iTargetShortlistCount = 0
    local iMaxLifetimeAssignment = 3
    local bIncludeInShortlist

    local tEnemyGroundAA
    local iEnemyAASearchRange = 80
    local iFriendlyMexUnitSearchRange = 70
    local tUnitPosition
    local bProceed
    local bAAAroundTarget, iEnemyGroundAAThreat
    local bIgnoreMobileShield = false
    local reftPriorityTargetCategories = {M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryEnergyStorage, M27UnitInfo.refCategoryEngineer, M27UnitInfo.refCategoryPower, M27UnitInfo.refCategoryMex, M27UnitInfo.refCategoryGroundExperimental}
    local iTypeLowPriority = 4 --table number at which its a low priority (>= this)
    if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] >= 3 then
        bIgnoreMobileShield = true
        reftPriorityTargetCategories = {M27UnitInfo.refCategoryT2Mex, M27UnitInfo.refCategoryGroundExperimental, M27UnitInfo.refCategoryT3Mex, M27UnitInfo.refCategoryPower, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryEnergyStorage}
        iTypeLowPriority = 4
    elseif aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 2 then
        --Currently same as for a t3 bomber
        reftPriorityTargetCategories = {M27UnitInfo.refCategoryT2Mex, M27UnitInfo.refCategoryGroundExperimental, M27UnitInfo.refCategoryT3Mex, M27UnitInfo.refCategoryPower, M27UnitInfo.refCategoryRadar, M27UnitInfo.refCategoryEnergyStorage, M27UnitInfo.refCategoryEngineer}
        iTypeLowPriority = 4
    end


    aiBrain[reftBomberTargetShortlist] = {}

    if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through different types of categories with iMaxSearchRange='..iMaxSearchRange) end

    if bDebugMessages == true then
        LOG('tStartPosition='..repr(tStartPosition))
        local tIntelAndPower = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryRadar + categories.ENERGYPRODUCTION * categories.STRUCTURE, tStartPosition, 1000, 'Enemy')
        LOG('Size of tIntelAndPower='..table.getn(tIntelAndPower))
        local tRadar = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryRadar, tStartPosition, 1000, 'Enemy')
        LOG('Size of tRadar='..table.getn(tRadar))
        local tRectRadar = EntityCategoryFilterDown(M27UnitInfo.refCategoryRadar, GetUnitsInRect(Rect(0, 0, 1000, 1000)))
        LOG('Size of tRectRadar='..table.getn(tRectRadar))
    end

    for iTypeCount, iCategory in reftPriorityTargetCategories do
        bProceed = true
        if iTypeCount >= iTypeLowPriority then
            if iTargetShortlistCount > 0 then
                aiBrain[refbShortlistContainsLowPriorityTargets] = false
                bProceed = false
            else
                aiBrain[refbShortlistContainsLowPriorityTargets] = true
                bProceed = true
                local iCurX, iCurZ = GetAirSegmentFromPosition(M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
                if GetGameTimeSeconds() - aiBrain[reftAirSegmentTracker][iCurX][iCurZ][refiLastScouted] > 30 then bProceed = false end
            end
        end
        if bProceed == true then
            tEnemyUnitsOfType = aiBrain:GetUnitsAroundPoint(iCategory, tStartPosition, iMaxSearchRange, 'Enemy')
            if M27Utilities.IsTableEmpty(tEnemyUnitsOfType) == false then
                for iUnit, oUnit in tEnemyUnitsOfType do
                    if not(oUnit.Dead) and oUnit.GetPosition then
                        bIncludeInShortlist = false
                        if oUnit[refiCurBombersAssigned] == nil or oUnit[refiCurBombersAssigned] == 0 then
                            bIncludeInShortlist = true
                            if oUnit[refiLifetimeBombersAssigned] and oUnit[refiLifetimeBombersAssigned] >= iMaxLifetimeAssignment then bIncludeInShortlist = false end
                        end
                        if bIncludeInShortlist == true then
                            --Is there any ground AA around the target? If so ignore unless have T3
                            tUnitPosition = oUnit:GetPosition()
                            tEnemyGroundAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, tUnitPosition, iEnemyAASearchRange, 'Enemy')
                            if bDebugMessages == true then LOG(sFunctionRef..': iTypeCount='..iTypeCount..'; iUnit='..iUnit..'; size of tEnemyGroundAA='..table.getn(tEnemyGroundAA)..'; iEnemyAASearchRange='..iEnemyAASearchRange) end
                            if M27Utilities.IsTableEmpty(tEnemyGroundAA) == true then bAAAroundTarget = false
                            else
                                bAAAroundTarget = true
                                if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[M27Overseer.refiOurHighestAirFactoryTech]='..aiBrain[M27Overseer.refiOurHighestAirFactoryTech]..'; if this is >=3 then will ignore low level ground AA') end
                                if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] >= 3 then
                                    --Still include in shortlist if low level of AA/no AA that can easily counter a strat bomber
                                    --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride)
                                    local tEnemyT3OrCruiserGroundAA = EntityCategoryFilterDown(M27UnitInfo.refCategoryCruiserCarrier + categories.TECH3 * categories.ANTIAIR, tEnemyGroundAA)
                                    if M27Utilities.IsTableEmpty(tEnemyT3OrCruiserGroundAA) == true then
                                        if bDebugMessages == true then LOG(sFunctionRef..': T3 anti air not near target') end
                                        bAAAroundTarget = false
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': T3 anti air near target') end
                                    end
                                        --[[iEnemyGroundAAThreat = M27Logic.GetAirThreatLevel(aiBrain, tEnemyGroundAA, false, false, true, false, false)
                                        if bDebugMessages == true then LOG(sFunctionRef..': iEnemyGroundAAThreat='..iEnemyGroundAAThreat..'; if this is <700 then will ignore') end
                                        if iEnemyGroundAAThreat < 700 then bAAAroundTarget = false end --]]
                                end
                            end
                            if bAAAroundTarget == false then
                                --Is the target shielded?
                                if M27Logic.IsTargetUnderShield(aiBrain, oUnit, bIgnoreMobileShield) == false then
                                    --if iTypeCount == iTypeMex then
                                        --Do we already have direct or indirect fire units near this location? If so then ignore as good chance our units will kill it
                                        local tFriendlyUnitsNearMex = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, tUnitPosition, iFriendlyMexUnitSearchRange, 'Ally')
                                        if M27Utilities.IsTableEmpty(tFriendlyUnitsNearMex) == false then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Have units near target already') end
                                            bIncludeInShortlist = false
                                        end
                                    --end

                                    if bIncludeInShortlist == true then
                                        if bDebugMessages == true then LOG(sFunctionRef..': iTypeCount='..iTypeCount..'; iUnit='..iUnit..': Including in target shortlist') end
                                        iTargetShortlistCount = iTargetShortlistCount + 1
                                        aiBrain[reftBomberTargetShortlist][iTargetShortlistCount] = oUnit
                                    end
                                elseif bDebugMessages == true then LOG(sFunctionRef..': Target is under shield')
                                end
                            end
                        end
                    end
                    if iTargetShortlistCount > 0 and aiBrain[refbShortlistContainsLowPriorityTargets] then break end
                end
            end
        end

        if bDebugMessages == true then LOG(sFunctionRef..': end of loop for iTypeCount='..iTypeCount..'; iTargetShortlistCount='..iTargetShortlistCount) end
    end
end

function IssueLargeBomberAttack(aiBrain, tBombers)
    --Call via forkthread; will assign targets to tBombers until they're all dead
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IssueLargeBomberAttack'

    local iAliveBombers, iBombersNeedingTargets
    local bValidAttackPlatoon = true
    local refoTrackerUnit = 'TrackerUnit'
    local refiTrackerDistanceToEnemy = 'DistanceToEnemy'
    local tBombersNeedingTargetsTracker = {}

    if M27Utilities.IsTableEmpty(tBombers) == true then
        M27Utilities.ErrorHandler('Thought we had bombers to do a large attack but tBombers is empty')
    else

        local tCategoryGroupings = {M27UnitInfo.refCategoryStructureAA, M27UnitInfo.refCategoryMAA, M27UnitInfo.refCategoryPower, M27UnitInfo.refCategoryMex, categories.STRUCTURE, categories.COMMAND, categories.LAND}
        --local iMaxCategories = table.getn(tCategoryGroupings)
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
        --Flag that bombers will never be available again
        for iBomber, oBomber in tBombers do
            oBomber[refbPartOfLargeAttack] = true
        end

        local tEnemyBase = M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]

        local iCurLoop = 0
        local iMaxLoop = 100

        local tEnemyUnitsOfType, oNearestEnemyUnitOfType
        local tEnemyUnitsToTargetTracker, iEnemyUnitsToTarget
        tEnemyUnitsToTargetTracker = {}
        local tBomberCurPosition, oCurBomber, bHaveCurTarget, oCurTarget, iCurTargetRemainingHealth

        local iHealthFactorWanted --Change based on the category we're dealing with

        while bValidAttackPlatoon do
            --Update number of bombers that are alive and that need targets
            iCurLoop = iCurLoop + 1
            if iCurLoop >= iMaxLoop then M27Utilities.ErrorHandler('Infinite loop') break end
            iAliveBombers = 0
            iBombersNeedingTargets = 0
            tBombersNeedingTargetsTracker = {}
            if bDebugMessages == true then LOG(sFunctionRef..': iCurLoop='..iCurLoop..': About to cycle through all bombers and get nearest one to enemy base. Total bombers='..table.getn(tBombers)) end
            for iBomber, oBomber in tBombers do
                if not(oBomber.Dead) then
                    if bDebugMessages == true then
                        local sTarget = oBomber[refiCurTargetNumber]
                        if sTarget == nil then sTarget = 'nil' end
                        LOG(sFunctionRef..': iBomber='..iBomber..': Bomber isnt dead, Bomber CurTargetNumber='..sTarget)
                    end
                    iAliveBombers = iAliveBombers + 1
                    UpdateBomberTargets(oBomber) --Checks if target is dead
                    if oBomber[refiCurTargetNumber] == nil or oBomber[refiCurTargetNumber] == 0 then
                        if not(oBomber[refbWillBeRefueling]) then
                            iBombersNeedingTargets = iBombersNeedingTargets + 1
                            tBombersNeedingTargetsTracker[iBombersNeedingTargets] = {}
                            tBombersNeedingTargetsTracker[iBombersNeedingTargets][refoTrackerUnit] = oBomber
                            tBombersNeedingTargetsTracker[iBombersNeedingTargets][refiTrackerDistanceToEnemy] = M27Utilities.GetDistanceBetweenPositions(oBomber:GetPosition(), tEnemyBase)
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': iBomber='..iBomber..': Bomber already has a current target number='..oBomber[refiCurTargetNumber]) end
                    end
                end
            end

            --Determine what targets to assign, cycling through each bomber based on how close they are to enemy, and then determining the closest unit if the category being considered to the bomber that doesnt already have enough units assigned to it
            if bDebugMessages == true then LOG(sFunctionRef..': Finished going through bombers, iBombersNeedingTargets='..iBombersNeedingTargets) end
            if iBombersNeedingTargets > 0 then
                --Sort bombers based on distance to enemy start, so will start by assigning action to the nearest bomber to enemy start
                for iEntry, tSubvalue in M27Utilities.SortTableBySubtable(tBombersNeedingTargetsTracker, refiTrackerDistanceToEnemy, true) do
                    iCurLoop = 0
                    oCurBomber = tSubvalue[refoTrackerUnit]
                    tBomberCurPosition = oCurBomber:GetPosition()

                    --while iBombersNeedingTargets > 0 do
                        --iCurLoop = iCurLoop + 1
                        --if iCurLoop > iMaxLoop then M27Utilities.ErrorHandler('Infinite loop') end
                    bHaveCurTarget = false
                    for iCount, iCurCategoryCondition in tCategoryGroupings do
                        iHealthFactorWanted = 1.25
                        if iCurCategoryCondition == M27UnitInfo.refCategoryStructureAA or iCurCategoryCondition == M27UnitInfo.refCategoryMAA then iHealthFactorWanted = 1.5 end
                        tEnemyUnitsOfType = aiBrain:GetUnitsAroundPoint(iCurCategoryCondition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[refiMaxScoutRadius], 'Enemy')
                        if M27Utilities.IsTableEmpty(tEnemyUnitsOfType) == false then
                            iEnemyUnitsToTarget = 0
                            tEnemyUnitsToTargetTracker = {}

                            for iEnemyUnit, oEnemyUnit in tEnemyUnitsOfType do
                                if oEnemyUnit.GetPosition and not(oEnemyUnit.Dead) then
                                    iEnemyUnitsToTarget = iEnemyUnitsToTarget + 1
                                    tEnemyUnitsToTargetTracker[iEnemyUnitsToTarget] = {}
                                    tEnemyUnitsToTargetTracker[iEnemyUnitsToTarget][refoTrackerUnit] = oEnemyUnit
                                    tEnemyUnitsToTargetTracker[iEnemyUnitsToTarget][refiTrackerDistanceToEnemy] = M27Utilities.GetRoughDistanceBetweenPositions(oEnemyUnit:GetPosition(), tBomberCurPosition)
                                end

                            end
                            --Sort based on how close the enemy is
                            for iEntry2, tSubvalue2 in M27Utilities.SortTableBySubtable(tEnemyUnitsToTargetTracker, refiTrackerDistanceToEnemy, true) do
                                --Do we have enough alpha damage already assigned?
                                iCurTargetRemainingHealth = tSubvalue2[refoTrackerUnit]:GetHealth()
                                if tSubvalue2[refoTrackerUnit][refiStrikeDamageAssigned] == nil then
                                    bHaveCurTarget = true
                                elseif iCurTargetRemainingHealth * 1.25 > tSubvalue2[refoTrackerUnit][refiStrikeDamageAssigned] then --Want a bit of leeway incase bomber shot down or unit regens
                                    bHaveCurTarget = true
                                end
                                if bDebugMessages == true then
                                    local iStrikeDamageAssigned = tSubvalue2[refoTrackerUnit][refiStrikeDamageAssigned]
                                    if iStrikeDamageAssigned == nil then iStrikeDamageAssigned = 'nil' end
                                    LOG(sFunctionRef..': Cycling through enemy units that bomer can target, iEntry (i.e. bomber)='..iEntry..'; iCategoryCount='..iCount..'; iEntry2='..iEntry2..'; iCurTargetRemainingHealth='..iCurTargetRemainingHealth..'; iStrikeDamageAssigned='..iStrikeDamageAssigned)
                                end
                                if bHaveCurTarget == true then
                                    oCurTarget = tSubvalue2[refoTrackerUnit]
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have oCurTarget='..oCurTarget:GetUnitId()) end
                                    break
                                end
                            end

                            if bHaveCurTarget == true then break end
                        end
                    end
                    if bHaveCurTarget == true then
                        if oCurTarget == nil then M27Utilities.ErrorHandler('Have a nil CurTarget for large attack bomber')
                        else
                            TrackBomberTarget(oCurBomber, oCurTarget)
                            IssueAttack({oCurBomber}, oCurTarget)
                            iBombersNeedingTargets = iBombersNeedingTargets - 1
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Dont have a current target for bomber') end
                    end
                    --end
                end
            else bValidAttackPlatoon = false
            end

            if iAliveBombers == 0 then
                bValidAttackPlatoon = false
                break
            end
            WaitTicks(10)
        end
    end
end

function AirBomberManager(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AirBomberManager'
    local iMaxJourneyDistanceForBomber = aiBrain[refiMaxScoutRadius] --Dont want a single bomber to have queued up actions which will make it go more than this
    local iMaxTargetsForBomber = 4 --Dont want a bomber to have more than this queued as likely it will die so we want other bombers to try and target beyond this number
    if aiBrain[refbShortlistContainsLowPriorityTargets] == true then iMaxTargetsForBomber = 1 end --Dont want to issue low priority targets unless bomber is idle
    local iSpareBombers = -1
    if M27Utilities.IsTableEmpty(aiBrain[reftAvailableBombers]) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': have available bombers, total number='..table.getn(aiBrain[reftAvailableBombers])) end
        --Record bomber target list
        GetBomberTargetShortlist(aiBrain)
        --Do we have any targets?
        local tBomberLastTarget
        local iBomberRemainingTargetCount
        local iCurLoopCount
        local iMaxLoopCount = iMaxTargetsForBomber + 1
        local iUnassignedTargets
        local tPersonalisedShortlist = {}
        local refoTarget = 'M27ShortlistTargetUnit'
        local refiDistanceFromBomber = 'M27ShortlistDistanceFromBomber'
        local iPersonalShortlistCount, oCurNavigator
        local tNewTargetPosition, oNewTarget
        local oClosestNewTarget, iClosestNewTargetDistance, iNewTargetDistance, iClosestTargetShortlistKey
        local tClosestNewTargetPos = {}
        local oBomberCurTarget
        local bBomberHasDeadOrShieldedTarget


        --Assign any bomber targets to any available bombers
        if M27Utilities.IsTableEmpty(aiBrain[reftBomberTargetShortlist]) == false then
            iUnassignedTargets = table.getn(aiBrain[reftBomberTargetShortlist])
            for iAvailableBomberCount, oBomber in aiBrain[reftAvailableBombers] do

                --Get the bomber's current target (so can use this position to determine the closest target to add to it)
                UpdateBomberTargets(oBomber)
                if iUnassignedTargets == 0 then
                    if oBomber[refiCurTargetNumber] == nil or oBomber[refiCurTargetNumber] == 0 then
                        --Bomber has no current target, make sure it's near base if its not already
                        IssueMove({oBomber}, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                        if M27Config.M27ShowUnitNames == true and oBomber.GetUnitId then M27PlatoonUtilities.UpdateUnitNames({oBomber}, oBomber:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oBomber)..':NoTargetReturnToBase') end
                    end
                else
                    if oBomber[refiCurTargetNumber] == nil or oBomber[refiCurTargetNumber] == 0 then
                        iBomberRemainingTargetCount = 0
                        tBomberLastTarget = oBomber:GetPosition()
                        IssueClearCommands({oBomber})
                        oBomber[reftTargetList] = {}
                        if M27Config.M27ShowUnitNames == true and oBomber.GetUnitId then M27PlatoonUtilities.UpdateUnitNames({oBomber}, oBomber:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oBomber)..':Cleared') end
                        if bDebugMessages == true then LOG(sFunctionRef..': Clearing bomber commands') end
                    else
                        iBomberRemainingTargetCount = table.getn(oBomber[reftTargetList]) - oBomber[refiCurTargetNumber] + 1
                        if oBomber.GetNavigator == nil then
                            M27Utilities.ErrorHandler('Bomber has a target but no navigator - investigate - will return bomber cur pos instead')
                            tBomberLastTarget = oBomber:GetPosition()
                        else
                            oCurNavigator = oBomber:GetNavigator()
                            if oCurNavigator.GetGoalPos then
                                tBomberLastTarget = oCurNavigator:GetGoalPos()
                            else
                                tBomberLastTarget = oCurNavigator:GetCurrentTargetPos()
                            end
                        end
                    end
                    iCurLoopCount = 0
                    while iBomberRemainingTargetCount < iMaxTargetsForBomber do
                        iCurLoopCount = iCurLoopCount + 1
                        if iCurLoopCount >= iMaxLoopCount then M27Utilities.ErrorHandler('Infinite loop, will abort') break end
                        if iUnassignedTargets > 0 then
                            --Get the closest target from the shortlist
                            iClosestNewTargetDistance = 10000

                            for iTarget, oTarget in aiBrain[reftBomberTargetShortlist] do
                                tNewTargetPosition = oTarget:GetPosition()
                                iNewTargetDistance = M27Utilities.GetDistanceBetweenPositions(tNewTargetPosition, tBomberLastTarget)
                                if iNewTargetDistance < iClosestNewTargetDistance then
                                    iClosestNewTargetDistance = iNewTargetDistance
                                    oClosestNewTarget = oTarget
                                    tClosestNewTargetPos[1] = tNewTargetPosition[1]
                                    tClosestNewTargetPos[2] = tNewTargetPosition[2]
                                    tClosestNewTargetPos[3] = tNewTargetPosition[3]
                                    iClosestTargetShortlistKey = iTarget
                                end
                            end

                            --Update the shortlist and bomber targeting
                            TrackBomberTarget(oBomber, oClosestNewTarget) --Updates the targetted unit with various trackers
                            table.remove(aiBrain[reftBomberTargetShortlist], iClosestTargetShortlistKey)
                            IssueAttack({oBomber}, oClosestNewTarget)
                            if bDebugMessages == true then LOG(sFunctionRef..': Size of bomber target list='..table.getn(oBomber[reftTargetList])..'; iCurTargetNumber='..oBomber[refiCurTargetNumber]..': Issued attack order for target with position='..repr(tClosestNewTargetPos)..' and unitId='..oClosestNewTarget:GetUnitId()) end
                            iUnassignedTargets = iUnassignedTargets - 1
                            iBomberRemainingTargetCount = iBomberRemainingTargetCount + 1
                            tBomberLastTarget = tClosestNewTargetPos
                            if iBomberRemainingTargetCount == iMaxTargetsForBomber then oBomber[refbOnAssignment] = true end

                            if iUnassignedTargets == 0 then break end
                        end
                    end
                    if iUnassignedTargets == 0 then
                        iSpareBombers = math.max(1, table.getn(aiBrain[reftAvailableBombers]) - iAvailableBomberCount + 1)
                    end
                end
            end
            if iUnassignedTargets > 0 then iSpareBombers = -math.max(1, math.ceil(iUnassignedTargets / iMaxTargetsForBomber)) end
        else
            iSpareBombers = table.getn(aiBrain[reftAvailableBombers])
        end
    else
        if M27Utilities.IsTableEmpty(aiBrain[reftBomberTargetShortlist]) == false then
            iSpareBombers = -math.max(1, math.ceil(table.getn(aiBrain[reftBomberTargetShortlist]) / iMaxTargetsForBomber))
        else
            iSpareBombers = -1
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': iSpareBombers='..iSpareBombers..'; aiBrain[refiLargeBomberAttackThreshold]='..aiBrain[refiLargeBomberAttackThreshold]) end
    if iSpareBombers and iSpareBombers < 0 then aiBrain[refiBombersWanted] = -iSpareBombers
    else
        aiBrain[refiBombersWanted] = 0
        if iSpareBombers >= aiBrain[refiLargeBomberAttackThreshold] then
            --Get the number of completely unassigned bombers
            local iIdleBomberCount = 0
            local tIdleBombers = {}
            for iBomber, oBomber in aiBrain[reftAvailableBombers] do
                if oBomber[refiCurTargetNumber] == nil or oBomber[refiCurTargetNumber] == 0 then
                    iIdleBomberCount = iIdleBomberCount + 1
                    tIdleBombers[iIdleBomberCount] = oBomber
                end
                if bDebugMessages == true then LOG(sFunctionRef..': iIdleBomberCount='..iIdleBomberCount) end
                if iIdleBomberCount >= aiBrain[refiLargeBomberAttackThreshold] then
                    ForkThread(IssueLargeBomberAttack, aiBrain, tIdleBombers)
                    aiBrain[refiLargeBomberAttackThreshold] = aiBrain[refiLargeBomberAttackThreshold] * 1.5
                end
            end
        end
    end

end

function AirAAManager(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AirAAManager'
    local iNearToACUThreshold = 80
    local iMAANearACURange = 40
    local iEnemyGroundAASearchRange = 90
    local iAssistNearbyUnitRange = 30 --if spot an enemy air unit, will intercept it if we have friendly non-air units within this range of it
    --Does ACU have MAA near it?
    local tACUPos = M27Utilities.GetACU(aiBrain):GetPosition()
    local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    local tNearbyMAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, tACUPos, iMAANearACURange, 'Ally')
    if M27Utilities.IsTableEmpty(tNearbyMAA) == false then iNearToACUThreshold = 0 end

    local tEnemyAirUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryAllAir, tStartPosition, aiBrain[refiMaxScoutRadius], 'Enemy')

    local iDistanceAway

    local iAirThreatShortfall = 0
    if M27Utilities.IsTableEmpty(tEnemyAirUnits) == false then

        local iDistanceFromACUToStart = 0
        if iNearToACUThreshold > 0 then iDistanceFromACUToStart = M27Utilities.GetDistanceBetweenPositions(tStartPosition, tACUPos) end
        local tEnemyStartPosition = M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)]
        local iDistanceFromEnemyStartToOurStart = M27Utilities.GetDistanceBetweenPositions(tStartPosition, tEnemyStartPosition)
        local iMapMidpointDistance = iDistanceFromEnemyStartToOurStart * 0.5

        local tValidEnemyAirThreats = {}
        local refoUnit = 'AirAAUnit'
        local refiDistance = 'AirAADistance'
        local iEnemyUnitCount = 0
        local tUnitCurPosition
        local iDistanceToACU

        local iCurTargetModDistanceFromStart
        local bShouldAttackThreat
        local iDefenceCoverage = aiBrain[M27Overseer.refiNearestOutstandingThreat]
        local iCurDistanceToStart
        local tEnemyGroundAA
        local bCloseEnoughToConsider
        local tFriendlyGroundUnits

        if bDebugMessages == true then LOG(sFunctionRef..': total enemy threats='..table.getn(tEnemyAirUnits)..'; total vailable inties='..table.getn(aiBrain[reftAvailableAirAA])) end

        --Create a table with all air threats and their distance
        for iUnit, oUnit in tEnemyAirUnits do
            bShouldAttackThreat = false
            if not(oUnit.Dead) and oUnit.GetUnitId then
                bCloseEnoughToConsider = false
                tUnitCurPosition = oUnit:GetPosition()
                iCurDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tStartPosition, tUnitCurPosition)
                if iDistanceFromACUToStart > 0 then
                    if iCurDistanceToStart > iDistanceFromACUToStart then
                        iDistanceToACU = M27Utilities.GetDistanceBetweenPositions(tACUPos, tUnitCurPosition)
                        if iDistanceToACU <= iNearToACUThreshold then
                            iCurDistanceToStart = math.min(iCurDistanceToStart, iDistanceToACU)
                        end
                    end
                end
                iCurTargetModDistanceFromStart = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tUnitCurPosition)
                if iCurDistanceToStart <= iNearToACUThreshold then bShouldAttackThreat = true
                else
                    if iCurDistanceToStart <= iMapMidpointDistance then bCloseEnoughToConsider = true
                    else
                        --Are we in defence coverage?
                        if bDebugMessages == true then LOG(sFunctionRef..': Target unit='..oUnit:GetUnitId()..'; iCurTargetModDistanceFromStart='..iCurTargetModDistanceFromStart..'; iDefenceCoverage='..iDefenceCoverage) end
                        if iCurTargetModDistanceFromStart <= iDefenceCoverage then
                            bCloseEnoughToConsider = true
                        else
                            --Do we have nearby ground units (that we'll want to protect)?
                            tFriendlyGroundUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE + categories.LAND + categories.NAVAL, tUnitCurPosition, iAssistNearbyUnitRange, 'Ally')
                            if M27Utilities.IsTableEmpty(tFriendlyGroundUnits) == false then bCloseEnoughToConsider = true end
                        end
                    end
                    if bCloseEnoughToConsider == true then
                        --Check if ground AA near the target
                        tEnemyGroundAA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA, tUnitCurPosition, iEnemyGroundAASearchRange, 'Enemy')
                        if M27Utilities.IsTableEmpty(tEnemyGroundAA) == true then
                            bShouldAttackThreat = true
                        end
                    end
                end
                if bShouldAttackThreat == true then
                    iEnemyUnitCount = iEnemyUnitCount + 1
                    tValidEnemyAirThreats[iEnemyUnitCount] = {}
                    tValidEnemyAirThreats[iEnemyUnitCount][refoUnit] = oUnit
                    tValidEnemyAirThreats[iEnemyUnitCount][refiDistance] = iCurTargetModDistanceFromStart
                    if bDebugMessages == true then LOG(sFunctionRef..': Air threat that we should attack, recording in tValidEnemyAirThreats, iEnemyUnitCount='..iEnemyUnitCount) end
                end
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
            for iUnit, tSubtable in M27Utilities.SortTableBySubtable(tValidEnemyAirThreats, refiDistance, true) do

                --Get mass threat
                --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride)

                oCurTarget = tSubtable[refoUnit]
                tCurUnitPos = oCurTarget:GetPosition()
                iOriginalMassThreat = M27Logic.GetAirThreatLevel(aiBrain, {oCurTarget}, true, true, false, true, true)
                --Update details of units already assigned to the unit
                iRemainingMassThreat = iOriginalMassThreat * 3
                iAlreadyAssignedMassValue = 0
                if M27Utilities.IsTableEmpty(oCurTarget[reftTargetedByList]) == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through reftTargetedByList, table size='..table.getn(oCurTarget[reftTargetedByList])) end
                    for iExistingAirAA, oExistingAirAA in oCurTarget[reftTargetedByList] do
                        if oExistingAirAA.GetUnitId then
                            iAlreadyAssignedMassValue = iAlreadyAssignedMassValue + M27Logic.GetAirThreatLevel(aiBrain, {oExistingAirAA}, false, true, false, false, false)
                        end
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': oCurTargetId='..oCurTarget:GetUnitId()..'; iOriginalMassThreat='..iOriginalMassThreat..'; iRemainingMassThreat pre assigned value='..iRemainingMassThreat..'; iAlreadyAssignedMassValue='..iAlreadyAssignedMassValue) end

                iRemainingMassThreat = iRemainingMassThreat - iAlreadyAssignedMassValue


                iClosestAirAADistance = 10000


                local iCurLoopCount = 0
                local iMaxLoopCount = 50
                local iMaxAirAA = 50 --Will stop cycling through after this many (performance reasons)

                if bDebugMessages == true then LOG(sFunctionRef..': About to look for inties to attack; Target Unit Id='..oCurTarget:GetUnitId()..'; original mass threat='..iOriginalMassThreat..'; iAlreadyAssignedMassValue='..iAlreadyAssignedMassValue..'; iRemainingMassThreat='..iRemainingMassThreat..'; size of availableAA='..table.getn(aiBrain[reftAvailableAirAA])) end
                while iRemainingMassThreat > 0 and bAbortAsNoMoreAirAA == false do
                    if iCurLoopCount > iMaxLoopCount then
                        if iOriginalMassThreat <= 5000 then M27Utilities.ErrorHandler('Infinite loop; threat mass threat='..iOriginalMassThreat) end
                        break
                    end

                    iClosestAirAADistance = 10000
                    oClosestAirAA = nil
                    if bDebugMessages == true then LOG(sFunctionRef..': About to look for inties to attack, iRemainingMassThreat='..iRemainingMassThreat..'; size of availableAA='..table.getn(aiBrain[reftAvailableAirAA])) end
                    iCurLoopCount = iCurLoopCount + 1


                    for iAirAA, oAirAA in aiBrain[reftAvailableAirAA] do
                        if iAirAA > iMaxAirAA then
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering more AA than want to this cycle so aborting') end
                            bAbortAsNoMoreAirAA = true
                            break
                        end

                        iCurAirAADistance = M27Utilities.GetDistanceBetweenPositions(oAirAA:GetPosition(), tCurUnitPos)
                        if iCurAirAADistance < iClosestAirAADistance then
                            iClosestAirAADistance = iCurAirAADistance
                            oClosestAirAA = oAirAA
                            iClosestAirAARef = iAirAA
                        end
                    end
                    if oClosestAirAA then
                        if bDebugMessages == true then
                            local iLifetimeCount = M27UnitInfo.GetUnitLifetimeCount(oClosestAirAA)
                            if iLifetimeCount == nil then iLifetimeCount = 'nil' end
                            LOG(sFunctionRef..': Clearing commands for closest airAA, ClosestAirAA='..oClosestAirAA:GetUnitId()..'; Unique ID='..iLifetimeCount..'; iClosestAirAARef='..iClosestAirAARef..'ClosestAA Pos='..repr(oClosestAirAA:GetPosition()))
                        end
                        IssueClearCommands({oClosestAirAA})
                        IssueAttack({oClosestAirAA}, oCurTarget)
                        IssueAggressiveMove({oClosestAirAA}, tStartPosition)
                        if M27Config.M27ShowUnitNames == true and oClosestAirAA.GetUnitId then M27PlatoonUtilities.UpdateUnitNames({oClosestAirAA}, oClosestAirAA:GetUnitId()..M27UnitInfo.GetUnitLifetimeCount(oClosestAirAA)..':IntereceptAir') end
                        oClosestAirAA[refbOnAssignment] = true
                        oClosestAirAA[refoAirAATarget] = oCurTarget
                        if oCurTarget[reftTargetedByList] == nil then oCurTarget[reftTargetedByList] = {} end
                        table.insert(oCurTarget[reftTargetedByList], 1, oClosestAirAA)
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': about to cycle through available AA noting their lifetime count before removing cur entry')
                            for iAA, oAA in aiBrain[reftAvailableAirAA] do
                                LOG('iAA='..iAA..'; Lifetime count='..M27UnitInfo.GetUnitLifetimeCount(oAA))
                            end
                        end
                        table.remove(aiBrain[reftAvailableAirAA], iClosestAirAARef)
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Finished removing iClosestAirAARef='..iClosestAirAARef..'; about to cycle through available AA noting their lifetime count')
                            for iAA, oAA in aiBrain[reftAvailableAirAA] do
                                LOG('iAA='..iAA..'; Lifetime count='..M27UnitInfo.GetUnitLifetimeCount(oAA))
                            end
                        end
                        if M27Utilities.IsTableEmpty(aiBrain[reftAvailableAirAA]) == true then
                            if bDebugMessages == true then LOG(sFunctionRef..': No longer have any availalbe AA so aborting loop') end
                            bAbortAsNoMoreAirAA = true
                            break
                        else
                            --GetAirThreatLevel(aiBrain, tUnits, bMustBeVisibleToIntelOrSight, bIncludeAirToAir, bIncludeGroundToAir, bIncludeAirToGround, bIncludeNonCombatAir, iAirBlipThreatOverride, iMobileLandBlipThreatOverride, iNavyBlipThreatOverride, iStructureBlipThreatOverride)
                            iRemainingMassThreat = iRemainingMassThreat - M27Logic.GetAirThreatLevel(aiBrain, {oClosestAirAA}, false, true, false, false, false)
                        end
                    else
                        bAbortAsNoMoreAirAA = true
                        if M27Utilities.IsTableEmpty(aiBrain[reftAvailableAirAA]) == false then
                            M27Utilities.ErrorHandler('oClosestAirAA is blank despite having AA nearby, size of availableairAA='..table.getn(aiBrain[reftAvailableAirAA]))
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': No airAA available any more') end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': iRemainingMassThreat='..iRemainingMassThreat..'; bAbortAsNoMoreAirAA='..tostring(bAbortAsNoMoreAirAA)) end
                    if bAbortAsNoMoreAirAA == true then
                        break
                    end
                end
                if bAbortAsNoMoreAirAA == true then iAirThreatShortfall = iAirThreatShortfall + iRemainingMassThreat end
            end
            local iAirAACountWanted
            local iExpectedThreatPerCount = 50
            if aiBrain[M27Overseer.refiOurHighestAirFactoryTech] >= 3 then iExpectedThreatPerCount = 350 end
            if iAirThreatShortfall > 0 then
                aiBrain[refiAirAANeeded] = math.max(5, math.ceil(iAirThreatShortfall / iExpectedThreatPerCount))
                if bDebugMessages == true then LOG(sFunctionRef..': End of calculating threat required; iAirThreatShortfall='..iAirThreatShortfall..'; iExpectedThreatPerCount='..iExpectedThreatPerCount..'; aiBrain[refiAirAANeeded]='..aiBrain[refiAirAANeeded]) end
            else
                aiBrain[refiAirAANeeded] = 0
                if bDebugMessages == true then LOG(sFunctionRef..': iAirThreatShortfall is 0 so airAA needed is 0') end
            end
        else
            aiBrain[refiAirAANeeded] = 2
            if bDebugMessages == true then LOG(sFunctionRef..': Have no inties, will flag we need more AirAA if any enemy air threats are detected; aiBrain[refiAirAANeeded]='..tostring(aiBrain[refiAirAANeeded])) end
        end
    end
end



function AirLogicOverseer(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AirLogicOverseer'
    local bProfiling = false
    local iProfileStartTime = 0

    local iCycleCount = 0
    local iLongCycleThreshold = 4

    if bProfiling == true then iProfileStartTime = M27Utilities.ProfilerTimeSinceLastCall(sFunctionRef..': Pre start of while loop', iProfileStartTime) end

    while(not(aiBrain:IsDefeated())) do
        if bProfiling == true then iProfileStartTime = M27Utilities.ProfilerTimeSinceLastCall(sFunctionRef..': Start of loop', iProfileStartTime) end

        if bDebugMessages == true then LOG(sFunctionRef..': iCycleCount='..iCycleCount..': GameTime='..GetGameTimeSeconds()) end
        RecordSegmentsThatHaveVisualOf(aiBrain)
        RecordAvailableAndLowFuelAirUnits(aiBrain)
        if bDebugMessages == true then
            LOG(sFunctionRef..': about to show how many available bombers we have')
            if aiBrain[reftAvailableBombers] then LOG('Size of table='..table.getn(aiBrain[reftAvailableBombers])) end
        end
        ForkThread(AirThreatChecker,aiBrain)
        ForkThread(AirScoutManager,aiBrain)
        ForkThread(AirBomberManager,aiBrain)
        ForkThread(AirAAManager,aiBrain)

        iCycleCount = iCycleCount + 1
        if iCycleCount == iLongCycleThreshold then
            iCycleCount = 0
            if M27Utilities.IsTableEmpty(aiBrain[reftLowFuelAir]) == false then
                if bDebugMessages == true then LOG(sFunctionRef..': Have some scouts with low fuel so about to call function to tell them to refuel') end
                ForkThread(OrderUnitsToRefuel, aiBrain, aiBrain[reftLowFuelAir])
            end

            ForkThread(ReleaseRefueledUnits, aiBrain)
        elseif iCycleCount == (iLongCycleThreshold - 1) then
            ForkThread(RefuelIdleAirUnits, aiBrain)
        end

        if bProfiling == true then iProfileStartTime = M27Utilities.ProfilerTimeSinceLastCall(sFunctionRef..': End of loop', iProfileStartTime) end
        WaitTicks(10)
    end
end


function Initialise()  end --Done so can find air overseer setup more easily
function SetupAirOverseer(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'SetupAirOverseer'
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    --Sets default/starting values for everything so dont have to worry about checking if is nil or not
    aiBrain[refiExtraAirScoutsWanted] = 0
    aiBrain[refiAirStagingWanted] = 0
    aiBrain[refiTorpBombersWanted] = 0
    aiBrain[refiAirAANeeded] = 0
    aiBrain[refiAirAAWanted] = 1
    aiBrain[refiBombersWanted] = 1

    aiBrain[refbBombersAreEffective] = {}
    for iTech = 1, 4 do
        aiBrain[refbBombersAreEffective][iTech] = true
    end


    --Air scouts have visual of 42, so want to divide map into segments of size 20

    iAirSegmentSize = 20
    iSegmentVisualThresholdBoxSize1 = iAirSegmentSize * 2
    iSegmentVisualThresholdBoxSize2 = iAirSegmentSize * 3

    aiBrain[refiIntervalLowestPriority] = 300
    aiBrain[refiIntervalHighestPriority] = 30
    aiBrain[refiIntervalMexNotBuiltOn] = 100
    aiBrain[refiIntervaPriorityMex] = 60
    aiBrain[refiIntervalEnemyMex] = 120
    aiBrain[refiIntervalEnemyBase] = 90

    aiBrain[reftAirSegmentTracker] = {}
    aiBrain[reftScoutingTargetShortlist] = {}

    aiBrain[refiLargeBomberAttackThreshold] = 10 --Default

    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
    local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]

    if iMapMaxSegmentX == nil then --Only need to do once if have multiple brains
        iMapMaxSegmentX = math.ceil(iMapSizeX / iAirSegmentSize)
        iMapMaxSegmentZ = math.ceil(iMapSizeZ / iAirSegmentSize)
    end

    iMinScoutsForMap = math.min(12, math.ceil(iMapSizeX * iMapSizeZ / (250 * 250)) * 0.75)
    iMaxScoutsForMap = iMinScoutsForMap * 3

    if bDebugMessages == true then LOG(sFunctionRef..': iMapMaxSegmentX='..iMapMaxSegmentX..'; iMapMaxSegmentZ='..iMapMaxSegmentZ..'; rPlayableArea='..repr(rPlayableArea)..'; iAirSegmentSize='..iAirSegmentSize) end
    --For large maps want to limit the segments that we consider
    local iDistanceToEnemyFromStart = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.PlayerStartPoints[M27Logic.GetNearestEnemyStartNumber(aiBrain)])
    aiBrain[refiMaxScoutRadius] = math.max(1250, iDistanceToEnemyFromStart * 1.5)
    local iStartSegmentX, iStartSegmentZ = GetAirSegmentFromPosition(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
    local iSegmentSizeX = iMapSizeX / iAirSegmentSize
    local iSegmentSizeZ = iMapSizeZ / iAirSegmentSize
    local iMaxSegmentDistanceFromStartX = math.ceil(aiBrain[refiMaxScoutRadius] / iSegmentSizeX)
    local iMaxSegmentDistanceFromStartZ = math.ceil(aiBrain[refiMaxScoutRadius] / iSegmentSizeZ)

    aiBrain[refiMaxSegmentX] = math.min(iMapMaxSegmentX, iStartSegmentX + iMaxSegmentDistanceFromStartX)
    aiBrain[refiMaxSegmentZ] = math.min(iMapMaxSegmentZ, iStartSegmentZ + iMaxSegmentDistanceFromStartZ)
    aiBrain[refiMinSegmentX] = math.max(1, iStartSegmentX - iMaxSegmentDistanceFromStartX)
    aiBrain[refiMinSegmentZ] = math.max(1, iStartSegmentZ - iMaxSegmentDistanceFromStartZ)


    --Default values for each segment:
    if bDebugMessages == true then LOG(sFunctionRef..': Recording segments for iMapMaxSegmentX='..iMapMaxSegmentX..' iMapMaxSegmentZ='..iMapMaxSegmentZ) end
    for iCurX = 1, iMapMaxSegmentX do
        aiBrain[reftAirSegmentTracker][iCurX] = {}
        for iCurZ = 1, iMapMaxSegmentZ do
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
    local iOurArmyIndex = aiBrain:GetArmyIndex()
    local iEnemyArmyIndex, tEnemyStartPosition
    local iCurAirSegmentX, iCurAirSegmentZ
    for iCurBrain, oBrain in ArmyBrains do
        if not(oBrain == aiBrain) then
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
        LOG(sFunctionRef..': air units wanted: aiBrain[refiExtraAirScoutsWanted]='..aiBrain[refiExtraAirScoutsWanted]..'; aiBrain[refiAirStagingWanted]='..aiBrain[refiAirStagingWanted]..'; aiBrain[refiTorpBombersWanted]='..aiBrain[refiTorpBombersWanted]..'; aiBrain[refiAirAANeeded]='..aiBrain[refiAirAANeeded])
        LOG(sFunctionRef..': End of code pre wait ticks and calling of air logic overseer fork thread')
    end
    WaitTicks(100)
    ForkThread(AirLogicOverseer, aiBrain)
end

--Decide on mex targets and update air scouting for these
function UpdateMexScoutingPriorities(aiBrain)
    --called from strategic overseer
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateMexScoutingPriorities'

    if bDebugMessages == true then LOG(sFunctionRef..': Start') end
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
        if bDebugMessages == true then LOG(sFunctionRef..': Sorted mex count='..table.getn(aiBrain[M27MapInfo.reftSortedMexesInOriginalGroup])..'; full list of sorted mex locations='..repr(aiBrain[M27MapInfo.reftSortedMexesInOriginalGroup])) end


        --Make mexes near enemy high priority if we need actions
        local bAlsoConsiderMexesNearerEnemyBase = false
        local sPathing, iMinDistanceFromEnemy, iMaxDistanceFromEnemy, iPathingGroup
        local bConsiderIfWeShouldConsiderOtherMexes = false
        if M27Utilities.IsTableEmpty(aiBrain[reftBomberTargetShortlist]) == true and M27Utilities.IsTableEmpty(aiBrain[reftAvailableBombers]) == false then bConsiderIfWeShouldConsiderOtherMexes = true
        elseif M27Utilities.IsTableEmpty(aiBrain[reftAvailableBombers]) == false and aiBrain[reftAvailableBombers][1] and aiBrain[reftAvailableBombers][1]['M27LifetimeUnitCount'] and aiBrain[reftAvailableBombers][1]['M27LifetimeUnitCount'] == 1 then bConsiderIfWeShouldConsiderOtherMexes = true end

        if bConsiderIfWeShouldConsiderOtherMexes == true then
            --RecordMexesInPathingGroupFilteredByEnemyDistance(aiBrain, sPathing, iPathingGroup, iMinDistanceFromEnemy, iMaxDistanceFromEnemy)
            sPathing = M27UnitInfo.refPathingTypeAmphibious
            iMinDistanceFromEnemy = 50
            iMaxDistanceFromEnemy = 300
            iPathingGroup = aiBrain[M27MapInfo.refiStartingSegmentGroup][sPathing]
            M27MapInfo.RecordMexesInPathingGroupFilteredByEnemyDistance(aiBrain, sPathing, iPathingGroup, iMinDistanceFromEnemy, iMaxDistanceFromEnemy)
            if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup][iMinDistanceFromEnemy][iMaxDistanceFromEnemy]) == false then bAlsoConsiderMexesNearerEnemyBase = true end
        end

        local tMexesToCycleThrough
        local iTablesToCycleThrough = 1
        if bAlsoConsiderMexesNearerEnemyBase == true then iTablesToCycleThrough = iTablesToCycleThrough + 1 end

        local iMaxHighPriorityTargets = 3
        for iCurTable = 1, iTablesToCycleThrough do
            if iTablesToCycleThrough == 1 then
                tMexesToCycleThrough = aiBrain[M27MapInfo.reftSortedMexesInOriginalGroup]
                iMaxHighPriorityTargets = math.max(3, table.getn(aiBrain[M27MapInfo.reftSortedMexesInOriginalGroup]) * 0.2)
            elseif iTablesToCycleThrough == 2 then
                tMexesToCycleThrough = aiBrain[M27MapInfo.reftMexesInPathingGroupFilteredByDistanceToEnemy][sPathing][iPathingGroup][iMinDistanceFromEnemy][iMaxDistanceFromEnemy]
                iMaxHighPriorityTargets = math.max(20, iMaxHighPriorityTargets)
            else M27Utilities.ErrorHandler('Not added code for more tables') end

            for iMex, tMexLocation in tMexesToCycleThrough do
                iCurAirSegmentX, iCurAirSegmentZ = GetAirSegmentFromPosition(tMexLocation)
                iPriorityValue = nil
                --IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatAllyMexAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
                if M27Conditions.IsMexUnclaimed(aiBrain, tMexLocation, true, false, false) == true then
                    iPriorityCount = iPriorityCount + 1
                    if bDebugMessages == true then LOG(sFunctionRef..': Mex location is either unclaimed or has enemy mex on it, location='..repr(tMexLocation)..'; iPriorityCount='..iPriorityCount) end
                    if iPriorityCount <= iMaxHighPriorityTargets then
                        iPriorityValue = aiBrain[refiIntervaPriorityMex]
                        aiBrain[M27MapInfo.reftHighPriorityMexes][iPriorityCount] = tMexLocation
                    else
                        iPriorityValue = aiBrain[refiIntervalEnemyMex]
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Mex location is already built on by us or queued, location='..repr(tMexLocation)) end
                    --Only update if not already updated this segment (as if already updated it mightve been for a high priority)
                    if aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastTimeScoutingIntervalChanged] < iGameTime then
                        --Do we own the mex? We already know that the mex is claimed if considering our buildings+queued buildings, so now just want to consider if its unclaimed when ignoring queued buildings
                        if M27Conditions.IsMexUnclaimed(aiBrain, tMexLocation, false, false, true) == true then
                            --Mex is not built on (might be queued though)
                            iPriorityValue = aiBrain[refiIntervalMexNotBuiltOn]
                        else --Mex is built on by us/ally so we already have small visual range of it, so low priority
                            iPriorityValue = aiBrain[refiIntervalLowestPriority]
                        end
                    end
                end
                if not(iPriorityValue == nil) then
                    aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiNormalScoutingIntervalWanted] = iPriorityValue
                    if aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval] > iPriorityValue then aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiCurrentScoutingInterval] = iPriorityValue end
                    aiBrain[reftAirSegmentTracker][iCurAirSegmentX][iCurAirSegmentZ][refiLastTimeScoutingIntervalChanged] = iGameTime
                end
            end
        end


        if bDebugMessages == true then
            LOG(sFunctionRef..': End: Number of high priority mexes='..table.getn(aiBrain[M27MapInfo.reftHighPriorityMexes]))
            M27Utilities.DrawLocations(aiBrain[M27MapInfo.reftHighPriorityMexes])
        end
    end
end
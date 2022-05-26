local M27Config = import('/mods/M27AI/lua/M27Config.lua')
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27utilities.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')
local M27Logic = import('/mods/M27AI/lua/AI/M27GeneralLogic.lua')
local M27Conditions = import('/mods/M27AI/lua/AI/M27CustomConditions.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')
local M27FactoryOverseer = import('/mods/M27AI/lua/AI/M27FactoryOverseer.lua')
local M27AirOverseer = import('/mods/M27AI/lua/AI/M27AirOverseer.lua')
local M27EconomyOverseer = import('/mods/M27AI/lua/AI/M27EconomyOverseer.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27PlatoonFormer = import('/mods/M27AI/lua/AI/M27PlatoonFormer.lua')
local M27Transport = import('/mods/M27AI/lua/AI/M27Transport.lua')
local M27PlatoonTemplates = import('/mods/M27AI/lua/AI/M27PlatoonTemplates.lua')


local refCategoryEngineer = M27UnitInfo.refCategoryEngineer
local refCategoryLandFactory = M27UnitInfo.refCategoryLandFactory
local refCategoryAirStaging = M27UnitInfo.refCategoryAirStaging
local refCategoryAirFactory = M27UnitInfo.refCategoryAirFactory


local refCategoryT1Mex = M27UnitInfo.refCategoryT1Mex
local refCategoryMex = M27UnitInfo.refCategoryMex
local refCategoryHydro = M27UnitInfo.refCategoryHydro
local refCategoryPower = M27UnitInfo.refCategoryPower
local refCategoryEnergyStorage = M27UnitInfo.refCategoryEnergyStorage

--Actions for engineers (dont have as local variables due to cap on how many local variables we can have)
refActionBuildMex = 1
refActionBuildHydro = 2
refActionReclaimArea = 3
refActionBuildPower = 4
refActionBuildLandFactory = 5
refActionBuildEnergyStorage = 6
refActionSpare = 7
refActionHasNearbyEnemies = 8
refActionUpgradeBuilding = 9
refActionBuildSecondPower = 10
refActionBuildAirStaging = 11
refActionBuildAirFactory = 12
refActionBuildSMD = 13
refActionBuildMassStorage = 14
refActionBuildT1Radar = 15
refActionBuildT2Radar = 16
refActionBuildT3Radar = 17
refActionAssistSMD = 18
refActionAssistAirFactory = 19
refActionBuildThirdPower = 20
refActionBuildExperimental = 21
refActionReclaimUnit = 22
refActionBuildT3MexOverT2 = 23
refActionUpgradeHQ = 24 --Assists an HQ with its upgrade
refActionReclaimTrees = 25
refActionBuildT1Sonar = 26
refActionBuildT2Sonar = 27
refActionAssistNuke = 28
refActionBuildShield = 29
refActionBuildT3ArtiPower = 30
refActionBuildTMD = 31
refActionBuildAA = 32
refActionBuildEmergencyPD = 33
refActionBuildSecondLandFactory = 34
refActionBuildSecondAirFactory = 35
refActionBuildTML = 36
refActionBuildSecondExperimental = 37
refActionLoadOnTransport = 38
refActionFortifyFirebase = 39
refActionAssistShield = 40
tiEngiActionsThatDontBuild = {refActionReclaimArea, refActionSpare, refActionHasNearbyEnemies, refActionReclaimUnit, refActionReclaimTrees, refActionUpgradeBuilding, refActionAssistSMD, refActionAssistAirFactory, refActionUpgradeHQ, refActionAssistNuke, refActionLoadOnTransport, refActionAssistShield}
--NOTE: IF ADDING MORE ACTIONS, UPDATE THE ACTIONS IN THE POWER STALL MANAGER
--ALSO update the actions noted in RefreshT3ArtiAdjacencyLocations as being ones that can ignore when deciding whether to clear existing engineer commands


--Plateau actions
refActionBuildPlateauFactory = 1001
refActionBuildPlateauMex = 1002
refActionPlateauReclaim = 1003
refActionPlateauSpareAction = 1004


--Build order related variables
refiBOInitialEngineersWanted = 'M27BOInitialEngineersWanted'
refiBOPreReclaimEngineersWanted = 'M27BOPreReclaimEngineersWanted'
refiBOPreSpareEngineersWanted = 'M27BOPreSpareEngineersWanted'
reftiBOActiveSpareEngineersByTechLevel = 'M27ActiveSpareEngineers' --[x] = tech level; returns the number of active spare engineers (i.e. engineers with the spare action)

iEngineerMobileEnemySearchRange = 40

--Tracking variables
--Engineer main tracking tables:
--local reftPrevEngineerAssignmentsByAction = 'M27EngineerPrevAssignmentsByAction' --Records all engineers. [x][y]; x is the action ref, [y] is the nth engineer (1st is the primary), returns engineer object
--local reftPrevEngineerAssignmentsByLocation = 'M27PrevEngineerAssignmentsByLoc' --[x][y]: x = unique location ref, y = action ref, returns engineer

--NOTE: table.getn wont work properly with below tables if are referring to keys that use a non-sequential numerical reference
reftEngineerAssignmentsByLocation = 'M27EngineerAssignmentsByLoc'     --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the engineer unique ref assigned to this location; returns the engineer object
reftEngineerAssignmentsByActionRef = 'M27EngineerAssignmentsByAction' --Records all engineers. [x][y]{1,2, 3} - x is the action ref; y is the engineer unique ref, 1 is the location ref, 2 is the engineer object (use the subtable ref keys instead of numbers to refer to these), 3 is refEngineerAssignmentActualLocation
reftEngineerActionsByEngineerRef = 'M27EngineerActionsByEngineerRef' --Records actions by engineer reference; aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][BuildingQueue]: returns {LocRef, EngRef, AssistingRef, ActionRef, refbPrimaryBuilder, refEngineerAssignmentActualLocation} but not in that order - i.e. use subtable keys to reference these; buildingqueue will be 1 for the first queueud building by the unit, 2 for the second etc. (e.g. t1 power)
reftEngineersHelpingACU = 'M27AllEngineersHelpingACU' --Engineer objects for any spare engineers assisting ACU
reftSpareEngineerAttackMoveTimeByLocation = 'M27EngineerSpareAttackMoveLocations' --[x] is the location ref, returns the gametime that an attack-move order was given to a spare engineer

--Subtable reference keys:
refEngineerAssignmentLocationRef = 'LocationRef' --Could use a number but this makes it more likely errors will be identified
refEngineerAssignmentEngineerRef = 'EngineerRef' --EngineerObject
refEngineerAssignmentActualLocation = 'ActualLocation' --The precise location instead of just the location ref
refoObjectTarget = 'Obj ectAssistingRef' --Usually this will be the object we are assisting; however in the case of 'build t3 mex' it will be the mex itself if dealing with the priamry engineer
refiActionRef = 'ActionRef'
refiCategoryBuilt = 'CategoryBuilt' --If primary builder is building something, then the category they build should be recorded against this subtable
refbPrimaryBuilder = 'M27EngineerPrimaryBuilder' --true if arent assisting anything
refiLastExperimentalReference = 'M27EngineerLastExperimentalCategory' --Category reference for the last experimental category that have tried to build
refiExperimentalLand = 1
refiExperimentalAir = 2
refiExperimentalNuke = 3
refiExperimentalT3Arti = 4
refiExperimentalNovax = 5
refiAllExperimentals = 6

refiLastSecondExperimentalRef = 'M27EngineerLastSecondExperimentalCategory' --As above
refiSMLConstructionStart = 'M27EngineerSMLConstructionStart' --Game time that started construction of nuke

refiMassSpentOnPD = 'M27EngineerMassSpentOnPD'
refiMassKilledByPD = 'M27EngineerMassKilledByPD'


--Localised engineer tracking:
refiTimeOfLastAssignment = 'M27EngineerTimeOfLastAssignment'
refiTimeOfLastIdleCheck = 'M27EngineerTimeOfLastIdleCheck' --used to avoid checking an engineer for targets more than once a second
refbAlreadyReassigning = 'M27EngineerAlreadyReassigning' --set to true when delayed reassignment is called, then 1 tick later is cleared (backup to stop recursive loop)
reftPrimaryEngineerLocations = 'M27EngineerPrimaryLocations' --Recorded against engineer; Records all locations where the engineer as the primary builder has been told to build something
local refiEngineerConditionNumber = 'M27EngineerConditionNumber' --condition number of the action assigned to the engineer (for if want an engineer with a lower priority, i.e. higher condition number)
refiEngineerCurrentAction = 'M27EngineerCurrentAction' --current action reference number that the engineer has been assigned
reftEngineerCurrentTarget = 'M27EngineerCurrentTarget'
refbEngineerActiveReclaimChecker = 'M27EngineerActiveReclaim'
reftEngineerLastPositionOfReclaimOrder = 'M27EngineerIssueReclaimLastPosition'
refbRecentlyAbortedReclaim = 'M27EngineerRecentlyAbortedReclaim' --Not reset by changes in action - used to flag if engineer was meant to be reclaiming but ran due to nearby enemies
local reftGuardedBy = 'M27EngineerGuardedByList' --stored as a variable on a particular unit, to track units which are guarding it
refiEngineerCurUniqueReference = 'M27EngineerCurUniqueReference' --aiBrain stores the xth engineer object its given an action to, so this can be used as a unique reference
local refiTotalActionsAssigned = 'M27EngineerTotalActionsAssigned' --Having issues with counting size of table so use this instead
--local refbEngineerHasNearbyEnemies = 'M27EngineerNearbyEnemies'
--local refbEngineerActionBeingRefreshed = 'M27EngineerActionBeingRefreshed' --Used to refresh tracking variables that have the relevant engineer as the one to be used
rebToldToStartBuildingT3Mex = 'M27EngineerStartedT3Mex' --Used so engineer can wait efore being treated as idle if this is false (for building t3 ontop of t2)
refbHelpingACU = 'M27EngineerHelpingACU' --e.g. used for spare engineers so can track how many we have helping the ACU
refbActiveDelayedTargetRechecker = 'M27EngActiveLastTargetChecker' --Against engineer - true if have a delayed target rechecker active


--Other variables:
local refiInitialMexBuildersWanted = 'M27InitialMexBuildersWanted' --build order related
refbNeedResourcesForMissile = 'M27NeedResourcesForMissile' -- true if e.g. want to build anti-nuke from SMD
refiTimeOfLastEngiSelfDestruct = 'M27TimeOfLastSelfDestruct' --floor(gametimeseconds) of when last ctrl K engineer (to stop ctrlK of all engis at once)
refbLastSpareEngineerHadNoAction = 'M27EngLastSpareEngineerHadNoAction' --True if the last spare engineer had nothing to do - used to increase search range
refiTimeOfLastFailure = 'M27EngLastFailure' --Game time that failed to build an action, [x] = actionref
refiTimeOfLastAction = 'M27EngLastAction'

reftUnclaimedMexOrHydroByCondition = 'M27EngUnclaimedMexOrHydroByCondition' --[ConvertUnclaimedConditionsToKey()] - returns a table {reftResourceLocations, refiTimeOfLastUpdate}
reftResourceLocations = 'M27EngResourceLocations'
refiTimeOfLastUpdate = 'M27EngTimeOfLastUpdate'
reftiResourceClaimedStatus = 'M27EngResourceClaimStatus' --aiBrain[this][sLocationRef] = {refiResourceStatus, refiTimeOfLastUpdate}
refiResourceStatus = 'M27EngResourceStatus'
refiStatusEnemyBuilt = 1
refiStatusAllyBuilt = 2
refiStatusAllyPartBuilt = 6
refiStatusQueued = 3
refiStatusAvailable = 4
refiStatusT3MexQueued = 5

refbMissileRecentlyBuilt = 'M27EngineerMissileRecentlyBuilt' --True when the missilebuilt event is run, given a delay in the unit registering that it has missiles

--TMD
reftUnitsWantingTMD = 'M27EngineerUnitsWantingTMD' --[key] is the UnitId..LifetimeCount; returns the unit object

--TML
reftoTMLTargetsOfInterest = 'M27EngineerTMLTargetsOfInterest' --General targets based on our base rather than a specific TML we have (used to decide if want to build a TML)
refiTimeOfLastTMLTargetRefresh = 'M27EngineerTimeOfLastTMLTargetRefresh' --Time we last refreshed the targetsofinterest
refiTMLShotsFired = 'M27EngineerTMLShotsFired' --times we have fired TML at a unit
refoLastTMLTarget = 'M27EngineerLastTMLTarget' --Against TML launcher, records the unit we last fired a missile at
refiLastTMLMassKills = 'M27EngineerLastTMLMassKills' --Against TML Launcher, records mass kills when last fired a missile
iTMLMissileRange = 256 --e.g. use if dont have access to a unit blueprint
iTMLMinMissileRange = 15
refiFirstTimeNoTargetsAvailable = 'M27EngineerFirstTimeNoTargetsAvailable' --For TML - Gametimeseconds so if its been a while of having no targets we can reclaim
refiTimeOfLastFailedTML = 'M27EngineerTimeLastFailedTML' --GameTime that TML died doing minimal damage
iTMLHighPriorityCategories = M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryT3Mex * categories.CYBRAN + M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryTML + M27UnitInfo.refCategorySML + M27UnitInfo.refCategorySMD + M27UnitInfo.refCategoryT2Power + M27UnitInfo.refCategoryT3Radar

--Firebases
reftFirebaseUnitsByFirebaseRef = 'M27EngineerFirebaseUnits' --aiBrain[x] is the unique firebase count (which gets set when first assining units to a new firebase)
refbPotentialFirebaseBuildingChangedSinceLastFirebaseCheck = 'M27EngineerPDHaveChanged' --aiBrain, true/false, based on if PD have been built or died
refiTimeOfLastFirebaseRefresh = 'M27EngineerTimeOfFirebaseRefresh' --aiBrain, Gametimeseconds
refiAssignedFirebase = 'M27EngineerAssignedFirebase' --Localised unit tracker, returns the unique firebase count
refiFirebaseUniqueCount = 'M27EngineerUniqueFirebaseCount' --aiBrain, stores the current firebase count (increased by 1 for each new firebase)
reftFirebasesWantingFortification = 'M27EngineerFirebasesToFortify' --aiBrain, [x] is the firebase unique count to be fortified, returns true if firebase to be fortified
refiFirebaseCategoryWanted = 'M27EngineerFirebaseCategoryWanted' --aiBrain, [x] is the firebase unqiue count, returns the category condition wnated to be built for the nearest firebase
reftFirebasePosition = 'M27EngineerFirebasePosition' --aiBrain, [x] is the firebase unique count, returns midpoint of the firebase based on average of all units within it
reftFirebaseFrontPDPosition = 'M27EngineerFirebaseFrontPD' --aiBrain, [x] is the firebase unique count
refiFirebaseBeingFortified = 'M27EngineerFirebaseBeingFortified' --aiBrain, returns firebase unique count that are currently trying to fortify
reftiFirebaseDeadPDMassCost = 'M27EngineerFirebaseDeadPDCost' --aiBrain, [x] is firebase unique count
reftiFirebaseDeadPDMassKills = 'M27EngineerFirebaseDeadPDKills' --aiBrain, [x] is firebase unique count

--Shield related
reftUnitsWantingFixedShield = 'M27EngineerUnitsWantingFixedShield'
reftUnitsWithFixedShield = 'M27EngineerUnitsWithFixedShield'
refbNeedsLargeShield = 'M27EngineerNeedsLargeShield' -- set to true on a unit if want to only try and build T3 shield by it (rather than T2)
refiShieldsWanted = 'M27EngineerShieldsWanted' --Set to the number of shields wanted for the unit - i.e. want to be 2 for T3 arti/novax when enemy has T3 arti/novax
refbHaveUnitsWantingHeavyShield = 'M27EngineerHaveUnitsWantingHeavyShield' --set against aibrain, true once we start on first unit wanting a heavy shield, so we only then have t3 engis trying to build shields
reftFailedShieldLocations = 'M27EngineerFailedShieldLocations' --set against aiBrain, [x] = sLocationRef, returns the actual location. Failed shield location logic - this is redundancy for if the initial logic for units wanting shields fails

--Shield assistance
reftPriorityShieldsToAssist = 'M27EngineerShieldsToAssist' --aiBrain, [x] is unitid..lifetimecount; returns the shield unit
reftAssistingEngineers = 'M27EngineerAssistingEngineers' --oUnit, [x] is the engineer unique count, returns the engineer object; currently used when assisting shields (not for other assisting actions)
refiTimeOfLastShieldPriorityRefresh = 'M27EngineerTimeOfLastShieldPriorityRefresh' --aiBrain, returns gametimeseconds that last refreshed priority shields
refoPriorityShieldProvidingCoverage = 'M27EngineerPriorityShieldProvidingCoverage' --Unit, returns the shield that covers this unit that is considered a high priority for assistance
refoUnitBeingAssisted = 'M27EngineerUnitBeingAssisted'
refbActiveShieldHealthChecker = 'M27EngineerActiveShieldHealthChecker' --Unit, returns true if currently have code monitoring the shield health
refbHavePausedAssistingEngineers = 'M27EngineerHavePausedAssistingEngineers' --Unit, against the shiield unit, returns true if have told the engineers assisting it to be paused

--local refoCurrentlyGuarding = 'M27CurrentlyGuarding' -- Unit object stored on a particular unit when its guarding another

function GetEngineerUniqueCount(oEngineer)
    local iUniqueRef = oEngineer[refiEngineerCurUniqueReference]
    if iUniqueRef == nil then
        local aiBrain = oEngineer:GetAIBrain()
        iUniqueRef = aiBrain[refiEngineerCurUniqueReference] + 1
        aiBrain[refiEngineerCurUniqueReference] = iUniqueRef
        oEngineer[refiEngineerCurUniqueReference] = iUniqueRef
    end
    return iUniqueRef
end

function CanBuildAtLocation(aiBrain, sBlueprintToBuild, tTargetLocation, iEngiActionToIgnore, bClearActionsIfNotStartedBuilding, bCheckForQueuedBuildings)
    --iEngiActionToIgnore and bClearActionsIfNotStartedBuilding are optional
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CanBuildAtLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': About to see if we can build '..sBlueprintToBuild..' at '..repru(tTargetLocation)..'; iEngiActionToIgnore='..(iEngiActionToIgnore or 'nil')..'; bClearActionsIfNotStartedBuilding='..tostring((bClearActionsIfNotStartedBuilding or false))..'; terrain height at target='..GetTerrainHeight(tTargetLocation[1], tTargetLocation[3])) end

    local bCanBuildStructure = false
    if aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation) == true then
        bCanBuildStructure = true
        if bCheckForQueuedBuildings == true then
            --Check if any engi actions queued up that would stop this
            local iBuildingRadius = math.max(__blueprints[sBlueprintToBuild].Physics.SkirtSizeX * 0.5 - 1,0)  --E.g. if building a t1 power, it has a size of 2, and radius of 1; when it's queued, the location and blocks within 1 of it will all be marked as being built on (i.e. a 3x3 area).  Hence, if considering building another power, if we dont reduce the search range by 1, it will lead to spacing things out more than needed
            local sLocationRef
            local tLocationToCheck
            local bIgnoreAction
            if bDebugMessages == true then LOG(sFunctionRef..': Can build structure at the location, checking if we already have building queued up for this location. iBuildingRadius='..iBuildingRadius) end
            --tiEngiActionsThatDontBuild
            for iAdjustX = -iBuildingRadius, iBuildingRadius, 1 do
                for iAdjustZ = -iBuildingRadius, iBuildingRadius, 1 do
                    tLocationToCheck = {tTargetLocation[1] + iAdjustX, 0, tTargetLocation[3] + iAdjustZ}
                    tLocationToCheck[2] = GetTerrainHeight(tLocationToCheck[1], tLocationToCheck[3])
                    sLocationRef = M27Utilities.ConvertLocationToStringRef(tLocationToCheck)
                    if bDebugMessages == true then LOG(sFunctionRef..': iAdjustX='..iAdjustX..'; iAdjustZ='..iAdjustZ..'; sLocationRef='..sLocationRef..'; Is table empty for this='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef]))) end
                    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef]) == false then
                        for iActionRef, tSubtable in aiBrain[reftEngineerAssignmentsByLocation][sLocationRef] do
                            bIgnoreAction = false
                            for _, iActionToIgnore in tiEngiActionsThatDontBuild do
                                if iActionRef == iActionToIgnore then
                                    bIgnoreAction = true
                                    break
                                end
                            end
                            if iEngiActionToIgnore and iActionRef == iEngiActionToIgnore then bIgnoreAction = true end
                            if bDebugMessages == true then LOG(sFunctionRef..': iActionRef='..iActionRef..'; bIgnoreAction='..tostring(bIgnoreAction)) end
                            if not(bIgnoreAction) then
                                bCanBuildStructure = false
                                --Do we want to cancel any blocking units?
                                if bClearActionsIfNotStartedBuilding then
                                    for iUniqueEngiRef, oEngineer in tSubtable do
                                        --if GetEngineerUniqueCount(oEngineer) == 58 and GetGameTimeSeconds() >= 2040 then bDebugMessages = true else bDebugMessages = false end
                                        --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
                                        if bDebugMessages == true then LOG(sFunctionRef..': About to clear oEngineer='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' which was recorded as having iActionRef='..iActionRef) end
                                        IssueClearCommands({oEngineer})
                                        ClearEngineerActionTrackers(aiBrain, oEngineer, true)
                                    end
                                    bCanBuildStructure = M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionRef])
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have just cleared any blocking units; bCanBuildStructure='..tostring(bCanBuildStructure)) end
                                end
                                if not(bCanBuildStructure) then break end
                            end
                        end
                    end
                    if not(bCanBuildStructure) then break end
                end
                if not(bCanBuildStructure) then break end
            end
        end
        if bCanBuildStructure then
            --Thanks to jip for flagging there's an engine bug where in rare situations units can be built slightly overlapping even if aiBrain:CanBuildStructureAt returns true - comments in the code Jip linked to suggested this is only where a building has upgraded
            -- compute build locations and issue the capping
            local iSkirtSizeRadius = __blueprints[sBlueprintToBuild].Physics.SkirtSizeX * 0.5

            -- find all units that may prevent us from building
            local tNearbyStructures = GetUnitsInRect(tTargetLocation[1] - (iSkirtSizeRadius + 4), tTargetLocation[3] - (iSkirtSizeRadius + 4), tTargetLocation[1] + (iSkirtSizeRadius + 4), tTargetLocation[3] + (iSkirtSizeRadius + 4))
            if M27Utilities.IsTableEmpty(tNearbyStructures) == false then
                tNearbyStructures = EntityCategoryFilterDown(M27UnitInfo.refCategoryUpgraded, tNearbyStructures)
                local iClosestDistance
                if M27Utilities.IsTableEmpty(tNearbyStructures) == false then
                    for iStructure, oStructure in tNearbyStructures do
                        if not(oStructure.Dead) then
                            if bDebugMessages == true then LOG(sFunctionRef..': oStructure='..oStructure.UnitId..M27UnitInfo.GetUnitLifetimeCount(oStructure)..'; position='..repru(oStructure:GetPosition())..'; target location='..repru(tTargetLocation)..'; target building ID='..sBlueprintToBuild..'; 50% of target building skirt size='..iSkirtSizeRadius..'; 50% of oStructure skrit size='..oStructure:GetBlueprint().Physics.SkirtSizeX * 0.5) end
                            iClosestDistance = math.max(math.abs(oStructure:GetPosition()[1] - tTargetLocation[1]), math.abs(oStructure:GetPosition()[3] - tTargetLocation[3]))
                            if iClosestDistance < (iSkirtSizeRadius + oStructure:GetBlueprint().Physics.SkirtSizeX * 0.5) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Cant build as iClosestDistance='..iClosestDistance..'which is less than the two skirt sizes') end
                                bCanBuildStructure = false
                                break
                            end
                        end
                    end
                end
            end
            if not(bCanBuildStructure) and bDebugMessages == true then LOG(sFunctionRef..': Skirt size is overlaping with a building that could have upgraded so will return false') end
        end
    elseif bDebugMessages == true then LOG(sFunctionRef..': Cant build structure at the location')
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, bCanBuildStructure='..tostring(bCanBuildStructure)) end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bCanBuildStructure
end

function TEMPTEST(aiBrain, sFunctionRef)
    --DONT REMOVE THIS as its helpful for testing, instead just comment out except for the errorhandler line once have used it

    --M27Utilities.ErrorHandler('This was only meant for debugging, disable') --remove this line if are actually using this for testing
    --Used if a particular location gives strange results - can hard code the location ref and track the variable and when it changes by uncommenting out various uses of --TEMPTEST

    if sFunctionRef then LOG('Temp test called from function ref '..sFunctionRef..'; Game time in seconds='..GetGameTimeSeconds()) end



    --BELOW CAN BE USED IF KNOW A PARTICULAR LOCATION THAT WANT TO TRACK

    local tLocationRefs = {'X207Z306', 'X87Z357', 'X231Z280'}
    M27Utilities.DrawLocations({{207,GetTerrainHeight(207,306),306}, {87,GetTerrainHeight(87,357),357}, {231,GetTerrainHeight(231,280),280}})
    local iActionRef = refActionBuildMex


    local iMaxCycle = table.getn(tLocationRefs)
    local sLocationRef
    local sEngiRef
    local oEngBuilder
    local sUnitState

    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation]) == true then LOG('All engineer assignments by location are empty')
    else
        LOG('Cycling through locations, iMaxCycle='..iMaxCycle)
        for iCurCount = 1, iMaxCycle do
            local iAssignments = 0
            local tAssignmentLocationRefs = {}
            sLocationRef = tLocationRefs[iCurCount]
            if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef]) == true then
                LOG('Building location '..sLocationRef..' is currently empty when considering by location')
            else
                if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionRef]) == false then
                    for iEngiRef, oEngBuilder in aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionRef] do
                        sEngiRef = GetEngineerUniqueCount(oEngBuilder)

                        sUnitState = M27Logic.GetUnitState(oEngBuilder)
                        if sUnitState == nil then sUnitState='NoState' end
                        sEngiRef = sEngiRef..sUnitState
                        LOG('Engineer with unique ref='..sEngiRef..'; is assigned to location ref='..sLocationRef..' for actionref='..iActionRef)
                    end
                else LOG('nothing recorded for sLocationRef:'..sLocationRef..' with iActionRef='..iActionRef)
                end
            end
        end
    end

    --Tracking ACUs actions:
    --[[
if aiBrain[reftEngineerActionsByEngineerRef][1] then
for iAction, tSubtable in aiBrain[reftEngineerActionsByEngineerRef][1] do
LOG('iAction='..iAction..'; iActionRef='..tSubtable[refiActionRef]..'; location='..repru(tSubtable[refEngineerAssignmentLocationRef]))
end
end--]]



    --Tracking nth engineer's actions and/or guards
    --[[
local bFirstEngiHasGuards = false
for iEngi, oEngi in aiBrain:GetListOfUnits(refCategoryEngineer, false, true) do
if GetEngineerUniqueCount(oEngi) == 2 then
local iUniqueRef = GetEngineerUniqueCount(oEngi)
local sLocRef
local iActionCount = oEngi[refiTotalActionsAssigned]
if iActionCount == nil then iActionCount = 0 end
if M27Utilities.IsTableEmpty(aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef]) == false then
    for iAction, tSubtable in aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef] do
        if tSubtable[refEngineerAssignmentLocationRef] == nil then sLocRef = 'nil' else sLocRef = tSubtable[refEngineerAssignmentLocationRef] end
        LOG('iAction='..iAction..'; refEngineerAssignmentLocationRef='..sLocRef..'; ActionRef='..tSubtable[refiActionRef]..'; Engi action count='..iActionCount)
    end
else LOG('Eng '..iUniqueRef..' has no actions assigned in EngineerActionsbyEngineerRef. Engi action count='..iActionCount)
end

--]]
    --Track guards
    --[[if oEngi[reftGuardedBy] and M27Utilities.IsTableEmpty(oEngi[reftGuardedBy]) == false then
    bFirstEngiHasGuards = true
    LOG('First engi number of guards using invalid tablegetn method='..table.getn(oEngi[reftGuardedBy]))
    for iGuard, oGuard in oEngi[reftGuardedBy] do
        LOG('First engi iGuard ref='..iGuard)
        LOG('First engi iGuard unique ref from object variable='..GetEngineerUniqueCount(oGuard))
    end
end--]]
    --[[
end
end--]]

    --[[
local iActionToTrack = refActionBuildHydro
if aiBrain[reftEngineerAssignmentsByActionRef] and aiBrain[reftEngineerAssignmentsByActionRef][iActionToTrack] then
local sLocationRef = 'nil'
for iEngiUniqueRef, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][iActionToTrack] do
if tSubtable[refEngineerAssignmentLocationRef] then sLocationRef = tSubtable[refEngineerAssignmentLocationRef] end
LOG('iEngiUniqueRef='..iEngiUniqueRef..'; sLocationRef='..sLocationRef..'; Engineer object unique ref (should be the same)='..tSubtable[refEngineerAssignmentEngineerRef][refiEngineerCurUniqueReference])
end
end
--]]
    --if bFirstEngiHasGuards == false then LOG('First engi has no guards') end


    --Tracking a particular action:
    --[[if aiBrain[reftEngineerAssignmentsByActionRef] and aiBrain[reftEngineerAssignmentsByActionRef][1] then
if aiBrain[reftEngineerAssignmentsByActionRef][1][1] then
local oEngineer = aiBrain[reftEngineerAssignmentsByActionRef][1][1][refEngineerAssignmentEngineerRef]
local sEngineer = 'Nil'
if oEngineer then
    if oEngineer.GetUnitId then sEngineer = oEngineer.UnitId
        else sEngineer = 'Not a unit'
    end
end
LOG(sEngineer)
else LOG('No unit assigned for action 1')
end
else
LOG('No action recrded for action 1 yet')
end--]]



end

function ClearEngineerActionTrackers(aiBrain, oEngineer, bDontClearUnitThatAreGuarding)
    --Assumes the unit will have been given a clearcommands() action if it needs one prior to calling this since sometimes will want to sometimes wont
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'ClearEngineerActionTrackers'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if M27UnitInfo.GetUnitLifetimeCount(oEngineer) == 1 and oEngineer.UnitId=='ual0105' then bDebugMessages = true end

    --if oEngineer[refiEngineerCurrentAction] == refActionBuildTMD then bDebugMessages = true end
    --if GetEngineerUniqueCount(oEngineer) == 31 and GetGameTimeSeconds() >= 305 then bDebugMessages = true end
    --if oEngineer == M27Utilities.GetACU(aiBrain) then bDebugMessages = true end
    if not(aiBrain.M27IsDefeated) and M27Logic.iTimeOfLastBrainAllDefeated < 10 then
        if bDontClearUnitThatAreGuarding == nil then bDontClearUnitThatAreGuarding = true end
        local iCurActionRef, sCurLocationRef, oCurAssistingRef, iGuardedByTableLocation
        local iUniqueRef = GetEngineerUniqueCount(oEngineer)
        local iEngiActionPreClear = oEngineer[refiEngineerCurrentAction]
        local tPrevReclaimTarget
        local bWasPrimaryEngi = oEngineer[refbPrimaryBuilder]
        --TEMPTEST(aiBrain, sFunctionRef..': Start')

        if iUniqueRef then --Wont have any actions assigned by code if unique ref is nil (since its set by the action tracker)
            if bDebugMessages == true then
                LOG(sFunctionRef..': UC='..iUniqueRef..': Engi='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..': Start of clearing actions. GameTime='..GetGameTimeSeconds()..'; bDontClearUnitThatAreGuarding='..tostring(bDontClearUnitThatAreGuarding)..'; action of engineer that are clearing='..(oEngineer[refiEngineerCurrentAction] or 'nil')..'; iEngiActionPreClear='..(iEngiActionPreClear or 'nil')..'; bWasPrimaryEngi='..tostring(bWasPrimaryEngi))
            end
            local tEngiTargetPreClear = {aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][1][refEngineerAssignmentActualLocation][1], aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][1][refEngineerAssignmentActualLocation][2], aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][1][refEngineerAssignmentActualLocation][3]}
            if not(tEngiTargetPreClear) and oEngineer[refbPrimaryBuilder] then M27Utilities.ErrorHandler(sFunctionRef..': Engineer with UC='..GetEngineerUniqueCount(oEngineer)..' and LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' doesnt have a location for its last action despite being a primary engineer') end

            --Clear engineer local variables:
            if oEngineer[refiEngineerCurrentAction] == refActionAssistShield and M27UnitInfo.IsUnitValid(oEngineer[refoUnitBeingAssisted]) then
                if M27Utilities.IsTableEmpty(oEngineer[refoUnitBeingAssisted][reftAssistingEngineers]) == false then
                    oEngineer[refoUnitBeingAssisted][reftAssistingEngineers][GetEngineerUniqueCount(oEngineer)] = nil
                end
            end

            --Make sure the engineer isnt paused (since we would have paused based on its previous action)
            if bDebugMessages == true then LOG(sFunctionRef..': About to unpause engineer with UC='..GetEngineerUniqueCount(oEngineer)..' if it is still alive') end
            if oEngineer.SetPaused and M27UnitInfo.IsUnitValid(oEngineer) then
                oEngineer:SetPaused(false)
                --Also update engineer's name to show it has no action
                if M27Config.M27ShowUnitNames == true or M27Config.M27ShowUnitNames == true then
                    local sName = 'E'..iUniqueRef..':UID='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..': No action'
                    if oEngineer.SetCustomName then oEngineer:SetCustomName(sName) end
                end
            end
            oEngineer[M27UnitInfo.refbPaused] = false

            if oEngineer[refiEngineerCurrentAction] == refActionReclaimArea or oEngineer[refiEngineerCurrentAction] == refActionPlateauReclaim then tPrevReclaimTarget = {oEngineer[reftEngineerCurrentTarget][1], oEngineer[reftEngineerCurrentTarget][2], oEngineer[reftEngineerCurrentTarget][3]} end
            oEngineer[refoUnitBeingAssisted] = nil
            oEngineer[refiEngineerConditionNumber] = nil
            oEngineer[refiEngineerCurrentAction] = nil
            oEngineer[reftEngineerCurrentTarget] = nil
            oEngineer[reftEngineerLastPositionOfReclaimOrder] = nil
            oEngineer[refiTotalActionsAssigned] = 0
            oEngineer[rebToldToStartBuildingT3Mex] = false
            oEngineer[refbPrimaryBuilder] = false
            if bDebugMessages == true then LOG(sFunctionRef..': Was engineer helping ACU='..tostring(oEngineer[refbHelpingACU] or false)) end
            if oEngineer[refbHelpingACU] then
                if M27Utilities.IsTableEmpty(aiBrain[reftEngineersHelpingACU]) == false then
                    for iUnit, oUnit in aiBrain[reftEngineersHelpingACU] do
                        if oUnit == oEngineer then
                            table.remove(aiBrain[reftEngineersHelpingACU], iUnit)
                            break
                        end
                    end
                end
            end

            oEngineer[refbHelpingACU] = false
            --reftGuardedBy is cleared later
            --TEMPTEST(aiBrain, sFunctionRef..': Just cleared local variables moving on to tables')
            --reftEngineerActionsByEngineerRef = 'M27EngineerActionsByEngineerRef' --Records actions by engineer reference; aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable]: returns {LocRef, EngRef, AssistingRef, ActionRef} - i.e. use subtable keys to reference these
            if bDebugMessages == true then LOG(sFunctionRef..': tEngiTargetPreClear='..repru(tEngiTargetPreClear or {'nil'})..'; is table of actions by engineer for iUniqueRef='..iUniqueRef..' empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef]))) end
            if M27Utilities.IsTableEmpty(aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef]) == false then
                for iRef, tActionSubtable in aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef] do
                    iCurActionRef = tActionSubtable[refiActionRef]
                    sCurLocationRef = tActionSubtable[refEngineerAssignmentLocationRef]
                    if bDebugMessages == true then LOG(sFunctionRef..': Cycling through entries in ActionByEngineerRef for iUniqueRef '..iUniqueRef..'; iRef='..iRef..'; tActionSubtable[refiActionRef]='..(tActionSubtable[refiActionRef] or 'nil')..'; sCurLocationRef='..(sCurLocationRef or 'nil')..'; iCurActionRef='..(iCurActionRef or 'nil')) end
                    if sCurLocationRef then
                        if bDebugMessages == true then
                            if sCurLocationRef then LOG(sFunctionRef..': Clearing for iCurActionRef='..iCurActionRef..'; sCurLocationRef='..sCurLocationRef)
                            else LOG(sFunctionRef..': Clearing for iCurActionRef='..iCurActionRef..'; sCurLocationRef is nil') end
                        end

                        --Clear bylocationref: reftEngineerAssignmentsByLocation --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the engineer unique ref assigned to this location
                        if aiBrain[reftEngineerAssignmentsByLocation][sCurLocationRef] and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sCurLocationRef][iCurActionRef]) == false then
                            --TEMPTEST(aiBrain, sFunctionRef..': Pre making sCurLocationRef nil, sCurLocationRef='..sCurLocationRef)
                            if bDebugMessages == true then LOG(sFunctionRef..': about to clear assignmentsbylocation, sCurLocationRef='..sCurLocationRef..'; iCurActionRef='..iCurActionRef..'; iUniqueRef='..iUniqueRef) end
                            aiBrain[reftEngineerAssignmentsByLocation][sCurLocationRef][iCurActionRef][iUniqueRef] = nil

                            --[[
                            --TEMPTEST(aiBrain, sFunctionRef..': Post making sCurLocationRef nil, sCurLocationRef='..sCurLocationRef)
                            if bDebugMessages == true then LOG(sFunctionRef..': Have cleared from AssignmentsByLocation for sCurLocationRef='..sCurLocationRef) end
                            --Also clear adjacent areas
                            local iBuildingRadius = math.ceil((GetBuildingSizeRadiusFromCategory(GetCategoryToBuildFromAction(iEngiActionPreClear, nil, aiBrain)) or 0))
                            if iBuildingRadius > 1 then --e.g. t1 power would be 1
                                if bDebugMessages == true then LOG(sFunctionRef..': sCurLocationRef='..sCurLocationRef..'; tEngiTargetPreClear='..repru(tEngiTargetPreClear or {'nil'})) end
                                local sOtherLocationRef
                                for iAdjX = -iBuildingRadius, iBuildingRadius, 1 do
                                    for iAdjZ = -iBuildingRadius, iBuildingRadius, 1 do
                                        sOtherLocationRef = M27Utilities.ConvertLocationToReference({tEngiTargetPreClear[1] + iAdjX, tEngiTargetPreClear[2], tEngiTargetPreClear[3] + iAdjZ})
                                        if aiBrain[reftEngineerAssignmentsByLocation][sOtherLocationRef] then
                                            aiBrain[reftEngineerAssignmentsByLocation][sOtherLocationRef][iCurActionRef] = nil
                                        end
                                    end
                                end
                            end--]]
                        else
                            if iCurActionRef then
                                if bDebugMessages == true then LOG('No table tracker to clear when clearing assignmentsbylocation or non nil location ref. iCurActionRef='..iCurActionRef) end
                            else
                                if oEngineer[refiEngineerCurrentAction] then M27Utilities.ErrorHandler('iCurActionRef is nil; iRef='..iRef..'; iUniqueRef='..iUniqueRef..'; oEngineer[refiEngineerCurrentAction] pre clear='..(iEngiActionPreClear or 'nil'))
                                else M27Utilities.ErrorHandler('iCurActionRef is nil; iRef='..iRef..'; iUniqueRef='..iUniqueRef..'; oEngineer[refiEngineerCurrentAction] pre clear=nil')
                                end
                            end
                        end
                        --TEMPTEST(aiBrain, sFunctionRef..': Just cleared for sCurLocationRef='..sCurLocationRef)
                    elseif bDebugMessages == true then LOG(sFunctionRef..': sCurLocationRef is nil')
                    end

                    --Clear by action ref:
                    --reftEngineerAssignmentsByActionRef --Records all engineers. [x][y]{1,2} - x is the action ref; y is the engineer unique ref, 1 is the location ref, 2 is the engineer object (use the subtable ref keys instead of numbers to refer to these)
                    if iCurActionRef and aiBrain[reftEngineerAssignmentsByActionRef] and aiBrain[reftEngineerAssignmentsByActionRef][iCurActionRef] then
                        if bDebugMessages == true then LOG(sFunctionRef..': Clearing reftEngineerAssignmentsByActionRef for iCurActionRef='..iCurActionRef) end
                        aiBrain[reftEngineerAssignmentsByActionRef][iCurActionRef][iUniqueRef] = nil
                    end
                    --TEMPTEST(aiBrain, sFunctionRef..': Just cleared engineer assignments by action ref')

                    --Clear this engineer from any unit it is assisting
                    if bDontClearUnitThatAreGuarding == false then
                        oCurAssistingRef = tActionSubtable[refoObjectTarget]
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Are assigned as assisting a unit')
                            if oCurAssistingRef.GetUnitId then LOG('Unit ID assisting='..oCurAssistingRef.UnitId)
                            else LOG('unit that are assisting has no unit Id') end
                            if oCurAssistingRef[reftEngineerActionsByEngineerRef] then LOG('Unique ref assisting='..oCurAssistingRef[reftEngineerActionsByEngineerRef])
                            else LOG('Unit that are assisting has no unique ref') end
                            if M27Utilities.IsTableEmpty(oCurAssistingRef[reftGuardedBy]) == true then LOG('Unit that are assisting doesnt have a table of units its guarded by') end
                        end
                        if oCurAssistingRef and M27Utilities.IsTableEmpty(oCurAssistingRef[reftGuardedBy]) == false then
                            oCurAssistingRef[reftGuardedBy][iUniqueRef] = nil
                        end
                    end
                end
                aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef] = {}
                --TEMPTEST(aiBrain, sFunctionRef..': Just cleared engineer actions by engineer ref')
            else
                if bDebugMessages == true then LOG(sFunctionRef..': table of actions by engineer ref is empty') end
            end

            --Clear any locations assigned to the engineer itself
            if bDebugMessages == true then LOG(sFunctionRef..': About to clear any locations assigned to the engineer.  Is table of primary locations empty='..tostring(M27Utilities.IsTableEmpty(oEngineer[reftPrimaryEngineerLocations]))) end
            if M27Utilities.IsTableEmpty(oEngineer[reftPrimaryEngineerLocations]) == false then
                for iLocation, tLocation in oEngineer[reftPrimaryEngineerLocations] do
                    sCurLocationRef = M27Utilities.ConvertLocationToReference(tLocation)
                    if aiBrain[reftEngineerAssignmentsByLocation][sCurLocationRef] and aiBrain[reftEngineerAssignmentsByLocation][sCurLocationRef][iCurActionRef] then aiBrain[reftEngineerAssignmentsByLocation][sCurLocationRef][iCurActionRef][iUniqueRef] = nil end
                end
                oEngineer[reftPrimaryEngineerLocations] = {}
            end



            --Clear actions of any units guarding this one and then call the update engineer tracker on them:
            local tTempGuardedBy = {}
            if bDebugMessages == true then LOG(sFunctionRef..': Considering if we have any engineers that are assisting us; is the table empty='..tostring(M27Utilities.IsTableEmpty(oEngineer[reftGuardedBy]))) end
            if M27Utilities.IsTableEmpty(oEngineer[reftGuardedBy]) == false then
                if bDebugMessages == true then LOG(sFunctionRef..': Clearing guards, number of guards='..table.getn(oEngineer[reftGuardedBy])) end
                local bAbortClearGuards = false
                local iGuardCount = 0
                for iGuard, oGuard in oEngineer[reftGuardedBy] do
                    if GetEngineerUniqueCount(oGuard) then
                        iGuardCount = iGuardCount + 1
                        tTempGuardedBy[iGuardCount] = oGuard
                        if bDebugMessages == true then LOG(sFunctionRef..': iGuardCount='..iGuardCount..'; oGuard lifetime count='..M27UnitInfo.GetUnitLifetimeCount(oGuard)) end
                    else
                        M27Utilities.ErrorHandler('Guard assigned to engineer with lifetime count='..iUniqueRef..'; doesnt have a unique ref so something has gone wrong, aborting actions to clear commands. iGuard='..iGuard)
                        bAbortClearGuards = true
                    end
                end

                if bAbortClearGuards == false then
                    if bDebugMessages == true then LOG(sFunctionRef..'; iGuardCount='..iGuardCount..'; will now clear commands of those guards and send them for reassignment') end
                    if M27Utilities.IsTableEmpty(tTempGuardedBy) == false then
                        --for iEngi, oEngi in tTempGuardedBy do
                            --if M27UnitInfo.IsUnitValid(oEngi) and (oEngi:IsUnitState('Building') or oEngi:IsUnitState('Repairing')) then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
                        --end

                        if bDebugMessages == true then
                            LOG(sFunctionRef..': About to issue clear commands to '..table.getn(tTempGuardedBy)..'engineers.  Unique ref of each engineer about to be cleared')
                            for iEngi, oEngi in tTempGuardedBy do
                                LOG('iEngi='..iEngi..'; oEngi[UniqueRef]='..GetEngineerUniqueCount(oEngi))
                            end
                        end
                        --if bDebugMessages == true then M27Utilities.ErrorHandler('Full audit trail pre delayed engi reassignment order') end

                        IssueClearCommands(tTempGuardedBy) --Otherwise engi will appear to be busy when reassignengi cycles through engis
                        ForkThread(DelayedEngiReassignment, aiBrain, true, tTempGuardedBy)
                    end
                    oEngineer[reftGuardedBy] = {}
                    for iGuard, oGuard in tTempGuardedBy do
                        --if GetEngineerUniqueCount(oGuard) == 59 then bDebugMessages = true end
                        if bDebugMessages == true then LOG(sFunctionRef..': About to clear oGuard, oGuard UC='..GetEngineerUniqueCount(oGuard)..'LC='..M27UnitInfo.GetUnitLifetimeCount(oGuard)..' if it has an action assigned') end
                        if oGuard[refiEngineerCurrentAction] and M27UnitInfo.IsUnitValid(oGuard) then
                            ClearEngineerActionTrackers(aiBrain, oGuard, true) --Dont want to do this earlier as risk infinite loop if this engineer assists another engineer that assists it
                        end
                    end
                end
            elseif bDebugMessages == true then LOG(sFunctionRef..': Dont have any guards assigned')
            end
            if tPrevReclaimTarget then
                local iReclaimSegmentX, iReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tPrevReclaimTarget)
                if bDebugMessages == true then LOG(sFunctionRef..': iReclaimSegmentX-Z='..iReclaimSegmentX..'-'..iReclaimSegmentZ..'; Engineer UC='..GetEngineerUniqueCount(oEngineer)..'; LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)) end
                --Update both this segment and adjacent ones (since adjacent ones will have beeni gnored if they were by a segment assigned for reclaim)
                for iAdjX = -1, 1 do
                    for iAdjZ = -1, 1 do
                        M27MapInfo.UpdateReclaimSegmentAreaOfInterest(iReclaimSegmentX + iAdjX, iReclaimSegmentZ + iAdjZ, {aiBrain})
                    end
                end
            end
        else if bDebugMessages == true then LOG(sFunctionRef..'; Unique ref is nil') end
        end

        --Clear escort requirements
        if oEngineer[M27PlatoonUtilities.refbShouldHaveEscort] then
            if not(M27Utilities.IsACU(oEngineer)) then
                --if not(oEngineer == M27Utilities.GetACU(aiBrain)) then

                --Reset after 20s incase the engineer is running from an enemy or is in danger, but only reset if we dont have a new action that is the same as the current action (in case engineer runs away, threat is dealt with, and then engineer returns and wants an escort)
                --DelayChangeVariable(oVariableOwner, sVariableName, vVariableValue, iDelayInSeconds, sOptionalOwnerTimeRef, iMustBeLessThanThisTimeValue, iMustBeMoreThanThisTimeValue, vMustEqualThisValue)
                if iEngiActionPreClear then
                    M27Utilities.DelayChangeVariable(oEngineer, M27PlatoonUtilities.refbShouldHaveEscort, false, 20, refiEngineerCurrentAction, nil, nil, iEngiActionPreClear)
                else
                    oEngineer[M27PlatoonUtilities.refbShouldHaveEscort] = false
                end
            end
        end
        if bDebugMessages == true and M27Utilities.IsACU(oEngineer) then
            local iACUAction = M27Utilities.GetACU(aiBrain)[refiEngineerCurrentAction]
            if iACUAction == nil then iACUAction = 'nil' end
            LOG(sFunctionRef..': Were dealing with ACU; ACU action at end of code ='..iACUAction)
        end
    elseif bDebugMessages == true then LOG(sFunctionRef..': M27 has been defaeted')
    end
    --DoesPlatoonStillHaveSupportTarget function will cause the escort to be disbanded (eventually) - dont want to do here since we may assign an action that leads us to wanting the engineer to still be escorted immediately after clearing its actions
    --TEMPTEST(aiBrain, sFunctionRef..': End')
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdateReclaimSegmentsForEngineerDeathOrNearbyEnemy(aiBrain, oEngineer, bNearbyEnemyNotDeath)
    local iArmyIndex = aiBrain:GetArmyIndex()
    local ReclaimReference = M27MapInfo.reftReclaimTimeOfLastEngineerDeathByArmyIndex
    if bNearbyEnemyNotDeath then ReclaimReference = M27MapInfo.refReclaimTimeLastEnemySightedByArmyIndex end
    if (oEngineer[refiEngineerCurrentAction] == refActionReclaimArea or oEngineer[refiEngineerCurrentAction] == refActionPlateauReclaim or oEngineer[refbRecentlyAbortedReclaim]) and M27Utilities.IsTableEmpty(oEngineer[reftEngineerCurrentTarget]) == false then
        local iReclaimSegmentX, iReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(oEngineer[reftEngineerCurrentTarget])
        for iAdjX = -1, 1 do
            for iAdjZ = -1, 1 do
                if M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX] and M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ] then
                    if not(M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ][ReclaimReference]) then M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ][ReclaimReference] = {} end
                    M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ][ReclaimReference][iArmyIndex] = GetGameTimeSeconds()
                end
            end
        end
    end

    --Also mark nearby segments from where the engineer just died/spotted enemies
    local iReclaimSegmentX, iReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(oEngineer:GetPosition())
    for iAdjX = -1, 1 do
        for iAdjZ = -1, 1 do
            if M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX] and M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ] then
                if not(M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ][ReclaimReference]) then M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ][ReclaimReference] = {} end
                M27MapInfo.tReclaimAreas[iReclaimSegmentX + iAdjX][iReclaimSegmentZ + iAdjZ][ReclaimReference][iArmyIndex] = GetGameTimeSeconds()
            end
        end
    end
end

function OnEngineerDeath(aiBrain, oEngineer)
    if oEngineer[M27Transport.refiAssignedPlateau] and aiBrain[M27MapInfo.reftOurPlateauInformation][oEngineer[M27Transport.refiAssignedPlateau]] then
        if aiBrain[M27MapInfo.reftOurPlateauInformation][oEngineer[M27Transport.refiAssignedPlateau]][M27MapInfo.subrefPlateauEngineers] then
            aiBrain[M27MapInfo.reftOurPlateauInformation][oEngineer[M27Transport.refiAssignedPlateau]][M27MapInfo.subrefPlateauEngineers][GetEngineerUniqueCount(oEngineer)] = nil
        end
    end

    --Was the engineer reclaiming? If so then mark its target and surroundings as dangerous
    if not (aiBrain.M27IsDefeated) and M27Logic.iTimeOfLastBrainAllDefeated < 10 then
        UpdateReclaimSegmentsForEngineerDeathOrNearbyEnemy(aiBrain, oEngineer, false)
        ClearEngineerActionTrackers(aiBrain, oEngineer, true)
    end
end

function GetBuildingSizeRadiusFromCategory(iCategory)
    --Determines the maximum building size that would satisfy iCategory; returns nil if no category
    if iCategory then
        local iMaxSize = 1
        for iRef, sBlueprint in EntityCategoryGetUnitList(iCategory) do
            iMaxSize = math.max((__blueprints[sBlueprint].Physics.SkirtSizeX or 0), (__blueprints[sBlueprint].Physics.SkirtSizeZ or 0), iMaxSize)
        end
        return iMaxSize * 0.5
    end
end

function UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers, oUnitToBeDestroyed, iPrimaryEngineerCategoryBuilt)
    --iPrimaryEngineerCategoryBuilt - should onl yspecify if are dealing with the primary engineer; can be used e.g. to reproduce an engineers order after we have done something to remove it (such as reclaiming)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'UpdateEngineerActionTrackers'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetGameTimeSeconds() >= 600 then bDebugMessages = true end

    --if bAreAssisting and M27Utilities.IsACU(oUnitToAssist) then bDebugMessages = true end
    --if iActionToAssign == refActionBuildTMD then bDebugMessages = true end
    --if GetEngineerUniqueCount(oEngineer) == 31 and GetGameTimeSeconds() >= 305 then bDebugMessages = true end
    if not(M27UnitInfo.IsUnitValid(oEngineer)) then M27Utilities.ErrorHandler('oEngineer isnt valid. UnitID='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; iConditionNumber='..iConditionNumber..'; iActionToAssign='..iActionToAssign..'; tTargetLocation='..repru(tTargetLocation or {'nil'})..'; aiBrain index='..aiBrain:GetArmyIndex()) end


    if iActionToAssign == nil then M27Utilities.ErrorHandler('iActionToAssign is nil') end

    --TEMPTEST(aiBrain, sFunctionRef..': Start')
    if bDontClearExistingTrackers == nil then bDontClearExistingTrackers = false end
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code; iActionToAssign='..iActionToAssign..'; tTargetLocation='..repru(tTargetLocation)..'; bAreAssisting='..tostring(bAreAssisting)..'; bDontClearExistingTrackers='..tostring(bDontClearExistingTrackers)..'; tTargetLocation='..repru((tTargetLocation or {'nil'}))..'; oEngineer='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer)) end
    local sLocationRef
    if tTargetLocation == nil then
        if not(bAreAssisting) and oUnitToAssist == nil and not(iActionToAssign == refActionSpare or iActionToAssign == refActionPlateauSpareAction) then M27Utilities.ErrorHandler('dont have a location or unit to assist') end
    else
        sLocationRef = M27Utilities.ConvertLocationToReference(tTargetLocation)
        if bDebugMessages == true then LOG(sFunctionRef..': sLocationRef='..sLocationRef) end
    end

    --Ensure have unique ref for engineer
    local iUniqueRef = GetEngineerUniqueCount(oEngineer)


    if bDebugMessages == true then LOG(sFunctionRef..': oEngineer uniqueref='..iUniqueRef..'; updating displayed name') end




    --Update oEngineer trackers
    if not(bDontClearExistingTrackers) then
        if bDebugMessages == true then LOG(sFunctionRef..': Clearing engineer action trackers for engineer with UC='..GetEngineerUniqueCount(oEngineer)..' which has action '..(oEngineer[refiEngineerCurrentAction] or 'nil')) end
        ClearEngineerActionTrackers(aiBrain, oEngineer, true)
    else
        if bDebugMessages == true then LOG(sFunctionRef..': Not clearing engineers trackers due to input settings') end
    end

    if M27Config.M27ShowUnitNames == true then
        local sName = 'E'..iUniqueRef..':UID='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; Action='..iActionToAssign
        if bAreAssisting then sName = sName..': AssistObject' end
        if oEngineer.SetCustomName then oEngineer:SetCustomName(sName) end
        if bDebugMessages == true then LOG(sFunctionRef..': Updated engineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer)..' to have sName='..sName) end
    end

    oEngineer[refiEngineerCurrentAction] = iActionToAssign
    oEngineer[reftEngineerCurrentTarget] = tTargetLocation
    oEngineer[refiEngineerConditionNumber] = iConditionNumber
    local iCurPlaceInEngineerActionTable = oEngineer[refiTotalActionsAssigned]
    if iCurPlaceInEngineerActionTable == nil then iCurPlaceInEngineerActionTable = 1
    else iCurPlaceInEngineerActionTable = iCurPlaceInEngineerActionTable + 1 end
    oEngineer[refiTotalActionsAssigned] = iCurPlaceInEngineerActionTable
    oEngineer[refiTimeOfLastAssignment] = GetGameTimeSeconds()

    if bDebugMessages == true then LOG(sFunctionRef..': Have updated engineers current action to '..oEngineer[refiEngineerCurrentAction]) end




    --Record guard in unit to be guarded
    if bAreAssisting == true and oUnitToAssist == nil then
        M27Utilities.ErrorHandler('Are meant to be assisting but unit to assist is nil')
        oEngineer[refbPrimaryBuilder] = false
    elseif oUnitToAssist and not(bAreAssisting) then
        M27Utilities.ErrorHandler('Have a unit to assist but bAreAssisting isnt true')
        oEngineer[refbPrimaryBuilder] = false
    elseif bAreAssisting == true then
        if EntityCategoryContains(M27UnitInfo.refCategoryEngineer + categories.COMMAND, oUnitToAssist.UnitId) then
            oEngineer[refbPrimaryBuilder] = false
            if oUnitToAssist[reftGuardedBy] == nil then oUnitToAssist[reftGuardedBy] = {} end
            oUnitToAssist[reftGuardedBy][iUniqueRef] = oEngineer
            if bDebugMessages == true then
                LOG(sFunctionRef..': Recorded engineer with unique ref '..iUniqueRef..'; as a guard for unit with ID= '..oUnitToAssist.UnitId..'; so wont be marked as a primary builder')
                LOG('Unit that are assisting has unique reference='..GetEngineerUniqueCount(oUnitToAssist))
                LOG('Will cycle through each guardedby entry now and output the unique ref of each unit')
                for iGuard, oGuard in oUnitToAssist[reftGuardedBy] do
                    LOG('oGuard has unique ref='..iGuard)
                end
            end
        else
            --Are assisting a non-engineer, e.g. we started building something but no longer have any engineers assigned to it
            oEngineer[refbPrimaryBuilder] = true
        end

    else
        --Not guarding a unit - check if have an action that means we want an escort
        oEngineer[refbPrimaryBuilder] = true
    end
    if oEngineer[refbPrimaryBuilder] then
        if bDebugMessages == true then LOG(sFunctionRef..': Set engineer as being the primary builder') end
        local bWantEscort = false
        if not(oEngineer == M27Utilities.GetACU(aiBrain)) then
            if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] and (iActionToAssign == refActionBuildMex or iActionToAssign == refActionBuildHydro or iActionToAssign == refActionReclaimArea) then
                --Want an escort for the platoon if the target destination is far enough away and we can path to the enemy base with amphibious units
                if M27Utilities.IsTableEmpty(tTargetLocation) then
                    M27Utilities.ErrorHandler('No target location for iActionToAssign='..iActionToAssign..'; oEngineer='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UQ='..GetEngineerUniqueCount(oEngineer))
                    tTargetLocation = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
                end

                local iTargetDistanceFromOurBase = M27Utilities.GetDistanceBetweenPositions(tTargetLocation, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                if iTargetDistanceFromOurBase > 100 then bWantEscort = true
                elseif iTargetDistanceFromOurBase > 50 then
                    --Are we closer to enemy base than our base is?
                    local tEnemyStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
                    local iDistanceBetweenBases = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]
                    local iTargetDistanceToEnemyBase = M27Utilities.GetDistanceBetweenPositions(tTargetLocation, tEnemyStartPosition)
                    if iTargetDistanceToEnemyBase < iDistanceBetweenBases then bWantEscort = true end
                end
            end
        end
        if bWantEscort == true then
            oEngineer[M27PlatoonUtilities.refbShouldHaveEscort] = true
            M27PlatoonUtilities.RecordPlatoonUnitsByType(oEngineer, true)
            M27PlatoonUtilities.GetNearbyEnemyData(oEngineer, iEngineerMobileEnemySearchRange, true)
            M27PlatoonUtilities.UpdateEscortDetails(oEngineer)
        else
            oEngineer[M27PlatoonUtilities.refbShouldHaveEscort] = false --Redundancy (clearactiontracker should already cover)
        end
    end

    --Record action in engineer reference table
    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef]) == true then
        aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef] = {}
    end

    aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable] = {}
    if oUnitToAssist then aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refoObjectTarget] = oUnitToAssist end
    if M27Utilities.IsTableEmpty(tTargetLocation) == false then
        aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refEngineerAssignmentLocationRef] = sLocationRef
        aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refEngineerAssignmentActualLocation] = {tTargetLocation[1], tTargetLocation[2], tTargetLocation[3]}
    end
    --[[if not(bAreAssisting) then
aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refEngineerAssignmentLocationRef] = sLocationRef
else aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refoObjectTarget] = oUnitToAssist
end--]]
    aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refbPrimaryBuilder] = not(bAreAssisting)
    aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refiActionRef] = iActionToAssign
    aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][iCurPlaceInEngineerActionTable][refiCategoryBuilt] = iPrimaryEngineerCategoryBuilt
    if bDebugMessages == true then
        local sLocRef = sLocationRef
        if sLocRef == nil then sLocRef = 'nil' end
        LOG(sFunctionRef..': UniqueRef='..iUniqueRef..'; Recorded in ActionsByEngineerRef subtable for sLocRef='..sLocRef..'; iActionToAssign='..iActionToAssign..'; iCurPlaceInEngineerActionTable='..iCurPlaceInEngineerActionTable)
    end
    --Record AssignmentsByActionRef: -Records all engineers. [x][y]{1,2} - x is the action ref; y is the Engineer unique ref, 1 is the location ref, 2 is the engineer object
    if aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] == nil then
        aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] = {}
    end
    aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign][iUniqueRef] = {}
    aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign][iUniqueRef][refEngineerAssignmentLocationRef] = sLocationRef
    aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign][iUniqueRef][refEngineerAssignmentEngineerRef] = oEngineer
    aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign][iUniqueRef][refEngineerAssignmentActualLocation] = tTargetLocation
    if bDebugMessages == true then LOG(sFunctionRef..': Recorded in AssignmentsByActionRef') end

    --Record reftEngineerAssignmentsByLocation; --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the nth engineer assigned to this location
    if sLocationRef then
        if aiBrain[reftEngineerAssignmentsByLocation][sLocationRef] == nil then
            aiBrain[reftEngineerAssignmentsByLocation][sLocationRef] = {}
            aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionToAssign] = {}
        else
            if aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionToAssign] == nil then aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionToAssign] = {} end
        end

        aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionToAssign][iUniqueRef] = oEngineer

        if oEngineer[refbPrimaryBuilder] then
            if not(oEngineer[reftPrimaryEngineerLocations]) then oEngineer[reftPrimaryEngineerLocations] = {} end
            table.insert(oEngineer[reftPrimaryEngineerLocations], tTargetLocation)
        end

        if bDebugMessages == true then
            LOG(sFunctionRef..': Recorded in assignments by location; sLocationRef='..sLocationRef..'; iActionToAssign='..iActionToAssign..'; iUniqueRef='..iUniqueRef)
            LOG(sFunctionRef..': Values for corresponding entry in 1st action for actionsbyengineerref: iActionRef='..aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][1][refiActionRef]..'; sLocationRef='..aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][1][refEngineerAssignmentLocationRef])
        end
        --Record for adjacent locations as well so we dont try and build on these
        if iActionToAssign then
            local iCategory = GetCategoryToBuildFromAction(iActionToAssign, nil, aiBrain)
            local iBuildingRadius = 0
            if iCategory then iBuildingRadius = math.ceil((GetBuildingSizeRadiusFromCategory(iCategory) or 0)) end
            if bDebugMessages == true then
                LOG(sFunctionRef..': iBuildingRadius='..(iBuildingRadius or 'nil'))
                if iActionToAssign == refActionBuildExperimental or iActionToAssign == refActionBuildSecondExperimental then

                    if iCategory == M27UnitInfo.refCategorySML then
                        LOG('Are trying to build a nuke category')
                    end
                    LOG('Will list out each possible blueprint and its size now')

                    if iCategory then
                        local iMaxSize = 1
                        for iRef, sBlueprint in EntityCategoryGetUnitList(iCategory) do
                            iMaxSize = math.max((__blueprints[sBlueprint].Physics.SkirtSizeX or 0), (__blueprints[sBlueprint].Physics.SkirtSizeZ or 0), iMaxSize)
                            if bDebugMessages == true then LOG(sFunctionRef..': sBlueprint='..sBlueprint..': iMaxSize='..iMaxSize) end
                        end
                    else
                        LOG('iCategory is nil')
                    end
                end
            end
            if iBuildingRadius > 1 then --e.g. t1 power would be 1
                for iAdjX = -iBuildingRadius, iBuildingRadius do
                    for iAdjZ = -iBuildingRadius, iBuildingRadius do
                        sLocationRef = M27Utilities.ConvertLocationToReference({tTargetLocation[1] + iAdjX, tTargetLocation[2], tTargetLocation[3] + iAdjZ})

                        table.insert(oEngineer[reftPrimaryEngineerLocations], {tTargetLocation[1] + iAdjX, tTargetLocation[2], tTargetLocation[3] + iAdjZ})

                        if aiBrain[reftEngineerAssignmentsByLocation][sLocationRef] == nil then
                            aiBrain[reftEngineerAssignmentsByLocation][sLocationRef] = {}
                            aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionToAssign] = {}
                        else
                            if aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionToAssign] == nil then aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionToAssign] = {} end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Recording sLocationRef '..sLocationRef..' as having an engineer with UC='..GetEngineerUniqueCount(oEngineer)..': LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' assigned to it') end
                        aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionToAssign][iUniqueRef] = oEngineer

                    end
                end
            end
        end
    end
    --Update reclaim tracker
    if iActionToAssign == refActionReclaimArea or iActionToAssign == refActionPlateauReclaim then
        local iReclaimSegmentX, iReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tTargetLocation)
        if bDebugMessages == true then LOG(sFunctionRef..': iReclaimSegmentX-Z='..iReclaimSegmentX..'-'..iReclaimSegmentZ..'; Engineer UC='..GetEngineerUniqueCount(oEngineer)..'; LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)) end
        --Update both the target segment and all adjacent segments (as dont want to relcaim if engineer already assigned nearby)
        for iAdjX = -1, 1 do
            for iAdjZ = -1, 1 do
                M27MapInfo.UpdateReclaimSegmentAreaOfInterest(iReclaimSegmentX + iAdjX, iReclaimSegmentZ + iAdjZ, {aiBrain})
            end
        end
    end
    --Record when we sent engineer this action (used for some occasional build conditions)
    if oEngineer[refbPrimaryBuilder] and oEngineer[refiEngineerCurrentAction] == iActionToAssign then aiBrain[refiTimeOfLastAction][iActionToAssign] = GetGameTimeSeconds() end

    --Record mexes that will be ctrl-k ing
    if oUnitToBeDestroyed then
        oUnitToBeDestroyed[M27EconomyOverseer.refbWillCtrlKMex] = true
    end

    --Clear the primary builder flag if the action doesnt relate to building
    if oEngineer[refbPrimaryBuilder] then
        for iRef, iAction in tiEngiActionsThatDontBuild do
            if iAction == iActionToAssign then
                oEngineer[refbPrimaryBuilder] = false
                if bDebugMessages == true then LOG(sFunctionRef..': Action isnt one that can build so wont flag this as a primary builder any more') end
                break
            end
        end
    end


    if bDebugMessages == true then LOG(sFunctionRef..': End of code; Is reftEngineerAssignmentsByActionRef empty for iActionToAssign '..iActionToAssign..'='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign]))) end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    --TEMPTEST(aiBrain, sFunctionRef..': End')
end

function UpdateActionsForACUMovementPath(tMovementPath, aiBrain, oEngineer, iPathStartPoint)
    --Assumes oEngineer (e.g. the ACU) will build mexes anywhere near tMovementPath locations
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateActionsForACUMovementPath'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iUniqueRef = GetEngineerUniqueCount(oEngineer)

    if bDebugMessages == true then

        LOG(sFunctionRef..': Start of code; tMovementPath='..repru(tMovementPath)..'; oEngineer BP='..oEngineer.UnitId)

        LOG('oEngineer lifetime count='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; Engineer Unique count='..iUniqueRef)
        local iPlatoonCount
        local sPlan = 'None'

        if oEngineer.PlatoonHandle and oEngineer.PlatoonHandle.GetPlan then
            sPlan = oEngineer.PlatoonHandle:GetPlan()
            iPlatoonCount = oEngineer.PlatoonHandle[M27PlatoonUtilities.refiPlatoonCount]
        end
        if iPlatoonCount == nil then iPlatoonCount = 0 end
        LOG(sFunctionRef..': sPlan='..sPlan..'; iPlatoonCount='..iPlatoonCount)
    end
    --TEMPTEST(aiBrain, sFunctionRef..': Start')
    ClearEngineerActionTrackers(aiBrain, oEngineer, true) --Only want to clear ACU and units guarding ACU, not the unit the ACU is assisting
    --TEMPTEST(aiBrain, sFunctionRef..': Just after clearing action trackers')
    local tNearbyMexes
    local iSearchRange = M27Overseer.iACUMaxTravelToNearbyMex

    for iLocation, tLocation in tMovementPath do
        if iLocation >= iPathStartPoint then
            if M27Utilities.IsTableEmpty(tLocation) == false then

                tNearbyMexes = M27MapInfo.GetResourcesNearTargetLocation(tLocation, iSearchRange, true)
                if M27Utilities.IsTableEmpty(tNearbyMexes) == false then
                    for iMex, tMexLocation in tNearbyMexes do
                        if bDebugMessages == true then LOG(sFunctionRef..': Updating for tMexLocation ref='..M27Utilities.ConvertLocationToReference(tMexLocation)) end
                        --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers, oUnitToBeDestroyed, iPrimaryEngineerCategoryBuilt)
                        UpdateEngineerActionTrackers(aiBrain, oEngineer, refActionBuildMex, tMexLocation, false, 0, nil, true, nil, M27UnitInfo.refCategoryMex)
                        --TEMPTEST(aiBrain, sFunctionRef..': Just after updating engineer action trackers for the mex location')
                    end
                end
            else
                M27Utilities.ErrorHandler(sFunctionRef..': Warning - tMovementPath is blank - likely error unless happens near start of game')
            end
        end
    end
    --TEMPTEST(aiBrain, sFunctionRef..': End')
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ProcessingEngineerActionForNearbyEnemies(aiBrain, oEngineer)
    --Returns true if are enemies near the engineer such that it's been given an override action (and should be ignored)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'ProcessingEngineerActionForNearbyEnemies'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetEngineerUniqueCount(oEngineer) == 31 and GetGameTimeSeconds() >= 305 then bDebugMessages = true end
    local bAreNearbyEnemies = false
    --if oEngineer and not(oEngineer.Dead) then --We already check this in the engineer reassignment before calling this action


    local iSearchRangeLong = iEngineerMobileEnemySearchRange

    local bNearbyPD, tNearbyUnits
    local bKeepBuilding = true
    local tEngPosition = oEngineer:GetPosition()
    --if aiBrain[M27Overseer.refiSearchRangeForEnemyStructures] > iSearchRangeLong then
    tNearbyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2PlusPD, tEngPosition, math.min(aiBrain[M27Overseer.refiSearchRangeForEnemyStructures], 73), 'Enemy')
    bNearbyPD = not(M27Utilities.IsTableEmpty(tNearbyUnits))
    local bOnPlateau = false
    if not(oEngineer[M27Transport.refiAssignedPlateau] == aiBrain[M27MapInfo.refiOurBasePlateauGroup]) then bOnPlateau = true end

    --Run away
    if bNearbyPD and bOnPlateau then
        --Is the PD on the plateau?
        bNearbyPD = false
        for iUnit, oUnit in tNearbyUnits do
            if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition()) == oEngineer[M27Transport.refiAssignedPlateau] then
                bNearbyPD = true
                break
            end
        end
    end
    if bNearbyPD then
        --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing due to nearby PD') end
        bKeepBuilding = false
        bAreNearbyEnemies = true
        UpdateReclaimSegmentsForEngineerDeathOrNearbyEnemy(aiBrain, oEngineer, true)
        IssueClearCommands({oEngineer})
        IssueMove({oEngineer}, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        if bDebugMessages == true then LOG(sFunctionRef..': Nearby PD so will run away') end
    else
        --end
        tNearbyUnits = aiBrain:GetUnitsAroundPoint(categories.LAND + M27UnitInfo.refCategoryStructure, tEngPosition, iSearchRangeLong, 'Enemy')
        bAreNearbyEnemies = not(M27Utilities.IsTableEmpty(tNearbyUnits))
        if bAreNearbyEnemies and bOnPlateau then
            --Is the enemy on the plateau?
            bAreNearbyEnemies = false
            for iUnit, oUnit in tNearbyUnits do
                if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition()) == oEngineer[M27Transport.refiAssignedPlateau] then
                    bAreNearbyEnemies = true
                    break
                end
            end
        end
        if bAreNearbyEnemies then
            if bDebugMessages == true then LOG(sFunctionRef..': oEngineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' UC='..GetEngineerUniqueCount(oEngineer)..' ahs nearby enemies, will consider if want to try and reclaim, keep building, or run. Engineer plateau='..oEngineer[M27Transport.refiAssignedPlateau]) end
            --Mark nearby reclaim segments as having nearby enemy so will avoid
            UpdateReclaimSegmentsForEngineerDeathOrNearbyEnemy(aiBrain, oEngineer, true)


            --Have nearby long ragne enemies (buildings or mobile units); check if they are mobile as well
            local iSearchRangeShort = 13
            local tMobileEnemies = EntityCategoryFilterDown(categories.MOBILE, tNearbyUnits)
            local bNearbyMobileEnemies = not(M27Utilities.IsTableEmpty(tMobileEnemies))

            if bNearbyMobileEnemies and bOnPlateau then
                --Is the enemy on the plateau?
                bNearbyMobileEnemies = false
                for iUnit, oUnit in tMobileEnemies do
                    if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition()) == oEngineer[M27Transport.refiAssignedPlateau] then
                        bNearbyMobileEnemies = true
                        break
                    end
                end
            end

            if bDebugMessages == true then
                local sUniqueRef = GetEngineerUniqueCount(oEngineer)
                LOG(sFunctionRef..': Eng unique ref='..sUniqueRef..'; LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; iEngineerMobileEnemySearchRange='..iEngineerMobileEnemySearchRange..'; bNearbyMobileEnemies='..tostring(bNearbyMobileEnemies)..'; aiBrain[M27Overseer.refiSearchRangeForEnemyStructures]='..aiBrain[M27Overseer.refiSearchRangeForEnemyStructures]..'; bNearbyPD='..tostring(bNearbyPD or false))
                if bNearbyMobileEnemies == true then LOG(sFunctionRef..': Nearby mobileEnemySize='..table.getn(tMobileEnemies))
                else LOG(sFunctionRef..': No nearby mobile enemies; all enemies incl structures='..table.getn(tNearbyUnits))
                end
            end
            bKeepBuilding = false --default if enemies nearby, will change in some cases
            if bDebugMessages == true then
                local oNearestEnemyUnit
                if M27Utilities.IsTableEmpty(tMobileEnemies) == false then
                    oNearestEnemyUnit = M27Utilities.GetNearestUnit(tMobileEnemies, tEngPosition, aiBrain)
                    LOG(sFunctionRef..': Nearby enemies within a long search range; nearest enemy unit='..oNearestEnemyUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oNearestEnemyUnit)..'; position='..repru(oNearestEnemyUnit:GetPosition())..'; distance to us='..M27Utilities.GetDistanceBetweenPositions(oNearestEnemyUnit:GetPosition(), oEngineer:GetPosition())..'; Combat threat rating of all enemies in a long range='..M27Logic.GetCombatThreatRating(aiBrain, tMobileEnemies, true, nil, nil, false, false)..'; will list out all enemy units and their threat')
                    for iUnit, oUnit in tMobileEnemies do
                        LOG(sFunctionRef..': oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; threat rating='..M27Logic.GetCombatThreatRating(aiBrain, { oUnit }, true, nil, nil, false, false))
                    end
                else
                    LOG(sFunctionRef..': have nearby enemies within a long search range but no mobile enemies')
                end
            end
            local tNearbyEnemiesShort
            if bNearbyMobileEnemies == true then
                tNearbyEnemiesShort = aiBrain:GetUnitsAroundPoint(categories.LAND - categories.BENIGN, tEngPosition, iSearchRangeShort, 'Enemy')
                if bDebugMessages == true then LOG(sFunctionRef..': Are mobile enemies within a long range, seeing if are any units within a short range; is table empty='..tostring(M27Utilities.IsTableEmpty(tNearbyEnemiesShort))) end
            elseif bDebugMessages == true then LOG(sFunctionRef..': No mobile enemies in a long range so wont check for enemies in a short range')
            end
            local oReclaimTarget
            local bCaptureNotReclaim = false
            if bNearbyMobileEnemies == false or (M27Utilities.IsTableEmpty(tNearbyEnemiesShort) and M27Logic.GetCombatThreatRating(aiBrain, tMobileEnemies, true, nil, nil, false, false) <= 10) then
                if bDebugMessages == true then LOG(sFunctionRef..': No very close mobile enemies; bNearbyMobileEnemies='..tostring(bNearbyMobileEnemies)..'; M27Utilities.IsTableEmpty(tNearbyEnemiesShort)='..tostring(M27Utilities.IsTableEmpty(tNearbyEnemiesShort))..'; M27Logic.GetCombatThreatRating(aiBrain, tMobileEnemies, true, nil, nil, false, false)='..M27Logic.GetCombatThreatRating(aiBrain, tMobileEnemies, true, nil, nil, false, false)) end
                --Liekly enemy engineer or scout, so just ignore until it gets close to us; if its a building then instead try to reclaim
                local tEnemyStructures = EntityCategoryFilterDown(categories.STRUCTURE, tNearbyUnits)
                if M27Utilities.IsTableEmpty(tEnemyStructures) == false then
                    local iNearestUnitDist = 100000
                    local iCurUnitDist
                    for iUnit, oUnit in tEnemyStructures do
                        if oUnit:GetFractionComplete() == 1 then --Need this rather than using normal m27utilities.getnearestunit since engineers cant reclaim a unit whose fraction complete is <1
                            iCurUnitDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tEngPosition)
                            if iCurUnitDist < iNearestUnitDist then
                                iNearestUnitDist = iCurUnitDist
                                oReclaimTarget = oUnit
                            end
                        end
                    end
                    if not(oReclaimTarget) and bNearbyMobileEnemies then
                        for iUnit, oUnit in tMobileEnemies do
                            if oUnit:GetFractionComplete() == 1 then
                                iCurUnitDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tEngPosition)
                                if iCurUnitDist < iNearestUnitDist then
                                    iNearestUnitDist = iCurUnitDist
                                    oReclaimTarget = oUnit
                                end
                            end
                        end
                    end
                    --oReclaimTarget = M27Utilities.GetNearestUnit(tEnemyStructures, tEngPosition, aiBrain, true)
                    if bDebugMessages == true then
                        if oReclaimTarget then
                            LOG(sFunctionRef..': Will try and reclaim the nearest enemy unit='..oReclaimTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oReclaimTarget)..'; will draw red around it. Target health='..oReclaimTarget:GetHealth()..'; Target position='..repru(oReclaimTarget:GetPosition()))
                            M27Utilities.DrawLocation(oReclaimTarget:GetPosition(), nil, 2, 20, nil)
                        else LOG(sFunctionRef..': Couldnt find any completed structures to reclaim')
                        end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': No nearby enemies but the threat of all enemies in longer range is less than 10 so likely land scout or engi') end
                    bKeepBuilding = true
                end
            elseif M27Utilities.IsTableEmpty(tNearbyEnemiesShort) == false then
                --Have nearby enemies so try and reclaim
                oReclaimTarget = M27Utilities.GetNearestUnit(tNearbyEnemiesShort, tEngPosition, aiBrain, true)
                if oReclaimTarget.GetFractionComplete and EntityCategoryContains(M27UnitInfo.refCategoryStructure - categories.BENIGN, oReclaimTarget.UnitId) and oReclaimTarget:GetFractionComplete() == 1 and oReclaimTarget:GetHealthPercent() >= 0.8 then bCaptureNotReclaim = true end
                if bDebugMessages == true then LOG(sFunctionRef..': Have '..table.getn(tNearbyEnemiesShort)..' nearby enemies; bCaptureNotReclaim='..tostring(bCaptureNotReclaim)..'; contains structure='..tostring(EntityCategoryContains(categories.STRUCTURE, oReclaimTarget.UnitId))..'; fraction complete='..oReclaimTarget:GetFractionComplete()..'; Health%='..oReclaimTarget:GetHealthPercent()) end
            else
                --Have nearby enemies but they're not close, and they have a threat of at least 10 - ignore if we're almost done building
                local oBeingBuilt, iFractionComplete

                if oEngineer:IsUnitState('Repairing') or oEngineer:IsUnitState('Building') then
                    if oEngineer.GetFocusUnit then
                        oBeingBuilt = oEngineer:GetFocusUnit()
                        if oBeingBuilt and oBeingBuilt.GetFractionComplete then
                            iFractionComplete = oBeingBuilt:GetFractionComplete()
                            if iFractionComplete >= 0.9  and iFractionComplete < 1 then bKeepBuilding = true end
                        end
                        if not(bKeepBuilding) and EntityCategoryContains(M27UnitInfo.refCategoryPD + M27UnitInfo.refCategoryWall, oBeingBuilt.UnitId) then
                            bKeepBuilding = true
                        end
                    end
                elseif oEngineer:IsUnitState('Reclaiming') then
                    bKeepBuilding = true
                end

                --Keep building if we are building PD even if it isnt done yet
                if not(bKeepBuilding) and (oEngineer[refiEngineerCurrentAction] == refActionBuildEmergencyPD or oEngineer[refiEngineerCurrentAction] == refActionFortifyFirebase) then bKeepBuilding = true end
                if bDebugMessages == true then LOG(sFunctionRef..': Have far away enemies that arent close, bKeepBuilding='..tostring(bKeepBuilding)) end
                if bKeepBuilding == false then
                    if bDebugMessages == true then LOG(sFunctionRef..': Dont want to keep building') end
                    --otherwise, run unless it's an enemy engineer in which case try to reclaim, or a mex in which case capture
                    local bOnlyNearbyEngisOrStructure = true
                    if bNearbyMobileEnemies == true then
                        oReclaimTarget = nil
                        local sCurEnemyID
                        for iUnit, oUnit in tNearbyUnits do
                            if M27UnitInfo.IsEnemyUnitAnEngineer(aiBrain, oUnit) == false then
                                --Dont need to know if unit visible to know if its a mex since mex only built on mass deposits
                                if not(EntityCategoryContains(M27UnitInfo.refCategoryMex, oUnit.UnitId)) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': iUnit isnt a mex or engineer') end
                                    bOnlyNearbyEngisOrStructure = false
                                    break
                                elseif bDebugMessages == true then LOG(sFunctionRef..': iUnit is a mex so isnt a threat')
                                end
                            end
                        end

                        --[[local tPossibleEngineers = M27Logic.GetVisibleUnitsOnly(aiBrain, tNearbyEnemiesLong)
            if M27Utilities.IsTableEmpty(tPossibleEngineers) == false and tNearbyEnemiesLong == tNearbyEnemiesLong then
                tPossibleEngineers = EntityCategoryFilterDown(refCategoryEngineer, tPossibleEngineers)
                if M27Utilities.IsTableEmpty(tPossibleEngineers) == false and tPossibleEngineers == tNearbyEnemiesLong then
                    oReclaimTarget = M27Utilities.GetNearestUnit(tNearbyEnemiesShort, oEngineer:GetPosition(), aiBrain, true)
                end
            end--]]
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Only structures nearby, will capture if theyre only mexes') end
                        for iUnit, oUnit in tNearbyUnits do
                            if not(EntityCategoryContains(M27UnitInfo.refCategoryMex, oUnit.UnitId)) then bOnlyNearbyEngisOrStructure = false break end
                        end
                    end

                    if bOnlyNearbyEngisOrStructure then
                        local iNearestUnitDist = 100000
                        local iCurUnitDist
                        for iUnit, oUnit in tNearbyUnits do
                            if oUnit:GetFractionComplete() == 1 then --Need this rather than using normal m27utilities.getnearestunit since engineers cant reclaim a unit whose fraction complete is <1
                                iCurUnitDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tEngPosition)
                                if iCurUnitDist < iNearestUnitDist then
                                    iNearestUnitDist = iCurUnitDist
                                    oReclaimTarget = oUnit
                                end
                            end
                        end
                        if oReclaimTarget and oReclaimTarget.GetUnitId and EntityCategoryContains(M27UnitInfo.refCategoryMex, oReclaimTarget.UnitId) then bCaptureNotReclaim = true end
                    end
                end
            end
            if oReclaimTarget then
                bKeepBuilding = false
                if bDebugMessages == true then LOG(sFunctionRef..': Will tell engineer to reclaim the target. Engineer unitstate='..M27Logic.GetUnitState(oEngineer)) end
                --if oEngineer:IsUnitState('Capturing') == false and oEngineer:IsUnitState('Reclaiming') == false then
                --Do we already have the unit as a target and arent yet in build range, but are moving towards it?
                local bDontClearCommands = false
                if oEngineer:IsUnitState('Moving') or oEngineer:IsUnitState('Capturing') or oEngineer:IsUnitState('Reclaiming') then
                    local iBuildRange = oEngineer:GetBlueprint().Economy.MaxBuildDistance
                    if not(oEngineer:IsUnitState('Moving')) or M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), oReclaimTarget:GetPosition()) > iBuildRange then
                        if oEngineer.GetNavigator and M27Utilities.GetDistanceBetweenPositions(oReclaimTarget:GetPosition(), oEngineer:GetNavigator():GetCurrentTargetPos()) < 0.1 then
                            bDontClearCommands = true
                        end
                    end
                end
                --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing due to nearby enemies') end
                if bDebugMessages == true then LOG(sFunctionRef..': Clearing commands for engi with count='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' and unique ref='..GetEngineerUniqueCount(oEngineer)..' unless it is already t argeting the enemy.  Engineer unit state='..M27Logic.GetUnitState(oEngineer)..'; Distance to target='..M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), oReclaimTarget:GetPosition())..'; bDontClearCOmmands='..tostring(bDontClearCommands)) end
                if not(bDontClearCommands) then
                    IssueClearCommands({oEngineer})
                    if bCaptureNotReclaim then
                        IssueCapture({oEngineer}, oReclaimTarget)
                    else
                        IssueReclaim({oEngineer}, oReclaimTarget)
                    end
                end
                --end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': No reclaim target; bKeepBuilding='..tostring(bKeepBuilding)..'; if engi is near our base then will keep building anyway') end
                if not(bKeepBuilding) and M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oEngineer:GetPosition()) <= 30 then
                    bKeepBuilding = true
                end
                if bKeepBuilding == false then
                    --Nearby enemy but we dont know if its an engineer so we want to run back towards base
                    --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
                    if bDebugMessages == true then LOG(sFunctionRef..': Clearing commands for engi with count='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' and unique ref='..GetEngineerUniqueCount(oEngineer)) end
                    IssueClearCommands({oEngineer})
                    IssueMove({oEngineer}, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                end
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': no nearby enemies') end
        end
    end
    if bKeepBuilding == false then
        --Reset variables relating to the engineer
        --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers, oUnitToBeDestroyed, iPrimaryEngineerCategoryBuilt)
        UpdateEngineerActionTrackers(aiBrain, oEngineer, refActionHasNearbyEnemies, oEngineer:GetPosition(), false, 0)
        oEngineer[refbRecentlyAbortedReclaim] = true
        M27Utilities.DelayChangeVariable(oEngineer, refbRecentlyAbortedReclaim, false, 10)
    elseif bAreNearbyEnemies and M27Logic.IsUnitIdle(oEngineer, false, false, false) and M27Utilities.IsTableEmpty(tNearbyUnits) == false then
        --Presumably a scout or engineer, attack-move towards them as dont want to get new commands yet
        local oNearestUnit = M27Utilities.GetNearestUnit(tNearbyUnits, oEngineer:GetPosition(), aiBrain, nil, nil)
        IssueAggressiveMove({oEngineer}, oNearestUnit:GetPosition())
        local sLocationRef = M27Utilities.ConvertLocationToReference(oNearestUnit:GetPosition())
        aiBrain[reftSpareEngineerAttackMoveTimeByLocation][sLocationRef] = GetGameTimeSeconds()
    end
    --end


    --oEngineer[refbEngineerHasNearbyEnemies] = bAreNearbyEnemies
    if bDebugMessages == true then LOG(sFunctionRef..': End of code, bAreNearEnemies='..tostring(bAreNearbyEnemies)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bAreNearbyEnemies
end

function GetNearestEngineerWithLowerPriority(aiBrain, tEngineers, iCurrentActionPriority, tCurrentActionTarget, iActionRefToGetExistingCount, tsUnitStatesToIgnore, iMaxRangeForPrevEngi, iMaxRangeForNearestEngi, bOnlyGetIdleEngis, bGetInitialEngineer, iMinTechLevelWanted)
    --Returns the nearest engineer
    --Will also look for nearby enemies and get engineers to run away or reclaim, if it's the first time this cycle it's been done
    --If engineer was assigned previously to the action being looked for, will choose that in priority if it's nearby even if its not closest
    --bIgnoreActiveBuilders - if true, then wont consider engineers that are building or repairing a unit (but will consider if assisting, guarding etc.)
    --bOnlyGetIdleEngineers - Only affects engineers that have no action (i.e. doesnt even affect if are moving)
    --iCurrentActionPriority - the condition number (will only get engineers that have a higher condition number)
    --iMaxRangeForPrevEngi -- will only consider prev engineer if its within this range
    --bGetInitialEngineer - if true then will just look for the first idle engineer, ignoring everything else
    --iMinTechLevelWanted - will ignore engis lower than this tech level
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'GetNearestEngineerWithLowerPriority'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local oNearestEngineer
    --local iActionExistingCount = 0
    local bNeedToCheckForNearbyEnemies = false
    local bEngineerIsBusy
    local iCurEngiPriority
    local iClosestDistanceToTarget, iCurDistanceToTarget
    iClosestDistanceToTarget = 10000
    if M27Utilities.IsTableEmpty(tEngineers) == true then
        M27Utilities.ErrorHandler('tEngineers is nil')
    else
        --[[if bDebugMessages == true then LOG(sFunctionRef..': iAction='..iActionRefToGetExistingCount..': Engineer count='..table.getn(tEngineers)..': bNeedToCheckForNearbyEnemies='..tostring(bNeedToCheckForNearbyEnemies)..'; Will cycle through to find nearest if we dont have a previously assigned engineer') end

--Do we have a previous engineer already assigned to the action which is within range that is available?
local bHavePreviousEngineer = false
if bDebugMessages == true then LOG(sFunctionRef..': Checking if have any prev engineers recorded for this action, iActionRefToGetExistingCount='..iActionRefToGetExistingCount) end
--Only do the first check below on non-mexes, since mexes can have multiple engis building multiple mexes at once (all other buildings aim to just have 1 primary unit building)
if not(iActionRefToGetExistingCount==refActionBuildMex) and aiBrain[reftPrevEngineerAssignmentsByAction] and aiBrain[reftPrevEngineerAssignmentsByAction][iActionRefToGetExistingCount] then
if bDebugMessages == true then LOG(sFunctionRef..': iActionRefToGetExistingCount='..iActionRefToGetExistingCount..': Checking previous engineers, size of table='..table.getn(aiBrain[reftPrevEngineerAssignmentsByAction][iActionRefToGetExistingCount])) end
for iPrevEngi, oPrevEngi in aiBrain[reftPrevEngineerAssignmentsByAction][iActionRefToGetExistingCount] do
    if not(oPrevEngi.Dead) and oPrevEngi[refiEngineerCurrentAction] == nil then
        iCurDistanceToTarget = M27Utilities.GetDistanceBetweenPositions(tCurrentActionTarget, oPrevEngi:GetPosition())
        if iCurDistanceToTarget <= iMaxRangeForPrevEngi then
            if bDebugMessages == true then
                local sNearestEngiName = 'nil'
                if oNearestEngineer then sNearestEngiName = oNearestEngineer.M27LifetimeUnitCount if sNearestEngiName == nil then sNearestEngiName = 'nil' end end
                local sPrevEngiName = oPrevEngi.M27LifetimeUnitCount if sPrevEngiName == nil then sPrevEngiName = 'nil' end
                LOG(sFunctionRef..': Are replacing nearest engineer with previous engineer.  iActionRefToGetExistingCount='..iActionRefToGetExistingCount..'sPrevEngiName='..sPrevEngiName..'; sNearestEngiName='..sNearestEngiName..'; iPrevEngi='..iPrevEngi)
            end
            bHavePreviousEngineer = true
            oNearestEngineer = oPrevEngi
            break
        end
        bHavePreviousEngineer = true
        oNearestEngineer = oPrevEngi
        break
    else
        LOG(sFunctionRef..': iPrevEngi '..iPrevEngi..' has a current action='..oPrevEngi[refiEngineerCurrentAction])
    end
end
end--]]
        --[[if bHavePreviousEngineer == false then
if aiBrain[reftPrevEngineerAssignmentsByLocation] then
    local sLocationRef = M27Utilities.ConvertLocationToReference(tCurrentActionTarget)
    if aiBrain[reftPrevEngineerAssignmentsByLocation][sLocationRef] then
        local oPrevEngi = aiBrain[reftPrevEngineerAssignmentsByLocation][sLocationRef][iActionRefToGetExistingCount]
        if oPrevEngi and not(oPrevEngi.Dead) and oPrevEngi[refiEngineerCurrentAction] == nil then
            if oPrevEngi.GetPosition then
                --if M27Utilities.GetDistanceBetweenPositions(oPrevEngi:GetPosition(), oNearestEngineer:GetPosition() <= iMaxRangeForPrevEngi) then
                    bHavePreviousEngineer = true
                    oNearestEngineer = oPrevEngi
                --end
            else
                M27Utilities.ErrorHandler('oPrevEngi doesnt have a position; iActionRef='..iActionRefToGetExistingCount..'; sLocationRef='..sLocationRef..'; Will send log of the blueprint if its not nil next')
                if oPrevEngi.GetUnitId then LOG('prev Engi Unit ID='..oPrevEngi.UnitId) else LOG('Prev engi doesnt have unit ID so isnt a unit') end
                LOG('oPrevEngi result of istableempty='..tostring(M27Utilities.IsTableEmpty(oPrevEngi)))
                if oPrevEngi[refEngineerAssignmentEngineerRef] and oPrevEngi[refEngineerAssignmentEngineerRef].GetUnitId then LOG('If do the subtable then its an engineer object') end
            end
        end
    end
end
end--]]
        --if bHavePreviousEngineer == false then
        --Filter tEngineers to min tech level
        if iMinTechLevelWanted > 1 then
            local iTechRestrictedEngiCategory
            if iMinTechLevelWanted == 3 then iTechRestrictedEngiCategory = refCategoryEngineer * categories.TECH3
            else iTechRestrictedEngiCategory = refCategoryEngineer * categories.TECH3 + refCategoryEngineer * categories.TECH2 end

            tEngineers = EntityCategoryFilterDown(iTechRestrictedEngiCategory, tEngineers)
            if bDebugMessages == true then LOG(sFunctionRef..': Want engineers with min tech level='..iMinTechLevelWanted) end
        end
        if M27Utilities.IsTableEmpty(tEngineers) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': tEngineers size='..table.getn(tEngineers)) end
            for iEngineer, oEngineer in tEngineers do
                if bDebugMessages == true then LOG(sFunctionRef..': Considering engineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer)..'; Unit state='..M27Logic.GetUnitState(oEngineer)) end
                if bGetInitialEngineer == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': Want one of the initial T1 engineers we first built') end
                    if M27UnitInfo.GetUnitLifetimeCount(oEngineer) <= aiBrain[refiInitialMexBuildersWanted] and M27UnitInfo.GetUnitTechLevel(oEngineer) == 1 then
                        oNearestEngineer = oEngineer
                        break
                    end
                else
                    if M27UnitInfo.IsUnitValid(oEngineer) then
                        if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..': Engineer='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer)..'; No nearby enemies so will consider action') end
                        --Does the engineer have a higher condition (so lower priority) assigned?
                        iCurEngiPriority = oEngineer[refiEngineerConditionNumber]
                        if iCurEngiPriority == nil then iCurEngiPriority = 10000 end
                        if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..': iCurEngiPriority='..iCurEngiPriority..': iCurrentActionPriority='..iCurrentActionPriority) end
                        if iCurEngiPriority > iCurrentActionPriority then
                            --Check engineer state/if is busy:
                            bEngineerIsBusy = false
                            if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..': Engineer state='..M27Logic.GetUnitState(oEngineer)) end
                            if bOnlyGetIdleEngis == true then bEngineerIsBusy = not(M27Logic.IsUnitIdle(oEngineer, false, false, true, true))
                            else
                                for iState, sState in tsUnitStatesToIgnore do
                                    if oEngineer:IsUnitState(sState) == true then bEngineerIsBusy = true break end
                                end
                            end

                            if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..': bEngineerIsBusy='..tostring(bEngineerIsBusy)..'; M27Logic.IsUnitIdle(oEngineer, false, false, true, true)='..tostring(M27Logic.IsUnitIdle(oEngineer, false, false, true, true))) end
                            if bEngineerIsBusy == false then
                                if not(iActionRefToGetExistingCount == refActionSpare or iActionRefToGetExistingCount == refActionPlateauSpareAction) then
                                    iCurDistanceToTarget = M27Utilities.GetDistanceBetweenPositions(tCurrentActionTarget, oEngineer:GetPosition())
                                    if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..': iCurDistanceToTarget='..iCurDistanceToTarget..'; iClosestDistanceToTarget='..iClosestDistanceToTarget) end
                                    if iCurDistanceToTarget < iClosestDistanceToTarget then
                                        if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..': Have a valid engineer') end
                                        iClosestDistanceToTarget = iCurDistanceToTarget
                                        oNearestEngineer = oEngineer
                                    end
                                else oNearestEngineer = oEngineer break end
                            end
                        end
                    elseif bDebugMessages == true then LOG(sFunctionRef..': Engineer isnt valid anymore')
                    end
                end
            end
        end
        --end
        if oNearestEngineer and not(iActionRefToGetExistingCount == refActionSpare or iActionRefToGetExistingCount == refActionPlateauSpareAction) then
            if iClosestDistanceToTarget > iMaxRangeForNearestEngi and not (bGetInitialEngineer) then
                if bDebugMessages == true then LOG(sFunctionRef..': iClosestDistanceToTarget='..iClosestDistanceToTarget..'; iMaxRangeForNearestEngi='..iMaxRangeForNearestEngi..'; therefore engineer too far away') end
                oNearestEngineer = nil
            end
        end
    end
    if bDebugMessages == true then
        if oNearestEngineer == nil then LOG(sFunctionRef..': No engineer found')
        else LOG(sFunctionRef..': Found engineer='..oNearestEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oNearestEngineer))
        end
    end
    if oNearestEngineer.GetPlan then M27Utilities.ErrorHandler('oNearestEngineer is a platoon, plan='..oNearestEngineer:GetPlan()..(oNearestEngineer[M27PlatoonUtilities.refiPlatoonCount] or 'nil')) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oNearestEngineer
end

function DelayedSpareEngineerClearAction(aiBrain, oEngineer, iDelaySeconds)
    --Will wait iDelay seconds, before clearing engineer's actions if it's guarding a unit and its action is still spare
    local bDebugMessages = false

    local sFunctionRef = 'DelayedSpareEngineerClearAction'
    local iOrigAction = oEngineer[refiEngineerCurrentAction]
    if not(oEngineer[refbActiveDelayedTargetRechecker]) then
        oEngineer[refbActiveDelayedTargetRechecker] = true
        WaitSeconds(iDelaySeconds)
        if M27UnitInfo.IsUnitValid(oEngineer) then
            oEngineer[refbActiveDelayedTargetRechecker] = false
            --if GetEngineerUniqueCount(oEngineer) == 58 and GetGameTimeSeconds() >= 2040 then bDebugMessages = true else bDebugMessages = false end
            if oEngineer[refiEngineerCurrentAction] == iOrigAction or oEngineer[refiEngineerCurrentAction] == refActionSpare or oEngineer[refiEngineerCurrentAction] == refActionPlateauSpareAction then
                --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
                if bDebugMessages == true then LOG(sFunctionRef..': About to clear engineer '..GetEngineerUniqueCount(oEngineer)..' actions as it still has a spare action') end
                IssueClearCommands({oEngineer})
                ClearEngineerActionTrackers(aiBrain, oEngineer, true)
            end
        end
    end
    --ReassignEngineers(aiBrain, true, {oEngineer})
end

function IssuePlateauSpareEngineerAction(aiBrain, oEngineer)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IssuePlateauSpareEngineerAction'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetEngineerUniqueCount(oEngineer) == 58 and GetGameTimeSeconds() >= 2040 then bDebugMessages = true else bDebugMessages = false end

    local oLandFactory
    local iPlateauGroup = oEngineer[M27Transport.refiAssignedPlateau]
    if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup][M27MapInfo.subrefPlateauLandFactories]) == false then
        for iFactory, oFactory in aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup][M27MapInfo.subrefPlateauLandFactories] do
            if M27UnitInfo.IsUnitValid(oFactory) then
                oLandFactory = oFactory
                break
            end
        end
    end

    if oLandFactory then
        --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
        IssueClearCommands({oEngineer})
        IssueGuard({oEngineer}, oLandFactory)
    else
        --Attack-move to a random location
        if bDebugMessages == true then LOG(sFunctionRef..': iPlateauGroup='..iPlateauGroup..'; aiBrain[M27MapInfo.subrefPlateauMaxXZ]='..repru(aiBrain[M27MapInfo.subrefPlateauMaxXZ])..'; aiBrain[M27MapInfo.subrefPlateauMinXZ]='..repru(aiBrain[M27MapInfo.subrefPlateauMinXZ])) end

        local iSearchSizeMax
        local iSearchSizeMin
        if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.subrefPlateauMaxXZ]) then iSearchSizeMin = 2 iSearchSizeMax = 6
        else
            iSearchSizeMax = math.max(4, math.min(aiBrain[M27MapInfo.subrefPlateauMaxXZ][iPlateauGroup][1] - aiBrain[M27MapInfo.subrefPlateauMinXZ][iPlateauGroup][1], aiBrain[M27MapInfo.subrefPlateauMaxXZ][iPlateauGroup][2] - aiBrain[M27MapInfo.subrefPlateauMinXZ][iPlateauGroup][2]) * 0.5)
            iSearchSizeMin = math.min(15, math.max(iSearchSizeMax * 0.2, iSearchSizeMax - 5, 2))
        end
        local tRandomTargetLocation = M27Logic.GetRandomPointInAreaThatCanPathTo(M27UnitInfo.refPathingTypeAmphibious, iPlateauGroup, oEngineer:GetPosition(), iSearchSizeMax, iSearchSizeMin)
        if M27Utilities.IsTableEmpty(tRandomTargetLocation) then
            --Recheck pathing
            if bDebugMessages == true then LOG(sFunctionRef..': Failed to find somewhere to path to, will draw engineer position in red. PlateauGroup='..oEngineer[M27Transport.refiAssignedPlateau]..'; position='..repru(oEngineer:GetPosition()))
                M27Utilities.DrawLocation(oEngineer:GetPosition(), nil, 2, 100, nil)
            end
            if M27MapInfo.RecheckPathingOfLocation(M27UnitInfo.refPathingTypeAmphibious, oEngineer, oEngineer:GetPosition(), nil, nil) then
                tRandomTargetLocation = M27Logic.GetRandomPointInAreaThatCanPathTo(M27UnitInfo.refPathingTypeAmphibious, iPlateauGroup, oEngineer:GetPosition(), 40, 15)
            end
        end
        if M27Utilities.IsTableEmpty(tRandomTargetLocation) then
            tRandomTargetLocation = oEngineer:GetPosition()
            tRandomTargetLocation[1] = tRandomTargetLocation[1] + math.random(1, 20) * math.random(-1, 1)
            tRandomTargetLocation[3] = tRandomTargetLocation[3] + math.random(1, 20) * math.random(-1, 1)
            tRandomTargetLocation[2] = GetSurfaceHeight(tRandomTargetLocation[1], tRandomTargetLocation[3])
        end
        --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
        IssueClearCommands({oEngineer})
        IssueAggressiveMove({oEngineer}, tRandomTargetLocation)
        local sLocationRef = M27Utilities.ConvertLocationToReference(tRandomTargetLocation)
        aiBrain[reftSpareEngineerAttackMoveTimeByLocation][sLocationRef] = GetGameTimeSeconds()
    end
    ForkThread(DelayedSpareEngineerClearAction, aiBrain, oEngineer, math.random(15, 25))
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function IssueSpareEngineerAction(aiBrain, oEngineer)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IssueSpareEngineerAction'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if oEngineer.UnitId == 'xsl0105' and M27UnitInfo.GetUnitLifetimeCount(oEngineer) == 4 and aiBrain:GetArmyIndex() == 3 and GetGameTimeSeconds() >= 1326 and GetGameTimeSeconds() <= 1327 then bDebugMessages = true end


    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end

    --Action already cleared in previous code
    local iCurSearchDistance = 40
    --local iRangeIncreaseFactor = 2 --Will increase search distance by this factor each cycle
    local bHaveAction = false
    local tTempTarget
    local rPlayableArea = M27MapInfo.rMapPlayableArea
    local iMapSizeX = rPlayableArea[3] - rPlayableArea[1]
    local iMapSizeZ = rPlayableArea[4] - rPlayableArea[2]

    local iMaxSearchRange = math.min(iMapSizeX, iMapSizeZ)

    local iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS')
    local tEngineerPosition = oEngineer:GetPosition()
    local tNearbyBuildings
    local oBuildingProducing

    local bDestroy = false

    --while bHaveAction == false do
    --Check for reclaim

    if bDebugMessages == true then
        LOG(sFunctionRef..': About to start checking for spare engi actions for engi with unique ref='..GetEngineerUniqueCount(oEngineer)..'; iMassStoredRatio='..iMassStoredRatio)
    end

    local tLocationToSearchFrom
    local iDistToStart = M27Utilities.GetDistanceBetweenPositions(tEngineerPosition,M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
    if iDistToStart <= 30 then tLocationToSearchFrom = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber] else tLocationToSearchFrom = tEngineerPosition end

    --Check if we have a reasonable amount of power
    local iNetCurEnergyIncome = aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome]
    local iEnergyStored = aiBrain:GetEconomyStored('ENERGY')
    local iEnergyPercentStorage = aiBrain:GetEconomyStoredRatio('ENERGY')
    local iStorageModIfUpgrading = 0
    if oEngineer:IsUnitState('Upgrading') or oEngineer:IsUnitState('Building') then iStorageModIfUpgrading = -0.1 end
    iEnergyPercentStorage = iEnergyPercentStorage + iStorageModIfUpgrading
    iNetCurEnergyIncome = iNetCurEnergyIncome * (1 + iStorageModIfUpgrading)
    local bHaveLowPower = false
    --Are we power stalling or have we in the last 5s?
    if aiBrain[M27EconomyOverseer.refbStallingEnergy] or (aiBrain:GetEconomyStoredRatio('ENERGY') < 1 and GetGameTimeSeconds() - aiBrain[M27EconomyOverseer.refiLastEnergyStall] <= 5) then
        if bDebugMessages == true then LOG(sFunctionRef..': Are stalling energy or recently stalled so have low power') end
        bHaveLowPower = true
    else
        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
            iCurSearchDistance = 70
            if iNetCurEnergyIncome < 2 or iEnergyPercentStorage < 0.98 then bHaveLowPower = true end
        else
            if iNetCurEnergyIncome < 0 and iEnergyPercentStorage < 0.9 then
                if bDebugMessages == true then LOG(sFunctionRef..': Have negative energy income and less than 90% stored so low power') end
                bHaveLowPower = true
            elseif iEnergyPercentStorage < 0.2 then
                if bDebugMessages == true then LOG(sFunctionRef..': have less than 20% energy stored so low power') end
                bHaveLowPower = true
            end
        end
    end

    local bHaveLowMass = M27Conditions.HaveLowMass(aiBrain)
    local bACUIsUpgrading = false
    local oACU = M27Utilities.GetACU(aiBrain)
    if oACU:IsUnitState('Upgrading') then bACUIsUpgrading = true end
    local iCategoryToSearchFor = M27UnitInfo.refCategoryStructure + M27UnitInfo.refCategoryExperimentalLevel
    if bHaveLowPower then
        iCurSearchDistance = math.max(iCurSearchDistance, 50)
        iCategoryToSearchFor = refCategoryPower
    elseif aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then iCategoryToSearchFor = refCategoryPower + refCategoryAirFactory
    end

    if aiBrain[refbLastSpareEngineerHadNoAction] then iCurSearchDistance = iCurSearchDistance + 15 end

    --Help ACU if its nearby and upgrading
    if bDebugMessages == true then LOG(sFunctionRef..': If ACU is upgrading will see if want to help it. bACUIsUpgrading='..tostring(bACUIsUpgrading)..'; bHaveLowPower='..tostring(bHaveLowPower)..'; iEnergyPercentStorage='..iEnergyPercentStorage) end
    if bACUIsUpgrading and not(bHaveLowPower) then
        local bCanHelpACU = false

        local iDistToACU = M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), oACU:GetPosition())
        local iEngineersAlreadyHelpingACU = 0
        if M27Utilities.IsTableEmpty(aiBrain[reftEngineersHelpingACU]) == false then iEngineersAlreadyHelpingACU = table.getsize(aiBrain[reftEngineersHelpingACU]) end
        if iDistToACU <= 10 or (iDistToACU <= 25 and oACU:GetWorkProgress() < 0.95 and iEngineersAlreadyHelpingACU <= 15) then
            bCanHelpACU = true
        elseif iEngineersAlreadyHelpingACU <= 8 then
            local iSpeed = oEngineer:GetBlueprint().Physics.MaxSpeed
            local iTimeToGetToACU = math.max(0, iDistToACU - 6) / iSpeed
            local iCurGameTime = math.floor(GetGameTimeSeconds())
            local iTimeForACUToCompleteUpgrade
            if oACU[M27Overseer.reftACURecentUpgradeProgress][iCurGameTime - 11] and oACU[M27Overseer.reftACURecentUpgradeProgress][iCurGameTime - 1] then
                iTimeForACUToCompleteUpgrade = (1 - oACU[M27Overseer.reftACURecentUpgradeProgress][iCurGameTime - 1]) / ((oACU[M27Overseer.reftACURecentUpgradeProgress][iCurGameTime - 1] - oACU[M27Overseer.reftACURecentUpgradeProgress][iCurGameTime - 11]) / 10)
            else
                --ACU must have only just started, so assume it will complete based on its build power
                iTimeForACUToCompleteUpgrade = (M27UnitInfo.GetUpgradeBuildTime(oACU, oACU[M27UnitInfo.refsUpgradeRef]) or 1) / oACU:GetBlueprint().Economy.BuildRate
            end
            if bDebugMessages == true then LOG(sFunctionRef..': ACU is upgrading.  iTimeToGetToACU='..iTimeToGetToACU..'; iTimeForACUToCompleteUpgrade='..iTimeForACUToCompleteUpgrade..'; Engineer LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer)..'; Engineer position='..repru(oEngineer:GetPosition())..'; ACU position='..repru(oACU:GetPosition())) end
            if iTimeToGetToACU * 1.05 < iTimeForACUToCompleteUpgrade then
                bCanHelpACU = true
            elseif bDebugMessages == true then LOG(sFunctionRef..': Wont help ACU as will take too long to get to ACU. reftACURecentUpgradeProgress='..repru(oACU[M27Overseer.reftACURecentUpgradeProgress])..'; refsUpgradeRef='..oACU[M27UnitInfo.refsUpgradeRef]..'; Upgrade time='..(M27UnitInfo.GetUpgradeBuildTime(oACU, oACU[M27UnitInfo.refsUpgradeRef]) or 1))
            end
            if bCanHelpACU then
                --If ACU isn't close to our base or the engineer, then limit the number of spare engineers helping the ACU
                if M27Utilities.GetDistanceBetweenPositions(oACU:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) > 120 then
                    local iSpareEngisHelpingACU = 0
                    if M27Utilities.IsTableEmpty(aiBrain[reftEngineersHelpingACU]) == false then
                        for iSpareEngi, oSpareEngi in aiBrain[reftEngineersHelpingACU] do
                            if M27UnitInfo.IsUnitValid(oSpareEngi) and oSpareEngi[refbHelpingACU] then iSpareEngisHelpingACU = iSpareEngisHelpingACU + 1 end
                        end
                    end
                    if iSpareEngisHelpingACU >= 10 then bCanHelpACU = false end
                end
            end
        end
        if bCanHelpACU then
            --Help ACU
            if bDebugMessages == true then LOG(sFunctionRef..': Will tell engineer to help ACU') end
            bHaveAction = true
            IssueGuard({oEngineer}, oACU)
            oEngineer[refbHelpingACU] = true

            table.insert(aiBrain[reftEngineersHelpingACU], oEngineer)
        end
    end
    local iOurPathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tEngineerPosition)
    if bHaveAction == false then
        --Are there nearby unclaimed mexes? Only consider if we are far from base
        if M27Utilities.GetDistanceBetweenPositions(tEngineerPosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) >= 125 then

            --[a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
            if M27Utilities.IsTableEmpty(M27MapInfo.tMexByPathingAndGrouping[M27UnitInfo.refPathingTypeAmphibious][iOurPathingGroup]) == false then
                local iClosestDist = 40 --Not interested in mexes further away than this
                local tClosestMex
                local iCurDist
                for iMex, tMex in M27MapInfo.tMexByPathingAndGrouping[M27UnitInfo.refPathingTypeAmphibious][iOurPathingGroup] do
                    iCurDist = M27Utilities.GetDistanceBetweenPositions(tEngineerPosition, tMex)
                    if iCurDist < iClosestDist then
                        --Is the mex unclaimed?
                        if M27Conditions.IsMexUnclaimed(aiBrain, tMex, false, false, true) then
                            tClosestMex = tMex
                            iClosestDist = iCurDist
                        end
                    end
                end
                if tClosestMex then
                    --Do we have an engineer already assigned to build on this mex that is close enough to it that we wont save much time by building it ourselves?  Also ignore if we have queued up to build a t3 mex
                    local sLocationRef = M27Utilities.ConvertLocationToStringRef(tClosestMex)
                    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][refActionBuildT3MexOverT2]) then
                        local bBuildMex = true
                        local iClosestAssignedEngi = 10000
                        if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][refActionBuildMex]) == false then
                            for iSubtable, oAssignedEngi in aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][refActionBuildMex] do
                                iCurDist = M27Utilities.GetDistanceBetweenPositions(oAssignedEngi:GetPosition(), tClosestMex)
                                if iCurDist < iClosestAssignedEngi then iClosestAssignedEngi = iCurDist end
                            end
                        end

                        if iClosestAssignedEngi - iClosestDist <= 60 then
                            bBuildMex = false
                        end

                        if bBuildMex then
                            --BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tAlternativePositionToLookFrom, bLookForPartCompleteBuildings, bLookForQueuedBuildings, oUnitToBuildBy, bNeverBuildRandom, iOptionalCategoryForStructureToBuild, bBuildCheapestStructure, iOptionalEngiActionRef)
                            local tBuildLocation = BuildStructureAtLocation(aiBrain, oEngineer, M27UnitInfo.refCategoryT1Mex, 1, nil, tClosestMex, true, false, nil, nil, nil, true)
                            if M27Utilities.IsTableEmpty(tBuildLocation) == false then
                                bHaveAction = true
                            end
                        end
                    end
                end
            end


        end

        if not(bHaveAction) then
            if iMassStoredRatio < 0.60 and aiBrain:GetEconomyStored('MASS') < 5000 then
                tTempTarget = M27MapInfo.GetNearestReclaimSegmentLocation(tEngineerPosition, iCurSearchDistance, 2, aiBrain)
                --Setting min value to 1 caused issue with wall segment
                if tTempTarget then
                    --Has it been at least 14s since an engineer was told to attack-move here? (attack-move normally will be refreshed after min of 15s if engi had an action)
                    local sLocationRef = M27Utilities.ConvertLocationToReference(tTempTarget)
                    if GetGameTimeSeconds() - (aiBrain[reftSpareEngineerAttackMoveTimeByLocation][sLocationRef] or -1000) >= 14 then
                        --Can we path here?
                        if M27Utilities.GetDistanceBetweenPositions(tTempTarget, tEngineerPosition) <= (oEngineer:GetBlueprint().Economy.MaxBuildDistance - 0.5) or M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tTempTarget) == iOurPathingGroup then
                            bHaveAction = true
                            IssueAggressiveMove({oEngineer}, tTempTarget )
                            if bDebugMessages == true then LOG(sFunctionRef..': Have nearby reclaim, at location '..repru(tTempTarget)) end
                            local iReclaimSegmentX, iReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(tTempTarget)
                            M27MapInfo.UpdateReclaimDataNearSegments(iReclaimSegmentX, iReclaimSegmentZ, 1, { aiBrain })
                            aiBrain[reftSpareEngineerAttackMoveTimeByLocation][sLocationRef] = GetGameTimeSeconds()
                        end
                    end
                end
            end
        end
    end
    if bHaveAction == false then
        if bHaveLowMass and M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftUnitsToReclaim]) == false then
            --See if we are near any of the units to be reclaimed
            local iNearestUnit = 60 --Dont want to try and reclaim if the unit is further away than this
            local oNearestUnit
            local iCurDistance
            for iUnit, oUnit in aiBrain[M27EconomyOverseer.reftUnitsToReclaim] do
                if M27UnitInfo.IsUnitValid(oUnit) and oUnit:GetHealth() >= 50 then
                    iCurDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tEngineerPosition)
                    if iCurDistance < iNearestUnit then
                        iNearestUnit = iCurDistance
                        oNearestUnit = oUnit
                    end
                end
            end
            if oNearestUnit then
                bHaveAction = true
                IssueReclaim({oEngineer}, oNearestUnit)
            end
        elseif not(bACUIsUpgrading and bHaveLowMass) then
            --Do we have too many engineers of this tech level and have low mass? If so ctrl-K if are near base
            if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 2 and M27Conditions.HaveLowMass(aiBrain) then
                local iCurTechLevel = M27UnitInfo.GetUnitTechLevel(oEngineer)
                if iCurTechLevel < aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] then
                    local iCurTime = math.floor(GetGameTimeSeconds())
                    if iCurTime - aiBrain[refiTimeOfLastEngiSelfDestruct] > 0.99 and M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 90 then
                        local iMaxEngisOfThisTechLevelWanted = 30
                        local iHighestTechUnits = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * M27UnitInfo.ConvertTechLevelToCategory(aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]))
                        if iHighestTechUnits >= 10 then
                            if bHaveLowMass then iMaxEngisOfThisTechLevelWanted = 5
                            else iMaxEngisOfThisTechLevelWanted = 8
                            end
                        elseif bHaveLowMass and iHighestTechUnits >= 5 then
                            iMaxEngisOfThisTechLevelWanted = 12
                        end
                        local iEngisOfTechLevel = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * M27UnitInfo.ConvertTechLevelToCategory(iCurTechLevel))
                        if iHighestTechUnits >= 3 and iEngisOfTechLevel > iMaxEngisOfThisTechLevelWanted then
                            --Double threshold if we have any factories below tech3
                            if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAllFactories * M27UnitInfo.ConvertTechLevelToCategory(iCurTechLevel)) == 0 or iEngisOfTechLevel < iMaxEngisOfThisTechLevelWanted * 2 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Have too many engineers of the current tech level so will kill engineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' with UC='..GetEngineerUniqueCount(oEngineer)) end
                                ClearEngineerActionTrackers(aiBrain, oEngineer, true)
                                oEngineer:Kill()
                                bDestroy = true
                                bHaveAction = true
                            end
                        end
                    end
                end
            end

            if bDestroy == false then
                --Prioritise any HQ upgrades that are nearby
                if bDebugMessages == true then LOG(sFunctionRef..': Checking whether we have active HQ upgrades; Is the table empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]))) end
                if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]) == false then
                    tNearbyBuildings = {}
                    if bDebugMessages == true then LOG(sFunctionRef..': Have active HQ upgrades will cycle through each one, size of table='..table.getn(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades])) end
                    for iUnit, oUnit in aiBrain[M27EconomyOverseer.reftActiveHQUpgrades] do
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; will see if it is close enough to tLocationToSearchFrom='..repru(tLocationToSearchFrom)) end
                        if M27UnitInfo.IsUnitValid(oUnit) and M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tLocationToSearchFrom) <= iCurSearchDistance then
                            if bDebugMessages == true then LOG(sFunctionRef..': Unit is close enough so adding to list of nearby buildings') end
                            table.insert(tNearbyBuildings, oUnit)
                        end
                    end
                end
                --Prioritise part-built experimentals if no HQ upgrades and dont have low mass
                if M27Utilities.IsTableEmpty(tNearbyBuildings) and (aiBrain[refiLastExperimentalReference] or aiBrain[refiLastSecondExperimentalRef]) and not(M27Conditions.HaveLowMass(aiBrain)) and aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] >= 100 then
                    local tExperimentals = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryExperimentalLevel, tLocationToSearchFrom, math.max(iCurSearchDistance, 110), 'Ally')
                    if M27Utilities.IsTableEmpty(tExperimentals) == false then
                        local oClosestByDistExperimental
                        local oClosestByConstructionExperimental
                        local iClosestExperimentalDist = 10000
                        local iHighestExperimentalConstruction = 0
                        local iCurDist


                        tNearbyBuildings = {}
                        for iUnit, oUnit in tExperimentals do
                            iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tEngineerPosition)
                            if oUnit:GetFractionComplete() <= 0.95 or iCurDist <= 10 then
                                if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition()) == iOurPathingGroup then
                                    if iCurDist < iClosestExperimentalDist then
                                        oClosestByDistExperimental = oUnit
                                        iClosestExperimentalDist = iCurDist
                                    end
                                    if oUnit:GetFractionComplete() > iHighestExperimentalConstruction then
                                        iHighestExperimentalConstruction = oUnit:GetFractionComplete()
                                        oClosestByConstructionExperimental = oUnit
                                    end
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have lots of mass and a nearby under construction experimental so will assist this, based on the closest to completion or closest to us') end
                                end
                            end
                        end
                        --Decide on which experimental to assist if have multiple
                        if oClosestByDistExperimental then
                            if bDebugMessages == true then LOG(sFunctionRef..': oClosestByDistExperimental='..oClosestByDistExperimental.UnitId..M27UnitInfo.GetUnitLifetimeCount(oClosestByDistExperimental)..'; Fraction complete='..oClosestByDistExperimental:GetFractionComplete()..'; iClosestDist='..iClosestExperimentalDist..'; oClosestByConstructionExperimental='..oClosestByConstructionExperimental.UnitId..M27UnitInfo.GetUnitLifetimeCount(oClosestByConstructionExperimental)..'; Fraction complete='..oClosestByConstructionExperimental:GetFractionComplete()..'; Dist to engi='..M27Utilities.GetDistanceBetweenPositions(tEngineerPosition, oClosestByConstructionExperimental:GetPosition())) end
                            if oClosestByDistExperimental == oClosestByConstructionExperimental then
                                table.insert(tNearbyBuildings, oClosestByDistExperimental)
                            else
                                --Pick the closest one if it's not that far behind and is a lot closer
                                if iHighestExperimentalConstruction - oClosestByDistExperimental:GetFractionComplete() <= 0.05 and M27Utilities.GetDistanceBetweenPositions(oClosestByConstructionExperimental:GetPosition(), tEngineerPosition) - iClosestExperimentalDist >= 40 then
                                    table.insert(tNearbyBuildings, oClosestByDistExperimental)
                                else
                                    table.insert(tNearbyBuildings, oClosestByConstructionExperimental)
                                end
                            end
                        end
                    end
                end

                if M27Utilities.IsTableEmpty(tNearbyBuildings) == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': Adding nearby buildings') end
                    tNearbyBuildings = aiBrain:GetUnitsAroundPoint(iCategoryToSearchFor, tLocationToSearchFrom, iCurSearchDistance, 'Ally')
                end
                if M27Utilities.IsTableEmpty(tNearbyBuildings) == false then
                    --If have low mass or are in eco mode then prioritise mexes, subject to wanting to tech up
                    if bDebugMessages == true then LOG(sFunctionRef..': Cycling through each unit to see if it can be helped') end
                    local tiCategoriesByPriority

                    if bHaveLowMass or (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle) then
                        if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers]) == false then
                            tiCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryMex, M27UnitInfo.refCategoryPower, M27UnitInfo.refCategoryAllFactories, M27UnitInfo.refCategoryExperimentalLevel, M27UnitInfo.refCategoryStructure - M27UnitInfo.refCategoryAllFactories - M27UnitInfo.refCategoryPower - M27UnitInfo.refCategorySMD}
                        else tiCategoriesByPriority = {M27UnitInfo.refCategoryMex, M27UnitInfo.refCategoryPower, M27UnitInfo.refCategoryAllFactories, M27UnitInfo.refCategoryExperimentalLevel, M27UnitInfo.refCategoryStructure - M27UnitInfo.refCategoryAllFactories - M27UnitInfo.refCategoryPower - M27UnitInfo.refCategorySMD}
                        end
                    else
                        if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers]) == false then
                            tiCategoriesByPriority = {M27UnitInfo.refCategorySMD, M27UnitInfo.refCategoryExperimentalLevel, M27UnitInfo.refCategoryStructure - M27UnitInfo.refCategorySMD}
                        else
                            tiCategoriesByPriority = {M27UnitInfo.refCategoryExperimentalLevel, M27UnitInfo.refCategoryStructure - M27UnitInfo.refCategorySMD}
                        end
                    end

                    local tBuildingsOfPriority = {}
                    for iCategoryType, iCategoryRef in tiCategoriesByPriority do
                        tBuildingsOfPriority = EntityCategoryFilterDown(iCategoryRef, tNearbyBuildings)
                        if M27Utilities.IsTableEmpty(tBuildingsOfPriority) == false then
                            for iBuilding, oBuilding in tBuildingsOfPriority do
                                if not(oBuilding[M27EconomyOverseer.refbWillReclaimUnit]) then


                                    --for iBuilding, oBuilding in tNearbyBuildings do
                                    if oBuilding.GetFractionComplete and oBuilding:GetFractionComplete() < 0.99 then
                                        bHaveAction = true
                                        IssueRepair({ oEngineer}, oBuilding)
                                        if bDebugMessages == true then LOG(sFunctionRef..': Have a part-complete building that will assist') end
                                    elseif (not(oBuilding.IsPaused) or not(oBuilding:IsPaused())) then
                                        if oBuilding.IsUnitState then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Have a non-paused building with unit state='..M27Logic.GetUnitState(oEngineer)) end
                                            if oBuilding:IsUnitState('Upgrading') == true or oBuilding:IsUnitState('SiloBuildingAmmo') or (oBuilding.GetWorkProgress and oBuilding:GetWorkProgress() < 1 and oBuilding:GetWorkProgress() > 0 and not(EntityCategoryContains(categories.ARTILLERY, oBuilding.UnitId))) then
                                                --Check we have spare resources
                                                if aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] > 2 then
                                                    --If building ammo, check if we already have 2
                                                    if not(oBuilding:IsUnitState('SiloBuildingAmmo')) or oBuilding:GetTacticalSiloAmmoCount() + oBuilding:GetNukeSiloAmmoCount() < 2 then
                                                        bHaveAction = true
                                                        IssueGuard({ oEngineer}, oBuilding)
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Have an upgrading unti that will assist='..oBuilding.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBuilding)..'; building unit state='..M27Logic.GetUnitState(oBuilding)..'; Workprogress='..(oBuilding:GetWorkProgress() or 'nil')) end
                                                    end
                                                end
                                            elseif oBuilding:IsUnitState('Building') == true then
                                                oBuildingProducing = oBuilding --Dont mind which order upgrade and part-complete buildings are done in, but assisting a factory is a lower priority so only do if no matches to prev 2 in the search area
                                                if bDebugMessages == true then LOG(sFunctionRef..': Have a unit that is building something, will assist it if cant find upgrading or part complete buildings') end
                                            end
                                        end
                                    end
                                end
                                if bHaveAction then break end
                            end
                        end
                        if bHaveAction then break end
                    end
                    if bHaveAction == false and oBuildingProducing then
                        if bDebugMessages == true then LOG(sFunctionRef..': Issuing guard to assist unit in its production') end
                        bHaveAction = true
                        IssueGuard({oEngineer}, oBuildingProducing)
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Dont have any buildings within '..iCurSearchDistance..' of engineer') end
                end
            end
        end
    end

    --[[if iCurSearchDistance > iMaxSearchRange then
break
end
iCurSearchDistance = iCurSearchDistance * iRangeIncreaseFactor

iLoopCount = iLoopCount + 1
if iLoopCount > iMaxLoop then
M27Utilities.ErrorHandler('Exceeded max loop, likely infinite loop')
end--]]
    --end
    local iTimeToWaitInSecondsBeforeRefresh
    if bHaveAction == false then
        aiBrain[refbLastSpareEngineerHadNoAction] = true
        --Are we within 50 of the base? If not then attack-move to random point within 30 of start position
        local tPlaceToMoveTo
        if iDistToStart > 50 then
            AttackMoveToRandomPositionAroundBase(aiBrain, oEngineer, 30, 20)
            --tPlaceToMoveTo = M27Logic.GetRandomPointInAreaThatCanPathTo(M27UnitInfo.GetUnitPathingType(oEngineer), M27MapInfo.GetUnitSegmentGroup(oEngineer), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 30, 20)
        else
            --Already near base - have checked above to upgrade within a 40 range, so presumably we are power stalling; attack-move further away from base
            AttackMoveToRandomPositionAroundBase(aiBrain, oEngineer, 50, 30)
            --tPlaceToMoveTo = M27Logic.GetRandomPointInAreaThatCanPathTo(M27UnitInfo.GetUnitPathingType(oEngineer), M27MapInfo.GetUnitSegmentGroup(oEngineer), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 50, 30)
        end
        --IssueAggressiveMove({oEngineer}, tPlaceToMoveTo)
        iTimeToWaitInSecondsBeforeRefresh = math.random(3,7)
    else
        aiBrain[refbLastSpareEngineerHadNoAction] = false
        iTimeToWaitInSecondsBeforeRefresh = math.random(15, 25)
    end
    if bDestroy == false then ForkThread(DelayedSpareEngineerClearAction, aiBrain, oEngineer, iTimeToWaitInSecondsBeforeRefresh) end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function AreMobileUnitsInRect(rRectangleToSearch, bOnlyLookForMobileLand)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'AreMobileUnitsInRect'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bAreUnits
    local tBlockingUnits = GetUnitsInRect(rRectangleToSearch)
    if bOnlyLookForMobileLand == nil then bOnlyLookForMobileLand = true end
    if M27Utilities.IsTableEmpty(tBlockingUnits) == true then
        bAreUnits = false
    else
        if bOnlyLookForMobileLand == true then
            --For some reason using entity category filters down
            local bHaveMobileLand = false
            local sUnitID
            for iUnit, oUnit in tBlockingUnits do
                if oUnit.GetUnitId then
                    sUnitID = oUnit.UnitId
                    if bDebugMessages == true then LOG(sFunctionRef..': Units in rect: iUnit='..iUnit..' sUnitID='..sUnitID) end
                    if EntityCategoryContains(categories.MOBILE * categories.LAND, sUnitID) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Unit is mobile land so stopping loop') end
                        bHaveMobileLand = true
                        break
                    end
                end
            end
            if bHaveMobileLand == true then
                bAreUnits = true
            else
                bAreUnits = false
            end
        else bAreUnits = true end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bAreUnits
end

function FindRandomPlaceToBuild(aiBrain, oBuilder, tStartPosition, sBlueprintToBuild, iFirstSearchSizeMin, iFirstSearchSizeMax, bForcedDebug, iOptionalMaxCycleOverride, bAlreadyRecheckedPathing, bDontHaveBuilder)
    --Returns nil if cant find anywhere
    --tries finding somewhere with enough space to build sBuildingBPToBuild - e.g. to be used as a backup when fail to find adjacency location
    --Can also be used for general movement
    --very similar to FindEmptyPathableAreaNearTarget, but now with added code to ignore if blocking mex
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'FindRandomPlaceToBuild'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if EntityCategoryContains(categories.SHIELD + M27UnitInfo.refCategoryTMD, sBlueprintToBuild) then bDebugMessages = true end


    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    local rPlayableArea
    if M27MapInfo.bNoRushActive then
        rPlayableArea = {aiBrain[M27MapInfo.reftNoRushCentre][1] - M27MapInfo.iNoRushRange,aiBrain[M27MapInfo.reftNoRushCentre][3] - M27MapInfo.iNoRushRange, aiBrain[M27MapInfo.reftNoRushCentre][1] + M27MapInfo.iNoRushRange,aiBrain[M27MapInfo.reftNoRushCentre][3] + M27MapInfo.iNoRushRange}
    else
        rPlayableArea = M27MapInfo.rMapPlayableArea
    end

    local iMapBoundMaxX = rPlayableArea[3]
    local iMapBoundMaxZ = rPlayableArea[4]
    local iMapBoundMinX = rPlayableArea[1]
    local iMapBoundMinZ = rPlayableArea[2]

    local tTargetLocation = {} --{tStartPosition[1], tStartPosition[2], tStartPosition[3]}
    local iSearchSizeMax = iFirstSearchSizeMax
    local iSearchSizeMin = iFirstSearchSizeMin
    if iSearchSizeMax == nil then iSearchSizeMax = 10 end
    if iSearchSizeMin == nil then iSearchSizeMin = 2 end

    local iRandomX, iRandomZ
    local iCurSizeCycleCount = 0
    local iCycleSize = 8
    local iSignageX, iSignageZ
    local iMaxCycles = (iOptionalMaxCycleOverride or 5)
    local iCurCycle = 0
    local iValidLocationCount = 0
    local tValidLocations = {}
    local tValidDistanceToEnemy = {}
    local tValidDistanceToBuilder = {}
    local iMinDistanceToBuilder = 10000
    local iMaxDistanceToBuilder = 0
    local iMaxDistanceToEnemy = 0
    local iCurDistanceToEnemy, iCurDistanceToBuilder
    local iCurPriority = 0
    local iMaxPriority = -1000000
    local tBuilderPosition
    local oBuilderBP, iBuilderRange, sPathing

    local iMaxDistanceToIncreaseEachCycle = math.min(25, math.max(iSearchSizeMax * 0.75, 4))

    if oBuilder and oBuilder.GetPosition then
        tBuilderPosition = oBuilder:GetPosition()
        oBuilderBP = oBuilder:GetBlueprint()
        if oBuilderBP.Economy and oBuilderBP.Economy.MaxBuildDistance then iBuilderRange = oBuilderBP.Economy.MaxBuildDistance end
        sPathing = M27UnitInfo.GetUnitPathingType(oBuilder)
    else
        if not(bDontHaveBuilder) then M27Utilities.ErrorHandler('oBuilder is nil or has no position but were expecingt one to have been specified') end
        tBuilderPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        sPathing = M27UnitInfo.refPathingTypeAmphibious
        iBuilderRange = 0
    end
    if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end


    local tEnemyStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
    local tNewBuildingSize
    if sBlueprintToBuild then tNewBuildingSize = M27UnitInfo.GetBuildingSize(sBlueprintToBuild) end
    if tNewBuildingSize == nil then
        M27Utilities.ErrorHandler('sBlueprintToBuild is nil or has no building size')
        tNewBuildingSize = {0,0}
    end
    local fSizeMod = 0.5
    local iNewBuildingRadius = tNewBuildingSize[1] * fSizeMod
    local iMaxDistanceToBuildWithoutMoving = (iBuilderRange or 0) + iNewBuildingRadius

    local iBuilderPathingGroup = M27MapInfo.GetSegmentGroupOfLocation(sPathing, tBuilderPosition)
    --local iCurPathingGroup
    --local iCurSegmentX, iCurSegmentZ
    local iGroupCycleCount = 0
    local sLocationRef

    local tSignageX = {1, 1, 1, 0, -1, -1, -1, 0}
    local tSignageZ = {1, 0, -1, -1, -1, 0, 1, 1}
    local iRandomDistance
    --[[local tPathingAdjust = {    {0, 0},
                    {-iNewBuildingRadius, -iNewBuildingRadius},
                    {iNewBuildingRadius, -iNewBuildingRadius},
                    {-iNewBuildingRadius, iNewBuildingRadius},
                    {iNewBuildingRadius, iNewBuildingRadius},
                }--]]

    local iCycleAbortCount = 5
    local tBP = __blueprints[sBlueprintToBuild]
    if tBP.Economy.BuildCostMass >= 2000 or EntityCategoryContains(M27UnitInfo.refCategoryPower, sBlueprintToBuild) then
        iCycleAbortCount = 6
        if tBP.Economy.BuildCostMass >= 6000 then
            if tBP.Economy.BuildCostMass >= 12000 then iCycleAbortCount = 8 else
                iCycleAbortCount = 7 end
        end
    end
    if tBP.Physics.SkirtSizeX >= 10 then iCycleAbortCount = iCycleAbortCount + 2 end

    while iValidLocationCount == 0 do
        iGroupCycleCount = iGroupCycleCount + 1
        if bDebugMessages == true then LOG(sFunctionRef..': Start of main loop grouping, iGroupCycleCount='..iGroupCycleCount..'; iCycleSize='..iCycleSize..'; iValidLocationCount='..iValidLocationCount) end
        if iGroupCycleCount > iMaxCycles then
            if iMaxCycles >= iCycleAbortCount then --Sometimes we may be ok with not finding anywhere to build, e.g. for rally points
                --(dont get UC in error message as engineer may be nil, e.g. if its a TML)
                if not(bAlreadyRecheckedPathing) and M27UnitInfo.IsUnitValid(oBuilder) and M27MapInfo.RecheckPathingOfLocation(sPathing, oBuilder, tStartPosition, nil) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Pathing was incorrect and has now changed so will rerun function') end
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    return FindRandomPlaceToBuild(aiBrain, oBuilder, tStartPosition, sBlueprintToBuild, iSearchSizeMin, iSearchSizeMax, false, nil, true)
                else
                    if bDebugMessages == true then M27Utilities.DrawLocation(tStartPosition, nil, 1, 100, nil) end
                    M27Utilities.ErrorHandler('Possible infinite loop or just bad terrain/lots of buildings already - unable to find anywhere to build despite iSearchSizeMax='..iSearchSizeMax..'; iGroupCycleCount='..iGroupCycleCount..'; iMaxCycles='..iMaxCycles..'; iCycleAbortCount='..iCycleAbortCount..'; tStartPosition='..math.floor(tStartPosition[1])..'-'..math.floor(tStartPosition[2])..'-'..math.floor(tStartPosition[3])..'; aiBrain index='..aiBrain:GetArmyIndex()..'; start number='..aiBrain.M27StartPositionNumber..'; sBlueprintToBuild='..(sBlueprintToBuild or 'nil')..'; Builder='..(oBuilder.UnitId or 'nil')..(M27UnitInfo.GetUnitLifetimeCount(oBuilder) or 'nil')..'; will check pathing and rerun if pathing changes if not already checked, bAlreadyRecheckedPathing='..tostring(bAlreadyRecheckedPathing or false)..'; iFirstSearchSizeMax='..(iFirstSearchSizeMax or 'nil')..'; iFirstSearchSizeMin='..(iFirstSearchSizeMin or 'nil'), true)
                    if oBuilder then
                        LOG('Pathing='..sPathing..'; Engineer pathing group='..M27MapInfo.GetSegmentGroupOfLocation(sPathing, oBuilder:GetPosition())..'; start position group='..M27MapInfo.GetSegmentGroupOfLocation(sPathing, tStartPosition)..'; our base group='..M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]))
                    else LOG(sFunctionRef..': Dont have a builder so cant provide more info')
                    end
                end
            end
            break
        end
        iRandomDistance = math.random(iSearchSizeMin, iSearchSizeMin + math.max(2, (iSearchSizeMax - iSearchSizeMin) * 0.4))
        if bDebugMessages == true then LOG(sFunctionRef..': Picking random distance='..iRandomDistance..'; iSearchSizeMin='..iSearchSizeMin..'; iSearchSizeMax='..iSearchSizeMax..'; iGroupCycleCount='..iGroupCycleCount) end
        for iCurSizeCycleCount = 1, iCycleSize do
            iSignageX = tSignageX[iCurSizeCycleCount]
            iSignageZ = tSignageZ[iCurSizeCycleCount]
            iRandomX = iRandomDistance * iSignageX + tStartPosition[1]
            iRandomZ = iRandomDistance * iSignageZ + tStartPosition[3]
            if bDebugMessages == true then LOG(sFunctionRef..': iRandomX='..iRandomX..'; iRandomZ='..iRandomZ..'; iMapBoundMinX='..iMapBoundMinX..'; iMapBoundMaxX='..iMapBoundMaxX..'; iMapBoundMinZ='..iMapBoundMinZ..'; iMapBoundMaxZ='..iMapBoundMaxZ..'; iNewBuildingRadius='..iNewBuildingRadius) end
            if iRandomX < (iMapBoundMinX + iNewBuildingRadius) then iRandomX = iMapBoundMinX + iNewBuildingRadius
            elseif iRandomX > (iMapBoundMaxX - iNewBuildingRadius) then iRandomX = iMapBoundMaxX - iNewBuildingRadius end
            if iRandomZ < (iMapBoundMinZ + iNewBuildingRadius) then iRandomZ = iMapBoundMinZ + iNewBuildingRadius
            elseif iRandomZ > (iMapBoundMaxZ - iNewBuildingRadius) then iRandomZ = iMapBoundMaxZ - iNewBuildingRadius end

            tTargetLocation = {iRandomX, GetTerrainHeight(iRandomX, iRandomZ), iRandomZ}
            if bDebugMessages == true then LOG(sFunctionRef..': Checking if can build at location '..repru(tTargetLocation)) end
            if CanBuildAtLocation(aiBrain, sBlueprintToBuild, tTargetLocation, nil, false, true) then
                --if aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation) == true and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][M27Utilities.ConvertLocationToReference(tTargetLocation)]) then
                --Check not blocking a mex
                if bDebugMessages == true then LOG(sFunctionRef..': Can build structure at the location, checking if will block mex') end
                if WillBuildingBlockMex(sBlueprintToBuild, tTargetLocation) == false then
                    --Is it either in range of the engineer or in the same pathing group?
                    iCurDistanceToBuilder = M27Utilities.GetDistanceBetweenPositions(tTargetLocation, tBuilderPosition)
                    local bEngineerCanBuild = false
                    if iCurDistanceToBuilder < iMaxDistanceToBuildWithoutMoving then bEngineerCanBuild = true
                    else
                        --Check both target and the build area appear to be in the same group
                        bEngineerCanBuild = true
                        if not(iBuilderPathingGroup == M27MapInfo.GetSegmentGroupOfLocation(sPathing, tTargetLocation)) then bEngineerCanBuild = false end

                        --[[for iAdjEntry, tAdjust in tPathingAdjust do
                if not(iBuilderPathingGroup == M27MapInfo.GetSegmentGroupOfLocation(sPathing, { tTargetLocation[1] + tAdjust[1], tTargetLocation[2], tTargetLocation[3] + tAdjust[2] })) then
                    bEngineerCanBuild = false
                    break
                end
            end--]]
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': Wont block mex, checking if in range of engineer or in same pathing group. bEngineerCanBuild='..tostring(bEngineerCanBuild)) end
                    if bEngineerCanBuild == true then
                        iValidLocationCount = iValidLocationCount + 1
                        tValidLocations[iValidLocationCount] = tTargetLocation
                        iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tEnemyStartPosition, tTargetLocation)
                        tValidDistanceToEnemy[iValidLocationCount] = iCurDistanceToEnemy
                        if iCurDistanceToEnemy > iMaxDistanceToEnemy then iMaxDistanceToEnemy = iCurDistanceToEnemy end
                        tValidDistanceToBuilder[iValidLocationCount] = iCurDistanceToBuilder
                        if iCurDistanceToBuilder > iMaxDistanceToBuilder then iMaxDistanceToBuilder = iCurDistanceToBuilder end
                        if iCurDistanceToBuilder < iMinDistanceToBuilder then iMinDistanceToBuilder = iCurDistanceToBuilder end
                        if bDebugMessages == true then LOG(sFunctionRef..': Have a valid location taht engineers can path to; tTargetLocation='..repru(tTargetLocation)..'; iValidLocationCount='..iValidLocationCount) end
                    end
                end
            elseif bDebugMessages == true then
                LOG(sFunctionRef..': Cant build at location, will draw in red, position='..repru(tTargetLocation))
                M27Utilities.DrawLocation(tTargetLocation, false, 2, 100, nil)
            end
            if iCurSizeCycleCount == iCycleSize then
                iSearchSizeMin = math.max(iSearchSizeMin + 2, iRandomDistance)
                iSearchSizeMax = math.max(iSearchSizeMin + 2, math.min(iSearchSizeMax * 1.25, iMaxDistanceToIncreaseEachCycle))
            end
            if bDebugMessages == true then M27Utilities.DrawLocation(tTargetLocation) end
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': Finished looping through locations, iValidLocationCount='..iValidLocationCount) end
    if iValidLocationCount > 0 then
        if iValidLocationCount > 1 then
            --Pick the best valid location that we have
            if bDebugMessages == true then LOG(sFunctionRef..': Have a valid location count or '..iValidLocationCount..' so will pick the best location; possible locations to choose from='..repru(tValidLocations)) end
            local rBuildAreaRect
            for iCurLocation, tLocation in tValidLocations do
                rBuildAreaRect = Rect(tLocation[1] - iNewBuildingRadius, tLocation[3] - iNewBuildingRadius, tLocation[1] + iNewBuildingRadius, tLocation[3] + iNewBuildingRadius)
                if M27MapInfo.GetReclaimInRectangle(1, rBuildAreaRect) == false then iCurPriority = iCurPriority + 3 end
                if AreMobileUnitsInRect(rBuildAreaRect) == false then iCurPriority = iCurPriority + 3 end
                if tValidDistanceToEnemy[iCurLocation] >= iMaxDistanceToEnemy then iCurPriority = iCurPriority + 1 end
                iCurDistanceToBuilder = tValidDistanceToBuilder[iValidLocationCount]
                if iCurDistanceToBuilder <= iMaxDistanceToBuildWithoutMoving then
                    iCurPriority = iCurPriority + 3
                    --else
                    --iCurSegmentX, iCurSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tLocation)
                    --iCurPathingGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iCurSegmentX, iCurSegmentZ)
                    --if not(iCurPathingGroup == iBuilderPathingGroup) then
                    --iCurPriority = iCurPriority - 40
                    --if iCurDistanceToBuilder == iMinDistanceToBuilder then iCurPriority = iCurPriority + 20 end --If only have places that cant path to, then want the cloest one as are most likely to be able to build
                    --end
                end
                if iCurDistanceToEnemy >= iMinDistanceToBuilder then iCurPriority = iCurPriority + 1 end
                if iMaxDistanceToBuilder - iMinDistanceToBuilder > 0 then
                    iCurPriority = iCurPriority + 2 * (iCurDistanceToBuilder - iMinDistanceToBuilder) / (iMaxDistanceToBuilder - iMinDistanceToBuilder)
                end

                if iCurPriority > iMaxPriority then
                    iMaxPriority = iCurPriority
                    tTargetLocation = tLocation
                    if bDebugMessages == true then LOG(sFunctionRef..': New highest priority location, iCurPriority='..iCurPriority..'; tTargetLocation='..repru(tTargetLocation)) end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Finished considering iCurLocation='..iCurLocation..'; tLocation='..repru(tLocation)..'; iCurPriority='..iCurPriority..'; iMaxPriority='..iMaxPriority..'; iCurDistanceToBuilder='..iCurDistanceToBuilder..'; iMaxDistanceToBuildWithoutMoving='..iMaxDistanceToBuildWithoutMoving..'; iMinDistanceToBuilder='..iMinDistanceToBuilder) end
            end
        else tTargetLocation = tValidLocations[1]
        end
    else
        tTargetLocation = nil
        if iGroupCycleCount >= math.max(5, iMaxCycles) then
            M27Utilities.ErrorHandler('Failed to find a random place to build that engineer can path to after iGroupCycleCount='..iCycleAbortCount..' with iMaxCycles='..iMaxCycles..';, will check pathing and re-run this function if this is the first time', true)
            bDebugMessages = true --To help with errors
        end


    end

    if bDebugMessages == true then LOG(sFunctionRef..': If only had 1 valid location count will consider nearer options to base; iValidLocationCount='..(iValidLocationCount or 0)) end
    if iValidLocationCount > 0 then --if had more than 1 valid location then will have already been through logic to pick the best one; if only had 1 valid location then more likely was an issue
        --Refine location - see if we can move closer to base/original target if we are far away
        if M27Utilities.GetDistanceBetweenPositions(tTargetLocation, tStartPosition) >= 50 then
            if bDebugMessages == true then LOG(sFunctionRef..': Random location is '.. M27Utilities.GetDistanceBetweenPositions(tTargetLocation, tStartPosition)..' away from the position we wanted, will see if we can move closer to base') end
            local iLastSuccessfulInterval = 8
            iValidLocationCount = 0
            local iAngleToStart = M27Utilities.GetAngleFromAToB(tTargetLocation, tStartPosition)
            local tPossibleLocation
            local bBlockingReclaimOrMobileUnits
            local rBuildAreaRect

            while iLastSuccessfulInterval > 1 do
                iValidLocationCount = iValidLocationCount + 1
                if iValidLocationCount >= 10 then break end

                tPossibleLocation = M27Utilities.MoveInDirection(tTargetLocation, iAngleToStart, iLastSuccessfulInterval, false)
                if bDebugMessages == true then LOG(sFunctionRef..': iLastSuccessfulInterval='..iLastSuccessfulInterval..'; New potential location='..repru(tPossibleLocation)..'; Segment group='..M27MapInfo.GetSegmentGroupOfLocation(sPathing, tTargetLocation)..' (vs builder group '..iBuilderPathingGroup..'); Can build here='..tostring(CanBuildAtLocation(aiBrain, sBlueprintToBuild, tPossibleLocation, nil, false, true))) end
                if M27MapInfo.GetSegmentGroupOfLocation(sPathing, tTargetLocation) == iBuilderPathingGroup then
                    --CHeck no blocking reclaim or mobile units if had more than 1 valid location (as we'd have taken these into account for the valid locations)
                    if iValidLocationCount > 1 then
                        bBlockingReclaimOrMobileUnits = false
                        rBuildAreaRect = Rect(tPossibleLocation[1] - iNewBuildingRadius, tPossibleLocation[3] - iNewBuildingRadius, tPossibleLocation[1] + iNewBuildingRadius, tPossibleLocation[3] + iNewBuildingRadius)
                        if M27MapInfo.GetReclaimInRectangle(1, rBuildAreaRect) then
                            bBlockingReclaimOrMobileUnits = true
                        else
                            if AreMobileUnitsInRect(rBuildAreaRect) then
                                bBlockingReclaimOrMobileUnits = true
                            end
                        end
                    else bBlockingReclaimOrMobileUnits = false
                    end
                    if not(bBlockingReclaimOrMobileUnits) and CanBuildAtLocation(aiBrain, sBlueprintToBuild, tPossibleLocation, nil, false, true) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have a location that is closer than before so will choose it') end
                        tTargetLocation = {tPossibleLocation[1], tPossibleLocation[2], tPossibleLocation[3]}
                    end
                else
                    iLastSuccessfulInterval = iLastSuccessfulInterval * 0.5
                end
            end
        end
    end

    if bDebugMessages == true then
        if M27Utilities.IsTableEmpty(tTargetLocation) == false then
            LOG(sFunctionRef..'; Found random place to build, which is tTargetLocation='..repru(tTargetLocation)..'; aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation)='..tostring(aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation)))
        else LOG(sFunctionRef..': Couldnt find anywhere to build')
        end
        LOG(sFunctionRef..': End of code')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tTargetLocation
end

function WillBuildingBlockMex(sNewBuildingBPID, tPositionOfNewBuilding)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'WillBuildingBlockMex'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --returns true if building will build by a mex; will only check outer border of the buildingID, i.e. assumes mex location wont be inside this since hten we couldnt build anyway
    --MassPoints = {} -- Stores position of each mass point (as a position value, i.e. a table with 3 values, x, y, z
    --tMexPointsByLocationRef = {} --As per mass points, but the key is the locationref value, and it returns the position

    --Mex has a size 2x2 so centre of mex will have 1 space to either side
    --So if e.g. we're building T1 power, which is also 2x2 building, then will block a mex if mex is +/-2 from midpoint of t1 power on x or z (but not +/- 2 on both, so should be 12 combinations that are testing
    --If instead dealing with 4x4 building, then is up to +/-3
    --If instead dealing with 1x1 building, then is up to +/- 1
    --so formula for the max +/- is the floor of the radius + 1

    local tBuildingSize = M27UnitInfo.GetBuildingSize(sNewBuildingBPID)
    local iSizeX = math.floor(tBuildingSize[1] * 0.5 + 3) --if were to build a T1 power right by a mex, then it woudl show as 2 away; 1 being the power's radius, 1 being the mexes' radius.  We want at least 4 away, to allow space for mass storage; building size*0.5 returns radius of the building we're considering
    local iSizeZ = math.floor(tBuildingSize[2] * 0.5 + 3)
    local iBuildingSizeRadius = math.max(iSizeX, iSizeZ)
    --local sLocationRef
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return not(M27Utilities.IsTableEmpty(M27MapInfo.GetResourcesNearTargetLocation(tPositionOfNewBuilding, iBuildingSizeRadius, true)))

    --[[if bDebugMessages == true then LOG(sFunctionRef..': tMexPointsByLocationRef='..repru(M27MapInfo.tMexPointsByLocationRef)..'; tBuildingSize='..repru(tBuildingSize)..'; sNewBuildingBPID='..sNewBuildingBPID..'; tPositionOfNewBuilding='..repru(tPositionOfNewBuilding)) end
for iModX = -iSizeX, iSizeX, 1 do
for iModZ = -iSizeZ, iSizeZ, 1 do
if iModZ <= -iSizeZ or iModZ >= iSizeZ or iModX <= -iSizeX or iModX >= iSizeX then
    if not (math.abs(iModX) == iSizeX and math.abs(iModZ) == iSizeZ) then
        sLocationRef = M27Utilities.ConvertLocationToReference({tPositionOfNewBuilding[1] + iModX, 0, tPositionOfNewBuilding[3] + iModZ})
        if bDebugMessages == true then
            LOG(sFunctionRef..': iSizeX='..iSizeX..'; iSizeZ='..iSizeZ..'; iModX='..iModX..'; iModZ='..iModZ..'; tPositionOfNewBuilding='..repru(tPositionOfNewBuilding)..'; sLocationRef='..sLocationRef)
            M27Utilities.DrawLocation({tPositionOfNewBuilding[1] + iModX, GetTerrainHeight(tPositionOfNewBuilding[1] + iModX, tPositionOfNewBuilding[3] + iModZ), tPositionOfNewBuilding[3] + iModZ}, nil, 1, 100)
        end

        if M27MapInfo.tMexPointsByLocationRef[sLocationRef] then
            if bDebugMessages == true then LOG(sFunctionRef..': Mex identified near building, so will return that are blocking') end
            return true
        end
    end
end
end
end
if bDebugMessages == true then LOG(sFunctionRef..': No mexes identified around target building') end
return false--]]
end

function AdjustPDBuildLocation(aiBrain, tBasePosition, sUnitID)
    --Assumes tBasePosition can be built on.  Calculates if shot is blocked for cur position and if so looks for another, unless cur position is shielded
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AdjustPDBuildLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if M27Logic.IsLocationUnderFriendlyFixedShield(aiBrain, tBasePosition) then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return tBasePosition
    else
        local tShotStartPosition
        local tShotEndPosition

        local oBP = __blueprints[sUnitID]
        local iPDFireHeight = 0.8 --Rough approximation, not done any testing to see how accurate this is
        local iTargetHeight = 0.5 --e.g. striker has sizey of this
        local iMaxRange = 25 --Basic default in case something goes wrong
        for iWeapon, tWeapon in oBP.Weapon do
            if tWeapon.WeaponCategory == 'Direct Fire' then
                iMaxRange = math.max(iMaxRange, tWeapon.MaxRadius)
            end
        end

        local sPathing = M27UnitInfo.refPathingTypeAmphibious
        local iPathingGroupWanted = M27MapInfo.GetSegmentGroupOfLocation(sPathing, tBasePosition)

        --Adjust max range down slightly
        iMaxRange = iMaxRange * 0.8

        local iTotalDistanceNotBlocked = 0
        tShotStartPosition = {tBasePosition[1], tBasePosition[2] + iPDFireHeight, tBasePosition[3]}

        for iShotAngle = -50, 50, 25 do --If changing here also change for below
            tShotEndPosition = M27Utilities.MoveInDirection(tShotStartPosition, iShotAngle, iMaxRange, true)
            tShotEndPosition[2] = tShotEndPosition[2] + iTargetHeight
            iTotalDistanceNotBlocked = iTotalDistanceNotBlocked + M27Logic.IsLineBlocked(aiBrain, tShotStartPosition, tShotEndPosition, nil, true)
            if bDebugMessages == true then LOG(sFunctionRef..': Will draw shot end position in gold') M27Utilities.DrawLocation(tShotEndPosition, nil, 4, 100, nil) end
        end
        local iHighestDistanceNotBlocked = iTotalDistanceNotBlocked
        local iAbortDistance = iMaxRange * 5.7 --Most shots arent blocked so little value in doing detailed calculation
        if bDebugMessages == true then LOG(sFunctionRef..': sUnitID='..sUnitID..'; tBasePosition='..repru(tBasePosition)..'; iTotalDistanceNotBlocked from base='..iTotalDistanceNotBlocked..'; iAbortDistance='..iAbortDistance) end
        if iHighestDistanceNotBlocked >= iAbortDistance then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return tBasePosition
        else
            iAbortDistance = iMaxRange * 5.8 --If going to cycle through lots of entries might as well get a better result

            local iAngleToBase = M27Utilities.GetAngleFromAToB(tBasePosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            local tPotentialBuildLocation
            local tBestBuildLocation = {tBasePosition[1], tBasePosition[2], tBasePosition[3]}
            local iAngleFromBuildToEnemyBase
            local tEnemyBase = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)




            for iPlacementAngleAdjust = -70, 70, 35 do
                for iPlacementDist = 4, 20, 4 do
                    iTotalDistanceNotBlocked = 0
                    tPotentialBuildLocation = M27Utilities.MoveInDirection(tBasePosition, iAngleToBase + iPlacementAngleAdjust, iPlacementDist)
                    --Could we build here? Are we in the same amphib pathing group or <=5 dist?

                    if iPlacementDist <= 5 or iPathingGroupWanted == M27MapInfo.GetSegmentGroupOfLocation(sPathing, tPotentialBuildLocation) then
                        if CanBuildAtLocation(aiBrain, sUnitID, tPotentialBuildLocation, nil, false, true) then
                            tShotStartPosition = { tPotentialBuildLocation[1], tPotentialBuildLocation[2] + iPDFireHeight, tPotentialBuildLocation[3]}
                            iAngleFromBuildToEnemyBase = M27Utilities.GetAngleFromAToB(tPotentialBuildLocation, tEnemyBase)
                            for iShotAngle = -50 + iAngleFromBuildToEnemyBase, 50 + iAngleFromBuildToEnemyBase, 25 do --If changing here also change for above
                                tShotEndPosition = M27Utilities.MoveInDirection(tShotStartPosition, iShotAngle, iMaxRange, true)
                                tShotEndPosition[2] = tShotEndPosition[2] + iTargetHeight
                                iTotalDistanceNotBlocked = iTotalDistanceNotBlocked + M27Logic.IsLineBlocked(aiBrain, tShotStartPosition, tShotEndPosition, nil, true)
                            end


                            if iTotalDistanceNotBlocked > iHighestDistanceNotBlocked then
                                tBestBuildLocation = {tPotentialBuildLocation[1], tPotentialBuildLocation[2], tPotentialBuildLocation[3]}
                                iHighestDistanceNotBlocked = iTotalDistanceNotBlocked
                                if iTotalDistanceNotBlocked >= iAbortDistance then break end
                            end
                        end
                    end
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': Finished considering iPlacementAngleAdjust='..(iPlacementAngleAdjust or 'nil')..'; iPlacementDist='..(iPlacementDist or 'nil')..'; tPotentialBuildLocation='..repru(tPotentialBuildLocation or {'nil'})..'; iHighestDistanceNotBlocked='..(iHighestDistanceNotBlocked or 'nil')..'; tBestBuildLocation='..repru(tBestBuildLocation or {'nil'})..'; Cur position iTotalDistanceNotBlocked='..(iTotalDistanceNotBlocked or 'nil')..'; If cur position dist not blocked is less than highest value then will draw in red, otherwise will draw in blue. iPathingGroupWanted='..(iPathingGroupWanted or 'nil')..'; Pathing of potential build location='..(M27MapInfo.GetSegmentGroupOfLocation(sPathing, tPotentialBuildLocation) or 'nil')..'; CanBuildAtLocation(aiBrain, sUnitID, tPotentialBuildLocation, nil, false, true)='..tostring(CanBuildAtLocation(aiBrain, sUnitID, tPotentialBuildLocation, nil, false, true) or false))
                        if iTotalDistanceNotBlocked == iHighestDistanceNotBlocked then
                            M27Utilities.DrawLocation(tPotentialBuildLocation, false, 1, 100)
                        else
                            M27Utilities.DrawLocation(tPotentialBuildLocation, false, 2, 100)
                        end
                    end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': End of code, tBestBuildLocation='..repru(tBestBuildLocation)..'; iTotalDistanceNotBlocked='..iTotalDistanceNotBlocked) end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return tBestBuildLocation
        end
    end
end

function GetBuildLocationForShield(aiBrain, sShieldBP,  tPositionToCoverWithShield, bBuildAwayFromEnemy)
    --find the first location near tPositionToCoverWithShield that can build on that doesnt have anything queued for either it or nearby locations
    --if bBuildAwayFromEnemy is true then instead will try looking away from enemy in preference
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetBuildLocationForShield'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    local iShieldRadius = math.floor(__blueprints[sShieldBP].Defense.Shield.ShieldSize * 0.5 - 0.5)
    local iBuildingSizeRadius = math.ceil(math.max(__blueprints[sShieldBP].Physics.SkirtSizeX, __blueprints[sShieldBP].Physics.SkirtSizeZ) * 0.5)
    local tPossibleLocation, sLocationRef
    local bValidLocation
    if bDebugMessages == true then LOG(sFunctionRef..': About to search through every point around target to check we can build the shield '..sShieldBP..' there.  iBuildingSizeRadius='..iBuildingSizeRadius..'; iShieldRadius='..iShieldRadius..'; base position is '..repru(tPositionToCoverWithShield)..' which will draw in blue.  bBuildAwayFromEnemy='..tostring(bBuildAwayFromEnemy or false)) end

    local iAngleToEnemyBase = M27Utilities.GetAngleFromAToB(tPositionToCoverWithShield, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
    local ttValidLocationPositions = {}
    local iValidLocations = 0
    local tiValidLocationAngles = {}
    local iHighestAngleDifValue = 0
    local iHighestAngleDifLocationRef
    local iCurAngleDif

    for iAbsAdjX = 0, iShieldRadius, 1 do
        for iXFactor = -1, 1, 2 do
            for iAbsAdjZ = 0, iShieldRadius, 1 do
                for iZFactor = -1, 1, 2 do
                    if not(iAbsAdjX < iBuildingSizeRadius and iAbsAdjZ < iBuildingSizeRadius) then
                        tPossibleLocation = {tPositionToCoverWithShield[1] + iAbsAdjX * iXFactor, nil, tPositionToCoverWithShield[3] + iAbsAdjZ * iZFactor}
                        tPossibleLocation[2] = GetTerrainHeight(tPossibleLocation[1], tPossibleLocation[3])
                        if CanBuildAtLocation(aiBrain, sShieldBP, tPossibleLocation, nil, false) then
                            bValidLocation = true
                            if bValidLocation then
                                --Can build here, so record
                                if bDebugMessages == true then
                                    LOG(sFunctionRef..': No engineer assignments around here so can build here, will draw in white. iAbsAdjX='..iAbsAdjX * iXFactor..'; iAbsAdjZ='..iAbsAdjZ * iZFactor)
                                    M27Utilities.DrawLocation(tPossibleLocation, nil, 7, 100)
                                end

                                iValidLocations = iValidLocations + 1
                                if bBuildAwayFromEnemy then
                                    ttValidLocationPositions[iValidLocations] = tPossibleLocation
                                    tiValidLocationAngles[iValidLocations] = M27Utilities.GetAngleFromAToB(tPositionToCoverWithShield, tPossibleLocation)
                                    iCurAngleDif = math.abs(tiValidLocationAngles[iValidLocations] - iAngleToEnemyBase)
                                    if iCurAngleDif > 180 then iCurAngleDif = math.abs(iCurAngleDif - 360) end
                                    if iCurAngleDif > iHighestAngleDifValue then
                                        iHighestAngleDifValue = iCurAngleDif
                                        iHighestAngleDifLocationRef = iValidLocations
                                    end
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have a valid location '..iValidLocations..' with position '..repru(tPossibleLocation)..'; angle from target to possible position='..tiValidLocationAngles[iValidLocations]..'; Angle from target to base='..iAngleToEnemyBase..'; iCurAngleDif='..iCurAngleDif..'; iHighestAngleDifValue='..iHighestAngleDifValue) end
                                end

                                if not(bBuildAwayFromEnemy) or iCurAngleDif >= 150 then
                                    --Good enough match so abort
                                    if bDebugMessages == true then LOG(sFunctionRef..': iCurAngleDif >= 150 or arent worried about building away from enemy so will abort') end
                                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                                    return tPossibleLocation
                                end
                            end
                        elseif bDebugMessages == true then
                            LOG(sFunctionRef..': Cant build here as existing building is blocking, will draw in red')
                            M27Utilities.DrawLocation(tPossibleLocation, nil, 2, 100)
                        end
                    end
                end
            end
        end
    end
    if iValidLocations > 0 then
        if bBuildAwayFromEnemy then
            --Get best location
            tPossibleLocation = ttValidLocationPositions[iHighestAngleDifLocationRef]
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return tPossibleLocation
    end

    --Haven't found somewhere so record the location (this is redundancy logic, mostly this is already covered by the logic that considers if a specific unit has failed to have a shield built for it)

    if EntityCategoryContains(categories.TECH3, sShieldBP) then
        aiBrain[reftFailedShieldLocations][M27Utilities.ConvertLocationToReference(tPositionToCoverWithShield)] = tPositionToCoverWithShield
        if bDebugMessages == true then LOG(sFunctionRef..': Have a failed shield location that will record. Table of failed locations='..repru(aiBrain[reftFailedShieldLocations])) end
    end

    if bDebugMessages == true then LOG(sFunctionRef..': Finished searching, unable to find any valid locations') end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetBestBuildLocationForTarget(tablePosTarget, sTargetBuildingBPID, sNewBuildingBPID, bCheckValid, aiBrain, bReturnOnlyBestMatch, pBuilderPos, iMaxAreaToSearch, iBuilderRange, bIgnoreOutsideBuildArea, bBetterIfNoReclaim, bPreferCloseToEnemy, bPreferFarFromEnemy, bLookForQueuedBuildings)
    --Returns all co-ordinates that will result in a sNewBuildingBPID being built adjacent to PosTarget; if bCheckValid is true (default) then will also check it's a valid location to build
    -- tablePosTarget can either be a table (e.g. a table of mex locations), or just a single position
    --bIgnoreOutsideBuildArea - if true then ignore any locations outside of the builder's build area
    --bReturnOnlyBestMatch: if true then applies prioritisation and returns only the best match
    --bBetterIfNoReclaim - if true, then will ignore any build location that contains any reclaim (to avoid ACU trying to build somewhere that it has to walk to and reclaim)
    --bPreferCloseToEnemy, bPreferFarFromEnemy - optional variables, if either is set then will give +0.5 priority to locations that are closer/further to enemy
    --bLookForQueuedBuildings - optional, defaults to true, if true then check if any engineer has been assigned to buidl to that location already

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end --True if want most log messages to print
    local sFunctionRef = 'GetBestBuildLocationForTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --if EntityCategoryContains(categories.SHIELD, sNewBuildingBPID) then bDebugMessages = true end


    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end



    if bCheckValid == nil then bCheckValid = false end
    if aiBrain == nil then bCheckValid = false end
    if bReturnOnlyBestMatch == nil then bReturnOnlyBestMatch = false end
    local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    local tEnemyStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
    local iDistanceToEnemy
    local iMinDistanceToEnemy = 10000
    local iMaxDistanceToEnemy = 0
    if pBuilderPos == nil then
        ErrorHandler('pBuilderPos is nil')
        pBuilderPos = tStartPosition
        bIgnoreOutsideBuildArea = false
    end
    if iBuilderRange == nil then iBuilderRange = 5 end
    if iMaxAreaToSearch == nil then iMaxAreaToSearch = iBuilderRange + 10 end
    if bIgnoreOutsideBuildArea == nil then bIgnoreOutsideBuildArea = false end
    if bBetterIfNoReclaim == nil then bBetterIfNoReclaim = false end
    if bLookForQueuedBuildings == nil then bLookForQueuedBuildings = true end

    local bWantAdjacency = true

    if sTargetBuildingBPID == nil then
        bWantAdjacency = false
    end

    local bDontBuildByMex = true
    if bWantAdjacency and EntityCategoryContains(categories.MASSEXTRACTION, sTargetBuildingBPID) then bDontBuildByMex = false end
    if bDebugMessages == true then LOG(sFunctionRef..': sNewBuildingBPID='..sNewBuildingBPID..'; sTargetBuildingBPID='..(sTargetBuildingBPID or 'nil')..'; tablePosTarget='..repru(tablePosTarget)..'; bBetterIfNoReclaim='..tostring(bBetterIfNoReclaim or false)) end
    --local TargetSize = GetBuildingTypeInfo(TargetBuildingType, 1)
    local TargetSize
    if bWantAdjacency then TargetSize = M27UnitInfo.GetBuildingSize(sTargetBuildingBPID) end

    --local tNewBuildingSize = GetBuildingTypeInfo(NewBuildingType, 1)
    local tNewBuildingSize = M27UnitInfo.GetBuildingSize(sNewBuildingBPID)
    local fSizeMod = 0.5
    local iRectangleSizeReduction = 0
    local iNewBuildingRadius = tNewBuildingSize[1] * fSizeMod
    if bDebugMessages == true and bWantAdjacency then LOG(sFunctionRef..': TargetSize='..repru(TargetSize)..'; NewBuildingSize='..repru(tNewBuildingSize)) end
    local iBuildRangeExtension = iNewBuildingRadius
    if bDebugMessages == true then LOG(sFunctionRef..': Increasing builder distance from '..iBuilderRange..' by '..iBuildRangeExtension) end
    iBuilderRange = iBuilderRange + iBuildRangeExtension
    iMaxAreaToSearch = math.max(iMaxAreaToSearch, iBuilderRange + tNewBuildingSize[1])


    local iMaxX, iMinX, iMaxZ, iMinZ, iTargetMaxX, iTargetMinX, iTargetMaxZ, iTargetMinZ, OptionsX, OptionsZ
    local iNewX, iNewZ
    local iValidPosCount = 0
    local CurPosition = {}
    local PossiblePositions = {}
    local iValidPositionPriorities = {}
    local iValidPositionDistanceToEnemy = {}
    local iPriority
    local iDistanceBetween
    local iMaxPriority = -100
    local tBestPosition = {}
    local bMultipleTargets = M27Utilities.IsTableArray(tablePosTarget[1])
    local iTotalTargets = 1
    local PosTarget = {}
    if bMultipleTargets == true then iTotalTargets = M27Utilities.GetTableSize(tablePosTarget) end
    local bNewBuildingLargerThanNewTarget = false
    if TargetSize[1] < tNewBuildingSize[1] or TargetSize[2] < tNewBuildingSize[2] then bNewBuildingLargerThanNewTarget = true end

    local rPlayableArea
    if M27MapInfo.bNoRushActive then
        rPlayableArea = {aiBrain[M27MapInfo.reftNoRushCentre][1] - M27MapInfo.iNoRushRange,aiBrain[M27MapInfo.reftNoRushCentre][3] - M27MapInfo.iNoRushRange, aiBrain[M27MapInfo.reftNoRushCentre][1] + M27MapInfo.iNoRushRange,aiBrain[M27MapInfo.reftNoRushCentre][3] + M27MapInfo.iNoRushRange}
    else
        rPlayableArea = M27MapInfo.rMapPlayableArea
    end
    local iMaxMapX = rPlayableArea[3]
    local iMaxMapZ = rPlayableArea[4]

    local bHaveGoodMatch
    local iMapBoundarySize = 4
    local iActualMaxSearchRange
    local iIncrementSize = 4
    if bWantAdjacency then
        iIncrementSize = 1
        iActualMaxSearchRange = math.min(iMaxAreaToSearch + iNewBuildingRadius, TargetSize[1] * fSizeMod + iNewBuildingRadius)
    else iActualMaxSearchRange = math.min(iMaxAreaToSearch + iNewBuildingRadius, iBuilderRange)
    end
    if bDebugMessages == true then LOG(sFunctionRef..': About to try and build '..sNewBuildingBPID..' adjacent to '..(sTargetBuildingBPID or 'nil')..'; bDontBuildByMex='..tostring(bDontBuildByMex)..'; iTotalTargets='..iTotalTargets) end

    for iCurTarget = 1, iTotalTargets do
        if bMultipleTargets == true then
            PosTarget = tablePosTarget[iCurTarget]
        else
            PosTarget = tablePosTarget
        end
        --LOG('PosTarget[1]='..PosTarget[1])
        --LOG('TargetSize[1]='..TargetSize[1])
        --LOG('tNewBuildingSize[1]='..tNewBuildingSize[1])
        if bWantAdjacency then
            iMaxX = PosTarget[1] + TargetSize[1] * fSizeMod + iNewBuildingRadius
            if iMaxX > (iMaxMapX - iNewBuildingRadius) then iMaxX = iMaxMapX - iNewBuildingRadius end
            iMinX = PosTarget[1] - TargetSize[1] * fSizeMod - tNewBuildingSize[1]* fSizeMod
            if iMinX < (rPlayableArea[1] + iMapBoundarySize + iNewBuildingRadius) then iMinX = rPlayableArea[1] + iMapBoundarySize + iNewBuildingRadius end
            iMaxZ = PosTarget[3] + TargetSize[2] * fSizeMod + tNewBuildingSize[2]* fSizeMod
            if iMaxZ > (iMaxMapZ - iNewBuildingRadius) then iMaxZ = iMaxMapZ - iNewBuildingRadius end
            iMinZ = PosTarget[3] - TargetSize[2] * fSizeMod - tNewBuildingSize[2]* fSizeMod
            if iMinZ < (rPlayableArea[2] + iMapBoundarySize + iNewBuildingRadius) then iMinZ = rPlayableArea[2] + iMapBoundarySize + iNewBuildingRadius end

            iTargetMaxX = PosTarget[1] + TargetSize[1] * fSizeMod
            iTargetMinX = PosTarget[1] - TargetSize[1] * fSizeMod
            iTargetMaxZ = PosTarget[3] + TargetSize[2] * fSizeMod
            iTargetMinZ = PosTarget[3] - TargetSize[2] * fSizeMod
        else --Not interested in adjacency
            iMaxX = math.min(PosTarget[1] + iActualMaxSearchRange, iMaxMapX - iNewBuildingRadius)
            iMinX = math.max(PosTarget[1] - iActualMaxSearchRange,  rPlayableArea[1] + iMapBoundarySize + iNewBuildingRadius)
            iMaxZ = math.min(PosTarget[3] + iActualMaxSearchRange, iMaxMapZ - iNewBuildingRadius)
            iMinZ = math.max(PosTarget[3] - iActualMaxSearchRange,  rPlayableArea[2] + iMapBoundarySize + iNewBuildingRadius)
            if bDebugMessages == true then LOG(sFunctionRef..': Dont have adjancy so X Min-Max='..iMinX..'-'..iMaxX..'; Z Min-Max='..iMinZ..'-'..iMaxZ..'; iActualMaxSearchRange='..iActualMaxSearchRange) end
        end
        OptionsX = math.floor(iMaxX - iMinX)
        OptionsZ = math.floor(iMaxZ - iMinZ)
        if bDebugMessages == true then LOG(sFunctionRef..':About to cycle through potential adjacency locations for iCurTarget='..iCurTarget..'; iTotalTargets='..iTotalTargets..'; iMinX-iMaxX='..iMinX..'-'..iMaxX..'; iMinZ-iMaxZ='..iMinZ..'-'..iMaxZ..'; OptionsX='..OptionsX..'; OptionsZ='..OptionsZ..'; bWantAdjacency='..tostring(bWantAdjacency))end

        for xi = 0, OptionsX, iIncrementSize do
            iNewX = iMinX + xi
            --if iNewX >= (iMinX + TargetSize[1]*fSizeMod) or iNewX >= (iTargetMaxX - iNewBuildingRadius) then
            for zi = 0, OptionsZ, iIncrementSize do
                iPriority = 0
                iNewZ = iMinZ + zi

                --if iNewZ < (iTargetMinZ + tNewBuildingSize[2]* fSizeMod) or iNewZ > (iTargetMaxZ - tNewBuildingSize[2]* fSizeMod) then
                --ignore corner results (new building larger than target):
                local bIgnore = false
                if bWantAdjacency then
                    if bNewBuildingLargerThanNewTarget == true then
                        if iNewX - iNewBuildingRadius > iTargetMinX or iNewX + iNewBuildingRadius < iTargetMaxX then
                            if iNewZ - iNewBuildingRadius > iTargetMinZ or iNewZ + iNewBuildingRadius < iTargetMaxZ then
                                iPriority = iPriority - 4
                                --bIgnore = true
                                if bDebugMessages == true then LOG(sFunctionRef..': Corner position so no adjacency - priority decreased; iNewX='..iNewX..'; iNewZ='..iNewZ) end
                            end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Seeing if X or Z are within required range for adjacency. iNewX='..iNewX..'; iTargetMinX='..iTargetMinX..'; iTargetMaxX='..iTargetMaxX) end
                        if iNewX >= iTargetMinX and iNewX <= iTargetMaxX then
                            if bDebugMessages == true then LOG(sFunctionRef..': x value is within the required range for adjacency, now checking if z values are') end
                            --z value needs to be right by the min or max values:
                            if iNewZ == (iTargetMinZ - iNewBuildingRadius) or iNewZ == (iTargetMaxZ + iNewBuildingRadius) then
                                --valid co-ordinate
                                if bDebugMessages == true then LOG(sFunctionRef..': Should benefit from adjacency') end
                            else
                                --If it's within the target building area then ignore, otherwise record with lower priority as no adjacency:
                                if iNewZ < (iTargetMinZ - iNewBuildingRadius) or iNewZ > (iTargetMaxZ + iNewBuildingRadius) then
                                    iPriority = iPriority - 4
                                else bIgnore = true end
                                if bDebugMessages == true then LOG(sFunctionRef..': NewBuilding <= NewTarget size 1 - failed to find adjacency match so reducing priority by 4; iNewX='..iNewX..'; iNewZ='..iNewZ..'; iTargetMinX='..iTargetMinX..'; iTargetMaxX='..iTargetMaxX..'; iTargetMinZ='..iTargetMinZ..'; iTargetMaxZ='..iTargetMaxZ..'; iNewBuildingRadius='..iNewBuildingRadius..'; tNewBuildingSize[1] * fSizeMod='..tNewBuildingSize[1] * fSizeMod) end
                            end
                        else
                            if iNewZ >= iTargetMinZ and iNewZ <= iTargetMaxZ then
                                if iNewX == (iTargetMinX - iNewBuildingRadius) or iNewX == (iTargetMaxX + iNewBuildingRadius) then
                                    --Valid match
                                    if bDebugMessages == true then LOG(sFunctionRef..': Should benefit from adjacency') end
                                else
                                    --If it's within the target building area then ignore, otherwise record with lower priority as no adjacency:
                                    if iNewX < (iTargetMinX - iNewBuildingRadius) or iNewX > (iTargetMaxX + iNewBuildingRadius) then
                                        iPriority = iPriority - 4
                                    else bIgnore = true end
                                    if bDebugMessages == true then LOG(sFunctionRef..': NewBuilding <= NewTarget size 2 - failed to find adjacency match so reducing priority by 4; iNewX='..iNewX..'; iNewZ='..iNewZ..'; iTargetMinX='..iTargetMinX..'; iTargetMaxX='..iTargetMaxX..'; iTargetMinZ='..iTargetMinZ..'; iTargetMaxZ='..iTargetMaxZ..'; iNewBuildingRadius='..iNewBuildingRadius..'; tNewBuildingSize[1] * fSizeMod='..tNewBuildingSize[1] * fSizeMod) end
                                end
                            else
                                if (iNewX < (iTargetMinX - iNewBuildingRadius) or iNewX > (iTargetMaxX + iNewBuildingRadius)) and (iNewZ < (iTargetMinZ - iNewBuildingRadius) or iNewZ > (iTargetMaxZ + iNewBuildingRadius)) then
                                    --should be valid just no adjacency
                                    iPriority = iPriority - 4
                                else bIgnore = true end
                                if bDebugMessages == true then LOG(sFunctionRef..': NewBuilding <= NewTarget size 3 - failed to find adjacency match so reducing priority by 4; iNewX='..iNewX..'; iNewZ='..iNewZ..'; iTargetMinX='..iTargetMinX..'; iTargetMaxX='..iTargetMaxX..'; iTargetMinZ='..iTargetMinZ..'; iTargetMaxZ='..iTargetMaxZ..'; iNewBuildingRadius='..iNewBuildingRadius..'; tNewBuildingSize[1] * fSizeMod='..tNewBuildingSize[1] * fSizeMod) end
                            end
                        end
                        -- If bCheckValid then see if aiBrain can build the desired structure at the location
                    end
                end
                --Check if already queued up
                --if bIgnore == false and bLookForQueuedBuildings == true then
                --bIgnore = not(CanBuildAtLocation(aiBrain, sNewBuildingBPID, { iNewX, GetTerrainHeight(iNewX, iNewZ), iNewZ }, nil, nil, bLookForQueuedBuildings))

                --[[local sLocationRef = M27Utilities.ConvertLocationToReference({iNewX, 0, iNewZ})
        --reftEngineerAssignmentsByLocation --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the engineer unique ref assigned to this location
        if aiBrain[reftEngineerAssignmentsByLocation] and aiBrain[reftEngineerAssignmentsByLocation][sLocationRef] then
            if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef]) == false then bIgnore = true end
        end--]]
                --end
                local rBuildAreaRect
                if bIgnore == false then
                    --Check for reclaim:
                    if bBetterIfNoReclaim == true then

                        rBuildAreaRect = Rect(iNewX - iNewBuildingRadius + iRectangleSizeReduction, iNewZ - iNewBuildingRadius + iRectangleSizeReduction, iNewX + iNewBuildingRadius - iRectangleSizeReduction, iNewZ + iNewBuildingRadius - iRectangleSizeReduction)
                        --ReturnType: 1 = true/false: GetReclaimInRectangle(iReturnType, rRectangleToSearch)
                        if M27MapInfo.GetReclaimInRectangle(1, rBuildAreaRect) == true then iPriority = iPriority - 4 end
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Want to avoid reclaim if we can; Checking if any reclaim in the area, rBuildAreaRec='..repru(rBuildAreaRect)..'; iNewBuildingRadius='..iNewBuildingRadius..'; iRectangleSizeReduction='..iRectangleSizeReduction..'; iNewX-Z='..iNewX..'-'..iNewZ..'; M27MapInfo.GetReclaimInRectangle(1, rBuildAreaRect)='..tostring((M27MapInfo.GetReclaimInRectangle(1, rBuildAreaRect) or false)))
                        end
                    end
                end
                if bIgnore ==  false then
                    CurPosition = {iNewX, GetTerrainHeight(iNewX, iNewZ), iNewZ}

                    if bCheckValid then
                        if not(CanBuildAtLocation(aiBrain, sNewBuildingBPID, CurPosition, nil, false, bLookForQueuedBuildings)) then
                            --if aiBrain:CanBuildStructureAt(sNewBuildingBPID, CurPosition) == false or not(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][M27Utilities.ConvertLocationToReference(CurPosition)])) then
                            bIgnore = true
                            if bDebugMessages == true then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef..': aiBrain cant build at iNewX='..iNewX..'; iNewZ='..iNewZ..'; CurPosition='..CurPosition[1]..'-'..CurPosition[2]..'-'..CurPosition[3])
                                end
                            end
                        end
                    end
                end
                --Ignore if -ve priority and already have better:
                if iPriority < 0 and iMaxPriority > iPriority then
                    if bDebugMessages == true then LOG(sFunctionRef..': Ignoring location as priority too low; iPriority='..iPriority..';iMaxPriority='..iMaxPriority..'; iNewX='..iNewX..'; iNewZ='..iNewZ) end
                    bIgnore = true end

                if bIgnore == false then
                    if not(bIgnore) and aiBrain[M27Overseer.refbDefendAgainstArti] then
                        if M27Logic.IsLocationUnderFriendlyFixedShield(aiBrain, CurPosition) then
                            iPriority = iPriority + 15
                        end
                    end
                    -- We now have a co-ordinate that should result in newbuilding being built adjacent to target building (unless negative priority); check other conditions/priorities
                    iPriority = iPriority + 1


                    if bDebugMessages == true then LOG(sFunctionRef..': Have valid build location, iPriority pre considering build distance='..iPriority..'; CurPosition[1]='..CurPosition[1]..'-'..CurPosition[2]..'-'..CurPosition[3]) end
                    if bIgnoreOutsideBuildArea == true or bReturnOnlyBestMatch == true then iDistanceBetween = M27Utilities.GetDistanceBetweenBuildingPositions(pBuilderPos, CurPosition, iNewBuildingRadius) end
                    --if bIgnoreOutsideBuildArea == true or bReturnOnlyBestMatch == true then iDistanceBetween = GetDistanceBetweenPositions(pBuilderPos, PosTarget) end
                    if bReturnOnlyBestMatch == true then
                        --Check if within build area:
                        if iDistanceBetween <= iMaxAreaToSearch then
                            if bDebugMessages == true then LOG(sFunctionRef..': Is within build area, iDistanceBetween='..iDistanceBetween..'; iMaxAreaToSearch='..iMaxAreaToSearch) end
                            if iDistanceBetween > 0 then
                                iPriority = iPriority + 4
                            else iPriority = iPriority + 1
                            end
                            if iDistanceBetween <= iBuilderRange then iPriority = iPriority + 2 end
                        end
                        --Deduct 3 if ACU would have to move to build - should hopefully be covered by above
                        --if pBuilderPos[1] >= iNewX - tNewBuildingSize[1] * fSizeMod and pBuilderPos[1] <= iNewX + tNewBuildingSize[1] * fSizeMod then
                        --if pBuilderPos[3] >= iNewZ - tNewBuildingSize[2] * fSizeMod and pBuilderPos[3] <= iNewX + tNewBuildingSize[2] * fSizeMod then
                        --iPriority = iPriority - 3
                        --end
                        --end
                        --Check if level with target (makes it easier for other buildings to get adjacency):
                        if bWantAdjacency then
                            if CurPosition[1] - iNewBuildingRadius == iTargetMinX then iPriority = iPriority + 1 end
                            if CurPosition[1] + iNewBuildingRadius == iTargetMaxX then iPriority = iPriority + 1 end
                            if CurPosition[3] - iNewBuildingRadius == iTargetMinZ then iPriority = iPriority + 1 end
                            if CurPosition[3] + iNewBuildingRadius == iTargetMaxZ then iPriority = iPriority + 1 end
                        end
                    end
                    if bIgnoreOutsideBuildArea == true then
                        if iDistanceBetween > iMaxAreaToSearch then
                            bIgnore = true
                            if bDebugMessages == true then LOG(sFunctionRef..': Ignoring as iDistanceBetween='..iDistanceBetween..'; normal dist='..M27Utilities.GetDistanceBetweenPositions(pBuilderPos, CurPosition)) end
                        else iPriority = iPriority - 2
                        end
                    end

                    --Check if any units in the area (if not then icnrease priority)
                    if AreMobileUnitsInRect(rBuildAreaRect) == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': No mobile units are in the build area rectangle='..repru(rBuildAreaRect)) end
                        iPriority = iPriority + 1
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': mobile units are in the build area rectangle='..repru(rBuildAreaRect)) end
                    end

                    --Check if want to weight for if its closer or further from start (jsut enough that it affects equal priority locations)
                    if bPreferCloseToEnemy or bPreferFarFromEnemy then
                        iDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(CurPosition, tEnemyStartPosition)
                        if iDistanceToEnemy < iMinDistanceToEnemy then iMinDistanceToEnemy = iDistanceToEnemy end
                        if iDistanceToEnemy > iMaxDistanceToEnemy then iMaxDistanceToEnemy = iDistanceToEnemy end
                    end

                    if bIgnore == false then
                        --Check not blocking a mex
                        if bDebugMessages == true then LOG(sFunctionRef..': About to check whether we will block a mex by building '..sNewBuildingBPID..' and CurPosition='..repru(CurPosition)) end
                        if bDontBuildByMex and WillBuildingBlockMex(sNewBuildingBPID, CurPosition) then bIgnore = true end
                        if bIgnore == false then
                            iValidPosCount = iValidPosCount + 1
                            PossiblePositions[iValidPosCount] = CurPosition
                            iValidPositionPriorities[iValidPosCount] = iPriority
                            iValidPositionDistanceToEnemy[iValidPosCount] = iDistanceToEnemy
                            if iPriority > iMaxPriority then
                                iMaxPriority = iPriority
                                if bReturnOnlyBestMatch == true then
                                    tBestPosition = CurPosition
                                end
                            end
                            if bDebugMessages == true then if bReturnOnlyBestMatch == true then LOG('iPriority='..iPriority..'; iDistanceBetween='..iDistanceBetween) end end
                            if bDebugMessages == true then LOG(sFunctionRef..': iValidPosCount='..iValidPosCount..'; PossiblePositions[iValidPosCount][1-2-3]='..PossiblePositions[iValidPosCount][1]..'-'..PossiblePositions[iValidPosCount][2]..'-'..PossiblePositions[iValidPosCount][3]..'; bReturnOnlyBestMatch='..tostring(bReturnOnlyBestMatch)) end
                        end
                    end
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef..': End of considering this option, bIgnore='..tostring(bIgnore)..'; iPriority='..iPriority)
                    if bIgnore == true or iPriority < 0 then
                        LOG('WIll draw a red circle as are wanting to ignore or the location has negative priority')
                        M27Utilities.DrawLocation(CurPosition, nil, 2, 100)
                    else
                        LOG('WIll draw a white circle as dont want to ignore and priority is 0 or more')
                        M27Utilities.DrawLocation(CurPosition, nil, 7, 100)
                    end
                end
                --end
            end
            --end
        end
    end
    if iValidPosCount >= 1 then
        --Check if want to weight for if its closer or further from start (jsut enough that it affects equal priority locations)
        if bDebugMessages == true then LOG(sFunctionRef..': Considering if closest or furthest from enemy; bPreferCloseToEnemy='..tostring(bPreferCloseToEnemy)..'; bPreferFarFromEnemy='..tostring(bPreferFarFromEnemy)) end
        if bPreferCloseToEnemy or bPreferFarFromEnemy then
            for iPosition, tPosition in PossiblePositions do
                iDistanceToEnemy = iValidPositionDistanceToEnemy[iPosition]
                iPriority = iValidPositionPriorities[iPosition]
                bHaveGoodMatch = false
                if bPreferFarFromEnemy == true and iDistanceToEnemy >= iMaxDistanceToEnemy then bHaveGoodMatch = true
                elseif bPreferCloseToEnemy == true and iDistanceToEnemy <= iMinDistanceToEnemy then bHaveGoodMatch = true end
                if bDebugMessages == true then LOG(sFunctionRef..': iPosition='..iPosition..'; tPosition='..repru(tPosition)..'iPriority pre distance='..iPriority..'; iDistanceToEnemy='..iDistanceToEnemy..'; iMaxDistanceToEnemy='..iMaxDistanceToEnemy..'; iMinDistanceToEnemy='..iMinDistanceToEnemy..'; bHaveGoodMatch='..tostring(bHaveGoodMatch)) end
                if bHaveGoodMatch == true then
                    iPriority = iPriority + 0.5
                    if iPriority > iMaxPriority then
                        iMaxPriority = iPriority
                        tBestPosition = tPosition
                    end
                end
            end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Near end of code, will return value depending on specifics') end
        if bReturnOnlyBestMatch then
            --Firebase specific - build within shield if there is one nearby
            if tBestPosition and EntityCategoryContains(M27UnitInfo.refCategoryFirebaseSuitable, sNewBuildingBPID) then
                local iSearchRange = 20
                local iExtraDist = 0
                if EntityCategoryContains(M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategoryT2Radar + categories.TECH3, sNewBuildingBPID) then
                    iSearchRange = 40
                    iExtraDist = 20
                end
                local tNearbyShields = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedShield, tBestPosition, iSearchRange, 'Ally')
                if M27Utilities.IsTableEmpty(tNearbyShields) == false and not(M27Logic.IsLocationUnderFriendlyFixedShield(aiBrain, tBestPosition)) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have shields nearby so will see if can move closer to shield') end

                    local tClosestShield = M27Utilities.GetNearestUnit(tNearbyShields, tBestPosition, aiBrain):GetPosition()
                    local iDistToShield = M27Utilities.GetDistanceBetweenPositions(tClosestShield, tBestPosition)
                    if iDistToShield >= 4 then
                        local tValidCloserLocation
                        local tCloserBuildLocation
                        local iAngleToShield = M27Utilities.GetAngleFromAToB(tBestPosition, tClosestShield)
                        for iTravelDist = 2, math.min(math.floor(iDistToShield / 2)*2 - 2) + iExtraDist, 2 do
                            tCloserBuildLocation = M27Utilities.MoveInDirection(tBestPosition, iAngleToShield, iTravelDist, true)
                            if CanBuildAtLocation(aiBrain, sNewBuildingBPID, tCloserBuildLocation, nil, false, bLookForQueuedBuildings) then
                                tValidCloserLocation = {tCloserBuildLocation[1], tCloserBuildLocation[2], tCloserBuildLocation[3]}
                                if M27Logic.IsLocationUnderFriendlyFixedShield(aiBrain, tValidCloserLocation) then
                                    break
                                end
                            end
                        end
                        if not(tValidCloserLocation) and table.getn(tNearbyShields) > 1 then
                            --Try again for other shields, with random x and z movement
                            local tCurShieldPosition, iShieldSize, iRandX, iRandZ, iAngleToUnit
                            for iShield, oShield in tNearbyShields do
                                tCurShieldPosition = oShield:GetPosition()
                                iShieldSize = oShield:GetBlueprint().Defense.Shield.ShieldSize * 0.5
                                iAngleToUnit = M27Utilities.GetAngleFromAToB(tCurShieldPosition, tBestPosition)
                                if not(tCurShieldPosition[1] == tClosestShield[1]) and not(tCurShieldPosition[3] == tClosestShield[3]) then
                                    iDistToShield = M27Utilities.GetDistanceBetweenPositions(tCurShieldPosition, tBestPosition)
                                    if iDistToShield >= 6 then
                                        for iDistFromShieldToUnit = math.floor(iShieldSize / 2) * 2, 4, -2 do
                                            iRandX = math.random(-(iDistFromShieldToUnit - iShieldSize)*0.5, (iDistFromShieldToUnit - iShieldSize)*0.5)
                                            iRandZ = math.random(-(iDistFromShieldToUnit - iShieldSize)*0.5, (iDistFromShieldToUnit - iShieldSize)*0.5)
                                            tCloserBuildLocation = M27Utilities.MoveInDirection(tCurShieldPosition, iAngleToUnit, iDistFromShieldToUnit, true)
                                            tCloserBuildLocation[1] = tCloserBuildLocation[1] + iRandX
                                            tCloserBuildLocation[3] = tCloserBuildLocation[3] + iRandZ
                                            if CanBuildAtLocation(aiBrain, sNewBuildingBPID, tCloserBuildLocation, nil, false, bLookForQueuedBuildings) then
                                                tValidCloserLocation = {tCloserBuildLocation[1], tCloserBuildLocation[2], tCloserBuildLocation[3]}
                                                if M27Logic.IsLocationUnderFriendlyFixedShield(aiBrain, tValidCloserLocation) then
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if tValidCloserLocation then
                            if bDebugMessages == true then LOG(sFunctionRef..': Have a valid location that is closr to the shield='..repru(tValidCloserLocation)..'; prev best position was '..repru(tBestPosition)) end
                            tBestPosition = {tValidCloserLocation[1], tValidCloserLocation[2], tValidCloserLocation[3]}
                        end
                    end

                end
            end

            if bDebugMessages == true then
                LOG(sFunctionRef..': Returning best possible position; tBestPosition[1]='..tBestPosition[1]..'-'..tBestPosition[2]..'-'..tBestPosition[3]..'; iMaxPriority='..iMaxPriority)
                LOG(sFunctionRef..': iMaxMapX='..iMaxMapX..'; iMaxMapZ='..iMaxMapZ..'tBestPosition='..repru(tBestPosition)..'; our start position='..repru(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]))
                M27Utilities.DrawLocations(PossiblePositions, nil, 3, 10)
                M27Utilities.DrawLocation(tBestPosition, nil, 7, 100) --draws best position in white
            end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return tBestPosition
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Returning table of possible positions; PossiblePositions[1][1]='..PossiblePositions[1][1]..'-'..PossiblePositions[1][2]..'-'..PossiblePositions[1][3]) end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return PossiblePositions
        end
    else
        if bDebugMessages == true then LOG(sFunctionRef..': No valid matches found. PosTarget='..PosTarget[1]..'-'..PosTarget[3]) end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return nil
    end

end

function BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tAlternativePositionToLookFrom, bLookForPartCompleteBuildings, bLookForQueuedBuildings, oUnitToBuildBy, bNeverBuildRandom, iOptionalCategoryForStructureToBuild, bBuildCheapestStructure, iOptionalEngiActionRef)
    --Determines the blueprint and location for oEngineer to build at; also returns the location
    --iCatToBuildBy: Optional, specify if want to look for adjacency locations; Note to factor in 50% of the builder's size and 50% of the likely adjacency building size
    --bLookForQueuedBuildings: Optional, if true, then doesnt choose a target if another engineer already has that target function ref assigned to build something
    --Returns nil if dealing with a non-resource based building

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'BuildStructureAtLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --if iCategoryToBuild == M27UnitInfo.refCategoryTML then bDebugMessages = true end
    --if GetEngineerUniqueCount(oEngineer) == 1 then bDebugMessages = true end
    --if GetEngineerUniqueCount(oEngineer) == 31 and GetGameTimeSeconds() >= 305 then bDebugMessages = true end


    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, Engineer UC='..GetEngineerUniqueCount(oEngineer)..'; Engineer LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; Techlevel='..M27UnitInfo.GetUnitTechLevel(oEngineer)..'; tAlternativePositionToLookFrom='..repru(tAlternativePositionToLookFrom or {'nil'})..'; bBuildCheapestStructure='..tostring((bBuildCheapestStructure or false))..'; bNeverBuildRandom='..tostring((bNeverBuildRandom or false))..'; All blueprints that meet the category='..repru(EntityCategoryGetUnitList(iCategoryToBuild))..'; iMaxAreaToSearch='..(iMaxAreaToSearch or 'nil')) end


    local bAbortConstruction = false

    --GetBlueprintsThatCanBuildOfCategory(aiBrain, iCategoryCondition, oFactory, bGetSlowest, bGetFastest, iOptionalCategoryThatMustBeAbleToBuild, bGetCheapest)
    local sBlueprintToBuild = M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, iCategoryToBuild, oEngineer, false, false, iOptionalCategoryForStructureToBuild, bBuildCheapestStructure)

    --Increase max area to search if dealing with czar or similarly large unit due to its size
    if __blueprints[sBlueprintToBuild].Physics.SkirtSizeX >= 10 then
        iMaxAreaToSearch = iMaxAreaToSearch * 1.5
        if bDebugMessages == true then LOG(sFunctionRef..': Building a large unit such as a czar, increased iMaxAreaToSearch to '..iMaxAreaToSearch) end
    end

    --Reduce max area to search if dealing with a shield
    if EntityCategoryContains(M27UnitInfo.refCategoryFixedShield, sBlueprintToBuild) then
        iMaxAreaToSearch = math.min(iMaxAreaToSearch, (__blueprints[sBlueprintToBuild].Defense.Shield.ShieldSize or 0) * 0.5)
        if bDebugMessages == true then LOG(sFunctionRef..': Dealing with a shield so reduce max area to search based on half of shield size. iMaxAreaToSearch='..(iMaxAreaToSearch or 'nil')..'; shield size='..__blueprints[sBlueprintToBuild].Defense.Shield.ShieldSize or 0) end
    end


    --if GetGameTimeSeconds() >= 1234 and sBlueprintToBuild == 'urb1103' then bDebugMessages = true end
    if bDebugMessages == true then LOG(sFunctionRef..': sBlueprintToBuild='..(sBlueprintToBuild or 'nil')..'; Location to look from='..repru(tAlternativePositionToLookFrom or oEngineer:GetPosition())) end
    local sBlueprintBuildBy
    local bFindRandomLocation = false
    local tTargetLocation = tAlternativePositionToLookFrom
    local tEngineerPosition = oEngineer:GetPosition()
    if not(tTargetLocation) then tTargetLocation = tEngineerPosition end
    local bFoundEnemyInstead = false

    if sBlueprintToBuild == nil then
        M27Utilities.ErrorHandler('sBlueprintToBuild is nil, could happen e.g. if try and get sparky to build sxomething it cant - refer to log for more details')
        if not(iCategoryToBuild) then LOG(sFunctionRef..': No category to build. oEngineer='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer))
        else
            LOG(sFunctionRef..': Had category to build. oEngineer='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer)..'; All blueprints that satisfy the category='..repru(EntityCategoryGetUnitList(iCategoryToBuild)))
        end
        tTargetLocation = nil
    else
        local iNewBuildingRadius = M27UnitInfo.GetBuildingSize(sBlueprintToBuild)[1] * 0.5
        local iBuilderRange = oEngineer:GetBlueprint().Economy.MaxBuildDistance + math.min(oEngineer:GetBlueprint().SizeX, oEngineer:GetBlueprint().SizeZ)*0.5
        local iDistanceFromStart = M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        local bBuildNearToEnemy = false
        if iDistanceFromStart <= 80 then bBuildNearToEnemy = true end

        --Check we're not trying to buidl a mex or hydro or mass storage
        local bMexHydroOrStorage = false
        if EntityCategoryContains(refCategoryMex, sBlueprintToBuild) or EntityCategoryContains(refCategoryHydro, sBlueprintToBuild) or EntityCategoryContains(M27UnitInfo.refCategoryMassStorage, sBlueprintToBuild) then bMexHydroOrStorage = true end

        --Check if is an existing building of the type wanted first:
        local oPartCompleteBuilding
        if bLookForPartCompleteBuildings then
            --GetPartCompleteBuilding(aiBrain, oBuilder, iCategoryToBuild, iBuildingSearchRange, iEnemySearchRange)
            --Returns nil if no nearby part complete building
            --iEnemySearchRange: nil if dont care about nearby enemies, otherwise will ignore buildings that have enemies within iEnemySearchRange
            oPartCompleteBuilding = GetPartCompleteBuilding(aiBrain, oEngineer, iCategoryToBuild, iBuilderRange + 15, nil)
        end
        if oPartCompleteBuilding then
            if bDebugMessages == true then LOG(sFunctionRef..': have partcompletebuilding so returning that as the position') end
            tTargetLocation = oPartCompleteBuilding:GetPosition()
        else
            if bDebugMessages == true then
                local sEngUniqueRef = GetEngineerUniqueCount(oEngineer)
                LOG(sFunctionRef..': Eng builder unique ref='..sEngUniqueRef..'; builder range='..iBuilderRange)
            end



            if not(bMexHydroOrStorage) then
                if iCatToBuildBy or oUnitToBuildBy then
                    local oPossibleBuildingsToBuildBy
                    local iBuildingCount = 0
                    local tPossibleTargets = {}
                    local tBuildingPosition

                    if iCatToBuildBy then
                        sBlueprintBuildBy = M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, iCatToBuildBy, oEngineer)--, false, false)
                        if bDebugMessages == true then LOG(sFunctionRef..': Engineer position='..repru(oEngineer:GetPosition())..'; tTargetLocation='..repru(tTargetLocation)..'; iMaxAreaToSearch='..iMaxAreaToSearch) end
                        oPossibleBuildingsToBuildBy = aiBrain:GetUnitsAroundPoint(iCatToBuildBy, tTargetLocation, iMaxAreaToSearch, 'Ally')
                    elseif oUnitToBuildBy then
                        sBlueprintBuildBy = oUnitToBuildBy.UnitId
                        oPossibleBuildingsToBuildBy = {oUnitToBuildBy}
                    else M27Utilities.ErrorHandler('Missing code')
                    end


                    if M27Utilities.IsTableEmpty(oPossibleBuildingsToBuildBy) == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have possible buildings to build by, so will consider best location') end
                        for iBuilding, oBuilding in oPossibleBuildingsToBuildBy do
                            if not(oBuilding.Dead) and oBuilding.GetPosition then
                                tBuildingPosition = oBuilding:GetPosition()
                                if M27Utilities.GetDistanceBetweenPositions(tBuildingPosition, tTargetLocation) <= iMaxAreaToSearch then
                                    --Check we're not building by a mex
                                    --if M27Utilities.IsTableEmpty(M27MapInfo.GetResourcesNearTargetLocation(tBuildingPosition, iNewBuildingRadius, true)) == true then
                                    --if bDebugMessages == true then LOG(sFunctionRef..': No resources near the target build position') end
                                    iBuildingCount = iBuildingCount + 1
                                    tPossibleTargets[iBuildingCount] = tBuildingPosition
                                    --else
                                    --if bDebugMessages == true then LOG(sFunctionRef..': Have resources near the target build position') end
                                    --end
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Found iBuildingCount='..iBuildingCount..' to build by') end
                    else
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Cant find any buildings for adjacency, getting random location to build unless we want to build by a mex/hydro and have an unbuilt one nearby')
                            local tNearestBuildingOfCategory = aiBrain:GetUnitsAroundPoint(iCatToBuildBy, tTargetLocation, 10000, 'Ally')
                            if M27Utilities.IsTableEmpty(tNearestBuildingOfCategory) then LOG(sFunctionRef..': Dont have any units of the desired category anywhere on map')
                            else
                                local oNearestBuildingOfCategory = M27Utilities.GetNearestUnit(tNearestBuildingOfCategory, oEngineer:GetPosition(), aiBrain)
                                LOG(sFunctionRef..': Nearest unit of desired category is '..oNearestBuildingOfCategory.UnitId..M27UnitInfo.GetUnitLifetimeCount(oNearestBuildingOfCategory)..' which is '..M27Utilities.GetDistanceBetweenPositions(oNearestBuildingOfCategory:GetPosition(), oEngineer:GetPosition())..' away from the engineer')
                            end
                        end
                        bFindRandomLocation = not(bNeverBuildRandom)
                    end
                    --Also check for unbuilt buildings if dealing with a mex or hydro, unless are building a shield
                    local tResourceLocations
                    if not(EntityCategoryContains(categories.SHIELD, sBlueprintToBuild)) then
                        if EntityCategoryContains(M27UnitInfo.refCategoryMex, sBlueprintBuildBy) then
                            tResourceLocations = M27MapInfo.GetResourcesNearTargetLocation(tTargetLocation, 30, true)
                        elseif EntityCategoryContains(M27UnitInfo.refCategoryHydro, sBlueprintBuildBy) or EntityCategoryContains(M27UnitInfo.refCategoryT2Power, sBlueprintBuildBy) then --Dont want to make this all power, because the adjacency code requires a building size, and only works for a single building size; i.e. if try and get adjacency for t1 power and include hydro locations, then it will think it needs to build within the hydro for adjacency
                            tResourceLocations = M27MapInfo.GetResourcesNearTargetLocation(tTargetLocation, 30, false)
                        end
                    end
                    if M27Utilities.IsTableEmpty(tResourceLocations) == false then
                        for iResource, tCurResourceLocation in tResourceLocations do
                            iBuildingCount = iBuildingCount + 1
                            tPossibleTargets[iBuildingCount] = tCurResourceLocation
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Will try and build by resource location (mex or hydro); iBuildingCount including these locations='..iBuildingCount..'; table of building locations='..repru(tPossibleTargets)) end
                    end
                    if iBuildingCount > 0 then
                        --GetBestBuildLocationForTarget(tablePosTarget, sTargetBuildingBPID, sNewBuildingBPID, bCheckValid, aiBrain, bReturnOnlyBestMatch, pBuilderPos, iMaxAreaToSearch, iBuilderRange, bIgnoreOutsideBuildArea, bBetterIfNoReclaim, bPreferCloseToEnemy, bPreferFarFromEnemy, bLookForQueuedBuildings)
                        if EntityCategoryContains(M27UnitInfo.refCategoryFixedShield, sBlueprintToBuild) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Will try and build the shield anywhere near the target. iOptionalEngiActionRef='..(iOptionalEngiActionRef or 'nil')) end
                            local bBuildAwayFromEnemy = false
                            if iOptionalEngiActionRef == refActionFortifyFirebase then bBuildAwayFromEnemy = true end
                            tTargetLocation = GetBuildLocationForShield(aiBrain, sBlueprintToBuild, tAlternativePositionToLookFrom, bBuildAwayFromEnemy)
                            if not(tTargetLocation) then bAbortConstruction = true end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': About to call GetBestBuildLocation; iBuildingCount='..iBuildingCount..'; sBlueprintBuildBy='..sBlueprintBuildBy) end
                            tTargetLocation = GetBestBuildLocationForTarget(tPossibleTargets, sBlueprintBuildBy, sBlueprintToBuild, true, aiBrain, true, tTargetLocation, iMaxAreaToSearch, iBuilderRange, false, true, bBuildNearToEnemy, not(bBuildNearToEnemy), bLookForQueuedBuildings)

                            if M27Utilities.IsTableEmpty(tTargetLocation) == true then
                                if bDebugMessages == true then LOG('Adjacency location is empty, will try finding anywhere to build') end
                                bFindRandomLocation = not(bNeverBuildRandom)
                            else
                                bFindRandomLocation = false
                                if bDebugMessages == true then LOG(sFunctionRef..': Have determined the best build location for target to be '..repru(tTargetLocation)..'; will double-check we can build here') end
                                if not(CanBuildAtLocation(aiBrain, sBlueprintToBuild, tTargetLocation, nil, false, bLookForQueuedBuildings)) then
                                    --if aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation) == false or not(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][M27Utilities.ConvertLocationToReference(tTargetLocation)])) then
                                    M27Utilities.ErrorHandler('Cant build '..sBlueprintToBuild..' on adjacency location tTargetLocation='..repru({tTargetLocation[1], tTargetLocation[2],tTargetLocation[3]}))
                                    bFindRandomLocation = not(bNeverBuildRandom)
                                else
                                    --Check we're within mapBoundary
                                    if bDebugMessages == true then LOG(sFunctionRef..': Cant build at the location; Checking if tTargetLocation '..repru(tTargetLocation)..' is in the playable area '..repru(M27MapInfo.rMapPlayableArea)..' based on building size radius='..iNewBuildingRadius) end
                                    if (tTargetLocation[1] - iNewBuildingRadius) < M27MapInfo.rMapPlayableArea[1] or (tTargetLocation[3] - iNewBuildingRadius) < M27MapInfo.rMapPlayableArea[2] or (tTargetLocation[1] + iNewBuildingRadius) > M27MapInfo.rMapPlayableArea[3] or (tTargetLocation[3] + iNewBuildingRadius) > M27MapInfo.rMapPlayableArea[4] then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Target location isnt in playable area so will find random place to build instead') end
                                        bFindRandomLocation = not(bNeverBuildRandom)
                                        tTargetLocation = tEngineerPosition
                                    end
                                    if bDebugMessages == true then M27Utilities.DrawLocation(tTargetLocation) end
                                end
                            end
                        end
                    else
                        bFindRandomLocation = not(bNeverBuildRandom)
                        if bDebugMessages == true then LOG(sFunctionRef..': Cant find any valid buildings for adjacency') end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Dont have a category to build by, will look for random location unless current target is valid or we are a shield') end
                    if EntityCategoryContains(M27UnitInfo.refCategoryFixedShield, sBlueprintToBuild) then
                        local bBuildAwayFromEnemy = false
                        if iOptionalEngiActionRef == refActionFortifyFirebase then bBuildAwayFromEnemy = true end
                        tTargetLocation = GetBuildLocationForShield(aiBrain, sBlueprintToBuild, tAlternativePositionToLookFrom, bBuildAwayFromEnemy)
                        if tTargetLocation then bFindRandomLocation = false else bFindRandomLocation = not(bNeverBuildRandom) end
                    else
                        bFindRandomLocation = not(bNeverBuildRandom)
                    end
                end
            else
                --Dealing with mex or hydro or storage
                if bDebugMessages == true then LOG(sFunctionRef..': Are trying to build a mex, hydro or storage; tTargetLocation='..repru((tTargetLocation or {}))..'; oEngineer='..GetEngineerUniqueCount(oEngineer)..'; LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)) end
                if M27Utilities.IsTableEmpty(tTargetLocation) == true then
                    M27Utilities.ErrorHandler('Trying to build mex, hydro or storage without defined location')
                else
                    if aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation) then --and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][M27Utilities.ConvertLocationToReference(tTargetLocation)]) then
                        --Not interested in if other units have queued up, as e.g. might be ACU that can build and is much closer, so just want whichever unit is closest to try and build
                        if bDebugMessages == true then LOG(sFunctionRef..': Can build structure at targetlocation='..repru(tTargetLocation)..'; if are buildling a t1 mex and there is a t3 mex queued up then will ignore though') end
                        --Are we trying to build a T1 mex? If so then only consider if have an order to build T3 mex
                        if EntityCategoryContains(refCategoryT1Mex, sBlueprintToBuild) then
                            local sLocationRef = M27Utilities.ConvertLocationToReference(tTargetLocation)
                            if aiBrain[reftEngineerAssignmentsByLocation][sLocationRef] and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][refActionBuildT3MexOverT2]) == false then
                                bAbortConstruction = true
                                if bDebugMessages == true then LOG(sFunctionRef..': Trying to build t1 mex when want to build t3 here') end
                            end
                        end
                    else
                        --Cant build at location, is that because of enemy building blocking it, or we have a part-built building?
                        if bDebugMessages == true then LOG(sFunctionRef..': Are trying to build a mex or hydro or mass storage so cant get a random location, but we cant build a structure at the target') end
                        local tEnemyBuildingAtTarget = aiBrain:GetUnitsAroundPoint(iCategoryToBuild, tTargetLocation, 1, 'Enemy')
                        if M27Utilities.IsTableEmpty(tEnemyBuildingAtTarget) == false then
                            if bDebugMessages == true then LOG(sFunctionRef..': Have enemy buildings around target') end
                            M27PlatoonUtilities.MoveNearConstruction(aiBrain, oEngineer, tTargetLocation, sBlueprintToBuild, 0, false, false, false)
                            for iUnit, oUnit in tEnemyBuildingAtTarget do
                                if oUnit.GetPosition then
                                    IssueReclaim({oEngineer}, oUnit)
                                end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': Enemy building is at the target mex/hydro so will try and reclaim that first') end

                            IssueBuildMobile({oEngineer}, tTargetLocation, sBlueprintToBuild, {})
                            if bDebugMessages == true then LOG(sFunctionRef..': 1 - Have sent issuebuildmobile order to engineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer)..' to build blueprint '..sBlueprintToBuild..' at location '..repru(tTargetLocation)) end
                            bAbortConstruction = true
                            bFoundEnemyInstead = true

                        else
                            local tAllyBuildingAtTarget = aiBrain:GetUnitsAroundPoint(iCategoryToBuild, tTargetLocation, 1, 'Ally')
                            if M27Utilities.IsTableEmpty(tAllyBuildingAtTarget) == false then
                                if bDebugMessages == true then LOG(sFunctionRef..': Will target the ally building as its part complete') end
                                oPartCompleteBuilding = tAllyBuildingAtTarget[1]
                            else
                                --Are we stopped from building due to reclaim?

                                local tNewBuildingSize = M27UnitInfo.GetBuildingSize(sBlueprintToBuild)
                                local fSizeMod = 0.5

                                local rTargetRect = M27Utilities.GetRectAroundLocation(tTargetLocation, tNewBuildingSize[1] * fSizeMod)
                                if bDebugMessages == true then LOG(sFunctionRef..': tTargetLocation='..repru(tTargetLocation)..'; tNewBuildingSize='..repru(tNewBuildingSize)..'; rTargetRect='..repru(rTargetRect)) end
                                --GetReclaimInRectangle(iReturnType, rRectangleToSearch)
                                --iReturnType: 1 = true/false; 2 = number of wrecks; 3 = total mass, 4 = valid wrecks
                                local tReclaimables = M27MapInfo.GetReclaimInRectangle(4, rTargetRect)

                                if M27Utilities.IsTableEmpty(tReclaimables) == false then
                                    for iReclaim, oReclaim in tReclaimables do
                                        --oEngineer:IssueReclaim(oReclaim)
                                        IssueReclaim({oEngineer}, oReclaim)
                                    end
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef..': Reclaim found that is blocking mex or hydro so will reclaim all wrecks in rectangle='..repru(rTargetRect))
                                        M27Utilities.DrawRectangle(rTargetRect, 7, 100)
                                    end

                                    IssueBuildMobile({oEngineer}, tTargetLocation, sBlueprintToBuild, {})
                                    if bDebugMessages == true then LOG(sFunctionRef..': 2 - Have sent issuebuildmobile order to engineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer)..' to build blueprint '..sBlueprintToBuild..' at location '..repru(tTargetLocation)) end

                                else
                                    --Are we trying to build a T3 mex? If so then we probably are trying to replace a T2 mex which  can lead to problems with the canbuild check
                                    if iCategoryToBuild == M27UnitInfo.refCategoryT3Mex then
                                        IssueBuildMobile({oEngineer}, tTargetLocation, sBlueprintToBuild, {})
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef..': Not sure we can build here but will try anyway')
                                            LOG(sFunctionRef..': 3 - Have sent issuebuildmobile order to engineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer)..' to build blueprint '..sBlueprintToBuild..' at location '..repru(tTargetLocation))
                                        end
                                    else
                                        --One likely explanation is that enemy has built on the mex and we cant see the building, in which case we only want to check this for debugging purposes, and proceed with the default action of having hte engineer try to move there
                                        local tUnits = GetUnitsInRect(rTargetRect)
                                        if M27Utilities.IsTableEmpty(tUnits) == true then
                                            M27Utilities.ErrorHandler(sFunctionRef..': Cant build at resource location but no units or reclaim on it, will just try moving near the target instead. sBlueprintToBuild='..sBlueprintToBuild..'; Engineer UC='..GetEngineerUniqueCount(oEngineer)..'; LC='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; Location='..repru({tTargetLocation[1], tTargetLocation[2],tTargetLocation[3]})..'; Will draw white circle around the target if in debug mode. CanBuildStructure result='..tostring(aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation))..'; Is the table of assigned engineer actions empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][M27Utilities.ConvertLocationToReference(tTargetLocation)])), true)
                                            if bDebugMessages == true then
                                                M27Utilities.DrawLocation(tTargetLocation, nil, 7)
                                                LOG(sFunctionRef..': Cnat build at TargetLocation='..repru(tTargetLocation)..'; RectangleSearched='..repru(rTargetRect))
                                            end
                                        end
                                        if bDebugMessages == true then LOG(sFunctionRef..': Will just move to the target location') end
                                        M27PlatoonUtilities.MoveNearConstruction(aiBrain, oEngineer, tTargetLocation, sBlueprintToBuild, 0, false, false, false)
                                        bAbortConstruction = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        --Switch to random location if an amphibious unit cant path there and its not a resource based location
        if not(bFindRandomLocation) and not(bAbortConstruction) then -- and not(bMexHydroOrStorage) then
            if not(M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tTargetLocation) == M27MapInfo.GetUnitSegmentGroup(oEngineer)) then
                if bDebugMessages == true then LOG(sFunctionRef..': Pathing group of the target is different to where we are, so will try and get a random location if its not a resource based building; Target amphibious pathing group='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tTargetLocation)..'; Pathing group of unit='..M27MapInfo.GetUnitSegmentGroup(oEngineer)..'; Amphibious pathing group of engineer current position='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oEngineer:GetPosition())..'; pathing group of base='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) end
                --Recheck pathing
                if not(M27MapInfo.RecheckPathingOfLocation(M27UnitInfo.refPathingTypeAmphibious, oEngineer, tTargetLocation, nil)) and not(bMexHydroOrStorage) then
                    bFindRandomLocation = not(bNeverBuildRandom)
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Pathing was wrong or are trying to build on a resource location so wont try and get random location but will proceed with current location') end
                end
            end
        end

        if bFindRandomLocation and (bMexHydroOrStorage or EntityCategoryContains(M27UnitInfo.refCategoryFixedShield, sBlueprintToBuild)) and not(bAbortConstruction) and not(iOptionalEngiActionRef == refActionFortifyFirebase) then
            --Backup - Trying to build a mex or hydro so no point getting random location
            if not(EntityCategoryContains(M27UnitInfo.refCategoryFixedShield, sBlueprintToBuild)) then
                M27Utilities.ErrorHandler('Are trying to build in a random place for am ex/hydro/mass storage - figure out why as this shouldnt trigger; Engineer with UC='..GetEngineerUniqueCount(oEngineer)..'='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; trying to build blueprint='..sBlueprintToBuild)
                if bDebugMessages == true then LOG(sFunctionRef..': Trying to build mex or hydro so cant choose a random location') end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Trying to build a shield but couldnt find anywhere to build it so no point building it in the end. iOptionalEngiActionRef='..(iOptionalEngiActionRef or 'nil')) end
            end
            bFindRandomLocation = false
            bAbortConstruction = true
        end

        if bFindRandomLocation == true and not(bAbortConstruction) then
            if bDebugMessages == true then LOG(sFunctionRef..': Are finding a random location to build unless current location is valid; sBlueprintToBuild='..sBlueprintToBuild..'; iMaxAreaToSearch='..(iMaxAreaToSearch or 'nil')) end
            if M27Utilities.IsTableEmpty(tTargetLocation) == true then tTargetLocation = (tAlternativePositionToLookFrom or tEngineerPosition) end

            --First check in build area for the best location assuming the target location isnt far away
            if M27Utilities.GetDistanceBetweenPositions(tTargetLocation, tEngineerPosition) <= 30 then tTargetLocation = GetBestBuildLocationForTarget(tTargetLocation, nil, sBlueprintToBuild, true, aiBrain, true, tTargetLocation, iMaxAreaToSearch, iBuilderRange, false, true, bBuildNearToEnemy, not(bBuildNearToEnemy), false) end
            if M27Utilities.IsTableEmpty(tTargetLocation) == true or not(CanBuildAtLocation(aiBrain, sBlueprintToBuild, tTargetLocation, nil, false, bLookForQueuedBuildings)) then
                --if M27Utilities.IsTableEmpty(tTargetLocation) == true or not(aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation)) or not(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][M27Utilities.ConvertLocationToReference(tTargetLocation)])) then
                if M27Utilities.IsTableEmpty(tTargetLocation) then tTargetLocation = (tAlternativePositionToLookFrom or tEngineerPosition) end
                if bDebugMessages == true then
                    LOG(sFunctionRef..' Cant build '..sBlueprintToBuild..'; will try and find a random place to build; target location for random place to build='..repru(tTargetLocation))
                    if iCategoryToBuild == nil then LOG(sFunctionRef..' iCategoryToBuild is nil somehow') end
                end
                --FindRandomPlaceToBuild(aiBrain, oBuilder, tStartPosition, sBlueprintToBuild, iSearchSizeMin, iSearchSizeMax, bForcedDebug)
                tTargetLocation = FindRandomPlaceToBuild(aiBrain, oEngineer, tTargetLocation, sBlueprintToBuild, 2, iMaxAreaToSearch, bDebugMessages)
                if M27Utilities.IsTableEmpty(tTargetLocation) == true then
                    LOG(sFunctionRef..': WARNING - couldnt find a random place to build based on position='..repru(tTargetLocation)..'; will abort construction')
                    bAbortConstruction = true
                elseif bDebugMessages == true then LOG(sFunctionRef..': Found random place to build='..repru(tTargetLocation))
                end
            else if bDebugMessages == true then LOG(sFunctionRef..': No need for random place as current targetlocation is valid, ='..repru(tTargetLocation)) end
            end
        end
        if bAbortConstruction == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Not aborting function so will try to move near construction if we have a valid location') end
            if M27Utilities.IsTableEmpty(tTargetLocation) == false and sBlueprintToBuild then
                --Adjust Target location if building PD
                if EntityCategoryContains(M27UnitInfo.refCategoryPD, sBlueprintToBuild) then tTargetLocation = AdjustPDBuildLocation(aiBrain, tTargetLocation, sBlueprintToBuild) end

                M27PlatoonUtilities.MoveNearConstruction(aiBrain, oEngineer, tTargetLocation, sBlueprintToBuild, 0, false, false, false)
                if oPartCompleteBuilding then
                    if bDebugMessages == true then LOG(sFunctionRef..': Send order for oEngineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' to repair '..oPartCompleteBuilding.UnitId..M27UnitInfo.GetUnitLifetimeCount(oPartCompleteBuilding)..' at '..repru(oPartCompleteBuilding:GetPosition())) end
                    IssueRepair({ oEngineer}, oPartCompleteBuilding)
                else
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': Send order for oEngineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' to build '..sBlueprintToBuild..' at '..repru(tTargetLocation)..'; will draw target location in gold')
                        M27Utilities.DrawLocation(tTargetLocation, nil, 4, 500)
                    end

                    --MAIN ISSUEBUILDMOBILE FOR CONSTRUCTION (i.e. other issuebuilds here are for specific actions)
                    IssueBuildMobile({oEngineer}, tTargetLocation, sBlueprintToBuild, {})
                    if bDebugMessages == true then LOG(sFunctionRef..': 4 - Have sent issuebuildmobile order to engineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer)..' to build blueprint '..sBlueprintToBuild..' at location '..repru(tTargetLocation)) end
                end
            end
        else
            if bDebugMessages == true then LOG('Warning - couldnt find any places to build after looking randomly nearby, will abort construction. bFoundEnemyInstead='..tostring(bFoundEnemyInstead)) end
            if bDebugMessages == true then
                LOG(sFunctionRef..': Aborted construction, will draw target location in red')
                M27Utilities.DrawLocation(tTargetLocation, nil, 2, 100)
            end
            if not(bMexHydroOrStorage) then tTargetLocation = nil end
        end
    end
    if bDebugMessages == true then
        if sBlueprintToBuild == nil then LOG('sBlueprintToBuild is nil')
        else
            if tTargetLocation then
                LOG(sFunctionRef..': tTargetLocation='..repru(tTargetLocation)..'; aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation)='..tostring(aiBrain:CanBuildStructureAt(sBlueprintToBuild, tTargetLocation))..'; sBlueprintToBuild='..(sBlueprintToBuild or 'nil'))
                if not(bAbortConstruction) then M27Utilities.DrawLocation(tTargetLocation, nil, 7, 100) end --show in white (colour 7)
                LOG(sFunctionRef..': About to list any units in 1x1 rectangle around targetlocation')
                local iSizeAdj = 3
                local rBuildAreaRect = Rect(tTargetLocation[1] - iSizeAdj, tTargetLocation[3] - iSizeAdj, tTargetLocation[1] + iSizeAdj, tTargetLocation[3] + iSizeAdj)
                local tUnitsInRect = GetUnitsInRect(rBuildAreaRect)
                local tsUnitRefs = {}
                if M27Utilities.IsTableEmpty(tUnitsInRect) == false then
                    for iUnit, oUnit in tUnitsInRect do
                        table.insert(tsUnitRefs, iUnit, oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit))
                    end
                end
                LOG('tsUnitRefs='..repru(tsUnitRefs))
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tTargetLocation
end

function GetPartCompleteBuilding(aiBrain, oBuilder, iCategoryToBuild, iBuildingSearchRange, iEnemySearchRange)
    --Returns nil if no nearby part complete building
    --iEnemySearchRange: nil if dont care about nearby enemies, otherwise will ignore buildings that have enemies within iEnemySearchRange
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetPartCompleteBuilding'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tBuilderPosition = oBuilder:GetPosition()
    local tAllBuildings = aiBrain:GetUnitsAroundPoint(iCategoryToBuild, tBuilderPosition, iBuildingSearchRange, 'Ally')
    local iCurDistanceToBuilder
    local iMinDistanceToBuilder = 10000
    local tBuildingPosition
    local oNearestPartCompleteBuilding
    if M27Utilities.IsTableEmpty(tAllBuildings) == false then
        for iBuilding, oBuilding in tAllBuildings do
            if oBuilding.GetFractionComplete and oBuilding.GetPosition and oBuilding:GetFractionComplete() < 1 then
                local tNearbyEnemies
                local tBuildingPosition = oBuilding:GetPosition()
                if iEnemySearchRange then tNearbyEnemies = aiBrain:GetUnitsAroundPoint(categories.ALLUNITS, tBuildingPosition, iEnemySearchRange, 'Enemy') end
                if M27Utilities.IsTableEmpty(tNearbyEnemies) == true then
                    iCurDistanceToBuilder = M27Utilities.GetDistanceBetweenPositions(tBuildingPosition, tBuilderPosition)
                    if iCurDistanceToBuilder < iMinDistanceToBuilder then
                        iMinDistanceToBuilder = iCurDistanceToBuilder
                        oNearestPartCompleteBuilding = oBuilding
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oNearestPartCompleteBuilding
end

function ConvertExperimentalRefToCategory(iExperimentalRef)
    local iCategory
    if iExperimentalRef == refiExperimentalLand then
        iCategory = M27UnitInfo.refCategoryLandExperimental
    elseif iExperimentalRef == refiExperimentalAir then
        iCategory = M27UnitInfo.refCategoryAirNonScout * categories.EXPERIMENTAL
    elseif iExperimentalRef == refiExperimentalNuke then
        iCategory = M27UnitInfo.refCategorySML * categories.TECH3
    elseif iExperimentalRef == refiExperimentalT3Arti then
        iCategory = M27UnitInfo.refCategoryFixedT3Arti
    elseif iExperimentalRef == refiExperimentalNovax then
        iCategory = M27UnitInfo.refCategoryNovaxCentre
    elseif iExperimentalRef == refiAllExperimentals then
        iCategory = M27UnitInfo.refCategoryExperimentalLevel
    else
        M27Utilities.ErrorHandler('No recognised experimental category for iExperimentalRef='..(iExperimentalRef or 'nil')..'; will return land experimental')
        iCategory = M27UnitInfo.refCategoryLandExperimental
    end
        return iCategory
end

function DecideOnExperimentalToBuild(iActionToAssign, aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'DecideOnExperimentalToBuild'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iCategoryRef
    local iCategoryToBuild
    local iFactionIndex = aiBrain:GetFactionIndex()
    --Have we already started construction on an experimental?
    --reftEngineerAssignmentsByActionRef --Records all engineers. [x][y]{1,2} - x is the action ref; y is the engineer unique ref, 1 is the location ref, 2 is the engineer object (use the subtable ref keys instead of numbers to refer to these)
    if bDebugMessages == true then LOG(sFunctionRef..': iActionToAssign='..iActionToAssign..'; Is the table of engi actions for this empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign]))..'; aiBrain[refiLastExperimentalReference]='..(aiBrain[refiLastExperimentalReference] or 'nil')..'; aiBrain[refiLastSecondExperimentalRef]='..(aiBrain[refiLastSecondExperimentalRef] or 'nil')) end

--CHECK IF ALREADY BUILDING EXPERIMENTAL OR ALLY IS
    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign]) == false then
        if bDebugMessages == true then LOG(sFunctionRef..': Already have an experimental category from before, will use this. Category='..(aiBrain[refiLastExperimentalReference] or 'nil')..'; aiBrain[refiLastSecondExperimentalRef]='..(aiBrain[refiLastSecondExperimentalRef] or 'nil')) end
        if not(iActionToAssign == refActionBuildSecondExperimental) then iCategoryRef = aiBrain[refiLastExperimentalReference]
        else iCategoryRef = aiBrain[refiLastSecondExperimentalRef]
        end

    else
        --Do we have nearby experimental type units being built by us or an ally? If so pick this category (in the hope we will then assist construction of the existing unit) unless we are trying to buidl a second experimental
        if not(iActionToAssign == refActionBuildSecondExperimental) then
            local iBasePathingGroup = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
            local tNearbyExperimentals = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryExperimentalLevel, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 150, 'Ally')
            local tNearbyExperimentalSubset
            if M27Utilities.IsTableEmpty(tNearbyExperimentals) == false then

                if aiBrain[refiLastExperimentalReference] then tNearbyExperimentalSubset = EntityCategoryFilterDown(ConvertExperimentalRefToCategory(aiBrain[refiLastExperimentalReference]), tNearbyExperimentals) end
                if M27Utilities.IsTableEmpty(tNearbyExperimentalSubset) == false then
                    for iUnit, oUnit in tNearbyExperimentalSubset do
                        if oUnit:GetFractionComplete() >= 0.03 and oUnit:GetFractionComplete() < 1 then
                            --Can we path here?
                            if iBasePathingGroup == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition()) then
                                iCategoryRef = aiBrain[refiLastExperimentalReference]
                                break
                            end
                        end
                    end
                else
                    --Dont know the category so will cycle through main categories and if still cant figure it out will choose every category
                    for iCatRef, iCategory in {refiExperimentalLand, refiExperimentalAir, refiExperimentalNuke, refiExperimentalT3Arti, refiExperimentalNovax, refiAllExperimentals} do
                        tNearbyExperimentalSubset = EntityCategoryFilterDown(ConvertExperimentalRefToCategory(iCategory), tNearbyExperimentals)
                        if M27Utilities.IsTableEmpty(tNearbyExperimentalSubset) == false then
                            for iUnit, oUnit in tNearbyExperimentalSubset do
                                if oUnit:GetFractionComplete() >= 0.03 and oUnit:GetFractionComplete() < 1 then
                                    iCategoryRef = iCategory
                                    break
                                end
                            end
                            if iCategoryRef then break end
                        end
                    end
                end
            end
            if iCategoryRef then
                aiBrain[refiLastExperimentalReference] = iCategoryRef
            end
        end
    end

    --Backup incase nothing noted, and/or if we havent previously assigned
    if not(iCategoryRef) then
        --Can we path to enemy base with amphibious unit, and is there a land unit withi n40% of our base? then build land experimental
        local tEnemyPDThreat = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2PlusPD, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], math.min(1000, aiBrain[M27AirOverseer.refiMaxScoutRadius]), 'Enemy')
        local iEnemyPDThreat = 0
        local tEnemyT2Arti = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], math.min(1000, aiBrain[M27AirOverseer.refiMaxScoutRadius]), 'Enemy')
        local iEnemyT2ArtiCount = 0
        if M27Utilities.IsTableEmpty(tEnemyT2Arti) == false then iEnemyT2ArtiCount = table.getn(tEnemyT2Arti) end
        if M27Utilities.IsTableEmpty(tEnemyPDThreat) == false then
            iEnemyPDThreat = M27Logic.GetCombatThreatRating(aiBrain, tEnemyPDThreat, true, nil, nil, false, false)
        end
        local iExistingLandExperimentals = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryLandExperimental)
        if iActionToAssign == refActionBuildSecondExperimental and aiBrain[refiLastExperimentalReference] == refiExperimentalLand then iExistingLandExperimentals = iExistingLandExperimentals + 1 end


        --is the enemy turtling? If so then ignore normal logic to build land experimental and go straight to Nuke, T3 arti or air experimental
        local bEnemyIsTurtling = false
        local iTotalActivePlayers = 1
        local iTotalEnemyPlayers = 0

        local bTargetsForT3Arti = true
        if aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] > 750 and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2Mex + M27UnitInfo.refCategoryT3Mex + M27UnitInfo.refCategoryExperimentalStructure + M27UnitInfo.refCategoryFixedT3Arti + M27UnitInfo.refCategorySML, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 750, 'Enemy')) then
            bTargetsForT3Arti = false
        end

        for iBrain, oBrain in aiBrain[M27Overseer.toAllyBrains] do
            iTotalActivePlayers = iTotalActivePlayers + 1
        end
        for iBrain, oBrain in aiBrain[M27Overseer.toEnemyBrains] do
            iTotalEnemyPlayers = iTotalEnemyPlayers + 1
        end
        iTotalActivePlayers = iTotalActivePlayers + iTotalEnemyPlayers
        --Is enemy's nearest unit more than 50% of dist to enemy base away, and we control at least half of mexes in our starting pathing group?
        if aiBrain[M27Overseer.refiModDistFromStartNearestThreat] / aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] > 0.5 and (aiBrain[M27Overseer.refiAllMexesInBasePathingGroup] - aiBrain[M27Overseer.refiUnclaimedMexesInBasePathingGroup]) >= aiBrain[M27Overseer.refiAllMexesInBasePathingGroup] / iTotalActivePlayers then
            --Is the nearest enemy land experimental at least 70% away?
            local bEnemyLandExperimentalFarAway = true
            if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyLandExperimentals]) == false then
                local iCurModDist
                local iMinDistWanted = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.7
                for iUnit, oUnit in aiBrain[M27Overseer.reftEnemyLandExperimentals] do
                    iCurModDist = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false)
                    if iCurModDist <= iMinDistWanted then
                        bEnemyLandExperimentalFarAway = false
                        break
                    end
                end
            end
            if bEnemyLandExperimentalFarAway then
                --Does the enemy have significant PD based threat?
                if iTotalActivePlayers <= 2 and iEnemyPDThreat + iEnemyT2ArtiCount * 2000 >= 4000 + iTotalEnemyPlayers * 4000 then
                    bEnemyIsTurtling = true
                else

                end
            end
        end

        --MAIN LOGIC FOR DECIDING EXPERIMENTAL



        --Dont worry about building land experimental if enemy is turtling
        local bNearbyLandPathableThreat = false
        if aiBrain[M27Overseer.refiModDistFromStartNearestThreat] / aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 0.4 and ((aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= 175 and aiBrain[M27Overseer.refiModDistFromStartNearestThreat] / aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 0.35) or M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, aiBrain[M27Overseer.reftLocationFromStartNearestThreat])) then
            bNearbyLandPathableThreat = true
        end
        local iT3ArtiWeOwn = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryFixedT3Arti)
        local iLifetimeLandExperimentalCount = M27Conditions.GetLifetimeBuildCount(aiBrain, ConvertExperimentalRefToCategory(refiExperimentalLand))
        if bDebugMessages == true then LOG(sFunctionRef..': Deciding if want land experimental due to nearby enemy threat; iT3ArtiWeOwn='..iT3ArtiWeOwn..'; iLifetimeLandExperimentalCount='..iLifetimeLandExperimentalCount..'; aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]='..tostring(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious])..'; aiBrain[M27Overseer.refiModDistFromStartNearestThreat]='..aiBrain[M27Overseer.refiModDistFromStartNearestThreat]..'; Enemy PD threat='..iEnemyPDThreat..'; iExistingLandExperimentals='..iExistingLandExperimentals..'; iEnemyT2ArtiCount='..iEnemyT2ArtiCount) end

        --Top priority for UEF - build novax if enemy has navy and we dont have novax and have lifetime build count of at least 1 on land experimental
        if iFactionIndex == M27UnitInfo.refFactionUEF and iLifetimeLandExperimentalCount > 0 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryNovaxCentre) == 0 and (iActionToAssign == refActionBuildExperimental or not(aiBrain[refiLastExperimentalReference] == refiExperimentalNovax)) then
            local tEnemyNavy = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryNavalFactory + M27UnitInfo.refCategoryNavalSurface, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], math.max(500, aiBrain[M27AirOverseer.refiMaxScoutRadius]), 'Enemy')
            if M27Utilities.IsTableEmpty(tEnemyNavy) == false and (table.getn(tEnemyNavy) >= 4 or M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL, tEnemyNavy)) == false) then
                iCategoryRef = refiExperimentalNovax
            end
        end

        local bTeamHasChokepoint = false
        if not(M27Utilities.IsTableEmpty(M27Overseer.tTeamData[aiBrain.M27Team][M27MapInfo.tiPlannedChokepointsByDistFromStart])) then
            for iBrain, oBrain in M27Overseer.tTeamData[aiBrain.M27Team][M27Overseer.reftFriendlyActiveM27Brains] do
                if oBrain[M27Overseer.refiDefaultStrategy] == M27Overseer.refStrategyTurtle then
                    bTeamHasChokepoint = true
                    break
                end
            end
        end
        if not(iCategoryRef) and not(bEnemyIsTurtling) and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] and aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 850 and (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] or aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 500) then
            --If have a chokepoint on the map then dont build land experimental if have as many as the enemy
            if bTeamHasChokepoint then

                local iEnemyLandExperimentals = 0
                if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyLandExperimentals]) == false then iEnemyLandExperimentals = table.getsize(aiBrain[M27Overseer.reftEnemyLandExperimentals]) end
                if bDebugMessages == true then LOG(sFunctionRef..': bTeamHasChokepoint='..tostring(bTeamHasChokepoint)..'; iEnemyLandExperimentals='..iEnemyLandExperimentals..'; iExistingLandExperimentals='..iExistingLandExperimentals) end
                if iEnemyLandExperimentals > iExistingLandExperimentals and (not(iActionToAssign == refActionBuildSecondExperimental) or iEnemyLandExperimentals - 1 > iExistingLandExperimentals) then
                    iCategoryRef = refiExperimentalLand
                end
            else
                if iExistingLandExperimentals <= 1 and iLifetimeLandExperimentalCount < 3 and ((iEnemyPDThreat <= 12500 + 5000 * iTotalEnemyPlayers and not(iFactionIndex == M27UnitInfo.refFactionUEF)) or (iFactionIndex == M27UnitInfo.refFactionUEF and iEnemyT2ArtiCount <= math.min(8, (iExistingLandExperimentals + 1) * 2)) and bNearbyLandPathableThreat) then
                    iCategoryRef = refiExperimentalLand
                    if bDebugMessages == true then LOG(sFunctionRef..': WIll build land experimental') end
                elseif iExistingLandExperimentals == 0 and iLifetimeLandExperimentalCount < 1 and ((iEnemyPDThreat <= 17500 + 5000 * iTotalEnemyPlayers and not(iFactionIndex == M27UnitInfo.refFactionUEF)) or (iFactionIndex == M27UnitInfo.refFactionUEF and iEnemyT2ArtiCount <= math.min(8, (iExistingLandExperimentals + 1) * 2))) and aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 500 then
                    iCategoryRef = refiExperimentalLand
                    if bDebugMessages == true then LOG(sFunctionRef..': WIll build land experimental as havent built any before and are relatively close to enemy base') end
                    --Do we have a T3 arti and no active land experimental, but can path to enemy base amphibiously? Then build a land experimental
                elseif iExistingLandExperimentals == 0 and iLifetimeLandExperimentalCount < (iT3ArtiWeOwn+1) * 2 and iT3ArtiWeOwn > 0 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirNonScout * categories.EXPERIMENTAL) == 0 and (bNearbyLandPathableThreat or aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= math.max(200, math.min(350, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.6))) then
                    if bDebugMessages == true then LOG(sFunctionRef..': We have a t3 arti and no land experimentals or air experimentals so will build a land experimental') end
                    iCategoryRef = refiExperimentalLand
                end
            end
        end
        if not(iCategoryRef) then
            --Worth building nuke? Check we and any ally dont already own a nuke (unless cant path to enemy base in which case ignore ally check), we have a decent amount of energy (at least 3 T3 PGens) and check nearest enemy has no SMD around our base or theirs, and that we have scouted their base in the last 90s
            if bDebugMessages == true then LOG(sFunctionRef..': Considering if want to build a nuke; checking gross energy and if we already have a nuke; current SML per getcurrentunits='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategorySML)..'; Gross energy='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; ') end
            local tFriendlyNukes = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategorySML, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 10000, 'Ally')
            local iFriendlyNukes = 0
            if M27Utilities.IsTableEmpty(tFriendlyNukes) == false then iFriendlyNukes = table.getn(tFriendlyNukes) end
            if iActionToAssign == refActionBuildSecondExperimental then

                if aiBrain[refiLastExperimentalReference] == refiExperimentalNuke then
                    iFriendlyNukes = iFriendlyNukes + 1
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Building second experimental, will check if the last experimental category was a nuke. iFriendlyNukes='..iFriendlyNukes) end
            end
            if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 600 and (iFriendlyNukes == 0 or not(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]) and aiBrain:GetCurrentUnits(M27UnitInfo.refCategorySML) == 0) then
                local iEnemyBaseSegmentX, iEnemyBaseSegmentZ = M27AirOverseer.GetAirSegmentFromPosition(M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                if bDebugMessages == true then LOG(sFunctionRef..': Considering if want to build a nuke; Time since last had sight of enemy start='..aiBrain[M27AirOverseer.reftAirSegmentTracker][iEnemyBaseSegmentX][iEnemyBaseSegmentZ][M27AirOverseer.refiLastScouted]..'; Cur gametime='..GetGameTimeSeconds()) end
                if GetGameTimeSeconds() - (aiBrain[M27AirOverseer.reftAirSegmentTracker][iEnemyBaseSegmentX][iEnemyBaseSegmentZ][M27AirOverseer.refiLastScouted] or 0) <= 100 then
                    --Anti-nuke has range of 90; SML has aoe of 30
                    local tEnemySMD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategorySMD, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] + 60, 'Enemy')
                    if bDebugMessages == true then LOG(sFunctionRef..': Have recent sight of enemy base; Is tEnemySMD empty='..tostring(M27Utilities.IsTableEmpty(tEnemySMD))) end
                    if M27Utilities.IsTableEmpty(tEnemySMD) then
                        iCategoryRef = refiExperimentalNuke
                        if bDebugMessages == true then LOG(sFunctionRef..': Will try and build a nuke. iActionToAssign='..iActionToAssign) end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Will consider if are enough viable targets just based on enemy team start points that are out of range of any smd under construction') end
                        local iValuableTargets = 0
                        --Assume what the values will be for damage and aoe
                        local iAOE = 30
                        local iDamage = 70000
                        --Increase SMD range by 5 to be prudent, as there's a chance we end up building the nuke somewhere that means the SMD can block it
                        --GetBestAOETarget(aiBrain, tBaseLocation, iAOE, iDamage, bOptionalCheckForSMD, tSMLLocationForSMDCheck, iOptionalTimeSMDNeedsToHaveBeenBuiltFor, iSMDRangeAdjust)
                        --Below will allow SMD a range of 92 (by doing +1 range mod) - normally would search based on range of 91
                        local tSMLTarget, iSMLDamage = M27Logic.GetBestAOETarget(aiBrain, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), iAOE, iDamage, true, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 0, 1)
                        if bDebugMessages == true then LOG(sFunctionRef..': If target primary enemy base we expect to deal damage of '..iSMLDamage) end
                        if iSMLDamage >= 27000 then iValuableTargets = iValuableTargets + 1 end

                        for iStartPoint = 1, table.getn(M27MapInfo.PlayerStartPoints) do
                            if not(iStartPoint == aiBrain.M27StartPositionNumber) and M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[iStartPoint], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) >= 30 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Considering the start position '..iStartPoint..'='..repru(M27MapInfo.PlayerStartPoints[iStartPoint])) end
                                tSMLTarget, iSMLDamage = M27Logic.GetBestAOETarget(aiBrain, M27MapInfo.PlayerStartPoints[iStartPoint], iAOE, iDamage, true, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 0, 1)
                                if iSMLDamage >= 27000 then iValuableTargets = iValuableTargets + 1 end
                            end
                        end
                        --Reduce by ally SML in case we are ignoring them
                        if bDebugMessages == true then LOG(sFunctionRef..': iValuableTargets='..iValuableTargets..'; iFriendlyNukes='..iFriendlyNukes) end
                        if iValuableTargets - iFriendlyNukes > 0 then
                            iCategoryRef = refiExperimentalNuke
                        end
                    end
                end
            end
        end
        if not(iCategoryRef) then
            --Faction specific logic - check that our brain faction aligns with our highest engineer
            local tT3Engis = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryEngineer * categories.TECH3, false, true)

            if tT3Engis and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27Utilities.FactionIndexToCategory(iFactionIndex), tT3Engis)) then
                --Have T3 engis but theyre not of the same tech level as our ACU
                for iUnit, oUnit in tT3Engis do
                    if M27UnitInfo.IsUnitValid(oUnit) then
                        iFactionIndex = M27UnitInfo.GetUnitFaction(oUnit)
                        break
                    end
                end
            end

            if iFactionIndex == M27UnitInfo.refFactionUEF then
                if bDebugMessages == true then LOG(sFunctionRef..': Dealing with UEF, consider if want to build novax') end
                --Do we want to build a novax? Only consider if enemy base relatively far away or it cant be pathed to amphibiously
                if aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] >= 500 or aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] == false or (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == false and aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] >= 350) then
                    --Does the enemy have enough targets for a novax? Factor in any novaxes our team has that aren't massively far away
                    local iExistingNovax = table.getn(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryNovaxCentre, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 1500, 'Ally'))
                    local iNovaxTargetValue = 0 --want at least 10k worth of good targets per novax
                    local iValueWanted = 20000 * iExistingNovax + 10000

                    --If enemy has T3 navy then want at least 1 novax
                    if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryNavalFactory * categories.TECH3, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), 1500, 'Enemy')) == false then iNovaxTargetValue = iNovaxTargetValue + 10000 end

                    if iNovaxTargetValue < iValueWanted then
                        --Include mass value of any enemy cruisers and carriers
                        iNovaxTargetValue = iNovaxTargetValue + M27Logic.GetAirThreatLevel(aiBrain, aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryCruiserCarrier, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 1500, 'Enemy'), true, false, true, false, false, nil, nil, 2000, nil, false)
                        if iNovaxTargetValue < iValueWanted then
                            --Include value of enemy unshielded mexes that arent near to the enemy base.  Base value on 200s of income
                            local tMexValueByTech = {400, 1800, 3600, 5000}
                            local tEnemyMexes = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryMex, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 1500, 'Enemy')
                            if M27Utilities.IsTableEmpty(tEnemyMexes) == false then
                                for iMex, oMex in tEnemyMexes do
                                    if M27Utilities.GetDistanceBetweenPositions(oMex:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) >= 90 then
                                        if not(M27Logic.IsTargetUnderShield(aiBrain, oMex, 0, nil, false, true)) then
                                            iNovaxTargetValue = iNovaxTargetValue + tMexValueByTech[M27UnitInfo.GetUnitTechLevel(oMex)]
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': iNovaxTargetValue='..iNovaxTargetValue..'; iExistingNovax='..iExistingNovax) end

                    if iNovaxTargetValue >= iValueWanted then
                        iCategoryRef = refiExperimentalNovax
                        if bDebugMessages == true then LOG(sFunctionRef..': Will build a novax') end
                    end
                end
                if not(iCategoryRef) then
                    --Do we want a fatboy?
                    if bDebugMessages == true then LOG(sFunctionRef..': Deciding if we want a fatboy or a T3 arti; aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand]='..tostring(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand])..'; aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]..'; iExistingLandExperimentals='..iExistingLandExperimentals..'; Enemy T2 arti='..table.getn(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 725, 'Enemy'))..'; M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryLandExperimental, 3)='..tostring(M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryLandExperimental, 3))) end
                    if iExistingLandExperimentals <= 2 and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] and aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 600 and iExistingLandExperimentals <= 1 and (iEnemyT2ArtiCount <= (iExistingLandExperimentals + 1) * 2 or table.getn(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 725, 'Enemy')) <= (iExistingLandExperimentals + 1) * 2) and (M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryLandExperimental, 3) or not(M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryFixedT3Arti, 1))) then
                        iCategoryRef = refiExperimentalLand
                    else
                        --T3 arti if we have the eco to support it
                        if bDebugMessages == true then LOG(sFunctionRef..': Will build T3 arti if we have the eco to support it; aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]='..aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]..'; T3 mexes='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex)..'; Mexes near start='..table.getn(M27MapInfo.tResourceNearStart[M27Utilities.GetAIBrainArmyNumber(aiBrain)][1])) end
                        if bTargetsForT3Arti and ((not(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]) and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 10) or (aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 15 and (aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] >= 325 or not(M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryLandExperimental, 4))))) and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex) >= math.max(1, table.getn(M27MapInfo.tResourceNearStart[M27Utilities.GetAIBrainArmyNumber(aiBrain)][1])) then
                            iCategoryRef = refiExperimentalT3Arti
                        end
                    end
                end
            else --Non-UEF faction so have experimental air available
                --First consider if want experimental land
                --Note - construction logic will automatically seek the cheapest land experimental if we havent built any before, so no need to code specific logic to pick monkeylord over megalith

                local bNearbyLandExperimental = false
                if iEnemyPDThreat <= 20000 and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyLandExperimentals]) == false then
                    local iNearbyDist = aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.55
                    for iUnit, oUnit in aiBrain[M27Overseer.reftEnemyLandExperimentals] do
                        if M27UnitInfo.IsUnitValid(oUnit) then
                            if M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, oUnit:GetPosition(), false) <= iNearbyDist then
                                bNearbyLandExperimental = true
                                break
                            end
                        end
                    end
                end
                if bDebugMessages == true then LOG(sFunctionRef..': bNearbyLandExperimental='..tostring(bNearbyLandExperimental)..'; aiBrain[M27AirOverseer.refiOurMassInAirAA]='..aiBrain[M27AirOverseer.refiOurMassInAirAA]..'; aiBrain[M27AirOverseer.refiHighestEnemyAirThreat]='..aiBrain[M27AirOverseer.refiHighestEnemyAirThreat]..'; aiBrain[M27AirOverseer.refiAirAANeeded]='..aiBrain[M27AirOverseer.refiAirAANeeded]..'; aiBrain[M27AirOverseer.refiEnemyMassInGroundAA]='..aiBrain[M27AirOverseer.refiEnemyMassInGroundAA]..'; aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirNonScout * categories.EXPERIMENTAL)='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirNonScout * categories.EXPERIMENTAL)) end

                --Do we want to build an experimental air unit?
                if iFactionIndex == M27UnitInfo.refFactionAeon or iFactionIndex == M27UnitInfo.refFactionCybran or iFactionIndex == M27UnitInfo.refFactionSeraphim then
                    local iAirRatioWanted = 0.8
                    if iFactionIndex == M27UnitInfo.refFactionAeon then iAirRatioWanted = 0.7 end
                    local iMaxT3AA = 5
                    local iVulnerableMexesWanted = 3 --For aeon - Czar more versatile for maintaining air control and attritional battles
                    --Soulripper has stealth so easier to target vulnerable mexes; Bomber able to fire from a distance so can also be effective
                    if iFactionIndex == M27UnitInfo.refFactionCybran then
                        iMaxT3AA = 8
                        iVulnerableMexesWanted = 6
                    elseif iFactionIndex == M27UnitInfo.refFactionSeraphim then
                        iMaxT3AA = 6
                        iVulnerableMexesWanted = 5
                    end
                    local bEnemyHasLowAA = false
                    if aiBrain[M27AirOverseer.refiEnemyMassInGroundAA] <= 10000 then bEnemyHasLowAA = true
                    else
                        local tEnemyT3AA = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryGroundAA * categories.TECH3, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27AirOverseer.refiMaxScoutRadius], 'Enemy')
                        if M27Utilities.IsTableEmpty(tEnemyT3AA) or table.getn(tEnemyT3AA) <= iMaxT3AA then bEnemyHasLowAA = true end
                        if bDebugMessages == true then
                            if M27Utilities.IsTableEmpty(tEnemyT3AA) then LOG(sFunctionRef..': Enemy has no T3 AA')
                            else
                                LOG(sFunctionRef..': Enemy has '..table.getn(tEnemyT3AA)..' T3 AA; iMaxT3AA='..iMaxT3AA)
                            end
                        end
                    end


                    if bDebugMessages == true then LOG(sFunctionRef..': Considering if enemy has low AA; bEnemyHasLowAA='..tostring(bEnemyHasLowAA)..'; aiBrain[M27AirOverseer.refiEnemyMassInGroundAA]='..aiBrain[M27AirOverseer.refiEnemyMassInGroundAA]..'; refiOurMassInAirAA wanted='..aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] * iAirRatioWanted..'; aiBrain[M27AirOverseer.refiAirAANeeded]='..aiBrain[M27AirOverseer.refiAirAANeeded]) end
                    if bEnemyHasLowAA and (aiBrain[M27AirOverseer.reftEnemyAirFactoryByTech][3] == 0 or (aiBrain[M27AirOverseer.refiOurMassInAirAA] >= aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] * iAirRatioWanted or aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] <= 5000) and aiBrain[M27AirOverseer.refiAirAANeeded] <= 4) then
                        --Does the enemy have a land experimental within 55% of our base and we dont ahve any experimental air? Then go for air unit
                        if bDebugMessages == true then LOG(sFunctionRef..': We have air control or are close to it, so will build experimental air unless we already own one') end
                        if bNearbyLandExperimental and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirNonScout * categories.EXPERIMENTAL) <= 0 then
                            iCategoryRef = refiExperimentalAir
                            if bDebugMessages == true then LOG(sFunctionRef..' Will build experimental air') end
                        else
                            --If enemy has really low AA then build air experimental, otherwise calculate how many vulnerable enemy mex targets there are - any T2+ mexes with no T3 AA and not under a heavy shield
                            if aiBrain[M27AirOverseer.refiEnemyMassInGroundAA] <= 5000 and aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] <= math.max(2500, aiBrain[M27AirOverseer.refiOurMassInAirAA] * 0.9) and aiBrain[M27AirOverseer.refiAirAANeeded] <= 0 then
                                --iCategoryRef = M27UnitInfo.refCategoryAirNonScout * categories.EXPERIMENTAL
                                iCategoryRef = refiExperimentalAir
                                if bDebugMessages == true then
                                    LOG(sFunctionRef..': Enemy has minimal AA so will build air experimental')
                                    if iCategoryRef == refiExperimentalAir then
                                        LOG('Category to build is air experimental') --Note - for some reason this test doesnt work; however the repr confirms it's still looking at air experimentals - may work now that have switched from using categories to using references thgat are converted to categories later
                                    else
                                        LOG(repru(EntityCategoryGetUnitList(ConvertExperimentalRefToCategory(iCategoryRef))))
                                    end
                                end

                            else

                                local tVulnerableMexes = M27AirOverseer.GetVulnerableMexes(aiBrain, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 14000)
                                local iMexesWanted = iVulnerableMexesWanted + aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirNonScout * categories.EXPERIMENTAL) * iVulnerableMexesWanted * 0.5
                                if bDebugMessages == true then LOG(sFunctionRef..': Will see if we have enough vulnerable mexes; iVulnerableMexes='..table.getn(tVulnerableMexes)..'; iMexesWanted='..iMexesWanted) end
                                if table.getn(tVulnerableMexes) >= iMexesWanted then
                                    iCategoryRef = refiExperimentalAir
                                    if bDebugMessages == true then LOG(sFunctionRef..' Will build experimental air') end
                                end
                            end
                        end
                    end
                    if not(iCategoryRef) then
                        --Either enemy land experimental on our side of map and we lack sufficient air to deal with it, or the nearest threat is within 45% of start and is pathable amphibiously
                        if iExistingLandExperimentals <= 2 and iEnemyPDThreat <= 20000 and ((bNearbyLandExperimental or (aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.45 and M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, aiBrain[M27Overseer.reftLocationFromStartNearestThreat]))) and (iLifetimeLandExperimentalCount < 3 or not(aiBrain[M27AirOverseer.refiPreviousAvailableBombers] >= 100 or (aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryBomber * categories.TECH3) >= 6 and aiBrain[M27AirOverseer.refiOurMassInAirAA] >= aiBrain[M27AirOverseer.refiAirAAWanted]*0.65)))) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Will build land experimental as nearby experimental or we can path to nearest <=45% threat') end
                            iCategoryRef = refiExperimentalLand
                        end
                        if not(iCategoryRef) and aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] <= 750 then
                            iCategoryRef = refiExperimentalT3Arti
                        end
                    end
                else

                    --Other faction logic - T3 arti
                    local iCurrentT3Arti = iT3ArtiWeOwn
                    if bTargetsForT3Arti and not(M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryLandExperimental, 3 + iCurrentT3Arti)) and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 12 then
                        iCategoryRef = refiExperimentalT3Arti
                    end
                end
            end

            if not(iCategoryRef) then
                --Backup - if still nothing to build, then build a land experimental if we can path to the enemy base by amphibious, or a t3 arti if we cant
                if iExistingLandExperimentals <= 3 and (iExistingLandExperimentals < 1 or M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryLandExperimental, 3 + iT3ArtiWeOwn)) and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] and ((iFactionIndex == M27UnitInfo.refFactionUEF and iEnemyT2ArtiCount <= (iExistingLandExperimentals + 1) * 3)  or (not(iFactionIndex == M27UnitInfo.refFactionUEF) and iEnemyPDThreat <= 22000)) then
                    iCategoryRef = refiExperimentalLand
                elseif bTargetsForT3Arti then
                    iCategoryRef = refiExperimentalT3Arti
                else
                    if iFactionIndex == M27UnitInfo.refFactionUEF then
                        iCategoryRef = refiExperimentalNovax
                    else
                        iCategoryRef = refiExperimentalAir
                    end
                end

                if bDebugMessages == true then LOG(sFunctionRef..': Backup logic for what to build activated. iCategoryRef='..iCategoryRef) end
            end
        end
    end

    --Are there unit restrictions? If so then make sure we can build the category
    if M27Utilities.IsTableEmpty(ScenarioInfo.Options.RestrictedCategories) then
        local tT3EngisOfOurFaction = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryEngineer * categories.TECH3 * M27Utilities.FactionIndexToCategory(iFactionIndex), false, true)
        if M27Utilities.IsTableEmpty(tT3EngisOfOurFaction) == false then
            local oT3EngiOfOurFaction = tT3EngisOfOurFaction[1]
            if not(M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, ConvertExperimentalRefToCategory(iCategoryRef), oT3EngiOfOurFaction)) then
                --Cant build the desired experimental, try every experimental type category
                if bDebugMessages == true then LOG(sFunctionRef..': Cant build desired experimental, will try every experimental type') end
                iCategoryRef = refiAllExperimentals
            end
        end
    end

    if iActionToAssign == refActionBuildExperimental then aiBrain[refiLastExperimentalReference] = iCategoryRef
    elseif iActionToAssign == refActionBuildSecondExperimental then aiBrain[refiLastSecondExperimentalRef] = iCategoryRef
    else
        M27Utilities.ErrorHandler(sFunctionRef..': iActionToAssign='..(iActionToAssign or 'nil')..'; unrecognised action')
        if iCategoryRef then aiBrain[refiLastExperimentalReference] = iCategoryRef end
    end

    if bDebugMessages == true then
        LOG(sFunctionRef..': End of code; will note the type of experimental we will try and build; Action='..iActionToAssign..'; iCategoryRef='..(iCategoryRef or 'nil'))
    end
    if iCategoryRef then return ConvertExperimentalRefToCategory(iCategoryRef) else return nil end
end

function GetCategoryToBuildFromAction(iActionToAssign, iMinTechLevel, aiBrain)
    --Returns the building category type based on the action; iMinTechLevel is optional; aiBrain is required if dealing with construction of experimental
    local iCategoryToBuild
    if iActionToAssign == refActionBuildMex or iActionToAssign == refActionBuildPlateauMex then
        iCategoryToBuild = refCategoryT1Mex --Note: Will override this separately in some cases
    elseif iActionToAssign == refActionBuildT3MexOverT2 then
        iCategoryToBuild = M27UnitInfo.refCategoryT3Mex
    elseif iActionToAssign == refActionBuildMassStorage then
        iCategoryToBuild = M27UnitInfo.refCategoryMassStorage
    elseif iActionToAssign == refActionBuildHydro then
        iCategoryToBuild = refCategoryHydro
    elseif iActionToAssign == refActionBuildPower or iActionToAssign == refActionBuildSecondPower or iActionToAssign == refActionBuildThirdPower then
        iCategoryToBuild = refCategoryPower
    elseif iActionToAssign == refActionBuildT3ArtiPower then
        iCategoryToBuild = refCategoryPower --Placeholder - will want to override due to defining this against the unit itself
    elseif iActionToAssign == refActionBuildLandFactory or iActionToAssign == refActionBuildSecondLandFactory then
        iCategoryToBuild = refCategoryLandFactory
    elseif iActionToAssign == refActionBuildPlateauFactory then
        iCategoryToBuild = refCategoryLandFactory - categories.TECH3
    elseif iActionToAssign == refActionBuildAirFactory or iActionToAssign == refActionBuildSecondAirFactory then
        iCategoryToBuild = refCategoryAirFactory
    elseif iActionToAssign == refActionBuildEnergyStorage then
        iCategoryToBuild = refCategoryEnergyStorage
    elseif iActionToAssign == refActionBuildAA then
        iCategoryToBuild = M27UnitInfo.refCategoryStructureAA
    elseif iActionToAssign == refActionBuildEmergencyPD then
        if aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 4 or aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPD * categories.TECH1) > 0 then
            --Want to build either T2 or T2+ PD
            local iT2PD = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPD * categories.TECH2)
            if iT2PD <= 5 or aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPD * categories.TECH3) >= iT2PD then
                iCategoryToBuild = M27UnitInfo.refCategoryPD - categories.TECH3
            else
                iCategoryToBuild = M27UnitInfo.refCategoryT2PlusPD
            end
        else
            iCategoryToBuild = M27UnitInfo.refCategoryPD * categories.TECH1
        end
    elseif iActionToAssign == refActionFortifyFirebase then
        --Calculate closest firebase and assume we are trying to build this
        if aiBrain[refiFirebaseBeingFortified] then
            iCategoryToBuild = aiBrain[refiFirebaseCategoryWanted][aiBrain[refiFirebaseBeingFortified]]
            if M27Utilities.IsTableEmpty(iCategoryToBuild, false) then M27Utilities.ErrorHandler('Dont have a category to build for firebase ref '..(aiBrain[refiFirebaseBeingFortified] or 'nil')..'; will just build T2 plus PD')
                iCategoryToBuild = M27UnitInfo.refCategoryT2PlusPD
            end
        else
            M27Utilities.ErrorHandler('Dont have a firebase to be fortified so will just build T2 plus PD')
            iCategoryToBuild = M27UnitInfo.refCategoryT2PlusPD
        end

    elseif iActionToAssign == refActionBuildAirStaging then
        iCategoryToBuild = refCategoryAirStaging
    elseif iActionToAssign == refActionBuildSMD then
        iCategoryToBuild = M27UnitInfo.refCategorySMD
    elseif iActionToAssign == refActionBuildTML then
        iCategoryToBuild = M27UnitInfo.refCategoryTML
    elseif iActionToAssign == refActionBuildTMD then
        iCategoryToBuild = M27UnitInfo.refCategoryTMD
    elseif iActionToAssign == refActionBuildT1Radar then
        iCategoryToBuild = M27UnitInfo.refCategoryT1Radar
    elseif iActionToAssign == refActionBuildT2Radar then
        iCategoryToBuild = M27UnitInfo.refCategoryT2Radar
    elseif iActionToAssign == refActionBuildT3Radar then
        iCategoryToBuild = M27UnitInfo.refCategoryT3Radar
    elseif iActionToAssign == refActionAssistSMD or iActionToAssign == refActionAssistNuke then
        iCategoryToBuild = nil
    elseif iActionToAssign == refActionAssistAirFactory then
        iCategoryToBuild = nil
    elseif iActionToAssign == refActionAssistShield then
        iCategoryToBuild = nil
    elseif iActionToAssign == refActionBuildExperimental or iActionToAssign == refActionBuildSecondExperimental then
        iCategoryToBuild = DecideOnExperimentalToBuild(iActionToAssign, aiBrain)
    elseif iActionToAssign == refActionSpare or iActionToAssign == refActionHasNearbyEnemies or iActionToAssign == refActionPlateauSpareAction then
        iCategoryToBuild = nil
    elseif iActionToAssign == refActionReclaimArea or iActionToAssign == refActionReclaimUnit or iActionToAssign == refActionReclaimTrees or iActionToAssign == refActionPlateauReclaim then
        iCategoryToBuild = nil
    elseif iActionToAssign == refActionBuildT1Sonar then
        iCategoryToBuild = M27UnitInfo.refCategoryT1Sonar
    elseif iActionToAssign == refActionBuildT2Sonar then
        iCategoryToBuild = M27UnitInfo.refCategoryT2Sonar
    elseif iActionToAssign == refActionBuildShield then
        --NOTE: Separately this gets changed to tech3 if need increased range
        if not(aiBrain[M27Overseer.refbDefendAgainstArti]) then
            iCategoryToBuild = M27UnitInfo.refCategoryFixedShield * categories.TECH2
        else
            iCategoryToBuild = M27UnitInfo.refCategoryFixedShield * categories.TECH3 - categories.CYBRAN * categories.CQUEMOV
        end
    else
        M27Utilities.ErrorHandler('Need to add code for action='..iActionToAssign)
    end
    if iMinTechLevel > 1 then
    if iMinTechLevel == 3 then iCategoryToBuild = iCategoryToBuild * categories.TECH3 + iCategoryToBuild*categories.EXPERIMENTAL
    else iCategoryToBuild = iCategoryToBuild - categories.TECH1
    end
        end
        return iCategoryToBuild
end

function UpgradeBuildingActionCompleteChecker(aiBrain, oEngineer, oBuildingToUpgrade)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'UpgradeBuildingActionCompleteChecker'
    --if GetEngineerUniqueCount(oEngineer) == 58 and GetGameTimeSeconds() >= 2040 then bDebugMessages = true else bDebugMessages = false end

    local bContinue = true
    while bContinue == true do
        WaitSeconds(1)
        --Check if building has finished upgrading
        bContinue = false
        if bDebugMessages == true then
            LOG(sFunctionRef..': CHecking if buildingtoupgrade is still building')
            if not(M27UnitInfo.IsUnitValid(oBuildingToUpgrade)) then LOG('Unit is no longer valid')
            else LOG('Unit is valid; building to upgrade='..oBuildingToUpgrade.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBuildingToUpgrade)..'; Building state='..M27Logic.GetUnitState(oBuildingToUpgrade)) end
        end
        if oBuildingToUpgrade and not(oBuildingToUpgrade.Dead) and oBuildingToUpgrade.IsUnitState and (oBuildingToUpgrade:IsUnitState('Upgrading') or oBuildingToUpgrade:IsUnitState('BeingBuilt')) then bContinue = true end
    end
    --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
    if bDebugMessages == true then LOG(sFunctionRef..': About to clear engineer with ref '..GetEngineerUniqueCount(oEngineer)..' actions') end
    IssueClearCommands({oEngineer})
    ClearEngineerActionTrackers(aiBrain, oEngineer, true)

end

function ReissueEngineerOldOrders(aiBrain, oEngineer, bClearActionsFirst)
    --to use if have given engineer a temporary detour e.g. to get reclaim.  Doesnt clear action trackers
    --NOTE: Currently are using for reclaim and building mexes, likely will be flaws if use more generally that will need to work through
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReissueEngineerOldOrders'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetEngineerUniqueCount(oEngineer) == 58 and GetGameTimeSeconds() >= 2040 then bDebugMessages = true else bDebugMessages = false end

    if bClearActionsFirst then
        --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
        IssueClearCommands({oEngineer})
    end
    --reftEngineerActionsByEngineerRef Records actions by engineer reference; aiBrain[reftEngineerActionsByEngineerRef][iUniqueRef][BuildingQueue]: returns {LocRef, EngRef, AssistingRef, ActionRef, refbPrimaryBuilder, refEngineerAssignmentActualLocation} but not in that order - i.e. use subtable keys to reference these; buildingqueue will be 1 for the first queueud building by the unit, 2 for the second etc. (e.g. t1 power)
    local iUC = GetEngineerUniqueCount(oEngineer)
    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerActionsByEngineerRef][iUC]) then
        if EntityCategoryContains(categories.COMMAND, oEngineer.UnitId) then LOG(sFunctionRef..': Unable to reissue old orders as are dealing with ACU')
        else
            --Could happen if platoon former calls this and the engineer doesnt have any action to start with
            ForkThread(DelayedEngiReassignment, aiBrain, true, {oEngineer})
            --M27Utilities.ErrorHandler(sFunctionRef..': Cant find any actions for this engineer with iUC='..iUC..'; Engi='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer))
        end
    else
        local bActionToBuild
        for iQueue, tSubtable in aiBrain[reftEngineerActionsByEngineerRef][iUC] do
            if tSubtable[refoObjectTarget] then
                --Were assisting something
                if M27UnitInfo.IsUnitValid(tSubtable[refoObjectTarget]) then
                    --Was it to reclaim rather than assist?
                    if tSubtable[refiActionRef] == refActionReclaimUnit then
                        IssueReclaim(tSubtable[refoObjectTarget])
                    else
                        --Engineer? then still assist
                        if EntityCategoryContains(M27UnitInfo.refCategoryEngineer, tSubtable[refoObjectTarget].UnitId) then
                            IssueGuard({oEngineer}, tSubtable[refoObjectTarget])
                        elseif tSubtable[refoObjectTarget]:GetFractionComplete() < 1 then
                            IssueRepair({oEngineer}, tSubtable[refoObjectTarget])
                        elseif tSubtable[refoObjectTarget].GetWorkProgress and tSubtable[refoObjectTarget]:GetWorkProgress() > 0 and tSubtable[refoObjectTarget]:GetWorkProgress() < 1 then
                            IssueGuard({oEngineer}, tSubtable[refoObjectTarget])
                        else
                            --Do nothing
                        end
                    end
                end
            else
                --Was our action to build something as teh primary engineer?
                if tSubtable[refiCategoryBuilt] then
                    --Can we still build at teh target location?
                    local sBPWanted = M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, tSubtable[refiCategoryBuilt], oEngineer)
                    if CanBuildAtLocation(aiBrain, sBPWanted, tSubtable[refEngineerAssignmentActualLocation], nil, false, false) then
                        IssueBuildMobile({oEngineer}, tSubtable[refEngineerAssignmentActualLocation], sBPWanted, {})
                    else
                        --Is the same building owned by an ally within 1 of this spot that matches this category? (e.g. we may have started construction and stopped)
                        local tNearbyBuildings = aiBrain:GetUnitsAroundPoint(tSubtable[refiCategoryBuilt], tSubtable[refEngineerAssignmentActualLocation], 1, 'Ally')
                        if M27Utilities.IsTableEmpty(tNearbyBuildings) == false then
                            for iBuilding, oBuilding in tNearbyBuildings do
                                if oBuilding:GetFractionComplete() < 1 then
                                    IssueRepair({oEngineer}, oBuilding)
                                end
                            end
                        end
                    end
                else
                    --Wasn't to assist or build, assume it was just to move
                    if M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), tSubtable[refEngineerAssignmentActualLocation]) > 3 then
                        IssueMove({oEngineer}, tSubtable[refEngineerAssignmentActualLocation])
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function UpdateActionForNearbyReclaim(oEngineer, iMinReclaimIndividualValue, bDontIssueMoveAfter, bWantEnergy)
    --Gets engineer to stop and reclaim if its about to move out of range of reclaim with at least iMinReclaimIndividualValue
    --Will stop and reclaim anyway if >100 reclaim individually, or if engineer almost at its target destination
    --returns true if it triggers an issuereclaim order
    --bWantEnergy - for v30 will try removing this and deciding for ourself if we want energy
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'UpdateActionForNearbyReclaim'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetEngineerUniqueCount(oEngineer) == 1 and GetGameTimeSeconds() >= 840 and GetGameTimeSeconds() <= 1020 then bDebugMessages = true else bDebugMessages = false end
    --if GetEngineerUniqueCount(oEngineer) == 58 and GetGameTimeSeconds() >= 2040 then bDebugMessages = true else bDebugMessages = false end

    local bReclaimWillMoveOutOfRangeSoon = false
    --First check we have space to accept any reclaim - want higher of 1% storage and 50 mass
    local aiBrain = oEngineer:GetAIBrain()
    if bDebugMessages == true then LOG(sFunctionRef..': Considering for E'..GetEngineerUniqueCount(oEngineer)..' LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' with unit state='..M27Logic.GetUnitState(oEngineer)..' currently at position '..repru(oEngineer:GetPosition())..'; mass stored='..aiBrain:GetEconomyStoredRatio('MASS')) end


    --Are we about to overflow in both mass and energy? then clear commands if we are reclaiming, otherwise ignore this action
    if aiBrain:GetEconomyStoredRatio('MASS') >= 0.9 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.95 then
        if bDebugMessages == true then LOG(sFunctionRef..': Are about to overflow so wont try and reclaim; if are already reclaiming then will clear; Engineer unit state='..M27Logic.GetUnitState(oEngineer)) end
        if oEngineer:IsUnitState('Reclaiming') then
            ReissueEngineerOldOrders(aiBrain, oEngineer, true)
            --[[IssueClearCommands({oEngineer})
            if M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), oEngineer[reftEngineerCurrentTarget]) >= 3 then
                IssueMove({oEngineer}, oEngineer[reftEngineerCurrentTarget])
            end--]]
        end
    else

    --if aiBrain:GetEconomyStoredRatio('MASS') < 0.98 and (aiBrain:GetEconomyStoredRatio('MASS') == 0 or aiBrain:GetEconomyStored('MASS') / aiBrain:GetEconomyStoredRatio('MASS') > 50) then

        local tCurPos = oEngineer:GetPosition()
        --Has the engineer moved from its location when it was last told to reclaim?
        if bDebugMessages == true then LOG(sFunctionRef..': Checking if engineer has moved, oEngineer[M27UnitInfo.refbSpecialMicroActive]='..tostring((oEngineer[M27UnitInfo.refbSpecialMicroActive] or false))..'; oEngineer[reftEngineerLastPositionOfReclaimOrder]='..repru(oEngineer[reftEngineerLastPositionOfReclaimOrder])..'; oEngineer[reftEngineerCurrentTarget]='..repru(oEngineer[reftEngineerCurrentTarget])..'; dist to cur target='..M27Utilities.GetDistanceBetweenPositions(tCurPos, oEngineer[reftEngineerCurrentTarget])) end
        if not(oEngineer[M27UnitInfo.refbSpecialMicroActive]) then
            if not(oEngineer[reftEngineerLastPositionOfReclaimOrder]) or (M27Utilities.GetDistanceBetweenPositions(tCurPos, oEngineer[reftEngineerLastPositionOfReclaimOrder]) > 1 or M27Utilities.GetDistanceBetweenPositions(tCurPos, oEngineer[reftEngineerCurrentTarget]) <= 1.5) then
                --Is the engineer part of a segment with iMinReclaimIndividualValue reclaim, or near a segment with this minimum)?
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Engineer isnt close to recent reclaim order; will check if any reclaim in range of engi')
                    --DrawRectangle(rRect, iColour, iDisplayCount)
                    local iCurX, iCurZ = M27MapInfo.GetReclaimSegmentsFromLocation(tCurPos)
                    M27Utilities.DrawRectangle(Rect((iCurX - 1) * M27MapInfo.iReclaimSegmentSizeX, (iCurZ - 1) * M27MapInfo.iReclaimSegmentSizeZ, iCurX * M27MapInfo.iReclaimSegmentSizeX, iCurZ * M27MapInfo.iReclaimSegmentSizeZ))
                    LOG(sFunctionRef..': Have drawn rectangle that the engineer is in, iCurX='..iCurX..'; iCurZ='..iCurZ..'; IsReclaimNearby='..tostring(M27Conditions.IsReclaimNearby(tCurPos, 1, iMinReclaimIndividualValue)))
                end

                if M27Conditions.IsReclaimNearby(tCurPos, 1, iMinReclaimIndividualValue) then --want to only look at adjacent segments even for ACU, as build range of 10 should still be smaller than 1+bit of segment in almost all cases
                    if bDebugMessages == true then LOG(sFunctionRef..' Is reclaim in current or adjacent segment, will check if any reclaim will move out of range; oEngineer[reftEngineerCurrentTarget]='..repru(oEngineer[reftEngineerCurrentTarget] or {'nil'})) end
                    local oEngBP = oEngineer:GetBlueprint()
                    local iMoveSpeed = oEngBP.Physics.MaxSpeed
                    local iMaxDistanceToEngineer = oEngBP.Economy.MaxBuildDistance + math.min(oEngBP.SizeX, oEngBP.SizeZ) * 0.5 - 0.1
                    --local iRadius = iMaxDistanceToEngineer * 0.5

                    local iCurDistToEngineer
                    local iMinDistanceToEngineer = math.max(oEngBP.SizeX, oEngBP.SizeZ)
                    local iCompletionDistToFinalDestination = 3.5
                    if oEngineer.PlatoonHandle and oEngineer.Platoonhandle[M27PlatoonUtilities.refiOverrideDistanceToReachDestination] then iCompletionDistToFinalDestination = math.max(iCompletionDistToFinalDestination, oEngineer.Platoonhandle[M27PlatoonUtilities.refiOverrideDistanceToReachDestination]) end

                    local tExpectedPositionSoon = M27Utilities.MoveInDirection(tCurPos, M27Utilities.GetAngleFromAToB(tCurPos, oEngineer[reftEngineerCurrentTarget]), iMoveSpeed)

                    --GetReclaimInRectangle(iReturnType, rRectangleToSearch)
                    --    --iReturnType: 1 = true/false; 2 = number of wrecks; 3 = total mass, 4 = valid wrecks
                    local tNearbyReclaim = M27MapInfo.GetReclaimInRectangle(4, Rect(tCurPos[1] - iMaxDistanceToEngineer, tCurPos[3] - iMaxDistanceToEngineer, tCurPos[1] + iMaxDistanceToEngineer, tCurPos[3] + iMaxDistanceToEngineer))
                    if bDebugMessages == true then
                        if bDebugMessages == true then LOG(sFunctionRef..': iMaxDistanceToEngineer='..iMaxDistanceToEngineer..'; oEngBP.Economy.MaxBuildDistance='..oEngBP.Economy.MaxBuildDistance..'; Rect='..repru(Rect(tCurPos[1] - iMaxDistanceToEngineer, tCurPos[3] - iMaxDistanceToEngineer, tCurPos[1] + iMaxDistanceToEngineer, tCurPos[3] + iMaxDistanceToEngineer))) end
                        M27Utilities.DrawRectangle(Rect(tCurPos[1] - iMaxDistanceToEngineer, tCurPos[3] - iMaxDistanceToEngineer, tCurPos[1] + iMaxDistanceToEngineer, tCurPos[3] + iMaxDistanceToEngineer), 2, 20)
                    end

                    if M27Utilities.IsTableEmpty(tNearbyReclaim) == false then
                        local bGetEnergy = true
                        local bGetMass = true

                        if aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.95 then
                            bGetEnergy = false
                        else
                            if aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.25 then
                                bGetMass = false
                            end
                        end
                        if bGetMass and aiBrain:GetEconomyStoredRatio('MASS') >= 0.85 then
                            bGetMass = false
                        end

                        if bDebugMessages == true then LOG(sFunctionRef..': bGetEnergy='..tostring(bGetEnergy)..'; bGetMass='..tostring(bGetMass)) end

                        if bGetEnergy or bGetMass then
                            if M27Utilities.IsTableEmpty(oEngineer[reftEngineerCurrentTarget]) then
                                if oEngineer.GetNavigator then
                                    local oNavigator = oUnit:GetNavigator()
                                    if oNavigator and oNavigator.GetCurrentTargetPos then
                                        oEngineer[reftEngineerCurrentTarget] = oNavigator:GetCurrentTargetPos()
                                    end
                                end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': oEngineer[reftEngineerCurrentTarget]='..repru(oEngineer[reftEngineerCurrentTarget])..'; tCurPos='..repru(tCurPos)..'; iCompletionDistToFinalDestination='..iCompletionDistToFinalDestination..'; Dist to destination='..M27Utilities.GetDistanceBetweenPositions(oEngineer[reftEngineerCurrentTarget], tCurPos)) end
                            if M27Utilities.GetDistanceBetweenPositions(oEngineer[reftEngineerCurrentTarget], tCurPos) <= iCompletionDistToFinalDestination then
                                bReclaimWillMoveOutOfRangeSoon = true
                                iMinDistanceToEngineer = 0
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..'Have nearby reclaim, will check if any will move out of range soon. iMinDistanceToEngineer='..iMinDistanceToEngineer) end
                            local tReclaimInRange = {}
                            local iValidReclaimInRange = 0
                            for iReclaim, oReclaim in tNearbyReclaim do
                                --is this valid reclaim within our build area?
                                if bDebugMessages == true then
                                    LOG(sFunctionRef..': iReclaim='..iReclaim..'; oReclaim.MaxMassReclaim='..(oReclaim.MaxMassReclaim or 0))
                                    if oReclaim.MaxMassReclaim >= 100 or (bWantEnergy and oReclaim.MaxEnergyReclaim >= 100) then
                                        LOG('Large reclaim, repr of all values='..repru(oReclaim))
                                        if oReclaim.GetBlueprint then
                                            LOG('oReclaim has a blueprint='..repru(oReclaim:GetBlueprint()))
                                        else LOG('oReclaim doesnt have .GetBlueprint')
                                        end
                                    end--M27Utilities.DebugArray(oReclaim)) end
                                end
                                if oReclaim.CachePosition and ((bGetMass and oReclaim.MaxMassReclaim >= iMinReclaimIndividualValue) or (bGetEnergy and oReclaim.MaxEnergyReclaim >= iMinReclaimIndividualValue)) and not(oReclaim:BeenDestroyed()) then
                                    iCurDistToEngineer = math.max(0, M27Utilities.GetDistanceBetweenPositions(tCurPos, oReclaim.CachePosition) - math.min(oReclaim:GetBlueprint().SizeX, oReclaim:GetBlueprint().SizeZ)*0.5)
                                    if iCurDistToEngineer <= iMaxDistanceToEngineer and (iCurDistToEngineer > iMinDistanceToEngineer or oReclaim.MaxMassReclaim > 100) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': iReclaim='..iReclaim..'; Reclaim is in range, iCurDistToEngineer='..iCurDistToEngineer) end
                                        table.insert(tReclaimInRange, oReclaim)
                                        --Will the reclaim be out of range soon? or is it very high value such that we want to reclaim immediately?
                                        if (bGetMass and oReclaim.MaxMassReclaim > 100) or (bGetEnergy and oReclaim.MaxEnergyReclaim > 100) or M27Utilities.GetDistanceBetweenPositions(tExpectedPositionSoon, oReclaim.CachePosition) > iMaxDistanceToEngineer then
                                            bReclaimWillMoveOutOfRangeSoon = true
                                            --(dont want a break here, as need to record all reclaim in range right now for the recelaim command)
                                        end
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': iReclaim='..iReclaim..'; Too far away from engineer, iCurDistToEngineer='..iCurDistToEngineer) end
                                    end
                                end
                            end

                            --If we want to reclaim (it will move out of range soon) but we dont have any reclaim flagged as being in-range, then update to include all nearby reclaim as backup

                            if M27Utilities.IsTableEmpty(tReclaimInRange) and M27Utilities.IsTableEmpty(tNearbyReclaim) == false and bReclaimWillMoveOutOfRangeSoon then
                                tReclaimInRange = tNearbyReclaim
                            end

                            --Also reclaim if lots of enemy walls nearby if dealing with ACU (dont need to do for engis as their 'nearby enemy' logic should have them reclaim walls anyway)
                            if M27Utilities.IsACU(oEngineer) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Looking for how many walls we have nearby; tCurPos='..repru(tCurPos)..'; iMaxDistanceToEngineer='..iMaxDistanceToEngineer) end
                                local tNearbyWalls = aiBrain:GetUnitsAroundPoint(categories.WALL, tCurPos, iMaxDistanceToEngineer, 'Enemy')
                                if M27Utilities.IsTableEmpty(tNearbyWalls) == false then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have walls nearby, size of table='..table.getn(tNearbyWalls)) end
                                    for iWall, oWall in tNearbyWalls do
                                        table.insert(tReclaimInRange, oWall)
                                    end
                                    if table.getn(tNearbyWalls) >= 3 then bReclaimWillMoveOutOfRangeSoon = true end
                                    if bDebugMessages == true then LOG(sFunctionRef..': Finished adding nearby walls to reclaiminrange, size of tReclaimInRange='..table.getn(tReclaimInRange)..'; bReclaimWillMoveOutOfRangeSoon='..tostring(bReclaimWillMoveOutOfRangeSoon)) end
                                end
                            elseif bReclaimWillMoveOutOfRangeSoon and oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bReclaimWillMoveOutOfRangeSoon = false
                            end




                            if bDebugMessages == true then LOG(sFunctionRef..'bReclaimWillMoveOutOfRangeSoon='..tostring(bReclaimWillMoveOutOfRangeSoon)) end
                            if bReclaimWillMoveOutOfRangeSoon then
                                --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
                                if bDebugMessages == true then LOG(sFunctionRef..'Reclaim is about to go out of range so will issue reclaim command for any valid reclaim') end
                                oEngineer[reftEngineerLastPositionOfReclaimOrder] = {tCurPos[1], tCurPos[2], tCurPos[3]}
                                IssueClearCommands({oEngineer})
                                for iValidReclaim, oValidReclaim in tReclaimInRange do
                                    if bDebugMessages == true then LOG(sFunctionRef..'Issuing reclaim command to iValidReclaim='..iValidReclaim) end
                                    IssueReclaim({oEngineer}, oValidReclaim)
                                end
                                if not(bDontIssueMoveAfter) then
                                    ReissueEngineerOldOrders(aiBrain, oEngineer, false)
                                    --[[if M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), oEngineer[reftEngineerCurrentTarget]) >= 3 then
                                        IssueMove({oEngineer}, oEngineer[reftEngineerCurrentTarget])
                                    end--]]
                                end
                            end
                        elseif bDebugMessages == true then LOG(sFunctionRef..': Dont want mass or energy reclaim')
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..' No reclaim in engineer build range') end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..' No reclaim in nearby segments') end
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Engineer hasnt moved from its last position where it was given a reclaim order; tCurPos='..repru(tCurPos)..'; oEngineer[reftEngineerLastPositionOfReclaimOrder]='..repru(oEngineer[reftEngineerLastPositionOfReclaimOrder] or {'nil'})) end
            end
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Engineer has special micro active') end
        end
    --else
    --    if bDebugMessages == true then LOG(sFunctionRef..': Have too much mass so wont try to reclaim; Stored ratio='..aiBrain:GetEconomyStoredRatio('MASS')..'; Mass stored='..aiBrain:GetEconomyStored('MASS')) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bReclaimWillMoveOutOfRangeSoon
end

function RegularlyCheckForNearbyReclaim(oEngineer, bWantEnergy)
    --Should be called via a fork thread
    --(dont use function profiler as too few commands absent the waitseconds to be worth putting in lots of profiler calls)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RegularlyCheckForNearbyReclaim'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iMinReclaimValue = 2.5
    local aiBrain = oEngineer:GetAIBrain()
    if oEngineer[refiEngineerCurrentAction] == refActionBuildMex or oEngineer[refiEngineerCurrentAction] == refActionBuildPlateauMex then iMinReclaimValue = 10 end
    --if GetEngineerUniqueCount(oEngineer) == 31 and GetGameTimeSeconds() >= 305 then bDebugMessages = true end
    if not(oEngineer[refbEngineerActiveReclaimChecker]) then
        oEngineer[refbEngineerActiveReclaimChecker] = true
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitSeconds(1)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        while M27UnitInfo.IsUnitValid(oEngineer) do
            if oEngineer[refiEngineerCurrentAction] == refActionReclaimArea or oEngineer[refiEngineerCurrentAction] == refActionPlateauReclaim or oEngineer[refiEngineerCurrentAction] == refActionReclaimTrees or oEngineer[refiEngineerCurrentAction] == refActionBuildMex or oEngineer[refiEngineerCurrentAction] == refActionBuildPlateauMex then
                if bDebugMessages == true then LOG(sFunctionRef..': Will call function to check for nearby reclaim as that is still our action') end
                --If action is to build mex, only do this if we have <20% mass or <=80% energy stored
                if not(oEngineer[refiEngineerCurrentAction] == refActionBuildMex or oEngineer[refiEngineerCurrentAction] == refActionBuildPlateauMex) or aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.8 or aiBrain:GetEconomyStoredRatio('MASS') <= 0.2 then
                    UpdateActionForNearbyReclaim(oEngineer, iMinReclaimValue, nil, bWantEnergy)
                end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitSeconds(1)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Engineer doesnt ahve an action that we want to have checking for reclaim so will abort the loop to check periodically for reclaim') end
                oEngineer[refbEngineerActiveReclaimChecker] = false
                break
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function AttackMoveToRandomPositionAroundBase(aiBrain, oEngineer, iMaxDistance, iMinDistance)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'AttackMoveToRandomPositionAroundBase'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if M27MapInfo.bNoRushActive then
        iMinDistance = math.max(M27MapInfo.iNoRushRange - iMaxDistance + iMinDistance, 0)
        iMaxDistance = math.min(iMaxDistance, M27MapInfo.iNoRushRange)
    end

    --Check pathing group
    local iEngiPathingGroup = M27MapInfo.GetUnitSegmentGroup(oEngineer)
    local sPathing = M27UnitInfo.GetUnitPathingType(oEngineer)
    if sPathing == M27UnitInfo.refPathingTypeNone or sPathing == M27UnitInfo.refPathingTypeAll then sPathing = M27UnitInfo.refPathingTypeLand end
    local tActionTargetLocation = {M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][2], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]}
    if not(iEngiPathingGroup == M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) then
        --Engi not expected to be able to path to base based on segment pathing - check if this is correct
        if not(M27MapInfo.RecheckPathingOfLocation(sPathing, oEngineer, tActionTargetLocation, nil)) or not(iEngiPathingGroup == M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) then
            --Engi cant path to base, so instead look for somwhere randomly from where it currently is and reduce min and max distance
            tActionTargetLocation = oEngineer:GetPosition()
            iMinDistance = math.min(5, iMinDistance)
            iMaxDistance = math.min(iMinDistance + 5, iMaxDistance)
        end
    end
    if bDebugMessages == true then LOG(sFunctionRef..': About to get random point in area that can path to') end

    local tRandomTargetLocation = M27Logic.GetRandomPointInAreaThatCanPathTo(sPathing, iEngiPathingGroup, tActionTargetLocation, iMaxDistance, iMinDistance, bDebugMessages)
    if tRandomTargetLocation == nil then
        --Couldnt find anywhere that can path to, check if pathing is correct for our current position; if it is then just go for the location itself
        --We cant path to the target, check if its correct to think this
        if M27MapInfo.RecheckPathingOfLocation(sPathing, oEngineer, tActionTargetLocation, nil) then
            --Have changed the pathing so retry
            tRandomTargetLocation = M27Logic.GetRandomPointInAreaThatCanPathTo(sPathing, iEngiPathingGroup, tActionTargetLocation, iMaxDistance, iMinDistance)
            if tRandomTargetLocation == nil then tRandomTargetLocation = tActionTargetLocation end
        else
            --Its correct that we cant path to the target, so just resort to backup of trying to go there anywhere
            tRandomTargetLocation = tActionTargetLocation
            --Generate log in all scenarios as this ideally shouldnt happen often so may want to check logs
            LOG(sFunctionRef..': aiBrain with index='..aiBrain:GetArmyIndex()..' failed to get random location that can path to; oEngineer='..oEngineer.UnitId..GetEngineerUniqueCount(oEngineer)..'; iEngiPathingGroup='..iEngiPathingGroup..'; Pathing group of base='..M27MapInfo.GetSegmentGroupOfLocation(sPathing, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]))
        end
    end
    IssueAggressiveMove({ oEngineer }, tRandomTargetLocation)
    local sLocationRef = M27Utilities.ConvertLocationToReference(tRandomTargetLocation)
    aiBrain[reftSpareEngineerAttackMoveTimeByLocation][sLocationRef] = GetGameTimeSeconds()
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tRandomTargetLocation
end

function ReplaceT2WithT3Monitor(aiBrain, oEngineer, oActionTargetObject)
    --Call this via forkthread; will check if oEngineer is near the target object, and if the target object exists, and once it is, will get it rebuilt with a T3 mex
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReplaceT2WithT3Monitor'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if GetEngineerUniqueCount(oEngineer) == 58 and GetGameTimeSeconds() >= 2040 then bDebugMessages = true else bDebugMessages = false end

    local tTargetMex = oActionTargetObject:GetPosition()
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code for Engineer UC='..GetEngineerUniqueCount(oEngineer)..'; LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..', tTargetMex='..repru(tTargetMex)..'; Target object='..oActionTargetObject.UnitId..M27UnitInfo.GetUnitLifetimeCount(oActionTargetObject)) end

    local iDistanceThreshold = oEngineer:GetBlueprint().Economy.MaxBuildDistance + 1 --Mex is 2x2 size, so has radius of 1

    --Move towards the target if we aren't already near there
    if M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), tTargetMex) >= 6 then
        if bDebugMessages == true then LOG(sFunctionRef..': Arent near the target so sending issuemove to it before starting main loop') end
        IssueMove({oEngineer}, tTargetMex)
        WaitTicks(10)
    end

    --Wait until we are near the target

    while M27UnitInfo.IsUnitValid(oEngineer) and M27UnitInfo.IsUnitValid(oActionTargetObject) and oEngineer[refiEngineerCurrentAction] == refActionBuildT3MexOverT2 do
        if M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), tTargetMex) >= iDistanceThreshold then
            if bDebugMessages == true then LOG(sFunctionRef..': Are more than 6 away from target so waiting 1 second then rechecking') end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitTicks(10)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Are close enough to mex now so will move on to ctrlk logic') end
            break
        end
    end

    --Ctrl-K the target if engineer and target still exist
    if M27UnitInfo.IsUnitValid(oEngineer) and oEngineer[refiEngineerCurrentAction] == refActionBuildT3MexOverT2 then
        if bDebugMessages == true then LOG(sFunctionRef..': UC='..GetEngineerUniqueCount(oEngineer)..': Are near target, current action='..oEngineer[refiEngineerCurrentAction]..'; Target object='..oActionTargetObject.UnitId..M27UnitInfo.GetUnitLifetimeCount(oActionTargetObject)) end

        if not(M27UnitInfo.IsUnitValid(oActionTargetObject)) or (oActionTargetObject:IsUnitState('Upgrading') and oActionTargetObject.GetWorkProgress and oActionTargetObject:GetWorkProgress() > 0.01) then
            if bDebugMessages == true then LOG(sFunctionRef..': Target no longer valid or is upgrading so will clear engineer trackers') end
            ClearEngineerActionTrackers(aiBrain, oEngineer, true)
            M27EconomyOverseer.RefreshT2MexesNearBase(aiBrain)
        else
            --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
            if bDebugMessages == true then LOG(sFunctionRef..': About to tell '..oActionTargetObject.UnitId..M27UnitInfo.GetUnitLifetimeCount(oActionTargetObject)..' to ctrlk') end
            oActionTargetObject:Kill()
            IssueClearCommands({oEngineer})
            BuildStructureAtLocation(aiBrain, oEngineer, M27UnitInfo.refCategoryT3Mex, 1, nil, tTargetMex, true, false)
            M27Utilities.DelayChangeVariable(oEngineer, rebToldToStartBuildingT3Mex, true, 20)
            WaitTicks(10) --Backup logic
            if M27UnitInfo.IsUnitValid(oEngineer) then
                if bDebugMessages == true then LOG(sFunctionRef..': Finished waiting for engineer UC'..GetEngineerUniqueCount(oEngineer)..'; About to tell engineer to build T3 mex at the location. tTargetMex='..repru(tTargetMex)) end
                --M27Utilities.DelayChangeVariable(oEngineer, rebToldToStartBuildingT3Mex, true, 8)
                BuildStructureAtLocation(aiBrain, oEngineer, M27UnitInfo.refCategoryT3Mex, 1, nil, tTargetMex, true, false)
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Engineer is no longer valid') end
            end
        end
    elseif bDebugMessages == true then LOG(sFunctionRef..': Engineer either no longer valid or has been reassigned so aborting')
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetLikelySMLTarget(aiBrain, oSML)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetLikelySMLTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iAOE, iDamage, iMinRange, iMaxRange = M27UnitInfo.GetLauncherAOEStrikeDamageMinAndMaxRange(oSML)
    local tSMLTarget, iSMLDamage

    local tLikelyTarget, iBestDamage = M27Logic.GetBestAOETarget(aiBrain, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), iAOE, iDamage, true, oSML:GetPosition(), 0, 1)
    if bDebugMessages == true then LOG(sFunctionRef..': If target primary enemy base we expect to deal damage of '..iBestDamage) end
    if iBestDamage < 27000 then
        for iStartPoint = 1, table.getn(M27MapInfo.PlayerStartPoints) do
            if not(iStartPoint == aiBrain.M27StartPositionNumber) and M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[iStartPoint], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)) >= 30 then
                if bDebugMessages == true then LOG(sFunctionRef..': Considering the start position '..iStartPoint..'='..repru(M27MapInfo.PlayerStartPoints[iStartPoint])) end
                tSMLTarget, iSMLDamage = M27Logic.GetBestAOETarget(aiBrain, M27MapInfo.PlayerStartPoints[iStartPoint], iAOE, iDamage, true, oSML:GetPosition(), 0, 1)
                if iSMLDamage > iBestDamage then
                    iBestDamage = iSMLDamage
                    tLikelyTarget = tSMLTarget
                end
                if iSMLDamage >= 27000 then
                    break
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tLikelyTarget, iBestDamage
end

function IsValidTMLTarget(aiBrain, tStartPos, oTarget, tEnemyTMD)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsValidTMLTarget'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Considering whether oTarget '..oTarget.UnitId..M27UnitInfo.GetUnitLifetimeCount(oTarget)..' is a valid TML target.  Is TMD table empty='..tostring(M27Utilities.IsTableEmpty(tEnemyTMD))..'; target faction complete='..oTarget:GetFractionComplete()..'; TML shots fired at target='..(oTarget[refiTMLShotsFired] or 'nil')..'; Strike damage assigned='..(oTarget[M27AirOverseer.refiStrikeDamageAssigned] or 'nil')..'; Unit max health='..oTarget:GetMaxHealth()) end

    if M27UnitInfo.IsUnitValid(oTarget) and oTarget:GetFractionComplete() >= 0.5 and ((oTarget[refiTMLShotsFired] or 0) == 0 or oTarget[refiTMLShotsFired] <= math.floor(oTarget:GetMaxHealth() / 6000)) and (oTarget[M27AirOverseer.refiStrikeDamageAssigned] or 0) == 0 then
        local iDistStartToTarget = M27Utilities.GetDistanceBetweenPositions(tStartPos, oTarget:GetPosition())
        --local iMaxShieldHealth = math.max(0, 6000 - oTarget:GetHealth() * 1.1 - 100) --Decided not to do, since unclear whether the shield could still stop the missile if strong enough - recall when testing mobile shields they could block a missile and survive
        --IsTargetUnderShield(aiBrain, oTarget, iIgnoreShieldsWithLessThanThisHealth, bReturnShieldHealthInstead, bIgnoreMobileShields, bTreatPartCompleteAsComplete)
        if bDebugMessages == true then LOG(sFunctionRef..': iDistStartToTarget='..iDistStartToTarget..'; iTMLMinMissileRange='..iTMLMinMissileRange..'; iTMLMissileRange='..iTMLMissileRange..'; Is target under shield='..tostring(M27Logic.IsTargetUnderShield(aiBrain, oTarget, 0, false, false, true))) end
        if iDistStartToTarget >= iTMLMinMissileRange and iDistStartToTarget <= iTMLMissileRange and not(M27Logic.IsTargetUnderShield(aiBrain, oTarget, 0, false, false, true)) then
            local bIsBlockedByTMD = false
            if M27Utilities.IsTableEmpty(tEnemyTMD) == false then
                local iDistFromStartToTMD
                local iAngleFromStartToTMD
                local iDistFromTargetToTMD
                for iTMD, oTMD in tEnemyTMD do
                    iAngleFromStartToTMD = M27Utilities.GetAngleFromAToB(tStartPos, oTMD:GetPosition())
                    iDistFromStartToTMD = M27Utilities.GetDistanceBetweenPositions(tStartPos, oTMD:GetPosition())
                    iDistFromTargetToTMD = M27Utilities.GetDistanceBetweenPositions(oTarget:GetPosition(), oTMD:GetPosition())
                    if M27Utilities.IsLineFromAToBInRangeOfCircleAtC(iDistStartToTarget, iDistFromStartToTMD, iDistFromTargetToTMD, M27Utilities.GetAngleFromAToB(tStartPos, oTarget:GetPosition()), iAngleFromStartToTMD, 31) then
                        bIsBlockedByTMD = true
                        break
                    end
                end
            end

            if bDebugMessages == true then LOG(sFunctionRef..': Finished checking if blocked by TMD. bIsBlockedByTMD='..tostring(bIsBlockedByTMD)) end


            if bIsBlockedByTMD == false then
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                return true
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return false
end

function GetTMLBuildLocation(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetTMLBuildLocation'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --Returns nil if cant find at least 2 valid TML targets
    if GetGameTimeSeconds() - (aiBrain[refiTimeOfLastTMLTargetRefresh] or -100) > 1 then
        RecordPossibleTMLTargets(aiBrain)
    end
    local tStartPos = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': Start of code, aiBrain index=' .. aiBrain:GetArmyIndex() .. '; tStartPos=' .. repru(tStartPos) .. '; Is table of TML targets empty=' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftoTMLTargetsOfInterest])))
    end
    if M27Utilities.IsTableEmpty(aiBrain[reftoTMLTargetsOfInterest]) == false and table.getn(aiBrain[reftoTMLTargetsOfInterest]) >= 2 then
        local oNearestTargetOfInterest = M27Utilities.GetNearestUnit(aiBrain[reftoTMLTargetsOfInterest], tStartPos, aiBrain)
        if bDebugMessages == true then
            LOG(sFunctionRef .. ': Have at least 2 targets of interest. oNearestTargetOfInterest is valid=' .. tostring(M27UnitInfo.IsUnitValid(oNearestTargetOfInterest)))
        end
        if M27UnitInfo.IsUnitValid(oNearestTargetOfInterest) then
            --Get rough build location so can look for enemies in range of it
            local iInitialDistanceFromBase = math.max(math.min(M27Utilities.GetDistanceBetweenPositions(oNearestTargetOfInterest:GetPosition(), tStartPos) - 100, 125), 25)
            local iAngleToFirstTarget = M27Utilities.GetAngleFromAToB(tStartPos, oNearestTargetOfInterest:GetPosition())
            local tPositionToCheckForBuildingLocation = M27Utilities.MoveInDirection(tStartPos, iAngleToFirstTarget, iInitialDistanceFromBase, true)
            --local tPositionToCheckForBuildingLocation = M27Utilities.MoveTowardsTarget(tStartPos, oNearestTargetOfInterest:GetPosition(), iInitialDistanceFromBase, iAngleToFirstTarget)
            if bDebugMessages == true then
                LOG(sFunctionRef .. ': Our start position=' .. repru(tStartPos) .. '; oNearestTargetOfInterest=' .. oNearestTargetOfInterest.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oNearestTargetOfInterest) .. '; position=' .. repru(oNearestTargetOfInterest:GetPosition()) .. '; tPositionToCheckForBuildingLocation=' .. repru(tPositionToCheckForBuildingLocation) .. '; iInitialDistanceFromBase=' .. iInitialDistanceFromBase .. '; iAngleToFirstTarget=' .. iAngleToFirstTarget)
            end
            local tLikelyBuildLocation = FindRandomPlaceToBuild(aiBrain, nil, tPositionToCheckForBuildingLocation, 'ueb2108', 0, 8, false, nil, true, true)
            if M27Utilities.IsTableEmpty(tLikelyBuildLocation) then

                local iAngleToLocation = M27Utilities.GetAngleFromAToB(tStartPos, tPositionToCheckForBuildingLocation)
                local iPathingGroupWanted = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tStartPos)
                local iMaxDist = M27Utilities.GetDistanceBetweenPositions(tStartPos, tPositionToCheckForBuildingLocation)
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': tLikelyBuildLocation is empty so will try and find somewhere else. iMaxDist=' .. iMaxDist .. '; iPathingGroupWanted=' .. iPathingGroupWanted .. '; iAngleToLocation=' .. iAngleToLocation)
                end
                for iDistAdjust = -2, -50, -2 do
                    tLikelyBuildLocation = M27Utilities.MoveInDirection(tStartPos, iAngleToLocation, iMaxDist + iDistAdjust, true)
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Considering alternative location ' .. repru(tLikelyBuildLocation) .. '; M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tLikelyBuildLocation)=' .. M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tLikelyBuildLocation) .. '; Base=' .. aiBrain[M27MapInfo.refiOurBasePlateauGroup] .. '; CanBuildAtLocation=' .. tostring(CanBuildAtLocation(aiBrain, 'ueb2108', tLikelyBuildLocation, nil, false, true)))
                    end
                    if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tLikelyBuildLocation) == iPathingGroupWanted and CanBuildAtLocation(aiBrain, 'ueb2108', tLikelyBuildLocation, nil, false, true) then
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Have found alternative position=' .. repru(tLikelyBuildLocation) .. ' that is a valid location to build')
                        end
                        break
                    else
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Cant build here, will draw in red')
                            M27Utilities.DrawLocation(tLikelyBuildLocation, nil, 2, 100, nil)
                        end
                        tLikelyBuildLocation = nil
                    end
                end
            end
            if M27Utilities.IsTableEmpty(tLikelyBuildLocation) == false then
                local iTargetsInRange = 0
                local toTargetsInRange = {}
                local iDistHeadroom = 10000
                local iFurthestDistToLikelyBuildLocation = 0
                local tEnemyTMD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryTMD, tLikelyBuildLocation, iTMLMissileRange + 30, 'Enemy')
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': Have a location ' .. repru(tLikelyBuildLocation) .. '; will check how many targets are in range after considering TMD. Is enemy TMD empty=' .. tostring(M27Utilities.IsTableEmpty(tEnemyTMD)))
                end
                for iTarget, oTarget in aiBrain[reftoTMLTargetsOfInterest] do
                    if IsValidTMLTarget(aiBrain, tLikelyBuildLocation, oTarget, tEnemyTMD) then
                        iTargetsInRange = iTargetsInRange + 1
                        toTargetsInRange[iTargetsInRange] = oTarget
                        iFurthestDistToLikelyBuildLocation = math.max(iFurthestDistToLikelyBuildLocation, M27Utilities.GetDistanceBetweenPositions(tLikelyBuildLocation, oTarget:GetPosition()))
                    end
                end
                
                iDistHeadroom = iTMLMissileRange - iFurthestDistToLikelyBuildLocation
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iTargetsInRange=' .. iTargetsInRange .. '; iDistHeadroom=' .. iDistHeadroom)
                end
                if iTargetsInRange < 2 then
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': iTargetsInRange=' .. iTargetsInRange .. '; will abort as want at least 2 targets')
                    end
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    return nil
                else
                    --Can the build position be moved closer to base while keeping within range?
                    if iDistHeadroom > 2 and iDistHeadroom < iTMLMissileRange then
                        --Move in a line starting closest towards our base and moving towards the location found
                        local tPossibleBuildLocation
                        local iAngleFromBuildLocationToStart = M27Utilities.GetAngleFromAToB(tLikelyBuildLocation, tStartPos)
                        local iPathingGroupWanted = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tStartPos)
                        local iMaxDist = M27Utilities.GetDistanceBetweenPositions(tStartPos, tLikelyBuildLocation)
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Will see if we can move closer to base while keeping the targets within range.  iMaxDist=' .. iMaxDist .. '; iDistHeadroom=' .. iDistHeadroom .. '; iPathingGroupWanted=' .. iPathingGroupWanted .. '; iAngleFromBuildLocationToStart=' .. iAngleFromBuildLocationToStart .. '; tStartPos=' .. repru(tStartPos) .. '; tLikelyBuildLocation=' .. repru(tLikelyBuildLocation))
                        end
                        iDistHeadroom = math.floor(math.min((iDistHeadroom - 2), iMaxDist) * 0.5)*2
                        if iDistHeadroom >= 2 then
                            for iDistAdjust = iDistHeadroom, 2, -2 do
                                tPossibleBuildLocation = M27Utilities.MoveInDirection(tLikelyBuildLocation, iAngleFromBuildLocationToStart, iDistAdjust, true)
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': iDistAdjust=' .. iDistAdjust .. '; tPossibleBuildLocation=' .. repru(tPossibleBuildLocation) .. '; segment group of this=' .. M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tPossibleBuildLocation) .. '; iPathingGroupWanted=' .. iPathingGroupWanted .. '; CanBuildAtLocation=' .. tostring(CanBuildAtLocation(aiBrain, 'ueb2108', tPossibleBuildLocation, nil, false, true))..'; will draw in white')
                                    --Draw in white
                                    M27Utilities.DrawLocation(tLikelyBuildLocation, nil, 7, 100, nil)
                                end
                                if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tPossibleBuildLocation) == iPathingGroupWanted and CanBuildAtLocation(aiBrain, 'ueb2108', tPossibleBuildLocation, nil, false, true) then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Have found a possible build location so will return this, tPossibleBuildLocation=' .. repru(tPossibleBuildLocation))
                                    end
                                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                                    return tPossibleBuildLocation
                                end
                            end
                        end
                    end
                    if bDebugMessages == true then
                        LOG(sFunctionRef .. ': Found likely build location=' .. repru(tLikelyBuildLocation))
                    end
                    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                    return tLikelyBuildLocation
                end
            elseif bDebugMessages == true then
                LOG(sFunctionRef .. ': Couldnt find any likely build location for TML so will return nil')
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef .. ': End of code, since we got here we presumably didnt find a suitable location, tLikelyBuildLocation=' .. repru(tLikelyBuildLocation or { 'nil' }) .. '; will return nil')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return nil
end

function RecordPossibleTMLTargets(aiBrain, bForceRefresh)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordPossibleTMLTargets'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bForceRefresh or GetGameTimeSeconds() - (aiBrain[refiTimeOfLastTMLTargetRefresh] or -100) >= 10 then
        local iSearchRange = iTMLMissileRange + math.min(125, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.25)
        local tPotentialTargets = aiBrain:GetUnitsAroundPoint(iTMLHighPriorityCategories, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iSearchRange, 'Enemy')
        aiBrain[reftoTMLTargetsOfInterest] = {}
        aiBrain[refiTimeOfLastTMLTargetRefresh] = GetGameTimeSeconds()
        if bDebugMessages == true then LOG(sFunctionRef..': GameTime='..aiBrain[refiTimeOfLastTMLTargetRefresh]..'; SearchRange='..iSearchRange..'; Is tPotentialTargets empty='..tostring(M27Utilities.IsTableEmpty(tPotentialTargets))) end
        if M27Utilities.IsTableEmpty(tPotentialTargets) == false then
            local iValidTargets = 0
            local tEnemyTMD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryTMD, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iSearchRange + 31, 'Enemy')
            for iUnit, oUnit in tPotentialTargets do
                if bDebugMessages == true then LOG(sFunctionRef..': Considering whether oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' is a valid TML target.  Is table of TMD empty='..tostring(M27Utilities.IsTableEmpty(tEnemyTMD))) end
                if IsValidTMLTarget(aiBrain, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oUnit, tEnemyTMD) then
                    iValidTargets = iValidTargets + 1
                    aiBrain[reftoTMLTargetsOfInterest][iValidTargets] = oUnit
                    if bDebugMessages == true then LOG(sFunctionRef..': Have a valid target, iValidTargets='..iValidTargets..'; recording for oUnit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function IsUnitCoveredBySMD(aiBrain, oTarget, tSMD, tNukes)
    --Returns true if either no nukes, or target is protected from every nuke by SMD
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsUnitCoveredBySMD'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)



    if M27Utilities.IsTableEmpty(tNukes) == false then
        --If we have already checked in the last 10 seconds then just use this value
        if GetGameTimeSeconds() - (oTarget[M27UnitInfo.refiTimeOfLastSMDCheck] or -100) <= 10 then
            if bDebugMessages == true then LOG(sFunctionRef..': We have checked in the last 10 seconds so returning that value') end
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return oTarget[M27UnitInfo.refbLastCoveredBySMD]
        elseif M27Utilities.IsTableEmpty(tSMD) then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return false
        else
            --Recalculate
            oTarget[M27UnitInfo.refiTimeOfLastSMDCheck] = GetGameTimeSeconds()
            local iDistFromNukeToTarget
            local iDistFromNukeToSMD
            local iDistFromTargetToSMD
            local iAngleFromNukeToTarget
            local iAngleFromNukeToSMD
            local iSMDRange
            local bCurNukeIsBlocked



            for iNuke, oNuke in aiBrain[M27Overseer.reftEnemyNukeLaunchers] do
                iDistFromNukeToTarget = M27Utilities.GetDistanceBetweenPositions(oNuke:GetPosition(), oTarget:GetPosition())
                iAngleFromNukeToTarget = M27Utilities.GetAngleFromAToB(oNuke:GetPosition(), oTarget:GetPosition())
                bCurNukeIsBlocked = false
                for iSMD, oSMD in tSMD do
                    iDistFromNukeToSMD = M27Utilities.GetDistanceBetweenPositions(oNuke:GetPosition(), oSMD:GetPosition())
                    if iDistFromNukeToSMD < iDistFromNukeToTarget then iSMDRange = 90 else iSMDRange = 60 end
                    iDistFromTargetToSMD = M27Utilities.GetDistanceBetweenPositions(oSMD:GetPosition(), oTarget:GetPosition())
                    iAngleFromNukeToSMD = M27Utilities.GetAngleFromAToB(oNuke:GetPosition(), oSMD:GetPosition())
                    if M27Utilities.IsLineFromAToBInRangeOfCircleAtC(iDistFromNukeToTarget, iDistFromNukeToSMD, iDistFromTargetToSMD, iAngleFromNukeToTarget, iAngleFromNukeToSMD, iSMDRange) then
                        bCurNukeIsBlocked = true
                        break
                    end
                end
                if not(bCurNukeIsBlocked) then break end
            end
            oTarget[M27UnitInfo.refbLastCoveredBySMD] = bCurNukeIsBlocked
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            return bCurNukeIsBlocked
        end
    else
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        return true
    end
end


function CheckForEnemySMD(aiBrain, oSML)
    --Call via fork thread; Checks if enemy has built an SMD, and if so considers if should abort the SML
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CheckForEnemySMD'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    oSML[M27UnitInfo.refbActiveSMDChecker] = true
    local tEnemySMD
    local bEnemyHasConstructedSMD = false
    aiBrain[M27EconomyOverseer.refbReclaimNukes] = false
    if bDebugMessages == true then LOG(sFunctionRef..': Starting loop for checking for enemy SMD; Nuke details='..oSML.UnitId..M27UnitInfo.GetUnitLifetimeCount(oSML)) end
    local reftSMDAlreadyConsidered = 'M27SMDAlreadyConsidered'

    --Reset SMD that have considered
    oSML[reftSMDAlreadyConsidered] = {}

    local bAlreadyConsideredSMD

    local tLikelyTarget, iLikelyDamage = GetLikelySMLTarget(aiBrain, oSML)
    local bAbortConstruction



    while M27UnitInfo.IsUnitValid(oSML) do
        --Be more responsive to enemy SMD
        if bDebugMessages == true then LOG(sFunctionRef..': About to make segments around tLikelyTarget='..repru((tLikelyTarget or {'nil'}))..' a high priority for scouting') end
        M27AirOverseer.MakeSegmentsAroundPositionHighPriority(aiBrain, tLikelyTarget, 1)

        tEnemySMD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategorySMD, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] + 60, 'Enemy')
        if bDebugMessages == true then LOG(sFunctionRef..': GameTime='..GetGameTimeSeconds()..'; Does enemy have No SMD='..tostring(M27Utilities.IsTableEmpty(tEnemySMD))) end
        if M27Utilities.IsTableEmpty(tEnemySMD) == false then
            for iSMD, oSMD in tEnemySMD do
                bAlreadyConsideredSMD = false
                --Check we havent already considered this SMD for this SML
                if M27Utilities.IsTableEmpty(oSML[reftSMDAlreadyConsidered]) == false then
                   for iConsideredSMD, oConsideredSMD in oSML[reftSMDAlreadyConsidered] do
                      if oSMD == oConsideredSMD then bAlreadyConsideredSMD = true end
                   end
                end
                if not(bAlreadyConsideredSMD) then
                    table.insert(oSML[reftSMDAlreadyConsidered], oSMD)
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': Considering oSMD for the first time, oSMD='..oSMD.UnitId..M27UnitInfo.GetUnitLifetimeCount(oSMD)..'; Enemy SMD fraction complete='..oSMD:GetFractionComplete()..'; SML fraction complete='..oSML:GetFractionComplete())
                        if oSML.GetWorkProgress then LOG(sFunctionRef..': SML work progress='..oSML:GetWorkProgress()) end
                    end
                    if oSMD.GetFractionComplete and oSMD:GetFractionComplete() == 1 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy SMD is fully constructed') end
                        bEnemyHasConstructedSMD = true
                    elseif oSMD:GetFractionComplete() < 1 and (oSML:GetFractionComplete() < 1 or oSML:GetWorkProgress() < (0.075 + 0.12 * oSMD:GetFractionComplete())) then
                        bEnemyHasConstructedSMD = true
                    end

                    if bEnemyHasConstructedSMD then
                        if bDebugMessages == true then LOG(sFunctionRef..': Checking if SMD will impact ono ur expected destination') end
                        --Check if this impacts on our expected destination, and if so get a new expected destination
                        if M27Logic.IsSMDBlockingTarget(aiBrain, tLikelyTarget, oSML:GetPosition(), 0, 0) then
                            tLikelyTarget, iLikelyDamage = GetLikelySMLTarget(aiBrain, oSML)
                            if bDebugMessages == true then LOG(sFunctionRef..': SMD is blocking likely target, new likely target and damage='..repru(tLikelyTarget)..'; Damage='..iLikelyDamage) end
                            if iLikelyDamage < 20000 then
                                bAbortConstruction = true
                            end
                        elseif bDebugMessages == true then LOG(sFunctionRef..': SMD isnt blocking tLikelyTarget='..repru(tLikelyTarget))
                        end
                    end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': bEnemyHasConstructedSMD='..tostring(bEnemyHasConstructedSMD)) end
            if bAbortConstruction then
                --Dont abort if lots of enemies, since the cost of SMD to protect from nuke will exceed the benefit of reclaiming
                if oSML:GetFractionComplete() >= 0.5 then
                    local iEnemyBrainCount = 0
                    for iBrain, oBrain in aiBrain[M27Overseer.toEnemyBrains] do
                        iEnemyBrainCount = iEnemyBrainCount + 1
                    end
                    if iEnemyBrainCount >= 3 then
                        bAbortConstruction = false
                    end
                end
                if not(bAbortConstruction) then
                    break --No point carrying on with the loop as we are committed to building it now
                else


                    local oEngineer
                    if oSML:GetFractionComplete() < 1 then
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': Will clear all engis constructing experimental; Is table of engineers with action to build experimental empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildExperimental]))..'; aiBrain[refiLastExperimentalReference]='..(aiBrain[refiLastExperimentalReference] or 'nil'))
                        end
                        --Abort construction if the SMD impacts on our expected target location and we cant find any other viable targets
                        if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildExperimental]) == false and aiBrain[refiLastExperimentalReference] == refiExperimentalNuke then
                            if bDebugMessages == true then LOG(sFunctionRef..'Have engineers building experimental that is SML so will go through and clear them') end
                            for iRef, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildExperimental] do
                                --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
                                oEngineer = tSubtable[refEngineerAssignmentEngineerRef]
                                --if GetEngineerUniqueCount(oEngineer) == 58 and GetGameTimeSeconds() >= 2040 then bDebugMessages = true else bDebugMessages = false end
                                IssueClearCommands({oEngineer})
                                ClearEngineerActionTrackers(aiBrain, oEngineer, true)
                                if bDebugMessages == true then LOG(sFunctionRef..': Cleared engineer UC='..GetEngineerUniqueCount(oEngineer)..' with LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)) end
                            end
                        end
                    end
                    --Clear any assisting engineers
                    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistNuke]) == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': Have engineers with assist nuke action - will clear') end
                        for iRef, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistNuke] do
                            oEngineer = tSubtable[refEngineerAssignmentEngineerRef]
                            --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
                            --if GetEngineerUniqueCount(oEngineer) == 58 and GetGameTimeSeconds() >= 2040 then bDebugMessages = true else bDebugMessages = false end
                            IssueClearCommands({oEngineer})
                            ClearEngineerActionTrackers(aiBrain, oEngineer, true)
                            if bDebugMessages == true then LOG(sFunctionRef..': Cleared engineer UC='..GetEngineerUniqueCount(oEngineer)..' with LC='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)) end
                        end
                    end

                    --Add SML to list of units to be reclaimed
                    if bDebugMessages == true then LOG(sFunctionRef..': Have set a flag to reclaim nukes') end
                    aiBrain[M27EconomyOverseer.refbReclaimNukes] = true
                    oSML[M27EconomyOverseer.refbWillReclaimUnit] = true
                    --Disable missile autobuild
                    oSML:SetAutoMode(false)
                    --Pause the SML
                    oSML:SetPaused(true)
                    --Note - is a graphical bug where a paused SML will appear to still use resources - the below commented out code was used to confirm that it doesnt; a manual calculation was also done of energy usage which was consistent with the SML not using energy based on the total displayed energy usage
                    --[[if bDebugMessages == true then
            while M27UnitInfo.IsUnitValid(oSML) do
                LOG(sFunctionRef..': GameTime='..GetGameTimeSeconds()..'; SML GetConsumptionPerSecondMass='..oSML:GetConsumptionPerSecondMass())
                WaitSeconds(1)
            end
        end--]]

                    break
                end
            end
        end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitSeconds(1)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        if bDebugMessages == true then LOG(sFunctionRef..': Checking if SML is far enough along with its progress; Progress='..(oSML:GetWorkProgress() or 0)) end
        if oSML.GetWorkProgress and oSML:GetWorkProgress() >= 0.2 then
            if bDebugMessages == true then LOG(sFunctionRef..': SML has got far enough that we will proceed even if enemy builds SMD') end
            break
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function AssignActionToEngineer(aiBrain, oEngineer, iActionToAssign, tActionTargetLocation, oActionTargetObject, iConditionNumber, sBuildingBPRef)
    --If oActionTargetObject is specified, then will assist this (unless specifically coded an exception), otherwise will try and construct a new building
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'AssignActionToEngineer'
    M27Utilities.FunctionProfiler(sFunctionRef..iActionToAssign, M27Utilities.refProfilerStart)

    --if GetEngineerUniqueCount(oEngineer) == 58 and GetGameTimeSeconds() >= 2040 then bDebugMessages = true else bDebugMessages = false end


    if oEngineer then
        if M27UnitInfo.IsUnitValid(oEngineer) then
            --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
            if bDebugMessages == true then
                LOG(sFunctionRef..': Issuing clear commands to engineer with unique ref '..GetEngineerUniqueCount(oEngineer)..'; iActionToAssign='..iActionToAssign..'; tActionTargetLocation='..repru(tActionTargetLocation or {'nil'}))
                if oActionTargetObject then LOG('oActionTargetObject='..oActionTargetObject.UnitId..M27UnitInfo.GetUnitLifetimeCount(oActionTargetObject))
                else LOG('oActionTargetObject is nil') end
            end
            IssueClearCommands{oEngineer}
            if iActionToAssign == refActionSpare then
                IssueSpareEngineerAction(aiBrain, oEngineer)
                --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers, oUnitToBeDestroyed, iPrimaryEngineerCategoryBuilt)
                --Engineer may not be valid if we just gave a kill order
                if M27UnitInfo.IsUnitValid(oEngineer) then
                    UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, nil, false, iConditionNumber)
                end
            elseif iActionToAssign == refActionPlateauSpareAction then
                IssuePlateauSpareEngineerAction(aiBrain, oEngineer)
                UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, nil, false, iConditionNumber)
            else
                local bAreAssisting = false
                if iActionToAssign == refActionReclaimArea or iActionToAssign == refActionReclaimTrees then
                    tActionTargetLocation = M27Logic.ChooseReclaimTarget(oEngineer, (iActionToAssign == refActionReclaimTrees))
                    if M27Utilities.IsTableEmpty(tActionTargetLocation) == true then
                        --Get random position between 50 and 100 of base to attack-move to (30-80 if cant path to enemy base since means less likely to find somewhere)
                        local iDistanceMod = 0
                        if not(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]) then iDistanceMod = -20 end
                        tActionTargetLocation = AttackMoveToRandomPositionAroundBase(aiBrain, oEngineer, 100 + iDistanceMod, 50 + iDistanceMod)
                    else
                        IssueMove({ oEngineer }, tActionTargetLocation)
                    end
                    ForkThread(RegularlyCheckForNearbyReclaim, oEngineer, true)
                    UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tActionTargetLocation, false, iConditionNumber)
                elseif iActionToAssign == refActionPlateauReclaim then
                    --Should have already determined the reclaim target
                    IssueMove({oEngineer}, tActionTargetLocation)
                    ForkThread(RegularlyCheckForNearbyReclaim, oEngineer, true)
                    UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tActionTargetLocation, false, iConditionNumber)
                else
                    if oActionTargetObject then
                        if not(iActionToAssign == refActionReclaimArea) and not(iActionToAssign == refActionPlateauReclaim) and not(iActionToAssign == refActionReclaimTrees) and not(iActionToAssign == refActionBuildShield and not(EntityCategoryContains(categories.MOBILE, oActionTargetObject.UnitId))) then
                            if iActionToAssign == refActionReclaimUnit then
                                IssueReclaim({oEngineer}, oActionTargetObject)
                                --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers, oUnitToBeDestroyed, iPrimaryEngineerCategoryBuilt)
                                UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, nil, true, iConditionNumber, oActionTargetObject)
                                bAreAssisting = true
                            elseif iActionToAssign == refActionBuildT3MexOverT2 and M27UnitInfo.IsUnitValid(oActionTargetObject) and EntityCategoryContains(M27UnitInfo.refCategoryMex, oActionTargetObject.UnitId) then
                                --Redundancy - set the target location equal to the target object position
                                tActionTargetLocation = oActionTargetObject:GetPosition()
                                if bDebugMessages == true then LOG(sFunctionRef..': Have an action target object but the target is a mex so we dont want to assist it, instead its the target location') end
                            elseif iActionToAssign == refActionLoadOnTransport then
                                M27Transport.LoadEngineerOnTransport(aiBrain, oEngineer, oActionTargetObject)
                                UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, nil, true, iConditionNumber, oActionTargetObject)
                                bAreAssisting = true
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Are assisting an object') end
                                bAreAssisting = true
                                if oActionTargetObject.GetUnitId then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Telling engineer '..GetEngineerUniqueCount(oEngineer)..'to assist object '..oActionTargetObject.UnitId..M27UnitInfo.GetUnitLifetimeCount(oActionTargetObject)) end
                                    if oActionTargetObject.GetFractionComplete and oActionTargetObject:GetFractionComplete() < 1 then
                                        IssueRepair({ oEngineer}, oActionTargetObject)
                                    else
                                        IssueGuard({ oEngineer}, oActionTargetObject)
                                    end

                                    local bIgnoreLocation = false
                                    --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers, oUnitToBeDestroyed, iPrimaryEngineerCategoryBuilt)
                                    --If we are helping a building be constructed rather than assisting a unit then record the location; will assume if target is a factory or mex that are assisting, even though in some cases we will be building
                                    if EntityCategoryContains(categories.COMMAND + M27UnitInfo.refCategoryEngineer, oActionTargetObject.UnitId) then -- or iActionToAssign == refActionUpgradeBuilding or iActionToAssign == refActionAssistSMD or iActionToAssign == refActionAssistAirFactory then
                                        bIgnoreLocation = true
                                    else
                                        for _, iActionRef in tiEngiActionsThatDontBuild do
                                            if iActionRef == iActionToAssign then
                                                bIgnoreLocation = true
                                                break
                                            end
                                        end
                                    end
                                    if bIgnoreLocation then
                                        tActionTargetLocation = nil
                                    else tActionTargetLocation = oActionTargetObject:GetPosition()
                                    end

                                    --Do we want to clear the engineer after a while (e.g. if are assisting a factory)?  Note for shield assistance that separate logic is used to handle when to clear the engineer
                                    if iActionToAssign == refActionAssistAirFactory then
                                        ForkThread(DelayedSpareEngineerClearAction, aiBrain, oEngineer, math.random(45,60))
                                    end

                                    UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tActionTargetLocation, true, iConditionNumber, oActionTargetObject)
                                else
                                    LOG('oActionTargetObject isnt a unit, will see if it has a subtable with a unit and use that (workaround for strange issue)')
                                    if oActionTargetObject[2] and oActionTargetObject[2].GetUnitId then
                                        LOG(sFunctionRef..': Have a valid unit in a subtable, so will make this the target')
                                        oActionTargetObject = oActionTargetObject[2]
                                    else
                                        bAreAssisting = false
                                        LOG(sFunctionRef..': Dont have a valid unit in a subtable, so will try and perform action without assisting')
                                    end
                                end
                            end
                        end
                    end
                    if bAreAssisting then
                        oEngineer[refoUnitBeingAssisted] = oActionTargetObject
                        if iActionToAssign == refActionAssistShield and EntityCategoryContains(M27UnitInfo.refCategoryFixedShield, oActionTargetObject.UnitId) then
                            if M27Utilities.IsTableEmpty(oActionTargetObject[reftAssistingEngineers]) then oActionTargetObject[reftAssistingEngineers] = {} end
                            oActionTargetObject[reftAssistingEngineers][GetEngineerUniqueCount(oEngineer)] = oEngineer
                            ForkThread(MonitorShieldHealth, aiBrain, oActionTargetObject) --Ensures engineers are paused until the shield is below x% health
                        end
                    else --Arent assisting anything
                        oEngineer[refoUnitBeingAssisted] = nil --redundancy
                        if bDebugMessages == true then
                            LOG(sFunctionRef .. ': Arent assisting so determine what to build based on action=' .. iActionToAssign)
                        end
                        --Get the building to construct, and the location to construct it at, factoring in adjacency if its not a mex/hydro
                        local iCategoryToBuild
                        local bConstructBuilding = true
                        local iCatToBuildBy
                        local tTargetLocation = tActionTargetLocation
                        local bQueueUpMultiple = false
                        local iMaxAreaToSearch = 60
                        local oUnitToBuildBy
                        local oTempUnit --Used to record unit that wants TMD, generic variable for if we want something else to store a unit reference
                        local bBuildCheapest = false
                        local bAbort = false
                        iCategoryToBuild = GetCategoryToBuildFromAction(iActionToAssign, nil, aiBrain)
                        if iCategoryToBuild == nil then
                            bConstructBuilding = false
                            M27Utilities.ErrorHandler('Couldnt get category to build for iActionToAssign=' .. iActionToAssign)
                        else
                            if iActionToAssign == refActionBuildMex then
                                --iCategoryToBuild = refCategoryT1Mex
                                bQueueUpMultiple = true
                                --Build t3 mex in some cases
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Building a mex; Engineer tech level=' .. M27UnitInfo.GetUnitTechLevel(oEngineer) .. '; Distance between target and base=' .. M27Utilities.GetDistanceBetweenPositions(tActionTargetLocation, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) .. '; Gross mass income=' .. aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] .. '; nearest threat=' .. aiBrain[M27Overseer.refiModDistFromStartNearestThreat])
                                end
                                if M27UnitInfo.GetUnitTechLevel(oEngineer) >= 3 and M27Utilities.GetDistanceBetweenPositions(tActionTargetLocation, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 60 and aiBrain[M27Overseer.refiModDistFromStartNearestThreat] >= 160 and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 3 then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Setting category to build to be a t3 mex')
                                    end
                                    iCategoryToBuild = M27UnitInfo.refCategoryT3Mex
                                end
                            elseif iActionToAssign == refActionBuildPlateauMex then
                                bQueueUpMultiple = true
                                --(Dont want to build t3 mex even if have T3 engi)
                            elseif iActionToAssign == refActionBuildT3MexOverT2 then
                                bConstructBuilding = false --Wont want to construct immediately so want to avoid normal logic
                            elseif iActionToAssign == refActionBuildHydro then
                                if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] <= 11 then
                                    bBuildCheapest = true
                                end
                                --iCategoryToBuild = refCategoryHydro
                            elseif iActionToAssign == refActionBuildPower or iActionToAssign == refActionBuildSecondPower or iActionToAssign == refActionBuildThirdPower then

                                --iCategoryToBuild = refCategoryPower
                                if M27UnitInfo.GetUnitTechLevel(oEngineer) == 1 then
                                    iCatToBuildBy = refCategoryLandFactory + refCategoryAirFactory
                                    bQueueUpMultiple = true
                                    iMaxAreaToSearch = 20
                                elseif M27UnitInfo.GetUnitTechLevel(oEngineer) == 2 then
                                    iCatToBuildBy = refCategoryAirFactory + M27UnitInfo.refCategoryT2Radar
                                    iMaxAreaToSearch = 35
                                    if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] < 150 then
                                        iMaxAreaToSearch = 30
                                    end
                                else
                                    iCatToBuildBy = refCategoryAirFactory + M27UnitInfo.refCategoryT3Radar + M27UnitInfo.refCategorySMD + M27UnitInfo.refCategoryFixedT3Arti
                                    iMaxAreaToSearch = 50
                                    if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] < 300 then
                                        iMaxAreaToSearch = 40
                                    end --If not got t3 power yet then would rather build closer to base without adjacency than wait a while before building
                                end

                                if iActionToAssign == refActionBuildSecondPower or iActionToAssign == refActionBuildThirdPower then
                                    iMaxAreaToSearch = 50
                                end
                            elseif iActionToAssign == refActionBuildT3ArtiPower then
                                bQueueUpMultiple = true
                                iMaxAreaToSearch = 1
                            elseif iActionToAssign == refActionBuildLandFactory or iActionToAssign == refActionBuildPlateauFactory then
                                --iCategoryToBuild = refCategoryLandFactory
                                iCatToBuildBy = refCategoryT1Mex
                            elseif iActionToAssign == refActionBuildSecondLandFactory then
                                --Dont build next to anything - we just want a factory quickly
                            elseif iActionToAssign == refActionBuildAirFactory or iActionToAssign == refActionBuildSecondAirFactory then
                                --iCategoryToBuild = refCategoryAirFactory
                                --HydroNearACUAndBase(aiBrain, bNearBaseOnlyCheck, bAlsoReturnHydroTable)
                                if M27Conditions.HydroNearACUAndBase(aiBrain, true, false) == true then
                                    --Need to decide what power to build by, as adjacency code requires a fixed building size (whereas T2+Hydro is dif to T3 power)
                                    --for now simple check - if have t3 power, then build by t3 power; otherwise build by hydro+t2 power (which have the same size)
                                    if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Power) > 0 then
                                        iCatToBuildBy = M27UnitInfo.refCategoryT3Power
                                    else
                                        iCatToBuildBy = refCategoryHydro + M27UnitInfo.refCategoryT2Power
                                    end
                                else
                                    if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Power) > 0 then
                                        iCatToBuildBy = M27UnitInfo.refCategoryT3Power
                                    elseif aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Power) > 0 then
                                        iCatToBuildBy = M27UnitInfo.refCategoryT2Power
                                    else
                                        iCatToBuildBy = M27UnitInfo.refCategoryT1Power
                                    end
                                end
                            elseif iActionToAssign == refActionBuildEnergyStorage then
                                --iCategoryToBuild = refCategoryEnergyStorage
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Decided on category to build for energy storage')
                                end
                            elseif iActionToAssign == refActionBuildAA then
                                --Use default values - want quite a large search area so hopefully static AA is more spread out
                            elseif iActionToAssign == refActionBuildEmergencyPD then
                                local sBPToBuild = M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, iCategoryToBuild, oEngineer)
                                if __blueprints[sBPToBuild].Physics.SkirtSizeX <= 1 then
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Building emergency PD, will try and build T1 PD followed by walls')
                                    end
                                    bQueueUpMultiple = true
                                elseif bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Building emergency PD but not building T1 PD so wont build walls')
                                end
                                iMaxAreaToSearch = 30
                            elseif iActionToAssign == refActionBuildAirStaging then
                                --iCategoryToBuild = refCategoryAirStaging
                            elseif iActionToAssign == refActionBuildSMD then
                                iCatToBuildBy = M27UnitInfo.refCategoryT3Power
                                iMaxAreaToSearch = 70
                            elseif iActionToAssign == refActionBuildTML then
                                --Use default values
                            elseif iActionToAssign == refActionBuildTMD then
                                --Will use custom logic
                                iMaxAreaToSearch = 20
                                if EntityCategoryContains(categories.AEON, oEngineer.UnitId) then
                                    iMaxAreaToSearch = 10
                                end

                                --Adjust the target based on the enemy TML location
                                local tLocationToMoveTowards
                                local bMoveTowardsTarget = true
                                if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign]) then
                                    local tAssumedUnitWantingProtection = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryProtectFromTML, tTargetLocation, 1, 'Ally')
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Trying to build TMD, iMaxAreaToSearch=' .. iMaxAreaToSearch .. '; Is tAssumedUnitWantingProtection empty=' .. tostring(M27Utilities.IsTableEmpty(tAssumedUnitWantingProtection)))
                                    end
                                    if M27Utilities.IsTableEmpty(tAssumedUnitWantingProtection) == false then
                                        oTempUnit = tAssumedUnitWantingProtection[1]
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': oTempUnit=' .. oTempUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oTempUnit) .. '; is the table of tml threats empty=' .. tostring(M27Utilities.IsTableEmpty(oTempUnit[M27UnitInfo.reftTMLThreats])))
                                        end
                                        if M27Utilities.IsTableEmpty(oTempUnit[M27UnitInfo.reftTMLThreats]) == false then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': oTempUnit has some TML threats identified, will get the first valid TML and use that as the one we want to protect from')
                                            end
                                            for sTMLRef, oTML in tAssumedUnitWantingProtection[1][M27UnitInfo.reftTMLThreats] do
                                                if M27UnitInfo.IsUnitValid(oTML) then
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Have TML ' .. oTML.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oTML) .. ' that is still valid identified, will see if we have TMD protecting from it')
                                                    end
                                                    --Do we already have a valid TMD that protects from this?
                                                    if not (oTempUnit[M27UnitInfo.reftTMLDefence] and M27UnitInfo.IsUnitValid(oTempUnit[M27UnitInfo.reftTMLDefence][oTML.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oTML)])) then
                                                        tLocationToMoveTowards = oTML:GetPosition()
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': We arent protected from this TML so returning its position, tLocationToMoveTowards=' .. repru(tLocationToMoveTowards))
                                                        end
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    if not (tLocationToMoveTowards) then
                                        M27Utilities.ErrorHandler('Backup logic - cant find any units wanting protection from TML; if can find any enemy TML within 300 of the target location then will pick this as the location to move towards.  See log for more info')
                                        local tNearbyTML = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryTML, tTargetLocation, 300, 'Enemy')
                                        if M27Utilities.IsTableEmpty(tNearbyTML) then
                                            bAbort = true
                                        else
                                            tLocationToMoveTowards = M27Utilities.GetNearestUnit(tNearbyTML):GetPosition()
                                        end
                                    end
                                else
                                    bMoveTowardsTarget = false
                                end
                                if not (bAbort) and bMoveTowardsTarget then
                                    tTargetLocation = M27Utilities.MoveInDirection(tTargetLocation, M27Utilities.GetAngleFromAToB(tTargetLocation, tLocationToMoveTowards), iMaxAreaToSearch, true)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': New tTargetLocation after trying to move towards the TML by ' .. iMaxAreaToSearch .. ' =' .. repru(tTargetLocation))
                                    end
                                end
                            elseif iActionToAssign == refActionBuildT1Radar then
                                iCatToBuildBy = M27UnitInfo.refCategoryT1Power
                            elseif iActionToAssign == refActionBuildT2Radar then
                                iCatToBuildBy = M27UnitInfo.refCategoryT2Power
                            elseif iActionToAssign == refActionBuildT3Radar then
                                iCatToBuildBy = M27UnitInfo.refCategoryT3Power
                                iMaxAreaToSearch = 70
                            elseif iActionToAssign == refActionAssistSMD or iActionToAssign == refActionAssistNuke then
                                bConstructBuilding = false
                            elseif iActionToAssign == refActionAssistAirFactory then
                                bConstructBuilding = false
                            elseif iActionToAssign == refActionAssistShield then
                                bConstructBuilding = false
                            elseif iActionToAssign == refActionBuildExperimental or iActionToAssign == refActionBuildSecondExperimental then
                                if iCategoryToBuild == M27UnitInfo.refCategorySML or iCategoryToBuild == M27UnitInfo.refCategoryFixedT3Arti then
                                    iCatToBuildBy = M27UnitInfo.refCategoryT3Power
                                    if aiBrain[M27Overseer.refbDefendAgainstArti] then iCatToBuildBy = iCatToBuildBy + M27UnitInfo.refCategoryFixedShield end
                                end
                                iMaxAreaToSearch = 60
                                --Cybran - build monkeylord instead of megalith as first choice experimental
                                if iCategoryToBuild == M27UnitInfo.refCategoryLandExperimental and M27Conditions.LifetimeBuildCountLessThan(aiBrain, iCategoryToBuild, 1) then
                                    bBuildCheapest = true
                                end
                            elseif iActionToAssign == refActionBuildMassStorage then
                                bQueueUpMultiple = true
                                iMaxAreaToSearch = 5
                            elseif iActionToAssign == refActionBuildT1Sonar or iActionToAssign == refActionBuildT2Sonar then
                            elseif iActionToAssign == refActionBuildShield then
                                oUnitToBuildBy = oActionTargetObject
                                if oUnitToBuildBy[refbNeedsLargeShield] then
                                    iCategoryToBuild = M27UnitInfo.refCategoryFixedShield * categories.TECH3 - categories.CYBRAN * categories.CQUEMOV
                                end
                            elseif iActionToAssign == refActionFortifyFirebase then
                                iMaxAreaToSearch = math.min(iMaxAreaToSearch, 12)
                            else
                                M27Utilities.ErrorHandler('Need to add code for action=' .. iActionToAssign .. '; will assume will use default values and have something to build')
                                --bConstructBuilding = false
                            end
                        end
                        if bAbort then
                            aiBrain[refiTimeOfLastFailure][iActionToAssign] = GetGameTimeSeconds()
                        else

                            if bConstructBuilding == true then
                                if not (iCategoryToBuild) then
                                    M27Utilities.ErrorHandler('Are about to try and build without having a category to build')
                                else
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. '; iCategoryToBuild is not nil. Blueprints that match this category='..repru(EntityCategoryGetUnitList(iCategoryToBuild)))
                                    end
                                end
                                --If have any queueupmultiple orders where we want to give them all in one go then disable this part of the logic
                                if bQueueUpMultiple and (iActionToAssign == refActionBuildT3ArtiPower) then
                                    --Set target location to dummy value so the next section doesnt error out
                                    if not (tTargetLocation) then
                                        tTargetLocation = oEngineer:GetPosition()
                                    end
                                else
                                    --Build the first structure (including for queueupmultiple where not using special logic
                                    --BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild,                iMaxAreaToSearch, iCatToBuildBy, tAlternativePositionToLookFrom, bLookForPartCompleteBuildings, bLookForQueuedBuildings, oUnitToBuildBy, bNeverBuildRandom, iOptionalCategoryForStructureToBuild, bBuildCheapestStructure, iOptionalEngiActionRef)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': About to tell engineer to build the category using the location ' .. repru(tTargetLocation) .. ' as a starting point')
                                    end
                                    tTargetLocation = BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tTargetLocation, nil, nil, oUnitToBuildBy, nil, nil, bBuildCheapest, iActionToAssign)
                                    if M27Utilities.IsTableEmpty(tTargetLocation) == true and iActionToAssign == refActionBuildShield then
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Failed to build a shield, oUnitToBuildBy[refbNeedsLargeShield]=' .. tostring((oUnitToBuildBy[refbNeedsLargeShield] or false)))
                                        end
                                        --Are we trying to build a shield? If so then try building a T3 shield if we hadnt already flagged to try this
                                        if oUnitToBuildBy[refbNeedsLargeShield] then
                                            --Couldnt get shield coverage even with a large shield so remove from list of units to be shielded
                                            for iUnit, oUnit in aiBrain[reftUnitsWantingFixedShield] do
                                                if oUnit == oUnitToBuildBy then
                                                    table.remove(aiBrain[reftUnitsWantingFixedShield], iUnit)
                                                    break
                                                end
                                            end
                                        else
                                            oUnitToBuildBy[refbNeedsLargeShield] = true --Next engineer will try with T3 shield (dont want to try this time as may be dealing with a T2 engi)
                                        end
                                    end
                                    if M27Utilities.IsTableEmpty(tTargetLocation) == true then
                                        --Did we fail to build a TMD? If so then flag that we cant build TMD for the unit we just tried
                                        if oTempUnit and iActionToAssign == refActionBuildTMD then
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Failed to find somewhere to build TMD, so will flag for oTempUnit=' .. oTempUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oTempUnit) .. ' that we arent to try and build tmd by it again')
                                            end
                                            oTempUnit[M27UnitInfo.refbCantBuildTMDNearby] = true
                                            aiBrain[reftUnitsWantingTMD][oTempUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oTempUnit)] = nil
                                        end

                                        M27Utilities.ErrorHandler('Failed to find a location to build at for oEngineer UC=' .. GetEngineerUniqueCount(oEngineer) .. '; Action=' .. iActionToAssign .. '; , switching to backup engineer logic.  This message is expected if there are lots of buildings near the target', true)
                                        aiBrain[refiTimeOfLastFailure][iActionToAssign] = GetGameTimeSeconds()
                                        tTargetLocation = oEngineer:GetPosition()
                                        iActionToAssign = refActionSpare
                                        IssueSpareEngineerAction(aiBrain, oEngineer)
                                        --Engineer may not be valid if we just gave a kill order
                                        if M27UnitInfo.IsUnitValid(oEngineer) then

                                            --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers, oUnitToBeDestroyed, iPrimaryEngineerCategoryBuilt)
                                            UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, nil, false, iConditionNumber)
                                        end
                                        bQueueUpMultiple = false

                                    else
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Found a valid location, about to call update tracker for tTargetLocation=' .. repru(tTargetLocation))
                                        end
                                        UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, false, iConditionNumber, nil, nil, nil, iCategoryToBuild)
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Will give results for if we have flagged anywhere in a 3x3 grid centred on target location with the same action (whether this is correct will depend on the building size - would expect at least the centre point to be flagged')
                                            local sLocationRef
                                            for iAdjX = -1, 1, 1 do
                                                for iAdjZ = -1, 1, 1 do
                                                    sLocationRef = M27Utilities.ConvertLocationToReference({ tTargetLocation[1] + iAdjX, tTargetLocation[2], tTargetLocation[3] + iAdjZ })
                                                    --reftEngineerAssignmentsByLocation --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the engineer unique ref assigned to this location; returns the engineer object
                                                    LOG('sLocationRef=' .. sLocationRef .. ': Is the table of building assignments for this location empty? =' .. tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef])))
                                                end
                                            end
                                        end
                                    end
                                end

                                if bQueueUpMultiple == true and M27Utilities.IsTableEmpty(tTargetLocation) == false then
                                    iMaxAreaToSearch = iMaxAreaToSearch - 5
                                    if iActionToAssign == refActionBuildMex or iActionToAssign == refActionBuildPlateauMex then
                                        --Get nearest mex in pathing group and see if its close enough
                                        local tMexesToIgnore = {}
                                        local iCurMexCount = 1
                                        local iMaxMexCount = 3
                                        local iCurLoopCount = 0
                                        local tNearestMex
                                        while iCurMexCount < iMaxMexCount do
                                            iCurLoopCount = iCurLoopCount + 1
                                            if iCurLoopCount > iCurMexCount then
                                                break
                                            end
                                            tMexesToIgnore[iCurMexCount] = { tTargetLocation[1], tTargetLocation[2], tTargetLocation[3] }
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Looking for extra mexes to build; tMexesToIgnore=' .. repru(tMexesToIgnore) .. '; tTargetLocation=' .. repru(tTargetLocation))
                                            end
                                            --GetNearestMexToUnit(oBuilder, bCanBeBuiltOnByAlly, bCanBeBuiltOnByEnemy, bCanBeQueuedToBeBuilt, iMaxSearchRangeMod, tStartPositionOverride, tMexesToIgnore)
                                            tNearestMex = M27MapInfo.GetNearestMexToUnit(oEngineer, false, false, false, iMaxAreaToSearch, tTargetLocation, tMexesToIgnore)
                                            if tNearestMex then
                                                tTargetLocation = tNearestMex
                                                --BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tAlternativePositionToLookFrom, bLookForPartCompleteBuildings, bLookForQueuedBuildings, oUnitToBuildBy, bNeverBuildRandom, iOptionalCategoryForStructureToBuild, bBuildCheapestStructure, iOptionalEngiActionRef)
                                                tTargetLocation = BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tTargetLocation, nil, nil, nil, true, nil, nil, iActionToAssign)
                                                if M27Utilities.IsTableEmpty(tTargetLocation) == false then
                                                    --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers, oUnitToBeDestroyed, iPrimaryEngineerCategoryBuilt)
                                                    UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, false, iConditionNumber, nil, true, nil, iCategoryToBuild)
                                                    iCurMexCount = iCurMexCount + 1
                                                end
                                            end
                                        end

                                        --Check for reclaim as well, as likely to be travelling away from base
                                        ForkThread(RegularlyCheckForNearbyReclaim, oEngineer)
                                    elseif iActionToAssign == refActionBuildPower or iActionToAssign == refActionBuildSecondPower or iActionToAssign == refActionBuildThirdPower then
                                        if EntityCategoryContains(categories.TECH1, oEngineer.UnitId) and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 16 then
                                            --Dont want to queue up multiple T2 or T3 as theyre much more expensive, and also only want to start queing once we have a base level of power
                                            if M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), tTargetLocation) <= 10 then
                                                --TODO - improve movenearconstruction so dont need above line
                                                local iMaxCount = 3
                                                local iCurCount = 1
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Last T1 power is within 10 of builder, so will queue up more; iCurCount=' .. iCurCount)
                                                end
                                                while iCurCount < iMaxCount do
                                                    --BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tAlternativePositionToLookFrom, bLookForPartCompleteBuildings, bLookForQueuedBuildings, oUnitToBuildBy, bNeverBuildRandom, iOptionalCategoryForStructureToBuild, bBuildCheapestStructure, iOptionalEngiActionRef)
                                                    tTargetLocation = BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tTargetLocation, nil, nil, nil, nil, nil, nil, iActionToAssign)
                                                    if M27Utilities.IsTableEmpty(tTargetLocation) == false then
                                                        --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers, oUnitToBeDestroyed, iPrimaryEngineerCategoryBuilt)
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': Found location for an extra T1 power to be built; tTargetLocation=' .. repru(tTargetLocation))
                                                        end
                                                        UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, false, iConditionNumber, nil, true, nil, iCategoryToBuild)
                                                        iCurCount = iCurCount + 1
                                                    else
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                    elseif iActionToAssign == refActionBuildMassStorage then

                                        local iMaxCount = 4
                                        local iCurCount = 1
                                        local iLoopCount = 0
                                        while iCurCount < iMaxCount do
                                            iLoopCount = iLoopCount + 1
                                            if iLoopCount > 100 then
                                                M27Utilities.ErrorHandler('Infinite loop')
                                                break
                                            end
                                            --Do we have other locations near the current location where storage would be adjacent to a mex?
                                            local tNearestStorage
                                            local iNearestStorage = 1000
                                            local iCurDistance
                                            local tStorage
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': About to loop through all storage locations to see if we want to queue up more of them; repr of storage locations=' .. repru(aiBrain[M27EconomyOverseer.reftMassStorageLocations]))
                                            end
                                            for iStorage, tSubtable in aiBrain[M27EconomyOverseer.reftMassStorageLocations] do
                                                tStorage = tSubtable[M27EconomyOverseer.reftStorageSubtableLocation]
                                                iCurDistance = M27Utilities.GetDistanceBetweenPositions(tTargetLocation, tStorage)
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': iStorage=' .. iStorage .. '; iCurDistance=' .. iCurDistance .. '; tStorage=' .. repru(tStorage))
                                                end
                                                if iCurDistance <= math.min(iNearestStorage, 8) and iCurDistance > 0 then
                                                    --Have we queued up anything for this location already?

                                                    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][M27Utilities.ConvertLocationToReference(tStorage)]) then
                                                        iNearestStorage = iCurDistance
                                                        tNearestStorage = tStorage
                                                    elseif bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Have already got something queued in this location so dont want to build here')
                                                    end
                                                end
                                            end
                                            if tNearestStorage then
                                                --BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tAlternativePositionToLookFrom, bLookForPartCompleteBuildings, bLookForQueuedBuildings, oUnitToBuildBy, bNeverBuildRandom, iOptionalCategoryForStructureToBuild, bBuildCheapestStructure, iOptionalEngiActionRef)
                                                tTargetLocation = BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tNearestStorage, nil, nil, nil, true, nil, nil, iActionToAssign)
                                                if M27Utilities.IsTableEmpty(tTargetLocation) == false then
                                                    --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers, oUnitToBeDestroyed, iPrimaryEngineerCategoryBuilt)
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Found location for an extra T1 power to be built; tTargetLocation=' .. repru(tTargetLocation))
                                                    end
                                                    UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, false, iConditionNumber, nil, true, nil, iCategoryToBuild)
                                                    iCurCount = iCurCount + 1
                                                else
                                                    --Couldnt build here for some reason so abort
                                                    break
                                                end
                                            else
                                                if bDebugMessages == true then
                                                    LOG(sFunctionRef .. ': Couldnt find any more storage locations')
                                                end
                                                --No storage locations so stop
                                                break
                                            end
                                        end
                                    elseif iActionToAssign == refActionBuildT3ArtiPower then
                                        --Special logic - base the locations on the Arti unit itself
                                        --if oEngineer:IsUnitState('Building') or oEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Clearing engineer ' .. GetEngineerUniqueCount(oEngineer) .. 'LC=' .. M27UnitInfo.GetUnitLifetimeCount(oEngineer) .. ' actions and will then loop through every power that want and tell it to build')
                                        end
                                        IssueClearCommands({ oEngineer })
                                        ClearEngineerActionTrackers(aiBrain, oEngineer, true)
                                        for iUnit, oUnit in aiBrain:GetListOfUnits(M27UnitInfo.refCategoryFixedT3Arti, false, false) do
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Considering adjacency locations for T3 Arti=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit))
                                            end
                                            if M27Utilities.IsTableEmpty(oUnit[M27UnitInfo.reftAdjacencyPGensWanted]) == false then
                                                for iSubtable, tSubtable in oUnit[M27UnitInfo.reftAdjacencyPGensWanted] do
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Arti=' .. oUnit.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oUnit) .. '; iSubtable=' .. iSubtable .. '; tSubtable=' .. repru(tSubtable))
                                                    end
                                                    --if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][M27Utilities.ConvertLocationToStringRef(tSubtable[M27UnitInfo.refiSubrefBuildLocation])]) then
                                                    if bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Will try and build PGen at ' .. repru(tSubtable[M27UnitInfo.refiSubrefBuildLocation]))
                                                    end

                                                    --BuildStructureAtLocation(aiBrain, oEngineer, iCategoryToBuild, iMaxAreaToSearch, iCatToBuildBy, tAlternativePositionToLookFrom, bLookForPartCompleteBuildings, bLookForQueuedBuildings, oUnitToBuildBy, bNeverBuildRandom, iOptionalCategoryForStructureToBuild, bBuildCheapestStructure, iOptionalEngiActionRef)
                                                    tTargetLocation = BuildStructureAtLocation(aiBrain, oEngineer, tSubtable[M27UnitInfo.refiSubrefCategory], iMaxAreaToSearch, nil, tSubtable[M27UnitInfo.refiSubrefBuildLocation], false, false, nil, true, nil, nil, iActionToAssign)
                                                    if tTargetLocation then
                                                        if bDebugMessages == true then
                                                            LOG(sFunctionRef .. ': Successfully sent order to build PGen, will update engi trackers')
                                                        end
                                                        UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, false, iConditionNumber, nil, true, nil, tSubtable[M27UnitInfo.refiSubrefCategory])
                                                    elseif bDebugMessages == true then
                                                        LOG(sFunctionRef .. ': Failed to build pgen at tTargetLocation=' .. repru(tTargetLocation) .. '; Blueprint probably attempted=' .. M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, iCategoryToBuild, oEngineer) .. '; aiBrain:CanBuildStructureAt=' .. tostring(aiBrain:CanBuildStructureAt(M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, iCategoryToBuild, oEngineer), tTargetLocation)))
                                                    end
                                                    --end
                                                end
                                            elseif bDebugMessages == true then
                                                LOG(sFunctionRef .. ': No adjacency PGen locations, wont build anything')
                                            end
                                        end
                                    elseif iActionToAssign == refActionBuildEmergencyPD then

                                        --Build walls around the PD (queue up and dont even bother checking if we can build or not)
                                        local sWall = M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, M27UnitInfo.refCategoryWall, oEngineer)
                                        local tWallLocation
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Will try and build walls with blueprint ' .. sWall .. '; around target location ' .. repru(tTargetLocation))
                                        end
                                        for iAdjustX = -1, 1 do
                                            for iAdjustZ = -1, 1 do
                                                if not (iAdjustX == 0 and iAdjustZ == 0) then
                                                    tWallLocation = { tTargetLocation[1] + iAdjustX, 0, tTargetLocation[3] + iAdjustZ }
                                                    tWallLocation[2] = GetTerrainHeight(tWallLocation[1], tWallLocation[3])
                                                    IssueBuildMobile({ oEngineer }, tWallLocation, sWall, {})
                                                    UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tWallLocation, false, iConditionNumber, nil, true, nil, iCategoryToBuild)
                                                end
                                            end
                                        end

                                    else
                                        --WARNING: If add in any new queue'd actions, then make sure update ClearEngineerActionTrackers as it will only cycle through location tables for mex and power (for performance reasons)
                                        --Alternatively, define for each action if we sometimes might queue it
                                        M27Utilities.ErrorHandler('Need to add code for this action to queue up multiple')
                                    end
                                end
                            else
                                --Not constructing anything, consider other actions
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': Dont have anything to build, so check for reclaim order')
                                end
                                if iActionToAssign == refActionReclaimArea or iActionToAssign == refActionReclaimTrees or iActionToAssign == refActionPlateauReclaim then
                                    IssueAggressiveMove({ oEngineer }, tTargetLocation)
                                    --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers)
                                    UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, false, iConditionNumber)
                                    local sLocationRef = M27Utilities.ConvertLocationToReference(tTargetLocation)
                                    aiBrain[reftSpareEngineerAttackMoveTimeByLocation][sLocationRef] = GetGameTimeSeconds()
                                elseif iActionToAssign == refActionBuildT3MexOverT2 then
                                    --Want to move near the location first, wait for it to be ctrl-Kd, and then build

                                    --First make sure we can build a T3 mex with this engineer (e.g. in case unit restrictions are active or somethign unexpected has happened)
                                    if M27FactoryOverseer.GetBlueprintsThatCanBuildOfCategory(aiBrain, M27UnitInfo.refCategoryT3Mex, oEngineer) then

                                        --UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, bAreAssisting, iConditionNumber, oUnitToAssist, bDontClearExistingTrackers, oUnitToBeDestroyed)
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Are trying to build T3 mex, and have been flagged that we arent assisting anything. tTargetLocation=' .. repru((tTargetLocation or { 'nil' })) .. '; Engi location=' .. repru(oEngineer:GetPosition()))
                                        end
                                        if M27UnitInfo.IsUnitValid(oActionTargetObject) == false then
                                            M27Utilities.ErrorHandler('Dont have a target mex to be replaced')
                                        else
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. 'L Will update the tracker, with an oActionTargetObject object that has a position=' .. repru(oActionTargetObject:GetPosition()))
                                            end
                                            UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, tTargetLocation, false, iConditionNumber, nil, false, oActionTargetObject, M27UnitInfo.refCategoryT3Mex)
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef .. ': Have action to build T3 over T2, oEngineer UC=' .. GetEngineerUniqueCount(oEngineer))
                                                if M27UnitInfo.IsUnitValid(oActionTargetObject) then
                                                    LOG('oActionTargetObject=' .. oActionTargetObject.UnitId .. M27UnitInfo.GetUnitLifetimeCount(oActionTargetObject))
                                                else
                                                    LOG('No oActionTargetObject')
                                                end
                                            end

                                            ForkThread(ReplaceT2WithT3Monitor, aiBrain, oEngineer, oActionTargetObject)
                                        end
                                    else
                                        M27Utilities.ErrorHandler('Unable to build a T3 mex with engineer ' .. oEngineer.UnitId .. GetEngineerUniqueCount(oEngineer) .. '; either unit restrictions are active or something has gone wrong with the code', true)
                                        aiBrain[refiTimeOfLastFailure][iActionToAssign] = GetGameTimeSeconds()
                                        IssueSpareEngineerAction(aiBrain, oEngineer)
                                        --Engineer may not be valid if we just gave a kill order
                                        if M27UnitInfo.IsUnitValid(oEngineer) then
                                            UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, nil, false, iConditionNumber)
                                        end
                                    end
                                else
                                    if iActionToAssign == refActionReclaimUnit then
                                        M27Utilities.ErrorHandler('No reclaim unit logic activated so may be missing a valid target, will issue a spare action', true)
                                    end
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Nothing to build or reclaim, will issue spare action instead')
                                    end
                                    IssueSpareEngineerAction(aiBrain, oEngineer)
                                    --Engineer may not be valid if we just gave a kill order
                                    if M27UnitInfo.IsUnitValid(oEngineer) then
                                        UpdateEngineerActionTrackers(aiBrain, oEngineer, iActionToAssign, nil, false, iConditionNumber)
                                    end
                                end
                            end
                        end
                    end
                end
                --Not a spare action - if upgrading a building then need to check if should reset after a short time period
                if iActionToAssign == refActionUpgradeBuilding or iActionToAssign == refActionUpgradeHQ then
                    ForkThread(UpgradeBuildingActionCompleteChecker, aiBrain, oEngineer, oActionTargetObject)
                end
            end

        else
            if not(oEngineer.UnitId) and not(oEngineer.GetUnitId) then
                M27Utilities.ErrorHandler('oEngineer isnt a unit; Action='..(iActionToAssign or 'nil')..'; iConditionNumber='..(iConditionNumber or 'nil')..'; tActionTargetLocation='..repru((tActionTargetLocation or {'nil'})))
                if bDebugMessages == true then
                    LOG(sFunctionRef..': Will debug array for oEngineer')
                    M27Utilities.DebugArray(oEngineer)
                    if oEngineer.UnitId then LOG(sFunctionRef..': UnitId='..oEngineer.UnitId) end
                    if oEngineer.M27LifetimeUnitCount then LOG(sFunctionRef..': M27LifetimeUnitCount='..oEngineer.M27LifetimeUnitCount) end
                end
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Engineer isnt valid but it has a unit ID; .Dead='..tostring(oEngineer.Dead)) end
            end
        end
    else
        M27Utilities.ErrorHandler('oEngineer is nil')
    end
    M27Utilities.FunctionProfiler(sFunctionRef..iActionToAssign, M27Utilities.refProfilerEnd)
end

function FilterLocationsBasedOnDistanceToEnemy(aiBrain, tLocationsToFilter, iMaxPercentageOfWayTowardsEnemy, bSortTable)
    --Returns {} if cant find any
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'FilterLocationsBasedOnDistanceToEnemy'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tRevisedLocations = {}
    --local tNearestLocation = {}
    if bDebugMessages == true then LOG(sFunctionRef..': Start; about to filter through '..table.getn(tLocationsToFilter)..' locations') end
    if M27Utilities.IsTableEmpty(tLocationsToFilter) == false then
        local iCurPercentageDistance, iCurDistanceToEnemy, iCurDistanceToStart
        local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
        local tEnemyStartPosition = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
        local iValidLocationCount = 0
        local iClosestDistance = 1000
        if M27Utilities.IsTableEmpty(tStartPosition) == false and M27Utilities.IsTableEmpty(tEnemyStartPosition) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Just before main loop; tStartPosition='..repru(tStartPosition)..'; tEnemyStartPosition='..repru(tEnemyStartPosition)..'; our startposition number='..aiBrain.M27StartPositionNumber..'; enemy start position number='..M27Logic.GetNearestEnemyStartNumber(aiBrain)) end
            for iLocation, tLocation in tLocationsToFilter do
                iCurDistanceToEnemy = M27Utilities.GetDistanceBetweenPositions(tLocation, tEnemyStartPosition)
                iCurDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tLocation, tStartPosition)
                iCurPercentageDistance = iCurDistanceToStart / (iCurDistanceToEnemy + iCurDistanceToStart)
                if iCurPercentageDistance <= iMaxPercentageOfWayTowardsEnemy then
                    iValidLocationCount = iValidLocationCount + 1
                    tRevisedLocations[iValidLocationCount] = tLocation
                end
                if bDebugMessages == true then LOG(sFunctionRef..': LocationRef='..M27Utilities.ConvertLocationToReference(tLocation)..'; iCurDistanceToEnemy='..iCurDistanceToEnemy..'; iCurDistanceToStart='..iCurDistanceToStart..'; iCurPercentageDistance='..iCurPercentageDistance..'; iValidLocationCount='..iValidLocationCount) end
            end
        else
            M27Utilities.ErrorHandler('tStartPosition or tEnemyStartPosition is empty')
        end
    else
        M27Utilities.ErrorHandler('tLocationsToFilter is empty')
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tRevisedLocations--, tNearestLocation
end

function FilterLocationsBasedOnIntelPathCoverage(aiBrain, tLocationsToFilter, bNOTYETCODEDAlsoReturnClosest, bTableOfObjectsNotLocations)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'FilterLocationsBasedOnIntelPathCoverage'

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tFilteredLocations = {}
    if bTableOfObjectsNotLocations == nil then bTableOfObjectsNotLocations = false end
    if M27Utilities.IsTableEmpty(tLocationsToFilter) == true then
        M27Utilities.ErrorHandler('tLocationsToFilter are empty')
    else
        local iValidLocationCount = 0
        local bInIntelLine
        for iLocation, tLocation in tLocationsToFilter do
            if bTableOfObjectsNotLocations == true then
                bInIntelLine = M27Conditions.IsLocationWithinIntelPathLine(aiBrain, tLocation:GetPosition())
            else
                if bDebugMessages == true then LOG(sFunctionRef..': Checking if tLocation '..repru(tLocation)..' is within intel path line') end
                bInIntelLine = M27Conditions.IsLocationWithinIntelPathLine(aiBrain, tLocation)
            end
            if bInIntelLine == false then
                --Do we have visual/intel coverage of the location anyway?
                if bTableOfObjectsNotLocations then bInIntelLine = M27Logic.GetIntelCoverageOfPosition(aiBrain, tLocation:GetPosition(), 40, true)
                else bInIntelLine = M27Logic.GetIntelCoverageOfPosition(aiBrain, tLocation, 40, true)
                end
            end
            if bInIntelLine == true then
                if bDebugMessages == true then LOG(sFunctionRef..': Location is within intel path line so recording') end
                iValidLocationCount = iValidLocationCount + 1
                tFilteredLocations[iValidLocationCount] = tLocation
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tFilteredLocations
end

function FilterLocationsBasedOnDefenceCoverage(aiBrain, tLocationsToFilter, bAlsoNeedIntelCoverage, bNOTYETCODEDAlsoReturnClosest, bTableOfObjectsNotLocations)
    --Intel coverage - achieved if either have intel coverage of the target, or intel path line is closer to enemy base than it
    --Returns nil if cant find anywhere
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'FilterLocationsBasedOnDefenceCoverage'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bTableOfObjectsNotLocations == nil then bTableOfObjectsNotLocations = false end
    local tFilteredLocations = {}
    if M27Utilities.IsTableEmpty(tLocationsToFilter) == true then
        M27Utilities.ErrorHandler('tLocationsToFilter doesnt contain values')
    else
        local iValidLocationCount = 0
        local iModDistanceFromStart
        local iDefenceCoverage = aiBrain[M27Overseer.refiModDistFromStartNearestOutstandingThreat]
        if iDefenceCoverage and iDefenceCoverage > 0 then
            for iLocation, tLocation in tLocationsToFilter do
                if bTableOfObjectsNotLocations == true then
                    iModDistanceFromStart = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tLocation:GetPosition())
                    if bDebugMessages == true then LOG(sFunctionRef..': bTableOfObjectsNotLocations='..tostring(bTableOfObjectsNotLocations)..'; Location='..repru(tLocation:GetPosition())..'; iModDistanceFromStart='..iModDistanceFromStart..'; iDefenceCoverage='..iDefenceCoverage) end
                else
                    iModDistanceFromStart = M27Overseer.GetDistanceFromStartAdjustedForDistanceFromMid(aiBrain, tLocation)
                    if bDebugMessages == true then LOG(sFunctionRef..': bTableOfObjectsNotLocations='..tostring(bTableOfObjectsNotLocations)..'; tLocation='..repru(tLocation)..'; iModDistanceFromStart='..iModDistanceFromStart..'; iDefenceCoverage='..iDefenceCoverage) end
                end

                if iModDistanceFromStart <= iDefenceCoverage then
                    iValidLocationCount = iValidLocationCount + 1
                    tFilteredLocations[iValidLocationCount] = tLocation
                    if bDebugMessages == true then LOG(sFunctionRef..': Location is valid, iValidLoctionCount='..iValidLocationCount) end
                end
            end
        end
    end

    if bAlsoNeedIntelCoverage == true and M27Utilities.IsTableEmpty(tFilteredLocations) == false and (M27Utilities.IsTableEmpty(ScenarioInfo.Options.RestrictedCategories) or not(M27UnitInfo.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryLandScout, 1))) then
        tFilteredLocations = FilterLocationsBasedOnIntelPathCoverage(aiBrain, tFilteredLocations, bNOTYETCODEDAlsoReturnClosest, bTableOfObjectsNotLocations)
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tFilteredLocations
end

function FilterLocationsBasedOnIfUnclaimed(aiBrain, tLocationsToFilter, bMexNotHydro)
    local sFunctionRef = 'FilterLocationsBasedOnIfUnclaimed'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tValidLocations = {}
    if M27Utilities.IsTableEmpty(tLocationsToFilter) == true then
        M27Utilities.ErrorHandler('tLocationsToFilter doesnt contain values')
    else
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        local sFunctionRef = 'FilterLocationsBasedOnIfUnclaimed'
        if bDebugMessages == true then LOG(sFunctionRef..': Start - have valid table of locations, with size='..table.getn(tLocationsToFilter)) end
        local iValidLocationCount = 0
        local bUnclaimed
        for iLocation, tLocation in tLocationsToFilter do
            --IsMexOrHydroUnclaimed(aiBrain, tResourcePosition, bMexNotHydro, bTreatEnemyBuildingAsUnclaimed, bTreatAllyBuildingAsUnclaimed, bTreatQueuedBuildingsAsUnclaimed)
            bUnclaimed = M27Conditions.IsMexOrHydroUnclaimed(aiBrain, tLocation, bMexNotHydro, false, false, true)
            if bDebugMessages == true then LOG(sFunctionRef..': iLocation='..iLocation..': tLocation='..repru(tLocation)..'; bUnclaimed='..tostring(bUnclaimed)) end
            if bUnclaimed == true then
                iValidLocationCount = iValidLocationCount + 1
                tValidLocations[iValidLocationCount] = tLocation
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tValidLocations
end

function ConvertUnclaimedConditionsToKey(bMexNotHydro, aiBrain, sPathing, iPathingGroup, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
    local sKey
    if bMexNotHydro then sKey = '1' else sKey = '0' end
    if bTreatEnemyMexAsUnclaimed then sKey = sKey..'1' else sKey = sKey..'0' end
    if bTreatOurOrAllyMexAsUnclaimed then sKey = sKey..'1' else sKey = sKey..'0' end
    if bTreatQueuedBuildingAsUnclaimed then sKey = sKey..'1' else sKey = sKey..'0' end
    sKey = sKey..sPathing..iPathingGroup
    return sKey
end

function GetUnclaimedMexOrHydro(bMexNotHydro, aiBrain, sPathing, iPathingGroup, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
    --Returns a table of mexes/hydros that are within the sPathing iPathingGroup which are unclaimed
    --returns {} if no such table
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetUnclaimedMexOrHydro'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local tAllLocationsInGroup
    if bTreatQueuedBuildingAsUnclaimed == nil then bTreatQueuedBuildingAsUnclaimed = bTreatOurOrAllyMexAsUnclaimed end
    local sKey = ConvertUnclaimedConditionsToKey(bMexNotHydro, aiBrain, sPathing, iPathingGroup, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
    if not(aiBrain[reftUnclaimedMexOrHydroByCondition][sKey]) then
        aiBrain[reftUnclaimedMexOrHydroByCondition][sKey] = {}
        aiBrain[reftUnclaimedMexOrHydroByCondition][sKey][reftResourceLocations] = {}
        aiBrain[reftUnclaimedMexOrHydroByCondition][sKey][refiTimeOfLastUpdate] = -1000
    end
    if GetGameTimeSeconds() - aiBrain[reftUnclaimedMexOrHydroByCondition][sKey][refiTimeOfLastUpdate] < 10 then
        tAllLocationsInGroup = aiBrain[reftUnclaimedMexOrHydroByCondition][sKey][reftResourceLocations]
    else
        --Do a full refresh
        if bMexNotHydro == false then
            if bDebugMessages == true then LOG(sFunctionRef..': sPathing='..sPathing..': iPathingGroup='..iPathingGroup) end
            tAllLocationsInGroup = M27MapInfo.GetHydroLocationsForPathingGroup(sPathing, iPathingGroup)
        else tAllLocationsInGroup = M27MapInfo.tMexByPathingAndGrouping[sPathing][iPathingGroup] --Stores position of each mex based on the segment that it's part of; [a][b][c]: [a] = pathing type ('Land' etc.); [b] = Segment grouping; [c] = Mex position
        end
        aiBrain[reftUnclaimedMexOrHydroByCondition][sKey][refiTimeOfLastUpdate] = GetGameTimeSeconds()
    end
    local iValidMexCount = 0
    local tUnclaimedLocations = {}
    if bDebugMessages == true then LOG(sFunctionRef..': Just before main loop, bMexNotHydro='..tostring(bMexNotHydro)..'; iPathingGroup='..iPathingGroup..'; sPathing='..sPathing..'; bTreatEnemyMexAsUnclaimed='..tostring(bTreatEnemyMexAsUnclaimed)..'; bTreatOurOrAllyMexAsUnclaimed='..tostring(bTreatOurOrAllyMexAsUnclaimed)..'; bTreatQueuedBuildingAsUnclaimed='..tostring(bTreatQueuedBuildingAsUnclaimed)) end
    if M27Utilities.IsTableEmpty(tAllLocationsInGroup) == false then
        for iMex, tMexPosition in tAllLocationsInGroup do
            if bDebugMessages == true then
                local bClaimedResult= M27Conditions.IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
                local sLocationRef = M27Utilities.ConvertLocationToReference(tMexPosition)
                LOG(sFunctionRef..': Checking if sLocation ref is unclaimed; sLocationRef='..sLocationRef..'; bClaimedResult='..tostring(bClaimedResult)..'; Brain start number='..aiBrain.M27StartPositionNumber)
            end
            if M27Conditions.IsMexUnclaimed(aiBrain, tMexPosition, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed) == true then
                --Is it in norush radius?
                if not(M27MapInfo.bNoRushActive) or M27Utilities.GetDistanceBetweenPositions(tMexPosition, aiBrain[M27MapInfo.reftNoRushCentre]) <= M27MapInfo.iNoRushRange then
                    iValidMexCount = iValidMexCount + 1
                    if bDebugMessages == true then
                        local sLocationRef = M27Utilities.ConvertLocationToReference(tMexPosition)
                        LOG(sFunctionRef..': iValidMexCount='..iValidMexCount..': Recorded mex with location '..sLocationRef..' as a valid mex. aiBrain startposition='..aiBrain.M27StartPositionNumber)
                    end
                    tUnclaimedLocations[iValidMexCount] = {}
                    tUnclaimedLocations[iValidMexCount] = tMexPosition
                end
            end
        end
    end
    aiBrain[reftUnclaimedMexOrHydroByCondition][sKey][reftResourceLocations] = tUnclaimedLocations

    if bDebugMessages == true then
        LOG(sFunctionRef..': Finished getting all unclaimed locations, will now draw them if there are any')
        if M27Utilities.IsTableEmpty(tUnclaimedLocations) == false then
            LOG('Have '..table.getn(tUnclaimedLocations)..' uncalimed locations, drawing them all')
            M27Utilities.DrawLocations(tUnclaimedLocations, nil, 1, 50)
        else LOG('Table is empty')
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)

    return tUnclaimedLocations
end

function GetNearestPartBuiltUnit(aiBrain, iCategoryToBuild, tStartPosition, iSearchRange)
    local bDebugMessages = false
    local sFunctionRef = 'GetNearestPartBuiltUnit'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local oNearestPartBuilt
    --Check if any nearby part-built units (that have abandoned) near tStartPosition
    if iCategoryToBuild then
        local tNearbyUnitsOfType = aiBrain:GetUnitsAroundPoint(iCategoryToBuild, tStartPosition, iSearchRange, 'Ally')
        local sPartBuiltLocationRef
        if M27Utilities.IsTableEmpty(tNearbyUnitsOfType) == false then
            if bDebugMessages == true then LOG(sFunctionRef..': Have '..table.getn(tNearbyUnitsOfType)..' units of the target type, will see if any are part-complete') end
            for iUnit, oUnit in tNearbyUnitsOfType do
                if oUnit.GetFractionComplete and oUnit:GetFractionComplete() < 1 then
                    --Check not already assigned to an existing unit
                    sPartBuiltLocationRef = M27Utilities.ConvertLocationToReference(oUnit:GetPosition())
                    if bDebugMessages == true then LOG(sFunctionRef..': Unit is part complete, checking if its location is already assigned to an engineer') end
                    --reftEngineerAssignmentsByLocation = 'M27EngineerAssignmentsByLoc'     --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the engineer unique ref assigned to this location; returns the engineer object
                    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sPartBuiltLocationRef]) == true then
                        if bDebugMessages == true then LOG(sFunctionRef..': Location not assigned to an engineer, so will assist this') end
                        oNearestPartBuilt = oUnit
                    end
                end
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return oNearestPartBuilt
end

function GetActionTargetAndObject(aiBrain, iActionRefToAssign, tExistingLocationsToPickFrom, tIdleEngineers, iActionPriority, tsUnitStatesToIgnoreCurrent, iSearchRangeForPrevEngi, iSearchRangeForNearestEngi, bOnlyReassignIdle, bGetInitialEngineer, iMinTechLevelWanted)
    --Returns both the location of the target, and (if relevant) the object (either the first engineer assigned the action, or the building its constructing if it exists yet); will return nil for object if there is none
    --if tExistingLocationsToPickFrom isn't nil then will only refer to here
    --Variables from tIdleEngineers onwards are only used by the mex functionality which will use the existing function to get the nearest idle engineer, and see hwo far it is from the mex
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetActionTargetAndObject'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    --if iActionRefToAssign == refActionFortifyFirebase then bDebugMessages = true end



    local tLocationsToGoThrough = tExistingLocationsToPickFrom
    --local tNearbyUnitsOfType, iCategoryToBuild
    local tActionLocation, oActionObject
    local iClosestUnassignedLocation = 10000
    local iCurLocationDistance
    local tCurAssignments
    local bLocationAlreadyAssigned
    local oEngiAlreadyAssigned
    local oFirstConstructingEngineer
    --local oBuildingUnderConstruction
    local oAssistTarget
    local bAssistBuildingOrEngineer = false
    local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]




    local bClearCurrentlyAssignedEngineer = false --e.g. if want to switch to T2 unit then will clear actions of the currently assigned engineer

    if bDebugMessages == true then LOG(sFunctionRef..': Start of code. iActionRefToAssign='..iActionRefToAssign) end

    --Are we assisting a building?
    if iActionRefToAssign == refActionUpgradeBuilding or iActionRefToAssign == refActionAssistSMD or iActionRefToAssign == refActionAssistNuke or iActionRefToAssign == refActionAssistAirFactory or iActionRefToAssign == refActionUpgradeHQ or iActionRefToAssign == refActionAssistShield then
        --Find the nearest building that is upgrading and assist it, but set a timer to reconsider engineer action after a while
        if bDebugMessages == true then LOG(sFunctionRef..': About to search for buildings to assist in upgrading') end
        local iCategoryToAssist = M27UnitInfo.refCategoryStructure
        local sUnitStateWanted = 'Upgrading'
        local sAltUnitStateWanted
        local bIgnoreUnitState = false
        local iEnemySearchRange = 60
        local tAllBuildings

        if iActionRefToAssign == refActionAssistSMD then
            iCategoryToAssist = M27UnitInfo.refCategorySMD
            sUnitStateWanted = 'SiloBuildingAmmo'
            iEnemySearchRange = 0
        elseif iActionRefToAssign == refActionAssistNuke then
            iCategoryToAssist = M27UnitInfo.refCategorySML
            sUnitStateWanted = 'SiloBuildingAmmo'
            iEnemySearchRange = 20
        elseif iActionRefToAssign == refActionAssistAirFactory then
            iCategoryToAssist = M27UnitInfo.refCategoryAirFactory
            sUnitStateWanted = 'Building'
            sAltUnitStateWanted = 'Upgrading'
            iEnemySearchRange = 20
        elseif iActionRefToAssign == refActionUpgradeHQ then
            tAllBuildings = aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]
            bIgnoreUnitState = true
            iEnemySearchRange = 0
        elseif iActionRefToAssign == refActionAssistShield then
            if bDebugMessages == true then LOG(sFunctionRef..': Are assisting a shield so will look for priority shields that dont have many engineers assigned') end
            tAllBuildings = {}
            local iValidBuildings = 0
            iCategoryToAssist = M27UnitInfo.refCategoryFixedShield --redundancy
            bIgnoreUnitState = true
            if M27Utilities.IsTableEmpty(aiBrain[reftPriorityShieldsToAssist]) == false then --redundancy
                local iMaxEngisWanted = 4
                --Spread out engis per priority shield initially
                if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionRefToAssign]) == false then iMaxEngisWanted = math.min(14, math.max(4, math.ceil(table.getsize(aiBrain[reftEngineerAssignmentsByActionRef][iActionRefToAssign]) / table.getsize(aiBrain[reftPriorityShieldsToAssist])) + 1)) end

                for iUnit, oUnit in aiBrain[reftPriorityShieldsToAssist] do
                    if bDebugMessages == true then
                        LOG(sFunctionRef..': Considering Shield '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; is table of assisting engis empty='..tostring(M27Utilities.IsTableEmpty(oUnit[reftAssistingEngineers]))..'; iMaxEngisWanted='..iMaxEngisWanted..'; If table not empty will list out engis assigned already')
                        if not(M27Utilities.IsTableEmpty(oUnit[reftAssistingEngineers])) then
                            for iEngi, oEngi in oUnit[reftAssistingEngineers] do
                                LOG(sFunctionRef..': Engi assisting='..oEngi.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi)..'; UC='..GetEngineerUniqueCount(oEngi))
                            end
                        end
                    end
                    if M27Utilities.IsTableEmpty(oUnit[reftAssistingEngineers]) or table.getsize(oUnit[reftAssistingEngineers]) < iMaxEngisWanted then
                        iValidBuildings = iValidBuildings + 1
                        tAllBuildings[iValidBuildings] = oUnit
                        if bDebugMessages == true then LOG(sFunctionRef..': Adding shield to list of valid buildings to consider assisting. iValidBuildings='..iValidBuildings) end
                    end
                end
            end
        end


        if M27Utilities.IsTableEmpty(tAllBuildings) then
            tAllBuildings = aiBrain:GetListOfUnits(iCategoryToAssist, false, false)
            if iActionRefToAssign == refActionAssistShield then M27Utilities.ErrorHandler('Couldnt find a priority shield to assist with the normal logic so will just assist the nearest T3 shield') end
        end
        local iNearestUpgradingBuilding = 10000
        local iCurDistanceToStart, tCurPosition
        local tNearbyEnemies


        if bDebugMessages == true then LOG(sFunctionRef..': About to cycle through all buildings meeting the category in question to see if we can assist them') end
        if M27Utilities.IsTableEmpty(tAllBuildings) == false then
            for iBuilding, oBuilding in tAllBuildings do
                if M27UnitInfo.IsUnitValid(oBuilding) then
                    if bDebugMessages == true then LOG(sFunctionRef..': iBuilding='..iBuilding..'; oBuilding Id='..oBuilding.UnitId..'; Unit state='..M27Logic.GetUnitState(oBuilding)) end
                    if not(oBuilding[M27EconomyOverseer.refbWillReclaimUnit]) and (oBuilding:GetFractionComplete() < 1 or bIgnoreUnitState or (oBuilding.IsUnitState and (oBuilding:IsUnitState(sUnitStateWanted) or (sAltUnitStateWanted and oBuilding:IsUnitState(sAltUnitStateWanted))))) then
                        tCurPosition = oBuilding:GetPosition()
                        iCurDistanceToStart = M27Utilities.GetDistanceBetweenPositions(tCurPosition, tStartPosition)
                        if bDebugMessages == true then LOG(sFunctionRef..': iBuilding is '..sUnitStateWanted..';  its distance to start='..iCurDistanceToStart) end
                        if iCurDistanceToStart < iNearestUpgradingBuilding then
                            --Check no nearby enemies
                            if iEnemySearchRange > 0 then tNearbyEnemies = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.DIRECTFIRE + categories.LAND * categories.INDIRECTFIRE, tCurPosition, iEnemySearchRange, 'Enemy')
                            else tNearbyEnemies = nil end
                            if M27Utilities.IsTableEmpty(tNearbyEnemies) == true then
                                if bDebugMessages == true then LOG(sFunctionRef..': No nearby enemies so will assign this building as target unless we subsequently find ones that are even closer') end
                                iNearestUpgradingBuilding = iCurDistanceToStart
                                oActionObject = oBuilding
                                tActionLocation = oBuilding:GetPosition()
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Have nearby enemies so not picking this building') end
                            end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': oBuilding='..oBuilding.UnitId..M27UnitInfo.GetUnitLifetimeCount(oBuilding)..'; Unit state='..M27Logic.GetUnitState(oBuilding)) end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': iBuilding count in tAllBuildings='..iBuilding..'; unit isnt valid. Size of tAllBuildings='..table.getsize(tAllBuildings)) end
                end
            end
        else
            M27Utilities.ErrorHandler('Couldnt find any buildings for Action '..(iActionRefToAssign or 'nil'))
        end
    elseif iActionRefToAssign == refActionLoadOnTransport then
        for iUnit, oUnit in aiBrain[M27Transport.reftTransportsWaitingForEngi] do
            if M27UnitInfo.IsUnitValid(oUnit) then
                oActionObject = oUnit
                tActionLocation = oUnit:GetPosition()
                break
            end
        end
    else
        if M27Utilities.IsTableEmpty(tLocationsToGoThrough) == true then --No locations to go through
            if iActionRefToAssign == refActionBuildMex or iActionRefToAssign == refActionBuildPlateauMex then M27Utilities.ErrorHandler('Likely error - should have mex location determined before calling the action') end
            if bDebugMessages == true then LOG(sFunctionRef..': Dont have existing locations to choose from, so pick location based on action') end
            --Pick targets based on action
            if iActionRefToAssign == refActionReclaimArea then
                --Get preferred reclaim position - pick engineer closest to below location (will overwrite the actual target location later on when assigning reclaim action)
                tActionLocation = M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)
            elseif iActionRefToAssign == refActionReclaimUnit then
                --Pick a reclaim unit closest to our start
                oActionObject = M27Utilities.GetNearestUnit(aiBrain[M27EconomyOverseer.reftUnitsToReclaim], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain, false, false)
                if oActionObject.GetPosition then
                    tActionLocation = oActionObject:GetPosition()
                else oActionObject = nil
                end
            elseif iActionRefToAssign == refActionReclaimTrees then
                tActionLocation = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
            elseif iActionRefToAssign == refActionBuildT1Sonar or iActionRefToAssign == refActionBuildT2Sonar then
                if bDebugMessages == true then LOG(sFunctionRef..': Want to build sonar, will try and find a water location along a line from us to enemy base; will draw valid location in gold, invalid in red') end
                --Find water along the way from our base to the midpoint of the map that is pathable by an amphibious unit
                local tPossiblePosition
                local iT2SonarAdjust = 5
                --local iAngleToEnemyBase = M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                for iCurPath = 1, math.floor(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.05) do
                    --Debug mode - draw valid location in gold, invalid locations in red
                    tPossiblePosition = M27Utilities.MoveTowardsTarget(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), iCurPath * 10 + iT2SonarAdjust, 0)
                    if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tPossiblePosition) == aiBrain[M27MapInfo.refiStartingSegmentGroup][M27UnitInfo.refPathingTypeAmphibious] and not(M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, tPossiblePosition) == aiBrain[M27MapInfo.refiStartingSegmentGroup][M27UnitInfo.refPathingTypeLand]) then
                        --Can path there amphibiously but not with land, is the locaiton water?
                        if GetTerrainHeight(tPossiblePosition[1], tPossiblePosition[3]) < M27MapInfo.iMapWaterHeight then
                            --Is underwater, so want to build around here
                            if bDebugMessages == true then
                                M27Utilities.DrawLocation(tPossiblePosition, nil, 4)
                                LOG('Have a location that is underwater, tPossiblePosition='..repru(tPossiblePosition))
                            end
                            tActionLocation = tPossiblePosition

                            break
                        end
                    end
                    if bDebugMessages == true then M27Utilities.DrawLocation(tPossiblePosition, nil, 2) end
                end
                if M27Utilities.IsTableEmpty(tActionLocation) then
                    --Try a (sort of) random location
                    if bDebugMessages == true then LOG(sFunctionRef..': COuldnt find a location moving in a straight line so will try a random location') end
                    local tBasePoint = M27Utilities.MoveTowardsTarget(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.25, 0)
                    for iDistanceAdjust = 50, 250, 50 do
                        for iAngleAdjust = -2, 6 do
                            tPossiblePosition = M27Utilities.MoveTowardsTarget(tBasePoint, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain), iDistanceAdjust + iT2SonarAdjust, iAngleAdjust * 45)
                            if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, tPossiblePosition) == aiBrain[M27MapInfo.refiStartingSegmentGroup][M27UnitInfo.refPathingTypeAmphibious] and not(M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, tPossiblePosition) == aiBrain[M27MapInfo.refiStartingSegmentGroup][M27UnitInfo.refPathingTypeLand]) then
                                --Can path there amphibiously but not with land, is the locaiton water?
                                if GetTerrainHeight(tPossiblePosition[1], tPossiblePosition[3]) < M27MapInfo.iMapWaterHeight then
                                    --Is underwater, so want to build around here
                                    if bDebugMessages == true then M27Utilities.DrawLocation(tPossiblePosition, nil, 4) end
                                    tActionLocation = tPossiblePosition
                                    break
                                end
                            end
                            if bDebugMessages == true then M27Utilities.DrawLocation(tPossiblePosition, nil, 2) end
                        end
                    end
                    if M27Utilities.IsTableEmpty(tActionLocation) then M27Utilities.ErrorHandler('Unable to find any water to build sonar on despite being able to path to enemy base only with amphibious units') end
                end
            else
                --First check if we are already building anything under this action (in which case want to assist it instead of building a new one)
                if bDebugMessages == true then LOG(sFunctionRef..': Dont have a predefined location and are doing a normal action so will see if anyone is already building for this action and if so if there is a building we can assist') end
                if aiBrain[reftEngineerAssignmentsByActionRef] then
                    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionRefToAssign]) == false or (iActionRefToAssign == refActionBuildExperimental and not(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildSecondExperimental]))) then
                        oFirstConstructingEngineer = nil
                        local oAlternativeEngineer
                        local oEngi
                        local iEngineerCount = 0
                        local iActionToSearch = iActionRefToAssign
                        local bDontGetPrimary = false
                        --If we are building land experimental our first engineer may have chosen to assist the engineer building the second experimental instead, in which acse we wont have a primary engineer
                        if iActionRefToAssign == refActionBuildExperimental and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildSecondExperimental]) == false then
                            bDontGetPrimary = true
                        end
                        if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionRefToAssign]) and iActionRefToAssign == refActionBuildExperimental then
                            iActionToSearch = refActionBuildSecondExperimental
                            if bDebugMessages == true then LOG(sFunctionRef..': Are building an experimental and dont have anything being built for this action, so presumably we did for building a second experimental') end
                        end
                        for iEngi, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][iActionToSearch] do
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering iEngi ref in table of '..iEngi..'; is unit valid='..tostring(M27UnitInfo.IsUnitValid(tSubtable[refEngineerAssignmentEngineerRef]))) end
                            if M27UnitInfo.IsUnitValid(tSubtable[refEngineerAssignmentEngineerRef]) then
                                oAlternativeEngineer = tSubtable[refEngineerAssignmentEngineerRef]
                                if (bDontGetPrimary or tSubtable[refEngineerAssignmentEngineerRef][refbPrimaryBuilder]) then
                                    oFirstConstructingEngineer = tSubtable[refEngineerAssignmentEngineerRef]
                                    break
                                end
                            end
                        end
                        --Redundancy:
                        if not(M27UnitInfo.IsUnitValid(oFirstConstructingEngineer)) and M27UnitInfo.IsUnitValid(oAlternativeEngineer) then
                            oFirstConstructingEngineer = oAlternativeEngineer
                        end
                        if bDebugMessages == true then
                            if oFirstConstructingEngineer then LOG(sFunctionRef..': Have identified first constructing engineer='..oFirstConstructingEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oFirstConstructingEngineer))
                            else LOG(sFunctionRef..': Couldnt find first constructing engineer')
                            end
                        end
                        --[[
                            iEngineerCount = iEngineerCount + 1
                            if not(oFirstConstructingEngineer) then
                                oEngi = tSubtable[refEngineerAssignmentEngineerRef]
                                if bDebugMessages == true then LOG(sFunctionRef..': Cycling through engineers assigned to action '..iActionRefToAssign..'; Engi unique ref='..iEngi) end
                                if oEngi.GetUnitId == nil then LOG(sFunctionRef..': oEngi doesnt have a unit ID so likely error recording it') end
                                if not(oEngi.Dead) and oEngi.GetPosition then
                                    oFirstConstructingEngineer = oEngi
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef..': Engi is still alive so assigning it as the first constructing engineer')
                                    end
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': size of engineers assigned to iActionRef '..iActionRefToAssign..' is: '..iEngineerCount) end
                        --]]


                        if oFirstConstructingEngineer == nil then
                            --Not bothered about units with the spare action as they all operate independently, and theyre ctrlKd
                            if not(iActionRefToAssign == refActionSpare) then M27Utilities.ErrorHandler('Potential error unless unit died in last second - FirstConstructingEngineer for action ref '..iActionRefToAssign..' is dead or not a unit', true) end
                        else
                            if bDebugMessages == true then
                                local sFirstConstructingName = GetEngineerUniqueCount(oFirstConstructingEngineer)
                                LOG(sFunctionRef..': First constructing engineer unique ref='..sFirstConstructingName)
                            end
                            --Do we want to assist the first constructing engineer, or instead clear it of its actions and become the first constructing engineer?
                            bAssistBuildingOrEngineer = true
                            if iMinTechLevelWanted > 1 and not(bDontGetPrimary) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Checking if unit constructing tech level is below the min wanted and unit isnt already building/repairing. oFirstConstructingEngineer='..oFirstConstructingEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oFirstConstructingEngineer)..'; UC='..GetEngineerUniqueCount(oFirstConstructingEngineer)..'; Unit state='..M27Logic.GetUnitState(oFirstConstructingEngineer)..'; iMinTechLevelWanted='..iMinTechLevelWanted) end
                                if M27UnitInfo.GetUnitTechLevel(oFirstConstructingEngineer) < iMinTechLevelWanted and not(oFirstConstructingEngineer:IsUnitState('Building')) and not(oFirstConstructingEngineer:IsUnitState('Repairing')) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Unit constructing tech level is below the min wanted so will mark it to be cleared.  Unit state of first constructing engineer='..M27Logic.GetUnitState(oFirstConstructingEngineer)) end
                                    bAssistBuildingOrEngineer = false
                                    bClearCurrentlyAssignedEngineer = true
                                end
                            end
                            if bAssistBuildingOrEngineer == true then
                                --Want to assist the first constructing engineer, unless we are building power and our engi is a higher tech level in which case want to clear the first constructing engineer's primary flag but still let it keep building
                                local bBuildSeparateBuilding = false
                                if iActionRefToAssign == refActionBuildPower then
                                    local iTechOfFirstConstructingEngi = M27UnitInfo.GetUnitTechLevel(oFirstConstructingEngineer)
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have action to build power.  Tech level of first constructing engi ='..iTechOfFirstConstructingEngi..'; if this is below 3 then will see if we have higher tech in our idle engineers') end
                                    if iTechOfFirstConstructingEngi < 3 then
                                        for iUnit, oUnit in tIdleEngineers do
                                            if bDebugMessages == true then LOG(sFunctionRef..': Considering idle engineer '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; UC='..GetEngineerUniqueCount(oUnit)..' with a tech level '..M27UnitInfo.GetUnitTechLevel(oUnit)) end
                                            if M27UnitInfo.GetUnitTechLevel(oUnit) > iTechOfFirstConstructingEngi then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Engineer is a higher level than the first constructing engineer so will build separate building') end
                                                bBuildSeparateBuilding = true
                                                break
                                            end
                                        end
                                    end
                                end
                                if bBuildSeparateBuilding then
                                    oFirstConstructingEngineer[refbPrimaryBuilder] = false
                                    bAssistBuildingOrEngineer = false
                                    local iExistingEngineers = table.getn(aiBrain[reftEngineerAssignmentsByActionRef][iActionRefToAssign])
                                    local iWorkProgressThreshold = 0.7 - math.min(4, iExistingEngineers) * 0.1

                                    if M27UnitInfo.GetUnitTechLevel(oFirstConstructingEngineer) == 1 then iWorkProgressThreshold = math.max(0.2, iWorkProgressThreshold - 0.2) end


                                    if bDebugMessages == true then LOG(sFunctionRef..': Are building separate builting. first constructing engineer unit state='..M27Logic.GetUnitState(oFirstConstructingEngineer)..'; Engineer work progress='..(oFirstConstructingEngineer:GetWorkProgress() or 'nil')..'; iWorkProgressThreshold='..iWorkProgressThreshold) end
                                    if not(oFirstConstructingEngineer:IsUnitState('Building')) or oFirstConstructingEngineer:GetWorkProgress() <= iWorkProgressThreshold then
                                        bClearCurrentlyAssignedEngineer = true
                                        if bDebugMessages == true then LOG(sFunctionRef..': Will clear currently assigned engineer as it hasnt g ot far with its building') end
                                    end
                                else
                                    oAssistTarget = oFirstConstructingEngineer
                                end
                            end
                        end
                    else
                        --Check if any nearby part-built units (that have abandoned) near the start position
                        local iCategoryToBuild = GetCategoryToBuildFromAction(iActionRefToAssign, iMinTechLevelWanted, aiBrain)
                        --Use massive range for experimentals
                        local iSearchRangeForPartBuilt = math.max(iSearchRangeForNearestEngi, 30)
                        if iActionRefToAssign == refActionBuildExperimental then iSearchRangeForPartBuilt = math.max(iSearchRangeForPartBuilt, 150) end
                        local oNearestPartBuilt = GetNearestPartBuiltUnit(aiBrain, iCategoryToBuild, tStartPosition, iSearchRangeForPartBuilt)
                        if oNearestPartBuilt then
                            if bDebugMessages == true then LOG(sFunctionRef..': Are assisting part built building') end
                            bAssistBuildingOrEngineer = true
                            oAssistTarget = oNearestPartBuilt
                        end
                    end
                end
                if bAssistBuildingOrEngineer == true then
                    if bDebugMessages == true then LOG(sFunctionRef..': Are assisting building or engineer') end
                    oActionObject = oAssistTarget
                    tActionLocation = oActionObject:GetPosition()
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Will construct a new building instead of assisting') end
                    --Need to create a new building instead of assisting - will determine actual location to try and build later on

                    if iActionRefToAssign == refActionBuildShield then
                        --Pick the closest unit that wants a shield that isnt at a failed location
                        if M27Utilities.IsTableEmpty(aiBrain[reftUnitsWantingFixedShield]) == false then
                            local iClosestDistance = 10000
                            oActionObject = nil
                            local iCurDist
                            for iUnit, oUnit in aiBrain[reftUnitsWantingFixedShield] do
                                if M27UnitInfo.IsUnitValid(oUnit) then
                                    --Failed shield location logic - this is redundancy for if the initial logic for units wanting shields fails
                                    if not(aiBrain[reftFailedShieldLocations][M27Utilities.ConvertLocationToReference(oUnit:GetPosition())]) then
                                        iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                        if iCurDist < iClosestDistance then
                                            iClosestDistance = iCurDist
                                            oActionObject = oUnit
                                        end
                                    else
                                        table.remove(aiBrain[reftUnitsWantingFixedShield], iUnit)
                                        if bDebugMessages == true then LOG(sFunctionRef..': Unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; is on a location where we have a failed shield location for building, so wont consider it') end
                                    end
                                end
                            end
                        end
                        if oActionObject then
                            tActionLocation = oActionObject:GetPosition()
                        end
                    elseif iActionRefToAssign == refActionBuildEmergencyPD then
                        --Pick somewhere on the way from our base to the nearest enemy threat
                        --Do we have a choekpoint near here that is assigned to a teammate and which has at least 3 T2 PD? If so then build here
                        local tNearestChokepoint
                        local iNearestChokepointDistance = aiBrain[M27Overseer.refiModDistFromStartNearestThreat] - 25
                        local iCurChokepointDistance
                        if not(M27Utilities.IsTableEmpty(M27Overseer.tTeamData[aiBrain.M27Team][M27MapInfo.tiPlannedChokepointsByDistFromStart])) then
                            for iBrain, oBrain in M27Overseer.tTeamData[aiBrain.M27Team][M27Overseer.reftFriendlyActiveM27Brains] do
                                if oBrain[M27Overseer.refiDefaultStrategy] == M27Overseer.refStrategyTurtle and oBrain[M27MapInfo.refiAssignedChokepointFirebaseRef] then
                                    iCurChokepointDistance = M27Utilities.GetDistanceBetweenPositions(oBrain[M27MapInfo.reftChokepointBuildLocation], tStartPosition)
                                    if iCurChokepointDistance < iNearestChokepointDistance then
                                        tNearestChokepoint = {oBrain[M27MapInfo.reftChokepointBuildLocation][1], oBrain[M27MapInfo.reftChokepointBuildLocation][2], oBrain[M27MapInfo.reftChokepointBuildLocation][3]}
                                        iNearestChokepointDistance = iCurChokepointDistance
                                    end
                                end
                            end
                        end



                        --Do we have complete T2 PD between us and the enemy? If so try and fortify here
                        local tNearbyPD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2PlusPD, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], math.min(100, aiBrain[M27Overseer.refiModDistFromStartNearestThreat] * 0.6), 'Ally')
                        local iAngleToNearestThreat, toInRangePD
                        local iInRangePD = 0
                        if M27Utilities.IsTableEmpty(tNearbyPD) == false then
                            local iCurAngle
                            toInRangePD = {}
                            iAngleToNearestThreat = M27Utilities.GetAngleFromAToB(tStartPosition, aiBrain[M27Overseer.reftLocationFromStartNearestThreat])
                            for iPD, oPD in tNearbyPD do
                                if oPD:GetFractionComplete() >= 1 and oPD:GetHealthPercent() >= 0.5 then
                                    iCurAngle = M27Utilities.GetAngleFromAToB(tStartPosition, oPD:GetPosition())
                                    if math.abs(iCurAngle - iAngleToNearestThreat) <= 45 then
                                        iInRangePD = iInRangePD + 1
                                        toInRangePD[iInRangePD] = oPD
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': Just considered oPD='..oPD.UnitId..M27UnitInfo.GetUnitLifetimeCount(oPD)..'; Fraction complete='..oPD:GetFractionComplete()..'; Heatlh%='..oPD:GetHealthPercent()..'; Angle from base='..M27Utilities.GetAngleFromAToB(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], oPD:GetPosition())..'; angle from base of nearest threat='..iAngleToNearestThreat..'; iInRangePD='..iInRangePD) end
                            end
                        end
                        if iInRangePD > 0 then
                            if iInRangePD <= 3 then
                                tActionLocation = M27Utilities.GetAveragePosition(toInRangePD)
                            else
                                --Get the 3 PD closest to the enemy
                                local tClosestPDUnits = {}
                                local iClosestPDCount = 0
                                local tPDDistToEnemy = {}
                                for iUnit, oUnit in toInRangePD do
                                    tPDDistToEnemy[iUnit] = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), aiBrain[M27Overseer.reftLocationFromStartNearestThreat])
                                end
                                for iUnit, iDistance in M27Utilities.SortTableByValue(tPDDistToEnemy, false) do
                                    iClosestPDCount = iClosestPDCount + 1
                                    tClosestPDUnits[iClosestPDCount] = toInRangePD[iUnit]
                                    if iClosestPDCount >= 3 then break end
                                end

                                tActionLocation = M27Utilities.GetAveragePosition(tClosestPDUnits)
                            end
                            --Move slightly forwards if we are really close to our base
                            if M27Utilities.GetDistanceBetweenPositions(tStartPosition, tActionLocation) < (math.min(math.min(aiBrain[M27Overseer.refiModDistFromStartNearestThreat] - 30, aiBrain[M27Overseer.refiModDistFromStartNearestThreat] * 0.4, 50))) then
                                local iDistToMoveForwards = 5
                                if iInRangePD > 3 then iDistToMoveForwards = 10 end
                                tActionLocation = M27Utilities.MoveInDirection(tActionLocation, M27Utilities.GetAngleFromAToB(tActionLocation, aiBrain[M27Overseer.reftLocationFromStartNearestThreat]), iDistToMoveForwards, true)
                            end
                        else
                            if aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= 30 then
                                tActionLocation = tStartPosition
                            else
                                local iDistTowardsEnemy = math.min(aiBrain[M27Overseer.refiModDistFromStartNearestThreat] - 30, aiBrain[M27Overseer.refiModDistFromStartNearestThreat] * 0.4, 50)
                                tActionLocation = M27Utilities.MoveInDirection(tStartPosition, M27Utilities.GetAngleFromAToB(tStartPosition, aiBrain[M27Overseer.reftLocationFromStartNearestThreat]), iDistTowardsEnemy, true)
                            end
                        end
                        if bDebugMessages == true then
                            LOG(sFunctionRef..': tActionLocation for PD before running the adjustPDlocation function='..repru(tActionLocation)..'; will draw in white')
                            M27Utilities.DrawLocation(tActionLocation, nil, 7, 100, nil)
                        end
                    else
                        tActionLocation = tStartPosition
                    end
                end
            end
        else --Have preset locations to consider
            if bDebugMessages == true then LOG(sFunctionRef..': Have already been given a list of potential locations to consider') end
            --Pick target from existing locations, and check if already been assigned to an engineer (e.g. would expect this to be done for actions to buidl mex and hydro)
            local oNearestEngineer, tPositionToLookFrom
            bLocationAlreadyAssigned = false
            bAssistBuildingOrEngineer = false

            for iLocation, tLocation in tExistingLocationsToPickFrom do
                bAssistBuildingOrEngineer = false
                if not(iActionRefToAssign == refActionBuildMex or iActionRefToAssign == refActionBuildPlateauMex) then --Exclude any actions that want to by default only 1 engi to build per location (with new locations being chosen)
                    --Check we aren't already constructing something at this location
                    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionRefToAssign]) == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': Already have an engineer assigned to build TMD so will see if can assist it') end
                        --local sLocationRef = M27Utilities.ConvertLocationToReference(tLocation)
                        local oEngi
                        bAssistBuildingOrEngineer = true
                        for iSubtable, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][iActionRefToAssign] do
                            oEngi = tSubtable[refEngineerAssignmentEngineerRef]
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering oEngi='..oEngi.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi)..'; UC='..GetEngineerUniqueCount(oEngi)..' for location '..repru(tSubtable[refEngineerAssignmentActualLocation])) end
                            if M27UnitInfo.IsUnitValid(oEngi) then
                                if oEngi[refbPrimaryBuilder] then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Found the primary builder for this action so will assist it') end
                                    oActionObject = oEngi
                                    tActionLocation = tSubtable[refEngineerAssignmentActualLocation]
                                    bAssistBuildingOrEngineer = true
                                    break
                                end
                            end
                        end
                    end
                    if not(bAssistBuildingOrEngineer) then
                        --Check if any nearby part-built units (that have abandoned) near the start position
                        local iCategoryToBuild = GetCategoryToBuildFromAction(iActionRefToAssign, iMinTechLevelWanted, aiBrain)
                        local oNearestPartBuilt = GetNearestPartBuiltUnit(aiBrain, iCategoryToBuild, tLocation, math.max(iSearchRangeForNearestEngi, 30))
                        if oNearestPartBuilt then
                            if bDebugMessages == true then LOG(sFunctionRef..': Are assisting part built building') end
                            bAssistBuildingOrEngineer = true
                            oActionObject = oNearestPartBuilt
                            tActionLocation = oActionObject:GetPosition()
                            break
                        end
                    end
                    if bAssistBuildingOrEngineer then break end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Are building a mex so dont want to check if there is a unit to assist') end
                end
                --[[if not(bAssistBuildingOrEngineer) or (not(oActionObject) and not(tActionLocation)) then
                    bLocationAlreadyAssigned = false
                    local sLocationRef = M27Utilities.ConvertLocationToReference(tLocation)
                    --Do we want to check we dont already have an action assigned for this location? Ignore this check for some actions like building TMD since the locations will have units on them that we want to protect
                    if not(aiBrain[reftEngineerAssignmentsByLocation] == nil) and not(iActionRefToAssign == refActionBuildTMD) then
                        if not(iActionRefToAssign == refActionBuildMassStorage) or (aiBrain:CanBuildStructureAt('uab1106', tLocation) or (aiBrain[reftEngineerAssignmentsByLocation][sLocationRef] and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iActionRefToAssign]) == false)) then
                            --reftEngineerAssignmentsByLocation --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the engineer unique ref assigned to this location
                            tCurAssignments = aiBrain[reftEngineerAssignmentsByLocation][sLocationRef]
                            if M27Utilities.IsTableEmpty(tCurAssignments) == false then
                                --Could we build the building we want to at this location
                                if bDebugMessages == true then LOG(sFunctionRef..': Checking if the location has been assigned already, sLocationRef='..sLocationRef) end
                                if M27Utilities.IsTableEmpty(tCurAssignments[iActionRefToAssign]) == false then
                                    oEngiAlreadyAssigned = nil
                                    for iUniqueEngiRef, oEngi in tCurAssignments[iActionRefToAssign] do
                                        if not(oEngi.Dead) and oEngi.GetPosition then
                                            oEngiAlreadyAssigned = oEngi
                                            break
                                        end
                                    end
                                    if oEngiAlreadyAssigned == nil then
                                        if bDebugMessages == true then LOG(sFunctionRef..': sLocationRef='..sLocationRef..': No alive engineer has been assigned this action yet') end
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': iLocation='..iLocation..' is already assigned to an engineer so will ignore unless building hydro. iActionRefToAssign='..iActionRefToAssign) end
                                        bLocationAlreadyAssigned = true
                                        if iActionRefToAssign == refActionBuildHydro or iActionRefToAssign == refActionBuildMassStorage or iActionRefToAssign == refActionBuildT3MexOverT2 or iActionRefToAssign == refActionBuildT3ArtiPower then --If we're building a mex dont need to assist it.  If we're building a hydro or mass storage then do want to assist it
                                            oActionObject = oEngiAlreadyAssigned
                                            tActionLocation = oActionObject:GetPosition()
                                            if bDebugMessages == true then LOG(sFunctionRef..': iLocation='..iLocation..'; Location of engineer that will be assisting='..repru(tActionLocation)) end
                                            if M27Utilities.IsTableEmpty(tActionLocation) == true then
                                                if not(oActionObject.GetUnitId) then
                                                    M27Utilities.ErrorHandler('Action object doesnt have a unit ID; iActionRefToAssign='..iActionRefToAssign..'; previously had a workaround, have commented out for new appraoch, revisit')
                                                else
                                                    M27Utilities.ErrorHandler('tActionLocation is nil')
                                                end
                                            end
                                            break
                                        end
                                    end
                                end
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': table for sLocationRef='..sLocationRef..' is empty') end
                            end
                        else
                            if bDebugMessages == true then LOG(sFunctionRef..': Mass storage location is blocked') end
                        end
                    end
                end--]]
                if bDebugMessages == true then LOG(sFunctionRef..': bLocationAlreadyAssigned='..tostring(bLocationAlreadyAssigned)..'; bAssistBuildingOrEngineer='..tostring(bAssistBuildingOrEngineer)) end
                if bLocationAlreadyAssigned == false and not(bAssistBuildingOrEngineer) then
                    if bDebugMessages == true then LOG(sFunctionRef..': iLocation='..iLocation..': tLocation='..repru(tLocation)..': No units to assist so will decide on location to build at out of the preset options') end
                    tPositionToLookFrom = tStartPosition
                    --Specify if action is the type for which we might be far away from base, and so want to base the location choice on one closest to the nearest valid engineer
                    if iActionRefToAssign == refActionBuildMex or iActionRefToAssign == refActionBuildMassStorage or iActionRefToAssign == refActionBuildTMD then
                        --Find the nearest unassigned engineer
                        --GetNearestEngineerWithLowerPriority(aiBrain, tEngineers, iCurrentActionPriority, tCurrentActionTarget, iActionRefToGetExistingCount, tsUnitStatesToIgnore, iMaxRangeForPrevEngi, iMaxRangeForNearestEngi, bOnlyGetIdleEngis, bGetInitialEngineer)
                        --GetNearestEngineerWithLowerPriority(aiBrain, tEngineers, iCurrentActionPriority, tCurrentActionTarget, iActionRefToGetExistingCount, tsUnitStatesToIgnore, iMaxRangeForPrevEngi, iMaxRangeForNearestEngi, bOnlyGetIdleEngis, bGetInitialEngineer, iMinTechLevelWanted)
                        oNearestEngineer = GetNearestEngineerWithLowerPriority(aiBrain, tIdleEngineers, iActionPriority, tLocation, iActionRefToAssign, tsUnitStatesToIgnoreCurrent, iSearchRangeForPrevEngi, iSearchRangeForNearestEngi, bOnlyReassignIdle, bGetInitialEngineer, iMinTechLevelWanted)
                        if oNearestEngineer and oNearestEngineer.GetPosition then
                            if bDebugMessages == true then LOG(sFunctionRef..': Found an engi '..oNearestEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oNearestEngineer)..' UC'..GetEngineerUniqueCount(oNearestEngineer)..' near to the mex, so will use this as the base position to see how close the mex is to it') end
                            tPositionToLookFrom = oNearestEngineer:GetPosition()
                        end
                    end

                    iCurLocationDistance = M27Utilities.GetDistanceBetweenPositions(tLocation, tPositionToLookFrom)
                    if bDebugMessages == true then LOG(sFunctionRef..': iCurLocationDistance='..iCurLocationDistance..'; iClosestUnassignedLocation='..iClosestUnassignedLocation) end
                    if iCurLocationDistance < iClosestUnassignedLocation then
                        if bDebugMessages == true then LOG(sFunctionRef..': Location is closest, iCurLocationDistance='..iCurLocationDistance..' based on tPositionToLookFrom='..repru(tPositionToLookFrom)) end
                        iClosestUnassignedLocation = iCurLocationDistance
                        tActionLocation = tLocation
                    end
                    if iActionRefToAssign == refActionBuildT3MexOverT2 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Will assign nearest T2 mex as the action object') end
                        oActionObject = aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]
                        if M27UnitInfo.IsUnitValid(oActionObject) == false then M27Utilities.ErrorHandler('Dont have a valid mex assigned for the action to build t3 mex') end
                    end
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Already have the target location assigned to another engineer') end
                end
            end
            if iActionRefToAssign == refActionFortifyFirebase and not(bAssistBuildingOrEngineer) and not(bLocationAlreadyAssigned) then
                --Adjust movement slightly
                local iDistTowardsEnemy
                if M27Utilities.DoesCategoryContainCategory(M27UnitInfo.refCategoryPD, GetCategoryToBuildFromAction(iActionRefToAssign, iMinTechLevelWanted, aiBrain), false) then
                    --Move towards enemy base slightly
                    iDistTowardsEnemy = 4 --math.min(10, 2 + table.getsize(aiBrain[reftFirebaseUnitsByFirebaseRef][aiBrain[refiFirebaseBeingFortified]]))
                elseif M27Utilities.DoesCategoryContainCategory(M27UnitInfo.refCategoryTMD, GetCategoryToBuildFromAction(iActionRefToAssign, iMinTechLevelWanted, aiBrain), false) then
                    iDistTowardsEnemy = 1
                elseif M27Utilities.DoesCategoryContainCategory(M27UnitInfo.refCategoryFixedT2Arti + M27UnitInfo.refCategorySMD, GetCategoryToBuildFromAction(iActionRefToAssign, iMinTechLevelWanted, aiBrain), false) then
                    iDistTowardsEnemy = -4
                end
                if iDistTowardsEnemy then
                if bDebugMessages == true then LOG(sFunctionRef..': Will adjust start point by iDistTowardsEnemy='..(iDistTowardsEnemy or 'nil')..'; tActionLocation pre adjust='..repru(tActionLocation)) end
                tActionLocation = M27Utilities.MoveInDirection(tActionLocation, M27Utilities.GetAngleFromAToB(tActionLocation, M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain)), iDistTowardsEnemy, true)
                    end
            end
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef..': About to return tActionLocation and oActionObject')
        if M27Utilities.IsTableEmpty(tActionLocation) == true then LOG(sFunctionRef..': End - iActionRefToAssign='..iActionRefToAssign..'; tActionLocation is nil/empty')
        else LOG(sFunctionRef..': tActionLocation='..repru(tActionLocation)..'; ref='..M27Utilities.ConvertLocationToReference(tActionLocation)) end
        if oActionObject == nil then LOG(sFunctionRef..': End - oActionObject is nil/empty')
        else LOG(sFunctionRef..': oActionObject='..oActionObject.UnitId..M27UnitInfo.GetUnitLifetimeCount(oActionObject)..'; Object location='..repru(oActionObject:GetPosition())..'; Object health='..oActionObject:GetHealth()..'; Fraction complete='..oActionObject:GetFractionComplete())
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return tActionLocation, oActionObject, bClearCurrentlyAssignedEngineer
end

function FirebaseTrackingOfConstruction(aiBrain, oEngineer, oPossibleFirebaseUnit)
    --Assumes we have already checked oPossibleFirebaseUnit is a structure

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'FirebaseTrackingOfConstruction'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if bDebugMessages == true then LOG(sFunctionRef..': Considering if building just built is part of a firebase.  Engineer action='..(oEngineer[refiEngineerCurrentAction] or 'nil')..'; Unit assigned firebase='..(oPossibleFirebaseUnit[refiAssignedFirebase] or 'nil')..'; is the table of firebase positions empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftFirebasePosition]))) end
    if oEngineer[refiEngineerCurrentAction] == refActionFortifyFirebase then
        --Get the closest firebase, if its within 50 of here then assign the unit to it
        if not(oPossibleFirebaseUnit[refiAssignedFirebase]) and M27Utilities.IsTableEmpty(aiBrain[reftFirebasePosition]) == false then
            local iCurDist
            local iClosestDist = 10000
            local iClosestFirebaseRef
            if bDebugMessages == true then LOG(sFunctionRef..': Will find the closest firebase being constructed unless the firebase last being constructed is nearby') end
            if aiBrain[refiFirebaseBeingFortified] and aiBrain[reftFirebasePosition][aiBrain[refiFirebaseBeingFortified]] and M27Utilities.GetDistanceBetweenPositions(aiBrain[reftFirebasePosition][aiBrain[refiFirebaseBeingFortified]], oPossibleFirebaseUnit:GetPosition()) <= 60 then
                iClosestFirebaseRef =  aiBrain[refiFirebaseBeingFortified]
            else
                local sRefToSearch = reftFirebasePosition
                if EntityCategoryContains(M27UnitInfo.refCategoryPD + M27UnitInfo.refCategoryTMD, oPossibleFirebaseUnit.UnitId) then sRefToSearch = reftFirebaseFrontPDPosition end

                for iFirebase, tFirebase in aiBrain[sRefToSearch] do
                    iCurDist = M27Utilities.GetDistanceBetweenPositions(tFirebase, oPossibleFirebaseUnit:GetPosition())
                    if iCurDist < iClosestDist then
                        iClosestDist = iCurDist
                        iClosestFirebaseRef = iFirebase
                    end
                end
                if iClosestDist > 50 then iClosestFirebaseRef = nil end
            end
            if iClosestFirebaseRef then
                if bDebugMessages == true then LOG(sFunctionRef..': Assigning '..oPossibleFirebaseUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oPossibleFirebaseUnit)..' to firebase ref '..iClosestFirebaseRef) end
                AssignUnitToFirebase(aiBrain, oPossibleFirebaseUnit, iClosestFirebaseRef)
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)

end

function AssignUnitToFirebase(aiBrain, oUnit, iFirebaseRef)
    if M27Utilities.IsTableEmpty(aiBrain[reftFirebaseUnitsByFirebaseRef][iFirebaseRef]) then --Redundancy - shouldnt need (but if put in an error message it triggers when this is being called from the function to track a new firebase)
        aiBrain[reftFirebaseUnitsByFirebaseRef][iFirebaseRef] = {}
    end
    if not(oUnit[refiAssignedFirebase]) then
        if EntityCategoryContains(M27UnitInfo.refCategoryFixedT2Arti, oUnit.UnitId) then ForkThread(M27UnitInfo.SetUnitTargetPriorities, oUnit, M27UnitInfo.refWeaponPriorityT2Arti) end
    end
    oUnit[refiAssignedFirebase] = iFirebaseRef
    aiBrain[reftFirebaseUnitsByFirebaseRef][iFirebaseRef][oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)] = oUnit
end

function TrackNewFirebase(aiBrain, tUnits)
    local iFirebaseRef = (aiBrain[refiFirebaseUniqueCount] or 0) + 1
    aiBrain[refiFirebaseUniqueCount] = iFirebaseRef
    if M27Utilities.IsTableEmpty(aiBrain[reftFirebaseUnitsByFirebaseRef][iFirebaseRef]) then
        aiBrain[reftFirebaseUnitsByFirebaseRef][iFirebaseRef] = {}
    end
    for iUnit, oUnit in tUnits do
        AssignUnitToFirebase(aiBrain, oUnit, iFirebaseRef)
    end
end


function RefreshListOfFirebases(aiBrain, bForceRefresh)
    --Have there been any PD changes since we last checked or has it been a while since we last checked (e.g. in case things have changed like enemy indirect fire units or SML)?
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RefreshListOfFirebases'

    --if aiBrain[M27Overseer.refiTotalEnemyShortRangeThreat] >= 20000 then bDebugMessages = true end

    local iRefreshInterval = 20
    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle then iRefreshInterval = 5 end

    if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[refbPotentialFirebaseBuildingChangedSinceLastFirebaseCheck]='..tostring(aiBrain[refbPotentialFirebaseBuildingChangedSinceLastFirebaseCheck])..'; Time since last refresh='..(GetGameTimeSeconds() - (aiBrain[refiTimeOfLastFirebaseRefresh] or -100))..'; iRefreshInterval='..iRefreshInterval..'; bForceRefresh='..tostring(bForceRefresh)) end



    if bForceRefresh or aiBrain[refbPotentialFirebaseBuildingChangedSinceLastFirebaseCheck] or GetGameTimeSeconds() - (aiBrain[refiTimeOfLastFirebaseRefresh] or -100) >= iRefreshInterval then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


        aiBrain[reftFirebasesWantingFortification] = {}
        if M27Utilities.IsTableEmpty(aiBrain[reftFirebaseUnitsByFirebaseRef]) == false then
            --Check all existing units assigned to a firebase are still valid
            for iFirebase, tFirebaseUnits in aiBrain[reftFirebaseUnitsByFirebaseRef] do
                for iUnit, oUnit in tFirebaseUnits do
                    if not(M27UnitInfo.IsUnitValid(oUnit)) then
                        tFirebaseUnits[iUnit] = nil
                    end
                end
            end
        end

        --Cycle through all PD and Arti and assign to a firebase
        local tPDAndArti = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT2PlusPD + M27UnitInfo.refCategoryFixedT2Arti, false, false)
        local tNearbyDefences
        local iExistingFirebaseRef
        if M27Utilities.IsTableEmpty(tPDAndArti) == false then
            for iUnit, oUnit in tPDAndArti do
                if bDebugMessages == true then LOG(sFunctionRef..': Cycling through T2 PD+Arti, Unit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Assigned firebase='..(oUnit[refiAssignedFirebase] or 'nil')) end
                if not(oUnit[refiAssignedFirebase]) then
                    iExistingFirebaseRef = nil
                    --Do we have lots of PD and arti near this?
                    tNearbyDefences = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2PlusPD + M27UnitInfo.refCategoryFixedT2Arti, oUnit:GetPosition(), 30, 'Ally')
                    if M27Utilities.IsTableEmpty(tNearbyDefences) == false and table.getn(tNearbyDefences) >= 3 then
                        for iPD, oPD in tNearbyDefences do
                            if bDebugMessages == true then LOG(sFunctionRef..': Going through nearby defences, oPD='..oPD.UnitId..M27UnitInfo.GetUnitLifetimeCount(oPD)..'; Distance to oUnit='..M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), oPD:GetPosition())..'; oPD[refiAssignedFirebase]='..(oPD[refiAssignedFirebase] or 'nil')) end
                            if oPD[refiAssignedFirebase] then
                                iExistingFirebaseRef = oPD[refiAssignedFirebase]
                                break
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Have at least 3 PD or T2 arti nearby; size of table='..table.getn(tNearbyDefences)..';  after going through each of htese, iExistingFirebaseRef='..(iExistingFirebaseRef or 'nil')) end

                        if iExistingFirebaseRef then
                            for iPD, oPD in tNearbyDefences do
                                if not(oPD[refiAssignedFirebase]) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Assigning oPD='..oPD.UnitId..M27UnitInfo.GetUnitLifetimeCount(oPD)..' to firebase '..iExistingFirebaseRef) end
                                    AssignUnitToFirebase(aiBrain, oPD, iExistingFirebaseRef)
                                end
                            end
                        else
                            --Create a new firebase ref
                            if bDebugMessages == true then LOG(sFunctionRef..': None of hte units have an assigned firebase so will create a new one') end
                            TrackNewFirebase(aiBrain, tNearbyDefences)
                        end
                    end
                end
                --If unit is a veteran and is damaged, flag it to request mobile shield

                if oUnit.Sync.VeteranLevel > 0 then
                    if oUnit:GetHealth() / oUnit:GetMaxHealth() < 0.97 then
                        aiBrain[M27PlatoonFormer.reftPriorityUnitsForShielding][oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)] = oUnit
                    else
                        aiBrain[M27PlatoonFormer.reftPriorityUnitsForShielding][oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)] = nil
                    end
                end
            end
        else
            aiBrain[reftFirebaseUnitsByFirebaseRef] = {}
            if bDebugMessages == true then LOG(sFunctionRef..': No T2 PD or T2 arti so clearing all firebase tracking') end
        end

        --Cycle through each firebase and decide if it wants fortification (e.g. T2 Arti or fixed shield)
        aiBrain[refiFirebaseCategoryWanted] = {}
        local tSMD
        if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers]) == false then tSMD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategorySMD, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.refiDistanceToNearestEnemyBase], 'Ally') end

        if bDebugMessages == true then LOG(sFunctionRef..': Is table of units by firebase ref empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftFirebaseUnitsByFirebaseRef]))) end
        if M27Utilities.IsTableEmpty(aiBrain[reftFirebaseUnitsByFirebaseRef]) == false then
            local tEnemyT2PlusIndirect = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryIndirectT2Plus + M27UnitInfo.refCategorySniperBot, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.refiDistanceToNearestEnemyBase], 'Enemy')
            local iEnemyT2PlusIndirect = 0
            if M27Utilities.IsTableEmpty(tEnemyT2PlusIndirect) == false then iEnemyT2PlusIndirect = table.getn(tEnemyT2PlusIndirect) end
            local bWantFortification = false

            function CheckForNearbySupportUnits(aiBrain, iFirebaseRef, tLocation, iCategory, iRange, iSupportUnitsWanted)
                local tSupportUnits = aiBrain:GetUnitsAroundPoint(iCategory, tLocation, iRange, 'Ally')
                local iValidSupportUnits = 0
                if M27Utilities.IsTableEmpty(tSupportUnits) == false then
                    for iUnit, oUnit in tSupportUnits do
                        if not(oUnit[refiAssignedFirebase]) then
                            AssignUnitToFirebase(aiBrain, oUnit, iFirebaseRef)
                            iValidSupportUnits = iValidSupportUnits + 1
                        elseif oUnit[refiAssignedFirebase] == iFirebaseRef then iValidSupportUnits = iValidSupportUnits + 1
                        end
                    end
                end
                if iValidSupportUnits < iSupportUnitsWanted then
                    bWantFortification = true
                    aiBrain[refiFirebaseCategoryWanted][iFirebaseRef] = iCategory
                    if bDebugMessages == true then LOG(sFunctionRef..': Have set the category to be built and flagged we want fortification.  iFirebaseRef='..iFirebaseRef..'; Is table of category wanted empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[refiFirebaseCategoryWanted][iFirebaseRef], false))..'; table of units that meet this category='..repru(EntityCategoryGetUnitList(iCategory))) end
                end
            end

            if not(aiBrain[reftFirebasePosition]) then aiBrain[reftFirebasePosition] = {} end
            local bCoveredBySMD = false
            local oClosestUnitToFirebase
            local tExistingT2Arti

            if bDebugMessages == true then LOG(sFunctionRef..': Will cycle through each firebase and determine if it needs fortifying') end
            local tFirebaseUnits
            local iFirebaseUnits = 0
            local oPartCompleteUnit

            local oClosestUnitToEnemyBase, oShieldPlatoonToReassign, iCurDistance, iClosestDistance
            local oSecondClosestUnitToEnemyBase, iSecondClosestDistance

            local bConsiderMobileShieldsForAllUnits = false



            for iFirebaseRef, tFirebaseStringKeyUnits in aiBrain[reftFirebaseUnitsByFirebaseRef] do
                if not(aiBrain:GetFactionIndex() == M27UnitInfo.refFactionCybran) and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle and iFirebaseRef == aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef] then
                    bConsiderMobileShieldsForAllUnits = true
                end

                bWantFortification = false
                --First convert table to sequentially numbered so entitycategoryfilterdown works:
                tFirebaseUnits = {}
                local iMassInvested = 0
                oClosestUnitToEnemyBase = nil

                iClosestDistance = 10000
                --oShieldPlatoonToReassign = nil

                --Convert to a normal table and at the same time get info where would need to cycle through each unit
                for iUnit, oUnit in tFirebaseStringKeyUnits do
                    iFirebaseUnits = iFirebaseUnits + 1
                    tFirebaseUnits[iFirebaseUnits] = oUnit
                    if oUnit:GetFractionComplete() < 1 and oUnit:GetFractionComplete() > 0.02 then oPartCompleteUnit = oUnit end
                    iMassInvested = iMassInvested + oUnit:GetBlueprint().Economy.BuildCostMass
                    iCurDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                    if iCurDistance < iClosestDistance then
                        if iFirebaseUnits > 1 then
                            oSecondClosestUnitToEnemyBase = oClosestUnitToEnemyBase
                            iSecondClosestDistance = iClosestDistance
                        end
                        oClosestUnitToEnemyBase = oUnit
                        iClosestDistance = iCurDistance
                    end

                    --if oUnit[M27PlatoonUtilities.refoSupportingShieldPlatoon] and aiBrain:PlatoonExists(oUnit[M27PlatoonUtilities.refoSupportingShieldPlatoon]) then
                    --oShieldPlatoonToReassign = oUnit[M27PlatoonUtilities.refoSupportingShieldPlatoon]
                    --end

                    if bConsiderMobileShieldsForAllUnits and not(M27Logic.IsLocationUnderFriendlyFixedShield(aiBrain, oUnit:GetPosition())) and EntityCategoryContains(categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL, oUnit.UnitId) then
                        aiBrain[M27PlatoonFormer.reftPriorityUnitsForShielding][oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)] = oUnit
                        oUnit[M27PlatoonTemplates.refbWantsShieldEscort] = true
                    else
                        if aiBrain[M27PlatoonFormer.reftPriorityUnitsForShielding][oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)] then aiBrain[M27PlatoonFormer.reftPriorityUnitsForShielding][oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)] = nil end
                        oUnit[M27PlatoonTemplates.refbWantsShieldEscort] = false --Shield platoon will automatically ignore/disband if the unit it is shielding has this set to false; will change back to true for then earest unti in a moment
                    end
                end
                if oClosestUnitToEnemyBase then
                    aiBrain[M27PlatoonFormer.reftPriorityUnitsForShielding][oClosestUnitToEnemyBase.UnitId..M27UnitInfo.GetUnitLifetimeCount(oClosestUnitToEnemyBase)] = oClosestUnitToEnemyBase
                    oClosestUnitToEnemyBase[M27PlatoonTemplates.refbWantsShieldEscort] = true
                    --if oShieldPlatoonToReassign and not(oClosestUnitToEnemyBase[M27PlatoonUtilities.refoSupportingShieldPlatoon] and oClosestUnitToEnemyBase[M27PlatoonUtilities.refoSupportingShieldPlatoon] == oShieldPlatoonToReassign) then
                    --oShieldPlatoonToReassign[M27PlatoonUtilities.refiCurrentAction] = M27PlatoonUtilities.refActionDisband
                    --end
                end
                if iFirebaseUnits >= 6 and oSecondClosestUnitToEnemyBase then
                    aiBrain[M27PlatoonFormer.reftPriorityUnitsForShielding][oSecondClosestUnitToEnemyBase.UnitId..M27UnitInfo.GetUnitLifetimeCount(oSecondClosestUnitToEnemyBase)] = oSecondClosestUnitToEnemyBase
                    oSecondClosestUnitToEnemyBase[M27PlatoonTemplates.refbWantsShieldEscort] = true
                end




                if bDebugMessages == true then
                    LOG(sFunctionRef..': Will list out every unti in iFirebaseRef='..iFirebaseRef..':')
                    for iUnit, oUnit in tFirebaseUnits do
                        LOG(sFunctionRef..': '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit))
                    end
                    LOG(sFunctionRef..': If filter to just structures with entity category filter down does this show as empty='..tostring(M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.STRUCTURE, tFirebaseUnits))))
                end
                local tFirebaseShields = EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedShield, tFirebaseUnits)
                local tT2PlusPD = EntityCategoryFilterDown(M27UnitInfo.refCategoryT2PlusPD, tFirebaseUnits)

                if iFirebaseRef == aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef] then
                    aiBrain[reftFirebasePosition][iFirebaseRef] = aiBrain[M27MapInfo.reftChokepointBuildLocation]
                elseif M27Utilities.IsTableEmpty(tFirebaseShields) == false then
                    aiBrain[reftFirebasePosition][iFirebaseRef] = M27Utilities.GetAveragePosition(tFirebaseShields)
                end
                if M27Utilities.IsTableEmpty(tT2PlusPD) == false then
                    local tPDDistToEnemy = {}
                    local tClosestPDUnits = {}
                    local iClosestPDCount = 0
                    for iUnit, oUnit in tT2PlusPD do
                        tPDDistToEnemy[iUnit] = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), M27MapInfo.GetPrimaryEnemyBaseLocation(aiBrain))
                    end
                    for iUnit, iDistance in M27Utilities.SortTableByValue(tPDDistToEnemy, false) do
                        iClosestPDCount = iClosestPDCount + 1
                        tClosestPDUnits[iClosestPDCount] = tT2PlusPD[iUnit]
                        if iClosestPDCount >= 3 then break end
                    end

                    if M27Utilities.IsTableEmpty(tFirebaseShields) then aiBrain[reftFirebasePosition][iFirebaseRef] = M27Utilities.GetAveragePosition(tClosestPDUnits) end
                    aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef] = M27Utilities.GetAveragePosition(tClosestPDUnits)
                else --Redundancy
                    if M27Utilities.IsTableEmpty(aiBrain[reftFirebasePosition][iFirebaseRef]) then aiBrain[reftFirebasePosition][iFirebaseRef] = M27Utilities.GetAveragePosition(tFirebaseUnits) end
                    if M27Utilities.IsTableEmpty(aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef]) then aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef] = M27Utilities.GetAveragePosition(tFirebaseUnits) end
                end


                if bDebugMessages == true then LOG(sFunctionRef..': Considering firebase with ref='..iFirebaseRef..' and tFirebaseUnits with a size '..table.getsize(tFirebaseUnits)..'; Firebase average position='..repru(aiBrain[reftFirebasePosition][iFirebaseRef])) end
                local tSupportUnits
                --Check if we want to build extra units to fortify the firebase

                --Highest priority - 2 T2 PD (in case original PD were destroyed)
                if table.getsize(tT2PlusPD) < 2 then
                    CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebasePosition][iFirebaseRef], M27UnitInfo.refCategoryT2PlusPD, 30, 2)
                    if bDebugMessages == true then LOG(sFunctionRef..': bWantFortification after checking if have fewer than 2 T2 PD='..tostring(bWantFortification)) end
                end

                --Next highest priority - part complete units
                if not(bWantFortification) and M27UnitInfo.IsUnitValid(oPartCompleteUnit) then
                    CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebasePosition][iFirebaseRef], M27UnitInfo.GetCategoryConditionFromUnitID(oPartCompleteUnit.UnitId), 10, 20)
                    if bDebugMessages == true then LOG(sFunctionRef..': bWantFortification after checking if have part complete units='..tostring(bWantFortification)) end
                end
                if not(bWantFortification) then
                    --Shield provided have enough energy
                    if not(bWantFortification) and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 100 and aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] > 20 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedShield, tFirebaseUnits)) then
                        CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef], M27UnitInfo.refCategoryFixedShield, 20, 1)
                        if bDebugMessages == true then LOG(sFunctionRef..': Do we want fortification after checking for fixed shields='..tostring(bWantFortification)) end
                    end
                    --TMD if enemy has MMLs or TML
                    if not(bWantFortification) and (M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyTML]) == false or (iEnemyT2PlusIndirect > 0 and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.SILO, tEnemyT2PlusIndirect)) == false)) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Enemy has missile units, so checking if have TMD near base.  Is table of TMD empty='..tostring(M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryTMD, tFirebaseUnits)))) end
                        if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryTMD, tFirebaseUnits)) == false then
                            for iUnit, oUnit in EntityCategoryFilterDown(M27UnitInfo.refCategoryTMD, tFirebaseUnits) do
                                if bDebugMessages == true then LOG(sFunctionRef..': Existing TMD assigned to firebase: ref='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Position='..repru(oUnit:GetPosition())..'; PD front position='..repru(aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef])..'; Distance to front PD postiion='..M27Utilities.GetDistanceBetweenPositions(aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef], oUnit:GetPosition())..'; Firebase position='..repru(aiBrain[reftFirebasePosition][iFirebaseRef])) end
                            end
                        end
                        CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef], M27UnitInfo.refCategoryTMD, 30, 1)
                        if not(bWantFortification) then
                            --Do we have at least 4k mass invested in the firebase and dont have any TMD near the front 3 T2 PD? If not then build a second PD
                            if iMassInvested >= 4000 and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryTMD, aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef], 20, 'Ally')) then
                                CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef], M27UnitInfo.refCategoryTMD, 30, 2)
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Do we want fortification after checking for TMD='..tostring(bWantFortification)) end
                    end
                    if bDebugMessages == true and not(bWantFortification) then LOG(sFunctionRef..': About to see if want our first t2 arti. iEnemyT2PlusIndirect='..iEnemyT2PlusIndirect..'; iMassInvested='..iMassInvested..'; Size of tT2PlusPD='..table.getsize(tT2PlusPD)..'; Is tfirebase units table of fixed t2 arti empty='..tostring(M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedT2Arti, tFirebaseUnits)))) end
                    if not(bWantFortification) and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 4 and (iEnemyT2PlusIndirect > 0 or iMassInvested >= 7000 or table.getsize(tT2PlusPD) >= 5) and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedT2Arti, tFirebaseUnits)) then
                        CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebasePosition][iFirebaseRef], M27UnitInfo.refCategoryFixedT2Arti, 50, 1)
                        if bDebugMessages == true then LOG(sFunctionRef..': Do we want fortification after checking for initial Arti='..tostring(bWantFortification)) end
                    end
                    --SAM
                    if not(bWantFortification) and aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 and aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] >= 2500 and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryStructureAA * categories.TECH3, tFirebaseUnits)) then
                        CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebasePosition][iFirebaseRef], M27UnitInfo.refCategoryStructureAA * categories.TECH3, 35, 1)
                        if bDebugMessages == true then LOG(sFunctionRef..': Do we want fortification after checking for enemy air='..tostring(bWantFortification)) end
                    end
                    --T1 radar if lack intel
                    local iIntelCoverage = M27Logic.GetIntelCoverageOfPosition(aiBrain, aiBrain[reftFirebasePosition][iFirebaseRef], nil, true)
                    local iRadarCat
                    if iIntelCoverage <= 75 then iRadarCat = M27UnitInfo.refCategoryT1Radar
                    else iRadarCat = M27UnitInfo.refCategoryT2Radar
                    end

                    if bDebugMessages == true then LOG(sFunctionRef..': bWantFortification before checking if want radar='..tostring(bWantFortification)..'; iIntelCoverage='..iIntelCoverage) end
                    if not(bWantFortification) and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(iRadarCat, tFirebaseUnits)) then
                        --Do we lack intel coverage of at least 90?

                        if iIntelCoverage <= 90 or (iIntelCoverage <= 150 and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 350) then
                            CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebasePosition][iFirebaseRef], iRadarCat, 40, 1)
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Intel coverage of firebase='..iIntelCoverage..'; bWantFortification after checking for radar='..tostring(bWantFortification)) end
                    end

                    if not(bWantFortification) and aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 400 then
                        --Get T3 shield if have significant mass invested in firebase

                        if bDebugMessages == true then LOG(sFunctionRef..': Deciding if we want T3 shield or SMD in the firebase. iMassInvested='..iMassInvested..'; Is the table of firebase units filtered to T3 shields empty='..tostring(M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedShield * categories.TECH3, tFirebaseUnits)))..'; Is the table filtered for SMD empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers]))) end

                        if iMassInvested >= 10000 and aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] >= 50 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedShield * categories.TECH3, tFirebaseUnits)) then
                            CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef], M27UnitInfo.refCategoryFixedShield * categories.TECH3, 30, 1)
                        end

                        --SMD
                        if not(bWantFortification) and iMassInvested >= 15000 and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers]) == false and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 500 then
                            --Are we protected by SMD?
                            bCoveredBySMD = false

                            if M27Utilities.IsTableEmpty(tSMD) == false then
                                oClosestUnitToFirebase = M27Utilities.GetNearestUnit(tFirebaseUnits, aiBrain[reftFirebasePosition][iFirebaseRef], aiBrain)
                                if oClosestUnitToFirebase then
                                    bCoveredBySMD = IsUnitCoveredBySMD(aiBrain, oClosestUnitToFirebase, tSMD, aiBrain[M27Overseer.reftEnemyNukeLaunchers])
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': Just considered if closest unit to firebase is covered by SMD. oClosestUnitToFirebase='..oClosestUnitToFirebase.UnitId..M27UnitInfo.GetUnitLifetimeCount(oClosestUnitToFirebase)..'; bCoveredBySMD='..tostring(bCoveredBySMD or false)) end
                            end
                            if not(bCoveredBySMD) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Will check for if we have SMD within 65 of here, and if not then will say we want to build SMD') end
                                CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebasePosition][iFirebaseRef], M27UnitInfo.refCategorySMD, 65, 1)
                            end
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': WIll consider whether we want more T2 arti if they are effective and we have eco.  bWantFortification='..tostring(bWantFortification)..'; aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]='..aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]) end
                    if not(bWantFortification) and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 5 then
                        --More T2 Arti (if are effective)
                        tExistingT2Arti = EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedT2Arti, tFirebaseUnits)
                        local iExistingT2Arti = 0
                        local iPDToArtiRatioWanted = 1
                        if aiBrain[M27Overseer.refiTotalEnemyShortRangeThreat] >= 20000 then iPDToArtiRatioWanted = 4 end
                        if M27Utilities.IsTableEmpty(tExistingT2Arti) == false then iExistingT2Arti = table.getsize(tExistingT2Arti) end
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering if we want more T2 arti based on how effective they are.  Is table of firebase units filtered to T2 arti empty='..tostring(M27Utilities.IsTableEmpty(tExistingT2Arti))..'; Size of T2 Arti='..table.getsize(tExistingT2Arti)..'; Size of T2 PD='..table.getsize(tT2PlusPD)..'; iPDToArtiRatioWanted='..iPDToArtiRatioWanted) end
                        if iExistingT2Arti > 0 or (M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyLandExperimentals]) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFatboy, aiBrain[M27Overseer.reftEnemyLandExperimentals])) == false and M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[reftFirebasePosition][iFirebaseRef]) <= math.max(75, math.min(200, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]))) then
                            if (M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyLandExperimentals]) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFatboy, aiBrain[M27Overseer.reftEnemyLandExperimentals])) == false) or (iExistingT2Arti <= 14 and table.getsize(tT2PlusPD) >= table.getsize(tExistingT2Arti) * iPDToArtiRatioWanted) then
                                local iTotalMassKilled = 0
                                local iTotalMassCost = 0
                                local iArtiWithNoKills = 0
                                if M27Utilities.IsTableEmpty(tExistingT2Arti) == false then
                                    for iUnit, oUnit in tExistingT2Arti do
                                        if M27UnitInfo.IsUnitValid(oUnit) then
                                            iTotalMassKilled = iTotalMassKilled + (oUnit.Sync.totalMassKilled or 0)
                                            iTotalMassCost = iTotalMassCost + oUnit:GetBlueprint().Economy.BuildCostMass
                                            if (oUnit.Sync.totalMassKilled or 0) <= 150 then
                                                iArtiWithNoKills = iArtiWithNoKills + 1
                                            end
                                        end
                                    end
                                end
                                local iPercentFactor = 1
                                --Increase the amount of mass we want to have killed to build more if we have low mass
                                if M27Conditions.HaveLowMass(aiBrain) then
                                    if aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] <= 10 then iPercentFactor = 2.5
                                    else iPercentFactor = 1.75
                                    end
                                end
                                if iTotalMassCost > aiBrain[M27Overseer.refiTotalEnemyLongRangeThreat] * 2 then iPercentFactor = iPercentFactor * 1.75 end

                                if bDebugMessages == true then LOG(sFunctionRef..': iArtiWithNoKills='..iArtiWithNoKills..'; iTotalMassKilled='..iTotalMassKilled..'; iTotalMassCost='..iTotalMassCost..'; iPercentFactor='..iPercentFactor) end
                                if (iTotalMassKilled >= iTotalMassCost * 0.65 * iPercentFactor and iArtiWithNoKills == 0) or (iTotalMassKilled >= iTotalMassCost * 0.85 * iPercentFactor and iArtiWithNoKills <= 1) or (iTotalMassKilled >= iTotalMassCost * iPercentFactor and iArtiWithNoKills <= 2) or (iTotalMassCost <= 22000 and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyLandExperimentals]) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFatboy, aiBrain[M27Overseer.reftEnemyLandExperimentals])) == false) or (iTotalMassKilled >= iTotalMassCost * 2.5 * iPercentFactor and iArtiWithNoKills <= 5) then
                                    bWantFortification = true
                                    aiBrain[refiFirebaseCategoryWanted][iFirebaseRef] = M27UnitInfo.refCategoryFixedT2Arti
                                    if bDebugMessages == true then LOG(sFunctionRef..': Want to build more T2 arti at firebase') end
                                end
                            end
                        end
                    end
                        --TML if lifetime nubmer built is <=1 and dont already have action to build TML at base (so avoid keep tyring to build tml at firebase if they keep dying, and allow both 1 tml at main base and 1 at firebase)
                        if not(bWantFortification) and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildTML]) and M27Conditions.GetLifetimeBuildCount(aiBrain, M27UnitInfo.refCategoryTML) <= 1 and GetGameTimeSeconds() - (aiBrain[refiTimeOfLastFailedTML] or -300) >= 300 and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryTML, tFirebaseUnits)) then
                            local tPotentialTargets = aiBrain:GetUnitsAroundPoint(iTMLHighPriorityCategories, aiBrain[reftFirebasePosition][iFirebaseRef], 241, 'Enemy') --Range is 256, so this gives a buffer for if we are built a bit further from the firebase
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering if want TML. Table of potential targets is empty='..tostring(M27Utilities.IsTableEmpty(tPotentialTargets))) end
                            if M27Utilities.IsTableEmpty(tPotentialTargets) == false then
                                local iValidTargets = 0
                                local tEnemyTMD = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryTMD, aiBrain[reftFirebasePosition][iFirebaseRef], 241 + 31, 'Enemy')
                                for iUnit, oUnit in tPotentialTargets do
                                    if bDebugMessages == true then LOG(sFunctionRef..': Considering whether oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' is a valid TML target.  Is table of TMD empty='..tostring(M27Utilities.IsTableEmpty(tEnemyTMD))) end
                                    if IsValidTMLTarget(aiBrain, aiBrain[reftFirebasePosition][iFirebaseRef], oUnit, tEnemyTMD) then
                                        iValidTargets = iValidTargets + 1
                                        aiBrain[reftoTMLTargetsOfInterest][iValidTargets] = oUnit
                                        if bDebugMessages == true then LOG(sFunctionRef..': Have a valid target, iValidTargets='..iValidTargets..'; recording for oUnit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                                    end
                                end
                                if iValidTargets >= 2 then
                                    CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebasePosition][iFirebaseRef], M27UnitInfo.refCategoryTML, 50, 1)
                                end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': bWantFortification after checking if want TML='..tostring(bWantFortification)) end
                        end

                        --Second shield
                        if iMassInvested >= 4000 and aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] >= 50 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99 and (not(M27Conditions.HaveLowMass(aiBrain)) or M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.reftLocationFromStartNearestThreat], aiBrain[reftFirebasePosition][iFirebaseRef]) <= 100) and table.getn(EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedShield, tFirebaseUnits)) <= 1 then
                            CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebasePosition][iFirebaseRef], M27UnitInfo.refCategoryFixedShield * categories.TECH2, 35, 2)
                        end


                        --T2 arti - other conditions - enemy T2 structure in likely arti range?
                        if not(bWantFortification) then
                            local tNearbyEnemyStructures = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure * categories.TECH2 + M27UnitInfo.refCategoryStructure * categories.TECH3 + M27UnitInfo.refCategoryStructure * categories.EXPERIMENTAL, aiBrain[reftFirebasePosition][iFirebaseRef], 128, 'Enemy')
                            if M27Utilities.IsTableEmpty(tNearbyEnemyStructures) == false then
                                local tNearbyEnemyShieldsAndArti = EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedShield + M27UnitInfo.refCategoryFixedT2Arti, tNearbyEnemyStructures)
                                local iNearbyEnemyShields = 0
                                if M27Utilities.IsTableEmpty(tNearbyEnemyShieldsAndArti) == false then iNearbyEnemyShields = table.getn(tNearbyEnemyShieldsAndArti) end
                                local iMinT2ArtiWanted = 1
                                if iNearbyEnemyShields >= 2 then
                                    iMinT2ArtiWanted = 6
                                elseif iNearbyEnemyShields == 1 then
                                    iMinT2ArtiWanted = 3
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': iNearbyEnemyShieldsAndArti='..iNearbyEnemyShields..'; iMinT2ArtiWanted='..iMinT2ArtiWanted) end
                                CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebasePosition][iFirebaseRef], M27UnitInfo.refCategoryFixedT2Arti, 50, iMinT2ArtiWanted)
                            end
                        end

                        if not(bWantFortification) and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 3 then
                            --Do we want more T1/T2/T3 PD at this specific firebase? (up to 10 T2+ PD, or 25 if enemy has at least 20k threat)
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': Checking if want T1+ PD at the firebase.  Is the table of filtered PD empty='..tostring(M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryPD, tFirebaseUnits))))

                                if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryPD, tFirebaseUnits)) then
                                    LOG(sFunctionRef..': Something has gone wrong as we shoudl ahve PD.  Will list out every unti in iFirebaseRef='..iFirebaseRef..' again:')
                                    for iUnit, oUnit in tFirebaseUnits do
                                        LOG(sFunctionRef..': '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Does this contain PD category='..tostring(EntityCategoryContains(M27UnitInfo.refCategoryPD, oUnit.UnitId))..'; Is a table containing just this unit filtered for PD empty='..tostring(M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryPD, { oUnit }))))
                                    end
                                end
                            end

                            if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryPD, tFirebaseUnits)) == false then
                                if M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryPD * categories.TECH1, tFirebaseUnits)) then
                                    CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef], M27UnitInfo.refCategoryPD * categories.TECH1, 25, 1)
                                end
                                if bDebugMessages == true then
                                    LOG(sFunctionRef .. ': First checking for T1 PD, is table empty=' .. tostring(M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryPD * categories.TECH1, tFirebaseUnits))) .. '; bWantFortification after checking for t1 PD=' .. tostring(bWantFortification))
                                end
                                if not (bWantFortification) then
                                    local tT2PlusPD = EntityCategoryFilterDown(M27UnitInfo.refCategoryT2PlusPD, tFirebaseUnits)
                                    local iT2PlusPD = 0
                                    if M27Utilities.IsTableEmpty(tT2PlusPD) == false then iT2PlusPD = table.getn(tT2PlusPD) end
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Size of T2PlusPD table=' .. iT2PlusPD)
                                    end
                                    if M27Utilities.IsTableEmpty(tT2PlusPD) or iT2PlusPD < 3 then
                                        CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef], M27UnitInfo.refCategoryPD * categories.TECH2, 35, 3)
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': bWantFortification after checking for at least 3 TdPlusPD=' .. tostring(bWantFortification))
                                        end
                                    else
                                        local iTotalMassKilled = (aiBrain[reftiFirebaseDeadPDMassKills][iFirebaseRef] or 0)
                                        local iTotalMassCost = (aiBrain[reftiFirebaseDeadPDMassCost][iFirebaseRef] or 0)
                                        local iPDWithNoKills = 0
                                        if bDebugMessages == true then LOG(sFunctionRef..': About to calculate mass killed and cost of all PD in the firebase.  Initial values based on dead PD are a cost of '..iTotalMassCost..' and total mass kills of '..iTotalMassKilled) end
                                        for iUnit, oUnit in tT2PlusPD do
                                            if M27UnitInfo.IsUnitValid(oUnit) then
                                                iTotalMassKilled = iTotalMassKilled + (oUnit.Sync.totalMassKilled or 0)
                                                iTotalMassCost = iTotalMassCost + oUnit:GetBlueprint().Economy.BuildCostMass
                                                if (oUnit.Sync.totalMassKilled or 0) <= 25 then
                                                    iPDWithNoKills = iPDWithNoKills + 1
                                                end
                                                if bDebugMessages == true then LOG(sFunctionRef..': oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; Unit mass killed='..(oUnit.Sync.totalMassKilled or 0)..'; iTotalMassKilled='..iTotalMassKilled..'; iTotalMassCost='..iTotalMassCost..'; iPDWithNoKills='..iPDWithNoKills) end
                                            end
                                        end
                                        local iPercentFactor = 1
                                        if iTotalMassCost > aiBrain[M27Overseer.refiTotalEnemyShortRangeThreat] then iPercentFactor = iPercentFactor * 1.5 end
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': Finished considering if we want more PD for the firebase. iTotalMassKilled=' .. iTotalMassKilled .. '; iTotalMassCost=' .. iTotalMassCost .. '; iPDWithNoKills=' .. iPDWithNoKills)
                                        end
                                        if iTotalMassKilled > iTotalMassCost * iPercentFactor and (iPDWithNoKills <= 1 or (iPDWithNoKills <= 4 and iTotalMassKilled > iTotalMassCost * 2 * iPercentFactor) or (iPDWithNoKills <= 8 and iTotalMassKilled > iTotalMassCost * 4 * iPercentFactor)) then
                                            local iMaxT2PD = 10
                                            if aiBrain[M27Overseer.refiTotalEnemyShortRangeThreat] >= 20000 then iMaxT2PD = 25 end
                                            CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef], M27UnitInfo.refCategoryT2PlusPD, 35, iMaxT2PD)
                                            if bDebugMessages == true then
                                                LOG(sFunctionRef ..': bWantFortification after checking if we have < iMaxT2PD='..iMaxT2PD..'; WantFortification='..tostring(bWantFortification))
                                            end
                                        end
                                    end
                                else
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef .. ': Want to get T1 PD for firebase')
                                    end
                                end
                            end
                        end
                        --More AA defences
                        if not(bWantFortification) and (iMassInvested >= 3000 or (aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] >= 800 and aiBrain[M27AirOverseer.refiAirAANeeded] > 0)) then
                            local iAAWanted = 1
                            local iAACategory = M27UnitInfo.refCategoryStructureAA - categories.TECH1
                            if aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 then
                                iAACategory = M27UnitInfo.refCategoryStructureAA * categories.TECH3
                                local iMassPerAA = 3000
                                if aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] >= 6000 and iMassInvested >= 4000 then
                                    iMassPerAA = 2500
                                    --Have we lost air control?
                                    if aiBrain[M27AirOverseer.refiAirAAWanted] > 5 and (aiBrain[M27AirOverseer.refiAirAANeeded] >= 3 or aiBrain[M27AirOverseer.refiOurMassInAirAA] < aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] * 0.75) then
                                        iMassPerAA = 1500
                                    end
                                end

                                iAAWanted = math.min(16, math.max(aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] / iMassPerAA, iMassInvested / 8000))
                                if bDebugMessages == true then LOG(sFunctionRef..': Have access to T3, iMassPerAA wanted='..iMassPerAA..'; iAAWanted='..iAAWanted..'; Highest enemy air threat='..aiBrain[M27AirOverseer.refiHighestEnemyAirThreat]..'; iMassInvested='..iMassInvested..'; AirAA Needed='..aiBrain[M27AirOverseer.refiAirAANeeded]..'; AirAA Wanted='..aiBrain[M27AirOverseer.refiAirAAWanted]) end
                            end
                            CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebasePosition][iFirebaseRef], iAACategory, 40, iAAWanted)
                        end

                        if not(bWantFortification) and iFirebaseRef == aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef] then
                            --Do we want more based on our threat?
                            if bDebugMessages == true then LOG(sFunctionRef..': Dealing with chokepoint, will see if we have enough threat in the chokepoint to handle the enemy. aiBrain[M27Overseer.refiTotalEnemyLongRangeThreat]='..aiBrain[M27Overseer.refiTotalEnemyLongRangeThreat]..'; aiBrain[M27Overseer.refiTotalEnemyShortRangeThreat]='..aiBrain[M27Overseer.refiTotalEnemyShortRangeThreat]) end
                            if aiBrain[M27Overseer.refiTotalEnemyLongRangeThreat] >= 50 or aiBrain[M27Overseer.refiTotalEnemyShortRangeThreat] > 1250 then
                                local tiCategoriesWanted = {[M27Overseer.refiTotalEnemyShortRangeThreat] = M27UnitInfo.refCategoryPD + M27UnitInfo.refCategoryFixedShield, [M27Overseer.refiTotalEnemyLongRangeThreat] = M27UnitInfo.refCategoryFixedT2Arti}
                                local tiUnitCap = {[M27Overseer.refiTotalEnemyShortRangeThreat] = 35, [M27Overseer.refiTotalEnemyLongRangeThreat] = 14}
                                if aiBrain[M27Overseer.refiTotalEnemyShortRangeThreat] >= 20000 then tiUnitCap[M27Overseer.refiTotalEnemyShortRangeThreat] = math.max(tiUnitCap[M27Overseer.refiTotalEnemyShortRangeThreat], 55) end
                                local tOurUnitsOfRelevance
                                local iCurMassTotal
                                local tiOurThreatVsEnemyThreat = {}
                                local iLowestRatio = 10000
                                local sRefWanted
                                local iRatioWanted = 0.8
                                if M27Conditions.HaveLowMass(aiBrain) and M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat + M27UnitInfo.refCategoryIndirect, aiBrain[reftFirebasePosition][iFirebaseRef], 120)) then iRatioWanted = 0.55 end
                                for sThreatVariableRef, iCategory in tiCategoriesWanted do
                                    tOurUnitsOfRelevance = EntityCategoryFilterDown(iCategory, tFirebaseUnits)
                                    --For performance reasons will just get mass cost total
                                    iCurMassTotal = 0.01
                                    if M27Utilities.IsTableEmpty(tOurUnitsOfRelevance) == false then
                                        --Hard caps on the number of units that will build
                                        if table.getn(tOurUnitsOfRelevance) >= tiUnitCap[sThreatVariableRef] then
                                            iCurMassTotal = 1000000
                                        else
                                            for iUnit, oUnit in tOurUnitsOfRelevance do
                                                iCurMassTotal = iCurMassTotal + oUnit:GetBlueprint().Economy.BuildCostMass
                                            end
                                        end
                                    end
                                    tiOurThreatVsEnemyThreat[sThreatVariableRef] = iCurMassTotal / math.max(aiBrain[sThreatVariableRef], 0.001)
                                    if tiOurThreatVsEnemyThreat[sThreatVariableRef] < iLowestRatio then
                                        iLowestRatio = tiOurThreatVsEnemyThreat[sThreatVariableRef]
                                        sRefWanted = sThreatVariableRef
                                    end
                                    if bDebugMessages == true then LOG(sFunctionRef..': Considering sThreatVariableRef='..sThreatVariableRef..'; iCurMassTotal='..iCurMassTotal..'; aiBrain[sThreatVariableRef]='..aiBrain[sThreatVariableRef]..'; tiOurThreatVsEnemyThreat[sThreatVariableRef]='..tiOurThreatVsEnemyThreat[sThreatVariableRef]..'; iLowestRatio='..iLowestRatio..'; tiUnitCap[sRefWanted]='..tiUnitCap[sRefWanted]) end
                                end
                                if iLowestRatio < 0.7 and sRefWanted then
                                    CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef], tiCategoriesWanted[sRefWanted] - M27UnitInfo.refCategoryFixedShield, 50, tiUnitCap[sRefWanted])
                                    if bDebugMessages == true then LOG(sFunctionRef..': Will try and build something to satisfy sRefWanted='..sRefWanted..'; bWantFortification after checking='..tostring(bWantFortification)) end
                                end
                            end
                            --Force the building of ravagers if are UEF and have lots of T2 PD but not many ravagers
                            if not(bWantFortification) and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 14 and aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] >= 150 and aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 500 and EntityCategoryContains(categories.UEF, M27Utilities.GetACU(aiBrain).UnitId) then
                                if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPD * categories.TECH3) <= 5 then
                                    CheckForNearbySupportUnits(aiBrain, iFirebaseRef, aiBrain[reftFirebaseFrontPDPosition][iFirebaseRef], M27UnitInfo.refCategoryPD * categories.TECH3, 40, 3)
                                end
                            end
                        end
                    end
                if bWantFortification then
                    aiBrain[reftFirebasesWantingFortification][iFirebaseRef] = true
                end
                if bDebugMessages == true then LOG(sFunctionRef..': Finished considering if want to fortify firebase. bWantFortification='..tostring(bWantFortification or false)..'; do we have a category assigned to firebase ref '..iFirebaseRef..' - is table empty?='..tostring(M27Utilities.IsTableEmpty(aiBrain[refiFirebaseCategoryWanted][iFirebaseRef], false))..'; is table of firebases wanting fortification empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftFirebasesWantingFortification]))) end
            end
        end

        --If have an assigned chokepoint and not an assigned firebase for it then check if any of the firebases are near the chokepoint
        if aiBrain[M27MapInfo.refiAssignedChokepointCount] and not(aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef]) and not(M27Utilities.IsTableEmpty(aiBrain[reftFirebasePosition])) then
            local iClosestDist = 55 --Dont want to consider if further away than this
            local iCurDist
            local iClosestRef
            for iFirebaseRef, tFirebaseLocation in aiBrain[reftFirebasePosition] do
                iCurDist = M27Utilities.GetDistanceBetweenPositions(tFirebaseLocation, aiBrain[M27MapInfo.reftChokepointBuildLocation])
                if iCurDist < iClosestDist then
                    iClosestRef = iFirebaseRef
                    iClosestDist = iCurDist
                end
            end
            if iClosestRef then
                aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef] = iClosestRef
                --Update teh build location for the chokepoint if this is mroe than 18 away
                if bDebugMessages == true then LOG(sFunctionRef..': Have a firebase with iClosestDist='..iClosestDist..'; If this is far away then will update the firebase position to this. Build location before update='..repru(aiBrain[M27MapInfo.reftChokepointBuildLocation])..'; Firebase location='..repru(aiBrain[reftFirebasePosition][iClosestRef])) end
                if iClosestDist >= 18 then
                    aiBrain[M27MapInfo.reftChokepointBuildLocation] = {aiBrain[reftFirebasePosition][iClosestRef][1], aiBrain[reftFirebasePosition][iClosestRef][2], aiBrain[reftFirebasePosition][iClosestRef][3]}
                end

            end
        end

        aiBrain[refbPotentialFirebaseBuildingChangedSinceLastFirebaseCheck] = false
        aiBrain[refiTimeOfLastFirebaseRefresh] = GetGameTimeSeconds()
        if bDebugMessages == true then LOG(sFunctionRef..': End of code.  Size of table containing firebases with units='..table.getsize(aiBrain[reftFirebaseUnitsByFirebaseRef])) end
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    end
end

function GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetUnclaimedMexes'
    if bDebugMessages == true then LOG(sFunctionRef..': bTreatEnemyMexAsUnclaimed='..tostring(bTreatEnemyMexAsUnclaimed)..'; bTreatOurOrAllyMexAsUnclaimed='..tostring(bTreatOurOrAllyMexAsUnclaimed)..'; bTreatQueuedBuildingAsUnclaimed='..tostring(bTreatQueuedBuildingAsUnclaimed)) end
    --GetUnclaimedMexOrHydro(bMexNotHydro, aiBrain, sPathing, iPathingGroup, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
    return GetUnclaimedMexOrHydro(true, aiBrain, sPathing, iPathingGroup, bTreatEnemyMexAsUnclaimed, bTreatOurOrAllyMexAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
end

function GetUnclaimedHydros(aiBrain, sPathing, iPathingGroup, bTreatEnemyHydroAsUnclaimed, bTreatOurOrAllyHydroAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
    return GetUnclaimedMexOrHydro(false, aiBrain, sPathing, iPathingGroup, bTreatEnemyHydroAsUnclaimed, bTreatOurOrAllyHydroAsUnclaimed, bTreatQueuedBuildingAsUnclaimed)
end

function UpdateShieldingToDefendAgainstArti(aiBrain)
    --Called as a 1-off when T3 arti or novax detected
    local tHighValueBuildings = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryStructure * categories.TECH3 + M27UnitInfo.refCategoryExperimentalStructure, false, false)
    if M27Utilities.IsTableEmpty(tHighValueBuildings) == false then
        local oBP
        local bAddToTableOfUnitsWantingShielding
        for iUnit, oUnit in tHighValueBuildings do
            bAddToTableOfUnitsWantingShielding = false
            if not(oUnit[refbNeedsLargeShield]) then
                oBP = oUnit:GetBlueprint()
                if oBP.Economy.BuildCostMass >= 3000 or oBP.Defense.Health / oBP.Economy.BuildCostMass < 1 then

                    if oBP.Economy.BuildCostMass >= 12000 then
                        if (oUnit[refiShieldsWanted] or 0) <= 1 or not(oUnit[refbNeedsLargeShield]) then
                            oUnit[refiShieldsWanted] = 2
                            bAddToTableOfUnitsWantingShielding = true
                        end
                    else
                        if (oUnit[refiShieldsWanted] or 0) <= 0 or not(oUnit[refbNeedsLargeShield]) then
                            bAddToTableOfUnitsWantingShielding = true
                            oUnit[refiShieldsWanted] = 1
                        end
                    end

                    if bAddToTableOfUnitsWantingShielding then
                        table.insert(aiBrain[reftUnitsWantingFixedShield], oUnit)
                        oUnit[refbNeedsLargeShield] = true
                    end
                end
            end
        end
    end
end

function CheckUnitsStillShielded(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CheckUnitsStillShielded'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if M27Utilities.IsTableEmpty(aiBrain[reftUnitsWithFixedShield]) == false then
        local bChangesMade = true
        local iLoopCount = 0
        local iShieldingWanted, iTotalShieldHealth

        while bChangesMade do
            bChangesMade = false
            iLoopCount = iLoopCount + 1
            if iLoopCount > 100 then
                M27Utilities.ErrorHandler(sFunctionRef..': Likely infinite loop')
                break
            end
            for iUnit, oUnit in aiBrain[reftUnitsWithFixedShield] do
                if not(M27UnitInfo.IsUnitValid(oUnit)) then
                    bChangesMade = true
                    table.remove(aiBrain[reftUnitsWithFixedShield], iUnit)
                    break
                else
                    --Unit is still valid, how much shield protection does it have?
                    iTotalShieldHealth = M27Logic.IsTargetUnderShield(aiBrain, oUnit, 3000, true, true, true)
                    iShieldingWanted = GetShieldHealthWanted(oUnit)

                    if iTotalShieldHealth < iShieldingWanted then
                        bChangesMade = true
                        table.insert(aiBrain[reftUnitsWantingFixedShield], oUnit)
                        table.remove(aiBrain[reftUnitsWithFixedShield], iUnit)
                        break
                    end
                end
            end
            if M27Utilities.IsTableEmpty(aiBrain[reftUnitsWithFixedShield]) then break end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function GetShieldHealthWanted(oUnit)
    local iShieldingWanted = 0
    if oUnit[refbNeedsLargeShield] then
        if EntityCategoryContains(categories.CYBRAN, oUnit.UnitId) then
            iShieldingWanted = (oUnit[refiShieldsWanted] or 1) * 13000 --ED4 shield (in case end up building instead of ED5 - have hopefully fixed though so ED5 gets built, but if not, then having 15k threshold can lead to infinite shielding being built
        else
            iShieldingWanted = (oUnit[refiShieldsWanted] or 1) * 15000
        end
    else iShieldingWanted = (oUnit[refiShieldsWanted] or 0) * 3000
    end
    return iShieldingWanted
end

function MonitorShieldHealth(aiBrain, oShield)
    --Handles pausing and unpausing of any assisting engineers based on shield health
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'MonitorShieldHealth'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if M27Utilities.IsTableEmpty(oShield[reftAssistingEngineers]) == false and not(oShield[refbActiveShieldHealthChecker]) then
        oShield[refbActiveShieldHealthChecker] = true
        local iCurShield, iMaxShield
        while M27UnitInfo.IsUnitValid(oShield) do
            iCurShield, iMaxShield = M27UnitInfo.GetCurrentAndMaximumShield(oShield)
            if iMaxShield > 0 and iCurShield / iMaxShield <= 0.75 then
                if oShield[refbHavePausedAssistingEngineers] then
                    oShield[refbHavePausedAssistingEngineers] = false
                    for iEngi, oEngi in oShield[reftAssistingEngineers] do
                        if M27UnitInfo.IsUnitValid(oEngi) then
                            oEngi:SetPaused(false)
                        end
                    end
                end
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
                WaitSeconds(1)
                M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
            else
                break
            end
        end

        --Dont need shield assisting any more so pause engineers
        oShield[refbHavePausedAssistingEngineers] = true
        for iEngi, oEngi in oShield[reftAssistingEngineers] do
            if M27UnitInfo.IsUnitValid(oEngi) then
                if bDebugMessages == true then LOG(sFunctionRef..': Shield doesnt need repairing so will pause engis so they dont waste resources. oEngi='..oEngi.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngi)..'; UC='..GetEngineerUniqueCount(oEngi)) end
                oEngi:SetPaused(true)
            end
        end

        oShield[refbActiveShieldHealthChecker] = false
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RecordPriorityShields(aiBrain)
    --Records shields that want to ahve engineers assisting
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RecordPriorityShields'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if GetGameTimeSeconds() - (aiBrain[refiTimeOfLastShieldPriorityRefresh] or -100) >= 10 then
        aiBrain[refiTimeOfLastShieldPriorityRefresh] = GetGameTimeSeconds()
        local tShieldsToAssist = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryFixedShield, false, false)
        --First clear any engineers assigned to shields that arent listed as a priority shield from the last update
        if bDebugMessages == true then LOG(sFunctionRef..': WIll refresh list of shields. Is table empty='..tostring(M27Utilities.IsTableEmpty(tShieldsToAssist))..'; do we already have any priority shields when when last ran this? is table empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftPriorityShieldsToAssist]))) end
        if M27Utilities.IsTableEmpty(tShieldsToAssist) == false then
            if M27Utilities.IsTableEmpty(aiBrain[reftPriorityShieldsToAssist]) == false then
                for iShield, oShield in tShieldsToAssist do
                    if M27Utilities.IsTableEmpty(oShield[reftAssistingEngineers]) == false and M27Utilities.IsTableEmpty(aiBrain[reftPriorityShieldsToAssist][oShield.UnitId..M27UnitInfo.GetUnitLifetimeCount(oShield)]) then
                        --Shield wasnt a priority shield in the last cycle but has engineers assigned to assist it - will clear these engineers
                        for iEngi, oEngi in oShield[reftAssistingEngineers] do
                            --if oEngi:IsUnitState('Building') or oEngi:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
                            IssueClearCommands({oEngi})
                            ClearEngineerActionTrackers(aiBrain, oEngi, true)
                        end
                        oShield[reftAssistingEngineers] = {}
                    end
                end
            end


            aiBrain[reftPriorityShieldsToAssist] = {}
            local iTotalUnitMassCoverage
            local tNearbyUnits
            local iCurMassValue
            for iShield, oShield in tShieldsToAssist do
                iTotalUnitMassCoverage = 0
                tNearbyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure, oShield:GetPosition(), oShield:GetBlueprint().Defense.Shield.ShieldSize * 0.5, 'Ally')
                if bDebugMessages == true then LOG(sFunctionRef..': Considering shield '..oShield.UnitId..M27UnitInfo.GetUnitLifetimeCount(oShield)..'; size of table of units nearby='..table.getn(tNearbyUnits)) end
                if M27Utilities.IsTableEmpty(tNearbyUnits) == false then
                    for iUnit, oUnit in tNearbyUnits do
                        if not(oUnit == oShield) then
                            if EntityCategoryContains(M27UnitInfo.refCategorySMD, oUnit.UnitId) and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers]) == false then
                                iCurMassValue = 30000
                            elseif EntityCategoryContains(M27UnitInfo.refCategorySML, oUnit.UnitId) then
                                iCurMassValue = 27500
                            else
                                iCurMassValue = oUnit:GetBlueprint().Economy.BuildCostMass
                            end
                            if M27UnitInfo.IsUnitValid(oUnit[refoPriorityShieldProvidingCoverage]) and not(oUnit[refoPriorityShieldProvidingCoverage] == oShield) then
                                iCurMassValue = iCurMassValue * 0.2
                            end
                            iTotalUnitMassCoverage = iTotalUnitMassCoverage + iCurMassValue
                        end
                    end
                    if bDebugMessages == true then LOG(sFunctionRef..': iTotalUnitMassCoverage='..iTotalUnitMassCoverage) end
                    if iTotalUnitMassCoverage >= 25000 or (iTotalUnitMassCoverage >= 12500 and oShield[refiAssignedFirebase]) then
                        --Add as a priority shield
                        aiBrain[reftPriorityShieldsToAssist][oShield.UnitId..M27UnitInfo.GetUnitLifetimeCount(oShield)] = oShield
                        for iUnit, oUnit in tNearbyUnits do
                            oUnit[refoPriorityShieldProvidingCoverage] = oShield --Deliberately overwrites existing value, means if 2 shields cover same area, and one can justify it even with the ot her, but the other cant, then we wont protect the other
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Adding the shield as a priority shield') end
                    end
                end
            end
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function RefreshUnitsWantingFixedShields(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'RefreshUnitsWantingFixedShields'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local bChangesMade = true
    local iLoopCount = 0

    if M27Utilities.IsTableEmpty(aiBrain[reftUnitsWantingFixedShield]) == false then
        while bChangesMade do
            bChangesMade = false
            iLoopCount = iLoopCount + 1
            if iLoopCount > 100 then
                if iLoopCount > 101 then break end
                M27Utilities.ErrorHandler(sFunctionRef..': Likely infinite loop.  Will run 1 more time with logs enabled then abort') bDebugMessages = true --WANTED FOR DEBUGING
            end
            if bDebugMessages == true then LOG(sFunctionRef..': iLoopCount='..iLoopCount..'; size of units wanting fixed shield='..table.getn(aiBrain[reftUnitsWantingFixedShield])) end
            local iTotalShieldHealth
            local iShieldingWanted
            for iUnit, oUnit in aiBrain[reftUnitsWantingFixedShield] do
                if bDebugMessages == true then LOG(sFunctionRef..': iUnit='..iUnit..'; oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; M27UnitInfo.IsUnitValid(oUnit)='..tostring(M27UnitInfo.IsUnitValid(oUnit))..'; Is under shield='..tostring(M27Logic.IsTargetUnderShield(aiBrain, oUnit, 3000, false, true, true))) end
                if not(M27UnitInfo.IsUnitValid(oUnit)) then
                    bChangesMade = true
                    table.remove(aiBrain[reftUnitsWantingFixedShield], iUnit)
                    break
                else
                    --Unit is still valid, how much shield protection does it have?
                    iTotalShieldHealth = M27Logic.IsTargetUnderShield(aiBrain, oUnit, 3000, true, true, true)
                    iShieldingWanted = GetShieldHealthWanted(oUnit)

                    if iTotalShieldHealth > iShieldingWanted then
                        bChangesMade = true
                        table.insert(aiBrain[reftUnitsWithFixedShield], oUnit)
                        table.remove(aiBrain[reftUnitsWantingFixedShield], iUnit)
                        break
                    end
                end
            end
            if M27Utilities.IsTableEmpty(aiBrain[reftUnitsWantingFixedShield]) then break end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function SafeToBuildExperimental(aiBrain)
    --Considers if we have enemies near our base, but will still return that its safe if the experimental is almost done
    local bSafeToGetExperimental = false
    if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech or (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle and M27Utilities.GetDistanceBetweenPositions(aiBrain[M27Overseer.reftLocationFromStartNearestThreat], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) >= M27Utilities.GetDistanceBetweenPositions(aiBrain[M27MapInfo.reftChokepointBuildLocation], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) or aiBrain[M27Overseer.refiPercentageClosestFriendlyFromOurBaseToEnemy] >= 0.45 or aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == false or aiBrain[M27Overseer.refiModDistFromStartNearestThreat] >= aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.3 then
        bSafeToGetExperimental = true
    else
        --Are we already building an experimental of use in combat that is near completion?
        if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildExperimental]) == false then
            local tUnderConstructionExperimental = aiBrain:GetListOfUnits(ConvertExperimentalRefToCategory(aiBrain[refiLastExperimentalReference]), false, true)
            if M27Utilities.IsTableEmpty(tUnderConstructionExperimental) == false then
                for iExperimental, oExperimental in tUnderConstructionExperimental do
                    if oExperimental:GetFractionComplete() < 1 and oExperimental:GetFractionComplete() > 0.6 and EntityCategoryContains(categories.MOBILE, oExperimental.UnitId) then
                        bSafeToGetExperimental = true --not really safe, but we might complete it in time
                    end
                end
            end
        end
    end
    return bSafeToGetExperimental
end



function ReassignEngineers(aiBrain, bOnlyReassignIdle, tEngineersToReassign)
    --tEngineersToReassign - optional - if specified, then will only consider these engineers for reassignment


    --DEBUGGING: Key log below to look for: LOG(sFunctionRef..': Game time='..GetGameTimeSeconds()..': About to assign action '..iActionToAssign..' to engineer number '..GetEngineerUniqueCount(oEngineerToAssign)..' with lifetime count='..sEngineerName..'; Eng unitId='..oEngineerToAssign.UnitId..'; ActionTargetLocation='..repru(tActionTargetLocation))

    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReassignEngineers'
    M27Utilities.FunctionProfiler(sFunctionRef..': Overall', M27Utilities.refProfilerStart)
    --if aiBrain:GetEconomyStoredRatio('MASS') >= 0.8 and aiBrain:GetEconomyStored('MASS') >= 5000 then bDebugMessages = true end


    if M27Logic.iTimeOfLastBrainAllDefeated < 10 then
        M27Utilities.FunctionProfiler(sFunctionRef..': ID IdleEngis', M27Utilities.refProfilerStart)

        local iCurGameTime = GetGameTimeSeconds()
        local tEngineers
        local bOnlyLookingAtSomeEngineers = false
        if tEngineersToReassign == nil then
            bOnlyLookingAtSomeEngineers = true
            tEngineers = aiBrain:GetListOfUnits(refCategoryEngineer, false, true)
        else tEngineers = tEngineersToReassign end
        local tIdleEngineers = {}
        local iEngineersToConsider = 0
        local tiAvailableEngineersByTech = {0,0,0}
        local bEngineerIsBusy = false
        local tsUnitStatesToIgnoreStrict = {'Building', 'Repairing', 'BeingBuilt'}
        local tsUnitStateToIgnoreBroader = {'Building', 'Repairing', 'BeingBuilt', 'Moving', 'Reclaiming', 'Guarding'}
        local tsUnitStatesToIgnoreBase, tsUnitStatesToIgnoreCurrent
        if bOnlyReassignIdle == true then tsUnitStatesToIgnoreBase = tsUnitStateToIgnoreBroader
        else tsUnitStatesToIgnoreBase = tsUnitStatesToIgnoreStrict end



        local iHighestTechLevelEngi = 1
        local iMinEngiTechLevelWanted
        local iCurEngiTechLevel
        local bHaveEngisOfCurrentOrHigherTech


        --TEMPTEST(aiBrain, sFunctionRef..': Pre record prev actions')
        --RecordPreviousEngineerActions(aiBrain)
        --Determine engineers that are available to be assigned
        local bStillHaveEarlyEngis = false
        local iIdleEarlyEngis = 0
        local iInitialCountThreshold = aiBrain[refiInitialMexBuildersWanted]

        --local iEngineersAlreadyBuildingMexes = 0
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code; is tEngineers empty='..tostring(M27Utilities.IsTableEmpty(tEngineers))) end
        --TEMPTEST(aiBrain, sFunctionRef..': Start')
        local sEngineerID

        if M27Utilities.IsTableEmpty(tEngineers) == false then
            for iEngineer, oEngineer in tEngineers do
                --if oEngineer.UnitId == 'xsl0105' and M27UnitInfo.GetUnitLifetimeCount(oEngineer) == 4 and aiBrain:GetArmyIndex() == 3 and GetGameTimeSeconds() >= 1326 and GetGameTimeSeconds() <= 1327 then bDebugMessages = true else bDebugMessages = false end
                --if GetEngineerUniqueCount(oEngineer) == 58 and GetGameTimeSeconds() >= 2040 then bDebugMessages = true else bDebugMessages = false end
                if M27UnitInfo.IsUnitValid(oEngineer) and oEngineer:GetFractionComplete() >= 1 and not(oEngineer:IsUnitState('Attached')) then

                    if bDebugMessages == true then LOG(sFunctionRef..': Considering if oEngineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' with UC='..GetEngineerUniqueCount(oEngineer)..' is idle. TIme of last assignment='..iCurGameTime - (oEngineer[refiTimeOfLastAssignment] or -100)..'; Engineer is valid='..tostring(M27UnitInfo.IsUnitValid(oEngineer))) end
                    if GetGameTimeSeconds() - (oEngineer[refiTimeOfLastIdleCheck] or -100) <= 0.99 or (not(tEngineersToReassign) and iCurGameTime - (oEngineer[refiTimeOfLastAssignment] or -100) < 1) then --DOnt refresh more than once a second
                        bEngineerIsBusy = true
                    else
                        oEngineer[refiTimeOfLastIdleCheck] = GetGameTimeSeconds()
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering if engineer with unique count='..GetEngineerUniqueCount(oEngineer)..' and assigned action '..(oEngineer[refiEngineerCurrentAction] or 'nil')..' is idle; FractionComplete='..oEngineer:GetFractionComplete()..'; Unit state='..M27Logic.GetUnitState(oEngineer)..'; IsUnitValid='..tostring(M27UnitInfo.IsUnitValid(oEngineer))) end

                        sEngineerID = oEngineer.UnitId
                        if M27UnitInfo.GetUnitLifetimeCount(oEngineer) <= iInitialCountThreshold then bStillHaveEarlyEngis = true end

                        bEngineerIsBusy = ProcessingEngineerActionForNearbyEnemies(aiBrain, oEngineer)

                        if bEngineerIsBusy == false and oEngineer[refiEngineerCurrentAction] == refActionHasNearbyEnemies then
                            if bDebugMessages == true then LOG(sFunctionRef..': Engi action was that it had nearby enemies so will clear action trackers') end
                            ClearEngineerActionTrackers(aiBrain, oEngineer, true)
                        elseif bEngineerIsBusy and M27Logic.IsUnitIdle(oEngineer, false, false, false) or oEngineer[M27Logic.refiIdleCount] > 10 then
                            --Have issue where sometimes an engineer can just stay motionless doing nothing if nearby enemies, so this way it will start moving
                            --if bDebugMessages == true then LOG(sFunctionRef..': Issuing aggressive move to engineer UC='..GetEngineerUniqueCount(oEngineer)..' to nearest rally point') end
                            if oEngineer[M27Transport.refiAssignedPlateau] and not (oEngineer[M27Transport.refiAssignedPlateau] == aiBrain[M27MapInfo.refiOurBasePlateauGroup]) then
                                if bDebugMessages == true then LOG(sFunctionRef..': will give plateau spare engi action') end
                                IssuePlateauSpareEngineerAction(aiBrain, oEngineer)
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Engi has nearby enemies but appears idle so will give spare engi action. Is unit valid='..tostring(M27UnitInfo.IsUnitValid(oEngineer))) end
                                IssueSpareEngineerAction(aiBrain, oEngineer)
                                if bDebugMessages == true then LOG(sFunctionRef..': Is oEngineer still valid='..tostring(M27UnitInfo.IsUnitValid(oEngineer))) end
                                --Engineer may not be valid if we just gave a kill order
                                if M27UnitInfo.IsUnitValid(oEngineer) then
                                    UpdateEngineerActionTrackers(aiBrain, oEngineer, refActionSpare, nil, false, 1000)
                                end
                            end
                        end
                        if bDebugMessages == true then
                            if M27UnitInfo.IsUnitValid(oEngineer) then
                                LOG(sFunctionRef..': Cycling through all engineers. Engineer Unique ref='..GetEngineerUniqueCount(oEngineer)..' Lifetimecount='..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..' iEngineer in loop of current engineers being considered='..iEngineer..'; Engineer state='..M27Logic.GetUnitState(oEngineer)..'; bOnlyReassignIdle='..tostring(bOnlyReassignIdle)..'; M27Logic.IsUnitIdle(oEngineer, not(bOnlyReassignIdle))='..tostring(M27Logic.IsUnitIdle(oEngineer, not(bOnlyReassignIdle), not(bOnlyReassignIdle), true, true))..'; bEngineerIsBusy after nearby enemy check='..tostring(bEngineerIsBusy)..'; refiIdleCount='..(oEngineer[M27Logic.refiIdleCount] or 'nil'))
                            end
                        end
                        if bEngineerIsBusy == false then
                            --Ignore engineer if it has been less than 4 seconds since it was given an assignment, unless it has specifically been sent for reassignment
                            if not(tEngineersToReassign) and iCurGameTime - (oEngineer[refiTimeOfLastAssignment] or -100) <= 4 then
                                if bDebugMessages == true then LOG(sFunctionRef..': Less than 4s since last assignment so will treat engineer as busy') end
                                bEngineerIsBusy = true
                            else

                                if bDebugMessages == true then LOG(sFunctionRef..': Engineer doest have nearby enemies, checking if its busy based on unit state. Unit state='..M27Logic.GetUnitState(oEngineer)) end
                                if bOnlyReassignIdle == true then
                                    bEngineerIsBusy = not(M27Logic.IsUnitIdle(oEngineer, false, false, true)) --Dont want to constantly reassign guarding units or else if theyre assisting a building they'll keep stuttering and not do anything; if this causes issues elsewhere then need to think up better solution
                                    if bDebugMessages == true then LOG(sFunctionRef..': EngineerIsBusy based on IsUnitIdle ='..tostring(bEngineerIsBusy)) end
                                else
                                    if oEngineer[refiEngineerCurrentAction] == refActionSpare or oEngineer[refiEngineerCurrentAction] == refActionPlateauSpareAction then
                                        tsUnitStatesToIgnoreCurrent = tsUnitStatesToIgnoreStrict
                                    else tsUnitStatesToIgnoreCurrent = tsUnitStatesToIgnoreBase end
                                    if bDebugMessages == true then LOG(sFunctionRef..': Cycling through engineer unit states and comparing to the list of states to treat as idle') end
                                    if oEngineer.IsUnitState then
                                        for iState, sState in tsUnitStatesToIgnoreCurrent do
                                            if bDebugMessages == true then LOG(sFunctionRef..': iEngineer='..iEngineer..'; considering if iEngineer state is '..sState) end
                                            if oEngineer:IsUnitState(sState) == true then
                                                bEngineerIsBusy = true break end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    --oEngineer[refbEngineerActionBeingRefreshed] = not(bEngineerIsBusy)
                    if bEngineerIsBusy == false then
                        if bDebugMessages == true then LOG(sFunctionRef..': Engineer isnt busy.  Considering if engineer with UC='..GetEngineerUniqueCount(oEngineer)..' is part of a plateau.  oEngineer[M27Transport.refiAssignedPlateau]='..(oEngineer[M27Transport.refiAssignedPlateau] or 'nil')..'; aiBrain[M27MapInfo.refiOurBasePlateauGroup]='..aiBrain[M27MapInfo.refiOurBasePlateauGroup]..'; Pathing group of engineer position='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oEngineer:GetPosition())) end
                        if oEngineer[M27Transport.refiAssignedPlateau] and not (oEngineer[M27Transport.refiAssignedPlateau] == aiBrain[M27MapInfo.refiOurBasePlateauGroup]) then
                            ReassignPlateauEngineer(aiBrain, oEngineer)
                        else
                            --Confirm engineer pathing is as expected

                            if not(M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oEngineer:GetPosition()) == aiBrain[M27MapInfo.refiOurBasePlateauGroup]) then
                                --Engineer not marked as a plateau engineer but isnt in same pathing group. recheck pathing
                                if M27MapInfo.RecheckPathingOfLocation(M27UnitInfo.refPathingTypeAmphibious, oEngineer, oEngineer:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then
                                    --Do nothing - will fix on next cycle
                                    if bDebugMessages == true then LOG(sFunctionRef..': Pathing was wrong for engineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; wont do anything so it shoudl be picked up correctly for next cycle') end
                                else
                                    --Engineer is in different pathing group - assign it to a plateau
                                    oEngineer[M27Transport.refiAssignedPlateau] = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oEngineer:GetPosition())
                                    if bDebugMessages == true then LOG(sFunctionRef..': Checked pathing but no change made. will assign engineer to plateau group '..oEngineer[M27Transport.refiAssignedPlateau]..'; our base group='..aiBrain[M27MapInfo.refiOurBasePlateauGroup]) end
                                end
                            else

                                iEngineersToConsider = iEngineersToConsider + 1
                                tIdleEngineers[iEngineersToConsider] = oEngineer
                                iCurEngiTechLevel = math.min(M27UnitInfo.GetUnitTechLevel(oEngineer), 3)
                                tiAvailableEngineersByTech[iCurEngiTechLevel] = tiAvailableEngineersByTech[iCurEngiTechLevel] + 1
                                --if GetEngineerUniqueCount(oEngineer) == 31 and GetGameTimeSeconds() >= 305 then bDebugMessages = true end
                                if bDebugMessages == true then LOG(sFunctionRef..': Engineer with UC='..GetEngineerUniqueCount(oEngineer)..' isnt busy so will clear its action trackers; TechLevel='..iCurEngiTechLevel..'; Available engis by tech level='..repru(tiAvailableEngineersByTech)) end
                                ClearEngineerActionTrackers(aiBrain, oEngineer, true)
                                if iCurEngiTechLevel > iHighestTechLevelEngi then iHighestTechLevelEngi = iCurEngiTechLevel end
                                if bDebugMessages == true then LOG(sFunctionRef..': Engineer isnt busy, so recording as available and clearing its actions. iCurEngiTechLevel='..iCurEngiTechLevel) end

                                if bStillHaveEarlyEngis == true and M27UnitInfo.GetUnitLifetimeCount(oEngineer) <= iInitialCountThreshold and iCurEngiTechLevel == 1 then
                                    iIdleEarlyEngis = iIdleEarlyEngis + 1
                                end
                            end
                        end
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Engineer is busy so leaving alone') end
                    end
                elseif oEngineer.Dead then
                    if bDebugMessages == true then LOG(sFunctionRef..': Engineer is dead so clearing its actions') end
                    ClearEngineerActionTrackers(aiBrain, oEngineer, true)
                end
            end
        end
        if bOnlyReassignIdle == nil then bOnlyReassignIdle = false end
        local iAllEngineers = iEngineersToConsider

        if bDebugMessages == true then
            if iIdleEarlyEngis == nil then LOG('iIdleEarlyEngis is nil') else LOG('iIdleEarlyEngis='..iIdleEarlyEngis) end
            --LOG('iEngineersAlreadyBuildingMexes='..iEngineersAlreadyBuildingMexes)
        end

        local iHighestFactoryOrEngineerTechAvailable = math.max(aiBrain[M27Overseer.refiOurHighestFactoryTechLevel], iHighestTechLevelEngi)

        M27Utilities.FunctionProfiler(sFunctionRef..': ID IdleEngis', M27Utilities.refProfilerEnd)

        if iEngineersToConsider > 0 then
            if bDebugMessages == true then LOG(sFunctionRef..': Have finished identifying idle engineers; iEngienersToConsider='..iEngineersToConsider..'; list of engineers available by tech level='..repru(tiAvailableEngineersByTech)) end


            --TEMPTEST(aiBrain, sFunctionRef..': After determined have engineers to consider')
            --Reset action variables for any engineers that are idle (otherwise will end up having an engineer with that action thinking it can assit itself)
            --[[ Now handled via function called whenever engineer is given action or is being made available for an action
    local oRecordedEngineer
    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation]) == false then
        for iRef1, tSubtable in aiBrain[reftEngineerAssignmentsByLocation] do
            if bDebugMessages == true then LOG(sFunctionRef..': Considering resetting for iRef1='..iRef1) end
            if M27Utilities.IsTableEmpty(tSubtable) == false then
                for iRef2, tSubSubTable in tSubtable do
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering resetting for iRef1='..iRef1..'; iRef2='..iRef2) end
                    oRecordedEngineer = tSubSubTable[refEngineerAssignmentEngineerRef]
                    if bDebugMessages == true then if oRecordedEngineer and oRecordedEngineer.GetUnitId then LOG(sFunctionRef..': oRecordedEngineer ID='..oRecordedEngineer.UnitId) end end
                    if oRecordedEngineer and oRecordedEngineer[refbEngineerActionBeingRefreshed] == true then
                        if bDebugMessages == true then LOG(sFunctionRef..': iRef1='..iRef1..'; iRef2='..iRef2..': Engineer assigned is being refreshed so resetting') end
                        aiBrain[reftEngineerAssignmentsByLocation][iRef1][iRef2] = {}
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': iRef1='..iRef1..'; iRef2='..iRef2..': Engineer assigned isnt being refreshed') end
                    end
                end
            end
        end
    end
    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef]) == false then
        for iActionRef, oRecordedEngineer in aiBrain[reftEngineerAssignmentsByActionRef] do
            if oRecordedEngineer[refbEngineerActionBeingRefreshed] == true then
                aiBrain[reftEngineerAssignmentsByActionRef][iActionRef] = nil
            end
        end
    end--]]


            local iCurrentConditionToTry = 1
            local oEngineerToAssign, iExistingEngineersAssigned, bWillBeAssigning
            local iLoopCount = 0
            local iMaxLoopCount = 150

            --Get values for various conditions that wont change so dont have to keep getting them for every engineer in the loop:
            local iGameTime = GetGameTimeSeconds()
            local sPathing = M27UnitInfo.refPathingTypeAmphibious
            local tStartPosition = M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]
            local iSegmentX, iSegmentZ = M27MapInfo.GetPathingSegmentFromPosition(tStartPosition)
            local iPathingGroup = M27MapInfo.GetSegmentGroupOfTarget(sPathing, iSegmentX, iSegmentZ)
            if bDebugMessages == true then LOG(sFunctionRef..': iEngineersToConsider ='..iEngineersToConsider..'; about to get unclaimed mexes') end
            local tAllUnclaimedHydroInPathingGroup
            --NOTE: For optimisation reasons, variables are declared here but are first defined in the first condition that uses them (so dont obtain the condition value if not enough engineers in the first place)
            local tAllUnclaimedMexesInPathingGroup, iAllUnclaimedMexesInPathingGroup, tAllUnclaimedMexesInLandPathingGroup, iAllUnclaimedMexesInLandPathingGroup
            local tUnclaimedMexesOnOurSideOfMap, iUnclaimedMexesOnOurSideOfMap
            local tUnclaimedMexesWithinDefenceCoverage, iUnclaimedMexesWithinDefenceCoverage
            local iUnclaimedHydroWithinDefenceCoverage, tUnclaimedHydroWithinDefenceCoverage
            local bNearbyHydro, tNearbyHydro, iUnclaimedHydroNearBase, tUnclaimedHydroNearBase
            local iGrossCurEnergyIncome, iNetCurEnergyIncome
            local iLandFactories, iAirFactories, iMassStored, iEnergyStored, iEnergyStorageMax, iEnergyStoredRatio, iMassStoredRatio
            local tExistingLocationsToPickFrom

            local iMaxEngisWanted
            local iActionToAssign
            local tActionTargetLocation, oActionTargetObject
            local iSearchRangeForPrevEngi = 100 --when set to 50 would sometimes have issues with engis looping from one to the other
            local iSearchRangeForNearestEngi --will ignore engis further away than this - should set to massive value for mexes etc. that build far away from base, but low value for buildings that want built by base

            --Build order threshold variables:
            local bThresholdInitialEngineerCondition
            local bThresholdPreReclaimEngineerCondition
            local iCurConditionEngiShortfall = 0
            local bClearCurrentlyAssignedEngineer

            local bHaveVeryLowPower = false
            local bWantMorePower = true

            iNetCurEnergyIncome = aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome]
            iEnergyStored = aiBrain:GetEconomyStored('ENERGY')
            --NOTE: IF UPDATING LOW POWER VALUES: Also consider updating spare engineer action
            if iNetCurEnergyIncome < 0 then
                if iEnergyStored < 1000 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Less than 1k energy stored so have very low power') end
                    bHaveVeryLowPower = true
                end
            elseif aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.5 and iEnergyStored < 2000 * (aiBrain[M27Overseer.refiOurHighestFactoryTechLevel]-1) + 50 then
                if bDebugMessages == true then LOG(sFunctionRef..': Have very low power as energy stored is below 50% and below threshold based on factory tech') end
                bHaveVeryLowPower = true
            end
            local bHaveLowPower = bHaveVeryLowPower
            local iLowPowerThreshold = 6
            local iAbsolutePowerBufferWanted = 10 --Min amoutn of net energy income wanted per tick; 100 for t1
            local iEnergyBufferMassFactorWanted = 7 --e.g. t2 mex needs 6 power for every 1 mass; T1 bomber is 22.8; striker is 4.75
            local iExtraEngisForPowerBasedOnTech = 0



            if iHighestFactoryOrEngineerTechAvailable >= 3 then
                iLowPowerThreshold = 40
                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                    iEnergyBufferMassFactorWanted = 50
                else
                    --Increase based on number of T3 air factories we have - --t3 mex needs 7 power for every 1 mass; titan needs 11, t3 strat 69
                    iEnergyBufferMassFactorWanted = math.min(50,15 + aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryAirFactory * categories.TECH3) * 5)
                end
                iAbsolutePowerBufferWanted = 250 --2500
                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
                    iEnergyBufferMassFactorWanted = iEnergyBufferMassFactorWanted * 0.9
                    iAbsolutePowerBufferWanted = 80 --800
                end
                iExtraEngisForPowerBasedOnTech = 5
            elseif iHighestFactoryOrEngineerTechAvailable == 2 then
                iLowPowerThreshold = 10
                iEnergyBufferMassFactorWanted = 12    --T3 mex is 7:1, janus is 20, pillar is 5
                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then iEnergyBufferMassFactorWanted = 15 end
                iAbsolutePowerBufferWanted = 40 --400
                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech then
                    iEnergyBufferMassFactorWanted = 9
                    iAbsolutePowerBufferWanted = 25 --250
                end
                iExtraEngisForPowerBasedOnTech = 7
            else
                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then iEnergyBufferMassFactorWanted = 15 end
            end

            iAbsolutePowerBufferWanted = iAbsolutePowerBufferWanted + math.min(75, aiBrain:GetCurrentUnits(categories.SHIELD) * 10)
            --Reduce power buffers wanted if are ecoing (as want to focus more on mass)



            local iPowerWantedPerTick = math.max(aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] * iEnergyBufferMassFactorWanted, aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] - aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome]) + iAbsolutePowerBufferWanted
            --Ensure we can support guncom if ACU wont be staying in base
            if M27Utilities.GetACU(aiBrain)[M27Overseer.refbACUCantPathAwayFromBase] then
                iPowerWantedPerTick = math.max(iPowerWantedPerTick, 35)
            else iPowerWantedPerTick = math.max(iPowerWantedPerTick, 50)
            end

            --If have active T2 air upgrade and lifetime bomber count is < 0 then increase threshold by 50
            if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryAirFactory * categories.TECH2, aiBrain[M27EconomyOverseer.reftActiveHQUpgrades])) == false and aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 2 then
                iPowerWantedPerTick = math.max(275, iPowerWantedPerTick + 50)
            end

            if bHaveLowPower == false then
                if iNetCurEnergyIncome < iLowPowerThreshold and (iEnergyStored < 4000 or aiBrain:GetEconomyStoredRatio('ENERGY') < 0.95) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Neg energy income below low power threshold and dont have much stored so have low power') end
                    bHaveLowPower = true
                elseif iEnergyStored < 2000 or aiBrain:GetEconomyStoredRatio('ENERGY') < 0.6 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Have less than 2k energy stored and less than 60%, so low power') end
                    bHaveLowPower = true
                end
            end
            if bHaveLowPower == false then
                --Do we have enough power? Base the power wanted on factory tech level
                --is true by default
                if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] > iPowerWantedPerTick and not(GetGameTimeSeconds() - (aiBrain[M27EconomyOverseer.refiLastEnergyStall] or -100)) <= 20 then bWantMorePower = false end
            end

            if bDebugMessages == true then LOG(sFunctionRef..': Power calcs: bHaveLowPower='..tostring(bHaveLowPower)..'; bWantMorePower='..tostring(bWantMorePower)..'; iPowerWantedPerTick='..iPowerWantedPerTick..'; iNetCurEnergyIncome='..iNetCurEnergyIncome..'; % energy stored='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; iEnergyBufferMassFactorWanted='..iEnergyBufferMassFactorWanted..'; aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]='..aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]..'; aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; iAbsolutePowerBufferWanted='..iAbsolutePowerBufferWanted..'; Time since last power stall='..(GetGameTimeSeconds() - (aiBrain[M27EconomyOverseer.refiLastEnergyStall] or -100))) end



            --Reset the number of engineers wanted
            local iEngineersWantedPreReset = (aiBrain[refiBOInitialEngineersWanted] or 0) + (aiBrain[refiBOPreReclaimEngineersWanted] or 0) + (aiBrain[refiBOPreSpareEngineersWanted] or 0)
            aiBrain[refiBOInitialEngineersWanted] = 0
            aiBrain[refiBOPreReclaimEngineersWanted] = 0
            aiBrain[refiBOPreSpareEngineersWanted] = 0
            aiBrain[reftiBOActiveSpareEngineersByTechLevel] = {0,0,0,0} --By tech level

            local bGetInitialEngineer
            local bAreOnSpareActions = false
            local iT2Power, iT3Power
            local iCurRadarCount, iCurT2RadarCount
            local iNearbyOmniCount
            local bHaveLowMass = M27Conditions.HaveLowMass(aiBrain)






            local iCount = 0

            bThresholdInitialEngineerCondition = false --Dont want inside while loop or else it gets reset to false while the line setting it to true only gets called once (when on that specific condition)
            bThresholdPreReclaimEngineerCondition = false

            --if iEngineersToConsider >= 5 and aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 then bDebugMessages = true end
            --if tiAvailableEngineersByTech[3] > 0 and GetGameTimeSeconds() >= 1200 then bDebugMessages = true end


            while iEngineersToConsider >= 0 do --want >= rather than > so get correct calculation of engineers needed
                --if aiBrain:GetEconomyStoredRatio('MASS') >= 0.8 and aiBrain:GetEconomyStored('MASS') >= 10000 and tiAvailableEngineersByTech[3] > 0 then bDebugMessages = true else bDebugMessages = false end
                M27Utilities.FunctionProfiler(sFunctionRef..': EngiConditions', M27Utilities.refProfilerStart)
                M27Utilities.FunctionProfiler(sFunctionRef..': Condition'..iCurrentConditionToTry..'Strat'..aiBrain[M27Overseer.refiAIBrainCurrentStrategy], M27Utilities.refProfilerStart)
                iCount = iCount + 1
                if M27Logic.iTimeOfLastBrainAllDefeated > 10 then break end
                if iCount > 100 then
                    if iEngineersToConsider < 40 then
                        M27Utilities.ErrorHandler('Possible infinite loop - have done more than 100 cycles.  Remaining engineers to consider='..(iEngineersToConsider or 'nil')..'.  If we have large number of engineers being reassigned at once then this could cause this message to trigger')
                        break
                    elseif iCount > 110 then
                        --abort for performance reasons anyway
                        break
                    end
                end

                --TEMPTEST(aiBrain, sFunctionRef..': just after while loop start')
                if bDebugMessages == true then LOG(sFunctionRef..': Start of loop to assign engineer action; iEngineersToConsider='..iEngineersToConsider..'; iCurrentConditionToTry='..iCurrentConditionToTry..'; iHighestFactoryOrEngineerTechAvailable='..iHighestFactoryOrEngineerTechAvailable..'; iAbsolutePowerBufferWanted='..iAbsolutePowerBufferWanted) end
                tExistingLocationsToPickFrom = {}
                iMaxEngisWanted = 1 --default; NOTE: This should be the cumulative value for that action (not that condition)
                iActionToAssign = nil

                oEngineerToAssign = nil
                bGetInitialEngineer = false
                iMinEngiTechLevelWanted = nil --Default - will consider later in the code
                iSearchRangeForNearestEngi = 100 --Default



                --Special logic if in ACU attack mode
                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and aiBrain[M27Overseer.refbIncludeACUInAllOutAttack] then
                    --ACU in attack - want energy storage if we dont already have it so can overcharge
                    if iCurrentConditionToTry == 1 then
                        if iEnergyStoredRatio == nil then iEnergyStoredRatio = aiBrain:GetEconomyStoredRatio('ENERGY') end
                        if iEnergyStorageMax == nil then iEnergyStorageMax = iEnergyStored / iEnergyStoredRatio end
                        if iEnergyStorageMax < 9000 then
                            iActionToAssign = refActionBuildEnergyStorage
                            iMaxEngisWanted = 6
                        end

                    elseif iCurrentConditionToTry == 2 then
                        if bDebugMessages == true then LOG(sFunctionRef..': Will build pogen') end
                        iActionToAssign = refActionBuildPower
                        iMaxEngisWanted = 10
                    elseif iCurrentConditionToTry == 3 then
                        if iHighestFactoryOrEngineerTechAvailable <= 1 then
                            iActionToAssign = refActionBuildSecondPower
                            iMaxEngisWanted = 5
                        end
                    else
                        iActionToAssign = refActionSpare
                        iSearchRangeForNearestEngi = 10000
                        iMaxEngisWanted = 1000
                    end
                else

                    if iCurrentConditionToTry == 1 then --Start of game - hydro near start?
                        if bDebugMessages == true then LOG(sFunctionRef..': Condition 1 - checking if want to build hydro') end
                        if iGrossCurEnergyIncome == nil then  iGrossCurEnergyIncome = aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] end
                        if iGrossCurEnergyIncome < 11 then -->110 per second, so must have hydro and/or 5 T1 power

                            if bNearbyHydro == nil then bNearbyHydro, tNearbyHydro = M27Conditions.HydroNearACUAndBase(aiBrain, true, true) end --Ignores ACU and just checks if near start position
                            if bNearbyHydro == true then
                                if bDebugMessages == true then LOG(sFunctionRef..': Condition 1 - want to build hydro; iGrossCurEnergyIncome='..iGrossCurEnergyIncome) end
                                iActionToAssign = refActionBuildHydro
                                iSearchRangeForNearestEngi = 100
                                if iUnclaimedHydroNearBase == nil then
                                    tUnclaimedHydroNearBase = FilterLocationsBasedOnIfUnclaimed(aiBrain, tNearbyHydro)
                                    if M27Utilities.IsTableEmpty(tUnclaimedHydroNearBase) == true then iUnclaimedHydroNearBase = 0
                                    else iUnclaimedHydroNearBase = table.getn(tUnclaimedHydroNearBase) end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': Condition='..iCurrentConditionToTry..': iUnclaimedHydroNearBase='..iUnclaimedHydroNearBase) end
                                tExistingLocationsToPickFrom = tUnclaimedHydroNearBase
                            end
                        elseif bDebugMessages == true then LOG(sFunctionRef..': We have enough energy so dont need hydro urgently')
                        end
                        iMaxEngisWanted = 3
                    elseif iCurrentConditionToTry == 2 then --Power stall early on where nearby reclaim might help
                        if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; aiBrain[M27EconomyOverseer.refbStallingEnergy]='..tostring(aiBrain[M27EconomyOverseer.refbStallingEnergy])..'; Energy storage='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; Net income='..aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome]) end
                        if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] < 150 and (aiBrain[M27EconomyOverseer.refbStallingEnergy] or (aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] < 0 and aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.3)) then
                            --Have really low energy so want to try and get energy reclaim - how much energy is nearby?
                            local iNearbyEnergy = 0
                            local iSegmentSearchRange = math.ceil(50 / M27MapInfo.iReclaimSegmentSizeX)
                            local iBaseReclaimSegmentX, iBaseReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])

                            for iReclaimSegmentX = iBaseReclaimSegmentX - iSegmentSearchRange, iBaseReclaimSegmentX + iSegmentSearchRange do
                                for iReclaimSegmentZ = iBaseReclaimSegmentZ - iSegmentSearchRange, iBaseReclaimSegmentZ + iSegmentSearchRange do
                                    iNearbyEnergy = iNearbyEnergy + (M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][M27MapInfo.refReclaimTotalEnergy] or 0)
                                end
                            end
                            --local iNearbyEnergy = M27MapInfo.GetReclaimInRectangle(5, Rect(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1]-50, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]-50, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1] + 50, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]+50), bDebugMessages)
                            if bDebugMessages == true then LOG(sFunctionRef..': iNearbyEnergy='..iNearbyEnergy) end
                            if iNearbyEnergy >= 100 then
                                iActionToAssign = refActionReclaimTrees
                                iMaxEngisWanted = math.max(3, math.min(aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] / 10, iNearbyEnergy / 90, 10))
                                if bDebugMessages == true then LOG(sFunctionRef..': Want engineers to reclaim energy, iMaxEngisWanted='..iMaxEngisWanted) end
                            end

                        end
                    elseif iCurrentConditionToTry == 3 then --TMD
                        --Build if have units wanting TMD, or have already started construction of TMD
                        if bDebugMessages == true then LOG(sFunctionRef..': Will see if want to build TMD. Is table of units wanting TMD empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftUnitsWantingTMD]))..'; is table of enemy TML empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyTML]))..'; Is table of engiener actions to build TMD empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildTMD]))) end
                        if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyTML]) == false and (M27Utilities.IsTableEmpty(aiBrain[reftUnitsWantingTMD]) == false or M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildTMD]) == false) then
                            iActionToAssign = refActionBuildTMD
                            iMaxEngisWanted = 3
                            iMinEngiTechLevelWanted = 2
                            tExistingLocationsToPickFrom = {}

                            if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildTMD]) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Dont have any existing actions to build TMD so will just record locations of all units wanting TMD and then consider later which of these is closest to the nearest idle engineer') end
                                for iUnit, oUnit in aiBrain[reftUnitsWantingTMD] do
                                    if M27UnitInfo.IsUnitValid(oUnit) then
                                        table.insert(tExistingLocationsToPickFrom, oUnit:GetPosition())
                                    end
                                end
                            else
                                local iClosestDistanceToEngi = 10000
                                local tPrimaryEngiLocation
                                local iCurDistance
                                local bNoPrimaryBuilder = true
                                for iSubtable, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] do
                                    if not(M27Utilities.IsTableEmpty(tSubtable[refEngineerAssignmentActualLocation])) then
                                        table.insert(tExistingLocationsToPickFrom, tSubtable[refEngineerAssignmentActualLocation])
                                        if bDebugMessages == true then LOG(sFunctionRef..': Considering existing locations; location='..repru(tSubtable[refEngineerAssignmentActualLocation])..'; Engineer='..tSubtable[refEngineerAssignmentEngineerRef].UnitId..M27UnitInfo.GetUnitLifetimeCount(tSubtable[refEngineerAssignmentEngineerRef])..'; UC='..GetEngineerUniqueCount(tSubtable[refEngineerAssignmentEngineerRef])..'; Is primary engineer='..tostring((tSubtable[refEngineerAssignmentEngineerRef][refbPrimaryBuilder]) or false)) end
                                        if tSubtable[refEngineerAssignmentEngineerRef][refbPrimaryBuilder] then
                                            bNoPrimaryBuilder = false
                                            if bDebugMessages == true then LOG(sFunctionRef..': Dealing with primary builder, time of last assignment='..(tSubtable[refEngineerAssignmentEngineerRef][refiTimeOfLastAssignment] or 0)..'; So was '..(GetGameTimeSeconds() - (tSubtable[refEngineerAssignmentEngineerRef][refiTimeOfLastAssignment] or 0))..' seconds ago') end
                                            if GetGameTimeSeconds() - (tSubtable[refEngineerAssignmentEngineerRef][refiTimeOfLastAssignment] or 0) >= 5 then
                                                iCurDistance = M27Utilities.GetDistanceBetweenPositions(tSubtable[refEngineerAssignmentActualLocation], tSubtable[refEngineerAssignmentEngineerRef]:GetPosition())
                                                if iCurDistance < iClosestDistanceToEngi then
                                                    iClosestDistanceToEngi = iCurDistance
                                                    tPrimaryEngiLocation = {tSubtable[refEngineerAssignmentActualLocation][1], tSubtable[refEngineerAssignmentActualLocation][2], tSubtable[refEngineerAssignmentActualLocation][3]}
                                                end
                                            end
                                        end
                                    else
                                        if tSubtable[refEngineerAssignmentEngineerRef][refbPrimaryBuilder] then
                                            M27Utilities.ErrorHandler('Dealing with primary builder but for some reason engineer assignment actual locaiton isnt specified; will do more logs to help debug')
                                            LOG(sFunctionRef..': iSubtable='..iSubtable..'; Is assigned engineer valid='..tostring(M27UnitInfo.IsUnitValid(tSubtable[refEngineerAssignmentEngineerRef])))
                                            if M27UnitInfo.IsUnitValid(tSubtable[refEngineerAssignmentEngineerRef]) then
                                                LOG(sFunctionRef..': Assigned engi details='..tSubtable[refEngineerAssignmentEngineerRef].UnitId..M27UnitInfo.GetUnitLifetimeCount(tSubtable[refEngineerAssignmentEngineerRef])..'; UC='..GetEngineerUniqueCount(tSubtable[refEngineerAssignmentEngineerRef])..'; Engi action='..tSubtable[refEngineerAssignmentEngineerRef][refiEngineerCurrentAction]..'; is primary engineer='..tostring((tSubtable[refEngineerAssignmentEngineerRef][refbPrimaryBuilder] or false)))
                                            end
                                        end
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': Already have a location, will use this unless it is far away from base and we think we can do closer. iClosestDistanceToEngi='..iClosestDistanceToEngi..'; tPrimaryEngiLocation='..repru(tPrimaryEngiLocation)..'; tExistingLocationsToPickFrom based on existing locations (i.e. if we later dont choose to replace this)='..repru(tExistingLocationsToPickFrom)) end
                                if bNoPrimaryBuilder then M27Utilities.ErrorHandler('Had action assigned but couldnt find any primary builder for it') end
                                local bHaveBetterAlternative = false
                                --Note: If engi was given its orders in the last 5s then closest distance will show as 10k but theree will be no priamryengilocation
                                if iClosestDistanceToEngi >= 80 and tPrimaryEngiLocation then --Check if any locations wanting TMD protection that are closer
                                    if bDebugMessages == true then LOG(sFunctionRef..': The engineer target is quite far away and its been a short while since it was given the order, so want to check there arent any closer ones') end

                                    for iUnit, oUnit in aiBrain[reftUnitsWantingTMD] do
                                        if M27UnitInfo.IsUnitValid(oUnit) then
                                            iCurDistance = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tPrimaryEngiLocation)
                                            if iCurDistance < (iClosestDistanceToEngi + 50) then
                                                if bDebugMessages == true then LOG(sFunctionRef..': Found a closer target to the primary engineer, target='..oUnit:GetPosition()..'; which is the postiion of unit wanting TMD '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                                                bHaveBetterAlternative = true
                                                break
                                            end
                                        end
                                    end
                                end
                                if bHaveBetterAlternative then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have better alternative so will clear all existing engineers and reset locations to consider') end
                                    --Clear all engineers assigned this action and make them available for this cycle
                                    for iSubtable, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] do
                                        iCurEngiTechLevel = math.min(M27UnitInfo.GetUnitTechLevel(tSubtable[refEngineerAssignmentEngineerRef]), 3)
                                        tiAvailableEngineersByTech[iCurEngiTechLevel] = tiAvailableEngineersByTech[iCurEngiTechLevel] + 1
                                        table.insert(tIdleEngineers, tSubtable[refEngineerAssignmentEngineerRef])
                                        --if tSubtable[refEngineerAssignmentEngineerRef]:IsUnitState('Building') or tSubtable[refEngineerAssignmentEngineerRef]:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
                                        if bDebugMessages == true then LOG(sFunctionRef..': Will add engineer '..tSubtable[refEngineerAssignmentEngineerRef].UnitId..M27UnitInfo.GetUnitLifetimeCount(tSubtable[refEngineerAssignmentEngineerRef])..' with UC='..GetEngineerUniqueCount(tSubtable[refEngineerAssignmentEngineerRef])..' to the list of engineers that are available as have better alternative') end
                                        IssueClearCommands({tSubtable[refEngineerAssignmentEngineerRef]})
                                        ClearEngineerActionTrackers(aiBrain, tSubtable[refEngineerAssignmentEngineerRef], true)
                                    end
                                    --Reset the locations to consider
                                    tExistingLocationsToPickFrom = {}
                                    for iUnit, oUnit in aiBrain[reftUnitsWantingTMD] do
                                        if M27UnitInfo.IsUnitValid(oUnit) then
                                            table.insert(tExistingLocationsToPickFrom, oUnit:GetPosition())
                                        end
                                    end
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': No better alternative so will stick with current location; will allow T1 engis to assist if we have no more t2 available') end
                                    if tiAvailableEngineersByTech[2] + tiAvailableEngineersByTech[3] == 0 then
                                        iMinEngiTechLevelWanted = 1 --Can have T1 engis assist a T2 engi to build TMD since we have no T2 or T3 available
                                    end
                                end
                            end
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': Have set action to build TMD; list of locations of units wanting TMD='..repru(tExistingLocationsToPickFrom)..'; will draw locations in black')
                                M27Utilities.DrawLocations(tExistingLocationsToPickFrom, nil, 3, 200, false, nil)
                            end
                            if M27Utilities.IsTableEmpty(tExistingLocationsToPickFrom) then
                                M27Utilities.ErrorHandler('Couldnt find any locations to build TMD at, wont try and build TMD')
                                iActionToAssign = nil
                            end
                        end
                    elseif iCurrentConditionToTry == 4 then --Emergency PD and (if turtling) firebase fortification
                        --Dont want to get this too early even if threats detected, so require at least 15 mass income per tick
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering if we want emergency PD. Gross mass income='..aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]..'; bHaveLowPower='..tostring(bHaveLowPower)..'; Gross energy income='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; Is table of existing engineers assigned to build PD empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildEmergencyPD]))..'; Land segment group of nearest enemy='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, aiBrain[M27Overseer.reftLocationFromStartNearestThreat])..'; Land segment group of base='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])) end
                        if aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 1.5 and (not(bHaveLowPower) or aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 65) then
                            --Are there nearby threats to our base that are land pathable, or have we already started constructing an emergency PD?
                            if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildEmergencyPD]) == false then
                                --Already building so want to assign lots of engineers
                                iMaxEngisWanted = math.min(math.ceil(aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]), 6)
                                iActionToAssign = refActionBuildEmergencyPD
                                --Do we have fewer than 5 engineers assigned? if so then free up the nearest 5 engineers
                                iExistingEngineersAssigned = 0
                                local tExistingLocation
                                for iRef, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildEmergencyPD] do
                                    iExistingEngineersAssigned = iExistingEngineersAssigned + 1
                                    if tSubtable[refEngineerAssignmentEngineerRef][refbPrimaryBuilder] then
                                        tExistingLocation = tSubtable[refEngineerAssignmentActualLocation]
                                    end
                                end

                                if iExistingEngineersAssigned < 5 and tExistingLocation then
                                    local iEngineersToClear = 5 - iExistingEngineersAssigned
                                    local tNearbyEngineersToClear = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryEngineer, tExistingLocation, 40, 'Ally')
                                    --Only clear those engineers we personally own
                                    local iEngisAvailableToClear = 0
                                    local tEngisAvailableToClear = {}
                                    if M27Utilities.IsTableEmpty(tNearbyEngineersToClear) == false then
                                        for iAltEngi, oAltEngi in tNearbyEngineersToClear do
                                            if oAltEngi:GetAIBrain() == aiBrain and oAltEngi[refiEngineerConditionNumber] > iCurrentConditionToTry then
                                                if bDebugMessages == true then LOG(sFunctionRef..': iEngisAvailableToClear='..iEngisAvailableToClear..'; oAltEngi='..oAltEngi.UnitId..M27UnitInfo.GetUnitLifetimeCount(oAltEngi)..'; UC='..GetEngineerUniqueCount(oAltEngi)..'; AltEngi action='..(oAltEngi[refiEngineerCurrentAction] or 'nil')..'; Is alt engi primary engi='..tostring(oAltEngi[refbPrimaryBuilder])) end
                                                if not(oAltEngi[refbPrimaryBuilder]) and not(oAltEngi[refiEngineerCurrentAction] == refActionFortifyFirebase) then
                                                    iEngisAvailableToClear = iEngisAvailableToClear + 1
                                                    tEngisAvailableToClear[iEngisAvailableToClear] = oAltEngi
                                                end
                                            end
                                        end
                                    end
                                    if iEngisAvailableToClear > 0 then
                                        if iEngisAvailableToClear <= iEngineersToClear then
                                            --for iAltEngi, oAltEngi in tEngisAvailableToClear do
                                            --if oAltEngi:IsUnitState('Building') or oAltEngi:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
                                            --end
                                            IssueClearCommands(tEngisAvailableToClear)
                                            for iAltEngi, oAltEngi in tEngisAvailableToClear do
                                                ClearEngineerActionTrackers(aiBrain, oAltEngi, true)
                                            end
                                        else
                                            --Loop through the table of engis to clear, clearing the ones closest first
                                            local oNearestEngineer
                                            local iRefNearestEngi
                                            local iNearestEngineer
                                            local iCurDistance
                                            while iEngineersToClear > 0 do
                                                iEngineersToClear = iEngineersToClear - 1
                                                iNearestEngineer = 10000
                                                for iAltEngi, oAltEngi in tEngisAvailableToClear do
                                                    iCurDistance = M27Utilities.GetDistanceBetweenPositions(tExistingLocation, oAltEngi:GetPosition())
                                                    if iCurDistance < iNearestEngineer then
                                                        oNearestEngineer = oAltEngi
                                                        iRefNearestEngi = iAltEngi
                                                        iNearestEngineer = iCurDistance
                                                    end
                                                end
                                                --if GetEngineerUniqueCount(oNearestEngineer) == 31 and GetGameTimeSeconds() >= 305 then bDebugMessages = true end
                                                --if oNearestEngineer:IsUnitState('Building') or oNearestEngineer:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
                                                if bDebugMessages == true then LOG(sFunctionRef..': About to clear nearest engineer='..oNearestEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oNearestEngineer)..'; UC='..GetEngineerUniqueCount(oNearestEngineer)) end
                                                IssueClearCommands({oNearestEngineer})
                                                ClearEngineerActionTrackers(aiBrain, oNearestEngineer, true)
                                                tEngisAvailableToClear[iRefNearestEngi] = nil
                                            end
                                        end
                                    end
                                end
                            else
                                --Can we path to the nearest land threat and is it within max defence coverage?
                                if bDebugMessages == true then LOG(sFunctionRef..': Can we path to nearest land threat='..tostring(M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, aiBrain[M27Overseer.reftLocationFromStartNearestThreat]) == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]))) end
                                if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, aiBrain[M27Overseer.reftLocationFromStartNearestThreat]) == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) then
                                    local iSearchRange
                                    local iThreatRatio
                                    local iMassKilledToCost = aiBrain[refiMassKilledByPD] / aiBrain[refiMassSpentOnPD]
                                    if iMassKilledToCost >= 2 then
                                        iThreatRatio = 0.25
                                        iSearchRange = math.max(aiBrain[M27AirOverseer.refiBomberDefenceModDistance] * 0.75, math.min(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.425, 210))
                                    elseif iMassKilledToCost >= 1 or aiBrain[refiMassSpentOnPD] <= 470 then --Havent built 1 T2 PD yet
                                        iThreatRatio = 0.45
                                        iSearchRange = math.max(aiBrain[M27AirOverseer.refiBomberDefenceModDistance] * 0.675, math.min(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.4, 190))
                                    elseif iMassKilledToCost >= 0.6 or aiBrain[refiMassSpentOnPD] <= 950 then --have built less than 2 T2 PD
                                        iThreatRatio = 0.6
                                        iSearchRange = math.max(aiBrain[M27AirOverseer.refiBomberDefenceModDistance] * 0.625, math.min(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.375, 170))
                                    else
                                        iThreatRatio = 0.8
                                        iSearchRange = math.max(aiBrain[M27AirOverseer.refiBomberDefenceModDistance] * 0.6, math.min(aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.35, 160))
                                    end
                                    if iSearchRange >= 80 then iSearchRange = math.min(iSearchRange, aiBrain[M27Overseer.refiMaxDefenceCoverageWanted] * aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]) end

                                    if bDebugMessages == true then LOG(sFunctionRef..': Can path by land to closest enemy. Mod distance from start of threat='..aiBrain[M27Overseer.refiModDistFromStartNearestThreat]..'; SearchRange='..iSearchRange..'; iThreatRatio='..iThreatRatio) end

                                    if aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= iSearchRange then
                                        --Rect: Small X-Z; Large X-Z
                                        local rRect = Rect(math.min(aiBrain[M27Overseer.reftLocationFromStartNearestThreat][1], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1]) - 15, math.min(aiBrain[M27Overseer.reftLocationFromStartNearestThreat][3], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]) - 15, math.max(aiBrain[M27Overseer.reftLocationFromStartNearestThreat][1], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][1]) + 15, math.max(aiBrain[M27Overseer.reftLocationFromStartNearestThreat][3], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber][3]) + 15)
                                        local tUnitsOfInterest = GetUnitsInRect(rRect)

                                        local iThreatOfPD = 0
                                        local iExistingPD = 0
                                        if bDebugMessages == true then LOG(sFunctionRef..': rRect to search for PD='..repru(rRect)..'; is tUnitsOfInterest empty='..tostring(M27Utilities.IsTableEmpty(tUnitsOfInterest))) end
                                        if M27Utilities.IsTableEmpty(tUnitsOfInterest) == false then
                                            tUnitsOfInterest = EntityCategoryFilterDown(M27UnitInfo.refCategoryPD, tUnitsOfInterest)
                                            if M27Utilities.IsTableEmpty(tUnitsOfInterest) == false then
                                                local tExistingPD = {}

                                                local oBrainOwner
                                                local iOurArmyIndex = aiBrain:GetArmyIndex()
                                                for iUnit, oUnit in tUnitsOfInterest do
                                                    if M27UnitInfo.IsUnitValid(oUnit) and oUnit:GetFractionComplete() == 1 then
                                                        oBrainOwner = oUnit:GetAIBrain()
                                                        if oBrainOwner == aiBrain or not (IsEnemy(oBrainOwner:GetArmyIndex(), iOurArmyIndex)) then
                                                            iExistingPD = iExistingPD + 1
                                                            tExistingPD[iExistingPD] = oUnit
                                                            if bDebugMessages == true then LOG(sFunctionRef..': Have a PD in the units of interest, oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; iExistingPD='..iExistingPD) end
                                                        end
                                                    end
                                                end
                                                if iExistingPD > 0 then
                                                    iThreatOfPD = M27Logic.GetCombatThreatRating(aiBrain, tExistingPD)
                                                end
                                            end
                                        end
                                        if iExistingPD < 15 then
                                            local tEnemyMobileGround = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryLandCombat, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], iSearchRange, 'Enemy')
                                            local iEnemyThreat = M27Logic.GetCombatThreatRating(aiBrain, tEnemyMobileGround)
                                            if aiBrain[M27AirOverseer.refbBomberDefenceRestrictedByAA] then
                                                iThreatRatio = math.min(iThreatRatio, 0.45)
                                            end
                                            if bDebugMessages == true then LOG(sFunctionRef..': iThreatOfPD='..iThreatOfPD..'; iEnemyThreat='..iEnemyThreat..'; iHighestFactoryOrEngineerTechAvailable='..iHighestFactoryOrEngineerTechAvailable..'; iThreatRatio='..iThreatRatio..'; aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]='..aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]) end
                                            if iThreatOfPD + 188 < iEnemyThreat / iThreatRatio or (iThreatOfPD <= 400 and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 7) then
                                                if iHighestFactoryOrEngineerTechAvailable >= 2 or M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.INDIRECTFIRE, tEnemyMobileGround)) then
                                                    iActionToAssign = refActionBuildEmergencyPD
                                                    iMaxEngisWanted = math.min(math.ceil(aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]), 6)
                                                    if iThreatOfPD > 0 or aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPD * categories.TECH1) > 0 then
                                                        iMinEngiTechLevelWanted = 2
                                                    end
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Will assign action to build emergency PD. iMaxEngisWanted='..iMaxEngisWanted) end
                                                end
                                            end
                                        else

                                        end
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef .. ': iExistingPD=' .. iExistingPD .. '; iThreatOfPD (if <10)=' .. iThreatOfPD .. '; ; 35% of Enemy dist to base=' .. aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.35 .. '; refiModDistFromStartNearestThreat=' .. aiBrain[M27Overseer.refiModDistFromStartNearestThreat] .. '; T2 PD=' .. aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2PlusPD) .. '; Action to assign after considering whether to get emergency PD=' .. (iActionToAssign or 'nil'))
                                        end
                                    end
                                end
                            end
                            --Are we turtling? If so then consider fortifying the firebase as a high priority
                            if not(iActionToAssign) and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 4 then
                                RefreshListOfFirebases(aiBrain)
                                if aiBrain[reftFirebasesWantingFortification] and aiBrain[reftFirebasesWantingFortification][aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef]] then
                                    iActionToAssign = refActionFortifyFirebase
                                    aiBrain[refiFirebaseBeingFortified] = aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef]
                                    if aiBrain[M27Overseer.refiTotalEnemyShortRangeThreat] >= 20000 then
                                        iMaxEngisWanted = 7
                                        if bHaveLowMass then iMaxEngisWanted = 5 end
                                    elseif bHaveLowMass then iMaxEngisWanted = 1 else iMaxEngisWanted = 3
                                    end
                                    iMinEngiTechLevelWanted = 2
                                    if not(M27Utilities.DoesCategoryContainCategory(categories.TECH1 + categories.TECH2, aiBrain[refiFirebaseCategoryWanted][aiBrain[refiFirebaseBeingFortified]], false)) then iMinEngiTechLevelWanted = 3
                                        --Are we building T2Plus PD and have an available UEF engineer?
                                    elseif tiAvailableEngineersByTech[3] > 0 and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.TECH3 * categories.UEF, tIdleEngineers)) == false and aiBrain[refiFirebaseCategoryWanted][aiBrain[refiFirebaseBeingFortified]] == M27UnitInfo.refCategoryT2PlusPD then
                                        aiBrain[refiFirebaseCategoryWanted][aiBrain[refiFirebaseBeingFortified]] = M27UnitInfo.refCategoryT3PD
                                        iMinEngiTechLevelWanted = 3
                                    end
                                    tExistingLocationsToPickFrom[1] = {aiBrain[M27MapInfo.reftChokepointBuildLocation][1], aiBrain[M27MapInfo.reftChokepointBuildLocation][2], aiBrain[M27MapInfo.reftChokepointBuildLocation][3]}
                                end
                            end
                        end
                        --Cap engineers to 3 if we need to build power
                        if iActionToAssign and bHaveLowPower and aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.9 and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildPower]) then
                            iMaxEngisWanted = math.min(iMaxEngisWanted, 3)
                        end
                    elseif iCurrentConditionToTry == 5 then --First ever transport waiting for engineers
                        if bDebugMessages == true then LOG(sFunctionRef..': Is table of transports waiting for engineers empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27Transport.reftTransportsWaitingForEngi]))) end
                        if M27Utilities.IsTableEmpty(aiBrain[M27Transport.reftTransportsWaitingForEngi]) == false then
                            for iUnit, oUnit in aiBrain[M27Transport.reftTransportsWaitingForEngi] do
                                if M27UnitInfo.GetUnitLifetimeCount(oUnit) == 1 then
                                    iActionToAssign = refActionLoadOnTransport
                                    iMaxEngisWanted = aiBrain[M27Transport.refiEngineersWantedForTransports]
                                    if bDebugMessages == true then LOG(sFunctionRef..': Are dealing with first lifetime count transport.  Want action to load on transport, with iMaxEngisWanted='..iMaxEngisWanted) end
                                    break
                                end
                            end

                        end

                    elseif iCurrentConditionToTry == 6 then  --want 2 engis claiming mexes for first 5m of game (and for initial 2 engis to keep building mexes)
                        --Have initial engineers only build mexes, separate to the normal process
                        if iAllUnclaimedMexesInPathingGroup == nil then
                            tAllUnclaimedMexesInPathingGroup = GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, false, false, false)

                            if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInPathingGroup) == false then iAllUnclaimedMexesInPathingGroup = table.getn(tAllUnclaimedMexesInPathingGroup)
                            else iAllUnclaimedMexesInPathingGroup = 0 end
                            if bDebugMessages == true then LOG(sFunctionRef..': Condition '..iCurrentConditionToTry..': iAllUnclaimedMexesInPathingGroup='..iAllUnclaimedMexesInPathingGroup) end
                        end
                        if iAllUnclaimedMexesInPathingGroup > 0 then
                            --Initial build order - if no hydro and we dont have muc hpower, then dont assign engis to mexe as want them for power instead
                            if bNearbyHydro == nil then bNearbyHydro, tNearbyHydro = M27Conditions.HydroNearACUAndBase(aiBrain, true, true) end --Ignores ACU and just checks if near start position
                            if bDebugMessages == true then LOG(sFunctionRef..': Checking if should build power as initial priority instead of mex; aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; aiBrain:GetEconomyStoredRatio(Energy)='..aiBrain:GetEconomyStoredRatio('ENERGY')..'; bNearbyHydro='..tostring(bNearbyHydro)) end
                            if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] <= 8 and not(bNearbyHydro) and aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.7 and aiBrain:GetEconomyStoredRatio('MASS') >= 0.1 then --have 3 or fewer t1 power
                                if bDebugMessages == true then LOG(sFunctionRef..': Will build pogen') end
                                iActionToAssign = refActionBuildPower
                                iMaxEngisWanted = 1
                            else
                                if iUnclaimedMexesOnOurSideOfMap == nil then
                                    tUnclaimedMexesOnOurSideOfMap = FilterLocationsBasedOnDistanceToEnemy(aiBrain, tAllUnclaimedMexesInPathingGroup, 0.5)
                                    if M27Utilities.IsTableEmpty(tUnclaimedMexesOnOurSideOfMap) == false then iUnclaimedMexesOnOurSideOfMap = table.getn(tUnclaimedMexesOnOurSideOfMap)
                                    else iUnclaimedMexesOnOurSideOfMap = 0 end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': Condition '..iCurrentConditionToTry..': iUnclaimedMexesOnOurSideOfMap='..iUnclaimedMexesOnOurSideOfMap) end
                                if iUnclaimedMexesOnOurSideOfMap > 0 then
                                    if bDebugMessages == true then LOG(sFunctionRef..': We have '..iUnclaimedMexesOnOurSideOfMap..' unclaimed mexes our side of the map') end
                                    if iGameTime <= 500 then
                                        iActionToAssign = refActionBuildMex
                                        iSearchRangeForNearestEngi = 10000
                                        iMaxEngisWanted = aiBrain[refiInitialMexBuildersWanted]
                                        if iUnclaimedMexesOnOurSideOfMap <= aiBrain[refiInitialMexBuildersWanted] then iMaxEngisWanted = aiBrain[refiInitialMexBuildersWanted] end
                                        tExistingLocationsToPickFrom = tUnclaimedMexesOnOurSideOfMap
                                    end
                                    --Still want this action for initial engineers - do we have any idle engineers that are the initial engineers?
                                    if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..': bStillHaveEarlyEngis='..tostring(bStillHaveEarlyEngis)..'; iIdleEarlyEngis='..iIdleEarlyEngis..'; aiBrain[refiInitialMexBuildersWanted]='..aiBrain[refiInitialMexBuildersWanted]) end
                                    if bStillHaveEarlyEngis == true and iIdleEarlyEngis > 0 then
                                        bGetInitialEngineer = true
                                        iActionToAssign = refActionBuildMex
                                        iSearchRangeForNearestEngi = 10000
                                        local iEngineersAlreadyBuildingMexes = 0
                                        for iEngi, oEngineer in aiBrain:GetListOfUnits(refCategoryEngineer, false, true) do
                                            if oEngineer[refiEngineerCurrentAction] == refActionBuildMex then iEngineersAlreadyBuildingMexes = iEngineersAlreadyBuildingMexes + 1 end
                                        end
                                        if bDebugMessages == true then LOG(sFunctionRef..': iEngineersAlreadyBuildingMexes='..iEngineersAlreadyBuildingMexes) end
                                        iMaxEngisWanted = math.max(iEngineersAlreadyBuildingMexes + iIdleEarlyEngis, iMaxEngisWanted)
                                        iIdleEarlyEngis = iIdleEarlyEngis - 1
                                        tExistingLocationsToPickFrom = tUnclaimedMexesOnOurSideOfMap
                                    end
                                    if bDebugMessages == true then LOG('iMaxEngisWanted after finishing checking condition for initial mexes='..iMaxEngisWanted) end
                                end
                            end
                        end
                        if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] < 10 then iMaxEngisWanted = 1 end
                    elseif iCurrentConditionToTry == 7 then --Get reclaim if low on mass

                        if iMassStoredRatio == nil then iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS') end
                        if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..'; iMassStoredRatio='..iMassStoredRatio..'; M27MapInfo.iMapTotalMass='..(M27MapInfo.iMapTotalMass or 'nil')..'; aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1]='..(aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] or 'nil')) end
                        if iMassStoredRatio < 0.05 or (iMassStoredRatio < 0.25 and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] < 10) then
                            if aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] > 0 then
                                --Have some reclaim somewhere on map, so have at least 1 engineer assigned to reclaim even if no high priority locations
                                iActionToAssign = refActionReclaimArea
                                --M27MapInfo.UpdateReclaimMarkers() --Does periodically if been a while since last update --Moved this to overseer so dont end up with engis waiting for this to compelte
                                iMaxEngisWanted = math.min(2, math.max(1, math.ceil((aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] or 0)/3)))
                                if bStillHaveEarlyEngis and aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] > 5 then iMaxEngisWanted = iMaxEngisWanted + 1 end
                                iSearchRangeForNearestEngi = 10000
                            end
                        end
                    elseif iCurrentConditionToTry == 8 then --Want 2-5 factories as a high priority (higher than power)
                        if iLandFactories == nil then
                            iLandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory)
                            if iLandFactories == nil then iLandFactories = 0 end
                        end
                        if iAirFactories == nil then
                            iAirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory)
                            if iAirFactories == nil then iAirFactories = 0 end
                        end

                        local bHaveNoLandHQ = false
                        local bHaveNoAirHQ = false
                        if iLandFactories == 0 then bHaveNoLandHQ = true
                        else
                            if aiBrain:GetCurrentUnits(refCategoryLandFactory - categories.SUPPORTFACTORY) == 0 then bHaveNoLandHQ = true end
                        end

                        if iAirFactories == 0 then bHaveNoAirHQ = true
                        else
                            if aiBrain:GetCurrentUnits(refCategoryAirFactory - categories.SUPPORTFACTORY) == 0 then bHaveNoAirHQ = true end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Deciding if need high priority factory/HQ. bHaveNoLandHQ='..tostring(bHaveNoLandHQ)..'; bHaveNoAirHQ='..tostring(bHaveNoAirHQ)..'; iLandFactories='..iLandFactories..'; iAirFactories='..iAirFactories..'; Max land factories wanted='..aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand]..'; max air facs wanted='..aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir]..'; Mass gross income='..aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]..'; Mass stored='..aiBrain:GetEconomyStored('MASS')..'; Energy stored='..aiBrain:GetEconomyStored('ENERGY')..'; Energy gross income='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; Enemy air threat='..aiBrain[M27AirOverseer.refiHighestEnemyAirThreat]..'; Can path to enemy with land='..tostring(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand])..'; Cur strategy='..aiBrain[M27Overseer.refiAIBrainCurrentStrategy]) end

                        if bHaveNoLandHQ or bHaveNoAirHQ or (iLandFactories+iAirFactories < (aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] + aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir]) and (iLandFactories+iAirFactories < 2 or (iLandFactories+iAirFactories < 5 and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyLandMain and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand]))) then
                            if (aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] > 6 and ((aiBrain:GetEconomyStored('MASS') >= 100 and aiBrain:GetEconomyStored('ENERGY') >= 1000) or (aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 8 and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 40))) or (iAirFactories == 0 and aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] > 0) then
                                --Enemy has air and we dont
                                if iAirFactories == 0 and aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] > 0 then
                                    iActionToAssign = refActionBuildAirFactory
                                    --1 engi requires 40 gross energy and 3.5 mass per sec to build a t1 air fac.  Will do /5.5 so still ahve engis free to e.g. build power or somethign else
                                    iMaxEngisWanted = math.max(1, math.min(aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] / 5.5, aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] / 0.4))
                                    if iLandFactories < aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes] then
                                        iActionToAssign = refActionBuildLandFactory
                                        iMaxEngisWanted = 1
                                    elseif iAirFactories == 0 then
                                        iActionToAssign = refActionBuildAirFactory
                                        iMaxEngisWanted = 1
                                    else
                                        if bHaveNoLandHQ then
                                            iActionToAssign = refActionBuildLandFactory
                                        elseif bHaveNoAirHQ then iActionToAssign = refActionBuildAirFactory
                                        else
                                            if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] then
                                                iActionToAssign = refActionBuildLandFactory
                                                iMaxEngisWanted = 1
                                            else iActionToAssign = refActionBuildAirFactory
                                                iMaxEngisWanted = 1
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 9 then --If engi tech level >1 then want to build power if have none >= that tech level
                        if bDebugMessages == true then LOG(sFunctionRef..': About to check if we have any power of current tech level') end
                        if iHighestFactoryOrEngineerTechAvailable > 1 then
                            if iT3Power == nil then iT3Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH3) end
                            if iHighestFactoryOrEngineerTechAvailable > 2 then
                                if iT3Power == 0 or (iT3Power < 2 and (GetGameTimeSeconds() - aiBrain[M27EconomyOverseer.refiLastEnergyStall] <= 60 or aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] <= 100)) then
                                    iSearchRangeForNearestEngi = 100
                                    if bDebugMessages == true then LOG(sFunctionRef..': Will build pogen') end
                                    iActionToAssign = refActionBuildPower
                                    if iT3Power == 0 then
                                        iMaxEngisWanted = 5
                                    else iMaxEngisWanted = 1 end
                                end
                            else
                                if iT2Power == nil then iT2Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH2) end
                                if iT2Power + iT3Power == 0 or (bWantMorePower and iT3Power == 0 and iT2Power < 4 and (bHaveLowMass == false or iT2Power < 2) and (aiBrain[M27EconomyOverseer.refiLastEnergyStall] <= 60 or aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] <= 50)) then
                                    iSearchRangeForNearestEngi = 100
                                    if bDebugMessages == true then LOG(sFunctionRef..': Will build pogen') end
                                    iActionToAssign = refActionBuildPower
                                    if iT2Power <= 3 then
                                        iMaxEngisWanted = 5
                                    else iMaxEngisWanted = 1 end
                                end
                            end
                            if bDebugMessages == true then
                                if iT2Power == nil then iT2Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH2) end
                                LOG('Condition:'..iCurrentConditionToTry..': iT3Power='..iT3Power..'; iT2Power='..iT2Power..'; iHighestFactoryOrEngineerTechAvailable='..iHighestFactoryOrEngineerTechAvailable..'; bWantMorePower='..tostring(bWantMorePower))
                                if iActionToAssign == nil then LOG('Not assigned an action') else LOG('iActionToAssign='..iActionToAssign) end
                            end
                        end
                        --Do we have any engis of the highest tech level already assigned?
                        if iActionToAssign and tiAvailableEngineersByTech[iHighestFactoryOrEngineerTechAvailable] > 0 and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign]) == false then
                            local iHighestTechLevelAssigned = 1
                            local iExistingEngineersAssigned = 0
                            for iSubtable, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] do
                                iExistingEngineersAssigned = iExistingEngineersAssigned + 1
                                iHighestTechLevelAssigned = math.max(M27UnitInfo.GetUnitTechLevel(tSubtable[refEngineerAssignmentEngineerRef]), iHighestTechLevelAssigned)
                                if iHighestTechLevelAssigned >=  iHighestFactoryOrEngineerTechAvailable then break end
                            end
                            if iHighestTechLevelAssigned < iHighestFactoryOrEngineerTechAvailable then
                                iMaxEngisWanted = math.max(iExistingEngineersAssigned + 1)
                            end
                        end
                    elseif iCurrentConditionToTry == 10 then --Non-early game want 1 engi getting unclaimed mexes as a higher priority
                        if iGameTime >= 360 then --6 mins
                            if iAllUnclaimedMexesInPathingGroup == nil then
                                tAllUnclaimedMexesInPathingGroup = GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, false, false, false)
                                if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInPathingGroup) == false then iAllUnclaimedMexesInPathingGroup = table.getn(tAllUnclaimedMexesInPathingGroup)
                                else iAllUnclaimedMexesInPathingGroup = 0 end
                            end
                            if iAllUnclaimedMexesInPathingGroup > 0 then
                                if iUnclaimedMexesWithinDefenceCoverage == nil then
                                    if iAllUnclaimedMexesInPathingGroup > 0 then
                                        tUnclaimedMexesWithinDefenceCoverage = FilterLocationsBasedOnDefenceCoverage(aiBrain, tAllUnclaimedMexesInPathingGroup, true)
                                        if M27Utilities.IsTableEmpty(tUnclaimedMexesWithinDefenceCoverage) == false then iUnclaimedMexesWithinDefenceCoverage = table.getn(tUnclaimedMexesWithinDefenceCoverage)
                                        else iUnclaimedMexesWithinDefenceCoverage = 0 end
                                    else iUnclaimedMexesWithinDefenceCoverage = 0 end
                                end
                                if iUnclaimedMexesWithinDefenceCoverage > 0 then
                                    iActionToAssign = refActionBuildMex
                                    iSearchRangeForNearestEngi = 10000
                                    iMaxEngisWanted = 1
                                    if bStillHaveEarlyEngis and iUnclaimedMexesWithinDefenceCoverage > 1 then iMaxEngisWanted = 2 end
                                    tExistingLocationsToPickFrom = tUnclaimedMexesWithinDefenceCoverage
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 11 then --Low power action part 1; also T3 power adjacency logic (as want this built as high priority  ahead of normal power)
                        local tT3Arti = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryFixedT3Arti, false, false)
                        if M27Utilities.IsTableEmpty(tT3Arti) == false then
                            if bDebugMessages == true then LOG(sFunctionRef..': Have T3 arti so will look to build power by it') end
                            --Do we already have an engineer with this action? If so will want to assist it so no need to refresh pgen adjacency locations
                            --reftEngineerAssignmentsByActionRef = 'M27EngineerAssignmentsByAction' --Records all engineers. [x][y]{1,2, 3} - x is the action ref; y is the engineer unique ref, 1 is the location ref, 2 is the engineer object (use the subtable ref keys instead of numbers to refer to these), 3 is refEngineerAssignmentActualLocation
                            if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildT3ArtiPower]) == false then iActionToAssign = refActionBuildT3ArtiPower
                            else
                                for iT3Arti, oT3Arti in tT3Arti do
                                    M27Logic.RefreshT3ArtiAdjacencyLocations(oT3Arti)
                                    if bDebugMessages == true then LOG(sFunctionRef..': Just called logic to refresh T3 arti adjacency locations for T3Arti='..oT3Arti.UnitId..M27UnitInfo.GetUnitLifetimeCount(oT3Arti)..'; Is the table of PGens wanted empty='..tostring(M27Utilities.IsTableEmpty(oT3Arti[M27UnitInfo.reftAdjacencyPGensWanted]))) end
                                    if M27Utilities.IsTableEmpty(oT3Arti[M27UnitInfo.reftAdjacencyPGensWanted]) == false then
                                        --Have locations for T3 arti
                                        iActionToAssign = refActionBuildT3ArtiPower
                                        --Have custom logic later that goes through all locations so this is to just avoid unexpected issues with logic up to this point and for things like selecting nearest engi to work
                                        table.insert(tExistingLocationsToPickFrom, oT3Arti[M27UnitInfo.reftAdjacencyPGensWanted][1][M27UnitInfo.refiSubrefBuildLocation])
                                        if bDebugMessages == true then LOG(sFunctionRef..': Have assigned '..repru(oT3Arti[M27UnitInfo.reftAdjacencyPGensWanted][1][M27UnitInfo.refiSubrefBuildLocation])..' as the base location but will override later') end
                                    end
                                end
                            end
                            if iActionToAssign == refActionBuildT3ArtiPower then
                                iMinEngiTechLevelWanted = 3
                                if aiBrain:GetEconomyStoredRatio('MASS') <= 0.01 then
                                    iMaxEngisWanted = 3
                                else
                                    iMaxEngisWanted = 10
                                end
                            end
                        end
                        if not(iActionToAssign) then --Normal low power action
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering normal low power logic; bHaveLowPower='..tostring(bHaveLowPower)..'; iMassStoredRatio='..iMassStoredRatio..'; Gross energy income='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; Are there no active HQ upgrades='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]))) end

                            if iMassStoredRatio == nil then iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS') end
                            if bHaveLowPower or (not(bHaveLowMass) and bWantMorePower) then -- and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] <= 40) or (aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] <= 275 and M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryAirFactory * categories.TECH2, aiBrain[M27EconomyOverseer.reftActiveHQUpgrades])) == false) then
                                --Build power unless early game hydro under construction in which case assist it instead
                                if bDebugMessages == true then LOG(sFunctionRef..': Want to build pgen unless hydro under construction') end
                                local bAssistHydroInstead = false
                                if iUnclaimedHydroNearBase > 0 and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildHydro]) == false then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Condition 4 (low power): iUnclaimedHydroNearBase='..iUnclaimedHydroNearBase..'; iGrossCurEnergyIncome='..iGrossCurEnergyIncome) end
                                    --Get first valid unit building hydro:
                                    local oUnitRecordedAsBuildingHydro, oEngi
                                    for iEngiUniqueRef, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildHydro] do
                                        oEngi = tSubtable[refEngineerAssignmentEngineerRef]
                                        if not(oEngi.Dead) and oEngi.GetPosition then
                                            oUnitRecordedAsBuildingHydro = oEngi
                                            break
                                        end
                                    end
                                    if oUnitRecordedAsBuildingHydro and not(oUnitRecordedAsBuildingHydro.Dead) and oUnitRecordedAsBuildingHydro.GetFocusUnit then
                                        local oHydro = oUnitRecordedAsBuildingHydro:GetFocusUnit()
                                        if EntityCategoryContains(refCategoryHydro, oHydro) then
                                            bAssistHydroInstead = true
                                        else
                                            if bDebugMessages == true then LOG(sFunctionRef..': low power1 condition: The unit being built isnt a hydro') end
                                        end
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': low power1 condition: Dont have a unit assigned to building hydro') end
                                    end
                                end
                                if bAssistHydroInstead == true then iActionToAssign = refActionBuildHydro
                                else
                                    if bNearbyHydro == nil then bNearbyHydro, tNearbyHydro = M27Conditions.HydroNearACUAndBase(aiBrain, true, true) end --Ignores ACU and just checks if near start position
                                    if bNearbyHydro and iUnclaimedHydroNearBase == nil then
                                        tUnclaimedHydroNearBase = FilterLocationsBasedOnIfUnclaimed(aiBrain, tNearbyHydro)
                                        if M27Utilities.IsTableEmpty(tUnclaimedHydroNearBase) == true then iUnclaimedHydroNearBase = 0
                                        else iUnclaimedHydroNearBase = table.getn(tUnclaimedHydroNearBase) end
                                    end
                                    if bNearbyHydro and iUnclaimedHydroNearBase > 0 then
                                        iActionToAssign = refActionBuildHydro
                                        tExistingLocationsToPickFrom = tUnclaimedHydroNearBase
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': Will build pogen') end
                                        iActionToAssign = refActionBuildPower
                                    end
                                end

                                iSearchRangeForNearestEngi = 75
                                iMaxEngisWanted = 3

                                if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] > 16 and aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] < 40 then
                                    iMaxEngisWanted = 4
                                    if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] > 20 and iMassStoredRatio > 0.1 then iMaxEngisWanted = 5 end
                                end
                                if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] <= 275 and M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryAirFactory * categories.TECH2, aiBrain[M27EconomyOverseer.reftActiveHQUpgrades])) == false then iMaxEngisWanted = 6 end
                            end
                        end
                    elseif iCurrentConditionToTry == 12 then --High priority energy storage
                        --Want to build energy storage if dont have any, and either have no ACU, or ACU is in combat and have high energy
                        if iEnergyStoredRatio == nil then iEnergyStoredRatio = aiBrain:GetEconomyStoredRatio('ENERGY') end
                        if aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] >= 1 or iEnergyStoredRatio == 1 then
                            if M27Utilities.IsACU(M27Utilities.GetACU(aiBrain)) then
                                --Does the ACU have more than 2 enemy units near it, or less than 90% health?
                                if (M27Utilities.GetACU(aiBrain).PlatoonHandle[M27PlatoonUtilities.refiEnemiesInRange] or 0) >= 3 or M27UnitInfo.GetUnitHealthPercent(M27Utilities.GetACU(aiBrain)) < 0.9 or aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 100 then
                                    if iEnergyStoredRatio == nil then iEnergyStoredRatio = aiBrain:GetEconomyStoredRatio('ENERGY') end
                                    if iEnergyStoredRatio > 0 then
                                        if iEnergyStorageMax == nil then iEnergyStorageMax = iEnergyStored / iEnergyStoredRatio end
                                        if iEnergyStorageMax < 9000 then
                                            iActionToAssign = refActionBuildEnergyStorage
                                            iMaxEngisWanted = math.max(1, math.floor(math.min(aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome], 4, aiBrain[M27EconomyOverseer.refiMassNetBaseIncome] * 10)))
                                        end
                                    end
                                end

                            else
                                --Dont have ACU - so build storage if have none
                                if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEnergyStorage) == 0 then
                                    iActionToAssign = refActionBuildEnergyStorage
                                    iMaxEngisWanted = 4
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 13 then --Initial land factories (high priority with low resource conditions)
                        if iLandFactories == nil then
                            iLandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory)
                            if iLandFactories == nil then iLandFactories = 0 end
                        end
                        if iAirFactories == nil then
                            iAirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory)
                            if iAirFactories == nil then iAirFactories = 0 end
                        end
                        if iMassStored == nil then iMassStored = aiBrain:GetEconomyStored('MASS') end
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering buildilng land facs, iMassStored='..iMassStored..'; iEnergyStored='..iEnergyStored..'; iLandFactories='..iLandFactories) end

                        if iMassStored > 100 and iEnergyStored > 250 and (not(bHaveLowMass) or (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] and not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech))) and (iLandFactories < aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes] or iAirFactories < 1 or aiBrain[M27EconomyOverseer.refbWantMoreFactories] == true) then
                            iSearchRangeForNearestEngi = 75
                            iMaxEngisWanted = 2
                            if iLandFactories < aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes] then iActionToAssign = refActionBuildLandFactory
                            else
                                if iAirFactories < 1 then iActionToAssign = refActionBuildAirFactory
                                else
                                    if bHaveLowPower == false and bHaveLowMass == false then
                                        if iAirFactories < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir] then iActionToAssign = refActionBuildAirFactory
                                        else
                                            if not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance) and iLandFactories < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] then iActionToAssign = refActionBuildLandFactory end
                                        end
                                    end
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 14 then --SMD
                        if bDebugMessages == true then LOG(sFunctionRef..': Checking if need to build SMD; iHighestFactoryOrEngineerTechAvailable='..iHighestFactoryOrEngineerTechAvailable..'; M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers])='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers]))) end
                        if iHighestFactoryOrEngineerTechAvailable >= 3 and M27Utilities.IsTableEmpty(aiBrain[M27Overseer.reftEnemyNukeLaunchers]) == false then
                            --Do we have as many SMD as they have nuke launchers?
                            local iSMDsWeHave = 0
                            local iSMDsWithNoMissiles = 0
                            local tSMD = aiBrain:GetListOfUnits(M27UnitInfo.refCategorySMD, false, true)
                            if M27Utilities.IsTableEmpty(tSMD) == false then
                                for iSMDNumber, oSMD in tSMD do
                                    --Check we've completed construction
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have an SMD, will check if its completed construction') end
                                    if M27UnitInfo.IsUnitValid(oSMD, true) then
                                        iSMDsWeHave = iSMDsWeHave + 1
                                        --Check missile count
                                        if bDebugMessages == true then LOG(sFunctionRef..': SMD LC='..M27UnitInfo.GetUnitLifetimeCount(oSMD)..'; will check its nuke silo ammo count') end
                                        if oSMD.GetTacticalSiloAmmoCount and oSMD:GetTacticalSiloAmmoCount() < 1 and not(oSMD[refbMissileRecentlyBuilt]) then
                                            iSMDsWithNoMissiles = iSMDsWithNoMissiles + 1
                                            --Backup - make sure we try to build more missiles in case we have paused
                                            oSMD:SetPaused(false)
                                            oSMD:SetAutoMode(true)
                                        end
                                        if bDebugMessages == true then
                                            if oSMD.GetNukeSiloAmmoCount then LOG('Silo ammo count='..oSMD:GetNukeSiloAmmoCount())
                                            else LOG('SiloAmmoCount doesnt exist') end
                                            if oSMD.GetTacticalSiloAmmoCount then LOG('GetTacticalSiloAmmoCount='..oSMD:GetTacticalSiloAmmoCount()) else LOG('GetTacticalSiloAmmoCount doesnt exist') end
                                        end
                                    end
                                end
                            end
                            local iEnemyNukes = 0 --Cant use table.getn
                            for iNuke, oNuke in aiBrain[M27Overseer.reftEnemyNukeLaunchers] do
                                iEnemyNukes = iEnemyNukes + 1
                            end
                            iEnemyNukes = math.max(iEnemyNukes, 1) --Redundancy - if table isnt empty enemy must have at least one
                            if bDebugMessages == true then LOG(sFunctionRef..': iSMDsWeHave='..iSMDsWeHave..'; iEnemyNukes='..iEnemyNukes..'; iSMDsWithNoMissiles='..iSMDsWithNoMissiles) end
                            if iSMDsWeHave < iEnemyNukes then
                                aiBrain[refbNeedResourcesForMissile] = true
                                iMinEngiTechLevelWanted = 3
                                iActionToAssign = refActionBuildSMD
                                iMaxEngisWanted = 20
                                if bHaveLowPower == false and bHaveLowMass == false then iMaxEngisWanted = 30 end

                            elseif iSMDsWithNoMissiles > 0 then
                                --We have enough SMDs, so want to assist SMD unless all SMDs have an anti-nuke loaded already
                                aiBrain[refbNeedResourcesForMissile] = true
                                iActionToAssign = refActionAssistSMD
                                iMaxEngisWanted = 20
                                if bHaveLowPower == false and bHaveLowMass == false then iMaxEngisWanted = 40 end
                            else
                                aiBrain[refbNeedResourcesForMissile] = false
                                --Have SMDs but they all have anti-nuke loaded; check if we have any engineers already assigned to this action and if so clear them
                                if bDebugMessages == true then LOG(sFunctionRef..': Checking if any engineers have been assigned to assist SMD, if so will clear their actions') end
                                if aiBrain[reftEngineerAssignmentsByActionRef] and aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistSMD] and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistSMD]) == false then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Engineers have been assigned to assist an SMD, will cycle through them') end
                                    --Cant use table.getn for this table so do manually:
                                    for iUniqueRef, tSubtable in  aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistSMD] do
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef..': refEngineerAssignmentEngineerRef='..repru(aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistSMD][iUniqueRef][refEngineerAssignmentLocationRef]))
                                            LOG(sFunctionRef..': oEngineer UC='..GetEngineerUniqueCount(aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistSMD][iUniqueRef][refEngineerAssignmentEngineerRef])..'; About to check if valid unit')
                                        end
                                        if M27UnitInfo.IsUnitValid(tSubtable[refEngineerAssignmentEngineerRef]) then
                                            --if GetEngineerUniqueCount(tSubtable[refEngineerAssignmentEngineerRef]) == 31 and GetGameTimeSeconds() >= 305 then bDebugMessages = true end
                                            --if tSubtable[refEngineerAssignmentEngineerRef]:IsUnitState('Building') or tSubtable[refEngineerAssignmentEngineerRef]:IsUnitState('Repairing') then bDebugMessages = true M27Utilities.ErrorHandler('Clearing an engineer whose unit state is building or repairing') end
                                            if bDebugMessages == true then LOG(sFunctionRef..': Engineer is assigned the action so will clear it') end
                                            IssueClearCommands({tSubtable[refEngineerAssignmentEngineerRef]})
                                            ClearEngineerActionTrackers(aiBrain, tSubtable[refEngineerAssignmentEngineerRef], true)
                                        end
                                    end
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': No engineers appear to have been assigned to assist an SMD') end
                                end

                                --Do we want 1 extra SMD to give coverage to exposed T3 buildings?  Only consider buildings within the lower of 250, 40% from our base, and also only within the same land pathing group
                                if iSMDsWeHave <= iEnemyNukes then --i.e. cap at 1 more SMD than enemy nukes, to avoid the risk we cant build at the desired location, and so end up in a cycle of building SMD to rptoect the desired location, ending up building nearby, and then building another nearby and another etc.
                                    local tPotentialBuildingsToCover = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryStructure * categories.TECH3 + M27UnitInfo.refCategoryStructure * categories.EXPERIMENTAL, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], math.min(250, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.4), 'Ally')
                                    if bDebugMessages == true then LOG(sFunctionRef..': Deciding if want extra SMD to cover T3 buildings.  Size of potential buildings='..table.getn(tPotentialBuildingsToCover)) end
                                    if M27Utilities.IsTableEmpty(tPotentialBuildingsToCover) == false and table.getn(tPotentialBuildingsToCover) >= 5 then
                                        local tBuildingsToCover = {}
                                        local iBuildingsToCover = 0
                                        local iLandPathingGroupWanted = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                        local bUnitCoveredBySMD
                                        --tSMD
                                        --aiBrain[M27Overseer.reftEnemyNukeLaunchers]


                                        for iUnit, oUnit in tPotentialBuildingsToCover do
                                            if bDebugMessages == true then LOG(sFunctionRef..': Considering if oUnit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..' wants SMD coverage.  Land pathing group='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, oUnit:GetPosition())..'; Land pathing of base='..iLandPathingGroupWanted..'; Fraction complete='..oUnit:GetFractionComplete()..'; Is unit covered by SMD='..tostring(IsUnitCoveredBySMD(aiBrain, oUnit, tSMD, aiBrain[M27Overseer.reftEnemyNukeLaunchers]))) end
                                            if oUnit:GetFractionComplete() == 1 then
                                                if M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, oUnit:GetPosition()) == iLandPathingGroupWanted then
                                                    if not(IsUnitCoveredBySMD(aiBrain, oUnit, tSMD, aiBrain[M27Overseer.reftEnemyNukeLaunchers])) then
                                                        iBuildingsToCover = iBuildingsToCover + 1
                                                        tBuildingsToCover[iBuildingsToCover] = oUnit
                                                    end
                                                end
                                            end

                                        end
                                        if bDebugMessages == true then LOG(sFunctionRef..': iBuildingsToCover='..iBuildingsToCover) end
                                        if iBuildingsToCover >= 4 then
                                            local tPossibleSMDLocation = M27Utilities.GetAveragePosition(tBuildingsToCover)
                                            local iAdditionalBuildingsCovered = 0
                                            local iCurDist
                                            for iUnit, oUnit in tBuildingsToCover do
                                                iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tPossibleSMDLocation)
                                                if bDebugMessages == true then LOG(sFunctionRef..': Dist between possible SMD location of '..repru(tPossibleSMDLocation)..' and unit locatino of '..repru(oUnit:GetPosition())..' is '..iCurDist..'; Unit='..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)) end
                                                if iCurDist <= 60 then
                                                    iAdditionalBuildingsCovered = iAdditionalBuildingsCovered + 1
                                                elseif iCurDist <= 90 then
                                                    iAdditionalBuildingsCovered = iAdditionalBuildingsCovered + 0.5
                                                end
                                            end
                                            if bDebugMessages == true then LOG(sFunctionRef..': iAdditionalBuildingsCovered='..iAdditionalBuildingsCovered) end
                                            if iAdditionalBuildingsCovered >= 4 then
                                                iActionToAssign = refActionBuildSMD
                                                iMaxEngisWanted = 20
                                                if bHaveLowPower == false and bHaveLowMass == false then iMaxEngisWanted = 30 end
                                                tExistingLocationsToPickFrom = {}
                                                tExistingLocationsToPickFrom[1] = tPossibleSMDLocation
                                                if bDebugMessages == true then LOG(sFunctionRef..': Will try and build an extra SMD') end
                                            end
                                        end
                                    end
                                end
                            end

                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Finsihed considering if want to build or assist SMD. iActionToAssign='..(iActionToAssign or 'nil')) end
                    elseif iCurrentConditionToTry == 15 then --Emergency AA when non-air threat near our base and we have no AA
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering if we want to build static AA as an emergency; aiBrain[M27AirOverseer.refiHighestEnemyAirThreat]='..aiBrain[M27AirOverseer.refiHighestEnemyAirThreat]..'; aiBrain[M27AirOverseer.refiOurMassInAirAA]='..aiBrain[M27AirOverseer.refiOurMassInAirAA]..'; aiBrain[M27AirOverseer.refiOurMassInMAA]='..aiBrain[M27AirOverseer.refiOurMassInMAA]..'; iHighestFactoryOrEngineerTechAvailable='..iHighestFactoryOrEngineerTechAvailable) end
                        if aiBrain[M27AirOverseer.refiAirAANeeded] > 0 and not(M27Utilities.IsTableEmpty(aiBrain[M27AirOverseer.reftNearestEnemyAirThreat])) and M27Utilities.GetDistanceBetweenPositions(aiBrain[M27AirOverseer.reftNearestEnemyAirThreat], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= math.min(150, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.5) and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryStructureAA * M27UnitInfo.ConvertTechLevelToCategory(iHighestFactoryOrEngineerTechAvailable)) == 0 then
                            iActionToAssign = refActionBuildAA
                            iMinEngiTechLevelWanted = iHighestFactoryOrEngineerTechAvailable
                            iMaxEngisWanted = 4
                        end
                    elseif iCurrentConditionToTry == 16 then --Omni to protect from cloaked ACU/SACU, or if enemy has large air threat and have ok resources
                        if (aiBrain[M27Overseer.refbCloakedEnemyACU] or (bHaveLowMass == false and not(aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyProtectACU) and aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] >= 175 and (aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] >= 7000 or (aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] >= 4000 and (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyLandMain or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle))))) and iHighestFactoryOrEngineerTechAvailable >= 3 then
                            if (aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] >= 350 or aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 1000) and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 5 then
                                --Have resources to support an emergency omni - do we or an ally already have one nearby?

                                if M27Utilities.IsTableEmpty(aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT3Radar, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 100, 'Ally')) then
                                    --No nearby omnis so want to build one
                                    iActionToAssign = refActionBuildT3Radar
                                    iMinEngiTechLevelWanted = 3
                                    iMaxEngisWanted = math.min(10, math.max(3, aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] / 100))
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 17 then --Assist air fac if ACU needs protecting, or has taken recent torpedo damage and is underwater
                        if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyProtectACU then
                            if iAirFactories == nil then
                                iAirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory)
                                if iAirFactories == nil then iAirFactories = 0 end
                            end
                            if iAirFactories > 0 then
                                iActionToAssign = refActionAssistAirFactory
                                iMaxEngisWanted = 3
                                if bHaveLowPower == false then
                                    if bHaveLowMass == false then iMaxEngisWanted = 10
                                    else iMaxEngisWanted = 5
                                    end
                                    if GetGameTimeSeconds() - (M27Utilities.GetACU(aiBrain)[M27Overseer.refiACULastTakenUnseenOrTorpedoDamage] or -100) <= 30 and M27UnitInfo.IsUnitUnderwater(M27Utilities.GetACU(aiBrain)) then
                                        iMaxEngisWanted = iMaxEngisWanted + 5
                                    end
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 18 then --Shield if needed for SML/SMD as high priority
                        if not(bHaveVeryLowPower) and aiBrain[M27Overseer.refbDefendAgainstArti] then
                            RefreshUnitsWantingFixedShields(aiBrain)
                            if M27Utilities.IsTableEmpty(aiBrain[reftUnitsWantingFixedShield]) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategorySMD + M27UnitInfo.refCategorySML + M27UnitInfo.refCategoryFixedT3Arti, aiBrain[reftUnitsWantingFixedShield])) == false then
                                --Have SML or SMD that needs a shield, and enemy has novax or T3 arti, so need to shield as high priority
                                iActionToAssign = refActionBuildShield
                                iMaxEngisWanted = 5
                                if bHaveLowPower then iMaxEngisWanted = 1 elseif bHaveLowMass then iMaxEngisWanted = 3 end
                                iMinEngiTechLevelWanted = 3
                            end
                        end
                    elseif iCurrentConditionToTry == 19 then --Assist shields to defend against arti
                        if not(bHaveLowPower) and aiBrain[M27Overseer.refbDefendAgainstArti] then
                            RecordPriorityShields(aiBrain)
                            if M27Utilities.IsTableEmpty(aiBrain[reftPriorityShieldsToAssist]) == false then
                                iMaxEngisWanted = table.getsize(aiBrain[reftPriorityShieldsToAssist]) * 13
                                iActionToAssign = refActionAssistShield
                                iMinEngiTechLevelWanted = 2 --T1 engis will do too little and could cause us to think we'll be ok when we wont be
                                if bDebugMessages == true then
                                    LOG(sFunctionRef..': Have priority shields to assist. iMaxEngisWanted='..iMaxEngisWanted..'; size of shields to assist table='..table.getsize(aiBrain[reftPriorityShieldsToAssist])..'; will cycle through each entry')
                                    for iShield, oShield in aiBrain[reftPriorityShieldsToAssist] do
                                        LOG(sFunctionRef..': Priority shield='..oShield.UnitId..M27UnitInfo.GetUnitLifetimeCount(oShield))
                                    end
                                end

                            end
                        end
                    elseif iCurrentConditionToTry == 20 then --Shield for T2 arti if are turtling
                        if not(bHaveLowPower) and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 6 and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle then
                            RefreshUnitsWantingFixedShields(aiBrain)
                            if M27Utilities.IsTableEmpty(aiBrain[reftUnitsWantingFixedShield]) == false and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(M27UnitInfo.refCategoryFixedT2Arti, aiBrain[reftUnitsWantingFixedShield])) == false then
                                iActionToAssign = refActionBuildShield
                                iMaxEngisWanted = 5
                                if bHaveLowMass then iMaxEngisWanted = 3 end
                                iMinEngiTechLevelWanted = 2
                            end
                        end
                    elseif iCurrentConditionToTry == 21 then --Initial engi for experimental (to reduce risk we spend a while looking for somewhere to build)
                        if iMassStoredRatio == nil then iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS') end
                        if aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 22 and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildExperimental]) and (iMassStoredRatio >= 0.1 or aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 35) then
                            iActionToAssign = refActionBuildExperimental
                            iMaxEngisWanted = 1
                            iMinEngiTechLevelWanted = 3
                            if iMassStoredRatio >= 0.75 and not(bHaveLowPower) then iMaxEngisWanted = 5 end
                        elseif aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 40 and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildSecondExperimental]) and (iMassStoredRatio >= 0.15 or aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 52.5) then
                            iActionToAssign = refActionBuildSecondExperimental
                            iMaxEngisWanted = 1
                            iMinEngiTechLevelWanted = 3
                        end

                    elseif iCurrentConditionToTry == 22 then --Engis for transport
                        if bDebugMessages == true then LOG(sFunctionRef..': Is table of transports waiting for engineers empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27Transport.reftTransportsWaitingForEngi]))) end
                        if M27Utilities.IsTableEmpty(aiBrain[M27Transport.reftTransportsWaitingForEngi]) == false then
                            iActionToAssign = refActionLoadOnTransport
                            iMaxEngisWanted = aiBrain[M27Transport.refiEngineersWantedForTransports]
                            if bDebugMessages == true then LOG(sFunctionRef..': Want action to load on transport, with iMaxEngisWanted='..iMaxEngisWanted) end
                        end

                    elseif iCurrentConditionToTry == 23 then --Nuke assist
                        if bDebugMessages == true then LOG(sFunctionRef..': Checking if have a nuke that want to assist; aiBrain[M27EconomyOverseer.refbStallingEnergy]='..tostring(aiBrain[M27EconomyOverseer.refbStallingEnergy])..'; Number of SMLs='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategorySML)..'; iHighestFactoryOrEngineerTechAvailable='..iHighestFactoryOrEngineerTechAvailable..'; aiBrain[M27EconomyOverseer.refbReclaimNukes]='..tostring((aiBrain[M27EconomyOverseer.refbReclaimNukes] or false))) end
                        if iHighestFactoryOrEngineerTechAvailable >= 3 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategorySML) > 0 and not(aiBrain[M27EconomyOverseer.refbReclaimNukes]) and not(aiBrain[M27EconomyOverseer.refbStallingEnergy]) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Want to assist nuke') end
                            aiBrain[refbNeedResourcesForMissile] = true
                            iMinEngiTechLevelWanted = 3
                            iActionToAssign = refActionAssistNuke
                            iMaxEngisWanted = 5
                            if bHaveLowPower == false and bHaveLowMass == false then
                                if aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] < 150 then iMaxEngisWanted = 15
                                else iMaxEngisWanted = 30 end
                            end
                        end






                        --..................................................--
                        --END OF INITIAL ENGINEER BUILD ORDER


                    elseif iCurrentConditionToTry == 24 then --Unclaimed mexes within defender coverage

                        bThresholdInitialEngineerCondition = true



                        if iAllUnclaimedMexesInPathingGroup == nil then
                            tAllUnclaimedMexesInPathingGroup = GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, false, false, false)
                            if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInPathingGroup) == false then iAllUnclaimedMexesInPathingGroup = table.getn(tAllUnclaimedMexesInPathingGroup)
                            else iAllUnclaimedMexesInPathingGroup = 0 end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Looking if unclaimed mexes within defence coverage, iAllUnclaimedMexesInPathingGroup='..iAllUnclaimedMexesInPathingGroup) end
                        if iAllUnclaimedMexesInPathingGroup > 0 then
                            if iUnclaimedMexesWithinDefenceCoverage == nil then
                                tUnclaimedMexesWithinDefenceCoverage = FilterLocationsBasedOnDefenceCoverage(aiBrain, tAllUnclaimedMexesInPathingGroup, true)
                                if M27Utilities.IsTableEmpty(tUnclaimedMexesWithinDefenceCoverage) == false then iUnclaimedMexesWithinDefenceCoverage = table.getn(tUnclaimedMexesWithinDefenceCoverage)
                                else iUnclaimedMexesWithinDefenceCoverage = 0 end
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': Have unclaimed mexes in pathing group, iUnclaimedMexesWithinDefenceCoverage='..iUnclaimedMexesWithinDefenceCoverage) end
                            if iUnclaimedMexesWithinDefenceCoverage > 2 then
                                iActionToAssign = refActionBuildMex
                                iMaxEngisWanted = math.ceil(iUnclaimedMexesWithinDefenceCoverage / 1.35) + 1
                                if bStillHaveEarlyEngis and iUnclaimedMexesWithinDefenceCoverage > 3 then iMaxEngisWanted = iMaxEngisWanted + 1 end
                                tExistingLocationsToPickFrom = tUnclaimedMexesWithinDefenceCoverage
                                iSearchRangeForNearestEngi = 10000
                            elseif not(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand]) then
                                --Do we have mexes that are land pathable from our base?
                                if iAllUnclaimedMexesInLandPathingGroup == nil then
                                    --Include enemy mexes in this list since if theyre on our land pathable mass it could just be a lucky engi got through
                                    tAllUnclaimedMexesInLandPathingGroup = GetUnclaimedMexes(aiBrain, M27UnitInfo.refPathingTypeLand, M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeLand, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]), true, false, false)
                                    if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInLandPathingGroup) then iAllUnclaimedMexesInLandPathingGroup = 0
                                    else iAllUnclaimedMexesInLandPathingGroup = table.getn(tAllUnclaimedMexesInLandPathingGroup)
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': iAllUnclaimedMexesInLandPathingGroup='..iAllUnclaimedMexesInLandPathingGroup) end
                                if iAllUnclaimedMexesInLandPathingGroup > 0 then
                                    iActionToAssign = refActionBuildMex
                                    iMaxEngisWanted = math.min(2, math.max(1, math.ceil(iAllUnclaimedMexesInPathingGroup / 3)))
                                    if bStillHaveEarlyEngis and iAllUnclaimedMexesInPathingGroup > 4 then iMaxEngisWanted = iMaxEngisWanted + 1 end
                                    tExistingLocationsToPickFrom = tAllUnclaimedMexesInLandPathingGroup
                                    iSearchRangeForNearestEngi = 10000
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 25 then --T1/T2 radar if enemy may have significant air threat or high tech units
                        if bHaveLowPower == false then
                            if iCurRadarCount == nil then iCurRadarCount = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryRadar) end
                            if iCurRadarCount == 0 then
                                if iNetCurEnergyIncome > 5 and iEnergyStored >= 2000 and not(bHaveLowMass) and (aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] >= 50 or aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 3 or aiBrain:GetEconomyStored('MASS') >= 400) then
                                    iActionToAssign = refActionBuildT1Radar
                                    iMaxEngisWanted = 1
                                end
                            else
                                --Already have a radar, check if enemy has T2+ air factory or we have T2 arti, in which case  we or an ally has T3
                                if aiBrain[M27Overseer.refiEnemyHighestTechLevel] >= 3 or aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryFixedT2Arti) then
                                    if iNearbyOmniCount == nil then
                                        local tNearbyOmni = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT3Radar, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 250, 'Ally')
                                        if M27Utilities.IsTableEmpty(tNearbyOmni) == false then iNearbyOmniCount = table.getn(tNearbyOmni)
                                        else iNearbyOmniCount = 0 end
                                    end
                                    if iNearbyOmniCount == 0 then
                                        if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] >= 100 and aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] >= 15 then
                                            --Do we already have T2 radar
                                            if iCurT2RadarCount == nil then iCurT2RadarCount = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Radar) end
                                            if iCurT2RadarCount == 0 and iNetCurEnergyIncome >= 40 then
                                                iActionToAssign = refActionBuildT2Radar
                                                iMinEngiTechLevelWanted = 2
                                                iMaxEngisWanted = 3
                                            end
                                        end
                                    end
                                end
                            end
                        end

                    elseif iCurrentConditionToTry == 26 then --Hydro within our defence coverage?'
                        if iUnclaimedHydroWithinDefenceCoverage == nil then
                            if tAllUnclaimedHydroInPathingGroup == nil then tAllUnclaimedHydroInPathingGroup = GetUnclaimedHydros(aiBrain, sPathing, iPathingGroup, false, false, false)  end
                            if M27Utilities.IsTableEmpty(tAllUnclaimedHydroInPathingGroup) == false then
                                tUnclaimedHydroWithinDefenceCoverage = FilterLocationsBasedOnDefenceCoverage(aiBrain, tAllUnclaimedHydroInPathingGroup, true)
                                if M27Utilities.IsTableEmpty(tUnclaimedHydroWithinDefenceCoverage) == true then iUnclaimedHydroWithinDefenceCoverage = 0
                                else iUnclaimedHydroWithinDefenceCoverage = table.getn(tUnclaimedHydroWithinDefenceCoverage) end
                            else iUnclaimedHydroWithinDefenceCoverage = 0
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': iUnclaimedHydroWithinDefenceCoverage='..iUnclaimedHydroWithinDefenceCoverage) end
                        if iUnclaimedHydroWithinDefenceCoverage > 0 then
                            if bDebugMessages == true then LOG(sFunctionRef..': Want to build hydro as is at least 1 within defense coverage; iUnclaimedHydroWithinDefenceCoverage='..iUnclaimedHydroWithinDefenceCoverage) end
                            iActionToAssign = refActionBuildHydro
                            tExistingLocationsToPickFrom = tUnclaimedHydroNearBase
                            iSearchRangeForNearestEngi = 10000
                            iMaxEngisWanted = 2
                            --Increase max number of engis if hydro is close to us
                            local iNearestHydroDistance = 10000
                            local iCurHydroDistance
                            for iHydro, tHydro in tUnclaimedHydroWithinDefenceCoverage do
                                iCurHydroDistance = M27Utilities.GetDistanceBetweenPositions(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], tHydro)
                                if iCurHydroDistance < iNearestHydroDistance then iNearestHydroDistance = iCurHydroDistance end
                            end
                            if iNearestHydroDistance <= 90 then iMaxEngisWanted = 4 end
                            tExistingLocationsToPickFrom = tUnclaimedHydroWithinDefenceCoverage
                        end
                    elseif iCurrentConditionToTry == 27 then --Static AA due to losing air control
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering if we want to build static AA; aiBrain[M27AirOverseer.refiHighestEnemyAirThreat]='..aiBrain[M27AirOverseer.refiHighestEnemyAirThreat]..'; aiBrain[M27AirOverseer.refiOurMassInAirAA]='..aiBrain[M27AirOverseer.refiOurMassInAirAA]..'; aiBrain[M27AirOverseer.refiOurMassInMAA]='..aiBrain[M27AirOverseer.refiOurMassInMAA]..'; iHighestFactoryOrEngineerTechAvailable='..iHighestFactoryOrEngineerTechAvailable) end
                        if aiBrain[M27Overseer.refbEmergencyMAANeeded] or aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] > 1000 and aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] * 0.8 - aiBrain[M27AirOverseer.refiOurMassInAirAA] - aiBrain[M27AirOverseer.refiOurMassInMAA] * 2 > 1000 then
                            local iStaticAAWanted = math.floor((aiBrain[M27AirOverseer.refiHighestEnemyAirThreat] * 0.8 - aiBrain[M27AirOverseer.refiOurMassInAirAA] - aiBrain[M27AirOverseer.refiOurMassInMAA] * 2) / (750 * iHighestFactoryOrEngineerTechAvailable))
                            if aiBrain[M27Overseer.refbEmergencyMAANeeded] then iStaticAAWanted = 1 end
                            if iStaticAAWanted > 0 then
                                iStaticAAWanted = math.min(iStaticAAWanted, 10)
                                local iExistingAA = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryStructureAA * M27UnitInfo.ConvertTechLevelToCategory(iHighestFactoryOrEngineerTechAvailable))
                                if bDebugMessages == true then LOG(sFunctionRef..': iStaticAAWanted='..iStaticAAWanted..'; iExistingAA='..iExistingAA) end
                                if iExistingAA < iStaticAAWanted then
                                    iActionToAssign = refActionBuildAA
                                    iMinEngiTechLevelWanted = iHighestFactoryOrEngineerTechAvailable
                                    iMaxEngisWanted = math.min((iStaticAAWanted - iExistingAA) * 3, 6)
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 28 then --Lower power action part 2 - want enough power to support guncom
                        if bDebugMessages == true then LOG(sFunctionRef..': 2nd low power action; bHaveLowPower='..tostring(bHaveLowPower)..'; bWantMorePower='..tostring(bWantMorePower)..'; bHaveLowMass='..tostring(bHaveLowMass)) end
                        if bHaveLowPower or (bWantMorePower and bHaveLowMass == false) then
                            --Hydro or power
                            if bNearbyHydro == nil then bNearbyHydro, tNearbyHydro = M27Conditions.HydroNearACUAndBase(aiBrain, true, true) end --Ignores ACU and just checks if near start position
                            if iUnclaimedHydroNearBase == nil then
                                if bNearbyHydro == false then
                                    iUnclaimedHydroNearBase = 0
                                else
                                    tUnclaimedHydroNearBase = FilterLocationsBasedOnIfUnclaimed(aiBrain, tNearbyHydro)
                                    if M27Utilities.IsTableEmpty(tUnclaimedHydroNearBase) == true then iUnclaimedHydroNearBase = 0
                                    else iUnclaimedHydroNearBase = table.getn(tUnclaimedHydroNearBase) end
                                end
                            end
                            iSearchRangeForNearestEngi = 75
                            if iUnclaimedHydroNearBase > 0 then
                                iActionToAssign = refActionBuildHydro
                                tExistingLocationsToPickFrom = tUnclaimedHydroNearBase
                                iMaxEngisWanted = 5
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': Will build pogen') end
                                iActionToAssign = refActionBuildPower
                                iMaxEngisWanted = math.min(math.ceil(iAllEngineers * 0.4), 5)
                            end
                            if bDebugMessages == true then LOG(sFunctionRef..': 2nd low power action: Want to build power; iAllEngineers='..iAllEngineers..'; iMaxEngisWanted='..iMaxEngisWanted) end
                        end
                    elseif iCurrentConditionToTry == 29 then --Mass storage around T2/T3 mexes
                        if bHaveLowPower == false and M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftMassStorageLocations]) == false and iNetCurEnergyIncome > 8 then
                            iActionToAssign = refActionBuildMassStorage
                            iMaxEngisWanted = 5
                            --Pick the best 3 locations as the target for storage, provided they're reasonably comparable in preference
                            local tClosestSubtableRef = {}
                            local iLastModDistance = 100000
                            local iCurModDistance
                            local iClosestCount = 0
                            local iMaxModDistanceIncrease = 30
                            local bInclude
                            for iSubtable, tSubtable in M27Utilities.SortTableBySubtable(aiBrain[M27EconomyOverseer.reftMassStorageLocations], M27EconomyOverseer.refiStorageSubtableModDistance, true) do
                                iCurModDistance = tSubtable[M27EconomyOverseer.refiStorageSubtableModDistance]
                                if iCurModDistance - iLastModDistance <= iMaxModDistanceIncrease then
                                    iClosestCount = iClosestCount + 1
                                    tClosestSubtableRef[iClosestCount] = iSubtable
                                    iLastModDistance = iCurModDistance
                                    if iClosestCount >= 3 then break end
                                end
                            end

                            --[[for iSubtable, tSubtable in aiBrain[M27EconomyOverseer.reftMassStorageLocations] do
                        if tSubtable[M27EconomyOverseer.refiStorageSubtableModDistance] < iClosestModDistance then
                            iClosestModDistance = tSubtable[M27EconomyOverseer.refiStorageSubtableModDistance]
                            iClosestSubtableRef = iSubtable
                        end
                    end--]]
                            tExistingLocationsToPickFrom = {}
                            for iEntry, vEntry in tClosestSubtableRef do
                                tExistingLocationsToPickFrom[iEntry] = {}
                                tExistingLocationsToPickFrom[iEntry][1] = aiBrain[M27EconomyOverseer.reftMassStorageLocations][vEntry][M27EconomyOverseer.reftStorageSubtableLocation][1]
                                tExistingLocationsToPickFrom[iEntry][2] = aiBrain[M27EconomyOverseer.reftMassStorageLocations][vEntry][M27EconomyOverseer.reftStorageSubtableLocation][2]
                                tExistingLocationsToPickFrom[iEntry][3] = aiBrain[M27EconomyOverseer.reftMassStorageLocations][vEntry][M27EconomyOverseer.reftStorageSubtableLocation][3]
                            end
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': tExistingLocationsToPickFrom='..repru(tExistingLocationsToPickFrom))
                                M27Utilities.DrawLocation(tExistingLocationsToPickFrom[1], nil, 1, 100)
                            end
                        end
                    elseif iCurrentConditionToTry == 30 then --TML if think enough targets
                        --if iHighestFactoryOrEngineerTechAvailable >= 2 and tiAvailableEngineersByTech[2] > 0 then bDebugMessages = true end
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering if we want to build a TML. iHighestFactoryOrEngineerTechAvailable='..iHighestFactoryOrEngineerTechAvailable..'; aiBrain[refiTimeOfLastFailedTML]='..(aiBrain[refiTimeOfLastFailedTML] or 'nil')..'; aiBrain[M27Overseer.refiModDistFromStartNearestThreat]='..aiBrain[M27Overseer.refiModDistFromStartNearestThreat]..'; refbNeedIndirect='..tostring(aiBrain[M27Overseer.refbNeedIndirect])..'; aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryTML='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryTML)..'; M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildTML]='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildTML]))..'; bHaveLowMass='..tostring(bHaveLowMass)..'; Is list of firebase units empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftFirebaseUnitsByFirebaseRef]) == false)) end
                        if iHighestFactoryOrEngineerTechAvailable >= 2 and not(aiBrain[refiTimeOfLastFailedTML]) and (aiBrain[M27Overseer.refbNeedIndirect] or aiBrain[M27Overseer.refiModDistFromStartNearestThreat] >= math.min(aiBrain[M27AirOverseer.refiBomberDefenceModDistance], 150) or (aiBrain[M27Overseer.refiModDistFromStartNearestThreat] >= 70 and M27Utilities.IsTableEmpty(aiBrain[reftFirebaseUnitsByFirebaseRef]) == false)) and (aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryTML) == 0 or M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildTML]) == false) then
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering whether to build TML. Is table of existing TML action empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildTML]))) end
                            if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildTML]) == false then
                                iActionToAssign = refActionBuildTML
                                iMinEngiTechLevelWanted = 2
                                iMaxEngisWanted = 3
                                if bHaveLowMass then iMaxEngisWanted = 2 end
                                for iEntry, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildTML] do
                                    tExistingLocationsToPickFrom = {}
                                    tExistingLocationsToPickFrom[1] = tSubtable[refEngineerAssignmentActualLocation]
                                    break
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': Already have an action to build TML, will make sure we have enough engis assigned. iMaxEngisWanted='..iMaxEngisWanted) end
                            else
                                RecordPossibleTMLTargets(aiBrain, false)
                                if bDebugMessages == true then LOG(sFunctionRef..': Have recorded possible TML targets.  Is the table empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftoTMLTargetsOfInterest]))..'; size of targets='..table.getn(aiBrain[reftoTMLTargetsOfInterest])) end
                                if M27Utilities.IsTableEmpty(aiBrain[reftoTMLTargetsOfInterest]) == false and table.getn(aiBrain[reftoTMLTargetsOfInterest]) >= 2 then
                                    tExistingLocationsToPickFrom = {}
                                    tExistingLocationsToPickFrom[1] = GetTMLBuildLocation(aiBrain)
                                    if bDebugMessages == true then LOG(sFunctionRef..': TML build location in tExistingLocationsToPickFrom='..repru(tExistingLocationsToPickFrom)) end
                                    if M27Utilities.IsTableEmpty(tExistingLocationsToPickFrom[1]) == false then
                                        iActionToAssign = refActionBuildTML
                                        iMinEngiTechLevelWanted = 2
                                        iMaxEngisWanted = 3
                                        if bHaveLowMass then iMaxEngisWanted = 2 end
                                        if bDebugMessages == true then LOG(sFunctionRef..': Will try to build TML.  Available engineers='..repru(tiAvailableEngineersByTech)) end
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': Couldnt find a TML build location') end
                                    end
                                end
                            end

                        end
                    elseif iCurrentConditionToTry == 31 then --Higher priority air staging for if we have lots of air units wanting refueling
                        if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..': bHaveLowPower='..tostring(bHaveLowPower)..'; aiBrain[M27AirOverseer.refiAirStagingWanted]='..(aiBrain[M27AirOverseer.refiAirStagingWanted] or 'nil')) end
                        if bHaveLowPower == false and (aiBrain[M27AirOverseer.refiAirStagingWanted] or 0) >= 3 and aiBrain:GetCurrentUnits(refCategoryAirStaging) == 0 then
                            iActionToAssign = refActionBuildAirStaging
                            iSearchRangeForNearestEngi = 100
                            iMaxEngisWanted = 1
                            if not(bHaveLowMass) and not(bHaveLowPower) then iMaxEngisWanted = 2 end
                            if bDebugMessages == true then LOG(sFunctionRef..': Setting action to be build air staging, iMaxEngisWanted='..iMaxEngisWanted) end
                        end
                    elseif iCurrentConditionToTry == 32 then --Fortify firebase
                        --if tiAvailableEngineersByTech[3] > 0 then bDebugMessages = true end
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering if we want to fortify the firebase further. bHaveLowPower='..tostring(bHaveLowPower)..'; bHaveLowMass='..tostring(bHaveLowMass)..'; Gross mass income='..aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]..'; Mass stored='..aiBrain:GetEconomyStored('MASS')..'; nearest threat='..aiBrain[M27Overseer.refiModDistFromStartNearestThreat]) end
                        if not(bHaveLowPower) and (not(bHaveLowMass) or aiBrain:GetEconomyStored('MASS') > 0 or aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 12 or aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= 150) then
                            if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionFortifyFirebase]) == false then
                                iActionToAssign = refActionFortifyFirebase
                                iMinEngiTechLevelWanted = 2
                                iMaxEngisWanted = 4
                                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle then iMaxEngisWanted = 6 end
                                if bDebugMessages == true then LOG(sFunctionRef..': Already fortifying a firebase with ref='..aiBrain[refiFirebaseBeingFortified]..'; and position='..repru(aiBrain[reftFirebasePosition][aiBrain[refiFirebaseBeingFortified]])) end
                                if aiBrain[refiFirebaseBeingFortified] == aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef] then
                                    tExistingLocationsToPickFrom[1] = {aiBrain[M27MapInfo.reftChokepointBuildLocation][1], aiBrain[M27MapInfo.reftChokepointBuildLocation][2], aiBrain[M27MapInfo.reftChokepointBuildLocation][3]}
                                else
                                    if M27Utilities.DoesCategoryContainCategory(M27UnitInfo.refCategoryPD + M27UnitInfo.refCategoryTMD + M27UnitInfo.refCategoryFixedShield, GetCategoryToBuildFromAction(iActionToAssign, iMinEngiTechLevelWanted, aiBrain), false) then
                                        tExistingLocationsToPickFrom[1] = {aiBrain[reftFirebaseFrontPDPosition][aiBrain[refiFirebaseBeingFortified]][1], aiBrain[reftFirebaseFrontPDPosition][aiBrain[refiFirebaseBeingFortified]][2], aiBrain[reftFirebaseFrontPDPosition][aiBrain[refiFirebaseBeingFortified]][3]}
                                    else
                                        tExistingLocationsToPickFrom[1] = {aiBrain[reftFirebasePosition][aiBrain[refiFirebaseBeingFortified]][1], aiBrain[reftFirebasePosition][aiBrain[refiFirebaseBeingFortified]][2], aiBrain[reftFirebasePosition][aiBrain[refiFirebaseBeingFortified]][3]}
                                    end
                                end

                            else
                                local tPD = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT2PlusPD, false, false)
                                if bDebugMessages == true then LOG(sFunctionRef..': Not already building firebase so will see if want to. Is table of PD empty='..tostring(M27Utilities.IsTableEmpty(tPD))) end
                                if M27Utilities.IsTableEmpty(tPD) == false then
                                    local iPD = table.getn(tPD)
                                    if bDebugMessages == true then LOG(sFunctionRef..': iPD='..iPD..'; if >=3 then will consider fortifying firebase') end
                                    if iPD >= 3 then
                                        --Check if have any locations for firebases
                                        RefreshListOfFirebases(aiBrain)
                                        if bDebugMessages == true then LOG(sFunctionRef..': Is table of firebases wanting fortification empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftFirebasesWantingFortification]))) end
                                        if M27Utilities.IsTableEmpty(aiBrain[reftFirebasesWantingFortification]) == false then
                                            iActionToAssign = refActionFortifyFirebase
                                            iMinEngiTechLevelWanted = 2
                                            iMaxEngisWanted = 4
                                            if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle then iMaxEngisWanted = 6 end
                                            local iCurDist
                                            local iClosestDist = 10000
                                            tExistingLocationsToPickFrom = {}
                                            --Get closest firebase to our base in need of fortification
                                            local sLocationRef = reftFirebasePosition
                                            local iClosestFirebaseRef


                                            if bDebugMessages == true then LOG(sFunctionRef..': Is the table of firebases wanting fortification empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftFirebasesWantingFortification]))..'; available engineers='..repru(tiAvailableEngineersByTech)) end
                                            for iFirebase, bWantsFortifying in aiBrain[reftFirebasesWantingFortification] do
                                                --Temporarily set the firebase to be built as this one so the logic for getting the category to build works
                                                aiBrain[refiFirebaseBeingFortified] = iFirebase
                                                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle and aiBrain[M27MapInfo.refiAssignedChokepointFirebaseRef] == iFirebase then
                                                    iClosestFirebaseRef = iFirebase
                                                    tExistingLocationsToPickFrom[1] = {aiBrain[M27MapInfo.reftChokepointBuildLocation][1], aiBrain[M27MapInfo.reftChokepointBuildLocation][2], aiBrain[M27MapInfo.reftChokepointBuildLocation][3]}
                                                    break --want to fortify chokepoint in priority to anything else
                                                else
                                                    if M27Utilities.DoesCategoryContainCategory(M27UnitInfo.refCategoryPD + M27UnitInfo.refCategoryTMD + M27UnitInfo.refCategoryFixedShield, GetCategoryToBuildFromAction(iActionToAssign, iMinEngiTechLevelWanted, aiBrain), false) then sLocationRef = reftFirebaseFrontPDPosition else sLocationRef = reftFirebasePosition end


                                                    iCurDist = M27Utilities.GetDistanceBetweenPositions(aiBrain[sLocationRef][iFirebase], M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Considering iFirebase='..iFirebase..'; iCurDist='..iCurDist..'; iClosestDist pre this='..iClosestDist) end
                                                    if iCurDist < iClosestDist then
                                                        tExistingLocationsToPickFrom[1] = {aiBrain[sLocationRef][iFirebase][1], aiBrain[sLocationRef][iFirebase][2], aiBrain[sLocationRef][iFirebase][3]}
                                                        iClosestDist = iCurDist
                                                        iClosestFirebaseRef = iFirebase
                                                        if bDebugMessages == true then LOG(sFunctionRef..': Setting firebase to be fortified as '..iFirebase) end
                                                    end
                                                end
                                            end
                                            aiBrain[refiFirebaseBeingFortified] = iClosestFirebaseRef
                                        end
                                    end
                                end
                                if iActionToAssign then
                                    --Are we building T2Plus PD and have an available UEF engineer?
                                    if tiAvailableEngineersByTech[3] > 0 and M27Utilities.IsTableEmpty(EntityCategoryFilterDown(categories.TECH3 * categories.UEF, tIdleEngineers)) == false and aiBrain[refiFirebaseCategoryWanted][aiBrain[refiFirebaseBeingFortified]] == M27UnitInfo.refCategoryT2PlusPD then
                                        aiBrain[refiFirebaseCategoryWanted][aiBrain[refiFirebaseBeingFortified]] = M27UnitInfo.refCategoryT3PD
                                        iMinEngiTechLevelWanted = 3
                                    elseif not(M27Utilities.DoesCategoryContainCategory(categories.TECH1 + categories.TECH2, aiBrain[refiFirebaseCategoryWanted][aiBrain[refiFirebaseBeingFortified]], false)) then iMinEngiTechLevelWanted = 3
                                    end
                                end
                            end
                            if iActionToAssign and bHaveLowMass then iMaxEngisWanted = 2 end
                        end

                    elseif iCurrentConditionToTry == 33 then --T3 mexes in place of existing T2 mexes
                        if iHighestFactoryOrEngineerTechAvailable >= 3 then
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering if shoudl assign action to ctrlK mex. Is tMexesToCtrlK empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftMexesToCtrlK]))..'; Existing engi assignments='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildT3MexOverT2]))) end
                            if iT3Power == nil then iT3Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH3) end
                            if bDebugMessages == true then LOG(sFunctionRef..': iT3Power='..iT3Power..': T3 Engis='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * categories.TECH3)..'; T3 mex='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex)) end
                            if iT3Power > 0 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer * categories.TECH3) >= 1 then -- and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex) >= 1 then
                                --Do we have T1 mexes near base that are upgrading or available to upgrade? If so, then only want to get a T3 mex if we have high mass
                                local iT1MexesNearBase = 0
                                local tAllT1Mexes = aiBrain:GetListOfUnits(M27UnitInfo.refCategoryT1Mex, false, true)
                                local bProceedWithT3 = true
                                if M27Utilities.IsTableEmpty(tAllT1Mexes) == false then
                                    for iT1Mex, oT1Mex in tAllT1Mexes do
                                        if M27UnitInfo.IsUnitValid(oT1Mex) and M27Utilities.GetDistanceBetweenPositions(oT1Mex:GetPosition(), M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) <= 90 and M27Conditions.SafeToUpgradeUnit(oT1Mex) then
                                            iT1MexesNearBase = iT1MexesNearBase + 1
                                        end
                                    end
                                end
                                if iT1MexesNearBase > 0 then
                                    if bHaveLowMass then bProceedWithT3 = false
                                    elseif aiBrain:GetEconomyStoredRatio('MASS') < 0.1 or aiBrain:GetEconomyStored('MASS') < 1000 then
                                        bProceedWithT3 = false
                                    end
                                end

                                if bProceedWithT3 then
                                    local bRefreshMexes = M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildT3MexOverT2])
                                    if bRefreshMexes and M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftMexesToCtrlK]) == false then
                                        bRefreshMexes = false
                                        --Check all mexes are valid as we dont have an existing order to assist
                                        for iMex, oMex in aiBrain[M27EconomyOverseer.reftMexesToCtrlK] do
                                            if M27UnitInfo.IsUnitValid(oMex) == false then
                                                bRefreshMexes = true
                                                break
                                            end
                                        end
                                    end


                                    if bRefreshMexes then
                                        --Do we have any suitable mexes to add to this list? Check if we meet the conditions for shortlisting a mex
                                        --Do we have any T2 mexes near our base who arent upgrading? (Below will also update the variable for the nearest one of these, based on mexes which arent upgrading)
                                        if bDebugMessages == true then LOG(sFunctionRef..': T2 mexes near base pre refresh='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftT2MexesNearBase]))..'; Nearest T2mex is valid='..tostring((M27UnitInfo.IsUnitValid(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]) or false))) end
                                        --if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftT2MexesNearBase]) == true or not(M27UnitInfo.IsUnitValid(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase])) then
                                        --if bDebugMessages == true then LOG(sFunctionRef..': Will refresh T2 mexes near base') end
                                        M27EconomyOverseer.RefreshT2MexesNearBase(aiBrain)
                                        --end
                                        if bDebugMessages == true then LOG(sFunctionRef..': Is T2 mexes near base post any refresh empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftT2MexesNearBase]))..'; Nearest T2mex is valid='..tostring((M27UnitInfo.IsUnitValid(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]) or false))) end

                                        if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftT2MexesNearBase]) == false and M27UnitInfo.IsUnitValid(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]) then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Have a valid t2 mex near our base, Safe To upgrade='..tostring(M27Conditions.SafeToUpgradeUnit(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]))) end
                                            --Is the nearest mex to our base within defence coverage, with no nearby threats?
                                            if M27Conditions.SafeToUpgradeUnit(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]) then
                                                if bDebugMessages == true then LOG(sFunctionRef..': will add the mex '..aiBrain[M27EconomyOverseer.refoNearestT2MexToBase].UnitId..M27UnitInfo.GetUnitLifetimeCount(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase])..' to the list of mexes to ctrlk') end
                                                table.insert(aiBrain[M27EconomyOverseer.reftMexesToCtrlK], aiBrain[M27EconomyOverseer.refoNearestT2MexToBase])
                                            end
                                        end
                                    elseif bDebugMessages == true then LOG(sFunctionRef..': Not refreshing list of mexes')
                                    end
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef..': After potential refresh, reftT2MexesNearBase size='..table.getn(aiBrain[M27EconomyOverseer.reftT2MexesNearBase])..'; MexesToCtrlK size='..table.getn(aiBrain[M27EconomyOverseer.reftMexesToCtrlK]))
                                        if M27UnitInfo.IsUnitValid(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]) then LOG('Mex nearest base position='..repru(aiBrain[M27EconomyOverseer.refoNearestT2MexToBase]:GetPosition()))
                                        else LOG(' refoNearestT2MexToBase is no longer valid')
                                        end
                                    end

                                    if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftMexesToCtrlK]) == false or M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildT3MexOverT2]) == false then
                                        iActionToAssign = refActionBuildT3MexOverT2
                                        iMaxEngisWanted = 10
                                        tExistingLocationsToPickFrom = {}
                                        iSearchRangeForNearestEngi = 125
                                        iMinEngiTechLevelWanted = 3
                                        if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildT3MexOverT2]) == false then
                                            if bDebugMessages == true then LOG(sFunctionRef..': Already have an engineer assigned to build t3 mex so will just assist that engi') end
                                            tExistingLocationsToPickFrom = nil
                                        else
                                            --Dont already have this assigned so get a new location
                                            for iMex, oMex in aiBrain[M27EconomyOverseer.reftMexesToCtrlK] do
                                                if oMex.GetPosition then table.insert(tExistingLocationsToPickFrom, oMex:GetPosition()) end
                                            end
                                            if bDebugMessages == true then LOG(sFunctionRef..': Dont have engi assigned to build T3 yet, so will pick location from mexes to ctrlK table; size of table='..table.getn(aiBrain[M27EconomyOverseer.reftMexesToCtrlK])..'; size of ctrlk table='..table.getn(aiBrain[M27EconomyOverseer.reftMexesToCtrlK])..'; tExistingLocationsToPickFrom='..repru(tExistingLocationsToPickFrom)) end
                                            if M27Utilities.IsTableEmpty(tExistingLocationsToPickFrom) == true then M27Utilities.ErrorHandler('Couldnt find any mex locations for ctrlk') end
                                        end
                                    elseif bDebugMessages == true then LOG(sFunctionRef..': Dont have existing order to build T3 mex over T2, and no mexes that we think we should')
                                    end
                                elseif bDebugMessages == true then LOG(sFunctionRef..': Have t1 mexes to upgrade near our base and have decent amount of mass')
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 34 then --Make sure we have at least 2 T3 land factories if we have significant mass and want more engineers
                        if iEngineersWantedPreReset >= 5 and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 15 and aiBrain[M27EconomyOverseer.refiMassNetBaseIncome] > 0 and aiBrain:GetEconomyStoredRatio('MASS') >= 0.25 and not(bHaveVeryLowPower) and aiBrain[M27Overseer.refiOurHighestLandFactoryTech] == 3 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryLandFactory * categories.TECH3) == 1 then
                            iActionToAssign = refActionBuildLandFactory
                            iMinEngiTechLevelWanted = 3
                            iMaxEngisWanted = 5
                        end
                    elseif iCurrentConditionToTry == 35 then --Queue up an experimental if we have significant mass as it may take time to find the right position
                        if iMassStored == nil then iMassStored = aiBrain:GetEconomyStored('MASS') end
                        if not(bHaveLowPower) and not(bHaveLowMass) and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 7 and iMassStored >= 1000 and (aiBrain[M27EconomyOverseer.refiMassNetBaseIncome] > 1 or aiBrain:GetEconomyStoredRatio('MASS') >= 0.3) and iHighestFactoryOrEngineerTechAvailable >= 3 and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 7 then
                            --Have the resources to build an experimental - is it safe to do so?
                            if SafeToBuildExperimental(aiBrain) then
                                iActionToAssign = refActionBuildExperimental
                                iSearchRangeForNearestEngi = 60 --Dont want too far away as if in high mass scenario could end up overflowing by the time the engi arrives
                                iMaxEngisWanted = 1
                                if aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 10 and iMassStored >= 2000 then iMaxEngisWanted = math.max(2, math.floor(aiBrain[M27EconomyOverseer.refiMassNetBaseIncome]), math.ceil(iMassStored / 2000)) end
                                if aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.99 or aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] <= 50 then iMaxEngisWanted = 1 end
                                iMinEngiTechLevelWanted = 3
                            end
                        end
                    elseif iCurrentConditionToTry == 36 then --Build factories (or upgrade HQ) if getting too much mass
                        if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..'; bHaveVeryLowPower='..tostring(bHaveVeryLowPower)) end
                        if bHaveVeryLowPower == false and bHaveLowMass == false then
                            if iLandFactories == nil then
                                iLandFactories = aiBrain:GetCurrentUnits(refCategoryLandFactory)
                                if iLandFactories == nil then iLandFactories = 0 end
                            end

                            if iMassStored == nil then iMassStored = aiBrain:GetEconomyStored('MASS') end
                            if iEnergyStored == nil then iEnergyStored = aiBrain:GetEconomyStored('ENERGY') end
                            if bDebugMessages == true then LOG(sFunctionRef..': Considering buildilng land or air facs, iMassStored='..iMassStored..'; iEnergyStored='..iEnergyStored..'; iLandFactories='..iLandFactories) end
                            if iMassStored > 100 and iEnergyStored > 250 then
                                if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftActiveHQUpgrades]) == false then
                                    --Double check al lthe units are still valid (as may be a slight delay)
                                    local bStillValid = false
                                    for iHQ, oHQ in aiBrain[M27EconomyOverseer.reftActiveHQUpgrades] do
                                        if M27UnitInfo.IsUnitValid(oHQ) then
                                            bStillValid = true
                                            break
                                        end
                                    end
                                    if not(bStillValid) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Clearing all of the active HQ upgrades') end
                                        aiBrain[M27EconomyOverseer.reftActiveHQUpgrades] = {}
                                    else
                                        iActionToAssign = refActionUpgradeHQ
                                    end
                                end
                                if not(iActionToAssign) then
                                    if bDebugMessages == true then LOG(sFunctionRef..': Not trying to upgrade to HQ, will consider if want more land or air facs as dont have very low mass or energy; aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes]='..aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes]..'; iLandFactories='..iLandFactories..'; iAirFactories='..aiBrain:GetCurrentUnits(refCategoryAirFactory)..'; bHaveLowPower='..tostring(bHaveLowPower)..'; aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir]='..aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir]..'; aiBrain[M27EconomyOverseer.refbWantMoreFactories]='..tostring(aiBrain[M27EconomyOverseer.refbWantMoreFactories])) end
                                    --Not trying to upgrade a factory to HQ; do we have the min number of land factories wanted before we get an air fac?
                                    if iLandFactories < aiBrain[M27Overseer.refiMinLandFactoryBeforeOtherTypes] then
                                        iActionToAssign = refActionBuildLandFactory
                                    else
                                        --Have min. number of land facs wanted, so now consider if we want more air facs
                                        if iAirFactories == nil then
                                            iAirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory)
                                            if iAirFactories == nil then iAirFactories = 0 end
                                        end
                                        if bDebugMessages == true then LOG(sFunctionRef..': iAirFactories='..iAirFactories..'; iEnergyStored='..iEnergyStored..'; iNetCurEnergyIncome='..iNetCurEnergyIncome) end
                                        if iAirFactories == 0 then
                                            iActionToAssign = refActionBuildAirFactory
                                        else
                                            --Already have 1 air fac, only get more if we both have power, and we have fewer than the ratio of max factories wanted
                                            if not(bHaveLowPower) then
                                                local bTooFewAirFacs = false
                                                if aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir] > iAirFactories then
                                                    if not(aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons]) then bTooFewAirFacs = true
                                                    else
                                                        --Are making use of land units, check ratio of land fac vs air fac
                                                        if iLandFactories / math.max(1,aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand]) >= iAirFactories / math.max(1, aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir]) then
                                                            bTooFewAirFacs = true
                                                        end
                                                    end
                                                end
                                                if bTooFewAirFacs then iActionToAssign = refActionBuildAirFactory end
                                            end
                                        end
                                    end
                                    if not(iActionToAssign) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Not building air factory; consider if we want to build more land factories; aiBrain[M27EconomyOverseer.refbWantMoreFactories]='..tostring(aiBrain[M27EconomyOverseer.refbWantMoreFactories])) end
                                        if not(iActionToAssign) then
                                            --Dont want to build any more air facs, or upgrade a HQ, and have the min. level of land facs; build another tank if we are making use of tanks and dont ahve the max number
                                            if not(aiBrain[M27PlatoonFormer.refbUsingTanksForPlatoons]) and iLandFactories < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] then
                                                iActionToAssign = refActionBuildLandFactory
                                            end
                                        end
                                    end
                                end
                                if not(iActionToAssign) then
                                    --Dont want to build any factories, so upgrade a mex if we are upgrading any
                                    if aiBrain[M27EconomyOverseer.refiMexesUpgrading] > 0 then
                                        iActionToAssign = refActionUpgradeBuilding
                                    end
                                end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': Action after checking if want to build a factory, upgrade HQ, or upgrade a mex='..(iActionToAssign or 'nil')) end
                        if iActionToAssign then
                            iSearchRangeForNearestEngi = 75
                            iMaxEngisWanted = math.min(math.floor(iMassStored / 100), math.floor(iEnergyStored / 250), 5)
                            --Increase engineers if we are about to overflow
                            if bHaveLowPower == false and bHaveLowMass == false then
                                if iMassStoredRatio == nil then iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS') end
                                if iMassStored == nil then iMassStored = aiBrain:GetEconomyStored('MASS') end
                                if iNetCurEnergyIncome > 0.2 and (iMassStoredRatio > 0.6 or (iMassStoredRatio > 0.4 and iMassStored > 3500)) then --Have too much mass stored so try to build something
                                    iMaxEngisWanted = iMaxEngisWanted + 5
                                end
                            end

                        end
                    elseif iCurrentConditionToTry == 37 then --Air staging if we need one for low fuel air units
                        if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..': bHaveLowPower='..tostring(bHaveLowPower)..'; aiBrain[M27AirOverseer.refiAirStagingWanted]='..(aiBrain[M27AirOverseer.refiAirStagingWanted] or 'nil')) end
                        if bHaveLowPower == false and aiBrain[M27AirOverseer.refiAirStagingWanted] and aiBrain[M27AirOverseer.refiAirStagingWanted] > 0 then
                            local iCurAirStaging = aiBrain:GetCurrentUnits(refCategoryAirStaging)
                            if bDebugMessages == true then LOG(sFunctionRef..': iCurAirStaging='..iCurAirStaging..'; M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryAllAir, (1+iCurAirStaging)*5)='..tostring(M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryAllAir, (1+iCurAirStaging)*5))..'; (1+iCurAirStaging)*5='..(1+iCurAirStaging)*5) end
                            if (not(bHaveLowMass) or aiBrain[M27Overseer.refiOurHighestAirFactoryTech] == 3) and aiBrain[M27AirOverseer.refiAirStagingWanted] > iCurAirStaging and iCurAirStaging < 5 and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] > iCurAirStaging * 5 and not(M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryAllAir, (1+iCurAirStaging)*5)) then
                                if bDebugMessages == true then LOG(sFunctionRef..': Dont have enough air staging so will build more') end
                                iActionToAssign = refActionBuildAirStaging
                                iSearchRangeForNearestEngi = 100
                                if iCurAirStaging < 3 then iMaxEngisWanted = 2
                                else iMaxEngisWanted = 1
                                end
                            end
                        end
                        --end
                    elseif iCurrentConditionToTry == 38 then --Energy storage once have certain level of power
                        if bHaveLowPower == false then
                            if iGrossCurEnergyIncome >= 28 then
                                if iEnergyStoredRatio == nil then iEnergyStoredRatio = aiBrain:GetEconomyStoredRatio('ENERGY') end
                                if iEnergyStoredRatio > 0 then
                                    if iEnergyStorageMax == nil then iEnergyStorageMax = iEnergyStored / iEnergyStoredRatio end
                                    local iMaxStorageWanted = 9000
                                    if not(M27Utilities.IsACU(M27Utilities.GetACU(aiBrain))) then
                                        if iGrossCurEnergyIncome >= 90 or (iGrossCurEnergyIncome >= 40 and aiBrain[M27Overseer.refiEnemyHighestTechLevel] >= 2) then
                                            if iGrossCurEnergyIncome >= 200 or (aiBrain[M27Overseer.refiEnemyHighestTechLevel] >= 3 and iGrossCurEnergyIncome >= 100) then
                                                iMaxStorageWanted = math.max(17000, aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] * 200) --Energy storage to replenish overcharge every 20s
                                            else
                                                iMaxStorageWanted = 13000
                                            end
                                        end
                                        iMaxStorageWanted = math.min(65000, iMaxStorageWanted) --need 60k energy to deal max of 15k, but only a % of current energy (90%?) is used; when sandboxing, dealt max 15k damage at 68.5k storage, and c.800 below max at 63.5k storage
                                    else
                                        --Dont have an ACU so only want energy to manage powerstalls
                                        iMaxStorageWanted = math.min(30000, math.max(5000, iGrossCurEnergyIncome * 40))
                                    end

                                    if iEnergyStorageMax < iMaxStorageWanted then
                                        iActionToAssign = refActionBuildEnergyStorage
                                        if iEnergyStorageMax < 9000 then
                                            iSearchRangeForNearestEngi = 100
                                            iMaxEngisWanted = 3
                                        else
                                            iSearchRangeForNearestEngi = 75
                                            iMaxEngisWanted = 2
                                        end
                                    end
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 39 then --Get reclaim
                        bThresholdPreReclaimEngineerCondition = true

                        if iMassStoredRatio == nil then iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS') end
                        if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..'; iMassStoredRatio='..iMassStoredRatio..'; M27MapInfo.iMapTotalMass='..(M27MapInfo.iMapTotalMass or 'nil')..'; aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1]='..(aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] or 'nil')) end
                        if iMassStoredRatio < 0.98 then
                            if aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] > 0 then
                                --Have some reclaim somewhere on map, so have at least 1 engineer assigned to reclaim even if no high priority locations
                                iActionToAssign = refActionReclaimArea
                                --M27MapInfo.UpdateReclaimMarkers() --Does periodically if been a while since last update --Moved this to overseer so dont end up with engis waiting for this to compelte
                                iMaxEngisWanted = math.max(1, math.ceil((aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] or 0)/3))
                                if iMaxEngisWanted > 5 then iMaxEngisWanted = 5 end
                                iSearchRangeForNearestEngi = 10000
                            end
                        end
                    elseif iCurrentConditionToTry == 40 then
                        if M27Utilities.IsTableEmpty(aiBrain[M27EconomyOverseer.reftUnitsToReclaim]) == false and (iMassStoredRatio < 0.2 or (iMassStoredRatio < 0.5 and aiBrain[M27EconomyOverseer.refiMassNetBaseIncome] < 0)) then
                            iActionToAssign = refActionReclaimUnit
                            iMaxEngisWanted = math.min(4, table.getn(aiBrain[M27EconomyOverseer.reftUnitsToReclaim]))
                            iSearchRangeForNearestEngi = 200
                        end
                    elseif iCurrentConditionToTry == 41 then --Try to get nearest unclaimed mex (i.e. this will only run if are no mexes within defensive area or our side of map):
                        if iAllUnclaimedMexesInPathingGroup == nil then
                            tAllUnclaimedMexesInPathingGroup = GetUnclaimedMexes(aiBrain, sPathing, iPathingGroup, false, false, false)
                            if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInPathingGroup) == false then iAllUnclaimedMexesInPathingGroup = table.getn(tAllUnclaimedMexesInPathingGroup)
                            else iAllUnclaimedMexesInPathingGroup = 0 end
                        end
                        if iAllUnclaimedMexesInPathingGroup > 0 then
                            iActionToAssign = refActionBuildMex
                            iSearchRangeForNearestEngi = 10000
                            iMaxEngisWanted = math.ceil(iAllUnclaimedMexesInPathingGroup / 2)

                            if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] and iMaxEngisWanted > 3 then iMaxEngisWanted = 3 end
                            tExistingLocationsToPickFrom = tAllUnclaimedMexesInPathingGroup
                        end
                    elseif iCurrentConditionToTry == 42 then --2nd T1 power construction with low priority engineers
                        if bHaveVeryLowPower == false and bHaveLowMass == false then --If almost power stalling then want to focus on the first T1 power rather than trying multiple at once
                            if bDebugMessages == true then LOG(sFunctionRef..': Separate power action; bWantMorePower='..tostring(bWantMorePower)) end
                            if iT3Power == nil then iT3Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH3) end
                            if iT2Power == nil then iT2Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH2) end
                            if bWantMorePower == true then
                                if iHighestFactoryOrEngineerTechAvailable == 1 or (iHighestFactoryOrEngineerTechAvailable == 2 and iT2Power >= 2) then
                                    iActionToAssign = refActionBuildSecondPower
                                    iSearchRangeForNearestEngi = 100
                                    iMaxEngisWanted = 4
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': Will build pogen') end
                                    iActionToAssign = refActionBuildPower
                                    iSearchRangeForNearestEngi = 100
                                    iMaxEngisWanted = 8
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 43 then --Radar near base
                        if bHaveLowPower == false then
                            if iCurRadarCount == nil then iCurRadarCount = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryRadar) end
                            if iCurRadarCount == 0 and iNetCurEnergyIncome > 5 and iEnergyStored >= 2000 then
                                iActionToAssign = refActionBuildT1Radar
                                iMaxEngisWanted = 1
                            elseif bHaveLowMass == false then

                                --Already have a radar, check if we or an ally has T3
                                if iNearbyOmniCount == nil then
                                    local tNearbyOmni = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT3Radar, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 250, 'Ally')
                                    if M27Utilities.IsTableEmpty(tNearbyOmni) == false then iNearbyOmniCount = table.getn(tNearbyOmni)
                                    else iNearbyOmniCount = 0 end
                                end
                                if iNearbyOmniCount == 0 then
                                    local iOmniWanted = 0
                                    --GetResourcesNearTargetLocation(tTargetPos, iMaxDistance, bMexNotHydro)
                                    if iT3Power == nil then iT3Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH3) end
                                    --Only get omni if we have several T3 power, and we have no nearby enemies (within 175, as T2 radar is 200 range; also not much point if enemy start is within 250 of us)
                                    if iHighestFactoryOrEngineerTechAvailable >= 3 and iNetCurEnergyIncome >= 300 and iT3Power > 1 and aiBrain[M27Overseer.refiModDistFromStartNearestThreat] >= 175 and aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] >= 250 then
                                        --Also want at least 2 T3 mexes (or 4 if we're in eco mode), assuming we have that many near our start position
                                        local iT3MexesWantedFirst = M27MapInfo.GetResourcesNearTargetLocation(M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], 40, true)
                                        if M27Utilities.IsTableEmpty(iT3MexesWantedFirst) == true then iT3MexesWantedFirst = 1 else iT3MexesWantedFirst = table.getn(iT3MexesWantedFirst) end

                                        if (aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyEcoAndTech or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle) then iT3MexesWantedFirst = math.min(4, iT3MexesWantedFirst)
                                        else iT3MexesWantedFirst = math.min(2, iT3MexesWantedFirst) end
                                        if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT3Mex) >= iT3MexesWantedFirst then
                                            iOmniWanted = 1
                                        end
                                    end
                                    if iOmniWanted > 0 and (GetGameTimeSeconds() >= 1200 or aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 10 or aiBrain:GetEconomyStored('MASS') >= 2500) then
                                        iActionToAssign = refActionBuildT3Radar
                                        iMinEngiTechLevelWanted = 3
                                        iMaxEngisWanted = 3
                                    else
                                        if iT2Power == nil then iT2Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH2) end
                                        if iT2Power + iT3Power > 0 then
                                            --Do we already have T2 radar
                                            if iCurT2RadarCount == nil then iCurT2RadarCount = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Radar) end
                                            if iCurT2RadarCount == 0 and iNetCurEnergyIncome >= 40 then
                                                iActionToAssign = refActionBuildT2Radar
                                                iMinEngiTechLevelWanted = 2
                                                iMaxEngisWanted = 3
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 44 then --Shields
                        if bHaveLowPower == false and (bHaveLowMass == false or aiBrain[M27Overseer.refbDefendAgainstArti]) and (iHighestFactoryOrEngineerTechAvailable >= 3 or (not(aiBrain[M27Overseer.refbDefendAgainstArti]) and not(aiBrain[refbHaveUnitsWantingHeavyShield]) and iHighestFactoryOrEngineerTechAvailable >= 2)) and M27Utilities.IsTableEmpty(aiBrain[reftUnitsWantingFixedShield]) == false then
                            --Refresh table of units wanting a shield to make sure its correct
                            RefreshUnitsWantingFixedShields(aiBrain)
                            if M27Utilities.IsTableEmpty(aiBrain[reftUnitsWantingFixedShield]) == false then
                                iActionToAssign = refActionBuildShield
                                iMaxEngisWanted = 3
                                if aiBrain[M27Overseer.refbDefendAgainstArti] and bHaveLowMass == false then iMaxEngisWanted = 8 end
                                iSearchRangeForNearestEngi = 150
                                if aiBrain[M27Overseer.refbDefendAgainstArti] or aiBrain[refbHaveUnitsWantingHeavyShield] then
                                    iMinEngiTechLevelWanted = 3
                                else
                                    iMinEngiTechLevelWanted = 2
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 45 then --reclaim on enemy side of map
                        if iMassStoredRatio <= 0.25 and aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] + aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][2] + aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][3] > 0 then
                            iActionToAssign = refActionReclaimArea
                            iMaxEngisWanted = math.min(15, math.max(1, math.min(math.ceil(aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] * 0.5 + aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][2] * 0.3 + aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][3] * 0.1))))
                            iSearchRangeForNearestEngi = 10000
                        end
                    elseif iCurrentConditionToTry == 46 then --Assist air
                        if bHaveLowPower == false and aiBrain:GetEconomyStoredRatio('Energy') >= 0.99 and aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] >= 15 then
                            if iAirFactories == nil then
                                iAirFactories = aiBrain:GetCurrentUnits(refCategoryAirFactory)
                                if iAirFactories == nil then iAirFactories = 0 end
                            end

                            if iAirFactories > 0 and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance or (iAirFactories >= 1 and iAirFactories < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir]) then
                                iActionToAssign = refActionAssistAirFactory
                                if bHaveLowMass == false then iMaxEngisWanted = 10
                                else iMaxEngisWanted = 5 end
                                --Reduce engineers based on power; T3 engi will require between 135 and 450 net energy income; however if we had already assigned engineers then want to take that into account
                                iExistingEngineersAssigned = 0
                                if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistAirFactory]) == false then
                                    for iEngi, oEngi in aiBrain[reftEngineerAssignmentsByActionRef][refActionAssistAirFactory] do
                                        iExistingEngineersAssigned = iExistingEngineersAssigned + 1
                                    end
                                end

                                iMaxEngisWanted = math.min(iMaxEngisWanted, math.ceil(aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] / (15 * iHighestFactoryOrEngineerTechAvailable) + iExistingEngineersAssigned))
                                iSearchRangeForNearestEngi = 75
                            end
                        end
                    elseif iCurrentConditionToTry == 47 then --Sonar
                        if bDebugMessages == true then LOG(sFunctionRef..': Checking if we want sonar, aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand]='..tostring(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand])..'; aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]='..tostring(aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious])..'; M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryTorpBomber, 1)='..tostring(M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryTorpBomber, 1))) end
                        local iTorpThreshold = 5
                        if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == false and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] then iTorpThreshold = 1 end
                        --Want sonar if we have built at least 1 torp bomber, or if we have a naval factory, or if we have a T3 air factory (broader range of conditions to help reduce risk of unit restrictions interfering)
                        if (M27MapInfo.bMapHasWater or aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == false and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious]) and not(M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryTorpBomber, iTorpThreshold)) or (aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] == false and aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithAmphibious] and aiBrain[M27Overseer.refiOurHighestAirFactoryTech] >= 3) or aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryNavalFactory) >= 1  then
                            --Can get to enemy via amphib not land so must be a water map, so want sonar to detect subs if we dont already have it
                            if bDebugMessages == true then LOG(sFunctionRef..': aiBrain:GetCurrentUnits(M27UnitInfo.refCategorySonar)='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategorySonar)) end
                            if aiBrain:GetCurrentUnits(M27UnitInfo.refCategorySonar) == 0 then
                                iActionToAssign = refActionBuildT1Sonar
                                iMinEngiTechLevelWanted = 1
                            else
                                if bDebugMessages == true then LOG(sFunctionRef..': aiBrain[M27Overseer.refiOurHighestAirFactoryTech]='..aiBrain[M27Overseer.refiOurHighestAirFactoryTech]..'; aiBrain[M27AirOverseer.refiAirAANeeded]='..aiBrain[M27AirOverseer.refiAirAANeeded]..'; aiBrain[M27AirOverseer.refiTorpBombersWanted]='..aiBrain[M27AirOverseer.refiTorpBombersWanted]..'; aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT1Sonar)='..aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT1Sonar)) end
                                if aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT2Sonar) == 0 and aiBrain[M27Overseer.refiOurHighestAirFactoryTech] >= 3 and aiBrain[M27AirOverseer.refiAirAANeeded] <= 0 and aiBrain[M27AirOverseer.refiTorpBombersWanted] <= 0 and aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryT1Sonar) > 0 then
                                    iActionToAssign = refActionBuildT2Sonar
                                    iMinEngiTechLevelWanted = 2
                                end
                            end
                            if iActionToAssign then
                                iMaxEngisWanted = 1
                                iSearchRangeForNearestEngi = 1000
                                if bDebugMessages == true then LOG(sFunctionRef..': Will build sonar, action='..iActionToAssign) end
                            end
                        end
                    elseif iCurrentConditionToTry == 48 then --More reclaim (lower priority locations)
                        if iMassStoredRatio == nil then iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS') end
                        if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..'; iMassStoredRatio='..iMassStoredRatio..'; M27MapInfo.iMapTotalMass='..M27MapInfo.iMapTotalMass..'; aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1]='..aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1]) end
                        if iMassStoredRatio < 0.98 then
                            if aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] + aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][2] + aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][3] > 0 then
                                --Have some reclaim somewhere on map, so have at least 1 engineer assigned to reclaim even if no high priority locations
                                iActionToAssign = refActionReclaimArea
                                --M27MapInfo.UpdateReclaimMarkers() --Does periodically if been a while since last update --Moved this to overseer so dont end up with engis waiting for this to compelte
                                iMaxEngisWanted = math.max(1, math.ceil(((aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][1] or 0) + (aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][2] or 0) + (aiBrain[M27MapInfo.refiTotalReclaimAreasOfInterestByPriority][3] or 0))/3))
                                if iMaxEngisWanted > 20 then iMaxEngisWanted = 20 end
                                iSearchRangeForNearestEngi = 10000
                                if bDebugMessages == true then LOG(sFunctionRef..': Reclaim: iMaxEngisWanted='..iMaxEngisWanted) end
                            end
                        end
                    elseif iCurrentConditionToTry == 49 then --Experimental if have loads of mass or satisfy other tests; one of these will be if we ahve already started on an experimental
                        if bDebugMessages == true then LOG(sFunctionRef..': Will consider building experimental if lots of mass or other tests. iHighestFactoryOrEngineerTechAvailable='..iHighestFactoryOrEngineerTechAvailable..';  Mass stored='..aiBrain:GetEconomyStored('MASS')..'; aiBrain[M27Overseer.refiAIBrainCurrentStrategy]='..aiBrain[M27Overseer.refiAIBrainCurrentStrategy]..'; Mass%='..aiBrain:GetEconomyStoredRatio('MASS')..'; aiBrain[M27EconomyOverseer.refiMassNetBaseIncome]='..aiBrain[M27EconomyOverseer.refiMassNetBaseIncome]..'; bHaveLowPower='..tostring(bHaveLowPower)..'; aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]='..aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]..'; aiBrain[M27Overseer.refiModDistFromStartNearestThreat]='..aiBrain[M27Overseer.refiModDistFromStartNearestThreat]..'; aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]*0.35='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase]*0.35..'; T3 lifetime buildcount='..M27Conditions.GetLifetimeBuildCount(aiBrain, M27UnitInfo.refCategoryLandCombat * categories.TECH3)..'; aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.3='..aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.3..'; Do we already have an active action to build an experimental='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildExperimental]))..'; Is it safe to build an experimental='..tostring(SafeToBuildExperimental(aiBrain))) end
                        if iHighestFactoryOrEngineerTechAvailable >= 3 then --at least 250 gross income ignoring reclaim
                            if aiBrain:GetEconomyStored('MASS') >= 10000 or ((aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyLandMain or aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyTurtle) and aiBrain:GetEconomyStored('MASS') >= 8000) or (aiBrain:GetEconomyStoredRatio('MASS') >= 0.5 and aiBrain:GetEconomyStored('MASS') >= 4000 and aiBrain[M27EconomyOverseer.refiMassNetBaseIncome] >= 1 and bHaveLowPower == false and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 7) then
                                iActionToAssign = refActionBuildExperimental
                            elseif not(bHaveLowPower) then
                                if aiBrain[M27Overseer.refiPercentageOutstandingThreat] >= 0.45 and aiBrain[M27Overseer.refiModDistFromStartNearestThreat] <= math.max(math.min(200, aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.5), aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.35) then
                                    iActionToAssign = refActionBuildExperimental
                                elseif not(bHaveLowPower) and aiBrain[M27Overseer.refiModDistFromStartNearestThreat] >= aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.35 and M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryLandCombat * categories.TECH3, 50) == false then
                                    iActionToAssign = refActionBuildExperimental
                                elseif not(bHaveLowPower) and not(bHaveLowMass) and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildExperimental]) == false and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 12 then
                                    iActionToAssign = refActionBuildExperimental
                                else
                                    --Consider experimental anyway if enemy has lots of T2 arti and PD and no very nearby enemy units, or if have already started construction
                                    if aiBrain[M27Overseer.refiModDistFromStartNearestThreat] >= aiBrain[M27Overseer.refiDistanceToNearestEnemyBase] * 0.3 then
                                        local tEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryFixedT2Arti, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.refiDistanceToNearestEnemyBase], 'Enemy')
                                        if M27Utilities.IsTableEmpty(tEnemyUnits) == false and table.getn(tEnemyUnits) >= 3 then
                                            --Do they have at least 6k threat in T2+ PD?
                                            tEnemyUnits = aiBrain:GetUnitsAroundPoint(M27UnitInfo.refCategoryT2PlusPD, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber], aiBrain[M27Overseer.refiDistanceToNearestEnemyBase], 'Enemy')
                                            if M27Utilities.IsTableEmpty(tEnemyUnits) == false and M27Logic.GetCombatThreatRating(aiBrain, tEnemyUnits, true, nil, nil, nil, nil) >= 8000 then
                                                iActionToAssign = refActionBuildExperimental
                                            end
                                        end
                                    end
                                end
                            end
                            if not(iActionToAssign) and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildExperimental]) == false and SafeToBuildExperimental(aiBrain) then
                                iActionToAssign = refActionBuildExperimental
                            end

                            if bDebugMessages == true then LOG(sFunctionRef..': iActionToAssign after considering if want to build experimental='..(iActionToAssign or 'nil')) end

                            if iActionToAssign == refActionBuildExperimental then
                                iSearchRangeForNearestEngi = 60
                                iMinEngiTechLevelWanted = 3

                                if bHaveLowPower and aiBrain:GetEconomyStoredRatio('Energy') < 0.8 then iMaxEngisWanted = 1
                                elseif aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] <= 500 then
                                    --If building land experi then would expect it to need c.20 energy per tick to support a T3 engi
                                    iMaxEngisWanted = math.max(1, math.floor(aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] / 10), math.floor(aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] / 50))
                                else
                                    --Building an experimental - a T3 engineer building e.g. a fatboy uses 17.6 mass/s; A monkeylord is 21.8; Ythotha 16.96; Also dont want 100% of mass to be going on experimental.  Therefore for every 25 gross mass income over 40, want an engineer assigned; also want a minimum of 5 engis as otherwise will take way too long to build the experimental
                                    if bHaveLowPower then iMaxEngisWanted = 3
                                    else
                                        iMaxEngisWanted = math.min(35, math.max(5, math.ceil((aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] - 4) / 2 + aiBrain:GetEconomyStored('MASS') / 800)))
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': Will build an experimental. iMaxEngisWanted='..iMaxEngisWanted..'; aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome]='..aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome]..'; aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]='..aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome]..'; Gross mass income='..aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome]..'; Mass stored='..aiBrain:GetEconomyStored('MASS')..'; bHaveLowPower='..tostring(bHaveLowPower)) end
                            end
                        end

                        --SPARE ACTIONS BELOW
                    elseif iCurrentConditionToTry == 50 then
                        if bHaveVeryLowPower == false and bHaveLowMass == false then
                            if bWantMorePower then
                                if iHighestFactoryOrEngineerTechAvailable == 1 then
                                    iActionToAssign = refActionBuildSecondPower
                                    iSearchRangeForNearestEngi = 100
                                    iMaxEngisWanted = 8
                                else
                                    if iT3Power == nil then iT3Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH3) end
                                    if iT2Power == nil then iT2Power = aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryPower * categories.TECH2) end

                                    --If at T2 or T3, only build second power if it is taking a while to build, or if we have high gross power
                                    local bBeenAWhile = false
                                    if GetGameTimeSeconds() - (aiBrain[refiTimeOfLastAction][refActionBuildPower] or -1000) >= 15 then
                                        bBeenAWhile = true
                                        --Check the primary engineer for this action doesnt have a building status
                                        if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildPower]) == false then
                                            for iEngiRef, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildPower] do
                                                if tSubtable[refEngineerAssignmentEngineerRef] then
                                                    if tSubtable[refEngineerAssignmentEngineerRef]:IsUnitState('Building') or tSubtable[refEngineerAssignmentEngineerRef]:IsUnitState('Repairing') then
                                                        bBeenAWhile = false
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                    end

                                    if bBeenAWhile and (aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 16 and ((aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] >= 3 and iT3Power >= 2) or (aiBrain[M27Overseer.refiOurHighestFactoryTechLevel] == 2 and iT2Power >=2))) then
                                        if bDebugMessages == true then LOG(sFunctionRef..': Will build 2nd pogen') end
                                        iActionToAssign = refActionBuildSecondPower
                                        iMaxEngisWanted = 5
                                        iMinEngiTechLevelWanted = iHighestFactoryOrEngineerTechAvailable
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..': Will build pogen') end
                                        iActionToAssign = refActionBuildPower
                                        iMaxEngisWanted = 15
                                    end
                                    iSearchRangeForNearestEngi = 100
                                end
                            end
                        end

                    elseif iCurrentConditionToTry == 51 then
                        if bHaveLowMass == false and bHaveLowPower == false then
                            if iMassStoredRatio == nil then iMassStoredRatio = aiBrain:GetEconomyStoredRatio('MASS') end
                            if iMassStored == nil then iMassStored = aiBrain:GetEconomyStored('MASS') end
                            if iMassStored > 800 and iMassStoredRatio >= 0.5 and (aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] < 750 or bWantMorePower) then --7.5k net energy income
                                iActionToAssign = refActionBuildSecondPower
                                iSearchRangeForNearestEngi = 100
                                iMaxEngisWanted = 10
                            end
                        end
                    elseif iCurrentConditionToTry == 52 then
                        if bHaveLowMass == false and iHighestFactoryOrEngineerTechAvailable == 1 and aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyAirDominance then
                            iActionToAssign = refActionBuildThirdPower
                            iMaxEngisWanted = 4
                        end
                    elseif iCurrentConditionToTry == 53 then
                        if bDebugMessages == true then LOG(sFunctionRef..': About to decide if want to build an experimental (or in some cases a factory) if have lots of mass. bHaveLowMass='..tostring(bHaveLowMass)..'; bHaveLowPower='..tostring(bHaveLowPower)..'; iMassStoredRatio='..iMassStoredRatio..'; iMassStored='..iMassStored) end
                        if bHaveLowMass == false and bHaveLowPower == false then
                            iMaxEngisWanted = 10
                            if (iMassStoredRatio > 0.6 or iMassStored > 12000) then --About to overflow so try to build something
                                --local iFactoryToAirRatio = iLandFactories / math.max(1, iAirFactories)
                                --local iDesiredFactoryToAirRatio = aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] / math.max(1, aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir])
                                --if iFactoryToAirRatio > iDesiredFactoryToAirRatio then
                                --if bDebugMessages == true then LOG(sFunctionRef..': iFactoryToAirRatio='..iFactoryToAirRatio..'; iDesiredFactoryToAirRatio='..iDesiredFactoryToAirRatio..'; iLandFactories='..iLandFactories..'; iAirFactories='..iAirFactories..'; aiBrain[M27Overseer.reftiMaxFactoryByType]='..repru(aiBrain[M27Overseer.reftiMaxFactoryByType])) end
                                if iAirFactories < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeAir] then
                                    iActionToAssign = refActionBuildAirFactory
                                else
                                    --Are we actively building an experimental?
                                    local bActiveExperimental = false
                                    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildExperimental]) == false then
                                        for iRef, tSubtable in  aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildExperimental] do
                                            if tSubtable[refEngineerAssignmentEngineerRef]:IsUnitState('Building') then
                                                bActiveExperimental = true
                                                break
                                            end
                                        end
                                    end
                                    if bActiveExperimental then
                                        iActionToAssign = refActionBuildExperimental
                                        iMaxEngisWanted = 30
                                        iSearchRangeForNearestEngi = 60
                                        if aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.99 then iMaxEngisWanted = 1
                                        elseif aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] <= 500 then
                                            iMaxEngisWanted = math.max(1, math.min(iMaxEngisWanted, math.floor(aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] / 10), math.floor(aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] / 50)))
                                        end
                                    else
                                        if iLandFactories < aiBrain[M27Overseer.reftiMaxFactoryByType][M27Overseer.refFactoryTypeLand] then
                                            iActionToAssign = refActionBuildLandFactory
                                        end
                                    end
                                end
                            end
                        end
                    elseif iCurrentConditionToTry == 54 then
                        --If about to overflow mass then build a second factory unless we arent using existing factories
                        if bHaveLowMass == false and bHaveLowPower == false and iMassStoredRatio >= 0.7 and aiBrain:GetEconomyStored('MASS') >= 2000 and aiBrain:GetEconomyStored('ENERGY') >= 0.99 and aiBrain[M27FactoryOverseer.refiFactoriesTemporarilyPaused] == 0 then
                            if aiBrain[M27MapInfo.refbCanPathToEnemyBaseWithLand] then

                                if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildLandFactory]) == true then
                                    iActionToAssign = refActionBuildLandFactory
                                    iMaxEngisWanted = 6
                                else
                                    --Already building a factory, so build a second factory
                                    iActionToAssign = refActionBuildSecondLandFactory
                                    iMaxEngisWanted = 4
                                end

                            else
                                if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildAirFactory]) == true then
                                    iActionToAssign = refActionBuildAirFactory
                                    iMaxEngisWanted = 6
                                else
                                    iActionToAssign = refActionBuildSecondAirFactory
                                    iMaxEngisWanted = 4
                                end
                            end
                        end
                    else
                        bAreOnSpareActions = true
                        if iCurrentConditionToTry == 55 then
                            --Start building a second experimental if we look like we might overflow mass, or have a very high mass income
                            if bHaveLowMass == false and bHaveLowPower == false and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildExperimental]) == false then
                                local bAlreadyBuildingFirstExperimental = false
                                for iEngiRef, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildExperimental] do
                                    if tSubtable[refEngineerAssignmentEngineerRef] then
                                        if tSubtable[refEngineerAssignmentEngineerRef]:IsUnitState('Building') or tSubtable[refEngineerAssignmentEngineerRef]:IsUnitState('Repairing') then
                                            bAlreadyBuildingFirstExperimental = true
                                            break
                                        end
                                    end
                                end
                                if aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 45 or (not (bAlreadyBuildingFirstExperimental) and aiBrain[M27EconomyOverseer.refiMassGrossBaseIncome] >= 17 and aiBrain:GetEconomyStoredRatio('MASS') >= 0.45 and aiBrain[M27EconomyOverseer.refiMassNetBaseIncome] > 0.5) then

                                    iActionToAssign = refActionBuildSecondExperimental
                                    iMaxEngisWanted = 1 + math.max(0, math.min(math.floor((aiBrain:GetEconomyStoredRatio('MASS') - 0.2) / 0.05)))
                                    iMinEngiTechLevelWanted = 3
                                    if iMaxEngisWanted >= 3 then
                                        --Consider increasing if we have positive net income and have started building
                                        local bAreBuilding = false
                                        if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildSecondExperimental]) == false then
                                            for iEngiRef, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildSecondExperimental] do
                                                if tSubtable[refEngineerAssignmentEngineerRef] then

                                                    if tSubtable[refEngineerAssignmentEngineerRef]:IsUnitState('Building') or tSubtable[refEngineerAssignmentEngineerRef]:IsUnitState('Repairing') then
                                                        bAreBuilding = true
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                        if bAreBuilding and aiBrain[M27EconomyOverseer.refiMassNetBaseIncome] > 1 then
                                            iMaxEngisWanted = math.max(iMaxEngisWanted, 30)
                                        end
                                    end
                                end
                            end
                        else
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': No priority actions so will assign any remaining engineers to spare action')
                            end
                            iActionToAssign = refActionSpare
                            iSearchRangeForNearestEngi = 10000
                            iMaxEngisWanted = 1000
                        end
                    end
                    end
                M27Utilities.FunctionProfiler(sFunctionRef..': Condition'..iCurrentConditionToTry..'Strat'..aiBrain[M27Overseer.refiAIBrainCurrentStrategy], M27Utilities.refProfilerEnd)
                M27Utilities.FunctionProfiler(sFunctionRef..': EngiConditions', M27Utilities.refProfilerEnd)

                iLoopCount = iLoopCount + 1
                if iLoopCount > iMaxLoopCount then
                    M27Utilities.ErrorHandler('Infinite loop for engineer assignment, will abort')
                    break
                end


                bWillBeAssigning = false
                if iActionToAssign then
                    --Check we havent recently failed to assign this action
                    if aiBrain[refiTimeOfLastFailure][iActionToAssign] and GetGameTimeSeconds() - aiBrain[refiTimeOfLastFailure][iActionToAssign] <= 9 then
                        iActionToAssign = nil
                        iCurConditionEngiShortfall = 0
                    else
                        if bDebugMessages == true then LOG(sFunctionRef..': Have an action to assign='..iActionToAssign..', will adjust the number of engineers we want if we are building power; iMaxEngisWanted before adj='..iMaxEngisWanted) end
                        --Increase engis to assign to power based on tech level; also dont build primary power if are buildilng power for adjacency for t3 arti (but are ok to build second power)
                        if iActionToAssign == refActionBuildPower or iActionToAssign == refActionBuildSecondPower then
                            if iActionToAssign == refActionBuildPower and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][refActionBuildT3ArtiPower]) == false then iActionToAssign = nil
                            else
                                iMaxEngisWanted = iMaxEngisWanted + iExtraEngisForPowerBasedOnTech
                                --Clear existing engineers if the primary engineer is a lower tech level and doesnt have a building unit state
                                if bDebugMessages == true then LOG(sFunctionRef..': Have an action to build power. iMaxEngisWanted='..iMaxEngisWanted..'; iHighestTechLevelEngi='..iHighestTechLevelEngi..';  M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign])='..tostring( M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign]))) end
                                if iHighestTechLevelEngi > 1 then
                                    if aiBrain[reftEngineerAssignmentsByActionRef] and aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign]) == false then
                                        for iRef, tEngSubtable in  aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] do
                                            if bDebugMessages == true then LOG(sFunctionRef..': looking for primary builder to see if it has a high enough tech level; Eng UC='..iRef..': Eng LC='..M27UnitInfo.GetUnitLifetimeCount(tEngSubtable[refEngineerAssignmentEngineerRef])..'; is primary builder='..tostring(tEngSubtable[refEngineerAssignmentEngineerRef][refbPrimaryBuilder])) end
                                            if tEngSubtable[refEngineerAssignmentEngineerRef][refbPrimaryBuilder] then
                                                if M27UnitInfo.GetUnitTechLevel(tEngSubtable[refEngineerAssignmentEngineerRef]) < iHighestTechLevelEngi and not(tEngSubtable[refEngineerAssignmentEngineerRef]:IsUnitState('Building')) then
                                                    if bDebugMessages == true then LOG(sFunctionRef..': Clearing engineer trackers as its not a high enough tech level') end
                                                    ClearEngineerActionTrackers(aiBrain, tEngSubtable[refEngineerAssignmentEngineerRef], true)
                                                end
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        iExistingEngineersAssigned = 0
                        if iActionToAssign and aiBrain[reftEngineerAssignmentsByActionRef] and aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign]) == false then
                            --Cant use table.getn for this table so do manually:
                            for iRef, tEngSubtable in  aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] do
                                iExistingEngineersAssigned = iExistingEngineersAssigned + 1
                                if bDebugMessages == true then LOG(sFunctionRef..': Engineer assigned='..tEngSubtable[refEngineerAssignmentEngineerRef].UnitId..M27UnitInfo.GetUnitLifetimeCount(tEngSubtable[refEngineerAssignmentEngineerRef])..'; UC='..GetEngineerUniqueCount(tEngSubtable[refEngineerAssignmentEngineerRef])..'; Engineer action='..(tEngSubtable[refEngineerAssignmentEngineerRef][refiEngineerCurrentAction] or 'nil')) end
                            end
                        end
                        if bDebugMessages == true then LOG(sFunctionRef..': iExistingEngineersAssigned='..iExistingEngineersAssigned..'; iMaxEngisWanted='..iMaxEngisWanted) end
                        if iActionToAssign and iExistingEngineersAssigned <= iMaxEngisWanted then
                            if iExistingEngineersAssigned == iMaxEngisWanted then
                                --Check if ACU is one of the units assigned to this action
                                if M27Utilities.GetACU(aiBrain)[refiEngineerCurrentAction] == iActionToAssign then
                                    if bDebugMessages == true then LOG(sFunctionRef..': iActionToAssign='..iActionToAssign..': ACU already has this action so reducing the number of engineers assigned.  iExistingEngineersAssigned before this change='..iExistingEngineersAssigned..'; iMaxEngisWanted='..iMaxEngisWanted) end
                                    iExistingEngineersAssigned = iExistingEngineersAssigned - 1
                                end
                            end
                            if iExistingEngineersAssigned < iMaxEngisWanted then

                                if bDebugMessages == true then LOG(sFunctionRef..': iActionToAssign='..iActionToAssign..'; iMaxEngisWanted='..iMaxEngisWanted..'; iCurrentConditionToTry='..iCurrentConditionToTry) end
                                --Need to get the location first so can search for engineers nearest to it
                                if iSearchRangeForNearestEngi == nil then iSearchRangeForNearestEngi = 100 end
                                if M27MapInfo.bNoRushActive then iSearchRangeForNearestEngi = math.min(iSearchRangeForNearestEngi, M27MapInfo.iNoRushRange * 2) end
                                --GetActionTargetAndObject(aiBrain, iActionRefToAssign, tExistingLocationsToPickFrom, tIdleEngineers, iActionPriority, tsUnitStatesToIgnoreCurrent, iSearchRangeForPrevEngi, iSearchRangeForNearestEngi, bOnlyReassignIdle, bGetInitialEngineer, iMinTechLevelWanted)
                                --GET MIN ENGI TECH LEVEL WANTED if not already specified above
                                --Set minimum engineer tech level if not specified and no existing engineers assigned to the action
                                if (iHighestFactoryOrEngineerTechAvailable > 1 or iHighestFactoryOrEngineerTechAvailable > 1) and iMinEngiTechLevelWanted == nil then
                                    --Are we building power or factory? If so then only build with the highest tech engi unless action is already in progress
                                    if iActionToAssign == refActionBuildPower or iActionToAssign == refActionBuildSecondPower or iActionToAssign == refActionBuildThirdPower or iActionToAssign == refActionBuildAirFactory or iActionToAssign == refActionBuildLandFactory or iActionToAssign == refActionBuildSecondLandFactory or iActionToAssign == refActionBuildSecondAirFactory then
                                        --Do we have at least 440 gross power or minimal mass stored? othwerise dont set any limit
                                        if aiBrain[M27EconomyOverseer.refiEnergyGrossBaseIncome] > 44 or (aiBrain:GetEconomyStoredRatio('MASS') <= 0.1 and aiBrain:GetEconomyStoredRatio('ENERGY') >= 0.99) then
                                            --Have we already got an engineer assigned to this action?
                                            if iExistingEngineersAssigned == 0 then
                                                if iActionToAssign == refActionBuildPower then iMinEngiTechLevelWanted = math.max(iHighestFactoryOrEngineerTechAvailable, iHighestFactoryOrEngineerTechAvailable)
                                                else iMinEngiTechLevelWanted = iHighestFactoryOrEngineerTechAvailable end
                                                if aiBrain[M27Overseer.refiAIBrainCurrentStrategy] == M27Overseer.refStrategyACUKill and aiBrain[M27Overseer.refbIncludeACUInAllOutAttack] then
                                                    iMinEngiTechLevelWanted = math.min(iHighestFactoryOrEngineerTechAvailable, iHighestFactoryOrEngineerTechAvailable)
                                                end
                                            elseif iHighestFactoryOrEngineerTechAvailable >= 3 then
                                                iMinEngiTechLevelWanted = 2
                                            end
                                        end
                                    elseif iActionToAssign == refActionBuildT3MexOverT2 then iMinEngiTechLevelWanted = 3
                                    else
                                        --Dont use t1 engineers for anything likely to be built near base once we have T3+ factory
                                        if iMinEngiTechLevelWanted == nil and iHighestFactoryOrEngineerTechAvailable >= 3 then
                                            if not(iActionToAssign == refActionBuildMex) and not(iActionToAssign == refActionBuildT1Radar) and not(iActionToAssign == refActionBuildMassStorage) and not(iActionToAssign == refActionReclaimArea) and not(iActionToAssign == refActionReclaimTrees) and not(iActionToAssign == refActionSpare) and not(iActionToAssign == refActionBuildHydro) then
                                                iMinEngiTechLevelWanted = 2
                                            end
                                        end
                                    end
                                end
                                if iMinEngiTechLevelWanted == nil then iMinEngiTechLevelWanted = 1 end
                                bHaveEngisOfCurrentOrHigherTech = false
                                if iEngineersToConsider > 0 then
                                    --Have we already assigned an engineer this action so we only need to be able to assist?
                                    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign]) == false then
                                        if iHighestFactoryOrEngineerTechAvailable >= 3 then
                                            iMinEngiTechLevelWanted = math.min(2, iMinEngiTechLevelWanted)
                                        else iMinEngiTechLevelWanted = 1
                                        end
                                    end
                                    if iMinEngiTechLevelWanted == 1 or M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign]) == false then bHaveEngisOfCurrentOrHigherTech = true
                                    else
                                        if iMinEngiTechLevelWanted == 2 and tiAvailableEngineersByTech[iMinEngiTechLevelWanted] + tiAvailableEngineersByTech[iMinEngiTechLevelWanted + 1] > 0 then bHaveEngisOfCurrentOrHigherTech = true
                                        elseif tiAvailableEngineersByTech[3] > 0 then bHaveEngisOfCurrentOrHigherTech = true
                                        end
                                    end
                                end
                                if bDebugMessages == true then LOG(sFunctionRef..': iMinEngiTechLevelWanted='..iMinEngiTechLevelWanted..'; bHaveEngisOfCurrentOrHigherTech='..tostring(bHaveEngisOfCurrentOrHigherTech)..'; tiAvailableEngineersByTech='..repru(tiAvailableEngineersByTech)) end
                                tActionTargetLocation = nil
                                oActionTargetObject = nil
                                if bHaveEngisOfCurrentOrHigherTech then
                                    M27Utilities.FunctionProfiler(sFunctionRef..': Action'..iActionToAssign, M27Utilities.refProfilerStart)
                                    tActionTargetLocation, oActionTargetObject, bClearCurrentlyAssignedEngineer = GetActionTargetAndObject(aiBrain, iActionToAssign, tExistingLocationsToPickFrom, tIdleEngineers, iCurrentConditionToTry, tsUnitStatesToIgnoreCurrent, iSearchRangeForPrevEngi, iSearchRangeForNearestEngi, bOnlyReassignIdle, bGetInitialEngineer, iMinEngiTechLevelWanted)
                                    if bDebugMessages == true then
                                        LOG(sFunctionRef..': Finished getting action target location and object; tActionTargetLocation = '..repru(tActionTargetLocation or {'nil'})..'; bClearCurrentlyAssignedEngineer='..tostring((bClearCurrentlyAssignedEngineer or false)))
                                        if not(oActionTargetObject) then LOG('ActionTargetObject is nil')
                                        else LOG('ActionTargetObject='..oActionTargetObject.UnitId..M27UnitInfo.GetUnitLifetimeCount(oActionTargetObject))
                                        end
                                    end
                                    M27Utilities.FunctionProfiler(sFunctionRef..': Action'..iActionToAssign, M27Utilities.refProfilerEnd)
                                end



                                --GetNearestEngineerWithLowerPriority(aiBrain, tEngineers, iCurrentActionPriority, tCurrentActionTarget, iActionRefToGetExistingCount, tsUnitStatesToIgnore)
                                if M27Utilities.IsTableEmpty(tActionTargetLocation) == true and oActionTargetObject == nil then
                                    if bHaveEngisOfCurrentOrHigherTech and not(iActionToAssign == refActionReclaimUnit) then M27Utilities.ErrorHandler('Couldnt find valid target or object for the action so wont proceed with it, review if this happens repeatedly for unexpected actions (examples where this triggers in line with expectations are if want to assist a building but all of them have nearby enemies (or are factories that are idle), or if try to reclaim a unit that no longer has a position (this warning is hidden if the action was to reclaim a unit as a result though). iActionToAssign='..iActionToAssign..'; iCurrentConditionToTry='..iCurrentConditionToTry, true) end
                                    iCurConditionEngiShortfall = iMaxEngisWanted - iExistingEngineersAssigned
                                    if bDebugMessages == true then LOG(sFunctionRef..': Have no action target or object target, so unless anErrormessage has appeared we are just calculating how many engis we want to build; Total available T3 engis='..tiAvailableEngineersByTech[3]..'; repr of table of available engis by tech level='..repru(tiAvailableEngineersByTech)) end
                                else
                                    if bDebugMessages == true then LOG(sFunctionRef..': iExistingEngineersAssigned='..iExistingEngineersAssigned..'; iMinEngiTechLevelWanted='..iMinEngiTechLevelWanted) end
                                    --GetNearestEngineerWithLowerPriority(aiBrain, tEngineers, iCurrentActionPriority, tCurrentActionTarget, iActionRefToGetExistingCount, tsUnitStatesToIgnore, iMaxRangeForPrevEngi)
                                    if iActionToAssign == refActionBuildTMD then iSearchRangeForNearestEngi = math.max(iSearchRangeForNearestEngi, M27Utilities.GetDistanceBetweenPositions(tActionTargetLocation, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber]) + 10) end
                                    if oEngineerToAssign == nil and bHaveEngisOfCurrentOrHigherTech then oEngineerToAssign = GetNearestEngineerWithLowerPriority(aiBrain, tIdleEngineers, iCurrentConditionToTry, (tActionTargetLocation or oActionTargetObject:GetPosition()), iActionToAssign, tsUnitStatesToIgnoreCurrent, iSearchRangeForPrevEngi, iSearchRangeForNearestEngi, bOnlyReassignIdle, bGetInitialEngineer, iMinEngiTechLevelWanted) end
                                    if oEngineerToAssign then
                                        if oEngineerToAssign.GetPlan then M27Utilities.ErrorHandler('oEngineer is a platoon, plan='..oEngineerToAssign:GetPlan()..(oEngineerToAssign[M27PlatoonUtilities.refiPlatoonCount] or 'nil')) end
                                        if bDebugMessages == true then
                                            LOG(sFunctionRef..': Have a valid engineer and not already assigned for the action, so will be assigning action='..iActionToAssign..' from condition '..iCurrentConditionToTry..' to this engineer with name='..oEngineerToAssign.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineerToAssign)..'; UC='..GetEngineerUniqueCount(oEngineerToAssign))
                                        end
                                        bWillBeAssigning = true
                                    else
                                        if bDebugMessages == true then LOG(sFunctionRef..' condition:'..iCurrentConditionToTry..': oEngineerToAssign is nil, assuming its because available engineer is too far away so wont abort. bHaveEngisOfCurrentOrHigherTech='..tostring(bHaveEngisOfCurrentOrHigherTech)..'; bOnlyReassignIdle='..tostring(bOnlyReassignIdle)) end
                                        iCurConditionEngiShortfall = iMaxEngisWanted - iExistingEngineersAssigned

                                        --Strange issue where somehow will pick an engineer that isn't part of the original idle engineers in the above to try and assign an order, spent a while and couldnt figure out why so will just try and have it only trigger once per cycle
                                        for iTech = iMinEngiTechLevelWanted, 3 do
                                            tiAvailableEngineersByTech[iTech] = 0
                                        end
                                        iEngineersToConsider = 0
                                        for iTech = 1, 3 do
                                            iEngineersToConsider = iEngineersToConsider + tiAvailableEngineersByTech[iTech]
                                        end
                                        if bDebugMessages == true then LOG(sFunctionRef..': Couldnt find any engineers so will revise the list of available engineers') end
                                    end
                                end
                            end
                        else
                            if bDebugMessages == true then
                                LOG(sFunctionRef..': iActionToAssign='..(iActionToAssign or 'nil')..'; Already assigned '..iExistingEngineersAssigned..'  engis and only wanted '..iMaxEngisWanted..'; will list out all engineers assigned')
                                --reftEngineerAssignmentsByActionRef = 'M27EngineerAssignmentsByAction' --Records all engineers. [x][y]{1,2} - x is the action ref; y is the engineer unique ref, 1 is the location ref, 2 is the engineer object (use the subtable ref keys instead of numbers to refer to these)
                                for iRef, tRef in aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] do
                                    LOG('iRef='..iRef..'; Engineer ID and LC='..tRef[refEngineerAssignmentEngineerRef].UnitId..M27UnitInfo.GetUnitLifetimeCount(tRef[refEngineerAssignmentEngineerRef]))
                                end
                            end
                        end
                    end
                else
                    iCurConditionEngiShortfall = 0
                end



                --Update build order tracker; all of below were set to 0 before started the loop, so only need to change from 0
                --Note that for spare engis we just track how many we have (not how many we want)
                if iCurConditionEngiShortfall > 0 then
                    if bAreOnSpareActions == false then
                        --NOTE: Although below will set engis wanted, this may be changed back to 0 at end if we have engineers of the highest tech level
                        if bThresholdPreReclaimEngineerCondition == false then
                            if bThresholdInitialEngineerCondition == false then --Not got through initial conditions
                                aiBrain[refiBOInitialEngineersWanted] = aiBrain[refiBOInitialEngineersWanted] + iCurConditionEngiShortfall
                                aiBrain[refiBOPreReclaimEngineersWanted] = math.max(1, aiBrain[refiBOPreReclaimEngineersWanted])
                                aiBrain[refiBOPreSpareEngineersWanted] = math.max(1, aiBrain[refiBOPreSpareEngineersWanted])
                            else --Have got initial engis
                                aiBrain[refiBOPreReclaimEngineersWanted] = aiBrain[refiBOPreReclaimEngineersWanted] + iCurConditionEngiShortfall
                                aiBrain[refiBOPreSpareEngineersWanted] = math.max(1, aiBrain[refiBOPreSpareEngineersWanted])
                            end
                        else --Have got initial engis and pre-reclaim engis
                            aiBrain[refiBOPreSpareEngineersWanted] = aiBrain[refiBOPreSpareEngineersWanted] + iCurConditionEngiShortfall
                        end
                    else
                        --Already all set to 0
                    end
                end
                --Ensure we will be building initial engineer build order in priority to anything else
                if M27Conditions.LifetimeBuildCountLessThan(aiBrain, M27UnitInfo.refCategoryEngineer, aiBrain[M27FactoryOverseer.refiInitialEngineersWanted]) then
                    aiBrain[refiBOInitialEngineersWanted] = math.max(aiBrain[refiBOInitialEngineersWanted], aiBrain[M27FactoryOverseer.refiInitialEngineersWanted] - aiBrain:GetCurrentUnits(M27UnitInfo.refCategoryEngineer))
                end
                if bDebugMessages == true then LOG(sFunctionRef..': iCurrentConditionToTry='..iCurrentConditionToTry..'; iCurConditionEngiShortfall='..iCurConditionEngiShortfall..'; aiBrain[refiBOInitialEngineersWanted]='..aiBrain[refiBOInitialEngineersWanted]..'; aiBrain[refiBOPreReclaimEngineersWanted]='..aiBrain[refiBOPreReclaimEngineersWanted]..'; aiBrain[refiBOPreSpareEngineersWanted]='..aiBrain[refiBOPreSpareEngineersWanted]) end



                if bWillBeAssigning == true then
                    M27Utilities.FunctionProfiler(sFunctionRef..': Action'..iActionToAssign, M27Utilities.refProfilerStart)
                    if bDebugMessages == true then
                        local sEngineerName = M27UnitInfo.GetUnitLifetimeCount(oEngineerToAssign)
                        LOG(sFunctionRef..': Game time='..GetGameTimeSeconds()..': About to assign action '..iActionToAssign..' to engineer number '..GetEngineerUniqueCount(oEngineerToAssign)..' with lifetime count='..sEngineerName..' due to iCurrentConditionToTry='..iCurrentConditionToTry..'; Eng unitId='..oEngineerToAssign.UnitId..'; ActionTargetLocation='..repru(tActionTargetLocation))
                        if iAllUnclaimedMexesInPathingGroup then LOG('iAllUnclaimedMexesInPathingGroup='..iAllUnclaimedMexesInPathingGroup) end
                        if iUnclaimedMexesOnOurSideOfMap then LOG('iUnclaimedMexesOnOurSideOfMap='..iUnclaimedMexesOnOurSideOfMap) end
                        if iUnclaimedMexesWithinDefenceCoverage then LOG('iUnclaimedMexesWithinDefenceCoverage='..iUnclaimedMexesWithinDefenceCoverage) end
                    end
                    if bClearCurrentlyAssignedEngineer == true then --will be true if currently assigned engineer is lower tech level than the min tech level wanted
                        --Clear existing engineer assigned the action
                        if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign]) == false then
                            for iSubtable, tSubtable in aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] do
                                if bDebugMessages == true then LOG(sFunctionRef..': Want to clear currently assigned engineer for the action; engi to clear='..tSubtable[refEngineerAssignmentEngineerRef].UnitId..M27UnitInfo.GetUnitLifetimeCount(tSubtable[refEngineerAssignmentEngineerRef])..'; UC='..GetEngineerUniqueCount(tSubtable[refEngineerAssignmentEngineerRef])) end
                                ClearEngineerActionTrackers(aiBrain, tSubtable[refEngineerAssignmentEngineerRef], true)
                            end
                        end
                    end
                    iEngineersToConsider = iEngineersToConsider - 1
                    iCurEngiTechLevel = math.min(M27UnitInfo.GetUnitTechLevel(oEngineerToAssign), 3)
                    tiAvailableEngineersByTech[iCurEngiTechLevel] = tiAvailableEngineersByTech[iCurEngiTechLevel] - 1
                    if bDebugMessages == true then LOG(sFunctionRef..': oEngineerToAssign UC='..GetEngineerUniqueCount(oEngineerToAssign)..'; iActionToAssign='..iActionToAssign..'; tActionTargetLocation='..repru((tActionTargetLocation or {'nil'}))) end

                    AssignActionToEngineer(aiBrain, oEngineerToAssign, iActionToAssign, tActionTargetLocation, oActionTargetObject, iCurrentConditionToTry)
                    if iActionToAssign == refActionBuildMex then
                        tAllUnclaimedMexesInPathingGroup = nil
                        iAllUnclaimedMexesInPathingGroup = nil
                        tUnclaimedMexesOnOurSideOfMap = nil
                        iUnclaimedMexesOnOurSideOfMap = nil
                        tUnclaimedMexesWithinDefenceCoverage = nil
                        iUnclaimedMexesWithinDefenceCoverage = nil
                    end
                    M27Utilities.FunctionProfiler(sFunctionRef..': Action'..iActionToAssign, M27Utilities.refProfilerEnd)
                else
                    iCurrentConditionToTry = iCurrentConditionToTry + 1
                    if iActionToAssign == refActionSpare then
                        if iEngineersToConsider > 0 then
                            M27Utilities.ErrorHandler('Werent able to assign a spare action to an engineer so likely we think an engineer is idle but we cant then locate that engineer when trying toa ssign the action - investigate. tiAvailableEngineersByTech='..repru(tiAvailableEngineersByTech)..'; iMinEngiTechLevelWanted='..iMinEngiTechLevelWanted)
                        end
                        break
                    end --If we couldnt assign a spare engi action then dont want to keep going as may be in infinite loop territory
                end
            end
        end

        --Check how many spare engineers we have
        local tiSpareEngiCount = {0,0,0,0}
        local iCurTechLevel
        for iEngineer, oEngineer in tEngineers do
            if oEngineer[refiEngineerCurrentAction] == refActionSpare then
                iCurTechLevel = M27UnitInfo.GetUnitTechLevel(oEngineer)
                tiSpareEngiCount[iCurTechLevel] = tiSpareEngiCount[iCurTechLevel] + 1
            end
        end
        local iExistingSpareEngisForCurTechLevel = 0
        for iCurTechLevel = iHighestFactoryOrEngineerTechAvailable, 4 do
            if tiSpareEngiCount[iCurTechLevel] > 0 then iExistingSpareEngisForCurTechLevel = iExistingSpareEngisForCurTechLevel + 1 end
        end
        aiBrain[reftiBOActiveSpareEngineersByTechLevel] = tiSpareEngiCount --Want it to be a table
        if bDebugMessages == true then LOG(sFunctionRef..': tiSpareEngiCount='..repru(tiSpareEngiCount)..'; Mass stored %='..aiBrain:GetEconomyStoredRatio('MASS')..'; Mass stored='..aiBrain:GetEconomyStored('MASS')..'; will set engineers wnated to 0 if have at least 5 spare engis and dont have lots of mass') end
        if tiSpareEngiCount[iHighestFactoryOrEngineerTechAvailable] > 5 and (tiSpareEngiCount[iHighestFactoryOrEngineerTechAvailable] >= 25 or aiBrain:GetEconomyStoredRatio('MASS') <= 0.2 or aiBrain:GetEconomyStored('MASS') < 600) then
            aiBrain[refiBOInitialEngineersWanted] = 0
            aiBrain[refiBOPreReclaimEngineersWanted] = 0
            aiBrain[refiBOPreSpareEngineersWanted] = 0
        end

        --TEMPTEST(aiBrain, sFunctionRef..': End of code')
    end
    if bDebugMessages == true then LOG(sFunctionRef..': End of code') end
    M27Utilities.FunctionProfiler(sFunctionRef..': Overall', M27Utilities.refProfilerEnd)
end

function DelayedEngiReassignment(aiBrain, bOnlyReassignIdle, tEngineersToReassign)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end

    local sFunctionRef = 'DelayedEngiReassignment'
    local tRevisedEngisToReassign = {}
    local iRevisedEngisToReassign = 0
    --Below is redundancy to help protect from recursive loop that had happen once (hopefully cause was fixed but want this as backup since it crashes the game within 30s)
    for iEngi, oEngi in tEngineersToReassign do
        if not(oEngi[refbAlreadyReassigning]) then
            oEngi[refbAlreadyReassigning] = true
            iRevisedEngisToReassign = iRevisedEngisToReassign + 1
            tRevisedEngisToReassign[iRevisedEngisToReassign] = oEngi
        end
    end
    WaitTicks(1)
    if M27Logic.iTimeOfLastBrainAllDefeated < 10 then
        if bDebugMessages == true then
            LOG(sFunctionRef..': Reassigning '..table.getn(tEngineersToReassign)..'engineers')
            --M27Utilities.ErrorHandler('Full audit trail of reassignengineer call', true)
        end
        for iEngi, oEngi in tRevisedEngisToReassign do
            oEngi[refbAlreadyReassigning] = false
        end
        ReassignEngineers(aiBrain, bOnlyReassignIdle, tEngineersToReassign)
    end
end

function CheckAllEngineerLocations(aiBrain)
    --Flags errors if any inconsistencies with engineers, and hten clears the location data
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'CheckAllEngineerLocations'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local tOldLocations = {}
    local iOldLocations = 0
    --reftEngineerAssignmentsByLocation = 'M27EngineerAssignmentsByLoc'     --[x][y][z];  x is the unique location ref (need to use ConvertLocationToReference in utilities to use), [y] is the actionref, z is the engineer unique ref assigned to this location; returns the engineer object
    if M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation]) == false then
       for sLocationRef, tSubtable in aiBrain[reftEngineerAssignmentsByLocation] do
           for iAction, tActionSubtable in aiBrain[reftEngineerAssignmentsByLocation][sLocationRef] do
               for iEngiRef, oEngi in aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][iAction] do
                   if not(oEngi[refiEngineerCurrentAction] == iAction) then
                       iOldLocations = iOldLocations + 1
                       tOldLocations[iOldLocations] = {sLocationRef, iAction, iEngiRef}
                   end
               end
           end
       end
    end
    if iOldLocations > 0 then
        M27Utilities.ErrorHandler('Have old locations, will list out before clearing; 1st val=location, 2nd=action, 3rd=engiref: '..repru({tOldLocations[1], tOldLocations[2], tOldLocations[3]}))
        for iOldLocation, tSubtable in tOldLocations do
            aiBrain[reftEngineerAssignmentsByLocation][tSubtable[1]][tSubtable[2]][tSubtable[3]] = nil
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function ReassignPlateauEngineer(aiBrain, oEngineer)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'ReassignPlateauEngineer'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    local iPlateauGroup = oEngineer[M27Transport.refiAssignedPlateau]
    if bDebugMessages == true then LOG(sFunctionRef..': Start of code, for oEngineer='..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer)..'; iPlateauGroup='..iPlateauGroup..'; plateau group based on location='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oEngineer:GetPosition())..'; Our base plateau group='..aiBrain[M27MapInfo.refiOurBasePlateauGroup]..'; Engineer unit state='..M27Logic.GetUnitState(oEngineer)) end

    local iCurLoopCount = 0
    local iCurrentConditionToTry = 0
    local iCurLandFactories = 0
    local iMaxEngisWanted
    local iActionToAssign
    local iMinEngiTechLevelWanted = 1
    local iSearchRangeForNearestEngi
    local iExistingEngineersAssigned
    local oExistingBuilder
    local tActionTargetLocation

    --Common conditions
    local bHaveLowMass = M27Conditions.HaveLowMass(aiBrain)
    local bHaveLowPower = false

    --Make sure plateau flags that this engineer is assigned to it (used e.g. to track how many engineers we have on the plateau when deciding if should build more)
    if not(aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup]) or M27Utilities.IsTableEmpty(M27Utilities.IsTableEmpty(M27MapInfo.tAllPlateausWithMexes[iPlateauGroup])) then
        --First recheck pathing and update engineer plateau group if it has changed
        local bPathingChanged = M27MapInfo.RecheckPathingOfLocation(M27UnitInfo.refPathingTypeAmphibious, oEngineer, oEngineer:GetPosition())
        if bDebugMessages == true then LOG(sFunctionRef..': iPlateauGroup='..(iPlateauGroup or 'nil')..'; didnt have a table for this so will recheck pathing.  bPathingChanged='..tostring(bPathingChanged)..'; Eng position='..repru(oEngineer:GetPosition())..'; palteau pathing group of cur position='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oEngineer:GetPosition())) end
        if bPathingChanged then
            iCurLoopCount = 10000
        else
            if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup]) then aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup] = {} end
        end
        oEngineer[M27Transport.refiAssignedPlateau] = M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oEngineer:GetPosition())
        if M27Utilities.IsTableEmpty(M27MapInfo.tAllPlateausWithMexes[iPlateauGroup]) then
            iCurLoopCount = 10000
            IssueAggressiveMove({oEngineer}, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
        end
    end
    if aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup] then
        if not(aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup][M27MapInfo.subrefPlateauEngineers]) then aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup][M27MapInfo.subrefPlateauEngineers] = {} end
        aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup][M27MapInfo.subrefPlateauEngineers][GetEngineerUniqueCount(oEngineer)] = oEngineer

        if aiBrain[M27EconomyOverseer.refbStallingEnergy] or GetGameTimeSeconds() - aiBrain[M27EconomyOverseer.refiLastEnergyStall] <= 20 then
            if bDebugMessages == true then LOG(sFunctionRef..': Have low power as recently stalled') end
            bHaveLowPower = true
        else
            if aiBrain:GetEconomyStoredRatio('ENERGY') < 0.99 and (aiBrain:GetEconomyStored('ENERGY') < 1000 or aiBrain[M27EconomyOverseer.refiEnergyNetBaseIncome] <= 0) then
                if bDebugMessages == true then LOG(sFunctionRef..': Have low power as dont have much stored') end
                bHaveLowPower = true
            end
        end

        if bDebugMessages == true then LOG(sFunctionRef..': Is table of plateau land factories for plateau group '..iPlateauGroup..' empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup][M27MapInfo.subrefPlateauLandFactories]))) end
        if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup][M27MapInfo.subrefPlateauLandFactories]) == false then
            for iUnit, oUnit in aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup][M27MapInfo.subrefPlateauLandFactories] do
                if bDebugMessages == true then LOG(sFunctionRef..': Considering factory iUnit='..iUnit..'; Is valid='..tostring(M27UnitInfo.IsUnitValid(oUnit))) end
                if M27UnitInfo.IsUnitValid(oUnit) and oUnit:GetFractionComplete() == 1 then
                    iCurLandFactories = iCurLandFactories + 1
                else
                    if bDebugMessages == true then LOG(sFunctionRef..': Factory not valid or not compelte so removing the reference') end
                    aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup][M27MapInfo.subrefPlateauLandFactories][iUnit] = nil
                end
            end
        end

        --Move to random position if have no info for this plateau
        if M27Utilities.IsTableEmpty(M27MapInfo.tAllPlateausWithMexes[iPlateauGroup]) then
            --Recheck engineer pathing

        end

        while iCurLoopCount <= 100 do
            iCurLoopCount = iCurLoopCount + 1
            if iCurLoopCount >= 99 then M27Utilities.ErrorHandler('Infinite loop') break end

            iCurrentConditionToTry = iCurrentConditionToTry + 1


            --Set defaults
            iMaxEngisWanted = 1
            iMinEngiTechLevelWanted = 1
            iActionToAssign = nil
            oExistingBuilder = nil
            tActionTargetLocation = nil

            if iCurrentConditionToTry == 1 then
                --Land factory to secure plateau
                if bDebugMessages == true then LOG(sFunctionRef..': Considering whether to get initial land factory. iCurLandFactories='..(iCurLandFactories or 'nil')..'; MexesOnPlateau='..(M27MapInfo.tAllPlateausWithMexes[iPlateauGroup][M27MapInfo.subrefPlateauTotalMexCount] or 'nil')) end
                if iCurLandFactories == 0 and M27MapInfo.tAllPlateausWithMexes[iPlateauGroup][M27MapInfo.subrefPlateauTotalMexCount] >= 3 then
                    iActionToAssign = refActionBuildPlateauFactory
                    iMaxEngisWanted = 10
                end
            elseif iCurrentConditionToTry == 2 then
                --Unclaimed mexes (by anyone) that arent queued up
                local tAllUnclaimedMexesInPathingGroup = GetUnclaimedMexes(aiBrain, M27UnitInfo.refPathingTypeAmphibious, iPlateauGroup, true, false, false)
                if bDebugMessages == true then LOG(sFunctionRef..': Is table of unclaimed mexes empty='..tostring(M27Utilities.IsTableEmpty(tAllUnclaimedMexesInPathingGroup))) end
                if M27Utilities.IsTableEmpty(tAllUnclaimedMexesInPathingGroup) == false then
                    --Get the closest mex to our position (note - getting some bugs when leave this to the standard logic)
                    iActionToAssign = refActionBuildPlateauMex
                    iMaxEngisWanted = math.max(1, M27MapInfo.tAllPlateausWithMexes[iPlateauGroup][M27MapInfo.subrefPlateauTotalMexCount]) --Onlya ssigning engineers 1 at a time and are checking if mex unclaimed each time, so this is just to make sure we give the engineer the order
                    local iCurDist
                    local iClosestDist = 10000
                    for iMex, tMex in tAllUnclaimedMexesInPathingGroup do
                        iCurDist = M27Utilities.GetDistanceBetweenPositions(oEngineer:GetPosition(), tMex)
                        if iCurDist < iClosestDist then
                            iClosestDist = iCurDist
                            tActionTargetLocation = {tMex[1], tMex[2], tMex[3]}
                        end
                    end
                end
            elseif iCurrentConditionToTry == 3 then
                --Land factories if not low mass and none of existing factories are paused
                if bDebugMessages == true then LOG(sFunctionRef..': Considering whether to get more land factories. bHaveLowMass='..tostring(bHaveLowMass)..'; bHaveLowPower='..tostring(bHaveLowPower)..'; Floor of Mexes on plateau*0.5='..math.floor((M27MapInfo.tAllPlateausWithMexes[iPlateauGroup][M27MapInfo.subrefPlateauTotalMexCount] - 1) * 0.5)..'; iCurLandFactories='..iCurLandFactories..'; Mexes on plateau='..M27MapInfo.tAllPlateausWithMexes[iPlateauGroup][M27MapInfo.subrefPlateauTotalMexCount]) end
                if not(bHaveLowMass) and not(bHaveLowPower) and iCurLandFactories < math.floor((M27MapInfo.tAllPlateausWithMexes[iPlateauGroup][M27MapInfo.subrefPlateauTotalMexCount] - 1) * 0.5) then
                    iActionToAssign = refActionBuildPlateauFactory
                    iMaxEngisWanted = 10
                    if M27Utilities.IsTableEmpty(aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup][M27MapInfo.subrefPlateauLandFactories]) == false then

                        for iFactory, oFactory in aiBrain[M27MapInfo.reftOurPlateauInformation][iPlateauGroup] do
                            if oFactory[M27FactoryOverseer.refbFactoryTemporaryPauseActive] then
                                iActionToAssign = nil
                                break
                            end
                        end
                    end
                end
            elseif iCurrentConditionToTry == 4 then --Reclaim
                local bWantMass
                local bWantEnergy

                if aiBrain:GetEconomyStoredRatio('ENERGY') <= 0.7 then bWantEnergy = true
                elseif bHaveLowMass or aiBrain:GetEconomyStoredRatio('MASS') <= 0.3 then bWantMass = true end
                if bDebugMessages == true then LOG(sFunctionRef..': Considering if want to get reclaim. bWantMass='..tostring(bWantMass or false)..'; bWantEnergy='..tostring(bWantEnergy or false)) end
                if bWantMass or bWantEnergy then
                    local iBaseSegmentX, iBaseSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(oEngineer:GetPosition())
                    local iAbsMaxDif = 10000
                    local iAbsCurDif
                    local sLocationRef, tCurLocation
                    local tClosestReclaimLocation
                    local sReclaimValueRef
                    local iMinValueWanted = 15
                    local iArmyIndex = aiBrain:GetArmyIndex()
                    if bWantEnergy then iMinValueWanted = 100 end

                    if bWantMass then sReclaimValueRef = M27MapInfo.refReclaimTotalMass
                    else sReclaimValueRef = M27MapInfo.refReclaimTotalEnergy
                    end


                    --Get closest segment with reclaim that is unassigned
                    if bDebugMessages == true then
                        local iEngReclaimSegmentX, iEngReclaimSegmentZ = M27MapInfo.GetReclaimSegmentsFromLocation(oEngineer:GetPosition())
                        LOG(sFunctionRef..': Reclaim segment taht engineer is currently in='..iEngReclaimSegmentX, iEngReclaimSegmentZ..'; Eng position='..repru(oEngineer:GetPosition())..'; will cycle through every segment recorded as being part of the engineer plateau '..iPlateauGroup)
                    end
                    for iReclaimSegmentX, tSubtable in M27MapInfo.tAllPlateausWithMexes[iPlateauGroup][M27MapInfo.subrefPlateauReclaimSegments] do
                        if bDebugMessages == true then LOG(sFunctionRef..': Considering iReclaimSegmentX='..iReclaimSegmentX) end
                        for iReclaimSegmentZ, bValue in tSubtable do
                            if bDebugMessages == true then LOG(sFunctionRef..': iReclaimSegmentZ='..iReclaimSegmentZ..'; Reclaim value='..(M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][sReclaimValueRef] or 0)..'; iMinValueWanted='..iMinValueWanted) end
                            --Do we have enough reclaim at the location?
                            if M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][sReclaimValueRef] >= iMinValueWanted then
                                if bDebugMessages == true then
                                    LOG(sFunctionRef..': Has an engineer died here recently? Will give the time if one has')
                                    if M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][M27MapInfo.reftReclaimTimeOfLastEngineerDeathByArmyIndex] and M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][M27MapInfo.reftReclaimTimeOfLastEngineerDeathByArmyIndex][iArmyIndex] then LOG(sFunctionRef..': Time since death='..(GetGameTimeSeconds() - M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][M27MapInfo.reftReclaimTimeOfLastEngineerDeathByArmyIndex][iArmyIndex])) end
                                end
                                --Has an engi died here recently?
                                if not(M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][M27MapInfo.reftReclaimTimeOfLastEngineerDeathByArmyIndex]) or not(M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][M27MapInfo.reftReclaimTimeOfLastEngineerDeathByArmyIndex][iArmyIndex]) or (GetGameTimeSeconds() - M27MapInfo.tReclaimAreas[iReclaimSegmentX][iReclaimSegmentZ][M27MapInfo.reftReclaimTimeOfLastEngineerDeathByArmyIndex][iArmyIndex]) > 300 then
                                    --Is an engineer already assigned here?
                                    tCurLocation = M27MapInfo.GetReclaimLocationFromSegment(iReclaimSegmentX, iReclaimSegmentZ)
                                    sLocationRef = M27Utilities.ConvertLocationToReference(tCurLocation)
                                    if bDebugMessages == true then LOG(sFunctionRef..': Checking if engi already assigned to this location. Is table empty for sLocationRef='..sLocationRef..'='..tostring(M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef]))) end
                                    if not(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef]) or not(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][refActionPlateauReclaim]) or M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByLocation][sLocationRef][refActionPlateauReclaim]) == true then
                                        iAbsCurDif = math.abs(iReclaimSegmentX - iBaseSegmentX) + math.abs(iReclaimSegmentZ - iBaseSegmentZ)
                                        if iAbsCurDif < iAbsMaxDif then
                                            tClosestReclaimLocation = tCurLocation
                                            iAbsMaxDif = iAbsCurDif
                                            if iAbsMaxDif <= 3 then break end
                                        end
                                    end
                                end
                            end
                        end
                    end

                    if bDebugMessages == true then LOG(sFunctionRef..': Finished searching for potential reclaim. tClosestReclaimLocation ='..repru((tClosestReclaimLocation or {'nil'}))..'; Eng position='..repru(oEngineer:GetPosition())) end

                    if tClosestReclaimLocation then
                        iActionToAssign = refActionPlateauReclaim
                        iMaxEngisWanted = 100 --No limit on engineers assigned to reclaim
                        tActionTargetLocation = tClosestReclaimLocation
                    end
                end
            elseif iCurrentConditionToTry == 5 then --Spare
                if bDebugMessages == true then LOG(sFunctionRef..': No more actions so will give spare action') end
                iActionToAssign = refActionPlateauSpareAction
                iMaxEngisWanted = 100
            end

            if iActionToAssign then

                --Check we havent recently failed to assign this action
                if bDebugMessages == true then LOG(sFunctionRef..': Have iActionToAssign='..iActionToAssign) end
                if aiBrain[refiTimeOfLastFailure][iActionToAssign] and GetGameTimeSeconds() - aiBrain[refiTimeOfLastFailure][iActionToAssign] <= 9 then
                    if bDebugMessages == true then LOG(sFunctionRef..': Time since last failure='..GetGameTimeSeconds() - aiBrain[refiTimeOfLastFailure][iActionToAssign]) end
                    iActionToAssign = nil
                end
            end
            if iActionToAssign then
                iExistingEngineersAssigned = 0
                if iActionToAssign and aiBrain[reftEngineerAssignmentsByActionRef] and aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] and M27Utilities.IsTableEmpty(aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign]) == false then
                    --Cant use table.getn for this table so do manually:
                    for iRef, tEngSubtable in aiBrain[reftEngineerAssignmentsByActionRef][iActionToAssign] do
                        if tEngSubtable[refEngineerAssignmentEngineerRef][M27Transport.refiAssignedPlateau] == iPlateauGroup then
                            iExistingEngineersAssigned = iExistingEngineersAssigned + 1
                            if bDebugMessages == true then
                                LOG(sFunctionRef .. ': Engineer assigned=' .. tEngSubtable[refEngineerAssignmentEngineerRef].UnitId .. M27UnitInfo.GetUnitLifetimeCount(tEngSubtable[refEngineerAssignmentEngineerRef]) .. '; UC=' .. GetEngineerUniqueCount(tEngSubtable[refEngineerAssignmentEngineerRef]) .. '; Engineer action=' .. (tEngSubtable[refEngineerAssignmentEngineerRef][refiEngineerCurrentAction] or 'nil'))
                            end
                            if tEngSubtable[refEngineerAssignmentEngineerRef][refbPrimaryBuilder] then
                                oExistingBuilder = tEngSubtable[refEngineerAssignmentEngineerRef]
                            end
                        end
                    end
                end
                if bDebugMessages == true then
                    LOG(sFunctionRef .. ': iExistingEngineersAssigned=' .. iExistingEngineersAssigned .. '; iMaxEngisWanted=' .. iMaxEngisWanted)
                end
                if iExistingEngineersAssigned < iMaxEngisWanted then
                    if bDebugMessages == true then LOG(sFunctionRef..': Want to assign more engis, if action is to buidl factory then will tell engis to assist existing builder. iActionToAssign='..iActionToAssign..'; iExistingEngineersAssigned='..iExistingEngineersAssigned) end
                    local oActionTargetObject = nil
                    if iActionToAssign == refActionBuildPlateauFactory and iExistingEngineersAssigned > 0 then
                        oActionTargetObject = oExistingBuilder
                        if bDebugMessages == true then LOG(sFunctionRef..': Will tell engis to assist existing builder '..oExistingBuilder.UnitId..M27UnitInfo.GetUnitLifetimeCount(oExistingBuilder)) end
                    end
                    if M27Utilities.IsTableEmpty(tActionTargetLocation) then
                        if not(oActionTargetObject) then
                            --Check for part-complete nearby buildings
                            local iCategoryToBuild = GetCategoryToBuildFromAction(iActionToAssign, 1, aiBrain)
                            if bDebugMessages == true then LOG(sFunctionRef..': Dont have an object to assist or a specified location, will see if we have part complete buildings nearby. iActionToAssign='..iActionToAssign..'; iExistingEngineersAssigned='..iExistingEngineersAssigned) end
                            if iCategoryToBuild and (not(iActionToAssign == refActionBuildPlateauMex) or iExistingEngineersAssigned == 0) then

                                local tEngiPosition = oEngineer:GetPosition()
                                local tNearbyBuildings = aiBrain:GetUnitsAroundPoint(iCategoryToBuild, tEngiPosition, 30, 'Ally')
                                if bDebugMessages == true then LOG(sFunctionRef..': Is table of nearby buildings empty='..tostring(M27Utilities.IsTableEmpty(tNearbyBuildings))) end
                                if M27Utilities.IsTableEmpty(tNearbyBuildings) == false then
                                    local oNearbyPartComplete
                                    local iBuildRange = oEngineer:GetBlueprint().Economy.MaxBuildDistance or 5
                                    local iCurDist
                                    local iClosestDist = 1000
                                    for iUnit, oUnit in tNearbyBuildings do
                                        if bDebugMessages == true then LOG(sFunctionRef..': Considering unit '..oUnit.UnitId..M27UnitInfo.GetUnitLifetimeCount(oUnit)..'; fraction complete='..oUnit:GetFractionComplete()..'; Distance='..M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tEngiPosition)..'; Build range='..iBuildRange..'; Unit pathing group='..M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition())..'; PlateauGroup='..iPlateauGroup) end
                                        if oUnit:GetFractionComplete() < 1 then
                                            iCurDist = M27Utilities.GetDistanceBetweenPositions(oUnit:GetPosition(), tEngiPosition)
                                            if iCurDist < iClosestDist and (iCurDist <= iBuildRange or iPlateauGroup == M27MapInfo.GetSegmentGroupOfLocation(M27UnitInfo.refPathingTypeAmphibious, oUnit:GetPosition())) then
                                                iClosestDist = iCurDist
                                                oNearbyPartComplete = oUnit
                                            end
                                        end
                                    end
                                    if oNearbyPartComplete then
                                        oActionTargetObject = oNearbyPartComplete
                                        tActionTargetLocation = oActionTargetObject:GetPosition()
                                        if bDebugMessages == true then LOG(sFunctionRef..': Found part complete building, will tell engi to assist the unit '..oNearbyPartComplete.UnitId..M27UnitInfo.GetUnitLifetimeCount(oNearbyPartComplete)) end
                                    elseif bDebugMessages == true then LOG(sFunctionRef..': Couldnt find part complete building to assist')
                                    end
                                end
                            end
                            if M27Utilities.IsTableEmpty(tActionTargetLocation) then
                                if oActionTargetObject then
                                    tActionTargetLocation = oActionTargetObject:GetPosition()
                                else tActionTargetLocation = oEngineer:GetPosition()
                                end
                            end
                        else
                            tActionTargetLocation = oEngineer:GetPosition()
                        end
                    end

                    --if are building a factory then check if already have engineer assigned, in which case will assist that
                    if bDebugMessages == true then LOG(sFunctionRef..': About to assign '..iActionToAssign..' action to the engineer '..oEngineer.UnitId..M27UnitInfo.GetUnitLifetimeCount(oEngineer)..'; UC='..GetEngineerUniqueCount(oEngineer)) end

                    AssignActionToEngineer(aiBrain, oEngineer, iActionToAssign, tActionTargetLocation, oActionTargetObject, iCurrentConditionToTry)
                end
            end

            if iActionToAssign then
                break
            end
        end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function EngineerInitialisation() end --Done to help find where we declare our variables
function EngineerManager(aiBrain)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'EngineerManager'
    local iLongLoopCount = 0
    local iLongLoopThreshold = 120

    --Initial setup:
    aiBrain[refiInitialMexBuildersWanted] = 2
    aiBrain[refiEngineerCurUniqueReference] = 0
    aiBrain[reftEngineerActionsByEngineerRef] = {}
    aiBrain[reftEngineerAssignmentsByActionRef] = {}
    aiBrain[reftEngineerAssignmentsByLocation] = {}
    aiBrain[refbNeedResourcesForMissile] = false
    aiBrain[refiTimeOfLastEngiSelfDestruct] = 0
    aiBrain[reftEngineersHelpingACU] = {}
    aiBrain[reftUnitsWantingFixedShield] = {}
    aiBrain[reftUnitsWithFixedShield] = {}
    aiBrain[reftFailedShieldLocations] = {}
    aiBrain[refiTimeOfLastFailure] = {}
    aiBrain[refiTimeOfLastAction] = {}
    aiBrain[reftUnclaimedMexOrHydroByCondition] = {}
    aiBrain[reftUnitsWantingTMD] = {}
    aiBrain[reftoTMLTargetsOfInterest] = {}
    --reftUnclaimedMexOrHydroByCondition = 'M27EngUnclaimedMexOrHydroByCondition' --[ConvertUnclaimedConditionsToKey()] - returns a table {reftResourceLocations, refiTimeOfLastUpdate}

    aiBrain[reftiResourceClaimedStatus] = {}
    aiBrain[reftSpareEngineerAttackMoveTimeByLocation] = {}
    aiBrain[refiMassSpentOnPD] = 5 --To avoid infinite loop when dividing by this
    aiBrain[refiMassKilledByPD] = 1 --Avoid infinite loop in case divide by this
    aiBrain[reftFirebaseUnitsByFirebaseRef] = {}
    aiBrain[reftiFirebaseDeadPDMassCost] = {}
    aiBrain[reftiFirebaseDeadPDMassKills] = {}
    aiBrain[reftFirebaseFrontPDPosition] = {}
    aiBrain[reftPriorityShieldsToAssist] = {}




    if bDebugMessages == true then LOG(sFunctionRef..': Start of code') end
    while(not(aiBrain:IsDefeated())) do
        if aiBrain.M27IsDefeated or M27Logic.iTimeOfLastBrainAllDefeated > 10 then break end

        ForkThread(ReassignEngineers, aiBrain, true)
        iLongLoopCount = iLongLoopCount + 1
        if iLongLoopCount >= iLongLoopThreshold then
           iLongLoopCount = 0
            ForkThread(CheckAllEngineerLocations, aiBrain)
        end


        --[[if iLongLoopCount == 0 then
            if bDebugMessages == true then LOG(sFunctionRef..': Doing full refresh of all engineers') end
            --ReassignEngineers(aiBrain, false)
            ForkThread(ReassignEngineers, aiBrain, false)
        else
            if bDebugMessages == true then LOG(sFunctionRef..': Only assigning actions to idle engineers') end
            ForkThread(ReassignEngineers, aiBrain, true)
        end
        iLongLoopCount = iLongLoopCount + 1
        --Had hoped to do a full refresh periodically but causing too many bugs and poor CPU performance
        --if iLongLoopCount >= iLongLoopThreshold then iLongLoopCount = 0 end
        if bDebugMessages == true then LOG(sFunctionRef..': About to wait 10 ticks') end
        --TEMPTEST(aiBrain, sFunctionRef..': Pre wait 10 ticks')
        --]]
        WaitTicks(10)
        if bDebugMessages == true then LOG(sFunctionRef..': End of cycle after waiting 10 ticks') end
        --TEMPTEST(aiBrain, sFunctionRef..': Post wait 10 ticks')

    end
end
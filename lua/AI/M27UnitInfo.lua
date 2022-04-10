---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by maudlin27.
--- DateTime: 09/10/2021 07:26
local BuildingTemplates = import('/lua/BuildingTemplates.lua').BuildingTemplates
local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local M27PlatoonUtilities = import('/mods/M27AI/lua/AI/M27PlatoonUtilities.lua')

refPathingTypeAmphibious = 'Amphibious'
refPathingTypeNavy = 'Water'
refPathingTypeAir = 'Air'
refPathingTypeLand = 'Land'
refPathingTypeNone = 'None'
refPathingTypeAll = {refPathingTypeAmphibious, refPathingTypeNavy, refPathingTypeAir, refPathingTypeLand}

--Special information
--[[refiLastTimeGotDistanceToStart = 'M27UnitDistToStartTime'
refiDistanceToStart = 'M27UnitDistToStartDist'
refiLastTimeGotDistanceToEnemy = 'M27UnitDistToEnemyTime'
refiDistanceToEnemyt = 'M27UnitDistToENemyDist'--]]
refbShieldIsDisabled = 'M27UnitShieldDisabled'
refbSpecialMicroActive = 'M27UnitSpecialMicroActive' --e.g. if dodging bombers
refiGameTimeToResetMicroActive = 'M27UnitGameTimeToResetMicro'
refiGameTimeMicroStarted = 'M27UnitGameTimeMicroStarted'
refbOverchargeOrderGiven = 'M27UnitOverchargeOrderGiven'
refiTimeOfLastOverchargeShot = 'M27UnitOverchargeShotFired' --gametime of actual firing of overcharge shot
refsUpgradeRef = 'M27UnitUpgradeRef' --If ACU starts an upgrade, it records the string reference here
refbPaused = 'M27UnitPaused' --true if paused due to poewr stall manager
refbRecentlyDealtDamage = 'M27UnitRecentlyDealtDamage' --true if dealt damage in last 5s
refiGameTimeDamageLastDealt = 'M27UnitTimeLastDealtDamage'
refoFactoryThatBuildThis = 'M27UnitFactoryThatBuildThis'
refbFullyUpgraded = 'M27UnitFullyUpgraded' --used on ACU to avoid running some checks every time it wants an upgrade
refbRecentlyRemovedHealthUpgrade = 'M27UnitRecentlyRemovedHealthUpgrade' --Used on ACU to flag if e.g. we removed T2 which will decrease our health
refbActiveMissileChecker = 'M27UnitMissileTracker' --True if are actively checking for missile targets
refbActiveSMDChecker = 'M27UnitSMDChecker' -- true if unit is checking for enemy SMD (use on nuke)
refbActiveTargetChecker = 'M27UnitActiveTargetChecker' --e.g. used for T3 fixed arti
refoLastTargetUnit = 'M27UnitLastTargetUnit' --e.g. indirect fire units will update this when given an IssueAttack order
reftAdjacencyPGensWanted = 'M27UnitAdjacentPGensWanted' --Table, [x] = subref: 1 = category wanted; 2 = buildlocation
refiSubrefCategory = 1 --for reftAdjacencyPGensWanted
refiSubrefBuildLocation = 2 --for reftAdjacencyPGensWanted
refiTimeOfLastCheck = 'M27UnitTimeOfLastCheck' --Currently used for T3 arti adjacency and when first detected enemy SMD, but could be used for other things if want

--TMD:
refbTMDChecked = 'M27TMDChecked' --Used against enemy TML to flag if we've already checked for TMD we want when it was first detected
reftTMLDefence = 'M27TMLDefence' --[sTMLRef] - returns either nil if not considered, or the unit object of TMD protecting it
reftTMLThreats = 'M27TMLThreats' --[sTMLRef] - returns object number of TML that is threatening this unit
refbCantBuildTMDNearby = 'M27CantBuildTMDNearby'


--Factions
refFactionUEF = 1
refFactionAeon = 2
refFactionCybran = 3
refFactionSeraphim = 4
refFactionNomads = 5

--Categories:
--Buildings - eco
refCategoryMex = categories.STRUCTURE * categories.MASSEXTRACTION - categories.NAVAL --Some mods add a naval mex which causes issues as we will try and build on land mexes without naval exclusion
refCategoryT1Mex = refCategoryMex * categories.TECH1
refCategoryT2Mex = refCategoryMex * categories.TECH2
refCategoryT3Mex = refCategoryMex * categories.TECH3
refCategoryHydro = categories.HYDROCARBON - categories.NAVAL

refCategoryPower = categories.STRUCTURE * categories.ENERGYPRODUCTION - categories.EXPERIMENTAL - categories.HYDROCARBON
refCategoryT1Power = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH1 - categories.EXPERIMENTAL - categories.HYDROCARBON
refCategoryT2Power = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH2 - categories.EXPERIMENTAL - categories.HYDROCARBON
refCategoryT3Power = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 - categories.EXPERIMENTAL - categories.HYDROCARBON
refCategoryMassStorage = categories.STRUCTURE * categories.MASSSTORAGE * categories.TECH1

refCategoryEnergyStorage = categories.STRUCTURE * categories.ENERGYSTORAGE

--Building - intel and misc
refCategoryAirStaging = categories.STRUCTURE * categories.AIRSTAGINGPLATFORM
refCategoryRadar = categories.STRUCTURE * categories.RADAR + categories.STRUCTURE * categories.OMNI
refCategoryT1Radar = refCategoryRadar * categories.TECH1
refCategoryT2Radar = refCategoryRadar * categories.TECH2
refCategoryT3Radar = refCategoryRadar * categories.TECH3 --+ categories.OMNI * categories.TECH3 (dont need this as refcategoryradar already includes omni)
refCategorySonar = categories.STRUCTURE * categories.SONAR + categories.MOBILESONAR
refCategoryT1Sonar = refCategorySonar * categories.TECH1
refCategoryT2Sonar = refCategorySonar * categories.TECH2
refCategoryT3Sonar = refCategorySonar * categories.TECH3
refCategoryStructure = categories.STRUCTURE - categories.WALL
refCategoryWall = categories.STRUCTURE * categories.WALL --NOTE: Some walls are props; this is for if want a wall that can build
refCategoryUnitsWithOmni = categories.OMNI + categories.COMMAND + categories.OVERLAYOMNI


--Building - factory
refCategoryLandFactory = categories.LAND * categories.FACTORY * categories.STRUCTURE
refCategoryAirFactory = categories.AIR * categories.FACTORY * categories.STRUCTURE - categories.ORBITALSYSTEM --Novax is an air factory, so excluded from being treated as an air factory by my logic
refCategoryNavalFactory = categories.NAVAL * categories.FACTORY * categories.STRUCTURE
refCategoryAllFactories = refCategoryLandFactory + refCategoryAirFactory + refCategoryNavalFactory
refCategoryAllHQFactories = refCategoryAllFactories - categories.SUPPORTFACTORY

--Building - defensive
refCategoryT2PlusPD = categories.STRUCTURE * categories.DIRECTFIRE - categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH1
refCategoryPD = categories.STRUCTURE * categories.DIRECTFIRE
refCategoryT3PD = refCategoryPD * categories.TECH3
refCategoryTMD = categories.STRUCTURE * categories.ANTIMISSILE - categories.SILO * categories.TECH3 --Not perfect but should pick up most TMD without picking up SMD
refCategoryFixedShield = categories.SHIELD * categories.STRUCTURE
refCategoryFixedT2Arti = categories.STRUCTURE * categories.INDIRECTFIRE * categories.ARTILLERY * categories.TECH2
refCategoryFixedT3Arti = categories.STRUCTURE * categories.INDIRECTFIRE * categories.ARTILLERY * categories.TECH3
refCategorySML = categories.NUKE * categories.SILO
refCategorySMD = categories.ANTIMISSILE * categories.SILO * categories.TECH3 * categories.STRUCTURE
refCategoryTML = categories.SILO * categories.STRUCTURE * categories.TECH2 - categories.ANTIMISSILE
refCategoryNovaxCentre = categories.EXPERIMENTAL * categories.STRUCTURE * categories.ORBITALSYSTEM
refCategorySatellite = categories.EXPERIMENTAL * categories.SATELLITE
--refCategorySAM = categories.ANTIAIR * categories.STRUCTURE * categories.TECH3

refCategoryUpgraded = refCategoryT2Radar + refCategoryT3Radar + refCategoryT2Sonar + refCategoryT3Sonar + refCategoryAllFactories * categories.TECH2 + refCategoryAllFactories * categories.TECH3 + refCategoryFixedShield * categories.TECH3 + refCategoryT2Mex + refCategoryT3Mex

--Land units
refCategoryExperimentalStructure = categories.CYBRAN * categories.ARTILLERY * categories.EXPERIMENTAL + categories.STRUCTURE * categories.EXPERIMENTAL
refCategoryLandExperimental = categories.EXPERIMENTAL * categories.MOBILE * categories.LAND - categories.CYBRAN * categories.ARTILLERY - categories.UNSELECTABLE
refCategoryMobileLand = categories.LAND * categories.MOBILE  - categories.UNSELECTABLE
refCategoryEngineer = categories.LAND * categories.MOBILE * categories.ENGINEER - categories.COMMAND - categories.FIELDENGINEER --Dont include sparkys as they cant build a lot of things, so just treat them as a combat unit that can reclaim
refCategoryAttackBot = categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.BOT - categories.ANTIAIR -categories.REPAIR --(repair exclusion added as basic way to differentiate between mantis (which has repair category) and LAB; alternative way is to specify the fastest when choosing the blueprint to build
refCategoryMAA = categories.LAND * categories.MOBILE * categories.ANTIAIR - categories.EXPERIMENTAL
refCategoryDFTank = categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.SCOUT - refCategoryMAA --NOTE: Need to specify slowest (so dont pick LAB)
refCategoryLandScout = categories.LAND * categories.MOBILE * categories.SCOUT
refCategoryCombatScout = categories.SERAPHIM * categories.SCOUT * categories.DIRECTFIRE
refCategoryIndirect = categories.LAND * categories.MOBILE * categories.INDIRECTFIRE - categories.DIRECTFIRE - refCategoryLandExperimental
refCategoryT3MobileArtillery = categories.ARTILLERY * categories.LAND * categories.MOBILE * categories.TECH3
refCategoryT3MML = categories.SILO * categories.MOBILE * categories.TECH3 * categories.LAND
refCategoryLandCombat = categories.MOBILE * categories.LAND * categories.DIRECTFIRE + categories.MOBILE * categories.LAND * categories.INDIRECTFIRE * categories.TECH1 + categories.FIELDENGINEER - refCategoryEngineer -refCategoryLandScout -refCategoryMAA
refCategoryAmphibiousCombat = refCategoryLandCombat * categories.HOVER + refCategoryLandCombat * categories.AMPHIBIOUS - categories.ANTISHIELD * categories.AEON --Dont include aeon T3 anti-shield here as it sucks unless against shields
refCategoryGroundAA = categories.LAND * categories.ANTIAIR + categories.NAVAL * categories.ANTIAIR + categories.STRUCTURE * categories.ANTIAIR
refCategoryStructureAA = categories.STRUCTURE * categories.ANTIAIR
refCategoryIndirectT2Plus = categories.MOBILE * categories.LAND * categories.INDIRECTFIRE - categories.MOBILE * categories.LAND * categories.INDIRECTFIRE * categories.TECH1 - categories.DIRECTFIRE
refCategoryIndirectT2Below = categories.MOBILE * categories.INDIRECTFIRE * categories.LAND * categories.TECH1 + categories.MOBILE * categories.INDIRECTFIRE * categories.LAND * categories.TECH2
refCategoryIndirectT3 = categories.MOBILE * categories.LAND * categories.INDIRECTFIRE * categories.TECH3 - categories.DIRECTFIRE
--Obsidian special case with shields due to inconsistent categories:
refCategoryObsidian = categories.AEON * categories.TECH2 * categories.SHIELD * categories.DIRECTFIRE * categories.MOBILE * categories.LAND * categories.TANK --
refCategoryMobileLandShield = categories.LAND * categories.MOBILE * categories.SHIELD - refCategoryObsidian --Miscategorised obsidian tank
refCategoryPersonalShield = categories.PERSONALSHIELD + refCategoryObsidian
refCategoryFatboy = categories.EXPERIMENTAL * categories.UEF * categories.MOBILE * categories.LAND * categories.ARTILLERY
refCategorySniperBot = categories.MOBILE * categories.SNIPER * categories.LAND

--Air units
refCategoryAirScout = categories.AIR * categories.SCOUT
refCategoryAirAA = categories.AIR * categories.ANTIAIR - categories.BOMBER - categories.GROUNDATTACK
refCategoryBomber = categories.AIR * categories.BOMBER - categories.ANTINAVY - categories.CANNOTUSEAIRSTAGING --excludes mercies
refCategoryFighterBomber = categories.AIR * categories.ANTIAIR * categories.BOMBER
refCategoryGunship = categories.AIR * categories.GROUNDATTACK
refCategoryTorpBomber = categories.AIR * categories.BOMBER * categories.ANTINAVY
refCategoryAllAir = categories.MOBILE * categories.AIR - categories.UNTARGETABLE --Excludes novax
refCategoryAllNonExpAir = categories.MOBILE * categories.AIR * categories.TECH1 + categories.MOBILE * categories.AIR * categories.TECH2 + categories.MOBILE * categories.AIR * categories.TECH3
refCategoryAirNonScout = refCategoryAllAir - categories.SCOUT
refCategoryMercy = categories.HIGHPRIAIR * categories.AEON * categories.BOMBER * categories.TECH2

--Naval units
refCategoryFrigate = categories.NAVAL * categories.FRIGATE
refCategoryNavalSurface = categories.NAVAL - categories.SUBMERSIBLE
refCategoryAllNavy = categories.NAVAL
refCategoryCruiser = categories.NAVAL * categories.CRUISER
refCategoryCruiserCarrier = refCategoryCruiser + categories.NAVAL * categories.NAVALCARRIER
refCategoryAllAmphibiousAndNavy = categories.NAVAL + categories.AMPHIBIOUS + categories.HOVER + categories.STRUCTURE --NOTE: Structures have no category indicating whether they can be built on sea (instead they have aquatic ability) hence the need to include all structures
refCategoryNavyThatCanBeTorpedoed = categories.NAVAL + categories.AMPHIBIOUS + categories.STRUCTURE --NOTE: Structures have no category indicating whether they can be built on sea (instead they have aquatic ability) hence the need to include all structures; Hover units cant be targeted
refCategoryTorpedoLandAndNavy = categories.ANTINAVY * categories.LAND + categories.ANTINAVY * categories.NAVAL + categories.OVERLAYANTINAVY * categories.LAND --If removing overlayantinavy then think up better solution for fatboy/experimentals so they dont run when in water

--Multi-category:
--Antinavy mobile units (can include land units - e.g for land factories to build antisub units)
refCategoryAntiNavy = categories.ANTINAVY * categories.STRUCTURE + categories.ANTINAVY * categories.MOBILE --for some reason get error message if just use antinavy, so need to be more restrictive
--Dangerous to land units, e.g. engieners look for these when deciding reclaim area
refCategoryDangerousToLand = refCategoryLandCombat + refCategoryIndirect + refCategoryAllNavy + refCategoryBomber + refCategoryGunship + refCategoryPD + refCategoryFixedT2Arti
refCategoryAllNonAirScoutUnits = categories.MOBILE + refCategoryStructure + refCategoryAirNonScout
refCategoryStealthGenerator = categories.STEALTHFIELD
refCategoryStealthAndCloakPersonal = categories.STEALTH
refCategoryProtectFromTML = refCategoryT2Mex + refCategoryT3Mex + refCategoryT2Power + refCategoryT3Power + refCategoryFixedT2Arti
refCategoryExperimentalLevel = categories.EXPERIMENTAL + refCategoryFixedT3Arti + refCategorySML

--Weapon target priorities
refWeaponPriorityACU = {categories.COMMAND, refCategoryMobileLandShield, refCategoryFixedShield, refCategoryPD, refCategoryLandCombat, categories.MOBILE, refCategoryStructure - categories.BENIGN}
refWeaponPriorityNormal = {refCategoryMobileLandShield, refCategoryFixedShield, refCategoryPD, refCategoryLandCombat - categories.COMMAND, refCategoryEngineer, categories.LAND * categories.MOBILE, refCategoryStructure - categories.BENIGN}
refWeaponPriorityOurGroundExperimental = {categories.COMMAND, refCategoryLandExperimental, categories.EXPERIMENTAL, refCategoryFixedT2Arti, refCategoryT3PD, refCategoryPD, refCategoryFixedShield, refCategoryLandCombat * categories.TECH3, refCategoryStructure - categories.TECH1, refCategoryLandCombat, categories.MOBILE, refCategoryStructure - categories.BENIGN}
refWeaponPriorityOurFatboy = {refCategoryFixedShield, refCategoryFixedT2Arti, refCategoryLandExperimental, categories.EXPERIMENTAL, refCategoryT3PD, refCategoryPD, categories.COMMAND, refCategoryLandCombat * categories.TECH3, refCategoryStructure - categories.TECH1, refCategoryLandCombat, categories.MOBILE, refCategoryStructure - categories.BENIGN}


function GetUnitLifetimeCount(oUnit)
    local sCount = oUnit.M27LifetimeUnitCount

    if sCount == nil then
        if oUnit.GetAIBrain and oUnit.GetUnitId then
            local aiBrain = oUnit:GetAIBrain()
            local sUnitId = oUnit.UnitId
            if aiBrain.M27LifetimeUnitCount == nil then aiBrain.M27LifetimeUnitCount = {} end
            if aiBrain.M27LifetimeUnitCount[sUnitId] == nil then
                aiBrain.M27LifetimeUnitCount[sUnitId] = 1
            else aiBrain.M27LifetimeUnitCount[sUnitId] = aiBrain.M27LifetimeUnitCount[sUnitId] + 1 end
            sCount = aiBrain.M27LifetimeUnitCount[sUnitId]
            oUnit.M27LifetimeUnitCount = sCount
        else
            sCount = 'nil'
        end
    end
    return sCount
end

function GetBlueprintIDFromBuildingType(buildingType, tBuildingTemplate)
    --Returns blueprintID based on buildingType and buildingTemplate; buildingTemplate should be series of tables containing the building types and blueprint IDs for a particular faction
    for Key, Data in tBuildingTemplate do
        if Data[1] == buildingType and Data[2] then
            return Data[2]
        end
    end
end

function GetBlueprintIDFromBuildingTypeAndFaction(buildingType, iFactionNumber)
    --Returns the BlueprintID for a building type and faction number (see the BuildingTemplates lua file for a list of all building types)
    --To get iFactionNumber use e.g. factionIndex = aiBrain:GetFactionIndex()
    --1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
    --Alternatively could get faction of a unit, using the FactionName = 'Aeon' property
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if bDebugMessages == true then LOG('About to print out entire building template:'..repr(BuildingTemplates)) end
    local tBuildingTemplateForFaction = BuildingTemplates[iFactionNumber]
    return GetBlueprintIDFromBuildingType(buildingType, tBuildingTemplateForFaction)
end

function GetFactionFromBP(oBlueprint)
    --Returns faction number for oBlueprint
    --1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads, 6 = not recognised
    --Note: General.FactionName property uses lowercase for some factions; the categories.x uses upper case
    --Assumed nomads is Nomads

    local tFactionsByName = {'UEF', 'Aeon', 'Cybran', 'Seraphim', 'Nomads'}
    local sUnitFactionName = oBlueprint.General.FactionName
    for iName, sName in tFactionsByName do
        if sName == sUnitFactionName then return iName end
    end
    return 6
end

function GetBlueprintFromID(sBlueprintID)
    --returns blueprint based on the blueprintID
    return __blueprints[string.lower(sBlueprintID)]
end

function GetUnitFaction(oUnit)
    ----1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads, 6 = not recognised
    return GetFactionFromBP(oUnit:GetBlueprint())
end

function GetBuildingSize(BlueprintID)
    --Returns table with X and Z size of sBlueprintID
    local tSizeXZ = {}
    local oBlueprint = GetBlueprintFromID(BlueprintID)
    tSizeXZ[1] = oBlueprint.Physics.SkirtSizeX
    tSizeXZ[2] = oBlueprint.Physics.SkirtSizeZ
    return tSizeXZ
end

function GetUnitPathingType(oUnit)
    --Returns Land, Amphibious, Air or Water or None
    if oUnit and not(oUnit.Dead) and oUnit.GetBlueprint then
        local mType = oUnit:GetBlueprint().Physics.MotionType
        if (mType == 'RULEUMT_AmphibiousFloating' or mType == 'RULEUMT_Hover' or mType == 'RULEUMT_Amphibious') then
            return refPathingTypeAmphibious
        elseif (mType == 'RULEUMT_Water' or mType == 'RULEUMT_SurfacingSub') then
            return refPathingTypeNavy
        elseif mType == 'RULEUMT_Air' then
            return refPathingTypeAir
        elseif (mType == 'RULEUMT_Biped' or mType == 'RULEUMT_Land') then
            return refPathingTypeLand
        else return refPathingTypeNone
        end
    else
        M27Utilities.ErrorHandler('oUnit is nil or doesnt have a GetBlueprint function')
    end
end

function GetUnitUpgradeBlueprint(oUnitToUpgrade, bGetSupportFactory)
    --Returns support factory ID if it can be built, otherwise returns normal upgrade unit (works for any unit, not just factory)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetUnitUpgradeBlueprint'

    if bGetSupportFactory == nil then bGetSupportFactory = true end
    --Gets the support factory blueprint, and checks if it can be built; if not then returns the normal UpgradesTo blueprint
    local sUpgradeBP
    if not(oUnitToUpgrade.Dead) and oUnitToUpgrade.CanBuild then
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code, UnitToUpgrade='..oUnitToUpgrade.UnitId..GetUnitLifetimeCount(oUnitToUpgrade)) end
        if bGetSupportFactory == true and oUnitToUpgrade.CanBuild then
            local tsSupportFactoryBP = {

                -- Aeon
                ['uab0101']  = 'zab9501',
                ['uab0102']  = 'zab9502',
                ['uab0103']  = 'zab9503',
                ['uab0201'] = 'zab9601',
                ['uab0202'] = 'zab9602',
                ['uab0203'] = 'zab9603',

                -- UEF
                ['ueb0101']  = 'zeb9501',
                ['ueb0102']  = 'zeb9502',
                ['ueb0103']  = 'zeb9503',
                ['ueb0201'] = 'zeb9601',
                ['ueb0202'] = 'zeb9602',
                ['ueb0203'] = 'zeb9603',

                -- Cybran
                ['urb0101']  = 'zrb9501',
                ['urb0102']  = 'zrb9502',
                ['urb0103']  = 'zrb9503',
                ['urb0201'] = 'zrb9601',
                ['urb0202'] = 'zrb9602',
                ['urb0203'] = 'zrb9603',

                -- Seraphim
                ['xsb0101']  = 'zsb9501',
                ['xsb0102']  = 'zsb9502',
                ['xsb0103']  = 'zsb9503',
                ['xsb0201'] = 'zsb9601',
                ['xsb0202'] = 'zsb9602',
                ['xsb0203'] = 'zsb9603',
            }

            local sFactoryBP = oUnitToUpgrade.UnitId
            if tsSupportFactoryBP[sFactoryBP] then
                if bDebugMessages == true then LOG(sFunctionRef..': Support factoryBP='..tsSupportFactoryBP[sFactoryBP]) end
                sUpgradeBP = tsSupportFactoryBP[sFactoryBP]
                if bDebugMessages == true then LOG(sFunctionRef..': oUnitToUpgrade='..sFactoryBP..GetUnitLifetimeCount(oUnitToUpgrade)..'; Checking if can upgrade to sUpgradeBP='..sUpgradeBP..'; oUnitToUpgrade:CanBuild(sUpgradeBP)='..tostring(oUnitToUpgrade:CanBuild(sUpgradeBP))) end
                if not(oUnitToUpgrade:CanBuild(sUpgradeBP)) then
                    if bDebugMessages == true then LOG(sFunctionRef..': Cant build '..sUpgradeBP) end
                    sUpgradeBP = nil
                end
            end
        end
        if not(sUpgradeBP) then
            local oFactoryBP = oUnitToUpgrade:GetBlueprint()
            sUpgradeBP = oFactoryBP.General.UpgradesTo
            if bDebugMessages == true then LOG(sFunctionRef..': sUpgradeBP='..(sUpgradeBP or 'nil')) end
            if not(sUpgradeBP) or not(oUnitToUpgrade:CanBuild(sUpgradeBP)) then sUpgradeBP = nil end
            if bDebugMessages == true then LOG(sFunctionRef..': Didnt have valid support factory to upgrade to; blueprint UpgradesTo='..(sUpgradeBP or 'nil')) end
        end
        if sUpgradeBP == '' then
            sUpgradeBP = nil
            if bDebugMessages == true then LOG(sFunctionRef..': Have no blueprint to upgrade to') end
        elseif bDebugMessages == true then LOG(sFunctionRef..': Returning sUpgradeBP'..(sUpgradeBP or 'nil'))
        end
    end

    return sUpgradeBP
end

function IsUnitUnderwaterAmphibious(oUnit)
    local oUnitBP = oUnit:GetBlueprint()
    local bIsUnderwater = false
    if oUnitBP.Physics and oUnitBP.Physics.MotionType then
        if oUnitBP.Physics.MotionType == 'RULEUMT_Amphibious' then
            bIsUnderwater = true
        end
    end
    return bIsUnderwater
end

function GetUnitIDTechLevel(sUnitId)
    local iTechLevel = 1
    if EntityCategoryContains(categories.TECH1, sUnitId) then iTechLevel = 1
    elseif EntityCategoryContains(categories.TECH2, sUnitId) then iTechLevel = 2
    elseif EntityCategoryContains(categories.TECH3, sUnitId) then iTechLevel = 3
    elseif EntityCategoryContains(categories.EXPERIMENTAL, sUnitId) then iTechLevel = 4
    end
    return iTechLevel
end

function GetUnitTechLevel(oUnit)
    local sUnitId = oUnit.UnitId
    local iTechLevel = 1
    if EntityCategoryContains(categories.TECH1, sUnitId) then iTechLevel = 1
    elseif EntityCategoryContains(categories.TECH2, sUnitId) then iTechLevel = 2
    elseif EntityCategoryContains(categories.TECH3, sUnitId) then iTechLevel = 3
    elseif EntityCategoryContains(categories.EXPERIMENTAL, sUnitId) then iTechLevel = 4
    end
    return iTechLevel
end

function ConvertTechLevelToCategory(iTechLevel)
    if iTechLevel == 2 then return categories.TECH2
    elseif iTechLevel == 3 then return categories.TECH3
    elseif iTechLevel == 4 then return categories.EXPERIMENTAL
    else return categories.TECH1
    end
end

function GetUnitStrikeDamage(oUnit)
    --Gets strike damage of the first weapon in oUnit (longer term might want to make better so it considers other weapons)
    --For bombers will be subject to a minimum value as some bombers will have
    local oBP = oUnit:GetBlueprint()
    local sBP = oUnit.UnitId
    local iStrikeDamage = 0


    if EntityCategoryContains(refCategoryBomber, sBP) then
        --Doublecheck strike damage based on if it references a bomb
        local iAOE
        iAOE, iStrikeDamage = GetBomberAOEAndStrikeDamage(oUnit)
    elseif oBP.Weapon and oBP.Weapon[1] then
        iStrikeDamage = oBP.Weapon[1].Damage
    end
    return iStrikeDamage
end

function IsUnitUnderwater(oUnit)
    if oUnit.GetPosition and oUnit.GetBlueprint then
        return M27MapInfo.IsUnderwater({oUnit:GetPosition()[1], oUnit:GetPosition()[2] + (oUnit:GetBlueprint().SizeY or 0), oUnit:GetPosition()[3]}, false)
    else return false
    end
end

function IsUnitOnOrUnderWater(oUnit)
    if M27MapInfo.GetSegmentGroupOfLocation(refPathingTypeLand, oUnit:GetPosition()) == M27MapInfo.iLandPathingGroupForWater then
        return true
    else return false
    end
end

function IsEnemyUnitAnEngineer(aiBrain, oEnemyUnit)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsEnemyUnitAnEngineer'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local bIsEngineer = true
    local iEnemySpeed
    if oEnemyUnit.GetUnitId then

        local sEnemyID = oEnemyUnit.UnitId

        if EntityCategoryContains(categories.STRUCTURE, sEnemyID) then bIsEngineer = false
        else
            --function CanSeeUnit(aiBrain, oUnit, bTrueIfOnlySeeBlip)
            if M27Utilities.CanSeeUnit(aiBrain, oEnemyUnit, false) then
                if not(EntityCategoryContains(refCategoryEngineer, sEnemyID)) then bIsEngineer = false end
            else
                local oEnemyBP = oEnemyUnit:GetBlueprint()
                if oEnemyBP.Physics then
                    iEnemySpeed = oEnemyBP.Physics.MaxSpeed
                    if not(iEnemySpeed == 1.9) then bIsEngineer = false end
                end
             end
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Checking if oEnemyUnit with ID='..sEnemyID..' is an engineer; bIsEngineer='..tostring(bIsEngineer)..'; iEnemySpeed if we have calculated it='..(iEnemySpeed or 'nil')) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return bIsEngineer
end

function GetACUShieldRegenRate(oUnit)
    --Cycles through every possible enhancement, sees if the unit has it, and if so what its shield regen rate is, and returns the max value
    local iRegenRate = 0
    for sEnhancement, tEnhancement in oUnit:GetBlueprint().Enhancements do
        if oUnit:HasEnhancement(sEnhancement) and tEnhancement.ShieldRegenRate then
            iRegenRate = math.max(iRegenRate, tEnhancement.ShieldRegenRate)
        end
    end
    return iRegenRate
end

function GetCurrentAndMaximumShield(oUnit)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetCurrentAndMaximumShield'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    local iCurShield = 0
    local iMaxShield = 0
    if oUnit.MyShield then
        iCurShield = oUnit.MyShield:GetHealth()
        iMaxShield = oUnit.MyShield:GetMaxHealth()
    else
        local tShield = oUnit:GetBlueprint().Defense
        if tShield then
            iCurShield = (oUnit:GetShieldRatio(false) or 0) * iMaxShield
        end
    end
    if iCurShield > 0 then
        --GetHealth doesnt look like it factors in power stall
        if oUnit:GetAIBrain():GetEconomyStored('ENERGY') == 0 then iCurShield = 0 end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef..': iCurShield='..iCurShield..'; iMaxShield='..iMaxShield..'; ShieldRatio False='..oUnit:GetShieldRatio(false)..'; ShieldRatio true='..oUnit:GetShieldRatio(true)..' iCurShield='..iCurShield)
        if oUnit.MyShield then LOG('Unit has MyShield; IsUp='..tostring(oUnit.MyShield:IsUp())..'; shield health='..oUnit.MyShield:GetHealth()) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
    return iCurShield, iMaxShield
end

--Below commented out because after profiling, the time savings are negligible so doesnt justify the loss of accuracy
--[[function GetUnitDistanceFromOurStart(aiBrain, oUnitOrPlatoon)
    --Intended to only be called once every cycle
    local iCurTime = math.floor(GetGameTimeSeconds())
    if oUnitOrPlatoon[refiLastTimeGotDistanceToStart] == iCurTime then return oUnitOrPlatoon[refiDistanceToStart]
    else
        oUnitOrPlatoon[refiLastTimeGotDistanceToStart] = iCurTime
        local tPosition = M27PlatoonUtilities.GetPlatoonFrontPosition(oUnitOrPlatoon)
        return M27Utilities.GetDistanceBetweenPositions(tPosition, M27MapInfo.PlayerStartPoints[aiBrain.M27StartPositionNumber])
    end
end

function GetUnitDistanceFromOurEnemy(aiBrain, oUnit)  end--]]
function IsUnitShieldEnabled(oUnit)
    return not(oUnit[refbShieldIsDisabled])
end
function DisableUnitShield(oUnit)
    oUnit[refbShieldIsDisabled] = true
    oUnit:DisableShield()
end
function EnableUnitShield(oUnit)
    oUnit:EnableShield()
    oUnit[refbShieldIsDisabled] = false
end

function DisableUnitIntel(oUnit)
    --[[
    if oUnit.DisableUnitIntel then
        oUnit:DisableUnitIntel('ToggleBit3', 'Sonar')
        oUnit:DisableUnitIntel('ToggleBit3', 'Omni')
        oUnit:DisableUnitIntel('ToggleBit3', 'Radar')
    end--]]
    oUnit:OnScriptBitSet(3)
end
function EnableUnitIntel(oUnit)
    --[[if oUnit.EnableUnitIntel then
        oUnit:EnableUnitIntel('ToggleBit3', 'Sonar')
        oUnit:EnableUnitIntel('ToggleBit3', 'Omni')
        oUnit:EnableUnitIntel('ToggleBit3', 'Radar')
    end--]]
    oUnit:OnScriptBitClear(3)
end

function DisableUnitJamming(oUnit)
    --[[if oUnit.DisableUnitIntel then
        oUnit:DisableUnitIntel('ToggleBit3', 'Jammer')
    end--]]
    oUnit:OnScriptBitSet(2)
end
function EnableUnitJamming(oUnit)
    --if oUnit.EnableUnitIntel then oUnit:EnableUnitIntel('ToggleBit3', 'Jammer') end
    oUnit:OnScriptBitClear(2)
end

function DisableUnitStealth(oUnit)
    --[[if oUnit.DisableUnitIntel then
        oUnit:DisableUnitIntel('ToggleBit3', 'RadarStealth')--]]

    --[[oUnit:OnScriptBitSet(5) --stealth
    oUnit:OnScriptBitSet(8) --cloak--]]
    oUnit:SetScriptBit('RULEUTC_StealthToggle', true)
    oUnit:SetScriptBit('RULEUTC_CloakToggle', true)
end

function EnableUnitStealth(oUnit)
    --[[oUnit:OnScriptBitClear(5)
    oUnit:OnScriptBitClear(8)
    oUnit:EnableUnitIntel('ToggleBit3', 'RadarStealth')--]]
    oUnit:SetScriptBit('RULEUTC_StealthToggle', false)
    oUnit:SetScriptBit('RULEUTC_CloakToggle', false)
end


function GetUnitFacingAngle(oUnit)
    --0/360 = north, 90 = west, 180 = south, 270 = east
    return 180 - oUnit:GetHeading() / math.pi * 180
end

function IsUnitValid(oUnit, bMustBeComplete)
    --Returns true if unit is constructed and not dead
    --Note - if get error in this that arises from getting threat value of units, then check we're sending a table to the threat value function rather than a single unit
    if not(oUnit) or oUnit.Dead or not(oUnit.GetFractionComplete) or not(oUnit.GetUnitId) or not(oUnit.GetBlueprint) or not(oUnit.GetAIBrain) then return false
    else
        if bMustBeComplete and oUnit:GetFractionComplete() < 1 then return false
        else
            return true
        end
    end
end

function SetUnitTargetPriorities(oUnit, tPriorityTable)
    if IsUnitValid(oUnit) then
        for i =1, oUnit:GetWeaponCount() do
            local wep = oUnit:GetWeapon(i)
            wep:SetWeaponPriorities(tPriorityTable)
        end
    end
end

function GetUnitAARange(oUnit)
    local iMaxRange = 0
    for iCurWeapon, oCurWeapon in oUnit:GetBlueprint().Weapon do
        if oCurWeapon.WeaponCategory == 'Anti Air' then
            if not(oCurWeapon.ManualFire == true) then
                if oCurWeapon.MaxRadius > iMaxRange then iMaxRange = oCurWeapon.MaxRadius end
            end
        end
    end
    return iMaxRange
end

function GetUnitIndirectRange(oUnit)

    local iMaxRange = 0
    if oUnit.GetBlueprint then
        for iCurWeapon, oCurWeapon in oUnit:GetBlueprint().Weapon do
            if oCurWeapon.WeaponCategory == 'Missile' or oCurWeapon.WeaponCategory == 'Artillery' or oCurWeapon.WeaponCategory == 'Indirect Fire' then
                if oCurWeapon.MaxRadius > iMaxRange then iMaxRange = oCurWeapon.MaxRadius end
            end
        end
    end
    return iMaxRange
end

function GetUpgradeBuildTime(oUnit, sUpgradeRef)
    --Returns nil if unit cant get enhancements
    local oBP = oUnit:GetBlueprint()
    local iUpgradeTime
    if oBP.Enhancements then
        for sUpgradeID, tUpgrade in oBP.Enhancements do
            if sUpgradeID == sUpgradeRef then
                iUpgradeTime = tUpgrade.BuildTime
            end

        end
    end
    return iUpgradeTime
end

function GetUpgradeEnergyCost(oUnit, sUpgradeRef)
    local oBP = oUnit:GetBlueprint()
    local iUpgradeEnergy
    for sUpgradeID, tUpgrade in oBP.Enhancements do
        if sUpgradeID == sUpgradeRef then
            iUpgradeEnergy = tUpgrade.BuildCostEnergy
        end

    end
    if not(iUpgradeEnergy) then M27Utilities.ErrorHandler('oUnit '..oUnit.UnitId..GetUnitLifetimeCount(oUnit)..' has no upgrade with reference '..sUpgradeRef) end
    return iUpgradeEnergy
end

function GetBomberAOEAndStrikeDamage(oUnit)
    local oBP = oUnit:GetBlueprint()
    local iAOE = 0
    local iStrikeDamage = 0
    for sWeaponRef, tWeapon in oBP.Weapon do
        if tWeapon.WeaponCategory == 'Bomb' or tWeapon.WeaponCategory == 'Direct Fire' then
            if (tWeapon.DamageRadius or 0) > iAOE then
                iAOE = tWeapon.DamageRadius
                iStrikeDamage = tWeapon.Damage * tWeapon.MuzzleSalvoSize
            end
        end
    end
    if iStrikeDamage == 0 then
        M27Utilities.ErrorHandler('Couldnt identify strike damage for bomber '..oUnit.UnitId..GetUnitLifetimeCount(oUnit)..'; will refer to predefined value instead')
    end

    --Manual floor for strike damage due to complexity of some bomber calculations
    --Check if manual override is higher, as some weapons will fire lots of shots so above method wont be accurate
    local tiBomberStrikeDamageByFactionAndTech =
    {
        --UEF, Aeon, Cybran, Sera, Nomads (are using default), Default
        { 125, 200, 125, 250, 150, 150 }, --Tech 1
        { 350, 300, 850, 1175, 550, 550 }, --Tech 2
        { 2500, 2500, 2500, 2500, 2500, 2500}, --Tech 3 - the strike damage calculation above should be accurate so this is just as a backup, and set at a low level due to potential for more balance changes affecting this
        { 11000,11000,11000,11000,11000,11000} --Tech 4 - again as a backup
    }
    iStrikeDamage = math.max(iStrikeDamage, tiBomberStrikeDamageByFactionAndTech[GetUnitTechLevel(oUnit)][GetFactionFromBP(oBP)])


    return iAOE, iStrikeDamage
end

function GetLauncherAOEStrikeDamageMinAndMaxRange(oUnit)
    local oBP = oUnit:GetBlueprint()
    local iAOE = 0
    local iStrikeDamage
    local iMinRange = 0
    local iMaxRange = 0
    for sWeaponRef, tWeapon in oBP.Weapon do
        if not(tWeapon.WeaponCategory == 'Death') then
            if (tWeapon.DamageRadius or 0) > iAOE then
                iAOE = tWeapon.DamageRadius
                iStrikeDamage = tWeapon.Damage * tWeapon.MuzzleSalvoSize
            elseif (tWeapon.NukeInnerRingRadius or 0) > iAOE then
                iAOE = tWeapon.NukeInnerRingRadius
                iStrikeDamage = tWeapon.NukeInnerRingDamage
            end
            if (tWeapon.MinRadius or 0) > iMinRange then iMinRange = tWeapon.MinRadius end
            if (tWeapon.MaxRadius or 0) > iMaxRange then iMaxRange = tWeapon.MaxRadius end
        end
    end
    return iAOE, iStrikeDamage, iMinRange, iMaxRange
end

function GetBomberRange(oUnit)
    local oBP = oUnit:GetBlueprint()
    local iRange = 0
    for sWeaponRef, tWeapon in oBP.Weapon do
        if tWeapon.WeaponCategory == 'Bomb' or tWeapon.WeaponCategory == 'Direct Fire' or tWeapon.WeaponCategory == 'Anti Navy' then
            if (tWeapon.MaxRadius or 0) > iRange then
                iRange = tWeapon.MaxRadius
            end
        end
    end
    return iRange
end

function BomberMultiAttackMuzzle(oUnit)
    --Done to help with searching
    return DoesBomberFireSalvo(oUnit)
end
function DoesBomberFireSalvo(oUnit)
    local oBP = oUnit:GetBlueprint()
    for sWeaponRef, tWeapon in oBP.Weapon do
        if tWeapon.WeaponCategory == 'Bomb' or tWeapon.WeaponCategory == 'Direct Fire' or tWeapon.WeaponCategory == 'Anti Navy' then
            if tWeapon.MuzzleSalvoSize == 1 then
                return false
            else return true
            end
        end
    end
end

function PauseOrUnpauseEnergyUsage(aiBrain, oUnit, bPauseNotUnpause)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'PauseOrUnpauseEnergyUsage'
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)


    --Jamming - check via blueprint since no reliable category
    local oBP = oUnit:GetBlueprint()
    if oBP.Intel.JamRadius then
        if bPauseNotUnpause then DisableUnitJamming(oUnit)
        else EnableUnitJamming(oUnit)
        end
    end
    
    --Want to pause unit, check for any special logic for pausing
    local bWasUnitPaused = (oUnit[refbPaused] or false)
    oUnit[refbPaused] = bPauseNotUnpause
    if oUnit.MyShield and oUnit.MyShield:GetMaxHealth() > 0 then
        if IsUnitShieldEnabled(oUnit) == bPauseNotUnpause then
            if bPauseNotUnpause then DisableUnitShield(oUnit)
            else EnableUnitShield(oUnit) end
        end
    elseif oBP.Intel.ReactivateTime and (oBP.Intel.SonarRadius or oBP.Intel.RadarRadius) then
        if bPauseNotUnpause then DisableUnitIntel(oUnit)
        else EnableUnitIntel(oUnit)
        end
    elseif oBP.Intel.Cloak or oBP.Intel.RadarStealth or oBP.Intel.RadarStealthFieldRadius then
        if bPauseNotUnpause then DisableUnitStealth(oUnit)
        else EnableUnitStealth(oUnit)
        end
    else
        --Normal logic - just pause unit
        oUnit:SetPaused(bPauseNotUnpause)
        if bDebugMessages == true then LOG(sFunctionRef..': Just set paused to '..tostring(bPauseNotUnpause)) end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)

end

function GetNumberOfUpgradesObtained(oACU)
    --Returns the number of upgrades a unit (e.g. ACU) has got
    local iUpgradeCount = 0
    for sEnhancement, tEnhancement in oACU:GetBlueprint().Enhancements do
        if oACU:HasEnhancement(sEnhancement) and tEnhancement.BuildCostMass > 1 then
            iUpgradeCount = iUpgradeCount + 1
        end
    end
    return iUpgradeCount
end
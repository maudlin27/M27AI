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

--Factions
refFactionUEF = 1
refFactionAeon = 2
refFactionCybran = 3
refFactionSeraphim = 4
refFactionNomads = 5

--Categories:
--Buildings - eco
refCategoryT1Mex = categories.STRUCTURE * categories.TECH1 * categories.MASSEXTRACTION
refCategoryT2Mex = categories.STRUCTURE * categories.TECH2 * categories.MASSEXTRACTION
refCategoryT3Mex = categories.STRUCTURE * categories.TECH3 * categories.MASSEXTRACTION
refCategoryMex = categories.STRUCTURE * categories.MASSEXTRACTION
refCategoryHydro = categories.HYDROCARBON
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


--Building - factory
refCategoryLandFactory = categories.LAND * categories.FACTORY * categories.STRUCTURE
refCategoryAirFactory = categories.AIR * categories.FACTORY * categories.STRUCTURE
refCategoryNavalFactory = categories.NAVAL * categories.FACTORY * categories.STRUCTURE
refCategoryAllFactories = refCategoryLandFactory + refCategoryAirFactory + refCategoryNavalFactory

--Building - defensive
refCategoryT2PlusPD = categories.STRUCTURE * categories.DIRECTFIRE - categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH1
refCategoryPD = categories.STRUCTURE * categories.DIRECTFIRE
refCategoryTMD = categories.ANTIMISSILE - categories.SILO * categories.TECH3 --Not perfect but should pick up most TMD without picking up SMD
refCategoryFixedShield = categories.SHIELD * categories.STRUCTURE
refCategoryFixedT2Arti = categories.STRUCTURE * categories.INDIRECTFIRE * categories.ARTILLERY * categories.TECH2
refCategoryFixedT3Arti = categories.STRUCTURE * categories.INDIRECTFIRE * categories.ARTILLERY * categories.TECH3
refCategorySML = categories.NUKE * categories.SILO
refCategorySMD = categories.ANTIMISSILE * categories.SILO * categories.TECH3 * categories.STRUCTURE
refCategoryTML = categories.SILO * categories.STRUCTURE * categories.TECH2 - categories.ANTIMISSILE
--refCategorySAM = categories.ANTIAIR * categories.STRUCTURE * categories.TECH3

--Land units
refCategoryMobileLand = categories.LAND * categories.MOBILE
refCategoryEngineer = categories.LAND * categories.MOBILE * categories.ENGINEER - categories.COMMAND
refCategoryAttackBot = categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.BOT - categories.ANTIAIR --NOTE: Need to specify fastest (for cybran who have mantis and LAB)
refCategoryDFTank = categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.SCOUT - categories.ANTIAIR --NOTE: Need to specify slowest (so dont pick LAB)
refCategoryLandScout = categories.LAND * categories.MOBILE * categories.SCOUT
refCategoryMAA = categories.LAND * categories.MOBILE * categories.ANTIAIR
refCategoryIndirect = categories.LAND * categories.MOBILE * categories.INDIRECTFIRE - categories.DIRECTFIRE
refCategoryLandCombat = categories.MOBILE * categories.LAND * categories.DIRECTFIRE + categories.MOBILE * categories.LAND * categories.INDIRECTFIRE * categories.TECH1 - refCategoryEngineer -refCategoryLandScout -refCategoryMAA
refCategoryAmphibiousCombat = refCategoryLandCombat * categories.HOVER + refCategoryLandCombat * categories.AMPHIBIOUS
refCategoryGroundAA = categories.LAND * categories.ANTIAIR + categories.NAVAL * categories.ANTIAIR + categories.STRUCTURE * categories.ANTIAIR
refCategoryStructureAA = categories.STRUCTURE * categories.ANTIAIR
refCategoryIndirectT2Plus = categories.MOBILE * categories.LAND * categories.INDIRECTFIRE - categories.MOBILE * categories.LAND * categories.INDIRECTFIRE * categories.TECH1 - categories.DIRECTFIRE
refCategoryGroundExperimental = categories.LAND * categories.EXPERIMENTAL + categories.STRUCTURE * categories.EXPERIMENTAL
--Obsidian special case with shields due to inconsistent categories:
refCategoryObsidian = categories.AEON * categories.TECH2 * categories.SHIELD * categories.DIRECTFIRE * categories.MOBILE * categories.LAND * categories.TANK --
refCategoryMobileLandShield = categories.LAND * categories.MOBILE * categories.SHIELD - refCategoryObsidian --Miscategorised obsidian tank
refCategoryPersonalShield = categories.PERSONALSHIELD + refCategoryObsidian

--Air units
refCategoryAirScout = categories.AIR * categories.SCOUT
refCategoryAirAA = categories.AIR * categories.ANTIAIR - categories.BOMBER - categories.GROUNDATTACK
refCategoryBomber = categories.AIR * categories.BOMBER - categories.ANTINAVY - categories.CANNOTUSEAIRSTAGING --excludes mercies
refCategoryTorpBomber = categories.AIR * categories.BOMBER * categories.ANTINAVY
refCategoryAllAir = categories.MOBILE * categories.AIR - categories.UNTARGETABLE --Excludes novax
refCategoryAllNonExpAir = categories.MOBILE * categories.AIR * categories.TECH1 + categories.MOBILE * categories.AIR * categories.TECH2 + categories.MOBILE * categories.AIR * categories.TECH3
refCategoryAirNonScout = refCategoryAllAir - categories.SCOUT

--Naval units
refCategoryFrigate = categories.NAVAL * categories.FRIGATE
refCategoryNavalSurface = categories.NAVAL - categories.SUBMERSIBLE
refCategoryAllNavy = categories.NAVAL
refCategoryCruiserCarrier = categories.NAVAL * categories.CRUISER + categories.NAVAL * categories.NAVALCARRIER
refCategoryAllAmphibiousAndNavy = categories.NAVAL + categories.AMPHIBIOUS + categories.HOVER + categories.STRUCTURE --NOTE: Structures have no category indicating whether they can be built on sea (instead they have aquatic ability) hence the need to include all structures
refCategoryTorpedoLandAndNavy = categories.ANTINAVY * categories.LAND + categories.ANTINAVY * categories.NAVAL


--Weapon target priorities
refWeaponPriorityACU = {categories.COMMAND, refCategoryMobileLandShield, refCategoryFixedShield, refCategoryPD, refCategoryLandCombat, categories.MOBILE, categories.STRUCTURE}
refWeaponPriorityNormal = {refCategoryMobileLandShield, refCategoryFixedShield, refCategoryPD, refCategoryLandCombat, categories.MOBILE, categories.STRUCTURE}

function GetUnitLifetimeCount(oUnit)
    local sCount = oUnit.M27LifetimeUnitCount

    if sCount == nil then
        if oUnit.GetAIBrain and oUnit.GetUnitId then
            local aiBrain = oUnit:GetAIBrain()
            local sUnitId = oUnit:GetUnitId()
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
    if not(oUnitToUpgrade.Dead) then
        if bDebugMessages == true then LOG(sFunctionRef..': Start of code, UnitToUpgrade='..oUnitToUpgrade:GetUnitId()..GetUnitLifetimeCount(oUnitToUpgrade)) end
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

            local sFactoryBP = oUnitToUpgrade:GetUnitId()
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

function GetUnitTechLevel(oUnit)
    local sUnitId = oUnit:GetUnitId()
    local iTechLevel = 1
    if EntityCategoryContains(categories.TECH1, sUnitId) then iTechLevel = 1
    elseif EntityCategoryContains(categories.TECH2, sUnitId) then iTechLevel = 2
    elseif EntityCategoryContains(categories.TECH3, sUnitId) then iTechLevel = 3
    elseif EntityCategoryContains(categories.EXPERIMENTAL, sUnitId) then iTechLevel = 4
    end
    return iTechLevel
end

function GetUnitStrikeDamage(oUnit)
    --Gets strike damage of the first weapon in oUnit (longer term might want to make better so it considers other weapons)
    --For bombers will be subject to a minimum value as some bombers will have
    local oBP = oUnit:GetBlueprint()
    local sBP = oUnit:GetUnitId()
    local iStrikeDamage = 0

    if oBP.Weapon and oBP.Weapon[1] then
        iStrikeDamage = oBP.Weapon[1].Damage
    end

    if EntityCategoryContains(refCategoryBomber, sBP) then
        --Check if manual override is higher, as some weapons will fire lots of shots so above method wont be accurate
        local iFaction = GetFactionFromBP(oBP)
        local iTech = GetUnitTechLevel(oUnit)
        local tiBomberStrikeDamageByFactionAndTech =
        {
            --UEF, Aeon, Cybran, Sera, Nomads (are using default), Default
            { 125, 200, 125, 250, 150, 150 }, --Tech 1
            { 350, 1, 850, 1175, 550, 550 }, --Tech 2
            { 2500, 2500, 2500, 2500, 2500, 2500}, --Tech 3 - the strike damage calculation above should be accurate so this is just as a backup, and set at a low level due to potential for more balance changes affecting this
            { 11000,11000,11000,11000,11000,11000} --Tech 4 - again as a backup
        }
        iStrikeDamage = math.max(iStrikeDamage, tiBomberStrikeDamageByFactionAndTech[iTech][iFaction])


    end
    return iStrikeDamage
end

function IsUnitUnderwater(oUnit)
    return M27MapInfo.IsUnderwater(oUnit:GetPosition(), false)
end

function IsEnemyUnitAnEngineer(aiBrain, oEnemyUnit)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'IsEnemyUnitAnEngineer'
    local bIsEngineer = true
    local iEnemySpeed
    if oEnemyUnit.GetUnitId then

        local sEnemyID = oEnemyUnit:GetUnitId()

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
    return bIsEngineer
end

function GetCurrentAndMaximumShield(oUnit)
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    local sFunctionRef = 'GetCurrentAndMaximumShield'
    local iCurShield = 0
    local iMaxShield = 0
    if oUnit.MyShield then
        iCurShield = oUnit.MyShield:GetHealth()
        iMaxShield = oUnit.MyShield:GetMaxHealth()
    else
        local tShield = oUnit:GetBlueprint().Defense
        if tShield then
            local iCurShield = (oUnit:GetShieldRatio(false) or 0) * iMaxShield
        end
    end
    if bDebugMessages == true then
        LOG(sFunctionRef..': iCurShield='..iCurShield..'; iMaxShield='..iMaxShield..'; ShieldRatio False='..oUnit:GetShieldRatio(false)..'; ShieldRatio true='..oUnit:GetShieldRatio(true)..' iCurShield='..iCurShield)
        if oUnit.MyShield then LOG('Unit has MyShield; IsUp='..tostring(oUnit.MyShield:IsUp())..'; shield health='..oUnit.MyShield:GetHealth()) end
    end
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

function GetUnitFacingAngle(oUnit)
    --0/360 = north, 90 = west, 180 = south, 270 = east
    return 180 - oUnit:GetHeading() / math.pi * 180
end

function IsUnitValid(oUnit)
    --Returns true if unit is constructed and not dead
    if not(oUnit.GetUnitId) or oUnit.Dead or not(oUnit.GetFractionComplete) or oUnit:GetFractionComplete() < 1 or not(oUnit.GetBlueprint) then return false else return true end
end

function SetUnitTargetPriorities(oUnit, tPriorityTable)
    if IsUnitValid(oUnit) then
        for i =1, oUnit:GetWeaponCount() do
            local wep = oUnit:GetWeapon(i)
            wep:SetWeaponPriorities(tPriorityTable)
        end
    end
end
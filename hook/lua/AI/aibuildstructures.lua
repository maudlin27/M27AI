--[[local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
--local M27MapInfo = import('/mods/M27AI/lua/AI/M27MapInfo.lua')
--local M27ConUtility = import('/mods/M27AI/lua/AI/M27ConstructionUtilities.lua')
--local M27EngineerOverseer = import('/mods/M27AI/lua/AI/M27EngineerOverseer.lua')
local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')


--Not sure if any of the below are used, but left in as e.g. might want for future debugging/hooks and just in case part of my code uses this
M27AIExecuteBuildStructure = AIExecuteBuildStructure

local M27AddToBuildQueue = AddToBuildQueue
function AddToBuildQueue(aiBrain, builder, whatToBuild, buildLocation, relative)
    --Hook of code - so that can add debuging if wanted; below will also have a reclaim size of 8 before building

    if not(aiBrain.M27AI) then
        M27AddToBuildQueue(aiBrain, builder, whatToBuild, buildLocation, relative)
    else
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        --repeat of core code, but with log added for debugging:
        if not builder.EngineerBuildQueue then
            builder.EngineerBuildQueue = {}
        end
        -- put in build queue.. but will be removed afterwards... just so that it can iteratively find new spots to build
        if aiBrain.Sorian then
            AIUtils.EngineerTryReclaimCaptureAreaSorian(aiBrain, builder, BuildToNormalLocation(buildLocation))
        else
            AIUtils.EngineerTryReclaimCaptureArea(aiBrain, builder, BuildToNormalLocation(buildLocation))
        end

        if bDebugMessages == true then LOG('About to send build structure command') end
            --Below log removed to help stop desyncs
            --LOG(tostring(aiBrain:BuildStructure(builder, whatToBuild, buildLocation, true)))
        aiBrain:BuildStructure(builder, whatToBuild, buildLocation, false)

        local newEntry = {whatToBuild, buildLocation, relative}
        if bDebugMessages==true then LOG('7 Adding to BuildQueue: whatToBuild='..tostring(whatToBuild)..'; buildLocation='..buildLocation[1]..'-'..buildLocation[2]..'-'..buildLocation[3]) end
        table.insert(builder.EngineerBuildQueue, newEntry)
    end
end--]]

function M27BuildStructureAtLocation(oBuilder, sBuildingType, tBuildLocation)
    --Custom function - will no doubt want to expand at some point to add some of the checks in the core AI logic
    local aiBrain = oBuilder:GetAIBrain()
    local oBuilderBP = oBuilder:GetBlueprint()
    local iBuilderFaction = M27UnitInfo.GetFactionFromBP(oBuilderBP)
    local sBuildingBlueprintID = M27UnitInfo.GetBlueprintIDFromBuildingTypeAndFaction(sBuildingType, iBuilderFaction)
    --MoveNearConstruction(aiBrain, oBuilder, tLocation, sBlueprintID, iBuildDistanceMod, bReturnMovePathInstead)
    AddToBuildQueue(aiBrain, oBuilder, sBuildingBlueprintID, NormalToBuildLocation(tBuildLocation), false)
end

function M27BuildStructureDirectAtLocation(oBuilder, sBuildingType, tBuildLocation)
    --Bypasses the normal AI logic and just issues a build command
    --sBuildingType - e.g. 'T1Resource' - i.e. as per the normal AIBuilders references
    local aiBrain = oBuilder:GetAIBrain()
    local oBuilderBP = oBuilder:GetBlueprint()
    local iBuilderFaction = M27UnitInfo.GetFactionFromBP(oBuilderBP)
    local sBuildingBlueprintID = M27UnitInfo.GetBlueprintIDFromBuildingTypeAndFaction(sBuildingType, iBuilderFaction)
    --either of the below 2 work
    --aiBrain:BuildStructure(oBuilder, sBuildingBlueprintID, NormalToBuildLocation(tBuildLocation), false)
    IssueBuildMobile({oBuilder}, tBuildLocation, sBuildingBlueprintID, {})
end

--[[function AIExecuteBuildStructure(aiBrain, builder, buildingType, closeToBuilder, relative, buildingTemplate, baseTemplate, reference, NearMarkerType)
    -- aiBrain - various functions that can be used for this, including aiBrain:GetArmyStartPos()
    -- builder - error message suggests it's a table value, but doesn't return anything using log; however builder.UnitId returns a string with the unit blueprint ID, e.g. ual0001 is the aeon ACU
        --Other functions: builder:getarmy(); builder:GetPosition()
    -- buildingType is a string, e.g. 'T1LandFactory'
    -- buildingTemplate is a table value, containing table values, which gives the blueprint in question, so baseTemplate[i1][i2]
        -- if loop through i, v in buildinTemplate, and then loop through i2, v2 in v, then the first i2 value will be the name grouping/type (e.g. Experimental, T1EnergyProduction), the second i2 value will be the blueprint (e.g. uaa0310, uab1101)
        -- the table in question only appears to contain the options for the faction in question
    -- baseTemplate is a table value, containing table values, which contain table values; these appear to contain co-ordinates, i.e. the relative co-ordinates to try and build the building in question
        -- i1 is the first list of buildings (i.e. if looking at the orig template file it's grouped by faction, then by buildings, then co-ordinates - this template is already filtered to just pick the relevant faction)
        -- i2 is then 1 for the name of the building grouping, with i3 cycling between each building type included in the grouping.  for i2=2 it is then the c-ordinates, with i3 = 1, 2 and 3 for the coordinates
    -- relative is true or false; guessing true means the buildingTemplate co-ordinates are treated as relative co-ordinates
    -- reference is true or false - not sure what this will impact

    -- If not using M27AI run default function:
    if not aiBrain.M27AI then
        return M27AIExecuteBuildStructure(aiBrain, builder, buildingType, closeToBuilder, relative, buildingTemplate, baseTemplate, reference, NearMarkerType)
    else
        local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
        local sFunctionRef = 'aiBuildStructures'
        M27Utilities.ErrorHandler('Not an error but I want to move away from using this function - this is to highlight if I have any code still using this that I have missed')
        if builder and not(builder.Dead) then
            local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
            -- M27AI - initially a copy of the original code, so that tweaks can be added
            if bDebugMessages == true then LOG('* M27AI: aibuildstructures.lua: Hook successful') end

            --Convert buildingType to a blueprint:
            if bDebugMessages == true then
                for Key, Data in buildingTemplate do
                    if Data[1] == buildingType and Data[2] then
                        LOG('*AIExecuteBuildStructure: Found template: '..repru(Data[1])..' - Using UnitID: '..repru(Data[2]))
                    end
                end
            end
            -- ---------------------------------------------
            -- Below includes (in comments) various code for returning values relating to these variables, for future reference
            -- Commented out functions to record some of the variables to understand what they relate to:

            -- Record values in this:
            if bDebugMessages == true then LOG('M27AI: aibuildstructures.lua: buildingType='..buildingType) end
            if bDebugMessages == true then LOG('IsACU(builder.UnitId)='..tostring(M27Utilities.IsACU(builder))) end
            -- local army = builder:GetArmy()
            -- local BuilderPosition = builder:GetPosition()
            -- LOG('GetPosition='..BuilderPosition[1])
            -- if closeToBuilder ~= nil then
            -- LOG('closeToBuilder='..closeToBuilder)
            -- end
            -- LOG('relative='..tostring(relative))
            -- LOG('reference='..tostring(reference))
            -- if NearMarkerType ~= nil then
            -- LOG('NearMarkerType'..NearMarkerType)
            -- end
            -- for i, v in ipairs(buildingTemplate) do
            -- v is a table value so the below cycles through the options:
            -- for i2, v2 in ipairs(v) do
            -- LOG('buildingTemplate i='..i..'; i2='..i2..'v2='..v2)
            -- end
            -- end
            -- NOTE: The below log will cause massive slowdown/crash for 10-20s due to the amount of data being printed
            -- for i, v in ipairs(baseTemplate) do
            -- for i2, v2 in ipairs(v) do
            -- for i3, v3 in ipairs(v2) do
            -- LOG('baseTemplate i='..i..'; i2='..i2..'; i3='..i3..'v3='..v3..'; ')
            -- end
            -- end
            -- end
            -- ---------------------------------------------

            --Check if are building a unit where have special code to determine location:
            local bSpecialBehaviour = false
            local relativeLoc = {}
            if bDebugMessages == true then LOG('builder.UnitId='..tostring(builder.UnitId)) end

            if buildingType == 'T1LandFactory' or buildingType == 'T1EnergyProduction' then
                -- Check if it's an ACU building it
                --if M27Utilities.IsACU(builder) == true then
                -- Check if the builder is near the start position:
                local builderPos = builder:GetPosition()
                local iBuildDistance = builder:GetBlueprint().Economy.MaxBuildDistance
                local iPlayerStartPosition = aiBrain.M27StartPositionNumber --M27Utilities.GetAIBrainArmyNumber(aiBrain)
                if M27Utilities.IsTableEmpty(builderPos) == true then
                    M27Utilities.ErrorHandler('builderPos is empty')
                else
                    local iDistFromStart = 0
                    if M27Utilities.IsTableEmpty(M27MapInfo.PlayerStartPoints[iPlayerStartPosition]) == true then
                        M27Utilities.ErrorHandler('Player start point is empty, will assume are at start position')
                        if iPlayerStartPosition == nil then M27Utilities.ErrorHandler('Re prev error, the player start position is nil') end
                    else
                        iDistFromStart = M27Utilities.GetDistanceBetweenPositions(builderPos, M27MapInfo.PlayerStartPoints[iPlayerStartPosition])
                    end
                    if bDebugMessages == true then LOG('M27AI aibuildstructures.lua: ACU distance from start is' ..tostring(iDistFromStart)..'; ACU iBuildDistance='..iBuildDistance) end
                    local tBuildAdjacentTo = nil
                    local sBuildingTypeToBuildBy

                    if buildingType == 'T1LandFactory' then
                        sBuildingTypeToBuildBy = 'T1Resource'
                        if iDistFromStart <= iBuildDistance then
                            --Use start location for building reference
                            --First try and find a build location that benefits from mex adjacency:
                            if bDebugMessages == true then LOG('aibuildstructures: Near start area - looking for nearby mexes to build on') end
                            --M27Utilities.DrawLocations(M27MapInfo.tResourceNearStart[iPlayerStartPosition][1], nil, 1, 50, false)
                            tBuildAdjacentTo = M27MapInfo.tResourceNearStart[iPlayerStartPosition][1]
                            -- M27Utilities.DrawLocations(NewLocations, { 0,0,0 }, 2)
                        else
                            --T1 factory but not v.close to start
                            if bDebugMessages == true then LOG('aibuildstructures: Outside start area - looking for nearby mexes to build on') end
                            tBuildAdjacentTo = M27MapInfo.GetResourcesNearTargetLocation(builderPos, 30, true)
                        end
                    elseif buildingType == 'T1EnergyProduction' then
                        --GetOwnedUnitsAroundPoint(aiBrain, iCategoryCondition, tTargetPos, iSearchRange)
                        tBuildAdjacentTo = M27Utilities.GetAllUnitPositions(M27Utilities.GetOwnedUnitsAroundPoint(aiBrain, categories.STRUCTURE * categories.FACTORY - categories.NAVAL, builderPos, iBuildDistance + 4 + 2))
                        --LOG('tBuildAdjacentTo for T1Energy='..tBuildAdjacentTo[1][1]..'-'..tBuildAdjacentTo[1][2]..'-'..tBuildAdjacentTo[1][3])
                        sBuildingTypeToBuildBy = 'T1LandFactory' --This is used to determine the size of the building, so should work whether dealing with land or air fac                         --function GetAllCategoryUnitsNearPosition(aibrain, unitCategory,                        lLocation, i   Distance,           bHostile)
                    end

                    if tBuildAdjacentTo == nil or tBuildAdjacentTo[1] == nil then
                        if bDebugMessages == true then LOG('aibuildstructures: No units to build adjacent to') end
                    else
                        local sBuildAdjacentToBP = M27UnitInfo.GetBlueprintIDFromBuildingType(sBuildingTypeToBuildBy, buildingTemplate)
                        if bDebugMessages == true then LOG(sFunctionRef..': sBuildAdjacentToBP = '..sBuildAdjacentToBP) end
                        local sToBuildBP = M27UnitInfo.GetBlueprintIDFromBuildingType(buildingType, buildingTemplate)
                        if bDebugMessages == true then LOG(sFunctionRef..': sToBuildBP = '..sToBuildBP) end
                        local bBuildNearToEnemy = true
                        if iDistFromStart >= 80 then bBuildNearToEnemy = false end
                        local bBuildAwayFromEnemy = not(bBuildNearToEnemy)
                        --GetBestBuildLocationForTarget(tablePosTarget, sTargetBuildingBPID, sNewBuildingBPID, bCheckValid, aiBrain, bReturnOnlyBestMatch, pBuilderPos, iMaxAreaToSearch, iBuilderRange, bIgnoreOutsideBuildArea, bBetterIfNoReclaim, bPreferCloseToEnemy, bPreferFarFromEnemy, bLookForQueuedBuildings)
                        relativeLoc = M27EngineerOverseer.GetBestBuildLocationForTarget(tBuildAdjacentTo, sBuildAdjacentToBP, sToBuildBP, true, aiBrain, true, builderPos, iBuildDistance, iBuildDistance, false, true, bBuildNearToEnemy, bBuildAwayFromEnemy)

                        if relativeLoc == nil or relativeLoc[1] == nil then
                            --Do nothing
                            if bDebugMessages == true then LOG('aibuildstructures: relativeLoc is nil - use default buildTemplate') end
                        else
                            if bDebugMessages == true then LOG('1 relativeLoc is valid, ='..relativeLoc[1]..'-'..relativeLoc[2]..'-'..relativeLoc[3]) end
                            bSpecialBehaviour = true
                        end
                    end

                    --Notes from when were using baseTemplate rather than just jumping straight to determining relativeLoc - only relevant if want to use baseTemplate appraoch in the future:

                    -- If want to test out specific co-ordinates, comment out the baseTemplate = ... above, and make use of the following:
                    -- local TempTable = {}
                    --TempTable[1] = { -10, 0, -10 }
                    --TempTable[2] = { -10, 0, -9 }
                    -- TempTable[1] = { 2, 0, -10 }
                    --TempTable[1] = { 4, 0, -12 }
                    --baseTemplate = M27Utilities.ConvertLocationsToBuildTemplate({'T1LandFactory'},TempTable)
                end
            elseif buildingType == 'T1HydroCarbon' then
                if bDebugMessages == true then LOG('GetUnitId for builder='..tostring(builder.UnitId)) end
                M27ConUtility.RecordHydroConstructor(aiBrain, builder)
                if bDebugMessages == true then LOG('Have just recorded hydro constroctor engineer; UnitID='..M27ConUtility.tHydroBuilder[M27Utilities.GetAIBrainArmyNumber(aiBrain)][1].UnitId) end
            end


            local factionIndex = aiBrain:GetFactionIndex()
            local whatToBuild = aiBrain:DecideWhatToBuild( builder, buildingType, buildingTemplate)
            -- if we can't decide, we build NOTHING
            if not whatToBuild then
                return
            end

            if bSpecialBehaviour == true then
                if bDebugMessages == true then LOG('aiBuildStructures: About to add to build queue; whatToBuild='..whatToBuild..'; relativeLoc='..repru(relativeLoc)) end
                AddToBuildQueue(aiBrain, builder, whatToBuild, NormalToBuildLocation(relativeLoc), false)
                return
            else
                --Normal code:


                -- #find a place to build it (ignore enemy locations if it's a resource)
                -- build near the base the engineer is part of, rather than the engineer location
                local relativeTo
                if closeToBuilder then
                    relativeTo = closeToBuilder:GetPosition()
                elseif builder.BuilderManagerData and builder.BuilderManagerData.EngineerManager then
                    relativeTo = builder.BuilderManagerData.EngineerManager:GetLocationCoords()
                else
                    local startPosX, startPosZ = aiBrain:GetArmyStartPos()
                    relativeTo = {startPosX, 0, startPosZ}
                end
                local location = false
                if IsResource(buildingType) then
                    location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, baseTemplate, relative, closeToBuilder, 'Enemy', relativeTo[1], relativeTo[3], 5)
                else
                    if bSpecialBehaviour == false then
                        location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, baseTemplate, relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
                    else
                        location = baseTemplate[1][2]
                    end
                end
                -- if it's a reference, look around with offsets
                if not location and reference then
                    for num,offsetCheck in RandomIter({1,2,3,4,5,6,7,8}) do
                        if bDebugMessages == true then LOG('3 looking for nearby reference as not location') end
                        location = aiBrain:FindPlaceToBuild( buildingType, whatToBuild, BaseTmplFile['MovedTemplates'..offsetCheck][factionIndex], relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
                        if location then
                            break
                        end
                    end
                end

                -- if we have a location, build!
                -- if bSpecialBehaviour == true then location = builder:GetPosition() end
                if location then
                    if bSpecialBehaviour == false then
                        relativeLoc = BuildToNormalLocation(location) --converts {a b c} to {a c b}; buildTemplate is {x z y}
                        if bDebugMessages == true then LOG('4 location[1]-[2]-[3]='..location[1]..'-'..location[2]..'-'..location[3]..'; relativeLoc='..relativeLoc[1]..'-'..relativeLoc[2]..'-'..relativeLoc[3]..'; relativeTo='..relativeTo[1]..'-'..relativeTo[2]..'-'..relativeTo[3]..'; bSpecialBehaviour='..tostring(bSpecialBehaviour)) end
                        if relative then
                            if bDebugMessages == true then LOG('5 relative is true, changing relativeLoc') end
                            relativeLoc = {relativeLoc[1] + relativeTo[1], relativeLoc[2] + relativeTo[2], relativeLoc[3] + relativeTo[3]}
                        end
                    end
                    -- put in build queue.. but will be removed afterwards... just so that it can iteratively find new spots to build
                    if bDebugMessages == true then LOG('6 now AddToBuildQueue; relativeLoc='..relativeLoc[1]..'-'..relativeLoc[2]..'-'..relativeLoc[3]) end
                    --Extra custom code - move near construction:
                    --MoveNearConstruction(aiBrain, builder, relativeLoc, whatToBuild)
                    AddToBuildQueue(aiBrain, builder, whatToBuild, NormalToBuildLocation(relativeLoc), false)
                    return
                end
            end
            -- otherwise, we're SOL, so move on to the next thing
        end

    end --not aiBrain.M27AI
end--]]


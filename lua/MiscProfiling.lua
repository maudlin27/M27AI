local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by maudlin27.
--- DateTime: 03/12/2021 14:53
---

--Below code from Balthazaar - to be included in blueprints.lua hook - to help identify redundant categories
--[[function GetCategoryStats(all_bbps)
--    local allCategories = {}
--    for id, bp in all_bbps do
--        if bp.Categories then
--            --table.insert(bp.Categories, 'GRIDBASEDMOTION')
--            for i, cat in bp.Categories do
--                allCategories[cat] = (allCategories[cat] or 0) + 1
--            end
--        end
--    end
--    _ALERT(repr(allCategories))
--end--]]

--Alterantive - originally used with __blueprints - it gave numbers that looked to be double what they should be; therefore tried using Balthazaar's approach above, gave same result, so must just be blueprints file that list things multiple times
function ListCategoriesUsedByCount(tAllBlueprints)
    local sFunctionRef = 'ListCategoriesUsedByCount'
    local tCategoryUsage = {}

    LOG(sFunctionRef..': About to list category usage')
    if tAllBlueprints == nil then tAllBlueprints = __blueprints end

    local tIDOnlyOnce = {}
    local sCurID
    for iBP, oBP in tAllBlueprints do
        if oBP.Categories then
            sCurID = oBP.BlueprintId
            if tIDOnlyOnce[sCurID] == nil then
                tIDOnlyOnce[sCurID] = true
                local tOnlyListOnce = {}
                for iCat, sCat in oBP.Categories do
                    if tOnlyListOnce[sCat] == nil then
                        tCategoryUsage[sCat] = (tCategoryUsage[sCat] or 0) + 1
                        tOnlyListOnce[sCat] = true
                    end
                end
            end
        end
    end
    for iCategory, iCount in M27Utilities.SortTableByValue(tCategoryUsage, true) do
        LOG(iCategory..': '..iCount)
    end

    --List units with lowest count
    local iLowCountThreshold = 2
    local tUnitsWithLowUsageCategories = {}
    local sCurRef
    tIDOnlyOnce = {}
    for iBP, oBP in tAllBlueprints do
        if oBP.Categories then
            sCurID = oBP.BlueprintId
            if tIDOnlyOnce[sCurID] == nil then
                tIDOnlyOnce[sCurID] = true
                sCurRef = sCurID..': '..(oBP.General.UnitName or 'nil name')
                local tOnlyListOnce = {}

                for iCat, sCat in oBP.Categories do
                    if tCategoryUsage[sCat] <= iLowCountThreshold then
                        if tOnlyListOnce[sCat] == nil then
                            tOnlyListOnce[sCat] = true
                            if tUnitsWithLowUsageCategories[sCurRef] then table.insert(tUnitsWithLowUsageCategories[sCurRef], 1, sCat) else tUnitsWithLowUsageCategories[sCurRef] = {sCat} end
                        end
                    end
                end
            end
        end
    end
    LOG(repr(tUnitsWithLowUsageCategories))
end
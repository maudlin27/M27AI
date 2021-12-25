local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local SUtils = import('/lua/AI/sorianutilities.lua')


function SendSuicideMessage(aiBrain)
    --See the taunt.lua for a full list of taunts

    aiBrain.LastVocTaunt = GetGameTimeSeconds()
    local iFactionIndex = aiBrain:GetFactionIndex()
    local tTauntsByFaction = {
        [M27UnitInfo.refFactionUEF] = {7,22}, --Hall: I guess it’s time to end this farce; Fletcher: Theres no stopping me
        [M27UnitInfo.refFactionAeon] = {28, 38}, --For the Aeon!; My time is wasted on you
        [M27UnitInfo.refFactionCybran] = {82, 84}, --If you destroy this ACU, another shall rise in its place. I am endless.; My time is wasted on you
        [M27UnitInfo.refFactionSeraphim] = {82, 94}, --If you destroy this ACU...'; Do not fret. Dying by my hand is the supreme honor
        [M27UnitInfo.refFactionNomads] = {82} --If you destroy this ACU...;
    }
    local iTauntOptions
    local iTauntTableRef
    local sTauntChatCode = 82
    if M27Utilities.IsTableEmpty(tTauntsByFaction[iFactionIndex]) == false then
        iTauntOptions = table.getn(tTauntsByFaction[iFactionIndex])
        iTauntTableRef = math.random(1, iTauntOptions)
        sTauntChatCode = tTauntsByFaction[iFactionIndex][iTauntTableRef]
    end

    SUtils.AISendChat('all', aiBrain.Nickname, '/'..sTauntChatCode) --QAI I cannot be defeated.

end

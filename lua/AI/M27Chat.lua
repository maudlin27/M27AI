local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local SUtils = import('/lua/AI/sorianutilities.lua')

tiM27VoiceTauntByType = {} --[x] = string for the type of voice taunt (functionref), returns gametimeseconds it was last issued

function SendSuicideMessage(aiBrain)
    --See the taunt.lua for a full list of taunts
    local sFunctionRef = 'SendSuicideMessage'
    if GetGameTimeSeconds() - (tiM27VoiceTauntByType[sFunctionRef] or -10000) > 60 then

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
        tiM27VoiceTauntByType[sFunctionRef] = GetGameTimeSeconds()
    end
end

function SendGloatingMessage(aiBrain, iOptionalDelay, iOptionalTimeBetweenTaunts)
    --Sends a taunt message after waiting iOptionalDelay, provided we havent sent one within 60s or iOptionalTimeBetweenTaunts
    local sFunctionRef = 'SendGloatingMessage'
    local bDebugMessages = true if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if iOptionalDelay then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitSeconds(iOptionalDelay)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    end
    if bDebugMessages == true then LOG(sFunctionRef..': iOptionalTimeBetweenTaunts='..(iOptionalTimeBetweenTaunts or 'nil')..'; tiM27VoiceTauntByType[sFunctionRef]='..(tiM27VoiceTauntByType[sFunctionRef] or 'nil')..'; Cur game time='..GetGameTimeSeconds()) end

    if GetGameTimeSeconds() - (tiM27VoiceTauntByType[sFunctionRef] or -10000) > (iOptionalTimeBetweenTaunts or 60) then
        local iFactionIndex = aiBrain:GetFactionIndex()
        local tTauntsByFaction = {
            [M27UnitInfo.refFactionUEF] = {4,16}, --Hall: The gloves are coming off; Fletcher: I feel a bit bad, beatin' up on you like this
            [M27UnitInfo.refFactionAeon] = {26, 30}, --Rhiza: All enemies of the Princess will be destroyed; Behold the power of the Illuminate
            [M27UnitInfo.refFactionCybran] = {58, 81}, --Dostya: Observe. You may learn something; QAI: All calculations indicate that your demise is near
            [M27UnitInfo.refFactionSeraphim] = {98}, --Sera: You will perish at my hand
            [M27UnitInfo.refFactionNomads] = {81} --QAI: All calculations indicate that your demise is near
        }
        local iTauntOptions
        local iTauntTableRef
        local sTauntChatCode = 81
        if M27Utilities.IsTableEmpty(tTauntsByFaction[iFactionIndex]) == false then
            iTauntOptions = table.getn(tTauntsByFaction[iFactionIndex])
            iTauntTableRef = math.random(1, iTauntOptions)
            sTauntChatCode = tTauntsByFaction[iFactionIndex][iTauntTableRef]
        end
        if bDebugMessages == true then LOG(sFunctionRef..': Will send chat with taunt code '..sTauntChatCode) end

        SUtils.AISendChat('all', aiBrain.Nickname, '/'..sTauntChatCode)

        tiM27VoiceTauntByType[sFunctionRef] = GetGameTimeSeconds()
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end


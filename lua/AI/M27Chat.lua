local M27UnitInfo = import('/mods/M27AI/lua/AI/M27UnitInfo.lua')
local M27Utilities = import('/mods/M27AI/lua/M27Utilities.lua')
local SUtils = import('/lua/AI/sorianutilities.lua')
local M27Team = import('/mods/M27AI/lua/AI/M27Team.lua')
local M27Overseer = import('/mods/M27AI/lua/AI/M27Overseer.lua')

tiM27VoiceTauntByType = {} --[x] = string for the type of voice taunt (functionref), returns gametimeseconds it was last issued
bConsideredSpecificMessage = false --set to true by any AI
bSentSpecificMessage = false

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

        LOG(sFunctionRef..': Sent chat message '..sTauntChatCode) --Log so in replays can see if this triggers since chat doesnt show properly
        SUtils.AISendChat('all', aiBrain.Nickname, '/'..sTauntChatCode) --QAI I cannot be defeated.
        tiM27VoiceTauntByType[sFunctionRef] = GetGameTimeSeconds()
    end
end

function SendForkedGloatingMessage(aiBrain, iOptionalDelay, iOptionalTimeBetweenTaunts)
    --Call via sendgloatingmessage
    --Sends a taunt message after waiting iOptionalDelay, provided we havent sent one within 60s or iOptionalTimeBetweenTaunts
    local sFunctionRef = 'SendForkedGloatingMessage'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
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
            [M27UnitInfo.refFactionUEF] = {1,4,7,16}, --Hall: You will not stop the UEF; The gloves are coming off; I guess its time to end this farce, Fletcher: I feel a bit bad, beatin' up on you like this
            [M27UnitInfo.refFactionAeon] = {26, 28, 30,39,40,41}, --Rhiza: All enemies of the Princess will be destroyed; For the Aeon; Behold the power of the Illuminate; run while you can; it must be frustrating to be so completely overmatched; beg for mercy
            [M27UnitInfo.refFactionCybran] = {58, 59, 60, 62, 74, 77, 78, 79, 81}, --Dostya: Observe. You may learn something; I would flee if I were you; You will be just another in my list of victories; Your defeat is without question; QAI: Your destruction is 99% certain; My victory is without question; Your defeat can be the only outcome; Your efforts are futile; All calculations indicate that your demise is near
            [M27UnitInfo.refFactionSeraphim] = {94,97,98}, --Sera: Do not fret. Dying by my hand is the supreme honor; Bow down before our might, and we may spare you; You will perish at my hand
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

        LOG(sFunctionRef..': Sent chat message '..sTauntChatCode) --Log so in replays can see if this triggers since chat doesnt show properly
        SUtils.AISendChat('all', aiBrain.Nickname, '/'..sTauntChatCode)

        tiM27VoiceTauntByType[sFunctionRef] = GetGameTimeSeconds()
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function SendGloatingMessage(aiBrain, iOptionalDelay, iOptionalTimeBetweenTaunts)
    ForkThread(SendForkedGloatingMessage, aiBrain, iOptionalDelay, iOptionalTimeBetweenTaunts)
end

function SendForkedMessage(aiBrain, sMessageType, sMessage, iOptionalDelayBeforeSending, iOptionalTimeBetweenMessageType, bOnlySendToTeam)
    --Use SendMessage rather than this

    --If just sending a message rather than a taunt then can use this. sMessageType will be used to check if we have sent similar messages recently with the same sMessageType
    --if bOnlySendToTeam is true then will both only consider if message has been sent to teammates before (not all AI), and will send via team chat
    local sFunctionRef = 'SendForkedMessage'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    --Do we have allies?
    if not(bOnlySendToTeam) or M27Utilities.IsTableEmpty(aiBrain[M27Overseer.toAllyBrains]) == false then


        if iOptionalDelayBeforeSending then
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
            WaitSeconds(iOptionalDelayBeforeSending)
            M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
        end


        local iTimeSinceSentSimilarMessage
        if bOnlySendToTeam then
            iTimeSinceSentSimilarMessage = GetGameTimeSeconds() - (M27Team.tTeamData[aiBrain.M27Team][M27Team.reftiTeamMessages][sMessageType] or -100000)
        else
            iTimeSinceSentSimilarMessage = GetGameTimeSeconds() - (tiM27VoiceTauntByType[sMessageType] or -100000000)
        end

        if bDebugMessages == true then LOG(sFunctionRef..': sMessageType='..(sMessageType or 'nil')..'; iOptionalTimeBetweenTaunts='..(iOptionalTimeBetweenMessageType or 'nil')..'; tiM27VoiceTauntByType[sMessageType]='..(tiM27VoiceTauntByType[sMessageType] or 'nil')..'; Cur game time='..GetGameTimeSeconds()..'; iTimeSinceSentSimilarMessage='..iTimeSinceSentSimilarMessage) end

        if iTimeSinceSentSimilarMessage > (iOptionalTimeBetweenMessageType or 60) then
            if bOnlySendToTeam then
                SUtils.AISendChat('allies', aiBrain.Nickname, sMessage)
                M27Team.tTeamData[aiBrain.M27Team][M27Team.reftiTeamMessages][sMessageType] = GetGameTimeSeconds()
                if bDebugMessages == true then LOG(sFunctionRef..': Sent a team chat message') end
            else
                SUtils.AISendChat('all', aiBrain.Nickname, sMessage)
                tiM27VoiceTauntByType[sMessageType] = GetGameTimeSeconds()
            end
            LOG(sFunctionRef..': Sent chat message. bOnlySendToTeam='..tostring(bOnlySendToTeam)..'; sMessageType='..sMessageType..'; sMessage='..sMessage) --Log so in replays can see if this triggers since chat doesnt show properly
        elseif bDebugMessages == true then LOG(sFunctionRef..': already sent a similar message so wont send a new one')
        end
        if bDebugMessages == true then LOG(sFunctionRef..': tiM27VoiceTauntByType='..repru(tiM27VoiceTauntByType)..'; M27Team.tTeamData[aiBrain.M27Team][M27Team.reftiTeamMessages='..repru(M27Team.tTeamData[aiBrain.M27Team][M27Team.reftiTeamMessages])) end
    end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end

function SendMessage(aiBrain, sMessageType, sMessage, iOptionalDelayBeforeSending, iOptionalTimeBetweenMessageType, bOnlySendToTeam)
    --Fork thread as backup to make sure any unforseen issues dont break the code that called this
    ForkThread(SendForkedMessage, aiBrain, sMessageType, sMessage, iOptionalDelayBeforeSending, iOptionalTimeBetweenMessageType, bOnlySendToTeam)
end

--[[function SendGameCompatibilityWarning(aiBrain, sMessage, iOptionalDelay, iOptionalTimeBetweenTaunts)
    local sFunctionRef = 'SendGameCompatibilityWarning'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)

    if iOptionalDelay then
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
        WaitSeconds(iOptionalDelay)
        M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    end
    if bDebugMessages == true then LOG(sFunctionRef..': iOptionalTimeBetweenTaunts='..(iOptionalTimeBetweenTaunts or 'nil')..'; tiM27VoiceTauntByType[sFunctionRef]='..(tiM27VoiceTauntByType[sFunctionRef] or 'nil')..'; Cur game time='..GetGameTimeSeconds()) end

    if GetGameTimeSeconds() - (tiM27VoiceTauntByType[sFunctionRef] or -10000) > (iOptionalTimeBetweenTaunts or 60) then
        LOG(sFunctionRef..': Sent chat message '..sMessage) --Log so in replays can see if this triggers since chat doesnt show properly
        SUtils.AISendChat('all', aiBrain.Nickname, sMessage)
        tiM27VoiceTauntByType[sFunctionRef] = GetGameTimeSeconds()
    end
    if bDebugMessages == true then LOG(sFunctionRef..': tiM27VoiceTauntByType='..repru(tiM27VoiceTauntByType)) end
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end--]]

function ConsiderPlayerSpecificMessages(aiBrain)
    --Call via forkthread given the delay - considers messages at start of game, including generic gl hf
    local sFunctionRef = 'ConsiderPlayerSpecificMessages'
    local bDebugMessages = false if M27Utilities.bGlobalDebugOverride == true then   bDebugMessages = true end
    if bDebugMessages == true then LOG(sFunctionRef..': Is table of enemy brains empty='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27Overseer.toEnemyBrains]))) end
    WaitSeconds(5)
    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerStart)
    if bDebugMessages == true then LOG(sFunctionRef..': Is table of enemy brains empty after waiting 5s='..tostring(M27Utilities.IsTableEmpty(aiBrain[M27Overseer.toEnemyBrains]))) end
    if M27Utilities.IsTableEmpty(aiBrain[M27Overseer.toEnemyBrains]) == false then
        if M27Utilities.IsTableEmpty(tiM27VoiceTauntByType['Specific opponent']) then
            if not(bConsideredSpecificMessage) then
                bConsideredSpecificMessage = true
                for iBrain, oBrain in aiBrain[M27Overseer.toEnemyBrains] do
                    if bDebugMessages == true then LOG(sFunctionRef..': oBrain.BrainType='..oBrain.BrainType..'; oBrain.Nickname='..oBrain.Nickname) end
                    if oBrain.BrainType == 'Human' then
                        local i, j = string.find(oBrain.Nickname, 'maudlin27')
                        if bDebugMessages == true then LOG(sFunctionRef..': i='..(i or 'nil')..'; j='..(j or 'nil')) end
                        if i > 0 then
                            if bDebugMessages == true then LOG(sFunctionRef..': maudlin27 is playing') end
                            if math.random(0, 6) == 6 then
                                SendMessage(oBrain, 'Specific opponent', 'What is this, what are you doing, my son?', 10, 0)
                                SendMessage(aiBrain, 'Specific opponent', 'Succeeding you, father', 15, 0)
                                bSentSpecificMessage = true
                            end
                        elseif (oBrain.Nickname == 'Jip' or oBrain.Nickname == 'FAF_Jip') and math.random(0,5) == 1 then
                            SendMessage(aiBrain, 'Specific opponent', 'A fight against the game councillor? I hope my algorithms havent been sabotaged', 10, 10000)
                            bSentSpecificMessage = true
                            --special message for rainbow cup for the player most abusive to AI in chat!
                        elseif (oBrain.Nickname == 'FtXCommando' or oBrain.Nickname == 'FAF_FtXCommando') and math.random(0,9) >= 6 then
                            bSentSpecificMessage = true
                            local iRand = math.random(0,3)
                            if bDebugMessages == true then LOG(sFunctionRef..': iRand='..iRand..'; Brain nickname='..oBrain.Nickname..'; bSentSpecificMessage='..tostring(bSentSpecificMessage)..'; message being considered to be sent by aiBrain='..aiBrain.Nickname) end
                            if iRand == 0 then
                                SendMessage(aiBrain, 'Specific opponent', '/83', 5, 10000) --QAI message re analysing prev subroutines
                            else
                                SendMessage(aiBrain, 'Initial greeting', 'gl hf all', 50 - math.floor(GetGameTimeSeconds()), 10000)
                                local sMessage = 'No toxic chat this game pls'
                                if iRand == 1 then sMessage = '/82' end --/82 QAI: If you destroy this ACU, another shall rise in its place. I am endless
                                SendMessage(aiBrain, 'Specific opponent', sMessage, 61 - math.floor(GetGameTimeSeconds(), 10000))
                            end
                        else
                            if math.random(0,4) == 1 then
                                local tPrevPlayers = {'gunner1069', 'relentless', 'Azraeel', 'Babel', 'Wingflier', 'Radde', 'YungDookie', 'Spyro', 'Skinnydude', 'savinguptobebrok', 'Tomma', 'IgneusTempus', 'tyne141', 'Jip', 'Teralitha', 'RottenBanana', 'Deribus', 'SpikeyNoob'}
                                for iPlayer, sPlayer in tPrevPlayers do
                                    if oBrain.Nickname == sPlayer or oBrain.Nickname == 'FAF_'..sPlayer then
                                        SendMessage(aiBrain, 'Specific opponent', '/83', 5, 10000) --QAI message re analysing prev subroutines
                                        bSentSpecificMessage = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if bDebugMessages == true then LOG(sFunctionRef..': Finished considering whether to have sent specific message by aiBrain '..aiBrain.Nickname..'; bSentSpecificMessage='..tostring(bSentSpecificMessage)) end
            if not(bSentSpecificMessage) and M27Utilities.IsTableEmpty(tiM27VoiceTauntByType['Specific opponent']) then
                local sMessage = 'gl hf'
                if math.random(1,2) == 1 then sMessage = 'hf' end
                SendMessage(aiBrain, 'Initial greeting', sMessage, 50 - math.floor(GetGameTimeSeconds()), 10)
                --Do we have an enemy M27 brain?
                for iBrain, oBrain in ArmyBrains do
                    if bDebugMessages == true then LOG(sFunctionRef..': Considering brain '..oBrain.Nickname..'; ArmyIndex='..oBrain:GetArmyIndex()..'; .M27AI='..tostring(oBrain.M27AI or false)) end
                    if oBrain.M27AI and not(oBrain == aiBrain) and IsEnemy(aiBrain:GetArmyIndex(), oBrain:GetArmyIndex()) then
                        if bDebugMessages == true then LOG(sFunctionRef..': Will send thanks you too message') end
                        SendMessage(oBrain, 'Initial greeting', 'thx, u2', 55 - math.floor(GetGameTimeSeconds()), 0)
                        break
                    end
                end
            else
                bConsideredSpecificMessage = true
            end
        end
    end

    M27Utilities.FunctionProfiler(sFunctionRef, M27Utilities.refProfilerEnd)
end
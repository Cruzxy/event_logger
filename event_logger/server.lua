local function defineScriptLogName()
	return os.time()
end

local logFileName = 'log-'..defineScriptLogName()




local function appendTextToFile(fileName, text)
    local resName = GetCurrentResourceName()
    local existing = LoadResourceFile(resName, fileName) or ""
    SaveResourceFile(resName, fileName, existing .. text .. "\n", -1)
end

local function getFileData(fileName)
    local resName = GetCurrentResourceName()
    local content = LoadResourceFile(resName, fileName)
    if not content then
        error("Error reading file: " .. fileName)
        return nil
    end
    return content
end

local eventLogsRegistered = {}
local canRegisterLogInCache = true

AddEventHandler('registerEventLog', function(eventName, sourceId, eventArgs)
    if canRegisterLogInCache then
        table.insert(eventLogsRegistered, {
            eventName = eventName, 
            sourceId = sourceId, 
            eventArgs = eventArgs,
            timestamp = os.time()
        })
    end
end)

RegisterCommand('stoplogevent', function(source)
    if source == 0 then
        canRegisterLogInCache = false
        print('Logs de eventos parados com sucesso!')
    end
end)

RegisterCommand('startlogevent', function(source)
    if source == 0 then
        canRegisterLogInCache = true
        print('Logs de eventos iniciados com sucesso!')
    end
end)

RegisterCommand('clearlogevent', function(source)
    if source == 0 then
        eventLogsRegistered = {}
        collectgarbage("collect")
        print('Logs de eventos limpos com sucesso!')
    end
end)

RegisterCommand('collectlogevent', function(source)
    if source == 0 then
        collectgarbage("collect")
        print('Coleta de lixo realizada com sucesso!')
    end
end)

RegisterCommand('logevent', function(source)
	if source == 0 then
		print('Iniciando registro de logs')
		print('Isso pode demorar um pouco...')
		print('Há um total de ' .. #eventLogsRegistered .. ' logs para serem registradas!')
		registerLogsInCacheOnSystem(true)
        print('Arquivo: "' ..  logFileName .. '.log' .. '" criado com sucesso!')
	end
end)

RegisterCommand('logeventfull', function(source)
	if source == 0 then
		print('Iniciando registro de logs')
		print('Isso pode demorar um pouco...')
		print('Há um total de ' .. #eventLogsRegistered .. ' logs para serem registradas!')
		registerLogsInCacheOnSystem(false)
        print('Arquivo: "' ..  logFileName .. '.log' .. '" criado com sucesso!')
	end
end)

function registerLogsInCacheOnSystem(justLogsFromLast10Minutes)
	for index, logInfo in ipairs(eventLogsRegistered) do
        if justLogsFromLast10Minutes then
            if logInfo.timestamp + 60 * 10 >= os.time() then
                local message = generateEventLogMessage(logInfo.eventName, logInfo.sourceId, logInfo.eventArgs)
                appendTextToFile(logFileName..'.log', message)
            end
        else
            local message = generateEventLogMessage(logInfo.eventName, logInfo.sourceId, logInfo.eventArgs)
            appendTextToFile(logFileName..'.log', message)
        end
	end
	eventLogsRegistered = {}
    collectgarbage("collect")
	print('Processo finalizado com sucesso!')
end

function generateEventLogMessage(eventName, sourceId, eventArgs)
	local message = '[EVENT_NAME]: ' .. eventName .. '\n[SOURCE_TRIGGERED]: ' .. sourceId .. '\n[BYTES]: ' .. getSizeInBytes(eventArgs) .. '\n[DATA_ARGS]: ' .. removeLineBreaks(getTableDumped(eventArgs)) .. '\n'
    return message
end

function removeLineBreaks(inputString)
    local stringWithoutLineBreaks = inputString:gsub("\n", " ")
    return stringWithoutLineBreaks
end

function getSizeInBytes(data)
    if type(data) == "number" then
        return 8
    elseif type(data) == "string" then
        return #data
    elseif type(data) == "table" then
        local totalSize = 0
        for _, v in pairs(data) do
            local size = getSizeInBytes(v)
            if size then
                totalSize = totalSize + size
            end
        end
        return totalSize
    else
        return nil
    end
end

function getTableDumped(node)
    return json.encode(node)
end

local function hasPermission(source)
    return source == 0
end

function removeEventEntries(inputStr, eventToRemove)
    local lines = {}
    local skip = 0

    for line in inputStr:gmatch("([^\r\n]+)") do  
        if line:find(eventToRemove, 1, true) then
            skip = 4 
        end

        if line:find('%[DATA%-ARGS%]:') then
            line = line .. '\n'
        end

        if skip == 0 then
            table.insert(lines, line)
        else
            skip = skip - 1
        end
    end

    return table.concat(lines, "\n")
end

RegisterCommand('logfilter', function(source, args)
    if not hasPermission(source) then
        return
    end

    local couldLoad, fileData = pcall(getFileData, tostring(args[1]))

    if couldLoad and args[2] then
        local filteredLog = removeEventEntries(fileData, '%[EVENT_NAME%]: ' .. args[2])

        local filteredFileName = logFileName .. '-filter-' .. os.time() .. '.log'
        appendTextToFile(filteredFileName, filteredLog)
        print('Filtro criado com sucesso removendo eventos com nome: ' .. tostring(args[2]))
        print('Filename: ' .. filteredFileName)
    else
        print('Comando dado de forma inválida!')
    end
end)

local function transformLogAsStringIntoATable(input)
    local result = {}
    local currentEntry = nil

    for line in input:gmatch("[^\r\n]+") do
        if line:match("^%[EVENT_NAME%]:") then
            if currentEntry then
                table.insert(result, currentEntry)
            end
            currentEntry = {}
        end

        if currentEntry then
            local key, value = line:match("^%[(.-)%]:%s*(.*)")
            if key and value then
                if key == "BYTES" or key == "SOURCE_TRIGGERED" then
                    value = tonumber(value)
                elseif key == "DATA_ARGS" then
                    value = value
                end
                currentEntry[key] = value
            end
        end
    end

    if currentEntry then
        table.insert(result, currentEntry)
    end

    return result
end

local function getLoopedEvents(logsTabled)
    local LOGS_TRIGGERS_LIMIT_IN_A_ROW = 50
    local logsSequence = {}
    local preWarningEventsPack = {}
    local warningEventsPack = {}

    for index, logInfo in pairs(logsTabled) do
        if #logsSequence == 0 then
            table.insert(logsSequence, logInfo)
        else
            if logsSequence[#logsSequence].EVENT_NAME == logInfo.EVENT_NAME then
                table.insert(logsSequence, logInfo)
                if #logsSequence >= LOGS_TRIGGERS_LIMIT_IN_A_ROW then
                    preWarningEventsPack = logsSequence
                end
            else
                if #preWarningEventsPack > 0 then
                    table.insert(warningEventsPack, preWarningEventsPack)
                    preWarningEventsPack = {}
                end
                logsSequence = {}
            end
        end
    end

    return warningEventsPack
end

local function getBigGlobalEvents(logsTabled)
    local warningEventsPack = {}
    local warningEvents = {}
    local ARGS_LENGHT_LIMIT = 100

    for index, logInfo in pairs(logsTabled) do
        if logInfo.SOURCE_TRIGGERED == -1 and #logInfo['DATA_ARGS'] > ARGS_LENGHT_LIMIT then
            table.insert(warningEvents, logInfo)
        end
    end

    for index, logInfo in pairs(warningEvents) do
        if not warningEventsPack[logInfo.EVENT_NAME] then
            warningEventsPack[logInfo.EVENT_NAME] = {}
        end

        table.insert(warningEventsPack[logInfo.EVENT_NAME], logInfo)
    end

    local instance = {}

    for index, value in pairs(warningEventsPack) do
        table.insert(instance, value)
    end

    return instance
end

local function getKillerEvents(loopedEvents, bigGlobalEvents)
    local loopedEventsNames = {}
    local bigGlobalEventsNames = {}

    for index, eventPack in pairs(loopedEvents) do
        loopedEventsNames[eventPack[1].EVENT_NAME] = eventPack
    end

    for index, eventPack in pairs(bigGlobalEvents) do
        bigGlobalEventsNames[eventPack[1].EVENT_NAME] = eventPack
    end

    local instance = {}

    for eventName, eventInfo in pairs(bigGlobalEventsNames) do
        if loopedEventsNames[eventName] then
            table.insert(instance, eventInfo)
        end
    end

    return instance
end

local function trunkString(s)
    if #s > 80 then
        return string.sub(s, 1, 80) .. "..."
    else
        return s
    end
end

local function defineWarningEventsAndNotify(logsTabled)
    local loopedEvents = getLoopedEvents(logsTabled)
    local bigGlobalEvents = getBigGlobalEvents(logsTabled)
    local killerEvents = getKillerEvents(loopedEvents, bigGlobalEvents)
    
    local function filterLoopedEvents(loopedEvents)
        local instance = {}

        for index, eventPack in pairs(loopedEvents) do
            if not instance[eventPack[1].EVENT_NAME] then
                instance[eventPack[1].EVENT_NAME] = {}
            end

            for _, eventInfo in pairs(eventPack) do
                table.insert(instance[eventPack[1].EVENT_NAME], eventInfo)
            end
        end

        local newInstance = {}

        for index, eventPack in pairs(instance) do
            table.insert(newInstance, eventPack)
        end

        return newInstance
    end
    
    print('[EVENT_LOGGER] [BAIXO RISCO DE PERIGO] ' .. #filterLoopedEvents(loopedEvents) .. ' tipos eventos encontrados que triggam de forma excessiva para os clients.')
    print('[EVENT_LOGGER] [ALTO RISCO DE PERIGO] ' .. #bigGlobalEvents .. ' tipos eventos encontrados que triggam dados MUITO PESADOS (alta quantia de bytes) para TODOS OS JOGADORES')
    print('[EVENT_LOGGER] [RISCO MÁXIMO DE PERIGO] ' .. #killerEvents .. ' tipos de eventos que triggam de forma excessiva e ALTAMENTE PESADA para TODOS OS JOGADORES')

    local currentEventList = nil
    local currentEventIndex = 0
    local awaitingNext = nil

    local function showCurrentEvent()
        if not currentEventList or currentEventIndex > #currentEventList then
            print('[EVENT_LOGGER] Não tem mais eventos!')
            currentEventList = nil
            return
        end
        local eventPack = currentEventList[currentEventIndex]
        print('[' .. currentEventIndex .. '/' .. #currentEventList .. '] ' .. eventPack[1].EVENT_NAME)
        print('[EVENT_LOGGER] /args - ver argumentos (limitado a 80 chars)')
        print('[EVENT_LOGGER] /args 1 - ver argumentos completos')
        print('/next - próximo evento')
    end

    local function seeEventsArguments(eventPack, showFullArguments)
        print('[EVENT_LOGGER] getting arguments ' .. eventPack[1].EVENT_NAME)

        table.sort(eventPack, function(a,b)
            if a.SOURCE_TRIGGERED == -1 and b.SOURCE_TRIGGERED == -1 then
                return false
            elseif a.SOURCE_TRIGGERED == -1 then
                return true
            else
                return a.SOURCE_TRIGGERED < b.SOURCE_TRIGGERED
            end
        end)

        for _, eventInfo in pairs(eventPack) do
            local arguments = eventInfo['DATA_ARGS']
            if not showFullArguments then
                arguments = trunkString(arguments)
            end
            print('[ARGS] ' .. arguments .. '\n[SOURCE_TARGET] ' .. eventInfo.SOURCE_TRIGGERED)
        end
    end

    RegisterCommand('args', function(source, args)
        if not hasPermission(source) then return end
        if not currentEventList or currentEventIndex > #currentEventList then
            print('[EVENT_LOGGER] Nenhum evento selecionado. Use /result low/mid/high primeiro.')
            return
        end
        local eventPack = currentEventList[currentEventIndex]
        seeEventsArguments(eventPack, args[1] ~= nil)
        print('[AVISO] /next - Para ir para o próximo evento')
    end)

    RegisterCommand('next', function(source, args)
        if not hasPermission(source) then return end
        if not currentEventList then
            print('[EVENT_LOGGER] Nenhuma lista de eventos ativa.')
            return
        end
        currentEventIndex = currentEventIndex + 1
        if currentEventIndex > #currentEventList then
            print('[EVENT_LOGGER] Fim da lista de eventos!')
            currentEventList = nil
            return
        end
        showCurrentEvent()
    end)

    RegisterCommand('result', function(source, args)
        if not hasPermission(source) then return end

        if args[1] == 'low' then
            currentEventList = filterLoopedEvents(loopedEvents)
            print('[EVENT_LOGGER] Lista de eventos de baixo risco')
        elseif args[1] == 'mid' then
            currentEventList = bigGlobalEvents
            print('[EVENT_LOGGER] Lista de eventos de alto risco elevado')
        elseif args[1] == 'high' then
            currentEventList = killerEvents
            print('[EVENT_LOGGER] Lista de eventos de RISCO ELEVADISSIMO')
        else
            print('/result low/mid/high')
            return
        end

        currentEventIndex = 1
        if #currentEventList == 0 then
            print('[EVENT_LOGGER] Nenhum evento encontrado nessa categoria.')
            currentEventList = nil
            return
        end
        showCurrentEvent()
    end)

    print('[EVENT_LOGGER] Para analisar quais são os eventos pesados:')
    print('[EVENT_LOGGER] /result low - Ver nomes dos eventos de baixo risco')
    print('[EVENT_LOGGER] /result mid - Ver nomes dos eventos de risco alto')
    print('[EVENT_LOGGER] /result high - Ver nomes dos eventos de risco ALTÍSSIMO')
end

RegisterCommand('loganalyze', function(source, args)
    if not hasPermission(source) then
        return
    end

    local couldLoad, fileData = pcall(getFileData, 'eventLog/' .. tostring(args[1]))

    if couldLoad then
        print('Iniciando análise dos eventos...')
        local logsTabled = transformLogAsStringIntoATable(fileData)

        defineWarningEventsAndNotify(logsTabled)
    else
        print('Comando dado de forma inválida!')
    end
end)

RegisterCommand('loghelp', function(source)
    print('/loginstall - Para instalar dependências do script na base (precisa dar RR)')
    print('/loguninstall - Desinstalar dependências da base (precisa dar RR)')
    print('/logevent - Para gerar a log dos eventos dos últimos 10 minutos do servidor')
    print('/logeventfull - Para gerar a log dos eventos desde o start do servidor (COMANDO ALTAMENTE PESADO)')
    print('/logfilter [filename] [event-to-remove] - Remover eventos de uma log específica gerando outra log filtrada')
    print('/loganalyze [filename] - O algoritmo analisa quais eventos certamente estão pesados e derrubam o servidor')
    print('/stoplogevent - Parar de registrar logs de eventos')
    print('/startlogevent - Iniciar de registrar logs de eventos')
    print('/clearlogevent - Limpar logs de eventos')
    print('/collectlogevent - Coletar lixo')
end)

CreateThread(function()
    ExecuteCommand('loghelp')
end)
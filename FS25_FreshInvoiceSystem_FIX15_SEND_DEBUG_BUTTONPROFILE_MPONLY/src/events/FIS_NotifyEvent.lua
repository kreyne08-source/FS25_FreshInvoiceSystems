
FIS_NotifyEvent = {}
local FIS_NotifyEvent_mt = Class(FIS_NotifyEvent, Event)

InitEventClass(FIS_NotifyEvent, "FIS_NotifyEvent")

function FIS_NotifyEvent.emptyNew()
    local self = Event.new(FIS_NotifyEvent_mt)
    self.notificationType = 0
    self.textKey = ""
    self.textParam1 = ""
    self.textParam2 = ""
    return self
end

function FIS_NotifyEvent.new(notificationType, textKey, param1, param2)
    local self = FIS_NotifyEvent.emptyNew()
    self.notificationType = notificationType or 0
    self.textKey = textKey or ""
    self.textParam1 = param1 or ""
    self.textParam2 = param2 or ""
    return self
end

function FIS_NotifyEvent:readStream(streamId, connection)
    self.notificationType = streamReadInt8(streamId)
    self.textKey = streamReadString(streamId) or ""
    self.textParam1 = streamReadString(streamId) or ""
    self.textParam2 = streamReadString(streamId) or ""
    self:run(connection)
end

function FIS_NotifyEvent:writeStream(streamId, connection)
    streamWriteInt8(streamId, self.notificationType)
    streamWriteString(streamId, self.textKey)
    streamWriteString(streamId, self.textParam1)
    streamWriteString(streamId, self.textParam2)
end

local function showNotification(notificationType, text)
    if g_currentMission == nil then
        return
    end

    if type(g_currentMission.addIngameNotification) == "function" and FSBaseMission ~= nil then
        local nType = FSBaseMission.INGAME_NOTIFICATION_INFO
        if notificationType == 2 then
            nType = FSBaseMission.INGAME_NOTIFICATION_WARNING
        end
        g_currentMission:addIngameNotification(nType, text, 5000)
        return
    end

    if type(g_currentMission.showBlinkingWarning) == "function" then
        g_currentMission:showBlinkingWarning(text, 5000)
    end
end

function FIS_NotifyEvent:run(connection)
    if g_i18n == nil then
        return
    end

    local text = ""
    if self.textKey ~= "" then
        text = g_i18n:getText(self.textKey) or self.textKey
        if self.textParam1 ~= "" then
            text = string.format(text, self.textParam1, self.textParam2)
        end
    end

    showNotification(self.notificationType, text)
end

function FIS_NotifyEvent.sendToConnection(connection, notificationType, textKey, param1, param2)
    if connection ~= nil then
        connection:sendEvent(FIS_NotifyEvent.new(notificationType, textKey, param1, param2))
    end
end

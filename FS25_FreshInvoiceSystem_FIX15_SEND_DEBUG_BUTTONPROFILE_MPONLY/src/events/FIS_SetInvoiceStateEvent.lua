FIS_SetInvoiceStateEvent = {}
local FIS_SetInvoiceStateEvent_mt = Class(FIS_SetInvoiceStateEvent, Event)

InitEventClass(FIS_SetInvoiceStateEvent, "FIS_SetInvoiceStateEvent")

function FIS_SetInvoiceStateEvent.emptyNew()
    local self = Event.new(FIS_SetInvoiceStateEvent_mt)
    return self
end

function FIS_SetInvoiceStateEvent.new(invoiceId, newState, requestingFarmId)
    local self = FIS_SetInvoiceStateEvent.emptyNew()
    self.invoiceId = invoiceId or 0
    self.newState = newState or 0
    self.requestingFarmId = requestingFarmId or 0
    return self
end

function FIS_SetInvoiceStateEvent:readStream(streamId, connection)
    self.invoiceId = streamReadInt32(streamId)
    self.newState = streamReadUInt8(streamId)
    self.requestingFarmId = streamReadInt32(streamId)

    self:run(connection)
end

function FIS_SetInvoiceStateEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.invoiceId)
    streamWriteUInt8(streamId, self.newState)
    streamWriteInt32(streamId, self.requestingFarmId)
end

function FIS_SetInvoiceStateEvent:run(connection)
    if g_currentMission:getIsServer() then
        local farmId = connection:getFarmId()
        if farmId ~= self.requestingFarmId then
            return
        end

        local hasPerm = true
        if g_currentMission.userManager ~= nil and type(g_currentMission.userManager.getUserByConnection) == "function" then
            local user = g_currentMission.userManager:getUserByConnection(connection)
            if user ~= nil and type(user.getHasPermission) == "function" then
                hasPerm = user:getHasPermission("manageFinance", farmId) or user:getHasPermission("manageMoney", farmId) or user:getHasPermission("farmManager", farmId)
            end
        end
        if hasPerm ~= true then
            return
        end

        if g_fis_invoiceManager ~= nil then
            g_fis_invoiceManager:setInvoiceState(self.invoiceId, self.newState, self.requestingFarmId)
        end
    end
end

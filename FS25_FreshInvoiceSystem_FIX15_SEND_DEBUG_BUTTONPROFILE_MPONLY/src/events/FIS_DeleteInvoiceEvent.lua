FIS_DeleteInvoiceEvent = {}
local FIS_DeleteInvoiceEvent_mt = Class(FIS_DeleteInvoiceEvent, Event)

InitEventClass(FIS_DeleteInvoiceEvent, "FIS_DeleteInvoiceEvent")

function FIS_DeleteInvoiceEvent.emptyNew()
    local self = Event.new(FIS_DeleteInvoiceEvent_mt)
    return self
end

function FIS_DeleteInvoiceEvent.new(invoiceId, requestingFarmId)
    local self = FIS_DeleteInvoiceEvent.emptyNew()
    self.invoiceId = invoiceId or 0
    self.requestingFarmId = requestingFarmId or 0
    return self
end

function FIS_DeleteInvoiceEvent:readStream(streamId, connection)
    self.invoiceId = streamReadInt32(streamId)
    self.requestingFarmId = streamReadInt32(streamId)
    self:run(connection)
end

function FIS_DeleteInvoiceEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.invoiceId)
    streamWriteInt32(streamId, self.requestingFarmId)
end

function FIS_DeleteInvoiceEvent:run(connection)
    if g_currentMission:getIsServer() then
        local farmId = connection:getFarmId()
        if farmId ~= self.requestingFarmId then
            return
        end

        if g_fis_invoiceManager ~= nil then
            g_fis_invoiceManager:deleteInvoice(self.invoiceId, self.requestingFarmId)
        end
    end
end

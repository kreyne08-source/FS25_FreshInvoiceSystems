FIS_CreateInvoiceEvent = {}
local FIS_CreateInvoiceEvent_mt = Class(FIS_CreateInvoiceEvent, Event)

InitEventClass(FIS_CreateInvoiceEvent, "FIS_CreateInvoiceEvent")

function FIS_CreateInvoiceEvent.emptyNew()
    local self = Event.new(FIS_CreateInvoiceEvent_mt)
    return self
end

function FIS_CreateInvoiceEvent.new(fromFarmId, toFarmId, category, description, lineItems)
    local self = FIS_CreateInvoiceEvent.emptyNew()

    self.fromFarmId = fromFarmId or 0
    self.toFarmId = toFarmId or 0
    self.category = category or "other"
    self.description = description or ""
    self.lineItems = lineItems or {}

    return self
end

function FIS_CreateInvoiceEvent:readStream(streamId, connection)
    self.fromFarmId = streamReadInt32(streamId)
    self.toFarmId = streamReadInt32(streamId)
    self.category = streamReadString(streamId) or "other"
    self.description = streamReadString(streamId)
    local n = streamReadUInt8(streamId)
    self.lineItems = {}
    for i = 1, n do
        local item = {
            itemType = streamReadString(streamId) or "units",
            description = streamReadString(streamId) or "",
            quantity = streamReadFloat32(streamId),
            unitPrice = streamReadFloat32(streamId),
            unit = streamReadString(streamId) or ""
        }
        table.insert(self.lineItems, item)
    end

    self:run(connection)
end

function FIS_CreateInvoiceEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.fromFarmId)
    streamWriteInt32(streamId, self.toFarmId)
    streamWriteString(streamId, self.category or "other")
    streamWriteString(streamId, self.description)
    local n = 0
    if self.lineItems ~= nil then
        n = #self.lineItems
    end
    streamWriteUInt8(streamId, math.min(n, 20))
    for i = 1, math.min(n, 20) do
        local item = self.lineItems[i]
        streamWriteString(streamId, item.itemType or "units")
        streamWriteString(streamId, item.description or "")
        streamWriteFloat32(streamId, item.quantity or 0)
        streamWriteFloat32(streamId, item.unitPrice or 0)
        streamWriteString(streamId, item.unit or "")
    end
end

function FIS_CreateInvoiceEvent:run(connection)
    if g_currentMission:getIsServer() then
        local farmId = connection:getFarmId()
if farmId == nil or farmId == 0 or farmId == FarmManager.SPECTATOR_FARM_ID then
    Logging.warning("[FIS] CreateInvoiceEvent rejected: invalid sender farmId=%s", tostring(farmId))
    return
end

self.fromFarmId = farmId

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
            g_fis_invoiceManager:createInvoice(self.fromFarmId, self.toFarmId, self.category, self.description, self.lineItems)
        end
    end
end

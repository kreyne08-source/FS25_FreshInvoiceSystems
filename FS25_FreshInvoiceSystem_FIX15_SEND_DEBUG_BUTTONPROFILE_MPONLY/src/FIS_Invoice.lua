FIS_Invoice = {}
local FIS_Invoice_mt = Class(FIS_Invoice, Object)

FIS_Invoice.STATE_OPEN = 1
FIS_Invoice.STATE_PAID = 2
FIS_Invoice.STATE_DECLINED = 3

function FIS_Invoice.new(isServer, isClient)
    local self = Object.new(isServer, isClient, FIS_Invoice_mt)

    self.invoiceDirtyFlag = self:getNextDirtyFlag()

    self.id = 0
    self.fromFarmId = 0
    self.toFarmId = 0
    self.amount = 0
    self.category = "other"
    self.description = ""
    self.lineItems = {}
    self.state = FIS_Invoice.STATE_OPEN
    self.createdTimestamp = 0
    self.paidTimestamp = 0

    return self
end

function FIS_Invoice:loadFromXMLFile(xmlFile, key)
    self.id = xmlFile:getInt(key .. "#id", 0)
    self.fromFarmId = xmlFile:getInt(key .. "#fromFarmId", 0)
    self.toFarmId = xmlFile:getInt(key .. "#toFarmId", 0)
    self.amount = xmlFile:getFloat(key .. "#amount", 0)
    self.category = xmlFile:getString(key .. "#category", "other")
    self.description = xmlFile:getString(key .. "#description", "")
    self.state = xmlFile:getInt(key .. "#state", FIS_Invoice.STATE_OPEN)
    self.createdTimestamp = xmlFile:getInt(key .. "#createdTimestamp", 0)
    self.paidTimestamp = xmlFile:getInt(key .. "#paidTimestamp", 0)

    self.lineItems = {}
    local i = 0
    while true do
        local itemKey = string.format("%s.lineItem(%d)", key, i)
        if not xmlFile:hasProperty(itemKey) then
            break
        end
        local item = {
            itemType = xmlFile:getString(itemKey .. "#type", "units"),
            description = xmlFile:getString(itemKey .. "#description", ""),
            quantity = xmlFile:getFloat(itemKey .. "#quantity", 0),
            unitPrice = xmlFile:getFloat(itemKey .. "#unitPrice", 0),
            unit = xmlFile:getString(itemKey .. "#unit", "")
        }
        table.insert(self.lineItems, item)
        i = i + 1
    end
end

function FIS_Invoice:saveToXMLFile(xmlFile, key)
    xmlFile:setInt(key .. "#id", self.id)
    xmlFile:setInt(key .. "#fromFarmId", self.fromFarmId)
    xmlFile:setInt(key .. "#toFarmId", self.toFarmId)
    xmlFile:setFloat(key .. "#amount", self.amount)
    xmlFile:setString(key .. "#category", self.category or "other")
    xmlFile:setString(key .. "#description", self.description)
    xmlFile:setInt(key .. "#state", self.state)
    xmlFile:setInt(key .. "#createdTimestamp", self.createdTimestamp)
    xmlFile:setInt(key .. "#paidTimestamp", self.paidTimestamp)

    if self.lineItems ~= nil then
        for i, item in ipairs(self.lineItems) do
            local itemKey = string.format("%s.lineItem(%d)", key, i - 1)
            xmlFile:setString(itemKey .. "#type", item.itemType or "units")
            xmlFile:setString(itemKey .. "#description", item.description or "")
            xmlFile:setFloat(itemKey .. "#quantity", item.quantity or 0)
            xmlFile:setFloat(itemKey .. "#unitPrice", item.unitPrice or 0)
            xmlFile:setString(itemKey .. "#unit", item.unit or "")
        end
    end
end

function FIS_Invoice:recalculateAmount()
    local total = 0
    if self.lineItems ~= nil then
        for _, item in ipairs(self.lineItems) do
            local q = tonumber(item.quantity) or 0
            local p = tonumber(item.unitPrice) or 0
            total = total + (q * p)
        end
    end
    self.amount = total
end

function FIS_Invoice:getStateText()
    if self.state == FIS_Invoice.STATE_OPEN then
        return g_i18n:getText("ui_fis_open")
    elseif self.state == FIS_Invoice.STATE_PAID then
        return g_i18n:getText("ui_fis_paid")
    elseif self.state == FIS_Invoice.STATE_DECLINED then
        return g_i18n:getText("ui_fis_declined")
    end

    return g_i18n:getText("ui_fis_invalid")
end


function FIS_Invoice:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.id)
    streamWriteInt32(streamId, self.fromFarmId)
    streamWriteInt32(streamId, self.toFarmId)
    streamWriteFloat32(streamId, self.amount)
    streamWriteString(streamId, self.category or "other")
    streamWriteString(streamId, self.description)
    local n = 0
    if self.lineItems ~= nil then
        n = #self.lineItems
    end
    streamWriteUInt8(streamId, math.min(n, 50))
    for i = 1, math.min(n, 50) do
        local item = self.lineItems[i]
        streamWriteString(streamId, item.itemType or "units")
        streamWriteString(streamId, item.description or "")
        streamWriteFloat32(streamId, item.quantity or 0)
        streamWriteFloat32(streamId, item.unitPrice or 0)
        streamWriteString(streamId, item.unit or "")
    end
    streamWriteUInt8(streamId, self.state)
    streamWriteInt32(streamId, self.createdTimestamp)
    streamWriteInt32(streamId, self.paidTimestamp)
end

function FIS_Invoice:readStream(streamId, connection)
    self.id = streamReadInt32(streamId)
    self.fromFarmId = streamReadInt32(streamId)
    self.toFarmId = streamReadInt32(streamId)
    self.amount = streamReadFloat32(streamId)
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
    self.state = streamReadUInt8(streamId)
    self.createdTimestamp = streamReadInt32(streamId)
    self.paidTimestamp = streamReadInt32(streamId)

    if g_fis_invoiceManager ~= nil then
        g_fis_invoiceManager:onInvoiceStreamedIn(self)
    end
end

function FIS_Invoice:writeUpdateStream(streamId, connection, dirtyMask)
    if streamWriteBool(streamId, bitAND(dirtyMask, self.invoiceDirtyFlag) ~= 0) then
        streamWriteUInt8(streamId, self.state)
        streamWriteInt32(streamId, self.paidTimestamp)
    end
end

function FIS_Invoice:readUpdateStream(streamId, connection, dirtyMask)
    if streamReadBool(streamId) then
        self.state = streamReadUInt8(streamId)
        self.paidTimestamp = streamReadInt32(streamId)
    end
end



function FIS_Invoice:isOverdue(currentDay)
    return self.state == "OPEN" and self.dueDate ~= nil and currentDay > self.dueDate
end



function FIS_Invoice:applyLateInterest(currentDay)
    if not self:isOverdue(currentDay) then return end
    if self.lastInterestDay == currentDay then return end

    local daysLate = currentDay - math.max(self.dueDate, self.lastInterestDay or self.dueDate)
    if daysLate <= 0 then return end

    local interest = self.totalAmount * self.lateInterestRate * daysLate
    self.totalAmount = self.totalAmount + interest
    self.lastInterestDay = currentDay

    self:raiseDirtyFlags(self.dirtyFlag)
    self:raiseActive()
end


function FIS_Invoice:applyLateInterestWithCap(currentDay)
    if not self:isOverdue(currentDay) then return end
    self.maxLateMultiplier = self.maxLateMultiplier or 1.25

    local cappedMax = self.baseTotalAmount * self.maxLateMultiplier
    if self.totalAmount >= cappedMax then return end

    self:applyLateInterest(currentDay)
    if self.totalAmount > cappedMax then
        self.totalAmount = cappedMax
    end
end

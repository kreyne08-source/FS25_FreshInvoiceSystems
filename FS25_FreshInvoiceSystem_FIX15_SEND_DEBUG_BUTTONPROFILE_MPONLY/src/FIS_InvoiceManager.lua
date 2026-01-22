FIS_InvoiceManager = {}
local FIS_InvoiceManager_mt = Class(FIS_InvoiceManager)

local SAVE_FILE = "fis_invoices.xml"

local function safeConnectionsForFarm(farmId)
    if g_currentMission ~= nil and g_currentMission.userManager ~= nil then
        local um = g_currentMission.userManager
        if type(um.getConnectionsByFarmId) == "function" then
            local ok, res = pcall(function()
                return um:getConnectionsByFarmId(farmId)
            end)
            if ok and res ~= nil then
                return res
            end
        end
    end
    return nil
end

function FIS_InvoiceManager:_notifyFarm(farmId, notificationType, textKey, p1, p2)
    if not g_currentMission:getIsServer() then
        return
    end
    local conns = safeConnectionsForFarm(farmId)
    if conns ~= nil then
        for _, c in pairs(conns) do
            FIS_NotifyEvent.sendToConnection(c, notificationType, textKey, p1, p2)
        end
    elseif g_server ~= nil then
        g_server:broadcastEvent(FIS_NotifyEvent.new(notificationType, textKey, p1, p2), true)
    end
end

function FIS_InvoiceManager.new()
    local self = setmetatable({}, FIS_InvoiceManager_mt)

    self.invoicesById = {}
    self.inboxByFarmId = {}
    self.outboxByFarmId = {}

    self.nextInvoiceId = 1

    return self
end

function FIS_InvoiceManager:delete()
end

function FIS_InvoiceManager:loadMap()
    g_fis_invoiceManager = self
end

function FIS_InvoiceManager:onInvoiceStreamedIn(invoice)
    Logging.info(string.format("[FIS] invoice streamed in id=%d from=%d to=%d amount=%s", invoice.id or -1, invoice.fromFarmId or -1, invoice.toFarmId or -1, tostring(invoice.amount)))
self.invoicesById[invoice.id] = invoice

    self.inboxByFarmId[invoice.toFarmId] = self.inboxByFarmId[invoice.toFarmId] or {}
    self.outboxByFarmId[invoice.fromFarmId] = self.outboxByFarmId[invoice.fromFarmId] or {}

    self.inboxByFarmId[invoice.toFarmId][invoice.id] = invoice
    self.outboxByFarmId[invoice.fromFarmId][invoice.id] = invoice
end


function FIS_InvoiceManager:getFarmName(farmId)
    local farm = g_farmManager ~= nil and g_farmManager:getFarmById(farmId) or nil
    if farm ~= nil and farm.name ~= nil then
        return farm.name
    end
    return tostring(farmId)
end

function FIS_InvoiceManager:getInvoicesForFarm(farmId, isInbox)
    if isInbox then
        return self.inboxByFarmId[farmId] or {}
    end
    return self.outboxByFarmId[farmId] or {}
end

function FIS_InvoiceManager:getInvoiceById(invoiceId)
    return self.invoicesById[invoiceId]
end

function FIS_InvoiceManager:canChangeInvoice(invoice)
    return invoice ~= nil and invoice.state == FIS_Invoice.STATE_OPEN
end

function FIS_InvoiceManager:_ensureFarmLists(fromFarmId, toFarmId)
    self.outboxByFarmId[fromFarmId] = self.outboxByFarmId[fromFarmId] or {}
    self.inboxByFarmId[toFarmId] = self.inboxByFarmId[toFarmId] or {}
end

function FIS_InvoiceManager:_registerInvoice(invoice)
    invoice:register()
    invoice:raiseDirtyFlags(invoice.invoiceDirtyFlag)
    invoice:raiseActive()
end

function FIS_InvoiceManager:_addMoney(amount, farmId, moneyType)
    if g_currentMission:getIsServer() then
        g_currentMission:addMoneyChange(amount, farmId, moneyType, true)
        local farm = g_farmManager:getFarmById(farmId)
        if farm ~= nil then
            farm:changeBalance(amount, moneyType)
        end
    else
    end
end


function FIS_InvoiceManager:createInvoice(fromFarmId, toFarmId, category, description, lineItems)
    if not g_currentMission:getIsServer() then
        Logging.info("[FIS] createInvoice client->server event")
        g_client:getServerConnection():sendEvent(FIS_CreateInvoiceEvent.new(fromFarmId, toFarmId, category, description, lineItems))
        return nil
    end

    self:_ensureFarmLists(fromFarmId, toFarmId)

    Logging.info(string.format("[FIS] createInvoice server from=%d to=%d", fromFarmId, toFarmId))

    local invoice = FIS_Invoice.new(true, g_currentMission:getIsClient())
    invoice.id = self.nextInvoiceId
    self.nextInvoiceId = self.nextInvoiceId + 1

    invoice.fromFarmId = fromFarmId
    invoice.toFarmId = toFarmId
    invoice.category = category or "other"
    invoice.description = tostring(description or "")
    invoice.lineItems = lineItems or {}
    invoice:recalculateAmount()
    invoice.state = FIS_Invoice.STATE_OPEN
    invoice.createdTimestamp = g_currentMission.time
    invoice.paidTimestamp = 0

    self.invoicesById[invoice.id] = invoice
    self.outboxByFarmId[fromFarmId][invoice.id] = invoice
    self.inboxByFarmId[toFarmId][invoice.id] = invoice

    self:_registerInvoice(invoice)

    local fromName = self:getFarmName(fromFarmId)
    local toName = self:getFarmName(toFarmId)
    self:_notifyFarm(toFarmId, 0, "ui_fis_notify_received", fromName, g_i18n:formatMoney(invoice.amount, 0, true, true))
    self:_notifyFarm(fromFarmId, 0, "ui_fis_notify_sent", toName, g_i18n:formatMoney(invoice.amount, 0, true, true))

    return invoice
end


function FIS_InvoiceManager:setInvoiceState(invoiceId, newState, requestingFarmId)
    if not g_currentMission:getIsServer() then
        Logging.info("[FIS] createInvoice client->server event")
        g_client:getServerConnection():sendEvent(FIS_SetInvoiceStateEvent.new(invoiceId, newState, requestingFarmId))
        return
    end

    local invoice = self.invoicesById[invoiceId]
    if invoice == nil then
        return
    end

    if not self:canChangeInvoice(invoice) then
        return
    end

    if requestingFarmId ~= nil and invoice.toFarmId ~= requestingFarmId then
        return
    end

    if newState == FIS_Invoice.STATE_DECLINED then
        invoice.state = FIS_Invoice.STATE_DECLINED
        invoice.paidTimestamp = 0

        local fromName = self:getFarmName(invoice.fromFarmId)
        local toName = self:getFarmName(invoice.toFarmId)
        self:_notifyFarm(invoice.fromFarmId, 2, "ui_fis_notify_declined_sender", toName, g_i18n:formatMoney(invoice.amount, 0, true, true))
        self:_notifyFarm(invoice.toFarmId, 0, "ui_fis_notify_declined_receiver", fromName, g_i18n:formatMoney(invoice.amount, 0, true, true))
    elseif newState == FIS_Invoice.STATE_PAID then
        local payerFarm = g_farmManager:getFarmById(invoice.toFarmId)
        if payerFarm == nil or payerFarm.money < invoice.amount then
            return
        end

        self:_addMoney(-invoice.amount, invoice.toFarmId, MoneyType.OTHER)
        self:_addMoney(invoice.amount, invoice.fromFarmId, MoneyType.OTHER)

        invoice.state = FIS_Invoice.STATE_PAID
        invoice.paidTimestamp = g_currentMission.time

        local fromName = self:getFarmName(invoice.fromFarmId)
        local toName = self:getFarmName(invoice.toFarmId)
        self:_notifyFarm(invoice.fromFarmId, 0, "ui_fis_notify_paid_sender", toName, g_i18n:formatMoney(invoice.amount, 0, true, true))
        self:_notifyFarm(invoice.toFarmId, 0, "ui_fis_notify_paid_receiver", fromName, g_i18n:formatMoney(invoice.amount, 0, true, true))
    else
        return
    end

    invoice:raiseDirtyFlags(invoice.invoiceDirtyFlag)
    invoice:raiseActive()
end


function FIS_InvoiceManager:deleteInvoice(invoiceId, requestingFarmId)
    if not g_currentMission:getIsServer() then
        Logging.info("[FIS] createInvoice client->server event")
        g_client:getServerConnection():sendEvent(FIS_DeleteInvoiceEvent.new(invoiceId, requestingFarmId))
        return
    end

    local invoice = self.invoicesById[invoiceId]
    if invoice == nil then
        return
    end

    if requestingFarmId == nil or invoice.fromFarmId ~= requestingFarmId then
        return
    end

    if invoice.state ~= FIS_Invoice.STATE_OPEN then
        return
    end

    if self.outboxByFarmId[invoice.fromFarmId] == nil or self.outboxByFarmId[invoice.fromFarmId][invoiceId] == nil then
        return
    end

    self.invoicesById[invoiceId] = nil
    if self.outboxByFarmId[invoice.fromFarmId] ~= nil then
        self.outboxByFarmId[invoice.fromFarmId][invoiceId] = nil
    end
    if self.inboxByFarmId[invoice.toFarmId] ~= nil then
        self.inboxByFarmId[invoice.toFarmId][invoiceId] = nil
    end

end


function FIS_InvoiceManager:saveToXMLFile(missionInfo)
    if not g_currentMission:getIsServer() then
        return
    end

    local saveDir = g_currentMission.missionInfo.savegameDirectory
    if saveDir == nil then
        return
    end

    local path = saveDir .. "/" .. SAVE_FILE
    local key = "invoices"
    local xmlFile = XMLFile.create("fis_invoices", path, key)
    if xmlFile == nil then
        return
    end

    xmlFile:setInt(key .. "#nextInvoiceId", self.nextInvoiceId)

    local i = 0
    for _, invoice in pairs(self.invoicesById) do
        local invKey = string.format("%s.invoice(%d)", key, i)
        invoice:saveToXMLFile(xmlFile, invKey)
        i = i + 1
    end

    xmlFile:save()
    xmlFile:delete()
end

function FIS_InvoiceManager:loadFromXMLFile(missionInfo)
    if not g_currentMission:getIsServer() then
        return
    end

    local saveDir = g_currentMission.missionInfo.savegameDirectory
    if saveDir == nil then
        return
    end

    local path = saveDir .. "/" .. SAVE_FILE
    local seedMarker = saveDir .. "/fis_seeded_test_invoices.txt"
    local key = "invoices"

    if not fileExists(path) then
        if not fileExists(seedMarker) then
            local seeded = self:_seedTestInvoicesOnce(seedMarker)
            if not seeded then
                self.seedPending = true
                Logging.info("[FIS] Seed pending (no invoices file yet; waiting for >=2 farms)")
            end
        end
        return
    end

    local xmlFile = XMLFile.load("fis_invoices", path, key)
    if xmlFile == nil then
        return
    end

    self.nextInvoiceId = xmlFile:getInt(key .. "#nextInvoiceId", 1)

    local i = 0
    while true do
        local invKey = string.format("%s.invoice(%d)", key, i)
        if not xmlFile:hasProperty(invKey) then
            break
        end

        local invoice = FIS_Invoice.new(true, g_currentMission:getIsClient())
        invoice:loadFromXMLFile(xmlFile, invKey)

        self:_ensureFarmLists(invoice.fromFarmId, invoice.toFarmId)
        self.invoicesById[invoice.id] = invoice
        self.outboxByFarmId[invoice.fromFarmId][invoice.id] = invoice
        self.inboxByFarmId[invoice.toFarmId][invoice.id] = invoice

        self:_registerInvoice(invoice)

        i = i + 1
    end

    xmlFile:delete()

    if next(self.invoicesById) == nil and not fileExists(seedMarker) then
        local seeded = self:_seedTestInvoicesOnce(seedMarker)
        if not seeded then
            self.seedPending = true
            Logging.info("[FIS] Seed pending (invoices file empty; waiting for >=2 farms)")
        end
    end
end


function FIS_InvoiceManager:_seedTestInvoicesOnce(seedMarkerPath)
    local farmIds = {}
    if g_farmManager ~= nil and g_farmManager.farms ~= nil then
        for farmId, _farm in pairs(g_farmManager.farms) do
            if farmId ~= FarmManager.SPECTATOR_FARM_ID then
                table.insert(farmIds, farmId)
            end
        end
    end

    table.sort(farmIds)
    if #farmIds < 2 then
        return false
    end

    local fromFarmId = farmIds[1]
    local toFarmId = farmIds[2]

    self:createInvoice(fromFarmId, toFarmId, "other", "Test invoice (seed)", {
        { itemType = "units", description = "Equipment rental", quantity = 1, unitPrice = 2500, unit = "" }
    })

    self:createInvoice(toFarmId, fromFarmId, "other", "Test invoice (seed)", {
        { itemType = "units", description = "Custom work", quantity = 2, unitPrice = 1250, unit = "" }
    })

    local f = io.open(seedMarkerPath, "w")
    if f ~= nil then
        f:write("seeded\n")
        f:close()
    end

    Logging.info("[FIS] Seeded 2 test invoices between farm %d and farm %d", fromFarmId, toFarmId)
    return true
end

function FIS_InvoiceManager:update(dt)
    if not g_currentMission:getIsServer() then
        return
    end

    if self.seedPending ~= true then
        return
    end

    local saveDir = g_currentMission.missionInfo.savegameDirectory
    if saveDir == nil then
        return
    end

    local seedMarker = saveDir .. "/fis_seeded_test_invoices.txt"
    if fileExists(seedMarker) then
        self.seedPending = false
        return
    end

    if next(self.invoicesById) ~= nil then
        self.seedPending = false
        return
    end

    if self:_seedTestInvoicesOnce(seedMarker) then
        self.seedPending = false
    end
end


function FIS_InvoiceManager:writeStream(streamId, connection)
end

function FIS_InvoiceManager:readStream(streamId, connection)
end



function FIS_InvoiceManager:checkReminders(currentDay)
    for _, invoice in pairs(self.invoicesById or {}) do
        if invoice.state == "OPEN" and invoice.dueDate ~= nil then
            if currentDay >= invoice.dueDate and
               (invoice.lastReminderDay == nil or currentDay - invoice.lastReminderDay >= self.reminderIntervalDays) then

                invoice.lastReminderDay = currentDay
                self:sendReminder(invoice)
                invoice:raiseDirtyFlags(invoice.dirtyFlag)
                invoice:raiseActive()
            end
        end
    end
end

function FIS_InvoiceManager:sendReminder(invoice)
    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_INFO,
        string.format(g_i18n:getText("fis_invoiceReminder"), invoice.id)
    )
end


function FIS_InvoiceManager:processAutoPay(currentDay)
    for _, invoice in pairs(self.invoicesById or {}) do
        if invoice.state == "OPEN" and self.autoPayEnabledByFarm and
           self.autoPayEnabledByFarm[invoice.toFarmId] then

            local farm = g_farmManager:getFarmById(invoice.toFarmId)
            if farm ~= nil and farm.money >= invoice.totalAmount then
                self:setInvoiceState(invoice, "PAID", true)
            end
        end
    end
end
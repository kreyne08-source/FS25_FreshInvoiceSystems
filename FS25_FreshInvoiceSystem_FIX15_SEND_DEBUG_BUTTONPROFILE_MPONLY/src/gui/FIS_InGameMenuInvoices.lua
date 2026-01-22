FIS_InGameMenuInvoices = {}
local FIS_InGameMenuInvoices_mt = Class(FIS_InGameMenuInvoices, TabbedMenuFrameElement)

local function fisGetPlayerFarmId()
    if g_currentMission == nil or g_farmManager == nil then
        return FarmManager.SPECTATOR_FARM_ID
    end

    if g_currentMission.player ~= nil and g_currentMission.player.farmId ~= nil then
        local id = g_currentMission.player.farmId
        if id ~= FarmManager.SPECTATOR_FARM_ID then
            return id
        end
    end

    if g_currentMission.getFarmId ~= nil then
        local id = g_currentMission:getFarmId()
        if id ~= nil and id ~= FarmManager.SPECTATOR_FARM_ID then
            return id
        end
    end

    if g_farmManager.getFarmByUserId ~= nil and g_currentMission.playerUserId ~= nil then
        local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
        if farm ~= nil and farm.farmId ~= nil and farm.farmId ~= FarmManager.SPECTATOR_FARM_ID then
            return farm.farmId
        end
    end

    if g_farmManager.getFarms ~= nil then
        for _, farm in pairs(g_farmManager:getFarms()) do
            if farm ~= nil and farm.farmId ~= nil and farm.farmId ~= FarmManager.SPECTATOR_FARM_ID then
                return farm.farmId
            end
        end
    end

    return FarmManager.SPECTATOR_FARM_ID
end

function FIS_InGameMenuInvoices.new(i18n, messageCenter)
    local self = FIS_InGameMenuInvoices:superClass().new(nil, FIS_InGameMenuInvoices_mt)
    self.i18n = i18n
    self.messageCenter = messageCenter
    self.hasCustomMenuButtons = true
    self.menuButtons = nil

    self.visibleInvoices = {}
    self.currentInvoice = nil

    self.activeTab = "invoices"

    self.viewMode = "inbox" -- "inbox" | "outbox"

    return self
end


function FIS_InGameMenuInvoices:initialize()
    self.backButtonInfo = { inputAction = InputAction.MENU_BACK }

    self.createInvoiceButtonInfo = {
		inputAction = InputAction.MENU_EXTRA_2,
        text = self.i18n:getText("ui_fis_create") or "Create invoice",
        callback = function ()
            self:onClickNewInvoice()
        end
    }

    self.deleteButtonInfo = {
        inputAction = InputAction.MENU_EXTRA_1,
        text = self.i18n:getText("ui_fis_delete") or "Delete",
        callback = function ()
            self:onClickDeleteSelected()
        end
    }

    self.activateButtonInfo = {
		inputAction = InputAction.MENU_ACTIVATE,
        text = self.i18n:getText("ui_fis_details") or "Details",
        callback = function ()
            self:onClickShowDetails()
        end
    }

    self.menuButtons = {
        self.backButtonInfo,
        self.deleteButtonInfo,
        self.createInvoiceButtonInfo,
        self.activateButtonInfo
    }

    self:setMenuButtonInfo(self.menuButtons)
    self:setMenuButtonInfoDirty()
end

function FIS_InGameMenuInvoices:onGuiSetupFinished()
    FIS_InGameMenuInvoices:superClass().onGuiSetupFinished(self)

    if self.frameBackground ~= nil then
    end
    if self.frameOverlay ~= nil then
    end

    self:setActiveTab(self.activeTab, true)

    if self.tabHistoryButton ~= nil then
        self.tabHistoryButton:setDisabled(true)
    end

    if self.invoiceTable ~= nil then
        self.invoiceTable:setDataSource(self)
        self.invoiceTable:setDelegate(self)
    end

    if self.historyTable ~= nil then
        self.historyTable:setDataSource(self)
        self.historyTable:setDelegate(self)
    end
end

function FIS_InGameMenuInvoices:onOpen()
    if FIS_InGameMenuInvoices:superClass().onOpen ~= nil then
        FIS_InGameMenuInvoices:superClass().onOpen(self)
    end

    self:updateContent()

    self:updateMenuButtonsState()
    self:setMenuButtonInfoDirty()

    if self.activeTab == "invoices" and self.invoiceTable ~= nil then
        FocusManager:setFocus(self.invoiceTable)
    elseif self.activeTab == "history" and self.historyTable ~= nil then
        FocusManager:setFocus(self.historyTable)
    end
end


function FIS_InGameMenuInvoices:requestDevSeedIfEmpty()
    return
end


function FIS_InGameMenuInvoices:updateButtons()
    local farmId = fisGetPlayerFarmId()
    if farmId == nil then
        farmId = FarmManager.SPECTATOR_FARM_ID
    end

    local canFinance = (farmId ~= FarmManager.SPECTATOR_FARM_ID) and FIS_Permissions.hasFinancePermission(farmId)

    if self.newButton ~= nil then
        self.newButton:setDisabled(not canFinance)
    end

    local canPayDecline = (self.activeTab == "invoices") and (self.viewMode == "inbox") and canFinance and self.currentInvoice ~= nil and self.currentInvoice.state == FIS_Invoice.STATE_OPEN
    if self.payButton ~= nil then
        self.payButton:setDisabled(not canPayDecline)
    end
    if self.declineButton ~= nil then
        self.declineButton:setDisabled(not canPayDecline)
    end

    self:updateMenuButtonsState()
    self:setMenuButtonInfoDirty()
end

function FIS_InGameMenuInvoices:updateMenuButtonsState()
    if self.createInvoiceButtonInfo == nil or self.deleteButtonInfo == nil or self.activateButtonInfo == nil then
        return
    end

    local farmId = fisGetPlayerFarmId()

    local canFinance = (farmId ~= FarmManager.SPECTATOR_FARM_ID) and FIS_Permissions.hasFinancePermission(farmId)

    self.createInvoiceButtonInfo.disabled = not (self.activeTab == "invoices" and canFinance)

    local inv = self.currentInvoice

    local shouldPay = false
    if self.activeTab == "invoices" and self.viewMode == "inbox" and canFinance and inv ~= nil then
        shouldPay = (inv.state == FIS_Invoice.STATE_OPEN) and (inv.toFarmId == farmId)
    end

    if shouldPay then
        self.activateButtonInfo.text = self.i18n:getText("ui_fis_pay") or "Pay"
        self.activateButtonInfo.callback = function ()
            self:onClickPay()
        end
        self.activateButtonInfo.disabled = false
    else
        self.activateButtonInfo.text = self.i18n:getText("ui_fis_details") or "Details"
        self.activateButtonInfo.callback = function ()
            self:onClickShowDetails()
        end
        self.activateButtonInfo.disabled = (inv == nil)
    end

    local canDelete = false
    if self.activeTab == "invoices" and self.viewMode == "outbox" and canFinance and inv ~= nil then
        canDelete = (inv.state == FIS_Invoice.STATE_OPEN) and (inv.fromFarmId == farmId)
    end
    self.deleteButtonInfo.disabled = not canDelete
end

function FIS_InGameMenuInvoices:updateContent()
    self.visibleInvoices = {}
    self.currentInvoice = nil

    local farmId = fisGetPlayerFarmId()
    local isSpectator = (farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID)
    if isSpectator then
        if self.activeTab == "history" then
            if self.historyTable ~= nil then
                self.historyTable:reloadData()
            end
        else
            if self.invoiceTable ~= nil then
                self.invoiceTable:reloadData()
            end
        end

        self:updateButtons()
        return
    end

    if g_fis_invoiceManager ~= nil then
        if self.activeTab == "history" then
            local inbox = g_fis_invoiceManager:getInvoicesForFarm(farmId, true) or {}
            local outbox = g_fis_invoiceManager:getInvoicesForFarm(farmId, false) or {}

            local function addFinalized(list)
                for _, inv in pairs(list) do
                    if inv ~= nil and inv.state ~= FIS_Invoice.STATE_OPEN then
                        table.insert(self.visibleInvoices, inv)
                    end
                end
            end

            addFinalized(inbox)
            addFinalized(outbox)
        else
            local src = g_fis_invoiceManager:getInvoicesForFarm(farmId, self.viewMode == "inbox")
            for _, inv in pairs(src) do
                table.insert(self.visibleInvoices, inv)
            end
        end
    end

    if self.activeTab == "invoices" and self.viewMode == "inbox" and #self.visibleInvoices == 0 and not self.devSeedLocalAdded then
        local isMultiplayer = false
        if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
            isMultiplayer = g_currentMission.missionInfo.isMultiplayer == true
        end

        if not isMultiplayer and FIS_Invoice ~= nil and FIS_Invoice.new ~= nil then
            local demo = FIS_Invoice.new(false, false)
            demo.id = 1
            demo.fromFarmId = farmId
            demo.toFarmId = farmId
            demo.category = "other"
            demo.description = "Demo invoice (layout test)"
            demo.lineItems = {
                { itemType = "units", description = "Layout seed", quantity = 1, unitPrice = 1000, unit = "" }
            }
            demo:recalculateAmount()
            demo.state = FIS_Invoice.STATE_OPEN

            table.insert(self.visibleInvoices, demo)
            self.devSeedLocalAdded = true
        end
    end

    table.sort(self.visibleInvoices, function(a, b)
        return (a.id or 0) > (b.id or 0)
    end)

    if self.activeTab == "history" then
        if self.historyTable ~= nil then
            self.historyTable:reloadData()
        end
    else
        if self.invoiceTable ~= nil then
            self.invoiceTable:reloadData()
        end
    end

    if self.fisHintText ~= nil then
        self.fisHintText:setText("#" .. tostring(#self.visibleInvoices))
    end

    self:updateButtons()
end

function FIS_InGameMenuInvoices:onListSelectionChanged(list, section, index)
    if index == nil then
        index = section
    end

    self.currentInvoice = self.visibleInvoices[index]
    self:updateButtons()
end

function FIS_InGameMenuInvoices:getNumberOfItemsInSection(list, section)
    return #self.visibleInvoices
end

function FIS_InGameMenuInvoices:populateCellForItemInSection(list, section, index, cell)
    local inv = self.visibleInvoices[index]
    if inv == nil then
        return
    end

    local function safeFarmName(farmId)
        if g_fis_invoiceManager ~= nil and g_fis_invoiceManager.getFarmName ~= nil then
            return g_fis_invoiceManager:getFarmName(farmId)
        end
        return string.format("Farm %d", tonumber(farmId) or 0)
    end

    local fromName = safeFarmName(inv.fromFarmId)
    local toName = safeFarmName(inv.toFarmId)

    cell:getAttribute("from"):setText(fromName)
    cell:getAttribute("to"):setText(toName)
    cell:getAttribute("cat"):setText(self.i18n:getText("ui_fis_cat_" .. tostring(inv.category or "other")) or tostring(inv.category or "other"))
    cell:getAttribute("amount"):setText(g_i18n:formatMoney(inv.amount or 0, 0, true, true))
    cell:getAttribute("state"):setText(inv:getStateText())
    cell:getAttribute("desc"):setText(inv.description or "")
end

function FIS_InGameMenuInvoices:getCellTypeForItemInSection(list, section, index)
    return "rowTemplate"
end

function FIS_InGameMenuInvoices:getNumberOfItems(list)
    return self:getNumberOfItemsInSection(list, 1)
end

function FIS_InGameMenuInvoices:populateCellForItem(list, index, cell)
    return self:populateCellForItemInSection(list, 1, index, cell)
end

function FIS_InGameMenuInvoices:getCellTypeForItem(list, index)
    return self:getCellTypeForItemInSection(list, 1, index)
end


function FIS_InGameMenuInvoices:setActiveTab(tabName, skipFocus)
    self.activeTab = tabName

    if self.invoicesPanel ~= nil then
        self.invoicesPanel:setVisible(tabName == "invoices")
    end
    if self.historyPanel ~= nil then
        self.historyPanel:setVisible(tabName == "history")
    end
    if self.settingsPanel ~= nil then
        self.settingsPanel:setVisible(tabName == "settings")
    end

    if self.fisButtonRow ~= nil then
        self.fisButtonRow:setVisible(tabName == "invoices")
    end
    if self.fisInboxOutboxRow ~= nil then
        self.fisInboxOutboxRow:setVisible(tabName == "invoices")
    end

    self:updateContent()

    if not skipFocus then
        if tabName == "invoices" and self.invoiceTable ~= nil then
            FocusManager:setFocus(self.invoiceTable)
        elseif tabName == "history" and self.historyTable ~= nil then
            FocusManager:setFocus(self.historyTable)
        end
    end
end

function FIS_InGameMenuInvoices:onClickTabInvoices()
    self:setActiveTab("invoices")
end

function FIS_InGameMenuInvoices:onClickTabHistory()
    return
end

function FIS_InGameMenuInvoices:onClickTabSettings()
    self:setActiveTab("settings")
end

function FIS_InGameMenuInvoices:onClickInbox()
    self.viewMode = "inbox"
    self:updateContent()

end

function FIS_InGameMenuInvoices:onClickOutbox()
    self.viewMode = "outbox"
    self:updateContent()

end

function FIS_InGameMenuInvoices:onClickNewInvoice()
    Logging.info("[FIS] onClickNewInvoice called")
    
    local farmId = fisGetPlayerFarmId()
    if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
        Logging.warning("[FIS] onClickNewInvoice: farmId is nil or spectator")
        return
    end
    Logging.info("[FIS] onClickNewInvoice: farmId=%s", tostring(farmId))

    if not FIS_Permissions.hasFinancePermission(farmId) then
        Logging.warning("[FIS] onClickNewInvoice: no finance permission")
        return
    end

    local dlg = g_gui.guis["FIS_CreateInvoiceDialog"]
    if dlg ~= nil then
        Logging.info("[FIS] onClickNewInvoice: setting callback and showing dialog")
        dlg:setCallback(self.onInvoiceCreated, self)
        g_gui:showDialog("FIS_CreateInvoiceDialog")
    else
        Logging.error("[FIS] onClickNewInvoice: FIS_CreateInvoiceDialog not found in g_gui.guis")
    end
end

function FIS_InGameMenuInvoices:onClickDeleteSelected()
    if self.currentInvoice == nil then
        return
    end

    if self.activeTab ~= "invoices" or self.viewMode ~= "outbox" then
        return
    end
    if self.currentInvoice.state ~= FIS_Invoice.STATE_OPEN then
        return
    end

    local farmId = fisGetPlayerFarmId()
    if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
        return
    end
    if not FIS_Permissions.hasFinancePermission(farmId) then
        return
    end
    if self.currentInvoice.fromFarmId ~= farmId then
        return
    end

    if g_fis_invoiceManager ~= nil and g_fis_invoiceManager.deleteInvoice ~= nil then
        g_fis_invoiceManager:deleteInvoice(self.currentInvoice.id, farmId)
    end

    self:updateContent()
end

function FIS_InGameMenuInvoices:onClickShowDetails()
    if self.currentInvoice == nil then
        return
    end

    local dlg = g_gui.guis["FIS_InvoiceDetailDialog"]
    if dlg ~= nil and dlg.setInvoice ~= nil then
        dlg:setInvoice(self.currentInvoice)
        g_gui:showDialog("FIS_InvoiceDetailDialog")
    end
end

function FIS_InGameMenuInvoices:onInvoiceCreated(toFarmId, category, desc, lineItems)
    Logging.info("[FIS] onInvoiceCreated called: toFarmId=%s, category=%s, desc=%s, lineItems=%d", 
        tostring(toFarmId), tostring(category), tostring(desc), lineItems ~= nil and #lineItems or 0)
    
    local farmId = fisGetPlayerFarmId()
    if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
        Logging.warning("[FIS] onInvoiceCreated: farmId is nil or spectator")
        return
    end
    Logging.info("[FIS] onInvoiceCreated: farmId=%s", tostring(farmId))

    if g_fis_invoiceManager ~= nil then
        Logging.info("[FIS] onInvoiceCreated: calling g_fis_invoiceManager:createInvoice")
        g_fis_invoiceManager:createInvoice(farmId, toFarmId, category, desc, lineItems)
        self:updateContent()
    else
        Logging.error("[FIS] onInvoiceCreated: g_fis_invoiceManager is nil!")
    end
end

function FIS_InGameMenuInvoices:onClickPay()
    if self.currentInvoice == nil then
        return
    end
    local farmId = fisGetPlayerFarmId()
    if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
        return
    end
    if not FIS_Permissions.hasFinancePermission(farmId) then
        return
    end
    if g_fis_invoiceManager ~= nil then
        g_fis_invoiceManager:setInvoiceState(self.currentInvoice.id, FIS_Invoice.STATE_PAID, farmId)
    end
    self:updateContent()

end

function FIS_InGameMenuInvoices:onClickDecline()
    if self.currentInvoice == nil then
        return
    end
    local farmId = fisGetPlayerFarmId()
    if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
        return
    end
    if not FIS_Permissions.hasFinancePermission(farmId) then
        return
    end
    if g_fis_invoiceManager ~= nil then
        g_fis_invoiceManager:setInvoiceState(self.currentInvoice.id, FIS_Invoice.STATE_DECLINED, farmId)
    end
    self:updateContent()

end

FIS_CreateInvoiceDialog = {}
local FIS_CreateInvoiceDialog_mt = Class(FIS_CreateInvoiceDialog, MessageDialog)

local UNIT_CHOICES = {
    { type = "units", textKey = "ui_fis_unit_units", unit = "" },
    { type = "liters", textKey = "ui_fis_unit_liters", unit = "L" },
    { type = "hours", textKey = "ui_fis_unit_hours", unit = "h" },
}

local function trim(s)
    s = s or ""
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function fisResolveMyFarm()
    if g_farmManager == nil or g_currentMission == nil then
        return nil
    end

    if g_currentMission.player ~= nil and g_currentMission.player.farmId ~= nil then
        local farm = g_farmManager.getFarmById ~= nil and g_farmManager:getFarmById(g_currentMission.player.farmId) or nil
        if farm ~= nil then
            return farm
        end
    end

    if g_currentMission.playerUserId ~= nil and g_currentMission.playerUserId ~= 0 and g_farmManager.getFarmByUserId ~= nil then
        local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
        if farm ~= nil then
            return farm
        end
    end

    if g_currentMission.getFarmId ~= nil then
        local id = g_currentMission:getFarmId()
        if id ~= nil and id ~= FarmManager.SPECTATOR_FARM_ID and g_farmManager.getFarmById ~= nil then
            local farm = g_farmManager:getFarmById(id)
            if farm ~= nil then
                return farm
            end
        end
    end

    if g_farmManager.getFarms ~= nil then
        for _, farm in pairs(g_farmManager:getFarms()) do
            if farm ~= nil and farm.farmId ~= nil and farm.farmId ~= FarmManager.SPECTATOR_FARM_ID then
                return farm
            end
        end
    end

    return nil
end

local function toNumberOrZero(s)
    if s == nil then
        return 0
    end
    s = tostring(s):gsub(",", "")
    return tonumber(s) or 0
end

local function sanitizeDecimalText(text, maxDecimals)
    text = tostring(text or "")
    text = text:gsub(",", ".")

    text = text:gsub("[^0-9\.]", "")

    local firstDot = text:find("%.")
    if firstDot ~= nil then
        local before = text:sub(1, firstDot)
        local after = text:sub(firstDot + 1):gsub("%.", "")
        text = before .. after

        if maxDecimals ~= nil then
            local intPart = text:sub(1, firstDot - 1)
            local decPart = text:sub(firstDot + 1)
            if #decPart > maxDecimals then
                decPart = decPart:sub(1, maxDecimals)
            end
            text = intPart .. "." .. decPart
        end
    end

    if text:match("^0+[0-9]") and not text:match("^0%.") then
        text = tostring(tonumber(text) or 0)
    end

    return text
end

function FIS_CreateInvoiceDialog:_syncLineItemsFromUI()
    self.lineItems = {}
    for i = 1, 5 do
        local d = trim(self["itemDesc" .. i]:getText())
        local q = toNumberOrZero(self["itemQty" .. i]:getText())
        local p = toNumberOrZero(self["itemPrice" .. i]:getText())
        if d ~= "" then
            local unitIndex = self["itemUnit" .. i]:getState() or 1
            local u = UNIT_CHOICES[unitIndex] or UNIT_CHOICES[1]
            table.insert(self.lineItems, {
                itemType = u.type,
                description = d,
                quantity = q,
                unitPrice = p,
                unit = u.unit
            })
        end
    end
end

function FIS_CreateInvoiceDialog:_renderLineItemsToUI()
    for i = 1, 5 do
        local item = self.lineItems[i]
        if item ~= nil then
            self["itemDesc" .. i]:setText(item.description or "")
            self["itemQty" .. i]:setText(tostring(item.quantity or ""))
            self["itemPrice" .. i]:setText(tostring(item.unitPrice or ""))

            local unitIndex = 1
            for u = 1, #UNIT_CHOICES do
                if UNIT_CHOICES[u].type == (item.itemType or "units") then
                    unitIndex = u
                    break
                end
            end
            self["itemUnit" .. i]:setState(unitIndex)
        else
            self["itemDesc" .. i]:setText("")
            self["itemQty" .. i]:setText("")
            self["itemPrice" .. i]:setText("")
            self["itemUnit" .. i]:setState(1)
        end
    end
end

function FIS_CreateInvoiceDialog:clearLineItems()
    self.lineItems = {}
    self:_renderLineItemsToUI()
    self:updateTotals()
end

function FIS_CreateInvoiceDialog:addLineItem(description, quantity, unitType, unitPrice)
    description = trim(description)
    if description == "" then
        return false
    end

    self:_syncLineItemsFromUI()

    if #self.lineItems >= 5 then
        return false
    end

    local chosenType = unitType or "units"
    local unit = ""
    for _, u in ipairs(UNIT_CHOICES) do
        if u.type == chosenType then
            unit = u.unit
            break
        end
    end

    table.insert(self.lineItems, {
        itemType = chosenType,
        description = description,
        quantity = tonumber(quantity) or 0,
        unitPrice = tonumber(unitPrice) or 0,
        unit = unit
    })

    self:_renderLineItemsToUI()
    self:updateTotals()
    return true
end

function FIS_CreateInvoiceDialog:updateTotals()
    self:_syncLineItemsFromUI()

    local total = 0
    for _, item in ipairs(self.lineItems) do
        total = total + ((tonumber(item.quantity) or 0) * (tonumber(item.unitPrice) or 0))
    end
    self.totalText:setText(g_i18n:formatMoney(total, 0, true, true))
end

function FIS_CreateInvoiceDialog.new(i18n, messageCenter)
    local self = MessageDialog.new(nil, FIS_CreateInvoiceDialog_mt)
    self.i18n = i18n
    self.messageCenter = messageCenter
    self.callbackFunc = nil
    self.callbackTarget = nil

    self.farmIds = {}
    self.categoryKeys = {}
    self.presetKeys = {}

    self.lineItems = {}

    return self
end

function FIS_CreateInvoiceDialog:setCallback(callbackFunc, target)
    self.callbackFunc = callbackFunc
    self.callbackTarget = target
end

function FIS_CreateInvoiceDialog:onOpen()
    FIS_CreateInvoiceDialog:superClass().onOpen(self)

    self.errorText:setText("")
    self.descInput:setText("")

    local farm = fisResolveMyFarm()
    local canFinance = farm ~= nil and FIS_Permissions.hasFinancePermission(farm.farmId)

    if self.sendButton ~= nil then
        self.sendButton:setDisabled(not canFinance)
    end

    if not canFinance then
        self.errorText:setText(self.i18n:getText("ui_fis_err_permission"))
    end

    self:populateFarmDropdown()
    self:populateCategoryDropdown()
    self:populatePresetDropdown()
    self:populateItemDropdown()
    self:populateUnitDropdowns()

    for i = 1, 5 do
        if self["itemDesc" .. i] ~= nil then
            self["itemDesc" .. i]:setDisabled(false)
        end
        if self["itemQty" .. i] ~= nil then
            self["itemQty" .. i]:setDisabled(false)
        end
        if self["itemPrice" .. i] ~= nil then
            self["itemPrice" .. i]:setDisabled(false)
        end
    end

    self:clearLineItems()

    if self.itemOption ~= nil then
        local state = self.itemOption.state or 1
        self:onItemChanged(state)
    end

    FocusManager:setFocus(self.toFarmOption)
end


function FIS_CreateInvoiceDialog:populateFarmDropdown()
    self.farmItems = {}
    self.farmIds = {}

    local myFarm = fisResolveMyFarm()
    local playerFarmId = myFarm ~= nil and myFarm.farmId or (g_currentMission ~= nil and g_currentMission:getFarmId() or FarmManager.SPECTATOR_FARM_ID)

    local entries = {}
    if g_farmManager ~= nil and g_farmManager.farms ~= nil then
        for farmId, farm in pairs(g_farmManager.farms) do
            if farm ~= nil and farm.isSpectator == false and farmId ~= playerFarmId then
                table.insert(entries, { name = farm.name or tostring(farmId), id = farmId })
            end
        end
    end

    table.sort(entries, function(a, b)
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)

    for _, e in ipairs(entries) do
        table.insert(self.farmItems, e.name)
        table.insert(self.farmIds, e.id)
    end

    if #self.farmItems == 0 then
        self.farmItems = { g_i18n:getText("ui_fis_noRecipientFarms") }
        self.farmIds = { nil }
    end

    self.toFarmOption:setTexts(self.farmItems)
    self.toFarmOption:setState(1)
end

function FIS_CreateInvoiceDialog:populateCategoryDropdown()
    self.categoryKeys = {}
    local texts = {}
    for _, c in ipairs(FIS_Presets.CATEGORIES) do
        table.insert(self.categoryKeys, c.key)
        table.insert(texts, self.i18n:getText(c.i18n))
    end
    self.categoryOption:setTexts(texts)
    self.categoryOption:setState(1)
end

function FIS_CreateInvoiceDialog:populatePresetDropdown()
    self.presetKeys = {}
    local texts = {}
    for _, p in ipairs(FIS_Presets.PRESETS) do
        table.insert(self.presetKeys, p.key)
        table.insert(texts, self.i18n:getText(p.i18n))
    end
    self.presetOption:setTexts(texts)
    self.presetOption:setState(1)
end


function FIS_CreateInvoiceDialog:_buildMarketItemList()
    local items = {}

    local em = g_currentMission ~= nil and g_currentMission.economyManager or nil
    local function getPricePerLiter(fillTypeIndex)
        if em ~= nil then
            if em.getPricePerLiter ~= nil then
                return em:getPricePerLiter(fillTypeIndex) or 0
            end
            if em.getPricePerUnit ~= nil then
                return em:getPricePerUnit(fillTypeIndex) or 0
            end
        end
        return 0
    end

    local function addFillType(fillTypeIndex, label, unitType, unitIndex, unitSuffix)
        local price = getPricePerLiter(fillTypeIndex)
        local suffix = unitSuffix or ""
        local text = string.format("%s ($%.2f%s)", label, price, suffix)
        items[#items + 1] = {
            description = label,
            text = text,
            fillTypeIndex = fillTypeIndex,
            unitType = unitType,
            unitIndex = unitIndex,
            unitPrice = price,
            sortKey = (label or ""):lower()
        }
    end

    if g_fillTypeManager ~= nil then
        local dieselIndex = FillType ~= nil and FillType.DIESEL or nil
        if dieselIndex ~= nil then
            local ft = g_fillTypeManager:getFillTypeByIndex(dieselIndex)
            local label = (ft ~= nil and ft.title) or "Diesel"
            addFillType(dieselIndex, label, "liters", 2, "/L")
        end
    end

    if g_fruitTypeManager ~= nil and g_fillTypeManager ~= nil then
        for _, fruitType in pairs(g_fruitTypeManager:getFruitTypes()) do
            if fruitType ~= nil and fruitType.fillType ~= nil then
                local ft = g_fillTypeManager:getFillTypeByIndex(fruitType.fillType)
                if ft ~= nil and ft.index ~= nil and ft.showOnPriceTable ~= false then
                    local label = ft.title or fruitType.name or ("FillType " .. tostring(ft.index))
                    addFillType(ft.index, label, "liters", 2, "/L")
                end
            end
        end
    end

    table.sort(items, function(a, b) return a.sortKey < b.sortKey end)
    return items
end

function FIS_CreateInvoiceDialog:populateItemDropdown()
    if self.itemOption == nil then
        return
    end

    self.itemOption:setCallback("onItemChanged", self)

    self.marketItems = self:_buildMarketItemList()
    local texts = {}

    if self.marketItems == nil or #self.marketItems == 0 then
        local t = self.i18n:getText("ui_fis_noMarketItems")
        texts = { t }
        self.marketItems = { { description = t, text = t, unitType = "units", unitIndex = 1, unitPrice = 0 } }
        self.itemOption:setTexts(texts)
        self.itemOption:setState(1)
        return
    end

    for _, it in ipairs(self.marketItems) do
        texts[#texts + 1] = it.text
    end

    self.itemOption:setTexts(texts)
    self.itemOption:setState(1)
end

function FIS_CreateInvoiceDialog:onItemChanged(state)
    if self.marketItems == nil or self.marketItems[state] == nil then
        return
    end

    local it = self.marketItems[state]

    if self.itemDesc1 ~= nil then
        self.itemDesc1:setText(it.description or "")
    end
    if self.itemQty1 ~= nil then
        self.itemQty1:setText("1")
    end
    if self.itemPrice1 ~= nil then
        self.itemPrice1:setText(string.format("%.2f", tonumber(it.unitPrice) or 0))
    end
    if self.itemUnit1 ~= nil then
        self.itemUnit1:setState(it.unitIndex or 1)
    end

    self:updateTotals()
end

function FIS_CreateInvoiceDialog:onClickAddSelectedItem()
    if self.marketItems == nil or self.itemOption == nil then
        return
    end

    local idx = self.itemOption:getState()
    local it = self.marketItems[idx]
    if it == nil then
        return
    end

    self:addLineItem(it.description, 1, it.unitType, it.unitPrice)
end

function FIS_CreateInvoiceDialog:populateUnitDropdowns()





    local texts = {}
    for _, u in ipairs(UNIT_CHOICES) do
        table.insert(texts, self.i18n:getText(u.textKey))
    end
    for i = 1, 5 do
        self["itemUnit" .. i]:setTexts(texts)
        self["itemUnit" .. i]:setState(1)
    end
end

function FIS_CreateInvoiceDialog:onPresetChanged()
    local idx = self.presetOption:getState() or 1
    local key = self.presetKeys[idx] or "custom"
    local preset = nil
    for _, p in ipairs(FIS_Presets.PRESETS) do
        if p.key == key then
            preset = p
            break
        end
    end
    if preset == nil then
        return
    end

    local catIndex = FIS_Presets.getCategoryIndexByKey(preset.category or "other")
    self.categoryOption:setState(catIndex)

    self.lineItems = {}
    if preset.lineItems ~= nil then
        for i, item in ipairs(preset.lineItems) do
            if i > 5 then break end
            local it = item.itemType or "units"
            local unit = ""
            for _, u in ipairs(UNIT_CHOICES) do
                if u.type == it then
                    unit = u.unit
                    break
                end
            end
            table.insert(self.lineItems, {
                itemType = it,
                description = item.description or "",
                quantity = tonumber(item.quantity) or 0,
                unitPrice = tonumber(item.unitPrice) or 0,
                unit = unit
            })
        end
    end
    self:_renderLineItemsToUI()
    self:updateTotals()
end

function FIS_CreateInvoiceDialog:onOptionChanged()
    self.errorText:setText("")
end

function FIS_CreateInvoiceDialog:onLineQtyChanged(element)
    if self._fisSanitizingText then
        return
    end
    self._fisSanitizingText = true

    local cleaned = sanitizeDecimalText(element ~= nil and element:getText() or "", 3)
    if element ~= nil then
        element:setText(cleaned)
    end

    self._fisSanitizingText = false
    self.errorText:setText("")
    self:updateTotals()
end

function FIS_CreateInvoiceDialog:onLinePriceChanged(element)
    if self._fisSanitizingText then
        return
    end
    self._fisSanitizingText = true

    local cleaned = sanitizeDecimalText(element ~= nil and element:getText() or "", 3)
    if element ~= nil then
        element:setText(cleaned)
    end

    self._fisSanitizingText = false
    self.errorText:setText("")
    self:updateTotals()
end

function FIS_CreateInvoiceDialog:onTextChanged()
    self.errorText:setText("")
    self:updateTotals()
end

function FIS_CreateInvoiceDialog:onClickCancel()
    self:close()
end

function FIS_CreateInvoiceDialog:onClickSend()
    local myFarm = fisResolveMyFarm()
    if myFarm == nil then
        self.errorText:setText(self.i18n:getText("ui_fis_err_farm"))
        return
    end
    if not FIS_Permissions.hasFinancePermission(myFarm.farmId) then
        self.errorText:setText(self.i18n:getText("ui_fis_err_permission"))
        return
    end

    local toIndex = self.toFarmOption:getState() or 1
    local toFarmId = self.farmIds[toIndex] or 0
    if toFarmId == 0 then
        self.errorText:setText(self.i18n:getText("ui_fis_err_selectFarm"))
        return
    end

    local catIndex = self.categoryOption:getState() or 1
    local category = self.categoryKeys[catIndex] or "other"

    local desc = trim(self.descInput:getText() or "")
    if desc == "" then
        self.errorText:setText(self.i18n:getText("ui_fis_err_desc"))
        return
    end

    self:_syncLineItemsFromUI()
    local lineItems = self.lineItems
    if #lineItems == 0 then
        self.errorText:setText(self.i18n:getText("ui_fis_err_lineItems"))
        return
    end

    local total = 0
    for _, item in ipairs(lineItems) do
        total = total + ((tonumber(item.quantity) or 0) * (tonumber(item.unitPrice) or 0))
    end
    if total <= 0 then
        self.errorText:setText(self.i18n:getText("ui_fis_err_amount"))
        return
    end

    self:close()

    -- Execute callback with error handling
    if self.callbackFunc ~= nil then
        local success, err = pcall(function()
            self.callbackFunc(self.callbackTarget, toFarmId, category, desc, lineItems)
        end)
        
        if not success then
            if Logging ~= nil and Logging.error ~= nil then
                Logging.error("[FIS] Error in invoice creation callback: %s", tostring(err))
            end
            -- Show error to user if dialog is still open
            if self.errorText ~= nil and self.errorText.setText ~= nil then
                local textSuccess, textErr = pcall(function()
                    self.errorText:setText("Error creating invoice. Check log for details.")
                end)
                if not textSuccess and Logging ~= nil and Logging.warning ~= nil then
                    Logging.warning("[FIS] Could not display error text to user: %s", tostring(textErr))
                end
            end
        end
    end
end


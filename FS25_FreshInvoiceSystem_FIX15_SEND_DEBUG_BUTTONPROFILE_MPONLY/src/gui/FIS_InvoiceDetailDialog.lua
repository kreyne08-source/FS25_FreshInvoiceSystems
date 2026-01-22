FIS_InvoiceDetailDialog = {}
local FIS_InvoiceDetailDialog_mt = Class(FIS_InvoiceDetailDialog, MessageDialog)

function FIS_InvoiceDetailDialog.new(i18n, messageCenter)
    local self = MessageDialog.new(nil, FIS_InvoiceDetailDialog_mt)
    self.i18n = i18n
    self.messageCenter = messageCenter
    self.invoice = nil
    return self
end

function FIS_InvoiceDetailDialog:setInvoice(invoice)
    self.invoice = invoice
end

function FIS_InvoiceDetailDialog:onOpen()
    FIS_InvoiceDetailDialog:superClass().onOpen(self)

    if self.invoice == nil then
        return
    end

    local inv = self.invoice

    local function safeFarmName(farmId)
        if g_fis_invoiceManager ~= nil and g_fis_invoiceManager.getFarmName ~= nil then
            return g_fis_invoiceManager:getFarmName(farmId)
        end
        return string.format("Farm %d", tonumber(farmId) or 0)
    end

    if self.titleText ~= nil then
        self.titleText:setText(self.i18n:getText("ui_fis_details") or "Invoice details")
    end
    if self.idText ~= nil then
        self.idText:setText(string.format("#%s", tostring(inv.id or "")))
    end
    if self.fromText ~= nil then
        self.fromText:setText(safeFarmName(inv.fromFarmId))
    end
    if self.toText ~= nil then
        self.toText:setText(safeFarmName(inv.toFarmId))
    end
    if self.categoryText ~= nil then
        local catKey = "ui_fis_cat_" .. tostring(inv.category or "other")
        self.categoryText:setText(self.i18n:getText(catKey) or tostring(inv.category or "other"))
    end
    if self.amountText ~= nil then
        self.amountText:setText(g_i18n:formatMoney(inv.amount or 0, 0, true, true))
    end
    if self.stateText ~= nil and inv.getStateText ~= nil then
        self.stateText:setText(inv:getStateText())
    end
    if self.descText ~= nil then
        self.descText:setText(inv.description or "")
    end
end

function FIS_InvoiceDetailDialog:onClickClose()
    self:close()
end

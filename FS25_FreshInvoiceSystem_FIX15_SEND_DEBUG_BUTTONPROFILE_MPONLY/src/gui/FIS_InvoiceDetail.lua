
FIS_InvoiceDetail = {}
local FIS_InvoiceDetail_mt = Class(FIS_InvoiceDetail)

function FIS_InvoiceDetail.new()
    local self = setmetatable({}, FIS_InvoiceDetail_mt)
    self.isExpanded = true
    return self
end

function FIS_InvoiceDetail:setInvoice(invoice)
    self.invoice = invoice
    self:updateView()
end

function FIS_InvoiceDetail:toggleCollapse()
    self.isExpanded = not self.isExpanded
    self.lineItemList:setVisible(self.isExpanded)
end

function FIS_InvoiceDetail:updateView()
    if self.invoice == nil then return end

    local subtotal = 0
    for _, item in ipairs(self.invoice.lineItems or {}) do
        subtotal = subtotal + (item.qty * item.unitPrice)
    end

    self.subtotal:setText(string.format("$%.2f", subtotal))
    self.total:setText(string.format("$%.2f", subtotal))

    if self.invoice:isOverdue(g_currentMission.environment.currentDay) then
        self.overdueWarning:setVisible(true)
        self.overdueWarning:setText(g_i18n:getText("fis_invoiceOverdue"))
    else
        self.overdueWarning:setVisible(false)
    end
end

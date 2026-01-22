
FIS_Tax = {}

FIS_Tax.rules = {
    GOODS = 0.07,
    SERVICE = 0.05,
    FIELDWORK = 0.0,
    RENTAL = 0.06
}

function FIS_Tax.calculate(invoice)
    local rate = FIS_Tax.rules[invoice.category] or 0
    invoice.taxAmount = invoice.subtotal * rate
    return invoice.taxAmount
end

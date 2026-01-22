
FIS_AIDebt = {}

function FIS_AIDebt.process(farm, invoices)
    for _, invoice in ipairs(invoices) do
        if invoice.state == "OVERDUE" then
            farm.trust = math.max((farm.trust or 1) - 0.1, 0)
        end
    end
end

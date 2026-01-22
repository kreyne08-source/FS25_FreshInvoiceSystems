
FIS_FinancialReports = {}

function FIS_FinancialReports.generateForFarm(farmId)
    local report = {
        income = 0,
        expenses = 0,
        paidInvoices = 0,
        overdueInvoices = 0
    }

    for _, invoice in pairs(g_fis_invoiceManager.invoicesById or {}) do
        if invoice.fromFarmId == farmId and invoice.state == "PAID" then
            report.income = report.income + invoice.totalAmount
            report.paidInvoices = report.paidInvoices + 1
        end
        if invoice.toFarmId == farmId then
            if invoice.state == "PAID" then
                report.expenses = report.expenses + invoice.totalAmount
            elseif invoice:isOverdue(g_currentMission.environment.currentDay) then
                report.overdueInvoices = report.overdueInvoices + 1
            end
        end
    end

    return report
end

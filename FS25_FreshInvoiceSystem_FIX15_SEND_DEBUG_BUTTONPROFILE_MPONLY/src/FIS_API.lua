
FIS_API = {}

function FIS_API.createInvoice(fromFarmId, toFarmId, data)
    g_fis_invoiceManager:createInvoice(fromFarmId, toFarmId, data)
end

function FIS_API.registerContractInvoice(contract, completingFarmId)
    FIS_createInvoiceFromContract(contract, completingFarmId)
end

function FIS_API.getFinancialReport(farmId)
    return FIS_FinancialReports.generateForFarm(farmId)
end

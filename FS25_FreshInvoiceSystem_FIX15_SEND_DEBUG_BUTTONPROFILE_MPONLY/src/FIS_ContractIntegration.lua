

function FIS_createInvoiceFromContract(contract, farmId)
    local invoiceData = {
        category = "SERVICE",
        dueDate = g_currentMission.environment.currentDay + 7,
        lineItems = {
            {
                desc = contract:getName(),
                qty = contract.reward,
                unitType = "GOODS",
                unitPrice = 1
            }
        }
    }

    g_fis_invoiceManager:createInvoice(
        contract:getOwnerFarmId(),
        farmId,
        invoiceData
    )
end

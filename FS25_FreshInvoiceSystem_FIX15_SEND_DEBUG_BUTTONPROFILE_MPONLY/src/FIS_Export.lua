
FIS_Export = {}

function FIS_Export.exportCSV(path)
    local file = io.open(path, "w")
    file:write("InvoiceId,FromFarm,ToFarm,Subtotal,Tax,Total,State\n")
    for _, inv in pairs(g_fis_invoiceManager.invoicesById) do
        file:write(string.format(
            "%d,%d,%d,%.2f,%.2f,%.2f,%s\n",
            inv.id, inv.fromFarmId, inv.toFarmId,
            inv.subtotal or 0, inv.taxAmount or 0,
            inv.totalAmount or 0, inv.state
        ))
    end
    file:close()
end

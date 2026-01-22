
FIS_Presets = {}

FIS_Presets.CATEGORIES = {
    { key = "service",  i18n = "ui_fis_cat_service" },
    { key = "goods",    i18n = "ui_fis_cat_goods" },
    { key = "rental",   i18n = "ui_fis_cat_rental" },
    { key = "contract", i18n = "ui_fis_cat_contract" },
    { key = "other",    i18n = "ui_fis_cat_other" }
}

FIS_Presets.PRESETS = {
    {
        key = "custom",
        i18n = "ui_fis_preset_custom",
        category = "other",
        header = "",
        lineItems = {}
    },
    {
        key = "fieldwork_hours",
        i18n = "ui_fis_preset_fieldwork_hours",
        category = "service",
        header = "",
        lineItems = {
            { itemType = "hours", description = "Fieldwork", quantity = 1, unitPrice = 0, unit = "h" }
        }
    },
    {
        key = "transport",
        i18n = "ui_fis_preset_transport",
        category = "service",
        header = "",
        lineItems = {
            { itemType = "units", description = "Transport", quantity = 1, unitPrice = 0, unit = "job" }
        }
    },
    {
        key = "liquid_liters",
        i18n = "ui_fis_preset_liquid_liters",
        category = "goods",
        header = "",
        lineItems = {
            { itemType = "liters", description = "Liquid", quantity = 1000, unitPrice = 0, unit = "L" }
        }
    },
    {
        key = "bales",
        i18n = "ui_fis_preset_bales",
        category = "goods",
        header = "",
        lineItems = {
            { itemType = "units", description = "Bales", quantity = 1, unitPrice = 0, unit = "bale" }
        }
    }
}

function FIS_Presets.getCategoryIndexByKey(key)
    for i, c in ipairs(FIS_Presets.CATEGORIES) do
        if c.key == key then
            return i
        end
    end
    return 1
end

function FIS_Presets.getPresetIndexByKey(key)
    for i, p in ipairs(FIS_Presets.PRESETS) do
        if p.key == key then
            return i
        end
    end
    return 1
end

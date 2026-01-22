-- Unit tests for FIS_CreateInvoiceDialog callback functionality
local helper = require("tests.test_helper")

describe("FIS_CreateInvoiceDialog", function()
    local FIS_CreateInvoiceDialog
    
    before_each(function()
        helper.setupMocks()
        helper.setupTestFarms()
        
        -- Mock MessageDialog
        _G.MessageDialog = {
            new = function(parent, mt)
                local self = setmetatable({}, mt)
                return self
            end,
            onOpen = function(self) end,
            close = function(self) end
        }
        
        -- Mock FIS_Permissions
        _G.FIS_Permissions = {
            hasFinancePermission = function(farmId)
                return farmId == 1 or farmId == 2
            end
        }
        
        -- Mock FIS_Presets
        _G.FIS_Presets = {
            CATEGORIES = {
                { key = "service", i18n = "ui_fis_cat_service" },
                { key = "goods", i18n = "ui_fis_cat_goods" },
                { key = "other", i18n = "ui_fis_cat_other" }
            },
            PRESETS = {
                { key = "custom", i18n = "ui_fis_preset_custom" }
            },
            getCategoryIndexByKey = function(key)
                for i, cat in ipairs(_G.FIS_Presets.CATEGORIES) do
                    if cat.key == key then return i end
                end
                return 3
            end
        }
        
        -- Setup player farm
        g_currentMission.player = {
            farmId = 1
        }
        
        -- Load the module
        dofile(helper.MOD_SOURCE_PATH .. "gui/FIS_CreateInvoiceDialog.lua")
        FIS_CreateInvoiceDialog = _G.FIS_CreateInvoiceDialog
    end)
    
    describe("setCallback()", function()
        it("should set callback function and target", function()
            local dialog = FIS_CreateInvoiceDialog.new(g_i18n, nil)
            
            local targetObj = { name = "test" }
            local callbackFunc = function() end
            
            dialog:setCallback(callbackFunc, targetObj)
            
            assert.equals(callbackFunc, dialog.callbackFunc)
            assert.equals(targetObj, dialog.callbackTarget)
        end)
    end)
    
    describe("onClickSend() validation", function()
        local dialog
        
        before_each(function()
            dialog = FIS_CreateInvoiceDialog.new(g_i18n, nil)
            
            -- Set up line items first
            dialog.lineItems = helper.createTestLineItems()
            
            -- Mock all required UI elements for _syncLineItemsFromUI to read from lineItems
            for i = 1, 5 do
                local item = dialog.lineItems[i]
                dialog["itemDesc" .. i] = { 
                    setText = function() end, 
                    getText = function() return item and item.description or "" end 
                }
                dialog["itemQty" .. i] = { 
                    setText = function() end, 
                    getText = function() return item and tostring(item.quantity) or "0" end 
                }
                dialog["itemPrice" .. i] = { 
                    setText = function() end, 
                    getText = function() return item and tostring(item.unitPrice) or "0" end 
                }
                dialog["itemUnit" .. i] = { 
                    setState = function() end, 
                    getState = function() return item and (item.itemType == "liters" and 2 or 1) or 1 end 
                }
            end
            dialog.totalText = { setText = function() end }
            
            -- Mock UI elements
            dialog.errorText = {
                setText = function(self, text)
                    dialog._errorText = text
                end
            }
            
            dialog.toFarmOption = {
                getState = function() return 1 end
            }
            dialog.farmIds = { 2 }
            
            dialog.categoryOption = {
                getState = function() return 1 end
            }
            dialog.categoryKeys = { "service" }
            
            dialog.descInput = {
                getText = function() return "Test Description" end
            }
        end)
        
        it("should validate and call callback when all fields are valid", function()
            local callbackCalled = false
            local receivedToFarmId, receivedCategory, receivedDesc, receivedItems
            
            dialog:setCallback(function(target, toFarmId, category, desc, lineItems)
                callbackCalled = true
                receivedToFarmId = toFarmId
                receivedCategory = category
                receivedDesc = desc
                receivedItems = lineItems
            end, nil)
            
            dialog:onClickSend()
            
            assert.is_true(callbackCalled)
            assert.equals(2, receivedToFarmId)
            assert.equals("service", receivedCategory)
            assert.equals("Test Description", receivedDesc)
            assert.is_table(receivedItems)
            assert.equals(2, #receivedItems)
        end)
        
        it("should reject when toFarmId is 0", function()
            dialog.farmIds = { 0 }
            
            local callbackCalled = false
            dialog:setCallback(function() callbackCalled = true end, nil)
            
            dialog:onClickSend()
            
            assert.is_false(callbackCalled)
            assert.is_not_nil(dialog._errorText)
        end)
        
        it("should reject when description is empty", function()
            dialog.descInput.getText = function() return "" end
            
            local callbackCalled = false
            dialog:setCallback(function() callbackCalled = true end, nil)
            
            dialog:onClickSend()
            
            assert.is_false(callbackCalled)
            assert.is_not_nil(dialog._errorText)
        end)
        
        it("should reject when lineItems are empty", function()
            dialog.lineItems = {}
            
            -- Update UI mocks to return empty values
            for i = 1, 5 do
                dialog["itemDesc" .. i].getText = function() return "" end
                dialog["itemQty" .. i].getText = function() return "0" end
                dialog["itemPrice" .. i].getText = function() return "0" end
            end
            
            local callbackCalled = false
            dialog:setCallback(function() callbackCalled = true end, nil)
            
            dialog:onClickSend()
            
            assert.is_false(callbackCalled)
            assert.is_not_nil(dialog._errorText)
        end)
        
        it("should reject when total amount is zero", function()
            dialog.lineItems = {
                { quantity = 0, unitPrice = 100 },
                { quantity = 10, unitPrice = 0 }
            }
            
            -- Update UI mocks to return zero values
            dialog["itemDesc1"].getText = function() return "Item 1" end
            dialog["itemQty1"].getText = function() return "0" end
            dialog["itemPrice1"].getText = function() return "100" end
            
            dialog["itemDesc2"].getText = function() return "Item 2" end
            dialog["itemQty2"].getText = function() return "10" end
            dialog["itemPrice2"].getText = function() return "0" end
            
            local callbackCalled = false
            dialog:setCallback(function() callbackCalled = true end, nil)
            
            dialog:onClickSend()
            
            assert.is_false(callbackCalled)
            assert.is_not_nil(dialog._errorText)
        end)
        
        it("should not call callback if callback is nil", function()
            dialog.callbackFunc = nil
            
            -- Should not crash when callback is nil
            dialog:onClickSend()
            
            -- Test passes if no error is raised
            assert.is_true(true)
        end)
    end)
    
    describe("addLineItem()", function()
        it("should add a line item successfully", function()
            local dialog = FIS_CreateInvoiceDialog.new(g_i18n, nil)
            
            -- Mock the methods that interact with UI
            dialog._renderLineItemsToUI = function() end
            dialog._syncLineItemsFromUI = function() end
            dialog.updateTotals = function() end
            
            -- Add line item directly without UI sync
            local success = dialog:addLineItem("Test Item", 10, "units", 50)
            
            assert.is_true(success)
            assert.equals(1, #dialog.lineItems)
            assert.equals("Test Item", dialog.lineItems[1].description)
            assert.equals(10, dialog.lineItems[1].quantity)
            assert.equals(50, dialog.lineItems[1].unitPrice)
        end)
        
        it("should reject empty description", function()
            local dialog = FIS_CreateInvoiceDialog.new(g_i18n, nil)
            
            dialog._renderLineItemsToUI = function() end
            dialog._syncLineItemsFromUI = function() end
            dialog.updateTotals = function() end
            
            local success = dialog:addLineItem("", 10, "units", 50)
            
            assert.is_false(success)
            assert.equals(0, #dialog.lineItems)
        end)
        
        it("should reject when 5 items already exist", function()
            local dialog = FIS_CreateInvoiceDialog.new(g_i18n, nil)
            
            dialog._renderLineItemsToUI = function() end
            dialog._syncLineItemsFromUI = function() end
            dialog.updateTotals = function() end
            
            -- Add 5 items
            for i = 1, 5 do
                dialog:addLineItem("Item " .. i, 1, "units", 10)
            end
            
            -- Try to add 6th item
            local success = dialog:addLineItem("Item 6", 1, "units", 10)
            
            assert.is_false(success)
            assert.equals(5, #dialog.lineItems)
        end)
    end)
    
    describe("updateTotals()", function()
        it("should calculate and display correct total", function()
            local dialog = FIS_CreateInvoiceDialog.new(g_i18n, nil)
            
            -- Mock _syncLineItemsFromUI to not clear lineItems
            dialog._syncLineItemsFromUI = function() end
            
            local displayedTotal = nil
            dialog.totalText = {
                setText = function(self, text)
                    displayedTotal = text
                end
            }
            
            dialog.lineItems = {
                { quantity = 10, unitPrice = 100 },
                { quantity = 5, unitPrice = 50 }
            }
            
            dialog:updateTotals()
            
            -- Total should be (10*100) + (5*50) = 1250
            assert.is_not_nil(displayedTotal)
            assert.is_true(string.find(displayedTotal, "1250") ~= nil or string.find(displayedTotal, "1,250") ~= nil)
        end)
    end)
end)

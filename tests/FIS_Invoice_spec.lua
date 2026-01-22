-- Unit tests for FIS_Invoice
local helper = require("tests.test_helper")

describe("FIS_Invoice", function()
    local FIS_Invoice
    
    before_each(function()
        helper.setupMocks()
        
        -- Mock Object class
        _G.Object = {
            new = function(isServer, isClient, mt)
                local self = setmetatable({}, mt)
                self.getNextDirtyFlag = function() return 1 end
                self.register = function() end
                self.raiseDirtyFlags = function() end
                self.raiseActive = function() end
                return self
            end
        }
        
        -- Load the FIS_Invoice module
        local mod_path = "FS25_FreshInvoiceSystem_FIX15_SEND_DEBUG_BUTTONPROFILE_MPONLY/src/"
        dofile(mod_path .. "FIS_Invoice.lua")
        FIS_Invoice = _G.FIS_Invoice
    end)
    
    describe("new()", function()
        it("should create a new invoice with default values", function()
            local invoice = FIS_Invoice.new(true, true)
            
            assert.is_not_nil(invoice)
            assert.equals(0, invoice.id)
            assert.equals(0, invoice.fromFarmId)
            assert.equals(0, invoice.toFarmId)
            assert.equals(0, invoice.amount)
            assert.equals("other", invoice.category)
            assert.equals("", invoice.description)
            assert.equals(FIS_Invoice.STATE_OPEN, invoice.state)
            assert.equals(0, invoice.createdTimestamp)
            assert.equals(0, invoice.paidTimestamp)
            assert.is_table(invoice.lineItems)
            assert.equals(0, #invoice.lineItems)
        end)
    end)
    
    describe("recalculateAmount()", function()
        it("should calculate total from line items", function()
            local invoice = FIS_Invoice.new(true, true)
            invoice.lineItems = {
                { quantity = 10, unitPrice = 100 },
                { quantity = 5, unitPrice = 50 }
            }
            
            invoice:recalculateAmount()
            
            assert.equals(1250, invoice.amount) -- (10*100) + (5*50) = 1250
        end)
        
        it("should handle empty line items", function()
            local invoice = FIS_Invoice.new(true, true)
            invoice.lineItems = {}
            
            invoice:recalculateAmount()
            
            assert.equals(0, invoice.amount)
        end)
        
        it("should handle nil quantity or unitPrice", function()
            local invoice = FIS_Invoice.new(true, true)
            invoice.lineItems = {
                { quantity = nil, unitPrice = 100 },
                { quantity = 5, unitPrice = nil }
            }
            
            invoice:recalculateAmount()
            
            assert.equals(0, invoice.amount)
        end)
        
        it("should handle decimal quantities and prices", function()
            local invoice = FIS_Invoice.new(true, true)
            invoice.lineItems = {
                { quantity = 10.5, unitPrice = 99.99 },
                { quantity = 2.25, unitPrice = 150.50 }
            }
            
            invoice:recalculateAmount()
            
            -- (10.5 * 99.99) + (2.25 * 150.50) = 1049.895 + 338.625 = 1388.52
            assert.is_true(math.abs(invoice.amount - 1388.52) < 0.01)
        end)
    end)
    
    describe("getStateText()", function()
        it("should return text for OPEN state", function()
            local invoice = FIS_Invoice.new(true, true)
            invoice.state = FIS_Invoice.STATE_OPEN
            
            local text = invoice:getStateText()
            
            assert.equals("ui_fis_open", text)
        end)
        
        it("should return text for PAID state", function()
            local invoice = FIS_Invoice.new(true, true)
            invoice.state = FIS_Invoice.STATE_PAID
            
            local text = invoice:getStateText()
            
            assert.equals("ui_fis_paid", text)
        end)
        
        it("should return text for DECLINED state", function()
            local invoice = FIS_Invoice.new(true, true)
            invoice.state = FIS_Invoice.STATE_DECLINED
            
            local text = invoice:getStateText()
            
            assert.equals("ui_fis_declined", text)
        end)
    end)
end)

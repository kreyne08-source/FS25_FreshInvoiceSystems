-- Unit tests for FIS_CreateInvoiceEvent
local helper = require("tests.test_helper")

describe("FIS_CreateInvoiceEvent", function()
    local FIS_CreateInvoiceEvent
    
    before_each(function()
        helper.setupMocks()
        helper.setupTestFarms()
        
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
        
        -- Load dependencies
        local mod_path = "FS25_FreshInvoiceSystem_FIX15_SEND_DEBUG_BUTTONPROFILE_MPONLY/src/"
        
        -- Mock FIS_NotifyEvent before loading InvoiceManager
        _G.FIS_NotifyEvent = {
            sendToConnection = function(connection, notificationType, textKey, p1, p2)
                -- Mock implementation
            end,
            new = function(notificationType, textKey, p1, p2)
                return {}
            end
        }
        
        dofile(mod_path .. "FIS_Invoice.lua")
        dofile(mod_path .. "FIS_InvoiceManager.lua")
        dofile(mod_path .. "events/FIS_CreateInvoiceEvent.lua")
        
        FIS_CreateInvoiceEvent = _G.FIS_CreateInvoiceEvent
        
        -- Setup invoice manager
        _G.g_fis_invoiceManager = _G.FIS_InvoiceManager.new()
    end)
    
    describe("new()", function()
        it("should create a new event with provided parameters", function()
            local lineItems = helper.createTestLineItems()
            local event = FIS_CreateInvoiceEvent.new(1, 2, "service", "Test invoice", lineItems)
            
            assert.is_not_nil(event)
            assert.equals(1, event.fromFarmId)
            assert.equals(2, event.toFarmId)
            assert.equals("service", event.category)
            assert.equals("Test invoice", event.description)
            assert.equals(2, #event.lineItems)
        end)
        
        it("should use default values when parameters are nil", function()
            local event = FIS_CreateInvoiceEvent.new(nil, nil, nil, nil, nil)
            
            assert.equals(0, event.fromFarmId)
            assert.equals(0, event.toFarmId)
            assert.equals("other", event.category)
            assert.equals("", event.description)
            assert.is_table(event.lineItems)
            assert.equals(0, #event.lineItems)
        end)
    end)
    
    describe("readStream()", function()
        it("should read event data from stream", function()
            local event = FIS_CreateInvoiceEvent.emptyNew()
            
            -- Mock stream that returns test data
            _G.streamReadInt32 = function(streamId)
                if not event._readCount then event._readCount = 0 end
                event._readCount = event._readCount + 1
                if event._readCount == 1 then return 1 end  -- fromFarmId
                if event._readCount == 2 then return 2 end  -- toFarmId
                return 0
            end
            
            _G.streamReadString = function(streamId)
                if not event._stringReadCount then event._stringReadCount = 0 end
                event._stringReadCount = event._stringReadCount + 1
                if event._stringReadCount == 1 then return "service" end  -- category
                if event._stringReadCount == 2 then return "Test" end     -- description
                return ""
            end
            
            _G.streamReadUInt8 = function(streamId) return 0 end  -- no line items
            
            event:readStream(1, { getFarmId = function() return 1 end })
            
            assert.equals(1, event.fromFarmId)
            assert.equals(2, event.toFarmId)
            assert.equals("service", event.category)
            assert.equals("Test", event.description)
        end)
    end)
    
    describe("writeStream()", function()
        it("should write event data to stream", function()
            local lineItems = helper.createTestLineItems()
            local event = FIS_CreateInvoiceEvent.new(1, 2, "service", "Test invoice", lineItems)
            
            local written = {}
            
            _G.streamWriteInt32 = function(streamId, value)
                table.insert(written, { type = "int32", value = value })
            end
            
            _G.streamWriteString = function(streamId, value)
                table.insert(written, { type = "string", value = value })
            end
            
            _G.streamWriteUInt8 = function(streamId, value)
                table.insert(written, { type = "uint8", value = value })
            end
            
            _G.streamWriteFloat32 = function(streamId, value)
                table.insert(written, { type = "float32", value = value })
            end
            
            event:writeStream(1, nil)
            
            -- Verify data was written
            assert.is_true(#written > 0)
            assert.equals("int32", written[1].type)
            assert.equals(1, written[1].value) -- fromFarmId
        end)
        
        it("should limit line items to 20", function()
            local lineItems = {}
            for i = 1, 25 do
                table.insert(lineItems, {
                    itemType = "units",
                    description = "Item " .. i,
                    quantity = 1,
                    unitPrice = 10,
                    unit = ""
                })
            end
            
            local event = FIS_CreateInvoiceEvent.new(1, 2, "service", "Test", lineItems)
            
            local itemCount = 0
            _G.streamWriteUInt8 = function(streamId, value)
                itemCount = value
            end
            _G.streamWriteInt32 = function(streamId, value) end
            _G.streamWriteString = function(streamId, value) end
            _G.streamWriteFloat32 = function(streamId, value) end
            
            event:writeStream(1, nil)
            
            -- Should be limited to 20
            assert.equals(20, itemCount)
        end)
    end)
    
    describe("run()", function()
        it("should create invoice when run on server with valid connection", function()
            local lineItems = helper.createTestLineItems()
            local event = FIS_CreateInvoiceEvent.new(0, 2, "service", "Test invoice", lineItems)
            
            local mockConnection = {
                getFarmId = function() return 1 end
            }
            
            -- Mock user manager with permissions
            g_currentMission.userManager = {
                getUserByConnection = function(self, connection)
                    return {
                        getHasPermission = function(self, perm, farmId)
                            return true
                        end
                    }
                end
            }
            
            local invoiceCreated = false
            local originalCreate = g_fis_invoiceManager.createInvoice
            g_fis_invoiceManager.createInvoice = function(self, fromFarmId, toFarmId, category, desc, items)
                invoiceCreated = true
                assert.equals(1, fromFarmId)
                assert.equals(2, toFarmId)
                assert.equals("service", category)
                assert.equals("Test invoice", desc)
                return originalCreate(self, fromFarmId, toFarmId, category, desc, items)
            end
            
            event:run(mockConnection)
            
            assert.is_true(invoiceCreated)
        end)
        
        it("should reject event from spectator farm", function()
            local event = FIS_CreateInvoiceEvent.new(0, 2, "service", "Test", {})
            
            local mockConnection = {
                getFarmId = function() return FarmManager.SPECTATOR_FARM_ID end
            }
            
            local invoiceCreated = false
            g_fis_invoiceManager.createInvoice = function()
                invoiceCreated = true
            end
            
            event:run(mockConnection)
            
            assert.is_false(invoiceCreated)
        end)
        
        it("should reject event from connection without permissions", function()
            local event = FIS_CreateInvoiceEvent.new(0, 2, "service", "Test", helper.createTestLineItems())
            
            local mockConnection = {
                getFarmId = function() return 1 end
            }
            
            g_currentMission.userManager = {
                getUserByConnection = function(self, connection)
                    return {
                        getHasPermission = function(self, perm, farmId)
                            return false -- No permissions
                        end
                    }
                end
            }
            
            local invoiceCreated = false
            g_fis_invoiceManager.createInvoice = function()
                invoiceCreated = true
            end
            
            event:run(mockConnection)
            
            assert.is_false(invoiceCreated)
        end)
    end)
end)

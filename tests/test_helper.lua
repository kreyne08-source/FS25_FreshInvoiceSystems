-- Test Helper for FIS Mod Unit Tests
-- Mocks FS25 game engine globals and utilities

local M = {}

-- Mock global game objects
function M.setupMocks()
    -- Mock logging
    _G.Logging = {
        info = function(msg, ...)
            if select('#', ...) > 0 then
                print(string.format("[INFO] " .. msg, ...))
            else
                print("[INFO] " .. tostring(msg))
            end
        end,
        warning = function(msg, ...)
            if select('#', ...) > 0 then
                print(string.format("[WARN] " .. msg, ...))
            else
                print("[WARN] " .. tostring(msg))
            end
        end,
        error = function(msg, ...)
            if select('#', ...) > 0 then
                print(string.format("[ERROR] " .. msg, ...))
            else
                print("[ERROR] " .. tostring(msg))
            end
        end,
    }
    
    -- Mock i18n
    _G.g_i18n = {
        getText = function(self, key)
            return key -- Return key as text for testing
        end,
        formatMoney = function(self, amount, decimals, showCurrency, showSign)
            return string.format("$%.2f", amount)
        end
    }
    
    -- Mock FarmManager
    _G.FarmManager = {
        SPECTATOR_FARM_ID = 0
    }
    
    -- Mock farm manager
    _G.g_farmManager = {
        farms = {},
        getFarmById = function(self, farmId)
            return self.farms[farmId]
        end,
        getFarmByUserId = function(self, userId)
            for _, farm in pairs(self.farms) do
                if farm.userId == userId then
                    return farm
                end
            end
            return nil
        end,
        getFarms = function(self)
            return self.farms
        end
    }
    
    -- Mock current mission
    _G.g_currentMission = {
        time = 0,
        player = nil,
        playerUserId = 1,
        userManager = nil,
        
        getIsServer = function(self)
            return true
        end,
        
        getIsClient = function(self)
            return true
        end,
        
        getFarmId = function(self)
            return 1
        end,
        
        addMoneyChange = function(self, amount, farmId, moneyType, direct)
            -- Mock implementation
        end
    }
    
    -- Mock server/client
    _G.g_server = {
        broadcastEvent = function(self, event, ...)
            -- Mock implementation
        end
    }
    
    _G.g_client = {
        getServerConnection = function(self)
            return {
                sendEvent = function(self, event)
                    -- Mock implementation
                end,
                getFarmId = function(self)
                    return 1
                end
            }
        end
    }
    
    -- Mock GUI
    _G.g_gui = {
        guis = {},
        showDialog = function(self, dialogName)
            -- Mock implementation
        end,
        loadProfiles = function(self, path)
            -- Mock implementation
        end,
        loadGui = function(self, path, name, frame)
            self.guis[name] = frame
        end
    }
    
    -- Mock FocusManager
    _G.FocusManager = {
        setFocus = function(element)
            -- Mock implementation
        end
    }
    
    -- Mock Event class
    _G.Event = {
        new = function(mt)
            return setmetatable({}, mt)
        end
    }
    
    -- Mock Class function
    _G.Class = function(class, superClass)
        local mt = {}
        mt.__index = class
        if superClass then
            setmetatable(class, { __index = superClass })
        end
        return mt
    end
    
    -- Mock InitEventClass
    _G.InitEventClass = function(class, name)
        -- Mock implementation
    end
    
    -- Mock stream functions
    _G.streamReadInt32 = function(streamId) return 0 end
    _G.streamReadString = function(streamId) return "" end
    _G.streamReadUInt8 = function(streamId) return 0 end
    _G.streamReadFloat32 = function(streamId) return 0.0 end
    _G.streamWriteInt32 = function(streamId, value) end
    _G.streamWriteString = function(streamId, value) end
    _G.streamWriteUInt8 = function(streamId, value) end
    _G.streamWriteFloat32 = function(streamId, value) end
end

-- Helper to create a test farm
function M.createTestFarm(farmId, name, userId)
    return {
        farmId = farmId or 1,
        name = name or "Test Farm",
        userId = userId or 1,
        isSpectator = false,
        changeBalance = function(self, amount, moneyType)
            -- Mock implementation
        end
    }
end

-- Helper to create test line items
function M.createTestLineItems()
    return {
        {
            itemType = "units",
            description = "Test Item 1",
            quantity = 10,
            unitPrice = 100,
            unit = ""
        },
        {
            itemType = "liters",
            description = "Test Item 2",
            quantity = 50,
            unitPrice = 20,
            unit = "L"
        }
    }
end

-- Helper to setup farms in the manager
function M.setupTestFarms()
    g_farmManager.farms[1] = M.createTestFarm(1, "Farm 1", 1)
    g_farmManager.farms[2] = M.createTestFarm(2, "Farm 2", 2)
    g_farmManager.farms[3] = M.createTestFarm(3, "Farm 3", 3)
end

return M

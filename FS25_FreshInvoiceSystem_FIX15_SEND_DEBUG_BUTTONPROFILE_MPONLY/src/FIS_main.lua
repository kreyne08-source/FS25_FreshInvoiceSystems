
FIS = FIS or {}

local MOD_DIR  = g_currentModDirectory

local PAGE_NAME = "FIS_InGameMenuInvoices"
local TAB_POS   = 6 -- insert position in ESC menu tabs
local TAB_UVS   = {0, 0, 1024, 1024}
local TAB_ICON  = Utils.getFilename('modIcon.dds', MOD_DIR)


local function fis_isMultiplayerMission()
    local mission = g_currentMission
    if mission == nil then
        return false
    end

    if g_dedicatedServerInfo ~= nil then
        return true
    end

    if mission.missionDynamicInfo ~= nil and mission.missionDynamicInfo.isMultiplayer ~= nil then
        return mission.missionDynamicInfo.isMultiplayer
    end
    if mission.missionInfo ~= nil and mission.missionInfo.isMultiplayer ~= nil then
        return mission.missionInfo.isMultiplayer
    end

    return false
end

source(MOD_DIR .. "src/FIS_Debug.lua")
source(MOD_DIR .. "src/FIS_Invoice.lua")
source(MOD_DIR .. "src/FIS_InvoiceManager.lua")
source(MOD_DIR .. "src/FIS_Permissions.lua")
source(MOD_DIR .. "src/FIS_Presets.lua")

source(MOD_DIR .. "src/events/FIS_CreateInvoiceEvent.lua")
source(MOD_DIR .. "src/events/FIS_SetInvoiceStateEvent.lua")
source(MOD_DIR .. "src/events/FIS_DeleteInvoiceEvent.lua")
source(MOD_DIR .. "src/events/FIS_NotifyEvent.lua")

source(MOD_DIR .. "src/gui/FIS_InGameMenuInvoices.lua")
source(MOD_DIR .. "src/gui/FIS_CreateInvoiceDialog.lua")
source(MOD_DIR .. "src/gui/FIS_InvoiceDetailDialog.lua")

g_fis_invoiceManager = g_fis_invoiceManager or FIS_InvoiceManager.new()

local function fis_fixInGameMenu(frame, pageName, uvs, position, predicateFunc)
    local inGameMenu = nil

    if g_inGameMenu ~= nil then
        inGameMenu = g_inGameMenu
    elseif g_gui ~= nil and g_gui.screenControllers ~= nil then
        inGameMenu = g_gui.screenControllers[InGameMenu] or g_gui.screenControllers["InGameMenu"]
    end

    if inGameMenu == nil then
        if not silent then
        Logging.error("[FIS] InGameMenu controller not available")
    else
        Logging.warning("[FIS] InGameMenu controller not available")
    end
        return false
    end

    inGameMenu.controlIDs[pageName] = nil

    inGameMenu[pageName] = frame
    inGameMenu.pagingElement:addElement(inGameMenu[pageName])
    inGameMenu:exposeControlsAsFields(pageName)

    for i = 1, #inGameMenu.pagingElement.elements do
        local child = inGameMenu.pagingElement.elements[i]
        if child == inGameMenu[pageName] then
            table.remove(inGameMenu.pagingElement.elements, i)
            table.insert(inGameMenu.pagingElement.elements, position, child)
            break
        end
    end

    for i = 1, #inGameMenu.pagingElement.pages do
        local child = inGameMenu.pagingElement.pages[i]
        if child.element == inGameMenu[pageName] then
            table.remove(inGameMenu.pagingElement.pages, i)
            table.insert(inGameMenu.pagingElement.pages, position, child)
            break
        end
    end

    inGameMenu.pagingElement:updateAbsolutePosition()
    inGameMenu.pagingElement:updatePageMapping()

    inGameMenu:registerPage(inGameMenu[pageName], position, predicateFunc)
    inGameMenu:addPageTab(inGameMenu[pageName], TAB_ICON)

    for i = 1, #inGameMenu.pageFrames do
        local child = inGameMenu.pageFrames[i]
        if child == inGameMenu[pageName] then
            table.remove(inGameMenu.pageFrames, i)
            table.insert(inGameMenu.pageFrames, position, child)
            break
        end
    end

    inGameMenu:rebuildTabList()

    return true
end

local function fis_openInvoicesMenu()
    local inGameMenu = nil
    if g_inGameMenu ~= nil then
        inGameMenu = g_inGameMenu
    elseif g_gui ~= nil and g_gui.screenControllers ~= nil then
        inGameMenu = g_gui.screenControllers[InGameMenu] or g_gui.screenControllers["InGameMenu"]
    end
    if inGameMenu == nil then
        return
    end

    g_gui:showGui("InGameMenu")

    if inGameMenu.pagingElement ~= nil then
        if inGameMenu.pagingElement.setPageId ~= nil then
            inGameMenu.pagingElement:setPageId(TAB_POS)
        elseif inGameMenu.pagingElement.setPage ~= nil and inGameMenu[PAGE_NAME] ~= nil then
            inGameMenu.pagingElement:setPage(inGameMenu[PAGE_NAME])
        end
    end
end

local FIS_Controller = {}
FIS_Controller.__index = FIS_Controller

function FIS_Controller.new()
    local self = setmetatable({}, FIS_Controller)
    self.menuInstalled = false
    self._installRetryMs = 0
    self._installTriedOnce = false
    self.actionEventId = nil
    return self
end

function FIS_Controller:loadMap()
        
    print(string.format("FIS: loadMap() executed | isServer=%s isClient=%s isMultiplayer=%s", tostring(g_currentMission ~= nil and g_currentMission:getIsServer()), tostring(g_currentMission ~= nil and g_currentMission:getIsClient()), tostring(g_currentMission ~= nil and g_currentMission.missionInfo ~= nil and g_currentMission.missionInfo.isMultiplayer)))
if not fis_isMultiplayerMission() then
        return
    end
Logging.info("[FIS] loadMap()")
end

function FIS_Controller:deleteMap()
    if self.actionEventId ~= nil then
        g_inputBinding:removeActionEvent(self.actionEventId)
        self.actionEventId = nil
    end
    self.menuInstalled = false
end

function FIS_Controller:startMission()
        if not fis_isMultiplayerMission() then
        return
    end
Logging.info("[FIS] startMission()")
    self:ensureMenuInstalled()
end

function FIS_Controller:update(dt)
    if g_dedicatedServerInfo ~= nil then
        return
    end

    if not self.menuInstalled then
        local inGameMenu = g_inGameMenu
        if inGameMenu == nil and g_gui ~= nil and g_gui.screenControllers ~= nil then
            inGameMenu = g_gui.screenControllers[InGameMenu] or g_gui.screenControllers["InGameMenu"]
        end

        if inGameMenu ~= nil then
            self:ensureMenuInstalled()
        end
    end

    if self.actionEventId == nil and g_inputBinding ~= nil and InputAction ~= nil and InputAction.FIS_TOGGLE_INVOICES_MENU ~= nil then
        local _, actionEventId = g_inputBinding:registerActionEvent(InputAction.FIS_TOGGLE_INVOICES_MENU, self, fis_openInvoicesMenu, false, true, false, true)
        self.actionEventId = actionEventId

        if self.actionEventId ~= nil then
            g_inputBinding:setActionEventText(self.actionEventId, g_i18n:getText("ui_fis_openInvoices") or "Open Invoices")
            g_inputBinding:setActionEventTextVisibility(self.actionEventId, true)
            Logging.info("[FIS] Keybind registered (late) (actionEventId=%s)", tostring(self.actionEventId))
        else
            if not silent then
        Logging.error("[FIS] Failed to register keybind (late)")
    else
        Logging.warning("[FIS] Failed to register keybind (late)")
    end
        end
    end
end

function FIS_Controller:ensureMenuInstalled(silent)
    if self.menuInstalled then
        return
    end

    if g_dedicatedServerInfo ~= nil then
        self.menuInstalled = true
        return
    end

    if g_gui == nil then
        return
    end

    if g_gui.loadProfiles ~= nil then
        g_gui:loadProfiles(MOD_DIR .. "gui/FIS_guiProfiles.xml")
    end


    if FIS_InGameMenuInvoices == nil or FIS_InGameMenuInvoices.new == nil
        or FIS_CreateInvoiceDialog == nil or FIS_CreateInvoiceDialog.new == nil
        or FIS_InvoiceDetailDialog == nil or FIS_InvoiceDetailDialog.new == nil then
        if not self.menuInstallFailed then
            Logging.error("[FIS] GUI classes not available (script compile error). Disabling menu install.")
            self.menuInstallFailed = true
        end
        self.menuInstalled = true
        return
    end

    local frame = FIS_InGameMenuInvoices.new(g_i18n, g_messageCenter)
    g_gui:loadGui(MOD_DIR .. "gui/FIS_InGameMenuInvoices.xml", PAGE_NAME, frame)

    if frame.initialize ~= nil then
        frame:initialize()
    end

    local createDialog = FIS_CreateInvoiceDialog.new(g_i18n, g_messageCenter)
    g_gui:loadGui(MOD_DIR .. "gui/FIS_CreateInvoiceDialog.xml", "FIS_CreateInvoiceDialog", createDialog)

    if createDialog.initialize ~= nil then
        createDialog:initialize()
    end

    local detailDialog = FIS_InvoiceDetailDialog.new(g_i18n, g_messageCenter)
    g_gui:loadGui(MOD_DIR .. "gui/FIS_InvoiceDetailDialog.xml", "FIS_InvoiceDetailDialog", detailDialog)
    if detailDialog.initialize ~= nil then
        detailDialog:initialize()
    end

    local ok = fis_fixInGameMenu(frame, PAGE_NAME, TAB_UVS, TAB_POS, function() return true end)
    self.menuInstalled = ok

    if ok then
        Logging.info("[FIS] Menu injected")
    end
end

function FIS_Controller:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
        if not fis_isMultiplayerMission() then
        return
    end
    self:ensureMenuInstalled()

    if self.actionEventId ~= nil then
        g_inputBinding:removeActionEvent(self.actionEventId)
        self.actionEventId = nil
    end

    if not isActiveForInput then
        return
    end

    if InputAction == nil or InputAction.FIS_TOGGLE_INVOICES_MENU == nil then
        if not silent then
        Logging.error("[FIS] InputAction.FIS_TOGGLE_INVOICES_MENU missing - inputBinding.xml not loaded")
    else
        Logging.warning("[FIS] InputAction.FIS_TOGGLE_INVOICES_MENU missing - inputBinding.xml not loaded")
    end
        return
    end

    local _, actionEventId = g_inputBinding:registerActionEvent(InputAction.FIS_TOGGLE_INVOICES_MENU, self, fis_openInvoicesMenu, false, true, false, true)
    self.actionEventId = actionEventId

    if self.actionEventId ~= nil then
        g_inputBinding:setActionEventText(self.actionEventId, g_i18n:getText("ui_fis_openInvoices") or "Open Invoices")
        g_inputBinding:setActionEventTextVisibility(self.actionEventId, true)
        Logging.info("[FIS] Keybind registered (actionEventId=%s)", tostring(self.actionEventId))
    else
        if not silent then
        Logging.error("[FIS] Failed to register keybind")
    else
        Logging.warning("[FIS] Failed to register keybind")
    end
    end
end

local function onLoadItemsFinished(mission, node)
        if not fis_isMultiplayerMission() then
        return
    end
if g_fis_invoiceManager ~= nil then
        g_fis_invoiceManager:loadFromXMLFile(mission.missionInfo)
    end
end

local function onSaveToXMLFile(missionInfo)
        if not fis_isMultiplayerMission() then
        return
    end
if g_fis_invoiceManager ~= nil then
        g_fis_invoiceManager:saveToXMLFile(missionInfo)
    end
end

if Mission00 ~= nil then
    Mission00.loadItemsFinished = Utils.appendedFunction(Mission00.loadItemsFinished, onLoadItemsFinished)
end

if FSCareerMissionInfo ~= nil then
    FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, onSaveToXMLFile)
end

addModEventListener(g_fis_invoiceManager)

g_fis_controller = FIS_Controller.new()
addModEventListener(g_fis_controller)

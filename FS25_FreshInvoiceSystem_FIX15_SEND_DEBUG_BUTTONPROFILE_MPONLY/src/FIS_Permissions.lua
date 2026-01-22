
FIS_Permissions = {}

local function hasPermission(permissionEnum, farmId)
    if g_currentMission == nil or type(g_currentMission.getHasPlayerPermission) ~= "function" then
        return false
    end

    local ok1, res1 = pcall(function()
        return g_currentMission:getHasPlayerPermission(permissionEnum)
    end)
    if ok1 and res1 == true then
        return true
    end

    if farmId ~= nil then
        local ok2, res2 = pcall(function()
            return g_currentMission:getHasPlayerPermission(permissionEnum, farmId)
        end)
        if ok2 and res2 == true then
            return true
        end
    end

    return false
end

function FIS_Permissions.hasFinancePermission(farmId)
    if g_currentMission == nil or Farm == nil or Farm.PERMISSION == nil then
        return false
    end

    if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
        return false
    end

    if Farm.PERMISSION.MANAGE_FINANCES ~= nil then
        if hasPermission(Farm.PERMISSION.MANAGE_FINANCES, farmId) then
            return true
        end
    end

    if Farm.PERMISSION.MANAGE_RIGHTS ~= nil then
        if hasPermission(Farm.PERMISSION.MANAGE_RIGHTS, farmId) then
            return true
        end
    end

    return false
end

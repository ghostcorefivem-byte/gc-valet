local QBCore = exports['qb-core']:GetCoreObject()

--==============================================================================
-- IMPOUND CONFIG
--==============================================================================

local ImpoundConfig = {
    AutoImpoundInterval = 5 * 60 * 1000,
    AbandonedThreshold  = 300,
    DefaultGarage       = 'pillboxgarage',
    AdminPermission     = 'admin',
    Debug               = false
}

local function DebugPrint(msg)
    if ImpoundConfig.Debug then print("^3[IMPOUND DEBUG]^7 " .. msg) end
end

--==============================================================================
-- VALET VEHICLE TRACKING
--==============================================================================

local TrackedVehicles = {}

RegisterNetEvent('valet:impound:trackVehicle', function(netId, plate, citizenid, garage)
    local src = source
    if not QBCore.Functions.GetPlayer(src) then return end

    TrackedVehicles[netId] = {
        plate        = plate,
        citizenid    = citizenid,
        garage       = garage or ImpoundConfig.DefaultGarage,
        spawnedAt    = os.time(),
        lastOccupied = os.time(),
    }
    DebugPrint("Tracking netId=" .. netId .. " plate=" .. plate)
end)

RegisterNetEvent('valet:impound:occupiedPing', function(netId)
    if TrackedVehicles[netId] then
        TrackedVehicles[netId].lastOccupied = os.time()
    end
end)

--==============================================================================
-- IMPOUND HELPER
--==============================================================================

local function ImpoundTrackedVehicle(netId, data, reason)
    if data and data.plate then
        local garage = data.garage or ImpoundConfig.DefaultGarage
        MySQL.update.await(
            'UPDATE player_vehicles SET state = 1, garage = ? WHERE plate = ?',
            { garage, data.plate }
        )
        DebugPrint("DB: " .. data.plate .. " → " .. garage)

        for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
            local Player = QBCore.Functions.GetPlayer(playerId)
            if Player and Player.PlayerData.citizenid == data.citizenid then
                TriggerClientEvent('valet:client:vehicleImpounded', playerId, data.plate, data.plate)
                break
            end
        end
    end

    TriggerClientEvent('valet:impound:deleteVehicle', -1, netId)
    TrackedVehicles[netId] = nil
end

--==============================================================================
-- AUTO-IMPOUND LOOP
--==============================================================================

CreateThread(function()
    while true do
        Wait(ImpoundConfig.AutoImpoundInterval)
        local now, removed = os.time(), 0

        for netId, data in pairs(TrackedVehicles) do
            local idle = now - (data.lastOccupied or data.spawnedAt)
            if idle >= ImpoundConfig.AbandonedThreshold then
                ImpoundTrackedVehicle(netId, data, "auto-abandoned")
                removed += 1
            end
        end

        if removed > 0 then
            print("^3[IMPOUND]^7 Auto-impounded " .. removed .. " abandoned valet vehicle(s)")
        end
    end
end)

--==============================================================================
-- /wipecars — ask a client to scan world vehicles, then delete unoccupied ones
--
-- FIX: Removed WipeScanPending guard that was causing a race condition where
-- the timeout could flip the flag before the scan result arrived, silently
-- dropping the result. Now we just process whatever comes back.
-- FIX: occupied is now 1/0 (integer) instead of true/false to avoid any
-- Lua→JSON→Lua boolean serialization issues over the network event.
--==============================================================================

local WipeScanSrc = 0

RegisterNetEvent('valet:impound:scanResult', function(vehicleList)
    local src = source
    if not QBCore.Functions.GetPlayer(src) then return end

    print("^2[IMPOUND]^7 Scan result received from player " .. src .. ". Entries: " .. #vehicleList)

    local count = 0

    for _, entry in ipairs(vehicleList) do
        local netId    = entry.netId
        local plate    = entry.plate
        local occupied = entry.occupied  -- 1 = occupied, 0 = empty

        print(string.format("^3[IMPOUND]^7 Processing: netId=%s plate=%s occupied=%s",
            tostring(netId), tostring(plate), tostring(occupied)))

        -- occupied == 0 means empty (using int to avoid bool serialization issues)
        if occupied == 0 then
            count += 1

            if TrackedVehicles[netId] then
                ImpoundTrackedVehicle(netId, TrackedVehicles[netId], "admin-wipecars")
            else
                if plate and plate ~= "" then
                    MySQL.update(
                        'UPDATE player_vehicles SET state = 1 WHERE TRIM(plate) = ? AND state = 0',
                        { plate }
                    )
                end
                TriggerClientEvent('valet:impound:deleteVehicle', -1, netId)
            end
        end
    end

    print("^2[IMPOUND]^7 Wipe complete. Removed: " .. count)
    TriggerClientEvent('valet:impound:wipeNotify', -1, count)

    if WipeScanSrc ~= 0 then
        TriggerClientEvent('QBCore:Notify', WipeScanSrc, '✅ Wiped ' .. count .. ' unoccupied vehicle(s).', 'success')
    end
end)

RegisterCommand('wipecars', function(source, args)
    local src = source

    if src ~= 0 then
        if not IsPlayerAceAllowed(tostring(src), ImpoundConfig.AdminPermission) then
            TriggerClientEvent('QBCore:Notify', src, '❌ No permission.', 'error')
            return
        end
    end

    local players = QBCore.Functions.GetPlayers()
    if not players or #players == 0 then
        if src ~= 0 then TriggerClientEvent('QBCore:Notify', src, '❌ No players online to scan.', 'error')
        else print("^3[IMPOUND]^7 No players online.") end
        return
    end

    WipeScanSrc = src

    -- Use the admin themselves as scanner so vehicles near them are in pool
    local scanTarget = (src ~= 0) and src or players[1]

    print("^2[IMPOUND]^7 Sending scan request to player " .. scanTarget)
    TriggerClientEvent('valet:impound:requestScan', scanTarget)

    if src ~= 0 then
        TriggerClientEvent('QBCore:Notify', src, '🔍 Scanning city for vehicles...', 'primary')
    end
end, false)

--==============================================================================
-- /impound [plate]
--==============================================================================

RegisterCommand('impound', function(source, args)
    local src = source

    if src ~= 0 then
        if not IsPlayerAceAllowed(tostring(src), ImpoundConfig.AdminPermission) then
            TriggerClientEvent('QBCore:Notify', src, '❌ No permission.', 'error')
            return
        end
    end

    local plate = args[1]
    if not plate then
        if src ~= 0 then TriggerClientEvent('QBCore:Notify', src, '❌ Usage: /impound [plate]', 'error')
        else print("Usage: /impound [plate]") end
        return
    end
    plate = plate:upper()

    for netId, data in pairs(TrackedVehicles) do
        if data.plate:upper() == plate then
            ImpoundTrackedVehicle(netId, data, "admin-manual")
            local name = src == 0 and "Console" or GetPlayerName(src)
            print("^2[IMPOUND]^7 " .. name .. " impounded tracked vehicle: " .. plate)
            if src ~= 0 then TriggerClientEvent('QBCore:Notify', src, '✅ Vehicle ' .. plate .. ' impounded.', 'success') end
            return
        end
    end

    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ?', { plate })
    if result and result[1] then
        MySQL.update.await('UPDATE player_vehicles SET state = 1 WHERE plate = ?', { plate })
        local name = src == 0 and "Console" or GetPlayerName(src)
        print("^3[IMPOUND]^7 " .. name .. " DB-impounded: " .. plate)
        if src ~= 0 then TriggerClientEvent('QBCore:Notify', src, '✅ ' .. plate .. ' returned to garage in DB.', 'success') end
    else
        if src ~= 0 then TriggerClientEvent('QBCore:Notify', src, '❌ No vehicle found: ' .. plate, 'error')
        else print("No vehicle found: " .. plate) end
    end
end, false)

--==============================================================================
-- /listvehicles
--==============================================================================

RegisterCommand('listvehicles', function(source, args)
    local src = source

    if src ~= 0 then
        if not IsPlayerAceAllowed(tostring(src), ImpoundConfig.AdminPermission) then
            TriggerClientEvent('QBCore:Notify', src, '❌ No permission.', 'error')
            return
        end
    end

    local count = 0
    print("^2[IMPOUND]^7 ======= TRACKED VALET VEHICLES =======")
    for netId, data in pairs(TrackedVehicles) do
        local idle = os.time() - (data.lastOccupied or data.spawnedAt)
        print(string.format("  NetID: %-6s | Plate: %-12s | Idle: %4ds | Garage: %s",
            netId, data.plate, idle, data.garage))
        count += 1
    end
    print("^2[IMPOUND]^7 Total: " .. count)

    if src ~= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Console shows ' .. count .. ' tracked vehicle(s).', 'primary')
    end
end, false)

--==============================================================================
-- STARTUP
--==============================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print('^2[GC-VALET IMPOUND]^7 Loaded! /wipecars | /impound [plate] | /listvehicles')
    end
end)

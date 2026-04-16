local QBCore = exports['qb-core']:GetCoreObject()

--==============================================================================
-- CLIENT CONFIG
--==============================================================================

local Config = {
    DeliveryRadius    = 30.0,
    NPCModel          = 'a_m_m_business_01',
    DeliveryTime      = 30,
    BlipDuration      = 60000,
    ArrivalDistance   = 12.0,   -- how close NPC must be to trigger handoff
    DriveSpeed        = 18.0,   -- NPC drive speed (lower = more accurate stop)
    Debug             = false   -- 🔥 TURN DEBUG ON/OFF HERE
}

local function DebugPrint(msg)
    if Config.Debug then print("^3[VALET DEBUG]^7 " .. msg) end
end

--==============================================================================
-- VEHICLE BLIP TABLES
--==============================================================================

local VehicleBlipSprites = {
    sports = 226, super = 227, muscle = 228, motorcycles = 226,
    suvs = 225, sedans = 225, compacts = 225, coupes = 226,
    offroad = 225, vans = 225, boats = 427, helicopters = 43,
    planes = 16, cycles = 226
}

local VehicleBlipColors = {
    sports = 2, super = 6, muscle = 27, motorcycles = 17,
    suvs = 3, sedans = 0, compacts = 5, coupes = 2,
    offroad = 25, vans = 4, boats = 3, helicopters = 5,
    planes = 6, cycles = 2
}

-- Active blips tracked per plate
local VehicleBlips = {}

--==============================================================================
-- BLIP HELPERS
--==============================================================================

local function AddVehicleBlip(vehicle, plate, vehicleName, category)
    -- Remove existing blip for this plate first
    if VehicleBlips[plate] then
        if DoesBlipExist(VehicleBlips[plate]) then
            RemoveBlip(VehicleBlips[plate])
        end
        VehicleBlips[plate] = nil
    end

    local sprite = VehicleBlipSprites[category] or 225
    local color  = VehicleBlipColors[category] or 0

    local blip = AddBlipForEntity(vehicle)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, false)          -- show on full map & minimap
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("🚗 " .. vehicleName .. " [" .. plate .. "]")
    EndTextCommandSetBlipName(blip)

    VehicleBlips[plate] = blip
    DebugPrint("Blip added for plate: " .. plate)
end

local function RemoveVehicleBlip(plate)
    if VehicleBlips[plate] then
        if DoesBlipExist(VehicleBlips[plate]) then
            RemoveBlip(VehicleBlips[plate])
        end
        VehicleBlips[plate] = nil
        DebugPrint("Blip removed for plate: " .. plate)
    end
end

--==============================================================================
-- SPAWN HELPERS
--==============================================================================

local function GetSafeSpawnCoord(playerCoords)
    -- Try to find an unoccupied spot within radius
    for i = 1, 8 do
        local angle  = math.random(0, 360)
        local dist   = math.random(20, math.floor(Config.DeliveryRadius))
        local rad    = math.rad(angle)
        local sx     = playerCoords.x + dist * math.cos(rad)
        local sy     = playerCoords.y + dist * math.sin(rad)
        local sz     = playerCoords.z + 1.0

        if not IsPositionOccupied(sx, sy, sz, 3.5, false, true, true, false, false, 0, false) then
            DebugPrint("Safe spawn found on attempt " .. i)
            return vector3(sx, sy, sz)
        end
    end

    DebugPrint("Fallback spawn used")
    return vector3(playerCoords.x + 15.0, playerCoords.y + 15.0, playerCoords.z + 1.0)
end

local function RequestModelAsync(hash)
    RequestModel(hash)
    local attempts = 0
    while not HasModelLoaded(hash) and attempts < 60 do
        Wait(100)
        attempts += 1
    end
    return HasModelLoaded(hash)
end

--==============================================================================
-- MAIN DELIVERY FUNCTION
--==============================================================================

local function SpawnNPCDelivery(vehicleData, vehicleName, category)
    local playerPed    = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    DebugPrint("Delivery requested: " .. (vehicleData.vehicle or "?"))

    CreateThread(function()
        local spawnCoord = GetSafeSpawnCoord(playerCoords)

        -- Load vehicle model
        local vHash = GetHashKey(vehicleData.vehicle)
        if not RequestModelAsync(vHash) then
            QBCore.Functions.Notify('Failed to load vehicle model!', 'error')
            return
        end

        -- Spawn vehicle
        local playerVehicle = CreateVehicle(vHash, spawnCoord.x, spawnCoord.y, spawnCoord.z, 0.0, true, false)
        Wait(400)

        if not DoesEntityExist(playerVehicle) then
            QBCore.Functions.Notify('Failed to spawn vehicle!', 'error')
            SetModelAsNoLongerNeeded(vHash)
            return
        end

        SetVehicleOnGroundProperly(playerVehicle)
        SetModelAsNoLongerNeeded(vHash)

        -- Apply mods
        if vehicleData.mods then
            local ok, mods = pcall(json.decode, vehicleData.mods)
            if ok and mods then
                QBCore.Functions.SetVehicleProperties(playerVehicle, mods)
            end
        end

        -- Fuel
        if vehicleData.fuel then
            if GetResourceState('LegacyFuel') == 'started' then
                exports['LegacyFuel']:SetFuel(playerVehicle, vehicleData.fuel)
            elseif GetResourceState('ps-fuel') == 'started' then
                exports['ps-fuel']:SetFuel(playerVehicle, vehicleData.fuel)
            end
        end

        -- Add vehicle blip so player can track it on full map & minimap
        local plate = GetVehicleNumberPlateText(playerVehicle)
        AddVehicleBlip(playerVehicle, plate, vehicleName or vehicleData.vehicle, category or "sedans")

        -- Load NPC model
        local npcHash = GetHashKey(Config.NPCModel)
        if not RequestModelAsync(npcHash) then
            QBCore.Functions.Notify('Failed to load valet NPC!', 'error')
            if DoesEntityExist(playerVehicle) then DeleteEntity(playerVehicle) end
            RemoveVehicleBlip(plate)
            return
        end

        local npc = CreatePed(4, npcHash, spawnCoord.x, spawnCoord.y, spawnCoord.z, 0.0, true, false)
        Wait(400)

        if not DoesEntityExist(npc) then
            QBCore.Functions.Notify('Failed to spawn valet NPC!', 'error')
            if DoesEntityExist(playerVehicle) then DeleteEntity(playerVehicle) end
            RemoveVehicleBlip(plate)
            SetModelAsNoLongerNeeded(npcHash)
            return
        end

        SetModelAsNoLongerNeeded(npcHash)
        SetPedIntoVehicle(npc, playerVehicle, -1)
        Wait(200)

        SetEntityAsMissionEntity(npc, true, true)
        SetEntityAsMissionEntity(playerVehicle, true, true)
        SetPedCanBeTargetted(npc, false)
        SetBlockingOfNonTemporaryEvents(npc, true)

        -- Drive toward player
        local dest = GetEntityCoords(PlayerPedId())
        TaskVehicleDriveToCoord(
            npc, playerVehicle,
            dest.x, dest.y, dest.z,
            Config.DriveSpeed,
            0,
            GetEntityModel(playerVehicle),
            786603,   -- normal + obey traffic
            Config.ArrivalDistance - 2.0,
            true
        )

        QBCore.Functions.Notify('🚗 Your valet is on the way! Check your map.', 'primary')
        DebugPrint("NPC driving to player")

        -- ----------------------------------------------------------------
        -- ARRIVAL DETECTION — event-driven, checks every 1s only
        -- ----------------------------------------------------------------
        local deliveryComplete = false
        local timedOut         = false

        -- Timeout kill-switch
        SetTimeout(90000, function()
            if not deliveryComplete then
                timedOut = true
                DebugPrint("Delivery timeout reached")
            end
        end)

        CreateThread(function()
            while not deliveryComplete and not timedOut do
                if DoesEntityExist(npc) and DoesEntityExist(playerVehicle) then
                    local npcCoords    = GetEntityCoords(npc)
                    local plCoords     = GetEntityCoords(PlayerPedId())
                    local distance     = #(npcCoords - plCoords)

                    DebugPrint("NPC distance to player: " .. math.floor(distance))

                    if distance <= Config.ArrivalDistance then
                        deliveryComplete = true

                        -- Brake NPC
                        TaskVehicleTempAction(npc, playerVehicle, 6, 3000)
                        Wait(2500)

                        -- Stop at exact player location if still too far
                        local finalDist = #(GetEntityCoords(npc) - GetEntityCoords(PlayerPedId()))
                        if finalDist > Config.ArrivalDistance + 5.0 then
                            -- Teleport vehicle close to player cleanly
                            local closeCoord = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 5.0, 0.0)
                            SetEntityCoords(playerVehicle, closeCoord.x, closeCoord.y, closeCoord.z, false, false, false, false)
                            SetVehicleOnGroundProperly(playerVehicle)
                            Wait(300)
                        end

                        TaskLeaveVehicle(npc, playerVehicle, 0)
                        Wait(2200)

                        -- Hand keys to player
                        local vPlate = GetVehicleNumberPlateText(playerVehicle)
                        if GetResourceState('qb-vehiclekeys') == 'started' then
                            TriggerEvent('vehiclekeys:client:SetOwner', vPlate)
                            TriggerEvent('qb-vehiclekeys:client:AddKeys', vPlate)
                            TriggerServerEvent('qb-vehiclekeys:server:GiveKeys', vPlate)
                        end

                        -- Remove blip since vehicle is delivered
                        RemoveVehicleBlip(vPlate)

                        -- Register with impound system for tracking & auto-impound
                        local netId = NetworkGetNetworkIdFromEntity(playerVehicle)
                        TriggerServerEvent('valet:impound:trackVehicle', netId, vPlate, nil, vehicleData.garage)

                        -- Heartbeat: tell server we are still in the vehicle
                        CreateThread(function()
                            while DoesEntityExist(playerVehicle) do
                                if GetPedInVehicleSeat(playerVehicle, -1) == PlayerPedId() or
                                   GetPedInVehicleSeat(playerVehicle,  0) == PlayerPedId() then
                                    TriggerServerEvent('valet:impound:occupiedPing', netId)
                                end
                                Wait(30000) -- ping every 30 seconds
                            end
                        end)

                        -- NPC walks away and deletes
                        local walkTo = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, -25.0, 0.0)
                        TaskGoStraightToCoord(npc, walkTo.x, walkTo.y, walkTo.z, 1.0, -1, 0.0, 0.0)
                        Wait(7000)
                        if DoesEntityExist(npc) then DeleteEntity(npc) end

                        QBCore.Functions.Notify('✅ Your vehicle has been delivered!', 'success')
                        DebugPrint("Delivery complete")
                    end
                end
                Wait(1000)
            end

            -- Timeout fallback
            if timedOut and not deliveryComplete then
                if DoesEntityExist(npc) then
                    TaskLeaveVehicle(npc, playerVehicle, 0)
                    Wait(1500)
                    DeleteEntity(npc)
                end
                if DoesEntityExist(playerVehicle) then
                    local vPlate = GetVehicleNumberPlateText(playerVehicle)
                    if GetResourceState('qb-vehiclekeys') == 'started' then
                        TriggerEvent('vehiclekeys:client:SetOwner', vPlate)
                        TriggerEvent('qb-vehiclekeys:client:AddKeys', vPlate)
                        TriggerServerEvent('qb-vehiclekeys:server:GiveKeys', vPlate)
                    end
                    RemoveVehicleBlip(vPlate)
                end
                QBCore.Functions.Notify('⚠️ Valet timed out — vehicle left nearby.', 'error')
            end
        end)
    end)
end

--==============================================================================
-- CLIENT EVENTS
--==============================================================================

RegisterNetEvent('valet:client:showMenu', function(menuOptions)
    DebugPrint("Menu received, options: " .. #menuOptions)

    local formatted = {}
    for _, option in pairs(menuOptions) do
        table.insert(formatted, {
            title       = option.title,
            description = option.description,
            icon        = option.icon,
            onSelect    = function()
                TriggerServerEvent('valet:server:requestVehicle', option.vehicleData, option.vehicleName)
            end
        })
    end

    exports.ox_lib:registerContext({
        id          = 'valet_menu',
        title       = '🚗 Valet Service',
        description = 'Select a vehicle for delivery:',
        options     = formatted
    })

    exports.ox_lib:showContext('valet_menu')
end)

RegisterNetEvent('valet:client:spawnDelivery', function(vehicleData, vehicleName, category)
    DebugPrint("Spawn delivery triggered")
    SpawnNPCDelivery(vehicleData, vehicleName, category)
end)

-- Impound notification (from impound.lua server side)
RegisterNetEvent('valet:client:vehicleImpounded', function(plate, vehicleName)
    QBCore.Functions.Notify('🚔 Your ' .. vehicleName .. ' (' .. plate .. ') has been impounded!', 'error', 6000)
    RemoveVehicleBlip(plate)
end)

local QBCore = exports['qb-core']:GetCoreObject()

--==============================================================================
-- IMPOUND CLIENT
--==============================================================================

-- Server told us to delete a specific vehicle entity
RegisterNetEvent('valet:impound:deleteVehicle', function(netId)
    local vehicle = NetToVeh(netId)
    if DoesEntityExist(vehicle) then
        SetVehicleAsNoLongerNeeded(vehicle)
        DeleteVehicle(vehicle)
    end
end)

-- Broadcast: admin wiped X vehicles
RegisterNetEvent('valet:impound:wipeNotify', function(count)
    QBCore.Functions.Notify('🚔 [ADMIN] ' .. count .. ' vehicle(s) removed from the city.', 'error', 6000)
end)

--==============================================================================
-- WORLD SCAN
-- Server cannot call GetGamePool — so it asks this client to do it.
-- We return a plain list: netId (number), plate (string), occupied (1 or 0).
-- Using 1/0 instead of true/false to avoid any JSON serialization issues.
--==============================================================================

RegisterNetEvent('valet:impound:requestScan', function()
    CreateThread(function()
        -- Build a set of all real player ped handles so we can check against them
        local playerPeds = {}
        for _, playerId in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(playerId)
            if ped and ped ~= 0 then
                playerPeds[ped] = true
            end
        end

        local results  = {}
        local vehicles = GetGamePool('CVehicle')

        print("^3[IMPOUND CLIENT]^7 Scan requested. Vehicles in pool: " .. #vehicles)

        for _, vehicle in ipairs(vehicles) do
            if DoesEntityExist(vehicle) and NetworkGetEntityIsNetworked(vehicle) then
                local netId = NetworkGetNetworkIdFromEntity(vehicle)

                -- Only occupied if a real player ped is in any seat
                local occupied = 0
                local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
                for seat = -1, maxSeats do
                    if not IsVehicleSeatFree(vehicle, seat) then
                        local pedInSeat = GetPedInVehicleSeat(vehicle, seat)
                        if playerPeds[pedInSeat] then
                            occupied = 1
                            break
                        end
                    end
                end

                local plate = GetVehicleNumberPlateText(vehicle) or ""
                plate = plate:gsub("%s+", "")

                print(string.format("^3[IMPOUND CLIENT]^7 netId=%d plate=%s occupied=%d", netId, plate, occupied))

                table.insert(results, {
                    netId    = netId,
                    plate    = plate,
                    occupied = occupied,
                })
            end
        end

        print("^3[IMPOUND CLIENT]^7 Scan complete. Sending " .. #results .. " entries to server.")
        TriggerServerEvent('valet:impound:scanResult', results)
    end)
end)

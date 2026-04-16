local QBCore = exports['qb-core']:GetCoreObject()

--==============================================================================
-- CONFIG
--==============================================================================

local Config = {
    ValetPrice   = 250,
    CommandName  = 'valet',
    Debug        = false
}

local function DebugPrint(msg)
    if Config.Debug then print("^3[VALET SERVER]^7 " .. msg) end
end

--==============================================================================
-- VEHICLE ICONS / CLASS NAMES
--==============================================================================

local VehicleIcons = {
    ['0'] = '🚗', ['1'] = '🚗', ['2'] = '🚗', ['3'] = '🚗',
    ['4'] = '🚗', ['5'] = '🚗', ['6'] = '🚗', ['7'] = '🚗',
    ['8'] = '🚗', ['9'] = '🚗', ['10'] = '🚗', ['11'] = '🚗',
    ['12'] = '🚗', ['13'] = '🚗', ['14'] = '🚗', ['15'] = '🚗',
    ['16'] = '🚗', ['17'] = '🚗', ['18'] = '🚗', ['19'] = '🚗',
    ['20'] = '🚗', ['21'] = '🚗'
}

local VehicleClasses = {
    ['0'] = 'Compact', ['1'] = 'Sedan', ['2'] = 'SUV', ['3'] = 'Coupe',
    ['4'] = 'Muscle', ['5'] = 'Sports Classic', ['6'] = 'Sports', ['7'] = 'Super',
    ['8'] = 'Motorcycle', ['9'] = 'Off-road', ['10'] = 'Industrial', ['11'] = 'Utility',
    ['12'] = 'Van', ['13'] = 'Cycle', ['14'] = 'Boat', ['15'] = 'Helicopter',
    ['16'] = 'Plane', ['17'] = 'Service', ['18'] = 'Emergency', ['19'] = 'Military',
    ['20'] = 'Commercial', ['21'] = 'Train'
}

local CategoryNameMap = {
    sports = 6, super = 7, muscle = 4,
    motorcycles = 8, suvs = 2, sedans = 1,
    compacts = 0, coupes = 3, offroad = 9,
    vans = 12
}

--==============================================================================
-- HELPERS
--==============================================================================

local function GetVehicleName(model)
    if QBCore.Shared.Vehicles[model] then
        return QBCore.Shared.Vehicles[model].name
    end
    return string.gsub(model, "^%l", string.upper)
end

local function GetVehicleClass(model)
    local class = 6
    if QBCore.Shared.Vehicles[model] then
        local cat = QBCore.Shared.Vehicles[model].category
        if type(cat) == "string" then
            class = CategoryNameMap[cat:lower()] or 6
        elseif type(cat) == "number" then
            class = cat
        end
    end
    return class
end

local function GetCategoryName(model)
    if QBCore.Shared.Vehicles[model] then
        local cat = QBCore.Shared.Vehicles[model].category
        if type(cat) == "string" then return cat:lower() end
    end
    return "sedans"
end

--==============================================================================
-- /valet COMMAND
--==============================================================================

RegisterCommand(Config.CommandName, function(source)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local vehicles = MySQL.query.await(
        'SELECT * FROM player_vehicles WHERE citizenid = ? AND state = 1',
        { Player.PlayerData.citizenid }
    )

    if not vehicles or #vehicles == 0 then
        TriggerClientEvent('QBCore:Notify', src, '❌ You have no vehicles in storage!', 'error')
        return
    end

    local menuOptions = {}
    for _, vehicle in pairs(vehicles) do
        local model    = vehicle.vehicle
        local name     = GetVehicleName(model)
        local class    = GetVehicleClass(model)
        local classStr = tostring(class)
        local category = GetCategoryName(model)

        table.insert(menuOptions, {
            title       = (VehicleIcons[classStr] or "🚗") .. " " .. name,
            description = (VehicleClasses[classStr] or "Vehicle") ..
                          " • " .. (vehicle.garage or "Unknown") ..
                          " • Plate: " .. vehicle.plate,
            vehicleData  = vehicle,
            vehicleName  = name,
            category     = category,
        })
    end

    TriggerClientEvent('valet:client:showMenu', src, menuOptions)
    DebugPrint("Menu sent to " .. src)
end)

--==============================================================================
-- SERVER EVENT: Request vehicle delivery
--==============================================================================

RegisterNetEvent('valet:server:requestVehicle', function(vehicleData, vehicleName)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(vehicleData) ~= 'table' or type(vehicleData.plate) ~= 'string' then return end
    if type(vehicleName) ~= 'string' or #vehicleName > 100 then return end

    -- Server-side validation: confirm this plate actually belongs to the player
    local owned = MySQL.scalar.await(
        'SELECT COUNT(*) FROM player_vehicles WHERE plate = ? AND citizenid = ? AND state = 1',
        { vehicleData.plate, Player.PlayerData.citizenid }
    )

    if not owned or owned == 0 then
        TriggerClientEvent('QBCore:Notify', src, '❌ You do not own this vehicle or it is already out.', 'error')
        return
    end

    -- Money check
    local cash = Player.PlayerData.money.cash
    local bank = Player.PlayerData.money.bank

    if cash < Config.ValetPrice and bank < Config.ValetPrice then
        TriggerClientEvent('QBCore:Notify', src, '❌ Not enough money! Valet costs $' .. Config.ValetPrice, 'error')
        return
    end

    if cash >= Config.ValetPrice then
        Player.Functions.RemoveMoney('cash', Config.ValetPrice, 'valet-service')
    else
        Player.Functions.RemoveMoney('bank', Config.ValetPrice, 'valet-service')
    end

    -- Set vehicle state to out (0 = out, 1 = in garage)
    MySQL.update.await('UPDATE player_vehicles SET state = 0 WHERE plate = ?', { vehicleData.plate })

    local category = GetCategoryName(vehicleData.vehicle)

    TriggerClientEvent('QBCore:Notify', src, '🚗 Valet dispatched! $' .. Config.ValetPrice .. ' charged.', 'success')
    TriggerClientEvent('valet:client:spawnDelivery', src, vehicleData, vehicleName, category)

    DebugPrint("Delivery dispatched for " .. vehicleName .. " to player " .. src)
end)

--==============================================================================
-- STARTUP LOG
--==============================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print('^2[GC-VALET]^7 Loaded! /' .. Config.CommandName .. ' — Cost: $' .. Config.ValetPrice)
    end
end)

local QBCore = exports['qb-core']:GetCoreObject()
local diggingPlayers = {}

RegisterNetEvent("dig:syncHoleStart")
AddEventHandler("dig:syncHoleStart", function(coords)
    local src = source
    TriggerClientEvent("dig:clientStartEffects", -1, coords, src)
end)

RegisterNetEvent("dig:syncHoleProp")
AddEventHandler("dig:syncHoleProp", function(coords)
    local src = source
    diggingPlayers[src] = diggingPlayers[src] or {}
    diggingPlayers[src].coords = coords
    TriggerClientEvent("dig:clientCreateHole", -1, coords, src)
end)

RegisterNetEvent("dig:syncPlayerLeave")
AddEventHandler("dig:syncPlayerLeave", function()
    local src = source
    diggingPlayers[src] = nil
    TriggerClientEvent("dig:clientLeaveHole", -1, src)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    if diggingPlayers[src] then
        diggingPlayers[src] = nil
        TriggerClientEvent("dig:clientLeaveHole", -1, src)
    end
end)

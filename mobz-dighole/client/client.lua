local QBCore = exports['qb-core']:GetCoreObject()
local isInHole = false
local hiddenCoords = nil
local holeProps = {}  -- table to track hole props by serverId
local diggingCooldown = 0 -- timestamp of when the cooldown ends
local COOLDOWN_TIME = 30 -- cooldown time in seconds

local shovelModel = `prop_tool_shovel`

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function LoadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
end

local function AttachShovelToHand(ped)
    LoadModel(shovelModel)
    local boneIndex = GetPedBoneIndex(ped, 57005) -- right hand bone
    local shovel = CreateObject(shovelModel, 1.0, 1.0, 1.0, true, true, false)
    AttachEntityToEntity(
		shovel, ped, boneIndex,
		0.1, 0.0, 0.0,           -- ⬅ Move X slightly to the right
		45.0, 20.0, 250.0,       -- Rotation stays the same
		true, true, false, true, 1, true
	)

    return shovel
end

local function RemoveShovel(shovel)
    if shovel and DoesEntityExist(shovel) then
        DeleteEntity(shovel)
    end
end

function LoadParticle(dict)
    if not HasNamedPtfxAssetLoaded(dict) then
        RequestNamedPtfxAsset(dict)
        while not HasNamedPtfxAssetLoaded(dict) do
            Wait(10)
        end
    end
    UseParticleFxAssetNextCall(dict)
end

RegisterCommand("dighole", function()
    local currentTime = GetGameTimer() / 1000

    if isInHole then
        QBCore.Functions.Notify("You are already hiding in a hole!", "error")
        return
    end

    if currentTime < diggingCooldown then
        local remaining = math.ceil(diggingCooldown - currentTime)
        QBCore.Functions.Notify("You must wait " .. remaining .. " seconds before digging again.", "error")
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    TriggerServerEvent("dig:syncHoleStart", coords)

    --LoadAnimDict("random@burial")
	--TaskPlayAnim(ped, "random@burial", "a_burial", 8.0, -8.0, -1, 1, 0, false, false, false)
	
	--local shovel = AttachShovelToHand(ped) -- attach shovel prop
	
	TaskStartScenarioInPlace(ped, "world_human_gardener_plant", 0, true)

    QBCore.Functions.Progressbar("dig_hole", "Digging into gravel...", 8000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableCombat = true,
    }, {}, {}, {}, function() -- On finish
        ClearPedTasks(ped)
        RemoveShovel(shovel)

        TriggerServerEvent("dig:syncHoleProp", coords)
		
		-- Make all peds ignore the player
		SetPlayerCanBeHassledByGangs(PlayerId(), false)
		SetEveryoneIgnorePlayer(PlayerId(), true)
		SetPoliceIgnorePlayer(PlayerId(), true)
		
        SetEntityCoords(ped, coords.x, coords.y, coords.z - 1.4)
        SetEntityVisible(ped, false, false)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)

        hiddenCoords = coords
        isInHole = true

        diggingCooldown = currentTime + COOLDOWN_TIME

        QBCore.Functions.Notify("You are hidden. Use /leavehole to exit.", "success")
    end, function() -- Cancel
        ClearPedTasks(ped)
        RemoveShovel(shovel)
        QBCore.Functions.Notify("Dig cancelled.", "error")
    end)
end)
RegisterCommand("leavehole", function()
    if not isInHole then
        QBCore.Functions.Notify("You are not hiding in a hole!", "error")
        return
    end

    local ped = PlayerPedId()
    SetEntityCoords(ped, hiddenCoords.x, hiddenCoords.y, hiddenCoords.z + 1.4)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
	
	-- Re-enable ped interaction
	SetPlayerCanBeHassledByGangs(PlayerId(), true)
	SetEveryoneIgnorePlayer(PlayerId(), false)
	SetPoliceIgnorePlayer(PlayerId(), false)
	
    TriggerServerEvent("dig:syncPlayerLeave")

    isInHole = false
    hiddenCoords = nil
end)

RegisterNetEvent("dig:clientStartEffects")
AddEventHandler("dig:clientStartEffects", function(coords, sourceId)
    LoadParticle("core")
    UseParticleFxAssetNextCall("core")

    StartParticleFxNonLoopedAtCoord(
        "ent_anim_dust",          -- Effect name
        coords.x, coords.y, coords.z + 0.3,  -- Location (Z+0.3 lifts dust slightly)
        0.0, 0.0, 0.0,            -- Rotation
        1.5,                      -- Scale (1.0–2.0 is usually good)
        false, false, false       -- Looping & network options
    )
end)


RegisterNetEvent("dig:clientCreateHole")
AddEventHandler("dig:clientCreateHole", function(coords, sourceId)
    -- Create hole prop for given player id, keep track so we can delete it later
	LoadModel('prop_pile_dirt_01')
	local offsetZ = -1.9 -- Tune this value as needed
	local coords = GetEntityCoords(PlayerPedId()) -- Or wherever you're digging
	local hole = CreateObject('prop_pile_dirt_01', coords.x, coords.y, coords.z + offsetZ, true, true, true)

	SetEntityHeading(hole, GetEntityHeading(PlayerPedId()))
	SetEntityAsMissionEntity(hole, true, true)

    holeProps[sourceId] = hole
end)

RegisterNetEvent("dig:clientLeaveHole")
AddEventHandler("dig:clientLeaveHole", function(sourceId)
    -- Remove hole prop and show player for everyone
    local hole = holeProps[sourceId]
    if hole and DoesEntityExist(hole) then
        DeleteEntity(hole)
        holeProps[sourceId] = nil
    end

    local player = GetPlayerFromServerId(sourceId)
    if player ~= -1 then
        local ped = GetPlayerPed(player)
        if DoesEntityExist(ped) then
            SetEntityVisible(ped, true, false)
            SetEntityInvincible(ped, false)
            FreezeEntityPosition(ped, false)
        end
    end
end)

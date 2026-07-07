local menuOpen = false
local currentSpawnedVehicle = 0        -- véhicule "catalogue" (test / spawn rapide, comportement inchangé)
local spawnedGarageVehicles = {}       -- [modelHash] = { entity = veh, blip = blip } (véhicules du garage sortis)

-- ===================== MAPPING DES MODS (mod type -> nombre max dépend du véhicule) =====================
-- Ces types correspondent aux slots natifs SetVehicleMod / GetNumVehicleMods.
-- Le "type de roues" (catégorie : sport/muscle/...) n'est PAS un mod slot, il utilise
-- SetVehicleWheelType/GetVehicleWheelType et est géré séparément (voir applyTuningData).
local ModSlots = {
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 37, -- carrosserie
    11, 12, 13, 15, 16,        -- performance (moteur, freins, transmission, suspension, armure)
    14, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, -- interieur / habitacle
    23, 24                     -- roues (jantes avant, jantes arrière/moto)
}

-- ===================== UTILITAIRES COULEUR =====================

-- Vérifie si une couleur custom a été appliquée (avec repli si la native n'existe pas
-- sur d'anciennes builds du serveur, pour éviter un crash du script).
local function isPrimaryColourCustom(veh)
    local ok, result = pcall(GetIsVehiclePrimaryColourCustom, veh)
    return ok and result
end

local function isSecondaryColourCustom(veh)
    local ok, result = pcall(GetIsVehicleSecondaryColourCustom, veh)
    return ok and result
end

-- Renvoie la couleur RÉELLEMENT affichée par le véhicule (custom si définie, sinon
-- une approximation de la couleur "de série" via client/colors.lua).
local function getVehicleColorRGB(veh)
    local primaryIndex, secondaryIndex = GetVehicleColours(veh)

    local primary
    if isPrimaryColourCustom(veh) then
        local r, g, b = GetVehicleCustomPrimaryColour(veh)
        primary = { r = r, g = g, b = b }
    else
        local rgb = GetApproxColorRGB(primaryIndex)
        primary = { r = rgb[1], g = rgb[2], b = rgb[3] }
    end

    local secondary
    if isSecondaryColourCustom(veh) then
        local r, g, b = GetVehicleCustomSecondaryColour(veh)
        secondary = { r = r, g = g, b = b }
    else
        local rgb = GetApproxColorRGB(secondaryIndex)
        secondary = { r = rgb[1], g = rgb[2], b = rgb[3] }
    end

    return primary, secondary
end

-- ===================== LECTURE DE L'ÉTAT COMPLET D'UN VÉHICULE =====================
-- Utilisé pour pré-remplir l'onglet Personnalisation avec les VRAIES valeurs du véhicule
-- (couleur, mods déjà posés, et le nombre de mods réellement disponibles sur CE véhicule).
local function getVehicleTuningData(veh)
    local mods = {}
    for _, modType in ipairs(ModSlots) do
        local numMods = GetNumVehicleMods(veh, modType)
        mods[tostring(modType)] = {
            value = GetVehicleMod(veh, modType),
            max = numMods - 1 -- -1 si aucun mod dispo pour ce slot sur ce véhicule (numMods = 0)
        }
    end

    local extras = {}
    for i = 1, 20 do
        if DoesExtraExist(veh, i) then
            local isOn = IsVehicleExtraTurnedOn(veh, i)
            extras[tostring(i)] = isOn == true or isOn == 1
        end
    end

    local primary, secondary = getVehicleColorRGB(veh)
    local wheelR, wheelG, wheelB = GetVehicleExtraColours(veh)
    local neonR, neonG, neonB = GetVehicleNeonLightsColour(veh)
    local tireR, tireG, tireB = GetVehicleTyreSmokeColor(veh)

    return {
        mods = mods,
        extras = extras,
        color = primary,
        secondaryColor = secondary,
        wheelColor = { r = wheelR, g = wheelG, b = wheelB },
        neonColor = { r = neonR, g = neonG, b = neonB },
        tireSmokeColor = { r = tireR, g = tireG, b = tireB },
        neon = {
            left = IsVehicleNeonLightEnabled(veh, 0),
            right = IsVehicleNeonLightEnabled(veh, 1),
            front = IsVehicleNeonLightEnabled(veh, 2),
            back = IsVehicleNeonLightEnabled(veh, 3)
        },
        xenon = IsToggleModOn(veh, 22),
        turbo = IsToggleModOn(veh, 18),
        wheelType = GetVehicleWheelType(veh),
        windowTint = GetVehicleWindowTint(veh),
        dirtLevel = GetVehicleDirtLevel(veh),
        plate = GetVehicleNumberPlateText(veh)
    }
end

-- ===================== APPLICATION D'UN TUNING (live NUI + restauration garage) =====================
local function applyTuningData(veh, data)
    if not veh or veh == 0 or not data then return end

    SetVehicleModKit(veh, 0)

    -- Le type de roue (catégorie) doit être appliqué AVANT le mod visuel des jantes,
    -- car il change le nombre de jantes disponibles pour ce véhicule.
    if data.wheelType ~= nil then
        local newWheelType = tonumber(data.wheelType)
        if newWheelType and newWheelType >= -1 then
            SetVehicleWheelType(veh, newWheelType)
        end
    end

    if data.mods then
        for modType, modIndex in pairs(data.mods) do
            local modTypeNum = tonumber(modType)
            local modIndexNum = tonumber(modIndex)
            if modTypeNum and modIndexNum then
                local numMods = GetNumVehicleMods(veh, modTypeNum)
                -- Correction : les index valides vont de -1 à numMods-1 (borne stricte, pas <=)
                if modIndexNum >= -1 and modIndexNum < numMods then
                    SetVehicleMod(veh, modTypeNum, modIndexNum, false)
                end
            end
        end
    end

    if data.color then
        ClearVehicleCustomPrimaryColour(veh)
        SetVehicleCustomPrimaryColour(veh, data.color.r, data.color.g, data.color.b)
    end

    if data.secondaryColor then
        ClearVehicleCustomSecondaryColour(veh)
        SetVehicleCustomSecondaryColour(veh, data.secondaryColor.r, data.secondaryColor.g, data.secondaryColor.b)
    end

    if data.wheelColor then SetVehicleExtraColours(veh, data.wheelColor.r, data.wheelColor.g, data.wheelColor.b) end
    if data.plate and data.plate ~= "" then SetVehicleNumberPlateText(veh, string.upper(data.plate)) end

    if data.neon then
        SetVehicleNeonLightEnabled(veh, 0, data.neon.left or false)
        SetVehicleNeonLightEnabled(veh, 1, data.neon.right or false)
        SetVehicleNeonLightEnabled(veh, 2, data.neon.front or false)
        SetVehicleNeonLightEnabled(veh, 3, data.neon.back or false)
    end

    if data.neonColor then SetVehicleNeonLightsColour(veh, data.neonColor.r, data.neonColor.g, data.neonColor.b) end
    if data.xenon ~= nil then ToggleVehicleMod(veh, 22, data.xenon) end
    if data.turbo ~= nil then ToggleVehicleMod(veh, 18, data.turbo) end
    if data.tireSmokeColor then SetVehicleTyreSmokeColor(veh, data.tireSmokeColor.r, data.tireSmokeColor.g, data.tireSmokeColor.b) end
    if data.windowTint then SetVehicleWindowTint(veh, data.windowTint) end
    if data.dirtLevel then SetVehicleDirtLevel(veh, data.dirtLevel + 0.0) end

    if data.extras then
        for i = 1, 20 do
            if data.extras[tostring(i)] ~= nil then
                SetVehicleExtra(veh, i, not data.extras[tostring(i)])
            end
        end
    end
end

-- ===================== MENU =====================

local function notifyClient(message)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function openMenu()
    if menuOpen then return end
    SetNuiFocus(true, true)
    menuOpen = true
    TriggerServerEvent("vehicleBrowser:requestVehicles")

    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh ~= 0 then
        SendNUIMessage({ action = "vehicleInfo", data = getVehicleTuningData(veh) })
    end

    if Config.EnableGarage then
        TriggerServerEvent("vehicleBrowser:requestGarage")
    end
end

local function closeMenu()
    if not menuOpen then return end
    SetNuiFocus(false, false)
    menuOpen = false
    SendNUIMessage({ action = "closeMenu" })
end

RegisterCommand(Config.Command, function()
    if menuOpen then closeMenu() else openMenu() end
end, false)
RegisterKeyMapping(Config.Command, "Ouvrir le menu des véhicules", "keyboard", "F1")

RegisterNetEvent("vehicleBrowser:receiveVehicles", function(data)
    SendNUIMessage({ action = "loadVehicles", vehicles = data or {} })
end)

RegisterNUICallback("close", function(_, cb)
    closeMenu()
    cb("ok")
end)

-- ===================== CATALOGUE : SPAWN RAPIDE (comportement inchangé) =====================

RegisterNUICallback("spawnVehicle", function(data, cb)
    local model = data.model
    if not model then return cb({ success = false, error = "Aucun modèle spécifié" }) end

    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then return cb({ success = false, error = "Modèle introuvable" }) end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    if Config.DeletePreviousVehicle and currentSpawnedVehicle ~= 0 and DoesEntityExist(currentSpawnedVehicle) then
        DeleteEntity(currentSpawnedVehicle)
        currentSpawnedVehicle = 0
    end

    RequestModel(hash)
    local startTime = GetGameTimer()
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() - startTime > Config.ModelLoadTimeout then
            SetModelAsNoLongerNeeded(hash)
            return cb({ success = false, error = "Timeout lors du chargement du modèle" })
        end
    end

    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    if vehicle == 0 then
        SetModelAsNoLongerNeeded(hash)
        return cb({ success = false, error = "Échec de la création du véhicule" })
    end

    SetPedIntoVehicle(ped, vehicle, -1)
    SetVehicleModKit(vehicle, 0)
    currentSpawnedVehicle = vehicle

    SetModelAsNoLongerNeeded(hash)
    cb({ success = true })

    closeMenu()
end)

-- ===================== PERSONNALISATION (live) =====================

RegisterNUICallback("updateTuning", function(data, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return cb({ success = false, error = "Vous devez être dans un véhicule" }) end

    local previousWheelType = GetVehicleWheelType(veh)
    applyTuningData(veh, data)

    local response = { success = true }

    -- Si le type de roue a changé, le nombre de jantes disponibles change aussi :
    -- on renvoie les nouveaux maximums pour que l'interface adapte ses sliders.
    if data.wheelType ~= nil and tonumber(data.wheelType) ~= previousWheelType then
        response.wheelModsMax = {
            ["23"] = GetNumVehicleMods(veh, 23) - 1,
            ["24"] = GetNumVehicleMods(veh, 24) - 1
        }
    end

    cb(response)
end)

RegisterNUICallback("saveVehicleData", function(_, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return cb({ success = false, error = "Vous devez être dans un véhicule" }) end

    local tuningData = getVehicleTuningData(veh)

    -- On aplatit mods.value pour la sauvegarde (getVehicleTuningData renvoie {value,max} pour l'UI,
    -- mais on ne doit sauvegarder que la valeur réellement appliquée sur le véhicule).
    local flatMods = {}
    for modType, modData in pairs(tuningData.mods) do
        flatMods[modType] = modData.value
    end
    tuningData.mods = flatMods

    tuningData.modelHash = GetEntityModel(veh)
    tuningData.modelName = GetDisplayNameFromVehicleModel(GetEntityModel(veh))

    local coords = GetEntityCoords(veh)
    tuningData.coords = { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(veh) }

    TriggerServerEvent("vehicleBrowser:saveToDB", tuningData)
    closeMenu()
    cb({ success = true })
end)

-- ===================== GARAGE =====================

local function getCoordsPayload(veh)
    local coords = GetEntityCoords(veh)
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(veh)
    }
end

local function saveGarageVehicleCoords(entry)
    if not entry or not entry.plate or not entry.entity or not DoesEntityExist(entry.entity) then return end
    TriggerServerEvent("vehicleBrowser:updateGarageVehicleCoords", entry.plate, getCoordsPayload(entry.entity))
end

local function removeGarageVehicle(modelHash, saveBeforeDelete)
    local entry = spawnedGarageVehicles[modelHash]
    if entry then
        if saveBeforeDelete then
            saveGarageVehicleCoords(entry)
        end
        if entry.blip and DoesBlipExist(entry.blip) then RemoveBlip(entry.blip) end
        if entry.entity and DoesEntityExist(entry.entity) then DeleteEntity(entry.entity) end
        spawnedGarageVehicles[modelHash] = nil
    end
end

local function removeGarageVehicleByPlate(plate, saveBeforeDelete)
    if not plate then return false end

    for modelHash, entry in pairs(spawnedGarageVehicles) do
        if entry and entry.plate == plate then
            removeGarageVehicle(modelHash, saveBeforeDelete)
            return true
        end
    end

    return false
end

local function addBlipForGarageVehicle(veh, modelHash, plate)
    if not Config.EnableBlips then return nil end

    local blip = AddBlipForEntity(veh)
    local paletteSize = #Config.BlipColorPalette
    local colorIndex = Config.BlipColorPalette[(math.abs(modelHash) % paletteSize) + 1]

    SetBlipColour(blip, colorIndex)
    SetBlipAsShortRange(blip, true)
    SetBlipCategory(blip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(plate or "Véhicule du garage")
    EndTextCommandSetBlipName(blip)

    return blip
end

-- Fait apparaître un véhicule du garage. `putPlayerInside` = true pour une sortie manuelle
-- (onglet Garage), false pour l'auto-respawn à la connexion (le joueur n'est pas encore là).
local function spawnGarageVehicleAt(modelHash, tuningData, coords, heading, putPlayerInside)
    if not modelHash or not IsModelInCdimage(modelHash) then return nil end

    -- Si CE modèle est déjà sorti, on le supprime avant de le respawn (règle demandée :
    -- un même modèle ne peut avoir qu'une seule instance sortie à la fois).
    removeGarageVehicle(modelHash, true)

    RequestModel(modelHash)
    local startTime = GetGameTimer()
    while not HasModelLoaded(modelHash) do
        Wait(10)
        if GetGameTimer() - startTime > Config.ModelLoadTimeout then
            SetModelAsNoLongerNeeded(modelHash)
            return nil
        end
    end

    local veh = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading or 0.0, true, false)
    if veh == 0 then
        SetModelAsNoLongerNeeded(modelHash)
        return nil
    end

    applyTuningData(veh, tuningData)
    SetModelAsNoLongerNeeded(modelHash)

    if putPlayerInside then
        SetPedIntoVehicle(PlayerPedId(), veh, -1)
    end

    local plate = tuningData and tuningData.plate
    local blip = addBlipForGarageVehicle(veh, modelHash, plate)
    spawnedGarageVehicles[modelHash] = { entity = veh, blip = blip, plate = plate }

    closeMenu()
    return veh
end

RegisterNetEvent("vehicleBrowser:receiveGarageList", function(list)
    SendNUIMessage({ action = "loadGarage", vehicles = list or {} })
end)

RegisterNUICallback("spawnGarageVehicle", function(data, cb)
    if not data.plate then return cb({ success = false, error = "Plaque manquante" }) end
    TriggerServerEvent("vehicleBrowser:requestGarageVehicleData", data.plate)
    cb({ success = true })
end)

-- La réponse arrive de façon asynchrone (aller-retour serveur) car les données de tuning
-- sont stockées en BDD ; le spawn effectif se fait ici une fois les données reçues.
RegisterNetEvent("vehicleBrowser:receiveGarageVehicleData", function(vehicleRow)
    if not vehicleRow or not vehicleRow.modelHash then return end
    if vehicleRow.plate and vehicleRow.tuningData then
        vehicleRow.tuningData.plate = vehicleRow.tuningData.plate or vehicleRow.plate
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local veh = spawnGarageVehicleAt(vehicleRow.modelHash, vehicleRow.tuningData, coords, heading, true)
    if veh then
        notifyClient("Vehicule sorti du garage !")
    end
end)

-- Auto-respawn à la connexion : on ne met PAS le joueur dedans (il n'est pas forcément là),
-- le véhicule apparaît simplement à sa dernière position enregistrée.
RegisterNetEvent("vehicleBrowser:spawnSavedVehicleAtPosition", function(vehicleRow)
    if not vehicleRow or not vehicleRow.modelHash or not vehicleRow.tuningData or not vehicleRow.tuningData.coords then
        return
    end

    local c = vehicleRow.tuningData.coords
    spawnGarageVehicleAt(vehicleRow.modelHash, vehicleRow.tuningData, { x = c.x, y = c.y, z = c.z }, c.heading, false)
end)

RegisterNUICallback("deleteGarageVehicle", function(data, cb)
    if not data.plate then return cb({ success = false, error = "Plaque manquante" }) end
    TriggerServerEvent("vehicleBrowser:deleteGarageVehicle", data.plate)
    cb({ success = true })
end)

RegisterNUICallback("despawnGarageVehicle", function(data, cb)
    if not data.plate then return cb({ success = false, error = "Plaque manquante" }) end

    if removeGarageVehicleByPlate(data.plate, true) then
        cb({ success = true })
    else
        cb({ success = false, error = "Ce véhicule n'est pas sorti" })
    end
end)

-- Le serveur nous confirme la suppression + le modelHash correspondant pour qu'on retire
-- l'entité/blip physiquement présents dans le monde, le cas échéant.
RegisterNetEvent("vehicleBrowser:garageVehicleDeleted", function(modelHash, plate)
    if plate and removeGarageVehicleByPlate(plate, false) then
        return
    end

    if modelHash then
        removeGarageVehicle(modelHash, false)
    end
end)

CreateThread(function()
    while true do
        Wait(Config.CoordsSaveInterval or 10000)

        for modelHash, entry in pairs(spawnedGarageVehicles) do
            if entry and entry.entity and DoesEntityExist(entry.entity) then
                saveGarageVehicleCoords(entry)
            else
                if entry and entry.blip and DoesBlipExist(entry.blip) then RemoveBlip(entry.blip) end
                spawnedGarageVehicles[modelHash] = nil
            end
        end
    end
end)

if Config.AutoRespawnSavedVehicles then
    RegisterNetEvent("vehicleBrowser:requestAutoRespawn", function()
        -- déclenché par le serveur peu après le chargement du joueur (voir server/main.lua)
    end)
end

-- ===================== NETTOYAGE =====================

AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() then
        if menuOpen then
            SetNuiFocus(false, false)
        end
        for modelHash, _ in pairs(spawnedGarageVehicles) do
            removeGarageVehicle(modelHash, true)
        end
    end
end)

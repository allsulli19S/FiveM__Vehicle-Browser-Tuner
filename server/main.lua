local Vehicles = {}
local hasScanned = false

-- ===================== SCAN DES VÉHICULES DISPONIBLES (inchangé) =====================

local function extractModels(xml)
    local list = {}
    for model in xml:gmatch("<modelName>%s*(.-)%s*</modelName>") do
        if model ~= "" then
            table.insert(list, model)
        end
    end
    return list
end

local function loadVehiclesMeta(resourceName)
    for _, path in ipairs(Config.MetaPaths) do
        local content = LoadResourceFile(resourceName, path)
        if content then
            return content
        end
    end
    return nil
end

local function scanVehicles()
    local newVehicles = {}
    local seen = {}
    local resourceCount = GetNumResources()
    local resourcesWithVehicles = 0

    for i = 0, resourceCount - 1 do
        local res = GetResourceByFindIndex(i)
        if res and res ~= GetCurrentResourceName() and GetResourceState(res) == "started" then
            local metaContent = loadVehiclesMeta(res)
            if metaContent then
                local models = extractModels(metaContent)
                if #models > 0 then
                    resourcesWithVehicles = resourcesWithVehicles + 1
                end
                for _, model in ipairs(models) do
                    if not seen[model] then
                        seen[model] = true
                        table.insert(newVehicles, {
                            model = model,
                            resource = res
                        })
                    end
                end
            end
        end
    end

    table.sort(newVehicles, function(a, b) return a.model < b.model end)
    Vehicles = newVehicles
    hasScanned = true
    print(("[VehicleBrowser] %d véhicule(s) trouvé(s) dans %d resource(s)"):format(#Vehicles, resourcesWithVehicles))
end

CreateThread(function()
    Wait(Config.InitialScanDelay)
    scanVehicles()
end)

RegisterNetEvent("vehicleBrowser:requestVehicles", function()
    local src = source
    if not hasScanned then
        scanVehicles()
    end
    TriggerClientEvent("vehicleBrowser:receiveVehicles", src, Vehicles)
end)

-- ===================== HELPERS QBOX / JOUEUR =====================

local function getPlayer(src)
    if not Config.UseQBox then return nil end
    local QBCore = exports['qb-core']:GetCoreObject()
    if not QBCore then return nil end
    return QBCore.Functions.GetPlayer(src)
end

local function getCitizenId(src)
    if Config.UseQBox then
        local Player = getPlayer(src)
        return Player and Player.PlayerData.citizenid or nil
    else
        local identifiers = GetPlayerIdentifiers(src)
        for _, id in ipairs(identifiers) do
            if string.sub(id, 1, 8) == "license:" then
                return "standalone_" .. id
            end
        end
        return "standalone_" .. src
    end
end

-- ===================== SAUVEGARDE (logique existante, inchangée) =====================

RegisterNetEvent("vehicleBrowser:saveToDB", function(tuningData)
    local src = source
    if not src then
        print("[VehicleBrowser] ERREUR: source est nil")
        return
    end

    print("[VehicleBrowser] Début sauvegarde pour joueur: " .. src)

    if Config.UseQBox then
        local QBCore = exports['qb-core']:GetCoreObject()
        if not QBCore then
            print("[VehicleBrowser] ERREUR: qb-core introuvable !")
            TriggerClientEvent("QBCore:Notify", src, "Erreur: qb-core introuvable", "error")
            return
        end

        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then
            print("[VehicleBrowser] ERREUR: Joueur introuvable (ID: " .. src .. ")")
            TriggerClientEvent("QBCore:Notify", src, "Erreur: Joueur introuvable", "error")
            return
        end

        local citizenid = Player.PlayerData.citizenid
        local license = Player.PlayerData.license
        local plate = tuningData.plate or "SULLI"
        local modelHash = tuningData.modelHash
        local jsonData = json.encode(tuningData)

        MySQL.query("SHOW TABLES LIKE 'player_vehicles'", {}, function(result)
            if not result or #result == 0 then
                print("[VehicleBrowser] ERREUR: Table player_vehicles n'existe pas !")
                TriggerClientEvent("QBCore:Notify", src, "Erreur: Table player_vehicles manquante", "error")
                return
            end

            MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', { plate, citizenid }, function(existing)
                if existing and #existing > 0 then
                    MySQL.update('UPDATE player_vehicles SET vehicle = ?, mods = ?, license = ? WHERE plate = ? AND citizenid = ?', {
                        json.encode({ model = modelHash }),
                        jsonData,
                        license,
                        plate,
                        citizenid
                    }, function(rowsChanged)
                        if rowsChanged > 0 then
                            print("[VehicleBrowser] ✅ Véhicule mis à jour avec succès !")
                            TriggerClientEvent("QBCore:Notify", src, "Véhicule mis à jour avec succès !", "success")
                        else
                            print("[VehicleBrowser] ❌ ERREUR: Aucune ligne mise à jour")
                            TriggerClientEvent("QBCore:Notify", src, "Erreur: Aucune ligne mise à jour", "error")
                        end
                    end)
                else
                    MySQL.insert('INSERT INTO player_vehicles (citizenid, license, plate, vehicle, mods) VALUES (?, ?, ?, ?, ?)', {
                        citizenid,
                        license,
                        plate,
                        json.encode({ model = modelHash }),
                        jsonData
                    }, function(id)
                        if id then
                            print("[VehicleBrowser] ✅ Véhicule sauvegardé avec succès ! (ID: " .. id .. ")")
                            TriggerClientEvent("QBCore:Notify", src, "Véhicule sauvegardé avec succès !", "success")
                        else
                            print("[VehicleBrowser] ❌ ERREUR: Insertion échouée")
                            TriggerClientEvent("QBCore:Notify", src, "Erreur: Sauvegarde échouée", "error")
                        end
                    end)
                end
            end)
        end)
    else
        local identifiers = GetPlayerIdentifiers(src)
        local license = "unknown"
        for _, id in ipairs(identifiers) do
            if string.sub(id, 1, 8) == "license:" then
                license = id
                break
            end
        end

        local citizenid = "standalone_" .. src
        local plate = tuningData.plate or "SULLI"
        local modelHash = tuningData.modelHash
        local jsonData = json.encode(tuningData)

        MySQL.insert('INSERT INTO player_vehicles (citizenid, license, plate, vehicle, mods) VALUES (?, ?, ?, ?, ?)', {
            citizenid,
            license,
            plate,
            json.encode({ model = modelHash }),
            jsonData
        }, function(id)
            if id then
                print("[VehicleBrowser] ✅ Véhicule sauvegardé en mode standalone (ID: " .. id .. ")")
            else
                print("[VehicleBrowser] ❌ ERREUR: Sauvegarde échouée en mode standalone")
            end
        end)
    end
end)

-- ===================== GARAGE : LISTE =====================

RegisterNetEvent("vehicleBrowser:requestGarage", function()
    local src = source
    local citizenid = getCitizenId(src)
    if not citizenid then return end

    MySQL.query('SELECT plate, mods FROM player_vehicles WHERE citizenid = ?', { citizenid }, function(rows)
        local list = {}
        if rows then
            for _, row in ipairs(rows) do
                local ok, decoded = pcall(json.decode, row.mods)
                local modelName = (ok and decoded and decoded.modelName) or "Véhicule inconnu"
                table.insert(list, { plate = row.plate, model = modelName })
            end
        end
        TriggerClientEvent("vehicleBrowser:receiveGarageList", src, list)
    end)
end)

-- ===================== GARAGE : SORTIR UN VÉHICULE =====================

RegisterNetEvent("vehicleBrowser:requestGarageVehicleData", function(plate)
    local src = source
    local citizenid = getCitizenId(src)
    if not citizenid or not plate then return end

    MySQL.query('SELECT mods FROM player_vehicles WHERE citizenid = ? AND plate = ?', { citizenid, plate }, function(rows)
        if not rows or #rows == 0 then
            TriggerClientEvent("QBCore:Notify", src, "Véhicule introuvable en base de données", "error")
            return
        end

        local ok, tuningData = pcall(json.decode, rows[1].mods)
        if not ok or not tuningData or not tuningData.modelHash then
            print("[VehicleBrowser] ERREUR: données de tuning invalides pour la plaque " .. plate)
            return
        end

        tuningData.plate = tuningData.plate or plate

        TriggerClientEvent("vehicleBrowser:receiveGarageVehicleData", src, {
            modelHash = tuningData.modelHash,
            plate = plate,
            tuningData = tuningData
        })
    end)
end)

-- ===================== GARAGE : SAUVEGARDE CONTINUE DES COORDONNEES =====================

RegisterNetEvent("vehicleBrowser:updateGarageVehicleCoords", function(plate, coords)
    local src = source
    local citizenid = getCitizenId(src)
    if not citizenid or not plate or type(coords) ~= "table" then return end
    if type(coords.x) ~= "number" or type(coords.y) ~= "number" or type(coords.z) ~= "number" then return end

    local safeCoords = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = type(coords.heading) == "number" and coords.heading or 0.0
    }

    MySQL.query('SELECT mods FROM player_vehicles WHERE citizenid = ? AND plate = ?', { citizenid, plate }, function(rows)
        if not rows or not rows[1] then return end

        local ok, tuningData = pcall(json.decode, rows[1].mods)
        if not ok or not tuningData then return end

        tuningData.coords = safeCoords

        MySQL.update('UPDATE player_vehicles SET mods = ? WHERE citizenid = ? AND plate = ?', {
            json.encode(tuningData),
            citizenid,
            plate
        })
    end)
end)

-- ===================== GARAGE : SUPPRIMER UN VÉHICULE =====================

RegisterNetEvent("vehicleBrowser:deleteGarageVehicle", function(plate)
    local src = source
    local citizenid = getCitizenId(src)
    if not citizenid or not plate then return end

    MySQL.query('SELECT mods FROM player_vehicles WHERE citizenid = ? AND plate = ?', { citizenid, plate }, function(rows)
        local modelHash = nil
        if rows and rows[1] then
            local ok, decoded = pcall(json.decode, rows[1].mods)
            if ok and decoded then modelHash = decoded.modelHash end
        end

        MySQL.query('DELETE FROM player_vehicles WHERE citizenid = ? AND plate = ?', { citizenid, plate }, function(rowsChanged)
            if rowsChanged and rowsChanged > 0 then
                TriggerClientEvent("QBCore:Notify", src, "Véhicule supprimé du garage", "success")
                TriggerClientEvent("vehicleBrowser:garageVehicleDeleted", src, modelHash, plate)

                -- On renvoie la liste à jour pour rafraîchir l'onglet Garage côté NUI
                MySQL.query('SELECT plate, mods FROM player_vehicles WHERE citizenid = ?', { citizenid }, function(remaining)
                    local list = {}
                    if remaining then
                        for _, row in ipairs(remaining) do
                            local ok, decoded = pcall(json.decode, row.mods)
                            local modelName = (ok and decoded and decoded.modelName) or "Véhicule inconnu"
                            table.insert(list, { plate = row.plate, model = modelName })
                        end
                    end
                    TriggerClientEvent("vehicleBrowser:receiveGarageList", src, list)
                end)
            else
                TriggerClientEvent("QBCore:Notify", src, "Erreur lors de la suppression", "error")
            end
        end)
    end)
end)

-- ===================== AUTO-RESPAWN À LA CONNEXION =====================
-- Fait réapparaître automatiquement, à leur dernière position enregistrée, tous les
-- véhicules qu'un joueur a sauvegardés, une fois son chargement terminé.
--
-- ⚠️ Si votre build QBox n'émet pas exactement l'event "QBCore:Server:PlayerLoaded"
-- (certaines versions récentes de qbx_core utilisent des noms différents), adaptez
-- le nom de l'event ci-dessous.

if Config.AutoRespawnSavedVehicles then
    local function respawnPlayerVehicles(src, citizenid)
        MySQL.query('SELECT mods FROM player_vehicles WHERE citizenid = ? LIMIT ?', { citizenid, Config.MaxAutoRespawnVehicles }, function(rows)
            if not rows or #rows == 0 then return end

            CreateThread(function()
                for _, row in ipairs(rows) do
                    local ok, tuningData = pcall(json.decode, row.mods)
                    if ok and tuningData and tuningData.modelHash and tuningData.coords then
                        TriggerClientEvent("vehicleBrowser:spawnSavedVehicleAtPosition", src, {
                            modelHash = tuningData.modelHash,
                            tuningData = tuningData
                        })
                        Wait(Config.AutoRespawnStagger)
                    end
                end
            end)
        end)
    end

    if Config.UseQBox then
        AddEventHandler("QBCore:Server:PlayerLoaded", function(Player)
            if not Player or not Player.PlayerData then return end
            respawnPlayerVehicles(Player.PlayerData.source, Player.PlayerData.citizenid)
        end)
    else
        -- Mode standalone : pas d'event de "joueur chargé" fiable et générique, on se
        -- contente donc de déclencher au premier chargement du script client (voir
        -- client/main.lua) via un event manuel si besoin. Adaptez selon votre framework.
        RegisterNetEvent("vehicleBrowser:manualRespawnTrigger", function()
            local src = source
            respawnPlayerVehicles(src, getCitizenId(src))
        end)
    end
end

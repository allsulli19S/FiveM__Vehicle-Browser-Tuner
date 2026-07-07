Config = {}

Config.Command = "vehicles"
Config.DeletePreviousVehicle = true
Config.ModelLoadTimeout = 10000

-- Ajout de chemins alternatifs pour être compatible avec les loaders custom (ex: onigri)
Config.MetaPaths = {
    "data/vehicles.meta",
    "meta/vehicles.meta",
    "vehicles.meta",
    "stream/vehicles.meta",
    "onigri/vehicles.meta"
}
Config.InitialScanDelay = 5000
Config.UseQBox = true  -- ⚠️ DOIT ÊTRE À TRUE SI VOUS UTILISEZ QBOX

-- ===================== GARAGE / PERSISTANCE =====================
Config.EnableGarage = true              -- Active l'onglet "Garage" (véhicules sauvegardés en BDD)
Config.EnableBlips = true               -- Ajoute un blip sur la carte pour chaque véhicule sorti du garage
Config.AutoRespawnSavedVehicles = true  -- Fait réapparaître automatiquement les véhicules sauvegardés à la connexion
Config.AutoRespawnStagger = 800         -- Délai (ms) entre chaque spawn si le joueur a plusieurs véhicules sauvegardés
Config.MaxAutoRespawnVehicles = 15      -- Sécurité anti-spam si un joueur a énormément de véhicules sauvegardés
Config.CoordsSaveInterval = 10000       -- Sauvegarde les coordonnées des véhicules sortis toutes les X ms

-- Palette d'indices de blips (couleurs natives GTA) utilisée en boucle pour différencier
-- visuellement les véhicules du garage. Le jeu ne supporte pas les blips en RGB "libre",
-- uniquement une palette d'indices : on choisit donc une couleur différente par véhicule
-- via ces indices (toujours la même couleur pour un même modèle, entre deux sessions).
Config.BlipColorPalette = { 1, 2, 3, 5, 17, 18, 25, 27, 38, 47, 66, 68, 83 }

Config.Notify = function(source, message, type)
    if Config.UseQBox then
        TriggerClientEvent("QBox:Notify", source, message, type)
    else
        TriggerClientEvent("chat:addMessage", source, { args = { "Vehicle Browser", message } })
    end
end

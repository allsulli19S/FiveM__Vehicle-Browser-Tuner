--[[
    Table APPROXIMATIVE des couleurs "de série" de GTA V (index -> RGB).

    ⚠️ IMPORTANT : GTA V n'utilise pas du vrai RGB pour les couleurs non-custom,
    mais une palette d'environ 160 couleurs indexées (0 à ~159). Il n'existe pas
    de native permettant de récupérer le vrai RGB affiché à l'écran pour un index
    donné. Cette table contient donc des valeurs approchées pour les couleurs les
    plus courantes, afin d'éviter d'afficher du blanc par défaut dans le menu de
    personnalisation. Si tu veux un rendu pixel-perfect, tu peux remplacer/complé-
    ter cette table par la liste officielle complète (facilement trouvable en
    cherchant "GTA V vehicle color codes list").

    Cela ne concerne QUE les véhicules dont la couleur n'a jamais été personnalisée
    (SetVehicleCustomPrimaryColour) : dès qu'une couleur custom existe, le vrai RGB
    exact est utilisé (voir client/main.lua -> getVehicleColorRGB).
]]

local ApproxColors = {
    [0]   = { 12, 12, 12 },     -- Metallic Black
    [1]   = { 40, 40, 42 },     -- Metallic Graphite Black
    [2]   = { 54, 60, 66 },     -- Metallic Black Steel
    [3]   = { 58, 60, 64 },     -- Metallic Dark Silver
    [4]   = { 176, 181, 185 },  -- Metallic Silver
    [5]   = { 161, 166, 175 },  -- Metallic Blue Silver
    [6]   = { 121, 125, 130 },  -- Metallic Steel Gray
    [7]   = { 93, 98, 102 },    -- Metallic Shadow Silver
    [9]   = { 54, 58, 63 },     -- Metallic Midnight Silver
    [11]  = { 48, 49, 49 },     -- Metallic Anthracite Grey
    [12]  = { 20, 20, 20 },     -- Matte Black
    [13]  = { 75, 76, 77 },     -- Matte Gray
    [14]  = { 150, 150, 150 },  -- Matte Light Grey
    [27]  = { 138, 20, 25 },    -- Metallic Red
    [28]  = { 159, 30, 29 },    -- Metallic Torino Red
    [29]  = { 165, 20, 20 },    -- Metallic Formula Red
    [35]  = { 190, 10, 20 },    -- Metallic Candy Red
    [38]  = { 218, 25, 24 },    -- Metallic Racing Red (approx)
    [61]  = { 21, 46, 115 },    -- Metallic Dark Blue (approx)
    [62]  = { 30, 70, 150 },    -- Metallic Saxony Blue (approx)
    [64]  = { 30, 60, 130 },    -- Metallic Ultra Blue (approx)
    [70]  = { 30, 90, 45 },     -- Metallic Racing Green (approx)
    [80]  = { 255, 255, 255 },  -- Metallic White
    [88]  = { 255, 205, 25 },   -- Racing Yellow (approx)
    [99]  = { 255, 130, 20 },   -- Bright Orange (approx)
    [100] = { 130, 20, 130 },   -- Purple (approx)
    [111] = { 245, 245, 245 },  -- Frost White (approx)
    [143] = { 90, 55, 35 },     -- Brown (approx)
}

local DefaultColor = { 150, 150, 150 } -- gris neutre si l'index n'est pas référencé ci-dessus

function GetApproxColorRGB(colorIndex)
    return ApproxColors[colorIndex] or DefaultColor
end

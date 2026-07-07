let vehicles = [];

const app = document.getElementById("app");
const list = document.getElementById("list");
const search = document.getElementById("search");
const garageList = document.getElementById("garageList");
const garageTabBtn = document.getElementById("garageTabBtn");

// Mapping "mod type natif" -> id du slider correspondant dans le HTML.
// Le type de roue (catégorie) N'EST PAS ici : il est géré à part (voir wheelType).
const MOD_SLIDER_MAP = {
    0: "modSpoiler",
    1: "modFrontBumper",
    2: "modRearBumper",
    3: "modSkirts",
    4: "modExhaust",
    5: "modFrame",
    6: "modGrille",
    7: "modHood",
    8: "modLeftFender",
    9: "modRightFender",
    10: "modRoof",
    11: "modEngine",
    12: "modBrakes",
    13: "modTransmission",
    14: "modHorn",
    15: "modSuspension",
    16: "modArmor",
    27: "modTrim",
    28: "modOrnaments",
    29: "modDashboard",
    30: "modDial",
    31: "modDoorSpeakers",
    32: "modSeats",
    33: "modSteeringWheel",
    34: "modShifter",
    35: "modPlaques",
    36: "modSpeakers",
    37: "modTrunk",
    23: "modFrontWheels",
    24: "modRearWheels"
};


// ==============================
// Gestion des onglets
// ==============================
document.querySelectorAll(".tab-btn").forEach(btn => {
    btn.addEventListener("click", () => {
        document.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
        document.querySelectorAll(".tab-content").forEach(c => c.classList.remove("active"));

        btn.classList.add("active");

        const tab = document.getElementById(btn.dataset.tab);
        if (tab) tab.classList.add("active");

        app.classList.toggle("tuning-view", btn.dataset.tab === "tune-tab");
    });
});


// ==============================
// Réception des messages Lua
// ==============================
window.addEventListener("message", (event) => {
    const data = event.data;

    switch (data.action) {

        case "loadVehicles":
            vehicles = Array.isArray(data.vehicles) ? data.vehicles : [];
            app.classList.add("visible");
            render(vehicles);
            break;

        case "vehicleInfo":
            applyVehicleInfo(data.data);
            break;

        case "loadGarage":
            renderGarage(Array.isArray(data.vehicles) ? data.vehicles : []);
            break;

        case "closeMenu":
            app.classList.remove("visible");
            break;

    }
});


// ==============================
// Affichage des véhicules (catalogue)
// ==============================
function render(items) {

    list.innerHTML = "";

    if (!items.length) {
        list.innerHTML = `<div class="empty">🚗 Aucun véhicule trouvé</div>`;
        return;
    }

    items.forEach(vehicle => {

        const row = document.createElement("div");
        row.className = "vehicle";

        row.innerHTML = `
            <span class="model">${escapeHtml(vehicle.model)}</span>
            <span class="resource">${escapeHtml(vehicle.resource || "")}</span>
            <button data-model="${escapeHtml(vehicle.model)}">
                🚗 Spawn
            </button>
        `;

        list.appendChild(row);

    });

}


// ==============================
// Affichage du garage
// ==============================
function renderGarage(items) {

    if (!items.length) {
        garageTabBtn.style.display = "none";
        garageList.innerHTML = "";
        // Si l'onglet Garage était actif et devient vide (ex: après suppression), on
        // repasse sur le catalogue pour ne pas laisser un onglet vide sélectionné.
        if (garageTabBtn.classList.contains("active")) {
            document.querySelector('.tab-btn[data-tab="spawn-tab"]').click();
        }
        return;
    }

    garageTabBtn.style.display = "block";
    garageList.innerHTML = "";

    items.forEach(vehicle => {

        const row = document.createElement("div");
        row.className = "vehicle garage-vehicle";

        row.innerHTML = `
            <span class="model">${escapeHtml(vehicle.model)}</span>
            <span class="resource">${escapeHtml(vehicle.plate || "")}</span>
            <div class="garage-actions">
                <button class="btn-despawn-garage" data-plate="${escapeHtml(vehicle.plate)}">Ranger</button>
                <button class="btn-spawn-garage" data-plate="${escapeHtml(vehicle.plate)}">🚗 Sortir</button>
                <button class="btn-delete-garage" data-plate="${escapeHtml(vehicle.plate)}">🗑️ Supprimer</button>
            </div>
        `;

        garageList.appendChild(row);

    });

}

garageList.addEventListener("click", (e) => {

    const spawnBtn = e.target.closest(".btn-spawn-garage");
    const despawnBtn = e.target.closest(".btn-despawn-garage");
    const deleteBtn = e.target.closest(".btn-delete-garage");

    if (spawnBtn) {
        post("spawnGarageVehicle", { plate: spawnBtn.dataset.plate }).then(response => {
            if (response?.success) {
                showNotification("✅ Véhicule sorti du garage !", "success");
                app.classList.remove("visible");
            } else {
                showNotification(`❌ ${response?.error || "Erreur"}`, "error");
            }
        });
        return;
    }

    if (despawnBtn) {
        post("despawnGarageVehicle", { plate: despawnBtn.dataset.plate }).then(response => {
            if (response?.success) {
                showNotification("Vehicule range du garage.", "success");
            } else {
                showNotification(`Erreur: ${response?.error || "Erreur"}`, "error");
            }
        });
        return;
    }

    if (deleteBtn) {
        const plate = deleteBtn.dataset.plate;
        showGameConfirm("Supprimer definitivement ce vehicule du garage ?", () => {
            post("deleteGarageVehicle", { plate }).then(response => {
                if (response?.success) {
                    showNotification("Vehicule supprime", "info");
                    // Retrait immediat cote client, la liste officielle sera de toute
                    // facon re-synchronisee par le serveur (event loadGarage).
                    const row = deleteBtn.closest(".vehicle");
                    if (row) row.remove();
                    if (!garageList.children.length) {
                        renderGarage([]);
                    }
                } else {
                    showNotification(`Erreur: ${response?.error || "Erreur"}`, "error");
                }
            });
        });
    }

});


// ==============================
// Application des données réelles du véhicule dans l'onglet Personnalisation
// ==============================
function applyVehicleInfo(data) {
    if (!data) return;

    // Mods à plage dynamique (dépend du véhicule réellement assis dessous)
    for (const [modType, sliderId] of Object.entries(MOD_SLIDER_MAP)) {
        const modData = data.mods && data.mods[modType];
        applyModSlider(sliderId, modData);
    }

    // Type de roue (catégorie) : plage fixe, pas liée à GetNumVehicleMods
    setSliderValue("modWheelType", data.wheelType ?? -1);

    // Couleurs réelles du véhicule (fix : ne se met plus sur blanc par défaut)
    if (data.color) setColorInput("primaryColor", data.color);
    if (data.secondaryColor) setColorInput("secondaryColor", data.secondaryColor);
    if (data.wheelColor) setColorInput("wheelColor", data.wheelColor);
    if (data.neonColor) setColorInput("neonColor", data.neonColor);
    if (data.tireSmokeColor) setColorInput("tireSmokeColor", data.tireSmokeColor);

    // Néons (déduit l'option du select à partir des 4 booléens)
    if (data.neon) {
        const { left, right, front, back } = data.neon;
        let mode = "none";
        if (left && right && front && back) mode = "all";
        else if (left) mode = "left";
        else if (right) mode = "right";
        else if (front) mode = "front";
        else if (back) mode = "back";
        setSelectValue("neonLights", mode);
    }

    setCheckbox("modXenon", !!data.xenon);
    setCheckbox("modTurbo", !!data.turbo);
    setSliderValue("modWindowTint", data.windowTint ?? 0);
    setSliderValue("modDirtLevel", Math.round(data.dirtLevel ?? 0));
    setTextValue("plateText", data.plate || "");

    // Extras
    for (let i = 1; i <= 20; i++) {
        const checkbox = document.getElementById(`extra${i}`);
        if (!checkbox) continue;

        const item = checkbox.closest(".extra-item");
        const exists = !!(data.extras && Object.prototype.hasOwnProperty.call(data.extras, String(i)));

        checkbox.disabled = !exists;
        checkbox.checked = exists ? !!data.extras[i] : false;
        if (item) item.classList.toggle("unavailable", !exists);
    }
}

function applyModSlider(sliderId, modData) {
    const slider = document.getElementById(sliderId);
    const valueSpan = document.getElementById(`${sliderId}Value`);
    if (!slider) return;

    const label = slider.closest("label");

    if (!modData || modData.max < 0) {
        // Ce mod n'existe pas sur ce véhicule : on désactive proprement le slider
        slider.min = -1;
        slider.max = -1;
        slider.value = -1;
        slider.disabled = true;
        if (label) label.classList.add("unavailable");
        if (valueSpan) valueSpan.textContent = "-1";
        return;
    }

    slider.disabled = false;
    if (label) label.classList.remove("unavailable");
    slider.min = -1;
    slider.max = modData.max;
    slider.value = Math.min(Math.max(modData.value, -1), modData.max);
    if (valueSpan) valueSpan.textContent = slider.value;
}

function setSliderValue(id, value) {
    const slider = document.getElementById(id);
    const valueSpan = document.getElementById(`${id}Value`);
    if (!slider) return;
    slider.value = value;
    if (valueSpan) valueSpan.textContent = value;
}

function setCheckbox(id, checked) {
    const el = document.getElementById(id);
    if (el) el.checked = checked;
}

function setSelectValue(id, value) {
    const el = document.getElementById(id);
    if (el) el.value = value;
}

function setTextValue(id, value) {
    const el = document.getElementById(id);
    if (el) el.value = value;
}

function setColorInput(id, rgb) {
    const el = document.getElementById(id);
    if (el) el.value = rgbToHex(rgb);
}

function rgbToHex({ r, g, b }) {
    const clamp = v => Math.max(0, Math.min(255, Math.round(v || 0)));
    return "#" + [clamp(r), clamp(g), clamp(b)]
        .map(v => v.toString(16).padStart(2, "0"))
        .join("");
}


// ==============================
// Spawn d'un véhicule (catalogue)
// ==============================
list.addEventListener("click", (e) => {

    const button = e.target.closest("button[data-model]");

    if (!button) return;

    post("spawnVehicle", {
        model: button.dataset.model
    }).then(response => {

        if (response?.success) {

            showNotification(
                "✅ Véhicule spawné avec succès !",
                "success"
            );

        } else {

            showNotification(
                `❌ ${response?.error || "Erreur lors du spawn"}`,
                "error"
            );

        }

    });

});


// ==============================
// Recherche
// ==============================
search.addEventListener("input", (e) => {

    const value = e.target.value.toLowerCase();

    render(

        vehicles.filter(vehicle =>
            vehicle.model.toLowerCase().includes(value)
        )

    );

});


// ==============================
// Initialisation des sliders
// ==============================
function initSliders() {

    document.querySelectorAll(".tune-slider").forEach(slider => {

        const value = document.getElementById(`${slider.id}Value`);

        if (value)
            value.textContent = slider.value;

        slider.addEventListener("input", function () {

            if (value)
                value.textContent = this.value;

            updateVehicleLive();

        });

    });

    // Création automatique des extras
    const container = document.getElementById("extrasContainer");

    if (container) {

        for (let i = 1; i <= 20; i++) {

            const div = document.createElement("div");

            div.className = "extra-item unavailable";

            div.innerHTML = `
                <label>
                    Extra ${i}
                    <input
                        type="checkbox"
                        id="extra${i}"
                        class="extra-checkbox"
                        disabled
                    >
                </label>
            `;

            container.appendChild(div);

            document
                .getElementById(`extra${i}`)
                .addEventListener("change", updateVehicleLive);

        }

    }

}


// ==============================
// Debounce
// ==============================
function debounce(func, wait) {

    let timeout;

    return function (...args) {

        clearTimeout(timeout);

        timeout = setTimeout(() => {

            func.apply(this, args);

        }, wait);

    };

}

// ==============================
// Conversion HEX -> RGB
// ==============================
function hexToRgb(hex) {

    if (!hex) {
        return { r: 255, g: 255, b: 255 };
    }

    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);

    if (!result) {
        return { r: 255, g: 255, b: 255 };
    }

    return {
        r: parseInt(result[1], 16),
        g: parseInt(result[2], 16),
        b: parseInt(result[3], 16)
    };

}


// ==============================
// Mise à jour du véhicule (live)
// ==============================
const updateVehicleLive = debounce(() => {

    const getValue = (id, def = -1) => {

        const element = document.getElementById(id);

        if (!element || element.disabled) return def;

        const value = parseInt(element.value);

        return isNaN(value) ? def : value;

    };

    const getChecked = (id) => {

        const element = document.getElementById(id);

        return element ? element.checked : false;

    };

    const getText = (id) => {

        const element = document.getElementById(id);

        return element ? element.value : "";

    };


    // Couleurs
    const colorRGB = hexToRgb(getText("primaryColor"));
    const secondaryColorRGB = hexToRgb(getText("secondaryColor"));
    const wheelColorRGB = hexToRgb(getText("wheelColor"));
    const neonColorRGB = hexToRgb(getText("neonColor"));
    const tireSmokeColorRGB = hexToRgb(getText("tireSmokeColor"));


    // Néons
    const neonMode = getText("neonLights");

    const neon = {
        left: neonMode === "left" || neonMode === "all",
        right: neonMode === "right" || neonMode === "all",
        front: neonMode === "front" || neonMode === "all",
        back: neonMode === "back" || neonMode === "all"
    };


    // Extras
    const extras = {};

    for (let i = 1; i <= 20; i++) {

        const checkbox = document.getElementById(`extra${i}`);

        if (checkbox && !checkbox.disabled) {
            extras[i] = checkbox.checked;
        }

    }


    // Mods (générés depuis MOD_SLIDER_MAP pour rester synchro avec le HTML)
    const mods = {};
    for (const [modType, sliderId] of Object.entries(MOD_SLIDER_MAP)) {
        mods[modType] = getValue(sliderId);
    }
    mods[18] = getChecked("modTurbo") ? 1 : -1;
    mods[22] = getChecked("modXenon") ? 1 : -1;


    // Envoi au Lua (wheelType est séparé des "mods" : ce n'est pas un SetVehicleMod
    // mais un SetVehicleWheelType)
    post("updateTuning", {

        mods: mods,
        wheelType: getValue("modWheelType", -1),

        color: colorRGB,
        secondaryColor: secondaryColorRGB,
        wheelColor: wheelColorRGB,

        neon: neon,
        neonColor: neonColorRGB,

        tireSmokeColor: tireSmokeColorRGB,

        plate: getText("plateText"),

        windowTint: getValue("modWindowTint", 0),
        dirtLevel: getValue("modDirtLevel", 0),

        xenon: getChecked("modXenon"),
        turbo: getChecked("modTurbo"),

        extras: extras

    }).then(response => {

        // Si le type de roue vient de changer, le nombre de jantes dispo change aussi :
        // on met à jour les bornes des sliders "Jantes Avant/Arrière" en conséquence.
        if (response?.wheelModsMax) {
            applyModSlider("modFrontWheels", { value: getValue("modFrontWheels"), max: response.wheelModsMax["23"] });
            applyModSlider("modRearWheels", { value: getValue("modRearWheels"), max: response.wheelModsMax["24"] });
        }

    });

}, 50);

// Écouteurs pour le tuning en direct
document.querySelectorAll(".tune-slider").forEach(slider => {
    slider.addEventListener("input", updateVehicleLive);
});

document.querySelectorAll(".tune-checkbox").forEach(checkbox => {
    checkbox.addEventListener("change", updateVehicleLive);
});

document.getElementById("primaryColor").addEventListener("input", updateVehicleLive);
document.getElementById("secondaryColor").addEventListener("input", updateVehicleLive);
document.getElementById("wheelColor").addEventListener("input", updateVehicleLive);
document.getElementById("neonColor").addEventListener("input", updateVehicleLive);
document.getElementById("tireSmokeColor").addEventListener("input", updateVehicleLive);
document.getElementById("neonLights").addEventListener("change", updateVehicleLive);
document.getElementById("plateText").addEventListener("input", updateVehicleLive);

// Bouton Sauvegarder
document.getElementById("saveVehicleBtn").addEventListener("click", () => {
    post("saveVehicleData").then(response => {
        if (response && response.success) {
            showNotification("✅ Véhicule sauvegardé avec succès!", "success");
            app.classList.remove("visible");
        } else {
            showNotification(`❌ ${response?.error || "Erreur lors de la sauvegarde"}`, "error");
        }
    });
});

// Bouton Réinitialiser
document.getElementById("resetTuningBtn").addEventListener("click", () => {
    showGameConfirm("Reinitialiser toutes les modifications ?", () => {
        document.querySelectorAll(".tune-slider").forEach(slider => {
            if (slider.disabled) return;
            slider.value = "-1";
            const valueSpan = document.getElementById(`${slider.id}Value`);
            if (valueSpan) {
                valueSpan.textContent = "-1";
            }
        });

        document.querySelectorAll(".tune-checkbox").forEach(checkbox => {
            checkbox.checked = false;
        });

        document.getElementById("primaryColor").value = "#ffffff";
        document.getElementById("secondaryColor").value = "#000000";
        document.getElementById("wheelColor").value = "#ffffff";
        document.getElementById("neonColor").value = "#00ffff";
        document.getElementById("tireSmokeColor").value = "#ffffff";
        document.getElementById("neonLights").value = "none";
        document.getElementById("plateText").value = "";
        document.getElementById("modWindowTint").value = "0";
        document.getElementById("modDirtLevel").value = "0";

        document.querySelectorAll(".extra-checkbox").forEach(checkbox => {
            checkbox.checked = false;
        });

        updateVehicleLive();
        showNotification("Tuning reinitialise", "info");
    });
});

function showGameConfirm(message, onConfirm) {
    document.querySelectorAll(".game-confirm").forEach(el => el.remove());

    const overlay = document.createElement("div");
    overlay.className = "game-confirm";
    overlay.innerHTML = `
        <div class="game-confirm-box">
            <p>${escapeHtml(message)}</p>
            <div class="game-confirm-actions">
                <button type="button" class="confirm-yes">Confirmer</button>
                <button type="button" class="confirm-no">Annuler</button>
            </div>
        </div>
    `;

    overlay.querySelector(".confirm-yes").addEventListener("click", () => {
        overlay.remove();
        onConfirm();
    });

    overlay.querySelector(".confirm-no").addEventListener("click", () => {
        overlay.remove();
    });

    document.body.appendChild(overlay);
}

// Communication avec le client Lua
function post(endpoint, body) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body || {})
    }).then(r => r.json()).catch(() => ({ success: false, error: "Erreur réseau" }));
}

// Fermeture avec la touche Escape
document.addEventListener("keydown", e => {
    if (e.key === "Escape") {
        post("close");
        app.classList.remove("visible");
    }
});

// Échappement HTML pour éviter les injections XSS
function escapeHtml(str) {
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
}

// Affichage des notifications
function showNotification(message, type) {
    const notification = document.createElement("div");
    notification.className = `notification ${type}`;
    notification.textContent = message;
    document.body.appendChild(notification);

    setTimeout(() => {
        notification.classList.add("hide");
        setTimeout(() => notification.remove(), 300);
    }, 5000);
}

// Initialisation au chargement
initSliders();

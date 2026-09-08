-- ============================================================
-- PlantModule.lua
-- Modul data tanaman untuk Farm game
-- Digunakan: _G.PlantModule:findPlants(filter)
-- ============================================================

local PlantModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

-- ============================================================
-- 1. Fungsi untuk mendapatkan DataService dan SavedObjects
-- ============================================================
local function findDataService()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        local ds = modules:FindFirstChild("DataService")
        if ds then return require(ds) end
    end
    local ds = ReplicatedStorage:FindFirstChild("DataService")
    if ds then return require(ds) end
    if _G.DataService then return _G.DataService end
    local success, result = pcall(function()
        return game:GetService("DataService")
    end)
    if success and result then return result end
    return nil
end

local DataService = findDataService()

-- ============================================================
-- 2. Ambil data tanaman dari SavedObjects (server) atau workspace
-- ============================================================
local function getPlantsFromServer()
    if not DataService then return nil end
    local data = DataService:GetData()
    if not data then return nil end

    -- Cari di SavedObjects (seperti untuk egg)
    local saved = data.SaveSlots and data.SaveSlots.AllSlots and data.SaveSlots.AllSlots.DEFAULT and data.SaveSlots.AllSlots.DEFAULT.SavedObjects
    if saved then
        local plants = {}
        for uuid, objData in pairs(saved) do
            local objType = objData.ObjectType or ""
            -- Cari ObjectType yang berhubungan dengan tanaman
            if string.find(objType, "Plant") or string.find(objType, "Fruit") or string.find(objType, "Harvest") or string.find(objType, "Crop") then
                local d = objData.Data or {}
                plants[uuid] = {
                    uuid = uuid,
                    ObjectType = objType,
                    Data = d,
                    PetType = d.Type or d.PlantType or d.Name or "Unknown",
                    Level = d.Level or d.Age or 0,
                    Weight = d.Weight or d.BaseWeight or 0,
                    Mutation = d.Mutation or d.MutationType or "Normal",
                    Location = d.Location or d.GardenBed or "",
                    Status = d.Status or d.Health or "",
                    IsFavorite = d.IsFavorite or d.Favored or false,
                }
            end
        end
        return plants
    end

    -- Coba di GardenData (alternatif)
    local gardenData = data.GardenData or data.PlantsData or data.Garden
    if gardenData then
        local inventory = gardenData.Inventory or gardenData.Plants or gardenData.Data or gardenData
        if type(inventory) == "table" then
            local plants = {}
            for uuid, plant in pairs(inventory) do
                local d = plant.PlantData or plant
                plants[uuid] = {
                    uuid = uuid,
                    ObjectType = "Plant",
                    Data = d,
                    PetType = d.Name or d.PlantType or d.Type or "Unknown",
                    Level = d.Level or d.Age or 0,
                    Weight = d.Weight or d.BaseWeight or 0,
                    Mutation = d.Mutation or d.MutationType or "Normal",
                    Location = d.Location or d.GardenBed or "",
                    Status = d.Status or d.Health or "",
                    IsFavorite = d.IsFavorite or d.Favored or false,
                }
            end
            return plants
        end
    end
    return nil
end

-- ============================================================
-- 3. Fallback: Ambil dari workspace (fisik)
-- ============================================================
local function getPlantsFromWorkspace()
    local plantsPhysical = Workspace:FindFirstChild("Farm") and Workspace.Farm:FindFirstChild("Farm") and Workspace.Farm.Farm:FindFirstChild("Important") and Workspace.Farm.Farm.Important:FindFirstChild("Plants_Physical")
    if not plantsPhysical then return nil end

    local plants = {}
    -- Fungsi untuk mengumpulkan atribut true (mutasi)
    local function collectMutations(obj)
        local muts = {}
        for k, v in pairs(obj:GetAttributes()) do
            if v == true and k ~= "Favored" and k ~= "Favorite" then
                muts[k] = true
            end
        end
        return muts
    end

    for _, plantFolder in ipairs(plantsPhysical:GetChildren()) do
        -- Tentukan target (single atau multi harvest)
        local fruits = plantFolder:FindFirstChild("Fruits")
        local target = nil
        local harvestType = "single"
        if fruits then
            target = fruits:FindFirstChild(plantFolder.Name)
            if not target then
                local children = fruits:GetChildren()
                if #children > 0 then target = children[1] end
            end
            harvestType = "multi"
        else
            target = plantFolder
        end

        if target then
            local muts = collectMutations(target)
            local mutationList = {}
            for m in pairs(muts) do table.insert(mutationList, m) end
            table.sort(mutationList)

            local uuid = target:GetAttribute("OBJECT_UUID") or target:GetAttribute("UUID") or plantFolder.Name .. "_" .. tostring(os.time())
            plants[uuid] = {
                uuid = uuid,
                ObjectType = "Plant",
                Data = target:GetAttributes(),
                PetType = plantFolder.Name,
                Level = target:GetAttribute("Level") or target:GetAttribute("Age") or 0,
                Weight = target:GetAttribute("Weight") or target:GetAttribute("BaseWeight") or 0,
                Mutation = table.concat(mutationList, ",") or "Normal",
                Location = target:GetAttribute("Location") or target:GetAttribute("GardenBed") or "",
                Status = target:GetAttribute("Status") or target:GetAttribute("Health") or "",
                IsFavorite = target:GetAttribute("Favored") == true or target:GetAttribute("Favorite") == true,
                HarvestType = harvestType,
                Mutations = mutationList,
            }
        end
    end
    return plants
end

-- ============================================================
-- 4. Fungsi utama untuk mendapatkan semua tanaman
-- ============================================================
function PlantModule.getAllPlants()
    local serverPlants = getPlantsFromServer()
    if serverPlants and next(serverPlants) then
        return serverPlants
    end
    local wsPlants = getPlantsFromWorkspace()
    if wsPlants and next(wsPlants) then
        return wsPlants
    end
    return {}
end

-- ============================================================
-- 5. Kalkulasi berat (jika ada formula)
-- ============================================================
function PlantModule.calculateWeightAtLevel(baseWeight, level)
    baseWeight = tonumber(baseWeight) or 0
    level = tonumber(level) or 0
    if baseWeight <= 0 then return 0 end
    -- Contoh formula: W(level) = baseWeight * (level + 10) / 10 (sama seperti pet)
    local weight = baseWeight * (level + 10) / 10
    return math.floor(weight * 100 + 0.5) / 100
end

-- ============================================================
-- 6. Terjemahan mutasi (bisa pakai MutationHandler jika ada)
-- ============================================================
function PlantModule.getMutationName(rawCode)
    if not rawCode or rawCode == "" then return "Normal" end
    -- Coba ambil dari MutationHandler
    local Modules = ReplicatedStorage:FindFirstChild("Modules")
    if Modules then
        local mutHandler = Modules:FindFirstChild("MutationHandler")
        if mutHandler then
            local ok, handler = pcall(require, mutHandler)
            if ok and type(handler) == "table" and handler.GetMutations then
                local muts = handler:GetMutations()
                for name, data in pairs(muts) do
                    if data.Id == rawCode or data.Name == rawCode then
                        return data.Name
                    end
                end
            end
        end
    end
    return tostring(rawCode)
end

-- ============================================================
-- 7. Fungsi findPlants dengan filter
-- ============================================================
function PlantModule.findPlants(filter)
    filter = filter or {}
    local allPlants = PlantModule.getAllPlants()
    local results = {}

    for uuid, plant in pairs(allPlants) do
        local name = plant.PetType or "Unknown"
        local mutation = plant.Mutation or "Normal"
        local level = plant.Level or 0
        local weight = plant.Weight or 0
        local location = plant.Location or ""
        local status = plant.Status or ""
        local isFavorite = plant.IsFavorite or false
        local mutList = plant.Mutations or {}

        -- Filter
        if filter.name and not string.lower(name):find(string.lower(filter.name)) then
            goto continue
        end
        if filter.exactName and string.lower(name) ~= string.lower(filter.exactName) then
            goto continue
        end
        if filter.type and string.lower(name) ~= string.lower(filter.type) then
            goto continue
        end
        if filter.mutation then
            local found = false
            for _, m in ipairs(mutList) do
                if string.lower(m) == string.lower(filter.mutation) then
                    found = true
                    break
                end
            end
            if not found then goto continue end
        end
        if filter.isFavorite ~= nil and isFavorite ~= filter.isFavorite then
            goto continue
        end
        if filter.minLevel and level < filter.minLevel then
            goto continue
        end
        if filter.maxLevel and level > filter.maxLevel then
            goto continue
        end
        if filter.minWeight and weight < filter.minWeight then
            goto continue
        end
        if filter.maxWeight and weight > filter.maxWeight then
            goto continue
        end
        if filter.location and string.lower(location) ~= string.lower(filter.location) then
            goto continue
        end
        if filter.status and string.lower(status) ~= string.lower(filter.status) then
            goto continue
        end
        if filter.excludeUUIDs and table.find(filter.excludeUUIDs, uuid) then
            goto continue
        end

        table.insert(results, plant)

        ::continue::
    end

    -- Sortir
    if filter.sortBy then
        table.sort(results, function(a, b)
            local va = a[filter.sortBy] or 0
            local vb = b[filter.sortBy] or 0
            return va < vb
        end)
    end

    if filter.limit then
        local limited = {}
        for i = 1, math.min(filter.limit, #results) do
            table.insert(limited, results[i])
        end
        return limited
    end
    return results
end

-- ============================================================
-- 8. Fungsi bantuan: dapatkan satu tanaman berdasarkan UUID
-- ============================================================
function PlantModule.getPlant(uuid)
    local all = PlantModule.getAllPlants()
    return all[uuid]
end

-- ============================================================
-- 9. Fungsi bantuan: dapatkan mutasi per tanaman
-- ============================================================
function PlantModule.getPlantMutations(uuid)
    local plant = PlantModule.getPlant(uuid)
    if plant then
        return plant.Mutations or {}
    end
    return {}
end

-- ============================================================
-- 10. Simpan ke _G agar bisa dipanggil dari mana saja
-- ============================================================
_G.PlantModule = PlantModule

print("✅ PlantModule berhasil dimuat.")
print("   Gunakan _G.PlantModule:findPlants(filter) untuk mencari tanaman.")
print("   Contoh: _G.PlantModule:findPlants({name = 'Corn', minLevel = 2})")
print("   Data semua tanaman: _G.PlantModule:getAllPlants()")

return PlantModule

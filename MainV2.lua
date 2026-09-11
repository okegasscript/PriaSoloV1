-- ============================================================
-- PRIA SOLO HUB - ALL IN ONE FINAL
-- Tab : Auto Shark | Auto Leveling | Auto Leveling Anubis | PNP | Webhook
-- Notes:
--   - DataPetModule: SATU SUMBER (PriaSoloV1)
--   - Webhook: satu settingan (tab Webhook, dipakai semua fitur)
--   - Badge "PSHB" minimize diperbesar
--   - Dropdown pet seragam & rapi (Mutasi Nama 1,25kg lv45 + #2 utk duplikat)
--   - Anubis: ClearGarden otomatis sebelum equip Frog/Cornling/Anubis
--   - Cache data pet saat startup (tidak scan inventory berkali-kali)
-- ============================================================

-- ================= SERVICES =================
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

local GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
local PetsServiceEvent = GameEvents and GameEvents:FindFirstChild("PetsService")
local NotificationEvent = GameEvents and GameEvents:FindFirstChild("Notification")
local FavoriteToolRemote = GameEvents and GameEvents:FindFirstChild("FavoriteToolRemote")
local RemoveItemRemote = GameEvents and GameEvents:FindFirstChild("Remove_Item")
local BuyGearStock = GameEvents and GameEvents:FindFirstChild("BuyGearStock")

local PetsService = PetsServiceEvent

-- ================= UI REFS (diisi belakangan) =================
local MyConfig = nil
local AnubisConfig = nil
local Anubis_AutoToggle, Anubis_AutoBuyToggle, Anubis_StatusLabel
local Anubis_DD_Anubis, Anubis_DD_Cornling, Anubis_DD_Frog, Anubis_DD_Target, Anubis_DD_Tree
local Anubis_IN_TargetLevel, Anubis_IN_MutCount, Anubis_IN_Threshold
local Shark_DD_Shark, Shark_DD_Target, Shark_DD_Mutasi, Shark_DD_Tumbal
local AL_DD_Tim, AL_DD_Target, AL_IN_TargetLevel
local PNP_DD_Tim

-- ================= LOAD WINDUI =================
local function loadWindUI()
    local urls = {
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
    }
    for attempt = 1, 3 do
        for _, url in ipairs(urls) do
            local ok, result = pcall(function()
                return loadstring(game:HttpGet(url))()
            end)
            if ok and result then return result end
        end
        task.wait(1)
    end
    return nil
end

local WindUI = loadWindUI()
if not WindUI then error("Gagal memuat WindUI!") end

-- ================= LOAD DATAPETMODULE (SATU SUMBER: V1) =================
local DataPetModule
pcall(function()
    DataPetModule = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/DataPetModule.lua"
    ))()
end)
if not DataPetModule then error("Gagal memuat DataPetModule!") end
print("✅ DataPetModule (PriaSoloV1) dimuat")

-- ================= DATASERVICE (SOFT) =================
local DataService
pcall(function()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules and modules:FindFirstChild("DataService") then
        DataService = require(modules.DataService)
        return
    end
    local ds = ReplicatedStorage:FindFirstChild("DataService")
    if ds then DataService = require(ds) return end
    if _G.DataService then DataService = _G.DataService end
end)
if not DataService then
    warn("⚠️ DataService tidak ditemukan (ClearGarden/PNP mungkin terbatas).")
end

-- ================= SHARED HELPERS =================
local DISCORD_WEBHOOK_URL_DEFAULT = "https://discord.com/api/webhooks/1513620114975490058/b6VnqOUomMeXuMKdrfKkJrSfOvSh_p98YcwNGEu6NBe6fwi9qvzbKEN8JV-COEbH0Gx_"
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

local function safeCall(obj, method, ...)
    if obj and type(obj) ~= "function" and type(obj[method]) == "function" then
        local ok, err = pcall(obj[method], obj, ...)
        if not ok then warn("⚠️ " .. tostring(method) .. " gagal: " .. tostring(err)) end
    end
end

local function formatDuration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 0 then seconds = 0 end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return string.format("%dj %dm %ds", h, m, s)
    elseif m > 0 then return string.format("%dm %ds", m, s)
    else return string.format("%ds", s) end
end

local function getWebhookURL()
    if MyConfig then
        local ok, url = pcall(function() return MyConfig:Get("discord_webhook_url") end)
        if ok and type(url) == "string" and url ~= "" then
            return url
        end
    end
    return DISCORD_WEBHOOK_URL_DEFAULT
end

local function sendDiscordWebhook(title, description, color)
    if not httpRequest then
        warn("Fungsi request tidak tersedia di executor ini.")
        return
    end
    local webhookUrl = getWebhookURL()
    if not webhookUrl or webhookUrl == "" then
        warn("URL Discord Webhook belum di-setting.")
        return
    end
    color = color or 3066993
    local payload = { embeds = { { title = title, description = description, color = color } } }
    task.spawn(function()
        pcall(function()
            httpRequest({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload),
            })
        end)
    end)
end

local function getPetInfoByUUID(uuid)
    local ok, allPets = pcall(function() return DataPetModule.findPets({}) end)
    if not ok or not allPets then return nil end
    for _, pet in ipairs(allPets) do
        if pet.uuid == uuid then return pet end
    end
    return nil
end

local function getEquippedPetsUUIDs()
    if not DataService then return {} end
    local ok, data = pcall(function() return DataService:GetData() end)
    if not ok or not data then return {} end
    local equipped = data.EquippedPets
    if not equipped or type(equipped) ~= "table" then
        if data.PetsData then equipped = data.PetsData.EquippedPets end
    end
    if not equipped or #equipped == 0 then return {} end
    local result = {}
    for _, uuid in ipairs(equipped) do
        if type(uuid) == "string" then table.insert(result, uuid) end
    end
    return result
end

local function getMutationList()
    local mutations = {}
    local ok, allPets = pcall(function() return DataPetModule.getAllPets() end)
    if ok and allPets then
        for _, pet in pairs(allPets) do
            local petData = pet.PetData or {}
            local rawMut = petData.MutationType or "Normal"
            local okN, mutName = pcall(function() return DataPetModule.getAutoMutationName(rawMut) end)
            if okN and mutName and mutName ~= "" and not table.find(mutations, mutName) then
                table.insert(mutations, mutName)
            end
        end
    end
    if not table.find(mutations, "Normal") then table.insert(mutations, "Normal") end
    table.sort(mutations)
    return mutations
end

local function formatPetDisplay(pet)
    local weightStr = string.format("%.2f", pet.weight or 0)
    weightStr = weightStr:gsub("%.", ",")
    return string.format("%s %s %skg lv%d", pet.mutation, pet.name, weightStr, pet.level)
end

local function buildDropdownOptions(petList)
    local options = {}
    local nameCount = {}
    for _, pet in ipairs(petList or {}) do
        local baseDisplay = formatPetDisplay(pet)
        local display = baseDisplay
        if nameCount[baseDisplay] then
            nameCount[baseDisplay] = nameCount[baseDisplay] + 1
            display = display .. " (#" .. nameCount[baseDisplay] .. ")"
        else
            nameCount[baseDisplay] = 1
        end
        table.insert(options, { Title = display, Value = pet.uuid })
    end
    if #options == 0 then
        table.insert(options, { Title = "Tidak ada pet", Value = "" })
    end
    return options
end

local function getPetLabelForWebhook(uuid)
    local pet = getPetInfoByUUID(uuid)
    if pet then return formatPetDisplay(pet) end
    return uuid
end

local function normalizeUUIDList(list)
    if type(list) ~= "table" then return {} end
    local result = {}
    for _, item in ipairs(list) do
        if type(item) == "string" and item ~= "" then
            table.insert(result, item)
        elseif type(item) == "table" and item.Value then
            table.insert(result, item.Value)
        end
    end
    return result
end

local function getEquipCFrame()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        return char.HumanoidRootPart.CFrame
    end
    return CFrame.new(0, 0, 0)
end

local function equipPet(uuid)
    if not PetsService or uuid == "" or uuid == nil then return end
    pcall(function()
        PetsService:FireServer("EquipPet", uuid, getEquipCFrame())
    end)
end

local function unequipPet(uuid)
    if not PetsService or uuid == "" or uuid == nil then return end
    pcall(function()
        PetsService:FireServer("UnequipPet", uuid)
    end)
end

local function runClearGarden()
    print("ClearGarden: Memulai...")
    local equipped = getEquippedPetsUUIDs()
    if not equipped or #equipped == 0 then
        print("ClearGarden: Tidak ada pet terpasang.")
        return
    end
    for i, uuid in ipairs(equipped) do
        unequipPet(uuid)
        if i < #equipped then task.wait(0.6) end
    end
    print("ClearGarden: Selesai.")
end

-- ============================================================
-- WINDOW (badge PSHB besar saat minimize)
-- ============================================================
local Window = WindUI:CreateWindow({
    Title = "Pria Solo HUB",
    Folder = "PriaSoloHUB",
    Size = UDim2.new(0, 420, 0, 750),
    Center = true,
    AutoShow = true,
    Draggable = true,
    OpenButton = {
        Title = "PSHB",
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 2,
        Scale = 1.5, -- badge lebih besar (ubah ke 2 kalau mau lebih besar lagi)
        Color = ColorSequence.new(Color3.fromHex("#30FF6A"), Color3.fromHex("#e7ff2f")),
    },
})

local function createConfigObject(name)
    local cm = Window.ConfigManager
    if not cm then
        return {
            Get = function() return nil end,
            Set = function() end,
            Save = function() end,
            Load = function() return nil end,
        }
    end
    if type(cm.CreateConfig) == "function" then
        local ok, cfg = pcall(cm.CreateConfig, cm, name)
        if ok and cfg then return cfg end
    end
    if type(cm.Config) == "function" then
        local ok, cfg = pcall(cm.Config, cm, name)
        if ok and cfg then return cfg end
    end
    return {
        Get = function() return nil end,
        Set = function() end,
        Save = function() end,
        Load = function() return nil end,
    }
end

MyConfig = createConfigObject("AutoSharkConfig")       -- config utama (termasuk webhook)
AnubisConfig = createConfigObject("PriaSoloConfig")    -- config khusus Anubis
pcall(function() MyConfig:Load() end)

-- ================= FARMESP (EMBEDDED) =================
local FarmESP = {}

local officialMutations = {}
local function loadMutations()
    local Modules = ReplicatedStorage:FindFirstChild("Modules")
    if Modules then
        local handler = Modules:FindFirstChild("MutationHandler")
        if handler then
            local ok, h = pcall(require, handler)
            if ok and h and h.GetMutations then
                for name in pairs(h:GetMutations()) do
                    officialMutations[name] = true
                end
                return
            end
        end
    end
    local hardcoded = {
        "Shocked","Windstruck","Dawnbound","Beanbound","Twisted","Cloudtouched","Voidtouched",
        "Wet","Fried","Molten","Vamp","Moonbled","Moist","Crystalized","Alienated","Brewed",
        "Ghostly","Spooky","Volcanic","Slashbound","Sliced","Severed","Alienlike","Galactic",
        "Drenched","Aurora","Chilled","Sundried","Wiltproof","Verdant","Paradisal","Glitched",
        "Gilded","Glimmering","Luminous","Cracked","Enchanted","Frozen","Disco","Choc","Plasma",
        "Heavenly","Burnt","Cooked","Sizzled","Gourmet","Moonlit","Moonbeam","Heartstruck","Luck",
        "Bloodlit","Peppermint","Zombified","Celestial","Meteoric","HoneyGlazed","Pollinated",
        "Amber","OldAmber","AncientAmber","Sandy","Clay","Ceramic","Friendbound","Tempestuous",
        "Infected","Radioactive","Chakra","FoxfireChakra","Cute","Heartbound","CorruptChakra",
        "CorruptFoxfireChakra","AscendedChakra","Static","HarmonisedChakra","HarmonisedFoxfireChakra",
        "Pasta","Sauce","Meatball","Spaghetti","Eclipsed","Enlightened","Tranquil","Corrupt",
        "Toxic","Acidic","Corrosive","Flaming","Blazing","Infernal","Goldsparkle","Oil","Boil",
        "OilBoil","Fortune","Bloom","Rot","Gloom","Blight","Pestilent","Umbral","Shadowbound",
        "Necrotic","Cyclonic","Maelstrom","Stormcharged","Cosmic","Webbed","Astral","Abyssal",
        "Graceful","Jackpot","Plagued","Biohazard","Contagion","Blitzshock","Junkshock","Touchdown",
        "Subzero","Lightcycle","Brainrot","Warped","Azure","Terran","Aromatic","Gnomed","Fall",
        "Blackout","Wilted","Withered","Desolate","Batty","Glossy","Leeched","Lush","Nocturnal",
        "Arid","Mirage","Stampede","Monsoon","Twilight","Typhoon","Wildfast","Tempered","Charcoal",
        "Geode","Supernatural","Stormbound","SunScorched","Riptide","Grim","Extraterrestrial","Mineral",
        "MindBender","Affluent","Fractured","Coin","Arctic","Ornamented","Glacial","Snowtouched",
        "Snowy","Eggnog","Blizzard","Opulent","Gale","Sleepy","Firework","Fiery","Fierywork",
        "Whalebound","Festive","Clockwork","Whimsical","Ash","Haze","Smoldering","Gummy","Floral",
        "Blossoming","Candy","Confection","Spotty","Pollinated_Poor","Pollinated_Fair","Pollinated_Good",
        "Pollinated_Godly","Honeygem","Jellygem","Resplendent","Sylvan","Ember","Shadow","Tidal",
        "Dream","Nightmare"
    }
    for _, name in ipairs(hardcoded) do officialMutations[name] = true end
end
loadMutations()

local espFolder = nil
local espObjects = {}
local espConnection = nil

local function getPlantsPhysical()
    local p = Workspace:FindFirstChild("Farm")
    p = p and p:FindFirstChild("Farm")
    p = p and p:FindFirstChild("Important")
    p = p and p:FindFirstChild("Plants_Physical")
    return p
end

local function collectMutations(obj)
    local muts = {}
    for k, v in pairs(obj:GetAttributes()) do
        if v == true and officialMutations[k] then muts[k] = true end
    end
    return muts
end

local function countTable(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function resolvePart(inst)
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") and inst.PrimaryPart then return inst.PrimaryPart end
    for _, desc in ipairs(inst:GetDescendants()) do
        if desc:IsA("BasePart") then return desc end
    end
    return nil
end

local function scanFruitEntry(plantFolder, fruit, index)
    local muts = collectMutations(fruit)
    for _, desc in ipairs(fruit:GetDescendants()) do
        if desc:IsA("BasePart") or desc:IsA("Model") then
            for k, v in pairs(desc:GetAttributes()) do
                if v == true and officialMutations[k] then muts[k] = true end
            end
        end
    end
    local part = resolvePart(fruit)
    local position = part and part.Position or fruit:GetPivot().Position
    local uuid = fruit:GetAttribute("OBJECT_UUID") or fruit:GetAttribute("UUID") or plantFolder.Name .. "_fruit_" .. index
    return {
        name = plantFolder.Name .. " #" .. index,
        mutCount = countTable(muts),
        position = position,
        uuid = uuid,
        instance = fruit,
        plantName = plantFolder.Name,
    }
end

local function scanAllPlants()
    local plantsPhysical = getPlantsPhysical()
    if not plantsPhysical then
        warn("❌ Plants_Physical tidak ditemukan.")
        return {}
    end

    local plantList = {}
    local index = 0

    for _, plantFolder in ipairs(plantsPhysical:GetChildren()) do
        local fruitsFolder = plantFolder:FindFirstChild("Fruits") or plantFolder:FindFirstChild("Fruit_Spawn")
        if fruitsFolder then
            for _, fruit in ipairs(fruitsFolder:GetChildren()) do
                if fruit:IsA("BasePart") or fruit:IsA("Model") or fruit:IsA("Folder") then
                    index = index + 1
                    table.insert(plantList, scanFruitEntry(plantFolder, fruit, index))
                end
            end
        else
            local target = plantFolder
            if target:IsA("Folder") then
                for _, child in ipairs(target:GetChildren()) do
                    if child:IsA("BasePart") or child:IsA("Model") then
                        target = child
                        break
                    end
                end
            end
            if target:IsA("BasePart") or target:IsA("Model") then
                index = index + 1
                local entry = scanFruitEntry(plantFolder, target, index)
                entry.name = plantFolder.Name
                entry.uuid = target:GetAttribute("OBJECT_UUID") or target:GetAttribute("UUID") or plantFolder.Name .. "_" .. index
                table.insert(plantList, entry)
            end
        end
    end
    return plantList
end

local function createESP(data)
    if not espFolder then
        espFolder = Instance.new("Folder")
        espFolder.Name = "FarmESP"
        espFolder.Parent = Workspace
    end
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.5, 0.5, 0.5)
    part.Position = data.position
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = espFolder

    local bill = Instance.new("BillboardGui")
    bill.Size = UDim2.new(0, 200, 0, 50)
    bill.StudsOffset = Vector3.new(0, 4, 0)
    bill.Adornee = part
    bill.AlwaysOnTop = true
    bill.Parent = espFolder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = string.format("%s: %d", data.name, data.mutCount)
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 18
    label.Font = Enum.Font.SourceSansBold
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Parent = bill

    return { part = part, bill = bill, label = label, uuid = data.uuid }
end

local function updateESP()
    local plants = scanAllPlants()
    local current = {}
    for _, p in ipairs(plants) do current[p.uuid] = p end

    for uuid, obj in pairs(espObjects) do
        if not current[uuid] then
            pcall(function() obj.part:Destroy() obj.bill:Destroy() end)
            espObjects[uuid] = nil
        end
    end
    for uuid, data in pairs(current) do
        local obj = espObjects[uuid]
        if not obj then
            local okC, created = pcall(createESP, data)
            if okC and created then espObjects[uuid] = created end
        else
            pcall(function()
                obj.part.Position = data.position
                obj.label.Text = string.format("%s: %d", data.name, data.mutCount)
            end)
        end
    end
end

function FarmESP.start()
    if espConnection then return end
    updateESP()
    espConnection = RunService.Heartbeat:Connect(function()
        if tick() % 2 < 0.05 then pcall(updateESP) end
    end)
    print("✅ FarmESP started.")
end

function FarmESP.stop()
    if espConnection then
        espConnection:Disconnect()
        espConnection = nil
    end
    for _, obj in pairs(espObjects) do
        pcall(function() obj.part:Destroy() obj.bill:Destroy() end)
    end
    espObjects = {}
    if espFolder then
        pcall(function() espFolder:Destroy() end)
        espFolder = nil
    end
    print("✅ FarmESP stopped.")
end

-- ================= SCAN PER POHON =================
local function scanFruitsOnTree(treeName)
    local all = scanAllPlants()
    local result = {}
    for _, p in ipairs(all) do
        if p.plantName == treeName then table.insert(result, p) end
    end
    return result
end

local function findFruitOnTreeByExactMutation(treeName, mutationCount)
    for _, p in ipairs(scanFruitsOnTree(treeName)) do
        if p.mutCount == mutationCount then return p end
    end
    return nil
end

local function countFruitsOnTreeWithMutationAbove(treeName, threshold, exceptInstance)
    local count = 0
    for _, p in ipairs(scanFruitsOnTree(treeName)) do
        if p.instance ~= exceptInstance and p.mutCount > threshold then count = count + 1 end
    end
    return count
end

-- ================= ANUBIS LOGIC =================
local currentAnubis, currentCornling, currentFrog = {}, {}, {}
local currentTargets = {}
local currentTree = ""
local currentTargetLevel = 500
local currentMutationCount = 1
local currentCollectThreshold = 10
local suppressToggleCallback = false
local suppressAutoBuyToggle = false
local anubisLevelingRunning = false

local NOTIF_TARGET_COUNT = 6
local NOTIF_TIMEOUT_SECONDS = 60
local SPIDER_WEB_WAVE_TARGET_COUNT = 7
local SPIDER_WEB_WAVE_TIMEOUT_SECONDS = 120
local ANUBIS_TIMEOUT_SECONDS = 60
local SHOVEL_MAX_PASSES = 6

local function debugStep(msg)
    print("🐾 [AutoLevelingAnubis] " .. msg)
end

local function anubisSetStatus(txt)
    if Anubis_StatusLabel then pcall(function() Anubis_StatusLabel:SetDesc(txt) end) end
end

local function getTreeList()
    local plantsPhysical = getPlantsPhysical()
    local options = {}
    if plantsPhysical then
        for _, folder in ipairs(plantsPhysical:GetChildren()) do
            table.insert(options, { Title = folder.Name, Value = folder.Name })
        end
    end
    return options
end

local function getPetByUUID(uuid)
    if not uuid then return nil end
    local ok, inv = pcall(function() return DataPetModule.getAllPets() end)
    if not ok or not inv then return nil end
    local pet = inv[uuid]
    if not pet then return nil end

    local petData = pet.PetData or {}
    local okM, mutation = pcall(function() return DataPetModule.getAutoMutationName(petData.MutationType or "Normal") end)
    local level = petData.Level or petData.Lvl or 0
    local baseWeight = petData.Weight or petData.BaseWeight or 0
    local currentWeight = baseWeight
    if DataPetModule.calculateWeightAtLevel then
        local okW, w = pcall(DataPetModule.calculateWeightAtLevel, baseWeight, level)
        if okW and w then currentWeight = w end
    end

    return {
        uuid = uuid, pet = pet, petData = petData,
        name = pet.PetType or petData.PetType or petData.Name or "Unknown",
        mutation = (okM and mutation) or "Normal",
        level = level, baseWeight = baseWeight, weight = currentWeight,
        isFavorite = petData.IsFavorite or false, passive = petData.Passive or "",
    }
end

local function findToolInBackpackByPrefix(namePrefix)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:sub(1, #namePrefix) == namePrefix then return item end
    end
    return nil
end

local function findToolInCharacterByPrefix(namePrefix)
    local character = LocalPlayer.Character
    if not character then return nil end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") and item.Name:sub(1, #namePrefix) == namePrefix then return item end
    end
    return nil
end

local function getHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function equipToolByPrefix(namePrefix)
    local alreadyEquipped = findToolInCharacterByPrefix(namePrefix)
    if alreadyEquipped then return alreadyEquipped end
    local tool = findToolInBackpackByPrefix(namePrefix)
    if not tool then
        warn("⚠️ Tool '" .. namePrefix .. "' tidak ditemukan di Backpack.")
        return nil
    end
    local humanoid = getHumanoid()
    if not humanoid then return nil end
    humanoid:EquipTool(tool)
    task.wait(0.2)
    return findToolInCharacterByPrefix(namePrefix) or tool
end

local function equipNonFavoriteTool()
    local humanoid = getHumanoid()
    if not humanoid then return false end
    local character = LocalPlayer.Character
    if not character then return false end

    local currentTool = nil
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") then currentTool = item break end
    end
    if not currentTool then return true end
    if not string.find(currentTool.Name, "Favorite Tool") then return true end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return false end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and not string.find(tool.Name, "Favorite Tool") then
            humanoid:EquipTool(tool)
            task.wait(0.3)
            debugStep("Lepas Favorite Tool, equip: " .. tool.Name)
            return true
        end
    end
    currentTool.Parent = backpack
    task.wait(0.3)
    debugStep("Favorite Tool dilepas ke Backpack")
    return true
end

local autoBuyRunning = false

local function startAutoBuyFavoriteTool()
    if autoBuyRunning then return end
    if not BuyGearStock then
        warn("⚠️ BuyGearStock remote tidak ditemukan.")
        return
    end
    autoBuyRunning = true
    task.spawn(function()
        local totalBuy, totalDuration = 10, 300
        local interval = totalDuration / totalBuy
        print("🛒 Auto Buy Favorite Tool: 10x dalam 5 menit")
        for i = 1, totalBuy do
            if not autoBuyRunning then break end
            pcall(function() BuyGearStock:FireServer("Favorite Tool") end)
            print("🛒 Pembelian ke-" .. i)
            if i < totalBuy then task.wait(interval) end
        end
        autoBuyRunning = false
        suppressAutoBuyToggle = true
        safeCall(Anubis_AutoBuyToggle, "Set", false)
        suppressAutoBuyToggle = false
        print("✅ Auto Buy Favorite Tool selesai")
    end)
end

local function stopAutoBuyFavoriteTool()
    autoBuyRunning = false
    print("⏹️ Auto Buy Favorite Tool dihentikan.")
end

local function shovelFruitsOnTree(treeName, threshold)
    if not RemoveItemRemote then
        warn("⚠️ Remove_Item remote tidak ditemukan.")
        return
    end
    local shovel = equipToolByPrefix("Shovel [Destroy Plants]")
    if not shovel then return end
    debugStep("Shovel di-equip")

    for pass = 1, SHOVEL_MAX_PASSES do
        local toShovel = {}
        for _, p in ipairs(scanFruitsOnTree(treeName)) do
            if p.mutCount < threshold then table.insert(toShovel, p.instance) end
        end
        if #toShovel == 0 then break end

        debugStep("Pass " .. pass .. ": " .. #toShovel .. " buah < " .. threshold)
        for _, fruit in ipairs(toShovel) do
            pcall(function() RemoveItemRemote:FireServer(fruit) end)
            task.wait(0.3)
        end
        task.wait(0.7)
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack and shovel.Parent == LocalPlayer.Character then shovel.Parent = backpack end
    task.wait(0.3)
end

local function setFruitFavorite(fruitInstance, state)
    if not fruitInstance then return false end
    if not FavoriteToolRemote then
        warn("⚠️ FavoriteToolRemote tidak ditemukan.")
        return false
    end
    local favTool = equipToolByPrefix("Favorite Tool")
    if not favTool then return false end
    local ok, err = pcall(function()
        FavoriteToolRemote:InvokeServer(favTool, fruitInstance, state)
    end)
    if not ok then warn("⚠️ Gagal fav/unfav buah: " .. tostring(err)) end
    return ok
end

local PET_EQUIP_CFRAME = CFrame.new(-16.000007629395, 4, -116.50244903564, 1, 0, 0, 0, 1, 0, 0, 0, 1)

local function equipPetByUUID(uuid)
    if not uuid or not PetsServiceEvent then return end
    pcall(function() PetsServiceEvent:FireServer("EquipPet", uuid, PET_EQUIP_CFRAME) end)
end

local function unequipPetByUUID(uuid)
    if not uuid or not PetsServiceEvent then return end
    pcall(function() PetsServiceEvent:FireServer("UnequipPet", uuid) end)
end

local function equipPetListTogether(uuidList)
    for _, uuid in ipairs(uuidList) do equipPetByUUID(uuid) end
    task.wait(0.2)
end

local function unequipPetList(uuidList)
    for _, uuid in ipairs(uuidList) do unequipPetByUUID(uuid) end
    task.wait(0.2)
end

local function waitForNotificationCount(matchFn, targetCount, timeoutSeconds)
    local count = 0
    local startTime = tick()
    if not NotificationEvent then return 0 end

    local connection
    connection = NotificationEvent.OnClientEvent:Connect(function(...)
        for _, v in ipairs({ ... }) do
            if type(v) == "string" and matchFn(v) then
                count = count + 1
                break
            end
        end
    end)
    while count < targetCount and (tick() - startTime) < timeoutSeconds and anubisLevelingRunning do
        task.wait(0.5)
    end
    connection:Disconnect()
    return count
end

local function waitForGrowthOrSpiderWeb(matchFn, spiderWebTargetCount, timeoutSeconds)
    local growthFound, spiderWebCount = false, 0
    local startTime = tick()
    if not NotificationEvent then return false, 0 end

    local connection
    connection = NotificationEvent.OnClientEvent:Connect(function(...)
        for _, v in ipairs({ ... }) do
            if type(v) == "string" then
                if matchFn(v) then growthFound = true end
                if v:find("Spider's ability: Web Weave", 1, true) then
                    spiderWebCount = spiderWebCount + 1
                end
            end
        end
    end)
    while anubisLevelingRunning and not growthFound and spiderWebCount < spiderWebTargetCount
        and (tick() - startTime) < timeoutSeconds do
        task.wait(0.5)
    end
    connection:Disconnect()
    return growthFound, spiderWebCount
end

-- vFinal: webhook target tercapai Anubis pakai webhook TUNGGAL
local function sendTargetReachedWebhook(petData, targetUUID, targetLevel, durationSeconds)
    local petName = (petData and petData.name) or "Unknown"
    local petMutation = (petData and petData.mutation) or "Normal"
    local petLevel = (petData and petData.level) or targetLevel

    sendDiscordWebhook(
        "🎯 Target Level Tercapai! (Anubis)",
        "**Pet:** " .. tostring(petMutation) .. " " .. tostring(petName) ..
        "\n**UUID:** " .. tostring(targetUUID) ..
        "\n**Level Tercapai:** " .. tostring(petLevel) .. " / " .. tostring(targetLevel) ..
        "\n**Lama Pengerjaan:** " .. formatDuration(durationSeconds),
        3066993
    )
    debugStep("Webhook terkirim (" .. formatDuration(durationSeconds) .. ")")
end

local function unfavoritePreviousTargetFruit(previousInstance)
    if not previousInstance then return false end
    debugStep("Langkah 1: unfavorite buah target sebelumnya")
    local success = setFruitFavorite(previousInstance, false)
    task.wait(0.3)
    return success
end

local function stopLevelingAnubis()
    anubisLevelingRunning = false
    suppressToggleCallback = true
    safeCall(Anubis_AutoToggle, "Set", false)
    suppressToggleCallback = false
    anubisSetStatus("Status: Stopped")
    debugStep("⏹️ STOP")
end

local function startLevelingAnubis()
    if anubisLevelingRunning then return end

    local anubis, cornling, frog = currentAnubis, currentCornling, currentFrog
    local targets = currentTargets
    local targetLevel, mutationCount = currentTargetLevel, currentMutationCount
    local collectThreshold, tree = currentCollectThreshold, currentTree

    if #cornling == 0 then warn("⚠️ Pilih Tim Cornling!") return end
    if #anubis == 0 then warn("⚠️ Pilih Tim Anubis!") return end
    if #frog == 0 then warn("⚠️ Pilih Tim Frog/Echo Frog!") return end
    if #targets == 0 then warn("⚠️ Pilih Target Leveling!") return end
    if targetLevel < 1 then warn("⚠️ Target Level tidak valid!") return end
    if collectThreshold < 0 then warn("⚠️ Batas Shovel tidak valid!") return end
    if tree == "" then warn("⚠️ Pilih Pohon!") return end

    anubisLevelingRunning = true
    anubisSetStatus("Status: Running...")

    task.spawn(function()
        local anubisEquipped = false -- FLAG BARU: status Tim Anubis sedang terpasang atau tidak

        local ok, err = pcall(function()
            for targetIndex, targetUUID in ipairs(targets) do
                if not anubisLevelingRunning then break end

                debugStep("=== TARGET #" .. targetIndex .. "/" .. #targets .. " ===")
                local petData = getPetByUUID(targetUUID)
                local currentLevel = petData and petData.level or 0

                if currentLevel >= targetLevel then
                    debugStep("Target sudah level " .. currentLevel .. ", lewati.")
                    unequipPetByUUID(targetUUID)
                    -- PERUBAHAN: Tim Anubis tetap terpasang, tidak di-unequip
                else
                    local favoritedFruitInstance = nil
                    local targetStartTime = tick()

                    while anubisLevelingRunning and currentLevel < targetLevel do

                        if not anubisEquipped then
                            -- ==========================================================
                            -- SIKLUS PERSIAPAN PENUH (perilaku lama, untuk target baru
                            -- yang belum pernah masuk step Anubis / setelah retry)
                            -- ==========================================================

                            -- LANGKAH 1
                            anubisSetStatus("Status: Bersihkan buah target sebelumnya...")
                            unfavoritePreviousTargetFruit(favoritedFruitInstance)
                            favoritedFruitInstance = nil
                            if not anubisLevelingRunning then break end

                            -- LANGKAH 2 : CLEAR GARDEN -> EQUIP FROG
                            anubisSetStatus("Status: Clear Garden + Equip Frog...")
                            debugStep("Langkah 2: ClearGarden sebelum equip Tim Frog")
                            runClearGarden()
                            task.wait(0.5)
                            if not anubisLevelingRunning then break end

                            equipPetListTogether(frog)
                            if not anubisLevelingRunning then break end

                            anubisSetStatus("Status: Shovel buah mutasi rendah...")
                            shovelFruitsOnTree(tree, collectThreshold)
                            if not anubisLevelingRunning then unequipPetList(frog) break end

                            anubisSetStatus("Status: Tunggu growth / Spider Web Wave...")
                            local frogTrigger = string.format("Frog advanced the growth of your %s plant by 24 hours", tree)
                            local growthFound, spiderWebCount = waitForGrowthOrSpiderWeb(function(msg)
                                return msg:find(frogTrigger) ~= nil
                            end, SPIDER_WEB_WAVE_TARGET_COUNT, SPIDER_WEB_WAVE_TIMEOUT_SECONDS)
                            debugStep(growthFound and "Growth diterima!" or (spiderWebCount .. "x Spider Web Wave"))

                            unequipPetList(frog)
                            task.wait(0.5)
                            if not anubisLevelingRunning then break end

                            -- LANGKAH 3 : CLEAR GARDEN -> EQUIP CORNLING
                            anubisSetStatus("Status: Clear Garden + Equip Cornling...")
                            debugStep("Langkah 3: ClearGarden sebelum equip Tim Cornling")
                            runClearGarden()
                            task.wait(0.5)
                            if not anubisLevelingRunning then break end

                            equipPetListTogether(cornling)
                            local synergyProcs = waitForNotificationCount(function(msg)
                                return msg:find("Corn Synergy") ~= nil
                            end, NOTIF_TARGET_COUNT, NOTIF_TIMEOUT_SECONDS)
                            debugStep("Corn Synergy: " .. synergyProcs .. "/" .. NOTIF_TARGET_COUNT)
                            unequipPetList(cornling)
                            task.wait(0.5)
                            if not anubisLevelingRunning then break end

                            -- LANGKAH 3B
                            anubisSetStatus("Status: Shovel pasca Cornling...")
                            shovelFruitsOnTree(tree, collectThreshold)
                            if not anubisLevelingRunning then break end

                            -- LANGKAH 4
                            anubisSetStatus("Status: Favoritkan buah target mutasi...")
                            local matched = findFruitOnTreeByExactMutation(tree, mutationCount)
                            if matched then
                                setFruitFavorite(matched.instance, true)
                                favoritedFruitInstance = matched.instance
                            else
                                debugStep("Tidak ada buah tepat " .. mutationCount .. " mutasi")
                            end
                            task.wait(0.5)
                            if not anubisLevelingRunning then break end

                            -- LANGKAH 5
                            anubisSetStatus("Status: Shovel buah rendah...")
                            shovelFruitsOnTree(tree, collectThreshold)
                            task.wait(0.5)
                            if not anubisLevelingRunning then break end

                            -- LANGKAH 6 : CLEAR GARDEN -> EQUIP ANUBIS + TARGET
                            anubisSetStatus("Status: Clear Garden + Equip Anubis + Target...")
                            debugStep("Langkah 6: ClearGarden sebelum equip Tim Anubis + Target")
                            runClearGarden()
                            task.wait(0.5)
                            if not anubisLevelingRunning then break end

                            local anubisAndTarget = {}
                            for _, uuid in ipairs(anubis) do table.insert(anubisAndTarget, uuid) end
                            table.insert(anubisAndTarget, targetUUID)
                            equipPetListTogether(anubisAndTarget)
                            anubisEquipped = true -- Tim Anubis (dan target) sekarang terpasang
                        else
                            -- ==========================================================
                            -- PERUBAHAN: FAST-SWAP TARGET
                            -- Target sebelumnya sudah selesai & targetnya sudah di-unequip.
                            -- Tim Anubis MASIH TERPASANG -> cukup equip target baru saja,
                            -- TIDAK kembali ke Langkah 1-5, TIDAK ClearGarden
                            -- (ClearGarden justru akan melepas Tim Anubis).
                            -- ==========================================================
                            anubisSetStatus("Status: Ganti target (Anubis tetap terpasang)...")
                            debugStep("Fast-swap: equip target baru #" .. targetIndex .. " (Anubis tidak dilepas)")
                            equipPetByUUID(targetUUID)
                            task.wait(0.5)
                            targetStartTime = tick() -- reset durasi pengerjaan untuk target baru
                        end

                        anubisSetStatus("Status: Equip Anubis + Target...")

                        -- ============ TUNGGU (PARAMETER SAMA SEPERTI SEBELUMNYA) ============
                        local anubisStartTime = tick()
                        local reachedDuringAnubis = false
                        while anubisLevelingRunning do
                            local pd = getPetByUUID(targetUUID)
                            local lvl = pd and (pd.level or 0) or currentLevel
                            if lvl >= targetLevel then
                                currentLevel = lvl
                                reachedDuringAnubis = true
                                break
                            end
                            local remaining = countFruitsOnTreeWithMutationAbove(tree, 10, favoritedFruitInstance)
                            if remaining <= 0 then break end
                            if (tick() - anubisStartTime) >= ANUBIS_TIMEOUT_SECONDS then break end
                            task.wait(1)
                        end

                        if reachedDuringAnubis then
                            -- ==========================================================
                            -- PERUBAHAN UTAMA:
                            -- Target selesai -> UNEQUIP TARGET SAJA (Anubis tetap on),
                            -- lalu lanjut ke target berikutnya dalam bentuk fast-swap.
                            -- TIDAK ada pengulangan Frog/Cornling untuk target berikutnya.
                            -- ==========================================================
                            debugStep("✅ Level tercapai! Unequip TARGET saja, Tim Anubis tetap terpasang.")
                            sendTargetReachedWebhook(getPetByUUID(targetUUID), targetUUID, targetLevel, tick() - targetStartTime)
                            unequipPetByUUID(targetUUID)
                            break -- lanjut target berikutnya (masuk cabang fast-swap)
                        end

                        -- Belum tercapai: perilaku LAMA -> lepas Anubis + target,
                        -- siklus penuh (Frog/Cornling/dst) diulang untuk target yang sama
                        local anubisAndTarget = {}
                        for _, uuid in ipairs(anubis) do table.insert(anubisAndTarget, uuid) end
                        table.insert(anubisAndTarget, targetUUID)
                        unequipPetList(anubisAndTarget)
                        anubisEquipped = false
                        task.wait(0.5)

                        -- LANGKAH 7
                        local petDataNow = getPetByUUID(targetUUID)
                        currentLevel = petDataNow and (petDataNow.level or 0) or currentLevel
                        anubisSetStatus(string.format("Status: Leveling... %d/%d", currentLevel, targetLevel))

                        if currentLevel >= targetLevel then
                            debugStep("✅ Level tercapai!")
                            sendTargetReachedWebhook(petDataNow, targetUUID, targetLevel, tick() - targetStartTime)
                            unequipPetByUUID(targetUUID)
                            break
                        end
                    end

                    unequipPetByUUID(targetUUID)
                    -- PERUBAHAN: Tim Anubis TIDAK di-unequip di sini.
                    -- Ia tetap terpasang untuk target berikutnya, dan baru dilepas
                    -- setelah SEMUA target selesai (blok setelah for-loop).
                    debugStep("Selesai target #" .. targetIndex)
                end
            end

            -- SEMUA target selesai / dihentikan -> baru lepas Tim Anubis
            if anubisEquipped then
                debugStep("Semua target selesai, unequip Tim Anubis.")
                for _, uuid in ipairs(anubis) do unequipPetByUUID(uuid) end
                anubisEquipped = false
            end
        end)

        if not ok then
            warn("❌ [Anubis] Error: " .. tostring(err))
            -- Safety: pastikan Tim Anubis tidak tertinggal terpasang saat error
            pcall(function()
                for _, uuid in ipairs(anubis) do unequipPetByUUID(uuid) end
            end)
        end

        stopLevelingAnubis()
    end)
end

-- ================= SHARK LOGIC =================
local isAutoSharkRunning = false
local autoSharkCoroutine = nil
local targetQueue = {}
local currentTarget = nil
local currentTumbal = nil
local tumbalIndex = 1
local mutationResult = nil
local notificationConnection = nil
local currentTargetStartTime = nil

local function getCooldownTime(uuid)
    local ok, raw = pcall(function() return DataPetModule.getCooldown(uuid) end)
    if not ok or raw == nil then return 0 end
    if type(raw) == "table" then
        if type(raw.Time) == "number" then return raw.Time end
        if type(raw[1]) == "number" then return raw[1] end
        for _, v in ipairs(raw) do
            if type(v) == "number" then return v end
        end
        return 0
    end
    if type(raw) == "number" then return raw end
    return 0
end

local function getCooldownPassive(uuid)
    local ok, raw = pcall(function() return DataPetModule.getCooldown(uuid) end)
    if not ok or raw == nil then return "" end
    if type(raw) == "table" then
        if type(raw.Passive) == "string" then return raw.Passive end
        if type(raw[2]) == "string" then return raw[2] end
    end
    return ""
end

local function checkTargetMutation(uuid, targetMutation)
    local ok, petData = pcall(function() return DataPetModule.getAllPets()[uuid] end)
    if not ok or not petData then return false end
    local petInfo = petData.PetData or {}
    local okM, currentMut = pcall(function()
        return DataPetModule.getAutoMutationName(petInfo.MutationType or "Normal")
    end)
    return (okM and currentMut) == targetMutation
end

local function getMimicUUID(timSharkUUIDs)
    local equipped = getEquippedPetsUUIDs()
    local equippedMap = {}
    for _, uuid in ipairs(equipped) do equippedMap[uuid] = true end
    for _, uuid in ipairs(timSharkUUIDs) do
        if equippedMap[uuid] and getCooldownPassive(uuid) == "Mimicry" then
            return uuid
        end
    end
    return nil
end

local function getSharkUUID(timSharkUUIDs, mimicUUID)
    local equipped = getEquippedPetsUUIDs()
    local equippedMap = {}
    for _, uuid in ipairs(equipped) do equippedMap[uuid] = true end
    for _, uuid in ipairs(timSharkUUIDs) do
        if equippedMap[uuid] and uuid ~= mimicUUID then return uuid end
    end
    return nil
end

local function setupSharkNotificationListener()
    if notificationConnection then return end
    notificationConnection = NotificationEvent.OnClientEvent:Connect(function(message)
        if type(message) ~= "string" then return end
        if message:find("failed to transfer") then
            mutationResult = "failed"
        elseif message:find("spat its") and message:find("mutation onto") then
            mutationResult = "success"
        end
    end)
end

local function cleanupSharkNotificationListener()
    if notificationConnection then
        notificationConnection:Disconnect()
        notificationConnection = nil
    end
end

local function prepareSharkTargetQueue()
    local targets = normalizeUUIDList(MyConfig:Get("pet_target_uuids") or {})
    local targetMut = MyConfig:Get("target_mutasi") or "Blossoming"
    targetQueue = {}
    for _, uuid in ipairs(targets) do
        if not checkTargetMutation(uuid, targetMut) then
            table.insert(targetQueue, uuid)
        end
    end
    print("Antrian target shark:", #targetQueue)
end

local function getNextTumbal()
    local tumbalList = normalizeUUIDList(MyConfig:Get("pet_tumbal_uuids") or {})
    if #tumbalList == 0 then return nil end
    if tumbalIndex > #tumbalList then tumbalIndex = 1 end
    local selected = tumbalList[tumbalIndex]
    tumbalIndex = tumbalIndex + 1
    return selected
end

local function autoSharkLoop()
    print("Auto Shark loop dimulai")
    runClearGarden()
    task.wait(1)

    prepareSharkTargetQueue()
    if #targetQueue == 0 then
        print("Tidak ada target shark.")
        return
    end

    local timSharkUUIDs = normalizeUUIDList(MyConfig:Get("tim_shark_uuids") or {})
    if #timSharkUUIDs < 2 then
        print("Tim shark minimal 2 pet (mimic + shark).")
        return
    end

    setupSharkNotificationListener()

    for _, uuid in ipairs(timSharkUUIDs) do
        equipPet(uuid)
        task.wait(0.3)
    end
    task.wait(1.5)

    local mimic, cooldownTime = nil, 0
    repeat
        task.wait(0.5)
        mimic = getMimicUUID(timSharkUUIDs)
        if mimic then cooldownTime = getCooldownTime(mimic) end
    until (mimic and cooldownTime == 0) or not isAutoSharkRunning
    if not isAutoSharkRunning then cleanupSharkNotificationListener() return end

    task.wait(0.6)
    mimic = getMimicUUID(timSharkUUIDs)
    if not mimic then cleanupSharkNotificationListener() return end

    currentTarget = table.remove(targetQueue, 1)
    if not currentTarget then cleanupSharkNotificationListener() return end
    currentTargetStartTime = tick()
    currentTumbal = getNextTumbal()
    if not currentTumbal then cleanupSharkNotificationListener() return end

    while isAutoSharkRunning do
        mimic = getMimicUUID(timSharkUUIDs)
        if not mimic then break end

        local shark = getSharkUUID(timSharkUUIDs, mimic)
        if shark then unequipPet(shark) end
        task.wait(0.3)

        equipPet(currentTarget)
        equipPet(currentTumbal)
        task.wait(0.5)

        mutationResult = nil
        local waitCount = 0
        while isAutoSharkRunning and waitCount < 30 do
            if getCooldownTime(mimic) > 0 then break end
            task.wait(0.1)
            waitCount = waitCount + 1
        end
        if not isAutoSharkRunning then break end

        local startWait = tick()
        while isAutoSharkRunning and mutationResult == nil and (tick() - startWait) < 20 do
            task.wait(0.2)
        end
        if mutationResult == nil then mutationResult = "failed" end

        task.wait(1)
        unequipPet(currentTarget)
        unequipPet(currentTumbal)

        local targetMut = MyConfig:Get("target_mutasi") or "Blossoming"
        if mutationResult == "success" then
            sendDiscordWebhook(
                "Auto Shark - Berhasil!",
                "**Pet selesai:** " .. getPetLabelForWebhook(currentTarget) ..
                "\n**Mutasi:** " .. targetMut ..
                "\n**Lama Pengerjaan:** " .. formatDuration(tick() - (currentTargetStartTime or tick())) ..
                "\n**Target tersisa:** " .. #targetQueue,
                3066993
            )
            if #targetQueue > 0 then
                currentTarget = table.remove(targetQueue, 1)
                currentTargetStartTime = tick()
                currentTumbal = getNextTumbal()
                if not currentTumbal then break end
            else
                break
            end
        else
            currentTumbal = getNextTumbal()
            if not currentTumbal then break end
        end

        task.wait(1)
        for _, uuid in ipairs(timSharkUUIDs) do
            if uuid ~= mimic then equipPet(uuid) break end
        end

        task.wait(3)

        repeat
            task.wait(0.5)
            mimic = getMimicUUID(timSharkUUIDs)
            if mimic then cooldownTime = getCooldownTime(mimic) end
        until (mimic and cooldownTime == 0) or not isAutoSharkRunning
        if not isAutoSharkRunning then break end

        task.wait(0.6)
        mimic = getMimicUUID(timSharkUUIDs)
        if not mimic then break end
    end

    cleanupSharkNotificationListener()
    runClearGarden()
end

local function startAutoShark()
    if autoSharkCoroutine then return end
    isAutoSharkRunning = true
    autoSharkCoroutine = coroutine.create(function()
        autoSharkLoop()
        autoSharkCoroutine = nil
    end)
    coroutine.resume(autoSharkCoroutine)
end

local function stopAutoShark()
    isAutoSharkRunning = false
    autoSharkCoroutine = nil
    cleanupSharkNotificationListener()
    runClearGarden()
end

-- ================= LEVELING A LOGIC =================
local function getPetLevel(uuid)
    local ok, petData = pcall(function() return DataPetModule.getAllPets()[uuid] end)
    if not ok or not petData then return nil end
    local info = petData.PetData or {}
    return info.Level or info.Lvl or 0
end

local isAutoLevelingRunning = false
local autoLevelingCoroutine = nil

local function prepareLevelingQueue()
    local targets = normalizeUUIDList(MyConfig:Get("target_leveling_uuids") or {})
    local targetLevel = tonumber(MyConfig:Get("target_level")) or 500
    local queue = {}
    for _, uuid in ipairs(targets) do
        local lvl = getPetLevel(uuid)
        if lvl ~= nil and lvl < targetLevel then
            table.insert(queue, uuid)
        end
    end
    return queue
end

local function autoLevelingLoop()
    print("Auto Leveling loop dimulai")
    runClearGarden()
    task.wait(1)

    local timLevelingUUIDs = normalizeUUIDList(MyConfig:Get("tim_leveling_uuids") or {})
    if #timLevelingUUIDs == 0 then
        print("Tim Leveling kosong.")
        return
    end

    local queue = prepareLevelingQueue()
    if #queue == 0 then
        print("Tidak ada target leveling.")
        return
    end

    for _, uuid in ipairs(timLevelingUUIDs) do
        equipPet(uuid)
        task.wait(0.3)
    end

    while isAutoLevelingRunning and #queue > 0 do
        local targetLevel = tonumber(MyConfig:Get("target_level")) or 500
        local currentTargetUUID = table.remove(queue, 1)
        local lvlCheck = getPetLevel(currentTargetUUID)

        if lvlCheck ~= nil and lvlCheck < targetLevel then
            local levelStartTime = tick()
            equipPet(currentTargetUUID)

            local finishedNormally = false
            while isAutoLevelingRunning do
                task.wait(1)
                local lvl = getPetLevel(currentTargetUUID)
                if lvl == nil then break end
                targetLevel = tonumber(MyConfig:Get("target_level")) or targetLevel
                if lvl >= targetLevel then
                    finishedNormally = true
                    break
                end
            end

            unequipPet(currentTargetUUID)

            if finishedNormally then
                sendDiscordWebhook(
                    "Auto Leveling - Selesai!",
                    "**Pet selesai:** " .. getPetLabelForWebhook(currentTargetUUID) ..
                    "\n**Target Level:** " .. targetLevel ..
                    "\n**Lama Pengerjaan:** " .. formatDuration(tick() - levelStartTime) ..
                    "\n**Target tersisa:** " .. #queue,
                    3066993
                )
            end
        end
        task.wait(0.5)
    end

    runClearGarden()
end

local function startAutoLeveling()
    if autoLevelingCoroutine then return end
    isAutoLevelingRunning = true
    autoLevelingCoroutine = coroutine.create(function()
        autoLevelingLoop()
        autoLevelingCoroutine = nil
    end)
    coroutine.resume(autoLevelingCoroutine)
end

local function stopAutoLeveling()
    isAutoLevelingRunning = false
    autoLevelingCoroutine = nil
    runClearGarden()
end

-- ================= PNP LOGIC =================
local isPNPRunning = false
local pnpOffsets = {}
local pnpProcessing = {}

local function equipPetPNP(uuid, offsetIndex)
    if not PetsService or uuid == "" then return end
    local offset = CFrame.new((offsetIndex or 0) * 3, 0, 0)
    pcall(function()
        PetsService:FireServer("EquipPet", uuid, getEquipCFrame() * offset)
    end)
end

local PNP_MIN_PLACE_DELAY = 0.5

local function pnpProcessPet(uuid, offsetIndex)
    if pnpProcessing[uuid] then return end
    pnpProcessing[uuid] = true

    local pickupDelay = tonumber(MyConfig:Get("pnp_pickup")) or 0.6
    local placeDelay = tonumber(MyConfig:Get("pnp_place")) or 0

    task.wait(pickupDelay)
    unequipPet(uuid)
    task.wait(math.max(placeDelay, PNP_MIN_PLACE_DELAY))
    equipPetPNP(uuid, offsetIndex)

    pnpProcessing[uuid] = false
end

local PNPCooldownEvent = GameEvents and GameEvents:FindFirstChild("PetCooldownsUpdated")
if PNPCooldownEvent then
    PNPCooldownEvent.OnClientEvent:Connect(function(petId, dataArray)
        if not isPNPRunning or not petId then return end
        local uuids = normalizeUUIDList(MyConfig:Get("tim_pnp_uuids") or {})
        local offsetIndex = nil
        for i, uuid in ipairs(uuids) do
            if uuid == petId then
                offsetIndex = pnpOffsets[uuid] or (i - 1)
                break
            end
        end
        if offsetIndex == nil then return end

        local time = nil
        if type(dataArray) == "table" then
            for _, entry in ipairs(dataArray) do
                if type(entry) == "table" and entry.Time then
                    time = entry.Time
                    break
                end
            end
        end
        if time == nil then return end

        if time <= 0.1 and not pnpProcessing[petId] then
            task.spawn(function() pnpProcessPet(petId, offsetIndex) end)
        end
    end)
end

local function startPNP()
    if isPNPRunning then return end
    local uuids = normalizeUUIDList(MyConfig:Get("tim_pnp_uuids") or {})
    if #uuids == 0 then
        print("Tim PNP kosong.")
        return
    end
    isPNPRunning = true
    for i, uuid in ipairs(uuids) do
        pnpOffsets[uuid] = i - 1
        equipPetPNP(uuid, pnpOffsets[uuid])
        task.wait(0.2)
    end
    print("PNP dimulai (" .. #uuids .. " pet).")
end

local function stopPNP()
    isPNPRunning = false
    pnpOffsets = {}
    pnpProcessing = {}
    print("PNP dihentikan.")
end

-- ================= DROPDOWN UPDATE FUNCS =================
local function updateTumbalDropdown(mutation)
    if not Shark_DD_Tumbal then return end
    local ok, tumbalPets = pcall(function()
        return DataPetModule.findPets({ isFavorite = false, mutation = mutation })
    end)
    if not ok or not tumbalPets then return end
    local newOptions = buildDropdownOptions(tumbalPets)

    local savedUUIDs = normalizeUUIDList(MyConfig:Get("pet_tumbal_uuids") or {})
    local validUUIDs = {}
    for _, uuid in ipairs(savedUUIDs) do
        for _, opt in ipairs(newOptions) do
            if opt.Value == uuid then
                table.insert(validUUIDs, uuid)
                break
            end
        end
    end
    safeCall(Shark_DD_Tumbal, "Refresh", newOptions)
    safeCall(Shark_DD_Tumbal, "Select", validUUIDs)
    MyConfig:Set("pet_tumbal_uuids", validUUIDs)
    pcall(function() MyConfig:Save() end)
end

local function updateTargetLevelingDropdown(targetLevel)
    if not AL_DD_Target then return end
    local ok, pets = pcall(function()
        return DataPetModule.findPets({ isFavorite = false, maxLevel = targetLevel })
    end)
    if not ok or not pets then return end
    local newOptions = buildDropdownOptions(pets)

    local savedUUIDs = normalizeUUIDList(MyConfig:Get("target_leveling_uuids") or {})
    local validUUIDs = {}
    for _, uuid in ipairs(savedUUIDs) do
        for _, opt in ipairs(newOptions) do
            if opt.Value == uuid then
                table.insert(validUUIDs, uuid)
                break
            end
        end
    end
    safeCall(AL_DD_Target, "Refresh", newOptions)
    safeCall(AL_DD_Target, "Select", validUUIDs)
    MyConfig:Set("target_leveling_uuids", validUUIDs)
    pcall(function() MyConfig:Save() end)
end

-- ============ APPLY CONFIG FUNCS ============
local function applySharkUIFromConfig()
    pcall(function() MyConfig:Load() end)
    safeCall(Shark_DD_Shark, "Select", MyConfig:Get("tim_shark_uuids") or {})
    safeCall(Shark_DD_Target, "Select", MyConfig:Get("pet_target_uuids") or {})
    local mut = MyConfig:Get("target_mutasi")
    if type(mut) == "string" and mut ~= "" then
        safeCall(Shark_DD_Mutasi, "Select", mut)
        updateTumbalDropdown(mut)
    end
end

local function applyLevelingUIFromConfig()
    safeCall(AL_DD_Tim, "Select", MyConfig:Get("tim_leveling_uuids") or {})
    local tl = tonumber(MyConfig:Get("target_level")) or 500
    safeCall(AL_IN_TargetLevel, "SetValue", tostring(tl))
    updateTargetLevelingDropdown(tl)
end

local function applyPNPUIFromConfig()
    safeCall(PNP_DD_Tim, "Select", MyConfig:Get("tim_pnp_uuids") or {})
end

local anubisLegacyMap = {
    { new = "anubis_tim_anubis",        old = "tim_anubis" },
    { new = "anubis_tim_cornling",      old = "tim_cornling" },
    { new = "anubis_tim_frog",          old = "tim_frog" },
    { new = "anubis_target_leveling",   old = "target_leveling" },
    { new = "anubis_selected_tree",     old = "selected_tree" },
    { new = "anubis_target_level",      old = "target_level" },
    { new = "anubis_mutation_count",    old = "mutation_count" },
    { new = "anubis_collect_threshold", old = "collect_threshold" },
    { new = "anubis_esp_mutation",      old = "esp_mutation" },
    { new = "anubis_auto_buy_fav_tool", old = "auto_buy_fav_tool" },
}

local function applyAnubisUIFromConfig()
    pcall(function() AnubisConfig:Load() end)

    for _, m in ipairs(anubisLegacyMap) do
        if AnubisConfig:Get(m.new) == nil then
            local ov = AnubisConfig:Get(m.old)
            if ov ~= nil then AnubisConfig:Set(m.new, ov) end
        end
    end

    safeCall(Anubis_DD_Anubis,      "Select", normalizeUUIDList(AnubisConfig:Get("anubis_tim_anubis") or {}))
    safeCall(Anubis_DD_Cornling,    "Select", normalizeUUIDList(AnubisConfig:Get("anubis_tim_cornling") or {}))
    safeCall(Anubis_DD_Frog,        "Select", normalizeUUIDList(AnubisConfig:Get("anubis_tim_frog") or {}))
    safeCall(Anubis_DD_Target,      "Select", normalizeUUIDList(AnubisConfig:Get("anubis_target_leveling") or {}))
    safeCall(Anubis_DD_Tree,        "Select", tostring(AnubisConfig:Get("anubis_selected_tree") or ""))
    safeCall(Anubis_IN_TargetLevel, "SetValue", tostring(AnubisConfig:Get("anubis_target_level") or 500))
    safeCall(Anubis_IN_MutCount,    "SetValue", tostring(AnubisConfig:Get("anubis_mutation_count") or 110))
    safeCall(Anubis_IN_Threshold,   "SetValue", tostring(AnubisConfig:Get("anubis_collect_threshold") or 10))

    pcall(function() AnubisConfig:Save() end)
end

-- ============================================================
-- CACHE DATA PET (ANTI BERAT SAAT START)
-- findPets() hanya 2x saat startup; semua dropdown memakai cache.
-- ============================================================
local FavPetsCache, NonFavPetsCache = {}, {}
local FavOptionsCache, NonFavOptionsCache, NormalTargetOptionsCache = {}, {}, {}

local function rebuildPetCaches()
    pcall(function() FavPetsCache = DataPetModule.findPets({ isFavorite = true }) or {} end)
    pcall(function() NonFavPetsCache = DataPetModule.findPets({ isFavorite = false }) or {} end)

    FavOptionsCache = buildDropdownOptions(FavPetsCache)
    NonFavOptionsCache = buildDropdownOptions(NonFavPetsCache)

    local normalPets = {}
    for _, p in ipairs(NonFavPetsCache) do
        if (p.mutation or "Normal") == "Normal" then
            table.insert(normalPets, p)
        end
    end
    NormalTargetOptionsCache = buildDropdownOptions(normalPets)
end
rebuildPetCaches()

-- ============================================================
-- ================== UI CREATION ==================
-- ============================================================

-- ------------- TAB AUTO SHARK -------------
local TabAutoShark = Window:Tab({ Title = "Auto Shark", Icon = "solar:shark-bold" })
local SharkSettings = TabAutoShark:Section({ Title = "Auto Shark Settings" })

Shark_DD_Shark = SharkSettings:Dropdown({
    Title = "Pilih Tim Shark", Multi = true, Search = true, AllowNone = true,
    Values = FavOptionsCache,
    Value = MyConfig:Get("tim_shark_uuids") or {},
    Flag = "tim_shark_uuids",
    Callback = function(selected)
        MyConfig:Set("tim_shark_uuids", normalizeUUIDList(selected))
        pcall(function() MyConfig:Save() end)
    end
})
SharkSettings:Button({ Title = "Clear All Tim Shark", Justify = "Center", Callback = function()
    safeCall(Shark_DD_Shark, "Select", {})
    MyConfig:Set("tim_shark_uuids", {})
    pcall(function() MyConfig:Save() end)
end })
SharkSettings:Space()

Shark_DD_Target = SharkSettings:Dropdown({
    Title = "Pilih Pet Target", Multi = true, Search = true, AllowNone = true,
    Values = NormalTargetOptionsCache,
    Value = MyConfig:Get("pet_target_uuids") or {},
    Flag = "pet_target_uuids",
    Callback = function(selected)
        MyConfig:Set("pet_target_uuids", normalizeUUIDList(selected))
        pcall(function() MyConfig:Save() end)
    end
})
SharkSettings:Button({ Title = "Clear All Pet Target", Justify = "Center", Callback = function()
    safeCall(Shark_DD_Target, "Select", {})
    MyConfig:Set("pet_target_uuids", {})
    pcall(function() MyConfig:Save() end)
end })
SharkSettings:Space()

local mutationList = getMutationList()
local mutOptions = {}
for _, m in ipairs(mutationList) do
    table.insert(mutOptions, { Title = m, Value = m })
end
local defaultMutation = "Blossoming"
if not table.find(mutationList, defaultMutation) then
    defaultMutation = mutationList[1] or "Normal"
end
local savedMutation = MyConfig:Get("target_mutasi")
if savedMutation and table.find(mutationList, savedMutation) then
    defaultMutation = savedMutation
end

Shark_DD_Mutasi = SharkSettings:Dropdown({
    Title = "Pilih Target Mutasi", Multi = false, Search = false,
    Values = mutOptions, Value = defaultMutation,
    Flag = "target_mutasi",
    Callback = function(selected)
        local value = selected
        if type(selected) == "table" and selected.Value then value = selected.Value
        elseif type(selected) == "table" and #selected > 0 then value = selected[1] end
        MyConfig:Set("target_mutasi", value)
        pcall(function() MyConfig:Save() end)
        updateTumbalDropdown(value)
    end
})
SharkSettings:Space()

-- Pet Tumbal (query spesifik, hanya 1x di awal)
local initialTumbalPets = {}
pcall(function()
    initialTumbalPets = DataPetModule.findPets({ isFavorite = false, mutation = defaultMutation }) or {}
end)
local initialTumbalOpts = buildDropdownOptions(initialTumbalPets)
local initialTumbalValid = {}
for _, uuid in ipairs(normalizeUUIDList(MyConfig:Get("pet_tumbal_uuids") or {})) do
    for _, opt in ipairs(initialTumbalOpts) do
        if opt.Value == uuid then table.insert(initialTumbalValid, uuid) break end
    end
end

Shark_DD_Tumbal = SharkSettings:Dropdown({
    Title = "Pilih Pet Tumbal", Multi = true, Search = true, AllowNone = true,
    Values = initialTumbalOpts,
    Value = initialTumbalValid,
    Flag = "pet_tumbal_uuids",
    Callback = function(selected)
        MyConfig:Set("pet_tumbal_uuids", normalizeUUIDList(selected))
        pcall(function() MyConfig:Save() end)
    end
})
SharkSettings:Button({ Title = "Clear All Pet Tumbal", Justify = "Center", Callback = function()
    safeCall(Shark_DD_Tumbal, "Select", {})
    MyConfig:Set("pet_tumbal_uuids", {})
    pcall(function() MyConfig:Save() end)
end })

local SharkActions = TabAutoShark:Section({ Title = "Actions" })
SharkActions:Toggle({
    Title = "Start / Stop",
    Value = MyConfig:Get("is_running") or false,
    Flag = "is_running",
    Callback = function(value)
        MyConfig:Set("is_running", value)
        pcall(function() MyConfig:Save() end)
        if value then startAutoShark() else stopAutoShark() end
    end
})
SharkActions:Space()
SharkActions:Button({ Title = "Refresh Pet Tumbal", Justify = "Center", Callback = function()
    local currentMut = defaultMutation
    pcall(function()
        local v = Shark_DD_Mutasi:GetValue()
        if type(v) == "string" and v ~= "" then currentMut = v end
    end)
    updateTumbalDropdown(currentMut)
end })
SharkActions:Space()
SharkActions:Button({ Title = "Refresh Semua Data Pet", Justify = "Center", Callback = function()
    rebuildPetCaches()
    safeCall(Shark_DD_Shark, "Refresh", FavOptionsCache)
    safeCall(Shark_DD_Target, "Refresh", NormalTargetOptionsCache)
    local newMuts = getMutationList()
    local newMutOpts = {}
    for _, m in ipairs(newMuts) do
        table.insert(newMutOpts, { Title = m, Value = m })
    end
    safeCall(Shark_DD_Mutasi, "Refresh", newMutOpts)
    local currentMut = MyConfig:Get("target_mutasi") or defaultMutation
    if table.find(newMuts, currentMut) then
        safeCall(Shark_DD_Mutasi, "Select", currentMut)
        updateTumbalDropdown(currentMut)
    else
        safeCall(Shark_DD_Mutasi, "Select", newMuts[1] or "Normal")
        updateTumbalDropdown(newMuts[1] or "Normal")
    end
    print("Semua data shark di-refresh!")
end })

local SharkConfigSec = TabAutoShark:Section({ Title = "Config" })
SharkConfigSec:Button({ Title = "Simpan Konfigurasi", Justify = "Center", Callback = function()
    pcall(function() MyConfig:Save() end)
    print("Konfigurasi disimpan!")
end })
SharkConfigSec:Button({ Title = "Muat Konfigurasi", Justify = "Center", Callback = function()
    applySharkUIFromConfig()
    print("Konfigurasi dimuat!")
end })

-- ------------- TAB AUTO LEVELING (SCRIPT A) -------------
local TabAutoLeveling = Window:Tab({ Title = "Auto Leveling", Icon = "solar:graph-up-bold" })
local ALSettings = TabAutoLeveling:Section({ Title = "Auto Leveling Settings" })

AL_DD_Tim = ALSettings:Dropdown({
    Title = "Pilih Tim Leveling", Multi = true, Search = true, AllowNone = true,
    Values = FavOptionsCache,
    Value = MyConfig:Get("tim_leveling_uuids") or {},
    Flag = "tim_leveling_uuids",
    Callback = function(selected)
        MyConfig:Set("tim_leveling_uuids", normalizeUUIDList(selected))
        pcall(function() MyConfig:Save() end)
    end
})
ALSettings:Button({ Title = "Clear All Tim Leveling", Justify = "Center", Callback = function()
    safeCall(AL_DD_Tim, "Select", {})
    MyConfig:Set("tim_leveling_uuids", {})
    pcall(function() MyConfig:Save() end)
end })
ALSettings:Space()

local defaultTargetLevel = tonumber(MyConfig:Get("target_level")) or 500
defaultTargetLevel = math.clamp(math.floor(defaultTargetLevel), 1, 500)
MyConfig:Set("target_level", defaultTargetLevel)

local levelingTargetPets = {}
pcall(function()
    levelingTargetPets = DataPetModule.findPets({ isFavorite = false, maxLevel = defaultTargetLevel }) or {}
end)
AL_DD_Target = ALSettings:Dropdown({
    Title = "Pilih Target Leveling", Multi = true, Search = true, AllowNone = true,
    Values = buildDropdownOptions(levelingTargetPets),
    Value = {},
    Flag = "target_leveling_uuids",
    Callback = function(selected)
        MyConfig:Set("target_leveling_uuids", normalizeUUIDList(selected))
        pcall(function() MyConfig:Save() end)
    end
})
ALSettings:Button({ Title = "Clear All Target Leveling", Justify = "Center", Callback = function()
    safeCall(AL_DD_Target, "Select", {})
    MyConfig:Set("target_leveling_uuids", {})
    pcall(function() MyConfig:Save() end)
end })
ALSettings:Space()

AL_IN_TargetLevel = ALSettings:Input({
    Title = "Target Level",
    Value = tostring(defaultTargetLevel),
    Placeholder = "1-500",
    Flag = "target_level_input",
    Callback = function(value)
        local num = tonumber(value) or 1
        num = math.clamp(math.floor(num), 1, 500)
        MyConfig:Set("target_level", num)
        pcall(function() MyConfig:Save() end)
        updateTargetLevelingDropdown(num)
    end
})

ALSettings:Space()
local ALActions = TabAutoLeveling:Section({ Title = "Actions" })
ALActions:Toggle({
    Title = "Start / Stop",
    Value = MyConfig:Get("is_leveling_running") or false,
    Flag = "is_leveling_running",
    Callback = function(value)
        MyConfig:Set("is_leveling_running", value)
        pcall(function() MyConfig:Save() end)
        if value then startAutoLeveling() else stopAutoLeveling() end
    end
})
ALSettings:Space()
ALSettings:Button({ Title = "Refresh Data Pet", Justify = "Center", Callback = function()
    rebuildPetCaches()
    safeCall(AL_DD_Tim, "Refresh", FavOptionsCache)
    local tl = tonumber(MyConfig:Get("target_level")) or 500
    updateTargetLevelingDropdown(tl)
    print("Data Auto Leveling di-refresh!")
end })

-- ------------- TAB AUTO LEVELING ANUBIS (SCRIPT B) -------------
local TabAnubis = Window:Tab({ Title = "Auto Leveling Anubis", Icon = "solar:skull-bold" })
local ASettings = TabAnubis:Section({ Title = "Anubis Leveling Settings" })

Anubis_AutoToggle = ASettings:Toggle({
    Title = "Auto Leveling (ON = Mulai / OFF = Stop)",
    Value = false,
    Flag = "anubis_auto_leveling",
    Callback = function(state)
        if suppressToggleCallback then return end
        if state then startLevelingAnubis() else stopLevelingAnubis() end
    end
})

ASettings:Toggle({
    Title = "ESP Mutasi",
    Value = AnubisConfig:Get("anubis_esp_mutation") or false,
    Flag = "anubis_esp_mutation",
    Callback = function(state)
        if state then FarmESP.start() else FarmESP.stop() end
    end
})
ASettings:Space()

Anubis_AutoBuyToggle = ASettings:Toggle({
    Title = "Auto Buy Favorite Tool (10x / 5 menit)",
    Value = false,
    Flag = "anubis_auto_buy_fav_tool",
    Callback = function(state)
        if suppressAutoBuyToggle then return end
        if state then startAutoBuyFavoriteTool() else stopAutoBuyFavoriteTool() end
    end
})
ASettings:Space()

Anubis_DD_Tree = ASettings:Dropdown({
    Title = "Pilih Pohon", Multi = false, Search = true, AllowNone = false,
    Values = getTreeList(), Value = "",
    Flag = "anubis_selected_tree",
    Callback = function(selected)
        local val = selected
        if type(selected) == "table" and selected.Value then val = selected.Value
        elseif type(selected) == "table" and #selected > 0 then val = selected[1] end
        currentTree = tostring(val or "")
        print("🌳 Pohon dipilih:", currentTree)
    end
})
ASettings:Space()

Anubis_DD_Frog = ASettings:Dropdown({
    Title = "Pilih Tim Frog / Echo Frog", Multi = true, Search = true, AllowNone = true,
    Values = FavOptionsCache, Value = {},
    Flag = "anubis_tim_frog",
    Callback = function(selected) currentFrog = normalizeUUIDList(selected) end
})
ASettings:Button({ Title = "Clear Tim Frog", Justify = "Center", Callback = function()
    safeCall(Anubis_DD_Frog, "Select", {})
    currentFrog = {}
end })
ASettings:Space()

Anubis_DD_Cornling = ASettings:Dropdown({
    Title = "Pilih Tim Cornling", Multi = true, Search = true, AllowNone = true,
    Values = FavOptionsCache, Value = {},
    Flag = "anubis_tim_cornling",
    Callback = function(selected) currentCornling = normalizeUUIDList(selected) end
})
ASettings:Button({ Title = "Clear Tim Cornling", Justify = "Center", Callback = function()
    safeCall(Anubis_DD_Cornling, "Select", {})
    currentCornling = {}
end })
ASettings:Space()

Anubis_DD_Anubis = ASettings:Dropdown({
    Title = "Pilih Tim Anubis", Multi = true, Search = true, AllowNone = true,
    Values = FavOptionsCache, Value = {},
    Flag = "anubis_tim_anubis",
    Callback = function(selected) currentAnubis = normalizeUUIDList(selected) end
})
ASettings:Button({ Title = "Clear Tim Anubis", Justify = "Center", Callback = function()
    safeCall(Anubis_DD_Anubis, "Select", {})
    currentAnubis = {}
end })
ASettings:Space()

Anubis_DD_Target = ASettings:Dropdown({
    Title = "Pilih Target Leveling", Multi = true, Search = true, AllowNone = true,
    Values = NonFavOptionsCache, Value = {},
    Flag = "anubis_target_leveling",
    Callback = function(selected) currentTargets = normalizeUUIDList(selected) end
})
ASettings:Button({ Title = "Clear Target Leveling", Justify = "Center", Callback = function()
    safeCall(Anubis_DD_Target, "Select", {})
    currentTargets = {}
end })
ASettings:Space()

Anubis_IN_TargetLevel = ASettings:Input({
    Title = "Target Level", Value = tostring(AnubisConfig:Get("anubis_target_level") or 500),
    Placeholder = "1-500",
    Flag = "anubis_target_level",
    Callback = function(value)
        currentTargetLevel = math.clamp(tonumber(value) or 500, 1, 500)
    end
})
ASettings:Space()

Anubis_IN_MutCount = ASettings:Input({
    Title = "Jumlah Mutasi (untuk difavoritkan)",
    Value = tostring(AnubisConfig:Get("anubis_mutation_count") or 110),
    Placeholder = "misal: 110",
    Flag = "anubis_mutation_count",
    Callback = function(value)
        currentMutationCount = math.max(tonumber(value) or 1, 0)
    end
})

Anubis_IN_Threshold = ASettings:Input({
    Title = "Shovel Buah Dengan Mutasi Dibawah",
    Value = tostring(AnubisConfig:Get("anubis_collect_threshold") or 10),
    Placeholder = "misal: 10",
    Flag = "anubis_collect_threshold",
    Callback = function(value)
        currentCollectThreshold = math.max(tonumber(value) or 10, 0)
    end
})

-- vFinal: webhook Anubis otomatis pakai tab Webhook (setting tunggal)
ASettings:Space()
ASettings:Paragraph({
    Title = "Info Webhook",
    Desc = "Notifikasi Anubis memakai URL yang sama dengan tab Webhook (setting tunggal)."
})

Anubis_StatusLabel = TabAnubis:Paragraph({ Title = "Status", Desc = "Status: Stopped" })

ASettings:Button({ Title = "🔄 Refresh Data", Justify = "Center", Callback = function()
    rebuildPetCaches()
    safeCall(Anubis_DD_Anubis, "Refresh", FavOptionsCache)
    safeCall(Anubis_DD_Cornling, "Refresh", FavOptionsCache)
    safeCall(Anubis_DD_Frog, "Refresh", FavOptionsCache)
    safeCall(Anubis_DD_Target, "Refresh", NonFavOptionsCache)
    safeCall(Anubis_DD_Tree, "Refresh", getTreeList())
    print("✅ Data Anubis di-refresh!")
end })

local AConfigSec = TabAnubis:Section({ Title = "Config" })
AConfigSec:Button({ Title = "Simpan Konfigurasi", Justify = "Center", Callback = function()
    AnubisConfig:Set("anubis_tim_anubis", currentAnubis)
    AnubisConfig:Set("anubis_tim_cornling", currentCornling)
    AnubisConfig:Set("anubis_tim_frog", currentFrog)
    AnubisConfig:Set("anubis_target_leveling", currentTargets)
    AnubisConfig:Set("anubis_selected_tree", currentTree)
    AnubisConfig:Set("anubis_target_level", currentTargetLevel)
    AnubisConfig:Set("anubis_mutation_count", currentMutationCount)
    AnubisConfig:Set("anubis_collect_threshold", currentCollectThreshold)
    pcall(function() AnubisConfig:Save() end)
    print("✅ Konfigurasi Anubis disimpan!")
end })
AConfigSec:Button({ Title = "Muat Konfigurasi", Justify = "Center", Callback = function()
    applyAnubisUIFromConfig()
    currentAnubis = normalizeUUIDList(AnubisConfig:Get("anubis_tim_anubis") or {})
    currentCornling = normalizeUUIDList(AnubisConfig:Get("anubis_tim_cornling") or {})
    currentFrog = normalizeUUIDList(AnubisConfig:Get("anubis_tim_frog") or {})
    currentTargets = normalizeUUIDList(AnubisConfig:Get("anubis_target_leveling") or {})
    currentTree = tostring(AnubisConfig:Get("anubis_selected_tree") or "")
    currentTargetLevel = tonumber(AnubisConfig:Get("anubis_target_level")) or 500
    currentMutationCount = tonumber(AnubisConfig:Get("anubis_mutation_count")) or 1
    currentCollectThreshold = tonumber(AnubisConfig:Get("anubis_collect_threshold")) or 10
    print("✅ Konfigurasi Anubis dimuat!")
end })

-- ------------- TAB PNP -------------
local TabPNP = Window:Tab({ Title = "PNP", Icon = "solar:refresh-bold" })
local PNPSettings = TabPNP:Section({ Title = "PNP Settings" })

PNP_DD_Tim = PNPSettings:Dropdown({
    Title = "Pilih Tim PNP", Multi = true, Search = true, AllowNone = true,
    Values = FavOptionsCache,
    Value = MyConfig:Get("tim_pnp_uuids") or {},
    Flag = "tim_pnp_uuids",
    Callback = function(selected)
        MyConfig:Set("tim_pnp_uuids", normalizeUUIDList(selected))
        pcall(function() MyConfig:Save() end)
    end
})
PNPSettings:Button({ Title = "Clear All Tim PNP", Justify = "Center", Callback = function()
    safeCall(PNP_DD_Tim, "Select", {})
    MyConfig:Set("tim_pnp_uuids", {})
    pcall(function() MyConfig:Save() end)
end })
PNPSettings:Space()

PNPSettings:Input({
    Title = "Pickup",
    Value = tostring(tonumber(MyConfig:Get("pnp_pickup")) or 0.6),
    Placeholder = "0.6",
    Flag = "pnp_pickup_input",
    Callback = function(value)
        MyConfig:Set("pnp_pickup", math.max(tonumber(value) or 0.6, 0))
        pcall(function() MyConfig:Save() end)
    end
})
PNPSettings:Space()
PNPSettings:Input({
    Title = "Place",
    Value = tostring(tonumber(MyConfig:Get("pnp_place")) or 0),
    Placeholder = "0",
    Flag = "pnp_place_input",
    Callback = function(value)
        MyConfig:Set("pnp_place", math.max(tonumber(value) or 0, 0))
        pcall(function() MyConfig:Save() end)
    end
})
PNPSettings:Space()
PNPSettings:Button({ Title = "Refresh Data Pet", Justify = "Center", Callback = function()
    rebuildPetCaches()
    safeCall(PNP_DD_Tim, "Refresh", FavOptionsCache)
    print("Data PNP di-refresh!")
end })

local PNPActions = TabPNP:Section({ Title = "Actions" })
PNPActions:Toggle({
    Title = "Start / Stop",
    Value = MyConfig:Get("is_pnp_running") or false,
    Flag = "is_pnp_running",
    Callback = function(value)
        MyConfig:Set("is_pnp_running", value)
        pcall(function() MyConfig:Save() end)
        if value then startPNP() else stopPNP() end
    end
})

-- ------------- TAB WEBHOOK (TUNGGAL - SEMUA FITUR) -------------
local TabWebhook = Window:Tab({ Title = "Webhook", Icon = "solar:link-bold" })
local WebhookSettings = TabWebhook:Section({ Title = "Discord Webhook Settings" })

local inputWebhookURL = WebhookSettings:Input({
    Title = "Url Discord Webhook (dipakai semua fitur)",
    Value = tostring(MyConfig:Get("discord_webhook_url") or ""),
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "discord_webhook_url_input",
    Callback = function(value)
        value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
        MyConfig:Set("discord_webhook_url", value)
        pcall(function() MyConfig:Save() end)
        if value ~= "" then
            print("URL Discord Webhook tersimpan (dipakai semua fitur).")
        else
            print("URL Discord Webhook dikosongkan, akan pakai URL default.")
        end
    end
})
WebhookSettings:Space()
WebhookSettings:Button({ Title = "Kirim Test Webhook", Justify = "Center", Callback = function()
    sendDiscordWebhook("Test Webhook",
        "Ini adalah pesan tes dari Pria Solo HUB.\nJika kamu melihat pesan ini, webhook sudah terhubung.\nURL ini dipakai oleh: Auto Shark, Auto Leveling, Auto Leveling Anubis.",
        3447003)
end })
WebhookSettings:Space()
WebhookSettings:Button({ Title = "Reset ke Webhook Default", Justify = "Center", Callback = function()
    safeCall(inputWebhookURL, "SetValue", "")
    MyConfig:Set("discord_webhook_url", "")
    pcall(function() MyConfig:Save() end)
end })

-- ============================================================
-- ================== STARTUP / RESTORE ==================
-- ============================================================
pcall(applySharkUIFromConfig)
pcall(applyLevelingUIFromConfig)
pcall(applyPNPUIFromConfig)
pcall(applyAnubisUIFromConfig)

pcall(function() MyConfig:Save() end)
pcall(function() AnubisConfig:Save() end)

if MyConfig:Get("is_running") then
    task.delay(1, startAutoShark)
end
if MyConfig:Get("is_leveling_running") then
    task.delay(1, startAutoLeveling)
end
if MyConfig:Get("is_pnp_running") then
    task.delay(1, startPNP)
end

print("✅ Pria Solo HUB (All-in-One Final) siap digunakan!")

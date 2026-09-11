-- ============================================================
-- PRIA SOLO HUB - ALL IN ONE (GABUNGAN SCRIPT A + SCRIPT B)
-- Tab : Auto Shark | Auto Leveling | Auto Leveling Anubis | PNP | Webhook
-- Fitur Auto Leveling DIPISAH:
--   - "Auto Leveling"         = versi Script A (sederhana)
--   - "Auto Leveling Anubis"  = versi Script B (Frog/Cornling/Anubis + ESP + Shovel)
-- ============================================================

-- ============================================================
-- 0. SERVICES (SHARED)
-- ============================================================
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
local PetsServiceEvent = GameEvents and GameEvents:FindFirstChild("PetsService")
local NotificationEvent = GameEvents and GameEvents:FindFirstChild("Notification")
local FavoriteToolRemote = GameEvents and GameEvents:FindFirstChild("FavoriteToolRemote")
local CropsFolder = GameEvents and GameEvents:FindFirstChild("Crops")
local CollectRemoteEvent = CropsFolder and CropsFolder:FindFirstChild("Collect")
local RemoveItemRemote = GameEvents and GameEvents:FindFirstChild("Remove_Item")
local BuyGearStock = GameEvents and GameEvents:FindFirstChild("BuyGearStock")

local PetsService = PetsServiceEvent -- alias dipakai Script A

-- ============================================================
-- 1. LOAD WINDUI (SEKALI)
-- ============================================================
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
            if ok and result then
                return result
            end
        end
        task.wait(1)
    end
    return nil
end

local WindUI = loadWindUI()
if not WindUI then error("❌ Gagal memuat WindUI!") end

-- ============================================================
-- 2. LOAD MODULES (FarmLib + DataPetModule, SEKALI)
-- ============================================================
local FarmLib, DataPetModule

local function loadModules()
    local moduleUrls = {
        FarmLib = "https://raw.githubusercontent.com/okegasscript/PriaSoloAutoAnubis/refs/heads/main/FarmLib.lua",
        -- DataPetModule: pakai repo Anubis (Script B), fallback ke repo V1 (Script A)
        DataPetModule = "https://raw.githubusercontent.com/okegasscript/PriaSoloAutoAnubis/refs/heads/main/DataPetModule.lua",
        DataPetModuleFallback = "https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/DataPetModule.lua",
    }

    for name, url in pairs(moduleUrls) do
        local ok, result = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)
        if ok and result then
            if name == "FarmLib" then FarmLib = result end
            if name == "DataPetModule" and not DataPetModule then DataPetModule = result end
            if name == "DataPetModuleFallback" and not DataPetModule then DataPetModule = result end
        else
            warn("❌ Gagal memuat: " .. name)
        end
    end

    if not DataPetModule then error("❌ DataPetModule gagal dimuat!") end
    print("✅ Modules berhasil dimuat!")
end

loadModules()

-- ============================================================
-- 3. SHARED HELPERS (WEBHOOK, PET, DLL)
-- ============================================================
local MyConfig = nil -- di-set setelah Window dibuat (Config Script A)

-- URL default (fallback) apabila belum di-setting lewat tab "Webhook".
local DISCORD_WEBHOOK_URL_DEFAULT = "https://discord.com/api/webhooks/1513620114975490058/b6VnqOUomMeXuMKdrfKkJrSfOvSh_p98YcwNGEu6NBe6fwi9qvzbKEN8JV-COEbH0Gx_"

-- Ambil fungsi request yang tersedia di executor
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

local function getWebhookURL()
    if MyConfig then
        local ok, url = pcall(function() return MyConfig:Get("discord_webhook_url") end)
        if ok and type(url) == "string" and url ~= "" then
            return url
        end
    end
    return DISCORD_WEBHOOK_URL_DEFAULT
end

-- Format durasi (detik) jadi teks "Xj Ym Zd" / "Ym Zd" / "Zd"
local function formatDuration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 0 then seconds = 0 end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%dj %dm %ds", h, m, s)
    elseif m > 0 then
        return string.format("%dm %ds", m, s)
    else
        return string.format("%ds", s)
    end
end

local function sendDiscordWebhook(title, description, color)
    if not httpRequest then
        warn("Fungsi request/http_request tidak ditemukan di executor ini, notifikasi Discord tidak terkirim.")
        return
    end
    local webhookUrl = getWebhookURL()
    if not webhookUrl or webhookUrl == "" then
        warn("URL Discord Webhook belum di-setting, notifikasi tidak terkirim.")
        return
    end
    color = color or 3066993

    local payload = {
        embeds = { {
            title = title,
            description = description,
            color = color,
        } }
    }

    task.spawn(function()
        local ok, result = pcall(function()
            return httpRequest({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload),
            })
        end)
        if not ok then
            warn("Gagal mengirim webhook Discord:", result)
        end
    end)
end

-- Raw webhook sender (dari Script B) untuk body JSON yang sudah di-encode
local function sendWebhookRaw(webhookUrl, jsonBody)
    if not webhookUrl or webhookUrl == "" then return false, "URL kosong" end

    local ok, err = pcall(function()
        if syn and syn.request then
            syn.request({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonBody,
            })
        elseif http_request then
            http_request({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonBody,
            })
        elseif request then
            request({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonBody,
            })
        else
            HttpService:PostAsync(webhookUrl, jsonBody, Enum.HttpContentType.ApplicationJson)
        end
    end)

    return ok, err
end

-- Cari info lengkap pet dari uuid
local function getPetInfoByUUID(uuid)
    local allPets = DataPetModule.findPets({})
    for _, pet in ipairs(allPets) do
        if pet.uuid == uuid then
            return pet
        end
    end
    return nil
end

local function getDataService()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        local ds = modules:FindFirstChild("DataService")
        if ds then return require(ds) end
    end
    local ds = ReplicatedStorage:FindFirstChild("DataService")
    if ds then return require(ds) end
    if _G.DataService then return _G.DataService end
    error("DataService tidak ditemukan")
end

local DataService = getDataService()

local function getEquippedPetsUUIDs()
    local data = DataService:GetData()
    if not data then return {} end
    local equipped = data.EquippedPets
    if not equipped or type(equipped) ~= "table" then
        if data.PetsData then
            equipped = data.PetsData.EquippedPets
        end
    end
    if not equipped or #equipped == 0 then
        return {}
    end
    local result = {}
    for _, uuid in ipairs(equipped) do
        if type(uuid) == "string" then
            table.insert(result, uuid)
        end
    end
    return result
end

local function getMutationList()
    local mutations = {}
    local allPets = DataPetModule.getAllPets()
    for _, pet in pairs(allPets) do
        local petData = pet.PetData or {}
        local rawMut = petData.MutationType or "Normal"
        local mutName = DataPetModule.getAutoMutationName(rawMut)
        if mutName and mutName ~= "" and not table.find(mutations, mutName) then
            table.insert(mutations, mutName)
        end
    end
    if not table.find(mutations, "Normal") then
        table.insert(mutations, "Normal")
    end
    table.sort(mutations)
    return mutations
end

local function formatPetDisplay(pet)
    local weightStr = string.format("%.2f", pet.weight or 0)
    weightStr = weightStr:gsub("%.", ",")
    return string.format("%s %s %skg lv%d", pet.mutation, pet.name, weightStr, pet.level)
end

local function getPetLabelForWebhook(uuid)
    local pet = getPetInfoByUUID(uuid)
    if pet then
        return formatPetDisplay(pet)
    end
    return uuid
end

local function buildDropdownOptions(petList)
    local options = {}
    local nameCount = {}
    for _, pet in ipairs(petList) do
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

-- Equip / Unequip pet (pakai posisi karakter, dipakai Script A)
local function getEquipCFrame()
    if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return LocalPlayer.Character.HumanoidRootPart.CFrame
    else
        return CFrame.new(0, 0, 0)
    end
end

local function equipPet(uuid)
    if not PetsService or uuid == "" then return end
    local cframe = getEquipCFrame()
    PetsService:FireServer("EquipPet", uuid, cframe)
    print("Equip pet:", uuid)
end

local function unequipPet(uuid)
    if not PetsService or uuid == "" then return end
    PetsService:FireServer("UnequipPet", uuid)
    print("Unequip pet:", uuid)
end

local function runClearGarden()
    print("ClearGarden: Memulai...")
    local equipped = getEquippedPetsUUIDs()
    if not equipped or #equipped == 0 then
        print("ClearGarden: Tidak ada pet terpasang.")
        return
    end
    print("ClearGarden: Menemukan " .. #equipped .. " pet terpasang.")
    for i, uuid in ipairs(equipped) do
        unequipPet(uuid)
        if i < #equipped then task.wait(0.6) end
    end
    print("ClearGarden: Selesai.")
end

-- ============================================================
-- 4. WINDOW & CONFIGS (SATU WINDOW)
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
        Scale = 0.55,
        Color = ColorSequence.new(
            Color3.fromHex("#30FF6A"),
            Color3.fromHex("#e7ff2f")
        ),
    },
})

-- Config Script A (Shark / Leveling A / PNP / Webhook)
MyConfig = Window.ConfigManager:CreateConfig("AutoSharkConfig")
MyConfig:Load()

-- Config Script B (Anubis) - terpisah agar setelan lama tidak bentrok
local AnubisConfig = Window.ConfigManager:CreateConfig("PriaSoloConfig")

-- ============================================================
-- 5. TAB AUTO SHARK (SCRIPT A)
-- ============================================================
local TabAutoShark = Window:Tab({
    Title = "Auto Shark",
    Icon = "solar:shark-bold",
})

local SharkSettingsSection = TabAutoShark:Section({ Title = "Auto Shark Settings" })

-- DROPDOWN 1: Tim Shark
local sharkPets = DataPetModule.findPets({ isFavorite = true })
local sharkOptions = buildDropdownOptions(sharkPets)
local defaultSharkUUIDs = MyConfig:Get("tim_shark_uuids") or {}

local dropdownTimShark = SharkSettingsSection:Dropdown({
    Title = "Pilih Tim Shark",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = sharkOptions,
    Value = defaultSharkUUIDs,
    Flag = "tim_shark_uuids",
    Callback = function(selected)
        local uuids = normalizeUUIDList(selected)
        MyConfig:Set("tim_shark_uuids", uuids)
        MyConfig:Save()
        print("Tim Shark UUIDs tersimpan:", table.concat(uuids, ", "))
    end
})

SharkSettingsSection:Button({
    Title = "Clear All Tim Shark",
    Justify = "Center",
    Callback = function()
        dropdownTimShark:Select({})
        MyConfig:Set("tim_shark_uuids", {})
        MyConfig:Save()
        print("Tim Shark list dikosongkan.")
    end
})

SharkSettingsSection:Space()

-- DROPDOWN 2: Pet Target
local targetPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = "Normal"
})
local targetOptions = buildDropdownOptions(targetPets)
local defaultTargetUUIDs = MyConfig:Get("pet_target_uuids") or {}

local dropdownPetTarget = SharkSettingsSection:Dropdown({
    Title = "Pilih Pet Target",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = targetOptions,
    Value = defaultTargetUUIDs,
    Flag = "pet_target_uuids",
    Callback = function(selected)
        local uuids = normalizeUUIDList(selected)
        MyConfig:Set("pet_target_uuids", uuids)
        MyConfig:Save()
        print("Pet Target UUIDs tersimpan:", table.concat(uuids, ", "))
    end
})

SharkSettingsSection:Button({
    Title = "Clear All Pet Target",
    Justify = "Center",
    Callback = function()
        dropdownPetTarget:Select({})
        MyConfig:Set("pet_target_uuids", {})
        MyConfig:Save()
        print("Pet Target list dikosongkan.")
    end
})

SharkSettingsSection:Space()

-- DROPDOWN 3: Target Mutasi
local function getCooldownTime(uuid)
    local raw = DataPetModule.getCooldown(uuid)
    if raw == nil then return 0 end
    if type(raw) == "table" then
        if raw.Time ~= nil and type(raw.Time) == "number" then return raw.Time end
        if raw[1] ~= nil and type(raw[1]) == "number" then return raw[1] end
        for _, v in ipairs(raw) do
            if type(v) == "number" then return v end
        end
        return 0
    end
    if type(raw) == "number" then return raw end
    return 0
end

local function getCooldownPassive(uuid)
    local raw = DataPetModule.getCooldown(uuid)
    if raw == nil then return "" end
    if type(raw) == "table" then
        if raw.Passive ~= nil and type(raw.Passive) == "string" then return raw.Passive end
        if raw[2] ~= nil and type(raw[2]) == "string" then return raw[2] end
    end
    return ""
end

local function checkTargetMutation(uuid, targetMutation)
    print("Cek mutasi target:", uuid, "target:", targetMutation)
    local allPets = DataPetModule.getAllPets()
    local petData = allPets[uuid]
    if not petData then
        print("Target tidak ditemukan di inventory.")
        return false
    end
    local petInfo = petData.PetData or {}
    local rawMut = petInfo.MutationType or "Normal"
    local currentMut = DataPetModule.getAutoMutationName(rawMut)
    print("Mutasi saat ini:", currentMut)
    return currentMut == targetMutation
end

-- Forward declaration supaya callback dropdown mutasi bisa dipanggil
local updateTumbalDropdown

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

local dropdownTargetMutasi = SharkSettingsSection:Dropdown({
    Title = "Pilih Target Mutasi",
    Multi = false,
    Search = false,
    Values = mutOptions,
    Value = defaultMutation,
    Flag = "target_mutasi",
    Callback = function(selected)
        local value = selected
        if type(selected) == "table" and selected.Value then
            value = selected.Value
        elseif type(selected) == "table" and #selected > 0 then
            value = selected[1]
        end
        MyConfig:Set("target_mutasi", value)
        MyConfig:Save()
        print("Target Mutasi tersimpan:", value)
        if updateTumbalDropdown then
            updateTumbalDropdown(value)
        end
    end
})

SharkSettingsSection:Space()

-- DROPDOWN 4: Pet Tumbal
local tumbalOptions = {}
local tumbalDropdownObject = nil

updateTumbalDropdown = function(mutation)
    print("updateTumbalDropdown dipanggil dengan mutasi:", mutation)
    local tumbalPets = DataPetModule.findPets({
        isFavorite = false,
        mutation = mutation
    })
    print("Jumlah pet tumbal ditemukan:", #tumbalPets)

    local newOptions = buildDropdownOptions(tumbalPets)
    tumbalOptions = newOptions

    local savedUUIDs = MyConfig:Get("pet_tumbal_uuids") or {}
    local validUUIDs = {}
    for _, uuid in ipairs(savedUUIDs) do
        for _, opt in ipairs(newOptions) do
            if opt.Value == uuid then
                table.insert(validUUIDs, uuid)
                break
            end
        end
    end
    if #validUUIDs == 0 and #newOptions > 0 and newOptions[1].Value ~= "" then
        table.insert(validUUIDs, newOptions[1].Value)
    end

    if tumbalDropdownObject then
        if tumbalDropdownObject.Refresh then
            tumbalDropdownObject:Refresh(newOptions)
            tumbalDropdownObject:Select(validUUIDs)
        else
            tumbalDropdownObject.Values = newOptions
            tumbalDropdownObject.Value = validUUIDs
        end
        print("Dropdown tumbal diperbarui dengan", #newOptions, "opsi")
    end
end

-- Inisialisasi tumbal
local initialTumbalPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = defaultMutation
})
tumbalOptions = buildDropdownOptions(initialTumbalPets)

local initialValidUUIDs = {}
local savedTumbalUUIDs = MyConfig:Get("pet_tumbal_uuids") or {}
for _, uuid in ipairs(savedTumbalUUIDs) do
    for _, opt in ipairs(tumbalOptions) do
        if opt.Value == uuid then
            table.insert(initialValidUUIDs, uuid)
            break
        end
    end
end
if #initialValidUUIDs == 0 and #tumbalOptions > 0 and tumbalOptions[1].Value ~= "" then
    table.insert(initialValidUUIDs, tumbalOptions[1].Value)
end

local dropdownPetTumbal = SharkSettingsSection:Dropdown({
    Title = "Pilih Pet Tumbal",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = tumbalOptions,
    Value = initialValidUUIDs,
    Flag = "pet_tumbal_uuids",
    Callback = function(selected)
        local uuids = normalizeUUIDList(selected)
        MyConfig:Set("pet_tumbal_uuids", uuids)
        MyConfig:Save()
        print("Pet Tumbal UUIDs tersimpan:", table.concat(uuids, ", "))
    end
})

SharkSettingsSection:Button({
    Title = "Clear All Pet Tumbal",
    Justify = "Center",
    Callback = function()
        dropdownPetTumbal:Select({})
        MyConfig:Set("pet_tumbal_uuids", {})
        MyConfig:Save()
        print("Pet Tumbal list dikosongkan.")
    end
})

tumbalDropdownObject = dropdownPetTumbal

-- SECTION AKSI
local SharkActionSection = TabAutoShark:Section({ Title = "Actions" })

-- ============================================================
-- DETEKSI MIMIC & SHARK
-- ============================================================
local function getMimicUUID(timSharkUUIDs)
    local equipped = getEquippedPetsUUIDs()
    if #equipped == 0 then return nil end
    local equippedMap = {}
    for _, uuid in ipairs(equipped) do
        equippedMap[uuid] = true
    end

    for _, uuid in ipairs(timSharkUUIDs) do
        if equippedMap[uuid] then
            local passive = getCooldownPassive(uuid)
            if passive == "Mimicry" then
                local cdTime = getCooldownTime(uuid)
                print("Mimic ditemukan:", uuid, "Passive:", passive, "Time:", cdTime)
                return uuid
            end
        end
    end
    return nil
end

local function getSharkUUID(timSharkUUIDs, mimicUUID)
    local equipped = getEquippedPetsUUIDs()
    local equippedMap = {}
    for _, uuid in ipairs(equipped) do
        equippedMap[uuid] = true
    end

    for _, uuid in ipairs(timSharkUUIDs) do
        if equippedMap[uuid] and uuid ~= mimicUUID then
            return uuid
        end
    end
    return nil
end

-- ============================================================
-- LOGIKA AUTO SHARK
-- ============================================================
local autoSharkCoroutine = nil
local isAutoSharkRunning = false
local targetQueue = {}
local currentTarget = nil
local currentTumbal = nil
local tumbalIndex = 1
local mutationResult = nil
local notificationConnection = nil
local currentTargetStartTime = nil

local function setupNotificationListener()
    if notificationConnection then return end
    notificationConnection = NotificationEvent.OnClientEvent:Connect(function(message)
        if type(message) ~= "string" then return end
        print("Notifikasi diterima:", message)
        if message:find("failed to transfer") then
            mutationResult = "failed"
            print("Mutasi GAGAL")
        elseif message:find("spat its") and message:find("mutation onto") then
            mutationResult = "success"
            print("Mutasi BERHASIL")
        end
    end)
end

local function cleanupNotificationListener()
    if notificationConnection then
        notificationConnection:Disconnect()
        notificationConnection = nil
        print("Listener notifikasi dilepas.")
    end
end

local function prepareTargetQueue()
    local targets = MyConfig:Get("pet_target_uuids") or {}
    targets = normalizeUUIDList(targets)
    local targetMut = MyConfig:Get("target_mutasi") or "Blossoming"
    targetQueue = {}
    for _, uuid in ipairs(targets) do
        if not checkTargetMutation(uuid, targetMut) then
            table.insert(targetQueue, uuid)
        else
            print("Target", uuid, "sudah memiliki mutasi", targetMut, "di-skip")
        end
    end
    local safeQueue = {}
    for _, v in ipairs(targetQueue) do
        if type(v) == "string" then
            table.insert(safeQueue, v)
        end
    end
    print("Antrian target:", table.concat(safeQueue, ", "))
end

local function getNextTumbal()
    local tumbalList = MyConfig:Get("pet_tumbal_uuids") or {}
    tumbalList = normalizeUUIDList(tumbalList)
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

    prepareTargetQueue()
    if #targetQueue == 0 then
        print("Tidak ada target yang perlu diproses.")
        return
    end

    local timSharkUUIDs = MyConfig:Get("tim_shark_uuids") or {}
    timSharkUUIDs = normalizeUUIDList(timSharkUUIDs)
    if #timSharkUUIDs < 2 then
        print("Tim shark harus terdiri dari minimal 2 pet (mimic dan shark).")
        return
    end

    setupNotificationListener()

    print("Equip tim shark...")
    for _, uuid in ipairs(timSharkUUIDs) do
        equipPet(uuid)
        task.wait(0.3)
    end
    task.wait(1.5)

    print("Menunggu mimic ready...")
    local mimic = nil
    local cooldownTime = 0
    repeat
        task.wait(0.5)
        mimic = getMimicUUID(timSharkUUIDs)
        if mimic then
            cooldownTime = getCooldownTime(mimic)
            print("Cooldown mimic:", cooldownTime, "Passive:", getCooldownPassive(mimic))
        else
            print("Mimic belum terdeteksi, mungkin belum ter-equip.")
        end
    until (mimic and cooldownTime == 0) or not isAutoSharkRunning
    if not isAutoSharkRunning then
        cleanupNotificationListener()
        return
    end
    print("Mimic siap (cooldown 0).")

    print("Jeda 0.6 detik setelah mimic ready...")
    task.wait(0.6)

    mimic = getMimicUUID(timSharkUUIDs)
    if not mimic then
        print("Mimic hilang setelah jeda, hentikan.")
        cleanupNotificationListener()
        return
    end

    currentTarget = table.remove(targetQueue, 1)
    if not currentTarget then
        print("Tidak ada target.")
        cleanupNotificationListener()
        return
    end
    currentTargetStartTime = tick()
    currentTumbal = getNextTumbal()
    if not currentTumbal then
        print("Tidak ada tumbal.")
        cleanupNotificationListener()
        return
    end

    while isAutoSharkRunning and #targetQueue >= 0 do
        mimic = getMimicUUID(timSharkUUIDs)
        if not mimic then
            print("Mimic hilang, hentikan siklus.")
            break
        end

        -- Step 1: Unequip shark
        local shark = getSharkUUID(timSharkUUIDs, mimic)
        if shark then
            unequipPet(shark)
            print("Shark diunequip.")
        else
            print("Shark tidak ditemukan, mungkin sudah tidak terpasang.")
        end
        task.wait(0.3)

        -- Step 2: Equip target & tumbal
        print("Equip target & tumbal...")
        equipPet(currentTarget)
        equipPet(currentTumbal)
        task.wait(0.5)

        mutationResult = nil

        print("Menunggu mimic mulai aktif...")
        local waitCount = 0
        while isAutoSharkRunning and waitCount < 30 do
            local cd = getCooldownTime(mimic)
            if cd > 0 then
                print("Mimic aktif, cooldown:", cd)
                break
            end
            task.wait(0.1)
            waitCount = waitCount + 1
        end
        if not isAutoSharkRunning then break end

        print("Menunggu notifikasi mutasi... (timeout 20 detik)")
        local startWait = tick()
        while isAutoSharkRunning and mutationResult == nil and (tick() - startWait) < 20 do
            task.wait(0.2)
        end

        if mutationResult == nil then
            print("Timeout 20 detik tanpa notifikasi, anggap GAGAL.")
            mutationResult = "failed"
        end

        print("Jeda 1 detik sebelum unequip target & tumbal...")
        task.wait(1)
        unequipPet(currentTarget)
        unequipPet(currentTumbal)
        print("Unequip target & tumbal setelah notifikasi.")

        -- Step 4: Proses hasil mutasi
        local targetMut = MyConfig:Get("target_mutasi") or "Blossoming"
        local success = (mutationResult == "success")
        if success then
            print("Target", currentTarget, "BERHASIL mendapatkan mutasi", targetMut)

            local finishedLabel = getPetLabelForWebhook(currentTarget)
            local sisaTarget = #targetQueue
            local sisaTumbal = #normalizeUUIDList(MyConfig:Get("pet_tumbal_uuids") or {})
            local durasiStr = formatDuration(tick() - (currentTargetStartTime or tick()))
            sendDiscordWebhook(
                "Auto Shark - Berhasil!",
                "**Pet selesai:** " .. finishedLabel ..
                "\n**Mutasi:** " .. targetMut ..
                "\n**Lama Pengerjaan:** " .. durasiStr ..
                "\n**Target tersisa:** " .. sisaTarget ..
                "\n**Tumbal tersisa:** " .. sisaTumbal,
                3066993
            )

            if #targetQueue > 0 then
                currentTarget = table.remove(targetQueue, 1)
                currentTargetStartTime = tick()
                currentTumbal = getNextTumbal()
                if not currentTumbal then
                    print("Tidak ada tumbal tersisa.")
                    break
                end
            else
                print("Semua target selesai!")
                currentTarget = nil
                currentTumbal = nil
                break
            end
        else
            print("Target", currentTarget, "GAGAL mendapatkan mutasi", targetMut, "akan diulang.")
            currentTumbal = getNextTumbal()
            if not currentTumbal then
                print("Tidak ada tumbal tersisa.")
                break
            end
        end

        -- Step 5: Equip shark kembali
        print("Jeda 1 detik sebelum equip shark kembali...")
        task.wait(1)
        local timShark = MyConfig:Get("tim_shark_uuids") or {}
        timShark = normalizeUUIDList(timShark)
        for _, uuid in ipairs(timShark) do
            if uuid ~= mimic then
                equipPet(uuid)
                break
            end
        end
        print("Shark di-equip kembali.")

        -- Step 5.5: Jeda istirahat minimum
        local MIMIC_MIN_REST = 3
        print("Jeda istirahat minimum " .. MIMIC_MIN_REST .. " detik...")
        task.wait(MIMIC_MIN_REST)

        -- Step 6: Tunggu mimic ready lagi
        print("Menunggu mimic ready untuk cycle berikutnya...")
        repeat
            task.wait(0.5)
            mimic = getMimicUUID(timSharkUUIDs)
            if mimic then
                cooldownTime = getCooldownTime(mimic)
                print("Cooldown mimic:", cooldownTime)
            else
                print("Mimic belum terdeteksi.")
            end
        until (mimic and cooldownTime == 0) or not isAutoSharkRunning
        if not isAutoSharkRunning then break end
        print("Mimic siap, cycle berikutnya dimulai.")

        task.wait(0.6)
        mimic = getMimicUUID(timSharkUUIDs)
        if not mimic then
            print("Mimic hilang setelah jeda, hentikan siklus.")
            break
        end
    end

    print("Auto Shark loop selesai.")
    cleanupNotificationListener()
    runClearGarden()
end

local function startAutoShark()
    if autoSharkCoroutine then return end
    isAutoSharkRunning = true
    autoSharkCoroutine = coroutine.create(function()
        autoSharkLoop()
    end)
    coroutine.resume(autoSharkCoroutine)
end

local function stopAutoShark()
    isAutoSharkRunning = false
    if autoSharkCoroutine then
        autoSharkCoroutine = nil
        print("Auto Shark dihentikan.")
    end
    cleanupNotificationListener()
    runClearGarden()
end

local isRunning = MyConfig:Get("is_running") or false

local toggleStartStop = SharkActionSection:Toggle({
    Title = "Start / Stop",
    Value = isRunning,
    Flag = "is_running",
    Callback = function(value)
        MyConfig:Set("is_running", value)
        MyConfig:Save()
        if value then
            print("Toggle: ON")
            startAutoShark()
        else
            print("Toggle: OFF")
            stopAutoShark()
        end
    end
})

SharkActionSection:Space()

SharkActionSection:Button({
    Title = "Refresh Pet Tumbal",
    Justify = "Center",
    Callback = function()
        local currentMut = dropdownTargetMutasi:GetValue()
        updateTumbalDropdown(currentMut)
        print("Pet tumbal diperbarui manual")
    end
})

SharkActionSection:Space()

SharkActionSection:Button({
    Title = "Refresh Semua Data Pet",
    Justify = "Center",
    Callback = function()
        local newShark = DataPetModule.findPets({ isFavorite = true })
        local newOpts = buildDropdownOptions(newShark)
        dropdownTimShark:Refresh(newOpts)
        local oldUUIDs = MyConfig:Get("tim_shark_uuids") or {}
        local keepUUIDs = {}
        for _, uuid in ipairs(oldUUIDs) do
            for _, opt in ipairs(newOpts) do
                if opt.Value == uuid then
                    table.insert(keepUUIDs, uuid)
                    break
                end
            end
        end
        dropdownTimShark:Select(keepUUIDs)

        local newTarget = DataPetModule.findPets({ isFavorite = false, mutation = "Normal" })
        local newTargetOpts = buildDropdownOptions(newTarget)
        dropdownPetTarget:Refresh(newTargetOpts)
        local oldTargetUUIDs = MyConfig:Get("pet_target_uuids") or {}
        local keepTargetUUIDs = {}
        for _, uuid in ipairs(oldTargetUUIDs) do
            for _, opt in ipairs(newTargetOpts) do
                if opt.Value == uuid then
                    table.insert(keepTargetUUIDs, uuid)
                    break
                end
            end
        end
        dropdownPetTarget:Select(keepTargetUUIDs)

        local newMuts = getMutationList()
        local newMutOpts = {}
        for _, m in ipairs(newMuts) do
            table.insert(newMutOpts, { Title = m, Value = m })
        end
        dropdownTargetMutasi:Refresh(newMutOpts)
        local currentMut = MyConfig:Get("target_mutasi") or defaultMutation
        if table.find(newMuts, currentMut) then
            dropdownTargetMutasi:Select(currentMut)
        else
            dropdownTargetMutasi:Select(newMuts[1] or "Normal")
        end

        updateTumbalDropdown(dropdownTargetMutasi:GetValue())
        print("Semua data pet di-refresh!")
    end
})

-- CONFIG AUTO SHARK
local SharkConfigSection = TabAutoShark:Section({ Title = "Config" })

SharkConfigSection:Button({
    Title = "Simpan Konfigurasi",
    Justify = "Center",
    Callback = function()
        MyConfig:Save()
        print("Konfigurasi disimpan!")
    end
})

SharkConfigSection:Space()

SharkConfigSection:Button({
    Title = "Muat Konfigurasi",
    Justify = "Center",
    Callback = function()
        MyConfig:Load()
        print("Konfigurasi dimuat!")
        dropdownTimShark:Select(MyConfig:Get("tim_shark_uuids") or {})
        dropdownPetTarget:Select(MyConfig:Get("pet_target_uuids") or {})
        local loadedMut = MyConfig:Get("target_mutasi") or defaultMutation
        dropdownTargetMutasi:Select(loadedMut)
        updateTumbalDropdown(loadedMut)
        toggleStartStop:Set(MyConfig:Get("is_running") or false)
        print("Semua nilai dimuat dari config!")
    end
})

-- ============================================================
-- 6. TAB AUTO LEVELING (SCRIPT A - VERSI SEDERHANA)
-- ============================================================
local TabAutoLeveling = Window:Tab({
    Title = "Auto Leveling",
    Icon = "solar:graph-up-bold",
})

local LevelingSettingsSection = TabAutoLeveling:Section({ Title = "Auto Leveling Settings" })

-- DROPDOWN: Tim Leveling (isFavorite = true)
local levelingTeamPets = DataPetModule.findPets({ isFavorite = true })
local levelingTeamOptions = buildDropdownOptions(levelingTeamPets)
local defaultLevelingTeamUUIDs = MyConfig:Get("tim_leveling_uuids") or {}

local dropdownTimLeveling = LevelingSettingsSection:Dropdown({
    Title = "Pilih Tim Leveling",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = levelingTeamOptions,
    Value = defaultLevelingTeamUUIDs,
    Flag = "tim_leveling_uuids",
    Callback = function(selected)
        local uuids = normalizeUUIDList(selected)
        MyConfig:Set("tim_leveling_uuids", uuids)
        MyConfig:Save()
        print("Tim Leveling UUIDs tersimpan:", table.concat(uuids, ", "))
    end
})

LevelingSettingsSection:Button({
    Title = "Clear All Tim Leveling",
    Justify = "Center",
    Callback = function()
        dropdownTimLeveling:Select({})
        MyConfig:Set("tim_leveling_uuids", {})
        MyConfig:Save()
        print("Tim Leveling list dikosongkan.")
    end
})

LevelingSettingsSection:Space()

-- INPUT: Target Level (1-500)
local defaultTargetLevel = tonumber(MyConfig:Get("target_level")) or 500
if defaultTargetLevel < 1 then defaultTargetLevel = 1 end
if defaultTargetLevel > 500 then defaultTargetLevel = 500 end
MyConfig:Set("target_level", defaultTargetLevel)

-- Forward declaration
local updateTargetLevelingDropdown

-- DROPDOWN: Target Leveling
local levelingTargetPets = DataPetModule.findPets({ isFavorite = false, maxLevel = defaultTargetLevel })
local levelingTargetOptions = buildDropdownOptions(levelingTargetPets)
local defaultLevelingTargetUUIDs = MyConfig:Get("target_leveling_uuids") or {}
do
    local validDefaults = {}
    for _, uuid in ipairs(defaultLevelingTargetUUIDs) do
        for _, opt in ipairs(levelingTargetOptions) do
            if opt.Value == uuid then
                table.insert(validDefaults, uuid)
                break
            end
        end
    end
    defaultLevelingTargetUUIDs = validDefaults
    MyConfig:Set("target_leveling_uuids", defaultLevelingTargetUUIDs)
end

local dropdownTargetLeveling = LevelingSettingsSection:Dropdown({
    Title = "Pilih Target Leveling",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = levelingTargetOptions,
    Value = defaultLevelingTargetUUIDs,
    Flag = "target_leveling_uuids",
    Callback = function(selected)
        local uuids = normalizeUUIDList(selected)
        MyConfig:Set("target_leveling_uuids", uuids)
        MyConfig:Save()
        print("Target Leveling UUIDs tersimpan:", table.concat(uuids, ", "))
    end
})

LevelingSettingsSection:Button({
    Title = "Clear All Target Leveling",
    Justify = "Center",
    Callback = function()
        dropdownTargetLeveling:Select({})
        MyConfig:Set("target_leveling_uuids", {})
        MyConfig:Save()
        print("Target Leveling list dikosongkan.")
    end
})

updateTargetLevelingDropdown = function(targetLevel)
    local pets = DataPetModule.findPets({ isFavorite = false, maxLevel = targetLevel })
    local newOptions = buildDropdownOptions(pets)

    local savedUUIDs = MyConfig:Get("target_leveling_uuids") or {}
    local validUUIDs = {}
    for _, uuid in ipairs(savedUUIDs) do
        for _, opt in ipairs(newOptions) do
            if opt.Value == uuid then
                table.insert(validUUIDs, uuid)
                break
            end
        end
    end

    if dropdownTargetLeveling.Refresh then
        dropdownTargetLeveling:Refresh(newOptions)
    end
    dropdownTargetLeveling:Select(validUUIDs)
    MyConfig:Set("target_leveling_uuids", validUUIDs)
    MyConfig:Save()
    print("Dropdown Target Leveling diperbarui, pet dengan level > " .. targetLevel .. " dihapus dari list.")
end

LevelingSettingsSection:Space()

local inputTargetLevel = LevelingSettingsSection:Input({
    Title = "Target Level",
    Value = tostring(defaultTargetLevel),
    Placeholder = "1-500",
    Flag = "target_level_input",
    Callback = function(value)
        local num = tonumber(value)
        if not num then num = 1 end
        num = math.floor(num)
        if num < 1 then num = 1 end
        if num > 500 then num = 500 end
        MyConfig:Set("target_level", num)
        MyConfig:Save()
        print("Target Level tersimpan:", num)
        updateTargetLevelingDropdown(num)
    end
})

LevelingSettingsSection:Space()

local LevelingActionSection = TabAutoLeveling:Section({ Title = "Actions" })

-- ============================================================
-- LOGIKA AUTO LEVELING (SCRIPT A)
-- ============================================================
local function getPetLevel(uuid)
    local allPets = DataPetModule.getAllPets()
    local petData = allPets[uuid]
    if not petData then return nil end
    local info = petData.PetData or {}
    return info.Level or info.Lvl or 0
end

local isAutoLevelingRunning = false
local autoLevelingCoroutine = nil

local function prepareLevelingQueue()
    local targets = MyConfig:Get("target_leveling_uuids") or {}
    targets = normalizeUUIDList(targets)
    local targetLevel = tonumber(MyConfig:Get("target_level")) or 500
    local queue = {}
    for _, uuid in ipairs(targets) do
        local lvl = getPetLevel(uuid)
        if lvl == nil then
            print("Target leveling", uuid, "tidak ditemukan, di-skip")
        elseif lvl >= targetLevel then
            print("Target leveling", uuid, "sudah level " .. lvl .. " (>= target " .. targetLevel .. "), di-skip")
        else
            table.insert(queue, uuid)
        end
    end
    return queue
end

local function autoLevelingLoop()
    print("Auto Leveling loop dimulai")
    runClearGarden()
    task.wait(1)

    local timLevelingUUIDs = MyConfig:Get("tim_leveling_uuids") or {}
    timLevelingUUIDs = normalizeUUIDList(timLevelingUUIDs)
    if #timLevelingUUIDs == 0 then
        print("Tim Leveling kosong, tidak bisa memulai.")
        return
    end

    local queue = prepareLevelingQueue()
    if #queue == 0 then
        print("Tidak ada target leveling yang perlu diproses.")
        return
    end

    print("Equip tim leveling...")
    for _, uuid in ipairs(timLevelingUUIDs) do
        equipPet(uuid)
        task.wait(0.3)
    end

    while isAutoLevelingRunning and #queue > 0 do
        local targetLevel = tonumber(MyConfig:Get("target_level")) or 500
        local currentTargetUUID = table.remove(queue, 1)
        local lvlCheck = getPetLevel(currentTargetUUID)

        if lvlCheck == nil then
            print("Target", currentTargetUUID, "tidak ditemukan, di-skip.")
        elseif lvlCheck >= targetLevel then
            print("Target", currentTargetUUID, "sudah level " .. lvlCheck .. " (>= target " .. targetLevel .. "), di-skip.")
        else
            print("Equip target leveling:", currentTargetUUID, "(level saat ini:", lvlCheck, ")")
            local levelStartTime = tick()
            equipPet(currentTargetUUID)

            local finishedNormally = false
            while isAutoLevelingRunning do
                task.wait(1)
                local lvl = getPetLevel(currentTargetUUID)
                if lvl == nil then
                    print("Target", currentTargetUUID, "hilang dari inventory, hentikan pemantauan.")
                    break
                end
                targetLevel = tonumber(MyConfig:Get("target_level")) or targetLevel
                if lvl >= targetLevel then
                    print("Target", currentTargetUUID, "sudah mencapai level " .. lvl .. " (>= target " .. targetLevel .. ")")
                    finishedNormally = true
                    break
                end
            end

            unequipPet(currentTargetUUID)
            print("Unequip target leveling:", currentTargetUUID)

            if finishedNormally then
                local finishedLabel = getPetLabelForWebhook(currentTargetUUID)
                local durasiStr = formatDuration(tick() - levelStartTime)
                sendDiscordWebhook(
                    "Auto Leveling - Selesai!",
                    "**Pet selesai:** " .. finishedLabel ..
                    "\n**Target Level:** " .. targetLevel ..
                    "\n**Lama Pengerjaan:** " .. durasiStr ..
                    "\n**Target tersisa:** " .. #queue,
                    3066993
                )
            end
        end

        task.wait(0.5)
    end

    print("Auto Leveling loop selesai.")
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

local isLevelingRunningSaved = MyConfig:Get("is_leveling_running") or false

local toggleLevelingStartStop = LevelingActionSection:Toggle({
    Title = "Start / Stop",
    Value = isLevelingRunningSaved,
    Flag = "is_leveling_running",
    Callback = function(value)
        MyConfig:Set("is_leveling_running", value)
        MyConfig:Save()
        if value then
            print("Auto Leveling: ON")
            startAutoLeveling()
        else
            print("Auto Leveling: OFF")
            stopAutoLeveling()
        end
    end
})

-- ============================================================
-- 7. TAB AUTO LEVELING ANUBIS (SCRIPT B - v24)
-- ============================================================
local TabAnubis = Window:Tab({
    Title = "Auto Leveling Anubis",
    Icon = "solar:skull-bold",
})

-- ------------------------------------------------------------
-- 7A. FARMESP (EMBEDDED)
-- ------------------------------------------------------------
local FarmESP = {}

local officialMutations = {}
local function loadMutations()
    local Modules = ReplicatedStorage:FindFirstChild("Modules")
    if Modules then
        local handler = Modules:FindFirstChild("MutationHandler")
        if handler then
            local ok, h = pcall(require, handler)
            if ok and h and h.GetMutations then
                for name, _ in pairs(h:GetMutations()) do
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
    for _, name in ipairs(hardcoded) do
        officialMutations[name] = true
    end
end
loadMutations()

local espFolder = nil
local espObjects = {}
local espConnection = nil

local function getPlantsPhysical()
    local p = Workspace:FindFirstChild("Farm")
    if p then p = p:FindFirstChild("Farm") end
    if p then p = p:FindFirstChild("Important") end
    if p then p = p:FindFirstChild("Plants_Physical") end
    return p
end

local function collectMutations(obj)
    local muts = {}
    for k, v in pairs(obj:GetAttributes()) do
        if v == true and officialMutations[k] then
            muts[k] = true
        end
    end
    return muts
end

local function scanAllPlants()
    local plantsPhysical = getPlantsPhysical()
    if not plantsPhysical then
        plantsPhysical = Workspace:FindFirstChild("Farm")
        if plantsPhysical then plantsPhysical = plantsPhysical:FindFirstChild("Farm") end
        if plantsPhysical then plantsPhysical = plantsPhysical:FindFirstChild("Important") end
        if plantsPhysical then plantsPhysical = plantsPhysical:FindFirstChild("Plants_Physical") end
        if not plantsPhysical then
            warn("❌ Plants_Physical tidak ditemukan.")
            return {}
        end
    end

    local plantList = {}
    local index = 0

    for _, plantFolder in ipairs(plantsPhysical:GetChildren()) do
        local fruitsFolder = plantFolder:FindFirstChild("Fruits") or plantFolder:FindFirstChild("Fruit_Spawn")
        if fruitsFolder then
            for _, fruit in ipairs(fruitsFolder:GetChildren()) do
                if fruit:IsA("BasePart") or fruit:IsA("Model") or fruit:IsA("Folder") then
                    index = index + 1
                    local muts = collectMutations(fruit)
                    for _, desc in ipairs(fruit:GetDescendants()) do
                        if desc:IsA("BasePart") or desc:IsA("Model") then
                            for k, v in pairs(desc:GetAttributes()) do
                                if v == true and officialMutations[k] then
                                    muts[k] = true
                                end
                            end
                        end
                    end
                    local mutCount = 0
                    for _ in pairs(muts) do mutCount = mutCount + 1 end

                    local part = nil
                    if fruit:IsA("BasePart") then
                        part = fruit
                    elseif fruit:IsA("Model") and fruit.PrimaryPart then
                        part = fruit.PrimaryPart
                    else
                        for _, desc in ipairs(fruit:GetDescendants()) do
                            if desc:IsA("BasePart") then
                                part = desc
                                break
                            end
                        end
                    end
                    local position = part and part.Position or fruit:GetPivot().Position
                    local uuid = fruit:GetAttribute("OBJECT_UUID") or fruit:GetAttribute("UUID") or plantFolder.Name .. "_fruit_" .. index

                    table.insert(plantList, {
                        name = plantFolder.Name .. " #" .. index,
                        mutCount = mutCount,
                        position = position,
                        uuid = uuid,
                        instance = fruit,
                        plantName = plantFolder.Name,
                    })
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
                local muts = collectMutations(target)
                for _, desc in ipairs(target:GetDescendants()) do
                    if desc:IsA("BasePart") or desc:IsA("Model") then
                        for k, v in pairs(desc:GetAttributes()) do
                            if v == true and officialMutations[k] then
                                muts[k] = true
                            end
                        end
                    end
                end
                local mutCount = 0
                for _ in pairs(muts) do mutCount = mutCount + 1 end

                local part = nil
                if target:IsA("BasePart") then
                    part = target
                elseif target:IsA("Model") and target.PrimaryPart then
                    part = target.PrimaryPart
                else
                    for _, desc in ipairs(target:GetDescendants()) do
                        if desc:IsA("BasePart") then
                            part = desc
                            break
                        end
                    end
                end
                local position = part and part.Position or target:GetPivot().Position
                local uuid = target:GetAttribute("OBJECT_UUID") or target:GetAttribute("UUID") or plantFolder.Name .. "_" .. index

                table.insert(plantList, {
                    name = plantFolder.Name,
                    mutCount = mutCount,
                    position = position,
                    uuid = uuid,
                    instance = target,
                    plantName = plantFolder.Name,
                })
            end
        end
    end

    if #plantList == 0 then
        print("⚠️ scanAllPlants: tidak ada tanaman terdeteksi.")
    else
        print("🔍 ESP: Ditemukan " .. #plantList .. " target tanaman.")
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

    return {
        part = part,
        bill = bill,
        label = label,
        uuid = data.uuid
    }
end

local function updateESP()
    local plants = scanAllPlants()
    local current = {}
    for _, p in ipairs(plants) do
        current[p.uuid] = p
    end

    for uuid, obj in pairs(espObjects) do
        if not current[uuid] then
            obj.part:Destroy()
            obj.bill:Destroy()
            espObjects[uuid] = nil
        end
    end

    for uuid, data in pairs(current) do
        local obj = espObjects[uuid]
        if not obj then
            obj = createESP(data)
            espObjects[uuid] = obj
        else
            obj.part.Position = data.position
            obj.label.Text = string.format("%s: %d", data.name, data.mutCount)
        end
    end
end

function FarmESP.start()
    if espConnection then return end
    updateESP()
    espConnection = RunService.Heartbeat:Connect(function()
        if tick() % 2 < 0.05 then
            pcall(updateESP)
        end
    end)
    print("✅ FarmESP started.")
end

function FarmESP.stop()
    if espConnection then
        espConnection:Disconnect()
        espConnection = nil
    end
    for _, obj in pairs(espObjects) do
        obj.part:Destroy()
        obj.bill:Destroy()
    end
    espObjects = {}
    if espFolder then
        espFolder:Destroy()
        espFolder = nil
    end
    print("✅ FarmESP stopped.")
end

-- ------------------------------------------------------------
-- 7B. FORWARD DECLARATIONS + STATE ANUBIS
-- ------------------------------------------------------------
local scanFruitsOnTree
local findFruitOnTreeByExactMutation
local countFruitsOnTreeWithMutationAbove

local function debugStep(msg)
    print("🐾 [AutoLevelingAnubis] " .. msg)
end

local anubisLevelingRunning = false

local function getPetList(isFavorite)
    local pets = DataPetModule.findPets({ isFavorite = isFavorite })
    local options = {}
    for _, pet in ipairs(pets) do
        local name = pet.name or "Unknown"
        local mutation = pet.mutation or "Normal"
        local level = pet.level or 0
        local weight = pet.weight or 0
        local display = string.format("%s %s %.0fkg lv%d", mutation, name, weight, level)
        table.insert(options, {
            Title = display,
            Value = pet.uuid
        })
    end
    return options
end

local function getTreeList()
    local plantsPhysical = getPlantsPhysical()
    if not plantsPhysical then return {} end
    local options = {}
    for _, folder in ipairs(plantsPhysical:GetChildren()) do
        table.insert(options, {
            Title = folder.Name,
            Value = folder.Name
        })
    end
    return options
end

local function getPetByUUID(uuid)
    if not uuid then return nil end
    local ok, inv = pcall(DataPetModule.getAllPets)
    if not ok or not inv then return nil end
    local pet = inv[uuid]
    if not pet then return nil end

    local petData = pet.PetData or {}
    local rawMut = petData.MutationType or "Normal"
    local mutation = DataPetModule.getAutoMutationName(rawMut)
    local level = petData.Level or petData.Lvl or 0
    local baseWeight = petData.Weight or petData.BaseWeight or 0
    local currentWeight = baseWeight
    if DataPetModule.calculateWeightAtLevel then
        local okW, w = pcall(DataPetModule.calculateWeightAtLevel, baseWeight, level)
        if okW and w then currentWeight = w end
    end

    return {
        uuid = uuid,
        pet = pet,
        petData = petData,
        name = pet.PetType or petData.PetType or petData.Name or "Unknown",
        mutation = mutation,
        level = level,
        baseWeight = baseWeight,
        weight = currentWeight,
        isFavorite = petData.IsFavorite or false,
        passive = petData.Passive or "",
    }
end

-- ------------------------------------------------------------
-- 7C. UI ANUBIS
-- ------------------------------------------------------------
local AnubisSection = TabAnubis:Section({ Title = "Anubis Leveling Settings" })

local suppressToggleCallback = false
local suppressAutoBuyToggle = false

local currentAnubis = {}
local currentCornling = {}
local currentFrog = {}
local currentTargets = {}
local currentTree = ""
local currentTargetLevel = 500
local currentMutationCount = 1
local currentCollectThreshold = 10
local currentESPEnabled = false
local currentWebhookUrl = ""

local autoToggle = AnubisSection:Toggle({
    Title = "Auto Leveling (ON = Mulai / OFF = Stop)",
    Value = false,
    Flag = "anubis_auto_leveling",
    Callback = function(state)
        if suppressToggleCallback then return end
        print("🟢 [Toggle] Auto Leveling Anubis ->", state and "ON" or "OFF")
        if state then
            if startLevelingAnubis then startLevelingAnubis() end
        else
            if stopLevelingAnubis then stopLevelingAnubis() end
        end
    end
})

local espToggle = AnubisSection:Toggle({
    Title = "ESP Mutasi",
    Value = false,
    Flag = "anubis_esp_mutation",
    Callback = function(state)
        currentESPEnabled = state
        if state then
            if FarmESP and FarmESP.start then
                FarmESP.start()
            else
                warn("⚠️ FarmESP.start tidak tersedia")
            end
        else
            if FarmESP and FarmESP.stop then
                FarmESP.stop()
            else
                warn("⚠️ FarmESP.stop tidak tersedia")
            end
        end
    end
})

AnubisSection:Space()

local autoBuyToggle = AnubisSection:Toggle({
    Title = "Auto Buy Favorite Tool (10x / 5 menit)",
    Value = false,
    Flag = "anubis_auto_buy_fav_tool",
    Callback = function(state)
        if suppressAutoBuyToggle then return end
        print("🛒 Auto Buy Favorite Tool:", state and "ON" or "OFF")
        if state then
            startAutoBuyFavoriteTool()
        else
            stopAutoBuyFavoriteTool()
        end
    end
})

AnubisSection:Space()

local treeDropdown = AnubisSection:Dropdown({
    Title = "Pilih Pohon",
    Multi = false,
    Search = true,
    AllowNone = false,
    Values = getTreeList(),
    Value = "",
    Flag = "anubis_selected_tree",
    Callback = function(selected)
        local val = selected
        if type(selected) == "table" and selected.Value then
            val = selected.Value
        elseif type(selected) == "string" then
            val = selected
        end
        currentTree = val
        print("🌳 Pohon dipilih:", currentTree)
    end
})

AnubisSection:Space()

local frogDropdown = AnubisSection:Dropdown({
    Title = "Pilih Tim Frog / Echo Frog",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = getPetList(true),
    Value = {},
    Flag = "anubis_tim_frog",
    Callback = function(selected)
        currentFrog = normalizeUUIDList(selected)
    end
})

AnubisSection:Button({
    Title = "Clear Tim Frog",
    Justify = "Center",
    Callback = function()
        frogDropdown:Select({})
    end
})

AnubisSection:Space()

local cornlingDropdown = AnubisSection:Dropdown({
    Title = "Pilih Tim Cornling",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = getPetList(true),
    Value = {},
    Flag = "anubis_tim_cornling",
    Callback = function(selected)
        currentCornling = normalizeUUIDList(selected)
    end
})

AnubisSection:Button({
    Title = "Clear Tim Cornling",
    Justify = "Center",
    Callback = function()
        cornlingDropdown:Select({})
    end
})

AnubisSection:Space()

local anubisDropdown = AnubisSection:Dropdown({
    Title = "Pilih Tim Anubis",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = getPetList(true),
    Value = {},
    Flag = "anubis_tim_anubis",
    Callback = function(selected)
        currentAnubis = normalizeUUIDList(selected)
    end
})

AnubisSection:Button({
    Title = "Clear Tim Anubis",
    Justify = "Center",
    Callback = function()
        anubisDropdown:Select({})
    end
})

AnubisSection:Space()

local targetLevelingDropdown = AnubisSection:Dropdown({
    Title = "Pilih Target Leveling",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = getPetList(false),
    Value = {},
    Flag = "anubis_target_leveling",
    Callback = function(selected)
        currentTargets = normalizeUUIDList(selected)
    end
})

AnubisSection:Button({
    Title = "Clear Target Leveling",
    Justify = "Center",
    Callback = function()
        targetLevelingDropdown:Select({})
    end
})

AnubisSection:Space()

local targetLevelInput = AnubisSection:Input({
    Title = "Target Level",
    Value = "500",
    Placeholder = "1-500",
    Flag = "anubis_target_level",
    Callback = function(value)
        local num = tonumber(value) or 500
        if num < 1 then num = 1 end
        if num > 500 then num = 500 end
        currentTargetLevel = num
    end
})

AnubisSection:Space()

local mutationCountInput = AnubisSection:Input({
    Title = "Jumlah Mutasi (untuk difavoritkan)",
    Value = "110",
    Placeholder = "misal: 110",
    Flag = "anubis_mutation_count",
    Callback = function(value)
        local num = tonumber(value) or 1
        if num < 0 then num = 0 end
        currentMutationCount = num
    end
})

local collectThresholdInput = AnubisSection:Input({
    Title = "Shovel Buah Dengan Mutasi Dibawah",
    Value = "10",
    Placeholder = "misal: 10",
    Flag = "anubis_collect_threshold",
    Callback = function(value)
        local num = tonumber(value) or 10
        if num < 0 then num = 0 end
        currentCollectThreshold = num
    end
})

AnubisSection:Space()

local webhookInput = AnubisSection:Input({
    Title = "Webhook Anubis (opsional)",
    Value = "",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "anubis_webhook_url",
    Callback = function(value)
        currentWebhookUrl = tostring(value or "")
    end
})

local anubisStatusParagraph = TabAnubis:Paragraph({
    Title = "Status",
    Desc = "Status: Stopped",
})

-- ------------------------------------------------------------
-- 7D. TOOLS & HELPER ANUBIS
-- ------------------------------------------------------------
local function findToolInBackpackByPrefix(namePrefix)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:sub(1, #namePrefix) == namePrefix then
            return item
        end
    end
    return nil
end

local function findToolInCharacterByPrefix(namePrefix)
    local character = LocalPlayer.Character
    if not character then return nil end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") and item.Name:sub(1, #namePrefix) == namePrefix then
            return item
        end
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
    if not humanoid then
        warn("⚠️ Humanoid tidak ditemukan di Character.")
        return nil
    end
    humanoid:EquipTool(tool)
    task.wait(0.2)
    return findToolInCharacterByPrefix(namePrefix) or tool
end

-- 8A. AUTO BUY FAVORITE TOOL
local autoBuyRunning = false

function startAutoBuyFavoriteTool()
    if autoBuyRunning then return end
    if not BuyGearStock then
        warn("⚠️ BuyGearStock remote tidak ditemukan.")
        return
    end

    autoBuyRunning = true
    task.spawn(function()
        local totalBuy = 10
        local totalDuration = 300
        local interval = totalDuration / totalBuy

        print("🛒 Auto Buy Favorite Tool dimulai: 10x dalam 5 menit")
        for i = 1, totalBuy do
            if not autoBuyRunning then break end
            local ok, err = pcall(function()
                BuyGearStock:FireServer("Favorite Tool")
            end)
            if ok then
                print("🛒 Pembelian Favorite Tool ke-" .. i .. " berhasil")
            else
                warn("⚠️ Gagal membeli Favorite Tool ke-" .. i .. ": " .. tostring(err))
            end
            if i < totalBuy then
                task.wait(interval)
            end
        end
        print("✅ Auto Buy Favorite Tool selesai (10x)")
        autoBuyRunning = false
        suppressAutoBuyToggle = true
        autoBuyToggle:Set(false)
        suppressAutoBuyToggle = false
    end)
end

function stopAutoBuyFavoriteTool()
    autoBuyRunning = false
    print("⏹️ Auto Buy Favorite Tool dihentikan.")
end

-- 8B. LEPAS FAVORITE TOOL
local function equipNonFavoriteTool()
    local humanoid = getHumanoid()
    if not humanoid then return false end

    local character = LocalPlayer.Character
    if not character then return false end

    local currentTool = nil
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") then
            currentTool = item
            break
        end
    end

    if not currentTool then return true end
    if not string.find(currentTool.Name, "Favorite Tool") then return true end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return false end

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and not string.find(tool.Name, "Favorite Tool") then
            humanoid:EquipTool(tool)
            task.wait(0.3)
            debugStep("Langkah 5: lepas Favorite Tool, equip: " .. tool.Name)
            return true
        end
    end

    if currentTool then
        currentTool.Parent = backpack
        task.wait(0.3)
        debugStep("Langkah 5: Favorite Tool dilepas (dipindahkan ke Backpack)")
        return true
    end

    return false
end

-- 8C. SHOVEL BUAH MUTASI < THRESHOLD (multi-pass)
local SHOVEL_MAX_PASSES = 6

local function shovelFruitsOnTree(treeName, threshold)
    if not RemoveItemRemote then
        warn("⚠️ Remove_Item remote tidak ditemukan.")
        return
    end

    local shovel = equipToolByPrefix("Shovel [Destroy Plants]")
    if not shovel then
        warn("⚠️ Shovel [Destroy Plants] tidak ditemukan di Backpack.")
        return
    end
    debugStep("Langkah 2B: shovel di-equip")

    for pass = 1, SHOVEL_MAX_PASSES do
        local fruits = scanFruitsOnTree(treeName)
        local toShovel = {}
        for _, p in ipairs(fruits) do
            if p.mutCount < threshold then
                table.insert(toShovel, p.instance)
            end
        end

        if #toShovel == 0 then
            if pass == 1 then
                debugStep("Langkah 2B: tidak ada buah di " .. treeName .. " dengan mutasi < " .. threshold)
            else
                debugStep("Langkah 2B: sudah bersih (pass " .. pass .. ")")
            end
            break
        end

        debugStep("Langkah 2B: pass " .. pass .. "/" .. SHOVEL_MAX_PASSES .. " - " .. #toShovel .. " buah mutasi < " .. threshold)
        for i, fruit in ipairs(toShovel) do
            local ok, err = pcall(function()
                RemoveItemRemote:FireServer(fruit)
            end)
            if ok then
                debugStep("Langkah 2B: shovel " .. i .. "/" .. #toShovel .. " berhasil")
            else
                warn("⚠️ Gagal shovel buah: " .. tostring(err))
            end
            task.wait(0.3)
        end

        task.wait(0.7)
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack and shovel.Parent == LocalPlayer.Character then
        shovel.Parent = backpack
        debugStep("Langkah 2B: shovel dilepas")
    end
    task.wait(0.3)
end

-- 8D. FAV/UNFAV BUAH
local function setFruitFavorite(fruitInstance, state)
    if not fruitInstance then return false end
    if not FavoriteToolRemote then
        warn("⚠️ FavoriteToolRemote tidak ditemukan.")
        return false
    end

    local favTool = equipToolByPrefix("Favorite Tool")
    if not favTool then
        warn("⚠️ Favorite Tool gagal di-equip.")
        return false
    end

    local ok, err = pcall(function()
        FavoriteToolRemote:InvokeServer(favTool, fruitInstance, state)
    end)
    if not ok then
        warn("⚠️ Gagal " .. (state and "favorite" or "unfavorite") .. " buah: " .. tostring(err))
    end
    return ok
end

-- 8E. PET EQUIP / UNEQUIP (posisi tetap, khusus Anubis)
local PET_EQUIP_CFRAME = CFrame.new(-16.000007629395, 4, -116.50244903564, 1, 0, 0, 0, 1, 0, 0, 0, 1)

local function equipPetByUUID(uuid)
    if not uuid or not PetsServiceEvent then return end
    PetsServiceEvent:FireServer("EquipPet", uuid, PET_EQUIP_CFRAME)
end

local function unequipPetByUUID(uuid)
    if not uuid or not PetsServiceEvent then return end
    PetsServiceEvent:FireServer("UnequipPet", uuid)
end

local function equipPetListTogether(uuidList)
    for _, uuid in ipairs(uuidList) do
        equipPetByUUID(uuid)
    end
    task.wait(0.2)
end

local function unequipPetList(uuidList)
    for _, uuid in ipairs(uuidList) do
        unequipPetByUUID(uuid)
    end
    task.wait(0.2)
end

-- 8F. NOTIFICATION LISTENERS
local function waitForNotificationCount(matchFn, targetCount, timeoutSeconds)
    local count = 0
    local startTime = tick()

    if not NotificationEvent then
        warn("⚠️ Notification event tidak ditemukan, skip.")
        return 0
    end

    local connection
    connection = NotificationEvent.OnClientEvent:Connect(function(...)
        local args = { ... }
        for _, v in ipairs(args) do
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
    local growthFound = false
    local spiderWebCount = 0
    local startTime = tick()

    if not NotificationEvent then
        warn("⚠️ Notification event tidak ditemukan, skip.")
        return false, 0
    end

    local connection
    connection = NotificationEvent.OnClientEvent:Connect(function(...)
        local args = { ... }
        for _, v in ipairs(args) do
            if type(v) == "string" then
                if matchFn(v) then
                    growthFound = true
                end
                if v:find("Spider's ability: Web Weave", 1, true) then
                    spiderWebCount = spiderWebCount + 1
                end
            end
        end
    end)

    while anubisLevelingRunning and not growthFound and spiderWebCount < spiderWebTargetCount and (tick() - startTime) < timeoutSeconds do
        task.wait(0.5)
    end

    connection:Disconnect()
    return growthFound, spiderWebCount
end

local NOTIF_TARGET_COUNT = 6
local NOTIF_TIMEOUT_SECONDS = 60
local SPIDER_WEB_WAVE_TARGET_COUNT = 7
local SPIDER_WEB_WAVE_TIMEOUT_SECONDS = 120
local ANUBIS_TIMEOUT_SECONDS = 60

-- 8G0. WEBHOOK TARGET TERCAPAI (ANUBIS)
local function sendTargetReachedWebhook(webhookUrl, petData, targetUUID, targetLevel, durationSeconds)
    if not webhookUrl or webhookUrl == "" then
        return
    end

    local petName = (petData and petData.name) or "Unknown"
    local petMutation = (petData and petData.mutation) or "Normal"
    local petLevel = (petData and petData.level) or targetLevel

    local payload = {
        embeds = {
            {
                title = "🎯 Target Level Tercapai!",
                color = 3066993,
                fields = {
                    { name = "Pet", value = tostring(petMutation) .. " " .. tostring(petName), inline = true },
                    { name = "UUID", value = tostring(targetUUID), inline = true },
                    { name = "Level Tercapai", value = tostring(petLevel) .. " / " .. tostring(targetLevel), inline = true },
                    { name = "Lama Pengerjaan", value = formatDuration(durationSeconds), inline = false },
                },
            }
        }
    }

    local ok, jsonBody = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not ok then
        warn("⚠️ Gagal encode payload webhook: " .. tostring(jsonBody))
        return
    end

    local sent, err = sendWebhookRaw(webhookUrl, jsonBody)
    if sent then
        debugStep("Webhook terkirim: target level tercapai (" .. formatDuration(durationSeconds) .. ")")
    else
        warn("⚠️ Gagal mengirim webhook: " .. tostring(err))
    end
end

-- 8G. SCAN & COLLECT PER POHON (forward-declared di atas)
function scanFruitsOnTree(treeName)
    local all = scanAllPlants()
    local result = {}
    for _, p in ipairs(all) do
        if p.plantName == treeName then
            table.insert(result, p)
        end
    end
    return result
end

function findFruitOnTreeByExactMutation(treeName, mutationCount)
    local fruits = scanFruitsOnTree(treeName)
    for _, p in ipairs(fruits) do
        if p.mutCount == mutationCount then
            return p
        end
    end
    return nil
end

function countFruitsOnTreeWithMutationAbove(treeName, threshold, exceptInstance)
    local count = 0
    local fruits = scanFruitsOnTree(treeName)
    for _, p in ipairs(fruits) do
        if p.instance ~= exceptInstance and p.mutCount > threshold then
            count = count + 1
        end
    end
    return count
end

-- 8H. SHOVEL BUAH MUTASI < threshold (LANGKAH 5)
local function shovelLowMutationFruitsOnTree(treeName, threshold)
    if not RemoveItemRemote then
        warn("⚠️ Remove_Item remote tidak ditemukan.")
        return
    end

    equipNonFavoriteTool()

    local shovel = equipToolByPrefix("Shovel [Destroy Plants]")
    if not shovel then
        warn("⚠️ Shovel [Destroy Plants] tidak ditemukan di Backpack.")
        return
    end
    debugStep("Langkah 5: shovel di-equip untuk menghapus buah mutasi < " .. threshold)

    for pass = 1, SHOVEL_MAX_PASSES do
        local fruits = scanFruitsOnTree(treeName)
        local toShovel = {}
        for _, p in ipairs(fruits) do
            if p.mutCount < threshold then
                table.insert(toShovel, p.instance)
            end
        end

        if #toShovel == 0 then
            if pass == 1 then
                debugStep("Langkah 5: tidak ada buah di " .. treeName .. " dengan mutasi < " .. threshold)
            else
                debugStep("Langkah 5: sudah bersih (pass " .. pass .. ")")
            end
            break
        end

        debugStep("Langkah 5: pass " .. pass .. "/" .. SHOVEL_MAX_PASSES .. " - " .. #toShovel .. " buah")
        for i, fruit in ipairs(toShovel) do
            local ok, err = pcall(function()
                RemoveItemRemote:FireServer(fruit)
            end)
            if ok then
                debugStep("Langkah 5: shovel " .. i .. "/" .. #toShovel .. " berhasil")
            else
                warn("⚠️ Gagal shovel buah: " .. tostring(err))
            end
            task.wait(0.3)
        end

        task.wait(0.7)
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack and shovel.Parent == LocalPlayer.Character then
        shovel.Parent = backpack
        debugStep("Langkah 5: shovel dilepas")
    end
    task.wait(0.3)
end

-- 8I. UNFAVORITE TARGET BUAH SEBELUMNYA
local function unfavoritePreviousTargetFruit(previousInstance)
    if not previousInstance then
        debugStep("Langkah 1: tidak ada buah target sebelumnya, lewati")
        return false
    end
    debugStep("Langkah 1: unfavorite buah target sebelumnya")
    local success = setFruitFavorite(previousInstance, false)
    task.wait(0.3)
    return success
end

-- ------------------------------------------------------------
-- 7E. START / STOP ANUBIS LEVELING
-- ------------------------------------------------------------
function stopLevelingAnubis()
    anubisLevelingRunning = false
    suppressToggleCallback = true
    autoToggle:Set(false)
    suppressToggleCallback = false
    if anubisStatusParagraph then
        anubisStatusParagraph:SetDesc("Status: Stopped")
    end
    debugStep("⏹️ STOP")
end

function startLevelingAnubis()
    if anubisLevelingRunning then
        debugStep("sudah berjalan, abaikan.")
        return
    end

    debugStep("startLevelingAnubis() dipanggil...")

    local anubis = currentAnubis
    local cornling = currentCornling
    local frog = currentFrog
    local targets = currentTargets
    local targetLevel = currentTargetLevel
    local mutationCount = currentMutationCount
    local collectThreshold = currentCollectThreshold
    local tree = currentTree

    if #cornling == 0 then warn("⚠️ Pilih Tim Cornling!"); return end
    if #anubis == 0 then warn("⚠️ Pilih Tim Anubis!"); return end
    if #frog == 0 then warn("⚠️ Pilih Tim Frog/Echo Frog!"); return end
    if #targets == 0 then warn("⚠️ Pilih Target Leveling!"); return end
    if targetLevel < 1 then warn("⚠️ Target Level tidak valid!"); return end
    if mutationCount < 0 then warn("⚠️ Jumlah Mutasi tidak valid!"); return end
    if collectThreshold < 0 then warn("⚠️ Batas Collect tidak valid!"); return end
    if tree == "" then warn("⚠️ Pilih Pohon!"); return end

    anubisLevelingRunning = true
    if anubisStatusParagraph then
        anubisStatusParagraph:SetDesc("Status: Running...")
    end

    task.spawn(function()
        local ok, err = pcall(function()
            for targetIndex, targetUUID in ipairs(targets) do
                if not anubisLevelingRunning then break end

                debugStep("=== TARGET #" .. targetIndex .. "/" .. #targets .. " ===")

                local petData = getPetByUUID(targetUUID)
                local currentLevel = petData and petData.level or 0

                if currentLevel >= targetLevel then
                    debugStep("⚠️ Target sudah mencapai level " .. currentLevel .. ", lewati.")
                    unequipPetByUUID(targetUUID)
                    for _, uuid in ipairs(anubis) do
                        unequipPetByUUID(uuid)
                    end
                    debugStep("Selesai target #" .. targetIndex)
                else
                    debugStep(string.format("Level target: %d/%d", currentLevel, targetLevel))

                    local favoritedFruitInstance = nil
                    local targetStartTime = tick()

                    while anubisLevelingRunning and currentLevel < targetLevel do

                        -- ===== LANGKAH 1 =====
                        debugStep("Langkah 1: unfavorite buah target sebelumnya (jika ada)")
                        if anubisStatusParagraph then anubisStatusParagraph:SetDesc("Status: Bersihkan buah target sebelumnya...") end
                        unfavoritePreviousTargetFruit(favoritedFruitInstance)
                        favoritedFruitInstance = nil
                        if not anubisLevelingRunning then break end

                        -- ===== LANGKAH 2 =====
                        debugStep("Langkah 2A: equip Frog")
                        if anubisStatusParagraph then anubisStatusParagraph:SetDesc("Status: Equip Frog...") end
                        equipPetListTogether(frog)
                        if not anubisLevelingRunning then break end

                        debugStep("Langkah 2B: shovel buah di " .. tree .. " dengan mutasi < " .. collectThreshold)
                        if anubisStatusParagraph then anubisStatusParagraph:SetDesc("Status: Shovel buah mutasi rendah...") end
                        shovelFruitsOnTree(tree, collectThreshold)
                        if not anubisLevelingRunning then
                            unequipPetList(frog)
                            break
                        end

                        debugStep("Langkah 2C: tunggu notifikasi growth atau Spider Web Wave " .. SPIDER_WEB_WAVE_TARGET_COUNT .. "x")
                        if anubisStatusParagraph then anubisStatusParagraph:SetDesc("Status: Tunggu growth / Spider Web Wave...") end
                        local frogTrigger = string.format("Frog advanced the growth of your %s plant by 24 hours", tree)
                        local growthFound, spiderWebCount = waitForGrowthOrSpiderWeb(function(msg)
                            return msg:find(frogTrigger) ~= nil
                        end, SPIDER_WEB_WAVE_TARGET_COUNT, SPIDER_WEB_WAVE_TIMEOUT_SECONDS)
                        if growthFound then
                            debugStep("Langkah 2C: notifikasi growth diterima!")
                        elseif spiderWebCount >= SPIDER_WEB_WAVE_TARGET_COUNT then
                            debugStep("Langkah 2C: Spider Web Wave terpicu " .. spiderWebCount .. "x")
                        else
                            debugStep("Langkah 2C: timeout")
                        end

                        unequipPetList(frog)
                        task.wait(0.5)
                        if not anubisLevelingRunning then break end

                        -- ===== LANGKAH 3 =====
                        debugStep("Langkah 3: equip Cornling, tunggu 6x Corn Synergy")
                        if anubisStatusParagraph then anubisStatusParagraph:SetDesc("Status: Equip Cornling & tunggu synergy...") end
                        equipPetListTogether(cornling)

                        local synergyProcs = waitForNotificationCount(function(msg)
                            return msg:find("Corn Synergy") ~= nil
                        end, NOTIF_TARGET_COUNT, NOTIF_TIMEOUT_SECONDS)
                        debugStep(string.format("Langkah 3: Corn Synergy proc %d/%d", synergyProcs, NOTIF_TARGET_COUNT))

                        unequipPetList(cornling)
                        task.wait(0.5)
                        if not anubisLevelingRunning then break end

                        -- ===== LANGKAH 3B =====
                        debugStep("Langkah 3B: shovel buah di " .. tree .. " (pasca Cornling)")
                        if anubisStatusParagraph then anubisStatusParagraph:SetDesc("Status: Shovel buah mutasi rendah (pasca Cornling)...") end
                        shovelFruitsOnTree(tree, collectThreshold)
                        if not anubisLevelingRunning then break end

                        -- ===== LANGKAH 4 =====
                        debugStep(string.format("Langkah 4: cari buah di %s dengan tepat %d mutasi, favoritkan", tree, mutationCount))
                        if anubisStatusParagraph then anubisStatusParagraph:SetDesc("Status: Favoritkan buah target mutasi...") end
                        local matched = findFruitOnTreeByExactMutation(tree, mutationCount)
                        if matched then
                            debugStep("Langkah 4: buah ditemukan, difavoritkan")
                            setFruitFavorite(matched.instance, true)
                            favoritedFruitInstance = matched.instance
                        else
                            debugStep("Langkah 4: tidak ada buah dengan tepat " .. mutationCount .. " mutasi di " .. tree)
                        end
                        task.wait(0.5)
                        if not anubisLevelingRunning then break end

                        -- ===== LANGKAH 5 =====
                        debugStep("Langkah 5: shovel buah di " .. tree .. " dengan mutasi < " .. collectThreshold)
                        if anubisStatusParagraph then anubisStatusParagraph:SetDesc("Status: Shovel buah rendah...") end
                        shovelLowMutationFruitsOnTree(tree, collectThreshold)
                        task.wait(0.5)
                        if not anubisLevelingRunning then break end

                        -- ===== LANGKAH 6 =====
                        debugStep("Langkah 6: equip Anubis + Target")
                        if anubisStatusParagraph then anubisStatusParagraph:SetDesc("Status: Equip Anubis + Target...") end
                        local anubisAndTarget = {}
                        for _, uuid in ipairs(anubis) do table.insert(anubisAndTarget, uuid) end
                        table.insert(anubisAndTarget, targetUUID)
                        equipPetListTogether(anubisAndTarget)

                        local anubisStartTime = tick()
                        local reachedDuringAnubis = false
                        while anubisLevelingRunning do
                            local petDataDuringAnubis = getPetByUUID(targetUUID)
                            local levelDuringAnubis = petDataDuringAnubis and (petDataDuringAnubis.level or 0) or currentLevel
                            if levelDuringAnubis >= targetLevel then
                                currentLevel = levelDuringAnubis
                                reachedDuringAnubis = true
                                debugStep("Langkah 6: level target tercapai (" .. levelDuringAnubis .. "/" .. targetLevel .. ") saat equip Anubis")
                                break
                            end

                            local remaining = countFruitsOnTreeWithMutationAbove(tree, 10, favoritedFruitInstance)
                            if remaining <= 0 then
                                debugStep("Langkah 6: semua buah di " .. tree .. " sudah <= 10 mutasi (kecuali favorit)")
                                break
                            end
                            if (tick() - anubisStartTime) >= ANUBIS_TIMEOUT_SECONDS then
                                debugStep("Langkah 6: timeout, lanjut ke Langkah 7")
                                break
                            end
                            task.wait(1)
                        end

                        unequipPetList(anubisAndTarget)
                        task.wait(0.5)

                        if reachedDuringAnubis then
                            debugStep("✅ Target level tercapai! (terdeteksi saat equip Anubis)")
                            local elapsed = tick() - targetStartTime
                            sendTargetReachedWebhook(currentWebhookUrl, getPetByUUID(targetUUID), targetUUID, targetLevel, elapsed)
                            unequipPetByUUID(targetUUID)
                            for _, uuid in ipairs(anubis) do
                                unequipPetByUUID(uuid)
                            end
                            break
                        end

                        -- ===== LANGKAH 7 =====
                        debugStep("Langkah 7: cek level target")
                        local petDataNow = getPetByUUID(targetUUID)
                        currentLevel = petDataNow and (petDataNow.level or 0) or currentLevel
                        debugStep(string.format("Langkah 7: level sekarang %d/%d", currentLevel, targetLevel))
                        if anubisStatusParagraph then
                            anubisStatusParagraph:SetDesc(string.format("Status: Leveling... %d/%d", currentLevel, targetLevel))
                        end

                        if currentLevel >= targetLevel then
                            debugStep("✅ Target level tercapai! Unequip target dan lanjut.")
                            local elapsed = tick() - targetStartTime
                            sendTargetReachedWebhook(currentWebhookUrl, petDataNow, targetUUID, targetLevel, elapsed)
                            unequipPetByUUID(targetUUID)
                            for _, uuid in ipairs(anubis) do
                                unequipPetByUUID(uuid)
                            end
                            break
                        end
                    end -- while

                    unequipPetByUUID(targetUUID)
                    for _, uuid in ipairs(anubis) do
                        unequipPetByUUID(uuid)
                    end
                    debugStep("Selesai target #" .. targetIndex)
                end
            end
        end)

        if not ok then
            warn("❌ [AutoLevelingAnubis] Error: " .. tostring(err))
        end

        debugStep("Proses selesai, stop.")
        stopLevelingAnubis()
    end)
end

-- TOMBOL REFRESH ANUBIS
AnubisSection:Button({
    Title = "🔄 Refresh Data",
    Justify = "Center",
    Callback = function()
        anubisDropdown:Refresh(getPetList(true))
        cornlingDropdown:Refresh(getPetList(true))
        frogDropdown:Refresh(getPetList(true))
        targetLevelingDropdown:Refresh(getPetList(false))
        treeDropdown:Refresh(getTreeList())
        print("✅ Data Anubis di-refresh!")
    end
})

-- CONFIG ANUBIS
local function applyAnubisConfig()
    local data, err = AnubisConfig:Load()
    if data == false then
        warn("⚠️ [Anubis] Gagal memuat konfigurasi: " .. tostring(err))
    end
end

local AnubisConfigSection = TabAnubis:Section({ Title = "Config" })
AnubisConfigSection:Button({
    Title = "Simpan Konfigurasi",
    Justify = "Center",
    Callback = function()
        AnubisConfig:Save()
        print("✅ Konfigurasi Anubis disimpan!")
    end
})
AnubisConfigSection:Button({
    Title = "Muat Konfigurasi",
    Justify = "Center",
    Callback = function()
        applyAnubisConfig()
        print("✅ Konfigurasi Anubis dimuat!")
        anubisDropdown:Select(AnubisConfig:Get("anubis_tim_anubis") or {})
        cornlingDropdown:Select(AnubisConfig:Get("anubis_tim_cornling") or {})
        frogDropdown:Select(AnubisConfig:Get("anubis_tim_frog") or {})
        targetLevelingDropdown:Select(AnubisConfig:Get("anubis_target_leveling") or {})
        treeDropdown:Select(AnubisConfig:Get("anubis_selected_tree") or "")
        targetLevelInput:SetValue(tostring(AnubisConfig:Get("anubis_target_level") or 500))
        mutationCountInput:SetValue(tostring(AnubisConfig:Get("anubis_mutation_count") or 1))
        collectThresholdInput:SetValue(tostring(AnubisConfig:Get("anubis_collect_threshold") or 10))
        webhookInput:SetValue(tostring(AnubisConfig:Get("anubis_webhook_url") or ""))
        autoToggle:Set(AnubisConfig:Get("anubis_auto_leveling") or false)
        espToggle:Set(AnubisConfig:Get("anubis_esp_mutation") or false)
        autoBuyToggle:Set(AnubisConfig:Get("anubis_auto_buy_fav_tool") or false)
    end
})

-- ============================================================
-- 8. TAB PNP (SCRIPT A)
-- ============================================================
local TabPNP = Window:Tab({
    Title = "PNP",
    Icon = "solar:refresh-bold",
})

local PNPSettingsSection = TabPNP:Section({ Title = "PNP Settings" })

local pnpPets = DataPetModule.findPets({ isFavorite = true })
local pnpOptions = buildDropdownOptions(pnpPets)
local defaultPNPUUIDs = MyConfig:Get("tim_pnp_uuids") or {}

local dropdownTimPNP = PNPSettingsSection:Dropdown({
    Title = "Pilih Tim PNP",
    Multi = true,
    Search = true,
    AllowNone = true,
    Values = pnpOptions,
    Value = defaultPNPUUIDs,
    Flag = "tim_pnp_uuids",
    Callback = function(selected)
        local uuids = normalizeUUIDList(selected)
        MyConfig:Set("tim_pnp_uuids", uuids)
        MyConfig:Save()
        print("Tim PNP UUIDs tersimpan:", table.concat(uuids, ", "))
    end
})

PNPSettingsSection:Button({
    Title = "Clear All Tim PNP",
    Justify = "Center",
    Callback = function()
        dropdownTimPNP:Select({})
        MyConfig:Set("tim_pnp_uuids", {})
        MyConfig:Save()
        print("Tim PNP list dikosongkan.")
    end
})

PNPSettingsSection:Space()

local defaultPickup = tonumber(MyConfig:Get("pnp_pickup")) or 0.6
MyConfig:Set("pnp_pickup", defaultPickup)

PNPSettingsSection:Input({
    Title = "Pickup",
    Value = tostring(defaultPickup),
    Placeholder = "0.6",
    Flag = "pnp_pickup_input",
    Callback = function(value)
        local num = tonumber(value) or 0.6
        if num < 0 then num = 0 end
        MyConfig:Set("pnp_pickup", num)
        MyConfig:Save()
        print("Pickup tersimpan:", num)
    end
})

PNPSettingsSection:Space()

local defaultPlace = tonumber(MyConfig:Get("pnp_place")) or 0
MyConfig:Set("pnp_place", defaultPlace)

PNPSettingsSection:Input({
    Title = "Place",
    Value = tostring(defaultPlace),
    Placeholder = "0",
    Flag = "pnp_place_input",
    Callback = function(value)
        local num = tonumber(value) or 0
        if num < 0 then num = 0 end
        MyConfig:Set("pnp_place", num)
        MyConfig:Save()
        print("Place tersimpan:", num)
    end
})

local PNPActionSection = TabPNP:Section({ Title = "Actions" })

-- LOGIKA PNP (event-driven via PetCooldownsUpdated)
local isPNPRunning = false
local pnpOffsets = {}
local pnpProcessing = {}

local function equipPetPNP(uuid, offsetIndex)
    if not PetsService or uuid == "" then return end
    local baseCFrame = getEquipCFrame()
    local offset = CFrame.new((offsetIndex or 0) * 3, 0, 0)
    local cframe = baseCFrame * offset
    PetsService:FireServer("EquipPet", uuid, cframe)
    print("Equip pet (PNP):", uuid)
end

local PNP_MIN_PLACE_DELAY = 0.5

local function pnpProcessPet(uuid, offsetIndex)
    if pnpProcessing[uuid] then return end
    pnpProcessing[uuid] = true

    local pickupDelay = tonumber(MyConfig:Get("pnp_pickup")) or 0.6
    local placeDelay = tonumber(MyConfig:Get("pnp_place")) or 0

    task.wait(pickupDelay)
    unequipPet(uuid)
    print("PNP Pickup:", uuid)

    task.wait(math.max(placeDelay, PNP_MIN_PLACE_DELAY))
    equipPetPNP(uuid, offsetIndex)
    print("PNP Place:", uuid)

    pnpProcessing[uuid] = false
end

local PNPCooldownEvent = GameEvents and GameEvents:FindFirstChild("PetCooldownsUpdated")

if PNPCooldownEvent then
    PNPCooldownEvent.OnClientEvent:Connect(function(petId, dataArray)
        if not isPNPRunning or not petId then return end

        local uuids = MyConfig:Get("tim_pnp_uuids") or {}
        uuids = normalizeUUIDList(uuids)

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
            task.spawn(function()
                pnpProcessPet(petId, offsetIndex)
            end)
        end
    end)
else
    warn("PetCooldownsUpdated tidak ditemukan, PNP mungkin tidak bekerja optimal.")
end

local function startPNP()
    if isPNPRunning then return end
    local uuids = MyConfig:Get("tim_pnp_uuids") or {}
    uuids = normalizeUUIDList(uuids)
    if #uuids == 0 then
        print("Tim PNP kosong, tidak bisa memulai.")
        return
    end

    isPNPRunning = true

    for i, uuid in ipairs(uuids) do
        pnpOffsets[uuid] = i - 1
        equipPetPNP(uuid, pnpOffsets[uuid])
        task.wait(0.2)
    end

    print("PNP dimulai untuk " .. #uuids .. " pet secara bersamaan (event-driven).")
end

local function stopPNP()
    isPNPRunning = false
    pnpOffsets = {}
    pnpProcessing = {}
    print("PNP dihentikan.")
end

local isPNPRunningSaved = MyConfig:Get("is_pnp_running") or false

local togglePNPStartStop = PNPActionSection:Toggle({
    Title = "Start / Stop",
    Value = isPNPRunningSaved,
    Flag = "is_pnp_running",
    Callback = function(value)
        MyConfig:Set("is_pnp_running", value)
        MyConfig:Save()
        if value then
            print("PNP: ON")
            startPNP()
        else
            print("PNP: OFF")
            stopPNP()
        end
    end
})

-- ============================================================
-- 9. TAB WEBHOOK (SHARED - dipakai semua fitur)
-- ============================================================
local TabWebhook = Window:Tab({
    Title = "Webhook",
    Icon = "solar:link-bold",
})

local WebhookSettingsSection = TabWebhook:Section({ Title = "Discord Webhook Settings" })

local savedWebhookURL = MyConfig:Get("discord_webhook_url")
if type(savedWebhookURL) ~= "string" then savedWebhookURL = "" end

local inputWebhookURL = WebhookSettingsSection:Input({
    Title = "Url Discord Webhook",
    Value = savedWebhookURL,
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "discord_webhook_url_input",
    Callback = function(value)
        value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
        MyConfig:Set("discord_webhook_url", value)
        MyConfig:Save()
        if value ~= "" then
            print("URL Discord Webhook tersimpan:", value)
        else
            print("URL Discord Webhook dikosongkan, akan pakai URL default.")
        end
    end
})

WebhookSettingsSection:Space()

WebhookSettingsSection:Button({
    Title = "Kirim Test Webhook",
    Justify = "Center",
    Callback = function()
        sendDiscordWebhook(
            "Test Webhook",
            "Ini adalah pesan tes dari Pria Solo HUB.\nJika kamu melihat pesan ini, webhook sudah terhubung dengan benar.",
            3447003
        )
        print("Test webhook dikirim.")
    end
})

WebhookSettingsSection:Space()

WebhookSettingsSection:Button({
    Title = "Reset ke Webhook Default",
    Justify = "Center",
    Callback = function()
        inputWebhookURL:SetValue("")
        MyConfig:Set("discord_webhook_url", "")
        MyConfig:Save()
        print("URL Discord Webhook direset ke default.")
    end
})

-- ============================================================
-- 10. FINALISASI: AUTO-LOAD CONFIG & RESTORE TOGGLE
-- ============================================================
MyConfig:Save()

print("✅ Pria Solo HUB (All-in-One) siap digunakan!")

if MyConfig:Get("is_running") then
    toggleStartStop:Set(true)
end

if MyConfig:Get("is_leveling_running") then
    toggleLevelingStartStop:Set(true)
end

if MyConfig:Get("is_pnp_running") then
    togglePNPStartStop:Set(true)
end

-- Auto-load config Anubis (seperti v24)
applyAnubisConfig()

-- ============================================================
-- SCRIPT: Pria Solo HUB - Auto Shark Tab (WindUI + ConfigManager)
-- Logika FINAL: satu cycle = equip target+tumbal sekali, tunggu notifikasi,
-- lalu unequip target+tumbal, equip shark, dan cycle berikutnya dimulai
-- dari awal (tunggu mimic ready lagi)
-- ============================================================

-- ============================================================
-- 1. LOAD WindUI
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
if not WindUI then error("Gagal memuat WindUI!") end

-- ============================================================
-- 2. LOAD DataPetModule
-- ============================================================
local DataPetModule = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/DataPetModule.lua"
))()
if not DataPetModule then error("Gagal memuat DataPetModule!") end

-- ============================================================
-- 3. FUNGSI BANTUAN & AKSES DATA SERVICE
-- ============================================================
local function getDataService()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

-- ============================================================
-- 4. FUNGSI LAINNYA (mutasi, format, dropdown)
-- ============================================================
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
    return string.format("%s [%s] Lv.%d", pet.name, pet.mutation, pet.level)
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

-- ============================================================
-- 5. BUAT WINDOW DAN CONFIG MANAGER
-- ============================================================
local Window = WindUI:CreateWindow({
    Title = "Pria Solo HUB",
    Folder = "PriaSoloHUB",
    Size = UDim2.new(0, 400, 0, 600),
    Center = true,
    AutoShow = true,
    Draggable = true,
})

local MyConfig = Window.ConfigManager:Config("AutoSharkConfig")
MyConfig:Load()

-- ============================================================
-- 6. TAB AUTO SHARK
-- ============================================================
local TabAutoShark = Window:Tab({
    Title = "Auto Shark",
    Icon = "solar:shark-bold",
})

local SettingsSection = TabAutoShark:Section({ Title = "Auto Shark Settings" })

-- ========== DROPDOWN 1: Tim Shark ==========
local sharkPets = DataPetModule.findPets({ isFavorite = true })
local sharkOptions = buildDropdownOptions(sharkPets)
local defaultSharkUUIDs = MyConfig:Get("tim_shark_uuids") or {}

local dropdownTimShark = SettingsSection:Dropdown({
    Title = "Pilih Tim Shark",
    Multi = true,
    Search = true,
    Values = sharkOptions,
    Value = defaultSharkUUIDs,
    Flag = "tim_shark_uuids",
    Callback = function(selected)
        local uuids = {}
        if type(selected) == "table" then
            for _, item in ipairs(selected) do
                if type(item) == "table" and item.Value then
                    table.insert(uuids, item.Value)
                elseif type(item) == "string" then
                    table.insert(uuids, item)
                end
            end
        end
        MyConfig:Set("tim_shark_uuids", uuids)
        MyConfig:Save()
        print("Tim Shark UUIDs tersimpan:", table.concat(uuids, ", "))
    end
})

SettingsSection:Space()

-- ========== DROPDOWN 2: Pet Target ==========
local targetPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = "Normal"
})
local targetOptions = buildDropdownOptions(targetPets)
local defaultTargetUUIDs = MyConfig:Get("pet_target_uuids") or {}

local dropdownPetTarget = SettingsSection:Dropdown({
    Title = "Pilih Pet Target",
    Multi = true,
    Search = true,
    Values = targetOptions,
    Value = defaultTargetUUIDs,
    Flag = "pet_target_uuids",
    Callback = function(selected)
        local uuids = {}
        if type(selected) == "table" then
            for _, item in ipairs(selected) do
                if type(item) == "table" and item.Value then
                    table.insert(uuids, item.Value)
                elseif type(item) == "string" then
                    table.insert(uuids, item)
                end
            end
        end
        MyConfig:Set("pet_target_uuids", uuids)
        MyConfig:Save()
        print("Pet Target UUIDs tersimpan:", table.concat(uuids, ", "))
    end
})

SettingsSection:Space()

-- ========== DROPDOWN 3: Target Mutasi ==========
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

local dropdownTargetMutasi = SettingsSection:Dropdown({
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
        updateTumbalDropdown(value)
    end
})

SettingsSection:Space()

-- ========== DROPDOWN 4: Pet Tumbal ==========
local tumbalOptions = {}
local tumbalDropdownObject = nil

local function updateTumbalDropdown(mutation)
    print("updateTumbalDropdown dipanggil dengan mutasi:", mutation)
    local tumbalPets = DataPetModule.findPets({
        isFavorite = false,
        mutation = mutation
    })
    print("Jumlah pet tumbal ditemukan:", #tumbalPets)
    if #tumbalPets > 0 then
        print("Contoh pet pertama:", tumbalPets[1].name, tumbalPets[1].mutation)
    end
    
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
            tumbalDropdownObject:Set(validUUIDs)
        else
            tumbalDropdownObject.Values = newOptions
            tumbalDropdownObject.Value = validUUIDs
        end
        print("Dropdown tumbal diperbarui dengan", #newOptions, "opsi")
    end
end

-- Inisialisasi tumbal
local initialMut = defaultMutation
local initialTumbalPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = initialMut
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

local dropdownPetTumbal = SettingsSection:Dropdown({
    Title = "Pilih Pet Tumbal",
    Multi = true,
    Search = true,
    Values = tumbalOptions,
    Value = initialValidUUIDs,
    Flag = "pet_tumbal_uuids",
    Callback = function(selected)
        local uuids = {}
        if type(selected) == "table" then
            for _, item in ipairs(selected) do
                if type(item) == "table" and item.Value then
                    table.insert(uuids, item.Value)
                elseif type(item) == "string" then
                    table.insert(uuids, item)
                end
            end
        end
        MyConfig:Set("pet_tumbal_uuids", uuids)
        MyConfig:Save()
        print("Pet Tumbal UUIDs tersimpan:", table.concat(uuids, ", "))
    end
})

tumbalDropdownObject = dropdownPetTumbal

-- ============================================================
-- 7. SECTION TOMBOL AKSI
-- ============================================================
local ActionSection = TabAutoShark:Section({ Title = "Actions" })

-- ============================================================
-- 8. FUNGSI EQUIP/UNEQUIP VIA REMOTE
-- ============================================================
local PetsService = game:GetService("ReplicatedStorage"):FindFirstChild("GameEvents"):FindFirstChild("PetsService")
local NotificationEvent = game:GetService("ReplicatedStorage"):FindFirstChild("GameEvents"):FindFirstChild("Notification")
local Player = game.Players.LocalPlayer

local function getEquipCFrame()
    if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        return Player.Character.HumanoidRootPart.CFrame
    else
        return CFrame.new(0, 0, 0)
    end
end

local function equipPet(uuid)
    if not PetsService or uuid == "" then return end
    local cframe = getEquipCFrame()
    PetsService:FireServer("EquipPet", uuid, cframe)
    print("✅ Equip pet:", uuid)
end

local function unequipPet(uuid)
    if not PetsService or uuid == "" then return end
    PetsService:FireServer("UnequipPet", uuid)
    print("❌ Unequip pet:", uuid)
end

-- ============================================================
-- 9. FUNGSI CLEAR GARDEN
-- ============================================================
local function runClearGarden()
    print("🧹 ClearGarden: Memulai...")
    local equipped = getEquippedPetsUUIDs()
    if not equipped or #equipped == 0 then
        print("🧹 ClearGarden: Tidak ada pet terpasang.")
        return
    end
    print("🧹 ClearGarden: Menemukan " .. #equipped .. " pet terpasang.")
    for i, uuid in ipairs(equipped) do
        unequipPet(uuid)
        if i < #equipped then task.wait(0.6) end
    end
    print("🧹 ClearGarden: Selesai.")
end

-- ============================================================
-- 10. FUNGSI PENGECEKAN MUTASI TARGET
-- ============================================================
local function checkTargetMutation(uuid, targetMutation)
    print("🔍 Cek mutasi target:", uuid, "target:", targetMutation)
    local allPets = DataPetModule.getAllPets()
    local petData = allPets[uuid]
    if not petData then
        print("❌ Target tidak ditemukan di inventory.")
        return false
    end
    local petInfo = petData.PetData or {}
    local rawMut = petInfo.MutationType or "Normal"
    local currentMut = DataPetModule.getAutoMutationName(rawMut)
    print("🔍 Mutasi saat ini:", currentMut)
    return currentMut == targetMutation
end

-- ============================================================
-- 11. FUNGSI COOLDOWN
-- ============================================================
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

-- ============================================================
-- 12. DETEKSI MIMIC & SHARK
-- ============================================================
local function getMimicUUID(timSharkUUIDs)
    local equipped = getEquippedPetsUUIDs()
    if #equipped == 0 then return nil end
    local equippedMap = {}
    for _, uuid in ipairs(equipped) do equippedMap[uuid] = true end
    
    for _, uuid in ipairs(timSharkUUIDs) do
        if equippedMap[uuid] then
            local passive = getCooldownPassive(uuid)
            if passive == "Mimicry" then
                local cdTime = getCooldownTime(uuid)
                print("🟢 Mimic ditemukan:", uuid, "Passive:", passive, "Time:", cdTime)
                return uuid
            end
        end
    end
    return nil
end

local function getSharkUUID(timSharkUUIDs, mimicUUID)
    local equipped = getEquippedPetsUUIDs()
    local equippedMap = {}
    for _, uuid in ipairs(equipped) do equippedMap[uuid] = true end
    
    for _, uuid in ipairs(timSharkUUIDs) do
        if equippedMap[uuid] and uuid ~= mimicUUID then
            return uuid
        end
    end
    return nil
end

-- ============================================================
-- 13. NORMALISASI UUID
-- ============================================================
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

-- ============================================================
-- 14. LOGIKA AUTO SHARK FINAL
-- ============================================================
local autoSharkCoroutine = nil
local isAutoSharkRunning = false
local targetQueue = {}
local currentTarget = nil
local currentTumbal = nil
local tumbalIndex = 1
local mutationResult = nil
local notificationConnection = nil

local function setupNotificationListener()
    if notificationConnection then return end
    notificationConnection = NotificationEvent.OnClientEvent:Connect(function(message)
        if type(message) ~= "string" then return end
        print("📢 Notifikasi diterima:", message)
        -- Hanya respon jika mengandung kata "failed" atau "spat its"
        if message:find("failed to transfer") then
            mutationResult = "failed"
            print("❌ Mutasi GAGAL")
        elseif message:find("spat its") then
            mutationResult = "success"
            print("✅ Mutasi BERHASIL")
        end
    end)
end

local function cleanupNotificationListener()
    if notificationConnection then
        notificationConnection:Disconnect()
        notificationConnection = nil
        print("🔌 Listener notifikasi dilepas.")
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
            print("⏭️ Target", uuid, "sudah memiliki mutasi", targetMut, "di-skip")
        end
    end
    local safeQueue = {}
    for _, v in ipairs(targetQueue) do
        if type(v) == "string" then table.insert(safeQueue, v) end
    end
    print("📋 Antrian target:", table.concat(safeQueue, ", "))
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
    print("🚀 Auto Shark loop dimulai")
    
    runClearGarden()
    task.wait(1)
    
    prepareTargetQueue()
    if #targetQueue == 0 then
        print("❌ Tidak ada target yang perlu diproses.")
        return
    end
    
    local timSharkUUIDs = MyConfig:Get("tim_shark_uuids") or {}
    timSharkUUIDs = normalizeUUIDList(timSharkUUIDs)
    if #timSharkUUIDs < 2 then
        print("❌ Tim shark harus terdiri dari minimal 2 pet (mimic dan shark).")
        return
    end
    
    setupNotificationListener()
    
    -- Siklus utama: setiap iterasi = satu cycle
    while isAutoSharkRunning and #targetQueue > 0 do
        -- 1. Equip tim shark (mimic + shark)
        print("🦈 Equip tim shark untuk cycle baru...")
        for _, uuid in ipairs(timSharkUUIDs) do
            equipPet(uuid)
            task.wait(0.3)
        end
        task.wait(1.5)
        
        -- 2. Tunggu mimic ready (cooldown 0)
        print("⏳ Menunggu mimic ready...")
        local mimic = nil
        local cooldownTime = 0
        repeat
            task.wait(0.5)
            mimic = getMimicUUID(timSharkUUIDs)
            if mimic then
                cooldownTime = getCooldownTime(mimic)
                print("⏳ Cooldown mimic:", cooldownTime, "Passive:", getCooldownPassive(mimic))
            else
                print("⏳ Mimic belum terdeteksi, mungkin belum ter-equip.")
            end
        until (mimic and cooldownTime == 0) or not isAutoSharkRunning
        if not isAutoSharkRunning then break
        print("✅ Mimic siap (cooldown 0).")
        
        -- 3. Jeda 0.6 detik
        print("⏳ Jeda 0.6 detik setelah mimic ready...")
        task.wait(0.6)
        
        -- 4. Cek mimic masih ada
        mimic = getMimicUUID(timSharkUUIDs)
        if not mimic then
            print("❌ Mimic hilang setelah jeda, hentikan siklus.")
            break
        end
        
        -- 5. Ambil target dan tumbal untuk cycle ini
        currentTarget = table.remove(targetQueue, 1)
        if not currentTarget then
            print("❌ Tidak ada target.")
            break
        end
        currentTumbal = getNextTumbal()
        if not currentTumbal then
            print("❌ Tidak ada tumbal.")
            break
        end
        
        -- 6. Unequip shark
        local shark = getSharkUUID(timSharkUUIDs, mimic)
        if shark then
            unequipPet(shark)
            print("🦈 Shark diunequip.")
        else
            print("⚠️ Shark tidak ditemukan, mungkin sudah tidak terpasang.")
        end
        task.wait(0.3)
        
        -- 7. Equip target & tumbal (hanya sekali per cycle)
        print("🎯 Equip target & tumbal...")
        equipPet(currentTarget)
        equipPet(currentTumbal)
        task.wait(0.5)
        
        -- 8. Tunggu mimic aktif (cooldown > 0)
        print("⏳ Menunggu mimic mulai aktif...")
        local waitCount = 0
        while isAutoSharkRunning and waitCount < 30 do
            local cd = getCooldownTime(mimic)
            if cd > 0 then
                print("✅ Mimic aktif, cooldown:", cd)
                break
            end
            task.wait(0.1)
            waitCount = waitCount + 1
        end
        if not isAutoSharkRunning then break
        
        -- 9. Reset notifikasi
        mutationResult = nil
        
        -- 10. Tunggu notifikasi (failed atau spat its) dengan timeout 15 detik
        local targetMut = MyConfig:Get("target_mutasi") or "Blossoming"
        print("⏳ Menunggu notifikasi mutasi... (timeout 15 detik)")
        local startWait = tick()
        while isAutoSharkRunning and mutationResult == nil and (tick() - startWait) < 15 do
            task.wait(0.2)
        end
        
        if mutationResult == nil then
            print("⏰ Timeout 15 detik tanpa notifikasi, anggap GAGAL.")
            mutationResult = "failed"
        end
        
        -- 11. Jeda 1 detik, lalu unequip target & tumbal (karena notifikasi sudah muncul)
        print("⏳ Jeda 1 detik sebelum unequip target & tumbal...")
        task.wait(1)
        unequipPet(currentTarget)
        unequipPet(currentTumbal)
        print("❌ Unequip target & tumbal.")
        
        -- 12. Proses hasil mutasi
        local success = (mutationResult == "success")
        if success then
            print("✅ Target", currentTarget, "BERHASIL mendapatkan mutasi", targetMut)
            -- Target selesai, lanjut ke target berikutnya di cycle selanjutnya
        else
            print("❌ Target", currentTarget, "GAGAL mendapatkan mutasi", targetMut, "akan diulang.")
            -- Kembalikan target ke antrian (diulang di cycle berikutnya)
            table.insert(targetQueue, 1, currentTarget)
        end
        
        -- 13. Jeda 1 detik, lalu equip shark kembali
        print("⏳ Jeda 1 detik sebelum equip shark kembali...")
        task.wait(1)
        local timShark = MyConfig:Get("tim_shark_uuids") or {}
        timShark = normalizeUUIDList(timShark)
        for _, uuid in ipairs(timShark) do
            if uuid ~= mimic then
                equipPet(uuid)
                break
            end
        end
        print("🦈 Shark di-equip kembali.")
        
        -- 14. Jeda sebentar sebelum cycle berikutnya (agar mimic sempat cooldown)
        print("⏳ Tunggu 0.5 detik sebelum cycle berikutnya...")
        task.wait(0.5)
    end
    
    print("🏁 Auto Shark loop selesai.")
    cleanupNotificationListener()
    runClearGarden()
end

-- ============================================================
-- 15. START / STOP
-- ============================================================
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
        print("⏹️ Auto Shark dihentikan.")
    end
    cleanupNotificationListener()
    runClearGarden()
end

-- ============================================================
-- 16. TOGGLE START/STOP
-- ============================================================
local isRunning = MyConfig:Get("is_running") or false

local toggleStartStop = ActionSection:Toggle({
    Title = "Start / Stop",
    Value = isRunning,
    Flag = "is_running",
    Callback = function(value)
        MyConfig:Set("is_running", value)
        MyConfig:Save()
        if value then
            print("▶️ Toggle: ON")
            startAutoShark()
        else
            print("⏹️ Toggle: OFF")
            stopAutoShark()
        end
    end
})

-- ============================================================
-- 17. TOMBOL LAINNYA
-- ============================================================
ActionSection:Space()

ActionSection:Button({
    Title = "Refresh Pet Tumbal",
    Justify = "Center",
    Callback = function()
        local currentMut = dropdownTargetMutasi:GetValue()
        updateTumbalDropdown(currentMut)
        print("🔄 Pet tumbal diperbarui manual")
    end
})

ActionSection:Space()

ActionSection:Button({
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
        dropdownTimShark:Set(keepUUIDs)

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
        dropdownPetTarget:Set(keepTargetUUIDs)

        local newMuts = getMutationList()
        local newMutOpts = {}
        for _, m in ipairs(newMuts) do
            table.insert(newMutOpts, { Title = m, Value = m })
        end
        dropdownTargetMutasi:Refresh(newMutOpts)
        local currentMut = MyConfig:Get("target_mutasi") or defaultMutation
        if table.find(newMuts, currentMut) then
            dropdownTargetMutasi:Set(currentMut)
        else
            dropdownTargetMutasi:Set(newMuts[1] or "Normal")
        end

        updateTumbalDropdown(dropdownTargetMutasi:GetValue())
        print("🔄 Semua data pet di-refresh!")
    end
})

-- ============================================================
-- 18. TOMBOL SAVE & LOAD CONFIG
-- ============================================================
local ConfigSection = TabAutoShark:Section({ Title = "Config" })

ConfigSection:Button({
    Title = "Simpan Konfigurasi",
    Justify = "Center",
    Callback = function()
        MyConfig:Save()
        print("💾 Konfigurasi disimpan!")
    end
})

ConfigSection:Space()

ConfigSection:Button({
    Title = "Muat Konfigurasi",
    Justify = "Center",
    Callback = function()
        MyConfig:Load()
        print("📂 Konfigurasi dimuat!")
        local loadedShark = MyConfig:Get("tim_shark_uuids") or {}
        dropdownTimShark:Set(loadedShark)
        local loadedTarget = MyConfig:Get("pet_target_uuids") or {}
        dropdownPetTarget:Set(loadedTarget)
        local loadedMut = MyConfig:Get("target_mutasi") or defaultMutation
        dropdownTargetMutasi:Set(loadedMut)
        updateTumbalDropdown(loadedMut)
        local loadedRunning = MyConfig:Get("is_running") or false
        toggleStartStop:Set(loadedRunning)
        print("✅ Semua nilai dimuat dari config!")
    end
})

-- ============================================================
-- 19. SIMPAN DAN TAMPILKAN
-- ============================================================
MyConfig:Save()

print("🚀 Pria Solo HUB - Auto Shark Tab siap digunakan!")

if MyConfig:Get("is_running") then
    toggleStartStop:Set(true)
end

-- ============================================================
-- SCRIPT: Pria Solo HUB - Auto Shark Tab (WindUI + ConfigManager)
-- Logika Auto Shark dengan CFrame untuk equip pet
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
-- 3. FUNGSI BANTUAN
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
-- 4. BUAT WINDOW DAN CONFIG MANAGER
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
-- 5. TAB AUTO SHARK
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
    Callback = function(selectedUUIDs)
        MyConfig:Set("tim_shark_uuids", selectedUUIDs)
        MyConfig:Save()
        print("Tim Shark UUIDs tersimpan:", table.concat(selectedUUIDs, ", "))
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
    Callback = function(selectedUUIDs)
        MyConfig:Set("pet_target_uuids", selectedUUIDs)
        MyConfig:Save()
        print("Pet Target UUIDs tersimpan:", table.concat(selectedUUIDs, ", "))
    end
})

SettingsSection:Space()

-- ========== DROPDOWN 3: Target Mutasi (default Blossoming) ==========
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
        MyConfig:Set("target_mutasi", selected)
        MyConfig:Save()
        print("Target Mutasi tersimpan:", selected)
        updateTumbalDropdown(selected)
    end
})

SettingsSection:Space()

-- ========== DROPDOWN 4: Pet Tumbal (dinamis) ==========
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
    Callback = function(selectedUUIDs)
        MyConfig:Set("pet_tumbal_uuids", selectedUUIDs)
        MyConfig:Save()
        print("Pet Tumbal UUIDs tersimpan:", table.concat(selectedUUIDs, ", "))
    end
})

tumbalDropdownObject = dropdownPetTumbal

-- ============================================================
-- 6. SECTION TOMBOL AKSI
-- ============================================================
local ActionSection = TabAutoShark:Section({ Title = "Actions" })

-- ============================================================
-- 7. FUNGSI UNTUK EQUIP/UNEQUIP VIA REMOTE (DENGAN CFrame)
-- ============================================================
local PetsService = game:GetService("ReplicatedStorage"):FindFirstChild("GameEvents"):FindFirstChild("PetsService")
local Player = game.Players.LocalPlayer

local function getEquipCFrame()
    -- Ambil posisi pemain sebagai default CFrame untuk equip pet
    if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        return Player.Character.HumanoidRootPart.CFrame
    else
        -- Fallback: posisi default di (0, 0, 0) dengan rotasi identitas
        return CFrame.new(0, 0, 0)
    end
end

local function equipPet(uuid)
    if not PetsService or uuid == "" then return end
    local cframe = getEquipCFrame()
    PetsService:FireServer("EquipPet", uuid, cframe)
    print("Equip pet:", uuid, "at", cframe.Position)
end

local function unequipPet(uuid)
    if not PetsService or uuid == "" then return end
    PetsService:FireServer("UnequipPet", uuid)
    print("Unequip pet:", uuid)
end

-- ============================================================
-- 8. FUNGSI CLEAR GARDEN (unequip semua pet terpasang)
-- ============================================================
local function runClearGarden()
    print("ClearGarden: Memulai proses...")
    local equipped = DataPetModule.getEquippedPets()
    if not equipped or next(equipped) == nil then
        print("ClearGarden: Tidak ada pet terpasang.")
        return
    end
    
    local uuids = {}
    for uuid, _ in pairs(equipped) do
        table.insert(uuids, uuid)
    end
    print("ClearGarden: Menemukan " .. #uuids .. " pet terpasang.")
    
    for i, uuid in ipairs(uuids) do
        unequipPet(uuid)
        if i < #uuids then
            task.wait(0.6)
        end
    end
    print("ClearGarden: Selesai.")
end

-- ============================================================
-- 9. FUNGSI PENGECEKAN MUTASI TARGET
-- ============================================================
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

-- ============================================================
-- 10. FUNGSI UNTUK MENDETEKSI MIMIC & SHARK
-- ============================================================
local function getMimicUUID(equipped)
    for uuid, _ in pairs(equipped) do
        local cd = DataPetModule.getCooldown(uuid)
        if cd and cd > 0 then
            return uuid
        end
    end
    return nil
end

local function getSharkUUID(equipped, timSharkUUIDs, mimicUUID)
    for _, uuid in ipairs(timSharkUUIDs) do
        if equipped[uuid] and uuid ~= mimicUUID then
            return uuid
        end
    end
    return nil
end

-- ============================================================
-- 11. LOGIKA AUTO SHARK (target diulang sampai berhasil)
-- ============================================================
local autoSharkCoroutine = nil
local isAutoSharkRunning = false
local targetQueue = {}
local currentTarget = nil
local currentTumbal = nil
local tumbalIndex = 1

local function prepareTargetQueue()
    local targets = MyConfig:Get("pet_target_uuids") or {}
    local targetMut = MyConfig:Get("target_mutasi") or "Blossoming"
    targetQueue = {}
    for _, uuid in ipairs(targets) do
        if not checkTargetMutation(uuid, targetMut) then
            table.insert(targetQueue, uuid)
        else
            print("Target", uuid, "sudah memiliki mutasi", targetMut, "di-skip")
        end
    end
    print("Antrian target:", table.concat(targetQueue, ", "))
end

local function getNextTumbal()
    local tumbalList = MyConfig:Get("pet_tumbal_uuids") or {}
    if #tumbalList == 0 then
        return nil
    end
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
        print("Tidak ada target yang perlu diproses (semua sudah memiliki mutasi atau tidak ada target).")
        return
    end
    
    local timSharkUUIDs = MyConfig:Get("tim_shark_uuids") or {}
    if #timSharkUUIDs < 2 then
        print("Tim shark harus terdiri dari minimal 2 pet (mimic dan shark).")
        return
    end
    for _, uuid in ipairs(timSharkUUIDs) do
        equipPet(uuid)
        task.wait(0.3)
    end
    
    print("Menunggu mimic ready...")
    local mimic = nil
    local cooldown = nil
    repeat
        task.wait(0.5)
        local equipped = DataPetModule.getEquippedPets()
        mimic = getMimicUUID(equipped)
        if mimic then
            cooldown = DataPetModule.getCooldown(mimic) or 0
            print("Cooldown mimic:", cooldown)
        else
            print("Mimic belum terdeteksi, mungkin belum ter-equip.")
        end
    until (cooldown and cooldown == 0) or not isAutoSharkRunning
    if not isAutoSharkRunning then return end
    print("Mimic siap (cooldown 0).")
    
    currentTarget = table.remove(targetQueue, 1)
    if not currentTarget then
        print("Tidak ada target.")
        return
    end
    currentTumbal = getNextTumbal()
    if not currentTumbal then
        print("Tidak ada tumbal.")
        return
    end
    
    while isAutoSharkRunning and #targetQueue >= 0 do
        local equipped = DataPetModule.getEquippedPets()
        mimic = getMimicUUID(equipped)
        if not mimic then
            print("Mimic hilang, hentikan siklus.")
            break
        end
        
        local shark = getSharkUUID(equipped, timSharkUUIDs, mimic)
        if shark then
            unequipPet(shark)
        else
            print("Shark tidak ditemukan, mungkin sudah tidak terpasang.")
        end
        
        print("Target saat ini:", currentTarget)
        print("Tumbal saat ini:", currentTumbal)
        
        equipPet(currentTarget)
        equipPet(currentTumbal)
        task.wait(0.5)
        
        local targetMut = MyConfig:Get("target_mutasi") or "Blossoming"
        local targetUnequipped = false
        local sharkEquipped = false
        
        while isAutoSharkRunning do
            local currentCooldown = DataPetModule.getCooldown(mimic) or 0
            print("Cooldown mimic:", currentCooldown)
            
            if currentCooldown <= 10 and not targetUnequipped then
                unequipPet(currentTarget)
                unequipPet(currentTumbal)
                targetUnequipped = true
                print("Unequip target & tumbal pada cooldown 10.")
                task.wait(2)
                local success = checkTargetMutation(currentTarget, targetMut)
                if success then
                    print("Target", currentTarget, "BERHASIL mendapatkan mutasi", targetMut)
                    if #targetQueue > 0 then
                        currentTarget = table.remove(targetQueue, 1)
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
                end
            end
            
            if currentCooldown <= 7 and not sharkEquipped then
                local timShark = MyConfig:Get("tim_shark_uuids") or {}
                for _, uuid in ipairs(timShark) do
                    if uuid ~= mimic then
                        equipPet(uuid)
                        break
                    end
                end
                sharkEquipped = true
                print("Equip shark kembali pada cooldown 7.")
            end
            
            if currentCooldown == 0 then
                print("Mimic siap, siklus selesai.")
                break
            end
            
            task.wait(0.2)
        end
        
        if not currentTarget then
            break
        end
        task.wait(1)
    end
    
    print("Auto Shark loop selesai.")
    runClearGarden()
end

-- ============================================================
-- 12. START / STOP AUTO SHARK
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
        print("Auto Shark dihentikan.")
    end
    runClearGarden()
end

-- ============================================================
-- 13. TOGGLE START/STOP
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
            print("Toggle: ON")
            startAutoShark()
        else
            print("Toggle: OFF")
            stopAutoShark()
        end
    end
})

-- ============================================================
-- 14. TOMBOL LAINNYA
-- ============================================================
ActionSection:Space()

ActionSection:Button({
    Title = "Refresh Pet Tumbal",
    Justify = "Center",
    Callback = function()
        local currentMut = dropdownTargetMutasi:GetValue()
        updateTumbalDropdown(currentMut)
        print("Pet tumbal diperbarui manual")
    end
})

ActionSection:Space()

ActionSection:Button({
    Title = "Refresh Semua Data Pet",
    Justify = "Center",
    Callback = function()
        -- Refresh Tim Shark
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

        -- Refresh Pet Target
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

        -- Refresh Target Mutasi
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

        -- Refresh Tumbal
        updateTumbalDropdown(dropdownTargetMutasi:GetValue())

        print("Semua data pet di-refresh!")
    end
})

-- ============================================================
-- 15. TOMBOL SAVE & LOAD CONFIG
-- ============================================================
local ConfigSection = TabAutoShark:Section({ Title = "Config" })

ConfigSection:Button({
    Title = "Simpan Konfigurasi",
    Justify = "Center",
    Callback = function()
        MyConfig:Save()
        print("Konfigurasi disimpan!")
    end
})

ConfigSection:Space()

ConfigSection:Button({
    Title = "Muat Konfigurasi",
    Justify = "Center",
    Callback = function()
        MyConfig:Load()
        print("Konfigurasi dimuat!")
        local loadedShark = MyConfig:Get("tim_shark_uuids") or {}
        dropdownTimShark:Set(loadedShark)
        local loadedTarget = MyConfig:Get("pet_target_uuids") or {}
        dropdownPetTarget:Set(loadedTarget)
        local loadedMut = MyConfig:Get("target_mutasi") or defaultMutation
        dropdownTargetMutasi:Set(loadedMut)
        updateTumbalDropdown(loadedMut)
        local loadedRunning = MyConfig:Get("is_running") or false
        toggleStartStop:Set(loadedRunning)
        print("Semua nilai dimuat dari config!")
    end
})

-- ============================================================
-- 16. SIMPAN DAN TAMPILKAN
-- ============================================================
MyConfig:Save()

print("Pria Solo HUB - Auto Shark Tab siap digunakan!")

if MyConfig:Get("is_running") then
    toggleStartStop:Set(true)
end

-- ============================================================
-- SCRIPT: Pria Solo HUB - Auto Shark Tab (WindUI + ConfigManager)
-- Perbaikan: State tersimpan di JSON dengan ConfigManager
-- Default Target Mutasi: Blossoming
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

-- Ambil daftar mutasi unik
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

-- Format tampilan pet
local function formatPetDisplay(pet)
    return string.format("%s [%s] Lv.%d", pet.name, pet.mutation, pet.level)
end

-- Bangun opsi dropdown: {Title = display, Value = uuid}
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
    Folder = "PriaSoloHUB",  -- Folder tempat menyimpan config
    Size = UDim2.new(0, 400, 0, 600),
    Center = true,
    AutoShow = true,
    Draggable = true,
})

-- Buat config file
local MyConfig = Window.ConfigManager:Config("AutoSharkConfig")
-- Load config yang sudah ada (jika ada)
MyConfig:Load()

-- ============================================================
-- 5. TAB AUTO SHARK (pertama)
-- ============================================================
local TabAutoShark = Window:Tab({
    Title = "Auto Shark",
    Icon = "solar:shark-bold",
})

local SettingsSection = TabAutoShark:Section({ Title = "Auto Shark Settings" })

-- ============================================================
-- 6. DROPDOWN 1: Pilih Tim Shark (Multi-Select + Search)
-- ============================================================
local sharkPets = DataPetModule.findPets({ isFavorite = true })
local sharkOptions = buildDropdownOptions(sharkPets)

-- Ambil nilai default dari config (list UUID)
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

-- ============================================================
-- 7. DROPDOWN 2: Pilih Pet Target (Multi-Select + Search)
-- ============================================================
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

-- ============================================================
-- 8. DROPDOWN 3: Pilih Target Mutasi (Single-Select, tanpa search)
-- DEFAULT: Blossoming
-- ============================================================
local mutationList = getMutationList()
local mutOptions = {}
for _, m in ipairs(mutationList) do
    table.insert(mutOptions, { Title = m, Value = m })
end

-- Tentukan default: "Blossoming" jika ada
local defaultMutation = "Blossoming"
if not table.find(mutationList, defaultMutation) then
    defaultMutation = mutationList[1] or "Normal"
end
-- Ambil dari config jika sudah tersimpan
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

-- ============================================================
-- 9. DROPDOWN 4: Pilih Pet Tumbal (Multi-Select + Search)
--    Dinamis berdasarkan mutasi yang dipilih
-- ============================================================
local tumbalOptions = {}
local tumbalDropdownObject = nil

-- Fungsi untuk memperbarui dropdown tumbal
local function updateTumbalDropdown(mutation)
    print("updateTumbalDropdown dipanggil dengan mutasi:", mutation)
    
    -- Ambil pet dengan mutasi tertentu dan bukan favorit
    local tumbalPets = DataPetModule.findPets({
        isFavorite = false,
        mutation = mutation
    })
    
    print("Jumlah pet tumbal ditemukan:", #tumbalPets)
    if #tumbalPets > 0 then
        print("Contoh pet pertama:", tumbalPets[1].name, tumbalPets[1].mutation)
    end
    
    -- Buat opsi baru
    local newOptions = buildDropdownOptions(tumbalPets)
    tumbalOptions = newOptions
    
    -- Ambil UUID yang tersimpan sebelumnya
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
    
    -- Jika tidak ada yang valid dan ada opsi, pilih opsi pertama
    if #validUUIDs == 0 and #newOptions > 0 and newOptions[1].Value ~= "" then
        table.insert(validUUIDs, newOptions[1].Value)
    end
    
    -- Perbarui dropdown
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

-- Inisialisasi tumbal dengan mutasi default
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
-- 10. SECTION TOMBOL AKSI
-- ============================================================
local ActionSection = TabAutoShark:Section({ Title = "Actions" })

-- Toggle Start/Stop
local isRunning = MyConfig:Get("is_running") or false

local toggleStartStop = ActionSection:Toggle({
    Title = "Start / Stop",
    Value = isRunning,
    Flag = "is_running",
    Callback = function(value)
        MyConfig:Set("is_running", value)
        MyConfig:Save()
        if value then
            print("Auto Shark DIMULAI!")
            startAutoShark()
        else
            print("Auto Shark DIHENTIKAN!")
            stopAutoShark()
        end
    end
})

ActionSection:Space()

-- Tombol refresh tumbal manual
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

-- Tombol refresh semua data
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
-- 11. TOMBOL SAVE & LOAD CONFIG MANUAL (untuk memastikan)
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
        -- Refresh tampilan dropdown dengan nilai dari config
        -- Tim Shark
        local loadedShark = MyConfig:Get("tim_shark_uuids") or {}
        dropdownTimShark:Set(loadedShark)
        -- Pet Target
        local loadedTarget = MyConfig:Get("pet_target_uuids") or {}
        dropdownPetTarget:Set(loadedTarget)
        -- Target Mutasi
        local loadedMut = MyConfig:Get("target_mutasi") or defaultMutation
        dropdownTargetMutasi:Set(loadedMut)
        -- Tumbal
        updateTumbalDropdown(loadedMut)
        -- Toggle
        local loadedRunning = MyConfig:Get("is_running") or false
        toggleStartStop:Set(loadedRunning)
        print("Semua nilai dimuat dari config!")
    end
})

-- ============================================================
-- 12. FUNGSI START/STOP (contoh)
-- ============================================================
local autoSharkCoroutine = nil

local function startAutoShark()
    if autoSharkCoroutine then return end
    autoSharkCoroutine = coroutine.create(function()
        while MyConfig:Get("is_running") do
            local timShark = MyConfig:Get("tim_shark_uuids") or {}
            local petTarget = MyConfig:Get("pet_target_uuids") or {}
            local petTumbal = MyConfig:Get("pet_tumbal_uuids") or {}
            local targetMutasi = MyConfig:Get("target_mutasi") or "Normal"

            print("=== AUTO SHARK RUNNING ===")
            print("Tim Shark:", table.concat(timShark, ", "))
            print("Pet Target:", table.concat(petTarget, ", "))
            print("Pet Tumbal:", table.concat(petTumbal, ", "))
            print("Target Mutasi:", targetMutasi)

            task.wait(5)
        end
    end)
    coroutine.resume(autoSharkCoroutine)
end

local function stopAutoShark()
    if autoSharkCoroutine then
        autoSharkCoroutine = nil
        print("Auto Shark dihentikan.")
    end
end

-- ============================================================
-- 13. SIMPAN KONFIGURASI AWAL DAN TAMPILKAN
-- ============================================================
MyConfig:Save()

print("Pria Solo HUB - Auto Shark Tab siap digunakan!")

-- Jalankan otomatis jika sebelumnya sedang berjalan
if MyConfig:Get("is_running") then
    toggleStartStop:Set(true)
end

-- ============================================================
-- SCRIPT: Pria Solo HUB - Auto Shark Tab
-- Ukuran Window: 400x600
-- Dropdown menyimpan UUID sebagai nilai tersembunyi
-- ============================================================

-- ============================================================
-- 1. LOAD DataPetModule dari GitHub
-- ============================================================
local DataPetModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/DataPetModule.lua"))()
if not DataPetModule then error("Gagal memuat DataPetModule!") end

-- ============================================================
-- 2. LOAD LinoriaLib
-- ============================================================
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()
if not Library then error("Gagal memuat LinoriaLib!") end

-- ============================================================
-- 3. FUNGSI BANTUAN
-- ============================================================

-- Ambil daftar mutasi unik dari data pet
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

-- Format string pet untuk ditampilkan di dropdown
local function formatPetString(petInfo)
    return string.format(
        "%s [%s] | Lv.%d | %.2f kg",
        petInfo.name,
        petInfo.mutation,
        petInfo.level,
        petInfo.weight
    )
end

-- Buat options untuk dropdown dari daftar petInfo, mengembalikan {options, mapLabelToUUID}
local function buildPetOptions(petInfos)
    local options = {}
    local labelToUUID = {}
    for _, pet in ipairs(petInfos) do
        local label = formatPetString(pet)
        table.insert(options, label)
        labelToUUID[label] = pet.uuid
    end
    if #options == 0 then
        table.insert(options, "Tidak ada data")
        labelToUUID["Tidak ada data"] = nil
    end
    return options, labelToUUID
end

-- ============================================================
-- 4. BUAT WINDOW (400x600) & TAB
-- ============================================================
local Window = Library:CreateWindow({
    Title = "Pria Solo HUB",
    Center = true,
    AutoShow = true,
    Size = UDim2.new(0, 400, 0, 600), -- ukuran 400x600
    TabPadding = 8,
})

local TabAutoShark = Window:AddTab("Auto Shark")

-- ============================================================
-- 5. DROPDOWN "Pilih Tim Shark" (favorit = true)
-- ============================================================
local timSharkPets = DataPetModule.findPets({ isFavorite = true })
local sharkOptions, sharkMap = buildPetOptions(timSharkPets)
local dropdownTimShark = TabAutoShark:AddDropdown({
    Name = "Pilih Tim Shark",
    Options = sharkOptions,
    Default = sharkOptions[1],
    Callback = function(value)
        local uuid = sharkMap[value]
        -- Simpan UUID yang dipilih ke variabel global atau lakukan aksi
        _G.SelectedSharkUUID = uuid
        print("Tim Shark UUID:", uuid)
    end
})
-- Set default UUID
_G.SelectedSharkUUID = sharkMap[sharkOptions[1]]

-- ============================================================
-- 6. DROPDOWN "Pilih Pet Target" (favorit = false, mutasi Normal)
-- ============================================================
local targetPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = "Normal"
})
local targetOptions, targetMap = buildPetOptions(targetPets)
local dropdownPetTarget = TabAutoShark:AddDropdown({
    Name = "Pilih Pet Target",
    Options = targetOptions,
    Default = targetOptions[1],
    Callback = function(value)
        local uuid = targetMap[value]
        _G.SelectedTargetUUID = uuid
        print("Target UUID:", uuid)
    end
})
_G.SelectedTargetUUID = targetMap[targetOptions[1]]

-- ============================================================
-- 7. DROPDOWN "Pilih Target Mutasi" (daftar semua mutasi)
-- ============================================================
local mutationOptions = getMutationList()
local dropdownTargetMutasi = TabAutoShark:AddDropdown({
    Name = "Pilih Target Mutasi",
    Options = mutationOptions,
    Default = mutationOptions[1] or "Normal",
    Callback = function(value)
        _G.SelectedMutation = value
        updateTumbalDropdown(value)
    end
})
_G.SelectedMutation = dropdownTargetMutasi:GetValue() or "Normal"

-- ============================================================
-- 8. DROPDOWN "Pilih Pet Tumbal" (favorit = false, mutasi sesuai pilihan)
-- ============================================================
local tumbalMap = {} -- akan diisi saat update
local dropdownPetTumbal -- deklarasi dulu

local function updateTumbalDropdown(mutation)
    local tumbalPets = DataPetModule.findPets({
        isFavorite = false,
        mutation = mutation
    })
    local options, map = buildPetOptions(tumbalPets)
    tumbalMap = map
    if dropdownPetTumbal then
        dropdownPetTumbal:SetOptions(options)
        dropdownPetTumbal:SetValue(options[1])
    end
    _G.SelectedTumbalUUID = map[options[1]]
    print("Tumbal UUID updated:", _G.SelectedTumbalUUID)
end

-- Inisialisasi dropdown pet tumbal
local initialMutation = dropdownTargetMutasi:GetValue() or "Normal"
local initialTumbalPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = initialMutation
})
local initialTumbalOptions, initialTumbalMap = buildPetOptions(initialTumbalPets)
tumbalMap = initialTumbalMap

dropdownPetTumbal = TabAutoShark:AddDropdown({
    Name = "Pilih Pet Tumbal",
    Options = initialTumbalOptions,
    Default = initialTumbalOptions[1],
    Callback = function(value)
        local uuid = tumbalMap[value]
        _G.SelectedTumbalUUID = uuid
        print("Tumbal UUID:", uuid)
    end
})
_G.SelectedTumbalUUID = initialTumbalMap[initialTumbalOptions[1]]

-- ============================================================
-- 9. TOMBOL DEBUG / START
-- ============================================================
TabAutoShark:AddButton({
    Name = "Tampilkan Pilihan Saat Ini",
    Callback = function()
        print("=== Pilihan Auto Shark ===")
        print("Tim Shark UUID   :", _G.SelectedSharkUUID)
        print("Target UUID      :", _G.SelectedTargetUUID)
        print("Tumbal UUID      :", _G.SelectedTumbalUUID)
        print("Target Mutasi    :", _G.SelectedMutation)
    end
})

TabAutoShark:AddButton({
    Name = "Refresh Data Pet",
    Callback = function()
        -- Refresh Tim Shark
        local newShark = DataPetModule.findPets({ isFavorite = true })
        local newSharkOpts, newSharkMap = buildPetOptions(newShark)
        sharkMap = newSharkMap
        dropdownTimShark:SetOptions(newSharkOpts)
        dropdownTimShark:SetValue(newSharkOpts[1])
        _G.SelectedSharkUUID = newSharkMap[newSharkOpts[1]]

        -- Refresh Target
        local newTarget = DataPetModule.findPets({ isFavorite = false, mutation = "Normal" })
        local newTargetOpts, newTargetMap = buildPetOptions(newTarget)
        targetMap = newTargetMap
        dropdownPetTarget:SetOptions(newTargetOpts)
        dropdownPetTarget:SetValue(newTargetOpts[1])
        _G.SelectedTargetUUID = newTargetMap[newTargetOpts[1]]

        -- Refresh Mutasi
        local newMutations = getMutationList()
        dropdownTargetMutasi:SetOptions(newMutations)
        local defaultMut = newMutations[1] or "Normal"
        dropdownTargetMutasi:SetValue(defaultMut)
        _G.SelectedMutation = defaultMut

        -- Refresh Tumbal
        updateTumbalDropdown(defaultMut)

        print("Data pet berhasil di-refresh!")
    end
})

-- ============================================================
-- 10. SETUP THEME & SAVE MANAGER (opsional)
-- ============================================================
local UISettingsTab = Window:AddTab("UI Settings")
UISettingsTab:AddButton({
    Name = "Theme Manager",
    Callback = function()
        ThemeManager:SetTheme("Dark")
        ThemeManager:OpenThemeMenu()
    end
})
UISettingsTab:AddButton({
    Name = "Save Config",
    Callback = function() SaveManager:SaveConfig() end
})
UISettingsTab:AddButton({
    Name = "Load Config",
    Callback = function() SaveManager:LoadConfig() end
})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

-- ============================================================
-- 11. INISIALISASI AWAL
-- ============================================================
updateTumbalDropdown(dropdownTargetMutasi:GetValue() or "Normal")

print("Pria Solo HUB - Auto Shark Tab siap digunakan!")
print("Window size: 400x600")
print("UUID tersimpan di _G.SelectedSharkUUID, _G.SelectedTargetUUID, _G.SelectedTumbalUUID, _G.SelectedMutation")

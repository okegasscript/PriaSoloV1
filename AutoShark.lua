-- ============================================================
-- SCRIPT: Pria Solo HUB - Auto Shark Tab
-- Menggunakan DataPetModule dari GitHub & LinoriaLib
-- ============================================================

-- ============================================================
-- 1. LOAD DataPetModule dari GitHub
-- ============================================================
local DataPetModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/DataPetModule.lua"))()

if not DataPetModule then
    error("Gagal memuat DataPetModule dari GitHub!")
end

-- ============================================================
-- 2. LOAD LinoriaLib
-- ============================================================
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

if not Library then
    error("Gagal memuat LinoriaLib!")
end

-- ============================================================
-- 3. KONSTANTA & FUNGSI BANTUAN
-- ============================================================

-- Ambil daftar mutasi unik dari MUTATION_MAP di DataPetModule
-- (tidak perlu menduplikasi, kita ambil langsung dari module)
local function getMutationList()
    -- Kita baca MUTATION_MAP dari module yang sudah di-load
    -- Karena MUTATION_MAP adalah local di module, kita ambil via fungsi yang sudah tersedia
    local mutations = {}
    -- DataPetModule tidak mengekspos MUTATION_MAP langsung, jadi kita generate dari findPets
    local allPets = DataPetModule.getAllPets()
    for _, pet in pairs(allPets) do
        local petData = pet.PetData or {}
        local rawMut = petData.MutationType or "Normal"
        local mutName = DataPetModule.getAutoMutationName(rawMut)
        if mutName and mutName ~= "" and not table.find(mutations, mutName) then
            table.insert(mutations, mutName)
        end
    end
    -- Pastikan "Normal" selalu ada
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

-- ============================================================
-- 4. BUAT WINDOW & TAB
-- ============================================================
local Window = Library:CreateWindow({
    Title = "Pria Solo HUB",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
})

local TabAutoShark = Window:AddTab("Auto Shark")

-- ============================================================
-- 5. DROPDOWN "Pilih Tim Shark" (favorit = true)
-- ============================================================
local timSharkPets = DataPetModule.findPets({ isFavorite = true })
local timSharkOptions = {}
for _, pet in ipairs(timSharkPets) do
    table.insert(timSharkOptions, formatPetString(pet))
end
if #timSharkOptions == 0 then
    table.insert(timSharkOptions, "Tidak ada pet favorit")
end

local dropdownTimShark = TabAutoShark:AddDropdown({
    Name = "Pilih Tim Shark",
    Options = timSharkOptions,
    Default = timSharkOptions[1],
})

-- ============================================================
-- 6. DROPDOWN "Pilih Pet Target" (favorit = false, mutasi Normal)
-- ============================================================
local targetPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = "Normal"
})
local targetOptions = {}
for _, pet in ipairs(targetPets) do
    table.insert(targetOptions, formatPetString(pet))
end
if #targetOptions == 0 then
    table.insert(targetOptions, "Tidak ada pet target")
end

local dropdownPetTarget = TabAutoShark:AddDropdown({
    Name = "Pilih Pet Target",
    Options = targetOptions,
    Default = targetOptions[1],
})

-- ============================================================
-- 7. DROPDOWN "Pilih Target Mutasi" (daftar semua mutasi)
-- ============================================================
local mutationOptions = getMutationList()

local dropdownTargetMutasi = TabAutoShark:AddDropdown({
    Name = "Pilih Target Mutasi",
    Options = mutationOptions,
    Default = mutationOptions[1] or "Normal",
    Callback = function(value)
        updateTumbalDropdown(value)
    end
})

-- ============================================================
-- 8. DROPDOWN "Pilih Pet Tumbal" (favorit = false, mutasi sesuai pilihan)
-- ============================================================
local function updateTumbalDropdown(mutation)
    local tumbalPets = DataPetModule.findPets({
        isFavorite = false,
        mutation = mutation
    })
    local options = {}
    for _, pet in ipairs(tumbalPets) do
        table.insert(options, formatPetString(pet))
    end
    if #options == 0 then
        table.insert(options, "Tidak ada pet tumbal")
    end
    dropdownPetTumbal:SetOptions(options)
    dropdownPetTumbal:SetValue(options[1])
end

-- Buat dropdown dengan opsi awal
local initialMutation = dropdownTargetMutasi:GetValue() or "Normal"
local initialTumbalPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = initialMutation
})
local initialTumbalOptions = {}
for _, pet in ipairs(initialTumbalPets) do
    table.insert(initialTumbalOptions, formatPetString(pet))
end
if #initialTumbalOptions == 0 then
    table.insert(initialTumbalOptions, "Tidak ada pet tumbal")
end

local dropdownPetTumbal = TabAutoShark:AddDropdown({
    Name = "Pilih Pet Tumbal",
    Options = initialTumbalOptions,
    Default = initialTumbalOptions[1],
})

-- ============================================================
-- 9. TOMBOL DEBUG / START
-- ============================================================
TabAutoShark:AddButton({
    Name = "Tampilkan Pilihan Saat Ini",
    Callback = function()
        local shark = dropdownTimShark:GetValue()
        local target = dropdownPetTarget:GetValue()
        local tumbal = dropdownPetTumbal:GetValue()
        local mutasi = dropdownTargetMutasi:GetValue()

        print("=== Pilihan Auto Shark ===")
        print("Tim Shark    : " .. shark)
        print("Pet Target   : " .. target)
        print("Pet Tumbal   : " .. tumbal)
        print("Target Mutasi: " .. mutasi)
    end
})

TabAutoShark:AddButton({
    Name = "Refresh Data Pet",
    Callback = function()
        -- Refresh semua dropdown
        -- Tim Shark
        local newShark = DataPetModule.findPets({ isFavorite = true })
        local newSharkOpts = {}
        for _, pet in ipairs(newShark) do
            table.insert(newSharkOpts, formatPetString(pet))
        end
        if #newSharkOpts == 0 then
            table.insert(newSharkOpts, "Tidak ada pet favorit")
        end
        dropdownTimShark:SetOptions(newSharkOpts)
        dropdownTimShark:SetValue(newSharkOpts[1])

        -- Pet Target
        local newTarget = DataPetModule.findPets({
            isFavorite = false,
            mutation = "Normal"
        })
        local newTargetOpts = {}
        for _, pet in ipairs(newTarget) do
            table.insert(newTargetOpts, formatPetString(pet))
        end
        if #newTargetOpts == 0 then
            table.insert(newTargetOpts, "Tidak ada pet target")
        end
        dropdownPetTarget:SetOptions(newTargetOpts)
        dropdownPetTarget:SetValue(newTargetOpts[1])

        -- Target Mutasi (refresh daftar mutasi)
        local newMutations = getMutationList()
        dropdownTargetMutasi:SetOptions(newMutations)
        dropdownTargetMutasi:SetValue(newMutations[1] or "Normal")

        -- Pet Tumbal (ikut refresh)
        updateTumbalDropdown(dropdownTargetMutasi:GetValue() or "Normal")

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
    Callback = function()
        SaveManager:SaveConfig()
    end
})

UISettingsTab:AddButton({
    Name = "Load Config",
    Callback = function()
        SaveManager:LoadConfig()
    end
})

-- Inisialisasi ThemeManager & SaveManager
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

-- ============================================================
-- 11. INISIALISASI AWAL
-- ============================================================
updateTumbalDropdown(dropdownTargetMutasi:GetValue() or "Normal")

print("Pria Solo HUB - Auto Shark Tab siap digunakan!")

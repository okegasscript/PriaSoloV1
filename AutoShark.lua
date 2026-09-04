-- ============================================================
-- SCRIPT: Pria Solo HUB - Auto Shark Tab (Ukuran 400x600)
-- DataPetModule dari GitHub, LinoriaLib
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

-- Ambil daftar mutasi unik dari data pet yang ada
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

-- Format teks pet untuk ditampilkan
local function formatPetText(petInfo)
    return string.format(
        "%s [%s] | Lv.%d | %.2f kg",
        petInfo.name,
        petInfo.mutation,
        petInfo.level,
        petInfo.weight
    )
end

-- Buat opsi dropdown: list of { Text = "...", UUID = "..." }
local function buildDropdownOptions(petList)
    local options = {}
    for _, pet in ipairs(petList) do
        table.insert(options, {
            Text = formatPetText(pet),
            UUID = pet.uuid
        })
    end
    if #options == 0 then
        table.insert(options, { Text = "Tidak ada pet", UUID = "" })
    end
    return options
end

-- Ambil UUID dari teks yang dipilih (mencocokkan)
local function getUUIDFromText(dropdownOptions, selectedText)
    for _, opt in ipairs(dropdownOptions) do
        if opt.Text == selectedText then
            return opt.UUID
        end
    end
    return nil
end

-- ============================================================
-- 4. BUAT WINDOW UKURAN 400x600
-- ============================================================
local Window = Library:CreateWindow({
    Title = "Pria Solo HUB",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    Size = UDim2.new(0, 400, 0, 600)  -- ukuran 400x600
})

local TabAutoShark = Window:AddTab("Auto Shark")

-- ============================================================
-- 5. DROPDOWN "Pilih Tim Shark" (favorit = true)
-- ============================================================
local timSharkPets = DataPetModule.findPets({ isFavorite = true })
local timSharkOptions = buildDropdownOptions(timSharkPets)

-- Simpan opsi asli untuk referensi UUID
local timSharkOptionsData = timSharkOptions

local dropdownTimShark = TabAutoShark:AddDropdown({
    Name = "Pilih Tim Shark",
    Options = timSharkOptions,  -- list of {Text, UUID} atau list string?
    Default = timSharkOptions[1] and timSharkOptions[1].Text or "Tidak ada pet",
    Callback = function(selectedText)
        local uuid = getUUIDFromText(timSharkOptionsData, selectedText)
        print("Tim Shark dipilih: " .. selectedText .. " | UUID: " .. tostring(uuid))
        -- Simpan UUID ke variabel global atau lakukan aksi
        _G.selectedTimSharkUUID = uuid
    end
})

-- ============================================================
-- 6. DROPDOWN "Pilih Pet Target" (favorit = false, mutasi Normal)
-- ============================================================
local targetPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = "Normal"
})
local targetOptions = buildDropdownOptions(targetPets)
local targetOptionsData = targetOptions

local dropdownPetTarget = TabAutoShark:AddDropdown({
    Name = "Pilih Pet Target",
    Options = targetOptions,
    Default = targetOptions[1] and targetOptions[1].Text or "Tidak ada pet",
    Callback = function(selectedText)
        local uuid = getUUIDFromText(targetOptionsData, selectedText)
        print("Pet Target dipilih: " .. selectedText .. " | UUID: " .. tostring(uuid))
        _G.selectedTargetUUID = uuid
    end
})

-- ============================================================
-- 7. DROPDOWN "Pilih Target Mutasi" (daftar semua mutasi)
-- ============================================================
local mutationList = getMutationList()
local mutationOptions = {}
for _, m in ipairs(mutationList) do
    table.insert(mutationOptions, { Text = m, UUID = m }) -- UUID = nama mutasi
end

local dropdownTargetMutasi = TabAutoShark:AddDropdown({
    Name = "Pilih Target Mutasi",
    Options = mutationOptions,
    Default = mutationOptions[1] and mutationOptions[1].Text or "Normal",
    Callback = function(selectedText)
        print("Target Mutasi dipilih: " .. selectedText)
        _G.selectedMutation = selectedText
        -- Update pet tumbal sesuai mutasi
        updateTumbalDropdown(selectedText)
    end
})

-- ============================================================
-- 8. DROPDOWN "Pilih Pet Tumbal" (favorit = false, mutasi sesuai pilihan)
-- ============================================================
local tumbalOptionsData = {}

local function updateTumbalDropdown(mutation)
    local tumbalPets = DataPetModule.findPets({
        isFavorite = false,
        mutation = mutation
    })
    local options = buildDropdownOptions(tumbalPets)
    tumbalOptionsData = options
    dropdownPetTumbal:SetOptions(options)
    dropdownPetTumbal:SetValue(options[1] and options[1].Text or "Tidak ada pet")
end

-- Buat dropdown dengan opsi awal
local initialMutation = mutationList[1] or "Normal"
local initialTumbalPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = initialMutation
})
local initialTumbalOptions = buildDropdownOptions(initialTumbalPets)
tumbalOptionsData = initialTumbalOptions

local dropdownPetTumbal = TabAutoShark:AddDropdown({
    Name = "Pilih Pet Tumbal",
    Options = initialTumbalOptions,
    Default = initialTumbalOptions[1] and initialTumbalOptions[1].Text or "Tidak ada pet",
    Callback = function(selectedText)
        local uuid = getUUIDFromText(tumbalOptionsData, selectedText)
        print("Pet Tumbal dipilih: " .. selectedText .. " | UUID: " .. tostring(uuid))
        _G.selectedTumbalUUID = uuid
    end
})

-- ============================================================
-- 9. TOMBOL REFRESH & DEBUG
-- ============================================================
TabAutoShark:AddButton({
    Name = "Tampilkan UUID Terpilih",
    Callback = function()
        print("=== UUID Terpilih ===")
        print("Tim Shark   : " .. tostring(_G.selectedTimSharkUUID))
        print("Pet Target  : " .. tostring(_G.selectedTargetUUID))
        print("Pet Tumbal  : " .. tostring(_G.selectedTumbalUUID))
        print("Target Mutasi : " .. tostring(_G.selectedMutation))
    end
})

TabAutoShark:AddButton({
    Name = "Refresh Data Pet",
    Callback = function()
        -- Refresh Tim Shark
        local newShark = DataPetModule.findPets({ isFavorite = true })
        local newOpts = buildDropdownOptions(newShark)
        timSharkOptionsData = newOpts
        dropdownTimShark:SetOptions(newOpts)
        dropdownTimShark:SetValue(newOpts[1] and newOpts[1].Text or "Tidak ada pet")

        -- Refresh Pet Target
        local newTarget = DataPetModule.findPets({ isFavorite = false, mutation = "Normal" })
        local newTargetOpts = buildDropdownOptions(newTarget)
        targetOptionsData = newTargetOpts
        dropdownPetTarget:SetOptions(newTargetOpts)
        dropdownPetTarget:SetValue(newTargetOpts[1] and newTargetOpts[1].Text or "Tidak ada pet")

        -- Refresh Target Mutasi
        local newMutations = getMutationList()
        local newMutOpts = {}
        for _, m in ipairs(newMutations) do
            table.insert(newMutOpts, { Text = m, UUID = m })
        end
        dropdownTargetMutasi:SetOptions(newMutOpts)
        dropdownTargetMutasi:SetValue(newMutOpts[1] and newMutOpts[1].Text or "Normal")

        -- Refresh Pet Tumbal (sesuai mutasi yang dipilih)
        local currentMut = dropdownTargetMutasi:GetValue() or "Normal"
        updateTumbalDropdown(currentMut)

        print("Semua data pet di-refresh!")
    end
})

-- ============================================================
-- 10. SETUP THEME & SAVE
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

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

-- ============================================================
-- 11. INISIALISASI AWAL
-- ============================================================
updateTumbalDropdown(dropdownTargetMutasi:GetValue() or "Normal")
print("Pria Solo HUB - Auto Shark Tab siap digunakan!")

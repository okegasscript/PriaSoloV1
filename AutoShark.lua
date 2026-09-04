-- ============================================================
-- SCRIPT: Pria Solo HUB - Auto Shark Tab (Ukuran 400x600)
-- Menggunakan pola LinoriaLib sesuai contoh
-- ============================================================

-- ============================================================
-- 1. LOAD DataPetModule dari GitHub
-- ============================================================
local DataPetModule = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/DataPetModule.lua"
))()
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

-- Format tampilan pet
local function formatPetDisplay(pet)
    return string.format(
        "%s [%s] | Lv.%d | %.2f kg",
        pet.name,
        pet.mutation,
        pet.level,
        pet.weight
    )
end

-- Bangun daftar value untuk dropdown (list display string) dan mapping display->uuid
local function buildDropdownData(petList)
    local displayToUUID = {}
    local values = {}
    for _, pet in ipairs(petList) do
        local display = formatPetDisplay(pet)
        -- Tambahkan UUID untuk memastikan unik jika ada nama yang sama
        display = display .. " | " .. tostring(pet.uuid):sub(1, 8)
        displayToUUID[display] = pet.uuid
        table.insert(values, display)
    end
    if #values == 0 then
        local noPet = "Tidak ada pet"
        displayToUUID[noPet] = ""
        table.insert(values, noPet)
    end
    return values, displayToUUID
end

-- ============================================================
-- 4. BUAT WINDOW UKURAN 400x600
-- ============================================================
local Window = Library:CreateWindow({
    Title = "Pria Solo HUB",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    Size = UDim2.new(0, 400, 0, 600)
})

local TabAutoShark = Window:AddTab("Auto Shark")

-- ============================================================
-- 5. DROPDOWN "Pilih Tim Shark" (favorit = true)
-- ============================================================
local sharkPets = DataPetModule.findPets({ isFavorite = true })
local sharkValues, sharkMap = buildDropdownData(sharkPets)

local dropdownTimShark = TabAutoShark:AddDropdown("TimShark", {
    Values = sharkValues,
    Default = sharkValues[1] or "",
    Multi = false,   -- single select
    Text = "Pilih Tim Shark",
    Tooltip = "Pilih pet favorit untuk tim shark"
})

-- ============================================================
-- 6. DROPDOWN "Pilih Pet Target" (favorit = false, mutasi Normal)
-- ============================================================
local targetPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = "Normal"
})
local targetValues, targetMap = buildDropdownData(targetPets)

local dropdownPetTarget = TabAutoShark:AddDropdown("PetTarget", {
    Values = targetValues,
    Default = targetValues[1] or "",
    Multi = false,
    Text = "Pilih Pet Target",
    Tooltip = "Pilih pet target (tanpa mutasi)"
})

-- ============================================================
-- 7. DROPDOWN "Pilih Target Mutasi" (daftar semua mutasi)
-- ============================================================
local mutationList = getMutationList()
local mutValues = {}
local mutMap = {}
for _, m in ipairs(mutationList) do
    mutMap[m] = m
    table.insert(mutValues, m)
end

local dropdownTargetMutasi = TabAutoShark:AddDropdown("TargetMutasi", {
    Values = mutValues,
    Default = mutValues[1] or "Normal",
    Multi = false,
    Text = "Pilih Target Mutasi",
    Tooltip = "Pilih mutasi yang diinginkan"
})

-- ============================================================
-- 8. DROPDOWN "Pilih Pet Tumbal" (favorit = false, mutasi sesuai pilihan)
-- ============================================================
-- Simpan mapping dan nilai untuk tumbal
local tumbalValues = {}
local tumbalMap = {}

-- Fungsi untuk memperbarui dropdown tumbal berdasarkan mutasi terpilih
local function updateTumbalDropdown(mutation)
    local tumbalPets = DataPetModule.findPets({
        isFavorite = false,
        mutation = mutation
    })
    local newValues, newMap = buildDropdownData(tumbalPets)
    tumbalValues = newValues
    tumbalMap = newMap
    dropdownPetTumbal:SetValues(tumbalValues)
    dropdownPetTumbal:SetValue(tumbalValues[1] or "")
end

-- Buat dropdown tumbal dengan data awal (mutasi default)
local initialMut = mutValues[1] or "Normal"
local initialTumbalPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = initialMut
})
local initVals, initMap = buildDropdownData(initialTumbalPets)
tumbalValues = initVals
tumbalMap = initMap

local dropdownPetTumbal = TabAutoShark:AddDropdown("PetTumbal", {
    Values = tumbalValues,
    Default = tumbalValues[1] or "",
    Multi = false,
    Text = "Pilih Pet Tumbal",
    Tooltip = "Pilih pet tumbal sesuai mutasi yang dipilih"
})

-- ============================================================
-- 9. EVENT HANDLER: update tumbal saat mutasi berubah
-- ============================================================
-- Karena Linoria tidak menyediakan callback langsung untuk dropdown,
-- kita bisa menggunakan sinyal atau meng-override metode Value.
-- Cara sederhana: tambahkan tombol refresh atau gunakan task.wait untuk polling.
-- Tapi lebih baik kita pasang koneksi ke peristiwa perubahan.
-- Alternatif: kita buat tombol "Update Tumbal" manual.
-- Saya akan tambahkan tombol "Refresh Tumbal" agar user bisa update manual.

TabAutoShark:AddButton({
    Name = "Refresh Pet Tumbal",
    Callback = function()
        local selectedMut = dropdownTargetMutasi:GetValue()
        updateTumbalDropdown(selectedMut)
        print("Pet tumbal diperbarui sesuai mutasi: " .. selectedMut)
    end
})

-- ============================================================
-- 10. TOMBOL DEBUG / TAMPILKAN UUID
-- ============================================================
local function getSelectedUUID(dropdownObj, map)
    local selectedText = dropdownObj:GetValue()
    return map[selectedText] or ""
end

TabAutoShark:AddButton({
    Name = "Tampilkan UUID Terpilih",
    Callback = function()
        local sharkUUID = getSelectedUUID(dropdownTimShark, sharkMap)
        local targetUUID = getSelectedUUID(dropdownPetTarget, targetMap)
        local tumbalUUID = getSelectedUUID(dropdownPetTumbal, tumbalMap)
        local mutasi = dropdownTargetMutasi:GetValue()

        print("=== UUID Terpilih ===")
        print("Tim Shark   : " .. sharkUUID)
        print("Pet Target  : " .. targetUUID)
        print("Pet Tumbal  : " .. tumbalUUID)
        print("Target Mutasi : " .. mutasi)
    end
})

TabAutoShark:AddButton({
    Name = "Refresh Semua Data Pet",
    Callback = function()
        -- Refresh Tim Shark
        local newShark = DataPetModule.findPets({ isFavorite = true })
        local newVals, newMap = buildDropdownData(newShark)
        sharkValues = newVals
        sharkMap = newMap
        dropdownTimShark:SetValues(sharkValues)
        dropdownTimShark:SetValue(sharkValues[1] or "")

        -- Refresh Pet Target
        local newTarget = DataPetModule.findPets({ isFavorite = false, mutation = "Normal" })
        local newTVals, newTMap = buildDropdownData(newTarget)
        targetValues = newTVals
        targetMap = newTMap
        dropdownPetTarget:SetValues(targetValues)
        dropdownPetTarget:SetValue(targetValues[1] or "")

        -- Refresh Target Mutasi
        local newMuts = getMutationList()
        local newMutVals = {}
        local newMutMap = {}
        for _, m in ipairs(newMuts) do
            newMutMap[m] = m
            table.insert(newMutVals, m)
        end
        mutValues = newMutVals
        mutMap = newMutMap
        dropdownTargetMutasi:SetValues(mutValues)
        dropdownTargetMutasi:SetValue(mutValues[1] or "Normal")

        -- Refresh Tumbal sesuai mutasi terpilih
        local currentMut = dropdownTargetMutasi:GetValue()
        updateTumbalDropdown(currentMut)

        print("Semua data pet di-refresh!")
    end
})

-- ============================================================
-- 11. SETUP THEME & SAVE
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
-- 12. INISIALISASI AWAL
-- ============================================================
updateTumbalDropdown(dropdownTargetMutasi:GetValue() or "Normal")
print("Pria Solo HUB - Auto Shark Tab siap digunakan!")

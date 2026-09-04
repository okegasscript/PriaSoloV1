-- ============================================================
-- SCRIPT: Pria Solo HUB - Auto Shark Tab (Ukuran 400x600)
-- Tampilan pet dipersingkat agar tidak overflow
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

-- Format tampilan pet yang lebih pendek (tanpa berat dan UUID)
local function formatPetDisplay(pet)
    return string.format(
        "%s [%s] Lv.%d",
        pet.name,
        pet.mutation,
        pet.level
    )
end

-- Bangun daftar value untuk dropdown (list display string) dan mapping display->uuid
local function buildDropdownData(petList)
    local displayToUUID = {}
    local values = {}
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
    MenuFadeTime = 0.2,
    Size = UDim2.new(0, 400, 0, 600)
})

-- ============================================================
-- 5. BUAT TAB & GROUPBOX
-- ============================================================
local TabAutoShark = Window:AddTab("Auto Shark")
local UISettingsTab = Window:AddTab("UI Settings")

local AutoSharkGroup = TabAutoShark:AddLeftGroupbox("Auto Shark Settings")
local ActionGroup = TabAutoShark:AddRightGroupbox("Actions")

local UISettingsGroup = UISettingsTab:AddLeftGroupbox("Settings")

-- ============================================================
-- 6. DROPDOWN "Pilih Tim Shark" (favorit = true)
-- ============================================================
local sharkPets = DataPetModule.findPets({ isFavorite = true })
local sharkValues, sharkMap = buildDropdownData(sharkPets)

local dropdownTimShark = AutoSharkGroup:AddDropdown("TimShark", {
    Values = sharkValues,
    Default = sharkValues[1] or "",
    Multi = false,
    Text = "Pilih Tim Shark",
    Tooltip = "Pilih pet favorit untuk tim shark"
})

-- ============================================================
-- 7. DROPDOWN "Pilih Pet Target" (favorit = false, mutasi Normal)
-- ============================================================
local targetPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = "Normal"
})
local targetValues, targetMap = buildDropdownData(targetPets)

local dropdownPetTarget = AutoSharkGroup:AddDropdown("PetTarget", {
    Values = targetValues,
    Default = targetValues[1] or "",
    Multi = false,
    Text = "Pilih Pet Target",
    Tooltip = "Pilih pet target (tanpa mutasi)"
})

-- ============================================================
-- 8. DROPDOWN "Pilih Target Mutasi" (daftar semua mutasi)
-- ============================================================
local mutationList = getMutationList()
local mutValues = {}
local mutMap = {}
for _, m in ipairs(mutationList) do
    mutMap[m] = m
    table.insert(mutValues, m)
end

local dropdownTargetMutasi = AutoSharkGroup:AddDropdown("TargetMutasi", {
    Values = mutValues,
    Default = mutValues[1] or "Normal",
    Multi = false,
    Text = "Pilih Target Mutasi",
    Tooltip = "Pilih mutasi yang diinginkan"
})

-- ============================================================
-- 9. DROPDOWN "Pilih Pet Tumbal" (favorit = false, mutasi sesuai pilihan)
-- ============================================================
local tumbalValues = {}
local tumbalMap = {}

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

local initialMut = mutValues[1] or "Normal"
local initialTumbalPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = initialMut
})
local initVals, initMap = buildDropdownData(initialTumbalPets)
tumbalValues = initVals
tumbalMap = initMap

local dropdownPetTumbal = AutoSharkGroup:AddDropdown("PetTumbal", {
    Values = tumbalValues,
    Default = tumbalValues[1] or "",
    Multi = false,
    Text = "Pilih Pet Tumbal",
    Tooltip = "Pilih pet tumbal sesuai mutasi yang dipilih"
})

-- ============================================================
-- 10. TOMBOL DI ACTION GROUP
-- ============================================================

-- Fungsi untuk mendapatkan UUID dari dropdown
local function getSelectedUUID(dropdownObj, map)
    local selectedText = dropdownObj:GetValue()
    return map[selectedText] or ""
end

-- Tombol Refresh Pet Tumbal
ActionGroup:AddButton({
    Name = "Refresh Pet Tumbal",
    Callback = function()
        local selectedMut = dropdownTargetMutasi:GetValue()
        updateTumbalDropdown(selectedMut)
        print("Pet tumbal diperbarui sesuai mutasi: " .. selectedMut)
    end
})

-- Tombol Tampilkan UUID Terpilih
ActionGroup:AddButton({
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

-- Tombol Refresh Semua Data Pet
ActionGroup:AddButton({
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

        -- Refresh Tumbal
        local currentMut = dropdownTargetMutasi:GetValue()
        updateTumbalDropdown(currentMut)

        print("Semua data pet di-refresh!")
    end
})

-- ============================================================
-- 11. TOMBOL START / STOP AUTO SHARK
-- ============================================================
local isRunning = false
local autoSharkLoop = nil

-- Fungsi utama auto shark (contoh, sesuaikan dengan logika game)
local function startAutoShark()
    local sharkUUID = getSelectedUUID(dropdownTimShark, sharkMap)
    local targetUUID = getSelectedUUID(dropdownPetTarget, targetMap)
    local tumbalUUID = getSelectedUUID(dropdownPetTumbal, tumbalMap)
    local targetMutasi = dropdownTargetMutasi:GetValue()

    if sharkUUID == "" or targetUUID == "" or tumbalUUID == "" then
        print("Error: Pastikan semua pet sudah dipilih!")
        return
    end

    print("=== Memulai Auto Shark ===")
    print("Tim Shark UUID   : " .. sharkUUID)
    print("Target UUID      : " .. targetUUID)
    print("Tumbal UUID      : " .. tumbalUUID)
    print("Target Mutasi    : " .. targetMutasi)

    -- Contoh loop sederhana (ganti dengan logika auto shark yang sebenarnya)
    isRunning = true
    autoSharkLoop = game:GetService("RunService").Heartbeat:Connect(function()
        if not isRunning then return end
        -- Di sini Anda bisa menambahkan logika untuk melakukan auto shark
        -- Misalnya: menggunakan pet UUID untuk melakukan aksi di game
        -- Contoh: print("Auto Shark berjalan...")
    end)

    print("Auto Shark dimulai!")
end

local function stopAutoShark()
    if autoSharkLoop then
        autoSharkLoop:Disconnect()
        autoSharkLoop = nil
    end
    isRunning = false
    print("Auto Shark dihentikan.")
end

-- Tombol Start
ActionGroup:AddButton({
    Name = "Start Auto Shark",
    Callback = function()
        if isRunning then
            print("Auto Shark sudah berjalan!")
            return
        end
        startAutoShark()
    end
})

-- Tombol Stop
ActionGroup:AddButton({
    Name = "Stop Auto Shark",
    Callback = function()
        if not isRunning then
            print("Auto Shark tidak sedang berjalan.")
            return
        end
        stopAutoShark()
    end
})

-- ============================================================
-- 12. SETUP THEME & SAVE
-- ============================================================
UISettingsGroup:AddButton({
    Name = "Theme Manager",
    Callback = function()
        ThemeManager:SetTheme("Dark")
        ThemeManager:OpenThemeMenu()
    end
})

UISettingsGroup:AddButton({
    Name = "Save Config",
    Callback = function()
        SaveManager:SaveConfig()
    end
})

UISettingsGroup:AddButton({
    Name = "Load Config",
    Callback = function()
        SaveManager:LoadConfig()
    end
})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

-- ============================================================
-- 13. INISIALISASI AWAL
-- ============================================================
updateTumbalDropdown(dropdownTargetMutasi:GetValue() or "Normal")
print("Pria Solo HUB - Auto Shark Tab siap digunakan!")

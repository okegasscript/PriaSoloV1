-- ============================================================
-- SCRIPT: Pria Solo HUB - Auto Shark Tab (WindUI)
-- Menggunakan WindUI dari GitHub & DataPetModule
-- Ukuran Window: 400x600
-- ============================================================

-- ============================================================
-- 1. LOAD WindUI dari repository yang diberikan
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

if not WindUI then
    error("Gagal memuat WindUI!")
end

-- ============================================================
-- 2. LOAD DataPetModule dari GitHub
-- ============================================================
local DataPetModule = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/DataPetModule.lua"
))()
if not DataPetModule then error("Gagal memuat DataPetModule!") end

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

-- Format tampilan pet yang pendek
local function formatPetDisplay(pet)
    return string.format("%s [%s] Lv.%d", pet.name, pet.mutation, pet.level)
end

-- Bangun opsi dropdown dalam format WindUI: {Title = display, UUID = uuid}
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
        table.insert(options, { Title = display, UUID = pet.uuid })
    end
    if #options == 0 then
        table.insert(options, { Title = "Tidak ada pet", UUID = "" })
    end
    return options
end

-- ============================================================
-- 4. BUAT WINDOW DENGAN WINDUI (Ukuran 400x600)
-- ============================================================
local Window = WindUI:CreateWindow({
    Title = "Pria Solo HUB",
    Size = UDim2.new(0, 400, 0, 600),
    Center = true,
    AutoShow = true,  -- AutoShow sudah true, jadi window otomatis muncul
    Draggable = true,
})

-- ============================================================
-- 5. BUAT TAB "Auto Shark"
-- ============================================================
local TabAutoShark = Window:Tab({
    Title = "Auto Shark",
    Icon = "solar:shark-bold",
})

-- Buat Section untuk dropdown
local AutoSharkSection = TabAutoShark:Section({
    Title = "Auto Shark Settings",
})

-- ============================================================
-- 6. DROPDOWN "Pilih Tim Shark" (favorit = true)
-- ============================================================
local sharkPets = DataPetModule.findPets({ isFavorite = true })
local sharkOptions = buildDropdownOptions(sharkPets)
local selectedTimSharkUUID = sharkOptions[1] and sharkOptions[1].UUID or ""

local dropdownTimShark = AutoSharkSection:Dropdown({
    Title = "Pilih Tim Shark",
    Values = sharkOptions,
    Value = sharkOptions[1] and sharkOptions[1].Title or "Tidak ada pet",
    Callback = function(option)
        selectedTimSharkUUID = option.UUID or ""
        print("Tim Shark UUID:", selectedTimSharkUUID)
        _G.selectedTimSharkUUID = selectedTimSharkUUID
    end
})

AutoSharkSection:Space()

-- ============================================================
-- 7. DROPDOWN "Pilih Pet Target" (favorit = false, mutasi Normal)
-- ============================================================
local targetPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = "Normal"
})
local targetOptions = buildDropdownOptions(targetPets)
local selectedTargetUUID = targetOptions[1] and targetOptions[1].UUID or ""

local dropdownPetTarget = AutoSharkSection:Dropdown({
    Title = "Pilih Pet Target",
    Values = targetOptions,
    Value = targetOptions[1] and targetOptions[1].Title or "Tidak ada pet",
    Callback = function(option)
        selectedTargetUUID = option.UUID or ""
        print("Pet Target UUID:", selectedTargetUUID)
        _G.selectedTargetUUID = selectedTargetUUID
    end
})

AutoSharkSection:Space()

-- ============================================================
-- 8. DROPDOWN "Pilih Target Mutasi" (daftar mutasi)
-- ============================================================
local mutationList = getMutationList()
local mutOptions = {}
for _, m in ipairs(mutationList) do
    table.insert(mutOptions, { Title = m, UUID = m })
end
local selectedMutation = mutOptions[1] and mutOptions[1].Title or "Normal"

local dropdownTargetMutasi = AutoSharkSection:Dropdown({
    Title = "Pilih Target Mutasi",
    Values = mutOptions,
    Value = mutOptions[1] and mutOptions[1].Title or "Normal",
    Callback = function(option)
        selectedMutation = option.Title or "Normal"
        print("Target Mutasi:", selectedMutation)
        _G.selectedMutation = selectedMutation
        -- Update tumbal otomatis
        updateTumbalDropdown(selectedMutation)
    end
})

AutoSharkSection:Space()

-- ============================================================
-- 9. DROPDOWN "Pilih Pet Tumbal" (favorit = false, mutasi sesuai pilihan)
-- ============================================================
local tumbalOptions = {}
local selectedTumbalUUID = ""

-- Fungsi untuk memperbarui dropdown tumbal
local function updateTumbalDropdown(mutation)
    local tumbalPets = DataPetModule.findPets({
        isFavorite = false,
        mutation = mutation
    })
    tumbalOptions = buildDropdownOptions(tumbalPets)
    dropdownPetTumbal:Refresh(tumbalOptions)
    dropdownPetTumbal:Set(tumbalOptions[1] and tumbalOptions[1].Title or "Tidak ada pet")
    -- Update selected UUID
    selectedTumbalUUID = tumbalOptions[1] and tumbalOptions[1].UUID or ""
    _G.selectedTumbalUUID = selectedTumbalUUID
end

-- Inisialisasi tumbal dengan mutasi default
local initialMut = mutOptions[1] and mutOptions[1].Title or "Normal"
local initialTumbalPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = initialMut
})
tumbalOptions = buildDropdownOptions(initialTumbalPets)

local dropdownPetTumbal = AutoSharkSection:Dropdown({
    Title = "Pilih Pet Tumbal",
    Values = tumbalOptions,
    Value = tumbalOptions[1] and tumbalOptions[1].Title or "Tidak ada pet",
    Callback = function(option)
        selectedTumbalUUID = option.UUID or ""
        print("Pet Tumbal UUID:", selectedTumbalUUID)
        _G.selectedTumbalUUID = selectedTumbalUUID
    end
})

-- ============================================================
-- 10. SECTION UNTUK TOMBOL AKSI
-- ============================================================
local ActionSection = TabAutoShark:Section({
    Title = "Actions",
})

-- Tombol refresh tumbal (jika ingin manual)
ActionSection:Button({
    Title = "Refresh Pet Tumbal",
    Justify = "Center",
    Callback = function()
        local currentMut = selectedMutation or "Normal"
        updateTumbalDropdown(currentMut)
        print("Pet tumbal diperbarui")
    end
})

ActionSection:Space()

-- Tombol tampilkan UUID terpilih
ActionSection:Button({
    Title = "Tampilkan UUID Terpilih",
    Justify = "Center",
    Callback = function()
        print("=== UUID Terpilih ===")
        print("Tim Shark   : " .. tostring(selectedTimSharkUUID))
        print("Pet Target  : " .. tostring(selectedTargetUUID))
        print("Pet Tumbal  : " .. tostring(selectedTumbalUUID))
        print("Target Mutasi : " .. tostring(selectedMutation))
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
        dropdownTimShark:Set(newOpts[1] and newOpts[1].Title or "Tidak ada pet")
        selectedTimSharkUUID = newOpts[1] and newOpts[1].UUID or ""

        -- Refresh Pet Target
        local newTarget = DataPetModule.findPets({ isFavorite = false, mutation = "Normal" })
        local newTargetOpts = buildDropdownOptions(newTarget)
        dropdownPetTarget:Refresh(newTargetOpts)
        dropdownPetTarget:Set(newTargetOpts[1] and newTargetOpts[1].Title or "Tidak ada pet")
        selectedTargetUUID = newTargetOpts[1] and newTargetOpts[1].UUID or ""

        -- Refresh Target Mutasi
        local newMuts = getMutationList()
        local newMutOpts = {}
        for _, m in ipairs(newMuts) do
            table.insert(newMutOpts, { Title = m, UUID = m })
        end
        dropdownTargetMutasi:Refresh(newMutOpts)
        dropdownTargetMutasi:Set(newMutOpts[1] and newMutOpts[1].Title or "Normal")
        selectedMutation = newMutOpts[1] and newMutOpts[1].Title or "Normal"

        -- Refresh Tumbal
        updateTumbalDropdown(selectedMutation)

        print("Semua data pet di-refresh!")
    end
})

-- ============================================================
-- 11. WINDOW OTOMATIS TAMPIL (AutoShow = true)
-- ============================================================
-- Tidak perlu memanggil Window:Show() karena AutoShow sudah true
-- Jika ingin dipanggil manual, gunakan Window:Open() bukan Show()
-- Window:Open() -- opsional jika AutoShow false

print("Pria Solo HUB - Auto Shark Tab siap digunakan dengan WindUI!")

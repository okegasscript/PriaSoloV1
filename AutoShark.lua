-- ============================================================
-- SCRIPT: Pria Solo HUB - Auto Shark Tab (WindUI)
-- Menggunakan DataPetModule dari GitHub & WindUI
-- Ukuran Window: 400x600
-- ============================================================

-- ============================================================
-- 1. LOAD DataPetModule dari GitHub
-- ============================================================
local DataPetModule = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/DataPetModule.lua"
))()
if not DataPetModule then error("Gagal memuat DataPetModule!") end

-- ============================================================
-- 2. LOAD WindUI
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/wind-js/WindUI/main/WindUI.lua"))()
if not WindUI then error("Gagal memuat WindUI!") end

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

-- Bangun opsi dropdown dalam format WindUI: {text = display, value = uuid}
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
        table.insert(options, { text = display, value = pet.uuid })
    end
    if #options == 0 then
        table.insert(options, { text = "Tidak ada pet", value = "" })
    end
    return options
end

-- ============================================================
-- 4. BUAT WINDOW DENGAN WINDUI
-- ============================================================
local Window = WindUI:CreateWindow({
    Title = "Pria Solo HUB",
    Size = UDim2.new(0, 400, 0, 600),
    Center = true,
    AutoShow = true,
    Draggable = true,
})

-- ============================================================
-- 5. BUAT TAB "Auto Shark"
-- ============================================================
local TabAutoShark = Window:AddTab("Auto Shark")

-- ============================================================
-- 6. DROPDOWN "Pilih Tim Shark" (favorit = true)
-- ============================================================
local sharkPets = DataPetModule.findPets({ isFavorite = true })
local sharkOptions = buildDropdownOptions(sharkPets)

local dropdownTimShark = TabAutoShark:AddDropdown({
    Text = "Pilih Tim Shark",
    List = sharkOptions,
    Default = sharkOptions[1] and sharkOptions[1].value or "",
    Callback = function(value)
        print("Tim Shark UUID:", value)
        _G.selectedTimSharkUUID = value
    end
})

-- ============================================================
-- 7. DROPDOWN "Pilih Pet Target" (favorit = false, mutasi Normal)
-- ============================================================
local targetPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = "Normal"
})
local targetOptions = buildDropdownOptions(targetPets)

local dropdownPetTarget = TabAutoShark:AddDropdown({
    Text = "Pilih Pet Target",
    List = targetOptions,
    Default = targetOptions[1] and targetOptions[1].value or "",
    Callback = function(value)
        print("Pet Target UUID:", value)
        _G.selectedTargetUUID = value
    end
})

-- ============================================================
-- 8. DROPDOWN "Pilih Target Mutasi" (daftar mutasi)
-- ============================================================
local mutationList = getMutationList()
local mutOptions = {}
for _, m in ipairs(mutationList) do
    table.insert(mutOptions, { text = m, value = m })
end

local dropdownTargetMutasi = TabAutoShark:AddDropdown({
    Text = "Pilih Target Mutasi",
    List = mutOptions,
    Default = mutOptions[1] and mutOptions[1].value or "Normal",
    Callback = function(value)
        print("Target Mutasi:", value)
        _G.selectedMutation = value
        -- Update tumbal otomatis
        updateTumbalDropdown(value)
    end
})

-- ============================================================
-- 9. DROPDOWN "Pilih Pet Tumbal" (favorit = false, mutasi sesuai pilihan)
-- ============================================================
local tumbalOptions = {}

local function updateTumbalDropdown(mutation)
    local tumbalPets = DataPetModule.findPets({
        isFavorite = false,
        mutation = mutation
    })
    tumbalOptions = buildDropdownOptions(tumbalPets)
    dropdownPetTumbal:SetList(tumbalOptions)
    dropdownPetTumbal:SetDefault(tumbalOptions[1] and tumbalOptions[1].value or "")
end

-- Inisialisasi tumbal dengan mutasi default
local initialMut = mutOptions[1] and mutOptions[1].value or "Normal"
local initialTumbalPets = DataPetModule.findPets({
    isFavorite = false,
    mutation = initialMut
})
tumbalOptions = buildDropdownOptions(initialTumbalPets)

local dropdownPetTumbal = TabAutoShark:AddDropdown({
    Text = "Pilih Pet Tumbal",
    List = tumbalOptions,
    Default = tumbalOptions[1] and tumbalOptions[1].value or "",
    Callback = function(value)
        print("Pet Tumbal UUID:", value)
        _G.selectedTumbalUUID = value
    end
})

-- ============================================================
-- 10. TOMBOL-Tombol Aksi
-- ============================================================

-- Tombol refresh tumbal (jika ingin manual)
TabAutoShark:AddButton({
    Text = "Refresh Pet Tumbal",
    Callback = function()
        local currentMut = dropdownTargetMutasi:GetValue()
        updateTumbalDropdown(currentMut)
        print("Pet tumbal diperbarui")
    end
})

-- Tombol tampilkan UUID terpilih
TabAutoShark:AddButton({
    Text = "Tampilkan UUID Terpilih",
    Callback = function()
        print("=== UUID Terpilih ===")
        print("Tim Shark   : " .. tostring(_G.selectedTimSharkUUID))
        print("Pet Target  : " .. tostring(_G.selectedTargetUUID))
        print("Pet Tumbal  : " .. tostring(_G.selectedTumbalUUID))
        print("Target Mutasi : " .. tostring(_G.selectedMutation))
    end
})

-- Tombol refresh semua data
TabAutoShark:AddButton({
    Text = "Refresh Semua Data Pet",
    Callback = function()
        -- Refresh Tim Shark
        local newShark = DataPetModule.findPets({ isFavorite = true })
        local newOpts = buildDropdownOptions(newShark)
        dropdownTimShark:SetList(newOpts)
        dropdownTimShark:SetDefault(newOpts[1] and newOpts[1].value or "")

        -- Refresh Pet Target
        local newTarget = DataPetModule.findPets({ isFavorite = false, mutation = "Normal" })
        local newTargetOpts = buildDropdownOptions(newTarget)
        dropdownPetTarget:SetList(newTargetOpts)
        dropdownPetTarget:SetDefault(newTargetOpts[1] and newTargetOpts[1].value or "")

        -- Refresh Target Mutasi
        local newMuts = getMutationList()
        local newMutOpts = {}
        for _, m in ipairs(newMuts) do
            table.insert(newMutOpts, { text = m, value = m })
        end
        dropdownTargetMutasi:SetList(newMutOpts)
        dropdownTargetMutasi:SetDefault(newMutOpts[1] and newMutOpts[1].value or "Normal")

        -- Refresh Tumbal
        local currentMut = dropdownTargetMutasi:GetValue()
        updateTumbalDropdown(currentMut)

        print("Semua data pet di-refresh!")
    end
})

-- ============================================================
-- 11. TAMPILKAN WINDOW
-- ============================================================
Window:Show()

print("Pria Solo HUB - Auto Shark Tab siap digunakan dengan WindUI!")

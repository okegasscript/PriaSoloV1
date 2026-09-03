-- ============================================================
-- MAIN SCRIPT - Leveling UI dengan Fluent (Multi-Select Dropdown)
-- Memuat DataPetModule dari GitHub (versi terbaru dengan berat otomatis)
-- ============================================================

-- Load Library Fluent
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ============================================================
-- LOAD DATAPETMODULE DARI GITHUB (versi terbaru)
-- ============================================================
local DataPetModule
local loadSuccess, loadResult = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSoloV1/refs/heads/main/DataPetModule.lua"))()
end)

if loadSuccess and loadResult then
    DataPetModule = loadResult
    print("[Leveling Script] DataPetModule berhasil dimuat (versi terbaru)")
else
    warn("[Leveling Script] Gagal memuat DataPetModule:", loadResult)
end

-- ============================================================
-- BUAT WINDOW UTAMA dengan judul "Pria Solo HUB"
-- ============================================================
local Window = Fluent:CreateWindow({
    Title = "Pria Solo HUB",
    SubTitle = "Multi-Select Pet",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Tambahkan Tab Leveling
local LevelingTab = Window:AddTab({ Title = "Leveling" })

-- ============================================================
-- VARIABEL GLOBAL
-- ============================================================
local petOptions = {}          -- label -> pet data
local selectedPets = {}        -- array pet data yang dipilih
local selectedUUIDs = {}       -- array UUID yang dipilih (untuk penyimpanan)
local dropdownControl = nil    -- referensi dropdown
local infoParagraph = nil      -- referensi paragraf info

-- Key penyimpanan di SaveManager (gunakan _G sebagai fallback)
local SAVE_KEY = "SelectedPetUUIDs"

-- ============================================================
-- FUNGSI UPDATE INFO PET (menampilkan daftar pet terpilih)
-- Sekarang menggunakan pet.weight (berat aktual sesuai level)
-- ============================================================
local function updatePetInfo(pets)
    if not infoParagraph then return end
    if pets and #pets > 0 then
        local lines = {}
        for i, pet in ipairs(pets) do
            table.insert(lines, string.format(
                "%d. %s | %s | Lv.%d | Berat: %.2f",
                i,
                pet.name,
                pet.mutation,
                pet.level,
                pet.weight  -- sudah dihitung oleh DataPetModule.calculateWeightAtLevel
            ))
        end
        infoParagraph:SetText("Pet Terpilih:\n" .. table.concat(lines, "\n"))
    else
        infoParagraph:SetText("Belum ada pet dipilih")
    end
end

-- ============================================================
-- FUNGSI REFRESH DROPDOWN
-- ============================================================
local function refreshPetDropdown()
    if not DataPetModule then
        Fluent:Notify({
            Title = "Error",
            Description = "DataPetModule tidak tersedia",
            Duration = 5
        })
        return
    end

    -- Ambil semua pet favorite (isFavorite = true)
    local pets = DataPetModule.findPets({ isFavorite = true })
    if #pets == 0 then
        Fluent:Notify({
            Title = "Info",
            Description = "Tidak ada pet favorite ditemukan",
            Duration = 5
        })
        if dropdownControl then
            dropdownControl:SetValues({})
        end
        petOptions = {}
        selectedPets = {}
        selectedUUIDs = {}
        updatePetInfo({})
        return
    end

    -- Bangun daftar opsi dengan format: Mutation, Name, Berat, Level
    -- Gunakan pet.weight yang sudah dihitung otomatis
    local values = {}
    petOptions = {}
    for _, pet in ipairs(pets) do
        local label = string.format(
            "%s, %s, %.2f, %d",   -- mutasi, nama, berat (dengan 2 desimal), level
            pet.mutation,
            pet.name,
            pet.weight,  -- berat aktual
            pet.level
        )
        -- Tambahkan UUID di belakang agar unik
        label = label .. " [UUID: " .. pet.uuid .. "]"
        table.insert(values, label)
        petOptions[label] = pet
    end

    -- Set opsi ke dropdown
    if dropdownControl then
        dropdownControl:SetValues(values)

        -- Restore pilihan sebelumnya dari penyimpanan
        local savedUUIDs = _G[SAVE_KEY] or SaveManager:GetData(SAVE_KEY)
        local restoredLabels = {}
        if savedUUIDs and type(savedUUIDs) == "table" then
            for _, uuid in ipairs(savedUUIDs) do
                for label, pet in pairs(petOptions) do
                    if pet.uuid == uuid then
                        table.insert(restoredLabels, label)
                        break
                    end
                end
            end
        end

        if #restoredLabels > 0 then
            dropdownControl:SetValue(restoredLabels)
            local selected = {}
            for _, label in ipairs(restoredLabels) do
                if petOptions[label] then
                    table.insert(selected, petOptions[label])
                end
            end
            selectedPets = selected
            selectedUUIDs = {}
            for _, pet in ipairs(selected) do
                table.insert(selectedUUIDs, pet.uuid)
            end
            updatePetInfo(selected)
        else
            dropdownControl:SetValue({})
            selectedPets = {}
            selectedUUIDs = {}
            updatePetInfo({})
        end
    end
end

-- ============================================================
-- BUAT DROPDOWN DAN KOMPONEN LAINNYA
-- ============================================================
local section = LevelingTab:AddSection("Pilih Pet Favorite (Multi)")

-- Dropdown dengan multi-select = true
dropdownControl = section:AddDropdown("PetDropdown", {
    Title = "Daftar Pet Favorite",
    Values = {},  -- akan diisi oleh refresh
    Multi = true,
    Default = {},
    Callback = function(selectedLabels)
        if selectedLabels and #selectedLabels > 0 then
            local selected = {}
            local uuids = {}
            for _, label in ipairs(selectedLabels) do
                if petOptions[label] then
                    table.insert(selected, petOptions[label])
                    table.insert(uuids, petOptions[label].uuid)
                end
            end
            selectedPets = selected
            selectedUUIDs = uuids
            _G[SAVE_KEY] = uuids
            pcall(function() SaveManager:SetData(SAVE_KEY, uuids) end)
            updatePetInfo(selected)
            print("[Leveling] Pet terpilih:", #selected, "pet")
        else
            selectedPets = {}
            selectedUUIDs = {}
            _G[SAVE_KEY] = {}
            pcall(function() SaveManager:SetData(SAVE_KEY, {}) end)
            updatePetInfo({})
        end
    end
})

-- Tombol Refresh
section:AddButton({
    Title = "↻ Refresh Daftar",
    Callback = function()
        refreshPetDropdown()
    end
})

-- Tombol Pilih Semua
section:AddButton({
    Title = "Select All",
    Callback = function()
        if dropdownControl and next(petOptions) then
            local allLabels = {}
            for label, _ in pairs(petOptions) do
                table.insert(allLabels, label)
            end
            dropdownControl:SetValue(allLabels)
            local cb = dropdownControl.Callback
            if cb then cb(allLabels) end
        end
    end
})

-- Tombol Hapus Semua
section:AddButton({
    Title = "Clear All",
    Callback = function()
        if dropdownControl then
            dropdownControl:SetValue({})
            local cb = dropdownControl.Callback
            if cb then cb({}) end
        end
    end
})

-- ============================================================
-- PARAGRAPH DENGAN FORMAT TABEL (Title & Content)
-- ============================================================
infoParagraph = section:AddParagraph({
    Title = "Pet Terpilih",
    Content = "Belum ada pet dipilih"
})

-- ============================================================
-- MUAT DAFTAR PERTAMA KALI
-- ============================================================
task.wait(1)
refreshPetDropdown()

-- ============================================================
-- SETUP SAVEMANAGER & INTERFACEMANAGER
-- ============================================================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("LevelingScript")
InterfaceManager:BuildInterfaceSection(Window)

Window:OnClose(function()
    SaveManager:Save()
    InterfaceManager:Save()
end)

SaveManager:Load()
InterfaceManager:Load()

-- ============================================================
-- NOTIFIKASI AWAL
-- ============================================================
Fluent:Notify({
    Title = "Pria Solo HUB",
    Description = "Script leveling siap digunakan!",
    Duration = 3
})

print("[Pria Solo HUB] UI selesai dimuat (multi-select, berat otomatis)")
